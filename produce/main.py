#!/usr/bin/python3

import os
import sys

import http.server
import urllib.parse

import psycopg2.pool

_dbpool = psycopg2.pool.ThreadedConnectionPool(1, 10, dsn="client_encoding=UTF8")
class JJSDB(object):
    def __enter__(self):
        self.csr = _dbpool.getconn().cursor()
        return self.csr

    def __exit__(self, exc_type, exc_value, traceback):
        conn = self.csr.connection
        try:
            self.csr.close()
            _dbpool.putconn(conn, close=(exc_value is not None))
        except:
            _dbpool.putconn(conn, close=True)
            raise

with JJSDB() as csr:
    csr.execute("""SELECT json_agg(json_build_array(pk, ts, comment) ORDER BY ts DESC) FROM jensjs.sessions;""")
    print(csr.fetchall()[0][0])

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
    foo['bar'][0]
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
