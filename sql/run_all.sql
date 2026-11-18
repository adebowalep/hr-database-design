-- Runs the whole project in order. From psql:  \i run_all.sql   (run from this folder)
-- Prerequisite: proj_stg already exists (INIT DATABASE button / StageTableLoad.sql).
\set ON_ERROR_STOP on
\i schema.sql
\i etl_from_proj_stg.sql
\i optional/01_employee_view.sql
\i optional/02_stored_procedure.sql
\i optional/03_salary_security.sql
\i crud_queries.sql
