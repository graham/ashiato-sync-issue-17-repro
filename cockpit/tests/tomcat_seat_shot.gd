extends Node3D
## Windowed: THE F-14'S WINGS AT FORWARD, MID AND FULL SWEEP, from outside and from BOTH crew seats -- the Tomcat as a
## craft, built as the game builds it (`VehicleView`, every seat manned, the wing played from its VAT casting), not the
## airframe on its own that `tomcat_shot` photographs.
##
##   Godot --path cockpit res://tests/tomcat_seat_shot.tscn -- --out=<folder>
##
## NOT HEADLESS. The seat pictures are taken from each seat's own eye, `CockpitStation.EYE_HEIGHT` over the seat marker the
## view places, looking at the middle of the port wing wherever the sweep has put it -- the one thing either crew member
## can see move when a handle is pulled.
##
## The sweep is posed on the airframe, which is what the view does with the bus's value (`_draw_the_wing_sweep`), because
## a picture has no server to ask. The VAT casting reads the airframe's own `sweep()` and plays it, so what is drawn is
## the casting, as it is in the game.

const SWEEPS: Array[float] = [20.0, 44.0, 68.0]

var out := ""
var failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	CockpitStation.use_saved_layouts = false
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.66, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 0.9
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.85, -0.55, 0.0)
	light.light_energy = 1.4
	add_child(light)
	var view := (load("res://objects/vehicles/craft_tomcat.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	# THE VAT CASTING, poured by the view where there is a renderer: wait for it, so every picture is of the casting.
	for i in range(30):
		await get_tree().process_frame
		if view._tomcat_casting != null:
			break
	var cast: bool = view._tomcat_casting != null
	print("[tomcat_seat_shot] the view's wing is %s" % ("played from its VAT casting" if cast else "drawn as parts: NO CASTING"))
	if not cast:
		failures.append("no casting")
	var camera := Camera3D.new()
	camera.fov = 70
	camera.current = true
	add_child(camera)
	for sweep in SWEEPS:
		view._tomcat.set_sweep(sweep)
		view._sweep_drawn = sweep
		camera.fov = 38
		camera.global_position = view.to_global(Vector3(-14.0, 8.0, 12.0))
		camera.look_at(view.to_global(Vector3(0.0, 0.5, 1.0)), Vector3.UP)
		await _save("cockpit-tomcat-craft-outside-sweep-%02d.png" % int(sweep))
		for seat in range(view.seats.size()):
			var marker: Node3D = view.seats[seat]
			var eye: Vector3 = marker.global_transform * Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
			camera.fov = 75
			camera.global_position = eye
			# AT THE PORT WING ITSELF, wherever this sweep has put it: the centre of its drawn vertices, asked of the
			# airframe rather than typed. A fixed aim point behind either seat photographed the glove and the deck at every
			# sweep -- identical pictures -- because from 2.94 m the glove's roof at 2.72 hides the wing's root, and only
			# the outer panel shows past it.
			var wing := view._tomcat.find_child("WingPort", true, false) as MeshInstance3D
			var middle := Vector3.ZERO
			var count: int = 0
			for v in (wing.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				middle += wing.global_transform * v
				count += 1
			camera.fov = 90
			camera.look_at(middle / float(maxi(count, 1)), Vector3.UP)
			await _save("cockpit-tomcat-seat%d-%s-port-wing-sweep-%02d.png"
				% [seat, "pilot" if seat == 0 else "rio", int(sweep)])
	print("[tomcat_seat_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL " + ", ".join(failures), out])
	get_tree().quit(0 if failures.is_empty() else 1)


func _save(filename: String) -> void:
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[tomcat_seat_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
