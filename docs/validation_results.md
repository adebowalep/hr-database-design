# Validation Results - Tech ABC Corp HR Database (original course dataset)

> **Historical record.** These results were produced before the later hardening work. Section 3 (salary security) used the original grant script, which let the read-only role read `proj_stg`; see [security/README.md](security/README.md). Current automated results are in [test_results/](test_results/README.md). Paths such as `erd/` are now `docs/erd/`, and `validation_checks.sql` is now `sql/validation_checks.sql`.

Everything below was run against a **local PostgreSQL 17.11** server (not the Udacity workspace, which was not accessible from here). The full pipeline was run on a brand-new database loaded only from the supplied `StageTableLoad.sql`: `run_all.sql` (schema, ETL, view, procedure, security, CRUD) completed with exit code 0 and no errors. Output below comes from `validation_checks.sql`.

## 1. Data checks (actual output)
```
                     check_name                      |  actual  | expected 
-----------------------------------------------------+----------+----------
 staging rows = job_assignment rows                  |      205 |      205
 distinct Emp_ID = employee rows                     |      199 |      199
 salary rows = staging rows                          |      205 |      205
 salary total matches staging total                  | 22060329 | 22060329
 Toni Lembeck job records                            |        2 |        2
 employees with exactly one current job              |      199 |      199
 employees with 2+ current jobs                      |        0 |        0
 orphan assignments (no employee/job/dept)           |        0 |        0
 assignments whose manager_id is missing in employee |        0 |        0
 assignments with NULL manager (President only)      |        1 |        1
 duplicate employee emails                           |        0 |        0
 assignments with end_date before start_date         |        0 |        0
 placeholder 2100 dates remaining                    |        0 |        0
 current headcount (sum of Q5 query)                 |      199 |      199
 job table rows after CRUD Q2-Q4 (back to original)  |       10 |       10
(15 rows)
```
## 2. Constraints enforced (actual output; each statement is expected to fail and is rolled back)
```
psql:validation_checks.sql:21: ERROR:  insert or update on table "job_assignment" violates foreign key constraint "fk_assignment_employee"
DETAIL:  Key (employee_id)=(999999) is not present in table "employee".
psql:validation_checks.sql:22: ERROR:  update or delete on table "department" violates foreign key constraint "fk_assignment_department" on table "job_assignment"
DETAIL:  Key (department_id)=(3) is still referenced from table "job_assignment".
psql:validation_checks.sql:23: ERROR:  new row for relation "employee_salary" violates check constraint "ck_salary_positive"
DETAIL:  Failing row contains (206, 1, -5.00).
```
## 3. Salary table-level security (actual output)
```
 rolname  | can_read_salary | can_read_other_tables | can_write 
----------+-----------------+-----------------------+-----------
 NoMgr    | f               | t                     | f
 hr_read  | f               | t                     | f
 hr_staff | t               | t                     | t
(3 rows)
```
`screenshots/q7_security_test_output.txt` shows the same restriction in practice: as `NoMgr`, `SELECT * FROM employee_salary` fails with *permission denied*; as `hr_staff` the salary is returned.

## 4. Physical ERD vs. database (automated comparison, actual output)
```
DB columns: 57 ERD columns: 28
missing in ERD: only the two optional views (not tables)
missing in DB: []
type mismatches: []
FK match: True 7
PK match: True 7
```
All 28 table columns, their data types, 7 primary keys and 7 foreign keys in `erd/physical_erd.png` match `information_schema` of the built database.

## 5. Data profiling of `proj_stg` (actual results)
| Item | Result |
|---|---|
| Rows / distinct Emp_ID / distinct emails | 205 / 199 / 199 (the project text says 206 records; that figure counts the Excel header row) |
| Employees with 2 rows (job history) | 6: Eric Baxter, Melinda Fisher, Abby Lockhart, Edward Eslser, Lori Scatchard, Toni Lembeck |
| Departments / job titles / locations / education levels | 5 / 10 / 5 / 7 |
| end_dt in year 2100 | 199 rows (one per employee, each a different date, e.g. 2100-01-01, 2100-01-02): treated as placeholder for "current job" and stored as NULL. Only 6 rows have a real end date |
| Missing values (NULL) | none. Manager text `None` appears once (the President) |
| Formatting problems | 3 untrimmed values and double spaces in names (e.g. "Eric  Baxter"); city typo "Minnapolis"; leading tabs in date strings (dates still load) |
| start_dt earlier than hire_dt | 6 rows: for employees with history the source hire_dt equals the date of their LAST job change. Stored hire_date = earliest job start date |
| Salary range | 26,050 - 540,000 |

## 6. Known limitations / not verified
* Lucidchart was not accessible. ERDs were generated by `erd/generate_erds.py` (PNG) with `.drawio` files as editable sources. The `.drawio` files are valid XML, but were **not opened in diagrams.net** here.
* Screenshots are PNG renderings of the **real psql output** (text captured from the executions listed above and drawn onto a terminal-style image); they are not literal operating-system screen grabs. The raw text for each is saved next to it in `screenshots/*.txt`. Q1's image shows the first 12 of 199 rows (marked on the image); the full result is in `q1_full_output.txt`.
* The deck was checked visually by exporting it to PDF with Keynote; it was not opened in PowerPoint.
* `NoMgr` is created without a password; set one before using it as a real login.
