"""IS THIS PHOTOGRAPH A BROADSIDE? Measured off a circle in the subject, not judged by eye.

    python cockpit/research/broadside.py --self-test
    python cockpit/research/broadside.py <image> [--dark|--light] [--top 8]

WHY THIS EXISTS. `cockpit/research/measure_cl415.py` screens candidate photographs by the
silhouette's aspect ratio against a true broadside's, which turned sixty-nine files into ten in a
second -- and then ranked a three-quarter view from the front FIRST. It scores well because a
wing projecting wide trades against a low camera making the aeroplane tall, and an aspect ratio
cannot separate those two. **A filter that only rules things out is worth writing; it is not a
detector, and its own doc block says so.**

A DETECTOR HAS TO BE SINGLE-VALUED: zero at the answer and monotonic away from it, so nothing can
trade against it. `lane/cooling` supplied the one this wants, from a cooling tower:

    A circle in the subject is a free protractor.

Its tower's top rim read as an ellipse 7 px deep on a 112 px semi-major, so the camera was
asin(7/112) = 3.6 degrees off level -- **measured from the image alone, with no published
dimension, no camera data and no scale.** A circle seen at an angle projects to an ellipse whose
MINOR OVER MAJOR is the cosine of the angle between the view and the circle's own axis. That is
the whole of the arithmetic here, and it is why this needs nothing that a caption could get wrong.

WHAT TO POINT IT AT, on an aircraft, and which way each one reads:

  * A PROPELLER DISC or a circular intake. Its axis lies along the aeroplane, so square from the
    side it is EDGE ON: minor/major goes to 0. A fat ellipse is a three-quarter view.
  * A MAIN WHEEL. Its axis lies across the aeroplane, so square from the side it is a FULL CIRCLE:
    minor/major goes to 1. This is the same measurement read the other way up, and the two
    together are a cross-check that shares no arithmetic with the first.

THE TWO DISAGREEING IS INFORMATION. A disc that says square-on and a wheel that says otherwise
means the camera is off in ELEVATION rather than in azimuth -- a low or high camera tilts a wheel
without yawing a propeller -- which is the exact confusion the aspect-ratio screen could not
resolve. See `report`.

AND IT IS HELD TO CIRCLES WHOSE ANSWER IS KNOWN. `--self-test` draws ellipses at tilts this file
types, measures them back and fails if any is out by more than a degree. A tool for judging
photographs that has never been shown a shape with a known answer is a tool nobody should believe.

WHAT IS EXACT HERE AND WHAT IS NOT, because the difference decides how to use it.

**The protractor is exact and proved.** Given the pixels of a circle, the tilt comes back within a
degree at every tilt and orientation tried, and a mutant that swaps `acos` for `asin` is caught on
all fifteen cases.

**Finding the circle is not.** `--box` is the honest interface: a person says where the wheel is,
in fractions of the image, and the tool measures it. `blobs()` is a HINT and not an answer -- run
against two real photographs of a CL-415 it returned shadows, a cowling and a patch of tarmac
above the wheels it was looking for, because a threshold and a flood fill cannot tell a wheel from
a dark shape that happens to be round. **A research tool that pretends to a certainty it has not
got is worse than one that asks for help**, and the aspect-ratio screen this replaces failed
exactly by being trusted past its evidence.
"""
import io
import math
import sys

import numpy as np
from PIL import Image

## HOW FAR OFF SQUARE A PHOTOGRAPH MAY BE and still be measured as an elevation, in degrees.
##
## Not a taste: at 20 degrees off, a CL-415's 28.6 m wing projects 9.8 m across the view against a
## 19.8 m hull, so the outline that looks like a side elevation is a hull and a wing superimposed
## and every station measured off it carries that error silently. At 3 degrees the wing projects
## 1.5 m, which is inside the fuselage it lies over. THE NUMBER COMES FROM THE SUBJECT, so it is
## an argument and not a constant -- `square_enough` takes the span and the length.
DEFAULT_SQUARE_DEGREES = 3.0

## A blob smaller than this share of the image is noise, a rivet or a bird.
MIN_BLOB_SHARE = 0.00008
## And one bigger than this is the sky, the tarmac or the whole aeroplane.
MAX_BLOB_SHARE = 0.25
## How elliptical a blob has to be before its axes mean anything: the share of the blob's own
## bounding ellipse that is actually filled. A true filled ellipse is pi/4 = 0.785 of its box.
MIN_FILL = 0.55


def ellipse_of(mask):
    """The second-moment ellipse of a boolean mask: (major, minor, degrees, filled share).

    FROM THE MOMENTS AND NOT FROM THE BOUNDING BOX. A bounding box is aligned to the image, so a
    circle and a 45-degree ellipse of the same box read identically; the moments carry the
    ORIENTATION, which is what makes this work on a wheel photographed from any angle.
    """
    ys, xs = np.nonzero(mask)
    if xs.size < 12:
        return None
    x = xs.astype(np.float64) - xs.mean()
    y = ys.astype(np.float64) - ys.mean()
    cxx = float((x * x).mean())
    cyy = float((y * y).mean())
    cxy = float((x * y).mean())
    # The eigenvalues of the covariance matrix are the variances along the principal axes; twice
    # their square roots are the axes of the ellipse with the same moments.
    common = math.sqrt(max(0.0, (cxx - cyy) ** 2 / 4.0 + cxy * cxy))
    big = (cxx + cyy) / 2.0 + common
    small = (cxx + cyy) / 2.0 - common
    if big <= 0.0:
        return None
    major = 4.0 * math.sqrt(big)
    minor = 4.0 * math.sqrt(max(0.0, small))
    degrees = math.degrees(0.5 * math.atan2(2.0 * cxy, cxx - cyy))
    area = float(xs.size)
    filled = area / (math.pi * major * minor / 4.0) if minor > 0.0 else 0.0
    return major, minor, degrees, filled


def tilt_from_circle(major, minor):
    """How far the view is from the circle's own axis, in degrees. 90 means edge on."""
    if major <= 0.0:
        return float("nan")
    return math.degrees(math.acos(min(1.0, max(0.0, minor / major))))


def square_enough(span_m, length_m, tolerance_m=None):
    """How many degrees off square a subject of this shape may be, before its wing lies over its
    own hull by more than the hull is wide.

    THE LIMIT IS A PROPERTY OF THE SUBJECT AND NOT OF THE CAMERA. A long thin aeroplane with a
    short span tolerates more yaw than a short one with an enormous wing, and quoting one figure
    for both is how a tolerance becomes a superstition. `tolerance_m` defaults to a twentieth of
    the length, which is about a light aircraft's fuselage width.
    """
    if tolerance_m is None:
        tolerance_m = length_m / 20.0
    if span_m <= 0.0:
        return DEFAULT_SQUARE_DEGREES
    return math.degrees(math.asin(min(1.0, tolerance_m / span_m)))


def blobs(image, want_dark=True, background_tolerance=0.16):
    """Connected components of the subject's dark (or light) detail, largest first.

    DELIBERATELY CRUDE. This is a research tool for looking at a dozen photographs, not a vision
    system: a flood fill on a threshold finds a wheel against a wing or a propeller disc against
    sky, and anything it cannot find is a photograph a person should look at instead.
    """
    grey = np.asarray(image.convert("L")).astype(np.float32) / 255.0
    level = float(np.median(grey))
    mask = (grey < level - background_tolerance) if want_dark else (grey > level + background_tolerance)
    height, width = mask.shape
    seen = np.zeros(mask.shape, dtype=bool)
    found = []
    smallest = MIN_BLOB_SHARE * height * width
    biggest = MAX_BLOB_SHARE * height * width
    ys, xs = np.nonzero(mask)
    for start in range(xs.size):
        sy, sx = int(ys[start]), int(xs[start])
        if seen[sy, sx]:
            continue
        stack = [(sy, sx)]
        seen[sy, sx] = True
        pixels = []
        while stack:
            cy, cx = stack.pop()
            pixels.append((cy, cx))
            if len(pixels) > biggest:
                break
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if not (smallest <= len(pixels) <= biggest):
            continue
        piece = np.zeros(mask.shape, dtype=bool)
        rows = np.array([p[0] for p in pixels])
        cols = np.array([p[1] for p in pixels])
        piece[rows, cols] = True
        shape = ellipse_of(piece)
        if shape is None or shape[3] < MIN_FILL:
            continue
        found.append({
            "pixels": len(pixels),
            "at": (float(cols.mean()), float(rows.mean())),
            "major": shape[0], "minor": shape[1], "degrees": shape[2], "filled": shape[3],
            "axis_tilt": tilt_from_circle(shape[0], shape[1]),
        })
    found.sort(key=lambda b: -b["pixels"])
    return found


def measure_box(path, box, want_dark=True):
    """Measure the round feature inside a box given as fractions of the image: x0,y0,x1,y1.

    IN FRACTIONS AND NOT PIXELS, so a box read off a shrunk copy still lands on the full-size
    original, and so the same box can be quoted in a sources file beside the Commons filename
    without also quoting a resolution that whoever re-fetches it may not get.
    """
    with Image.open(path) as opened:
        image = opened.convert("RGB")
    width, height = image.size
    x0, y0, x1, y1 = box
    crop = image.crop((int(x0 * width), int(y0 * height), int(x1 * width), int(y1 * height)))
    grey = np.asarray(crop.convert("L")).astype(np.float32) / 255.0
    level = float(np.median(grey))
    # OTSU WOULD BE BETTER AND IS NOT WORTH IT: inside a box a person has already drawn round one
    # feature, the median splits it from its surround, and anything it cannot split is a box drawn
    # round two things.
    mask = (grey < level) if want_dark else (grey > level)
    shape = ellipse_of(mask)
    if shape is None:
        print("RESULT=FAIL nothing measurable in that box")
        return None
    major, minor, degrees, filled = shape
    tilt = tilt_from_circle(major, minor)
    print("in a box %.0f x %.0f px: an ellipse %.1f by %.1f px, lying at %.1f degrees, "
          "filling %.2f of itself" % (crop.size[0], crop.size[1], major, minor, degrees, filled))
    print("  minor/major %.3f  ->  the view is %.1f degrees off this circle's own axis"
          % (minor / major if major else 0.0, tilt))
    print("  IF IT IS A WHEEL (axis across the aeroplane): %.1f degrees off a broadside." % tilt)
    print("  IF IT IS A PROPELLER DISC (axis along it):    %.1f degrees off a broadside."
          % abs(90.0 - tilt))
    # A TYRE IS A RING, and that is not a fault. Dark rubber round a light hub reads about half
    # filled, and its minor/major is STILL EXACT: a ring between two similar ellipses has the same
    # second-moment shape as either of them, so the aspect survives the hole. Measured on two
    # CL-415 main wheels, both read 0.52 and 0.57 filled and both gave angles that agreed with an
    # independent estimate. Low fill WITHOUT a light centre is the case to distrust.
    print("  filled %.2f: a tyre or a spinner is a RING and reads about 0.5 with its ratio intact;"
          % filled)
    print("  low fill with NO light centre means the box holds two things -- redraw it.")
    return {"major": major, "minor": minor, "degrees": degrees, "filled": filled, "tilt": tilt}


def report(path, want_dark=True, top=8, span_m=28.6, length_m=19.8):
    with Image.open(path) as opened:
        image = opened.convert("RGB")
        image.thumbnail((1400, 1400))
        found = blobs(image, want_dark=want_dark)
    limit = square_enough(span_m, length_m)
    print("a subject %.1f m across over %.1f m long may be %.1f degrees off square"
          % (span_m, length_m, limit))
    print("%5s %8s %8s %7s %7s  %s" % ("px", "major", "minor", "minor/", "off its", "at"))
    print("%5s %8s %8s %7s %7s  %s" % ("", "", "", "major", "axis", ""))
    for blob in found[:top]:
        print("%5d %8.1f %8.1f %7.3f %7.1f  (%.0f, %.0f)" % (
            blob["pixels"], blob["major"], blob["minor"],
            blob["minor"] / blob["major"] if blob["major"] else 0.0,
            blob["axis_tilt"], blob["at"][0], blob["at"][1]))
    print("")
    print("READ IT LIKE THIS. A round feature whose axis lies ALONG the subject -- a propeller")
    print("disc, a circular intake -- is edge on in a true broadside, so minor/major goes to 0")
    print("and 'off its axis' goes to 90. A round feature whose axis lies ACROSS it -- a wheel --")
    print("is a full circle, so minor/major goes to 1 and 'off its axis' goes to 0. If the two")
    print("disagree the camera is off in ELEVATION rather than azimuth, which is the confusion an")
    print("aspect-ratio screen cannot resolve.")
    return found


# ---- held to shapes whose answer is typed here -------------------------------------------

def _drawn_ellipse(size, major, minor, degrees):
    """A filled ellipse, drawn from its own parameters, for measuring back."""
    height = width = size
    ys, xs = np.mgrid[0:height, 0:width]
    x = xs - width / 2.0
    y = ys - height / 2.0
    radians = math.radians(degrees)
    along = x * math.cos(radians) + y * math.sin(radians)
    across = -x * math.sin(radians) + y * math.cos(radians)
    return (along / (major / 2.0)) ** 2 + (across / (minor / 2.0)) ** 2 <= 1.0


def self_test():
    """Draw circles at tilts typed HERE and measure them back.

    THE EXPECTED NUMBERS ARE TYPED AND NOT COMPUTED FROM THE CODE UNDER TEST. A tilt of 60 degrees
    makes a circle of diameter 200 into an ellipse 200 by 100, because cos 60 is exactly a half --
    the cases are chosen so a reader can check the arithmetic without running anything.
    """
    failures = []
    cases = [
        # (tilt off the circle's axis, major, minor, and the minor a reader can verify)
        (0.0, 200, 200.0),
        (60.0, 200, 100.0),
        (45.0, 200, 141.4),
        (75.0, 200, 51.8),
        (84.3, 200, 20.0),
    ]
    for tilt, major, expected_minor in cases:
        minor = major * math.cos(math.radians(tilt))
        if abs(minor - expected_minor) > 0.5:
            failures.append("the case itself is wrong: cos %.1f x %d is %.1f, not %.1f"
                            % (tilt, major, minor, expected_minor))
    for tilt, major, expected_minor in cases:
        for drawn_at in (0.0, 30.0, -50.0):
            mask = _drawn_ellipse(420, major, max(6.0, expected_minor), drawn_at)
            shape = ellipse_of(mask)
            if shape is None:
                failures.append("no ellipse found at tilt %.1f drawn at %.0f" % (tilt, drawn_at))
                continue
            got = tilt_from_circle(shape[0], shape[1])
            if abs(got - tilt) > 1.0:
                failures.append("tilt %.1f drawn at %.0f measured back as %.1f (%.1f x %.1f px)"
                                % (tilt, drawn_at, got, shape[0], shape[1]))
            # AND THE ORIENTATION, because a tool that gets the angle right and the direction
            # wrong will happily call a wheel a propeller disc.
            turned = (shape[2] - drawn_at + 90.0) % 180.0 - 90.0
            if expected_minor < major - 6.0 and abs(turned) > 2.0:
                failures.append("drawn at %.0f, measured at %.1f" % (drawn_at, shape[2]))
    # AND THE SUBJECT'S OWN LIMIT. A CL-415 is 28.6 m across and 19.8 m long, so a fuselage width
    # of 0.99 m is reached at asin(0.99 / 28.6) = 1.98 degrees.
    limit = square_enough(28.6, 19.8)
    if abs(limit - 1.98) > 0.05:
        failures.append("a CL-415 should tolerate 1.98 degrees, not %.2f" % limit)
    print("RESULT=PASS %d ellipses at five tilts and three orientations, and one subject limit"
          % (len(cases) * 3) if not failures else "RESULT=FAIL " + "; ".join(failures))
    return 0 if not failures else 1


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    if "--box" in sys.argv:
        corners = [float(v) for v in sys.argv[sys.argv.index("--box") + 1].split(",")]
        measure_box(sys.argv[1], corners, want_dark="--light" not in sys.argv)
        sys.exit(0)
    report(sys.argv[1], want_dark="--light" not in sys.argv,
           top=int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 8)
