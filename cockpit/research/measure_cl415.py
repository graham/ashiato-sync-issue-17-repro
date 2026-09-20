"""Screen Wikimedia Commons photographs of a Canadair CL-415 for one that can be MEASURED.

Run from the repository root with the candidate images in a scratch directory:

    python cockpit/research/measure_cl415.py <directory holding kept.json and the images>

WHAT THIS IS FOR. `cockpit/craft/tanker/sources.md` says the water bomber's overall envelope is
measured from De Havilland's published figures and its fuselage SECTIONS are not -- they were
written by eye. Re-lofting them wants a true broadside or a stated-scale drawing
(`modelling_here.md`). This is the search for one, and its answer, and it re-derives every number
below from the images alone so the next person does not have to take any of it on trust.

WHAT IT MEASURES, AND WHAT THAT IS WORTH. It segments the airframe from its background by colour
-- every CL-415 in service is painted in high-visibility yellow, orange or red against grass,
tarmac, water or sky -- and reports the silhouette's bounding box and how much of that box the
aeroplane fills.

THE SCREEN IS THE ASPECT RATIO, AND IT IS A SCREEN AND NOT A PROOF. A CL-415 photographed
squarely from the side draws a silhouette 19.82 m long and 8.98 m tall over the gear, so its box
is 2.21 wide for 1 tall. Yaw the aeroplane and that number RISES, because the 28.6 m wing starts
projecting into the horizontal: at 20 degrees off, the wing alone spans 9.8 m across the view and
the silhouette is half as wide again as the fuselage that is supposed to be setting its length.
So a candidate near 2.21 MAY be a broadside and one well above it certainly is not. It cannot
prove the good case, because a wing seen edge-on and a wing seen at 20 degrees from a camera that
is also 20 degrees high can trade against each other, and this measures neither angle.

**A CHEAP SCREEN THAT ONLY RULES THINGS OUT IS STILL WORTH WRITING**, because the alternative is
looking at sixty-nine photographs by eye and writing down an impression. What it cannot do is
license the answer, which is why its output is a shortlist and this file does not pretend to hand
back a loft.
"""
import io
import json
import os
import sys

import numpy as np
from PIL import Image

## A CL-415 SQUARELY FROM THE SIDE. 19.82 m long over 8.98 m tall on its gear -- Canadair's
## published figures for the type, and the DHC-515 sheet in craft/tanker/sources.md gives
## 19.8 by 9.02, which is the same aeroplane to within a fifth of a per cent.
BROADSIDE_ASPECT = 19.82 / 8.98

## HOW SATURATED AND HOW BRIGHT A PIXEL HAS TO BE to be paint rather than scenery. These are
## generous on purpose: the screen's job is to find the aeroplane's extent, and a few hundred
## stray pixels of a yellow tow tractor cost less than missing a shadowed tailcone.
PAINT_SATURATION = 0.34
PAINT_VALUE = 0.28
## Hues counted as firefighting paint, as fractions of the wheel: red through orange to yellow.
PAINT_HUE_LOW, PAINT_HUE_HIGH = 0.95, 0.20
## How much of a row or column has to be paint before it counts towards the silhouette, as a
## share of the largest such count. Rejects isolated specks without eroding a thin tailcone.
EDGE_SHARE = 0.06


def silhouette(path):
    """The painted airframe's bounding box, and how much of it is paint."""
    with Image.open(path) as opened:
        image = opened.convert("RGB")
        image.thumbnail((1600, 1600))
        pixels = np.asarray(image).astype(np.float32) / 255.0
    high = pixels.max(axis=2)
    low = pixels.min(axis=2)
    value = high
    span = high - low
    saturation = np.where(high > 0.0, span / np.maximum(high, 1e-6), 0.0)
    red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
    hue = np.zeros_like(high)
    safe = span > 1e-6
    is_red = safe & (high == red)
    is_green = safe & (high == green)
    is_blue = safe & (high == blue)
    hue[is_red] = ((green - blue)[is_red] / span[is_red]) % 6.0
    hue[is_green] = ((blue - red)[is_green] / span[is_green]) + 2.0
    hue[is_blue] = ((red - green)[is_blue] / span[is_blue]) + 4.0
    hue = hue / 6.0
    warm = (hue >= PAINT_HUE_LOW) | (hue <= PAINT_HUE_HIGH)
    paint = warm & (saturation >= PAINT_SATURATION) & (value >= PAINT_VALUE)
    if paint.sum() < 500:
        return None
    columns = paint.sum(axis=0)
    rows = paint.sum(axis=1)
    keep_x = np.nonzero(columns >= max(1.0, columns.max() * EDGE_SHARE))[0]
    keep_y = np.nonzero(rows >= max(1.0, rows.max() * EDGE_SHARE))[0]
    if keep_x.size < 2 or keep_y.size < 2:
        return None
    wide = float(keep_x[-1] - keep_x[0] + 1)
    tall = float(keep_y[-1] - keep_y[0] + 1)
    inside = paint[keep_y[0]:keep_y[-1] + 1, keep_x[0]:keep_x[-1] + 1]
    return {
        "wide_px": wide,
        "tall_px": tall,
        "aspect": wide / tall,
        "fill": float(inside.mean()),
        "paint_px": int(paint.sum()),
        "image_wide": int(paint.shape[1]),
        "image_tall": int(paint.shape[0]),
    }


def main(folder):
    kept = json.load(io.open(os.path.join(folder, "kept.json"), encoding="utf-8"))
    measured = []
    for row in kept:
        path = os.path.join(folder, row["file"])
        if not os.path.exists(path):
            continue
        shape = silhouette(path)
        if shape is None:
            continue
        shape["excess"] = shape["aspect"] / BROADSIDE_ASPECT
        row.update(shape)
        measured.append(row)
    measured.sort(key=lambda r: abs(r["excess"] - 1.0))
    print("a true broadside draws %.2f wide for 1 tall (19.82 m over 8.98 m)" % BROADSIDE_ASPECT)
    print("%-8s %7s %7s %6s %6s  %s" % ("file", "wide", "tall", "aspect", "x2.21", "title"))
    for row in measured:
        print("%-8s %7.0f %7.0f %6.2f %6.2f  %s" % (
            row["file"], row["wide_px"], row["tall_px"], row["aspect"], row["excess"],
            row["title"][5:58]))
    io.open(os.path.join(folder, "measured.json"), "w", encoding="utf-8").write(
        json.dumps(measured, indent=1, ensure_ascii=False))
    return measured


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
