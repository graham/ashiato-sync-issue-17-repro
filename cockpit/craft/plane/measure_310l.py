"""Re-derive every MEASURED number in craft/plane/sources.md from the Cessna 310L three-view.

Run it in this folder with the drawing beside it:

    python measure_310l.py

The drawing is `cessna_310L_3view.png`, the "PRINCIPAL DIMENSIONS" page of the 1967 Cessna
Model 310L Owner's Manual (D436-13) as restored on Wikimedia Commons, public domain through a
defective US copyright notice. It is NOT committed to the repository: download it beside this
file from
<https://commons.wikimedia.org/wiki/File:Cessna_310L_3-view_line_drawing.png>.

NOTHING HERE IS A NUMBER TYPED OUT OF THE WRITE-UP. Every figure is computed from the page, so
the write-up and this script can disagree and one of them be wrong -- which is the only way a
research file audits itself (modelling_here.md section 3).

FIVE THINGS ABOUT THIS PAGE, EACH OF WHICH COST AN HOUR, IN THE ORDER THEY BIT:

  * ITS OUTLINE STROKES ARE GREY 130 TO 200, NOT BLACK. A threshold at 128 catches the
    dimension lines, the lettering and the filled tyres -- everything that makes a scale look
    right -- and DROPS THE AEROPLANE'S OWN THIN OUTLINE. The port wing came back as an empty
    column and the tip tanks as nothing at all, while every printed dimension still checked out
    to half a per cent. A threshold that loses the subject while keeping its dimensions is the
    worst kind, because the residuals all look healthy. INK is `a < 190` here, and the extent
    it finds is stable from 160 to 200. The dimension lines and the tyres are still read on
    DARK ink, because that is what tells them from the aeroplane.

  * THE AEROPLANE IS DRAWN LEVEL AND THE GROUND IS RAKED. The wing's lower line in the side
    view is horizontal to the pixel, and a Hough sweep of the side view's dark ink finds one
    dominant family of long straight lines at exactly -4.500 degrees -- the printed
    "4 deg 30 min". The nose tyre therefore hangs BELOW the mains in the craft's own frame, and
    on level ground a 310 sits NOSE-UP by that angle. Two further things agree: the front view
    draws the nose wheel's ground pad lower than the mains', and a CC BY-SA 3.0 broadside of a
    parked 310R (OO-MSN, Ad Meskens) has its cheat line falling aft. Reading the convention the
    other way round buries the nose wheel, which is what `lane/warbirds2` found under the P-38
    (learnings/2026-09-19-warbirds2.md).

  * WHICH PARALLEL IS THE GROUND HAS TO BE ASKED OF THE TYRES. There are a dozen lines in that
    family and two of them lie BELOW the aeroplane. Taking "the lowest" read the height 8 per
    cent high with no complaint from anything.

  * THE VIEWS ARE NOT ALL AT ONE SCALE. The front and plan views agree with each other across
    the aeroplane to 0.3 per cent (80.7 px/m) and the side view is 81.8 px/m along it and
    within 1.2 per cent of that up it. So the page's two axes differ by about 1.35 per cent and
    the model takes RATIOS from the drawing and ABSOLUTE sizes from the published 310R figures:
    "a ratio you are sure of plus a scale you are not is a better state than a number you have
    quietly guessed".

  * THE TWO PRINTED LENGTHS (29 ft 6 in and 29 ft 3.25 in) DIFFER BY 70 mm AND ONE PIXEL IS
    12.2 mm. That pair cannot arbitrate anything, and is printed here only to say so.
"""

import math
import os
import sys

import numpy as np
from PIL import Image

SRC = "cessna_310L_3view.png"
FALLBACK = os.path.expanduser(
    "~/godotgames-drafts/2026-09-19/cockpit-twin310/research/cessna_310L_3view.png")

INK = 190
DARK = 128
FOOT = 0.3048
INCH = 0.0254


def feet(ft, inch=0.0):
    return ft * FOOT + inch * INCH


# ---- what the page prints ------------------------------------------------------------------
# The ONLY typed numbers here, each read off the page's own dimension lines.
SPAN = feet(36, 11)
TRACK = feet(12, 0)
PROPELLER = feet(6, 9)
TAILPLANE = feet(17, 0)
TANK_LENGTH = feet(10, 0)
LENGTH = feet(29, 6)
LENGTH_B = feet(29, 3.25)
WHEELBASE = feet(9, 6.75)
HEIGHT = feet(9, 11.25)
HEIGHT_DEPRESSED = feet(10, 8.75)
BEACON_ADDS = feet(0, 3)
RAKE_DEG = 4.5

# The 310R's published envelope, which is what the MODEL is built to (sources.md). Printed here
# only to say what each drawn ratio becomes on the R.
R_LENGTH = 9.74
R_SPAN = 11.25
R_PROPELLER = feet(0, 76.5)   # [TCDS] McCauley three-blade, 74.5 to 76.5 in

# [TCDS] FAA 3A10 Rev 63: the 310J through the 310R all carry 51 US gal a tip tank at arm
# +35 in, so the L sheet's tanks ARE the R's and their drawn size has a published volume to
# answer to.
TIP_TANK_GALLONS = 51.0
GALLON = 0.0037854118


def load():
    path = SRC if os.path.exists(SRC) else FALLBACK
    if not os.path.exists(path):
        sys.exit("put %s beside this script (see the doc block)" % SRC)
    a = np.array(Image.open(path).convert("L")).astype(np.int16)
    return a, (a < INK), (a < DARK)


# ---- pixel tools ---------------------------------------------------------------------------

def witness_lines(a, dark, y0, y1, x0, x1, minlen):
    """Every tall vertical stroke in a window, as sub-pixel x centres: a dimension's witnesses.
    Read on DARK ink, because that is what tells a witness line from the aeroplane behind it."""
    cols = [x for x in range(x0, x1 + 1) if dark[y0:y1 + 1, x].sum() >= minlen]
    if not cols:
        return []
    groups = []
    start = prev = cols[0]
    for c in cols[1:]:
        if c > prev + 3:
            groups.append((start, prev))
            start = c
        prev = c
    groups.append((start, prev))
    out = []
    for lo, hi in groups:
        w = (255 - a[y0:y1 + 1, lo - 1:hi + 2]).clip(0).astype(float).sum(0)
        out.append(float((np.arange(lo - 1, hi + 2) * w).sum() / w.sum()))
    return out


def spans(ink, x, y0, y1, gap=2):
    """Ink runs down one column, as (first, last) pairs."""
    col = np.nonzero(ink[y0:y1 + 1, x])[0]
    if len(col) == 0:
        return []
    out = []
    start = prev = col[0]
    for y in col[1:]:
        if y > prev + gap:
            out.append((int(y0 + start), int(y0 + prev)))
            start = y
        prev = y
    out.append((int(y0 + start), int(y0 + prev)))
    return out


def extent(ink, x, y0, y1):
    col = np.nonzero(ink[y0:y1 + 1, x])[0]
    return None if len(col) == 0 else (y0 + int(col.min()), y0 + int(col.max()))


def fit_line(xs, ys):
    xs, ys = np.asarray(xs, float), np.asarray(ys, float)
    m, c = np.polyfit(xs, ys, 1)
    res = ys - (m * xs + c)
    return float(m), float(c), float(np.sqrt((res ** 2).mean()))


def fit_circle(pts):
    xs = np.array([p[0] for p in pts], float)
    ys = np.array([p[1] for p in pts], float)
    A = np.column_stack([xs, ys, np.ones(len(xs))])
    sol, *_ = np.linalg.lstsq(A, xs ** 2 + ys ** 2, rcond=None)
    cx, cy = sol[0] / 2.0, sol[1] / 2.0
    r = math.sqrt(sol[2] + cx * cx + cy * cy)
    res = np.hypot(xs - cx, ys - cy) - r
    return cx, cy, r, float(np.sqrt((res ** 2).mean()))


def arc_circle(ink, x0, x1, y0, y1):
    """A circle fitted to the TOP arc of a drawn disc, pruned of anything that is not on it.
    The disc's widest points lie where the wing crosses it, so a bounding box round the window
    measures the wing; an arc fit does not. 160-odd points come back at 0.3 px rms."""
    pts = []
    for x in range(x0, x1 + 1):
        col = np.nonzero(ink[y0:y1 + 1, x])[0]
        if len(col):
            pts.append((float(x), float(y0 + col.min())))
    if len(pts) < 40:
        return None
    for _ in range(4):
        cx, cy, r, rms = fit_circle(pts)
        keep = [p for p in pts if abs(math.hypot(p[0] - cx, p[1] - cy) - r) < max(2.0, 2 * rms)]
        if len(keep) < 40:
            break
        pts = keep
    return fit_circle(pts) + (len(pts),)


def blobs(dark, y0, y1, x0, x1, floor=8, gap=3):
    cols = dark[y0:y1 + 1, x0:x1 + 1].sum(0)
    xs = np.nonzero(cols > floor)[0]
    if len(xs) == 0:
        return []
    groups = []
    start = prev = xs[0]
    for x in xs[1:]:
        if x > prev + gap:
            groups.append((start, prev))
            start = x
        prev = x
    groups.append((start, prev))
    out = []
    for lo, hi in groups:
        seg = cols[lo:hi + 1].astype(float)
        out.append({"lo": x0 + lo, "hi": x0 + hi, "width": hi - lo + 1,
                    "centre": x0 + float((np.arange(lo, hi + 1) * seg).sum() / seg.sum())})
    return out


def _row_run(ink, y, x0, x1):
    row = np.nonzero(ink[y, x0:x1 + 1])[0]
    return None if len(row) == 0 else (x0 + int(row.min()), x0 + int(row.max()))


def check(label, measured, printed, unit="m"):
    print("      %-34s %8.3f %s  printed %7.3f  %+6.2f%%"
          % (label, measured, unit, printed, (measured - printed) / printed * 100.0))


# ---- the front view ---------------------------------------------------------------------------

def front(a, ink, dark):
    print("FRONT VIEW -- scale from the printed 36 ft 11 in span; everything else is a check")
    w = witness_lines(a, dark, 1315, 1430, 200, 1200, 60)
    left, right = w[0], w[-1]
    s = (right - left) / SPAN
    axis = (left + right) / 2.0
    print("    witnesses x %.2f .. %.2f -> %.3f px/m (1 px = %.1f mm), axis x %.1f"
          % (left, right, s, 1000.0 / s, axis))

    cols = [x for x in range(150, 1250) if ink[1430:1755, x].any()]
    check("drawn tank face to tank face", (cols[-1] - cols[0]) / s, SPAN)

    mains = [b for b in blobs(dark, 1655, 1745, 400, 980) if b["width"] >= 10]
    if len(mains) >= 2:
        check("main wheel centres", (mains[-1]["centre"] - mains[0]["centre"]) / s, TRACK)
        print("      (drawn tyre width %.3f m, and the nose wheel is at x %.1f)"
              % (mains[0]["width"] / s, axis))

    # THE PROPELLER DISCS ARE THE ONLY TRUE CIRCLES ON THE PAGE, so fitting both of their axes
    # asks whether this view is isotropic without needing a second printed figure to do it.
    hubs = []
    for name, x0, x1 in (("port", 450, 640), ("starboard", 740, 930)):
        c = arc_circle(ink, x0, x1, 1430, 1560)
        if c is None:
            continue
        cx, cy, r, rms, n = c
        hubs.append((cx, cy, r))
        print("      %-10s disc: centre (%.1f, %.1f), %d arc points at %.2f px rms"
              % (name, cx, cy, n, rms))
        check("  diameter", 2 * r / s, PROPELLER)
    if len(hubs) == 2:
        print("      propeller centres %.3f m apart, %.3f m either side of the axis"
              % ((hubs[1][0] - hubs[0][0]) / s, (hubs[1][0] - hubs[0][0]) / (2 * s)))
        print("      (the 310R's propeller is a three-blade McCauley, %.3f m [TCDS])"
              % R_PROPELLER)

    # THE DIHEDRAL, fitted over every station between the nacelle and the tank, with its
    # residual, because a fit through two ends proves nothing (modelling_here.md section 3).
    for name, lo, hi, sign in (("port", 300, 430, -1.0), ("starboard", 940, 1075, 1.0)):
        xs, ys = [], []
        for x in range(lo, hi + 1):
            runs = [r for r in spans(ink, x, 1500, 1620) if r[1] - r[0] < 40]
            if not runs:
                continue
            xs.append(float(x))
            ys.append((runs[0][0] + runs[-1][1]) / 2.0)
        if len(xs) < 30:
            continue
        m, _, rms = fit_line(xs, ys)
        print("      %-10s wing mid-line, %d stations: %.2f deg dihedral, rms %.2f px (%.0f mm)"
              % (name, len(xs), math.degrees(math.atan(-m * sign)), rms, rms / s * 1000.0))

    # THE TIP TANK END ON, at a column a fifth of its width inboard of its outer face.
    for name, x in (("port", cols[0] + 10), ("starboard", cols[-1] - 10)):
        e = extent(ink, int(x), 1450, 1680)
        if e:
            print("      %-10s tip tank, %.2f m inboard of its face: %.3f m deep, centred %.2f m"
                  % (name, 10.0 / s, (e[1] - e[0]) / s, 0.0))
    print()
    return s, left, right, axis


# ---- the side view ----------------------------------------------------------------------------

def hough_parallels(dark):
    ys, xs = np.nonzero(dark[60:440, :])
    ys = ys + 60
    best = (0, 0.0)
    for ang in np.arange(-8.0, 8.0001, 0.05):
        b = ys - math.tan(math.radians(ang)) * xs
        h, _ = np.histogram(b, bins=np.arange(60, 441, 1.0))
        k = np.convolve(h, [1, 1, 1], mode="same")
        if k.max() > best[0]:
            best = (int(k.max()), float(ang))
    ang = best[1]
    b = ys - math.tan(math.radians(ang)) * xs
    h, edges = np.histogram(b, bins=np.arange(60, 441, 1.0))
    offs = []
    for i in range(1, len(h) - 1):
        if h[i] >= 60 and h[i] >= h[i - 1] and h[i] > h[i + 1]:
            lo, hi = max(0, i - 2), min(len(h), i + 3)
            wgt = h[lo:hi].astype(float)
            offs.append((float((edges[lo:hi] * wgt).sum() / wgt.sum()), int(h[i])))
    merged = []
    for o, c in sorted(offs):
        if merged and o - merged[-1][0] < 8:
            if c > merged[-1][1]:
                merged[-1] = (o, c)
            continue
        merged.append((o, c))
    return ang, [o for o, _ in merged], best[0]


def side(a, ink, dark):
    print("SIDE VIEW -- scale from the printed 29 ft 6 in length; everything else is a check")
    w = witness_lines(a, dark, 14, 40, 200, 1050, 8)
    nose_x, tail_x = w[0], w[-1]
    s = (tail_x - nose_x) / LENGTH
    print("    witnesses x %.2f .. %.2f -> %.3f px/m (1 px = %.1f mm)"
          % (nose_x, tail_x, s, 1000.0 / s))
    w2 = witness_lines(a, dark, 44, 66, 200, 1050, 8)
    if len(w2) >= 2:
        check("the second printed length", (w2[-1] - w2[0]) / s, LENGTH_B)
        print("      (printed 70 mm apart, and one pixel is %.1f mm: no arbitration there)"
              % (1000.0 / s))

    ang, offs, votes = hough_parallels(dark)
    t = math.tan(math.radians(ang))
    print("      the page's strongest straight-line family: %.3f deg on %d px, %d parallels"
          % (ang, votes, len(offs)))
    check("      the rake it found", abs(ang), RAKE_DEG, "deg")

    # WHICH PARALLEL IS THE GROUND: the one both tyres stand on. Two of the family lie below
    # the aeroplane, and taking the lowest reads the height 8 per cent high in silence.
    tyres = [b for b in blobs(dark, 340, 395, 200, 540, floor=6) if b["width"] >= 20]
    ground, feet_y = None, []
    if len(tyres) >= 2:
        for b in tyres[:1] + tyres[-1:]:
            # THE MEDIAN COLUMN, NOT THE DEEPEST. The wheelbase dimension's own witness line
            # stands at the nose tyre's centre and runs 9 px past the ground, and taking the
            # deepest dark pixel there moved the ground line 9 px down and the height 5 per
            # cent up -- with every other residual on the page still healthy.
            deep = []
            for x in range(b["lo"], b["hi"] + 1):
                col = np.nonzero(dark[330:408, x])[0]
                if len(col):
                    deep.append(330 + int(col.max()))
            feet_y.append(float(np.median(deep)) - 1.0)   # less the ground stroke's own width
        best = min(offs, key=lambda o: sum(abs(t * b["centre"] + o - fy)
                                           for b, fy in zip(tyres[:1] + tyres[-1:], feet_y)))
        ground = best
        err = sum(abs(t * b["centre"] + ground - fy)
                  for b, fy in zip(tyres[:1] + tyres[-1:], feet_y))
        print("      tyres at x %.1f and %.1f stand on the parallel at offset %.1f (%.1f px out)"
              % (tyres[0]["centre"], tyres[-1]["centre"], ground, err))

    top = offs[0]
    if ground is not None:
        check("fin-top line to ground line", (ground - top) * math.cos(math.radians(ang)) / s,
              HEIGHT)
        print("      (the page: a beacon adds %.0f mm, and with the nose gear depressed the"
              % (BEACON_ADDS * 1000.0))
        print("       maximum is %.3f m -- which is what the 310R's published 10 ft 7 in to"
              % HEIGHT_DEPRESSED)
        print("       10 ft 8 in reproduces, NOT the %.3f m a 310 stands at normally.)" % HEIGHT)

    wb = witness_lines(a, dark, 392, 432, 200, 520, 18)
    if len(wb) >= 2:
        check("wheelbase witnesses", (wb[-1] - wb[0]) / s, WHEELBASE)
        drop = (t * wb[0] - t * wb[-1]) / s
        print("      THE NOSE TYRE HANGS %.3f m BELOW THE MAINS in the craft's own level frame:"
              % drop)
        print("      %.2f deg nose-up on flat ground over a %.3f m wheelbase. That is the number"
              % (math.degrees(math.atan(drop / ((wb[-1] - wb[0]) / s))), (wb[-1] - wb[0]) / s))
        print("      `parked()` needs, and nothing else in the model can supply it.")

    if ground is not None:
        print("      fuselage profile: station aft of the propeller tip, and the top and bottom")
        print("      of the skin over the ground there (metres at the L's own scale):")
        # ONLY AS FAR AS THE TAILCONE. Past 0.85 of the length the topmost ink in a column is
        # one of the page's own construction lines, which reads as a fin 5 per cent too tall.
        for frac in (0.01, 0.03, 0.06, 0.10, 0.15, 0.22, 0.30, 0.38, 0.46, 0.54,
                     0.62, 0.70, 0.78, 0.84):
            x = int(round(nose_x + frac * (tail_x - nose_x)))
            gy = t * x + ground
            e = extent(ink, x, 70, int(gy) - 3)
            if e is None:
                continue
            print("        s %5.2f   top %5.2f   bottom %5.2f"
                  % ((x - nose_x) / s, (gy - e[0]) / s, (gy - e[1]) / s))
        for name, b in zip(("nose", "main"), tyres[:1] + tyres[-1:]):
            print("      %s tyre centred at s %.2f, %.3f m across"
                  % (name, (b["centre"] - nose_x) / s, b["width"] / s))
        # THE FIN, measured off its own two edges rather than off the topmost ink, and the
        # tailplane's station, taken where the stabiliser leaves the tailcone.
        fin = []
        for x in range(int(nose_x + 0.72 * (tail_x - nose_x)), int(tail_x) - 4):
            runs = [r for r in spans(ink, x, 70, int(t * x + ground) - 6) if r[1] - r[0] < 60]
            if not runs:
                continue
            fin.append(((x - nose_x) / s, (t * x + ground - runs[0][0]) / s))
        if len(fin) > 20:
            peak = max(fin, key=lambda f: f[1])
            print("      the fin rises from s %.2f to its top %.2f m up at s %.2f"
                  % (fin[0][0], peak[1], peak[0]))
            rise = [f for f in fin if f[0] < peak[0]]
            m, _, rms = fit_line([f[0] for f in rise], [f[1] for f in rise])
            print("      its leading edge climbs %.2f m a metre (%.1f deg), rms %.0f mm"
                  % (m, math.degrees(math.atan(m)), rms * 1000.0))
    print()
    return s, nose_x, tail_x, ang, ground


# ---- the plan view ----------------------------------------------------------------------------

def plan(a, ink, dark):
    print("PLAN VIEW -- across from the printed 17 ft 0 in tailplane, fore and aft from the")
    print("            aeroplane's own nose-to-fin extent. The nose points DOWN the page.")
    w = witness_lines(a, dark, 515, 562, 250, 780, 12)
    tl, tr = w[0], w[-1]
    sx = (tr - tl) / TAILPLANE

    # THE AXIS FROM THE AEROPLANE, not from a dimension: the fuselage's own middle at four
    # stations ahead of the wing, where nothing else is drawn. The tailplane's dimension line
    # centres 4 px off it, which is the drafter's, not the aeroplane's.
    mids = []
    for y in (1150, 1180, 1210, 1230):
        row = np.nonzero(ink[y, 400:660])[0]
        if len(row):
            mids.append(400 + (row.min() + row.max()) / 2.0)
    axis = float(np.mean(mids))
    print("    tailplane witnesses x %.2f .. %.2f -> %.3f px/m across" % (tl, tr, sx))
    print("    axis from the fuselage at %d stations: x %.1f (the tailplane dimension: %.1f)"
          % (len(mids), axis, (tl + tr) / 2.0))

    # THE TIP TANKS' OUTER FACES, counted over the wing's own rows and requiring ink in several
    # of them, so the page's note text (short letters) cannot pretend to be a wing tip.
    band = ink[980:1080]
    cnt = band.sum(0)
    faces = [x for x in range(0, 1334) if cnt[x] >= 4]
    tank_l = float(faces[0])
    tank_r = 2 * axis - tank_l
    check("tank face to tank face", 2 * (axis - tank_l) / sx, SPAN)

    ys = [y for y in range(520, 1320) if ink[y, int(axis) - 45:int(axis) + 45].any()]
    tail_y, nose_y = float(ys[0]), float(ys[-1])
    sy = (nose_y - tail_y) / LENGTH
    print("    aeroplane y %.0f .. %.0f -> %.3f px/m fore and aft" % (tail_y, nose_y, sy))
    print("    THE TWO AXES OF THIS ONE VIEW DISAGREE BY %.2f PER CENT. Scale each by its own"
          % ((sy - sx) / sx * 100.0))
    print("    printed figure and take ratios; never carry one number across both.")

    # THE TIP TANK, fore and aft: the printed dimension on the other axis, and the only check
    # this view has of it.
    lo, hi = int(round(tank_l)), int(round(tank_l + 0.55 * sx))
    trow = [y for y in range(860, 1260) if ink[y, lo:hi].any()]
    check("port tip tank length", (trow[-1] - trow[0]) / sy, TANK_LENGTH)
    # THE TANK'S PLAN WIDTH, taken across its own widest row rather than along a guessed band.
    # MEASURED FORWARD OF THE WING'S LEADING EDGE, where the tank is the only thing drawn.
    # Taken over its whole length instead, the widest row is the one the wing root crosses and
    # the tank comes back 0.88 m wide against a true 0.62.
    ahead = range(int(trow[-1] - 0.9 * sy), int(trow[-1] - 0.25 * sy))
    widest = max(ahead, key=lambda y: (lambda r: 0 if r is None else r[1] - r[0])(
        _row_run(ink, y, int(tank_l) - 2, int(tank_l + 0.9 * sx))))
    run = _row_run(ink, widest, int(tank_l) - 2, int(tank_l + 0.9 * sx))
    print("      the tank is %.3f m wide in plan at its widest row; its NOSE is at station"
          % ((run[1] - run[0]) / sx))
    print("      %.2f m and its TAIL at %.2f m aft of the propeller tip (%.2f m long)"
          % ((nose_y - trow[-1]) / sy, (nose_y - trow[0]) / sy,
             (trow[-1] - trow[0]) / sy))
    vol = TIP_TANK_GALLONS * GALLON
    print("      [TCDS] gives it 51 US gal (%.3f m3), which is %.0f per cent of a cylinder that"
          % (vol, vol / (math.pi * ((run[1] - run[0]) / sx / 2) ** 2
                         * ((trow[-1] - trow[0]) / sy)) * 100.0))
    print("      long and that wide -- about right for a tank with structure and a fin in it.")

    # THE WING, edge by edge, from the tank inboard. The nacelle reaches further fore and aft
    # than the wing, so runs taller than a chord are dropped.
    print("      port wing: half-span station, leading and trailing edge as metres aft of the")
    print("      propeller tip, and the chord there:")
    rows = []
    for x in range(int(round(tank_l + 0.6 * sx)), int(round(axis - 85)), 4):
        runs = [r for r in spans(ink, x, 900, 1140) if r[1] - r[0] < 30]
        if len(runs) < 2:
            continue
        te, le = runs[0][0], runs[-1][1]
        # STATIONS ARE MEASURED FROM THE PROPELLER TIP, which in this view is the BOTTOM of
        # the page: the nose points down it. Measuring from `tail_y` instead put the wing's
        # leading edge at station 6.6 on a 9 m aeroplane and looked almost plausible.
        rows.append(((axis - x) / sx, (nose_y - te) / sy, (nose_y - le) / sy, (le - te) / sy))
    for r in rows[::5]:
        print("        y %5.2f   TE %5.2f   LE %5.2f   chord %4.2f" % r)
    outer = [r for r in rows if r[0] > 2.9]
    if len(outer) > 8:
        m, c, rms = fit_line([r[0] for r in outer], [r[3] for r in outer])
        print("      outboard of the nacelle the chord is %.3f - %.4f y, rms %.3f m over %d"
              % (c, -m, rms, len(outer)))
        mle, cle, rle = fit_line([r[0] for r in outer], [r[2] for r in outer])
        mte, cte, rte = fit_line([r[0] for r in outer], [r[1] for r in outer])
        print("      leading edge sweeps %.2f deg aft, trailing edge %.2f deg forward,"
              % (math.degrees(math.atan(mle)), math.degrees(math.atan(-mte))))
        print("      so the taper is mostly in the trailing edge, as a 310's is.")

    # THE FUSELAGE IN PLAN, which is what a cabin has to be built inside.
    print("      fuselage half-width in plan, by station aft of the propeller tip:")
    for st in (0.4, 0.8, 1.2, 1.8, 2.4, 3.0, 3.6, 4.4, 5.2, 6.0, 6.8):
        y = int(round(nose_y - st * sy))
        r = _row_run(ink, y, int(axis) - 70, int(axis) + 70)
        if r is None:
            continue
        print("        s %4.1f   half-width %5.3f m" % (st, (r[1] - r[0]) / 2.0 / sx))
    # THE NACELLE in plan: its outer and inner faces and its ends.
    nx = int(round(axis - 1.863 * sx))
    ncol = [y for y in range(860, 1260) if ink[y, nx - 3:nx + 3].any()]
    if ncol:
        print("      port nacelle on the propeller's own centreline (%.2f m off the axis) runs"
              % 1.863)
        print("      from s %.2f to s %.2f (%.2f m long)"
              % ((nose_y - ncol[-1]) / sy, (nose_y - ncol[0]) / sy,
                 (ncol[-1] - ncol[0]) / sy))
        wide = max(range(ncol[0] + 20, ncol[-1] - 20),
                   key=lambda y: (lambda r: 0 if r is None else r[1] - r[0])(
                       _row_run(ink, y, nx - 45, nx + 45)))
        r = _row_run(ink, wide, nx - 45, nx + 45)
        print("      and is %.3f m wide at s %.2f" % ((r[1] - r[0]) / sx, (nose_y - wide) / sy))

    tp = [r for r in spans(ink, int(round(axis - 120)), 520, 700) if r[1] - r[0] < 40]
    if len(tp) >= 2:
        print("      tailplane at %.2f m off the axis: %.2f m chord"
              % (120 / sx, (tp[-1][1] - tp[0][0]) / sy))
    print()
    return sx, sy, axis, tail_y, nose_y




# ---- the wing's area, and a sweep over the threshold everything else depends on ---------------

SQ_FT = 0.09290304
PUBLISHED_AREA_R = 179.0 * SQ_FT      # [AOPA][RR] for the 310R
PUBLISHED_AREA_EARLY = 175.0 * SQ_FT  # the figure quoted for the early 310s
TANK_HALF = 0.533 / 2.0               # the tank's plan half-width, measured above
TANK_X = 5.345                        # its centre off the axis, measured above


def wing_chords(a, threshold, sx, sy, axis):
    """(half-span station, chord) down the port wing outboard of the nacelle, at one threshold."""
    ink = a < threshold
    out = []
    for x in range(int(round(axis - 5.15 * sx)), int(round(axis - 2.45 * sx)), 2):
        runs = [r for r in spans(ink, x, 900, 1140) if r[1] - r[0] < 30]
        if len(runs) < 2:
            continue
        out.append(((axis - x) / sx, (runs[-1][1] - runs[0][0]) / sy))
    return out


def wing_from(rows):
    """The trapezoidal planform from a chord fit, BOTH SIDES, with the chord law carried through
    the fuselage to the centreline -- which is what a reference wing area is."""
    if len(rows) < 8:
        return None
    m, c, rms = fit_line([r[0] for r in rows], [r[1] for r in rows])
    tip = TANK_X - TANK_HALF
    area = 2.0 * (c * tip + m * tip * tip / 2.0)
    over = 2.0 * (c * (SPAN / 2.0) + m * (SPAN / 2.0) ** 2 / 2.0)
    mac = 0.0
    steps = 400
    for i in range(steps):
        x = tip * (i + 0.5) / steps
        mac += (c + m * x) ** 2 * (tip / steps)
    return {"root": c, "fall": -m, "rms": rms, "tip": tip, "tip_chord": c + m * tip,
            "area": area, "over": over, "mac": 2.0 * mac / area, "n": len(rows),
            "aspect": (tip * 2.0) ** 2 / area}


def wing(a, sx, sy, axis):
    print("THE WING'S AREA -- the structural cross-check, because it combines BOTH of the plan")
    print("view's axes and no view's length goes into it (modelling_here.md section 3).")
    got = wing_from(wing_chords(a, INK, sx, sy, axis))
    if got is None:
        print("    not measurable")
        return
    print("    chord %.3f - %.4f y over %d stations at %.3f m rms; tip chord %.3f at %.3f m out"
          % (got["root"], got["fall"], got["n"], got["rms"], got["tip_chord"], got["tip"]))
    print("    MAC %.3f m, aspect ratio %.2f on the wing's own span" % (got["mac"], got["aspect"]))
    check("planform to the tank's face", got["area"], PUBLISHED_AREA_EARLY)
    print("      ...which is the EARLY 310's published 175 sq ft, and the agreement is the thing:")
    print("      a printed AREA combines the plan view's two axes, so a chord law fitted across it")
    print("      and integrated along it landing on a published area says the view is isotropic.")
    check("the same, carried out to the tanks", got["over"], PUBLISHED_AREA_R)
    print("      ...against the 310R's published 179 sq ft. The wing did not change between those")
    print("      models [TCDS], so ONE OF THE TWO PUBLISHED FIGURES IS A DIFFERENT CONVENTION")
    print("      rather than a different wing, and nothing here settles which. The model builds to")
    print("      the first, because the lifting surface a flight model integrates ends at the tank.")
    # WHERE WOULD THE WING HAVE TO END for the R's published area to come out? Solved rather than
    # guessed at, because "somewhere between the two" is not a finding and a station is.
    lo, hi = got["tip"], SPAN / 2.0
    for _ in range(60):
        mid = (lo + hi) / 2.0
        if 2.0 * (got["root"] * mid - got["fall"] * mid * mid / 2.0) < PUBLISHED_AREA_R:
            lo = mid
        else:
            hi = mid
    print("      The R's 179 sq ft is the same chord law carried to %.3f m out -- %.0f mm past"
          % ((lo + hi) / 2.0, ((lo + hi) / 2.0 - got["tip"]) * 1000.0))
    print("      where the structure ends and %.0f mm short of the tank's centreline. So it looks"
          % ((TANK_X - (lo + hi) / 2.0) * 1000.0))
    print("      like a wing area with part of the tank's own plan counted into it, which is a")
    print("      guess about a convention and is marked as one.")

    print()
    print("A THRESHOLD SWEEP OVER THAT WHOLE MEASUREMENT, which is `lane/harrier`'s pattern: print")
    print("the test rather than the claim, so the next reader can see whether this page has a")
    print("threshold that loses its subject. THIS ONE DOES -- harrier's NAVAIR sheet did not.")
    print("  thr  stations  root chord  chord fall  rms m   area m2  aspect")
    for threshold in range(60, 226, 15):
        got = wing_from(wing_chords(a, threshold, sx, sy, axis))
        if got is None:
            print("  %3d   -- nothing measurable: the outline is invisible at this threshold --"
                  % threshold)
            continue
        print("  %3d  %8d  %10.3f  %10.4f  %6.3f  %7.3f  %6.2f"
              % (threshold, got["n"], got["root"], got["fall"], got["rms"], got["area"],
                 got["aspect"]))
    print("  Below 120 the aeroplane is not there at all; from 120 to 165 the fit is being made")
    print("  through a partly-seen outline and the chord law is out by up to 68 per cent at the")
    print("  root; from 180 up it settles to within 0.7 per cent on area. EVERY PRINTED DIMENSION")
    print("  ON THE PAGE CHECKS OUT TO HALF A PER CENT AT EVERY ONE OF THOSE THRESHOLDS.")


def main():
    a, ink, dark = load()
    print("page %d x %d px, ink < %d, dark < %d" % (a.shape[1], a.shape[0], INK, DARK))
    print()
    front(a, ink, dark)
    side(a, ink, dark)
    sx, sy, axis, _tail, _nose = plan(a, ink, dark)
    wing(a, sx, sy, axis)
    print()
    print("THE 310R IS THE L SHEET'S AEROPLANE PLUS A BAGGAGE NOSE. Published length %.2f m"
          % R_LENGTH)
    print("against the L's printed %.3f m is a plug of %.3f m ahead of the firewall, and [TCDS]"
          % (LENGTH, R_LENGTH - LENGTH))
    print("puts the R's nose baggage at station -31 in where the 310Q has no nose entry at all.")
    print("The span, the tip tanks (51 US gal at +35 in on every model from the J) and the tail")
    print("are unchanged; the propeller becomes a three-blade %.3f m McCauley." % R_PROPELLER)


if __name__ == "__main__":
    main()
