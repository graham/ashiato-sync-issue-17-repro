extends Node
## THE SD40-2, PHOTOGRAPHED ON ITS OWN, because a suite cannot see whether a locomotive looks like a locomotive.
##
##   Godot --xr-mode off --desktop-only --path cockpit res://tests/road_diesel_shot.tscn
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device. Four pictures -- a three-quarter view, and
## the side, front and top ORTHOGRAPHIC with the scale in the filename, so each can be laid over the photograph it was
## measured from and argued with. The elevations get a shadowless fill along the camera's own line of sight, or the side
## away from the sun is a black slab (`modelling_here.md` section 7, and lane/train's 0.55).
##
## A STAGE OF ITS OWN (`own_world_3d`), or four stages share the parent's world and each one's light fights the others.
## Read RESULT=, not the exit code.

const SETTLE: int = 3

var _failures: PackedStringArray = []
var _out: String = ""


func _check(label: String, ok: bool, detail: String) -> void:
	print("[road_diesel_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	if _out == "":
		var repo: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		_out = repo.path_join("screenshots").path_join(Time.get_date_string_from_system())
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var loco := RoadDiesel.new()
	loco.dress()
	var box: AABB = _drawn_box(loco)
	print("[road_diesel_shot] drawn %.3f long, %.3f wide, %.3f tall, %d triangles in %d parts"
		% [box.size.z, box.size.x, box.size.y, _triangles(loco), loco.get_child_count()])
	loco.queue_free()

	await _lineup()
	await _shoot("11-sd40-2-three-quarters-on", Vector3(1.0, 0.42, 0.85), false)
	await _shoot("12-sd40-2-side", Vector3(1.0, 0.0, 0.0), true)
	await _shoot("13-sd40-2-front", Vector3(0.0, 0.0, -1.0), true)
	await _shoot("14-sd40-2-top", Vector3(0.0, 1.0, 0.03), true)
	_finish()


## THE SCALE LINE-UP: the locomotive beside a boxcar and two aeroplanes the reader already knows the size of, all drawn
## by the game and all standing on one ground. A dimension in a doc block is a claim; a 21 m locomotive standing beside
## a 30 m Hercules is a fact anybody can check by eye. The pattern is `liners_shot --only=lineup`.
func _lineup() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1920, 1080)
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	BuildStamp.attach_to(stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.58, 0.66, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.74, 0.80)
	env.ambient_light_energy = 0.9
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, -0.7, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	stage.add_child(sun)

	var along: float = 0.0
	var said: PackedStringArray = []
	var subjects: Array = [["the SD40-2", -1], ["a boxcar", -2], ["a C-130", Sim.Kind.TRANSPORT],
		["a 737", Sim.Kind.AIRLINER]]
	for entry in subjects:
		var node: Node3D = null
		if int(entry[1]) == -1:
			var loco := RoadDiesel.new()
			loco.dress()
			node = loco
		elif int(entry[1]) == -2:
			var car := MeshInstance3D.new()
			car.mesh = Boxcar.mesh()
			car.material_override = Boxcar.painted()
			node = car
		else:
			var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
			stage.add_child(view)
			view.setup(0, int(entry[1]))
			node = view
		if node.get_parent() == null:
			stage.add_child(node)
		var box: AABB = _drawn_box(node)
		# NOSE TO NOSE along x, 8 m apart, each one's lowest drawn point on the ground.
		node.position = Vector3(along - box.position.x, -box.position.y, -box.get_center().z)
		along += box.size.x + 8.0
		var tag := Label3D.new()
		tag.text = "%s\n%.1f m long" % [entry[0], box.size.z]
		tag.font_size = 150
		tag.pixel_size = 0.013
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Color(0.05, 0.05, 0.08)
		tag.no_depth_test = true
		# BESIDE EACH SUBJECT, clear of its own plan, since the picture is taken from overhead.
		tag.position = Vector3(node.position.x + box.size.x * 0.5 + 1.0, 6.0, box.size.z * 0.5 + 6.0)
		stage.add_child(tag)
		said.append("%s %.1f m" % [entry[0], box.size.z])
	print("[road_diesel_shot] lineup: %s" % ", ".join(said))

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	ground.mesh = plane
	var turf := StandardMaterial3D.new()
	turf.albedo_color = Color(0.33, 0.40, 0.26)
	ground.material_override = turf
	ground.position = Vector3(along * 0.5, -0.01, 0.0)
	stage.add_child(ground)

	# FROM ABOVE. Stood side by side and looked at from the front, four things of different LENGTHS are four end-on
	# silhouettes and the picture says nothing: the length is the quantity being compared, so the camera is overhead.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = along * 0.60
	camera.look_at_from_position(Vector3(along * 0.5, 90.0, 0.0), Vector3(along * 0.5, 0.0, 0.0), Vector3.FORWARD)
	camera.current = true
	stage.add_child(camera)
	await _frames(SETTLE)
	var path: String = _out.path_join("cockpit-trains-15-scale-line-up.png")
	_check("15-scale-line-up_is_saved", stage.get_texture().get_image().save_png(path) == OK, path)
	stage.queue_free()


## ONE PICTURE from `from`, a direction in the locomotive's own frame, orthographic or not.
func _shoot(what: String, from: Vector3, flat: bool) -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1600, 900)
	stage.own_world_3d = true
	stage.transparent_bg = false
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	BuildStamp.attach_to(stage)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# AMBIENT_SOURCE_COLOR READS `ambient_light_color`, WHICH DEFAULTS TO BLACK, so setting only the energy lights
	# nothing and the first three-quarter view comes back with one face of every box in shadow.
	env.ambient_light_color = Color(0.72, 0.76, 0.82)
	env.ambient_light_energy = 0.85
	world.environment = env
	stage.add_child(world)

	var loco := RoadDiesel.new()
	loco.dress()
	stage.add_child(loco)
	var box: AABB = _drawn_box(loco)
	var middle: Vector3 = box.get_center()
	var radius: float = box.size.length() * 0.5

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-42.0, 130.0, 0.0)
	stage.add_child(sun)
	var camera := Camera3D.new()
	var eye: Vector3 = middle + from.normalized() * radius * 3.0
	if flat:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		# FITTED TO THE DRAWN BOX, never by eye: sized by eye, the Tomcat's fin was clipped out of its own elevation.
		var across: float = maxf(maxf(box.size.x, box.size.z), box.size.y) * 1.08
		camera.size = across * (900.0 / 1600.0) if from.y == 0.0 else across
		if from.y == 0.0:
			camera.size = maxf(box.size.y, across * 900.0 / 1600.0) * 1.12
		# The shadowless fill along the line of sight, so an elevation reads like a drawing rather than like a slab.
		var fill := DirectionalLight3D.new()
		fill.shadow_enabled = false
		fill.light_energy = 0.55
		fill.look_at_from_position(eye, middle, Vector3.UP if absf(from.y) < 0.9 else Vector3.FORWARD)
		stage.add_child(fill)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 40.0
		eye = middle + from.normalized() * radius * 2.6
	camera.look_at_from_position(eye, middle, Vector3.UP if absf(from.y) < 0.9 else Vector3.FORWARD)
	camera.current = true
	stage.add_child(camera)
	await _frames(SETTLE)

	var scale_note: String = ""
	if flat:
		scale_note = "-at-%.1f-px-a-metre" % (900.0 / maxf(camera.size, 0.001))
	var path: String = _out.path_join("cockpit-trains-%s%s.png" % [what, scale_note])
	var saved: bool = stage.get_texture().get_image().save_png(path) == OK
	_check("%s_is_saved" % what, saved, path)
	print("[road_diesel_shot] %s: %s" % [what, path])
	stage.queue_free()


## THE DRAWN BOX of a node and its children. **The node ITSELF counts**: a boxcar is one `MeshInstance3D` with no
## children at all, and walking only the children measured it as 0.0 m long in the line-up's own caption.
func _drawn_box(root: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	var drawn_nodes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		drawn_nodes.append(root)
	for found in drawn_nodes:
		var drawn := found as MeshInstance3D
		if drawn.mesh == null:
			continue
		for s in range(drawn.mesh.get_surface_count()):
			for v in drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var at: Vector3 = drawn.transform * (v as Vector3)
				if first:
					box = AABB(at, Vector3.ZERO)
					first = false
				else:
					box = box.expand(at)
	return box


func _triangles(root: Node3D) -> int:
	var count: int = 0
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := found as MeshInstance3D
		if drawn.mesh == null:
			continue
		for s in range(drawn.mesh.get_surface_count()):
			count += (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return count


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	print("RESULT=%s" % ["PASS" if _failures.is_empty() else "FAIL"])
	get_tree().quit(0 if _failures.is_empty() else 1)
