-- =====================================================================
-- Query / view / procedure tests (dataset-independent behaviour).
-- sql/crud_queries.sql is executed by run_all.sql (exit status checked in CI); the checks below assert the
-- results of the same query logic.
-- =====================================================================

-- Q1: current job per employee = exactly one row per employee
CALL pg_temp.assert_queries('queries', 'Q1 current-job listing returns one row per employee',
    $$ SELECT count(*) FROM employee e JOIN job_assignment a ON a.employee_id = e.employee_id AND a.end_date IS NULL
         JOIN job j ON j.job_id = a.job_id JOIN department d ON d.department_id = a.department_id $$,
    'SELECT count(*) FROM employee');

-- Q2-Q4: insert, correct and delete a job title leaves the table as it was
CALL pg_temp.expect_success('queries', 'Q2-Q4 insert / update / delete of a job title restores the original job table', NULL,
    $q$ DO $x$
        DECLARE n0 bigint; e0 bigint;
        BEGIN
            SELECT count(*) INTO n0 FROM job; SELECT count(*) INTO e0 FROM employee;
            INSERT INTO job (job_title) VALUES ('Web Programmer');
            IF (SELECT count(*) FROM job) <> n0 + 1 THEN RAISE EXCEPTION 'Q2 insert failed'; END IF;
            UPDATE job SET job_title = 'Web Developer' WHERE job_title = 'Web Programmer';
            IF NOT EXISTS (SELECT 1 FROM job WHERE job_title = 'Web Developer') THEN RAISE EXCEPTION 'Q3 update failed'; END IF;
            DELETE FROM job WHERE job_title = 'Web Developer';
            IF (SELECT count(*) FROM job) <> n0 OR (SELECT count(*) FROM employee) <> e0 THEN RAISE EXCEPTION 'Q4 delete changed other rows'; END IF;
        END $x$ $q$, 0);

-- Q5: employees per department (current jobs only)
CALL pg_temp.assert_queries('queries', 'Q5 department headcounts add up to the number of employees',
    $$ SELECT sum(c) FROM (SELECT count(DISTINCT a.employee_id) AS c FROM department d
         LEFT JOIN job_assignment a ON a.department_id = d.department_id AND a.end_date IS NULL GROUP BY d.department_id) t $$,
    'SELECT count(*) FROM employee');

-- Views
CALL pg_temp.assert_queries('views', 'v_employee_directory has one row per job record',
    'SELECT count(*) FROM v_employee_directory', 'SELECT count(*) FROM job_assignment');
CALL pg_temp.assert_queries('views', 'v_employee_full_hr has one row per job record (every record has a salary)',
    'SELECT count(*) FROM v_employee_full_hr', 'SELECT count(*) FROM job_assignment');
CALL pg_temp.assert_sql('views', 'v_employee_directory exposes no salary column',
    $$ SELECT count(*) FROM information_schema.columns WHERE table_name = 'v_employee_directory' AND column_name ILIKE '%salary%' $$, '0');
CALL pg_temp.assert_sql('views', 'v_employee_full_hr salary equals employee_salary (0 mismatches)',
    $$ SELECT count(*) FROM v_employee_full_hr v JOIN employee e ON e.employee_number = v.emp_id
         JOIN job_assignment a ON a.employee_id = e.employee_id AND a.start_date = v.start_dt
         JOIN employee_salary s ON s.assignment_id = a.assignment_id WHERE s.salary_amount <> v.salary $$, '0');

-- Stored procedure: for every employee the cursor returns exactly their number of job records
DO $$
DECLARE e record; cur refcursor := 'c_hist'; r record; n int; bad int := 0; total int := 0;
BEGIN
    FOR e IN SELECT x.full_name, (SELECT count(*) FROM job_assignment a WHERE a.employee_id = x.employee_id) AS expected FROM employee x LOOP
        CALL sp_employee_job_history(e.full_name, cur);
        n := 0;
        LOOP FETCH cur INTO r; EXIT WHEN NOT FOUND; n := n + 1; END LOOP;
        CLOSE cur;
        total := total + n;
        IF n <> e.expected THEN bad := bad + 1; END IF;
    END LOOP;
    CALL pg_temp.assert_eq('procedure', 'sp_employee_job_history returns the right number of rows for every employee (mismatching employees)', bad, 0);
    CALL pg_temp.assert_queries('procedure', 'sp_employee_job_history rows over all employees = job_assignment rows',
        format('SELECT %s::bigint', total), 'SELECT count(*) FROM job_assignment');
END $$;
