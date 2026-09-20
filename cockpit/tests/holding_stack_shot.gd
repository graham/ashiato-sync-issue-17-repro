extends Node
## Windowed evidence: the real island, real VehicleViews for the 200-aircraft stack, a
## camera placed at one middle-layer aircraft, and the live TRAFFIC panel composited at
## readable size. Run with --xr-mode off --desktop-only; headless cannot produce this picture.

var _output := ""


func _ready() -> void:
	if get_tree().current_scene != self:
		_capture()
		return
	var watcher := Node.new()
	watcher.name = "HoldingStackShotWatch"
	watcher.set_script(get_script())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			watcher.set("_output", arg.trim_prefix("--out="))
	get_tree().root.add_child.call_deferred(watcher)


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_finish(false, "rendering is required")
		return
	if _output == "":
		var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		_output = repo.path_join("screenshots").path_join(Time.get_date_string_from_system()) \
			.path_join("holding_stack_200.png")
	DirAccess.make_dir_recursive_absolute(_output.get_base_dir())
	Net.choose_level(ChartDrawer.DEFAULT)
	Net.play_solo()
	get_tree().change_scene_to_file("res://world/sky.tscn")
	var level: FlightLevel = null
	for i in range(2400):
		level = get_tree().current_scene as FlightLevel
		if level != null and level.holding_stack != null and level.rig != null and Sim.is_ready:
			break
		await get_tree().physics_frame
	if level == null or level.holding_stack == null:
		_finish(false, "flight level did not start")
		return
	level.choose_stack_count(200)
	level.choose_clouds(false)
	for i in range(1200):
		if level.holding_stack.count() == 200 and (level.get("_views") as Dictionary).size() >= 200:
			break
		await get_tree().physics_frame
	if level.holding_stack.count() != 200:
		_finish(false, "only %d aircraft spawned" % level.holding_stack.count())
		return
	var middle := level.holding_stack.base_altitude() + level.holding_stack.layer_spacing() * 5.0
	var chosen := 0
	var nearest := INF
	for entity in level.holding_stack.entities():
		var error := absf(level.holding_stack.assigned_altitude(entity) - middle)
		if error < nearest:
			nearest = error
			chosen = entity
	var state: Dictionary = Sim.server.vehicle_state(chosen)
	var forward := (state["velocity"] as Vector3).normalized()
	var eye := Camera3D.new()
	eye.name = "MiddleLayerSeatView"
	eye.fov = 64.0
	eye.far = 18000.0
	eye.position = (state["position"] as Vector3) + Vector3(0.0, 1.6, 0.0) + forward * 2.0
	level.add_child(eye)
	eye.look_at(eye.position + forward * 1000.0 + Vector3(0.0, -15.0, 0.0), Vector3.UP)
	eye.make_current()
	(level.get_node("Ui/Status") as Control).visible = false
	var own_view: Node3D = (level.get("_views") as Dictionary).get(chosen)
	if own_view != null:
		own_view.visible = false
	var page := level.rig.clipboard.page()
	page.show_tab(ClipboardPage.Tab.TRAFFIC)
	page.show_load_test(200, 0, "2 peers · 247.6 kB/s each · 2 pkt/tick · buffer 9 · 0.6 rollback/s · tick 4.4 ms")
	var panel := level.rig.clipboard.panel()
	var glass := panel.get("_screen") as SubViewport
	glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	level.add_child(overlay)
	var board := TextureRect.new()
	board.texture = glass.get_texture()
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	board.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	board.position = Vector2(-520.0, -675.0)
	board.size = Vector2(480.0, 625.0)
	overlay.add_child(board)
	var caption := Label.new()
	caption.position = Vector2(32.0, 28.0)
	caption.text = "200-AIRCRAFT HOLDING STACK  ·  VIEW FROM MIDDLE LAYER"
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(caption)
	for i in range(24):
		await RenderingServer.frame_post_draw
	var saved := get_viewport().get_texture().get_image().save_png(_output)
	_finish(saved == OK, "%s: %s" % [error_string(saved), _output])


func _finish(ok: bool, detail: String) -> void:
	print("[holding_stack_shot] %s (%s)" % ["PASS" if ok else "FAIL", detail])
	print("RESULT=%s" % ["PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
