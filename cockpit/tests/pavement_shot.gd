extends Node
## THE RUNWAY'S SURFACE, LOOKED AT, from the four distances it is actually seen from -- and on the strip 8 km out as
## well as the one at the origin, because that is where a distance shader goes wrong on a double build.
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/pavement_shot.tscn -- --level=watch
##       --clouds=none --out=C:/somewhere
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). What can be checked
## without eyes is `tests/pavement.gd`'s; almost the whole of this feature cannot be, which is why this exists.
## NEVER A CAPTURE OF THE DESKTOP: every picture is the viewport's own image.
##
## THREE TREATMENTS AT EVERY POSE, so the comparison is honest -- same camera, same sun, same frame count:
##
## - `was`: the bare StandardMaterial3D the runway wore before this lane, reproduced here. It is three lines and they
##   are the three lines the commit removed; keeping them means the "before" is the real before rather than a
##   screenshot from yesterday under a different sky.
## - `plain` and `fine`: the two pavement shaders, chosen the way the game chooses them, through `Finish`.
##
## FOUR POSES, IN THE RUNWAY'S OWN FRAME, because they are the four distances the two fade bands were sized for: on
## the roll in the touchdown zone, at the threshold, on short final, and from the downwind leg. If the transition is
## wrong it is wrong BETWEEN two of these, so they are deliberately not evenly spaced -- they are where a pilot is.
##
## THE TWO DISTANT POSES USE A LONGER LENS, and that is not cheating: at a true 50-degree field a 45 m runway seen
## from 900 m is seventy pixels wide and the picture shows nothing about a surface either way. The lens is part of the
## pose, so the three treatments at a pose share it exactly and the comparison is still one-thing-at-a-time. The first
## run of this probe framed `final` at 900 m and proved only that the probe was pointed wrongly.
##
## AND TWO RUNWAYS. The island's own strip is 1.3 km from the origin; the generated world's others are 7 to 9 km out,
## which is where float32 gives up and where a shader that had reached for the camera's world position would put the
## detail in the wrong place or everywhere at once. Same poses, same names, `far-` in front.

## WHERE THE CAMERA STANDS AND WHAT IT LOOKS AT, in the runway's frame: metres along from the THRESHOLD (positive is
## up the strip), metres across from the centreline, and height. `at_along` is what it looks at, on the centreline.
const POSES: Array[Dictionary] = [
	{"name": "roll", "along": 120.0, "across": 0.0, "up": 1.6, "at_along": 900.0, "fov": 60.0},
	{"name": "threshold", "along": -90.0, "across": 0.0, "up": 14.0, "at_along": 420.0, "fov": 55.0},
	{"name": "final", "along": -260.0, "across": 0.0, "up": 55.0, "at_along": 300.0, "fov": 55.0},
	{"name": "downwind", "along": 250.0, "across": -760.0, "up": 210.0, "at_along": 300.0, "fov": 26.0},
	# STRAIGHT DOWN OVER THE TOUCHDOWN ZONE, orthographic, this many metres of ground across the frame. The clearest
	# single piece of evidence there is for the rubber and the paving lanes, because it removes perspective, the mist
	# and the sky from the question and leaves the surface on its own.
	{"name": "plan", "along": 250.0, "across": 0.0, "up": 400.0, "at_along": 250.0, "ortho": 260.0},
]

var _out: String = "user://pavement_shot"
var _level: FlightLevel = null
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[pavement_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
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
	# NOTHING WRITTEN OVER THE PICTURE: the banner and the observer's boards would sit across the very surface this is
	# a picture of.
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false
	var runway := _level.get_node_or_null("Runway") as MultiMeshInstance3D
	if runway == null:
		_check("the_level_drew_a_runway", false, "no Runway node")
		_finish()
		return
	var frames: Array[Dictionary] = Terrain.runways()
	_check("there_are_runways_to_stand_on", not frames.is_empty(), "%d" % frames.size())
	if frames.is_empty():
		_finish()
		return
	await _shoot("near", frames[0], runway)
	# THE FURTHEST STRIP FROM THE ORIGIN, whichever it is, so this keeps testing the far case if the world changes.
	var far: Dictionary = frames[0]
	for frame in frames:
		if (frame["centre"] as Vector3).length() > (far["centre"] as Vector3).length():
			far = frame
	await _shoot_the_concrete()
	if far != frames[0]:
		print("[pavement_shot] the far strip is %.0f m from the origin" % (far["centre"] as Vector3).length())
		await _shoot("far", far, runway)
	else:
		_check("there_is_a_strip_far_from_the_origin", false, "every runway is the island's")
	_finish()


## THE AIR BASE'S CONCRETE, which is the other pavement: slabs in a grid rather than lanes, no rubber, and its colour
## converted from sRGB where the runway's is not. Three treatments at one pose, plus a plan straight down over an
## apron where the bay grid reads clearest.
##
## THE EXITS LIE AT 30 DEGREES to everything else (`AirbaseView._boxes`) and the slab grid is laid to the WORLD, not
## to each piece, so a joint crosses an exit at an angle. That is deliberate -- a site grid is what real airfield
## concrete is poured to, and a per-piece grid would break phase between two pieces of the same taxiway -- but it is
## the thing to look at in these pictures and change if it reads wrongly.
func _shoot_the_concrete() -> void:
	var bases: Node = _level.get_node_or_null("Airbases")
	if bases == null or bases.get_child_count() == 0:
		_check("there_is_an_air_base_to_look_at", false, "no Airbases")
		return
	var base: Node3D = bases.get_child(0) as Node3D
	var at: Vector3 = base.position
	var camera: Camera3D = _level.observer
	var finish: Node = get_node_or_null("/root/Finish")
	var was_fine: bool = finish != null and bool(finish.call("is_fine"))
	var ground := base.get_node_or_null("Ground") as GeometryInstance3D
	if ground == null:
		_check("the_base_drew_its_ground", false, "no Ground")
		return
	var worn: Material = ground.material_override
	var was := StandardMaterial3D.new()
	was.vertex_color_use_as_albedo = true
	was.vertex_color_is_srgb = true
	was.roughness = 0.92
	for pose in ["stand", "plan"]:
		for treatment in ["was", "plain", "fine"]:
			if treatment == "was":
				ground.material_override = was
			else:
				ground.material_override = worn
				if finish != null:
					finish.call("choose", treatment == "fine")
			if pose == "stand":
				camera.projection = Camera3D.PROJECTION_PERSPECTIVE
				camera.fov = 62.0
				camera.far = 30000.0
				camera.look_from(at + Vector3(70.0, 6.0, 70.0), at + Vector3(0.0, 1.0, 0.0))
			else:
				camera.projection = Camera3D.PROJECTION_ORTHOGONAL
				camera.size = 150.0
				camera.far = 30000.0
				camera.look_from(at + Vector3.UP * 300.0, at + Vector3(0.001, -100.0, 0.0))
			await _frames(45)
			_save("pavement-concrete-%s-%s" % [pose, treatment])
	if finish != null:
		finish.call("choose", was_fine)
	ground.material_override = worn


## EVERY POSE ON ONE RUNWAY, IN EVERY TREATMENT. The treatment is changed and the pose is not, so each trio of files
## differs by exactly one thing.
func _shoot(where: String, frame: Dictionary, runway: MultiMeshInstance3D) -> void:
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.far = 30000.0
	var finish: Node = get_node_or_null("/root/Finish")
	var was_fine: bool = finish != null and bool(finish.call("is_fine"))
	# The bare material the runway wore before this lane: see the doc block.
	var was := StandardMaterial3D.new()
	was.vertex_color_use_as_albedo = true
	was.roughness = 0.92
	var worn: ShaderMaterial = runway.material_override as ShaderMaterial
	for pose in POSES:
		_stand(camera, frame, pose)
		for treatment in ["was", "plain", "fine"]:
			if treatment == "was":
				runway.material_override = was
			else:
				runway.material_override = worn
				if finish != null:
					finish.call("choose", treatment == "fine")
			# LONG ENOUGH FOR THE SHADER TO HAVE COMPILED AND THE SUN TO HAVE SETTLED. A picture taken on the frame a
			# material changed is a picture of the fallback shader.
			await _frames(45)
			_save("pavement-%s-%s-%s" % [where, pose["name"], treatment])
	if finish != null:
		finish.call("choose", was_fine)
	runway.material_override = worn


## THE CAMERA, IN THE RUNWAY'S FRAME. Off `frame`, so a pose is the same pose on every strip whatever its bearing and
## wherever in the world it is -- which is the whole point of shooting the far one.
func _stand(camera: Camera3D, frame: Dictionary, pose: Dictionary) -> void:
	var threshold: Vector3 = frame["threshold"]
	var along: Vector3 = frame["along"]
	var across: Vector3 = frame["across"]
	var from: Vector3 = threshold + along * float(pose["along"]) + across * float(pose["across"]) \
		+ Vector3.UP * float(pose["up"])
	var at: Vector3 = threshold + along * float(pose["at_along"])
	if pose.has("ortho"):
		# STRAIGHT DOWN. The aim point is nudged off the camera's own column because a look-at along exactly -Y has no
		# unique up vector and the basis comes out unusable.
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = float(pose["ortho"])
		camera.look_from(from, Vector3(from.x, from.y - 100.0, from.z) + along * 0.001)
		return
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = float(pose["fov"])
	camera.look_from(from, at)


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
	get_tree().quit(0 if _failures.is_empty() else 1)
