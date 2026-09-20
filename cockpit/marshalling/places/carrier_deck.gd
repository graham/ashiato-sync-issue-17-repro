extends Node3D
class_name CarrierDeck
## A THIRD OF A KILOMETRE OF RUNWAY, AT SEA, WITH THE DECK AT ZERO.
##
## The ship is the game's own carrier -- `craft_carrier.tscn`, built by `VehicleView.setup` from the simulation's own
## Ford-class parts -- sunk by exactly its own deck height so that the flight deck is the plane y = 0. Everything else in
## the level, the marshaller included, is then placed at zero and does not have to know how tall a carrier is. Move the
## ship and the deck moves with it; nothing else changes.
##
## What this adds on top of the ship is the CATAPULT a jet is marshalled onto: a track, a shuttle to stop the nosewheel
## on, and a blast deflector that comes up out of the deck behind the aeroplane when it takes tension. None of it is
## collision and none of it is physics. It is paint, and one hinged slab.
##
## WHERE THAT CATAPULT IS comes from `CarrierPlan`, not from here. This file used to type its own (`TRACK_X = -14`,
## `SHUTTLE_Z = -60`, on a 333 m Nimitz deck), and when the ship became a Ford those numbers would have kept a catapult
## wherever the old deck had one.


var _jbd: Node3D = null
var _jbd_up: float = 0.0


## WHERE THE LAUNCH CATAPULT RUNS, in the ship's own frame: its track's x, the shuttle's z, and the end of the stroke.
static func track_x() -> float:
	return (CarrierPlan.CATAPULTS[CarrierPlan.LAUNCH]["start"] as Vector2).x


static func shuttle_z() -> float:
	return (CarrierPlan.CATAPULTS[CarrierPlan.LAUNCH]["start"] as Vector2).y


static func bow_z() -> float:
	return (CarrierPlan.CATAPULTS[CarrierPlan.LAUNCH]["end"] as Vector2).y


func _ready() -> void:
	var ship := (load("res://objects/vehicles/craft_carrier.tscn") as PackedScene).instantiate() as VehicleView
	add_child(ship)
	ship.setup(0, Sim.Kind.CARRIER)
	# THE DECK IS THE TOP OF THE SHIP'S DECK PARTS, which is `extents.y` above its origin on the waterline, so this is
	# the one number that puts the deck at zero -- and the sea, at the origin, that far below it.
	var deck: float = CarrierPlan.deck_height()
	ship.position = Vector3(0.0, -deck, 0.0)

	_sea(-deck)
	_catapult()
	_weather()


## ---- the catapult -------------------------------------------------------------------

func _catapult() -> void:
	var cat: Dictionary = CarrierPlan.CATAPULTS[CarrierPlan.LAUNCH]
	var start: Vector2 = cat["start"]
	var end: Vector2 = cat["end"]
	var behind: Vector2 = CarrierPlan.deflector_at(CarrierPlan.LAUNCH)
	# The slot itself, and the two rails either side of it that a nosewheel is steered between, from the blast
	# deflector to the end of the stroke.
	var middle: float = (behind.y + end.y) * 0.5
	var length: float = absf(behind.y - end.y)
	_paint(Vector3(start.x, 0.02, middle), Vector3(0.9, 0.04, length), Color(0.07, 0.07, 0.08))
	for side in [-1.0, 1.0]:
		_paint(Vector3(start.x + side * 3.2, 0.02, middle), Vector3(0.30, 0.04, length), Color(0.92, 0.92, 0.88))
	# THE SHUTTLE MARK: a bar across the track, which is the thing a marshaller is aiming a nosewheel at and the thing
	# the whole level is scored on.
	_paint(Vector3(start.x, 0.03, start.y), Vector3(7.0, 0.05, 0.5), Color(0.95, 0.82, 0.25))
	# Distance marks down the track behind it, so "how far to go" is readable without an instrument.
	for i in range(1, 9):
		_paint(Vector3(start.x + 4.2, 0.02, start.y + float(i) * 10.0), Vector3(1.6, 0.04, 0.3),
			Color(0.75, 0.76, 0.72))

	# THE JET BLAST DEFLECTOR. Flat in the deck until there is tension on the shuttle, and then it is a wall behind the
	# aeroplane -- which is the one piece of the deck that MOVES, and the clearest sign to a player that the catapult now
	# has her. Its size is the Navy's: 11 m across, 3.3 m tall when raised.
	_jbd = Node3D.new()
	_jbd.position = Vector3(behind.x, 0.0, behind.y)
	add_child(_jbd)
	var panel := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(CarrierPlan.DEFLECTOR_WIDE, 0.35, CarrierPlan.DEFLECTOR_TALL)
	panel.mesh = slab
	# Hinged at its aft edge: the slab lies forward of the hinge, towards the aeroplane.
	panel.position = Vector3(0.0, 0.18, -CarrierPlan.DEFLECTOR_TALL * 0.5)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.28, 0.30, 0.33)
	steel.metallic = 0.5
	steel.roughness = 0.6
	panel.material_override = steel
	_jbd.add_child(panel)


## Raise or lower the deflector. Hinged at its aft edge, like the real one.
func deflector(up: bool) -> void:
	_jbd_up = 1.0 if up else 0.0


func _process(delta: float) -> void:
	if _jbd == null:
		return
	var wanted: float = _jbd_up * CarrierPlan.DEFLECTOR_RAISED
	_jbd.rotation.x = move_toward(_jbd.rotation.x, wanted, delta * deg_to_rad(45.0))


## ---- the sea and the sky -------------------------------------------------------------

## ONE ENORMOUS QUAD. The game's sea is displaced only near the eye, on SeaSwell's sheet; a deck scene's four corners
## are 8 km out, past where any vertex moves, so this quad paints the simulation's swell (`SeaSwell.hand_the_swell`)
## and stays flat, which from a flight deck is what it looks like.
func _sea(at: float) -> void:
	var water := MeshInstance3D.new()
	var flat := PlaneMesh.new()
	flat.size = Vector2(16000.0, 16000.0)
	water.mesh = flat
	water.position = Vector3(0.0, at, 0.0)
	water.name = "Sea"
	# THE SEA'S OWN SHADER FOR THE FINISH, from the one place water is dressed (WaterSurface). Until 2026-09-17 this was
	# always the plain shader, with a flat StandardMaterial3D blue behind it for a missing file.
	WaterSurface.wear(water, Finish.is_fine())
	add_child(water)


func _weather() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(125.0), 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	var air := WorldEnvironment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.19, 0.36, 0.62)
	sky_material.sky_horizon_color = Color(0.63, 0.72, 0.80)
	sky_material.ground_bottom_color = Color(0.10, 0.17, 0.24)
	sky_material.ground_horizon_color = Color(0.55, 0.65, 0.74)
	var overhead := Sky.new()
	overhead.sky_material = sky_material
	var weather := Environment.new()
	weather.background_mode = Environment.BG_SKY
	weather.sky = overhead
	weather.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	weather.ambient_light_energy = 1.0
	air.environment = weather
	add_child(air)


func _paint(at: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	slab.mesh = box
	slab.position = at
	var paint := StandardMaterial3D.new()
	paint.albedo_color = tint
	paint.roughness = 0.92
	slab.material_override = paint
	add_child(slab)
	return slab
