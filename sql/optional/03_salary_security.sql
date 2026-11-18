-- Challenge 3 / Question 7: table-level security for salary data.
-- Run as a superuser/owner (postgres). Only creates the roles named here; no other users are touched.
-- No passwords are stored in this script. For real logins, set one separately:  ALTER ROLE "NoMgr" PASSWORD '...';

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='hr_read')  THEN CREATE ROLE hr_read  NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='hr_staff') THEN CREATE ROLE hr_staff NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='NoMgr')    THEN CREATE ROLE "NoMgr" LOGIN;   END IF;
END $$;

-- 1. Nobody gets salary access by default
REVOKE ALL ON employee_salary, v_employee_full_hr FROM PUBLIC;

-- 2. Read-only group for ordinary employees: all tables/views, then take salary away (company policy: grant all, revoke restricted)
GRANT USAGE ON SCHEMA public TO hr_read, hr_staff;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO hr_read;
REVOKE ALL ON employee_salary, v_employee_full_hr FROM hr_read;

-- 3. HR/management group: read + write everything, including salary
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hr_staff;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO hr_staff;

-- 4. Non-management user NoMgr: member of hr_read only
GRANT hr_read TO "NoMgr";
