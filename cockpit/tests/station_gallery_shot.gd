extends Node
## A forward startup picture from every real seat in every drawn craft.
##
## This is a visual audit, not a headless suite. It uses the same VehicleView and station
## fit path the game uses, hides only the hull that would otherwise be inside the viewer's
## head, and records each seat at its actual craft-local anchor. The quiet apron, centre
## marker, and three reference blocks make each picture legible in context without putting
## level-specific scenery into the craft or its saved cockpit package.

const FOV := 75.0
var _out := ""
var _failed: PackedStringArray = []
var _scheduled := 0
var _saved := 0
var _only := ""
## A DEMONSTRATION TANK LEVEL, 0 to 1, or -1 for "tell the stations nothing". See `_capture`.
var _tank := -1.0
var _tank_word := ""

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[station_gallery] rendering is required; do not run this headless")
		get_tree().quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="):
			_only = argument.trim_prefix("--only=").to_lower()
		elif argument.begins_with("--tank="):
			_tank = clampf(argument.trim_prefix("--tank=").to_float(), 0.0, 1.0)
		elif argument.begins_with("--tank-word="):
			_tank_word = argument.trim_prefix("--tank-word=").to_lower()
	if _out == "":
		var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		_out = repo.path_join("screenshots").path_join(Time.get_date_string_from_system())
	if DirAccess.make_dir_recursive_absolute(_out) != OK:
		push_error("[station_gallery] could not create " + _out)
		get_tree().quit(1)
		return
	# A visual baseline must describe the authored station, never furniture a particular
	# player left in user://.  This is restored before exit for callers that embed the probe.
	var saved_layout_setting := CockpitStation.use_saved_layouts
	CockpitStation.use_saved_layouts = false
	_light_the_audit_room()
	for kind in range(Sim.Kind.size()):
		if not VehicleCatalogue.is_drawn(kind):
			continue
		if _only != "" and Sim.kind_name(kind) != _only:
			continue
		var poses := Sim.geometry_of(kind).get("seat_poses", []) as Array
		if poses.is_empty():
			continue
		for seat in range(poses.size()):
			_scheduled += 1
			await _capture(kind, seat)
	CockpitStation.use_saved_layouts = saved_layout_setting
	if _saved != _scheduled:
		_failed.append("saved %d of %d requested seats" % [_saved, _scheduled])
	print("[station_gallery] RESULT=%s %d of %d saved, %d failures, into %s" % ["PASS" if _failed.is_empty() else "FAIL", _saved, _scheduled, _failed.size(), _out])
	get_tree().quit(0 if _failed.is_empty() else 1)

func _light_the_audit_room() -> void:
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, -0.6, 0.0)
	light.light_energy = 1.2
	add_child(light)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.40, 0.46)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.ambient_light_energy = 1.0
	world.environment = env
	add_child(world)
	_build_audit_apron()


## The gallery is intentionally a tiny level: it gives every station a common horizon,
## ground plane, centre line, and recognizable fixed landmarks. The objects are visual-only
## MeshInstance3D nodes (Godot class reference: class_meshinstance3d.html), so they cannot
## alter vehicle physics or the authored seat view.
func _build_audit_apron() -> void:
	_add_box("Apron", Vector3(64.0, 0.12, 64.0), Vector3(0.0, -1.56, 0.0), Color(0.18, 0.21, 0.24))
	_add_box("CentreLine", Vector3(0.35, 0.03, 40.0), Vector3(0.0, -1.48, -4.0), Color(0.82, 0.70, 0.24))
	# The forward tower is deliberately tall enough to appear above most panels; the side
	# markers reveal a station's lateral view without crowding its immediate exit path.
	_add_box("ForwardMarker", Vector3(2.0, 7.0, 2.0), Vector3(0.0, 1.95, -18.0), Color(0.82, 0.34, 0.18))
	_add_box("LeftMarker", Vector3(2.5, 3.5, 2.5), Vector3(-11.0, 0.2, -9.0), Color(0.22, 0.48, 0.82))
	_add_box("RightMarker", Vector3(2.5, 5.0, 2.5), Vector3(11.0, 0.95, -12.0), Color(0.30, 0.72, 0.43))


func _add_box(label: String, size: Vector3, at: Vector3, colour: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = at
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = 0.82
	part.material_override = paint
	add_child(part)

func _capture(kind: int, seat: int) -> void:
	var scene_path := "res://objects/vehicles/craft_%s.tscn" % Sim.kind_name(kind)
	var scene := load(scene_path) as PackedScene
	if scene == null:
		_failed.append("%s has no preview scene" % Sim.kind_name(kind))
		return
	var view := scene.instantiate() as VehicleView
	add_child(view)
	view.preview_kind = kind as Sim.Kind
	view._show_in_editor()
	view._show_body(true)
	# A parked station starts with every turret at its native rest aim.  Without this the
	# gunner screenshot says "no gun", which is the opposite of the startup view this job
	# exists to preserve.
	var aims: Array = []
	for mount in range(3):
		aims.append((Sim.gun_of(kind, mount).get("rest", Vector2.ZERO)) as Vector2)
	view.draw_turrets_at(aims)
	# AND A WATER GAUGE THAT HAS BEEN TOLD NOTHING SAYS NOTHING, which is right and photographs
	# as "---". `--tank=<0..1>`, with `--tank-word=fill` or `drop`, hands every station one
	# demonstration craft state so the gauge can be pictured reading something. OFF BY DEFAULT:
	# a visual baseline must describe the authored station and not a moment of somebody's play.
	if _tank >= 0.0:
		for station in view.stations():
			(station as CockpitStation).show_state({"tank": _tank,
				"scooping": _tank_word == "fill", "dropping": _tank_word == "drop"}, [])
	var eye := Camera3D.new()
	eye.position = Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	eye.fov = FOV
	eye.near = 0.02
	view.seat_anchor(seat).add_child(eye)
	eye.current = true
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var path := _out.path_join("cockpit-station-%s-seat%d.png" % [Sim.kind_name(kind), seat])
	var err := get_viewport().get_texture().get_image().save_png(path)
	if err != OK:
		_failed.append("%s seat %d" % [Sim.kind_name(kind), seat])
		print("[station_gallery] FAILED %s" % path)
	else:
		_saved += 1
		print("[station_gallery] %s" % path)
	view.queue_free()
	await get_tree().process_frame
