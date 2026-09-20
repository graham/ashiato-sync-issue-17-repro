extends Node
## WHAT A STEAM JOIN CODE CAN STAND ON, asked of the GodotSteam binary and of Steam itself rather than remembered.
##
##   Godot --headless --path cockpit res://tests/steam_probe.tscn                  the code, and the binary's surface
##   Godot --headless --path cockpit res://tests/steam_probe.tscn -- --init        and initialise Steam as App ID 480
##   Godot --headless --path cockpit res://tests/steam_probe.tscn -- --lobby       and make an INVISIBLE lobby, tag it
##                                                                                 with a code, and find it by that alone
##
## A PROBE AND NOT A SUITE, because what it needs is a property of the desk: whether a Steam client is running is not
## something a change to the code can make true. Where Steam is missing it says SKIP out loud and goes on. cockpit has
## carried GodotSteam since 2026-09-14, built in both precisions by tools/build_godotsteam.ps1 (see agents.md, "GodotSteam
## is built here, in both precisions"); the measurements below are the ones that made that build necessary.
##
## STEAM IS REACHED THROUGH `Engine.get_singleton`, never by the name `Steam`. The identifier is a class the extension
## registers, so on an editor where the library did not load a script that names it does not parse -- and a parse error
## HANGS a headless run rather than failing it. The double-precision editor is that editor: see below.
##
## MEASURED 2026-09-14, on GodotSteam 4.21 as committed in racer/ and topdowntest/ (identical DLLs, SHA-256 f45768d1 for
## the win64 debug library), copied into a scratch project and then into this one, and removed again:
##
## - The STOCK editor loads it. 736 methods on `Steam`; `SteamMultiplayerPeer` extends MultiplayerPeerExtension with
##   `host_with_lobby(lobby_id)`, `connect_to_lobby(lobby_id)`, `create_host(virtual_port)`,
##   `create_client(steam_id, virtual_port)`, `get_peer_id_for_steam_id`, `get_steam_id_for_peer_id`, `set_server_relay`,
##   `set_no_delay`, `set_no_nagle`. There is NO `getLobbyByIndex`: the list arrives whole in `lobby_match_list(lobbies)`.
## - The DOUBLE editor does not. Untagged, `--import` and a plain run both die in CrashHandlerException with
##   libgodotsteam in the backtrace, and `tests/lint.tscn` in cockpit exits 0xC0000374 (heap corruption) before printing
##   a line. Tagged `windows.debug.single.x86_64`, the double editor skips it -- and prints three `ERROR:` lines on every
##   run ("No GDExtension library found for current OS and architecture"), so `run_all.ps1 -Only docs` reported
##   `ERRORS ... 3 engine error(s)` and failed. `lint` passed only because it is the one suite exempt from the error gate.
## - `steamInitEx(480, true)` answered `{status: 0}` with the Steam client running.
## - An INVISIBLE lobby (type 3) was created in 187 ms. With `game` and `code` set as lobby data, a request filtered on
##   both, worldwide, found exactly that lobby in 186 ms; the same code in lower case found it too (Steam's string filter
##   ignores case); a code nobody held found nothing in 250 ms; and after `leaveLobby` the code found nothing in 228 ms.
## - Steamworks documents FRIENDS_ONLY (1) as "does not show up in the lobby list" and PRIVATE (0) as invite-only, so
##   neither can be found by a code. racer hosts FRIENDS_ONLY, which is why this cannot simply be racer's lobby.
##
## Read RESULT=, not the exit code.

const APP_ID: int = 480
## Not the game's tag: a probe's lobby must never be found by somebody typing a real code.
const TAG: String = "cockpit_steam_probe"
const PATIENCE_SECONDS: float = 20.0

var _fails: PackedStringArray = []
var _steam: Object = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[steam_probe] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _init() -> void:
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	print("[steam_probe] engine %s double=%s" % [Engine.get_version_info().string, OS.has_feature("double")])
	_the_code()
	if not ClassDB.class_exists(&"Steam"):
		print("[steam_probe] SKIP the binary and Steam -- no GodotSteam extension is loaded in this project")
		_finish()
		return
	_steam = Engine.get_singleton("Steam")
	_the_binary()
	if "--init" in args or "--lobby" in args or "--real" in args or "--host" in args or "--join" in args or "--strangers" in args or "--overlap" in args or "--browse" in args:
		await _initialise()
	if "--lobby" in args and _fails.is_empty():
		await _a_lobby_found_by_its_code()
	if "--real" in args:
		await _the_lobby_net_really_makes()
	if "--host" in args:
		await _net_hosts_and_we_look_for_it()
	if "--join" in args:
		await _net_joins_by_code()
	if "--strangers" in args:
		await _somebody_elses_lobby()
	if "--browse" in args:
		await _every_cockpit_lobby()
	if "--overlap" in args:
		await _two_searches_at_once()
	_finish()


## ---- the code ----------------------------------------------------------------------------------

## THE CODE IS `JoinCode`'s, and tests/join_code.gd is what holds it to its rules. This only counts repeats over a
## bigger draw than a suite should spend time on.
func _the_code() -> void:
	var seen: Dictionary = {}
	var repeats: int = 0
	for i in range(20000):
		var code: String = JoinCode.fresh()
		if seen.has(code):
			repeats += 1
		seen[code] = true
	# n^2 / 2N for twenty thousand draws from 32^6 is 0.19.
	print("[steam_probe] 20000 fresh codes, %d repeats, 0.19 expected" % repeats)


## ---- what the binary offers -------------------------------------------------------------------

const WANTED_METHODS: Array[String] = [
	"steamInitEx", "run_callbacks", "getSteamID", "createLobby", "joinLobby", "leaveLobby", "setLobbyData",
	"getLobbyData", "getAllLobbyData", "setLobbyJoinable", "setLobbyType", "getNumLobbyMembers",
	"getLobbyMemberLimit", "getLobbyOwner", "requestLobbyList", "addRequestLobbyListStringFilter",
	"addRequestLobbyListDistanceFilter", "addRequestLobbyListResultCountFilter",
	"addRequestLobbyListFilterSlotsAvailable", "getLobbyByIndex", "sendMessageToUser", "receiveMessagesOnChannel",
]
const WANTED_SIGNALS: Array[String] = [
	"lobby_created", "lobby_joined", "lobby_match_list", "lobby_data_update", "lobby_chat_update", "join_requested",
]


func _the_binary() -> void:
	var all: Dictionary = {}
	for m in ClassDB.class_get_method_list(&"Steam", true):
		all[String(m["name"])] = m
	print("[steam_probe] Steam has %d methods" % all.size())
	for name in WANTED_METHODS:
		if not all.has(name):
			print("[steam_probe] method %s MISSING" % name)
			continue
		print("[steam_probe] method %s(%s) -> %s" % [name, _arguments_of(all[name]["args"]),
			type_string(int(all[name]["return"]["type"]))])
	for name in WANTED_SIGNALS:
		var s: Dictionary = ClassDB.class_get_signal(&"Steam", name)
		print("[steam_probe] signal %s(%s)" % [name, "MISSING" if s.is_empty() else _arguments_of(s["args"])])
	for c in ClassDB.class_get_integer_constant_list(&"Steam", true):
		if c.begins_with("LOBBY_TYPE") or c.begins_with("LOBBY_DISTANCE") or c.begins_with("LOBBY_COMPARISON") \
				or c.begins_with("CHAT_ROOM_ENTER") or c == "MAX_LOBBY_KEY_LENGTH" or c == "CHAT_METADATA_MAX":
			print("[steam_probe] const %s = %d" % [c, ClassDB.class_get_integer_constant(&"Steam", c)])
	if ClassDB.class_exists(&"SteamMultiplayerPeer"):
		print("[steam_probe] SteamMultiplayerPeer extends %s" % ClassDB.get_parent_class(&"SteamMultiplayerPeer"))
		for m in ClassDB.class_get_method_list(&"SteamMultiplayerPeer", true):
			print("[steam_probe] peer %s(%s)" % [m["name"], _arguments_of(m["args"])])


static func _arguments_of(args: Array) -> String:
	var said: PackedStringArray = []
	for a in args:
		said.append("%s: %s" % [a["name"], type_string(int(a["type"]))])
	return ", ".join(said)


## ---- Steam itself ------------------------------------------------------------------------------

func _initialise() -> void:
	var result: Dictionary = _steam.call("steamInitEx", APP_ID, true)
	var up: bool = int(result.get("status", 1)) == 0
	if not up:
		print("[steam_probe] SKIP Steam -- steamInitEx said %s; is the Steam client running?" % result)
		return
	print("[steam_probe] steamInitEx(%d) answered %s" % [APP_ID, result])
	await get_tree().process_frame


## Pump Steam's callbacks until `done` is true, or give up. A Callable rather than a flag: a GDScript lambda captures by
## value, so a bool set inside a signal handler is set on a copy.
func _pump_until(done: Callable, seconds: float) -> bool:
	var since: int = Time.get_ticks_msec()
	while not done.call():
		if Time.get_ticks_msec() - since > int(seconds * 1000.0):
			return false
		_steam.call("run_callbacks")
		await get_tree().process_frame
	return true


func _constant(named: String) -> int:
	return ClassDB.class_get_integer_constant(&"Steam", named)


func _lobbies_holding(code: String) -> Array:
	var got: Array = []
	var answered: Array = [false]
	var on_list := func(lobbies: Array) -> void:
		got.assign(lobbies)
		answered[0] = true
	_steam.connect("lobby_match_list", on_list)
	_steam.call("addRequestLobbyListDistanceFilter", _constant("LOBBY_DISTANCE_FILTER_WORLDWIDE"))
	_steam.call("addRequestLobbyListStringFilter", "game", TAG, _constant("LOBBY_COMPARISON_EQUAL"))
	_steam.call("addRequestLobbyListStringFilter", "code", code, _constant("LOBBY_COMPARISON_EQUAL"))
	_steam.call("addRequestLobbyListResultCountFilter", 2)
	var since: int = Time.get_ticks_msec()
	_steam.call("requestLobbyList")
	var in_time: bool = await _pump_until(func() -> bool: return answered[0], PATIENCE_SECONDS)
	_steam.disconnect("lobby_match_list", on_list)
	print("[steam_probe] lobbies holding '%s': %d, answered=%s in %d ms" % [code, got.size(), in_time,
		Time.get_ticks_msec() - since])
	return got


func _a_lobby_found_by_its_code() -> void:
	var made: Array = [0, -1]
	var on_created := func(result: int, lobby: int) -> void:
		made[0] = lobby
		made[1] = result
	_steam.connect("lobby_created", on_created)
	var since: int = Time.get_ticks_msec()
	_steam.call("createLobby", _constant("LOBBY_TYPE_INVISIBLE"), 4)
	var created: bool = await _pump_until(func() -> bool: return made[1] != -1, PATIENCE_SECONDS)
	_steam.disconnect("lobby_created", on_created)
	_check("an_invisible_lobby_is_created", created and made[1] == 1 and made[0] != 0,
		"result=%d in %d ms" % [made[1], Time.get_ticks_msec() - since])
	if not created or int(made[0]) == 0:
		return
	var lobby: int = int(made[0])
	var code: String = JoinCode.fresh()
	_steam.call("setLobbyData", lobby, "game", TAG)
	_steam.call("setLobbyData", lobby, "code", code)
	await _pump_until(func() -> bool: return false, 2.0)
	_check("the_lobby_is_found_by_its_code_alone", (await _lobbies_holding(code)).has(lobby), code)
	var lower: bool = (await _lobbies_holding(code.to_lower())).has(lobby)
	print("[steam_probe] the filter is case-%s" % ("insensitive" if lower else "sensitive"))
	var nobody: String = "222223" if code != "222223" else "222224"
	_check("a_code_nobody_holds_finds_nothing", not (await _lobbies_holding(nobody)).has(lobby), nobody)
	_steam.call("leaveLobby", lobby)
	await _pump_until(func() -> bool: return false, 1.0)
	_check("a_lobby_left_is_found_no_more", not (await _lobbies_holding(code)).has(lobby), code)


## ---- the lobby `Net` really makes ---------------------------------------------------------------

## THE JOIN BY CODE SAID "No game has the code ..." EVERY TIME (the user, 2026-09-15) while the section above was
## green against the same backend. So the probe was not taking the real path, and this is the difference measured one
## variable at a time: `_a_lobby_found_by_its_code` makes an INVISIBLE lobby with two keys and nothing else on it;
## `Net._on_opened` makes a PUBLIC one, writes SIX keys, and then hands the lobby to
## `SteamMultiplayerPeer.host_with_lobby`. Each of those three is a candidate, and each search below is one of the
## three `Net` actually makes.
##
## Read the counts, not a PASS: this is a probe. Every line says what was asked and what Steam answered.
const REAL_KEYS: Array[String] = ["game", "code", "build", "host", "level", "level_hash"]


func _the_lobby_net_really_makes() -> void:
	for kind in ["LOBBY_TYPE_PUBLIC", "LOBBY_TYPE_INVISIBLE"]:
		for with_peer in [false, true]:
			await _one_real_lobby(kind, with_peer)


func _one_real_lobby(kind: String, with_peer: bool) -> void:
	var made: Array = [0, -1]
	var on_created := func(result: int, lobby: int) -> void:
		made[0] = lobby
		made[1] = result
	_steam.connect("lobby_created", on_created)
	_steam.call("createLobby", _constant(kind), 8)
	var created: bool = await _pump_until(func() -> bool: return made[1] != -1, PATIENCE_SECONDS)
	_steam.disconnect("lobby_created", on_created)
	if not created or int(made[0]) == 0:
		_check("a_%s_lobby_is_created" % kind, false, "result=%d" % int(made[1]))
		return
	var lobby: int = int(made[0])
	var code: String = JoinCode.fresh()
	# EXACTLY WHAT `Net._on_opened` WRITES, in the order it writes it, with the probe's tag in place of the game's.
	var wrote: PackedStringArray = []
	var values: Dictionary = {"game": TAG, "code": code, "build": Net.build(),
		"compatibility": Net.compatibility(), "host": str(_steam.call("getSteamID")),
		"level": "island", "level_hash": "0".repeat(64)}
	for key in REAL_KEYS:
		wrote.append("%s=%s" % [key, _steam.call("setLobbyData", lobby, key, String(values[key]))])
	print("[steam_probe] %s lobby %d, code %s, setLobbyData %s" % [kind, lobby, code, " ".join(wrote)])
	if with_peer:
		# AND THE PEER `Net` PUTS ON IT ONE LINE LATER. If this is what hides the lobby, the game's own host is what
		# takes its lobby out of the list a joiner searches.
		var peer: MultiplayerPeer = null
		if ClassDB.class_exists(&"SteamMultiplayerPeer"):
			peer = ClassDB.instantiate(&"SteamMultiplayerPeer") as MultiplayerPeer
			peer.call("set_no_nagle", true)
			print("[steam_probe] host_with_lobby said %d" % int(peer.call("host_with_lobby", lobby)))
	await _pump_until(func() -> bool: return false, 2.0)
	print("[steam_probe] the lobby reads back %s" % _steam.call("getAllLobbyData", lobby))
	var what: String = "%s peer=%s" % [kind, with_peer]
	# THE THREE SEARCHES `Net` MAKES, and the two that would tell a filter from a lobby.
	_check("join_code finds it (%s)" % what,
		(await _search({"game": TAG, "code": code}, 2, "LOBBY_DISTANCE_FILTER_WORLDWIDE")).has(lobby), code)
	_check("look_for_games finds it (%s)" % what,
		(await _search({"game": TAG}, Net.MOST_LISTED, "LOBBY_DISTANCE_FILTER_WORLDWIDE")).has(lobby), TAG)
	_check("the code alone finds it (%s)" % what,
		(await _search({"code": code}, 2, "LOBBY_DISTANCE_FILTER_WORLDWIDE")).has(lobby), code)
	_check("no filter at all finds it (%s)" % what,
		(await _search({}, 50, "LOBBY_DISTANCE_FILTER_WORLDWIDE")).has(lobby), "50 worldwide")
	_steam.call("leaveLobby", lobby)
	await _pump_until(func() -> bool: return false, 1.0)


## ONE `requestLobbyList`, filtered as asked. Steam clears its filters on every request, so each of these stands alone.
func _search(filters: Dictionary, most: int, distance: String) -> Array:
	var got: Array = []
	var answered: Array = [false]
	var on_list := func(lobbies: Array) -> void:
		got.assign(lobbies)
		answered[0] = true
	_steam.connect("lobby_match_list", on_list)
	if distance != "":
		_steam.call("addRequestLobbyListDistanceFilter", _constant(distance))
	for key in filters:
		_steam.call("addRequestLobbyListStringFilter", String(key), String(filters[key]),
			_constant("LOBBY_COMPARISON_EQUAL"))
	_steam.call("addRequestLobbyListResultCountFilter", most)
	var since: int = Time.get_ticks_msec()
	_steam.call("requestLobbyList")
	var in_time: bool = await _pump_until(func() -> bool: return answered[0], PATIENCE_SECONDS)
	_steam.disconnect("lobby_match_list", on_list)
	print("[steam_probe] search %s most=%d -> %d lobbies, answered=%s in %d ms" % [filters, most, got.size(), in_time,
		Time.get_ticks_msec() - since])
	return got


## ---- `Net` hosts, and a joiner's search looks for what it made ----------------------------------

## THE LAST THING BETWEEN THE PROBE AND THE REAL PATH. `--real` above builds a lobby that LOOKS like `Net`'s; this one
## calls `Net.host_steam()` and lets the game's own code draw the code, check it, make the lobby, write the six keys and
## put a host peer on it. Then it asks `Net`'s own directory the search `Net.join_code` asks -- the same filters, the
## same tag, the same count -- so what a joiner on another machine sends to Steam is sent here, about a lobby the game
## itself made. If this finds nothing, the host is at fault; if it finds it, everything but the second account is ruled out.
func _net_hosts_and_we_look_for_it() -> void:
	Net.host_steam()
	var up: bool = await _pump_until(func() -> bool: return Net.is_in_session or Net.transport == "none",
		PATIENCE_SECONDS)
	_check("net_hosts_over_steam", up and Net.is_in_session, "transport=%s lobby=%d code=%s build=%s"
		% [Net.transport, Net.lobby, Net.session_code, Net.build()])
	if not Net.is_in_session:
		return
	print("[steam_probe] Net's lobby reads back %s" % _steam.call("getAllLobbyData", Net.lobby))
	print("[steam_probe] getLobbyData(game)='%s' (code)='%s'" % [Net.lobbies.read(Net.lobby, "game"),
		Net.lobbies.read(Net.lobby, "code")])
	# THE JOINER'S SEARCH, asked of `Net`'s own directory so nothing about it is a second copy -- and asked again every
	# second for half a minute, because "not yet" and "never" are different bugs and only a clock tells them apart.
	var since: int = Time.get_ticks_msec()
	var first_found: int = -1
	var code_alone: int = -1
	var tag_alone: int = -1
	for attempt in range(30):
		var by_both: bool = (await _ask_nets_directory({"game": Net.GAME_TAG, "code": Net.session_code}, 2)).has(Net.lobby)
		var by_code: bool = (await _ask_nets_directory({"code": Net.session_code}, 2)).has(Net.lobby)
		var by_tag: bool = (await _ask_nets_directory({"game": Net.GAME_TAG}, Net.MOST_LISTED)).has(Net.lobby)
		var at: int = Time.get_ticks_msec() - since
		print("[steam_probe] %d ms: both=%s code=%s game=%s" % [at, by_both, by_code, by_tag])
		first_found = at if first_found < 0 and by_both else first_found
		code_alone = at if code_alone < 0 and by_code else code_alone
		tag_alone = at if tag_alone < 0 and by_tag else tag_alone
		if first_found >= 0:
			break
		await _pump_until(func() -> bool: return false, 1.0)
	_check("a_joiner_search_finds_nets_lobby", first_found >= 0,
		"game+code first matched at %d ms; code alone at %d; game alone at %d" % [first_found, code_alone, tag_alone])
	Net.leave("probe done")


## ONE SEARCH THROUGH `Net.lobbies`, the real `SteamLobbyDirectory`. `Net._on_found` hears it too and does nothing,
## because no stage is waiting.
func _ask_nets_directory(filters: Dictionary, most: int) -> Array:
	var got: Array = []
	var answered: Array = [false]
	var request: int = 900000 + Time.get_ticks_msec()
	var on_found := func(answered_request: int, lobbies: Array) -> void:
		if answered_request != request:
			return
		got.assign(lobbies)
		answered[0] = true
	Net.lobbies.found.connect(on_found)
	var since: int = Time.get_ticks_msec()
	Net.lobbies.find(request, filters, most)
	var in_time: bool = await _pump_until(func() -> bool: return answered[0], PATIENCE_SECONDS)
	Net.lobbies.found.disconnect(on_found)
	print("[steam_probe] Net.lobbies.find(%s, %d) -> %d lobbies, answered=%s in %d ms" % [filters, most, got.size(),
		in_time, Time.get_ticks_msec() - since])
	return got


## ---- `Net.join_code`, at a lobby that carries what a host writes --------------------------------

## THE JOINER'S HALF, which no test had ever driven against the real backend. A lobby is made here with the six keys
## `Net._on_opened` writes and the values this machine would write, so every check in `Net._what_is_wrong_with` can pass;
## then `Net.join_code` is handed the code and we listen to what it says. A search that comes back empty says
## "No game has the code ...", which is the sentence the user is getting.
##
## It cannot reach a session -- `connect_to_lobby` to our own lobby is not a second peer -- so the probe stops reading at
## the stage after the search, which is the one in question.
func _net_joins_by_code() -> void:
	var made: Array = [0, -1]
	var on_created := func(result: int, lobby: int) -> void:
		made[0] = lobby
		made[1] = result
	_steam.connect("lobby_created", on_created)
	_steam.call("createLobby", _constant("LOBBY_TYPE_PUBLIC"), Net.MAX_PLAYERS)
	var created: bool = await _pump_until(func() -> bool: return made[1] != -1, PATIENCE_SECONDS)
	_steam.disconnect("lobby_created", on_created)
	if not created or int(made[0]) == 0:
		_check("a_lobby_for_the_joiner_to_find", false, "result=%d" % int(made[1]))
		return
	var lobby: int = int(made[0])
	var code: String = JoinCode.fresh()
	var flying: LevelChart = ChartDrawer.chart(Net.level)
	for pair in [["game", Net.GAME_TAG], ["code", code], ["build", Net.build()],
			["compatibility", Net.compatibility()],
			["host", str(_steam.call("getSteamID"))], ["level", Net.level],
			["level_hash", flying.content_hash if flying != null else ""]]:
		_steam.call("setLobbyData", lobby, String(pair[0]), String(pair[1]))
	# PAST THE PROPAGATION. Measured in `--host`: a lobby's data reached the matchmaking servers 1.7 s after it was
	# written and not at 0.4 s, so a search sooner than that answers nothing about whether the search itself works.
	await _pump_until(func() -> bool: return false, 4.0)
	var said: PackedStringArray = []
	var listen := func(text: String) -> void: said.append(text)
	Net.session_message.connect(listen)
	Net.join_code(JoinCode.spell(code))
	# UNTIL THE SEARCH IS ANSWERED, whatever it is answered with: either `Net` refused, or it got past the search and is
	# knocking on a lobby it cannot really enter twice.
	await _pump_until(func() -> bool: return Net.transport == "none" or said.size() > 1, PATIENCE_SECONDS)
	Net.session_message.disconnect(listen)
	var refused: bool = false
	for text in said:
		refused = refused or String(text).begins_with("No game has the code")
	_check("net_join_code_finds_a_real_host_lobby", not refused, "%s; said %s" % [code, said])
	_steam.call("leaveLobby", lobby)
	await _pump_until(func() -> bool: return false, 1.0)


## ---- somebody else's lobby, which is the only kind a joiner ever searches for -------------------

## THE ONE QUESTION ONE STEAM ACCOUNT CAN ASK ABOUT TWO. Every check above searched for a lobby this machine had just
## made and was still a member of, and a member is told things about a lobby that a stranger is not. App ID 480 is
## shared by every Steamworks developer, so an unfiltered search returns fifty lobbies this machine is NOT in -- which
## is exactly the shape of the lobby a joiner's search finds -- and `Net._what_is_wrong_with` asks four things of one:
## `read` (getLobbyData), `members` (getNumLobbyMembers), `limit` (getLobbyMemberLimit) and `owner` (getLobbyOwner).
##
## Steamworks says of GetLobbyOwner: "You must be a member of the lobby to access this." If that is true of the binary
## as well as the documentation, then `Net` refuses every lobby a search ever finds.
func _somebody_elses_lobby() -> void:
	var strangers: Array = await _search({}, 50, "LOBBY_DISTANCE_FILTER_WORLDWIDE")
	var mine: int = int(_steam.call("getSteamID"))
	var owners: int = 0
	var limits: int = 0
	var counted: int = 0
	var carried_data: int = 0
	var looked: int = 0
	for other in strangers:
		var lobby: int = int(other)
		if int(_steam.call("getLobbyOwner", lobby)) == mine:
			continue
		looked += 1
		var owner: int = int(_steam.call("getLobbyOwner", lobby))
		var limit: int = int(_steam.call("getLobbyMemberLimit", lobby))
		var members: int = int(_steam.call("getNumLobbyMembers", lobby))
		var data: Dictionary = _steam.call("getAllLobbyData", lobby)
		owners += 1 if owner != 0 else 0
		limits += 1 if limit > 0 else 0
		counted += 1 if members > 0 else 0
		carried_data += 1 if data.size() > 0 else 0
		if looked <= 5:
			print("[steam_probe] stranger %d: owner=%d limit=%d members=%d keys=%d" % [lobby, owner, limit, members,
				data.size()])
	print("[steam_probe] of %d lobbies this machine is not in: %d gave an owner, %d a member limit, %d a member count, %d any data"
		% [looked, owners, limits, counted, carried_data])
	# WHAT STEAM REALLY DOES, asserted as it really is, so this goes RED if the backend ever changes rather than sitting
	# permanently red about a wish. `getLobbyOwner` naming NOBODY is the measurement the fix in `Net` stands on.
	_check("a_strangers_lobby_never_names_its_owner", looked > 0 and owners == 0, "%d of %d named one" % [owners, looked])
	_check("a_strangers_lobby_names_its_member_limit", looked > 0 and limits == looked, "%d of %d" % [limits, looked])
	# Not all of them: a lobby with no metadata at all carries none, and plenty on 480 have none. What matters is that
	# a lobby which HAS data hands it over, which is the next check.
	print("[steam_probe] %d of %d strangers' lobbies carried any data at all" % [carried_data, looked])
	# AND THE ONE `Net` REALLY DEPENDS ON: a search FILTERED on a key must hand back a lobby whose data this machine can
	# read, because `_what_is_wrong_with` reads four keys off a search result before it enters anything. Asked of a
	# stranger's own key and value, which is the only filtered search one account can make about two.
	for other in strangers:
		var data: Dictionary = _steam.call("getAllLobbyData", int(other))
		if data.is_empty():
			continue
		var key: String = String(data[0]["key"])
		var value: String = String(data[0]["value"])
		if value.strip_edges().is_empty():
			continue
		var again: Array = await _search({key: value}, 50, "LOBBY_DISTANCE_FILTER_WORLDWIDE")
		var readable: int = 0
		for found_at in again:
			readable += 1 if String(_steam.call("getLobbyData", int(found_at), key)) == value else 0
		_check("a_filtered_search_hands_back_readable_data", not again.is_empty() and readable == again.size(),
			"%s=%s: %d of %d readable" % [key, value, readable, again.size()])
		break


## ---- two searches at once, which the desk can ask for -------------------------------------------

## STEAMWORKS SAYS "There can only be one active lobby search at a time" (ISteamMatchmaking, RequestLobbyList), and the
## desk can ask for two: "Look for other players" starts a browse on a 20-second deadline, and nothing stops the player
## typing a code into the keypad while it is still out. `LobbyDirectory.found` carries a list of lobbies and NOTHING
## saying which question it answers, so whichever answer arrives first is read as the answer to whichever stage `Net` is
## waiting on. This measures what Steam really does with the second request: how many answers come back, in what order,
## and holding what.
func _two_searches_at_once() -> void:
	var made: Array = [0, -1]
	var on_created := func(result: int, lobby: int) -> void:
		made[0] = lobby
		made[1] = result
	_steam.connect("lobby_created", on_created)
	_steam.call("createLobby", _constant("LOBBY_TYPE_PUBLIC"), Net.MAX_PLAYERS)
	await _pump_until(func() -> bool: return made[1] != -1, PATIENCE_SECONDS)
	_steam.disconnect("lobby_created", on_created)
	if int(made[0]) == 0:
		_check("a_lobby_to_search_for", false, "result=%d" % int(made[1]))
		return
	var lobby: int = int(made[0])
	var code: String = JoinCode.fresh()
	_steam.call("setLobbyData", lobby, "game", TAG)
	_steam.call("setLobbyData", lobby, "code", code)
	await _pump_until(func() -> bool: return false, 4.0)
	# THE BROWSE, then the code search a keystroke later, with nothing waited for in between. The browse is asked for a
	# tag nothing wears, so its answer is EMPTY and the code's answer holds one lobby: whichever `Net` reads first is
	# then obvious from the count alone.
	var answers: Array = []
	var on_list := func(lobbies: Array) -> void: answers.append(lobbies.size())
	_steam.connect("lobby_match_list", on_list)
	_steam.call("addRequestLobbyListDistanceFilter", _constant("LOBBY_DISTANCE_FILTER_WORLDWIDE"))
	_steam.call("addRequestLobbyListStringFilter", "game", "nothing_wears_this_tag", _constant("LOBBY_COMPARISON_EQUAL"))
	_steam.call("addRequestLobbyListResultCountFilter", Net.MOST_LISTED)
	_steam.call("requestLobbyList")
	_steam.call("addRequestLobbyListDistanceFilter", _constant("LOBBY_DISTANCE_FILTER_WORLDWIDE"))
	_steam.call("addRequestLobbyListStringFilter", "game", TAG, _constant("LOBBY_COMPARISON_EQUAL"))
	_steam.call("addRequestLobbyListStringFilter", "code", code, _constant("LOBBY_COMPARISON_EQUAL"))
	_steam.call("addRequestLobbyListResultCountFilter", 2)
	_steam.call("requestLobbyList")
	await _pump_until(func() -> bool: return false, 8.0)
	_steam.disconnect("lobby_match_list", on_list)
	print("[steam_probe] a browse and a code search asked together answered %s (0 is the browse, 1 the code)" % [answers])
	# MEASURED 2026-09-15: ONE answer comes back, and it is the SECOND request's. Steam abandons the first outright
	# rather than answering both or ignoring the second, which is "only one active lobby search at a time" made concrete.
	# So a code typed while a browse is still out is answered correctly -- the code search is the later one -- and it is
	# the browse that is lost, leaving the games list empty with no deadline left to say so. That rules the overlap out
	# as a cause of "No game has the code", which is why this asks it.
	_check("two_searches_at_once_leave_only_the_later_one", answers.size() == 1 and int(answers[0]) == 1,
		"%d answer(s), holding %s; wanted one holding the code search's single lobby" % [answers.size(), answers])
	_steam.call("leaveLobby", lobby)
	await _pump_until(func() -> bool: return false, 1.0)


## ---- every cockpit lobby Steam knows of ---------------------------------------------------------

## THE LOOK ROUND, ASKED WITHOUT THE GAME. `Net.look_for_games` makes this search and draws it on the desk; this prints
## it, which is two things at once. On a two-machine run it is how each end checks whether it can see the other end's
## lobby at all, before anybody blames a code. And after any run that hosted, it is how you check no lobby was left
## open behind a killed process -- a lobby whose last member goes is destroyed by Steam, and this says whether it was.
func _every_cockpit_lobby() -> void:
	var here: Array = await _search({"game": Net.GAME_TAG}, Net.MOST_LISTED, "LOBBY_DISTANCE_FILTER_WORLDWIDE")
	print("[steam_probe] %d lobby(s) wearing %s" % [here.size(), Net.GAME_TAG])
	for other in here:
		var lobby: int = int(other)
		print("[steam_probe]   lobby %d code=%s level=%s build=%s host=%s members=%d of %d" % [lobby,
			JoinCode.spell(JoinCode.read(_steam.call("getLobbyData", lobby, "code"))),
			_steam.call("getLobbyData", lobby, "level"), _steam.call("getLobbyData", lobby, "build"),
			_steam.call("getLobbyData", lobby, "host"), int(_steam.call("getNumLobbyMembers", lobby)),
			int(_steam.call("getLobbyMemberLimit", lobby))])


func _finish() -> void:
	print("[steam_probe] RESULT=%s" % ("PASS" if _fails.is_empty() else "FAIL %s" % [_fails]))
	get_tree().quit(0 if _fails.is_empty() else 1)
