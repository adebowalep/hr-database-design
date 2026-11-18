# Backup, retention and recovery (design notes)

This is an educational design. **No backup job, retention policy or disaster-recovery setup is configured or running** in this repository. This page separates concepts that the first README mixed up.

| Topic | What it is | Status here |
|---|---|---|
| Foreign-key delete behaviour (`ON DELETE RESTRICT`) | Stops a row being deleted while other rows still reference it (for example a job, department, manager or an employee who has job history). It protects referential integrity. | Implemented and tested (`tests/30_constraints.sql`) |
| Retention requirement | A business/legal rule such as "keep employee records for 7+ years". | A requirement from the course brief only. `ON DELETE RESTRICT` does **not** enforce it: an employee row with no references can still be deleted, and a superuser or `hr_staff` can delete unreferenced data. |
| Backup policy | The IT Best Practices guide in the course classes this database as Critical: weekly full backup plus daily incremental backup. | Policy only, not configured |
| Backup implementation | The tooling that produces the backups. | Examples below; only the logical dump/restore was tried locally |
| Disaster recovery | Restoring service after losing the server: restore procedure, restore tests, target recovery time and data loss. | Not designed here |

## How the policy could be implemented with standard PostgreSQL tools
* **Logical backup** (small databases, any version): `pg_dump -Fc -d hr -f hr.dump`, restore with `pg_restore -d newdb hr.dump`. Tried locally on the synthetic database: the restored copy passed the test suite. A logical dump is always a full backup, so it covers the "weekly full" part only.
* **Physical full + incremental backup** (PostgreSQL 17+): `pg_basebackup` for the weekly full backup; with `summarize_wal = on`, `pg_basebackup --incremental=<previous manifest>` for the daily incremental ones; `pg_combinebackup` to combine them for restore. Not tried here.
* **Point-in-time recovery**: continuous WAL archiving (`archive_mode`, `archive_command`) on top of a base backup. Not tried here.
* **Scheduling and retention of backup files**: an external scheduler (cron, systemd timer, a backup tool) and a rule for deleting old backups. Not provided.
* **A backup that has never been restored is unproven.** Schedule a periodic restore test.

## What would be needed to actually enforce 7-year retention
Soft deletion or an archive table instead of `DELETE`, no `DELETE` privilege for ordinary roles (already the case for `hr_read`; `hr_staff` currently has `DELETE`), and audit logging of changes. None of this is implemented.
