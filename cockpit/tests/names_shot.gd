extends Node
## The briefing room identity board with two roster-coloured pilots beside it.
##
## THIS IS A PICTURE PROBE, NOT A SUITE. Its only pass condition is that a PNG was written,
## which asserts nothing; `names.gd` and `names_peers.gd` hold the roster's rules and its
## network. It was listed in `suites.txt` from 2026-09-16 (`8fbede1d`, which added the script
## and its suite line together) to 2026-09-17, and in that time it never once passed a gate:
## `run_all` launches every suite `--headless`, where `RenderingServer.frame_post_draw` below
## never comes, so the run hung to the three-minute deadline every time. A permanently red
## line teaches everyone to read red as normal, which costs more than the three minutes.
## The refusal below is why it now says so in one second instead.

const LEVEL := preload("res://world/sky.tscn")
const PILOT := preload("res://player/remote_pilot.tscn")


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[names_shot] RESULT=FAIL headless has no rendering device; this is a probe, run it with one")
		get_tree().quit(1)
		return
	var out: String = ProjectSettings.globalize_path("user://names_shot.png")
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with("--out="): out = String(argument).substr(6)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	Net.set_profile("GRAHAM", 1, false)
	var why: String = Net.choose_level("lobby")
	if why != "":
		print("[names_shot] RESULT=FAIL %s" % why)
		get_tree().quit(1)
		return
	var level := LEVEL.instantiate() as FlightLevel
	add_child(level)
	for i in range(1800):
		if level.room != null and level.rig != null and level.rig.is_seated(): break
		await get_tree().physics_frame
	if level.room == null or level.room.roster_board == null:
		print("[names_shot] RESULT=FAIL roster board did not stand")
		get_tree().quit(1)
		return
	# Freeze the solo host's normal one-card publication while this picture supplies two people.
	Net.process_mode = Node.PROCESS_MODE_DISABLED
	Net.roster = {1: {"player": 1, "name": "GRAHAM", "colour": 1},
		2: {"player": 2, "name": "ALICE", "colour": 3}}
	Net.roster_changed.emit()
	var roster_page := level.room.roster_board.shown() as RosterPage
	if roster_page != null:
		roster_page.refresh()
	print("[names_shot] roster cards=%s rows=%d" % [Net.roster_cards(),
		roster_page.rows.get_child_count() if roster_page != null else -1])
	var middle: Vector3 = BriefingRoom.middle_of(level.level)
	for row in [[1, -0.7], [2, 0.7]]:
		var pilot := PILOT.instantiate() as RemotePilot
		level.room.add_child(pilot)
		pilot.global_position = middle + Vector3(2.55 + float(row[1]), 1.05, -BriefingRoom.INSIDE.z + 0.8)
		pilot.rotation.y = PI
		pilot.setup(int(row[0]), "")
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = middle + Vector3(2.55, 1.7, -BriefingRoom.INSIDE.z + 3.4)
	camera.look_at(middle + Vector3(2.55, 1.4, -BriefingRoom.INSIDE.z), Vector3.UP)
	camera.fov = 56.0
	camera.make_current()
	for i in range(20): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var saved: Error = image.save_png(out)
	print("[names_shot] %dx%d %s %s" % [image.get_width(), image.get_height(), error_string(saved), out])
	print("[names_shot] RESULT=%s" % ("PASS" if saved == OK else "FAIL"))
	get_tree().quit(0 if saved == OK else 1)
