"""Re-derive every MEASURED number in research-prowler.md from the SAC three-view.

Run it in this folder with sac-ea6b-3view.png beside it:

    python measure_sac.py

It writes sac_derotated.png and prints the page rotation, each view's scale, whether the
plan view is isotropic, the ground rake, and the fin top. Nothing here is a number typed from the research
file: every figure is computed, so a disagreement with the file is a real disagreement.
"""

from PIL import Image
import numpy as np
import math

SRC = "sac-ea6b-3view.png"
DEROT = "sac_derotated.png"


def hough(ink, xlo, xhi, ylo, yhi, alo=-4.0, ahi=4.0, step=0.02):
    """The longest near-straight line in a window: (count, angle_degrees, offset)."""
    ys, xs = np.nonzero(ink)
    m = (xs >= xlo) & (xs < xhi) & (ys >= ylo) & (ys < yhi)
    x = xs[m].astype(float)
    y = ys[m].astype(float)
    best = (0, 0.0, 0.0)
    for ang in np.arange(alo, ahi + 1e-9, step):
        b = y - math.tan(math.radians(ang)) * (x - xlo)
        h, edges = np.histogram(b, bins=np.arange(ylo, yhi + 1, 1.0))
        k = np.convolve(h, [1, 1, 1], mode="same")
        i = int(k.argmax())
        if k[i] > best[0]:
            best = (int(k[i]), float(ang), float(edges[i]))
    return best


def runs_along(ink, ang, b0, xlo, xhi, tol=2.5, gap=6):
    """Contiguous runs of ink along a line, so a dimension broken by its text still reads."""
    s = math.tan(math.radians(ang))
    cols = [x for x in range(xlo, xhi)
            if ink[int(round(b0 + s * (x - xlo) - tol)):
                   int(round(b0 + s * (x - xlo) + tol)) + 1, x].any()]
    out = []
    start = prev = cols[0]
    for c in cols[1:]:
        if c - prev > gap:
            out.append((start, prev))
            start = c
        prev = c
    out.append((start, prev))
    return out


def circle_fit(points):
    """Least-squares circle through ink points: (cx, cy, r)."""
    x = points[:, 0].astype(float)
    y = points[:, 1].astype(float)
    a = np.column_stack([x, y, np.ones_like(x)])
    sol, *_ = np.linalg.lstsq(a, x * x + y * y, rcond=None)
    cx = sol[0] / 2.0
    cy = sol[1] / 2.0
    return cx, cy, math.sqrt(sol[2] + cx * cx + cy * cy)


def main() -> None:
    page = Image.open(SRC).convert("L")

    # (a) THE PAGE ROTATION, off four printed dimension lines.
    raw = np.array(page) < 128
    angles = [hough(raw, 300, 1100, 0, 60)[1],          # plan, the 244 in tailplane span
              hough(raw, 150, 1200, 1090, 1160)[1],     # front, the 636 in span
              hough(raw, 300, 1100, 1140, 1200)[1],     # front, the 299 in folded span
              hough(raw, 100, 1250, 1560, 1650)[1]]     # side, the 709 in length
    turn = float(np.mean(angles))
    print("page rotation from four dimension lines: %s -> %+.2f degrees"
          % (["%+.2f" % a for a in angles], turn))
    page.rotate(turn, resample=Image.BICUBIC, fillcolor=255).save(DEROT)
    ink = np.array(Image.open(DEROT)) < 128
    print("after de-rotation the same four read: %s"
          % ["%+.2f" % hough(ink, *w)[1] for w in
             [(300, 1100, 0, 60), (150, 1200, 1090, 1160),
              (300, 1100, 1140, 1200), (100, 1250, 1560, 1650)]])

    # (b) EACH VIEW'S SCALE, between the ends of its printed dimension.
    def span_of(ang, b0, xlo, xhi):
        r = runs_along(ink, ang, b0, xlo, xhi)
        return min(a for a, _ in r), max(b for _, b in r)

    lo, hi = span_of(0.05, 1121, 150, 1200)
    front_636 = (hi - lo) / 636.0
    lo2, hi2 = span_of(0.05, 1169, 300, 1100)
    front_299 = (hi2 - lo2) / 299.0
    print("front view: 636 in over %d px = %.4f px/in; 299 in over %d px = %.4f px/in"
          % (hi - lo, front_636, hi2 - lo2, front_299))
    print("            its centreline from each: x=%.1f and x=%.1f"
          % ((lo + hi) / 2.0, (lo2 + hi2) / 2.0))

    # The side view's length, between its two vertical extension lines.
    def vline(xlo, xhi, ylo, yhi, minlen):
        w = [(x, ink[ylo:yhi, x].sum()) for x in range(xlo, xhi)]
        w = [p for p in w if p[1] >= minlen]
        return sum(x * n for x, n in w) / sum(n for _, n in w)

    nose_x = vline(170, 190, 1600, 1960, 60)
    tail_x = vline(1215, 1230, 1560, 2000, 100)
    side_len = (tail_x - nose_x) / 709.0
    print("side view: 709 in over %.1f px (x=%.1f to %.1f) = %.4f px/in"
          % (tail_x - nose_x, nose_x, tail_x, side_len))

    # The plan view's span, between the drawn wingtips. The NAVAL AIR SYSTEMS COMMAND title
    # sits at the same height as the tailplane and has to go, or it reads as a 690 px
    # tailplane.
    plan = ink.copy()
    plan[:60, :] = False
    plan[1080:, :] = False
    plan[:, :150] = False
    plan[790:1080, 800:] = False
    plan[55:90, :460] = False
    widest = max(((np.where(plan[y])[0].max() - np.where(plan[y])[0].min(), y)
                  for y in range(400, 600) if plan[y].any()))
    row = np.where(plan[widest[1]])[0]
    plan_span = (row.max() - row.min()) / 636.0
    centre = (row.min() + row.max()) / 2.0
    tail = max(((np.where(plan[y])[0].max() - np.where(plan[y])[0].min(), y)
                for y in range(60, 220) if plan[y].any()))
    print("plan view: 636 in over %d px (row y=%d) = %.4f px/in, centreline x=%.1f"
          % (widest[0], widest[1], plan_span, centre))
    print("           its own printed 244 in tailplane span over %d px = %.4f px/in"
          % (tail[0], tail[0] / 244.0))

    # (c) IS THE PLAN VIEW ISOTROPIC? The printed wing area and MAC answer, and neither of
    # them went into any view's length. Fit the chord over EVERY clean station, not its two
    # ends: a two-point fit put the tip chord 9 in short and made a wrong answer look proved.
    chords = []
    for x in list(range(200, 470, 5)) + list(range(870, 1140, 5)):
        col = np.where(plan[350:800, x])[0] + 350
        if len(col) == 0:
            continue
        out = abs(x - centre) / plan_span
        if 160.0 <= out <= 303.0:
            chords.append((out, float(col.max() - col.min())))
    out = np.array([c[0] for c in chords])
    ch = np.array([c[1] for c in chords])
    taper, root_px = np.polyfit(out, ch, 1)
    rms = float((ch - (taper * out + root_px)).std())
    half = 636.0 / 2.0
    tip_px = root_px + taper * half
    lam = tip_px / root_px
    root = root_px / plan_span
    area = (root + tip_px / plan_span) * half
    mac = (2.0 / 3.0) * root * (1 + lam + lam * lam) / (1 + lam)
    print("outer wing over %d stations, residual %.1f px rms: root %.1f in, tip %.1f in, taper %.3f"
          % (len(chords), rms, root, tip_px / plan_span, lam))
    print("  at the plan view's OWN span scale: area %.1f sq ft against the printed 528.9,"
          " MAC %.1f in against the printed 130.8" % (area / 144.0, mac))
    band = plan[:, int(centre) - 14:int(centre) + 14].any(axis=1)
    rr = np.where(band)[0]
    print("  so it is isotropic -- and yet it draws the aeroplane %.1f in long (radome tip"
          " y=%d to rudder trailing edge y=%d) against the side view's printed 709. NOT SETTLED."
          % ((rr.max() - rr.min()) / plan_span, rr.max(), rr.min()))

    # (d) THE GROUND RAKE, as the lower common tangent to the two printed-diameter tyres.
    def tyre(xlo, xhi, ylo, yhi):
        sub = ink[ylo:yhi, xlo:xhi]
        pts = np.column_stack(np.nonzero(sub)[::-1]).astype(float)
        pts[:, 0] += xlo
        pts[:, 1] += ylo
        cx, cy, r = circle_fit(pts)
        keep = np.abs(np.hypot(pts[:, 0] - cx, pts[:, 1] - cy) - r) < 4.0
        return circle_fit(pts[keep])

    nose = tyre(378, 409, 2028, 2059)
    main = tyre(665, 722, 1972, 2028)
    print("nose tyre centre (%.1f, %.1f) r=%.1f px -> %.1f in diameter against the printed 20"
          % (nose[0], nose[1], nose[2], 2 * nose[2] / side_len))
    print("main tyre centre (%.1f, %.1f) r=%.1f px -> %.1f in diameter against the printed 36"
          % (main[0], main[1], main[2], 2 * main[2] / side_len))
    dx = main[0] - nose[0]
    dy = main[1] - nose[1]
    dr = main[2] - nose[2]
    m = -0.10
    for _ in range(200):                      # the lower common tangent y = m x + c
        m -= (m * dx - dy - dr * math.sqrt(m * m + 1)) / (dx - dr * m / math.sqrt(m * m + 1)) * 0.5
    rake = math.degrees(math.atan(-m))
    print("lower common tangent to both tyres: %.2f degrees of ground rake" % rake)
    print("the two printed lengths say: cos-1(709/712.5) = %.2f degrees"
          % math.degrees(math.acos(709.0 / 712.5)))
    print("wheelbase between the tyre centres: %.1f in along the ground, printed 206.11"
          % (dx / side_len / math.cos(math.radians(rake))))
    print("nose tyre bottom below the main tyres' in the level frame: %.1f in = %.2f m"
          % (((nose[1] + nose[2]) - (main[1] + main[2])) / side_len,
             ((nose[1] + nose[2]) - (main[1] + main[2])) / side_len * 0.0254))

    # (e) THE FIN TOP, which is what says the side view needs no separate height scale.
    fin = ink.copy()
    for ang, b0, x0 in [(-6.26, 1743, 350), (-6.88, 1688, 350)]:   # the folded-wing leaders
        sl = math.tan(math.radians(ang))
        for x in range(fin.shape[1]):
            y = b0 + sl * (x - x0)
            fin[max(0, int(y - 5)):int(y + 6), x] = False
    grad = -m
    intercept = nose[1] + nose[2] * math.sqrt(grad * grad + 1) + grad * nose[0]
    tops = []
    for x in range(1090, 1186, 2):   # the fin TIP only: its leading edge is still climbing before 1090
        col = np.where(fin[1640:1900, x])[0] + 1640
        if len(col):
            tops.append((intercept - grad * x - col.min()) / side_len)
    print("fin top over the ground line: %.1f in against the printed 195"
          % float(np.median(tops)))


if __name__ == "__main__":
    main()
