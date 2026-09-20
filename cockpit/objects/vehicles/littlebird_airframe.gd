@tool
extends Node3D
class_name LittleBirdAirframe
## A BOEING (MD HELICOPTERS) MH-6M LITTLE BIRD, DRAWN: TWO PILOTS SIDE BY SIDE IN AN OPEN EGG. The egg-shaped cabin that
## is nearly all glass forward of the pilots, both doors off, a six-bladed main rotor on a short mast, the thin tail boom
## with a T-tail and endplates, a four-bladed tail rotor on the PORT side, skids, a FLIR ball under the chin, and the
## outboard benches the MH-6 carries troops on.
##
## THE MH-6M AND NOT ANOTHER LITTLE BIRD. Six main blades (the MH-6J and the civil MD 500E have five), four tail blades,
## the T-tail with endplates of the MD 530F family rather than the OH-6A's canted stabiliser, and the FLIR -- all as
## [FOX] draws them. Stay with this variant: a five-bladed rotor on this body is a different aircraft.
##
## THE OPEN COCKPIT IS THE FEATURE, and the user said so: "keep in mind it has a very open cockpit so make sure we
## preserve this, pilot and copilot should be able to see very well." So: the nose is glass from the roof to under the
## pilots' heels (the upper windscreen, the chin windows and the roof windows, each cut from [FOX]'s own outlines), the
## doors are OFF -- their openings are cut from the drawn door outlines, not left as painted panels -- and the only
## frames in front of a pilot are the centre post between the two of them and the thin band where the upper windscreen
## meets the chin window, 0.29 m below the eye. `tests/littlebird.gd` fires rays from both eyes and holds the view to it.
##
## PACKED IN CLOSE, AND NOT WIDENED. The pod is [W]'s published 1.402 m across, NARROWER than the drawing, and the two
## eyes are 0.60 m apart. Kind 28 seats the pilot and the copilot there; the benches are drawn and nobody rides them. Both players still fit the `tests/seat_room.gd` envelope with no widening at all -- because the
## doors are off, a shoulder or a turned head beside the door is in the open air, as it is in the real aircraft.
##
## THE SIMULATION GIVES THE SIZE, THIS GIVES THE SHAPE. The box is `kind_geometry`'s `extents` for kind 28,
## `Sim.Kind.LITTLEBIRD`. Every other size is MEASURED off [FOX], a VECTOR three-view read in its own
## document units by `craft/littlebird/measure_drawing.py` -- see `craft/littlebird/sources.md` for the licence, the
## scale and every disagreement. THE SCALE IS THE ROTOR: [W]'s 27 ft 4.8 in over the side view's blade tips is
## 0.032921 m a unit, and nothing else was fitted. The fuselage then measures 7.443 m nose to tail against [W]'s 7.498
## and 9.899 m with the rotors turning against [W]'s 9.936, neither of which the scale was set by.
##
## THE FRAME IS THE DRAWING'S OWN. `station(x)` turns the side view's x (units, increasing aft) into a z, and `height(y)`
## its y (units, increasing DOWN the page) into a y. The datum is y 297.86, the bottom of the skids, so heights are over
## the ground with the skids on it. The plan view's y maps to the side view's x with no offset (its roof windows land on
## the side view's to 0.5 units); its widths are 5 per cent wide against its own front view on TWO features (the cabin and
## the skid track), so a plan width is multiplied by `PLAN_X`. THE POD alone is multiplied by `POD_WIDTH_SCALE` instead,
## to [W]'s published width: the drawing draws it 1.525 m (front) and 1.603 m (plan) against [W]'s 1.402. A published
## figure with no stated datum is weak evidence (`modelling_here.md` section 2), but a TRACED drawing is weaker: this one's
## plan rotor is 8 per cent short of its side view's and its front view is 4 per cent squashed in height. The user asked
## for the small size.
##
## THE HEIGHT IS AS DRAWN, AND DISAGREES. The hub's top is 2.979 m over the skids on [FOX] against [W]'s 2.667 m (8 ft
## 9 in, the MD 530F's with standard gear). The MH-6 stands on the tall gear it carries the benches on, and the drawing is
## of an MH-6; the difference is 0.31 m and is reported, not hidden.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT. The Hawkeye is the reference (`modelling_here.md` section 4):
## - THE POD: 16 facets a ring (the Hawkeye's fuselage has 20) through 21 measured rings. The ring's shape is the front
##   view's cabin section -- seven points a side at the drawn depth shares -- stretched to each station's top, bottom and
##   plan width. The glazing and the door openings are CUT from the facets along [FOX]'s outlines rather than chosen facet
##   by facet, so a door's edge is where the drawing puts it and not a staircase of facets.
## - BOOM 8 a ring, COWLING 7, SKID TUBE 6, MAST 6, HUB 12, FLIR 8. A blade is SIX points round (NACA 0012, as [W] says).
## Every face carries its own normal, so no edge is smoothed.
##
## BUILT ON `RotorcraftKit`, as `LightHelicopterAirframe`, `Uh60Airframe` and `ChinookAirframe` are: its skin and glass
## materials, and its ROTORS -- lofted blades on a hub that `set_rotors(turning, collective, seconds)` turns on the shared
## physics clock, with the faint swept disc once the collective is up. The POD IS NOT the kit's `loft`: that chooses whole
## facets as skin, glass or opening, and this pod's glazing and door openings are CUT along the drawing's own outlines
## (below), which is what keeps a door's edge where the drawing puts it. It answers `set_rotors`, `rotors_state`,
## `cabin_room` and `show_layers` as the other three do, so `VehicleView._rotorcraft` can take it when it is a kind.
##
## NOT IN VehicleView's `_body`: `_show_body` paints one flat material over every mesh there, and this airframe's colour is
## in its vertices (`lane/fleet`, Hawkeye).

## THE SIMULATION OWNS THE SIZE since 2026-09-18: kind 28, `littlebird_shape` in `cockpit_world.cpp`, carries the box
## this airframe was drawn round -- [W]'s 1.402 m pod width, the skids to the cowling's top (2.578 m) and the nose to the
## T-tail (7.443 m) -- and the crew's seats under `crew_eyes()`. `dress()` asks the simulation when it is handed nothing.
## `tests/littlebird.gd` holds the two to each other.
const KIND: int = Sim.Kind.LITTLEBIRD

## [W]: the published figures, in inches, converted where they are used.
const ROTOR_DIAMETER: float = 328.8 * 0.0254
const WIDTH: float = 55.2 * 0.0254
## The side view's blade tips, x 223.75 to 477.44: THE SCALE.
const DRAWN_ROTOR: float = 253.69
const UNIT: float = ROTOR_DIAMETER / DRAWN_ROTOR

## THE DATUMS, on [FOX], in its document units.
const NOSE_X: float = 288.98
const GROUND_Y: float = 297.86
const PLAN_NOSE_Y: float = 64.87
## The plan's widest half-width, and the front view's: the plan is 5 per cent wide against the front, and the same ratio
## comes back from the skid track (0.988 m in plan, 0.937 in front), so the plan is scaled across by PLAN_X.
const PLAN_HALF_MAX: float = 24.34
const FRONT_HALF_MAX: float = 23.17
const PLAN_X: float = FRONT_HALF_MAX / PLAN_HALF_MAX
## The pod, and only the pod, to [W]'s published width.
const POD_WIDTH_SCALE: float = (WIDTH * 0.5) / (PLAN_HALF_MAX * UNIT)

## THE PAINT. The 160th's Little Birds are black; a black that is not quite black, so the facets read. ESTIMATE.
const BODY := Color(0.17, 0.18, 0.19)
const TOP := Color(0.13, 0.14, 0.15)
const TRIM := Color(0.07, 0.07, 0.08)
const EXHAUST := Color(0.03, 0.03, 0.03)
const BLADE := Color(0.10, 0.10, 0.11)
const TIP := Color(0.78, 0.74, 0.30)
const METAL := Color(0.36, 0.36, 0.37)
const LENS := Color(0.04, 0.05, 0.08)
const FLOOR := Color(0.24, 0.24, 0.23)
## The glazing: clear acrylic, faintly grey. Its alpha is what makes the open cockpit open in a picture.
const GLASS := Color(0.62, 0.70, 0.74, 0.18)

## THE POD, ring by ring [FOX]: [side x, top y, bottom y, plan half-width], every figure printed by `measure_drawing.py`.
## Forward of x 342.4 the top is the cabin roof off the side outline; aft of it the outline's top is the engine cowling,
## so the pod's own top is the fairing line under it (path3843) and the cowling is its own part.
const POD: Array = [
	[289.5, 252.77, 261.99, 5.19], [291.0, 248.64, 266.05, 10.30], [293.0, 245.39, 269.02, 14.23],
	[296.0, 241.53, 271.75, 17.85], [300.0, 237.63, 274.24, 20.57], [305.0, 233.99, 276.58, 22.26],
	[310.0, 231.30, 278.40, 23.36], [315.0, 229.39, 279.83, 24.01], [320.0, 228.11, 280.91, 24.30],
	[326.0, 227.23, 281.75, 24.32], [332.0, 226.98, 282.14, 24.17], [338.0, 227.26, 282.47, 23.89],
	[342.0, 227.62, 282.63, 23.57], [348.0, 228.47, 282.76, 22.92], [356.0, 230.40, 282.68, 21.83],
	[364.0, 233.04, 282.23, 20.44], [372.0, 236.30, 280.74, 18.65], [380.0, 240.14, 278.36, 16.48],
	[388.0, 244.56, 275.72, 13.83], [396.0, 249.44, 272.66, 10.49], [404.0, 254.69, 269.02, 6.15],
]
## THE SECTION [FOX], front view: [depth share down from the roof, half-width share], seven a side. The roof and keel
## points on the centreline make sixteen.
const SECTION: Array = [[0.039, 0.557], [0.076, 0.729], [0.169, 0.921], [0.393, 1.000], [0.674, 0.959],
	[0.879, 0.691], [0.972, 0.328]]
const POD_SIDES: int = 16

## THE GLAZING [FOX], each outline simplified to 0.35 units off the drawn path.
## - The UPPER WINDSCREEN, side view (path3837), its top edge carried above the fuselage so the roof's own curve is inside.
const UPPER_WINDSCREEN: Array = [[292.6, 246.5], [302.6, 246.6], [305.9, 242.2], [310.5, 238.1], [315.8, 234.6],
	[321.4, 232.4], [321.4, 222.0], [310.0, 224.0], [298.0, 232.0], [289.0, 243.0], [286.0, 246.5]]
## - The CHIN WINDOW, side view (path3309), carried ahead of the nose. Between it and the upper windscreen the drawing
##   leaves a band from y 246.5 to 248.1 -- the one horizontal frame, 0.29 m below the eye.
const CHIN_WINDOW: Array = [[286.0, 248.1], [302.1, 248.1], [300.8, 256.8], [302.1, 268.5], [298.9, 273.9],
	[292.9, 268.5], [286.0, 262.0]]
## - The same upper windscreen seen from ABOVE (path4798), [plan out, plan y], starboard; mirrored to port. The roof's
##   top facets are cut by this, since a side outline cannot see them.
const NOSE_GLASS_PLAN: Array = [[0.55, 63.0], [0.55, 96.15], [17.6, 96.2], [22.6, 80.4], [21.4, 76.1], [19.4, 72.8],
	[16.8, 70.3], [6.9, 65.5], [0.55, 63.0]]
## - The ROOF WINDOWS over the pilots' heads (rect4825, path4832), [plan out, plan y].
const ROOF_WINDOWS: Array = [[1.0, 97.4], [17.4, 97.4], [17.0, 105.2], [18.1, 115.2], [1.0, 115.2]]
## THE DOORS, OFF [FOX]: the front door (path3827) and the rear (path3845), side view. Their outlines are cut out of the
## pod's side and nothing is drawn in them.
const FRONT_DOOR: Array = [[305.4, 246.6], [304.5, 268.6], [320.2, 270.8], [328.8, 258.4], [333.3, 250.1], [335.9, 241.8],
	[336.2, 238.0], [335.6, 235.8], [334.2, 233.9], [331.7, 232.6], [328.1, 232.3], [323.1, 233.3], [320.1, 234.4],
	[312.4, 239.2], [307.8, 243.3]]
const REAR_DOOR: Array = [[343.4, 233.6], [328.5, 271.5], [356.8, 271.8], [358.2, 271.3], [359.2, 270.0], [362.4, 247.2],
	[362.4, 243.8], [361.7, 240.8], [359.6, 237.2], [355.6, 234.4]]
## Which facets a side outline may cut: a facet looking mostly UP is cut by the plan's outlines instead, and a door is
## only cut through a facet that looks at least this far sideways.
const TOP_FACING: float = 0.6
const SIDE_FACING: float = 0.25
## And a facet looking this far DOWN is belly, and nothing cuts it: the chin window wraps under the nose's curve to below
## the floor, and a lower threshold would leave the pilots' heels on painted metal.
const BELLY_FACING: float = 0.85
## THE CENTRE POST between the two windscreens: 0.06 m across at the roof and 0.30 at the chin's foot. The plan view draws
## the gap between the two glass halves 1.1 units (0.036 m) across and the front view 4.3 (0.14 m); the plan looks
## straight down on the member and the front view's panes are traced outlines with a stroke, so the post is the plan's
## and a little, and the first build's 0.13 m -- the front view's -- put 7 of each pilot's 78 forward sightlines on it.
## At the chin's foot the front view's 10.2 units is the instrument console's face, where a pilot is not looking out.
const POST_HALF: Vector2 = Vector2(0.03, 0.15)

## THE ENGINE COWLING [FOX]: [side x, top y, plan half-width] -- its top off the side outline, its width off the plan's
## fairing (path3209). Its underside is buried in the pod's top.
const COWLING: Array = [[343.0, 226.01, 8.65], [346.0, 220.99, 9.23], [352.0, 219.55, 9.40], [360.0, 219.64, 9.36],
	[370.0, 220.06, 9.21], [380.0, 220.88, 8.38], [390.0, 222.14, 5.83], [397.0, 232.3, 2.2]]
## THE MAST AND HUB [FOX]: the mast rect3958, 4.2 units across, from the cowling up to the hub; the swashplate's base
## rect3956; the hub cap path3951, 16.5 units across, y 207.35 to 210.83. The blades turn in the plane y 214.30.
const HUB_X: float = 351.74
const ROTOR_Y: float = 214.30
const HUB_CAP: Vector3 = Vector3(8.28, 207.35, 210.83)  # radius, top y, bottom y
const MAST_HALF: float = 2.1
const BASE_PLATE: Vector3 = Vector3(7.3, 219.25, 220.16)  # radius, top y, bottom y
## THE BLADES. Chord 7.21 in, [NPS]'s OH-6A blade with its trailing-edge tab: the drawing's blades are 0.26 m fat, and
## its plan rotor is 8 per cent short, so they are not measured off it. The section, taper and painted tip are
## `RotorcraftKit.blade`'s, the same blade every helicopter here has.
const BLADES: int = 6
const CHORD: float = 7.21 * 0.0254

## THE TAIL BOOM [FOX]: [side x, top y, bottom y, plan half-width], its root buried in the cowling and the pod.
const BOOM: Array = [[394.0, 231.8, 251.5, 6.3], [404.0, 233.11, 251.0, 5.9], [412.0, 234.01, 250.5, 5.52],
	[420.0, 234.91, 249.42, 5.20], [440.0, 237.17, 246.67, 4.40], [460.0, 239.42, 247.26, 3.60],
	[480.0, 241.67, 247.85, 2.80], [501.5, 245.0, 247.4, 2.02]]
const BOOM_SIDES: int = 8
## THE FIN, upper and lower, one outline (path3871), and the tail skid under it (path3879). Half-thickness 0.038 m at the
## root to 0.012 at the tip: [NPS]'s OH-6A upper fin is 3 in thick at the root and 0.7 in at the tip.
const FIN: Array = [[486.1, 243.7], [502.2, 212.4], [511.2, 212.1], [504.7, 236.5], [500.0, 238.4], [498.3, 243.1],
	[495.4, 245.5], [498.0, 248.3], [499.1, 268.2], [493.9, 268.5], [485.6, 245.2]]
const FIN_HALF: Vector2 = Vector2(0.038, 0.012)
const TAIL_SKID: Array = [[495.4, 268.3], [499.3, 272.1]]
## THE T-TAIL [FOX]: the stabiliser's chord off the plan (path4110), [half-span share, plan y], on the fin's top at
## y 212.3; its span off the FRONT view (path4406), 51.15 units over its tips, and its endplates (rect4408, path4413)
## 52.5 units apart middle to middle, 53.75 over their outsides: 1.77 m. The plan draws the endplates 57.3 units apart
## -- 1.80 m once its 5 per cent is taken out, agreeing -- and BOTH views draw the whole T-tail 0.06 to 0.12 m to
## starboard of the boom. That offset is left out and written down: nothing else in the drawing is off the centreline,
## and the first build, which read one endplate's distance from the plan's centre as the half-span, came out 1.55 m.
const STABILISER: Array = [[0.0, 275.17], [1.0, 280.6], [1.0, 288.5], [0.0, 288.4]]
const STABILISER_HALF: float = 25.575
const STABILISER_Y: float = 212.3
const ENDPLATE: Array = [[510.43, 206.98], [503.71, 214.21], [503.71, 218.86], [510.43, 219.12], [515.08, 207.49]]
const ENDPLATE_OUT: float = 26.25
## THE TAIL ROTOR [FOX]: hub (501.70, 246.58) in side view, radius 23.89 units (the plan's edge-on blade, rect4122 and
## rect4124), 0.310 m to PORT of the centreline. Four blades as drawn; chord 4.81 in, [NPS]'s OH-6A tail blade.
const TAIL_HUB: Vector2 = Vector2(501.70, 246.58)
const TAIL_RADIUS: float = 23.89
const TAIL_OUT: float = 0.310
const TAIL_BLADES: int = 4
const TAIL_CHORD: float = 4.81 * 0.0254
## THE HUBS, for `RotorcraftKit.rotor`: the main hub's radius is the drawn cap's (path3951, 8.28 units, 0.27 m) and its
## height puts the kit's hub top at the drawn cap's top, 2.979 m over the skids; the tail hub is an ESTIMATE.
const HUB_HEIGHT: float = 0.24
const TAIL_HUB_RADIUS: float = 0.06
const TAIL_HUB_HEIGHT: float = 0.10

## THE SKIDS [FOX]: the tube's centreline in side view (rect3816), up-turned at the front; 2.46 units through, its bottom
## on the ground. Each skid's middle 0.937 m out, the front view's (rect3983, path3998).
const SKID_LINE: Array = [[288.3, 291.4], [290.3, 294.5], [293.0, 296.0], [297.0, 296.55], [369.5, 296.63]]
const SKID_RADIUS: float = 1.23
const SKID_OUT: float = 0.937
## THE LEGS [FOX], side view: [top x, top y, foot x, foot y] of the front leg (path3765) and the aft (path3808). A leg's
## top is buried in the pod wherever the pod is at that height, which is asked of the pod, not typed.
const LEGS: Array = [[326.2, 275.5, 320.3, 295.6], [366.4, 281.3, 364.0, 295.6]]
## THE BENCHES, one each side: the plank in side view (rect4240), x 328.75 to 372.75, y 277.47 to 279.97, MEASURED. How
## far out it reaches is an ESTIMATE: the plan hides it under the cabin's bulge, and a seated soldier's legs hang outboard
## of the skid, so it runs from 0.62 m to 1.05 m out, past the skid by 0.11. Two brackets carry it from the pod.
const BENCH: Rect2 = Rect2(328.75, 277.47, 44.0, 2.50)
const BENCH_OUT: Vector2 = Vector2(0.62, 1.05)
const BENCH_BRACKETS: Array = [334.0, 366.0]
## THE FLIR BALL [FOX] under the chin (path5062), centre (294.57, 278.91), 4.68 units round, on its mount (rect5060).
const FLIR: Vector3 = Vector3(294.57, 278.91, 4.68)
const FLIR_SIDES: int = 8

## THE CREW, ESTIMATE, reasoned from the drawing. The eye at x 328.5, y 237.3: 1.30 m aft of the nose and 1.99 m over the
## skids, in the front door's opening, 0.15 m under the door's top and 0.25 m ahead of the pillar behind it. EYE_OUT is
## the seat's middle: the two eyes 0.60 m apart, the pilot to STARBOARD as in every MD 500.
##
## PINNED BY THE EGG FROM ABOVE AND BELOW, and that is why these numbers and no others. A seat's ANCHOR is
## `CockpitStation.EYE_HEIGHT` (1.35 m) under its eye, and `tests/shell_room.gd` wants the anchor inside the craft as
## well as the head: the egg narrows so fast under the pilots that at the first eye (y 238.5, 0.33 m out) the anchor
## stood 6 cm outside the belly. `seat_room` wants 0.25 m over the eye, and the roof there is 0.29. So the eye went up
## 0.04 m, as far as the roof allows (0.25 left), and in 0.03 m each side, which is where the anchor is inside the belly
## by 0.8 drawing units. Two pilots 0.60 m apart are still clear of seat_room's 0.53.
const EYE_STATION: float = 328.5
const EYE_HEIGHT: float = 237.3
const EYE_OUT: float = 0.30
## THE CABIN FLOOR IS AT THE DOORS' SILLS, WHERE THE STATION'S FOOTWELL IS. A seat stands its occupant's eye
## `CockpitStation.EYE_HEIGHT` (1.35 m) over its anchor and lays its footwell `CockpitStation.FLOOR` (0.04) over that --
## but the egg is only 0.28 to 0.35 m wide each side at that height, so a pilot's footwell stood out of the belly under
## each open door. The kind's catalogue entry lifts it 0.20 m ("footwell", team-lead's option A, 2026-09-18), to where
## the egg is 0.5 m wide and the real aircraft's floor is, and the drawn floor is its top: y = the eye's 237.3 +
## (1.35 - 0.04 - 0.20) / UNIT = 271.02, 1.11 m under the eye. The player's real feet are 0.20 m under it, which nothing
## tracks. It runs from where the chin has room for it to the rear door.
const FLOOR_Y: float = 271.02
const FLOOR_X: Vector2 = Vector2(302.0, 362.0)
## THE INSTRUMENT CONSOLE, ESTIMATE: the MD 500's small pedestal on the centreline between the pilots' knees, 0.24 m
## across and 0.30 long, its top 0.63 m under the eye, so it is under the view and not in it, standing on the chin's
## belly. The first build's box was half a metre tall and read in every picture as a crate in the nose.
const CONSOLE: Rect2 = Rect2(301.0, 257.8, 9.0, 18.2)  # x from, top y, x length, height
const CONSOLE_HALF: float = 0.12
## THE ROOM a crew is promised inside the drawn skin, `cabin_room()`: x 319.4 to 338.2 (the pilots' stations), 0.45 m
## each side of the centreline, from y 274.0 to y 232.0, where the roof's curve is at 0.45 m out. Held to the triangles
## by `tests/littlebird.gd`: the first room, 0.50 m out and up to y 229.5, had its top corners through the roof. ITS
## BOTTOM IS THE FLOOR, and was not while the floor was 0.2 m lower in the belly: the floor is published beside it all
## the same (`modelling_here.md` section 1: two different facts, two fields).
const ROOM: Rect2 = Rect2(319.4, 232.0, 18.8, 39.0)
const ROOM_HALF: float = 0.45

## Small fittings stop drawing once the whole 7.4 m helicopter is a few pixels high.
const DETAIL_RANGE: float = 450.0
const DETAIL_HYSTERESIS: float = 45.0

var _half: Vector3 = Vector3(0.701, 1.289, 3.7215)
var exterior: Node3D
var interior: Node3D
var main_rotor: Node3D
var tail_rotor: Node3D
var _rotors_handed: Dictionary = {"turning": false, "collective": 0.0, "seconds": 0.0}


## BUILT IN PLACE, after `new()`, from the simulation's geometry: what `VehicleView` hands it, or the kind's own when it
## is handed nothing (a suite, a probe).
## Everything a person sees from outside is under `Exterior`; the floor and console, which only matter from the seats,
## under `Interior`, as on the other helicopters, so `show_layers` can hide either.
func dress(geometry: Dictionary = {}) -> void:
	if get_child_count() > 0:
		return
	name = "LittleBird"
	var given: Dictionary = geometry if geometry.has("extents") else Sim.geometry_of(KIND)
	_half = given.get("extents", _half) as Vector3
	exterior = Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	interior = Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	# THE KIT'S SKIN IS DOUBLE-SIDED, which this pod needs: it is seen from inside through its open doors and its glass.
	var paint := RotorcraftKit.paint()
	var glass := RotorcraftKit.glass()

	var body := _tool()
	var glazing := _tool()
	_pod(body, glazing)
	_pod_part(body, glazing, paint, glass)
	var post := _tool()
	_post(post)
	_add(exterior, "WindscreenPost", post, paint)
	var cowling := _tool()
	_cowling(cowling)
	_add(exterior, "Cowling", cowling, paint)
	var mast := _tool()
	_mast(mast)
	_add(exterior, "Mast", mast, paint)
	var boom := _tool()
	_boom(boom)
	_add(exterior, "TailBoom", boom, paint)
	var fin := _tool()
	_fin(fin)
	_add(exterior, "Fin", fin, paint)
	var stabiliser := _tool()
	_stabiliser(stabiliser)
	_add(exterior, "Stabiliser", stabiliser, paint)
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var skid := _tool()
		_skid(skid, side)
		_add(exterior, "Skid" + named, skid, paint)
		var bench := _tool()
		_bench(bench, side)
		_add(exterior, "Bench" + named, bench, paint)
	var flir := _tool()
	_flir(flir)
	_detail(_add(exterior, "Flir", flir, paint))
	var cabin := _tool()
	_cabin(cabin)
	_detail(_add(interior, "Cabin", cabin, paint))
	_rotors(paint)


## WHERE THE LIGHTS GO, on the parts that carry them, in the craft's frame: a nav light on the outside of each
## T-tail endplate (red to port), the white tail light on the stabiliser's trailing edge on the centreline -- AFT of the
## nav lights, as `tests/lights_on_skin.gd` requires of every craft; on the fin at the boom's end it stood 0.12 m ahead
## of them -- the anti-collision
## strobe on the stabiliser's top, a beacon on the cowling's back and one under the belly. `VehicleLights` asks for these,
## as it asks the other three helicopters. Static, so it reads the kind's box rather than a built airframe's.
static func lights() -> Dictionary:
	var half: Vector3 = Sim.geometry_of(KIND).get("extents", Vector3(0.701, 1.289, 3.7215)) as Vector3
	var put := func(out: float, x: float, y: float) -> Vector3:
		return Vector3(out, -half.y + (GROUND_Y - y) * UNIT, -half.z + (x - NOSE_X) * UNIT)
	var plate: float = ENDPLATE_OUT * UNIT + 0.02
	# THE NAV LIGHTS AT THE ENDPLATES' LEADING EDGE, so the tail light on the stabiliser's trailing edge is 0.26 m aft of
	# them; `lights_on_skin` asks for 0.25, and at the endplates' middle they were 0.11.
	return {"port": put.call(-plate, 504.4, 216.5), "starboard": put.call(plate, 504.4, 216.5),
		"tail": put.call(0.0, 512.4, STABILISER_Y), "strobe": put.call(0.0, 508.0, STABILISER_Y - 1.4),
		"top": put.call(0.0, 380.0, 220.2), "bottom": put.call(0.0, 350.0, 283.4)}


func show_layers(show_exterior: bool, show_interior: bool) -> void:
	if exterior != null:
		exterior.visible = show_exterior
	if interior != null:
		interior.visible = show_interior


## A DRAWING X (units, increasing aft) as a z: the nose is at the box's front face.
func station(x: float) -> float:
	return -_half.z + (x - NOSE_X) * UNIT


## A DRAWING Y (units, increasing down the page) as a y: the skids' bottoms are at the box's bottom face.
func height(y: float) -> float:
	return -_half.y + (GROUND_Y - y) * UNIT


## A point `out` METRES from the centreline (positive to starboard), at drawing x and y.
func at(out: float, x: float, y: float) -> Vector3:
	return Vector3(out, height(y), station(x))


## A plan view's y as the side view's x: the two share a scale and the nose (`measure_drawing.py`).
static func plan_x(plan_y: float) -> float:
	return NOSE_X + (plan_y - PLAN_NOSE_Y)


## THE POD'S HALF-WIDTH in metres at drawing x, height y: its ring's plan width and the front view's section there. Used
## wherever a part has to be buried in the pod's side, so nothing is typed that the pod already knows.
func pod_out(x: float, y: float) -> float:
	var row: Array = _pod_row(x)
	var share: float = clampf((y - float(row[1])) / (float(row[2]) - float(row[1])), 0.0, 1.0)
	var points: Array = [[0.0, 0.0]] + SECTION + [[1.0, 0.0]]
	var f: float = 0.0
	for i in range(points.size() - 1):
		var a: Array = points[i]
		var b: Array = points[i + 1]
		if share >= float(a[0]) and share <= float(b[0]):
			f = lerpf(float(a[1]), float(b[1]), (share - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-6))
			break
	return f * float(row[3]) * UNIT * POD_WIDTH_SCALE


## The pod's [x, top, bottom, half] at any x, between the measured rings.
func _pod_row(x: float) -> Array:
	if x <= float(POD[0][0]):
		return POD[0]
	for i in range(POD.size() - 1):
		var a: Array = POD[i]
		var b: Array = POD[i + 1]
		if x <= float(b[0]):
			var t: float = (x - float(a[0])) / (float(b[0]) - float(a[0]))
			return [x, lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t)]
	return POD[-1]


## THE ROOM A CREW SITS IN, in the shape `VehicleView.cabin_room()` asks for (`SkyhawkAirframe.cabin_room` is the worked
## example). `room` is the largest box PROMISED inside the drawn skin, and `tests/littlebird.gd` holds it to the triangles.
func cabin_room() -> Dictionary:
	var fore: float = station(ROOM.position.x)
	var low: float = height(ROOM.end.y)
	return {
		"drawn": true,
		"floor": height(FLOOR_Y),
		"room": AABB(Vector3(-ROOM_HALF, low, fore),
			Vector3(ROOM_HALF * 2.0, height(ROOM.position.y) - low, station(ROOM.end.x) - fore)),
		"because": &"",
		"why_not": "",
		"source": "eyes ESTIMATE from the drawn doors, the floor from the seat anchors; the room MEASURED against the drawn skin, 2026-09-18",
	}


## THE CREW'S EYES, craft-local: the pilot to starboard, then the copilot to port. Where a seat should put each head.
func crew_eyes() -> Array[Vector3]:
	return [at(EYE_OUT, EYE_STATION, EYE_HEIGHT), at(-EYE_OUT, EYE_STATION, EYE_HEIGHT)]


## THE ROTORS, from what this machine holds: turning or parked, how far the collective is up, and the shared clock --
## `LightHelicopterAirframe.set_rotors`, word for word in what it does, so `VehicleView` drives every helicopter alike.
## A pure function of what it is handed. Seen from above the main rotor turns anticlockwise, as an American rotor does.
func set_rotors(turning: bool, collective: float, seconds: float) -> void:
	_rotors_handed = {"turning": turning, "collective": clampf(collective, 0.0, 1.0), "seconds": seconds}
	var shown: float = smoothstep(0.05, 0.6, collective) if turning else 0.0
	RotorcraftKit.turn(main_rotor, seconds * RotorcraftKit.MAIN_TURNS if turning else 0.0, shown)
	RotorcraftKit.turn(tail_rotor, seconds * RotorcraftKit.TAIL_TURNS if turning else 0.0, 0.0)


func rotors_state() -> Dictionary:
	return _rotors_handed.duplicate()


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


## THE POD, ONE PART OF TWO SURFACES: the painted skin and the glass. ONE PART because the egg only closes as a whole --
## the roof over a pilot's head is glass and the floor under him is skin -- and `tests/shell_room.gd` asks each drawn
## part on its own whether a point is inside it, by ray parity. Drawn as two parts, `Fuselage` and `Glazing`, neither
## held the pilots and both read as "nothing round the pilot's head" (2026-09-18). Two surfaces keep the glass its own
## material and its own draw.
func _pod_part(body: SurfaceTool, glazing: SurfaceTool, paint: Material, glass: Material) -> void:
	var mesh: ArrayMesh = body.commit()
	glazing.commit(mesh)
	mesh.surface_set_material(0, paint)
	mesh.surface_set_material(1, glass)
	var node := MeshInstance3D.new()
	node.name = "Fuselage"
	node.mesh = mesh
	exterior.add_child(node)


static func _detail(mesh: MeshInstance3D) -> void:
	mesh.visibility_range_end = DETAIL_RANGE
	mesh.visibility_range_end_margin = DETAIL_HYSTERESIS
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## ONE TRIANGLE, wound so its face looks along `out`.
static func _fan(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-14:
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


## A LOFT through matching loops, each quad wound to face away from its own loops' middle, both ends closed by fans.
## `tints` colours each facet by its index round the loop.
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
## normal and `half` its half-thickness at each point. The engine's ear clipper triangulates a concave outline.
static func _slab(tool: SurfaceTool, outline: PackedVector2Array, place: Callable, across: Vector3, half: Callable,
		tint: Color) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var top: Array = []
	var under: Array = []
	for p in outline:
		var h: float = float(half.call(p))
		top.append((place.call(p) as Vector3) + across * h)
		under.append((place.call(p) as Vector3) - across * h)
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


static func _outline(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


# ---------------------------------------------------------------------------------------------------------------------
# THE POD, and the glazing and doors cut out of it

## ONE RING's sixteen points from a POD row: the roof on the centreline, seven down the starboard side at the section's
## depth shares, the keel, and seven back up the port side.
func _ring(row: Array) -> Array:
	var x: float = row[0]
	var top: float = row[1]
	var bottom: float = row[2]
	var half: float = float(row[3]) * UNIT * POD_WIDTH_SCALE
	var points: Array = [at(0.0, x, top)]
	for s in SECTION:
		points.append(at(float(s[1]) * half, x, top + float(s[0]) * (bottom - top)))
	points.append(at(0.0, x, bottom))
	for i in range(SECTION.size() - 1, -1, -1):
		var s: Array = SECTION[i]
		points.append(at(-float(s[1]) * half, x, top + float(s[0]) * (bottom - top)))
	return points


## THE POD: sixteen flat facets a ring through the measured rings, a nose cone to the drawn tip, and the exhaust closing
## the egg's tail. Every triangle goes through `_skin`, which cuts the glazing into `glazing` and the doors out of both.
func _pod(body: SurfaceTool, glazing: SurfaceTool) -> void:
	var regions: Dictionary = _regions()
	var rings: Array = []
	for row in POD:
		rings.append(_ring(row))
	var n: int = POD_SIDES
	for r in range(rings.size() - 1):
		var here: float = (float(POD[r][0]) + float(POD[r + 1][0])) * 0.5
		var row: Array = _pod_row(here)
		var axis_y: float = height((float(row[1]) + float(row[2])) * 0.5)
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		for k in range(n):
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			var out := Vector3(mid.x, mid.y - axis_y, 0.0)
			_skin(body, glazing, regions, quad[0], quad[1], quad[2], out)
			_skin(body, glazing, regions, quad[0], quad[2], quad[3], out)
	# THE NOSE: a cone from the first ring forward to the drawn tip, half a unit ahead of it.
	var first: Array = rings[0]
	var tip: Vector3 = at(0.0, NOSE_X, (float(POD[0][1]) + float(POD[0][2])) * 0.5)
	var behind: Vector3 = tip + Vector3(0.0, 0.0, 0.3)
	for k in range(n):
		var c: Vector3 = (tip + (first[k] as Vector3) + (first[(k + 1) % n] as Vector3)) / 3.0
		_skin(body, glazing, regions, tip, first[k], first[(k + 1) % n], c - behind)
	# THE TAIL: the egg closes on the engine's exhaust, dark.
	var last: Array = rings[rings.size() - 1]
	var end_row: Array = POD[-1]
	var back: Vector3 = at(0.0, float(end_row[0]) + 1.2, (float(end_row[1]) + float(end_row[2])) * 0.5)
	for k in range(n):
		_fan(body, back, last[k], last[(k + 1) % n], Vector3.BACK, EXHAUST)


## THE OUTLINES THAT CUT THE POD, in the craft's frame: side outlines as (z, y), plan outlines as (x, z), mirrored.
func _regions() -> Dictionary:
	var side := func(points: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in points:
			out.append(Vector2(station(float(p[0])), height(float(p[1]))))
		return out
	var plan := func(points: Array, mirror: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in points:
			out.append(Vector2(mirror * float(p[0]) * UNIT * POD_WIDTH_SCALE, station(plan_x(float(p[1])))))
		return out
	return {
		"glass_side": [side.call(UPPER_WINDSCREEN), side.call(CHIN_WINDOW)],
		"doors": [side.call(FRONT_DOOR), side.call(REAR_DOOR)],
		"glass_plan": [plan.call(NOSE_GLASS_PLAN, 1.0), plan.call(NOSE_GLASS_PLAN, -1.0), plan.call(ROOF_WINDOWS, 1.0),
			plan.call(ROOF_WINDOWS, -1.0)],
	}


## ONE TRIANGLE OF SKIN, cut along the outlines that apply to where it faces: glass into `glazing`, a door into nothing,
## the rest into `body`. A facet looking up is cut by the plan's outlines, one looking sideways by the side view's.
func _skin(body: SurfaceTool, glazing: SurfaceTool, regions: Dictionary, a: Vector3, b: Vector3, c: Vector3,
		out: Vector3) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-14:
		return
	if normal.dot(out) < 0.0:
		normal = -normal
	var n: Vector3 = normal.normalized()
	var cuts: Array = []  # [polygon, plan?, glass?]
	if n.y > TOP_FACING:
		for polygon in regions["glass_plan"]:
			cuts.append([polygon, true, true])
	elif n.y > -BELLY_FACING:
		for polygon in regions["glass_side"]:
			cuts.append([polygon, false, true])
	# A DOOR IS CUT THROUGH ANY FACET THAT LOOKS SIDEWAYS, whichever way else it looks: the first build cut doors only
	# through the facets the side view owns, and the strip of roof curve over each door's top stayed in the opening.
	if absf(n.x) > SIDE_FACING and n.y > -BELLY_FACING:
		for polygon in regions["doors"]:
			cuts.append([polygon, false, false])
	var pieces: Array = [[a, b, c]]
	for cut in cuts:
		var rest: Array = []
		for tri in pieces:
			var split: Array = _split(tri, cut[0], cut[1])
			if cut[2]:
				for inside in split[0]:
					_fan(glazing, inside[0], inside[1], inside[2], n, GLASS)
			rest.append_array(split[1])
		pieces = rest
	for tri in pieces:
		_fan(body, tri[0], tri[1], tri[2], n, TOP if n.y > 0.55 else (TRIM if n.y < -0.8 else BODY))


## A TRIANGLE CUT BY A POLYGON in one projection: [the pieces inside, the pieces outside], each a list of 3D triangles
## lifted back onto the triangle's own plane. A triangle seen edge-on in that projection is not cut, but goes wholly to
## whichever side its middle is on.
static func _split(tri: Array, polygon: PackedVector2Array, plan: bool) -> Array:
	var flat := PackedVector2Array()
	for p in tri:
		var v: Vector3 = p
		flat.append(Vector2(v.x, v.z) if plan else Vector2(v.z, v.y))
	var area: float = (flat[1] - flat[0]).cross(flat[2] - flat[0])
	if absf(area) < 1e-7:
		var middle: Vector2 = (flat[0] + flat[1] + flat[2]) / 3.0
		return [[tri], []] if Geometry2D.is_point_in_polygon(middle, polygon) else [[], [tri]]
	var inside: Array = []
	var outside: Array = []
	for piece in Geometry2D.intersect_polygons(flat, polygon):
		inside.append_array(_lift(piece, flat, tri))
	for piece in Geometry2D.clip_polygons(flat, polygon):
		outside.append_array(_lift(piece, flat, tri))
	return [inside, outside]


## A 2D PIECE of a triangle's projection, triangulated and put back on the triangle in 3D by its barycentric coordinates.
static func _lift(piece: PackedVector2Array, flat: PackedVector2Array, tri: Array) -> Array:
	var out: Array = []
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(piece)
	var e0: Vector2 = flat[1] - flat[0]
	var e1: Vector2 = flat[2] - flat[0]
	var d: float = e0.cross(e1)
	var a: Vector3 = tri[0]
	var ab: Vector3 = (tri[1] as Vector3) - a
	var ac: Vector3 = (tri[2] as Vector3) - a
	for i in range(0, indices.size(), 3):
		var corners: Array = []
		for j in range(3):
			var q: Vector2 = piece[indices[i + j]] - flat[0]
			corners.append(a + ab * (q.cross(e1) / d) + ac * (e0.cross(q) / d))
		out.append(corners)
	return out


## THE CENTRE POST between the windscreens, down the nose's centreline from the roof windows' front to the chin's foot,
## standing a centimetre proud of the glass and bedded two into it.
func _post(tool: SurfaceTool) -> void:
	var line: Array = []
	for row in POD:
		if float(row[0]) <= 321.0:
			line.append(Vector2(float(row[0]), float(row[1])))
	line.reverse()
	line.append(Vector2(NOSE_X, (float(POD[0][1]) + float(POD[0][2])) * 0.5))
	for row in POD:
		if float(row[0]) <= 300.0:
			line.append(Vector2(float(row[0]), float(row[2])))
	line.push_front(Vector2(321.0, float(_pod_row(321.0)[1])))
	var loops: Array = []
	for i in range(line.size()):
		var p: Vector2 = line[i]
		var before: Vector2 = line[maxi(i - 1, 0)]
		var after: Vector2 = line[mini(i + 1, line.size() - 1)]
		var here: Vector3 = at(0.0, p.x, p.y)
		var along: Vector3 = at(0.0, after.x, after.y) - at(0.0, before.x, before.y)
		# Outward in the side plane: the profile turned a quarter, away from the pod's middle.
		var normal := Vector3(0.0, -along.z, along.y).normalized()
		if normal.dot(here - at(0.0, 330.0, 255.0)) < 0.0:
			normal = -normal
		var w: float = lerpf(POST_HALF.x, POST_HALF.y, float(i) / float(line.size() - 1))
		loops.append([here + normal * 0.012 + Vector3(w, 0, 0), here + normal * 0.012 - Vector3(w, 0, 0),
			here - normal * 0.02 - Vector3(w, 0, 0), here - normal * 0.02 + Vector3(w, 0, 0)])
	_loft(tool, loops, [TRIM])


# ---------------------------------------------------------------------------------------------------------------------
# THE COWLING, MAST, BOOM AND TAIL

## THE ENGINE COWLING on the pod's back, seven facets round, its underside three units down inside the pod.
func _cowling(tool: SurfaceTool) -> void:
	var loops: Array = []
	for row in COWLING:
		var x: float = row[0]
		var top: float = row[1]
		var bottom: float = float(_pod_row(x)[1]) + 3.0
		var half: float = float(row[2]) * UNIT * POD_WIDTH_SCALE
		var d: float = bottom - top
		loops.append([at(0.0, x, top), at(half * 0.75, x, top + 0.08 * d), at(half, x, top + 0.35 * d),
			at(half, x, bottom), at(-half, x, bottom), at(-half, x, top + 0.35 * d), at(-half * 0.75, x, top + 0.08 * d)])
	_loft(tool, loops, [TOP, BODY, BODY, TRIM, BODY, BODY, TOP])


## THE MAST from inside the cowling up into the hub, and the swashplate's base on the cowling's top.
func _mast(tool: SurfaceTool) -> void:
	var loops: Array = []
	for y in [223.0, HUB_CAP.z - 0.5]:
		var loop: Array = []
		for k in range(6):
			var t: float = TAU * float(k) / 6.0
			loop.append(at(MAST_HALF * UNIT * cos(t), HUB_X + MAST_HALF * sin(t), y))
		loops.append(loop)
	_loft(tool, loops, [METAL])
	var plate: Array = []
	for y in [BASE_PLATE.y, BASE_PLATE.z + 0.6]:
		var loop: Array = []
		for k in range(8):
			var t: float = TAU * (float(k) + 0.5) / 8.0
			loop.append(at(BASE_PLATE.x * UNIT * cos(t), HUB_X + BASE_PLATE.x * sin(t), y))
		plate.append(loop)
	_loft(tool, plate, [METAL])


## THE TAIL BOOM: eight flat facets a ring, its root in the cowling and the pod, its end inside the fin, and the tail
## rotor's gearbox reaching out to port from its end.
func _boom(tool: SurfaceTool) -> void:
	var loops: Array = []
	for row in BOOM:
		var x: float = row[0]
		var mid: float = (float(row[1]) + float(row[2])) * 0.5
		var half_h: float = (float(row[2]) - float(row[1])) * 0.5
		var half_w: float = float(row[3]) * UNIT * PLAN_X
		var loop: Array = []
		for k in range(BOOM_SIDES):
			var t: float = TAU * (float(k) + 0.5) / BOOM_SIDES
			loop.append(at(half_w * cos(t), x, mid - half_h * sin(t)))
		loops.append(loop)
	_loft(tool, loops, [TOP, BODY, BODY, TOP, TOP, BODY, BODY, TOP])
	# The gearbox: a square bar from inside the boom's end out to the tail rotor's hub.
	var hub: Vector3 = at(-TAIL_OUT, TAIL_HUB.x, TAIL_HUB.y)
	var root: Vector3 = at(0.0, TAIL_HUB.x - 1.5, TAIL_HUB.y)
	Plating.box(tool, (hub + root) * 0.5 + Vector3(0.02, 0, 0), Vector3(absf(hub.x - root.x) - 0.02, 0.09, 0.10), METAL)


## THE FIN, upper and lower in one outline with the notch the tail rotor's shaft passes, thinning from root to tip, and
## the tail skid under the lower fin.
func _fin(tool: SurfaceTool) -> void:
	var place := func(p: Vector2) -> Vector3: return at(0.0, p.x, p.y)
	var half := func(p: Vector2) -> float:
		var share: float = clampf(absf(p.y - 244.0) / 32.0, 0.0, 1.0)
		return lerpf(FIN_HALF.x, FIN_HALF.y, share)
	_slab(tool, _outline(FIN), place, Vector3.RIGHT, half, BODY)
	var a: Vector3 = at(0.0, TAIL_SKID[0][0], TAIL_SKID[0][1])
	var b: Vector3 = at(0.0, TAIL_SKID[1][0], TAIL_SKID[1][1])
	var along: Vector3 = (b - a).normalized()
	var up: Vector3 = along.cross(Vector3.RIGHT).normalized() * 0.012
	var side := Vector3(0.012, 0.0, 0.0)
	_loft(tool, [[a + up + side, a + up - side, a - up - side, a - up + side],
		[b + up + side, b + up - side, b - up - side, b - up + side]], [METAL])


## THE T-TAIL: the stabiliser across the fin's top, and an endplate at each tip.
func _stabiliser(tool: SurfaceTool) -> void:
	var outline: Array = []
	for p in STABILISER:
		outline.append([float(p[0]), float(p[1])])
	for i in range(STABILISER.size() - 1, -1, -1):
		outline.append([-float(STABILISER[i][0]), float(STABILISER[i][1])])
	var flat := PackedVector2Array()
	var seen: Dictionary = {}
	for p in outline:
		var key := Vector2(float(p[0]), float(p[1]))
		if not seen.has(key):
			seen[key] = true
			flat.append(key)
	var place := func(p: Vector2) -> Vector3: return at(p.x * STABILISER_HALF * UNIT, plan_x(p.y), STABILISER_Y)
	_slab(tool, flat, place, Vector3.UP, func(_p: Vector2) -> float: return 0.025, TOP)
	for side in [1.0, -1.0]:
		var out: float = side * ENDPLATE_OUT * UNIT
		var plate := func(p: Vector2) -> Vector3: return at(out, p.x, p.y)
		_slab(tool, _outline(ENDPLATE), plate, Vector3.RIGHT, func(_p: Vector2) -> float: return 0.012, BODY)


# ---------------------------------------------------------------------------------------------------------------------
# THE ROTORS, on RotorcraftKit

## BOTH ROTORS, from `RotorcraftKit.rotor`. THE MAIN ROTOR on the mast's axis in the drawn rotor plane: six blades of
## [NPS]'s chord to [W]'s radius exactly, blade 0 dead ahead (the kit's blade at `phase` points (cos, 0, -sin)), so a
## parked rotor reaches [W]'s length forward. THE TAIL ROTOR on the port side, its shaft pointing to port as the light
## helicopter's does, four blades, blade 0 straight aft so the parked rotor reaches [W]'s length aft.
func _rotors(paint: Material) -> void:
	main_rotor = RotorcraftKit.rotor(exterior, "MainRotor", at(0.0, HUB_X, ROTOR_Y), Basis.IDENTITY,
		ROTOR_DIAMETER * 0.5, BLADES, CHORD, HUB_CAP.x * UNIT, HUB_HEIGHT, BLADE, TIP, METAL, paint, 1.0, PI * 0.5)
	var to_port := Basis(Vector3(0.0, 1.0, 0.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
	tail_rotor = RotorcraftKit.rotor(exterior, "TailRotor", at(-TAIL_OUT, TAIL_HUB.x, TAIL_HUB.y), to_port,
		TAIL_RADIUS * UNIT, TAIL_BLADES, TAIL_CHORD, TAIL_HUB_RADIUS, TAIL_HUB_HEIGHT, BLADE, TIP, METAL, paint, 1.0,
		-PI * 0.5)


# ---------------------------------------------------------------------------------------------------------------------
# THE GEAR, THE BENCHES AND THE FITTINGS

## ONE SKID: the tube, six-sided with a FLAT on the ground, up-turned at the front, and its two legs up into the pod.
func _skid(tool: SurfaceTool, side: float) -> void:
	var out: float = side * SKID_OUT
	var loops: Array = []
	var corner: float = SKID_RADIUS / cos(PI / 6.0)
	for i in range(SKID_LINE.size()):
		var p: Vector2 = Vector2(SKID_LINE[i][0], SKID_LINE[i][1])
		var before: Vector2 = Vector2(SKID_LINE[maxi(i - 1, 0)][0], SKID_LINE[maxi(i - 1, 0)][1])
		var after: Vector2 = Vector2(SKID_LINE[mini(i + 1, SKID_LINE.size() - 1)][0],
			SKID_LINE[mini(i + 1, SKID_LINE.size() - 1)][1])
		var tangent: Vector2 = (after - before).normalized()
		# Down the page and aft is +y +x in drawing units; the tube's "down" is the tangent turned a quarter.
		var down := Vector2(-tangent.y, tangent.x)
		if down.y < 0.0:
			down = -down
		var loop: Array = []
		for k in range(6):
			var t: float = TAU * (float(k) + 0.5) / 6.0
			var q: Vector2 = p + down * corner * cos(t)
			loop.append(at(out + corner * sin(t) * UNIT, q.x, q.y))
		loops.append(loop)
	_loft(tool, loops, [TRIM])
	for leg in LEGS:
		var top_x: float = leg[0]
		var top_y: float = leg[1]
		var top: Vector3 = at(side * (pod_out(top_x, top_y) - 0.04), top_x, top_y)
		var foot: Vector3 = at(out, float(leg[2]), float(leg[3]) - SKID_RADIUS * 0.4)
		_strut(tool, top, foot, 0.13, 0.05)


## A FAIRED LEG from `top` to `foot`: `chord` fore and aft, `thick` across.
func _strut(tool: SurfaceTool, top: Vector3, foot: Vector3, chord: float, thick: float) -> void:
	var along: Vector3 = (foot - top).normalized()
	var across: Vector3 = along.cross(Vector3.BACK).normalized()
	var fore: Vector3 = across.cross(along).normalized()
	var loops: Array = []
	for p in [top, foot]:
		loops.append([p + fore * chord * 0.5, p + across * thick * 0.5, p - fore * chord * 0.5, p - across * thick * 0.5])
	_loft(tool, loops, [BODY])


## ONE BENCH: the plank outboard beside the rear cabin, and two brackets from under its inboard edge into the pod.
func _bench(tool: SurfaceTool, side: float) -> void:
	var mid_out: float = side * (BENCH_OUT.x + BENCH_OUT.y) * 0.5
	var fore: Vector3 = at(mid_out, BENCH.position.x, BENCH.position.y)
	var aft: Vector3 = at(mid_out, BENCH.end.x, BENCH.end.y)
	Plating.box(tool, Vector3(mid_out, (fore.y + aft.y) * 0.5, (fore.z + aft.z) * 0.5),
		Vector3(BENCH_OUT.y - BENCH_OUT.x, absf(fore.y - aft.y), absf(aft.z - fore.z)), BODY)
	for x in BENCH_BRACKETS:
		var root_y: float = BENCH.end.y + 1.2
		var root: Vector3 = at(side * (pod_out(x, root_y) - 0.04), x, root_y)
		var under: Vector3 = at(side * (BENCH_OUT.x + 0.04), x, BENCH.end.y - 0.3)
		_strut(tool, root, under, 0.06, 0.04)


## THE FLIR BALL under the chin: an eight-sided ball with a dark window, on a mount bedded into the chin.
func _flir(tool: SurfaceTool) -> void:
	var r: float = FLIR.z
	var loops: Array = []
	for step in [[-0.95, 0.30], [-0.6, 0.8], [0.0, 1.0], [0.6, 0.8], [0.95, 0.30]]:
		var loop: Array = []
		for k in range(FLIR_SIDES):
			var t: float = TAU * (float(k) + 0.5) / FLIR_SIDES
			var ring_r: float = r * float(step[1])
			loop.append(at(ring_r * UNIT * cos(t), FLIR.x + ring_r * sin(t), FLIR.y + r * float(step[0])))
		loops.append(loop)
	var tints: Array = []
	for k in range(FLIR_SIDES):
		# The window looks forward: the facets whose middle is ahead of the ball's axis.
		tints.append(LENS if sin(TAU * (float(k) + 1.0) / FLIR_SIDES) < -0.3 else METAL)
	_loft(tool, loops, tints)
	var top: float = float(_pod_row(FLIR.x)[2]) - 1.5
	var bottom: float = FLIR.y - r * 0.8
	Plating.box(tool, at(0.0, FLIR.x, (top + bottom) * 0.5), Vector3(0.12, (bottom - top) * UNIT, 0.22), METAL)


## THE CABIN: the floor at the sills, from the chin to the rear door's back, each side at the pod's own wall; and the
## instrument console on the centreline between the pilots' knees.
func _cabin(tool: SurfaceTool) -> void:
	var loops: Array = []
	var x: float = FLOOR_X.x
	while x <= FLOOR_X.y + 0.01:
		var half: float = pod_out(x, FLOOR_Y) - 0.015
		loops.append([at(half, x, FLOOR_Y), at(-half, x, FLOOR_Y), at(-half, x, FLOOR_Y + 1.0), at(half, x, FLOOR_Y + 1.0)])
		x += 6.2
	_loft(tool, loops, [FLOOR, TRIM, TRIM, TRIM])
	var fore: Vector3 = at(0.0, CONSOLE.position.x, CONSOLE.position.y)
	var aft: Vector3 = at(0.0, CONSOLE.end.x, CONSOLE.end.y)
	Plating.box(tool, (fore + aft) * 0.5, Vector3(CONSOLE_HALF * 2.0, absf(fore.y - aft.y), absf(aft.z - fore.z)), TRIM)
