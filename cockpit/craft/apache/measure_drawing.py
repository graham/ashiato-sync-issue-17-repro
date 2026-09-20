"""Re-derive the AH-64 Apache's scale and cross-checks from the Army three-view ALONE, and audit the hand picks.

    python cockpit/craft/apache/measure_drawing.py [path/to/ah64_3view.png]

The drawing is [ARMY]: "McDonnell Douglas AH-64 Apache 3-view line drawing.png", Wikimedia Commons, public domain (a US
Army work), 574 x 385 px. Default path: ~/godotgames-drafts/2026-09-18/cockpit-apache/research/ah64_3view.png.

WHAT IT DOES, with no number typed out of sources.md or the airframe's doc block:
  1. finds the front view's rotor tips (the longest dark row there) -> THE SCALE, against [W]'s 14.63 m;
  2. finds the plan view's four blade tips and measures both diagonals -> the plan's own scale, for comparison;
  3. measures, at that one scale, the side view's fuselage (nose to stabilator), the length with rotors, the front
     view's top over its wheels, the plan's wing span -- and prints each against its published figure;
  4. reads the airframe's RINGS table out of apache_airframe.gd and checks every roof, sill-free outline pick (roof and
     belly) lies within 2 px (0.11 m) of a dark pixel in its column of the side view. A pick in open paper is a typo.
Prints PASS/FAIL per item and exits non-zero on any FAIL.
"""
import os
import re
import sys

import numpy as np
from PIL import Image

ROTOR = 14.63        # [W]
FUSELAGE = 15.06     # [W] 49 ft 5 in
LENGTH = 17.73       # [W], [FAS]
HEIGHT_A = 4.64      # [FAS] AH-64A
SPAN = 5.227         # [FAS]

here = os.path.dirname(os.path.abspath(__file__))
path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.expanduser("~"), "godotgames-drafts", "2026-09-18", "cockpit-apache", "research", "ah64_3view.png")
dark = np.array(Image.open(path).convert("L")) < 128
failures = []


def check(label, ok, detail):
    print("%s %s (%s)" % ("PASS" if ok else "FAIL", label, detail))
    if not ok:
        failures.append(label)


def box(x0, y0, x1, y1):
    ys, xs = np.nonzero(dark[y0:y1, x0:x1])
    return xs.min() + x0, ys.min() + y0, xs.max() + x0, ys.max() + y0


# 1. THE FRONT VIEW'S ROTOR: the blade line is drawn a hair off level and crosses two pixel rows, so its tips are the
# extremes over every row of the view's upper part that carries a long dark run (more than 100 px).
long_rows = []
for y in range(60, 110):
    xs = np.nonzero(dark[y, 270:574])[0]
    if len(xs) > 100:
        long_rows.append((y, xs.min() + 270, xs.max() + 270))
best = (tuple(r[0] for r in long_rows), min(r[1] for r in long_rows), max(r[2] for r in long_rows))
drawn_rotor = best[2] - best[1] + 1
unit = ROTOR / drawn_rotor
print("front view rotor: rows %s, x %d..%d = %d px -> %.5f m a pixel" % (best[0], best[1], best[2], drawn_rotor, unit))

# 2. THE PLAN VIEW'S BLADE TIPS: the dark pixel furthest into each corner of the plan view's box.
x0, y0, x1, y1 = 30, 55, 250, 275
sub = np.argwhere(dark[y0:y1, x0:x1])
pts = [(int(x) + x0, int(y) + y0) for y, x in sub]
tl = min(pts, key=lambda p: p[0] + p[1])
br = max(pts, key=lambda p: p[0] + p[1])
tr = max(pts, key=lambda p: p[0] - p[1])
bl = min(pts, key=lambda p: p[0] - p[1])
d1 = np.hypot(br[0] - tl[0], br[1] - tl[1])
d2 = np.hypot(tr[0] - bl[0], tr[1] - bl[1])
plan = (d1 + d2) / 2.0
print("plan view blade tips %s %s %s %s: diagonals %.1f and %.1f px" % (tl, br, tr, bl, d1, d2))
check("the plan view agrees with the front view's scale within 2 per cent", abs(plan / drawn_rotor - 1.0) < 0.02,
      "plan %.1f px against the front's %d (%+.1f %%)" % (plan, drawn_rotor, (plan / drawn_rotor - 1.0) * 100.0))

# 3. AT THAT ONE SCALE: the side view's body, the length with rotors, the front view's height, the plan's span.
sx0, sy0, sx1, sy1 = box(240, 195, 574, 315)
nose = min(x for x in range(240, 320) if dark[268:292, x].any())
# The stabilator's trailing edge: the last dark column in its rows.
tail = max(x for x in range(500, 574) if dark[260:268, x].any())
fuselage = (tail - nose + 1) * unit
# THREE PER CENT, AND WHY: [W]'s "fuselage length" gives no datum -- nose to what? -- and the drawing's body, TADS to the
# stabilator's trailing edge, comes out 2.5 per cent short of it at the rotor's scale, while the length with rotors,
# which has an unambiguous datum, agrees to 0.05 per cent. That is written in sources.md as a disagreement, not tuned away.
check("the side view's body is the published fuselage within 3 per cent", abs(fuselage / FUSELAGE - 1.0) < 0.03,
      "x %d..%d = %.3f m against %.2f" % (nose, tail, fuselage, FUSELAGE))
length = (sx1 - sx0 + 1) * unit
check("the side view with its rotor is the published length within 2 per cent", abs(length / LENGTH - 1.0) < 0.02,
      "x %d..%d = %.3f m against %.2f" % (sx0, sx1, length, LENGTH))
fx0, fy0, fx1, fy1 = box(270, 60, 574, 175)
height = (fy1 - fy0 + 1) * unit
check("the front view's top over its wheels is FAS's AH-64A height within 2 per cent", abs(height / HEIGHT_A - 1.0) < 0.02,
      "y %d..%d = %.3f m against %.2f" % (fy0, fy1, height, HEIGHT_A))
row = 168
xs = np.nonzero(dark[row, 0:260])[0]
span = (xs.max() - xs.min() + 1) * unit
check("the plan view's stub wings are within 4 per cent of FAS's span (the drawn tips are rounded)",
      abs(span / SPAN - 1.0) < 0.04, "row %d x %d..%d = %.3f m against %.3f" % (row, xs.min(), xs.max(), span, SPAN))

# 4. THE AIRFRAME'S PICKS, read out of its own table and held to the drawing.
source = open(os.path.join(here, "..", "..", "objects", "vehicles", "apache_airframe.gd"), encoding="utf8").read()
table = source[source.index("const RINGS: Array = ["):]
table = table[:table.index("\n]")]
rows = [[float(v) for v in r.split(",")] for r in re.findall(r"\[([0-9.,\s]+)\]", table)]
off_line = []
for r in rows:
    x = int(round(r[0]))
    for name, y, raised in (("roof", r[1], x in (311, 316, 320, 330)), ("belly", r[5], False)):
        if raised:
            continue  # the gunner's raised roof: deliberately NOT the drawing's line (see the airframe's doc block)
        column = np.nonzero(dark[195:315, x])[0] + 195
        nearest = min(abs(column - y)) if len(column) else 99
        if nearest > 2.0:
            off_line.append("x %d %s %.1f is %.1f px from any line (2 px, 0.11 m, is a pick's resolution)" % (x, name, y, nearest))
check("every roof and belly pick in RINGS lies on a drawn line", not off_line,
      "%d rows; %s" % (len(rows), "; ".join(off_line) if off_line else "all within 2 px, 0.11 m"))

print("RESULT=%s" % ("PASS" if not failures else "FAIL " + ", ".join(failures)))
sys.exit(1 if failures else 0)
