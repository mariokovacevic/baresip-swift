"""Push gateway of the door stack.

Listens on Asterisk's manager interface for the BSKPush event, which the dialplan raises when
a door station rings a resident whose contact carries a push token, and sends a VoIP push to
APNs or a high-priority data message to Firebase Cloud Messaging. The token and the app's
identifier come from the Contact parameters that BaresipKit registers: on iOS
`pn-type=apple`, `pn-tok=<hex>:remote&<hex>:voip`, `app-id=<bundle id>`; on Android
`pn-type=firebase`, `pn-tok=<registration token>`, `app-id=<package>`. The payload names the
caller and carries the call's UUID, which the dialplan also puts in the INVITE as X-Call-UUID.

Environment:
  STATE_DIR       folder with secrets.env (AMI_SECRET) and apns-mock.pem, default /state
  AMI_HOST, AMI_PORT, AMI_USER   manager interface, default 127.0.0.1:5038, bsk-push
  APNS_HOST       host[:port] of APNs, default 127.0.0.1:8443 (the mock);
                  api.sandbox.push.apple.com or api.push.apple.com for a phone
  APNS_CA_FILE    CA for APNS_HOST; default STATE_DIR/apns-mock.pem for the mock, the system
                  store otherwise
  APNS_KEY_FILE, APNS_KEY_ID, APNS_TEAM_ID   token signing key (.p8) for Apple's servers
  FCM_HOST        host[:port] of FCM, default 127.0.0.1:8444 (the mock, plain HTTP);
                  fcm.googleapis.com for phones
  FCM_PROJECT_ID  Firebase project, default doorstack
  FCM_SERVICE_ACCOUNT_FILE   service account key (JSON) that signs requests to Google's servers
  SIP_DOMAIN      host part of the caller URI in the push payload, default 127.0.0.1
  HTTP_LISTEN     host:port of the status endpoint, default 127.0.0.1:8088

GET /health and GET /pushes on HTTP_LISTEN report the state and the last pushes.
"""

import asyncio
import json
import os
import ssl
import sys
import time
import urllib.parse

import httpx
import jwt

STATE_DIR = os.environ.get("STATE_DIR", "/state")
MOCK_HOST = "127.0.0.1:8443"
FCM_MOCK_HOST = "127.0.0.1:8444"
FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
FIREBASE_TYPES = ("firebase", "fcm", "google")
HISTORY = 50
JWT_LIFETIME = 45 * 60
RECONNECT_DELAY = 2


def log(message):
    print("gateway: %s" % message, flush=True)


def read_env_file(path):
    values = {}
    try:
        with open(path) as handle:
            for line in handle:
                name, separator, value = line.strip().partition("=")
                if separator:
                    values[name] = value
    except OSError:
        pass
    return values


def contact_parameters(uri):
    parameters = {}
    for part in urllib.parse.unquote(uri).strip("<>").split(";")[1:]:
        name, _, value = part.partition("=")
        parameters[name.lower()] = value
    return parameters


def push_tokens(parameters):
    tokens = {}
    for entry in parameters.get("pn-tok", "").split("&"):
        token, separator, kind = entry.rpartition(":")
        if separator and token:
            tokens[kind] = token
    return tokens


def short(token):
    return token[:8] + "..."


class Apns:
    def __init__(self):
        self.host = os.environ.get("APNS_HOST", MOCK_HOST)
        ca_file = os.environ.get("APNS_CA_FILE")
        if not ca_file and self.host == MOCK_HOST:
            ca_file = os.path.join(STATE_DIR, "apns-mock.pem")
        context = ssl.create_default_context(cafile=ca_file) if ca_file else ssl.create_default_context()
        self.client = httpx.AsyncClient(http2=True, verify=context, timeout=10)
        self.key_file = os.environ.get("APNS_KEY_FILE")
        self.key_id = os.environ.get("APNS_KEY_ID")
        self.team_id = os.environ.get("APNS_TEAM_ID")
        self.bearer = None
        self.bearer_time = 0

    def authorization(self):
        if not (self.key_file and self.key_id and self.team_id):
            return None
        now = int(time.time())
        if self.bearer is None or now - self.bearer_time > JWT_LIFETIME:
            with open(self.key_file) as handle:
                key = handle.read()
            self.bearer = jwt.encode({"iss": self.team_id, "iat": now}, key, algorithm="ES256",
                                     headers={"kid": self.key_id})
            self.bearer_time = now
        return "bearer %s" % self.bearer

    async def send(self, token, topic, push_type, payload):
        headers = {
            "apns-topic": topic,
            "apns-push-type": push_type,
            "apns-priority": "10",
            "apns-expiration": "0",
        }
        authorization = self.authorization()
        if authorization:
            headers["authorization"] = authorization
        response = await self.client.post("https://%s/3/device/%s" % (self.host, token),
                                          headers=headers, content=json.dumps(payload))
        reason = ""
        if response.status_code != 200:
            try:
                reason = response.json().get("reason", "")
            except ValueError:
                reason = response.text[:80]
        return response.status_code, reason


class Fcm:
    def __init__(self):
        self.host = os.environ.get("FCM_HOST", FCM_MOCK_HOST)
        self.project = os.environ.get("FCM_PROJECT_ID", "doorstack")
        self.client = httpx.AsyncClient(timeout=10)
        self.account = None
        account_file = os.environ.get("FCM_SERVICE_ACCOUNT_FILE")
        if account_file and os.path.getsize(account_file) > 0:
            with open(account_file) as handle:
                self.account = json.load(handle)
        self.bearer = None
        self.bearer_time = 0

    @property
    def base_url(self):
        scheme = "http" if self.host == FCM_MOCK_HOST else "https"
        return "%s://%s" % (scheme, self.host)

    async def authorization(self):
        if not self.account:
            return None
        now = int(time.time())
        if self.bearer is None or now - self.bearer_time > JWT_LIFETIME:
            assertion = jwt.encode({"iss": self.account["client_email"], "scope": FCM_SCOPE,
                                    "aud": self.account["token_uri"], "iat": now, "exp": now + 3600},
                                   self.account["private_key"], algorithm="RS256")
            response = await self.client.post(self.account["token_uri"], data={
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion})
            response.raise_for_status()
            self.bearer = response.json()["access_token"]
            self.bearer_time = now
        return "Bearer %s" % self.bearer

    async def send(self, token, payload):
        data = {name: ("1" if value is True else "0" if value is False else str(value))
                for name, value in payload.items()}
        data["type"] = "call"
        message = {"message": {"token": token, "data": data,
                               "android": {"priority": "high", "ttl": "0s"}}}
        headers = {"content-type": "application/json"}
        authorization = await self.authorization()
        if authorization:
            headers["authorization"] = authorization
        response = await self.client.post("%s/v1/projects/%s/messages:send" % (self.base_url, self.project),
                                          headers=headers, content=json.dumps(message))
        reason = ""
        if response.status_code != 200:
            try:
                reason = response.json().get("error", {}).get("status", "")
            except ValueError:
                reason = response.text[:80]
        return response.status_code, reason


class Gateway:
    def __init__(self):
        self.apns = Apns()
        self.fcm = Fcm()
        self.sip_domain = os.environ.get("SIP_DOMAIN", "127.0.0.1")
        self.ami_connected = False
        self.pushes = []

    def record(self, entry):
        self.pushes.append(entry)
        del self.pushes[:-HISTORY]

    async def wake(self, event):
        resident = event.get("Resident", "")
        parameters = contact_parameters(event.get("Contact", ""))
        caller = event.get("Caller", "")
        payload = {
            "from": "sip:%s@%s" % (caller, self.sip_domain),
            "name": event.get("CallerName", "") or caller,
            "video": event.get("Video", "0") == "1",
        }
        if event.get("CallUUID"):
            payload["uuid"] = event["CallUUID"]
        app_id = parameters.get("app-id")
        if parameters.get("pn-type", "").lower() in FIREBASE_TYPES:
            await self.wake_android(resident, parameters.get("pn-tok", ""), app_id, payload)
            return
        token = push_tokens(parameters).get("voip")
        entry = {"time": time.time(), "resident": resident, "type": "voip"}
        if not token or not app_id:
            entry["error"] = "the contact has no VoIP token or app-id"
            log("%s: %s" % (resident, entry["error"]))
            self.record(entry)
            return
        entry.update(token=short(token), topic=app_id + ".voip")
        try:
            status, reason = await self.apns.send(token, app_id + ".voip", "voip", payload)
            entry.update(status=status, reason=reason)
            log("%s: VoIP push to %s: %s %s" % (resident, short(token), status, reason))
        except (httpx.HTTPError, OSError, ValueError) as error:
            entry["error"] = str(error)
            log("%s: VoIP push to %s failed: %s" % (resident, short(token), error))
        self.record(entry)

    async def wake_android(self, resident, token, app_id, payload):
        entry = {"time": time.time(), "resident": resident, "type": "fcm"}
        if not token:
            entry["error"] = "the contact has no Firebase token"
            log("%s: %s" % (resident, entry["error"]))
            self.record(entry)
            return
        entry.update(token=short(token), app=app_id or "")
        try:
            status, reason = await self.fcm.send(token, payload)
            entry.update(status=status, reason=reason)
            log("%s: FCM message to %s: %s %s" % (resident, short(token), status, reason))
        except (httpx.HTTPError, OSError, ValueError, KeyError) as error:
            entry["error"] = str(error)
            log("%s: FCM message to %s failed: %s" % (resident, short(token), error))
        self.record(entry)

    async def read_message(self, reader):
        message = {}
        while True:
            line = await reader.readline()
            if not line:
                raise ConnectionError("the manager interface closed the connection")
            text = line.decode(errors="replace").rstrip("\r\n")
            if not text:
                if message:
                    return message
                continue
            name, separator, value = text.partition(": ")
            if separator:
                message[name] = value

    async def manager_session(self, secret):
        host = os.environ.get("AMI_HOST", "127.0.0.1")
        port = int(os.environ.get("AMI_PORT", "5038"))
        user = os.environ.get("AMI_USER", "bsk-push")
        reader, writer = await asyncio.open_connection(host, port)
        try:
            await reader.readline()
            writer.write(("Action: Login\r\nUsername: %s\r\nSecret: %s\r\nEvents: user\r\n\r\n"
                          % (user, secret)).encode())
            await writer.drain()
            reply = await self.read_message(reader)
            if reply.get("Response") != "Success":
                raise ConnectionError("manager login refused: %s" % reply.get("Message", ""))
            self.ami_connected = True
            log("connected to the manager interface at %s:%d" % (host, port))
            while True:
                event = await self.read_message(reader)
                if event.get("Event") == "UserEvent" and event.get("UserEvent") == "BSKPush":
                    asyncio.ensure_future(self.wake(event))
        finally:
            self.ami_connected = False
            writer.close()

    async def manager_loop(self):
        while True:
            secret = read_env_file(os.path.join(STATE_DIR, "secrets.env")).get("AMI_SECRET", "")
            try:
                await self.manager_session(secret)
            except (OSError, ConnectionError) as error:
                log("manager interface: %s" % error)
            await asyncio.sleep(RECONNECT_DELAY)

    async def http_client(self, reader, writer):
        try:
            request = (await reader.readline()).decode(errors="replace").split()
            while (await reader.readline()).strip():
                pass
            path = request[1] if len(request) > 1 else ""
            if path == "/health":
                status, body = 200, {"ami": self.ami_connected, "apns": self.apns.host,
                                     "signed": self.apns.authorization() is not None,
                                     "fcm": self.fcm.host, "fcm_signed": self.fcm.account is not None,
                                     "pushes": len(self.pushes)}
            elif path == "/pushes":
                status, body = 200, self.pushes
            else:
                status, body = 404, {"error": "not found"}
            data = json.dumps(body).encode()
            writer.write(("HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\n"
                          "Connection: close\r\n\r\n" % (status, "OK" if status == 200 else "Not Found",
                                                         len(data))).encode() + data)
            await writer.drain()
        except (OSError, ValueError):
            pass
        finally:
            writer.close()

    async def run(self):
        host, _, port = os.environ.get("HTTP_LISTEN", "127.0.0.1:8088").rpartition(":")
        server = await asyncio.start_server(self.http_client, host, int(port))
        log("status on http://%s:%s, pushes go to %s%s and %s%s" % (
            host, port, self.apns.host, "" if self.apns.authorization() else " (unsigned)",
            self.fcm.host, "" if self.fcm.account else " (unsigned)"))
        async with server:
            await self.manager_loop()


if __name__ == "__main__":
    try:
        asyncio.run(Gateway().run())
    except KeyboardInterrupt:
        sys.exit(0)
