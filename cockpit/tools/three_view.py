"""Tools for measuring an aeroplane off a scanned or drawn three-view, shared by the warbirds' `craft/<kind>/`
measure and overlay scripts (lane/warbirds, 2026-09-19). The P-51's scripts carry their own copies of the first four;
these are the same functions, lifted out when the second drawing needed them.

- `solid` is a view's silhouette: everything the border's white cannot reach, then only the part holding a seed. A
  1-bit scan's outlines have GAPS (NACA RM L8A06's P-47 side view leaked into its fuselage through three), so `solid`
  can CLOSE them first: the ink is grown by `close` px before the fill and the silhouette shrunk back by as much after,
  which keeps its edge where the ink's outer edge was.
- `take_out` erases a straight line (a dimension, extension or ground line) between two hand-picked ends, before the fill.
- `circle` fits a circle to the ink in a box by a centre search and a least-squares fit.
- `fit` is a straight line over every row with its residual, never through two ends (`modelling_here.md` section 3).
"""
import numpy as np


def sweep(allowed, seed):
    """The `allowed` pixels connected to `seed` (a boolean array), sweeping each axis both ways until nothing grows."""
    out = seed & allowed
    while True:
        before = out.sum()
        for axis in (0, 1):
            for flip in (False, True):
                o = np.flip(out, axis) if flip else out
                w = np.flip(allowed, axis) if flip else allowed
                o = np.moveaxis(o, axis, 0).copy()
                w = np.moveaxis(w, axis, 0)
                for i in range(1, o.shape[0]):
                    o[i] |= o[i - 1] & w[i]
                o = np.moveaxis(o, 0, axis)
                out = np.flip(o, axis) if flip else o
        if out.sum() == before:
            return out


def grow(mask, k):
    """`mask` grown by a disc of radius `k` px."""
    out = mask.copy()
    for dy in range(-k, k + 1):
        for dx in range(-k, k + 1):
            if dy * dy + dx * dx <= k * k:
                out |= np.roll(np.roll(mask, dy, 0), dx, 1)
    return out


def shrink(mask, k):
    return ~grow(~mask, k)


def solid(ink, box, seed, close=0, fence=None, holes=()):
    """A view's silhouette inside `box` (row0, row1, col0, col1), in the box's own pixels: everything the border's white
    cannot reach, the ink first grown by `close` px and the result shrunk back by as much, then only the part that
    holds `seed` (a sheet row, col). `fence` is a hull's points (sheet col, row): ink outside it is taken out first.
    `holes` are sheet (row, col) points in white the aeroplane ENCLOSES that are still outside it -- the P-38's booms,
    tailplane and wing close a ring round the space between the booms, which no fill from the border reaches.
    Returns (silhouette, every solid part)."""
    r0, r1, c0, c1 = box
    part = ink[r0:r1, c0:c1].copy()
    if fence is not None:
        part &= hull(part.shape, fence, (r0, c0))
    if close:
        part = grow(part, close)
    white = ~part
    border = np.zeros_like(white)
    border[0, :] = border[-1, :] = True
    border[:, 0] = border[:, -1] = True
    for r, c in holes:
        border[r - r0, c - c0] = True
    body = ~sweep(white, border)
    if close:
        body = shrink(body, close)
    at = np.zeros_like(body)
    at[seed[0] - r0, seed[1] - c0] = True
    return sweep(body, at), body


def take_out(ink, start, end, keep=0, width=2.5):
    """Erase the ink within `width` px of the straight line from `start` to `end` (row, col), `keep` px short of each end."""
    (r0, c0), (r1, c1) = start, end
    d = np.array([r1 - r0, c1 - c0], dtype=float)
    length = np.hypot(*d)
    d /= length
    rows, cols = np.mgrid[min(r0, r1) - 6:max(r0, r1) + 7, min(c0, c1) - 6:max(c0, c1) + 7]
    rel_r = rows - r0
    rel_c = cols - c0
    along = rel_r * d[0] + rel_c * d[1]
    off = np.abs(rel_r * d[1] - rel_c * d[0])
    cut = (off <= width) & (along > keep) & (along < length - keep)
    ok = (rows >= 0) & (rows < ink.shape[0]) & (cols >= 0) & (cols < ink.shape[1])
    ink[rows[cut & ok], cols[cut & ok]] = False


def hull(shape, points, origin=(0, 0)):
    """A HULL: the inside of the polygon `points` (sheet col, row) as a mask of `shape`, whose top-left is the sheet's
    `origin` (row, col). Drawn by hand a little outside the aeroplane, it is what keeps a dimension line from closing a
    region against the outline: everything outside it is taken out before the fill (NACA RM L8A06's P-47 sheet, whose
    dimension lines closed the plan's whole space between wing and tail)."""
    from PIL import Image, ImageDraw
    img = Image.new("L", (shape[1], shape[0]), 0)
    ImageDraw.Draw(img).polygon([(c - origin[1], r - origin[0]) for c, r in points], fill=255)
    return np.asarray(img) > 127


def turned(mask, degrees):
    """A silhouette turned `degrees` anticlockwise about its box's middle (nearest pixel): a view drawn or scanned turned
    is read square (the P-38 sheet's plan is turned 0.92 degrees: both booms lean the same way, 0.85 and 1.00, over 65
    rows each, and two booms that are parallel cannot)."""
    from PIL import Image
    img = Image.fromarray((mask * 255).astype(np.uint8))
    return np.asarray(img.rotate(degrees, resample=Image.NEAREST, expand=False)) > 127


def runs(indices):
    if len(indices) == 0:
        return []
    splits = np.where(np.diff(indices) != 1)[0] + 1
    return [(r[0], r[-1]) for r in np.split(indices, splits)]


def fit(rows):
    """A straight line through (x, y) rows by least squares: ((a, b) for y = a + b x, rms, worst)."""
    rows = np.array(rows)
    a_matrix = np.c_[np.ones(len(rows)), rows[:, 0]]
    c, *_ = np.linalg.lstsq(a_matrix, rows[:, 1], rcond=None)
    r = rows[:, 1] - a_matrix @ c
    return c, float(np.sqrt((r ** 2).mean())), float(np.abs(r).max())


def circle(ink, box, radii):
    """The circle the ink in `box` (row0, row1, col0, col1) most agrees with: a search for the centre whose distances
    pile up at one radius, then a least-squares fit to the ink within 4 px of it. (sheet col, row, radius, rms)."""
    r0, r1, c0, c1 = box
    ys, xs = np.nonzero(ink[r0:r1, c0:c1])
    ys = ys + r0
    xs = xs + c0
    bins = np.arange(radii[0], radii[1], 1)
    best = None
    for cyy in range(r0, r1, 2):
        for cx in range(c0, c1, 2):
            dist = np.hypot(ys - cyy, xs - cx)
            count = np.histogram(dist, bins=bins)[0]
            if best is None or count.max() > best[0]:
                best = (count.max(), cyy, cx, bins[count.argmax()])
    _, cyy, cx, rad = best
    near = np.abs(np.hypot(ys - cyy, xs - cx) - rad) < 4
    x = xs[near].astype(float)
    y = ys[near].astype(float)
    c, *_ = np.linalg.lstsq(np.c_[2 * x, 2 * y, np.ones(len(x))], x ** 2 + y ** 2, rcond=None)
    radius = float(np.sqrt(c[2] + c[0] ** 2 + c[1] ** 2))
    rms = float(np.sqrt(((np.hypot(x - c[0], y - c[1]) - radius) ** 2).mean()))
    return float(c[0]), float(c[1]), radius, rms
