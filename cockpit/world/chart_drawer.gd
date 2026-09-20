extends RefCounted
class_name ChartDrawer
## EVERY LEVEL THERE IS: the folders under `levels/`, each read by `LevelChart`, scanned once and kept.
##
## Rule 7 of the workshop (building_a_game_here.md): content is a folder scanned at boot, the folder name is the id, a
## `_`-prefixed folder is skipped, and a malformed item disables itself with a message. A level that is refused is kept
## beside the usable ones with its reason, so a suite and a person can both ask why it is not on the desk, and the
## reason is said once, as a warning, when the drawer is first opened.
##
## WHICH LEVEL A SESSION FLIES is `Net.level`: chosen on the desk or with `--world=` before hosting or flying solo, and
## learned from the host by a joiner. This file only knows what exists.

const FOLDER: String = "res://levels"
## THE LEVEL NOTHING ELSE WAS ASKED FOR. The island, until the user accepts the alpine world's pictures (team-lead,
## 2026-09-15).
const DEFAULT: String = "island"
## THE LEVEL A HOSTED SESSION STARTS ON when nobody has chosen one. The user, 2026-09-15: "let's make the lobby default
## when hosting a session. and island if they are playing alone" -- so the default is not one level any more but a rule
## about the kind of session, and `Net.suit_the_session` is where the rule lives. Playing alone starts on `DEFAULT`.
const HOSTING: String = "lobby"
## `--world=<level id>`, after the bare `--`. The same word the terrain lane's probes were already passing, and not
## `--level=`, which is the boot router's word for a door.
const FLAG: String = "world"

## Where the drawer is: `--levels-from=res://...` after the bare `--`, or the game's folder. A suite points it at a
## folder of its own with `open_at`; a child process a suite starts is pointed with the flag, which is how a joiner
## with a different copy of a level is made (tests/level_join.gd).
static var folder: String = folder_for(OS.get_cmdline_user_args())
const FROM_FLAG: String = "--levels-from="


static func folder_for(arguments: PackedStringArray) -> String:
	for argument in arguments:
		if String(argument).begins_with(FROM_FLAG) and String(argument).substr(FROM_FLAG.length()).begins_with("res://"):
			return String(argument).substr(FROM_FLAG.length())
	return FOLDER


static var _charts: Array[LevelChart] = []
static var _opened: bool = false


## EVERY USABLE LEVEL, the default first and then by id: the order the desk lists them in.
static func charts() -> Array[LevelChart]:
	_open()
	var out: Array[LevelChart] = []
	for chart in _charts:
		if chart.usable():
			out.append(chart)
	return out


## EVERY LEVEL REFUSED, each with its `refusal`.
static func refused() -> Array[LevelChart]:
	_open()
	var out: Array[LevelChart] = []
	for chart in _charts:
		if not chart.usable():
			out.append(chart)
	return out


## THE USABLE LEVEL WITH THIS ID, or null.
static func chart(id: String) -> LevelChart:
	for each in charts():
		if each.id == id:
			return each
	return null


## Open the drawer at a folder of a suite's choosing, or the game's. The folder already open is not read again; `rescan`
## is for a folder whose files have changed. Every refusal is said again on a read.
static func open_at(where: String) -> void:
	if where == folder and _opened:
		return
	folder = where
	rescan()


static func rescan() -> void:
	_opened = false
	_open()


static func _open() -> void:
	if _opened:
		return
	_opened = true
	_charts.clear()
	var ids: PackedStringArray = DirAccess.get_directories_at(folder)
	ids.sort()
	for id in ids:
		if id.begins_with("_"):
			continue
		var chart := LevelChart.read(folder.path_join(id))
		if not chart.usable():
			push_warning("[levels] %s is not on the desk: %s" % [id, chart.refusal])
		_charts.append(chart)
	# THE DEFAULT FIRST, and the rest in the order of their ids, so the desk's row does not move when a level is added.
	_charts.sort_custom(func(a: LevelChart, b: LevelChart) -> bool:
		return a.id == DEFAULT if (a.id == DEFAULT) != (b.id == DEFAULT) else a.id < b.id)


## WHAT `--world=` ASKS FOR on a command line: {id: String, error: String}. `id` is "" when nothing was asked. An id that
## is not a usable level is an error in words, and so is naming a level on a command line that JOINS somebody: a joiner
## flies the host's level, and is told which in the handshake.
static func asked_in(arguments: PackedStringArray, session_mode: String) -> Dictionary:
	var out: Dictionary = {"id": "", "error": ""}
	for argument in arguments:
		var text: String = String(argument)
		if not text.begins_with("--%s=" % FLAG):
			continue
		var wanted: String = text.substr(FLAG.length() + 3)
		if chart(wanted) == null:
			var ids: PackedStringArray = []
			for each in charts():
				ids.append(each.id)
			out["error"] = "--%s=%s is not a level: %s" % [FLAG, wanted, ", ".join(ids)]
			return out
		if session_mode in ["join", "steam_code", "steam_lobby"]:
			out["error"] = "--%s= cannot go with a join: a joiner flies the host's level" % FLAG
			return out
		out["id"] = wanted
	return out
