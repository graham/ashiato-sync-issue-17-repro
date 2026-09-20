extends Node
## THE E-2D HAWKEYE, LOOKED AT: in the air with its wings spread from the front quarter, the side and overhead; parked on the
## island's runway with its wings folded from its real bus; and from the pilot's seat and a mission officer's.
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/hawkeye_shot.tscn -- --level=watch --clouds=none --out=C:/somewhere
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). Whether the airframe reads
## as an E-2D, whether the folded panels hang under the rotodome and whether the lights stand on the tips are for eyes; the
## fold's bus and the drawn panels' measurements are held by tests/fleet_shapes.gd.
##
## THE CRAFT IS FOUND BY KIND AND PLACE, NOT BY THE ID A SPAWN RETURNS. `Sim.spawn_vehicle` answers with the server's entity,
## and the level draws the client's world, whose ids differ: the first run of this probe asked `view_of` for the server's id
## and photographed a patrol boat eight times (contrail_shot finds its aeroplane by position for the same reason).
##
## THE FOLD IS THE REAL ONE, ON STATIC GROUND: a pilot is spawned in a pod far away, seated as the parked Hawkeye's CO-PILOT
## (the pilot's seat would launch it, `launch_if_grounded`), and the wing fold is commanded through `set_pilot_input`. It is
## parked on the island's runway. The first run tried the carrier and its gear stayed up: it had found the carrier by the
## CLIENT's id and read it on the server, so the Hawkeye was put over open sea, with nothing under it for the gear, and the
## squat switch refused the fold. `spawn_vehicle`'s ground ray does count a ship's deck. The view eases the drawn panels over
## `HawkeyeAirframe.FOLD_SECONDS`, so the picture waits for that.
##
## Pictures in `--out`: `hawkeye-<finish>-<shot>.png`.

const SETTLE: int = 10
const CLIENT: int = 91
## How far out the outside shots stand, metres: a few lengths of the aircraft.
const NEAR: float = 45.0
## How far along the runway from its middle the parked Hawkeye stands, metres: toward the far end of its 900 m, clear of the
## craft the island parks at its middle.
const PARKED_ALONG: float = 330.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://hawkeye_shot"
var _view: VehicleView = null
var _from_local: Vector3 = Vector3.ZERO
var _toward_local: Vector3 = Vector3.ZERO
var _fov: float = 50.0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[hawkeye_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
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
	var finish: Node = get_node("/root/Finish")
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.HAWKEYE)
	var half: Vector3 = geometry.get("extents", Vector3.ONE)

	# IN THE AIR, spread: over the sea near the middle, flying.
	var up_at := Vector3(0.0, 900.0, 0.0)
	var flying: int = Sim.spawn_vehicle(Sim.Kind.HAWKEYE, up_at, 0.0, Vector3(0.0, 0.0, -110.0))
	_view = await _drawn_hawkeye_near(up_at)
	_check("there_is_a_hawkeye_in_the_air", _view != null and _view.kind == Sim.Kind.HAWKEYE,
		"server entity %d, drawn %s" % [flying, _view.name if _view != null else "nothing"])
	if _view != null:
		for fine in [false, true]:
			var finish_name: String = "fine" if fine else "plain"
			finish.call("choose", fine)
			_level.choose_time(DaylightTuning.When.DAY)
			for shot in ["front_quarter", "side", "overhead"]:
				_place(shot, geometry, half)
				await _frames(SETTLE)
				_save("hawkeye-%s-%s" % [finish_name, shot])
			if not fine:
				for shot in ["pilot", "operator"]:
					_place(shot, geometry, half)
					await _frames(SETTLE)
					_save("hawkeye-%s-%s" % [finish_name, shot])
	_view = null
	Sim.server.despawn_vehicle(flying)

	# PARKED ON THE ISLAND'S RUNWAY, folded through the bus.
	var runway: Dictionary = Terrain.runways()[0]
	var along: Vector3 = runway["along"]
	var spot: Vector3 = (runway["centre"] as Vector3) + along * PARKED_ALONG
	spot.y = maxf(spot.y, float(Sim.server.ground_height_at(spot.x, spot.z))) + half.y + 0.8
	var parked: int = Sim.spawn_vehicle(Sim.Kind.HAWKEYE, spot, -float(runway["bearing"]), Vector3.ZERO)
	var made: Dictionary = Sim.server.spawn_pilot(CLIENT, Sim.Kind.POD, spot + Vector3(0.0, 400.0, 3000.0), 0.0, Vector3.ZERO)
	await _frames(120)
	var standing: Dictionary = Sim.server.craft_controls(parked)
	_check("the_parked_hawkeye_stands_on_its_gear", bool(standing.get("gear", false)), "%s" % [standing])
	var seated: bool = bool(Sim.server.seat_client(CLIENT, parked, 1))
	Sim.server.set_pilot_input(int(made.get("pilot", 0)), {"command_channel": Sim.Channel.FOLD, "command_value": 1,
		"command_seq": 1})
	await _frames(int((HawkeyeAirframe.FOLD_SECONDS + 2.0) * Engine.physics_ticks_per_second))
	var bus: Dictionary = Sim.server.craft_controls(parked)
	_check("the_parked_hawkeye_is_folded_on_its_bus", seated and bool(bus.get("fold", false)), "seated %s, %s" % [
		seated, bus])
	_view = await _drawn_hawkeye_near(spot)
	_check("there_is_a_parked_hawkeye_drawn", _view != null and _view.kind == Sim.Kind.HAWKEYE, "")
	if _view != null:
		finish.call("choose", false)
		for shot in ["front_quarter", "side", "overhead"]:
			_place(shot, geometry, half)
			await _frames(SETTLE)
			_save("hawkeye-plain-folded_%s" % shot)
	_finish()


## WHERE THE CAMERA GOES for a shot, in the craft's frame.
func _place(shot: String, geometry: Dictionary, half: Vector3) -> void:
	_fov = 50.0
	_toward_local = Vector3(0.0, half.y, 0.0)
	match shot:
		"front_quarter":
			_from_local = Vector3(NEAR * 0.6, half.y + 4.0, -NEAR * 0.8)
		"side":
			_from_local = Vector3(NEAR, half.y + 1.0, 0.0)
		"overhead":
			_from_local = Vector3(0.0, NEAR * 1.1, 8.0)
		"pilot", "operator":
			var poses: Array = geometry.get("seat_poses", []) as Array
			var seat: Dictionary = poses[0 if shot == "pilot" else 2]
			var turn := Basis(Vector3.UP, float(seat["yaw"]))
			_from_local = (seat["position"] as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
			_toward_local = _from_local + turn * Vector3(0.0, -0.1, -1.0) * 50.0
			_fov = 90.0


func _process(_delta: float) -> void:
	if _view == null or not is_instance_valid(_view) or _level == null or _level.observer == null:
		return
	_level.observer.fov = _fov
	var pose: Transform3D = _view.global_transform
	_level.observer.look_from(pose * _from_local, pose * _toward_local)


## THE HAWKEYE THIS MACHINE DRAWS NEAREST A POINT, within 300 m, waited for: found by its kind in `Sim.current`, which is
## keyed by the ids the level draws, never the id a spawn returns.
func _drawn_hawkeye_near(near: Vector3) -> VehicleView:
	for i in range(240):
		var best: int = 0
		var nearest: float = 300.0
		for entity in Sim.current:
			var state: Dictionary = Sim.current[entity]
			if int(state.get("kind", -1)) != Sim.Kind.HAWKEYE:
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
