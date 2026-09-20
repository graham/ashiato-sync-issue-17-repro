extends Node
## Windowed visual proof of the ninth clipboard tab. Always run with --xr-mode off.

const OUT := "user://music_shot.png"

func _ready() -> void:
	var board := TouchPanel.new()
	board.page = preload("res://ui/menus/clipboard_page.tscn")
	board.size = Clipboard.SIZE
	board.pixels = Clipboard.PIXELS
	add_child(board)
	await get_tree().process_frame
	var page := board.shown() as ClipboardPage
	page.show_music_catalog(["lotr", "mighty", "pirates", "ride", "stalker", "transformers", "tullia"])
	page.show_music({"track":"ride", "volume_to":-18.0}, "ride · 2:14 · fading to 13%", true)
	page.show_tab(ClipboardPage.Tab.MUSIC)
	var glass := board.get("_screen") as SubViewport
	# THE BUILD STAMP IN THE PAGE'S LOWER RIGHT: a picture of a page is a screenshot too (`BuildStamp`, 2026-09-18).
	BuildStamp.attach_to(glass)
	glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for _i in range(5): await RenderingServer.frame_post_draw
	var result := glass.get_texture().get_image().save_png(OUT)
	print("[music_shot] %s -> %s" % [error_string(result), ProjectSettings.globalize_path(OUT)])
	print("RESULT=%s" % ("PASS" if result == OK else "FAIL"))
	get_tree().quit(0 if result == OK else 1)
