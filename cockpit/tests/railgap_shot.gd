extends Node
## THE MOUNTAINS BESIDE THE RAILWAY, PHOTOGRAPHED FROM THE SAME PLACES BEFORE AND AFTER a change to how near rock may come to it.
##
##   Godot --headless --path cockpit res://tests/railgap_shot.tscn -- --find
##   Godot --xr-mode off --desktop-only --path cockpit res://tests/railgap_shot.tscn -- --level=watch --at=<index> --tag=after
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device. `tests/mountains.gd` holds the distances; whether the
## ground beside the line reads as mountains near a railway or as a trench has no assertion and is what these pictures are for.
##
## `--find` prints the survey point with the closest drawn rock to it under the CURRENT keep-outs, and its direction. Note that
## index and use it for BOTH the before and the after run, so the two cameras stand in the same place; the ground beside the line
## is the only thing that differs. Both pictures stand beside the track at eye height and look at the nearest rock, and from
## above at the same point.
##
## Read RESULT=, not the exit code.

const WARM: int = 240
const SETTLE: int = 45
const EYE: float = 1.7
const OFF_LINE: float = 9.0
const ROCK_IS_ABOVE: float = 5.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _fov: float = 70.0
var _aiming: bool = false


func _check(label: String, ok: bool, detail: String) -> void:
	print("[railgap_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## THE NEAREST ROCK TO A SURVEY POINT: its distance and the point itself, over 16 bearings in 4 m steps.
static func _nearest_rock(rock: Object, at: Vector3) -> Dictionary:
	var best: float = INF
	var where := Vector3.ZERO
	for a in range(16):
		var dir := Vector2.from_angle(TAU * float(a) / 16.0)
		var d: float = 0.0
		while d < 700.0 and d < best:
			if float(rock.call("surface_at", at.x + dir.x * d, at.z + dir.y * d)) > at.y + ROCK_IS_ABOVE:
				best = d
				where = Vector3(at.x + dir.x * d, 0.0, at.z + dir.y * d)
				break
			d += 4.0
	return {"distance": best, "where": where}


func _ready() -> void:
	var out: String = ""
	var tag: String = "shot"
	var at: int = -1
	var find: bool = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		if argument.begins_with("--tag="):
			tag = argument.trim_prefix("--tag=")
		if argument.begins_with("--at="):
			at = argument.trim_prefix("--at=").to_int()
		if argument == "--find":
			find = true
	var points: Array[Vector3] = Terrain.rail_points()
	if find:
		var rock: Object = Terrain.mountains()
		var best_index: int = -1
		var best: float = INF
		for i in range(points.size()):
			var near: Dictionary = _nearest_rock(rock, points[i])
			if float(near["distance"]) < best:
				best = float(near["distance"])
				best_index = i
		var found: Dictionary = _nearest_rock(rock, points[best_index])
		print("[railgap_shot] FOUND index %d at %v, rock %.0f m away at %v" % [best_index, points[best_index], best, found["where"]])
		_finish()
		return
	if out == "":
		var repo: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		out = repo.path_join("screenshots").path_join(Time.get_date_string_from_system())
	if DisplayServer.get_name() == "headless" or at < 0:
		_check("it_is_rendering_at_a_point", false, "run it windowed with --at=<index> (see --find)")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(out)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	var waited: int = 0
	while Sim.current.is_empty() and waited < 6000:
		await _frames(1)
		waited += 1
	await _frames(WARM)
	_level.choose_time(DaylightTuning.When.DAY)
	var words: Node = _level.get_node_or_null("Ui")
	if words != null:
		words.set("visible", false)
	var board := _level.observer.get("_board") as CanvasItem
	if board != null:
		board.visible = false
	RenderingServer.frame_pre_draw.connect(_aim)
	var point: Vector3 = points[at]
	var near: Dictionary = _nearest_rock(Terrain.mountains(), point)
	_check("there_is_rock_to_look_at", float(near["distance"]) < INF, "%.0f m" % float(near["distance"]))
	var toward: Vector3 = (near["where"] as Vector3) - Vector3(point.x, 0.0, point.z)
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.RIGHT
	# AT THE ROCK'S OWN SLOPE 150 m BEYOND ITS NEAREST POINT, where the ground has risen, and not at the sky over it.
	var beyond: Vector3 = (near["where"] as Vector3) + toward * 150.0
	var peak: Vector3 = beyond + Vector3.UP * float(Terrain.mountains().call("surface_at", beyond.x, beyond.z))
	# 1. BESIDE THE TRACK at eye height on the side away from the rock, looking across the line at the nearest rock.
	_place(point - toward * OFF_LINE + Vector3.UP * EYE, peak, 70.0)
	await _shoot(out, "01-trackside", tag, point)
	# 2. FROM ABOVE: 700 m up and 400 m back from the line on the side away from the rock, looking down at the point.
	_place(point - toward * 400.0 + Vector3.UP * 700.0, point + toward * 200.0, 60.0)
	await _shoot(out, "02-from-above", tag, point)
	_finish()


func _place(from: Vector3, to: Vector3, fov: float) -> void:
	_from = from
	_to = to
	_fov = fov
	_aiming = true


func _aim() -> void:
	if not _aiming or _level == null or _level.observer == null:
		return
	_level.observer.fov = _fov
	_level.observer.look_from(_from, _to)


func _shoot(out: String, what: String, tag: String, point: Vector3) -> void:
	await _frames(SETTLE)
	var drew: Camera3D = get_viewport().get_camera_3d()
	_check("%s_was_drawn_with_the_observer" % what, drew == _level.observer, "%s" % [drew.name if drew != null else "no camera"])
	var path: String = out.path_join("cockpit-railgap-%s-%s.png" % [what, tag])
	var saved: bool = get_viewport().get_texture().get_image().save_png(path) == OK
	_check("%s_is_saved" % what, saved, "%s at %v" % [path, point])
	_aiming = false


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	print("RESULT=%s" % ["PASS" if _failures.is_empty() else "FAIL"])
	if not _failures.is_empty():
		print("[railgap_shot] failed: %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
