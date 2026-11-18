-- Challenge 2: stored procedure returning current and past jobs for an employee name.
-- PostgreSQL procedures return result sets through a refcursor (INOUT parameter).
CREATE OR REPLACE PROCEDURE sp_employee_job_history(IN p_employee_name VARCHAR, INOUT p_result REFCURSOR DEFAULT 'job_history')
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_result FOR
        SELECT e.full_name  AS employee_name,
               j.job_title,
               d.department_name,
               m.full_name  AS manager_name,
               a.start_date AS job_start_date,
               a.end_date   AS job_end_date          -- NULL = current job
        FROM employee e
        JOIN job_assignment a ON a.employee_id   = e.employee_id
        JOIN job            j ON j.job_id        = a.job_id
        JOIN department     d ON d.department_id = a.department_id
        LEFT JOIN employee  m ON m.employee_id   = a.manager_id
        WHERE lower(e.full_name) = lower(trim(p_employee_name))
        ORDER BY a.start_date;
END;
$$;

-- Usage (cursor must be fetched inside the same transaction):
-- BEGIN;
-- CALL sp_employee_job_history('Marlow Finch', 'job_history');
-- FETCH ALL FROM job_history;
-- COMMIT;
