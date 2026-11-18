-- DIAGNOSTIC REPORT for the original course dataset (this produced docs/validation_results.md).
-- It prints actual vs expected but does NOT fail automatically. The automated, failing-on-error checks
-- are in tests/ (run tests/run_tests.sql). Several figures below (6 employees with history, 2100 dates, 1 President) are
-- specific to the course data, so this report is not meaningful on the synthetic dataset.
-- Run after run_all.sql. Expected result is shown in the 'expected' column.
\pset pager off
SELECT 'staging rows = job_assignment rows' AS check_name, (SELECT count(*) FROM proj_stg) AS actual, (SELECT count(*) FROM job_assignment) AS expected
UNION ALL SELECT 'distinct Emp_ID = employee rows', (SELECT count(DISTINCT emp_id) FROM proj_stg), (SELECT count(*) FROM employee)
UNION ALL SELECT 'salary rows = staging rows', (SELECT count(*) FROM employee_salary), (SELECT count(*) FROM proj_stg)
UNION ALL SELECT 'salary total matches staging total', (SELECT sum(salary_amount)::int FROM employee_salary), (SELECT sum(salary) FROM proj_stg)
UNION ALL SELECT 'employees with 2 job records (history preserved)', (SELECT count(*) FROM (SELECT employee_id FROM job_assignment GROUP BY 1 HAVING count(*)=2) t), 6
UNION ALL SELECT 'employees with exactly one current job', (SELECT count(*) FROM (SELECT employee_id FROM job_assignment WHERE end_date IS NULL GROUP BY 1 HAVING count(*)=1) t), (SELECT count(*) FROM employee)
UNION ALL SELECT 'employees with 2+ current jobs', (SELECT count(*) FROM (SELECT employee_id FROM job_assignment WHERE end_date IS NULL GROUP BY 1 HAVING count(*)>1) t), 0
UNION ALL SELECT 'orphan assignments (no employee/job/dept)', (SELECT count(*) FROM job_assignment a WHERE NOT EXISTS (SELECT 1 FROM employee e WHERE e.employee_id=a.employee_id) OR NOT EXISTS (SELECT 1 FROM job j WHERE j.job_id=a.job_id) OR NOT EXISTS (SELECT 1 FROM department d WHERE d.department_id=a.department_id)), 0
UNION ALL SELECT 'assignments whose manager_id is missing in employee', (SELECT count(*) FROM job_assignment a WHERE a.manager_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM employee m WHERE m.employee_id=a.manager_id)), 0
UNION ALL SELECT 'assignments with NULL manager (President only)', (SELECT count(*) FROM job_assignment WHERE manager_id IS NULL), 1
UNION ALL SELECT 'duplicate employee emails', (SELECT count(*) FROM (SELECT email FROM employee GROUP BY 1 HAVING count(*)>1) t), 0
UNION ALL SELECT 'assignments with end_date before start_date', (SELECT count(*) FROM job_assignment WHERE end_date < start_date), 0
UNION ALL SELECT 'placeholder 2100 dates remaining', (SELECT count(*) FROM job_assignment WHERE end_date >= DATE '2099-01-01'), 0
UNION ALL SELECT 'current headcount (sum of Q5 query)', (SELECT sum(c) FROM (SELECT count(DISTINCT employee_id) c FROM job_assignment WHERE end_date IS NULL GROUP BY department_id) t)::bigint, (SELECT count(*) FROM employee)
UNION ALL SELECT 'job table rows after CRUD Q2-Q4 (back to original)', (SELECT count(*) FROM job), (SELECT count(DISTINCT trim(job_title)) FROM proj_stg);

-- Foreign keys are enforced (each statement should fail; wrapped in a rolled-back transaction)
\set ON_ERROR_STOP off
BEGIN; INSERT INTO job_assignment (employee_id, job_id, department_id, start_date) VALUES (999999, 1, 1, CURRENT_DATE); ROLLBACK;
BEGIN; DELETE FROM department WHERE department_name = 'IT'; ROLLBACK;
BEGIN; INSERT INTO employee_salary (assignment_id, salary_amount) VALUES (1, -5); ROLLBACK;
\set ON_ERROR_STOP on

-- Table security: who can read salary?
SELECT r.rolname,
       has_table_privilege(r.rolname, 'employee_salary', 'SELECT') AS can_read_salary,
       has_table_privilege(r.rolname, 'proj_stg', 'SELECT')        AS can_read_staging,
       has_table_privilege(r.rolname, 'job', 'SELECT')             AS can_read_other_tables,
       has_table_privilege(r.rolname, 'job', 'INSERT')             AS can_write
FROM pg_roles r WHERE r.rolname IN ('NoMgr','hr_read','hr_staff') ORDER BY 1;
