-- =====================================================================
-- Full automated test suite. Needs a database built by sql/run_all.sql; run as a superuser (role switching).
--   psql -d <db> -v ON_ERROR_STOP=1 -f tests/run_tests.sql        (any working directory)
-- Exit status 0 = every assertion passed, 3 = at least one FAILED (or a script error).
-- The whole run is a single transaction that is ALWAYS rolled back: the database is not modified, and
-- nothing is dropped. Temporary helpers live in pg_temp and disappear with the session.
-- =====================================================================
\set ON_ERROR_STOP on
\pset pager off
BEGIN;
\ir 00_helpers.sql
\ir 10_security.sql
\ir 20_data_assertions.sql
\ir 25_etl_preflight.sql
\ir 30_constraints.sql
\ir 35_schema_matches_erd.sql
\ir 40_queries.sql
\ir 50_dataset_expectations.sql
\ir 99_report.sql
ROLLBACK;
