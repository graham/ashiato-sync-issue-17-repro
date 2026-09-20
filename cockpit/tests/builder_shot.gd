extends Node
## Windowed visual proof of the generated workshop, parked craft and craft/version board.
## Godot --xr-mode off --path cockpit res://tests/builder_shot.tscn -- --desktop-only --out=C:/path

const PATIENCE: int = 1200
const LEVEL := preload("res://world/sky.tscn")
var output := ""


func _ready() -> void:
	output = _asked("out")
	if output.is_empty(): output = ProjectSettings.globalize_path("user://builder_shot")
	DirAccess.make_dir_recursive_absolute(output)
	var refusal := Net.choose_level("builder")
	if refusal != "":
		print("[builder_shot] RESULT=FAIL %s" % refusal); get_tree().quit(1); return
	# Keep the probe as the current scene and put the production level beneath it.  This
	# is the same startup path as lobby_shot: Sky sees that no session exists, starts the
	# solo session, and builds after its Sim signal connections are installed.
	var level := LEVEL.instantiate() as FlightLevel
	add_child(level)
	var view: VehicleView = null
	for _i in range(PATIENCE):
		if level != null and level.builder_session != null and level.builder_session.entity > 0:
			view = level.view_of(level.builder_session.entity)
			if view != null and level.builder_room != null and level.builder_room.board != null: break
		await get_tree().physics_frame
	if level == null or view == null:
		print("[builder_shot] RESULT=FAIL workshop did not come up (chart %s, room %s, session %s, ready %s, entity %d)" % [
			level.level.id if level != null and level.level != null else "-", level.builder_room if level != null else null,
			level.builder_session if level != null else null, Sim.is_ready,
			level.builder_session.entity if level != null and level.builder_session != null else 0])
		print("[builder_shot] client vehicles %s, views %s" % [Sim.current.keys(), level.get("_views").keys()])
		get_tree().quit(1); return
	# Draw two stations and two crew silhouettes for context without changing simulation
	# occupancy; the peer suite owns authority behavior.
	view.man([0, 1], -1)
	var camera := Camera3D.new(); level.add_child(camera); camera.current = true
	camera.position = Vector3(8.0, 4.5, 11.0); camera.look_at(Vector3(0, 1.8, 0)); camera.fov = 62.0
	var craft_ok := await _save(camera, output.path_join("builder_room.png"))
	# The room is sized for the largest offered craft, which puts the fixed wall board too
	# far away to read in the craft-wide view.  Keep a second close view as evidence that
	# the production board and its dynamically generated seat actions are legible.
	var board_at := level.builder_room.board.global_position
	camera.global_position = board_at + Vector3(0.0, 0.15, 3.6)
	camera.look_at(board_at); camera.fov = 48.0
	var board_ok := await _save(camera, output.path_join("builder_board.png"))
	var ok := craft_ok and board_ok
	print("[builder_shot] RESULT=%s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _save(_camera: Camera3D, path: String) -> bool:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[builder_shot] saved %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	return error == OK and image.get_width() > 100


func _asked(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name): return arg.get_slice("=", 1)
	return ""
