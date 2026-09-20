"""Re-derives every MEASURED figure in `sources.md` and `OspreyAirframe` from the V-22 six-view alone, reading nothing out
of the write-up.

    python cockpit/craft/osprey/measure_views.py [folder holding v22_line_3840.png]

The folder defaults to ~/godotgames-drafts/2026-09-19/cockpit-osprey/research/. The drawing is not in the repo: it is
study material, "Bell Boeing MV-22 Osprey line drawing.svg" by Jetijones on Wikimedia Commons, CC BY 3.0, rendered by
Commons at 3840 px wide, and `sources.md` names its page.

THE SIX VIEWS: a side, a front and a plan, each drawn twice, in AEROPLANE mode (nacelles forward) and HELICOPTER mode
(nacelles up). The PLANS AND FRONTS share one camera: the proprotor
disc, face on in both front views and both plans, is the same number of pixels across in all four. THE SIDES DO NOT: they
are 0.8 per cent shorter than the plans, nose to tail (1,357 px against 1,368). So each is scaled by the published
fuselage length, 17.48 m, over its own nose tip to tail: the sides at 77.63 px a metre, the plans and fronts at 78.26.

THE SILHOUETTE is every pixel NOT connected to the white border by white pixels (a flood fill in numpy, no scipy), so the
closed outlines' white insides count as aircraft.

STATIONS are metres aft of the nose tip (the refuelling probe is ahead of it), HEIGHTS metres over the belly datum (the
side view's flat belly), and OUT metres from the centreline, positive either side.

EDGES ARE FITTED OVER EVERY ROW AND THE RESIDUAL PRINTED, never through two ends (`modelling_here.md` section 3).
"""
import os
import sys

import numpy as np
from PIL import Image

FOLDER = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/godotgames-drafts/2026-09-19/cockpit-osprey/research")
LENGTH_M = 17.48      # Wikipedia, V-22 specifications: 57 ft 4 in
SPAN_M = 13.97        # 45 ft 10 in
WIDTH_M = 25.77       # 84 ft 6.8 in, "including rotors"
ROTOR_M = 11.61       # 38 ft 1 in
HEIGHT_M = 6.73       # 22 ft 1 in, "engine nacelles vertical"
FIN_TOP_M = 5.38      # 17 ft 7.8 in, "to top of tailfins"
WHITE = 200


def outside(white):
    """The white pixels connected to the border, by sweeping each axis both ways until nothing changes."""
    out = np.zeros_like(white)
    out[0, :] = white[0, :]
    out[-1, :] = white[-1, :]
    out[:, 0] = white[:, 0]
    out[:, -1] = white[:, -1]
    while True:
        before = out.sum()
        for axis in (0, 1):
            for flip in (False, True):
                o = np.flip(out, axis) if flip else out
                w = np.flip(white, axis) if flip else white
                o = np.moveaxis(o, axis, 0).copy()
                w = np.moveaxis(w, axis, 0)
                for i in range(1, o.shape[0]):
                    o[i] |= o[i - 1] & w[i]
                o = np.moveaxis(o, 0, axis)
                out = np.flip(o, axis) if flip else o
        if out.sum() == before:
            return out


def runs(indices):
    """Consecutive runs in a sorted index array, as (first, last) pairs."""
    if len(indices) == 0:
        return []
    splits = np.where(np.diff(indices) != 1)[0] + 1
    return [(int(r[0]), int(r[-1])) for r in np.split(indices, splits)]


def fit(rows):
    """Least squares y = a + b x over (x, y) rows: (a, b), rms and worst residual."""
    rows = np.array(rows, dtype=float)
    a_matrix = np.c_[np.ones(len(rows)), rows[:, 0]]
    c, *_ = np.linalg.lstsq(a_matrix, rows[:, 1], rcond=None)
    r = rows[:, 1] - a_matrix @ c
    return c, float(np.sqrt((r ** 2).mean())), float(np.abs(r).max())


def circle(points):
    """The circle through three points: centre and radius."""
    (ax, ay), (bx, by), (cx, cy) = points
    d = 2.0 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
    ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d
    uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d
    return (ux, uy), float(np.hypot(ax - ux, ay - uy))


def main():
    gray = np.asarray(Image.open(os.path.join(FOLDER, "v22_line_3840.png")).convert("LA")).astype(int)
    # Composite the grey-and-alpha render on white.
    g = 255 - ((255 - gray[:, :, 0]) * gray[:, :, 1] // 255)
    sil = ~outside(g >= WHITE)
    report = []

    def say(text):
        report.append(text)
        print(text)

    # ---- the side views -------------------------------------------------------------------------------------------
    sa = sil[0:1100, 0:1900]        # aeroplane mode, nose to the right
    sh = sil[0:1100, 1900:3840]     # helicopter mode, nose to the left
    # THE NOSE TIP is the furthest-forward pixel below the probe (the probe's rows are its own, above the nose's).
    sa_nose = max(np.where(sa[r])[0].max() for r in range(770, 830))
    sa_probe = np.where(sa.any(0))[0].max()
    sa_tail = np.where(sa.any(0))[0].min()
    sh_nose = 1900 + min(np.where(sh[r])[0].min() for r in range(770, 830))
    sh_probe = 1900 + np.where(sh.any(0))[0].min()
    sh_tail = 1900 + np.where(sh.any(0))[0].max()
    # THE BELLY DATUM: the flat belly's row, the median of each column's lowest pixel from 5 to 12 m aft.
    sa_len = sa_nose - sa_tail
    sh_len = sh_tail - sh_nose
    say("side lengths, nose tip to fin trailing edge: aeroplane %d px, helicopter %d px" % (sa_len, sh_len))
    k = sa_len / LENGTH_M
    say("SCALE: %.3f px a metre (%.2f cm a pixel), from the published %.2f m length" % (k, 100.0 / k, LENGTH_M))
    say("probe: %.2f m ahead of the nose tip (aeroplane view), %.2f (helicopter)" % (
        (sa_probe - sa_nose) / k, (sh_nose - sh_probe) / k))

    def belly(view, nose, sign):
        cols = [int(nose - sign * s * k) for s in np.arange(5.0, 12.0, 0.25)]
        return float(np.median([np.where(view[:, c - (0 if sign > 0 else 1900)])[0].max() for c in cols]))
    sa_belly = belly(sa, sa_nose, 1)
    sh_belly = belly(sh, sh_nose, -1)
    say("belly datum: row %.0f (aeroplane view), %.0f (helicopter)" % (sa_belly, sh_belly))

    # ---- the plans ------------------------------------------------------------------------------------------------
    pa = sil[2100:4304, 0:1900]
    ph = sil[2100:4304, 1900:3840]
    # The plan's nose tip: the furthest-forward pixel near the centreline row, the probe excepted (it is to starboard).
    pa_cols = np.where(pa.any(0))[0]
    pa_tail = pa_cols.min()
    ph_cols = np.where(ph.any(0))[0]
    ph_tail = 1900 + ph_cols.max()
    # CENTRELINE: the middle of the fuselage's width at 12 to 14 m aft, where nothing else is beside it.
    def plan_centre(view, nose_col, sign, offset):
        mids = []
        for s in np.arange(12.5, 14.0, 0.1):
            c = int(round(nose_col - sign * s * k)) - offset
            rr = runs(np.where(view[:, c])[0])
            body = max(rr, key=lambda r: r[1] - r[0])
            mids.append((body[0] + body[1]) * 0.5)
        return float(np.median(mids))
    # First guess of the nose from the sides' length; refined on the centreline row.
    pa_nose = pa_tail + sa_len
    pa_mid = plan_centre(pa, pa_nose, 1, 0)
    pa_nose = max(np.where(pa[int(pa_mid) + d])[0].max() for d in range(-25, 26))
    ph_nose = ph_tail - sa_len
    ph_mid = plan_centre(ph, ph_nose, -1, 1900)
    ph_nose = 1900 + min(np.where(ph[int(ph_mid) + d])[0].min() for d in range(-25, 26))
    say("plan lengths, nose tip to tail: aeroplane %d px (%.3f m), helicopter %d px (%.3f m)" % (
        pa_nose - pa_tail, (pa_nose - pa_tail) / k, ph_tail - ph_nose, (ph_tail - ph_nose) / k))
    say("plan centreline rows: aeroplane %.1f, helicopter %.1f" % (2100 + pa_mid, 2100 + ph_mid))
    # THE PLANS ARE DRAWN 0.8 PER CENT LONGER THAN THE SIDES, so each is scaled by the published length on its own.
    kp = (pa_nose - pa_tail) / LENGTH_M
    say("THE PLANS' SCALE: %.3f px a metre (%+.2f per cent on the sides'). The FRONTS share the plans' camera -- the"
        " proprotor disc is the same size in pixels in all four face-on views, below -- so they are read at it too" % (
            kp, (kp / k - 1.0) * 100.0))

    # ---- the fronts ------------------------------------------------------------------------------------------------
    front = sil[1100:2100, :]
    # Each front view's centreline: the middle of its fuselage between 0.3 and 1.5 m under the fins' roots, found as
    # the widest run near each view's middle.
    def front_centre(c_from, c_to):
        mids = []
        for r in range(760, 800):
            rr = [x for x in runs(np.where(front[r, c_from:c_to])[0] + c_from)]
            body = max(rr, key=lambda x: x[1] - x[0])
            mids.append((body[0] + body[1]) * 0.5)
        return float(np.median(mids))
    fa_mid = front_centre(700, 1400)
    fh_mid = front_centre(2500, 3200)
    # The front belly: the lowest pixel within 0.8 m of the centreline.
    fa_belly = max(np.where(front[:, c])[0].max() for c in range(int(fa_mid - 0.8 * kp), int(fa_mid + 0.8 * kp)))
    fh_belly = max(np.where(front[:, c])[0].max() for c in range(int(fh_mid - 0.8 * kp), int(fh_mid + 0.8 * kp)))
    say("front centrelines: aeroplane col %.1f, helicopter col %.1f; bellies rows %d, %d" % (
        fa_mid, fh_mid, 1100 + fa_belly, 1100 + fh_belly))

    # ---- one camera? the fins -------------------------------------------------------------------------------------
    # THE FIN TOP over the belly, side against front.
    sa_fin_top = np.where(sa[:, sa_tail:sa_tail + int(1.5 * k)].any(1))[0].min()
    sh_fin_top = np.where(sh[:, sh_tail - 1900 - int(1.5 * k):sh_tail - 1900].any(1))[0].min()
    say("fin top over the belly, side views: %.3f m, %.3f m" % ((sa_belly - sa_fin_top) / k, (sh_belly - sh_fin_top) / k))
    # In the front views the fins are the two thin uprights either side; their tops.
    def fin_tops(mid):
        tops = []
        for side in (-1, 1):
            c_lo, c_hi = sorted((int(mid + side * 1.8 * kp), int(mid + side * 3.6 * kp)))
            cols = [c for c in range(c_lo, c_hi) if front[:, c].any()]
            # the fin is the column band whose top is highest in this range but below the rotor's blades
            best = None
            for c in cols:
                rr = runs(np.where(front[:, c])[0])
                # the run reaching the tailplane (within 1.2 m over the fuselage top)
                for a, b in rr:
                    if b - a > 0.8 * kp and b > (fa_belly if mid < 1920 else fh_belly) - 3.5 * kp:
                        if best is None or a < best[0]:
                            best = (a, c)
            tops.append(best)
        return tops
    for label, mid, bel in (("aeroplane", fa_mid, fa_belly), ("helicopter", fh_mid, fh_belly)):
        tops = fin_tops(mid)
        say("fin tops over the belly, %s front view: %s" % (label, ", ".join(
            "%.3f m at %.3f m out" % ((bel - t[0]) / kp, abs(t[1] - mid) / kp) for t in tops if t)))

    tables(g, k, kp, say, sil, sa, sh, sa_nose, sa_belly, sh_nose, sh_belly, pa, pa_nose, pa_mid, pa_tail, ph_mid,
           front, fa_mid, fa_belly, fh_mid, fh_belly)
    ground_line(say)


def component(solid, seed):
    """The connected run of SOLID (thick black) pixels nearest `seed` (x, y): one rotor's hub and blades."""
    x0, y0 = seed
    ys, xs = np.where(solid[y0 - 60:y0 + 60, x0 - 60:x0 + 60])
    i = int(np.argmin(np.hypot(xs - 60, ys - 60)))
    start = (y0 - 60 + int(ys[i]), x0 - 60 + int(xs[i]))
    seen = np.zeros_like(solid)
    seen[start] = True
    frontier = [start]
    while frontier:
        nxt = []
        for y, x in frontier:
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (y + dy, x + dx)
                if solid[n] and not seen[n]:
                    seen[n] = True
                    nxt.append(n)
        frontier = nxt
    ys, xs = np.where(seen)
    return xs, ys


def rotor_disc(solid, ink, seed):
    """A rotor seen FACE ON: the circle through its three blade tips. The blades are found on the ink eroded by six
    pixels, so only the filled blades survive and the outlines do not; each tip is then walked back out along its own
    ray to the last inked pixel, so the erosion does not shorten the blade. Returns the centre and radius in pixels."""
    xs, ys = component(solid, seed)
    hx, hy = seed
    d = np.hypot(xs - hx, ys - hy)
    ang = np.arctan2(ys - hy, xs - hx)
    tips = []
    for i in np.argsort(-d):
        if all(abs(np.angle(np.exp(1j * (ang[i] - t[2])))) > 1.0 for t in tips):
            tips.append((float(xs[i]), float(ys[i]), float(ang[i])))
        if len(tips) == 3:
            break
    (ux, uy), _ = circle([(x, y) for x, y, _a in tips])
    walked = []
    for x, y, _a in tips:
        direction = np.array([x - ux, y - uy]) / np.hypot(x - ux, y - uy)
        p = np.array([x, y])
        while ink[int(round(p[1] + direction[1])), int(round(p[0] + direction[0]))]:
            p = p + direction
        walked.append((p[0], p[1]))
    (ux, uy), r = circle(walked)
    return ux, uy, r


def tables(g, k, kp, say, sil, sa, sh, sa_nose, sa_belly, sh_nose, sh_belly, pa, pa_nose, pa_mid, pa_tail, ph_mid,
           front, fa_mid, fa_belly, fh_mid, fh_belly):
    ink = g < 128
    solid = ink.copy()
    for _ in range(6):
        solid = solid & np.roll(solid, 1, 0) & np.roll(solid, -1, 0) & np.roll(solid, 1, 1) & np.roll(solid, -1, 1)

    # ---- the rotors ------------------------------------------------------------------------------------------------
    say("\n== THE PROPROTORS, face on (the front view in aeroplane mode, the plan in helicopter mode)")
    discs = []
    fa_hub_h = []
    for label, seed, scale, across in (("front, port", (488, 1608), kp, True),
                                       ("front, starboard", (1568, 1608), kp, True),
                                       ("plan, one", (2848, 2640), kp, False),
                                       ("plan, other", (2840, 3760), kp, False)):
        ux, uy, r = rotor_disc(solid, ink, seed)
        discs.append(2.0 * r / scale)
        if across:
            fa_hub_h.append((1100 + fa_belly - uy) / scale)
            say("  %-16s diameter %.3f m; hub %.3f m out, %.3f m over the belly" % (
                label, 2.0 * r / scale, abs(ux - fa_mid) / scale, (1100 + fa_belly - uy) / scale))
        else:
            say("  %-16s diameter %.3f m; hub %.3f m out" % (label, 2.0 * r / scale, abs(uy - 2100 - ph_mid) / scale))
    say("  mean diameter %.3f m against the published %.2f (%+.2f per cent)" % (
        np.mean(discs), ROTOR_M, (np.mean(discs) / ROTOR_M - 1.0) * 100.0))
    hub_h = float(np.mean(fa_hub_h))

    # THE HELICOPTER-MODE HUB from the side: the spinner's top and the blades' plane beside it.
    top_row = np.where(sh.any(1))[0].min()
    top_cols = np.where(sh[top_row])[0] + 1900
    hub_s = (top_cols.mean() - sh_nose) / k
    spinner_top = (sh_belly - top_row) / k
    blades, blade_tops = [], []
    for s in list(np.arange(hub_s - 2.5, hub_s - 1.4, 0.1)) + list(np.arange(hub_s + 1.4, hub_s + 2.5, 0.1)):
        c = int(round(sh_nose + s * k)) - 1900
        rr = [r for r in runs(np.where(sh[:, c])[0]) if (sh_belly - r[1]) / k > 5.0]
        if rr:
            blades.append(((sh_belly - rr[0][0]) / k + (sh_belly - rr[0][1]) / k) * 0.5)
    for c in range(0, sh.shape[1]):
        rr = [r for r in runs(np.where(sh[:, c])[0]) if (sh_belly - r[1]) / k > 5.0]
        if rr and abs((c + 1900 - sh_nose) / k - hub_s) > 4.5:
            blade_tops.append((sh_belly - rr[0][0]) / k)
    blade_plane = float(np.median(blades))
    front_top = np.where(front[:, 1920:].any(1))[0].min()
    say("  helicopter mode, side: rotor axis at station %.3f, spinner top %.3f m over the belly, blade plane %.3f"
        " (the blade's middle, %d columns 1.4 to 2.5 m either side of the axis), outer blades' top %.3f" % (
            hub_s, spinner_top, blade_plane, len(blades), max(blade_tops)))
    say("  helicopter mode, front: spinner top %.3f m over the belly" % ((fh_belly - front_top) / kp))
    # THE AEROPLANE-MODE HUB: the front view's disc centre for the height, the plan's blade band for the station.
    band = []
    for x in np.arange(3.0, 6.0, 0.2):
        for side in (-1, 1):
            row = int(round(pa_mid + side * x * kp))
            rr = [r for r in runs(np.where(pa[row, :])[0]) if 3.5 < (pa_nose - r[1]) / kp < 4.8]
            if rr:
                band.append(((pa_nose - rr[0][1]) / kp + (pa_nose - rr[0][0]) / kp) * 0.5)
    hub_sa = float(np.median(band))
    spinner_tip = min((pa_nose - np.where(pa[int(pa_mid + side * 7.1 * kp) + d])[0].max()) / kp
                      for side in (-1, 1) for d in range(-6, 7))
    say("  aeroplane mode: blade plane at station %.3f (plan, median of %d rows), hub %.3f m over the belly (front),"
        " spinner tip at station %.3f" % (hub_sa, len(band), hub_h, spinner_tip))
    # THE CONVERSION AXIS: the point a quarter turn nose-up carries the aeroplane hub onto the helicopter one.
    ps = (hub_s - hub_h + blade_plane + hub_sa) * 0.5
    pv = (blade_plane + hub_sa - hub_s + hub_h) * 0.5
    say("  CONVERSION AXIS: station %.3f, %.3f m over the belly. Pivot to the blade plane %.3f m (aeroplane), %.3f"
        " (helicopter); to the spinner tip %.3f (aeroplane), top %.3f (helicopter)" % (
            ps, pv, ps - hub_sa, blade_plane - pv, ps - spinner_tip, spinner_top - pv))

    # ---- the fuselage, side ----------------------------------------------------------------------------------------
    say("\n== THE FUSELAGE'S SIDE PROFILE: top and bottom over the belly, from the helicopter-mode side view (the"
        " aeroplane one where the vertical nacelle stands in front of it)")
    for s in np.arange(0.0, 17.49, 0.25):
        c = int(round(sh_nose + s * k)) - 1900
        body = runs(np.where(sh[:, c])[0])[-1:]
        datum, source = sh_belly, "heli"
        if not body or (sh_belly - body[0][0]) / k > 4.0:
            c = int(round(sa_nose - s * k))
            body = runs(np.where(sa[:, c])[0])[-1:]
            datum, source = sa_belly, "aero"
        if body:
            say("  s %5.2f  top %5.2f  bottom %5.2f  (%s)" % (s, (datum - body[0][0]) / k, (datum - body[0][1]) / k,
                                                            source))

    # ---- the fuselage, plan ----------------------------------------------------------------------------------------
    say("\n== THE PLAN'S HALF-WIDTH of the run holding the centreline (aeroplane-mode plan, its own scale)")
    for s in np.arange(0.0, 17.49, 0.25):
        c = int(round(pa_nose - s * kp))
        rr = [r for r in runs(np.where(pa[:, c])[0]) if r[0] <= pa_mid <= r[1]]
        if rr:
            say("  s %5.2f  one side %5.2f  other %5.2f" % (s, (pa_mid - rr[0][0]) / kp, (rr[0][1] - pa_mid) / kp))

    # ---- the fuselage, front ---------------------------------------------------------------------------------------
    say("\n== THE FRONT VIEW'S HALF-WIDTH at each height, the run holding the centreline (aeroplane mode)")
    for h in np.arange(0.05, 3.5, 0.1):
        r = int(round(fa_belly - h * kp))
        lo = int(fa_mid - 4 * kp)
        rr = [x for x in runs(np.where(front[r, lo:int(fa_mid + 4 * kp)])[0] + lo) if x[0] <= fa_mid <= x[1]]
        if rr:
            say("  h %4.2f  one side %5.2f  other %5.2f" % (h, (fa_mid - rr[0][0]) / kp, (rr[0][1] - fa_mid) / kp))

    # ---- the wing --------------------------------------------------------------------------------------------------
    say("\n== THE WING in plan (aeroplane mode): leading and trailing edges over 2.6 to 6.2 m out, both sides")
    le, te = [], []
    for x in np.arange(2.6, 6.21, 0.05):
        for side in (-1, 1):
            row = int(round(pa_mid + side * x * kp))
            rr = [r for r in runs(np.where(pa[row, :])[0]) if (pa_nose - r[1]) / kp > 4.9 and (pa_nose - r[0]) / kp < 9.5]
            if rr:
                le.append((x, (pa_nose - rr[0][1]) / kp))
                te.append((x, (pa_nose - rr[0][0]) / kp))
    (a, b), rms, worst = fit(le)
    say("  leading edge: station %.3f %+.4f x out, %d rows, %.1f mm rms, %.1f worst: swept %.2f degrees FORWARD" % (
        a, b, len(le), rms * 1000, worst * 1000, -np.degrees(np.arctan(b))))
    (a2, b2), rms, worst = fit(te)
    say("  trailing edge: station %.3f %+.4f x out, %d rows, %.1f mm rms, %.1f worst" % (
        a2, b2, len(te), rms * 1000, worst * 1000))
    say("  chord %.3f m at 2.6 m out, %.3f at 6.2" % ((a2 + b2 * 2.6) - (a + b * 2.6), (a2 + b2 * 6.2) - (a + b * 6.2)))
    tops, bottoms = [], []
    for x in np.arange(3.0, 6.01, 0.05):
        for side in (-1, 1):
            c = int(round(fh_mid + side * x * kp))
            rr = [r for r in runs(np.where(front[:, c])[0]) if 2.6 < (fh_belly - r[1]) / kp < 3.4]
            if rr:
                tops.append((x, (fh_belly - rr[0][0]) / kp))
                bottoms.append((x, (fh_belly - rr[0][1]) / kp))
    (at, bt), rms_t, _ = fit(tops)
    (ab, bb), rms_b, _ = fit(bottoms)
    say("  front view (helicopter mode, no blades across it): top %.3f %+.4f x out (%.1f mm rms), bottom %.3f %+.4f x"
        " out (%.1f mm rms): DIHEDRAL %.2f degrees, %.3f m deep" % (
            at, bt, rms_t * 1000, ab, bb, rms_b * 1000, np.degrees(np.arctan((bt + bb) * 0.5)), at - ab))

    # ---- the nacelle -----------------------------------------------------------------------------------------------
    say("\n== THE NACELLE, helicopter mode: its extent along the fuselage (side) and across (front) at each height")
    for h in np.arange(0.8, 7.0, 0.2):
        r = int(round(sh_belly - h * k))
        along = [((a - sh_nose) / k, (b - sh_nose) / k) for a, b in runs(np.where(sil[r, 1900:])[0] + 1900)
                 if 4.0 < (a - sh_nose) / k < 9.5 or 4.0 < (b - sh_nose) / k < 9.5]
        rf = int(round(fh_belly - h * kp))
        lo = int(fh_mid + 5.5 * kp)
        across = [((a - fh_mid) / kp, (b - fh_mid) / kp) for a, b in runs(np.where(front[rf, lo:])[0] + lo)]
        say("  h %4.2f  along %s  across %s" % (h, " ".join("%.2f-%.2f" % x for x in along),
                                              " ".join("%.2f-%.2f" % x for x in across)))

    # ---- the tail --------------------------------------------------------------------------------------------------
    say("\n== THE TAIL: the fins in side view, their outline by height (aeroplane-mode side)")
    for h in np.arange(1.4, 5.3, 0.2):
        r = int(round(sa_belly - h * k))
        rr = [((sa_nose - b) / k, (sa_nose - a) / k) for a, b in runs(np.where(sa[r])[0]) if (sa_nose - a) / k > 14.5]
        say("  h %4.2f  %s" % (h, " ".join("%.2f-%.2f" % x for x in rr)))
    say("  across, front view (aeroplane mode), by height:")
    for h in np.arange(1.5, 5.1, 0.25):
        r = int(round(fa_belly - h * kp))
        lo = int(fa_mid - 3.2 * kp)
        rr = [((a - fa_mid) / kp, (b - fa_mid) / kp) for a, b in runs(np.where(front[r, lo:int(fa_mid + 3.2 * kp)])[0] + lo)]
        say("  h %4.2f  %s" % (h, " ".join("%.2f:%.2f" % x for x in rr)))
    say("  in plan, by station:")
    for s in np.arange(14.5, 17.5, 0.25):
        c = int(round(pa_nose - s * kp))
        rr = [((a - pa_mid) / kp, (b - pa_mid) / kp) for a, b in runs(np.where(pa[:, c])[0])]
        say("  s %5.2f  %s" % (s, " ".join("%.2f:%.2f" % x for x in rr)))

    # ---- the flight deck's glazing ---------------------------------------------------------------------------------
    say("\n== THE FLIGHT DECK'S GLAZING, the drawing's filled black panes in the aeroplane-mode side view")
    ys, xs = np.where(solid[600:900, 1300:1560])
    ys = ys + 600
    xs = xs + 1300
    for y in range(int(ys.min()), int(ys.max()) + 1, 6):
        row = np.sort(xs[ys == y])
        if len(row):
            say("  h %4.2f  %s" % ((sa_belly - y) / k, " ".join(
                "%.2f-%.2f" % ((sa_nose - b) / k, (sa_nose - a) / k) for a, b in runs(row))))


def ground_line(say):
    """THE ONE DRAWING WITH A GROUND LINE: the V-22 Program Office side view on page 97 of the Naval Postgraduate School
    thesis "The V-22 tilt rotor, a comparison with existing Coast Guard aircraft" (Commons, public domain), rendered at
    300 dpi as nps_cg_page110.png. A poor scan: it gives the belly's clearance and ratios, nothing finer."""
    path = os.path.join(FOLDER, "nps_cg_page110.png")
    if not os.path.exists(path):
        say("\n(no %s: the ground line is not re-measured)" % path)
        return
    im = np.asarray(Image.open(path).convert("L")).astype(int)[1180:1530, 960:1650]
    dark = im < 140
    counts = dark.sum(1)
    ground = int(np.median([r for r in range(240, 280) if counts[r] > 400]))
    dims = [r for r in range(300, 330) if counts[r] > 300]
    dim_row = dims[len(dims) // 2]
    cols = np.where(dark[dim_row])[0]
    length_px = int(cols.max() - cols.min())
    top_row = float(np.mean([r for r in range(60, 90) if counts[r] > 200 and np.where(dark[r])[0].min() < 40]))
    kn = length_px / LENGTH_M
    belly = []
    for x in range(180, 420, 10):
        col = np.where(im[150:ground - 2, x] < 150)[0]
        belly.append(ground - (150 + int(col.max())))
    # The fin's height dimension: its upper extension line, the dark row right of the fin at 540 to 600 px.
    fin = [r for r in range(100, 130) if dark[r, 545:600].sum() > 30]
    say("\n== THE GROUND LINE (Program Office side view, NPS thesis p. 97, public domain; helicopter mode)")
    say("  length dimension %d px: %.2f px a metre; ground at row %d" % (length_px, kn, ground))
    say("  belly over the ground: %.2f m (median of %d columns from 3.8 to 12.8 m aft)" % (
        np.median(belly) / kn, len(belly)))
    say("  height dimension's top %.2f m over the ground; fin's %.2f. The page prints 22 ft 7 in (6.88 m) for the"
        " height; read at its own printed height the scan's vertical scale is %.3f of its horizontal" % (
            (ground - top_row) / kn, (ground - np.mean(fin)) / kn, 6.88 / ((ground - top_row) / kn)))
    say("  the ratio the scan's stretch cannot move: height over fin %.3f (published 6.88 / 5.38 = %.3f, 6.73 / 5.38"
        " = %.3f)" % ((ground - top_row) / (ground - np.mean(fin)), 6.88 / 5.38, 6.73 / 5.38))


if __name__ == "__main__":
    main()
