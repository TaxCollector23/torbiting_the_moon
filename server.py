#!/usr/bin/env python3
import http.server, json, os, subprocess, threading, time, uuid
from urllib.parse import urlparse

PORT         = 3000
BASE_PORT    = 6100
MAX_SESSIONS = 10
SESSION_TTL  = 1800  # 30 minutes
IMAGE        = "torbrowser"
PUBLIC       = os.path.join(os.path.dirname(os.path.abspath(__file__)), "public")

sessions = {}
lock = threading.Lock()

MIME = {".html":"text/html",".js":"application/javascript",".css":"text/css",".ico":"image/x-icon"}

def next_port():
    used = {s["port"] for s in sessions.values()}
    for i in range(MAX_SESSIONS):
        p = BASE_PORT + i
        if p not in used:
            return p
    return None

def kill(sid):
    with lock:
        s = sessions.pop(sid, None)
    if not s:
        return
    if s.get("timer"):
        s["timer"].cancel()
    subprocess.run(["docker", "rm", "-f", f"tb-{sid}"], capture_output=True)
    print(f"Killed session {sid[:8]}")

def auto_kill(sid):
    t = threading.Timer(SESSION_TTL, lambda: kill(sid))
    t.daemon = True
    t.start()
    return t

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): pass  # silence default logs

    def json(self, code, data):
        b = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(b))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        p = urlparse(self.path).path
        if p == "/api/sessions":
            with lock:
                out = [{"id":k,"port":v["port"],"url":v["url"]} for k,v in sessions.items()]
            return self.json(200, {"sessions": out})
        if p in ("/", ""):
            p = "/index.html"
        fp = os.path.join(PUBLIC, p.lstrip("/"))
        if not os.path.abspath(fp).startswith(os.path.abspath(PUBLIC)) or not os.path.isfile(fp):
            self.send_error(404)
            return
        ext = os.path.splitext(fp)[1]
        with open(fp, "rb") as f:
            b = f.read()
        self.send_response(200)
        self.send_header("Content-Type", MIME.get(ext, "application/octet-stream"))
        self.send_header("Content-Length", len(b))
        self.end_headers()
        self.wfile.write(b)

    def do_POST(self):
        if urlparse(self.path).path != "/api/session":
            return self.send_error(404)
        with lock:
            count = len(sessions)
        if count >= MAX_SESSIONS:
            return self.json(429, {"error": "Max sessions reached."})
        port = next_port()
        if not port:
            return self.json(503, {"error": "No ports available."})
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        except:
            body = {}
        url = body.get("url", "https://check.torproject.org").replace("`","").replace("$","").replace("'","").replace('"',"")
        sid = str(uuid.uuid4())
        cmd = ["docker","run","-d","--name",f"tb-{sid}","-p",f"{port}:6080","-e",f"URL={url}","--cap-add","SYS_ADMIN","--security-opt","seccomp=unconfined","--shm-size=1g", IMAGE]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            return self.json(500, {"error": "Docker failed to start.", "detail": r.stderr.strip()})
        with lock:
            sessions[sid] = {"port": port, "url": url, "timer": auto_kill(sid)}
        print(f"New session {sid[:8]} → port {port} → {url}")
        self.json(200, {"id": sid, "port": port, "novnc": f"http://localhost:{port}/vnc.html?autoconnect=true&resize=scale"})

    def do_DELETE(self):
        parts = urlparse(self.path).path.strip("/").split("/")
        if len(parts) == 3 and parts[1] == "session":
            sid = parts[2]
            with lock:
                exists = sid in sessions
            if not exists:
                return self.json(404, {"error": "Not found."})
            kill(sid)
            return self.json(200, {"ok": True})
        self.send_error(404)

if __name__ == "__main__":
    import signal, sys
    def bye(s,f):
        print("\nShutting down...")
        for sid in list(sessions): kill(sid)
        sys.exit(0)
    signal.signal(signal.SIGINT, bye)
    signal.signal(signal.SIGTERM, bye)
    print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"  tor-browser running")
    print(f"  open → http://localhost:{PORT}")
    print(f"  stop → Ctrl + C")
    print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    http.server.HTTPServer(("0.0.0.0", PORT), H).serve_forever()
