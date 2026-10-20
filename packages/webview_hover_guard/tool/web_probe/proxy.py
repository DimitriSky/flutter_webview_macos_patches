"""Serves real pages unchanged plus the injected probe.js logger.

  python3 proxy.py --port 8792 --upstream http://127.0.0.1:8777 --file mockup=/path/page.html

  /<name>  -> the local file given with --file name=path
  anything else -> proxied to --upstream (HTML responses get the logger)
  Logs: events.jsonl next to this script (one JSON event per line).
"""
import argparse
import json
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).parent
TAG = b'<script src="/__probe.js"></script>'
parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8792)
parser.add_argument('--upstream')
parser.add_argument('--file', action='append', default=[], help='name=path')
parser.add_argument('--out', default=str(ROOT / 'events.jsonl'))
ARGS = parser.parse_args()
FILES = dict(item.split('=', 1) for item in ARGS.file)


def inject(html: bytes) -> bytes:
    i = html.rfind(b'</body>')
    return html[:i] + TAG + html[i:] if i >= 0 else html + TAG


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, ctype):
        self.send_response(code)
        self.send_header('content-type', ctype)
        self.send_header('content-length', str(len(body)))
        self.send_header('cache-control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def proxy(self, method):
        if not ARGS.upstream:
            return self.send(404, b'not found', 'text/plain')
        length = int(self.headers.get('content-length', 0))
        req = urllib.request.Request(ARGS.upstream + self.path, data=self.rfile.read(length) if length else None, method=method)
        for k in ('content-type', 'range', 'accept'):
            if self.headers.get(k):
                req.add_header(k, self.headers[k])
        try:
            res = urllib.request.urlopen(req, timeout=600)
            code, body, headers = res.status, res.read(), res.headers
        except urllib.error.HTTPError as e:
            code, body, headers = e.code, e.read(), e.headers
        ctype = headers.get('content-type', 'application/octet-stream')
        self.send(code, inject(body) if 'text/html' in ctype else body, ctype)

    def do_GET(self):
        name = self.path.split('?')[0].lstrip('/')
        if name == '__probe.js':
            return self.send(200, (ROOT / 'probe.js').read_bytes(), 'text/javascript')
        if name in FILES:
            return self.send(200, inject(Path(FILES[name]).read_bytes()), 'text/html; charset=utf-8')
        self.proxy('GET')

    def do_POST(self):
        if self.path != '/__log':
            return self.proxy('POST')
        body = self.rfile.read(int(self.headers.get('content-length', 0)))
        with open(ARGS.out, 'a') as f:
            for event in json.loads(body):
                event['wall'] = round(time.time(), 3)
                f.write(json.dumps(event, ensure_ascii=False) + '\n')
        self.send_response(204)
        self.end_headers()

    def log_message(self, *args):
        pass


ThreadingHTTPServer(('127.0.0.1', ARGS.port), Handler).serve_forever()
