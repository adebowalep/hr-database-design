-- =====================================================================
-- Constraint tests: invalid operations must fail with the expected SQLSTATE.
--   23502 not_null_violation   23503 foreign_key_violation   23505 unique_violation
--   23514 check_violation      22003 numeric_value_out_of_range
-- Every statement runs in a sub-transaction that is rolled back, and a snapshot comparison at the end
-- proves nothing was left behind.
-- =====================================================================
CREATE TEMP TABLE row_snapshot AS
SELECT 'employee' AS t, count(*) AS n FROM employee UNION ALL SELECT 'job_assignment', count(*) FROM job_assignment
UNION ALL SELECT 'employee_salary', count(*) FROM employee_salary UNION ALL SELECT 'job', count(*) FROM job
UNION ALL SELECT 'department', count(*) FROM department UNION ALL SELECT 'location', count(*) FROM location
UNION ALL SELECT 'education_level', count(*) FROM education_level;

-- ---- Foreign keys: orphans ----
CALL pg_temp.expect_sqlstate('constraints', 'orphan job_assignment (unknown employee) rejected', NULL,
    'INSERT INTO job_assignment (employee_id, job_id, department_id, start_date) SELECT -1, job_id, department_id, current_date FROM job_assignment LIMIT 1', '23503');
CALL pg_temp.expect_sqlstate('constraints', 'job_assignment with unknown job rejected', NULL,
    'INSERT INTO job_assignment (employee_id, job_id, department_id, start_date, end_date) SELECT employee_id, -1, department_id, DATE ''1900-01-01'', DATE ''1900-02-01'' FROM job_assignment LIMIT 1', '23503');
CALL pg_temp.expect_sqlstate('constraints', 'job_assignment with unknown manager rejected', NULL,
    'UPDATE job_assignment SET manager_id = -1 WHERE assignment_id = (SELECT min(assignment_id) FROM job_assignment)', '23503');
CALL pg_temp.expect_sqlstate('constraints', 'salary for a non-existent assignment rejected', NULL,
    'INSERT INTO employee_salary (assignment_id, salary_amount) VALUES (-1, 100)', '23503');
CALL pg_temp.expect_sqlstate('constraints', 'employee with unknown location rejected', NULL,
    'UPDATE employee SET location_id = -1 WHERE employee_id = (SELECT min(employee_id) FROM employee)', '23503');

-- ---- Foreign keys: ON DELETE RESTRICT ----
CALL pg_temp.expect_sqlstate('constraints', 'deleting a referenced department rejected', NULL,
    'DELETE FROM department WHERE department_id = (SELECT department_id FROM job_assignment LIMIT 1)', '23503');
CALL pg_temp.expect_sqlstate('constraints', 'deleting a referenced job rejected', NULL,
    'DELETE FROM job WHERE job_id = (SELECT job_id FROM job_assignment LIMIT 1)', '23503');
CALL pg_temp.expect_sqlstate('constraints', 'deleting a referenced location rejected', NULL,
    'DELETE FROM location WHERE location_id = (SELECT location_id FROM employee LIMIT 1)', '23503');
CALL pg_temp.expect_sqlstate('constraints', 'deleting a referenced education level rejected', NULL,
    'DELETE FROM education_level WHERE education_level_id = (SELECT education_level_id FROM employee LIMIT 1)', '23503');
CALL pg_temp.expect_sqlstate('constraints', 'deleting an employee who has job history rejected', NULL,
    'DELETE FROM employee WHERE employee_id = (SELECT employee_id FROM job_assignment LIMIT 1)', '23503');
CALL pg_temp.expect_sqlstate('constraints', 'deleting an employee who is someone''s manager rejected', NULL,
    'DELETE FROM employee WHERE employee_id = (SELECT manager_id FROM job_assignment WHERE manager_id IS NOT NULL LIMIT 1)', '23503');
CALL pg_temp.expect_sqlstate('constraints', 'deleting a job_assignment that has a salary rejected', NULL,
    'DELETE FROM job_assignment WHERE assignment_id = (SELECT assignment_id FROM employee_salary LIMIT 1)', '23503');

-- ---- Unique constraints ----
CALL pg_temp.expect_sqlstate('constraints', 'duplicate employee_number rejected', NULL,
    $$ INSERT INTO employee (employee_number, full_name, email, hire_date, location_id, education_level_id)
       SELECT employee_number, 'Dup Person', 'dup.person@example.com', hire_date, location_id, education_level_id FROM employee LIMIT 1 $$, '23505');
CALL pg_temp.expect_sqlstate('constraints', 'duplicate employee e-mail rejected', NULL,
    $$ INSERT INTO employee (employee_number, full_name, email, hire_date, location_id, education_level_id)
       SELECT 'ZZ999', 'Dup Person', email, hire_date, location_id, education_level_id FROM employee LIMIT 1 $$, '23505');
CALL pg_temp.expect_sqlstate('constraints', 'duplicate job title rejected', NULL,
    'INSERT INTO job (job_title) SELECT job_title FROM job LIMIT 1', '23505');
CALL pg_temp.expect_sqlstate('constraints', 'duplicate department name rejected', NULL,
    'INSERT INTO department (department_name) SELECT department_name FROM department LIMIT 1', '23505');
CALL pg_temp.expect_sqlstate('constraints', 'duplicate location name rejected', NULL,
    $$ INSERT INTO location (location_name, street_address, city, state_code) SELECT location_name, 'Other St', 'Other', 'OT' FROM location LIMIT 1 $$, '23505');
CALL pg_temp.expect_sqlstate('constraints', 'duplicate (employee, start_date) rejected', NULL,
    'INSERT INTO job_assignment (employee_id, job_id, department_id, start_date, end_date) SELECT employee_id, job_id, department_id, start_date, start_date FROM job_assignment LIMIT 1', '23505');
CALL pg_temp.expect_sqlstate('constraints', 'second salary for one assignment rejected', NULL,
    'INSERT INTO employee_salary (assignment_id, salary_amount) SELECT assignment_id, 1 FROM employee_salary LIMIT 1', '23505');
CALL pg_temp.expect_sqlstate('constraints', 'second CURRENT assignment for one employee rejected', NULL,
    'INSERT INTO job_assignment (employee_id, job_id, department_id, start_date) SELECT employee_id, job_id, department_id, DATE ''1900-01-01'' FROM job_assignment WHERE end_date IS NULL LIMIT 1', '23505');

-- ---- CHECK constraints ----
CALL pg_temp.expect_sqlstate('constraints', 'negative salary rejected', NULL,
    'UPDATE employee_salary SET salary_amount = -5 WHERE salary_id = (SELECT min(salary_id) FROM employee_salary)', '23514');
CALL pg_temp.expect_sqlstate('constraints', 'zero salary rejected', NULL,
    'UPDATE employee_salary SET salary_amount = 0 WHERE salary_id = (SELECT min(salary_id) FROM employee_salary)', '23514');
CALL pg_temp.expect_sqlstate('constraints', 'employee as their own manager rejected', NULL,
    'UPDATE job_assignment SET manager_id = employee_id WHERE assignment_id = (SELECT min(assignment_id) FROM job_assignment)', '23514');
CALL pg_temp.expect_sqlstate('constraints', 'assignment ending before it starts rejected', NULL,
    'UPDATE job_assignment SET end_date = start_date - 1 WHERE assignment_id = (SELECT min(assignment_id) FROM job_assignment)', '23514');

-- ---- NOT NULL and data type limits ----
CALL pg_temp.expect_sqlstate('constraints', 'employee without a name rejected', NULL,
    'INSERT INTO employee (employee_number, full_name, email, hire_date, location_id, education_level_id) SELECT ''ZZ998'', NULL, ''x@example.com'', hire_date, location_id, education_level_id FROM employee LIMIT 1', '23502');
CALL pg_temp.expect_sqlstate('constraints', 'job_assignment without a start date rejected', NULL,
    'INSERT INTO job_assignment (employee_id, job_id, department_id, start_date) SELECT employee_id, job_id, department_id, NULL FROM job_assignment LIMIT 1', '23502');
CALL pg_temp.expect_sqlstate('constraints', 'salary beyond NUMERIC(10,2) rejected', NULL,
    'UPDATE employee_salary SET salary_amount = 123456789012 WHERE salary_id = (SELECT min(salary_id) FROM employee_salary)', '22003');

-- ---- Positive control: a valid change is accepted (and rolled back) ----
CALL pg_temp.expect_success('constraints', 'valid closed historical assignment is accepted', NULL,
    'INSERT INTO job_assignment (employee_id, job_id, department_id, start_date, end_date) SELECT employee_id, job_id, department_id, DATE ''1900-01-01'', DATE ''1900-06-30'' FROM job_assignment WHERE end_date IS NULL LIMIT 1', 1);

-- ---- Nothing was left behind by the intentional failures ----
CALL pg_temp.assert_sql('constraints', 'row counts unchanged after all constraint tests',
    $$ SELECT count(*) FROM row_snapshot s WHERE s.n <> (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM %I', s.t), false, true, '')))[1]::text::bigint $$, '0');
