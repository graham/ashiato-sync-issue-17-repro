"""Lays `tests/warthog_shot.gd`'s gear frames side by side, in cycle order, as one strip.

    python cockpit/craft/warthog/strip.py <folder of warthog_shot's pictures> <out.png>

Each frame keeps the label the probe burnt into it (the gear's amount, 0 up and 100 down), so the strip reads left to
right, top to bottom, as a lowering: the nose doors open, the legs swing down and back, the nose doors shut, and the main
wheels come out of their pods, where they were half out all along.
"""
import glob
import os
import sys

from PIL import Image

frames = sorted(glob.glob(os.path.join(sys.argv[1], "warthog-12-gear-*.png")))
box = (0, 0, 1600, 680)
tiles = [Image.open(f).crop(box).resize((700, 298)) for f in frames]
columns = 2
sheet = Image.new("RGB", (700 * columns, 298 * ((len(tiles) + columns - 1) // columns)), "white")
for i, tile in enumerate(tiles):
    sheet.paste(tile, ((i % columns) * 700, (i // columns) * 298))
sheet.save(sys.argv[2])
print("%d frames into %s" % (len(tiles), sys.argv[2]))
