@tool
extends Node3D
class_name OspreyAirframe
## A BELL BOEING MV-22B OSPREY, DRAWN. What makes it a V-22 at a glance: the rounded nose with the refuelling probe on its
## starboard side and the flight deck's glazing wrapped round it, a boxy cabin on a flat belly with a SPONSON either side
## for the main gear, the high wing on its centre fairing -- swept 6.6 degrees FORWARD, with 4.5 degrees of dihedral --
## the aft fuselage sweeping up into the loading ramp, and the H-tail: a tailplane with a fin at each end that reaches
## down below it. And, on each wing tip, THE NACELLE AND ITS PROPROTOR, which is what moves:
## - THE NACELLES (`set_tilt`) swing together about one conversion axis through the wing tips, from straight ahead (0)
##   to the simulation's `vector_travel` (97.5 degrees, "past vertical ... for rearward flight" [WP]). The drawn angle IS
##   the simulation's: `travel()` reads the kind's handling, the one number both use;
## - THE PROPROTORS (`set_spin`, `set_rotors`) turn, three blades each, in opposite senses, and a faint disc shows the
##   swept circle while they run, as every rotor in the game does (`RotorcraftKit`).
##
## PRESENTATION ONLY. The native simulation owns the size (`dress` reads `extents`), the flight, the collision, the
## stations and the wire. The box's floor is the ground the gear stands on.
##
## ORIGINAL GEOMETRY, MEASURED. No mesh, texture, photograph or livery is incorporated. Every size names its source:
## - [JJ] "Bell Boeing MV-22 Osprey line drawing.svg", Jetijones 2011, Wikimedia Commons, CC BY 3.0: a side, a front and
##   a plan, each in aeroplane and in helicopter mode, rendered by Commons at 3840 px. The plans and fronts share ONE
##   camera (the proprotor disc is the same size in pixels in all four face-on views); the sides are drawn 0.8 per cent
##   shorter, so each is scaled by the published length on its own (77.63 px a metre for the sides, 78.26 for the rest).
##   The disc then reads 11.665 m against the published 11.61. `craft/osprey/measure_views.py` re-derives every MEASURED
##   figure here from the drawing alone, reading nothing out of this file or `sources.md`.
## - [NPS] the V-22 Program Office's side view with a GROUND LINE, page 97 of the Naval Postgraduate School thesis "The
##   V-22 tilt rotor, a comparison with existing Coast Guard aircraft" (Commons, public domain): the belly stands 0.45 m
##   over the ground. [JJ] has no ground line.
## - [WP] Wikipedia's V-22 specifications (Norton, Boeing): 17.48 m long, 13.97 m span, 25.77 m across the turning
##   proprotors, 11.61 m discs, 6.73 m high with the nacelles vertical, 5.38 m to the fins' tops; the nacelles to 97.5.
## - [NASA] C. W. Acree, "Effects of Blade Sweep on V-22 Whirl Flutter and Loads" (AHS 2004): the blade "36-in chord at
##   5% radius, linearly tapering to a 22-in chord at the tip. Total effective blade twist is 47.5 deg over a 228.5-in
##   radius."
## - ESTIMATE where nothing gives a figure, and it says what it was reasoned from.
##
## STATIONS ARE METRES AFT OF THE NOSE TIP, HEIGHTS METRES OVER THE BELLY DATUM (the side view's flat belly), and OUT
## metres from the centreline. The drawn length is centred on the box, and the ground is the box's floor, `CLEARANCE`
## under the datum.
##
## THE HEIGHT, AND WHERE [JJ] IS NOT FOLLOWED. With [NPS]'s 0.45 m of clearance, [JJ]'s blade plane stands 6.43 m over the
## ground in helicopter mode, which [NPS] puts at 6.32 (a scan read at its own printed height), and its outer blades'
## tops at 6.74, which is [WP]'s 6.73. [JJ]'s spinner is a tall cone standing 0.95 m proud of the blades, which would put
## the aircraft 7.38 m high; [NPS]'s is about 0.5 m, and the page prints 22 ft 7 in (6.88 m). The spinner is drawn to
## [WP]'s 6.73 instead, 0.30 m proud of the blade plane. And [JJ]'s side view has the fins' tops 0.17 m higher than its
## own front view: the front's 4.96 m is taken, 5.41 m over the ground against [WP]'s 5.38.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT. The user's direction of 2026-09-17: "a somewhat lower poly look", with the
## E-2D Hawkeye as the reference. The FUSELAGE is 12 facets a ring through the measured sections (the Hawkeye's is 20);
## a SPONSON 8; a NACELLE 12; a BLADE a six-point airfoil at six stations; the wing an eight-point section at seven
## stations; the fins and tailplane slabs; a TYRE 8 sides. Every face carries its own normal; nothing is smoothed.

## [WP] The published envelope, held by `tests/osprey.gd`.
const LENGTH: float = 17.48
const SPAN: float = 13.97
const WIDTH: float = 25.77
const ROTOR_RADIUS: float = 11.61 * 0.5
const HEIGHT: float = 6.73
const FIN_TOP_PUBLISHED: float = 5.38

## [NPS] The belly over the ground.
const CLEARANCE: float = 0.45

## THE PAINT. The MV-22B is two greys, darker above (FS 36118) than below (FS 36375) -- ESTIMATE, sRGB approximations.
const TOP := Color(0.33, 0.35, 0.36)
const LOWER := Color(0.45, 0.47, 0.48)
const GLASS := Color(0.16, 0.20, 0.22)
const BLACK := Color(0.05, 0.05, 0.055)
const METAL := Color(0.30, 0.30, 0.31)
const BLADE := Color(0.20, 0.21, 0.22)
const BLADE_TIP := Color(0.72, 0.66, 0.30)
const TYRE := Color(0.06, 0.06, 0.06)
const GEAR := Color(0.62, 0.63, 0.63)
const WELL := Color(0.58, 0.60, 0.60)
const FLOOR := Color(0.26, 0.27, 0.27)
const LINING := Color(0.13, 0.14, 0.14)

## THE FUSELAGE, RING BY RING: [station, top, bottom, half-width, roof]. `top` and `bottom` are [JJ]'s side silhouette
## column by column (measure_views.py prints them every 0.25 m); `half` is the plan's run through the centreline. The
## section between them is the front view's: a flat belly 0.72 of the half-width across, sides upright from 15 to 62 per
## cent of the way up to the ROOF, a shoulder at 84 per cent 0.89 of the half-width out -- the front view is 1.19 m out at
## 2.15 m up over the cabin, and this makes it 1.18 at 2.18 -- and a crown. `roof` is the cabin's roof line, 2.55 to 2.62
## m; over the wing the silhouette's top is the WING FAIRING, a narrow ridge standing up out of the roof, and the shoulder
## stays with the roof so the fairing does not widen the cabin into a box (the first build's front view did).
## - The nose's bottom at 0.50 is 0.28, between its neighbours: [JJ] draws the nose wheel there, 0.05 under the belly.
## - Aft of 11.0 the belly rises in a straight line to 2.07 m at 15.25 (26 degrees): the loading ramp.
## - Past 15.25 the fins and tailplane cover the tail; the cone closes inside the tailplane at 16.3 (ESTIMATE).
const SECTIONS: Array = [
	[0.25, 1.33, 0.41, 0.55, 1.33],
	[0.50, 1.34, 0.28, 0.67, 1.34],
	[0.75, 1.35, 0.19, 0.83, 1.35],
	[1.00, 1.49, 0.14, 0.95, 1.49],
	[1.25, 1.70, 0.08, 1.05, 1.70],
	[1.50, 1.98, 0.03, 1.11, 1.98],
	[1.75, 2.29, 0.00, 1.18, 2.29],
	[2.00, 2.46, 0.00, 1.23, 2.46],
	[2.25, 2.52, 0.00, 1.28, 2.52],
	[2.50, 2.55, 0.00, 1.33, 2.55],
	[2.80, 2.55, 0.00, 1.33, 2.55],
	[3.43, 2.586, 0.00, 1.33, 2.586],
	[3.50, 2.59, 0.00, 1.33, 2.59],
	[4.27, 2.659, 0.00, 1.33, 2.613],
	[4.50, 2.68, 0.00, 1.33, 2.62],
	[4.75, 2.81, 0.00, 1.33, 2.62],
	[5.00, 2.94, 0.00, 1.33, 2.62],
	[5.25, 3.25, 0.00, 1.33, 2.62],
	[5.60, 3.42, 0.00, 1.33, 2.62],
	[7.50, 3.50, 0.00, 1.33, 2.62],
	[7.75, 3.44, 0.00, 1.33, 2.62],
	[8.00, 3.35, 0.00, 1.33, 2.62],
	[8.50, 3.17, 0.00, 1.33, 2.62],
	[9.00, 3.01, 0.00, 1.33, 2.62],
	[9.50, 2.89, 0.00, 1.33, 2.62],
	[10.0, 2.77, 0.00, 1.33, 2.62],
	[10.5, 2.68, 0.00, 1.33, 2.62],
	[11.0, 2.59, 0.00, 1.32, 2.59],
	[11.5, 2.52, 0.17, 1.30, 2.52],
	[12.0, 2.47, 0.36, 1.28, 2.47],
	[12.5, 2.46, 0.57, 1.26, 2.46],
	[13.0, 2.46, 0.81, 1.25, 2.46],
	[13.5, 2.46, 1.07, 1.24, 2.46],
	[14.0, 2.49, 1.35, 1.21, 2.49],
	[14.5, 2.61, 1.65, 1.20, 2.61],
	[15.0, 2.76, 1.93, 1.19, 2.76],
	[15.25, 2.80, 2.07, 1.10, 2.80],
	[15.8, 2.80, 2.26, 0.80, 2.80],
	[16.3, 2.78, 2.40, 0.45, 2.78],
]
const FUSELAGE_SIDES: int = 12
## [JJ] The nose tip, 0.76 m over the datum.
const NOSE_TIP_H: float = 0.76
## THE FLIGHT DECK'S GLAZING, off [JJ]'s filled black panes in the side view: the windscreen from 1.26 to 1.71 and up to
## 2.16 m, the side windows 1.93 to 2.77 (1.70 to 2.47 m up) and the chin windows 0.94 to 1.65 (0.85 to 1.24 m up). The
## windscreen runs on to 2.00 over the roof, where [JJ]'s side windows begin: with the seats where the simulation has
## them the eye is 2.30 m up, and the roof at 1.75 to 2.00 is 2.29 to 2.46, so a windscreen stopping at 1.75 put the view
## ahead through an opaque panel (tests/osprey.gd, the see-out check).
const WINDSCREEN: Vector2 = Vector2(1.25, 2.00)
const SIDE_WINDOWS: Vector2 = Vector2(2.00, 2.80)
const CHIN_WINDOWS: Vector2 = Vector2(1.00, 1.50)

## [JJ] THE REFUELLING PROBE: its tip 0.12 m ahead of the nose, 1.15 m up, 0.485 m out to starboard (the plan's probe
## is at 0.36 to 0.61 m out). ESTIMATE of the side: the photographs' MV-22s carry it on the right.
const PROBE: Vector3 = Vector3(0.485, 1.15, -0.12)
const PROBE_ROOT: float = 1.30

## THE SPONSONS: [station, out]. The plan's outline beyond the cabin's 1.33 m: from 4.75 to 12.5 m, 2.35 m out at most
## at 8.5 to 9.0. Under the wing (5.75 to 8.0) the plan cannot see it and it is carried smoothly between. The front view
## gives its section, as (out, height) with the outermost at 2.19 m: the front view is 7 per cent narrower there than the
## plan, and the plan is taken, since [JJ]'s front and plan disagree about nothing else by more than 2 per cent.
const SPONSON: Array = [[4.75, 1.38], [5.00, 1.55], [5.25, 1.74], [5.50, 1.89], [6.00, 2.08], [6.50, 2.20],
	[7.00, 2.27], [7.50, 2.31], [8.00, 2.33], [8.50, 2.35], [9.00, 2.35], [9.50, 2.28], [10.0, 2.17], [10.5, 2.04],
	[11.0, 1.88], [11.5, 1.70], [12.0, 1.49], [12.5, 1.27]]
const SPONSON_SECTION: Array = [[1.25, 1.62], [1.60, 1.45], [1.88, 1.25], [2.12, 1.02], [2.19, 0.65], [2.10, 0.25],
	[1.85, 0.03], [1.25, 0.00]]
const SPONSON_ROOT: float = 1.25

## [JJ] THE WING: its leading edge at station 5.943 - 0.1157 x out (146 rows, 28 mm rms: 6.6 degrees FORWARD), its trailing
## edge at 8.507 - 0.1111 x out; the front view's top at 3.289 + 0.078 x out and bottom at 2.569 + 0.081 x out (4.5
## degrees of dihedral, 0.72 m deep). It runs to the nacelles' inner faces.
const WING_LE: Vector2 = Vector2(5.943, -0.1157)
const WING_TE: Vector2 = Vector2(8.507, -0.1111)
const WING_TOP: Vector2 = Vector2(3.289, 0.078)
const WING_BOTTOM: Vector2 = Vector2(2.569, 0.081)
const WING_TIP: float = 6.40
## An eight-point airfoil: (fraction of the chord aft of the leading edge, height over the section's middle in half
## depths).
const AIRFOIL: Array = [[0.0, 0.0], [0.08, 0.72], [0.30, 1.0], [0.70, 0.62], [1.0, 0.05], [0.70, -0.45], [0.30, -1.0],
	[0.08, -0.72]]

## THE NACELLES' CONVERSION AXIS [JJ]: the point a quarter turn nose-up carries the aeroplane-mode hub onto the
## helicopter-mode one, station 6.615, 3.48 m over the belly -- inside the wing tip, 55 per cent of its chord aft. And
## the axis's OUT is [WP]'s: (25.77 - 11.61) / 2 = 7.08 m, the discs' centres. [JJ] reads 6.90 in the front and 7.18 in
## the plan, 7.05 on average.
const PIVOT: Vector2 = Vector2(6.615, 3.48)
const PIVOT_OUT: float = (WIDTH - 2.0 * ROTOR_RADIUS) * 0.5
## THE NACELLE in its own frame, aeroplane mode: [a, low, high, half-width, inboard] -- `a` metres FORWARD of the axis
## along the nacelle, `low` and `high` metres over the axis, `half` its half-width and `inboard` how far its middle sits
## inboard of the disc's. From [JJ]'s helicopter-mode side (which sees the nacelle standing up, so its depth by height) and
## front (its width), and the aeroplane-mode side's top line aft of the wing. Its underside aft of the wing is hidden in
## every view and is an ESTIMATE, tapering to the exhaust.
const NACELLE: Array = [
	[-2.48, -0.50, 0.10, 0.25, 0.19],
	[-2.10, -0.75, 0.17, 0.39, 0.20],
	[-1.50, -0.95, 0.28, 0.46, 0.20],
	[-0.90, -1.10, 0.45, 0.62, 0.10],
	[-0.40, -1.19, 0.58, 0.72, 0.0],
	[0.30, -1.19, 0.70, 0.74, 0.0],
	[1.10, -1.19, 0.76, 0.72, 0.0],
	[1.55, -1.10, 0.79, 0.70, 0.0],
	[1.72, -0.45, 0.79, 0.65, 0.0],
	[1.95, -0.40, 0.70, 0.58, 0.0],
	[2.20, -0.28, 0.56, 0.40, 0.0],
]
const NACELLE_SIDES: int = 12
## THE ROTOR'S AXIS, 0.16 m over the conversion axis [JJ: the front view's disc centres, 3.64 m up, against 3.48]; its
## blades 2.50 m forward of the conversion axis, in both modes. The SPINNER from 2.30 to 2.80 (see the height, above).
const HUB_UP: float = 0.16
const BLADE_PLANE: float = 2.50
const SPINNER: Vector3 = Vector3(2.30, 2.80, 0.50)  # from, tip, radius at its foot
const BLADE_ROOT: float = 0.45
## [NASA] The chord at 5 per cent of the radius and at the tip, and the twist over the whole radius.
const CHORD_ROOT: float = 36.0 * 0.0254
const CHORD_TIP: float = 22.0 * 0.0254
const TWIST: float = deg_to_rad(47.5)
## THE PITCH AT THREE QUARTERS OF THE RADIUS, as drawn: 14 degrees, a hovering collective (ESTIMATE).
const PITCH_75: float = deg_to_rad(14.0)
const BLADE_STATIONS: Array = [0.45, 1.20, 2.50, 4.00, 5.30, 5.805]
## Each rotor's sense: the starboard turns one way and the port the other. Which way is an ESTIMATE.
const SPIN_SENSE: Dictionary = {1.0: 1.0, -1.0: -1.0}

## [JJ] THE TAIL. The tailplane runs between the fins, 15.15 to 17.45 aft, 2.5 m up and 0.34 deep (the front view's band
## is 2.25 to 2.75 across the fins). The fins stand 2.61 m out (the front's 2.67, the plan's 2.55), canted in 2.1 degrees
## at the top (the front view's middle moves 0.11 m inboard over 3.0 m), and reach from 1.49 m up, below the tailplane,
## to the front view's 4.96. The side outline, (station, height):
const TAILPLANE: Vector3 = Vector3(15.15, 17.45, 2.50)
const TAILPLANE_DEEP: float = 0.34
const FIN_OUT: float = 2.61
const FIN_CANT: float = deg_to_rad(2.1)
const FIN_TOP: float = 4.96
const FIN: Array = [[15.56, 1.49], [15.37, 2.00], [15.40, 2.60], [15.42, 3.00], [15.79, 4.00], [16.12, 4.85],
	[16.35, FIN_TOP], [17.30, FIN_TOP], [17.48, 4.80], [17.48, 1.62], [17.35, 1.49]]
const FIN_THICK: float = 0.20

## THE GEAR: twin nose wheels and, in each sponson, twin mains. WHERE: [NPS]'s side view puts the nose wheels under the
## chin at station 1.1 and the mains under the wing's trailing half at 7.5; the photographs (studied, not incorporated)
## put the nose leg just behind the chin turret and the mains half hidden in the sponsons, their tyres' tops inside the
## sponsons' bottoms with the gear down. HOW THEY RETRACT is an ESTIMATE: the nose leg aft into a well under the flight
## deck, the mains forward into the sponsons. Each leg is [pivot out, pivot height, pivot station, axle station]; the axle
## stands a tyre's inscribed radius over the ground, so an eight-sided tyre stands on a flat. The tyres: 22 in (0.56 m)
## nose, 0.74 m mains (ESTIMATE).
const NOSE_LEG: Vector4 = Vector4(0.0, 0.45, 1.25, 1.10)
const MAIN_LEG: Vector4 = Vector4(1.66, 0.65, 7.90, 7.45)
const NOSE_TYRE: Vector3 = Vector3(0.28, 0.18, 0.20)  # radius, each wheel's offset out, width
const MAIN_TYRE: Vector3 = Vector3(0.37, 0.16, 0.20)
const TYRE_SIDES: int = 8
## THE WELL DOORS, 3 cm under the skin and swinging down about their OUTER edges: the nose well's pair from 1.42 to 2.25,
## each from a 0.12 m slot at the middle (the strut's) to 0.40 out; each main well's from 6.30 to 7.05, 1.42 to 1.95 out.
## Each door STOPS SHORT OF WHERE ITS LEG LEAVES THE SKIN (the nose strut at 1.10 to 1.25, a main tyre's top at 7.08 to
## 7.82), because a door that shuts with the gear down cannot shut across the leg (lane/lightning's first run). The nose
## doors began at 1.35 and shut 3 cm into the nose tyres, which reach 1.38 (tests/osprey.gd, no leg through a door).
const NOSE_DOORS: Vector4 = Vector4(1.42, 2.25, 0.12, 0.40)  # fore, aft, slot, outer
const MAIN_DOOR: Vector4 = Vector4(6.30, 7.05, 1.42, 1.95)
const DOOR_DROP: float = 0.03
const WELL_OPEN: float = deg_to_rad(85.0)
## THE CYCLE'S SHARES, the F-35B's: the doors open over the first fifth, the legs move over the middle three, the doors
## shut over the last; a whole cycle takes `GEAR_SECONDS` drawn (the user: "the amount of time isn't important right now,
## we just need to be able to adjust it", `actuators_research.md` 3.10).
const DOORS_OPEN_BY: float = 0.2
const DOORS_SHUT_FROM: float = 0.8
const GEAR_SECONDS: float = 8.0

## THE RAMP AND ITS UPPER DOOR: the underside of the upswept tail, cut out of the fuselage's lower facets (its chines
## and belly). The RAMP runs from its hinge at station 11.0, where the belly starts up, to 14.0, and LOWERS until its
## aft edge meets the ground; the UPPER DOOR runs from 14.0 to the tail cone at 15.25 and swings UP into the tail about
## its aft edge, 20 degrees. [JJ] draws the ramp's line; the split and the upper door's travel are ESTIMATE
## from the photographs, which show the ramp down on a deck and the door out of sight above the opening. Both are drawn
## 1.5 per cent narrower than the skin, so a swinging edge never grazes a side wall. The door opens over the first 35 per
## cent of the amount, the ramp over the rest from 25; a whole opening takes `RAMP_SECONDS` drawn.
const RAMP: Vector3 = Vector3(11.0, 14.0, 15.25)  # hinge, the door's forward edge, the door's aft edge
const RAMP_FACETS: Array = [4, 5, 6, 7]
const RAMP_INSET: float = 0.985
## THE UPPER DOOR SWINGS UP 20 DEGREES, its forward edge to 1.99 m up at station 13.85, still on the cabin's upright
## side wall: at 30 degrees, level, that edge stood 2.23 m up where the wall has turned in to the shoulder, and went
## through it (tests/osprey.gd, the ramp through nothing).
const RAMP_DOOR_OPEN: float = deg_to_rad(20.0)
const RAMP_DOOR_BY: float = 0.35
const RAMP_FROM: float = 0.25
const RAMP_SECONDS: float = 10.0

## THE CREW DOOR, forward on the starboard side: [JJ]'s outline from station 3.43 to 4.27. Cut from the fuselage's
## starboard side facets there, it is two halves: the LOWER (the side facet, 0.39 to 1.62 m up) drops outward about its
## sill, 100 degrees, to hang as the steps; the UPPER (the shoulder's slope, up to 2.20) swings in and up about its top
## edge, 85 degrees, under the roof. ESTIMATE of the travel, from the photographs.
const CREW_DOOR: Vector2 = Vector2(3.43, 4.27)
const CREW_UPPER_OPEN: float = deg_to_rad(85.0)
const CREW_LOWER_OPEN: float = deg_to_rad(100.0)

## THE CHIN TURRET: the FLIR ball under the nose, just ahead of the nose gear (the photographs), 0.52 m across. ESTIMATE.
const TURRET: Vector3 = Vector3(0.62, 0.05, 0.26)  # station, middle height, radius

## THE CABIN FLOOR, 0.45 m over the belly from the flight deck's bulkhead to the ramp's hinge: where the simulation stands
## the crew chiefs (`osprey_shape`). ESTIMATE.
const CABIN_FLOOR: Vector3 = Vector3(2.90, 11.0, 0.45)  # from, to, height
const CABIN_FLOOR_HALF: float = 1.20
## THE LINING inside the skin: its walls 1.22 m out, 1.55 m tall, its shoulders turning in to a ceiling 1.00 m either
## side of the middle, 1.75 m over the floor (the published cabin is 1.83 m high).
const LINING_HALF: float = 1.22
const LINING_WALL: float = 1.55
const LINING_CEILING: float = 1.75
const LINING_CEILING_HALF: float = 1.00

## THE FLIGHT DECK: the simulation seats the crew over station 2.34 (`osprey_shape`), anchors 0.70 m over the belly and
## eyes 2.05 m up -- the anchor plus `CockpitStation.EYE_HEIGHT` -- in the middle of the side windows. The room is a box
## promised inside the drawn skin there, its floor the anchors'.
const ROOM: AABB = AABB(Vector3(-0.75, 0.70, 2.00), Vector3(1.50, 1.55, 0.80))

var _half: Vector3 = Vector3.ONE
var _hinges: Dictionary = {}
var _tilt: float = 1.0
var _spin: float = 0.0
var _running: bool = false
var _travel: float = 1.702
var _discs: Array[MeshInstance3D] = []
var _gear: float = 1.0
var _ramp: float = 0.0
var _door: float = 0.0
## THE LEGS, and the turn each is stowed at (from down), worked out from its own geometry when it is built.
var _legs: Array[Node3D] = []
var _stowed: Array[float] = []
## How far the ramp turns to put its aft edge on the ground, worked out from the drawn ramp when it is built.
var _ramp_open: float = 0.0


## BUILT IN PLACE, after `new()`, from the simulation's geometry.
func dress(geometry: Dictionary = {}) -> void:
	name = "Osprey"
	_half = (geometry.get("extents", Vector3(1.75, 1.90, 8.75)) as Vector3)
	_travel = travel()
	var paint: StandardMaterial3D = ShipHull.painted()
	paint.roughness = 0.62
	# THE SKIN SEEN FROM THE SEAT: double-sided, or from inside the one closed solid the crew see no aeroplane at all.
	var inside: StandardMaterial3D = ShipHull.painted()
	inside.roughness = 0.62
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.vertex_color_is_srgb = true
	glass.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.08
	glass.metallic = 0.35

	# THE GLAZING IS THE FUSELAGE'S SECOND SURFACE, so the skin round the crew is one closed solid.
	var body := _tool()
	var glazing := _tool()
	var cut: Dictionary = _fuselage(body, glazing)
	var fuselage := _add(self, "Fuselage", body, paint)
	fuselage.material_override = null
	fuselage.mesh = glazing.commit(fuselage.mesh as ArrayMesh)
	fuselage.set_surface_override_material(0, inside)
	fuselage.set_surface_override_material(1, glass)
	_build_ramp(cut, inside)
	_build_crew_door(cut, inside)
	var floor_tool := _tool()
	_cabin_floor(floor_tool)
	_add(self, "CabinFloor", floor_tool, inside)
	var lining := _tool()
	_cabin_lining(lining)
	_add(self, "CabinLining", lining, inside)
	var turret := _tool()
	_chin_turret(turret)
	AircraftVisualLod.configure(_add(self, "ChinTurret", turret, paint))

	var probe := _tool()
	_probe(probe)
	AircraftVisualLod.configure(_add(self, "RefuellingProbe", probe, paint))
	var wing := _tool()
	_wing(wing)
	_add(self, "Wing", wing, paint)
	var tailplane := _tool()
	_tailplane(tailplane)
	_add(self, "Tailplane", tailplane, paint)
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var sponson := _tool()
		_sponson(sponson, side)
		_add(self, "Sponson" + named, sponson, paint)
		var fin := _tool()
		_fin(fin, side)
		_add(self, "Fin" + named, fin, paint)
		_build_nacelle(side, named, paint)
	_build_gear(paint)
	set_tilt(vertical())
	set_spin(0.0)
	set_rotors(false, 0.0, 0.0)
	set_gear(1.0)
	set_ramp(0.0)
	set_door(0.0)


# ---- the frame ---------------------------------------------------------------------------------------------------------

## A POINT: `out` metres to starboard, `high` over the belly datum, `station` aft of the nose tip, in the craft's frame.
## The drawn length is centred on the box and the ground is its floor.
func point(out: float, high: float, station: float) -> Vector3:
	return Vector3(out, -_half.y + CLEARANCE + high, -LENGTH * 0.5 + station)


## The ground, as a height over the datum: where every tyre stands.
static func ground() -> float:
	return -CLEARANCE


## HOW FAR THE NACELLES SWING, radians: the kind's `vector_travel`, the number `fly_tiltrotor` turns the thrust by
## (lane/lightning made it the kind's; the Osprey's is 1.702). Asked of the simulation every time, never typed here.
static func travel() -> float:
	return float(Sim.handling_of(Sim.Kind.OSPREY)["vector_travel"])


## THE LEVER THAT STANDS THE NACELLES STRAIGHT UP, which is how a V-22 parks and what its published height is measured
## at. Past it, at the full 97.5 degrees, the discs lean back and the blades pointing aft stand 0.65 m higher: the preview
## drew the aircraft 7.37 m high there (tests/aircraft_fidelity.gd).
static func vertical() -> float:
	return PI * 0.5 / travel()


## THE CONVERSION AXIS's point on one side, craft-local.
func pivot(side: float) -> Vector3:
	return point(side * PIVOT_OUT, PIVOT.y, PIVOT.x)


## THE ROOM THE CREW SIT IN, in the shape `VehicleView.cabin_room()` asks for.
func cabin_room() -> Dictionary:
	var low: Vector3 = point(ROOM.position.x, ROOM.position.y, ROOM.position.z)
	var high: Vector3 = point(ROOM.end.x, ROOM.end.y, ROOM.end.z)
	return {
		"drawn": true,
		"floor": point(0.0, ROOM.position.y, 2.35).y,
		"room": AABB(low, high - low).abs(),
		"because": &"",
		"why_not": "",
		"source": "the flight deck over [JJ]'s side-window stations; the room MEASURED against the drawn skin",
	}


## WHETHER A BOX IS INSIDE THE DRAWN FUSELAGE, every corner inside the section at its station, 1 cm in. Asked by
## `VehicleView.holster_fits`, so a seat's signal-lamp holster is hung where the skin covers it: the first holster for the
## left-hand seat, laid out unmirrored, stood 1.12 m out at the flight deck's shoulder, through the skin.
func encloses(box: AABB) -> bool:
	var datum: float = point(0.0, 0.0, 0.0).y
	for corner in range(8):
		var p: Vector3 = box.get_endpoint(corner)
		var s: float = p.z + LENGTH * 0.5
		if s < float(SECTIONS[0][0]) or s > float(SECTIONS[-1][0]):
			return false
		if absf(p.x) > half_width_at(s, p.y - datum) - 0.01:
			return false
	return true


## THE FUSELAGE'S HALF-WIDTH at a station and a height over the belly, off the outline `_ring` draws; 0 outside it.
func half_width_at(station: float, high: float) -> float:
	var row: Array = [station]
	for index in range(1, 5):
		row.append(_column(station, index))
	var ring: Array = _ring(row)
	# The starboard half, top to keel: points 0 to 6.
	for i in range(6):
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[i + 1]
		var ha: float = a.y - point(0.0, 0.0, 0.0).y
		var hb: float = b.y - point(0.0, 0.0, 0.0).y
		if (high <= ha and high >= hb) or (high >= ha and high <= hb):
			if absf(ha - hb) < 1e-6:
				return maxf(a.x, b.x)
			return lerpf(a.x, b.x, (high - ha) / (hb - ha))
	return 0.0


## THE LIGHTS, where a V-22 carries them, in this node's frame: the nav lights on the wing tips' faces (they do not turn
## with the nacelles), the strobes aft of them, the tail light on the tail cone's end, the beacons over the wing fairing
## and under the belly at the conversion axis's station.
func lights() -> Dictionary:
	var tips: Array[Vector3] = []
	var strobes: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		var at: float = wing_le(WING_TIP) + 0.35
		tips.append(point(side * (WING_TIP + 0.02), _wing_mid(WING_TIP), at))
		strobes.append(point(side * (WING_TIP + 0.02), _wing_mid(WING_TIP), at + 0.45))
	return {"port": tips[0], "starboard": tips[1], "strobes": strobes,
		"tail": point(0.0, 2.60, float(SECTIONS[-1][0]) + 0.02),
		"top": point(0.0, 3.52, PIVOT.x), "bottom": point(0.0, -0.02, PIVOT.x)}


func wing_le(out: float) -> float:
	return WING_LE.x + WING_LE.y * absf(out)


func wing_te(out: float) -> float:
	return WING_TE.x + WING_TE.y * absf(out)


func _wing_mid(out: float) -> float:
	return ((WING_TOP.x + WING_TOP.y * absf(out)) + (WING_BOTTOM.x + WING_BOTTOM.y * absf(out))) * 0.5


# ---- what moves ---------------------------------------------------------------------------------------------------------

## THE NACELLES, 0 straight ahead to 1 at the kind's full travel. A PURE FUNCTION OF THE AMOUNT: the angle is `amount x
## travel()`, linear, because the simulation turns its thrust by the same product of the same lever (`fly_tiltrotor`).
func set_tilt(amount: float) -> void:
	# UNCHANGED IS FREE: the view hands every Osprey its bus every frame, and a hundred of them re-posing parts that had
	# not moved cost 3.4 ms a frame (`tests/osprey_shot.gd --only=crowd`).
	if clampf(amount, 0.0, 1.0) == _tilt:
		return
	_tilt = clampf(amount, 0.0, 1.0)
	for named in ["Port", "Starboard"]:
		_turn("Nacelle" + named, _tilt * _travel)


func tilt() -> float:
	return _tilt


## THE ANGLE THE DRAWN NACELLES STAND AT, radians up from straight ahead: what `tests/osprey.gd` holds against the
## simulation's travel.
func tilt_angle() -> float:
	return _tilt * _travel


## THE PROPROTORS' TURN: `phase` 0 to 1 is a third of a turn -- all three identical blades can show -- so a VAT bakes it
## in a third of a turn's rows and the view hands it the phase.
func set_spin(phase: float) -> void:
	_spin = fposmod(phase, 1.0)
	for side in [1.0, -1.0]:
		_turn("Proprotor" + ("Starboard" if side > 0.0 else "Port"), float(SPIN_SENSE[side]) * _spin * TAU / 3.0)


func spin() -> float:
	return _spin


## THE ROTORS RUNNING OR NOT, as the helicopters are told (`RotorcraftKit`): turning at `RotorcraftKit.MAIN_TURNS` a
## second on the physics clock every machine shares, a faint disc over them while they run, parked otherwise.
func set_rotors(running: bool, _collective: float, seconds: float) -> void:
	if not running and not _running and not _discs.is_empty() and not _discs[0].visible:
		return
	_running = running
	if running:
		set_spin(seconds * RotorcraftKit.MAIN_TURNS * 3.0)
	for disc in _discs:
		disc.visible = running
		(disc.material_override as StandardMaterial3D).albedo_color.a = RotorcraftKit.DISC_ALPHA if running else 0.0


func rotors_running() -> bool:
	return _running


## THE GEAR, 0 up and 1 down, IN THE F-35B'S SEQUENCE: doors open, legs travel, doors shut. The well doors are open
## over the middle of the cycle and shut at both ends, so a leg never moves while its doors are shut. A PURE FUNCTION OF
## THE AMOUNT, so a VAT bakes it and an amount off the grid draws between its rows.
func set_gear(amount: float) -> void:
	if clampf(amount, 0.0, 1.0) == _gear:
		return
	_gear = clampf(amount, 0.0, 1.0)
	var legs: float = legs_down(_gear)
	for index in range(_legs.size()):
		_legs[index].basis = Basis(Vector3.RIGHT, (1.0 - legs) * _stowed[index])
	var doors: float = well_doors_open(_gear)
	for named in ["NoseDoorStarboard", "NoseDoorPort", "MainDoorStarboard", "MainDoorPort"]:
		_turn(named, doors * WELL_OPEN)


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


## THE RAMP, 0 shut to 1 down on the ground: the upper door swings up into the tail over the first `RAMP_DOOR_BY`, and
## the ramp lowers from `RAMP_FROM` until its aft edge meets the ground.
func set_ramp(amount: float) -> void:
	if clampf(amount, 0.0, 1.0) == _ramp:
		return
	_ramp = clampf(amount, 0.0, 1.0)
	_turn("RampDoor", smoothstep(0.0, RAMP_DOOR_BY, _ramp) * RAMP_DOOR_OPEN)
	_turn("Ramp", smoothstep(RAMP_FROM, 1.0, _ramp) * _ramp_open)


func ramp() -> float:
	return _ramp


## THE CREW DOOR, 0 shut to 1 open: the upper half swings in and up first, the lower drops out to be the steps.
func set_door(amount: float) -> void:
	if clampf(amount, 0.0, 1.0) == _door:
		return
	_door = clampf(amount, 0.0, 1.0)
	_turn("CrewDoorUpper", smoothstep(0.0, 0.5, _door) * CREW_UPPER_OPEN)
	_turn("CrewDoorLower", smoothstep(0.3, 1.0, _door) * CREW_LOWER_OPEN)


func door() -> float:
	return _door


## HOW FAR THE RAMP TURNS DOWN, radians: until its lowest drawn point meets the ground.
func ramp_travel() -> float:
	return _ramp_open


## THE FEATURES A VAT BAKES (`VatCasting`): the nacelles and the blades' third of a turn inside them, the gear with its
## doors, the ramp with its upper door, and the crew door.
func features() -> Array:
	return [
		{"name": "tilt", "set": set_tilt, "get": tilt, "low": 0.0, "high": 1.0},
		{"name": "spin", "set": set_spin, "get": spin, "low": 0.0, "high": 1.0, "samples": 65},
		{"name": "gear", "set": set_gear, "get": gear, "low": 0.0, "high": 1.0},
		{"name": "ramp", "set": set_ramp, "get": ramp, "low": 0.0, "high": 1.0, "samples": 65},
		{"name": "door", "set": set_door, "get": door, "low": 0.0, "high": 1.0},
	]



## WHAT A VAT DOES NOT POUR: the discs, whose see-through fade is not a transform (`VatCasting`: "a part's visibility is
## not baked"). They ride their nacelle's hinge on the CPU.
static func unpoured(part: MeshInstance3D) -> bool:
	return String(part.name).ends_with("Disc")


## A HINGE turned `angle` radians from where it was built, about the axis stored on it when it was built.
func _turn(named: String, angle: float) -> void:
	var hinge: Node3D = _hinges.get(named) as Node3D
	if hinge != null:
		hinge.basis = Basis(hinge.get_meta("axis") as Vector3, angle)


## A HINGE at `at` (in `parent`'s frame), turning about `along`.
func _hinge(named: String, parent: Node3D, at: Vector3, along: Vector3) -> Node3D:
	var hinge := Node3D.new()
	# "HINGE" ON THE END, so a hinge is never found in place of the part it carries (lane/tomcat2).
	hinge.name = named + "Hinge"
	hinge.position = at
	hinge.set_meta("axis", along.normalized())
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


## A LOFT through matching closed loops, each quad facing away from its own loops' middle, both ends closed by fans.
## `tint` answers each quad's colour from (span, facet, its outward normal).
static func _loft(tool: SurfaceTool, loops: Array, tint: Callable, close: bool = true) -> void:
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
			Plating.facing(tool, quad, mid - mid_centre, tint.call(i, k, (mid - mid_centre).normalized()))
	if not close:
		return
	for end in [0, loops.size() - 1]:
		var along: Vector3 = (centres[end] as Vector3) - centres[1 if end == 0 else loops.size() - 2]
		var loop: Array = loops[end]
		for k in range(n):
			_fan(tool, centres[end], loop[k], loop[(k + 1) % n], along, tint.call(-1, k, along.normalized()))


## A FLAT SLAB from a 2D outline: `place` turns an outline point into its middle-surface position, `across` is the slab's
## normal and `half` its half-thickness. The engine's ear clipper triangulates both faces.
static func _slab(tool: SurfaceTool, outline: PackedVector2Array, place: Callable, across: Vector3, half: float,
		tint: Color) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var top: Array = []
	var under: Array = []
	for p in outline:
		top.append((place.call(p) as Vector3) + across * half)
		under.append((place.call(p) as Vector3) - across * half)
	for t in range(0, tris.size(), 3):
		_fan(tool, top[tris[t]], top[tris[t + 1]], top[tris[t + 2]], across, tint)
		_fan(tool, under[tris[t]], under[tris[t + 1]], under[tris[t + 2]], -across, tint)
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


## THE FUSELAGE'S RING at one row of SECTIONS: 12 points from the top centreline down the starboard side to the keel and
## back up the port side.
func _ring(row: Array) -> Array:
	var s: float = row[0]
	var top: float = row[1]
	var bottom: float = row[2]
	var half: float = row[3]
	var roof: float = row[4]
	var tall: float = roof - bottom
	var crown_w: float = half * 0.55 if top <= roof + 0.01 else 0.62
	var starboard: Array = [Vector2(0.0, top), Vector2(crown_w, top - 0.04 * (top - bottom)),
		Vector2(half * 0.89, bottom + 0.84 * tall), Vector2(half, bottom + 0.62 * tall),
		Vector2(half, bottom + 0.15 * tall), Vector2(half * 0.72, bottom), Vector2(0.0, bottom)]
	var points: Array = []
	for i in range(starboard.size() - 1):
		points.append(point((starboard[i] as Vector2).x, (starboard[i] as Vector2).y, s))
	for i in range(starboard.size() - 1, 0, -1):
		points.append(point(-(starboard[i] as Vector2).x, (starboard[i] as Vector2).y, s))
	return points


## WHETHER A FUSELAGE PANEL IS GLASS: the facets round the windscreen, the side windows and the chin windows, by the
## span's middle station. Facets 0 and 11 are the roof, 1 and 10 the shoulders, 2 and 9 the upper sides, 3 and 8 the
## sides, 4 and 7 the chines, 5 and 6 the belly.
static func _glazed(station: float, facet: int) -> bool:
	var from_top: int = facet if facet < 6 else 11 - facet
	if station > WINDSCREEN.x and station < WINDSCREEN.y:
		return from_top <= 2
	if station > SIDE_WINDOWS.x and station < SIDE_WINDOWS.y:
		return from_top == 1 or from_top == 2
	if station > CHIN_WINDOWS.x and station < CHIN_WINDOWS.y:
		return from_top == 3
	return false


## THE FUSELAGE: 12 flat facets a ring through the measured sections, the nose a fan to its tip and the tail closed.
## Upward-facing panels take the darker top grey.
func _fuselage(tool: SurfaceTool, glazing: SurfaceTool) -> Dictionary:
	var cut: Dictionary = {}
	var rings: Array = []
	for row in SECTIONS:
		rings.append(_ring(row))
	var n: int = FUSELAGE_SIDES
	for r in range(rings.size() - 1):
		var here: float = (float(SECTIONS[r][0]) + float(SECTIONS[r + 1][0])) * 0.5
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var centre: Vector3 = point(0.0, (float(SECTIONS[r][4]) + float(SECTIONS[r][2])) * 0.5, here)
		for k in range(n):
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			var out: Vector3 = Vector3(mid.x - centre.x, mid.y - centre.y, 0.0)
			if _glazed(here, k):
				Plating.facing(glazing, quad, out, GLASS)
				continue
			var normal: Vector3 = ((quad[2] as Vector3) - (quad[0] as Vector3)).cross(
				(quad[1] as Vector3) - (quad[0] as Vector3)).normalized()
			if normal.dot(out) < 0.0:
				normal = -normal
			var panel: String = _panel_of(here, k)
			if not panel.is_empty():
				if not cut.has(panel):
					cut[panel] = []
				(cut[panel] as Array).append([quad, out, TOP if normal.y > 0.5 else LOWER])
				continue
			Plating.facing(tool, quad, out, TOP if normal.y > 0.5 else LOWER)
	# THE NOSE: a fan from the first ring to the nose tip. THE TAIL: a fan to the last ring's middle.
	var tip: Vector3 = point(0.0, NOSE_TIP_H, 0.0)
	var first: Array = rings[0]
	for k in range(n):
		_fan(tool, tip, first[k], first[(k + 1) % n], Vector3.FORWARD, TOP if k <= 1 or k >= n - 2 else LOWER)
	var last: Array = rings[rings.size() - 1]
	var row: Array = SECTIONS[-1]
	var back: Vector3 = point(0.0, (float(row[1]) + float(row[2])) * 0.5, float(row[0]) + 0.05)
	for k in range(n):
		_fan(tool, back, last[k], last[(k + 1) % n], Vector3.BACK, LOWER)
	return cut


## WHICH MOVING PANEL a fuselage facet belongs to, by its span's middle station, or "" for skin: the ramp and its
## upper door out of the lower facets aft, the crew door's halves out of the starboard side's facets 2 and 3.
static func _panel_of(station: float, facet: int) -> String:
	if RAMP_FACETS.has(facet) and station > RAMP.x and station < RAMP.z:
		return "Ramp" if station < RAMP.y else "RampDoor"
	if station > CREW_DOOR.x and station < CREW_DOOR.y:
		if facet == 3:
			return "CrewDoorLower"
		if facet == 2:
			return "CrewDoorUpper"
	return ""


## THE REFUELLING PROBE: an eight-sided tube along the starboard side of the nose, its tip a little fatter (the drogue's
## coupling), its root buried in the nose.
func _probe(tool: SurfaceTool) -> void:
	var rings: Array = []
	for row in [[PROBE.z, 0.07], [PROBE.z + 0.04, 0.12], [PROBE.z + 0.16, 0.12], [PROBE.z + 0.24, 0.08],
			[PROBE_ROOT, 0.10]]:
		var ring: Array = []
		for k in range(8):
			var angle: float = TAU * (float(k) + 0.5) / 8.0
			ring.append(point(PROBE.x + cos(angle) * float(row[1]), PROBE.y + sin(angle) * float(row[1]), float(row[0])))
		rings.append(ring)
	_loft(tool, rings, func(_s, _k, _n): return METAL)


## ONE SPONSON: 8 points a ring, the front view's section scaled out to the plan's outline at each station, its inner
## edge bedded in the cabin's side. Where the belly rises aft, its bottom rises with it.
func _sponson(tool: SurfaceTool, side: float) -> void:
	var rings: Array = []
	var widest: float = float(SPONSON_SECTION[4][0])
	for row in SPONSON:
		var s: float = row[0]
		var reach: float = (float(row[1]) - SPONSON_ROOT) / (widest - SPONSON_ROOT)
		var floor_h: float = _bottom_at(s)
		var ring: Array = []
		for p in SPONSON_SECTION:
			var out: float = SPONSON_ROOT + (float(p[0]) - SPONSON_ROOT) * reach
			var high: float = floor_h + float(p[1]) * (1.62 - floor_h) / 1.62
			ring.append(point(side * out, high, s))
		rings.append(ring)
	_loft(tool, rings, func(_s, _k, normal: Vector3): return TOP if normal.y > 0.5 else LOWER)


## THE BELLY'S HEIGHT at a station, from the section table.
func _bottom_at(s: float) -> float:
	return _column(s, 2)


## THE SPINE'S HEIGHT at a station.
func _top_at(s: float) -> float:
	return _column(s, 1)


## ONE COLUMN of the section table, interpolated along the fuselage.
func _column(s: float, index: int) -> float:
	for i in range(SECTIONS.size() - 1):
		var a: Array = SECTIONS[i]
		var b: Array = SECTIONS[i + 1]
		if s <= float(b[0]):
			return lerpf(float(a[index]), float(b[index]),
				clampf((s - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))
	return float(SECTIONS[-1][index])


## THE WING: one piece from tip to tip through the fuselage's fairing, an eight-point airfoil at seven stations, swept
## forward and with its dihedral from the centre.
func _wing(tool: SurfaceTool) -> void:
	var loops: Array = []
	for out in [-WING_TIP, -4.0, -1.33, 0.0, 1.33, 4.0, WING_TIP]:
		var le: float = wing_le(out)
		var chord: float = wing_te(out) - le
		var top: float = WING_TOP.x + WING_TOP.y * absf(out)
		var bottom: float = WING_BOTTOM.x + WING_BOTTOM.y * absf(out)
		var mid: float = (top + bottom) * 0.5
		var half_deep: float = (top - bottom) * 0.5
		var loop: Array = []
		for p in AIRFOIL:
			loop.append(point(out, mid + float(p[1]) * half_deep, le + float(p[0]) * chord))
		loops.append(loop)
	_loft(tool, loops, func(_s, _k, normal: Vector3): return TOP if normal.y > 0.3 else LOWER)


## THE TAILPLANE: a slab between the fins, its ends inside them.
func _tailplane(tool: SurfaceTool) -> void:
	var outline := PackedVector2Array([Vector2(-FIN_OUT, TAILPLANE.x + 0.20), Vector2(FIN_OUT, TAILPLANE.x + 0.20),
		Vector2(FIN_OUT, TAILPLANE.y), Vector2(-FIN_OUT, TAILPLANE.y)])
	var place := func(p: Vector2) -> Vector3: return point(p.x, TAILPLANE.z, p.y)
	_slab(tool, outline, place, Vector3.UP, TAILPLANE_DEEP * 0.5, TOP)
	# THE LEADING EDGE rounded off in one facet: a strip ahead of the slab, half as deep.
	var le := PackedVector2Array([Vector2(-FIN_OUT, TAILPLANE.x), Vector2(FIN_OUT, TAILPLANE.x),
		Vector2(FIN_OUT, TAILPLANE.x + 0.22), Vector2(-FIN_OUT, TAILPLANE.x + 0.22)])
	_slab(tool, le, place, Vector3.UP, TAILPLANE_DEEP * 0.25, LOWER)


## ONE FIN: a slab through [JJ]'s side outline, standing FIN_OUT out and canted in at the top.
func _fin(tool: SurfaceTool, side: float) -> void:
	var outline := PackedVector2Array()
	for p in FIN:
		outline.append(Vector2(float(p[0]), float(p[1])))
	var base: float = TAILPLANE.z
	var place := func(p: Vector2) -> Vector3:
		return point(side * (FIN_OUT - (p.y - base) * tan(FIN_CANT)), p.y, p.x)
	var across := Vector3(side * cos(FIN_CANT), side * sin(FIN_CANT), 0.0)
	_slab(tool, outline, place, across, FIN_THICK * 0.5, TOP)


## ONE NACELLE, its PROPROTOR and its DISC, on a hinge at the conversion axis. The nacelle is built in aeroplane mode;
## the hinge turns it up.
func _build_nacelle(side: float, named: String, paint: Material) -> void:
	var axis_at: Vector3 = pivot(side)
	var hinge := _hinge("Nacelle" + named, self, axis_at, Vector3.RIGHT)
	# Points in the hinge's frame: forward is -Z, up +Y, out is +X on the starboard side.
	var local := func(a: float, up: float, across: float) -> Vector3: return Vector3(across, up, -a)
	var rings: Array = []
	for row in NACELLE:
		var a: float = row[0]
		var low: float = row[1]
		var high: float = row[2]
		var half: float = row[3]
		var middle: float = -side * float(row[4])
		var ring: Array = []
		for k in range(NACELLE_SIDES):
			var angle: float = TAU * (float(k) + 0.5) / float(NACELLE_SIDES)
			var c: float = cos(angle)
			var s: float = sin(angle)
			# A ROUNDED BOX, not an ellipse: the nacelle is a tall pod with flat-ish sides.
			var x: float = signf(c) * pow(absf(c), 0.6) * half
			var y: float = (low + high) * 0.5 + signf(s) * pow(absf(s), 0.6) * (high - low) * 0.5
			ring.append(local.call(a, y, middle + x))
		rings.append(ring)
	var skin := _tool()
	_loft(skin, rings, func(_s, _k, normal: Vector3): return TOP if normal.y > 0.3 else LOWER)
	_add(hinge, "Nacelle" + named, skin, paint)

	# THE PROPROTOR: a hinge on the rotor's axis, the spinner, the hub and three blades in one mesh.
	var hub_at: Vector3 = local.call(BLADE_PLANE, HUB_UP, 0.0)
	var spin := _hinge("Proprotor" + named, hinge, hub_at, Vector3.FORWARD)
	var rotor := _tool()
	_spinner(rotor)
	var sense: float = float(SPIN_SENSE[side])
	for b in range(3):
		# THE FIRST BLADE POINTS OUTBOARD, so a parked rotor's tip stands at [WP]'s 25.77 m width.
		_blade(rotor, TAU * float(b) / 3.0 + (0.0 if side > 0.0 else PI), sense)
	_add(spin, "Proprotor" + named, rotor, paint)

	# THE DISC, circumscribing the swept circle, faint and unshaded, shown only while the rotor runs.
	var disc_tool := _tool()
	var rim: Array = []
	for k in range(24):
		var angle: float = TAU * float(k) / 24.0
		rim.append(Vector3(cos(angle), sin(angle), 0.0) * ROTOR_RADIUS / cos(PI / 24.0))
	for k in range(24):
		_fan(disc_tool, Vector3.ZERO, rim[k], rim[(k + 1) % 24], Vector3.FORWARD, BLACK)
	var disc := _add(hinge, "Proprotor" + named + "Disc", disc_tool, RotorcraftKit.disc_material(), hub_at)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.visible = false
	_discs.append(disc)


## THE SPINNER: an eight-sided cone on the rotor's axis, in the spin hinge's frame (forward -Z), and the hub behind it.
func _spinner(tool: SurfaceTool) -> void:
	var foot: float = SPINNER.x - BLADE_PLANE
	var tip: Vector3 = Vector3(0.0, 0.0, -(SPINNER.y - BLADE_PLANE))
	var rings: Array = []
	for row in [[foot - 0.30, SPINNER.z * 0.80], [foot, SPINNER.z], [foot + 0.22, SPINNER.z * 0.78]]:
		var ring: Array = []
		for k in range(8):
			var angle: float = TAU * (float(k) + 0.5) / 8.0
			ring.append(Vector3(cos(angle) * float(row[1]), sin(angle) * float(row[1]), -float(row[0])))
		rings.append(ring)
	_loft(tool, rings, func(_s, _k, _n): return METAL)
	var last: Array = rings[rings.size() - 1]
	for k in range(8):
		_fan(tool, tip, last[k], last[(k + 1) % 8], Vector3.FORWARD, TOP)


## ONE BLADE at `angle` round the rotor, in the spin hinge's frame (the rotor's plane is z = 0, forward -Z). [NASA]'s
## chord, tapering from 36 in at 5 per cent of the radius to 22 in at the tip, and its 47.5 degrees of twist, drawn at
## 14 degrees of pitch at three quarters of the radius. The leading edge goes the way the blade turns (`sense`), turned
## towards the thrust by the pitch. A six-point airfoil at six stations.
func _blade(tool: SurfaceTool, angle: float, sense: float) -> void:
	var span := Vector3(cos(angle), sin(angle), 0.0)
	var along: Vector3 = Vector3.FORWARD.cross(span).normalized() * sense
	var rings: Array = []
	for r in BLADE_STATIONS:
		var radius: float = float(r)
		var chord: float = lerpf(CHORD_ROOT, CHORD_TIP, clampf((radius - 0.05 * ROTOR_RADIUS)
			/ (ROTOR_RADIUS * 0.95), 0.0, 1.0))
		if radius < 1.2:
			chord = CHORD_ROOT * 0.8
		var pitch: float = PITCH_75 + TWIST * (0.75 - radius / ROTOR_RADIUS)
		var lead: Vector3 = along * cos(pitch) + Vector3.FORWARD * sin(pitch)
		var thick: Vector3 = Vector3.FORWARD * cos(pitch) - along * sin(pitch)
		var deep: float = chord * lerpf(0.22, 0.09, radius / ROTOR_RADIUS)
		var centre: Vector3 = span * radius
		rings.append([centre + lead * chord * 0.30, centre + lead * chord * 0.18 + thick * deep * 0.5,
			centre - lead * chord * 0.25 + thick * deep * 0.3, centre - lead * chord * 0.70,
			centre - lead * chord * 0.25 - thick * deep * 0.2, centre + lead * chord * 0.18 - thick * deep * 0.4])
	_loft(tool, rings, func(s, _k, _n): return BLADE_TIP if s == BLADE_STATIONS.size() - 2 else BLADE)


## THE GEAR: each leg a strut and an axle with its twin tyres, on a hinge at its pivot, built DOWN and turned up by
## `set_gear`; the turn it stows at is worked out here from its own geometry, so a leg moved in the table stows level
## wherever it is. The well doors on hinges at their outer edges, and the wells' insides as patches just under the skin,
## hidden by the doors until they open.
func _build_gear(paint: Material) -> void:
	var legs: Array = [["NoseGear", 0.0, NOSE_LEG, NOSE_TYRE, 1.0], ["MainGearStarboard", 1.0, MAIN_LEG, MAIN_TYRE, -1.0],
		["MainGearPort", -1.0, MAIN_LEG, MAIN_TYRE, -1.0]]
	for leg in legs:
		var named: String = leg[0]
		var side: float = leg[1]
		var row: Vector4 = leg[2]
		var tyre: Vector3 = leg[3]
		var stows: float = leg[4]  # +1 aft, -1 forward
		var pivot_at: Vector3 = point(side * row.x, row.y, row.z)
		var axle_at: Vector3 = point(side * row.x, ground() + tyre.x * cos(PI / float(TYRE_SIDES)), row.w)
		var hinge := _hinge(named, self, pivot_at, Vector3.RIGHT)
		var tool := _tool()
		var axle: Vector3 = axle_at - pivot_at
		RotorcraftKit.rod(tool, Vector3.ZERO, axle, 0.08 if named == "NoseGear" else 0.11, GEAR, 6)
		RotorcraftKit.rod(tool, axle + Vector3(-tyre.y - tyre.z * 0.5, 0.0, 0.0),
			axle + Vector3(tyre.y + tyre.z * 0.5, 0.0, 0.0), 0.05, GEAR, 6)
		for w in [-1.0, 1.0]:
			RotorcraftKit.rod(tool, axle + Vector3(w * tyre.y - tyre.z * 0.5, 0.0, 0.0),
				axle + Vector3(w * tyre.y + tyre.z * 0.5, 0.0, 0.0), tyre.x, TYRE, TYRE_SIDES)
		AircraftVisualLod.configure(_add(hinge, named, tool, paint))
		# THE STOWED TURN: the one that lays the axle level with the pivot, aft (+z) or forward (-z) of it. About +X a
		# turn takes (y, z) anticlockwise in that plane, so it is the difference of the two angles atan2(z, y).
		var now: float = atan2(axle.z, axle.y)
		var wanted: float = atan2(stows * axle.length(), 0.0)
		_legs.append(hinge)
		_stowed.append(wrapf(wanted - now, -PI, PI))
	# THE DOORS: the nose well's pair either side of the strut's slot, and each main well's one.
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		_well_door("NoseDoor" + named, side, NOSE_DOORS.z, NOSE_DOORS.w, NOSE_DOORS.x, NOSE_DOORS.y,
			_bottom_at((NOSE_DOORS.x + NOSE_DOORS.y) * 0.5) - DOOR_DROP, paint)
		_well_door("MainDoor" + named, side, MAIN_DOOR.z, MAIN_DOOR.w, MAIN_DOOR.x, MAIN_DOOR.y, -DOOR_DROP, paint)
	var wells := _tool()
	_patch(wells, -NOSE_DOORS.w, NOSE_DOORS.w, NOSE_LEG.w - 0.15, NOSE_DOORS.y, _bottom_at(1.6) - 0.01)
	for side in [1.0, -1.0]:
		_patch(wells, side * (MAIN_DOOR.z - 0.02), side * MAIN_DOOR.w, MAIN_DOOR.x - 0.05, MAIN_LEG.z, -0.01)
	_add(self, "Wells", wells, paint)


## ONE WELL DOOR: a plate from `inner` to `outer` metres out on `side`, `fore` to `aft`, at `high`, on a hinge along its
## outer edge that swings its inner edge down.
func _well_door(named: String, side: float, inner: float, outer: float, fore: float, aft: float, high: float,
		paint: Material) -> void:
	var hinge_at: Vector3 = point(side * outer, high, (fore + aft) * 0.5)
	var hinge := _hinge(named, self, hinge_at, Vector3(0.0, 0.0, side))
	var tool := _tool()
	var outline := PackedVector2Array([Vector2(inner, fore), Vector2(outer, fore), Vector2(outer, aft),
		Vector2(inner, aft)])
	var place := func(p: Vector2) -> Vector3: return point(side * p.x, high, p.y) - hinge_at
	_slab(tool, outline, place, Vector3.UP, 0.01, LOWER)
	_add(hinge, named, tool, paint)


## A WELL'S INSIDE: a flat patch facing down at `high`, from `from` to `to` across and `fore` to `aft` along.
func _patch(tool: SurfaceTool, from: float, to: float, fore: float, aft: float, high: float) -> void:
	var corners: Array = [point(from, high, fore), point(to, high, fore), point(to, high, aft), point(from, high, aft)]
	Plating.facing(tool, corners, Vector3.DOWN, WELL)


## THE RAMP AND ITS UPPER DOOR, from the panels the fuselage left out: each on a hinge across the fuselage, the ramp's
## at its forward edge on the belly, the door's at its aft edge where the tail cone begins, each drawn `RAMP_INSET` of the
## skin's width. How far the ramp turns is worked out here: until its lowest drawn point meets the ground.
func _build_ramp(cut: Dictionary, material: Material) -> void:
	var ramp_hinge_at: Vector3 = point(0.0, _bottom_at(RAMP.x), RAMP.x)
	# THE DOOR'S HINGE IS AT ITS CHINES' HEIGHT, not the keel's: turned about the keel, its chines swung aft through the
	# tail cone's first facets (tests/osprey.gd, the ramp through nothing).
	var door_hinge_at: Vector3 = point(0.0, _bottom_at(RAMP.z) + 0.15 * (_column(RAMP.z, 4) - _bottom_at(RAMP.z)), RAMP.z)
	var ramp := _panel("Ramp", cut, ramp_hinge_at, Vector3.RIGHT, RAMP_INSET, material)
	_panel("RampDoor", cut, door_hinge_at, Vector3.RIGHT, RAMP_INSET, material)
	# THE TURN THAT PUTS THE RAMP ON THE GROUND, by bisection over its drawn points.
	var pts := (ramp.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var floor_y: float = point(0.0, ground(), 0.0).y - ramp_hinge_at.y
	var lo: float = 0.0
	var hi: float = deg_to_rad(80.0)
	for _i in range(40):
		var mid: float = (lo + hi) * 0.5
		var lowest: float = INF
		var turn := Basis(Vector3.RIGHT, mid)
		for p in pts:
			lowest = minf(lowest, (turn * p).y)
		if lowest > floor_y:
			lo = mid
		else:
			hi = mid
	_ramp_open = lo


## THE CREW DOOR'S TWO HALVES, from the starboard side's panels: the lower on a hinge along its sill, the upper along
## its top edge, both running fore and aft.
func _build_crew_door(cut: Dictionary, material: Material) -> void:
	var middle: float = (CREW_DOOR.x + CREW_DOOR.y) * 0.5
	var roof: float = _column(middle, 4)
	var half: float = _column(middle, 3)
	# EACH HALF DRAWN 2 CM SHY OF ITS OPENING'S EDGES: the roof line rises 2 cm over the door's length, so an edge laid on
	# it is off a straight hinge at its ends, and the first swing put the upper half's corners through the roof.
	_panel("CrewDoorLower", cut, point(half, 0.15 * roof, middle), Vector3.BACK, 1.0, material, 0.02)
	_panel("CrewDoorUpper", cut, point(half * 0.89, 0.84 * roof, middle), Vector3.BACK, 1.0, material, 0.02)


## ONE MOVING PANEL from the fuselage's cut facets, on a hinge at `hinge_at` turning about `along`, its points drawn
## `inset` of their distance from the centreline. Returns the mesh.
func _panel(named: String, cut: Dictionary, hinge_at: Vector3, along: Vector3, inset: float,
		material: Material, shy: float = 0.0) -> MeshInstance3D:
	var hinge := _hinge(named, self, hinge_at, along)
	var tool := _tool()
	# The panel's middle, for drawing it `shy` metres in from its edges.
	var middle := Vector3.ZERO
	var count: int = 0
	for entry in cut.get(named, []):
		for p in (entry[0] as Array):
			middle += p
			count += 1
	middle /= float(maxi(count, 1))
	for entry in cut.get(named, []):
		var quad: Array = []
		for p in (entry[0] as Array):
			var q: Vector3 = p
			if shy > 0.0:
				var towards: Vector3 = Vector3(0.0, middle.y - q.y, middle.z - q.z)
				q += towards.normalized() * minf(shy, towards.length()) if towards.length() > 0.0 else Vector3.ZERO
			quad.append(Vector3(q.x * inset, q.y, q.z) - hinge_at)
		Plating.facing(tool, quad, entry[1] as Vector3, entry[2] as Color)
	return _add(hinge, named, tool, material)


## THE CABIN FLOOR: a slab from the flight deck's bulkhead to the ramp's hinge, where the crew chiefs stand.
func _cabin_floor(tool: SurfaceTool) -> void:
	var outline := PackedVector2Array([Vector2(-CABIN_FLOOR_HALF, CABIN_FLOOR.x),
		Vector2(CABIN_FLOOR_HALF, CABIN_FLOOR.x), Vector2(CABIN_FLOOR_HALF, CABIN_FLOOR.y),
		Vector2(-CABIN_FLOOR_HALF, CABIN_FLOOR.y)])
	var place := func(p: Vector2) -> Vector3: return point(p.x, CABIN_FLOOR.z, p.y)
	_slab(tool, outline, place, Vector3.UP, 0.02, FLOOR)


## THE CABIN'S LINING: dark walls, ceiling and shoulders inside the skin from the flight deck's bulkhead to the ramp's
## hinge, drawn from both sides. WHY: the skin is drawn from both sides too, so the first open crew door showed the far
## wall's inside in the skin's own grey, and read as no doorway at all. The starboard wall, shoulder and ceiling leave the
## crew door's stations open, so the upper half has room to swing in. ESTIMATE of the cabin: 2.44 m wide at the walls,
## 1.75 m from the floor to the ceiling.
func _cabin_lining(tool: SurfaceTool) -> void:
	var fore: float = CABIN_FLOOR.x
	var aft: float = CABIN_FLOOR.y
	var floor_h: float = CABIN_FLOOR.z
	var wall: float = LINING_HALF
	var spans: Array = [[fore, aft, -1.0]]
	spans.append([fore, CREW_DOOR.x, 1.0])
	spans.append([CREW_DOOR.y, aft, 1.0])
	for span in spans:
		var a: float = float(span[0])
		var b: float = float(span[1])
		var side: float = float(span[2])
		var wall_top: float = floor_h + LINING_WALL
		var ceiling: float = floor_h + LINING_CEILING
		# The wall, the shoulder up to the ceiling's edge, and this side's half of the ceiling.
		Plating.facing(tool, [point(side * wall, floor_h, a), point(side * wall, wall_top, a), point(side * wall, wall_top, b),
			point(side * wall, floor_h, b)], Vector3(-side, 0.0, 0.0), LINING)
		Plating.facing(tool, [point(side * wall, wall_top, a), point(side * LINING_CEILING_HALF, ceiling, a),
			point(side * LINING_CEILING_HALF, ceiling, b), point(side * wall, wall_top, b)], Vector3(-side, -1.0, 0.0), LINING)
		Plating.facing(tool, [point(0.0, ceiling, a), point(side * LINING_CEILING_HALF, ceiling, a),
			point(side * LINING_CEILING_HALF, ceiling, b), point(0.0, ceiling, b)], Vector3.DOWN, LINING)
	# The starboard ceiling over the door is kept: the upper half swings in under it.
	var ceiling_h: float = floor_h + LINING_CEILING
	Plating.facing(tool, [point(0.0, ceiling_h, CREW_DOOR.x), point(0.45, ceiling_h, CREW_DOOR.x),
		point(0.45, ceiling_h, CREW_DOOR.y), point(0.0, ceiling_h, CREW_DOOR.y)], Vector3.DOWN, LINING)


## THE CHIN TURRET: an eight-sided ball on a short neck, its top buried in the nose, its window facing ahead.
func _chin_turret(tool: SurfaceTool) -> void:
	var rings: Array = []
	var r: float = TURRET.z
	for row in [[TURRET.y + r * 1.3, r * 0.8], [TURRET.y + r * 0.35, r], [TURRET.y - r * 0.35, r],
			[TURRET.y - r * 0.85, r * 0.55]]:
		var ring: Array = []
		for k in range(8):
			var angle: float = TAU * (float(k) + 0.5) / 8.0
			ring.append(point(cos(angle) * float(row[1]), float(row[0]), TURRET.x + sin(angle) * float(row[1])))
		rings.append(ring)
	_loft(tool, rings, func(span, k, _n): return GLASS if span == 1 and (k == 5 or k == 6) else LOWER)
