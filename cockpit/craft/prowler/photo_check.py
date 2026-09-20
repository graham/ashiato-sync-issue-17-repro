"""Lay the DRAWN MODEL over a photograph of a parked Prowler, pinned ONLY on the two tyre
contacts.

    python photo_check.py

WHY TWO POINTS AND NOTHING ELSE. The question the photograph is being asked is whether a
Prowler really sits nose-up the way `ProwlerAirframe.GEAR_RAKE` says. That attitude cannot be
measured off a photograph directly, because the aeroplane carries no visible datum line. But
it IS what puts the aircraft at a particular pose ON ITS OWN WHEELS -- so if the model's two
tyre contacts are made to coincide with the photograph's, and the rest of the model then
lands on the rest of the aeroplane, the model's attitude is confirmed. Two point pairs fix
rotation, scale and translation and nothing else; the fin, the canopy and the nose are
predictions, not fits. The render already noses right, as the photograph does.

IT DOES NOT GIVE A NUMBER, and the write-up says so. This frame is not taken square on, and
its contrast under the aircraft is too poor to fit either wheel as an ellipse, so the heading
cannot be recovered -- and a fore-aft angle read off a foreshortened photograph is wrong by
an unknown amount. The rake's three agreeing readings all come off the drawing; what this
picture adds is that a real parked Prowler stands the way the model stands.
"""

from PIL import Image
import numpy as np
import math
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
OUT = pathlib.Path(r"C:\gg-wt\prowler\screenshots\2026-09-17")

# Read off the photograph as the LOWEST DARK PIXEL under each wheel, scanned column by column
# rather than eyeballed: the twin nose wheel bottoms at y 735.5 over x 1075..1135, the port
# main wheel at y 729.6 over x 615..700.
PH_NOSE = (1105.0, 735.5)
PH_MAIN = (655.0, 729.6)
PUBLISHED_WHEELBASE = 5.235      # 206.11 in [NAVY]


def _contact(solid, lo, hi):
    """The lowest drawn point within a band of the render's width: a tyre's contact."""
    w = solid.shape[1]
    band = solid[:, int(w * lo):int(w * hi)]
    ys, xs = np.nonzero(band)
    y = ys.max()
    return (int(w * lo) + float(xs[ys == y].mean()), float(y))


def _outline(solid):
    """The silhouette's edge, so the photograph shows through it."""
    inner = solid.copy()
    inner[1:, :] &= solid[:-1, :]
    inner[:-1, :] &= solid[1:, :]
    inner[:, 1:] &= solid[:, :-1]
    inner[:, :-1] &= solid[:, 1:]
    return solid & ~inner


def main() -> None:
    model = Image.open(OUT / "cockpit-prowler-02-side-at-sac-scale.png").convert("RGB")
    photo = Image.open(HERE / "photo-fallon-sideon.jpg").convert("RGB")

    solid = np.array(model)[:, :, 1] < 200
    nose = _contact(solid, 0.72, 0.88)
    main = _contact(solid, 0.40, 0.56)
    print("render contacts: nose (%.1f, %.1f), main (%.1f, %.1f)" % (nose + main))

    dx, dy = main[0] - nose[0], main[1] - nose[1]
    ex, ey = PH_MAIN[0] - PH_NOSE[0], PH_MAIN[1] - PH_NOSE[1]
    scale = math.hypot(ex, ey) / math.hypot(dx, dy)
    turn = math.atan2(ey, ex) - math.atan2(dy, dx)
    cos_t, sin_t = math.cos(turn) * scale, math.sin(turn) * scale
    print("model -> photograph: scale x%.4f, rotation %+.2f degrees" % (scale, math.degrees(turn)))
    print("photograph: %.1f px a metre along the ground, from the printed %.3f m wheelbase"
          % (math.hypot(ex, ey) / PUBLISHED_WHEELBASE, PUBLISHED_WHEELBASE))

    ys, xs = np.nonzero(_outline(solid))
    base = np.array(photo).astype(float)
    tint = np.array([255.0, 40.0, 40.0])
    hit = 0
    for y, x in zip(ys, xs):
        u, v = x - nose[0], y - nose[1]
        px = PH_NOSE[0] + cos_t * u - sin_t * v
        py = PH_NOSE[1] + sin_t * u + cos_t * v
        iy, ix = int(round(py)), int(round(px))
        if 0 <= iy < base.shape[0] and 0 <= ix < base.shape[1]:
            base[iy, ix] = base[iy, ix] * 0.25 + tint * 0.75
            hit += 1
    print("%d of %d outline pixels land on the photograph" % (hit, len(ys)))
    Image.fromarray(base.astype(np.uint8)).save(
        OUT / "cockpit-prowler-06-model-on-both-tyre-contacts-over-fallon-photo.png")
    print("wrote cockpit-prowler-06-model-on-both-tyre-contacts-over-fallon-photo.png")


if __name__ == "__main__":
    main()
