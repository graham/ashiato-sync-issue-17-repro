"""Lays the P-47D-30 airframe's orthographic silhouettes over [AN]'s three-view at x1.000 -- no fitting.

    python cockpit/craft/p47/overlay_views.py <folder of warbirds_shot's pictures> <out folder> [research folder]

`tests/warbirds_shot.gd -- --only=p47` renders the side, top and front silhouettes at 116.00 px a metre (the plan's own
scale), gear down and the propeller left out, each with the datum at the picture's middle: the spinner's tip from the side
and above, the propeller's axis from ahead.

[AN] draws the RP-47B, so two things are done TO THE DRAWING before it is laid, and each filename says so:
- THE C-1'S PLUG IS PUT IN: the drawing is cut at station 1.80 and everything aft of it moved 0.203 m aft (the 8 in [AN]'s
  own note gives), in the side view and the plan;
- EACH VIEW IS RESAMPLED to 116.00 px a metre by its own two scales: the side is 116.85 along and 119.65 up, the front
  116.00 across (the plan's, whose span it also draws 1 per cent short) and 119.65 up; the plan is turned nose-left.
The model is a D-30 and the drawing a razorback, so over the canopy and the spine behind it the two SHOULD disagree; the
side's agreement is printed whole and outside that region, 3.5 to 9.0 m aft and above the deck. From ahead the
propeller's disc is left out of the agreement, as the P-51's is.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_views as m  # noqa: E402

SHOTS = sys.argv[1]
OUT = sys.argv[2]
if len(sys.argv) > 3:
    m.FOLDER = sys.argv[3]
PX = 116.00
PLUG_AT = 1.80
PLUG = 0.203
MAGENTA = np.array([209, 41, 140])


def model_mask(name):
    rgb = np.asarray(Image.open(os.path.join(SHOTS, name)).convert("RGB")).astype(int)
    return np.abs(rgb - MAGENTA).sum(axis=2) < 120


def resample(mask, grey, sx, sy):
    h, w = mask.shape
    size = (int(round(w * PX / sx)), int(round(h * PX / sy)))
    mask2 = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).resize(size, Image.NEAREST)) > 127
    grey2 = np.asarray(Image.fromarray(grey.astype(np.uint8)).resize(size, Image.BILINEAR)).astype(float)
    return mask2, grey2


def plug(mask, grey, cut_col):
    """The C-1's 8 in put in: the columns from `cut_col` on moved PLUG x PX aft, the gap filled from the cut column."""
    n = int(round(PLUG * PX))
    mask2 = np.concatenate([mask[:, :cut_col], np.repeat(mask[:, cut_col:cut_col + 1], n, axis=1), mask[:, cut_col:]], axis=1)
    grey2 = np.concatenate([grey[:, :cut_col], np.repeat(grey[:, cut_col:cut_col + 1], n, axis=1), grey[:, cut_col:]], axis=1)
    return mask2, grey2


def outline(mask):
    edge = mask & ~(np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))
    return edge | np.roll(edge, 1, 0) | np.roll(edge, 1, 1)


def lay(name, ref, grey, datum, model_file, filename, apart=None, apart_said=""):
    mine = model_mask(model_file)
    canvas = np.zeros(mine.shape, dtype=bool)
    back = np.full(mine.shape, 255.0)
    dy = mine.shape[0] / 2.0 - datum[0]
    dx = mine.shape[1] / 2.0 - datum[1]
    ys, xs = np.nonzero(np.ones(ref.shape, dtype=bool))
    ty = np.round(ys + dy).astype(int)
    tx = np.round(xs + dx).astype(int)
    ok = (ty >= 0) & (ty < mine.shape[0]) & (tx >= 0) & (tx < mine.shape[1])
    canvas[ty[ok], tx[ok]] = ref[ys[ok], xs[ok]]
    back[ty[ok], tx[ok]] = grey[ys[ok], xs[ok]]
    said = "%-5s the two silhouettes agree over %.1f%% of their union (drawing %d px, model %d px)" % (
        name, 100.0 * (canvas & mine).sum() / (canvas | mine).sum(), canvas.sum(), mine.sum())
    if apart is not None:
        keep = ~apart(mine.shape, dy, dx)
        said += "; %s %.1f%%" % (apart_said, 100.0 * (canvas & mine & keep).sum() / ((canvas | mine) & keep).sum())
    picture = np.stack([back] * 3, axis=2) * 0.55 + 255 * 0.45
    picture[mine] = picture[mine] * 0.5 + MAGENTA * 0.5
    picture[outline(canvas)] = [0, 0, 0]
    ys, xs = np.nonzero(canvas | mine)
    crop = picture[max(ys.min() - 40, 0):ys.max() + 40, max(xs.min() - 40, 0):xs.max() + 40]
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(crop.clip(0, 255).astype(np.uint8)).save(os.path.join(OUT, filename))
    print(said)


def main():
    r = m.measure(lambda *args: None)
    sheet = np.asarray(Image.open(os.path.join(m.FOLDER, m.AN_SHEET)).convert("L")).astype(float)

    # ---- THE SIDE: the blades out, the plug in, the heights to scale ----
    side = m.opened(r["side"])
    r0, r1, c0, c1 = m.SIDE_BOX
    grey = sheet[r0:r1, c0:c1]
    nose = r["nose_s"] - c0
    thrust = r["thrust_row"] - r0
    rows, cols = np.mgrid[0:side.shape[0], 0:side.shape[1]]
    prop_col = nose + 0.50 * r["ss"]
    side &= ~((np.abs(cols - prop_col) < 0.12 * r["ss"]) & (np.abs(rows - thrust) > 0.30 * r["vs"]))
    ref, g = resample(side, grey, r["ss"], r["vs"])
    datum = (thrust * PX / r["vs"], nose * PX / r["ss"])
    ref, g = plug(ref, g, int(round(datum[1] + PLUG_AT * PX)))

    def canopy_region(shape, dy, dx):
        rows2, cols2 = np.mgrid[0:shape[0], 0:shape[1]]
        station = (cols2 - datum[1] - dx) / PX
        high = (datum[0] + dy - rows2) / PX
        return (station > 3.5) & (station < 9.0) & (high > 0.70)

    lay("Side", ref, g, datum, "warbirds-p47-20-side-at-drawing-scale.png",
        "cockpit-warbirds-p47-side-on-spinner-tip-over-an01-65bc-2-c1-plug-destretched-x1.000.png", canopy_region,
        "outside the canopy and spine the B and the D-30 do not share,")

    # ---- THE PLAN: turned nose-left (starboard up), the blades out, the plug in ----
    plan = m.opened(r["plan"])
    r0, r1, c0, c1 = m.PLAN_BOX
    grey = sheet[r0:r1, c0:c1]
    plan = np.rot90(plan, k=-1)
    grey = np.rot90(grey, k=-1)
    # after a quarter turn clockwise, a sheet (row, col) in the box goes to (col, height - 1 - row)
    h = r1 - r0
    nose_col = h - 1 - (r["nose_row"] - r0)
    centre_row = r["cx"] - c0
    rows, cols = np.mgrid[0:plan.shape[0], 0:plan.shape[1]]
    prop_col = nose_col + 0.50 * r["sp"]
    plan = plan & ~((np.abs(cols - prop_col) < 0.12 * r["sp"]) & (np.abs(rows - centre_row) > 0.30 * r["sp"]))
    ref, g = resample(plan, grey, r["sp"], r["sp"])
    datum = (centre_row * PX / r["sp"], nose_col * PX / r["sp"])
    ref, g = plug(ref, g, int(round(datum[1] + PLUG_AT * PX)))
    lay("Top", ref, g, datum, "warbirds-p47-21-top-at-drawing-scale.png",
        "cockpit-warbirds-p47-top-on-spinner-tip-and-centreline-over-an01-65bc-2-c1-plug-x1.000.png")

    # ---- THE FRONT: the disc left out of the agreement ----
    front = m.opened(r["front"])
    r0, r1, c0, c1 = m.FRONT_BOX
    grey = sheet[r0:r1, c0:c1]
    ref, g = resample(front, grey, r["sp"], r["vs"])
    datum = ((r["dcy"] - r0) * PX / r["vs"], (r["dcx"] - c0) * PX / r["sp"])
    across = r["drad"] * PX / r["sp"] + 2.0
    up = r["drad"] * PX / r["vs"] + 2.0

    def disc(shape, dy, dx):
        rows2, cols2 = np.mgrid[0:shape[0], 0:shape[1]]
        return ((rows2 - datum[0] - dy) / up) ** 2 + ((cols2 - datum[1] - dx) / across) ** 2 <= 1.0

    lay("Front", ref, g, datum, "warbirds-p47-22-front-at-drawing-scale.png",
        "cockpit-warbirds-p47-front-on-propeller-axis-over-an01-65bc-2-destretched-x1.000.png", disc,
        "outside the propeller's disc")


if __name__ == "__main__":
    main()
