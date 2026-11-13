"""Stand-in for Apple's push service, for running the door stack without a phone.

Speaks HTTP/2 over TLS like APNs and accepts every POST /3/device/<token>. The pushes it
received are listed by GET /pushes and forgotten by DELETE /pushes.

Environment:
  STATE_DIR     folder with apns-mock.pem and apns-mock.key, default /state
  MOCK_LISTEN   host:port, default 127.0.0.1:8443
"""

import asyncio
import json
import os
import ssl
import sys
import uuid

import h2.config
import h2.connection
import h2.events

STATE_DIR = os.environ.get("STATE_DIR", "/state")
HISTORY = 200
DEVICE_PATH = "/3/device/"


def log(message):
    print("apns-mock: %s" % message, flush=True)


class Connection(asyncio.Protocol):
    pushes = []

    def __init__(self):
        self.h2 = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=False))
        self.transport = None
        self.streams = {}

    def connection_made(self, transport):
        self.transport = transport
        self.h2.initiate_connection()
        self.transport.write(self.h2.data_to_send())

    def data_received(self, data):
        try:
            events = self.h2.receive_data(data)
        except Exception:
            self.transport.close()
            return
        for event in events:
            if isinstance(event, h2.events.RequestReceived):
                headers = {}
                for name, value in event.headers:
                    name = name.decode() if isinstance(name, bytes) else name
                    value = value.decode() if isinstance(value, bytes) else value
                    headers[name] = value
                self.streams[event.stream_id] = (headers, bytearray())
            elif isinstance(event, h2.events.DataReceived):
                if event.stream_id in self.streams:
                    self.streams[event.stream_id][1].extend(event.data)
                self.h2.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
            elif isinstance(event, h2.events.StreamEnded):
                self.respond(event.stream_id)
        self.transport.write(self.h2.data_to_send())

    def respond(self, stream_id):
        headers, body = self.streams.pop(stream_id, ({}, bytearray()))
        method = headers.get(":method", "")
        path = headers.get(":path", "")
        extra = []
        if method == "POST" and path.startswith(DEVICE_PATH):
            try:
                payload = json.loads(bytes(body) or b"{}")
            except ValueError:
                payload = None
            push = {
                "token": path[len(DEVICE_PATH):],
                "topic": headers.get("apns-topic", ""),
                "type": headers.get("apns-push-type", ""),
                "priority": headers.get("apns-priority", ""),
                "signed": "authorization" in headers,
                "payload": payload,
            }
            type(self).pushes.append(push)
            del type(self).pushes[:-HISTORY]
            log("%s push for %s, topic %s" % (push["type"], push["token"][:8] + "...", push["topic"]))
            status, data = 200, b""
            extra = [("apns-id", str(uuid.uuid4()))]
        elif method == "GET" and path == "/pushes":
            status, data = 200, json.dumps(type(self).pushes).encode()
        elif method == "DELETE" and path == "/pushes":
            del type(self).pushes[:]
            status, data = 200, b"[]"
        else:
            status, data = 404, json.dumps({"reason": "BadPath"}).encode()
        response = [(":status", str(status)), ("content-length", str(len(data)))] + extra
        if data:
            response.append(("content-type", "application/json"))
        self.h2.send_headers(stream_id, response, end_stream=not data)
        if data:
            self.h2.send_data(stream_id, data, end_stream=True)


async def main():
    host, _, port = os.environ.get("MOCK_LISTEN", "127.0.0.1:8443").rpartition(":")
    context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    context.load_cert_chain(os.path.join(STATE_DIR, "apns-mock.pem"), os.path.join(STATE_DIR, "apns-mock.key"))
    context.set_alpn_protocols(["h2"])
    server = await asyncio.get_running_loop().create_server(Connection, host, int(port), ssl=context)
    log("listening on https://%s:%s" % (host, port))
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
