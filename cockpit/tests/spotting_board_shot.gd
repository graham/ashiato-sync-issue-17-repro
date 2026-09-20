extends Node
## THE SPOTTING TAB, AS A PERSON SEES IT: off, on MEDIUM with the normal limit, and on HIGH with the limit at 1 km. Saved
## as PNGs for a human to look at -- the page's own SubViewport, never the desktop.
##
##   Godot --path cockpit --xr-mode off res://tests/spotting_board_shot.tscn -- --out=C:/somewhere
##
## NOT HEADLESS: headless has no rendering device and the picture comes back black. A PROBE, because whether the words
## read on a board in the hand has no assertion; tests/spotting.gd presses the same buttons with the beam and holds what
## they do, and tests/clipboard.gd that every tab fits.
##
## Read RESULT=, not the exit code.


func _ready() -> void:
	var out: String = ProjectSettings.globalize_path("user://spotting_board_shot")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var board := TouchPanel.new()
	board.page = preload("res://ui/menus/clipboard_page.tscn")
	board.size = Clipboard.SIZE
	board.pixels = 1024
	add_child(board)
	await get_tree().process_frame
	var page := board.shown() as ClipboardPage
	var glass := board.get("_screen") as SubViewport
	BuildStamp.attach_to(glass)
	glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	page.show_tab(ClipboardPage.Tab.SPOTTING)
	var saved: Array[int] = []
	for setting in [[Spectacles.Strength.OFF, 500.0, "off"], [Spectacles.Strength.MEDIUM, 500.0, "medium-0.5km"],
			[Spectacles.Strength.HIGH, 1000.0, "high-1km"]]:
		var pair := Spectacles.new()
		pair.strength = setting[0]
		pair.near_m = setting[1]
		page.show_spotting(pair)
		var path: String = out.path_join("cockpit-spotting-board-%s.png" % setting[2])
		for i in range(4):
			await RenderingServer.frame_post_draw
		saved.append(glass.get_texture().get_image().save_png(path))
		print("[spotting_board_shot] %s -> %s" % [error_string(saved[-1]), path])
	var ok: bool = saved.all(func(e: int) -> bool: return e == OK)
	print("RESULT=%s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
