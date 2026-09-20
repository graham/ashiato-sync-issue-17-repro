extends Node
## THE CREW PAGE, AS A PERSON SEES IT: the clipboard's CREW tab full -- four craft, eight players and the Steam code --
## the same page with a refusal at the head of the list, nearly empty -- your own craft and nobody else -- and a crew
## with one player on a build two days older than this one, saved as PNGs for a human to look at.
##
##   Godot --path cockpit res://tests/crew_shot.tscn
##
## NOT HEADLESS. Headless has no rendering device and the picture comes back a black rectangle. A PROBE, because whether
## a seat's role and a JOIN read on a board in your hand has no assertion: tests/clipboard.gd holds that the full page is
## on the glass without scrolling and that the beam on JOIN seats you, and this is what that looks like.
##
## The board is the clipboard's own size and density (`Clipboard.SIZE`, `Clipboard.PIXELS` across), and the pages are handed
## manifests rather than a session, because what is being looked at is the page: the full one is the same
## `full_manifest` the fit check measures.
##
## Read RESULT=, not the exit code.

const FULL_SHOT: String = "user://crew_shot_full.png"
const EMPTY_SHOT: String = "user://crew_shot_alone.png"
const REFUSED_SHOT: String = "user://crew_shot_refused.png"
const MANY_SHOT: String = "user://crew_shot_ten.png"
const MANY_SCROLLED_SHOT: String = "user://crew_shot_ten_scrolled.png"
const BUILDS_SHOT: String = "user://crew_shot_builds.png"
const STEAM_NAMES_SHOT: String = "user://crew_shot_steam_names.png"
const CLIPBOARD_TEST := preload("res://tests/clipboard.gd")


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
	page.show_tab(ClipboardPage.Tab.CREW)
	var full: Array = CLIPBOARD_TEST.full_manifest()
	page.show_crew(full, {})
	var full_saved: int = await _save(glass, FULL_SHOT)

	# REFUSED: a JOIN pressed on the page, and the host's answer that somebody else has the seat, as a player sees it.
	(page.find_child("Join193_3", true, false) as Button).pressed.emit()
	page.show_crew(full, {"count": 1, "why": "seat_taken"})
	var refused_saved: int = await _save(glass, REFUSED_SHOT)
	Net.session_code = ""

	# NEARLY EMPTY: your own aeroplane, you in the pilot's seat, and nobody else in the session.
	var alone: Array = CrewManifest.read([{"client": 1, "vehicle": 7, "seat": 0}], {7: {"kind": Sim.Kind.PLANE}}, 1)
	# A FRESH PAGE's worth of answer: `show_tab` keeps the last answer, so the board is rebuilt for the lonely picture.
	board.queue_free()
	board = TouchPanel.new()
	board.page = preload("res://ui/menus/clipboard_page.tscn")
	board.size = Clipboard.SIZE
	board.pixels = Clipboard.PIXELS
	add_child(board)
	await get_tree().process_frame
	page = board.shown() as ClipboardPage
	glass = board.get("_screen") as SubViewport
	# THE BUILD STAMP IN THE PAGE'S LOWER RIGHT: a picture of a page is a screenshot too (`BuildStamp`, 2026-09-18).
	BuildStamp.attach_to(glass)
	glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	page.show_tab(ClipboardPage.Tab.CREW)
	page.show_crew(alone, {})
	var alone_saved: int = await _save(glass, EMPTY_SHOT)

	# TEN CRAFT, MORE THAN FIT: the top of the list, then the thumb's worth of scrolling to its end.
	page.show_crew(CLIPBOARD_TEST.many_manifest(10), {})
	var many_saved: int = await _save(glass, MANY_SHOT)
	var scroll := page.get("_scroll") as ScrollContainer
	scroll.scroll_vertical = 100000
	var scrolled_saved: int = await _save(glass, MANY_SCROLLED_SHOT)

	# ON ANOTHER BUILD (lane/buildtime, 2026-09-19): two craft, three players, and one of them on a build of this commit
	# made two days earlier, as the host's CREW page says it. The roster is what every machine holds; its times are the
	# host's, from each player's hi.
	scroll.scroll_vertical = 0
	var mine: int = int(Net.identity()["built"])
	var was: Dictionary = Net.roster
	Net.roster = {
		1: {"player": 1, "name": "HOST", "colour": 0, "built": mine},
		2: {"player": 2, "name": "MAVERICK", "colour": 2, "built": mine - 2 * 86400 - 600},
		3: {"player": 3, "name": "GOOSE", "colour": 5, "built": mine},
	}
	page.show_crew(CrewManifest.read([{"client": 1, "vehicle": 7, "seat": 0}, {"client": 3, "vehicle": 7, "seat": 1},
		{"client": 2, "vehicle": 8, "seat": 0}], {7: {"kind": Sim.Kind.PLANE, "position": Vector3.ZERO},
			8: {"kind": Sim.Kind.PLANE, "position": Vector3(2400.0, 500.0, 0.0)}}, 1), {})
	var builds_saved: int = await _save(glass, BUILDS_SHOT)

	# STEAM NAMES, NOT "PLAYER N" (lane/buildtime, 2026-09-19): the same crew as every machine lists it once each card
	# carries its player's Steam persona. Test personas, never a real account's.
	Net.roster = {
		1: {"player": 1, "name": "HOST", "colour": 0, "built": mine},
		2: {"player": 2, "name": "kestrel_77", "colour": 2, "built": mine},
		3: {"player": 3, "name": "Sam Flies", "colour": 5, "built": mine},
	}
	page.show_crew(CrewManifest.read([{"client": 1, "vehicle": 7, "seat": 0}, {"client": 3, "vehicle": 7, "seat": 1},
		{"client": 2, "vehicle": 8, "seat": 0}], {7: {"kind": Sim.Kind.PLANE, "position": Vector3.ZERO},
			8: {"kind": Sim.Kind.PLANE, "position": Vector3(2400.0, 500.0, 0.0)}}, 1), {})
	var names_saved: int = await _save(glass, STEAM_NAMES_SHOT)
	Net.roster = was
	builds_saved = builds_saved if names_saved == OK else names_saved

	var all_saved: bool = full_saved == OK and alone_saved == OK and refused_saved == OK and many_saved == OK \
		and scrolled_saved == OK and builds_saved == OK
	print("[crew_shot] RESULT=%s" % ("PASS" if all_saved else "FAIL"))
	get_tree().quit(0 if all_saved else 1)


func _save(glass: SubViewport, path: String) -> int:
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = glass.get_texture().get_image()
	var saved: int = picture.save_png(path)
	print("[crew_shot] %s x %s, saved %s to %s" % [picture.get_width(), picture.get_height(), error_string(saved),
		ProjectSettings.globalize_path(path)])
	return saved
