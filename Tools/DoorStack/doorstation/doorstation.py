"""Door station simulator of the door stack.

Runs baresip as a SIP door station: it registers as door1, sends H.264 video from a test
picture and a tone, rings a resident on request and opens the door when the resident sends
the door code as DTMF, then hangs up as door stations do.

Environment:
  STATE_DIR        folder with secrets.env (DOOR_PASSWORD), default /state
  SIP_SERVER       host[:port] of the PBX, default 127.0.0.1:5060
  SIP_USER         account name, default door1
  SIP_LISTEN       address baresip listens on, default 0.0.0.0:5070
  RING_TARGET      resident rung by POST /ring without `to`, default 100
  RING_EVERY       seconds between automatic rings, default 0 (never)
  DOOR_CODE        DTMF that opens the door, default 1234
  HANGUP_AFTER_OPEN  seconds from opening the door to hanging up, default 1
  HTTP_LISTEN      host:port of the control endpoint, default 127.0.0.1:8089

POST /ring[?to=101] rings, POST /hangup ends the call, GET /status reports the state.
"""

import asyncio
import json
import os
import sys
import urllib.parse

STATE_DIR = os.environ.get("STATE_DIR", "/state")
CONFIG_DIR = "/tmp/doorstation"
CONTROL_PORT = 4444
MODULES = [
    "g711", "opus", "avcodec", "avformat", "swscale", "ausine", "aubridge", "fakevideo",
    "stun", "ice", "ctrl_tcp",
]


def log(message):
    print("doorstation: %s" % message, flush=True)


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


def module_path():
    for base in ("/opt/baresip/lib", "/usr/local/lib", "/usr/lib"):
        for root, _, files in os.walk(base):
            if "avcodec.so" in files and "baresip" in root:
                return root
    raise RuntimeError("baresip modules not found")


def write_config(server, user, password):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    lines = [
        "sip_listen\t\t%s" % os.environ.get("SIP_LISTEN", "0.0.0.0:5070"),
        "call_max_calls\t\t1",
        "audio_player\t\taubridge,doorstation",
        "audio_source\t\tausine,440",
        "audio_alert\t\taubridge,alert",
        "video_source\t\tavformat,/media/door.mp4",
        "video_display\t\tfakevideo,nil",
        "video_size\t\t640x480",
        "video_bitrate\t\t500000",
        "video_fps\t\t15",
        "rtp_ports\t\t30000-30100",
        "ctrl_tcp_listen\t\t127.0.0.1:%d" % CONTROL_PORT,
        "module_path\t\t%s" % module_path(),
    ]
    lines += ["module\t\t\t%s.so" % name for name in MODULES]
    lines += ["module_app\t\taccount.so", "module_app\t\tmenu.so"]
    with open(os.path.join(CONFIG_DIR, "config"), "w") as handle:
        handle.write("\n".join(lines) + "\n")
    account = ("<sip:%s@%s;transport=udp>;auth_pass=%s;regint=300;answermode=auto;"
               "audio_codecs=opus/48000/2,PCMU;video_codecs=H264\n" % (user, server, password))
    with open(os.path.join(CONFIG_DIR, "accounts"), "w") as handle:
        handle.write(account)
    os.chmod(os.path.join(CONFIG_DIR, "accounts"), 0o600)


class DoorStation:
    def __init__(self):
        self.server = os.environ.get("SIP_SERVER", "127.0.0.1:5060")
        self.user = os.environ.get("SIP_USER", "door1")
        self.target = os.environ.get("RING_TARGET", "100")
        self.code = os.environ.get("DOOR_CODE", "1234")
        self.hangup_delay = float(os.environ.get("HANGUP_AFTER_OPEN", "1"))
        self.registered = False
        self.state = "idle"
        self.digits = ""
        self.door_opens = 0
        self.rings = 0
        self.writer = None

    async def command(self, name, params=""):
        if self.writer is None:
            return False
        data = json.dumps({"command": name, "params": params, "token": name}).encode()
        self.writer.write(b"%d:%s," % (len(data), data))
        await self.writer.drain()
        return True

    async def ring(self, target=None):
        if self.state != "idle":
            return False
        self.rings += 1
        uri = "sip:%s@%s" % (target or self.target, self.server)
        log("ringing %s" % uri)
        return await self.command("dial", uri)

    async def open_door(self):
        self.door_opens += 1
        log("door opened (%d)" % self.door_opens)
        await asyncio.sleep(self.hangup_delay)
        await self.command("hangup")

    def handle(self, event):
        kind = event.get("type", "")
        if kind == "REGISTER_OK":
            if not self.registered:
                log("registered as %s at %s" % (self.user, self.server))
            self.registered = True
        elif kind in ("REGISTER_FAIL", "UNREGISTERING"):
            self.registered = False
            log("registration: %s %s" % (kind, event.get("param", "")))
        elif kind in ("CALL_INCOMING", "CALL_RINGING", "CALL_PROGRESS"):
            self.state = "ringing"
        elif kind == "CALL_ESTABLISHED":
            self.state = "in call"
            self.digits = ""
            log("call with %s established" % event.get("peeruri", ""))
        elif kind == "CALL_CLOSED":
            self.state = "idle"
            self.digits = ""
            log("call closed: %s" % event.get("param", ""))
        elif kind == "CALL_DTMF_START":
            self.digits = (self.digits + event.get("param", ""))[-32:]
            log("DTMF %s" % event.get("param", ""))
            if self.code and self.digits.endswith(self.code):
                self.digits = ""
                asyncio.ensure_future(self.open_door())

    async def control(self):
        reader = None
        for _ in range(100):
            try:
                reader, self.writer = await asyncio.open_connection("127.0.0.1", CONTROL_PORT)
                break
            except OSError:
                await asyncio.sleep(0.2)
        if reader is None:
            raise RuntimeError("baresip's control port did not open")
        while True:
            length = (await reader.readuntil(b":"))[:-1]
            data = await reader.readexactly(int(length) + 1)
            message = json.loads(data[:-1])
            if message.get("event"):
                self.handle(message)

    async def http_client(self, reader, writer):
        try:
            request = (await reader.readline()).decode(errors="replace").split()
            while (await reader.readline()).strip():
                pass
            method = request[0] if request else ""
            url = urllib.parse.urlsplit(request[1] if len(request) > 1 else "")
            query = urllib.parse.parse_qs(url.query)
            status = 200
            if method == "POST" and url.path == "/ring":
                body = {"ringing": await self.ring(query.get("to", [None])[0])}
            elif method == "POST" and url.path == "/hangup":
                body = {"hangup": await self.command("hangup")}
            elif method == "GET" and url.path == "/status":
                body = {"registered": self.registered, "state": self.state, "rings": self.rings,
                        "door_opens": self.door_opens}
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

    async def ring_periodically(self, interval):
        while True:
            await asyncio.sleep(interval)
            if self.registered:
                await self.ring()

    async def run(self):
        password = read_env_file(os.path.join(STATE_DIR, "secrets.env")).get("DOOR_PASSWORD", "")
        write_config(self.server, self.user, password)
        baresip = await asyncio.create_subprocess_exec("baresip", "-4", "-f", CONFIG_DIR,
                                                       stdin=asyncio.subprocess.DEVNULL)
        host, _, port = os.environ.get("HTTP_LISTEN", "127.0.0.1:8089").rpartition(":")
        server = await asyncio.start_server(self.http_client, host, int(port))
        log("control on http://%s:%s, door code %s" % (host, port, "set" if self.code else "not set"))
        tasks = [asyncio.ensure_future(self.control()), asyncio.ensure_future(baresip.wait())]
        interval = float(os.environ.get("RING_EVERY", "0"))
        if interval > 0:
            tasks.append(asyncio.ensure_future(self.ring_periodically(interval)))
        async with server:
            done, _ = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for task in done:
            if task.exception():
                log("stopped: %s" % task.exception())
        if baresip.returncode is None:
            baresip.terminate()
        return 1


if __name__ == "__main__":
    try:
        sys.exit(asyncio.run(DoorStation().run()))
    except KeyboardInterrupt:
        sys.exit(0)
