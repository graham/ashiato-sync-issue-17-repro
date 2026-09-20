"""Lays `tests/liners_shot.gd`'s gear frames side by side, in cycle order, as one strip.

    python cockpit/craft/airliner/strip.py <folder of liners_shot's pictures> <prefix, e.g. liners-737> <out.png>

Each frame is cropped to the same band round the aeroplane and keeps the label the probe burnt into it (the gear's
amount, 0 up and 100 down), so the strip reads left to right, top to bottom, as a lowering: doors open, legs down, doors
shut.
"""
import glob
import os
import sys

from PIL import Image

frames = sorted(glob.glob(os.path.join(sys.argv[1], sys.argv[2] + "-06-gear-*.png")))
box = (0, 0, 1600, 560)
tiles = [Image.open(f).crop(box).resize((800, 280)) for f in frames]
columns = 2
sheet = Image.new("RGB", (800 * columns, 280 * ((len(tiles) + columns - 1) // columns)), "white")
for i, tile in enumerate(tiles):
    sheet.paste(tile, ((i % columns) * 800, (i // columns) * 280))
sheet.save(sys.argv[3])
print("%d frames into %s" % (len(tiles), sys.argv[3]))
