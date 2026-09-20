extends Node
## Headless: can a second person actually get into this game?
##
##   Godot --headless --path cockpit res://tests/session.tscn
##
## THE BUG THIS EXISTS FOR. `world/sky.gd` called `Net.play_solo()` unconditionally in
## `_ready`, and `play_solo` begins by CLOSING whatever peer is installed. So pressing
## "Host a game" on the desk created an ENet server on port 7788, loaded the world, and
## destroyed the listening socket one frame later with `transport` back to "solo". Both
## networked paths out of the only menu in the game were dead, and nothing anywhere said
## so: `Sim.start()` saw an un-networked peer, stood up a local server, and the game played
## on quite happily in a session nobody could reach.
##
## Nothing caught it because no cockpit suite had ever called `Net.host()` or `Net.join()`.
## `trim`, `clipboard` and `bench` all call `Net.play_solo()` -- which is the function the
## bug was IN -- and the real two-peer coverage lives in `ashiato-gd` and exercises the C++
## replication layer directly, far below the desk-to-sky scene transition. That is the
## tautology this project already has a name for, at a layer boundary.
##
## SO THIS ONE STARTS AT A BUTTON. It loads the real desk, finds the real `Button` inside
## the real `SessionMenu`, emits its `pressed`, and then looks at what the world it lands in
## believes about the session. Everything between -- `SessionMenu.chose`, `DeskRoom`,
## `Net.host`, `change_scene_to_file`, `FlightLevel._ready`, `Sim.start` -- is the game's
## own code and none of it is reached any other way.
##
## AND IT SURVIVES ITS OWN SCENE CHANGE. `change_scene_to_file` frees `current_scene`, so a
## suite that is the current scene is deleted by the first thing it asks the game to do.
## The scene's root therefore does nothing but hang a second copy of this script on
## `/root`, which is a SIBLING of the current scene and outlives every swap. That is the
## whole of the `self != current_scene` branch in `_ready`.
##
## Read RESULT=, not the exit code.

var _failures: PackedStringArray = []
## How many of the four sections got to their own end. A GDScript error aborts the function
## it is in and carries on with the next, so a suite that counts only failures reports a
## cheerful pass over a section that fell over.
var _sections: int = 0

## How long to wait for a scene change plus a session handshake, in physics frames. At the
## project's 120 Hz that is five seconds, which is an order more than the world takes to
## build headless.
const PATIENCE: int = 600
## Where the desk's own "Host a game" listens and the loopback client knocks: `Net.usual_port`, which a player's game
## leaves at `Net.DEFAULT_PORT` and this suite sets to one of THIS CHECKOUT's ports (`TestPorts`) before pressing, so
## the button under test is the button a player presses and still does not take 7788 from every other lane's `session`
## and from a developer's own game. Asked silently first whether anything holds it; held, and the suite says PORT BUSY.
static var PORT: int = TestPorts.first_free(47912)
## A port nothing listens on, for the join that must give up. Asked the same way: another lane's host there would answer.
static var NOBODY_PORT: int = TestPorts.first_free(47913)


func _check(label: String, ok: bool, detail: String) -> void:
	print("[session] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if PORT == 0 or NOBODY_PORT == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(47912, 2))
		get_tree().quit(1)
		return
	Net.usual_port = PORT
	# The copy hung on /root is the one that runs. See the header.
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "SessionWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	await _solo_when_nobody_asked_for_a_session()
	# The right hand's beam on the desk's menu was section 2 here until 2026-09-14; it is tests/desk_screens.gd now,
	# with both screens and the clipboard in front of them.
	await _hosting_from_the_desk_reaches_the_world()
	await _and_a_second_peer_can_join_it()
	await _a_join_with_nobody_listening_gives_up()
	_check("every_section_of_the_suite_ran", _sections == 4, "%d of 4" % _sections)
	_finish()


## ---- 1: the world on its own ----------------------------------------------------------

## NOTHING ASKED, SO IT PLAYS SOLO -- which is the half that must not regress.
##
## `--level=world`, the editor, and every bench in the project arrive here with no session
## at all, and the level has to start one for itself. The fix for the bug above is one
## `if`, and the way to get that `if` wrong is to make the level wait for a session that
## nobody is ever going to announce.
func _solo_when_nobody_asked_for_a_session() -> void:
	await _open("res://world/sky.tscn")
	var level := get_tree().current_scene as FlightLevel
	_check("a_world_nobody_asked_about_plays_solo", level != null and Net.transport == "solo",
		"transport=%s in_session=%s" % [Net.transport, Net.is_in_session])
	_check("and_it_stood_up_its_own_server", Sim.client != null and Sim.server != null,
		"client=%s server=%s" % [Sim.client != null, Sim.server != null])
	# THE HANDSHAKE HAPPENS EVEN SOLO. `server.take_outbound()` is wired straight into
	# `client.deliver()`, so a solo session runs the whole replication pipeline over a
	# simulated link and `is_ready` is still something to wait for rather than assume.
	var built: bool = await _wait_for(func() -> bool: return Sim.is_ready)
	_check("and_the_world_got_built", built, "sim_ready=%s" % Sim.is_ready)
	_sections += 1


## ---- 2: the button a player presses ---------------------------------------------------

## HOST A GAME, from the desk, through the menu, into the world.
##
## The assertion that matters is `transport == "enet"` AFTER the world has loaded. Before
## the fix it read "solo" here, and everything else about the run looked perfect.
func _hosting_from_the_desk_reaches_the_world() -> void:
	Sim.stop()
	Net.leave("suite")
	await _open("res://world/desk.tscn")
	# The desk connects the menu one frame into its own `_ready`, after an await.
	for i in range(4):
		await get_tree().process_frame

	var desk := get_tree().current_scene
	var pressed: bool = _press(desk, "Host a game")
	_check("the_desk_has_a_host_button_to_press", pressed, "found and emitted")
	if not pressed:
		_sections += 1
		return

	var arrived: bool = await _wait_for_the_world()
	_check("and_pressing_it_lands_in_the_world", arrived,
		"current scene is %s" % _scene_name())
	_check("and_the_world_is_still_the_session_the_menu_started",
		Net.transport == "enet" and Net.is_host and Net.is_in_session,
		"transport=%s host=%s in_session=%s" % [Net.transport, Net.is_host, Net.is_in_session])
	# `is_networked()` is the real question and a null check is not: Godot installs an
	# OfflineMultiplayerPeer by default, so `multiplayer_peer != null` reports a live
	# session for a scene that never joined anything.
	_check("and_the_listening_socket_is_still_open", Net.is_networked(),
		"peer=%s" % _peer_name())
	_check("and_the_simulation_is_hosting_rather_than_predicting_alone",
		Sim.client != null and Sim.server != null,
		"client=%s server=%s" % [Sim.client != null, Sim.server != null])
	_sections += 1


## ---- 3: somebody else on the same machine ---------------------------------------------

## A SECOND PEER ON 127.0.0.1 GETS IN.
##
## A raw `ENetMultiplayerPeer` rather than a second `Net`, because one process has one
## `SceneTree.multiplayer` and therefore one `Net`. What is being proved here is the thing
## the bug destroyed -- that there is a socket listening on the port the menu opened and
## that it completes a handshake -- and an ENet client is exactly the right instrument for
## that question. What it deliberately does NOT prove is that a second PLAYER arrives --
## only two processes with two `Sim`s can say that, and there is no boot flag to start a
## host or a join from a command line yet, so that check cannot be written today. The gap
## is named here because it is exactly where the next bug will live.
func _and_a_second_peer_can_join_it() -> void:
	if not Net.is_networked():
		_check("a_second_peer_reaches_the_host", false, "there is no host to reach")
		_sections += 1
		return
	var guest := ENetMultiplayerPeer.new()
	var err: int = guest.create_client("127.0.0.1", PORT)
	_check("a_loopback_client_can_be_created", err == OK, "create_client=%s" % error_string(err))

	# WHO THE HOST SAW ARRIVE. An Array is a reference in GDScript, so a lambda that
	# appends to this one appends to THIS one -- unlike a captured bool, which is a copy.
	var saw: Array[int] = []
	Net.peer_joined.connect(func(id: int) -> void: saw.append(id))

	# KEEP POLLING THE GUEST AFTER IT SAYS IT IS CONNECTED, which is the whole of why the
	# first version of this check failed. ENet's handshake is three-way and the two ends
	# finish it at DIFFERENT times: the client dispatches its connect event when the
	# server's VERIFY_CONNECT arrives, and the server dispatches its own only when the
	# client's acknowledgement of that gets back. Stop polling the client the instant it
	# reports CONNECTED -- which is the obvious thing to write -- and that acknowledgement
	# is never sent, so the host never hears about a peer that believes it is in.
	# Measured: the guest read CONNECTED one frame after `create_client` and
	# `multiplayer.get_peers()` was still empty thirty frames later.
	var connected: bool = false
	var told: bool = false
	for i in range(PATIENCE):
		guest.poll()
		if guest.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			connected = true
		if connected and multiplayer.get_peers().size() == 1:
			told = true
			break
		await get_tree().physics_frame
	_check("a_second_peer_reaches_the_host", connected,
		"status=%d" % guest.get_connection_status())
	# The socket answering is one thing; the HOST hearing about it is the other, and it is
	# the half `Sim` needs -- `_on_peer_joined` is what gives the arrival a sync client id,
	# and it cannot fire for a peer nobody was told about.
	_check("and_the_host_is_told_who_arrived", told and saw.size() == 1,
		"peers=%s joined=%s" % [multiplayer.get_peers(), saw])
	# LET IT GO CLEANLY, then stop touching it. `poll()` on a closed peer is an engine
	# error every frame -- "The multiplayer instance isn't currently active" -- and the
	# runner fails a suite that prints one whatever its own checks said.
	for i in range(10):
		guest.poll()
		await get_tree().physics_frame
	guest.close()
	for i in range(10):
		await get_tree().physics_frame
	_sections += 1


## ---- 4: the refusal ---------------------------------------------------------------

## A JOIN THAT NOBODY ANSWERS GIVES UP, rather than flying into an empty world.
##
## This is the other half of the same bug and the reason the desk now waits. Measured on
## 4.7.2 and written down in `working_with_godot.md`: `create_client` against a dead port
## returns OK, `get_connection_status()` sits at CONNECTION_CONNECTING for ever and
## `connection_failed` never fires -- so there is no signal that could end the wait and
## `Net`'s connect deadline is the only thing that ever says no. What is checked here is the
## shape rather than the ten seconds: the peer exists, it is connecting, and it is NOT in a
## session -- which is precisely the state the old code called `_fly()` from.
func _a_join_with_nobody_listening_gives_up() -> void:
	Sim.stop()
	Net.leave("suite")
	# A port off the documented default, so a developer's own instance cannot fail this.
	Net.join("127.0.0.1", NOBODY_PORT)
	for i in range(60):
		await get_tree().physics_frame
	var status: int = multiplayer.multiplayer_peer.get_connection_status()
	_check("a_join_nobody_answers_never_reports_a_session", not Net.is_in_session,
		"in_session=%s status=%d" % [Net.is_in_session, status])
	_check("and_it_sits_in_CONNECTING_rather_than_failing",
		status == MultiplayerPeer.CONNECTION_CONNECTING,
		"status=%d (CONNECTING=%d)" % [status, MultiplayerPeer.CONNECTION_CONNECTING])
	# AND NET PUTS A DEADLINE ON IT, its own since 2026-09-18 rather than the desk's, so every door ends it the same way.
	_check("and_net_puts_a_deadline_on_it", String(Net.get("_stage")) == "connect"
		and float(Net.PATIENCE["connect"]) > 0.0, "stage '%s', %.1f s" % [Net.get("_stage"), Net.PATIENCE["connect"]])
	Net.leave("suite")
	_sections += 1


## ---- the machinery --------------------------------------------------------------------

## Spin frames until something is true, or give up. The condition is a Callable rather
## than a flag because a GDScript lambda captures by VALUE: a bool set inside a signal
## handler is set on a copy, and the loop outside it waits for ever.
func _wait_for(until: Callable) -> bool:
	for i in range(PATIENCE):
		if until.call():
			return true
		await get_tree().physics_frame
	return until.call()


## Open a scene the way the game does, and wait for it to be the current one.
func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)
	for i in range(PATIENCE):
		await get_tree().physics_frame
		var now: Node = get_tree().current_scene
		if now != null and now.scene_file_path == path:
			# One more frame so the arriving scene's own `_ready` has finished.
			await get_tree().physics_frame
			return


## Wait for the desk to have handed over to the world, and for the world to be running.
func _wait_for_the_world() -> bool:
	for i in range(PATIENCE):
		await get_tree().physics_frame
		if get_tree().current_scene is FlightLevel and Sim.is_ready:
			return true
	return false


## Find a `Button` by the words on it and emit what a press emits.
##
## `pressed.emit()` rather than a synthetic click, deliberately: the panel is a SubViewport
## on a quad in a room, and what is under test here is the SESSION and not the geometry of
## the desk -- `tests/clipboard.gd` and `fit` are what measure whether a finger reaches a
## button. What this does buy over calling `Net.host()` is everything above it: the button
## is the real one the menu built, its `pressed` is wired to the real `chose`, and
## `DeskRoom._on_chose` is what decides what "host" means.
func _press(within: Node, words: String) -> bool:
	if within == null:
		return false
	for node in within.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == words:
			button.pressed.emit()
			return true
	return false


func _scene_name() -> String:
	var now: Node = get_tree().current_scene
	return "null" if now == null else now.get_class() + "/" + now.name


func _peer_name() -> String:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	return "null" if peer == null else peer.get_class()


func _finish() -> void:
	# The port goes back, or a second run of this suite cannot listen on it.
	Sim.stop()
	Net.leave("suite over")
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
