extends Node
## THE CESSNA 310R'S PICTURES, in a viewport of this game's own. Read RESULT=.
##
##   Godot --headless --xr-mode off --path cockpit res://tests/twin310_shot.tscn -- --out=<folder>
##
## Five pictures, and each one answers a question a suite cannot:
##   `side`, `front`, `top`   -- orthographic, at a stated pixels-a-metre, on white with a
##                               shadowless fill, so they can be laid over the factory three-view.
##   `quarter`                -- the aeroplane as a player meets it.
##   `gear`                   -- the legs down, halfway and up, in one strip.
##   `lineup`                 -- beside a Cessna 172S and a Boeing 737-800W, because SCALE IS THE
##                               THING A PICTURE OF ONE AEROPLANE CANNOT SHOW.
##
## THE TRAPS THIS SCRIPT IS BUILT ROUND, all of them from `modelling_here.md` section 7:
##   * A `SubViewport` does not get its own `World3D` unless asked, and without it every stage
##     shares one world and the aeroplanes stand in each other's pictures.
##   * `AMBIENT_SOURCE_COLOR` reads `ambient_light_color`, which defaults to BLACK, so setting
##     energy alone lights nothing and the first three-quarter came back with a black fuselage
##     beside a lit wing.
##   * An elevation meant to be laid beside a drawing gets a SHADOWLESS fill along the camera's own
##     line of sight; the sun lights one face and a drawing lights all of them.
##   * **Assert what is IN the frame, not that `save_png` returned OK.** Every picture here projects
##     the aeroplane's own drawn corners and requires it to cover a share of the frame.
##   * **Stamp it.** A gallery goes stale and nothing in it says so, so every filename carries the
##     commit and whether the tree was dirty.

const WIDE := 1600
const TALL := 900
const PX_PER_METRE := 110.0   # so an 11.25 m span is 1,238 px and fits WIDE with a margin

var _failures: PackedStringArray = []
var _out: String = "user://twin310"
var _stamp: String = ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_stamp = _commit()
	print("[twin310_shot] writing to %s, stamped %s" % [_out, _stamp])
	await get_tree().process_frame
	await _elevations()
	await _quarter()
	await _gear_strip()
	await _lineup()
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	print("[twin310_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## `<short commit>[+dirty]`, so a picture says what code it is of. The `+dirty` matters as much as
## the hash: it says the picture is of code nobody else has.
func _commit() -> String:
	var lines: Array = []
	var project: String = ProjectSettings.globalize_path("res://")
	OS.execute("git", ["-C", project, "rev-parse", "--short", "HEAD"], lines)
	var hash: String = String(lines[0]).strip_edges() if not lines.is_empty() else "unknown"
	lines = []
	OS.execute("git", ["-C", project, "status", "--porcelain"], lines)
	var dirty: bool = not lines.is_empty() and not String(lines[0]).strip_edges().is_empty()
	return hash + ("+dirty" if dirty else "")


## ---- the stage --------------------------------------------------------------------------------

func _stage(background: Color, sunless: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(WIDE, TALL)
	# ITS OWN WORLD, or four stages put four aeroplanes in one scene (`lane/prowler`).
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	BuildStamp.attach_to(viewport)
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = background
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# AND ITS COLOUR, which defaults to black however much energy it is given.
	world.ambient_light_color = Color(1.0, 1.0, 1.0)
	world.ambient_light_energy = 0.65 if sunless else 0.35
	environment.environment = world
	viewport.add_child(environment)
	var camera := Camera3D.new()
	camera.current = true
	viewport.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.15 if sunless else 1.25
	sun.shadow_enabled = not sunless
	sun.rotation_degrees = Vector3(-38.0, -125.0, 0.0)
	viewport.add_child(sun)
	return {"viewport": viewport, "camera": camera, "sun": sun}


func _aeroplane(stage: Dictionary, scene: String) -> Node3D:
	var node := (load(scene) as PackedScene).instantiate() as Node3D
	(stage["viewport"] as SubViewport).add_child(node)
	if node.get_child_count() == 0 and node.has_method("_build"):
		node.call("_build")
	return node


## Every drawn vertex of a subtree, in the world.
func _points(root: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh == null or drawn.name.begins_with("PropellerDisc"):
			continue
		for surface in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(surface)
			for point in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				out.append(drawn.global_transform * point)
	return out


func _box_of(root: Node3D) -> AABB:
	var box := AABB()
	var found := false
	for point in _points(root):
		box = box.expand(point) if found else AABB(point, Vector3.ZERO)
		found = true
	return box


## SAVE IT, AND THEN ASSERT WHAT IS IN IT. A camera that drew the wrong thing still returns OK from
## `save_png`, which is how nine pictures of a desk were filed under RESULT=PASS (`lane/hangar`).
func _shoot(stage: Dictionary, subject: Node3D, label: String, least_share: float) -> void:
	var viewport: SubViewport = stage["viewport"]
	var camera: Camera3D = stage["camera"]
	# The viewport must have drawn with OUR camera, which `camera.is_current()` cannot tell us --
	# it asks the thing under test. Ask the viewport.
	for attempt in range(6):
		camera.current = true
		await RenderingServer.frame_post_draw
		if viewport.get_camera_3d() == camera:
			break
	var drew: bool = viewport.get_camera_3d() == camera
	var covered := Rect2()
	var started := false
	for point in _points(subject):
		var at: Vector2 = camera.unproject_position(point)
		covered = covered.expand(at) if started else Rect2(at, Vector2.ZERO)
		started = true
	var share: float = (covered.size.x * covered.size.y) / float(WIDE * TALL)
	var path: String = "%s/cockpit-twin310-%s-%s.png" % [_out, label, _stamp]
	var image := viewport.get_texture().get_image()
	var saved: int = image.save_png(path)
	_check("the_%s_picture_holds_the_aeroplane" % label,
		saved == OK and drew and share >= least_share and covered.position.x > -40.0
			and covered.end.x < WIDE + 40.0,
		"%s, our camera %s, the aeroplane covers %.0f%% of the frame in %s"
		% [path.get_file(), drew, share * 100.0, covered])


## ---- the five pictures ------------------------------------------------------------------------

## THE THREE ELEVATIONS, orthographic, at a stated scale, on white with no shadow: these are the
## ones that get laid over the factory drawing, and a reader can dispute them.
func _elevations() -> void:
	for view in [["side", Vector3(1.0, 0.0, 0.0), Vector3.UP],
			["front", Vector3(0.0, 0.0, -1.0), Vector3.UP],
			["top", Vector3(0.0, -1.0, 0.0), Vector3(0.0, 0.0, -1.0)]]:
		var stage := _stage(Color(1.0, 1.0, 1.0), true)
		var plane := _aeroplane(stage, "res://objects/vehicles/cessna310_airframe.tscn")
		var box := _box_of(plane)
		var camera: Camera3D = stage["camera"]
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		# FIT THE SUBJECT, then say what scale that came out at. A fixed pixels-a-metre chosen by
		# hand clipped the top view's nose and tail off the frame and the check still passed,
		# because a clipped aeroplane still covers most of a frame.
		var fit: float = maxf(box.size.y, box.size.x * float(TALL) / float(WIDE))
		if String(view[0]) == "top":
			fit = maxf(box.size.z, box.size.x * float(TALL) / float(WIDE))
		camera.size = fit * 1.12
		print("[twin310_shot] %s at %.1f px a metre" % [view[0], float(TALL) / camera.size])
		camera.near = 0.05
		camera.far = 200.0
		var eye: Vector3 = box.get_center() - (view[1] as Vector3) * 40.0
		camera.position = eye
		camera.look_at(box.get_center(), view[2])
		# THE FILL RUNS DOWN THE CAMERA'S OWN LINE OF SIGHT, so an elevation has no shaded face.
		(stage["sun"] as DirectionalLight3D).rotation = camera.rotation
		await _shoot(stage, plane, String(view[0]), 0.10)
		(stage["viewport"] as SubViewport).queue_free()
		await get_tree().process_frame


func _quarter() -> void:
	var stage := _stage(Color(0.42, 0.52, 0.62), false)
	var plane := _aeroplane(stage, "res://objects/vehicles/cessna310_airframe.tscn")
	var ground := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(60.0, 0.2, 60.0)
	ground.mesh = slab
	ground.position = Vector3(0.0, _box_of(plane).position.y - 0.10, 0.0)
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.30, 0.34, 0.26)
	ground.material_override = grass
	(stage["viewport"] as SubViewport).add_child(ground)
	var box := _box_of(plane)
	var camera: Camera3D = stage["camera"]
	camera.fov = 32.0
	camera.position = box.get_center() + Vector3(-9.5, 3.4, -13.0)
	camera.look_at(box.get_center() + Vector3(0.0, -0.3, 0.0), Vector3.UP)
	await _shoot(stage, plane, "quarter", 0.12)
	(stage["viewport"] as SubViewport).queue_free()
	await get_tree().process_frame


## THE GEAR, down, halfway and up, side on. Three aeroplanes rather than three pictures, so the
## strip is one frame and nothing can drift between them.
func _gear_strip() -> void:
	var stage := _stage(Color(1.0, 1.0, 1.0), true)
	var subject: Node3D = null
	var all := Node3D.new()
	(stage["viewport"] as SubViewport).add_child(all)
	var at: float = -13.0
	# DOWN, HALF, UP, READING LEFT TO RIGHT. The camera stands off +x and looks back, so +z is on
	# the LEFT of the frame -- and the first strip read up, half, down, which is a gear cycle
	# backwards and looks exactly like a gear cycle forwards to anyone who does not check.
	for amount in [0.0, 0.5, 1.0]:
		var plane := (load("res://objects/vehicles/cessna310_airframe.tscn") as PackedScene).instantiate() as Node3D
		all.add_child(plane)
		if plane.get_child_count() == 0 and plane.has_method("_build"):
			plane.call("_build")
		plane.call("set_gear", amount)
		plane.position = Vector3(0.0, 0.0, at)
		at += 13.0
		if subject == null:
			subject = plane
	var box := _box_of(all)
	var camera: Camera3D = stage["camera"]
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(box.size.y, box.size.z * float(TALL) / float(WIDE)) * 1.10
	camera.position = box.get_center() + Vector3(60.0, 0.0, 0.0)
	camera.look_at(box.get_center(), Vector3.UP)
	(stage["sun"] as DirectionalLight3D).rotation = camera.rotation
	await _shoot(stage, all, "gear", 0.10)
	(stage["viewport"] as SubViewport).queue_free()
	await get_tree().process_frame


## THE SCALE LINE-UP. A picture of one aeroplane says nothing about how big it is, so the 310R
## stands between the Cessna 172S it is twice the weight of and the 737-800W it is a tenth of.
func _lineup() -> void:
	var stage := _stage(Color(1.0, 1.0, 1.0), true)
	var all := Node3D.new()
	(stage["viewport"] as SubViewport).add_child(all)
	var placed: int = 0
	# THE LINE-UP IS OF THE GAME'S OWN CRAFT, not of bare airframe scenes. `Boeing737Airframe` is a
	# measured TABLE that `JetlinerAirframe` draws from and has no scene of its own; instantiating
	# the class put drawn vertices in the frame's bounding box -- so the camera pulled back to
	# include it and the check counted "3 placed" -- while NOTHING of it rendered. The picture was
	# two small aeroplanes in the left half and an empty right half, under RESULT=PASS. A count is
	# not a picture (`modelling_here.md` section 7).
	for entry in [["res://objects/vehicles/craft_cessna.tscn", -30.0],
			["res://objects/vehicles/craft_plane.tscn", -17.0],
			["res://objects/vehicles/craft_airliner.tscn", 16.0]]:
		if not ResourceLoader.exists(String(entry[0]), "PackedScene"):
			continue
		var node := (load(String(entry[0])) as PackedScene).instantiate() as Node3D
		all.add_child(node)
		if node.has_method("_show_in_editor"):
			node.call("_show_in_editor")
		node.position = Vector3(float(entry[1]), 0.0, 0.0)
		placed += 1
	_check("the_line_up_found_three_aeroplanes_to_stand_together", placed == 3, "%d placed" % placed)
	var box := _box_of(all)
	var camera: Camera3D = stage["camera"]
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(TALL) / float(WIDE) * (box.size.x + 8.0)
	camera.position = box.get_center() + Vector3(0.0, 4.0, 70.0)
	camera.look_at(box.get_center(), Vector3.UP)
	(stage["sun"] as DirectionalLight3D).rotation = camera.rotation
	await _shoot(stage, all, "lineup", 0.04)
	(stage["viewport"] as SubViewport).queue_free()
	await get_tree().process_frame
