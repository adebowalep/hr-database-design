"""Generates the three ERDs (PNG + editable draw.io XML) for the Tech ABC Corp HR database.
Usage: python3 generate_erds.py   (needs Pillow). Output goes next to this file.
Lucidchart was not accessible from this environment, so diagrams.net-compatible (.drawio) files are provided as the editable sources.
"""
import os
from xml.sax.saxutils import escape
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
FR = "/System/Library/Fonts/Supplemental/Arial.ttf"
FB = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FI = "/System/Library/Fonts/Supplemental/Arial Italic.ttf"
S = 2                      # supersample factor
BLUE, GREY, RED = (200, 214, 236), (236, 238, 242), (250, 214, 210)
INK, LINE = (30, 34, 44), (60, 64, 76)


def font(p, s): return ImageFont.truetype(p, int(s * S))


# ------------------------------------------------------------------ data model
# Physical model: (column, type, key)  key in {"PK","FK",""}
PHYS = {
    "location": [("location_id", "INTEGER", "PK"), ("location_name", "VARCHAR(50)", ""), ("street_address", "VARCHAR(100)", ""),
                 ("city", "VARCHAR(50)", ""), ("state_code", "CHAR(2)", "")],
    "employee": [("employee_id", "INTEGER", "PK"), ("employee_number", "VARCHAR(8)", ""), ("full_name", "VARCHAR(100)", ""),
                 ("email", "VARCHAR(100)", ""), ("hire_date", "DATE", ""), ("location_id", "INTEGER", "FK"),
                 ("education_level_id", "INTEGER", "FK")],
    "education_level": [("education_level_id", "INTEGER", "PK"), ("education_level_name", "VARCHAR(50)", "")],
    "job": [("job_id", "INTEGER", "PK"), ("job_title", "VARCHAR(100)", "")],
    "job_assignment": [("assignment_id", "INTEGER", "PK"), ("employee_id", "INTEGER", "FK"), ("job_id", "INTEGER", "FK"),
                       ("department_id", "INTEGER", "FK"), ("manager_id", "INTEGER", "FK"), ("start_date", "DATE", ""),
                       ("end_date", "DATE", "")],
    "department": [("department_id", "INTEGER", "PK"), ("department_name", "VARCHAR(50)", "")],
    "employee_salary": [("salary_id", "INTEGER", "PK"), ("assignment_id", "INTEGER", "FK"), ("salary_amount", "NUMERIC(10,2)", "")],
}
LOGI = {
    "Location": ["Location ID (PK)", "Location Name", "Street Address", "City", "State"],
    "Employee": ["Employee ID (PK)", "Employee Number", "Full Name", "Email", "Hire Date", "Location ID (FK)", "Education Level ID (FK)"],
    "Education Level": ["Education Level ID (PK)", "Education Level Name"],
    "Job": ["Job ID (PK)", "Job Title"],
    "Job Assignment": ["Assignment ID (PK)", "Employee ID (FK)", "Job ID (FK)", "Department ID (FK)", "Manager ID (FK to Employee)",
                       "Start Date", "End Date (blank = current job)"],
    "Department": ["Department ID (PK)", "Department Name"],
    "Salary (Restricted)": ["Salary ID (PK)", "Assignment ID (FK)", "Salary Amount"],
}
# column x origin / y origin for the 3x3 grid (same layout for the three diagrams)
POS = {"left": 30, "mid": 585, "right": 1140}
TW = 420
Y1, Y2, Y3 = 110, 560, 960


class Node:
    def __init__(self, name, rows, x, y, w, kind, restricted=False):
        self.name, self.rows, self.x, self.y, self.w, self.kind, self.restricted = name, rows, x, y, w, kind, restricted
        self.hh, self.rh = 46, 36
        self.h = self.hh + max(len(rows), 1) * self.rh if rows else 96

    def row_y(self, i): return self.y + self.hh + i * self.rh + self.rh / 2
    def left(self, i=None): return (self.x, self.row_y(i) if i is not None else self.y + self.h / 2)
    def right(self, i=None): return (self.x + self.w, self.row_y(i) if i is not None else self.y + self.h / 2)
    def top(self, dx=0.5): return (self.x + self.w * dx if dx <= 1 else self.x + dx, self.y)
    def bottom(self, dx=0.5): return (self.x + self.w * dx if dx <= 1 else self.x + dx, self.y + self.h)


def build_nodes(kind):
    nodes = {}
    if kind == "physical":
        place = {"location": ("left", Y1), "employee": ("mid", Y1), "education_level": ("right", Y1), "job": ("left", Y2),
                 "job_assignment": ("mid", Y2), "department": ("right", Y2), "employee_salary": ("mid", Y3)}
        for n, (c, y) in place.items():
            nodes[n] = Node(n, PHYS[n], POS[c], y, TW, kind, n == "employee_salary")
    elif kind == "logical":
        place = {"Location": ("left", Y1), "Employee": ("mid", Y1), "Education Level": ("right", Y1), "Job": ("left", Y2),
                 "Job Assignment": ("mid", Y2), "Department": ("right", Y2), "Salary (Restricted)": ("mid", Y3)}
        for n, (c, y) in place.items():
            nodes[n] = Node(n, LOGI[n], POS[c], y, TW, kind, n.startswith("Salary"))
    else:
        place = {"Location": ("left", 130), "Employee": ("mid", 130), "Education Level": ("right", 130), "Job": ("left", 560),
                 "Job Assignment": ("mid", 560), "Department": ("right", 560), "Salary (Restricted)": ("mid", 990)}
        for n, (c, y) in place.items():
            nodes[n] = Node(n, None, POS[c], y, TW, kind, n.startswith("Salary"))
    return nodes


def idx(node, col):
    return [r[0] if isinstance(r, tuple) else r for r in node.rows].index(col)


# edges: (src, src_anchor, dst, dst_anchor, src_marker, dst_marker, label, label_pos)
# markers: "one" (exactly one), "zero_one", "many" (one-or-many side drawn as crow's foot), "zero_many"
def build_edges(kind, N):
    E = []
    if kind == "physical":
        e, a = N["employee"], N["job_assignment"]
        E += [(N["location"].right(0), N["employee"].left(5), "one", "many", "", "h"),
              (N["education_level"].left(0), N["employee"].right(6), "one", "many", "", "h"),
              (N["job"].right(0), a.left(2), "one", "many", "", "h"),
              (N["department"].left(0), a.right(3), "one", "many", "", "h"),
              (e.bottom(110), a.top(110), "one", "many", "employee_id", "v"),
              (e.bottom(275), a.top(275), "zero_one", "many", "manager_id (manager)", "v"),
              (a.bottom(110), N["employee_salary"].top(110), "one", "one", "assignment_id (1:1)", "v")]
    else:
        lab = kind == "logical" or True
        e, a = N["Employee"], N["Job Assignment"]
        E += [(N["Location"].right(), e.left(), None, None, "hosts", "h"),
              (N["Education Level"].left(), e.right(), None, None, "level of", "h"),
              (N["Job"].right(), a.left(), None, None, "filled by", "h"),
              (N["Department"].left(), a.right(), None, None, "contains", "h"),
              (e.bottom(110), a.top(110), None, None, "has jobs over time", "v"),
              (e.bottom(275), a.top(275), None, None, "manages", "v"),
              (a.bottom(110), N["Salary (Restricted)"].top(110), None, None, "is paid", "v")]
    return E


# ------------------------------------------------------------------ PNG drawing
def draw_marker(d, p, direction, kind, scale=1.0):
    """p: point on the entity edge; direction: unit vector pointing away from the entity along the line."""
    x, y = p; dx, dy = direction; px, py = -dy, dx   # perpendicular
    k = S * scale
    def pt(a, b): return (x + (dx * a + px * b) * k, y + (dy * a + py * b) * k)
    w = int(2.4 * S)
    if kind in ("many", "zero_many"):
        for off in (-11, 0, 11):
            d.line([pt(24, 0), pt(0, off)], fill=LINE, width=w)
        if kind == "many": d.line([pt(30, -11), pt(30, 11)], fill=LINE, width=w)
        else:
            d.ellipse([pt(37, -7)[0], pt(37, -7)[1], pt(37, 7)[0], pt(37, 7)[1]], fill="white", outline=LINE, width=w)
            cx, cy = pt(37, 0); r = 7 * k
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill="white", outline=LINE, width=w)
    elif kind == "one":
        d.line([pt(14, -11), pt(14, 11)], fill=LINE, width=w); d.line([pt(24, -11), pt(24, 11)], fill=LINE, width=w)
    elif kind == "zero_one":
        d.line([pt(14, -11), pt(14, 11)], fill=LINE, width=w)
        cx, cy = pt(27, 0); r = 7 * k
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill="white", outline=LINE, width=w)


def unit(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]; n = (dx * dx + dy * dy) ** .5 or 1
    return dx / n, dy / n


def route(p, q, orient):
    if orient == "h":
        mx = (p[0] + q[0]) / 2
        return [p, (mx, p[1]), (mx, q[1]), q] if abs(p[1] - q[1]) > 1 else [p, q]
    my = (p[1] + q[1]) / 2
    return [p, (p[0], my), (q[0], my), q] if abs(p[0] - q[0]) > 1 else [p, q]


def render(kind, N, E, title, subtitle, W, H, outfile):
    im = Image.new("RGB", (W * S, H * S), "white"); d = ImageDraw.Draw(im)
    d.text((30 * S, 22 * S), title, font=font(FB, 30), fill=INK)
    d.text((30 * S, 64 * S), subtitle, font=font(FI, 19), fill=(90, 94, 104))
    # edges first
    for (p, q, m1, m2, label, orient) in E:
        pts = route(p, q, orient)
        d.line([(x * S, y * S) for x, y in pts], fill=LINE, width=int(2.4 * S), joint="curve")
        if m1:
            draw_marker(d, (p[0] * S, p[1] * S), unit(pts[0], pts[1]), m1)
            draw_marker(d, (q[0] * S, q[1] * S), unit(pts[-1], pts[-2]), m2)
        # label
        f = font(FI if kind != "physical" else FR, 16)
        if orient == "h":
            mx = pts[1][0] if len(pts) > 2 else (p[0] + q[0]) / 2
            lw = d.textlength(label, font=f) / S
            ty = (pts[1][1] if len(pts) > 2 else p[1]) - 24
            d.text(((mx - lw / 2) * S, ty * S), label, font=f, fill=(70, 74, 90))
        else:
            my = pts[1][1] if len(pts) > 2 else (p[1] + q[1]) / 2
            d.text(((pts[0][0] + 10) * S, (my - 8) * S), label, font=f, fill=(70, 74, 90))
    # nodes
    for n in N.values():
        x, y, w, h = n.x * S, n.y * S, n.w * S, n.h * S
        head = RED if n.restricted else BLUE
        if n.kind == "conceptual":
            d.rounded_rectangle([x, y, x + w, y + h], radius=14 * S, fill=head, outline=LINE, width=3 * S)
            f = font(FB, 24); t = n.name; tw = d.textlength(t, font=f)
            d.text((x + (w - tw) / 2, y + h / 2 - 15 * S), t, font=f, fill=INK)
            if n.restricted:
                f2 = font(FI, 15); t2 = "restricted: table-level security"
                d.text((x + (w - d.textlength(t2, font=f2)) / 2, y + h - 26 * S), t2, font=f2, fill=(150, 40, 30))
            continue
        d.rectangle([x, y, x + w, y + h], fill="white", outline=LINE, width=3 * S)
        d.rectangle([x, y, x + w, y + n.hh * S], fill=head, outline=LINE, width=3 * S)
        f = font(FB, 22); d.text((x + 14 * S, y + 10 * S), n.name + ("  (restricted)" if n.restricted and n.kind == "physical" else ""), font=f, fill=INK)
        for i, r in enumerate(n.rows):
            ry = y + (n.hh + i * n.rh) * S
            if i % 2: d.rectangle([x + 2 * S, ry, x + w - 2 * S, ry + n.rh * S], fill=GREY)
            if n.kind == "physical":
                col, typ, key = r
                txt = col + (" (PK)" if key == "PK" else " (FK)" if key == "FK" else "")
                d.text((x + 14 * S, ry + 7 * S), txt, font=font(FB if key == "PK" else FR, 19), fill=INK)
                d.line([(x + 262 * S, ry), (x + 262 * S, ry + n.rh * S)], fill=(190, 194, 204), width=S)
                d.text((x + 274 * S, ry + 7 * S), typ, font=font(FI, 18), fill=(70, 74, 90))
            else:
                d.text((x + 14 * S, ry + 7 * S), r, font=font(FB if "(PK)" in r else FR, 19), fill=INK)
    return im, d


def legend(im, d, x, y):
    f = font(FR, 17)
    d.text((x * S, y * S), "Legend", font=font(FB, 18), fill=INK)
    items = [("one", "exactly one"), ("zero_one", "zero or one"), ("many", "one or many")]
    for i, (k, t) in enumerate(items):
        yy = y + 36 + i * 34
        d.line([((x + 10) * S, yy * S), ((x + 110) * S, yy * S)], fill=LINE, width=int(2.4 * S))
        draw_marker(d, ((x + 110) * S, yy * S), (-1, 0), k)
        d.text(((x + 128) * S, (yy - 11) * S), t, font=f, fill=INK)
    d.text((x * S, (y + 140) * S), "PK = primary key (bold)   FK = foreign key", font=font(FR, 16), fill=INK)


# ------------------------------------------------------------------ draw.io export
def drawio(kind, N, E, outfile):
    cells = ['<mxCell id="0"/>', '<mxCell id="1" parent="0"/>']
    ids = {}
    for i, n in enumerate(N.values()):
        nid = "t%d" % (i + 2); ids[n.name] = nid
        fill = "#fad6d2" if n.restricted else "#c8d6ec"
        if n.kind == "conceptual":
            cells.append(f'<mxCell id="{nid}" value="{escape(n.name)}" style="rounded=1;whiteSpace=wrap;html=1;fillColor={fill};strokeColor=#3c404c;fontStyle=1;fontSize=16;" vertex="1" parent="1"><mxGeometry x="{n.x}" y="{n.y}" width="{n.w}" height="{n.h}" as="geometry"/></mxCell>')
            continue
        cells.append(f'<mxCell id="{nid}" value="{escape(n.name)}" style="swimlane;fontStyle=1;childLayout=stackLayout;horizontal=1;startSize={n.hh};horizontalStack=0;resizeParent=1;resizeParentMax=0;resizeLast=0;collapsible=0;marginBottom=0;fillColor={fill};strokeColor=#3c404c;fontSize=14;" vertex="1" parent="1"><mxGeometry x="{n.x}" y="{n.y}" width="{n.w}" height="{n.h}" as="geometry"/></mxCell>')
        for j, r in enumerate(n.rows):
            if kind == "physical":
                col, typ, key = r
                txt = escape((f"<b>{col} (PK)</b>" if key == "PK" else f"{col} (FK)" if key == "FK" else col) + f"  &nbsp;&nbsp;<i>{typ}</i>")
            else:
                txt = escape(f"<b>{r}</b>" if "(PK)" in r else r)
            cells.append(f'<mxCell id="{nid}_r{j}" value="{txt}" style="text;strokeColor=none;fillColor={"#ecedf2" if j % 2 else "#ffffff"};align=left;verticalAlign=middle;spacingLeft=8;html=1;fontSize=13;" vertex="1" parent="{nid}"><mxGeometry y="{n.hh + j * n.rh}" width="{n.w}" height="{n.rh}" as="geometry"/></mxCell>')
    arrow = {"one": "ERmandOne", "zero_one": "ERzeroToOne", "many": "ERmany", None: "none"}
    names = list(N.keys())
    for k, (p, q, m1, m2, label, orient) in enumerate(E):
        def owner(pt):
            for n in N.values():
                if n.x - 1 <= pt[0] <= n.x + n.w + 1 and n.y - 1 <= pt[1] <= n.y + n.h + 1: return ids[n.name]
        s, t = owner(p), owner(q)
        cells.append(f'<mxCell id="e{k}" value="{escape(label)}" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow={arrow[m2]};startArrow={arrow[m1]};endSize=12;startSize=12;strokeColor=#3c404c;fontSize=11;" edge="1" parent="1" source="{s}" target="{t}"><mxGeometry relative="1" as="geometry"/></mxCell>')
    xml = '<mxfile host="app.diagrams.net"><diagram name="%s" id="erd"><mxGraphModel dx="1400" dy="1000" grid="1" gridSize="10" page="1" pageScale="1" pageWidth="1400" pageHeight="1200"><root>%s</root></mxGraphModel></diagram></mxfile>' % (kind, "".join(cells))
    open(outfile, "w").write(xml)


for kind, title, sub, H in [
    ("conceptual", "Tech ABC Corp HR Database - Conceptual ERD", "Main business objects and how they relate (no attributes, no cardinality notation at this level)", 1130),
    ("logical", "Tech ABC Corp HR Database - Logical ERD (3NF)", "Plain-English entities and attributes; salary separated into its own restricted entity", 1150),
    ("physical", "Tech ABC Corp HR Database - Physical ERD (PostgreSQL)", "Matches schema.sql exactly: data types, PK (bold), FK, crow's foot cardinality", 1150)]:
    N = build_nodes(kind); E = build_edges(kind, N)
    im, d = render(kind, N, E, title, sub, 1590, H, None)
    if kind == "physical": legend(im, d, 30, 960)
    im = im.resize((1590, H), Image.LANCZOS) if False else im
    im.save(os.path.join(OUT, f"{kind}_erd.png"), dpi=(200, 200))
    drawio(kind, N, E, os.path.join(OUT, f"{kind}_erd.drawio"))
print("ERDs written to", OUT)
