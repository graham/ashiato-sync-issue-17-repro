"""Lays the AV-8B airframe's orthographic silhouette over [SAC] page 2's own side view, at x1.000 -- no fitting.

    python cockpit/craft/harrier/overlay_views.py <folder of harrier_shot's silhouettes> <out folder> [research]

THIS IS THE INSTRUMENT THAT WAS MISSING, and its absence is the whole story of this aeroplane. Ten other craft here
have one (`craft/*/overlay_views.py`, on `tools/three_view.py`). The Harrier was measured harder than any of them --
three scripts, nine published figures recovered inside two per cent, a printed scale bar caught a fifth wrong, a plan
view caught 3.5 per cent short -- and it was the only one whose drawn OUTLINE had never once been laid over the
drawing's. Fifteen green suites shipped an aeroplane the user said looked like an F-4, and every one of them was
checking the model against a LIST of figures rather than against the aeroplane. A dimension check cannot see a shape.

WHAT IT COMPARES, and what it deliberately does not. The view is reduced to a BAND: the drawn top and the drawn
bottom at every station. A band cannot describe a concavity -- the gap between two undercarriage legs is filled in on
both sides alike -- and that is said here rather than discovered later. What a band CAN do is answer the only
question that matters, in metres and at a named station: where does my outline leave the drawing, and by how much.

REGISTRATION IS BY CONSTRUCTION AND NOTHING IS FITTED. `tests/harrier_shot.gd` points an orthographic camera at the
craft's own origin at [SAC]'s own 62.956 px/m, and `HarrierAirframe.point` puts that origin at station LENGTH / 2 and
datum height HEIGHT / 2. So the centre pixel of the render IS station 7.061 at height 1.776, exactly, and the two
pictures are in the same frame before this script starts. Nothing is slid to make the answer nicer. Where the F-35B's
overlay aligns on a datum named in the filename, this one does not have to.

THE REFERENCE OUTLINE IS `measure_stations.side_outline`, RE-USED RATHER THAN RE-DERIVED. It is the routine that
returns nine published figures inside two per cent, and a second extractor written here would mean two answers about
one drawing with nothing to say which was right. It stops short of the raked ground line, so the drawn wheels fall
outside it -- and `harrier_shot.gd` draws the aeroplane parked, on its gear, as [SAC] does, so the two are asking one
question. Stations forward of 0.30 are not reported, because the drawing's nose is a stroke's width wide and a band
there is mostly ink; stations aft of `LAST_CLEAN` are not reported for the reason given at that constant.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import measure_stations as ms  # noqa: E402
from measure_sac import load, widest_row, SPAN_FT, PLAN_BAND  # noqa: E402

M = 0.3048
RAKE = np.tan(np.radians(6.5))
MAGENTA = np.array([209, 41, 140])
# `HarrierAirframe`: the craft's origin sits LENGTH / 2 aft of the nose and HEIGHT / 2 over the datum, and
# `harrier_shot.gd` points every silhouette camera at it. These are the only two registration numbers there are.
LENGTH_M = 14.122
ORIGIN_STATION = LENGTH_M / 2.0
ORIGIN_HEIGHT = 3.551 / 2.0
# A DISAGREEMENT WORTH A READER'S EYE. One pixel of [SAC] is 15.9 mm, so anything under about 5 cm is the scan.
LOUD = 0.25
# WHERE THE DRAWING STOPS BEING THE AEROPLANE. [SAC]'s 11.65 FT height dimension puts a horizontal extension line
# out from the fin tip, and aft of about station 13.4 that line is the topmost ink in the column -- so the band reads
# 5.19 m at station 14.05 where the tailcone is 3.0, and reports a two-metre disagreement that belongs to a
# dimension. A BAND CANNOT TELL A DIMENSION FROM AN AEROPLANE; this is the same trap that made the printed scale bar
# unusable and the plan view's stations 3.5 per cent short, met a third time on the same sheet. The honest answer is
# to stop where the reading is clean and say so, rather than to report a number about the wrong object.
LAST_CLEAN = 13.30


def model_mask(path):
    """The magenta silhouette as a boolean mask, and the picture it came from."""
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return (np.abs(rgb - MAGENTA).sum(axis=2) < 150), rgb


def reference_side(ink, pxm):
    """[SAC]'s side view as {station: (top_m, bottom_m)} over the DATUM, the aeroplane drawn level."""
    out = {}
    station = 0.30
    while station <= LAST_CLEAN:
        x = int(round(ms.SIDE_NOSE + station * pxm))
        seen = ms.side_outline(ink, x)
        if seen:
            ground = ms.ground_at(x)
            out[round(station, 2)] = ((ground - seen[0]) / pxm + station * RAKE,
                                      (ground - seen[1]) / pxm + station * RAKE)
        station += 0.25
    return out


def model_side(mask, pxm):
    """The rendered silhouette as {station: (top_m, bottom_m)}, registered by construction."""
    height, width = mask.shape
    cx, cy = (width - 1) / 2.0, (height - 1) / 2.0
    out = {}
    for column in range(width):
        rows = np.nonzero(mask[:, column])[0]
        if not len(rows):
            continue
        # Screen right is world +Z, which is AFT: `harrier_shot.gd` stands the side camera on the PORT side so the
        # nose points left as [SAC] draws it. Rows increase downward, so a larger row is a lower height.
        out[ORIGIN_STATION + (column - cx) / pxm] = (ORIGIN_HEIGHT - (int(rows.min()) - cy) / pxm,
                                                     ORIGIN_HEIGHT - (int(rows.max()) - cy) / pxm)
    return out


def reference_plan(ink, pxm):
    """[SAC]'s PLAN view as {station: (starboard_m, port_m)}, on the plan's OWN longitudinal scale.

    THE DRAWING'S PLAN RUNS NOSE-DOWN THE PAGE and the render runs nose-up, so one of them has to be
    turned over. It is done HERE, once and deliberately, rather than by negating a number downstream
    until the picture looks right: `measure_stations` takes the plan's nose as the LARGER row and
    steps aft by subtracting, and this follows it rather than forming a second opinion about which
    end of a drawing is the nose.

    AND THIS VIEW IS ANISOTROPIC, WHICH IS THE WHOLE REASON THIS FUNCTION IS LONGER THAN THE SIDE
    ONE. `measure_stations` prints it every run and nobody had acted on it: the plan's own nose-to-
    tail length is 13.629 m against the published 14.122, THREE AND A HALF PER CENT SHORT, while its
    lateral scale -- set from the printed 30.33 ft span -- is right. So the two axes of this one view
    do not share a scale, and stepping stations along it with the span's number walks off the end of
    the aeroplane: by the tailplane it is nearly half a metre out, all of it in one direction, which
    is exactly the shape of error that gets read as "the tailplane is too far aft".

    So the station axis is stepped on the plan's OWN length and the lateral axis stays on the span's,
    which puts the drawing's nose at station 0 and its tailcone at 14.122 where the model's are. Two
    scales on two axes of one view is not a fudge -- it is what an anisotropic view IS, and
    `modelling_here.md` section 3 says to check a view's two axes against each other for this reason.
    The alternative, one scale for both, is a silent claim that the view is isotropic when its own
    printed length says it is not.
    """
    rows = [row for row in range(300, 1240) if ms.plan_half(ink, row) is not None]
    nose_row, tail_row = max(rows), min(rows)
    along = (nose_row - tail_row) / LENGTH_M          # the plan's OWN pixels per metre of station
    print("  the plan view's own length is %.3f m against the published %.3f (%+.2f per cent), so its"
          % ((nose_row - tail_row) / pxm, LENGTH_M, 100 * ((nose_row - tail_row) / pxm / LENGTH_M - 1)))
    print("  stations are stepped at %.3f px/m and its half-widths at the span's %.3f. See the doc block."
          % (along, pxm))
    out = {}
    station = 0.30
    while station <= 13.80:
        row = int(round(nose_row - station * along))
        half = ms.plan_half(ink, row)
        if half:
            out[round(station, 2)] = (half / pxm, -half / pxm)
        station += 0.25
    return out


def refuse_front(ink):
    """THE FRONT VIEW IS NOT SCORED, and this says why rather than leaving a gap for somebody to fill.

    A band needs a datum. The side view has one -- [SAC] draws the aeroplane level over a raked ground
    line and `measure_stations.ground_at` fits it from 445 px of drawn line at 0.277 px rms. The plan
    view needs none, because its second axis is a half-width about a centreline that
    `measure_front.centreline` finds and that the published span and the printed 17.00 FT tread both
    check. THE FRONT VIEW HAS NEITHER: its second axis is a HEIGHT, and this drawing gives it nothing
    to measure a height from.

    Looked for and not found: there is no drawn ground line under the front view. Not one row in or
    below `measure_sac.FRONT_BAND` carries a horizontal run of even 300 px, and the inkiest rows near
    it -- 1353, 1753, 1898, 1938 -- are a mixture of the wing seen edge-on and dimension lines, with
    nothing that a rule can tell apart from the others. `measure_front.py` works entirely in ROWS and
    never converts one to a height, which is not an oversight: it is the same refusal, made quietly.

    AND THE TRAP HERE IS ALREADY PAID FOR. `lane/harrierlook` calibrated this view's heights by taking
    the topmost ink near the centreline as the fin tip and got the 30.33 FT DIMENSION LINE above it
    instead; every height in the view came out 1.05 m low, and only drawing the datum lines onto the
    picture and looking caught it. The same sheet has produced four of these -- a scale bar a fifth
    wrong, the plan view's stations, a belly line that was really a gun pod, and that one.

    So the honest state is a scored side view, a scored plan view, and a front view whose registration
    nobody has earned yet. What would earn it: a landmark in this view whose height is PUBLISHED and
    which can be identified without assuming the answer. The 11.65 FT overall height is measured to
    the fin tip from the GROUND, so finding the ground line would settle it -- and the ground line is
    the thing that is not drawn. `modelling_here.md`: a feature you cannot identify cannot be measured,
    however good the scale is.
    """
    print("")
    print("THE FRONT VIEW -- NOT SCORED, and not for want of a render")
    print("  `harrier_shot.gd` draws and asserts this silhouette, and it is sitting there. What is")
    print("  missing is a DATUM: the front view's second axis is a height, and this drawing has no")
    print("  ground line to measure one from. The inkiest rows near the view are the wing seen")
    print("  edge-on and dimension lines, and this sheet has already turned a dimension line into a")
    print("  fin tip once, at a cost of 1.05 m on every height in the view. See `refuse_front`.")


def model_plan(mask, pxm):
    """The rendered plan silhouette as {station: (starboard_m, port_m)}, registered by construction.

    `harrier_shot.gd` points the plan camera at the craft's own origin with the NOSE UP the frame, so
    the centre pixel is station 7.061 on the centreline and rows increase aft. Nothing is aligned.
    """
    height, width = mask.shape
    cx, cy = (width - 1) / 2.0, (height - 1) / 2.0
    out = {}
    for row in range(height):
        cols = np.nonzero(mask[row])[0]
        if not len(cols):
            continue
        out[ORIGIN_STATION + (row - cy) / pxm] = ((int(cols.max()) - cx) / pxm,
                                                 (int(cols.min()) - cx) / pxm)
    return out


def score(name, ref, mine, units, note=()):
    """One band against another, station by station, in metres. The same arithmetic for every view."""
    print("")
    print("THE %s, %s" % (name.upper(), units))
    print("  station |   SAC a     mine      d   |   SAC b     mine      d")
    worst = (0.0, "nothing", 0.0, 0.0)
    overlap = union = 0.0
    counted = 0
    for at in sorted(ref):
        got = sample(mine, at)
        if got is None:
            continue
        counted += 1
        (a, b), (mine_a, mine_b) = ref[at], got
        d_a, d_b = mine_a - a, mine_b - b
        for side, d in (("a", d_a), ("b", d_b)):
            if abs(d) > worst[0]:
                worst = (abs(d), side, at, d)
        overlap += max(0.0, min(a, mine_a) - max(b, mine_b))
        union += max(a, mine_a) - min(b, mine_b)
        print("  %7.2f | %7.3f %7.3f %+6.3f | %7.3f %7.3f %+6.3f%s"
              % (at, a, mine_a, d_a, b, mine_b, d_b,
                 "   <<<" if max(abs(d_a), abs(d_b)) > LOUD else ""))
    print("")
    print("  AGREEMENT %.1f per cent of the two bands' union, over %d stations."
          % (100.0 * overlap / max(union, 1e-9), counted))
    print("  WORST %.3f m on %s at %.2f (%+.3f)" % worst)
    for line in note:
        print(line)
    return worst


def sample(band, station):
    """The model's band at a station, linearly between the two columns either side of it."""
    keys = sorted(band)
    if not keys or station < keys[0] or station > keys[-1]:
        return None
    i = min(max(int(np.searchsorted(keys, station)), 1), len(keys) - 1)
    a, b = keys[i - 1], keys[i]
    t = 0.0 if b == a else (station - a) / (b - a)
    return (band[a][0] + t * (band[b][0] - band[a][0]),
            band[a][1] + t * (band[b][1] - band[a][1]))


def lay(rgb, ref, pxm, path, down=False):
    """The render in magenta with [SAC]'s own two edges drawn over it in black, at x1.000.

    `down` swaps the axes for the PLAN view, where station runs down the frame and the pair of values
    is a lateral half-width either side of the centreline rather than a height over the datum.
    """
    picture = rgb.copy()
    height, width = picture.shape[0], picture.shape[1]
    cx, cy = (width - 1) / 2.0, (height - 1) / 2.0
    for station, edges in ref.items():
        if down:
            row = int(round(cy + (station - ORIGIN_STATION) * pxm))
            if not 0 <= row < height:
                continue
            for value in edges:
                column = int(round(cx + value * pxm))
                for step in (-1, 0, 1):
                    if 0 <= column + step < width:
                        picture[row, column + step] = (0, 0, 0)
            continue
        column = int(round(cx + (station - ORIGIN_STATION) * pxm))
        if not 0 <= column < width:
            continue
        for value in edges:
            row = int(round(cy + (ORIGIN_HEIGHT - value) * pxm))
            for step in (-1, 0, 1):
                if 0 <= row + step < height:
                    picture[row + step, column] = (0, 0, 0)
    Image.fromarray(picture.astype(np.uint8)).save(path)
    print("  overlay -> %s" % path)
    print("  (magenta: the drawn model. black: [SAC]'s own top and bottom, at x1.000 and unshifted)")


def main(shots, out_dir, research):
    _, ink, _ = load(research)
    pxm = widest_row(ink, *PLAN_BAND)[0] / SPAN_FT / M
    os.makedirs(out_dir, exist_ok=True)
    print("[SAC] %.4f px/m, imported from measure_sac (one number, one place)" % pxm)
    print("the render is at that same scale and its centre pixel IS station %.3f, height %.3f -- by"
          " construction, not by fitting\n" % (ORIGIN_STATION, ORIGIN_HEIGHT))

    ref = reference_side(ink, pxm)
    mask, rgb = model_mask(os.path.join(shots, "cockpit-harrier-silhouette-side.png"))
    mine = model_side(mask, pxm)

    print("THE SIDE VIEW, station by station, in metres over the datum")
    print("  station |  SAC top    mine      d   |  SAC bot    mine      d")
    worst = (0.0, "nothing", 0.0, 0.0)
    overlap = union = 0.0
    counted = 0
    for station in sorted(ref):
        got = sample(mine, station)
        if got is None:
            continue
        counted += 1
        (top, bottom), (mine_top, mine_bottom) = ref[station], got
        d_top, d_bottom = mine_top - top, mine_bottom - bottom
        for name, d in (("top", d_top), ("bottom", d_bottom)):
            if abs(d) > worst[0]:
                worst = (abs(d), name, station, d)
        overlap += max(0.0, min(top, mine_top) - max(bottom, mine_bottom))
        union += max(top, mine_top) - min(bottom, mine_bottom)
        print("  %7.2f | %7.3f %7.3f %+6.3f | %7.3f %7.3f %+6.3f%s"
              % (station, top, mine_top, d_top, bottom, mine_bottom, d_bottom,
                 "   <<<" if max(abs(d_top), abs(d_bottom)) > LOUD else ""))

    print("")
    print("  AGREEMENT %.1f per cent of the two bands' union, over %d stations."
          % (100.0 * overlap / max(union, 1e-9), counted))
    print("  WORST %.3f m on the %s at station %.2f (%+.3f)" % worst)
    print("  Every row marked <<< is more than %.2f m out somewhere. One pixel of [SAC] is 15.9 mm," % LOUD)
    print("  so a tenth of a metre is real and a centimetre is the scan.")
    print("  Stations past %.2f are NOT compared: see LAST_CLEAN." % LAST_CLEAN)
    lay(rgb, ref, pxm, os.path.join(out_dir, "overlay-side.png"))

    # ---- THE PLAN VIEW, which until 2026-09-20 was rendered and asserted and never scored --------
    plan_mask, plan_rgb = model_mask(os.path.join(shots, "cockpit-harrier-silhouette-plan.png"))
    plan_ref = reference_plan(ink, pxm)
    score("plan view", plan_ref, model_plan(plan_mask, pxm),
          "half-widths in metres either side of the centreline",
          note=[
              "  SAY THIS BEFORE READING THE NUMBER: [SAC]'s plan view DRAWS PYLONS and this model",
              "  carries none, so the drawn band is wider than the airframe wherever a pylon is and",
              "  the score reads low for a reason that is not the aeroplane. Predicting where an",
              "  instrument will lie before running it is the only way to stop somebody tuning to it.",
          ])
    lay(plan_rgb, plan_ref, pxm, os.path.join(out_dir, "overlay-plan.png"), down=True)
    refuse_front(ink)
    return worst


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2],
         sys.argv[3] if len(sys.argv) > 3
         else os.path.expanduser("~/godotgames-drafts/2026-09-19/cockpit-harrier/research"))
