"""Re-derives every MEASURED figure in `sources.md` and `LittleBirdAirframe` from the MH-6 three-view, reading nothing
out of the write-up.

    python cockpit/craft/littlebird/measure_drawing.py [folder holding the drawing]

The folder defaults to ~/godotgames-drafts/2026-09-17/cockpit-littlebird/research/. The drawing is not in the repo: it is
study material, CC BY-SA 4.0, and `sources.md` names its Commons page. It is [FOX], FOX 52's "Boeing MH-6
orthographical image.svg", a VECTOR file in unscaled document units, so this measures its own coordinates: no pixels.

THE SCALE IS THE ROTOR. [W]'s published main rotor diameter (27 ft 4.8 in) over the side view's drawn blade tips gives
metres a unit, and NOTHING ELSE IS FITTED. Two numbers the drawing was not scaled by then come back as checks: the
fuselage length (nose to tail, [W]'s 24 ft 7.2 in) and the length with the rotors turning (32 ft 7.2 in).

THE DRAWING IS TRACED ART, AND THIS SAYS WHERE. Its plan view's rotor blades are 8 per cent short of its own side and
front views, and its front view's heights are about 5 per cent squashed against its side view, so the side view is the
authority for every station and height, the plan for widths, and the front for the SHAPE of a section only. Printed
below, so nobody has to take it on trust.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "falcon"))
import svg_lines  # noqa: E402  (the falcon lane's reader, shared rather than copied)

FOLDER = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-17/cockpit-littlebird/research")
FOX = os.path.join(FOLDER, "mh6_fox52.svg")

INCH = 0.0254
FOOT = 12 * INCH
# [W] Wikipedia, "MD Helicopters MH-6 Little Bird", Specifications (MH-6), read 2026-09-17.
ROTOR_DIAMETER = 27 * FOOT + 4.8 * INCH       # 8.357 m
FUSELAGE_LENGTH = 24 * FOOT + 7.2 * INCH      # 7.498 m, "fuselage only"
LENGTH_ROTORS = 32 * FOOT + 7.2 * INCH        # 9.939 m, "including rotors"
WIDTH = 4 * FOOT + 7.2 * INCH                 # 1.402 m
HEIGHT = 8 * FOOT + 9 * INCH                  # 2.667 m


def by_id(lines):
    out = {}
    for line in lines:
        out.setdefault(line["id"], []).append(line["points"])
    return out


def ext(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return min(xs), max(xs), min(ys), max(ys)


def cut_x(points, x):
    """Every height where the closed outline crosses the vertical x."""
    ys = []
    for a, b in zip(points, points[1:] + points[:1]):
        if (a[0] - x) * (b[0] - x) < 0:
            ys.append(a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0]))
    return sorted(ys)


def cut_y(points, y):
    xs = []
    for a, b in zip(points, points[1:] + points[:1]):
        if (a[1] - y) * (b[1] - y) < 0:
            xs.append(a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]))
    return sorted(xs)


def fit_line(rows):
    """Least squares y = a + b x over every row, and the rms residual. Never through two ends."""
    n = len(rows)
    mx = sum(r[0] for r in rows) / n
    my = sum(r[1] for r in rows) / n
    b = sum((r[0] - mx) * (r[1] - my) for r in rows) / sum((r[0] - mx) ** 2 for r in rows)
    a = my - b * mx
    rms = math.sqrt(sum((r[1] - a - b * r[0]) ** 2 for r in rows) / n)
    return a, b, rms


def main():
    s = by_id(svg_lines.read(FOX))
    body = s["path3804"][0]          # side view: the fuselage and boom outline
    plan = s["path4237"][0]          # plan view: the fuselage and boom outline
    front = s["rect3057"][0]         # front view: the cabin
    print("== THE SCALE, from the side view's rotor")
    tip_fore = ext(s["path3972"][0])[0]
    tip_aft = ext(s["path3978"][0])[1]
    drawn = tip_aft - tip_fore
    unit = ROTOR_DIAMETER / drawn
    print("  side blade tips x %.2f .. %.2f = %.2f units for [W] %.3f m: %.6f m a unit, %.3f units a metre"
          % (tip_fore, tip_aft, drawn, ROTOR_DIAMETER, unit, 1 / unit))
    front_rotor = ext(s["path4402"][0])[1] - ext(s["path4376"][0])[0]
    print("  front view's rotor %.2f units: %+.2f %% against the side" % (front_rotor, 100 * (front_rotor / drawn - 1)))
    left = s["path4464"][0]
    right = s["path4348"][0]
    plan_rotor = ext(right)[1] - ext(left)[0]
    print("  plan view's two near-level blades tip to tip %.2f units: %+.1f %% -- THE PLAN'S BLADES ARE DRAWN SHORT"
          % (plan_rotor, 100 * (plan_rotor / drawn - 1)))

    nose_x = ext(body)[0]
    ground_y = ext(s["rect3816"][0])[3]
    tail_x = ext(s["path3873"][0])[1]
    print("== TWO CHECKS THE SCALE WAS NOT FITTED TO")
    print("  nose x %.2f to the tail's endplate x %.2f: %.3f m against [W]'s fuselage %.3f (%+.1f %%)"
          % (nose_x, tail_x, (tail_x - nose_x) * unit, FUSELAGE_LENGTH,
             100 * ((tail_x - nose_x) * unit / FUSELAGE_LENGTH - 1)))
    hub_x = (ext(s["path3951"][0])[0] + ext(s["path3951"][0])[1]) * 0.5
    tr = s["path3896"][0]
    tr_x = (ext(tr)[0] + ext(tr)[1]) * 0.5
    tr_y = (ext(tr)[2] + ext(tr)[3]) * 0.5
    tr_radius = (ext(s["rect4124"][0])[3] - ext(s["rect4122"][0])[2]) * 0.5
    fore = hub_x - drawn * 0.5
    aft = tr_x + tr_radius
    print("  rotor tip ahead of the hub (x %.2f) to the tail rotor's tip aft of its hub (x %.2f + %.2f): %.3f m"
          " against [W]'s %.3f with rotors (%+.1f %%)" % (hub_x, tr_x, tr_radius, (aft - fore) * unit, LENGTH_ROTORS,
                                                          100 * ((aft - fore) * unit / LENGTH_ROTORS - 1)))
    print("== WHAT THE DRAWING DISAGREES WITH")
    hub_top = ext(s["path3951"][0])[2]
    rotor_plane = (ext(s["path3972"][0])[2] + ext(s["path3972"][0])[3]) * 0.5
    fin_top = ext(s["path3873"][0])[2]
    print("  height: skids y %.2f to the hub's top y %.2f = %.3f m, to the rotor plane %.3f, to the T-tail's top %.3f;"
          " [W] says %.3f" % (ground_y, hub_top, (ground_y - hub_top) * unit, (ground_y - rotor_plane) * unit,
                              (ground_y - fin_top) * unit, HEIGHT))
    fw = ext(front)[1] - ext(front)[0]
    pw = max(b - a for a, b in [cut_y(plan, y)[:2] for y in [x * 0.5 for x in range(160, 260)]])
    print("  width: the front view's cabin %.2f units = %.3f m; the plan's widest %.2f = %.3f m; [W] says %.3f"
          % (fw, fw * unit, pw, pw * unit, WIDTH))
    print("  so the pod is drawn narrower by x%.4f to [W]'s width: POD_WIDTH_SCALE" % (WIDTH / (pw * unit)))
    fh = ext(front)[3] - ext(front)[2]
    top_side = min(cut_x(body, 335.0))
    bottom_side = max(cut_x(body, 350.0))
    print("  the front view's cabin %.2f units tall against the side's %.2f (roof x 335 to belly x 350): %+.1f %%"
          % (fh, bottom_side - top_side, 100 * (fh / (bottom_side - top_side) - 1)))

    print("== THE DATUMS, drawing units")
    print("  NOSE_X %.2f  GROUND_Y %.2f  HUB_X %.2f  ROTOR_Y %.2f  HUB_TOP %.2f  PLAN_NOSE_Y %.2f  PLAN_CENTRE %.3f  "
          "FRONT_CENTRE %.3f" % (nose_x, ground_y, hub_x, rotor_plane, hub_top, ext(plan)[2],
                                 (ext(plan)[0] + ext(plan)[1]) * 0.5, (ext(front)[0] + ext(front)[1]) * 0.5))
    print("  the plan against the side: the roof windows at plan y %.2f..%.2f and side x %.2f..%.2f"
          % (ext(s["rect4825"][0])[2], ext(s["rect4825"][0])[3], ext(s["path3839"][0])[0], ext(s["path3839"][0])[1]))

    print("== THE POD, side view: [x, top, bottom] and the plan's half-width there")
    centre = (ext(plan)[0] + ext(plan)[1]) * 0.5
    cowl_line = s["path3843"][0]
    for x in [289.5, 291, 293, 296, 300, 305, 310, 315, 320, 326, 332, 338, 342, 348, 356, 364, 372, 380, 388, 396, 404]:
        ys = cut_x(body, x)
        top = ys[0]
        if x > 342.4:
            # Aft of the cabin the outline's top is the engine cowling; the pod's own top is the fairing line under it.
            top = cut_x(cowl_line + cowl_line[::-1], x)[0] if x < 407.6 else ys[0]
        xs = cut_y(plan, ext(plan)[2] + (x - nose_x))
        print("  [%.1f, %.2f, %.2f, %.2f]," % (x, top, ys[-1], (xs[-1] - xs[0]) * 0.5))
    print("== THE SECTION, front view: [depth share from the roof, half-width share]")
    top, bottom = ext(front)[2], ext(front)[3]
    half = (ext(front)[1] - ext(front)[0]) * 0.5
    for y in [86.0, 88.0, 93.0, 105.0, 120.0, 131.0, 136.0]:
        xs = cut_y(front, y)
        print("  [%.3f, %.3f]," % ((y - top) / (bottom - top), (xs[-1] - xs[0]) * 0.5 / half))

    print("== THE BOOM, side and plan: [x, top, bottom, half-width]")
    for x in [396, 404, 412, 420, 440, 460, 480, 499.5]:
        ys = cut_x(body, x)
        xs = cut_y(plan, ext(plan)[2] + (x - nose_x))
        print("  [%.1f, %.2f, %.2f, %.2f]," % (x, ys[0], ys[-1], (xs[-1] - xs[0]) * 0.5))
    print("== THE COWLING: its top off the side outline, its half-width off the plan's fairing (path3209)")
    cowl_plan = s["path3209"][0]
    for x in [343, 346, 352, 360, 370, 380, 390, 397]:
        ys = cut_x(body, x)
        xs = cut_y(cowl_plan, ext(plan)[2] + (x - nose_x))
        print("  [%.1f, %.2f, %.2f]," % (x, ys[0], (xs[-1] - xs[0]) * 0.5 if len(xs) >= 2 else 0.0))

    print("== THE TAIL")
    fin = s["path3871"][0]
    print("  fin outline (upper and lower, one path):", " ".join("(%.1f,%.1f)" % p for p in fin[:-1]))
    a, b, rms = fit_line([(fin[0][1], fin[0][0]), (fin[1][1], fin[1][0])])
    print("  upper fin's leading edge swept %.1f degrees (two drawn corners -- the edge is one straight line);"
          " [NPS]'s OH-6A upper fin is 24" % math.degrees(math.atan(-b)))
    print("  lower fin's leading edge swept %.1f degrees, %.2f m deep; [NPS]'s OH-6A lower fin 12.5 and 0.70"
          % (math.degrees(math.atan((fin[10][0] - fin[9][0]) / (fin[9][1] - fin[10][1]))) * -1,
             (fin[8][1] - fin[10][1]) * unit))
    stab = s["path4110"][0]
    print("  stabiliser, plan: span %.3f m over its tips, %.3f m over the endplates (%.2f .. %.2f)"
          % ((ext(stab)[1] - ext(stab)[0]) * unit, (ext(s["rect4120"][0])[1] - ext(s["rect4118"][0])[0]) * unit,
             ext(s["rect4118"][0])[0], ext(s["rect4120"][0])[1]))
    print("  stabiliser outline, plan:", " ".join("(%.2f,%.2f)" % p for p in stab[:-1]))
    print("  endplate, side:", " ".join("(%.2f,%.2f)" % p for p in s["path3873"][0][:-1]))
    print("  tail rotor: hub (%.2f, %.2f), radius %.2f units = %.3f m, %.3f m to port of the plan's centreline"
          % (tr_x, tr_y, tr_radius, tr_radius * unit, (centre - (ext(s["rect4122"][0])[0] + ext(s["rect4122"][0])[1])
                                                        * 0.5) * unit))
    print("== THE GEAR")
    skid = s["rect3816"][0]
    print("  skid x %.2f .. %.2f, tube y %.2f .. %.2f" % (ext(skid)[0], ext(skid)[1], 295.4, ext(skid)[3]))
    fl = ext(s["rect3983"][0])
    fr = ext(s["path3998"][0])
    fc = (ext(front)[0] + ext(front)[1]) * 0.5
    print("  front view skid middles %.2f and %.2f: track %.3f m, %.3f m out each side"
          % ((fl[0] + fl[1]) * 0.5, (fr[0] + fr[1]) * 0.5, ((fr[0] + fr[1]) - (fl[0] + fl[1])) * 0.5 * unit,
             (fc - (fl[0] + fl[1]) * 0.5) * unit))
    print("  front leg (front view) from", ["(%.2f,%.2f)" % p for p in s["path3988"][0][:4]])
    for pid in ["path3765", "path3808"]:
        e = ext(s[pid][0])
        print("  %s side: x %.2f..%.2f y %.2f..%.2f" % (pid, *e))
    print("== THE GLAZING AND THE DOORS, side view outlines")
    for pid in ["path3837", "path3309", "path3827", "path3845"]:
        pts = s[pid][0]
        step = max(1, len(pts) // 14)
        print("  %s:" % pid, " ".join("(%.1f,%.1f)" % p for p in pts[:-1:step]))
    print("  roof windows, plan: x %.2f..%.2f and %.2f..%.2f, y %.2f..%.2f" % (
        ext(s["rect4825"][0])[0], ext(s["rect4825"][0])[1], ext(s["path4832"][0])[0], ext(s["path4832"][0])[1],
        ext(s["rect4825"][0])[2], ext(s["rect4825"][0])[3]))
    print("  the bench plank, side: x %.2f..%.2f y %.2f..%.2f" % ext(s["rect4240"][0]))
    print("  the FLIR ball, side: x %.2f..%.2f y %.2f..%.2f" % ext(s["path5062"][0]))


if __name__ == "__main__":
    main()
