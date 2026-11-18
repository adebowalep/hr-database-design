-- =====================================================================
-- Security regression tests: who can read salary, and who can write.
-- Requires: schema + ETL + sql/optional/*.sql already applied; run as a superuser
-- (needed to SET ROLE to the test roles).
-- =====================================================================
-- A role with no memberships and no grants: stands for "any other database user".
CREATE ROLE test_outsider NOLOGIN;            -- rolled back with the rest of the test transaction

-- ---- Role design ----
CALL pg_temp.assert_eq('security', 'NoMgr is a member of hr_read',    pg_has_role('NoMgr', 'hr_read', 'member'), true);
CALL pg_temp.assert_eq('security', 'NoMgr is NOT a member of hr_staff', pg_has_role('NoMgr', 'hr_staff', 'member'), false);
CALL pg_temp.assert_eq('security', 'hr_read is NOT a member of hr_staff', pg_has_role('hr_read', 'hr_staff', 'member'), false);
CALL pg_temp.assert_sql('security', 'no role other than NoMgr is a member of hr_read',
    $$ SELECT count(*) FROM pg_auth_members m JOIN pg_roles g ON g.oid = m.roleid
        WHERE g.rolname = 'hr_read' AND m.member <> (SELECT oid FROM pg_roles WHERE rolname = 'NoMgr') $$, '0');

-- ---- Catalog scan: every object that exposes salary data ----
-- (a) columns with "salary" in the name, in any ordinary table / view / partitioned table outside system schemas
-- (b) any view that depends on employee_salary
CREATE TEMP TABLE salary_objects AS
SELECT DISTINCT c.oid::regclass AS obj, c.relname::text AS name
FROM pg_attribute a
JOIN pg_class c     ON c.oid = a.attrelid AND c.relkind IN ('r', 'v', 'm', 'p', 'f')
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE a.attname ILIKE '%salary%' AND NOT a.attisdropped AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
UNION
SELECT c.oid::regclass, c.relname::text
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class c   ON c.oid = r.ev_class
WHERE d.refobjid = 'employee_salary'::regclass AND c.oid <> d.refobjid;

DO $$
DECLARE names text;
BEGIN
    SELECT string_agg(name, ', ' ORDER BY name) INTO names FROM salary_objects;
    CALL pg_temp.info('security', 'objects exposing salary data', names);
END $$;

-- No salary-bearing object (any column) is readable by the read-only roles, an outsider, or PUBLIC
DO $$
DECLARE o record; r text;
BEGIN
    FOR o IN SELECT * FROM salary_objects ORDER BY name LOOP
        FOREACH r IN ARRAY ARRAY['hr_read', 'NoMgr', 'test_outsider', 'public'] LOOP
            CALL pg_temp.assert_eq('security', r || ' cannot SELECT any column of ' || o.name,
                                   has_any_column_privilege(r, o.obj, 'SELECT'), false);
        END LOOP;
    END LOOP;
END $$;

-- ---- Read-only role: allowed reads ----
CALL pg_temp.expect_success('security', 'NoMgr can read the employee directory view', 'NoMgr', 'SELECT emp_nm, job_title FROM v_employee_directory', 1);
CALL pg_temp.expect_success('security', 'NoMgr can read employee',        'NoMgr', 'SELECT * FROM employee', 1);
CALL pg_temp.expect_success('security', 'NoMgr can read job_assignment',  'NoMgr', 'SELECT * FROM job_assignment', 1);
CALL pg_temp.expect_success('security', 'NoMgr can read lookup tables',   'NoMgr',
    'SELECT 1 FROM job, department, location, education_level LIMIT 1', 1);
CALL pg_temp.assert_eq('security', 'NoMgr can execute the job-history procedure',
    has_function_privilege('NoMgr', 'sp_employee_job_history(varchar, refcursor)', 'EXECUTE'), true);

-- ---- Read-only role: denied salary reads (42501 = insufficient_privilege) ----
CALL pg_temp.expect_sqlstate('security', 'NoMgr: SELECT employee_salary',            'NoMgr', 'SELECT * FROM employee_salary', '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: SELECT salary_amount column only',  'NoMgr', 'SELECT salary_amount FROM employee_salary', '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: SELECT v_employee_full_hr',         'NoMgr', 'SELECT salary FROM v_employee_full_hr', '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: SELECT salary from staging proj_stg', 'NoMgr', 'SELECT emp_id, salary FROM public.proj_stg', '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: SELECT * from staging proj_stg',      'NoMgr', 'SELECT * FROM proj_stg', '42501');
CALL pg_temp.expect_sqlstate('security', 'hr_read: SELECT salary from staging proj_stg', 'hr_read', 'SELECT salary FROM proj_stg', '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: salary via join to employee_salary', 'NoMgr',
    'SELECT e.full_name, s.salary_amount FROM employee e JOIN job_assignment a USING (employee_id) JOIN employee_salary s USING (assignment_id)', '42501');

-- ---- Read-only role: writes denied ----
CALL pg_temp.expect_sqlstate('security', 'NoMgr: INSERT job',               'NoMgr', $$INSERT INTO job (job_title) VALUES ('Intruder')$$, '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: UPDATE employee',          'NoMgr', $$UPDATE employee SET full_name = 'X'$$, '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: DELETE job_assignment',    'NoMgr', 'DELETE FROM job_assignment', '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: INSERT employee_salary',   'NoMgr', 'INSERT INTO employee_salary (assignment_id, salary_amount) VALUES (1, 1)', '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: TRUNCATE employee',        'NoMgr', 'TRUNCATE employee CASCADE', '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: DROP TABLE employee',      'NoMgr', 'DROP TABLE employee CASCADE', '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: CREATE TABLE in public',   'NoMgr', 'CREATE TABLE public.leak AS SELECT 1', '42501');
CALL pg_temp.expect_sqlstate('security', 'NoMgr: INSERT into staging',      'NoMgr', 'INSERT INTO proj_stg (emp_id) VALUES (''X'')', '42501');

-- ---- Other users: nothing through PUBLIC or an unrelated role ----
CALL pg_temp.expect_sqlstate('security', 'outsider: SELECT employee_salary', 'test_outsider', 'SELECT * FROM employee_salary', '42501');
CALL pg_temp.expect_sqlstate('security', 'outsider: SELECT v_employee_full_hr', 'test_outsider', 'SELECT * FROM v_employee_full_hr', '42501');
CALL pg_temp.expect_sqlstate('security', 'outsider: SELECT proj_stg',        'test_outsider', 'SELECT salary FROM proj_stg', '42501');
CALL pg_temp.expect_sqlstate('security', 'outsider: SELECT employee',        'test_outsider', 'SELECT * FROM employee', '42501');
CALL pg_temp.expect_sqlstate('security', 'outsider: CREATE TABLE in public', 'test_outsider', 'CREATE TABLE public.leak2 AS SELECT 1', '42501');

-- ---- HR-authorized role ----
CALL pg_temp.expect_success('security', 'hr_staff can read employee_salary',     'hr_staff', 'SELECT * FROM employee_salary', 1);
CALL pg_temp.expect_success('security', 'hr_staff can read v_employee_full_hr',  'hr_staff', 'SELECT salary FROM v_employee_full_hr', 1);
CALL pg_temp.expect_success('security', 'hr_staff can read the directory view',  'hr_staff', 'SELECT * FROM v_employee_directory', 1);
CALL pg_temp.expect_success('security', 'hr_staff can update a salary',          'hr_staff', 'UPDATE employee_salary SET salary_amount = salary_amount + 1', 1);
CALL pg_temp.expect_success('security', 'hr_staff can insert a job',             'hr_staff', $$INSERT INTO job (job_title) VALUES ('Test Title')$$, 1);
-- least privilege for HR too: no DDL, no TRUNCATE, no access to the raw staging copy, no role management
CALL pg_temp.expect_sqlstate('security', 'hr_staff: TRUNCATE employee_salary denied', 'hr_staff', 'TRUNCATE employee_salary', '42501');
CALL pg_temp.expect_sqlstate('security', 'hr_staff: DROP TABLE denied',        'hr_staff', 'DROP TABLE employee_salary CASCADE', '42501');
CALL pg_temp.expect_sqlstate('security', 'hr_staff: CREATE TABLE denied',      'hr_staff', 'CREATE TABLE public.hr_leak AS SELECT 1', '42501');
CALL pg_temp.expect_sqlstate('security', 'hr_staff: staging table not needed, denied', 'hr_staff', 'SELECT salary FROM proj_stg', '42501');
CALL pg_temp.expect_sqlstate('security', 'hr_staff: CREATE ROLE denied',       'hr_staff', 'CREATE ROLE sneaky', '42501');

-- ---- Views run with the caller's privileges, so a mistaken GRANT on the salary view still cannot expose salary ----
CALL pg_temp.assert_sql('security', 'v_employee_directory uses security_invoker',
    $$ SELECT coalesce(reloptions @> ARRAY['security_invoker=true'], false) FROM pg_class WHERE oid = 'v_employee_directory'::regclass $$, 'true');
CALL pg_temp.assert_sql('security', 'v_employee_full_hr uses security_invoker',
    $$ SELECT coalesce(reloptions @> ARRAY['security_invoker=true'], false) FROM pg_class WHERE oid = 'v_employee_full_hr'::regclass $$, 'true');
CALL pg_temp.expect_sqlstate('security', 'accidental GRANT on salary view to hr_read still blocked by base-table privileges', NULL,
    $q$ DO $d$ BEGIN
            GRANT SELECT ON v_employee_full_hr TO hr_read;
            SET LOCAL ROLE hr_read;
            PERFORM salary FROM v_employee_full_hr;
        END $d$ $q$, '42501');
