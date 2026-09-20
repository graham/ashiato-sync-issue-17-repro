extends Node3D
class_name CockpitHall
## EVERY COCKPIT IN THE GAME, IN A ROW, WITH NOTHING ROUND THEM.
##
##   Godot --path cockpit -- --level=hall
##
## Seats and nothing else: no fuselages, no world, no simulation. A cockpit is the part of
## a craft anybody actually spends time in, and the only way to judge one is to sit in it
## and reach for things -- which until now meant loading a world of a hundred and sixty
## machines and flying to the right one.
##
## SPACE for the next, SHIFT+SPACE for the last, and the MENU BUTTON on the left controller
## for the next in a headset. One station at a time is lit and manned; the rest stand there
## so you can see how they differ, which is most of what you want to know.
##
## Every station in here is the real scene the game uses, built by the real code, and the
## rig sits in it the same way it sits in an aeroplane -- see `PilotRig.take_station`, which
## is the one thing this needed that did not already exist. If a control is out of reach
## here it is out of reach in flight.

## How far apart the stations stand. Wide enough that two do not read as one cockpit.
const SPACING: float = 4.0

var _stations: Array[CockpitStation] = []
var _labels: Array[Label3D] = []
var _kinds: Array[int] = []
var _at: int = 0
var _rig: PilotRig = null
var _menu_was_down: bool = false


func _ready() -> void:
	_build_the_room()
	_lay_out_the_stations()
	_rig = load("res://player/pilot_rig.tscn").instantiate() as PilotRig
	add_child(_rig)
	_sit_at(0)


## ONE OF EVERY KIND, in the order Sim.Kind lists them, skipping any that share a station
## scene with one already placed.
##
## By SCENE and not by kind, because eight of the fourteen craft sit at the same station and
## a hall with eight identical light-aeroplane cockpits in it is a hall you cannot find
## anything in. What is on show is the cockpits, which is what there are fewer of.
func _lay_out_the_stations() -> void:
	var seen: Dictionary = {}
	for kind in range(Sim.Kind.size()):
		var scene: PackedScene = VehicleCatalogue.seat_scene(kind)
		if scene == null or seen.has(scene.resource_path):
			continue
		seen[scene.resource_path] = true
		var stand := Node3D.new()
		stand.position = Vector3(float(_stations.size()) * SPACING, 0.0, 0.0)
		add_child(stand)
		var station := scene.instantiate() as CockpitStation
		stand.add_child(station)
		# SEAT 0, AND MINE. There is nobody else here, and a station fitted to somebody
		# else's seat is a station whose controls refuse your hands.
		station.fit(0)
		_stations.append(station)
		_kinds.append(kind)

		# THE FLOOR IT STANDS ON, so a cockpit in mid-air reads as a cockpit on a stand.
		var plinth := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = Vector3(2.2, 0.12, 2.2)
		plinth.mesh = slab
		plinth.position = Vector3(0.0, -0.06, 0.0)
		var dull := StandardMaterial3D.new()
		dull.albedo_color = Color(0.17, 0.18, 0.20)
		dull.roughness = 0.9
		plinth.material_override = dull
		stand.add_child(plinth)

		var name_plate := Label3D.new()
		name_plate.text = _name_of(scene, kind)
		name_plate.font_size = 96
		name_plate.pixel_size = 0.0016
		name_plate.position = Vector3(0.0, 2.35, -1.0)
		name_plate.modulate = Color(0.95, 0.78, 0.30)
		name_plate.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		stand.add_child(name_plate)
		_labels.append(name_plate)


## What to call a station: the scene, and every kind of craft that uses it. A player looking
## for "the one out of the Chinook" wants the list, not the filename.
func _name_of(scene: PackedScene, first: int) -> String:
	# BY PATH, not by object. Two `load()` calls of the same scene usually hand back the
	# same cached resource and usually compare equal, and "usually" is not something to name
	# a station after.
	var shared: Array[String] = []
	for kind in range(Sim.Kind.size()):
		var theirs: PackedScene = VehicleCatalogue.seat_scene(kind)
		if theirs != null and theirs.resource_path == scene.resource_path:
			shared.append(Sim.kind_name(kind))
	var stem: String = scene.resource_path.get_file().trim_suffix(".tscn").trim_prefix("seat_")
	if shared.size() <= 1:
		return "%s\n%s" % [stem.to_upper(), Sim.kind_name(first)]
	return "%s\n%s" % [stem.to_upper(), ", ".join(shared)]


func _sit_at(index: int) -> void:
	if _stations.is_empty():
		return
	_at = posmod(index, _stations.size())
	var station: CockpitStation = _stations[_at]
	_rig.take_station(station)
	_rig.recentre()
	for i in range(_labels.size()):
		_labels[i].modulate = Color(0.95, 0.78, 0.30) if i == _at \
			else Color(0.42, 0.44, 0.48)
	print("[hall] %d of %d: %s" % [_at + 1, _stations.size(),
		_labels[_at].text.replace("\n", " ")])


## ---- what the tests ask ----------------------------------------------------------

## How many distinct stations are on show. One per station SCENE, not one per kind.
func station_count() -> int:
	return _stations.size()


## What the station at this position is called, first line only.
func name_at(index: int) -> String:
	if index < 0 or index >= _labels.size():
		return ""
	return _labels[index].text.split("\n")[0]


## Sit at one by number, which is what SPACE does with the next one along.
func sit_at(index: int) -> void:
	_sit_at(index)


## The rig in the hall, so a test can ask what its hands found.
func rig() -> PilotRig:
	return _rig


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_SPACE:
		_sit_at(_at + (-1 if key.shift_pressed else 1))


func _physics_process(_delta: float) -> void:
	# THE MENU BUTTON ON THE LEFT CONTROLLER, edge-detected here rather than through the
	# rig: the rig's buttons are the craft's -- next seat, next aircraft -- and this is a
	# control that belongs to the room instead. It is read directly for the same reason.
	if _rig == null or not _rig.using_xr or _rig.left_hand == null:
		return
	var down: bool = _rig.left_hand.is_button_pressed(&"menu_button")
	if down and not _menu_was_down:
		_sit_at(_at + 1)
	_menu_was_down = down


func _build_the_room() -> void:
	var deck := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(float(Sim.Kind.size()) * SPACING + 12.0, 0.4, 20.0)
	deck.mesh = slab
	deck.position = Vector3(slab.size.x * 0.5 - SPACING - 4.0, -0.32, 0.0)
	var floor_paint := StandardMaterial3D.new()
	floor_paint.albedo_color = Color(0.12, 0.13, 0.15)
	floor_paint.roughness = 0.95
	deck.material_override = floor_paint
	add_child(deck)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.7, 0.0)
	sun.light_energy = 1.0
	add_child(sun)
	var air := WorldEnvironment.new()
	var room := Environment.new()
	room.background_mode = Environment.BG_COLOR
	room.background_color = Color(0.06, 0.07, 0.09)
	room.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room.ambient_light_color = Color(0.48, 0.51, 0.58)
	room.ambient_light_energy = 1.1
	air.environment = room
	add_child(air)
