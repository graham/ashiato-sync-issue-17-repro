"""Re-derives every MEASURED figure in `sources.md` and `WarthogAirframe` from the A-10 three-view alone, reading
nothing out of the write-up.

    python cockpit/craft/warthog/measure_views.py [folder holding a10_3view_kaboldy.png]

The folder defaults to ~/godotgames-drafts/2026-09-19/cockpit-warthog/research/. The drawing is Kaboldy's
"Fairchild Republic A-10 Thunderbolt II 3-view.svg" (Wikimedia Commons, CC BY-SA 3.0), rasterised at x3 by Godot's own
SVG loader (`Image.load_svg_from_buffer(bytes, 3.0)`, 4442 x 4705 px). It is study material and is not in the repo.

THE SHEET HOLDS THREE VIEWS: the side view along the top (nose to the right), the plan under it (nose to the right,
starboard DOWN the page) and the front view to its left, TURNED A QUARTER (the fins point left, starboard down). They
are checked to share ONE scale before anything is measured: the plan's span against the front view's, and the plan's
length against the side view's. The scale is then the published span over the plan's span.

STATIONS ARE METRES AFT OF THE FOREMOST POINT, the GAU-8's muzzle. HEIGHTS ARE METRES OVER THE BELLY DATUM, the side
view's lowest point of the fuselage itself (not the gear pods or the wheels). The side view draws the gear UP, with the
wheels drawn down again below it as circles on two ground lines, so the drawing's own ground is also read.

THE SILHOUETTE is every pixel of a view not connected to the white border by white pixels (a sweep fill in numpy), then
only the component that holds a seed point, so the loose wheel circles and ground lines are measured apart.

EDGES ARE FITTED OVER EVERY ROW AND THE RESIDUAL PRINTED, never through two ends (`modelling_here.md` section 3).
"""
import os
import sys

import numpy as np
from PIL import Image

FOLDER = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-19/cockpit-warthog/research")
SPAN_M = 17.53       # Wikipedia, A-10C specifications: 57 ft 6 in
LENGTH_M = 16.26     # 53 ft 4 in
HEIGHT_M = 4.47      # 14 ft 8 in, gear down
# The sheet's three views, as [row0, row1, col0, col1] boxes of the x3 raster: found by the ink's own gaps (the side
# view's rows 73-995 and the rest's 1122-4624; the front view's columns 110-769, the plan's 1119-4356).
SIDE_BOX = (0, 1060, 1060, 4442)
PLAN_BOX = (1080, 4705, 1060, 4442)
FRONT_BOX = (1080, 4705, 0, 830)


def load():
    rgba = np.asarray(Image.open(os.path.join(FOLDER, "a10_3view_kaboldy.png")).convert("RGBA")).astype(int)
    ink = (rgba[..., 3] > 60) & (rgba[..., :3].min(axis=2) < 160)
    return ink


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


def solid(ink, box):
    """A view's silhouette: everything the border's white cannot reach."""
    r0, r1, c0, c1 = box
    part = ink[r0:r1, c0:c1]
    white = ~part
    border = np.zeros_like(white)
    border[0, :] = border[-1, :] = True
    border[:, 0] = border[:, -1] = True
    return ~sweep(white, border), (r0, c0)


def component(mask, at):
    seed = np.zeros_like(mask)
    seed[at] = True
    return sweep(mask, seed)


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


def main():
    ink = load()
    side_all, _ = solid(ink, SIDE_BOX)
    plan, _ = solid(ink, PLAN_BOX)
    front, _ = solid(ink, FRONT_BOX)
    # THE AEROPLANE in the side view is the component holding the middle of the fuselage; the rest is the wheels drawn down
    # and their ground lines.
    sy, sx = np.nonzero(side_all)
    mid = (int((sy.min() + sy.max()) * 0.5), int((sx.min() + sx.max()) * 0.5))
    rows_at_mid = np.nonzero(side_all[:, mid[1]])[0]
    side = component(side_all, (int(np.median(rows_at_mid)), mid[1]))
    wheels = side_all & ~side

    py, px = np.nonzero(plan)
    fy, fx = np.nonzero(front)
    sy, sx = np.nonzero(side)
    plan_span = py.max() - py.min() + 1
    front_span = fy.max() - fy.min() + 1
    plan_length = px.max() - px.min() + 1
    side_length = sx.max() - sx.min() + 1
    print("ONE SCALE: plan span %d px, front span %d (%.2f%%); plan length %d, side length %d (%.2f%%)"
          % (plan_span, front_span, 100.0 * (front_span - plan_span) / plan_span, plan_length, side_length,
             100.0 * (side_length - plan_length) / plan_length))
    s = plan_span / SPAN_M
    print("scale %.2f px a metre from the published span; %.4f m a pixel" % (s, 1.0 / s))
    print("length %.3f m against the published %.2f (%.2f%%)"
          % (plan_length / s, LENGTH_M, 100.0 * (plan_length / s - LENGTH_M) / LENGTH_M))
    nose_p = px.max()          # the plan's foremost column
    nose_s = sx.max()          # the side's
    cy = (py.min() + py.max()) / 2.0
    fcy = (fy.min() + fy.max()) / 2.0
    print("plan centreline row %.1f, front centreline row %.1f (%.1f px apart)" % (cy, fcy, cy - fcy))

    # ---- the side's datum, the fuselage's lowest point, and the drawing's own ground ----
    # The belly datum is the lowest silhouette point between the nose and the wing's leading edge, clear of the gear pods
    # and the nose gear's box: the fuselage keel, read over stations 0.6 to 3.0.
    keel = []
    for st in np.arange(0.6, 3.0, 0.05):
        c = int(round(nose_s - st * s))
        rr = runs(np.nonzero(side[:, c])[0])
        keel.append(rr[0][1] if rr else 0)
    fin_top = sy.min()
    wy, wx = np.nonzero(wheels)
    grounds = runs(np.unique(wy[np.isin(wy, np.nonzero((wheels.sum(axis=1) > 0.9 * s))[0])]))
    print("ground lines in the side view (rows):", grounds)
    body_low = []
    for st in np.arange(0.5, 14.8, 0.25):
        c = int(round(nose_s - st * s))
        rr = runs(np.nonzero(side[:, c])[0])
        body_low.append((st, rr[-1][1] if rr else 0))
    # THE BELLY DATUM is the flat of the belly under the wing, stations 8.5 to 9.25: the lowest the fuselage itself goes
    # (the chin under the nose is the gun's housing, and 2.5 to 3.0 is the nose gear's box).
    datum = max(b for st, b in body_low if 8.5 <= st <= 9.25)
    fin_tip = (datum - fin_top) / s
    drawn_ground = (grounds[-2][0] + grounds[-1][1]) / 2.0
    print("belly datum row %d; FIN TIP %.3f m over it; the drawing's ground lines %.3f m under it (fin %.3f m over the"
          " drawn ground against the published %.2f, %.1f%%); the ground under the datum for the published height: %.3f m"
          % (datum, fin_tip, (drawn_ground - datum) / s, (drawn_ground - fin_top) / s, HEIGHT_M,
             100.0 * ((drawn_ground - fin_top) / s - HEIGHT_M) / HEIGHT_M, HEIGHT_M - fin_tip))
    h = lambda row: (datum - row) / s

    print(chr(10) + "SIDE silhouette over the belly datum at each station (runs, low to high)")
    for st in np.arange(0.0, 16.25, 0.25):
        c = int(round(nose_s - st * s))
        rr = runs(np.nonzero(side[:, c])[0])
        print("  %5.2f " % st + " ".join("[%.2f,%.2f]" % (h(b), h(a)) for a, b in reversed(rr)))

    print(chr(10) + "WHEELS drawn down in the side view: each circle's centre and diameter, and its ground line")
    for a, b in runs(np.nonzero(wheels[:grounds[-2][0] - 2].any(axis=0))[0]):
        if b - a < 40:
            continue
        ys = np.nonzero(wheels[:grounds[-2][0] - 2, a:b + 1].any(axis=1))[0]
        print("  station %.2f, diameter %.3f m across and %.3f m high, bottom %.3f m under the datum"
              % ((nose_s - (a + b) / 2.0) / s, (b - a) / s, (ys.max() - ys.min()) / s, -h(ys.max())))

    out = lambda row: (row - cy) / s     # starboard positive
    print(chr(10) + "PLAN outline, out from the centreline at each station (runs, port negative)")
    for st in np.arange(0.0, 16.25, 0.25):
        c = int(round(nose_p - st * s))
        rr = runs(np.nonzero(plan[:, c])[0])
        print("  %5.2f " % st + " ".join("[%+.2f,%+.2f]" % (out(a), out(b)) for a, b in rr))

    print(chr(10) + "WING in plan: leading and trailing edge along each row, 2.6 to 8.7 m out, each side")
    for sign in (1, -1):
        le, te = [], []
        for o in np.arange(3.2, 8.2, 0.02):
            r = int(round(cy + sign * o * s))
            cols = np.nonzero(plan[r])[0]
            rr = runs(cols)
            # The wing is the run whose span crosses the middle of the drawing's length.
            best = max(rr, key=lambda q: q[1] - q[0])
            le.append((o, (nose_p - best[1]) / s))
            te.append((o, (nose_p - best[0]) / s))
        for named, rows in (("leading", le), ("trailing", te)):
            (a, b), rms, worst = fit(rows)
            print("  %s %s edge: station = %.3f + %.4f x out, %d rows 3.2-8.2 m out, rms %.1f mm, worst %.0f mm"
                  % ("starboard" if sign > 0 else "port", named, a, b, len(rows), rms * 1000, worst * 1000))
        print("  rows every 0.5 m:", " ".join("%.1f:%.2f-%.2f" % (le[i][0], le[i][1], te[i][1]) for i in range(0, len(le), 25)))

    # ---- THE CENTRE SECTION: constant chord, the leading edge on the rows between the fuselage and the pods, the
    # trailing edge on the rows between the nacelles and the break (the nacelles hide it further in) ----
    centre_le = []
    centre_te = []
    for o in np.arange(0.8, 3.01, 0.1):
        for sign in (1, -1):
            r = int(round(cy + sign * o * s))
            rr = runs(np.nonzero(plan[r])[0])
            wing = max(rr, key=lambda q: q[1] - q[0])
            if o <= 2.2:
                centre_le.append((nose_p - wing[1]) / s)
            if o >= 2.4:
                centre_te.append((nose_p - wing[0]) / s)
    le_c = float(np.median(centre_le))
    te_c = float(np.median(centre_te))
    print(chr(10) + "CENTRE SECTION: leading edge %.2f to %.2f over %d rows (median %.3f), trailing edge %.2f to %.2f over %d"
          " rows (median %.3f): a constant chord of %.2f m" % (min(centre_le), max(centre_le), len(centre_le), le_c,
                                                               min(centre_te), max(centre_te), len(centre_te), te_c,
                                                               te_c - le_c))
    # ---- THE WING'S AREA, row by row over the drawn planform: every row from 3.0 m out to the tip measured as drawn
    # (its widest run is the wing), and the centre section's constant chord carried to the centreline, as a reference
    # area is ----
    area = 0.0
    row = 1.0 / s
    for sign in (1, -1):
        o = 0.0
        while o < 8.9:
            if o < 3.0:
                chord = te_c - le_c
            else:
                r = int(round(cy + sign * o * s))
                rr = runs(np.nonzero(plan[r])[0])
                chord = ((max(rr, key=lambda q: q[1] - q[0])[1] - max(rr, key=lambda q: q[1] - q[0])[0]) / s) if rr else 0.0
            area += chord * row
            o += row
    print("WING AREA from the drawn planform: %.2f m2 against the printed 47.0 (%+.1f%%)" % (area, 100.0 * (area - 47.0) / 47.0))

    fh = lambda col: fin_tip - (col - fx.min()) / s     # the front view is turned: up is to the LEFT
    print(chr(10) + "FRONT view (turned back upright): runs of height at each distance out, starboard positive")
    for o in np.arange(-8.8, 8.81, 0.2):
        r = int(round(fcy + o * s))
        rr = runs(np.nonzero(front[r])[0])
        print("  %+5.2f " % o + " ".join("[%.2f,%.2f]" % (fh(b), fh(a)) for a, b in reversed(rr)))
    # ---- HAND PICKS off the sheet's interior lines, which a silhouette cannot see. Each is a pixel of the WHOLE x3 raster,
    # picked by eye off a crop and written here so it can be re-read and disputed; converted with the scale above. ----
    print(chr(10) + "HAND PICKS off interior lines (sheet column, row) -> station, height or out")
    side_picks = [
        ("windscreen's foot", 4027, 422), ("windscreen frame at the bubble", 3772, 402),
        ("gear pod's nose", 3185, 688), ("fin leading edge, top", 1520, 110), ("fin leading edge, low", 1600, 600),
        ("fin's foot under the tailplane", 1515, 680), ("fin trailing edge, top", 1255, 85),
        ("fin trailing edge, low", 1170, 590), ("rudder hinge, top", 1340, 80), ("rudder hinge, low", 1295, 620),
        ("tailplane edge-on, leading", 1525, 562), ("tailplane edge-on, trailing", 1265, 562),
    ]
    for named, col, row in side_picks:
        col, row = col - SIDE_BOX[2], row - SIDE_BOX[0]
        print("  side  %-32s station %6.2f, %5.2f m over the datum" % (named, (nose_s - col) / s, (datum - row) / s))
    plan_picks = [
        ("canopy's aft point", 3397, 2873), ("canopy widest, port edge", 3777, 2779),
        ("nacelle intake lip", 2439, 2873), ("nacelle inner edge", 2600, 2717),
        ("aileron, outer end", 2622, 1278), ("aileron, inner end", 2622, 1857), ("aileron hinge", 2622, 1500),
        ("outer flap, outer end", 2618, 1887), ("outer flap, inner end", 2618, 2300),
    ]
    for named, col, row in plan_picks:
        col, row = col - PLAN_BOX[2], row - PLAN_BOX[0]
        print("  plan  %-32s station %6.2f, %+5.2f m out" % (named, (nose_p - col) / s, (row - cy) / s))
    return s, nose_p, nose_s, cy, fcy, side, plan, front, wheels, fin_top


def view(name):
    """ONE VIEW OF THE SHEET as (rgb, silhouette), upright and the way the model's probe photographs it: "Side" with the
    nose to the right and without the wheels drawn below it, "Top" nose right and starboard down, "Front" turned back
    upright (the sheet has it a quarter turned, fins to the left), starboard on the left as seen from ahead."""
    ink = load()
    rgba = np.asarray(Image.open(os.path.join(FOLDER, "a10_3view_kaboldy.png")).convert("RGBA")).astype(float)
    grey = 255.0 - (255.0 - rgba[..., :3]) * (rgba[..., 3:4] / 255.0)
    box = {"Side": SIDE_BOX, "Top": PLAN_BOX, "Front": FRONT_BOX}[name]
    mask, _ = solid(ink, box)
    rgb = grey[box[0]:box[1], box[2]:box[3]]
    if name == "Side":
        ys, xs = np.nonzero(mask)
        mid = (int((xs.min() + xs.max()) * 0.5))
        rows = np.nonzero(mask[:, mid])[0]
        mask = component(mask, (int(np.median(rows)), mid))
    if name == "Front":
        mask = np.rot90(mask, k=-1)
        rgb = np.rot90(rgb, k=-1)
    return rgb, mask


if __name__ == "__main__":
    main()
