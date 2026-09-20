extends Node
## THE TIME TAB, AS A PERSON SEES IT, on the machine that decides the sky and on one that joined: the three times, the
## CLOUDS switch, and the line that says whose sky it is -- and on the joiner, the board after it pressed DAY and was
## refused. Saved as PNGs for a human to look at.
##
##   Godot --path cockpit --xr-mode off res://tests/sky_shot.tscn
##
## NOT HEADLESS: headless has no rendering device and the picture comes back black. A PROBE, because whether the words
## read on a board in the hand has no assertion; tests/sky_peers.gd holds what the words and the switch do across three
## real machines, and tests/clipboard.gd that the tab fits.
##
## THE JOINER IS A SOCKET THAT NEVER ARRIVES: `Net.join` to a port nobody listens on makes this machine networked and not
## the host, which is exactly the question `Net.decides_the_sky` asks, and nothing else about a session is in the picture.
## The refusal is `Net.choose_time`'s own sentence, said on the board as `FlightLevel._say_the_sky_is_not_ours` says it.
##
## Read RESULT=, not the exit code.

const HOST_SHOT: String = "user://sky_shot_host.png"
const JOINER_SHOT: String = "user://sky_shot_joiner_refused.png"
## A port nothing listens on: tests/sky_peers.gd's range, past its last.
## 47947 of this checkout's block (`TestPorts`), asked silently at load whether anything holds it: a fixed
## number was the same socket in every lane. Held, and the suite says PORT BUSY at once rather than timing out.
static var NOBODY_PORT: int = TestPorts.first_free(47947, 1)
## And the host's, the port below it.
static var HOST_PORT: int = TestPorts.first_free(47946, 1)


func _ready() -> void:
	if NOBODY_PORT == 0 or HOST_PORT == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(47946, 2))
		get_tree().quit(1)
		return
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

	# THE HOST'S BOARD: a quarter to six at a minute a second, no clouds, as a host that has just chosen them sees it -- the
	# clock, the sky's words and the rate in the readout, and 60X lit.
	Net.host(HOST_PORT)
	page.show_time(17.0 * 60.0 + 45.0)
	page.show_rate(60.0)
	page.show_clouds(false)
	page.show_tab(ClipboardPage.Tab.TIME)
	var host_saved: int = await _save(glass, HOST_SHOT)
	Net.leave("probe")

	# THE JOINER'S BOARD, after pressing DAY under its host's night.
	Net.join("127.0.0.1", NOBODY_PORT)
	page.show_tab(ClipboardPage.Tab.TIME)
	page.chose_clock.connect(func(minutes: float) -> void:
		var why: String = Net.choose_clock(minutes)
		if why != "":
			page.say_no(why))
	for button in page.find_children("*", "Button", true, false):
		if (button as Button).text == "DAY":
			(button as Button).pressed.emit()
	var joiner_said: String = page.said_text()
	var joiner_saved: int = await _save(glass, JOINER_SHOT)
	Net.leave("probe")

	print("[sky_shot] host %s -> %s" % [error_string(host_saved), ProjectSettings.globalize_path(HOST_SHOT)])
	print("[sky_shot] joiner said '%s', %s -> %s" % [joiner_said, error_string(joiner_saved),
		ProjectSettings.globalize_path(JOINER_SHOT)])
	var ok: bool = host_saved == OK and joiner_saved == OK and joiner_said.begins_with("The host sets")
	print("RESULT=%s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _save(glass: SubViewport, path: String) -> int:
	for i in range(4):
		await RenderingServer.frame_post_draw
	return glass.get_texture().get_image().save_png(path)
