"""Re-derive every MEASURED figure for the AV-8B from the NAVAIR SAC sheet ALONE.

This script reads nothing out of `sources.md` and nothing out of the airframe. It takes the scan,
finds the drawing's own scale from a PUBLISHED dimension, and then measures the aeroplane -- so the
write-up and the model can disagree with it and be wrong, which is the whole point
(`modelling_here.md` section 3: "make the research file reproducible by a script that does not read
it"). Run it and read the residuals; every fit prints one.

THE REFERENCE. NAVAIR 00-110AV8-4, *Standard Aircraft Characteristics: AV-8B Harrier II*, October
1986, page 2 ("DESCRIPTIVE AND ARRANGEMENT"). The PDF's page 4 carries one embedded greyscale scan
at its native 3510 x 2552; that image is extracted losslessly rather than re-rendered, because
rendering the page at 200 dpi gives 2340 x 1702 and throws away a third of the linear resolution
that is actually there.

    python measure_sac.py [path-to-research-dir]

Nothing here is incorporated into the game. The scan lives in ~/godotgames-drafts/, never in the
repository.

TWO FINDINGS THAT DECIDE HOW THE DRAWING MAY BE USED, both made by this script:

1. **THE PRINTED `SCALE IN FEET` BAR IS UNUSABLE.** Its five ticks give **15.20 px/ft** where four
   independent printed dimensions across three views give **19.04 to 19.32** -- the bar reads
   **20.8 per cent low**, or equivalently the aeroplane is drawn 26 per cent bigger than its own
   scale bar says. The bar is not internally even either: its four 5 ft gaps read 73.9, 75.2, 77.8
   and 77.1 px, a 2.3 per cent spread on sub-pixel centroids individually good to about a tenth of
   a pixel, so it is not a precision ruler even locally. The scale is therefore taken from the
   aeroplane's own published dimensions, and the bar is reported and discarded.

   **The bar is the one thing on the sheet that LOOKS like a ruler**, which is why it is dangerous:
   anything measured with it would have come out a fifth too small, uniformly, with nothing in the
   drawing to say so. A scale gets cross-checked before it is used, and a confident-looking ruler
   is still only a claim.

2. **THE THREE VIEWS SHARE ONE SCALE, and the plan view is ISOTROPIC.** The second is the one that
   matters and it cannot be settled by any length: scale-checking a drawing end to end says nothing
   about whether its two axes agree. The structural check is a printed AREA, ASPECT RATIO or MEAN
   AERODYNAMIC CHORD, because those combine both axes and no view's length goes into them. This
   sheet prints all three, and after the scale is set from the SPAN ALONE they come back to under
   two per cent. That is the evidence the drawing may be measured in both directions.
"""

import sys
import numpy as np
from PIL import Image

# ---- PUBLISHED, off the sheet itself. Nothing below is measured; these are what it is measured
# ---- AGAINST. [SAC] page 3's DIMENSIONS table and page 2's dimension lines.
SPAN_FT = 30.33          # sets the scale, and is the ONLY published figure that does
TAILPLANE_FT = 13.93     # page 2's dimension line over the tailplane
LENGTH_FT = 46.33        # page 2's dimension line under the aeroplane
AREA_SQFT = 230.0        # S_REF -- a CHECK, never an input
ASPECT = 4.0             # a CHECK
MAC_FT = 8.32            # a CHECK
SWEEP_QC_DEG = 30.62     # sweepback at 25 per cent chord, projected -- a CHECK
BAR_FEET = 20.0          # what the printed scale bar claims to span

# Where things are on the 3510 x 2552 scan. Found by profiling, and stated so the script is
# readable rather than magic; each is a generous window, not a hand-measured figure.
PANEL = (440, 1706)                  # the left panel, between its two heavy rules
PLAN_BAND = (640, 780, 700, 1420)    # rows that contain the wing, and the panel's x range
BAR_TICKS = (484, 558, 633, 711, 788)
BAR_ROWS = slice(1178, 1195)
EXT_ROWS = slice(340, 365)           # clear of the "13.93 FT" text and its arrowheads
EXT_X = (850, 1250)                  # ...and clear of the PANEL'S OWN RULES, which are thin
                                     # verticals spanning the same rows and were picked up as the
                                     # dimension's extension lines on the first run: 789 px apart,
                                     # a "scale" of 56.7 px/ft. A search window is part of the
                                     # measurement, not housekeeping.
LEN_ROWS = slice(2140, 2162)         # the 46.33 FT extension lines, clear of everything
LEN_X = (550, 1700)
DIM_ROW = (LEN_ROWS.start + LEN_ROWS.stop) / 2.0
FRONT_BAND = (1360, 1700, 700, 1500)


def load(research_dir):
    path = research_dir + r"\sac-native-p4-0.png"
    grey = np.array(Image.open(path).convert("L")).astype(float)
    return grey, grey < 128, np.clip(255.0 - grey, 0.0, None)


def centre_of(dark, approx_x, rows, half=6):
    """A vertical stroke's sub-pixel centre, weighted by ink DARKNESS rather than by a threshold.
    A threshold quantises a 1-2 px line to whole pixels; the weighting gets about a tenth of one."""
    w = dark[rows, approx_x - half: approx_x + half + 1].sum(axis=0)
    xs = np.arange(approx_x - half, approx_x + half + 1, dtype=float)
    return float((w * xs).sum() / w.sum())


def thin_verticals(ink, rows, x0, x1, most=4):
    """The x of every thin vertical line spanning `rows` -- a dimension's extension lines."""
    band = ink[rows, x0:x1]
    cols = np.where(band.mean(axis=0) > 0.9)[0] + x0
    if len(cols) == 0:
        return []
    runs, start = [], cols[0]
    for i in range(1, len(cols)):
        if cols[i] != cols[i - 1] + 1:
            runs.append((start, cols[i - 1])); start = cols[i]
    runs.append((start, cols[-1]))
    return [r for r in runs if r[1] - r[0] <= most]


def widest_row(ink, y0, y1, x0, x1):
    best = (0, 0, 0, 0)
    for j in range(y0, y1):
        c = np.where(ink[j, x0:x1])[0] + x0
        if len(c) > 1 and c.max() - c.min() > best[0]:
            best = (c.max() - c.min(), j, c.min(), c.max())
    return best


def run_mids(ink, x, y0, y1):
    r = np.where(ink[y0:y1, x])[0] + y0
    if len(r) == 0:
        return []
    out, start = [], r[0]
    for i in range(1, len(r)):
        if r[i] != r[i - 1] + 1:
            out.append((start + r[i - 1]) / 2.0); start = r[i]
    out.append((start + r[-1]) / 2.0)
    return out


def track_edge(ink, x_from, x_to, seed, y0=600, y1=940, jump=6.0):
    """Follow ONE edge inboard from the tip, taking at each station the ink run nearest a
    prediction from the last few accepted points.

    WHY NOT "the outermost run": because the pylons hang AHEAD of the leading edge in plan, and a
    naive max() takes a pylon for the wing. That is not a theoretical worry -- it is what the first
    run of this script did, and the leading-edge fit came back at 20.7 px rms (329 mm) with an area
    11.6 per cent high, an aspect ratio 10.4 per cent low and a quarter-chord sweep 12 per cent
    high. Every one of those numbers was plausible on its own. **The residual is what said the fit
    was junk**, which is the cheapest rule in `modelling_here.md` and the reason this prints one."""
    xs, ys = [x_from], [seed]
    step = -1 if x_to < x_from else 1
    for x in range(x_from + step, x_to, step):
        cand = run_mids(ink, x, y0, y1)
        if not cand:
            continue
        pred = np.polyval(np.polyfit(xs[-6:], ys[-6:], 1), x) if len(ys) >= 6 else ys[-1]
        c = min(cand, key=lambda v: abs(v - pred))
        if abs(c - pred) > jump:
            continue
        xs.append(x); ys.append(c)
    return np.array(xs, float), np.array(ys, float)


def line_fit(xs, ys, name, pxft):
    a = np.vstack([xs, np.ones_like(xs)]).T
    sol, *_ = np.linalg.lstsq(a, ys, rcond=None)
    rms = float(np.sqrt(((ys - a @ sol) ** 2).mean()))
    print("  %-14s %3d stations x=%d..%d   slope %+.5f   rms %.2f px (%.1f mm)"
          % (name, len(xs), xs.min(), xs.max(), sol[0], rms, rms / pxft * 304.8))
    return sol


# ---- the parked stance -------------------------------------------------------------------------
# PUBLISHED tyre sizes, used ONLY as a check on the circle fits -- never to set the scale.
TYRES_IN = {"nose (NLG)": 26.0, "main (MLG)": 26.0, "outrigger": 13.5}
# The row the 46.33 FT length extension lines are read at, which is the y the station datum
# SIDE_NOSE belongs to -- so a de-rotation has something to rotate ABOUT. COMPUTED from LEN_ROWS
# rather than typed beside it: one number, one place, and the first draft of this line typed 1660
# and was 491 px wrong, which is 0.8 m of aeroplane if the tilt had been larger than it is.
GROUND_RAKE_DEG = 6.5                # [SAC] page 2's printed angle -- a CHECK, and see below
WHEELBASE_FT = 11.42


def follow(ink, x_from, x_to, seed, y0, y1, jump=3.5):
    """Track one long drawn line across the page (see `track_edge` for why not "the outermost")."""
    xs, ys = [x_from], [seed]
    step = 1 if x_to > x_from else -1
    for x in range(x_from + step, x_to, step):
        mids = run_mids(ink, x, y0, y1)
        if not mids:
            continue
        pred = np.polyval(np.polyfit(xs[-8:], ys[-8:], 1), x) if len(ys) >= 8 else ys[-1]
        c = min(mids, key=lambda v: abs(v - pred))
        if abs(c - pred) > jump:
            continue
        xs.append(x); ys.append(c)
    return np.array(xs, float), np.array(ys, float)


def angle_of(xs, ys):
    a = np.vstack([xs, np.ones_like(xs)]).T
    sol, *_ = np.linalg.lstsq(a, ys, rcond=None)
    rms = float(np.sqrt(((ys - a @ sol) ** 2).mean()))
    return np.degrees(np.arctan(-sol[0])), rms, sol


def page_tilt(ink):
    """The scan's own rotation, off a panel rule that is vertical on the PRINTED page. The EA-6B's
    sheet from this same series was turned 0.26 deg (`modelling_here.md` section 3); this one is
    turned too, and an accumulator sweeping a tilted page finds lines that are not there."""
    xs, ys = [], []
    for y in range(300, 2300):
        row = np.where(ink[y, 1699:1723])[0]
        if len(row):
            ys.append(y); xs.append(1699 + row.mean())
    xs = np.array(xs, float); ys = np.array(ys, float)
    a = np.vstack([ys, np.ones_like(ys)]).T
    sol, *_ = np.linalg.lstsq(a, xs, rcond=None)
    rms = float(np.sqrt(((xs - a @ sol) ** 2).mean()))
    return np.degrees(np.arctan(sol[0])), rms, len(ys)


def stance(ink, pxft):
    from scipy.optimize import least_squares

    def hough(y0, y1, x0, x1, rmin, rmax):
        ys, xs = np.nonzero(ink[y0:y1, x0:x1]); ys = ys + y0; xs = xs + x0
        best = None
        for r in np.arange(rmin, rmax, 0.5):
            acc = {}
            for th in np.arange(0, 2 * np.pi, 0.08):
                for k in zip(np.round(xs - r * np.cos(th)).astype(int),
                             np.round(ys - r * np.sin(th)).astype(int)):
                    acc[k] = acc.get(k, 0) + 1
            (bx, by), v = max(acc.items(), key=lambda kv: kv[1])
            if best is None or v > best[0]:
                best = (v, bx, by, r)
        return best

    def refine(cx, cy, r, pad=4.0):
        ys, xs = np.nonzero(ink[int(cy - r - pad):int(cy + r + pad), int(cx - r - pad):int(cx + r + pad)])
        ys = ys + int(cy - r - pad); xs = xs + int(cx - r - pad)
        keep = np.abs(np.hypot(xs - cx, ys - cy) - r) < pad
        xs, ys = xs[keep], ys[keep]
        s = least_squares(lambda p: np.hypot(xs - p[0], ys - p[1]) - p[2], [cx, cy, r])
        return s.x[0], s.x[1], s.x[2], float(np.sqrt((s.fun ** 2).mean())), len(xs)

    print("")
    print("THE PARKED STANCE")
    tilt, trms, tn = page_tilt(ink)
    print("  the SCAN is turned %+.4f deg (panel rule, %d rows, rms %.3f px) -- removed below"
          % (tilt, tn, trms))

    boxes = (("nose (NLG)", (2010, 2090, 865, 950), (16, 26)),
             ("main (MLG)", (1990, 2070, 1080, 1165), (16, 26)),
             ("outrigger", (2005, 2065, 1135, 1180), (8, 16)))
    fits = {}
    print("  tyre            radius px   diameter in   published   rms px")
    for name, box, rr in boxes:
        _, bx, by, r = hough(*box, *rr)
        cx, cy, cr, rms, n = refine(bx, by, r)
        fits[name] = (cx, cy, cr)
        dia = 2 * cr / pxft * 12.0
        print("  %-14s %9.2f %13.2f %11.1f %8.2f  %+.1f per cent"
              % (name, cr, dia, TYRES_IN[name], rms, 100 * (dia / TYRES_IN[name] - 1)))
    print("  The published tyre sizes did NOT set the scale, so their coming back right is an")
    print("  independent check on it -- two facts that never saw each other agreeing on a third.")

    (nx, ny, nr) = fits["nose (NLG)"]
    (mx, my, mr) = fits["main (MLG)"]
    wb = (mx - nx) / pxft
    print("")
    print("  wheelbase %.3f ft   published %.2f   %+.2f per cent" % (wb, WHEELBASE_FT, 100 * (wb / WHEELBASE_FT - 1)))

    # WHERE THE TWO WHEELS ARE ALONG THE AEROPLANE, which is the question this fit was never asked.
    # The circles above were being fitted for a DAY before anybody printed a centre's station: the
    # radii were checked against the published tyre sizes and the gap between them against the
    # published wheelbase, and both came back right, so the fit was known to be good and its most
    # useful output was thrown away. The model carried `NOSE_STATION 3.05  # ESTIMATE`, 1.6 m
    # forward of this, until 2026-09-20. THE MEASUREMENT WAS TAKEN; THE QUESTION WAS NEVER ASKED
    # OF IT. That is a cheaper mistake to make than a wrong measurement and a dearer one to find.
    #
    # The datum is `measure_stations.SIDE_NOSE`, the 46.33 FT extension line, imported rather than
    # retyped. The scan's own rotation moves a point's x by tilt * (y - y_datum): the extension
    # lines are read near the dimension rows and the tyres sit ~700 px below them, so the shift is
    # about 3 px, 5 cm -- reported BOTH ways rather than silently chosen.
    import measure_stations as _ms
    tilt_rad = np.radians(tilt)
    print("")
    print("  the two tyre centres, as STATIONS from the nose (datum measure_stations.SIDE_NOSE = %.1f px)" % _ms.SIDE_NOSE)
    print("  tyre             centre px      raw station m    de-rotated m")
    for name, (cx, cy, _cr) in (("nose (NLG)", fits["nose (NLG)"]), ("main (MLG)", fits["main (MLG)"])):
        raw = (cx - _ms.SIDE_NOSE) / pxft * _ms.M
        fixed = (cx + tilt_rad * (cy - DIM_ROW) - _ms.SIDE_NOSE) / pxft * _ms.M
        print("  %-14s %7.2f, %7.2f %14.3f %15.3f" % (name, cx, cy, raw, fixed))
    print("  Their SEPARATION is the published wheelbase to %+.1f per cent and nothing was fitted to"
          % (100 * (wb / WHEELBASE_FT - 1)))
    print("  that figure, which is what says both circles were read right.")

    g_ang, g_rms, _ = angle_of(*follow(ink, 705, 1150, 2090.0, 2040, 2112))
    c_ang = np.degrees(np.arctan(-(my - ny) / (mx - nx)))
    print("")
    print("  THREE readings of the nose-up rake, each de-rotated by the scan's %+.3f deg:" % tilt)
    print("    the drawn ground line        %.3f deg  (rms %.3f px)" % (g_ang - tilt, g_rms))
    print("    the two tyre centres         %.3f deg" % (c_ang - tilt))
    print("    PRINTED on the sheet         %.3f deg" % GROUND_RAKE_DEG)
    print("""
  THE DRAWING AND ITS OWN ANNOTATION DISAGREE by about 8 per cent, and the model is built to the
  PRINTED 6.5 deg. The geometry of this sheet is demonstrably less reliable than its figures -- its
  scale bar is a fifth wrong (above) -- and 6.5 turns up again in a second document, [NATOPS] p96,
  which puts the fuselage about six and a half degrees nose-up at the hover stop. One measurement
  off a photocopied scan does not overrule a figure that two documents print. The disagreement is
  recorded rather than buried: it is 0.5 deg, about 12 cm of nose height on a 14.1 m aeroplane.""")


def threshold_sweep(grey, pxft_from_span):
    """twin310's trap, TESTED rather than assumed (lane/twin310, 2026-09-19): a threshold that keeps
    a drawing's dimension lines and lettering but loses the aeroplane's own outline lets every
    printed dimension check out over a subject that was never being seen.

    The test is not "does 128 look right" -- it is whether the ANSWERS move. They do not: from 60 to
    210 the span is 582 px at every threshold and the wing fit holds at 0.75-0.78 px rms over
    129-132 stations. This sheet draws its aeroplane at the same weight as its annotations, so there
    is no threshold that keeps one and drops the other. Printed here as evidence, not as a claim."""
    print("")
    print("THE THRESHOLD, swept -- do the answers move?")
    print("  thr   ink %   span px   LE stations   LE rms px   area sq ft   aspect")
    for thr in (60, 80, 100, 128, 150, 170, 190, 210):
        ink = grey < thr
        w, _, l, r = widest_row(ink, *PLAN_BAND)
        pxft = w / SPAN_FT
        centre = (l + r) / 2.0
        lex, ley = track_edge(ink, 1332, 1200, 723.0)
        tex, tey = track_edge(ink, 1332, 1200, 659.0)
        a = np.vstack([lex, np.ones_like(lex)]).T
        le, *_ = np.linalg.lstsq(a, ley, rcond=None)
        rms = float(np.sqrt(((ley - a @ le) ** 2).mean()))
        b = np.vstack([tex, np.ones_like(tex)]).T
        te, *_ = np.linalg.lstsq(b, tey, rcond=None)
        ch = lambda x: (le[0] * x + le[1]) - (te[0] * x + te[1])
        tip_x = centre + SPAN_FT / 2 * pxft
        area = (ch(centre) / pxft + ch(tip_x) / pxft) / 2 * SPAN_FT
        print("  %3d %7.2f %9d %13d %11.2f %12.2f %8.3f"
              % (thr, 100 * ink.mean(), w, len(lex), rms, area, SPAN_FT ** 2 / area))
    print("  Nothing moves. The outline and the annotations share a line weight on this sheet.")


def belly(ink, pxft):
    """Where the LOW INK under the fuselage runs, which is the LIDS strakes and the gun pods.

    WRITTEN TO TEST A HYPOTHESIS, AND IT KILLED IT, WHICH IS WHY IT IS STILL HERE. [SAC] page 3 says
    the LIDS are "two longitudinal strakes and a retractable forward fence mounted on the lower
    fuselage BETWEEN THE NOSE AND MAIN GEAR". When the undercarriage turned out to be 1.63 m too far
    forward, that sentence made it look as though `LIDS_FROM` 4.30 and `LIDS_TO` 7.90 must have been
    hung off the wrong gear stations and dragged forward with them -- a wrong number quietly
    propagating into a part nobody suspected. It was a good story and it is false. The drawing puts
    the low ink at stations 4.35 to 7.90, which is what the model already had to within 5 cm, so
    those bounds were MEASURED off this sheet and owe the gear nothing.

    The sentence is prose, not a dimension: the strakes sit either side of the centreline and the
    legs come down BETWEEN them, which is how a Harrier's belly is arranged, and "between the nose
    and main gear" describes that region rather than bounding it. A published sentence that reads
    like a constraint is still not a measurement.

    What comes back is an OUTER BOUND rather than the pods themselves. The low ink here is the
    strakes AND the gear legs AND the well doors together; `measure_stations.side_outline` stops
    short of the raked ground line so the wheels are excluded, but nothing separates a strake from a
    door at 15.9 mm a pixel.
    """
    import measure_stations as _ms
    pxm = pxft / _ms.M
    rake = np.tan(np.radians(GROUND_RAKE_DEG))
    rows = []
    for station in np.arange(2.0, 10.6, 0.05):
        x = int(round(_ms.SIDE_NOSE + station * pxm))
        seen = _ms.side_outline(ink, x)
        if seen:
            rows.append((station, (_ms.ground_at(x) - seen[1]) / pxm + station * rake))
    rows = np.array(rows)
    # The clean belly, taken FORWARD of and AFT of the region in question and never inside it, so
    # the reference cannot be pulled down by the thing it is the reference for.
    forward = rows[(rows[:, 0] > 2.6) & (rows[:, 0] < 4.2), 1]
    aft = rows[(rows[:, 0] > 9.2) & (rows[:, 0] < 10.4), 1]
    clean = float(np.median(np.concatenate([forward, aft])))
    below = rows[rows[:, 1] < clean - 0.15]

    print("")
    print("THE BELLY'S LOW INK -- the strakes, the gun pods, the legs and the doors together")
    print("  the clean belly either side of them sits %.3f m over the datum" % clean)
    runs, run = [], [below[0]]
    for row in below[1:]:
        if row[0] - run[-1][0] < 0.12:
            run.append(row)
        else:
            runs.append(np.array(run)); run = [row]
    runs.append(np.array(run))
    for group in runs:
        if len(group) > 3:
            print("  a run from station %5.2f to %5.2f, averaging %.3f m below the clean belly"
                  % (group[0, 0], group[-1, 0], clean - group[:, 1].mean()))
    print("  The model's LIDS_FROM and LIDS_TO are 4.30 and 7.90. The first run above is what they")
    print("  were measured from, and it is why they did NOT move when the undercarriage did.")
    return clean, runs


def main(research_dir):
    grey, ink, dark = load(research_dir)
    print("scan %d x %d, ink %.2f per cent\n" % (grey.shape[1], grey.shape[0], 100 * ink.mean()))

    # ---- 1. the printed scale bar, and why it is not used -------------------------------------
    print("THE PRINTED SCALE BAR")
    ticks = np.array([centre_of(dark, t, BAR_ROWS) for t in BAR_TICKS])
    gaps = np.diff(ticks)
    bar_pxft = (ticks[-1] - ticks[0]) / BAR_FEET
    print("  ticks      %s" % np.round(ticks, 2))
    print("  5 ft gaps  %s   mean %.2f  sd %.2f px (%.1f per cent)"
          % (np.round(gaps, 2), gaps.mean(), gaps.std(ddof=1), 100 * gaps.std(ddof=1) / gaps.mean()))
    print("  -> %.3f px/ft  ** NOT USED, see the module doc block **\n" % bar_pxft)

    # ---- 2. the scale, from the published span ALONE -------------------------------------------
    w, row, left, right = widest_row(ink, *PLAN_BAND)
    pxft = w / SPAN_FT
    centre = (left + right) / 2.0
    print("THE SCALE, from the published %.2f ft span and nothing else" % SPAN_FT)
    print("  plan widest row y=%d, x %d..%d = %d px, centreline %.1f" % (row, left, right, w, centre))
    print("  -> %.4f px/ft   ONE PIXEL IS %.1f mm\n" % (pxft, 304.8 / pxft))

    # ---- 3. do the three views agree? ----------------------------------------------------------
    print("DO THE THREE VIEWS SHARE ONE SCALE?")
    reads = [("plan, %.2f ft span" % SPAN_FT, pxft)]
    ext = thin_verticals(ink, EXT_ROWS, *EXT_X)
    if len(ext) >= 2:
        a = centre_of(dark, int(sum(ext[0]) / 2), EXT_ROWS)
        b = centre_of(dark, int(sum(ext[-1]) / 2), EXT_ROWS)
        reads.append(("plan, %.2f ft tailplane" % TAILPLANE_FT, (b - a) / TAILPLANE_FT))
    fw = widest_row(ink, *FRONT_BAND)
    reads.append(("front, %.2f ft span" % SPAN_FT, fw[0] / SPAN_FT))
    lext = thin_verticals(ink, LEN_ROWS, *LEN_X)
    if len(lext) >= 2:
        a = centre_of(dark, int(sum(lext[0]) / 2), LEN_ROWS)
        b = centre_of(dark, int(sum(lext[-1]) / 2), LEN_ROWS)
        reads.append(("side, %.2f ft length" % LENGTH_FT, (b - a) / LENGTH_FT))
    vals = np.array([r[1] for r in reads])
    for name, v in reads:
        print("  %-26s %7.3f px/ft" % (name, v))
    print("  spread %.2f per cent about the mean %.3f" % (100 * (vals.max() - vals.min()) / vals.mean(), vals.mean()))
    print("  the printed bar sits %+.1f per cent from that mean\n" % (100 * (bar_pxft / vals.mean() - 1)))

    # ---- 4. the wing, and the check that tests BOTH axes ---------------------------------------
    print("THE WING, outer panel tracked from the tip inboard")
    lex, ley = track_edge(ink, 1332, 1200, 723.0)
    tex, tey = track_edge(ink, 1332, 1200, 659.0)
    le = line_fit(lex, ley, "leading edge", pxft)
    te = line_fit(tex, tey, "trailing edge", pxft)

    chord = lambda x: (le[0] * x + le[1]) - (te[0] * x + te[1])
    tip_x = centre + SPAN_FT / 2 * pxft
    root_ft, tip_ft = chord(centre) / pxft, chord(tip_x) / pxft
    area = (root_ft + tip_ft) / 2 * SPAN_FT
    aspect = SPAN_FT ** 2 / area
    taper = tip_ft / root_ft
    mac = (2 / 3) * root_ft * (1 + taper + taper ** 2) / (1 + taper)
    qc_r = (te[0] * centre + te[1]) + 0.75 * chord(centre)
    qc_t = (te[0] * tip_x + te[1]) + 0.75 * chord(tip_x)
    sweep_qc = np.degrees(np.arctan(abs(qc_t - qc_r) / (tip_x - centre)))
    sweep_le = np.degrees(np.arctan(abs(le[0])))

    print("\nTHE REFERENCE TRAPEZOID, the outer panel's edges extended to the centreline")
    print("  root chord %6.2f ft (%.3f m)   tip %5.2f ft (%.3f m)   taper %.3f"
          % (root_ft, root_ft * 0.3048, tip_ft, tip_ft * 0.3048, taper))
    print("  leading-edge sweep %.2f deg\n" % sweep_le)

    print("THE CHECK -- four printed figures, NONE of which set the scale")
    for name, got, want in (("AREA, sq ft", area, AREA_SQFT), ("ASPECT RATIO", aspect, ASPECT),
                            ("M.A.C., ft", mac, MAC_FT), ("SWEEP @ 25%c, deg", sweep_qc, SWEEP_QC_DEG)):
        print("  %-18s measured %8.3f   printed %7.2f   %+6.2f per cent"
              % (name, got, want, 100 * (got / want - 1)))
    print("\n  Area and aspect ratio are one fact, not two (AR = b^2 / S); M.A.C. and the sweep are")
    print("  independent of them. All four inside two per cent, with the scale set from the span")
    print("  alone, is what says this view is ISOTROPIC and may be measured in both directions.")

    stance(ink, pxft)
    belly(ink, pxft)
    threshold_sweep(grey, pxft)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1
         else r"C:\Users\Graham\godotgames-drafts\2026-09-19\cockpit-harrier\research")
