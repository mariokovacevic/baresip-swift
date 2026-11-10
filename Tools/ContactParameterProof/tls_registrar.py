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
DEFAULT_SIP_PORT = 5060
DEFAULT_PEER_PORT = 5070

tls_connections = {}
tls_lock = threading.Lock()
udp_socket = None


def split_message(raw):
    head, _, body = raw.partition(b"\r\n\r\n")
    return head.decode(errors="replace").split("\r\n"), body


def join_message(lines, body):
    return ("\r\n".join(lines) + "\r\n\r\n").encode() + body


def uri_target(uri):
    m = re.search(r"sips?:(?:[^@;>]+@)?([^:;>]+)(?::(\d+))?([^>]*)", uri)
    host, port, params = m.group(1), m.group(2), m.group(3)
    transport = "tls" if "transport=tls" in params.lower() or uri.startswith("sips:") else "udp"
    return host, int(port) if port else DEFAULT_SIP_PORT, transport


def peer_address():
    host, _, port = os.environ.get("REGISTRAR_PEER", "%s:%d" % (HOST, DEFAULT_PEER_PORT)).rpartition(":")
    return host, int(port)


def trace_forward(trace, transport, host, port, data):
    trace.write("---- proxy -> %s %s:%d ----\n%s\n" % (transport, host, port, data.split(b"\r\n\r\n")[0].decode(errors="replace")))
    trace.flush()


def send(transport, host, port, data, trace):
    if transport == "tls":
        with tls_lock:
            conn = tls_connections.get((host, port))
            if conn:
                trace_forward(trace, transport, host, port, data)
                conn.sendall(data)
                return
    if (host, port) != peer_address():
        trace.write("---- refused: %s:%d is neither a registered connection nor the peer ----\n" % (host, port))
        trace.flush()
        return
    trace_forward(trace, "udp", host, port, data)
    udp_socket.sendto(data, (host, port))


def is_own_route(line):
    return line.lower().startswith("route:") and (":%d" % PORT) in line and HOST in line


def forward_request(raw, trace):
    lines, body = split_message(raw)
    host, port, transport = uri_target(lines[0].split(" ")[1])
    lines = [l for l in lines if not is_own_route(l)]
    branch = "z9hG4bK-proxy-" + os.urandom(6).hex()
    lines.insert(1, "Via: SIP/2.0/UDP %s:%d;branch=%s;rport" % (HOST, PORT, branch))
    to = header("\r\n".join(lines) + "\r\n", "To") or ""
    if lines[0].startswith("INVITE ") and ";tag=" not in to:
        lines.insert(2, "Record-Route: <sip:%s:%d;transport=udp;lr>" % (HOST, PORT))
    send(transport, host, port, join_message(lines, body), trace)


def route_response(raw, trace):
    lines, body = split_message(raw)
    vias = [i for i, l in enumerate(lines) if l.lower().startswith("via:")]
    if not vias or "z9hG4bK-proxy-" not in lines[vias[0]]:
        return
    del lines[vias[0]]
    if len(vias) < 2:
        return
    via = lines[vias[1] - 1]
    m = re.search(r"SIP/2\.0/(\w+)\s+([^:;\s]+)(?::(\d+))?", via)
    transport = m.group(1).lower()
    received = re.search(r"received=([^;\s]+)", via)
    host = received.group(1) if received else m.group(2)
    rport = re.search(r"rport=(\d+)", via)
    port = int(rport.group(1)) if rport else int(m.group(3) or DEFAULT_SIP_PORT)
    send("tls" if transport == "tls" else "udp", host, port, join_message(lines, body), trace)


def dispatch(raw, trace):
    if raw.startswith(b"SIP/2.0"):
        route_response(raw, trace)
    else:
        forward_request(raw, trace)


def udp_loop(trace):
    while True:
        try:
            data, addr = udp_socket.recvfrom(65535)
        except OSError:
            return
        trace.write("---- udp %s:%d -> proxy ----\n%s\n" % (addr[0], addr[1], data.split(b"\r\n\r\n")[0].decode(errors="replace")))
        dispatch(data, trace)


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
                body = rest[:clen]
                buf = rest[clen:]
                trace.write("---- tls %s -> registrar ----\n%s" % (conn.getpeername()[0], req))
                with tls_lock:
                    tls_connections[conn.getpeername()[:2]] = conn
                if not req.startswith("REGISTER "):
                    dispatch(head + b"\r\n\r\n" + body, trace)
                    continue
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
                with tls_lock:
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
    global udp_socket
    udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp_socket.bind((HOST, PORT))
    threading.Thread(target=udp_loop, args=(trace,), daemon=True).start()
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
