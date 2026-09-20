extends Node
## Headless: can a game be hosted over Steam with a code, and joined by typing that code -- and when it cannot, does the
## player read why?
##
##   Godot --headless --path cockpit res://tests/steam_join.tscn
##
## Asked for on 2026-09-14: "a join code for steam players so they can join a game via a join code rather than having
## to be invited or searching for a game."
##
## ON PAPER, OVER A REAL SOCKET. One Steam account cannot be two peers on one machine, so `Net.lobbies` is a
## `PaperLobbyDirectory` here: the lobbies are Dictionaries and the answers come a frame late, and the peers it hands out
## are real ENet sockets on the loopback. Everything else is the game's own: the desk's "Host over Steam" button,
## `Net.host_steam` and `Net.join_code`, `JoinCode`, every stage and its deadline, and the words. What only Steam can
## prove -- that its search finds an invisible lobby by its code -- tests/steam_probe.gd proved against the real backend.
##
## THE HOST STARTS AT THE BUTTON and lands in the world. THE JOINER STARTS AT `Net.join_code` with what a person typed,
## until the keypad exists to start it from.
##
## AND IT SURVIVES ITS OWN SCENE CHANGE the way tests/session.gd does: the scene's root hangs a second copy of this script
## on /root, which outlives every swap.
##
## Read RESULT=, not the exit code.

## Ports off every default and off tests/session.gd's, so a developer's own game and another suite cannot collide.
## THIS CHECKOUT'S PORTS (`TestPorts`), each asked silently at load whether anything holds it: fixed numbers were the
## same sockets in every lane. One held, and the suite says PORT BUSY at once rather than timing out.
static var HOST_PORT: int = TestPorts.first_free(47961, 1)
static var JOIN_PORT: int = TestPorts.first_free(47962, 1)
static var DEAD_PORT: int = TestPorts.first_free(47963, 1)
## Physics frames to wait for a scene change and a world build. Five seconds at 120 Hz.
const PATIENCE: int = 600
## Seconds every Steam stage is given here, so a deadline is reached in a suite's time rather than a player's.
const SHORT: float = 0.4
const CODE: String = "K7MQ2X"
## Who the other machine's host is, as the paper directory knows them.
const THEIR_HOST: int = 76561190000000900

var _failures: PackedStringArray = []
var _sections: int = 0
## Everything Net said, in order. An Array, because a lambda that appends to a captured Array appends to this one.
var _heard: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[steam_join] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if HOST_PORT == 0 or JOIN_PORT == 0 or DEAD_PORT == 0:
		print("RESULT=FAIL port_busy %s" % (TestPorts.busy(47961, 1) + " / " + TestPorts.busy(47962, 1) + " / " + TestPorts.busy(47963, 1)))
		get_tree().quit(1)
		return
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "SteamJoinWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	# A SUITE NAMES THE LEVEL IT TESTS AGAINST. This one writes `Net.level` onto every paper lobby it makes
	# (`_their_lobby`) and then expects the island's name in a refusal -- so with the level inherited from whatever ran
	# last it read "The host's copy of The lobby is not the same as yours." the day hosting started defaulting to the
	# lobby (2026-09-15). Nothing here changed; it had simply never said what it was flying. See agents.md, "A SUITE
	# NAMES ITS LEVEL".
	Net.choose_level(ChartDrawer.DEFAULT)
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	Net.session_message.connect(func(text: String) -> void: _heard.append(text))
	await _hosting_over_steam_from_the_desk_reaches_the_world_with_a_code()
	await get_tree().process_frame
	get_tree().unload_current_scene()
	await _a_code_somebody_already_holds_is_drawn_again()
	await _a_typed_code_finds_the_game_that_holds_it_and_joins_it()
	await _every_way_a_join_is_refused_says_why()
	await _an_invite_lands_in_the_same_join_with_the_same_refusals()
	await _every_way_hosting_is_refused_says_why_and_the_desk_stays()
	await _the_desk_starts_steam_only_where_an_invite_could_arrive()
	await _browse_and_code_search_keep_their_own_answers_and_deadlines()
	_check("every_section_of_the_suite_ran", _sections == 8, "%d of 8" % _sections)
	_finish()


## ---- 1: the host ------------------------------------------------------------------------------------------------

func _hosting_over_steam_from_the_desk_reaches_the_world_with_a_code() -> void:
	var paper := _paper(HOST_PORT)
	await _open("res://world/desk.tscn")
	for i in range(4):
		await get_tree().process_frame
	var pressed: bool = _press(get_tree().current_scene, "Host over Steam")
	_check("the_desk_has_a_host_over_steam_button_to_press", pressed, "found and emitted")
	var arrived: bool = await _wait_for(func() -> bool: return get_tree().current_scene is FlightLevel and Sim.is_ready)
	_check("and_pressing_it_lands_in_the_world_hosting_over_steam",
		arrived and Net.transport == "steam" and Net.is_host and Net.is_in_session and Net.is_networked(),
		"arrived %s, transport %s, host %s, in session %s, peer %s" % [arrived, Net.transport, Net.is_host,
			Net.is_in_session, multiplayer.multiplayer_peer.get_class() if multiplayer.multiplayer_peer else "none"])
	_check("with_a_code_that_is_a_code", JoinCode.read(Net.session_code) == Net.session_code and Net.session_code != "",
		"'%s'" % Net.session_code)
	var written: Dictionary = paper.lobbies.get(Net.lobby, {}).get("data", {})
	_check("written_on_the_lobby_with_the_game_the_build_who_hosts_and_the_level",
		written.get("code") == Net.session_code and written.get("game") == Net.GAME_TAG
			and written.get("build") == "alpha" and written.get("compatibility") == Net.compatibility()
			and written.get("host") == str(paper.who_i_am)
			and written.get("level") == Net.level
			and written.get("level_hash") == ChartDrawer.chart(Net.level).content_hash,
		"%s" % [written])
	_check("which_holds_as_many_as_a_session_does", paper.limit(Net.lobby) == Net.MAX_PLAYERS,
		"limit %d" % paper.limit(Net.lobby))
	_check("and_the_code_was_looked_for_before_the_lobby_was_made",
		paper.searches.size() == 1 and paper.searches[0].get("code") == Net.session_code, "%s" % [paper.searches])
	_check("and_the_host_says_its_code", _heard.has("Hosting over Steam. Code %s." % JoinCode.spell(Net.session_code)),
		"heard %s" % [_heard])

	# AND GOES ON SAYING IT IN THE AIR. The desk says the code once and is gone the moment the world loads, so a host who
	# wants to read it out to a friend needs it where a flying player looks: the status line on a monitor, and the
	# board in the hand in a headset -- on whatever tab is up since 2026-09-15 ("make sure the multiplayer steam code is
	# shown somewhere on the ipad or on the hud"), where it used to be at the head of the CREW list alone.
	# WHICH TAB IS UP IS tests/clipboard.gd'S QUESTION; this one asks whether the board carries the code of the session
	# the desk actually started, which no measurement of the page on its own can.
	var spelled: String = JoinCode.spell(Net.session_code)
	var level := get_tree().current_scene as FlightLevel
	for i in range(40):
		await get_tree().physics_frame
	var status := level.get("_status") as Label if level != null else null
	_check("the_status_line_names_the_code_while_hosting", status != null and status.text.contains(spelled),
		"'%s'" % [status.text if status != null else "no status line"])
	_check("and_the_board_in_the_hand_says_it_too_with_who_is_aboard", _crew_line(level).contains(spelled)
		and _crew_line(level).contains("1 of %d players connected" % Net.MAX_PLAYERS), "'%s'" % _crew_line(level))

	# THE SOCKET THE LOBBY HANDED OUT IS THE ONE LISTENING. A raw ENet guest, polled after it says CONNECTED, because
	# the host hears of it only when the guest's acknowledgement arrives -- see tests/session.gd.
	# ONLY IF SOMETHING IS HOSTING: `multiplayer.get_peers()` with no peer is an engine error every frame, and the
	# runner fails a suite that prints one -- the red run against a stub printed six hundred of them.
	var told: bool = false
	if Net.is_networked():
		var guest := ENetMultiplayerPeer.new()
		guest.create_client("127.0.0.1", HOST_PORT)
		for i in range(PATIENCE):
			guest.poll()
			if multiplayer.get_peers().size() == 1:
				told = true
				break
			await get_tree().physics_frame
		for i in range(10):
			guest.poll()
			await get_tree().physics_frame
		# THE COUNT FOLLOWS WHO ARRIVES: somebody reaching the lobby is somebody aboard.
		_check("and_the_board_counts_the_arrival", _crew_line(get_tree().current_scene as FlightLevel).contains(
			"2 of %d players connected" % Net.MAX_PLAYERS), "'%s'" % _crew_line(get_tree().current_scene as FlightLevel))
		guest.close()
	_check("and_somebody_reaching_that_lobby_reaches_the_host", told,
		"peers %s" % [multiplayer.get_peers() if Net.is_networked() else "no peer"])

	var was: int = Net.lobby
	Sim.stop()
	Net.leave("suite")
	_check("and_leaving_leaves_the_lobby_which_nobody_is_left_in", not paper.lobbies.has(was) and Net.lobby == 0
		and Net.session_code == "", "lobbies %s, code '%s'" % [paper.lobbies.keys(), Net.session_code])
	_sections += 1


## ---- 2: a clash ------------------------------------------------------------------------------------------------------

func _a_code_somebody_already_holds_is_drawn_again() -> void:
	var paper := _paper(HOST_PORT)
	paper.put({"game": Net.GAME_TAG, "code": "AAAAAA"}, 1, 8, THEIR_HOST, 0)
	var draws: Array = ["AAAAAA", "BBBBBB"]
	Net.draw_code = func() -> String: return String(draws.pop_front())
	Net.host_steam()
	await _until(func() -> bool: return Net.is_in_session or Net.transport == "none")
	_check("a_code_another_lobby_holds_is_drawn_again", Net.is_in_session and Net.session_code == "BBBBBB",
		"code '%s', searched %s" % [Net.session_code, paper.searches])
	Net.leave("suite")

	paper = _paper(HOST_PORT)
	paper.put({"game": Net.GAME_TAG, "code": "AAAAAA"}, 1, 8, THEIR_HOST, 0)
	Net.draw_code = func() -> String: return "AAAAAA"
	_heard.clear()
	Net.host_steam()
	await _until(func() -> bool: return Net.transport == "none")
	_check("and_a_host_that_draws_nothing_but_clashes_gives_up_and_says_so",
		not Net.is_in_session and _last() == "Every code drawn was already in use. Try again."
			and paper.searches.size() == Net.CODE_DRAWS, "said '%s', %d searches" % [_last(), paper.searches.size()])
	Net.draw_code = func() -> String: return JoinCode.fresh()
	_sections += 1


## ---- 3: the joiner --------------------------------------------------------------------------------------------------

func _a_typed_code_finds_the_game_that_holds_it_and_joins_it() -> void:
	var paper := _paper(DEAD_PORT)
	var server := ENetMultiplayerPeer.new()
	server.create_server(JOIN_PORT, Net.MAX_PLAYERS)
	var theirs: int = paper.put(_their_lobby(), 1, Net.MAX_PLAYERS, THEIR_HOST, JOIN_PORT)
	_heard.clear()
	Net.join_code("k7m-q2x")
	var joined: bool = false
	for i in range(PATIENCE):
		server.poll()
		_answer_as_the_host()
		if Net.is_in_session:
			joined = true
			break
		await get_tree().physics_frame
	_check("a_code_typed_in_lower_case_with_a_dash_joins_the_game_holding_it",
		joined and Net.transport == "steam" and not Net.is_host and Net.session_code == CODE and Net.lobby == theirs,
		"in session %s, transport %s, code '%s', lobby %d of %d, heard %s" % [joined, Net.transport, Net.session_code,
			Net.lobby, theirs, _heard])
	_check("and_it_looked_for_the_code_as_read_and_entered_only_that_lobby",
		paper.searches.size() == 1 and paper.searches[0].get("code") == CODE and paper.entries == [theirs],
		"searched %s, entered %s" % [paper.searches, paper.entries])
	_check("and_the_lobby_counts_it", paper.members(theirs) == 2, "%d members" % paper.members(theirs))
	for i in range(20):
		server.poll()
		await get_tree().physics_frame
	_check("and_the_host_has_it", server.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED,
		"status %d" % server.get_connection_status())

	# AND SYNC'S PACKETS GO ON THE UNRELIABLE CARRIER. GodotSteam 4.21 sends Godot's UNRELIABLE_ORDERED as Steam's
	# Reliable (godotsteam_multiplayer_peer.cpp:721-723), so over Steam they travel on an RPC marked "unreliable";
	# ashiato-gd/addon/tests/crowd_shuffled.gd measured one packet in twenty swapped, dropped or doubled as spotless.
	# The real path: a joined machine's own simulation sends its handshake through `Net`, and `Net` counts what it
	# carried on which RPC.
	var rpcs: Dictionary = (Net.get_script() as Script).get_rpc_config()
	var steam_carrier: StringName = Net.carrier_for("steam")
	var enet_carrier: StringName = Net.carrier_for("enet")
	_check("over_steam_sync_rides_an_unreliable_rpc_and_over_enet_an_ordered_one",
		steam_carrier != enet_carrier
			and int(rpcs.get(steam_carrier, {}).get("transfer_mode", -1)) == MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
			and int(rpcs.get(enet_carrier, {}).get("transfer_mode", -1)) == MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,
		"steam %s %s, enet %s %s" % [steam_carrier, rpcs.get(steam_carrier), enet_carrier, rpcs.get(enet_carrier)])
	Net.carried.clear()
	Sim.start()
	for i in range(30):
		server.poll()
		await get_tree().physics_frame
	_check("and_a_joined_simulation_sends_on_the_steam_carrier_and_nothing_on_the_ordered_one",
		int(Net.carried.get(steam_carrier, 0)) > 0 and int(Net.carried.get(enet_carrier, 0)) == 0,
		"carried %s" % [Net.carried])
	Sim.stop()

	# THE HOST GOES. The session ends, the way every departure of a host ends one. Said to the joiner rather than the
	# socket simply closed: an ENet host that vanishes is noticed only when its peer times out, which is longer than this
	# suite waits, and the thing under test is what Net does on hearing it -- not ENet's timeout.
	server.disconnect_peer(Net.my_peer_id())
	var ended: bool = false
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 3000:
		server.poll()
		if Net.transport == "none":
			ended = true
			break
		await get_tree().process_frame
	server.close()
	_check("and_when_the_host_goes_the_session_ends", ended and not Net.is_in_session and Net.lobby == 0,
		"transport %s, lobby %d" % [Net.transport, Net.lobby])
	_sections += 1


## ---- 4: no, and why ---------------------------------------------------------------------------------------------------

func _every_way_a_join_is_refused_says_why() -> void:
	var spelled: String = JoinCode.spell(CODE)
	var cases: Array = [
		{"why": "no_steam", "typed": CODE, "says": "Steam is not in this build.", "asked": false,
			"set": func(p: PaperLobbyDirectory) -> void: p.said_unavailable = "Steam is not in this build."},
		{"why": "a_zero", "typed": "K0MQ2X", "says": "Codes have no 0, O, 1 or I.", "asked": false,
			"set": func(_p: PaperLobbyDirectory) -> void: pass},
		{"why": "too_short", "typed": "K7MQ2", "says": JoinCode.why_not("K7MQ2"), "asked": false,
			"set": func(_p: PaperLobbyDirectory) -> void: pass},
		{"why": "nobody_holds_it", "typed": CODE, "says": "No game has the code %s. Check it with the host." % spelled,
			"set": func(_p: PaperLobbyDirectory) -> void: pass},
		{"why": "another_games_lobby_holds_it", "typed": CODE,
			"says": "No game has the code %s. Check it with the host." % spelled,
			"set": func(p: PaperLobbyDirectory) -> void: p.put({"game": "somebody_else", "code": CODE}, 1, 8, THEIR_HOST, 0)},
		{"why": "steam_never_answers_the_search", "typed": CODE, "says": "Steam did not answer. Try again.",
			"set": func(p: PaperLobbyDirectory) -> void: p.answers_searches = false},
		{"why": "two_lobbies_hold_it", "typed": CODE, "says": "Two games share that code; ask the host to host again.",
			"set": func(p: PaperLobbyDirectory) -> void: _theirs(p, 1, THEIR_HOST, Net.build(), 2)},
		# FULL AT THE SESSION'S OWN CAP, read from Net: it typed 8 of 8, and the cap went to 64 (lane/seats, 2026-09-18).
		{"why": "it_is_full", "typed": CODE, "says": "That game is full (%d of %d)." % [Net.MAX_PLAYERS, Net.MAX_PLAYERS],
			"set": func(p: PaperLobbyDirectory) -> void: _theirs(p, Net.MAX_PLAYERS, THEIR_HOST, Net.build(), 1)},
		{"why": "another_build", "typed": CODE, "says": "The host is on a different build.",
			"set": func(p: PaperLobbyDirectory) -> void: _theirs(p, 1, THEIR_HOST, "a release behind", 1)},
		{"why": "another_alpha_revision", "typed": CODE,
			"says": "The host is on an incompatible alpha revision.",
			"set": func(p: PaperLobbyDirectory) -> void:
				var written: Dictionary = _their_lobby()
				written["compatibility"] = "cockpit-older-p7-same-native"
				p.put(written, 1, Net.MAX_PLAYERS, THEIR_HOST, DEAD_PORT)},
		# AND THIS ONE COSTS A LOBBY ENTRY, which it did not until 2026-09-15. Steam answers 0 when a machine asks who
		# owns a lobby it is not in (`Net._whose_lobby_it_turned_out_to_be`), so the question cannot be put to a search
		# result at all: it is asked once inside, and the refusal is the same sentence one step later.
		{"why": "its_host_has_gone", "typed": CODE, "says": "The host has left that game.", "entered": true,
			"set": func(p: PaperLobbyDirectory) -> void: _theirs(p, 1, THEIR_HOST + 1, Net.build(), 1)},
		{"why": "it_ended_before_we_got_in", "typed": CODE, "says": "That game has ended.", "entered": true,
			"set": func(p: PaperLobbyDirectory) -> void: _answering(_theirs(p, 1, THEIR_HOST, Net.build(), 1),
				LobbyDirectory.DOES_NOT_EXIST)},
		{"why": "it_filled_before_we_got_in", "typed": CODE, "says": "That game filled up.", "entered": true,
			"set": func(p: PaperLobbyDirectory) -> void: _answering(_theirs(p, 1, THEIR_HOST, Net.build(), 1),
				LobbyDirectory.FULL)},
		{"why": "too_many_tries", "typed": CODE, "says": "Too many tries; wait a minute.", "entered": true,
			"set": func(p: PaperLobbyDirectory) -> void: _answering(_theirs(p, 1, THEIR_HOST, Net.build(), 1),
				LobbyDirectory.RATE_LIMITED)},
		{"why": "steam_says_no_for_its_own_reasons", "typed": CODE, "says": "Steam would not let you in (response 3).",
			"entered": true, "set": func(p: PaperLobbyDirectory) -> void: _answering(_theirs(p, 1, THEIR_HOST,
				Net.build(), 1), LobbyDirectory.NOT_ALLOWED)},
		{"why": "steam_never_lets_us_in", "typed": CODE, "says": "Steam did not let you into that game in time.",
			"entered": true, "set": func(p: PaperLobbyDirectory) -> void: _silent_at_the_door(_theirs(p, 1, THEIR_HOST,
				Net.build(), 1))},
		# WHERE AND HOW LONG, since the handshake (2026-09-18): it said "The host did not answer." and nothing else.
		{"why": "the_host_never_answers_the_socket", "typed": CODE,
			"says": Net.connect_words("game %s" % JoinCode.spell(CODE), SHORT, true), "entered": true,
			"set": func(p: PaperLobbyDirectory) -> void: _theirs(p, 1, THEIR_HOST, Net.build(), 1)},
	]
	for case in cases:
		var paper := _paper(DEAD_PORT)
		(case["set"] as Callable).call(paper)
		_heard.clear()
		Net.join_code(String(case["typed"]))
		var over: bool = await _until(func() -> bool: return Net.transport == "none")
		var asked: bool = not paper.searches.is_empty()
		var entered: bool = not paper.entries.is_empty()
		# NOTHING LEFT HALF DONE: out of the session, out of any lobby, and no socket open.
		var left_clean: bool = not Net.is_in_session and Net.lobby == 0 and not Net.is_networked()
		_check("refused_when_%s" % case["why"], over and _last() == String(case["says"]) and left_clean,
			"said '%s', wanted '%s', clean %s, in session %s, lobby %d" % [_last(), case["says"], left_clean,
				Net.is_in_session, Net.lobby])
		if not bool(case.get("asked", true)):
			_check("and_no_directory_was_asked_when_%s" % case["why"], not asked, "searches %s" % [paper.searches])
		_check("and_it_%s_the_lobby_when_%s" % ["entered" if bool(case.get("entered", false)) else "never_entered",
			case["why"]], entered == bool(case.get("entered", false)), "entries %s" % [paper.entries])
		if bool(case.get("entered", false)):
			var one: int = int(paper.entries[0]) if entered else 0
			_check("and_left_it_as_it_found_it_when_%s" % case["why"], paper.members(one) == 1,
				"%d members" % paper.members(one))
		# AND NEVER LEFT A LOBBY IT WAS NOT IN. The first green run left every lobby that refused it at the door, and a
		# paper directory that counted those leaves took the other game's host out of their own lobby.
		_check("and_left_no_lobby_it_was_not_in_when_%s" % case["why"], paper.stray_leaves.is_empty(),
			"stray leaves %s" % [paper.stray_leaves])
	_sections += 1


## ---- 5: an invite ------------------------------------------------------------------------------------------------------

## AN INVITE ACCEPTED, OR JOIN GAME ON A FRIEND'S PROFILE, lands in the same join: asked for on 2026-09-14, "joinable by
## code AND by Steam invites and friends' profiles". No search finds the lobby, so the game, the build and the host are
## checked once it is entered -- and a refused invite leaves the lobby it entered as full as it found it.
func _an_invite_lands_in_the_same_join_with_the_same_refusals() -> void:
	var paper := _paper(DEAD_PORT)
	var server := ENetMultiplayerPeer.new()
	server.create_server(JOIN_PORT, Net.MAX_PLAYERS)
	var theirs: int = paper.put(_their_lobby(), 1, Net.MAX_PLAYERS, THEIR_HOST, JOIN_PORT)
	paper.invite(theirs)
	var joined: bool = false
	for i in range(PATIENCE):
		server.poll()
		_answer_as_the_host()
		if Net.is_in_session:
			joined = true
			break
		await get_tree().physics_frame
	_check("an_invite_joins_the_lobby_it_names_with_no_search",
		joined and Net.transport == "steam" and Net.lobby == theirs and paper.searches.is_empty()
			and paper.entries == [theirs], "in session %s, lobby %d of %d, searched %s, entered %s" % [joined, Net.lobby,
			theirs, paper.searches, paper.entries])
	_check("and_learns_the_code_to_pass_on_from_the_lobby", Net.session_code == CODE, "'%s'" % Net.session_code)
	Net.leave("suite")
	for i in range(10):
		server.poll()
		await get_tree().physics_frame
	server.close()

	var cases: Array = [
		{"why": "another_game", "says": "That is not a cockpit game.", "data": {"game": "somebody_else"}},
		{"why": "another_build", "says": "The host is on a different build.", "data": {"build": "a release behind"}},
		{"why": "its_host_has_gone", "says": "The host has left that game.", "data": {"host": str(THEIR_HOST + 1)}},
		{"why": "it_is_on_a_level_this_game_does_not_have", "says": "That game is flying nowhere, a level this game does not have.",
			"data": {"level": "nowhere"}},
		{"why": "its_copy_of_the_level_is_not_ours", "says": "The host's copy of The island is not the same as yours.",
			"data": {"level_hash": "0".repeat(64)}},
	]
	for case in cases:
		paper = _paper(DEAD_PORT)
		var written: Dictionary = _their_lobby()
		written.merge(case["data"], true)
		var lobby: int = paper.put(written, 1, Net.MAX_PLAYERS, THEIR_HOST, DEAD_PORT)
		_heard.clear()
		paper.invite(lobby)
		var over: bool = await _until(func() -> bool: return not paper.entries.is_empty() and Net.transport == "none")
		_check("an_invite_is_refused_when_%s" % case["why"], over and _last() == String(case["says"])
			and not Net.is_in_session and Net.lobby == 0 and paper.members(lobby) == 1,
			"said '%s', wanted '%s', %d members" % [_last(), case["says"], paper.members(lobby)])

	paper = _paper(DEAD_PORT)
	paper.said_unavailable = "Steam is not in this build."
	_heard.clear()
	Net.join_lobby(paper.put(_their_lobby(), 1, Net.MAX_PLAYERS, THEIR_HOST, DEAD_PORT))
	_check("and_an_invite_with_no_steam_says_so", _last() == "Steam is not in this build." and paper.entries.is_empty(),
		"said '%s'" % _last())
	_sections += 1


## ---- 6: a host refused, at the desk ---------------------------------------------------------------------------------

func _every_way_hosting_is_refused_says_why_and_the_desk_stays() -> void:
	var cases: Array = [
		{"why": "no_steam", "says": "Steam is not in this build.",
			"set": func(p: PaperLobbyDirectory) -> void: p.said_unavailable = "Steam is not in this build."},
		{"why": "steam_never_answers_the_check", "says": "Steam did not answer. Try again.",
			"set": func(p: PaperLobbyDirectory) -> void: p.answers_searches = false},
		{"why": "steam_will_not_make_a_lobby", "says": "Steam could not make a lobby (result 16).",
			"set": func(p: PaperLobbyDirectory) -> void: p.open_result = 16},
		{"why": "steam_never_makes_the_lobby", "says": "Steam did not make a lobby in time.",
			"set": func(p: PaperLobbyDirectory) -> void: p.answers_opening = false},
	]
	for case in cases:
		var paper := _paper(HOST_PORT)
		(case["set"] as Callable).call(paper)
		_heard.clear()
		Net.host_steam()
		var over: bool = await _until(func() -> bool: return Net.transport == "none")
		_check("hosting_refused_when_%s" % case["why"], over and _last() == String(case["says"])
			and not Net.is_in_session and paper.lobbies.is_empty(),
			"said '%s', wanted '%s', lobbies left %s" % [_last(), case["says"], paper.lobbies.keys()])

	# AND AT THE DESK THE WORDS ARE ON THE SCREEN AND THE PLAYER IS STILL THERE TO READ THEM, through the real button.
	var paper := _paper(HOST_PORT)
	paper.said_unavailable = "Steam is not in this build."
	await _open("res://world/desk.tscn")
	for i in range(4):
		await get_tree().process_frame
	var desk := get_tree().current_scene
	_press(desk, "Host over Steam")
	for i in range(30):
		await get_tree().physics_frame
	var shown: bool = false
	for node in desk.find_children("*", "Label", true, false):
		shown = shown or String((node as Label).text) == "Steam is not in this build."
	_check("at_the_desk_a_refused_host_stays_at_the_desk_reading_why",
		get_tree().current_scene == desk and desk is DeskRoom and shown and Net.transport == "none",
		"scene %s, words on the screen %s, transport %s" % [get_tree().current_scene, shown, Net.transport])
	_check("and_can_still_press_something_else", not bool(desk.get("_going")), "going %s" % desk.get("_going"))
	_sections += 1


## ---- 7: Steam up at the desk, for an invite -------------------------------------------------------------------------

## AN INVITE ONLY REACHES A MACHINE THAT HAS STARTED STEAM. GodotSteam's `join_requested` -- an invite accepted, or Join
## Game on a friend's profile -- is a callback, and callbacks reach only a process that initialised Steam and pumps them.
## `SteamLobbyDirectory` starts Steam the first time it is asked, which was the first Steam button: a player sitting at the
## desk who accepted an invite from the overlay heard nothing. So the desk asks when it opens -- but never headless,
## where a suite, a harness or a second instance on one machine must not touch the Steam client.
##
## THE SEAM IS `DeskRoom.starts_steam`, a Callable that says whether this desk is somewhere an invite could arrive. Asked
## for by name (`set`, `get`), so this parsed and failed before the seam and the paper directory's count existed.
func _the_desk_starts_steam_only_where_an_invite_could_arrive() -> void:
	var paper := _paper(HOST_PORT)
	await _open("res://world/desk.tscn")
	for i in range(4):
		await get_tree().process_frame
	_check("a_headless_desk_does_not_start_steam", paper.get("asked") == 0, "asked %s" % [paper.get("asked")])

	get_tree().unload_current_scene()
	await get_tree().process_frame
	paper = _paper(HOST_PORT)
	var desk: Node = (load("res://world/desk.tscn") as PackedScene).instantiate()
	desk.set("starts_steam", func() -> bool: return true)
	add_child(desk)
	for i in range(4):
		await get_tree().process_frame
	_check("and_a_desk_where_an_invite_could_arrive_starts_it_once", paper.get("asked") == 1,
		"asked %s" % [paper.get("asked")])
	desk.queue_free()
	await get_tree().process_frame
	_sections += 1


## ---- 8: Steam's one search slot ------------------------------------------------------------------------------------------

func _browse_and_code_search_keep_their_own_answers_and_deadlines() -> void:
	var paper := _paper(DEAD_PORT)
	var theirs: int = paper.put(_their_lobby(), 1, Net.MAX_PLAYERS, THEIR_HOST, DEAD_PORT)
	var listed: Array = []
	var on_listed := func(games: Array) -> void: listed.append(games)
	Net.games_listed.connect(on_listed)

	# Steamworks permits one RequestLobbyList and cancels the old one when another starts.
	# Hold the browse forever, then type a code. The code must supersede it immediately;
	# its answer must enter the matching lobby, and the browse must be retried afterward.
	paper.answers_searches = false
	Net.look_for_games()
	await get_tree().process_frame
	paper.answers_searches = true
	Net.join_code(CODE)
	var both: bool = await _until(func() -> bool:
		return paper.entries.has(theirs) and listed.any(func(games: Array) -> bool: return not games.is_empty()))
	_check("a_code_search_supersedes_a_silent_browse_and_keeps_its_own_answer",
		both and paper.searches.size() == 3 and paper.searches[1].get("code") == CODE,
		"entries %s searches %s lists %d" % [paper.entries, paper.searches, listed.size()])
	Net.leave("overlap proved")

	# A request which never answers must release the directory at its deadline. A later
	# browse is a new owner and gets its answer instead of waiting behind a poisoned slot.
	paper = _paper(DEAD_PORT)
	paper.answers_searches = false
	listed.clear()
	Net.look_for_games()
	var timed_out: bool = await _until(func() -> bool: return not listed.is_empty())
	paper.answers_searches = true
	paper.put(_their_lobby(), 1, Net.MAX_PLAYERS, THEIR_HOST, DEAD_PORT)
	Net.look_for_games()
	var retried: bool = await _until(func() -> bool:
		return listed.size() >= 2 and not (listed.back() as Array).is_empty())
	_check("a_timed_out_search_does_not_poison_the_next_search",
		timed_out and retried and paper.searches.size() == 2,
		"timed out %s retried %s searches %s" % [timed_out, retried, paper.searches])
	Net.games_listed.disconnect(on_listed)
	_sections += 1


## ---- the machinery ------------------------------------------------------------------------------------------------------

## A FRESH PAPER DIRECTORY ON `Net`, with every stage's deadline short. Put back in `_finish`.
func _paper(port: int) -> PaperLobbyDirectory:
	Net.leave("suite")
	var paper := PaperLobbyDirectory.new()
	paper.port = port
	Net.lobbies = paper
	for stage in Net.PATIENCE:
		Net.patience[stage] = SHORT
	return paper


## THE FIRST LINE OF THE CLIPBOARD'S CREW TAB, as a player in the world would see it: the board up, the tab shown, the
## page refreshed as it is every frame the board is up. "" when there is no such line.
## WHAT THE BOARD SAYS ABOUT THE SESSION, off the line the code is written on. On CREW, which is where it was until
## 2026-09-15 and is as good a tab as any now that it is on all of them -- tests/clipboard.gd is what walks the eight.
func _crew_line(level: FlightLevel) -> String:
	if level == null or level.rig == null or level.rig.clipboard == null:
		return ""
	var board: Clipboard = level.rig.clipboard
	board.show_board(true)
	var page: ClipboardPage = board.page()
	page.show_tab(ClipboardPage.Tab.CREW)
	page.tick()
	for node in page.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text.begins_with("STEAM CODE"):
			return label.text
	return ""


## What the other machine's host would have written on its lobby.
func _their_lobby() -> Dictionary:
	return {"game": Net.GAME_TAG, "code": CODE, "build": Net.build(), "compatibility": Net.compatibility(),
		"host": str(THEIR_HOST),
		"level": Net.level, "level_hash": ChartDrawer.chart(Net.level).content_hash}


## `copies` LOBBIES HOLDING THE CODE, written down by a host that is `owned_by` now, on `build`, with `in_it` members of
## eight, carried on the dead port. Returns the paper, so a case can go on to change how it answers.
func _theirs(paper: PaperLobbyDirectory, in_it: int, owned_by: int, build: String, copies: int) -> PaperLobbyDirectory:
	var written: Dictionary = _their_lobby()
	written["build"] = build
	for i in range(copies):
		paper.put(written, in_it, Net.MAX_PLAYERS, owned_by, DEAD_PORT)
	return paper


func _answering(paper: PaperLobbyDirectory, response: int) -> void:
	paper.enter_response = response


func _silent_at_the_door(paper: PaperLobbyDirectory) -> void:
	paper.answers_entries = false


func _last() -> String:
	return String(_heard.back()) if not _heard.is_empty() else ""


## Frames until something is true, on the real clock -- the deadlines under test are real time -- or three seconds.
func _until(done: Callable) -> bool:
	var since: int = Time.get_ticks_msec()
	while not done.call():
		if Time.get_ticks_msec() - since > 3000:
			return false
		await get_tree().process_frame
	return true


func _wait_for(until: Callable) -> bool:
	for i in range(PATIENCE):
		if until.call():
			return true
		await get_tree().physics_frame
	return until.call()


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)
	for i in range(PATIENCE):
		await get_tree().physics_frame
		var now: Node = get_tree().current_scene
		if now != null and now.scene_file_path == path:
			await get_tree().physics_frame
			return


## The real Button by its words, and what a press emits. See tests/session.gd for why not a synthetic click.
func _press(within: Node, words: String) -> bool:
	if within == null:
		return false
	for node in within.find_children("*", "Button", true, false):
		if (node as Button).text == words:
			(node as Button).pressed.emit()
			return true
	return false


func _finish() -> void:
	Sim.stop()
	Net.leave("suite over")
	Net.lobbies = SteamLobbyDirectory.new()
	Net.patience = Net.PATIENCE.duplicate()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## THE HOST'S HELLO, said for a host that is a bare socket. A real host names its level before a joiner is in the
## session (Net's "THE HELLO"); this one cannot speak, so the suite says it for it once the joiner is waiting.
func _answer_as_the_host() -> void:
	if Net.transport != "none" and not Net.is_in_session and String(Net.get("_stage")) == "hello":
		var chart: LevelChart = ChartDrawer.chart(Net.level)
		Net.hear_hello(1, JSON.stringify({"say": "level", "protocol": Net.PROTOCOL, "level": chart.id,
			"hash": chart.content_hash, "name": chart.name}).to_utf8_buffer())
