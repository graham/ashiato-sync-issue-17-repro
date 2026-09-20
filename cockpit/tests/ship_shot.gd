extends Node
## THE SHIPS, LOOKED AT: every boat in the sky broadside and from the bow quarter, near and far, the carrier from overhead
## and at dusk, and the view from each helm, on both finishes -- and what each ship costs to draw.
##
##   Godot --path cockpit --resolution 1600x900 res://tests/ship_shot.tscn -- --level=watch --clouds=none --out=C:/somewhere
##   ... -- --level=watch --clouds=none --kinds=carrier --shots=broadside_500,helm
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). Whether a ship reads as the
## ship it is, whether its waterline is where the sea is and whether a helm can see its bow are for eyes; that the parts are
## the fact sheet's and a seat stands in its room is held headless by tests/carrier_shape.gd.
##
## THE COST IS MEASURED, NOT GUESSED: at each distance the frame's draw calls and primitives are read with the ship shown and
## again with it hidden, and the difference is the ship's. `RenderingServer.get_rendering_info` counts the whole frame --
## shadow passes included -- so the difference is what the ship adds to a real frame of the real sky.
##
## Pictures in `--out`: `<kind>-<finish>-<shot>.png`.

## Frames after the camera or the finish moves before a picture is taken.
const SETTLE: int = 10
const SHOTS: PackedStringArray = ["broadside_500", "bow_quarter_500", "broadside_3000", "bow_quarter_3000", "overhead",
	"helm", "helm_down", "dusk"]
const KINDS: Dictionary = {"boat": 2, "gunboat": 9, "carrier": 12, "battleship": 13, "submarine": 20}

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://ship_shot"
var _kinds: PackedStringArray = ["carrier", "battleship", "gunboat", "boat"]
var _shots: PackedStringArray = SHOTS
## Where the camera is, in the SHIP'S frame, re-placed every frame because the ship is under way.
var _ship: VehicleView = null
var _from_local: Vector3 = Vector3.ZERO
var _toward_local: Vector3 = Vector3.ZERO
var _fov: float = 50.0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ships] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--kinds="):
			_kinds = argument.trim_prefix("--kinds=").split(",")
		elif argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=").split(",")
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().scaling_3d_scale = PilotRig.RENDER_SCALE
	print("[ships] %s, %s precision, %s on %s, window %s" % [Engine.get_version_info()["string"],
		"double" if OS.has_feature("double") else "single", RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size()])
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
	for kind_name in _kinds:
		_ship = _first_of(int(KINDS.get(kind_name, -1)))
		_check("there_is_a_%s_in_the_sky" % kind_name, _ship != null, "")
		if _ship == null:
			continue
		var geometry: Dictionary = Sim.geometry_of(_ship.kind)
		var half: Vector3 = geometry.get("extents", Vector3.ONE)
		# Near is the carrier's 500 m for a ship as long as a carrier, and a fixed multiple of the length for a boat.
		var near: float = maxf(half.z * 3.0, 40.0)
		var far: float = near * 6.0
		for fine in [false, true]:
			var finish_name: String = "fine" if fine else "plain"
			finish.call("choose", fine)
			_level.choose_time(DaylightTuning.When.DAY)
			for shot in _shots:
				if not _place(shot, geometry, near, far):
					continue
				if shot == "dusk":
					_level.choose_time(DaylightTuning.When.EVENING)
				await _frames(SETTLE)
				_save(get_viewport().get_texture().get_image(), "%s-%s-%s" % [kind_name, finish_name, shot])
				if shot in ["broadside_500", "broadside_3000"] and not fine:
					await _cost(kind_name, shot)
				if shot == "dusk":
					_level.choose_time(DaylightTuning.When.DAY)
	_finish()


## WHERE THE CAMERA GOES for a shot, in the ship's frame. False for a shot this ship does not have.
func _place(shot: String, geometry: Dictionary, near: float, far: float) -> bool:
	var half: Vector3 = geometry.get("extents", Vector3.ONE)
	var eye_up: float = half.y + maxf(half.z * 0.06, 2.0)
	_fov = 50.0
	match shot:
		"broadside_500", "dusk":
			_from_local = Vector3(near, eye_up, 0.0)
			_toward_local = Vector3(0.0, half.y * 0.5, 0.0)
		"bow_quarter_500":
			_from_local = Vector3(near * 0.6, eye_up, -near * 0.8)
			_toward_local = Vector3(0.0, half.y * 0.5, 0.0)
		"broadside_3000":
			_from_local = Vector3(far, eye_up * 2.0, 0.0)
			_toward_local = Vector3(0.0, half.y * 0.5, 0.0)
			_fov = 20.0
		"bow_quarter_3000":
			_from_local = Vector3(far * 0.6, eye_up * 2.0, -far * 0.8)
			_toward_local = Vector3(0.0, half.y * 0.5, 0.0)
			_fov = 20.0
		"overhead":
			# FROM SIXTY METRES ASTERN OF MIDSHIPS, looking at midships: straight down, the camera's yaw comes from whatever
			# horizontal remainder is left, and a degree of the ship's roll at 433 m is metres of it -- the first overhead
			# came out with the bow to the right. Leaning the eye aft puts the bow up the picture, as the fact-sheet line
			# drawing has it; aiming at a point forward instead did the same and cut the stern off the bottom of the frame.
			_from_local = Vector3(0.0, half.z * 2.6, 60.0)
			_toward_local = Vector3(0.0, 0.0, 0.0)
			_fov = 45.0
		"helm", "helm_down":
			# THE SEAT'S OWN EYE: seat 0's pose from the shape table plus the seated eye height, which is the point
			# tests/carrier_shape.gd holds inside the bridge -- so a picture from here is a picture from that point, and the
			# height it prints is the one that test measured. `helm_down` looks thirty degrees down over the bow, which is
			# what shows how far below the eye the deck is when a flat deck with no markings gives no scale of its own.
			var poses: Array = geometry.get("seat_poses", []) as Array
			if poses.is_empty():
				return false
			var seat: Vector3 = poses[0]["position"]
			_from_local = seat + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
			var down: float = 0.08 if shot == "helm" else tan(deg_to_rad(30.0))
			_toward_local = _from_local + Vector3(0.0, -down, -1.0) * 100.0
			_fov = 90.0
			print("[ships] %s eye at %s in the ship's frame: %.2f m above the deck, %.2f m above the waterline" % [shot,
				_from_local, _from_local.y - half.y, _from_local.y])
		_:
			return false
	return true


func _process(_delta: float) -> void:
	if _ship == null or _level == null or _level.observer == null or not is_instance_valid(_ship):
		return
	var eye: Camera3D = _level.observer
	eye.fov = _fov
	var pose: Transform3D = _ship.global_transform
	var at: Vector3 = pose * _from_local
	var toward: Vector3 = pose * _toward_local
	if eye.has_method("look_from"):
		eye.call("look_from", at, toward)
	else:
		eye.global_position = at
		eye.look_at(toward, Vector3.UP)


## WHAT THE SHIP ADDS TO A FRAME: draw calls and primitives with it shown, less the same with it hidden.
func _cost(kind_name: String, shot: String) -> void:
	var shown: Vector2i = await _counted()
	_ship.visible = false
	var hidden: Vector2i = await _counted()
	_ship.visible = true
	await _frames(2)
	print("[ships] cost %s at %s: %d draw calls, %d primitives (frame %d / %d shown, %d / %d hidden)" % [kind_name, shot,
		shown.x - hidden.x, shown.y - hidden.y, shown.x, shown.y, hidden.x, hidden.y])


func _counted() -> Vector2i:
	await _frames(4)
	return Vector2i(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))


func _first_of(kind: int) -> VehicleView:
	var best: int = 0
	for entity in Sim.current:
		if int((Sim.current[entity] as Dictionary).get("kind", -1)) != kind:
			continue
		if best == 0 or int(entity) < best:
			best = int(entity)
	return _level.view_of(best) if best != 0 else null


func _save(picture: Image, name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, picture.save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	_ship = null
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
