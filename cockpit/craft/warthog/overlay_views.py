"""Lays the A-10C airframe's orthographic silhouettes over the three-view it was measured from, at x1.000 -- no fitting.

    python cockpit/craft/warthog/overlay_views.py <folder of warthog_shot's pictures> <out folder> [research folder]

`tests/warthog_shot.gd` renders the side, top and front silhouettes at the drawing's own 199.83 px a metre (3,503 px for
the published span, the x3 raster), gear UP as the drawing draws it, so the only thing left to choose is WHERE: each
pair is aligned on a datum stated in the filename -- the muzzle and the lowest point in the side view, the muzzle and the
centreline in plan, the centreline and the fin tips from the front (see `lay`).

Each picture shows the drawing in grey, the model's silhouette in magenta over it at half strength, and the drawing's
outline in black on top, so a reader can see both edges. Each view prints its agreement as the share of the two
silhouettes' union that both cover (intersection over union), a number a later model can be held to.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_views  # noqa: E402

SHOTS = sys.argv[1]
OUT = sys.argv[2]
# measure_views read its own folder from OUR first argument when it was imported; say which folder is meant.
measure_views.FOLDER = sys.argv[3] if len(sys.argv) > 3 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-19/cockpit-warthog/research")
MAGENTA = np.array([209, 41, 140])


def model_mask(path):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return (np.abs(rgb - MAGENTA).sum(axis=2) < 120), rgb


def placed(mask, shape, dy, dx):
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


def lay(name, model_file, filename):
    rgb, ref = measure_views.view(name)
    mine, _ = model_mask(os.path.join(SHOTS, model_file))
    ry, rx = np.nonzero(ref)
    my, mx = np.nonzero(mine)
    if name == "Side":
        dx = rx.max() - mx.max()
        dy = ry.max() - my.max()
    elif name == "Top":
        dx = rx.max() - mx.max()
        dy = int(round((ry.min() + ry.max()) / 2.0 - (my.min() + my.max()) / 2.0))
    else:
        # THE FRONT VIEW ON THE FIN TIPS, not its lowest point: [K]'s front view draws the main wheels inside their pods
        # (the lowest point 3.30 m under the fin tips) while its side view has them 0.36 m out of the pods' bottoms (3.62
        # m under). The two views of the drawing disagree there; the heights the model takes from the front view were
        # read on the fin tip, which both views agree on, so that is the datum the front is laid on too.
        dx = int(round((rx.min() + rx.max()) / 2.0 - (mx.min() + mx.max()) / 2.0))
        dy = ry.min() - my.min()
    mine = placed(mine, ref.shape, dy, dx)
    both = (ref & mine).sum()
    union = (ref | mine).sum()
    grey = np.stack([rgb.mean(axis=2)] * 3, axis=2)
    picture = grey * 0.55 + 255 * 0.45
    picture[mine] = picture[mine] * 0.5 + MAGENTA * 0.5
    picture[outline(ref)] = [0, 0, 0]
    ys, xs = np.nonzero(ref | mine)
    crop = picture[max(ys.min() - 60, 0):ys.max() + 60, max(xs.min() - 60, 0):xs.max() + 60]
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(crop.clip(0, 255).astype(np.uint8)).save(os.path.join(OUT, filename))
    print("%-5s shifted (%+d, %+d) px; the two silhouettes agree over %.1f%% of their union (drawing %d px, model %d px)"
          % (name, dx, dy, 100.0 * both / union, ref.sum(), mine.sum()))


lay("Side", "warthog-20-side-at-drawing-scale.png",
    "cockpit-warthog-side-on-muzzle-and-lowest-point-over-kaboldy-3-view-x1.000.png")
lay("Top", "warthog-21-top-at-drawing-scale.png",
    "cockpit-warthog-top-on-muzzle-and-centreline-over-kaboldy-3-view-x1.000.png")
lay("Front", "warthog-22-front-at-drawing-scale.png",
    "cockpit-warthog-front-on-centreline-and-fin-tips-over-kaboldy-3-view-x1.000.png")
