# Lockheed C-130H and AC-130U visual reference

Kind `gunship` is drawn as a Lockheed AC-130U Spooky since 2026-09-19 (`lane/liners`), by
`objects/vehicles/hercules_airframe.gd` with `armed` set; the same class with `armed` false is the C-130H transport, which
becomes a kind of its own in the lane's C++ step. The airframe is drawn by `objects/vehicles/jetliner_airframe.gd`, the
builder the 737 and the 747 share. The runtime exterior is an original procedural model made from Godot primitives. It
contains no downloaded mesh, photograph, texture, trademark, unit marking or line of any drawing.

**Why the H**: the AC-130U -- whose 25 mm GAU-12, 40 mm Bofors and 105 mm howitzer the simulation already fires
(`gun_of`) -- is a converted C-130H. The AC-130J carries two guns, not three, and the C-130J differs from outside mainly in
its six-bladed propellers.

## The authority for the shape

**[LM]** Lockheed Martin, *C-130J Super Hercules Pocket Guide*, page 6, "General Arrangement" (PDF page index 4),
`https://www.lockheedmartin.com/content/dam/lockheed-martin/aero/documents/C-130J/C130JPocketGuide.pdf`. Plan, side and
front of the **C-130J-30** drawn as VECTORS (grey fills over dark outlines), with printed dimensions: length 112 ft 9 in
(34.37 m), span 132 ft 7 in (40.38 m on the drawing; 40.41 in the guide's table), height 38 ft 10 in (11.84 m), tailplane
52 ft 8 in (16.05 m), fuselage 14 ft 2 in (4.32 m), main-gear track 14 ft 3 in (4.34 m), nose gear 11 ft 6 in (3.50 m)
aft of the nose, main gear 40 ft 4 in (12.30 m) behind it. Copyright Lockheed Martin; **used to MEASURE, not
incorporated**.

**[WP]** Wikipedia, "Lockheed C-130 Hercules": the C-130H 29.79 m long, 40.41 m span, 11.84 m high, 34,382 kg empty,
70,305 kg maximum take-off; its four-bladed Hamilton Standard propellers, 13.5 ft (4.11 m) across; and the -30 stretch,
"a 100 in (2.5 m) plug aft of the cockpit and an 80 in (2.0 m) plug at the rear of the fuselage".

**[JJ]** Jetijones, "Lockheed Martin AC-130U Line Drawing" and "Lockheed C-130H Hercules Line Drawing", Wikimedia Commons,
CC BY 3.0: vector three-views, an INDEPENDENT reference, studied for the AC-130U's guns and as a cross-check on the H.

## Reading [LM]: its views are not at one scale

`measure_views.py` redraws the page from its filled paths alone (`craft/airliner/acaps.py`'s `filled_page`), which drops
the dimension lines. **Scaled by the printed 34.37 m length, the plan and the side disagree by 8.6 per cent** (the side is
drawn larger), so each is scaled by the length separately, and each then checks against printed figures it was not set
from:

| cross-check | measured | printed | |
|---|---|---|---|
| span, plan | 40.149 m | 40.38 | -0.57% |
| fuselage width, plan | 4.179 | 4.32 | -3.3% |
| height, side | 11.619 | 11.84 | -1.87% |
| wheelbase, side | 12.341 | 12.30 | +0.33% |
| nose gear aft of the nose, side | 3.282 | 3.50 | -6.2% |
| height, front (at the side's scale) | 11.997 | 11.84 | +1.3% |
| fuselage over the sponsons, front | 4.470 | 4.32 (fuselage) | +3.5% |
| **span, front (at the side's scale)** | **36.65** | 40.38 | **-9.2%** |
| **main-gear track, front** | **3.54** | 4.34 | **-18.3%** |

**The front view is at the side's scale, and its wing and gear are drawn short and narrow.** So it is read for heights
and the fuselage's section only. [JJ]'s front view has the same fault: two artists drew the same wrong wing, and neither
front view can be scaled by its span.

## From the J-30 to the H

The -30 is the H with its two plugs: stations aft of 7.0 m lose 2.54 m, and aft of the -30's 19.4 m lose 4.57 in all.
The printed lengths agree to a centimetre (34.37 - 4.57 = 29.80 against the H's 29.79), and so do the H's own figures:

- the wheelbase 12.30 - 2.54 = **9.76 m against the H's 9.77**;
- [JJ]'s AC-130U drawing, scaled by 29.79 m, puts the main wheels at 12.45 and 13.99 m and the keel's climb to the ramp at
  17.4; the model has 12.50 and 14.03 (the printed wheelbase) and 17.43.

And the plugs can be put back: `HerculesAirframe.stretched` draws the J-30, and `overlay_views.py` lays it over [LM] at
each view's own scale at x1.000. The two silhouettes agree over **97.1 per cent** of their union from the side and
**95.0** in plan. The front's 62 is the drawing's short wing, above.

## Measured off [LM] (H stations: metres aft of the nose tip)

| shape | measured |
|---|---|
| wing leading edge | straight across at 11.78 to 7.0 m out, then back 0.024 a metre (1.35 degrees) to the published 20.2 m tip |
| wing trailing edge | 16.81 to 6.0 m out, then forward 0.137 a metre |
| wing, front | lower surface 4.0 m up inboard rising to 4.5 at the tip; upper 5.1 at the root |
| nacelles, plan | 4.52 to 5.59 m out and 9.77 to 10.82; from the front a tall oval from 2.5 m up |
| propellers | plane 9.45 m aft, blade tips 6.0 m up in front: axis 3.85 m up, half a metre over the nacelles' middle |
| tailplane | leading edge 24.012 + 0.264 x out (14.8 degrees), trailing edge 28.882 - 0.156 x out, tip 8.0 m out, 4.85 m up |
| fin | leading edge 19.787 + 0.578 x height, trailing edge 29.672 - 0.1655 x height (raked forward), tip 11.62 m up |
| fuselage | keel 0.60 m, crown 4.68, climbing aft of 17.43 to the tail cone; the nose tip 2.18 m up |
| sponsons | 2.56 m out between 0.66 and 2.30 m up, 9.9 to 16.9 m aft |

## ESTIMATE

- The guns' stations off [JJ]'s AC-130U plan and side (the 25 mm at 7.7 m, forward of the wing; the 40 mm over the
  sponson's aft end at 15.9; the 105 mm at 17.1), their heights and how far each barrel reaches out. All out of the PORT
  side. They run out and stow (`set_guns`), and are aimed from the gunners' mounts (`aim_guns`).
- The sensor turret under the port side of the nose.
- The ramp's hinge at the cargo floor's end (17.43 m, where the keel starts to climb), its 31.5-degree travel to the
  ground, and the upper door's 22 degrees up into the tail. The cargo floor 1.04 m up.
- The tyres (0.86 m twin nose wheels, 1.14 m tandem mains); the mains RISE STRAIGHT UP into the sponsons, behind doors.
- The flaps and ailerons' shares of the chord; the crew's eyes 0.55 m either side, 3.4 m aft and 3.9 m up.
- The paint: dark grey on the gunship, lighter on the transport, a black radome. No unit's marks.

## Datum and axes

- origin: the centre of `HerculesAirframe.GEOMETRY`, 4.32 x 4.68 x 29.79 m; forward `-Z`, up `+Y`, metres.
- The C++ shape is the drawing's since the lane's C++ step (2026-09-19): the box `HerculesAirframe.GEOMETRY`, 55 t, the
  pilot under the drawn eye and the three gunners on the cargo floor beside their guns at 8.5, 15.1 and 16.5 m, forward
  of the ramp's hinge. It was 4.6 x 4.6 x 29.8 m and 20 t, with the gunners at 16.5, 19.1 and 21.9, two over the ramp.
  The handling tuned at 20 t is carried to 55 by the mass ratio (`carry_to_mass`).
- THE ROUNDS LEAVE THE DRAWN MUZZLES: `gun_of`'s three mounts are on the drawn skin (1.954, 2.152 and 2.008 m out,
  measured off `skin_out`) and its barrels are the drawn reach, and `HerculesAirframe.gun_mount` draws the guns from
  them. `tests/hercules.gd` holds each mount on the skin within 5 cm.
- THE GUNS STOW: the gunship's Mode channel, "stow guns", a knob at each gunner's station, mirrored onto the craft's
  outside flags (bit 2) so every machine draws them in, and a stowed gun does not fire (`tests/gun_stow.gd`).
- The transport is kind `transport` (`craft/transport/sources.md`), the same airframe unarmed.

## Research files and licences

In `~/godotgames-drafts/2026-09-19/cockpit-liners/research/`, none incorporated into the game:

| file | source | licence | used for |
|---|---|---|---|
| C130JPocketGuide.pdf | Lockheed Martin | Lockheed Martin copyright, published | every MEASURED figure |
| C-130Brochure_NewPurchase_May2020_Web.pdf | Lockheed Martin | copyright, published | the -30's printed dimensions |
| Lockheed_Martin_AC-130U_Line_Drawing.svg | Jetijones via Commons | CC BY 3.0 | the guns; a cross-check on the H |
| Lockheed_C-130H_Hercules_Line_Drawing.svg | Jetijones via Commons | CC BY 3.0 | studied |
| Lockheed_Martin_C-130J_Super_Hercules.svg | Jetijones via Commons | CC BY 3.0 | studied |
