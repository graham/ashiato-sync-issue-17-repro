"""Lays the C-130's orthographic silhouettes, STRETCHED to the J-30 Lockheed Martin draws, over Lockheed's General
Arrangement at x1.000 -- no fitting.

    python cockpit/craft/gunship/overlay_views.py <folder of liners_shot's pictures> <out folder> [c130|ac130] [pdf]

`tests/liners_shot.gd` renders `HerculesAirframe` with `stretched` set -- the H with the J-30's two plugs put back -- at
each view's own scale (`measure_views.py`: the plan 75.618 px a metre at 1200 dpi, the side and front 82.106), so what
is left to choose is WHERE: the nose tip and the tyres' bottoms in the side view, the nose tip and the centreline in the
plan, the centreline and the tyres in the front. The front's wing is drawn 9 per cent short (`sources.md`), and the
front's share says so.

The picture: the drawing grey, the model magenta over it at half strength, the drawing's outline black. Each view prints
the share of the two silhouettes' union that both cover.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
# THIS FOLDER FIRST: the 737's `measure_views` is in `craft/airliner`, beside the `acaps` this one's needs.
sys.path.insert(0, os.path.join(HERE, "..", "airliner"))
sys.path.insert(0, HERE)
SHOTS = sys.argv[1]
OUT = sys.argv[2]
PLANE = sys.argv[3] if len(sys.argv) > 3 else "ac130"
PREFIX = "liners-" + PLANE
sys.argv = [sys.argv[0]] + sys.argv[4:5]
import measure_views  # noqa: E402

MAGENTA = np.array([209, 41, 140])


def model_mask(path):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return np.abs(rgb - MAGENTA).sum(axis=2) < 120


def shifted(mask, dy, dx, shape):
    out = np.zeros(shape, dtype=bool)
    ys, xs = np.nonzero(mask)
    ys = ys + dy
    xs = xs + dx
    keep = (ys >= 0) & (ys < shape[0]) & (xs >= 0) & (xs < shape[1])
    out[ys[keep], xs[keep]] = True
    return out


def outline(mask):
    edge = mask & ~(np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))
    return edge | np.roll(edge, 1, 0) | np.roll(edge, 1, 1)


def lay(ref, name, model_file, align, filename):
    mine = model_mask(os.path.join(SHOTS, model_file))
    ry, rx = np.nonzero(ref)
    my, mx = np.nonzero(mine)
    if align == "side":
        dx = rx.min() - mx.min()
        dy = ry.max() - my.max()
    elif align == "top":
        dx = rx.min() - mx.min()
        dy = int(round((ry.min() + ry.max()) / 2.0 - (my.min() + my.max()) / 2.0))
    else:
        dx = int(round((rx.min() + rx.max()) / 2.0 - (mx.min() + mx.max()) / 2.0))
        dy = ry.max() - my.max()
    mine = shifted(mine, dy, dx, ref.shape)
    both = (ref & mine).sum()
    union = (ref | mine).sum()
    picture = np.full(ref.shape + (3,), 255.0)
    picture[ref] = [190, 190, 190]
    picture[mine] = picture[mine] * 0.5 + MAGENTA * 0.5
    picture[outline(ref)] = [0, 0, 0]
    ys, xs = np.nonzero(ref | mine)
    crop = picture[max(ys.min() - 60, 0):ys.max() + 60, max(xs.min() - 60, 0):xs.max() + 60]
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(crop.clip(0, 255).astype(np.uint8)).save(os.path.join(OUT, filename))
    print("%-5s shifted (%+d, %+d) px; the two silhouettes agree over %.1f%% of their union (drawing %d px, model %d px)"
          % (name, dx, dy, 100.0 * both / union, ref.sum(), mine.sum()))


ink, plan, side, front = measure_views.views()
lay(side, "side", PREFIX + "-07-side-at-drawing-scale.png", "side",
    "cockpit-%s-stretched-to-j30-side-on-nose-tip-and-tyres-over-lockheed-ga-x1.000.png" % PREFIX)
lay(plan, "plan", PREFIX + "-08-top-at-drawing-scale.png", "top",
    "cockpit-%s-stretched-to-j30-top-on-nose-tip-and-centreline-over-lockheed-ga-x1.000.png" % PREFIX)
lay(front, "front", PREFIX + "-09-front-at-drawing-scale.png", "front",
    "cockpit-%s-stretched-to-j30-front-on-centreline-and-tyres-over-lockheed-ga-x1.000.png" % PREFIX)
