-- =====================================================================
-- reset_dev.sql  |  DESTRUCTIVE: drops the HR objects so schema.sql can be run again.
-- For disposable development/demo databases only.
--
-- Safety: you must pass the exact name of the current database as a confirmation, so a stray
-- run against the wrong database does nothing:
--     psql -d hr_demo -v confirm_reset=hr_demo -f sql/reset_dev.sql
--
-- Drops only: the two views, the stored procedure and the seven HR tables, in dependency order
-- (no CASCADE). Does NOT touch proj_stg, roles, or any other object. If something you did not
-- expect depends on these tables, the DROP fails and nothing is removed (single transaction).
-- =====================================================================
\if :{?confirm_reset}
\else
  \echo 'reset_dev.sql: refusing to run. Pass -v confirm_reset=<current database name>.'
  \quit
\endif
SELECT (:'confirm_reset' = current_database()) AS confirmed \gset
\if :confirmed
\else
  \echo 'reset_dev.sql: confirm_reset does not match the current database. Nothing was dropped.'
  \quit
\endif

\echo 'Resetting HR objects in database' :DBNAME
BEGIN;
DROP VIEW      IF EXISTS v_employee_full_hr;
DROP VIEW      IF EXISTS v_employee_directory;
DROP PROCEDURE IF EXISTS sp_employee_job_history(varchar, refcursor);
DROP TABLE     IF EXISTS employee_salary;
DROP TABLE     IF EXISTS job_assignment;
DROP TABLE     IF EXISTS employee;
DROP TABLE     IF EXISTS education_level;
DROP TABLE     IF EXISTS location;
DROP TABLE     IF EXISTS department;
DROP TABLE     IF EXISTS job;
DROP FUNCTION  IF EXISTS etl_check_staging(regclass);
COMMIT;
