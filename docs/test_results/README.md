# Test results (actually executed)

The results in the first table and the checks after it are **local** runs on macOS: PostgreSQL 17.11 (Homebrew), psql 17, executed on 2026-11-18 with `psql -v ON_ERROR_STOP=1 -f tests/run_tests.sql`. Exit status of every run below was 0.
The two datasets are different and must not be confused:

| Dataset | Rows / employees | PASS | FAIL | INFO | Output |
|---|---|---|---|---|---|
| **Synthetic** (fictional, in this repo) | 11 / 9 | 183 | 0 | 3 | [synthetic_dataset_pg17.txt](synthetic_dataset_pg17.txt) |
| **Original course dataset** (local only, not in this repo) | 205 / 199 | 181 | 0 | 3 | [original_dataset_pg17.txt](original_dataset_pg17.txt) |

The two output files were regenerated on 2026-11-18 after the course employee names were removed from the dataset-specific assertions (the assertion count is unchanged); they contain no course employee names. The counts differ because dataset-specific expectations (`50_dataset_expectations.sql`) differ: 14 synthetic vs 12 original.
INFO rows are informational and never count as PASS or FAIL.

Other checks run locally (PostgreSQL 17.11 (Homebrew)):
* **ETL atomicity** ([output](etl_atomicity_synthetic_pg17.txt)): an induced numeric overflow in ETL step 4 (after locations, employees and assignments were inserted) rolled everything back; all target tables had 0 rows. Result: PASS.
* **Negative controls**: the suite exited 3 (failed) on copies of the synthetic database after: deleting a salary row, altering a salary, granting `hr_read` SELECT on `employee_salary`, granting `hr_read` SELECT on `proj_stg`, and dropping the self-manager CHECK constraint.
* **Guarded reset**: `reset_dev.sql` without or with a wrong `confirm_reset` dropped nothing; with the right name it dropped the HR objects, and `run_all.sql` plus the suite then passed again.
* **Backup/restore** (`pg_dump -Fc` then `pg_restore` into a new database, synthetic data): the test suite passed on the restored copy.

## GitHub Actions (independently checked through the GitHub API and run logs, 2026-11-18)
[Run 44324800766](https://github.com/adebowalep/hr-database-design/actions/runs/44324800766): workflow `database-tests` (`.github/workflows/tests.yml`), repository `adebowalep/hr-database-design`, `push` to `main`, commit `67e0cc8d082c6a83380f7bbc9e7b531942ce4f02`, started 2026-11-18 14:29 UTC, conclusion **success**.

| Job | Server version in the log | Conclusion |
|---|---|---|
| sql-tests (15) | PostgreSQL 15.20 | success |
| sql-tests (16) | PostgreSQL 16.16 | success |
| sql-tests (17) | PostgreSQL 17.12 | success |

In each job these steps completed successfully: start container, checkout, psql check, create database + load **synthetic** data + schema + ETL + security (`run_all.sql`), full test suite (`tests/run_tests.sql`), five negative controls, ETL atomicity test, safe reset and rebuild (reset refused without confirmation, then reset, rebuild and the suite again). Runner client was psql 18.6 on Ubuntu.

What this does not show: the workflow runs `psql -q`, so the logs do not print the number of assertions; a step succeeding means the suite exited 0. This is a single run on one commit and says nothing about future runs. CI uses only the synthetic dataset; the original-dataset results above are local only.

Not executed anywhere: Windows.
