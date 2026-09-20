"""The AV-8B's FRONTAL shape, off [SAC] page 2's front view -- the one view on the sheet nobody had
measured, and the only one that shows a cross-section.

    python measure_front.py [path-to-research-dir]

WHY THIS EXISTS. `measure_stations.py` takes the side view's top and bottom outline and the plan
view's half-width, and between them they pin the SILHOUETTE: how deep the aeroplane is at each
station and how wide. They say nothing about the shape of the RING joining those four extremes, and
that ring is what makes an aeroplane look like itself. `harrier_airframe.SECTIONS` carries four
intermediate width/height pairs per station -- crown, shoulder, chine, under, belly -- and every one
of them was JUDGED rather than measured, because there was no instrument that could measure them.

The front view is that instrument. It is used elsewhere on this sheet for exactly one thing, a span
cross-check at `measure_sac.py`'s `FRONT_BAND`, and then dropped.

WHAT IT IS GOOD FOR AND WHAT IT IS NOT. It is good for WIDTHS and for the shape of the frontal
outline. It is NOT used here for heights, and that is a decision rather than an oversight: the front
view's lower half is a thicket of main gear, outrigger legs, gun pods and the 17.00 FT dimension's
own extension lines, and a datum picked out of that is a guess wearing a number. The side view's
top and bottom lines are already measured and already validated against the published height, so
heights come from there and the front view is registered against them. One instrument per question.

TWO PUBLISHED FIGURES CHECK THIS VIEW'S OWN SCALE, and neither sets it:

  - the 30.33 FT span across the wing tips, and
  - the 17.00 FT outrigger tread, whose dimension EXTENSION LINES are drawn on this view.

Both come back about one per cent large, which is this sheet's ordinary internal spread, and both
are printed below as residuals so a reader can see it rather than take it on trust.

THE WING AND THE PYLONS ARE EXCLUDED BY CONTINUITY, NOT BY A WINDOW. A window is a measurement
decision that hides inside housekeeping -- `measure_stations.py`'s doc block says so, having been
bitten by one -- and here a window cannot work anyway, because the wing crosses the body's own edge
on its way outboard. Instead the body's outline is TRACKED from a row below the wing, taking at each
step the ink nearest a prediction from the last few accepted points. The track is abandoned, loudly,
at the row where the wing root merges into the body's edge, because past that point no rule
distinguishes them and a number produced there would be a guess.

THE OUTER EDGE IS SYMMETRIC OR IT IS REFUSED, port against starboard, with a pixel floor for the
same reason `measure_stations.plan_half` needs one: a pure percentage is sub-pixel where the body is
narrow, and a guard that cannot be satisfied is as useless as one that cannot fail.
"""

import sys
import numpy as np
from measure_sac import load, widest_row, SPAN_FT, PLAN_BAND

M = 0.3048

# ---- PUBLISHED. Checks, never inputs. [SAC] page 3's DIMENSIONS table.
PUBLISHED_SPAN_M = 9.245
PUBLISHED_TREAD_M = 5.182      # "Tread (outrigger) 17.0 ft", dimensioned on THIS view
PEGASUS_DIA_M = 1.219          # [WP] Rolls-Royce Pegasus infobox, "diameter 48 in (1.219 m)"

# Where the front view lives on the 3510 x 2552 scan. Generous windows, stated rather than magic.
FRONT_ROWS = (1360, 1700)
FRONT_X = (700, 1500)
BODY_REACH = 130               # px either side of the centreline that the BODY can possibly occupy
                               # (the widest it gets is about 78 px; this is slack, not a limit)
TRACK_SEED_ROW = 1620          # a row below the wing and the pylons where the body edge is alone
TREAD_ROWS = (1670, 1700)      # the 17.00 FT dimension's extension lines, clear of the tyres


def runs(ink, y, x0, x1):
    """Every contiguous ink run in one row, as (first, last) columns."""
    c = np.where(ink[y, x0:x1])[0] + x0
    if len(c) == 0:
        return []
    out, start = [], c[0]
    for i in range(1, len(c)):
        if c[i] != c[i - 1] + 1:
            out.append((start, c[i - 1]))
            start = c[i]
    out.append((start, c[-1]))
    return out


def centreline(ink):
    """The front view's own centreline, from the span row -- the aeroplane, not the page."""
    w, row, xmin, xmax = widest_row(ink, *FRONT_ROWS, *FRONT_X)
    return (xmin + xmax) / 2.0, w, row


def track_body_edge(ink, centre, sign, jump=5.0):
    """The body's outer edge on one side, tracked UPWARD from below the wing by continuity.

    Returns (rows, offsets_px, merged_at) -- `merged_at` being the row where the track had to be
    abandoned because the wing root had merged with the body's edge, or None if it never did.

    WHY UPWARD. Below the wing the body's edge is the only ink at that distance from the
    centreline, so the seed is unambiguous. Going up, the edge bulges out to the intake bell's
    widest point and then turns back in towards the wing root, where the wing's own lower surface
    arrives from outboard and the two lines touch. A max() over the row takes the wing from the
    first row where it is inside BODY_REACH; a prediction from the last few points does not."""
    xs, ys = [], []
    merged = None
    prev = None
    for y in range(TRACK_SEED_ROW, FRONT_ROWS[0], -1):
        rr = runs(ink, y, int(centre) - BODY_REACH, int(centre) + BODY_REACH)
        if not rr:
            continue
        # the outer end of each run on this side, as a signed offset from the centreline
        cand = [sign * (r[1] - centre) if sign > 0 else sign * (r[0] - centre) for r in rr]
        cand = [c for c in cand if c > 0]
        if not cand:
            continue
        if prev is None:
            prev = max(cand)          # the seed row: the body IS the outermost thing here
            xs.append(y); ys.append(prev)
            continue
        pred = np.polyval(np.polyfit(xs[-6:], ys[-6:], 1), y) if len(ys) >= 6 else prev
        best = min(cand, key=lambda v: abs(v - pred))
        if abs(best - pred) > jump:
            merged = y
            break
        # the wing arriving: a run whose FAR end is far outboard but whose near end sits on the
        # prediction is the wing root touching the body, not the body.
        xs.append(y); ys.append(best); prev = best
    return np.array(xs), np.array(ys), merged


def main(research_dir):
    _, ink, _ = load(research_dir)
    pxft = widest_row(ink, *PLAN_BAND)[0] / SPAN_FT
    print("scale %.4f px/ft, imported from measure_sac (one number, one place); 1 px = %.1f mm\n"
          % (pxft, 304.8 / pxft))

    centre, span_px, span_row = centreline(ink)
    span_m = span_px / pxft * M
    print("THE FRONT VIEW'S OWN SCALE, CHECKED TWICE AND SET BY NEITHER")
    print("  span across the tips   %.3f m   published %.3f   %+.2f per cent  (row %d, centreline x=%.1f)"
          % (span_m, PUBLISHED_SPAN_M, 100 * (span_m / PUBLISHED_SPAN_M - 1), span_row, centre))

    # the 17.00 FT dimension's extension lines, which is what the drawing itself calls the tread
    ext = []
    for y in range(*TREAD_ROWS):
        for a, b in runs(ink, y, int(centre) - 260, int(centre) + 260):
            if b - a <= 3 and abs((a + b) / 2.0 - centre) > 100:
                ext.append((a + b) / 2.0)
    if ext:
        left = np.median([e for e in ext if e < centre])
        right = np.median([e for e in ext if e > centre])
        tread_m = (right - left) / pxft * M
        print("  outrigger tread        %.3f m   published %.3f   %+.2f per cent  (the 17.00 FT"
              " dimension's own extension lines)"
              % (tread_m, PUBLISHED_TREAD_M, 100 * (tread_m / PUBLISHED_TREAD_M - 1)))
    print("")

    # ---- the body's frontal outline ----------------------------------------------------------
    port_y, port_o, port_merge = track_body_edge(ink, centre, -1)
    star_y, star_o, star_merge = track_body_edge(ink, centre, +1)
    print("THE BODY'S FRONTAL OUTLINE, tracked from row %d upward by continuity" % TRACK_SEED_ROW)
    print("  port      %3d rows, abandoned at y=%s" % (len(port_y), port_merge))
    print("  starboard %3d rows, abandoned at y=%s" % (len(star_y), star_merge))
    print("  (the abandonment row is where the WING ROOT merges with the body's edge; past it no")
    print("   rule tells them apart, so nothing is reported rather than something being guessed)")
    print("")
    print("     y     port_m   starb_m    mean_m    asymmetry     (a dash = the row refused itself)")

    shared = sorted(set(port_y.tolist()) & set(star_y.tolist()), reverse=True)
    pmap = dict(zip(port_y.tolist(), port_o.tolist()))
    smap = dict(zip(star_y.tolist(), star_o.tolist()))
    best = (0.0, 0)
    kept = 0
    for y in shared:
        p, s = pmap[y], smap[y]
        wider = max(p, s)
        # SYMMETRY WITH A PIXEL FLOOR, for measure_stations.plan_half's reason.
        if abs(p - s) > max(0.06 * wider, 3.0):
            if y % 4 == 0:
                print("  %5d %10s %9s %9s %12s" % (y, "-", "-", "-", "refused"))
            continue
        kept += 1
        mean = (p + s) / 2.0
        if mean > best[0]:
            best = (mean, y)
        if y % 4 == 0:
            print("  %5d %10.3f %9.3f %9.3f %12.2f px"
                  % (y, p / pxft * M, s / pxft * M, mean / pxft * M, abs(p - s)))

    half_m = best[0] / pxft * M
    print("")
    print("THE WIDEST THE FUSELAGE EVER GETS -- the intake bells, which on this aeroplane ARE the")
    print("widest part of the body and are the reason the front view was worth measuring:")
    print("  half-width %.3f m at y=%d, so the body is %.3f m across."
          % (half_m, best[1], 2 * half_m))
    print("  %d of %d shared rows passed the symmetry test." % (kept, len(shared)))
    print("")
    print("  Corrected for this view reading about one per cent large (above), that is a maximum")
    print("  fuselage half-width of about %.3f m." % (half_m * PUBLISHED_SPAN_M / span_m))
    print("")
    print("A PUBLISHED FLOOR THE INTAKES MUST CLEAR, and it is not the measurement above.")
    print("  [WP]'s Pegasus infobox gives the engine diameter as 48 in (%.3f m). TWO intakes feed"
          % PEGASUS_DIA_M)
    print("  that ONE fan, so on area alone each duct needs an inner capture diameter of at least")
    print("  %.3f/sqrt(2) = %.3f m. This is a CHECK on a bell measured off the drawing, never a"
          % (PEGASUS_DIA_M, PEGASUS_DIA_M / np.sqrt(2.0)))
    print("  size the model is built to -- nothing may be fitted to a bound a test then checks.")


def sweep(research_dir):
    """THE SAME MEASUREMENT AT EVERY THRESHOLD FROM 60 TO 225, so a reader can see whether the
    conclusion depends on where the line between ink and paper was drawn. `lane/twin310` adopted
    this from `lane/harrier` and found its own page fails below 180 -- and printed that."""
    from PIL import Image
    grey = np.array(Image.open(research_dir + r"\sac-native-p4-0.png").convert("L")).astype(float)
    print("\nTHRESHOLD SWEEP -- the widest fuselage half-width at each ink threshold")
    print("  threshold   half_m   rows_kept")
    for t in range(60, 226, 15):
        ink = grey < t
        try:
            pxft = widest_row(ink, *PLAN_BAND)[0] / SPAN_FT
            centre, _, _ = centreline(ink)
            py, po, _ = track_body_edge(ink, centre, -1)
            sy, so, _ = track_body_edge(ink, centre, +1)
            pmap, smap = dict(zip(py.tolist(), po.tolist())), dict(zip(sy.tolist(), so.tolist()))
            shared = set(pmap) & set(smap)
            vals = [(pmap[y] + smap[y]) / 2.0 for y in shared
                    if abs(pmap[y] - smap[y]) <= max(0.06 * max(pmap[y], smap[y]), 3.0)]
            print("  %9d %8.3f %11d" % (t, max(vals) / pxft * M if vals else float("nan"), len(vals)))
        except Exception as exc:
            print("  %9d   failed: %s" % (t, exc))


if __name__ == "__main__":
    where = sys.argv[1] if len(sys.argv) > 1 \
        else r"C:\Users\Graham\godotgames-drafts\2026-09-19\cockpit-harrier\research"
    main(where)
    sweep(where)
