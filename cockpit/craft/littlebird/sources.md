# Boeing (MD Helicopters) MH-6M Little Bird visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/littlebird_airframe.gd`). It contains no downloaded mesh, photograph,
texture, trademark or livery.

**It is an MH-6M**: six main blades, four tail blades on the port side, the MD 530F family's
T-tail with endplates, a FLIR ball under the chin, and an outboard bench each side. Not an
MH-6J or a civil MD 500E (five main blades), and not an OH-6A (four blades, canted stabiliser).
It is flown **doors off**, and the user asked for exactly that: *"it has a very open cockpit so
make sure we preserve this, pilot and copilot should be able to see very well ... it's a smaller
craft so get the dimensions right, we'll need to pack the pilots in close."*

## The authority for the shape

**[FOX]** FOX 52, "Boeing MH-6 orthographical image", **CC BY-SA 4.0**, own work, 2016, on
Wikimedia Commons as
[`Boeing MH-6 orthographical image.svg`](https://commons.wikimedia.org/wiki/File:Boeing_MH-6_orthographical_image.svg).
A **vector** three-view (side, front, plan) in unscaled document units, 541 x 329. Every figure
below is read from its own coordinates by `measure_drawing.py` (which reuses the falcon lane's
`craft/falcon/svg_lines.py`), so no pixel was picked. It is a TRACED drawing, not a
manufacturer's, and it is measurably imperfect -- see "What the drawing gets wrong".

**[FOX-E]** FOX 52, "McDonnell Douglas MD 500E orthographical image", CC BY-SA 4.0, on Commons as
[`McDonnell Douglas MD 500E orthographical image.svg`](https://commons.wikimedia.org/wiki/File:McDonnell_Douglas_MD_500E_orthographical_image.svg).
Studied for the civil egg's shape only; not measured.

**[OH6]** "Hughes OH-6A Cayuse schema", **public domain**, on Commons as
[`Hughes OH-6A Cayuse schema.png`](https://commons.wikimedia.org/wiki/File:Hughes_OH-6A_Cayuse_schema.png),
592 x 397 px. An INDEPENDENT drawing, used for one cross-check: its front view's cabin is
0.184 to 0.191 of its rotor's diameter (line centres to line edges), which at the OH-6A's
published 26 ft 4 in rotor is **1.48 to 1.53 m** -- the same as [FOX]'s front view (1.525 m).

**[NPS]** "Modeling the OH-6A using FLIGHTLAB and helicopter simulator considerations", Naval
Postgraduate School thesis, **public domain** (US Government work), on Commons as
[`Modeling the OH-6A using FLIGHTLAB and helicopter simulator considerations (IA modelingohausing109456038).pdf`](https://commons.wikimedia.org/wiki/File:Modeling_the_OH-6A_using_FLIGHTLAB_and_helicopter_simulator_considerations_(IA_modelingohausing109456038).pdf).
For the OH-6A: main blade chord 7.21 in with its tab (NACA 0015), tail rotor 4.25 ft two-bladed
with a 4.81 in chord, upper fin 50 in span, 24 degrees swept, 14.2 in root chord 3 in thick;
lower fin 27.4 in span, 12.5 degrees swept; a rigid fuselage of 2,200 lb with roll, pitch and yaw
inertias of about **306, 875 and 689 slug ft2** (415, 1,186 and 934 kg m2) -- a garbled table in
the text layer, read as those three in that order; check the PDF's page before relying on them.
**These are an OH-6A's.** The blade chords are used here because [FOX]'s blades are drawn fat;
the inertias are for step 2.

The drawings, the thesis and the Wikipedia wikitext are in
`~/godotgames-drafts/2026-09-17/cockpit-littlebird/research/`; none is incorporated into the game.

| file | Commons page | licence |
|---|---|---|
| `mh6_fox52.svg` | Boeing MH-6 orthographical image.svg | CC BY-SA 4.0, FOX 52 |
| `md500e_fox52.svg` | McDonnell Douglas MD 500E orthographical image.svg | CC BY-SA 4.0, FOX 52 |
| `oh6a_schema.png` | Hughes OH-6A Cayuse schema.png | public domain |
| `nps_oh6a.pdf` | Modeling the OH-6A using FLIGHTLAB ... .pdf | public domain (US Government) |

## The envelope, published

**[W]** Wikipedia, "MD Helicopters MH-6 Little Bird", its `{{Aircraft specs}}` for the MH-6,
read 2026-09-17 through the MediaWiki API (`action=raw`). Its own sources: *U.S. Army Aircraft*
(Harding, 1997) and MD Helicopters' MD 530F data sheets.

| | [W] | metres | the model |
|---|---|---|---|
| Main rotor diameter | 27 ft 4.8 in | 8.352 | **8.352** -- the scale, by definition |
| Fuselage length, "fuselage only" | 24 ft 7.2 in | 7.498 | 7.443 drawn nose to T-tail, **-0.7 %**, not fitted |
| Length "including rotors" | 32 ft 7.2 in | 9.936 | 9.898, **-0.4 %**, not fitted |
| Width | 4 ft 7.2 in | 1.402 | **1.402** -- the pod, by choice (below) |
| Height | 8 ft 9 in | 2.667 | 2.979 to the hub's top, as drawn (below) |
| Crew | 2 | | 2, side by side |
| Maximum take-off weight | 3,100 lb | 1,406 kg | `DRAFT_GEOMETRY` |

## The scale, and the two numbers that check it

**The drawing is scaled by ONE published figure: the rotor.** The side view's blade tips are
x 223.75 and 477.44, 253.69 units, for [W]'s 8.352 m: **0.032921 m a unit**. The front view's
rotor is also 253.69 units, to the hundredth. Nothing else was fitted.

Then two figures the scale was never set by come back:

- **the fuselage**, nose (x 288.98) to the T-tail's endplate (x 515.08): 7.443 m against [W]'s
  7.498 -- 0.7 per cent;
- **the length with the rotors**, a blade's tip ahead of the hub (x 351.74) to the tail rotor's
  tip aft of its own (x 501.70 + 23.89): 9.899 m against [W]'s 9.936 -- 0.4 per cent.

That is the "two references that never saw each other" test (`modelling_here.md` section 3):
the length is right because the rotor is, not because it was tuned.

## What the drawing gets wrong, and what was done about each

- **The plan view's rotor blades are 7.8 per cent short** of its own side and front views (233.9
  units tip to tip for two near-level blades against 253.7). So the blades are not measured off
  the plan; they are [W]'s diameter and [NPS]'s chord. The plan's FUSELAGE is at the side view's
  scale: its roof windows (plan y 97.39 to 115.18) land on the side view's (x 321.88 to 340.42)
  to half a unit with no offset, so **plan y maps to side x by `plan_x(y) = 288.98 + (y - 64.87)`**.
- **The plan's widths are 5 per cent wide against its own front view**, on two features: the cabin
  (1.603 m against 1.525) and the skid track (0.988 m out against 0.937). So plan widths are
  multiplied by `PLAN_X` = 23.17 / 24.34.
- **The front view's heights are 4 per cent squashed** against the side view (the cabin 53.55
  units tall against 55.78). So every height comes from the side view, and the front view gives the
  SHAPE of a section only: seven depth shares and half-width shares a side.
- **The blades are drawn 0.26 m in chord**, fat for any Little Bird. The model uses [NPS]'s
  0.183 m, the OH-6A's; the MH-6M's own blade is not published anywhere an agent could read.
- **The whole T-tail is drawn 0.06 to 0.12 m to starboard** of the boom in both plan and front.
  Nothing else in the drawing is off the centreline; the offset is left out and written here.

## Two figures the model does NOT take from the drawing, and why

**THE WIDTH.** [FOX] draws the pod 1.525 m across (front) and 1.603 m (plan), and [OH6] agrees at
1.48 to 1.53. [W] says 1.402 m. The Wikipedia figure has no stated datum -- `modelling_here.md`
section 2 is clear that a figure without one is not yet evidence -- but it is the manufacturer's
data sheet's number, and both drawings are traced art with the errors above. **The user asked for
the small size and for the pilots packed close, so the pod is the published 1.402 m**
(`POD_WIDTH_SCALE` = 0.875 on the plan's widths), 8 per cent narrower than [FOX]'s front view. The
overlays `cockpit-littlebird-10-front-...` and `-11-top-...` show exactly that difference. Both
players still fit (`tests/littlebird.gd`), so nothing was widened for them. **If a source with a
stated datum turns up and says 1.5 m, this is the one number to change.**

**THE HEIGHT IS AS DRAWN, and disagrees.** [FOX]'s hub top is 2.979 m over the skids, its rotor
plane 2.751 m and its T-tail's top 2.992 m, against [W]'s 2.667 m. [W]'s figure is the MD 530F's
data sheet's, standard gear; an MH-6 stands on taller gear that carries the benches, and the
drawing is of an MH-6. The difference, 0.31 m, is reported rather than scaled away: no view of
the drawing gives any reason to shrink the gear, and scaling heights alone would have made the
egg 11 per cent squatter than every view of it.

## ESTIMATES, and what they were reasoned from

- **The crew's eyes**: x 328.5, y 237.3 in the drawing -- 1.30 m aft of the nose, 1.99 m over the
  skids, 0.30 m either side of the centreline (0.60 m apart, the pilot to starboard as in every
  MD 500). Reasoned from the front door's opening (the eye 0.15 m under its top and 0.25 m ahead
  of the pillar behind it), and then PINNED by the game's seat convention: a seat's anchor is
  1.35 m under its eye and must be inside the craft (`shell_room`), and the head wants 0.25 m of
  roof (`seat_room`). Step 1's eyes (y 238.5, 0.33 m out) put the anchor 6 cm outside the egg's
  narrowing belly; these are the only eyes the egg allows, to within a couple of centimetres.
  The cabin floor follows the anchor, y 277.09, 1.31 m under the eye -- 0.22 m under the doors'
  sills, where the real aircraft's floor is.
- **The benches' reach outboard**, 0.62 to 1.05 m: the plan hides a bench under the cabin's bulge.
  Its length and height are MEASURED (the side view's plank, rect4240: x 328.75 to 372.75, y 277.47
  to 279.97, 1.45 m long, 0.63 m over the ground).
- **The instrument console**, the paint, the tail rotor's gear ratio.

## Datum and axes

Forward is `-Z`, up is `+Y`, one Godot unit is one metre. `LittleBirdAirframe` works in [FOX]'s
own side-view coordinates: `station(x)` and `height(y)`, with the box's front face at the nose
(x 288.98) and its bottom at the skids (y 297.86). **The simulation stays authoritative** for the
box, the mass, the seats and every pose; until an MH-6 kind exists the box is `DRAFT_GEOMETRY`.

## Outstanding

- A drawing or photograph with a stated datum for the **pod width** (above).
- The **MH-6M's blade chord** and its **tail rotor's** diameter and chord: the model's are an
  OH-6A's chord and [FOX]'s 1.57 m disc.
- **A photograph of the benches from above or ahead**, for how far out they reach.
