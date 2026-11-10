"""UDP registrar that answers every REGISTER after a delay.

Used to check what the client does while a REGISTER is unanswered. It keeps
the bindings as a registrar does, one per Contact URI, added by a REGISTER
and removed by one with expires=0, in the order the requests arrive. A
request is a retransmission only when its top Via is the same (RFC 3261,
17.2.3), so a request that is sent again from another local address counts
as a new one.

Usage: slow_registrar.py HOST PORT FINAL_TOKEN
Environment: REGISTRAR_DELAY (seconds, default 0.3),
REGISTRAR_IDLE_TIMEOUT (seconds, default 5).
The last REGISTER with expires=0 is the client unregistering at the end of
the test. Exits 0 when the binding it removes existed until then and carries
FINAL_TOKEN, else 1.
"""

import os
import re
import select
import socket
import sys
import time


def header(msg, name):
    match = re.search(r"^%s:\s*(.*?)\r?$" % re.escape(name), msg, re.M | re.I)
    return match.group(1) if match else ""


def response(req, expires):
    to = header(req, "To")
    if ";tag=" not in to:
        to += ";tag=slow"
    contact = re.sub(r";expires=\d+", "", header(req, "Contact"))
    return ("SIP/2.0 200 OK\r\nVia: %s\r\nFrom: %s\r\nTo: %s\r\nCall-ID: %s\r\n"
            "CSeq: %s\r\nContact: %s;expires=%s\r\nContent-Length: 0\r\n\r\n"
            % (header(req, "Via"), header(req, "From"), to, header(req, "Call-ID"),
               header(req, "CSeq"), contact, expires))


def main():
    host, port, final_token = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    delay = float(os.environ.get("REGISTRAR_DELAY", "0.3"))
    idle = float(os.environ.get("REGISTRAR_IDLE_TIMEOUT", "5"))
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((host, port))

    pending = {}
    answered = {}
    bindings = set()
    last_unregister = None
    count = 0
    last_activity = time.time()

    while pending or time.time() - last_activity < idle:
        now = time.time()
        for key in [k for k, (due, _, _) in pending.items() if due <= now]:
            _, data, addr = pending.pop(key)
            sock.sendto(data, addr)
            answered[key] = data
            last_activity = now

        readable, _, _ = select.select([sock], [], [], 0.02)
        if not readable:
            continue
        data, addr = sock.recvfrom(65535)
        req = data.decode(errors="replace")
        last_activity = time.time()
        if not req.startswith("REGISTER "):
            continue

        key = header(req, "Via")
        if key in answered:
            sock.sendto(answered[key], addr)
            continue
        if key in pending:
            continue
        count += 1

        contact = header(req, "Contact")
        match = re.search(r";expires=(\d+)", contact)
        expires = match.group(1) if match else (header(req, "Expires") or "3600")
        uri = contact.split(">")[0]
        if expires == "0":
            last_unregister = (uri, uri in bindings)
            bindings.discard(uri)
        else:
            bindings.add(uri)
        pending[key] = (time.time() + delay, response(req, expires).encode(), addr)

    failure = None
    if last_unregister is None:
        failure = "the client did not unregister"
    elif not last_unregister[1]:
        failure = "the registrar had lost the binding of the client"
    elif final_token not in last_unregister[0]:
        failure = "the binding does not carry the parameters set last"

    print("slow registrar: %d REGISTER: %s"
          % (count, "PASS" if failure is None else "FAIL (%s)" % failure))
    return 0 if failure is None else 1


if __name__ == "__main__":
    sys.exit(main())
