extends Node
## Windowed visual proof of the host RADIO section. Run with --xr-mode off --desktop-only.

const OUT := "user://radio_shot.png"

func _ready() -> void:
	Net.is_host = true
	var board := TouchPanel.new()
	board.page = preload("res://ui/menus/clipboard_page.tscn")
	board.size = Clipboard.SIZE; board.pixels = Clipboard.PIXELS
	add_child(board)
	await get_tree().process_frame
	var page := board.shown() as ClipboardPage
	page.show_audio(true, true, "On. Host voice model ready.")
	page.show_radio("Sent to 3 players: All stations, tower, runway three six in use.", true)
	page.show_tab(ClipboardPage.Tab.AUDIO)
	var glass := board.get("_screen") as SubViewport
	# THE BUILD STAMP IN THE PAGE'S LOWER RIGHT: a picture of a page is a screenshot too (`BuildStamp`, 2026-09-18).
	BuildStamp.attach_to(glass)
	glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for _i in range(5): await RenderingServer.frame_post_draw
	var result := glass.get_texture().get_image().save_png(OUT)
	print("[radio_shot] %s -> %s" % [error_string(result), ProjectSettings.globalize_path(OUT)])
	print("RESULT=%s" % ("PASS" if result == OK else "FAIL"))
	get_tree().quit(0 if result == OK else 1)
