"""Lays the P-38L airframe's orthographic silhouettes over [AN]'s three-view at x1.000 -- no fitting.

    python cockpit/craft/p38/overlay_views.py <folder of warbirds_shot's pictures> <out folder> [research folder]

`tests/warbirds_shot.gd -- --only=p38` renders the side, top and front silhouettes at 94.07 px a metre (the plan's own
scale), GEAR UP, since [AN] draws the gear dashed and its silhouettes have none, and the propellers left out, each with
the datum at the picture's middle: the gondola's nose on the reference line from the side and above, the reference line
on the centreline from ahead.

Each view of the drawing is read square as `measure_views.py` turns it and RESAMPLED to 94.07 px a metre by its own
scale: the side 94.97 (its printed length), the plan its own, the front 93.52 (its printed span, the outer panels
foreshortened by the printed dihedral). The front's reference line is found from its spinners: their circles' middle,
the thrust line, is the printed 5.078 in under it. The plan is turned nose-left, starboard up.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import measure_views as m  # noqa: E402
import three_view as tv  # noqa: E402

SHOTS = sys.argv[1]
OUT = sys.argv[2]
if len(sys.argv) > 3:
    m.FOLDER = sys.argv[3]
PX = 94.07
MAGENTA = np.array([209, 41, 140])


def model_mask(name):
    rgb = np.asarray(Image.open(os.path.join(SHOTS, name)).convert("RGB")).astype(int)
    return np.abs(rgb - MAGENTA).sum(axis=2) < 120


def grey_turned(grey, degrees):
    return np.asarray(Image.fromarray(grey.astype(np.uint8)).rotate(degrees, resample=Image.BILINEAR,
                                                                     fillcolor=255)).astype(float)


def resample(mask, grey, scale):
    h, w = mask.shape
    size = (int(round(w * PX / scale)), int(round(h * PX / scale)))
    mask2 = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).resize(size, Image.NEAREST)) > 127
    grey2 = np.asarray(Image.fromarray(grey.astype(np.uint8)).resize(size, Image.BILINEAR)).astype(float)
    return mask2, grey2


def outline(mask):
    edge = mask & ~(np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))
    return edge | np.roll(edge, 1, 0) | np.roll(edge, 1, 1)


def lay(name, ref, grey, datum, model_file, filename):
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
    print("%-5s the two silhouettes agree over %.1f%% of their union (drawing %d px, model %d px)" % (
        name, 100.0 * (canvas & mine).sum() / (canvas | mine).sum(), canvas.sum(), mine.sum()))
    picture = np.stack([back] * 3, axis=2) * 0.55 + 255 * 0.45
    picture[mine] = picture[mine] * 0.5 + MAGENTA * 0.5
    picture[outline(canvas)] = [0, 0, 0]
    ys, xs = np.nonzero(canvas | mine)
    crop = picture[max(ys.min() - 40, 0):ys.max() + 40, max(xs.min() - 40, 0):xs.max() + 40]
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(crop.clip(0, 255).astype(np.uint8)).save(os.path.join(OUT, filename))


def main():
    r = m.measure(lambda *args: None)
    sheet = np.asarray(Image.open(os.path.join(m.FOLDER, m.SHEET)).convert("L")).astype(float)

    # ---- THE SIDE (nose left, the port side) ----
    r0, r1, c0, c1 = m.SIDE_BOX
    grey = grey_turned(sheet[r0:r1, c0:c1], m.SIDE_TURN)
    ref, g = resample(r["side"], grey, r["ss"])
    datum = ((r["frl_row"] - r0) * PX / r["ss"], (r["nose_col"] - c0) * PX / r["ss"])
    lay("Side", ref, g, datum, "warbirds-p38-20-side-at-drawing-scale.png",
        "cockpit-warbirds-p38-side-on-gondola-nose-and-reference-line-over-an01-75ff-2-x1.000.png")

    # ---- THE PLAN: turned nose-left (starboard up) ----
    r0, r1, c0, c1 = m.PLAN_BOX
    grey = grey_turned(sheet[r0:r1, c0:c1], m.PLAN_TURN)
    plan = np.rot90(r["plan"], k=-1)
    grey = np.rot90(grey, k=-1)
    # after a quarter turn clockwise, a sheet (row, col) in the box goes to (col, height - 1 - row)
    nose_col = (r1 - r0) - 1 - (r["nose_row"] - r0)
    centre_row = r["cx"] - c0
    ref, g = resample(plan, grey, r["sp"])
    datum = (centre_row * PX / r["sp"], nose_col * PX / r["sp"])
    lay("Top", ref, g, datum, "warbirds-p38-21-top-at-drawing-scale.png",
        "cockpit-warbirds-p38-top-on-gondola-nose-and-centreline-over-an01-75ff-2-x1.000.png")

    # ---- THE FRONT: its reference line the spinners' middle plus the printed 5.078 in ----
    r0, r1, c0, c1 = m.FRONT_BOX
    grey = grey_turned(sheet[r0:r1, c0:c1], m.FRONT_TURN)
    spinners = [tv.circle(r["ink"], (2030, 2110, c - 45, c + 45), (24, 34)) for c in (738, 1190)]
    thrust_row = float(np.mean([sp[1] for sp in spinners]))
    frl_row = thrust_row - 5.078 * m.INCH * r["fs"]
    print("Front the spinners' middles at rows %.1f and %.1f; the reference line row %.1f"
          % (spinners[0][1], spinners[1][1], frl_row))
    ref, g = resample(r["front"], grey, r["fs"])
    datum = ((frl_row - r0) * PX / r["fs"], (r["fcx"] - c0) * PX / r["fs"])
    lay("Front", ref, g, datum, "warbirds-p38-22-front-at-drawing-scale.png",
        "cockpit-warbirds-p38-front-on-reference-line-over-an01-75ff-2-x1.000.png")


if __name__ == "__main__":
    main()
