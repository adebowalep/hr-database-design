-- =====================================================================
-- Schema specification test. Compares the live PostgreSQL catalog with a hand-maintained list of the expected
-- 7 tables, columns (in order) with data types, primary keys, foreign keys and delete rules.
-- That list is the specification used when reviewing the ERD. The test does NOT read or parse
-- docs/erd/physical_erd.drawio or physical_erd.png, and docs/erd/generate_erds.py has its own copy of the
-- table definitions (PHYS), so the diagram and this list can drift apart independently.
-- If you change schema.sql: update this list AND PHYS in generate_erds.py, regenerate the diagrams, and
-- re-check the picture by eye.
-- =====================================================================
CREATE TEMP TABLE erd_expected (tbl text, cols text);
INSERT INTO erd_expected VALUES
 ('location',        'location_id integer, location_name character varying(50), street_address character varying(100), city character varying(50), state_code character(2)'),
 ('department',      'department_id integer, department_name character varying(50)'),
 ('job',             'job_id integer, job_title character varying(100)'),
 ('education_level', 'education_level_id integer, education_level_name character varying(50)'),
 ('employee',        'employee_id integer, employee_number character varying(8), full_name character varying(100), email character varying(100), hire_date date, location_id integer, education_level_id integer'),
 ('job_assignment',  'assignment_id integer, employee_id integer, job_id integer, department_id integer, manager_id integer, start_date date, end_date date'),
 ('employee_salary', 'salary_id integer, assignment_id integer, salary_amount numeric(10,2)');

DO $$
DECLARE r record; actual text;
BEGIN
    FOR r IN SELECT * FROM erd_expected ORDER BY tbl LOOP
        SELECT string_agg(a.attname || ' ' || format_type(a.atttypid, a.atttypmod), ', ' ORDER BY a.attnum) INTO actual
        FROM pg_attribute a WHERE a.attrelid = ('public.' || r.tbl)::regclass AND a.attnum > 0 AND NOT a.attisdropped;
        PERFORM pg_temp.record('schema-spec', 'columns and types match the expected specification: ' || r.tbl, actual = r.cols, 'actual=' || actual);
    END LOOP;
END $$;

CALL pg_temp.assert_sql('schema-spec', 'exactly the 7 expected tables exist in public',
    $$ SELECT string_agg(c.relname, ',' ORDER BY c.relname) FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'r' AND c.relname <> 'proj_stg' $$,
    'department,education_level,employee,employee_salary,job,job_assignment,location');
CALL pg_temp.assert_sql('schema-spec', 'primary keys match the expected specification',
    $$ SELECT string_agg(conrelid::regclass || '(' || (SELECT string_agg(attname, ',') FROM pg_attribute WHERE attrelid = conrelid AND attnum = ANY (conkey)) || ')', ' ' ORDER BY conrelid::regclass::text)
       FROM pg_constraint WHERE contype = 'p' AND connamespace = 'public'::regnamespace $$,
    'department(department_id) education_level(education_level_id) employee(employee_id) employee_salary(salary_id) job(job_id) job_assignment(assignment_id) location(location_id)');
CALL pg_temp.assert_sql('schema-spec', 'foreign keys (child.column -> parent) match the expected specification',
    $$ SELECT string_agg(conrelid::regclass || '.' || (SELECT attname FROM pg_attribute WHERE attrelid = conrelid AND attnum = conkey[1]) || '->' || confrelid::regclass, ' ' ORDER BY (conrelid::regclass || '.' || (SELECT attname FROM pg_attribute WHERE attrelid = conrelid AND attnum = conkey[1])) COLLATE "C")
       FROM pg_constraint WHERE contype = 'f' AND connamespace = 'public'::regnamespace $$,
    'employee.education_level_id->education_level employee.location_id->location employee_salary.assignment_id->job_assignment job_assignment.department_id->department job_assignment.employee_id->employee job_assignment.job_id->job job_assignment.manager_id->employee');
CALL pg_temp.assert_sql('schema-spec', 'all foreign keys are ON DELETE RESTRICT (confdeltype = r)',
    $$ SELECT count(*) FROM pg_constraint WHERE contype = 'f' AND connamespace = 'public'::regnamespace AND confdeltype <> 'r' $$, '0');
CALL pg_temp.assert_sql('schema-spec', 'salary FK is unique (1:0..1 with job_assignment)',
    $$ SELECT count(*) FROM pg_constraint WHERE conrelid = 'employee_salary'::regclass AND contype = 'u' AND conkey = ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid = 'employee_salary'::regclass AND attname = 'assignment_id')] $$, '1');
