extends RefCounted
class_name LobbyDirectory
## WHERE A GAME IS LOOKED UP BY ITS CODE: a directory of lobbies, each a handful of written-down facts, that answers
## later rather than at once.
##
## `Net` asks one of these and never Steam by name. `SteamLobbyDirectory` is the real one; `PaperLobbyDirectory` is a
## directory kept on paper that suites use, and hands out ENet peers on the loopback, so a test can drive the whole path
## from a code to a session with only Steam itself missing. This base is a directory with nothing in it that says so.
##
## THE SHAPE IS STEAM'S, measured in tests/steam_probe.gd on 2026-09-14 against GodotSteam 4.21: a lobby is made, then
## said to be made; a search is asked, then answered with every match at once (there is no fetching them one by one);
## a lobby is entered, then said to be entered with a response. So these are calls that return nothing and signals that
## carry the answer, and `Net` puts a deadline on every one, because a Steam request that is never answered is not an
## error anybody sees.
##
## THE NUMBERS ARE STEAM'S TOO, as the binary reported them, so a paper directory answers in the same words.

## `open` answered: `lobby` is 0 unless `result` is OPENED.
signal opened(lobby: int, result: int)
## `find` answered, with its owner id and every lobby that matched.
signal found(request: int, lobbies: Array)
## The request now owns Steam's one search slot. Deadlines begin here, not while queued.
signal find_started(request: int)
## `enter` answered.
signal entered(lobby: int, response: int)
## SOMEBODY ASKED TO JOIN `lobby` FROM OUTSIDE THE GAME: an invite accepted, or Join Game on a friend's profile. No search
## found it, so nothing about it has been checked.
signal invited(lobby: int)

## Steam's RESULT_OK.
const OPENED: int = 1
## Steam's CHAT_ROOM_ENTER_RESPONSE_*, as GodotSteam 4.21 reports them.
const ENTERED: int = 1
const DOES_NOT_EXIST: int = 2
const NOT_ALLOWED: int = 3
const FULL: int = 4
const RATE_LIMITED: int = 15


## WHY THIS DIRECTORY CANNOT BE ASKED ANYTHING, as a sentence, or "" when it can. May do the work of getting ready.
func unavailable() -> String:
	return "There is no lobby directory in this build."


## Let whatever answers arrive. Called every frame.
func pump() -> void:
	pass


## PUT EVERYTHING AWAY BEFORE THE GAME GOES: nothing this directory hooked into is left pointing back at it.
func close() -> void:
	pass


## Who is asking, as the directory knows them.
func me() -> int:
	return 0


func open(_members: int) -> void:
	pass


func write(_lobby: int, _key: String, _value: String) -> void:
	pass


func read(_lobby: int, _key: String) -> String:
	return ""


func members(_lobby: int) -> int:
	return 0


func limit(_lobby: int) -> int:
	return 0


func owner(_lobby: int) -> int:
	return 0


## Every lobby whose written-down facts include all of `wanted`, and at most `most` of them.
func find(_request: int, _wanted: Dictionary, _most: int) -> void:
	pass


func cancel_find(_request: int) -> void:
	pass


func enter(_lobby: int) -> void:
	pass


func leave(_lobby: int) -> void:
	pass


## THE PEER THE GAME TRAVELS OVER, once the lobby is made or entered, or null when there is none to be had.
func peer_to_host(_lobby: int) -> MultiplayerPeer:
	return null


func peer_to_join(_lobby: int) -> MultiplayerPeer:
	return null
