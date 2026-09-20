extends Node
## A RUNWAY SEEN THROUGH A MOUNTAIN, FOUND AND PHOTOGRAPHED: the user's "landing strips visible THROUGH the mountains".
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/seethrough_shot.tscn -- --level=watch
##       --out=C:/somewhere [--height=400] [--pick=N,N,...] [--overlay=top|world] [--list]
##
## A PROBE: it renders (headless has no rendering device). NEVER a capture of the desktop; every picture is the viewport's own.
##
## WHAT IT DOES. For every runway the world has (`Terrain.runways()`), it walks a ring of eyes round it at each of
## `RANGES_M` and asks `Terrain.ground_height` -- the rock's own triangles -- along the line from the eye to the runway's
## middle. An eye whose line goes through rock has the runway BEHIND a mountain: whatever the picture shows of the runway
## from there is seen through it. It prints each such eye, and stands the camera at the first `--pick` (default 0) and looks
## at the runway's middle. `--list` prints and quits.
##
## `--overlay=top|world` lays every runway's outline over the island the way `pattern_shot` draws the strip it flies to, with
## ITS OWN materials (`PatternShot._flat`): `top` is the drawing the user saw on the P-51 trip, no depth test, the outline
## showing through every ridge between it and the eye; `world` is what the chase scenes draw now, tested against the depth
## buffer. The same eye, the same frame, the two pictures are the before and the after. The game's own runway needs no
## overlay: seen from these eyes it is behind the rock, as it should be.

const RANGES_M: Array[float] = [2000.0, 5000.0, 10000.0, 20000.0, 30000.0]
const BEARINGS: int = 24
const STEP_M: float = 40.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://seethrough_shot"
var _height: float = 400.0
var _picks: PackedInt32Array = [0]
var _list: bool = false
var _overlay: String = ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--height="):
			_height = argument.trim_prefix("--height=").to_float()
		elif argument.begins_with("--pick="):
			_picks = []
			for word in argument.trim_prefix("--pick=").split(","):
				_picks.append(word.to_int())
		elif argument.begins_with("--overlay="):
			_overlay = argument.trim_prefix("--overlay=")
		elif argument == "--list":
			_list = true
	if not _list and DisplayServer.get_name() == "headless":
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
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false
	var eyes: Array[Dictionary] = _hidden_runways()
	_check("some_runway_stands_behind_rock", not eyes.is_empty(), "%d eyes" % eyes.size())
	if _list or eyes.is_empty():
		_finish()
		return
	if _overlay != "":
		_draw_the_runways("one" if _overlay == "top" else "trip")
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 60.0
	camera.far = 60000.0
	for pick in _picks:
		var eye: Dictionary = eyes[clampi(pick, 0, eyes.size() - 1)]
		camera.look_from(eye["from"], eye["at"])
		await _frames(90)
		print("[seethrough_shot] stood at %s looking at %s (runway %d, %.0f m out, %.0f m of rock on the line)" % [eye["from"],
			eye["at"], eye["runway"], eye["range"], eye["rock"]])
		_save("seethrough-%s-%d-%dm" % [_overlay if _overlay != "" else "none", pick, int(eye["range"])])
	_finish()


## EVERY RUNWAY'S OUTLINE, three metres over its own middle, forty metres wide so it reads from kilometres out, in
## `pattern_shot`'s own ribbon and material, as its `scene` ("trip", the chase, or any other, straight down) draws them.
func _draw_the_runways(scene: String) -> void:
	var shot: GDScript = load("res://tests/pattern_shot.gd")
	var paint: StandardMaterial3D = shot.call("_flat", Color(1.0, 0.9, 0.3), shot.call("draws_on_top", scene))
	for frame in Terrain.runways():
		var half_l: Vector3 = (frame["along"] as Vector3) * float(frame["length"]) * 0.5
		var half_w: Vector3 = (frame["across"] as Vector3) * float(frame["width"]) * 0.5
		var c: Vector3 = (frame["centre"] as Vector3) + Vector3.UP * 3.0
		var mesh := ImmediateMesh.new()
		shot.call("_ribbon_into", mesh, PackedVector3Array([c - half_l - half_w, c + half_l - half_w, c + half_l + half_w,
			c - half_l + half_w, c - half_l - half_w]), 40.0)
		var drawn := MeshInstance3D.new()
		drawn.mesh = mesh
		drawn.material_override = paint
		add_child(drawn)


## EVERY EYE ON THE RINGS WHOSE LINE TO A RUNWAY'S MIDDLE PASSES THROUGH ROCK, nearest ring first.
func _hidden_runways() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var runways: Array[Dictionary] = Terrain.runways()
	for r in range(runways.size()):
		var middle: Vector3 = runways[r]["centre"]
		for reach in RANGES_M:
			for b in range(BEARINGS):
				var angle: float = TAU * float(b) / float(BEARINGS)
				var from := Vector3(middle.x + cos(angle) * reach, _height, middle.z + sin(angle) * reach)
				var rock: float = _rock_on_line(from, middle + Vector3.UP * 2.0)
				if rock > 0.0:
					out.append({"runway": r, "range": reach, "from": from, "at": middle, "rock": rock})
					print("[seethrough_shot] eye %d: runway %d at %s, %.0f m out, bearing %d, %.0f m of rock" % [out.size() - 1,
						r, middle, reach, b * 360 / BEARINGS, rock])
	return out


## METRES OF THE LINE FROM `a` TO `b` THAT LIE BELOW THE ROCK.
func _rock_on_line(a: Vector3, b: Vector3) -> float:
	var length: float = a.distance_to(b)
	var inside: float = 0.0
	var steps: int = int(length / STEP_M)
	for i in range(1, steps):
		var p: Vector3 = a.lerp(b, float(i) / float(steps))
		var mountains: Object = Terrain.mountains()
		if mountains != null and float(mountains.call("surface_at", p.x, p.z)) > p.y:
			inside += STEP_M
	return inside


func _save(name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	print("[seethrough_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
