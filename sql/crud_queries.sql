-- =====================================================================
-- Tech ABC Corp - HR Database  |  crud_queries.sql  (Questions 1-7)
-- Run after schema.sql and etl_from_proj_stg.sql (psql 13+ for the \if in Q6).
-- "Current" = job_assignment.end_date IS NULL (source placeholder 2100 dates were converted to NULL).
-- =====================================================================

-- ### Q1
-- Question 1: Return a list of employees with their job titles and department names
SELECT e.employee_number,
       e.full_name       AS employee_name,
       j.job_title,
       d.department_name
FROM employee e
JOIN job_assignment a ON a.employee_id = e.employee_id
                     AND a.end_date IS NULL            -- current job only
JOIN job            j ON j.job_id        = a.job_id
JOIN department     d ON d.department_id = a.department_id
ORDER BY e.full_name;

-- ### Q2
-- Question 2: Insert 'Web Programmer' as a new job title
SELECT job_id, job_title FROM job WHERE job_title LIKE 'Web%';   -- BEFORE
INSERT INTO job (job_title) VALUES ('Web Programmer');
SELECT job_id, job_title FROM job WHERE job_title LIKE 'Web%';   -- AFTER
SELECT count(*) AS total_jobs FROM job;

-- ### Q3
-- Question 3: Correct the job title from 'Web Programmer' to 'Web Developer'
SELECT job_id, job_title FROM job WHERE job_title LIKE 'Web%';   -- BEFORE
UPDATE job SET job_title = 'Web Developer' WHERE job_title = 'Web Programmer';
SELECT job_id, job_title FROM job WHERE job_title LIKE 'Web%';   -- AFTER

-- ### Q4
-- Question 4: Delete the job title 'Web Developer' from the database
SELECT job_id, job_title FROM job WHERE job_title LIKE 'Web%';   -- BEFORE
DELETE FROM job WHERE job_title = 'Web Developer';   -- touches only this job row
SELECT job_id, job_title FROM job WHERE job_title LIKE 'Web%';   -- AFTER: no rows
SELECT count(*) AS total_jobs FROM job;              -- back to the original 10
SELECT count(*) AS employees_unchanged FROM employee;

-- ### Q5
-- Question 5: How many employees are in each department?
-- Counts CURRENT assignments only, so past jobs of the 6 employees with history are not double-counted.
SELECT d.department_name,
       count(DISTINCT a.employee_id) AS employee_count
FROM department d
LEFT JOIN job_assignment a ON a.department_id = d.department_id
                          AND a.end_date IS NULL
GROUP BY d.department_name
ORDER BY d.department_name;

-- ### Q6
-- Question 6: Current and past jobs of one employee who has changed jobs.
-- The course question names a specific employee from the course dataset (not published here). The default below is the
-- synthetic employee with a job change; run with  psql -v q6_employee='Full Name' ...  to ask about someone else.
\if :{?q6_employee}
\else
  \set q6_employee 'Marlow Finch'
\endif
SELECT e.full_name  AS employee_name,
       j.job_title,
       d.department_name,
       m.full_name  AS manager_name,
       a.start_date AS job_start_date,
       COALESCE(a.end_date::text, 'Current') AS job_end_date
FROM employee e
JOIN job_assignment a ON a.employee_id   = e.employee_id
JOIN job            j ON j.job_id        = a.job_id
JOIN department     d ON d.department_id = a.department_id
LEFT JOIN employee  m ON m.employee_id   = a.manager_id
WHERE e.full_name = :'q6_employee'
ORDER BY a.start_date;

-- ### Q7
-- Question 7: Table-level security for salaries (PostgreSQL)
-- Salary lives in its own table (employee_salary), so permissions can be set on that table only.
-- Use an explicit allow-list rather than "grant everything, then revoke the restricted objects":
--   REVOKE ALL ON employee_salary, v_employee_full_hr FROM PUBLIC;   -- nobody gets salary by default
--   GRANT SELECT ON employee, job_assignment, job, department, location, education_level,
--                   v_employee_directory TO hr_read;                  -- ordinary users: named non-salary objects only
--   GRANT SELECT, INSERT, UPDATE, DELETE ON <the seven HR tables> TO hr_staff;  -- HR/management: incl. salary
--   REVOKE ALL ON proj_stg FROM PUBLIC, hr_read, hr_staff;           -- the staging copy also contains salary
-- Each employee's login role is made a member of hr_read (about 90% of users); HR and management logins are members of hr_staff.
-- (The original answer granted SELECT ON ALL TABLES to hr_read and revoked the salary table afterwards. That left proj_stg readable.)
-- Full working script (with a tested NoMgr role): optional/03_salary_security.sql
-- Q7 evidence (shows the permission being enforced): run optional/03_salary_security.sql
