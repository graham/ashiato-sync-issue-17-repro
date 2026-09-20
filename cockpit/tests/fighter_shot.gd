extends Node
## THE F/A-18F, LOOKED AT IN THE WORLD: in the air with its gear up, then standing on the Ford's landing area with its
## gear down, and from both crews' eyes on the deck. Its cost is measured in the bare inspector room
## (`fighter_inspector_shot --measure`): in this level the shown-minus-hidden frame read -10 draw calls, the world's own.
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/fighter_shot.tscn -- --level=watch --clouds=none --out=C:/somewhere
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). The structure, gear, hook and
## lights are measured by tests/fighter.gd; whether it reads as a Super Hornet is for eyes. RESULT= says only that every
## picture saved and both fighters were found.
##
## THE CRAFT IS FOUND BY KIND AND PLACE, NOT BY THE ID A SPAWN RETURNS: `Sim.spawn_vehicle` answers with the server's entity
## and the level draws the client's (hawkeye_shot photographed a patrol boat eight times before it learnt that). THE DECK
## IS ASKED WHERE IT IS NOW: the Ford is found by its spawn's name and read from the server, because under way it has
## steered and heaved since it was put.
##
## Pictures in `--out`: `fighter-<shot>.png`.

const SETTLE: int = 12
## How far out the outside shots stand, metres: a few lengths of the aircraft.
const NEAR: float = 32.0
## WHERE ON THE FORD IT STANDS, in the ship's frame: on the landing centreline 40 m up from the ramp, short of the first wire,
## pointing up the angled deck as a trap would leave it.
const ON_DECK_FROM_RAMP: float = 40.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://fighter_shot"
var _view: VehicleView = null
var _from_local: Vector3 = Vector3.ZERO
var _toward_local: Vector3 = Vector3.ZERO
var _fov: float = 50.0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[fighter_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	await _frames(60)
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.FIGHTER)
	var half: Vector3 = geometry.get("extents", Vector3.ONE)
	_level.choose_time(DaylightTuning.When.DAY)

	# IN THE AIR, gear up: over the sea near the middle, flying.
	var up_at := Vector3(0.0, 900.0, 0.0)
	var flying: int = Sim.spawn_vehicle(Sim.Kind.FIGHTER, up_at, 0.0, Vector3(0.0, 0.0, -110.0))
	_view = await _drawn_fighter_near(up_at, 300.0)
	_check("there_is_a_fighter_in_the_air", _view != null, "server entity %d" % flying)
	if _view != null:
		for shot in ["front_quarter", "side", "overhead", "below"]:
			_place(shot, geometry, half)
			await _frames(SETTLE)
			_save("fighter-air-gear-up-%s" % shot)
	_view = null
	Sim.server.despawn_vehicle(flying)

	# ON THE FORD, gear down: spawned onto the deck as a parked craft is, carried at the ship's velocity.
	var ford: int = _level.spawned_entity(&"ford")
	var ship: Dictionary = Sim.server.vehicle_state(ford) if ford != 0 else {}
	_check("there_is_a_ford_to_stand_on", not ship.is_empty(), "server entity %d" % ford)
	if not ship.is_empty():
		var along: Vector2 = CarrierPlan.landing_direction()
		var spot2: Vector2 = CarrierPlan.RAMP + along * ON_DECK_FROM_RAMP
		var deck := Transform3D(Basis(ship["basis"] as Quaternion), ship["position"] as Vector3)
		var spot: Vector3 = deck * Vector3(spot2.x, CarrierPlan.deck_height() + half.y + 0.5, spot2.y)
		var yaw: float = (deck.basis.get_euler().y) + atan2(-along.x, -along.y)
		var parked: int = Sim.spawn_vehicle(Sim.Kind.FIGHTER, spot, yaw, ship.get("velocity", Vector3.ZERO) as Vector3)
		await _frames(90)
		var bus: Dictionary = Sim.server.craft_controls(parked)
		_check("the_fighter_on_the_deck_stands_on_its_gear", bool(bus.get("gear", false)), "%s" % [bus])
		_view = await _drawn_fighter_near(Sim.server.vehicle_state(parked).get("position", spot) as Vector3, 60.0)
		_check("there_is_a_fighter_drawn_on_the_deck", _view != null, "server entity %d" % parked)
		if _view != null:
			for shot in ["front_quarter", "side", "rear_quarter", "deck_level", "pilot", "wso"]:
				_place(shot, geometry, half)
				await _frames(SETTLE)
				_save("fighter-ford-gear-down-%s" % shot)
	_finish()


## WHERE THE CAMERA GOES for a shot, in the craft's frame.
func _place(shot: String, geometry: Dictionary, half: Vector3) -> void:
	_fov = 50.0
	_toward_local = Vector3(0.0, 0.0, 0.0)
	match shot:
		"front_quarter":
			_from_local = Vector3(NEAR * 0.55, 4.0, -NEAR * 0.75)
		"rear_quarter":
			_from_local = Vector3(-NEAR * 0.55, 5.0, NEAR * 0.75)
		"side":
			_from_local = Vector3(NEAR, 0.5, 0.0)
		"overhead":
			_from_local = Vector3(0.0, NEAR * 1.2, 4.0)
		"below":
			_from_local = Vector3(8.0, -NEAR * 0.7, -6.0)
		"deck_level":
			_from_local = Vector3(10.0, -half.y + 0.6, -12.0)
			_toward_local = Vector3(0.0, -half.y + 0.4, 1.0)
		"pilot", "wso":
			var poses: Array = geometry.get("seat_poses", []) as Array
			var seat: Dictionary = poses[0 if shot == "pilot" else 1]
			_from_local = (seat["position"] as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
			_toward_local = _from_local + Vector3(0.0, -0.15, -1.0) * 50.0
			_fov = 90.0


func _process(_delta: float) -> void:
	if _view == null or not is_instance_valid(_view) or _level == null or _level.observer == null:
		return
	_level.observer.fov = _fov
	var pose: Transform3D = _view.global_transform
	_level.observer.look_from(pose * _from_local, pose * _toward_local)


## THE FIGHTER THIS MACHINE DRAWS NEAREST A POINT, waited for: found by its kind in `Sim.current`, which is keyed by the ids
## the level draws, never the id a spawn returns.
func _drawn_fighter_near(near: Vector3, within: float) -> VehicleView:
	for i in range(240):
		var best: int = 0
		var nearest: float = within
		for entity in Sim.current:
			var state: Dictionary = Sim.current[entity]
			if int(state.get("kind", -1)) != Sim.Kind.FIGHTER:
				continue
			var away: float = (state.get("position", Vector3.ZERO) as Vector3).distance_to(near)
			if away < nearest:
				nearest = away
				best = int(entity)
		var view: VehicleView = _level.view_of(best) if best != 0 else null
		if view != null:
			await _frames(30)
			return view
		await _frames(1)
	return null


func _save(name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	_view = null
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
