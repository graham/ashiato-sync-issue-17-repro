"""Lay the drawn Cessna 310R over the 1967 factory three-view at x1.000.

Run it in this folder with the drawing and the renders beside it:

    python overlay_views.py --shots <folder>

`<folder>` is what `tests/twin310_shot.tscn -- --out=<folder>` wrote: `cockpit-twin310-side-*.png`,
`-front-*` and `-top-*`, rendered orthographically on white. This script reads each render's own
pixels-a-metre out of the shot log it is given, or takes `--px` per view, scales the render to the
DRAWING's own pixels-a-metre for that view, aligns it on a named datum and writes the overlay with
the datum and the scale in its filename -- which is the whole point: a reader can dispute a picture
that says what it is aligned on, and cannot dispute "it looks right".

WHAT CAN AND CANNOT BE OVERLAID, and it is stated here rather than quietly fudged:

  * THE FRONT VIEW OVERLAYS DIRECTLY. The 310L and the 310R have the same wing, the same tip tanks
    (51 US gal at arm +35 in on both, [TCDS]) and the same gear, so this is a true x1.000 comparison
    and the strongest evidence on the page.
  * THE SIDE AND PLAN VIEWS ARE ALIGNED ON THE WING'S LEADING EDGE AT THE ROOT, not on the nose,
    because the R is 0.748 m longer than the L and all of that is ahead of the firewall. Aligning
    them on the nose would make the whole aeroplane look 8 per cent short of its own drawing.
    Everything AFT of that datum should line up; everything forward of it should not, by exactly
    the plug.
"""

import argparse
import io
import os
import sys

import numpy as np
from PIL import Image

FOOT = 0.3048

# The drawing's own scales, as craft/plane/measure_310l.py derives them.
DRAWING = {
    "side": {"px_per_m": 81.802, "origin": (234.87, 380.29)},   # (nose tip x, mains' contact y)
    "front": {"px_per_m": 80.705, "origin": (684.50, 1672.0)},  # (axis x, mains' pads y)
    "top": {"px_per_m": 80.654, "origin": (525.60, 1266.0)},    # (axis x, nose tip y); see below
}
# The plan view's fore-and-aft scale is its own, 1.35 per cent from its across scale.
TOP_FORE_AFT = 81.743

# Where each view's datum sits on the MODEL, in metres from the nose tip and over the mains'
# contact plane. These are the airframe's own constants, and the overlay says which it used.
L_LENGTH = 8.9916
NOSE_PLUG = 9.74 - L_LENGTH
WING_LE_ROOT_R = 2.948          # Cessna310Airframe.WING_LE_ROOT, R frame
WING_LE_ROOT_L = WING_LE_ROOT_R - NOSE_PLUG


def load_grey(path):
    return np.array(Image.open(path).convert("L")).astype(np.int16)


def ink_mask(a, threshold):
    return a < threshold


def trim(mask):
    """The bounding box of the drawn thing, as (x0, y0, x1, y1)."""
    cols = np.nonzero(mask.any(0))[0]
    rows = np.nonzero(mask.any(1))[0]
    if len(cols) == 0 or len(rows) == 0:
        sys.exit("nothing drawn in that render")
    return int(cols.min()), int(rows.min()), int(cols.max()), int(rows.max())


def find(folder, view):
    for name in sorted(os.listdir(folder)):
        if name.startswith("cockpit-twin310-%s-" % view) and name.endswith(".png"):
            return os.path.join(folder, name)
    return None


def overlay(drawing_path, shot_path, view, px_per_m, out_dir, note):
    page = Image.open(drawing_path).convert("RGB")
    shot = Image.open(shot_path).convert("L")
    want = DRAWING[view]["px_per_m"]
    scale = want / px_per_m
    wide = max(1, int(round(shot.width * scale)))
    tall = max(1, int(round(shot.height * scale)))
    shot = shot.resize((wide, tall), Image.LANCZOS)
    mask = ink_mask(np.array(shot).astype(np.int16), 235)
    x0, y0, x1, y1 = trim(mask)

    # The model's own datum, in the resized render's pixels. The render is orthographic and
    # centred on the aeroplane, so the datum is found from the render's bounding box and the
    # airframe's known extent rather than from a hand-picked pixel.
    if view == "front":
        model_x = (x0 + x1) * 0.5
        model_y = y1                      # the tyres, which stand on the ground
        page_x, page_y = DRAWING["front"]["origin"]
        datum = "the centreline and the main tyres"
    elif view == "side":
        # The render runs nose (left) to fin (right) with the tyres at the bottom.
        model_x = x0 + (WING_LE_ROOT_R / 9.74) * (x1 - x0)
        model_y = y1
        page_x = DRAWING["side"]["origin"][0] + WING_LE_ROOT_L * want
        page_y = DRAWING["side"]["origin"][1]
        datum = "the wing root leading edge and the main tyres"
    else:
        # The plan render points up the frame; the drawing's plan points DOWN it, so the render
        # is turned through 180 degrees before anything is measured.
        shot = shot.rotate(180, expand=True)
        mask = ink_mask(np.array(shot).astype(np.int16), 235)
        x0, y0, x1, y1 = trim(mask)
        model_x = (x0 + x1) * 0.5
        model_y = y0 + (WING_LE_ROOT_R / 9.74) * (y1 - y0)
        page_x = DRAWING["top"]["origin"][0]
        page_y = DRAWING["top"]["origin"][1] - WING_LE_ROOT_L * TOP_FORE_AFT
        datum = "the axis and the wing root leading edge"

    tint = Image.new("RGB", shot.size, (200, 30, 30))
    alpha = Image.fromarray((mask * 150).astype(np.uint8), mode="L")
    at = (int(round(page_x - model_x)), int(round(page_y - model_y)))
    page.paste(tint, at, alpha)
    name = "cockpit-twin310-%s-on-%s-over-310L-x1.000.png" % (view, datum.split(" and ")[0].replace(" ", "-"))
    page.save(os.path.join(out_dir, name))
    print("  %-6s scaled x%.4f to %.3f px/m, aligned on %s -> %s"
          % (view, scale, want, datum, name))
    if note:
        print("         %s" % note)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--shots", required=True)
    parser.add_argument("--drawing", default="cessna_310L_3view.png")
    parser.add_argument("--out", default=".")
    parser.add_argument("--side-px", type=float, required=True)
    parser.add_argument("--front-px", type=float, required=True)
    parser.add_argument("--top-px", type=float, required=True)
    args = parser.parse_args()
    drawing = args.drawing
    if not os.path.exists(drawing):
        drawing = os.path.expanduser(
            "~/godotgames-drafts/2026-09-19/cockpit-twin310/research/cessna_310L_3view.png")
    os.makedirs(args.out, exist_ok=True)
    print("the drawn 310R over the 1967 310L sheet, at the sheet's own scale per view:")
    overlay(drawing, find(args.shots, "front"), "front", args.front_px, args.out,
            "the L and the R share this view: same wing, same tanks, same gear [TCDS]")
    overlay(drawing, find(args.shots, "side"), "side", args.side_px, args.out,
            "ahead of the datum the R is %.3f m longer than the L, and should not line up" % NOSE_PLUG)
    overlay(drawing, find(args.shots, "top"), "top", args.top_px, args.out,
            "the same plug applies; the plan's fore-and-aft scale is its own, %.3f px/m" % TOP_FORE_AFT)


if __name__ == "__main__":
    main()
