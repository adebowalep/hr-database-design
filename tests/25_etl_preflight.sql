-- =====================================================================
-- ETL preflight tests: each case copies the loaded staging table into a temp table, corrupts it in one
-- specific way, and checks that etl_check_staging() rejects it with the documented SQLSTATE (EL001..EL015).
-- A clean copy must pass. Everything happens in rolled-back sub-transactions.
-- =====================================================================
CREATE PROCEDURE pg_temp.expect_etl_rejects(p_name text, p_mutation text, p_sqlstate text)
LANGUAGE plpgsql AS $$
BEGIN
    CALL pg_temp.expect_sqlstate('etl-preflight', p_name, NULL,
        $do$ DO $b$ BEGIN
               CREATE TEMP TABLE bad_stg (LIKE proj_stg);
               INSERT INTO bad_stg SELECT * FROM proj_stg;
               $do$ || p_mutation || $do$;
               PERFORM etl_check_staging('pg_temp.bad_stg');
             END $b$ $do$, p_sqlstate);
END $$;

CALL pg_temp.expect_success('etl-preflight', 'unmodified copy of staging passes the preflight', NULL,
    $$ DO $b$ BEGIN CREATE TEMP TABLE bad_stg (LIKE proj_stg); INSERT INTO bad_stg SELECT * FROM proj_stg; PERFORM etl_check_staging('pg_temp.bad_stg'); END $b$ $$, 0);

-- An extra, non-overlapping period for the first employee, with one attribute changed, is used by several cases.
CALL pg_temp.expect_etl_rejects('EL001 missing required value', $m$ UPDATE bad_stg SET email = NULL WHERE emp_id = (SELECT min(emp_id) FROM bad_stg) $m$, 'EL001');
CALL pg_temp.expect_etl_rejects('EL002 same Emp_ID, two names',
    $m$ INSERT INTO bad_stg SELECT emp_id, 'Other Name', email, hire_dt, job_title, salary, department_nm, manager, start_dt - 5000, start_dt - 4000, location, address, city, state, education_lvl FROM bad_stg LIMIT 1 $m$, 'EL002');
CALL pg_temp.expect_etl_rejects('EL003 same Emp_ID, two emails',
    $m$ INSERT INTO bad_stg SELECT emp_id, emp_nm, 'other.mail@example.com', hire_dt, job_title, salary, department_nm, manager, start_dt - 5000, start_dt - 4000, location, address, city, state, education_lvl FROM bad_stg LIMIT 1 $m$, 'EL003');
CALL pg_temp.expect_etl_rejects('EL004 same Emp_ID, two locations',
    $m$ INSERT INTO bad_stg SELECT emp_id, emp_nm, email, hire_dt, job_title, salary, department_nm, manager, start_dt - 5000, start_dt - 4000, 'Elsewhere', address, city, state, education_lvl FROM bad_stg LIMIT 1 $m$, 'EL004');
CALL pg_temp.expect_etl_rejects('EL005 same Emp_ID, two education levels',
    $m$ INSERT INTO bad_stg SELECT emp_id, emp_nm, email, hire_dt, job_title, salary, department_nm, manager, start_dt - 5000, start_dt - 4000, location, address, city, state, 'Other Education' FROM bad_stg LIMIT 1 $m$, 'EL005');
CALL pg_temp.expect_etl_rejects('EL006 one e-mail on two Emp_IDs',
    $m$ INSERT INTO bad_stg SELECT 'ZZ0001', 'Different Person', email, hire_dt, job_title, salary, department_nm, manager, start_dt, end_dt, location, address, city, state, education_lvl FROM bad_stg LIMIT 1 $m$, 'EL006');
CALL pg_temp.expect_etl_rejects('EL007 duplicate (Emp_ID, start date)',
    $m$ INSERT INTO bad_stg SELECT * FROM bad_stg LIMIT 1 $m$, 'EL007');
CALL pg_temp.expect_etl_rejects('EL008 one name on two Emp_IDs (ambiguous manager lookup)',
    $m$ INSERT INTO bad_stg SELECT 'ZZ0002', emp_nm, 'second.person@example.com', hire_dt, job_title, salary, department_nm, manager, start_dt, end_dt, location, address, city, state, education_lvl FROM bad_stg LIMIT 1 $m$, 'EL008');
CALL pg_temp.expect_etl_rejects('EL009 manager matches no employee',
    $m$ UPDATE bad_stg SET manager = 'Nobody Known' WHERE emp_id = (SELECT min(emp_id) FROM bad_stg) $m$, 'EL009');
CALL pg_temp.expect_etl_rejects('EL010 employee is their own manager',
    $m$ UPDATE bad_stg SET manager = emp_nm WHERE emp_id = (SELECT min(emp_id) FROM bad_stg) $m$, 'EL010');
CALL pg_temp.expect_etl_rejects('EL011 end date before start date',
    $m$ UPDATE bad_stg SET end_dt = start_dt - 1 WHERE emp_id = (SELECT min(emp_id) FROM bad_stg) $m$, 'EL011');
CALL pg_temp.expect_etl_rejects('EL012 two current (placeholder end date) rows for one employee',
    $m$ INSERT INTO bad_stg SELECT emp_id, emp_nm, email, hire_dt, job_title, salary, department_nm, manager, start_dt - 5000, DATE '2100-12-31', location, address, city, state, education_lvl FROM bad_stg WHERE end_dt >= DATE '2099-01-01' LIMIT 1 $m$, 'EL012');
CALL pg_temp.expect_etl_rejects('EL013 overlapping job periods',
    $m$ INSERT INTO bad_stg SELECT emp_id, emp_nm, email, hire_dt, job_title, salary, department_nm, manager, start_dt + 1, start_dt + 10, location, address, city, state, education_lvl FROM bad_stg WHERE end_dt >= DATE '2099-01-01' LIMIT 1 $m$, 'EL013');
CALL pg_temp.expect_etl_rejects('EL014 salary not positive',
    $m$ UPDATE bad_stg SET salary = 0 WHERE emp_id = (SELECT min(emp_id) FROM bad_stg) $m$, 'EL014');
CALL pg_temp.expect_etl_rejects('EL015 management cycle (top manager reports to own subordinate)',
    $m$ UPDATE bad_stg t SET manager = (SELECT regexp_replace(trim(r.emp_nm), '\s+', ' ', 'g') FROM bad_stg r
                                         WHERE regexp_replace(trim(r.manager), '\s+', ' ', 'g') = regexp_replace(trim(t.emp_nm), '\s+', ' ', 'g')
                                           AND r.end_dt >= DATE '2099-01-01' LIMIT 1)
         WHERE lower(trim(t.manager)) = 'none' $m$, 'EL015');
