"""Lays `tests/osprey_shot.gd`'s gear frames side by side, in cycle order, as one strip.

    python cockpit/craft/osprey/strip.py <folder of osprey_shot's pictures> <out.png>

Each frame keeps the label the probe burnt into it (the gear's amount, 0 up and 100 down), so the strip reads left to
right and down as a lowering: the doors open, the legs come down, the doors shut.
"""
import glob
import os
import sys

from PIL import Image

frames = sorted(glob.glob(os.path.join(sys.argv[1], "osprey-24-gear-*.png")))
tiles = [Image.open(f).resize((800, 450)) for f in frames]
columns = 2
sheet = Image.new("RGB", (800 * columns, 450 * ((len(tiles) + columns - 1) // columns)), "white")
for i, tile in enumerate(tiles):
    sheet.paste(tile, ((i % columns) * 800, (i // columns) * 450))
sheet.save(sys.argv[2])
print("%d frames into %s" % (len(tiles), sys.argv[2]))
