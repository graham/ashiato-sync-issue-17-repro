@tool
extends Node3D
class_name WarthogAirframe
## A FAIRCHILD REPUBLIC A-10C THUNDERBOLT II, DRAWN: the "Warthog". Its first-glance features are the straight, thick,
## low wing with its drooped tips; the two TF34 turbofans in pods high on the rear fuselage; the twin fins on the ends
## of a straight tailplane; the bubble canopy set high and forward; the main gear's pods on the wing's leading edge, their
## wheels half out of them when they are up; and the GAU-8/A Avenger's seven barrels under the nose. What MOVES:
## - THE GAU-8 (`set_gun`): the barrel cluster turns about its axis. The gun is mounted to PORT so that the barrel in the
##   firing position, the starboard one, lies ON THE CENTRELINE, bore-sighted 2 degrees below the line of flight
##   [GAU-8 article]. `gun_port()` is that barrel's muzzle, and the rounds leave from it;
## - THE GEAR (`set_gear`), in sequence: the nose well's doors open, the three legs swing, the doors shut. The mains fold
##   FORWARD into their pods and have no doors, so a retracted main wheel stays half out of its pod, as on the real
##   aircraft (for a gear-up landing). The nose leg is OFFSET TO STARBOARD, because the gun has the centreline;
## - THE SURFACES: the ailerons, each split into an upper and a lower half that open apart as the speed brake (the
##   DECELERONS, `set_speedbrake`), the elevators, both rudders and the flaps.
##
## PRESENTATION ONLY. The native simulation owns the size (`dress` reads `extents` and `span`), the flight, the collision,
## the stations and the wire: kind WARTHOG since 2026-09-19. And it owns WHERE THE ROUNDS ARE BORN, `loadout_of`'s gun,
## which `tests/warthog_gun.gd` holds to this drawing's `gun_port()`, not to itself.
##
## ORIGINAL GEOMETRY, MEASURED. No mesh, texture, photograph or livery is incorporated. Every size names its source:
## - [K] Kaboldy's three-view on Wikimedia Commons, "Fairchild Republic A-10 Thunderbolt II 3-view.svg", CC BY-SA 3.0,
##   studied and measured, not incorporated. Rasterised at x3 its three views share ONE scale: the plan's span and the
##   front view's are both 3,503 px, the plan's length 3,238 and the side's 3,237. The published span over the plan's
##   is 199.83 px a metre, 5 mm a pixel; the length then comes out 16.204 m against the published 16.26 (-0.35 per
##   cent). `craft/warthog/measure_views.py` re-derives every MEASURED figure here from the drawing alone.
## - [WP] Wikipedia's A-10 specifications: 16.26 m long, 17.53 m span, 4.47 m high, 47.0 m2 of wing. [GAU] its GAU-8/A
##   article: seven barrels, a fixed 3,900 rounds a minute, 1,013 m/s, 1,174 rounds, the firing barrel on the centreline.
## - ESTIMATE where nothing gives a figure, and it says what it was reasoned from.
##
## STATIONS ARE METRES AFT OF THE FOREMOST POINT, the GAU-8's muzzle; HEIGHTS ARE METRES OVER THE BELLY DATUM, the flat of
## the belly under the wing in [K]'s side view; OUT is metres to starboard. [K] draws the gear UP, and draws the wheels a
## second time below it on ground lines 1.54 m under the datum, which stands the fin tip 4.60 m up: 2.9 per cent over
## [WP]'s 4.47. The model is BUILT to the published figure, the ground `CLEARANCE` under the datum, and the tyres are the
## real ones (drawn, [K]'s circles are 1.01 and 0.69 m across against 0.91 and 0.61), so `tests/warthog.gd` checks the
## tyres against the ground rather than the height against itself.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT (the user, 2026-09-17: "a somewhat lower poly look", the Hawkeye the
## reference). The FUSELAGE is 14 facets a ring, against the Hawkeye's 20; the NACELLES 12; a GEAR POD 8; a TYRE 8; a
## GUN BARREL 6. A wing section is seven points. The fins, tailplane, pylons and doors are flat slabs. Every face carries
## its own normal; nothing is smoothed.

## [WP] The published envelope, held by `tests/warthog.gd`.
const LENGTH: float = 16.26
const SPAN: float = 17.53
const HEIGHT: float = 4.47

## THE SIMULATION'S SHAPE IS THE KIND'S, WARTHOG (`cockpit_world.cpp`, `warthog_shape`): the box is the fuselage's 0.69 m
## half-width with a margin, the ground to the canopy's top, and the muzzle to the tail cone; the span is [WP]'s. It was
## a draft here until the kind arrived, and the draft is gone.

## THE FIN TIP over the belly datum [K side view, 3.063 m], and the ground under the datum that puts it at HEIGHT.
const FIN_TIP: float = 3.06
const CLEARANCE: float = HEIGHT - FIN_TIP

## THE PAINT: the A-10C's two greys, FS 36118 on top and a lighter grey under it (ESTIMATE, sRGB approximations). No
## markings: a model here carries no livery.
const TOP := Color(0.31, 0.33, 0.34)
const LOWER := Color(0.38, 0.40, 0.41)
const GLASS := Color(0.36, 0.40, 0.42)
const BLACK := Color(0.04, 0.04, 0.045)
const METAL := Color(0.24, 0.24, 0.25)
const GUNMETAL := Color(0.16, 0.16, 0.17)
const WELL := Color(0.80, 0.81, 0.82)
const GEAR_WHITE := Color(0.86, 0.87, 0.86)
const TYRE_BLACK := Color(0.06, 0.06, 0.06)

## THE FUSELAGE, as three profiles along it [K], and the canopy's sill.
## - TOP is the side view's upper silhouette (measure_views.py prints it every 0.25 m); over the canopy it is the glass.
##   From 9.75 to 12.75 the engine nacelles hide the fuselage's top in the side view, and it is carried down between
##   the two stations either side, 1.63 and 1.41 m: an interpolation, not a measurement.
## - BOTTOM is the side view's lower silhouette, without the nose gear's fairing (2.5 to 3.0) and the gear pods, which
##   are parts of their own. The belly is flat at the datum under the wing.
## - HALF_W is the plan's half-width: 0.69 m from the cockpit to the wing. Aft of the wing the nacelles hide it in plan
##   too, and it is carried from 0.69 at 9.75 to the tail cone's 0.52 at 13.25.
const TOP_PROFILE: Array = [[0.22, 0.60], [0.30, 0.72], [0.50, 0.93], [0.75, 1.02], [1.00, 1.12], [1.25, 1.21],
	[1.50, 1.31], [1.75, 1.48], [2.00, 1.67], [2.25, 1.87], [2.50, 2.07], [2.75, 2.24], [3.00, 2.27], [3.25, 2.27],
	[3.50, 2.25], [3.75, 2.22], [4.00, 2.17], [4.25, 2.10], [4.50, 2.03], [4.75, 1.95], [5.00, 1.88], [5.50, 1.85],
	[6.00, 1.84], [7.00, 1.80], [8.00, 1.71], [9.00, 1.65], [9.50, 1.63], [11.0, 1.54], [12.5, 1.46], [13.25, 1.41],
	[13.75, 1.38], [14.50, 1.33], [15.25, 1.24], [15.75, 1.16], [16.05, 1.07]]
const BOTTOM_PROFILE: Array = [[0.22, 0.12], [0.30, 0.07], [0.50, 0.05], [0.75, 0.06], [1.00, 0.03], [1.50, 0.02],
	[2.25, 0.04], [3.25, 0.04], [4.50, 0.06], [5.50, 0.07], [5.75, 0.02], [6.50, 0.0], [9.25, 0.0], [9.50, 0.21],
	[10.0, 0.23], [11.0, 0.28], [12.0, 0.33], [13.0, 0.38], [13.75, 0.41], [14.50, 0.45], [15.25, 0.52],
	[15.75, 0.58], [16.05, 0.67]]
const HALF_W_PROFILE: Array = [[0.22, 0.14], [0.30, 0.24], [0.50, 0.37], [0.75, 0.47], [1.00, 0.54], [1.25, 0.59],
	[1.50, 0.63], [1.75, 0.66], [2.00, 0.68], [2.25, 0.69], [9.75, 0.69], [11.5, 0.62], [13.25, 0.52], [14.00, 0.48],
	[15.00, 0.42], [15.75, 0.33], [16.05, 0.24]]
## THE RINGS THE FUSELAGE IS LOFTED THROUGH, stations.
const RINGS: Array = [0.22, 0.30, 0.50, 0.75, 1.00, 1.25, 1.50, 1.64, 1.75, 2.00, 2.25, 2.50, 2.75, 2.90, 3.00, 3.25,
	3.50, 3.80, 4.00, 4.25, 4.50, 4.80, 5.00, 5.50, 6.00, 7.00, 8.00, 9.00, 9.50, 9.75, 11.0, 12.5, 13.25, 13.75, 14.50,
	15.25, 15.75, 16.05]
const FUSELAGE_SIDES: int = 14
## THE NOSE TIP [K side view]: 0.17 m aft of the muzzle, 0.38 m up. The tail cone closes at 16.20, [K]'s aft end.
const NOSE_TIP: Vector2 = Vector2(0.17, 0.38)
const TAIL_END: Vector2 = Vector2(16.20, 0.87)

## THE CANOPY [K]: the windscreen's foot at 1.64 (plan and side), the windscreen frame at 2.90, the bubble's aft point
## at 4.80. Its SILL as [station, half-width, height]: the plan's glazing is 0.47 m either side at its widest, 2.90 to
## 3.80; the sill heights are [K]'s frame line in the side view, 1.30 at the windscreen rising to 1.80 at the tail of the
## bubble.
const CANOPY: Vector2 = Vector2(1.64, 4.80)
const SILL: Array = [[1.64, 0.28, 1.30], [2.00, 0.38, 1.34], [2.50, 0.44, 1.38], [2.90, 0.47, 1.42], [3.80, 0.47, 1.50],
	[4.40, 0.40, 1.62], [4.80, 0.30, 1.80]]

## THE GAU-8/A [K, GAU]: the muzzles at station 0, [K]'s foremost point; the cluster 0.17 m across in plan (-0.18 to
## -0.01 m out) and centred 0.21 m up in the side view. SEVEN BARRELS round a 0.075 m circle, the cluster's axis 0.075 m
## to port, so the starboard barrel -- the one in the firing position -- is on the centreline. The whole gun points
## `GUN_DEPRESSION` below the line of flight [GAU]. The barrels run aft into the nose to 0.75 (ESTIMATE, where the
## muzzle clamp's shroud meets the skin in photographs).
const GUN_H: float = 0.21
const GUN_BARRELS: int = 7
const GUN_CIRCLE: float = 0.075
const GUN_BARREL_R: float = 0.024
const GUN_LENGTH: float = 0.75
const GUN_DEPRESSION: float = deg_to_rad(2.0)
## HOW MANY BARREL PASSES A SECOND THE CLUSTER IS DRAWN TURNING AT WHILE IT FIRES: one barrel a round, 3,900 rounds a
## minute is 65 passes a second, which on a 90 Hz headset aliases into a cluster that stands still or runs backwards. So
## it is drawn at 9 passes a second, a blur that reads as turning (ESTIMATE, for the look, as the F-35's lift fan).
const GUN_PASSES: float = 9.0
## How fast the drawn cluster comes up to speed and runs down: the real one takes about half a second to spin up.
const GUN_SPIN_UP: float = 0.5

## THE WING, THE A-10'S OWN STRUCTURE: A CONSTANT-CHORD CENTRE SECTION, FLAT, AND TAPERED OUTER PANELS WITH DIHEDRAL
## BOLTED ON OUTBOARD OF THE GEAR PODS, ENDING IN DROOPED HOERNER TIPS. All of it [K], by measure_views.py:
## - THE CENTRE SECTION runs from the root to `WING_BREAK`, 2.95 m out, just outboard of the pods: its leading edge is
##   station 6.84 on all 30 plan rows from 0.8 to 2.2 m out and its trailing edge 9.90 to 9.94 (median 9.90) on the rows from 2.4
##   to 3.0, so its chord is a CONSTANT 3.06 m. It is FLAT: the front view's rows from 1.8 to 2.8 m out all read 0.18 to
##   0.87 m up.
## - THE OUTER PANELS, fitted over 250 rows each side from 3.2 to 8.2 m out: the LEADING EDGE is station 6.598 + 0.1056
##   x out (16 mm rms), the TRAILING EDGE 10.097 - 0.0653 x out (7 mm rms), a taper from 2.99 m of chord at the break to
##   2.10 at 8.2 m out. THE DIHEDRAL: the middle surface rises 0.114 m a metre outboard of the break, 6.5 degrees, to
##   the front view's 0.89 / 1.28 at 8.2 m out.
## - THE TIPS DROOP: the front view's 8.4 m row is 0.92 to 1.30 and the 8.6 m row 0.88 to 1.18, so the tip's middle
##   falls to 0.93 m, its lower edge to the drawing's 0.88; in plan the tip rounds from 8.39 m out at station 7.5 to the
##   full 8.765 at 8.5.
## - THE AREA, integrated row by row over the drawn planform with the centre section's chord carried to the centreline:
##   measure_views.py prints it against [WP]'s printed 47.0 m2, and `tests/warthog.gd` integrates the model's.
## - THE THICKNESS IS [WP]'s NACA 6716 at the root and 6713 at the tip, 16 and 13 per cent: THICK, and the A-10's. The
##   front view reads the centre section 0.69 m deep, 22 per cent of its chord, but that depth is the section and its
##   incidence and the flap tracks under it together, seen end on; the drawing cannot give a thickness alone, so the
##   published sections are what the model is built to.
const WING_LE: Vector2 = Vector2(6.598, 0.1056)
const WING_TE: Vector2 = Vector2(10.097, -0.0653)
const CENTRE_CHORD: Vector2 = Vector2(6.84, 9.90)   # the centre section's leading and trailing stations, constant
const WING_ROOT: float = 0.60
const WING_BREAK: float = 2.95
const WING_OUTER: float = 8.20
const WING_TIP: float = 8.765
const WING_MID: Vector3 = Vector3(0.515, 0.114, 0.93)    # the centre section's middle, its rise a metre, the tip's
const WING_THICK: Vector3 = Vector3(0.16, 0.13, 0.10)    # thickness as a share of chord: root, 8.2 m out, the tip
const TIP_CHORD: Vector2 = Vector2(8.40, 9.52)          # the tip's leading and trailing stations
## THE LEADING-EDGE SLATS, on the inner end of each outer panel, where the A-10 has them to keep the airflow on the
## wing ahead of the engines at high angles of attack: 3.05 to 4.70 m out and 14 per cent of the chord deep. ESTIMATE
## from photographs; [K] draws the panel's leading edge as a double line along its length and does not say where the
## slat ends. Drawn retracted, as a part of their own with a seam.
const SLAT: Vector3 = Vector3(3.05, 4.70, 0.14)
## THE HINGED SURFACES [K plan's panel lines]: one hinge line at station 8.70 all along the span, unswept. The aileron
## from 5.08 to 7.98 m out; the outer flap 2.90 to 4.95; the inner flap 0.75 to 2.80 behind the nacelles. [out_in,
## out_out].
const HINGE_STATION: float = 8.70
const AILERON: Vector2 = Vector2(5.08, 7.98)
const FLAP_OUTER: Vector2 = Vector2(2.90, 4.95)
const FLAP_INNER: Vector2 = Vector2(0.75, 2.80)
## TRAVELS, ESTIMATE: the ailerons 25 degrees each way; each deceleron half 40 degrees open, 80 in all, the speed brake
## wide open; the flaps' three positions (up, manoeuvre, down) at 0, 7 and 20 degrees, so `set_flaps(1)` is 20.
const AILERON_TRAVEL: float = deg_to_rad(25.0)
const DECELERON_OPEN: float = deg_to_rad(40.0)
const FLAP_TRAVEL: float = deg_to_rad(20.0)

## THE NACELLES [K]: the fan faces' circles in the front view are centred 1.47 m out and 1.63 m up, 0.76 m in radius;
## the plan's outer edge is 2.20 m out from 10.0 to 12.25, and the side view's top 2.39 at 10.0. The intake lip at 9.62,
## the exhaust at 13.05. Rows [station, radius].
const NACELLE: Vector2 = Vector2(1.47, 1.63)
const NACELLE_RINGS: Array = [[9.62, 0.70], [9.85, 0.76], [10.80, 0.74], [11.80, 0.72], [12.50, 0.66], [12.75, 0.56],
	[12.95, 0.36], [13.05, 0.25]]
const NACELLE_SIDES: int = 12
## THE PYLON each nacelle hangs from, on the upper rear fuselage, ESTIMATE from [K]'s plan and photographs.
const NACELLE_PYLON: Vector2 = Vector2(10.10, 12.40)

## THE TAILPLANE [K]: straight, 14.12 to the hinge at 15.15, 0.62 m up (the side view's edge-on tailplane), to 2.98 m
## out; the ELEVATORS from 0.38 to 2.70 m out, their trailing edge at 15.85 (15.75 at the tip). Travel ESTIMATE.
const TAIL_H: float = 0.62
const TAIL: Vector3 = Vector3(14.12, 15.15, 2.98)    # leading edge, hinge, half-span
const ELEVATOR: Vector3 = Vector3(0.38, 2.70, 15.85)  # inner, outer, trailing edge
const ELEVATOR_TRAVEL: float = deg_to_rad(25.0)
## THE FINS [K], on the tailplane's tips 2.84 m out, 0.16 m thick (the plan's 2.75 to 2.93), outlines [station, height]
## off the side view (measure_views.py's hand picks): the leading edge straight from (13.79, 0.43) to (14.19, 2.88), the
## top 3.05, the rudder's hinge from (15.09, 3.03) to (15.31, 0.33), its trailing edge (15.51, 3.00) to (15.94, 0.48),
## the fin's foot 0.03 m up under the tailplane at 14.21. The rudder stands 2 cm aft of the hinge line.
const FIN_OUT: float = 2.84
const FIN: Array = [[13.79, 0.43], [14.19, 2.88], [14.45, 3.05], [15.07, 3.05], [15.29, 0.33], [14.60, 0.13],
	[14.21, 0.03], [13.88, 0.18]]
const RUDDER: Array = [[15.11, 3.03], [15.51, 3.00], [15.94, 0.48], [15.33, 0.33]]
const RUDDER_TRAVEL: float = deg_to_rad(25.0)

## THE MAIN GEAR PODS [K], ahead of and under the wing: 2.25 to 2.91 m out in plan, their noses at 5.86, the bottom
## -0.24 in the side view; rows [station, half-width, bottom, top] round a 2.58 m line. 8 facets a ring.
const POD_OUT: float = 2.58
const POD: Array = [[5.86, 0.02, 0.10, 0.14], [6.10, 0.22, -0.10, 0.36], [6.50, 0.32, -0.24, 0.46], [7.30, 0.33, -0.24,
	0.46], [8.10, 0.28, -0.12, 0.40], [8.80, 0.12, 0.08, 0.32], [9.00, 0.02, 0.18, 0.22]]

## THE GEAR. Tyres ESTIMATE, the A-10's 36 x 11 mains and 24 x 7.7 nose (0.91 and 0.61 m); the axles down are [K]'s
## wheel circles' stations, 8.21 and 3.06, with each tyre's bottom on the ground. Each leg is [pivot, axle down, axle
## stowed] as (out, height, station); the axle's height down is worked out from the tyre, not typed.
## - THE MAINS fold FORWARD through 90 degrees into their pods, the stowed wheel [K]'s bulge under the pod at 6.72, its
##   bottom 0.56 m under the datum and so half out of the pod. The pivot is where the two axles are equally far.
## - THE NOSE LEG is 0.40 m to starboard (the plan's nose fairing stands 0.78 m out against 0.69 either side) and folds
##   forward through 90 degrees into a well from 1.35 to 3.35.
const MAIN_TYRE: Vector2 = Vector2(0.914, 0.28)   # across, wide
const NOSE_TYRE: Vector2 = Vector2(0.61, 0.20)
const MAIN_LEG: Array = [Vector3(POD_OUT, 0.20, 7.88), Vector3(POD_OUT, 0.0, 8.21), Vector3(POD_OUT, -0.10, 6.72)]
const NOSE_OUT: float = 0.40
const NOSE_LEG: Array = [Vector3(NOSE_OUT, 0.50, 3.25), Vector3(NOSE_OUT, 0.0, 3.06), Vector3(NOSE_OUT, 0.69, 1.65)]
const WHEEL_SIDES: int = 8
## THE NOSE WELL'S DOORS, 1.35 to 2.95 either side of the nose leg, 0.18 and 0.62 m out, hinged on their outer edges.
## They STOP SHORT of 3.35, where the leg leaves the belly, since a door that shuts after the gear is down cannot shut
## across the leg (lane/lightning); the leg's own door, on its back, covers the rest when the gear is up.
const NOSE_WELL: Vector4 = Vector4(1.35, 2.95, 0.18, 0.62)   # fore, aft, inner, outer
const WELL_OPEN: float = deg_to_rad(85.0)
const DOOR_DROP: float = 0.03
## THE GEAR CYCLE AS SHARES OF ONE AMOUNT, 0 up and 1 down, lane/lightning's: doors over the first fifth, legs over the
## middle three, doors over the last. Read backwards the same function retracts in the same order.
const DOORS_OPEN_BY: float = 0.2
const DOORS_SHUT_FROM: float = 0.8
## HOW LONG A WHOLE GEAR CYCLE IS DRAWN TAKING, seconds. ESTIMATE, the F-35B's; the user's word on actuators is that the
## time "isn't important right now, we just need to be able to adjust it" (2026-09-17).
const GEAR_SECONDS: float = 6.0
## How long the drawn speed brake takes to open fully, seconds: ESTIMATE.
const SPEEDBRAKE_SECONDS: float = 1.5

## THE ELEVEN HARDPOINTS [K front view]: the stubs under the wing 1.6, 3.6, 4.8 and 5.9 m out each side, and three under
## the belly, on the centreline and 0.6 m out. Drawn as plain pylons, 0.16 m deep, 7.40 to 8.60 along (ESTIMATE).
const WING_PYLONS: Array = [1.6, 3.6, 4.8, 5.9]
const BELLY_PYLONS: Array = [0.0, 0.6]
const PYLON: Vector3 = Vector3(7.40, 8.60, 0.16)   # fore, aft, depth

## THE COCKPIT. ESTIMATE: the eye 0.32 m under the bubble's top at station 3.30, over [K]'s cockpit; the station puts the
## eye `CockpitStation.EYE_HEIGHT` over the seat. The ROOM is the largest box promised inside the drawn skin there, held
## to the triangles by `tests/warthog.gd`.
const EYE: Vector2 = Vector2(3.30, 1.95)   # station, height
## THE COAMING: the instrument panel at station 2.50, a ring station so its edge is the lofted skin's, 0.80 m ahead of the
## eye and clear of the station's front bar, and the glare shield's deck across between the canopy's sills from there
## forward to the windscreen's foot. WHY: the canopy is the fuselage's second surface, one closed solid with the nose,
## so below the glass's foot the eye looked straight into the hollow nose, its inner skin and the gun inside it (team-lead
## off the pilot's-eye picture, 2026-09-19). A real A-10 has its panel and glare shield there. ESTIMATE, the station.
const PANEL: float = 2.50
const COAMING := Color(0.10, 0.11, 0.12)
const ROOM: AABB = AABB(Vector3(-0.32, 0.64, 2.80), Vector3(0.64, 1.16, 1.10))

## Small fittings stop drawing once the aeroplane is a few pixels high.
const DETAIL_RANGE: float = 700.0
const DETAIL_HYSTERESIS: float = 70.0

var _half: Vector3 = Vector3.ONE
var _span: float = 1.0
var _hinges: Dictionary = {}
var _gear: float = 1.0
var _pitch: float = 0.0
var _roll: float = 0.0
var _yaw: float = 0.0
var _flaps: float = 0.0
var _brake: float = 0.0
var _gun: float = 0.0
var _legs: Array[Node3D] = []
var _stowed: Array[Quaternion] = []


## BUILT IN PLACE, after `new()`, from the simulation's geometry: the view's, or the draft until the kind exists.
func dress(geometry: Dictionary = {}) -> void:
	name = "Warthog"
	var native: Dictionary = geometry if geometry.has("extents") else Sim.geometry_of(Sim.Kind.WARTHOG)
	_half = native["extents"] as Vector3
	_span = float(native["span"])
	var paint: StandardMaterial3D = ShipHull.painted()
	paint.roughness = 0.7
	# THE CANOPY IS GLASS THE PILOT SEES OUT THROUGH, drawn from both sides and half see-through, as the F-35B's is.
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.vertex_color_is_srgb = true
	# 0.30, NOT THE F-35B'S 0.55: the A-10's glass is clear and grey, and at 0.45 the station picture from the seat was the
	# whole world seen through a grey film.
	glass.albedo_color = Color(1.0, 1.0, 1.0, 0.30)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.08
	glass.metallic = 0.35
	# THE SKIN SEEN FROM THE SEAT: double-sided, or from inside the one closed solid the pilot sees no aeroplane at all.
	var inside: StandardMaterial3D = ShipHull.painted()
	inside.roughness = 0.7
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED

	# THE CANOPY IS THE FUSELAGE'S SECOND SURFACE, so the skin round the pilot is one closed solid (`tests/shell_room.gd`).
	var body := _tool()
	var canopy := _tool()
	_fuselage(body, canopy)
	var fuselage := _add(self, "Fuselage", body, paint)
	fuselage.material_override = null
	fuselage.mesh = canopy.commit(fuselage.mesh as ArrayMesh)
	fuselage.set_surface_override_material(0, inside)
	fuselage.set_surface_override_material(1, glass)
	var wells := _tool()
	_wells(wells)
	_add(self, "Wells", wells, paint)
	var belly := _tool()
	for out in BELLY_PYLONS:
		for side in ([1.0] if float(out) == 0.0 else [1.0, -1.0]):
			_pylon(belly, side * float(out), 0.02)
	_add(self, "BellyPylons", belly, paint)

	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var wing := _tool()
		_wing(wing, side)
		_add(self, "Wing" + named, wing, paint)
		var slat := _tool()
		_slat(slat, side)
		_add(self, "Slat" + named, slat, paint)
		# THE PYLONS A MESH OF THEIR OWN, not the wing's: a detail drawn into someone else's mesh moves their
		# measurement (lane/jetarms), and the wing's edges and dihedral are read off its drawn vertices.
		var pylons := _tool()
		for out in WING_PYLONS:
			_pylon(pylons, side * float(out), _wing_bottom(float(out)) + 0.02)
		_add(self, "WingPylons" + named, pylons, paint)
		_aileron(side, named, paint)
		_flap("FlapInner" + named, side, FLAP_INNER, paint)
		_flap("FlapOuter" + named, side, FLAP_OUTER, paint)
		var nacelle := _tool()
		_nacelle(nacelle, side)
		_add(self, "Nacelle" + named, nacelle, paint)
		var pylon := _tool()
		_nacelle_pylon(pylon, side)
		_add(self, "NacellePylon" + named, pylon, paint)
		var pod := _tool()
		_pod(pod, side)
		_add(self, "GearPod" + named, pod, paint)
		_elevator(side, named, paint)
		_fin(side, named, paint)
	var tail := _tool()
	_tailplane(tail)
	_add(self, "Tailplane", tail, paint)
	var coaming := _tool()
	_coaming(coaming)
	var dark: StandardMaterial3D = ShipHull.painted()
	dark.roughness = 0.9
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add(self, "Coaming", coaming, dark)
	_build_gun(paint)
	_build_gear(paint)
	set_gear(1.0)


# ---- the frame ---------------------------------------------------------------------------------------------------------

## A POINT: `out` metres to starboard, at `station` aft of the muzzle and `high` over the belly datum, in the craft's
## frame. The muzzle is at the box's front face and the ground at its bottom.
func point(out: float, high: float, station: float) -> Vector3:
	return Vector3(out, -_half.y + CLEARANCE + high, -_half.z + station)


## The ground, as a height over the datum: where every tyre stands.
static func ground() -> float:
	return -CLEARANCE


static func wing_le(out: float) -> float:
	if out <= WING_BREAK:
		return CENTRE_CHORD.x
	if out > WING_OUTER:
		return lerpf(WING_LE.x + WING_LE.y * WING_OUTER, TIP_CHORD.x, (out - WING_OUTER) / (WING_TIP - WING_OUTER))
	return WING_LE.x + WING_LE.y * out


static func wing_te(out: float) -> float:
	if out <= WING_BREAK:
		return CENTRE_CHORD.y
	if out > WING_OUTER:
		return lerpf(WING_TE.x + WING_TE.y * WING_OUTER, TIP_CHORD.y, (out - WING_OUTER) / (WING_TIP - WING_OUTER))
	return WING_TE.x + WING_TE.y * out


## THE WING'S MIDDLE SURFACE's height at `out`: flat to the kink, then the dihedral, then the tip's droop.
static func wing_mid(out: float) -> float:
	var rise: float = WING_MID.x + WING_MID.y * (minf(out, WING_OUTER) - WING_BREAK)
	if out <= WING_BREAK:
		return WING_MID.x
	if out <= WING_OUTER:
		return rise
	return lerpf(rise, WING_MID.z, (out - WING_OUTER) / (WING_TIP - WING_OUTER))


## THE WING'S DEPTH at `out`, metres: the published section's share of the chord there (see `WING_THICK`).
static func wing_thick(out: float) -> float:
	var chord: float = wing_te(out) - wing_le(out)
	if out <= WING_BREAK:
		return WING_THICK.x * chord
	if out <= WING_OUTER:
		return lerpf(WING_THICK.x, WING_THICK.y, (out - WING_BREAK) / (WING_OUTER - WING_BREAK)) * chord
	return lerpf(WING_THICK.y, WING_THICK.z, (out - WING_OUTER) / (WING_TIP - WING_OUTER)) * chord


static func _wing_bottom(out: float) -> float:
	return wing_mid(out) - wing_thick(out) * 0.5


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
		"source": "the eye under [K]'s canopy, the seat EYE_HEIGHT under it; the room MEASURED against the drawn skin",
	}


## THE PILOT'S EYE, craft-local.
func eye() -> Vector3:
	return point(0.0, EYE.y, EYE.x)


## The seat under that eye, as a height over the datum.
static func seat_height() -> float:
	return EYE.y - CockpitStation.EYE_HEIGHT


## WHETHER A BOX, craft-local, IS INSIDE THE DRAWN FUSELAGE, the canopy counted in: every corner no further out than the
## skin at its station and height, a centimetre kept for the skin. Asked by `VehicleView.holster_fits`, so the signal
## lamp is holstered under the glass rather than stood up out through it: the first spot, found for a cockpit 0.69 m
## either side, put the lamp's top corner 1.40 m up and 0.36 m out at the hip, where the bubble is 0.47 wide at its sill
## and narrows above it (`tests/signal_lamp.gd`, 2026-09-19).
func encloses(box: AABB) -> bool:
	for corner in range(8):
		var p: Vector3 = box.get_endpoint(corner)
		var s: float = p.z + _half.z
		if s < float(RINGS[0]) or s > float(RINGS[-1]):
			return false
		if absf(p.x) > skin_out_at(s, p.y + _half.y - CLEARANCE, p.x < 0.0) - 0.01:
			return false
	return true


## THE SKIN'S HALF-WIDTH at station `s` and `high` over the datum, on the `port` side or starboard, off the very triangles
## `_fuselage` draws between the rings either side; 0 above or below it. THE TRIANGLES AND NOT THE TWO RINGS BLENDED: a
## quad between two rings is not flat where the canopy's sill narrows, `_fuselage` cuts it corner to corner, and the cut
## runs the other way on the port side, where the ring is walked back up. Blended, one 5 cm box of 1,693 at the bubble's
## tail, port side, had a corner outside the drawn glass (`tests/warthog.gd`, 2026-09-19).
static func skin_out_at(s: float, high: float, port: bool = false) -> float:
	var i: int = 0
	while i < RINGS.size() - 2 and s > float(RINGS[i + 1]):
		i += 1
	var fore: Array = half_section(float(RINGS[i]))
	var aft: Array = half_section(float(RINGS[i + 1]))
	var at := Vector2(s, high)
	for k in range(fore.size() - 1):
		# Each point as (station, height, out). Starboard, the quad is cut from the upper point fore to the lower aft;
		# port, from the lower point fore to the upper aft.
		var a0 := Vector3(float(RINGS[i]), (fore[k] as Vector2).y, (fore[k] as Vector2).x)
		var a1 := Vector3(float(RINGS[i]), (fore[k + 1] as Vector2).y, (fore[k + 1] as Vector2).x)
		var b0 := Vector3(float(RINGS[i + 1]), (aft[k] as Vector2).y, (aft[k] as Vector2).x)
		var b1 := Vector3(float(RINGS[i + 1]), (aft[k + 1] as Vector2).y, (aft[k + 1] as Vector2).x)
		var cut: Array = [[a1, a0, b0], [a1, b0, b1]] if port else [[a0, a1, b1], [a0, b1, b0]]
		for triangle in cut:
			var p: Vector3 = triangle[0]
			var q: Vector3 = triangle[1]
			var r: Vector3 = triangle[2]
			# A facet seen edge on from the side (the keel, flat across) covers no height and cannot be the answer.
			var area: float = (q.x - p.x) * (r.y - p.y) - (r.x - p.x) * (q.y - p.y)
			if absf(area) < 1e-9:
				continue
			var u: float = ((q.x - at.x) * (r.y - at.y) - (r.x - at.x) * (q.y - at.y)) / area
			var v: float = ((r.x - at.x) * (p.y - at.y) - (p.x - at.x) * (r.y - at.y)) / area
			var w: float = 1.0 - u - v
			if u >= -1e-6 and v >= -1e-6 and w >= -1e-6:
				return u * p.z + v * q.z + w * r.z
	return 0.0


## THE MUZZLE OF THE BARREL IN THE FIRING POSITION, craft-local: on the centreline, at station 0, `GUN_H` up. It is what
## the rounds leave from, and `tests/warthog_gun.gd` holds the simulation's rounds to it.
func gun_port() -> Vector3:
	return point(0.0, GUN_H, 0.0)


## THE DIRECTION THE GUN IS BORE-SIGHTED, craft-local: forward and `GUN_DEPRESSION` down.
static func gun_axis() -> Vector3:
	return Vector3(0.0, -sin(GUN_DEPRESSION), -cos(GUN_DEPRESSION))


# ---- what moves ---------------------------------------------------------------------------------------------------------

## THE GEAR, 0 up and 1 down, IN SEQUENCE: the nose doors open, the legs travel, the nose doors shut. The mains have no
## doors; they are in the sequence as legs.
func set_gear(amount: float) -> void:
	_gear = clampf(amount, 0.0, 1.0)
	var legs: float = legs_down(_gear)
	for index in range(_legs.size()):
		_legs[index].basis = Basis(Quaternion.IDENTITY.slerp(_stowed[index], 1.0 - legs))
	var doors: float = well_doors_open(_gear)
	_turn("NoseDoorInner", doors * WELL_OPEN)
	_turn("NoseDoorOuter", doors * WELL_OPEN)


func gear() -> float:
	return _gear


## HOW FAR DOWN THE LEGS ARE at a gear amount: still over the doors' shares, eased over the middle.
static func legs_down(amount: float) -> float:
	return smoothstep(DOORS_OPEN_BY, DOORS_SHUT_FROM, amount)


## HOW OPEN THE NOSE WELL'S DOORS ARE at a gear amount: opening over the first share, open, shutting over the last.
static func well_doors_open(amount: float) -> float:
	if amount <= DOORS_OPEN_BY:
		return smoothstep(0.0, DOORS_OPEN_BY, amount)
	if amount >= DOORS_SHUT_FROM:
		return 1.0 - smoothstep(DOORS_SHUT_FROM, 1.0, amount)
	return 1.0


## THE STICK'S AND PEDALS' SURFACES: `roll` -1 left wing down to +1 right, `pitch` -1 nose down to +1 nose up, `yaw` -1
## nose left to +1 nose right. The A-10 is not fly-by-wire: the ailerons roll it, the elevators pitch it, the rudders yaw
## it, one surface each, and nothing mixes.
func set_ailerons(roll: float) -> void:
	_roll = clampf(roll, -1.0, 1.0)
	# A positive turn is trailing edge DOWN: right roll raises the right aileron and lowers the left.
	_turn("AileronStarboard", -_roll * AILERON_TRAVEL)
	_turn("AileronPort", _roll * AILERON_TRAVEL)


func set_elevators(pitch: float) -> void:
	_pitch = clampf(pitch, -1.0, 1.0)
	# Nose up is trailing edge UP.
	_turn("ElevatorStarboard", -_pitch * ELEVATOR_TRAVEL)
	_turn("ElevatorPort", -_pitch * ELEVATOR_TRAVEL)


func set_rudders(yaw: float) -> void:
	_yaw = clampf(yaw, -1.0, 1.0)
	_turn("RudderStarboard", _yaw * RUDDER_TRAVEL)
	_turn("RudderPort", _yaw * RUDDER_TRAVEL)


## THE FLAPS, 0 up to 1 fully down (20 degrees); the manoeuvre setting's 7 degrees is 0.35.
func set_flaps(amount: float) -> void:
	_flaps = clampf(amount, 0.0, 1.0)
	for named in ["FlapInnerStarboard", "FlapInnerPort", "FlapOuterStarboard", "FlapOuterPort"]:
		_turn(named, _flaps * FLAP_TRAVEL)


## THE SPEED BRAKE, 0 shut to 1 fully open: each aileron's upper half turns up and its lower half down, about the
## aileron's own hinge, WHEREVER the aileron stands -- the halves are hinged inside the aileron, so a roll and the brake
## add, as on the real decelerons.
func set_speedbrake(amount: float) -> void:
	_brake = clampf(amount, 0.0, 1.0)
	for named in ["Starboard", "Port"]:
		_turn("DeceleronUpper" + named, -_brake * DECELERON_OPEN)
		_turn("DeceleronLower" + named, _brake * DECELERON_OPEN)


## THE GUN'S BARRELS, `phase` 0 to 1 is one barrel's pitch -- a seventh of a turn -- which is the whole of a turn as far
## as seven identical barrels can show, so a VAT bakes it in one barrel's worth of rows and the view hands it the phase.
func set_gun(phase: float) -> void:
	_gun = fposmod(phase, 1.0)
	var spin := _hinges.get("GunSpin") as Node3D
	if spin != null:
		spin.basis = Basis(Vector3.BACK, _gun * TAU / float(GUN_BARRELS))


func stick_roll() -> float:
	return _roll


func stick_pitch() -> float:
	return _pitch


func stick_yaw() -> float:
	return _yaw


func flaps() -> float:
	return _flaps


func speedbrake() -> float:
	return _brake


func gun() -> float:
	return _gun


## THE FEATURES A VAT BAKES (`VatCasting`), each this airframe's own setter and getter. The deceleron halves ride the
## roll (outer) and the speed brake (inner); the gun is one barrel's pitch.
func features() -> Array:
	return [
		{"name": "gear", "set": set_gear, "get": gear, "low": 0.0, "high": 1.0},
		{"name": "pitch", "set": set_elevators, "get": stick_pitch, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "roll", "set": set_ailerons, "get": stick_roll, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "rudder", "set": set_rudders, "get": stick_yaw, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "flaps", "set": set_flaps, "get": flaps, "low": 0.0, "high": 1.0, "samples": 33},
		{"name": "speedbrake", "set": set_speedbrake, "get": speedbrake, "low": 0.0, "high": 1.0, "samples": 33},
		{"name": "gun", "set": set_gun, "get": gun, "low": 0.0, "high": 1.0, "samples": 17},
	]


## A HINGE turned `angle` radians from where it was built, about the axis stored on it when it was built.
func _turn(named: String, angle: float) -> void:
	var hinge: Node3D = _hinges.get(named) as Node3D
	if hinge != null:
		hinge.basis = Basis(hinge.get_meta("axis") as Vector3, angle)


## A HINGE at `at` (in `parent`'s frame), turning about `along`, wound so a small positive turn carries `probe` towards
## `wanted` (a direction): the Tomcat's way, so the builder never reasons about which way a mirrored hinge turns.
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


static func _add(parent: Node3D, title: String, tool: SurfaceTool, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = material
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


## ONE PROFILE, [[station, value], ...], read at `s` by straight lines between its rows.
static func _profile(rows: Array, s: float) -> float:
	for i in range(rows.size() - 1):
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		if s <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((s - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))
	return float(rows[-1][1])


static func top_at(s: float) -> float:
	return _profile(TOP_PROFILE, s)


static func bottom_at(s: float) -> float:
	return _profile(BOTTOM_PROFILE, s)


static func half_width_at(s: float) -> float:
	return _profile(HALF_W_PROFILE, s)


## THE CANOPY'S SILL at a station, (half-width, height).
static func sill_at(s: float) -> Vector2:
	for i in range(SILL.size() - 1):
		var a: Array = SILL[i]
		var b: Array = SILL[i + 1]
		if s <= float(b[0]):
			var t: float = clampf((s - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return Vector2(lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t))
	return Vector2(float(SILL[-1][1]), float(SILL[-1][2]))


## ONE RING's half-section, (half-width, height) pairs from the top centreline down to the keel: top, crown, sill,
## shoulder, side, under, keel and the bottom centre. OVER THE CANOPY the sill is the glass's lower edge and the crown
## sits on the glass, and between the sill and the shoulder is the flat deck the canopy stands on: the windscreen's foot
## is 0.28 m either side in plan where the fuselage is 0.66, and without the deck the glass's steep side ran down to the
## fuselage's side and the nose wheel's well came out through it. Elsewhere the sill is a point on the upper side.
static func half_section(s: float) -> Array:
	var top: float = top_at(s)
	var bottom: float = bottom_at(s)
	var w: float = half_width_at(s)
	var h: float = top - bottom
	var crown := Vector2(0.55 * w, top - 0.08 * h)
	var sill := Vector2(0.80 * w, top - 0.16 * h)
	var shoulder := Vector2(0.95 * w, top - 0.26 * h)
	var side := Vector2(w, bottom + 0.45 * h)
	if s >= CANOPY.x - 0.001 and s <= CANOPY.y + 0.001:
		var glass: Vector2 = sill_at(s)
		sill = Vector2(minf(glass.x, 0.9 * w), glass.y)
		crown = Vector2(0.55 * sill.x, top - 0.25 * (top - sill.y))
		shoulder = Vector2(maxf(0.92 * w, sill.x + 0.03), sill.y - 0.06)
		side = Vector2(w, minf(bottom + 0.45 * h, shoulder.y - 0.25))
	return [Vector2(0.0, top), crown, sill, shoulder, side, Vector2(0.88 * w, bottom + 0.08 * h), Vector2(0.45 * w, bottom),
		Vector2(0.0, bottom)]


## ONE RING's points round from the top centreline, starboard down to the keel and port back up: 14 points, 14 facets.
func _ring(s: float) -> Array:
	var half: Array = half_section(s)
	var points: Array = []
	for i in range(half.size() - 1):
		points.append(point((half[i] as Vector2).x, (half[i] as Vector2).y, s))
	for i in range(half.size() - 1, 0, -1):
		points.append(point(-(half[i] as Vector2).x, (half[i] as Vector2).y, s))
	return points


## THE FUSELAGE: 14 flat facets a ring through `RINGS`. Over the canopy the two upper facets each side are GLASS and go
## into `canopy`. Upward-facing panels take the darker top grey.
func _fuselage(tool: SurfaceTool, canopy: SurfaceTool) -> void:
	var rings: Array = []
	for s in RINGS:
		rings.append(_ring(float(s)))
	var n: int = FUSELAGE_SIDES
	for r in range(rings.size() - 1):
		var here: float = (float(RINGS[r]) + float(RINGS[r + 1])) * 0.5
		var glazed: bool = here > CANOPY.x and here < CANOPY.y
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var centre: Vector3 = point(0.0, (top_at(here) + bottom_at(here)) * 0.5, here)
		for k in range(n):
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			var out: Vector3 = Vector3(mid.x - centre.x, mid.y - centre.y, 0.0)
			# Facets 0 and 1 are the starboard spine and crown, 12 and 13 the port ones.
			var upper: bool = k <= 1 or k >= n - 2
			# EACH QUAD AS TWO TRIANGLES, each wound out on its own: where the canopy's deck starts and ends a ring's
			# quad is not flat, and one normal for both halves wound one of them inwards (`tests/warthog.gd`, 2 faces).
			if glazed and upper:
				_fan(canopy, quad[0], quad[1], quad[2], out, GLASS)
				_fan(canopy, quad[0], quad[2], quad[3], out, GLASS)
				continue
			var normal: Vector3 = ((quad[2] as Vector3) - (quad[0] as Vector3)).cross(
				(quad[1] as Vector3) - (quad[0] as Vector3)).normalized()
			if normal.dot(out) < 0.0:
				normal = -normal
			var tint: Color = TOP if normal.y > 0.5 else LOWER
			_fan(tool, quad[0], quad[1], quad[2], out, tint)
			_fan(tool, quad[0], quad[2], quad[3], out, tint)
	# THE NOSE: a fan from the first ring to the nose tip. THE TAIL: a fan to the tail cone's point.
	var tip: Vector3 = point(0.0, NOSE_TIP.y, NOSE_TIP.x)
	var first: Array = rings[0]
	for k in range(n):
		_fan(tool, tip, first[k], first[(k + 1) % n], Vector3.FORWARD, TOP if k <= 2 or k >= n - 3 else LOWER)
	var last: Array = rings[rings.size() - 1]
	var end: Vector3 = point(0.0, TAIL_END.y, TAIL_END.x)
	for k in range(n):
		_fan(tool, end, last[k], last[(k + 1) % n], Vector3.BACK, LOWER)


## THE COAMING (`PANEL`): the glare shield's deck, a strip between the port and starboard sill points of each ring from
## the windscreen's foot to the panel, facing up to the pilot; and the panel, the ring's section at `PANEL` from one sill
## down round the keel to the other, closed across the top, facing aft; and the lip at the windscreen's foot. A PART OF ITS OWN: inside the fuselage's one
## closed solid, and a point is inside that by ray parity.
func _coaming(tool: SurfaceTool) -> void:
	var stations: Array = []
	for s in RINGS:
		if float(s) >= CANOPY.x - 0.001 and float(s) <= PANEL + 0.001:
			stations.append(float(s))
	for i in range(stations.size() - 1):
		var a: Vector2 = half_section(stations[i])[2]
		var b: Vector2 = half_section(stations[i + 1])[2]
		var quad: Array = [point(-a.x, a.y, stations[i]), point(a.x, a.y, stations[i]), point(b.x, b.y, stations[i + 1]),
			point(-b.x, b.y, stations[i + 1])]
		_fan(tool, quad[0], quad[1], quad[2], Vector3.UP, COAMING)
		_fan(tool, quad[0], quad[2], quad[3], Vector3.UP, COAMING)
	var half: Array = half_section(PANEL)
	var outline: Array = []
	for i in range(2, half.size()):
		outline.append(point((half[i] as Vector2).x, (half[i] as Vector2).y, PANEL))
	for i in range(half.size() - 2, 1, -1):
		outline.append(point(-(half[i] as Vector2).x, (half[i] as Vector2).y, PANEL))
	var middle: Vector3 = point(0.0, ((half[2] as Vector2).y + (half[-1] as Vector2).y) * 0.5, PANEL)
	for i in range(outline.size()):
		_fan(tool, middle, outline[i], outline[(i + 1) % outline.size()], Vector3.BACK, COAMING)
	# AND ITS FRONT LIP, the ring's section above the sills at the windscreen's foot: the glass meets the nose's top there,
	# and a ray from the eye 20 degrees down passed over the deck's front edge and under that top into the nose.
	var foot: Array = half_section(CANOPY.x)
	var lip: Array = [point((foot[2] as Vector2).x, (foot[2] as Vector2).y, CANOPY.x),
		point((foot[1] as Vector2).x, (foot[1] as Vector2).y, CANOPY.x), point(0.0, (foot[0] as Vector2).y, CANOPY.x),
		point(-(foot[1] as Vector2).x, (foot[1] as Vector2).y, CANOPY.x),
		point(-(foot[2] as Vector2).x, (foot[2] as Vector2).y, CANOPY.x)]
	var lip_middle: Vector3 = point(0.0, ((foot[0] as Vector2).y + (foot[2] as Vector2).y) * 0.5, CANOPY.x)
	for i in range(lip.size()):
		_fan(tool, lip_middle, lip[i], lip[(i + 1) % lip.size()], Vector3.BACK, COAMING)


## THE NOSE WELL, a white patch 1 cm inside the belly, hidden by its doors until they open. A PART OF ITS OWN, not the
## fuselage's: the skin is one closed solid and a point is inside it by ray parity, and a patch in the same mesh is one
## more crossing (lane/lightning).
func _wells(tool: SurfaceTool) -> void:
	var corners: Array = []
	for c in [[NOSE_WELL.z, NOSE_WELL.x], [NOSE_WELL.w, NOSE_WELL.x], [NOSE_WELL.w, 3.35], [NOSE_WELL.z, 3.35]]:
		corners.append(point(float(c[0]), belly_at(float(c[1]), float(c[0])) + 0.01, float(c[1])))
	Plating.facing(tool, corners, Vector3.DOWN, WELL)


## THE SKIN'S UNDERSIDE at a station and `out` metres from the centreline: flat to the keel's edge, then rising along
## the lower facet to the under-chine. The nose well is 0.18 to 0.62 m out where the flat is 0.30 m either side, so a
## patch or a door laid flat at the keel's height stood out of the skin on its outboard side (the first pictures from
## below showed a white patch under a shut nose).
static func belly_at(s: float, out: float) -> float:
	var half: Array = half_section(s)
	var keel: Vector2 = half[6]
	var under: Vector2 = half[5]
	var a: float = absf(out)
	if a <= keel.x:
		return keel.y
	return lerpf(keel.y, under.y, clampf((a - keel.x) / (under.x - keel.x), 0.0, 1.0))


## A SEVEN-POINT WING SECTION at `out` from `le` to `end` along a chord whose full trailing edge is `te`: the leading
## edge, the upper surface at 15 and 50 per cent, the upper and lower surface at `end`, and the lower at 50 and 15. The
## section tapers from its full thickness at half chord to a 2 cm trailing edge, so a section cut at a hinge is as thick
## there as the surface hinged behind it.
func _section(out: float, le: float, te: float, end: float, side: float) -> Array:
	var c: float = te - le
	var mid: float = wing_mid(out)
	var t: float = wing_thick(out)
	var f: float = clampf((end - le) / c, 0.5, 1.0)
	var at_end: float = maxf(t * (1.0 - f), 0.01)
	return [point(side * out, mid, le), point(side * out, mid + 0.40 * t, le + 0.15 * c),
		point(side * out, mid + 0.5 * t, le + 0.5 * c), point(side * out, mid + at_end, end),
		point(side * out, mid - at_end, end), point(side * out, mid - 0.5 * t, le + 0.5 * c),
		point(side * out, mid - 0.40 * t, le + 0.15 * c)]


const _SURFACE_TINTS: Array = [TOP, TOP, TOP, LOWER, LOWER, LOWER, LOWER]


## WHERE THE FIXED WING ENDS at `out`: the hinge line where a flap or an aileron is hinged behind it, else the trailing
## edge.
static func _fixed_end(out: float) -> float:
	for span in [FLAP_INNER, FLAP_OUTER, AILERON]:
		if out >= (span as Vector2).x - 0.001 and out <= (span as Vector2).y + 0.001:
			return HINGE_STATION
	return wing_te(out)


## THE WING, one side: lofted through a section at every break -- the root inside the fuselage, each surface's ends, the
## dihedral's kink and the tip's droop -- each bay to the hinge where a surface is hinged behind it and to the trailing
## edge where none is. Each bay is its own closed loft, so a step in the chord is a closed end, not a hole.
func _wing(tool: SurfaceTool, side: float) -> void:
	# THE BREAK IS TWO SECTIONS 1 cm apart, the centre section's and the outer panel's, so the panel's own chord and
	# dihedral start at the joint and the step between them is a face, as the real joint is.
	var breaks: Array = [WING_ROOT, FLAP_INNER.x, FLAP_INNER.y, FLAP_OUTER.x, WING_BREAK, WING_BREAK + 0.01,
		SLAT.x, SLAT.y, FLAP_OUTER.y, AILERON.x, AILERON.y, WING_OUTER]
	breaks.sort()
	for i in range(breaks.size() - 1):
		var a: float = float(breaks[i])
		var b: float = float(breaks[i + 1])
		var middle: float = (a + b) * 0.5
		var hinged: bool = _fixed_end(middle) == HINGE_STATION
		var loops: Array = []
		for out in [a, b]:
			var end: float = HINGE_STATION if hinged else wing_te(float(out))
			loops.append(_section(float(out), wing_le(float(out)), wing_te(float(out)), end, side))
		_loft(tool, loops, _SURFACE_TINTS)
	# THE DROOPED TIP, from 8.2 m out to the tip, in three steps so its leading edge rounds and its middle falls.
	var tips: Array = []
	for t in [0.0, 0.45, 0.8, 1.0]:
		var out: float = lerpf(WING_OUTER, WING_TIP - 0.001, t)
		tips.append(_section(out, wing_le(out), wing_te(out), wing_te(out), side))
	_loft(tool, tips, _SURFACE_TINTS)


## A HINGED SURFACE'S PANEL between `from` and `to` metres out, `share` of its thickness from `lower` to `upper` (0 the
## middle surface, 1 the skin), hinge to trailing edge, in its hinge's frame.
func _surface_loop(side: float, out: float, lower: float, upper: float, at: Vector3) -> Array:
	var te: float = wing_te(out)
	var mid: float = wing_mid(out)
	var t: float = wing_thick(out)
	var half: float = maxf(t * (1.0 - (HINGE_STATION - wing_le(out)) / (te - wing_le(out))), 0.01)
	var low: float = mid + half * lower
	var high: float = mid + half * upper
	var tail_low: float = mid + 0.01 * lower
	var tail_high: float = mid + 0.01 * upper
	return [point(side * out, high, HINGE_STATION + 0.01) - at, point(side * out, tail_high, te) - at,
		point(side * out, tail_low, te) - at, point(side * out, low, HINGE_STATION + 0.01) - at]


## THE HINGE LINE at `out`: on the wing's middle surface at the hinge station.
func _hinge_point(side: float, out: float) -> Vector3:
	return point(side * out, wing_mid(out), HINGE_STATION)


## THE FLAP'S HINGE at `out`: UNDER the wing, on its lower surface at the hinge station, which is what makes it a
## SLOTTED flap -- turned down about its lower edge, its nose drops away from the wing's upper skin and opens the slot
## between them that the A-10's flaps have, where a flap on the middle surface would only fold.
func _flap_hinge_point(side: float, out: float) -> Vector3:
	return point(side * out, wing_mid(out) - _depth_at_hinge(out) * 0.9, HINGE_STATION)


## HALF THE WING'S DEPTH at the hinge station, `out` metres out: where a surface hinged there starts.
static func _depth_at_hinge(out: float) -> float:
	var te: float = wing_te(out)
	var le: float = wing_le(out)
	return maxf(wing_thick(out) * (1.0 - (HINGE_STATION - le) / (te - le)), 0.01)


## A FLAP, one side, SLOTTED: a wedge from the hinge to the trailing edge, hinged under the wing, turning trailing edge
## down.
func _flap(named: String, side: float, span: Vector2, paint: Material) -> void:
	var inner: Vector3 = _flap_hinge_point(side, span.x)
	var outer: Vector3 = _flap_hinge_point(side, span.y)
	var mid: Vector3 = (inner + outer) * 0.5
	var hinge := _hinge(named, self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	_loft(tool, [_surface_loop(side, span.x + 0.02, -1.0, 1.0, mid), _surface_loop(side, span.y - 0.02, -1.0, 1.0, mid)],
		[TOP, TOP, LOWER, LOWER])
	_add(hinge, named, tool, paint)


## THE AILERON, one side, AS TWO HALVES: an `Aileron` hinge the roll turns, and inside it an upper and a lower half each
## on its own hinge on the same line, which the speed brake turns apart. Each half is the aileron's section above or
## below its middle surface.
func _aileron(side: float, named: String, paint: Material) -> void:
	var inner: Vector3 = _hinge_point(side, AILERON.x)
	var outer: Vector3 = _hinge_point(side, AILERON.y)
	var mid: Vector3 = (inner + outer) * 0.5
	var roll := _hinge("Aileron" + named, self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	for half in [["DeceleronUpper", 0.0, 1.0, TOP], ["DeceleronLower", -1.0, 0.0, LOWER]]:
		var part: String = String(half[0]) + named
		var hinge := _hinge(part, roll, Vector3.ZERO, outer - inner, Vector3.BACK, Vector3.DOWN)
		var tool := _tool()
		_loft(tool, [_surface_loop(side, AILERON.x + 0.02, float(half[1]), float(half[2]), mid),
			_surface_loop(side, AILERON.y - 0.02, float(half[1]), float(half[2]), mid)], [half[3]])
		_add(hinge, part, tool, paint)


## A LEADING-EDGE SLAT, one side, retracted: a wedge laid over the wing's nose from `SLAT.x` to `SLAT.y`, 2 cm proud of
## the skin and 1.5 cm ahead of it, so its seam reads along the leading edge and at its two ends.
func _slat(tool: SurfaceTool, side: float) -> void:
	var loops: Array = []
	for out in [SLAT.x, SLAT.y]:
		var le: float = wing_le(float(out))
		var c: float = wing_te(float(out)) - le
		var mid: float = wing_mid(float(out))
		var t: float = wing_thick(float(out))
		var back: float = le + SLAT.z * c
		loops.append([point(side * float(out), mid, le - 0.015),
			point(side * float(out), mid + 0.40 * t + 0.02, back),
			point(side * float(out), mid - 0.40 * t - 0.02, back)])
	_loft(tool, loops, [TOP, LOWER, LOWER])


## A PYLON: a flat slab 0.08 m wide, `PYLON.z` deep under `top` (a height over the datum) at `out`.
func _pylon(tool: SurfaceTool, out: float, top: float) -> void:
	var fore: float = PYLON.x
	var aft: float = PYLON.y
	var low: float = top - PYLON.z - 0.02
	Plating.box(tool, point(out, (top + low) * 0.5, (fore + aft) * 0.5), Vector3(0.08, top - low, aft - fore), LOWER)


## ONE NACELLE: 12 facets a ring through the measured rings, a dark intake set 0.25 m back inside the lip with a grey fan
## face and spinner, and a dark exhaust.
func _nacelle(tool: SurfaceTool, side: float) -> void:
	var ring := func(s: float, r: float) -> Array:
		var loop: Array = []
		for k in range(NACELLE_SIDES):
			var t: float = TAU * (float(k) + 0.5) / NACELLE_SIDES
			loop.append(point(side * NACELLE.x + r * cos(t), NACELLE.y + r * sin(t), s))
		return loop
	var loops: Array = []
	for row in NACELLE_RINGS:
		loops.append(ring.call(float(row[0]), float(row[1])))
	var tints: Array = []
	for k in range(NACELLE_SIDES):
		tints.append(TOP if sin(TAU * (float(k) + 0.5) / NACELLE_SIDES) > 0.3 else LOWER)
	_loft(tool, loops, tints, false)
	# THE INTAKE: the lip's inner face going in to the fan, which is a dark disc with a grey spinner.
	var lip: Array = loops[0]
	var r0: float = float(NACELLE_RINGS[0][1])
	var throat: Array = ring.call(float(NACELLE_RINGS[0][0]) + 0.25, r0 - 0.08)
	var axis_front: Vector3 = point(side * NACELLE.x, NACELLE.y, float(NACELLE_RINGS[0][0]))
	for k in range(NACELLE_SIDES):
		var k2: int = (k + 1) % NACELLE_SIDES
		var wall: Array = [lip[k], lip[k2], throat[k2], throat[k]]
		var wmid: Vector3 = ((wall[0] as Vector3) + wall[1] + wall[2] + wall[3]) * 0.25
		Plating.facing(tool, wall, Vector3(axis_front.x - wmid.x, axis_front.y - wmid.y, 0.0), METAL)
		var fan: Vector3 = point(side * NACELLE.x, NACELLE.y, float(NACELLE_RINGS[0][0]) + 0.25)
		_fan(tool, fan, throat[k], throat[k2], Vector3.FORWARD, BLACK)
	var spinner_base: Array = ring.call(float(NACELLE_RINGS[0][0]) + 0.24, 0.22)
	var spinner_tip: Vector3 = point(side * NACELLE.x, NACELLE.y, float(NACELLE_RINGS[0][0]) + 0.02)
	for k in range(NACELLE_SIDES):
		_fan(tool, spinner_tip, spinner_base[k], spinner_base[(k + 1) % NACELLE_SIDES], Vector3.FORWARD, METAL)
	# THE EXHAUST: a dark disc closing the last ring.
	var last: Array = loops[loops.size() - 1]
	var back: Vector3 = point(side * NACELLE.x, NACELLE.y, float(NACELLE_RINGS[-1][0]) - 0.05)
	for k in range(NACELLE_SIDES):
		_fan(tool, back, last[k], last[(k + 1) % NACELLE_SIDES], Vector3.BACK, BLACK)


## THE PYLON a nacelle hangs from: a slab from the fuselage's shoulder up and out into the nacelle's lower inboard side.
func _nacelle_pylon(tool: SurfaceTool, side: float) -> void:
	var fore: float = NACELLE_PYLON.x
	var aft: float = NACELLE_PYLON.y
	var root_out: float = half_width_at((fore + aft) * 0.5) * 0.7
	var root_h: float = top_at((fore + aft) * 0.5) - 0.12
	var tip_out: float = NACELLE.x - 0.55
	var tip_h: float = NACELLE.y - 0.35
	var place := func(p: Vector2) -> Vector3:
		return point(side * lerpf(root_out, tip_out, p.x), lerpf(root_h, tip_h, p.x), p.y)
	var along: Vector3 = point(side * tip_out, tip_h, fore) - point(side * root_out, root_h, fore)
	var across: Vector3 = along.cross(Vector3.BACK).normalized()
	_slab(tool, _outline([[0.0, fore], [1.0, fore + 0.2], [1.0, aft], [0.0, aft - 0.3]]), place, across, 0.06, LOWER)


## A MAIN GEAR POD, one side: 8 facets a ring round `POD_OUT`, its top bedded in the wing's lower surface.
func _pod(tool: SurfaceTool, side: float) -> void:
	var loops: Array = []
	for row in POD:
		var s: float = float(row[0])
		var w: float = float(row[1])
		var low: float = float(row[2])
		var high: float = float(row[3])
		var loop: Array = []
		for k in range(8):
			var t: float = TAU * (float(k) + 0.5) / 8.0
			loop.append(point(side * POD_OUT + w * cos(t), (low + high) * 0.5 + (high - low) * 0.5 * sin(t), s))
		loops.append(loop)
	var tints: Array = []
	for k in range(8):
		tints.append(TOP if sin(TAU * (float(k) + 0.5) / 8.0) > 0.3 else LOWER)
	_loft(tool, loops, tints)


## THE TAILPLANE, both sides in one slab through the tail cone, from its leading edge to the elevators' hinge.
func _tailplane(tool: SurfaceTool) -> void:
	var place := func(p: Vector2) -> Vector3: return point(p.x, TAIL_H, p.y)
	_slab(tool, _outline([[-TAIL.z, TAIL.x], [TAIL.z, TAIL.x], [TAIL.z, TAIL.y + 0.40], [ELEVATOR.y + 0.01, TAIL.y + 0.40],
		[ELEVATOR.y + 0.01, TAIL.y], [-ELEVATOR.y - 0.01, TAIL.y], [-ELEVATOR.y - 0.01, TAIL.y + 0.40],
		[-TAIL.z, TAIL.y + 0.40]]), place, Vector3.UP, 0.06, TOP, LOWER)


## AN ELEVATOR, one side, on the tailplane's hinge line at 15.15.
func _elevator(side: float, named: String, paint: Material) -> void:
	var inner: Vector3 = point(side * ELEVATOR.x, TAIL_H, TAIL.y)
	var outer: Vector3 = point(side * ELEVATOR.y, TAIL_H, TAIL.y)
	var mid: Vector3 = (inner + outer) * 0.5
	# A positive turn is trailing edge DOWN.
	var hinge := _hinge("Elevator" + named, self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	var place := func(p: Vector2) -> Vector3: return point(side * p.x, TAIL_H, p.y) - mid
	_slab(tool, _outline([[ELEVATOR.x, TAIL.y + 0.01], [ELEVATOR.y, TAIL.y + 0.01], [ELEVATOR.y, ELEVATOR.z - 0.10],
		[ELEVATOR.x, ELEVATOR.z]]), place, Vector3.UP, 0.04, TOP, LOWER)
	_add(hinge, "Elevator" + named, tool, paint)


## THE FIN, one side: an upright slab of [K]'s outline at `FIN_OUT` through the tailplane's tip, and its rudder on the
## raked hinge line behind it.
func _fin(side: float, named: String, paint: Material) -> void:
	var place := func(p: Vector2) -> Vector3: return point(side * FIN_OUT, p.y, p.x)
	var tool := _tool()
	_slab(tool, _outline(FIN), place, Vector3.RIGHT, 0.08, TOP)
	_add(self, "Fin" + named, tool, paint)
	var foot: Vector3 = place.call(Vector2(float(RUDDER[3][0]), float(RUDDER[3][1])))
	var head: Vector3 = place.call(Vector2(float(RUDDER[0][0]), float(RUDDER[0][1])))
	# A positive turn swings the trailing edge to STARBOARD, for right rudder.
	var hinge := _hinge("Rudder" + named, self, foot, head - foot, foot + Vector3.BACK, Vector3.RIGHT)
	var rudder := _tool()
	var local := func(p: Vector2) -> Vector3: return (place.call(p) as Vector3) - foot
	_slab(rudder, _outline(RUDDER), local, Vector3.RIGHT, 0.06, TOP)
	_add(hinge, "Rudder" + named, rudder, paint)


## THE GAU-8: a mount at the cluster's muzzle end, turned `GUN_DEPRESSION` down, and inside it the spinning cluster of
## seven six-sided barrels and the muzzle clamp. The barrel at the cluster's starboard side at rest is the one on the
## centreline, in the firing position.
func _build_gun(paint: Material) -> void:
	var mount := Node3D.new()
	mount.name = "GunMount"
	mount.position = point(-GUN_CIRCLE, GUN_H, 0.0)
	mount.basis = Basis(Vector3.RIGHT, -GUN_DEPRESSION)
	add_child(mount)
	var spin := Node3D.new()
	spin.name = "GunSpin"
	mount.add_child(spin)
	_hinges["GunSpin"] = spin
	var tool := _tool()
	for b in range(GUN_BARRELS):
		var a: float = TAU * float(b) / float(GUN_BARRELS)
		var centre := Vector2(GUN_CIRCLE * cos(a), GUN_CIRCLE * sin(a))
		var loops: Array = []
		for z in [0.0, GUN_LENGTH]:
			var loop: Array = []
			for k in range(6):
				var t: float = TAU * (float(k) + 0.5) / 6.0
				loop.append(Vector3(centre.x + GUN_BARREL_R * cos(t), centre.y + GUN_BARREL_R * sin(t), z))
			loops.append(loop)
		_loft(tool, loops, [GUNMETAL])
		# THE BORE: a black hexagon on the muzzle face, 5 mm proud so it reads.
		var bore: Array = []
		for k in range(6):
			var t: float = TAU * (float(k) + 0.5) / 6.0
			bore.append(Vector3(centre.x + GUN_BARREL_R * 0.55 * cos(t), centre.y + GUN_BARREL_R * 0.55 * sin(t), -0.002))
		for k in range(6):
			_fan(tool, Vector3(centre.x, centre.y, -0.002), bore[k], bore[(k + 1) % 6], Vector3.FORWARD, BLACK)
	# THE MUZZLE CLAMP: an eight-sided band round the cluster, 0.06 to 0.14 m aft of the muzzles, and a second at 0.40.
	for z in [[0.06, 0.14], [0.40, 0.46]]:
		var band: Array = []
		for zz in z:
			var loop: Array = []
			for k in range(8):
				var t: float = TAU * (float(k) + 0.5) / 8.0
				var r: float = GUN_CIRCLE + GUN_BARREL_R + 0.012
				loop.append(Vector3(r * cos(t), r * sin(t), float(zz)))
			band.append(loop)
		_loft(tool, band, [METAL])
	var barrels := _add(spin, "GunBarrels", tool, paint)
	barrels.position = Vector3.ZERO


## A DOOR: a flat plate on its own hinge, painted `LOWER` on the face that faces `out` when shut and white inside.
func _door(named: String, corners: Array, hinge_a: Vector3, hinge_b: Vector3, opens_towards: Vector3, out: Vector3,
		paint: Material) -> Node3D:
	var mid: Vector3 = Vector3.ZERO
	for c in corners:
		mid += c
	mid /= float(corners.size())
	var at: Vector3 = (hinge_a + hinge_b) * 0.5
	var hinge := _hinge(named, self, at, hinge_b - hinge_a, mid, opens_towards)
	var tool := _tool()
	var thick: Vector3 = out.normalized() * 0.012
	var face: Array = []
	var back: Array = []
	for c in corners:
		face.append((c as Vector3) - at + thick)
		back.append((c as Vector3) - at - thick)
	Plating.facing(tool, face, out, LOWER)
	Plating.facing(tool, back, -out, WELL)
	for k in range(corners.size()):
		var k2: int = (k + 1) % corners.size()
		var edge_mid: Vector3 = ((face[k] as Vector3) + face[k2]) * 0.5
		Plating.facing(tool, [face[k], face[k2], back[k2], back[k]], edge_mid - (mid - at), LOWER)
	_add(hinge, named, tool, paint)
	return hinge


## THE GEAR: three legs on pivots, each built DOWN and turned up by the shortest arc from its down direction to its
## stowed one, and the nose well's two doors, hinged on their outer edges and opening down.
func _build_gear(paint: Material) -> void:
	_leg("NoseGear", NOSE_LEG, NOSE_TYRE, 1.0, paint)
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var leg: Array = []
		for p in MAIN_LEG:
			leg.append(Vector3(side * (p as Vector3).x, (p as Vector3).y, (p as Vector3).z))
		_leg("MainGear" + named, leg, MAIN_TYRE, side, paint)
	var fore: float = NOSE_WELL.x
	var aft: float = NOSE_WELL.y
	var inner: float = NOSE_WELL.z
	var outer: float = NOSE_WELL.w
	var meet: float = NOSE_OUT
	# Each corner DOOR_DROP under the skin at its own place, so a shut door lies along the lower facet it closes.
	var at := func(o: float, s: float) -> Vector3: return point(o, belly_at(s, o) - DOOR_DROP, s)
	_door("NoseDoorInner", [at.call(inner, fore), at.call(meet - 0.005, fore), at.call(meet - 0.005, aft),
		at.call(inner, aft)], at.call(inner, fore), at.call(inner, aft), Vector3.DOWN, Vector3.DOWN, paint)
	_door("NoseDoorOuter", [at.call(meet + 0.005, fore), at.call(outer, fore), at.call(outer, aft),
		at.call(meet + 0.005, aft)], at.call(outer, fore), at.call(outer, aft), Vector3.DOWN, Vector3.DOWN, paint)


## ONE LEG: a pivot at `leg[0]`, built with the axle down at `leg[1]` -- its height worked out so the tyre stands on the
## ground -- and stowed turning the axle toward `leg[2]`. A strut, a tyre across the leg's side, and on the nose leg its
## own door on the strut's back, which faces down when the leg is up and closes the well behind the doors.
func _leg(named: String, leg: Array, tyre: Vector2, side: float, paint: Material) -> void:
	var p0: Vector3 = leg[0]
	var p1: Vector3 = leg[1]
	var p2: Vector3 = leg[2]
	var pivot_at: Vector3 = point(p0.x, p0.y, p0.z)
	var axle: Vector3 = point(p1.x, ground() + tyre.x * 0.5, p1.z)
	var stowed: Vector3 = point(p2.x, p2.y, p2.z)
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
	var h: float = 0.06 if tyre.x < 0.7 else 0.09
	var loops: Array = []
	for p in [pivot_at, axle]:
		var q: Vector3 = (p as Vector3) - pivot_at
		loops.append([q + across * h + up * h, q - across * h + up * h, q - across * h - up * h, q + across * h - up * h])
	_loft(tool, loops, [GEAR_WHITE])
	# THE TYRE, an eight-sided prism whose bottom FLAT stands on the ground, turning across the aeroplane.
	var apothem: float = tyre.x * 0.5
	var corner: float = apothem / cos(PI / WHEEL_SIDES)
	var centre: Vector3 = axle - pivot_at
	var wheel: Array = []
	for w in [-tyre.y * 0.5, tyre.y * 0.5]:
		var loop: Array = []
		for k in range(WHEEL_SIDES):
			var t: float = TAU * (float(k) + 0.5) / WHEEL_SIDES
			loop.append(centre + Vector3(w, corner * cos(t), corner * sin(t)))
		wheel.append(loop)
	_loft(tool, wheel, [TYRE_BLACK])
	if named == "NoseGear":
		var top: Vector3 = along * 0.12 + Vector3(0.0, 0.0, 0.08)
		var bottom: Vector3 = along * ((axle - pivot_at).length() - apothem - 0.10) + Vector3(0.0, 0.0, 0.08)
		Plating.box(tool, (top + bottom) * 0.5, Vector3(0.22, (bottom - top).length(), 0.02), LOWER,
			Basis(Quaternion(Vector3.DOWN, along)))
	var mesh := _add(pivot, named, tool, paint)
	mesh.visibility_range_end = DETAIL_RANGE
	mesh.visibility_range_end_margin = DETAIL_HYSTERESIS
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
