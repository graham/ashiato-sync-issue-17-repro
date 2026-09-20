"""Re-derive the Three Forty Three's proportions FROM THE PHOTOGRAPH ALONE.

`modelling_here.md` section 3: "MAKE THE RESEARCH FILE REPRODUCIBLE BY A SCRIPT THAT DOES NOT
READ IT." Nothing here is typed out of `references.md` or out of the model. The only inputs are

  * the image,
  * two PUBLISHED figures (length overall and beam), and
  * two hand picks of the ends, which are stated below with their uncertainty and were made by
    looking at the image at 6x, not by thresholding it.

Everything else is measured, and the residuals are PRINTED, because `modelling_here.md`'s most
expensive rule is that a fit whose residual nobody printed is a fit nobody checked.

THE PHOTOGRAPH IS NOT IN THE REPO. It is CC BY 3.0 and study only, as `modelling_here.md` section 2
requires. Fetch `Peter Stehlik - FDNY Three Forty Three - 2012.05.17.jpg` from Wikimedia Commons at
width 2400 and put it beside this file as `stehlik.jpg`, exactly as `craft/prowler/measure_sac.py`
asks for its drawing.

Run:  python measure_boat.py
"""

from PIL import Image
import numpy as np

# ---- the published figures -------------------------------------------------------------
# [W] Wikipedia, "Three Forty Three", infobox, via action=raw, 2026-09-19.
LOA_M = 140.0 * 0.3048          # 42.672 m
BEAM_M = 36.0 * 0.3048          # 10.973 m
DRAUGHT_M = 9.0 * 0.3048        # 2.743 m

# ---- the two hand picks ----------------------------------------------------------------
# Picked at 6x and looked at. The stem is a clean near-vertical rub-strake edge and is worth
# +/- 4 px. The transom is NOT clean -- the camera is forward of the beam, so the quarter
# recedes and the stern wave crosses the boundary -- and is worth +/- 40.
STEM_X, STEM_TOL = 348.0, 4.0
TRANSOM_X, TRANSOM_TOL = 3390.0, 40.0


def red_mask(im):
    """The hull. A RATIO test, never a brightness one.

    The shadowed bow reads (26, 5, 4). A brightness threshold of 55 -- which looks entirely
    reasonable -- missed the forward third of the boat and put the stem 200 px out into the
    pier behind it, and every figure downstream would have been quietly 6 per cent long. The
    error was found by cropping the pick and looking at it, not by any check here.
    """
    r, g, b = im[:, :, 0], im[:, :, 1], im[:, :, 2]
    return (r > 18) & (r > g * 1.5) & (r > b * 1.4)


def white_mask(im):
    """The superstructure and the bulwark band: bright and near-neutral."""
    r, g, b = im[:, :, 0], im[:, :, 1], im[:, :, 2]
    lo = np.minimum(np.minimum(r, g), b)
    hi = np.maximum(np.maximum(r, g), b)
    return (lo > 120) & ((hi - lo) < 42)


def hull_run(red, x, lo=1200, hi=2120, min_len=40):
    """The hull in one column: the LONGEST CONTIGUOUS run of red, and its two ends.

    The first version of this took "the topmost red" and "the bottommost red" in the column,
    which is wrong in both directions and failed loudly, which is why it is written up here:

      * topmost red is a MONITOR or the red casing high on the superstructure, not the deck
        edge -- it put the deck at y 1310 and reported a freeboard of 8.6 m on a 42.7 m boat;
      * bottommost red is the hull's REFLECTION in the water or a patch of wake, not the
        waterline -- it dragged the fit to an rms of 41 px with a worst case of 211.

    The hull is the one thing that is continuously red from the waterline up to the deck edge,
    so that is what is asked for. Returns (top, bottom) or None.
    """
    col = red[lo:hi, x]
    best, start, run = None, None, 0
    for i, on in enumerate(col):
        if on:
            if start is None:
                start = i
            run += 1
        else:
            if start is not None and run >= min_len and (best is None or run > best[1] - best[0]):
                best = (start, start + run)
            start, run = None, 0
    if start is not None and run >= min_len and (best is None or run > best[1] - best[0]):
        best = (start, start + run)
    return None if best is None else (lo + best[0], lo + best[1])


def robust_line(xs, ys, passes=3, keep=2.5):
    """A straight fit that throws out what the bow wave and the wake put in, and says how many."""
    xs, ys = np.asarray(xs, float), np.asarray(ys, float)
    use = np.ones(xs.size, bool)
    for _ in range(passes):
        fit = np.polyfit(xs[use], ys[use], 1)
        r = ys - np.polyval(fit, xs)
        s = np.std(r[use]) or 1.0
        use = np.abs(r) < keep * s
    fit = np.polyfit(xs[use], ys[use], 1)
    return fit, ys - np.polyval(fit, xs), use


def main():
    im = np.asarray(Image.open("stehlik.jpg").convert("RGB")).astype(int)
    h, w, _ = im.shape
    red, white = red_mask(im), white_mask(im)

    px_per_m = (TRANSOM_X - STEM_X) / LOA_M
    tol = (TRANSOM_TOL + STEM_TOL) / (TRANSOM_X - STEM_X)
    print("image                 %d x %d" % (w, h))
    print("LOA                   %.0f px for %.3f m  (140 ft)" % (TRANSOM_X - STEM_X, LOA_M))
    print("SCALE                 %.2f px/m   one pixel = %.1f mm   +/- %.1f%%"
          % (px_per_m, 1000.0 / px_per_m, 100.0 * tol))
    print()

    # ---- the waterline, per column -----------------------------------------------------
    # NOT a row of pixels. The view is not exactly abeam, so it falls from bow to stern, and a
    # freeboard that falls steadily aft looks exactly like sheer -- which this boat genuinely
    # has. Fit a straight line through the per-column readings and print the residual.
    xs, wl, dk = [], [], []
    for x in range(int(STEM_X) + 60, int(TRANSOM_X) - 60, 10):
        run = hull_run(red, x)
        if run is not None:
            xs.append(x)
            dk.append(run[0])
            wl.append(run[1])
    fit, resid, use = robust_line(xs, wl)
    print("WATERLINE, fitted over %d columns, %d kept (not through two ends -- lane/prowler's rule)"
          % (len(xs), int(use.sum())))
    print("  at the stem    y = %.0f" % np.polyval(fit, STEM_X))
    print("  at the transom y = %.0f" % np.polyval(fit, TRANSOM_X))
    print("  fall along the hull   %.0f px = %.2f m"
          % (np.polyval(fit, TRANSOM_X) - np.polyval(fit, STEM_X),
             (np.polyval(fit, TRANSOM_X) - np.polyval(fit, STEM_X)) / px_per_m))
    print("  RESIDUAL  rms %.1f px (%.0f mm)  worst kept %.1f px"
          % (float(np.sqrt((resid[use] ** 2).mean())),
             1000.0 * float(np.sqrt((resid[use] ** 2).mean())) / px_per_m,
             float(np.abs(resid[use]).max())))
    print()

    def water_at(x):
        return float(np.polyval(fit, x))

    # ---- the deck edge, per station ----------------------------------------------------
    # Forward of the casing the hull's red is capped by the WHITE bulwark band, so the lowest
    # white pixel sitting directly on red is the deck edge. Aft the casing is red on red and
    # this cannot see it, which is said rather than papered over.
    print("FREEBOARD: the top of the hull's own contiguous red, against the fitted waterline")
    print("  station (m from stem)   deck y   water y   freeboard")
    raw = []
    for frac in (0.12, 0.22, 0.32, 0.42, 0.52, 0.62, 0.72, 0.82):
        x = int(STEM_X + frac * (TRANSOM_X - STEM_X))
        run = hull_run(red, x)
        if run is not None:
            raw.append((frac * LOA_M, x, run[0], (water_at(x) - run[0]) / px_per_m))

    # WHERE THE RED CASING STANDS ON THE RED HULL there is no colour change at the deck edge,
    # so the contiguous run climbs straight through it and the station measures the casing's
    # top instead. Those stations are NAMED AND DROPPED, not quietly averaged in: a freeboard
    # of 9 m on a 42.7 m boat is the method reporting where it cannot see, and that is a
    # finding about the reference, not a number about the ship.
    med = float(np.median([r[3] for r in raw]))
    rows = []
    for st, x, deck, fb in raw:
        if fb > 2.0 * med:
            print("  %6.1f                 %5d   %6.0f    -- red casing on red hull, no deck"
                  " edge to see (reads %.1f m)" % (st, deck, water_at(x), fb))
            continue
        rows.append((st, deck, water_at(x), fb))
        print("  %6.1f                 %5d   %6.0f    %5.2f m" % (st, deck, water_at(x), fb))

    if len(rows) >= 3:
        fbs = [r[3] for r in rows]
        fwd = sum(fbs[:2]) / 2.0
        aft = sum(fbs[-2:]) / 2.0
        print("  -> forward mean %.2f m, after mean %.2f m: freeboard FALLS AFT by %.2f m."
              % (fwd, aft, fwd - aft))
        print("     That is SHEER, and it is the right sign -- a real hull is deeper forward.")
        print("     An ordering is a sharper check than any one number inside a wide band,")
        print("     because compensating errors do not preserve it (modelling_here.md s3).")
        print("     BUT the fitted waterline also falls aft, so part of this is the view not")
        print("     being abeam. The two are not separable from one photograph; SAY SO.")
    print()

    # ---- a cross-check nothing above was fitted to -------------------------------------
    # PUBLISHED in, PUBLISHED out. Depth is not published for this boat, so the honest check
    # available is the hull's drawn depth against its published draught: freeboard + draught
    # is the moulded depth, and a 42.7 m steel boat must land in a believable band.
    if rows:
        amid = rows[-1][3]
        depth = amid + DRAUGHT_M
        print("CROSS-CHECK (nothing here was fitted to it)")
        print("  freeboard amidships %.2f m  +  published draught %.2f m  =  depth %.2f m"
              % (amid, DRAUGHT_M, depth))
        print("  ratio depth/LOA = %.3f   a 40-45 m workboat runs about 0.10-0.14" % (depth / LOA_M))
        print("  VERDICT: %s" % ("inside the band" if 0.09 <= depth / LOA_M <= 0.15 else "OUTSIDE -- go and look"))


if __name__ == "__main__":
    main()
