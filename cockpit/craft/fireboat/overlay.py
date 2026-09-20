"""Lay the drawn port elevation over the reference photograph AT THE SAME SCALE.

THIS IS THE ONLY INSTRUMENT THAT CAN CHECK A STATION, and `learnings/2026-09-20-harriershape.md`
is why it exists. That lane put the Harrier's intake bells round the nose, ahead of the
windscreen, and every published figure still held -- because not one published figure on its
sheet was a station. They were lengths, spans, heights, tracks and angles, and a component can
slide anywhere along a body without disturbing a single one of them.

This boat has the same exposure. Her published length, beam, draught, tonnage and speed are all
satisfied wherever her deckhouse sits, and `tests/fireboat.gd` cannot see a station either. Her
widths and heights are good to about a pixel off the reference; her POSITIONS ALONG THE HULL are
the soft measurement, at roughly 5 per cent, because the camera is forward of the beam.

So: render the model orthographically at a known px/m (`fireboat_shot.gd`, which prints the scale
into the picture's own filename), scale the photograph to the SAME px/m from its own measured
71.29 px/m, align on ONE datum, and look. A reader can dispute the result. Nobody can dispute
"it looks right".

    python overlay.py <elevation.png> <stehlik.jpg> [out.png]

The photograph is not in the repo -- it is CC BY 3.0 and study only. Fetch
`Peter Stehlik - FDNY Three Forty Three - 2012.05.17.jpg` from Wikimedia Commons at width 2400
and pass its path. See `sources.md`.
"""

import sys
from PIL import Image

# THE PHOTOGRAPH'S OWN SCALE, measured by `measure_boat.py` from the image alone: the stem at
# x 348 and the transom at x 3390, 3,042 px for a published 42.672 m.
PHOTO_PX_PER_M = 71.29
PHOTO_STEM_X = 348.0
# WHERE THE WATERLINE IS IN THE PHOTOGRAPH at the stem, from the same script's robust fit. The
# ALIGNMENT DATUM IS THE STEM AT THE WATERLINE and nothing else: one datum, stated, so any
# disagreement further aft is the model's and not the alignment's. Aligning on two points would
# hide exactly the error this picture exists to find.
PHOTO_WATERLINE_AT_STEM_Y = 1884.0


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    elevation = Image.open(sys.argv[1]).convert("RGBA")
    photo = Image.open(sys.argv[2]).convert("RGBA")
    out_path = sys.argv[3] if len(sys.argv) > 3 else "overlay.png"

    # THE RENDER'S SCALE IS IN ITS FILENAME, which is `modelling_here.md` section 7's rule: an
    # overlay whose scale lives only in somebody's head cannot be laid on anything.
    stem = sys.argv[1].rsplit("-", 1)[-1]
    render_px_per_m = float(stem.replace("pxm.png", ""))
    factor = render_px_per_m / PHOTO_PX_PER_M
    photo = photo.resize((int(photo.width * factor), int(photo.height * factor)), Image.LANCZOS)
    print("render %.3f px/m, photograph %.2f px/m -> photograph scaled x%.4f"
          % (render_px_per_m, PHOTO_PX_PER_M, factor))
    print("one pixel of the overlay is %.1f mm" % (1000.0 / render_px_per_m))

    canvas = Image.new("RGBA", photo.size, (0, 0, 0, 255))
    canvas.paste(photo, (0, 0))
    # The elevation is laid over it at half weight so both are readable at once.
    faded = elevation.copy()
    faded.putalpha(128)
    canvas.alpha_composite(faded, (0, 0))
    canvas.save(out_path)
    print("wrote %s -- align by eye on the STEM AT THE WATERLINE, then read the stations aft" % out_path)
    print("photograph datum after scaling: stem x %.0f, waterline y %.0f"
          % (PHOTO_STEM_X * factor, PHOTO_WATERLINE_AT_STEM_Y * factor))
    return 0


if __name__ == "__main__":
    sys.exit(main())
