-- Challenge 1: human-readable views that rebuild the original spreadsheet layout.
-- Salary is NOT in the general view; the full-detail view is restricted to HR/management (see 03_salary_security.sql).
CREATE OR REPLACE VIEW v_employee_directory AS
SELECT e.employee_number  AS emp_id,
       e.full_name        AS emp_nm,
       e.email,
       e.hire_date        AS hire_dt,
       j.job_title,
       d.department_name  AS department_nm,
       m.full_name        AS manager,
       a.start_date       AS start_dt,
       COALESCE(to_char(a.end_date,'YYYY-MM-DD'),'Current') AS end_dt,
       l.location_name    AS location,
       l.street_address   AS address,
       l.city,
       l.state_code       AS state,
       el.education_level_name AS education_lvl
FROM employee e
JOIN job_assignment a   ON a.employee_id = e.employee_id
JOIN job j              ON j.job_id = a.job_id
JOIN department d       ON d.department_id = a.department_id
LEFT JOIN employee m    ON m.employee_id = a.manager_id
JOIN location l         ON l.location_id = e.location_id
JOIN education_level el ON el.education_level_id = e.education_level_id;

-- Same columns plus salary: ONLY for HR / management
CREATE OR REPLACE VIEW v_employee_full_hr AS
SELECT v.emp_id, v.emp_nm, v.email, v.hire_dt, v.job_title, s.salary_amount AS salary,
       v.department_nm, v.manager, v.start_dt, v.end_dt, v.location, v.address, v.city, v.state, v.education_lvl
FROM v_employee_directory v
JOIN employee e        ON e.employee_number = v.emp_id
JOIN job_assignment a  ON a.employee_id = e.employee_id AND a.start_date = v.start_dt
JOIN employee_salary s ON s.assignment_id = a.assignment_id;
