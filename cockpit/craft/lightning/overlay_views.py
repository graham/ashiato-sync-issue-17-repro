"""Lays the F-35B airframe's orthographic silhouettes over the JSF renders it was measured from, at x1.000 -- no fitting.

    python cockpit/craft/lightning/overlay_views.py <folder of lightning_shot's pictures> <out folder> [research folder]

`tests/lightning_shot.gd` renders the side, top and front silhouettes at the renders' own 178.88 px a metre (1,914 px for
the published span), so the only thing left to choose is WHERE: each pair is aligned on a datum stated in the filename --
the nose tip and the belly datum in the side view, the nose tip and the centreline in the plan, the centreline and the
belly datum in the front. The renders draw the gear up, and so do the silhouettes.

Each picture shows the render in grey, the model's silhouette in magenta over it at half strength, and the render's own
outline in black on top, so a reader can see both edges. And each view prints its agreement as the share of the two
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
    "~/godotgames-drafts/2026-09-18/cockpit-lightning/research")
MAGENTA = np.array([209, 41, 140])


def model_mask(path):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return (np.abs(rgb - MAGENTA).sum(axis=2) < 120), rgb


def shifted(mask, dy, dx):
    out = np.zeros_like(mask)
    h, w = mask.shape
    ys, xs = np.nonzero(mask)
    ys = ys + dy
    xs = xs + dx
    keep = (ys >= 0) & (ys < h) & (xs >= 0) & (xs < w)
    out[ys[keep], xs[keep]] = True
    return out


def outline(mask):
    edge = mask & ~(np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))
    grown = edge | np.roll(edge, 1, 0) | np.roll(edge, 1, 1)
    return grown


def lay(name, render, model_file, align, filename):
    rgb, ref = measure_views.view(render)
    mine, _ = model_mask(os.path.join(SHOTS, model_file))
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
    mine = shifted(mine, dy, dx)
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
    print("%-5s shifted (%+d, %+d) px; the two silhouettes agree over %.1f%% of their union (render %d px, model %d px)"
          % (name, dx, dy, 100.0 * both / union, ref.sum(), mine.sum()))


lay("side", "Side", "lightning-09-side-at-jsf-scale.png", "side",
    "cockpit-lightning-side-on-nose-tip-and-belly-over-jsf-render-x1.000.png")
lay("top", "Top", "lightning-10-top-at-jsf-scale.png", "top",
    "cockpit-lightning-top-on-nose-tip-and-centreline-over-jsf-render-x1.000.png")
lay("front", "Front", "lightning-11-front-at-jsf-scale.png", "front",
    "cockpit-lightning-front-on-centreline-and-belly-over-jsf-render-x1.000.png")
