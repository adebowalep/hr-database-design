# Test results (actually executed)

All runs: local PostgreSQL 17.11 (Homebrew) (Homebrew, macOS), psql 17, executed on 2026-11-18 with `psql -v ON_ERROR_STOP=1 -f tests/run_tests.sql`. Exit status of every run below was 0.
The two datasets are different and must not be confused:

| Dataset | Rows / employees | PASS | FAIL | INFO | Output |
|---|---|---|---|---|---|
| **Synthetic** (fictional, in this repo) | 11 / 9 | 183 | 0 | 3 | [synthetic_dataset_pg17.txt](synthetic_dataset_pg17.txt) |
| **Original course dataset** (local only, not in this repo) | 205 / 199 | 181 | 0 | 3 | [original_dataset_pg17.txt](original_dataset_pg17.txt) |

The counts differ because dataset-specific expectations (`50_dataset_expectations.sql`) differ: 14 synthetic vs 12 original.
INFO rows are informational and never count as PASS or FAIL.

Other checks run locally (PostgreSQL 17.11 (Homebrew)):
* **ETL atomicity** ([output](etl_atomicity_synthetic_pg17.txt)): an induced numeric overflow in ETL step 4 (after locations, employees and assignments were inserted) rolled everything back; all target tables had 0 rows. Result: PASS.
* **Negative controls**: the suite exited 3 (failed) on copies of the synthetic database after: deleting a salary row, altering a salary, granting `hr_read` SELECT on `employee_salary`, granting `hr_read` SELECT on `proj_stg`, and dropping the self-manager CHECK constraint.
* **Guarded reset**: `reset_dev.sql` without or with a wrong `confirm_reset` dropped nothing; with the right name it dropped the HR objects, and `run_all.sql` plus the suite then passed again.
* **Backup/restore** (`pg_dump -Fc` then `pg_restore` into a new database, synthetic data): the test suite passed on the restored copy.

Not executed: PostgreSQL 15 and 16 (CI matrix entries exist but are unverified), the GitHub Actions workflow itself, Windows.
