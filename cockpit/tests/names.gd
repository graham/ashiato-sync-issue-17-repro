extends Node
## Identity protocol validation and the actual controls/surfaces that consume it.

var failures: PackedStringArray = []


func check(label: String, ok: bool, detail: String = "") -> void:
	print("[names] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)


func _ready() -> void:
	var long_name: String = " ALICE\u0007" + "X".repeat(300)
	var card: Dictionary = Net.read_hello(JSON.stringify({"say": "card", "name": long_name,
		"colour": 3}).to_utf8_buffer())
	check("a_name_is_printable_trimmed_and_clamped", card.get("name") == "ALICEXXXXXXXXXXX",
		String(card.get("name")))
	check("a_colour_outside_the_palette_is_dropped", Net.read_hello(JSON.stringify({"say": "card",
		"name": "ALICE", "colour": 99}).to_utf8_buffer()).is_empty())
	var roster: Dictionary = Net.read_hello(JSON.stringify({"say": "roster", "n": 7, "cards": [
		{"player": 1, "name": "HOST", "colour": 1}, {"player": 2, "name": "ALICE", "colour": 3}]}).to_utf8_buffer())
	check("an_authoritative_roster_is_read", roster.get("n") == 7 and (roster.get("cards", []) as Array).size() == 2)
	Net.roster.clear()
	for player in range(1, Net.MAX_PLAYERS + 1):
		Net.roster[player] = {"player": player, "name": "N".repeat(Net.NAME_MOST), "colour": player % 8}
	var level_hello: Dictionary = {"say": "level", "protocol": Net.PROTOCOL, "level": "maximum_level",
		"hash": "f".repeat(64), "name": "L".repeat(LevelChart.NAME_MOST), "clouds": true, "n": 1}
	# THE SKY AT ITS LONGEST, AS THE HOST WOULD SAY IT: a clock a hair before midnight, a session a year of frames old, and
	# a rate with every figure the board could ask for -- anchored the host's own way and said by `_the_sky_said`.
	var was: Array = [Net.clock_at, Net.clock_frame, Net.clock_rate]
	Net._anchor_the_clock(1439.999999999999, Net.CLOCK_RATE_MOST / 7.0)
	Net.clock_frame = roundf(365.0 * 86400.0 * 120.0 + 0.123456789)
	level_hello.merge(Net._the_sky_said())
	Net.clock_at = was[0]
	Net.clock_frame = was[1]
	Net.clock_rate = was[2]
	level_hello.merge(Net._roster_said())
	level_hello.merge(Net._music_level_said())
	# A FULL SESSION'S ROSTER DOES NOT FIT A LEVEL HELLO any more (sixty-four players, lane/seats 2026-09-18), so the
	# host leaves it out and says it in pages after admission. The level hello without it must fit; every page must fit
	# and be read; and a joiner takes the roster only when the last page is in, whatever order they arrive in.
	var with_roster: int = JSON.stringify(level_hello).to_utf8_buffer().size()
	level_hello.erase("roster_n")
	level_hello.erase("cards")
	var level_bytes: PackedByteArray = JSON.stringify(level_hello).to_utf8_buffer()
	check("the_level_hello_fits_without_the_roster", level_bytes.size() <= Net.HELLO_MOST_BYTES
		and not Net.read_hello(level_bytes).is_empty(),
		"%d bytes without it, %d with %d cards" % [level_bytes.size(), with_roster, Net.roster.size()])
	Net._roster_version = 5
	var pages: Array = Net.roster_pages()
	var fit: bool = not pages.is_empty()
	var heard: Array = []
	for page in pages:
		var bytes: PackedByteArray = JSON.stringify(page).to_utf8_buffer()
		fit = fit and bytes.size() <= Net.HELLO_MOST_BYTES
		heard.append(Net.read_hello(bytes))
	check("every_page_of_a_full_roster_fits_a_hello_and_is_read", fit and not heard.any(
		func(one: Dictionary) -> bool: return one.is_empty()), "%d pages" % pages.size())
	var everyone: Dictionary = Net.roster.duplicate(true)
	Net.roster = {}
	Net._roster_heard = -1
	Net._roster_parts.clear()
	heard.reverse()
	var early: int = -1
	for i in range(heard.size()):
		if i == heard.size() - 1:
			early = Net.roster.size()
		Net._hear_roster(heard[i], false)
	check("a_joiner_takes_the_roster_only_when_every_page_is_in", early == 0 and Net.roster.size() == Net.MAX_PLAYERS
		and Net.roster.keys().all(func(p: int) -> bool: return everyone.has(p)),
		"%d cards before the last page, %d after, of %d" % [early, Net.roster.size(), Net.MAX_PLAYERS])
	Net.roster = {2: {"player": 2, "name": "ALICE", "colour": 3}}
	check("the_stable_lookup_answers_name_and_colour", Net.name_of(2) == "ALICE"
		and Net.colour_of(2).is_equal_approx(PlayerColours.PALETTE[3]))
	var page := preload("res://ui/menus/roster_page.tscn").instantiate() as RosterPage
	add_child(page)
	await get_tree().process_frame
	var chosen: Array = []
	page.chose.connect(func(name: String, colour: int) -> void: chosen.assign([name, colour]))
	page.field.text = "BEAMTEST"
	page.swatches[3].pressed.emit()
	check("a_real_swatch_button_submits_the_line_edit", chosen == ["BEAMTEST", 3], str(chosen))
	var pilot := preload("res://player/remote_pilot.tscn").instantiate() as RemotePilot
	add_child(pilot)
	await get_tree().process_frame
	pilot.setup(2, "fallback")
	check("a_remote_pilot_uses_the_roster_label_and_colour", pilot.label.text == "ALICE"
		and (pilot.head.material_override as StandardMaterial3D).albedo_color.is_equal_approx(PlayerColours.PALETTE[3]))
	_steam_starts_at_boot_only_for_a_player()
	_a_typed_name_beats_steam_and_the_fallback_does_not()
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


## ---- the player's Steam name (lane/buildtime, 2026-09-19) ---------------------------------------------------------
## "if it's available, we should have players names pulled from steam (not player 1, player 2)". See Net's "THE
## PLAYER'S NAME". Starting Steam at boot is for a player at a window and nobody else: every case a suite, a probe or a
## second local instance is started with says no, in words, and so does this very process.
func _steam_starts_at_boot_only_for_a_player() -> void:
	var player: PackedStringArray = ["C:/games/Cockpit.exe"]
	var none: PackedStringArray = []
	var cases: Array = [
		["a player at a window", player, none, "windows", "", true, ""],
		["headless", player, none, "headless", "", true, "headless"],
		["a suite", player, none, "windows", "3", true, "a suite"],
		["a probe", PackedStringArray(["--path", "cockpit", "res://tests/crew_shot.tscn"]), none, "windows", "", true,
			"a test scene"],
		["--no-steam", player, PackedStringArray(["--no-steam"]), "windows", "", true, "--no-steam"],
		["a second instance by IP", player, PackedStringArray(["--join=a-friend"]), "windows", "", true, "ENet"],
		["a host on the command line", player, PackedStringArray(["--host"]), "windows", "", true, "ENet"],
		["no Steam client", player, none, "windows", "", false, "not running"],
	]
	var wrong: PackedStringArray = []
	for case in cases:
		var said: String = Net.steam_at_boot_refusal(case[1], case[2], case[3], case[4], case[5])
		var ok: bool = said == "" if String(case[6]) == "" else said.contains(String(case[6]))
		if not ok:
			wrong.append("%s said '%s'" % [case[0], said])
	var here: String = Net.steam_at_boot_refusal(OS.get_cmdline_args(), OS.get_cmdline_user_args(),
		DisplayServer.get_name(), OS.get_environment("COCKPIT_TEST_SLOT"), true)
	check("steam_starts_at_boot_only_for_a_player_at_a_window", wrong.is_empty() and here != ""
		and Net.lobbies.me() == 0, "%s; this suite: '%s', Steam id %d" % [", ".join(wrong) if not wrong.is_empty()
			else "%d cases" % cases.size(), here, Net.lobbies.me()])


## A NAME TYPED ON THE ROSTER PAGE WINS OVER STEAM, AND GOES ON WINNING AFTER A RESTART; the fallback and the persona
## itself pressed OK on unchanged are not typed names. Through `user://player.json` itself, put back afterwards.
func _a_typed_name_beats_steam_and_the_fallback_does_not() -> void:
	var path: String = Net.PROFILE.PATH
	var had: bool = FileAccess.file_exists(path)
	var was: String = FileAccess.get_file_as_string(path) if had else ""
	var persona_was: Callable = Net.persona_name
	Net.persona_name = func() -> String: return "STEAMSAM"
	var said: Array = []
	Net.set_profile("MAVERICK", 2)
	said.append(Net.local_card()["name"])
	Net.set("_local_card", Net.PROFILE.load_card())
	Net.set("_profile_edited", bool((Net.get("_local_card") as Dictionary).get("typed", false)))
	said.append(Net.local_card()["name"])
	Net.set_profile("PLAYER 3", 2)
	said.append(Net.local_card()["name"])
	Net.set_profile("STEAMSAM", 2)
	Net.persona_name = func() -> String: return "SAM RENAMED"
	said.append(Net.local_card()["name"])
	# A FILE FROM BEFORE `typed`: a name in it is one somebody pressed OK on, unless it is the fallback.
	var legacy := FileAccess.open(path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"name": "GOOSE", "colour": 1}))
	legacy.close()
	said.append(bool(Net.PROFILE.load_card()["typed"]))
	legacy = FileAccess.open(path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"name": "PLAYER 2", "colour": 1}))
	legacy.close()
	said.append(bool(Net.PROFILE.load_card()["typed"]))
	check("a_typed_name_beats_steam_even_after_a_restart_and_the_fallback_does_not",
		said == ["MAVERICK", "MAVERICK", "STEAMSAM", "SAM RENAMED", true, false], str(said))
	Net.persona_name = persona_was
	if had:
		var back := FileAccess.open(path, FileAccess.WRITE)
		back.store_string(was)
		back.close()
	else:
		DirAccess.remove_absolute(path)
	Net.set("_local_card", Net.PROFILE.load_card())
	Net.set("_profile_edited", bool((Net.get("_local_card") as Dictionary).get("typed", false)))
