"""Re-derive every MEASURED number in `sources.md` from the F-14D drawing alone.

    python measure_drawing.py [path/to/F-14D.jpg]

The drawing is Commons' `F-14D.jpg` (Niyansfarn, CC BY 3.0), held for study in
`~/godotgames-drafts/2026-09-17/cockpit-tomcat/research/` and NEVER incorporated into the game.
This script reads nothing out of the write-up: it finds the views by their ink, scales them by
the published length, fits the lines, and solves for the wing pivot, so `sources.md` and this
file can disagree and one of them be wrong.

Every figure it prints is in metres. STATIONS are metres aft of the nose tip; OUT is metres
from the centreline.
"""
import math
import sys

import numpy as np
from PIL import Image

LENGTH = 19.10        # 62 ft 8 in, published
SPAN_SPREAD = 19.54   # 64 ft 1.5 in at 20 degrees, published
SPAN_SWEPT = 11.65    # 38 ft 2.5 in at 68 degrees, published
SPAN_OVERSWEPT = 10.15  # 33 ft 3.5 in at 75 degrees, published -- the cross-check, NOT fitted to
FORWARD, AFT, OVER = 20.0, 68.0, 75.0

path = sys.argv[1] if len(sys.argv) > 1 else "F-14D.jpg"
ink = np.array(Image.open(path).convert("L")) < 140


def bands(mask, gap=20):
    """Runs of rows that hold ink, separated by blank rows: one run per view."""
    rows = mask.any(axis=1)
    out, start = [], None
    for y, r in enumerate(rows):
        if r and start is None:
            start = y
        if not r and start is not None:
            if y - start > gap:
                out.append((start, y))
            start = None
    return out


views = bands(ink)
assert len(views) == 5, "expected front+rear, plan, underside, two sides; found %d" % len(views)
(fy0, fy1), (py0, py1), (uy0, uy1), (sy0, sy1), (ry0, ry1) = views


def x_extent(y0, y1):
    cols = np.where(ink[y0:y1].any(axis=0))[0]
    return int(cols.min()), int(cols.max())


px0, px1 = x_extent(py0, py1)
lengths = {"plan": px1 - px0, "underside": np.subtract(*x_extent(uy0, uy1)[::-1]),
           "side": np.subtract(*x_extent(sy0, sy1)[::-1]), "other side": np.subtract(*x_extent(ry0, ry1)[::-1])}
print("== THE VIEWS AGREE ON LENGTH, px:", lengths)
per_m = (px1 - px0) / LENGTH
print("   plan scale %.2f px a metre (%.2f mm a pixel), off the published %.2f m length" % (per_m, 1000 / per_m, LENGTH))

centre = None
plan = ink[py0:py1, px0:px1 + 1]
mids = []
for x in range(40, 420, 20):
    r = np.where(plan[:, x])[0]
    mids.append((r.min() + r.max()) / 2)
centre = float(np.median(mids))
print("   plan centreline at row %.1f of the view (nose columns agree to %.1f px)" % (centre, max(mids) - min(mids)))

swept_span = (py1 - py0) / per_m
print("== SWEPT SPAN in the plan view: %.2f m, published %.2f m (%+.1f%%)" % (
    swept_span, SPAN_SWEPT, 100 * (swept_span / SPAN_SWEPT - 1)))


def at(x_px, y_px):
    """(station, out) of a plan-view pixel on the starboard (upper) half."""
    return x_px / per_m, (centre - y_px) / per_m


# THE WING LEADING EDGE AT FULL SWEEP: the topmost ink in every column between the glove corner and the tip,
# fitted as a line. The glove corner and the tip are where that line starts and stops being the silhouette.
top = np.array([np.where(plan[:, x])[0].min() if plan[:, x].any() else -1 for x in range(plan.shape[1])])
tip_x = int(np.argmin(np.where(top >= 0, top, 10 ** 6)))
tip = at(tip_x, top[tip_x])
print("== WING TIP, leading-edge corner (topmost ink): station %.2f, out %.2f" % tip)


def fit(x_from_m, x_to_m):
    xs = np.arange(int(x_from_m * per_m), int(x_to_m * per_m))
    s = xs / per_m
    o = (centre - top[xs]) / per_m
    k, c = np.polyfit(o, s, 1)
    rms = float(np.sqrt(np.mean((k * o + c - s) ** 2)))
    return k, c, rms, o.min(), o.max()


k, c, rms, _, _ = fit(11.3, tip[0] - 0.25)
le_sweep = math.degrees(math.atan(k))
print("   wing LE: station = %.3f + %.4f * out, rms %.3f m -> LE SWEEP %.1f deg (the drawing's wing is at %g)" % (
    c, k, rms, le_sweep, AFT))
gk, gc, grms, glo, ghi = fit(6.9, 10.6)
print("   glove LE: station = %.3f + %.4f * out, rms %.3f m, out %.2f..%.2f -> glove sweep %.1f deg" % (
    gc, gk, grms, glo, ghi, math.degrees(math.atan(gk))))
# THE TWO LINES ARE ONE LINE. Fully swept, the moving wing's leading edge carries straight on from the fixed
# glove's: that is what 68 degrees is FOR on this aeroplane, a continuous delta at Mach 2. Their crossing is therefore
# ill-conditioned and is not used; the glove's outer corner is read off the drawing instead (below).
print("   the wing LE continues the glove LE to %.1f deg: at full sweep the aeroplane is one delta" % abs(
    le_sweep - math.degrees(math.atan(gk))))

# THE TIP'S TRAILING-EDGE CORNER: the rightmost ink within the tip's own chord rows. Rows further down belong to
# the stabilator, which reaches further aft.
rows = range(int(top[tip_x]), int(top[tip_x] + 0.75 * per_m))
right = max(((int(np.where(plan[r])[0].max()), r) for r in rows), key=lambda p: p[0])
tip_te = at(*right)
print("   wing tip, trailing-edge corner: station %.2f, out %.2f; tip chord %.2f m" % (
    tip_te + (math.dist(tip, tip_te),)))


def rotate(point, pivot, degrees):
    """Sweep a (station, out) point about `pivot` by `degrees`, positive AFT."""
    t = math.radians(degrees)
    ds, do = point[0] - pivot[0], point[1] - pivot[1]
    return (pivot[0] + ds * math.cos(t) + do * math.sin(t), pivot[1] - ds * math.sin(t) + do * math.cos(t))


def half_span(pivot, sweep):
    return max(rotate(p, pivot, sweep - AFT)[1] for p in (tip, tip_te))


# THE PIVOT. Its OUT is read where the glove's outer corner fairing sits; its STATION is then the one that turns the
# drawn 68-degree tip into the published 20-degree span. One published number solves one unknown; the overswept span
# is then a PREDICTION, and the check.
print("== THE PIVOT, solved from the published spread span:")
for out in (2.8, 2.9, 3.0, 3.1, 3.2):
    lo, hi = 9.0, 13.0
    for _ in range(60):
        mid = (lo + hi) / 2
        if half_span((mid, out), FORWARD) * 2 > SPAN_SPREAD:
            lo = mid
        else:
            hi = mid
    pivot = ((lo + hi) / 2, out)
    over = half_span(pivot, OVER) * 2
    print("   out %.1f -> station %.2f; PREDICTS overswept span %.2f m against the published %.2f (%+.1f%%)" % (
        out, pivot[0], over, SPAN_OVERSWEPT, 100 * (over / SPAN_OVERSWEPT - 1)))


# THE PANEL'S EXPOSED ROOT. Its leading-edge end is ON THE FITTED LEADING EDGE at 3.5 m out, where the glove's corner
# fairing ends: a pick in the fairing itself (1334, 269) sat 0.3 m ahead of both fitted lines, because the fairing is
# rounded, and would have put a step in a leading edge that the drawing shows is straight. Its trailing-edge end is a
# pick, where the trailing edge disappears under the overwing fairing.
ROOT_LE_OUT = 3.5
ROOT_TE_PX = (1654, 575)
pivot = None
lo, hi = 9.0, 13.0
for _ in range(60):
    mid = (lo + hi) / 2
    if half_span((mid, 3.0), FORWARD) * 2 > SPAN_SPREAD:
        lo = mid
    else:
        hi = mid
pivot = ((lo + hi) / 2, 3.0)
root_le, root_te = (c + k * ROOT_LE_OUT, ROOT_LE_OUT), at(*ROOT_TE_PX)
print("== THE PANEL, at the pivot (%.2f, %.2f), drawn at 68 and swung to 20:" % pivot)
for label, point in (("root LE", root_le), ("root TE", root_te), ("tip LE", tip), ("tip TE", tip_te)):
    f = rotate(point, pivot, FORWARD - AFT)
    print("   %-8s 68 deg: station %6.2f out %5.2f   ->  20 deg: station %6.2f out %5.2f" % (label, *point, *f))
a, b = rotate(root_le, pivot, FORWARD - AFT), rotate(root_te, pivot, FORWARD - AFT)
print("   at 20 deg the exposed root runs %.1f deg off the airflow: a root rib is streamwise at some sweep, and this"
      " one is at the forward stop" % math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])))
print("   the panel about its pivot at 20 degrees, (aft, out) in metres:")
for label, point in (("root LE", root_le), ("root TE", root_te), ("tip LE", tip), ("tip TE", tip_te)):
    f = rotate(point, pivot, FORWARD - AFT)
    print("   %-8s (%.3f, %.3f)" % (label, f[0] - pivot[0], f[1] - pivot[1]))
print("   [A]'s drawn root leading edge at 20 degrees is 3.32 m out (0.08 m a pixel); this puts it at %.2f" % a[1])
