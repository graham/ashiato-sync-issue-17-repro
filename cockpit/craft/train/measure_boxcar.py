"""Measure a 40 ft boxcar off a true broadside photograph, from the image alone.

    python cockpit/craft/train/measure_boxcar.py [--image <path>] [--overlay <path>]

WHY THIS FILE EXISTS. `modelling_here.md` section 3: "make the research file reproducible by a
script that does not read it". Nothing below is typed out of `sources.md` or out of the lane's
research notes. The only hand-entered numbers are the colour and run thresholds that say what a
sky pixel and a red pixel are, and one PUBLISHED length used at the very end as a scale. Every
shape figure the model uses comes back out of the pixels, so the write-up and this script can
disagree and one of them be wrong -- which is the whole point of having it.

THE REFERENCE is Commons `RR77.96 Boxcar No. 5078 Side.JPG` (CC BY-SA 4.0, Derek Ramsey), the
side of Philadelphia & Reading 5078 at the Railroad Museum of Pennsylvania. It is the only TRUE
BROADSIDE of a boxcar found on Commons on 2026-09-17, and one of only two photographs of
anything in this lane's subject that is not three-quarter.

WHAT THIS PHOTOGRAPH CAN AND CANNOT BE ASKED. It gives the roof line, the side sill, the two
ends and the two door edges to an rms of two or three pixels, because each of those is an
unambiguous outline against sky or against a differently coloured surface. **It cannot give the
running gear.** The wheels, the rails, the ballast and the car's own shadow are all near black
at this exposure and no threshold separates them; a first version of this script fitted circles
to what it thought were wheel bottoms and drew them in the grass, twenty metres across. That is
`modelling_here.md`'s rule about a feature you cannot identify, met head on: **the trucks'
horizontal EXTENT is measurable in a band just below the sill, where only they are dark, but
their wheels' diameter and the railhead are not.**

SO THE ANSWER IS RATIOS, NOT LENGTHS. Everything is reported as a fraction of the car's own
length over the eaves, which is a quantity no scale is needed for. The absolute size then comes
from a PUBLISHED dimension of the 40 ft class in `sources.md`, and the file says that is what
happened rather than implying the photograph settled it. A ratio you are sure of plus a scale
you are not is a better state than a number quietly guessed.

AND IT DRAWS WHAT IT MEASURED. `--overlay` writes the photograph with every fitted line and edge
on it. That picture is what caught the wheel circles, and no printed residual did.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------------------
# The one PUBLISHED number, used only to turn the ratios into metres at the very end.
# A postwar AAR / Pullman-Standard 40 ft steel boxcar is 40 ft 6 in inside; over the eaves is
# that plus the end framing and the roof's overhang. See sources.md, where it is an ESTIMATE
# with what would settle it. Nothing above this line is scaled by it.
# ---------------------------------------------------------------------------------------
LENGTH_OVER_EAVES_M = 12.60

# ---------------------------------------------------------------------------------------
# What a pixel is. Thresholds only: no geometry.
# ---------------------------------------------------------------------------------------
SKY_LUMA = 140.0          # a sky pixel is brighter than this ...
SKY_SATURATION = 0.20     # ... and less coloured than this.
SKY_RUN = 15              # rows of not-sky before a roof is believed, so a wire is not a roof.
BODY_RED = 1.25           # the car's red-brown: red at least this much above green and blue.
BODY_FLOOR = 60.0         # and not merely dark.
UNDER_DARK = 75.0         # the running gear, in the band where only it is dark.
UNDER_FROM = 0.055        # that band, as a fraction of the body's depth below the sill ...
UNDER_TO = 0.135          # ... to here. Above it is the car; below it is shadow and ballast.
UNDER_SOLID = 0.70        # a column belongs to a truck when this much of the band is dark.


def load(path: Path) -> np.ndarray:
    if not path.exists():
        sys.exit(
            "No such image: %s\nIt is a study reference and is not kept in the repository; "
            "fetch it from Commons as `RR77.96 Boxcar No. 5078 Side.JPG`." % path
        )
    return np.asarray(Image.open(path).convert("RGB")).astype(float)


def fit_line(xs: np.ndarray, ys: np.ndarray) -> tuple[float, float, float]:
    """Least squares y = m x + c with the rms residual, so a bad fit announces itself."""
    m, c = np.polyfit(xs, ys, 1)
    return float(m), float(c), float(np.sqrt(np.mean((ys - (m * xs + c)) ** 2)))


def trim(xs: np.ndarray, ys: np.ndarray, keep: float = 0.90) -> tuple[np.ndarray, np.ndarray]:
    """Drop the worst tenth against a first fit: a lamp post crossing the sky is not a roof."""
    m, c, _ = fit_line(xs, ys)
    err = np.abs(ys - (m * xs + c))
    good = err <= np.quantile(err, keep)
    return xs[good], ys[good]


def roof_row(a: np.ndarray) -> np.ndarray:
    """Per column, the first row starting a run of SKY_RUN not-sky rows; -1 where there is none."""
    mx, mn = a.max(2), a.min(2)
    sky = (mx > SKY_LUMA) & ((mx - mn) / (mx + 1e-6) < SKY_SATURATION)
    solid = ~sky
    height, width = solid.shape
    top = np.full(width, -1)
    run = np.zeros(width, dtype=int)
    found = np.zeros(width, dtype=bool)
    for y in range(height):
        run = np.where(solid[y], run + 1, 0)
        hit = (~found) & (run >= SKY_RUN)
        top[hit] = y - (SKY_RUN - 1)
        found |= hit
        if found.all():
            break
    return top


def runs_of(flag: np.ndarray, least: int) -> list[tuple[int, int]]:
    """The [start, end] of every run of True at least `least` long."""
    out: list[tuple[int, int]] = []
    start = None
    for i, on in enumerate(flag):
        if on and start is None:
            start = i
        elif not on and start is not None:
            if i - start >= least:
                out.append((start, i - 1))
            start = None
    if start is not None and len(flag) - start >= least:
        out.append((start, len(flag) - 1))
    return out


def main() -> int:
    drafts = Path.home() / "godotgames-drafts" / "2026-09-17" / "cockpit-train" / "research"
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--image", type=Path, default=drafts / "boxcar-reading-5078-side.jpg")
    ap.add_argument("--overlay", type=Path, default=drafts / "boxcar-measured-overlay.png")
    args = ap.parse_args()

    a = load(args.image)
    height, width = a.shape[0], a.shape[1]
    print("[boxcar] %s, %d x %d px" % (args.image.name, width, height))

    # ---- 1. THE ROOF, AND THE TWO ENDS --------------------------------------------------
    xs = np.arange(width)
    top = roof_row(a)
    seen = top[top >= 0]
    band = np.median(seen[(seen > height * 0.15) & (seen < height * 0.40)])
    on_car = (top >= 0) & (np.abs(top - band) < height * 0.03)
    columns = np.nonzero(on_car)[0]
    left, right = int(columns.min()), int(columns.max())
    length_px = float(right - left)
    rx, ry = trim(xs[on_car].astype(float), top[on_car].astype(float))
    roof_m, roof_c, roof_rms = fit_line(rx, ry)
    roof_at = lambda x: roof_m * x + roof_c
    print("[boxcar] roof x=%d..%d, %.0f px long; slope %+.5f, rms %.1f px over %d columns"
          % (left, right, length_px, roof_m, roof_rms, rx.size))

    # ---- 2. THE SIDE SILL ---------------------------------------------------------------
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    body = (r > BODY_FLOOR) & (r > g * BODY_RED) & (r > b * BODY_RED)
    sill_x, sill_y = [], []
    for x in range(left + 40, right - 40):
        col = np.nonzero(body[:, x])[0]
        col = col[(col > band) & (col < height * 0.75)]
        if col.size:
            sill_x.append(x)
            sill_y.append(col.max())
    sx, sy = trim(np.array(sill_x, float), np.array(sill_y, float))
    sill_m, sill_c, sill_rms = fit_line(sx, sy)
    sill_at = lambda x: sill_m * x + sill_c
    print("[boxcar] side sill: slope %+.5f, rms %.1f px over %d columns"
          % (sill_m, sill_rms, sx.size))

    # THE BODY IS NOT A RECTANGLE IN THE IMAGE, and that is said rather than averaged away --
    # the same rule as interpolating a ship's waterline per column instead of taking one row.
    depth_left = sill_at(left) - roof_at(left)
    depth_right = sill_at(right) - roof_at(right)
    depth_px = 0.5 * (depth_left + depth_right)
    print("[boxcar] body depth roof to sill: %.0f px at the left end, %.0f px at the right, "
          "%+.1f%% across the car -- the camera is not exactly abeam, so no station's scale is "
          "carried to another" % (depth_left, depth_right,
                                  100.0 * (depth_right - depth_left) / depth_left))

    # ---- 3. THE TRUCKS, BY EXTENT ONLY --------------------------------------------------
    # In a narrow band just under the sill only the running gear is dark: above it is the car,
    # below it the shadow, the rails and the ballast, which are the same black as the wheels
    # and cannot be told from them. So this measures WHERE the trucks are and how long they
    # are, and says nothing about wheel diameter or the railhead.
    lum = a.mean(2)
    solid = np.zeros(width)
    for x in range(left, right + 1):
        lo = int(sill_at(x) + depth_px * UNDER_FROM)
        hi = int(sill_at(x) + depth_px * UNDER_TO)
        solid[x] = (lum[lo:hi, x] < UNDER_DARK).mean() if hi > lo else 0.0
    under = np.zeros(width, dtype=bool)
    under[left:right + 1] = solid[left:right + 1] > UNDER_SOLID
    trucks = [t for t in runs_of(under, int(length_px * 0.10))]
    print("[boxcar] running gear found in %d place(s): %s"
          % (len(trucks), ", ".join("x=%d..%d" % t for t in trucks)))
    if len(trucks) != 2:
        print("[boxcar] WARNING: a boxcar has two trucks. The ratios below are not trustworthy.")
    else:
        # THE INBOARD EDGES ARE THE HONEST PAIR. A truck's OUTBOARD edge runs into the
        # coupler and the draft gear at the same height and the same black, so the two runs
        # come out different lengths; their inboard ends have nothing beyond them but grass.
        # Reported separately because the spread is the uncertainty, not noise to average.
        wide, narrow = max(trucks, key=lambda t: t[1] - t[0]), min(trucks, key=lambda t: t[1] - t[0])
        spread = (wide[1] - wide[0]) / float(narrow[1] - narrow[0]) - 1.0
        print("[boxcar] the two runs differ by %.0f%%: the longer one has run into the draft gear,"
              " so a truck's own length is uncertain by about that much" % (100.0 * spread))
        print("[boxcar] inboard gap between them: %d px, %.4f of the length"
              % (trucks[1][0] - trucks[0][1], (trucks[1][0] - trucks[0][1]) / length_px))

    # ---- 4. THE DOOR --------------------------------------------------------------------
    # A sliding door is horizontal boarding let into vertical boarding, so its two edges are
    # the strongest vertical discontinuities anywhere along the middle of the side.
    y0 = int(0.5 * (roof_at(left) + sill_at(left)) - depth_px * 0.20)
    y1 = int(y0 + depth_px * 0.35)
    strip = lum[y0:y1, left:right]
    energy = np.convolve(np.abs(np.diff(strip, axis=1)).mean(0), np.ones(9) / 9.0, mode="same")
    mid = slice(int(len(energy) * 0.30), int(len(energy) * 0.70))
    picks: list[int] = []
    for idx in np.argsort(energy[mid])[::-1]:
        if all(abs(int(idx) - p) > length_px * 0.05 for p in picks):
            picks.append(int(idx))
        if len(picks) == 2:
            break
    door = sorted(p + mid.start + left for p in picks)

    # ---- 5. WHAT THE PHOTOGRAPH ACTUALLY SETTLED, AS RATIOS -----------------------------
    print("[boxcar] ---- ratios of the length over the eaves, which need no scale ----")
    print("[boxcar] body depth / length              %.4f" % (depth_px / length_px))
    ratios = {"depth": depth_px / length_px}
    if len(trucks) == 2:
        centres = [0.5 * (t[0] + t[1]) for t in trucks]
        ratios["truck_centres"] = (centres[1] - centres[0]) / length_px
        ratios["truck_length"] = 0.5 * sum(t[1] - t[0] for t in trucks) / length_px
        print("[boxcar] truck centres / length           %.4f" % ratios["truck_centres"])
        print("[boxcar] one truck, over its gear / length %.4f" % ratios["truck_length"])
    if len(door) == 2:
        ratios["door_width"] = (door[1] - door[0]) / length_px
        ratios["door_middle"] = (0.5 * (door[0] + door[1]) - left) / length_px
        print("[boxcar] door width / length              %.4f" % ratios["door_width"])
        print("[boxcar] door middle from the left end    %.4f  (0.5 would be centred)"
              % ratios["door_middle"])

    # ---- 6. AND IN METRES, BY THE PUBLISHED CLASS AND BY NOTHING IN THIS PICTURE ---------
    L = LENGTH_OVER_EAVES_M
    print("[boxcar] ---- scaled by a PUBLISHED %.2f m over the eaves (sources.md) ----" % L)
    print("[boxcar] one pixel is %.0f mm" % (1000.0 * L / length_px))
    print("[boxcar] body depth, sill to roof         %.2f m  (%.1f ft)"
          % (ratios["depth"] * L, ratios["depth"] * L / 0.3048))
    if "truck_centres" in ratios:
        print("[boxcar] truck centres                    %.2f m  (%.1f ft)"
              % (ratios["truck_centres"] * L, ratios["truck_centres"] * L / 0.3048))
    if "door_width" in ratios:
        print("[boxcar] door opening                     %.2f m  (%.1f ft)"
              % (ratios["door_width"] * L, ratios["door_width"] * L / 0.3048))

    # ---- 7. THE CROSS-CHECK NOTHING WAS FITTED TO ---------------------------------------
    # A 40 ft boxcar's door is a 6 ft or a 7 ft opening and its truck centres are about 30 ft.
    # Neither went into any fit above, and both come out of the ratios times the class length.
    if "door_width" in ratios:
        feet = ratios["door_width"] * L / 0.3048
        print("[boxcar] CROSS-CHECK: the door comes out at %.1f ft. A 40 ft boxcar was built with"
              % feet)
        print("[boxcar]   a 6 ft or a 7 ft door and nothing else; %s."
              % ("that is one of them" if 5.5 < feet < 7.5 else "IT IS NEITHER, so look again"))
    if "truck_centres" in ratios:
        feet = ratios["truck_centres"] * L / 0.3048
        print("[boxcar] CROSS-CHECK: truck centres come out at %.1f ft against a standard 30 ft"
              " for the class." % feet)

    # ---- 8. DRAW WHAT WAS MEASURED ------------------------------------------------------
    shot = Image.open(args.image).convert("RGB")
    d = ImageDraw.Draw(shot)
    d.line([(left, roof_at(left)), (right, roof_at(right))], fill=(0, 255, 255), width=5)
    d.line([(left, sill_at(left)), (right, sill_at(right))], fill=(0, 255, 0), width=5)
    for x in (left, right):
        d.line([(x, roof_at(x) - 80), (x, sill_at(x) + depth_px * 0.30)], fill=(255, 0, 255), width=5)
    for x0, x1 in trucks:
        y = sill_at(0.5 * (x0 + x1)) + depth_px * UNDER_TO
        d.line([(x0, y), (x1, y)], fill=(255, 128, 0), width=6)
        d.line([(0.5 * (x0 + x1), y - 40), (0.5 * (x0 + x1), y + 40)], fill=(255, 128, 0), width=6)
    for x in door:
        d.line([(x, y0), (x, sill_at(x))], fill=(255, 255, 0), width=4)
    args.overlay.parent.mkdir(parents=True, exist_ok=True)
    shot.save(args.overlay)
    print("[boxcar] overlay written to %s -- LOOK AT IT." % args.overlay)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
