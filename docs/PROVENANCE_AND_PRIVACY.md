# Data provenance and privacy review

Reviewed 2026-11-18 against the repository contents at that date.

## Where the data comes from
* **Original dataset**: the `proj_stg` staging table loaded by `StageTableLoad.sql`, supplied by the Udacity Data Architecture course for a fictional company (Tech ABC Corp, e-mail domain `TechCorp.com`). 205 rows, 199 employees. The course file is **not** in this repository and is git-ignored.
* **Synthetic dataset**: `data/synthetic/synthetic_proj_stg.sql`, written for this repository (9 invented employees, `example.com` addresses, placeholder street names). Nothing was copied from the course file. This is what a clone of the repository uses.

## What I could and could not establish
* The people appear to be fictional (fictional company, generic corporate domain), but **I cannot verify that from the repository**, and I found no licence text stating that the course dataset may be redistributed. Treat redistribution rights as **unconfirmed**; check the course terms.
* No usernames, home-directory paths, passwords, tokens or API keys were found in any tracked text file (searched for `/Users/`, user name, `password`, `secret`, `token`, `api key`, e-mail addresses). `NoMgr` is created without a password.
* The Q1-Q7 and challenge screenshots and the slides were rendered from real psql output (see `docs/validation_results.md`) and contain no paths or credentials.

## Course-derived content that is already published in this repository
| Where | What it shows |
|---|---|
| `docs/screenshots/q1_full_output.txt` (+ `q1_crud.png`, slide deck) | names, job titles and departments of all 199 employees (the PNG: first 12) |
| `docs/screenshots/q7_security_test_output.txt`, `q7_security_test.png`, slide deck | one employee name with one salary value (as `hr_staff`) |
| `docs/screenshots/c1_view_output.txt`, `c1_view_*.png` | employee ids, names, job titles |
| `docs/validation_results.md` | names of the 6 employees with job history; salary range and total |
These were left unchanged: they are the authentic execution evidence of the original course submission, and altering or re-drawing them would make them less authentic. This commit adds **no** new course data (the new security write-up reports only counts and totals).

## Needs your decision (not done without approval)
These files are already in the pushed Git history, so deleting them from the latest commit would **not** remove them from GitHub. Options, from least to most disruptive:
1. Accept the risk after confirming the course allows sharing the fictional data (most likely fine for a portfolio piece).
2. Replace the full 199-name listing and the salary example with redacted versions in a new commit (history still contains the originals).
3. Rewrite history (for example `git filter-repo`) and force-push. Only with your explicit approval, because it changes every commit hash.

## Evidence that is historical
`docs/screenshots/q7_*`, `c3_security_code.png`, slides 22-23 and 27 show the **original** security script (`GRANT SELECT ON ALL TABLES` then `REVOKE`), which had the staging-table hole described in `docs/security/README.md`. Those images are kept as the record of what was submitted; the current script is `sql/optional/03_salary_security.sql`.
