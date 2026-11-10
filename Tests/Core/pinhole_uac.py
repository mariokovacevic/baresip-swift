"""Calls a receive-only early media preview and counts the RTP packets it sends.

A media relay such as rtpengine forwards the caller's media only after it has
seen a packet from the callee. This minimal UAC sends an INVITE with a plain
PCMU offer, waits for the 183 answer and counts every UDP packet that arrives
on its RTP port before it cancels the call. It sends no RTP itself, so every
packet counted comes from the callee's NAT pinhole.

Usage: pinhole_uac.py HOST CALLEE_PORT
Exits 0 when the answer is recvonly and at least MIN_PACKETS RTP packets with
an empty payload arrived, else 1.
"""

import random
import re
import socket
import sys
import time

MIN_PACKETS = 3
RTP_HEADER = 12


def main():
    host, callee_port = sys.argv[1], int(sys.argv[2])
    sip = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sip.bind((host, 0))
    rtp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    rtp.bind((host, 0))
    sip.settimeout(0.2)
    rtp.settimeout(0.05)
    sip_port, rtp_port = sip.getsockname()[1], rtp.getsockname()[1]

    call_id = "%x@pinhole" % random.getrandbits(64)
    tag = "%x" % random.getrandbits(32)
    branch = "z9hG4bK%x" % random.getrandbits(48)
    uri = "sip:bob@%s:%d" % (host, callee_port)
    sdp = ("v=0\r\no=- 1 1 IN IP4 %s\r\ns=-\r\nc=IN IP4 %s\r\nt=0 0\r\n"
           "m=audio %d RTP/AVP 0\r\na=rtpmap:0 PCMU/8000\r\na=sendrecv\r\n"
           % (host, host, rtp_port))

    def request(method, cseq, body=""):
        lines = [
            "%s %s SIP/2.0" % (method, uri),
            "Via: SIP/2.0/UDP %s:%d;branch=%s;rport" % (host, sip_port, branch),
            "Max-Forwards: 70",
            "From: <sip:alice@%s>;tag=%s" % (host, tag),
            "To: <%s>" % uri,
            "Call-ID: %s" % call_id,
            "CSeq: %d %s" % (cseq, method),
            "Contact: <sip:alice@%s:%d>" % (host, sip_port),
            "X-Device-ID: 4711",
        ]
        if body:
            lines.append("Content-Type: application/sdp")
        lines.append("Content-Length: %d" % len(body))
        sip.sendto(("\r\n".join(lines) + "\r\n\r\n" + body).encode(),
                   (host, callee_port))

    request("INVITE", 1, sdp)

    answer = None
    deadline = time.time() + 15
    while time.time() < deadline and answer is None:
        try:
            data = sip.recv(65535).decode(errors="replace")
        except socket.timeout:
            continue
        if data.startswith("SIP/2.0 183") and "\r\n\r\n" in data:
            answer = data.split("\r\n\r\n", 1)[1]
    if answer is None:
        print("pinhole: no 183 with SDP")
        return 1

    direction = re.search(r"a=(sendrecv|sendonly|recvonly|inactive)", answer)
    packets = empty = 0
    end = time.time() + 2
    while time.time() < end:
        try:
            data = rtp.recv(2048)
        except socket.timeout:
            continue
        packets += 1
        if len(data) == RTP_HEADER and data[0] >> 6 == 2:
            empty += 1

    request("CANCEL", 1)
    time.sleep(0.3)

    ok = direction and direction.group(1) == "recvonly" and empty >= MIN_PACKETS
    print("pinhole: %s (answer %s, %d packets, %d empty RTP)"
          % ("PASS" if ok else "FAIL",
             direction.group(1) if direction else "?", packets, empty))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
