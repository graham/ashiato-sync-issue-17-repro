extends Node3D
## Windowed: WHAT SIXTY-FOUR STATIONS COST TO DRAW, and the CREW page of a long cabin, for looking at.
##
##   Godot --path cockpit res://tests/many_seats_shot.tscn -- --out=<folder> [--page-only]
##
## A MANNED CRAFT BUILDS A STATION FOR EVERY SEAT IT HAS (`VehicleView.man`), occupied or not, so that a crew member
## arriving next to you is seen arriving. That was four at most until lane/seats (2026-09-18, "yes, no max"). This builds
## the Chinook with its own four seats and then fitted with sixty-four (`Sim.fit_seats`), mans every seat of each, and
## says for each what the build took, how many nodes it made, how many draw calls and objects a frame costs, and the
## frame's CPU and GPU render time with the whole craft in frame from above. A REPORT, not a gate: it prints and
## saves pictures; the numbers go into learnings/2026-09-18-seats.md. Seats past a package's stations use the legacy
## station scene and say so, once each.
##
## Then the CREW page, drawn full screen, for a twelve-seat airliner and a sixty-four-seat Chinook with people aboard.

const KIND: int = Sim.Kind.CHINOOK
const MANY: int = 64
const SETTLE_FRAMES: int = 30
const MEASURED_FRAMES: int = 240

var out := ""
var failures: PackedStringArray = []


func _ready() -> void:
	var page_only: bool = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		elif argument == "--page-only":
			page_only = true
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://many_seats_shot")
	DirAccess.make_dir_recursive_absolute(out)
	CockpitStation.use_saved_layouts = false
	get_viewport().size = Vector2i(1600, 1000)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.74, 0.80)
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, -0.6, 0.0)
	light.shadow_enabled = true
	add_child(light)
	var camera := Camera3D.new()
	camera.current = true
	camera.near = 0.03
	camera.fov = 75.0
	add_child(camera)

	if page_only:
		await _the_crew_page(camera)
		print("[many_seats_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL " + ", ".join(failures), out])
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	var own: Dictionary = await _measure(camera, "own")
	var fitted: Dictionary = Sim.fit_seats(KIND, _cabin(MANY))
	if int(fitted.get("fitted", 0)) != MANY:
		failures.append("fit %s" % fitted)
	var many: Dictionary = await _measure(camera, "many")
	Sim.fit_seats(KIND, [])
	for row in [own, many]:
		print("[many_seats_shot] %d stations: built in %.1f ms, %d nodes; a frame %d draw calls, %d objects, %d primitives, render %.2f ms cpu / %.2f ms gpu"
			% [row["stations"], row["build_ms"], row["nodes"], row["draws"], row["objects"], row["primitives"], row["cpu_ms"], row["gpu_ms"]])
	await _the_crew_page(camera)
	print("[many_seats_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL " + ", ".join(failures), out])
	get_tree().quit(0 if failures.is_empty() else 1)


## FOUR ABREAST DOWN THE CABIN, the pilot first: a crowd, on purpose.
static func _cabin(count: int) -> Array:
	var seats: Array = []
	for seat in range(count):
		seats.append({"position": Vector3(-1.2 + 0.8 * float(seat % 4), -0.4, -4.0 + 0.7 * float(seat / 4)),
			"yaw": 0.0, "station": "pilot" if seat == 0 else "operator"})
	return seats


func _measure(camera: Camera3D, tag: String) -> Dictionary:
	var view := (load("res://objects/vehicles/craft_chinook.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	var began: int = Time.get_ticks_usec()
	view._show_in_editor()
	var build_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	var nodes: int = view.find_children("*", "", true, false).size()
	var stations: int = view.stations().size()
	# FROM ABOVE AND AHEAD, the whole craft in frame, so every station is in the frustum whichever are hidden by the hull:
	# nothing here culls by occlusion, so what is in the frustum is what is drawn.
	camera.global_position = view.to_global(Vector3(-9.0, 9.0, -16.0))
	camera.look_at(view.to_global(Vector3(0.0, 0.0, 1.0)), Vector3.UP)
	for i in range(SETTLE_FRAMES):
		await RenderingServer.frame_post_draw
	var rid: RID = get_viewport().get_viewport_rid()
	var cpu: float = 0.0
	var gpu: float = 0.0
	for i in range(MEASURED_FRAMES):
		await RenderingServer.frame_post_draw
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var row: Dictionary = {"stations": stations, "build_ms": build_ms, "nodes": nodes,
		"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"cpu_ms": cpu / MEASURED_FRAMES, "gpu_ms": gpu / MEASURED_FRAMES}
	await _save("cockpit-many-seats-chinook-%d-stations-from-above.png" % stations)
	view.queue_free()
	await RenderingServer.frame_post_draw
	return row


func _the_crew_page(camera: Camera3D) -> void:
	camera.current = false
	Sim.fit_seats(Sim.Kind.AIRLINER, _cabin(12))
	Sim.fit_seats(KIND, _cabin(MANY))
	var pilots: Array = [{"client": 1, "vehicle": 100, "seat": 0}, {"client": 2, "vehicle": 100, "seat": 9},
		{"client": 3, "vehicle": 100, "seat": 11}, {"client": 4, "vehicle": 200, "seat": 0},
		{"client": 5, "vehicle": 200, "seat": 17}, {"client": 6, "vehicle": 200, "seat": 40},
		{"client": 7, "vehicle": 200, "seat": 63}, {"client": 8, "vehicle": 300, "seat": 0}]
	var current: Dictionary = {100: {"kind": Sim.Kind.AIRLINER, "position": Vector3.ZERO},
		200: {"kind": KIND, "position": Vector3(1200.0, 0.0, 0.0)},
		300: {"kind": Sim.Kind.PLANE, "position": Vector3(9400.0, 0.0, 0.0)}}
	var manifest: Array = CrewManifest.read(pilots, current, 1)
	# ON THE CLIPBOARD'S OWN GLASS, at its own size, as `tests/crew_shot.gd` draws it.
	var board := TouchPanel.new()
	board.page = preload("res://ui/menus/clipboard_page.tscn")
	board.size = Clipboard.SIZE
	board.pixels = Clipboard.PIXELS
	add_child(board)
	await get_tree().process_frame
	var page := board.shown() as ClipboardPage
	var glass := board.get("_screen") as SubViewport
	# THE BUILD STAMP IN THE PAGE'S LOWER RIGHT: a picture of a page is a screenshot too (`BuildStamp`, 2026-09-18).
	BuildStamp.attach_to(glass)
	glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	page.show_tab(ClipboardPage.Tab.CREW)
	page.show_crew(manifest, {})
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = out.path_join("cockpit-many-seats-crew-page-twelve-and-sixty-four-seats.png")
	if glass.get_texture().get_image().save_png(path) != OK:
		failures.append("save crew page")
	else:
		print("[many_seats_shot] saved %s" % path)
	Sim.fit_seats(Sim.Kind.AIRLINER, [])
	Sim.fit_seats(KIND, [])


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = out.path_join(file)
	if image == null or image.save_png(path) != OK:
		failures.append("save %s" % file)
		return
	print("[many_seats_shot] saved %s" % path)
