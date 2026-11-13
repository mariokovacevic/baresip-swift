"""Scripted SIP peer for the security stages of the core tests.

Plays the other side of a call against bsk_test_security, or against
bsk_test_call in the peer role for require-timer, over UDP and checks the
responses.

Usage: sip_peer.py SCENARIO HOST CALLEE_PORT
Scenarios: refer-ringing, fake-replace, reentrant, remove-live, stop-live,
require-timer, cancel-elsewhere.
Exits 0 when the callee behaved as expected, else 1.
"""

import random
import re
import socket
import sys
import time


class Peer:
    def __init__(self, host, callee_port):
        self.host = host
        self.callee = (host, callee_port)
        self.sip = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sip.bind((host, 0))
        self.sip.settimeout(0.2)
        self.rtp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.rtp.bind((host, 0))
        self.port = self.sip.getsockname()[1]
        self.uri = "sip:bob@%s:%d" % (host, callee_port)
        self.new_dialog()

    def new_dialog(self):
        self.call_id = "%x@peer" % random.getrandbits(64)
        self.tag = "%x" % random.getrandbits(32)
        self.to_tag = None
        self.cseq = 0

    def sdp(self):
        return ("v=0\r\no=- 1 1 IN IP4 %s\r\ns=-\r\nc=IN IP4 %s\r\nt=0 0\r\n"
                "m=audio %d RTP/AVP 0\r\na=rtpmap:0 PCMU/8000\r\na=sendrecv\r\n"
                % (self.host, self.host, self.rtp.getsockname()[1]))

    def request(self, method, headers=(), body="", cseq=None, branch=None):
        if cseq is None:
            self.cseq += 1
            cseq = self.cseq
        branch = branch or "z9hG4bK%x" % random.getrandbits(48)
        to = "<%s>" % self.uri
        if self.to_tag:
            to += ";tag=%s" % self.to_tag
        lines = [
            "%s %s SIP/2.0" % (method, self.uri),
            "Via: SIP/2.0/UDP %s:%d;branch=%s;rport" % (self.host, self.port, branch),
            "Max-Forwards: 70",
            "From: <sip:alice@%s>;tag=%s" % (self.host, self.tag),
            "To: %s" % to,
            "Call-ID: %s" % self.call_id,
            "CSeq: %d %s" % (cseq, method),
            "Contact: <sip:alice@%s:%d>" % (self.host, self.port),
        ]
        lines.extend(headers)
        if body:
            lines.append("Content-Type: application/sdp")
        lines.append("Content-Length: %d" % len(body))
        self.sip.sendto(("\r\n".join(lines) + "\r\n\r\n" + body).encode(), self.callee)
        return branch

    def reply_ok(self, data):
        head = data.split("\r\n\r\n", 1)[0].split("\r\n")
        kept = [line for line in head[1:]
                if line.lower().startswith(("via:", "from:", "to:", "call-id:", "cseq:"))]
        self.sip.sendto(("\r\n".join(["SIP/2.0 200 OK"] + kept + ["Content-Length: 0"])
                         + "\r\n\r\n").encode(), self.callee)

    def receive(self, seconds, accept):
        deadline = time.time() + seconds
        while time.time() < deadline:
            try:
                data = self.sip.recv(65535).decode(errors="replace")
            except socket.timeout:
                continue
            if data.startswith("BYE ") or data.startswith("NOTIFY "):
                self.reply_ok(data)
            tag = re.search(r"^To:.*;tag=([^;\r\n]+)", data, re.M | re.I)
            if tag and data.startswith("SIP/2.0") and self.call_id in data:
                self.to_tag = tag.group(1)
            result = accept(data)
            if result is not None:
                return result
        return None

    def status(self, seconds, method, wanted):
        def accept(data):
            match = re.match(r"SIP/2.0 (\d+)", data)
            if not match or self.call_id not in data:
                return None
            if not re.search(r"^CSeq: \d+ %s" % method, data, re.M | re.I):
                return None
            code = int(match.group(1))
            return code if wanted(code) else None
        return self.receive(seconds, accept)

    def invite(self, headers=()):
        self.invite_cseq = self.cseq + 1
        self.invite_branch = self.request("INVITE", headers, self.sdp())

    def ack(self, final_error=False):
        self.request("ACK", cseq=self.invite_cseq,
                     branch=self.invite_branch if final_error else None)

    def cancel(self, headers=()):
        saved, self.to_tag = self.to_tag, None
        self.request("CANCEL", headers, cseq=self.invite_cseq, branch=self.invite_branch)
        self.to_tag = saved

    def send_rtp(self, answer, packets):
        port = re.search(r"^m=audio (\d+)", answer, re.M)
        addr = re.search(r"^c=IN IP4 ([0-9.]+)", answer, re.M)
        if not port or not addr:
            return False
        ssrc = random.getrandbits(32)
        for seq in range(packets):
            header = bytes([0x80, 0x00, seq >> 8 & 0xff, seq & 0xff])
            header += (seq * 160).to_bytes(4, "big") + ssrc.to_bytes(4, "big")
            self.rtp.sendto(header + b"\xff" * 160, (addr.group(1), int(port.group(1))))
            time.sleep(0.02)
        return True

    def bye_from_callee(self, seconds):
        return self.receive(seconds, lambda data: True if data.startswith("BYE ") else None)


def establish(peer):
    peer.invite()
    if peer.status(10, "INVITE", lambda code: code == 200) != 200:
        return False
    peer.ack()
    return True


def refer_ringing(peer):
    peer.invite()
    if peer.status(10, "INVITE", lambda code: code == 180) != 180:
        return "no 180"
    peer.request("REFER", ["Refer-To: <sip:mallory@%s:5099>" % peer.host])
    code = peer.status(3, "REFER", lambda code: code >= 200)
    if code != 403:
        return "REFER answered with %s" % code
    if peer.status(10, "INVITE", lambda code: code == 200) != 200:
        return "the call did not answer after the REFER"
    peer.ack()
    time.sleep(0.5)
    peer.request("BYE")
    if peer.status(3, "BYE", lambda code: code >= 200) != 200:
        return "BYE not accepted"
    return None


def fake_replace(peer):
    if not establish(peer):
        return "first call not answered"
    time.sleep(0.5)
    old = "%s;to-tag=%s;from-tag=%s" % (peer.call_id, peer.to_tag, peer.tag)
    peer.request("BYE", ['Reason: SIP;cause=200;text="%s replaced"' % old])
    if peer.status(3, "BYE", lambda code: code >= 200) != 200:
        return "BYE not accepted"

    peer.new_dialog()
    peer.invite(["Replaces: unknown@peer;to-tag=a;from-tag=b"])
    if peer.status(3, "INVITE", lambda code: code >= 300) != 481:
        return "an unknown Replaces was not answered with 481"
    peer.ack(final_error=True)

    peer.new_dialog()
    peer.invite()
    if peer.status(10, "INVITE", lambda code: code == 180) != 180:
        return "second call does not ring"
    if peer.status(2.5, "INVITE", lambda code: code == 200) == 200:
        return "second call was answered without the user"
    peer.cancel()
    peer.status(3, "INVITE", lambda code: code == 487)
    peer.ack(final_error=True)
    return None


def reentrant(peer):
    peer.invite()
    code = peer.status(10, "INVITE", lambda code: code >= 300)
    if code != 486:
        return "first call answered with %s" % code
    peer.ack(final_error=True)

    peer.new_dialog()
    if not establish(peer):
        return "second call not answered"
    time.sleep(0.5)
    peer.request("BYE")
    if peer.status(3, "BYE", lambda code: code >= 200) != 200:
        return "BYE not accepted"
    return None


def final_response(peer, seconds):
    def accept(data):
        match = re.match(r"SIP/2.0 (\d+)", data)
        if not match or peer.call_id not in data or int(match.group(1)) < 200:
            return None
        return data if re.search(r"^CSeq: \d+ INVITE", data, re.M | re.I) else None
    return peer.receive(seconds, accept)


def require_timer(peer):
    peer.invite(("Supported: timer", "Session-Expires: 30"))
    answer = final_response(peer, 10)
    if not answer or not answer.startswith("SIP/2.0 422"):
        return "an interval below Min-SE was not answered with 422"
    peer.ack(final_error=True)
    if not re.search(r"^Min-SE: 90\r?$", answer, re.M | re.I):
        return "the 422 names no Min-SE of 90"

    peer.new_dialog()
    peer.invite(("Supported: timer", "Require: timer", "Session-Expires: 90;refresher=uac"))
    answer = final_response(peer, 10)
    if not answer or not answer.startswith("SIP/2.0 200"):
        return "an INVITE that requires timers was not answered with 200"
    peer.ack()
    if not re.search(r"^Session-Expires: 90;refresher=uac\r?$", answer, re.M | re.I):
        return "the 200 has no Session-Expires with the caller as refresher"
    if not re.search(r"^Require:.*\btimer\b", answer, re.M | re.I):
        return "the 200 does not require timer"
    if not peer.send_rtp(answer, 50):
        return "the 200 has no audio address"
    peer.request("BYE")
    if peer.status(5, "BYE", lambda code: code == 200) != 200:
        return "BYE not answered"
    return None


def cancel_elsewhere(peer):
    reasons = (
        ('Reason: SIP;cause=200;text="Call completed elsewhere"',),
        ('Reason: SIP ;cause=603 ;text="Decline"',),
        ('Reason: SIP;cause=487;text="ORIGINATOR_CANCEL"',),
        (),
    )
    for headers in reasons:
        peer.new_dialog()
        peer.invite()
        if peer.status(10, "INVITE", lambda code: code == 180) != 180:
            return "the INVITE did not ring"
        peer.cancel(headers)
        if peer.status(5, "CANCEL", lambda code: code == 200) != 200:
            return "CANCEL not answered with 200"
        if peer.status(5, "INVITE", lambda code: code == 487) != 487:
            return "the INVITE did not end with 487"
        peer.ack(final_error=True)
        time.sleep(0.3)
    return None


def ended_by_callee(peer):
    if not establish(peer):
        return "call not answered"
    if not peer.bye_from_callee(10):
        return "no BYE from the callee"
    return None


SCENARIOS = {
    "refer-ringing": refer_ringing,
    "fake-replace": fake_replace,
    "reentrant": reentrant,
    "remove-live": ended_by_callee,
    "stop-live": ended_by_callee,
    "require-timer": require_timer,
    "cancel-elsewhere": cancel_elsewhere,
}


def main():
    scenario, host, port = sys.argv[1], sys.argv[2], int(sys.argv[3])
    failure = SCENARIOS[scenario](Peer(host, port))
    print("peer %s: %s" % (scenario, "PASS" if failure is None else "FAIL (%s)" % failure))
    return 0 if failure is None else 1


if __name__ == "__main__":
    sys.exit(main())
