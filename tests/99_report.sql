-- =====================================================================
-- Report: prints every result, a summary, and fails (non-zero psql exit status)
-- if any assertion FAILED. INFO rows are informational and never count as PASS/FAIL.
-- =====================================================================
\echo
\echo ===== Test results =====
SELECT seq, status, category, test_name, detail FROM test_results ORDER BY seq;
\echo ===== Summary =====
SELECT category, count(*) FILTER (WHERE status = 'PASS') AS passed,
                 count(*) FILTER (WHERE status = 'FAIL') AS failed,
                 count(*) FILTER (WHERE status = 'INFO') AS info
FROM test_results GROUP BY category ORDER BY category;
SELECT count(*) FILTER (WHERE status = 'PASS') AS passed,
       count(*) FILTER (WHERE status = 'FAIL') AS failed,
       count(*) FILTER (WHERE status = 'INFO') AS info_only
FROM test_results;
DO $$
DECLARE n_fail integer;
BEGIN
    SELECT count(*) INTO n_fail FROM test_results WHERE status = 'FAIL';
    IF n_fail > 0 THEN
        RAISE EXCEPTION '% assertion(s) FAILED - see the FAIL rows above', n_fail USING ERRCODE = 'P0001';
    END IF;
END $$;
