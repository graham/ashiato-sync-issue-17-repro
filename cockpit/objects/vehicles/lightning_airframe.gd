@tool
extends Node3D
class_name LightningAirframe
## A LOCKHEED MARTIN F-35B LIGHTNING II, DRAWN: THE STOVL ONE. Its first-glance features are the chined nose, the one-piece
## bubble canopy with no bow, the diamond (DSI) intakes whose cowls sweep forward, the trapezoid wing, the twin fins canted
## out 20 degrees, and the all-moving tailplanes on booms either side of a round nozzle. It is the B, not the A or the C, and
## what makes it the B is drawn and MOVES:
## - THE SWIVELLING NOZZLE (`set_nozzle`): one rotating nozzle swung from straight aft to 95 degrees down. The real
##   three-bearing swivel module turns three segments against each other to get there; the user asked for "just a nozzle
##   that can rotate", so this is one part on one hinge;
## - THE LIFT FAN behind the cockpit, under its big rear-hinged door, with the two auxiliary inlet doors aft of it, the
##   louvre doors under it and a roll-post door under each wing. They open with the nozzle;
## - THE GEAR, three legs, each well shut by doors that open, let the leg through and SHUT AGAIN (`set_gear`);
## - TWO WEAPONS BAYS in the belly, each with an inner and an outer door (`set_bay`).
## There is no internal gun: the B's GAU-22/A is a belly pod, not drawn here.
##
## PRESENTATION ONLY. The native simulation owns the size (`dress` reads `extents` and `span`), the flight, the collision,
## the stations and the wire: kind 32, LIGHTNING, since 2026-09-19. And it owns the NOZZLE'S TRAVEL, `vector_travel` in the
## kind's handling, which the thrust swings through: the drawing reads it rather than keeping a copy, so the nozzle the
## pilot sees and the force the world applies are one number (`tests/lightning.gd` holds them to each other).
##
## ORIGINAL GEOMETRY, MEASURED. No mesh, texture, photograph or livery is incorporated. Every size names its source:
## - [JSF] the JSF Program Office's three orthographic renders of the F-35B (`F-35B_Top.jpg`, `_Side.jpg` and `_Front.jpg`
##   on Commons, from jsf.mil media kit 7763, PUBLIC DOMAIN as a US DoD work). The three views share ONE camera scale,
##   178.88 px a metre, set by the published span: the plan span reads 1,914 px and the front span 1,911 (0.16 per cent);
##   the plan length 2,791 px and the side 2,793 (0.07). At that scale the length is 15.603 m against the published 15.6. `craft/lightning/measure_views.py` re-derives every MEASURED figure here from the
##   three images alone, reading nothing out of this file or out of `sources.md`.
## - [WP] Wikipedia's "Differences among variants" table for the B: 15.6 m long, 10.7 m span, 4.36 m high, 42.7 m2 of wing.
##   And "Rolls-Royce LiftSystem": the nozzle "able to rotate through 95 degrees in 2.5 seconds", the fan 1.3 m across.
## - [PH] Commons photographs of parked F-35Bs (public domain), studied for the gear and nothing incorporated.
## - ESTIMATE where nothing gives a figure, and it says what it was reasoned from.
##
## STATIONS ARE METRES AFT OF THE NOSE TIP and HEIGHTS ARE METRES OVER THE BELLY DATUM, the side view's lowest point with the
## gear up (the bay doors at station 9.0). [JSF] draws the gear UP, so the ground is not in the drawing: it is put
## `CLEARANCE` under the datum, so the fin tip stands at [WP]'s published 4.36 m. That makes the height a figure the model
## is BUILT to, not one it can be checked against, and `tests/lightning.gd` says so beside the check.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT. The user's direction of 2026-09-17: "a somewhat lower poly look ... not too
## many very round edges", with the E-2D Hawkeye as the aircraft with the right approach. Every count here is at or below the
## Hawkeye's for the same kind of part:
## - the FUSELAGE is 12 facets a ring (six a side, between the spine, crown, shoulder, chine, under-chine, belly edge and
##   keel) through the measured rings, against the Hawkeye's 20. The F-35 is drawn in flat planes for stealth, so its creases are real:
##   the chine is a hard edge from the nose tip to the wing;
## - NOZZLE_SIDES 12, with a sawtooth exit of 12 teeth (the real one has 15 flaps); WHEEL_SIDES 8; LIFT_FAN_SIDES 8;
## - a wing section is six points, as the F-16's is; the fins, tailplanes and doors are flat slabs.
## Every face carries its own normal; nothing is smoothed.

## [WP] The published envelope of the F-35B, held by `tests/lightning.gd`.
const LENGTH: float = 15.6
const SPAN: float = 10.7
const HEIGHT: float = 4.36

## THE SIMULATION'S SHAPE IS KIND 32, LIGHTNING (`cockpit_world.cpp`, `lightning_shape`): the box is the intakes' 1.80 m
## half-width, the ground to the canopy's top, and the nose tip to the tailplanes' trailing edge; the span is [WP]'s. It was
## a draft here until the kind arrived, and the draft is gone.

## THE FIN TIP over the belly datum [JSF side view, 3.46 m], and the ground under the datum that puts the tip at HEIGHT.
const FIN_TIP: float = 3.46
const CLEARANCE: float = HEIGHT - FIN_TIP

## THE PAINT. The F-35's "Have Glass V" is FS 36170, a dark grey, one colour all over; the upper surfaces are drawn a shade
## darker than the lower so the chine reads in flat light. ESTIMATE, sRGB approximations. The wells, bays and doors' inner
## faces are the gloss white the photographs show [PH].
const TOP := Color(0.33, 0.35, 0.37)
const LOWER := Color(0.39, 0.41, 0.43)
const GLASS := Color(0.42, 0.35, 0.18)
const FRAME := Color(0.22, 0.23, 0.24)
const BLACK := Color(0.04, 0.04, 0.045)
const METAL := Color(0.26, 0.26, 0.27)
const WELL := Color(0.80, 0.81, 0.82)
const GEAR_WHITE := Color(0.86, 0.87, 0.86)
const TYRE := Color(0.06, 0.06, 0.06)
const FAN := Color(0.46, 0.45, 0.43)

## THE FUSELAGE, RING BY RING. Each row is
##   [station, top, crown_w, crown_h, shoulder_w, shoulder_h, chine_w, chine_h, under_w, under_h, belly_w, bottom]
## with half-widths out from the centreline and heights over the belly datum.
## - `top` and `bottom` are [JSF]'s side silhouette, column by column (measure_views.py prints them every 0.25 m).
## - `chine` is the plan outline: the nose chine grows 0.12 m a metre from the tip (0.45 m out at station 1, 0.82 at 4);
##   aft of the intakes it is the intake nacelles' sides, 1.67 m out at 4.75 to 1.77 at 7.0, and under the wing it is the
##   wing root. Its HEIGHT is the chine line in the side view: 0.86 m at the nose tip, 1.04 at the intake's top lip.
## - Over the cockpit, `shoulder` is the canopy's sill: its plan half-width off [JSF]'s gold glazing (0.30 m at 2.1 to 0.60
##   at 3.8), its height the glazing's lower edge in the side view (1.47 to 1.60 m).
## - BEHIND THE CANOPY THE TOP IS NEARLY FLAT 0.45 m either side, where the lift fan's door lies, and 0.58 m over the
##   auxiliary inlet doors: a door laid on a ridge floats at its edges or has the spine through its middle. The first
##   build made it 0.62 m and the front overlay showed square shoulders standing out of the render's outline.
## - UNDER THE WING THE LOWER FUSELAGE FLARES OUT, 2.05 m out at 0.78 m up from 8 to 11 m: the front view is 2.22 m wide at
##   0.75 m up, which nothing else of the aeroplane reaches, and the first build's front overlay agreed over 79.5 per cent.
## - Aft of the canopy the upper fuselage is a steep roof: the front view is only 0.92 m across at 1.60 m up and 1.29 at
##   1.45, so the shoulder stands 0.9 m out at 1.60 and falls to the chine.
## - `under` and `belly` are the lower fuselage: the front view is 1.49 m out at 0.30 m up and 1.32 at 0.10.
## - BETWEEN 4.20 AND 5.35 THE FUSELAGE IS THE INNER BODY ONLY; the intake nacelles outside it are their own parts, and
##   it widens to them only BEHIND THE THROAT: the first build widened from 4.75, and a ray fired into the mouth met the
##   body's grey side ahead of the throat (`tests/lightning.gd`, 2 of 8 rays).
const SECTIONS: Array = [
	[0.30, 1.00, 0.05, 0.98, 0.10, 0.93, 0.14, 0.87, 0.11, 0.78, 0.06, 0.73],
	[0.75, 1.18, 0.10, 1.15, 0.24, 1.06, 0.36, 0.89, 0.28, 0.70, 0.14, 0.55],
	[1.25, 1.31, 0.14, 1.28, 0.33, 1.16, 0.48, 0.92, 0.37, 0.62, 0.19, 0.38],
	[1.95, 1.58, 0.14, 1.56, 0.30, 1.46, 0.58, 0.95, 0.45, 0.58, 0.23, 0.32],
	[2.50, 1.91, 0.27, 1.86, 0.43, 1.49, 0.64, 0.97, 0.50, 0.60, 0.26, 0.30],
	[3.00, 2.16, 0.33, 2.08, 0.53, 1.50, 0.70, 0.99, 0.55, 0.60, 0.28, 0.28],
	[3.50, 2.22, 0.35, 2.13, 0.57, 1.54, 0.76, 1.01, 0.60, 0.60, 0.30, 0.25],
	[3.80, 2.21, 0.37, 2.12, 0.60, 1.58, 0.80, 1.02, 0.62, 0.58, 0.31, 0.24],
	[4.20, 2.17, 0.45, 2.15, 0.66, 1.66, 0.86, 1.04, 0.68, 0.56, 0.33, 0.21],
	[4.75, 2.13, 0.46, 2.11, 0.75, 1.72, 0.92, 1.10, 0.74, 0.50, 0.40, 0.19],
	[5.35, 2.11, 0.46, 2.09, 0.85, 1.70, 0.98, 1.12, 0.80, 0.48, 0.46, 0.16],
	[5.90, 2.09, 0.48, 2.07, 0.88, 1.68, 1.66, 1.14, 1.48, 0.48, 1.25, 0.10],
	[6.20, 2.08, 0.60, 2.07, 0.90, 1.66, 1.72, 1.15, 1.52, 0.48, 1.30, 0.06],
	[7.00, 2.01, 0.58, 2.00, 0.92, 1.63, 1.77, 1.16, 1.55, 0.50, 1.35, 0.03],
	[8.00, 1.96, 0.58, 1.95, 0.92, 1.60, 1.80, 1.17, 2.00, 0.78, 1.25, 0.03],
	[9.00, 1.93, 0.52, 1.89, 0.92, 1.58, 1.80, 1.17, 2.05, 0.78, 1.25, 0.00],
	[10.0, 1.91, 0.52, 1.87, 0.92, 1.56, 1.80, 1.17, 2.05, 0.78, 1.25, 0.01],
	[11.0, 1.88, 0.52, 1.84, 0.92, 1.54, 1.80, 1.17, 2.02, 0.78, 1.25, 0.01],
	[12.0, 1.86, 0.50, 1.82, 0.88, 1.52, 1.72, 1.15, 1.85, 0.72, 1.28, 0.08],
	[12.6, 1.66, 0.42, 1.62, 0.70, 1.45, 1.10, 1.05, 1.00, 0.60, 0.70, 0.18],
	[13.2, 1.40, 0.30, 1.37, 0.52, 1.25, 0.66, 0.90, 0.60, 0.62, 0.34, 0.33],
]
const FUSELAGE_SIDES: int = 12
## THE NOSE TIP [JSF side view]: 0.86 m over the datum, on the chine.
const NOSE_TIP_H: float = 0.86

## THE CANOPY [JSF]: one transparency from the windscreen's foot at 1.95 m to its aft point at 4.20, the glazing's gold in
## both views. No bow: the F-35's canopy is one piece, and the aft frame is the fuselage behind it.
const CANOPY: Vector2 = Vector2(1.95, 4.20)

## THE INTAKES [JSF]: the mouth in the front view is a leaning quadrilateral, 0.72 to 1.22 m out at 0.43 m up and 1.08 to
## 1.47 at 1.15. Its lip is RAKED BOTH WAYS: in plan the outer lip leads (4.22 at 1.47 out, 4.45 at 1.08) and in the side
## view the top leads (4.22 at 1.15 up, about 4.95 at the bottom). The corners are [out, height, station], inner-low,
## outer-low, outer-high, inner-high.
const MOUTH: Array = [[0.72, 0.43, 5.00], [1.22, 0.42, 4.85], [1.47, 1.15, 4.22], [1.08, 1.15, 4.45]]
## The cowl's thickness at the lip, and where the nacelle's walls bed into the full-width fuselage: ESTIMATE.
const LIP: float = 0.09
const NACELLE_END: float = 6.20
## How far behind the lip the dark throat sits: enough that a lit mouth reads as a hole, as the F-16's does.
const THROAT_DEPTH: float = 0.28

## THE WING [JSF], fitted by measure_views.py over 130 rows each side: the LEADING EDGE is station 6.377 + 0.6745 x out
## (starboard, 4.3 mm rms) and 6.365 + 0.6743 x out (port, 4.6 mm), 34.0 degrees; inboard of 2.6 m out it curves into the
## LEX along the plan outline (1.77 m out at 7.0, 2.00 at 7.5, 2.42 at 8.0). The TRAILING EDGE runs forward about 0.25 m a
## metre outboard (12.878 - 0.260 x out starboard, 12.858 - 0.253 port, over 75 rows outboard of the tailplane), to 11.50 at
## the tip, 5.33 m out. The front view has the wing at 1.10 m up at the tip and about 1.18 at the
## root: 1.5 degrees of anhedral.
const WING_LE: Vector2 = Vector2(6.363, 0.675)
const LEX: Array = [[1.60, 6.90], [1.77, 7.00], [1.87, 7.25], [2.00, 7.50], [2.12, 7.75], [2.42, 8.00], [2.60, 8.118]]
const WING_TE: Vector2 = Vector2(12.83, -0.25)
const WING_ROOT: float = 1.60
const WING_TIP: float = 5.33
const WING_H: Vector2 = Vector2(1.18, 1.10)  # root, tip
## Thickness a share of chord, root to tip: ESTIMATE (a thin supersonic section).
const WING_THICK: Vector2 = Vector2(0.05, 0.04)
## THE FLAPERONS [JSF plan's panel line]: a hinge 0.68 m ahead of the trailing edge, from 2.03 m out to 4.69.
const FLAPERON: Vector3 = Vector3(2.03, 4.69, 0.68)  # inner, outer, chord
const FLAPERON_TRAVEL: float = deg_to_rad(20.0)

## THE TAILPLANES [JSF], all-moving: the leading edge station 12.82 + 0.756 x (out - 2.0), 37 degrees, to a tip 3.63 m out;
## the trailing edge 15.32 - 0.245 x (out - 2.0), and the inner trailing corner 1.03 m out at 15.57, the aeroplane's aft end.
## The root steps round the tail boom, which narrows from 1.65 to 1.0 m out at 14.2, so the tailplane turns clear of it.
## In the side view it lies at 1.15 m up. Pivot at 14.0: ESTIMATE, where an all-moving surface of this chord balances.
const TAIL: Array = [[1.68, 12.58], [3.63, 14.05], [3.63, 14.92], [1.03, 15.57], [1.03, 14.40], [1.68, 14.22]]
const TAIL_H: float = 1.15
const TAIL_PIVOT: float = 14.0
const TAIL_TRAVEL: float = deg_to_rad(20.0)

## THE FINS [JSF]: the side view (heights as drawn, so as projected) has the leading edge from (12.03, 1.9) to (13.41,
## 3.46), 0.885 m aft a metre up, and the trailing edge from (14.01, 1.9) to (14.82, 3.46); the front view has the fin
## 1.65 m out at 1.9 m up and the tip 2.22 out at 3.45: CANTED 20 DEGREES OUT. The rudder's hinge is the side view's
## panel line, (13.58, 1.9) to (14.44, 3.46).
## THE ROOT IS NOT AT 1.9 m, where the side view first shows the fin: there it comes out from behind the spine. The FRONT
## view has nothing at all between 0.92 and 1.46 m out at 1.6 m up, and the fin reaching down and in to 1.38 m out at 1.45,
## so the fin runs down to the boom at about 1.30 m up, 1.43 out, and its root chord runs from 11.50 on the leading edge's
## line -- where the plan view first shows the fins. The first build stood the fins on booms 1.86 m tall, and the rear
## quarter was two boxes with fins on them.
const FIN_ROOT: Vector2 = Vector2(1.43, 1.30)  # out, height
const FIN_CANT: float = deg_to_rad(20.2)
const FIN: Array = [[11.50, 1.30], [13.41, 3.46], [14.44, 3.46], [13.25, 1.30]]
const RUDDER: Array = [[13.25, 1.30], [14.44, 3.46], [14.82, 3.46], [13.70, 1.30]]
const RUDDER_TRAVEL: float = deg_to_rad(25.0)

## THE TAIL BOOMS the fins and tailplanes stand on, either side of the nozzle [JSF plan and side]: rows [station, inner,
## outer, low, top].
const BOOM: Array = [[11.8, 0.70, 1.72, 0.45, 1.26], [13.0, 0.72, 1.68, 0.55, 1.34], [14.2, 0.75, 1.66, 0.72, 1.32],
	[14.25, 0.75, 1.00, 0.74, 1.28], [14.90, 0.80, 1.00, 0.92, 1.20]]

## THE NOZZLE [JSF]: round, between the booms, its axis 0.85 m up, 0.52 m in radius at its root and 0.45 at the sawtooth
## exit, which is at station 13.85 (the plan's serrations run 13.4 to 13.85). It turns on ONE HINGE at its root, 13.0,
## straight aft at 0 and the kind's `vector_travel` down at 1 -- 95 degrees [WP: "able to rotate through 95 degrees"],
## asked of the simulation in `dress`. `NOZZLE_TRAVEL` is only what a library too old to say is drawn with.
const NOZZLE_AXIS: float = 0.85
const NOZZLE_ROOT: float = 13.0
const NOZZLE_EXIT: float = 13.85
const NOZZLE_R: Vector2 = Vector2(0.52, 0.45)
const NOZZLE_SIDES: int = 12
const NOZZLE_TRAVEL: float = deg_to_rad(95.0)

## THE LIFT FAN [JSF plan's panels, WP]: its door runs 4.35 to 5.95 behind the canopy, 0.45 m either side, hinged at its
## aft edge and standing up 70 degrees open (ESTIMATE, from photographs of hovering F-35Bs). The two auxiliary inlet doors
## are the plan's pair of panels at 6.63 to 7.97, each 0.55 m wide, hinged at their outboard edges and opening 50 degrees
## (ESTIMATE). The fan is 1.3 m across [WP], under the door; the louvre doors under it are ESTIMATE, 4.75 to 5.75.
const FAN_DOOR: Vector3 = Vector3(4.35, 5.95, 0.45)  # fore, aft, half width
const FAN_DOOR_OPEN: float = deg_to_rad(70.0)
const AUX_DOORS: Vector3 = Vector3(6.63, 7.97, 0.55)
const AUX_DOOR_OPEN: float = deg_to_rad(50.0)
const FAN_CENTRE: float = 5.15
## THE DRAWN FAN IS NARROWER THAN THE REAL ONE: it lies in the opening under the door, over the skin rather than in a
## hole cut through it, so it can be no wider than the door or its edge stands out of the skin with the door shut.
const FAN_RADIUS: float = 0.43
const LIFT_FAN_SIDES: int = 8
## HOW MANY BLADE PASSES A SECOND THE FAN IS DRAWN AT: slow enough to read as a turning fan rather than a strobe of
## blades standing still (a real fan's 8,000 rpm would alias). ESTIMATE, for the look.
const FAN_BLADE_PASSES: float = 3.0
const LOUVRE_DOORS: Vector3 = Vector3(4.75, 5.75, 0.36)
const LOUVRE_OPEN: float = deg_to_rad(80.0)
## THE ROLL POSTS' DOORS under each wing, 2.95 m out, 10.05 to 10.45: ESTIMATE, from photographs.
const ROLL_POST: Vector3 = Vector3(2.95, 10.05, 10.45)
## THE DOORS LEAD THE NOZZLE: they are open by the time the nozzle has turned a tenth of its travel.
const DOORS_BY: float = 0.1

## THE WEAPONS BAYS, ESTIMATE from photographs of the open bays [PH]: 6.50 to 10.60 (an AIM-120C is 3.66 m long), each an
## inner door hinged at the keel strip 0.12 m out and an outer door hinged at the bay's outer edge, 0.80 m out, the two
## meeting at 0.38. Both open to 95 degrees. The outer edge was 0.90 until the cavity behind the doors was cut: at 0.90
## it ran through a stowed main leg's upper end (0.85 m out), which `the_stowed_gear_is_inside_the_skin` caught.
const BAY: Vector2 = Vector2(6.50, 10.60)
const BAY_EDGES: Vector3 = Vector3(0.12, 0.38, 0.80)  # keel, doors meet, outer edge
## THE BAYS ARE HOLES, not paint: the belly is cut open over each and a white box stands behind the hole, its roof 0.52 m
## over the datum, so a missile can hang inside it (0.25 m up, fins 0.45 m across, clear of the doors) and be seen when
## the doors open. Painted on a flat belly, an AMRAAM was either buried in the skin or through the shut doors. The outer
## edge is 0.80 m out: at 0.90 the stowed main leg's inboard corner stood in the bay (0.85 m out, 0.49 up, station 6.85;
## `tests/lightning.gd`), and the AMRAAM's fins reach only 0.775.
const BAY_ROOF: float = 0.52
## HOW LONG THE BAY DOORS ARE DRAWN TAKING TO OPEN OR SHUT, seconds: the simulation's `kBayDoorSeconds`, the time it waits
## after opening a bay before it pushes the missile out, so the doors are drawn fully open before the missile moves.
## `tests/lightning_bays.gd` holds the server's wait to at least this.
const BAY_SECONDS: float = 1.0
const BAY_OPEN: float = deg_to_rad(95.0)

## THE GUN POD, the B's only gun: the GAU-22/A in Terma's multi-mission pod on the centreline (Wikipedia: "a Terma A/S
## multi-mission pod ... carrying the GAU-22/A and 220 rounds"). Where it hangs is an ESTIMATE from photographs, placed
## between the nose gear's leg and the bays so neither a leg nor a bay door meets it: 4.40 to 6.45, 0.22 m across, its
## underside 0.28 m under the datum. The muzzle is at its nose, 0.12 m under the datum -- `gun_port()`, which the
## simulation's gun (`loadout_of`) is held to by `tests/lightning_bays.gd`.
const POD: Vector4 = Vector4(4.40, 6.45, 0.11, -0.28)  # fore, aft, half width, underside
const MUZZLE_H: float = -0.12
## How far under the belly a shut door's middle lies, so it covers the white well behind it, which lies 1 cm under.
const DOOR_DROP: float = 0.03

## THE GEAR, ESTIMATE from [PH] (the renders draw it up). Tyres 0.64 m (mains) and 0.46 m (nose): the Cope North broadside
## has the main tyre 0.71 of the belly's height over the ground. The legs are [pivot, axle, stowed axle], each (out, height,
## station): the nose leg swings FORWARD into a well under the nose, and the mains forward into wells outboard of the bays.
## The track, 3.2 m, is the fins' spread against the mains' in the same photograph. Every tyre stands on the ground.
const NOSE_TYRE: float = 0.46
const MAIN_TYRE: float = 0.64
const NOSE_LEG: Array = [Vector3(0.0, 0.60, 3.55), Vector3(0.0, -0.67, 4.00), Vector3(0.0, 0.62, 2.20)]
const MAIN_LEG: Array = [Vector3(1.05, 0.55, 8.35), Vector3(1.60, -0.58, 8.50), Vector3(1.12, 0.47, 7.08)]
const WHEEL_SIDES: int = 8
## THE WELL DOORS: the nose's pair 2.0 to 3.45 either side of the centreline, 0.18 m out, hinged outboard; each main's
## 0.92 to 1.24 m out (the flat of the belly), 6.85 to 8.20, hinged INBOARD so the leg comes down past the open door rather than into it. EACH
## STOPS SHORT OF WHERE ITS LEG LEAVES THE BELLY (3.68 on the nose, 8.42 on a main), because a door that shuts after the
## gear is down cannot shut across the leg: the first build ran them to 3.80 and 8.60 and `tests/lightning.gd` found
## every door closing through its own strut at 86 and 94 per cent of the cycle. The leg's exit is its own door's.
const NOSE_WELL: Vector3 = Vector3(2.00, 3.45, 0.18)
const MAIN_WELL: Array = [0.92, 1.24, 6.85, 8.20]
const WELL_OPEN: float = deg_to_rad(85.0)
## THE GEAR CYCLE AS SHARES OF ONE AMOUNT, 0 up and 1 down: the doors open over the first fifth, the legs travel over the
## middle three, and the doors shut over the last. Read backwards the same function retracts in the same order.
const DOORS_OPEN_BY: float = 0.2
const DOORS_SHUT_FROM: float = 0.8
## HOW LONG A WHOLE GEAR CYCLE IS DRAWN TAKING, seconds. ESTIMATE: fighters take six to ten; the user's word on
## actuators is that the time "isn't important right now, we just need to be able to adjust it" (2026-09-17). Here.
const GEAR_SECONDS: float = 6.0

## THE COCKPIT. The pilot's helmet is at station 3.3, 1.75 m over the datum in [JSF]'s side view; the station puts the eye
## `CockpitStation.EYE_HEIGHT` over the seat, so the seat follows the eye and the floor is 4 cm over the seat. The ROOM is
## the largest box promised inside the drawn skin there, held to the triangles by `tests/lightning.gd`.
const EYE: Vector2 = Vector2(3.30, 1.75)  # station, height
const ROOM: AABB = AABB(Vector3(-0.35, 0.44, 2.85), Vector3(0.70, 1.34, 1.10))

## Small fittings stop drawing once the aeroplane is a few pixels high.
const DETAIL_RANGE: float = 700.0
const DETAIL_HYSTERESIS: float = 70.0

var _half: Vector3 = Vector3.ONE
## THE NOZZLE'S TRAVEL, radians, the simulation's `vector_travel` for the kind.
var _travel: float = NOZZLE_TRAVEL
var _span: float = 1.0
var _hinges: Dictionary = {}
var _nozzle: float = 0.0
var _gear: float = 1.0
var _bays: Array[float] = [0.0, 0.0]
var _fan_phase: float = 0.0
var _pitch: float = 0.0
var _roll: float = 0.0
var _yaw: float = 0.0
var _legs: Array[Node3D] = []
var _stowed: Array[Quaternion] = []


## BUILT IN PLACE, after `new()`, from the simulation's geometry: the view's, or the draft until the kind exists.
func dress(geometry: Dictionary = {}) -> void:
	name = "Lightning"
	var native: Dictionary = geometry if geometry.has("extents") else Sim.geometry_of(Sim.Kind.LIGHTNING)
	_half = native["extents"] as Vector3
	_span = float(native["span"])
	_travel = float(Sim.handling_of(Sim.Kind.LIGHTNING).get("vector_travel", NOZZLE_TRAVEL))
	var paint: StandardMaterial3D = ShipHull.painted()
	paint.roughness = 0.6
	# THE CANOPY IS GLASS THE PILOT SEES OUT THROUGH, drawn from both sides and a quarter opaque. It was 0.55, as the
	# F-16's is, and with the B's dark gold GLASS that put the whole world behind a murky brown pane from the seat:
	# team-lead read the station picture as "inside a hangar" (step 2's cockpit-lightning-15). At 0.25 the gold still
	# reads over the dark cockpit from outside, and from inside the sky is the sky.
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.vertex_color_is_srgb = true
	glass.albedo_color = Color(1.0, 1.0, 1.0, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.08
	glass.metallic = 0.35
	# THE SKIN SEEN FROM THE SEAT: double-sided, or from inside the one closed solid the pilot sees no aeroplane at all
	# (the Tomcat's and the F-16's station pictures, 2026-09-18).
	var inside: StandardMaterial3D = ShipHull.painted()
	inside.roughness = 0.6
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED

	# THE CANOPY IS THE FUSELAGE'S SECOND SURFACE, so the skin round the pilot is one closed solid (`tests/shell_room.gd`).
	var body := _tool()
	var canopy := _tool()
	_fuselage(body, canopy)
	var fuselage := _add(self, "Fuselage", body, paint)
	var wells := _tool()
	_wells(wells)
	_add(self, "Wells", wells, paint)
	fuselage.material_override = null
	fuselage.mesh = canopy.commit(fuselage.mesh as ArrayMesh)
	fuselage.set_surface_override_material(0, inside)
	fuselage.set_surface_override_material(1, glass)

	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var intake := _tool()
		_intake(intake, side)
		_add(self, "Intake" + named, intake, paint)
		var wing := _tool()
		_wing(wing, side)
		_add(self, "Wing" + named, wing, paint)
		var boom := _tool()
		_boom(boom, side)
		_add(self, "TailBoom" + named, boom, paint)
		_flaperon(side, named, paint)
		_tailplane(side, named, paint)
		_fin(side, named, paint)

	_build_nozzle(paint)
	_build_lift_fan(paint)
	var pod := _tool()
	_gun_pod(pod)
	_add(self, "GunPod", pod, paint)
	_build_bays(paint)
	_build_gear(paint)
	set_gear(1.0)
	set_nozzle(0.0)


# ---- the frame ---------------------------------------------------------------------------------------------------------

## A POINT: `out` metres to starboard, at `station` aft of the nose tip and `high` over the belly datum, in the craft's
## frame. The nose tip is at the box's front face and the ground at its bottom.
func point(out: float, high: float, station: float) -> Vector3:
	return Vector3(out, -_half.y + CLEARANCE + high, -_half.z + station)


## The ground, as a height over the datum: where every tyre stands.
static func ground() -> float:
	return -CLEARANCE


func wing_le(out: float) -> float:
	if out <= float(LEX[-1][0]):
		for i in range(LEX.size() - 1):
			var a: Array = LEX[i]
			var b: Array = LEX[i + 1]
			if out <= float(b[0]):
				return lerpf(float(a[1]), float(b[1]), (out - float(a[0])) / (float(b[0]) - float(a[0])))
		return float(LEX[0][1])
	return WING_LE.x + WING_LE.y * out


func wing_te(out: float) -> float:
	return WING_TE.x + WING_TE.y * out


func wing_h(out: float) -> float:
	return lerpf(WING_H.x, WING_H.y, clampf((out - WING_ROOT) / (WING_TIP - WING_ROOT), 0.0, 1.0))


## THE ROOM A CREW SITS IN, in the shape `VehicleView.cabin_room()` asks for.
func cabin_room() -> Dictionary:
	var low: Vector3 = point(ROOM.position.x, ROOM.position.y, ROOM.position.z)
	var high: Vector3 = point(ROOM.end.x, ROOM.end.y, ROOM.end.z)
	return {
		"drawn": true,
		"floor": point(0.0, seat_height() + 0.04, EYE.x).y,
		"room": AABB(low, high - low).abs(),
		"because": &"",
		"why_not": "",
		"source": "the eye off [JSF]'s side view, the seat EYE_HEIGHT under it; the room MEASURED against the drawn skin",
	}


## THE GUN'S MUZZLE, craft-local: the pod's nose.
func gun_port() -> Vector3:
	return point(0.0, MUZZLE_H, POD.x)


## THE PILOT'S EYE, craft-local.
func eye() -> Vector3:
	return point(0.0, EYE.y, EYE.x)


## The seat under that eye, as a height over the datum.
static func seat_height() -> float:
	return EYE.y - CockpitStation.EYE_HEIGHT


# ---- what moves ---------------------------------------------------------------------------------------------------------

## THE NOZZLE, 0 straight aft to 1 at 95 degrees down, AND THE DOORS THAT GO WITH IT. A PURE FUNCTION OF THE AMOUNT: the
## nozzle's angle is `amount x vector_travel`, linear, because the simulation's thrust vector is the same product of the
## same lever and a curve here would put the drawn nozzle somewhere the thrust is not. The lift fan's door, the auxiliary
## inlet doors, the louvre doors and the roll-post doors are open by `DOORS_BY` of the travel and stay open.
func set_nozzle(amount: float) -> void:
	_nozzle = clampf(amount, 0.0, 1.0)
	_turn("Nozzle", _nozzle * _travel)
	var doors: float = smoothstep(0.0, DOORS_BY, _nozzle)
	_turn("LiftFanDoor", doors * FAN_DOOR_OPEN)
	for named in ["Starboard", "Port"]:
		_turn("AuxInletDoor" + named, doors * AUX_DOOR_OPEN)
		_turn("LouvreDoor" + named, doors * LOUVRE_OPEN)
		_turn("RollPostDoor" + named, doors * LOUVRE_OPEN * 0.75)


func nozzle() -> float:
	return _nozzle


## THE ANGLE THE DRAWN NOZZLE POINTS, radians below straight aft: what `tests/lightning.gd` holds against the thrust.
func nozzle_angle() -> float:
	return _nozzle * _travel


## WHERE THIS AEROPLANE BLOWS, for `ExhaustYard` (lane/harrier, 2026-09-19). The F-35B is the first craft to wear the
## exhaust, and it was chosen for it rather than the Harrier the effect was asked for: proving the interface on an
## aeroplane that already hovers -- and whose suite already flies straight up, holds a hover and lands on a deck --
## answers "is this a feature or one aeroplane's effect" by construction rather than by promise.
##
## FOUR PORTS, and they are not all the same kind of thing, which is the interface earning its keep:
## - THE SWIVELLING NOZZLE is hot gas, and ITS AXIS IS READ OFF `nozzle_angle()` -- the same number the drawn nozzle
##   turns by and the same number the simulation's thrust vector swings by, so the plume cannot point anywhere the
##   thrust does not. `tests/lightning.gd:_the_nozzle_points_where_the_thrust_does` already holds that number to
##   `Sim.thrust_axis_of`, so the plume is anchored to the physics through a check that exists.
## - THE LIFT FAN blows cold air straight down through its louvres. No flame: a fan is not a burner.
## - THE TWO ROLL POSTS, cold, small, under each wing.
##
## THE THREE COLD ONES ARE DECLARED ONLY WHILE THEIR DOORS ARE OPEN, which is exactly while the nozzle is off zero.
## A lift fan behind a shut door is not blowing, and declaring it anyway would have drawn a column of dust under an
## F-35B in level cruise.
func exhaust_ports() -> Array:
	var angle: float = nozzle_angle()
	# THE GAS GOES THE OTHER WAY FROM THE THRUST. Forward is -Z, so a thrust of (forward cos + up sin) leaves the
	# nozzle along (+Z cos - Y sin): straight aft at zero, straight down at ninety.
	var gas := Vector3(0.0, -sin(angle), cos(angle))
	# THE EXIT MOVES WHEN THE NOZZLE SWINGS, so its place is worked out FROM THE SAME ANGLE as its direction rather
	# than typed as a station. The first version declared the port at a fixed `point(0, NOZZLE_AXIS, NOZZLE_EXIT)` and
	# `tests/exhaust.gd` caught it at once by holding the port to the DRAWN nozzle's own vertices: 0.45 m adrift with
	# the nozzle aft and 1.26 m with it down, which would have hung the plume in the air beside the aeroplane through
	# the whole of a vertical landing. One number, one place -- the angle.
	var ports: Array = [{
		"at": point(0.0, NOZZLE_AXIS, NOZZLE_ROOT) + gas * (NOZZLE_EXIT - NOZZLE_ROOT),
		"axis": gas,
		"radius": NOZZLE_R.y, "kind": ExhaustTuning.Kind.JET, "heat": 1.0,
	}]
	if _nozzle <= 0.0:
		return ports
	var fan_station: float = (LOUVRE_DOORS.x + LOUVRE_DOORS.y) * 0.5
	ports.append({
		"at": point(0.0, _door_at(fan_station), fan_station),
		"axis": Vector3.DOWN, "radius": FAN_RADIUS, "kind": ExhaustTuning.Kind.FAN, "heat": 0.0,
	})
	var post_station: float = (ROLL_POST.y + ROLL_POST.z) * 0.5
	for side in [1.0, -1.0]:
		ports.append({
			"at": point(side * ROLL_POST.x, _door_at(post_station), post_station),
			"axis": Vector3.DOWN, "radius": 0.12, "kind": ExhaustTuning.Kind.FAN, "heat": 0.0,
		})
	return ports


## THE LIFT FAN turning: `phase` 0 to 1 is one blade's pitch, which is the whole of a turn as far as eight identical blades
## can show, so a VAT bakes it in one blade's worth of rows and the view hands it the phase.
func set_fan(phase: float) -> void:
	_fan_phase = fposmod(phase, 1.0)
	var spin := _hinges.get("LiftFan") as Node3D
	if spin != null:
		spin.basis = Basis(Vector3.UP, _fan_phase * TAU / float(LIFT_FAN_SIDES))


func fan() -> float:
	return _fan_phase


## THE GEAR, 0 up and 1 down, IN THE F-35'S SEQUENCE: doors open, legs travel, doors shut. The well doors are open over the
## middle of the cycle and shut at both ends, so a leg never moves while its doors are shut and the gear down has them shut
## under it, as the photographs show; only the doors on the legs themselves stay open with the gear down.
func set_gear(amount: float) -> void:
	_gear = clampf(amount, 0.0, 1.0)
	var legs: float = legs_down(_gear)
	for index in range(_legs.size()):
		_legs[index].basis = Basis(Quaternion.IDENTITY.slerp(_stowed[index], 1.0 - legs))
	var doors: float = well_doors_open(_gear)
	_turn("NoseDoorStarboard", doors * WELL_OPEN)
	_turn("NoseDoorPort", doors * WELL_OPEN)
	_turn("MainDoorStarboard", doors * WELL_OPEN)
	_turn("MainDoorPort", doors * WELL_OPEN)


func gear() -> float:
	return _gear


## HOW FAR DOWN THE LEGS ARE at a gear amount: still over the doors' shares, eased over the middle.
static func legs_down(amount: float) -> float:
	return smoothstep(DOORS_OPEN_BY, DOORS_SHUT_FROM, amount)


## HOW OPEN THE WELL DOORS ARE at a gear amount: opening over the first share, open, shutting over the last.
static func well_doors_open(amount: float) -> float:
	if amount <= DOORS_OPEN_BY:
		return smoothstep(0.0, DOORS_OPEN_BY, amount)
	if amount >= DOORS_SHUT_FROM:
		return 1.0 - smoothstep(DOORS_SHUT_FROM, 1.0, amount)
	return 1.0


## A WEAPONS BAY's doors, 0 shut to 1 open: `side` +1 the starboard bay, -1 the port.
func set_bay(side: float, amount: float) -> void:
	var index: int = 0 if side > 0.0 else 1
	_bays[index] = clampf(amount, 0.0, 1.0)
	var named: String = "Starboard" if side > 0.0 else "Port"
	_turn("BayInnerDoor" + named, _bays[index] * BAY_OPEN)
	_turn("BayOuterDoor" + named, _bays[index] * BAY_OPEN)


func bay(side: float) -> float:
	return _bays[0 if side > 0.0 else 1]


## THE STICK'S SURFACES: `pitch` -1 nose down to +1 nose up, `roll` -1 left wing down to +1 right, `yaw` -1 nose left to +1
## nose right. The flaperons roll it, the tailplanes pitch it together and help roll it apart, and the rudders yaw it.
func set_flaperons(roll: float) -> void:
	_roll = clampf(roll, -1.0, 1.0)
	_turn("FlaperonStarboard", -_roll * FLAPERON_TRAVEL)
	_turn("FlaperonPort", _roll * FLAPERON_TRAVEL)
	_pose_tailplanes()


func set_tailplanes(pitch: float) -> void:
	_pitch = clampf(pitch, -1.0, 1.0)
	_pose_tailplanes()


func set_rudders(yaw: float) -> void:
	_yaw = clampf(yaw, -1.0, 1.0)
	_turn("RudderStarboard", _yaw * RUDDER_TRAVEL)
	_turn("RudderPort", _yaw * RUDDER_TRAVEL)


func stick_roll() -> float:
	return _roll


func stick_pitch() -> float:
	return _pitch


func stick_yaw() -> float:
	return _yaw


func _pose_tailplanes() -> void:
	var r: float = _roll * 0.4
	_turn("TailplaneStarboard", clampf(-_pitch - r, -1.0, 1.0) * TAIL_TRAVEL)
	_turn("TailplanePort", clampf(-_pitch + r, -1.0, 1.0) * TAIL_TRAVEL)


## THE FEATURES A VAT BAKES (`VatCasting`), each this airframe's own setter and getter. The nozzle carries its doors, the
## gear its doors, and the fan one blade's pitch.
func features() -> Array:
	return [
		{"name": "nozzle", "set": set_nozzle, "get": nozzle, "low": 0.0, "high": 1.0},
		{"name": "gear", "set": set_gear, "get": gear, "low": 0.0, "high": 1.0},
		{"name": "bay_starboard", "set": func(amount: float) -> void: set_bay(1.0, amount),
			"get": func() -> float: return bay(1.0), "low": 0.0, "high": 1.0, "samples": 33},
		{"name": "bay_port", "set": func(amount: float) -> void: set_bay(-1.0, amount),
			"get": func() -> float: return bay(-1.0), "low": 0.0, "high": 1.0, "samples": 33},
		{"name": "fan", "set": set_fan, "get": fan, "low": 0.0, "high": 1.0, "samples": 17},
		{"name": "pitch", "set": set_tailplanes, "get": stick_pitch, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "roll", "set": set_flaperons, "get": stick_roll, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "rudder", "set": set_rudders, "get": stick_yaw, "low": -1.0, "high": 1.0, "samples": 33},
	]


## A HINGE turned `angle` radians from where it was built, about the axis stored on it when it was built.
func _turn(named: String, angle: float) -> void:
	var hinge: Node3D = _hinges.get(named) as Node3D
	if hinge != null:
		hinge.basis = Basis(hinge.get_meta("axis") as Vector3, angle)


## A HINGE at `at`, turning about `along`, wound so a small positive turn carries `probe` towards `wanted` (a direction):
## the Tomcat's way, so the builder never reasons about which way a mirrored hinge turns.
func _hinge(named: String, parent: Node3D, at: Vector3, along: Vector3, probe: Vector3, wanted: Vector3) -> Node3D:
	var hinge := Node3D.new()
	# "HINGE" ON THE END, so a hinge is never found in place of the part it carries (lane/tomcat2).
	hinge.name = named + "Hinge"
	hinge.position = at
	var axis: Vector3 = along.normalized()
	if axis.cross(probe - at).dot(wanted) < 0.0:
		axis = -axis
	hinge.set_meta("axis", axis)
	parent.add_child(hinge)
	_hinges[named] = hinge
	return hinge


# ---- building ---------------------------------------------------------------------------------------------------------

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


## ONE TRIANGLE, wound so its face looks along `out`.
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
	for corner in [a, b, c]:
		tool.set_normal(normal.normalized())
		tool.add_vertex(corner)


## A LOFT through matching loops, each quad facing away from its own loops' middle, both ends closed by fans.
static func _loft(tool: SurfaceTool, loops: Array, tints: Array, close: bool = true) -> void:
	var n: int = (loops[0] as Array).size()
	var centres: Array = []
	for loop in loops:
		var c := Vector3.ZERO
		for p in loop:
			c += p
		centres.append(c / float(n))
	for i in range(loops.size() - 1):
		var a: Array = loops[i]
		var b: Array = loops[i + 1]
		var mid_centre: Vector3 = ((centres[i] as Vector3) + centres[i + 1]) * 0.5
		for k in range(n):
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			Plating.facing(tool, quad, mid - mid_centre, tints[k % tints.size()])
	if not close:
		return
	for end in [0, loops.size() - 1]:
		var along: Vector3 = (centres[end] as Vector3) - centres[1 if end == 0 else loops.size() - 2]
		var loop: Array = loops[end]
		for k in range(n):
			_fan(tool, centres[end], loop[k], loop[(k + 1) % n], along, tints[k % tints.size()])


## A FLAT SLAB from a 2D outline: `place` turns an outline point into its middle-surface position, `across` is the slab's
## normal and `half` its half-thickness. The engine's ear clipper triangulates both faces, so a concave outline is right.
static func _slab(tool: SurfaceTool, outline: PackedVector2Array, place: Callable, across: Vector3, half: float,
		tint: Color, under_tint: Color = Color(-1, 0, 0)) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var top: Array = []
	var under: Array = []
	for p in outline:
		top.append((place.call(p) as Vector3) + across * half)
		under.append((place.call(p) as Vector3) - across * half)
	var below: Color = tint if under_tint.r < 0.0 else under_tint
	for t in range(0, tris.size(), 3):
		_fan(tool, top[tris[t]], top[tris[t + 1]], top[tris[t + 2]], across, tint)
		_fan(tool, under[tris[t]], under[tris[t + 1]], under[tris[t + 2]], -across, below)
	var area: float = 0.0
	var n: int = outline.size()
	for i in range(n):
		area += outline[i].x * outline[(i + 1) % n].y - outline[(i + 1) % n].x * outline[i].y
	for i in range(n):
		var a2: Vector2 = outline[i]
		var b2: Vector2 = outline[(i + 1) % n]
		var edge: Vector2 = b2 - a2
		var out2: Vector2 = Vector2(edge.y, -edge.x) if area > 0.0 else Vector2(-edge.y, edge.x)
		var mid2: Vector2 = (a2 + b2) * 0.5
		var out3: Vector3 = (place.call(mid2 + out2.normalized() * 0.01) as Vector3) - (place.call(mid2) as Vector3)
		Plating.facing(tool, [top[i], top[(i + 1) % n], under[(i + 1) % n], under[i]], out3, tint)


static func _outline(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


## ONE RING's points round from the top centreline, starboard down to the keel and port back up: 12 points, 12 facets.
func _ring(row: Array) -> Array:
	var s: float = row[0]
	var half: Array = [Vector2(0.0, row[1]), Vector2(row[2], row[3]), Vector2(row[4], row[5]), Vector2(row[6], row[7]),
		Vector2(row[8], row[9]), Vector2(row[10], row[11]), Vector2(0.0, row[11])]
	var points: Array = []
	for i in range(half.size() - 1):
		points.append(point((half[i] as Vector2).x, (half[i] as Vector2).y, s))
	for i in range(half.size() - 1, 0, -1):
		points.append(point(-(half[i] as Vector2).x, (half[i] as Vector2).y, s))
	return points


## THE FUSELAGE: 12 flat facets a ring through the measured sections. Over the canopy the two upper facets each side are
## GLASS and go into `canopy`. Upward-facing panels take the darker top grey; the chine is the crease between them. The
## top facets over the lift fan and the auxiliary inlets are its dark cavities, and the belly's under the wells and bays
## is their white, each hidden by its door until the door opens.
func _fuselage(tool: SurfaceTool, canopy: SurfaceTool) -> void:
	# THE MEASURED RINGS, and one more at each end of the bays so the belly can be cut exactly there.
	var rows: Array = []
	for row in SECTIONS:
		for end in [BAY.x, BAY.y]:
			if (rows.is_empty() or float(rows[-1][0]) < end) and float(row[0]) > end:
				rows.append(_row_at(end))
		rows.append(row)
	var rings: Array = []
	for row in rows:
		rings.append(_ring(row))
	var n: int = FUSELAGE_SIDES
	for r in range(rings.size() - 1):
		var here: float = (float(rows[r][0]) + float(rows[r + 1][0])) * 0.5
		var glazed: bool = here > CANOPY.x and here < CANOPY.y
		var bay: bool = here > BAY.x and here < BAY.y
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var centre: Vector3 = point(0.0, (float(rows[r][1]) + float(rows[r][11])) * 0.5, here)
		for k in range(n):
			# THE BELLY OVER A BAY (facets 5 and 6, the flat bottom either side of the keel) is two strips, keel and outer,
			# with the bay's hole between them and its box behind.
			if bay and (k == 5 or k == 6):
				_belly_round_a_bay(tool, rows[r], rows[r + 1], 1.0 if k == 5 else -1.0)
				continue
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			var out: Vector3 = Vector3(mid.x - centre.x, mid.y - centre.y, 0.0)
			# Facets 0 and 1 are the starboard spine and crown, 10 and 11 the port ones.
			var upper: bool = k <= 1 or k >= n - 2
			if glazed and upper:
				Plating.facing(canopy, quad, out, GLASS)
				continue
			var normal: Vector3 = ((quad[2] as Vector3) - (quad[0] as Vector3)).cross(
				(quad[1] as Vector3) - (quad[0] as Vector3)).normalized()
			if normal.dot(out) < 0.0:
				normal = -normal
			Plating.facing(tool, quad, out, TOP if normal.y > 0.5 else LOWER)
	# THE NOSE: a fan from the first ring to the nose tip, on the chine. THE TAIL: closed inside the nozzle's root.
	var tip: Vector3 = point(0.0, NOSE_TIP_H, 0.0)
	var first: Array = rings[0]
	for k in range(n):
		_fan(tool, tip, first[k], first[(k + 1) % n], Vector3.FORWARD, TOP if k <= 2 or k >= n - 3 else LOWER)
	var last: Array = rings[rings.size() - 1]
	var back: Vector3 = point(0.0, NOZZLE_AXIS, float(SECTIONS[-1][0]))
	for k in range(n):
		_fan(tool, back, last[k], last[(k + 1) % n], Vector3.BACK, METAL)
	# THE EOTS WINDOW under the chin: the faceted sapphire of the targeting system, a low pyramid bedded in the belly.
	var eots: Array = [point(0.0, 0.26, 1.35), point(0.16, 0.28, 1.70), point(0.0, 0.28, 2.00), point(-0.16, 0.28, 1.70)]
	var apex: Vector3 = point(0.0, 0.17, 1.70)
	for k in range(4):
		_fan(tool, apex, eots[k], eots[(k + 1) % 4], Vector3.DOWN, Color(0.30, 0.26, 0.14))



## THE CAVITIES AND WELLS, as flat patches just inside the skin: the lift fan's dark hole and the auxiliary inlets' under
## their doors on top, and underneath the white nose and main wells, the bays, and the dark louvre box. A PART OF THEIR
## OWN, not the fuselage's: the skin is one closed solid and a point is inside it by ray parity, and a patch in the same
## mesh is one more crossing -- the first build called the pilot's eye and every stowed wheel "outside the aeroplane".
func _wells(tool: SurfaceTool) -> void:
	_patch(tool, 0.0, FAN_DOOR.z * 0.96, FAN_DOOR.x + 0.03, FAN_DOOR.y - 0.03, true, BLACK)
	_patch(tool, 0.0, AUX_DOORS.z * 0.96, AUX_DOORS.x + 0.03, AUX_DOORS.y - 0.03, true, BLACK)
	_patch(tool, -NOSE_WELL.z, NOSE_WELL.z, NOSE_WELL.x, NOSE_WELL.y, false, WELL)
	_patch(tool, -LOUVRE_DOORS.z, LOUVRE_DOORS.z, LOUVRE_DOORS.x, LOUVRE_DOORS.y, false, BLACK)
	for side in [1.0, -1.0]:
		_patch(tool, side * float(MAIN_WELL[0]), side * float(MAIN_WELL[1]), float(MAIN_WELL[2]), float(MAIN_WELL[3]),
			false, WELL)


## THE GUN POD: a six-sided prism under the belly, its top bedded 2 cm into the skin along the belly's own line, its nose
## drawn in to the muzzle, and a dark muzzle ring at the tip.
func _gun_pod(tool: SurfaceTool) -> void:
	var w: float = POD.z
	var loops: Array = []
	for s in [POD.x + 0.02, POD.x + 0.45, POD.y - 0.25, POD.y]:
		var top: float = _bottom_at(s) + 0.02
		var low: float = POD.w if s > POD.x + 0.1 else MUZZLE_H - 0.07
		var half: float = w if s > POD.x + 0.1 else w * 0.6
		if s >= POD.y - 0.01:
			low = lerpf(top, POD.w, 0.4)
		loops.append([point(half * 0.6, top, s), point(half, lerpf(top, low, 0.4), s), point(half * 0.7, low, s),
			point(-half * 0.7, low, s), point(-half, lerpf(top, low, 0.4), s), point(-half * 0.6, top, s)])
	_loft(tool, loops, [LOWER, LOWER, LOWER, LOWER, LOWER, LOWER])
	# The muzzle: a dark ring on the nose, facing forward.
	var at: Vector3 = gun_port()
	for k in range(6):
		var t0: float = TAU * float(k) / 6.0
		var t1: float = TAU * float(k + 1) / 6.0
		_fan(tool, at + Vector3(0.0, 0.0, -0.005), at + Vector3(0.03 * cos(t0), 0.03 * sin(t0), -0.005),
			at + Vector3(0.03 * cos(t1), 0.03 * sin(t1), -0.005), Vector3.FORWARD, BLACK)


## A SECTION ROW at any station, interpolated along the table column by column.
func _row_at(s: float) -> Array:
	var row: Array = [s]
	for index in range(1, 12):
		row.append(_column(s, index))
	return row


## THE BELLY BETWEEN TWO RINGS OVER A BAY, one side: the keel strip from the centreline to the bay's inner edge, the outer
## strip from its outer edge to the belly's, and the bay's box -- walls up to BAY_ROOF and the roof -- in white, every face
## looking into the bay, so the skin is still one closed solid round a hole.
func _belly_round_a_bay(tool: SurfaceTool, fore: Array, aft: Array, side: float) -> void:
	var s0: float = float(fore[0])
	var s1: float = float(aft[0])
	var b0: float = float(fore[11])
	var b1: float = float(aft[11])
	var inner: float = side * BAY_EDGES.x
	var outer: float = side * BAY_EDGES.z
	Plating.facing(tool, [point(0.0, b0, s0), point(inner, b0, s0), point(inner, b1, s1), point(0.0, b1, s1)],
		Vector3.DOWN, LOWER)
	Plating.facing(tool, [point(outer, b0, s0), point(side * float(fore[10]), b0, s0),
		point(side * float(aft[10]), b1, s1), point(outer, b1, s1)], Vector3.DOWN, LOWER)
	# The walls, looking in; the roof, looking down.
	Plating.facing(tool, [point(inner, b0, s0), point(inner, BAY_ROOF, s0), point(inner, BAY_ROOF, s1), point(inner, b1, s1)],
		Vector3(side, 0.0, 0.0), WELL)
	Plating.facing(tool, [point(outer, b0, s0), point(outer, BAY_ROOF, s0), point(outer, BAY_ROOF, s1), point(outer, b1, s1)],
		Vector3(-side, 0.0, 0.0), WELL)
	Plating.facing(tool, [point(inner, BAY_ROOF, s0), point(outer, BAY_ROOF, s0), point(outer, BAY_ROOF, s1),
		point(inner, BAY_ROOF, s1)], Vector3.DOWN, WELL)
	# The bay's ends, where this span is the first or the last.
	for end in [[s0, b0, BAY.x, Vector3.BACK], [s1, b1, BAY.y, Vector3.FORWARD]]:
		if absf(float(end[0]) - float(end[2])) < 0.001:
			Plating.facing(tool, [point(inner, float(end[1]), float(end[0])), point(outer, float(end[1]), float(end[0])),
				point(outer, BAY_ROOF, float(end[0])), point(inner, BAY_ROOF, float(end[0]))], end[3], WELL)


## A FLAT PATCH on the skin, `from` to `to` across and `fore` to `aft` along, 1 cm inside the top (`upper`) or the
## belly, facing out. A door drawn over it hides it until the door opens.
func _patch(tool: SurfaceTool, from: float, to: float, fore: float, aft: float, upper: bool, tint: Color) -> void:
	var at_top := func(s: float) -> float: return _top_at(s) - 0.01
	var corners: Array = []
	for c in [[from, fore], [to, fore], [to, aft], [from, aft]]:
		var s: float = float(c[1])
		var h: float = float(at_top.call(s)) if upper else _bottom_at(s) - 0.01
		corners.append(point(float(c[0]), h, s))
	Plating.facing(tool, corners, Vector3.UP if upper else Vector3.DOWN, tint)


## THE SPINE'S HEIGHT at a station, from the section table.
func _top_at(s: float) -> float:
	return _column(s, 1)


## THE KEEL'S HEIGHT at a station: the belly is flat from the keel to `belly_w` at this height.
func _bottom_at(s: float) -> float:
	return _column(s, 11)


## A shut door's height under the belly at a station.
func _door_at(s: float) -> float:
	return _bottom_at(s) - DOOR_DROP


## THE SKIN'S TOP at a station and a half-width, along the spine-to-crown-to-shoulder facets: where a door on top lies.
func _skin_top(s: float, w: float) -> float:
	var top: float = _column(s, 1)
	var cw: float = _column(s, 2)
	var ch: float = _column(s, 3)
	var sw: float = _column(s, 4)
	var sh: float = _column(s, 5)
	if w <= cw:
		return lerpf(top, ch, w / cw)
	return lerpf(ch, sh, clampf((w - cw) / (sw - cw), 0.0, 1.0))


## ONE COLUMN of the section table, interpolated along the fuselage.
func _column(s: float, index: int) -> float:
	for i in range(SECTIONS.size() - 1):
		var a: Array = SECTIONS[i]
		var b: Array = SECTIONS[i + 1]
		if s <= float(b[0]):
			return lerpf(float(a[index]), float(b[index]),
				clampf((s - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))
	return float(SECTIONS[-1][index])


## ONE INTAKE: the cowl's raked lip round the mouth, a dark throat set back inside it, the nacelle's outer walls running aft
## into the full-width fuselage, and the DSI bump on the body side ahead of the mouth that makes it a diverterless intake.
func _intake(tool: SurfaceTool, side: float) -> void:
	var corner := func(i: int, grow: float, back: float) -> Vector3:
		# The mouth's corner `i`, pushed out from the mouth's middle by `grow` and moved aft by `back`.
		var c: Array = MOUTH[i]
		var mid := Vector2(0.0, 0.0)
		for m in MOUTH:
			mid += Vector2(float(m[0]), float(m[1]))
		mid /= 4.0
		var p := Vector2(float(c[0]), float(c[1]))
		var d: Vector2 = (p - mid).normalized()
		p += d * grow
		return point(side * p.x, p.y, float(c[2]) + back)
	var lip: Array = []
	var outer: Array = []
	var throat: Array = []
	var aft: Array = []
	for i in range(4):
		lip.append(corner.call(i, 0.0, 0.0))
		outer.append(corner.call(i, LIP, 0.06))
		throat.append(corner.call(i, -0.05, THROAT_DEPTH))
	# The nacelle's aft end, inside the fuselage's first full-width ring: the mouth's outline grown and moved aft.
	for i in range(4):
		var c: Array = MOUTH[i]
		var out: float = float(c[0])
		var high: float = float(c[1])
		aft.append(point(side * (out + (0.10 if out > 1.0 else -0.05)), high + (0.05 if high > 1.0 else -0.12),
			NACELLE_END))
	var mid_axis: Vector3 = point(side * 1.1, 0.8, 4.6)
	for k in range(4):
		var k2: int = (k + 1) % 4
		# The lip's face, looking forward and out of the mouth.
		Plating.facing(tool, [lip[k], lip[k2], outer[k2], outer[k]], Vector3.FORWARD, LOWER)
		# The nacelle's outer skin, lip to the fuselage.
		var skin: Array = [outer[k], outer[k2], aft[k2], aft[k]]
		var smid: Vector3 = ((skin[0] as Vector3) + skin[1] + skin[2] + skin[3]) * 0.25
		Plating.facing(tool, skin, Vector3(smid.x - mid_axis.x, smid.y - mid_axis.y, 0.0), TOP if k == 2 else LOWER)
		# The duct wall, looking IN: the inside of the mouth.
		var wall: Array = [lip[k], lip[k2], throat[k2], throat[k]]
		var wmid: Vector3 = ((wall[0] as Vector3) + wall[1] + wall[2] + wall[3]) * 0.25
		Plating.facing(tool, wall, Vector3(mid_axis.x - wmid.x, mid_axis.y - wmid.y, 0.0), BLACK)
	var tmid := Vector3.ZERO
	var amid := Vector3.ZERO
	for k in range(4):
		tmid += throat[k]
		amid += aft[k]
	tmid /= 4.0
	amid /= 4.0
	for k in range(4):
		_fan(tool, tmid, throat[k], throat[(k + 1) % 4], Vector3.FORWARD, BLACK)
		_fan(tool, amid, aft[k], aft[(k + 1) % 4], Vector3.BACK, LOWER)
	# THE DSI BUMP: a low four-sided pyramid on the body side, bedded in it, its apex just inside the mouth's inner edge.
	var base: Array = [point(side * 0.80, 1.00, 3.95), point(side * 0.86, 1.02, 4.85), point(side * 0.72, 0.50, 4.95),
		point(side * 0.66, 0.50, 3.95)]
	var apex: Vector3 = point(side * 0.98, 0.78, 4.55)
	for k in range(4):
		_fan(tool, apex, base[k], base[(k + 1) % 4], Vector3(side, 0.0, 0.0), LOWER)


## A SIX-POINT SECTION of a flat lifting surface at `out`, chord `le` to `te` at height `high`: leading edge, two on top at
## 15 and 50 per cent, trailing edge, two below.
func _section(out: float, le: float, te: float, high: float, thick: float) -> Array:
	var c: float = te - le
	var t: float = c * thick * 0.5
	return [point(out, high, le), point(out, high + t * 0.8, le + 0.15 * c), point(out, high + t, le + 0.5 * c),
		point(out, high, te), point(out, high - t, le + 0.5 * c), point(out, high - t * 0.8, le + 0.15 * c)]


const _SURFACE_TINTS: Array = [TOP, TOP, TOP, LOWER, LOWER, LOWER]


## THE WING, one side: the LEX-to-root panel buried in the body, the panel to the flaperon's hinge across the flaperon,
## and full chord outboard of it to the tip.
func _wing(tool: SurfaceTool, side: float) -> void:
	var thick := func(out: float) -> float:
		return lerpf(WING_THICK.x, WING_THICK.y, clampf((out - WING_ROOT) / (WING_TIP - WING_ROOT), 0.0, 1.0))
	var section := func(out: float, te: float) -> Array:
		return _section(side * out, wing_le(out), te, wing_h(out), float(thick.call(out)))
	var stations: Array = [WING_ROOT]
	for row in LEX.slice(1):
		stations.append(float(row[0]))
	# Inboard of the flaperon, full chord, through the LEX's curve.
	var inner: Array = []
	for out in stations:
		if float(out) < FLAPERON.x:
			inner.append(section.call(float(out), wing_te(float(out))))
	inner.append(section.call(FLAPERON.x, wing_te(FLAPERON.x)))
	_loft(tool, inner, _SURFACE_TINTS)
	# Across the flaperon, to its hinge, through the LEX's outer points.
	var across: Array = [section.call(FLAPERON.x, wing_te(FLAPERON.x) - FLAPERON.z)]
	for out in stations:
		if float(out) > FLAPERON.x:
			across.append(section.call(float(out), wing_te(float(out)) - FLAPERON.z))
	across.append(section.call(FLAPERON.y, wing_te(FLAPERON.y) - FLAPERON.z))
	_loft(tool, across, _SURFACE_TINTS)
	# Outboard of it, full chord, to the tip.
	_loft(tool, [section.call(FLAPERON.y, wing_te(FLAPERON.y)), section.call(WING_TIP, wing_te(WING_TIP))], _SURFACE_TINTS)


## THE FLAPERON, one side, on its hinge along the swept-forward hinge line.
func _flaperon(side: float, named: String, paint: Material) -> void:
	var inner: Vector3 = point(side * FLAPERON.x, wing_h(FLAPERON.x), wing_te(FLAPERON.x) - FLAPERON.z)
	var outer: Vector3 = point(side * FLAPERON.y, wing_h(FLAPERON.y), wing_te(FLAPERON.y) - FLAPERON.z)
	var mid: Vector3 = (inner + outer) * 0.5
	# A positive turn is trailing edge DOWN.
	var hinge := _hinge("Flaperon" + named, self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	var loops: Array = []
	for out in [FLAPERON.x + 0.02, FLAPERON.y - 0.02]:
		var le: float = wing_te(out) - FLAPERON.z + 0.01
		var section: Array = _section(side * out, le, wing_te(out), wing_h(out), WING_THICK.y * 2.2)
		var local: Array = []
		for p in section:
			local.append((p as Vector3) - hinge.position)
		loops.append(local)
	_loft(tool, loops, _SURFACE_TINTS)
	_add(hinge, "Flaperon" + named, tool, paint)


## THE TAIL BOOM, one side: the strake beside the nozzle the fin stands on and the tailplane turns beside.
func _boom(tool: SurfaceTool, side: float) -> void:
	var loops: Array = []
	for row in BOOM:
		var s: float = float(row[0])
		var inner: float = float(row[1])
		var outer: float = float(row[2])
		var low: float = float(row[3])
		var top: float = float(row[4])
		loops.append([point(side * inner, top, s), point(side * outer, top - 0.05, s), point(side * outer, low + 0.05, s),
			point(side * inner, low, s)])
	_loft(tool, loops, [TOP, LOWER, LOWER, LOWER])


## THE TAILPLANE, one side, on its pivot: a flat slab of the measured planform turning about a spanwise axis at 14.0.
func _tailplane(side: float, named: String, paint: Material) -> void:
	var at: Vector3 = point(side * 1.03, TAIL_H, TAIL_PIVOT)
	# A positive turn is trailing edge DOWN, as the flaperons.
	var hinge := _hinge("Tailplane" + named, self, at, Vector3.RIGHT, at + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	var place := func(p: Vector2) -> Vector3: return point(side * p.x, TAIL_H, p.y) - at
	_slab(tool, _outline(TAIL), place, Vector3.UP, 0.035, TOP, LOWER)
	_add(hinge, "Tailplane" + named, tool, paint)


## THE FIN, one side: a slab in the fin's canted plane, from the side view's outline (whose heights are as projected), with
## its rudder on the raked hinge line. The root is bedded 4 cm into the boom's top.
func _fin(side: float, named: String, paint: Material) -> void:
	var place := func(p: Vector2) -> Vector3:
		var up: float = p.y - FIN_ROOT.y
		return point(side * (FIN_ROOT.x + up * tan(FIN_CANT)), p.y, p.x)
	var across: Vector3 = Vector3(side * cos(FIN_CANT), -sin(FIN_CANT), 0.0)
	var outline: Array = FIN.duplicate(true)
	outline[0] = [float(FIN[0][0]), FIN_ROOT.y - 0.04]
	outline[3] = [float(FIN[3][0]), FIN_ROOT.y - 0.04]
	var tool := _tool()
	_slab(tool, _outline(outline), place, across, 0.05, TOP)
	_add(self, "Fin" + named, tool, paint)
	var foot: Vector3 = place.call(Vector2(float(RUDDER[0][0]), float(RUDDER[0][1])))
	var head: Vector3 = place.call(Vector2(float(RUDDER[1][0]), float(RUDDER[1][1])))
	# A positive turn swings the trailing edge to STARBOARD, for right rudder.
	var hinge := _hinge("Rudder" + named, self, foot, head - foot, foot + Vector3.BACK, Vector3.RIGHT)
	var rudder := _tool()
	var local := func(p: Vector2) -> Vector3: return (place.call(p) as Vector3) - foot
	var r_outline: Array = RUDDER.duplicate(true)
	r_outline[0] = [float(RUDDER[0][0]) + 0.02, FIN_ROOT.y + 0.03]
	r_outline[1] = [float(RUDDER[1][0]) + 0.02, float(RUDDER[1][1])]
	r_outline[3] = [float(RUDDER[3][0]), FIN_ROOT.y + 0.03]
	_slab(rudder, _outline(r_outline), local, across, 0.035, TOP)
	_add(hinge, "Rudder" + named, rudder, paint)


## THE NOZZLE on its one hinge at 13.0: twelve flat petals from its root to the sawtooth exit, and a dark inside set back.
func _build_nozzle(paint: Material) -> void:
	var at: Vector3 = point(0.0, NOZZLE_AXIS, NOZZLE_ROOT)
	# A positive turn swings the exit DOWN.
	var hinge := _hinge("Nozzle", self, at, Vector3.RIGHT, at + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	var ring := func(s: float, r: float, teeth: bool) -> Array:
		var loop: Array = []
		for k in range(NOZZLE_SIDES):
			var t: float = TAU * (float(k) + 0.5) / NOZZLE_SIDES
			var back: float = s - (0.10 if teeth and k % 2 == 1 else 0.0)
			loop.append(point(r * cos(t), NOZZLE_AXIS + r * sin(t), back) - at)
		return loop
	var root: Array = ring.call(NOZZLE_ROOT - 0.15, NOZZLE_R.x, false)
	var mid: Array = ring.call(NOZZLE_ROOT + 0.45, (NOZZLE_R.x + NOZZLE_R.y) * 0.5, false)
	var exit: Array = ring.call(NOZZLE_EXIT, NOZZLE_R.y, true)
	_loft(tool, [root, mid, exit], [METAL], false)
	var deep: Array = ring.call(NOZZLE_EXIT - 0.35, NOZZLE_R.y * 0.85, false)
	var axis_exit: Vector3 = point(0.0, NOZZLE_AXIS, NOZZLE_EXIT) - at
	for k in range(NOZZLE_SIDES):
		var k2: int = (k + 1) % NOZZLE_SIDES
		var wall: Array = [exit[k], exit[k2], deep[k2], deep[k]]
		var wmid: Vector3 = ((wall[0] as Vector3) + wall[1] + wall[2] + wall[3]) * 0.25
		Plating.facing(tool, wall, Vector3(axis_exit.x - wmid.x, axis_exit.y - wmid.y, 0.0), BLACK)
		_fan(tool, point(0.0, NOZZLE_AXIS, NOZZLE_EXIT - 0.35) - at, deep[k], deep[k2], Vector3.BACK, BLACK)
		_fan(tool, point(0.0, NOZZLE_AXIS, NOZZLE_ROOT - 0.15) - at, root[k], root[k2], Vector3.FORWARD, METAL)
	_add(hinge, "Nozzle", tool, paint)


## A DOOR: a flat plate on its own hinge, painted `outside` on the face that faces `out` when shut and white inside.
func _door(named: String, corners: Array, hinge_a: Vector3, hinge_b: Vector3, opens_towards: Vector3, out: Vector3,
		paint: Material, parent: Node3D = null) -> Node3D:
	var mid: Vector3 = Vector3.ZERO
	for c in corners:
		mid += c
	mid /= float(corners.size())
	var at: Vector3 = (hinge_a + hinge_b) * 0.5
	var hinge := _hinge(named, self if parent == null else parent, at, hinge_b - hinge_a, mid, opens_towards)
	var tool := _tool()
	var thick: Vector3 = out.normalized() * 0.012
	var face: Array = []
	var back: Array = []
	for c in corners:
		face.append((c as Vector3) - at + thick)
		back.append((c as Vector3) - at - thick)
	Plating.facing(tool, face, out, LOWER if out.y < 0.5 else TOP)
	Plating.facing(tool, back, -out, WELL)
	for k in range(corners.size()):
		var k2: int = (k + 1) % corners.size()
		var edge_mid: Vector3 = ((face[k] as Vector3) + face[k2]) * 0.5
		var centre: Vector3 = mid - at
		Plating.facing(tool, [face[k], face[k2], back[k2], back[k]], edge_mid - centre, LOWER)
	_add(hinge, named, tool, paint)
	return hinge


## THE LIFT FAN AND ITS DOORS: the big door hinged at its aft edge, the auxiliary inlet doors hinged outboard, the fan
## itself under the door, the louvre doors underneath hinged outboard, and a roll-post door under each wing.
func _build_lift_fan(paint: Material) -> void:
	var fore: float = FAN_DOOR.x
	var aft: float = FAN_DOOR.y
	var w: float = FAN_DOOR.z
	var over := func(s: float, across: float) -> float: return _skin_top(s, absf(across)) + 0.02
	_door("LiftFanDoor", [point(-w * 0.8, float(over.call(fore, w * 0.8)), fore),
		point(w * 0.8, float(over.call(fore, w * 0.8)), fore), point(w, float(over.call(aft, w)), aft),
		point(-w, float(over.call(aft, w)), aft)],
		point(-w, float(over.call(aft, w)), aft), point(w, float(over.call(aft, w)), aft), Vector3.UP, Vector3.UP, paint)
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var a: float = AUX_DOORS.x
		var b: float = AUX_DOORS.y
		var o: float = side * AUX_DOORS.z
		var i: float = side * 0.02
		_door("AuxInletDoor" + named, [point(i, float(over.call(a, 0.0)), a), point(o, float(over.call(a, o)), a),
			point(o, float(over.call(b, o)), b), point(i, float(over.call(b, 0.0)), b)],
			point(o, float(over.call(a, o)), a), point(o, float(over.call(b, o)), b), Vector3.UP, Vector3.UP, paint)
		var lo: float = side * LOUVRE_DOORS.z
		var lf: float = _door_at(LOUVRE_DOORS.x)
		var la: float = _door_at(LOUVRE_DOORS.y)
		_door("LouvreDoor" + named, [point(side * 0.01, lf, LOUVRE_DOORS.x), point(lo, lf, LOUVRE_DOORS.x),
			point(lo, la, LOUVRE_DOORS.y), point(side * 0.01, la, LOUVRE_DOORS.y)],
			point(lo, lf, LOUVRE_DOORS.x), point(lo, la, LOUVRE_DOORS.y), Vector3.DOWN, Vector3.DOWN, paint)
		var rp: Vector3 = ROLL_POST
		var under: float = wing_h(rp.x) - 0.10
		_door("RollPostDoor" + named, [point(side * (rp.x - 0.14), under, rp.y), point(side * (rp.x + 0.14), under, rp.y),
			point(side * (rp.x + 0.14), under, rp.z), point(side * (rp.x - 0.14), under, rp.z)],
			point(side * (rp.x - 0.14), under, rp.y), point(side * (rp.x + 0.14), under, rp.y), Vector3.DOWN,
			Vector3.DOWN, paint)
	# THE FAN: eight blades round a hub, lying in the opening under the door, turned by `set_fan`.
	var centre: Vector3 = point(0.0, _top_at(FAN_CENTRE) - 0.005, FAN_CENTRE)
	var spin := Node3D.new()
	spin.name = "LiftFanSpin"
	spin.position = centre
	add_child(spin)
	_hinges["LiftFan"] = spin
	var tool := _tool()
	for k in range(LIFT_FAN_SIDES):
		var t0: float = TAU * float(k) / LIFT_FAN_SIDES
		var t1: float = t0 + TAU / LIFT_FAN_SIDES * 0.55
		var hub: float = 0.16
		_fan(tool, Vector3(hub * cos(t0), 0.0, hub * sin(t0)), Vector3(FAN_RADIUS * cos(t0), -0.01, FAN_RADIUS * sin(t0)),
			Vector3(FAN_RADIUS * cos(t1), 0.0, FAN_RADIUS * sin(t1)), Vector3.UP, FAN)
		_fan(tool, Vector3.ZERO, Vector3(hub * cos(t0), 0.0, hub * sin(t0)),
			Vector3(hub * cos(t0 + TAU / LIFT_FAN_SIDES), 0.0, hub * sin(t0 + TAU / LIFT_FAN_SIDES)), Vector3.UP, METAL)
	var disc := _add(spin, "LiftFan", tool, paint)
	disc.position = Vector3.ZERO


## THE WEAPONS BAYS' DOORS: in each bay an inner door hinged at the keel strip and an outer door hinged at the bay's outer
## edge, each opening down onto the white cavity `_belly_round_a_bay` cuts.
func _build_bays(paint: Material) -> void:
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var keel: float = side * BAY_EDGES.x
		var meet: float = side * BAY_EDGES.y
		var edge: float = side * BAY_EDGES.z
		var f: float = _door_at(BAY.x)
		var a: float = _door_at(BAY.y)
		_door("BayInnerDoor" + named, [point(keel, f, BAY.x), point(meet - side * 0.005, f, BAY.x),
			point(meet - side * 0.005, a, BAY.y), point(keel, a, BAY.y)],
			point(keel, f, BAY.x), point(keel, a, BAY.y), Vector3.DOWN, Vector3.DOWN, paint)
		_door("BayOuterDoor" + named, [point(meet + side * 0.005, f, BAY.x), point(edge, f, BAY.x),
			point(edge, a, BAY.y), point(meet + side * 0.005, a, BAY.y)],
			point(edge, f, BAY.x), point(edge, a, BAY.y), Vector3.DOWN, Vector3.DOWN, paint)


## THE GEAR: three legs on pivots, each built DOWN and turned up into its well by the shortest arc from its down direction
## to its stowed one, and the well doors. A leg's own door rides on the leg.
func _build_gear(paint: Material) -> void:
	_leg("NoseGear", NOSE_LEG, NOSE_TYRE, 0.16, 1.0, paint)
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var leg: Array = []
		for p in MAIN_LEG:
			leg.append(Vector3(side * (p as Vector3).x, (p as Vector3).y, (p as Vector3).z))
		_leg("MainGear" + named, leg, MAIN_TYRE, 0.22, side, paint)
		# The nose well's doors, hinged outboard; the main well's, hinged inboard.
		var nw: Vector3 = NOSE_WELL
		var nf: float = _door_at(nw.x)
		var na: float = _door_at(nw.y)
		_door("NoseDoor" + named, [point(side * 0.005, nf, nw.x), point(side * nw.z, nf, nw.x),
			point(side * nw.z, na, nw.y), point(side * 0.005, na, nw.y)],
			point(side * nw.z, nf, nw.x), point(side * nw.z, na, nw.y), Vector3.DOWN, Vector3.DOWN, paint)
		var a: float = side * float(MAIN_WELL[0])
		var b: float = side * float(MAIN_WELL[1])
		var fore: float = float(MAIN_WELL[2])
		var aft: float = float(MAIN_WELL[3])
		var mf: float = _door_at(fore)
		var ma: float = _door_at(aft)
		_door("MainDoor" + named, [point(a, mf, fore), point(b, mf, fore), point(b, ma, aft), point(a, ma, aft)],
			point(a, mf, fore), point(a, ma, aft), Vector3.DOWN, Vector3.DOWN, paint)


## ONE LEG: a pivot at `leg[0]`, built with the axle at `leg[1]` and stowed turning the axle to `leg[2]`. A strut, a
## tyre across the leg's side, and the leg's own door on its outboard face.
func _leg(named: String, leg: Array, tyre: float, wide: float, side: float, paint: Material) -> void:
	var pivot_at: Vector3 = point((leg[0] as Vector3).x, (leg[0] as Vector3).y, (leg[0] as Vector3).z)
	var axle: Vector3 = point((leg[1] as Vector3).x, (leg[1] as Vector3).y, (leg[1] as Vector3).z)
	var stowed: Vector3 = point((leg[2] as Vector3).x, (leg[2] as Vector3).y, (leg[2] as Vector3).z)
	var pivot := Node3D.new()
	pivot.name = named + "Pivot"
	pivot.position = pivot_at
	add_child(pivot)
	_legs.append(pivot)
	_stowed.append(Quaternion((axle - pivot_at).normalized(), (stowed - pivot_at).normalized()))
	var tool := _tool()
	# THE STRUT, a square bar from the pivot to the axle, and the axle across.
	var along: Vector3 = (axle - pivot_at).normalized()
	var across: Vector3 = along.cross(Vector3.FORWARD).normalized()
	var up: Vector3 = across.cross(along).normalized()
	var h: float = 0.06 if tyre < 0.5 else 0.08
	var loops: Array = []
	for p in [pivot_at, axle]:
		var q: Vector3 = (p as Vector3) - pivot_at
		loops.append([q + across * h + up * h, q - across * h + up * h, q - across * h - up * h, q + across * h - up * h])
	_loft(tool, loops, [GEAR_WHITE])
	# THE TYRE, an eight-sided prism whose bottom FLAT stands on the ground, turning across the aeroplane.
	var apothem: float = tyre * 0.5
	var corner: float = apothem / cos(PI / WHEEL_SIDES)
	var centre: Vector3 = axle - pivot_at
	var wheel: Array = []
	for w in [-wide * 0.5, wide * 0.5]:
		var loop: Array = []
		for k in range(WHEEL_SIDES):
			var t: float = TAU * (float(k) + 0.5) / WHEEL_SIDES
			loop.append(centre + Vector3(w, corner * cos(t), corner * sin(t)))
		wheel.append(loop)
	_loft(tool, wheel, [TYRE])
	# THE LEG'S OWN DOOR, a plate beside the strut on the outboard side (in front, on the nose leg): it stays with the leg.
	var door_off: Vector3 = Vector3(side * 0.13, 0.0, 0.0) if named != "NoseGear" else Vector3(0.0, 0.0, -0.12)
	var top: Vector3 = door_off + along * 0.10
	var bottom: Vector3 = door_off + along * ((axle - pivot_at).length() - apothem - 0.08)
	Plating.box(tool, (top + bottom) * 0.5, Vector3(0.02, (bottom - top).length(), 0.26) if named != "NoseGear"
		else Vector3(0.24, (bottom - top).length(), 0.02), LOWER, Basis(Quaternion(Vector3.DOWN, along)))
	var mesh := _add(pivot, named, tool, paint)
	mesh.visibility_range_end = DETAIL_RANGE
	mesh.visibility_range_end_margin = DETAIL_HYSTERESIS
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
