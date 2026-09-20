extends Node
## THE AIR BASE, LOOKED AT: from the air, straight down at a stated scale, from the tower cab, along the hangars and
## the revetments, and down the parallel taxiway from a taxiing fighter's eye.
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/airbase_shot.tscn -- --level=watch --clouds=none --out=C:/somewhere [--shots=air,top]
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). Whether the pavement reads
## as a base, the paint as paint and the hangars as hangars is for eyes; where everything is, and that it keeps its
## clearances, is held by tests/airbase.gd.
##
## THE TOP-DOWN SHOT IS ORTHOGRAPHIC at TOP_METRES across the picture's height, centred on the base's own hull, and its
## scale in metres a pixel is printed and written into its file name, so a picture can be laid against a chart.
##
## Pictures in `--out`: `airbase-<shot>.png`.

const SETTLE: int = 90
## How much ground the top-down shot shows across its height, metres.
const TOP_METRES: float = 1100.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://airbase_shot"
var _shots: PackedStringArray = ["air", "top"]


func _check(label: String, ok: bool, detail: String) -> void:
	print("[airbase_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=").split(",")
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
	var bases: Array[Dictionary] = AirbasePlan.bases()
	_check("there_is_a_base_on_this_world", not bases.is_empty(), "%d laid" % bases.size())
	if bases.is_empty():
		_finish()
		return
	var base: Dictionary = bases[0]
	var frame: Dictionary = base["frame"]
	var hull: AABB = _hull(base)
	var middle: Vector3 = hull.get_center()
	for shot in _shots:
		var camera: Camera3D = _level.observer
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 55.0
		match shot:
			"air":
				# From beyond the threshold end, off to the base's side and up, looking at its middle.
				var from: Vector3 = (frame["threshold"] as Vector3) - (frame["along"] as Vector3) * 500.0 \
					+ (frame["across"] as Vector3) * 900.0 + Vector3.UP * 420.0
				camera.look_from(from, middle)
				await _frames(SETTLE)
				_save("airbase-air")
			"hangars":
				# From over the ramp taxilane, off to one side, looking at the three hangars' doors.
				camera.look_from(_frame_at(frame, -170.0, 360.0, 35.0), _frame_at(frame, 0.0, 525.0, 6.0))
				await _frames(SETTLE)
				_save("airbase-hangars")
			"revetments":
				# From beyond the north block's end, low, looking along its bays.
				camera.look_from(_frame_at(frame, 300.0, 380.0, 18.0), _frame_at(frame, 170.0, 432.0, 1.0))
				await _frames(SETTLE)
				_save("airbase-revetments")
			"tower", "tower_back":
				# FROM THE TOWER CAB: seat 0's eye, or seat 1's for `tower_back`, off the spawn the level stood the tower
				# up from, looking where that seat faces and down a little, as wide as a person's view.
				var tower: Dictionary = {}
				for spawn in Terrain.spawns():
					if int(spawn["kind"]) == Sim.Kind.TOWER:
						tower = spawn
				var pose: Dictionary = Sim.geometry_of(Sim.Kind.TOWER)["seat_poses"][0 if shot == "tower" else 1]
				var turn := Basis(Vector3.UP, float(tower["yaw"]) + float(pose["yaw"]))
				var eye: Vector3 = (tower["position"] as Vector3) + Basis(Vector3.UP, float(tower["yaw"])) 					* (pose["position"] as Vector3) + Vector3.UP * CockpitStation.EYE_HEIGHT
				camera.fov = 80.0
				camera.look_from(eye, eye + turn * Vector3(0.0, -0.12, -1.0) * 100.0)
				await _frames(SETTLE)
				_save("airbase-%s" % shot.replace("_", "-"))
			"taxiway":
				# DOWN THE PARALLEL TAXIWAY FROM A COCKPIT'S EYE, which is the question the user asked -- can a plane
				# drive around to get to the runway. From over stub a's hold bar, at a seated fighter pilot's height
				# off the shape table, looking back up the taxiway the way it came. tests/airbase_taxi.gd drives it.
				var hold: Vector3 = (base["nodes"]["a.hold"] as Dictionary)["position"]
				var junction: Vector3 = (base["nodes"]["parallel/south_link"] as Dictionary)["position"]
				var seat_high: float = (Sim.geometry_of(Sim.Kind.FIGHTER).get("extents", Vector3.ONE) as Vector3).y 					+ CockpitStation.EYE_HEIGHT
				camera.fov = 70.0
				camera.look_from(hold + Vector3.UP * seat_high, junction + Vector3.UP * seat_high)
				await _frames(SETTLE)
				_save("airbase-taxiway")
			"tower_outside":
				# THE TOWER FROM THE GROUND NEARBY, because a controller sitting in it cannot see what it looks like.
				var stood: Dictionary = {}
				for spawn in Terrain.spawns():
					if int(spawn["kind"]) == Sim.Kind.TOWER:
						stood = spawn
				var at: Vector3 = stood["position"]
				camera.look_from(at + Vector3(90.0, 26.0, 90.0), at + Vector3.UP * 12.0)
				await _frames(SETTLE)
				_save("airbase-tower-outside")
			"bay":
				# ONE REVETMENT BAY, CLOSE, mouth on: the floor, the walls and the earth on top of them.
				var bay: Vector3 = (base["spots"]["north.1"] as Dictionary)["position"]
				camera.look_from(bay + (frame["across"] as Vector3) * -40.0 + Vector3.UP * 12.0, bay + Vector3.UP * 2.0)
				await _frames(SETTLE)
				_save("airbase-bay")
			"top":
				camera.projection = Camera3D.PROJECTION_ORTHOGONAL
				camera.size = TOP_METRES
				camera.far = 4000.0
				camera.look_from(middle + Vector3.UP * 1500.0, middle + Vector3(0.0, 0.0, -0.001))
				await _frames(SETTLE)
				var metres_a_pixel: float = TOP_METRES / float(get_viewport().get_visible_rect().size.y)
				print("[airbase_shot] top: %.3f m a pixel, centred on (%.0f, %.0f), north up" % [metres_a_pixel, middle.x,
					middle.z])
				_save("airbase-top-%.2fm-per-px" % metres_a_pixel)
	_finish()


## A point of a base's frame, `up` metres over the runway's level.
func _frame_at(frame: Dictionary, along: float, across: float, up: float) -> Vector3:
	return AirbasePlan.frame_point(frame, along, across) + Vector3.UP * up


## The hull of everything a base laid on the ground and stood up.
func _hull(base: Dictionary) -> AABB:
	var hull := AABB(base["frame"]["centre"], Vector3.ZERO)
	for piece in (base["pavement"] as Array) + (base["boxes"] as Array):
		var half: Vector3 = piece["half_extents"]
		hull = hull.merge(AABB((piece["position"] as Vector3) - half, half * 2.0))
	return hull


func _save(name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
