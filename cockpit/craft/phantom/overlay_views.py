"""Lays the F-4E airframe's orthographic silhouettes over the technical order it was measured from, at x1.000.

    python cockpit/craft/phantom/overlay_views.py <folder of phantom_shot's pictures> <out folder> [the drawing png]

The same instrument nine other craft already use -- `tools/three_view.py` for the reference silhouettes,
`craft/lightning/overlay_views.py` for the shape: the model in magenta over the reference in grey with the
reference's own outline in black on top, aligned on a datum named in the filename, **shifted only and never
scaled**, and reporting agreement as the share of the two silhouettes' union that both cover.

THE DRAWING IS NOT IN THIS REPOSITORY. It is a public-domain USAF technical order held for study in
`~/godotgames-drafts/2026-09-19/phantom/research/`, with its licence table beside it.

THE ONE THING THIS SHEET NEEDS THAT THE OTHER NINE DID NOT: **its three views do not share a scale.** The
JSF renders the F-35B was measured off share a camera, so `lightning_shot.gd` renders all three views at one
px-per-metre. Here the side view is 100.42 px/m, the plan 100.26 along and the front 101.54, each off a
figure printed on that view. `phantom_shot.gd` therefore renders each view at ITS OWN scale, and each
picture carries that scale in its name. A single constant would have reported 1.3 per cent of disagreement
on the front view that belongs to the PAPER rather than to the model.

AND THE PLAN VIEW CANNOT BE MATCHED ON BOTH AXES AT ONCE. The sheet is stretched about one per cent ALONG
the aeroplane -- two spanwise readings agreeing to the second decimal while two lengthwise readings sit one
per cent away -- and an orthographic render is isotropic by construction. The plan is rendered at the along
scale, so it reads about 0.8 per cent WIDE across. **That residual is the finding, not a fault**, and it is
printed separately from the agreement so nobody scales it away.

THIS IS THE INSTRUMENT THAT FOUND THIS LANE'S WORST BUG. Fifteen headless checks were green on an aeroplane
drawn half a metre too flat, because the drawing carries two long level lines over the fuselage -- at 3.33
and 3.28 m -- which this lane took for the page's own construction lines and masked out before reading the
top of the body. What was left underneath was a panel line at about 2.75. Not one dimension check knows
where the top of a fuselage is.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools")))
import three_view  # noqa: E402

MAGENTA = np.array([209, 41, 140])
INK = 128

# EACH VIEW'S OWN SCALE, off a figure printed on that view (`measure_manual.py`).
SCALE = {"side": 713.0 / 7.09, "top": 1925.0 / 19.2, "front": 1189.0 / 11.71}

# WHERE EACH VIEW IS ON THE SHEET (row0, row1, col0, col1), a seed inside the aeroplane, and the straight
# lines to erase before the fill -- dimension rules, extension lines and the two CONSTRUCTION LINES that
# lie ACROSS the fuselage at 3.33 and 3.28 m. Those two touch the outline, so a fill would leak through
# them; they are taken out here rather than masked, which is the mistake that cost this lane half a metre.
VIEWS = {
    # A CUT MUST NOT RUN PAST THE LINE IT IS ERASING. The first version swept the 3.33 m construction
    # line across the whole page and SAWED THE FIN IN HALF, so the fill -- seeded in the fuselage --
    # could not reach anything above row 164 and the reference silhouette came back 321 px tall for a
    # 500 px aeroplane. Agreement read 57.6 per cent and every bit of the shortfall was the
    # instrument. Each cut is now bounded to the extent the line was MEASURED at.
    "side":  dict(box=(0, 500, 20, 2008), seed=(300, 900), close=3,
                  cuts=[((162, 300), (162, 712)),      # the 3.33 m construction line, x 308..707
                        ((166, 803), (172, 1556)),     # the 3.28 m construction line, x 809..1550
                        ((492, 25), (485, 2000)),      # the ground line
                        ((160, 51), (498, 51))]),      # the 3.33 m rule, ahead of the nose
    "top":   dict(box=(1240, 2436, 40, 1992), seed=(1841, 900), close=2,
                  cuts=[((1843, 58), (2463, 58)),      # the nose extension line, standing ON the nose tip
                        ((1827, 1981), (2480, 1981)),  # the tail extension line
                        ((1596, 1960), (1596, 2060)),  # the 5.0 m rule's two extension lines
                        ((2081, 1960), (2081, 2060))]),
    "front": dict(box=(645, 1158, 420, 1758), seed=(1000, 1128), close=2,
                  cuts=[((566, 530), (566, 1725)),     # the 11.71 m rule
                        ((639, 715), (639, 1545)),     # the 8.41 m rule
                        ((1163, 360), (1160, 1755)),   # the ground line
                        ((820, 411), (1165, 411)),     # the 3.45 m rule
                        ((1070, 1768), (1165, 1768))]),
}


def reference(sheet, view):
    """The drawing's own silhouette for one view, by `three_view.solid` -- the shared library's fill."""
    spec = VIEWS[view]
    ink = np.asarray(Image.open(sheet).convert("L")) < INK
    for start, end in spec["cuts"]:
        three_view.take_out(ink, start, end, keep=0, width=3.0)
    shape, _parts = three_view.solid(ink, spec["box"], spec["seed"], close=spec["close"])
    full = np.zeros_like(ink)
    r0, r1, c0, c1 = spec["box"]
    full[r0:r1, c0:c1] = shape
    return full


def model(path):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return np.abs(rgb - MAGENTA).sum(axis=2) < 120


def shifted(mask, into, dy, dx):
    out = np.zeros(into, bool)
    ys, xs = np.nonzero(mask)
    ys, xs = ys + dy, xs + dx
    keep = (ys >= 0) & (ys < into[0]) & (xs >= 0) & (xs < into[1])
    out[ys[keep], xs[keep]] = True
    return out


def outline(mask):
    edge = mask & ~(np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))
    return edge | np.roll(edge, 1, 0) | np.roll(edge, 1, 1)


def lay(view, sheet, shot, out_dir, filename, datum):
    ref = reference(sheet, view)
    mine = model(shot)
    ry, rx = np.nonzero(ref)
    my, mx = np.nonzero(mine)
    if view == "side":
        dx, dy = rx.min() - mx.min(), ry.max() - my.max()          # nose tip and the ground line
    elif view == "top":
        dx = rx.min() - mx.min()                                   # nose tip
        dy = int(round((ry.min() + ry.max()) / 2.0 - (my.min() + my.max()) / 2.0))   # and the centreline
    else:
        dx = int(round((rx.min() + rx.max()) / 2.0 - (mx.min() + mx.max()) / 2.0))   # centreline
        dy = ry.max() - my.max()                                   # and the ground line
    mine = shifted(mine, ref.shape, dy, dx)
    both, union = int((ref & mine).sum()), int((ref | mine).sum())

    grey = np.asarray(Image.open(sheet).convert("RGB")).astype(float)
    picture = grey * 0.55 + 255 * 0.45
    picture[mine] = picture[mine] * 0.5 + MAGENTA * 0.5
    picture[outline(ref)] = [0, 0, 0]
    ys, xs = np.nonzero(ref | mine)
    crop = picture[max(ys.min() - 50, 0):ys.max() + 50, max(xs.min() - 50, 0):xs.max() + 50]
    os.makedirs(out_dir, exist_ok=True)
    Image.fromarray(crop.clip(0, 255).astype(np.uint8)).save(os.path.join(out_dir, filename))

    scale = SCALE[view]
    print("%-5s at %6.2f px/m, on %s: shifted (%+d, %+d) px, NEVER scaled."
          % (view, scale, datum, dx, dy))
    print("      the two silhouettes agree over %.1f%% of their union (drawing %d px, model %d px)"
          % (100.0 * both / union, ref.sum(), mine.sum()))
    print("      extents: drawing %d x %d px, model %d x %d px  ->  %+.2f%% along, %+.2f%% across"
          % (rx.ptp() if hasattr(rx, "ptp") else rx.max() - rx.min(), ry.max() - ry.min(),
             mx.max() - mx.min(), my.max() - my.min(),
             100.0 * ((mx.max() - mx.min()) / float(rx.max() - rx.min()) - 1.0),
             100.0 * ((my.max() - my.min()) / float(ry.max() - ry.min()) - 1.0)))
    if view == "top":
        print("      the ACROSS figure is the SHEET's one per cent stretch along the aeroplane, not the model's")
    return 100.0 * both / union


def main(shots, out_dir, sheet=None):
    sheet = sheet or os.path.expanduser(
        "~/Desktop/godotgames-drafts/2026-09-19/phantom/research/f4e_manual_3view.png")
    worst = 100.0
    for view, shot, filename, datum in [
        ("side", "phantom-10-side-at-100.42-px-per-m.png",
         "cockpit-phantom-side-on-nose-tip-and-ground-over-technical-order-x1.000.png",
         "the nose tip and the ground line"),
        ("top", "phantom-11-top-at-100.26-px-per-m.png",
         "cockpit-phantom-top-on-nose-tip-and-centreline-over-technical-order-x1.000.png",
         "the nose tip and the centreline"),
        ("front", "phantom-12-front-at-101.54-px-per-m.png",
         "cockpit-phantom-front-on-centreline-and-ground-over-technical-order-x1.000.png",
         "the centreline and the ground line"),
    ]:
        worst = min(worst, lay(view, sheet, os.path.join(shots, shot), out_dir, filename, datum))
    print("\nworst agreement over the three views: %.1f%% of the union" % worst)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    main(*sys.argv[1:4])
