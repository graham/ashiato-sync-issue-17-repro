extends Node
## THE CRAFT PAGE, AS A PERSON SEES IT: the clipboard's CRAFT tab in its groups, with the game's kinds and with sixty-four,
## and the one grid it used to be at sixty-four, saved as PNGs for a human to look at.
##
##   Godot --path cockpit res://tests/craft_shot.tscn
##
## NOT HEADLESS. Headless has no rendering device and the picture comes back a black rectangle. A PROBE, because whether
## a group bar reads as a set of tabs has no assertion: tests/craft_page.gd holds that every craft is one group press
## away and that sixty-four fit without scrolling, and this is what that looks like (lane/kinds, 2026-09-18).
##
## The board is the clipboard's own size and density, as `crew_shot` has it. "As it was" is the same page with every
## group's buttons shown at once, which is exactly the one grid the page drew before the groups.
##
## Read RESULT=, not the exit code.

const SHOTS: Dictionary = {
	"aeroplanes": "user://craft_shot_aeroplanes.png",
	"helicopters": "user://craft_shot_helicopters.png",
	"sixty_four_aeroplanes": "user://craft_shot_64_aeroplanes.png",
	"sixty_four_one_grid": "user://craft_shot_64_one_grid.png",
}


func _ready() -> void:
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
	page.show_tab(ClipboardPage.Tab.CRAFT)
	var saved: Array[int] = []

	page.show_craft_group("aeroplanes")
	saved.append(await _save(glass, SHOTS["aeroplanes"]))
	page.show_craft_group("helicopters")
	saved.append(await _save(glass, SHOTS["helicopters"]))

	# SIXTY-FOUR, dealt round the groups as tests/craft_page.gd deals them.
	var rows: Array[Dictionary] = VehicleCatalogue.craft_rows()
	var number: int = 100
	while rows.size() < 64:
		var group: String = VehicleCatalogue.GROUPS[rows.size() % VehicleCatalogue.GROUPS.size()]
		rows.append({"kind": number, "name": "%s %d" % [group.trim_suffix("s"), number], "group": group})
		number += 1
	page.show_kinds(rows)
	page.show_craft_group("aeroplanes")
	saved.append(await _save(glass, SHOTS["sixty_four_aeroplanes"]))
	# AS IT WAS: every button at once, which is the one grid the page drew before it had groups.
	for pick in (page.get("_craft_grid") as Node).get_children():
		(pick as Control).visible = true
	saved.append(await _save(glass, SHOTS["sixty_four_one_grid"]))

	var all_saved: bool = saved.all(func(result: int) -> bool: return result == OK)
	print("[craft_shot] RESULT=%s" % ("PASS" if all_saved else "FAIL"))
	get_tree().quit(0 if all_saved else 1)


func _save(glass: SubViewport, path: String) -> int:
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = glass.get_texture().get_image()
	var saved: int = picture.save_png(path)
	print("[craft_shot] %s x %s, saved %s to %s" % [picture.get_width(), picture.get_height(), error_string(saved),
		ProjectSettings.globalize_path(path)])
	return saved
