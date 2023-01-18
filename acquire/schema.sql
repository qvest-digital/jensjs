BEGIN;

CREATE SCHEMA IF NOT EXISTS jensjs;

SET search_path TO jensjs, public;

CREATE TABLE IF NOT EXISTS sessions (
	ts TIMESTAMP WITH TIME ZONE NOT NULL,
	ts0 BIGINT NOT NULL DEFAULT 0,
	pk SERIAL PRIMARY KEY,
	schemaname TEXT GENERATED ALWAYS AS ('jjs' || pk::text) STORED,
	comment TEXT NOT NULL DEFAULT ''
);

-- https://www.postgresql.org/docs/current/catalog-pg-type.html
CREATE OR REPLACE VIEW tabletetris
    AS SELECT n.nspname, c.relname,
	a.attname, t.typname, t.typstorage, t.typalign, t.typlen
    FROM pg_class c
    JOIN pg_namespace n ON (n.oid = c.relnamespace)
    JOIN pg_attribute a ON (a.attrelid = c.oid)
    JOIN pg_type t ON (t.oid = a.atttypid)
    WHERE a.attnum >= 0
    ORDER BY n.nspname ASC, c.relname ASC,
	t.typlen DESC, t.typalign DESC, a.attnum ASC;

CREATE OR REPLACE FUNCTION new_session()
    RETURNS TEXT AS $$
DECLARE
	sid TEXT;
BEGIN
	INSERT INTO jensjs.sessions (ts)
	    VALUES (CURRENT_TIMESTAMP)
	    RETURNING schemaname INTO sid;
	EXECUTE format('CREATE SCHEMA %I;', sid);
	EXECUTE format('SET search_path TO %I, jensjs, public;', sid);
	-- (ts, owd, qdelay, chance, ecnin, ecnout, bitfive, ismark, isdrop, flow, len)
	CREATE TABLE p (
		pk BIGSERIAL PRIMARY KEY,
		chance INTEGER NOT NULL,
		len INTEGER NOT NULL,
		ts NUMERIC(20, 9) NOT NULL,
		owd NUMERIC(20, 9) NOT NULL,
		qdelay NUMERIC(20, 9) NOT NULL,
		ecnin VARCHAR(2) NOT NULL,
		ecnout VARCHAR(2) NOT NULL,
		bitfive BOOLEAN NOT NULL,
		ismark BOOLEAN NOT NULL,
		isdrop BOOLEAN NOT NULL,
		flow TEXT NOT NULL
	);
	CREATE INDEX p_ts ON p (ts);
	-- (ts, membytes, npkts, handover, bwlim, tsofs)
	CREATE TABLE q (
		pk BIGSERIAL PRIMARY KEY,
		membytes BIGINT NOT NULL,
		bwlim BIGINT NOT NULL,
		npkts INTEGER NOT NULL,
		handover BOOLEAN NOT NULL,
		ts NUMERIC(20, 9) NOT NULL,
		tsofs NUMERIC(20, 9) NOT NULL
	);
	CREATE INDEX q_ts ON q (ts);
	CREATE VIEW o (ofs, d) AS
		WITH
		    p1 AS (
			SELECT ts, NULL::NUMERIC(20,9) AS tsofs
				FROM p ORDER BY pk LIMIT 1),
		    q1 AS (
			SELECT ts, tsofs FROM q ORDER BY pk LIMIT 1),
		    pq1 AS (
			SELECT * FROM p1
			UNION ALL
			SELECT * FROM q1
				ORDER BY ts LIMIT 1),
		    pq0 AS (
			SELECT pq1.ts, q1.tsofs FROM pq1, q1),
		    a1 AS (
			SELECT ts, tsofs, ts + tsofs AS abs1 FROM pq0),
		    ia1 AS (
			SELECT ts, tsofs, abs1, abs1::BIGINT AS iabs,
			    (abs1 - abs1)::BIGINT AS fabs FROM a1),
		    fa1 AS (
			SELECT ia1.*, ts - fabs AS d FROM ia1)
		SELECT iabs, d FROM fa1;
	RETURN sid;
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION use_session(IN sid TEXT)
    RETURNS TEXT AS $$
DECLARE
	num INTEGER;
BEGIN
	SET search_path TO jensjs, public;
	SELECT pk INTO STRICT num FROM jensjs.sessions WHERE schemaname=sid;
	EXECUTE format('SET search_path TO %I, jensjs, public;', sid);
	RETURN sid;
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION use_session(IN num INTEGER)
    RETURNS sessions AS $$
DECLARE
	sid TEXT;
	zts BIGINT;
BEGIN
	SET search_path TO jensjs, public;
	SELECT schemaname INTO STRICT sid FROM jensjs.sessions WHERE pk=num;
	EXECUTE format('SET search_path TO %I, jensjs, public;', sid);
	SELECT ofs INTO STRICT zts FROM o;
	UPDATE sessions SET ts0=zts WHERE pk=num;
	RETURN sessions FROM sessions WHERE pk=num;
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION drop_session(IN num INTEGER)
    RETURNS TEXT AS $$
DECLARE
	sid TEXT;
BEGIN
	SET search_path TO jensjs, public;
	SELECT schemaname INTO STRICT sid FROM jensjs.sessions WHERE pk=num;
	EXECUTE format('DROP SCHEMA IF EXISTS %I CASCADE;', sid);
	DELETE FROM jensjs.sessions WHERE pk=num;
	RETURN sid;
END;
$$ LANGUAGE 'plpgsql';

COMMIT;