"""THE CONCEPT SHEET BESIDE THE BUILT MODEL, panel for panel.

    python tools/hangar_comparison.py SHOTS_DIR OUT.png

SHOTS_DIR is a directory `tests/hangar_shot.gd` has written: its `cockpit-hangar-NN-*.png` pictures and the
`frames.json` it leaves beside them.

THIS IS THE PICTURE THE WORK IS JUDGED BY. The user drew the sheet and the question they will ask is whether the
building looks like it, so the two are laid out in the sheet's own order, at a matched scale, with the correspondence
made obvious rather than asserted.

EACH RENDER IS CROPPED TO WHERE THE BUILDING ACTUALLY LANDED, not to a box typed in here per view. The probe projects
the hangar's own drawn corners and writes the rect to `frames.json`; this reads it. A crop typed beside each view would
be wrong the first time a camera moved, and would be wrong silently (CLAUDE.md, rule 4 -- ask the authority, do not
keep a roster).

THE CONCEPT PANELS ARE CROPPED BY MEASUREMENT TOO, but the sheet is a flat picture with no authority to ask, so those
boxes are measured off it once and written down here with the sheet's own size beside them. If the sheet is ever
replaced the numbers must be re-measured, which is why the expected size is asserted rather than assumed.
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# The sheet these panel boxes were measured on. Asserted, because a different sheet would silently crop to nonsense.
SHEET_SIZE = (1448, 1086)

# EACH ROW: the sheet's panel, the render that answers it, and what to call the pair.
# The panel boxes are pixels on the sheet, measured off it by eye and checked on a contact sheet.
ROWS = [
    ((195, 5, 1300, 515), "cockpit-hangar-01-hero-three-quarter-front.png",
     "HERO THREE-QUARTER -- door open, fighter inside"),
    ((18, 545, 478, 770), "cockpit-hangar-02-front-elevation-door-open.png",
     "FRONT ELEVATION (DOOR OPEN) -- 24 m clear opening"),
    ((484, 545, 928, 770), "cockpit-hangar-03-rear-elevation.png",
     "REAR ELEVATION"),
    ((934, 545, 1440, 770), "cockpit-hangar-04-side-elevation-left.png",
     "SIDE ELEVATION (LEFT) -- 40 m length"),
    ((18, 772, 688, 1080), "cockpit-hangar-05-rear-three-quarter.png",
     "REAR THREE-QUARTER VIEW"),
    ((694, 772, 1190, 1080), "cockpit-hangar-06-top-view-roof.png",
     "TOP VIEW (ROOF) -- 40 x 32 m"),
]

CELL = (700, 300)
GAP = 14
LABEL = 26
HEADER = 116
INK = (233, 236, 242)
DIM = (150, 157, 172)
BACK = (26, 28, 34)
CARD = (38, 41, 49)
# How much of the building's own width is left round it when a render is cropped to it.
MARGIN = 0.10


def _font(size, bold=False):
    for name in (("arialbd.ttf", "seguisb.ttf") if bold else ("arial.ttf", "segoeui.ttf")):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _fitted(image, cell):
    """`image` scaled to sit inside `cell`, centred on a card the size of the cell."""
    shown = image.copy()
    shown.thumbnail(cell, Image.LANCZOS)
    card = Image.new("RGB", cell, CARD)
    card.paste(shown, ((cell[0] - shown.width) // 2, (cell[1] - shown.height) // 2))
    return card


def _cropped_to_the_building(picture, rect):
    """The render, cropped to where the probe measured the building, with a margin round it.

    A rect of no width means the probe was inside the building (the interior view) or could not see it, and the frame
    is used whole.
    """
    if rect is None or rect["w"] <= 1.0 or rect["h"] <= 1.0:
        return picture
    pad = rect["w"] * MARGIN
    box = (rect["x"] - pad, rect["y"] - pad, rect["x"] + rect["w"] + pad, rect["y"] + rect["h"] + pad)
    box = (max(0, int(box[0])), max(0, int(box[1])),
           min(picture.width, int(box[2])), min(picture.height, int(box[3])))
    if box[2] - box[0] < 40 or box[3] - box[1] < 40:
        return picture
    return picture.crop(box)


def main(shots_dir, out_path):
    shots = Path(shots_dir)
    sheet = Image.open(Path(__file__).resolve().parent.parent / "structures/hangar_03/hanger_v1.webp").convert("RGB")
    if sheet.size != SHEET_SIZE:
        raise SystemExit("the concept sheet is %s, not the %s these panel boxes were measured on"
                         % (sheet.size, SHEET_SIZE))
    frames = {}
    sidecar = shots / "frames.json"
    if sidecar.exists():
        frames = json.loads(sidecar.read_text())

    wide = GAP * 3 + CELL[0] * 2
    high = HEADER + len(ROWS) * (CELL[1] + LABEL + GAP) + GAP
    board = Image.new("RGB", (wide, high), BACK)
    pen = ImageDraw.Draw(board)
    pen.text((GAP + 4, 20), "SKYFRONT HANGAR 03", font=_font(34, True), fill=INK)
    pen.text((GAP + 6, 60), "the concept sheet, panel for panel, against the model built from it",
             font=_font(17), fill=DIM)

    y = HEADER
    for panel, render_name, caption in ROWS:
        pen.text((GAP + 4, y), caption, font=_font(16, True), fill=INK)
        drawn = sheet.crop(panel)
        board.paste(_fitted(drawn, CELL), (GAP, y + LABEL))
        picture_path = shots / render_name
        if picture_path.exists():
            picture = Image.open(picture_path).convert("RGB")
            picture = _cropped_to_the_building(picture, frames.get(render_name))
            board.paste(_fitted(picture, CELL), (GAP * 2 + CELL[0], y + LABEL))
        else:
            pen.rectangle([GAP * 2 + CELL[0], y + LABEL, GAP * 2 + CELL[0] * 2, y + LABEL + CELL[1]], fill=CARD)
            pen.text((GAP * 2 + CELL[0] + 20, y + LABEL + 20), "missing: %s" % render_name,
                     font=_font(15), fill=(220, 120, 120))
        y += CELL[1] + LABEL + GAP

    # WHICH SIDE IS WHICH, said once at the top of each column rather than on every row.
    pen.text((GAP + 4, HEADER - 26), "CONCEPT SHEET", font=_font(15, True), fill=DIM)
    pen.text((GAP * 2 + CELL[0] + 4, HEADER - 26), "BUILT IN COCKPIT", font=_font(15, True), fill=DIM)
    board.save(out_path)
    print("wrote %s (%d x %d)" % (out_path, board.width, board.height))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2])
