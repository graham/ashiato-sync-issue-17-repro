extends RefCounted
## The local player's durable preference. The network still validates both fields.
##
## `typed` (2026-09-19): whether the name is one the player chose, which beats their Steam persona in every later run.
## A file from before it has none, and its name counts as typed when it is not the fallback "PLAYER N" -- the only way
## a name got into this file was the roster page's OK. See `Net`'s "THE PLAYER'S NAME".

const PATH: String = "user://player.json"


static func load_card() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {"name": "", "colour": 0}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_warning("[profile] player.json is not an object; defaults used")
		return {"name": "", "colour": 0}
	var name: String = String(parsed.get("name", ""))
	var typed: bool = bool(parsed.get("typed")) if parsed.get("typed") is bool else is_a_typed_name(name)
	return {"name": name, "colour": int(parsed.get("colour", 0)), "typed": typed}


## Whether a saved name is one the player chose: not empty, and not the fallback a card says when nobody chose.
static func is_a_typed_name(saved: String) -> bool:
	return not saved.strip_edges().is_empty() \
		and RegEx.create_from_string("^PLAYER \\d+$").search(saved.strip_edges()) == null


static func save_card(card: Dictionary) -> Error:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"name": String(card.get("name", "")), "colour": int(card.get("colour", 0)),
		"typed": bool(card.get("typed", false))}))
	return OK
