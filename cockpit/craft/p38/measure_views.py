"""Re-derives every MEASURED figure in `sources.md` and `P38Airframe` from the P-38L three-view alone, reading nothing out
of the write-up.

    python cockpit/craft/p38/measure_views.py [folder holding p38l_an01-75ff-2.png]

The folder defaults to ~/Desktop/godotgames-drafts/2026-09-19/cockpit-warbirds/research/. The drawing is the USAAF's own,
from AN 01-75FF-2 p.2: "Lockheed P-38L Lightning 3-view line drawing.png" on Wikimedia Commons, {{PD-USGov-Military}},
1929 x 2362 px, with a great many printed dimensions (inches unless marked). Study material, not in the repo.

THE SHEET'S VIEWS: the side along the top (nose to the LEFT, the port side), the plan in the middle (nose DOWN, so
starboard on the LEFT), the front at the bottom (starboard on the viewer's left). There is no dimension-free copy, so each
view is FENCED by a hull drawn by hand a few pixels outside the aeroplane (`tools/three_view.py`), and the dimension
lines still inside a fence are taken out between their ends, before the fill.

THE SIDE VIEW OVERLAPS THE GONDOLA AND THE NEAR BOOM, so their separate heights are read from the FRONT view's sections
and the printed figures, and the side silhouette is used whole: for the length, the fin and the overlay.

STATIONS ARE METRES AFT OF THE GONDOLA'S NOSE; HEIGHTS ARE METRES OVER THE FUSELAGE REFERENCE LINE (the thrust line is
printed 5.078 in under it); OUT is metres to starboard. Each view is scaled by its own printed dimension and checked on
others (`learnings/2026-09-19-liners.md`).
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import three_view as tv  # noqa: E402

FOLDER = os.path.expanduser("~/Desktop/godotgames-drafts/2026-09-19/cockpit-warbirds/research")
SHEET = "p38l_an01-75ff-2.png"
INCH = 0.0254
LENGTH_M = (37 * 12 + 9 + 15.0 / 16.0) * INCH   # 11.530: printed over the side view
SPAN_M = 52 * 12 * INCH                         # 15.850: printed over the front view
HALF_SPAN_M = 26 * 12 * INCH                    # 7.925: printed over the front view
BOOM_OUT_M = 96 * INCH                          # 2.438: printed under the plan, the booms' centrelines
TRACK_M = 198 * INCH                            # 5.029: printed under the front view
TAILPLANE_M = 261 * INCH                        # 6.629: printed over the plan
PROP_M = (11 * 12 + 6) * INCH                   # 3.505: printed under the plan
ROOT_CHORD_M = 117 * INCH                       # 2.972: printed on the plan
NOSE_TO_ROOT_LE_M = 119.05 * INCH               # 3.024: printed over the side view
NOSE_TO_PROP_M = 61.875 * INCH                  # 1.572: printed over the side view
HEIGHT_M = (9 * 12 + 10 + 3.0 / 8.0) * INCH     # 3.007: printed on the side, the fin's top over the static ground
GROUND_ANGLE_DEG = 5.0 + 33.0 / 60.0 + 46.0 / 3600.0   # printed: the static ground against the reference line
WHEELBASE_M = 120.831 * INCH                    # 3.069: printed under the side view, nose strut to main strut

# THE VIEWS as (row0, row1, col0, col1) boxes, a seed (row, col) in each, and a FENCE (col, row) off gridded crops.
PLAN_BOX = (660, 1800, 180, 1740)
PLAN_SEED = (1350, 960)
PLAN_FENCE = [(600, 695), (1275, 695), (1275, 865), (1195, 865), (1200, 1000), (1265, 1060), (1272, 1215), (1500, 1268),
              (1650, 1313), (1707, 1355), (1714, 1396), (1692, 1426), (1450, 1442), (1268, 1456), (1258, 1470),
              (1250, 1640), (1205, 1678), (1170, 1678), (1135, 1640), (1128, 1472), (1045, 1472), (1045, 1600),
              (1012, 1733), (977, 1765), (943, 1765), (908, 1733), (878, 1600), (878, 1472), (792, 1472), (788, 1640),
              (727, 1678), (697, 1678), (660, 1640), (652, 1460), (450, 1442), (210, 1428), (192, 1392), (203, 1350),
              (250, 1310), (400, 1268), (638, 1215), (640, 1060), (700, 1000), (706, 865), (600, 865)]
PLAN_HOLES = [(900, 950), (880, 850), (880, 1050), (1180, 1100)]   # the white the booms, tailplane and wing close round
SIDE_BOX = (100, 560, 280, 1440)
SIDE_SEED = (300, 600)
SIDE_FENCE = [(300, 300), (330, 262), (420, 262), (560, 240), (620, 205), (680, 205), (760, 235), (1000, 245), (1270, 245),
              (1305, 128), (1345, 122), (1397, 148), (1407, 250), (1402, 300), (1352, 342), (1280, 342), (1200, 302),
              (1000, 332), (870, 362), (790, 385), (600, 420), (480, 415), (400, 410), (330, 372), (300, 340)]
FRONT_BOX = (1880, 2320, 190, 1740)
FRONT_SEED = (2080, 965)
FRONT_FENCE = [(220, 2010), (700, 2028), (700, 1950), (720, 1903), (750, 1903), (760, 1975), (800, 2028), (900, 2028),
               (930, 1983), (1000, 1983), (1030, 2028), (1150, 2028), (1165, 1975), (1180, 1903), (1210, 1903),
               (1225, 1975), (1240, 2028), (1710, 2003), (1714, 2032), (1250, 2082), (1248, 2150), (1175, 2162),
               (1160, 2082), (1040, 2082), (1032, 2168), (918, 2168), (905, 2082), (792, 2082), (787, 2152),
               (708, 2162), (690, 2082), (215, 2037)]


def load():
    grey = np.asarray(Image.open(os.path.join(FOLDER, SHEET)).convert("L")).astype(int)
    return grey < 128


# THE SHEET IS TURNED, and each view is read square, each by its own evidence:
# - the PLAN by its wing: turned -0.92 deg, its two halves' edges agree to 1 to 3 cm (unturned, 12 px apart at the tips);
#   the booms' own lean, 0.85 and 1.00 deg over 65 rows, says the same;
# - the FRONT is square as scanned: its two spinners' circles are level to 0.2 px over 452, and its outer panels rise
#   4.76 and 5.00 deg (turned by its fins' 0.8 deg lean, 5.53 and 4.21 -- the fins are drawn leaning);
# - the SIDE by two printed figures: turned -0.85 deg, the boom's top under the tailplane stands 0.41 to 0.42 m over the
#   reference line (the tailplane printed 21.099 in over the thrust line, 0.407) and the fin 3.006 m over the static
#   ground through the drawn tyres (printed 9 ft 10-3/8 in, 3.007). Its dash-dot reference and thrust lines themselves lean only 0.44 deg (a common
#   slope through 19 dashes, rms 0.4 px, 12.1 px apart for the printed 5.078 in); read square by THEM, the tail stands
#   6 cm higher than both printed figures, so the lines were drawn 0.4 deg off the aeroplane (NOTE 2 turns the
#   empennage 1 deg 15 min on purpose, and the draughtsman may have laid the lines by it). `measure()` prints both.
PLAN_TURN = -0.92
FRONT_TURN = 0.0
SIDE_TURN = -0.85


def views(close=2):
    ink = load()
    plan, _ = tv.solid(ink, PLAN_BOX, PLAN_SEED, close, PLAN_FENCE, PLAN_HOLES)
    side, _ = tv.solid(ink, SIDE_BOX, SIDE_SEED, close, SIDE_FENCE)
    front, front_all = tv.solid(ink, FRONT_BOX, FRONT_SEED, close, FRONT_FENCE)
    plan = tv.turned(opened(plan), PLAN_TURN)
    side = tv.turned(opened(side), SIDE_TURN)
    front = tv.turned(opened(front), FRONT_TURN)
    return ink, plan, side, front, front_all


def opened(mask):
    return tv.grow(tv.shrink(mask, 3), 3)


def edges_at(mask, box, index, axis):
    """The runs of `mask` along one sheet row (axis 0) or column (axis 1), in sheet pixels."""
    if axis == 0:
        line = mask[index - box[0], :]
        return [(a0 + box[2], b0 + box[2]) for a0, b0 in tv.runs(np.nonzero(line)[0])]
    line = mask[:, index - box[2]]
    return [(a0 + box[0], b0 + box[0]) for a0, b0 in tv.runs(np.nonzero(line)[0])]


def turned_sheet(ink, box, degrees):
    """The whole sheet with one view's box turned square, so a circle or a line found in it is in the view's own frame."""
    out = ink.copy()
    r0, r1, c0, c1 = box
    out[r0:r1, c0:c1] = tv.turned(ink[r0:r1, c0:c1], degrees)
    return out


def reference_lines(ink):
    """The side's dash-dot reference line (columns 330-600) and thrust line (760-1440) as drawn, fitted with one slope:
    (degrees, dashes, rms px, the lines' separation in px)."""
    pts = []
    for lo, hi, rows, k in ((330, 600, range(300, 312), 0), (760, 1440, range(308, 320), 1)):
        for a in range(lo, hi, 40):
            c = {r: int(ink[r, a:a + 40].sum()) for r in rows}
            best = max(c.values())
            if best >= 30:
                pts.append((a + 20, np.mean([r for r, n in c.items() if n >= best - 3]), k))
    p = np.array(pts)
    a_matrix = np.c_[p[:, 0], p[:, 2] == 0, p[:, 2] == 1]
    c, *_ = np.linalg.lstsq(a_matrix, p[:, 1], rcond=None)
    r = p[:, 1] - a_matrix @ c
    return float(np.degrees(np.arctan(c[0]))), len(p), float(np.sqrt((r ** 2).mean())), float(c[2] - c[1])


def inkiest(sheet, rows, c0, c1):
    """The middle of the rows holding the most ink between columns c0 and c1 (within 2 px of the most)."""
    counts = {r: int(sheet[r, c0:c1].sum()) for r in rows}
    top = max(counts.values())
    return float(np.mean([r for r, n in counts.items() if n >= top - 2]))


def measure(say=print):
    """Every figure, printed through `say`, and the working kept for `overlay_views.py`."""
    ink, plan, side, front, front_all = views()

    # ---- THE PLAN (nose DOWN, starboard LEFT): scaled by the printed span, checked on the tailplane and the booms ----
    ys, xs = np.nonzero(plan)
    ys = ys + PLAN_BOX[0]
    xs = xs + PLAN_BOX[2]
    nose_row = int(ys.max())
    span_px = int(xs.max() - xs.min() + 1)
    sp = span_px / SPAN_M
    cx = (xs.max() + xs.min()) / 2.0
    st = lambda row: (nose_row - row) / sp
    out = lambda col: (cx - col) / sp      # starboard on the LEFT is positive
    say("PLAN: span %d px for the printed 52 ft, %.2f px a metre; the middle column %.1f; the gondola's nose row %d"
        % (span_px, sp, cx, nose_row))
    tail_rows = [int(round(nose_row - s * sp)) for s in np.arange(9.8, 10.7, 0.1)]
    tail_px = max(max(b0 for a0, b0 in edges_at(plan, PLAN_BOX, r, 0)) - min(a0 for a0, b0 in edges_at(plan, PLAN_BOX, r, 0))
                  + 1 for r in tail_rows if edges_at(plan, PLAN_BOX, r, 0))
    say("  the tailplane %d px = %.3f m against the printed 261 in, %.3f (%+.1f%%)"
        % (tail_px, tail_px / sp, TAILPLANE_M, 100.0 * (tail_px / sp / TAILPLANE_M - 1.0)))
    booms = []
    for s in np.arange(7.75, 9.5, 0.25):
        rr = [r for r in edges_at(plan, PLAN_BOX, int(round(nose_row - s * sp)), 0) if abs(out((r[0] + r[1]) / 2.0)) > 1.5]
        if len(rr) == 2:
            booms.append((out((rr[0][0] + rr[0][1]) / 2.0), out((rr[1][0] + rr[1][1]) / 2.0)))
    b = np.mean(booms, axis=0)
    say("  the booms' middles %+.3f and %+.3f: %.3f m apart against the printed 2 x 96 in, %.3f (%+.1f%%), %d rows"
        % (b[0], b[1], b[0] - b[1], 2 * BOOM_OUT_M, 100.0 * ((b[0] - b[1]) / (2 * BOOM_OUT_M) - 1.0), len(booms)))

    def widest(col, lo, hi):
        rr = [r for r in edges_at(plan, PLAN_BOX, col, 1) if lo < st((r[0] + r[1]) / 2.0) < hi]
        return max(rr, key=lambda q: q[1] - q[0]) if rr else None

    say(chr(10) + "WING in plan, both halves averaged: out  leading - trailing  (starboard less port). From 1.9 to 3.0 out"
        " the boom stands in front of and behind the wing, so those rows are the boom's")
    for o in list(np.arange(1.0, 7.0, 0.5)) + list(np.arange(7.0, 7.95, 0.1)):
        pair = [widest(int(round(cx - sign * o * sp)), 2.5, 6.0) for sign in (1, -1)]
        if all(pair):
            le = [st(p[1]) for p in pair]
            te = [st(p[0]) for p in pair]
            say("  %5.2f  %.3f - %.3f  (%+.3f %+.3f)" % (o, np.mean(le), np.mean(te), le[0] - le[1], te[0] - te[1]))
    say(chr(10) + "TAILPLANE in plan, both halves averaged: out  leading - trailing")
    for o in np.arange(0.0, 3.3, 0.25):
        pair = [widest(int(round(cx - sign * o * sp)), 9.3, 11.2) for sign in (1, -1)]
        if all(pair):
            say("  %5.2f  %.3f - %.3f" % (o, np.mean([st(p[1]) for p in pair]), np.mean([st(p[0]) for p in pair])))
    say(chr(10) + "PLAN, every 0.25 m of station: the gondola's edges, then each boom's (out, starboard first)")
    for s in np.arange(0.0, 11.5, 0.25):
        rr = edges_at(plan, PLAN_BOX, int(round(nose_row - s * sp)), 0)
        g = [r for r in rr if r[0] <= cx <= r[1] and r[1] - r[0] < 2.0 * sp]
        bs = [r for r in rr if abs(abs(out((r[0] + r[1]) / 2.0)) - BOOM_OUT_M) < 0.4 and r[1] - r[0] < 1.4 * sp]
        say("  %5.2f  G %s  B %s" % (s, " ".join("[%+.3f,%+.3f]" % (out(a0), out(b0)) for a0, b0 in g),
                                      " ".join("[%+.3f,%+.3f]" % (out(a0), out(b0)) for a0, b0 in bs)))

    # ---- THE SIDE (nose LEFT): along by the printed length; the heights at the same scale, off the drawn reference line --
    sy, sx = np.nonzero(side)
    sy = sy + SIDE_BOX[0]
    sx = sx + SIDE_BOX[2]
    nose_col = int(sx.min())
    ss = (sx.max() - sx.min() + 1) / LENGTH_M
    fin_row = int(sy.min())
    sheet = turned_sheet(ink, SIDE_BOX, SIDE_TURN)
    # THE REFERENCE LINE is the long rule the 8 in dimension stands on at the nose, the inkiest row of columns 310-480;
    # the thrust line the long rule 5.078 in under it, the inkiest of columns 310-700 a few rows lower.
    frl_row = inkiest(sheet, range(290, 310), 310, 480)
    thrust_row = inkiest(sheet, range(int(frl_row) + 6, int(frl_row) + 20), 310, 700)
    say(chr(10) + "SIDE: length %d px for the printed 37 ft 9-15/16 in, %.2f px a metre (%+.2f%% on the plan); the nose"
        " column %d; the fin's top row %d; the reference line's row %.1f and the thrust line's %.1f, %.3f m under it against the printed"
        " 5.078 in, %.3f" % (sx.max() - sx.min() + 1, ss, 100.0 * (ss / sp - 1.0), nose_col, fin_row, frl_row, thrust_row,
                            (thrust_row - frl_row) / ss, 5.078 * INCH))
    lines = reference_lines(ink)
    say("  the dash-dot reference and thrust lines as drawn (unturned): a common slope of %.2f deg through %d dashes, rms"
        " %.1f px, %.1f px apart (%.3f m; printed 5.078 in, %.3f)" % (lines[0], lines[1], lines[2], lines[3],
                                                                    lines[3] / ss, 5.078 * INCH))
    tops = [(frl_row - edges_at(side, SIDE_BOX, int(round(nose_col + t * ss)), 1)[-1][0]) / ss
            for t in np.arange(10.2, 10.56, 0.05)]
    say("  the boom's top under the tailplane, 10.20 to 10.55 aft, %.3f to %.3f over the reference line (the tailplane is"
        " printed 21.099 in over the thrust line, %.3f over the reference line)" % (min(tops), max(tops),
                                                                                  (21.099 - 5.078) * INCH))
    sst = lambda col: (col - nose_col) / ss
    sh = lambda row: (frl_row - row) / ss
    say("  so the fin's top is %.3f over the reference line" % sh(fin_row))
    for name, box, radii, printed in (("NOSE", (425, 525, 385, 495), (28, 40), 27), ("MAIN", (375, 500, 670, 810), (38, 50), 36)):
        ccol, crow, rad, rms = tv.circle(sheet, box, radii)
        say("  the %s tyre's dashed circle at station %.3f, %.3f under the line, %.3f m across (printed %d in, %.3f;"
            " rms %.2f px)" % (name, sst(ccol), -sh(crow), 2 * rad / ss, printed, printed * INCH, rms))
    say(chr(10) + "SIDE silhouette (the gondola, the near boom and the fin together) every 0.25 m: runs low to high")
    for s in np.arange(0.0, LENGTH_M, 0.25):
        rr = edges_at(side, SIDE_BOX, int(round(nose_col + s * ss)), 1)
        say("  %5.2f " % s + " ".join("[%+.3f,%+.3f]" % (sh(b0), sh(a0)) for a0, b0 in reversed(rr)))

    # ---- THE FRONT: its span, its dihedral ----
    fy, fx = np.nonzero(front)
    fy = fy + FRONT_BOX[0]
    fx = fx + FRONT_BOX[2]
    f_span = fx.max() - fx.min() + 1
    fcx = (fx.max() + fx.min()) / 2.0
    fs = f_span / (SPAN_M * np.cos(np.radians(5.0 + 40.0 / 60.0)))
    say(chr(10) + "FRONT: span %d px, %.2f px a metre at the printed span over cos(5 deg 40 min); the middle column %.1f"
        % (f_span, fs, fcx))
    mids = []
    for o in np.arange(3.2, 7.4, 0.2):
        for sign in (1, -1):
            rr = edges_at(front, FRONT_BOX, int(round(fcx - sign * o * fs)), 1)
            if rr:
                a0, b0 = rr[0]
                mids.append((o, -(a0 + b0) / 2.0 / fs))
    (c0, c1), rms, worst = tv.fit(mids)
    say("  the outer wing's middle rises %.4f a metre out, %.2f deg, over %d columns, rms %.1f mm (printed 5 deg 40 min);"
        % (c1, np.degrees(np.arctan(c1)), len(mids), rms * 1000))
    inner = []
    for o in np.arange(0.9, 1.9, 0.2):
        for sign in (1, -1):
            rr = edges_at(front, FRONT_BOX, int(round(fcx - sign * o * fs)), 1)
            if rr:
                inner.append((o, -(rr[0][0] + rr[0][1]) / 2.0 / fs))
    (i0, i1), irms, _ = tv.fit(inner)
    say("  between the gondola and the booms %.2f deg (the centre section is flat, rms %.1f mm)"
        % (np.degrees(np.arctan(i1)), irms * 1000))
    return locals()


def main():
    measure(print)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        FOLDER = sys.argv[1]
    main()
