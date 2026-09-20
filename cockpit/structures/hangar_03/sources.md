# Hangar 03 (SKYFRONT) — the concept sheet, measured

The model (`objects/structures/skyfront_hangar.gd`) is an original Godot procedural build. It
incorporates no downloaded mesh, texture, photograph or font glyph image. Every marking is
drawn as geometry, or as text laid out by the project's own font at runtime.

Every number below is tagged, as `modelling_here.md` section 3 requires:

- **PUBLISHED** — stated on the sheet in words or in a dimension arrow.
- **MEASURED** — taken off the sheet here. The method is the one under "How the sheet was
  measured", and each figure is good to about 0.1 m at the sheet's own scale.
- **ESTIMATE** — reasoned, with what it was reasoned from beside it.

## The reference

`hanger_v1.webp` (1,448 × 1,086, 1.9 MB), in this folder, **is the user's own concept sheet**,
given on 2026-09-17 with *"there are dimensions in the image, read it, determine how to build
it, the fidelity and colours and design is important"*. It is committed here because it is the
fidelity reference for this asset and because the side-by-side comparison pictures are built
from it; it is the user's own artwork, not a downloaded reference, and nothing in it is
incorporated into the game as pixels.

It carries eight panels: a hero three-quarter view with the door open and a fighter inside,
front / rear / left-side elevations, a rear three-quarter view, a top view of the roof, a
feature list and SKYFRONT branding.

Stated on the sheet: **32 x 40 x 12 m**, **clear opening 24 x 8 m**; the top view is
dimensioned 40 m along and 32 m across; the side elevation is dimensioned "40 m (LENGTH)" and
"32 m (HEIGHT)"; the front elevation is dimensioned "24 m (CLEAR OPENING)".

Key features, quoted: fortified modular construction, raised armoured roof spine, sloped
blast-deflection roof, **no skylights / no vents**, reinforced structural ribs, armoured
service housings, integrated utilities (perimeter), large door opening (24 x 8 m), scalable
layout, "same parts. new horizons."

## How the sheet was measured

Every panel was measured in image pixels against the dimension arrow drawn in that panel, so
each view is scaled by its own stated number rather than by the sheet's layout. Scales:

| panel | dimension arrow | pixels | scale |
|---|---|---|---|
| front elevation | 24 m clear opening | 293.8 | 12.24 px/m |
| front elevation | 32 m overall (derived) | 417.5 | 13.05 px/m |
| rear elevation | 32 m overall | 388.8 | 12.15 px/m |
| side elevation | 40 m length | 419.0 | 10.48 px/m |
| top view | 40 m along | 331.5 | 8.29 px/m |
| top view | 32 m across | 228.8 | 7.15 px/m |

**The sheet is not internally consistent, and two disagreements had to be settled.**

1. **"32 m (HEIGHT)" on the side elevation is wrong.** That arrow spans 163 px, which at the
   same panel's own 40 m scale is **15.6 m**, and it reaches the spire tips rather than the
   building. The number is the sheet's width repeated. The title's **12 m** is right, and the
   elevations say what it measures: ground to the top of the raised roof spine is 158 px in
   the front elevation (0.378 of its 417.5 px width → **12.1 m** at 32 m wide) and 155 px in
   the rear elevation (0.399 → **12.8 m**). The side elevation draws the same height 20%
   taller (0.365 of 40 m → 14.6 m); its verticals are stretched, which is also why its height
   arrow reads high. **Decision: 12.0 m, ground to the top of the roof spine**, which the two
   width-dimensioned elevations agree on within 1% and 7%. The corner masts reach 12.6 m.
2. **The drawn door is shorter than the stated 8 m.** The opening in the front elevation is
   293.8 px wide and 85 px tall — 24.0 m by **6.9 m** at that panel's scale, a 3.5:1 opening
   where the sheet's words say 3:1. The stated **24 x 8 m** is honoured, which lifts the
   lintel 1.1 m and thins the drawn 2.7 m head band to **1.2 m** (a 0.4 m yellow lintel and a
   0.8 m riveted head beam). Rejected: keeping the drawn 6.9 m door, because the sheet states
   the opening twice in words and only once in a drawing.

## The dimensions the model is built to

- **Footprint 32 m (door face) × 40 m (deep)** [PUBLISHED], to the outer faces of the corner
  towers and the side ribs [MEASURED]. The side elevation's 40 m arrow lands exactly on the corner towers' outer
  faces (measured 40.2 m), so the same rule is applied across the width. Perimeter utility
  housings stand outside that line, up to 1.5 m further out.
- **12.0 m** to the top of the roof spine [PUBLISHED, as the title's third figure]; **9.2 m**
  eave (top of the wall) [ESTIMATE, from the measured eave share below and an 8 m door];
  **11.0 m** roof shoulder where the slopes meet the spine [MEASURED, 0.907 of the front
  elevation's total]; **12.6 m** corner masts [MEASURED, +0.6 m over the spine].
  Measured eave share of total height: front 0.740, rear 0.703, side 0.706 (mean 8.6 m at
  12 m); raised to 9.2 m to carry an 8 m door with a 1.2 m head, which is the one place the
  sheet's proportions were overridden and why.
- **Clear opening 24.0 m × 8.0 m** [PUBLISHED, twice in words and once dimensioned], centred
  on the 32 m face. **Each flank is then exactly 4.0 m**: a 1.2 m gunmetal jamb pillar and a
  2.8 m panelled tower [derived — 32, 24 and the two flanks cannot all be free]. The sheet
  draws 0.6 + 3.1 + 1.8 = 5.5 m flanks, which with a 24 m opening would make the face 35 m,
  so the drawn flank is 1.5 m wider than the arithmetic allows. The two towers at the door
  are therefore 2.8 m across where the two at the back are the full 3.6 m.
- **Structural ribs on 10 m bays down the long sides** [MEASURED]: five ribs at 0, 10, 20, 30
  and 40 m, the end ones being the corner towers. Measured rib centres: 0, 10.4, 19.3, 28.6,
  40.2 m (spacings 9.5, 9.3, 9.8, 10.1 m → a 10 m bay).
- **Three bays across the 32 m faces** [MEASURED]: ribs at 0, 10.67, 21.33, 32 m. Measured
  rear rib centres 0, 9.3, 19.1, 28.6 m on a face drawn 28.6 m wide between the corner ribs.
- **Rib 2.2 m wide, projecting 0.9 m** out of the wall face [MEASURED]; **corner towers
  3.6 × 3.6 m** [MEASURED, top view 3.5 to 4.0 m square].
- **Nothing on a rib stands outside the envelope.** The rib's outer face IS the dimensioned
  32 × 40 m line, so its lamp, bracket and bolt plates are flush with that face or inside it,
  and the plates widen along the wall rather than out of it. The first build hung the lamp
  0.18 m proud and the suite measured the building 34.16 m across a 32 m face.
- **X cross-bracing** in the end bays of each long side (bays 1 and 4) and in the outer bays
  of the rear face (bays 1 and 3); middle bays plain riveted with a mid rail. Matches both
  elevations and the rear three-quarter view.
- **Wall bands** [MEASURED], ground upward, as fractions of the eave measured on the side and
  rear elevations: base housing band 0–1.9 m; dark girder band 1.9–2.4 m; main riveted panel
  2.4–7.3 m; dark louvre strip 7.3–8.0 m; upper riveted band 8.0–8.8 m; eave cap beam
  8.8–9.2 m.
- **Roof** [MEASURED]: a hipped blast deflector rising from the eave to a **14 m × 12 m** flat shoulder,
  with the **raised armoured spine** 1.0 m above it. Slopes: 13 m run and 1.8 m rise on the
  ends (8°), 10 m run and 1.8 m rise on the long sides (10°). Top view: the central band runs
  13.2 to 27.4 m along (14.2 m); front elevation: the spine reads 12.3 m across.
  Dark armoured strip panels flank the spine on the long-side slopes at 9.3–13.2 m and
  26.8–30.7 m along; two rows of four dark armoured hatches sit at the spine edge.
- **Roof markings** [MEASURED]: "03" centred on the spine, digits 4.4 m tall and 5.1 m wide as a pair;
  two yellow longitudinal stripes at ±5.4 m from the centreline; a yellow chevron pair on each
  end hip face pointing outboard, about 4 m tall; 0.5 m yellow stripes inset along the four
  hip diagonals; yellow safety railings round the eave and the spine.
- **Wall markings** [MEASURED]: "03" with the winged chevron and a SKYFRONT / A CLEANER BRIGHTER
  TOMORROW plate on the right-hand front tower (digits measured 1.1 m tall in the front
  elevation, drawn larger in the hero; built at 1.6 m on the 2.8 m face); "H3" on a dark sign
  panel 1.7 m × 4.4 m on the left-hand front tower with two chevron arrows below it; yellow
  jamb strips and a yellow lintel band with dark stencil dashes across the opening.

## Colours, as sampled from the sheet

Sampled with a 12-colour median cut over the hero panel and medians over named patches. The
sheet is a warm-lit render, so the darkest and lightest samples are lighting, not paint.

| part | sampled | used as |
|---|---|---|
| armour panel, lit | (229, 220, 215) | off-white panel albedo |
| armour panel, mid | (202, 188, 176) | panel albedo, shaded bays |
| armour panel, shade | (168, 154, 141) | panel albedo under the eave |
| structure | (43, 44, 48) and (34, 33, 32) | gunmetal ribs, beams, roof strips |
| deep shadow | (17, 16, 16) | door reveal, hatch recesses |
| mid steel | (80, 77, 78) | girders, railing posts, cabinets |
| safety yellow | (205, 141, 30) median, (239, 177, 89) lit | trim, lintel, railings, road paint |
| rivet / rust | warm orange specks on every panel | rivet dots in the panel shader |

## The look, and the segment counts

Low poly and faceted on purpose (the user, 2026-09-17; `modelling_here.md` section 4): flat
panels, hard creases, no rounded edges, single-bevel steps. **The only round thing in the
building is the corner mast, at `MAST_SIDES` = 6**, built as two stacked prisms and a rod.
Everything else is a box, a quad or a flat painted piece. A retessellation must leave every
dimension `tests/hangar.gd` measures unchanged.

Measured 2026-09-17: the shell is **8,336 triangles in one surface**, plus the emissive light
strips and two `Label3D`s of small print — **4 draws** in all, against a budget of 20 draws
and 100,000 triangles for a near model (`aircraft_model_fidelity_plan.md`). For comparison,
the battleship's near model is 9,798 triangles in 17 surfaces.

## What the E-6B does not do

The user asked first for an E-6B in the shot for scale, and then, once the clearances below
were reported, *"maybe we should use the f-18 instead… I want a fighter to fit inside"*
(2026-09-17). So the pictures are of the F/A-18F, and this table stays as the evidence that
the sheet's hangar cannot house a Mercury. The sheet's own aircraft is fighter-sized.
NAVAIR's E-6B is 45.8 m long, 45.2 m in span and 12.9 m high (`craft/mercury/sources.md`),
so against this hangar:

| clearance | hangar | E-6B | result |
|---|---|---|---|
| door width vs span | 24.0 m | 45.2 m | 21.2 m too wide |
| door height vs tail | 8.0 m | 12.9 m | 4.9 m too tall |
| building height vs tail | 12.0 m | 12.9 m | fin stands 0.9 m over the spine |
| building width vs span | 32.0 m | 45.2 m | 6.6 m of wing beyond each side |
| building depth vs length | 40.0 m | 45.8 m | 5.8 m longer than the hangar is deep |

The F/A-18F (`fighter`, 18.5 m long, 13.68 m span, 4.88 m high) is the aircraft the sheet
draws inside, and `tests/hangar.gd` measures its DRAWN model at 13.68 m in span and 4.92 m
high and reports **5.16 m clear at each wingtip and 3.08 m over the fin**. It is also driven
through the opening as a box, half a metre at a time, against every static box the hangar
hands the simulation, from 12 m outside the door to the back wall, and touches nothing.

The hangar was not scaled up to make a Mercury fit, and the Mercury was not shrunk.

**Two clearances over the fin are quoted in this workshop and they are both right.**
`tests/hangar.gd` measures the DRAWN model and reports **3.08 m**; `tests/hangar_shot.gd`
prints its caption from `FighterAirframe.HEIGHT`, the declared constant, and so says
**3.13 m**. The 0.05 m between them is the constant and the drawn mesh disagreeing about the
aircraft's height, not the hangar moving. THE MEASURED ONE IS THE ONE TO QUOTE: the drawn
model is what a wingtip actually hits.

## The pictures, and how to take them again

`screenshots/` is gitignored, so the pictures themselves are not in the repository: they are
written to `screenshots/<date>/` and copied to the drafts folder. What is tracked is the
probe that takes them and the tool that lays them beside the sheet, so any of them can be
made again from files alone.

```
Godot --xr-mode off --path cockpit --resolution 1600x900 res://tests/hangar_shot.tscn \
      -- --desktop-only --out=screenshots/2026-09-17
python cockpit/tools/hangar_comparison.py screenshots/2026-09-17 \
      screenshots/2026-09-17/cockpit-hangar-10-concept-sheet-against-the-model.png
```

Ten pictures, taken on 2026-09-17, in the sheet's own order:

| # | what it is | what it is for |
|---|---|---|
| 01 | hero three-quarter, door open | the sheet's own hero panel |
| 02 | front elevation, door open | the 24 x 8 m opening, with the fighter centred in it |
| 03 | rear elevation | |
| 04 | side elevation (left) | the 40 m length |
| 05 | rear three-quarter | |
| 06 | roof from straight above | the spine deck, its `03`, the chevrons and the diagonals |
| 07 | interior from the back of the bay | the overhead strips, the ribs and the parked fighter |
| 08 | the fighter in the doorway, three-quarters | that it reads as standing IN the building |
| 09 | the fighter in the doorway, square on | the clearances, readable against the opening |
| 10 | **the sheet's six panels beside the six renders** | the picture the work is judged by |

**2-4, 6 and 5 are lit by a fill down the camera's line of sight**, because the sun stands
over the door face and left the rear and the left side reading as dark blue-grey slabs of a
building whose paint is white and yellow. 01, 07, 08 and 09 keep the world's light: those
are meant to look like the place rather than like a drawing of it, and the interior light
strips and lamps are what make the aeroplane read as being inside rather than as a
silhouette in a black opening.

Three faults were found by looking at pictures that every dimension check had passed, and
they are written up in `modelling_here.md`, "Traps in taking the picture": the seat camera
that took the view and gave nine pictures of a Segway's desk under `RESULT=PASS`; the
spine's "rim" that was a lid, burying the light deck and the `03` on it (luminance 0.24,
0.82 once fixed); and the orthographic `size` that framed a 12.6 m building in a 42 m window
(the front elevation went from 14 to 63 per cent of the frame).
