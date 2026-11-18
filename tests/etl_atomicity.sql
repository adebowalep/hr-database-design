-- =====================================================================
-- ETL atomicity test: a failure in the middle of the ETL must leave the target tables empty.
--
-- DESTRUCTIVE to the database it runs in (it corrupts staging on purpose), so it refuses to run unless the
-- database name ends in _etl_atomicity. Prerequisite: a database with only proj_stg loaded (synthetic data):
--     createdb hr_etl_atomicity
--     psql -d hr_etl_atomicity -f data/synthetic/synthetic_proj_stg.sql
--     psql -d hr_etl_atomicity -f tests/etl_atomicity.sql
-- Exit status 0 = target tables were empty after the failed ETL; 3 = leftovers or script error.
--
-- How the failure is induced: one salary of 2,000,000,000 passes the preflight (it is positive) but overflows
-- NUMERIC(10,2) in step 4 of the ETL, AFTER locations, employees and job_assignments were already inserted.
-- =====================================================================
SELECT (current_database() LIKE '%\_etl\_atomicity') AS guard_ok \gset
\if :guard_ok
\else
  \echo 'etl_atomicity.sql: refusing to run: database name must end with _etl_atomicity'
  \quit
\endif

\set ON_ERROR_STOP on
\ir ../sql/schema.sql
UPDATE proj_stg SET salary = 2000000000 WHERE emp_id = 'S0003';

\echo '--- running the ETL; the next ERROR (numeric field overflow) is EXPECTED ---'
\set ON_ERROR_STOP off
\ir ../sql/etl_from_proj_stg.sql
\set ON_ERROR_STOP on

SELECT (SELECT count(*) FROM location) + (SELECT count(*) FROM department) + (SELECT count(*) FROM job)
     + (SELECT count(*) FROM education_level) + (SELECT count(*) FROM employee)
     + (SELECT count(*) FROM job_assignment) + (SELECT count(*) FROM employee_salary) AS leftover_rows \gset
\echo 'rows left in target tables after the failed ETL:' :leftover_rows
\if :leftover_rows
  \echo 'FAIL: the failed ETL left partial data behind'
  SELECT 1 / 0;
\else
  \echo 'PASS: the failed ETL left the target tables empty'
\endif
