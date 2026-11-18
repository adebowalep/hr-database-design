-- Challenge 3 / Question 7: table-level security for salary data (least privilege).
-- Run as a superuser/owner (postgres). Only creates the roles named here; no other users are touched.
-- No passwords are stored in this script. For real logins, set one separately:  ALTER ROLE "NoMgr" PASSWORD '...';
--
-- Design: an explicit ALLOW-list. Nothing is granted with "ALL TABLES".
--   The first version of this script granted SELECT on ALL TABLES IN SCHEMA public to hr_read and then
--   revoked the salary table and view. That is a deny-list: it fails open for any object not named in
--   the REVOKE. The raw staging table proj_stg (which still holds every salary) was readable by hr_read.
--   See docs/security/ for the before/after test output.
--
-- Salary data lives in exactly three places and none is granted to hr_read:
--   employee_salary, v_employee_full_hr (view over it), proj_stg (staging copy with a salary column).

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='hr_read')  THEN CREATE ROLE hr_read  NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='hr_staff') THEN CREATE ROLE hr_staff NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='NoMgr')    THEN CREATE ROLE "NoMgr" LOGIN;   END IF;
END $$;

-- 1. Start closed: no PUBLIC access to salary-bearing objects, and nobody can create objects in public.
REVOKE ALL ON employee_salary, v_employee_full_hr FROM PUBLIC;
DO $$ BEGIN
  IF to_regclass('public.proj_stg') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON public.proj_stg FROM PUBLIC, hr_read, hr_staff';   -- staging stays owner-only (used by the ETL)
  END IF;
END $$;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO hr_read, hr_staff;

-- 2. hr_read (ordinary employees): read-only on the non-sensitive tables and the directory view. Nothing else.
REVOKE ALL ON employee, job_assignment, job, department, location, education_level, v_employee_directory FROM hr_read;
GRANT SELECT ON employee, job_assignment, job, department, location, education_level, v_employee_directory TO hr_read;

-- 3. hr_staff (HR / management): read + write the seven HR tables including salary, read both views.
--    No TRUNCATE, no DDL, no access to the staging table.
REVOKE ALL ON employee, job_assignment, employee_salary, job, department, location, education_level,
              v_employee_directory, v_employee_full_hr FROM hr_staff;
GRANT SELECT, INSERT, UPDATE, DELETE ON employee, job_assignment, employee_salary, job, department, location, education_level TO hr_staff;
GRANT SELECT ON v_employee_directory, v_employee_full_hr TO hr_staff;

-- 4. Non-management user NoMgr: member of hr_read only.
GRANT hr_read TO "NoMgr";
