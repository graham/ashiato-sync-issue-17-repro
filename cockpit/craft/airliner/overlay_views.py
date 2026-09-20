"""Lays the 737-800W airframe's orthographic silhouettes over Boeing's general-dimensions drawing it was measured from, at
x1.000 -- no fitting.

    python cockpit/craft/airliner/overlay_views.py <folder of liners_shot's pictures> <out folder> [737|747] [research folder]

`tests/liners_shot.gd` renders the side, top and front silhouettes at the drawing's own 75.07 px a metre (2,963 px for the
printed 39.47 m, at 600 dpi), so the only thing left to choose is WHERE: each pair is aligned on a datum stated in the
filename -- the nose tip and the ground (the tyres' bottoms) in the side view, the nose tip and the centreline in the
plan, the centreline and the ground in the front. Both draw the gear down.

THE SIDE VIEW IS EXPECTED TO DISAGREE BY 0.25 m IN HEIGHT: the model's body is raised by that much over the drawing's to
meet Boeing's own ground-clearance table (`Boeing737Airframe`'s disagreement 2), and it is aligned on the ground so the
disagreement SHOWS rather than being fitted away. The share printed for it is therefore lower than the plan's.

Each picture shows the drawing in grey, the model's silhouette in magenta over it at half strength, and the drawing's own
outline in black on top, so a reader can see both edges. And each view prints its agreement as the share of the two
silhouettes' union that both cover (intersection over union), a number a later model can be held to.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import acaps  # noqa: E402

SHOTS = sys.argv[1]
OUT = sys.argv[2]
PLANE = sys.argv[3] if len(sys.argv) > 3 else "737"
RESEARCH = sys.argv[4] if len(sys.argv) > 4 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-19/cockpit-liners/research")
# Each aeroplane's ACAPS file and its general-dimensions page: the 737-800W's section 2.2.6, the 747-400's 2.2.1.
PDF, PAGE = {"737": ("737NG_REV_C.pdf", 34), "747": ("747-400_acaps.pdf", 30)}[PLANE]
PDF = os.path.join(RESEARCH, PDF)
PREFIX = "liners-" + PLANE
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


def lay(views, name, model_file, align, filename):
    ref = views[name]
    ink = views["ink"]
    mine = model_mask(os.path.join(SHOTS, model_file))
    ry, rx = np.nonzero(ref)
    my, mx = np.nonzero(mine)
    if align == "side":
        dx = rx.min() - mx.min()
        dy = int(round(views["side_ground"])) - 1 - my.max()
    elif align == "top":
        dx = rx.min() - mx.min()
        dy = int(round((ry.min() + ry.max()) / 2.0 - (my.min() + my.max()) / 2.0))
    else:
        dx = int(round((rx.min() + rx.max()) / 2.0 - (mx.min() + mx.max()) / 2.0))
        dy = int(round(views["front_ground"])) - 1 - my.max()
    mine = shifted(mine, dy, dx, ref.shape)
    both = (ref & mine).sum()
    union = (ref | mine).sum()
    picture = np.full(ref.shape + (3,), 255.0)
    picture[ref] = [190, 190, 190]
    picture[mine] = picture[mine] * 0.5 + MAGENTA * 0.5
    picture[outline(ref) | (ink & ref)] = [0, 0, 0]
    ys, xs = np.nonzero(ref | mine)
    crop = picture[max(ys.min() - 60, 0):ys.max() + 60, max(xs.min() - 60, 0):xs.max() + 60]
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(crop.clip(0, 255).astype(np.uint8)).save(os.path.join(OUT, filename))
    print("%-5s shifted (%+d, %+d) px; the two silhouettes agree over %.1f%% of their union (drawing %d px, model %d px)"
          % (name, dx, dy, 100.0 * both / union, ref.sum(), mine.sum()))


views = acaps.views(PDF, PAGE, 600)
lay(views, "side", PREFIX + "-07-side-at-drawing-scale.png", "side",
    "cockpit-%s-side-on-nose-tip-and-ground-over-boeing-acaps-x1.000.png" % PREFIX)
lay(views, "plan", PREFIX + "-08-top-at-drawing-scale.png", "top",
    "cockpit-%s-top-on-nose-tip-and-centreline-over-boeing-acaps-x1.000.png" % PREFIX)
lay(views, "front", PREFIX + "-09-front-at-drawing-scale.png", "front",
    "cockpit-%s-front-on-centreline-and-ground-over-boeing-acaps-x1.000.png" % PREFIX)
