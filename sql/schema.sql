-- =====================================================================
-- Tech ABC Corp - HR Database  |  schema.sql (DDL)   PostgreSQL 15+
-- Run order: schema.sql -> etl_from_proj_stg.sql -> optional/*.sql -> crud_queries.sql  (or just run_all.sql)
-- NON-DESTRUCTIVE: this script only creates objects. If the HR tables already exist it stops with an
-- error instead of dropping anything. To rebuild a disposable database use reset_dev.sql (explicit confirmation).
-- The staging table proj_stg is never touched here.
-- =====================================================================
DO $$
BEGIN
    IF to_regclass('public.employee') IS NOT NULL OR to_regclass('public.job_assignment') IS NOT NULL
       OR to_regclass('public.employee_salary') IS NOT NULL THEN
        RAISE EXCEPTION 'HR tables already exist in database "%": schema.sql will not drop them. Use a new database, or sql/reset_dev.sql for a disposable one.', current_database();
    END IF;
END $$;

-- ---------- Lookup tables ----------
CREATE TABLE location (
    location_id     INTEGER GENERATED ALWAYS AS IDENTITY,
    location_name   VARCHAR(50)  NOT NULL,          -- e.g. HQ, West Coast
    street_address  VARCHAR(100) NOT NULL,
    city            VARCHAR(50)  NOT NULL,
    state_code      CHAR(2)      NOT NULL,
    CONSTRAINT pk_location PRIMARY KEY (location_id),
    CONSTRAINT uq_location_name UNIQUE (location_name),
    CONSTRAINT uq_location_address UNIQUE (street_address, city, state_code)
);

CREATE TABLE department (
    department_id   INTEGER GENERATED ALWAYS AS IDENTITY,
    department_name VARCHAR(50) NOT NULL,
    CONSTRAINT pk_department PRIMARY KEY (department_id),
    CONSTRAINT uq_department_name UNIQUE (department_name)
);

CREATE TABLE job (
    job_id    INTEGER GENERATED ALWAYS AS IDENTITY,
    job_title VARCHAR(100) NOT NULL,
    CONSTRAINT pk_job PRIMARY KEY (job_id),
    CONSTRAINT uq_job_title UNIQUE (job_title)
);

CREATE TABLE education_level (
    education_level_id   INTEGER GENERATED ALWAYS AS IDENTITY,
    education_level_name VARCHAR(50) NOT NULL,
    CONSTRAINT pk_education_level PRIMARY KEY (education_level_id),
    CONSTRAINT uq_education_level_name UNIQUE (education_level_name)
);

-- ---------- Employee (one row per person) ----------
CREATE TABLE employee (
    employee_id        INTEGER GENERATED ALWAYS AS IDENTITY,
    employee_number    VARCHAR(8)   NOT NULL,       -- business ID from the spreadsheet, e.g. S0004
    full_name          VARCHAR(100) NOT NULL,
    email              VARCHAR(100) NOT NULL,
    hire_date          DATE         NOT NULL,
    location_id        INTEGER      NOT NULL,
    education_level_id INTEGER      NOT NULL,
    CONSTRAINT pk_employee PRIMARY KEY (employee_id),
    CONSTRAINT uq_employee_number UNIQUE (employee_number),
    CONSTRAINT uq_employee_email  UNIQUE (email),
    CONSTRAINT fk_employee_location  FOREIGN KEY (location_id)
        REFERENCES location (location_id) ON DELETE RESTRICT,
    CONSTRAINT fk_employee_education FOREIGN KEY (education_level_id)
        REFERENCES education_level (education_level_id) ON DELETE RESTRICT
);

-- ---------- Job history (one row per employee per job/department/manager period) ----------
-- end_date NULL = current position (the source used placeholder dates in 2100).
CREATE TABLE job_assignment (
    assignment_id INTEGER GENERATED ALWAYS AS IDENTITY,
    employee_id   INTEGER NOT NULL,
    job_id        INTEGER NOT NULL,
    department_id INTEGER NOT NULL,
    manager_id    INTEGER NULL,                     -- self-reference to employee; NULL for the President
    start_date    DATE    NOT NULL,
    end_date      DATE    NULL,
    CONSTRAINT pk_job_assignment PRIMARY KEY (assignment_id),
    CONSTRAINT fk_assignment_employee   FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id)     ON DELETE RESTRICT,
    CONSTRAINT fk_assignment_job        FOREIGN KEY (job_id)
        REFERENCES job (job_id)               ON DELETE RESTRICT,
    CONSTRAINT fk_assignment_department FOREIGN KEY (department_id)
        REFERENCES department (department_id) ON DELETE RESTRICT,
    CONSTRAINT fk_assignment_manager    FOREIGN KEY (manager_id)
        REFERENCES employee (employee_id)     ON DELETE RESTRICT,
    CONSTRAINT uq_assignment_employee_start UNIQUE (employee_id, start_date),
    CONSTRAINT ck_assignment_dates   CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT ck_assignment_manager CHECK (manager_id IS NULL OR manager_id <> employee_id)
);
-- An employee can have only one current (open-ended) assignment
CREATE UNIQUE INDEX uq_assignment_one_current
    ON job_assignment (employee_id) WHERE end_date IS NULL;

-- ---------- RESTRICTED: salary (table-level security applied in optional/03_salary_security.sql) ----------
CREATE TABLE employee_salary (
    salary_id     INTEGER GENERATED ALWAYS AS IDENTITY,
    assignment_id INTEGER       NOT NULL,
    salary_amount NUMERIC(10,2) NOT NULL,
    CONSTRAINT pk_employee_salary PRIMARY KEY (salary_id),
    CONSTRAINT uq_salary_assignment UNIQUE (assignment_id),   -- one salary per job assignment
    CONSTRAINT fk_salary_assignment FOREIGN KEY (assignment_id)
        REFERENCES job_assignment (assignment_id) ON DELETE RESTRICT,
    CONSTRAINT ck_salary_positive CHECK (salary_amount > 0)
);

-- ---------- Indexes on foreign keys / common searches ----------
CREATE INDEX ix_employee_location   ON employee (location_id);
CREATE INDEX ix_employee_education  ON employee (education_level_id);
CREATE INDEX ix_employee_full_name  ON employee (full_name);
CREATE INDEX ix_assignment_employee ON job_assignment (employee_id);
CREATE INDEX ix_assignment_job      ON job_assignment (job_id);
CREATE INDEX ix_assignment_dept     ON job_assignment (department_id);
CREATE INDEX ix_assignment_manager  ON job_assignment (manager_id);
