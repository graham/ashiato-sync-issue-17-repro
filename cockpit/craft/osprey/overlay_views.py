"""Lays the V-22 airframe's orthographic silhouettes over the six views it was measured from, at x1.000 -- no fitting.

    python cockpit/craft/osprey/overlay_views.py <folder of osprey_shot's pictures> <out folder> [research folder]

`tests/osprey_shot.gd` renders each silhouette at the drawing's own scale for that view (the sides at 77.63 px a metre,
the fronts and plans at 78.26: `measure_views.py`), so the only thing left to choose is WHERE, and each pair is aligned
on a datum stated in the filename: the fin's trailing edge and the belly in a side view, the tail's trailing edge and the
tailplane's middle in a plan, the centreline and the belly in a front view. [JJ] draws the gear up, and the silhouettes
are drawn without it.

EACH VIEW PRINTS TWO AGREEMENTS, as the share of the two silhouettes' union that both cover (intersection over union):
the whole silhouette, and the silhouette OUTSIDE THE PROPROTOR DISCS -- a second picture from the probe, of the discs
alone. Where a blade stands in its disc is where the draughtsman stopped it, not a shape; in a face-on view the three
blades are a third of everything drawn, and a whole-silhouette number would mostly be a question about the phase.

Each picture shows the drawing in grey, the model's silhouette in magenta over it at half strength, the discs' region in
blue and the drawing's own outline in black on top, so a reader can see both edges.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_views  # noqa: E402

SHOTS = sys.argv[1]
OUT = sys.argv[2]
FOLDER = sys.argv[3] if len(sys.argv) > 3 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-19/cockpit-osprey/research")
MAGENTA = np.array([209, 41, 140])
BLUE = np.array([26, 115, 217])
SIDE_K = 1357.0 / 17.48
PLAN_K = 1368.0 / 17.48

# [JJ]'s six views: where each is on the sheet (rows, columns), and the other view's pixels that stray into its box.
VIEWS = {
    "side-aeroplane": ((0, 1100), (0, 1900)),
    "side-helicopter": ((0, 1100), (1900, 3840)),
    "front-aeroplane": ((1100, 2100), (0, 1930)),
    "front-helicopter": ((1100, 2100), (1880, 3840)),
    "plan-aeroplane": ((2100, 4304), (0, 1900)),
    "plan-helicopter": ((2100, 4304), (1900, 3840)),
}


def colour_mask(path, colour):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return np.abs(rgb - colour).sum(axis=2) < 120


def outline(mask):
    edge = mask & ~(np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))
    return edge | np.roll(edge, 1, 0) | np.roll(edge, 1, 1)


def grow(mask, n):
    for _ in range(n):
        mask = mask | np.roll(mask, 1, 0) | np.roll(mask, -1, 0) | np.roll(mask, 1, 1) | np.roll(mask, -1, 1)
    return mask


def paste(mask, shape, dy, dx):
    """`mask` moved by (dy, dx) onto a canvas of `shape`."""
    out = np.zeros(shape, dtype=bool)
    ys, xs = np.nonzero(mask)
    ys = ys + dy
    xs = xs + dx
    keep = (ys >= 0) & (ys < shape[0]) & (xs >= 0) & (xs < shape[1])
    out[ys[keep], xs[keep]] = True
    return out


def belly_row(mask, middle_col, k):
    """The lowest pixel within 0.8 m of a column: a front view's belly, below which only blades reach."""
    lo = int(middle_col - 0.8 * k)
    hi = int(middle_col + 0.8 * k)
    return max(np.nonzero(mask[:, c])[0].max() for c in range(lo, hi) if mask[:, c].any())


def datum(view, mask, k):
    """The view's alignment point in pixels (row, column), from the mask alone."""
    ys, xs = np.nonzero(mask)
    if view.startswith("side"):
        # THE FIN'S TRAILING EDGE (the tail end) and THE BELLY: the lowest pixel 5 to 11 m forward of the tail.
        tail = xs.max() if view.endswith("helicopter") else xs.min()
        sign = -1 if view.endswith("helicopter") else 1
        cols = [int(tail + sign * s * k) for s in np.arange(6.5, 12.0, 0.25)]
        belly = int(np.median([np.nonzero(mask[:, c])[0].max() for c in cols]))
        return belly, tail
    if view.startswith("front"):
        # THE CENTRELINE, the middle of the widest run 0.5 to 1.0 m over the belly, where only the sponsons are.
        first = belly_row(mask, (xs.min() + xs.max()) / 2.0, k)
        mids = []
        for r in range(int(first - 1.0 * k), int(first - 0.5 * k)):
            cols = np.nonzero(mask[r])[0]
            runs = measure_views.runs(cols)
            body = max(runs, key=lambda x: x[1] - x[0])
            mids.append((body[0] + body[1]) / 2.0)
        middle = float(np.median(mids))
        return belly_row(mask, middle, k), int(round(middle))
    # A PLAN: the tail's end, and the middle of the tail 0.3 to 1.5 m forward of it.
    tail = xs.min() if view.endswith("aeroplane") else xs.max()
    sign = 1 if view.endswith("aeroplane") else -1
    mids = []
    for s in np.arange(0.3, 1.5, 0.05):
        rows = np.nonzero(mask[:, int(tail + sign * s * k)])[0]
        mids.append((rows.min() + rows.max()) / 2.0)
    return int(round(float(np.median(mids)))), tail


def lay(view, sheet_gray, sheet_sil, number):
    (r0, r1), (c0, c1) = VIEWS[view]
    k = SIDE_K if view.startswith("side") else PLAN_K
    ref = sheet_sil[r0:r1, c0:c1].copy()
    gray = sheet_gray[r0:r1, c0:c1]
    stem = "osprey-%d-%s" % (number, view)
    mine = colour_mask(os.path.join(SHOTS, stem + ".png"), MAGENTA)
    discs = colour_mask(os.path.join(SHOTS, stem + "-discs.png"), BLUE)
    ry, rx = datum(view, ref, k)
    my, mx = datum(view, mine, k)
    mine = paste(mine, ref.shape, ry - my, rx - mx)
    discs = grow(paste(discs, ref.shape, ry - my, rx - mx), 4)
    whole = (ref & mine).sum() / float((ref | mine).sum())
    keep = ~discs
    outside = (ref & mine & keep).sum() / float(((ref | mine) & keep).sum())
    picture = np.stack([gray] * 3, axis=2).astype(float) * 0.55 + 255 * 0.45
    picture[discs] = picture[discs] * 0.7 + BLUE * 0.3
    picture[mine] = picture[mine] * 0.5 + MAGENTA * 0.5
    picture[outline(ref)] = [0, 0, 0]
    ys, xs = np.nonzero(ref | mine)
    crop = picture[max(ys.min() - 40, 0):ys.max() + 40, max(xs.min() - 40, 0):xs.max() + 40]
    os.makedirs(OUT, exist_ok=True)
    aligned = {"side": "tail-and-belly", "front": "centreline-and-belly", "plan": "tail-and-centreline"}[
        view.split("-")[0]]
    name = "cockpit-osprey-overlay-%s-on-%s-over-jetijones-cc-by-x1.000.png" % (view, aligned)
    Image.fromarray(crop.clip(0, 255).astype(np.uint8)).save(os.path.join(OUT, name))
    print("%-17s moved (%+d, %+d) px: agree over %.1f%% of the union, %.1f%% outside the discs" % (
        view, rx - mx, ry - my, 100.0 * whole, 100.0 * outside))
    return whole, outside


def main():
    gray = np.asarray(Image.open(os.path.join(FOLDER, "v22_line_3840.png")).convert("LA")).astype(int)
    g = 255 - ((255 - gray[:, :, 0]) * gray[:, :, 1] // 255)
    sil = ~measure_views.outside(g >= measure_views.WHITE)
    for number, view in enumerate(VIEWS, start=10):
        lay(view, g, sil, number)


if __name__ == "__main__":
    main()
