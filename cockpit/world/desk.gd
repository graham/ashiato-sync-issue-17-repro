extends Node3D
class_name DeskRoom
## THE MAIN MENU: you are sitting at a desk, and the menu is on the desk.
##
## A room rather than a screen, because this is a headset game and a flat menu pasted over
## both eyes is the one thing a headset does worse than a monitor. Sitting somewhere and
## reaching for something is what the rest of the game is; the menu may as well be too.
##
## THE SAME PANEL THE COCKPIT USES. `TouchPanel` renders an ordinary Control tree onto a
## quad and turns a fingertip into a click, so this menu is authored like any other Godot UI
## and works with a controller for nothing. There is no second menu system.
##
## It knows nothing about what the buttons MEAN beyond starting a session and loading a
## world. `SessionMenu` announces what was pressed and this decides; the menu is reusable
## anywhere and this is the part that is about being the front door.

const MENU_PAGE := preload("res://ui/menus/session_menu.tscn")
const DOOR_PAGE := preload("res://ui/menus/level_menu.tscn")
const CHART_PAGE := preload("res://ui/menus/chart_menu.tscn")
const RIG := preload("res://player/pilot_rig.tscn")

## THE DESK TOP: how big the slab is and how high its middle stands. `_build_the_room` builds it from these and the
## screens are laid out on it from these, so a wider desk spreads and enlarges its screens with nothing else changed.
const DESK := Vector3(1.60, 0.06, 0.80)
const DESK_MIDDLE: float = 0.74
const DESK_TOP: float = DESK_MIDDLE + DESK.y * 0.5
## Where the chair stands. Every screen is turned to face the seated eye above it.
const CHAIR := Vector3(0.0, 0.0, 0.62)

## THREE SCREENS IN A SHALLOW ARC: which level (left), which session (middle), where to (right).
##
## Asked for on 2026-09-15: "add a third monitor and reposition the other two so that they all fit on the desk". Two
## screens were 62 x 46 cm, and three of that width turned toward a chair need 1.9 m of a 1.6 m desk. So the width is
## WORKED OUT from the desk: the middle screen's frame across, plus each turned screen's footprint across seen from
## above -- its frame turned by SCREEN_TURN and laid back by SCREEN_LEAN, which is where most of a turned screen's width
## goes -- plus two gaps and two edges, is the desk's width. Every term is linear in the width, so it solves in one line
## (SCREEN_WIDTH), and came to 48.5 cm. The page keeps its old shape, so every page lays out on the same 1024 x 760 px.
##
## THE TURN IS THE ONE CHOICE, and the desk's front edge is what limits it: the turned screens stand where they face
## the chair square on, and the more they turn the nearer the chair they stand. Measured with the layout's own sums:
## at 0.8 rad a turned screen's front corner is 1.5 cm inside the desk's front edge and all three are 0.73 m from the
## eye across the floor; at 0.9 it hangs 7.7 cm over; at 0.35 they stand 1.5 m off, half beyond the back of the desk.
const SCREEN_LEAN: float = 0.62
const SCREEN_TURN: float = 0.8
const SCREEN_ASPECT: float = 0.46 / 0.62
## The gap between two screens' frames, and between an end screen's frame and the desk's end, in metres.
const SCREEN_GAP: float = 0.015
const DESK_EDGE: float = 0.015
const SCREEN_WIDTH: float = (DESK.x - 2.0 * DESK_EDGE - 2.0 * SCREEN_GAP - 2.0 * TouchPanel.BEZEL
	- 4.0 * TouchPanel.BEZEL * (cos(SCREEN_TURN) + sin(SCREEN_LEAN) * sin(SCREEN_TURN))
	- 2.0 * TouchPanel.BEZEL_DEPTH * cos(SCREEN_LEAN) * sin(SCREEN_TURN)) \
	/ (1.0 + 2.0 * cos(SCREEN_TURN) + 2.0 * SCREEN_ASPECT * sin(SCREEN_LEAN) * sin(SCREEN_TURN))
const SCREEN := Vector2(SCREEN_WIDTH, SCREEN_WIDTH * SCREEN_ASPECT)
## How much of the desk's width one screen's frame covers, seen from above: the middle one square on, an end one turned.
const ACROSS_SQUARE: float = SCREEN_WIDTH + 2.0 * TouchPanel.BEZEL
const ACROSS_TURNED: float = (SCREEN_WIDTH + 2.0 * TouchPanel.BEZEL) * cos(SCREEN_TURN) \
	+ ((SCREEN_WIDTH * SCREEN_ASPECT + 2.0 * TouchPanel.BEZEL) * sin(SCREEN_LEAN)
		+ TouchPanel.BEZEL_DEPTH * cos(SCREEN_LEAN)) * sin(SCREEN_TURN)
## How high a screen's middle stands for the bottom of its FRAME to rest on the desk: half the frame laid back, and half
## its thickness, plus a couple of millimetres. Worked out rather than typed, so changing the size or the lean of a
## screen cannot quietly sink it again. At 0.86 the old screens' lower edges were at 0.67, 10 cm into the woodwork; and
## until the frame was counted (2026-09-15) every frame's lower edge was 1 cm in.
const SCREEN_AT: float = DESK_TOP + 0.002 + (SCREEN_WIDTH * SCREEN_ASPECT * 0.5 + TouchPanel.BEZEL) * cos(SCREEN_LEAN) \
	+ TouchPanel.BEZEL_DEPTH * 0.5 * sin(SCREEN_LEAN)
const BENCH := preload("res://tests/bench.tscn")

var _rig: PilotRig = null
var _panel: TouchPanel = null
var _menu: SessionMenu = null
var _doors: TouchPanel = null
var _charts: TouchPanel = null
var _going: bool = false
## Every screen on the desk. Both hands are offered to all of them each frame; a panel that
## the finger is nowhere near says so and costs nothing.
var _screens: Array[TouchPanel] = []
## THE WAY OUT OF THE PROGRAM, and the one thing a test stands in for: a suite that really quit would report nothing.
## Set in `_ready`, where there is a tree to quit. See `_quit`.
var quit_the_game: Callable = Callable()


## WHETHER THIS DESK IS SOMEWHERE A STEAM INVITE COULD ARRIVE: anywhere but headless. The one thing a test stands in for,
## so a headless suite can ask what a desk in a window would do.
var starts_steam: Callable = func() -> bool: return DisplayServer.get_name() != "headless"


func _ready() -> void:
	quit_the_game = func() -> void: get_tree().quit(0)
	# AT THE DESK THERE IS NO SESSION, whatever the last world left behind. The clipboard's MAIN MENU only changes scene
	# (`Doors.to_the_desk`), so until 2026-09-15 a player back at the desk was still in the solo or hosted session: `Sim`
	# ticked the old world's collision and every pilot under the menu, a host's socket stayed open with nobody flying,
	# and the level row refused a new level because a session was up. Ended here, the way every leave ends one.
	#
	# ONLY FOR A DESK THAT IS THE SCENE, a child of the tree's root, which is where a scene change and the boot router put
	# it. A desk built inside something else is furniture: tests/smoke.gd stands one beside its running world to measure
	# its screens, and the first version of this line ended that world's session under it (2026-09-15, smoke 3 of 9
	# sections, every later call on a null `Sim.server`).
	if get_parent() == get_tree().root and (Net.is_in_session or Net.transport != "none"):
		Net.leave("Back at the desk.")
	# STEAM UP WHILE SOMEBODY IS AT THE DESK. An invite accepted from the overlay, or Join Game on a friend's profile,
	# arrives as GodotSteam's `join_requested`, which reaches only a process that has started Steam and pumps its
	# callbacks -- and `SteamLobbyDirectory` starts Steam the first time it is asked, which was the first Steam button, so a
	# player who accepted an invite while sitting here heard nothing. Asking now starts it; `Net` pumps it every frame and
	# hands the invite to `Net.join_lobby`. Never headless: a suite, a harness and a second instance on one machine must
	# not touch the Steam client. The answer is not shown -- nothing was pressed -- and a Steam button says it when pressed.
	if starts_steam.call() and Net.lobbies != null:
		Net.lobbies.unavailable()
	_build_the_room()
	_rig = RIG.instantiate() as PilotRig
	add_child(_rig)
	# A seat at the desk. The rig is built to sit in things, so it sits in this one and
	# every bit of the head and hand handling is the same code it uses in an aeroplane.
	var chair := Node3D.new()
	chair.position = CHAIR
	add_child(chair)
	_rig.sit_in(chair)

	# THREE QUESTIONS, THREE SCREENS, left to right in the order they are asked: which level, who with, and -- for
	# everything that is not a session in the world -- where to. Separate because they are separate questions: a solo
	# session in the hall of cockpits is a perfectly ordinary thing to want, and the level is chosen before either.
	_charts = _stand_a_screen(CHART_PAGE, -1)
	_panel = _stand_a_screen(MENU_PAGE, 0)
	_doors = _stand_a_screen(DOOR_PAGE, 1)
	# AND THE RIGHT HAND'S BEAM POINTS AT ALL THREE, and the trigger presses what it is on -- the board's pointer, handed the
	# desk's screens (asked for on 2026-09-13), and with the clipboard up too: the beam aims whichever glass its ray
	# crosses first (`HandBeam`, 2026-09-14). The fingertip below still presses them.
	_rig.pointer_panels.assign(_screens)

	await get_tree().process_frame
	var doors := _doors.shown() as LevelMenu
	if doors != null:
		doors.chose.connect(_on_door)
		_doors.redraw()
	var charts := _charts.shown() as ChartMenu
	if charts != null:
		charts.chose.connect(_choose_level)
		_show_the_levels()
	_menu = _panel.shown() as SessionMenu
	if _menu != null:
		_menu.chose.connect(_on_chose)
		_menu.say("Not in a session.")
		# AND WHY THE LAST SESSION ENDED, if it ended against the player's will: once, then forgotten. See
		# `Net.parting_words`.
		if Net.parting_words != "":
			_menu.say(Net.parting_words)
			Net.parting_words = ""
	Net.session_message.connect(_on_said)
	# AND WHO ELSE IS PLAYING, whenever the answer comes: the screen draws what `Net` read off Steam and decides none
	# of it. See `Net.look_for_games`.
	Net.games_listed.connect(_on_games)


## ONE SCREEN STOOD ON THE DESK: -1 the left end, 0 the middle, 1 the right end. See `screen_place`.
func _stand_a_screen(page: PackedScene, which: int) -> TouchPanel:
	var glass := TouchPanel.new()
	glass.page = page
	glass.size = SCREEN
	glass.pixels = 1024
	glass.transform = screen_place(which)
	add_child(glass)
	_screens.append(glass)
	return glass


## WHERE A SCREEN STANDS, in the desk's own space: -1 the left end, 0 the middle, 1 the right end.
##
## STANDING ON THE DESK, laid back by SCREEN_LEAN: a panel flat on a table is read at a glancing angle, and one
## standing straight up is a monitor. An end screen stands a gap clear of the middle one's frame, TURNED to face the
## chair square on: two flat panels side by side are two panels read at a glancing angle, and angling each at the
## person in the chair is what a row of monitors is for. The middle one stands as far from the chair as the ends do,
## so all three are read at one distance.
static func screen_place(which: int) -> Transform3D:
	var across: float = ACROSS_SQUARE * 0.5 + SCREEN_GAP + ACROSS_TURNED * 0.5
	var ahead: float = across / tan(SCREEN_TURN)
	var at := Vector3(CHAIR.x, SCREEN_AT, CHAIR.z - Vector2(across, ahead).length())
	if which != 0:
		at = Vector3(CHAIR.x + signf(which) * across, SCREEN_AT, CHAIR.z - ahead)
	return Transform3D(Basis.from_euler(Vector3(-SCREEN_LEAN, -signf(which) * SCREEN_TURN, 0.0)), at)


## THE LEVELS ON THEIR SCREEN, with the one `Net` will fly marked. The screen draws what it is handed.
func _show_the_levels() -> void:
	var charts := _charts.shown() as ChartMenu if _charts != null else null
	if charts == null:
		return
	# AND WHETHER ANYBODY HAS CHOSEN, with the two defaults: since 2026-09-15 the level a session starts on depends on
	# which button is pressed, so a screen that marked `Net.level` as "chosen" before anybody had chosen would be telling
	# a player they had picked one. See `ChartMenu.show_levels` and `Net.suit_the_session`.
	charts.show_levels(ChartDrawer.charts(), Net.level, Net.level_chosen,
		{"host": ChartDrawer.HOSTING, "solo": ChartDrawer.DEFAULT})
	_charts.redraw()


## WHICH LEVEL THE NEXT SESSION FLIES. The levels screen says which was pressed; `Net` takes it or says why (a session
## already up), and the screen is shown what is chosen now, with the why under it. `Net.play_solo` and `Net.host` build
## the world from `Net.level`, and a Steam lobby says it to a joiner.
func _choose_level(id: String) -> void:
	if _going:
		return
	var why: String = Net.choose_level(id)
	_show_the_levels()
	var charts := _charts.shown() as ChartMenu
	if why != "" and charts != null:
		charts.say(why)
		_charts.redraw()


func _physics_process(_delta: float) -> void:
	if _rig == null:
		return
	# BOTH HANDS AGAINST EVERY SCREEN, every frame, and each panel decides whether either is
	# on it. `press` returns false for a point off the glass, which is what lets a hand be
	# offered to all of them without anybody keeping track of which is nearest.
	for hand in range(2):
		var finger: Node3D = _rig.left_hand if hand == 0 else _rig.right_hand
		var touching: bool = false
		for panel in _screens:
			var local: Vector3 = panel.to_local(finger.global_position)
			if absf(local.z) < TouchPanel.FINGER:
				touching = true
				if not _pressing[hand]:
					panel.press(local, true)
					panel.press(local, false)
			elif absf(local.z) < TouchPanel.FINGER * 6.0:
				panel.hover(local)
		_pressing[hand] = touching


var _pressing: Array[bool] = [false, false]


## WHERE TO. The level screen names a door and a craft; this opens it.
##
## The world goes through `change_scene_to_file` like the session buttons do. The bench does
## not: it needs to be told WHICH craft and which mode, and those are exports rather than
## anything a scene path can carry -- so it is built here, told, and swapped in. Its own
## command-line reading leaves them alone when there are no arguments, which there are not
## when it is opened from a desk.
func _on_door(level: String, kind: int) -> void:
	if _going:
		return
	# THE MARSHALLING LEVELS ANSWER FOR THEMSELVES, the same way the router lets them: a
	# door into that directory is that directory's business and not this room's.
	var on_foot: String = MarshallingLevel.scene_for(level)
	if on_foot != "":
		_going = true
		get_tree().change_scene_to_file.call_deferred(on_foot)
		return
	match level:
		"world":
			if not Net.is_in_session:
				Net.play_solo()
			_fly()
		"hall":
			_going = true
			get_tree().change_scene_to_file.call_deferred("res://world/hall.tscn")
		"seat", "crew", "fly", "build":
			_going = true
			_open_the_bench(level, kind)


func _open_the_bench(mode: String, kind: int) -> void:
	if not Net.is_in_session:
		Net.play_solo()
	var bench := bench_for(mode, kind)
	# DEFERRED, and the old scene goes only once the new one is in: swapping inside a signal
	# is the same "busy adding/removing children" the boot router was caught by.
	_swap.call_deferred(bench)


## THE BENCH A DOOR ASKS FOR, told its craft and its mode and nothing else done to it -- apart from the swap,
## so a test can open the same door the menu's button opens without the test itself being swapped away.
## "build" is one cockpit with the builder switched on: see `CockpitBench.build`.
static func bench_for(mode: String, kind: int) -> CockpitBench:
	var bench := BENCH.instantiate() as CockpitBench
	bench.kind = kind as Sim.Kind
	match mode:
		"crew": bench.mode = CockpitBench.Mode.CREW
		"fly": bench.mode = CockpitBench.Mode.FLY
		_: bench.mode = CockpitBench.Mode.SEAT
	bench.build = mode == "build"
	return bench


func _swap(scene: Node) -> void:
	var tree := get_tree()
	var going: Node = tree.current_scene
	tree.root.add_child(scene)
	tree.current_scene = scene
	if going != null:
		going.queue_free()


func _on_said(text: String) -> void:
	_say(text)


## THE GAMES STEAM ANSWERED WITH, onto the session screen. Only while the list is the view that is up: an answer that
## arrived after the player pressed BACK is an answer to a question nobody is asking any more.
func _on_games(games: Array) -> void:
	if _menu == null or not _menu.showing_games():
		return
	_menu.list_games(games)
	if _panel != null:
		_panel.redraw()


## HOW LONG A HOST HAS TO ANSWER is `Net.PATIENCE["connect"]` and then `["hello"]`, and not a number here.
##
## A join needs a deadline and nothing else will end the wait. Measured on 4.7.2 and
## written down in `working_with_godot.md`: `ENetMultiplayerPeer.create_client()` against a
## port nothing is listening on returns OK, `get_connection_status()` goes to
## CONNECTION_CONNECTING and STAYS there, and `connection_failed` never fires. A probe sat
## on one for the full thirty seconds it was given. So the timeout is the only thing that
## ever says no -- and since 2026-09-18 it is `Net`'s, so a join from the command line, the desk or a test ends in the
## same words ("No answer from 127.0.0.1:7788 after 10 s: the host may be down, ...").


## WHAT A BUTTON MEANT. The menu says what was pressed; this decides what happens, which is
## why the same menu can be pulled up in an aeroplane and mean something else.
##
## THREE OF THESE FOUR ARE IMMEDIATE AND ONE IS NOT, and that split is `Net`'s contract
## rather than a preference. `play_solo` and `host` are both in a session by the time they
## return -- they set `is_in_session` and emit `session_ready` on the spot -- so there is
## nothing to wait for. `join` only opens a socket: `is_in_session` stays false until
## `connected_to_server` arrives, which is the one thing `session_ready` is for. Flying
## immediately on a `join` tore the handshake down mid-flight.
##
## And `host` is no longer unconditional either. A port already in use makes `host` say so
## and leave `is_in_session` false -- and flying anyway put the player in a world they
## believed was public and nobody could reach.
func _on_chose(what: String, detail: String) -> void:
	if _going:
		return
	match what:
		"solo":
			Net.play_solo()
			_fly()
		"host":
			Net.host()
			if Net.is_in_session:
				_fly()
		"steam":
			# A STEAM HOST IS NOT IMMEDIATE: a code is checked and a lobby made, each a Steam round trip. So it waits,
			# and on `Net` rather than on this room's clock -- see `_fly_once_steam_answers`.
			Net.host_steam()
			await _fly_once_steam_answers()
		# AN ADDRESS, OR AN ADDRESS AND A PORT, read by the same parser the `--join=` flag uses (`LaunchOrder.read_address`).
		# Until 2026-09-15 this handed the field straight to `Net.join`, whose port argument defaults, so a host on any
		# other port was unreachable from the main menu and a player who typed one got "Nothing is listening there" ten
		# seconds later. A port that is not a port is said at once, here, rather than waited out.
		"join":
			var where: Dictionary = LaunchOrder.read_address(detail, Net.usual_port)
			if String(where["error"]) != "":
				_say("That address %s." % where["error"])
				return
			Net.join(String(where["address"]), int(where["port"]))
			await _fly_once_the_session_is_up("%s:%d" % [where["address"], int(where["port"])])
		# A CODE TYPED ON THE KEYPAD, as it was typed: `Net.join_code` reads it through `JoinCode` and says why, if it is not
		# one. It waits the way hosting over Steam waits, on `Net`'s own deadlines.
		"code":
			Net.join_code(detail)
			await _fly_once_steam_answers()
		# LOOK FOR OTHER PLAYERS, asked for on 2026-09-15. Nothing is joined and nothing waits: the search has its own
		# deadline in `Net` and answers through `games_listed`, which `_on_games` puts on the screen. So the player can
		# press BACK, type a code or fly solo while Steam is still thinking, which a room that awaited it could not.
		"browse":
			_menu.show_games(true)
			_panel.redraw()
			Net.look_for_games()
		# JOIN ONE OFF THAT LIST, by the lobby the row named. It waits as a typed code waits.
		"game":
			Net.join_game(int(detail))
			await _fly_once_steam_answers()
		"quit":
			_quit()


## OUT OF THE PROGRAM, meant twice on the session screen (`GuardedButton`).
##
## A SESSION ENDS THE WAY EVERY LEAVE ENDS ONE: `Net.leave`, which closes the peer and says `session_ended`, and `Sim`
## stops on that. A join still knocking counts too -- `transport` is set the moment the socket opens, before
## `is_in_session` is.
##
## NO XR TEARDOWN FIRST, on purpose. Read in Godot 4.7's modules/openxr: `OpenXRInterface.uninitialize` does not end the
## session -- its own comment says the driver cleans up when Godot exits -- and engine exit runs
## `uninitialize_openxr_module`, then `OpenXRAPI::finish`, `destroy_session` and `xrEndSession`. So `quit(0)` is the
## clean exit, and an `uninitialize()` before it would only add frames with no trackers. Not measured in a headset: there
## is none on this machine.
func _quit() -> void:
	_going = true
	if Net.is_in_session or Net.transport != "none":
		Net.leave("quit")
	quit_the_game.call()


## Wait for the session to announce itself, then go; give up out loud if it never does.
##
## The flag is a MEMBER and the wait is a loop rather than a lambda on a timer, because a
## GDScript lambda captures by VALUE -- a flag cleared inside a signal callback is cleared
## on a copy and the loop outside it waits for ever. That is written down in agents.md and
## the bench walked into it once already.
func _fly_once_the_session_is_up(who: String) -> void:
	if Net.is_in_session:
		_fly()
		return
	_going = true
	while not Net.is_in_session:
		# REFUSED OR GIVEN UP ON, with the reason already on this screen: `Net` says every ending of a join in words --
		# the host's refusal naming both builds, or its own deadline saying where and how long -- and puts `transport`
		# back to "none". Until 2026-09-18 this room kept a deadline of its own, the same ten seconds as Net's, and the two
		# raced: whichever came first said its own sentence, "Nothing is listening there" or the reason.
		if Net.transport == "none":
			_going = false
			# SAID ALREADY, through `session_message`, so forgotten here as the desk forgets it at `_ready`: a reason
			# left standing would be said again by the next room this player walks into.
			if Net.parting_words == "":
				_say("No answer from %s." % who)
			Net.parting_words = ""
			return
		await get_tree().process_frame
		# The desk can be gone by now -- another button, or the tree shutting down.
		if not is_inside_tree():
			return
	_fly()


## WAIT FOR A STEAM SESSION TO COME UP OR BE REFUSED, and fly only if it came up.
##
## NO DEADLINE HERE, and that is not the mistake `JOIN_TIMEOUT` was written against: every stage of a Steam session has
## its own in `Net` (`Net.PATIENCE`), because each is a different request with a different answer to wait for, and each
## says its own sentence when it runs out. A refusal puts `transport` back to "none" and says why through
## `session_message`, which is already on this screen -- so all this has to do is stop waiting and stay at the desk.
## JOIN_TIMEOUT's "Nothing is listening there" is an ENet sentence and would be the wrong one.
func _fly_once_steam_answers() -> void:
	_going = true
	while not Net.is_in_session:
		if Net.transport != "steam":
			_going = false
			return
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_fly()


## Put a line on the session screen, the way `Net` does through `session_message`.
func _say(text: String) -> void:
	if _menu != null:
		_menu.say(text)
		if _panel != null:
			_panel.redraw()


## Into the world. One frame later, so whatever the session had to say is on the panel
## before the panel goes away with it, and deferred for the same reason the router defers:
## a scene change asked for from inside a signal can land while the tree is mid-edit.
func _fly() -> void:
	_going = true
	await get_tree().process_frame
	get_tree().change_scene_to_file.call_deferred("res://world/sky.tscn")


func _build_the_room() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.24, 0.17, 0.12)
	wood.roughness = 0.8
	var floor_paint := StandardMaterial3D.new()
	floor_paint.albedo_color = Color(0.14, 0.14, 0.16)
	floor_paint.roughness = 0.95

	_slab(floor_paint, Vector3(9.0, 0.2, 9.0), Vector3(0.0, -0.1, 0.0))
	# The desk: a top and two ends, at the height a desk is.
	_slab(wood, DESK, Vector3(0.0, DESK_MIDDLE, 0.0))
	for side in [-1.0, 1.0]:
		_slab(wood, Vector3(0.06, DESK_MIDDLE, DESK.z - 0.10), Vector3(side * (DESK.x * 0.5 - 0.06), DESK_MIDDLE * 0.5, 0.0))
	# A chair back behind the seat, so it reads as somewhere to sit rather than a mark on
	# the floor.
	_slab(wood, Vector3(0.50, 0.06, 0.46), CHAIR + Vector3(0.0, 0.45, 0.0))
	_slab(wood, Vector3(0.50, 0.50, 0.06), CHAIR + Vector3(0.0, 0.70, 0.24))

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.7, 0.0)
	sun.light_energy = 0.9
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 2.2, -0.4)
	lamp.omni_range = 7.0
	lamp.light_energy = 2.2
	add_child(lamp)
	var air := WorldEnvironment.new()
	var room := Environment.new()
	room.background_mode = Environment.BG_COLOR
	room.background_color = Color(0.05, 0.06, 0.08)
	room.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room.ambient_light_color = Color(0.35, 0.38, 0.44)
	room.ambient_light_energy = 1.0
	air.environment = room
	add_child(air)


func _slab(material: StandardMaterial3D, size: Vector3, at: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var node := MeshInstance3D.new()
	node.mesh = box
	node.material_override = material
	node.position = at
	add_child(node)
