"""Rings the sample app like a door station, for the screenshots CI takes of it.

Waits until TRIGGER exists, reads the Contact the app registered from the registrar's trace,
and sends an INVITE from sip:bob@HOST through the registrar, which passes it to the app on its
TLS connection. Acknowledges the app's final answer. With MESSAGE_TRIGGER, then waits until
that file exists and sends the app two SIP MESSAGEs from the same address, as a door station
writing during a call, and exits.

Usage: ring.py HOST REGISTRAR_PORT LOCAL_PORT TRACE TRIGGER [MESSAGE_TRIGGER]
The registrar must run with REGISTRAR_PEER=HOST:LOCAL_PORT so that it returns responses here.
"""

import os
import random
import re
import socket
import sys
import time

WAIT_FOR_TRIGGER = 900
WAIT_FOR_ANSWER = 120
MESSAGES = (
    "Parcel for you, I will leave it at the door.",
    "Could you come down to sign?",
)


def log(message):
    print("ring: %s" % message, flush=True)


def registered_contact(trace_path):
    try:
        with open(trace_path, errors="replace") as handle:
            trace = handle.read()
    except OSError:
        return None
    contacts = re.findall(r"^REGISTER .*?^Contact:\s*<([^>]+)>(.*?)$", trace, re.M | re.S)
    for uri, params in reversed(contacts):
        if "alice@" in uri and "expires=0" not in params:
            return uri
    return None


def wait_for(path, seconds):
    deadline = time.time() + seconds
    while not os.path.exists(path):
        if time.time() > deadline:
            return False
        time.sleep(0.2)
    return True


def send_messages(sip, host, local_port, registrar, contact):
    for number, text in enumerate(MESSAGES, start=1):
        body = text.encode()
        request = "\r\n".join([
            "MESSAGE %s SIP/2.0" % contact,
            "Via: SIP/2.0/UDP %s:%s;branch=z9hG4bK-msg-%x;rport" % (host, local_port, random.getrandbits(48)),
            "Max-Forwards: 70",
            "From: \"Front door\" <sip:bob@%s>;tag=%x" % (host, random.getrandbits(32)),
            "To: <sip:alice@%s>" % host,
            "Call-ID: %x@door-message" % random.getrandbits(64),
            "CSeq: %d MESSAGE" % number,
            "Content-Type: text/plain",
            "Content-Length: %d" % len(body),
            "", ""]).encode() + body
        sip.sendto(request, registrar)
        log("MESSAGE %d sent" % number)
        deadline = time.time() + 10
        while time.time() < deadline:
            try:
                data = sip.recv(65535).decode(errors="replace")
            except socket.timeout:
                continue
            status = data.split("\r\n", 1)[0]
            if re.search(r"^CSeq:\s*%d MESSAGE" % number, data, re.M | re.I):
                log("MESSAGE %d: %s" % (number, status))
                break
        time.sleep(1.5)


def main():
    host, registrar_port, local_port, trace_path, trigger = sys.argv[1:6]
    message_trigger = sys.argv[6] if len(sys.argv) > 6 else None
    registrar = (host, int(registrar_port))
    if not wait_for(trigger, WAIT_FOR_TRIGGER):
        log("no trigger")
        return 1
    contact = registered_contact(trace_path)
    if contact is None:
        log("no registration of alice in %s" % trace_path)
        return 1

    sip = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sip.bind((host, int(local_port)))
    sip.settimeout(1)
    rtp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    rtp.bind((host, 0))
    branch = "z9hG4bK-door-%x" % random.getrandbits(48)
    call_id = "%x@door" % random.getrandbits(64)
    tag = "%x" % random.getrandbits(32)
    sdp = ("v=0\r\no=- 1 1 IN IP4 %s\r\ns=-\r\nc=IN IP4 %s\r\nt=0 0\r\n"
           "m=audio %d RTP/AVP 0\r\na=rtpmap:0 PCMU/8000\r\na=sendrecv\r\n"
           % (host, host, rtp.getsockname()[1]))
    common = [
        "Via: SIP/2.0/UDP %s:%s;branch=%s;rport" % (host, local_port, branch),
        "Max-Forwards: 70",
        "From: \"Front door\" <sip:bob@%s>;tag=%s" % (host, tag),
    ]
    invite = "\r\n".join(["INVITE %s SIP/2.0" % contact] + common + [
        "To: <sip:alice@%s>" % host,
        "Call-ID: %s" % call_id,
        "CSeq: 1 INVITE",
        "Contact: <sip:bob@%s:%s>" % (host, local_port),
        "Content-Type: application/sdp",
        "Content-Length: %d" % len(sdp),
        "", sdp])
    sip.sendto(invite.encode(), registrar)
    log("INVITE sent to %s" % contact)

    deadline = time.time() + WAIT_FOR_ANSWER
    while time.time() < deadline:
        try:
            data = sip.recv(65535).decode(errors="replace")
        except socket.timeout:
            continue
        status = data.split("\r\n", 1)[0]
        log(status)
        match = re.match(r"SIP/2.0 (\d+)", status)
        if not match or int(match.group(1)) < 200:
            continue
        to = re.search(r"^To:\s*(.*?)\r?$", data, re.M | re.I)
        ack = "\r\n".join(["ACK %s SIP/2.0" % contact] + common + [
            "To: %s" % (to.group(1) if to else "<sip:alice@%s>" % host),
            "Call-ID: %s" % call_id,
            "CSeq: 1 ACK",
            "Content-Length: 0",
            "", ""])
        sip.sendto(ack.encode(), registrar)
        log("ACK sent")
        if message_trigger:
            if not wait_for(message_trigger, WAIT_FOR_TRIGGER):
                log("no message trigger")
                return 1
            send_messages(sip, host, local_port, registrar, contact)
        return 0
    log("no final answer")
    return 1


if __name__ == "__main__":
    sys.exit(main())
