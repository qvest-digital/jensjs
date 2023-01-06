#!/usr/bin/python3

import os
import sys

import http.server

class JJSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def send_response_only(self, code, message=None):
        super().send_response_only(code, message)
        self.send_header('Cache-Control', 'no-cache')

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
