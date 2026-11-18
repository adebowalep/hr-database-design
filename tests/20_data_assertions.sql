-- =====================================================================
-- Data assertions that must hold for ANY staging dataset loaded through the ETL
-- (synthetic or original). Dataset-specific expected values are in 50_dataset_expectations.sql.
-- =====================================================================

-- ---- ETL reconciliation against staging ----
CALL pg_temp.assert_queries('reconciliation', 'job_assignment rows = staging rows',
    'SELECT count(*) FROM job_assignment', 'SELECT count(*) FROM proj_stg');
CALL pg_temp.assert_queries('reconciliation', 'employee rows = distinct staging Emp_ID',
    'SELECT count(*) FROM employee', 'SELECT count(DISTINCT emp_id) FROM proj_stg');
CALL pg_temp.assert_queries('reconciliation', 'employee_salary rows = staging rows',
    'SELECT count(*) FROM employee_salary', 'SELECT count(*) FROM proj_stg');
CALL pg_temp.assert_sql('reconciliation', 'salary total equals staging salary total',
    'SELECT (SELECT sum(salary_amount) FROM employee_salary) = (SELECT sum(salary) FROM proj_stg)', 'true');
CALL pg_temp.assert_sql('reconciliation', 'each salary is attached to the matching employee and job period (0 mismatches)',
    $$ SELECT count(*) FROM proj_stg s
       LEFT JOIN employee e        ON e.employee_number = s.emp_id
       LEFT JOIN job_assignment a  ON a.employee_id = e.employee_id AND a.start_date = s.start_dt
       LEFT JOIN employee_salary x ON x.assignment_id = a.assignment_id
       WHERE x.salary_amount IS DISTINCT FROM s.salary $$, '0');
CALL pg_temp.assert_queries('reconciliation', 'lookup tables: job titles',
    'SELECT count(*) FROM job', 'SELECT count(DISTINCT trim(job_title)) FROM proj_stg');
CALL pg_temp.assert_queries('reconciliation', 'lookup tables: departments',
    'SELECT count(*) FROM department', 'SELECT count(DISTINCT trim(department_nm)) FROM proj_stg');
CALL pg_temp.assert_queries('reconciliation', 'lookup tables: education levels',
    'SELECT count(*) FROM education_level', 'SELECT count(DISTINCT trim(education_lvl)) FROM proj_stg');
CALL pg_temp.assert_queries('reconciliation', 'lookup tables: locations',
    'SELECT count(*) FROM location', 'SELECT count(DISTINCT trim(location)) FROM proj_stg');

-- ---- Keys and constraints exist and are validated ----
CALL pg_temp.assert_sql('keys', '7 primary keys exist',
    $$ SELECT count(*) FROM pg_constraint WHERE contype = 'p' AND connamespace = 'public'::regnamespace $$, '7');
CALL pg_temp.assert_sql('keys', '7 foreign keys exist',
    $$ SELECT count(*) FROM pg_constraint WHERE contype = 'f' AND connamespace = 'public'::regnamespace $$, '7');
CALL pg_temp.assert_sql('keys', 'all constraints are validated',
    $$ SELECT count(*) FROM pg_constraint WHERE connamespace = 'public'::regnamespace AND NOT convalidated $$, '0');
DO $$
DECLARE t record;
BEGIN
    FOR t IN SELECT * FROM (VALUES ('location','location_id'),('department','department_id'),('job','job_id'),
             ('education_level','education_level_id'),('employee','employee_id'),('job_assignment','assignment_id'),
             ('employee_salary','salary_id')) v(tbl, pk) LOOP
        CALL pg_temp.assert_sql('keys', 'primary key unique and not null: ' || t.tbl,
            format('SELECT count(*) - count(DISTINCT %1$I) + count(*) FILTER (WHERE %1$I IS NULL) FROM %2$I', t.pk, t.tbl), '0');
    END LOOP;
END $$;

-- ---- Referential integrity: no orphans (anti-joins, independent of the FK constraints) ----
CALL pg_temp.assert_sql('integrity', 'employee -> location: no orphans',
    'SELECT count(*) FROM employee e WHERE NOT EXISTS (SELECT 1 FROM location l WHERE l.location_id = e.location_id)', '0');
CALL pg_temp.assert_sql('integrity', 'employee -> education_level: no orphans',
    'SELECT count(*) FROM employee e WHERE NOT EXISTS (SELECT 1 FROM education_level l WHERE l.education_level_id = e.education_level_id)', '0');
CALL pg_temp.assert_sql('integrity', 'job_assignment -> employee: no orphans',
    'SELECT count(*) FROM job_assignment a WHERE NOT EXISTS (SELECT 1 FROM employee e WHERE e.employee_id = a.employee_id)', '0');
CALL pg_temp.assert_sql('integrity', 'job_assignment -> job: no orphans',
    'SELECT count(*) FROM job_assignment a WHERE NOT EXISTS (SELECT 1 FROM job j WHERE j.job_id = a.job_id)', '0');
CALL pg_temp.assert_sql('integrity', 'job_assignment -> department: no orphans',
    'SELECT count(*) FROM job_assignment a WHERE NOT EXISTS (SELECT 1 FROM department d WHERE d.department_id = a.department_id)', '0');
CALL pg_temp.assert_sql('integrity', 'job_assignment -> manager (employee): no unresolved manager references',
    'SELECT count(*) FROM job_assignment a WHERE a.manager_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM employee m WHERE m.employee_id = a.manager_id)', '0');
CALL pg_temp.assert_sql('integrity', 'employee_salary -> job_assignment: no orphans',
    'SELECT count(*) FROM employee_salary s WHERE NOT EXISTS (SELECT 1 FROM job_assignment a WHERE a.assignment_id = s.assignment_id)', '0');
CALL pg_temp.assert_sql('integrity', 'every job_assignment has exactly one salary',
    'SELECT count(*) FROM job_assignment a WHERE (SELECT count(*) FROM employee_salary s WHERE s.assignment_id = a.assignment_id) <> 1', '0');

-- ---- Job history ----
CALL pg_temp.assert_sql('history', 'every employee has exactly one current assignment',
    $$ SELECT count(*) FROM employee e WHERE (SELECT count(*) FROM job_assignment a WHERE a.employee_id = e.employee_id AND a.end_date IS NULL) <> 1 $$, '0');
CALL pg_temp.assert_queries('history', 'employees with more than one job record = same count in staging',
    'SELECT count(*) FROM (SELECT 1 FROM job_assignment GROUP BY employee_id HAVING count(*) > 1) t',
    'SELECT count(*) FROM (SELECT 1 FROM proj_stg GROUP BY emp_id HAVING count(*) > 1) t');
CALL pg_temp.assert_queries('history', 'past (closed) assignments = staging rows with a real end date',
    'SELECT count(*) FROM job_assignment WHERE end_date IS NOT NULL',
    $$ SELECT count(*) FROM proj_stg WHERE end_dt < DATE '2099-01-01' $$);
CALL pg_temp.assert_queries('history', 'current assignments = staging rows with the placeholder end date',
    'SELECT count(*) FROM job_assignment WHERE end_date IS NULL',
    $$ SELECT count(*) FROM proj_stg WHERE end_dt >= DATE '2099-01-01' $$);
CALL pg_temp.assert_sql('history', 'no overlapping job periods for one employee (shared boundary day allowed)',
    $$ SELECT count(*) FROM job_assignment a JOIN job_assignment b
         ON a.employee_id = b.employee_id AND a.start_date < b.start_date
        WHERE coalesce(a.end_date, DATE 'infinity') > b.start_date $$, '0');

-- ---- Dates ----
CALL pg_temp.assert_sql('dates', 'no assignment ends before it starts',
    'SELECT count(*) FROM job_assignment WHERE end_date < start_date', '0');
CALL pg_temp.assert_sql('dates', 'no 2099+ placeholder end dates remain in the target',
    $$ SELECT count(*) FROM job_assignment WHERE end_date >= DATE '2099-01-01' $$, '0');
CALL pg_temp.assert_sql('dates', 'hire_date is never after the first job start',
    $$ SELECT count(*) FROM employee e WHERE e.hire_date > (SELECT min(start_date) FROM job_assignment a WHERE a.employee_id = e.employee_id) $$, '0');
CALL pg_temp.assert_sql('dates', 'no job starts in the future',
    'SELECT count(*) FROM job_assignment WHERE start_date > current_date', '0');

-- ---- Managers and hierarchy ----
CALL pg_temp.assert_sql('hierarchy', 'staging rows with a named manager all resolved to an employee',
    $$ SELECT count(*) FROM proj_stg s JOIN employee e ON e.employee_number = s.emp_id
        JOIN job_assignment a ON a.employee_id = e.employee_id AND a.start_date = s.start_dt
       WHERE lower(trim(s.manager)) <> 'none' AND a.manager_id IS NULL $$, '0');
CALL pg_temp.assert_queries('hierarchy', 'assignments without a manager = staging rows whose manager is None',
    'SELECT count(*) FROM job_assignment WHERE manager_id IS NULL',
    $$ SELECT count(*) FROM proj_stg WHERE lower(trim(manager)) = 'none' $$);
CALL pg_temp.assert_sql('hierarchy', 'nobody is their own manager',
    'SELECT count(*) FROM job_assignment WHERE manager_id = employee_id', '0');
CALL pg_temp.assert_sql('hierarchy', 'every manager of a current assignment has a current assignment themselves',
    $$ SELECT count(*) FROM job_assignment a WHERE a.end_date IS NULL AND a.manager_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM job_assignment m WHERE m.employee_id = a.manager_id AND m.end_date IS NULL) $$, '0');
CALL pg_temp.assert_sql('hierarchy', 'no management cycles among current assignments',
    $$ WITH RECURSIVE cur AS (SELECT employee_id, manager_id FROM job_assignment WHERE end_date IS NULL),
       walk AS (SELECT employee_id AS start_id, manager_id AS cur_id, 1 AS depth FROM cur
                UNION ALL
                SELECT w.start_id, c.manager_id, w.depth + 1 FROM walk w JOIN cur c ON c.employee_id = w.cur_id
                WHERE w.depth <= (SELECT count(*) FROM cur))
       SELECT count(*) FROM walk WHERE cur_id = start_id $$, '0');

-- ---- Uniqueness and cleaning ----
CALL pg_temp.assert_sql('quality', 'no duplicate employee e-mails', 'SELECT count(*) - count(DISTINCT email) FROM employee', '0');
CALL pg_temp.assert_sql('quality', 'no duplicate employee numbers', 'SELECT count(*) - count(DISTINCT employee_number) FROM employee', '0');
CALL pg_temp.assert_sql('quality', 'no duplicate employee names (managers are matched by name)', 'SELECT count(*) - count(DISTINCT full_name) FROM employee', '0');
CALL pg_temp.assert_sql('quality', 'names have no leading/trailing/double spaces',
    $$ SELECT count(*) FROM employee WHERE full_name <> regexp_replace(trim(full_name), '\s+', ' ', 'g') $$, '0');
CALL pg_temp.assert_sql('quality', 'e-mails are lower-case and trimmed',
    'SELECT count(*) FROM employee WHERE email <> lower(trim(email))', '0');
CALL pg_temp.assert_sql('quality', 'state codes are upper-case',
    'SELECT count(*) FROM location WHERE state_code <> upper(state_code)', '0');
CALL pg_temp.assert_sql('quality', 'city typo "Minnapolis" is corrected',
    $$ SELECT count(*) FROM location WHERE city = 'Minnapolis' $$, '0');
CALL pg_temp.assert_sql('quality', 'all salaries are positive', 'SELECT count(*) FROM employee_salary WHERE salary_amount <= 0', '0');

-- ---- Informational ----
DO $$
DECLARE r text;
BEGIN
    SELECT 'employee=' || (SELECT count(*) FROM employee) || ', job_assignment=' || (SELECT count(*) FROM job_assignment)
        || ', employee_salary=' || (SELECT count(*) FROM employee_salary) || ', job=' || (SELECT count(*) FROM job)
        || ', department=' || (SELECT count(*) FROM department) || ', location=' || (SELECT count(*) FROM location)
        || ', education_level=' || (SELECT count(*) FROM education_level) || ', proj_stg=' || (SELECT count(*) FROM proj_stg) INTO r;
    CALL pg_temp.info('data', 'row counts', r);
END $$;
