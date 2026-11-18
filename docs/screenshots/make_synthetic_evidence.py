"""Regenerates the row-level evidence in this folder from the SYNTHETIC dataset.

For each item it (1) really runs the SQL with psql against a database you built from
data/synthetic/synthetic_proj_stg.sql + sql/run_all.sql, (2) saves the raw psql output as a .txt file, and
(3) renders that text as a terminal-style PNG. The PNGs are drawings of real output, not operating-system
screen captures. Nothing is typed in by hand.

Usage (from the repository root, PG* environment variables or defaults pointing at a superuser):
    python3 docs/screenshots/make_synthetic_evidence.py hr_demo
Needs: psql on PATH, Pillow, and a monospaced font (Menlo on macOS, DejaVu Sans Mono elsewhere).
"""
import os, re, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

DB = sys.argv[1] if len(sys.argv) > 1 else "hr_demo"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.dirname(os.path.abspath(__file__))
SQL = os.path.join(ROOT, "sql")
FONTS = ["/System/Library/Fonts/Menlo.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", "C:/Windows/Fonts/consola.ttf"]
FS, LH, PAD = 22, 29, 30
BG, BAR, FG = (24, 26, 31), (44, 46, 54), (232, 232, 232)
BLUE, GREEN, GREY = (130, 180, 255), (120, 200, 120), (150, 154, 164)
KW = r"\b(?:SELECT|FROM|JOIN|LEFT|ON|AND|WHERE|ORDER BY|GROUP BY|AS|LIMIT|INSERT INTO|VALUES|UPDATE|SET|DELETE|CREATE|OR REPLACE|VIEW|PROCEDURE|ROLE|GRANT|REVOKE|TO|FROM|ALL|TABLE|BEGIN|COMMIT|CALL|FETCH|IN|DO|IF|NOT|EXISTS|NULL|WITH|LANGUAGE|RETURNS|DEFAULT|USING|IS|OPEN|FOR|END|DECLARE|INOUT|IN|ON|SCHEMA|PUBLIC|LOGIN|NOLOGIN|SELECT)\b"


def font():
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, FS)
    raise SystemExit("no monospaced font found; edit FONTS in this script")


def run_psql(sql_text, extra=()):
    r = subprocess.run(["psql", "-d", DB, "-q", "-a", "-X", "-v", "ON_ERROR_STOP=0", *extra],
                       input=sql_text, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=True)
    return r.stdout.replace("psql:<stdin>:", "").rstrip() + "\n"


def run_file(path):
    # run from the script's own folder with a relative name so error messages carry no local absolute path
    r = subprocess.run(["psql", "-d", DB, "-q", "-a", "-X", "-f", os.path.basename(path)], cwd=os.path.dirname(path), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=True)
    return r.stdout.rstrip() + "\n"


def section(name):
    t = open(os.path.join(SQL, "crud_queries.sql")).read()
    m = re.search(r"-- ### %s\n(.*?)(?=\n-- ### |\Z)" % name, t, re.S)
    return m.group(1)


def render(text, title, png):
    f = font(); lines = text.rstrip("\n").split("\n")
    d0 = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    w = int(max(d0.textlength(l, font=f) for l in lines + [title])) + 2 * PAD + 60
    h = 46 + PAD + LH * len(lines) + PAD
    im = Image.new("RGB", (max(w, 900), h), BG); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, im.width, 46], fill=BAR)
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        d.ellipse([20 + i * 28 - 9, 23 - 9, 20 + i * 28 + 9, 23 + 9], fill=c)
    d.text((110, 10), title, font=f, fill=GREY)
    y = 46 + PAD
    for l in lines:
        if re.match(r"^[-+]+$", l.strip()) and "-" in l and len(l.strip()) > 3:
            d.text((PAD, y), l, font=f, fill=GREEN)
        elif l.lstrip().startswith("--"):
            d.text((PAD, y), l, font=f, fill=GREEN)
        elif l.startswith("psql:") or l.startswith(" ") or l.startswith("("):
            d.text((PAD, y), l, font=f, fill=FG)           # error lines and result rows: no keyword colouring
        else:
            x = PAD
            for tok in re.split("(%s)" % KW, l, flags=re.I):
                col = BLUE if re.fullmatch(KW, tok, flags=re.I) else FG
                d.text((x, y), tok, font=f, fill=col); x += d0.textlength(tok, font=f)
        y += LH
    im.save(os.path.join(OUT, png))


def save(txt_name, text):
    open(os.path.join(OUT, txt_name), "w").write(text)


LABEL = "(actual execution, SYNTHETIC data)"
# Q1
q1 = run_psql(section("Q1")); save("q1_full_output.txt", q1); render(q1, "psql  %s=#  Q1  %s" % (DB, LABEL), "q1_crud.png")
# Q6 (variable passed explicitly; backslash lines from the file are not part of the executed query text)
q6sql = "\n".join(l for l in section("Q6").split("\n") if not l.startswith("\\") and not l.startswith("  \\"))
q6 = "-- psql -v q6_employee='Marlow Finch'\n" + run_psql(q6sql, ["-v", "q6_employee=Marlow Finch"])
save("q6_full_output.txt", q6); render(q6, "psql  %s=#  Q6  %s" % (DB, LABEL), "q6_crud.png")
# Q7 / security test: runs sql/optional/04_security_test.sql as is
q7 = run_file(os.path.join(SQL, "optional", "04_security_test.sql"))
save("q7_security_test_output.txt", q7); render(q7, "psql  %s=#  04_security_test.sql  %s" % (DB, LABEL), "q7_security_test.png")
# Challenge 1 view
c1 = run_psql("SELECT emp_id, emp_nm, job_title, department_nm, start_dt, end_dt\n  FROM v_employee_directory ORDER BY emp_id, start_dt LIMIT 10;\n")
save("c1_view_output.txt", c1); render(c1, "psql  %s=#  v_employee_directory  %s" % (DB, LABEL), "c1_view_select.png")
# Challenge 2 procedure
c2 = run_psql("BEGIN;\nCALL sp_employee_job_history('Marlow Finch', 'job_history');\nFETCH ALL FROM job_history;\nCOMMIT;\n")
save("c2_procedure_call_output.txt", c2); render(c2, "psql  %s=#  sp_employee_job_history  %s" % (DB, LABEL), "c2_procedure_call.png")
# Code listings of the current repository files (rendering only, nothing executed)
for src, png in [("optional/01_employee_view.sql", "c1_view_create.png"), ("optional/03_salary_security.sql", "c3_security_code.png")]:
    code = open(os.path.join(SQL, src)).read()
    render(code, "sql/%s  (code listing rendered from the repository file)" % src, png)
print("evidence regenerated from database", DB)
