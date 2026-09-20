"""Re-derives every MEASURED figure in `sources.md` and `P47Airframe` from the two P-47 drawings alone, reading nothing out
of the write-up.

    python cockpit/craft/p47/measure_views.py [folder holding the two drawings]

The folder defaults to ~/Desktop/godotgames-drafts/2026-09-19/cockpit-warbirds/research/. The drawings, both study
material and not in the repo:
- [AN] the USAAF's three-view from AN 01-65BC-2 p.3, "Republic P-47 Thunderbolt 3-view line drawing.png" on Wikimedia
  Commons, {{PD-USGov-Military}}, 1724 x 2525 px, with its printed dimensions. It draws the RAZORBACK RP-47B, and its
  notes give the P-47C-1-and-later fuselage: 8 in longer ahead of the firewall. It is the authority for the WING, the
  TAIL, the GEAR and the ENVELOPE, which the bubble-top D-30 shares.
- [NACA] NACA RM L8A06 (1948), Figure 1, "Three-view layout of the P-47D-30 airplane", NTRS 20090022749, public domain,
  the embedded 2552 x 2999 px 1-bit scan. It is the authority for WHAT THE D-30 CHANGED: the bubble canopy, the cut-down
  spine behind it, the dorsal fillet and the 13 ft Curtiss propeller. It is a reduced sketch, and it disagrees with itself
  (see the checks it prints), so it gives SHAPES scaled to [AN]'s stations, not a scale of its own.

[AN]'s VIEWS: the plan with the nose DOWN (starboard on the LEFT), the front with starboard on the viewer's left, the side
with the nose to the LEFT (the port side). Neither sheet has a dimension-free copy, so each view is FENCED by a hull drawn
by hand a few pixels outside the aeroplane (`tools/three_view.py`, `hull`), and the lines that still cross inside the
fence are taken out between hand-picked ends, before the fill.

STATIONS ARE METRES AFT OF THE SPINNER'S TIP; HEIGHTS ARE METRES OVER THE THRUST LINE; OUT is metres to starboard. Each
view is scaled by its own printed dimension and checked on another (`learnings/2026-09-19-liners.md`).
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
import three_view as tv  # noqa: E402

FOLDER = os.path.expanduser("~/Desktop/godotgames-drafts/2026-09-19/cockpit-warbirds/research")
AN_SHEET = "p47bc_an01-65bc-2.png"
NACA_SHEET = "p47d30_naca_fig1.png"
INCH = 0.0254
SPAN_M = (40 * 12 + 9 + 5.0 / 16.0) * INCH       # 12.428: printed on [AN]'s front view
TAILPLANE_M = (16 * 12 + 3.0 / 32.0) * INCH      # 4.879: printed on [AN]'s plan
LENGTH_B_M = (35 * 12 + 5 + 3.0 / 16.0) * INCH   # 10.800: printed on [AN]'s plan, the RP-47B
LENGTH_C1_M = (36 * 12 + 1 + 3.0 / 16.0) * INCH  # 11.003: [AN]'s note, P-47C-1 and later
TRACK_M = (15 * 12 + 7) * INCH                   # 4.750: printed on [AN]'s front view
HEIGHT_M = (13 * 12 + 8 + 3.0 / 16.0) * INCH     # 4.171: printed on [AN]'s side, the fin's top over the level ground
FIN_OVER_THRUST_M = (6 * 12 + 10 + 1.0 / 32.0) * INCH   # 2.083: printed on [AN]'s side
PROP_B_M = (12 * 12 + 2) * INCH                  # 3.708: printed on [AN]'s front, the B's propeller
WING_TO_TAIL_M = (9 * 12 + 2) * INCH             # 2.794: printed on [AN]'s plan, the 9 ft 2 in
GROUND_RAKE_DEG = 12.0                           # printed on both sheets

# [AN]'s VIEWS as (row0, row1, col0, col1) boxes of the sheet, a seed (row, col) inside each fuselage, and its FENCE, a
# hull (col, row) drawn a few pixels outside the aeroplane off gridded crops at x0.85.
PLAN_BOX = (60, 1360, 100, 1600)
PLAN_SEED = (700, 840)
PLAN_FENCE = [(545, 85), (830, 65), (860, 65), (1150, 85), (1150, 232), (1000, 282), (910, 322), (935, 690), (1100, 720),
              (1300, 760), (1500, 820), (1565, 880), (1570, 980), (1500, 1022), (1200, 1045), (932, 1060), (932, 1062),
              (932, 1296), (1010, 1300), (1010, 1326), (870, 1331), (860, 1372), (820, 1372), (810, 1331), (690, 1326),
              (690, 1300), (765, 1296), (765, 1062), (700, 1052), (420, 1032), (170, 1015), (122, 980), (122, 880),
              (200, 820), (400, 760), (590, 720), (758, 690), (775, 322), (690, 282), (545, 232)]
SIDE_BOX = (1920, 2520, 190, 1600)
SIDE_SEED = (2200, 800)
SIDE_FENCE = [(205, 2160), (265, 2140), (268, 2010), (315, 2010), (315, 2080), (420, 2065), (580, 2060), (635, 2030),
              (835, 2035), (900, 2055), (912, 1965), (950, 1965), (952, 2065), (1150, 2098), (1232, 2118), (1372, 1918),
              (1425, 1912), (1470, 1935), (1505, 2035), (1515, 2165), (1490, 2238), (1310, 2268), (1292, 2318),
              (1210, 2322), (1195, 2295), (1000, 2335), (800, 2360), (600, 2372), (585, 2385), (585, 2490), (425, 2490),
              (425, 2385), (325, 2365), (300, 2345), (300, 2365), (265, 2365), (265, 2210), (205, 2210)]
FRONT_BOX = (1400, 1950, 0, 1640)
FRONT_SEED = (1680, 848)
FRONT_FENCE = [(118, 1605), (560, 1640), (560, 1580), (650, 1520), (700, 1460), (800, 1430), (900, 1430), (990, 1470),
               (1050, 1560), (1130, 1640), (1570, 1598), (1575, 1632), (1150, 1692), (1135, 1700), (1135, 1935),
               (1095, 1935), (1095, 1760), (1050, 1760), (950, 1830), (848, 1845), (750, 1830), (640, 1760),
               (605, 1760), (605, 1935), (565, 1935), (565, 1700), (120, 1640)]
# [NACA]'s SIDE VIEW (the 2552 x 2999 1-bit scan): its box, a seed and its fence. Its outlines have gaps, so it is closed
# by 3 px before the fill. Registered on [AN]'s: the fin's top and the belly under the wing at [AN]'s heights.
NACA_SIDE_BOX = (2060, 2620, 660, 1940)
NACA_SIDE_SEED = (2380, 1200)
NACA_SIDE_FENCE = [(688, 2320), (716, 2310), (716, 2090), (770, 2090), (770, 2275), (900, 2250), (1060, 2228), (1120, 2190),
                   (1180, 2188), (1280, 2215), (1320, 2232), (1690, 2232), (1790, 2072), (1845, 2070), (1915, 2180),
                   (1925, 2310), (1900, 2362), (1700, 2380), (1420, 2440), (1320, 2470), (1070, 2495), (1060, 2500),
                   (1060, 2612), (940, 2612), (940, 2500), (870, 2490), (775, 2470), (770, 2585), (716, 2585),
                   (716, 2345), (688, 2345)]
FIN_OVER_THRUST_M_DRAWN = 2.073   # [AN]'s side at its heights' scale, printed out below
BELLY_M = -1.120                  # [AN]'s side, under the wing
# LINES INSIDE THE FENCES that are not the aeroplane, (row, col) ends and how far short of each end to stop.
LINES = [
    # [AN]'s plan: the extension lines of the 35 ft 5-3/16 in length (at the fin's tip and the spinner's) and of the
    # 9 ft 2 in, each running from the fuselage's side out past the port wing (the plan's right), found as the rows whose ink
    # runs more than half of the right-hand columns; each taken out from 20 px clear of the fuselage.
    ((80, 875), (80, 1680), 0), ((729, 930), (729, 1640), 0), ((1053, 960), (1053, 1600), 0), ((1332, 880), (1332, 1680), 0),
    # and at the tail: the 18-3/32 in's extension just aft of the port tailplane's trailing edge, the hinge line's run
    # past its tip, and the 3 ft 11-9/16 in's lower extension ahead of it.
    ((103, 1000), (103, 1215), 0), ((158, 1137), (158, 1285), 0), ((298, 950), (298, 1285), 0),
]


def load(name):
    grey = np.asarray(Image.open(os.path.join(FOLDER, name)).convert("L")).astype(int)
    return grey < 128


def views(close=2):
    ink = load(AN_SHEET)
    for start, end, keep in LINES:
        tv.take_out(ink, start, end, keep)
    plan, _ = tv.solid(ink, PLAN_BOX, PLAN_SEED, close, PLAN_FENCE)
    side, _ = tv.solid(ink, SIDE_BOX, SIDE_SEED, close, SIDE_FENCE)
    front, front_all = tv.solid(ink, FRONT_BOX, FRONT_SEED, close, FRONT_FENCE)
    return ink, plan, side, front, front_all


def edges_at(mask, box, index, axis):
    """The runs of `mask` along one sheet row (axis 0) or column (axis 1), in sheet pixels."""
    if axis == 0:
        line = mask[index - box[0], :]
        return [(a0 + box[2], b0 + box[2]) for a0, b0 in tv.runs(np.nonzero(line)[0])]
    line = mask[:, index - box[2]]
    return [(a0 + box[0], b0 + box[0]) for a0, b0 in tv.runs(np.nonzero(line)[0])]


def opened(mask):
    """A silhouette without the pen's stubs: shrunk 3 px and grown back, so a line 6 px wide or less goes."""
    return tv.grow(tv.shrink(mask, 3), 3)


def measure(say=print):
    """Every figure, printed through `say`, and the working kept for `overlay_views.py`."""
    ink0 = load(AN_SHEET)
    ink, plan, side, front, front_all = views()
    op = opened(plan)
    ys, xs = np.nonzero(op)
    ys = ys + PLAN_BOX[0]
    xs = xs + PLAN_BOX[2]
    nose_row = ys.max()
    length_px = nose_row - ys.min() + 1
    tail = ys < 320
    tail_px = xs[tail].max() - xs[tail].min() + 1
    root_px = 1053 - 729
    sp = float(np.mean([length_px / LENGTH_B_M, tail_px / TAILPLANE_M, root_px / WING_TO_TAIL_M]))
    cx = float(np.mean([np.mean(np.nonzero(plan[r - PLAN_BOX[0]])[0]) + PLAN_BOX[2] for r in range(400, 650, 10)]))
    say("PLAN (nose down, starboard LEFT): three printed dimensions give one scale --")
    say("  length spinner to tail %d px for the RP-47B's printed 35 ft 5-3/16 in: %.2f px a metre" % (length_px, length_px / LENGTH_B_M))
    say("  tailplane %d px for the printed 16 ft 0-3/32 in: %.2f px a metre" % (tail_px, tail_px / TAILPLANE_M))
    say("  root chord, the 9 ft 2 in's extension lines at rows 729 and 1053, %d px: %.2f px a metre" % (root_px, root_px / WING_TO_TAIL_M))
    say("  -> %.2f px a metre (%.4f m a pixel); the centreline column %.1f" % (sp, 1.0 / sp, cx))
    wing = (ys > 700) & (ys < 1100)
    span_px = xs[wing].max() - xs[wing].min() + 1
    say("  THE SPAN at that scale: %d px = %.3f m against the printed 40 ft 9-5/16 in, %.3f (%+.2f%%); its halves %.1f and %.1f px"
        % (span_px, span_px / sp, SPAN_M, 100.0 * (span_px / sp / SPAN_M - 1.0), cx - xs[wing].min(), xs[wing].max() - cx))
    st = lambda row: (nose_row - row) / sp
    out = lambda col: (cx - col) / sp      # starboard on the LEFT is positive

    def wing_run(col):
        rr = [r for r in edges_at(op, PLAN_BOX, col, 1) if r[1] > 700 and r[0] < 1100]
        return max(rr, key=lambda q: q[1] - q[0]) if rr else None

    say(chr(10) + "WING in plan every 0.25 m out: [out: leading station - trailing station]")
    for sign in (1, -1):
        rows = []
        o = 0.0
        while o < SPAN_M / 2.0 + 0.05:
            best = wing_run(int(round(cx - sign * o * sp)))
            if best:
                rows.append((o, st(best[1]), st(best[0])))
            o += 0.25
        say("  %s: " % ("starboard" if sign > 0 else "port") + " ".join("%.2f:%.3f-%.3f" % r for r in rows))
    area = 0.0
    for sign in (1, -1):
        best = wing_run(int(round(cx - sign * 0.75 * sp)))
        area += (best[1] - best[0]) / sp * 0.75
        col = int(round(cx - sign * 0.75 * sp))
        while True:
            col -= sign
            best = wing_run(col)
            if best is None:
                break
            area += (best[1] - best[0]) / sp / sp
    say("WING AREA from the drawn planform, the chord at 0.75 m out (clear of the fuselage's 0.68) carried to the centreline: %.2f m2 against the"
        " published 300 sq ft, 27.87 m2 (%+.1f%%)" % (area, 100.0 * (area / 27.87 - 1.0)))

    say(chr(10) + "TAILPLANE in plan every 0.2 m out: [out: leading - trailing]")
    for sign in (1, -1):
        rows = []
        o = 0.0
        while o < 2.6:
            rr = [r for r in edges_at(op, PLAN_BOX, int(round(cx - sign * o * sp)), 1) if r[1] < 330]
            if rr:
                best = max(rr, key=lambda q: q[1] - q[0])
                rows.append((o, st(best[1]), st(best[0])))
            o += 0.2
        say("  %s: " % ("starboard" if sign > 0 else "port") + " ".join("%.1f:%.3f-%.3f" % r for r in rows))

    say(chr(10) + "PLAN, the fuselage's edges every 0.25 m of station (out, starboard first)")
    for station in np.arange(0.0, 11.0, 0.25):
        row = int(round(nose_row - station * sp))
        near = [r for r in edges_at(op, PLAN_BOX, row, 0) if r[0] <= cx <= r[1]]
        if near:
            say("  %5.2f  %+.3f %+.3f" % (station, out(near[0][0]), out(near[0][1])))

    # ---- THE SIDE: its length by the RP-47B's, its heights by its two printed heights ----
    os_ = opened(side)
    sy, sx = np.nonzero(os_)
    sy = sy + SIDE_BOX[0]
    sx = sx + SIDE_BOX[2]
    nose_s = int(sx.min())
    side_len = sx.max() - sx.min() + 1
    ss = side_len / LENGTH_B_M
    fin_row = int(sy.min())
    ground_row = [r for r in range(2430, 2460) if ink0[r, 300:1600].sum() > 500][0]
    thrust_row = float(np.mean([r for r in range(2175, 2200) if ink0[r, 300:1600].sum() > 400]))
    vs = (ground_row - fin_row) / HEIGHT_M
    say(chr(10) + "SIDE: length %d px for the RP-47B's 35 ft 5-3/16 in, %.2f px a metre along it (%+.2f%% against the plan's)"
        % (side_len, ss, 100.0 * (ss / sp - 1.0)))
    say("  its heights: the fin's top row %d, the thrust line %.1f, the level ground %d: fin over ground %d px for the"
        " printed 13 ft 8-3/16 in, %.2f px a metre UP (%+.2f%% against its length); fin over the thrust line %.1f px for"
        " the printed 6 ft 10-1/32 in, %.2f" % (fin_row, thrust_row, ground_row, ground_row - fin_row, vs,
                                                100.0 * (vs / ss - 1.0), thrust_row - fin_row,
                                                (thrust_row - fin_row) / FIN_OVER_THRUST_M))
    say("  so over the thrust line: the fin's top %.3f m, the level ground %.3f m under it"
        % ((thrust_row - fin_row) / vs, (ground_row - thrust_row) / vs))
    shh = lambda row: (thrust_row - row) / vs
    say(chr(10) + "SIDE silhouette (the RP-47B) over the thrust line every 0.25 m: runs low to high")
    for station in np.arange(0.0, 10.85, 0.25):
        col = int(round(nose_s + station * ss))
        rr = edges_at(os_, SIDE_BOX, col, 1)
        say("  %5.2f " % station + " ".join("[%+.3f,%+.3f]" % (shh(b0), shh(a0)) for a0, b0 in reversed(rr)))

    # ---- THE FRONT: its span, its tyres, its disc, its dihedral ----
    of = opened(front)
    fy, fx = np.nonzero(of)
    fy = fy + FRONT_BOX[0]
    fx = fx + FRONT_BOX[2]
    f_span = fx.max() - fx.min() + 1
    fcx = (fx.max() + fx.min()) / 2.0
    say(chr(10) + "FRONT: span %d px (the opened silhouette), %.2f px a metre at the printed span; middle column %.1f"
        % (f_span, f_span / SPAN_M, fcx))
    dcx, dcy, drad, drms = tv.circle(ink0, (1420, 1860, 640, 1060), (170, 230))
    say("  the dashed propeller disc (%.1f, %.1f) r %.1f (rms %.2f): %.3f m across at the plan's scale, against the"
        " printed 12 ft 2 in, %.3f (%+.1f%%)" % (dcx, dcy, drad, drms, 2 * drad / sp, PROP_B_M,
                                                100.0 * (2 * drad / sp / PROP_B_M - 1.0)))
    wheels = front_all & ~front
    tyre_cols = []
    band = wheels[1850 - FRONT_BOX[0]:1900 - FRONT_BOX[0]]
    for a0, b0 in tv.runs(np.nonzero(band.any(axis=0))[0]):
        if b0 - a0 > 15:
            tyre_cols.append((a0 + b0) / 2.0 + FRONT_BOX[2])
    if len(tyre_cols) >= 2:
        say("  tyres at columns %s: the track %.1f px, %.3f m at the plan's scale against the printed 15 ft 7 in, %.3f"
            % (tyre_cols, tyre_cols[-1] - tyre_cols[0], (tyre_cols[-1] - tyre_cols[0]) / sp, TRACK_M))
    mids = []
    for o in np.arange(1.5, 5.8, 0.25):
        for sign in (1, -1):
            rr = edges_at(of, FRONT_BOX, int(round(fcx - sign * o * sp)), 1)
            if rr:
                a0, b0 = rr[0]
                mids.append((o, (dcy - (a0 + b0) / 2.0) / vs, (b0 - a0) / vs))
    (c0, c1), rms, worst = tv.fit([(o, mid) for o, mid, t in mids])
    say("  the wing's middle over the thrust line = %.3f %+.4f x out (%.2f deg), %d rows, rms %.1f mm"
        % (c0, c1, np.degrees(np.arctan(c1)), len(mids), rms * 1000))
    for o, mid, t in mids[::4]:
        say("    %.2f m out: middle %+.3f, %.3f deep" % (o, mid, t))

    # ---- [NACA]'S SIDE VIEW, REGISTERED ON [AN]'S: the D-30's canopy and spine ----
    naca = load(NACA_SHEET)
    nside, _ = tv.solid(naca, NACA_SIDE_BOX, NACA_SIDE_SEED, 3, NACA_SIDE_FENCE)
    nside = opened(nside)
    ny, nx = np.nonzero(nside)
    ny = ny + NACA_SIDE_BOX[0]
    nx = nx + NACA_SIDE_BOX[2]
    n_nose, n_tail = nx.min(), nx.max()
    kx = (n_tail - n_nose) / LENGTH_C1_M
    n_fin = ny.min()
    # THE BELLY under the wing, 3.6 m aft, clear of the main leg: the end of the run that holds the fuselage's middle.
    n_belly = [r for r in edges_at(nside, NACA_SIDE_BOX, int(n_nose + 3.6 * kx), 1) if r[0] <= 2350 <= r[1]][0][1]
    ky = (n_belly - n_fin) / (FIN_OVER_THRUST_M_DRAWN - BELLY_M)
    n_thrust = n_fin + FIN_OVER_THRUST_M_DRAWN * ky
    say(chr(10) + "[NACA] SIDE, registered: its nose column %d and tail %d on the C-1's printed length, %.2f px a metre along;"
        " its fin's top row %d and belly row %d on [AN]'s 2.073 over and 1.120 under the thrust line, %.2f px a metre up;"
        " its thrust line row %.1f" % (n_nose, n_tail, kx, n_fin, n_belly, ky, n_thrust))
    deck_col = int(n_nose + 3.4 * kx)
    n_deck = (n_thrust - edges_at(nside, NACA_SIDE_BOX, deck_col, 1)[0][0]) / ky
    say("  its top every 0.22 m (the canopy and the spine); its deck ahead of the windscreen, 3.4 m aft, is %.3f against"
        " [AN]'s 0.811: the model lays [NACA]'s canopy and spine %.2f m up, on [AN]'s deck" % (n_deck, 0.811 - n_deck))
    for c in range(int(n_nose + 3.4 * kx), int(n_nose + 9.3 * kx), int(round(0.225 * kx))):
        rr = edges_at(nside, NACA_SIDE_BOX, c, 1)
        if rr:
            say("    %5.2f  top %+.3f" % ((c - n_nose) / kx, (n_thrust - rr[0][0]) / ky))
    return locals()


def main():
    measure(print)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        FOLDER = sys.argv[1]
    main()
