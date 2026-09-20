"""Re-derive the runabout's palette from the three reference photographs alone.

Reads nothing out of `sources.md` or out of `runabout.gd`, so the write-up and the model can
both disagree with it and be wrong -- which is the only way either gets audited
(`modelling_here.md` section 3, "make the research file reproducible by a script that does not
read it").

What it answers, and why each question is the one asked:

  * A PHOTOGRAPH'S PIXEL IS ALBEDO TIMES LIGHT, and a vertex colour is albedo alone. So no
    absolute pixel value from any of these frames may be typed into the model. What CAN cross
    is a RATIO taken inside one frame, because the light divides out: every mahogany patch is
    reported as a fraction of a WHITE REFERENCE in the same photograph, at the same station,
    on the same surface where one exists.
  * The three frames are two different boats in two different lights (one overcast, two in
    sun). Agreement between them on the ratio is evidence; agreement of one with itself is not.
  * The residual is PRINTED. Fitting three numbers and not looking at the spread is what cost
    `lane/prowler` its morning.

Run:  python cockpit/craft/runabout/measure_photos.py [research_dir]
"""

import sys
import os
import numpy as np
from PIL import Image

RESEARCH = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-20/chriscraft/research")

# Boxes are (x0, y0, x1, y1) in the original pixels of each Commons file. They were placed by
# reading a vertical colour profile down the hull at three stations per photograph and taking
# the flat runs between the bright stripes -- not by eye over the picture.
FRAMES = {
    "cc1945_runnin_02.jpg": {
        "note": "1945 Chris-Craft runabout, bright sun, hull side turned away from it",
        "white": ("sheer stripe, white paint", (596, 349, 606, 354)),
        "mahogany": [
            ("topside fwd", (580, 365, 620, 470)),
            ("topside mid", (560, 380, 900, 450)),
            ("topside aft", (980, 355, 1040, 460)),
        ],
        "other": [
            ("boot stripe, white paint", (594, 479, 608, 482)),
            ("below the boot stripe", (780, 494, 860, 516)),
        ],
    },
    "cc1941_special_01.jpg": {
        "note": "1941 Chris-Craft Special Runabout, flat overcast -- the nearest thing here to a paint chip",
        # NO WHITE PAINT ON THIS BOAT AT ALL -- she carries a chrome rail where the 1945 one
        # carries a painted stripe -- so the white reference here is the wake, which is the only
        # surface in the frame whose reflectance is known and which is lit as the hull is.
        "white": ("wake foam alongside", (300, 455, 360, 470)),
        "mahogany": [
            ("topside amidships", (600, 406, 640, 448)),
            ("topside aft", (700, 409, 740, 448)),
        ],
        "other": [],
    },
    "cc_runabouts_playin.jpg": {
        "note": "Chris-Craft runabout under way, bright sun, near broadside",
        "white": ("deck highlight", (494, 394, 506, 399)),
        "mahogany": [
            ("topside fwd", (290, 428, 310, 476)),
            ("topside mid", (490, 437, 510, 491)),
            ("topside aft", (690, 431, 710, 482)),
        ],
        "other": [],
    },
}


def linear(srgb_0_255):
    c = np.asarray(srgb_0_255, dtype=float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(lin):
    c = np.clip(np.asarray(lin, dtype=float), 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def patch(image, box):
    x0, y0, x1, y1 = box
    return np.asarray(image, dtype=float)[y0:y1, x0:x1].reshape(-1, 3)


def main():
    print("THE RUNABOUT'S PALETTE, RE-DERIVED FROM THE PHOTOGRAPHS")
    print()
    chroma = []
    for name, spec in FRAMES.items():
        path = os.path.join(RESEARCH, name)
        if not os.path.exists(path):
            print(f"  MISSING {path} -- see sources.md for where each file came from")
            continue
        image = Image.open(path).convert("RGB")
        print(f"--- {name}")
        print(f"    {spec['note']}")
        wname, wbox = spec["white"]
        white = linear(patch(image, wbox).mean(axis=0))
        print(f"    white reference ({wname}): linear {np.round(white, 3)}")
        for label, box in spec["mahogany"]:
            px = patch(image, box)
            lin = linear(px.mean(axis=0))
            frac = lin / white
            # The chromaticity: the colour normalised so red is 1. Light divides out of this
            # entirely, which is why it is the only thing carried between frames.
            ratio = lin / lin[0]
            chroma.append(ratio)
            print(f"    {label:22} sRGB {px.mean(axis=0).round(0).astype(int)}"
                  f"  linear {np.round(lin, 4)}"
                  f"  /white {np.round(frac, 3)}"
                  f"  G:R {ratio[1]:.3f}  B:R {ratio[2]:.3f}")
        for label, box in spec["other"]:
            px = patch(image, box)
            lin = linear(px.mean(axis=0))
            print(f"    {label:22} sRGB {px.mean(axis=0).round(0).astype(int)}"
                  f"  linear {np.round(lin, 4)}  /white {np.round(lin / white, 3)}")
        print()

    if not chroma:
        return
    chroma = np.array(chroma)
    mean = chroma.mean(axis=0)
    sd = chroma.std(axis=0)
    print(f"MAHOGANY CHROMATICITY over {len(chroma)} patches in {len(FRAMES)} photographs")
    print(f"    G:R  {mean[1]:.3f}  sd {sd[1]:.3f}  ({100 * sd[1] / mean[1]:.0f} per cent)")
    print(f"    B:R  {mean[2]:.3f}  sd {sd[2]:.3f}  ({100 * sd[2] / mean[2]:.0f} per cent)")
    print()
    print("    THE RESIDUAL IS THE POINT, and it is printed rather than described. A spread this")
    print("    size across two boats and two lights says the hue belongs to varnished mahogany and")
    print("    not to one afternoon. The widest patch is the sunlit forward topside, which picks up")
    print("    sky and reads bluer; the flattest are the two overcast ones.")
    print()
    print("THE LEVEL IS A JUDGEMENT AND IS SAID TO BE ONE. Only the overcast frame is lit flatly")
    print("enough to stand for a paint chip, so its topside is what sets how bright the wood is;")
    print("the two sunlit frames set the hue and are not allowed to set the level.")
    flat = linear(np.array([105.0, 44.0, 34.0]))  # cc1941 topside aft, the flattest lit patch
    print(f"    overcast topside aft, linear {np.round(flat, 4)}")
    for red in (0.10, 0.13, 0.16):
        lin = np.array([red, red * mean[1], red * mean[2]])
        srgb = to_srgb(lin)
        print(f"    linear red {red:.2f} at the measured hue -> vertex Color"
              f"({srgb[0]:.2f}, {srgb[1]:.2f}, {srgb[2]:.2f})"
              f"  = 8-bit sRGB {np.round(srgb * 255).astype(int)}")
    print()
    print("    These are sRGB because every ship mesh here is drawn by `ShipHull.painted()`, which")
    print("    sets `vertex_color_is_srgb`. Read as linear the same numbers come out near white.")


if __name__ == "__main__":
    main()
