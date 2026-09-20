extends Node3D
class_name SkyhawkAirframe
## A CESSNA 172S SKYHAWK, DRAWN: a cowled flat-four nose with its two inlets and a two-blade propeller, a cabin of flat sides
## under a braced high wing, a windscreen, two doors with their windows, a rear side window and the wrap-round rear window,
## a tailcone running back into a swept fin with its dorsal fillet, a rudder, a stabiliser with its elevators and trim tab,
## Fowler flaps and ailerons, a lift strut each side, and fixed tricycle gear on spring-steel legs in wheel spats.
## Presentation only: native CockpitWorld owns flight, collision, stations and replication.
##
## ORIGINAL GEOMETRY, measured from references recorded in `craft/cessna/sources.md`. No third-party mesh, photograph,
## texture or livery is incorporated, and the manuals were studied and measured, never copied. Every figure names its source:
## - [IM] Cessna's 172S NAV III information manual, figure 1-1, the three-view in normal ground attitude, measured at
##   0.0026685 m/px (side) and 0.003194 m/px (plan and front) off its own dimension lines. Its prop measures 1.905 m against
##   76 in, so its side view is to scale both ways; its front view's vertical is not, and gives widths and angles only.
## - [MM] Cessna's 172R/S maintenance manual, chapter 6: track 8 ft 4.5 in, cabin 39.5 in wide and 48 in tall, the fuselage
##   and wing stations, the tyre sizes and every control surface's travel.
## - [NOTES] the information manual's notes: wheelbase 65 in, propeller ground clearance 11.25 in, wing area 174 sq ft.
## - [EALT] a CC BY 3.0 Commons photograph of a 172S SP near broadside, scaled off its own track and wheelbase (303 px/m,
##   15.4 degrees off the beam; the length it predicts, 2,419 px, measures 2,425).
## ESTIMATE marks a figure no reference gives.
##
## IT IS FACETED ON PURPOSE, and the segment counts below are the whole of it: "let's keep a somewhat lower poly look to
## models, not too many very round edges, this will keep a better 'old school feel' to things" (the user, 2026-09-17).
## Every measured dimension and feature stays; what is coarse is the TESSELLATION. Three points to a quarter section, eight
## sides to a tyre, a spat or a rod, six cuts along a chord, and flat shading almost everywhere, so a panel is a panel and
## an edge is a crease. DO NOT SUBDIVIDE THIS: the facets are the look, and the check in `tests/skyhawk.gd` holds the
## triangle count under a budget that would not survive smoothing it.
##
## STATIONS ARE METRES AFT OF THE SPINNER TIP, so a station `s` is `z = s - LENGTH / 2`: the drawn aeroplane is centred on the
## native hull's middle. HEIGHTS ARE METRES OVER THE GROUND, so `h` is `y = h - rest`, where `rest` is the native hull's
## half-height -- a parked Cessna's origin rests 0.8499 m over flat ground (measured headless, 2026-09-17).
##
## HOW TALL IT IS, and why that is not the published 8 ft 11 in: Textron's 2.72 m is labelled MAXIMUM and nothing reproduces
## it -- [IM]'s side view puts the beacon at 2.39 m, [EALT] at about 2.34 m -- so this is built to the measured 2.36 m.
##
## WHAT THE FIRST MODEL GOT WRONG: it was a lofted oval with a plank wing, a box fin and two crossed boxes for a propeller,
## sized from the collision box, and it passed its 2% envelope check at the published 2.7 m while nothing inside the box was
## a 172. And a true-scale cabin exposed the SEATS: the package puts both eyes 1.90 m over the ground and 3.24 m aft of the
## spinner, 0.55 m either side of the centreline -- the rear seats, above the window tops, in the fuselage's own skin. A
## real pilot's eye is about 1.45 m up and 2.33 m aft, 0.27 m off the centreline; the seat move is its own package migration.

## SIX THINGS MOVE, and each is A PURE FUNCTION OF WHAT IT IS HANDED, holding no memory and no timer
## (`cockpit/actuators_research.md` section 3.5): `set_flaps(0.3)` then `set_flaps(0.5)` draws exactly what `set_flaps(0.5)`
## does. VehicleView hands each the bus or the linkage straight; how long a surface takes is the simulation's to say.
## - `set_flaps(0..1)`, from the bus's FLAPS: 0 to 30 degrees [MM], sliding aft and down as a Fowler flap does.
## - `set_trim(-1..1)`, from the bus's TRIM, +1 nose up: the tab 19 degrees down to 22 up [MM].
## - `set_ailerons(-1..1)` (+1 right wing down), `set_elevator(-1..1)` (+1 nose up) and `set_rudder(-1..1)` (+1 nose right),
##   from the crew's LINKAGE: ailerons 20 up and 15 down, elevator 28 up and 23 down, rudder 17 degrees 44 minutes [MM].
##   THE STICK AND RUDDER ARE NOT ON THE REPLICATED BUS: `crew_controls` is filled only on a machine aboard, so the crew see
##   these surfaces move and everybody else sees them neutral -- a follow-up that belongs with the timed actuators' wire
##   question (`actuators_research.md`).
## - `set_propeller(turning, throttle, seconds)`: stopped where it was parked, or turning at a fixed readable rate on the
##   physics clock every machine shares, its blades giving way to a disc as the throttle opens.

const LENGTH := 8.28   # [IM] 27 ft 2 in
const SPAN := 11.0     # [IM] 36 ft 1 in, over the strobes
const HEIGHT := 2.36   # measured: [IM] 2.39, [EALT] 2.34; Textron's 2.72 is a maximum nothing reproduces
const PUBLISHED_HEIGHT := 2.72

## THE REFERENCE EYES, where a front-seat crew's eyes are [EALT], 0.27 m either side of the centreline: half of [MM]'s 1.003 m
## cabin, and a seat's middle. The windows are drawn round these.
const EYE_STATION := 2.33
const EYE_HEIGHT := 1.45
const EYE_OUT := 0.27

const WHITE := Color(0.92, 0.92, 0.91)
const UNDER := Color(0.86, 0.87, 0.87)
const TRIM := Color(0.16, 0.22, 0.42)  # ESTIMATE: a dark cheat line, which is the only livery drawn
const SEAM := Color(0.50, 0.51, 0.52)
const DARK := Color(0.05, 0.05, 0.055)
const METAL := Color(0.38, 0.38, 0.39)
const TYRE := Color(0.06, 0.06, 0.06)
const CABIN := Color(0.33, 0.33, 0.34)
const CARPET := Color(0.20, 0.20, 0.22)
const PANEL := Color(0.09, 0.09, 0.10)
const BLADE := Color(0.10, 0.10, 0.11)
const BLADE_TIP := Color(0.90, 0.90, 0.88)

## THE FUSELAGE AS SECTIONS: [station, top, head, sill, bottom, half-width, top squareness, bottom squareness]. The side is
## straight between `head` and `sill`; above and below, a superellipse turns in to the centreline, 2 an ellipse and 4 nearly
## square. Heights over the ground.
## - The side and belly lines are [IM]'s profile, sampled column by column off the drawing against the render: cowl top
##   1.53 m at 0.6 m aft rising to 1.57, belly 0.63 under the firewall, 0.51 under the doors and 0.45 under the baggage door
##   [EALT: 0.44]; the tailcone's top falls from 1.37 behind the rear window to 1.00 at the rudder post, and its belly rises
##   from 0.58 to 0.69. [IM] draws the aeroplane about 1.5 degrees nose-up against [EALT] and [NOTES]' propeller
##   clearance, so aft of the wing its belly reads 0.03 to 0.05 m lower than this and ahead of it, higher.
## - Half-widths are [IM]'s plan view: 0.39 at 0.45 m, 0.50 at 1.0, 0.55 at the cabin -- 1.10 m over [MM]'s 1.003 m inside
##   -- and 0.50, 0.42, 0.34, 0.27, 0.21 at 3.6, 4.3, 5.0, 5.5 and 6.0 m.
## - THE CABIN'S TOP is tucked a centimetre into the wing's underside, 1.87 m under the doors [IM 1.86, EALT 1.83] and
##   1.91 at the windscreen's top, where the leading edge's nose rises: the wing sits on it.
## - THE WINDOWS' HEADS AND SILLS are 1.66 and 1.30 m, between [IM]'s 1.70/1.32 and [EALT]'s 1.52/1.17: a row at each
##   window's front and back edge, so an opening is a run of skipped strips.
## - THE NOSE is 0.10 m under [IM]'s drawing: its spinner would leave 0.41 m under the propeller, and [NOTES] give 11.25 in
##   (0.29 m), which [EALT]'s 1.28 m hub agrees with.
const SECTIONS: Array = [
	[0.30, 1.46, 1.32, 1.12, 0.98, 0.33, 2.4, 2.4],
	[0.45, 1.50, 1.30, 1.06, 0.86, 0.39, 2.6, 2.4],
	[0.64, 1.53, 1.28, 1.00, 0.76, 0.44, 2.8, 2.4],
	[1.00, 1.555, 1.30, 0.94, 0.645, 0.502, 3.0, 2.6],
	[1.50, 1.565, 1.42, 0.90, 0.56, 0.53, 3.0, 3.0],
	[1.72, 1.74, 1.52, 0.92, 0.54, 0.54, 3.2, 3.5],
	[1.95, 1.91, 1.62, 0.94, 0.52, 0.545, 4.0, 4.0],
	[2.20, 1.875, 1.66, 1.30, 0.51, 0.55, 4.0, 4.0],
	[3.01, 1.875, 1.66, 1.30, 0.46, 0.55, 4.0, 4.0],
	[3.07, 1.875, 1.64, 1.29, 0.46, 0.545, 4.0, 4.0],
	[3.52, 1.89, 1.60, 1.27, 0.48, 0.515, 3.6, 3.6],
	[3.77, 1.66, 1.53, 1.24, 0.50, 0.49, 3.0, 2.8],
	[4.19, 1.37, 1.22, 1.00, 0.53, 0.45, 2.6, 2.6],
	[4.70, 1.30, 1.11, 0.91, 0.56, 0.365, 2.4, 2.4],
	[5.50, 1.20, 1.00, 0.84, 0.595, 0.27, 2.2, 2.2],
	[6.40, 1.09, 0.93, 0.79, 0.64, 0.17, 2.2, 2.2],
	[7.15, 1.00, 0.87, 0.76, 0.69, 0.085, 2.2, 2.2],
]
## Points in each quarter of a section between the centreline and the straight side: three, so a section is a fourteen-sided
## ring and its corners read as corners.
const QUARTER := 3

## THE GLAZING, by station [IM][EALT]: the windscreen from the cowl deck to the wing's leading edge; each door's window; the
## rear side window behind it; and the rear window over the baggage bay from the wing's trailing edge down to the tailcone.
const WINDSCREEN := Vector2(1.50, 1.95)
const DOOR_WINDOW := Vector2(2.20, 3.01)
const REAR_SIDE_WINDOW := Vector2(3.07, 3.77)
const REAR_WINDOW := Vector2(3.52, 4.19)
## THE DOORS [IM]: s 2.08 to 3.03, from 0.66 m up to the window head; and the baggage door on the port side, 3.57 to 4.05 m,
## 0.60 to 1.20 m up.
const DOOR := Rect2(2.08, 0.66, 0.95, 1.06)
const BAGGAGE_DOOR := Rect2(3.57, 0.60, 0.48, 0.60)
## THE CABIN INSIDE: the floor, the instrument panel's face and its top, and the baggage bulkhead. ESTIMATE, from [MM]'s 48 in
## floor to headliner under a 1.84 m roof.
const CABIN_FLOOR := 0.56
const PANEL_STATION := 1.84
const PANEL_TOP := 1.31
## THE BOX THAT IS PROVABLY INSIDE THE DRAWN SKIN, which is NOT the cabin the manuals measure, and the difference is a
## fact about this model rather than about the aeroplane.
##
## MEASURED off the drawn sections, 2026-09-17, by scanning outward from the centreline until a ray left the skin
## (`tests/skyhawk.gd`, over s 1.95 to 3.01, at its narrowest station):
##
##     h    0.56  0.62  0.70  0.90  1.30  1.60  1.75  1.80  1.86
##     half 0.35  0.42  0.48  0.52  0.54  0.53  0.52  0.51  0.38
##
## SO THE PROMISE STOPS AT h 0.72, where the section still holds 0.48. It is not the cabin's full width down to its
## floor, because a box has to be true everywhere in it.
##
## AND THAT IS NOT EVIDENCE THAT THE BELLY IS WRONG, though a first draft of this comment said it was and very nearly
## had the aeroplane remodelled. [MM] gives "cabin 39.5 in wide" and NEVER SAYS THAT WIDTH IS AT THE FLOOR: it is a
## maximum, and this model already reproduces it where a cabin is widest -- 0.55 half-width at h 1.30 to 1.66, a lining
## 1.04 to 1.06 m inside against 1.003 m published. A real 172's floor pan is narrower than its shoulder room. The
## lower superellipse's squareness of 4.0 stays an ESTIMATE nothing has measured. A PUBLISHED DIMENSION HAS A DATUM,
## AND "CABIN WIDTH" IS NOT "FLOOR WIDTH".
const ROOM_HALF := 0.46
const ROOM_FLOOR := 0.72
const ROOM_ROOF := 1.78
## WHERE THE ROOM RUNS, fore and aft. Forward, the windscreen's aft edge, where the wing's leading edge crosses: ahead
## of it the roof falls away to the cowl deck (1.83 at s 1.84 against 1.91 at s 1.95) and the panel is in the way
## anyway. Aft, the door window's own aft edge, the last section at full width and full roof; by s 3.77 the roof has
## fallen to 1.66.
const ROOM_FORE := 1.95
const ROOM_AFT := 3.01

## THE WING [IM plan][MM]:
## - a constant 1.60 m chord from the centreline to the break 2.52 m out (WS 100, 2.54), leading edge 1.92 m and trailing
##   edge 3.52 m aft;
## - outboard, the leading edge sweeps back to 2.05 m and the trailing edge forward to 3.16 m at the tip rib 5.26 m out
##   (WS 208, 5.28): a 1.11 m tip chord;
## - a tip fairing out to 5.49 m, and [IM]'s 36 ft 1 in over the strobes;
## - NACA 2412 throughout; the quarter-chord line 1.93 m over the ground over the cabin, so the root's top is 2.05 m [IM] and
##   its underside 1.86 [IM] / 1.83 [EALT];
## - 1.73 degrees of dihedral from the cabin's side [IM front view: 1.44 over the top, 1.92 underneath];
## - 1.5 degrees of incidence at the root washing out to -1.5 at the tip: ESTIMATE.
const WING_ROOT_LE := 1.92
const WING_ROOT_TE := 3.52
const WING_BREAK_X := 2.52
const WING_TIP_X := 5.26
const WING_TIP_LE := 2.05
const WING_TIP_TE := 3.16
const WING_FAIRING_X := 5.49
const WING_QC_H := 1.93
const WING_SIDE_X := 0.55
const DIHEDRAL := 0.030194  # 1.73 degrees
const ROOT_INCIDENCE := 0.02618  # 1.5 degrees
const TIP_INCIDENCE := -0.02618
## THE MOVING SURFACES' CHORDS: the Fowler flap aft of 73% from the cabin's side to the break [IM: its hatching stops at the
## break], and the aileron aft of 78% from the break to the tip rib. The flap's chord is [IM]'s 0.33 m of hatching plus the
## part nested under the shroud: ESTIMATE.
const FLAP_CHORD := 0.73
const AILERON_CHORD := 0.78
const FLAP_X := Vector2(0.60, 2.49)
const AILERON_X := Vector2(2.56, 5.20)
## The gap drawn at every hinge line, metres.
const HINGE_GAP := 0.02

## THE LIFT STRUT [IM][EALT]: from the fuselage's skin 1.86 m aft and 0.63 m up, to the wing's underside 2.49 m out
## (WS 100, where [IM]'s front view meets it) and 2.18 m aft. A streamlined section 0.12 by 0.04 m: ESTIMATE.
const STRUT_FOOT := Vector3(0.53, 0.63, 1.86)
const STRUT_HEAD_X := 2.49
const STRUT_HEAD_S := 2.18

## THE STABILISER [IM plan]: 3.45 m over the tips [MM 11 ft 4 in]; its leading edge 6.33 m aft at the root sweeping to 6.56 at
## 1.40 m out; the elevators' hinge a straight line at 7.02 m; their trailing edge 7.27 m, reaching back to 7.60 m at the
## root where the rudder clears it; a horn balance at each tip from 6.83 m. Chord line 0.86 m over the ground [IM 0.87,
## EALT 0.83], no dihedral [IM front]. Travel [MM]: 28 degrees up, 23 down.
const STAB_H := 0.86
const STAB_ROOT_X := 0.08
const STAB_HORN_X := 1.54
const STAB_TIP_X := 1.725
const STAB_ROOT_LE := 6.30
const STAB_LE_SWEEP := 0.19   # metres aft per metre out
const ELEVATOR_HINGE := 7.02
const ELEVATOR_TE := 7.27
const ELEVATOR_ROOT_TE := 7.60
const HORN_LE := 6.83
## THE TRIM TAB on the starboard elevator [IM plan], 0.62 to 1.20 m out, the last 0.12 m of chord: ESTIMATE of its size.
const TRIM_TAB_X := Vector2(0.62, 1.20)
const TRIM_TAB_CHORD := 0.12

## THE FIN [IM side]: its leading edge from 1.51 m up at 6.70 m aft to 2.30 m at 7.56 m -- swept 47.4 degrees -- running down
## into the dorsal fillet; the rudder's hinge from (7.17, 1.02) to (7.92, 2.10); the rudder's trailing edge from (7.64, 0.735)
## to (8.22, 2.17); the cap over the rudder's top out to 8.28 m; the beacon on it at 7.75 m to 2.36 m. Travel [MM]: 17 degrees
## 44 minutes each way, perpendicular to the hinge.
const FIN_LE := [Vector2(6.70, 1.51), Vector2(7.56, 2.30)]  # (station, height)
const RUDDER_HINGE := [Vector2(7.17, 1.02), Vector2(7.92, 2.10)]
const RUDDER_TE := [Vector2(7.64, 0.735), Vector2(8.22, 2.17)]
const FIN_ROOT_H := 1.00
const FIN_CAP_H := Vector2(2.13, 2.30)
const RUDDER_TOP_H := 2.10
## The rudder's foot, sloping from behind the tailcone's belly up to its trailing edge [IM].
const RUDDER_FOOT := Vector2(0.69, 0.735)
const BEACON_S := 7.75
## THE DORSAL FILLET [IM side]: its top from the rear window's foot, nearly level, curving up into the fin's leading edge.
const DORSAL: Array[Vector2] = [Vector2(4.19, 1.37), Vector2(4.60, 1.345), Vector2(5.50, 1.37), Vector2(6.34, 1.40),
	Vector2(6.52, 1.445), Vector2(6.70, 1.51)]

## THE NOSE: the spinner's tip on the thrust line 1.27 m up [NOTES][EALT]; the propeller's plane 0.25 m aft of the tip; a two-blade
## McCauley 1A170E/JHA7660, 76 in (1.93 m) across [MM]; two round inlets either side of the spinner [IM front], their
## centres 0.235 m out on the nose bowl: ESTIMATE, since [IM]'s front view shows them 0.17 to 0.41 m out against a cowl its
## plan view makes 0.33 m wide there; the exhaust stub under the starboard cowl [IM front]. Blade chord and twist: ESTIMATE.
const HUB_H := 1.27
const PROP_S := 0.25
const PROP_RADIUS := 0.965
const SPINNER_LENGTH := 0.30
const SPINNER_RADIUS := 0.16
const INLET := Vector3(0.235, 1.25, 0.30)  # (out, height, station)
const INLET_HALF := Vector2(0.075, 0.065)

## THE GEAR [MM][NOTES][IM]: track 2.553 m, wheelbase 1.651 m; the nose axle 1.10 m aft, the main axles 2.75 m. Main tyres
## 6.00-6, 0.445 m across; nose tyre 5.00-5, 0.36 m [IM measures 0.34]. Spring-steel legs from the belly's skin under the
## cabin floor to the axles. Spats [IM][EALT]: the main 0.93 m long, 2.31 to 3.24 m; the nose 0.83 m, 0.72 to 1.55 m.
const TRACK := 2.553
const NOSE_AXLE_S := 1.10
const MAIN_AXLE_S := 2.751
const MAIN_TYRE_R := 0.2225
const MAIN_TYRE_WIDE := 0.15
const NOSE_TYRE_R := 0.18
const NOSE_TYRE_WIDE := 0.13
const MAIN_LEG_ROOT := Vector3(0.0, 0.53, 2.80)  # (unused, height, station): the root is on the skin

## THE TRAVELS [MM], radians, and the Fowler flap's slide at full travel, aft along the chord and down: ESTIMATE.
const FLAP_TRAVEL := 0.523599       # 30 degrees
const FLAP_SLIDE := Vector2(0.18, 0.05)
const AILERON_UP := 0.349066        # 20 degrees
const AILERON_DOWN := 0.261799      # 15 degrees
const ELEVATOR_UP := 0.488692       # 28 degrees
const ELEVATOR_DOWN := 0.401426     # 23 degrees
const TAB_UP := 0.383972            # 22 degrees
const TAB_DOWN := 0.331613          # 19 degrees
const RUDDER_TRAVEL := 0.309523     # 17 degrees 44 minutes, perpendicular to the hinge
## THE PROPELLER, DRAWN: turning at a fixed 2.5 revolutions a second -- a 2,700 rpm propeller at 90 frames a second turns
## 180 degrees a frame and a two-blade one then looks stopped, so the rate is one the eye reads -- clockwise from the seat,
## with the disc fading in from 15% to 55% throttle and the blades gone once it is whole. Parked, the blades stand where
## they were left, a little off the horizontal. ESTIMATE of the look, not of the aeroplane.
const PROP_TURNS := 2.5
const PROP_PARKED := 0.45
const DISC_ALPHA := 0.32
const DISC_FROM := Vector2(0.15, 0.55)

## Small fittings stop drawing once the whole aircraft is a few pixels high, with hysteresis; Mobile has no fade.
## https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html
const DETAIL_RANGE := 350.0
const DETAIL_HYSTERESIS := 40.0

var exterior: Node3D
var interior: Node3D
## Every separately-drawn surface's bounds in the model's frame, by name, as its vertices were emitted.
var surfaces: Dictionary = {}
var _rest: float = 0.85
## What each moving part was last handed, so a check can read it back.
var _flaps: float = 0.0
var _trim: float = 0.0
var _roll: float = 0.0
var _pitch: float = 0.0
var _yaw: float = 0.0
var _prop_handed: Dictionary = {"turning": false, "throttle": 0.0, "seconds": 0.0}
## Each moving node's hinge, {node: [rest position, hinge axis]}. The axis points to starboard for the wing and tail
## surfaces and up the hinge line for the rudder, so a positive angle moves a trailing edge down, or to starboard.
var _hinges: Dictionary = {}


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func show_layers(show_exterior: bool, show_interior: bool) -> void:
	if exterior != null: exterior.visible = show_exterior
	if interior != null: interior.visible = show_interior


## Model-frame z of a station.
static func station(s: float) -> float:
	return s - LENGTH * 0.5


## Model-frame y of a height over the ground.
func height(h: float) -> float:
	return h - _rest


## THE ROOM THIS AEROPLANE PROMISES ROUND ITS CREW, in the craft's own frame.
##
## WHAT IT PROMISES, and it is deliberately NOT "the shape of the cabin": **every point inside `room` is inside the skin
## this aeroplane draws.** A cabin is a lofted section and no box describes one. A conservative box is the thing another
## part of the game can act on -- a floor, a seat or a rail that fits in the room fits in the aeroplane -- without
## carrying any geometry of its own and without reading a single constant out of this file.
##
## A POINT OUTSIDE THE ROOM MAY OR MAY NOT BE OUTSIDE THE SKIN, and that is not a defect to be fixed. IT IS NOT A
## TWO-WAY TEST: the first person to use "outside the room" as "outside the aeroplane" will report a bug that is not
## one. The asymmetry is what buys the promise -- the room can be held against the drawn triangles, which
## `tests/skyhawk.gd` does on a grid over all six faces, where a description that was approximately true in both
## directions would be checkable in neither.
##
## ONE AABB AND NOT FOUR NUMBERS: the floor of the room is its bottom, the roof is its top, the half-width is half its
## size in x and the run of the cabin is its z. Six numbers in one value that cannot disagree with itself.
##
## THE FRAME IS THE CRAFT'S OWN, the one `Sim.geometry_of(kind)["seat_poses"]` uses: metres, +Y up, -Z forward, origin at
## the native hull's middle. So a seat pose and this room compare without a transform, which is the whole reason it is
## published in this frame and not in stations over the ground.
##
## IT IS THE PARKED AEROPLANE'S. Nothing here moves with the flaps, the doors or the gear.
##
## `floor` AND `room` ARE TWO DIFFERENT FACTS AND BOTH ARE NEEDED. `floor` is where the cabin floor is -- what a seat
## stands on -- and it is the number anything laying a floor wants. IT IS AN ESTIMATE, not a published figure: [MM]'s
## 48 in of cabin height under the drawn 1.875 m roof would put it at 0.656, a tenth of a metre higher than the 0.56
## this model has always used, and nothing has measured which is right. `room` is the
## largest box that can be PROMISED inside the drawn skin, and its bottom sits ABOVE that floor wherever the drawn
## belly pinches in below it, which on this aeroplane is 0.16 m. Collapsing the two would either promise room that is
## not there or move the floor to somewhere no floor is.
##
## THIS AEROPLANE'S OWN SEATS ARE NOT IN THIS ROOM, AND THE NUMBERS ARE RIGHT ANYWAY. The package puts seat 0's eye
## 0.12 m over the room's roof and 0.09 m outside its wall, because the seat poses are the rear seats' and were never
## moved. A seat pose is native shape-table data and the move is its own migration. DO NOT "CORRECT" THE ROOM TO MAKE
## THAT GO AWAY: a declaration that honestly reports a craft it does not yet fit is worth more than one that waits for
## the fix, and `tests/skyhawk.gd` prints the gap on every run so it cannot be forgotten.
func cabin_room() -> Dictionary:
	var fore: float = station(ROOM_FORE)
	var low: float = height(ROOM_FLOOR)
	return {
		"drawn": true,
		"floor": height(CABIN_FLOOR),
		"room": AABB(Vector3(-ROOM_HALF, low, fore),
			Vector3(ROOM_HALF * 2.0, height(ROOM_ROOF) - low, station(ROOM_AFT) - fore)),
		"because": &"",
		"why_not": "",
		"source": "floor ESTIMATE (see CABIN_FLOOR); the room MEASURED off the drawn sections, 2026-09-17",
	}


## THE NAMED SOCKETS, from the same constants the drawing uses: craft.json's copy is checked against these.
func sockets() -> Dictionary:
	var strut_head: Vector3 = _wing_point(1.0, STRUT_HEAD_X, _chord_at(STRUT_HEAD_X, STRUT_HEAD_S), -1.0)
	return {
		"nose_gear": [0.0, _round(height(NOSE_TYRE_R)), _round(station(NOSE_AXLE_S))],
		"main_gear_port": [_round(-TRACK * 0.5), _round(height(MAIN_TYRE_R)), _round(station(MAIN_AXLE_S))],
		"main_gear_starboard": [_round(TRACK * 0.5), _round(height(MAIN_TYRE_R)), _round(station(MAIN_AXLE_S))],
		"propeller": [0.0, _round(height(HUB_H)), _round(station(PROP_S))],
		"wing_strut_port": [-STRUT_HEAD_X, _round(strut_head.y), _round(strut_head.z)],
		"wing_strut_starboard": [STRUT_HEAD_X, _round(strut_head.y), _round(strut_head.z)],
	}


static func _round(value: float) -> float:
	return snappedf(value, 0.01)


func _build() -> void:
	var native: Dictionary = Sim.geometry_of(Sim.Kind.CESSNA)
	_rest = float((native.get("extents", Vector3(0.80, 0.85, 4.15)) as Vector3).y)
	exterior = Node3D.new(); exterior.name = "Exterior"; add_child(exterior)
	interior = Node3D.new(); interior.name = "Interior"; add_child(interior)
	var paint := _paint(false)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.10, 0.16, 0.20, 0.30)
	glass.roughness = 0.05
	glass.metallic = 0.2
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	var body := _tool()
	var windows := _tool()
	var lining := _tool()
	_fuselage(body, windows, lining)
	_cowl_face(body)
	_dorsal(body)
	_fin(body)
	for side in [1.0, -1.0]:
		_wing(body, side)
		_stabiliser(body, side)
		var strut := _tool()
		_strut(strut, side)
		_add(exterior, "Strut" + ("Starboard" if side > 0.0 else "Port"), strut, paint, false)
	_beacon(body)
	_add(exterior, "Airframe", body, paint, false)
	var glazing := _add(exterior, "Glazing", windows, glass, false)
	glazing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cabin(lining)
	var cabin := _add(interior, "Cabin", lining, paint, false)
	cabin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var details := _tool()
	_details(details)
	var fittings := _add(exterior, "Details", details, paint, true)
	fittings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var gear := _tool()
	_gear(gear)
	_add(exterior, "Gear", gear, paint, false)

	_moving_surfaces(paint)
	_propeller(paint)
	set_propeller(false, 0.0, 0.0)


## ---- the fuselage -------------------------------------------------------------------------------------------------

## One section's starboard half, top centre to bottom centre: QUARTER points turning in above the head, the straight side from
## head to sill, QUARTER points turning in below the sill. Its size is 2 * QUARTER + 2.
static func _half(row: Array) -> Array[Vector2]:
	var top: float = row[1]; var head: float = row[2]; var sill: float = row[3]; var bottom: float = row[4]
	var w: float = row[5]; var n_top: float = row[6]; var n_bottom: float = row[7]
	var half: Array[Vector2] = []
	for i in range(QUARTER + 1):
		var t: float = PI * 0.5 * (1.0 - float(i) / QUARTER)
		half.append(Vector2(w * pow(maxf(cos(t), 0.0), 2.0 / n_top), head + (top - head) * pow(maxf(sin(t), 0.0), 2.0 / n_top)))
	for i in range(QUARTER + 1):
		var t: float = PI * 0.5 * float(i) / QUARTER
		half.append(Vector2(w * pow(maxf(cos(t), 0.0), 2.0 / n_bottom),
			sill - (sill - bottom) * pow(maxf(sin(t), 0.0), 2.0 / n_bottom)))
	return half


## A section as a closed ring: the top centre, down the starboard side to the bottom centre, and up the port side.
func _ring(row: Array) -> Array[Vector3]:
	var s: float = float(row[0])
	var half := _half(row)
	var ring: Array[Vector3] = []
	for point in half:
		ring.append(Vector3(point.x, height(point.y), station(s)))
	for index in range(half.size() - 2, 0, -1):
		ring.append(Vector3(-half[index].x, height(half[index].y), station(s)))
	return ring


## A section's value at any station, linearly between rows: 1 top, 2 head, 3 sill, 4 bottom, 5 half-width.
static func section_at(s: float, column: int) -> float:
	for i in range(SECTIONS.size() - 1):
		var a: Array = SECTIONS[i]
		var b: Array = SECTIONS[i + 1]
		if s <= float(b[0]) or i == SECTIONS.size() - 2:
			var t: float = clampf((s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
			return lerpf(float(a[column]), float(b[column]), t)
	return 0.0


## THE SKIN'S HALF-WIDTH at a station and a height over the ground: the straight side between head and sill, the superellipse
## above and below. Zero outside the section.
static func half_width_at(s: float, h: float) -> float:
	var row: Array = []
	for column in range(8):
		row.append(section_at(s, column))
	var top: float = row[1]; var head: float = row[2]; var sill: float = row[3]; var bottom: float = row[4]
	var w: float = row[5]
	if h > top or h < bottom:
		return 0.0
	if h >= sill and h <= head:
		return w
	var n: float = row[6] if h > head else row[7]
	var reach: float = (h - head) / maxf(top - head, 0.0001) if h > head else (sill - h) / maxf(sill - bottom, 0.0001)
	var sine: float = pow(clampf(reach, 0.0, 1.0), n / 2.0)
	return w * pow(sqrt(maxf(1.0 - sine * sine, 0.0)), 2.0 / n)


## Which strip `k` of a section is glass between two stations: 0 to 3 turn in above the head, 4 is the straight side.
static func glazed(k: int, s0: float, s1: float) -> bool:
	var within := func(span: Vector2) -> bool: return s0 >= span.x - 0.001 and s1 <= span.y + 0.001
	if k <= QUARTER - 1 and (within.call(WINDSCREEN) or within.call(REAR_WINDOW)):
		return true
	return k == QUARTER and (within.call(DOOR_WINDOW) or within.call(REAR_SIDE_WINDOW))


func _fuselage(skin: SurfaceTool, windows: SurfaceTool, lining: SurfaceTool) -> void:
	var rings: Array = []
	for row in SECTIONS:
		rings.append(_ring(row as Array))
	var count: int = (rings[0] as Array).size()
	var last_k: int = 2 * QUARTER
	for i in range(rings.size() - 1):
		var a: Array[Vector3] = rings[i]
		var b: Array[Vector3] = rings[i + 1]
		var s0: float = float((SECTIONS[i] as Array)[0])
		var s1: float = float((SECTIONS[i + 1] as Array)[0])
		var cabin: bool = s0 >= WINDSCREEN.x - 0.001 and s1 <= REAR_WINDOW.y + 0.001
		var mid_h: float = (float((SECTIONS[i] as Array)[2]) + float((SECTIONS[i] as Array)[3])) * 0.5
		var centre := Vector3(0.0, height(mid_h), (a[0].z + b[0].z) * 0.5)
		for j in range(count):
			var k: int = j if j <= last_k else 2 * last_k + 1 - j
			var next: int = (j + 1) % count
			var out: Vector3 = (a[j] + b[next]) * 0.5 - centre
			if glazed(k, s0, s1):
				_quad(windows, a[j], a[next], b[next], b[j], out, Color.WHITE)
				continue
			var tint: Color = WHITE if k <= QUARTER else UNDER
			# FLAT, so every panel of the skin is a panel: smoothing a fourteen-sided ring only made it a soft tube.
			skin.set_smooth_group(-1)
			_quad(skin, a[j], a[next], b[next], b[j], out, tint)
			if cabin:
				# THE LINING, a hand's width in: what the crew see of the cabin's walls, roof and belly.
				var inward := func(p: Vector3) -> Vector3: return p + (centre - p).normalized() * 0.02
				lining.set_smooth_group(-1)
				_quad(lining, inward.call(a[j]), inward.call(a[next]), inward.call(b[next]), inward.call(b[j]), -out, CABIN)
	# THE TAILCONE'S END, behind the rudder's post.
	var last: Array[Vector3] = rings[rings.size() - 1]
	var middle := Vector3.ZERO
	for point in last:
		middle += point
	middle /= float(last.size())
	skin.set_smooth_group(-1)
	for j in range(count):
		_tri(skin, middle, last[j], last[(j + 1) % count], Vector3.BACK, UNDER)
	_record("Fuselage", rings)


## THE COWL'S FACE round the spinner, with its two inlets: each a dark recess behind a lip, so it reads as a hole from a
## quarter rather than a painted oval.
func _cowl_face(tool: SurfaceTool) -> void:
	tool.set_smooth_group(-1)
	var ring := _ring(SECTIONS[0] as Array)
	var hub := Vector3(0.0, height(HUB_H), station(float((SECTIONS[0] as Array)[0])))
	for j in range(ring.size()):
		_tri(tool, hub, ring[j], ring[(j + 1) % ring.size()], Vector3.FORWARD, WHITE)
	const SIDES := 8
	for side in [1.0, -1.0]:
		var centre := Vector3(side * INLET.x, height(INLET.y), station(INLET.z) - 0.004)
		for k in range(SIDES):
			var t0: float = TAU * float(k) / SIDES
			var t1: float = TAU * float(k + 1) / SIDES
			var r0 := Vector3(cos(t0) * INLET_HALF.x, sin(t0) * INLET_HALF.y, 0.0)
			var r1 := Vector3(cos(t1) * INLET_HALF.x, sin(t1) * INLET_HALF.y, 0.0)
			# The lip, standing 3 cm proud of the face and 1.5 cm wide.
			_quad(tool, centre + r0 * 1.15 + Vector3(0, 0, -0.03), centre + r1 * 1.15 + Vector3(0, 0, -0.03),
				centre + r1 * 1.15, centre + r0 * 1.15, r0 + r1, WHITE)
			_quad(tool, centre + r0 + Vector3(0, 0, -0.03), centre + r1 + Vector3(0, 0, -0.03),
				centre + r1 * 1.15 + Vector3(0, 0, -0.03), centre + r0 * 1.15 + Vector3(0, 0, -0.03), Vector3.FORWARD, SEAM)
			_quad(tool, centre + r0 + Vector3(0, 0, -0.03), centre + r1 + Vector3(0, 0, -0.03), centre + r1, centre + r0,
				-(r0 + r1), DARK.lightened(0.15))
			_tri(tool, centre, centre + r0, centre + r1, Vector3.FORWARD, DARK)


## THE DORSAL FILLET: a thin keel from the rear window's foot along the tailcone's top into the fin.
func _dorsal(tool: SurfaceTool) -> void:
	tool.set_smooth_group(-1)
	const HALF := 0.035
	var box := AABB()
	var found := false
	for i in range(DORSAL.size() - 1):
		var a: Vector2 = DORSAL[i]
		var b: Vector2 = DORSAL[i + 1]
		var a_low: float = section_at(a.x, 1) - 0.06
		var b_low: float = section_at(b.x, 1) - 0.06
		var corners: Array[Vector3] = []
		for side in [1.0, -1.0]:
			var taper_a: float = HALF * (0.4 if i == 0 else 1.0)
			var p0 := Vector3(side * taper_a, height(a.y), station(a.x))
			var p1 := Vector3(side * HALF, height(b.y), station(b.x))
			var p2 := Vector3(side * HALF, height(b_low), station(b.x))
			var p3 := Vector3(side * taper_a, height(a_low), station(a.x))
			_quad(tool, p0, p1, p2, p3, Vector3(side, 0.0, 0.0), WHITE)
			corners.append_array([p0, p1, p2, p3])
		_quad(tool, corners[0], corners[1], corners[5], corners[4], Vector3.UP, WHITE)
		for corner in corners:
			box = box.expand(corner) if found else AABB(corner, Vector3.ZERO)
			found = true
	surfaces["DorsalFillet"] = box


## ---- the fin and rudder ------------------------------------------------------------------------------------------

static func _along(line: Array, h: float) -> float:
	var a: Vector2 = line[0]
	var b: Vector2 = line[1]
	return a.x + (h - a.y) * (b.x - a.x) / (b.y - a.y)


## A point on the fin or rudder: `h` over the ground, `c` 0 to 1 between two edge lines, `face` +1 starboard.
func _fin_point(front: Array, back: Array, h: float, c: float, face: float, cap_back: float = -1.0) -> Vector3:
	var le: float = _along(front, h)
	var te: float = _along(back, h) if cap_back < 0.0 else cap_back
	var thick: float = lerpf(0.13, 0.06, clampf((h - FIN_ROOT_H) / (FIN_CAP_H.y - FIN_ROOT_H), 0.0, 1.0))
	return Vector3(face * 0.5 * thick * _thickness(c) / 0.06, height(h), station(lerpf(le, te, c)))


func _fin(tool: SurfaceTool) -> void:
	var fixed := func(u: float, c: float, face: float) -> Vector3:
		return _fin_point(FIN_LE, RUDDER_HINGE, lerpf(FIN_ROOT_H, FIN_CAP_H.x, u), c, face)
	_slab_about(tool, fixed, 0.0, 1.0, 0.0, 1.0, "Fin", Vector3.RIGHT, Vector3.UP, WHITE)
	# THE CAP over the rudder's top, out to the aircraft's length, and the stub of the fin behind the hinge above the rudder.
	var cap := func(u: float, c: float, face: float) -> Vector3:
		return _fin_point(FIN_LE, RUDDER_HINGE, lerpf(FIN_CAP_H.x, FIN_CAP_H.y, u), c, face, LENGTH)
	_slab_about(tool, cap, 0.0, 1.0, 0.0, 1.0, "FinCap", Vector3.RIGHT, Vector3.UP, WHITE)


## WHERE THE LIGHTS GO, in this airframe's frame, on the parts drawn to carry them: the red and green nav lights and a
## strobe each on the tip fairings `_wing` draws, the white light at the foot of the rudder's trailing edge, and the one
## red beacon on the rod on the fin's cap. A 172 carries no belly beacon, so "bottom" is null. `VehicleLights.for_view`
## asks for these. Until 2026-09-17 they came from the collision box: the tips 1.5 m inboard of these fairings and the
## beacon 2.4 m off the rod.
func lights() -> Dictionary:
	var tips: Array[Vector3] = []
	var strobes: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		# Just outboard of the lamp box, whose outer face is 0.02 m past the fairing's end.
		tips.append(_wing_point(side, WING_FAIRING_X - 0.01, 0.12, 0.0) + Vector3(side * 0.05, 0.0, 0.0))
		strobes.append(_wing_point(side, WING_FAIRING_X - 0.01, 0.55, 0.0) + Vector3(side * 0.03, 0.0, 0.0))
	var foot: Vector2 = RUDDER_TE[0]
	return {"port": tips[0], "starboard": tips[1], "strobes": strobes,
		"tail": Vector3(0.0, height(foot.y + 0.05), station(foot.x) + 0.05),
		"top": Vector3(0.0, height(HEIGHT) + 0.02, station(BEACON_S)), "bottom": null}


## THE BEACON on the fin's cap, whose top is the aircraft's height.
func _beacon(tool: SurfaceTool) -> void:
	var base := Vector3(0.0, height(FIN_CAP_H.y - 0.01), station(BEACON_S))
	_rod(tool, base, Vector3(0.0, height(HEIGHT), station(BEACON_S)), 0.035, Color(0.75, 0.10, 0.08), 4)


## ---- the wing ------------------------------------------------------------------------------------------------------

static func wing_leading_edge(x: float) -> float:
	if x <= WING_BREAK_X:
		return WING_ROOT_LE
	if x <= WING_TIP_X:
		return lerpf(WING_ROOT_LE, WING_TIP_LE, (x - WING_BREAK_X) / (WING_TIP_X - WING_BREAK_X))
	return lerpf(WING_TIP_LE, WING_TIP_LE + 0.16, (x - WING_TIP_X) / (WING_FAIRING_X - WING_TIP_X))


static func wing_trailing_edge(x: float) -> float:
	if x <= WING_BREAK_X:
		return WING_ROOT_TE
	if x <= WING_TIP_X:
		return lerpf(WING_ROOT_TE, WING_TIP_TE, (x - WING_BREAK_X) / (WING_TIP_X - WING_BREAK_X))
	return lerpf(WING_TIP_TE, WING_TIP_TE - 0.22, (x - WING_TIP_X) / (WING_FAIRING_X - WING_TIP_X))


## The chord fraction at which a station lies on the wing `x` out.
static func _chord_at(x: float, s: float) -> float:
	return (s - wing_leading_edge(x)) / (wing_trailing_edge(x) - wing_leading_edge(x))


## NACA 2412's half-thickness along the chord, as a fraction of the chord [NACA 4-digit formula, t = 0.12].
static func _thickness(c: float) -> float:
	var x: float = clampf(c, 0.0, 1.0)
	return 0.6 * (0.2969 * sqrt(x) - 0.1260 * x - 0.3516 * x * x + 0.2843 * x * x * x - 0.1036 * x * x * x * x)


## NACA 2412's camber line along the chord, as a fraction of the chord: 2% at 40%.
static func _camber(c: float) -> float:
	var x: float = clampf(c, 0.0, 1.0)
	if x < 0.4:
		return 0.02 / 0.16 * (0.8 * x - x * x)
	return 0.02 / 0.36 * (0.2 + 0.8 * x - x * x)


## The wing's quarter-chord height `x` out: level over the cabin, rising at the dihedral from its side.
static func wing_height(x: float) -> float:
	return WING_QC_H + maxf(x - WING_SIDE_X, 0.0) * tan(DIHEDRAL)


## A point on the wing: `x` out, `c` along the chord 0 to 1, `face` +1 on top and -1 underneath.
func _wing_point(side: float, x: float, c: float, face: float) -> Vector3:
	var le: float = wing_leading_edge(x)
	var chord: float = wing_trailing_edge(x) - le
	var twist: float = lerpf(ROOT_INCIDENCE, TIP_INCIDENCE, clampf((x - WING_SIDE_X) / (WING_TIP_X - WING_SIDE_X), 0.0, 1.0))
	var fade: float = 1.0 if x <= WING_TIP_X else lerpf(1.0, 0.45, (x - WING_TIP_X) / (WING_FAIRING_X - WING_TIP_X))
	var h: float = wing_height(x) - (c - 0.25) * chord * sin(twist) + chord * (_camber(c) + face * _thickness(c) * fade)
	return Vector3(side * x, height(h), station(le + c * chord))


func _wing(tool: SurfaceTool, side: float) -> void:
	var named := "Starboard" if side > 0.0 else "Port"
	var point := func(x: float, c: float, face: float) -> Vector3: return _wing_point(side, x, c, face)
	var g: float = HINGE_GAP
	# Over the cabin, and a strip either side of every moving surface, the whole chord.
	_slab(tool, point, 0.0, FLAP_X.x - g, 0.0, 1.0, "WingRoot" + named, side)
	_slab(tool, point, FLAP_X.x - g, FLAP_X.y + g, 0.0, FLAP_CHORD, "WingInboard" + named, side)
	_slab(tool, point, FLAP_X.y + g, AILERON_X.x - g, 0.0, 1.0, "WingBreak" + named, side)
	_slab(tool, point, AILERON_X.x - g, AILERON_X.y + g, 0.0, AILERON_CHORD, "WingOutboard" + named, side)
	_slab(tool, point, AILERON_X.y + g, WING_TIP_X, 0.0, 1.0, "WingTipPanel" + named, side)
	_slab(tool, point, WING_TIP_X, WING_FAIRING_X, 0.0, 1.0, "WingTip" + named, side)
	# THE NAV LIGHT AND STROBE's fairing on the tip, which is where [IM]'s 36 ft 1 in is measured to.
	var lamp: Vector3 = point.call(WING_FAIRING_X - 0.01, 0.12, 0.0)
	_box(tool, lamp + Vector3(side * 0.01, 0.0, 0.0), Vector3(0.02, 0.05, 0.10), SEAM)


## ---- the stabiliser ------------------------------------------------------------------------------------------------

static func stab_leading_edge(x: float) -> float:
	if x <= STAB_HORN_X:
		return STAB_ROOT_LE + x * STAB_LE_SWEEP
	return HORN_LE


static func elevator_trailing_edge(x: float) -> float:
	if x <= 0.55:
		return lerpf(ELEVATOR_ROOT_TE, ELEVATOR_TE, clampf((x - STAB_ROOT_X) / (0.55 - STAB_ROOT_X), 0.0, 1.0))
	return ELEVATOR_TE - maxf(x - STAB_HORN_X, 0.0) * 0.1


## A point on the stabiliser and elevator: `c` 0 to 1 between the two stations given, the section thinning from 9 to 6 cm.
func _tail_point(side: float, x: float, front: float, back: float, c: float, face: float, full_front: float,
		full_back: float) -> Vector3:
	var s: float = lerpf(front, back, c)
	var whole: float = clampf((s - full_front) / maxf(full_back - full_front, 0.01), 0.0, 1.0)
	var thick: float = lerpf(0.09, 0.05, clampf(x / STAB_TIP_X, 0.0, 1.0))
	return Vector3(side * x, height(STAB_H) + face * thick * _thickness(whole) / 0.12, station(s))


func _stabiliser(tool: SurfaceTool, side: float) -> void:
	var named := "Starboard" if side > 0.0 else "Port"
	var fixed := func(x: float, c: float, face: float) -> Vector3:
		var le: float = stab_leading_edge(x)
		return _tail_point(side, x, le, ELEVATOR_HINGE - HINGE_GAP * 0.5, c, face, le, elevator_trailing_edge(x))
	_slab(tool, fixed, 0.0, STAB_HORN_X - HINGE_GAP, 0.0, 1.0, "Stabiliser" + named, side)


## ---- the strut -----------------------------------------------------------------------------------------------------

func _strut(tool: SurfaceTool, side: float) -> void:
	var foot := Vector3(side * (half_width_at(STRUT_FOOT.z, STRUT_FOOT.y) + 0.02), height(STRUT_FOOT.y), station(STRUT_FOOT.z))
	var head: Vector3 = _wing_point(side, STRUT_HEAD_X, _chord_at(STRUT_HEAD_X, STRUT_HEAD_S), -1.0) + Vector3(0.0, 0.01, 0.0)
	_streamline(tool, foot, head, 0.12, 0.04, WHITE)
	# The fittings at each end.
	_box(tool, foot + Vector3(-side * 0.02, 0.0, 0.0), Vector3(0.05, 0.08, 0.14), SEAM)
	_box(tool, head + Vector3(0.0, -0.03, 0.0), Vector3(0.06, 0.05, 0.14), SEAM)
	surfaces["Strut" + ("Starboard" if side > 0.0 else "Port")] = AABB(foot, Vector3.ZERO).expand(head)


## A STRUT OF STREAMLINED SECTION from `a` to `b`, its long axis along the flight path.
func _streamline(tool: SurfaceTool, a: Vector3, b: Vector3, chord: float, thick: float, tint: Color) -> void:
	tool.set_smooth_group(-1)
	const SIDES := 6
	var along: Vector3 = (b - a).normalized()
	var fore: Vector3 = (Vector3.BACK - along * along.dot(Vector3.BACK)).normalized()
	var across: Vector3 = along.cross(fore).normalized()
	for k in range(SIDES):
		var t0: float = TAU * float(k) / SIDES
		var t1: float = TAU * float(k + 1) / SIDES
		var r0: Vector3 = fore * cos(t0) * chord * 0.5 + across * sin(t0) * thick * 0.5
		var r1: Vector3 = fore * cos(t1) * chord * 0.5 + across * sin(t1) * thick * 0.5
		_quad(tool, a + r0, a + r1, b + r1, b + r0, r0 + r1, tint)
	tool.set_smooth_group(-1)


## ---- the cabin inside ----------------------------------------------------------------------------------------------

## THE FLOOR, THE INSTRUMENT PANEL AND THE BAGGAGE BULKHEAD: what the crew see of the aeroplane besides its walls. The
## devices in front of them are the station's; this is the structure they are mounted in.
func _cabin(tool: SurfaceTool) -> void:
	tool.set_smooth_group(-1)
	var s0: float = WINDSCREEN.x
	var s1: float = REAR_WINDOW.y
	var floor_y: float = height(CABIN_FLOOR)
	const STEPS := 3
	for i in range(STEPS):
		var a: float = lerpf(s0, s1, float(i) / STEPS)
		var b: float = lerpf(s0, s1, float(i + 1) / STEPS)
		var wa: float = half_width_at(a, maxf(CABIN_FLOOR, section_at(a, 4) + 0.10)) - 0.03
		var wb: float = half_width_at(b, maxf(CABIN_FLOOR, section_at(b, 4) + 0.10)) - 0.03
		_quad(tool, Vector3(wa, floor_y, station(a)), Vector3(wb, floor_y, station(b)), Vector3(-wb, floor_y, station(b)),
			Vector3(-wa, floor_y, station(a)), Vector3.UP, CARPET)
	# The panel's face from the floor to its top, following the skin's curve at its foot; the glare shield over it reaching
	# aft; both the cabin's width.
	var w: float = section_at(PANEL_STATION, 5) - 0.03
	var levels: Array[float] = [CABIN_FLOOR, 0.70, PANEL_TOP]
	for i in range(levels.size() - 1):
		var wa: float = half_width_at(PANEL_STATION, maxf(levels[i], section_at(PANEL_STATION, 4) + 0.10)) - 0.03
		var wb: float = half_width_at(PANEL_STATION, levels[i + 1]) - 0.03
		_quad(tool, Vector3(wa, height(levels[i]), station(PANEL_STATION)), Vector3(-wa, height(levels[i]), station(PANEL_STATION)),
			Vector3(-wb, height(levels[i + 1]), station(PANEL_STATION)), Vector3(wb, height(levels[i + 1]), station(PANEL_STATION)),
			Vector3.BACK, PANEL)
	_box(tool, Vector3(0.0, height(PANEL_TOP + 0.03), station(PANEL_STATION + 0.06)), Vector3(w * 2.0, 0.06, 0.16), PANEL)
	# Forward of the panel, up to the windscreen's foot, so the ground does not show under the glare shield.
	var deck: float = section_at(WINDSCREEN.x, 2)
	_quad(tool, Vector3(w, height(PANEL_TOP + 0.06), station(PANEL_STATION)),
		Vector3(-w, height(PANEL_TOP + 0.06), station(PANEL_STATION)),
		Vector3(-w, height(deck), station(WINDSCREEN.x + 0.01)), Vector3(w, height(deck), station(WINDSCREEN.x + 0.01)),
		Vector3.UP, PANEL)
	# The baggage bulkhead closing the tailcone off.
	var ring := _ring(SECTIONS[_row_of(REAR_WINDOW.y)] as Array)
	var middle := Vector3(0.0, height(section_at(REAR_WINDOW.y, 3)), station(REAR_WINDOW.y - 0.005))
	for j in range(ring.size()):
		_tri(tool, middle, ring[j] + Vector3(0, 0, -0.005), ring[(j + 1) % ring.size()] + Vector3(0, 0, -0.005),
			Vector3.FORWARD, CABIN)


static func _row_of(s: float) -> int:
	for i in range(SECTIONS.size()):
		if absf(float((SECTIONS[i] as Array)[0]) - s) < 0.001:
			return i
	return 0


## ---- small fittings ------------------------------------------------------------------------------------------------

## Door seams and handles, window frames, the cheat line, antennae, the pitot tube, the exhaust and the landing light:
## small things, range-culled.
func _details(tool: SurfaceTool) -> void:
	tool.set_smooth_group(-1)
	for side in [1.0, -1.0]:
		# THE DOOR'S OUTLINE [IM]: a seam a centimetre wide just proud of the skin.
		_seam_rect(tool, side, DOOR, 0.012)
		if side < 0.0:
			_seam_rect(tool, side, BAGGAGE_DOOR, 0.010)
		# The window frames: a dark band round each side opening.
		for window in [DOOR_WINDOW, REAR_SIDE_WINDOW]:
			var s0: float = window.x
			var s1: float = window.y
			_seam_rect(tool, side, Rect2(s0 - 0.02, section_at(s0, 3) - 0.02, s1 - s0 + 0.04,
				section_at(s0, 2) - section_at(s0, 3) + 0.04), 0.025, DARK)
		# The handle, aft on the door under the window.
		var handle_s: float = DOOR.end.x - 0.20
		_box(tool, Vector3(side * (half_width_at(handle_s, 1.18) + 0.015), height(1.18), station(handle_s)),
			Vector3(0.02, 0.03, 0.14), METAL)
		# THE CHEAT LINE from the cowl to the tail: ESTIMATE of the livery.
		var line: Array[Vector3] = []
		for s in [0.96, 1.50, 2.00, 3.00, 4.19, 5.50, 7.00]:
			var h: float = lerpf(1.02, 0.84, s / 7.0)
			line.append(Vector3(side * (half_width_at(s, h) + 0.012), height(h), station(s)))
		for i in range(line.size() - 1):
			_quad(tool, line[i] + Vector3(0, 0.035, 0), line[i + 1] + Vector3(0, 0.035, 0), line[i + 1] - Vector3(0, 0.035, 0),
				line[i] - Vector3(0, 0.035, 0), Vector3(side, 0.0, 0.0), TRIM)
	# THE ANTENNAE [IM side]: a whip over the cabin raked aft, and a VHF blade on the tailcone's top behind the rear window.
	_rod(tool, Vector3(0.0, height(2.03), station(3.00)), Vector3(0.0, height(2.26), station(3.25)), 0.008, DARK, 4)
	_box(tool, Vector3(0.0, height(1.42), station(4.55)), Vector3(0.012, 0.15, 0.07), SEAM,
		Basis(Vector3.RIGHT, -0.5))
	# THE PITOT TUBE under the port wing, and the landing and taxi lights in its leading edge [IM front]: ESTIMATE of position.
	var pitot: Vector3 = _wing_point(-1.0, 3.30, 0.10, -1.0)
	_rod(tool, pitot + Vector3(0, -0.02, 0), pitot + Vector3(0, -0.08, -0.25), 0.012, METAL, 4)
	var lamp: Vector3 = _wing_point(-1.0, 3.80, 0.0, 0.0)
	_box(tool, lamp + Vector3(0, 0, -0.006), Vector3(0.28, 0.07, 0.01), Color(0.85, 0.87, 0.9))
	# THE EXHAUST STUB under the starboard cowl [IM front].
	_rod(tool, Vector3(0.25, height(0.72), station(1.02)), Vector3(0.27, height(0.60), station(1.14)), 0.03, METAL, 5)
	# THE STEP on each main leg, and the tie-down ring under the tail.
	for side in [1.0, -1.0]:
		_box(tool, Vector3(side * 0.62, height(0.42), station(MAIN_AXLE_S + 0.02)), Vector3(0.10, 0.015, 0.14), METAL)
	_rod(tool, Vector3(0.0, height(0.74), station(7.08)), Vector3(0.0, height(0.66), station(7.08)), 0.015, METAL, 4)


## A RECTANGULAR SEAM on the skin's side: the four edges of `rect` (station, height), each `wide` across.
func _seam_rect(tool: SurfaceTool, side: float, rect: Rect2, wide: float, tint: Color = SEAM) -> void:
	var s0: float = rect.position.x
	var s1: float = rect.end.x
	var h0: float = rect.position.y
	var h1: float = rect.end.y
	_seam(tool, side, Vector2(s0, h0), Vector2(s1, h0), wide, tint)
	_seam(tool, side, Vector2(s0, h1), Vector2(s1, h1), wide, tint)
	_seam(tool, side, Vector2(s0, h0), Vector2(s0, h1), wide, tint)
	_seam(tool, side, Vector2(s1, h0), Vector2(s1, h1), wide, tint)


## ONE SEAM from `a` to `b` (station, height), following the skin in steps so it lies on the curve below the sill.
func _seam(tool: SurfaceTool, side: float, a: Vector2, b: Vector2, wide: float, tint: Color) -> void:
	const STEPS := 3
	var across: Vector2 = Vector2(-(b - a).y, (b - a).x).normalized() * wide * 0.5
	for i in range(STEPS):
		var p: Vector2 = a.lerp(b, float(i) / STEPS)
		var q: Vector2 = a.lerp(b, float(i + 1) / STEPS)
		var corners: Array[Vector3] = []
		for at in [p + across, q + across, q - across, p - across]:
			var v: Vector2 = at
			corners.append(Vector3(side * (half_width_at(v.x, v.y) + 0.010), height(v.y), station(v.x)))
		_quad(tool, corners[0], corners[1], corners[2], corners[3], Vector3(side, 0.0, 0.0), tint)


## ---- the gear ------------------------------------------------------------------------------------------------------

## THE FIXED TRICYCLE GEAR: nothing retracts, so it is drawn into one mesh.
func _gear(tool: SurfaceTool) -> void:
	for side in [1.0, -1.0]:
		var axle := Vector3(side * TRACK * 0.5, height(MAIN_TYRE_R), station(MAIN_AXLE_S))
		var root := Vector3(side * (half_width_at(MAIN_LEG_ROOT.z, MAIN_LEG_ROOT.y) - 0.02), height(MAIN_LEG_ROOT.y),
			station(MAIN_LEG_ROOT.z))
		var inboard: Vector3 = axle - Vector3(side * (MAIN_TYRE_WIDE * 0.5 + 0.07), 0.02, 0.0)
		# THE SPRING-STEEL LEG: a flat tapered bar, wide along the flight path [IM front: it runs straight to the axle].
		_bar(tool, root, inboard, 0.10, 0.06, 0.03, WHITE)
		_rod(tool, inboard, axle, 0.025, METAL, 4)
		_wheel(tool, axle, MAIN_TYRE_R, MAIN_TYRE_WIDE)
		# THE SPAT, open underneath to show the tyre's bottom: 2.31 to 3.24 m aft, 0.12 m over the ground to 0.50.
		_spat(tool, Vector3(side * TRACK * 0.5, 0.0, 0.0), 2.31, 3.24, 0.12, 0.50, 0.135, "SpatMain" + ("Starboard" if side > 0.0 else "Port"))
		# The leg's fairing where it meets the belly.
		_box(tool, root + Vector3(side * 0.04, -0.03, 0.0), Vector3(0.16, 0.08, 0.20), WHITE)
	# THE NOSE LEG: an oleo from under the firewall with a torque link behind it and a fork to the axle.
	var nose_axle := Vector3(0.0, height(NOSE_TYRE_R), station(NOSE_AXLE_S))
	var oleo_top := Vector3(0.0, height(0.64), station(1.18))
	var oleo_foot := Vector3(0.0, height(0.40), station(1.13))
	_rod(tool, oleo_top, oleo_foot, 0.04, WHITE, 5)
	_rod(tool, oleo_foot, oleo_foot + Vector3(0.0, -0.08, -0.01), 0.028, METAL, 4)
	for fork in [1.0, -1.0]:
		_rod(tool, oleo_foot + Vector3(fork * 0.08, -0.06, -0.01), nose_axle + Vector3(fork * 0.08, 0.0, 0.0), 0.018, METAL, 4)
	_box(tool, oleo_foot + Vector3(0.0, -0.06, -0.01), Vector3(0.20, 0.03, 0.06), METAL)
	_rod(tool, oleo_top + Vector3(0, -0.06, 0.06), oleo_foot + Vector3(0, 0.02, 0.07), 0.012, METAL, 4)
	_rod(tool, nose_axle + Vector3(-0.09, 0, 0), nose_axle + Vector3(0.09, 0, 0), 0.015, METAL, 4)
	_wheel(tool, nose_axle, NOSE_TYRE_R, NOSE_TYRE_WIDE)
	_spat(tool, Vector3.ZERO, 0.72, 1.55, 0.10, 0.41, 0.11, "SpatNose")


## A WHEEL SPAT: a teardrop from `s0` to `s1`, `low` to `high` over the ground, `half` wide, open under the tyre.
func _spat(tool: SurfaceTool, centre: Vector3, s0: float, s1: float, low: float, high: float, half: float, label: String) -> void:
	tool.set_smooth_group(-1)
	const SIDES := 8
	# (fraction along, width fraction, height fraction): blunt in front, fullest over the axle, a point behind.
	var rows: Array[Vector3] = [Vector3(0.0, 0.25, 0.30), Vector3(0.12, 0.85, 0.85), Vector3(0.45, 1.0, 1.0),
		Vector3(1.0, 0.10, 0.25)]
	var rings: Array = []
	for row in rows:
		var s: float = lerpf(s0, s1, row.x)
		var mid: float = (low + high) * 0.5 + (high - low) * 0.08 * row.x
		var ring: Array[Vector3] = []
		for k in range(SIDES):
			var t: float = TAU * float(k) / SIDES
			ring.append(Vector3(centre.x + cos(t) * half * row.y, height(mid + sin(t) * (high - low) * 0.5 * row.z), station(s)))
		rings.append(ring)
	for i in range(rings.size() - 1):
		for k in range(SIDES):
			var a: Vector3 = (rings[i] as Array)[k]
			var b: Vector3 = (rings[i] as Array)[(k + 1) % SIDES]
			var c: Vector3 = (rings[i + 1] as Array)[(k + 1) % SIDES]
			var d: Vector3 = (rings[i + 1] as Array)[k]
			# The bottom facets under the middle are left open for the tyre.
			if (k == 5 or k == 6) and i >= 1:
				continue
			var mid_axis := Vector3(centre.x, (a.y + c.y) * 0.5, (a.z + c.z) * 0.5)
			_quad(tool, a, b, c, d, (a + c) * 0.5 - mid_axis, WHITE)
	# The front and back caps.
	for i in [0, rows.size() - 1]:
		var ring: Array = rings[i]
		var middle := Vector3.ZERO
		for p in ring:
			middle += p
		middle /= float(SIDES)
		for k in range(SIDES):
			_tri(tool, middle, ring[k], ring[(k + 1) % SIDES], Vector3.FORWARD if i == 0 else Vector3.BACK, WHITE)
	tool.set_smooth_group(-1)
	_record(label, rings)


## ---- the moving surfaces -------------------------------------------------------------------------------------------

## THE FLAPS, AILERONS, ELEVATORS, TRIM TAB AND RUDDER, each a node pivoted on its hinge and built in its neutral pose.
func _moving_surfaces(paint: Material) -> void:
	for side in [1.0, -1.0]:
		var named := "Starboard" if side > 0.0 else "Port"
		var point := func(x: float, c: float, face: float) -> Vector3: return _wing_point(side, x, c, face)

		var flap_pivot: Vector3 = _wing_point(side, FLAP_X.x, FLAP_CHORD, 0.0)
		var flap := _tool()
		_slab(flap, _shifted(point, -flap_pivot), FLAP_X.x, FLAP_X.y, FLAP_CHORD + HINGE_GAP / 1.6, 1.0, "Flap" + named, side)
		_offset_surface("Flap" + named, flap_pivot)
		_hinge(_add(exterior, "Flap" + named, flap, paint, false, flap_pivot),
			_wing_point(side, FLAP_X.y, FLAP_CHORD, 0.0) - flap_pivot)

		var aileron_pivot: Vector3 = _wing_point(side, AILERON_X.x, AILERON_CHORD, 0.0)
		var aileron := _tool()
		_slab(aileron, _shifted(point, -aileron_pivot), AILERON_X.x, AILERON_X.y, AILERON_CHORD + HINGE_GAP / 1.3, 1.0,
			"Aileron" + named, side)
		_offset_surface("Aileron" + named, aileron_pivot)
		_hinge(_add(exterior, "Aileron" + named, aileron, paint, false, aileron_pivot),
			_wing_point(side, AILERON_X.y, AILERON_CHORD, 0.0) - aileron_pivot)

		var hinge := Vector3(0.0, height(STAB_H), station(ELEVATOR_HINGE))
		var tail := func(x: float, c: float, face: float) -> Vector3:
			var front: float = ELEVATOR_HINGE + HINGE_GAP * 0.5 if x < STAB_HORN_X + 0.001 else HORN_LE
			return _tail_point(side, x, front, elevator_trailing_edge(x), c, face, stab_leading_edge(x),
				elevator_trailing_edge(x)) - hinge
		var elevator := _tool()
		_slab(elevator, tail, STAB_ROOT_X + 0.04, STAB_HORN_X, 0.0, 1.0, "Elevator" + named, side)
		_slab(elevator, tail, STAB_HORN_X, STAB_TIP_X, 0.0, 1.0, "ElevatorHorn" + named, side)
		_offset_surface("Elevator" + named, hinge)
		_offset_surface("ElevatorHorn" + named, hinge)
		var elevator_node := _add(exterior, "Elevator" + named, elevator, paint, false, hinge)
		_hinge(elevator_node, Vector3.RIGHT)
		if side > 0.0:
			# THE TRIM TAB, hinged on the elevator.
			var tab_hinge := Vector3(TRIM_TAB_X.x, height(STAB_H), station(ELEVATOR_TE - TRIM_TAB_CHORD)) - hinge
			var tab := _tool()
			var tab_point := func(x: float, c: float, face: float) -> Vector3:
				return _tail_point(side, x, ELEVATOR_TE - TRIM_TAB_CHORD + 0.01, ELEVATOR_TE, c, face, stab_leading_edge(x),
					ELEVATOR_TE) - hinge - tab_hinge + Vector3(0.0, face * 0.004, 0.0)
			_slab(tab, tab_point, TRIM_TAB_X.x, TRIM_TAB_X.y, 0.0, 1.0, "TrimTab", side)
			_hinge(_add(elevator_node, "TrimTab", tab, paint, false, tab_hinge), Vector3.RIGHT)

	var rudder_pivot := Vector3(0.0, height((RUDDER_HINGE[0] as Vector2).y), station((RUDDER_HINGE[0] as Vector2).x))
	var rudder := _tool()
	var rudder_point := func(u: float, c: float, face: float) -> Vector3:
		var h: float = lerpf(lerpf(RUDDER_FOOT.x, RUDDER_FOOT.y, c), RUDDER_TOP_H, u)
		var p: Vector3 = _fin_point(RUDDER_HINGE, RUDDER_TE, maxf(h, (RUDDER_HINGE[0] as Vector2).y), c, face)
		# Below the hinge line's foot the rudder's front edge stands straight down behind the tailcone [IM].
		if h < (RUDDER_HINGE[0] as Vector2).y:
			var te: float = _along(RUDDER_TE, h)
			var front: float = (RUDDER_HINGE[0] as Vector2).x
			p = Vector3(p.x, height(h), station(lerpf(front, te, c)))
		# The hinge sits a gap behind the fin's back edge.
		p.z += HINGE_GAP * (1.0 - c)
		return p - rudder_pivot
	_slab_about(rudder, rudder_point, 0.0, 1.0, 0.0, 1.0, "Rudder", Vector3.RIGHT, Vector3.UP, WHITE)
	_offset_surface("Rudder", rudder_pivot)
	var top := RUDDER_HINGE[1] as Vector2
	var foot := RUDDER_HINGE[0] as Vector2
	_hinge(_add(exterior, "Rudder", rudder, paint, false, rudder_pivot), Vector3(0.0, top.y - foot.y, top.x - foot.x))


## A surface function moved by `by`, so a part can be built about its own hinge.
static func _shifted(point: Callable, by: Vector3) -> Callable:
	return func(x: float, c: float, face: float) -> Vector3: return point.call(x, c, face) + by


## A surface's recorded bounds were emitted about its pivot: move them into the model's frame.
func _offset_surface(label: String, pivot: Vector3) -> void:
	if surfaces.has(label):
		var box: AABB = surfaces[label]
		surfaces[label] = AABB(box.position + pivot, box.size)


## ---- the moving parts ----------------------------------------------------------------------------------------------

func _hinge(node: MeshInstance3D, along: Vector3) -> void:
	var axis: Vector3 = along.normalized()
	# The wing and tail hinges point to starboard whichever side they are on, so one angle means one direction on both.
	if absf(axis.x) > 0.5 and axis.x < 0.0:
		axis = -axis
	_hinges[node] = [node.position, axis]


## Turns a hinged node `angle` radians about its hinge and slides it `by` from where it was built.
func _swing(node: Node3D, angle: float, by: Vector3 = Vector3.ZERO) -> void:
	var hinge: Array = _hinges.get(node, [])
	if hinge.is_empty():
		return
	node.basis = Basis(hinge[1] as Vector3, angle)
	node.position = (hinge[0] as Vector3) + by


func _part(named: String) -> Node3D:
	return find_child(named, true, false) as Node3D


## THE FLAPS, 0 up and 1 at 30 degrees, sliding aft along the chord and down as they go.
func set_flaps(amount: float) -> void:
	_flaps = clampf(amount, 0.0, 1.0)
	for named in ["FlapPort", "FlapStarboard"]:
		_swing(_part(named), FLAP_TRAVEL * _flaps, Vector3(0.0, -FLAP_SLIDE.y, FLAP_SLIDE.x) * _flaps)


## THE ELEVATOR TRIM TAB, -1 nose down to +1 nose up: nose-up trim puts the tab's trailing edge down.
func set_trim(amount: float) -> void:
	_trim = clampf(amount, -1.0, 1.0)
	_swing(_part("TrimTab"), TAB_DOWN * _trim if _trim >= 0.0 else TAB_UP * _trim)


## THE AILERONS, -1 left wing down to +1 right wing down: the down-going wing's aileron rises 20 degrees, the other falls 15.
func set_ailerons(amount: float) -> void:
	_roll = clampf(amount, -1.0, 1.0)
	var starboard: float = -AILERON_UP * _roll if _roll >= 0.0 else -AILERON_DOWN * _roll
	var port: float = AILERON_DOWN * _roll if _roll >= 0.0 else AILERON_UP * _roll
	_swing(_part("AileronStarboard"), starboard)
	_swing(_part("AileronPort"), port)


## THE ELEVATORS, -1 nose down to +1 nose up: 28 degrees up, 23 down.
func set_elevator(amount: float) -> void:
	_pitch = clampf(amount, -1.0, 1.0)
	var angle: float = -ELEVATOR_UP * _pitch if _pitch >= 0.0 else -ELEVATOR_DOWN * _pitch
	for named in ["ElevatorPort", "ElevatorStarboard"]:
		_swing(_part(named), angle)


## THE RUDDER, -1 nose left to +1 nose right: its trailing edge goes to starboard for right rudder.
func set_rudder(amount: float) -> void:
	_yaw = clampf(amount, -1.0, 1.0)
	_swing(_part("Rudder"), RUDDER_TRAVEL * _yaw)


## THE PROPELLER: stood still where it was parked, or turning on `seconds` of the physics clock, its disc as solid as the
## throttle is open.
func set_propeller(turning: bool, throttle: float, seconds: float) -> void:
	var open: float = clampf(throttle, 0.0, 1.0)
	_prop_handed = {"turning": turning, "throttle": open, "seconds": seconds}
	var blades := _part("Propeller") as MeshInstance3D
	var disc := _part("PropellerDisc") as MeshInstance3D
	if blades == null or disc == null:
		return
	var solid: float = smoothstep(DISC_FROM.x, DISC_FROM.y, open) if turning else 0.0
	var angle: float = -fposmod(seconds * PROP_TURNS, 1.0) * TAU if turning else PROP_PARKED
	blades.basis = Basis(Vector3.BACK, angle)
	blades.visible = solid < 1.0
	disc.visible = solid > 0.0
	(disc.material_override as StandardMaterial3D).albedo_color.a = DISC_ALPHA * solid


func flaps_amount() -> float:
	return _flaps


func trim_amount() -> float:
	return _trim


## What the ailerons, elevators and rudder were handed: (roll, pitch, yaw).
func stick_amounts() -> Vector3:
	return Vector3(_roll, _pitch, _yaw)


func propeller_state() -> Dictionary:
	return _prop_handed.duplicate()


## ---- the propeller -------------------------------------------------------------------------------------------------

## THE SPINNER, THE TWO BLADES and the disc they sweep, each its own node on the thrust line: the spinner looks the same at
## any angle and stays when the blades give way to the disc.
func _propeller(paint: Material) -> void:
	var hub := Vector3(0.0, height(HUB_H), station(PROP_S))
	var tool := _tool()
	# The spinner, from its tip forward of the propeller's plane to its base at the cowl's face.
	var rows: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.08, 0.10), Vector2(0.20, 0.15),
		Vector2(SPINNER_LENGTH, SPINNER_RADIUS)]
	tool.set_smooth_group(-1)
	const SIDES := 8
	for i in range(rows.size() - 1):
		for k in range(SIDES):
			var t0: float = TAU * float(k) / SIDES
			var t1: float = TAU * float(k + 1) / SIDES
			var a := Vector3(cos(t0) * rows[i].y, sin(t0) * rows[i].y, rows[i].x - PROP_S)
			var b := Vector3(cos(t1) * rows[i].y, sin(t1) * rows[i].y, rows[i].x - PROP_S)
			var c := Vector3(cos(t1) * rows[i + 1].y, sin(t1) * rows[i + 1].y, rows[i + 1].x - PROP_S)
			var d := Vector3(cos(t0) * rows[i + 1].y, sin(t0) * rows[i + 1].y, rows[i + 1].x - PROP_S)
			_quad(tool, a, b, c, d, Vector3(a.x + c.x, a.y + c.y, 0.0) * 0.5 + Vector3(0, 0, -0.02), WHITE)
	tool.set_smooth_group(-1)
	_add(exterior, "Spinner", tool, paint, false, hub)
	tool = _tool()
	# TWO BLADES: chord and twist along the radius, ESTIMATE; painted tips.
	var stations: Array[Vector3] = [Vector3(0.14, 0.09, 0.80), Vector3(0.32, 0.15, 0.58), Vector3(0.80, 0.12, 0.26),
		Vector3(0.89, 0.10, 0.23), Vector3(PROP_RADIUS, 0.06, 0.21)]  # (radius, chord, pitch)
	for blade in [1.0, -1.0]:
		for i in range(stations.size() - 1):
			var a: Vector3 = stations[i]
			var b: Vector3 = stations[i + 1]
			var tint: Color = BLADE_TIP if a.x >= 0.88 else BLADE
			var fa := _blade_section(blade, a)
			var fb := _blade_section(blade, b)
			var axis := Vector3(0.0, blade * (a.x + b.x) * 0.5, 0.0)
			for k in range(4):
				var n: int = (k + 1) % 4
				_quad(tool, fa[k], fb[k], fb[n], fa[n], (fa[k] + fa[n] + fb[k] + fb[n]) * 0.25 - axis, tint)
		var tip := _blade_section(blade, stations[stations.size() - 1])
		_quad(tool, tip[0], tip[1], tip[2], tip[3], Vector3(0, blade, 0), BLADE_TIP)
	var node := _add(exterior, "Propeller", tool, paint, false, hub)
	surfaces["Propeller"] = node.mesh.get_aabb()
	surfaces["Propeller"] = AABB((surfaces["Propeller"] as AABB).position + hub, (surfaces["Propeller"] as AABB).size)

	var disc := _tool()
	const DISC_SIDES := 20
	for k in range(DISC_SIDES):
		var t0: float = TAU * float(k) / DISC_SIDES
		var t1: float = TAU * float(k + 1) / DISC_SIDES
		var o0 := Vector3(cos(t0), sin(t0), 0.0) * PROP_RADIUS
		var o1 := Vector3(cos(t1), sin(t1), 0.0) * PROP_RADIUS
		_quad(disc, o0 * 0.17, o1 * 0.17, o1, o0, Vector3.FORWARD, Color(0.12, 0.12, 0.13))
	var blur := StandardMaterial3D.new()
	blur.vertex_color_use_as_albedo = true
	blur.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur.cull_mode = BaseMaterial3D.CULL_DISABLED
	var disc_node := _add(exterior, "PropellerDisc", disc, blur, false, hub)
	disc_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc_node.visible = false


## A blade's section at `row` (radius, chord, pitch in radians): four corners, leading edge first, thickness 12% of chord.
static func _blade_section(blade: float, row: Vector3) -> Array[Vector3]:
	var r: float = row.x
	var chord: float = row.y
	var pitch: float = row.z
	# The chord runs across the blade in the propeller's plane, turned toward the flight path by the pitch.
	var along := Vector3(blade * cos(pitch), 0.0, -sin(pitch))
	var normal := Vector3(blade * sin(pitch), 0.0, cos(pitch))
	var centre := Vector3(0.0, blade * r, 0.0)
	var thick: float = chord * 0.12 * 0.5
	return [centre + along * chord * 0.45, centre + normal * thick, centre - along * chord * 0.55, centre - normal * thick]


## ---- shapes -------------------------------------------------------------------------------------------------------

## A SLAB OVER A PLAN PATCH: `point.call(x, c, face)` gives the surface, and the patch from `x0` to `x1` and chord `c0` to
## `c1` is closed with its four edges. Cut along the chord where the section changes most, so the nose is round.
func _slab(tool: SurfaceTool, point: Callable, x0: float, x1: float, c0: float, c1: float, label: String, side: float) -> void:
	_slab_about(tool, point, x0, x1, c0, c1, label, Vector3.UP, Vector3(side, 0.0, 0.0), UNDER)


## THE CHORDWISE CUTS every slab is split at: six panels along a chord, with the closest pair round the leading edge where
## an aerofoil turns fastest. Eleven cuts drew a smooth wing and cost half again as many triangles.
const _CUTS: Array[float] = [0.0, 0.05, 0.18, 0.45, 0.73, 0.78, 1.0]


func _slab_about(tool: SurfaceTool, point: Callable, x0: float, x1: float, c0: float, c1: float, label: String,
		top: Vector3, outward: Vector3, under: Color) -> void:
	if x1 <= x0 or c1 <= c0:
		return
	var cuts: Array[float] = [c0]
	for cut in _CUTS:
		if cut > c0 + 0.005 and cut < c1 - 0.005:
			cuts.append(cut)
	cuts.append(c1)
	# Spanwise, a panel longer than two metres is cut once, so a twisted or tapered surface keeps its shape in two facets.
	var spans: Array[float] = [x0]
	var pieces: int = maxi(1, ceili((x1 - x0) / 2.0))
	for i in range(1, pieces):
		spans.append(lerpf(x0, x1, float(i) / pieces))
	spans.append(x1)
	var box := AABB()
	var found := false
	# FLAT, like every panel here: six facets along a chord read as a wing, and smoothing them read as moulding.
	for n in range(spans.size() - 1):
		var xa: float = spans[n]
		var xb: float = spans[n + 1]
		for i in range(cuts.size() - 1):
			var a: float = cuts[i]
			var b: float = cuts[i + 1]
			for face in [1.0, -1.0]:
				var p: Array[Vector3] = [point.call(xa, a, face), point.call(xb, a, face), point.call(xb, b, face),
					point.call(xa, b, face)]
				_quad(tool, p[0], p[1], p[2], p[3], top * face + Vector3.FORWARD * (0.3 if a < 0.1 else 0.0), WHITE if face > 0.0 else under)
				for corner in p:
					box = box.expand(corner) if found else AABB(corner, Vector3.ZERO)
					found = true
	tool.set_smooth_group(-1)
	# The inboard and outboard ends, and the front and back edges.
	for i in range(cuts.size() - 1):
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		_quad(tool, point.call(x0, a, 1.0), point.call(x0, b, 1.0), point.call(x0, b, -1.0), point.call(x0, a, -1.0),
			-outward, under)
		_quad(tool, point.call(x1, a, 1.0), point.call(x1, b, 1.0), point.call(x1, b, -1.0), point.call(x1, a, -1.0),
			outward, under)
	for n in range(spans.size() - 1):
		var xa: float = spans[n]
		var xb: float = spans[n + 1]
		_quad(tool, point.call(xa, c0, 1.0), point.call(xb, c0, 1.0), point.call(xb, c0, -1.0), point.call(xa, c0, -1.0),
			Vector3.FORWARD, under)
		_quad(tool, point.call(xa, c1, 1.0), point.call(xb, c1, 1.0), point.call(xb, c1, -1.0), point.call(xa, c1, -1.0),
			Vector3.BACK, under)
	surfaces[label] = box


## A FLAT TAPERED BAR from `a` to `b`: `wide` along the flight path at `a` narrowing to `narrow`, `thick` across.
func _bar(tool: SurfaceTool, a: Vector3, b: Vector3, wide: float, narrow: float, thick: float, tint: Color) -> void:
	tool.set_smooth_group(-1)
	var along: Vector3 = (b - a).normalized()
	var fore: Vector3 = (Vector3.BACK - along * along.dot(Vector3.BACK)).normalized()
	var across: Vector3 = along.cross(fore).normalized()
	var corners := func(at: Vector3, w: float) -> Array[Vector3]:
		return [at + fore * w * 0.5 + across * thick * 0.5, at - fore * w * 0.5 + across * thick * 0.5,
			at - fore * w * 0.5 - across * thick * 0.5, at + fore * w * 0.5 - across * thick * 0.5]
	var ca: Array[Vector3] = corners.call(a, wide)
	var cb: Array[Vector3] = corners.call(b, narrow)
	var outs: Array[Vector3] = [across, -fore, -across, fore]
	for k in range(4):
		_quad(tool, ca[k], ca[(k + 1) % 4], cb[(k + 1) % 4], cb[k], outs[k] if k % 2 == 0 else outs[k], tint)
	_quad(tool, ca[0], ca[1], ca[2], ca[3], -along, tint)
	_quad(tool, cb[0], cb[1], cb[2], cb[3], along, tint)


## A ROD from `a` to `b`, `sides`-sided and flat: four by default, which is the reference airframe's square strut
## (`hawkeye_airframe.gd` builds every leg and antenna as a box).
func _rod(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float, tint: Color, sides: int = 4) -> void:
	var along: Vector3 = (b - a).normalized()
	var across: Vector3 = along.cross(Vector3.FORWARD if absf(along.z) < 0.9 else Vector3.UP).normalized()
	var other: Vector3 = along.cross(across)
	for k in range(sides):
		var t0: float = TAU * float(k) / sides
		var t1: float = TAU * float(k + 1) / sides
		var r0: Vector3 = (across * cos(t0) + other * sin(t0)) * radius
		var r1: Vector3 = (across * cos(t1) + other * sin(t1)) * radius
		_quad(tool, a + r0, a + r1, b + r1, b + r0, r0 + r1, tint)
	for k in range(sides):
		var t0: float = TAU * float(k) / sides
		var t1: float = TAU * float(k + 1) / sides
		var r0: Vector3 = (across * cos(t0) + other * sin(t0)) * radius
		var r1: Vector3 = (across * cos(t1) + other * sin(t1)) * radius
		_tri(tool, b, b + r0, b + r1, along, tint)
		_tri(tool, a, a + r0, a + r1, -along, tint)


## A WHEEL on an axle along x: an eight-sided tyre band and two hubs, flat-shaded, which is what an old-school wheel is.
func _wheel(tool: SurfaceTool, centre: Vector3, radius: float, wide: float) -> void:
	const SIDES := 8
	for k in range(SIDES):
		var t0: float = TAU * float(k) / SIDES
		var t1: float = TAU * float(k + 1) / SIDES
		var r0 := Vector3(0.0, cos(t0), sin(t0)) * radius
		var r1 := Vector3(0.0, cos(t1), sin(t1)) * radius
		var h := Vector3(wide * 0.5, 0.0, 0.0)
		tool.set_smooth_group(-1)
		_quad(tool, centre - h + r0, centre - h + r1, centre + h + r1, centre + h + r0, r0 + r1, TYRE)
		for face in [1.0, -1.0]:
			var hub: Vector3 = centre + h * face
			_tri(tool, hub, hub + r0, hub + r1, Vector3(face, 0.0, 0.0), METAL)


func _box(tool: SurfaceTool, at: Vector3, size: Vector3, tint: Color, turn: Basis = Basis.IDENTITY) -> void:
	tool.set_smooth_group(-1)
	var half: Vector3 = size * 0.5
	for axis in range(3):
		for sign in [1.0, -1.0]:
			var n := Vector3.ZERO
			n[axis] = sign
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var c: Vector3 = n * half[axis]
			var du: Vector3 = u * half[(axis + 1) % 3]
			var dv: Vector3 = v * half[(axis + 2) % 3]
			_quad(tool, at + turn * (c - du - dv), at + turn * (c + du - dv), at + turn * (c + du + dv),
				at + turn * (c - du + dv), turn * n, tint)


## A QUAD from four corners in order round it, wound to face `out`.
func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, tint: Color) -> void:
	_tri(tool, a, b, c, out, tint)
	_tri(tool, a, c, d, out, tint)


## ONE TRIANGLE, wound clockwise as seen from `out` -- Godot's front face -- or skipped if it has no area.
func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-12:
		return
	if normal.dot(out) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
	tool.set_color(tint)
	tool.add_vertex(a)
	tool.set_color(tint)
	tool.add_vertex(b)
	tool.set_color(tint)
	tool.add_vertex(c)


func _record(label: String, rings: Array) -> void:
	var box := AABB()
	var found := false
	for ring in rings:
		for corner in ring:
			box = box.expand(corner) if found else AABB(corner, Vector3.ZERO)
			found = true
	surfaces[label] = box


func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


func _add(parent: Node3D, label: String, tool: SurfaceTool, material: Material, detail: bool,
		at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	node.material_override = material
	node.position = at
	if detail:
		node.visibility_range_end = DETAIL_RANGE
		node.visibility_range_end_margin = DETAIL_HYSTERESIS
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	parent.add_child(node)
	return node


func _paint(double_sided: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.45
	material.metallic = 0.05
	if double_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
