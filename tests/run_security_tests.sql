-- Security regression tests only (needs schema + ETL + optional/*.sql applied; run as superuser).
-- Usage (from any directory):  psql -d hr -v ON_ERROR_STOP=1 -f tests/run_security_tests.sql
-- The whole run is one transaction that is always rolled back: the database is not modified.
\set ON_ERROR_STOP on
\pset pager off
BEGIN;
\ir 00_helpers.sql
\ir 10_security.sql
\ir 99_report.sql
ROLLBACK;
