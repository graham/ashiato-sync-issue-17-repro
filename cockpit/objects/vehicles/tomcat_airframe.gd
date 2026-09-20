@tool
extends Node3D
class_name TomcatAirframe
## A GRUMMAN F-14D TOMCAT, DRAWN: a long pointed radome, two crew in tandem under one bubble canopy, the twin chin pod,
## the raked rectangular intakes of two widely spaced nacelles with the flat "pancake" deck and the tunnel between them,
## the fixed glove, THE SWING WING, twin canted fins, all-moving stabilators, ventral fins and the flat tail between the
## nozzles.
##
## THE WING SWEEPS, AND THAT IS THE POINT OF THIS FILE. `set_sweep(degrees)` swings each outer panel about its own pivot
## in the glove, from 20 degrees forward to 68 fully aft, and on to 75 OVERSWEPT, which is how a Tomcat is parked on a
## deck. It is A PURE FUNCTION OF THE ANGLE IT IS HANDED, holding no memory and no timer, as `SkyhawkAirframe`'s surfaces
## are: `set_sweep(30)` then `set_sweep(50)` draws exactly what `set_sweep(50)` does. Nothing drives it yet, because
## there is no craft kind to carry a Mach number; a probe poses it at any angle, and a later step will drive it from the
## simulation.
##
## HOW THE WING AND THE GLOVE SHARE SPACE WITHOUT PASSING THROUGH EACH OTHER. The real wing's root slides between the
## glove's upper and lower skins, and its trailing edge slides aft over the nacelle under the overwing fairing. So this
## glove is built as a real slot: a solid front, a lower block under the wing's plane and an upper plate over it, with
## the panel's root stub between them at a centimetre's clearance each side. Everything the panel sweeps over aft of the
## glove -- nacelle tops, the deck, the spine -- is kept under the wing's plane, and the fins and stabilators are aft of
## or under anywhere the panel reaches. `tests/tomcat.gd` asks it of the drawn triangles at 20, 44, 68 and 75 degrees.
##
## THE SIMULATION GIVES THE SIZE, THIS GIVES THE SHAPE, as for every airframe here -- except that there is no
## simulation kind until 2026-09-17: the box was a draft kept here and is now `Sim.Kind.TOMCAT`'s shape table, 2.2 x 1.3 x
## 9.55 m half-extents resting on the ground. Every other size names its source:
## - [D] MEASURED off Commons' `F-14D.jpg`, a CC BY 3.0 FAN SCHEMATIC, at 121.1 px a metre, scaled by the published
##   length. It is the best drawing Commons has and it is not an authority: `craft/tomcat/sources.md` says what it can
##   and cannot be asked, and `craft/tomcat/measure_drawing.py` re-derives every measured figure from it alone.
## - [A] the public-domain US Army recognition three-view, 0.08 m a pixel, for which way things go and nothing finer.
## - [PUB] Grumman's published envelope: 19.10 m long, 19.54 / 11.65 / 10.15 m span at 20 / 68 / 75 degrees, 4.88 m high.
## - ESTIMATE where nothing gives it, and it says what it was reasoned from.
##
## STATIONS ARE METRES AFT OF THE NOSE TIP and HEIGHTS ARE METRES OVER THE GROUND WITH THE GEAR DOWN, as in
## `SkyhawkAirframe`. THE GROUND IS PUT 4.88 m UNDER THE FIN TIP [PUB], because [D] draws the gear up and gives no ground
## at all; every tyre stands on that.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT. The user's direction of 2026-09-17: "Prefer the 'lower poly' model
## without smooth edges, but still high quality and high fidelity", and the Hawkeye is the reference for the look. Every
## count here is AT OR BELOW the Hawkeye's for the same kind of part:
## - FUSELAGE_SIDES 14 (seven facets a side, three of them glazing under the canopy), against the Hawkeye's 20;
## - NACELLE_SIDES 12, against its 16 on a nacelle;
## - WHEEL_SIDES 8, and a wing section of four facets -- a flat bottom, two top facets meeting at a ridge.
## Every face carries its own normal; nothing is smoothed. FIDELITY IS PROPORTION AND FEATURE, NOT TRIANGLES.
##
## THE F-14 HAS NO AILERONS, SO NONE ARE DRAWN. It rolls with SPOILERS, four panels on each outer wing's upper surface
## that rise on the down-going wing only, and with DIFFERENTIAL STABILATORS, the two all-moving tailplanes turning
## opposite ways; the same two tailplanes turning together are its elevator. Above 57 degrees of sweep the spoilers are
## locked down and the tailplanes roll it alone. Twin RUDDERS on the two fins. All of them follow the stick through
## `follow_the_stick`, each surface its own pure setter, and each is a VAT feature beside the sweep (`features()`). THE
## SPOILERS RIDE THE SWING WING: their hinge is a child of the wing's pivot, so the hinge line swings with the panel and a
## spoiler raised at 44 degrees is raised along the 44-degree wing. Added 2026-09-18 (`lane/tomcat2`); the user asked for
## "alerons and elevators", and these are the F-14's.
##
## NOT IN VehicleView's `_body`: `_show_body` paints one flat material over every mesh there, and this airframe's colour
## is in its vertices (`lane/fleet`, Hawkeye).

const LENGTH: float = 19.10
const HEIGHT: float = 4.88

## THE PAINT. An F-14D wore the tactical paint scheme's two greys, FS 36320 over 36375; ESTIMATE, sRGB approximations.
const GREY := Color(0.52, 0.55, 0.58)
const BELLY := Color(0.64, 0.66, 0.68)
const DARK := Color(0.16, 0.17, 0.18)
const METAL := Color(0.30, 0.29, 0.28)
const TYRE := Color(0.06, 0.06, 0.06)
const GLASS := Color(0.17, 0.22, 0.27)
## THE SPOILER PANELS a shade darker than the wing, so the four panel lines read when they lie flat. ESTIMATE.
const SPOILER := Color(0.45, 0.48, 0.51)

## ---- the sweep ------------------------------------------------------------------------------------------------------

## 20 FORWARD, 68 FULLY AFT, 75 OVERSWEPT FOR THE DECK [PUB]. The panel is BUILT at 20 degrees, which is where [D]'s drawn
## 68-degree wing lands when it is swung 48 degrees forward about the pivot.
const SWEEP_FORWARD: float = 20.0
const SWEEP_AFT: float = 68.0
const SWEEP_OVER: float = 75.0
## ROWS IN THE VAT'S SWEEP TABLE. Between two rows the shader blends a turn linearly, so the error falls about fourfold
## each time the rows double. Measured by `tests/tomcat.gd`, worst wing vertex at six sweeps OFF the grid: 9 rows 3.96 mm,
## 33 rows 0.35, 65 rows 0.10, 129 rows 0.02. 65 is a tenth of a millimetre at the wingtip, 7 m from the pivot, for
## 2 KB of texture a craft kind.
const SWEEP_ROWS: int = 65

## THE PIVOT [D]: 3.0 m out, read at the glove's outer corner fairing to about 0.2 m, and at station 11.22, the station
## that turns [D]'s drawn tip into the published 19.54 m spread span. Swung the other way the same wing PREDICTS 10.08 m
## overswept against the published 10.15 -- not fitted to. `measure_drawing.py` prints both.
const PIVOT_OUT: float = 3.0
const PIVOT_STATION: float = 11.22
## THE WING'S PLANE [D]: its flat underside at 2.50 m, off the rear view's wing root. The glove's slot and every surface
## the panel sweeps over are built round this one number.
const WING_UNDER: float = 2.50

## THE PANEL AT 20 DEGREES, about its pivot, as (metres aft, metres out) [D], from `measure_drawing.py`. The exposed root
## runs 2.9 degrees off the airflow at 20 degrees: a swing wing's root rib is streamwise at its forward stop, and nothing
## was fitted to make it so. [A]'s drawing puts the root leading edge 3.32 m out at 20 degrees; this puts it at 3.32.
const ROOT_LE: Vector2 = Vector2(-0.385, 0.320)
const ROOT_TE: Vector2 = Vector2(3.099, 0.495)
const TIP_LE: Vector2 = Vector2(1.858, 6.213)
const TIP_TE: Vector2 = Vector2(3.227, 6.770)
## THE ROOT STUB, the part of the panel that lives inside the glove at every sweep and carries the pivot. Its corners are
## chosen so it stays under the glove's upper plate from 20 to 75 degrees -- which `tests/tomcat.gd` asks of the drawn
## triangles rather than of this comment. ESTIMATE: nothing shows the inside of a glove.
const STUB_AFT: Vector2 = Vector2(-0.40, 0.60)   # from, to
const STUB_OUT: Vector2 = Vector2(-0.35, 0.33)   # from, to
## Thickness. The F-14's sections are NACA 64A209.65 at the root and 64A208.91 at the tip -- ESTIMATE from general
## references, not measured -- which on a 3.5 m root is 0.34 m. Drawn thinner, 0.15 m at the root and 0.07 at the tip:
## the glove's slot has to hold it, and at the range a wing is seen from the difference is the one between a Mach-2 wing
## and a plank.
const ROOT_THICK: float = 0.15
const TIP_THICK: float = 0.07
## The slot's clearance each side of the panel's thickest part.
const SLOT_CLEAR: float = 0.012

## ---- the fuselage ---------------------------------------------------------------------------------------------------

## THE FORWARD FUSELAGE, nose to the end of the canopy [D]. Rows are [station, half width, top, canopy sill, bottom,
## canopy half width]: the plan view's silhouette for width, the side view's for heights. Ahead of the windscreen the
## "sill" and "canopy" columns only shape the radome into a rounded section.
const SECTIONS: Array = [
	[0.33, 0.09, 1.53, 1.50, 1.46, 0.07],
	[0.66, 0.25, 1.71, 1.52, 1.34, 0.19],
	[0.99, 0.36, 1.87, 1.56, 1.25, 0.27],
	[1.32, 0.43, 2.01, 1.60, 1.20, 0.32],
	[1.65, 0.50, 2.13, 1.64, 1.15, 0.38],
	[1.98, 0.57, 2.22, 1.72, 1.13, 0.43],
	[2.40, 0.64, 2.31, 1.95, 1.11, 0.46],
	[2.97, 0.74, 2.47, 2.25, 1.11, 0.46],
	[3.30, 0.75, 2.60, 2.50, 1.11, 0.45],
	[3.96, 0.82, 3.00, 2.56, 1.13, 0.50],
	[4.62, 0.82, 3.24, 2.59, 1.16, 0.52],
	[5.61, 0.81, 3.37, 2.65, 1.20, 0.52],
	[6.26, 0.81, 3.37, 2.70, 1.24, 0.51],
	[6.92, 0.82, 3.31, 2.76, 1.26, 0.48],
	[7.58, 0.83, 3.23, 2.82, 1.28, 0.44],
	[8.00, 0.84, 3.10, 2.84, 1.30, 0.40],
]
const FUSELAGE_SIDES: int = 14
## THE CANOPY [D]: glazing runs from the windscreen base aft to its end, with the frame between the two cockpits.
const WINDSCREEN_BASE: float = 3.30
const WINDSCREEN_TOP: float = 4.40
const CANOPY_END: float = 7.75
const CANOPY_BOW: Vector2 = Vector2(5.55, 5.72)
## THE PITOT PROBE on the radome tip [D]: the drawn length starts at its point.
const PITOT_HEIGHT: float = 1.50

## THE CENTRE BODY [D]: the flat deck between and over the nacelles, and the tunnel under it, to the flat tail between
## the nozzles. Rows are [station, half width, top, bottom]. ITS TOP IS KEPT UNDER THE WING'S PLANE aft of the glove,
## because a fully swept wing's inboard trailing edge lies over it: [D] draws that edge 1.03 m out at 68 degrees.
const CENTRE: Array = [
	[6.50, 0.80, 2.50, 1.25],
	[8.00, 0.86, 2.56, 1.34],
	[11.00, 0.86, 2.42, 1.45],
	[14.00, 0.80, 2.38, 1.50],
	[16.50, 0.70, 2.25, 1.60],
	[18.30, 0.56, 2.12, 1.75],
	[19.10, 0.45, 2.02, 1.88],
]
## THE SPINE [D], the fairing behind the canopy that runs down into the deck. Rows are [station, half width, top].
const SPINE: Array = [
	[7.40, 0.46, 3.24],
	[8.50, 0.42, 3.05],
	[10.20, 0.36, 2.75],
	[12.20, 0.30, 2.60],
	[14.20, 0.22, 2.44],
	[15.50, 0.10, 2.34],
]

## THE NACELLES [D], each a loft from the raked rectangular intake to the round nozzle, centred 1.445 m out in the rear
## view. Rows are [station, inner out, outer out, bottom, top, roundness 0 box to 1 round]. The first row is the intake
## lip, RAKED: its top is at the station given and its bottom 0.48 m further aft, as [D]'s side view draws it.
## THEIR TOPS STAY UNDER THE WING'S PLANE as far aft as the overswept wing reaches over them (15.6), then rise to the
## round nozzle fairing.
const NACELLE: Array = [
	[6.32, 0.95, 1.70, 1.25, 2.24, 0.0],
	[8.00, 0.85, 1.86, 1.12, 2.36, 0.15],
	[11.00, 0.76, 2.10, 1.02, 2.44, 0.30],
	[14.30, 0.73, 2.17, 1.02, 2.44, 0.45],
	[15.60, 0.73, 2.17, 1.06, 2.46, 0.70],
	[16.60, 0.725, 2.165, 1.14, 2.58, 1.0],
	[18.30, 0.785, 2.105, 1.20, 2.52, 1.0],
]
const INTAKE_RAKE: float = 0.48
const NACELLE_SIDES: int = 12
## THE NOZZLES [D]: from the nacelle's end to the exit, narrowing, dark.
const NOZZLE: Vector2 = Vector2(18.30, 18.90)
const NOZZLE_OUT: float = 1.445
const NOZZLE_HEIGHT: float = 1.86

## ---- the glove ------------------------------------------------------------------------------------------------------

## THE GLOVE [D]: its leading edge is the fitted line `station = 2.294 + 2.5634 * out`, 68.7 degrees, which the fully
## swept wing's leading edge continues to within 0.3 of a degree. It runs from the intake's outer top corner out to
## 3.45 m, and the corner fairing round the pivot closes it.
const GLOVE_LE: Vector2 = Vector2(2.294, 2.5634)   # station at zero out, stations per metre out
const GLOVE_ROOT_OUT: float = 1.62
const GLOVE_TIP_OUT: float = 3.45
## THE SLOT starts here: forward of it the glove is solid, because no part of the panel reaches this far forward at any
## sweep (the root stub's nose is at 10.62 at 75 degrees).
const SLOT_FROM: float = 10.30
const GLOVE_AFT: float = 11.95
## THE OVERWING FAIRING's aft edge [D]: level with the spread wing's root trailing edge, 14.32.
const FAIRING_AFT: float = 14.30
## The glove's lower block sits on the nacelle; the upper plate's top.
const GLOVE_FLOOR: float = 2.20
const GLOVE_ROOF: float = 2.72

## ---- the tail -------------------------------------------------------------------------------------------------------

## THE FINS [D]: root on the nacelle top 1.46 m out, tip 1.68 m out at the published height -- 5.2 degrees of cant,
## outward, measured in the rear view. Root chord from the side view, 15.17 to 18.30; tip 17.97 to 18.98.
const FIN_ROOT: Vector3 = Vector3(1.46, 15.17, 18.30)   # out, leading edge, trailing edge
const FIN_TIP: Vector3 = Vector3(1.68, 17.97, 18.98)
const FIN_ROOT_HEIGHT: float = 2.40
const FIN_THICK: Vector2 = Vector2(0.20, 0.08)
## THE STABILATORS [D]: tip at 4.97 m out, 9.94 m across against the published 9.97 span (ESTIMATE of a published figure;
## [D] measures it). Anhedral from the rear view: 2.00 m at the root, 1.80 at the tip. THE ROOT STANDS 3 cm OFF THE
## NACELLE'S WIDEST SIDE (2.17 m out), at 2.20. It was bedded 12 cm inside the nacelle at 2.05 while the tailplane was
## fixed; an ALL-MOVING tailplane turned 25 degrees about a spindle swings its root's leading edge 0.7 m up, and a root
## bedded in the nacelle came out through the nacelle's top. Outboard of the widest nacelle, no turn of it can reach one.
const STAB_ROOT: Vector3 = Vector3(2.20, 14.80, 18.20)
const STAB_TIP: Vector3 = Vector3(4.97, 18.35, 19.05)
const STAB_HEIGHT: Vector2 = Vector2(2.00, 1.80)
const STAB_THICK: Vector2 = Vector2(0.14, 0.05)
## THE STABILATOR'S SPINDLE: a line straight across the aeroplane at this station and the root's height. ESTIMATE; nothing
## measured gives it. Straight across and not drooped with the anhedral, so every root point keeps its 2.20 m out at every
## angle. It was at 16.60, a little aft of the root chord's middle, and the swept wing -- which lies 0.43 m over the
## tailplane's root at 68 degrees -- met the root's leading edge rising 1.8 m ahead of the spindle: 18 points at 68 degrees
## with the stick forward and right. At 15.90 the leading edge is 1.1 m ahead and rises 0.30 m at the most trailing edge
## down the tailplane is ever given (16 degrees).
const STAB_SPINDLE: float = 15.90

## ---- the surfaces that follow the stick ----------------------------------------------------------------------------

## TRAVELS, in degrees. ESTIMATES, from general descriptions of the F-14 and not from a published rigging table: roll
## spoilers rise to about 55 degrees; the tailplanes 12 trailing edge up and 10 down for pitch, and 6 more either way for
## roll, summed and never clamped (a VAT adds its tables, and a clamp would be a difference between the parts and the
## cast); the rudders 30. THE TAILPLANES' TRAVEL IS WHAT THE FULLY SWEPT WING LEAVES ROOM FOR, measured by
## `tests/tomcat.gd`'s pass-through check at 68 degrees with the stick back and left: 20 up and 8 of roll put 12 wing
## edge points inside the port tailplane, 18 and 8 put 14, 15 and 8 still 14, 12 and 6 none. The wingtip lies over the
## tailplane's tip there. A real F-14 moves its tail further; its tail is not drawn from a rigging table.
## The spoilers and the rudders are asked the same question and have room to spare.
const SPOILER_TRAVEL: float = 55.0
const STAB_PITCH_TRAVEL: Vector2 = Vector2(12.0, 10.0)   # trailing edge up, down
const STAB_ROLL_TRAVEL: float = 6.0
const RUDDER_TRAVEL: float = 30.0
## THE TAILPLANES HELD STILL PAST FULL SWEEP. Overswept, the wingtips lie over the tailplanes, and a tailplane turned
## with the stick went into the wing at 75 degrees (`tests/tomcat.gd`: the port tip's trailing edge 0.67 m up into the
## port wingtip). Oversweep is a deck position; this drawing fades the tail's share of the stick out between 68 and 70
## degrees, as the spoilers' is past 57. A DRAWING RULE: the real aircraft's tail schedule in oversweep is not modelled.
const TAIL_HELD_FROM: float = 68.0
const TAIL_FADE: float = 2.0
## THE SPOILER LOCKOUT: above 57 degrees of sweep the F-14's roll spoilers are held down and the tailplanes roll it alone
## (the team lead's figure, "about 57", 2026-09-18). DRAWN AS A 2-DEGREE FADE and not a step, so a wing sweeping through
## 57 with the stick over lowers its spoilers in a sixth of a second at the handle's 12 degrees a second, rather than in
## one frame.
const SPOILER_LOCKOUT: float = 57.0
const SPOILER_FADE: float = 2.0
## THE FOUR SPOILER PANELS ON EACH WING, as spanwise fractions of the exposed panel, 0 at the root rib and 1 at the tip,
## and the chord they cover, from the hinge to their trailing edge: ahead of the flaps, over the inner two thirds of the
## span, as general arrangement drawings of the F-14 show them. ESTIMATE: [D] draws no panel lines.
const SPOILER_SPANS: Array = [[0.08, 0.22], [0.24, 0.38], [0.40, 0.54], [0.56, 0.70]]
const SPOILER_CHORD: Vector2 = Vector2(0.60, 0.77)
## How far the panels are laid proud of the wing's drawn top, and their thickness. Proud so no face is coplanar with the
## wing's; `tests/tomcat.gd` asks that no part of them is inside the wing, at rest or raised.
const SPOILER_PROUD: float = 0.012
const SPOILER_THICK: float = 0.012
## THE RUDDERS: the hinge at this fraction of the fin's chord, from the rudder's foot (clear of the nacelle top under
## it, 2.58 m at its highest) to the fin tip. ESTIMATE.
const RUDDER_HINGE: float = 0.72
const RUDDER_FOOT: float = 2.72
## THE COVE: the fin stops this far ahead of the rudder's hinge line, and under its foot. The rudder's nose is a knife on
## the hinge line and its shoulders are as far aft of it as they are wide, so no turn under 45 degrees brings any of it
## forward of the line; the first rudder was a box from the hinge back, face to face with the fin, and the pass-through
## check read it inside the fin at every pose (138 points), since a turned box's front corners swing forward.
const RUDDER_COVE: float = 0.012
## THE GAP UNDER THE RUDDER'S FOOT, larger than the cove: the hinge line leans out with the fin's 5-degree cant, so a rudder
## swung towards the lean lowers its foot's trailing edge. With 12 mm there, full pedal put 22 points of the foot inside
## the fixed strip under it, at 2.70 m, on the side each rudder leans to and never the other.
const RUDDER_FOOT_GAP: float = 0.04
## ROWS IN THE VAT'S SURFACE TABLES, each over -1 to 1. ODD, so a row falls exactly on the stick's centre, where the
## spoilers' one-sided travel has its corner: blended across a corner, a neutral stick would lift both wings' spoilers a
## little. Chosen by `tests/tomcat.gd`'s measurement, which prints the worst vertex for each.
const SURFACE_ROWS: int = 65
const SPOILER_ROWS: int = 65

## THE VENTRAL FINS [D], under each nacelle, canted out. Stations and their foot's height from the side view.
const VENTRAL: Vector3 = Vector3(14.00, 15.90, 0.46)   # leading edge, trailing edge, lowest point

## ---- the nose's fittings and the gear ------------------------------------------------------------------------------

## THE TWIN CHIN POD of the F-14D [D]: the IRST and the TV camera side by side under the nose.
const CHIN_POD: Vector4 = Vector4(2.10, 3.30, 0.70, 0.13)   # from, to, lowest point, each pod's half width
## THE M61A1 on the port side of the nose [D]: the muzzle vents on the lower forward fuselage.
const GUN: Vector3 = Vector3(3.10, 3.90, 1.45)   # from, to, height

## THE GEAR, DOWN. NOT FOUND: [D] draws it up and [A] does not draw it, so every figure here is an ESTIMATE from the
## F-14's general description -- a twin nose wheel ahead of the cockpit and single mains folding forward into the glove
## -- sized so the ground is where [PUB]'s height puts it.
const NOSE_GEAR_STATION: float = 4.10
const NOSE_TYRE_RADIUS: float = 0.28
const MAIN_GEAR_STATION: float = 11.40
const MAIN_TYRE_RADIUS: float = 0.47
const MAIN_TYRE_WIDE: float = 0.29
const TRACK: float = 5.00
const WHEEL_SIDES: int = 8

## ---- the crew ------------------------------------------------------------------------------------------------------

## THE TWO CREW IN TANDEM [D]: the helmets in the side view, pilot ahead and the radar intercept officer behind.
const PILOT_EYE: Vector2 = Vector2(4.86, 2.94)   # station, height
const RIO_EYE: Vector2 = Vector2(6.51, 3.07)
## THE ROOM THAT CAN BE PROMISED round them: every point in it is inside the drawn skin. ESTIMATE, chosen inside the
## measured sections and held against the drawn triangles by `tests/tomcat.gd`.
const ROOM: AABB = AABB(Vector3(-0.30, 1.65, 4.30), Vector3(0.60, 1.25, 2.90))   # out, height, station
const CABIN_FLOOR: float = 1.65

## Small fittings stop drawing once a 19 m aeroplane is a few pixels high.
const DETAIL_RANGE: float = 800.0
const DETAIL_HYSTERESIS: float = 80.0

var _half: Vector3 = Vector3(2.2, 1.3, 9.55)
var _sweep: float = SWEEP_FORWARD
var _pivots: Array[Node3D] = []
var _material: StandardMaterial3D
## THE MOVING SURFACES' HINGES, by name ("SpoilersStarboard", "StabilatorPitchPort", ...), each carrying its axis as
## meta "axis", wound so a positive turn is the surface's positive deflection.
var _hinges: Dictionary = {}
var _spoilers: float = 0.0
var _stab_pitch: float = 0.0
var _stab_roll: float = 0.0
var _rudders: float = 0.0


## BUILT IN PLACE, after `new()`, from the simulation's geometry -- asked of the simulation itself when nothing is handed.
func dress(geometry: Dictionary = {}) -> void:
	name = "Tomcat"
	var native: Dictionary = geometry if not geometry.is_empty() else Sim.geometry_of(Sim.Kind.TOMCAT)
	_half = native.get("extents", _half) as Vector3
	_material = _paint()
	var fuselage := _tool()
	var glass := _tool()
	_fuselage(fuselage, glass)
	_pitot(fuselage)
	_add_fuselage(fuselage, glass)
	var centre := _tool()
	_centre_body(centre)
	_add("CentreBody", centre)
	var spine := _tool()
	_spine(spine)
	_add("Spine", spine)
	var pod := _tool()
	_chin_pod(pod)
	_add("ChinPod", pod)
	var gun := _tool()
	_gun(gun)
	_detail(_add("Gun", gun))
	var nose_gear := _tool()
	_nose_gear(nose_gear)
	_detail(_add("NoseGear", nose_gear))
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var nacelle := _tool()
		_nacelle(nacelle, side)
		_add("Nacelle" + named, nacelle)
		var nozzle := _tool()
		_nozzle(nozzle, side)
		_add("Nozzle" + named, nozzle)
		var glove := _tool()
		_glove(glove, side)
		_add("Glove" + named, glove)
		var fin := _tool()
		_fin(fin, side)
		_add("Fin" + named, fin)
		_rudder(side, named)
		_stabilator(side, named)
		var ventral := _tool()
		_ventral(ventral, side)
		_add("VentralFin" + named, ventral)
		var main := _tool()
		_main_gear(main, side)
		_detail(_add("MainGear" + named, main))
		# THE SWING WING: a pivot node on the drawn pivot, and the panel built about it at 20 degrees.
		var pivot := Node3D.new()
		pivot.name = "WingPivot" + named
		pivot.position = point(side * PIVOT_OUT, WING_UNDER, PIVOT_STATION)
		add_child(pivot)
		var wing := _tool()
		_wing(wing, side)
		_add("Wing" + named, wing, pivot)
		_pivots.append(pivot)
		_spoiler_panels(side, named, pivot)
	set_sweep(SWEEP_FORWARD)
	follow_the_stick(Vector2.ZERO, 0.0)


## THE WING'S SWEEP, in degrees of leading-edge sweep: 20 forward, 68 fully aft, 75 overswept. Clamped to that range.
## A PURE FUNCTION OF THE ANGLE: each panel is turned about the vertical through its own pivot by the difference from the
## 20 degrees it was built at, and nothing else moves.
func set_sweep(degrees: float) -> void:
	_sweep = clampf(degrees, SWEEP_FORWARD, SWEEP_OVER)
	var turn: float = deg_to_rad(_sweep - SWEEP_FORWARD)
	for pivot in _pivots:
		var side: float = 1.0 if pivot.position.x > 0.0 else -1.0
		# About +Y a positive angle carries +X towards -Z, which is forward: a starboard tip sweeps AFT on a negative one.
		pivot.basis = Basis(Vector3.UP, -side * turn)


func sweep() -> float:
	return _sweep


## THE STICK AND THE PEDALS, AS THE VIEW HOLDS THEM: `stick.x` -1 left wing down to +1 right wing down, `stick.y` -1 nose
## down to +1 nose up, `rudder` -1 nose left to +1 nose right. The one place the F-14's mixing lives: roll goes to the
## spoilers, scaled down to nothing past the lockout AT THE SWEEP THE WING IS DRAWN AT NOW, and to the tailplanes
## differentially; pitch to the tailplanes together, held still past full sweep; the pedals to both rudders. So
## `set_sweep` first, then this.
func follow_the_stick(stick: Vector2, rudder: float) -> void:
	var roll: float = clampf(stick.x, -1.0, 1.0)
	var tail: float = tail_share(_sweep)
	set_spoilers(roll * spoiler_share(_sweep))
	set_stabilators(clampf(stick.y, -1.0, 1.0) * tail, roll * tail)
	set_rudders(rudder)


## HOW MUCH OF THE ROLL THE SPOILERS TAKE at a sweep: all of it to 55 degrees, none past the 57-degree lockout.
static func spoiler_share(degrees: float) -> float:
	return clampf((SPOILER_LOCKOUT - degrees) / SPOILER_FADE, 0.0, 1.0)


## HOW MUCH OF THE STICK THE TAILPLANES TAKE at a sweep: all of it to full sweep, none overswept past 70.
static func tail_share(degrees: float) -> float:
	return clampf((TAIL_HELD_FROM + TAIL_FADE - degrees) / TAIL_FADE, 0.0, 1.0)


## THE SPOILERS, -1 to 1: +1 raises the STARBOARD wing's four panels to their full travel (right wing down), -1 the
## PORT wing's. A spoiler only rises, so the other wing's stay down. A pure function of the amount.
func set_spoilers(amount: float) -> void:
	_spoilers = clampf(amount, -1.0, 1.0)
	_turn("SpoilersStarboard", maxf(_spoilers, 0.0) * SPOILER_TRAVEL)
	_turn("SpoilersPort", maxf(-_spoilers, 0.0) * SPOILER_TRAVEL)


func spoilers() -> float:
	return _spoilers


## THE STABILATORS: `pitch` -1 to +1 turns both together, trailing edges up for nose up; `roll` -1 to +1 turns them
## apart, the STARBOARD trailing edge up for right wing down. Each on its own hinge, the roll's inside the pitch's, so a
## VAT follows each as its own feature and composes them as the node tree does.
func set_stabilators(pitch: float, roll: float) -> void:
	_stab_pitch = clampf(pitch, -1.0, 1.0)
	_stab_roll = clampf(roll, -1.0, 1.0)
	for named in ["Starboard", "Port"]:
		var side: float = 1.0 if named == "Starboard" else -1.0
		# More trailing edge up than down: a corner at the centre, where the pitch table has a row.
		_turn("StabilatorPitch" + named, _stab_pitch * (STAB_PITCH_TRAVEL.x if _stab_pitch > 0.0 else STAB_PITCH_TRAVEL.y))
		_turn("StabilatorRoll" + named, side * _stab_roll * STAB_ROLL_TRAVEL)


func stabilator_pitch() -> float:
	return _stab_pitch


func stabilator_roll() -> float:
	return _stab_roll


## THE RUDDERS, -1 to 1: +1 swings both trailing edges to starboard, nose right.
func set_rudders(yaw: float) -> void:
	_rudders = clampf(yaw, -1.0, 1.0)
	_turn("RudderStarboard", _rudders * RUDDER_TRAVEL)
	_turn("RudderPort", _rudders * RUDDER_TRAVEL)


func rudders() -> float:
	return _rudders


## THE FEATURES A VAT BAKES (`VatCasting`, `research/vertex_animation.md`), each this airframe's own setter and getter:
## the one list a casting needs, kept beside the setter it names. The sweep is a plain turn about a vertical line, so it
## asks for SWEEP_ROWS rather than the default 129 -- measured in `tests/tomcat.gd`. THE SWEEP IS FIRST AND STAYS FIRST:
## a spoiler's two features are its own hinge (inner) and the sweep (outer), and the probes index the sweep as 0.
## The spoilers are baked at the build's 20 degrees, where their whole share is theirs; the lockout is applied to the
## AMOUNT in `follow_the_stick`, never to the geometry, so a feature's rows stay a pure function of its own amount.
func features() -> Array:
	return [
		{"name": "sweep", "set": set_sweep, "get": sweep, "low": SWEEP_FORWARD, "high": SWEEP_OVER,
			"samples": SWEEP_ROWS},
		{"name": "spoilers", "set": set_spoilers, "get": spoilers, "low": -1.0, "high": 1.0, "samples": SPOILER_ROWS},
		{"name": "pitch", "set": func(amount: float) -> void: set_stabilators(amount, _stab_roll),
			"get": stabilator_pitch, "low": -1.0, "high": 1.0, "samples": SURFACE_ROWS},
		{"name": "roll", "set": func(amount: float) -> void: set_stabilators(_stab_pitch, amount),
			"get": stabilator_roll, "low": -1.0, "high": 1.0, "samples": SURFACE_ROWS},
		{"name": "rudder", "set": set_rudders, "get": rudders, "low": -1.0, "high": 1.0, "samples": SURFACE_ROWS},
	]


## A HINGE turned `degrees` from where it was built, about the axis stored on it when it was built.
func _turn(named: String, degrees: float) -> void:
	var hinge: Node3D = _hinges.get(named) as Node3D
	if hinge != null:
		hinge.basis = Basis(hinge.get_meta("axis") as Vector3, deg_to_rad(degrees))


## THE ROOM THIS AEROPLANE PROMISES ROUND ITS CREW, in the craft's own frame -- the shape `VehicleView.cabin_room()` asks
## of an airframe (see `SkyhawkAirframe.cabin_room`). Every point inside `room` is inside the skin this draws; a point
## outside it may or may not be. `floor` is published beside it, not as its bottom.
func cabin_room() -> Dictionary:
	var low := point(ROOM.position.x, ROOM.position.y, ROOM.position.z)
	var high := point(ROOM.end.x, ROOM.end.y, ROOM.end.z)
	return {
		"drawn": true,
		"floor": height(CABIN_FLOOR),
		"room": AABB(low, high - low).abs(),
		"because": &"",
		"why_not": "",
		"source": "ESTIMATE inside the sections measured off [D]; see TomcatAirframe.ROOM",
	}


## THE TWO CREW EYES, pilot then RIO, in the craft's frame.
func crew_eyes() -> Array[Vector3]:
	return [point(0.0, PILOT_EYE.y, PILOT_EYE.x), point(0.0, RIO_EYE.y, RIO_EYE.x)]


## STATIONS are metres aft of the nose tip.
func station(s: float) -> float:
	return -_half.z + s


## HEIGHTS are metres over the ground with the gear down; the draft box rests on the ground, so its middle is half its
## depth up.
func height(h: float) -> float:
	return h - _half.y


## A point at `out` metres from the centreline (+ starboard), `h` over the ground and station `s`.
func point(out: float, h: float, s: float) -> Vector3:
	return Vector3(out, height(h), station(s))


## THE GLOVE'S LEADING EDGE station at `out` metres from the centreline.
static func glove_le(out: float) -> float:
	return GLOVE_LE.x + GLOVE_LE.y * out


## ---- the builders --------------------------------------------------------------------------------------------------

## ONE FUSELAGE SECTION's ring, starboard from the top round to the bottom and back up the port side: a narrow canopy
## over the sill, straight sides, a chine and a flat-ish belly. Seven facets a side.
func _ring(row: Array) -> Array[Vector3]:
	var s: float = row[0]
	var hw: float = row[1]
	var top: float = row[2]
	var sill: float = row[3]
	var bottom: float = row[4]
	var cw: float = row[5]
	var half: Array[Vector2] = [
		Vector2(0.0, top),
		Vector2(cw * 0.62, top - (top - sill) * 0.14),
		Vector2(cw, sill + (top - sill) * 0.40),
		Vector2(lerpf(cw, hw, 0.85), sill),
		Vector2(hw, sill - (sill - bottom) * 0.40),
		Vector2(hw * 0.84, bottom + (sill - bottom) * 0.14),
		Vector2(hw * 0.40, bottom),
		Vector2(0.0, bottom),
	]
	var ring: Array[Vector3] = []
	for p in half:
		ring.append(point(p.x, p.y, s))
	for i in range(half.size() - 2, 0, -1):
		ring.append(point(-half[i].x, half[i].y, s))
	return ring


func _fuselage(tool: SurfaceTool, glass: SurfaceTool) -> void:
	for r in range(SECTIONS.size() - 1):
		var a := _ring(SECTIONS[r])
		var b := _ring(SECTIONS[r + 1])
		var here: float = (float(SECTIONS[r][0]) + float(SECTIONS[r + 1][0])) * 0.5
		for k in range(a.size()):
			var n: int = (k + 1) % a.size()
			# THE CANOPY IS EVERY FACET ABOVE THE SILL, each side, between the windscreen base and the canopy's end, less the
			# bow between the two cockpits: facets 0-1, 1-2 and 2-3 and their mirrors. It was the top two, which left the
			# facet from the sill up to 2.94 m opaque -- the pilot's own eye height -- so from either seat every look out and
			# a little down was a look at a wall (`tests/tomcat_seat_shot.gd`, the first seat pictures).
			var upper: bool = k <= 2 or k >= a.size() - 3
			var glazed: bool = upper and here > WINDSCREEN_BASE and here < CANOPY_END \
				and not (here > CANOPY_BOW.x and here < CANOPY_BOW.y)
			var tint: Color = GLASS if glazed else (BELLY if k >= 5 and k <= 9 else GREY)
			var quad: Array = [a[k], a[n], b[n], b[k]]
			_facet(glass if glazed else tool, quad, _centre_of(quad) - (_centre_of(a) + _centre_of(b)) * 0.5, tint)
	_cap(tool, _ring(SECTIONS[-1]), Vector3.BACK, GREY)


## THE PITOT PROBE and the radome's point: a slender cone from the first section to the drawn nose tip at station zero.
func _pitot(tool: SurfaceTool) -> void:
	var ring := _ring(SECTIONS[0])
	var tip := point(0.0, PITOT_HEIGHT, 0.0)
	var axis: Vector3 = (tip + _centre_of(ring)) * 0.5
	for k in range(ring.size()):
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % ring.size()]
		_tri(tool, tip, a, b, (tip + a + b) / 3.0 - axis, DARK)


func _centre_body(tool: SurfaceTool) -> void:
	var rings: Array = []
	for row in CENTRE:
		var hw: float = row[1]
		var top: float = row[2]
		var bottom: float = row[3]
		var c: float = 0.12
		rings.append([
			point(0.0, top, row[0]), point(hw - c, top, row[0]), point(hw, top - c, row[0]),
			point(hw, bottom + c, row[0]), point(hw - c, bottom, row[0]), point(-(hw - c), bottom, row[0]),
			point(-hw, bottom + c, row[0]), point(-hw, top - c, row[0]), point(-(hw - c), top, row[0])])
	_loft(tool, rings, func(k: int) -> Color: return BELLY if k >= 3 and k <= 5 else GREY)


func _spine(tool: SurfaceTool) -> void:
	var rings: Array = []
	for row in SPINE:
		var hw: float = row[1]
		var top: float = row[2]
		var base: float = _centre_top(row[0]) - 0.10
		rings.append([point(0.0, top, row[0]), point(hw * 0.55, top - 0.05, row[0]), point(hw, base + 0.12, row[0]),
			point(hw, base, row[0]), point(-hw, base, row[0]), point(-hw, base + 0.12, row[0]),
			point(-hw * 0.55, top - 0.05, row[0])])
	_loft(tool, rings, func(_k: int) -> Color: return GREY)


## The centre body's top at a station, interpolated through CENTRE.
static func _centre_top(s: float) -> float:
	for r in range(CENTRE.size() - 1):
		var a: Array = CENTRE[r]
		var b: Array = CENTRE[r + 1]
		if s <= float(b[0]):
			return lerpf(a[2], b[2], clampf((s - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))
	return float(CENTRE[-1][2])


## ONE NACELLE: rings from a box to a circle, the first one raked, a dark intake mouth set into the lip.
func _nacelle(tool: SurfaceTool, side: float) -> void:
	var rings: Array = []
	for r in range(NACELLE.size()):
		rings.append(_nacelle_ring(NACELLE[r], side, r == 0))
	# THE MOUTH IS THE LOFT'S FRONT CAP, DARK, so the intake reads as a hole and not as a panel. A dark plate set back
	# inside the lip would be inside a closed solid and never drawn.
	_loft(tool, rings, func(k: int) -> Color: return BELLY if k >= 4 and k <= 8 else GREY, DARK)


func _nacelle_ring(row: Array, side: float, raked: bool) -> Array[Vector3]:
	var inner: float = row[1]
	var outer: float = row[2]
	var bottom: float = row[3]
	var top: float = row[4]
	var p: float = lerpf(0.22, 1.0, float(row[5]))
	var cx: float = (inner + outer) * 0.5
	var cy: float = (bottom + top) * 0.5
	var a: float = (outer - inner) * 0.5
	var b: float = (top - bottom) * 0.5
	var ring: Array[Vector3] = []
	for k in range(NACELLE_SIDES):
		# Offset half a facet so a flat, not a corner, faces up, down, in and out: a box keeps its flat sides.
		var t: float = TAU * (float(k) + 0.5) / NACELLE_SIDES
		var c: float = cos(t)
		var s: float = sin(t)
		var x: float = cx + a * signf(c) * pow(absf(c), p)
		var y: float = cy + b * signf(s) * pow(absf(s), p)
		var st: float = float(row[0]) + (INTAKE_RAKE * (top - y) / (top - bottom) if raked else 0.0)
		ring.append(point(side * x, y, st))
	return ring


func _nozzle(tool: SurfaceTool, side: float) -> void:
	var rings: Array = []
	for pair in [[NOZZLE.x - 0.10, 0.64], [NOZZLE.y, 0.56]]:
		var ring: Array[Vector3] = []
		for k in range(NACELLE_SIDES):
			var t: float = TAU * (float(k) + 0.5) / NACELLE_SIDES
			ring.append(point(side * NOZZLE_OUT + cos(t) * pair[1], NOZZLE_HEIGHT + sin(t) * pair[1], pair[0]))
		rings.append(ring)
	# The exit is the loft's back cap, dark.
	_loft(tool, rings, func(_k: int) -> Color: return METAL, METAL, DARK)


## THE GLOVE, a real slot: a solid wedge forward of SLOT_FROM, and behind it a lower block up to the wing's underside
## and an upper plate over the panel's root stub, a centimetre clear of it each side. Plan outline: the fitted leading
## edge from the intake's outer top corner to GLOVE_TIP_OUT, the corner fairing round the pivot, and back along GLOVE_AFT.
func _glove(tool: SurfaceTool, side: float) -> void:
	var slot_low: float = WING_UNDER - SLOT_CLEAR
	var slot_high: float = WING_UNDER + ROOT_THICK + SLOT_CLEAR
	var root: float = GLOVE_ROOT_OUT
	var tip: float = GLOVE_TIP_OUT
	# The leading edge is thin and the glove thickens inboard, so each block's outer edge is lower and slimmer.
	var le_mid: float = WING_UNDER + ROOT_THICK * 0.5
	# FORWARD SOLID WEDGE: from the leading edge at `root` out to where the leading edge reaches SLOT_FROM.
	var slot_out: float = (SLOT_FROM - GLOVE_LE.x) / GLOVE_LE.y
	_block(tool, [
		point(side * root, GLOVE_FLOOR, glove_le(root)), point(side * root, GLOVE_FLOOR, SLOT_FROM),
		point(side * root, GLOVE_ROOF, SLOT_FROM), point(side * root, GLOVE_FLOOR + 0.12, glove_le(root)),
		point(side * slot_out, le_mid - 0.03, SLOT_FROM), point(side * slot_out, le_mid - 0.03, SLOT_FROM),
		point(side * slot_out, le_mid + 0.03, SLOT_FROM), point(side * slot_out, le_mid + 0.03, SLOT_FROM)], GREY)
	# Behind SLOT_FROM the leading edge carries on out to `tip`; the lower block and upper plate share its outline.
	var outline: Array[Vector2] = [Vector2(root, SLOT_FROM), Vector2(slot_out, SLOT_FROM),
		Vector2(tip, glove_le(tip)), Vector2(tip + 0.05, glove_le(tip) + 0.35), Vector2(tip - 0.10, GLOVE_AFT - 0.20),
		Vector2(tip - 0.35, GLOVE_AFT), Vector2(root, GLOVE_AFT)]
	# LOWER BLOCK: from the nacelle top up to just under the wing's plane -- AND ON AFT AS THE OVERWING FAIRING, to where
	# the spread wing's root trailing edge is. The first build stopped it at GLOVE_AFT with the upper plate, and at 68
	# degrees a notch of open ground showed between the glove, the nacelle and the swept wing's root: on the real
	# aeroplane that is the fairing the wing's trailing edge slides over, and [D] draws it.
	var fairing: Array[Vector2] = [Vector2(root, SLOT_FROM), Vector2(slot_out, SLOT_FROM), Vector2(tip, glove_le(tip)),
		Vector2(tip + 0.05, glove_le(tip) + 0.35), Vector2(tip, FAIRING_AFT), Vector2(root, FAIRING_AFT)]
	_prism(tool, fairing, side, func(o: float) -> float: return GLOVE_FLOOR if o < root + 0.9 else lerpf(GLOVE_FLOOR, slot_low - 0.06, clampf((o - root - 0.9) / (tip - root - 0.9), 0.0, 1.0)),
		func(_o: float) -> float: return slot_low, GREY)
	# UPPER PLATE: from just over the root stub up to the glove's roof, thinning to its outer edge.
	_prism(tool, outline, side, func(_o: float) -> float: return slot_high,
		func(o: float) -> float: return lerpf(GLOVE_ROOF, slot_high + 0.05, clampf((o - root) / (tip - root), 0.0, 1.0)), GREY)


## THE WING PANEL, built about its pivot at 20 degrees: the root stub inside the glove, and the exposed panel from the
## root rib to the tip. Each section is four facets -- a flat underside, a ridge on top at 40 per cent of the chord.
func _wing(tool: SurfaceTool, side: float) -> void:
	# The stub is the panel's thickest part and a box: it never shows.
	var stub: Array = []
	for o in [STUB_OUT.x, STUB_OUT.y]:
		for corner in [[STUB_AFT.x, 0.0], [STUB_AFT.y, 0.0], [STUB_AFT.y, ROOT_THICK], [STUB_AFT.x, ROOT_THICK]]:
			stub.append(_local(side, corner[0], o, corner[1]))
	_block(tool, stub, GREY)
	var root := _section(side, ROOT_LE, ROOT_TE, ROOT_THICK)
	var tip := _section(side, TIP_LE, TIP_TE, TIP_THICK)
	var middle: Vector3 = (_centre_of(root) + _centre_of(tip)) * 0.5
	for k in range(4):
		var n: int = (k + 1) % 4
		var quad: Array = [root[k], root[n], tip[n], tip[k]]
		_facet(tool, quad, _centre_of(quad) - middle, BELLY if k == 3 or k == 2 else GREY)
	_cap(tool, root, _local(side, 0.0, -1.0, 0.0), GREY)
	_cap(tool, tip, _local(side, 0.0, 1.0, 0.0), GREY)


## A WING SECTION at the chord from `le` to `te` (each (aft, out) about the pivot): leading edge, the top ridge, the
## trailing edge and the bottom under the ridge, in pivot-local coordinates.
func _section(side: float, le: Vector2, te: Vector2, thick: float) -> Array[Vector3]:
	var ridge: Vector2 = le.lerp(te, 0.40)
	return [_local(side, le.x, le.y, thick * 0.30), _local(side, ridge.x, ridge.y, thick),
		_local(side, te.x, te.y, thick * 0.20), _local(side, ridge.x, ridge.y, 0.0)]


## A POINT IN THE PIVOT'S FRAME: `aft` metres aft of the pivot, `out` metres outboard, `up` metres over the wing's plane.
static func _local(side: float, aft: float, out: float, up: float) -> Vector3:
	return Vector3(side * out, up, aft)


## A FIN, canted out, from its root bedded in the nacelle top to the published height: the fixed part ahead of the
## rudder's hinge, full height, and the strip aft of the hinge under the rudder's foot. The rudder is its own part.
func _fin(tool: SurfaceTool, side: float) -> void:
	var under: float = (RUDDER_FOOT - RUDDER_FOOT_GAP - FIN_ROOT_HEIGHT) / (HEIGHT - FIN_ROOT_HEIGHT)
	var c: float = -RUDDER_COVE
	_block(tool, [_fin_at(side, 0.0, 0.0, -1.0), _fin_at(side, 0.0, 0.0, 1.0), _fin_at(side, 0.0, RUDDER_HINGE, 1.0, c),
		_fin_at(side, 0.0, RUDDER_HINGE, -1.0, c), _fin_at(side, 1.0, 0.0, -1.0), _fin_at(side, 1.0, 0.0, 1.0),
		_fin_at(side, 1.0, RUDDER_HINGE, 1.0, c), _fin_at(side, 1.0, RUDDER_HINGE, -1.0, c)], GREY)
	_block(tool, [_fin_at(side, 0.0, RUDDER_HINGE, -1.0, c), _fin_at(side, 0.0, RUDDER_HINGE, 1.0, c),
		_fin_at(side, 0.0, 1.0, 1.0), _fin_at(side, 0.0, 1.0, -1.0), _fin_at(side, under, RUDDER_HINGE, -1.0, c),
		_fin_at(side, under, RUDDER_HINGE, 1.0, c), _fin_at(side, under, 1.0, 1.0), _fin_at(side, under, 1.0, -1.0)], GREY)


## A POINT ON A FIN: `up` 0 at its root to 1 at its tip, `chord` 0 at the leading edge to 1 at the trailing edge, and
## `face` -1 or +1 for the inner or outer skin (0 for the middle plane), and `aft` metres further aft. Everything along
## the fin is linear in `up`, so the hinge line through `chord` RUDDER_HINGE is straight.
func _fin_at(side: float, up: float, chord: float, face: float, aft: float = 0.0) -> Vector3:
	var out: float = lerpf(FIN_ROOT.x, FIN_TIP.x, up) + face * _fin_half(up)
	var along: float = lerpf(lerpf(FIN_ROOT.y, FIN_TIP.y, up), lerpf(FIN_ROOT.z, FIN_TIP.z, up), chord) + aft
	return point(side * out, lerpf(FIN_ROOT_HEIGHT, HEIGHT, up), along)


func _fin_half(up: float) -> float:
	return lerpf(FIN_THICK.x, FIN_THICK.y, up) * 0.5


## THE RUDDER'S FOOT as a fraction of the fin's height.
static func _rudder_foot() -> float:
	return (RUDDER_FOOT - FIN_ROOT_HEIGHT) / (HEIGHT - FIN_ROOT_HEIGHT)


## A RUDDER, on its hinge line from its foot to the fin tip: in section a diamond, a knife-edged nose on the hinge line,
## shoulders the fin's full thickness as far aft of it as they are wide, and a knife-edged trailing edge.
func _rudder(side: float, named: String) -> void:
	var foot: float = _rudder_foot()
	var low: Vector3 = _fin_at(side, foot, RUDDER_HINGE, 0.0)
	var high: Vector3 = _fin_at(side, 1.0, RUDDER_HINGE, 0.0)
	var hinge := _hinge("Rudder" + named, self, low, high - low, _fin_at(side, foot, 1.0, 0.0), Vector3.RIGHT)
	var rings: Array = []
	for up in [foot, 1.0]:
		var ring: Array = []
		for p in [_fin_at(side, up, RUDDER_HINGE, 0.0), _fin_at(side, up, RUDDER_HINGE, 1.0, _fin_half(up)),
				_fin_at(side, up, 1.0, 0.0), _fin_at(side, up, RUDDER_HINGE, -1.0, _fin_half(up))]:
			ring.append((p as Vector3) - hinge.position)
		rings.append(ring)
	var tool := _tool()
	_loft(tool, rings, func(_k: int) -> Color: return GREY)
	_add("Rudder" + named, tool, hinge)


## A STABILATOR, all-moving, on a spindle straight across the aeroplane at STAB_SPINDLE: a pitch hinge, and the roll
## hinge inside it on the same line, and the tailplane in that.
func _stabilator(side: float, named: String) -> void:
	var spindle: Vector3 = point(side * STAB_ROOT.x, STAB_HEIGHT.x, STAB_SPINDLE)
	var trailing: Vector3 = point(side * STAB_ROOT.x, STAB_HEIGHT.x, STAB_ROOT.z)
	var pitch := _hinge("StabilatorPitch" + named, self, spindle, Vector3.RIGHT, trailing, Vector3.UP)
	var roll := _hinge("StabilatorRoll" + named, pitch, Vector3.ZERO, Vector3.RIGHT, trailing - spindle, Vector3.UP)
	var root_t: float = STAB_THICK.x * 0.5
	var tip_t: float = STAB_THICK.y * 0.5
	var corners: Array = []
	for p in [
			point(side * STAB_ROOT.x, STAB_HEIGHT.x - root_t, STAB_ROOT.y), point(side * STAB_ROOT.x, STAB_HEIGHT.x - root_t, STAB_ROOT.z),
			point(side * STAB_ROOT.x, STAB_HEIGHT.x + root_t, STAB_ROOT.z), point(side * STAB_ROOT.x, STAB_HEIGHT.x + root_t, STAB_ROOT.y),
			point(side * STAB_TIP.x, STAB_HEIGHT.y - tip_t, STAB_TIP.y), point(side * STAB_TIP.x, STAB_HEIGHT.y - tip_t, STAB_TIP.z),
			point(side * STAB_TIP.x, STAB_HEIGHT.y + tip_t, STAB_TIP.z), point(side * STAB_TIP.x, STAB_HEIGHT.y + tip_t, STAB_TIP.y)]:
		corners.append((p as Vector3) - spindle)
	var tool := _tool()
	_block(tool, corners, GREY)
	_add("Stabilator" + named, tool, roll)


## THE FOUR SPOILER PANELS OF ONE WING, one part on one hinge that is a CHILD OF THE WING'S PIVOT, so the hinge line
## swings with the panel. Built in the pivot's frame at the build's 20 degrees. The hinge runs along the panels' leading
## edges at SPOILER_CHORD.x, laid SPOILER_PROUD over the wing's drawn top -- and lifted, if anywhere along it the drawn
## top rises closer than that, since the top's two triangles fold across their diagonal and a straight line between two
## proud points can dip under the fold. Each panel's trailing edge lies proud of the drawn top where it is.
func _spoiler_panels(side: float, named: String, pivot: Node3D) -> void:
	var first: float = SPOILER_SPANS[0][0]
	var last: float = SPOILER_SPANS[-1][1]
	var inner: Vector3 = _proud_of_the_wing(side, first, SPOILER_CHORD.x)
	var outer: Vector3 = _proud_of_the_wing(side, last, SPOILER_CHORD.x)
	var lift: float = 0.0
	for k in range(41):
		var f: float = float(k) / 40.0
		lift = maxf(lift, _proud_of_the_wing(side, lerpf(first, last, f), SPOILER_CHORD.x).y - inner.lerp(outer, f).y)
	inner.y += lift
	outer.y += lift
	var hinge := _hinge("Spoilers" + named, pivot, inner, outer - inner,
		_proud_of_the_wing(side, first, SPOILER_CHORD.y), Vector3.UP)
	var tool := _tool()
	for span in SPOILER_SPANS:
		var corners: Array = []
		for s in [float(span[0]), float(span[1])]:
			var front: Vector3 = inner.lerp(outer, (s - first) / (last - first))
			var back: Vector3 = _proud_of_the_wing(side, s, SPOILER_CHORD.y)
			var thick := Vector3(0.0, SPOILER_THICK, 0.0)
			for p in [front, back, back + thick, front + thick]:
				corners.append((p as Vector3) - hinge.position)
		_block(tool, corners, SPOILER)
	_add("Spoilers" + named, tool, hinge)


## A POINT SPOILER_PROUD OVER THE WING PANEL'S DRAWN TOP, in the pivot's frame at the build's 20 degrees: `span` 0 at the
## root rib to 1 at the tip, `chord` 0 at the leading edge to 1 at the trailing edge.
func _proud_of_the_wing(side: float, span: float, chord: float) -> Vector3:
	var le: Vector2 = ROOT_LE.lerp(TIP_LE, span)
	var te: Vector2 = ROOT_TE.lerp(TIP_TE, span)
	var plan: Vector2 = le.lerp(te, chord)
	return _local(side, plan.x, plan.y, _wing_top(side, plan) + SPOILER_PROUD)


## THE WING PANEL'S DRAWN TOP over a plan point (aft, out) about the pivot, read off the very triangles `_wing` draws:
## its two top facets, each split as `_facet` splits it. -INF off the panel.
func _wing_top(side: float, plan: Vector2) -> float:
	var root := _section(side, ROOT_LE, ROOT_TE, ROOT_THICK)
	var tip := _section(side, TIP_LE, TIP_TE, TIP_THICK)
	var q := Vector2(side * plan.y, plan.x)
	var best: float = -INF
	for k in [0, 1]:
		var quad: Array = [root[k], root[k + 1], tip[k + 1], tip[k]]
		for tri in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
			var a: Vector3 = tri[0]
			var b: Vector3 = tri[1]
			var c: Vector3 = tri[2]
			var hit: Variant = _height_in(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), q, a.y, b.y, c.y)
			if hit != null:
				best = maxf(best, float(hit))
	return best


## Where a vertical line through `q` meets a triangle given in plan with its corners' heights, or null if it misses.
static func _height_in(a: Vector2, b: Vector2, c: Vector2, q: Vector2, ya: float, yb: float, yc: float) -> Variant:
	var d: float = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(d) < 1e-12:
		return null
	var u: float = ((b.y - c.y) * (q.x - c.x) + (c.x - b.x) * (q.y - c.y)) / d
	var v: float = ((c.y - a.y) * (q.x - c.x) + (a.x - c.x) * (q.y - c.y)) / d
	var w: float = 1.0 - u - v
	if u < -1e-6 or v < -1e-6 or w < -1e-6:
		return null
	return u * ya + v * yb + w * yc


## A HINGE: a node at `at` in `parent`'s frame, turning about `along`, its axis WOUND SO A POSITIVE TURN CARRIES `probe`
## (a point in the same frame) TOWARDS `wanted`. Asked of the geometry rather than reasoned per side, so a mirrored hinge
## cannot come out turning the wrong way; `tests/tomcat.gd` reads every surface's direction back off its vertices.
func _hinge(named: String, parent: Node3D, at: Vector3, along: Vector3, probe: Vector3, wanted: Vector3) -> Node3D:
	var hinge := Node3D.new()
	# "HINGE" ON THE END, so a hinge is never found in place of the part it carries: `find_child("RudderPort")` went to
	# the hinge first, being its parent, and the first checks read a rudder that never moved.
	hinge.name = named + "Hinge"
	hinge.position = at
	var axis: Vector3 = along.normalized()
	if axis.cross(probe - at).dot(wanted) < 0.0:
		axis = -axis
	hinge.set_meta("axis", axis)
	parent.add_child(hinge)
	_hinges[named] = hinge
	return hinge


## A VENTRAL FIN under a nacelle, its root bedded in the nacelle's underside and its foot canted out.
func _ventral(tool: SurfaceTool, side: float) -> void:
	var root_h: float = 1.20
	var x: float = side * NOZZLE_OUT
	var foot: float = side * (NOZZLE_OUT + 0.18)
	_block(tool, [
		point(x - 0.05, root_h, VENTRAL.x), point(x + 0.05, root_h, VENTRAL.x),
		point(x + 0.05, root_h, VENTRAL.y), point(x - 0.05, root_h, VENTRAL.y),
		point(foot - 0.03, VENTRAL.z + 0.25, VENTRAL.x + 0.9), point(foot + 0.03, VENTRAL.z + 0.25, VENTRAL.x + 0.9),
		point(foot + 0.03, VENTRAL.z, VENTRAL.y), point(foot - 0.03, VENTRAL.z, VENTRAL.y)], GREY)


## THE TWIN CHIN POD: two short blocks side by side under the nose, their tops bedded in the belly.
func _chin_pod(tool: SurfaceTool) -> void:
	for side in [1.0, -1.0]:
		var x: float = side * (CHIN_POD.w + 0.02)
		var w: float = CHIN_POD.w
		var roof: float = 1.20
		_block(tool, [
			point(x - w * 0.6, roof, CHIN_POD.x), point(x + w * 0.6, roof, CHIN_POD.x),
			point(x + w * 0.6, CHIN_POD.z + 0.10, CHIN_POD.x + 0.25), point(x - w * 0.6, CHIN_POD.z + 0.10, CHIN_POD.x + 0.25),
			point(x - w, roof, CHIN_POD.y), point(x + w, roof, CHIN_POD.y),
			point(x + w, CHIN_POD.z, CHIN_POD.y - 0.15), point(x - w, CHIN_POD.z, CHIN_POD.y - 0.15)], DARK)


## WHERE THE GUN PORT IS, in the craft's frame: the front of the vents, half way across them and half way up. The
## simulation fires the M61A1 from here (`loadout_of`, kind TOMCAT), and tests/jet_arms.gd holds every round to it.
func gun_port() -> Vector3:
	return point(-0.77, GUN.z, GUN.x)


## THE GUN'S MUZZLE VENTS on the port side of the nose: a dark panel set proud of the skin, bedded into it.
func _gun(tool: SurfaceTool) -> void:
	var skin: float = -0.70
	var proud: float = -0.84
	_block(tool, [
		point(skin, GUN.z - 0.10, GUN.x), point(proud, GUN.z - 0.10, GUN.x),
		point(proud, GUN.z + 0.10, GUN.x), point(skin, GUN.z + 0.10, GUN.x),
		point(skin, GUN.z - 0.10, GUN.y), point(proud, GUN.z - 0.10, GUN.y),
		point(proud, GUN.z + 0.10, GUN.y), point(skin, GUN.z + 0.10, GUN.y)], DARK)


## THE NOSE GEAR: a leg down from the belly and two wheels side by side, standing on the ground.
func _nose_gear(tool: SurfaceTool) -> void:
	var axle: float = NOSE_TYRE_RADIUS
	_box(tool, point(0.0, (axle + 1.14) * 0.5, NOSE_GEAR_STATION), Vector3(0.12, 1.14 - axle, 0.12), METAL)
	for side in [1.0, -1.0]:
		_wheel(tool, point(side * 0.16, axle, NOSE_GEAR_STATION), NOSE_TYRE_RADIUS, 0.16)


## A MAIN GEAR: a raked leg from the nacelle's outer side under the glove down to a single wheel at half the track.
func _main_gear(tool: SurfaceTool, side: float) -> void:
	var axle := point(side * TRACK * 0.5, MAIN_TYRE_RADIUS, MAIN_GEAR_STATION)
	var root := point(side * 2.05, 1.35, MAIN_GEAR_STATION - 0.30)
	_bar(tool, root, axle + Vector3(-side * MAIN_TYRE_WIDE * 0.5, 0.0, 0.0), 0.16, METAL)
	_wheel(tool, axle, MAIN_TYRE_RADIUS, MAIN_TYRE_WIDE)


## ---- geometry helpers ---------------------------------------------------------------------------------------------

## A WHEEL of WHEEL_SIDES facets that CIRCUMSCRIBES the real tyre: its flats are at the tyre's radius, so the bottom flat
## stands on the ground. A polygon through the circle would stand low.
func _wheel(tool: SurfaceTool, centre: Vector3, radius: float, wide: float) -> void:
	var corner: float = radius / cos(PI / WHEEL_SIDES)
	var h := Vector3(wide * 0.5, 0.0, 0.0)
	var ring: Array[Vector3] = []
	for k in range(WHEEL_SIDES):
		var t: float = TAU * (float(k) + 0.5) / WHEEL_SIDES - PI * 0.5
		ring.append(Vector3(0.0, sin(t), cos(t)) * corner)
	for k in range(WHEEL_SIDES):
		var n: int = (k + 1) % WHEEL_SIDES
		_facet(tool, [centre - h + ring[k], centre - h + ring[n], centre + h + ring[n], centre + h + ring[k]],
			ring[k] + ring[n], TYRE)
	for face in [1.0, -1.0]:
		var hub: Vector3 = centre + h * face
		var rim: Array[Vector3] = []
		for c in ring:
			rim.append(hub + c)
		_cap(tool, rim, Vector3(face, 0.0, 0.0), METAL)


## A SQUARE BAR from `a` to `b`, `wide` across.
func _bar(tool: SurfaceTool, a: Vector3, b: Vector3, wide: float, tint: Color) -> void:
	var along: Vector3 = (b - a).normalized()
	var u: Vector3 = along.cross(Vector3.FORWARD).normalized() * wide * 0.5
	if u.length_squared() < 1e-6:
		u = along.cross(Vector3.RIGHT).normalized() * wide * 0.5
	var v: Vector3 = along.cross(u).normalized() * wide * 0.5
	_block(tool, [a - u - v, a + u - v, a + u + v, a - u + v, b - u - v, b + u - v, b + u + v, b - u + v], tint)


func _box(tool: SurfaceTool, at: Vector3, size: Vector3, tint: Color) -> void:
	var h: Vector3 = size * 0.5
	_block(tool, [at + Vector3(-h.x, -h.y, -h.z), at + Vector3(h.x, -h.y, -h.z), at + Vector3(h.x, h.y, -h.z),
		at + Vector3(-h.x, h.y, -h.z), at + Vector3(-h.x, -h.y, h.z), at + Vector3(h.x, -h.y, h.z),
		at + Vector3(h.x, h.y, h.z), at + Vector3(-h.x, h.y, h.z)], tint)


## A PRISM over a plan `outline` of (out, station) points, its bottom and top each a function of `out`, so a glove can
## thin towards its leading edge. Convex outlines only.
func _prism(tool: SurfaceTool, outline: Array[Vector2], side: float, bottom: Callable, top: Callable, tint: Color) -> void:
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for p in outline:
		low.append(point(side * p.x, bottom.call(p.x), p.y))
		high.append(point(side * p.x, top.call(p.x), p.y))
	var centre: Vector3 = (_centre_of(low) + _centre_of(high)) * 0.5
	for k in range(outline.size()):
		var n: int = (k + 1) % outline.size()
		var quad: Array = [low[k], low[n], high[n], high[k]]
		_facet(tool, quad, _centre_of(quad) - centre, tint)
	for ring_and_out in [[low, Vector3.DOWN], [high, Vector3.UP]]:
		var ring: Array[Vector3] = ring_and_out[0]
		var mid: Vector3 = _centre_of(ring)
		for k in range(ring.size()):
			_tri(tool, mid, ring[k], ring[(k + 1) % ring.size()], ring_and_out[1], tint)


## A CONVEX BLOCK from two matching loops of four corners, each face wound to look away from the block's middle.
func _block(tool: SurfaceTool, corners: Array, tint: Color) -> void:
	var centre: Vector3 = _centre_of(corners)
	for f in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		var quad: Array = [corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]]]
		_facet(tool, quad, _centre_of(quad) - centre, tint)


## A LOFT through matching rings, closed at both ends. `tint` takes the facet's index round the ring; the caps take
## `front` and `back`, or the ring's first facet's tint.
func _loft(tool: SurfaceTool, rings: Array, tint: Callable, front: Variant = null, back: Variant = null) -> void:
	for r in range(rings.size() - 1):
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var centre: Vector3 = (_centre_of(a) + _centre_of(b)) * 0.5
		for k in range(a.size()):
			var n: int = (k + 1) % a.size()
			var quad: Array = [a[k], a[n], b[n], b[k]]
			_facet(tool, quad, _centre_of(quad) - centre, tint.call(k))
	var first: Array = rings[0]
	var last: Array = rings[-1]
	_cap(tool, first, _centre_of(first) - _centre_of(rings[1]), front if front is Color else tint.call(0))
	_cap(tool, last, _centre_of(last) - _centre_of(rings[-2]), back if back is Color else tint.call(0))


## A FAN closing a ring, wound to look along `out`.
func _cap(tool: SurfaceTool, ring: Array, out: Vector3, tint: Color) -> void:
	var mid: Vector3 = _centre_of(ring)
	for k in range(ring.size()):
		_tri(tool, mid, ring[k], ring[(k + 1) % ring.size()], out, tint)


## ONE QUAD FACET, both its triangles wound to look along `out`.
func _facet(tool: SurfaceTool, quad: Array, out: Vector3, tint: Color) -> void:
	_tri(tool, quad[0], quad[1], quad[2], out, tint)
	_tri(tool, quad[0], quad[2], quad[3], out, tint)


## ONE TRIANGLE, wound clockwise as seen from `out` -- Godot's front face -- with its own flat normal, or skipped if it
## has no area.
func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-12:
		return
	if normal.dot(out) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	var n: Vector3 = normal.normalized()
	for corner in [a, b, c]:
		tool.set_color(tint)
		tool.set_normal(n)
		tool.add_vertex(corner)


static func _centre_of(points: Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in points:
		sum += p
	return sum / float(maxi(points.size(), 1))


func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


## ONE NAMED PART. Every visible mesh here is added through this, with its side in its name, so Godot never has to
## rename a duplicate to `@MeshInstance3D@N` (`tests/named_parts.gd`).
func _add(title: String, tool: SurfaceTool, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = _material
	(parent if parent != null else self).add_child(mesh)
	return mesh


## THE FUSELAGE, IN TWO SURFACES OF ONE MESH: the painted skin, DOUBLE-SIDED, and the canopy, SEE-THROUGH and
## double-sided. One mesh, so it is still one closed solid for `tests/tomcat.gd`'s crew-inside parity.
##
## WHY BOTH ARE DOUBLE-SIDED. Every face here is wound to look outward, and from inside a closed solid with back faces
## culled the crew see NONE of it: the first pictures from the pilot's eye were open sky with the RIO's panel floating in
## it, no nose, no canopy frame, no cockpit walls, while every check was green (`tests/tomcat_seat_shot.gd`). The
## F/A-18's tub and canopy are double-sided for the same reason. The canopy is glass a crew can see out through: drawn
## opaque from inside, it would be a lid.
func _add_fuselage(skin: SurfaceTool, glass: SurfaceTool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Fuselage"
	var mesh: ArrayMesh = Plating.weld(skin)
	glass.commit(mesh)
	var inside := _paint()
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, inside)
	var pane := StandardMaterial3D.new()
	pane.vertex_color_use_as_albedo = true
	pane.vertex_color_is_srgb = true
	pane.albedo_color = Color(1.0, 1.0, 1.0, 0.40)
	pane.roughness = 0.08
	pane.metallic = 0.3
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(1, pane)
	node.mesh = mesh
	add_child(node)
	return node


func _detail(mesh: MeshInstance3D) -> void:
	mesh.visibility_range_end = DETAIL_RANGE
	mesh.visibility_range_end_margin = DETAIL_HYSTERESIS
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _paint() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# Without this a 0.52 grey draws at about 0.75: vertex colour is linear unless the material says otherwise
	# (`lane/carrier`).
	material.vertex_color_is_srgb = true
	material.roughness = 0.55
	material.metallic = 0.05
	return material
