extends LobbyDirectory
class_name PaperLobbyDirectory
## A LOBBY DIRECTORY KEPT ON PAPER, for suites: every lobby a Dictionary, every answer a frame late, and the game carried
## over ENet on the loopback.
##
## One Steam account cannot be two peers on one machine, so nothing about joining by code could be tested if the path
## needed Steam. This stands where Steam stands and nowhere else: `Net` asks it exactly what it asks
## `SteamLobbyDirectory`, and gets a real `ENetMultiplayerPeer` back, so a suite drives a typed code through the search,
## the checks, the entry and a real socket handshake into a session. What it cannot prove is Steam's half -- the probe
## (tests/steam_probe.gd) and a two-machine run do that.
##
## ANSWERS A FRAME LATE, deferred, because Steam never answers inside the call and a `Net` that only worked when it did
## would work only here. And every answer can be withheld or changed, which is how each refusal is reached.
##
## MATCHES IGNORING CASE, because Steam's string filter does: measured on 2026-09-14, a code searched in lower case
## found its lobby.

## "" to be usable, or the sentence `unavailable` says.
var said_unavailable: String = ""
## Set false to never answer that kind of request, which is what a deadline is for.
var answers_opening: bool = true
var answers_searches: bool = true
var answers_entries: bool = true
## What `open` answers, and what `enter` answers when the lobby is there and has room.
var open_result: int = OPENED
var enter_response: int = ENTERED
## Who is asking. A number that looks nothing like a peer id, so the two cannot be mixed up unnoticed.
var who_i_am: int = 76561190000000001
## The port a lobby opened here is carried on.
var port: int = 0
## lobby -> {data: Dictionary, members: int, limit: int, owner: int, port: int}
var lobbies: Dictionary = {}
## What was asked, in order, so a suite can say nothing was asked.
var searches: Array = []
var entries: Array = []
## Every `leave` of a lobby this machine was not in. Steam ignores one; a `Net` that sends one has lost track of where it
## is, so it is written down here rather than quietly done.
var stray_leaves: Array = []
## The lobbies this machine is in: made by it, or entered.
var _mine: Dictionary = {}
var _next: int = 100
var _find_active: Dictionary = {}
var _find_queue: Array[Dictionary] = []


## WRITE A LOBBY DOWN, as somebody else's host would have made it. Returns its id.
func put(data: Dictionary, in_it: int, most: int, owned_by: int, carried_on: int) -> int:
	_next += 1
	lobbies[_next] = {"data": data.duplicate(), "members": in_it, "limit": most, "owner": owned_by,
		"port": carried_on}
	return _next


## AN INVITE ACCEPTED, or Join Game pressed on a friend's profile, as Steam would say it: a frame late.
func invite(lobby: int) -> void:
	invited.emit.call_deferred(lobby)


## How many times this directory was asked whether it can be used -- which, for Steam's, is what starts Steam. A suite
## counts it to see who starts Steam, and when.
var asked: int = 0


func unavailable() -> String:
	asked += 1
	return said_unavailable


func me() -> int:
	return who_i_am


func open(most: int) -> void:
	if not answers_opening:
		return
	if open_result != OPENED:
		opened.emit.call_deferred(0, open_result)
		return
	var made: int = put({}, 1, most, who_i_am, port)
	_mine[made] = true
	opened.emit.call_deferred(made, OPENED)


func write(lobby: int, key: String, value: String) -> void:
	if lobbies.has(lobby):
		(lobbies[lobby]["data"] as Dictionary)[key] = value


func read(lobby: int, key: String) -> String:
	return String((lobbies[lobby]["data"] as Dictionary).get(key, "")) if lobbies.has(lobby) else ""


func members(lobby: int) -> int:
	return int(lobbies[lobby]["members"]) if lobbies.has(lobby) else 0


func limit(lobby: int) -> int:
	return int(lobbies[lobby]["limit"]) if lobbies.has(lobby) else 0


## WHO OWNS A LOBBY, AND ONLY WHERE STEAM WOULD SAY SO. Steam answers 0 about a lobby this machine is not in, and until
## 2026-09-15 this answered anyway -- so every suite believed a question could be asked of a search result that cannot be.
##
## Measured that day against the real backend, `tests/steam_probe.gd --strangers`: of fifty lobbies of other developers'
## games on the shared App ID 480, fifty gave a member limit, fifty a member count and forty-four their lobby data, and
## NONE gave an owner. Steamworks says the same of GetLobbyOwner -- "You must be a member of the lobby to access this."
func owner(lobby: int) -> int:
	if not _mine.has(lobby):
		return 0
	return int(lobbies[lobby]["owner"]) if lobbies.has(lobby) else 0


func find(request: int, wanted: Dictionary, most: int) -> void:
	searches.append(wanted.duplicate())
	_find_queue.append({"request": request, "wanted": wanted.duplicate(), "most": most})
	_start_next_find()


func cancel_find(request: int) -> void:
	if int(_find_active.get("request", 0)) == request:
		_find_active.clear()
		_start_next_find()
		return
	for index in range(_find_queue.size() - 1, -1, -1):
		if int((_find_queue[index] as Dictionary).get("request", 0)) == request:
			_find_queue.remove_at(index)


func _start_next_find() -> void:
	if not _find_active.is_empty() or _find_queue.is_empty():
		return
	_find_active = _find_queue.pop_front()
	find_started.emit(int(_find_active["request"]))
	if answers_searches:
		_answer_find.call_deferred(int(_find_active["request"]))


func _answer_find(request: int) -> void:
	if _find_active.is_empty() or int(_find_active.get("request", 0)) != request:
		return
	var wanted: Dictionary = _find_active["wanted"]
	var most: int = int(_find_active["most"])
	var matches: Array = []
	for lobby in lobbies:
		var data: Dictionary = lobbies[lobby]["data"]
		var all: bool = true
		for key in wanted:
			all = all and String(data.get(key, "")).nocasecmp_to(String(wanted[key])) == 0
		if all and matches.size() < most:
			matches.append(lobby)
	_find_active.clear()
	found.emit(request, matches)
	_start_next_find()


func enter(lobby: int) -> void:
	entries.append(lobby)
	if not answers_entries:
		return
	var response: int = enter_response
	if not lobbies.has(lobby):
		response = DOES_NOT_EXIST
	elif response == ENTERED and members(lobby) >= limit(lobby):
		response = FULL
	if response == ENTERED:
		lobbies[lobby]["members"] = members(lobby) + 1
		_mine[lobby] = true
	entered.emit.call_deferred(lobby, response)


## Out of the lobby; a lobby nobody is in is gone, as Steam's is. Out of one this machine is not in does nothing.
func leave(lobby: int) -> void:
	if not _mine.has(lobby):
		stray_leaves.append(lobby)
		return
	_mine.erase(lobby)
	if not lobbies.has(lobby):
		return
	lobbies[lobby]["members"] = members(lobby) - 1
	if members(lobby) <= 0:
		lobbies.erase(lobby)


func peer_to_host(lobby: int) -> MultiplayerPeer:
	if not lobbies.has(lobby):
		return null
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(int(lobbies[lobby]["port"]), limit(lobby)) != OK:
		return null
	return peer


func peer_to_join(lobby: int) -> MultiplayerPeer:
	if not lobbies.has(lobby):
		return null
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client("127.0.0.1", int(lobbies[lobby]["port"])) != OK:
		return null
	return peer
