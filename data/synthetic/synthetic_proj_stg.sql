-- =====================================================================
-- SYNTHETIC staging data for Tech ABC Corp (fictional company).
-- Every name, e-mail, address and salary below was invented for this repository. It is NOT derived from the
-- course-provided dataset and is safe to publish. Nothing here describes a real person.
--
-- It creates a table named proj_stg with the SAME columns as the course staging table, so sql/etl_from_proj_stg.sql
-- runs unchanged. Load it into an empty, disposable database only (the CREATE TABLE fails if proj_stg exists).
--
-- What the 11 rows (9 employees) are built to exercise:
--   * S0001 Avery Quill      top of the hierarchy, manager text 'None'            -> NULL manager_id
--   * S0004 Marlow Finch     2 job periods, source hire_dt = date of LAST change  -> hire_date = first start_dt
--   * S0008 Linden Roark     2 job periods in different departments, shared boundary day (end = next start)
--   * S0007 Cedar  Wynn      double space in name, upper-case e-mail, padded text  -> cleaning rules
--   * S0006 / S0005 / S0009  location 'Midwest Hub' spelled city 'Minnapolis'     -> corrected to Minneapolis
--   * 3 departments, 6 job titles, 3 locations, 4 education levels
--   * end_dt 2100-xx-xx = placeholder for "current job" -> NULL
-- =====================================================================
CREATE TABLE proj_stg (Emp_ID varchar(8),
                       Emp_NM varchar(50),
                       Email  varchar(100),
                       hire_dt date,
                       job_title varchar(100),
                       salary int,
                       department_nm varchar(50),
                       manager varchar(50),
                       start_dt date,
                       end_dt date,
                       location varchar(50),
                       address varchar(100),
                       city varchar(50),
                       state varchar(2),
                       education_lvl varchar(50));

INSERT INTO proj_stg (Emp_ID, Emp_NM, email, hire_dt, job_title, salary, department_nm, manager, start_dt, end_dt, location, address, city, state, education_lvl)
VALUES
('S0001', 'Avery Quill',     'Avery.Quill@example.com',     '2009-02-02', 'President',            250000, 'Executive',   'None',         '2009-02-02', '2100-01-01', 'HQ',          '1 Example Plaza',   'Springfield', 'EX', 'Master''s Degree'),
('S0002', 'Rowan Pike',      'Rowan.Pike@example.com',      '2012-05-14', 'Engineering Manager',  150000, 'Engineering', 'Avery Quill',  '2012-05-14', '2100-01-02', 'HQ',          '1 Example Plaza',   'Springfield', 'EX', 'Bachelor''s Degree'),
('S0003', 'Sage Holloway',   'Sage.Holloway@example.com',   '2016-09-19', 'Software Engineer',    105000, 'Engineering', 'Rowan Pike',   '2016-09-19', '2100-01-03', 'HQ',          '1 Example Plaza',   'Springfield', 'EX', 'Bachelor''s Degree'),
('S0004', 'Marlow Finch',    'Marlow.Finch@example.com',    '2021-07-01', 'Software Engineer',     88000, 'Engineering', 'Rowan Pike',   '2018-03-01', '2021-06-30', 'HQ',          '1 Example Plaza',   'Springfield', 'EX', 'Some College'),
('S0004', 'Marlow Finch',    'Marlow.Finch@example.com',    '2021-07-01', 'Data Engineer',        112000, 'Engineering', 'Rowan Pike',   '2021-07-01', '2100-01-04', 'HQ',          '1 Example Plaza',   'Springfield', 'EX', 'Some College'),
('S0005', 'Indigo Vance',    'Indigo.Vance@example.com',    '2013-01-21', 'Sales Manager',        120000, 'Sales',       'Avery Quill',  '2013-01-21', '2100-01-05', 'Midwest Hub', '22 Sample Avenue',  'Minnapolis',  'MN', 'Bachelor''s Degree'),
('S0006', 'Juniper Marsh',   'Juniper.Marsh@example.com',   '2019-04-08', 'Sales Representative',  64000, 'Sales',       'Indigo Vance', '2019-04-08', '2100-01-06', 'Midwest Hub', '22 Sample Avenue',  'Minnapolis',  'MN', 'Associates Degree'),
('S0007', ' Cedar  Wynn ',   'CEDAR.WYNN@EXAMPLE.COM ',     '2020-10-12', ' Sales Representative ', 61000, 'Sales',      'Indigo Vance', '2020-10-12', '2100-01-07', 'Midwest Hub', '22 Sample Avenue',  'Minneapolis', 'mn', 'Associates Degree'),
('S0008', 'Linden Roark',    'Linden.Roark@example.com',    '2022-02-28', 'Sales Representative',  60000, 'Sales',       'Indigo Vance', '2019-01-07', '2022-02-28', 'West Hub',    '9 Placeholder Road', 'Riverton',   'WX', 'Bachelor''s Degree'),
('S0008', 'Linden Roark',    'Linden.Roark@example.com',    '2022-02-28', 'Software Engineer',     97000, 'Engineering', 'Rowan Pike',   '2022-02-28', '2100-01-08', 'West Hub',    '9 Placeholder Road', 'Riverton',   'WX', 'Bachelor''s Degree'),
('S0009', 'Wren Calder',     'Wren.Calder@example.com',     '2023-06-05', 'Data Engineer',         99000, 'Engineering', 'Rowan Pike',   '2023-06-05', '2100-01-09', 'West Hub',    '9 Placeholder Road', 'Riverton',   'WX', 'Master''s Degree');
