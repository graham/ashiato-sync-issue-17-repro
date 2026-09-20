# Schempp-Hirth Duo Discus visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/sailplane_airframe.gd`). It contains no downloaded mesh, photograph,
drawing, texture, trademark, registration or competition marking.

**It is a Schempp-Hirth Duo Discus**: a 20 m two-seat high-performance sailplane, the two pilots in
tandem under ONE canopy, a T-tail, and a wing whose inner panels sweep slightly forward. The
winglets are the Duo Discus X's and XL's. It replaced the DG-1001 Club on 2026-09-18
(`lane/sailplane`). The user asked for a sailplane "like the photos on this page", which is the
cover of Vittorio Pajno's *Sailplane Design Example* showing his single-seat V 1/2 Rondine, "and it
should be a two seater as well". **The cover is copyrighted and nothing is measured from it.** It
gives the LOOK: long slender wings turned up at the tips, a slim boom, a T-tail, and a big bubble
canopy over a reclined pilot. The Duo Discus is the real two-seater with that look.

## The authorities

**[SH]** Schempp-Hirth Flugzeugbau, *Duo Discus Flight Manual*, October 1993 (revisions to
February 1996), LBA-approved. The Geelong Gliding Club hosts a scan at
`https://ggc.org.au/docs/aircraft/fmanual/Duo%20Discus%20Flight%20Manual.pdf`.

**It is the maker's own document, used only to MEASURE FROM, and nothing from it is in the game.**
It is not freely licensed, and there is no freely licensed alternative. Commons holds no three-view
of the Duo Discus, the Arcus, the DG-1000, the ASG 32, the ASH 25 or the ASK 32 (searched by
category and by title, 2026-09-18). The only modern two-seater with one is the ASK 21
(`File:Schleicher ASK 21 Three-view.svg`, CC BY 4.0), a 17 m trainer with no winglets and a
two-piece canopy, which is not the look asked for. The lane before this one measured the DG off
DG's own manual in the same way.

- **1.4.3, technical data:**
  - wing: span **20.00 m**, area **16.40 m2**, aspect ratio **24.4**, MAC **0.875 m**;
  - fuselage: length **8.62 m**, width **0.71 m**, height **1.00 m**;
  - mass: empty about **420 kg**, maximum all-up **700 kg**.
- **1.5, three-side view** (page 12 of the scan). Measured below.
- **5.2.2, stall speeds** (IAS, straight and level):
  - airbrakes closed: **58 to 60 km/h at 700 kg**, **35 to 45 km/h at 499 kg**;
  - airbrakes out: 62 to 66 km/h at 700 kg;
  - the manual warns the airspeed indicator is "heavily oscillating" at minimum speed.
- **5.3.2, flight polar** (DLR/Idaflieg 1994, at 609 kg and 37.1 kg/m2):
  - minimum sink **0.58 m/s**;
  - best L/D **45 at 100 to 103 km/h** (27.8 to 28.6 m/s).

**[W]** Wikipedia, "Schempp-Hirth Duo Discus", XL specifications: span 20.00 m, length 8.73 m,
**height 1.60 m**, area 16.4 m2, AR 24.4, empty 410 kg, gross 700 kg, glide 46 to 47, sink
0.58 m/s. Only the height is used from it, and it is a PARKED height (see below).

**[P]** Photographs, for study only and never incorporated. They are kept in
`~/godotgames-drafts/2026-09-18/cockpit-sailplane/research/`.

| Commons file | licence | what it was used for |
|---|---|---|
| `Duo Discus X hinterer Sitz.JPG` | CC BY-SA 3.0 | the rear seat: its panel on the back of the front seat, the stick between the knees, the view over the front pilot |
| `Duo Discus x vorderes Cockpit.jpg` | CC BY-SA 3.0 de | the front cockpit |
| `Schempp-Hirth DuoDiscus.jpg` | CC BY-SA 2.5 | the winglets in flight |

## Measuring the three-view

`measure_duo.py`, beside this file, renders [SH] page 12 at 300 dpi and turns it upright. It then
re-derives every table in `SailplaneAirframe` from the pixels, by LINE CENTRES, without reading any
figure from this write-up. Give it the manual's path and it prints the checks below.

**The scale comes from ONE published number, the 20.00 m span**, taken from outer tip edge to outer
tip edge in the plan view: **132.95 px a metre**. The lines are 4 px wide, so nothing off the drawing
is better than about 0.03 m.

**The checks that the scale is honest.** Each one tests something the span did not set.

| check | drawn | published | |
|---|---|---|---|
| side view, nose to rudder, at the span's scale | 8.605 m | 8.62 | 0.2 per cent |
| front-view span against plan-view span | 0.9981 | 1 | the scan is isotropic |
| plan chords integrated, line centres, root chord carried to the centreline | 16.67 m2 | 16.40 | 1.6 per cent over |
| fuselage width, plan view at the cockpit | 0.69 m | 0.71 | |
| fuselage width, front view | 0.72 m | 0.71 | |
| belly to crown at the canopy's highest | 1.03 m | 1.00 | |

**THE PUBLISHED AREA IS THE STRONGER FIGURE**, as it was for the DG. The manual prints it, and it
agrees with the manual's own span and aspect ratio (20^2 / 16.40 = 24.39). So every chord is scaled
about its quarter-chord point by `SailplaneAirframe.chord_scale()`. That factor is **computed** from
the table and the area (0.980), never typed. `tests/sailplane.gd` integrates the drawn triangles and
gets 16.397 m2.

**AND A THIRD FIGURE THAT NOBODY SET OUT TO PRODUCE.** The manual draws the aeroplane LEVEL, with the
tail wheel 0.29 m off the ground. [W]'s 1.60 m height is a parked one, on both wheels. Turn the drawn
aeroplane nose-up about the drawn main wheel until the drawn tail wheel touches the ground (3.16
degrees), and the tailplane's top stands at **1.601 m**. The wheels and the fin came off the drawing
and the height from a different source; none of the three was chosen to meet the others.

### What the drawing shows, and the model draws

- **The wing's inner panels sweep FORWARD.** The leading edge moves 0.22 m forward from the root to
  5 m out, then runs straight; the trailing edge tapers all the way. This is the Duo's trademark, and
  it puts the back-seat pilot ahead of the spar.
- **The wing has 4.2 degrees of dihedral from 1 m to 8 m out**, then the tips turn up about 11
  degrees over their last two metres (front view, line centres). That is the drawn, unloaded wing.
- **The ailerons run from 4.55 to 9.0 m out**, with 0.18 m of chord inboard and 0.10 m outboard. The
  wing's parting is at 8.05 m. **The airbrake slots run from 2.95 to 4.30 m out**, at 62 per cent of
  the chord.
- **The canopy is one piece**, from 0.65 m aft of the nose to 2.75 m, with its sill at 0.75 to
  0.80 m.
- **The T-tail**: a tailplane 3.13 m across sits on the fin's top at 1.84 to 1.91 m. The elevator's
  hinge runs straight across at 8.34 m aft of the nose. The fin's leading edge leans back 19.5
  degrees, and the rudder hangs 0.12 m below the end of the boom.
- **The wheels**: a 0.38 m main wheel under the wing's leading edge, a small nose wheel under the
  front seat, and a tail wheel under the fin.

### Estimates, and what would settle them

- **The winglets**: 0.40 m tall, 0.30 m of chord at the foot and 0.14 m at the top, in day-glo. These
  come from photographs of the X and XL, because the 1993 drawing has plain round tips. The tip is
  squared off from 9.4 m out into the winglet's foot; the drawn rows are kept in the airframe's
  comment. A three-view of the XL or XLT would settle both.
- **How high the airbrakes stand when open**: 0.16 m. The manual gives no figure.
- **Where along the canopy the eyes are**: 1.50 and 2.50 m aft of the nose, 1.00 m apart, taken from
  the cockpit photographs.
- **Aileron, elevator and rudder travel**: +-20, 25 and 30 degrees, which is usual for a sailplane.
- **The airfoil's thickness**: 14 per cent at the root to 12 at the tip. The front view's line
  centres give 12 to 15 per cent.

## Deviations, each on purpose

- **THE CANOPY IS A BUBBLE 0.10 m TALLER than the Duo's** (`CANOPY_RAISE`). It runs across the
  cockpit and is faired out by x = 3.4, which is also the Rondine's look. The reason is the game's
  rig: it puts an eye 1.35 m over the seat anchor, and `tests/seat_room.gd` wants 0.25 m of glass
  over that eye. The Duo's crown is only 0.90 m over its belly at the front seat, because a real
  pilot lies back with the eye about 0.8 m over a pan on the belly. See
  `SailplaneAirframe.crew_eyes` and the seat's recline.
- **Winglets on the 1993 airframe**, as above.

## Datum and axes

The craft origin is the centre of the native box (`glider_shape`, `cockpit_world.cpp`). Forward is
-Z, up is +Y, and one unit is one metre. `SailplaneAirframe.at(out, x, y)` puts the drawing's nose on
the box's front face and its ground line on the box's floor. The native collision, the lift model,
the mass and the two tandem station identifiers stay authoritative.

---

## Superseded: the DG-1001 Club (lane/glider, 2026-09-17)

This section is kept as the record of how the DG was measured. Two of its findings are why this model
is held the way it is: a published height that a stub gun was meeting, and a published area that
outweighed four measured chords. None of it describes the aeroplane the game draws now.


The runtime exterior is an original procedural model made from Godot primitives. It
contains no downloaded mesh, photograph, texture, trademark, or competition markings.

DG Aviation's official [DG-1001 Club specification](https://www.dg-aviation.de/en/dg1001club_en-2/)
gives an 8.6 m length, 1.8 m height, tandem seating, fixed main and nose wheels, winglets,
and a 750 kg maximum takeoff mass. The standard span is 18 m and the manufacturer lists
an optional 20 m outer-wing set. The game's established 20 m wing therefore represents
that published option; the visual fuselage still has to fit the real 8.6 m envelope.

Datum and axes: the craft origin is the centre of the aircraft envelope, forward is
`-Z`, up is `+Y`, and one Godot unit is one metre. Native collision, lift model, and the
two stable tandem station identifiers remain authoritative.


### The drawn shape, part by part, and what each figure is worth

Added 2026-09-17 (`lane/glider`), when the exterior went from a flat constant-height wing and
a single bubble canopy to the wing, winglets and two-piece tandem canopy of the real aircraft.
`tests/soaring.gd` measures every figure below off the drawn triangles in the craft's own
frame and holds it to the reference typed in that suite, so the model and the reference can
disagree. No mesh, photograph, texture or drawing is incorporated; nothing was downloaded into
the repository.

#### The authorities, and which is stronger

| What | Figure | Where from |
|---|---|---|
| Span (20 m option) | 20.00 m | DG's [DG-1001 Club page](https://www.dg-aviation.de/en/dg1001club_en-2/) |
| Length | 8.57 m manual and TCDS; 8.6 m on DG's page | Flight manual DG-1000S section 1.5; EASA TCDS A.072 |
| Height | **1.83 m** manual and TCDS; **1.8 m** DG's page | as above |
| **Wing area, 20 m span** | **17.53 m2** | Flight manual DG-1000S section 1.5; EASA TCDS A.072 issue 14 |
| **Dihedral** | **2.5 degrees**, leading-edge line, inboard panel to the parting | DG-1000T maintenance manual section 1.1, "Wing and tailplane setting data" |
| Leading-edge sweep | **0 degrees** between y = 3490 and y = 6979 mm | as above |
| Wing parting | y = **8.6 m**, four tip options incl. 20 m elongations with winglets | Flight manual section 1.4; TCDS |
| Fuselage | width **0.73 m**, height **1.0 m** | Flight manual section 1.5 |
| Canopy | "**Large 2 piece canopy** for very good in-flight vision" | Flight manual section 1.4 |
| Tailplane span | 3.2 m | Flight manual section 1.5, and dimensioned on the three-view |

**The USAF TG-16A is the DG-1001 Club** -- the TCDS covers the Club as the fixed-undercarriage,
nose-wheel version of the DG-1000S/DG-1001S -- so Commons TG-16A photographs are genuine Club
references and all the fuselage figures above are the Club's. Only the undercarriage differs.

**A single source is a claim.** Where these disagree: the manual and the TCDS both give
**1.83 m** of height where DG's own Club page gives 1.8; the model draws **1.80** because that
is the figure `tests/aircraft_fidelity.gd` has always held and the 30 mm is not worth a
migration -- but 1.83 is the better-attested number and this is where to start if it is ever
revisited. Length is 8.57 against 8.6, the same rounding. **Wikipedia is wrong about this
aircraft and should not be used for it**: it gives 1.6 m of height, and its specification block
pairs an 18 m span with 17.5 m2 and an aspect ratio of 22.8, which are the **20 m** figures --
18 squared over 17.5 is 18.5, not 22.8.

**A caption is a claim too.** The best cockpit close-up on Commons,
`File:DG-1000 AERO Friedrichshafen 2025-0611.jpg` (CC BY-SA 4.0), is captioned "DG-1000" but
shows a nose wheel and fixed gear, so the airframe is Club-type and the caption is looser than
the aeroplane. `File:TG-16A Short Final (2) - Aviation Nation 2019.jpg` (CC BY-SA 4.0) is a
clean Club side profile captioned only by its military designation. Neither is incorporated.

#### The wing

**The dihedral is published and the model draws it: 2.5 degrees.** The figure is for the
**inboard panel up to the parting at y = 8.6 m**; the 20 m elongation's own dihedral is not
published anywhere legible, so the model continues the same 2.5 degrees to the tip. That puts
the tip **61 mm higher** than a flat elongation would, and that 61 mm is the whole of the
uncertainty. An earlier version of this model drew 3.07 degrees from no source at all. Measured
independently off the manufacturer's front view at **2.4 +- 0.5 degrees**, which agrees.

**Applied as a rise at each station, never as a rotation of the panel.** A rotated 10 m plank
spans 10 cos(theta): at 2.5 degrees the aeroplane would quietly have lost 9.5 mm of span while
looking right, and the span is a published fact a visual choice must not move. For the same
reason the winglet's outer face sits exactly **on** the 20 m span -- centred on the tip it
would make a 20 m aeroplane 20.05 m across.

**The leading edge is straight and the trailing edge does the tapering**, because the setting
data gives 0 degrees of leading-edge sweep. The model drew it the other way round until this
change, with the tip set **back** by 0.18 m: a wing swept the wrong way.

**The planform is a double taper, and its one free number is computed from the published
area.** Chords measured off the manual's plan view, calibrated on the printed 20000 mm:
root **about 1.13 m**, **about 0.60 m** at the y = 8.6 m parting, **about 0.34 m** at the 20 m
tip. Drawn as a straight taper from root to parting, that integrates to **16.19 m2** against
DG's published **17.53** -- 7.6% short. **The published area is the stronger figure**: it is
printed in two independent documents and is consistent across all three span options, while the
chords are pixel measurements off a scan with no text layer. So the shortfall is taken up in
the one place the sources are silent -- how far the inboard wing runs at full chord before it
narrows -- and that station is **computed from the area rather than typed**
(`VehicleView.sailplane_full_chord_out_to`, which gives 2.52 m). The manual's zero-sweep band
begins at y = 3490 mm and holding the root chord that far out overshoots to 18.04 m2, so the
answer is between, and asking the area for it is the only way four numbers that must agree can
be kept from disagreeing. `tests/soaring.gd` integrates the **drawn triangles** and gets
17.530 m2, which is how the arithmetic is known to have closed.

**Winglet height is not published where it can be read.** 0.44 to 0.51 m measured off the 20 m
front view at 7.145 mm a pixel, the junction ambiguous at that scan resolution; the model draws
**0.47 m** and this sentence is what that is worth. Note the 18 m front view is drawn with a
winglet on one tip and none on the other -- both are certified options.

#### The canopy, and a disagreement worth keeping

**Two pieces, which is published**, with the inter-canopy frame about 1.7 m aft of the nose.
So the model draws a front canopy, a frame and a rear canopy -- which is also the clearest
thing about this aeroplane from outside that says two seats. It drew one 0.88 m sphere over
both crew until this change.

**No canopy dimension is published.** Glazing measured off the manufacturer's side view at
**7.20 mm a pixel** -- the scale taken from the printed 8570 mm overall length and cross-checked
against the printed 2795 mm nose-to-main-wheel, agreeing to one pixel -- runs from **about
0.5 m to about 2.9 m aft of the nose**, about **2.40 m plus or minus 0.15** of glass. The model
draws 2.40 m.

**And it is not in the same place as the real aeroplane's, because the seat poses are not.**
The simulation puts the crew **3.20 m and 4.90 m aft of the nose, 1.70 m apart**, against a
real pair about 0.95 m apart inside a cockpit that ends 2.9 m from the nose. The canopy is
drawn over **the seats**, because the crew are what has to be under glass. The disagreement is
named here and **printed by `tests/soaring.gd` on every run** rather than being quietly split
between the two: a seat pose is native shape-table data and moving it is its own migration.
`SkyhawkAirframe.cabin_room` sets the precedent -- a declaration that honestly reports a craft
it does not yet fit is worth more than one that waits for the fix.

**The drawn fuselage is 1.06 m wide against a published 0.73 m**, because it is derived from
the native collision half-extents (0.55 x 0.70 x 4.10) rather than from the aeroplane. That is
worth knowing before anybody tries to make this craft enclose its crew: `tests/shell_room.gd`
lists the glider as one of ten craft that enclose nobody, with the reason "the sailplane's pod
is narrower than the station at every height" -- and the station's shell is **0.86 m** wide,
which is wider than the real aeroplane's fuselage. Widening the canopy to swallow the station
would draw a DG-1001 that is not one. **The station is the thing that is the wrong size**, and
that is a station migration rather than a modelling job.

#### The height

**The published height is the fin, and the model now carries it there.** A T-tail sailplane's
overall height is the top of its fin. Until this change nothing in the drawn airframe reached
it: the model stood **1.69 m** and `tests/aircraft_fidelity.gd` was green anyway, because
`VehicleView._build_turret` invents a stub gun mount on any craft with no turret seat and that
mount's **anonymous** 0.36 m dome sat at y 0.98 -- the highest point of the aeroplane, and so
the thing the 1.80 m contract was actually measuring. A DG-1001 Club with a machine gun on its
spine, visible in `screenshots/2026-09-17/cockpit-craft-glider.png` as the dark tube over the
fuselage. **A dimension has to be carried by the thing it names**, so `soaring.gd` asks which
*part* is the tallest and not merely how tall the aeroplane is.

#### What would settle what is still measured rather than read

A better scan of flight manual page 1.6 -- or the DG-1001 Club's own manual, which DG lists but
does not publish for download -- would give the canopy and the winglet directly. Commons
category *Glaser-Dirks DG-1000* holds 27 files and **no three-view and no head-on front view**,
so the manufacturer's own drawing is the only front view there is. The 18 m and 20 m wings are
different outer panels: a figure taken from the wrong one is a figure about a different
aeroplane.
