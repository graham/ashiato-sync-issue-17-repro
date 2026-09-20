@tool
extends Node3D
class_name SavoiaAirframe
## PORCO ROSSO'S RED FLYING BOAT, DRAWN: the "Savoia S.21" of the 1992 film, a single-seat racing flying boat with a deep
## round-nosed red hull on a tan planing bottom, a straight shoulder wing on struts over it, the engine in a nacelle on
## struts over the wing driving a two-bladed TRACTOR propeller, two copper radiator drums at the nacelle's front, a
## stabilising float under each wing, an open cockpit behind the wing, a tall round-topped fin in the Italian tricolour
## with the tailplane on struts, and two machine guns in the nose.
##
## THE FILM'S AEROPLANE AND NOT THE REAL S.21. The real SIAI S.21 of 1921 was a BIPLANE flying boat with a four-bladed
## PUSHER propeller behind an engine slung between the wings, 7.62 m long and 7.69 m across, and one was built. The film
## borrows its name and draws something else: a monoplane with a tractor propeller over the wing, which Wikipedia (after
## McCarthy, 1999) says most resembles the Macchi M.33 of 1925. The user asked for the film's look -- "as much like the
## pictures as you can find" -- so the film's silhouette wins everywhere, and the M.33's engineering (a strut-mounted
## nacelle over a cantilever shoulder wing, stabilising floats, a planing step) is what makes it hang together. Every
## difference is written down in `craft/savoia/sources.md`.
##
## THE FRAME. Every constant here is a STATION `s` in metres aft of the hull's nose, a HEIGHT `h` in metres over the keel
## at the step (the lowest point of the hull, which is where a beaching trolley or the sea bed would take it), and an
## `out` in metres to starboard. `station(s)` and `height(h)` turn them into the craft's frame, whose box runs from the
## hull's nose to the rudder's trailing edge and from the keel to the nacelle's top. The gun barrels stand 0.12 m proud
## of the nose, outside that box, as the F-16's pitot does outside its own.
##
## WHERE THE NUMBERS COME FROM, tagged as `modelling_here.md` asks:
## - [KIT] PUBLISHED: FineMolds' 1/48 kit of the film's aeroplane is 21.5 cm across the wing, so 10.32 m. The one number
##   that scales everything.
## - [PLAN] MEASURED off an underside photograph of a finished 1/48 kit, looking straight up at it, at 119.5 px a metre
##   set by that span; [SIDE] off a near-broadside of another, at 109 px a metre set by the plan's hull length. Both are
##   perspective photographs of a model, not drawings, so these are good to about 0.1 m and no better. The two agree on
##   the step, 4.05 m and 4.00 m aft of the nose, which neither was scaled to.
## - ESTIMATE, with what it was reasoned from, everywhere a photograph could not say.
## The photographs are named in `sources.md` and are NOT in the repo: they are of film merchandise, used for study only.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT: the house's low-poly look, the Hawkeye the reference.
## - HULL: 12 facets a ring through 16 measured rings -- per side: crown, shoulder, flank, bilge, chine and the V of the
##   planing bottom -- so the chine and the step are hard edges, as a boat's are. (The Hawkeye's fuselage is 20.)
## - NACELLE_SIDES 12 (the Hawkeye's nacelle round is 16). FLOAT_SIDES 8. SPINNER_SIDES 8. RADIATOR_SIDES 10. GUN_SIDES 6.
## - A wing or tail section is EIGHT points, four on each face.
## Every face carries its own normal, so no edge is smoothed.
##
## THE COCKPIT IS OPEN, and that decides where the pilot sits. The film puts Porco's head just over the wing, behind its
## trailing edge, and the wing stands 0.24 m over the hull on struts with the nacelle 0.50 m over the wing: so a pilot
## looks forward over the wing and UNDER the nacelle, past its struts, which is the character of the aeroplane. The eye
## (`EYE`) is 0.26 m over the wing's top and the seat hangs from it -- which leaves the cockpit's rim, raised on a hump,
## at the pilot's chest rather than at the shoulder where the film draws it. A lower seat puts the eye level with the
## wing and a VR pilot looks into its trailing edge; that is a worse deviation than a pilot sitting tall.
##
## FOUR THINGS MOVE, each on a hinge: the ailerons, the elevators, the rudder and the propeller. `set_ailerons`,
## `set_elevator`, `set_rudder` and `set_propeller`, driven by `VehicleView` from the linkage as `SkyhawkAirframe`'s are.
##
## NOT IN VehicleView's `_body`: `_show_body` paints one flat material over every mesh there, and this airframe's colour
## is in its vertices (`lane/fleet`, Hawkeye).

## THE SIMULATION OWNS THE SHAPE: `Sim.Kind.SAVOIA`, since 2026-09-18. Its box is 0.63 x 1.63 x 4.315 m half-extents --
## the hull's beam, keel to nacelle top, hull nose to rudder -- its half-span 5.16 m, 1,450 kg, one seat, and it is an
## amphibian with the sea 0.30 m up its hull at rest (`savoia_shape` in `cockpit_world.cpp`). Until then those numbers
## were a draft kept here, and `tests/savoia.gd`'s clock went red the day the kind arrived, as it was written to.

## THE PAINT. The film's red over a tan planing bottom, and the Italian tricolour on the fin and in bands under the wing. sRGB, ESTIMATE from the photographs under their own lighting.
const RED := Color(0.80, 0.09, 0.07)
const TAN := Color(0.74, 0.62, 0.42)
const GREEN := Color(0.06, 0.46, 0.20)
const WHITE := Color(0.93, 0.91, 0.86)
const COPPER := Color(0.70, 0.44, 0.24)
const BLACK := Color(0.07, 0.07, 0.07)
const PIT := Color(0.22, 0.17, 0.13)
const BLADE := Color(0.74, 0.77, 0.80)
const GLASS := Color(0.55, 0.70, 0.78)

## THE HULL, ring by ring: [s, top, beam half-width, beam h, chine half-width, chine h, keel h] [PLAN, SIDE].
## - The forebody is a V-bottomed planing hull with the keel on the datum from 1.4 m to the STEP at 4.05 m, where the
##   keel jumps 0.12 m up (two rings a centimetre apart) and the afterbody's bottom then rises to the tail post.
## - The top line is level at about 1.28 m except for the COAMING HUMP over the cockpit, to 1.46 m, which the side photo
##   shows as a bump behind the wing (1.38 m there) and which carries the cockpit's rim up round a pilot sitting tall.
## - Beam: 1.26 m across at its widest [PLAN], tapering to a point at 8.41 m under the fin. The nose is rounded over its
##   first 0.3 m by three rings, since the kits' is a bulb and not a bow.
const SECTIONS: Array = [
	[0.03, 0.86, 0.16, 0.72, 0.12, 0.58, 0.54],
	[0.12, 0.98, 0.33, 0.71, 0.27, 0.40, 0.32],
	[0.30, 1.08, 0.46, 0.70, 0.38, 0.28, 0.18],
	[0.70, 1.22, 0.58, 0.68, 0.50, 0.15, 0.05],
	[1.40, 1.28, 0.63, 0.66, 0.56, 0.13, 0.00],
	[2.40, 1.28, 0.63, 0.65, 0.56, 0.13, 0.00],
	[3.40, 1.27, 0.60, 0.64, 0.54, 0.12, 0.00],
	[4.05, 1.30, 0.55, 0.64, 0.50, 0.12, 0.00],
	[4.06, 1.30, 0.55, 0.64, 0.46, 0.26, 0.12],
	[4.15, 1.40, 0.53, 0.66, 0.44, 0.30, 0.16],
	[4.65, 1.46, 0.47, 0.68, 0.38, 0.40, 0.24],
	[5.15, 1.42, 0.41, 0.72, 0.31, 0.50, 0.34],
	[5.60, 1.29, 0.36, 0.76, 0.27, 0.57, 0.42],
	[6.40, 1.16, 0.26, 0.82, 0.19, 0.68, 0.58],
	[7.20, 1.12, 0.18, 0.88, 0.13, 0.80, 0.74],
	[7.90, 1.10, 0.11, 0.94, 0.08, 0.90, 0.86],
]
## The nose's point, and the tail post's.
const NOSE: Vector2 = Vector2(0.0, 0.72)
const TAIL_POST: Vector2 = Vector2(8.41, 1.00)
const STEP: float = 4.05
const HULL_SIDES: int = 12
## The crown sits this share of the beam out, and is where the cockpit's opening is cut: 0.58 m across at the pilot's hips.
const CROWN_OUT: float = 0.62

## THE COCKPIT: the opening cut through the crown between two rings, a tub down to a floor, a seat and a windscreen.
## ESTIMATE, reasoned from the side photo's opening just behind the wing and from the eye (see the doc block above).
const COCKPIT: Vector2 = Vector2(4.15, 5.15)  # fore and aft rings of the opening
## The pilot's eye: 0.26 m over the wing's top (1.72) and 0.24 m under the nacelle's belly (2.22), 0.85 m behind the
## wing's trailing edge -- the head just over the wing, as the film draws it. The first build had it 0.10 m lower, and
## from there the wing's trailing edge filled the forward view.
const EYE: Vector2 = Vector2(4.95, 1.98)
## The floor the pilot's feet stand on, DERIVED from the eye: the game's rig puts the eye `CockpitStation.EYE_HEIGHT` over
## the seat's anchor, so a floor typed beside the eye would be a second copy of one number.
const COCKPIT_FLOOR: float = EYE.y - CockpitStation.EYE_HEIGHT
const COCKPIT_FLOOR_HALF: float = 0.22
## The ROOM, the largest box promised clear inside the tub, from the floor up: [s from, s to, half width, h to].
const ROOM: Array = [4.25, 5.10, 0.20, 1.26]
## THE WINDSCREEN: a raked three-pane screen on the coaming ahead of the pilot, lower than the eye as a racer's is.
const SCREEN: Array = [4.12, 4.34, 0.26, 1.34, 1.80]  # foot s, top s, half width, foot h, top h

## THE WING [KIT, PLAN]: 10.32 m across, 1.60 m chord, the leading edge swept back 7 degrees (the plan's leading edge runs
## back 0.07 m for each 0.55 m out), no dihedral (the front view draws it straight), its chord line 1.62 m over the keel
## [SIDE], 12 per cent thick (ESTIMATE, the M.33's was "fairly thick"). The tip rounds off over the last 0.26 m.
const WING_LE_ROOT: float = 2.50
const WING_SWEEP: float = deg_to_rad(7.0)
const WING_CHORD: float = 1.60
const WING_H: float = 1.62
const WING_THICK: float = 0.12
const WING_TIP: float = 5.16
## The rounded tip: [out, how far the leading edge comes back, how far the trailing edge comes forward].
const WING_TIP_ROUND: Array = [[4.90, 0.0, 0.0], [5.05, 0.12, 0.05], [5.16, 0.45, 0.15]]
## THE TRICOLOUR BANDS [PLAN]: green then white then a red tip, UNDER the wing only; the top is plain red. The late S.21F,
## after the rebuild, carries its tricolour "on the vertical stabiliser and under the wing" (Marcello Rosa's build notes,
## `sources.md`). One kit painted the bands on top as well and the first build followed it.
const BAND_GREEN: Vector2 = Vector2(1.70, 3.05)
const BAND_WHITE: Vector2 = Vector2(3.05, 4.30)
## THE AILERONS: the outer wing's trailing quarter from 3.05 to 4.90 m out, hinged at 75 per cent of the chord. Travel
## ESTIMATE, 22 degrees each way.
const AILERON: Vector2 = Vector2(3.05, 4.90)
const HINGE_CHORD: float = 0.75
const AILERON_TRAVEL: float = deg_to_rad(22.0)

## THE FLOATS [PLAN, SIDE]: 2.1 m teardrops centred 3.25 m out, from 2.64 to 4.75 m aft, their keels 0.28 m over the hull's,
## so on still water the aeroplane sits on its hull and a float just kisses the sea. Rows: [s, half width, bottom, top].
const FLOAT_OUT: float = 3.25
const FLOAT_ROWS: Array = [[2.64, 0.04, 0.54, 0.62], [2.85, 0.20, 0.36, 0.78], [3.30, 0.25, 0.28, 0.83],
	[3.90, 0.22, 0.30, 0.81], [4.40, 0.14, 0.40, 0.74], [4.75, 0.03, 0.56, 0.62]]
const FLOAT_SIDES: int = 8
## The two struts each float hangs from, at these stations.
const FLOAT_STRUTS: Array = [3.10, 3.80]

## THE CABANE: four struts from the hull's shoulders up to the wing's underside at its two spars, and a V brace each side
## from the hull's flank out to the wing 1.7 m out [SIDE]. ESTIMATE in detail; the photographs show struts, not drawings.
const SPARS: Array = [2.85, 3.65]
const STRUT: float = 0.055

## THE NACELLE [SIDE, FRONT]: from the cowl's face at 1.85 m to a tail at 4.25 m, its top 3.26 m over the keel and its
## belly 2.22 m, and 0.72 m across [FRONT: 0.75 to 0.82 m over the cylinder banks at 140 px a metre]. In section it is a
## V-12's: a narrow crankcase below, the flanks upright, and the two cylinder banks as two lobes along the top with a
## valley between them, which is what the kits' front view shows. The first build drew a rounded oblong 0.84 m across,
## an estimate, and beside the hull it read as a bulb. Rows: [s, half width, bottom, top].
const NACELLE_ROWS: Array = [[1.85, 0.26, 2.40, 2.88], [2.05, 0.33, 2.28, 3.10], [2.50, 0.36, 2.22, 3.24],
	[3.20, 0.35, 2.22, 3.26], [3.70, 0.29, 2.30, 3.20], [4.05, 0.18, 2.48, 3.05], [4.25, 0.05, 2.70, 2.86]]
const NACELLE_SIDES: int = 12
## The struts the nacelle stands on, from the wing's top: [out, s at the wing, s at the nacelle].
const NACELLE_STRUTS: Array = [[0.26, 2.75, 2.75], [0.26, 3.55, 3.55], [0.26, 2.75, 3.50]]
## THE RADIATORS: the Fiat's two copper drums either side of the cowl [SIDE, PLAN]: [out, h, radius, s from, s to].
const RADIATOR: Array = [0.50, 2.42, 0.20, 1.95, 2.27]
const RADIATOR_SIDES: int = 10
## The exhaust pipes along each upper side, and three round ports low on each flank (drawn square, as the look is).
const EXHAUST: Array = [0.33, 2.98, 2.15, 3.65]  # out, h, s from, s to
const PORTS: Array = [2.90, 3.15, 3.40]
const PORT_H: float = 2.58

## THE PROPELLER: two blades, 2.2 m across, on a hub 2.60 m over the keel at 1.80 m aft of the nose, under a long spinner.
## [FRONT] reads the blades at 2.3 to 2.5 m, but the propeller is the part nearest that camera and so the most magnified;
## 2.2 m is the most the hull allows, its tips 0.22 m over the hull's top. The first build's 2.0 m looked small.
const HUB: Vector2 = Vector2(1.80, 2.60)
const PROP_RADIUS: float = 1.10
const SPINNER: Vector2 = Vector2(0.50, 0.18)  # length ahead of the hub, radius
const SPINNER_SIDES: int = 8
## Parked across, not upright, so a blade does not stand above the nacelle: the box's top stays the nacelle's.
const PROP_PARKED: float = deg_to_rad(65.0)
const PROP_TURNS: float = 38.0  # turns a second at full throttle, drawn
const DISC_FROM: Vector2 = Vector2(0.15, 0.55)
const DISC_ALPHA: float = 0.30

## THE FIN AND RUDDER [SIDE], outlines as (s, h): a broad fin with an upright, rounded leading edge -- 1.33 m of chord at
## half height, its top 2.75 m over the keel -- painted in three upright bands of the tricolour, each about 0.45 m wide,
## green at the front. The rudder is the red band aft of the hinge at 8.18 m, and only ABOVE the tailplane, so the
## elevators have room to move under it; the red below the tailplane is fixed fin. The first build swept the leading
## edge back from 7.0 m and drew the green as a sliver, and it read as a light aeroplane's fin beside the photograph.
const FIN_GREEN: Array = [[7.08, 1.04], [7.30, 1.40], [7.38, 1.90], [7.45, 2.25], [7.58, 2.50], [7.73, 2.64], [7.73, 1.02]]
const FIN_WHITE: Array = [[7.73, 1.02], [7.73, 2.64], [7.95, 2.73], [8.18, 2.75], [8.18, 1.02]]
const FIN_RED: Array = [[8.18, 1.02], [8.18, 1.56], [8.60, 1.56], [8.60, 1.00]]
const RUDDER: Array = [[8.18, 1.56], [8.18, 2.75], [8.40, 2.70], [8.55, 2.52], [8.63, 2.20], [8.63, 1.56]]
const FIN_HALF: Vector2 = Vector2(0.07, 0.03)  # at root and top
const RUDDER_TRAVEL: float = deg_to_rad(28.0)

## THE TAILPLANE [PLAN, SIDE]: 3.5 m across at 1.51 m over the keel, the trailing edge straight at 8.54 m, the leading edge
## swept back to a rounded tip. Elevators aft of a hinge at 8.15 m, from 0.10 m out. 8 per cent thick, ESTIMATE.
const TAIL_H: float = 1.51
const TAIL_LE: Array = [[0.0, 7.32], [1.10, 7.45], [1.60, 7.62], [1.75, 7.85]]
const TAIL_TE: float = 8.54
const TAIL_HINGE: float = 8.15
const ELEVATOR: Vector2 = Vector2(0.10, 1.60)
const TAIL_THICK: float = 0.08
const ELEVATOR_TRAVEL: float = deg_to_rad(25.0)
## The V struts under the tailplane, from the hull to 0.8 m out.
const TAIL_STRUTS: Array = [[7.50, 7.70], [8.10, 8.05]]  # [s at the hull, s at the tailplane]

## THE GUNS: two machine guns in the nose, as the film has them (it calls them 7.7 mm): the barrels leave the nose's top
## either side of the stem and stand 0.12 m proud of it. ESTIMATE.
const GUNS: Array = [0.12, 0.88, 0.60, -0.12]  # out, h, breech s, muzzle s
const GUN_SIDES: int = 6

## Small fittings stop drawing once the aeroplane is a few pixels high.
const DETAIL_RANGE: float = 600.0
const DETAIL_HYSTERESIS: float = 60.0

var _half: Vector3 = Vector3(0.63, 1.63, 4.315)
var _span: float = 5.16
var _pivots: Dictionary = {}
var _stick: Vector3 = Vector3.ZERO
var _prop_handed: Dictionary = {"turning": false, "throttle": 0.0, "seconds": 0.0}


## BUILT IN PLACE, after `new()`, from the simulation's geometry -- asked of the simulation itself when nothing is handed.
func dress(geometry: Dictionary = {}) -> void:
	name = "Savoia"
	var native: Dictionary = geometry if not geometry.is_empty() else Sim.geometry_of(Sim.Kind.SAVOIA)
	_half = native.get("extents", _half) as Vector3
	_span = float(native.get("span", _span))
	var paint: StandardMaterial3D = ShipHull.painted()
	paint.roughness = 0.42
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.vertex_color_is_srgb = true
	glass.albedo_color = Color(1, 1, 1, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	glass.metallic = 0.3

	var hull := _tool()
	_hull(hull)
	_add(self, "Hull", hull, paint)
	var pit := _tool()
	_cockpit(pit)
	_add(self, "Cockpit", pit, paint)
	var seat := _tool()
	_seat(seat)
	_add(self, "Seat", seat, paint)
	var screen := _tool()
	_windscreen(screen)
	_add(self, "Windscreen", screen, glass)

	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var wing := _tool()
		_wing(wing, side)
		_cabane(wing, side)
		_add(self, "Wing" + named, wing, paint)
		_aileron(side, named, paint)
		var float_tool := _tool()
		_float(float_tool, side)
		_add(self, "Float" + named, float_tool, paint)

	var nacelle := _tool()
	_nacelle(nacelle)
	_add(self, "Nacelle", nacelle, paint)
	_propeller(paint)

	var fin := _tool()
	_fin(fin)
	_add(self, "Fin", fin, paint)
	_rudder(paint)
	var tail := _tool()
	_tailplane(tail)
	_add(self, "Tailplane", tail, paint)
	_elevator(paint)

	var guns := _tool()
	_guns(guns)
	var fittings := _add(self, "Guns", guns, paint)
	fittings.visibility_range_end = DETAIL_RANGE
	fittings.visibility_range_end_margin = DETAIL_HYSTERESIS
	fittings.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	fittings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_propeller(false, 0.0, 0.0)


## A STATION (metres aft of the hull's nose) as a z: the nose is the box's front face.
func station(s: float) -> float:
	return -_half.z + s


## A HEIGHT (metres over the keel at the step) as a y: the keel is the box's bottom face.
func height(h: float) -> float:
	return -_half.y + h


func at(out: float, s: float, h: float) -> Vector3:
	return Vector3(out, height(h), station(s))


func wing_le(out: float) -> float:
	return WING_LE_ROOT + tan(WING_SWEEP) * absf(out)


## THE ROOM THE PILOT SITS IN, in the shape `VehicleView.cabin_room()` asks for. An OPEN cockpit: the room is the tub, and
## over it is sky. `tests/savoia.gd` holds the box to the drawn tub's walls and floor.
func cabin_room() -> Dictionary:
	var fore: float = station(float(ROOM[0]))
	var low: float = height(COCKPIT_FLOOR)
	var half: float = float(ROOM[2])
	return {
		"drawn": true,
		"floor": height(COCKPIT_FLOOR),
		"room": AABB(Vector3(-half, low, fore), Vector3(half * 2.0, float(ROOM[3]) - COCKPIT_FLOOR,
			float(ROOM[1]) - float(ROOM[0]))),
		"because": &"",
		"why_not": "",
		"source": "an open cockpit: the tub ESTIMATE from the eye and the side photo's opening; over the room is sky",
	}


## THE PILOT'S EYE, craft-local.
func eye() -> Vector3:
	return at(0.0, EYE.x, EYE.y)


## WHERE THE LIGHTS GO, on the parts that carry them: the nav lights on the wing tips, the white tail light on the
## rudder's trailing edge, a beacon on the nacelle's top and one under the hull. ESTIMATE, placed on the drawn skin.
func lights() -> Dictionary:
	var tip_s: float = wing_le(WING_TIP) + 0.55
	return {"port": at(-WING_TIP - 0.02, tip_s, WING_H), "starboard": at(WING_TIP + 0.02, tip_s, WING_H),
		"tail": at(0.0, 8.65, 1.80), "top": at(0.0, 3.20, 3.30), "bottom": at(0.0, 3.00, -0.04)}


## THE NAMED SOCKETS: the two gun muzzles (where rounds leave), the propeller's hub, and the floats' keels.
func sockets() -> Dictionary:
	var muzzle: float = float(GUNS[3])
	return {
		"gun_port": at(-float(GUNS[0]), muzzle, float(GUNS[1])),
		"gun_starboard": at(float(GUNS[0]), muzzle, float(GUNS[1])),
		"propeller": at(0.0, HUB.x, HUB.y),
		"float_port": at(-FLOAT_OUT, 3.30, 0.28),
		"float_starboard": at(FLOAT_OUT, 3.30, 0.28),
	}


## THE AILERONS: -1 left wing down to +1 right wing down. The down-going wing's aileron rises.
func set_ailerons(roll: float) -> void:
	_stick.x = clampf(roll, -1.0, 1.0)
	# Trailing edge DOWN is a positive turn about the hinge running outboard, for a surface aft of it.
	_swing("AileronStarboard", -_stick.x * AILERON_TRAVEL)
	_swing("AileronPort", _stick.x * AILERON_TRAVEL)


## THE ELEVATORS: -1 nose down to +1 nose up (trailing edges up).
func set_elevator(pitch: float) -> void:
	_stick.y = clampf(pitch, -1.0, 1.0)
	_swing("Elevator", -_stick.y * ELEVATOR_TRAVEL)


## THE RUDDER: -1 nose left to +1 nose right; its trailing edge goes to starboard for right rudder.
func set_rudder(yaw: float) -> void:
	_stick.z = clampf(yaw, -1.0, 1.0)
	_swing("Rudder", _stick.z * RUDDER_TRAVEL)


## What the ailerons, elevators and rudder were handed: (roll, pitch, yaw).
func stick_amounts() -> Vector3:
	return _stick


## THE PROPELLER: parked across, or turning on `seconds` of the physics clock, its disc as solid as the throttle is open.
func set_propeller(turning: bool, throttle: float, seconds: float) -> void:
	var open: float = clampf(throttle, 0.0, 1.0)
	_prop_handed = {"turning": turning, "throttle": open, "seconds": seconds}
	var blades := find_child("Propeller", false, false) as MeshInstance3D
	var disc := find_child("PropellerDisc", false, false) as MeshInstance3D
	if blades == null or disc == null:
		return
	var solid: float = smoothstep(DISC_FROM.x, DISC_FROM.y, open) if turning else 0.0
	var angle: float = -fposmod(seconds * PROP_TURNS * maxf(open, 0.2), 1.0) * TAU if turning else PROP_PARKED
	blades.basis = Basis(Vector3.BACK, angle)
	blades.visible = solid < 1.0
	disc.visible = solid > 0.0
	(disc.material_override as StandardMaterial3D).albedo_color.a = DISC_ALPHA * solid


func propeller_state() -> Dictionary:
	return _prop_handed.duplicate()


func _swing(named: String, angle: float) -> void:
	var pivot: Node3D = _pivots.get(named) as Node3D
	if pivot == null:
		return
	pivot.basis = Basis(pivot.get_meta("axis") as Vector3, angle)


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


static func _middle(loop: Array) -> Vector3:
	var c := Vector3.ZERO
	for p in loop:
		c += p
	return c / float(loop.size())


## A LOFT through matching convex loops. Each quad faces away from the loft's axis AND along it by how much the loops
## shrink: so a quad between two loops of different size -- the hull's step, where two rings a centimetre apart differ
## by 0.12 m at the keel -- faces aft or forward as it should, where a purely radial test is edge-on and a coin toss.
## Both ends are closed by fans facing out along the loft. `tints` colours facets by index round the loop.
static func _loft(tool: SurfaceTool, loops: Array, tints: Array, close: bool = true) -> void:
	var n: int = (loops[0] as Array).size()
	var centres: Array = []
	for loop in loops:
		centres.append(_middle(loop))
	for i in range(loops.size() - 1):
		var a: Array = loops[i]
		var b: Array = loops[i + 1]
		var ca: Vector3 = centres[i]
		var cb: Vector3 = centres[i + 1]
		var along: Vector3 = (cb - ca).normalized()
		for k in range(n):
			var k2: int = (k + 1) % n
			var quad: Array = [a[k], a[k2], b[k2], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			var radial: Vector3 = mid - (ca + cb) * 0.5
			radial -= along * radial.dot(along)
			var shrink: float = (((a[k] as Vector3) - ca).length() + ((a[k2] as Vector3) - ca).length()
				- ((b[k] as Vector3) - cb).length() - ((b[k2] as Vector3) - cb).length()) * 0.5
			Plating.facing(tool, quad, radial.normalized() + along * shrink * 4.0, tints[k % tints.size()])
	if not close:
		return
	for end in [0, loops.size() - 1]:
		var outward: Vector3 = (centres[end] as Vector3) - centres[1 if end == 0 else loops.size() - 2]
		var loop: Array = loops[end]
		for k in range(n):
			_fan(tool, centres[end], loop[k], loop[(k + 1) % n], outward, tints[k % tints.size()])


## A FLAT SLAB from an outline in the (s, h) plane, at `out`, `half` thick either side as a function of the point.
func _slab(tool: SurfaceTool, outline: Array, half: Callable, tint: Color, origin: Vector3 = Vector3.ZERO) -> void:
	var flat := PackedVector2Array()
	for p in outline:
		flat.append(Vector2(float(p[0]), float(p[1])))
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(flat)
	var starboard: Array = []
	var port: Array = []
	for p in flat:
		var h: float = float(half.call(p))
		starboard.append(at(h, p.x, p.y) - origin)
		port.append(at(-h, p.x, p.y) - origin)
	for t in range(0, tris.size(), 3):
		_fan(tool, starboard[tris[t]], starboard[tris[t + 1]], starboard[tris[t + 2]], Vector3.RIGHT, tint)
		_fan(tool, port[tris[t]], port[tris[t + 1]], port[tris[t + 2]], Vector3.LEFT, tint)
	var n: int = flat.size()
	var area: float = 0.0
	for i in range(n):
		area += flat[i].x * flat[(i + 1) % n].y - flat[(i + 1) % n].x * flat[i].y
	for i in range(n):
		var i2: int = (i + 1) % n
		# Outward in the slab's plane from the outline's own winding, so a CONCAVE corner -- the white fin's step under
		# the rudder -- faces the right way, where "away from the middle" turned the step's top face down.
		var edge: Vector2 = flat[i2] - flat[i]
		var normal2 := Vector2(edge.y, -edge.x) if area < 0.0 else Vector2(-edge.y, edge.x)
		Plating.facing(tool, [starboard[i], starboard[i2], port[i2], port[i]], Vector3(0.0, normal2.y, normal2.x), tint)


## ONE HULL RING from a SECTIONS row: twelve points from the crown round the starboard side to the keel and back up the
## port side. Points 0 and 6 are the top and the keel on the centreline.
func _ring(row: Array) -> Array:
	var s: float = row[0]
	var top: float = row[1]
	var bw: float = row[2]
	var bh: float = row[3]
	var cw: float = row[4]
	var ch: float = row[5]
	var keel: float = row[6]
	var d: float = top - bh
	var half: Array = [Vector2(0.0, top), Vector2(bw * CROWN_OUT, top - 0.12 * d), Vector2(bw * 0.88, top - 0.45 * d),
		Vector2(bw, bh), Vector2((bw + cw) * 0.5 + 0.02, (bh + ch) * 0.5), Vector2(cw, ch), Vector2(0.0, keel)]
	var points: Array = []
	for i in range(half.size() - 1):
		points.append(at((half[i] as Vector2).x, s, (half[i] as Vector2).y))
	for i in range(half.size() - 1, 0, -1):
		points.append(at(-(half[i] as Vector2).x, s, (half[i] as Vector2).y))
	return points


## THE HULL: 12 flat facets a ring, red above the bilge and tan below it, the crown left open over the cockpit, and the
## nose and tail post closed by fans.
func _hull(tool: SurfaceTool) -> void:
	var rings: Array = []
	for row in SECTIONS:
		rings.append(_ring(row))
	var n: int = HULL_SIDES
	# Facet k runs from point k to k+1: 0 and 11 are the crown, 3,4 and 7,8 below the bilge.
	var tints: Array = [RED, RED, RED, RED, TAN, TAN, TAN, TAN, RED, RED, RED, RED]
	for r in range(rings.size() - 1):
		var here: float = (float(SECTIONS[r][0]) + float(SECTIONS[r + 1][0])) * 0.5
		var open: bool = here > COCKPIT.x and here < COCKPIT.y
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var ca: Vector3 = _middle(a)
		var cb: Vector3 = _middle(b)
		for k in range(n):
			if open and (k == 0 or k == n - 1):
				continue
			var k2: int = (k + 1) % n
			var quad: Array = [a[k], a[k2], b[k2], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			var radial: Vector3 = mid - (ca + cb) * 0.5
			radial.z = 0.0
			var shrink: float = (((a[k] as Vector3) - ca).length() + ((a[k2] as Vector3) - ca).length()
				- ((b[k] as Vector3) - cb).length() - ((b[k2] as Vector3) - cb).length()) * 0.5
			Plating.facing(tool, quad, radial.normalized() + Vector3.BACK * shrink * 4.0, tints[k])
	var nose: Vector3 = at(0.0, NOSE.x, NOSE.y)
	var first: Array = rings[0]
	var post: Vector3 = at(0.0, TAIL_POST.x, TAIL_POST.y)
	var last: Array = rings[rings.size() - 1]
	for k in range(n):
		_fan(tool, nose, first[k], first[(k + 1) % n], Vector3.FORWARD, tints[k])
		_fan(tool, post, last[k], last[(k + 1) % n], Vector3.BACK, tints[k])


## THE COCKPIT TUB: walls from the crown's opening down to a floor, all facing INTO the tub, so the hull and the tub
## together stay one closed solid with a pocket in it.
func _cockpit(tool: SurfaceTool) -> void:
	var fore: int = _row_of(COCKPIT.x)
	var aft: int = _row_of(COCKPIT.y)
	var floor_at := func(p: Vector3) -> Vector3:
		return Vector3(clampf(p.x, -COCKPIT_FLOOR_HALF, COCKPIT_FLOOR_HALF), height(COCKPIT_FLOOR), p.z)
	# The opening's edge each side is the crown point (1 starboard, 11 port) of every ring from fore to aft.
	for side_index in [1, HULL_SIDES - 1]:
		for r in range(fore, aft):
			var a: Vector3 = _ring(SECTIONS[r])[side_index]
			var b: Vector3 = _ring(SECTIONS[r + 1])[side_index]
			Plating.facing(tool, [a, b, floor_at.call(b), floor_at.call(a)], Vector3(-signf(a.x), 0.0, 0.0), PIT)
	# The front and back walls: the arc of the ring over the opening (crown, top, crown) down to the floor.
	for end in [[fore, Vector3.BACK], [aft, Vector3.FORWARD]]:
		var ring: Array = _ring(SECTIONS[int(end[0])])
		var arc: Array = [ring[1], ring[0], ring[HULL_SIDES - 1]]
		for i in range(arc.size() - 1):
			Plating.facing(tool, [arc[i], arc[i + 1], floor_at.call(arc[i + 1]), floor_at.call(arc[i])], end[1], PIT)
	# The floor.
	var front: Array = _ring(SECTIONS[fore])
	var back: Array = _ring(SECTIONS[aft])
	Plating.facing(tool, [floor_at.call(front[1]), floor_at.call(front[HULL_SIDES - 1]),
		floor_at.call(back[HULL_SIDES - 1]), floor_at.call(back[1])], Vector3.UP, PIT)


## THE SEAT, its own part so the room check can tell the tub from what stands in it: a pan 0.80 m under the eye (a seated
## eye's height over the cushion) and a back just behind the eye, on a pedestal from the floor. ESTIMATE.
func _seat(tool: SurfaceTool) -> void:
	var pan_h: float = EYE.y - 0.80
	Plating.box(tool, at(0.0, EYE.x + 0.02, pan_h - 0.03), Vector3(0.42, 0.06, 0.42), BLACK)
	Plating.box(tool, at(0.0, EYE.x + 0.20, pan_h + 0.22), Vector3(0.40, 0.44, 0.05), PIT,
		Basis(Vector3.RIGHT, deg_to_rad(-12.0)))
	var leg_h: float = pan_h - 0.06 - COCKPIT_FLOOR
	Plating.box(tool, at(0.0, EYE.x + 0.02, COCKPIT_FLOOR + leg_h * 0.5), Vector3(0.30, leg_h, 0.30), BLACK)


func _row_of(s: float) -> int:
	for r in range(SECTIONS.size()):
		if is_equal_approx(float(SECTIONS[r][0]), s):
			return r
	push_error("SavoiaAirframe: no hull ring at %.2f" % s)
	return 0


## THE WINDSCREEN: three panes, a front one square to the pilot and two turned back at the sides, each a thin slab.
func _windscreen(tool: SurfaceTool) -> void:
	var foot_s: float = SCREEN[0]
	var top_s: float = SCREEN[1]
	var w: float = SCREEN[2]
	var foot_h: float = SCREEN[3]
	var top_h: float = SCREEN[4]
	var corner := func(out: float, up: bool, back: float) -> Vector3:
		return at(out, (top_s if up else foot_s) + back, top_h if up else foot_h)
	var panes: Array = [
		[corner.call(-w * 0.6, false, 0.0), corner.call(w * 0.6, false, 0.0), corner.call(w * 0.5, true, 0.0),
			corner.call(-w * 0.5, true, 0.0)],
		[corner.call(w * 0.6, false, 0.0), corner.call(w, false, 0.10), corner.call(w * 0.9, true, 0.10),
			corner.call(w * 0.5, true, 0.0)],
		[corner.call(-w * 0.6, false, 0.0), corner.call(-w, false, 0.10), corner.call(-w * 0.9, true, 0.10),
			corner.call(-w * 0.5, true, 0.0)],
	]
	for pane in panes:
		var normal: Vector3 = ((pane[2] as Vector3) - (pane[0] as Vector3)).cross((pane[1] as Vector3) - (pane[0] as Vector3))
		var thick: Vector3 = normal.normalized() * 0.006
		var outer: Array = []
		var inner: Array = []
		for p in pane:
			outer.append((p as Vector3) + thick)
			inner.append((p as Vector3) - thick)
		Plating.facing(tool, outer, thick, GLASS)
		Plating.facing(tool, inner, -thick, GLASS)


## AN AEROFOIL SECTION at `out`, over the chord from `le` to `te`, cut at `from`..`to` as shares of that chord: points on
## the top face from front to back, then the bottom face back to front. `thick` is the whole thickness over the chord.
func _foil(out: float, le: float, te: float, h: float, thick: float, from: float, to: float) -> Array:
	var chord: float = te - le
	# ALWAYS FOUR POINTS a face, spread over the cut, so any two sections of one surface loft point to point.
	var shares: Array = []
	for x in [0.0, 0.2, 0.55, 1.0]:
		shares.append(lerpf(from, to, x))
	var half := func(f: float) -> float:
		# A plain thick section: 0 at the nose, full at 30 per cent, a sharp-ish trailing edge.
		var shape: float = sqrt(f / 0.3) if f < 0.3 else lerpf(1.0, 0.12, (f - 0.3) / 0.7)
		return 0.5 * thick * chord * shape
	var top: Array = []
	var under: Array = []
	for f in shares:
		var hh: float = float(half.call(float(f)))
		var s: float = le + chord * float(f)
		top.append(at(out, s, h + hh))
		if hh > 1e-5:
			under.push_front(at(out, s, h - hh))
	return top + under


## A WING SECTION at `out` (signed), over its full chord, the tip rounded, cut at shares of the chord.
func _wing_foil(out: float, from: float, to: float) -> Array:
	var le: float = wing_le(out)
	var te: float = le + WING_CHORD
	for row in WING_TIP_ROUND:
		if absf(absf(out) - float(row[0])) < 1e-4:
			le += float(row[1])
			te -= float(row[2])
	return _foil(out, le, te, WING_H, WING_THICK * WING_CHORD / (te - le), from, to)


func _band(out: float) -> Color:
	var o: float = absf(out)
	if o > BAND_GREEN.x - 1e-4 and o < BAND_GREEN.y - 1e-4:
		return GREEN
	if o > BAND_WHITE.x - 1e-4 and o < BAND_WHITE.y - 1e-4:
		return WHITE
	return RED


## THE WING, one side: from the centreline to the tip in the tricolour's bands, full chord except across the aileron,
## where it stops at the hinge.
func _wing(tool: SurfaceTool, side: float) -> void:
	var stations: Array = [0.0, BAND_GREEN.x, BAND_GREEN.y, BAND_WHITE.y, AILERON.y]
	for row in WING_TIP_ROUND:
		if float(row[0]) > AILERON.y + 1e-4:
			stations.append(float(row[0]))
	for i in range(stations.size() - 1):
		var a: float = float(stations[i])
		var b: float = float(stations[i + 1])
		var cut: float = HINGE_CHORD if (a >= AILERON.x - 1e-4 and b <= AILERON.y + 1e-4) else 1.0
		var tint: Color = _band((a + b) * 0.5)
		# Facets 0-2 are the top face, then the trailing face and the underside: RED over, the band under.
		_loft(tool, [_wing_foil(side * a, 0.0, cut), _wing_foil(side * b, 0.0, cut)], [RED, RED, RED, tint, tint, tint, tint])


## THE AILERON, one side, in its own pivot on the hinge line, which runs out along the swept wing.
func _aileron(side: float, named: String, paint: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = "Aileron" + named + "Hinge"
	var inner: Vector3 = at(side * AILERON.x, wing_le(AILERON.x) + WING_CHORD * HINGE_CHORD, WING_H)
	var outer: Vector3 = at(side * AILERON.y, wing_le(AILERON.y) + WING_CHORD * HINGE_CHORD, WING_H)
	pivot.position = (inner + outer) * 0.5
	# Along the hinge, pointing OUTBOARD: a positive turn about it lowers a trailing edge aft of it on the starboard
	# wing, so the port wing's axis is the mirror, pointing outboard to port.
	var axis: Vector3 = (outer - inner).normalized()
	pivot.set_meta("axis", axis if side > 0.0 else -axis)
	add_child(pivot)
	var tool := _tool()
	var bands: Array = [[AILERON.x + 0.01, BAND_WHITE.y], [BAND_WHITE.y, AILERON.y - 0.01]]
	for band in bands:
		var sub: Array = []
		for out in band:
			var local: Array = []
			for p in _wing_foil(side * float(out), HINGE_CHORD, 1.0):
				local.append((p as Vector3) - pivot.position)
			sub.append(local)
		var under: Color = _band((float(band[0]) + float(band[1])) * 0.5)
		_loft(tool, sub, [RED, RED, RED, under, under, under, under, under])
	_add(pivot, "Aileron" + named, tool, paint)
	_pivots["Aileron" + named] = pivot


## THE WING'S UNDERSIDE at a point, for a strut to meet: the chord line less the section's half thickness there.
func _wing_under(out: float, s: float) -> float:
	var le: float = wing_le(out)
	var f: float = clampf((s - le) / WING_CHORD, 0.0, 1.0)
	var shape: float = sqrt(f / 0.3) if f < 0.3 else lerpf(1.0, 0.12, (f - 0.3) / 0.7)
	return WING_H - 0.5 * WING_THICK * WING_CHORD * shape


func _wing_over(out: float, s: float) -> float:
	return 2.0 * WING_H - _wing_under(out, s)


## A STRUT from `a` to `b`: a streamlined bar, four-sided, `wide` across its chord and a third of that thick, bedded 3 cm
## into whatever it meets at each end.
static func _strut(tool: SurfaceTool, a: Vector3, b: Vector3, wide: float, tint: Color) -> void:
	var along: Vector3 = (b - a).normalized()
	a -= along * 0.03
	b += along * 0.03
	var chord: Vector3 = (Vector3.BACK - along * along.dot(Vector3.BACK))
	if chord.length_squared() < 1e-6:
		chord = Vector3.RIGHT
	chord = chord.normalized() * wide * 0.5
	var thick: Vector3 = along.cross(chord).normalized() * wide * 0.18
	var loops: Array = []
	for p in [a, b]:
		loops.append([p - chord, p + thick, p + chord, p - thick])
	_loft(tool, loops, [tint])


## THE CABANE, one side: the two struts from the hull's shoulder to the wing's underside at each spar, and the V brace
## from the hull's flank out to the wing.
func _cabane(tool: SurfaceTool, side: float) -> void:
	for s in SPARS:
		var shoulder: float = _hull_top(float(s)) - 0.10
		_strut(tool, at(side * 0.30, float(s), shoulder), at(side * 0.50, float(s), _wing_under(0.50, float(s))), STRUT, RED)
	var foot: Vector3 = at(side * 0.52, 3.25, 0.80)
	for s in SPARS:
		_strut(tool, foot, at(side * 1.70, float(s), _wing_under(1.70, float(s))), STRUT, RED)


## The hull's top at a station, off the table.
func _hull_top(s: float) -> float:
	for r in range(SECTIONS.size() - 1):
		var a: float = SECTIONS[r][0]
		var b: float = SECTIONS[r + 1][0]
		if s >= a and s <= b:
			return lerpf(float(SECTIONS[r][1]), float(SECTIONS[r + 1][1]), (s - a) / (b - a))
	return float(SECTIONS[-1][1])


## A FLOAT, one side: an eight-sided teardrop, red over a tan bottom, on two struts up to the wing's underside.
func _float(tool: SurfaceTool, side: float) -> void:
	var loops: Array = []
	for row in FLOAT_ROWS:
		var s: float = row[0]
		var w: float = row[1]
		var bottom: float = row[2]
		var top: float = row[3]
		var mid: float = (bottom + top) * 0.5
		var r: float = (top - bottom) * 0.5
		var loop: Array = []
		for k in range(FLOAT_SIDES):
			var t: float = TAU * (float(k) + 0.5) / FLOAT_SIDES
			loop.append(at(side * FLOAT_OUT + w * cos(t), s, mid + r * sin(t)))
		loops.append(loop)
	# Facets 4..7 are the lower half (sin < 0): tan.
	_loft(tool, loops, [RED, RED, RED, RED, TAN, TAN, TAN, TAN])
	for s in FLOAT_STRUTS:
		_strut(tool, at(side * FLOAT_OUT, float(s), 0.78), at(side * (FLOAT_OUT - 0.05), float(s),
			_wing_under(FLOAT_OUT, float(s))), STRUT, RED)


## THE NACELLE: twelve flat panels a ring, rounded-oblong in section, closed at the cowl's face and the tail; the struts it
## stands on; the two copper radiator drums; an exhaust pipe along each side; and three dark ports low on each flank.
func _nacelle(tool: SurfaceTool) -> void:
	var loops: Array = []
	for row in NACELLE_ROWS:
		loops.append(_nacelle_ring(row))
	_loft(tool, loops, [RED])
	for strut in NACELLE_STRUTS:
		for side in [1.0, -1.0]:
			var out: float = side * float(strut[0])
			var low: Vector3 = at(out, float(strut[1]), _wing_over(float(strut[0]), float(strut[1])))
			var high: Vector3 = at(out, float(strut[2]), _nacelle_belly(float(strut[2])))
			_strut(tool, low, high, STRUT, RED)
	for side in [1.0, -1.0]:
		var rad_loops: Array = []
		for s in [RADIATOR[3], RADIATOR[4]]:
			var loop: Array = []
			for k in range(RADIATOR_SIDES):
				var t: float = TAU * float(k) / RADIATOR_SIDES
				loop.append(at(side * float(RADIATOR[0]) + float(RADIATOR[2]) * cos(t), float(s),
					float(RADIATOR[1]) + float(RADIATOR[2]) * sin(t)))
			rad_loops.append(loop)
		_loft(tool, rad_loops, [COPPER])
		# Its face: a dark core inside a copper rim, just proud of the drum's front.
		var face_s: float = float(RADIATOR[3]) - 0.005
		var core: Array = []
		for k in range(RADIATOR_SIDES):
			var t: float = TAU * float(k) / RADIATOR_SIDES
			core.append(at(side * float(RADIATOR[0]) + float(RADIATOR[2]) * 0.8 * cos(t), face_s,
				float(RADIATOR[1]) + float(RADIATOR[2]) * 0.8 * sin(t)))
		var core_mid: Vector3 = at(side * float(RADIATOR[0]), face_s, float(RADIATOR[1]))
		for k in range(RADIATOR_SIDES):
			_fan(tool, core_mid, core[k], core[(k + 1) % RADIATOR_SIDES], Vector3.FORWARD, BLACK)
		# The exhaust pipe.
		Plating.box(tool, at(side * float(EXHAUST[0]), (float(EXHAUST[2]) + float(EXHAUST[3])) * 0.5, float(EXHAUST[1])),
			Vector3(0.08, 0.08, float(EXHAUST[3]) - float(EXHAUST[2])), BLACK)
		# The ports.
		for s in PORTS:
			var out: float = side * (_nacelle_half(float(s)) + 0.004)
			var c: Vector3 = at(out, float(s), PORT_H)
			Plating.facing(tool, [c + Vector3(0, 0.05, -0.05), c + Vector3(0, 0.05, 0.05), c + Vector3(0, -0.05, 0.05),
				c + Vector3(0, -0.05, -0.05)], Vector3(side, 0, 0), BLACK)


## A NACELLE RING: a rounded oblong, the sides flat and the top and belly rounded, from a row [s, half width, bottom, top].
func _nacelle_ring(row: Array) -> Array:
	var s: float = row[0]
	var w: float = row[1]
	var bottom: float = row[2]
	var top: float = row[3]
	var d: float = top - bottom
	# Starboard from the valley between the banks, over the bank, down the upright flank and under the crankcase.
	var half: Array = [Vector2(0.0, top - minf(0.07, 0.1 * d)), Vector2(w * 0.5, top), Vector2(w, top - 0.30 * d),
		Vector2(w, bottom + 0.28 * d), Vector2(w * 0.7, bottom + 0.08 * d), Vector2(w * 0.35, bottom), Vector2(0.0, bottom)]
	var loop: Array = []
	for i in range(half.size() - 1):
		loop.append(at((half[i] as Vector2).x, s, (half[i] as Vector2).y))
	for i in range(half.size() - 1, 0, -1):
		loop.append(at(-(half[i] as Vector2).x, s, (half[i] as Vector2).y))
	return loop


func _nacelle_row_at(s: float) -> Array:
	for r in range(NACELLE_ROWS.size() - 1):
		var a: Array = NACELLE_ROWS[r]
		var b: Array = NACELLE_ROWS[r + 1]
		if s >= float(a[0]) and s <= float(b[0]):
			var t: float = (s - float(a[0])) / (float(b[0]) - float(a[0]))
			return [s, lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t)]
	return NACELLE_ROWS[-1]


## The nacelle's belly and flank at a station, interpolated off the table: where a strut or a port meets it.
func _nacelle_belly(s: float) -> float:
	var row: Array = _nacelle_row_at(s)
	# The crankcase's corner is 0.08 of the depth up at the strut's 0.26 m out: bed the strut 0.10 m into the belly.
	return float(row[2]) + 0.10


func _nacelle_half(s: float) -> float:
	var row: Array = _nacelle_row_at(s)
	# The flank is upright at the full half width between 0.28 and 0.70 of the depth.
	return float(row[1])


## THE PROPELLER: the spinner, the two blades and the disc they sweep, each its own node on the hub.
func _propeller(paint: Material) -> void:
	var hub: Vector3 = at(0.0, HUB.x, HUB.y)
	var tool := _tool()
	var rows: Array = [[-SPINNER.x, 0.0], [-SPINNER.x * 0.6, SPINNER.y * 0.7], [0.0, SPINNER.y], [0.06, SPINNER.y]]
	var loops: Array = []
	for row in rows:
		var loop: Array = []
		for k in range(SPINNER_SIDES):
			var t: float = TAU * float(k) / SPINNER_SIDES
			var r: float = maxf(float(row[1]), 0.001)
			loop.append(Vector3(r * cos(t), r * sin(t), float(row[0])))
		loops.append(loop)
	_loft(tool, loops, [RED])
	_add(self, "Spinner", tool, paint, hub)
	# TWO BLADES: chord and twist along the radius, ESTIMATE; silver as the kits paint them.
	var blades := _tool()
	var stations: Array = [Vector3(0.12, 0.16, 0.70), Vector3(0.35, 0.20, 0.50), Vector3(0.75, 0.16, 0.30),
		Vector3(PROP_RADIUS, 0.09, 0.22)]  # (radius, chord, pitch)
	for blade in [1.0, -1.0]:
		var blade_loops: Array = []
		for row in stations:
			blade_loops.append(_blade_section(blade, row))
		_loft(blades, blade_loops, [BLADE])
	_add(self, "Propeller", blades, paint, hub)
	var disc := _tool()
	const DISC_SIDES := 20
	for k in range(DISC_SIDES):
		var t0: float = TAU * float(k) / DISC_SIDES
		var t1: float = TAU * float(k + 1) / DISC_SIDES
		var o0 := Vector3(cos(t0), sin(t0), 0.0) * PROP_RADIUS
		var o1 := Vector3(cos(t1), sin(t1), 0.0) * PROP_RADIUS
		Plating.facing(disc, [o0 * 0.17, o1 * 0.17, o1, o0], Vector3.FORWARD, Color(0.15, 0.15, 0.16))
	var blur := StandardMaterial3D.new()
	blur.vertex_color_use_as_albedo = true
	blur.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur.cull_mode = BaseMaterial3D.CULL_DISABLED
	var disc_node := _add(self, "PropellerDisc", disc, blur, hub)
	disc_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc_node.visible = false


## A blade's section at `row` (radius, chord, pitch in radians), in the hub's frame, blade along +y (or -y).
static func _blade_section(blade: float, row: Vector3) -> Array:
	var r: float = row.x * blade
	var half_chord: float = row.y * 0.5
	var thick: float = row.y * 0.06
	var turn := Basis(Vector3.UP, row.z * blade)
	var across: Vector3 = turn * Vector3.RIGHT
	var fore: Vector3 = turn * Vector3.FORWARD
	var centre := Vector3(0.0, r, 0.0)
	return [centre - across * half_chord, centre + fore * thick, centre + across * half_chord, centre - fore * thick]


## THE FIN: two slabs in the tricolour's green and white, thinning from root to top.
func _fin(tool: SurfaceTool) -> void:
	var half := func(p: Vector2) -> float:
		return lerpf(FIN_HALF.x, FIN_HALF.y, clampf((p.y - 1.05) / 1.70, 0.0, 1.0))
	_slab(tool, FIN_GREEN, half, GREEN)
	_slab(tool, FIN_WHITE, half, WHITE)
	_slab(tool, FIN_RED, half, RED)


## THE RUDDER in its pivot on the upright hinge at 8.18 m: the red third of the tricolour.
func _rudder(paint: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = "RudderHinge"
	var foot: Vector3 = at(0.0, float(RUDDER[0][0]), float(RUDDER[0][1]))
	var head: Vector3 = at(0.0, float(RUDDER[1][0]), float(RUDDER[1][1]))
	pivot.position = foot
	# Right rudder swings the trailing edge to starboard (+x): a positive turn about +y carries +z (aft) towards +x.
	pivot.set_meta("axis", (head - foot).normalized())
	add_child(pivot)
	var tool := _tool()
	var half := func(p: Vector2) -> float:
		return lerpf(FIN_HALF.x * 0.8, FIN_HALF.y * 0.8, clampf((p.y - 1.56) / 1.2, 0.0, 1.0))
	_slab(tool, RUDDER, half, RED, foot)
	_add(pivot, "Rudder", tool, paint)
	_pivots["Rudder"] = pivot


func _tail_le(out: float) -> float:
	var o: float = absf(out)
	for i in range(TAIL_LE.size() - 1):
		var a: Array = TAIL_LE[i]
		var b: Array = TAIL_LE[i + 1]
		if o >= float(a[0]) - 1e-6 and o <= float(b[0]) + 1e-6:
			return lerpf(float(a[1]), float(b[1]), (o - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(TAIL_LE[-1][1])


## THE TAILPLANE: both halves forward of the elevators' hinge through the fin, and the V struts under it to the hull.
func _tailplane(tool: SurfaceTool) -> void:
	var outs: Array = []
	for row in TAIL_LE:
		outs.append(float(row[0]))
	for side in [1.0, -1.0]:
		var loops: Array = []
		for o in outs:
			var le: float = _tail_le(float(o))
			var chord: float = TAIL_TE - le
			loops.append(_foil(side * float(o), le, TAIL_TE, TAIL_H, TAIL_THICK * (TAIL_TE - 7.32) / chord, 0.0,
				(TAIL_HINGE - le) / chord))
		_loft(tool, loops, [RED])
		for pair in TAIL_STRUTS:
			var hull_s: float = float(pair[0])
			var foot: Vector3 = at(side * 0.10, hull_s, _hull_keel_side(hull_s))
			var head: Vector3 = at(side * 0.80, float(pair[1]), TAIL_H - 0.03)
			_strut(tool, foot, head, STRUT * 0.8, RED)


## Somewhere low on the afterbody's flank at a station, for a strut's foot: halfway up from the chine to the beam.
func _hull_keel_side(s: float) -> float:
	for r in range(SECTIONS.size() - 1):
		var a: Array = SECTIONS[r]
		var b: Array = SECTIONS[r + 1]
		if s >= float(a[0]) and s <= float(b[0]):
			var t: float = (s - float(a[0])) / (float(b[0]) - float(a[0]))
			return lerpf((float(a[3]) + float(a[5])) * 0.5, (float(b[3]) + float(b[5])) * 0.5, t)
	return 1.0


## THE ELEVATORS, both halves on one pivot along the hinge at 8.15 m: they move together.
func _elevator(paint: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = "ElevatorHinge"
	pivot.position = at(0.0, TAIL_HINGE, TAIL_H)
	# Trailing edge DOWN is a positive turn about +x for a surface aft (+z) of its hinge.
	pivot.set_meta("axis", Vector3.RIGHT)
	add_child(pivot)
	var tool := _tool()
	for side in [1.0, -1.0]:
		var loops: Array = []
		for o in [ELEVATOR.x, ELEVATOR.y]:
			var le: float = _tail_le(float(o))
			var te: float = TAIL_TE - (0.08 if float(o) > 1.0 else 0.0)
			var chord: float = te - le
			var local: Array = []
			for p in _foil(side * float(o), le, te, TAIL_H, TAIL_THICK * (TAIL_TE - 7.32) / chord,
					(TAIL_HINGE + 0.005 - le) / chord, 1.0):
				local.append((p as Vector3) - pivot.position)
			loops.append(local)
		_loft(tool, loops, [RED])
	_add(pivot, "Elevator", tool, paint)
	_pivots["Elevator"] = pivot


## THE GUNS: two six-sided barrels leaving the nose's top, each with a flared muzzle.
func _guns(tool: SurfaceTool) -> void:
	for side in [1.0, -1.0]:
		var out: float = side * float(GUNS[0])
		var h: float = GUNS[1]
		var rows: Array = [[float(GUNS[2]), 0.035], [float(GUNS[3]) + 0.06, 0.035], [float(GUNS[3]) + 0.05, 0.045],
			[float(GUNS[3]), 0.045]]
		var loops: Array = []
		for row in rows:
			var loop: Array = []
			for k in range(GUN_SIDES):
				var t: float = TAU * float(k) / GUN_SIDES
				loop.append(at(out + float(row[1]) * cos(t), float(row[0]), h + float(row[1]) * sin(t)))
			loops.append(loop)
		_loft(tool, loops, [BLACK])
