-- =====================================================================
-- Test helpers (session-local; nothing here is stored in the database).
-- Included by tests/run_tests.sql inside ONE transaction that is always rolled back,
-- so running the tests never changes the database.
--
--   test_results            temp table collecting PASS / FAIL / INFO rows
--   CALL pg_temp.assert_eq       actual must equal expected (literal values)
--   CALL pg_temp.assert_sql      a query returning one value must equal the expected text
--   CALL pg_temp.expect_sqlstate statement (optionally run as a role) must fail with a given SQLSTATE
--   CALL pg_temp.expect_success  statement (optionally run as a role) must succeed and return >= N rows
--   CALL pg_temp.info            informational line (never counts as PASS or FAIL)
--
-- Statements under test run in a sub-transaction that is always rolled back, so even a
-- statement that unexpectedly SUCCEEDS cannot leave data behind.
-- =====================================================================
CREATE TEMP TABLE test_results (
    seq       serial PRIMARY KEY,
    category  text NOT NULL,
    test_name text NOT NULL,
    status    text NOT NULL CHECK (status IN ('PASS', 'FAIL', 'INFO')),
    detail    text
);

CREATE FUNCTION pg_temp.record(p_cat text, p_name text, p_ok boolean, p_detail text) RETURNS void
LANGUAGE sql AS $$
    INSERT INTO test_results (category, test_name, status, detail)
    VALUES (p_cat, p_name, CASE WHEN p_ok THEN 'PASS' ELSE 'FAIL' END, p_detail);
$$;

CREATE PROCEDURE pg_temp.info(p_cat text, p_name text, p_detail text)
LANGUAGE sql AS $$
    INSERT INTO test_results (category, test_name, status, detail) VALUES (p_cat, p_name, 'INFO', p_detail);
$$;

CREATE PROCEDURE pg_temp.assert_eq(p_cat text, p_name text, p_actual anyelement, p_expected anyelement)
LANGUAGE sql AS $$
    SELECT pg_temp.record(p_cat, p_name, p_actual IS NOT DISTINCT FROM p_expected,
                          'actual=' || coalesce(p_actual::text, 'NULL') || ' expected=' || coalesce(p_expected::text, 'NULL'));
$$;

-- Run a query that returns one value and compare it (as text) with the expected text.
CREATE PROCEDURE pg_temp.assert_sql(p_cat text, p_name text, p_query text, p_expected text)
LANGUAGE plpgsql AS $$
DECLARE got text;
BEGIN
    EXECUTE p_query INTO got;
    PERFORM pg_temp.record(p_cat, p_name, got IS NOT DISTINCT FROM p_expected,
                           'actual=' || coalesce(got, 'NULL') || ' expected=' || coalesce(p_expected, 'NULL'));
END $$;

-- The statement must fail with exactly p_sqlstate. p_role NULL = run as the session user.
CREATE PROCEDURE pg_temp.expect_sqlstate(p_cat text, p_name text, p_role text, p_sql text, p_sqlstate text)
LANGUAGE plpgsql AS $$
DECLARE got text := 'no error';
BEGIN
    IF p_role IS NOT NULL THEN EXECUTE format('SET ROLE %I', p_role); END IF;
    BEGIN
        EXECUTE p_sql;
        RAISE EXCEPTION 'statement succeeded' USING ERRCODE = 'XXTST';   -- forces rollback of any side effect
    EXCEPTION
        WHEN SQLSTATE 'XXTST' THEN got := 'no error';
        WHEN OTHERS THEN got := SQLSTATE;
    END;
    RESET ROLE;
    PERFORM pg_temp.record(p_cat, p_name, got = p_sqlstate,
        'role=' || coalesce(p_role, current_user) || ' expected SQLSTATE ' || p_sqlstate || ', got ' || got);
END $$;

-- The statement must succeed and affect/return at least p_min_rows rows (effects are rolled back).
CREATE PROCEDURE pg_temp.expect_success(p_cat text, p_name text, p_role text, p_sql text, p_min_rows integer DEFAULT 0)
LANGUAGE plpgsql AS $$
DECLARE n bigint := -1; err text := NULL;
BEGIN
    IF p_role IS NOT NULL THEN EXECUTE format('SET ROLE %I', p_role); END IF;
    BEGIN
        EXECUTE p_sql;
        GET DIAGNOSTICS n = ROW_COUNT;
        RAISE EXCEPTION 'rollback' USING ERRCODE = 'XXTST';
    EXCEPTION
        WHEN SQLSTATE 'XXTST' THEN NULL;
        WHEN OTHERS THEN err := SQLSTATE;
    END;
    RESET ROLE;
    PERFORM pg_temp.record(p_cat, p_name, err IS NULL AND n >= p_min_rows,
        'role=' || coalesce(p_role, current_user) || CASE WHEN err IS NULL THEN ', rows=' || n || ' (min ' || p_min_rows || ')' ELSE ', failed with SQLSTATE ' || err END);
END $$;
