"""MEASURE THE DUO DISCUS (cockpit/craft/glider/sources.md) off Schempp-Hirth's flight-manual three-view (section 1.5, Oct 1993), page 12 of the
Geelong Gliding Club scan, rendered at 300 dpi and turned upright. Study only; nothing from it is in the game.
Everything is derived from the drawing's pixels: the ONE published number used is the 20.00 m span, for the scale.
Output: metres. x = aft of the nose tip, y = over the main-wheel ground line (side view, level), out = starboard."""
import numpy as np, pymupdf, json, sys
from PIL import Image
# THE MANUAL'S PATH, as the first argument: it is not in the repository. It lives in
# ~/godotgames-drafts/2026-09-18/cockpit-sailplane/research/ and at the Geelong Gliding Club's URL in sources.md.
d = pymupdf.open(sys.argv[1] if len(sys.argv) > 1 else 'Duo_Discus_Flight_Manual.pdf')
d[11].get_pixmap(dpi=300).save('threeview_raw.png')
im = np.array(Image.open('threeview_raw.png').convert('L').rotate(-90, expand=True)); dark = im < 128
SPAN = 20.00
def runs(col):
    ys = np.nonzero(col)[0]
    if not len(ys): return []
    out = []; s = p = ys[0]
    for v in ys[1:]:
        if v != p + 1: out.append((s + p) / 2.0); s = v
        p = v
    out.append((s + p) / 2.0); return out
R = {}
# ---- PLAN VIEW: nose DOWN the page. The wing band is rows 1500-1800.
plan = dark[1500:1800]
xs = np.nonzero(plan.any(0))[0]; x0, x1 = xs.min(), xs.max()
S = (x1 - x0 + 1) / SPAN   # outer edge to outer edge of the tips
cx = (x0 + x1) / 2.0
R['px_per_m'] = S
fus = dark[900:2140, int(cx) - 60:int(cx) + 61]
nose_row = np.nonzero(dark[1800:2140, int(cx) - 30:int(cx) + 31].any(1))[0].max() + 1800
R['plan_nose_row'] = int(nose_row)
def aft_plan(row): return (nose_row - row) / S
wing = []
for y_m in list(np.arange(0.40, 9.81, 0.2)) + [9.9, 9.95]:
    row_sets = []
    for s in (1, -1):
        c = int(round(cx + s * y_m * S))
        r = runs(dark[1500:1800, c]); r = [v + 1500 for v in r]
        row_sets.append(r)
    le = np.mean([rs[-1] for rs in row_sets]); te = np.mean([rs[0] for rs in row_sets])
    hinge = np.mean([rs[1] for rs in row_sets]) if all(len(rs) >= 3 for rs in row_sets) else None
    wing.append({'out': round(float(y_m), 3), 'le': round(aft_plan(le), 4), 'te': round(aft_plan(te), 4),
                 'second_from_te': None if hinge is None else round(aft_plan(hinge), 4), 'lines': len(row_sets[0])})
R['wing'] = wing
area = 0.0; prev = None
# chord integral by line centres, the root chord carried to the centreline
chords = [(0.0, wing[0]['le'] - wing[0]['te'])] + [(w['out'], w['le'] - w['te']) for w in wing] + [(10.0, 0.0)]
for (a, ca), (b, cb) in zip(chords, chords[1:]): area += (b - a) * (ca + cb)
R['area_line_centres'] = round(abs(area), 3)
# ---- SIDE VIEW: nose RIGHT. Mask the plan view's tailplane, which reaches into the side view's top right corner.
side = dark.copy(); side[:1060, 1470:] = False
sv = side[1000:1285, 340:1540]
cols = np.nonzero(sv.any(0))[0]; xn = cols.max() + 340; xt = cols.min() + 340
ground = np.nonzero(sv.any(1))[0].max() + 1000
R['side_length'] = round((xn - xt + 1) / S, 3)
prof = []
for a in np.arange(0.0, (xn - xt) / S + 0.001, 0.1):
    c = int(round(xn - a * S)); r = [v + 1000 for v in runs(side[1000:1285, c])]
    prof.append({'x': round(float(a), 2), 'lines': [round((ground - v) / S, 3) for v in r]})
R['side'] = prof
# ---- FRONT VIEW: the wing's lower edge each side, for the dihedral.
fr = dark[480:800]
fc = np.nonzero(fr.any(0))[0]; f0, f1 = fc.min(), fc.max(); fcx = (f0 + f1) / 2.0
R['front_span_px'] = int(f1 - f0 + 1); R['front_scale_ratio'] = round((f1 - f0 + 1) / S / SPAN, 4)
dih = []
for y_m in [1.0, 2, 3, 4, 5, 6, 7, 8, 9, 9.5, 9.9]:
    vals = []
    for s in (1, -1):
        r = runs(dark[480:800, int(round(fcx + s * y_m * S))]); vals.append(r)
    dih.append({'out': y_m, 'lower_edge_row_mean': round(float(np.mean([v[-1] for v in vals])) + 480, 1),
                'upper_edge_row_mean': round(float(np.mean([v[0] for v in vals])) + 480, 1)})
R['front'] = dih
json.dump(R, open('duo_measured.json', 'w'), indent=1)
print('px/m %.2f  span-scaled side length %.3f (published 8.62)  line-centre wing area %.2f (published 16.40)  front/plan scale %.4f'
      % (S, R['side_length'], abs(area), R['front_scale_ratio']))
for w in wing[::3]: print(w)
