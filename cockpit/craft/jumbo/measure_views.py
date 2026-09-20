"""Re-derives every MEASURED figure in `sources.md` and `Boeing747Airframe` from Boeing's own general-dimensions drawing
of the 747-400, reading nothing out of the write-up.

    python cockpit/craft/jumbo/measure_views.py [path to 747-400_acaps.pdf]

The PDF defaults to ~/godotgames-drafts/2026-09-19/cockpit-liners/research/747-400_acaps.pdf. It is Boeing's "747-400
Airplane Characteristics for Airport Planning", D6-58326-1 Rev F (December 2024), section 2.2.1 "General Dimensions:
Model 747-400, -400 Combi, -400ER" on page index 30. It is study material and is not in the repo: `sources.md` says where
Boeing publishes it. `craft/airliner/acaps.py` reads it, as it reads the 737's.

ONE PUBLISHED NUMBER SETS THE SCALE: the overall length, 231 ft 10.25 in (70.67 m), over the SIDE view's length in pixels
(the side view's is the overall length's own dimension line). Everything else the page prints is a CROSS-CHECK the scale
was not set from: the span (211 ft 5 in, 64.44 m, in the jig; 213 ft 0 in, 64.92 m, at maximum gross weight), the
fuselage's width 6.50 m, the tailplane's span 22.17 m, the engines' centrelines 11.68 and 21 m out, their inlets 23.01
and 32.16 m aft (CF6-80C2), the nose gear 7.75 m aft, the wheelbase to the body gear 25.60 m, the body gear's track 3.84 m
and the wing gear's 11.00 m. And the three views must agree with each other before anything is measured off them.

STATIONS ARE METRES AFT OF THE NOSE TIP, OUT IS METRES FROM THE CENTRELINE, HEIGHTS ARE METRES OVER THE DRAWING'S GROUND
LINE (the aeroplane on its gear). Edges are fitted over every row and the residual printed, never through two ends.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "airliner"))
import acaps  # noqa: E402

PDF = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-19/cockpit-liners/research/747-400_acaps.pdf")
PAGE = 30
DPI = 600


# Printed on the page itself (feet and inches, with Boeing's metres in brackets).
LENGTH_M = 70.67        # 231 ft 10.25 in: THE SCALE, on the side view
SPAN_JIG_M = 64.44      # 211 ft 5 in, in the jig
SPAN_MGW_M = 64.92      # 213 ft 0 in, at maximum gross weight (full fuel)
WIDTH_M = 6.50          # 21 ft 4 in, the fuselage
TAILPLANE_M = 22.17     # 72 ft 9 in
INBOARD_OUT_M = 11.68   # 38 ft 4 in, the centreline to the inboard engine's
OUTBOARD_OUT_M = 21.0   # 69 ft, to the outboard's
INBOARD_AT_M = 23.01    # 75 ft 6 in, nose to the inboard CF6-80C2's inlet
OUTBOARD_AT_M = 32.16   # 105 ft 6 in, to the outboard's
NOSE_GEAR_M = 7.75      # 25 ft 5 in
WHEELBASE_M = 25.60     # 84 ft 0 in, the nose gear to the body gear
BODY_TRACK_M = 3.84     # 12 ft 7 in
WING_TRACK_M = 11.00    # 36 ft 1 in
HEIGHT_M = 19.41        # Wikipedia; the ground-clearance table's K is 18.80 to 19.51


def report(name, measured, printed):
    print("  %-40s %7.3f m against %.2f printed (%+.2f%%)" % (name, measured, printed,
                                                            100.0 * (measured - printed) / printed))


def main():
    v = acaps.views(PDF, PAGE, DPI)
    plan, side, front = v["plan"], v["side"], v["front"]
    py, px = np.nonzero(plan)
    sy, sx = np.nonzero(side)
    fy, fx = np.nonzero(front)
    ground = v["side_ground"]
    fground = v["front_ground"]
    side_len = sx.max() - sx.min() + 1
    plan_len = px.max() - px.min() + 1
    plan_span = py.max() - py.min() + 1
    front_span = fx.max() - fx.min() + 1
    print("ONE SCALE: side length %d px, plan %d (%+.2f%%); plan span %d px, front %d (%+.2f%%)"
          % (side_len, plan_len, 100.0 * (plan_len - side_len) / side_len, plan_span, front_span,
             100.0 * (front_span - plan_span) / plan_span))
    s = side_len / LENGTH_M
    print("scale %.3f px a metre from the printed length; %.4f m a pixel" % (s, 1.0 / s))
    nose = px.min()
    cy = (py.min() + py.max()) / 2.0
    snose = sx.min()
    fcx = (fx.min() + fx.max()) / 2.0

    def st(x):
        return (x - nose) / s

    print("\nCROSS-CHECKS the scale was not set from")
    report("span, plan, against the jig", plan_span / s, SPAN_JIG_M)
    report("span, plan, against max gross weight", plan_span / s, SPAN_MGW_M)
    report("span, front, against max gross weight", front_span / s, SPAN_MGW_M)
    report("length, plan", plan_len / s, LENGTH_M)
    report("height, side (fin tip over ground)", (ground - sy.min()) / s, HEIGHT_M)
    report("height, front", (fground - fy.min()) / s, HEIGHT_M)
    at = int(round(nose + 18.0 * s))
    body = [r for r in acaps.runs(np.nonzero(plan[:, at])[0]) if r[0] <= cy <= r[1]][0]
    report("fuselage width at station 18, plan", (body[1] - body[0] + 1) / s, WIDTH_M)

    print("\nPLAN outline: runs out from the centreline at each station")
    for station in np.arange(0.0, LENGTH_M + 0.01, 1.0):
        x = min(int(round(nose + station * s)), px.max())
        c = np.nonzero(plan[:, x])[0]
        print("  %5.1f " % station + " ".join("[%+.2f,%+.2f]" % ((cy - b) / s, (cy - a) / s) for a, b in acaps.runs(c)))

    print("\nSIDE silhouette over the ground line at each station (runs)")
    for station in np.arange(0.0, LENGTH_M + 0.01, 1.0):
        x = min(int(round(snose + station * s)), sx.max())
        c = np.nonzero(side[:, x])[0]
        print("  %5.1f " % station + " ".join("[%.2f,%.2f]" % ((ground - b) / s, (ground - a) / s)
                                             for a, b in acaps.runs(c)))

    print("\nWING in plan, starboard: the first and last object pixel of the wing's run")
    le, te = [], []
    for out in np.arange(3.5, 32.5, 0.05):
        y = int(round(cy - out * s))
        # The wing is the AFTMOST run that starts past station 15 and ends short of the tailplane: a nacelle's run, where
        # it is separate, is ahead of it.
        r = [q for q in acaps.runs(np.nonzero(plan[y])[0]) if st(q[0]) > 15.0 and st(q[1]) < 55.0]
        if r:
            le.append((out, st(r[-1][0])))
            te.append((out, st(r[-1][1])))
    for lo, hi in ((6.0, 11.0), (13.0, 19.5), (22.5, 30.0)):
        rows = [q for q in le if lo <= q[0] <= hi]
        (a, b), rms, worst = acaps.fit(rows)
        print("  leading edge %.1f-%.1f m out: station = %.3f + %.4f x out, %d rows, rms %.1f mm, worst %.0f mm: %.2f degrees"
              % (lo, hi, a, b, len(rows), rms * 1000, worst * 1000, np.degrees(np.arctan(b))))
    for lo, hi in ((4.0, 8.0), (13.0, 19.0), (22.0, 30.0)):
        rows = [q for q in te if lo <= q[0] <= hi]
        (a, b), rms, worst = acaps.fit(rows)
        print("  trailing edge %.1f-%.1f m out: station = %.3f + %.4f x out, %d rows, rms %.1f mm: %.2f degrees"
              % (lo, hi, a, b, len(rows), rms * 1000, np.degrees(np.arctan(b))))
    print("  every metre out (all runs past station 20):")
    for out in np.arange(3.0, 33.0, 1.0):
        y = int(round(cy - out * s))
        r = acaps.runs(np.nonzero(plan[y])[0])
        print("    %5.1f " % out + " ".join("[%.2f,%.2f]" % (st(a), st(b)) for a, b in r if st(b) > 20.0))
    tips = [st(x) for x in np.nonzero(plan[py.min():py.min() + 3].any(axis=0))[0]]
    print("  the tip's outermost rows run from station %.2f to %.2f" % (min(tips), max(tips)))

    print("\nTAILPLANE in plan, starboard, every half metre out (runs aft of station 55)")
    for out in np.arange(1.0, 11.5, 0.5):
        y = int(round(cy - out * s))
        r = acaps.runs(np.nonzero(plan[y])[0])
        print("    %5.1f " % out + " ".join("[%.2f,%.2f]" % (st(a), st(b)) for a, b in r if st(a) > 55.0))
    tail_le = []
    tail_te = []
    tip_out = 0.0
    for out in np.arange(3.0, 11.5, 0.05):
        y = int(round(cy - out * s))
        r = [q for q in acaps.runs(np.nonzero(plan[y])[0]) if st(q[0]) > 55.0]
        if r:
            tail_le.append((out, st(r[0][0])))
            tail_te.append((out, st(r[-1][1])))
            tip_out = out
    (a, b), rms, _ = acaps.fit([q for q in tail_le if 4.0 <= q[0] <= 10.0])
    print("  leading edge 4-10 m out: station = %.3f + %.4f x out, rms %.1f mm: %.2f degrees"
          % (a, b, rms * 1000, np.degrees(np.arctan(b))))
    (a, b), rms, _ = acaps.fit([q for q in tail_te if 4.0 <= q[0] <= 10.0])
    print("  trailing edge 4-10 m out: station = %.3f + %.4f x out, rms %.1f mm: %.2f degrees"
          % (a, b, rms * 1000, np.degrees(np.arctan(b))))
    report("tailplane span (plan, starboard x 2)", 2.0 * tip_out, TAILPLANE_M)

    print("\nFIN in the side view: leading and trailing edge at each height")
    fin_le, fin_te = [], []
    for h in np.arange(9.0, 19.5, 0.02):
        y = int(round(ground - h * s))
        r = [q for q in acaps.runs(np.nonzero(side[y])[0]) if (q[0] - snose) / s > 50.0]
        if r:
            fin_le.append((h, (r[0][0] - snose) / s))
            fin_te.append((h, (r[-1][1] - snose) / s))
    for name, rows in (("leading", fin_le), ("trailing", fin_te)):
        rows = [q for q in rows if 12.0 <= q[0] <= 18.8]
        (a, b), rms, worst = acaps.fit(rows)
        print("  %s edge 12.0-18.8 m up: station = %.3f + %.4f x height, rms %.1f mm, worst %.0f mm: %.2f degrees"
              % (name, a, b, rms * 1000, worst * 1000, np.degrees(np.arctan(b))))
    for h in np.arange(8.0, 19.6, 0.5):
        y = int(round(ground - h * s))
        r = [q for q in acaps.runs(np.nonzero(side[y])[0]) if (q[0] - snose) / s > 45.0]
        print("    %5.2f " % h + " ".join("[%.2f,%.2f]" % ((a - snose) / s, (b - snose) / s) for a, b in r))

    print("\nWHEELS in the side view: runs of columns whose silhouette comes within 3 px of the ground")
    low = np.array([side[:, x].nonzero()[0].max() if side[:, x].any() else 0 for x in range(side.shape[1])])
    for a, b in acaps.runs(np.nonzero(low >= ground - 3)[0]):
        print("  station %.2f to %.2f" % ((a - snose) / s, (b - snose) / s))

    print("\nFRONT view: runs out from the centre at each height over the ground line")
    for h in np.arange(0.0, 19.6, 0.25):
        y = int(round(fground - h * s))
        r = acaps.runs(np.nonzero(front[y])[0])
        print("  %5.2f " % h + " ".join("[%+.2f,%+.2f]" % ((a - fcx) / s, (b - fcx) / s) for a, b in r))
    lower = []
    for out in np.arange(8.0, 31.0, 0.05):
        x = int(round(fcx + out * s))
        c = np.nonzero(front[:, x])[0]
        if len(c):
            lower.append((out, (fground - c.max()) / s))
    for lo, hi in ((8.0, 10.0), (13.5, 19.0), (23.0, 30.0)):
        (a, b), rms, _ = acaps.fit([q for q in lower if lo <= q[0] <= hi])
        print("  wing's lower edge %.1f-%.1f m out: height = %.3f + %.4f x out, rms %.1f mm: %.2f degrees"
              % (lo, hi, a, b, rms * 1000, np.degrees(np.arctan(b))))


if __name__ == "__main__":
    main()
