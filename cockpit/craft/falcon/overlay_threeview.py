"""Lays `tests/falcon_shot.gd`'s three orthographic silhouettes over [CEL] at x1.000, with no fitting.

    python cockpit/craft/falcon/overlay_threeview.py <shots folder> <research folder> <out folder>

The silhouettes are rendered at 80 px a metre, which at the drawing's 1:100 is 8 px a drawing millimetre, centred on the
craft's origin. The origin is at a known drawing point -- half the box's length aft of the radome tip at x 13.30 and
half its height over the tyres' bottoms at y 60.0 -- so every silhouette pixel has a drawing coordinate and the drawing
is simply resampled to 8 px a millimetre and pasted on. A reader can dispute the result; nothing here chose it.

The front view is the exception, and says so in its name: [CEL]'s front view is drawn about 2.5 per cent taller than its
side view (`sources.md`), so it is aligned on the FIN TIP and the belly is expected to disagree.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import svg_lines  # noqa: E402

PX_PER_MM = 8.0
# The craft's origin on the drawing: FalconAirframe.DRAFT_GEOMETRY's box centre.
ORIGIN_X = 13.30 + 73.35
ORIGIN_Y = 60.0 - 15.965
PLAN_CENTRE_Y = 114.062
FIN_TOP_SIDE_Y = 5.757
FIN_TOP_FRONT_X = 222.707
DOC_WIDTH_MM = 230.0


def drawing(research, scratch):
    """[CEL] rasterised by Godot's own SVG loader is not available here, so it is drawn from its polylines: every path as
    a black line at 8 px a millimetre, which is exactly the resolution the overlay needs."""
    size = (int(DOC_WIDTH_MM * PX_PER_MM), int(170.0 * PX_PER_MM))
    image = Image.new("L", size, 255)
    pen = ImageDraw.Draw(image)
    for line in svg_lines.read(os.path.join(research, "cel_f16a_block15_3view.svg")):
        pts = [(x * PX_PER_MM, y * PX_PER_MM) for x, y in line["points"]]
        if len(pts) > 1:
            pen.line(pts, fill=0, width=2)
    return image


def overlay(silhouette_path, lines, out_path, label):
    shot = Image.open(silhouette_path).convert("RGB")
    lines = lines.resize(shot.size) if lines.size != shot.size else lines
    tinted = Image.blend(Image.new("RGB", shot.size, (255, 255, 255)), shot, 0.45)
    ink = ImageOps.invert(lines.convert("L"))
    black = Image.new("RGB", shot.size, (0, 0, 0))
    composite = Image.composite(black, tinted, ink)
    pen = ImageDraw.Draw(composite)
    pen.text((8, 6), label, fill=(0, 0, 0))
    composite.save(out_path)
    print("saved", out_path)


def main():
    shots, research, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    full = drawing(research, out)

    # SIDE: render px (u, v) = (w/2 + (x - ORIGIN_X) * 8, h/2 + (y - ORIGIN_Y) * 8).
    side = Image.open(os.path.join(shots, "cockpit-falcon-06-side-at-80px-per-m.png"))
    w, h = side.size
    left = ORIGIN_X * PX_PER_MM - w / 2
    top = ORIGIN_Y * PX_PER_MM - h / 2
    crop = full.crop((int(round(left)), int(round(top)), int(round(left)) + w, int(round(top)) + h))
    overlay(os.path.join(shots, "cockpit-falcon-06-side-at-80px-per-m.png"), crop,
            os.path.join(out, "cockpit-falcon-09-side-on-radome-tip-and-tyres-over-cel-1to100-x1.000.png"),
            "side: model (magenta) over [CEL] F-16A Block 15, 1:100, aligned on radome tip x13.30 and tyres y60.0, x1.000")

    # PLAN: image right is aft, image up is starboard; the plan's centreline is at PLAN_CENTRE_Y.
    plan = Image.open(os.path.join(shots, "cockpit-falcon-08-top-at-80px-per-m.png"))
    w, h = plan.size
    left = ORIGIN_X * PX_PER_MM - w / 2
    top = PLAN_CENTRE_Y * PX_PER_MM - h / 2
    crop = full.crop((int(round(left)), int(round(top)), int(round(left)) + w, int(round(top)) + h))
    overlay(os.path.join(shots, "cockpit-falcon-08-top-at-80px-per-m.png"), crop,
            os.path.join(out, "cockpit-falcon-10-top-on-radome-tip-and-centreline-over-cel-1to100-x1.000.png"),
            "plan: model (magenta) over [CEL], aligned on radome tip and centreline, x1.000")

    # FRONT: [CEL]'s front view is turned a quarter, fin towards +x. Turn it upright, then put the fin tip on the
    # model's fin tip.
    front = Image.open(os.path.join(shots, "cockpit-falcon-07-front-at-80px-per-m.png"))
    w, h = front.size
    # The model's fin tip is FIN_TOP_SIDE_Y on the side view's scale, which is (ORIGIN_Y - FIN_TOP_SIDE_Y) * 8 px above
    # the image centre.
    fin_v = h / 2 - (ORIGIN_Y - FIN_TOP_SIDE_Y) * PX_PER_MM
    upright = full.rotate(90, expand=True)  # counter-clockwise: drawing +x goes up, drawing +y goes right
    # After the turn a drawing point (x, y) is at (y, W - x) in pixels, where W is the drawing's width in pixels.
    W = full.size[0]
    fin_u_in = PLAN_CENTRE_Y * PX_PER_MM
    fin_v_in = W - FIN_TOP_FRONT_X * PX_PER_MM
    left = fin_u_in - w / 2
    top = fin_v_in - fin_v
    crop = upright.crop((int(round(left)), int(round(top)), int(round(left)) + w, int(round(top)) + h))
    overlay(os.path.join(shots, "cockpit-falcon-07-front-at-80px-per-m.png"), crop,
            os.path.join(out, "cockpit-falcon-11-front-on-fin-tip-over-cel-1to100-x1.000.png"),
            "front: model (magenta) over [CEL], aligned on the fin tip; [CEL]'s front view is 2.5% taller than its side")


if __name__ == "__main__":
    main()
