-- =====================================================================
-- Expected values for the two known datasets. The dataset is detected from the loaded staging data:
--   original  = the course dataset (205 rows, Emp_ID E27498 present)   -> figures recorded in docs/validation_results.md
--   synthetic = data/synthetic/synthetic_proj_stg.sql (11 rows, S0004 present)
-- Any other data: only the generic assertions run, and an INFO row says so.
-- =====================================================================
SELECT (SELECT count(*) FROM proj_stg) = 205 AND EXISTS (SELECT 1 FROM proj_stg WHERE emp_id = 'E27498') AS is_original,
       (SELECT count(*) FROM proj_stg) = 11  AND EXISTS (SELECT 1 FROM proj_stg WHERE emp_id = 'S0004')  AS is_synthetic \gset

\if :is_original
CALL pg_temp.info('dataset', 'dataset detected', 'ORIGINAL course dataset (local run; data is not in this repository)');
CALL pg_temp.assert_sql('original', 'staging rows = 205',                 'SELECT count(*) FROM proj_stg', '205');
CALL pg_temp.assert_sql('original', 'employees = 199',                    'SELECT count(*) FROM employee', '199');
CALL pg_temp.assert_sql('original', 'job_assignments = 205',              'SELECT count(*) FROM job_assignment', '205');
CALL pg_temp.assert_sql('original', 'salary rows = 205',                  'SELECT count(*) FROM employee_salary', '205');
CALL pg_temp.assert_sql('original', 'salary total = 22,060,329',          'SELECT sum(salary_amount)::bigint FROM employee_salary', '22060329');
CALL pg_temp.assert_sql('original', 'jobs / departments / locations / education levels = 10 / 5 / 5 / 7',
    $$ SELECT (SELECT count(*) FROM job) || '/' || (SELECT count(*) FROM department) || '/' || (SELECT count(*) FROM location) || '/' || (SELECT count(*) FROM education_level) $$, '10/5/5/7');
CALL pg_temp.assert_sql('original', '6 employees have job history',
    'SELECT count(*) FROM (SELECT 1 FROM job_assignment GROUP BY employee_id HAVING count(*) > 1) t', '6');
CALL pg_temp.assert_sql('original', 'employees with history are the 6 documented people',
    $$ SELECT string_agg(e.full_name, ', ' ORDER BY e.full_name) FROM employee e WHERE (SELECT count(*) FROM job_assignment a WHERE a.employee_id = e.employee_id) > 1 $$,
    'Abby Lockhart, Edward Eslser, Eric Baxter, Lori Scatchard, Melinda Fisher, Toni Lembeck');
CALL pg_temp.assert_sql('original', 'Toni Lembeck: 2 records, Network Engineer then Database Administrator (current)',
    $$ SELECT string_agg(j.job_title || CASE WHEN a.end_date IS NULL THEN ' (current)' ELSE '' END, ' > ' ORDER BY a.start_date)
         FROM employee e JOIN job_assignment a USING (employee_id) JOIN job j USING (job_id) WHERE e.full_name = 'Toni Lembeck' $$,
    'Network Engineer > Database Administrator (current)');
CALL pg_temp.assert_sql('original', 'exactly one assignment has no manager (the President)',
    'SELECT count(*) FROM job_assignment WHERE manager_id IS NULL', '1');
CALL pg_temp.assert_sql('original', '199 placeholder 2100 end dates became current assignments',
    'SELECT count(*) FROM job_assignment WHERE end_date IS NULL', '199');
CALL pg_temp.assert_sql('original', 'salary range 26,050 - 540,000',
    'SELECT min(salary_amount)::bigint || ' || quote_literal('-') || ' || max(salary_amount)::bigint FROM employee_salary', '26050-540000');
\elif :is_synthetic
CALL pg_temp.info('dataset', 'dataset detected', 'SYNTHETIC dataset (data/synthetic/synthetic_proj_stg.sql), fictional data');
CALL pg_temp.assert_sql('synthetic', 'staging rows = 11',   'SELECT count(*) FROM proj_stg', '11');
CALL pg_temp.assert_sql('synthetic', 'employees = 9',       'SELECT count(*) FROM employee', '9');
CALL pg_temp.assert_sql('synthetic', 'job_assignments = 11', 'SELECT count(*) FROM job_assignment', '11');
CALL pg_temp.assert_sql('synthetic', 'salary total = 1,206,000', 'SELECT sum(salary_amount)::bigint FROM employee_salary', '1206000');
CALL pg_temp.assert_sql('synthetic', 'jobs / departments / locations / education levels = 6 / 3 / 3 / 4',
    $$ SELECT (SELECT count(*) FROM job) || '/' || (SELECT count(*) FROM department) || '/' || (SELECT count(*) FROM location) || '/' || (SELECT count(*) FROM education_level) $$, '6/3/3/4');
CALL pg_temp.assert_sql('synthetic', '2 employees have job history (Marlow Finch, Linden Roark)',
    $$ SELECT string_agg(e.full_name, ', ' ORDER BY e.full_name) FROM employee e WHERE (SELECT count(*) FROM job_assignment a WHERE a.employee_id = e.employee_id) > 1 $$,
    'Linden Roark, Marlow Finch');
CALL pg_temp.assert_sql('synthetic', 'Marlow Finch history: Software Engineer then Data Engineer (current)',
    $$ SELECT string_agg(j.job_title || CASE WHEN a.end_date IS NULL THEN ' (current)' ELSE '' END, ' > ' ORDER BY a.start_date)
         FROM employee e JOIN job_assignment a USING (employee_id) JOIN job j USING (job_id) WHERE e.full_name = 'Marlow Finch' $$,
    'Software Engineer > Data Engineer (current)');
CALL pg_temp.assert_sql('synthetic', 'Marlow Finch hire_date = first job start (source hire_dt was the last change date)',
    $$ SELECT hire_date::text FROM employee WHERE employee_number = 'S0004' $$, '2018-03-01');
CALL pg_temp.assert_sql('synthetic', 'Linden Roark: shared boundary day kept (end of first job = start of second)',
    $$ SELECT (SELECT end_date FROM job_assignment a JOIN employee e USING (employee_id) WHERE e.employee_number = 'S0008' AND a.end_date IS NOT NULL)
              = (SELECT start_date FROM job_assignment a JOIN employee e USING (employee_id) WHERE e.employee_number = 'S0008' AND a.end_date IS NULL) $$, 'true');
CALL pg_temp.assert_sql('synthetic', 'only the top manager (Avery Quill) has no manager',
    $$ SELECT string_agg(e.full_name, ', ') FROM job_assignment a JOIN employee e USING (employee_id) WHERE a.manager_id IS NULL $$, 'Avery Quill');
CALL pg_temp.assert_sql('synthetic', 'manager resolution: Juniper Marsh reports to Indigo Vance',
    $$ SELECT m.full_name FROM job_assignment a JOIN employee e ON e.employee_id = a.employee_id JOIN employee m ON m.employee_id = a.manager_id WHERE e.employee_number = 'S0006' $$, 'Indigo Vance');
CALL pg_temp.assert_sql('synthetic', 'cleaning: padded name, upper-case e-mail and lower-case state are normalised',
    $$ SELECT e.full_name || ' | ' || e.email || ' | ' || l.state_code FROM employee e JOIN location l USING (location_id) WHERE e.employee_number = 'S0007' $$,
    'Cedar Wynn | cedar.wynn@example.com | MN');
CALL pg_temp.assert_sql('synthetic', 'cleaning: Minnapolis and Minneapolis collapse into one corrected location',
    $$ SELECT string_agg(city, ',') FROM location WHERE location_name = 'Midwest Hub' $$, 'Minneapolis');
CALL pg_temp.assert_sql('synthetic', 'Q5 headcount by department: Engineering 5, Executive 1, Sales 3',
    $$ SELECT string_agg(department_name || ' ' || c, ', ' ORDER BY department_name) FROM
         (SELECT d.department_name, count(DISTINCT a.employee_id) AS c FROM department d
          LEFT JOIN job_assignment a ON a.department_id = d.department_id AND a.end_date IS NULL GROUP BY d.department_name) t $$,
    'Engineering 5, Executive 1, Sales 3');
\else
CALL pg_temp.info('dataset', 'dataset detected', 'unknown dataset: only the generic assertions were run');
\endif
