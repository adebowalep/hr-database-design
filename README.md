# HR Database Design: Tech ABC Corp

A normalized (3NF) PostgreSQL database that replaces a shared HR spreadsheet for a fast-growing company (10 to 200 employees, 5 offices). It keeps full job history, restricts salary data with table-level security, and loads the original data through an ETL script. Built for the Udacity Data Architecture course.

## Highlights
- **7 tables in 3NF**: `employee`, `job_assignment` (job history and manager link), `employee_salary` (restricted), `job`, `department`, `location`, `education_level`
- **History preserved**: 205 staging rows load to 199 employees and 205 job records. Placeholder 2100 end dates become `NULL` (current job)
- **Salary protection**: own table, `REVOKE`d from the read-only role; `NoMgr` test user
- **Extras**: spreadsheet-style views, stored procedure (`refcursor`), validation checks

## Repository layout
| Path | Contents |
|---|---|
| `sql/schema.sql` | DDL: tables, keys, constraints, indexes |
| `sql/etl_from_proj_stg.sql` | ETL from the staging table with row-count validation |
| `sql/crud_queries.sql` | Queries for the 7 project questions |
| `sql/optional/` | View, stored procedure, salary security and security test |
| `sql/validation_checks.sql` | Integrity and security checks |
| `sql/run_all.sql` | Runs everything in order |
| `docs/erd/` | Conceptual, logical and physical ERDs (PNG and editable `.drawio`) |
| `docs/screenshots/` | Query evidence (rendered from real `psql` output) and raw text |
| `docs/presentation/` | Completed project slide deck |
| `docs/validation_results.md` | Actual test results, data profile, limitations |

## Run it
Requires PostgreSQL 13+ and a staging table `proj_stg` (created by the course's `StageTableLoad.sql`, not included here).
```bash
createdb hr
psql -d hr -f StageTableLoad.sql
cd sql
psql -d hr -f run_all.sql        # superuser needed for role creation
psql -d hr -f validation_checks.sql
```

## Design notes
- `employee` is one row per person. `job_assignment` is one row per job period with `end_date IS NULL` for the current job and `manager_id` pointing back to `employee`.
- Backup policy: Critical (weekly full plus daily incremental). Retention: 7+ years, enforced by `ON DELETE RESTRICT`.
- Data fixes (hire date, name cleanup, typo) are documented in `docs/validation_results.md`.
- `NoMgr` is created without a password; set one before real use.
