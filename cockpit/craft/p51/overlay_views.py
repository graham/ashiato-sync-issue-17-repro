"""Lays the P-51D airframe's orthographic silhouettes over the three-view it was measured from, at x1.000 -- no fitting.

    python cockpit/craft/p51/overlay_views.py <folder of warbirds_shot's pictures> <out folder> [research folder]

`tests/warbirds_shot.gd` renders the side, top and front silhouettes at 123.88 px a metre, gear down and the propeller
left out, each with the drawing's datum at the picture's middle: the spinner's tip from the side and above, the
propeller's axis from ahead. The drawing's views are NOT all at that scale (`measure_views.py`): the side is 122.49 px a
metre along and 119.27 up, the front 124.08 across and 119.27 up. So each view of the DRAWING is resampled to 123.88 in
both directions by its own two scales -- its stretch taken out, which the filename says -- and laid with its datum on the
picture's middle. Nothing is fitted.

WHAT IS LEFT OUT OF THE DRAWING'S SILHOUETTES, and why: the propeller's blades, which stand where the draughtsman stopped
them (lane/osprey; the model's are left out too); the ground line and the antenna wire, taken out before the fill; a drop
tank's outline drawn across the starboard wing's leading edge in the plan; and the drop tanks from the front. The tyres'
circles, drawn as rings the ground line cut open, are filled from their fitted circles. From ahead, where the propeller's
disc covers the nose, the fuselage and the wing's roots, the agreement is ALSO printed outside the disc alone.

Each picture shows the drawing in grey, the model's silhouette in magenta over it at half strength, and the drawing's
outline in black on top. Each view prints its agreement as the share of the two silhouettes' union that both cover.
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
PX = 123.88
MAGENTA = np.array([209, 41, 140])
FRONT_TOP = m.FRONT_BOX[0]


def model_mask(name):
    rgb = np.asarray(Image.open(os.path.join(SHOTS, name)).convert("RGB")).astype(int)
    return np.abs(rgb - MAGENTA).sum(axis=2) < 120


def disc(shape, centre, radius):
    rows, cols = np.mgrid[0:shape[0], 0:shape[1]]
    return (rows - centre[0]) ** 2 + (cols - centre[1]) ** 2 <= radius ** 2


def resample(mask, grey, sx, sy):
    """The view at PX both ways: `sx` and `sy` are its own pixels a metre across and up."""
    h, w = mask.shape
    size = (int(round(w * PX / sx)), int(round(h * PX / sy)))
    mask2 = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).resize(size, Image.NEAREST)) > 127
    grey2 = np.asarray(Image.fromarray(grey.astype(np.uint8)).resize(size, Image.BILINEAR)).astype(float)
    return mask2, grey2


def outline(mask):
    edge = mask & ~(np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))
    return edge | np.roll(edge, 1, 0) | np.roll(edge, 1, 1)


def lay(name, ref, grey, datum, model_file, filename, keep=None):
    """`ref` and `grey` at PX with `datum` (row, col) on it; the model's picture has its datum at its middle."""
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
    both = (canvas & mine).sum()
    union = (canvas | mine).sum()
    said = "%-5s the two silhouettes agree over %.1f%% of their union (drawing %d px, model %d px)" % (
        name, 100.0 * both / union, canvas.sum(), mine.sum())
    if keep is not None:
        k = keep(mine.shape, dy, dx)
        said += "; outside the propeller's disc %.1f%%" % (100.0 * (canvas & mine & k).sum() / ((canvas | mine) & k).sum())
    picture = np.stack([back] * 3, axis=2) * 0.55 + 255 * 0.45
    picture[mine] = picture[mine] * 0.5 + MAGENTA * 0.5
    picture[outline(canvas)] = [0, 0, 0]
    ys, xs = np.nonzero(canvas | mine)
    crop = picture[max(ys.min() - 40, 0):ys.max() + 40, max(xs.min() - 40, 0):xs.max() + 40]
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(crop.clip(0, 255).astype(np.uint8)).save(os.path.join(OUT, filename))
    print(said)


def main():
    r = m.main_quiet()
    ink, side, plan, front, front_all = r["ink"], r["side"], r["plan"], r["front"], r["front_all"]
    clean = np.asarray(Image.open(os.path.join(m.FOLDER, "p51d_nospecs.png")).convert("L")).astype(float)

    # ---- THE SIDE: the tyres filled, the blades out ----
    ref = side.copy()
    r0, r1, c0, c1 = m.SIDE_BOX
    for (col, row, rad) in r["tyres_side"]:
        ref |= disc(ref.shape, (row - r0, col - c0), rad)
    prop_col = r["nose_s"] + m.PROP_STATION * r["ss"]
    rows, cols = np.mgrid[0:ref.shape[0], 0:ref.shape[1]]
    blades = (np.abs(cols - prop_col) < 0.12 * r["ss"]) & (np.abs(rows - r["thrust"]) > 0.42 * r["vs"])
    ref &= ~blades
    grey = clean[r0:r1, c0:c1]
    ref2, grey2 = resample(ref, grey, r["ss"], r["vs"])
    datum = (r["thrust"] * PX / r["vs"], r["nose_s"] * PX / r["ss"])
    lay("Side", ref2, grey2, datum, "warbirds-p51-20-side-at-drawing-scale.png",
        "cockpit-warbirds-p51-side-on-spinner-tip-over-an01-60-3-destretched-x1.000.png")

    # ---- THE PLAN: the blades out, the drop tank's outline off the starboard leading edge ----
    ref = plan.copy()
    r0, r1, c0, c1 = m.PLAN_BOX
    sp, cy, nose_p = r["sp"], r["cy"], r["nose_p"]
    rows, cols = np.mgrid[0:ref.shape[0], 0:ref.shape[1]]
    prop_col = nose_p + m.PROP_STATION * sp
    ref &= ~((np.abs(cols - prop_col) < 0.12 * sp) & (np.abs(rows - cy) > 0.42 * sp))
    out = (cy - rows) / sp
    le_col = nose_p + (m.WING_LE[0] + m.WING_LE[1] * np.abs(out)) * sp
    ref &= ~((out > 1.8) & (out < 2.7) & (cols < le_col - 2))
    grey = clean[r0:r1, c0:c1]
    ref2, grey2 = resample(ref, grey, sp, sp)
    datum = (cy * PX / sp, nose_p * PX / sp)
    lay("Top", ref2, grey2, datum, "warbirds-p51-21-top-at-drawing-scale.png",
        "cockpit-warbirds-p51-top-on-spinner-tip-and-centreline-over-an01-60-3-x1.000.png")

    # ---- THE FRONT: the tyres, no drop tanks, the disc's agreement printed apart ----
    ref = front.copy()
    r0, r1, c0, c1 = m.FRONT_BOX
    wheels = front_all & ~front
    for (col, width, top, bottom) in r["tyres"]:
        band = np.zeros_like(wheels)
        band[380:, int(col - width):int(col + width) + 1] = True
        ref |= wheels & band
    # THE DROP TANKS hang under each wing 1.9 to 2.9 m out: in those columns, everything below the run that holds the
    # wing's fitted middle (the tailplane is over it there, 1.9 to 2.0 m out, so the first run is not the wing).
    for col in range(ref.shape[1]):
        out = abs(r["fcx"] - col) / r["sff"]
        if 1.9 < out < 2.9:
            mid_row = r["disc"][1] - FRONT_TOP - (m.WING_MID[0] + m.WING_MID[1] * out) * r["vs"]
            for a, b in m.runs(np.nonzero(ref[:, col])[0]):
                if a <= mid_row <= b:
                    ref[b + 2:, col] = False
    # THE FIN, whose thin outline the fill does not close from ahead: the solid ink in the middle 24 px over the canopy.
    fin = front_all.copy()
    fin[:, :int(r["fcx"]) - 12] = False
    fin[:, int(r["fcx"]) + 13:] = False
    fin[int(r["disc"][1] - FRONT_TOP - 0.80 * r["vs"]):, :] = False
    ref |= fin
    grey = clean[r0:r1, c0:c1]
    ref2, grey2 = resample(ref, grey, r["sff"], r["vs"])
    axis = (r["disc"][1] - r0, r["disc"][0] - c0)
    datum = (axis[0] * PX / r["vs"], axis[1] * PX / r["sff"])
    # THE DISC IS A CIRCLE ON THE SHEET (its compass line fits one to 1.6 px rms), so once the heights are taken to their
    # printed scale it is an ellipse, 3.9 per cent taller than wide; it is left out as that ellipse, with 2 px for the pen.
    across = r["disc"][2] * PX / r["sff"] + 2.0
    up = r["disc"][2] * PX / r["vs"] + 2.0

    def outside_disc(shape, dy, dx):
        rows, cols = np.mgrid[0:shape[0], 0:shape[1]]
        return ((rows - datum[0] - dy) / up) ** 2 + ((cols - datum[1] - dx) / across) ** 2 > 1.0

    lay("Front", ref2, grey2, datum, "warbirds-p51-22-front-at-drawing-scale.png",
        "cockpit-warbirds-p51-front-on-propeller-axis-over-an01-60-3-destretched-x1.000.png", outside_disc)


if __name__ == "__main__":
    main()
