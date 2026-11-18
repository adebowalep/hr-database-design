# Execution evidence

Screenshots here are PNG renderings (terminal style) of real `psql` output, not operating-system screen captures. The `.txt` next to each is the raw output.

## Synthetic demonstrations (regenerated 2026-11-18)
Produced by `make_synthetic_evidence.py`, which runs the SQL against a database built from `data/synthetic/synthetic_proj_stg.sql` (9 fictional employees) and renders the output. Each image title says "SYNTHETIC data".

| Files | What it shows |
|---|---|
| `q1_crud.png`, `q1_full_output.txt` | Q1 current job and department of all 9 employees |
| `q6_crud.png`, `q6_full_output.txt` | Q6 job history of a synthetic employee (run with `-v q6_employee='Marlow Finch'`) |
| `q7_security_test.png`, `q7_security_test_output.txt` | `sql/optional/04_security_test.sql` as `NoMgr` (salary table, staging table, salary view and writes denied) and as `hr_staff` |
| `c1_view_select.png`, `c1_view_output.txt` | `v_employee_directory`, first 10 of 11 rows |
| `c2_procedure_call.png`, `c2_procedure_call_output.txt` | `sp_employee_job_history` for a synthetic employee |
| `c1_view_create.png`, `c3_security_code.png` | code listings rendered from the current repository files (nothing executed) |

## Original course-run evidence kept (no employee records)
`q2`-`q5` (job-title insert/update/delete, department counts), `ddl_1`-`ddl_4`, `c2_procedure_create.png`, `ddl_and_etl_run_output.txt`. These come from the first local run on the course dataset (205 staging rows, 199 employees). They contain job titles, department counts, code and row counts only. The `ddl_*` images show the first version of `schema.sql` (with `DROP ... CASCADE`), which has since been made non-destructive.

Earlier row-level outputs from the course dataset were replaced; see [../PROVENANCE_AND_PRIVACY.md](../PROVENANCE_AND_PRIVACY.md).
