extends Node
## THE WAYS INTO SOMEBODY ELSE'S GAME, AS A PERSON SEES THEM: the desk's session screen with the join code's keypad up
## and a refusal under it, the same screen with a list of games on it, and the board in the hand carrying the code on a
## tab that is not CREW -- three PNGs for a human to look at.
##
##   Godot --path cockpit res://tests/code_pad_shot.tscn
##
## NOT HEADLESS. Headless has no rendering device and the picture comes back a black rectangle. A PROBE, because whether
## thirty-two keys read on a screen 62 cm wide at a desk's distance has no assertion: tests/code_pad.gd holds that every
## key is on the glass and presses, and this is what that looks like.
##
## Read RESULT=, not the exit code.

const DESK := preload("res://world/desk.tscn")
const SHOT: String = "user://code_pad_shot.png"
const GAMES_SHOT: String = "user://code_pad_shot_games.png"
const BOARD_SHOT: String = "user://code_pad_shot_board.png"
## Who somebody else's host is, as the paper directory knows them.
const THEIR_HOST: int = 76561190000000900


func _ready() -> void:
	var desk := DESK.instantiate() as DeskRoom
	add_child(desk)
	for i in range(6):
		await get_tree().process_frame
	var panel := desk.get("_panel") as TouchPanel
	var menu := panel.shown() as SessionMenu if panel != null else null
	if menu == null:
		print("[code_pad_shot] RESULT=FAIL no session screen")
		get_tree().quit(1)
		return
	menu.show_pad(true)
	var pad := menu.find_children("*", "CodePad", true, false)[0] as CodePad
	for symbol in "K7MQ2":
		pad.press_key(symbol)
	menu.say(JoinCode.why_not(pad.shown_code()))
	var screen := panel.get("_screen") as SubViewport
	# THE BUILD STAMP IN THE PAGE'S LOWER RIGHT: a picture of a page is a screenshot too (`BuildStamp`, 2026-09-18).
	BuildStamp.attach_to(screen)
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = screen.get_texture().get_image()
	var saved: int = picture.save_png(SHOT)
	print("[code_pad_shot] %s x %s, shows '%s', saved %s to %s" % [picture.get_width(), picture.get_height(),
		pad.shown_code(), error_string(saved), ProjectSettings.globalize_path(SHOT)])

	# AND THE SAME SCREEN LOOKING FOR OTHER PLAYERS: a list of games on paper, one of every kind of row -- joinable, full,
	# a release behind, a level this game does not have -- because the question nothing can assert is whether a row reads
	# at a desk's distance. tests/code_pad.gd holds that all of it is on the glass and presses.
	var paper := PaperLobbyDirectory.new()
	Net.lobbies = paper
	paper.put(_a_lobby("R4TN8W", Net.level, Net.build()), 3, Net.MAX_PLAYERS, THEIR_HOST, 0)
	paper.put(_a_lobby("PNS8L6", Net.level, Net.build()), 1, Net.MAX_PLAYERS, THEIR_HOST, 0)
	paper.put(_a_lobby("J2KD5Y", Net.level, Net.build()), 2, Net.MAX_PLAYERS, THEIR_HOST, 0)
	paper.put(_a_lobby("BBBBBB", Net.level, Net.build()), Net.MAX_PLAYERS, Net.MAX_PLAYERS, THEIR_HOST, 0)
	paper.put(_a_lobby("CCCCCC", Net.level, "a release behind"), 1, Net.MAX_PLAYERS, THEIR_HOST, 0)
	paper.put(_a_lobby("DDDDDD", "nowhere", Net.build()), 1, Net.MAX_PLAYERS, THEIR_HOST, 0)
	menu.show_games(true)
	Net.look_for_games()
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var games: Image = screen.get_texture().get_image()
	var saved_games: int = games.save_png(GAMES_SHOT)
	print("[code_pad_shot] games list %s x %s, saved %s to %s" % [games.get_width(), games.get_height(),
		error_string(saved_games), ProjectSettings.globalize_path(GAMES_SHOT)])
	Net.lobbies = SteamLobbyDirectory.new()

	# AND THE CODE WHERE A FLYING HOST READS IT: the board in the hand, on CRAFT -- the tab it opens on, and not the one
	# the code used to live under. The code is set by hand, because what is being looked at is the line on the page and
	# not a session -- tests/steam_join.gd holds that a real host's board says it.
	desk.queue_free()
	var board := TouchPanel.new()
	board.page = preload("res://ui/menus/clipboard_page.tscn")
	board.size = Vector2(0.34, 0.25)
	board.pixels = 1024
	add_child(board)
	await get_tree().process_frame
	var page := board.shown() as ClipboardPage
	Net.session_code = "PNS8L6"
	page.show_tab(ClipboardPage.Tab.CRAFT)
	page.tick()
	var glass := board.get("_screen") as SubViewport
	# THE BUILD STAMP IN THE PAGE'S LOWER RIGHT: a picture of a page is a screenshot too (`BuildStamp`, 2026-09-18).
	BuildStamp.attach_to(glass)
	glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var crew: Image = glass.get_texture().get_image()
	var saved_crew: int = crew.save_png(BOARD_SHOT)
	print("[code_pad_shot] board on CRAFT %s x %s, says '%s', saved %s to %s" % [crew.get_width(), crew.get_height(),
		page.code_text(), error_string(saved_crew), ProjectSettings.globalize_path(BOARD_SHOT)])
	Net.session_code = ""
	var all_saved: bool = saved == OK and saved_crew == OK and saved_games == OK
	print("[code_pad_shot] RESULT=%s" % ("PASS" if all_saved else "FAIL"))
	get_tree().quit(0 if all_saved else 1)


## A LOBBY AS SOMEBODY ELSE'S HOST WOULD HAVE WRITTEN IT.
func _a_lobby(code: String, level: String, build: String) -> Dictionary:
	var chart: LevelChart = ChartDrawer.chart(level)
	return {"game": Net.GAME_TAG, "code": code, "build": build, "compatibility": Net.compatibility(),
		"host": str(THEIR_HOST), "level": level,
		"level_hash": chart.content_hash if chart != null else ""}
