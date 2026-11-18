# Salary security: defect, fix and regression results

## The defect (found by audit, reproduced before fixing)
`sql/optional/03_salary_security.sql` originally did:

```sql
GRANT SELECT ON ALL TABLES IN SCHEMA public TO hr_read;
REVOKE ALL ON employee_salary, v_employee_full_hr FROM hr_read;
```

That is a deny-list. It protected the two objects named in the `REVOKE` but not the raw staging table
`proj_stg`, which holds a `salary` column for every employee and lives in the same schema. As the
read-only login `NoMgr` (member of `hr_read`), reproduced on the local PostgreSQL 17.11 database loaded
with the course data:

```
SELECT emp_id, salary FROM public.proj_stg LIMIT 3;     -> 3 rows returned (permission NOT denied)
SELECT count(*), sum(salary) FROM public.proj_stg;      -> 205 rows, total 22,060,329 (matches employee_salary)
SELECT salary_amount FROM employee_salary;              -> ERROR: permission denied for table employee_salary
```
(Individual salary values from the course data are deliberately not reproduced here.)

The earlier `validation_checks.sql` only tested `employee_salary`, so it reported the restriction as working.

## The fix
* Explicit allow-list: `hr_read` is granted `SELECT` on six named tables and `v_employee_directory`, nothing else.
* `proj_stg` is revoked from `PUBLIC`, `hr_read` and `hr_staff` (owner-only; the ETL runs as the owner). It is kept, not deleted, because the ETL and reconciliation need it.
* `hr_staff` gets DML on the seven HR tables and `SELECT` on both views. No `TRUNCATE`, no DDL, no staging access.
* Both views are `security_invoker = true` (PostgreSQL 15+), so a view runs with the caller's privileges instead of the owner's. A mistaken `GRANT SELECT` on `v_employee_full_hr` therefore still cannot expose salary (tested).
* `CREATE` on schema `public` is revoked from `PUBLIC`.

Not changed: a dedicated `staging` schema was considered. Explicit grants on one table are enough here and keep the course queries and ERDs unchanged.

## Regression test results (`tests/run_security_tests.sql`)
The tests assert expected SQLSTATE codes (`42501` = insufficient_privilege), not just "an error was printed". Each run is one transaction that is rolled back.

| Run | PASS | FAIL | INFO | psql exit status | Output |
|---|---|---|---|---|---|
| Before the fix (original data, old grants) | 45 | 9 | 1 | 3 | [before_fix_security_tests.txt](before_fix_security_tests.txt) |
| After the fix (original data) | 54 | 0 | 1 | 0 | [after_fix_security_tests.txt](after_fix_security_tests.txt) |

The 9 failures before the fix: `hr_read` and `NoMgr` could `SELECT` every column of `proj_stg` (2), `NoMgr` and `hr_read` read `salary` from `proj_stg` through three queries (3), `hr_staff` could read staging (1), the two views were not `security_invoker` (2), and an accidental `GRANT` on the salary view leaked data (1).

These runs used the original course dataset on a local database. The same suite also runs against the synthetic dataset (see the main README).
