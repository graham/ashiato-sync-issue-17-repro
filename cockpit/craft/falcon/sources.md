# General Dynamics F-16A Fighting Falcon (Block 15) visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/falcon_airframe.gd`). It contains no downloaded mesh, photograph,
texture, trademark or livery.

**It is a SINGLE-SEAT F-16A, Block 15**, the block that introduced the enlarged horizontal
tail, with the original small-mouth ("normal shock") intake. It is NOT a two-seat F-16B or D:
the canopy in the reference is one transparency 3.66 m long from windscreen foot to its aft
point, closing over one seat, with the fixed aft frame 2.4 m behind the windscreen foot.

## The authority for the shape

**[CEL]** Marek Cel, "Lockheed F-16A Fighting Falcon 3-view line drawing", a three-view of the
F-16 "Block 15 and subsequent", **CC0** (public domain dedication), 2019, held on Wikimedia
Commons as
[`Lockheed F-16A Fighting Falcon 3-view line drawing.svg`](https://commons.wikimedia.org/wiki/File:Lockheed_F-16A_Fighting_Falcon_3-view_line_drawing.svg).
**It is a vector file drawn in millimetres at 1:100**, so every figure below is read from the
drawing's own coordinates -- no pixel was picked -- and one document unit is 0.1 m. Its
views agree with each other: the plan and front views give the span as 99.60 and 100.36 mm
(0.76 per cent), and port and starboard edges of the wing and tail agree to under 0.001 mm.

**[USAF]** "General Dynamics F-16 Fighting Falcon 3-view line drawing", US Air Force
(af.mil art), public domain, on Commons as
[`General Dynamics F-16 Fighting Falcon 3-view line drawing.svg`](https://commons.wikimedia.org/wiki/File:General_Dynamics_F-16_Fighting_Falcon_3-view_line_drawing.svg).
**NOT USED FOR ANY DIMENSION, because it is not isotropic.** Its plan view is 1.703 times as
long as it is wide, against about 1.51 for the real aeroplane and 1.525 for [CEL]: it is
clip art with the fuselage stretched about 12 per cent against the wing. Its plan and side
views agree about length (0.09 per cent) and its front and plan views disagree about span by
2.74 per cent. It is kept as a shape cross-check for the canopy and intake only. **The
official drawing was the tempting one and it is the wrong one**; the free-licence drawing by
an individual is the one that measures.

**[ARMY]** US Army air-defence recognition three-view,
[`General Dynamics F-16 Fighting Falcon 3-view line drawing.png`](https://commons.wikimedia.org/wiki/File:General_Dynamics_F-16_Fighting_Falcon_3-view_line_drawing.png),
public domain, 574 x 385 px. Too small to measure (about 0.05 m a pixel at best); studied for
silhouette only.

`measure_threeview.py` re-derives every MEASURED figure here from the two SVGs, reading
nothing out of this file. The drawings and their licence table are in
`~/godotgames-drafts/2026-09-17/cockpit-falcon/research/`; none is incorporated into the game.

## Measured off [CEL], at 1:100

Stations are metres aft of the **radome tip**, which is [CEL] x = 13.30; the pitot boom
reaches 0.52 m further forward (x = 8.06 in plan, 7.21 in side). Heights are from the side
view's own datum, y = 60.0, the bottom of both drawn tyres (59.91 and 60.03).

| | drawing | model |
|---|---|---|
| Pitot tip to nozzle exit, plan | 151.87 mm | 15.19 m |
| Radome tip to nozzle exit | 146.6 mm | 14.66 m |
| Span over the wingtip launcher rails, plan | 99.60 mm | 9.96 m |
| Span to the wing tips, inside the rails | 96.2 mm | 9.62 m |
| Wing leading edge | x = 70.287 + 0.8058 h, rms 0.009 mm over 67 rows | **38.9 degrees** |
| Wing trailing edge | x = 121.49, unswept, rms 0.000 | |
| Wing root / tip chord (at the LERX's end, 1.41 m out / at 4.81 m) | 39.8 / 12.4 mm | 3.98 / 1.24 m |
| Tailplane leading edge | x = 124.46 + 0.8931 h, rms 0.009 | **41.8 degrees** |
| Tailplane trailing edge | x = 159.84, unswept | |
| Tailplane semi-span, root at the aft fuselage side | 11.0 to 29.45 mm | 1.10 to 2.95 m out |
| Fin root at the fin base / tip | x 127.0 to 153.75 / 152.2 to 165.0 | chords 2.68 / 1.28 m |
| Fin base / tip heights | y 28.1 / 5.76 | 3.19 / 5.42 m |
| Canopy: windscreen foot, top, aft frame, aft point | x 36.5, 52--56, 61.3, 73.1 | |
| Canopy top | y 28.07 | 3.19 m |
| Intake: upper lip, lower lip, bottom | x 52.8, x 55.4--56.5, y 50.0 | |
| Nozzle exit | x 160.0, 0.92 m across | |
| Ventral fins | x 117.1 to 131.9 at the root | |
| Nose / main tyre (side view circles) | 5.29 / 7.33 mm | 0.53 / 0.73 m |
| Main gear / nose gear station | x 104.04 / 62.21 | wheelbase 4.18 m |
| Main track (front view: the mains' middles at y 100.58 and 126.00) | 25.42 mm | **2.54 m** |
| Main / nose tyre width (front view) | 1.99 / 1.50 mm | |
| Tailplane anhedral (front view: 15.3 mm out at y 42.0 to 29.5 at 44.5) | | **10 degrees** |
| Ventral fins (front view) | root 5.4 mm out, splayed | 16 degrees |

## The envelope, published

**[W]** Wikipedia, "General Dynamics F-16 Fighting Falcon", its specifications template (the
`{{Aircraft specs}}` box), retrieved 2026-09-17 through the MediaWiki API with the user's
permission; its own sources are the USAF fact sheet, the International Directory of Military
Aircraft and an F-16C/D Block 50/52+ flight manual. **Every figure is for the F-16C Block 50/52,
not the Block 15 modelled here.** The outer envelope did not change between them; the weights did.

| [W], F-16C Block 50/52 | published | this model ([CEL] at 1:100) | difference |
|---|---|---|---|
| Length | 49 ft 5 in, 15.06 m | 15.17 m radome to fin cap; 15.69 m with the pitot | +0.7 % / +4.2 % |
| Span | 32 ft 8 in, 9.96 m | 9.96 m over the rails | 0.0 % |
| Height | 16 ft, 4.88 m | 5.42 m fin top over the drawn tyres | +11 % |
| Wing area | 300 sq ft, 27.87 m2 | about 30 m2 to the centreline, off the measured edges | about +8 %, datum unknown |
| Empty / gross / max take-off | 8,573 / 12,020 / 19,187 kg | `DRAFT_GEOMETRY` mass 12,000 kg | the gross figure, Block 50 |

**The height is left as the drawing has it**, because the aircraft sits and looks right on the
drawing's own tyres, and lowering it to 4.88 m would bury the main tyres in the belly; per the
user's priority (look and fly well over exact specs) this is not chased further.

## What is not settled

- **Where the aeroplane ends.** The side view runs the fin's tip cap to x 165.0, 0.50 m past the
  nozzle's exit at 160.0; the plan view ends everything at 159.93, though a fin cap on the
  centreline should show there. The model follows the side view, so it is 15.69 m from pitot tip
  to fin cap and 15.17 m from radome tip to fin cap. The figure commonly quoted for an F-16's
  length is [W]'s 15.06 m, which radome-to-fin-cap matches to 0.7 per cent.
- **The gear in the front view is drawn 0.77 mm off the centreline** (the nose tyre at y 113.29
  against the wing tips' 114.06), with the mains symmetric about the nose tyre. The track is taken
  as the distance between the mains. The front view also draws the tyres about 11 per cent
  smaller than the side view does; the side view's circles are used for size.
- **The height** (above): 5.42 m against [W]'s 4.88 m. The drawing's front view is also 1.7 to
  2.5 per cent taller than its side view. The side view is used; decided on the look.
- **The wing's reference area** is not checked: a trapezoid taken to the centreline off the
  measured edges gives about 30 m2 against a commonly quoted 27.87 m2 (300 sq ft), and
  without a printed root chord the datum of that figure is not known (`modelling_here.md`
  section 2, "a published dimension has a datum").
- **The wing's twist and the leading-edge flaps** are not on a three-view; the tailplane's anhedral is (the front view, 10 degrees).

## The first thing the drawing corrected

The first draft typed the main-gear track as 2.36 m, "the commonly quoted figure", with a note
that the three-view draws no gear in its front view. It does: three rounded bars on the ground
line, which a search for circles did not find because they are drawn as `rect`s. They give
2.54 m. **A number typed from memory beside a drawing that has it is the drawing unread.**

## Evidence

- `tests/falcon.gd` (suite): the envelope, the tyres, the chin intake and a ray into its mouth,
  the body's step behind the wing, a single-seat canopy with no bow ahead of the pilot, the
  planform and anhedral from drawn vertices, a pilot room inside the drawn skin by ray parity,
  the three hinges, winding and the budget -- 14 checks, 1,864 triangles, 17 draw surfaces.
- `tests/falcon_shot.gd` (probe, `tools\gate_run.ps1 -Probe falcon_shot`): four lit views and
  three silhouettes at 80 px a metre; `overlay_threeview.py` lays those on [CEL] at x1.000.

## Datum and axes

The craft origin is the centre of the model's box, forward is `-Z`, up is `+Y`, one Godot
unit is one metre. The box is DRAFT_GEOMETRY until an F-16 kind exists: radome tip to nozzle
exit, the ground to the canopy's top, and the tail booms' 2.20 m across. `FalconAirframe` works in [CEL]'s own coordinates -- `station(x)` and
`height(y)` turn a drawing x and y into model z and y -- so every constant in the file is a
number that can be found on the drawing.
