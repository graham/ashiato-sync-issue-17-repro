@tool
extends RefCounted
class_name CarrierPlan
## THE FORD'S FLIGHT DECK AS A DRAWING: where the catapults run, where the wires cross, where the blast deflectors stand
## and where the landing area is painted.
##
## The ship's SHAPE is not here. Its hull, deck outline, elevators, island and bridge are parts in the simulation's
## shape table (`carrier_shape` in `cockpit_world.cpp`), because an aeroplane lands on that deck and a helm is placed in
## that bridge, and `Sim.geometry_of` hands them to everything else. What is here is what nothing collides with: paint,
## rails and hinged slabs, which the drawing and the marshalling deck both read and which the simulation has never heard
## of. The old deck typed its catapult beside the ship it sat on (`TRACK_X = -14`, `SHUTTLE_Z = -60`) and a different ship
## would have kept a catapult in the sea.
##
## FRAME: the ship's own, the same as the parts -- origin midships on the waterline, +X to starboard, -Z to the bow -- as
## (x, z) in plan. The fact sheet measures "x aft of the bow tip, z to starboard", so a sheet point (a, b) is
## (b, a - 168.5) here. Every row below is an ESTIMATE in the sheet, from the Nimitz layout the Ford's hull shares, good to
## five or ten metres; the counts and lengths are sourced (`agents.md`, "A FORD-CLASS CARRIER").

## Four EMALS catapults: two at the bow, two in the waist. `start` is the shuttle at station zero, where a nosewheel is
## hooked up; `end` is where the stroke finishes, 91.4 m on. The waist pair splay to port with the angled deck.
const CATAPULTS: Array[Dictionary] = [
	{"name": "1", "start": Vector2(9.0, -67.5), "end": Vector2(9.0, -158.9)},
	{"name": "2", "start": Vector2(-5.0, -67.5), "end": Vector2(-9.8, -158.8)},
	{"name": "3", "start": Vector2(-12.0, 41.5), "end": Vector2(-23.1, -49.2)},
	{"name": "4", "start": Vector2(-24.0, 31.5), "end": Vector2(-38.3, -58.8)},
]
## The stroke every catapult has, sourced: a 300 ft linear motor.
const STROKE: float = 91.4
## THE ONE A JET IS MARSHALLED ONTO. Bow catapult 1 runs straight up the deck, parallel to the centreline, which is what
## `DeckLaunch` squares an aeroplane against.
const LAUNCH: int = 0

## A jet blast deflector behind each catapult: a panel 11 m across that stands up 3.3 m at 50 degrees, hinged this far
## aft of the shuttle's station zero (the Navy's figure is 17.7 to 20.7 m by catapult and ship).
const DEFLECTOR_AFT: float = 20.0
const DEFLECTOR_WIDE: float = 11.0
const DEFLECTOR_TALL: float = 3.3
const DEFLECTOR_RAISED: float = deg_to_rad(50.0)

## THE LANDING AREA: a centreline 9 degrees to port of the ship's, from the ramp at the stern to where it leaves the deck
## over the port bow, and 12.2 m either side of it.
const RAMP := Vector2(3.0, 166.5)
const LANDING_OFF := Vector2(-36.0, -77.5)
const LANDING_HALF_WIDE: float = 12.2
## THREE ARRESTING WIRES (the Ford's AAG; a Nimitz has four), across the landing centreline this far up it from the ramp,
## each reaching 12 m either side.
const WIRES_FROM_RAMP: Array[float] = [51.8, 64.0, 76.3]
const WIRE_HALF: float = 12.0

## The landing signal officer's platform, on the port deck edge abeam the wires.
const LSO := Rect2(Vector2(-27.0, 111.5), Vector2(5.0, 15.0))
## AIRCRAFT PARKED ON THE DECK, by kind name: where each stands in the ship's frame, and which way its nose points (0 is to
## the bow). A spawn stands the craft over `at` at `deck_height()`, carried by the ship, never at a typed height.
##
## The E-2D stands abaft the island with its wings folded: 10.4 m aft of the island's after face, 5.5 m from the starboard
## deck edge, and 8.9 m or more from the landing area's starboard edge, clear of the wires, the LSO and the port elevator.
## ESTIMATE, like every row here (cockpit-carrier, 2026-09-15). Its footprint is not typed here: its length is the
## simulation's hull, and its folded width the airframe's sourced 8.94 m.
const PARKED: Array[Dictionary] = [
	{"name": "hawkeye", "at": Vector2(18.0, 90.0), "yaw": 0.0},
]
## The hull number, painted on the forward flight deck, read from aft.
const NUMBER: String = "78"
const NUMBER_AT := Vector2(0.0, -136.0)
const NUMBER_TALL: float = 22.0


## A CATAPULT'S TRACK as a unit vector from the shuttle toward the bow.
static func track_direction(catapult: int) -> Vector2:
	var cat: Dictionary = CATAPULTS[catapult]
	return ((cat["end"] as Vector2) - (cat["start"] as Vector2)).normalized()


## The hinge of a catapult's blast deflector, aft of the shuttle along its own track.
static func deflector_at(catapult: int) -> Vector2:
	return (CATAPULTS[catapult]["start"] as Vector2) - track_direction(catapult) * DEFLECTOR_AFT


## The landing centreline, as a unit vector from the ramp toward the bow.
static func landing_direction() -> Vector2:
	return (LANDING_OFF - RAMP).normalized()


## WHERE A WIRE CROSSES THE DECK: its two ends, port first.
static func wire_ends(wire: int) -> Array[Vector2]:
	var along: Vector2 = landing_direction()
	var middle: Vector2 = RAMP + along * WIRES_FROM_RAMP[wire]
	var across := Vector2(-along.y, along.x)
	if across.x > 0.0:
		across = -across
	return [middle + across * WIRE_HALF, middle - across * WIRE_HALF]


## THE DECK AN AEROPLANE CAN STAND ON, asked of the simulation's own parts: true when (x, z) in the ship's frame is over
## any `deck` part. The marshalling deck's "she has gone over the side" is this, so a deck that changes shape changes
## where the edge is.
static func is_on_deck(at: Vector2) -> bool:
	for part in (Sim.geometry_of(Sim.Kind.CARRIER).get("parts", []) as Array):
		if String(part.get("part", "")) == "deck" \
				and Geometry2D.is_point_in_polygon(at, part.get("outline", PackedVector2Array())):
			return true
	return false


## The height of the flight deck above the ship's origin, which is on the waterline.
static func deck_height() -> float:
	return float((Sim.geometry_of(Sim.Kind.CARRIER).get("extents", Vector3.ZERO) as Vector3).y)
