-- =====================================================================
-- Tech ABC Corp - HR Database  |  etl_from_proj_stg.sql
-- Loads the normalized tables from the staging table proj_stg
-- (synthetic: data/synthetic/synthetic_proj_stg.sql; course data: StageTableLoad.sql). Run AFTER schema.sql.
-- Atomic: one transaction. Any failed check (preflight or reconciliation) rolls everything back, so the
-- target tables are either completely loaded or still empty.
-- Cleaning rules:
--   * names/titles trimmed and internal double spaces collapsed ('Cedar  Wynn' -> 'Cedar Wynn')
--   * 'Minnapolis' spelling corrected to 'Minneapolis'
--   * end_dt in year 2100 is a placeholder for "current job" -> stored as NULL
--   * manager text 'None' (the President) -> NULL manager_id; other managers resolved by name to employee
--   * hire_date = earliest of source hire_dt and first job start_dt (source hire_dt for the 6
--     employees with history holds their LAST job-change date, which is after their first start)
-- =====================================================================
BEGIN;

DO $$
BEGIN
    IF to_regclass('public.proj_stg') IS NULL THEN
        RAISE EXCEPTION 'proj_stg not found - run StageTableLoad.sql (INIT DATABASE) first';
    END IF;
    IF EXISTS (SELECT 1 FROM employee) THEN
        RAISE EXCEPTION 'Target tables are not empty - run schema.sql first';
    END IF;
END $$;

-- 0. Data-quality gate: fails with a specific SQLSTATE (EL001..EL015) instead of guessing
\ir etl_preflight.sql
DO $$ BEGIN PERFORM etl_check_staging('public.proj_stg'); END $$;

-- 1. Lookup tables
INSERT INTO location (location_name, street_address, city, state_code)
SELECT DISTINCT trim(location), trim(address),
       CASE WHEN trim(city) = 'Minnapolis' THEN 'Minneapolis' ELSE trim(city) END,
       upper(trim(state))
FROM proj_stg ORDER BY 1;

INSERT INTO department (department_name)
SELECT DISTINCT trim(department_nm) FROM proj_stg ORDER BY 1;

INSERT INTO job (job_title)
SELECT DISTINCT trim(job_title) FROM proj_stg ORDER BY 1;

INSERT INTO education_level (education_level_name)
SELECT DISTINCT trim(education_lvl) FROM proj_stg ORDER BY 1;

-- 2. Employees: one row per distinct Emp_ID.
--    min() is safe here ONLY because etl_check_staging proved name, email, location and education are identical
--    across an employee's rows. hire_dt/start_dt are the documented exception (see header).
INSERT INTO employee (employee_number, full_name, email, hire_date, location_id, education_level_id)
SELECT s.emp_id,
       regexp_replace(trim(s.emp_nm), '\s+', ' ', 'g'),
       lower(trim(s.email)),
       LEAST(s.hire_dt, s.first_start),
       l.location_id,
       e.education_level_id
FROM (
    SELECT emp_id,
           min(emp_nm) AS emp_nm, min(email) AS email, min(hire_dt) AS hire_dt,
           min(start_dt) AS first_start, min(location) AS location, min(education_lvl) AS education_lvl
    FROM proj_stg GROUP BY emp_id
) s
JOIN location        l ON l.location_name = trim(s.location)
JOIN education_level e ON e.education_level_name = trim(s.education_lvl)
ORDER BY s.emp_id;

-- 3. Job assignments: one row per staging row (history preserved)
INSERT INTO job_assignment (employee_id, job_id, department_id, manager_id, start_date, end_date)
SELECT emp.employee_id, j.job_id, d.department_id, mgr.employee_id,
       s.start_dt,
       CASE WHEN s.end_dt >= DATE '2099-01-01' THEN NULL ELSE s.end_dt END
FROM proj_stg s
JOIN employee   emp ON emp.employee_number = s.emp_id
JOIN job        j   ON j.job_title = trim(s.job_title)
JOIN department d   ON d.department_name = trim(s.department_nm)
LEFT JOIN employee mgr
       ON mgr.full_name = regexp_replace(trim(s.manager), '\s+', ' ', 'g')
      AND lower(trim(s.manager)) <> 'none'
ORDER BY emp.employee_id, s.start_dt;

-- 4. Restricted salary table (one salary per assignment)
INSERT INTO employee_salary (assignment_id, salary_amount)
SELECT a.assignment_id, s.salary
FROM proj_stg s
JOIN employee       emp ON emp.employee_number = s.emp_id
JOIN job_assignment a   ON a.employee_id = emp.employee_id AND a.start_date = s.start_dt;

-- 5. Validation: abort (ROLLBACK) if anything was lost
DO $$
DECLARE
    stg_rows int; stg_emps int; n_asg int; n_emp int; n_sal int; n_unres int; n_hist int;
BEGIN
    SELECT count(*), count(DISTINCT emp_id) INTO stg_rows, stg_emps FROM proj_stg;
    SELECT count(*) INTO n_asg FROM job_assignment;
    SELECT count(*) INTO n_emp FROM employee;
    SELECT count(*) INTO n_sal FROM employee_salary;
    SELECT count(*) INTO n_unres FROM proj_stg s JOIN employee e ON e.employee_number = s.emp_id
        JOIN job_assignment a ON a.employee_id = e.employee_id AND a.start_date = s.start_dt
        WHERE lower(trim(s.manager)) <> 'none' AND a.manager_id IS NULL;
    IF n_asg <> stg_rows OR n_emp <> stg_emps OR n_sal <> stg_rows OR n_unres <> 0 THEN
        RAISE EXCEPTION 'ETL validation failed: staging rows %, assignments %, staging employees %, employees %, salaries %, unresolved managers %',
            stg_rows, n_asg, stg_emps, n_emp, n_sal, n_unres;
    END IF;
    RAISE NOTICE 'ETL validation passed: % rows -> % assignments, % employees, % salaries', stg_rows, n_asg, n_emp, n_sal;
END $$;

COMMIT;

-- Reconciliation report
SELECT 'proj_stg rows'            AS check_name, count(*) AS value FROM proj_stg
UNION ALL SELECT 'proj_stg distinct Emp_ID', count(DISTINCT emp_id) FROM proj_stg
UNION ALL SELECT 'employee rows',            count(*) FROM employee
UNION ALL SELECT 'job_assignment rows',      count(*) FROM job_assignment
UNION ALL SELECT 'employee_salary rows',     count(*) FROM employee_salary
UNION ALL SELECT 'current assignments (end_date NULL)', count(*) FROM job_assignment WHERE end_date IS NULL
UNION ALL SELECT 'past assignments',         count(*) FROM job_assignment WHERE end_date IS NOT NULL
UNION ALL SELECT 'employees with >1 assignment', count(*) FROM (SELECT 1 FROM job_assignment GROUP BY employee_id HAVING count(*) > 1) t
UNION ALL SELECT 'job rows',        count(*) FROM job
UNION ALL SELECT 'department rows', count(*) FROM department
UNION ALL SELECT 'location rows',   count(*) FROM location
UNION ALL SELECT 'education_level rows', count(*) FROM education_level;
