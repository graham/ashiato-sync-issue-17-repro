"""Re-derives every MEASURED figure in `sources.md` and `FalconAirframe` from the two F-16 three-views, reading
nothing out of the write-up.

    python cockpit/craft/falcon/measure_threeview.py <folder holding the two SVGs>

The folder defaults to ~/godotgames-drafts/2026-09-17/cockpit-falcon/research/. The drawings are not in the repo:
they are study material, and `sources.md` names their Commons pages.

BOTH DRAWINGS ARE VECTOR FILES, so this measures their own coordinates: no pixels, no rasterising, no page rotation.
[CEL] is drawn in millimetres at 1:100, so one document unit is 0.1 m and the span check below is the only scale
there is. [USAF] is in unscaled points and is used for one thing only: showing that it is not isotropic.

A WING OR TAIL EDGE IS FITTED OVER EVERY ROW AND THE RESIDUAL PRINTED, never through two ends (`modelling_here.md`
section 3, which cost `lane/prowler` its best finding of a morning).
"""
import math
import os
import sys

import svg_lines

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-17/cockpit-falcon/research")
USAF = os.path.join(FOLDER, "usaf_f16_3view.svg")
CEL = os.path.join(FOLDER, "cel_f16a_block15_3view.svg")


def dense(line, step=0.05):
    out = []
    pts = line["points"]
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(a[0] - b[0], a[1] - b[1]) / step))
        out += [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(n)]
    return out + [pts[-1]]


def extent(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return min(xs), max(xs), min(ys), max(ys)


def fit(rows):
    """Least squares x = a + b h over (h, x) rows, and the rms residual."""
    n = len(rows)
    mh = sum(r[0] for r in rows) / n
    mx = sum(r[1] for r in rows) / n
    b = sum((r[0] - mh) * (r[1] - mx) for r in rows) / sum((r[0] - mh) ** 2 for r in rows)
    a = mx - b * mh
    rms = math.sqrt(sum((a + b * r[0] - r[1]) ** 2 for r in rows) / n)
    return a, b, rms


def usaf():
    """The USAF clip-art three-view: split into its three views by position, and compare the views' own axes."""
    views = {"plan": [], "side": [], "front": []}
    for line in svg_lines.read(USAF):
        x0, x1, y0, y1 = extent(line["points"])
        if y1 < 346 and x0 > 280:
            views["front"] += line["points"]
        elif x1 <= 397 and y0 >= 275 and y1 <= 504:
            views["plan"] += line["points"]
        else:
            views["side"] += line["points"]
    p = extent(views["plan"])
    s = extent(views["side"])
    f = extent(views["front"])
    length = p[1] - p[0]
    span = p[3] - p[2]
    print("[USAF] plan: length %.2f, span %.2f, length/span %.3f" % (length, span, length / span))
    print("[USAF] side: length %.2f (plan and side agree to %.2f%%)" % (s[1] - s[0], 100 * abs(s[1] - s[0] - length) / length))
    print("[USAF] front: span %.2f (front and plan disagree by %.2f%%)" % (f[1] - f[0], 100 * (f[1] - f[0] - span) / span))


def cel():
    side, plan, front = [], [], []
    wheels = []
    for line in svg_lines.read(CEL):
        x0, x1, y0, y1 = extent(line["points"])
        if y1 < 62 and x1 < 200:
            # The two tyres are the only closed near-circles below the fuselage in the side view.
            if y0 > 52 and abs((x1 - x0) - (y1 - y0)) < 0.2:
                wheels.append(((x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0)))
                continue
            side += dense(line)
        elif x0 > 160 and y0 > 60:
            front += dense(line)
        elif y0 > 60:
            plan += dense(line)
    p = extent(plan)
    s = extent(side)
    f = extent(front)
    centre = (p[2] + p[3]) / 2
    print()
    print("[CEL] units are millimetres at 1:100, so 1 unit = 0.1 m")
    print("[CEL] plan: pitot tip x %.2f, nozzle x %.2f, length %.2f; span %.2f; centreline y %.3f"
          % (p[0], p[1], p[1] - p[0], p[3] - p[2], centre))
    print("[CEL] front: span %.2f (front and plan disagree by %.2f%%)" % (f[3] - f[2], 100 * (f[3] - f[2] - (p[3] - p[2])) / (p[3] - p[2])))
    print("[CEL] side: x %.2f..%.2f, fin top y %.2f" % (s[0], s[1], s[2]))
    for w in sorted(wheels):
        print("[CEL] side tyre: centre x %.2f y %.2f, diameter %.2f, bottom y %.2f" % (w[0], w[1], w[2], w[1] + w[2] / 2))
    # THE FRONT VIEW'S TYRES are three stroked rects left of the front view (the view is turned a quarter, ground to -x).
    bars = []
    for line in svg_lines.read(CEL):
        x0, x1, y0, y1 = extent(line["points"])
        if x0 > 160 and x1 < 176 and y0 > 60:
            bars.append(((y0 + y1) / 2, y1 - y0, x0, x1))
    bars.sort()
    for b in bars:
        print("[CEL] front tyre: middle y %.3f, %.2f wide, ground x %.2f, top x %.2f" % b)
    if len(bars) == 3:
        print("[CEL] front: main track %.2f mm; nose tyre %.2f mm off the front view's span centre"
              % (bars[2][0] - bars[0][0], bars[1][0] - (f[2] + f[3]) / 2))

    def row(points, h, lo, hi):
        both = []
        for sign in (-1, 1):
            xs = [q[0] for q in points if abs((q[1] - centre) * sign - h) < 0.05 and lo < q[0] < hi]
            both.append((min(xs), max(xs)) if xs else None)
        return both

    # THE WING. Rows every half millimetre outboard of the LERX's end and inboard of the launcher rail.
    le, te, asym = [], [], 0.0
    h = 15.0
    while h <= 48.0:
        a, b = row(plan, h, 75, 126)
        le.append((h, (a[0] + b[0]) / 2))
        te.append((h, (a[1] + b[1]) / 2))
        asym = max(asym, abs(a[0] - b[0]), abs(a[1] - b[1]))
        h += 0.5
    a, b, r = fit(le)
    ta, tb, tr = fit(te)
    print("[CEL] wing LE: x = %.3f + %.4f h, rms %.3f over %d rows -> sweep %.2f deg" % (a, b, r, len(le), math.degrees(math.atan(b))))
    print("[CEL] wing TE: x = %.3f + %.4f h, rms %.3f -> sweep %.2f deg; port/starboard differ by at most %.3f"
          % (ta, tb, tr, math.degrees(math.atan(tb)), asym))
    # The rows where the plan outline leaves the LERX for the wing, and where the rail begins.
    # THE TAILPLANE, outboard of the aft fuselage's side.
    le, te = [], []
    h = 11.5
    while h <= 26.0:
        x = row(plan, h, 128, 162)
        le.append((h, (x[0][0] + x[1][0]) / 2))
        te.append((h, (x[0][1] + x[1][1]) / 2))
        h += 0.5
    a, b, r = fit(le)
    ta, tb, tr = fit(te)
    print("[CEL] tail LE: x = %.3f + %.4f h, rms %.3f -> sweep %.2f deg" % (a, b, r, math.degrees(math.atan(b))))
    print("[CEL] tail TE: x = %.3f + %.4f h, rms %.3f" % (ta, tb, tr))

    # THE PLAN OUTLINE AND THE SIDE SILHOUETTE, station by station.
    print("[CEL]   x     plan half-width   side top  side bottom")
    for x10 in range(90, 1601, 25):
        x = x10 / 10
        t = [abs(q[1] - centre) for q in plan if abs(q[0] - x) < 0.06]
        sv = [q[1] for q in side if abs(q[0] - x) < 0.06]
        print("[CEL] %6.1f   %6.2f           %6.2f    %6.2f" % (x, max(t) if t else -1, min(sv) if sv else -1, max(sv) if sv else -1))


if __name__ == "__main__":
    usaf()
    cel()
