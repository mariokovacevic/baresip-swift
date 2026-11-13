"""Stand-in for Firebase Cloud Messaging, for running the door stack without Google.

Accepts every POST /v1/projects/<project>/messages:send like the FCM HTTP v1 API, over plain
HTTP. The messages it received are listed by GET /messages and forgotten by DELETE /messages.

Environment:
  MOCK_LISTEN   host:port, default 127.0.0.1:8444
"""

import asyncio
import json
import os
import re
import sys
import uuid

HISTORY = 200
SEND_PATH = re.compile(r"^/v1/projects/([^/]+)/messages:send$")


def log(message):
    print("fcm-mock: %s" % message, flush=True)


class Mock:
    def __init__(self):
        self.messages = []

    async def client(self, reader, writer):
        try:
            request = (await reader.readline()).decode(errors="replace").split()
            headers = {}
            while True:
                line = (await reader.readline()).decode(errors="replace").strip()
                if not line:
                    break
                name, _, value = line.partition(":")
                headers[name.strip().lower()] = value.strip()
            length = int(headers.get("content-length", "0") or 0)
            body = await reader.readexactly(length) if length else b""
            method, path = (request + ["", ""])[:2]
            status, data = self.handle(method, path, headers, body)
            payload = json.dumps(data).encode()
            writer.write(("HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\n"
                          "Connection: close\r\n\r\n" % (status, "OK" if status == 200 else "Error",
                                                         len(payload))).encode() + payload)
            await writer.drain()
        except (OSError, ValueError, asyncio.IncompleteReadError):
            pass
        finally:
            writer.close()

    def handle(self, method, path, headers, body):
        match = SEND_PATH.match(path)
        if method == "POST" and match:
            try:
                message = json.loads(body or b"{}").get("message", {})
            except ValueError:
                return 400, {"error": {"status": "INVALID_ARGUMENT"}}
            if not message.get("token"):
                return 400, {"error": {"status": "INVALID_ARGUMENT", "message": "no token"}}
            entry = {
                "project": match.group(1),
                "token": message["token"],
                "data": message.get("data", {}),
                "priority": message.get("android", {}).get("priority", ""),
                "signed": "authorization" in headers,
            }
            self.messages.append(entry)
            del self.messages[:-HISTORY]
            log("message for %s, project %s" % (entry["token"][:8] + "...", entry["project"]))
            return 200, {"name": "projects/%s/messages/%s" % (match.group(1), uuid.uuid4())}
        if method == "GET" and path == "/messages":
            return 200, self.messages
        if method == "DELETE" and path == "/messages":
            del self.messages[:]
            return 200, []
        return 404, {"error": {"status": "NOT_FOUND"}}


async def main():
    host, _, port = os.environ.get("MOCK_LISTEN", "127.0.0.1:8444").rpartition(":")
    server = await asyncio.start_server(Mock().client, host, int(port))
    log("listening on http://%s:%s" % (host, port))
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
