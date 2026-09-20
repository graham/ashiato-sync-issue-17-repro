"""Re-derives every MEASURED figure in `sources.md` and `LightningAirframe` from the three JSF renders of the F-35B,
reading nothing out of the write-up.

    python cockpit/craft/lightning/measure_views.py [folder holding F-35B_Top.jpg, _Side.jpg and _Front.jpg]

The folder defaults to ~/godotgames-drafts/2026-09-18/cockpit-lightning/research/. The renders are not in the repo: they
are study material, and `sources.md` names their Commons pages.

THE THREE VIEWS SHARE ONE CAMERA SCALE, and that is checked here before anything is measured from it: the plan and the
front view must agree about the span, and the plan and the side about the length, to under half a per cent. The scale is
then the published span over the plan's span in pixels.

THE SILHOUETTE is every pixel NOT connected to the white border by white pixels (a flood fill in numpy, no scipy), so the
renders' pale highlights inside the aeroplane do not open holes in it.

EDGES ARE FITTED OVER EVERY ROW AND THE RESIDUAL PRINTED, never through two ends (`modelling_here.md` section 3).
"""
import os
import sys

import numpy as np
from PIL import Image

FOLDER = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-18/cockpit-lightning/research")
SPAN_M = 10.7        # Wikipedia, F-35B: 35 ft
LENGTH_M = 15.6      # 51.2 ft
HEIGHT_M = 4.36      # 14.3 ft, gear DOWN; the renders draw the gear up
WHITE = 230          # the silhouette's threshold on the darkest channel; the renders' background is 255


def outside(white):
    """The white pixels connected to the border, by sweeping each axis both ways until nothing changes."""
    out = np.zeros_like(white)
    out[0, :] = white[0, :]
    out[-1, :] = white[-1, :]
    out[:, 0] = white[:, 0]
    out[:, -1] = white[:, -1]
    while True:
        before = out.sum()
        for axis in (0, 1):
            for flip in (False, True):
                o = np.flip(out, axis) if flip else out
                w = np.flip(white, axis) if flip else white
                o = np.moveaxis(o, axis, 0).copy()
                w = np.moveaxis(w, axis, 0)
                for i in range(1, o.shape[0]):
                    o[i] |= o[i - 1] & w[i]
                o = np.moveaxis(o, 0, axis)
                out = np.flip(o, axis) if flip else o
        if out.sum() == before:
            return out


def view(name):
    rgb = np.asarray(Image.open(os.path.join(FOLDER, "F-35B_%s.jpg" % name)).convert("RGB")).astype(int)
    return rgb, ~outside(rgb.min(axis=2) >= WHITE)


def runs(indices):
    """Consecutive runs in a sorted index array, as (first, last) pairs."""
    if len(indices) == 0:
        return []
    splits = np.where(np.diff(indices) != 1)[0] + 1
    return [(r[0], r[-1]) for r in np.split(indices, splits)]


def fit(rows):
    """Least squares y = a + b x over (x, y) rows: (a, b), rms and worst residual."""
    rows = np.array(rows)
    a_matrix = np.c_[np.ones(len(rows)), rows[:, 0]]
    c, *_ = np.linalg.lstsq(a_matrix, rows[:, 1], rcond=None)
    r = rows[:, 1] - a_matrix @ c
    return c, float(np.sqrt((r ** 2).mean())), float(np.abs(r).max())


def main():
    top_rgb, top = view("Top")
    side_rgb, side = view("Side")
    front_rgb, front = view("Front")
    ty, tx = np.nonzero(top)
    sy, sx = np.nonzero(side)
    fy, fx = np.nonzero(front)
    plan_span = ty.max() - ty.min() + 1
    plan_length = tx.max() - tx.min() + 1
    side_length = sx.max() - sx.min() + 1
    front_span = fx.max() - fx.min() + 1
    print("ONE SCALE: plan span %d px, front span %d (%.2f%%); plan length %d, side length %d (%.2f%%); side height %d, front height %d"
          % (plan_span, front_span, 100.0 * (front_span - plan_span) / plan_span, plan_length, side_length,
             100.0 * (side_length - plan_length) / plan_length, sy.max() - sy.min() + 1, fy.max() - fy.min() + 1))
    s = plan_span / SPAN_M
    print("scale %.2f px a metre from the published span; %.4f m a pixel" % (s, 1.0 / s))
    print("length %.3f m against the published %.2f (%.2f%%)" % (plan_length / s, LENGTH_M,
                                                                  100.0 * (plan_length / s - LENGTH_M) / LENGTH_M))
    nose = tx.min()
    cy = (ty.min() + ty.max()) / 2.0
    low = sy.max()
    side_nose = sx.min()
    fin_tip = (low - sy.min()) / s
    print("fin tip %.3f m over the belly datum (the side view's lowest point); the ground under it for the published %.2f m: %.3f m"
          % (fin_tip, HEIGHT_M, HEIGHT_M - fin_tip))

    # ---- the plan's outline, every quarter metre ----
    print("\nPLAN outline, out from the centreline at each station (runs, starboard up the page)")
    for st in np.arange(0.0, 15.75, 0.25):
        x = int(round(nose + st * s))
        c = np.nonzero(top[:, x])[0]
        print("  %5.2f " % st + " ".join("[%+.2f,%+.2f]" % ((cy - b) / s, (cy - a) / s) for a, b in runs(c)))

    # ---- the side's top and bottom, every quarter metre, and the canopy's gold ----
    gold = (side_rgb[:, :, 0] - side_rgb[:, :, 2] > 25) & side
    print("\nSIDE silhouette over the belly datum at each station (runs), and the canopy's glazing")
    for st in np.arange(0.0, 15.75, 0.25):
        x = int(round(side_nose + st * s))
        c = np.nonzero(side[:, x])[0]
        g = np.nonzero(gold[:1300, x])[0]
        glass = " glass %.2f-%.2f" % ((low - g.max()) / s, (low - g.min()) / s) if len(g) > 3 else ""
        print("  %5.2f " % st + " ".join("[%.2f,%.2f]" % ((low - b) / s, (low - a) / s) for a, b in runs(c)) + glass)
    plan_gold = (top_rgb[:, :, 0] - top_rgb[:, :, 2] > 25) & top
    print("\nCANOPY in plan: half-width of the gold glazing at each station")
    for st in np.arange(1.9, 4.3, 0.1):
        x = int(round(nose + st * s))
        g = np.nonzero(plan_gold[:, x])[0]
        if len(g) > 3:
            print("  %.2f  %+.3f  %+.3f" % (st, (cy - g.min()) / s, (cy - g.max()) / s))

    # ---- the wing's and the tailplane's edges, fitted over every row ----
    print("\nWING leading edge: the first object pixel along each row from 2.6 to 5.2 m out")
    for side_sign in (1, -1):
        rows = []
        te = []
        for out in np.arange(2.6, 5.2, 0.02):
            y = int(round(cy - side_sign * out * s))
            row = np.nonzero(top[y])[0]
            rows.append((out, (row.min() - nose) / s))
            # Outboard of the tailplane's tip the wing is the only thing in the row, so its trailing edge is the row's end.
            te.append((out, (row.max() - nose) / s))
        (a, b), rms, worst = fit(rows)
        print("  %s: station = %.3f + %.4f x out, %d rows, rms %.1f mm, worst %.0f mm: %.2f degrees"
              % ("starboard" if side_sign > 0 else "port", a, b, len(rows), rms * 1000, worst * 1000,
                 np.degrees(np.arctan(b))))
        te = [r for r in te if r[0] >= 3.7]   # outboard of the tailplane's 3.63 m tip
        (a, b), rms, worst = fit(te)
        print("  trailing edge: station = %.3f + %.4f x out over %d rows from 3.7 m out, rms %.1f mm" %
              (a, b, len(te), rms * 1000))
    print("\nTAILPLANE: its run behind the wing's at each row")
    for out in np.arange(2.0, 3.7, 0.2):
        y = int(round(cy - out * s))
        r = runs(np.nonzero(top[y])[0])
        if len(r) > 1:
            print("  %.1f out  %.2f to %.2f" % (out, (r[1][0] - nose) / s, (r[1][1] - nose) / s))

    # ---- the fin, side and front ----
    print("\nFIN in the side view (projected heights): leading and trailing edge at each height")
    for h in np.arange(1.9, 3.47, 0.1):
        y = int(round(low - h * s))
        r = [q for q in runs(np.nonzero(side[y])[0]) if q[1] - q[0] > 5]
        print("  %.2f  %.2f to %.2f" % (h, (r[-1][0] - side_nose) / s, (r[-1][1] - side_nose) / s))
    fcx = (fx.min() + fx.max()) / 2.0
    flow = fy.max()
    print("\nFRONT view: the silhouette's runs out from the centre at each height over the belly datum")
    for h in np.arange(0.0, 3.46, 0.05):
        y = int(round(flow - h * s))
        print("  %.2f " % h + " ".join("[%+.2f,%+.2f]" % ((a - fcx) / s, (b - fcx) / s)
                                      for a, b in runs(np.nonzero(front[y])[0])))
    dark = (front_rgb.max(axis=2) < 60) & front
    print("\nINTAKE MOUTHS in the front view: the dark runs at each height")
    for h in np.arange(0.3, 1.25, 0.05):
        y = int(round(flow - h * s))
        print("  %.2f " % h + " ".join("[%+.2f,%+.2f]" % ((a - fcx) / s, (b - fcx) / s)
                                      for a, b in runs(np.nonzero(dark[y])[0]) if b - a > 4))


if __name__ == "__main__":
    main()
