"""Scripted phone that checks the door stack end to end, without Apple and without a phone.

It registers as a resident with push parameters in its Contact, goes away like a suspended
app, lets the door station ring, waits for the VoIP push at the APNs mock (or, with
PUSH_PLATFORM=firebase, for the data message at the FCM mock, as an Android phone gets it),
registers again as a woken app does, expects the INVITE with the call UUID of the push, previews the door's video
before answering, answers, sends the door code and expects the door station to open the door
and hang up.

Environment:
  STATE_DIR      folder with secrets.env and apns-mock.pem, default /state
  SIP_SERVER     host:port of the PBX, default 127.0.0.1:5060
  LOCAL_IP       address the phone uses, default 127.0.0.1
  RESIDENT       account, default 100
  DOOR_CODE      DTMF that opens the door, default 1234
  APNS_MOCK      host:port of the APNs mock, default 127.0.0.1:8443
  PUSH_PLATFORM  apple (default) or firebase
  FCM_MOCK       host:port of the FCM mock, default 127.0.0.1:8444
  DOOR_CONTROL   host:port of the door station's control endpoint, default 127.0.0.1:8089

Exits 0 when every step passed, else 1.
"""

import hashlib
import json
import os
import random
import re
import socket
import ssl
import sys
import time
import urllib.request
import uuid

import httpx

STATE_DIR = os.environ.get("STATE_DIR", "/state")
APP_ID = "com.example.doorstack"
PREVIEW_SECONDS = 3
MIN_PREVIEW_PACKETS = 20
SETTLE_SECONDS = 2


def read_env_file(path):
    values = {}
    with open(path) as handle:
        for line in handle:
            name, separator, value = line.strip().partition("=")
            if separator:
                values[name] = value
    return values


def md5(text):
    return hashlib.md5(text.encode()).hexdigest()


def header(message, name):
    match = re.search(r"^%s:\s*(.*?)\r?$" % re.escape(name), message, re.M | re.I)
    return match.group(1) if match else ""


def headers(message, name):
    return re.findall(r"^%s:\s*(.*?)\r?$" % re.escape(name), message, re.M | re.I)


class Failure(Exception):
    pass


class Phone:
    def __init__(self, server, local_ip, user, password, voip_token, platform="apple"):
        host, _, port = server.partition(":")
        self.server = (host, int(port or 5060))
        self.domain = host
        self.local_ip = local_ip
        self.user = user
        self.password = password
        self.voip_token = voip_token
        self.platform = platform
        self.remote_token = "%064x" % random.getrandbits(256)
        self.call_id = "%x@phone" % random.getrandbits(64)
        self.tag = "%x" % random.getrandbits(32)
        self.cseq = random.randint(1, 1000)
        self.sock = None
        self.port = 0

    def open(self):
        self.close()
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((self.local_ip, 0))
        self.sock.settimeout(0.2)
        self.port = self.sock.getsockname()[1]

    def close(self):
        if self.sock:
            self.sock.close()
            self.sock = None

    def contact(self):
        if self.platform == "firebase":
            return ("<sip:%s@%s:%d;app-id=%s;pn-type=firebase;pn-tok=%s;pn-silent=1;pn-timeout=0>"
                    % (self.user, self.local_ip, self.port, APP_ID, self.voip_token))
        return ("<sip:%s@%s:%d;app-id=%s;pn-type=apple;pn-tok=%s:remote&%s:voip;pn-silent=1;pn-timeout=0>"
                % (self.user, self.local_ip, self.port, APP_ID, self.remote_token, self.voip_token))

    def send(self, text):
        self.sock.sendto(text.encode(), self.server)

    def receive(self, seconds, accept):
        deadline = time.time() + seconds
        while time.time() < deadline:
            try:
                data = self.sock.recv(65535).decode(errors="replace")
            except socket.timeout:
                continue
            result = accept(data)
            if result is not None:
                return result
        return None

    def digest(self, challenge, method, uri):
        fields = dict((name, value.strip('"')) for name, value in
                      re.findall(r'(\w+)=("[^"]*"|[^,\s]+)', challenge))
        realm, nonce = fields.get("realm", ""), fields.get("nonce", "")
        ha1 = md5("%s:%s:%s" % (self.user, realm, self.password))
        ha2 = md5("%s:%s" % (method, uri))
        cnonce = "%x" % random.getrandbits(64)
        value = ('Digest username="%s", realm="%s", nonce="%s", uri="%s", algorithm=MD5'
                 % (self.user, realm, nonce, uri))
        if "auth" in fields.get("qop", ""):
            response = md5("%s:%s:00000001:%s:auth:%s" % (ha1, nonce, cnonce, ha2))
            value += ', qop=auth, nc=00000001, cnonce="%s"' % cnonce
        else:
            response = md5("%s:%s:%s" % (ha1, nonce, ha2))
        if "opaque" in fields:
            value += ', opaque="%s"' % fields["opaque"]
        return value + ', response="%s"' % response

    def register(self, expires):
        uri = "sip:%s" % self.domain
        authorization = ""
        for _ in range(2):
            self.cseq += 1
            cseq = self.cseq
            lines = [
                "REGISTER %s SIP/2.0" % uri,
                "Via: SIP/2.0/UDP %s:%d;branch=z9hG4bK%x;rport" % (self.local_ip, self.port,
                                                                    random.getrandbits(48)),
                "Max-Forwards: 70",
                "From: <sip:%s@%s>;tag=%s" % (self.user, self.domain, self.tag),
                "To: <sip:%s@%s>" % (self.user, self.domain),
                "Call-ID: %s" % self.call_id,
                "CSeq: %d REGISTER" % cseq,
                "Contact: %s;expires=%d" % (self.contact(), expires),
                "User-Agent: doorstack-phone-sim",
            ]
            if authorization:
                lines.append("Authorization: %s" % authorization)
            lines.append("Content-Length: 0")
            self.send("\r\n".join(lines) + "\r\n\r\n")

            def accept(data):
                match = re.match(r"SIP/2.0 (\d+)", data)
                if not match or ("CSeq: %d REGISTER" % cseq) not in data or int(match.group(1)) < 200:
                    return None
                return int(match.group(1)), data

            reply = self.receive(5, accept)
            if reply is None:
                raise Failure("no answer to REGISTER")
            status, data = reply
            if status == 200:
                return
            if status != 401 or authorization:
                raise Failure("REGISTER answered with %d" % status)
            authorization = self.digest(header(data, "WWW-Authenticate"), "REGISTER", uri)
        raise Failure("REGISTER was not accepted")


class Call:
    def __init__(self, phone, invite):
        self.phone = phone
        self.invite = invite
        self.tag = "%x" % random.getrandbits(32)
        self.cseq = random.randint(1, 1000)
        self.audio = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.audio.bind((phone.local_ip, 0))
        self.video = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.video.bind((phone.local_ip, 0))
        self.video.settimeout(0.2)
        self.bye = None

    def close(self):
        self.audio.close()
        self.video.close()

    def offer(self):
        return self.invite.split("\r\n\r\n", 1)[1] if "\r\n\r\n" in self.invite else ""

    def answer_sdp(self):
        offer = self.offer()
        video = re.search(r"^a=rtpmap:(\d+) H264/90000", offer, re.M)
        if not video or not re.search(r"^m=video [1-9]", offer, re.M):
            raise Failure("the INVITE offers no H.264 video")
        payload = video.group(1)
        fmtp = re.search(r"^a=fmtp:%s (.*?)\r?$" % payload, offer, re.M)
        audio = "0" if re.search(r"^m=audio \d+ \S+ .*\b0\b", offer, re.M) else "8"
        codec = "PCMU" if audio == "0" else "PCMA"
        lines = [
            "v=0",
            "o=- 1 1 IN IP4 %s" % self.phone.local_ip,
            "s=-",
            "c=IN IP4 %s" % self.phone.local_ip,
            "t=0 0",
            "m=audio %d RTP/AVP %s" % (self.audio.getsockname()[1], audio),
            "a=rtpmap:%s %s/8000" % (audio, codec),
            "a=recvonly",
            "m=video %d RTP/AVP %s" % (self.video.getsockname()[1], payload),
            "a=rtpmap:%s H264/90000" % payload,
        ]
        if fmtp:
            lines.append("a=fmtp:%s %s" % (payload, fmtp.group(1)))
        lines.append("a=recvonly")
        return "\r\n".join(lines) + "\r\n"

    def respond(self, status, body=""):
        to = header(self.invite, "To")
        lines = ["SIP/2.0 %s" % status]
        lines += ["Via: %s" % via for via in headers(self.invite, "Via")]
        lines += ["Record-Route: %s" % route for route in headers(self.invite, "Record-Route")]
        lines += [
            "From: %s" % header(self.invite, "From"),
            "To: %s;tag=%s" % (to, self.tag),
            "Call-ID: %s" % header(self.invite, "Call-ID"),
            "CSeq: %s" % header(self.invite, "CSeq"),
            "Contact: <sip:%s@%s:%d>" % (self.phone.user, self.phone.local_ip, self.phone.port),
        ]
        if body:
            lines.append("Content-Type: application/sdp")
        lines.append("Content-Length: %d" % len(body))
        self.phone.send("\r\n".join(lines) + "\r\n\r\n" + body)

    def count_video(self, seconds):
        packets = 0
        deadline = time.time() + seconds
        while time.time() < deadline:
            try:
                if len(self.video.recv(65535)) > 12:
                    packets += 1
            except socket.timeout:
                continue
        return packets

    def request(self, method, extra=(), body=""):
        self.cseq += 1
        cseq = self.cseq
        target = re.search(r"<([^>]+)>", header(self.invite, "Contact"))
        lines = [
            "%s %s SIP/2.0" % (method, target.group(1) if target else "sip:%s" % self.phone.domain),
            "Via: SIP/2.0/UDP %s:%d;branch=z9hG4bK%x;rport" % (self.phone.local_ip, self.phone.port,
                                                                random.getrandbits(48)),
            "Max-Forwards: 70",
            "From: %s;tag=%s" % (header(self.invite, "To"), self.tag),
            "To: %s" % header(self.invite, "From"),
            "Call-ID: %s" % header(self.invite, "Call-ID"),
            "CSeq: %d %s" % (cseq, method),
        ]
        lines += list(extra)
        lines.append("Content-Length: %d" % len(body))
        self.phone.send("\r\n".join(lines) + "\r\n\r\n" + body)

        def accept(data):
            match = re.match(r"SIP/2.0 (\d+)", data)
            if data.startswith("BYE "):
                self.bye = data
            if not match or ("CSeq: %d %s" % (cseq, method)) not in data or int(match.group(1)) < 200:
                return None
            return int(match.group(1))

        return self.phone.receive(5, accept)

    def wait_for_bye(self, seconds):
        def accept(data):
            return data if data.startswith("BYE ") else None

        bye = self.bye or self.phone.receive(seconds, accept)
        if bye is None:
            return False
        lines = ["SIP/2.0 200 OK"]
        lines += ["Via: %s" % via for via in headers(bye, "Via")]
        lines += [
            "From: %s" % header(bye, "From"),
            "To: %s" % header(bye, "To"),
            "Call-ID: %s" % header(bye, "Call-ID"),
            "CSeq: %s" % header(bye, "CSeq"),
            "Content-Length: 0",
        ]
        self.phone.send("\r\n".join(lines) + "\r\n\r\n")
        return True


def door(path, method="GET"):
    control = os.environ.get("DOOR_CONTROL", "127.0.0.1:8089")
    request = urllib.request.Request("http://%s%s" % (control, path), method=method)
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.loads(response.read())


def wait_until(seconds, check):
    deadline = time.time() + seconds
    while time.time() < deadline:
        result = check()
        if result:
            return result
        time.sleep(0.25)
    return None


def step(text):
    print("phone-sim: %s" % text, flush=True)


def run():
    secrets = read_env_file(os.path.join(STATE_DIR, "secrets.env"))
    user = os.environ.get("RESIDENT", "100")
    code = os.environ.get("DOOR_CODE", "1234")
    platform = os.environ.get("PUSH_PLATFORM", "apple")
    voip_token = "%064x" % random.getrandbits(256)
    if platform == "firebase":
        voip_token = "fcm%x-%x_%x" % (random.getrandbits(64), random.getrandbits(64), random.getrandbits(64))
    phone = Phone(os.environ.get("SIP_SERVER", "127.0.0.1:5060"), os.environ.get("LOCAL_IP", "127.0.0.1"),
                  user, secrets["RESIDENT_PASSWORD"], voip_token, platform)
    if platform == "firebase":
        mock = httpx.Client(timeout=5, base_url="http://%s" % os.environ.get("FCM_MOCK", "127.0.0.1:8444"))
        history = "/messages"
    else:
        context = ssl.create_default_context(cafile=os.path.join(STATE_DIR, "apns-mock.pem"))
        mock = httpx.Client(http2=True, verify=context, timeout=5,
                            base_url="https://%s" % os.environ.get("APNS_MOCK", "127.0.0.1:8443"))
        history = "/pushes"

    if not wait_until(30, lambda: door("/status")["registered"]):
        raise Failure("the door station did not register")
    step("door station is registered")

    phone.open()
    phone.register(3600)
    phone.close()
    step("registered with a push token, then went away like a suspended app")

    mock.delete(history)
    opens = door("/status")["door_opens"]
    if not door("/ring?to=%s" % user, "POST")["ringing"]:
        raise Failure("the door station did not ring")

    def pushed():
        return [push for push in mock.get(history).json() if push["token"] == voip_token]

    pushes = wait_until(10, pushed)
    if not pushes:
        raise Failure("no push arrived at the %s mock" % ("FCM" if platform == "firebase" else "APNs"))
    push = pushes[0]
    if platform == "firebase":
        payload = push["data"] or {}
        video = payload.get("video") == "1"
        if push["priority"] != "high" or payload.get("type") != "call":
            raise Failure("unexpected FCM message: %s" % json.dumps(push))
    else:
        payload = push["payload"] or {}
        video = payload.get("video") is True
        if push["topic"] != APP_ID + ".voip" or push["type"] != "voip":
            raise Failure("unexpected push headers: %s" % json.dumps(push))
    if not str(payload.get("from", "")).startswith("sip:door1@") or not video:
        raise Failure("unexpected push payload: %s" % json.dumps(payload))
    try:
        call_uuid = uuid.UUID(str(payload.get("uuid", "")))
    except ValueError:
        raise Failure("the push carries no call UUID: %s" % json.dumps(payload))
    step("push arrived: %s, from %s" % (push.get("topic") or "FCM data message", payload["from"]))

    phone.open()
    phone.register(3600)
    step("registered again, as a woken app does")

    invite = phone.receive(15, lambda data: data if data.startswith("INVITE ") else None)
    if invite is None:
        raise Failure("no INVITE after registering again")
    if header(invite, "X-Call-UUID").lower() != str(call_uuid):
        raise Failure("the INVITE's X-Call-UUID is not the push's UUID")
    step("the INVITE carries the UUID of the push")
    call = Call(phone, invite)
    try:
        sdp = call.answer_sdp()
        call.respond("100 Trying")
        call.respond("183 Session Progress", sdp)
        packets = call.count_video(PREVIEW_SECONDS)
        if packets < MIN_PREVIEW_PACKETS:
            raise Failure("only %d video packets before answering" % packets)
        step("preview before answering: %d H.264 packets in %d s" % (packets, PREVIEW_SECONDS))

        call.respond("200 OK", sdp)
        if phone.receive(5, lambda data: True if data.startswith("ACK ") else None) is None:
            raise Failure("no ACK after answering")
        time.sleep(SETTLE_SECONDS)
        for digit in code:
            status = call.request("INFO", ["Content-Type: application/dtmf-relay"],
                                  "Signal=%s\r\nDuration=160\r\n" % digit)
            if status != 200:
                raise Failure("INFO with DTMF %s answered with %s" % (digit, status))
            time.sleep(0.4)
        step("answered and sent the door code")

        if not wait_until(10, lambda: door("/status")["door_opens"] > opens):
            raise Failure("the door station did not open the door")
        if not call.wait_for_bye(10):
            raise Failure("the door station did not hang up after opening the door")
        step("door opened and the door station hung up")
    finally:
        call.close()

    phone.register(0)
    phone.close()


def main():
    try:
        run()
    except Failure as failure:
        print("phone-sim: FAIL (%s)" % failure, flush=True)
        return 1
    print("phone-sim: PASS", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
