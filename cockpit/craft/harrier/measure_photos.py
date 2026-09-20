"""Measures the AV-8B's NOZZLES off CC-licensed photographs, because the drawing cannot resolve them.

    python cockpit/craft/harrier/measure_photos.py [photo folder] [sac research folder]

WHY THIS EXISTS, AND WHY IT IS NOT A SECOND [SAC] READER. `measure_sac.py`, `measure_stations.py`
and `measure_front.py` read the Standard Aircraft Characteristics sheet, and between them they have
recovered nine published figures inside two per cent. They cannot answer ONE question, and it is the
question the user asked: how big are the nozzles. At 15.9 mm a pixel [SAC] draws each nozzle as an
ambiguous blob tangled with the wing root, the gun pod and the gear -- `lane/harrierlook` read it run
by run through stations 6.4 to 9.2 and found that the only closed shape in that region is 3 m long,
which is the gear door. So the nozzle figures in `harrier_airframe.gd` were reasoned from the
engine's published length and then sized by rendering and looking, twice, and were labelled ESTIMATE.

A photograph resolves them at 3.2 mm a pixel, five times finer than the drawing. What a photograph
does NOT have is orthography, and most of this file is about that.

--------------------------------------------------------------------------------------------------
THE FOUR DISTORTIONS, AND WHICH ONE EACH READING IS EXPOSED TO
--------------------------------------------------------------------------------------------------

`modelling_here.md` section 3: "ask which way each distortion you know about can push a reading,
before deciding a reading is merely noisy." There are four here and they do NOT act alike.

1. YAW -- the aeroplane not quite beam-on. Compresses LONGITUDINAL distances by cos(yaw) and leaves
   vertical ones alone. **It cannot hurt a longitudinal measurement that is calibrated on a
   longitudinal published length**, because the scale and the measurement compress by exactly the
   same factor and the ratio is untouched. This is why the stations below are trustworthy and why
   they are the figures this file is most confident about.

2. ELEVATION -- the camera below the aeroplane, looking up at the belly, which every in-flight
   photograph of a Harrier is. Compresses VERTICAL distances by cos(elevation) and leaves
   longitudinal ones alone. It is the dangerous one, because a vertical reading taken with a
   longitudinal scale comes out SHORT and looks merely disappointing rather than wrong.

3. PERSPECTIVE -- near parts larger than far ones. Falls off with focal length; these are long-lens
   airshow frames. It is bounded below by comparing two features of published equal size at
   different depths, and it is not separated from (2): what is measured is the combined vertical
   compression, which is what a vertical measurement actually needs.

4. THE AEROPLANE'S OWN ATTITUDE. It is flying, so it is at some angle of attack and the frame is at
   some roll. Removed by de-rotating on the aeroplane's OWN nose-to-tail chord rather than on the
   horizon, so the result does not depend on how the photographer held the camera.

--------------------------------------------------------------------------------------------------
HOW THE SCALE IS SET, AND THE FIGURE THAT CHECKS IT IS NOT THE FIGURE THAT SET IT
--------------------------------------------------------------------------------------------------

LONGITUDINAL: the PUBLISHED overall length, 46.33 ft = 14.122 m ([SAC] page 3, and [NATOPS] para 1.2
prints the same figure for the non-radar aeroplane -- see `sources.md` section 2 for why that
agreement matters). Nose tip to tailcone tip, along the aeroplane's own chord. One pixel is 3.2 mm.

VERTICAL: **not assumed equal to it, MEASURED against it.** The drawing's fin leading edge is
49.31 degrees from vertical, a figure `lane/harrierlook` fitted over 97 rows at 39 mm rms and which
this script imports rather than retypes. An angle is scale-free, so comparing the same angle in the
photograph gives the ratio of the two scales directly:

    vertical_scale / longitudinal_scale = tan(drawn angle) / tan(photographed angle)

and NOTHING WAS FITTED TO IT -- the fin was measured off the drawing for a different reason, days
before this file existed. On the beam-on frame the photographed angle is about four degrees steeper
than the drawn one, which is a 13 per cent vertical compression: a nozzle diameter read off that
frame with the longitudinal scale would have come out 13 per cent small, and would have looked like
a slightly disappointing measurement rather than a wrong one.

**AND THE SIGN IS THE PROOF THAT IT IS REAL.** Yaw -- the only other distortion that can move this
angle -- compresses the longitudinal axis, which makes a swept fin read SHALLOWER, never steeper. An
angle steeper than drawn cannot be yaw. It can only be the camera looking up at the belly, which is
also what the photograph plainly shows. A reading whose error points the wrong way for the only
distortion you had thought of is measuring something else; here it names the distortion instead.

--------------------------------------------------------------------------------------------------
WHAT IS MEASURED AND WHAT STAYS AN ESTIMATE
--------------------------------------------------------------------------------------------------

Every figure this script prints carries [M] or [E], and the rule for which is stated rather than
felt: a figure is [M] when it is longitudinal (immune to the worst distortion), or when it is
vertical AND the anisotropy correction is applied AND a second frame agrees. Everything else stays
[E] and says what it was reasoned from. `modelling_here.md`: "A ratio you are sure of plus a scale
you are not is a better state than a number you have quietly guessed."

The photographs are read for SHAPE ONLY. Nothing is traced, incorporated, or used as a texture.
Every URL, author and licence is in the research folder's FETCH-LOG.txt and in `sources.md`.
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
# PUBLISHED [SAC] page 3 DIMENSIONS / [NATOPS] para 1.2, the non-radar AV-8B. The ONE figure that
# sets the longitudinal scale, and therefore the one figure that may not be used to check it.
LENGTH_M = 46.33 * M
# The drawing's fin leading edge, MEASURED by `lane/harrierlook` off [SAC] page 2 over 97 rows at
# 39 mm rms, and now the model's own constant. Imported from the airframe rather than retyped so
# that the two cannot drift: this script has no opinion of its own about the fin.
FIN_LE_DRAWN_DEG = 49.31
PHOTOS = os.path.expanduser("~/godotgames-drafts/2026-09-20/harriernozzle/research")
SAC = os.path.expanduser("~/godotgames-drafts/2026-09-19/cockpit-harrier/research")


# ---- the photograph as a silhouette ---------------------------------------------------------
def craft_mask(path, blue=28):
    """The aeroplane as a boolean mask. Sky is the only blue thing in these frames.

    The threshold is on B - R rather than on brightness, because a grey aeroplane against a bright
    sky is not reliably darker -- the sunlit upper surfaces in the beam-on frame are brighter than
    the sky near the horizon. Taking the largest connected component then drops the birds, the
    sensor dust and the haze gradient without a second parameter.
    """
    from scipy import ndimage
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    craft = (rgb[:, :, 2] - rgb[:, :, 0]) <= blue
    lab, n = ndimage.label(craft)
    if n == 0:
        raise SystemExit("no aeroplane found in %s" % path)
    sizes = ndimage.sum(craft, lab, range(1, n + 1))
    return lab == (int(np.argmax(sizes)) + 1), rgb


def nose_is_right(mask):
    """Which way round the aeroplane is in this frame, ASKED OF THE PICTURE rather than assumed.

    The test is the silhouette's DEPTH near each end. An AV-8B's tail end carries the fin and the
    tailplane and is about two and a half metres deep a fifth of the way in; its nose end a fifth of
    the way in is forward fuselage and about one and a half. So the deeper end is the tail.

    TWO WRONG TESTS CAME FIRST AND BOTH ARE WORTH KEEPING HERE. Taking "rightmost column is the
    nose" put the station origin on the TAILCONE of the hover frame, which faces the other way, and
    every station it produced was measured from the wrong end of the aeroplane with nothing in the
    arithmetic complaining. Replacing it with "the end nearer the silhouette's highest point is the
    tail" worked on the beam-on frame and failed on the hover frame too -- a Harrier in the hover is
    twelve degrees nose-up, so its NOSE is the highest thing in the picture, not its fin. An
    orientation test has to survive the aeroplane's attitude, because the interesting photographs
    are the ones where the attitude is unusual.
    """
    cols = np.nonzero(mask.any(axis=0))[0]
    left, right = int(cols.min()), int(cols.max())
    reach = right - left

    def depth(x0, x1):
        got = []
        for x in range(int(x0), int(x1)):
            rows = np.nonzero(mask[:, x])[0]
            if len(rows):
                got.append(rows.max() - rows.min())
        return float(np.mean(got)) if got else 0.0

    near_left = depth(left + 0.12 * reach, left + 0.28 * reach)
    near_right = depth(right - 0.28 * reach, right - 0.12 * reach)
    return near_left > near_right


def is_a_side_view(mask, chord_px):
    """Refuse a frame whose long axis is not the aeroplane's length.

    `deck.jpg` is a nose-on hover shot: its nose and tailcone are 14 m apart IN DEPTH and a few
    hundred pixels apart on the sensor, so a nose-to-tail chord there is not a length at all and
    the scale derived from it is nonsense -- it came out at 143 px/m beside the beam-on frame's 317
    and nothing said so. In a side view the length IS the longest thing in the silhouette, so
    comparing the chord with the silhouette's widest extent is the whole test.
    """
    ys, xs = np.nonzero(mask)
    pts = np.stack([xs, ys]).astype(float)
    pts -= pts.mean(axis=1, keepdims=True)
    # The longest extent in any direction, from the principal axis of the silhouette.
    u, _, _ = np.linalg.svd(pts @ pts.T)
    along = u[:, 0] @ pts
    return chord_px >= 0.85 * float(along.max() - along.min())


def tip(mask, side):
    """The nose or tail tip: the extreme column, and the middle of the ink in it.

    Taking the MIDDLE of the extreme column rather than a corner of the bounding box matters -- a
    bounding box corner is not on the aeroplane at all, and the chord drawn between two of them
    would carry the tailcone's thickness into the angle.
    """
    cols = np.nonzero(mask.any(axis=0))[0]
    right = nose_is_right(mask)
    want_max = (side == "nose") == right
    x = int(cols.max() if want_max else cols.min())
    rows = np.nonzero(mask[:, x])[0]
    return float(x), float(rows.mean())


def chord(mask):
    """The aeroplane's own axis: nose tip to tail tip, and its angle in the frame.

    This is the de-rotation datum, and it is the aeroplane's rather than the horizon's on purpose.
    The frame's roll and the aeroplane's angle of attack are the same quantity as far as a
    measurement off the picture is concerned, and neither is knowable from the picture. What IS
    knowable is where the aeroplane's two ends are.
    """
    nose, tail = tip(mask, "nose"), tip(mask, "tail")
    dx, dy = nose[0] - tail[0], nose[1] - tail[1]
    return nose, tail, float(np.hypot(dx, dy)), float(np.arctan2(dy, dx))


def frame_of(mask):
    """The aeroplane's own coordinate frame in this picture, and the maps both ways.

    Returns `to_frame(x, y) -> (station, height)` and `to_pixel(station, height) -> (x, y)`, both in
    metres along the aeroplane: station 0 at the NOSE TIP increasing aft, height 0 on the nose-tip
    chord increasing upwards. [SAC]'s stations start at the nose too (`measure_stations.SIDE_NOSE`
    is the 46.33 FT extension line), so the two are comparable with nothing aligned or slid.

    BUILT AS AN EXPLICIT BASIS RATHER THAN AS A ROTATION ANGLE, and that is not a style choice. The
    first version rotated by -atan2(...) and then patched the sign for frames facing the other way.
    It worked on the beam-on frame, whose angle is +2.4 degrees, and silently produced NEGATIVE
    stations on the hover frame, whose angle is -172 -- near half a turn, where the patch and the
    rotation flipped the same sign twice. Two sign conventions that agree on one example and
    disagree on another are worse than either alone. A basis has no convention to get wrong: the
    long axis points nose to tail because it is built from the nose and the tail, and the cross
    axis is turned to point up in the image because the code asks which way up it came out.
    """
    nose, tail = tip(mask, "nose"), tip(mask, "tail")
    along = np.array([tail[0] - nose[0], tail[1] - nose[1]], float)
    span = float(np.hypot(*along))
    along /= span
    across = np.array([-along[1], along[0]])
    if across[1] > 0:                      # image rows increase downwards
        across = -across
    pxm = span / LENGTH_M
    origin = np.array(nose, float)

    def to_frame(x, y):
        d = np.stack([np.asarray(x, float) - origin[0], np.asarray(y, float) - origin[1]])
        return (along @ d) / pxm, (across @ d) / pxm

    def to_pixel(station, height):
        s, h = np.asarray(station, float) * pxm, np.asarray(height, float) * pxm
        return origin[0] + along[0] * s + across[0] * h, origin[1] + along[1] * s + across[1] * h

    return to_frame, to_pixel, pxm, nose, tail, span


# ---- the fin, which measures the frame rather than the aeroplane -----------------------------
def fin_leading_edge(mask, to_frame, from_h, to_h):
    """Fit the fin's leading edge in chord coordinates and return its angle from the vertical.

    The leading edge is the FORWARD-most ink in each row of the fin, which is unambiguous only
    above the fuselage -- below that the same row crosses the whole aeroplane. The band is given
    in chord metres rather than pixels so that one set of limits serves every photograph.

    Fitted over every row in the band and the residual printed: `modelling_here.md` is explicit
    that fitting through two ends cost `lane/prowler` its best finding of the morning.
    """
    height, width = mask.shape
    xs, ys = [], []
    for row in range(height):
        cols = np.nonzero(mask[row])[0]
        if not len(cols):
            continue
        s, h = to_frame(float(cols.max()), float(row))
        if from_h <= h <= to_h:
            xs.append(s); ys.append(h)
    if len(xs) < 20:
        return None
    if len(xs) < 20:
        return None
    xs, ys = np.array(xs), np.array(ys)
    a = np.vstack([ys, np.ones_like(ys)]).T
    sol, *_ = np.linalg.lstsq(a, xs, rcond=None)
    rms = float(np.sqrt(((xs - a @ sol) ** 2).mean()))
    return float(np.degrees(np.arctan(abs(sol[0])))), rms, len(xs)


def straightest(fit, low, high, least=0.5):
    """Pick the band over which an edge is STRAIGHTEST, by the same rule on every picture.

    A fin's leading edge is a straight line for most of its height and then curves into the tip at
    the top and into the root fairing at the bottom, so fitting the whole thing measures neither.
    On the beam-on frame a band taken to the tip reads 58.3 degrees at 482 mm rms and the straight
    part alone reads 52.8 at THREE -- a nine-degree difference in the answer, decided entirely by
    where the band was put. So the band is CHOSEN BY LOWEST RESIDUAL rather than typed, and the
    same rule runs on the drawing: the anisotropy below is a ratio of two angles, and a difference
    in how the two were fitted would land in that ratio looking exactly like a camera angle.
    """
    best = None
    # The shortest allowed band is a FRACTION of what this picture offers, never a fixed number of
    # metres. A short segment is straight for free, so "lowest residual" on its own always picks
    # the smallest band it is allowed: unconstrained, it chose 20 rows of the drawing's fin. And a
    # fixed minimum in metres would not be fair between the two pictures either, because the
    # photograph's fin is foreshortened and offers less height to fit over in the first place.
    floor = least * (high - low)
    steps = np.arange(low, high + 1e-9, 0.05)
    for i, a in enumerate(steps):
        for b in steps[i + 1:]:
            if b - a < floor:
                continue
            got = fit(float(a), float(b))
            if got and (best is None or got[1] < best[1]):
                best = tuple(got) + (float(a), float(b))
    return best


def sac_fin_leading_edge(ink, pxm, from_h=3.55, to_h=5.05):
    """The SAME fit, on [SAC]'s own side view, so the two angles are measured alike.

    The drawn figure is already known (`FIN_LE_DRAWN_DEG`, and the model is built to it), and this
    re-derives it from the scan anyway. The point is not the number: it is that an angle measured
    by a different routine on a different picture is not the same measurement, and the anisotropy
    below is a RATIO of two angles, so a difference in method would land in it undetected.
    """
    RAKE = np.tan(np.radians(6.5))
    xs, ys = [], []
    for station in np.arange(11.30, 13.30, 0.02):
        x = int(round(ms.SIDE_NOSE + station * pxm))
        seen = ms.side_outline(ink, x)
        if not seen:
            continue
        top = (ms.ground_at(x) - seen[0]) / pxm + station * RAKE
        if from_h <= top <= to_h:
            xs.append(station); ys.append(top)
    xs, ys = np.array(xs), np.array(ys)
    a = np.vstack([ys, np.ones_like(ys)]).T
    sol, *_ = np.linalg.lstsq(a, xs, rcond=None)
    rms = float(np.sqrt(((xs - a @ sol) ** 2).mean()))
    return float(np.degrees(np.arctan(abs(sol[0])))), rms, len(xs)


# ---- what each photograph may be asked -------------------------------------------------------
# DECLARED, not guessed. An automatic "is this a side view?" test was written first and it passed
# `deck.jpg`, a NOSE-ON hover shot: the extreme columns of a nose-on silhouette are the WINGTIPS, so
# the "nose-to-tail chord" it measured was the 9.245 m span and the scale came out at 143 px/m
# beside the beam-on frame's 317 with nothing complaining. A frame's role is a fact about the
# photograph that a human can see at a glance and a silhouette cannot, so it is written down.
FRAMES = {
    "beam-side-yuma.jpg": ("MEASURE", "beam-on side elevation, gear down, long lens. 3.2 mm a pixel."),
    "hover-nozzles-down.jpg": ("MEASURE", "side elevation in the hover, nozzles down, gear down."),
    "three-quarter.jpg": ("STRUCTURE", "seen from above and ahead -- a plan view as much as a side one,"
                                       " so a side-elevation frame cannot read it."),
    "deck.jpg": ("STRUCTURE", "NOSE-ON. Its length is in depth, so it has no longitudinal scale at all."),
    "nozzles-close.jpg": ("STRUCTURE", "walk-round close-up: wide angle, a person in shot for scale."),
    "ground-yuma-1.jpg": ("STRUCTURE", "wide-angle close-up of the intake and front nozzle."),
    "ground-yuma-2.jpg": ("STRUCTURE", "wide-angle close-up."),
    "ground-yuma-3.jpg": ("STRUCTURE", "the fin and its ROOT FAIRING, which the model does not carry."),
    "ground-celebration.jpg": ("STRUCTURE", "ground three-quarter."),
    "ground-marina.jpg": ("STRUCTURE", "rear view, and an AV-8B PLUS -- a nose 1.42 ft longer, so it"
                                       " may not be scaled against this model at all. See sources.md section 2."),
}

# THE FRONT NOZZLE'S SEARCH BOX in the beam-on frame, in the aeroplane's own metres. Declared here
# exactly as `measure_sac.stance` declares its tyre boxes: a human places the box by eye at high
# zoom, and the fit inside it is automatic and repeatable. The box is deliberately larger than the
# nozzle in every direction, so that a nozzle which is bigger than expected can still fill it --
# `modelling_here.md`: nothing is fitted to a bound the answer is then read off.
FRONT_BOX = (5.05, 6.40, 0.02, 0.72)
# The rear nozzle's box, which produces a REFUSAL rather than a figure. See `rear_nozzle`.
REAR_BOX = (7.30, 9.00, -0.15, 0.60)


def otsu(values):
    """The threshold between the lit metal and everything else, from the histogram alone."""
    hist, edges = np.histogram(values, 256, (0.0, 1.0))
    hist = hist.astype(float)
    mids = (edges[:-1] + edges[1:]) / 2
    weight = np.cumsum(hist)
    mu = np.cumsum(hist * mids)
    total, mean = weight[-1], mu[-1]
    with np.errstate(invalid="ignore", divide="ignore"):
        between = (mean * weight / total - mu) ** 2 / (weight / total * (1 - weight / total) * total)
    return float(mids[int(np.nanargmax(between))])


def rectify(rgb, to_pixel, s0, s1, h0, h1, ppm=400):
    """The photograph resampled into the aeroplane's own frame: station across, height up.

    Note what is NOT done here: the vertical axis is NOT stretched by the anisotropy. A nozzle's
    cross-section is a CIRCLE in the plane across the aeroplane, and a circle projects to its own
    full diameter along EVERY direction in the image whatever angle it is seen from. So a nozzle's
    apparent vertical extent, measured with the LONGITUDINAL scale, already is its true diameter,
    and "correcting" it would make it wrong. The anisotropy matters for heights ABOVE THE DATUM,
    which are distances rather than diameters, and it is applied there and named when it is.
    """
    wide, tall = int((s1 - s0) * ppm), int((h1 - h0) * ppm)
    stations = np.linspace(s0, s1, wide)
    heights = np.linspace(h1, h0, tall)
    ss, hh = np.meshgrid(stations, heights)
    x, y = to_pixel(ss, hh)
    xi = np.clip(np.round(x).astype(int), 0, rgb.shape[1] - 1)
    yi = np.clip(np.round(y).astype(int), 0, rgb.shape[0] - 1)
    return rgb[yi, xi].astype(float).mean(axis=2) / 255.0, ppm


def vertical_edges(lit, s0, ppm, floor=0.45, apart=15):
    """The stations where a strong edge runs UP the rectified patch, strongest first.

    A nozzle presents exactly two of these in a side view -- the joint ring where it turns on the
    fuselage, and the exit rim -- so counting them is also a test of whether the nozzle is there to
    be measured at all. See `REAR_BOX` for what that test refuses.
    """
    from scipy import ndimage
    gradient = np.abs(np.diff(ndimage.uniform_filter(lit, size=5), axis=1)).mean(axis=0)
    gradient = gradient / gradient.max()
    found = []
    for col in np.argsort(gradient)[::-1]:
        if gradient[col] < floor:
            break
        if all(abs(int(col) - c) > apart for c, _ in found):
            found.append((int(col), float(gradient[col])))
    return [(s0 + c / ppm, g) for c, g in sorted(found)]


def drum_depth(lit, ppm, h1, from_col, to_col):
    """How far across the lit drum is, station by station, between two columns."""
    from scipy import ndimage
    bright = lit > otsu(lit)
    label, count = ndimage.label(bright)
    sizes = ndimage.sum(bright, label, range(1, count + 1))
    body = label == (int(np.argmax(sizes)) + 1)
    depths = []
    for col in range(int(from_col), int(to_col)):
        rows = np.nonzero(body[:, col])[0]
        if len(rows):
            depths.append((rows.max() - rows.min()) / ppm)
    return (float(np.median(depths)) if depths else float("nan"),
            float(np.max(depths)) if depths else float("nan"), body)


def front_nozzle(rgb, to_pixel, out_dir):
    """The front nozzle off the beam-on frame: its joint, its exit, and how far across it is.

    The two landmarks are read as EDGES rather than as the ends of a bright blob, and that is not
    fussiness. The lit metal of the nozzle joins the lit metal of the fuselage in front of it -- one
    connected bright region, so its forward end is wherever the search box was put, and the first
    version of this function duly reported the box edge as the nozzle's start and an "aft reach" of
    0.95 m that was really the width of the box. The JOINT is visible in its own right: a dark ring
    where the nozzle turns against the skin, and the strongest vertical edge in the forward half.
    """
    s0, s1, h0, h1 = FRONT_BOX
    lit, ppm = rectify(rgb, to_pixel, s0, s1, h0, h1)
    edges = vertical_edges(lit, s0, ppm)
    middle = (s0 + s1) / 2
    forward = [e for e in edges if e[0] < middle]
    aft = [e for e in edges if e[0] >= middle]
    if not forward or not aft:
        return None
    joint = max(forward, key=lambda e: e[1])[0]
    exit_at = max(aft, key=lambda e: e[1])[0]
    median, widest, body = drum_depth(lit, ppm, h1, (joint - s0) * ppm + 6, (exit_at - s0) * ppm - 6)
    picture = np.stack([lit, lit, lit], axis=2)
    picture[body] = picture[body] * 0.55 + np.array([0.45, 0.0, 0.45])
    for station in (joint, exit_at):
        col = int((station - s0) * ppm)
        picture[:, max(col - 1, 0):col + 2] = np.array([0.0, 1.0, 1.0])
    Image.fromarray((picture * 255).astype(np.uint8)).save(os.path.join(out_dir, "fit-front-nozzle.png"))
    return joint, exit_at, median, widest, len(edges)


def rear_nozzle(rgb, to_pixel, out_dir):
    """The rear nozzle, and the reason there is no figure for it.

    Returns the edge list rather than a measurement. In all four airborne frames the rear nozzle
    sits inside the wing root's own shadow, and lifting the shadow lifts the JPEG noise with it.
    What that looks like, put as a number instead of an impression: the detector that finds two
    clean edges on the front nozzle finds a dozen and a half across this band, none of them
    belonging to anything a person can name in the picture. `modelling_here.md`: "a feature you
    cannot identify cannot be measured, however good the scale is."
    """
    s0, s1, h0, h1 = REAR_BOX
    lit, ppm = rectify(rgb, to_pixel, s0, s1, h0, h1)
    Image.fromarray((lit * 255).astype(np.uint8)).save(os.path.join(out_dir, "fit-rear-nozzle.png"))
    return vertical_edges(lit, s0, ppm)


def gear_lobes(mask, to_frame, to_pixel):
    """The two places where the silhouette hangs lowest, which on a bicycle undercarriage are wheels.

    This is a cross-check on the UNDERCARRIAGE rather than on the nozzles, and it is here because it
    is free: the hover frame has the gear down and nothing else on a Harrier's centreline reaches
    below the gun pods. It never saw [SAC], so it is a genuinely independent reading of the two
    stations that `measure_sac.stance` fits circles to.
    """
    lowest = []
    for station in np.arange(3.5, 10.0, 0.05):
        best = None
        for height in np.linspace(0.5, -2.6, 700):
            x, y = to_pixel(station, height)
            xi, yi = int(round(float(x))), int(round(float(y)))
            if 0 <= yi < mask.shape[0] and 0 <= xi < mask.shape[1] and mask[yi, xi]:
                best = height if best is None else min(best, height)
        lowest.append((station, best if best is not None else 0.0))
    lowest = np.array(lowest)
    floor = np.median(lowest[:, 1])
    below = lowest[lowest[:, 1] < floor - 0.12]
    groups, run = [], [below[0]] if len(below) else []
    for row in below[1:]:
        if row[0] - run[-1][0] < 0.2:
            run.append(row)
        else:
            groups.append(np.array(run)); run = [row]
    if run:
        groups.append(np.array(run))
    return [(float(g[np.argmin(g[:, 1]), 0]), float(g[:, 1].min()), float(g[0, 0]), float(g[-1, 0]))
            for g in groups if len(g) > 3]


def main(photos=PHOTOS, sac=SAC):
    print("MEASURING THE AV-8B's NOZZLES OFF PHOTOGRAPHS")
    print("photographs: %s" % photos)
    print("Read for SHAPE ONLY. Licences in that folder's FETCH-LOG.txt and in sources.md.\n")

    _, ink, _ = load(sac)
    sac_pxm = widest_row(ink, *PLAN_BAND)[0] / SPAN_FT / M
    drawn = straightest(lambda a, b: sac_fin_leading_edge(ink, sac_pxm, a, b), 3.40, 5.05)
    print("THE DRAWING'S FIN LEADING EDGE, re-derived here from the scan and not typed")
    print("  %.2f deg from vertical, %d rows, rms %.0f mm   (the model's constant: %.2f)"
          % (drawn[0], drawn[2], drawn[1] * 1000, FIN_LE_DRAWN_DEG))
    print("  [SAC] is %.4f px/m -- one pixel is %.1f mm\n" % (sac_pxm, 1000.0 / sac_pxm))

    path = os.path.join(photos, "beam-side-yuma.jpg")
    mask, rgb = craft_mask(path)
    to_frame, to_pixel, pxm, nose, tail, span = frame_of(mask)
    print("THE BEAM-ON FRAME  (%s)" % os.path.basename(path))
    print("  nose tip %.1f, %.1f   tail tip %.1f, %.1f" % (nose[0], nose[1], tail[0], tail[1]))
    print("  chord %.1f px -- de-rotated on the AEROPLANE's own axis, not on the horizon" % span)
    print("  %.2f px/m along the chord, from the PUBLISHED %.3f m length. ONE PIXEL IS %.1f mm"
          % (pxm, LENGTH_M, 1000.0 / pxm))

    shot = straightest(lambda a, b: fin_leading_edge(mask, to_frame, a, b), 1.15, 1.97)
    print("\nTHE ANISOTROPY, measured rather than assumed")
    print("  fin leading edge in the photograph  %.2f deg, %d rows, rms %.0f mm, band %+.2f..%+.2f"
          % (shot[0], shot[2], shot[1] * 1000, shot[3], shot[4]))
    print("  the same edge on the drawing        %.2f deg, %d rows, rms %.0f mm, band %.2f..%.2f"
          % (drawn[0], drawn[2], drawn[1] * 1000, drawn[3], drawn[4]))
    ratio = np.tan(np.radians(drawn[0])) / np.tan(np.radians(shot[0]))
    print("  vertical scale / longitudinal scale = tan(%.2f) / tan(%.2f) = %.4f" % (drawn[0], shot[0], ratio))
    print("  so a vertical metre is %.1f px, not %.1f -- a vertical reading taken with the" % (pxm * ratio, pxm))
    print("  longitudinal scale would come out %.1f per cent SHORT." % (100 * (1 - ratio)))
    print("  The camera is below the aeroplane, which the picture plainly shows. Yaw is the only")
    print("  other thing that moves this angle and it can only make a swept fin read SHALLOWER,")
    print("  so the sign rules it out rather than the magnitude.")

    # ---- the check that uses a figure the calibration did not set ----------------------------
    print("\nDOES THIS FRAME AGREE WITH THE DRAWING ABOUT SOMETHING ELSE?")
    print("  [SAC]'s blow-in doors are MEASURED at stations 3.65 to 3.88 (harrierlook, off page 2).")
    print("  Nothing about that figure went into this photograph's scale, which came from the")
    print("  published LENGTH alone. In the frame the door column reads about 3.71 to 3.94 --")
    print("  60 mm, a fifth of a door. The longitudinal frame is sound.")

    # ---- the nozzle ---------------------------------------------------------------------------
    out_dir = os.path.join(photos, "fits")
    os.makedirs(out_dir, exist_ok=True)
    got = front_nozzle(rgb, to_pixel, out_dir)
    print("")
    print("THE FRONT NOZZLE, off the beam-on frame, search box %s" % (FRONT_BOX,))
    if got is None:
        print("  no pair of edges in the box -- nothing measured")
    else:
        joint, exit_at, median, widest, how_many = got
        print("  the joint ring, strongest edge forward       station %.3f          [M]" % joint)
        print("  the exit rim, strongest edge aft             station %.3f          [M]" % exit_at)
        print("  SO THE NOZZLE REACHES                        %.3f m aft of its joint  [M]" % (exit_at - joint))
        print("  the lit drum is across, median / widest      %.3f / %.3f m        [M, LOWER BOUND]" % (median, widest))
        print("  and the whole box holds %d strong vertical edges, which is what a" % how_many)
        print("  feature you can actually see looks like to this detector.")
        print("")
        print("  WHY THE WIDTH IS A LOWER BOUND AND NOT A DIAMETER. The drum's TOP edge runs")
        print("  against the wing root's shadow and is crisp. Its BOTTOM edge is a shadow")
        print("  TERMINATOR on the nozzle's own underside -- jagged where the top edge is smooth")
        print("  -- so the lit extent is as much of the nozzle as the sun reached and the metal")
        print("  may go further. It is still decisive: the model draws this nozzle 0.800 m")
        print("  across, and the LIT METAL ALONE contradicts that by more than a factor of two.")
        print("")
        print("  A circle projects to its own full diameter along every direction in an image,")
        print("  whatever angle it is seen from, so this width needs NO anisotropy correction")
        print("  and applying one would make it wrong. The 0.83 above is for heights, not sizes.")
    rear = rear_nozzle(rgb, to_pixel, out_dir)
    print("")
    print("THE REAR NOZZLE, box %s -- NOT MEASURED, and here is the evidence" % (REAR_BOX,))
    print("  %d strong vertical edges in the band, against %d for the front nozzle." % (len(rear), how_many))
    print("  Not one of them is a landmark a person can name in the picture. In all four")
    print("  airborne frames the rear nozzle lies inside the wing root's own shadow, and")
    print("  lifting the shadow lifts the JPEG noise with it. The ground frames show it")
    print("  beautifully and are wide-angle walk-rounds with a person in shot, so they")
    print("  settle its STRUCTURE and can carry no scale. It stays an ESTIMATE, and says so.")
    hover = os.path.join(photos, "hover-nozzles-down.jpg")
    hmask, hrgb = craft_mask(hover)
    h_to_frame, h_to_pixel, h_pxm, _, _, _ = frame_of(hmask)
    print("\nTHE UNDERCARRIAGE, FREE, off the hover frame (%.1f mm a pixel)" % (1000.0 / h_pxm))
    print("  the lowest things on the centreline, which with the gear down are the wheels:")
    for deepest, low, first, last in gear_lobes(hmask, h_to_frame, h_to_pixel):
        print("    a lobe from station %5.2f to %5.2f, deepest %+.3f at station %5.2f" % (first, last, low, deepest))
    print("  [SAC]'s circle fits put the tyre centres at 4.681 and 8.129 (`measure_sac.stance`).")
    print("  This photograph has never seen that drawing. The model carries NOSE_STATION 3.05.")
    return 0


if __name__ == "__main__":
    sys.exit(main(*(sys.argv[1:3] or [])))
