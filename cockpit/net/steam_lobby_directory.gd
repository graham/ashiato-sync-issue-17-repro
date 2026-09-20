extends LobbyDirectory
class_name SteamLobbyDirectory
## STEAM'S LOBBIES, asked through GodotSteam.
##
## REACHED THROUGH `Engine.get_singleton("Steam")`, never by the name `Steam`. That name is a class the extension
## registers, and a script that names it does not parse where the library did not load -- which is every build of
## cockpit today, and the double-precision editor always (tests/steam_probe.gd: it crashes in libgodotsteam untagged, and
## skips it with three ERROR lines tagged). A parse error in `Net`'s dependency would take the whole game down with it.
##
## STEAM STARTS THE FIRST TIME IT IS ASKED FOR, not at boot. A suite, a second instance on one machine and a player who
## never presses a Steam button never touch the Steam client, so nothing fights over it and nothing has to remember to
## skip it. racer initialises at boot and needs `LocalPlay` to skip it; this does not.
##
## Every method and number below was read off the binary by tests/steam_probe.gd on 2026-09-14, GodotSteam 4.21:
## `lobby_created(connect, lobby_id)` -- result first; `lobby_joined(lobby, permissions, locked, response)`;
## `lobby_match_list(lobbies)`; `createLobby(lobby_type, max_members)`; `SteamMultiplayerPeer.host_with_lobby(lobby_id)`
## and `connect_to_lobby(lobby_id)`; `join_requested(lobby_id, steam_id)` for an invite accepted or a friend's Join Game.
##
## A PUBLIC LOBBY, because the user asked on 2026-09-14 for a game joinable by code AND by Steam invites and friends'
## profiles. Steamworks: PUBLIC is "returned by search and visible to friends"; INVISIBLE is returned by search but not
## visible to friends, so no Join Game; FRIENDS_ONLY "does not show up in the lobby list", so no code. What PUBLIC costs:
## the lobby shows in any unfiltered lobby search on App ID 480, which every Steamworks developer shares -- nothing in
## this game browses, and every search here is filtered on the game tag and the code, but somebody else's could list it.
## An invite and a profile skip the search, so `Net` checks the game and the build after entering, too.

## Spacewar, Valve's development App ID, until the game has its own.
const APP_ID: int = 480

var _steam: Object = null
## EVERY CONNECTION MADE TO THE STEAM SINGLETON, as [signal, callable], so `close` can take each one off again.
var _hooks: Array = []
var _find_active: Dictionary = {}
var _find_queue: Array[Dictionary] = []


func unavailable() -> String:
	if _steam != null:
		return ""
	if not Engine.has_singleton("Steam"):
		return "Steam is not in this build."
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))
	var steam: Object = Engine.get_singleton("Steam")
	var said: Dictionary = steam.call("steamInitEx", APP_ID, true)
	if int(said.get("status", 1)) != 0:
		return "Steam is not running. Start Steam and try again."
	_steam = steam
	_hook("lobby_created", func(result: int, lobby: int) -> void: opened.emit(lobby, result))
	_hook("lobby_match_list", _on_lobbies_found)
	_hook("lobby_joined", func(lobby: int, _permissions: int, _locked: bool, response: int) -> void:
		entered.emit(lobby, response))
	_hook("join_requested", func(lobby: int, _friend: int) -> void: invited.emit(lobby))
	return ""


func _hook(signal_name: String, callable: Callable) -> void:
	_steam.connect(signal_name, callable)
	_hooks.append([signal_name, callable])


func pump() -> void:
	if _steam != null:
		_steam.call("run_callbacks")


## EVERY CONNECTION OFF THE STEAM SINGLETON, THEN STEAM SHUT DOWN.
##
## THE CONNECTIONS ARE THE CRASH. Measured on 2026-09-14 on both editors, two runs a case: a GDScript lambda still
## connected to `Steam` when the game quits makes the process exit 0xC0000005 after everything else has finished --
## with a lobby or without, with Steam initialised or never, with `steamShutdown` called or not. The same runs with the
## lambda disconnected first exit 0. GodotSteam frees its singleton in the extension's terminator, after the scripts
## are gone, and takes the dangling connection with it (Windows: ntdll.dll+0x1283d on the stock editor). `Net._exit_tree`
## calls this, and tests/steam_quit.gd reads the exit code of a child that hosted over Steam and quit.
func close() -> void:
	if _steam == null:
		return
	for hook in _hooks:
		if _steam.is_connected(String(hook[0]), hook[1]):
			_steam.disconnect(String(hook[0]), hook[1])
	_hooks.clear()
	_find_active.clear()
	_find_queue.clear()
	_steam.call("steamShutdown")
	_steam = null


func me() -> int:
	return int(_steam.call("getSteamID")) if _steam != null else 0


## Persona is read only after a Steam action has already initialised this directory. Merely
## wanting a display name must never start Steam or contend with a second local process.
func persona_name() -> String:
	return String(_steam.call("getPersonaName")) if _steam != null and _steam.has_method("getPersonaName") else ""


func open(most: int) -> void:
	_steam.call("createLobby", _constant("LOBBY_TYPE_PUBLIC"), most)


func write(lobby: int, key: String, value: String) -> void:
	_steam.call("setLobbyData", lobby, key, value)


func read(lobby: int, key: String) -> String:
	return String(_steam.call("getLobbyData", lobby, key))


func members(lobby: int) -> int:
	return int(_steam.call("getNumLobbyMembers", lobby))


func limit(lobby: int) -> int:
	return int(_steam.call("getLobbyMemberLimit", lobby))


func owner(lobby: int) -> int:
	return int(_steam.call("getLobbyOwner", lobby))


## WORLDWIDE, because the default distance filter only returns lobbies "in the same region or nearby regions", and a
## friend on another continent typing a code they were given should still find it.
func find(request: int, wanted: Dictionary, most: int) -> void:
	_find_queue.append({"request": request, "wanted": wanted.duplicate(), "most": most})
	_start_next_find()


func cancel_find(request: int) -> void:
	if int(_find_active.get("request", 0)) == request:
		# RequestLobbyList has no explicit cancel call, but Steamworks guarantees that
		# starting the next request cancels the old one. Release this owner now so a
		# timed-out search cannot poison every later search in this process.
		_find_active.clear()
		_start_next_find()
		return
	for index in range(_find_queue.size() - 1, -1, -1):
		if int((_find_queue[index] as Dictionary).get("request", 0)) == request:
			_find_queue.remove_at(index)


func _start_next_find() -> void:
	if _steam == null or not _find_active.is_empty() or _find_queue.is_empty():
		return
	_find_active = _find_queue.pop_front()
	find_started.emit(int(_find_active["request"]))
	var wanted: Dictionary = _find_active["wanted"]
	var most: int = int(_find_active["most"])
	_steam.call("addRequestLobbyListDistanceFilter", _constant("LOBBY_DISTANCE_FILTER_WORLDWIDE"))
	for key in wanted:
		_steam.call("addRequestLobbyListStringFilter", String(key), String(wanted[key]), _constant("LOBBY_COMPARISON_EQUAL"))
	_steam.call("addRequestLobbyListResultCountFilter", most)
	_steam.call("requestLobbyList")


func _on_lobbies_found(lobbies: Array) -> void:
	if _find_active.is_empty():
		return
	var request: int = int(_find_active["request"])
	_find_active.clear()
	found.emit(request, lobbies)
	_start_next_find()


func enter(lobby: int) -> void:
	_steam.call("joinLobby", lobby)


func leave(lobby: int) -> void:
	if _steam != null:
		_steam.call("leaveLobby", lobby)


func peer_to_host(lobby: int) -> MultiplayerPeer:
	return _peer("host_with_lobby", lobby)


func peer_to_join(lobby: int) -> MultiplayerPeer:
	return _peer("connect_to_lobby", lobby)


func _peer(how: String, lobby: int) -> MultiplayerPeer:
	if not ClassDB.class_exists(&"SteamMultiplayerPeer"):
		return null
	var peer := ClassDB.instantiate(&"SteamMultiplayerPeer") as MultiplayerPeer
	if peer == null:
		return null
	# NAGLE OFF, before the peer opens. GodotSteam 4.21 defaults `no_nagle = false` (godotsteam_multiplayer_peer.h:74), and
	# its send flags are built from it (godotsteam_multiplayer_peer.cpp:711), so every message would be held back in case
	# another follows -- and sync sends a small packet every tick, which is exactly what Nagle batches.
	peer.call("set_no_nagle", true)
	if int(peer.call(how, lobby)) != OK:
		return null
	return peer


func _constant(named: String) -> int:
	return ClassDB.class_get_integer_constant(&"Steam", named)
