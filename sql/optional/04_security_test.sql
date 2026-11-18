-- Security test (demonstration, synthetic dataset): proves the salary restriction is enforced. Run as postgres after 03_salary_security.sql.
-- The statements that are EXPECTED to fail show a "permission denied" error.
\set ON_ERROR_STOP off
SET ROLE "NoMgr";
SELECT current_user AS acting_as;
SELECT count(*) AS employees_visible FROM employee;               -- allowed
SELECT emp_nm, job_title FROM v_employee_directory LIMIT 2;       -- allowed (no salary column)
SELECT * FROM employee_salary LIMIT 1;                            -- DENIED
SELECT emp_id, salary FROM proj_stg LIMIT 1;                      -- DENIED (staging table also holds salary)
SELECT salary FROM v_employee_full_hr LIMIT 1;                    -- DENIED
INSERT INTO job (job_title) VALUES ('Intruder');                  -- DENIED (read-only)
RESET ROLE;
SET ROLE hr_staff;
SELECT current_user AS acting_as;
SELECT e.full_name, s.salary_amount
FROM employee e JOIN job_assignment a USING (employee_id)
JOIN employee_salary s USING (assignment_id)
WHERE e.full_name = 'Marlow Finch' AND a.end_date IS NULL;        -- ALLOWED for HR (synthetic employee)
RESET ROLE;
