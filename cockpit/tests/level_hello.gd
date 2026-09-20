extends Node
## Headless, one process: the join handshake's pieces, each where it can be made to fail. What a hello may say, why a
## joiner refuses a level, a joiner connected over a real loopback socket that is NOT in the session until the host has
## named a level it has, and a host that holds back a peer's simulation until that peer says its level is loaded.
##
##   Godot --headless --path cockpit res://tests/level_hello.tscn
##
## THE HOST HERE IS A BARE ENET SOCKET, so its hello is spoken through `Net.hear_hello` -- the function the carriers call
## with a packet whose bit count is below zero. Two real processes saying it to each other over the carriers is
## tests/level_join.gd; this is what can be pinned down to the word in one.
##
## THE MALFORMED HELLOS ARE UNTRUSTED INPUT (CLAUDE.md, rule 8): each is dropped with a warning, which this suite prints
## on purpose.
##
## Read RESULT=, not the exit code.

const FIXTURES: String = "res://tests/level_fixtures"
## A port of the lane's own range, off every other suite's.
## 47951 of this checkout's block (`TestPorts`), asked silently at load whether anything holds it: a fixed
## number was the same socket in every lane. Held, and the suite says PORT BUSY at once rather than timing out.
static var PORT: int = TestPorts.first_free(47951, 1)
const PATIENCE: int = 600

var _failures: PackedStringArray = []
var _sections: int = 0
var _heard: Array[String] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[level_hello] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if PORT == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(47951, 1))
		get_tree().quit(1)
		return
	ChartDrawer.open_at(FIXTURES)
	Net.session_message.connect(func(text: String) -> void: _heard.append(text))
	_what_a_hello_may_say()
	_why_a_joiner_refuses_a_level()
	await _a_joiner_is_not_in_the_session_until_the_host_names_a_level_it_has()
	if ClassDB.class_exists("CockpitWorld"):
		await _the_host_holds_back_a_joiner_until_its_level_is_loaded()
		await _the_host_changes_the_level_and_the_handshake_runs_again()
	else:
		_check("extension_loaded", false, "CockpitWorld missing")
	_check("every_section_of_the_suite_ran", _sections == 5, "%d of 5" % _sections)
	_finish()


## ---- 1: the validator ----------------------------------------------------------------------------------------------

func _what_a_hello_may_say() -> void:
	var good_a: LevelChart = ChartDrawer.chart("good_a")
	var hash: String = good_a.content_hash
	var level: Dictionary = Net.read_hello(_bytes({"say": "level", "protocol": Net.PROTOCOL, "level": "good_a",
		"hash": hash, "name": "Good A", "evil": "a key no hello has"}))
	_check("a_level_hello_is_read_with_only_its_own_keys", level == {"say": "level", "protocol": Net.PROTOCOL,
		"level": "good_a", "hash": hash, "name": "Good A"}, "%s" % [level])
	var loaded: Dictionary = Net.read_hello(_bytes({"say": "loaded", "protocol": Net.PROTOCOL, "level": "good_a",
		"hash": hash, "ground": "-8105423577052357018"}))
	_check("a_loaded_hello_is_read_with_its_ground", loaded == {"say": "loaded", "protocol": Net.PROTOCOL,
		"level": "good_a", "hash": hash, "ground": "-8105423577052357018"}, "%s" % [loaded])
	# THE SKY (plan item 17): read with its own keys, and a level hello carries it whole or not at all.
	# A CLOCK SINCE 2026-09-18: where it was, at which of the session's frames, and how fast it runs.
	var sky: Dictionary = Net.read_hello(_bytes({"say": "sky", "clock": 1065.0, "frame": 480.0, "rate": 60.0,
		"clouds": false, "n": 3, "finish": "fine"}))
	_check("a_sky_is_read_with_only_its_own_keys_and_never_a_finish",
		sky == {"say": "sky", "clock": 1065.0, "frame": 480.0, "rate": 60.0, "clouds": false, "n": 3}, "%s" % [sky])
	var level_sky: Dictionary = Net.read_hello(_bytes({"say": "level", "protocol": Net.PROTOCOL, "level": "good_a",
		"hash": hash, "name": "Good A", "clock": 628.5, "frame": 0.0, "rate": 1.0, "clouds": true, "n": 0}))
	_check("and_a_level_hello_carries_one", level_sky.get("clock") == 628.5 and level_sky.get("rate") == 1.0
		and level_sky.get("clouds") == true and level_sky.get("n") == 0, "%s" % [level_sky])
	# THE CLOCK AND THE RATE ARE MAGNITUDES, clamped and said rather than dropped (CLAUDE.md, rule 8).
	var clamped: Dictionary = Net.read_hello(_bytes({"say": "sky", "clock": 5000.0, "frame": 0.0,
		"rate": Net.CLOCK_RATE_MOST * 10.0, "clouds": true, "n": 1}))
	_check("and_a_clock_past_midnight_and_a_rate_past_the_most_are_clamped",
		clamped.get("clock") == Orrery.DAY_LONG and clamped.get("rate") == Net.CLOCK_RATE_MOST, "%s" % [clamped])
	# THE NOTICES (plan item 13): a kind and its facts, never words; a count-down is a magnitude and is clamped.
	var joined: Dictionary = Net.read_hello(_bytes({"say": "notice", "kind": "joined", "player": 2, "n": 4,
		"words": "free text a host could print on your board"}))
	_check("a_notice_is_read_with_its_facts_and_never_words",
		joined == {"say": "notice", "kind": "joined", "player": 2, "n": 4}, "%s" % [joined])
	var sky_notice: Dictionary = Net.read_hello(_bytes({"say": "notice", "kind": "sky",
		"clock": 1410.0, "rate": 0.0, "clouds": false, "n": 5}))
	_check("and_a_sky_notice_is_read_as_bounded_facts",
		sky_notice == {"say": "notice", "kind": "sky", "clock": 1410.0, "rate": 0.0,
			"clouds": false, "n": 5}, "%s" % [sky_notice])
	var long_wait: Dictionary = Net.read_hello(_bytes({"say": "notice", "kind": "level", "level": "good_b", "in": 9.0e6,
		"hash": ChartDrawer.chart("good_b").content_hash, "n": 1}))
	_check("and_a_level_count_down_is_clamped_to_the_warning",
		long_wait.get("in") == Net.LEVEL_WARNING_MSEC and long_wait.get("level") == "good_b", "%s" % [long_wait])
	_check("and_an_admission_is_read", Net.read_hello(_bytes({"say": "admitted", "why": "no key"})) == {"say": "admitted"},
		"")
	var long_why: Dictionary = Net.read_hello(_bytes({"say": "refused", "why": "x".repeat(300)}))
	_check("a_refusal_s_reason_is_cut_to_its_most", String(long_why.get("why", "")).length() == Net.HELLO_WHY_MOST,
		"%d letters" % String(long_why.get("why", "")).length())
	var dropped: Dictionary = {
		"over_the_most_bytes": ("{\"say\": \"refused\", \"why\": \"%s\"}" % "y".repeat(Net.HELLO_MOST_BYTES)).to_utf8_buffer(),
		"not_json": "{ say: level".to_utf8_buffer(),
		"a_json_array": "[1, 2, 3]".to_utf8_buffer(),
		"no_bytes_at_all": PackedByteArray(),
		"a_say_no_hello_says": _bytes({"say": "hello"}),
		"a_protocol_in_words": _bytes({"say": "loaded", "protocol": "1", "level": "good_a", "hash": hash}),
		"a_protocol_with_a_fraction": _bytes({"say": "loaded", "protocol": 1.5, "level": "good_a", "hash": hash}),
		"a_level_that_is_no_id": _bytes({"say": "loaded", "protocol": 1, "level": "Bad-Id", "hash": hash}),
		"a_short_hash": _bytes({"say": "loaded", "protocol": 1, "level": "good_a", "hash": "abc"}),
		"a_name_too_long": _bytes({"say": "level", "protocol": 1, "level": "good_a", "hash": hash,
			"name": "n".repeat(LevelChart.NAME_MOST + 1)}),
		"a_refusal_with_no_reason": _bytes({"say": "refused"}),
		"a_loaded_hello_with_no_ground": _bytes({"say": "loaded", "protocol": 1, "level": "good_a", "hash": hash}),
		"a_ground_that_is_not_a_hash": _bytes({"say": "loaded", "protocol": 1, "level": "good_a", "hash": hash,
			"ground": "0x5f; drop"}),
		"a_sky_with_a_preset_and_no_clock": _bytes({"say": "sky", "time": 2, "clouds": true, "n": 1}),
		"a_clock_in_words": _bytes({"say": "sky", "clock": "23:30", "frame": 0.0, "rate": 1.0, "clouds": true, "n": 1}),
		"a_clock_with_no_frame": _bytes({"say": "sky", "clock": 600.0, "rate": 1.0, "clouds": true, "n": 1}),
		"a_rate_in_words": _bytes({"say": "sky", "clock": 600.0, "frame": 0.0, "rate": "fast", "clouds": true, "n": 1}),
		"clouds_that_are_a_number": _bytes({"say": "sky", "clock": 0.0, "frame": 0.0, "rate": 1.0, "clouds": 1, "n": 1}),
		"a_sky_with_no_count": _bytes({"say": "sky", "clock": 0.0, "frame": 0.0, "rate": 1.0, "clouds": true}),
		"a_notice_of_a_kind_there_are_no_words_for": _bytes({"say": "notice", "kind": "crashed", "player": 2, "n": 1}),
		"a_notice_naming_player_0": _bytes({"say": "notice", "kind": "left", "player": 0, "n": 1}),
		"a_notice_naming_a_player_past_the_most": _bytes({"say": "notice", "kind": "joined",
			"player": Net.PLAYER_MOST + 1, "n": 1}),
		"a_notice_naming_a_player_in_words": _bytes({"say": "notice", "kind": "joined", "player": "two", "n": 1}),
		"a_level_notice_naming_no_level": _bytes({"say": "notice", "kind": "level", "level": "Bad-Id", "in": 100, "n": 1}),
		"a_level_notice_counting_down_below_nothing": _bytes({"say": "notice", "kind": "level", "level": "good_b",
			"hash": ChartDrawer.chart("good_b").content_hash, "in": -5, "n": 1}),
		"a_level_notice_with_another_builds_hash": _bytes({"say": "notice", "kind": "level", "level": "good_b",
			"hash": "not this level", "in": 100, "n": 1}),
		"a_notice_with_no_count": _bytes({"say": "notice", "kind": "left", "player": 2}),
		"a_sky_notice_with_a_clock_in_words": _bytes({"say": "notice", "kind": "sky", "clock": "night", "rate": 1.0,
			"clouds": false, "n": 1}),
		"a_sky_notice_with_numeric_clouds": _bytes({"say": "notice", "kind": "sky", "clock": 0.0, "rate": 1.0,
			"clouds": 0, "n": 1}),
		"a_level_hello_with_half_a_sky": _bytes({"say": "level", "protocol": Net.PROTOCOL, "level": "good_a", "hash": hash,
			"name": "Good A", "clock": 600.0}),
	}
	for why in dropped:
		_check("a_hello_is_dropped_for_%s" % why, Net.read_hello(dropped[why] as PackedByteArray).is_empty(), "")
	_sections += 1


## ---- 2: the joiner's question ---------------------------------------------------------------------------------------

func _why_a_joiner_refuses_a_level() -> void:
	var hash: String = ChartDrawer.chart("good_a").content_hash
	var cases: Array = [
		[{"protocol": Net.PROTOCOL, "level": "good_a", "hash": hash, "name": "Good A"}, ""],
		[{"protocol": Net.PROTOCOL + 1, "level": "good_a", "hash": hash, "name": "Good A"},
			Net.host_protocol_words(Net.PROTOCOL + 1, BuildPlate.line())],
		[{"protocol": Net.PROTOCOL, "level": "nowhere", "hash": hash, "name": "Nowhere"},
			"The host is flying Nowhere, a level this game does not have."],
		[{"protocol": Net.PROTOCOL, "level": "good_a", "hash": "0".repeat(64), "name": "Good A"},
			"The host's copy of Good A is not the same as yours."],
	]
	for case in cases:
		var said: String = Net.why_not_the_level(case[0])
		_check("a_joiner_told_%s_%s_says_%s" % [case[0]["level"], String(case[0]["hash"]).left(4),
			"yes" if case[1] == "" else "no"], said == String(case[1]), "'%s'" % said)
	_sections += 1


## ---- 3: a joiner on a real socket --------------------------------------------------------------------------------

func _a_joiner_is_not_in_the_session_until_the_host_names_a_level_it_has() -> void:
	Net.choose_level("good_a")
	var host := ENetMultiplayerPeer.new()
	var err: int = host.create_server(PORT, 4)
	_check("a_bare_host_listens", err == OK, error_string(err))
	# RIGHT LEVEL: connected, waiting, then in.
	var ready: Array[int] = [0]
	var counting := func() -> void: ready[0] += 1
	Net.session_ready.connect(counting)
	Net.join("127.0.0.1", PORT)
	var connected: bool = await _pump(host, func() -> bool: return _heard.has("Connected. Asking the host which level..."))
	_check("a_joiner_connected_is_not_yet_in_the_session", connected and not Net.is_in_session and ready[0] == 0,
		"connected %s, in session %s, ready %d, heard %s" % [connected, Net.is_in_session, ready[0], _heard])
	var hash_b: String = ChartDrawer.chart("good_b").content_hash
	Net.hear_hello(1, _bytes({"say": "level", "protocol": Net.PROTOCOL, "level": "good_b", "hash": hash_b,
		"name": "Good B"}))
	_check("and_once_the_host_names_a_level_it_has_it_is_in_that_level", Net.is_in_session and ready[0] == 1
		and Net.level == "good_b", "in session %s, ready %d, level %s" % [Net.is_in_session, ready[0], Net.level])
	# SAID AGAIN, WITH THE SAME LEVEL: nothing changes. The host repeats the level hello every 200 ms until it is
	# answered, so a joiner must not re-enter the session on each repeat.
	#
	# THIS USED TO SAY A DIFFERENT LEVEL (good_a) and hold that nothing changed, which was right while a level hello
	# mid-session meant nothing at all. Since item 11 a different level mid-session IS the host changing the level, and
	# section 5 holds what it does instead -- so the check was rewritten rather than kept, because what it asserted is
	# now the bug (CLAUDE.md, rule 12).
	Net.hear_hello(1, _bytes({"say": "level", "protocol": Net.PROTOCOL, "level": "good_b", "hash": hash_b,
		"name": "Good B"}))
	_check("and_a_hello_said_again_with_the_same_level_changes_nothing", Net.level == "good_b" and ready[0] == 1,
		"level %s, ready %d" % [Net.level, ready[0]])
	Net.level_loaded("")
	_check("and_once_its_level_is_built_it_says_so_until_answered", int(Net.get("_loaded_next")) >= 0,
		"next %d" % int(Net.get("_loaded_next")))
	Net.hear_hello(1, _bytes({"say": "admitted"}))
	_check("and_stops_when_the_host_admits_it", int(Net.get("_loaded_next")) == -1,
		"next %d" % int(Net.get("_loaded_next")))
	var sent_away: String = "The ground under your Good B is not the host's: the two builds make it differently."
	Net.hear_hello(1, _bytes({"say": "refused", "why": sent_away}))
	var refused_last: String = _heard.back() if not _heard.is_empty() else ""
	_check("and_a_joiner_the_host_refuses_leaves_in_the_host_s_words",
		refused_last == sent_away and not Net.is_in_session and Net.transport == "none",
		"heard '%s', transport %s" % [refused_last, Net.transport])
	Net.session_ready.disconnect(counting)
	Net.leave("suite")
	await _pump(host, _never, 20)

	# WRONG COPY: refused in words, out of the session, the socket closed.
	_heard.clear()
	Net.join("127.0.0.1", PORT)
	await _pump(host, _asking)
	Net.hear_hello(1, _bytes({"say": "level", "protocol": Net.PROTOCOL, "level": "good_b", "hash": "f".repeat(64),
		"name": "Good B"}))
	var last: String = _heard.back() if not _heard.is_empty() else ""
	_check("a_joiner_told_a_different_copy_is_refused_in_words",
		last == "The host's copy of Good B is not the same as yours." and not Net.is_in_session
			and Net.transport == "none" and not Net.is_networked(),
		"heard '%s', in session %s, transport %s" % [last, Net.is_in_session, Net.transport])
	await _pump(host, _never, 20)

	# NO HELLO AT ALL: the hello's own deadline says so.
	_heard.clear()
	Net.patience["hello"] = 1.0
	Net.join("127.0.0.1", PORT)
	var gave_up: bool = await _pump_for_msec(host, _given_up_on_the_hello, 4000)
	_check("a_host_that_never_names_a_level_is_given_up_on", gave_up and not Net.is_in_session,
		"heard %s" % [_heard])
	Net.patience["hello"] = Net.PATIENCE["hello"]
	host.close()
	await _frames(10)
	_sections += 1


## ---- 4: the host's gate -----------------------------------------------------------------------------------------

func _the_host_holds_back_a_joiner_until_its_level_is_loaded() -> void:
	Net.leave("suite")
	Net.choose_level("good_a")
	Net.host(PORT)
	Sim.start()
	Net.level_loaded("")
	var stranger: int = 424242
	var clients_before: int = Sim.server.connected_clients().size()
	Sim.call("_on_packet", stranger, PackedByteArray([1, 2, 3, 4]), 30)
	_check("a_peer_that_has_not_said_its_level_is_loaded_is_held_back",
		not Net.admits(stranger) and Net.held_back == 1 and Sim.server.connected_clients().size() == clients_before,
		"admits %s, held %d, clients %d -> %d" % [Net.admits(stranger), Net.held_back, clients_before,
			Sim.server.connected_clients().size()])
	_check("while_this_machine_s_own_client_is_not", Net.admits(Net.my_peer_id()), "peer %d" % Net.my_peer_id())
	var mine: LevelChart = ChartDrawer.chart("good_a")
	# A PEER THAT SKIPS ITS HI: the right level, the right ground, and never let in, because nobody checked its build
	# (tests/handshake_peers.gd holds the same over real sockets).
	var skipper: int = 414141
	(Net.get("_greeting") as Dictionary)[skipper] = Time.get_ticks_msec() + 60000
	Net.hear_hello(skipper, _bytes({"say": "loaded", "protocol": Net.PROTOCOL, "level": "good_a",
		"hash": mine.content_hash, "ground": ""}))
	_check("a_peer_that_never_said_hi_is_not_let_in_however_right_its_level", not Net.admits(skipper),
		"admitted %s" % [Net.admitted])
	(Net.get("_greeting") as Dictionary).erase(skipper)
	_knock(stranger)
	Net.hear_hello(stranger, _bytes({"say": "loaded", "protocol": Net.PROTOCOL, "level": "good_b",
		"hash": ChartDrawer.chart("good_b").content_hash, "ground": ""}))
	_check("a_peer_that_loaded_another_level_is_not_let_in", not Net.admits(stranger), "")
	var other: int = 434343
	# A PEER NOT YET SENT AWAY: one refused is never let in, however it asks again.
	var welcome: int = 454545
	_knock(other)
	_knock(welcome)
	Net.hear_hello(other, _bytes({"say": "loaded", "protocol": Net.PROTOCOL, "level": "good_a",
		"hash": mine.content_hash, "ground": "1234567"}))
	_check("a_peer_whose_ground_differs_is_not_let_in_and_is_told_why",
		not Net.admits(other) and Net.said_to.get(other) == "refused" and (Net.get("_sending_away") as Dictionary).has(other),
		"said %s" % [Net.said_to])
	Net.hear_hello(welcome, _bytes({"say": "loaded", "protocol": Net.PROTOCOL, "level": "good_a",
		"hash": mine.content_hash, "ground": ""}))
	_check("and_one_that_loaded_this_level_on_this_ground_is_let_in_and_told", Net.admits(welcome)
		and Net.said_to.get(welcome) == "admitted", "admitted %s, said %s" % [Net.admitted, Net.said_to])
	Net.said_to.erase(welcome)
	Net.hear_hello(welcome, _bytes({"say": "loaded", "protocol": Net.PROTOCOL, "level": "good_a",
		"hash": mine.content_hash, "ground": ""}))
	_check("and_a_loaded_said_again_is_answered_again", Net.said_to.get(welcome) == "admitted", "said %s" % [Net.said_to])
	Sim.stop()
	Net.leave("suite")
	_check("and_leaving_forgets_who_was_let_in", Net.admitted.is_empty() and Net.held_back == 0 and Net.said_to.is_empty(),
		"")
	_sections += 1


## ---- 5: the host changes the level -----------------------------------------------------------------------------------

## A LEVEL CHANGE IS THE JOIN HANDSHAKE, RUN AGAIN (team-lead, 2026-09-15), and that is the whole of the design: there is
## no second protocol. The host un-admits every peer and puts it back in `_telling`, so the same four messages happen for
## the same reasons -- `level`, `loaded`, `admitted`, and `refused` in `why_not_the_level`'s own words for a peer that
## cannot fly the new one. `held_back` holds a peer's packets while it rebuilds, exactly as it holds a joiner's while it
## builds for the first time; the only new thing is that admission is WITHDRAWN rather than never granted.
##
## WHAT THIS SECTION FAILED ON BEFORE THE CHANGE (2026-09-15), which is what it can fail on again:
##   a client told a new level mid-session kept the old one -- `_told_the_level` returned at once unless
##   `_stage == "hello"`, so `Net.level` stayed 'good_a' and nothing was emitted;
##   a client told a level it has not got mid-session did nothing at all, and would have flown on in a world its host had
##   left;
##   the host had no `change_level` -- `choose_level` refuses outright while a session is up.
func _the_host_changes_the_level_and_the_handshake_runs_again() -> void:
	# ---- the client's half, on a real socket, told by a bare host ----
	Net.leave("suite")
	await _frames(10)
	_heard.clear()
	Net.choose_level("good_a")
	var host := ENetMultiplayerPeer.new()
	var err: int = host.create_server(PORT, 4)
	Net.join("127.0.0.1", PORT)
	await _pump(host, _asking)
	var hash_a: String = ChartDrawer.chart("good_a").content_hash
	Net.hear_hello(1, _bytes({"say": "level", "protocol": Net.PROTOCOL, "level": "good_a", "hash": hash_a,
		"name": "Good A"}))
	Net.hear_hello(1, _bytes({"say": "admitted"}))
	var changing: Array = []
	var readies: Array[int] = [0]
	if Net.has_signal("level_changing"):
		Net.connect("level_changing", func(id: String) -> void: changing.append(id))
	var counting_ready := func() -> void: readies[0] += 1
	Net.session_ready.connect(counting_ready)
	_check("a_client_is_in_a_session_on_the_hosts_level", err == OK and Net.is_in_session and Net.level == "good_a",
		"host %s, in session %s, level %s" % [error_string(err), Net.is_in_session, Net.level])
	# THE HOST CHANGES IT: the same `level` hello, said to a peer that is already in.
	var hash_b2: String = ChartDrawer.chart("good_b").content_hash
	Net.hear_hello(1, _bytes({"say": "level", "protocol": Net.PROTOCOL, "level": "good_b", "hash": hash_b2,
		"name": "Good B"}))
	_check("a_client_told_a_new_level_mid_session_takes_it", Net.level == "good_b" and Net.is_in_session,
		"level %s, in session %s" % [Net.level, Net.is_in_session])
	_check("and_says_it_is_changing_rather_than_joining_afresh", changing == ["good_b"] and readies[0] == 0,
		"changing %s, %d session_ready" % [changing, readies[0]])
	# AND SAYS SO AGAIN UNTIL THE HOST ADMITS IT, once its new level is built: the second half of the handshake,
	# unchanged.
	Net.level_loaded("")
	_check("and_tells_the_host_when_the_new_level_is_built", int(Net.get("_loaded_next")) >= 0,
		"next %d" % int(Net.get("_loaded_next")))
	Net.session_ready.disconnect(counting_ready)
	# ---- a client that cannot fly the new level ----
	_heard.clear()
	Net.hear_hello(1, _bytes({"say": "level", "protocol": Net.PROTOCOL, "level": "nowhere", "hash": hash_b2,
		"name": "Nowhere"}))
	var last: String = _heard.back() if not _heard.is_empty() else ""
	_check("a_client_that_cannot_fly_the_new_level_is_refused_in_words_and_not_left_in_a_dead_session",
		last == "The host is flying Nowhere, a level this game does not have." and not Net.is_in_session
			and Net.transport == "none" and Net.parting_words == last,
		"heard '%s', in session %s, transport %s, parting '%s'" % [last, Net.is_in_session, Net.transport,
			Net.parting_words])
	Net.parting_words = ""
	Net.leave("suite")
	await _pump(host, _never, 20)
	host.close()
	await _frames(10)

	# ---- the host's half ----
	_check("net_can_change_the_level_with_a_session_up", Net.has_method("change_level"),
		"change_level %s" % ["is there" if Net.has_method("change_level") else "is not"])
	if not Net.has_method("change_level"):
		_sections += 1
		return
	Net.choose_level("good_a")
	Net.host(PORT)
	Sim.start()
	Net.level_loaded("")
	var aboard: int = 464646
	var mine: LevelChart = ChartDrawer.chart("good_a")
	_knock(aboard)
	Net.hear_hello(aboard, _bytes({"say": "loaded", "protocol": Net.PROTOCOL, "level": "good_a",
		"hash": mine.content_hash, "ground": ""}))
	_check("a_peer_that_loaded_the_level_is_in", Net.admits(aboard), "admitted %s" % [Net.admitted])
	var held_before: int = Net.held_back
	var why: String = String(Net.call("change_level", "good_b"))
	_check("the_host_may_change_the_level_with_a_session_up", why == "" and Net.level == "good_b",
		"'%s', level %s" % [why, Net.level])
	# THE PEER IS UN-ADMITTED AND BEING TOLD AGAIN, and its packets are held while it rebuilds -- the same gate a joiner
	# meets, withdrawn rather than never granted.
	Sim.call("_on_packet", aboard, PackedByteArray([1, 2, 3, 4]), 30)
	_check("and_every_peer_is_un_admitted_and_told_the_new_level_again",
		not Net.admits(aboard) and (Net.get("_telling") as Dictionary).has(aboard) and Net.held_back > held_before,
		"admits %s, telling %s, held %d -> %d" % [Net.admits(aboard), (Net.get("_telling") as Dictionary).keys(),
			held_before, Net.held_back])
	# A PEER THAT SAYS IT IS LOADED BEFORE THE HOST HAS BUILT THE NEW LEVEL IS NOT ANSWERED AT ALL -- not admitted, and
	# not sent away either. The host's own ground hash is still the OLD level's until it has rebuilt, so answering would
	# refuse a peer that had done nothing wrong. It says "loaded" again every 200 ms, which is what that is for.
	Net.said_to.erase(aboard)
	var theirs: LevelChart = ChartDrawer.chart("good_b")
	Net.hear_hello(aboard, _bytes({"say": "loaded", "protocol": Net.PROTOCOL, "level": "good_b",
		"hash": theirs.content_hash, "ground": ""}))
	_check("and_a_peer_loaded_before_the_host_has_built_is_neither_let_in_nor_sent_away",
		not Net.admits(aboard) and not Net.said_to.has(aboard),
		"admits %s, said %s" % [Net.admits(aboard), Net.said_to.get(aboard, "nothing")])
	# THE HOST BUILDS, and the same "loaded" is answered.
	Net.level_loaded("")
	Net.hear_hello(aboard, _bytes({"say": "loaded", "protocol": Net.PROTOCOL, "level": "good_b",
		"hash": theirs.content_hash, "ground": ""}))
	_check("and_once_the_host_has_built_it_the_peer_is_let_back_in", Net.admits(aboard)
		and Net.said_to.get(aboard) == "admitted", "admits %s, said %s" % [Net.admits(aboard), Net.said_to])
	# AND ONLY TO A LEVEL THERE IS, AND ONLY BY THE HOST.
	var nowhere: String = String(Net.call("change_level", "nowhere"))
	_check("a_level_there_is_not_is_refused_in_words", nowhere.contains("nowhere") and Net.level == "good_b",
		"'%s', level %s" % [nowhere, Net.level])
	Sim.stop()
	Net.leave("suite")
	_check("and_a_machine_that_is_not_hosting_may_not", String(Net.call("change_level", "good_a")) != "",
		"'%s'" % Net.call("change_level", "good_a"))
	_sections += 1


## ---- the machinery -------------------------------------------------------------------------------------------

## THE CONDITIONS `_pump` WAITS ON, as functions. An inline lambda followed by another argument on its line is a parse
## error, and a parse error hangs a suite to its deadline (2026-09-15, this file's first run).
func _never() -> bool:
	return false


func _asking() -> bool:
	return _heard.has("Connected. Asking the host which level...")


func _given_up_on_the_hello() -> bool:
	return Net.transport == "none" and not _heard.is_empty() \
		and String(_heard.back()).begins_with("Connected to 127.0.0.1:%d, but the host said nothing" % PORT)


## A PEER AT THE HOST'S DOOR SAYING HI with this build, as `peer_connected` and a real joiner's first word would: the
## peers here are numbers, not sockets, so the door is opened for them by hand.
func _knock(peer: int) -> void:
	(Net.get("_greeting") as Dictionary)[peer] = Time.get_ticks_msec() + 60000
	var me: Dictionary = Net.identity()
	Net.hear_hello(peer, _bytes({"say": "hi", "protocol": me["protocol"], "commit": me["commit"], "line": me["line"]}))


func _bytes(said: Dictionary) -> PackedByteArray:
	return JSON.stringify(said).to_utf8_buffer()


## Poll the bare host every frame until something is true, or give up. A bare host is not polled by anything else.
func _pump(host: ENetMultiplayerPeer, until: Callable, frames: int = PATIENCE) -> bool:
	for i in range(frames):
		host.poll()
		if until.call():
			return true
		await get_tree().physics_frame
	return until.call()


## THE SAME, AGAINST THE CLOCK A DEADLINE IS KEPT ON. `--fixed-fps 120` runs physics frames faster than real time, so
## 480 of them passed before a one-second deadline had (2026-09-15, this file's first gate).
func _pump_for_msec(host: ENetMultiplayerPeer, until: Callable, msec: int) -> bool:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < msec:
		host.poll()
		if until.call():
			return true
		await get_tree().physics_frame
	return until.call()


func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().physics_frame


func _finish() -> void:
	Sim.stop()
	Net.leave("suite over")
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
