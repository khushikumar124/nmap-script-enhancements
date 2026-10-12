import os, sys, socket, ssl, threading, http.server, socketserver
# usage: python3 srv.py [mode]
#   mode "main" (default): web pages + TLS-wrapped mail/ldap/ftp/nntp servers + plain listeners
#   mode "ssh993": like main, but 993 is ssh wrapped in TLS
#   mode "smtp993": like main, but 993 is plaintext smtp (no TLS)
MODE = sys.argv[1] if len(sys.argv) > 1 else "main"
HERE = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(HERE, "requests.log")   # one line per HTTP request / TCP connection
_lk = threading.Lock()
def log(s):
    with _lk:
        with open(LOG, "a") as f: f.write(s + "\n")

# --- web pages. value = body, or (body, extra headers). "/" keeps the original behaviour. ---
def meta(t): return b'<html><head>' + t + b'<title>t</title></head><body>x</body></html>'
PAGES = {
 "/": b'<html><head><meta data-react-helmet="true" name="generator" content="Gatsby 5.13"><title>t</title></head><body>x</body></html>',
 # E1 cases (no headers)
 "/e1/stock":      (meta(b'<meta name="generator" content="TYPO3 4.2 CMS">'), {}),
 "/e1/single":     (meta(b"<meta name='generator' content='Joomla 4.3'>"), {}),
 "/e1/unquoted":   (meta(b'<meta name=generator content=WordPress>'), {}),
 "/e1/upper":      (meta(b'<META NAME="GENERATOR" CONTENT="Hexo 6.3">'), {}),
 "/e1/two":        (meta(b'<meta name="generator" content="WordPress 6.4"><meta name="generator" content="Elementor 3.18">'), {}),
 "/e1/nongen":     (meta(b'<meta name="viewport" content="width=device-width"><meta charset="utf-8">'), {}),
 "/e1/empty":      (meta(b'<meta name="generator" content="">'), {}),
 "/e1/selfclose":  (meta(b'<meta  content="Jekyll 4.3"\n   name="generator" />'), {}),
 # many meta tags first, generator last inside <head>; then 20 MB of junk in <body>
 "/e1/large":      (b'<html><head>' + b'<meta name="x" content="y">' * 20 + b'<meta name="generator" content="Big 1.0"></head><body>' + b'a' * (20 * 1024 * 1024) + b'</body></html>', {}),
 # E2 cases
 "/e2/header":     (b'<html><head><title>t</title></head></html>', {"X-Generator": "Drupal 10 (https://www.drupal.org)"}),
 "/e2/meta":       (meta(b'<meta name="generator" content="Hugo 0.120">'), {}),
 "/e2/same":       (meta(b'<meta name="generator" content="Drupal 10 (https://www.drupal.org)">'), {"X-Generator": "Drupal 10 (https://www.drupal.org)"}),
 "/e2/diff":       (meta(b'<meta name="generator" content="Hugo 0.120">'), {"X-Generator": "Drupal 10 (https://www.drupal.org)"}),
 "/e2/none":       (b'<html><head><title>t</title></head></html>', {}),
}
DEFAULT_HDR = {"X-Generator": "Drupal 10 (https://www.drupal.org)", "X-Powered-By": "PHP/8.2.1"}
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        log("http %d GET %s" % (self.server.server_address[1], self.path))
        v = PAGES.get(self.path, b"<html>none</html>")
        body, hdrs = v if isinstance(v, tuple) else (v, DEFAULT_HDR)
        self.send_response(200); self.send_header("Content-Type","text/html")
        for k, val in hdrs.items(): self.send_header(k, val)
        self.send_header("Content-Length",str(len(body))); self.end_headers(); self.wfile.write(body)
    def log_message(self,*a): pass
class H2(H):
    def do_GET(self):  # attribute-order variant: content first, no header
        log("http %d GET %s" % (self.server.server_address[1], self.path))
        body=b'<html><head><meta content="Hugo 0.120" name="generator"></head></html>'
        self.send_response(200); self.send_header("Content-Length",str(len(body))); self.end_headers(); self.wfile.write(body)
def web(port,h):
    socketserver.ThreadingTCPServer.allow_reuse_address=True
    s=socketserver.ThreadingTCPServer(("127.0.0.1",port),h); s.serve_forever()

# --- TCP servers. macOS only lets a normal user bind ports <1024 on the wildcard address. ---
def listener(port):
    s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    s.bind(("" if port < 1024 else "127.0.0.1", port)); s.listen(8); return s

def talk(t, banner, replies):
    # send banner, answer a few commands, stop after 2 s of silence
    t.settimeout(2)
    try:
        if banner: t.sendall(banner)
        while True:
            d=t.recv(1024)
            if not d: break
            for prefix, resp in replies:
                if d.upper().startswith(prefix): t.sendall(resp); break
            if d.upper().startswith(b"QUIT") or d.upper().startswith(b"A001 LOGOUT"): break
    except Exception: pass

def tcp_server(port, banner, replies, tls):
    ctx=None
    if tls:
        ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.load_cert_chain(os.path.join(HERE,"c.pem"),os.path.join(HERE,"k.pem"))
    try: s=listener(port)
    except Exception as e:
        print("cannot bind", port, e, flush=True); return
    while True:
        c,_=s.accept(); log("tcp %d connect" % port)
        try:
            t=ctx.wrap_socket(c,server_side=True) if ctx else c
            talk(t, banner, replies)
            t.close()
        except Exception:
            try: c.close()
            except Exception: pass

def tls_smtp(port): tcp_server(port, b"220 mail.example.com ESMTP Postfix\r\n", [(b"EHLO",b"250 mail.example.com\r\n"),(b"HELO",b"250 mail.example.com\r\n"),(b"QUIT",b"221 Bye\r\n")], True)

SMTP = (b"220 mail.example.com ESMTP Postfix\r\n", [(b"EHLO",b"250 mail.example.com\r\n"),(b"HELO",b"250 mail.example.com\r\n"),(b"QUIT",b"221 Bye\r\n")])
IMAP = (b"* OK [CAPABILITY IMAP4rev1 LITERAL+ SASL-IR LOGIN-REFERRALS ID ENABLE IDLE AUTH=PLAIN] Dovecot ready.\r\n", [(b"A001 CAPABILITY",b"* CAPABILITY IMAP4rev1\r\nA001 OK done\r\n"),(b"A001 LOGOUT",b"* BYE\r\nA001 OK\r\n")])
POP3 = (b"+OK Dovecot ready.\r\n", [(b"CAPA",b"+OK\r\nUSER\r\n.\r\n"),(b"QUIT",b"+OK bye\r\n")])
FTP  = (b"220 ProFTPD Server (Debian) [::ffff:127.0.0.1]\r\n", [(b"USER",b"331 Password required\r\n"),(b"QUIT",b"221 Goodbye\r\n")])
NNTP = (b"200 Leafnode NNTP Daemon, version 1.11.11 ready (posting ok)\r\n", [(b"CAPABILITIES",b"101 ok\r\n.\r\n"),(b"QUIT",b"205 bye\r\n")])
SSH  = (b"SSH-2.0-OpenSSH_8.9p1 Ubuntu-3ubuntu0.1\r\n", [])
# minimal LDAP bindResponse (success) for any request; good enough for Nmap's LDAP probe
LDAP = (None, [(b"",b"\x30\x0c\x02\x01\x01\x61\x07\x0a\x01\x00\x04\x00\x04\x00")])

if __name__ == "__main__":
    for p,h in ((8081,H),(8082,H2)): threading.Thread(target=web,args=(p,h),daemon=True).start()
    tls = {465:SMTP, 993:IMAP, 995:POP3, 636:LDAP, 990:FTP, 563:NNTP}
    plain = {23:SSH, 2222:SSH, 22:SSH}
    if MODE == "ssh993": tls[993] = SSH
    if MODE == "smtp993": del tls[993]; plain[993] = SMTP
    for p,(b,r) in tls.items(): threading.Thread(target=tcp_server,args=(p,b,r,True),daemon=True).start()
    for p,(b,r) in plain.items(): threading.Thread(target=tcp_server,args=(p,b,r,False),daemon=True).start()
    # plain http on a port whose nmap-services name is not http (3306 and 5432 are taken by local databases here)
    threading.Thread(target=web,args=(5433,H),daemon=True).start()
    threading.Event().wait()
