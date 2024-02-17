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

	-- (vts, hts, flow, flags, kind, mark, ue, psize, uepkts, uebytes, iptos, vbw, rbw, vqdelay, rqdelay, owdelay)
	CREATE TABLE r (
		pk BIGSERIAL PRIMARY KEY,
		vbw BIGINT NOT NULL,
		rbw BIGINT NOT NULL,
		psize INTEGER NOT NULL,
		uepkts INTEGER NOT NULL,
		uebytes INTEGER NOT NULL,
		kind "char" NOT NULL,
		mark BOOLEAN NOT NULL,
		ue "char" NOT NULL,
		-- really 8 hex nybbles but SQL meh ☹ so (normally)
		-- CHAR(8) but that is slower in PostgreSQL actually
		flags VARCHAR(8) NOT NULL,
		iptos VARCHAR(2) NOT NULL,
		vts NUMERIC(20, 9) NOT NULL,
		hts NUMERIC(20, 9) NOT NULL,
		vqdelay NUMERIC(20, 9) NOT NULL,
		rqdelay NUMERIC(20, 9) NOT NULL,
		owdelay NUMERIC(20, 9) NOT NULL,
		flow TEXT NOT NULL
	);
	CREATE INDEX r_vts ON r (vts);
	CREATE INDEX r_kind_ue_vts ON r (kind, ue, vts);

	CREATE VIEW o (ofs, d) AS
		SELECT TRUNC(hts)::BIGINT AS ofs, vts - (hts - TRUNC(hts)) AS d
		FROM r ORDER BY pk LIMIT 1;

	CREATE OR REPLACE FUNCTION get_d()
	    RETURNS NUMERIC(20, 9) AS $F$
		-- SELECT d FROM o;
		SELECT vts - (hts - TRUNC(hts)) FROM r ORDER BY pk LIMIT 1;
	$F$ LANGUAGE SQL
	    IMMUTABLE -- strictly not, but in practice
	    PARALLEL SAFE;

	CREATE OR REPLACE FUNCTION fqdelay(IN curue "char")
	    RETURNS TABLE(
		dts NUMERIC(20, 9),
		msvqdelay NUMERIC(20, 6),
		msrqdelay NUMERIC(20, 6),
		msowdelay NUMERIC(20, 6)
	    ) AS $F$
		SELECT vts - get_d(),
		    vqdelay * 1000, rqdelay * 1000, owdelay * 1000
		FROM r
		WHERE kind='1' AND ue=curue
		ORDER BY vts;
	$F$ LANGUAGE SQL
	    STABLE
	    PARALLEL SAFE
	    ROWS 250000;

	CREATE OR REPLACE FUNCTION fbandwidth(IN curue "char")
	    RETURNS TABLE(
		dts NUMERIC(20, 9),
		load NUMERIC(10, 6),
		rcapacity NUMERIC(10, 6),
		vcapacity NUMERIC(10, 6),
		pktsizebytes INTEGER
	    ) AS $F$
		WITH
		    prefiltered AS (
			SELECT vts, psize, vbw, rbw FROM r
			WHERE kind='1' AND ue=curue
			ORDER BY vts
		    ),
		    calculated AS (
			SELECT vts, psize, vbw::NUMERIC, rbw::NUMERIC,
			    -- https://stackoverflow.com/a/77051480/2171120
			    CASE WHEN (COUNT(*) OVER wtim) > 20
			    THEN 8 * (sum(psize) OVER wnum) / NULLIF(vts - min(vts) OVER wnum, 0)
			    ELSE 8 * (sum(psize) OVER wtim) / NULLIF(vts - min(vts) OVER wtim, 0)
			    END AS bps
			           -- NUMERIC so the TRUNC below does not cast it to double
			FROM prefiltered
			WINDOW
			    wnum AS (ORDER BY vts
				ROWS BETWEEN 20 PRECEDING AND CURRENT ROW
				EXCLUDE CURRENT ROW),
			    wtim AS (ORDER BY vts
				RANGE BETWEEN 0.1 PRECEDING AND CURRENT ROW
				EXCLUDE CURRENT ROW),
			    wts AS (ORDER BY vts)
			ORDER BY vts
		    )
		SELECT vts - get_d() AS dts,
		    (TRUNC(bps) / 1000000)::NUMERIC(10,6) AS load,
		    (TRUNC(rbw) / 1000000)::NUMERIC(10,6) AS rcapacity,
		    (TRUNC(vbw) / 1000000)::NUMERIC(10,6) AS vcapacity,
		    psize AS pktsizebytes
		FROM calculated ORDER BY vts;
	$F$ LANGUAGE SQL
	    STABLE
	    PARALLEL SAFE
	    ROWS 250000;

	CREATE OR REPLACE FUNCTION maptime(IN graphtime NUMERIC)
	    RETURNS NUMERIC(20, 9) AS $F$
		SELECT get_d() + graphtime;
	$F$ LANGUAGE SQL
	    STABLE
	    RETURNS NULL ON NULL INPUT
	    PARALLEL SAFE;

	RETURN sid;
END;
$$ LANGUAGE plpgsql;

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
$$ LANGUAGE plpgsql;

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
$$ LANGUAGE plpgsql;

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
$$ LANGUAGE plpgsql;

COMMIT;
