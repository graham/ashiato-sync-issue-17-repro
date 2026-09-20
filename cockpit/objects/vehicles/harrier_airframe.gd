@tool
extends Node3D
class_name HarrierAirframe
## A McDONNELL DOUGLAS / BAe AV-8B HARRIER II NIGHT ATTACK, DRAWN. Its first-glance features are the shoulder-mounted
## wing with eleven degrees of ANHEDRAL, the leading-edge root extensions, the deep twin intakes either side of a
## raised cockpit, and the four nozzles on the flanks. What makes it a Harrier is drawn and MOVES:
## - THE FOUR NOZZLES (`set_nozzle`), two cold forward and two hot aft, chain-synchronised on the real aeroplane and
##   so always at one angle here, swinging from straight aft through the hover stop to the BRAKING STOP past the
##   vertical;
## - THE BICYCLE UNDERCARRIAGE (`set_gear`): a nose wheel and a main wheel on the centreline, with OUTRIGGERS at
##   mid-span -- the thing a generic jet model gets wrong, and the thing that tells a Harrier II from a
##   first-generation aeroplane, which carried them at the wingtips;
## - THE CONTROL SURFACES: ailerons, a single slotted flap, an all-moving tailplane and a rudder;
## - THE REACTION CONTROL JETS at the nose, the tailcone and each wingtip, which do the flying in the hover and which
##   nothing else in this game has;
## - THE LIDS: two longitudinal strakes and a RETRACTABLE FORWARD FENCE under the fuselage, whose whole purpose is to
##   trap the fountain of air rebounding off the ground in the hover.
##
## PRESENTATION ONLY. The simulation owns the size, the flight, the collision, the stations and the wire. This draws.
##
## ORIGINAL GEOMETRY, MEASURED. No mesh, texture, photograph or livery is incorporated. Every figure names its source
## and `craft/harrier/sources.md` carries the licence table:
## - **[SAC]** NAVAIR 00-110AV8-4, *Standard Aircraft Characteristics: AV-8B Harrier II*, October 1986 -- a dimensioned
##   orthographic three-view and a DIMENSIONS table. `craft/harrier/measure_sac.py` and `measure_stations.py`
##   re-derive every MEASURED figure here from the scan ALONE, reading nothing out of this file or out of `sources.md`.
##   Its scale comes off the published 30.33 ft span and nothing else, and NINE published figures it was not scaled by
##   come back within about two per cent. **One pixel is 15.9 mm**, so nothing off it is better than that.
##   *Its own printed SCALE IN FEET bar is a fifth wrong and is not used.*
## - **[NATOPS]** A1-AV8BB-NFM-000 -- the nozzle stops, the reaction controls, the surface travels, the limits.
## - **[WP]**, **[PEG]** -- the -408 engine and the Pegasus's internals.
## - ESTIMATE where nothing gives a figure, saying what it was reasoned from.
##
## STATIONS ARE METRES AFT OF THE NOSE TIP and HEIGHTS ARE METRES ABOVE THE FUSELAGE DATUM, the aeroplane drawn LEVEL.
## THE GROUND IS NOT LEVEL: [SAC] draws the aeroplane level and rakes the ground line 6.5 degrees, so this aeroplane
## PARKS NOSE-UP and `ground_at(station)` returns a raked plane -- `ProwlerAirframe`'s machinery, not the Hawkeye's
## level-tyres convention, which would silently level an aeroplane that is not level (`modelling_here.md` section 5).
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT. The user's direction of 2026-09-17: "a somewhat lower poly look ...
## not too many very round edges", with the E-2D Hawkeye as the reference. Every count here is at or below the
## Hawkeye's for the same kind of part: the FUSELAGE is 12 facets a ring through the measured sections, against the
## Hawkeye's 20; NOZZLE_SIDES 10; WHEEL_SIDES 8; the wing section is six points, as the F-16's is; the fin, tailplane,
## flaps, ailerons, strakes and doors are flat slabs. Every face carries its own normal and nothing is smoothed.

## [SAC] and [NATOPS], agreeing: the published envelope, held by `tests/harrier.gd`.
const LENGTH: float = 14.122
const SPAN: float = 9.245
const HEIGHT: float = 3.551

## [SAC] page 3's DIMENSIONS table, and the wing MEASURED off its page 2 by `measure_sac.py`.
const WING_AREA: float = 21.368        # 230.0 sq ft
const MAC: float = 2.536               # 8.32 ft
const SWEEP_QUARTER: float = 30.62     # degrees, projected, PUBLISHED
const SWEEP_LEADING: float = 36.50     # degrees, MEASURED, 132 stations at 0.78 px rms
const ANHEDRAL: float = 11.0           # degrees, PUBLISHED as "dihedral -11"
const INCIDENCE: float = 3.0           # degrees, PUBLISHED
const ROOT_CHORD: float = 3.533        # MEASURED, the outer panel extended to the centreline
const TIP_CHORD: float = 1.007         # MEASURED
const TAILPLANE_SPAN: float = 4.246    # 13.93 ft, PUBLISHED on the drawing

## THE STANCE. [SAC] prints 6.5 degrees between the aeroplane and its ground line; the drawn geometry measures 6.06
## and the tyre centres 5.95, and the PRINTED figure is used -- this sheet's geometry is demonstrably less reliable
## than its figures (its scale bar is a fifth wrong) and [NATOPS] p96 independently puts the fuselage about six and a
## half degrees nose-up at the hover stop. The disagreement is recorded in `sources.md` rather than buried.
const GEAR_RAKE: float = 6.5

## THE UNDERCARRIAGE, all PUBLISHED [SAC]: a bicycle on the centreline with outriggers at mid-span.
##
## THE NOSE STATION WAS AN ESTIMATE AND IT WAS 1.63 m WRONG, which put the main wheel AHEAD of the wing instead of
## under it -- on a bicycle undercarriage the main wheel's station IS the stance, so this was the largest single
## error on the aeroplane and the overlay's worst disagreement, 1.222 m of leg hanging where the drawing has clean
## belly. It is MEASURED now, and by two instruments that share nothing:
##
##   [SAC] page 2   `measure_sac.stance` fits both drawn tyres sub-pixel and now PRINTS their stations: the nose
##                  tyre's centre is 4.681 and the main tyre's 8.129, at 0.89 and 0.98 px rms on 221 and 252 points.
##   a photograph   `measure_photos.gear_lobes` takes the two lowest points on the centreline of a CC-licensed
##                  hover frame, gear down, and gets stations 4.80 and 8.20. That photograph has never seen [SAC].
##
## The circles were being fitted for a day before anybody printed a centre's station. The measurement was taken;
## the question was never asked of it.
##
## WHY THE MAIN WHEEL LANDS 33 mm AFT OF ITS DRAWN CIRCLE, and why that is not split. The drawing's two centres are
## 3.448 m apart against a PUBLISHED wheelbase of 3.481, and this sheet's printed figures beat its drawn geometry --
## the same rule `GEAR_RAKE` below already follows, on a sheet whose scale bar is a fifth wrong. So the nose station
## comes from the drawn circle, which is its only source, and the separation stays published. Fitting the datum to
## split the 33 mm would leave neither number traceable to anything.
const WHEELBASE: float = 3.481         # 11.42 ft, nose wheel to main wheel
const NOSE_STATION: float = 4.681      # MEASURED, the drawn tyre's centre; see above
const OUTRIGGER_OUT: float = 2.591     # half of the published 17.0 ft "wing gear spread"
const OUTRIGGER_AFT: float = 0.686     # 2.25 ft, the printed offset from the main gear
const TYRE_MAIN: float = 0.330         # 26 in diameter, halved
const TYRE_NOSE: float = 0.330         # 26 in
const TYRE_OUTRIGGER: float = 0.171    # 13.5 in
const WHEEL_SIDES: int = 8

## THE NOZZLES [SAC page 3, POWER PLANT]: "Nozzle rotation angles -- Front 0 deg to 98.5 deg -- Rear 0 deg to 98.5
## deg". Both pairs, one range, which is why the real ones are described as synchronised: [PEG] says they are turned
## by motorcycle chains off one air motor, so they cannot point two ways and neither can these.
##
## THE TRAVEL IS THE SIMULATION'S once the kind exists (`Handling::vector_travel`, as the F-35B's is); until then this
## constant is what it is drawn with, and `tests/harrier.gd` says which it used.
const NOZZLE_TRAVEL: float = deg_to_rad(98.5)
## [NATOPS] p96's detents, which are richer than any other VTOL in this game: aft, a SELECTABLE short-take-off stop
## anywhere from 35 to 75 degrees in five-degree steps, the HOVER STOP at 82, and the BRAKING STOP at 98.5, reached by
## "lifting the nozzle lever over the hover stop and pulling it back along a ramp".
const HOVER_STOP_DEG: float = 82.0
const BRAKING_STOP_DEG: float = 98.5
const STO_STOP_FROM_DEG: float = 35.0
const STO_STOP_TO_DEG: float = 75.0
## WHERE THE FOUR NOZZLES ARE. Their stations are an ESTIMATE -- no table found gives them -- reasoned from the
## engine's PUBLISHED 3.487 m length ([PEG], 137.3 in including nozzles) laid on [SAC]'s cutaway, with the front pair
## at the fan and the rear pair at the turbine. `sources.md` says what would settle them.
##
## THEIR HEIGHT IS THE ENGINE'S CENTRELINE, and it is a judgement with a constraint under it rather than a taste.
## The four ducts leave the Pegasus at its own centreline, so one height serves all four however the body around
## them changes. The body runs 1.60 to 3.30 over the datum at station 5.55 and [WP]'s Pegasus is 1.219 m across, so
## the centreline must sit near the middle of that for the fan to fit inside the drawn skin at all.
##
## IT WAS TRIED AT 2.30 AND THE PICTURE SENT IT BACK DOWN. At 2.30 the elbows swung to the hover stop and finished
## level with the belly, where the gun pods hide them, so the aeroplane at 82 degrees still did not read as a Harrier
## in the hover -- the one attitude nothing else in this game can strike. At 2.05 the exit clears the belly line by
## 0.55 m and four of them are plainly there. The original 1.72 was lower still, but at that height the body is only
## 0.44 m of half-width and the nozzles hung clear of the aeroplane altogether.
##
## THEIR OFFSET IS NOT TYPED AT ALL: `_flank_at` reads it off `SECTIONS`, so each nozzle's root sits ON the skin at
## its own station by construction. It was a typed 1.14, and at 1.72 over the datum the body is only 0.44 m of
## half-width -- so the drums hung in space 0.30 m clear of the aeroplane, which is most of why they read as bolted-on
## discs rather than as part of it. One number, one place: ask the body where its side is, do not keep a roster.
const NOZZLE_FRONT_STATION: float = 5.50   # MEASURED: the joint ring, off a beam-on photograph
const NOZZLE_REAR_STATION: float = 8.35
const NOZZLE_HIGH: float = 2.05
const NOZZLE_SIDES: int = 10

## THE ELBOW. A Pegasus nozzle is a BENT DUCT on a rotating joint, not a drum: the flow leaves the engine OUTBOARD
## and the elbow turns it through a right angle so it leaves AFT, and turning the elbow about that lateral axis
## swings the exit from aft, through down, to 8.5 degrees forward of down at the braking stop. The bend is the whole
## reason a Harrier reads as a Harrier from any angle, and drawing it as a cylinder threw the aeroplane away.
##
## THE AFT REACH IS MEASURED NOW, off photographs, because [SAC] cannot resolve a nozzle at 15.9 mm a pixel and
## this figure was previously reasoned and then sized by rendering and looking. `craft/harrier/measure_photos.py`
## reads a beam-on CC-licensed frame at 3.2 mm a pixel: the front nozzle's JOINT RING is at station 5.502 and its
## EXIT RIM at 6.018, so it reaches 0.515 m aft of the joint. That frame's scale is the published 14.122 m length
## and nothing else, and it is checked against [SAC]'s blow-in doors -- measured at stations 3.65 to 3.88, and
## landing in the photograph at 3.71 to 3.94, sixty millimetres, on a figure that set nothing here. [M]
##
## THE OUTBOARD REACH IS STILL AN ESTIMATE and is now reasoned from a measurement instead of from nothing: at the
## measured radius below, standing the exit 0.19 m outboard of the skin puts the drum's inboard side ON the skin,
## which is where every photograph shows it. The old 0.26 was paired with a radius more than twice too large, so
## the drum spanned from 0.14 m INSIDE the fuselage to 0.66 m outboard of it.
const NOZZLE_AFT_REACH: float = 0.52
const NOZZLE_OUT_REACH: float = 0.19
const NOZZLE_BEND_STEPS: int = 4

## THE FRONT PAIR AND THE REAR PAIR ARE DIFFERENT OBJECTS, and this file said so in prose before the geometry did.
## The front two are the COLD LP-compressor nozzles and the rear two the HOT ones [PEG], and the production AV-8B
## specifically carries ZERO-SCARF front nozzles -- exhaust planes square to the duct, where the first generation's
## were cut obliquely. The rear pair keep the oblique cut. That is a published difference about THIS variant and not
## a modelling flourish, so the two pairs are drawn from two sets of figures.
##
## THE SCARF IS CUT IN THE HORIZONTAL PLANE, NEVER THE VERTICAL, and that is a test's requirement rather than a
## draughtsman's taste. `tests/harrier.gd` reads a nozzle's angle off the mean of its own furthest vertices, so a cut
## that leaves one SIDE longer does not move that mean off the axis, while a cut that left the TOP longer would bias
## it and the check would quietly measure the scarf instead of the lever. The check reads the metal, so the metal is
## not allowed to lie to it.
##
## THE SIZE WAS THE BIG ONE, AND IT WAS MORE THAN TWICE TOO LARGE. The photograph puts the lit drum of the front
## nozzle 0.362 m across, median over its length, 0.372 at its widest; the model drew it at 0.800. Four drums of
## twice the right diameter on the flanks of a fourteen-metre aeroplane is a great deal of what made this read as
## the wrong aircraft, and no check here could see it: every test asked whether the nozzles MOVED together, not
## how big they were.
##
## THE WIDTH NEEDS NO PERSPECTIVE CORRECTION and applying one would make it wrong -- a circle projects to its own
## full diameter along every direction in an image, whatever angle it is seen from. The photograph's vertical
## foreshortening (measured at 0.830) applies to HEIGHTS ABOVE THE DATUM, which are distances, not to a diameter.
##
## IT IS A LOWER BOUND, SAID PLAINLY RATHER THAN PADDED. The drum's top edge runs against the wing root's shadow
## and is crisp; its bottom edge is a shadow terminator on the nozzle's own underside, so the lit extent is as much
## of the nozzle as the sun reached. The drawn radius is the measured half-width and not a rounded-up one, because
## a bound is a measurement and a bound with something added to it is a guess wearing a measurement's clothes.
##
## THE REAR PAIR ARE NOT MEASURED. In all four airborne frames they sit inside the wing root's own shadow -- the
## edge detector finds five clean edges across the front nozzle and SIXTEEN across the rear, which is what noise
## looks like -- and the ground frames that show them beautifully are wide-angle walk-rounds with a person in shot
## and can carry no scale. So they keep the front-to-rear ratio this file already had, applied to the measured
## front figure, and they stay [E]. `measure_photos.py` prints the refusal and its evidence every run.
const NOZZLE_FRONT_ROOT: float = 0.19
const NOZZLE_FRONT_EXIT: float = 0.19
const NOZZLE_REAR_ROOT: float = 0.18
const NOZZLE_REAR_EXIT: float = 0.17
const NOZZLE_REAR_SCARF: float = 0.06
## THE CASCADE OF VANES each nozzle turns the flow with [PEG]: drawn as flat slats across the exit, which is what a
## cascade looks like end-on and costs six triangles a nozzle.
const NOZZLE_VANES: int = 3

## THE AUXILIARY BLOW-IN DOORS, MEASURED off [SAC] page 2's side view at the scan's native 63.0 px/m. A Harrier
## cannot breathe through its intakes alone at low speed, so each duct carries a column of spring-loaded suck-in
## doors that stand open in the hover and shut in cruise. After the nozzles they are the most photographed thing on
## the aeroplane's flank, and nothing in this model had them.
##
## The drawing puts FIVE in a column on each side, occupying stations 3.65 to 3.88 and running from 1.76 to 2.95
## over the datum -- roughly square panels a little under 0.2 m on a side. They are drawn on the bell's own outer
## surface, so their height decides how far out they sit and no second figure is kept for it.
const DOORS: int = 5
const DOOR_FROM: float = 3.65
const DOOR_TO: float = 3.88
const DOOR_LOW: float = 1.76
const DOOR_HIGH: float = 2.95

## THE REACTION CONTROLS [NATOPS Figure 1-1], which names all four and where they sit. Stations are ESTIMATE off that
## cutaway; that they EXIST and what each controls is PUBLISHED.
const RCS_NOSE_STATION: float = 1.25
const RCS_TAIL_STATION: float = 13.55
const RCS_TIP_OUT: float = 4.40

## THE LIDS [SAC page 3]: "two longitudinal strakes and a retractable forward fence mounted on the lower fuselage
## between the nose and main gear ... to improve performance in vertical takeoff or landing", and "fuselage strakes
## are interchangeable with the gun and ammo pack". So the strakes and the gun pods occupy the same two places, one or
## the other; this draws the GUN PODS, which is the armed aeroplane, and the fence forward of them.
const LIDS_FROM: float = 4.30
const LIDS_TO: float = 7.90
const LIDS_OUT: float = 0.56
const FENCE_STATION: float = 4.05
const FENCE_DROP: float = 0.42

## HOW LONG A WHOLE GEAR CYCLE TAKES, seconds, eased by the view as the F-35B's is. The user's rule (2026-09-17): "the
## amount of time isn't important right now, we just need to be able to adjust it".
const GEAR_SECONDS: float = 5.0
## The doors lead the legs, as the F-35B's do: open over the first fifth, the legs over the middle three, shut over the last.
const DOOR_SHARE: float = 0.2

## THE PAINT. USMC Harriers are two-tone grey; this is FS 36320 over FS 36375, ESTIMATE as sRGB approximations.
const TOP := Color(0.34, 0.36, 0.38)
const LOWER := Color(0.46, 0.48, 0.50)
const GLASS := Color(0.30, 0.34, 0.30)
const BLACK := Color(0.05, 0.05, 0.055)
const METAL := Color(0.30, 0.30, 0.31)
const WELL := Color(0.80, 0.81, 0.82)
const GEAR_WHITE := Color(0.86, 0.87, 0.86)
const TYRE_BLACK := Color(0.06, 0.06, 0.06)

## THE FUSELAGE, RING BY RING, off [SAC] page 2. Each row is [station, top, crown_w, crown_h, shoulder_w, shoulder_h,
## chine_w, chine_h, under_w, under_h, belly_w, bottom], half-widths out from the centreline and heights over the
## FUSELAGE DATUM (the aeroplane level). Heights measured over the RAKED GROUND have `station x tan(6.5 deg)` added
## back to bring them into that level frame -- the aeroplane is drawn level and the ground is not, and forgetting it
## makes the spine look a metre too high.
##
## THE RING IS AN ELLIPSE THROUGH ITS OWN TOP, BOTTOM AND WIDEST POINT, and that is the whole of this table's
## second pass. `propose_sections.py` computes every intermediate pair; nothing in the five is typed by hand.
##
## WHAT WENT WRONG BEFORE, and it is worth the next reader's time because the numbers looked like measurements.
## The first table's top and bottom lines were measured and right -- eight stations agree with the drawing to a
## centimetre -- but its five INTERMEDIATE pairs were judged, and judged against the plan column that
## `measure_stations.py` had not yet cleaned. They put `chine_w` 0.3 to 0.5 m proud of its neighbours at every
## station, which is a CHINED WEDGE, and the aeroplane came out reading as an F-35: 1.44 m of half-width amidships
## against a front view that measures 1.231. The body was WIDER THAN THE REAL AEROPLANE'S INTAKES, so the intakes
## could not stand proud of it and were drawn as slots on the flank. **Those two faults were one fault.**
##
## WHERE EACH NUMBER COMES FROM, because it is not one answer and pretending otherwise is how the first table went
## wrong:
## - WIDTHS, stations 0.0 to 2.0 and 8.5 to 10.0: the plan view, where its outermost ink and its nearest-to-centreline
##   ink agree -- when both edges are the same edge there is only one line there, and it is the fuselage side.
## - WIDTHS, stations 2.0 to 4.4: the intake, which measures 1.05 to 1.22 m of half-width in PLAN and 1.239 m in the
##   FRONT view. Two views, two instruments, the same answer.
## - WIDTHS, stations 4.5 to 8.0: NOTHING MEASURES THIS. The wing covers the fuselage side in plan and the front view
##   is a projection that cannot say which station its widest point belongs to. Interpolated between measured ends,
##   and this is the one judged thing left in the table.
## - TOP, stations 0.30 to 10.25, and BOTTOM, 0.30 to 4.25 and 9.00 to 10.50: the drawing's own silhouette.
## - TOP from 10.50 aft, and BOTTOM between 4.5 and 8.35 and from 11.25 aft: JUDGED, because the lowest ink there is
##   a GUN POD and the highest is the FIN. A measurement of the wrong object is worse than an honest judgement of
##   the right one -- this sheet's own scale bar is the lane's standing proof of that.
##
## - The top rises from 2.25 at the nose to the CANOPY's peak at station 2.75 and falls away aft.
## - THE INTAKE BELLS are their own part and stand OUTSIDE these rings, reaching 1.198 m where the body is 0.76.
## - The FIN rises from station 11.5; it is a separate part and not a ring.
const SECTIONS: Array = [
	[0.30, 2.23, 0.23, 2.20, 0.40, 2.12, 0.46, 2.00, 0.40, 1.89, 0.23, 1.77],
	[0.75, 2.44, 0.24, 2.39, 0.42, 2.26, 0.48, 2.08, 0.42, 1.90, 0.24, 1.72],
	[1.25, 2.63, 0.24, 2.57, 0.42, 2.39, 0.48, 2.15, 0.42, 1.90, 0.24, 1.66],
	[1.75, 2.94, 0.24, 2.85, 0.42, 2.62, 0.48, 2.29, 0.42, 1.97, 0.24, 1.65],
	[2.25, 3.24, 0.31, 3.13, 0.54, 2.84, 0.62, 2.43, 0.54, 2.03, 0.31, 1.62],
	[2.75, 3.43, 0.35, 3.31, 0.61, 2.97, 0.70, 2.51, 0.61, 2.05, 0.35, 1.59],
	[3.25, 3.44, 0.36, 3.32, 0.62, 2.97, 0.72, 2.51, 0.62, 2.04, 0.36, 1.58],
	[3.75, 3.36, 0.37, 3.24, 0.64, 2.91, 0.74, 2.46, 0.64, 2.01, 0.37, 1.56],
	[4.25, 3.24, 0.38, 3.13, 0.66, 2.82, 0.76, 2.40, 0.66, 1.97, 0.38, 1.55],
	[4.75, 3.25, 0.37, 3.14, 0.65, 2.83, 0.75, 2.41, 0.65, 1.99, 0.37, 1.57],
	[5.35, 3.29, 0.36, 3.18, 0.63, 2.87, 0.73, 2.45, 0.63, 2.02, 0.36, 1.60],
	[6.00, 3.32, 0.35, 3.21, 0.61, 2.90, 0.71, 2.48, 0.61, 2.06, 0.35, 1.64],
	[6.75, 3.33, 0.34, 3.22, 0.59, 2.92, 0.69, 2.50, 0.59, 2.08, 0.34, 1.67],
	[7.50, 3.30, 0.33, 3.19, 0.58, 2.90, 0.66, 2.50, 0.58, 2.11, 0.33, 1.71],
	[8.35, 3.27, 0.32, 3.17, 0.55, 2.89, 0.64, 2.51, 0.55, 2.13, 0.32, 1.75],
	[9.00, 3.26, 0.28, 3.16, 0.49, 2.89, 0.57, 2.52, 0.49, 2.15, 0.28, 1.78],
	[9.75, 3.26, 0.24, 3.17, 0.42, 2.91, 0.49, 2.56, 0.42, 2.21, 0.24, 1.86],
	[10.50, 3.30, 0.21, 3.21, 0.36, 2.96, 0.42, 2.63, 0.36, 2.29, 0.21, 1.96],
	[11.25, 3.32, 0.17, 3.23, 0.29, 2.98, 0.34, 2.65, 0.29, 2.31, 0.17, 1.98],
	[12.00, 3.34, 0.13, 3.25, 0.23, 3.00, 0.27, 2.65, 0.23, 2.31, 0.13, 1.96],
	[12.75, 3.34, 0.10, 3.25, 0.17, 3.00, 0.20, 2.65, 0.17, 2.31, 0.10, 1.96],
	[13.55, 3.30, 0.06, 3.25, 0.10, 3.10, 0.12, 2.91, 0.10, 2.72, 0.06, 2.52],
	[14.05, 3.22, 0.02, 3.20, 0.04, 3.15, 0.05, 3.08, 0.04, 3.02, 0.02, 2.95],
]
const FUSELAGE_SIDES: int = 12

## THE GROUND PASSES THROUGH THE DATUM AT THE NOSE and rises aft at the rake: `measure_stations.py` reports heights
## over the raked ground under each station, and `SECTIONS` stores those plus `station x tan(rake)`, so the ground in
## this frame is exactly `station x tan(rake)` and this constant is zero by construction rather than by choice.
const GROUND_AT_NOSE: float = 0.0

## THE WING, MEASURED: where its root leading edge sits, how high its chord plane is at the root, and where it leaves
## the fuselage side. The root chord and the sweeps put the tip at station 7.47 to 8.48, which is where
## `measure_stations.py` finds the plan silhouette widest and then losing the wing.
const WING_ROOT_STATION: float = 4.05
const WING_ROOT_HIGH: float = 2.72
const WING_ROOT_OUT: float = 0.62
const FLAP_TO_OUT: float = 2.55
const LERX_FROM: float = 2.35

## THE CANOPY's glazing, MEASURED off [SAC] page 2's side view at the scale its own 46.33 FT dimension sets: the
## windscreen base at station 1.20 and the canopy's rear edge at 3.60. It was an ESTIMATE of 1.85 to 3.45, and the
## windscreen being 0.65 m too far aft is a third of why this aeroplane read as a dart -- a Harrier's cockpit sits
## RIGHT FORWARD, so far forward that the pilot is ahead of the nose gear, and moving it back lengthens the nose by
## the same amount at the sharpest end. The raised cockpit is most of a Harrier II's face and it was in the wrong
## place. ESTIMATES beside measurable things are worth re-reading when the measuring gets better.
const CANOPY_FROM: float = 1.20
const CANOPY_TO: float = 3.60

## THE INTAKES, MEASURED, AND THEY ARE THE AEROPLANE'S FACE. [SAC]'s FRONT view -- the one view on the sheet that
## nobody had measured, used elsewhere for a single span cross-check and then dropped -- shows them as the WIDEST
## thing on the body: two big round-lipped bells either side of the cockpit. `measure_front.py` tracks the body's
## outer edge through the front view and fits a circle to seventeen rows of it: radius 0.611 m centred 0.587 m
## outboard, so an OUTER DIAMETER of 1.222 m, at 2.56 px rms on a photocopied line drawing.
##
## THE PLAN VIEW AGREES ABOUT THE WIDTH: its outer half-width runs 1.048 to 1.223 m through the intake, which is this
## same bell seen from above. Two views, two instruments, one width.
##
## **AND IT DISAGREES ABOUT THE STATION, AND IT IS THE ONE THAT IS WRONG.** Read off the plan, the bell began at
## station 2.00; read off the SIDE view, its lip is at 3.30. The side view wins and it is not a close call:
## `measure_stations.py` sets the side view's scale from the 46.33 FT dimension's own extension lines, and prints --
## in a line that was there to be read all along -- that **THE PLAN VIEW'S OWN LENGTH COMES OUT 13.629 m, 3.5 per
## cent short of the published 14.122**. A view that cannot reproduce the aeroplane's length cannot be trusted to
## say where along it anything sits. Its WIDTHS are unaffected, because a width is measured across the axis that is
## in error and not along it.
##
## The first cut of this lane put the lip at 2.00 and the bells came out wrapped round the nose, ahead of the
## windscreen. **The picture caught it; no check did, and none would have** -- every published figure still held,
## because not one of them is a station.
##
## AND SO DOES THE ENGINE, which is the check none of the above could have produced. [WP]'s Pegasus infobox gives a
## diameter of 48 in, 1.219 m, against this drawn 1.222 -- 0.2 per cent, and neither figure went into the other. A
## duct wrapping the fan face is the same size as the fan, and the drawing says so independently.
##
## THE HEIGHT IS REGISTERED, NOT CHOSEN. The front view's scale is the sheet's, so the bell's fitted centre sits
## 2.671 m below the fin tip, which is 2.49 m over the datum. The ellipse at station 3.25 is widest at 2.51 m. Two
## centimetres apart, from two unrelated measurements, which is why this height is trusted.
##
## WHAT THEY WERE. Boxes on the flank reaching 1.34 m of half-width, on a body that was itself 1.44 m wide -- the
## intakes were INSIDE THEIR OWN FUSELAGE and from the front they read as two black slots. That is why the profile
## and the intakes were one fault and not two: narrowing the body to what is drawn is what made room for these.
const INTAKE_LIP: float = 3.30
const INTAKE_FAIR: float = 5.40
const INTAKE_RADIUS: float = 0.611
const INTAKE_OUT: float = 0.587
const INTAKE_HIGH: float = 2.49
## The throat, an ESTIMATE, held only to being big enough: two ducts feed one 1.219 m fan, so on area alone each
## needs an inner capture of at least 1.219/sqrt(2) = 0.862 m across. This is 0.94 and clears it. **The bell is
## built to the MEASURED circle and never to this floor** -- nothing fitted to a bound a test then checks against.
const INTAKE_THROAT: float = 0.47
const INTAKE_SIDES: int = 10

## THE TAILPLANE and THE FIN, MEASURED: the tailplane half-span is the published 13.93 ft halved, and the fin tip
## stands at the published height over the ground under it.
##
## THE FIN'S LEADING EDGE WAS A TYPED 42 DEGREES, the one magic number left in this file, sitting inside `_fin` with
## no source beside it in a document where every other figure names one. It is now MEASURED off [SAC] page 2's side
## view: 97 rows between datum heights 3.55 and 5.10, **rms 39 mm (2.4 px)**, giving `station = 1.1630 x height +
## 7.1562` -- **49.31 degrees from the vertical**, with the root at station 11.041 and the tip at 13.158.
##
## The trailing edge was already right and is not touched: fitted the same way it comes back 13.259 at the root and
## 13.504 at the tip, at **rms 5 mm (0.3 px)**, against the drawn 13.30 and 13.50. So the whole fault was in the
## leading edge, which stood **0.49 m too far forward at the root and 0.97 m at the tip** -- a root chord of 2.75 m
## against a drawn 2.22 and a tip chord of 1.31 against 0.35.
##
## WHY IT MATTERED MORE THAN ITS SIZE. It made the fin a broad upright slab where the aeroplane's is narrow and
## sharply swept, and a big broad fin is the Phantom's and the F-35's. It is at the end of the aeroplane, it is
## against the sky, and it is a third of the side-on outline. `craft/harrier/overlay_views.py` found it without
## being told to look: the model's top line ran +0.11 to +0.81 m high over stations 10.55 to 12.80, the largest
## disagreement anywhere on the aeroplane, and it is plain in the overlay picture as the drawing's own leading edge
## running diagonally across the drawn fin.
const TAILPLANE_STATION: float = 11.55
const TAILPLANE_HIGH: float = 2.30
const FIN_FROM: float = 11.04
const FIN_TO: float = 13.30
const FIN_ROOT_HIGH: float = 3.34
const FIN_TIP_HIGH: float = 5.16
const FIN_SWEEP: float = 49.31

## THE PODS' height under the belly. They HANG FROM IT, so when the belly moved they moved: the fuselage keel over
## their stations is now 1.57 to 1.72 and the drawing's lowest ink through there -- which is the pod's own bottom,
## not the fuselage's -- is 1.12 to 1.35. So the pod is 0.50 m deep with its top inside the keel and its bottom on
## the drawn line, where before it was 0.40 deep hanging off a belly that had been drawn down to meet it.
const PODS_HIGH: float = 1.43
const PODS_DEEP: float = 0.50


var _half := Vector3(1.8, 1.8, 7.1)
var _span: float = SPAN
var _travel: float = NOZZLE_TRAVEL
var _nozzle: float = 0.0
var _gear: float = 1.0
var _flaps: float = 0.0
var _roll: float = 0.0
var _pitch: float = 0.0
var _yaw: float = 0.0
var _hinges: Dictionary = {}
var _legs: Array[Node3D] = []
var _stowed: Array[Quaternion] = []


# ---- the public shape ---------------------------------------------------------------------------------------------

## A POINT IN THE CRAFT'S FRAME from a station aft of the nose, a half-width out and a height over the FUSELAGE DATUM.
## Forward is -Z, up is +Y, starboard is +X.
func point(out: float, high: float, station: float) -> Vector3:
	return Vector3(out, -_half.y + high, -_half.z + station)


## WHERE THE GROUND IS UNDER A STATION, as a height over the fuselage datum -- A RAKED PLANE, not a level one.
## [SAC] draws the aeroplane level and rakes its ground line 6.5 degrees, so this aeroplane parks NOSE-UP and its nose
## tyre hangs further below the datum than its main one. `ProwlerAirframe` does the same for the EA-6B's 5.8 degrees,
## and `modelling_here.md` section 5 says why the other reading is dangerous: it silently levels an aeroplane that is
## not level, and somebody who knows the convention and not the aeroplane later "restores" it.
func ground_at(station: float) -> float:
	return GROUND_AT_NOSE + station * tan(deg_to_rad(GEAR_RAKE))


## THE WING, MEASURED [SAC]: its leading edge, trailing edge and the height of its chord plane at a half-width out.
## The chord plane FALLS going outboard -- eleven degrees of it -- which is the Harrier's most distinctive head-on
## feature and the reason a front view of one is unmistakable.
func wing_le(out: float) -> float:
	return WING_ROOT_STATION + absf(out) * tan(deg_to_rad(SWEEP_LEADING))


func wing_te(out: float) -> float:
	return wing_le(out) + ROOT_CHORD - (ROOT_CHORD - TIP_CHORD) * (absf(out) / (SPAN * 0.5))


func wing_h(out: float) -> float:
	return WING_ROOT_HIGH - absf(out) * tan(deg_to_rad(ANHEDRAL))


## WHERE THE PILOT'S EYE IS, over the datum: [SAC]'s "raised cockpit", the thing the Harrier II was given so its pilot
## could see over the nose in the hover. ESTIMATE off the side view's canopy.
func eye() -> Vector3:
	return point(0.0, 3.02, 2.60)


## HOW MUCH ROOM THE CREW HAS, for anything that wants to put a floor or a seat in it (`modelling_here.md` section 1).
func cabin_room() -> Dictionary:
	var floor_h: float = 2.30
	return {
		"drawn": true,
		"floor": point(0.0, floor_h, 2.60).y,
		"room": AABB(point(-0.38, floor_h, 1.95), Vector3(0.76, 0.98, 1.70)),
		"why_not": "",
		"because": &"",
		"source": "the canopy sill and the cockpit floor measured off [SAC] page 2's side view, inset to the "
			+ "narrowest ring the glazing covers",
	}


## WHERE THIS AEROPLANE BLOWS, for `ExhaustYard`: FOUR nozzles, and they are not all the same thing.
##
## [PEG]: "The front nozzles, which are made of steel, are fed with air from the LP compressor, and the rear nozzles,
## which are of Nimonic with hot (650 degrees C) jet exhaust. The airflow split is about 60/40 front/back." So the
## front pair is COLD and the rear pair is HOT, and this aeroplane wears two pale plumes forward and two burning ones
## aft. Nothing else in this game has an exhaust that is cold at one end and 650 degrees at the other.
##
## ALL FOUR AT ONE ANGLE, because the real ones are chain-driven off a single air motor and cannot point two ways.
## The angle is read off the same `nozzle_angle()` the drawn nozzles turn by, so a plume cannot be drawn where the
## metal is not -- `tests/harrier.gd` holds every port to its own drawn nozzle's vertices.
func exhaust_ports() -> Array:
	var angle: float = nozzle_angle()
	# THE GAS LEAVES ALONG THE REVERSE OF THE THRUST: forward is -Z, so a thrust of (forward cos + up sin) leaves
	# along (+Z cos - Y sin) -- straight aft at zero, straight down at ninety, and 8.5 degrees FORWARD of down at the
	# braking stop, which is what a real Harrier's nozzles look like there.
	var gas := Vector3(0.0, -sin(angle), cos(angle))
	var ports: Array = []
	# WHERE THE EXIT ACTUALLY IS, computed from the same three figures the elbow is drawn from rather than typed
	# beside them: the hinge sits on the flank, the exit stands `NOZZLE_OUT_REACH` outboard of it and
	# `NOZZLE_AFT_REACH` along the gas. So a plume leaves the drawn mouth at every lever position by construction,
	# which is what `tests/harrier.gd:_every_plume_leaves_its_own_drawn_nozzle` holds each of the four to.
	for side in [1.0, -1.0]:
		var front: float = _flank_at(NOZZLE_FRONT_STATION, NOZZLE_HIGH) + NOZZLE_OUT_REACH
		var rear: float = _flank_at(NOZZLE_REAR_STATION, NOZZLE_HIGH) + NOZZLE_OUT_REACH
		ports.append({
			"at": point(side * front, NOZZLE_HIGH, NOZZLE_FRONT_STATION) + gas * NOZZLE_AFT_REACH,
			"axis": gas, "radius": NOZZLE_FRONT_EXIT, "kind": ExhaustTuning.Kind.FAN, "heat": 0.0,
		})
		ports.append({
			"at": point(side * rear, NOZZLE_HIGH, NOZZLE_REAR_STATION) + gas * NOZZLE_AFT_REACH,
			"axis": gas, "radius": NOZZLE_REAR_EXIT, "kind": ExhaustTuning.Kind.JET, "heat": 1.0,
		})
	return ports


# ---- what moves ---------------------------------------------------------------------------------------------------

## THE FOUR NOZZLES, 0 straight aft to 1 at the braking stop. A PURE FUNCTION OF THE AMOUNT: the angle is
## `amount x travel`, linear, because once this is a kind the simulation's thrust vector will be the same product of
## the same lever, and a curve here would put the drawn nozzles where the thrust is not.
func set_nozzle(amount: float) -> void:
	_nozzle = clampf(amount, 0.0, 1.0)
	for named in ["NozzleFrontPort", "NozzleFrontStarboard", "NozzleRearPort", "NozzleRearStarboard"]:
		_turn(named, _nozzle * _travel)


func nozzle() -> float:
	return _nozzle


## THE ANGLE THE DRAWN NOZZLES POINT, radians below straight aft.
func nozzle_angle() -> float:
	return _nozzle * _travel


## WHERE THE LEVER SITS FOR A NAMED STOP, 0 to 1, so nothing types a lever position beside an angle [NATOPS p96].
func stop_at(degrees: float) -> float:
	return clampf(deg_to_rad(degrees) / _travel, 0.0, 1.0)


## THE GEAR, 0 up and 1 down. A BICYCLE: the nose and main legs swing on the centreline and the outriggers fold
## inboard into the wing. The doors open, the legs travel and the doors shut again, as the F-35B's do.
func set_gear(amount: float) -> void:
	_gear = clampf(amount, 0.0, 1.0)
	var legs: float = legs_down(_gear)
	for index in range(_legs.size()):
		_legs[index].basis = Basis(Quaternion.IDENTITY.slerp(_stowed[index], 1.0 - legs))
	var doors: float = doors_open(_gear)
	for named in ["NoseDoorPort", "NoseDoorStarboard", "MainDoorPort", "MainDoorStarboard",
			"OutriggerDoorPort", "OutriggerDoorStarboard"]:
		_turn(named, doors * deg_to_rad(85.0))


func gear() -> float:
	return _gear


## HOW FAR THE LEGS ARE THROUGH THEIR TRAVEL at a point in the cycle, and how far the doors are open: doors over the
## first `DOOR_SHARE` and the last, legs over the middle. A leg never moves while its doors are shut, and the gear
## down has them shut under it.
static func legs_down(cycle: float) -> float:
	return clampf((cycle - DOOR_SHARE) / (1.0 - 2.0 * DOOR_SHARE), 0.0, 1.0)


static func doors_open(cycle: float) -> float:
	if cycle <= DOOR_SHARE:
		return cycle / DOOR_SHARE
	if cycle >= 1.0 - DOOR_SHARE:
		return (1.0 - cycle) / DOOR_SHARE
	return 1.0


## THE FLAPS: [SAC] "a large, single slotted flap". Down 60 degrees, which is the STOL setting.
func set_flaps(amount: float) -> void:
	_flaps = clampf(amount, 0.0, 1.0)
	for side in ["Port", "Starboard"]:
		_turn("Flap" + side, _flaps * deg_to_rad(60.0))


func flaps() -> float:
	return _flaps


## THE AILERONS, one up and one down. [SAC]: "drooped ailerons in the high lift configuration", so they follow the
## flaps down as well as answering the stick.
func set_ailerons(roll: float) -> void:
	_roll = clampf(roll, -1.0, 1.0)
	var droop: float = _flaps * deg_to_rad(20.0)
	_turn("AileronStarboard", -_roll * deg_to_rad(20.0) + droop)
	_turn("AileronPort", _roll * deg_to_rad(20.0) + droop)


## THE ALL-MOVING TAILPLANE. [NATOPS] p122: stabilator travel about 10 degrees trailing-edge up and 11 down.
func set_tailplane(pitch: float) -> void:
	_pitch = clampf(pitch, -1.0, 1.0)
	var angle: float = deg_to_rad(10.0) * maxf(_pitch, 0.0) + deg_to_rad(11.0) * minf(_pitch, 0.0)
	for side in ["Port", "Starboard"]:
		_turn("Tailplane" + side, angle)


## THE RUDDER. [NATOPS] p123, PUBLISHED and not estimated: "Rudder travel is 15 degrees right and left."
func set_rudder(yaw: float) -> void:
	_yaw = clampf(yaw, -1.0, 1.0)
	_turn("Rudder", _yaw * deg_to_rad(15.0))


func stick_roll() -> float:
	return _roll


func stick_pitch() -> float:
	return _pitch


func stick_yaw() -> float:
	return _yaw


## THE FEATURES A VAT BAKES (`VatCasting`), each this airframe's own setter and getter. The nozzles are ONE feature
## because all four are chain-driven together on the real aeroplane.
func features() -> Array:
	return [
		{"name": "nozzle", "set": set_nozzle, "get": nozzle, "low": 0.0, "high": 1.0, "samples": 33},
		{"name": "gear", "set": set_gear, "get": gear, "low": 0.0, "high": 1.0},
		{"name": "flaps", "set": set_flaps, "get": flaps, "low": 0.0, "high": 1.0, "samples": 17},
		{"name": "roll", "set": set_ailerons, "get": stick_roll, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "pitch", "set": set_tailplane, "get": stick_pitch, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "rudder", "set": set_rudder, "get": stick_yaw, "low": -1.0, "high": 1.0, "samples": 33},
	]


## A HINGE turned `angle` radians from where it was built, about the axis stored on it when it was built.
func _turn(named: String, angle: float) -> void:
	var hinge: Node3D = _hinges.get(named) as Node3D
	if hinge != null:
		hinge.basis = Basis(hinge.get_meta("axis") as Vector3, angle)


## A HINGE at `at`, turning about `along`, wound so a small positive turn carries `probe` towards `wanted`: the
## Tomcat's way, so the builder never reasons about which way a mirrored hinge turns.
func _hinge(named: String, parent: Node3D, at: Vector3, along: Vector3, probe: Vector3, wanted: Vector3) -> Node3D:
	var hinge := Node3D.new()
	hinge.name = named + "Hinge"
	hinge.position = at
	var axis: Vector3 = along.normalized()
	if axis.cross(probe - at).dot(wanted) < 0.0:
		axis = -axis
	hinge.set_meta("axis", axis)
	parent.add_child(hinge)
	_hinges[named] = hinge
	return hinge


# ---- building -------------------------------------------------------------------------------------------------------

static func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


static func _add(parent: Node3D, title: String, tool: SurfaceTool, material: Material,
		at_position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = material
	mesh.position = at_position
	parent.add_child(mesh)
	return mesh


## DRESS THE AEROPLANE. `geometry` is the simulation's, when there is one; until the kind exists the published
## envelope stands in, and `tests/harrier.gd` prints which was used so a green run over a stub is not mistaken for a
## green run over the real thing.
func dress(geometry: Dictionary = {}) -> void:
	name = "Harrier"
	if geometry.has("extents"):
		_half = geometry["extents"] as Vector3
		_span = float(geometry.get("span", SPAN))
	else:
		_half = Vector3(1.80, HEIGHT * 0.5, LENGTH * 0.5)
		_span = SPAN
	for child in get_children():
		child.queue_free()
	_hinges.clear()
	_legs.clear()
	_stowed.clear()

	var paint: StandardMaterial3D = ShipHull.painted()
	paint.roughness = 0.62
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.vertex_color_is_srgb = true
	glass.albedo_color = Color(1.0, 1.0, 1.0, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.08
	glass.metallic = 0.3

	var body := _tool()
	var canopy := _tool()
	_fuselage(body, canopy)
	_add(self, "Fuselage", body, paint)
	_add(self, "Canopy", canopy, glass)

	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var wing := _tool()
		_wing(wing, side)
		_add(self, "Wing" + named, wing, paint)
		var lerx := _tool()
		_lerx(lerx, side)
		_add(self, "Lerx" + named, lerx, paint)
		var intake := _tool()
		_intake(intake, side)
		_add(self, "Intake" + named, intake, paint)
		_blow_in_doors(side, "BlowInDoors" + named, paint)
		_flap(side, "Flap" + named, paint)
		_aileron(side, "Aileron" + named, paint)
		_tailplane(side, "Tailplane" + named, paint)
		_build_nozzle(side, "NozzleFront" + named, NOZZLE_FRONT_STATION, false, paint)
		_build_nozzle(side, "NozzleRear" + named, NOZZLE_REAR_STATION, true, paint)
		_gun_pod(side, "GunPod" + named, paint)
		_outrigger(side, named, paint)
	_fin(paint)
	_rudder(paint)
	_reaction_jets(paint)
	_lids(paint)
	_centreline_gear(paint)
	set_nozzle(_nozzle)
	set_gear(_gear)
	set_flaps(_flaps)
	set_ailerons(_roll)
	set_tailplane(_pitch)
	set_rudder(_yaw)


## ONE RING's points round from the top centreline, starboard down to the keel and port back up: 12 points, 12 facets.
func _ring(row: Array) -> Array:
	var half: Array = [Vector2(0.0, row[1]), Vector2(row[2], row[3]), Vector2(row[4], row[5]),
		Vector2(row[6], row[7]), Vector2(row[8], row[9]), Vector2(row[10], row[11]), Vector2(0.0, row[11])]
	var points: Array = []
	for i in range(half.size() - 1):
		points.append(point((half[i] as Vector2).x, (half[i] as Vector2).y, float(row[0])))
	for i in range(half.size() - 1, 0, -1):
		points.append(point(-(half[i] as Vector2).x, (half[i] as Vector2).y, float(row[0])))
	return points


## THE FUSELAGE: 12 flat facets a ring through the measured sections. Over the cockpit the two upper facets each side
## are GLASS and go into `canopy` instead -- the Harrier II's raised cockpit is most of what you see of it from
## ahead, and drawing it as skin would lose the aeroplane's face.
func _fuselage(tool: SurfaceTool, canopy: SurfaceTool) -> void:
	var rings: Array = []
	for row in SECTIONS:
		rings.append(_ring(row))
	for r in range(rings.size() - 1):
		var s: float = (float(SECTIONS[r][0]) + float(SECTIONS[r + 1][0])) * 0.5
		var here: Array = rings[r]
		var next: Array = rings[r + 1]
		for i in range(FUSELAGE_SIDES):
			var j: int = (i + 1) % FUSELAGE_SIDES
			var quad: Array = [here[i], next[i], next[j], here[j]]
			var mid: Vector3 = (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
			var out: Vector3 = (mid - point(0.0, (float(SECTIONS[r][1]) + float(SECTIONS[r][11])) * 0.5, s)).normalized()
			# THE GLAZING IS THE CROWN AND NOTHING ELSE, and it was ASYMMETRIC. Facet 0 runs from the crown apex to
			# the STARBOARD crown point, facet 1 on from there to the starboard SHOULDER, and facet 11 from the port
			# crown point back to the apex -- so `0, 1, 11` glazed to 0.62 m out on the starboard side and 0.36 on
			# the port. One aeroplane, two canopies. [SAC]'s FRONT view measures the dome at about 0.35 m of
			# half-width where it meets the body, which is the crown width, so the pair `0, 11` is both symmetric
			# and the measured width -- and dropping facet 1 is what gives the canopy a SILL to be bounded by
			# instead of washing half way down the flank and reading as a blended spine.
			var glazed: bool = s > CANOPY_FROM and s < CANOPY_TO and (i == 0 or i == FUSELAGE_SIDES - 1)
			if glazed:
				Plating.facing(canopy, quad, out, GLASS)
			else:
				Plating.facing(tool, quad, out, TOP if out.y > 0.25 else LOWER)
	# The nose cap and the tail cap, so the skin is a closed solid the pilot is inside of.
	var nose: Vector3 = point(0.0, (float(SECTIONS[0][1]) + float(SECTIONS[0][11])) * 0.5, 0.0)
	var tail: Vector3 = point(0.0, (float(SECTIONS[-1][1]) + float(SECTIONS[-1][11])) * 0.5, LENGTH)
	for i in range(FUSELAGE_SIDES):
		var j: int = (i + 1) % FUSELAGE_SIDES
		_fan(tool, nose, rings[0][j], rings[0][i], Vector3(0.0, 0.0, -1.0), LOWER)
		_fan(tool, tail, rings[-1][i], rings[-1][j], Vector3(0.0, 0.0, 1.0), LOWER)


## ONE TRIANGLE, wound so its face looks along `out`, EMITTED DIRECTLY rather than through `Plating.facing`.
##
## `facing` is built for QUADS: it reads `corners[3]` when its first cross product is degenerate, and `Plating.quad`
## emits the index pattern [0, 1, 2, 0, 2, 3]. Handing it three corners drew the first triangle and then wound a
## second one out of whatever `corners[3]` resolved to. The model came back with 75 faces of 1,478 pointing inwards --
## every nose and tail cap, every nozzle exit ring, every LERX face and every tyre side -- and a backwards face is
## INVISIBLE, so nothing but this check would ever have said so.
static func _fan(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-12:
		return
	if normal.dot(out) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	tool.set_color(tint)
	var unit: Vector3 = normal.normalized()
	for p in [a, b, c]:
		tool.set_normal(unit)
		tool.add_vertex(p)


## A WING SECTION at a half-width out: six points, as the F-16's is, and the chord plane FALLS going outboard.
func _wing_section(out: float) -> Array:
	var le: float = wing_le(out)
	var te: float = wing_te(out)
	var h: float = wing_h(out)
	var chord: float = te - le
	var thick: float = chord * 0.085
	return [
		point(out, h, le),
		point(out, h + thick * 0.55, le + chord * 0.30),
		point(out, h + thick * 0.35, le + chord * 0.70),
		point(out, h, te),
		point(out, h - thick * 0.30, le + chord * 0.70),
		point(out, h - thick * 0.50, le + chord * 0.30),
	]


## THE WING, root to tip in four panels, with the aileron and flap cut out of its trailing edge as their own parts.
func _wing(tool: SurfaceTool, side: float) -> void:
	var half: float = _span * 0.5
	var steps: int = 4
	var sections: Array = []
	for i in range(steps + 1):
		sections.append(_wing_section(side * (WING_ROOT_OUT + (half - WING_ROOT_OUT) * float(i) / float(steps))))
	for i in range(steps):
		var here: Array = sections[i]
		var next: Array = sections[i + 1]
		for k in range(6):
			var j: int = (k + 1) % 6
			var quad: Array = [here[k], next[k], next[j], here[j]]
			var mid: Vector3 = (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
			var centre: Vector3 = Vector3.ZERO
			for p in here:
				centre += p
			centre /= 6.0
			Plating.facing(tool, quad, (mid - centre).normalized(), TOP if mid.y > centre.y else LOWER)
	# The tip, capped.
	var tip: Array = sections[-1]
	var middle: Vector3 = Vector3.ZERO
	for p in tip:
		middle += p
	middle /= 6.0
	for k in range(6):
		_fan(tool, middle, tip[k], tip[(k + 1) % 6], Vector3(side, 0.0, 0.0), LOWER)


## THE LEADING-EDGE ROOT EXTENSION, PUBLISHED [SAC]: a flat sharp-edged sliver running forward from the wing root
## along the intake, which is what gives a Harrier II its planform and what a first-generation aeroplane has not got.
func _lerx(tool: SurfaceTool, side: float) -> void:
	var root_le: float = wing_le(side * WING_ROOT_OUT)
	var h: float = wing_h(side * WING_ROOT_OUT)
	var corners: Array = [
		point(side * WING_ROOT_OUT, h, root_le),
		point(side * (WING_ROOT_OUT - 0.10), h, LERX_FROM),
		point(side * (WING_ROOT_OUT + 0.28), h, root_le - 0.20),
	]
	for lift in [0.035, -0.035]:
		var face: Array = []
		for c in corners:
			face.append(c + Vector3(0.0, lift, 0.0))
		_fan(tool, face[0], face[1], face[2], Vector3(0.0, signf(lift), 0.0), TOP if lift > 0.0 else LOWER)
	for i in range(3):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 3]
		Plating.facing(tool, [a + Vector3(0.0, 0.035, 0.0), b + Vector3(0.0, 0.035, 0.0),
			b - Vector3(0.0, 0.035, 0.0), a - Vector3(0.0, 0.035, 0.0)],
			(b - a).cross(Vector3.UP).normalized() * side, LOWER)


## THE INTAKE: A ROUND-LIPPED BELL standing proud of the flank, which is what a Harrier has instead of a slot.
##
## FOUR RINGS down the duct, each a circle in the (outboard, height) plane centred on the fitted centre: the LIP at
## station 2.00, the BLOW-IN DOOR band just behind it drawn slightly proud and in metal, the barrel, and the ring
## where the bell sinks into the fuselage at station 4.40. The inboard facets of each ring sit inside the body, which
## is correct rather than wasteful -- the duct really does go in there, and a closed tube is what keeps the winding
## check honest.
##
## THE MOUTH IS A HOLE. A throat ring of INTAKE_THROAT fans back to a point in BLACK, so a look into the bell finds
## depth rather than a painted disc. `Plating.facing` is for QUADS and must never be handed three corners -- that is
## what drew 75 faces inwards on this model once -- so every triangle here goes through `_fan`.
func _intake(tool: SurfaceTool, side: float) -> void:
	# station, radius scale, colour -- the bell full for its length, then shrinking into the flank.
	var steps: Array = [
		[INTAKE_LIP, 1.00, METAL],
		[INTAKE_LIP + 0.28, 1.03, METAL],
		[INTAKE_LIP + 1.20, 1.00, LOWER],
		[INTAKE_FAIR, 0.46, LOWER],
	]
	var rings: Array = []
	for step in steps:
		var ring: Array = []
		for i in range(INTAKE_SIDES):
			var a: float = TAU * float(i) / float(INTAKE_SIDES)
			ring.append(point(side * (INTAKE_OUT + cos(a) * INTAKE_RADIUS * float(step[1])),
				INTAKE_HIGH + sin(a) * INTAKE_RADIUS * float(step[1]), float(step[0])))
		rings.append(ring)
	for r in range(rings.size() - 1):
		var here: Array = rings[r]
		var next: Array = rings[r + 1]
		for i in range(INTAKE_SIDES):
			var j: int = (i + 1) % INTAKE_SIDES
			var quad: Array = [here[i], next[i], next[j], here[j]]
			var mid: Vector3 = (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
			var axis: Vector3 = point(side * INTAKE_OUT, INTAKE_HIGH,
				(float(steps[r][0]) + float(steps[r + 1][0])) * 0.5)
			Plating.facing(tool, quad, (mid - axis).normalized(), steps[r + 1][2] as Color)
	# THE LIP ITSELF, an annulus facing forward from the bell's rim in to the throat: the round, thick, blown lip is
	# the single most recognisable thing about this aeroplane's face and a flat rim would throw it away.
	var throat: Array = []
	for i in range(INTAKE_SIDES):
		var a: float = TAU * float(i) / float(INTAKE_SIDES)
		throat.append(point(side * (INTAKE_OUT + cos(a) * INTAKE_THROAT),
			INTAKE_HIGH + sin(a) * INTAKE_THROAT, INTAKE_LIP + 0.20))
	for i in range(INTAKE_SIDES):
		var j: int = (i + 1) % INTAKE_SIDES
		Plating.facing(tool, [rings[0][i], rings[0][j], throat[j], throat[i]],
			Vector3(0.0, 0.0, -1.0), METAL)
	# ...and the duct behind it, fanned to a point well aft so the hole has depth.
	var deep: Vector3 = point(side * INTAKE_OUT, INTAKE_HIGH, INTAKE_LIP + 1.10)
	for i in range(INTAKE_SIDES):
		var j: int = (i + 1) % INTAKE_SIDES
		_fan(tool, deep, throat[i], throat[j], Vector3(0.0, 0.0, -1.0), BLACK)


## A FLAT SLAB on a hinge: a flap, an aileron, a tailplane, a rudder or a door. `corners` are in the craft's frame.
func _slab(named: String, parent: Node3D, corners: Array, hinge_a: Vector3, hinge_b: Vector3,
		opens_towards: Vector3, paint: Material, thick: float = 0.035, tint: Color = TOP) -> Node3D:
	var middle: Vector3 = Vector3.ZERO
	for c in corners:
		middle += c
	middle /= float(corners.size())
	var hinge: Node3D = _hinge(named, parent, hinge_a, hinge_b - hinge_a, middle, opens_towards)
	var tool := _tool()
	var top: Array = []
	var under: Array = []
	for c in corners:
		top.append(c - hinge_a + Vector3(0.0, thick * 0.5, 0.0))
		under.append(c - hinge_a - Vector3(0.0, thick * 0.5, 0.0))
	Plating.facing(tool, top, Vector3.UP, tint)
	var reversed: Array = []
	for i in range(under.size() - 1, -1, -1):
		reversed.append(under[i])
	Plating.facing(tool, reversed, Vector3.DOWN, LOWER)
	for i in range(corners.size()):
		var j: int = (i + 1) % corners.size()
		var edge: Vector3 = top[j] - top[i]
		Plating.facing(tool, [top[i], top[j], under[j], under[i]], edge.cross(Vector3.UP).normalized(), tint)
	var mesh := _add(hinge, named, tool, paint)
	return mesh


## THE FLAP: [SAC] "a large, single slotted flap", inboard on the trailing edge, hinged at its own leading edge.
func _flap(side: float, named: String, paint: Material) -> void:
	var inner: float = WING_ROOT_OUT
	var outer: float = FLAP_TO_OUT
	var chord: float = 0.30
	var a := point(side * inner, wing_h(side * inner), wing_te(side * inner) - chord * (wing_te(side * inner) - wing_le(side * inner)))
	var b := point(side * outer, wing_h(side * outer), wing_te(side * outer) - chord * (wing_te(side * outer) - wing_le(side * outer)))
	_slab(named, self, [a, b, point(side * outer, wing_h(side * outer), wing_te(side * outer)),
		point(side * inner, wing_h(side * inner), wing_te(side * inner))], a, b, Vector3.DOWN, paint)


## THE AILERON, outboard of the flap on the same trailing edge.
func _aileron(side: float, named: String, paint: Material) -> void:
	var inner: float = FLAP_TO_OUT
	var outer: float = _span * 0.5 - 0.16
	var chord: float = 0.28
	var a := point(side * inner, wing_h(side * inner), wing_te(side * inner) - chord * (wing_te(side * inner) - wing_le(side * inner)))
	var b := point(side * outer, wing_h(side * outer), wing_te(side * outer) - chord * (wing_te(side * outer) - wing_le(side * outer)))
	_slab(named, self, [a, b, point(side * outer, wing_h(side * outer), wing_te(side * outer)),
		point(side * inner, wing_h(side * inner), wing_te(side * inner))], a, b, Vector3.DOWN, paint)


## THE ALL-MOVING TAILPLANE, hinged across its own quarter chord as a stabilator is.
func _tailplane(side: float, named: String, paint: Material) -> void:
	var half: float = TAILPLANE_SPAN * 0.5
	var root_le: float = TAILPLANE_STATION
	var tip_le: float = root_le + half * tan(deg_to_rad(34.0))
	var root_chord: float = 1.65
	var tip_chord: float = 0.80
	var h: float = TAILPLANE_HIGH
	var a := point(side * 0.34, h, root_le + root_chord * 0.25)
	var b := point(side * half, h - 0.14, tip_le + tip_chord * 0.25)
	_slab(named, self, [point(side * 0.34, h, root_le), point(side * half, h - 0.14, tip_le),
		point(side * half, h - 0.14, tip_le + tip_chord), point(side * 0.34, h, root_le + root_chord)],
		a, b, Vector3.DOWN, paint, 0.055)


## THE FIN, a flat slab standing on the spine, and its RUDDER on its trailing edge.
func _fin(paint: Material) -> void:
	var tool := _tool()
	var root_le: float = FIN_FROM
	var root_te: float = FIN_TO
	var tip_le: float = root_le + (FIN_TIP_HIGH - FIN_ROOT_HIGH) * tan(deg_to_rad(FIN_SWEEP))
	var tip_te: float = root_te + 0.20
	var outline: Array = [
		point(0.0, FIN_ROOT_HIGH, root_le), point(0.0, FIN_TIP_HIGH, tip_le),
		point(0.0, FIN_TIP_HIGH, tip_te), point(0.0, FIN_ROOT_HIGH, root_te),
	]
	for lean in [0.055, -0.055]:
		var face: Array = []
		for c in outline:
			face.append(c + Vector3(lean, 0.0, 0.0))
		Plating.facing(tool, face, Vector3(signf(lean), 0.0, 0.0), TOP)
	for i in range(4):
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i + 1) % 4]
		Plating.facing(tool, [a + Vector3(0.055, 0.0, 0.0), b + Vector3(0.055, 0.0, 0.0),
			b - Vector3(0.055, 0.0, 0.0), a - Vector3(0.055, 0.0, 0.0)],
			(b - a).cross(Vector3.RIGHT).normalized(), TOP)
	_add(self, "Fin", tool, paint)


func _rudder(paint: Material) -> void:
	var a := point(0.0, FIN_ROOT_HIGH, FIN_TO)
	var b := point(0.0, FIN_TIP_HIGH, FIN_TO + 0.20)
	var hinge: Node3D = _hinge("Rudder", self, a, b - a, a + Vector3(0.0, 0.0, 0.4), Vector3.RIGHT)
	var tool := _tool()
	var outline: Array = [
		Vector3.ZERO, b - a,
		b - a + Vector3(0.0, 0.0, 0.42), Vector3(0.0, 0.0, 0.62),
	]
	for lean in [0.05, -0.05]:
		var face: Array = []
		for c in outline:
			face.append(c + Vector3(lean, 0.0, 0.0))
		Plating.facing(tool, face, Vector3(signf(lean), 0.0, 0.0), TOP)
	for i in range(4):
		var p: Vector3 = outline[i]
		var q: Vector3 = outline[(i + 1) % 4]
		Plating.facing(tool, [p + Vector3(0.05, 0.0, 0.0), q + Vector3(0.05, 0.0, 0.0),
			q - Vector3(0.05, 0.0, 0.0), p - Vector3(0.05, 0.0, 0.0)],
			(q - p).cross(Vector3.RIGHT).normalized(), TOP)
	_add(hinge, "Rudder", tool, paint)


## ONE NOZZLE: A SWAN-NECK ELBOW on a hinge across the aeroplane, which is what a Pegasus nozzle is.
##
## The flow leaves the engine OUTBOARD and the elbow turns it through a right angle so it leaves AFT; turning the
## elbow about that lateral axis swings the exit from aft, through down, to 8.5 degrees forward of down at the
## braking stop. All four are chained to one air motor [PEG], so they cannot point two ways and neither can these.
##
## WHAT THIS REPLACED, because it is the whole reason this lane exists. It was a ten-sided DRUM of radius 0.40 lying
## straight aft, identical for all four, typed 1.14 m outboard at a height where the body is 0.44 m of half-width --
## so it floated 0.30 m clear of the aeroplane, 0.80 m across on a body 1.46 m across, and in a side view it was a
## grey disc you had to hunt for. The aeroplane's defining feature was drawn as a bottle cap. The proof of how little
## it was doing: the HOVER-STOP render was indistinguishable from the level-flight one, both covering 15.3 per cent
## of the frame, because four nozzles at 82 degrees down changed the outline by nothing at all. Nine green checks
## said the angles were right and not one of them asked whether anybody could see them.
func _build_nozzle(side: float, named: String, station: float, hot: bool, paint: Material) -> void:
	var at := point(side * _flank_at(station, NOZZLE_HIGH), NOZZLE_HIGH, station)
	# WOUND SO A POSITIVE TURN SWINGS THE EXIT DOWN. The probe is a point straight aft of the hinge and the wanted
	# direction is down, so `_hinge` picks the sign and no mirrored nozzle turns the wrong way.
	var hinge: Node3D = _hinge(named, self, at, Vector3.RIGHT, at + Vector3(0.0, 0.0, 1.0), Vector3.DOWN)
	var tool := _tool()
	var root_r: float = NOZZLE_REAR_ROOT if hot else NOZZLE_FRONT_ROOT
	var exit_r: float = NOZZLE_REAR_EXIT if hot else NOZZLE_FRONT_EXIT
	var scarf: float = NOZZLE_REAR_SCARF if hot else 0.0
	var rings: Array = []
	var spines: Array = []
	for step in range(NOZZLE_BEND_STEPS + 1):
		var t: float = float(step) / float(NOZZLE_BEND_STEPS)
		var turn: float = t * PI * 0.5
		# THE ELBOW'S CENTRELINE, a quarter turn from the flank heading OUTBOARD to the exit heading AFT. It is NOT a
		# circular arc: the aft reach is three times the outboard one, because a nozzle stands a long way back and
		# only a little way out, and a true quarter circle would have put the exit 0.62 m outboard of a body that is
		# 1.24 m across at its widest.
		var spine := Vector3(side * NOZZLE_OUT_REACH * sin(turn), 0.0, NOZZLE_AFT_REACH * (1.0 - cos(turn)))
		var across := Vector3(-side * sin(turn), 0.0, cos(turn))
		var along := Vector3(side * cos(turn), 0.0, sin(turn))
		var r: float = lerpf(root_r, exit_r, t)
		var ring: Array = []
		for i in range(NOZZLE_SIDES):
			var a: float = TAU * float(i) / float(NOZZLE_SIDES)
			# THE SCARF, RAMPED ALONG THE BEND AND CUT IN THE HORIZONTAL PLANE. `across` is horizontal at every step,
			# so this lengthens one SIDE of the duct and never its top -- see the constant's doc block for why the
			# other cut would have quietly biased the angle check that reads this metal.
			ring.append(spine + across * (cos(a) * r) + Vector3(0.0, sin(a) * r, 0.0)
				- along * (scarf * cos(a) * t))
		rings.append(ring)
		spines.append(spine)
	for s in range(rings.size() - 1):
		var here: Array = rings[s]
		var next: Array = rings[s + 1]
		var axis: Vector3 = ((spines[s] as Vector3) + (spines[s + 1] as Vector3)) * 0.5
		for i in range(NOZZLE_SIDES):
			var j: int = (i + 1) % NOZZLE_SIDES
			var quad: Array = [here[i], next[i], next[j], here[j]]
			var mid: Vector3 = (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
			var out: Vector3 = (mid - axis).normalized()
			# TWO TRIANGLES, EACH WITH ITS OWN NORMAL, and not one quad. A quad down a BENT, TAPERING duct is not
			# planar, and `Plating.facing` stores a single normal for both of its triangles -- so on a curved tube one
			# triangle of the pair ends up wound against it. That is eight faces of 1,668, two per nozzle, invisible
			# in every render because a backwards face draws nothing; `_every_face_is_wound_outwards` is the only
			# thing in this project that would ever have said so, and it did, first time.
			_fan(tool, quad[0], quad[1], quad[2], out, METAL)
			_fan(tool, quad[0], quad[2], quad[3], out, METAL)
	# THE MOUTH, recessed so a nozzle reads as a hole rather than a plug, and the CASCADE OF VANES across it.
	var mouth: Array = rings[-1]
	var exit_centre: Vector3 = spines[-1]
	# THE HOLE IS SHALLOW ON PURPOSE: a Pegasus nozzle's mouth is very nearly filled by its cascade, so there is no
	# deep pipe to see down -- the dark cone only gives the rim something to sit against behind the vanes.
	#
	# IT WAS 0.45 AND THAT WAS THE WRONG WAY ROUND. `exhaust_ports` puts each plume at its mouth's CENTRE, where a
	# hollow nozzle has no metal at all, so the nearest vertex is this cone's apex -- and at 0.45 that read 0.180 m
	# against `_every_plume_leaves_its_own_drawn_nozzle`'s 0.20 limit. Green, by two centimetres, with the depth of a
	# decorative hole holding the margin. `craft/harrier/sources.md`'s own rule, paid for twice on this aeroplane
	# already: NOTHING IS FITTED TO A BOUND THE TEST THEN CHECKS AGAINST. A quarter of the exit radius is what a
	# cascade-filled mouth looks like, it was chosen by looking at one, and the check now passes with 0.10 m in hand.
	var deep: Vector3 = exit_centre - Vector3(0.0, 0.0, exit_r * 0.25)
	for i in range(NOZZLE_SIDES):
		var j: int = (i + 1) % NOZZLE_SIDES
		_fan(tool, deep, mouth[j], mouth[i], Vector3(0.0, 0.0, 1.0), BLACK)
	for v in range(NOZZLE_VANES):
		var high: float = exit_r * (2.0 * (float(v) + 1.0) / (float(NOZZLE_VANES) + 1.0) - 1.0)
		var chord: float = sqrt(maxf(exit_r * exit_r - high * high, 0.0)) * 0.92
		var slat: float = exit_r * 0.075
		var face: float = -exit_r * 0.16
		Plating.facing(tool, [
			exit_centre + Vector3(-chord, high + slat, face),
			exit_centre + Vector3(chord, high + slat, face),
			exit_centre + Vector3(chord, high - slat, face),
			exit_centre + Vector3(-chord, high - slat, face)],
			Vector3(0.0, 0.0, 1.0), METAL)
	_add(hinge, named, tool, paint)


## THE AUXILIARY BLOW-IN DOORS, drawn on the intake bell's own surface: five panels a side, each one laid on the
## circle `_intake` is built from, so a door cannot drift off the duct it belongs to however the bell is re-measured.
##
## They are quads on a curved surface and therefore NOT PLANAR, so they go down as triangles with their own normals.
## That is the same trap the nozzle elbow hit an hour earlier -- `Plating.facing` stores one normal for both of a
## quad's triangles, and on anything curved one of the pair comes out wound against it and then draws nothing.
func _blow_in_doors(side: float, named: String, paint: Material) -> void:
	var tool := _tool()
	var span: float = (DOOR_HIGH - DOOR_LOW) / float(DOORS)
	for k in range(DOORS):
		var low: float = DOOR_LOW + span * (float(k) + 0.14)
		var high: float = DOOR_LOW + span * (float(k) + 0.86)
		var corners: Array = []
		for pair in [[DOOR_FROM, high], [DOOR_TO, high], [DOOR_TO, low], [DOOR_FROM, low]]:
			var at_high: float = float(pair[1])
			var rise: float = at_high - INTAKE_HIGH
			var out: float = INTAKE_OUT + sqrt(maxf(INTAKE_RADIUS * INTAKE_RADIUS - rise * rise, 0.0)) + 0.015
			corners.append(point(side * out, at_high, float(pair[0])))
		var mid: Vector3 = (corners[0] + corners[1] + corners[2] + corners[3]) * 0.25
		var axis: Vector3 = point(side * INTAKE_OUT, INTAKE_HIGH, (DOOR_FROM + DOOR_TO) * 0.5)
		var face: Vector3 = (mid - axis).normalized()
		_fan(tool, corners[0], corners[1], corners[2], face, BLACK)
		_fan(tool, corners[0], corners[2], corners[3], face, BLACK)
	_add(self, named, tool, paint)


## THE GUN AND AMMUNITION PODS, PUBLISHED [SAC]: "25 mm gun pod + 300 rounds installed in removable pods", one either
## side of the centreline pylon -- and "fuselage strakes are interchangeable with the gun and ammo pack", so these two
## pods stand where the LIDS strakes otherwise would.
func _gun_pod(side: float, named: String, paint: Material) -> void:
	var tool := _tool()
	Plating.box(tool, Vector3(side * LIDS_OUT, -_half.y + PODS_HIGH, -_half.z + (LIDS_FROM + LIDS_TO) * 0.5),
		Vector3(0.36, PODS_DEEP, LIDS_TO - LIDS_FROM), LOWER)
	_add(self, named, tool, paint)


## THE LIDS FENCE, PUBLISHED [SAC]: a RETRACTABLE forward fence under the fuselage ahead of the pods, which with them
## traps the fountain of air rebounding off the ground in the hover. Drawn down; its retraction is on this lane's
## `What's next` because nothing yet tells it when the aeroplane is in the hover.
func _lids(paint: Material) -> void:
	var tool := _tool()
	Plating.box(tool, Vector3(0.0, -_half.y + PODS_HIGH - FENCE_DROP * 0.5, -_half.z + FENCE_STATION),
		Vector3(LIDS_OUT * 2.0, FENCE_DROP, 0.07), METAL)
	_add(self, "LidsFence", tool, paint)


## THE REACTION CONTROL JETS, named and placed by [NATOPS] Figure 1-1: forward pitch under the nose, aft pitch and yaw
## at the tailcone, and roll under each wingtip. Small, and drawn because they are a real thing a Harrier has that
## nothing else in this game does -- in the hover they are what the stick and pedals actually work.
func _reaction_jets(paint: Material) -> void:
	var tool := _tool()
	Plating.box(tool, point(0.0, 1.72, RCS_NOSE_STATION), Vector3(0.16, 0.14, 0.30), BLACK)
	Plating.box(tool, point(0.0, 2.36, RCS_TAIL_STATION), Vector3(0.18, 0.16, 0.34), BLACK)
	for side in [1.0, -1.0]:
		var out: float = RCS_TIP_OUT
		Plating.box(tool, point(side * out, wing_h(side * out) - 0.10, wing_le(side * out) + 0.30),
			Vector3(0.14, 0.12, 0.26), BLACK)
	_add(self, "ReactionJets", tool, paint)


## THE BICYCLE UNDERCARRIAGE. A nose leg and a main leg BOTH ON THE CENTRELINE, one behind the other, which is what a
## bicycle gear is and what makes a Harrier's stance unlike anything else here. Each swings forward into its well and
## its doors open, let it through and shut again.
func _centreline_gear(paint: Material) -> void:
	_leg("NoseGear", NOSE_STATION, TYRE_NOSE, 0.10, paint)
	_leg("MainGear", NOSE_STATION + WHEELBASE, TYRE_MAIN, 0.12, paint)
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		_well_doors("Nose" + named, side, NOSE_STATION, 0.34, paint)
		_well_doors("Main" + named, side, NOSE_STATION + WHEELBASE, 0.40, paint)


## THE OUTRIGGERS, the distinctive half. PUBLISHED at half the 17.0 ft "wing gear spread", which is 2.591 m out --
## 56 per cent of semi-span, MID-SPAN and well inboard of a 4.62 m tip. A first-generation Harrier carried them AT
## the tip; moving them in is one of the things that makes this aeroplane a II, and `tests/harrier.gd` holds the two
## drawn tyres 5.182 m apart against the published figure rather than against anything measured off this model.
func _outrigger(side: float, named: String, paint: Material) -> void:
	var station: float = NOSE_STATION + WHEELBASE + OUTRIGGER_AFT
	var out: float = side * OUTRIGGER_OUT
	var top: Vector3 = point(out, wing_h(out) - 0.10, station)
	var hinge: Node3D = _hinge("Outrigger" + named, self, top, Vector3(0.0, 0.0, 1.0),
		top + Vector3(0.0, -1.0, 0.0), Vector3(-side, 0.0, 0.0))
	var tool := _tool()
	var drop: float = top.y - (-_half.y + ground_at(station) + TYRE_OUTRIGGER)
	Plating.box(tool, Vector3(0.0, -drop * 0.5, 0.0), Vector3(0.09, drop, 0.09), GEAR_WHITE)
	_tyre(tool, Vector3(0.0, -drop, 0.0), TYRE_OUTRIGGER, 0.07)
	var mesh := _add(hinge, "Outrigger" + named, tool, paint)
	_legs.append(hinge)
	# STOWED: folded inboard and up into the wing, which is where a Harrier's outriggers go.
	_stowed.append(Quaternion(Vector3(0.0, 0.0, 1.0), deg_to_rad(88.0) * -side))
	# ITS POD, which stays put: the fairing the leg folds into, a real feature of the wing's outboard panel.
	var pod := _tool()
	Plating.box(pod, point(out, wing_h(out) - 0.06, station - 0.10), Vector3(0.26, 0.24, 1.10), LOWER)
	_add(self, "OutriggerPod" + named, pod, paint)


## ONE CENTRELINE LEG: a strut and a tyre, swinging forward into its well.
func _leg(named: String, station: float, tyre: float, wide: float, paint: Material) -> void:
	var belly: float = _bottom_at(station)
	var top := point(0.0, belly + 0.06, station)
	var hinge: Node3D = _hinge(named, self, top, Vector3.RIGHT, top + Vector3(0.0, -1.0, 0.0),
		Vector3(0.0, 0.0, -1.0))
	var tool := _tool()
	var drop: float = top.y - (-_half.y + ground_at(station) + tyre)
	Plating.box(tool, Vector3(0.0, -drop * 0.5, 0.0), Vector3(wide, drop, wide), GEAR_WHITE)
	_tyre(tool, Vector3(0.0, -drop, 0.0), tyre, 0.11)
	_add(hinge, named, tool, paint)
	_legs.append(hinge)
	# STOWED: swung forward and up into the well, 84 degrees, which is the F-35B's way and the photographs'.
	_stowed.append(Quaternion(Vector3.RIGHT, deg_to_rad(84.0)))


## A TYRE: a low-sided drum, 8 facets, the Hawkeye's count.
func _tyre(tool: SurfaceTool, at: Vector3, radius: float, wide: float) -> void:
	for i in range(WHEEL_SIDES):
		var a: float = TAU * float(i) / float(WHEEL_SIDES)
		var b: float = TAU * float(i + 1) / float(WHEEL_SIDES)
		var pa := at + Vector3(0.0, sin(a) * radius, cos(a) * radius)
		var pb := at + Vector3(0.0, sin(b) * radius, cos(b) * radius)
		Plating.facing(tool, [pa + Vector3(wide, 0.0, 0.0), pb + Vector3(wide, 0.0, 0.0),
			pb - Vector3(wide, 0.0, 0.0), pa - Vector3(wide, 0.0, 0.0)],
			(pa - at).normalized(), TYRE_BLACK)
		for face in [1.0, -1.0]:
			_fan(tool, at + Vector3(wide * face, 0.0, 0.0), pa + Vector3(wide * face, 0.0, 0.0),
				pb + Vector3(wide * face, 0.0, 0.0), Vector3(face, 0.0, 0.0), TYRE_BLACK)


## A WELL'S DOORS, hinged on the belly either side of the leg's line and opening outwards. EACH STOPS SHORT OF WHERE
## ITS LEG LEAVES THE BELLY, because a door that shuts after the gear is down cannot shut across the leg.
func _well_doors(named: String, side: float, station: float, length: float, paint: Material) -> void:
	var belly: float = _bottom_at(station)
	var inner: float = 0.08
	var outer: float = 0.34
	var a := point(side * outer, belly, station - length)
	var b := point(side * outer, belly, station + length)
	_slab("%sDoor%s" % ["Nose" if named.begins_with("Nose") else "Main",
		"Starboard" if side > 0.0 else "Port"], self,
		[a, b, point(side * inner, belly, station + length), point(side * inner, belly, station - length)],
		a, b, Vector3(side, -1.0, 0.0), paint, 0.025, WELL)


## ONE COLUMN OF `SECTIONS`, INTERPOLATED TO A STATION. The skin's top, its bottom and its side are three questions
## with one answer underneath them, and they were three copies of the same walk until the nozzles needed a fourth.
func _section_at(station: float, column: int) -> float:
	for i in range(SECTIONS.size() - 1):
		var here: float = float(SECTIONS[i][0])
		var next: float = float(SECTIONS[i + 1][0])
		if station >= here and station <= next:
			var t: float = (station - here) / maxf(next - here, 1e-6)
			return lerpf(float(SECTIONS[i][column]), float(SECTIONS[i + 1][column]), t)
	return float(SECTIONS[-1][column])


## THE SKIN'S BOTTOM AT A STATION.
func _bottom_at(station: float) -> float:
	return _section_at(station, 11)


## THE SKIN'S TOP AT A STATION.
func _top_at(station: float) -> float:
	return _section_at(station, 1)


## THE SKIN'S HALF-WIDTH AT A STATION AND A HEIGHT -- WHERE THE BODY'S SIDE IS, ASKED OF THE BODY.
##
## The nozzles hang off this instead of off a typed offset, so each one's root sits ON the flank at its own station
## whatever `SECTIONS` is later measured to be. They were typed at 1.14 m out at a height where the body is 0.44 m of
## half-width, so they floated 0.30 m clear of the aeroplane and read as discs bolted to the air beside it. That is
## `CLAUDE.md` rule 4 -- one number, one place; ask the authority, do not keep a roster -- and it cost a lane.
##
## The ring's half-outline descends: crown, shoulder, chine, under, belly. A height above the top or below the bottom
## returns nothing rather than the nearest edge, because a nozzle asking for a flank that is not there is a fault to
## see and not one to paper over.
func _flank_at(station: float, high: float) -> float:
	var pairs: Array = [
		Vector2(0.0, _section_at(station, 1)),
		Vector2(_section_at(station, 2), _section_at(station, 3)),
		Vector2(_section_at(station, 4), _section_at(station, 5)),
		Vector2(_section_at(station, 6), _section_at(station, 7)),
		Vector2(_section_at(station, 8), _section_at(station, 9)),
		Vector2(_section_at(station, 10), _section_at(station, 11)),
	]
	for i in range(pairs.size() - 1):
		var a: Vector2 = pairs[i]
		var b: Vector2 = pairs[i + 1]
		if high <= a.y and high >= b.y:
			return lerpf(a.x, b.x, (a.y - high) / maxf(a.y - b.y, 1e-6))
	return 0.0
