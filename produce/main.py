#!/usr/bin/python3

import os
import sys

import http.server
import urllib.parse

import psycopg2.extensions
import psycopg2.pool

psycopg2.extensions.register_adapter(bytes, psycopg2.extensions.QuotedString)

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

_JJS_path_registry = {"GET": {}, "POST": {}}
class JJSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def send_response_only(self, code, message=None):
        super().send_response_only(code, message)
        self.send_header('Cache-Control', 'no-cache')

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        qs = dict(urllib.parse.parse_qsl(u.query,
          keep_blank_values=True, max_num_fields=20))
        path = urllib.parse.unquote(u.path)
        if path in _JJS_path_registry["GET"]:
            try:
                _JJS_path_registry["GET"][path](self, u, qs)
            except:
                # if send_response was already called, we lose
                self.send_error(500, "Exception caught")
                raise
        else:
            super().do_GET()

    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        qs = dict(urllib.parse.parse_qsl(u.query,
          keep_blank_values=True, max_num_fields=20))
        path = urllib.parse.unquote(u.path)
        if path in _JJS_path_registry["POST"]:
            try:
                datalen = int(self.headers.get("Content-Length"))
                data = self.rfile.read(datalen)
                _JJS_path_registry["POST"][path](self, u, qs, data)
            except:
                # if send_response was already called, we lose
                self.send_error(500, "Exception caught")
                raise
        else:
            super().do_POST()

    def ez_rsp(self, body, code=200, ct=None):
        if not isinstance(body, bytes):
            body = bytes(body, "UTF-8")
        self.send_response(code)
        if ct is not None:
            self.send_header("Content-Type", ct)
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

def _Path(path, method, func):
    _JJS_path_registry[method][path] = func
    return func
def Path(path, method="GET"):
    return lambda func: _Path(path, method, func)

@Path("/api/test")
def API_Test(rh, u, qs):
    print('u:', repr(u))
    print('qs:', repr(qs))
    rh.ez_rsp("Okäy!\n")

@Path("/api/test", "POST")
def API_Test_SET(rh, u, qs, data):
    print('u:', repr(u))
    print('qs:', repr(qs))
    print('data:', repr(data))
    rh.ez_rsp('OK\n')

@Path("/api/sessions")
def API_Sessions(rh, u, qs):
    with JJSDB() as csr:
        csr.execute("""SELECT json_agg(json_build_array(pk, ts, comment) ORDER BY ts DESC)::text FROM jensjs.sessions;""")
        output = csr.fetchall()[0][0]
    if not output:
        output = '[]'
    rh.ez_rsp(output, ct="application/json")

@Path("/api/comment", "POST")
def API_Comment_SET(rh, u, qs, data):
    if not 'id' in qs:
        rh.send_error(422, 'missing ID')
        return
    with JJSDB() as csr:
        csr.execute("""UPDATE jensjs.sessions SET comment=%s WHERE pk=%s""",
          (data, int(qs['id'])))
        if csr.rowcount != 1:
            rh.send_error(404, 'no row affected')
            return
        csr.connection.commit()
    rh.ez_rsp('', code=204)

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
