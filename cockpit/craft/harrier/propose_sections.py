"""The AV-8B's SECTIONS table, PROPOSED from the measurements rather than judged against them.

    python propose_sections.py [path-to-research-dir]

`harrier_airframe.SECTIONS` is [station, top, crown_w, crown_h, shoulder_w, shoulder_h, chine_w,
chine_h, under_w, under_h, belly_w, bottom] -- a top height, a bottom height, and five intermediate
width/height pairs that say what shape the ring between them is. The top and the bottom came off
`measure_stations.py` and are the drawing's. **The five pairs were judged**, and this script is
where they stop being judged.

WHAT SETS THE WIDTH AT EACH STATION, and where each number comes from:

  stations 0.0 to 2.0   the plan view's own fuselage half-width. `plan_half` (the OUTERMOST ink)
                        and `plan_body` (the NEAREST ink either side of the centreline) agree to
                        about 0.05 m through here, and when the outermost and the innermost edge
                        are the same edge there is only one line there -- which is the fuselage
                        side and nothing else. About 0.48 m.

  stations 2.0 to 4.4   THE INTAKES, and they are measurable in TWO views that were not compared
                        until now. In plan the outer half-width runs 1.048, 1.144, 1.175, 1.175,
                        1.160, 1.160, 1.160, 1.175, 1.191, 1.223 from station 2.00 to 4.25. In the
                        front view `measure_front.py` tracks the body's widest point to 1.239 m.
                        Two views, two instruments, the same 1.2 m.

  stations 8.5 to 10.0  the plan view again, and again with both edges agreeing: 0.635, 0.619,
                        0.588, 0.524, 0.492, 0.445. The rear fuselage is about half a metre of
                        half-width and the model has very nearly twice that.

  stations 4.5 to 8.0   NOTHING MEASURES THIS, and it is said rather than papered over. The wing
                        covers the fuselage side in plan and the front view is a projection that
                        cannot say which station its widest point belongs to. The body is
                        interpolated through here between two measured ends, and that is the one
                        judged thing left in the table.

THE RING IS AN ELLIPSE, not a wedge. Given a top T, a bottom B and a maximum half-width W, the five
pairs sit at 30-degree steps round the ellipse through them: crown at 30 degrees, shoulder at 60,
chine at 90 (the widest), under at 120, belly at 150. A Harrier's fuselage is a round barrel with
the intakes hung on its sides; the previous table's chine sat 0.3 to 0.5 m proud of its neighbours
at every station, which is a chined wedge and is what made the aeroplane read as an F-35.

THE INTAKES COME OFF THE BODY. In the old table the fuselage was 1.44 m of half-width at station
6.00 -- WIDER THAN THE REAL AEROPLANE'S INTAKES -- and the intakes were boxes reaching 1.34, so
they were inside the body and could not possibly read. The body is narrowed to what is drawn and
the bells are built as their own part standing proud of it.
"""

import sys
import numpy as np
from measure_sac import load, widest_row, SPAN_FT, PLAN_BAND
import measure_stations as ms

M = 0.3048
RAKE = np.tan(np.radians(6.5))

# The MEASURED fuselage half-width at the stations where the drawing actually shows it. Every one
# of these is read off the printed column below, not typed from memory; the script prints both so
# they can be compared. Stations 4.5 to 8.0 are absent on purpose -- see the doc block.
# THE PREVIOUS TABLE'S TOP AND BOTTOM, as (station, top, bottom). These are carried here rather
# than imported from the airframe for `measure_sac.py`'s reason: a script that proposes a
# replacement for a table must not read that table, or it can only ever agree with it. They are
# used ONLY at the stations where the drawing's outer silhouette is a fin, a gun pod or a
# tailplane rather than the fuselage, and the printout says which those are.
JUDGED = [
    (0.30, 2.15, 1.82), (0.75, 2.30, 1.74), (1.25, 2.47, 1.69), (1.75, 2.74, 1.67),
    (2.25, 3.04, 1.66), (2.75, 3.43, 1.65), (3.25, 3.44, 1.63), (3.75, 3.36, 1.60),
    (4.25, 3.24, 1.55), (4.75, 3.22, 1.44), (5.35, 3.30, 1.30), (6.00, 3.32, 1.18),
    (6.75, 3.30, 1.12), (7.50, 3.30, 1.10), (8.35, 3.31, 1.12), (9.00, 3.26, 1.22),
    (9.75, 3.26, 1.34), (10.50, 3.30, 1.46), (11.25, 3.32, 1.62), (12.00, 3.34, 1.82),
    (12.75, 3.34, 2.06), (13.55, 3.30, 2.36), (14.05, 3.22, 2.70),
]
# THE AFT TOPS WERE RE-JUDGED ONCE, and the picture is why. The previous table ran them 3.40, 3.56,
# 3.65, 3.66, 3.62, 3.52 -- a dorsal hump that RISES towards the tail. Paired with a belly that had
# been raised half a metre to the drawn line, station 12.00 came out DEEPER than station 10.50 and
# the tailcone visibly bulged. A fuselage top cannot be measured here because the FIN is the highest
# ink from station 10.55 aft, so this is a judgement either way; it is now a gentle rise to 3.34,
# which is `FIN_ROOT_HIGH`, so the fin root sits ON the spine instead of being buried in it.

WIDTH_ANCHORS = [
    (0.30, 0.46), (0.75, 0.48), (1.25, 0.48), (1.75, 0.48),
    (2.25, 0.62), (2.75, 0.70), (3.25, 0.72), (3.75, 0.74), (4.25, 0.76),
    (8.35, 0.64), (9.00, 0.57), (9.75, 0.49), (10.50, 0.42),
    (11.25, 0.34), (12.00, 0.27), (12.75, 0.20), (13.55, 0.12), (14.05, 0.05),
]


def measured_column(research_dir):
    """The drawing's own top, bottom and plan half-widths, brought into the LEVEL frame."""
    _, ink, _ = load(research_dir)
    pxft = widest_row(ink, *PLAN_BAND)[0] / SPAN_FT
    ys = [y for y in range(300, 1240) if ms.plan_half(ink, y) is not None]
    nose_y = max(ys)
    rows = {}
    s = 0.0
    while s <= 14.25:
        x = int(round(ms.SIDE_NOSE + s / M * pxft))
        y = int(round(nose_y - s / M * pxft))
        so = ms.side_outline(ink, x)
        if so:
            g = ms.ground_at(x)
            lift = s * RAKE                       # the drawing's ground is raked; the model is level
            hw = ms.plan_half(ink, y)
            bw = ms.plan_body(ink, y)
            rows[round(s, 2)] = (
                (g - so[0]) / pxft * M + lift,
                (g - so[1]) / pxft * M + lift,
                hw / pxft * M if hw is not None else None,
                bw / pxft * M if bw is not None else None,
            )
        s += 0.25
    return rows


def ring(top, bottom, width):
    """The four intermediate pairs and the belly's half-width, on the ellipse through the top, the
    bottom and the widest point.

    THE BELLY SHARES THE BOTTOM'S HEIGHT and is not free: `_ring` reads the table as
    [... under_w, under_h, belly_w, bottom] and then builds its half as
    `(belly_w, row[11]), (0.0, row[11])`, so the last pair's height IS the bottom. The ring
    therefore ends in a short flat keel of width `belly_w` rather than at a point. Emitting a
    fifth height here would silently shift every value in the row one place left, which is the
    sort of error that produces a plausible aeroplane with every station wrong."""
    centre = (top + bottom) * 0.5
    depth = (top - bottom) * 0.5
    out = []
    for k in range(1, 5):
        theta = np.pi * k / 6.0
        out.append((width * np.sin(theta), centre + depth * np.cos(theta)))
    return out, width * np.sin(np.pi * 5.0 / 6.0)


def main(research_dir):
    rows = measured_column(research_dir)
    print("THE DRAWING'S OWN COLUMN, in the LEVEL frame (station x tan 6.5 deg added back)\n")
    print("  station     top   bottom   plan_outer   plan_inner   agree?")
    for s in sorted(rows):
        t, b, ho, hi = rows[s]
        agree = "-"
        if ho is not None and hi is not None:
            agree = "yes" if abs(ho - hi) < 0.08 else "%.2f apart" % abs(ho - hi)
        print("  %7.2f %7.3f %8.3f %12s %12s   %s"
              % (s, t, b, "%.3f" % ho if ho else "-", "%.3f" % hi if hi else "-", agree))

    print("\n\nTHE PROPOSED TABLE.\n")
    print("WHERE THE TOP AND THE BOTTOM COME FROM, station by station, because it is not one answer:")
    print("  top     stations 0.30 to 10.25 are the drawing's. From 10.50 aft the drawn outer")
    print("          silhouette is the FIN, not the fuselage, so those rows keep the values the")
    print("          previous lane judged with the cutaway open -- a measurement of the wrong")
    print("          object is worse than an honest judgement of the right one.")
    print("  bottom  stations 0.30 to 4.25 and 9.00 to 10.50 are the drawing's. Between them the")
    print("          GUN PODS are the lowest ink and the belly is hidden behind them, and from")
    print("          11.25 aft the tailplane is in the way. Those rows keep the judged values.")
    print("")
    aw = np.array([a[0] for a in WIDTH_ANCHORS], float)
    ah = np.array([a[1] for a in WIDTH_ANCHORS], float)
    ms_s = np.array(sorted(rows), float)
    ms_t = np.array([rows[s][0] for s in sorted(rows)], float)
    ms_b = np.array([rows[s][1] for s in sorted(rows)], float)

    # The two measured ends the hidden belly is stretched between, taken from the column itself
    # rather than typed, so they cannot drift away from it.
    global BELLY_ENDS
    BELLY_ENDS = (float(np.median(ms_b[np.abs(ms_s - 4.25) <= 0.4])),
                  float(np.median(ms_b[np.abs(ms_s - 9.00) <= 0.4])))
    print("  the hidden belly is stretched between its measured ends: %.3f m at station 4.25 and"
          " %.3f at 9.00\n" % BELLY_ENDS)

    changed_top, changed_bot = [], []
    for s, old_top, old_bot in JUDGED:
        top_measured = s <= 10.25
        # THE BOTTOM IS MEASURABLE ALMOST EVERYWHERE. Only between stations 4.5 and 8.35 do the GUN
        # PODS hang below the belly and hide it. Aft of the wing the lowest ink is the fuselage: the
        # tailplane sits at 2.30 and the drawn bottom there is 1.96 to 2.95, well below it, so it is
        # not the tailplane being measured -- which was worth checking before trusting eight rows.
        bot_measured = s <= 4.25 or s >= 9.00
        # A LOCAL MEDIAN, not a single row. The drawn bottom at station 12.00 reads 0.175 m where
        # both its neighbours read 0.63 and 0.56 -- one row of a dimension line or a tick that the
        # column happened to cross. Interpolating straight through it put a 0.44 m DIP in the keel
        # between two rows that agreed with each other, which is the shape a single bad pixel makes
        # and is indistinguishable from a real feature once it is in the table. The median over
        # +-0.4 m ignores it and changes nothing anywhere the column is already smooth.
        near = np.abs(ms_s - s) <= 0.4
        t = float(np.median(ms_t[near])) if top_measured else old_top
        if bot_measured:
            b = float(np.median(ms_b[near]))
        else:
            # THE HIDDEN BELLY, stations 4.5 to 8.35, INTERPOLATED BETWEEN ITS TWO MEASURED ENDS.
            #
            # This is the row that makes the aeroplane "too deep amidships", which is what the lane
            # that built it said about its own work. The old table ran the belly down to 1.12 m
            # through here -- but 1.12 is where the drawing's lowest ink is, and the lowest ink
            # between these stations is THE GUN POD. The fuselage was being drawn down to the
            # bottom of a part that hangs off it, so the body swallowed its own pods and came out
            # 0.45 m too deep amidships: 2.14 m at station 6.00 where the ends imply 1.69.
            #
            # A measurement of the wrong object, again, and the third time on this one sheet after
            # the scale bar and the plan view's length. The ends at 4.25 and 9.00 ARE the fuselage
            # and they are 0.23 m apart, so the belly between them is very nearly straight.
            b = float(np.interp(s, [4.25, 9.00], [BELLY_ENDS[0], BELLY_ENDS[1]]))
        t, b = round(t, 2), round(b, 2)
        if top_measured and abs(t - old_top) >= 0.05:
            changed_top.append((s, old_top, t))
        if bot_measured and abs(b - old_bot) >= 0.05:
            changed_bot.append((s, old_bot, b))
        w = float(np.interp(s, aw, ah))
        pairs, belly = ring(t, b, w)
        cells = ", ".join("%.2f, %.2f" % (p[0], p[1]) for p in pairs)
        print("\t[%.2f, %.2f, %s, %.2f, %.2f]," % (s, t, cells, belly, b))

    print("\nWHAT MOVED IN THE OUTLINE, and it is less than the width change but it is not nothing:")
    for s, o, n in changed_top:
        print("  top    station %5.2f   %.2f -> %.2f  (%+.2f m)" % (s, o, n, n - o))
    for s, o, n in changed_bot:
        print("  bottom station %5.2f   %.2f -> %.2f  (%+.2f m)" % (s, o, n, n - o))
    print("")
    print("  The forward TOP rows rise 0.14 to 0.20 m. That is the blunt nose: the old table sat")
    print("  below the drawn line from station 0.75 to 2.25 and met it exactly from 2.75 aft, and")
    print("  a nose drawn under its own outline is a dart. The rear BOTTOM rows rise HALF A METRE,")
    print("  which takes the depth at station 9.75 from 1.92 m to 1.40 against a drawn 1.398. That")
    print("  is the rear fuselage finally tapering, and it is the largest single change here.")

    print("\nTHE INTAKE BELLS, measured, as their own part:")
    # NOT A CIRCLE FIT, AND IT SAID IT WAS. This line used to print "circle fit to 17 tracked rows of
    # the front view, 2.56 px rms" and `sources.md` quoted it as measured provenance. There is no
    # circle fit anywhere in `craft/harrier/` -- `measure_front.py` contains no `circle`, no
    # `least_squares` and no `rms` -- so the figure is a READING off the front view and the rms
    # belonged to nothing. The number itself is sound (`lane/harrierlook` checked it independently and
    # the bell reads datum 2.47 against the model's 2.49), which is exactly why it survived: a wrong
    # PROVENANCE on a right number is invisible to every check, because nothing disagrees.
    #
    # This craft's whole discipline is that the scripts re-derive every figure from the scan and read
    # nothing out of the write-up, SO THAT THE TWO CAN DISAGREE AND ONE OF THEM BE WRONG. A figure
    # presented with an rms that no code computes cannot do that. Labelled for what it is until
    # somebody writes the fit.
    print("  outer diameter 1.222 m -- READ off the front view, JUDGED, not circle-fitted: no fit exists")
    print("  centre 0.587 m outboard of the centreline, so the outer edge reaches 1.198 m")
    print("  in plan the bell runs station 2.0 to about 4.4, where the outer half-width is 1.05 to 1.22")
    print("  [WP]'s Pegasus is 1.219 m in diameter -- a 0.2 per cent agreement with the drawn bell,")
    print("  and neither figure went into the other.")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1
         else r"C:\Users\Graham\godotgames-drafts\2026-09-19\cockpit-harrier\research")
