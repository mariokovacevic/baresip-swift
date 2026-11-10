import hashlib
import os
import re
import secrets
import socket
import sys
import time

HOST = os.environ.get("REGISTRAR_HOST", "127.0.0.1")
PORT = 5080
REALM = "example.invalid"
USERS = {"alice": "secret"}


def md5(s):
    return hashlib.md5(s.encode()).hexdigest()


def header(msg, name):
    m = re.search(r"^%s:\s*(.*?)\r?$" % re.escape(name), msg, re.M | re.I)
    return m.group(1) if m else None


def parse_auth(value):
    out = {}
    for k, v in re.findall(r'(\w+)=("[^"]*"|[^,]+)', value):
        out[k] = v.strip().strip('"')
    return out


def check_digest(auth, method):
    p = parse_auth(auth)
    user = p.get("username")
    if user not in USERS:
        return False
    ha1 = md5("%s:%s:%s" % (user, p.get("realm"), USERS[user]))
    ha2 = md5("%s:%s" % (method, p.get("uri")))
    if p.get("qop") == "auth":
        expected = md5("%s:%s:%s:%s:%s:%s" % (ha1, p.get("nonce"), p.get("nc"),
                                              p.get("cnonce"), "auth", ha2))
    else:
        expected = md5("%s:%s:%s" % (ha1, p.get("nonce"), ha2))
    return expected == p.get("response")


def build_response(req, status, extra_headers=""):
    via = header(req, "Via")
    frm = header(req, "From")
    to = header(req, "To")
    callid = header(req, "Call-ID")
    cseq = header(req, "CSeq")
    if ";tag=" not in to:
        to = to + ";tag=reg-" + secrets.token_hex(4)
    return ("SIP/2.0 %s\r\n"
            "Via: %s\r\n"
            "From: %s\r\n"
            "To: %s\r\n"
            "Call-ID: %s\r\n"
            "CSeq: %s\r\n"
            "%s"
            "Content-Length: 0\r\n\r\n" % (status, via, frm, to, callid, cseq,
                                         extra_headers))


def main():
    trace_path = sys.argv[1] if len(sys.argv) > 1 else "trace.txt"
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((HOST, PORT))
    sock.settimeout(float(os.environ.get("REGISTRAR_IDLE_TIMEOUT", "6")))
    nonce = secrets.token_hex(8)
    trace = open(trace_path, "w")
    trace.write("# Sanitized SIP trace captured by fake_registrar.py\n")
    trace.write("# Registrar: udp/%s:%d  realm=%s\n\n" % (HOST, PORT, REALM))
    n = 0
    start = time.time()
    while True:
        try:
            data, addr = sock.recvfrom(65535)
        except socket.timeout:
            break
        req = data.decode(errors="replace")
        n += 1
        t = time.time() - start
        trace.write("---- [%02d] t=%.3fs  %s:%d -> registrar ----\n" % (n, t, addr[0], addr[1]))
        trace.write(req)
        if not req.startswith("REGISTER "):
            resp = build_response(req, "405 Method Not Allowed")
        else:
            auth = header(req, "Authorization")
            if not auth or not check_digest(auth, "REGISTER"):
                resp = build_response(
                    req, "401 Unauthorized",
                    'WWW-Authenticate: Digest realm="%s", nonce="%s", algorithm=MD5, qop="auth"\r\n'
                    % (REALM, nonce))
            else:
                contact = header(req, "Contact")
                expires = header(req, "Expires")
                m = re.search(r"expires=(\d+)", contact or "")
                exp = m.group(1) if m else (expires or "3600")
                contact_echo = re.sub(r";expires=\d+", "", contact)
                resp = build_response(
                    req, "200 OK",
                    "Contact: %s;expires=%s\r\nDate: %s\r\n"
                    % (contact_echo, exp, time.strftime("%a, %d %b %Y %H:%M:%S GMT", time.gmtime())))
        sock.sendto(resp.encode(), addr)
        trace.write("---- [%02d] registrar -> %s:%d ----\n%s" % (n, addr[0], addr[1], resp))
        trace.flush()
    trace.close()
    print("registrar: handled %d requests, trace written to %s" % (n, trace_path))


if __name__ == "__main__":
    main()
