#!/usr/bin/python3

import os
import sys

import http.server
import urllib.parse

_JJS_path_registry = {}
class JJSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def send_response_only(self, code, message=None):
        super().send_response_only(code, message)
        self.send_header('Cache-Control', 'no-cache')

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        qs = urllib.parse.parse_qs(u.query, max_num_fields=20)
        path = urllib.parse.unquote(u.path)
        if path in _JJS_path_registry:
            _JJS_path_registry[path](self, u, qs)
        else:
            super().do_GET()

    def ez_rsp(self, body, code=200, ct=None):
        if not isinstance(body, bytes):
            body = bytes(body, "UTF-8")
        self.send_response(code)
        if ct is not None:
            self.send_header("Content-Type", ct)
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

def _Path(path, func):
    _JJS_path_registry[path] = func
    return func
def Path(path):
    return lambda func: _Path(path, func)

@Path("/api/test")
def API_Test(rh, u, qs):
    print('u:', repr(u))
    print('qs:', repr(qs))
    rh.ez_rsp("Okäy!\n")

# …

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, 'static'))

if len(sys.argv) > 1:
    port = int(sys.argv[1])
else:
    port = 8080
http.server.test(HandlerClass=JJSRequestHandler,
  ServerClass=http.server.ThreadingHTTPServer,
  port=port)
#NOTREACHED
