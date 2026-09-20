"""Re-derive every measured figure for the F-4E FROM THE DRAWING ALONE.

    python measure_manual.py <path to the T.O. three-view png>

The drawing is NOT in this repository. It is a public-domain USAF technical order held for study
in `~/godotgames-drafts/2026-09-19/phantom/research/`, with its licence table beside it, and
nothing from it is incorporated into the game. Point this script at that file.

WHAT THIS IS FOR. `modelling_here.md` section 3: *make the research file reproducible by a script
that does not read it*, so `sources.md`, `PhantomAirframe` and this can disagree and one of them be
wrong. It earned that on its first run -- it disagreed with the figures measured by hand, twice,
and both times the script was the one that was wrong, for reasons worth knowing (see `thin lines`
below).

The only things typed in here are the figures PRINTED ON THE SHEET IN INK (`PRINTED`) and the few
windows in `BLOCKS` naming whole blocks of page furniture. Every centreline, edge, tip, station and
extent is found from the ink.

THE SHEET: the USAF general-arrangement three-view of the F-4E/F-4G, *Maintenance Instructions,
Cross Servicing Guide for Phantom II Aircraft*, T.O. 1F-4C-2-1-1 Change 7, 1993, p. 1-16, public
domain, 2,078 x 2,488 px, with eleven dimensions printed on it in metres.

A LIMIT ON WHAT IT CAN PROVE, SAID AT THE TOP. Those printed metric figures are millimetre
conversions of the F-4E flight manual's feet and inches -- 38 ft 5 in -> 11.71 m, 63 ft -> 19.2 m,
17 ft 11 in -> 5.46 m. The drawing and the manual are ONE AUTHORITY IN TWO UNITS. A printed figure
agreeing with another printed figure proves nothing; only a printed figure agreeing with the INK
does, and every check here is ink against print.

AND THE RULE THAT DECIDES HOW THIS SCRIPT IS ORGANISED, from `lane/harriershape` (2026-09-20):
**NOT ONE PUBLISHED FIGURE ABOUT AN AEROPLANE IS A STATION.** Lengths, spans, heights, tracks and
angles all survive sliding a component anywhere along the body, which is how that lane put an
intake round the nose with every check green. This sheet is a rare exception: the printed
**7.09 m wheelbase is a station difference**, measured along the very axis stations live on, so it
-- and not the aeroplane's own drawn length -- sets the side view's scale. Every other fore-and-aft
position is then its own measurement with its own uncertainty, and the report says whose number
each row is.

FOUR THINGS THAT WENT WRONG ON THE WAY HERE, so nobody re-derives them:

- **Masking the page's extension lines BY A COLUMN WINDOW removes the feature the line points at.**
  The plan's nose extension line stands ON the nose tip, five pixels short of the pitot. Windowing
  it cost 43 px of aeroplane and read the length 2.2 per cent short.
- **Masking them BY THINNESS eats the aeroplane's own long straight edges.** A stabilator leading
  edge is a two-pixel line running 300 px with blank page either side, which no thickness test can
  tell from an extension line. That version was deleting wing.
- **Taking the WIDEST group of ink on the axis** read the plan's length as the rear fuselage alone,
  520 px of 1,925, because a fuselage drawn as two side lines puts nothing on its own axis
  amidships.
- **A DATUM IS NOT A ROW OF PIXELS.** The side view's ground line drifts 6.8 px across the sheet.
  Read as one row it would put every height near the tail about 0.07 m out, all one way. It is
  fitted per column.
"""

import sys
import numpy as np
from PIL import Image

# --------------------------------------------------------------------------------------------
# PRINTED ON THE SHEET, IN INK
# --------------------------------------------------------------------------------------------
PRINTED = {
    "length": 19.2,           # plan, nose to tail
    "span": 11.71,            # front, tip to tip
    "stabilator_span": 5.0,   # plan, stabilator tip to tip
    "wheelbase": 7.09,        # side, nose axle to main axle -- THE ONLY PRINTED STATION FIGURE
    "track": 5.46,            # front, main tyre centres
    "folded_width": 8.41,     # front -- a SPAN over the FOLDED panels, NOT the hinge. Not used.
    "height": 4.98,           # side -- NOT MEASURABLE HERE: the scan clips the fin tip
}

BLOCKS = {
    "the 19.2 m rule and its label, under the plan": (slice(2440, None), slice(None)),
    "the 5.0 m rule, right of the plan":             (slice(None), slice(1995, None)),
}
BANDS = {"side": (0, 535), "front": (536, 1233), "plan": (1234, 2439)}
INK = 128
PEN = 4                       # the widest a drawn line gets; every pixel floor is at least this


def ink_of(img):
    return np.asarray(img.convert("L")) < INK


def runs(v, gap=3):
    idx = np.where(v)[0]
    if idx.size == 0:
        return []
    out, s, p = [], idx[0], idx[0]
    for i in idx[1:]:
        if i - p > gap:
            out.append((int(s), int(p)))
            s = i
        p = i
    out.append((int(s), int(p)))
    return out


def fit(xs, ys):
    xs, ys = np.asarray(xs, float), np.asarray(ys, float)
    m, c = np.polyfit(xs, ys, 1)
    r = ys - (m * xs + c)
    return m, c, float(np.sqrt((r ** 2).mean())), int(xs.size)


# --------------------------------------------------------------------------------------------
# 1. IS THE SHEET TURNED?
# --------------------------------------------------------------------------------------------
def rotation(ink):
    """Asked of BOTH axes, because here the answer is no and only both axes can say so.

    A real page turn tilts the horizontal rules one way and the vertical extension lines the
    other, consistently and by the same angle. These do not: six extension lines are straight
    within a single pixel column, bounding any turn at 0.15 degrees, while two long horizontal
    rules slope by -0.21 and -0.12. That is LOCAL WARP IN A PHOTOCOPY, and de-rotating the page
    would insert an error rather than remove one. The consequence is an error bar, not a
    correction -- which is why the ground line below is fitted per column instead.
    """
    H, W = ink.shape
    found = []
    for x in range(W):
        for s, e in runs(ink[:, x]):
            if e - s < 250:
                continue
            if ink[s:e + 1, max(0, x - 2)].mean() < 0.5 and ink[s:e + 1, min(W - 1, x + 2)].mean() < 0.5:
                found.append((x, s, e))
    print("=" * 94)
    print("1. IS THE SHEET TURNED?  asked of the vertical extension lines, not only the rules")
    print("=" * 94)
    for x, s, e in found:
        print(f"   x={x:5d} straight within ONE pixel column over rows {s}..{e} ({e - s} tall)"
              f" -> bounds any turn at {np.degrees(np.arctan(1.0 / (e - s))):.3f} deg")
    if found:
        worst = min(np.degrees(np.arctan(1.0 / (e - s))) for _x, s, e in found)
        print(f"   {len(found)} of them; the longest bounds any page turn at {worst:.3f} deg.")
        print("   VERDICT: local warp in a photocopy, NOT a page turn. Nothing is de-rotated.")


# --------------------------------------------------------------------------------------------
# 2. THE PLAN VIEW
# --------------------------------------------------------------------------------------------
def band(ink, name):
    y0, y1 = BANDS[name]
    keep = np.zeros_like(ink)
    keep[y0:y1 + 1] = ink[y0:y1 + 1]
    for rows, cols in BLOCKS.values():
        keep[rows, cols] = False
    return keep


def centreline(keep):
    """The row about which the drawing best mirrors onto itself.

    Not the midpoint of the extremes, which is circular when the extremes are what is about to be
    measured, and not typed, which would be a number beside a number.
    """
    rows = np.where(keep.any(axis=1))[0]
    lo, hi = int(rows.min()), int(rows.max())
    best = None
    for c2 in range(2 * (lo + 200), 2 * (hi - 200)):
        r = np.arange(max(lo, c2 - hi), min(hi, c2 - lo) + 1)
        m = c2 - r
        ok = (m >= 0) & (m < keep.shape[0])
        r, m = r[ok], m[ok]
        if r.size < 500:
            continue
        s = int((keep[r] & keep[m]).sum())
        if best is None or s > best[1]:
            best = (c2 / 2.0, s)
    return best


def mirrored(keep, r, c):
    """A wingtip is a row that is mirrored; a dimension line, running past on one side, is not."""
    mr = int(round(2 * c - r))
    if not (0 <= mr < keep.shape[0]):
        return False
    a = [q for q in runs(keep[r]) if q[1] - q[0] >= PEN]
    b = [q for q in runs(keep[mr]) if q[1] - q[0] >= PEN]
    if not a or not b:
        return False
    for s, e in a:
        mid, floor = 0.5 * (s + e), max(PEN, 0.03 * (e - s + 1) + 6)
        if not any(abs(mid - 0.5 * (s2 + e2)) <= floor for s2, e2 in b):
            return False
    return True


def plan_report(ink):
    keep = band(ink, "plan")
    c, score = centreline(keep)
    rows = np.where(keep.any(axis=1))[0]
    top = next(int(r) for r in rows if mirrored(keep, r, c))
    bot = next(int(r) for r in rows[::-1] if mirrored(keep, r, c))
    # nose and tail: outermost ink ON the axis, in a group longer than the pen
    cols = [x for x in range(keep.shape[1])
            if np.where(keep[:, x])[0].size
            and ((np.where(keep[:, x])[0] > c - 12) & (np.where(keep[:, x])[0] < c + 12)).any()]
    cols = np.array(cols)
    gaps = np.where(np.diff(cols) > PEN)[0]
    groups, s = [], 0
    for g in gaps:
        groups.append((int(cols[s]), int(cols[g])))
        s = g + 1
    groups.append((int(cols[s]), int(cols[-1])))
    real = [g for g in groups if g[1] - g[0] >= PEN]
    nose, tail = real[0][0], real[-1][1]

    along = (tail - nose) / PRINTED["length"]
    across = (bot - top) / PRINTED["span"]
    tailband = keep[:, 1900:1950]
    tr = np.where(tailband.any(axis=1))[0]
    stab = (tr.max() - tr.min()) / PRINTED["stabilator_span"]

    print("\n" + "=" * 94)
    print("2. THE PLAN VIEW: its centreline, its two axes, and the wing")
    print("=" * 94)
    print(f"   centreline y = {c:.1f}, from the aeroplane's own best mirror ({score:,} px)")
    print(f"   wingtips mirrored at y={top} and y={bot}; {c - top:.1f} and {bot - c:.1f} px off"
          f" the axis, {abs((c - top) - (bot - c)):.1f} apart against a floor of {PEN}")
    print(f"   nose x={nose}, tail x={tail}")
    print(f"     ALONG  {tail - nose:5d} px / {PRINTED['length']:5.2f} m = {along:7.2f} px/m")
    print(f"     ACROSS {bot - top:5d} px / {PRINTED['span']:5.2f} m = {across:7.2f} px/m")
    print(f"     stabilator span (scaled by nothing) {tr.max() - tr.min():4d} px /"
          f" {PRINTED['stabilator_span']:4.2f} m = {stab:7.2f} px/m")
    print(f"   THE TWO SPANWISE READINGS AGREE TO {100 * abs(across - stab) / across:.2f}%"
          f" AND SIT {100 * abs(along - across) / across:.2f}% FROM THE LENGTHWISE ONE.")
    print("   Noise does not sort itself by axis: the sheet is stretched ~1% ALONG the aeroplane.")
    print("   So sizes come from the published figures, and the drawing is asked only for")
    print("   proportions WITHIN one axis.")
    return keep, c, top, bot, nose, tail, along, across


def wing(keep, c, tip_row, along, across):
    """Both wing edges, tracked BY CONTINUITY FROM THE TIP, never by the outermost ink."""
    le, te, pl, pt = [], [], None, None
    for y in range(tip_row, int(c) - 40):
        rr = [q for q in runs(keep[y]) if q[1] - q[0] >= 1]
        if not rr:
            continue
        if pl is None:
            pl, pt = min(q[0] for q in rr), max(q[1] for q in rr)
        else:
            cl = [q[0] for q in rr if abs(q[0] - pl) <= 28]
            ct = [q[1] for q in rr if abs(q[1] - pt) <= 28]
            if not cl or not ct:
                break
            pl = min(cl, key=lambda v: abs(v - pl))
            pt = min(ct, key=lambda v: abs(v - pt))
        le.append((y, pl))
        te.append((y, pt))
    ys = np.array([p[0] for p in le], float)
    xl = np.array([p[1] for p in le], float)
    xt = np.array([p[1] for p in te], float)

    def sweep(m):
        return np.degrees(np.arctan((m / along) * across))

    _m, _c, one_rms, _n = fit(ys, xl)
    best = None
    for k in range(60, len(ys) - 60):
        m1, c1, r1, _ = fit(ys[:k], xl[:k])
        m2, c2, r2, _ = fit(ys[k:], xl[k:])
        tot = np.sqrt((r1 ** 2 * k + r2 ** 2 * (len(ys) - k)) / len(ys))
        if best is None or tot < best[0]:
            best = (tot, k, m1, c1, r1, m2, c2, r2)
    tot, k, m1, c1, r1, m2, c2, r2 = best
    split = ys[k]
    mL, cL, rL, nL = fit(ys[k:], xl[k:])
    mT, cT, rT, nT = fit(ys[k:], xt[k:])
    mq = 0.75 * mL + 0.25 * mT

    print("\n   THE WING, tracked by continuity from the tip over"
          f" {len(ys)} rows")
    print(f"     one straight fit over all of it: {sweep(_m):+7.2f} deg at {one_rms:5.2f} px rms")
    print(f"     TWO segments, split SEARCHED FOR:  {tot:5.2f} px rms -- {one_rms / tot:.1f}x better")
    print(f"       outboard {sweep(m1):+7.2f} deg at {r1:4.2f} px over {k} rows")
    print(f"       inboard  {sweep(m2):+7.2f} deg at {r2:4.2f} px over {len(ys) - k} rows")
    step = (m2 * split + c2) - (m1 * split + c1)
    print(f"     the two lines stand {step:+.1f} px apart at the split = {1000 * step / along:+.0f} mm"
          f" of DOGTOOTH, at {(c - split) / across:.3f} m out from the axis")
    print(f"     inboard panel: LE {sweep(mL):+7.3f} deg at {rL:4.2f} px,"
          f" TE {sweep(mT):+7.3f} deg at {rT:4.2f} px, over {nL} rows")
    print(f"     QUARTER CHORD, three quarters of the first plus one quarter of the second,"
          f" fitted to nothing: {sweep(mq):+7.3f} deg")
    print(f"       published 45 -> {abs(abs(sweep(mq)) - 45.0):.3f} deg apart."
          f"  THE PUBLISHED 45 IS THE QUARTER CHORD, NOT THE LEADING EDGE (which is"
          f" {abs(sweep(mL)):.1f}).")

    def xL(y):
        return mL * y + cL

    def xT(y):
        return mT * y + cT

    c_root = (xT(c) - xL(c)) / along
    c_tip = (xT(tip_row) - xL(tip_row)) / along
    semi = (c - tip_row) / across
    area = (c_root + c_tip) * 0.5 * semi * 2.0
    lam = c_tip / c_root
    mac = (2.0 / 3.0) * c_root * (1 + lam + lam * lam) / (1 + lam)
    print(f"     root chord {c_root:6.3f} m, tip {c_tip:6.3f} m, taper {lam:5.3f}, M.A.C. {mac:6.3f} m")
    print(f"     REFERENCE AREA {area:6.2f} m2 against a published 49.2 -> {100 * (area - 49.2) / 49.2:+.2f}%"
          f"   <- combines both axes, fitted to nothing")
    print(f"     aspect ratio {(2 * semi) ** 2 / area:5.3f} against 2.77"
          f" (NOT independent -- it is area and span again)")
    print(f"     span from the fitted panel {2 * semi:6.3f} m -- *** CIRCULAR ***, the across-axis")
    print("       scale was SET by the printed span, so this cannot fail and is not evidence.")
    return (c - split) / across


# --------------------------------------------------------------------------------------------
# 3. THE SIDE VIEW -- where stations come from
# --------------------------------------------------------------------------------------------
def ground_line(ink):
    """Fitted PER COLUMN. A datum in a scan is not a row of pixels."""
    pts = [(x, 480 + np.where(ink[480:500, x])[0].mean())
           for x in range(20, 2060) if np.where(ink[480:500, x])[0].size]
    m, c, rms, n = fit([p[0] for p in pts], [p[1] for p in pts])
    return m, c, rms, n


def side_report(ink):
    from scipy import ndimage
    gm, gc, grms, gn = ground_line(ink)
    print("\n" + "=" * 94)
    print("3. THE SIDE VIEW: the only view with a printed STATION figure on it")
    print("=" * 94)
    print(f"   ground line fitted per column: y = {gm:+.5f}x + {gc:.2f}, {grms:.2f} px rms over {gn} cols")
    print(f"     it drifts {gm * 2000:+.1f} px across the sheet. Read as ONE ROW it would put every")
    print(f"     height near the tail about {abs(gm * 2000) / 100.56:.2f} m out, all in one direction.")

    keep = np.zeros_like(ink)
    for x in range(ink.shape[1]):
        g = int(gm * x + gc)
        keep[0:g - 3, x] = ink[0:g - 3, x]
    keep[:, :64] = False
    keep[:, 2010:] = False
    lab, n = ndimage.label(keep, structure=np.ones((3, 3), int))
    sizes = ndimage.sum(keep, lab, range(1, n + 1))
    body = lab == (int(np.argmax(sizes)) + 1)
    xs = np.where(body.any(axis=0))[0]
    nose, tail = int(xs.min()), int(xs.max())

    # THE SCALE COMES FROM THE PRINTED WHEELBASE, measured along the axis stations live on.
    axles = wheelbase_ticks(ink)
    scale = (axles[1] - axles[0]) / PRINTED["wheelbase"]
    print(f"\n   the printed 7.09 m wheelbase: extension lines at x={axles[0]} and x={axles[1]},"
          f" {axles[1] - axles[0]} px")
    print(f"     SIDE STATION SCALE {scale:7.2f} px/m   <- from a printed STATION difference")
    print(f"   the aeroplane's own drawn length x {nose}..{tail} = {tail - nose} px"
          f" = {(tail - nose) / scale:.3f} m")
    print(f"     against a published {PRINTED['length']:.2f} ->"
          f" {100 * ((tail - nose) / scale - PRINTED['length']) / PRINTED['length']:+.2f}%"
          f"   <- a check: the wheelbase set the scale, the length did not")
    print(f"   nose gear axle at station {(axles[0] - nose) / scale:6.3f} m")
    print(f"   main gear axle at station {(axles[1] - nose) / scale:6.3f} m")
    return body, nose, tail, scale, gm, gc


def wheelbase_ticks(ink):
    """The two extension lines of the 7.09 m dimension, under the side view's ground line."""
    hits = [x for x in range(ink.shape[1]) if np.where(ink[495:536, x])[0].size >= 20]
    groups, s = [], 0
    for i in range(1, len(hits)):
        if hits[i] - hits[i - 1] > PEN:
            groups.append((hits[s], hits[i - 1]))
            s = i
    groups.append((hits[s], hits[-1]))
    ends = [int(0.5 * (a + b)) for a, b in groups]
    return ends[0], ends[-1]


def main(path):
    ink = ink_of(Image.open(path))
    print(f"sheet {path}: {ink.shape[1]} x {ink.shape[0]} px, ink {100 * ink.mean():.2f}%")
    rotation(ink)
    keep, c, top, bot, nose, tail, along, across = plan_report(ink)
    dogtooth = wing(keep, c, top, along, across)
    side_report(ink)
    print("\n" + "=" * 94)
    print("NOT MEASURED HERE, AND WHY")
    print("=" * 94)
    print("   height 4.98 m: THE SCAN CLIPS THE FIN TIP. At the side view's scale it would stand")
    print("     about 8 px above the top edge, and the ink stops at y=5. Taken from the printed")
    print("     figure -- and the F-4E flight manual's own 16 ft 5 in (5.004 m) is preferred to")
    print("     the drawing's 4.98, which is 16 ft 4 in. One inch, two USAF documents.")
    print("   folded width 8.41 m: the flight manual calls it a SPAN with the wings folded, so it")
    print("     is measured over the folded panels and does NOT place the fold hinge. The dashed")
    print(f"     lines it is printed between DO, and they agree with the dogtooth at {dogtooth:.3f} m.")
    print("   3.33, 3.28, 3.45 and 1.83 m: four printed figures whose datum is not yet named.")
    print("     Unspent constraints. A figure not yet used is a check not yet run.")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "f4e_manual_3view.png")
