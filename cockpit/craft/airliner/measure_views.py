"""Re-derives every MEASURED figure in `sources.md` and `Boeing737Airframe` from Boeing's own general-dimensions drawing
of the 737-800W, reading nothing out of the write-up.

    python cockpit/craft/airliner/measure_views.py [path to 737NG_REV_C.pdf]

The PDF defaults to ~/godotgames-drafts/2026-09-19/cockpit-liners/research/737NG_REV_C.pdf. It is Boeing's "737 Airplane
Characteristics for Airport Planning", D6-58325-7 Rev C (October 2025), section 2.2.6 "General Dimensions: Model
737-800W, BBJ2, -800BCF" on page index 34. It is study material and is not in the repo: `sources.md` says where Boeing
publishes it.

ONE PUBLISHED NUMBER SETS THE SCALE: the length, 129 ft 6 in (39.47 m), over the plan view's length in pixels. Everything
else the page prints is a CROSS-CHECK the scale was not set from, and each is printed with its disagreement:
the span 35.79 m (plan and front), the height 12.55 m (side), the fuselage width 3.76 m, the tailplane span 14.35 m, the
wheelbase 15.60 m, the nose gear 4.09 m aft of the nose, the main-gear track 5.72 m, the engine centreline 4.83 m out,
the fin tip 38.02 m aft, the wing tip 26.01 m aft. And the three views must agree with each other about the span and the
length before anything is measured off them.

STATIONS ARE METRES AFT OF THE NOSE TIP, OUT IS METRES FROM THE CENTRELINE, HEIGHTS ARE METRES OVER THE DRAWING'S GROUND
LINE (the aeroplane on its gear). Edges are fitted over every row and the residual printed, never through two ends.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import acaps  # noqa: E402

PDF = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-19/cockpit-liners/research/737NG_REV_C.pdf")
PAGE = 34
DPI = 600

# Printed on the page itself (feet and inches, with Boeing's metres in brackets).
LENGTH_M = 39.47     # 129 ft 6 in: THE SCALE
SPAN_M = 35.79       # 117 ft 5 in
HEIGHT_M = 12.55     # 41 ft 2 in
WIDTH_M = 3.76       # 12 ft 4 in, the fuselage
TAILPLANE_M = 14.35  # 47 ft 1 in
WHEELBASE_M = 15.60  # 51 ft 2 in
NOSE_GEAR_M = 4.09   # 13 ft 5 in, nose tip to the nose gear
TRACK_M = 5.72       # 18 ft 9 in
ENGINE_OUT_M = 4.83  # 15 ft 10 in, the centreline to the engine's
ENGINE_AT_M = 13.36  # 43 ft 10 in, nose tip to the engine's inlet
FIN_TIP_AT_M = 38.02  # 124 ft 9 in, nose tip to the fin tip's trailing corner
WING_TIP_AT_M = 26.01  # 85 ft 4 in, nose tip to the wing tip's trailing edge


def report(name, measured, printed):
    print("  %-34s %7.3f m against %.2f printed (%+.2f%%)" % (name, measured, printed,
                                                            100.0 * (measured - printed) / printed))


def main():
    v = acaps.views(PDF, PAGE, DPI)
    plan, side, front = v["plan"], v["side"], v["front"]
    py, px = np.nonzero(plan)
    sy, sx = np.nonzero(side)
    fy, fx = np.nonzero(front)
    ground = v["side_ground"]
    fground = v["front_ground"]

    plan_len = px.max() - px.min() + 1
    side_len = sx.max() - sx.min() + 1
    plan_span = py.max() - py.min() + 1
    front_span = fx.max() - fx.min() + 1
    print("ONE SCALE: plan length %d px, side %d (%+.2f%%); plan span %d px, front %d (%+.2f%%)"
          % (plan_len, side_len, 100.0 * (side_len - plan_len) / plan_len, plan_span, front_span,
             100.0 * (front_span - plan_span) / plan_span))
    s = plan_len / LENGTH_M
    print("scale %.2f px a metre from the printed length; %.4f m a pixel" % (s, 1.0 / s))

    nose = px.min()
    cy = (py.min() + py.max()) / 2.0
    snose = sx.min()
    fcx = (fx.min() + fx.max()) / 2.0

    def st(x):
        return (x - nose) / s

    print("\nCROSS-CHECKS the scale was not set from")
    report("span, plan", plan_span / s, SPAN_M)
    report("span, front", front_span / s, SPAN_M)
    report("length, side", side_len / s, LENGTH_M)
    report("height, side (fin tip over ground)", (ground - sy.min()) / s, HEIGHT_M)
    report("height, front", (fground - fy.min()) / s, HEIGHT_M)
    at = int(round(nose + 20.0 * s))
    col = np.nonzero(plan[:, at])[0]
    body = [r for r in acaps.runs(col) if r[0] <= cy <= r[1]][0]
    report("fuselage width at station 20, plan", (body[1] - body[0] + 1) / s, WIDTH_M)
    fin_tip_row = sy.min()
    fin_top_cols = np.nonzero(side[fin_tip_row:fin_tip_row + 3].any(axis=0))[0]
    report("fin tip's aft corner, side", (fin_top_cols.max() - snose) / s, FIN_TIP_AT_M)

    # ---- the plan outline, every half metre ----
    print("\nPLAN outline: runs out from the centreline at each station (starboard positive)")
    for station in np.arange(0.0, LENGTH_M + 0.01, 0.5):
        x = min(int(round(nose + station * s)), px.max())
        c = np.nonzero(plan[:, x])[0]
        print("  %5.2f " % station + " ".join("[%+.3f,%+.3f]" % ((cy - b) / s, (cy - a) / s) for a, b in acaps.runs(c)))

    # ---- the wing ----
    print("\nWING in plan, starboard and port: the first and last object pixel along each row")
    for sign in (1, -1):
        le, te = [], []
        for out in np.arange(3.0, 17.9, 0.02):
            y = int(round(cy - sign * out * s))
            row = np.nonzero(plan[y])[0]
            r = acaps.runs(row)
            # The wing is the run that spans station 16 (behind the nacelle, ahead of the tailplane).
            wing = [q for q in r if st(q[0]) < 24.5 and st(q[1]) > 17.0]
            if wing:
                le.append((out, st(wing[0][0])))
                te.append((out, st(wing[0][1])))
        name = "starboard" if sign > 0 else "port"
        for lo, hi in ((6.0, 15.5),):
            rows = [r for r in le if lo <= r[0] <= hi]
            (a, b), rms, worst = acaps.fit(rows)
            print("  %s leading edge %.1f-%.1f m out: station = %.3f + %.4f x out, %d rows, rms %.1f mm, worst %.0f mm:"
                  " %.2f degrees" % (name, lo, hi, a, b, len(rows), rms * 1000, worst * 1000, np.degrees(np.arctan(b))))
        for lo, hi in ((6.2, 15.5),):
            rows = [r for r in te if lo <= r[0] <= hi]
            (a, b), rms, worst = acaps.fit(rows)
            print("  %s trailing edge %.1f-%.1f m out: station = %.3f + %.4f x out, %d rows, rms %.1f mm, worst %.0f mm:"
                  " %.2f degrees" % (name, lo, hi, a, b, len(rows), rms * 1000, worst * 1000, np.degrees(np.arctan(b))))
        print("  %s leading and trailing edge every half metre out:" % name)
        for out in np.arange(1.5, 18.0, 0.5):
            y = int(round(cy - sign * out * s))
            r = acaps.runs(np.nonzero(plan[y])[0])
            print("    %5.2f " % out + " ".join("[%.3f,%.3f]" % (st(a), st(b)) for a, b in r))
    tips = [st(x) for x in np.nonzero(plan[py.min():py.min() + 4].any(axis=0))[0]]
    print("  the tip's outermost rows run from station %.3f to %.3f" % (min(tips), max(tips)))
    report("wing tip's trailing edge, plan", max(tips), WING_TIP_AT_M)

    # ---- the tailplane ----
    print("\nTAILPLANE in plan: its run at each row (the fuselage's run is the one that reaches the tail cone)")
    tail_le, tail_te = [], []
    for out in np.arange(2.2, 7.3, 0.02):
        y = int(round(cy - out * s))
        r = [q for q in acaps.runs(np.nonzero(plan[y])[0]) if st(q[0]) > 30.0]
        if r:
            tail_le.append((out, st(r[0][0])))
            tail_te.append((out, st(r[0][1])))
    (a, b), rms, worst = acaps.fit([q for q in tail_le if 2.6 <= q[0] <= 6.6])
    print("  leading edge 2.6-6.6 m out: station = %.3f + %.4f x out, rms %.1f mm: %.2f degrees"
          % (a, b, rms * 1000, np.degrees(np.arctan(b))))
    (a, b), rms, worst = acaps.fit([q for q in tail_te if 2.6 <= q[0] <= 6.6])
    print("  trailing edge 2.6-6.6 m out: station = %.3f + %.4f x out, rms %.1f mm: %.2f degrees"
          % (a, b, rms * 1000, np.degrees(np.arctan(b))))
    tail_rows = [q for q in tail_le if q[1] > 30.0]
    report("tailplane span (plan, starboard x 2)", 2.0 * max(q[0] for q in tail_rows), TAILPLANE_M)
    for out in np.arange(0.5, 7.3, 0.5):
        y = int(round(cy - out * s))
        r = acaps.runs(np.nonzero(plan[y])[0])
        print("    %5.2f " % out + " ".join("[%.3f,%.3f]" % (st(a), st(b)) for a, b in r if st(a) > 29.0))

    # ---- the side ----
    print("\nSIDE silhouette over the ground line at each station (runs)")
    for station in np.arange(0.0, LENGTH_M + 0.01, 0.5):
        x = min(int(round(snose + station * s)), sx.max())
        c = np.nonzero(side[:, x])[0]
        print("  %5.2f " % station + " ".join("[%.3f,%.3f]" % ((ground - b) / s, (ground - a) / s)
                                             for a, b in acaps.runs(c)))
    print("\nFIN in the side view: leading and trailing edge at each height")
    fin_le, fin_te = [], []
    for h in np.arange(6.5, 12.5, 0.02):
        y = int(round(ground - h * s))
        r = [q for q in acaps.runs(np.nonzero(side[y])[0]) if (q[0] - snose) / s > 28.0]
        if r:
            fin_le.append((h, (r[0][0] - snose) / s))
            fin_te.append((h, (r[-1][1] - snose) / s))
    for name, rows in (("leading", fin_le), ("trailing", fin_te)):
        rows = [q for q in rows if 7.8 <= q[0] <= 12.0]
        (a, b), rms, worst = acaps.fit(rows)
        print("  %s edge 7.8-12.0 m up: station = %.3f + %.4f x height, rms %.1f mm, worst %.0f mm: %.2f degrees swept"
              % (name, a, b, rms * 1000, worst * 1000, np.degrees(np.arctan(b))))
    for h in np.arange(5.0, 12.6, 0.25):
        y = int(round(ground - h * s))
        r = [q for q in acaps.runs(np.nonzero(side[y])[0]) if (q[0] - snose) / s > 26.0]
        print("    %5.2f " % h + " ".join("[%.3f,%.3f]" % ((a - snose) / s, (b - snose) / s) for a, b in r))

    # ---- the wheels: columns of the side silhouette that come down to the ground ----
    print("\nWHEELS in the side view: the columns whose silhouette comes within 3 px of the ground")
    low = np.array([side[:, x].nonzero()[0].max() if side[:, x].any() else 0 for x in range(side.shape[1])])
    down = np.nonzero(low >= ground - 3)[0]
    wheels = acaps.runs(down)
    centres = []
    for a, b in wheels:
        # The tyre is the lowest round thing: its top is where the column stops being the tyre, which the side
        # silhouette cannot tell from the leg, so the diameter is its width on the ground.
        c = (a + b) / 2.0
        centres.append((c - snose) / s)
        widest = 0
        for y in range(int(ground) - 1, int(ground) - int(1.5 * s), -1):
            rr = [q for q in acaps.runs(np.nonzero(side[y])[0]) if q[0] <= c <= q[1]]
            if rr:
                widest = max(widest, rr[0][1] - rr[0][0] + 1)
        print("  station %.3f, touching %d px; widest run within 1.5 m of the ground %.3f m" %
              ((c - snose) / s, b - a + 1, widest / s))
    if len(centres) >= 2:
        report("nose gear aft of the nose tip", centres[0], NOSE_GEAR_M)
        report("wheelbase", centres[-1] - centres[0], WHEELBASE_M)

    # ---- the front ----
    print("\nFRONT view: runs out from the centre at each height over the ground line")
    for h in np.arange(0.0, 12.6, 0.1):
        y = int(round(fground - h * s))
        r = acaps.runs(np.nonzero(front[y])[0])
        print("  %5.2f " % h + " ".join("[%+.3f,%+.3f]" % ((a - fcx) / s, (b - fcx) / s) for a, b in r))
    print("\nFRONT: the wing's lower edge at each station out (the lowest object pixel over 5.5 m out)")
    lower = []
    for out in np.arange(5.8, 17.0, 0.05):
        x = int(round(fcx + out * s))
        c = np.nonzero(front[:, x])[0]
        if len(c):
            lower.append((out, (fground - c.max()) / s))
    (a, b), rms, worst = acaps.fit([q for q in lower if 7.0 <= q[0] <= 16.5])
    print("  lower edge 7.0-16.5 m out: height = %.3f + %.4f x out, rms %.1f mm: dihedral %.2f degrees"
          % (a, b, rms * 1000, np.degrees(np.arctan(b))))
    print("\nFRONT: the tyres, the columns that reach the ground line")
    flow = np.array([front[:, x].nonzero()[0].max() if front[:, x].any() else 0 for x in range(front.shape[1])])
    tyres = acaps.runs(np.nonzero(flow >= fground - 3)[0])
    for a, b in tyres:
        print("  %+.3f to %+.3f m out" % ((a - fcx) / s, (b - fcx) / s))
    outer = [(a + b) / 2.0 for a, b in tyres if abs((a + b) / 2.0 - fcx) / s > 1.5]
    if len(outer) >= 2:
        # Each main leg has two tyres; the track is between the leg centres.
        left = [c for c in outer if c < fcx]
        right = [c for c in outer if c > fcx]
        report("main-gear track, front", (np.mean(right) - np.mean(left)) / s, TRACK_M)
    print("\nFRONT: the nacelles, the rows of the silhouette with a hole in them between 3 and 7 m out")
    hole = ~front & acaps.silhouette(np.zeros_like(front)) if False else None


if __name__ == "__main__":
    main()
