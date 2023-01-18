#!/usr/bin/python3

# pylint: disable=missing-module-docstring
# pylint: disable=missing-class-docstring
# pylint: disable=missing-function-docstring
# pylint: disable=invalid-name
# pylint: disable=unused-argument
# pylint: disable=consider-using-f-string

import os
import sys

import json

import http.server
import urllib.parse

import psycopg2.extensions
import psycopg2.pool

psycopg2.extensions.register_adapter(bytes, psycopg2.extensions.QuotedString)

_dbpool = psycopg2.pool.ThreadedConnectionPool(1, 10, dsn="client_encoding=UTF8")
class JJSDB:
    def __enter__(self):
        # pylint: disable=attribute-defined-outside-init
        self.csr = _dbpool.getconn().cursor()
        return self.csr

    def __exit__(self, exc_type, exc_value, traceback):
        conn = self.csr.connection
        try:
            self.csr.close()
            _dbpool.putconn(conn, close=(exc_value is not None))
        except:  # noqa: E722
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
            except:  # noqa: E722
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
            except:  # noqa: E722
                # if send_response was already called, we lose
                self.send_error(500, "Exception caught")
                raise
        else:
            #super().do_POST()
            self.send_error(501, "Cannot POST here")

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

def qs_int(rh, qs, key):
    try:
        return int(qs[key])
    except (KeyError, ValueError):
        ekey = urllib.parse.quote(key, errors='backslashreplace')
        rh.send_error(422, 'missing or malformed int(%s) parameter' % ekey)
        return None

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
        csr.execute("""SELECT
          json_agg(json_build_array(pk, (EXTRACT(EPOCH FROM ts) * 1000)::BIGINT, comment) ORDER BY ts DESC)::text
          FROM jensjs.sessions;""")
        output = csr.fetchall()[0][0]
    if not output:
        output = '[]'
    rh.ez_rsp(output, ct="application/json")

@Path("/api/comment", "POST")
def API_Comment_SET(rh, u, qs, data):
    session_id = qs_int(rh, qs, 'id')
    if session_id is None: return  # pylint: disable=multiple-statements
    with JJSDB() as csr:
        csr.execute("""UPDATE jensjs.sessions SET comment=%s WHERE pk=%s""",
          (data, session_id))
        if csr.rowcount != 1:
            rh.send_error(404, 'no row affected')
            return
        csr.connection.commit()
    rh.ez_rsp('', code=204)

@Path("/api/session")
def API_Session_Enter(rh, u, qs):
    session_id = qs_int(rh, qs, 'id')
    if session_id is None: return  # pylint: disable=multiple-statements
    answer = {}
    with JJSDB() as csr:
        csr.execute("""SELECT
          (EXTRACT(EPOCH FROM ts) * 1000)::BIGINT, ts0, pk, comment
          FROM jensjs.use_session(%s)""",
          (session_id, ))
        rows = csr.fetchall()
        if len(rows) != 1:
            rh.send_error(404, 'session not found')
            return
        answer['ts'] = rows[0][0]
        answer['ms'] = rows[0][1] * 1000
        answer['id'] = rows[0][2]
        answer['c'] = rows[0][3]
    output = json.dumps(answer, ensure_ascii=False, allow_nan=False,
      indent=None, separators=(',', ':')).encode('UTF-8')
    rh.ez_rsp(output, ct="application/json")

def API_Session_enter(csr, session_id):
    csr.execute("""SELECT pk FROM jensjs.use_session(%s)""", (session_id, ))
    rows = csr.fetchall()
    if len(rows) != 1:
        return True
    return session_id != rows[0][0]

@Path("/api/session/qdelay")
def API_Session_qdelay(rh, u, qs):
    session_id = qs_int(rh, qs, 'id')
    if session_id is None: return  # pylint: disable=multiple-statements
    #inited = False
    with JJSDB() as csr:
        if API_Session_enter(csr, session_id):
            rh.send_error(404, 'session not found')
            return
        rh.send_response(200)
        rh.send_header("Content-Type", "text/plain")
        rh.end_headers()
        csr.copy_expert("""COPY (
            SELECT ts - d, qdelay * 1000, owd * 1000 FROM p, o ORDER BY ts
          ) TO STDOUT WITH (DELIMITER ',')""", rh.wfile)

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
