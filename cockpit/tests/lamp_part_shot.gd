extends Node3D
## Windowed: THE SIGNAL LAMP AS A PART -- the BUILD tab's bin walked down to "+ SIGNAL LAMP", then the plane's pilot seat
## from the seated eye, looking down at where the holster is, before a lamp is placed and after.
##
##   Godot --path cockpit res://tests/lamp_part_shot.tscn -- --out=<folder>
##
## Asked for on 2026-09-19 (lane/lampopt): "let's have the light gun (like the director camera) is optional, not always
## present and can be loaded via the ipad." No seat has one until a player presses "+ SIGNAL LAMP".
##
## NOT HEADLESS, AND NEVER THE DESKTOP: every picture is this window's own viewport texture. The BUILD page is a
## `ClipboardPage` in a CanvasLayer, as `builder_package_shot` draws it, scrolled by `scroll` as the thumb scrolls it.
## The lamp is placed by `VehicleView.holster_a_lamp`, the call `PilotRig._add_a_lamp` makes for a "+ SIGNAL LAMP" press
## (`tests/signal_lamp.gd` presses the button itself). Every picture carries `<commit>[+dirty], <date> <time>`.

var out := ""
var stamp := ""
var failures: PackedStringArray = []
var _label: Label


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://lamp_part_shot")
	DirAccess.make_dir_recursive_absolute(out)
	stamp = _stamp()
	CockpitStation.use_saved_layouts = false
	_label = Label.new()
	_label.position = Vector2(12, get_viewport().get_visible_rect().size.y - 60)
	_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	_label.add_theme_font_size_override("font_size", 16)
	var top := CanvasLayer.new()
	top.layer = 10
	add_child(top)
	top.add_child(_label)
	await _the_build_tab()
	await _the_seat()
	print("[lamp_part_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL " + ", ".join(failures), out])
	get_tree().quit(0 if failures.is_empty() else 1)


func _the_build_tab() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color(0.2, 0.22, 0.25)
	back.size = Vector2(1600, 1000)
	layer.add_child(back)
	var page := ClipboardPage.new()
	page.size = Vector2(760, 950)
	page.position = Vector2(420, 10)
	layer.add_child(page)
	page.show_tab(ClipboardPage.Tab.BUILD)
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var button: Button = null
	for node in (page.get("_build") as Control).find_children("*", "Button", true, false):
		if (node as Button).text == "+ SIGNAL LAMP":
			button = node as Button
	if button == null:
		failures.append("no + SIGNAL LAMP button")
	else:
		var area := page.get("_scroll") as ScrollContainer
		var pulls: int = 0
		while button.get_global_rect().end.y > area.get_global_rect().end.y and pulls < 60:
			page.scroll(1)
			await RenderingServer.frame_post_draw
			pulls += 1
	await _save("cockpit-lampopt-01-the-build-tab-offers-plus-signal-lamp.png",
		"the BUILD tab's parts bin, walked down to + SIGNAL LAMP")
	layer.queue_free()
	await RenderingServer.frame_post_draw


func _the_seat() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.74, 0.80)
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, -0.6, 0.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	add_child(light)
	var view := (load("res://objects/vehicles/craft_plane.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var camera := Camera3D.new()
	camera.near = 0.03
	camera.fov = 80.0
	add_child(camera)
	camera.current = true
	var marker: Node3D = view.seats[0]
	var station: CockpitStation = view.station_for(0)
	var eye: Vector3 = marker.global_transform * Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	# WHERE THE HOLSTER IS: the spot the search finds for this seat, found as a placed lamp's would be.
	var spot: Vector3 = station.global_transform * SignalLamp.holster_spot(_grips(view, station),
		SignalLamp.faces_in(station), view.holster_fits(station, 0))
	# FROM THE EYE, TURNED DOWN AND RIGHT TO THE HOLSTER, as a pilot looks for it.
	camera.fov = 75.0
	camera.global_position = eye
	camera.look_at(spot + marker.global_basis * Vector3(-0.10, 0.10, -0.15), Vector3.UP)
	if SignalLamp.in_station(station) != null:
		failures.append("a lamp at the seat before one was placed")
	await _save("cockpit-lampopt-02-the-pilots-seat-before-no-lamp.png", "plane seat 0 from the eye: no lamp until one is placed")
	var lamp: SignalLamp = view.holster_a_lamp(0)
	# NO CLOSE-UP FROM AHEAD: from anywhere in front of the seat the plane's forward screen's back hides the holster.
	if lamp == null or lamp.global_position.distance_to(spot) > 0.001:
		failures.append("the lamp is not in the searched holster")
	await _save("cockpit-lampopt-03-the-pilots-seat-after-plus-signal-lamp.png",
		"plane seat 0 from the eye, after + SIGNAL LAMP: in its holster")


func _grips(view: VehicleView, station: CockpitStation) -> Array[Vector3]:
	var out_grips: Array[Vector3] = []
	var mine := station.global_transform.affine_inverse()
	var every: Array = []
	for seat in range(view.seats.size()):
		var other: CockpitStation = view.station_for(seat)
		if other != null:
			for control in other.controls().values():
				if not every.has(control):
					every.append(control)
	every.append_array((view.get("_console") as Dictionary).values())
	for control_any in every:
		var control := control_any as VehicleControl
		if control != null and control.is_inside_tree():
			out_grips.append(mine * control.grip_global())
	return out_grips


func _stamp() -> String:
	var root: String = ProjectSettings.globalize_path("res://")
	var said: Array = []
	OS.execute("git", ["-C", root, "rev-parse", "--short", "HEAD"], said)
	var status: Array = []
	OS.execute("git", ["-C", root, "status", "--porcelain"], status)
	var dirty: bool = not status.is_empty() and not String(status[0]).strip_edges().is_empty()
	return "%s%s, %s" % [String(said[0]).strip_edges() if not said.is_empty() else "?", "+dirty" if dirty else "",
		Time.get_datetime_string_from_system(false, true)]


func _save(filename: String, caption: String) -> void:
	_label.text = "%s   %s" % [caption, stamp]
	for frame in range(5):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[lamp_part_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
