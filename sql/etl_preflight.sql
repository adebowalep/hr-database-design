-- =====================================================================
-- etl_preflight.sql  |  Data-quality gate for the staging table. Included by etl_from_proj_stg.sql.
--
-- etl_check_staging(stg) raises an exception (with a distinct SQLSTATE) instead of letting the ETL
-- silently pick a value. Values are compared AFTER the same cleaning the ETL applies
-- (trim, collapse double spaces, lower-case email, upper-case state, 'Minnapolis' fix).
--
--   EL001 missing required value              EL009 manager name matches no employee
--   EL002 one Emp_ID, several names           EL010 employee listed as own manager
--   EL003 one Emp_ID, several emails          EL011 end date before start date
--   EL004 one Emp_ID, several locations       EL012 several current rows for one employee
--   EL005 one Emp_ID, several education lvls  EL013 overlapping job periods
--   EL006 one email on several Emp_IDs        EL014 salary not positive
--   EL007 duplicate (Emp_ID, start date)      EL015 management cycle among current rows
--   EL008 one name on several Emp_IDs (managers are resolved by name, so names must be unique)
--
-- hire_dt is deliberately NOT checked for consistency: in the course data it holds the date of the
-- employee's last job change, so it legitimately differs between an employee's rows. The ETL stores
-- hire_date = earliest of (hire_dt, first start_dt).
-- =====================================================================
CREATE OR REPLACE FUNCTION etl_check_staging(p_stg regclass) RETURNS void
LANGUAGE plpgsql AS $fn$
DECLARE
    v_bad text;
BEGIN
    DROP TABLE IF EXISTS pg_temp._stg_norm;
    EXECUTE format($q$
        CREATE TEMP TABLE _stg_norm ON COMMIT DROP AS
        SELECT trim(emp_id)                                   AS emp_id,
               regexp_replace(trim(emp_nm), '\s+', ' ', 'g')  AS nm,
               lower(trim(email))                             AS email,
               hire_dt,
               trim(job_title)                                AS job_title,
               salary,
               trim(department_nm)                            AS dept,
               regexp_replace(trim(manager), '\s+', ' ', 'g') AS mgr,
               start_dt, end_dt,
               trim(location)                                 AS loc,
               trim(address)                                  AS address,
               CASE WHEN trim(city) = 'Minnapolis' THEN 'Minneapolis' ELSE trim(city) END AS city,
               upper(trim(state))                             AS state,
               trim(education_lvl)                            AS edu
        FROM %s $q$, p_stg);

    -- EL001
    SELECT string_agg(DISTINCT coalesce(emp_id, '<null emp_id>'), ', ') INTO v_bad FROM _stg_norm
    WHERE emp_id IS NULL OR emp_id = '' OR nm IS NULL OR nm = '' OR email IS NULL OR email = '' OR hire_dt IS NULL
       OR job_title IS NULL OR job_title = '' OR salary IS NULL OR dept IS NULL OR dept = '' OR mgr IS NULL OR mgr = ''
       OR start_dt IS NULL OR end_dt IS NULL OR loc IS NULL OR loc = '' OR address IS NULL OR city IS NULL OR state IS NULL OR edu IS NULL OR edu = '';
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL001: required value missing for Emp_ID(s): %', v_bad USING ERRCODE = 'EL001'; END IF;

    -- EL002..EL005: attributes stored once per employee must not differ between that employee's rows
    SELECT string_agg(emp_id, ', ') INTO v_bad FROM (SELECT emp_id FROM _stg_norm GROUP BY emp_id HAVING count(DISTINCT nm) > 1) t;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL002: conflicting names for Emp_ID(s): %', v_bad USING ERRCODE = 'EL002'; END IF;
    SELECT string_agg(emp_id, ', ') INTO v_bad FROM (SELECT emp_id FROM _stg_norm GROUP BY emp_id HAVING count(DISTINCT email) > 1) t;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL003: conflicting emails for Emp_ID(s): %', v_bad USING ERRCODE = 'EL003'; END IF;
    SELECT string_agg(emp_id, ', ') INTO v_bad FROM (SELECT emp_id FROM _stg_norm GROUP BY emp_id HAVING count(DISTINCT loc) > 1) t;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL004: conflicting locations for Emp_ID(s): % (employee.location_id holds one location per person)', v_bad USING ERRCODE = 'EL004'; END IF;
    SELECT string_agg(emp_id, ', ') INTO v_bad FROM (SELECT emp_id FROM _stg_norm GROUP BY emp_id HAVING count(DISTINCT edu) > 1) t;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL005: conflicting education levels for Emp_ID(s): %', v_bad USING ERRCODE = 'EL005'; END IF;

    -- EL006 / EL008: identifiers that must be unique across employees
    SELECT string_agg(email, ', ') INTO v_bad FROM (SELECT email FROM _stg_norm GROUP BY email HAVING count(DISTINCT emp_id) > 1) t;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL006: email shared by several Emp_IDs: %', v_bad USING ERRCODE = 'EL006'; END IF;
    SELECT string_agg(nm, ', ') INTO v_bad FROM (SELECT nm FROM _stg_norm GROUP BY nm HAVING count(DISTINCT emp_id) > 1) t;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL008: name shared by several Emp_IDs (manager lookup by name would be ambiguous): %', v_bad USING ERRCODE = 'EL008'; END IF;

    -- EL007
    SELECT string_agg(emp_id || '@' || start_dt, ', ') INTO v_bad FROM (SELECT emp_id, start_dt FROM _stg_norm GROUP BY 1, 2 HAVING count(*) > 1) t;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL007: duplicate (Emp_ID, start date): %', v_bad USING ERRCODE = 'EL007'; END IF;

    -- EL009: every manager (except the literal text None) must be exactly one known employee name
    SELECT string_agg(DISTINCT s.mgr, ', ') INTO v_bad FROM _stg_norm s
    WHERE lower(s.mgr) <> 'none' AND NOT EXISTS (SELECT 1 FROM _stg_norm e WHERE e.nm = s.mgr);
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL009: manager name matches no employee: %', v_bad USING ERRCODE = 'EL009'; END IF;

    -- EL010
    SELECT string_agg(DISTINCT emp_id, ', ') INTO v_bad FROM _stg_norm WHERE lower(mgr) <> 'none' AND mgr = nm;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL010: employee is their own manager: %', v_bad USING ERRCODE = 'EL010'; END IF;

    -- EL011 / EL014
    SELECT string_agg(emp_id || '@' || start_dt, ', ') INTO v_bad FROM _stg_norm WHERE end_dt < start_dt;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL011: end date before start date: %', v_bad USING ERRCODE = 'EL011'; END IF;
    SELECT string_agg(emp_id, ', ') INTO v_bad FROM _stg_norm WHERE salary <= 0;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL014: salary not positive for Emp_ID(s): %', v_bad USING ERRCODE = 'EL014'; END IF;

    -- EL012: end_dt in 2099+ is the "current job" placeholder; at most one per employee
    SELECT string_agg(emp_id, ', ') INTO v_bad FROM (SELECT emp_id FROM _stg_norm WHERE end_dt >= DATE '2099-01-01' GROUP BY emp_id HAVING count(*) > 1) t;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL012: more than one current (placeholder end date) row for Emp_ID(s): %', v_bad USING ERRCODE = 'EL012'; END IF;

    -- EL013: a job period may not start before the previous one ended (a shared boundary day is allowed: the course data has them)
    SELECT string_agg(DISTINCT a.emp_id, ', ') INTO v_bad
    FROM _stg_norm a JOIN _stg_norm b ON a.emp_id = b.emp_id AND a.start_dt < b.start_dt
    WHERE LEAST(a.end_dt, DATE '2099-01-01') > b.start_dt;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL013: overlapping job periods for Emp_ID(s): %', v_bad USING ERRCODE = 'EL013'; END IF;

    -- EL015: following manager links from any current row must end at a person with no manager
    WITH RECURSIVE cur AS (
        SELECT s.nm, CASE WHEN lower(s.mgr) = 'none' THEN NULL ELSE s.mgr END AS mgr
        FROM _stg_norm s WHERE s.end_dt >= DATE '2099-01-01'),
    walk AS (
        SELECT nm AS start_nm, mgr AS cur_nm, 1 AS depth FROM cur
        UNION ALL
        SELECT w.start_nm, c.mgr, w.depth + 1 FROM walk w JOIN cur c ON c.nm = w.cur_nm
        WHERE w.depth <= (SELECT count(*) FROM cur))
    SELECT string_agg(DISTINCT start_nm, ', ') INTO v_bad FROM walk
    WHERE cur_nm = start_nm;
    IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'ETL preflight EL015: management cycle involving: %', v_bad USING ERRCODE = 'EL015'; END IF;
END
$fn$;

REVOKE ALL ON FUNCTION etl_check_staging(regclass) FROM PUBLIC;
