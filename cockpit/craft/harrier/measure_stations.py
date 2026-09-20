"""The AV-8B's fuselage stations, off [SAC] page 2: the side view's top and bottom outline and the
plan view's half-width, station by station, ready for the airframe's SECTIONS table.

IT IMPORTS ITS SCALE FROM `measure_sac.py` rather than keeping a copy. One number, one place: if the
scale is ever re-derived, this moves with it, and the two cannot drift into disagreeing about how
big the aeroplane is.

    python measure_stations.py [path-to-research-dir]

TWO THINGS THIS GOT WRONG FIRST, both worth the reader's time because both produced numbers that
looked like measurements:

1. **HEIGHTS ARE OVER THE RAKED GROUND UNDER EACH STATION, not over one ground level.** The
   aeroplane parks 6.5 degrees nose-up, so a single datum taken under the nose over-reads
   everything aft of it -- by 14.1 m x tan(6.5 deg) = 1.61 m at the tail. The first run put the fin
   tip at 5.12 m against a published 3.551 and looked like a badly drawn aeroplane. It was a badly
   chosen datum. `ProwlerAirframe.ground_at(station)` exists for exactly this reason.

2. **A SEARCH WINDOW IS PART OF THE MEASUREMENT.** The plan view's half-width was first taken over
   the whole panel, which contains the `SCALE IN FEET` bar and the AIRFOIL DESIGNATION text block.
   It returned half-widths of 5.8 m on an aeroplane whose semi-span is 4.62 -- wider than the
   aeroplane can be, which is the only reason it was caught. A window that includes the wrong ink
   does not fail; it answers confidently about the wrong object.

WHAT THIS CANNOT DO, said plainly. It extracts the drawn SILHOUETTE. Separating the fuselage proper
from the wing root, the gun and strake pods and the gear is a judgement the modeller makes with the
cutaway ([NATOPS] Figure 1-1) beside the outline -- it is not something a column of pixels knows.
The F-35B's `SECTIONS` block carries the same distinction by hand, and says so.
"""

import sys
import numpy as np
from measure_sac import load, widest_row, SPAN_FT, PLAN_BAND

M = 0.3048

# The ground line as `measure_sac.stance` fits it: y = GA*x + GB, from 445 px of drawn line at
# 0.277 px rms. Heights below are over THIS, per station, not over a level.
GA = -0.108943
GB = 2090.0 - GA * 705.0

SIDE_NOSE, SIDE_TAIL = 610.5, 1500.5   # the 46.33 FT extension lines -- 890 px, the published length
PLAN_CENTRE = 1050.0
PLAN_X = (755, 1348)                   # the span, and deliberately nothing else: see the doc block
SIDE_TOP = 1778                        # below the 17.00 FT dimension, which is not the aeroplane
PUBLISHED_HEIGHT_M = 3.551
PUBLISHED_SEMISPAN_M = 4.6225

# THE TWO THINGS ON THIS PAGE THAT ARE INSIDE THE SPAN AND ARE NOT THE AEROPLANE: the `SCALE IN FEET`
# bar with its numerals and caption, and the AIRFOIL DESIGNATION block. Boxes (x0, x1, y0, y1).
#
# The symmetry test below is the general guard and it catches most of this, but it is not sufficient
# ON ITS OWN and that is worth stating: at row 1196 the scale bar sits to port and the airfoil text to
# starboard at nearly the same distance, so the row LOOKED symmetric and reported a 4.686 m half-width
# at the nose -- and that row was then taken as the plan's nose tip, putting every station 2.4 m out.
# Two independent errors can conspire to pass a symmetry check. Belt and braces: mask what is known,
# and keep the symmetry test for what is not.
PLAN_MASKS = ((0, 800, 1160, 1290), (1130, 1500, 975, 1215))


def ground_at(x):
    return GA * x + GB


def side_outline(ink, x, pad=3.0):
    """The drawn silhouette at one station, stopping short of the ground line and its wheels."""
    hi = int(ground_at(x) - pad)
    if hi <= SIDE_TOP:
        return None
    r = np.where(ink[SIDE_TOP:hi, x])[0] + SIDE_TOP
    return (int(r.min()), int(r.max())) if len(r) else None


def _plan_ink(ink, y):
    """Every ink column of the plan view at one row, with the two known non-aeroplane boxes removed."""
    c = np.where(ink[y, PLAN_X[0]:PLAN_X[1]])[0] + PLAN_X[0]
    for x0, x1, y0, y1 in PLAN_MASKS:
        if y0 <= y <= y1:
            c = c[(c < x0) | (c > x1)]
    return c


def plan_half(ink, y, tol=0.06, floor=3.0):
    """The plan silhouette's half-width at one row -- or None where the row cannot be trusted.

    THE AEROPLANE IS ITS OWN VALIDITY TEST. An aircraft in plan is symmetric about its centreline, so a
    row whose left and right extremes disagree is not measuring the aircraft. That is not hypothetical:
    the first version of this took the outermost ink over the whole panel width and the column jumped
    between 0.46 m and 4.72 m at ADJACENT quarter-metre stations, because the `SCALE IN FEET` bar (rows
    ~1178-1196) and the AIRFOIL DESIGNATION text block (rows ~1000-1140) sit inside the span at exactly
    the rows that carry the FORWARD FUSELAGE -- stations 1.0 to 3.8, which is the whole nose.

    Masking the two boxes by hand would work until the next drawing put something else there. Asking the
    aeroplane to be symmetric catches both of them and anything else, and REFUSES the row rather than
    answering confidently about the wrong object."""
    c = _plan_ink(ink, y)
    if len(c) < 2:
        return None
    right = c.max() - PLAN_CENTRE
    left = PLAN_CENTRE - c.min()
    widest = max(right, left)
    # THE TOLERANCE NEEDS A PIXEL FLOOR. A pure percentage is sub-pixel where the aeroplane is narrow:
    # at the nose the half-width is about six pixels, six per cent of which is a third of a pixel, so
    # every row of the nose refused itself and the plan's "nose tip" came out 2.4 m aft of the real one
    # -- an 17 per cent short aeroplane. A guard that is impossible to satisfy is as bad as one that
    # cannot fail.
    if widest <= 0.0 or abs(right - left) > max(tol * widest, floor):
        return None
    return widest


def plan_body(ink, y, tol=0.20, floor=3.0):
    """The FUSELAGE's own half-width: the nearest ink either side of the centreline, rather than the
    outermost. Held to the same symmetry test, and it is the honest figure only FORWARD OF THE WING --
    abeam the wing the nearest line to the centreline is a wing root or a panel line, and no column of
    pixels can tell those from a fuselage side. That separation is the modeller's judgement with the
    flight manual's cutaway open, and it is said here rather than left to be discovered."""
    c = _plan_ink(ink, y)
    r = c[c > PLAN_CENTRE + 2]
    l = c[c < PLAN_CENTRE - 2]
    if len(r) == 0 or len(l) == 0:
        return None
    right = r.min() - PLAN_CENTRE
    left = PLAN_CENTRE - l.max()
    widest = max(right, left)
    if widest <= 0.0 or abs(right - left) > max(tol * widest, floor):
        return None
    return widest


def main(research_dir):
    _, ink, _ = load(research_dir)
    w, _, _, _ = widest_row(ink, *PLAN_BAND)
    pxft = w / SPAN_FT
    print("scale %.4f px/ft, imported from measure_sac (one number, one place)\n" % pxft)

    ys = [y for y in range(300, 1240) if plan_half(ink, y) is not None]
    plan_nose_y, plan_tail_y = max(ys), min(ys)
    plan_len = (plan_nose_y - plan_tail_y) / pxft * M
    print("plan view nose y=%d tail y=%d, its own length %.3f m (%+.2f per cent off the side view's"
          " published 14.122)" % (plan_nose_y, plan_tail_y, plan_len, 100 * (plan_len / 14.122 - 1)))
    print("")
    print("  station   top_m   bottom_m    outer_m     body_m      (a dash = the row refused itself)")

    rows = []
    s = 0.0
    while s <= 14.25:
        x = int(round(SIDE_NOSE + s / M * pxft))
        y = int(round(plan_nose_y - s / M * pxft))
        so = side_outline(ink, x)
        hw = plan_half(ink, y)
        bw = plan_body(ink, y)
        if so:
            g = ground_at(x)
            top, bot = (g - so[0]) / pxft * M, (g - so[1]) / pxft * M
            half = hw / pxft * M if hw is not None else float("nan")
            body = bw / pxft * M if bw is not None else float("nan")
            rows.append((s, top, bot, half, body))
            print("  %7.2f %7.3f %10.3f %10s %10s"
                  % (s, top, bot,
                     "%.3f" % half if hw is not None else "-",
                     "%.3f" % body if bw is not None else "-"))
        s += 0.25

    tops = [r[1] for r in rows]
    halves = [r[3] for r in rows if r[3] == r[3]]
    refused = sum(1 for r in rows if r[3] != r[3])
    print("")
    print("TWO MORE PUBLISHED FIGURES RETURNED, neither of which set the scale:")
    print("  tallest drawn point %.3f m   published height     %.3f   %+.2f per cent"
          % (max(tops), PUBLISHED_HEIGHT_M, 100 * (max(tops) / PUBLISHED_HEIGHT_M - 1)))
    print("  widest half-width   %.3f m   published semi-span  %.3f   %+.2f per cent"
          % (max(halves), PUBLISHED_SEMISPAN_M, 100 * (max(halves) / PUBLISHED_SEMISPAN_M - 1)))
    print("  %d of %d rows refused themselves on the symmetry test and are printed as a dash."
          % (refused, len(rows)))
    print("")
    print("  With the area, aspect ratio, M.A.C., quarter-chord sweep, three tyre diameters and the")
    print("  wheelbase from measure_sac, that is NINE published figures the drawing returns within")
    print("  about two per cent on a scale set by the span alone.")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1
         else r"C:\Users\Graham\godotgames-drafts\2026-09-19\cockpit-harrier\research")
