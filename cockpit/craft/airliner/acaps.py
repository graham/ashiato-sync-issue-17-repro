"""Reads a Boeing "Airplane Characteristics for Airport Planning" (ACAPS) general-dimensions page as three silhouettes.

Shared by `measure_views.py` and `overlay_views.py` here and by the 747's under `craft/jumbo/`. The ACAPS PDFs are study
material and are NOT in the repo: `sources.md` names where Boeing publishes them.

THE DRAWING IS VECTOR, and the aeroplane is the only thing drawn in blue: the grid is grey, the dimension lines and their
figures black. So the page is redrawn with its blue paths alone (pymupdf), which leaves nothing on the page but the
aeroplane and its ground lines, and no dimension line can cut a gap in an outline for a flood fill to leak through.

THE SILHOUETTE is every pixel NOT connected to the page border through white (PIL's flood fill), the F-35B's method
(`craft/lightning/measure_views.py`).
"""
import numpy as np
import pymupdf
from PIL import Image, ImageDraw


def _blue(c):
    return c is not None and len(c) == 3 and c[2] > 0.9 and c[0] < 0.1 and c[1] < 0.1


def blue_page(pdf, page_index, dpi):
    """The page redrawn with its blue paths only, black on white, as a numpy bool array (True = ink)."""
    src = pymupdf.open(pdf)[page_index]
    out = pymupdf.open()
    page = out.new_page(width=src.rect.width, height=src.rect.height)
    shape = page.new_shape()
    for d in src.get_drawings():
        stroke, fill = _blue(d.get("color")), _blue(d.get("fill"))
        if not (stroke or fill):
            continue
        for item in d["items"]:
            if item[0] == "l":
                shape.draw_line(item[1], item[2])
            elif item[0] == "c":
                shape.draw_bezier(item[1], item[2], item[3], item[4])
            elif item[0] == "re":
                shape.draw_rect(item[1])
            elif item[0] == "qu":
                shape.draw_quad(item[1])
        shape.finish(color=(0, 0, 0) if stroke else None, fill=(0, 0, 0) if fill else None,
                     width=max(d.get("width") or 0.3, 0.3), closePath=d.get("closePath", False),
                     even_odd=d.get("even_odd", False))
    shape.commit()
    pix = page.get_pixmap(dpi=dpi, colorspace=pymupdf.csGRAY)
    grey = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width)
    return grey < 128


def bands(ink, gap=40):
    """The page's views as (first row, last row) bands separated by at least `gap` blank rows."""
    rows = np.nonzero(ink.any(axis=1))[0]
    splits = np.where(np.diff(rows) > gap)[0] + 1
    return [(r[0], r[-1]) for r in np.split(rows, splits)]


def silhouette(ink):
    """Every pixel not joined to the border through blank pixels."""
    h, w = ink.shape
    img = Image.fromarray(np.where(ink, 0, 255).astype(np.uint8))
    pad = Image.new("L", (w + 2, h + 2), 255)
    pad.paste(img, (1, 1))
    ImageDraw.floodfill(pad, (0, 0), 128)
    return np.asarray(pad)[1:-1, 1:-1] != 128


def runs(indices):
    """Consecutive runs in a sorted index array, as (first, last) pairs."""
    if len(indices) == 0:
        return []
    splits = np.where(np.diff(indices) != 1)[0] + 1
    return [(int(r[0]), int(r[-1])) for r in np.split(indices, splits)]


def fit(rows):
    """Least squares y = a + b x over (x, y) rows: (a, b), rms and worst residual. Never through two ends
    (`modelling_here.md` section 3)."""
    rows = np.array(rows, dtype=float)
    a_matrix = np.c_[np.ones(len(rows)), rows[:, 0]]
    c, *_ = np.linalg.lstsq(a_matrix, rows[:, 1], rcond=None)
    r = rows[:, 1] - a_matrix @ c
    return c, float(np.sqrt((r ** 2).mean())), float(np.abs(r).max())


def ground_line(ink, band, share=0.1, look=60):
    """The ground line under a view, as (its rows). It is the ONE run wider than `share` of the band's width among the
    last `look` rows of the band. ACAPS draws the tyres a pixel or two THROUGH it, so it is not the band's last row."""
    first, last = band
    width = ink[first:last + 1].any(axis=0).sum()
    rows = []
    for y in range(last, max(first, last - look), -1):
        r = runs(np.nonzero(ink[y])[0])
        if r and max(b - a + 1 for a, b in r) > share * width:
            rows.append(y)
    return sorted(rows)


def components(mask, least=1):
    """Connected pieces of a mask (4-connected) as a list of (pixel count, bool mask), largest first. Labelled by runs:
    each row's runs are joined to the runs they overlap in the row above, through a union-find."""
    parent = []

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    rows = []
    for y in range(mask.shape[0]):
        here = []
        xs = np.nonzero(mask[y])[0]
        for a, b in runs(xs):
            label = len(parent)
            parent.append(label)
            for pa, pb, pl in (rows[-1] if rows else []):
                if pa <= b and pb >= a:
                    ra, rb = find(label), find(pl)
                    if ra != rb:
                        parent[max(ra, rb)] = min(ra, rb)
            here.append((a, b, label))
        rows.append(here)
    pieces = {}
    for y, here in enumerate(rows):
        for a, b, label in here:
            pieces.setdefault(find(label), []).append((y, a, b))
    out = []
    for spans in pieces.values():
        n = sum(b - a + 1 for _, a, b in spans)
        if n < least:
            continue
        piece = np.zeros_like(mask)
        for y, a, b in spans:
            piece[y, a:b + 1] = True
        out.append((n, piece))
    out.sort(key=lambda t: -t[0])
    return out


def views(pdf, page_index, dpi=600):
    """The page's three views as a dict of silhouettes, each with its ground row where it has one:
    {"plan": mask, "side": mask, "front": mask, "side_ground": row, "front_ground": row, "ink": the blue page}.

    The plan and the side view share rows on these pages (the side view's fin stands beside the plan's wing tip), so
    the views are told apart as the three largest connected pieces of the page's silhouette, ordered top to bottom.
    Smaller pieces (a wheel drawn apart from its leg) join the view whose box they fall in.

    The redrawn page is kept beside the PDF as .npy, because redrawing 6,000 paths takes half a minute."""
    import os
    cache = "%s.p%d.%ddpi.npy" % (pdf, page_index, dpi)
    if os.path.exists(cache):
        ink = np.load(cache)
    else:
        ink = blue_page(pdf, page_index, dpi)
        np.save(cache, ink)
    clean = ink.copy()
    grounds = []
    for band in bands(ink):
        rows = ground_line(ink, band)
        if rows:
            grounds.append(float(np.mean(rows)))
            clean[rows[0]:band[1] + 1] = False
    pieces = components(silhouette(clean))
    big = sorted(pieces[:3], key=lambda p: np.nonzero(p[1])[0].min())
    out = {"ink": ink}
    boxes = []
    for name, (_, mask) in zip(("plan", "side", "front"), big):
        ys, xs = np.nonzero(mask)
        boxes.append((name, ys.min(), ys.max(), xs.min(), xs.max()))
        out[name] = mask.copy()
    for _, mask in pieces[3:]:
        ys, xs = np.nonzero(mask)
        for name, y0, y1, x0, x1 in boxes:
            if y0 <= ys.mean() <= y1 + 60 and x0 <= xs.mean() <= x1:
                out[name] |= mask
                break
    for name in ("side", "front"):
        low = np.nonzero(out[name])[0].max()
        near = [g for g in grounds if abs(g - low) < 60]
        out[name + "_ground"] = near[0] if near else None
    return out


def filled_page(pdf, page_index, dpi, left_of=None):
    """A page redrawn from its FILLED paths alone, every one filled black: Lockheed's General Arrangement draws its
    aeroplanes as grey fills over dark outlines, and its dimension lines, figures and extension lines are strokes, so
    this leaves the aeroplanes and the arrowheads, which are too small to be a view. `left_of` keeps only paths whose
    box starts left of that x in points (the GA page is the left half of a spread)."""
    src = pymupdf.open(pdf)[page_index]
    out = pymupdf.open()
    page = out.new_page(width=src.rect.width, height=src.rect.height)
    shape = page.new_shape()
    for d in src.get_drawings():
        fill = d.get("fill")
        if fill is None or all(c > 0.95 for c in fill):
            continue
        if left_of is not None and d["rect"].x0 > left_of:
            continue
        for item in d["items"]:
            if item[0] == "l":
                shape.draw_line(item[1], item[2])
            elif item[0] == "c":
                shape.draw_bezier(item[1], item[2], item[3], item[4])
            elif item[0] == "re":
                shape.draw_rect(item[1])
            elif item[0] == "qu":
                shape.draw_quad(item[1])
        shape.finish(color=None, fill=(0, 0, 0), closePath=d.get("closePath", True), even_odd=d.get("even_odd", False))
    shape.commit()
    pix = page.get_pixmap(dpi=dpi, colorspace=pymupdf.csGRAY)
    return np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width) < 128
