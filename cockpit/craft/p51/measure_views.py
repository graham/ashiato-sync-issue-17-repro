"""Re-derives every MEASURED figure in `sources.md` and `P51Airframe` from the P-51D three-view alone, reading
nothing out of the write-up.

    python cockpit/craft/p51/measure_views.py [folder holding p51d_nospecs.png and p51d_an01-60-3.png]

The folder defaults to ~/Desktop/godotgames-drafts/2026-09-19/cockpit-warbirds/research/. The drawing is the USAAF's own, from
AN 01-60-3 p.30 (1945), after North American drawing 106-00001: "North American P-51D Mustang 3-view line drawing.png"
on Wikimedia Commons, {{PD-USGov-Military}}, with its printed dimensions (1905 x 2489 px); and the same sheet with the
dimension lines taken out, "... (no specs).png" (2489 x 1905 px), which is what the silhouettes are read off, since a
dimension line crossing an outline would let no flood fill tell inside from out. Study material, not in the repo.

THE CLEAN SHEET HOLDS THREE VIEWS: the side along the top left (nose to the LEFT, so the port side), the plan on the
right (nose to the left, starboard UP the page) and the front under the side (starboard on the viewer's left). The
side view draws the aeroplane with its FUSELAGE REFERENCE LINE LEVEL and the ground RAKED under it at the printed
13 deg 36 min, the three-point attitude: the drawing is read in that frame and so is the model (`modelling_here.md`,
"the gear convention is the Hawkeye's, not a law").

EACH VIEW IS SCALED BY ITS OWN PRINTED DIMENSION, and checked against a second printed figure it was not set from
(`learnings/2026-09-19-liners.md`): the plan by the span (37 ft 0-5/16 in) and checked on the tailplane (13 ft 2-1/8 in);
the side by the length (32 ft 3-5/16 in); the front by the main wheel track (142 in) and checked on the propeller's
disc (11 ft 2 in) and the span.

STATIONS ARE METRES AFT OF THE SPINNER'S TIP; HEIGHTS ARE METRES OVER THE THRUST LINE, which the drawing puts on the
fuselage reference line (the printed "THRUST" and "FUSE. REF. LINE" arrows are one row); OUT is metres to starboard.

EDGES ARE FITTED OVER EVERY ROW AND THE RESIDUAL PRINTED, never through two ends (`modelling_here.md` section 3).
"""
import os
import sys

import numpy as np
from PIL import Image

FOLDER = os.path.expanduser("~/Desktop/godotgames-drafts/2026-09-19/cockpit-warbirds/research")
INCH = 0.0254
SPAN_M = (37 * 12 + 5.0 / 16.0) * INCH          # 11.286: printed on the plan
LENGTH_M = (32 * 12 + 3 + 5.0 / 16.0) * INCH     # 9.838: printed over the side view, spinner to rudder
TRACK_M = 142.0 * INCH                           # 3.607: printed under the front view, tyre to tyre on their middles
TAILPLANE_M = (13 * 12 + 2 + 1.0 / 8.0) * INCH   # 4.016: printed over the plan's tailplane
PROP_M = (11 * 12 + 2) * INCH                    # 3.404: printed on the front view's dashed disc
FIN_OVER_FRL_M = (69 + 9.0 / 16.0) * INCH        # 1.767: printed, the fin's top over the reference line
GROUND_RAKE_DEG = 13.0 + 36.0 / 60.0             # printed: the ground line against the reference line
# The clean sheet's three views as (row0, row1, col0, col1), found by the ink's own gaps. The plan's box holds the side
# view's fin and the front view's port wing tip at two of its corners, so each view is also the component that holds a
# seed point in its own fuselage.
SIDE_BOX = (170, 700, 120, 1420)
PLAN_BOX = (205, 1665, 1175, 2440)
FRONT_BOX = (1195, 1700, 45, 1500)
SIDE_SEED = (420, 700)
PLAN_SEED = (950, 1600)
FRONT_SEED = (1470, 770)
# TWO LINES IN THE SIDE VIEW THAT ARE NOT THE AEROPLANE, taken out of the ink before the fill: the ANTENNA WIRE from the
# mast behind the canopy to the fin's top, a one-pixel line that closes a triangle over the spine a flood fill cannot
# enter; and the raked GROUND LINE, which the tail wheel and the main tyre both stand on and so joins them to the
# aeroplane. Each is its two ends (row, col), hand picked, and the ink within 2.5 px of the line between them is taken
# out, `keep` px short of each end. The tyres lose their bottom 2 px to it (2 cm); nothing measured is read there.
LINES = [((302, 760), (216, 1215), 12), ((676, 290), (441, 1395), 0)]


# THE MODEL'S OWN READINGS the overlay needs to leave the blades and a drop tank out: the propeller's plane (the side
# view's blade, station 0.51) and the leading edge's fit, both printed below and typed here only for the overlay's masks.
PROP_STATION = 0.51
WING_LE = (2.687, 0.0671)
WING_MID = (-0.593, 0.0993)
# HAND PICKS: (what, sheet column, sheet row) of the clean sheet, off crops at x2 and x3.
SIDE_PICKS = [
    ("windscreen's foot on the deck", 560, 335), ("windscreen's frame, top", 618, 303),
    ("windscreen's lower edge at its frame", 612, 368), ("hood's rail, fore", 622, 370), ("hood's rail, aft", 843, 337),
    ("canopy's aft end on the spine", 850, 333), ("radio mast's tip", 970, 280), ("scoop's lip", 635, 545),
    ("scoop's lip, top (the gap)", 635, 512), ("wing root's leading edge", 465, 500), ("wing root's trailing edge", 807, 500),
    ("tailplane's section, leading", 1120, 370), ("tailplane's section, trailing", 1270, 370),
    ("elevator's hinge in the section", 1227, 370), ("rudder's hinge, top", 1282, 200), ("rudder's hinge, foot", 1282, 427),
    ("fin's leading edge, low", 1187, 307), ("fin's leading edge, high", 1223, 213), ("fin's top, fore", 1247, 197),
    ("fin's top, aft", 1317, 198), ("rudder's trailing edge", 1343, 300), ("rudder's foot, aft", 1333, 417),
    ("dorsal fillet's start", 1160, 327), ("exhaust stacks, first", 295, 395), ("exhaust stacks, last", 410, 395),
]
PLAN_PICKS = [
    ("windscreen's foot", 1622, 945), ("windscreen's frame", 1670, 945), ("canopy's aft point", 1925, 945),
    ("canopy's widest, starboard edge", 1730, 896), ("fuselage's edge at the canopy", 1730, 889),
    ("aileron's hinge, outer end", 1727, 277), ("aileron's hinge, inner end", 1755, 535),
    ("flap's hinge, outer end", 1753, 537), ("flap's hinge, inner end", 1790, 882),
    ("elevator's hinge", 2286, 800), ("tailplane's leading edge at its root", 2183, 917),
    ("tailplane's leading edge near its tip", 2225, 717), ("retracted wheel's circle, middle", 1591, 900),
    ("retracted wheel's circle, other middle", 1591, 1000),
]
FRONT_PICKS = [
    ("gun muzzle, inner", 471, 1478), ("gun muzzle, middle", 494, 1478), ("gun muzzle, outer", 515, 1478),
]


def load(name):
    grey = np.asarray(Image.open(os.path.join(FOLDER, name)).convert("L")).astype(int)
    return grey < 160


def sweep(allowed, seed):
    """The `allowed` pixels connected to `seed` (a boolean array), sweeping each axis both ways until nothing grows."""
    out = seed & allowed
    while True:
        before = out.sum()
        for axis in (0, 1):
            for flip in (False, True):
                o = np.flip(out, axis) if flip else out
                w = np.flip(allowed, axis) if flip else allowed
                o = np.moveaxis(o, axis, 0).copy()
                w = np.moveaxis(w, axis, 0)
                for i in range(1, o.shape[0]):
                    o[i] |= o[i - 1] & w[i]
                o = np.moveaxis(o, 0, axis)
                out = np.flip(o, axis) if flip else o
        if out.sum() == before:
            return out


def without_lines(ink):
    ink = ink.copy()
    for line in LINES:
        _take_out(ink, *line)
    return ink


def _take_out(ink, start, end, keep):
    (r0, c0), (r1, c1) = start, end
    d = np.array([r1 - r0, c1 - c0], dtype=float)
    length = np.hypot(*d)
    d /= length
    rows, cols = np.mgrid[min(r0, r1) - 4:max(r0, r1) + 5, c0:c1 + 1]
    rel_r = rows - r0
    rel_c = cols - c0
    along = rel_r * d[0] + rel_c * d[1]
    off = np.abs(rel_r * d[1] - rel_c * d[0])
    cut = (off <= 2.5) & (along > keep) & (along < length - keep)
    ink[rows[cut], cols[cut]] = False


def solid(ink, box, seed):
    """A view's silhouette: everything the border's white cannot reach, then only the part holding `seed`."""
    r0, r1, c0, c1 = box
    part = ink[r0:r1, c0:c1]
    white = ~part
    border = np.zeros_like(white)
    border[0, :] = border[-1, :] = True
    border[:, 0] = border[:, -1] = True
    body = ~sweep(white, border)
    at = np.zeros_like(body)
    at[seed[0] - r0, seed[1] - c0] = True
    return sweep(body, at), body


def runs(indices):
    if len(indices) == 0:
        return []
    splits = np.where(np.diff(indices) != 1)[0] + 1
    return [(r[0], r[-1]) for r in np.split(indices, splits)]


def fit(rows):
    rows = np.array(rows)
    a_matrix = np.c_[np.ones(len(rows)), rows[:, 0]]
    c, *_ = np.linalg.lstsq(a_matrix, rows[:, 1], rcond=None)
    r = rows[:, 1] - a_matrix @ c
    return c, float(np.sqrt((r ** 2).mean())), float(np.abs(r).max())


def views():
    ink = load("p51d_nospecs.png")
    side, side_all = solid(without_lines(ink), SIDE_BOX, SIDE_SEED)
    plan, _ = solid(ink, PLAN_BOX, PLAN_SEED)
    front, front_all = solid(ink, FRONT_BOX, FRONT_SEED)
    return ink, side, side_all, plan, front, front_all


def measure(say=print):
    """Every figure, printed through `say`, and the working kept for `overlay_views.py`."""
    ink, side, side_all, plan, front, front_all = views()
    sy, sx = np.nonzero(side)
    py, px = np.nonzero(plan)
    fy, fx = np.nonzero(front)

    # ---- THE PLAN: scaled by its printed span, checked on its length and its printed tailplane ----
    plan_span = py.max() - py.min() + 1
    sp = plan_span / SPAN_M
    nose_p = px.min()
    cy = (py.min() + py.max()) / 2.0
    say("PLAN: span %d px for the printed %.3f m, %.2f px a metre (%.4f m a pixel); centreline row %.1f"
          % (plan_span, SPAN_M, sp, 1.0 / sp, cy))
    plan_length = px.max() - px.min() + 1
    say("  length spinner to tail %d px = %.3f m against the printed %.3f (%+.2f%%)"
          % (plan_length, plan_length / sp, LENGTH_M, 100.0 * (plan_length / sp - LENGTH_M) / LENGTH_M))
    # The tailplane: the widest run of rows in the columns aft of 8.2 m.
    tail_cols = [c for c in range(px.min(), px.max() + 1) if (c - nose_p) / sp > 8.0]
    widest = 0
    for c in tail_cols:
        rr = np.nonzero(plan[:, c])[0]
        if len(rr):
            widest = max(widest, rr.max() - rr.min() + 1)
    say("  tailplane span %d px = %.3f m against the printed %.3f (%+.2f%%)"
          % (widest, widest / sp, TAILPLANE_M, 100.0 * (widest / sp - TAILPLANE_M) / TAILPLANE_M))

    # ---- THE SIDE: scaled by its printed length; the thrust line is the spinner tip's row ----
    side_length = sx.max() - sx.min() + 1
    ss = side_length / LENGTH_M
    nose_s = sx.min()
    tip_rows = np.nonzero(side[:, nose_s:nose_s + 3].any(axis=1))[0]
    thrust = float(np.median(tip_rows))
    say("SIDE: length %d px for the printed %.3f m, %.2f px a metre (%+.2f%% against the plan's); thrust line row %.1f"
          % (side_length, LENGTH_M, ss, 100.0 * (ss - sp) / sp, thrust))
    fin_top = sy.min()

    # ---- THE FRONT: scaled by its printed track, checked on the propeller's disc and the span ----
    # THE TYRES hang below the wing on dashed legs, so each is its own component: read on the rows 430 to 455 of the box,
    # under the propeller's dashed disc (its bottom is row 405) and over the dashed ground line (467).
    wheels = front_all & ~front
    band = wheels[430:456]
    wheel_centres = []
    for a, b in runs(np.nonzero(band.any(axis=0))[0]):
        if b - a >= 30:
            rows = np.nonzero(wheels[:, a:b + 1].any(axis=1))[0]
            rows = rows[rows > 380]
            wheel_centres.append(((a + b) / 2.0, b - a + 1, rows.min(), rows.max()))
    say("  front view tyres (centre col, width px, top row, bottom row):", wheel_centres)
    track_px = abs(wheel_centres[-1][0] - wheel_centres[0][0])
    sf = track_px / TRACK_M
    fcx = (wheel_centres[-1][0] + wheel_centres[0][0]) / 2.0
    front_span = fx.max() - fx.min() + 1
    say("FRONT: track %.1f px for the printed %.3f m, %.2f px a metre (%+.2f%% against the plan's); centre col %.1f;"
          " the wing tips' middle col %.1f" % (track_px, TRACK_M, sf, 100.0 * (sf - sp) / sp, fcx,
                                             (fx.min() + fx.max()) / 2.0))
    say("  span %d px = %.3f m against the printed %.3f (%+.2f%%; a 5-degree dihedral alone foreshortens it %.2f%%)"
          % (front_span, front_span / sf, SPAN_M, 100.0 * (front_span / sf - SPAN_M) / SPAN_M,
             100.0 * (np.cos(np.radians(5.0)) - 1.0)))

    # ---- THE SIDE VIEW'S HEIGHTS ARE NOT AT ITS LENGTH'S SCALE. The original sheet prints two heights on the same side
    # view: the fin's top 69-9/16 in over the reference line and the level ground line 76-1/2 in under it, 146-1/16 in
    # (3.710 m) from the fin's top to the ground in all, whichever of the two close lines at the nose each arrow names.
    # Read on the original sheet, which is the same side view to a pixel (the fin stands 213 px over the spinner's tip on
    # both), that is the vertical scale. ----
    original = load("p51d_an01-60-3.png")
    # the fin's top is the first ink under the 32 ft dimension line (rows 20-30) in the fin's columns
    fin_row = [r for r in np.nonzero(original[35:120, 1380:1520].any(axis=1))[0] + 35][0]
    ground_rows = [r for r in range(470, 500) if original[r, 280:1500].sum() > 500]
    ground_row = float(np.mean(ground_rows))
    vs = (ground_row - fin_row) / ((69 + 9.0 / 16.0 + 76.5) * INCH)
    say("  the original's fin top row %d and level ground row %.1f: %.1f px for the printed 3.710 m, %.2f px a metre"
          " VERTICALLY (%+.2f%% against the side's own length)" % (fin_row, ground_row, ground_row - fin_row, vs,
                                                                    100.0 * (vs - ss) / ss))
    fin_over = (thrust - fin_top) / vs
    say("  so the fin top is %.3f m over the thrust line and the level ground %.3f m under it"
          % (fin_over, (69 + 9.0 / 16.0 + 76.5) * INCH - fin_over))
    st = lambda col: (col - nose_s) / ss
    hh = lambda row: (thrust - row) / vs

    say(chr(10) + "SIDE silhouette over the thrust line at each station (runs, low to high)")
    for station in np.arange(0.0, 9.85, 0.2):
        c = int(round(nose_s + station * ss))
        rr = runs(np.nonzero(side[:, c])[0])
        say("  %5.2f " % station + " ".join("[%+.3f,%+.3f]" % (hh(b), hh(a)) for a, b in reversed(rr)))

    stp = lambda col: (col - nose_p) / sp
    out = lambda row: (cy - row) / sp     # starboard UP the page is positive
    say(chr(10) + "PLAN outline, out from the centreline at each station (runs, starboard first)")
    for station in np.arange(0.0, 9.85, 0.2):
        c = int(round(nose_p + station * sp))
        rr = runs(np.nonzero(plan[:, c])[0])
        say("  %5.2f " % station + " ".join("[%+.3f,%+.3f]" % (out(a), out(b)) for a, b in rr))

    say(chr(10) + "WING in plan: leading and trailing edge along each row, fitted over 1.6 to 5.0 m out, each side")
    edges = {}
    for sign in (1, -1):
        le, te = [], []
        for o in np.arange(1.6, 5.0, 0.01):
            r = int(round(cy - sign * o * sp))
            rr = runs(np.nonzero(plan[r])[0])
            best = max(rr, key=lambda q: q[1] - q[0])
            le.append((o, stp(best[0])))
            te.append((o, stp(best[1])))
        for named, rows in (("leading", le), ("trailing", te)):
            (a0, b0), rms, worst = fit(rows)
            edges[(sign, named)] = (a0, b0)
            say("  %s %s edge: station = %.3f %+.4f x out, %d rows, rms %.1f mm, worst %.0f mm"
                  % ("starboard" if sign > 0 else "port", named, a0, b0, len(rows), rms * 1000, worst * 1000))
    say("  every 0.5 m, starboard:", " ".join("%.1f:%.3f-%.3f" % (o, stp(max(runs(np.nonzero(plan[int(round(cy - o * sp))])[0]), key=lambda q: q[1] - q[0])[0]), stp(max(runs(np.nonzero(plan[int(round(cy - o * sp))])[0]), key=lambda q: q[1] - q[0])[1])) for o in np.arange(0.5, 5.7, 0.25)))

    # THE WING'S AREA AND MEAN AERODYNAMIC CHORD, row by row over the drawn planform, the fitted edges carried in to the
    # centreline as a reference area is: both combine the plan's two axes, so they say whether the plan is stretched.
    area = 0.0
    c2 = 0.0
    row = 1.0 / sp
    for sign in (1, -1):
        o = 0.0
        while o < SPAN_M / 2.0:
            if o < 1.6:
                a0, b0 = edges[(sign, "leading")]
                a1, b1 = edges[(sign, "trailing")]
                chord = (a1 + b1 * o) - (a0 + b0 * o)
            else:
                r = int(round(cy - sign * o * sp))
                rr = runs(np.nonzero(plan[r])[0])
                chord = ((max(rr, key=lambda q: q[1] - q[0])[1] - max(rr, key=lambda q: q[1] - q[0])[0]) / sp) if rr else 0.0
            area += chord * row
            c2 += chord * chord * row
            o += row
    say("WING AREA %.2f m2 against the printed 235 sq ft, %.2f m2 (%+.1f%%); MAC %.3f m against the printed 79.60 in,"
          " %.3f m (%+.1f%%)" % (area, 235 * 0.09290304, 100.0 * (area / (235 * 0.09290304) - 1.0), c2 / area,
                                 79.60 * INCH, 100.0 * ((c2 / area) / (79.60 * INCH) - 1.0)))

    sff = front_span / (SPAN_M * np.cos(np.radians(5.0)))
    fo = lambda col: (fcx - col) / sff      # starboard on the viewer's LEFT is positive
    ground_front = [r for r in range(440, 500) if front_all[r].sum() > 0]
    say(chr(10) + "FRONT, scaled by its span over the 5-degree dihedral, %.2f px a metre; rows are box rows, the wing's"
          " middle row at each distance out, and the runs of rows" % sff)
    for o in np.arange(-5.6, 5.61, 0.2):
        c = int(round(fcx - o * sff))
        rr = runs(np.nonzero(front[:, c])[0])
        say("  %+5.2f " % o + " ".join("[%d,%d]" % (a0, b0) for a0, b0 in rr))

    # ---- CIRCLES, fitted to the ink rather than read by eye: the side view's two tyres and the front view's dashed
    # propeller disc ----
    say(chr(10) + "CIRCLES fitted to the ink (sheet col, row, radius px) and what they give")
    tyres_side = []
    for named, box, radii in (("main tyre", (560, 640, 440, 540), (30, 55)), ("tail wheel", (475, 510, 1090, 1150), (8, 25))):
        cx, cyy, rad = circle(ink, box, radii)
        tyres_side.append((cx, cyy, rad))
        say("  side %-10s (%.1f, %.1f) r %.1f: station %.3f, %.3f m over the thrust line, %.3f m across (%.3f up)"
            % (named, cx, cyy, rad, (cx - SIDE_BOX[2] - nose_s) / ss, (thrust + SIDE_BOX[0] - cyy) / vs, 2 * rad / ss,
               2 * rad / vs))
    main_t, tail_t = tyres_side
    a_pt = ((main_t[0] - SIDE_BOX[2] - nose_s) / ss, (thrust + SIDE_BOX[0] - main_t[1]) / vs, main_t[2] / vs)
    b_pt = ((tail_t[0] - SIDE_BOX[2] - nose_s) / ss, (thrust + SIDE_BOX[0] - tail_t[1]) / vs, tail_t[2] / vs)
    d = np.hypot(b_pt[0] - a_pt[0], b_pt[1] - a_pt[1])
    rake = np.degrees(np.arctan2(b_pt[1] - a_pt[1], b_pt[0] - a_pt[0]) + np.arcsin((a_pt[2] - b_pt[2]) / d))
    say("  the two tyres' lower common tangent is raked %.2f deg against the printed %.2f" % (rake, GROUND_RAKE_DEG))
    say("  the main tyre's bottom %.3f m under the thrust line" % (a_pt[2] - a_pt[1]))
    dcx, dcy, drad = circle(ink, (1210, 1700, 450, 1100), (180, 240))
    say("  front propeller disc (%.1f, %.1f) r %.1f: %.3f m across at the span's scale, against the printed %.3f (%+.1f%%)"
        % (dcx, dcy, drad, 2 * drad / sff, PROP_M, 100.0 * (2 * drad / sff / PROP_M - 1.0)))
    disc = (dcx, dcy, drad)

    # ---- HAND PICKS off the sheet's interior lines, which a silhouette cannot see. Each is a pixel of the clean sheet,
    # picked by eye off a crop and written here so it can be re-read and disputed; converted with the scales above. ----
    say(chr(10) + "HAND PICKS off interior lines (sheet col, row) -> station and height, or station and out")
    for named, col, row in SIDE_PICKS:
        say("  side  %-34s station %6.3f, %6.3f m over the thrust line"
            % (named, (col - SIDE_BOX[2] - nose_s) / ss, (thrust + SIDE_BOX[0] - row) / vs))
    for named, col, row in PLAN_PICKS:
        say("  plan  %-34s station %6.3f, %+6.3f m out" % (named, (col - PLAN_BOX[2] - nose_p) / sp,
                                                       (cy + PLAN_BOX[0] - row) / sp))
    for named, col, row in FRONT_PICKS:
        say("  front %-34s %+6.3f m out, %6.3f m over the thrust line"
            % (named, (fcx + FRONT_BOX[2] - col) / sff, (dcy - row) / vs))
    tyres = wheel_centres
    return locals()



def main_quiet():
    return measure(lambda *args: None)


def circle(ink, box, radii):
    """The circle the ink in `box` (row0, row1, col0, col1) most agrees with: a search for the centre whose distances
    pile up at one radius, then a least-squares fit to the ink within 4 px of it. (sheet col, row, radius)."""
    r0, r1, c0, c1 = box
    ys, xs = np.nonzero(ink[r0:r1, c0:c1])
    ys = ys + r0
    xs = xs + c0
    bins = np.arange(radii[0], radii[1], 1)
    best = None
    for cyy in range(r0, r1, 2):
        for cx in range(c0, c1, 2):
            dist = np.hypot(ys - cyy, xs - cx)
            count = np.histogram(dist, bins=bins)[0]
            if best is None or count.max() > best[0]:
                best = (count.max(), cyy, cx, bins[count.argmax()])
    _, cyy, cx, rad = best
    near = np.abs(np.hypot(ys - cyy, xs - cx) - rad) < 4
    x = xs[near].astype(float)
    y = ys[near].astype(float)
    c, *_ = np.linalg.lstsq(np.c_[2 * x, 2 * y, np.ones(len(x))], x ** 2 + y ** 2, rcond=None)
    return float(c[0]), float(c[1]), float(np.sqrt(c[2] + c[0] ** 2 + c[1] ** 2))


def main():
    measure(print)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        FOLDER = sys.argv[1]
    main()
