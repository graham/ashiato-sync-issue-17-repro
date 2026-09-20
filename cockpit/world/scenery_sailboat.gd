@tool
extends Node3D
class_name ScenerySailboat
## A CRUISING SLOOP OR A LEIGH 30 CUTTER SAILING PAST, AS SCENERY -- drawn, never simulated.
##
## WHAT THIS IS FOR. The user asked for the sailboats "on the water, moving and listing a bit (due to wind)" and said
## the listing could be faked. For the brig it is not faked and must never be: she is `Sim.Kind.PIRATE`, the only kind
## on the `Sail` movement model, and her lean is what four sails do to her hull (see `tests/sail_reel.gd`). These two
## are a different thing entirely. `cruising_sloop` and `classic_cutter` are NOT kinds -- `SmallCraftDraft` says so in
## its own second line, "MOVES TO cockpit_world.cpp WHEN THE KINDS EXIST" -- so there is no simulation under them to
## lean them over. This is the permission the user gave, spent here and nowhere else.
##
## EVERY ANGLE THIS NODE PUTS ON A BOAT IS A DRAWN ANGLE. Nothing here reaches the simulation, nothing here is
## replicated, and no number this computes is read by anything but the transform of a mesh. `_drawn_heel` says so in
## its own name, so that the next person to read it cannot mistake it for seakeeping: there is no righting moment, no
## sail force and no centre of effort behind that angle, only a curve chosen because it looks like a boat sailing.
##
## THE WIND IS ASKED FOR, NOT KEPT. `CockpitWorld.weather()` answers `from` and `speed` at this frame, wander and veer
## included, and it is the same field the brigs sail in -- so a sloop crossing the same water leans away from the same
## wind the square-rigger is leaning away from, and the day the weather veers she leans the other way without anybody
## editing a constant (CLAUDE.md rule 4). With no server she lies upright, which is correct: no wind, no lean.
##
## THE SEA UNDER HER IS REAL. Her height and her pitch come from `swell_height_at` sampled at her own bow and stern --
## the standing swell the simulation floats hulls on, not a guess -- so she rides the same water the ships do rather
## than sliding along a flat plane through it. That part is not a fake at all; only the heel and the small wander of
## her helm are.
##
## WHAT SHE HASN'T GOT. No wake, no bow wave and no crew: a wake here belongs to the hull system and this is a mesh on
## a track. At the distances she is meant to be seen from that reads as a becalmed-looking boat under way, and it is
## the first thing to fix if she is ever wanted in the foreground.

## The boats this will draw. The other two rows of `SmallCraftDraft.CLASSES` are a trawler and a motor yacht, which do
## not sail and have no business leaning.
const SAILING_BOATS: Array[String] = ["cruising_sloop", "classic_cutter"]

## THE MOST A DRAWN BOAT LEANS, in degrees, on a beam wind at `FULL_WIND` or more. Chosen by eye against the brig, who
## measured -17.3 degrees on a beam reach in 14 m/s of wind: a ballasted cruising yacht of this size is stiffer than a
## brig under a full press of square sail, and the user asked for "listing a bit", so she is given rather less.
const MOST_HEEL: float = 13.0
## The wind at which a boat is leaning as far as she is going to. Above it she does not lean further -- a drawn boat
## has no reef to take in, and one laid flat by a gust would read as a capsize rather than as weather.
const FULL_WIND: float = 12.0
## HER SLOW BREATH, in degrees and in seconds: the swell rolls her a little either side of the angle the wind holds her
## at. Without it a boat at a fixed heel reads as a model glued over at an angle, which is exactly what she is.
const BREATH: float = 1.6
const BREATH_SECONDS: float = 7.0
## HOW FAR HER HELM WANDERS, in degrees, and how long a wander takes. A boat that holds a compass heading to the
## arc-minute for a minute and a half is a boat on rails. Drawn, like the heel.
const WANDER: float = 3.5
const WANDER_SECONDS: float = 11.0

## Which of `SAILING_BOATS` she is, and which of `SmallCraft.LIVERIES`' six schemes she wears.
var which: String = "cruising_sloop"
var livery: int = 0
## Her track: where she was at `_sailing_since`, the compass heading she sails, and how fast in metres a second. Five
## knots is 2.57 m/s and is what a thirty-footer does on a reach in this much wind.
var from_place := Vector3.ZERO
var heading: float = 0.0
var speed: float = 2.57

var _clock: float = 0.0
var _mesh: MeshInstance3D = null
## Her length, kept from the draft so the pitch is sampled at her real bow and stern rather than at a guess.
var _length: float = 10.0
## The last angles drawn, in degrees, so a probe can photograph her and say what it photographed.
var _heel_drawn: float = 0.0
var _pitch_drawn: float = 0.0


## A BOAT PUT ON THE WATER AND SENT OFF. A factory, as `Marina.one` is: the mesh is built on construction, so anything
## that measures her drawn bounds the moment she is made finds a mesh there rather than an empty box.
static func one(boat: String, at: Vector3, sailing: float, paint: int = 0, through_water: float = 2.57) -> ScenerySailboat:
	var made := ScenerySailboat.new()
	made.which = boat
	made.livery = paint
	made.from_place = at
	made.heading = sailing
	made.speed = through_water
	made._build()
	return made


func _ready() -> void:
	if _mesh == null:
		_build()


func _build() -> void:
	assert(SAILING_BOATS.has(which), "%s is not a boat that sails; it would have nothing to lean for" % which)
	var geometry: Dictionary = SmallCraftDraft.geometry(which)
	_length = float(SmallCraftDraft.CLASSES[which]["length"])
	var mesh: ArrayMesh = ShipHull.models(-1, geometry, livery).get("near") as ArrayMesh
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.material_override = ShipHull.painted()
	add_child(_mesh)
	_settle(0.0)


func _process(delta: float) -> void:
	_clock += delta
	_settle(_clock)


## WHERE SHE IS AND HOW SHE SITS, this frame. Her place along the track and her height on the swell are real; her heel
## and the wander of her helm are drawn.
func _settle(time: float) -> void:
	var steered: float = heading + deg_to_rad(WANDER) * sin(TAU * time / WANDER_SECONDS)
	var nose := Vector3(sin(steered), 0.0, -cos(steered))
	var along: Vector3 = from_place + Vector3(sin(heading), 0.0, -cos(heading)) * speed * time
	var bow: Vector3 = along + nose * _length * 0.5
	var stern: Vector3 = along - nose * _length * 0.5
	var at_bow: float = _sea_at(bow)
	var at_stern: float = _sea_at(stern)
	# SHE RIDES THE SWELL she is actually on: her waterline sits on the mean of her ends, and she pitches by the slope
	# between them. Not drawn -- this is the same surface `swell_height_at` floats the ships on.
	var pitch: float = atan2(at_bow - at_stern, _length)
	var heel: float = _drawn_heel(steered, time)
	_heel_drawn = rad_to_deg(heel)
	_pitch_drawn = rad_to_deg(pitch)
	var upright := Basis(Vector3.UP, -steered)
	# PITCH ABOUT HER OWN ATHWARTSHIPS AXIS AND HEEL ABOUT HER OWN FORE-AND-AFT ONE, in that order, so the heel is
	# measured off her deck and not off the world -- a boat pitched bow-up and then rolled in world axes leans in a
	# direction she is not pointing.
	var sitting: Basis = upright * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, heel)
	transform = Transform3D(sitting, Vector3(along.x, (at_bow + at_stern) * 0.5, along.z))


## THE LEAN, AND IT IS DRAWN. There is no sail force behind this number and no righting moment under it: it is a curve
## picked because it looks like a boat sailing, evaluated against the wind the world really has.
##
## The shape of it is the one thing about a fake worth getting right. A boat leans most with the wind on her beam, not
## at all head to wind or dead downwind, and harder the more wind there is -- so the angle is `sin` of the wind off her
## bow, times the wind's share of `FULL_WIND`, capped there. The sign follows the brig's (`sail_report`): wind on the
## starboard side lays the masts to port, which is negative.
func _drawn_heel(steered: float, time: float) -> float:
	var world: Object = Sim.server if Sim.server != null else Sim.client
	if world == null or not world.has_method("weather"):
		return 0.0
	var weather: Dictionary = world.weather()
	var off: float = wrapf(float(weather.get("from", 0.0)) - steered, -PI, PI)
	var strength: float = clampf(float(weather.get("speed", 0.0)) / FULL_WIND, 0.0, 1.0)
	var lean: float = deg_to_rad(MOST_HEEL) * absf(sin(off)) * strength
	var breath: float = deg_to_rad(BREATH) * sin(TAU * time / BREATH_SECONDS)
	return -signf(off) * lean + breath


## THE WATER UNDER A POINT: the standing swell the simulation floats hulls on, or the flat sea with no server.
func _sea_at(place: Vector3) -> float:
	var world: Object = Sim.server if Sim.server != null else Sim.client
	if world == null or not world.has_method("swell_height_at"):
		return 0.0
	return float(world.swell_height_at(place.x, place.z))


## WHAT SHE IS DOING, for a probe that photographs her: the angles actually drawn this frame, in degrees, and both
## named so that a reader of the printout knows which of them is a fake.
func drawn_pose() -> Dictionary:
	return {"boat": which, "drawn_heel_deg": _heel_drawn, "swell_pitch_deg": _pitch_drawn,
		"place": global_position, "heading_deg": rad_to_deg(heading), "speed": speed}
