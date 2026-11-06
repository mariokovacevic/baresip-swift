import os
import re
import socket
import ssl
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fake_registrar import build_response, check_digest, header, REALM

HOST = os.environ.get("REGISTRAR_HOST", "127.0.0.1")
PORT = int(os.environ.get("REGISTRAR_PORT", "5081"))


def handle(conn, trace, nonce):
    buf = b""
    conn.settimeout(float(os.environ.get("REGISTRAR_IDLE_TIMEOUT", "6")))
    try:
        while True:
            data = conn.recv(65535)
            if not data:
                break
            buf += data
            while b"\r\n\r\n" in buf:
                head, rest = buf.split(b"\r\n\r\n", 1)
                req = head.decode(errors="replace") + "\r\n\r\n"
                clen = int(header(req, "Content-Length") or "0")
                if len(rest) < clen:
                    break
                buf = rest[clen:]
                trace.write("---- tls %s -> registrar ----\n%s" % (conn.getpeername()[0], req))
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
                        m = re.search(r"expires=(\d+)", contact or "")
                        exp = m.group(1) if m else (header(req, "Expires") or "3600")
                        contact_echo = re.sub(r";expires=\d+", "", contact)
                        resp = build_response(req, "200 OK", "Contact: %s;expires=%s\r\n" % (contact_echo, exp))
                conn.sendall(resp.encode())
                trace.write("---- registrar -> tls ----\n%s" % resp)
                trace.flush()
    except (socket.timeout, ssl.SSLError, ConnectionResetError, OSError):
        pass
    finally:
        try:
            conn.close()
        except OSError:
            pass


def main():
    certfile = sys.argv[1]
    keyfile = sys.argv[2]
    trace_path = sys.argv[3] if len(sys.argv) > 3 else "trace-tls.txt"
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.load_cert_chain(certfile, keyfile)
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((HOST, PORT))
    srv.listen(5)
    srv.settimeout(float(os.environ.get("REGISTRAR_IDLE_TIMEOUT", "6")))
    nonce = os.urandom(8).hex()
    trace = open(trace_path, "w")
    handled = 0
    failed_handshakes = 0
    while True:
        try:
            raw, addr = srv.accept()
        except socket.timeout:
            break
        try:
            conn = ctx.wrap_socket(raw, server_side=True)
        except ssl.SSLError as e:
            failed_handshakes += 1
            trace.write("---- tls handshake failed from %s: %s ----\n" % (addr[0], e))
            trace.flush()
            raw.close()
            continue
        handled += 1
        threading.Thread(target=handle, args=(conn, trace, nonce), daemon=True).start()
    trace.close()
    print("tls registrar: %d connections, %d failed handshakes, trace %s" % (handled, failed_handshakes, trace_path))


if __name__ == "__main__":
    main()
