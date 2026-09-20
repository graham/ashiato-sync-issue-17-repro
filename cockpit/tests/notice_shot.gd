extends Node
## THE SESSION'S NOTICE ON THE BOARD, AS A PERSON SEES IT: the level count-down a joiner reads in the briefing room before
## its screen goes, and "PLAYER 2 JOINED" -- each above the code and the debrief, on the tab a player is likeliest to have
## up. Saved as PNGs for a human to look at.
##
##   Godot --path cockpit --xr-mode off res://tests/notice_shot.tscn
##
## NOT HEADLESS: headless has no rendering device and the picture comes back black. A PROBE, because whether a notice reads
## on a board in the hand has no assertion; tests/notices.gd holds what notices do across two real machines, and
## tests/clipboard.gd that the line fits every tab at its longest.
##
## The notices are put on `Net.notice` directly, as tests/clipboard.gd's fit check does: what is being looked at is the
## line, and `Net.notice_words` writes it exactly as it does in a session.
##
## Read RESULT=, not the exit code.

const LEVEL_SHOT: String = "user://notice_shot_level.png"
const JOINED_SHOT: String = "user://notice_shot_joined.png"


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

	Net.session_code = "PNS8L6"
	page.show_tab(ClipboardPage.Tab.CRAFT)
	var now: int = Time.get_ticks_msec()
	Net.notice = {"kind": "level", "level": "island", "due": now + 2500, "shown_until": now + 60000}
	page.tick()
	var level_said: String = page.notice_text()
	var level_saved: int = await _save(glass, LEVEL_SHOT)

	Net.notice = {"kind": "joined", "player": 2, "shown_until": Time.get_ticks_msec() + 60000}
	page.tick()
	var joined_said: String = page.notice_text()
	var joined_saved: int = await _save(glass, JOINED_SHOT)
	Net.notice = {}
	Net.session_code = ""

	print("[notice_shot] '%s' %s -> %s" % [level_said, error_string(level_saved), ProjectSettings.globalize_path(LEVEL_SHOT)])
	print("[notice_shot] '%s' %s -> %s" % [joined_said, error_string(joined_saved),
		ProjectSettings.globalize_path(JOINED_SHOT)])
	var ok: bool = level_saved == OK and joined_saved == OK and level_said.begins_with("EVERYBODY TO") \
		and joined_said == "PLAYER 2 JOINED"
	print("RESULT=%s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _save(glass: SubViewport, path: String) -> int:
	for i in range(4):
		await RenderingServer.frame_post_draw
	return glass.get_texture().get_image().save_png(path)
