extends Node
## Headless: can the desk's screens be pointed at and pressed with the trigger, the way the clipboard is?
##
##   Godot --headless --path cockpit res://tests/desk_screens.tscn
##
## Asked for on 2026-09-13: "make sure the monitor screens on the opening main menu level allow for pointing and clicking
## like the ipad, so i don't have to collide with the button". The beam already reached both screens -- but only while
## no board was up. `PilotRig._point_a_hand` aimed the board ALONE while it was, so with the clipboard out the monitors
## could not be pointed at at all. The fix lifted the beam into `HandBeam`, which takes every glass and aims the nearest.
##
## THROUGH THE RIG'S SEAMS, `force_hand` and `force_input`, the ones a headset's hand and trigger arrive by, against the
## real desk, the real rig and the real pages. What a door or a session button would DO is taken off first -- the desk's
## own handlers would leave the desk -- because what is under test is which button a pull reaches, not the flight.
##
## Each aim is worked out from the button's own rectangle on its own panel, the inverse of `TouchPanel._pixel_at`, so a
## screen moved on the desk moves the aim with it. The beam section that used to live in tests/session.gd moved here.
##
## AND A THIRD SCREEN, for the level (asked for on 2026-09-15: "add a third monitor and reposition the other two so that
## they all fit on the desk"). Three sections hold it: the three stand inside the desk top and clear of each other,
## measured from their meshes' vertices; the levels screen has a row for every level folder, read off the folder here;
## and a pull on a level makes it the one the next session flies, through the desk's own handler.
##
## Read RESULT=, not the exit code.

const DESK := preload("res://world/desk.tscn")
## How far out from the glass the hand is put, along its normal, in metres. The beam's length is checked against it.
const HAND_OFF: float = 0.30

## Where section 9 hosts the session it quits out of: THIS CHECKOUT's (`TestPorts`), asked silently at load. It was
## `Net.host()`, which is 7788 -- one socket for every lane's `desk_screens` and for a developer's own game.
static var PORT: int = TestPorts.first_free(47914)
var _failures: PackedStringArray = []
var _sections: int = 0
var _desk: DeskRoom = null
var _rig: PilotRig = null
var _sessions: TouchPanel = null
var _doors: TouchPanel = null
var _charts: TouchPanel = null
## What each page announced, since last cleared.
var _asked_session: Array = []
var _asked_door: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[desk_screens] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if PORT == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(47914))
		get_tree().quit(1)
		return
	await _sit_at_the_desk()
	if _rig == null:
		_finish()
		return
	# FIRST, before any aim has lit a pointer dot on a glass.
	await _the_three_screens_stand_on_the_desk_clear_of_its_edges_and_each_other()
	await _a_pull_on_either_screen_presses_the_button_it_is_on()
	await _a_pull_already_held_presses_nothing()
	await _off_a_button_or_off_the_glass_a_pull_presses_nothing()
	await _with_the_clipboard_up_the_nearest_glass_takes_the_pull()
	await _a_mouse_on_a_desk_clicks_the_monitors()
	await _the_levels_screen_has_a_row_for_every_level_folder()
	await _a_pull_on_a_level_makes_it_the_level_the_next_session_flies()
	# LAST, because its second pull leaves the desk going. See the section.
	await _quit_takes_two_pulls_and_ends_the_session()
	_check("every_section_of_the_suite_ran", _sections == 9, "%d of 9" % _sections)
	_finish()


## The desk, as the router opens it, with what its pages mean taken off and listened to instead.
func _sit_at_the_desk() -> void:
	_desk = DESK.instantiate() as DeskRoom
	add_child(_desk)
	await _frames(4)
	_rig = _desk.get("_rig") as PilotRig
	_sessions = _desk.get("_panel") as TouchPanel
	_doors = _desk.get("_doors") as TouchPanel
	_charts = _desk.get("_charts") as TouchPanel
	var menu := _sessions.shown() as SessionMenu if _sessions != null else null
	var levels := _doors.shown() as LevelMenu if _doors != null else null
	var charts := _charts.shown() as ChartMenu if _charts != null else null
	_check("the_desk_has_a_rig_and_all_three_screens", _rig != null and menu != null and levels != null and charts != null,
		"rig %s, sessions %s, doors %s, levels %s" % [_rig, menu, levels, charts])
	if _rig == null or menu == null or levels == null or charts == null:
		_rig = null
		return
	if menu.chose.is_connected(Callable(_desk, "_on_chose")):
		menu.chose.disconnect(Callable(_desk, "_on_chose"))
	if levels.chose.is_connected(Callable(_desk, "_on_door")):
		levels.chose.disconnect(Callable(_desk, "_on_door"))
	# THE BOARD'S WAY OUT TOO: a pull that lands on the clipboard's MAIN MENU would take this suite back to a new desk.
	if _rig.clipboard.chose_menu.is_connected(Doors.to_the_desk):
		_rig.clipboard.chose_menu.disconnect(Doors.to_the_desk)
	menu.chose.connect(func(what: String, _detail: String): _asked_session.append(what))
	levels.chose.connect(func(level: String, _kind: int): _asked_door.append(level))


## ---- 1: a button on each screen ------------------------------------------------------------------------------

func _a_pull_on_either_screen_presses_the_button_it_is_on() -> void:
	var solo := _button(_sessions, "Fly on your own")
	var hall := _button(_doors, "Hall of cockpits")
	_check("each_screen_has_the_button_to_point_at", solo != null and hall != null, "solo %s, hall %s" % [solo, hall])
	if solo == null or hall == null:
		_sections += 1
		return
	_clear()
	_aim_at(_sessions, _centre_of(solo))
	await _frames(2)
	var beam := _rig.get("_beam") as MeshInstance3D
	_check("at_the_desk_the_right_hand_has_a_beam", beam != null and beam.visible, "%s" % [beam])
	_check("and_aimed_at_the_left_screen_it_reaches_exactly_to_the_glass",
		beam != null and absf(beam.scale.z - HAND_OFF) < 0.01, "length %s" % [_length(beam)])
	await _pull()
	_check("and_one_pull_presses_that_button_once", _asked_session == ["solo"] and _asked_door.is_empty(),
		"sessions %s, doors %s" % [_asked_session, _asked_door])

	# THE OTHER SCREEN, and the highlight: the door lights under the beam before it is pressed.
	_clear()
	_aim_at(_doors, _centre_of(hall))
	await _frames(2)
	_check("aimed_at_a_door_on_the_right_screen_the_door_lights_up", hall.is_hovered(), "hovered %s" % hall.is_hovered())
	await _pull()
	_check("and_one_pull_opens_that_door_and_nothing_on_the_other_screen",
		_asked_door == ["hall"] and _asked_session.is_empty(), "doors %s, sessions %s" % [_asked_door, _asked_session])
	_let_go()
	_sections += 1


## ---- 2: a squeezed trigger swept on --------------------------------------------------------------------------

## A PULL ALREADY HELD WHEN THE BEAM ARRIVES presses nothing: sweeping a squeezed trigger across a menu is not a way to
## press everything on it. From off the glass, and from the OTHER screen, which is the case one edge per glass got wrong.
func _a_pull_already_held_presses_nothing() -> void:
	var solo := _button(_sessions, "Fly on your own")
	var hall := _button(_doors, "Hall of cockpits")
	_clear()
	_aim_away(_sessions)
	_rig.force_input(1, Bind.TRIGGER, 1.0)
	await _frames(2)
	_aim_at(_sessions, _centre_of(solo))
	await _frames(2)
	_aim_at(_doors, _centre_of(hall))
	await _frames(2)
	_rig.force_input(1, Bind.TRIGGER, 0.0)
	await _frames(2)
	_check("a_pull_held_from_off_the_glass_onto_one_screen_and_across_to_the_other_presses_nothing",
		_asked_session.is_empty() and _asked_door.is_empty(), "sessions %s, doors %s" % [_asked_session, _asked_door])
	_let_go()
	_sections += 1


## ---- 3: near misses --------------------------------------------------------------------------------------------

## JUST OFF A BUTTON, still on the glass: the beam stops at the glass and a pull presses nothing. The gap between two
## doors is a few pixels of page, which is the nearest a real miss gets. And OFF THE GLASS: the beam keeps its own
## length, the door that was lit goes out, and a pull presses nothing.
func _off_a_button_or_off_the_glass_a_pull_presses_nothing() -> void:
	var hall := _button(_doors, "Hall of cockpits")
	var deck := _button(_doors, "Carrier deck")
	var beam := _rig.get("_beam") as MeshInstance3D
	_clear()
	var between := Vector2(hall.get_global_rect().get_center().x,
		(hall.get_global_rect().end.y + deck.get_global_rect().position.y) * 0.5)
	_aim_at(_doors, between)
	await _frames(2)
	await _pull()
	_check("aimed_between_two_doors_the_beam_is_on_the_glass_and_a_pull_opens_neither",
		_asked_door.is_empty() and beam != null and absf(beam.scale.z - HAND_OFF) < 0.01,
		"doors %s, length %s, gap %s px" % [_asked_door, _length(beam), deck.get_global_rect().position.y
			- hall.get_global_rect().end.y])

	_aim_at(_doors, _centre_of(hall))
	await _frames(2)
	var lit: bool = hall.is_hovered()
	_aim_away(_doors)
	await _frames(2)
	await _pull()
	_check("aimed_off_the_glass_the_beam_keeps_its_own_length_the_door_goes_out_and_a_pull_opens_nothing",
		lit and not hall.is_hovered() and _asked_door.is_empty() and beam != null
			and absf(beam.scale.z - PilotRig.BEAM_REACH) < 0.001,
		"lit first %s, lit now %s, doors %s, length %s" % [lit, hall.is_hovered(), _asked_door, _length(beam)])
	_let_go()
	_sections += 1


## ---- 4: the board in the hand and the screen behind it -------------------------------------------------------

## THE CLIPBOARD UP, HELD RIGHT IN THE BEAM between the hand and a monitor button: the board is the glass in front, so
## the beam stops at it and the monitor behind hears nothing. Then the SAME aim with the board held off to one side:
## the monitor presses -- which is what could not happen before, with the board up -- and the board's highlighted
## control is not pressed with it, because the one pull is the beam's.
func _with_the_clipboard_up_the_nearest_glass_takes_the_pull() -> void:
	var board: Clipboard = _rig.clipboard
	var solo := _button(_sessions, "Fly on your own")
	var beam := _rig.get("_beam") as MeshInstance3D
	board.show_board(true)
	var page: ClipboardPage = board.page()
	page.show_tab(ClipboardPage.Tab.CRAFT)
	await _frames(3)
	var decoy: Button = null
	# ANY CRAFT BUTTON ON SHOW. It named the pod's, which since the page grouped its craft (lane/kinds, 2026-09-18) is in
	# GROUND and hidden while the page opens on AEROPLANES: "highlighted nothing". Which craft does not matter; that one is
	# highlighted, and on the glass, does.
	for node in page.find_children("*", "Button", true, false):
		if (node as Button).is_visible_in_tree() and Sim.Kind.keys().has(String((node as Button).text).to_upper()):
			decoy = node as Button
			break
	var asked_kind: Array = []
	var listen := func(kind: int): asked_kind.append(kind)
	page.chose_kind.connect(listen)

	# IN FRONT: the board's glass square across the ray, halfway between the hand and the monitor.
	_clear()
	var hand_at: Transform3D = _aim_at(_sessions, _centre_of(solo))
	var along: Vector3 = -hand_at.basis.z
	_hold_the_board_at(board, Transform3D(Basis.looking_at(along, _sessions.global_basis.y), hand_at.origin
		+ along * HAND_OFF * 0.5))
	await _frames(3)
	await _pull()
	_check("with_the_clipboard_held_in_the_beam_the_beam_stops_at_the_board",
		board.is_aimed() and beam != null and absf(beam.scale.z - HAND_OFF * 0.5) < 0.01,
		"on the board %s, length %s" % [board.is_aimed(), _length(beam)])
	_check("and_the_monitor_behind_it_hears_nothing", _asked_session.is_empty(), "sessions %s" % [_asked_session])

	# NEAREST ALONG THE RAY, NOT NEAREST THE HAND (team-lead, 2026-09-13). The hand 8 cm off the left monitor's glass,
	# pointing along that glass and away from the other screen, so the ray never crosses it; the board 40 cm down the
	# ray. The monitor is five times nearer the hand than the board is, and the board is the only glass the beam crosses.
	# 8 cm is past `TouchPanel.FINGER`, so the fingertip only hovers the monitor and cannot press it.
	_clear()
	var beside: Vector3 = _sessions.global_position + _sessions.global_basis.z.normalized() * 0.08
	var sideways: Vector3 = -_sessions.global_basis.x.normalized()
	_rig.force_hand(1, Transform3D(Basis.looking_at(sideways, _sessions.global_basis.y), beside))
	_hold_the_board_at(board, Transform3D(Basis.looking_at(sideways, _sessions.global_basis.y), beside + sideways * 0.40))
	await _frames(3)
	await _pull()
	_check("a_monitor_nearer_the_hand_but_off_the_ray_loses_to_the_board_the_ray_crosses",
		board.is_aimed() and beam != null and absf(beam.scale.z - 0.40) < 0.01 and _asked_session.is_empty(),
		"on the board %s, length %s, sessions %s" % [board.is_aimed(), _length(beam), _asked_session])

	# TO ONE SIDE: the board a quarter of a metre down from the ray, and the same aim at the same monitor button.
	_clear()
	asked_kind.clear()
	if decoy != null:
		decoy.grab_focus()
	_hold_the_board_at(board, Transform3D(Basis.looking_at(along, _sessions.global_basis.y), hand_at.origin
		+ along * HAND_OFF * 0.5 - _sessions.global_basis.y * 0.25))
	_aim_at(_sessions, _centre_of(solo))
	await _frames(3)
	await _pull()
	_check("with_the_clipboard_up_but_to_one_side_the_beam_reaches_the_monitor_and_presses_it",
		_asked_session == ["solo"] and beam != null and absf(beam.scale.z - HAND_OFF) < 0.01,
		"sessions %s, length %s, on the board %s" % [_asked_session, _length(beam), board.is_aimed()])
	_check("and_the_boards_highlighted_control_is_not_pressed_with_it", decoy != null and asked_kind.is_empty(),
		"highlighted %s, asked for %s" % [decoy.text if decoy != null else "nothing", asked_kind])
	page.chose_kind.disconnect(listen)
	board.show_board(false)
	_rig.force_hand(0, null)
	_let_go()
	_sections += 1


## ---- 5: a mouse, on a monitor --------------------------------------------------------------------------------------

## A DESK HAS NO HAND TO POINT WITH, SO THE MOUSE POINTS. Found on 2026-09-14 while building the join code's keypad: the
## rig offered the mouse to the clipboard alone, so without a headset nothing on the desk's two screens could be clicked
## -- not a session, not a door, not a key. Driven by real mouse events in WINDOW coordinates: the button's centre on the
## glass, projected through the desk camera, then through the viewport's final transform (testing_godot_headless.md:
## headless under `canvas_items` that transform is a twentieth scale, and a click at a canvas point hits nothing).
func _a_mouse_on_a_desk_clicks_the_monitors() -> void:
	_rig.force_hand(0, null)
	_rig.force_hand(1, null)
	_rig.force_input(1, Bind.TRIGGER, null)
	var on_a_monitor: bool = bool(_rig.get("using_desktop"))
	_check("the_desk_rig_is_on_a_monitor", on_a_monitor, "using_desktop %s" % on_a_monitor)
	var solo := _button(_sessions, "Fly on your own")
	var hall := _button(_doors, "Hall of cockpits")
	_clear()
	await _click_with_the_mouse(_sessions, solo)
	_check("a_mouse_click_on_a_session_button_presses_it", _asked_session == ["solo"] and _asked_door.is_empty(),
		"sessions %s, doors %s, cursor mode %s" % [_asked_session, _asked_door, Input.mouse_mode])
	_clear()
	await _click_with_the_mouse(_doors, hall)
	_check("and_one_on_a_door_on_the_other_screen_opens_that_door", _asked_door == ["hall"] and _asked_session.is_empty(),
		"doors %s, sessions %s" % [_asked_door, _asked_session])
	# A HELD BUTTON BROUGHT ONTO A SCREEN PRESSES NOTHING: the beam's rule, which the mouse has to keep too.
	_clear()
	_move_the_mouse(Vector2(-4000.0, -4000.0))
	await _frames(2)
	_mouse_button(true)
	await _frames(2)
	_move_the_mouse(_window_point(_sessions, solo))
	await _frames(2)
	_mouse_button(false)
	await _frames(2)
	_check("and_a_button_already_held_when_the_mouse_arrives_presses_nothing", _asked_session.is_empty(),
		"sessions %s" % [_asked_session])
	_sections += 1


## ---- 0: three screens on one desk --------------------------------------------------------------------------------

## THE THREE STAND ON THE DESK TOP, INSIDE ITS EDGES, AND CLEAR OF EACH OTHER. Each screen's box and the desk top's are
## measured from every vertex of every surface of their meshes, carried into the world by each mesh's own global
## transform -- not `transform * get_aabb()`, which is the box round a box and grows with every turn. A screen's frame
## must rest on the wood within 5 mm, not sunk and not floating, and no two screens' boxes may meet: boxes, not
## shapes, because the layout was worked out so that its boxes do not (`DeskRoom.SCREEN_WIDTH`).
func _the_three_screens_stand_on_the_desk_clear_of_its_edges_and_each_other() -> void:
	var slab: MeshInstance3D = null
	for node in _desk.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh \
				and ((node as MeshInstance3D).mesh as BoxMesh).size == DeskRoom.DESK:
			slab = node as MeshInstance3D
	var top: AABB = _box_of([slab]) if slab != null else AABB()
	var boxes: Array[AABB] = []
	var wrong: Array[String] = []
	var named: Array[String] = ["levels", "sessions", "doors"]
	var screens: Array[TouchPanel] = [_charts, _sessions, _doors]
	for i in range(screens.size()):
		var parts: Array = []
		for node in screens[i].find_children("*", "MeshInstance3D", true, false):
			if node.name != "Pointer":
				parts.append(node)
		var box: AABB = _box_of(parts)
		boxes.append(box)
		if box.position.x < top.position.x or box.end.x > top.end.x or box.position.z < top.position.z \
				or box.end.z > top.end.z:
			wrong.append("%s over an edge: x %.3f..%.3f, z %.3f..%.3f" % [named[i], box.position.x, box.end.x,
				box.position.z, box.end.z])
		if absf(box.position.y - top.end.y) > 0.005:
			wrong.append("%s's foot at %.4f" % [named[i], box.position.y])
	_check("each_of_the_three_screens_stands_on_the_desk_top_inside_its_edges", slab != null and wrong.is_empty(),
		"desk x %.3f..%.3f, z %.3f..%.3f, top %.3f; %s" % [top.position.x, top.end.x, top.position.z, top.end.z, top.end.y,
			wrong if not wrong.is_empty() else "screens x %s" % [boxes.map(func(b: AABB): return "%.3f..%.3f" % [b.position.x,
				b.end.x])]])
	var meeting: Array[String] = []
	for i in range(boxes.size()):
		for j in range(i + 1, boxes.size()):
			if boxes[i].intersects(boxes[j]):
				meeting.append("%s and %s" % [named[i], named[j]])
	_check("and_no_two_screens_boxes_meet", meeting.is_empty(), "%s; %.1f cm apart at the nearest" % [meeting,
		100.0 * minf(boxes[1].position.x - boxes[0].end.x, boxes[2].position.x - boxes[1].end.x)])
	# AND EVERYTHING ON EACH PAGE IS ON ITS GLASS. Every page's words were made bigger on 2026-09-15, when the screens
	# shrank to fit three, so the smallest is 20 px (12.8 headset px from the chair). A page that outgrew its glass
	# would lose its last buttons off the bottom. So every visible control's rectangle must lie inside its page's pixels.
	var spilt: Array[String] = []
	var looked: int = 0
	for i in range(screens.size()):
		var pixels := Rect2(Vector2.ZERO, Vector2((screens[i].get("_screen") as SubViewport).size)).grow(0.5)
		for node in screens[i].shown().find_children("*", "Control", true, false):
			var control := node as Control
			if not control.is_visible_in_tree():
				continue
			looked += 1
			if not pixels.encloses(control.get_global_rect()):
				spilt.append("%s: %s at %s" % [named[i], control.get_class(), control.get_global_rect()])
	_check("and_everything_on_each_page_is_on_its_glass", looked > 0 and spilt.is_empty(),
		"%d controls; %s" % [looked, spilt.slice(0, 4)])
	_sections += 1


## ---- 7: the levels screen ------------------------------------------------------------------------------------------

## EVERY LEVEL FOLDER IS A ROW, AND NOTHING ELSE IS. Asked for on 2026-09-15: "a monitor so I can choose different levels
## (since we now have the starter island and the terrain level, and we'll probably have more in the future)". The ids
## are read off the folder here, `DirAccess` on `ChartDrawer.folder` with `_` folders skipped, and not from the drawer
## the desk asks, so a screen handed a typed list or only some of the levels reads red. Every level the game ships is
## usable; tests/levels.gd holds that a refused one is kept off.
func _the_levels_screen_has_a_row_for_every_level_folder() -> void:
	var shelf := _charts.shown() as ChartMenu
	var folders: Array = []
	for id in DirAccess.get_directories_at(ChartDrawer.folder):
		if not id.begins_with("_"):
			folders.append(id)
	folders.sort()
	var rows: Array = shelf.level_buttons.keys()
	rows.sort()
	_check("the_levels_screen_has_a_row_for_every_level_folder_and_no_other", not folders.is_empty() and rows == folders,
		"folders %s, rows %s" % [folders, rows])
	await _and_the_page_still_fits_when_the_game_grows(shelf)
	_sections += 1


## AND IT STILL FITS WHEN SOMEBODY ADDS A LEVEL. A level is a folder anybody may drop in (building_a_game_here.md, rule
## 7), and on 2026-09-17 the SIXTH one pushed this page 224 px off its own glass. The check above that should have
## caught it did -- but only after the level existed, and the second failure was the one that mattered: a beam aimed at
## a row that had fallen off the screen pressed nothing, so choosing that level silently did nothing at all.
##
## So the page is handed more levels than the game has and held to the same glass. TWELVE, because the rule is that the
## rows shrink and then the summaries go, and twelve is past the point where the summaries have to go: a page that only
## survives by shrinking has not been tested past its floor.
func _and_the_page_still_fits_when_the_game_grows(shelf: ChartMenu) -> void:
	var many: Array = []
	for i in range(12):
		var chart := LevelChart.new()
		# THE ID COMES FROM THE FOLDER NAME, which a fabricated chart has not got -- and `level_buttons` is keyed by it,
		# so twelve charts with no id were ONE row twelve times over. The first run of this check said "1 buttons".
		chart.id = "level_%d" % i
		chart._take({"name": "Level number %d" % i, "world": "island",
			"summary": "A level with a summary long enough to wrap on a narrower page than this one is.",
			"spawn": {"at": [0, 30, 0], "yaw_degrees": 0}})
		many.append(chart)
	shelf.show_levels(many, "", false, {"host": "", "solo": ""})
	await _frames(2)
	var pixels := Rect2(Vector2.ZERO, Vector2((_charts.get("_screen") as SubViewport).size)).grow(0.5)
	var spilt: Array[String] = []
	for node in shelf.find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree() and not pixels.encloses(control.get_global_rect()):
			spilt.append("%s at %s" % [control.get_class(), control.get_global_rect()])
	_check("and_twelve_levels_do_not_push_the_page_off_its_glass", spilt.is_empty(),
		"glass %s; %s" % [pixels.size, spilt.slice(0, 3)])
	# WHAT IT SHOWS IS A BEHAVIOUR, NOT A CAPACITY. The first version of this check asserted that all twelve were
	# drawn, which is a number worked out from the page's own constants and would have to be edited every time a font
	# or a margin moved -- the same coupling that made `--stack=100` press nothing. What matters is that the page
	# never draws a row nobody can reach: every row it DOES draw is on the glass, and if it cannot draw them all it
	# says how many it is holding instead of quietly losing the rest.
	var drawn: int = shelf.level_buttons.size()
	_check("and_it_draws_as_many_as_it_can_reach", drawn >= 1 and drawn <= 12, "%d of 12 drawn" % drawn)
	# AND MORE LEVELS THAN ANY SCREEN COULD HOLD. Twelve fit; forty cannot, at any size a person could read, so this is
	# the only way to reach the branch that says so -- and a branch nobody reaches is a branch that rots. What it must
	# NOT do is draw forty rows and lose twenty-eight of them off the bottom, which is precisely how the sixth real
	# level broke this page.
	var crowd: Array = []
	for i in range(40):
		var one := LevelChart.new()
		one.id = "crowd_%d" % i
		one._take({"name": "Level %d" % i, "world": "island", "summary": "One of far too many levels.",
			"spawn": {"at": [0, 30, 0], "yaw_degrees": 0}})
		crowd.append(one)
	shelf.show_levels(crowd, "", false, {"host": "", "solo": ""})
	await _frames(2)
	var over: Array[String] = []
	for node in shelf.find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree() and not pixels.encloses(control.get_global_rect()):
			over.append("%s at %s" % [control.get_class(), control.get_global_rect()])
	var said := shelf.get("_said") as Label
	_check("and_forty_levels_still_do_not_run_off_the_glass", over.is_empty(), "%s" % [over.slice(0, 3)])
	_check("and_the_page_says_how_many_it_is_holding",
		shelf.level_buttons.size() < 40 and said != null and said.text.contains("40"),
		"%d drawn, foot reads '%s'" % [shelf.level_buttons.size(), said.text if said != null else "-"])
	# AND PUT THE REAL LEVELS BACK, because the sections after this one press them.
	shelf.show_levels(ChartDrawer.charts(), Net.level, Net.level_chosen,
		{"host": ChartDrawer.HOSTING, "solo": ChartDrawer.DEFAULT})
	await _frames(2)


## ---- 8: choosing one -----------------------------------------------------------------------------------------------

## A PULL ON A LEVEL MAKES IT THE ONE THE NEXT SESSION FLIES: the right hand's beam on its row and the trigger, with the
## desk's own handler left on, because what the desk does with the press is what is under test. `Net.level` is what
## `Net.play_solo` and `Net.host` build the world from, and tests/levels.gd flies a level chosen on this screen and lands
## on its spawn. The row is marked chosen, and a pull on the first level puts it back.
func _a_pull_on_a_level_makes_it_the_level_the_next_session_flies() -> void:
	var shelf := _charts.shown() as ChartMenu
	var was: String = Net.level
	var other: String = ""
	for id in shelf.level_buttons.keys():
		if id != was:
			other = id
	_check("there_is_a_level_besides_the_chosen_one", other != "", "chosen %s, rows %s" % [was, shelf.level_buttons.keys()])
	if other == "":
		_sections += 1
		return
	_aim_at(_charts, _centre_of(shelf.level_buttons[other] as Button))
	await _frames(2)
	await _pull()
	var marked := shelf.level_buttons.get(other) as Button
	_check("a_pull_on_a_level_makes_it_the_level_the_next_session_flies_and_marks_it",
		Net.level == other and marked != null and marked.text.ends_with("chosen")
			and marked.get_theme_color("font_hover_color") == ChartMenu.AMBER,
		"Net.level %s (was %s), row reads '%s'" % [Net.level, was, marked.text if marked != null else "-"])
	_aim_at(_charts, _centre_of(shelf.level_buttons[was] as Button))
	await _frames(2)
	await _pull()
	_let_go()
	_check("and_a_pull_on_the_first_level_puts_it_back", Net.level == was, "Net.level %s" % Net.level)
	_sections += 1


## ---- 9: the way out of the program ------------------------------------------------------------------------------

## QUIT, AND ONLY WHEN IT IS MEANT. Asked for on 2026-09-13: "make sure that we have a quit button on the main menu to
## actually quit out of the game." A beam waved across a menu is easy to press by accident, so the first pull only arms
## it (`GuardedButton`, the clipboard's MAIN MENU guard), leaving it alone disarms it, and a second pull inside the time
## quits -- ending a hosted session on the way, through `Net.leave`, the path every leave takes.
##
## The quit itself goes through `DeskRoom.quit_the_game`, swapped here for a counter: a suite that really quit would
## report nothing. The desk's own `_on_chose` is put BACK on the menu for this section, because what the desk decides a
## "quit" means is half of what is under test -- which is also why this section is LAST: the second pull leaves the desk
## `_going`.
##
## WRITTEN TO PARSE BEFORE THE BUTTON EXISTED, so its first run failed checks rather than failing to compile: the button
## is found as a plain `Button` and asked `is_armed` by name, and the seam is written with `set`.
func _quit_takes_two_pulls_and_ends_the_session() -> void:
	var menu := _sessions.shown() as SessionMenu
	if not menu.chose.is_connected(Callable(_desk, "_on_chose")):
		menu.chose.connect(Callable(_desk, "_on_chose"))
	var quits: Array = [0]
	_desk.set("quit_the_game", func() -> void: quits[0] += 1)
	var quit: Button = _button(_sessions, "Quit")
	var screen := _sessions.get("_screen") as SubViewport
	_check("the_session_screen_has_a_quit_button_and_all_of_it_is_on_the_glass",
		quit != null and quit.has_method("is_armed")
			and Rect2(Vector2.ZERO, Vector2(screen.size)).encloses(quit.get_global_rect()),
		"%s" % [quit.get_global_rect() if quit != null else "no button whose text begins Quit"])
	_check("and_the_desk_has_a_way_out_a_test_can_stand_in_for", _desk.get("quit_the_game") is Callable,
		"quit_the_game %s" % [_desk.get("quit_the_game")])
	if quit == null or not quit.has_method("is_armed"):
		_sections += 1
		return
	Sim.stop()
	Net.host(PORT)
	_check("a_session_is_hosted_to_quit_out_of", Net.is_in_session, "transport %s" % Net.transport)

	# ONE PULL ARMS IT, and says so. The game goes on.
	_aim_at(_sessions, _centre_of(quit))
	await _frames(2)
	await _pull()
	var armed: bool = bool(quit.call("is_armed"))
	_check("one_pull_on_quit_only_arms_it", quits[0] == 0 and armed and String(quit.text).contains("AGAIN")
		and Net.is_in_session, "quits %d, armed %s, reads '%s', in session %s" % [quits[0], armed, quit.text,
		Net.is_in_session])
	# AND IT SAYS SO IN THE ARMED COLOUR WHILE THE BEAM IS ON IT. A hovered Button draws its words in `font_hover_color`,
	# not `font_color`, and the beam always hovers what it points at -- so the first picture showed the armed words in
	# the theme's plain white under the beam.
	# The colour it would draw in hovered, asked whether or not Godot has marked it hovered on this frame: the first run
	# of this check caught it between a press and the next pointer move, reporting not hovered.
	var hovered_in: Color = quit.get_theme_color("font_hover_color")
	_check("and_under_the_beam_the_armed_words_are_in_the_armed_colour",
		hovered_in == quit.get("armed_colour"),
		"hovered %s, hover colour %s, armed colour %s" % [quit.is_hovered(), hovered_in, quit.get("armed_colour")])

	# LEFT ALONE, IT PUTS ITSELF BACK. On the frame clock, which a timer is on too.
	_let_go()
	await get_tree().create_timer(ClipboardPage.MEANT_IT + 0.3).timeout
	armed = bool(quit.call("is_armed"))
	_check("and_left_alone_past_the_guard_time_it_disarms", not armed and String(quit.text).begins_with("Quit")
		and quits[0] == 0, "armed %s, reads '%s' after %.1f s" % [armed, quit.text, ClipboardPage.MEANT_IT])

	# TWO PULLS INSIDE THE TIME QUIT, and the hosted session is over.
	_aim_at(_sessions, _centre_of(quit))
	await _frames(2)
	await _pull()
	_aim_at(_sessions, _centre_of(quit))
	await _frames(2)
	await _pull()
	_check("and_two_pulls_inside_the_time_quit_once_and_end_the_session",
		quits[0] == 1 and not Net.is_in_session and Net.transport == "none",
		"quits %d, in session %s, transport %s" % [quits[0], Net.is_in_session, Net.transport])
	_let_go()
	if Net.is_in_session:
		Net.leave("suite")
	_sections += 1


## ---- helpers ----------------------------------------------------------------------------------------------------

## PUT THE RIGHT HAND `HAND_OFF` out from `panel`'s glass and aim it at `pixel` on that page. Returns the hand's pose.
func _aim_at(panel: TouchPanel, pixel: Vector2) -> Transform3D:
	var screen := panel.get("_screen") as SubViewport
	var on_glass := Vector3((pixel.x / float(screen.size.x) - 0.5) * panel.size.x,
		(0.5 - pixel.y / float(screen.size.y)) * panel.size.y, 0.0)
	var aimed_at: Vector3 = panel.to_global(on_glass)
	var hand_at: Vector3 = aimed_at + panel.global_basis.z.normalized() * HAND_OFF
	var pose := Transform3D(Basis.looking_at(aimed_at - hand_at, panel.global_basis.y.normalized()), hand_at)
	_rig.force_hand(1, pose)
	return pose


## AIM THE HAND AWAY, from where it stands: `looking_at(+normal)`, straight back out of the glass. See agents.md on
## why it is +normal.
func _aim_away(panel: TouchPanel) -> void:
	var at: Vector3 = _rig.right_hand.global_position
	_rig.force_hand(1, Transform3D(Basis.looking_at(panel.global_basis.z.normalized(), panel.global_basis.y), at))


## THE LEFT HAND PUT WHERE THE BOARD'S GLASS LANDS ON `glass`: the board hangs off the hand, so the hand is placed from
## the glass by the glass's own offset from the hand, read off the live nodes rather than typed from Clipboard.AT.
func _hold_the_board_at(board: Clipboard, glass: Transform3D) -> void:
	var from_hand: Transform3D = _rig.left_hand.global_transform.affine_inverse() * board.panel().global_transform
	_rig.force_hand(0, glass * from_hand.affine_inverse())


## WHERE A BUTTON IS IN THE WINDOW: its centre on its glass, through the desk camera, through the viewport's final
## transform. A mouse event is in window coordinates, headless or not.
func _window_point(panel: TouchPanel, button: Button) -> Vector2:
	var screen := panel.get("_screen") as SubViewport
	var pixel: Vector2 = button.get_global_rect().get_center()
	var on_glass := Vector3((pixel.x / float(screen.size.x) - 0.5) * panel.size.x,
		(0.5 - pixel.y / float(screen.size.y)) * panel.size.y, 0.0)
	var camera: Camera3D = _rig.desktop_camera
	return camera.get_viewport().get_final_transform() * camera.unproject_position(panel.to_global(on_glass))


func _move_the_mouse(window_at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = window_at
	motion.global_position = window_at
	Input.parse_input_event(motion)


func _mouse_button(down: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	var at: Vector2 = get_viewport().get_final_transform() * get_viewport().get_mouse_position()
	click.position = at
	click.global_position = at
	Input.parse_input_event(click)


func _click_with_the_mouse(panel: TouchPanel, button: Button) -> void:
	if button == null:
		return
	_move_the_mouse(_window_point(panel, button))
	await _frames(2)
	_mouse_button(true)
	await _frames(2)
	_mouse_button(false)
	await _frames(2)


## One pull of the right trigger: down for two frames, up for two, then the seam let go of.
func _pull() -> void:
	_rig.force_input(1, Bind.TRIGGER, 1.0)
	await _frames(2)
	_rig.force_input(1, Bind.TRIGGER, 0.0)
	await _frames(2)
	_rig.force_input(1, Bind.TRIGGER, null)


func _let_go() -> void:
	_rig.force_input(1, Bind.TRIGGER, null)
	_rig.force_hand(1, null)


func _clear() -> void:
	_asked_session.clear()
	_asked_door.clear()


func _button(panel: TouchPanel, starting: String) -> Button:
	for node in panel.shown().find_children("*", "Button", true, false):
		if String((node as Button).text).begins_with(starting):
			return node as Button
	return null


func _centre_of(button: Button) -> Vector2:
	return button.get_global_rect().get_center()


## THE WORLD BOX ROUND EVERY VERTEX of every surface of these meshes, each carried by its own global transform.
func _box_of(meshes: Array) -> AABB:
	var box := AABB()
	var first: bool = true
	for each in meshes:
		var mesh_node := each as MeshInstance3D
		for surface in range(mesh_node.mesh.get_surface_count()):
			for vertex in mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				var at: Vector3 = mesh_node.global_transform * vertex
				if first:
					box = AABB(at, Vector3.ZERO)
					first = false
				else:
					box = box.expand(at)
	return box


func _length(beam: MeshInstance3D) -> float:
	return beam.scale.z if beam != null else -1.0


func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
