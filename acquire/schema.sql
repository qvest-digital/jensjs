BEGIN;

CREATE SCHEMA IF NOT EXISTS jensjs;

SET search_path TO jensjs, public;

CREATE TABLE IF NOT EXISTS sessions (
	ts TIMESTAMP WITH TIME ZONE NOT NULL,
	ts0 BIGINT NOT NULL DEFAULT 0,
	pk SERIAL PRIMARY KEY,
	schemaname TEXT GENERATED ALWAYS AS ('jjs' || pk::text) STORED,
	comment TEXT NOT NULL
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

CREATE OR REPLACE FUNCTION new_session(IN name TEXT)
    RETURNS TEXT AS $$
DECLARE
	sid TEXT;
BEGIN
	INSERT INTO jensjs.sessions (ts, comment)
	    VALUES (CURRENT_TIMESTAMP, name)
	    RETURNING schemaname INTO sid;
	EXECUTE format('CREATE SCHEMA %I;', sid);
	EXECUTE format('SET search_path TO %I, jensjs, public;', sid);
	-- (ts, owd, qdelay, vqnb, ecnin, ecnout, bitfive, ismark, isdrop, flow, len)
	CREATE TABLE p (
		pk BIGSERIAL PRIMARY KEY,
		len INTEGER NOT NULL,
		ts NUMERIC(20, 9) NOT NULL,
		owd NUMERIC(20, 9) NOT NULL,
		qdelay NUMERIC(20, 9) NOT NULL,
		vqnb NUMERIC(20, 9) NOT NULL,
		ecnin VARCHAR(2) NOT NULL,
		ecnout VARCHAR(2) NOT NULL,
		bitfive BOOLEAN NOT NULL,
		ismark BOOLEAN NOT NULL,
		isdrop BOOLEAN NOT NULL,
		flow TEXT NOT NULL
	);
	CREATE INDEX p_ts ON p (ts);
	-- (ts, membytes, npkts, handover, vcap, tsofs, rcap)
	CREATE TABLE q (
		pk BIGSERIAL PRIMARY KEY,
		membytes BIGINT NOT NULL,
		vcap BIGINT NOT NULL,
		rcap BIGINT NOT NULL,
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
			SELECT ts, tsofs, abs1, TRUNC(abs1)::BIGINT AS iabs,
			    abs1 - TRUNC(abs1) AS fabs FROM a1),
		    fa1 AS (
			SELECT ia1.*, ts - fabs AS d FROM ia1)
		SELECT iabs, d FROM fa1;
	CREATE VIEW fqdelay (dts, msvdelay, msrdelay, mslatency) AS
		SELECT ts - d, qdelay * 1000, (qdelay - vqnb) * 1000, owd * 1000
		FROM p, o
		ORDER BY ts;
	CREATE VIEW fbandwidth (dts, load, capacity, pktsizebytes) AS
		WITH
		    prefiltered AS (
			SELECT ts, len FROM p
			WHERE NOT p.isdrop
		    ),
		    calculated AS (
			SELECT ts, len AS pktsizebytes, vcap as bwlim,
			    -- https://dba.stackexchange.com/a/105828/65843
			    count(vcap) OVER wts AS ct,
			    -- https://stackoverflow.com/a/77051480/2171120
			    CASE WHEN (COUNT(*) OVER wtim) > 20
			    THEN 8 * (sum(len) OVER wnum) / NULLIF(ts - min(ts) OVER wnum, 0)
			    ELSE 8 * (sum(len) OVER wtim) / NULLIF(ts - min(ts) OVER wtim, 0)
			    END AS bps
			FROM prefiltered FULL OUTER JOIN q USING (ts)
			WINDOW
			    wnum AS (ORDER BY ts
				ROWS BETWEEN 20 PRECEDING AND CURRENT ROW
				EXCLUDE CURRENT ROW),
			    wtim AS (ORDER BY ts
				RANGE BETWEEN 0.1 PRECEDING AND CURRENT ROW
				EXCLUDE CURRENT ROW),
			    wts AS (ORDER BY ts)
		    ),
		    filled AS (
			SELECT ts, pktsizebytes, bps,
			    min(bwlim) OVER (PARTITION BY ct) AS bw
			FROM calculated
		    )
		SELECT ts - d AS dts,
		    (TRUNC(bps) / 1000000)::NUMERIC(10,6) AS load,
		    (TRUNC(bw) / 1000000)::NUMERIC(10,6) AS capacity,
		    pktsizebytes
		FROM filled, o ORDER BY ts;
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
	BEGIN
		SELECT ofs INTO STRICT zts FROM o;
		UPDATE sessions SET ts0=zts WHERE pk=num;
	EXCEPTION
	    WHEN NO_DATA_FOUND THEN
		RAISE NOTICE 'no data yet';
	END;
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
