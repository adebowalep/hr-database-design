-- Builds the whole project in order on an EMPTY database that already contains proj_stg.
--   psql -d <db> -v ON_ERROR_STOP=1 -f sql/run_all.sql        (works from any directory: \ir is relative to this file)
-- Prerequisite: proj_stg exists (data/synthetic/synthetic_proj_stg.sql, or the course's StageTableLoad.sql).
-- Run as a superuser: the security script creates roles.
-- This script never drops anything; schema.sql stops if the tables already exist (see reset_dev.sql).
\set ON_ERROR_STOP on
\ir schema.sql
\ir etl_from_proj_stg.sql
\ir optional/01_employee_view.sql
\ir optional/02_stored_procedure.sql
\ir optional/03_salary_security.sql
\ir crud_queries.sql
