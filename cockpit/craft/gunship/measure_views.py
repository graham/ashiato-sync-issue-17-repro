"""Re-derives every MEASURED figure in `sources.md` and `HerculesAirframe` from Lockheed Martin's own General Arrangement
of the C-130J-30, reading nothing out of the write-up.

    python cockpit/craft/gunship/measure_views.py [path to C130JPocketGuide.pdf]

The PDF defaults to ~/godotgames-drafts/2026-09-19/cockpit-liners/research/C130JPocketGuide.pdf: Lockheed Martin's
"C-130J Super Hercules Pocket Guide", whose page index 4 is the "General Arrangement" -- plan, side and front at one scale,
drawn as VECTORS, the aeroplanes as grey fills over dark outlines, with printed dimensions. It is study material and is
not in the repo; `sources.md` says where Lockheed Martin publishes it. The page is redrawn from its FILLED paths alone
(`craft/airliner/acaps.py`'s `filled_page`), which leaves the aeroplanes and drops the dimension lines, which are strokes.

IT IS THE STRETCHED C-130J-30, and the model is the C-130H: the -30 is the H's airframe with a 100 in (2.54 m) plug
behind the flight deck and an 80 in (2.03 m) plug aft of the wing (Wikipedia, "Lockheed C-130 Hercules": the C-130H-30
"achieved by inserting a 100 in plug aft of the cockpit and an 80 in plug at the rear of the fuselage"). The printed
lengths agree to a centimetre: 112 ft 9 in (34.37 m) less 4.57 m is the H's 97 ft 9 in (29.79 m). So stations here are the
-30's, and `HerculesAirframe` takes the plugs out.

ONE PUBLISHED NUMBER SETS THE SCALE: the -30's length, 34.37 m, over the plan's length in pixels. The other printed
figures are cross-checks: the span 132 ft 7 in (40.38 m printed on the drawing, 40.41 in the text), the height 38 ft 10 in
(11.84 m), the tailplane 52 ft 8 in (16.05 m), the fuselage 14 ft 2 in (4.32 m), the main gear's track 14 ft 3 in (4.34
m), the nose gear 11 ft 6 in (3.50 m) aft of the nose and the main gear 40 ft 4 in (12.30 m) behind it.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "airliner"))
import acaps  # noqa: E402

PDF = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-19/cockpit-liners/research/C130JPocketGuide.pdf")
PAGE = 4
DPI = 1200

LENGTH_M = 34.37     # 112 ft 9 in: THE SCALE
SPAN_M = 40.38       # 132 ft 7 in, as the drawing prints it (the text says 40.41)
HEIGHT_M = 11.84     # 38 ft 10 in
TAILPLANE_M = 16.05  # 52 ft 8 in
WIDTH_M = 4.32       # 14 ft 2 in, the fuselage
TRACK_M = 4.34       # 14 ft 3 in
NOSE_GEAR_M = 3.50   # 11 ft 6 in
WHEELBASE_M = 12.30  # 40 ft 4 in


def report(name, measured, printed):
    print("  %-40s %7.3f m against %.2f printed (%+.2f%%)" % (name, measured, printed,
                                                            100.0 * (measured - printed) / printed))


def views():
    cache = "%s.p%d.%ddpi.fill.npy" % (PDF, PAGE, DPI)
    if os.path.exists(cache):
        ink = np.load(cache)
    else:
        ink = acaps.filled_page(PDF, PAGE, DPI, left_of=270.0)
        np.save(cache, ink)
    pieces = acaps.components(acaps.silhouette(ink), least=2000)
    # THE THREE VIEWS are the three largest pieces that are not the page's black title bar, which is far wider than tall.
    big = []
    for n, m in pieces:
        ys, xs = np.nonzero(m)
        if (xs.max() - xs.min()) > 6 * (ys.max() - ys.min()):
            continue
        big.append(m)
        if len(big) == 3:
            break
    big.sort(key=lambda m: np.nonzero(m)[0].min())
    plan, side, front = big
    # SMALL PIECES INSIDE A VIEW'S BOX join it: the front view's two propeller hubs drawn below the wing.
    for n, m in pieces:
        ys, xs = np.nonzero(m)
        for view in (front,):
            vy, vx = np.nonzero(view)
            if vy.min() <= ys.mean() <= vy.max() + 200 and vx.min() <= xs.mean() <= vx.max() and n < 20000:
                view |= m
    return ink, plan, side, front


def main():
    ink, plan, side, front = views()
    py, px = np.nonzero(plan)
    sy, sx = np.nonzero(side)
    fy, fx = np.nonzero(front)
    plan_len = px.max() - px.min() + 1
    side_len = sx.max() - sx.min() + 1
    plan_span = py.max() - py.min() + 1
    front_span = fx.max() - fx.min() + 1
    print("THE VIEWS ARE NOT AT ONE SCALE: plan length %d px, side %d (%+.2f%%); plan span %d px, front %d (%+.2f%%)"
          % (plan_len, side_len, 100.0 * (side_len - plan_len) / plan_len, plan_span, front_span,
             100.0 * (front_span - plan_span) / plan_span))
    # EACH VIEW BY ITS OWN PRINTED NUMBER: the plan and the side by the length; the front by the fuselage's width,
    # because its wing is drawn long (see "FRONT" below, and sources.md).
    sp = plan_len / LENGTH_M
    ss = side_len / LENGTH_M
    nose = px.min()
    cy = (py.min() + py.max()) / 2.0
    snose = sx.min()
    ground = sy.max() + 1
    fground = fy.max() + 1
    fcx = (fx.min() + fx.max()) / 2.0
    # THE FRONT VIEW IS AT THE SIDE VIEW'S SCALE, and its wing and gear are not: measured on 2026-09-19, at the side's
    # scale the front's fuselage is 4.34 m across (printed 4.32) and its fin tip 11.9 m up (printed 11.84), while its
    # span comes out 36.5 m (printed 40.38) and its track 3.5 m (printed 4.34). The plan's own scale is 8 per cent
    # smaller than both. So the front is read for heights and the fuselage's section only, at the side's scale.
    sf = ss
    print("plan %.3f px a metre and side %.3f, both from the printed 34.37 m length; the front at the side's"
          % (sp, ss))

    def st(x):
        return (x - nose) / sp

    print("\nCROSS-CHECKS the scales were not set from")
    report("span, plan", plan_span / sp, SPAN_M)
    at = int(round(nose + 8.0 * sp))
    body = [r for r in acaps.runs(np.nonzero(plan[:, at])[0]) if r[0] <= cy <= r[1]][0]
    report("fuselage width at station 8, plan", (body[1] - body[0] + 1) / sp, WIDTH_M)
    report("height, side (fin tip over the tyres)", (ground - sy.min()) / ss, HEIGHT_M)
    report("height, front", (fground - fy.min()) / sf, HEIGHT_M)
    report("span, front, at the side's scale (drawn short)", front_span / sf, SPAN_M)
    fw = max([q[1] - q[0] + 1 for y in range(int(fground - 4.5 * sf), int(fground - 2.9 * sf))
              for q in acaps.runs(np.nonzero(front[y])[0]) if q[0] <= fcx <= q[1] and q[1] - q[0] < 0.2 * front_span])
    report("fuselage width over the sponsons, front, at the side's scale", fw / sf, WIDTH_M)
    low = np.array([side[:, x].nonzero()[0].max() if side[:, x].any() else 0 for x in range(side.shape[1])])
    wheels = [((a + b) / 2.0 - snose) / ss for a, b in acaps.runs(np.nonzero(low >= ground - 4)[0])]
    print("  side's tyre contacts at stations %s" % ["%.2f" % w for w in wheels])
    report("nose gear aft of the nose, side", wheels[0], NOSE_GEAR_M)
    report("wheelbase, side (to the mains' middle)", (wheels[1] + wheels[-1]) / 2.0 - wheels[0], WHEELBASE_M)
    lowf = np.array([front[:, x].nonzero()[0].max() if front[:, x].any() else 0 for x in range(front.shape[1])])
    contacts = [((a + b) / 2.0 - fcx) / sf for a, b in acaps.runs(np.nonzero(lowf >= fground - 4)[0])]
    print("  front's tyre contacts at %s m out" % ["%+.2f" % c for c in contacts])
    report("main gear track, front (drawn narrow)", contacts[-1] - contacts[0], TRACK_M)

    print("\nPLAN outline: runs out from the centreline at each half metre")
    for station in np.arange(0.0, LENGTH_M + 0.01, 0.5):
        x = min(int(round(nose + station * sp)), px.max())
        c = np.nonzero(plan[:, x])[0]
        print("  %5.2f " % station + " ".join("[%+.2f,%+.2f]" % ((cy - b) / sp, (cy - a) / sp) for a, b in acaps.runs(c)))

    print("\nPLAN rows: the runs at each half metre out, starboard (up the page, with the optional tank) and port")
    for out in np.arange(0.0, 20.6, 0.5):
        line = []
        for sign in (1, -1):
            y = int(round(cy - sign * out * sp))
            if 0 <= y < plan.shape[0]:
                line.append(" ".join("[%.2f,%.2f]" % (st(a), st(b)) for a, b in acaps.runs(np.nonzero(plan[y])[0])))
        print("  %5.2f  S %s   P %s" % (out, line[0], line[1] if len(line) > 1 else ""))

    print("\nSIDE silhouette over the tyres' bottom at each half metre (runs), at the side's own scale")
    for station in np.arange(0.0, LENGTH_M + 0.01, 0.5):
        x = min(int(round(snose + station * ss)), sx.max())
        c = np.nonzero(side[:, x])[0]
        print("  %5.2f " % station + " ".join("[%.2f,%.2f]" % ((ground - b) / ss, (ground - a) / ss)
                                             for a, b in acaps.runs(c)))
    print("\nSIDE rows from 4 m up: the runs at each quarter metre (the fin)")
    for h in np.arange(4.0, 12.0, 0.25):
        y = int(round(ground - h * ss))
        print("  %5.2f " % h + " ".join("[%.2f,%.2f]" % ((a - snose) / ss, (b - snose) / ss)
                                       for a, b in acaps.runs(np.nonzero(side[y])[0])))

    print("\nFRONT view at the side's scale: runs out from the centre at each quarter metre over the tyres")
    for h in np.arange(0.0, 12.5, 0.25):
        y = int(round(fground - h * sf))
        print("  %5.2f " % h + " ".join("[%+.2f,%+.2f]" % ((a - fcx) / sf, (b - fcx) / sf)
                                       for a, b in acaps.runs(np.nonzero(front[y])[0])))


if __name__ == "__main__":
    main()
