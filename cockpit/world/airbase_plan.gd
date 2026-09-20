extends RefCounted
class_name AirbasePlan
## AN AIR BASE ROUND A RUNWAY, laid from one file: the taxiways, the aprons, the hangars, the revetments, the tower, the
## parking spots and the route an aeroplane taxis along, all in the runway's own frame.
##
## WHY ONE FILE AND A FRAME. The user asked for "an airbase ... modelled on what a real airbase looks like" (2026-09-17),
## and a real one is a runway with everything else measured off it: a taxiway so far from the centreline, a hold bar so
## far, a tower near the middle. So the file says where things are ALONG and ACROSS a runway `Terrain.runways()` already
## has, and the runway itself stays the island's constants -- one number, one place. Its ends are named rather than
## typed ("threshold", "far_end"), so a longer runway carries the end stubs and the parallel taxiway with it.
##
## EVERYTHING ELSE IS DERIVED FROM THE FILE, NEVER TYPED BESIDE IT: the pavement the level draws, the boxes the
## simulation collides with, the spots craft park and are issued on, the tower's place, and the route graph -- whose
## nodes are where taxiway centrelines meet, the hold bars, the runway joins and each spot's mouth, and whose edges run
## between neighbouring nodes along each taxiway. A route typed out node by node beside the taxiways would be a second
## copy of them that goes wrong the first time a taxiway moves.
##
## CONTENT IS A FOLDER SCANNED AT BOOT (building_a_game_here.md, rule 7): `res://world/airbases/<id>/airbase.json`, the
## folder name is the id, `_` folders are skipped, and a base that cannot be read or laid disables itself with a warning
## rather than being half a base. `_template` is a working base the suite reads by name.
##
## A BASE IS LAID ONLY WHERE IT FITS:
## - on a runway whose bearing is a whole number of quarter turns, because `Sim.add_static_box` has no rotation and a
##   hangar turned by 30 degrees would collide somewhere other than where it is drawn;
## - on ground level with the runway under every corner of its pavement, its walls and its tower, within LEVEL_SLACK.
##   The island's slab is flat everywhere. The generated ground's airfield strips are flattened only 120 m either side of
##   the centreline (`ground_core.cpp`, `Strip{..., 120, 380, ...}`), and a parallel taxiway 320 m out stands on a
##   mountainside there -- so on that world the base is refused by name and the strip keeps its bare runway. A wider
##   flat is a C++ change to the ground's function, for its own lane.

const FOLDER: String = "res://world/airbases"
## How far the ground under a base may stand from the runway's level, metres, and the base still be laid. The island's
## slab is exactly level; a generated strip's flat is within a height tick (1/32 m).
const LEVEL_SLACK: float = 0.5
## HOW FAR PAST A CLEARANCE THE PLAN LAYS WHAT IT WORKS OUT FROM ONE, metres: a surveyor's decimetre, on the safe side.
## Laid exactly on the line, a revetment's front stood "27.1 m from taxilane ramp's centreline, wanted 27.1" and read as
## inside it by a rounding (2026-09-19).
const SET_OUT: float = 0.1
## How far off a whole number of quarter turns a runway's bearing may be and still count as one, radians.
const QUARTER_SLACK: float = 0.0001
## Two route nodes nearer than this are one node, metres: where a link's end meets the taxiway it joins.
const SAME_NODE: float = 0.5
## THE PAVEMENT'S THICKNESS, as a half-height, metres. Drawn under the runway's asphalt (whose top is 0.12 m) so where a
## stub runs onto the runway the runway's own paint is what shows.
const PAVEMENT_HALF_HEIGHT: float = 0.05
## The kinds a taxiway may be: a taxiway proper, which the taxiway clearance applies to, or a taxilane on an apron.
const TAXIWAY_KINDS: Array[String] = ["taxiway", "taxilane"]
const REQUIRED_STANDARDS: Array[String] = ["taxiway_width", "taxiway_obstacle_clearance", "taxiway_to_taxilane",
	"hold_bar", "wingtip_to_wingtip", "wingtip_to_taxilane", "fillet"]
## The standards a base needs only when it has what they are about: revetments, exits, a terminal or a tower it builds.
const REVETMENT_STANDARDS: Array[String] = ["wall_clearance", "revetment_wall_height", "revetment_wall_thickness"]
const EXIT_STANDARDS: Array[String] = ["exit_angle_degrees"]
const BUILT_TOWER_STANDARDS: Array[String] = ["tower_height", "tower_cab"]
const HANGAR_NUMBERS: Array[String] = ["width", "depth", "clear_height", "door_width", "door_height"]
const ROOFS: Array[String] = ["gable", "arch", "flat"]

## The bases laid on the world last asked about, and which world that was: a base is read from disk and laid once, not
## once for every reader of `boxes()` and `spawns()`, and its warning is said once.
static var _laid: Array[Dictionary] = []
static var _laid_on: Object = null
static var _laid_ready: bool = false


## EVERY BASE THE GAME HAS, read, in id order. A base that cannot be read is left out with a warning.
static func catalogue() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(FOLDER):
		return out
	var ids: PackedStringArray = DirAccess.get_directories_at(FOLDER)
	ids.sort()
	for id in ids:
		if id.begins_with("_"):
			continue
		var base: Dictionary = read_base(FOLDER.path_join(id))
		if not base.is_empty():
			out.append(base)
	return out


## EVERY BASE LAID ON THE WORLD THE TERRAIN STANDS ON NOW: each base on its runway, or left out with a warning. Worked
## out once for a world and kept.
static func bases() -> Array[Dictionary]:
	if _laid_ready and _laid_on == Terrain.standing_on():
		return _laid
	_laid = []
	var runways: Array[Dictionary] = Terrain.runways()
	for base in catalogue():
		var which: int = runway_index(base["runway"])
		if which < 0 or which >= runways.size():
			# A BASE FOR ANOTHER WORLD'S RUNWAY IS NOT THIS WORLD'S FAULT: the catalogue is every base there is, and each world lays
			# the ones on its own runways. Said only under --verbose; a runway that no airfield file names at all still warns
			# (lane/noplace, 2026-09-19: the test field, the glider level and the generated ground each printed a warning for
			# every base that belongs to another).
			if _is_another_worlds(base["runway"]):
				print_verbose("[airbase] %s: its runway %s belongs to another world; it is not laid here" % [base["id"], str(base["runway"])])
			else:
				_refuse(base["id"], "this world has no runway %s" % str(base["runway"]))
			continue
		var others: Dictionary = {}
		for other in base.get("also_runways", []):
			var index: int = runway_index(other)
			if index < 0:
				break
			others[other] = runways[index]
		if others.size() != (base.get("also_runways", []) as Array).size():
			if (base.get("also_runways", []) as Array).any(_is_another_worlds):
				continue
			_refuse(base["id"], "this world has not got every runway in %s" % str(base["also_runways"]))
			continue
		var laid: Dictionary = lay(base, runways[which], others)
		if not laid.is_empty():
			laid["runway"] = which
			laid["also_indices"] = []
			for other in others:
				(laid["also_indices"] as Array).append(runway_index(other))
			_laid.append(laid)
	_laid_on = Terrain.standing_on()
	_laid_ready = true
	return _laid


## WHICH OF THIS WORLD'S RUNWAYS A BASE FILE MEANS: a number is an index into `Terrain.runways()`, and a string is the id
## of the airfield file that lays it (`Airfield`), which is how a base names a runway that is not the world's own -- its
## index depends on which other airfield files there are. -1 for none.
static func runway_index(runway: Variant) -> int:
	# AN INDEX MEANS ONE OF THE WORLD'S OWN RUNWAYS: the island's first strip, or the generated ground's flattest. A level
	# laid from its own airfield files has none of those, and its runway 0 is whichever of its files sorts first, so an
	# index there is no runway. The island's fighter base, `"runway": 0`, was laid round the test field's air base runway
	# by the accident of that sort (lane/testfield, 2026-09-19).
	if _is_number(runway):
		return -1 if Airfield.world_here() not in Airfield.WORLDS else int(runway)
	if runway is String:
		return int(Airfield.named(runway).get("index", -1))
	return -1


## WHETHER A RUNWAY A BASE NAMES IS ANOTHER WORLD'S, and so honestly absent here: a number on a level laid from its own airfield
## files (the island's and the generated ground's indices mean nothing there), or the id of an airfield file whose `world` is
## not this one. A name no airfield file has is not another world's, it is a mistake.
static func _is_another_worlds(runway: Variant) -> bool:
	if _is_number(runway):
		return Airfield.world_here() not in Airfield.WORLDS
	if runway is String:
		for field in Airfield.catalogue():
			if String(field["id"]) == runway:
				return String(field["world"]) != Airfield.world_here()
	return false


## THE BASE LAID ROUND THIS WORLD'S RUNWAY NUMBER `which`, or {} where there is none: the runway it was laid on, or one it
## also serves.
static func on_runway(which: int) -> Dictionary:
	for base in bases():
		if int(base["runway"]) == which or (base.get("also_indices", []) as Array).has(which):
			return base
	return {}


## EVERY SOLID BOX OF EVERY BASE ON THIS WORLD, for `Terrain.boxes()`.
static func boxes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for base in bases():
		out.append_array(base["boxes"])
	return out


## ---- reading ------------------------------------------------------------------------------------------------------

## ONE BASE, READ AND CHECKED FOR SHAPE, or {} with a warning saying why not. Public so a test can hand it a broken one.
## Nothing here needs a runway: where things land is `lay`'s business. Returns the manifest with `id` added.
static func read_base(path: String) -> Dictionary:
	var id: String = path.get_file()
	var file := FileAccess.open(path.path_join("airbase.json"), FileAccess.READ)
	if file == null:
		return _refuse(id, "there is no airbase.json")
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return _refuse(id, "airbase.json is not a JSON object (line %d: %s)" % [json.get_error_line(),
			json.get_error_message()])
	var data: Dictionary = json.data
	var why: String = _shape_problem(data)
	if why != "":
		return _refuse(id, why)
	data["id"] = id
	return data


## WHY THE LAST BASE REFUSED WAS REFUSED, in the words of its warning: so a test can tell a base refused for its own
## reason from one refused for another, which a bare {} cannot.
static var last_refusal: String = ""


## SAY WHY A BASE IS NOT LAID, and hand back the {} that means so.
static func _refuse(id: String, why: String) -> Dictionary:
	last_refusal = why
	push_warning("[airbase] %s: %s; it is not laid" % [id, why])
	return {}


## WHAT IS WRONG WITH A MANIFEST'S SHAPE, or "" for nothing: every key present with the right type, every taxiway
## running along one axis, every id unique. Whether the numbers keep the published clearances -- does a wall stand clear
## of a taxiway -- is `tests/airbase.gd`'s, against the file's own `standards`.
static func _shape_problem(data: Dictionary) -> String:
	if not (data.get("name") is String):
		return "`name` is not a string"
	var named_runway: bool = data.get("runway") is String and (data["runway"] as String) != ""
	if not named_runway and (not _is_number(data.get("runway")) or float(data["runway"]) < 0.0 \
			or float(data["runway"]) != floor(float(data["runway"]))):
		return "`runway` is neither a runway number nor an airfield's id"
	if not (data.get("also_runways", []) is Array):
		return "`also_runways` is not a list of airfield ids"
	for other in data.get("also_runways", []):
		if not (other is String) or not (other as String).is_valid_identifier():
			return "`also_runways` has %s, which is not an airfield's id" % JSON.stringify(other)
	if not (data.get("standards") is Dictionary):
		return "`standards` is not an object"
	var standards: Dictionary = data["standards"]
	var wanted: Array[String] = REQUIRED_STANDARDS.duplicate()
	if not (data.get("revetments", []) as Array).is_empty():
		wanted.append_array(REVETMENT_STANDARDS)
	if not (data.get("exits", []) as Array).is_empty():
		wanted.append_array(EXIT_STANDARDS)
	if data.get("tower") is Dictionary and bool((data["tower"] as Dictionary).get("built", false)):
		wanted.append_array(BUILT_TOWER_STANDARDS)
	for key in wanted:
		if not _is_number(standards.get(key)) or float(standards[key]) <= 0.0:
			return "`standards.%s` is not a positive number" % key
	if not (data.get("apron_craft") is String) or not Sim.Kind.has(data["apron_craft"]):
		return "`apron_craft` is not a kind of craft"
	if not (standards.get("hangar_types") is Dictionary):
		return "`standards.hangar_types` is not an object"
	for type in standards["hangar_types"]:
		var hangar: Variant = standards["hangar_types"][type]
		if not (hangar is Dictionary):
			return "hangar type %s is not an object" % type
		for key in HANGAR_NUMBERS:
			if not _is_number(hangar.get(key)) or float(hangar[key]) <= 0.0:
				return "hangar type %s: `%s` is not a positive number" % [type, key]
		if float(hangar["door_width"]) > float(hangar["width"]) or float(hangar["door_height"]) > float(hangar["clear_height"]):
			return "hangar type %s: its door is bigger than its bay" % type
		if not (hangar.get("roof") in ROOFS):
			return "hangar type %s: `roof` is not one of %s" % [type, ROOFS]
	var ids: Dictionary = {}
	if not (data.get("taxiways") is Array) or (data["taxiways"] as Array).is_empty():
		return "`taxiways` is not a list of taxiways"
	for taxiway in data["taxiways"]:
		if not (taxiway is Dictionary) or not (taxiway.get("id") is String):
			return "a taxiway has no `id`"
		if ids.has(taxiway["id"]):
			return "`%s` is used twice" % taxiway["id"]
		ids[taxiway["id"]] = true
		if not (taxiway.get("kind") in TAXIWAY_KINDS):
			return "taxiway %s: `kind` is not one of %s" % [taxiway["id"], TAXIWAY_KINDS]
		var runs_along: bool = taxiway.get("along") is Array
		var runs_across: bool = taxiway.get("across") is Array
		if runs_along == runs_across:
			return "taxiway %s: exactly one of `along` and `across` must be a pair" % taxiway["id"]
		for key in ["along", "across"]:
			var values: Array = taxiway[key] if taxiway[key] is Array else [taxiway[key]]
			if values.size() != (2 if taxiway[key] is Array else 1):
				return "taxiway %s: `%s` is not a pair" % [taxiway["id"], key]
			for value in values:
				if not _is_place(value, key):
					return "taxiway %s: `%s` has %s, which is not a place" % [taxiway["id"], key, JSON.stringify(value)]
	for list in ["aprons", "revetments", "hangars", "parked"]:
		if not (data.get(list) is Array):
			return "`%s` is not a list" % list
	for apron in data["aprons"]:
		if not (apron is Dictionary) or not (apron.get("id") is String):
			return "an apron has no `id`"
		if not _is_pair(apron.get("along")) or not _is_pair(apron.get("across")) or not _is_number(apron.get("nose_line")):
			return "apron %s: `along` and `across` must be number pairs and `nose_line` a number" % apron["id"]
		if not _is_number(apron.get("spots")) or float(apron["spots"]) < 1.0 \
				or float(apron["spots"]) != floor(float(apron["spots"])):
			return "apron %s: `spots` is not a count of spots" % apron["id"]
		if apron.has("craft") and (not (apron["craft"] is String) or not Sim.Kind.has(apron["craft"])):
			return "apron %s: `craft` is not a kind of craft" % apron["id"]
		if not (apron.get("nose_in", false) is bool):
			return "apron %s: `nose_in` is not true or false" % apron["id"]
	for list in ["exits", "terminals"]:
		if not (data.get(list, []) is Array):
			return "`%s` is not a list" % list
	for exit in data.get("exits", []):
		if not (exit is Dictionary) or not (exit.get("id") is String):
			return "an exit has no `id`"
		if not (exit.get("runway", "") is String) or not (exit.get("to") is String) \
				or not (exit.get("heading") in [1.0, -1.0, 1, -1]) or not (exit.get("from") is String or _is_number(exit.get("from"))):
			return "exit %s needs `from` (a place on its runway), `heading` (+1 or -1, the landing direction along that axis), `to` (a taxiway) and a `runway` (\"\" for the base's own)" % exit["id"]
	for terminal in data.get("terminals", []):
		if not (terminal is Dictionary) or not (terminal.get("id") is String):
			return "a terminal has no `id`"
		if not _is_pair(terminal.get("along")) or not _is_pair(terminal.get("across")) \
				or not _is_number(terminal.get("height")) or float(terminal["height"]) <= 0.0:
			return "terminal %s: `along` and `across` must be number pairs and `height` a positive number" % terminal["id"]
	for block in data["revetments"]:
		if not (block is Dictionary) or not (block.get("id") is String):
			return "a revetment block has no `id`"
		for key in ["along", "bays", "bay_width", "bay_depth"]:
			if not _is_number(block.get(key)):
				return "revetment block %s: `%s` is not a number" % [block["id"], key]
		if not (block.get("taxilane") is String):
			return "revetment block %s: `taxilane` does not name the taxilane its bays open onto" % block["id"]
		if int(block["bays"]) < 1 or float(block["bay_width"]) <= 0.0 or float(block["bay_depth"]) <= 0.0:
			return "revetment block %s: it needs at least one bay of positive size" % block["id"]
	for hangar in data["hangars"]:
		if not (hangar is Dictionary) or not (hangar.get("id") is String):
			return "a hangar has no `id`"
		if not (standards["hangar_types"] as Dictionary).has(hangar.get("type")):
			return "hangar %s: `type` is not one of standards.hangar_types" % hangar["id"]
		if not _is_number(hangar.get("along")) or not _is_number(hangar.get("door")) or float(hangar["door"]) == 0.0:
			return "hangar %s: `along` and `door` must be numbers, and a door on the centreline faces nowhere" % hangar["id"]
	# ONE NAMESPACE for every taxiway, apron, revetment block and hangar: spots and route nodes are named after them.
	for thing in (data["revetments"] as Array) + (data["aprons"] as Array) + (data["hangars"] as Array) \
			+ (data.get("exits", []) as Array) + (data.get("terminals", []) as Array):
		if ids.has(thing["id"]):
			return "`%s` is used twice" % thing["id"]
		ids[thing["id"]] = true
	if not (data.get("tower") is Dictionary) or not _is_number(data["tower"].get("along")) \
			or not _is_number(data["tower"].get("across")):
		return "`tower` needs a numeric `along` and `across`"
	for parked in data["parked"]:
		if not (parked is Dictionary) or not (parked.get("kind") is String) or not (parked.get("spot") is String):
			return "a parked craft needs a `kind` and a `spot`"
		if not Sim.Kind.keys().has(parked["kind"]):
			return "parked kind %s is not a kind" % parked["kind"]
	return ""


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_pair(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 2 and _is_number(value[0]) and _is_number(value[1])


## Whether a value names a place on an axis: a number, or on `along` a runway end with an optional offset, or on
## `across` the runway's edge.
static func _is_place(value: Variant, axis: String) -> bool:
	if _is_number(value):
		return true
	if not (value is String):
		return false
	var text: String = (value as String).trim_prefix("-")
	# ANOTHER RUNWAY'S PLACE, `<airfield id>.<name>`: whether that runway exists and runs the right way is `lay`'s to say.
	if text.contains("."):
		var id: String = text.get_slice(".", 0)
		var rest: String = text.substr(id.length() + 1)
		for name in OTHER_PLACES:
			if rest == name or (rest.begins_with(name) and rest.substr((name as String).length()).is_valid_float()):
				return id.is_valid_identifier()
		return false
	var named: Array = ["threshold", "far_end"] if axis == "along" else ["runway_edge"]
	for name in named:
		if text == name:
			return true
		if text.begins_with(name) and text.substr(name.length()).is_valid_float():
			return true
	return false


## THE NAMES A PLACE ON ANOTHER RUNWAY MAY HAVE: its two ends, on the axis it runs along, and its centreline and its edge on
## the other. `<id>.edge` is the centreline plus half its width, `-<id>.edge` minus; an offset after any of them is added
## as it is, metres along the axis ("cape_18_36.threshold+1700").
const OTHER_PLACES: Array[String] = ["threshold", "far_end", "centreline", "edge"]


## A PLACE ON AN AXIS ("along" or "across"), in metres, for this runway: a number as it is, or a named place worked out
## from the frame -- or from `others`, the base's other runways as `_other_runways` lays them in this frame. NAN for a
## place that is not there: a runway the base does not serve, or an end asked for on the axis that runway lies across.
static func _resolve(value: Variant, frame: Dictionary, axis: String = "", others: Dictionary = {}) -> float:
	if _is_number(value):
		return float(value)
	var text: String = (value as String).trim_prefix("-")
	var sign: float = -1.0 if (value as String).begins_with("-") else 1.0
	if text.contains("."):
		var runway: Dictionary = others.get(text.get_slice(".", 0), {})
		if runway.is_empty():
			return NAN
		var rest: String = text.substr(text.get_slice(".", 0).length() + 1)
		var runs_on: String = "along" if bool(runway["runs_along"]) else "across"
		for name in OTHER_PLACES:
			if not rest.begins_with(name):
				continue
			var offset: float = float(rest.substr((name as String).length())) if rest != name else 0.0
			match name:
				"threshold", "far_end":
					return float(runway[name]) + offset if axis == runs_on and sign > 0.0 else NAN
				"centreline":
					return float(runway["centreline"]) + offset if axis != runs_on and sign > 0.0 else NAN
				"edge":
					return float(runway["centreline"]) + sign * float(runway["width"]) * 0.5 + offset if axis != runs_on else NAN
		return NAN
	var named: Dictionary = {"threshold": -float(frame["length"]) * 0.5, "far_end": float(frame["length"]) * 0.5,
		"runway_edge": float(frame["width"]) * 0.5}
	for name in named:
		if text.begins_with(name):
			var rest: String = text.substr((name as String).length())
			return sign * (float(named[name]) + (float(rest) if rest != "" else 0.0))
	return NAN


## ---- laying ----------------------------------------------------------------------------------------------------

## ONE BASE LAID ON ONE RUNWAY'S FRAME (`Terrain.runway_frame`), in the world, or {} with a warning saying why not.
##
## THE TWO THINGS A WING DECIDES ARE WORKED OUT, NOT TYPED: the file names its `apron_craft`, the widest craft its aprons
## and taxilanes are laid out for, and from that craft's half span (`half_span_of`, the shape table's) an apron's
## `spots` -- a count -- are spaced a span and `wingtip_to_wingtip` apart, and a revetment block's front stands
## `wingtip_to_taxilane` past a wingtip off the taxilane it names. Both were typed, 33.1 m pitches and fronts at 420 m,
## round a 30 m airliner; when lane/liners drew the 737 at its real 35.8 m (2026-09-19) no apron spot held it and both
## blocks' walls stood 25.0 m from the ramp's centreline where 27.1 was wanted. A wing redrawn now moves the base.
##
## Returns `{id, name, frame, standards, taxiways, pavement, boxes, spots, nodes, edges, tower, parked, walls}`:
## - `taxiways`: each centreline in the frame, `{id, kind, along_runs, fixed, start, end, runway_join, points}`;
## - `pavement`: `{id, kind, along, across, position, half_extents}`, kind taxiway, taxilane, pad, apron or hardstand;
## - `boxes`: the solid list's entries, `{position, half_extents, group, place, part}`;
## - `walls`: the same boxes with what they are part of and their frame rectangle, for the view and the checks;
## - `spots`: by id, `{id, along, nose, out, half_span_room, length_room, bay_of, mouth, node, position, yaw}` -- `nose`
##   is the across line the craft's nose stands on, `out` the across direction its nose points (+1 or -1), `yaw` the
##   craft yaw that points it so, and the rooms the largest half span and hull length that fit (see `fits`);
## - `nodes`: by name, `{along, across, position}`; `edges`: `[from, to, metres]`, both ways implied;
## - `tower`: `{along, across, position, yaw}`, standing on the runway's level, its yaw facing the runway;
## - `hangars` and `revetments`: each as laid, in the frame, for the view to draw its detail from;
## - `hull`: an AABB round everything laid and stood up;
## - `runways`: every runway the base serves, by airfield id ("" for the one it is laid on), in the frame (`_other_runways`);
## - `holds`: by hold node, `{runway, taxiway, along_runs, side}`: which runway the bar holds short of, and on which side;
## - `exits`: each high-speed exit as laid, `{id, runway, from, to, heading, start, join, yaw}`;
## - `terminals`: each as laid, `{id, along, across, height}`.
##
## A BASE MAY SERVE MORE THAN ONE RUNWAY (lane/airport, 2026-09-19: "multiple runways, sometimes that cross one another"):
## `also_runways` names the others by their airfield files, `others` hands their frames in, and each must lie a whole
## number of quarter turns from this one, so it runs along one of the frame's axes. A taxiway may end on any of their
## edges (`<id>.edge`), and gets a hold bar there as it would on this runway's.
##
## `on_ground` false lays it in plan only, with no ground under it asked about: for `Airfield.pads_for`, which works out
## where a level's airports stand BEFORE the ground that flattens them exists (lane/testfield, 2026-09-19). Every other
## caller lays it on the ground and has it refused where the ground is not level.
static func lay(base: Dictionary, frame: Dictionary, others: Dictionary = {}, on_ground: bool = true) -> Dictionary:
	var id: String = base["id"]
	var bearing: float = frame["bearing"]
	var quarters: float = bearing / (PI * 0.5)
	if absf(quarters - round(quarters)) * PI * 0.5 > QUARTER_SLACK:
		return _refuse(id, "its runway's bearing of %.2f degrees is not a quarter turn, and a static box has no rotation" % [rad_to_deg(bearing)])
	var standards: Dictionary = base["standards"]
	var width: float = standards["taxiway_width"]
	var fillet: float = standards["fillet"]
	var out: Dictionary = {"id": id, "name": base["name"], "frame": frame, "standards": standards, "pavement": [],
		"boxes": [], "walls": [], "spots": {}, "nodes": {}, "edges": [], "parked": base["parked"], "taxiways": [],
		"hangars": [], "revetments": [], "holds": {}, "exits": [], "terminals": []}
	var runways: Dictionary = _other_runways(frame, others)
	for other in others:
		if not runways.has(other):
			return _refuse(id, "runway %s lies at no quarter turn to the base's own, so no taxiway can run along it" % other)
	out["runways"] = runways.duplicate()
	(out["runways"] as Dictionary)[""] = {"field": String(frame.get("field", "")), "runs_along": true, "centreline": 0.0,
		"threshold": -float(frame["length"]) * 0.5, "far_end": float(frame["length"]) * 0.5, "width": float(frame["width"])}
	# THE TAXIWAYS, each as a centreline in the frame: `fixed` on one axis, running from `start` to `end` on the other.
	var lines: Array[Dictionary] = []
	for taxiway in base["taxiways"]:
		var along_runs: bool = taxiway["along"] is Array
		var run: Array = taxiway["along"] if along_runs else taxiway["across"]
		var run_axis: String = "along" if along_runs else "across"
		var fixed_axis: String = "across" if along_runs else "along"
		var start: float = _resolve(run[0], frame, run_axis, runways)
		var end: float = _resolve(run[1], frame, run_axis, runways)
		var fixed: float = _resolve(taxiway["across"] if along_runs else taxiway["along"], frame, fixed_axis, runways)
		if is_nan(start) or is_nan(end) or is_nan(fixed):
			return _refuse(id, "taxiway %s names a place on a runway the base does not serve, or on the wrong axis" % taxiway["id"])
		# WHICH RUNWAY IT MEETS, if either end is on a runway's edge: "" for the base's own, an airfield id for another, and
		# NO_JOIN for none. A taxiway can only end square on a runway that runs across its own line.
		var joined: String = _joined_runway(run)
		if joined != NO_JOIN and bool((out["runways"] as Dictionary)[joined]["runs_along"]) == along_runs:
			return _refuse(id, "taxiway %s runs the same way as the runway it ends on" % taxiway["id"])
		var line := {"id": taxiway["id"], "kind": taxiway["kind"], "along_runs": along_runs,
			"fixed": fixed, "start": minf(start, end), "end": maxf(start, end),
			"runway_join": joined != NO_JOIN, "joins": joined, "points": []}
		lines.append(line)
		out["taxiways"].append(line)
		# Its pavement: the centreline, widened, and run on by half a width at each end so a junction is square.
		var half_run: float = (line["end"] - line["start"]) * 0.5 + width * 0.5
		var middle: float = (line["end"] + line["start"]) * 0.5
		if along_runs:
			_pave(out, frame, taxiway["id"], taxiway["kind"], [middle - half_run, middle + half_run],
				[line["fixed"] - width * 0.5, line["fixed"] + width * 0.5])
		else:
			_pave(out, frame, taxiway["id"], taxiway["kind"], [line["fixed"] - width * 0.5, line["fixed"] + width * 0.5],
				[middle - half_run, middle + half_run])
	# WHERE CENTRELINES MEET: a node, and a square pad of pavement round it `fillet` wider on every side, so a turn from
	# one onto the other has somewhere to swing.
	for i in range(lines.size()):
		for j in range(i + 1, lines.size()):
			var a: Dictionary = lines[i]
			var b: Dictionary = lines[j]
			if a["along_runs"] == b["along_runs"]:
				continue
			var runs: Dictionary = a if a["along_runs"] else b
			var crosses: Dictionary = b if a["along_runs"] else a
			var at_along: float = crosses["fixed"]
			var at_across: float = runs["fixed"]
			if at_along < runs["start"] - SAME_NODE or at_along > runs["end"] + SAME_NODE \
					or at_across < crosses["start"] - SAME_NODE or at_across > crosses["end"] + SAME_NODE:
				continue
			var names: Array = [a["id"], b["id"]]
			names.sort()
			var name: String = _node(out, frame, "%s/%s" % names, at_along, at_across)
			(runs["points"] as Array).append([at_along, name])
			(crosses["points"] as Array).append([at_across, name])
	# A PAD IN EACH CORNER A TURN IS MADE THROUGH, at each distinct junction, once: the legs that leave the junction are
	# found from where it lies on each taxiway, and every pair of legs at right angles fills the quarter between them. A
	# straight run through a junction has no fillet; a T fills the two quarters on its stem's side, which is a rectangle,
	# and a crossing all four, which is a square. The first picture had a full square at every junction, and the parallel
	# taxiway grew a 15 m shoulder on its runway side at every link where nothing turns (2026-09-17).
	var legs: Dictionary = {}
	for line in lines:
		for point in line["points"]:
			var at: float = point[0]
			var directions: Array = legs.get(point[1], [])
			if at > float(line["start"]) + SAME_NODE:
				directions.append(Vector2(-1.0, 0.0) if line["along_runs"] else Vector2(0.0, -1.0))
			if at < float(line["end"]) - SAME_NODE:
				directions.append(Vector2(1.0, 0.0) if line["along_runs"] else Vector2(0.0, 1.0))
			legs[point[1]] = directions
	var reach: float = width * 0.5 + fillet
	for name in legs:
		var node: Dictionary = out["nodes"][name]
		var corners := Rect2()
		var any: bool = false
		for first in legs[name]:
			for second in legs[name]:
				if (first as Vector2).x == 0.0 or (second as Vector2).y == 0.0:
					continue
				var quarter := Rect2(Vector2(float(node["along"]), float(node["across"])), Vector2.ZERO).expand(
					Vector2(float(node["along"]), float(node["across"])) + (first + second) * reach)
				corners = quarter if not any else corners.merge(quarter)
				any = true
		if any:
			_pave(out, frame, "pad " + name, "pad", [corners.position.x, corners.end.x], [corners.position.y, corners.end.y])
	# THE RUNWAY JOINS AND THE HOLD BARS, on every taxiway that starts at the runway's edge: a node where it meets the
	# runway's centreline, and one at the hold bar -- the frangibility zone's edge -- which is as far as a taxiing
	# aeroplane comes before it is cleared on.
	# On the base's own runway the centreline is across 0; on another runway, its centreline in the frame.
	var hold: float = standards["hold_bar"]
	for line in lines:
		if not line["runway_join"]:
			continue
		var runway: Dictionary = (out["runways"] as Dictionary)[line["joins"]]
		var centre: float = runway["centreline"]
		var side: float = signf((float(line["start"]) + float(line["end"])) * 0.5 - centre)
		var edge: float = line["start"] if side > 0.0 else line["end"]
		var at := func(value: float) -> Vector2:
			return Vector2(value, line["fixed"]) if line["along_runs"] else Vector2(line["fixed"], value)
		var p: Vector2 = at.call(centre)
		var join: String = _node(out, frame, "%s.runway" % line["id"], p.x, p.y)
		p = at.call(centre + side * hold)
		var held: String = _node(out, frame, "%s.hold" % line["id"], p.x, p.y)
		p = at.call(edge)
		var met: String = _node(out, frame, "%s.edge" % line["id"], p.x, p.y)
		(line["points"] as Array).append([centre + side * hold, held])
		(line["points"] as Array).append([edge, met])
		out["edges"].append([join, met, absf(edge - centre)])
		out["holds"][held] = {"runway": String(runway["field"]), "taxiway": line["id"], "along_runs": line["along_runs"],
			"side": side, "join": join}
		# The join's pad, on the taxiway's side of the edge: the runway's own asphalt is the rest of it.
		var run_span: Array = [minf(edge, edge + side * reach), maxf(edge, edge + side * reach)]
		var fixed_span: Array = [float(line["fixed"]) - reach, float(line["fixed"]) + reach]
		if line["along_runs"]:
			_pave(out, frame, "pad " + met, "pad", run_span, fixed_span)
		else:
			_pave(out, frame, "pad " + met, "pad", fixed_span, run_span)
	# THE HIGH-SPEED EXITS ([AC] 4.8.5, figure 4-19): off a runway's centreline at `exit_angle_degrees` to its landing
	# direction, toward the taxiway `to`, which it joins where the angled line meets it. Paved as one strip turned to its
	# angle -- pavement is drawn, never collided -- so it is the one piece of a base not on the frame's axes. A landing
	# rolled down to taxi speed short of it turns off here rather than taxiing on to a stub at the end.
	for exit in base.get("exits", []):
		var runway: Dictionary = (out["runways"] as Dictionary).get(String(exit.get("runway", "")), {})
		if runway.is_empty():
			return _refuse(id, "exit %s is on a runway the base does not serve" % exit["id"])
		var runs_along: bool = runway["runs_along"]
		var from: float = _resolve(exit["from"], frame, "along" if runs_along else "across", runways)
		var target: Dictionary = {}
		for line in lines:
			if line["id"] == exit["to"] and bool(line["along_runs"]) == runs_along:
				target = line
		if is_nan(from) or target.is_empty():
			return _refuse(id, "exit %s starts at no place on its runway, or its `to` is no taxiway alongside it" % exit["id"])
		var off: float = float(target["fixed"]) - float(runway["centreline"])
		var heading: float = float(exit["heading"])
		var ahead: float = absf(off) / tan(deg_to_rad(float(standards["exit_angle_degrees"])))
		var joins_at: float = from + heading * ahead
		if joins_at < float(target["start"]) - SAME_NODE or joins_at > float(target["end"]) + SAME_NODE:
			return _refuse(id, "exit %s meets taxiway %s at %.0f, past its end" % [exit["id"], exit["to"], joins_at])
		var start2 := Vector2(from, runway["centreline"]) if runs_along else Vector2(runway["centreline"], from)
		var join2 := Vector2(joins_at, target["fixed"]) if runs_along else Vector2(target["fixed"], joins_at)
		var on_runway: String = _node(out, frame, "%s.runway" % exit["id"], start2.x, start2.y)
		var meets: String = _node(out, frame, "%s.join" % exit["id"], join2.x, join2.y)
		(target["points"] as Array).append([joins_at, meets])
		out["edges"].append([on_runway, meets, start2.distance_to(join2)])
		var a: Vector3 = frame_point(frame, start2.x, start2.y)
		var b: Vector3 = frame_point(frame, join2.x, join2.y)
		var yaw: float = yaw_facing(b - a)
		out["exits"].append({"id": exit["id"], "runway": String(runway["field"]), "to": exit["to"], "heading": heading,
			"start": on_runway, "join": meets, "yaw": yaw, "length": a.distance_to(b)})
		var strip: Dictionary = {"id": exit["id"], "kind": "exit", "yaw": yaw,
			"position": (a + b) * 0.5 + Vector3.UP * PAVEMENT_HALF_HEIGHT,
			"half_extents": Vector3(width * 0.5, PAVEMENT_HALF_HEIGHT, a.distance_to(b) * 0.5 + width * 0.5),
			"along": [minf(start2.x, join2.x), maxf(start2.x, join2.x)],
			"across": [minf(start2.y, join2.y), maxf(start2.y, join2.y)]}
		out["pavement"].append(strip)
	# THE APRON CRAFT: the widest craft the aprons and the taxilanes are laid out for, and the half span that spaces the
	# apron's spots and stands every revetment off its taxilane. See this function's doc.
	var apron_half_span: float = half_span_of(Sim.Kind[base["apron_craft"]])
	# THE APRONS, their spots nose-in to the nose line and facing the taxilane they are reached from, a span and the
	# wingtip clearance apart and centred on the apron.
	#
	# AN APRON MAY NAME ITS OWN `craft`: an airport's 747 gates and 737 gates are spaced for each (lane/airport), where a
	# fighter base's one apron is spaced for the widest craft it takes. And it may be `nose_in`: a contact gate, the craft
	# parked facing away from its taxilane, its tail kept `taxilane_obstacle_clearance` off the taxilane's centreline (or
	# off its edge, for a base that cites none). A nose-in spot is only ever arrived at: the autopilot's wheels drive
	# forward, and pushing back is a tug the game has not got yet.
	for apron in base["aprons"]:
		var along_span: Array = [minf(apron["along"][0], apron["along"][1]), maxf(apron["along"][0], apron["along"][1])]
		var across_span: Array = [minf(apron["across"][0], apron["across"][1]), maxf(apron["across"][0], apron["across"][1])]
		_pave(out, frame, apron["id"], "apron", along_span, across_span)
		var count: int = int(apron["spots"])
		var craft: String = apron.get("craft", base["apron_craft"])
		var nose_in: bool = apron.get("nose_in", false)
		var pitch: float = half_span_of(Sim.Kind[craft]) * 2.0 + float(standards["wingtip_to_wingtip"]) + SET_OUT
		if float(count) * pitch > float(along_span[1]) - float(along_span[0]):
			return _refuse(id, "apron %s is %.1f m long, and %d spots for a %s want %.1f m" % [apron["id"],
				float(along_span[1]) - float(along_span[0]), count, craft, float(count) * pitch])
		var spots: Array = []
		for k in range(count):
			spots.append((float(along_span[0]) + float(along_span[1])) * 0.5 + (float(k) - float(count - 1) * 0.5) * pitch)
		var nose: float = apron["nose_line"]
		for k in range(spots.size()):
			var along: float = spots[k]
			var left: float = along - (spots[k - 1] if k > 0 else along_span[0] - (along - along_span[0]))
			var right: float = (spots[k + 1] if k + 1 < spots.size() else along_span[1] + (along_span[1] - along)) - along
			var lane: Dictionary = _taxilane_facing(lines, along, nose)
			if lane.is_empty():
				return _refuse(id, "apron %s's spot at along %.1f faces no taxilane" % [apron["id"], along])
			var spot_id: String = "%s.%d" % [apron["id"], k + 1]
			# ROOM: half a span may reach halfway to the next spot less half the wingtip clearance (the next craft is as
			# wide), or as far past the apron's end; a craft's length may reach the apron's back edge.
			var room_behind: float = absf((across_span[1] if signf(nose - lane["fixed"]) > 0.0 else across_span[0]) - nose)
			if nose_in:
				room_behind = absf(nose - float(lane["fixed"])) - float(standards.get("taxilane_obstacle_clearance", width * 0.5))
			var half_span_room: float = (minf(left, right) - float(standards["wingtip_to_wingtip"])) * 0.5
			if not _spot(out, frame, lane, spot_id, along, nose, half_span_room, room_behind, "", nose_in):
				return {}
			(out["spots"][spot_id] as Dictionary)["craft"] = craft
	# THE REVETMENT BLOCKS: a row of bays open to the taxilane in front, a side wall between each pair and at each end, and
	# one back wall behind them all. The floor from the taxilane's edge to the back wall is hardstand.
	var wall: float = standards.get("revetment_wall_thickness", 0.0)
	var wall_high: float = standards.get("revetment_wall_height", 0.0)
	for block in base["revetments"]:
		var bays: int = int(block["bays"])
		var bay_width: float = block["bay_width"]
		var bay_depth: float = block["bay_depth"]
		var first: float = block["along"]
		var length: float = float(bays) * bay_width + float(bays + 1) * wall
		var lane: Dictionary = _taxilane_named(lines, block["taxilane"], first + length * 0.5)
		if lane.is_empty():
			return _refuse(id, "revetment block %s opens onto no taxilane" % [block["id"]])
		# ITS FRONT, on the far side of its taxilane from the runway, the apron craft's wingtip clearance off the
		# taxilane's centreline: a wall any nearer is one an airliner taxiing past would strike.
		var out_sign: float = signf(float(lane["fixed"]))
		var front: float = float(lane["fixed"]) + out_sign * (apron_half_span + float(standards["wingtip_to_taxilane"]) + SET_OUT)
		var lane_edge: float = float(lane["fixed"]) + out_sign * width * 0.5
		var back: float = front + out_sign * bay_depth
		_pave(out, frame, "%s hardstand" % block["id"], "hardstand", [first, first + length],
			[minf(lane_edge, back), maxf(lane_edge, back)])
		out["revetments"].append({"id": block["id"], "first": first, "length": length, "front": front, "back": back,
			"out_sign": out_sign, "bays": bays, "bay_width": bay_width, "wall": wall, "height": wall_high})
		for k in range(bays + 1):
			var at: float = first + wall * 0.5 + float(k) * (bay_width + wall)
			_wall(out, frame, block["id"], "revetment", [at - wall * 0.5, at + wall * 0.5],
				[minf(front, back + out_sign * wall), maxf(front, back + out_sign * wall)], [0.0, wall_high])
		_wall(out, frame, block["id"], "revetment", [first, first + length],
			[minf(back, back + out_sign * wall), maxf(back, back + out_sign * wall)], [0.0, wall_high])
		for k in range(bays):
			var along: float = first + wall + float(k) * (bay_width + wall) + bay_width * 0.5
			# ROOM: a wingtip and the tail keep the wall clearance from the walls round them.
			var clearance: float = standards["wall_clearance"]
			if not _spot(out, frame, lane, "%s.%d" % [block["id"], k + 1], along, front, bay_width * 0.5 - clearance,
					bay_depth - clearance, block["id"]):
				return {}
	# THE HANGARS: two side walls as thick as the door leaves over, a back wall as thick, a roof on top at the clear
	# height and a header over the door where the door is lower than the roof. The doors face the runway's side.
	for hangar in base["hangars"]:
		var type: Dictionary = standards["hangar_types"][hangar["type"]]
		var hangar_width: float = type["width"]
		var depth: float = type["depth"]
		var clear: float = type["clear_height"]
		var door: float = hangar["door"]
		var inward: float = signf(door)
		var post: float = (hangar_width - float(type["door_width"])) * 0.5
		var skin: float = maxf(post, 0.3)
		var along: float = hangar["along"]
		var across_span: Array = [minf(door, door + inward * depth), maxf(door, door + inward * depth)]
		out["hangars"].append({"id": hangar["id"], "type": hangar["type"], "along": along, "door": door, "inward": inward,
			"width": hangar_width, "depth": depth, "clear_height": clear, "door_width": type["door_width"],
			"door_height": type["door_height"], "roof": type["roof"], "skin": skin})
		for side in [-1.0, 1.0]:
			var at: float = along + side * (hangar_width * 0.5 - skin * 0.5)
			_wall(out, frame, hangar["id"], "hangar", [at - skin * 0.5, at + skin * 0.5], across_span, [0.0, clear])
		var back: float = door + inward * depth
		_wall(out, frame, hangar["id"], "hangar", [along - hangar_width * 0.5, along + hangar_width * 0.5],
			[minf(back, back - inward * skin), maxf(back, back - inward * skin)], [0.0, clear])
		_wall(out, frame, hangar["id"], "hangar", [along - hangar_width * 0.5, along + hangar_width * 0.5], across_span,
			[clear, clear + skin])
		if clear - float(type["door_height"]) > 0.01:
			_wall(out, frame, hangar["id"], "hangar", [along - hangar_width * 0.5, along + hangar_width * 0.5],
				[minf(door, door + inward * skin), maxf(door, door + inward * skin)], [float(type["door_height"]), clear])
	# EACH TAXIWAY'S NODES JOINED TO THEIR NEIGHBOURS along it: the graph is the taxiways, and nothing else.
	for line in lines:
		var points: Array = line["points"]
		points.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		for k in range(points.size() - 1):
			if points[k][1] != points[k + 1][1]:
				out["edges"].append([points[k][1], points[k + 1][1], absf(float(points[k + 1][0]) - float(points[k][0]))])
	# THE TOWER, on the runway's level, its first seat facing the runway.
	var tower: Dictionary = base["tower"]
	var tower_across: float = tower["across"]
	out["tower"] = {"along": tower["along"], "across": tower_across,
		"position": frame_point(frame, tower["along"], tower_across),
		"yaw": yaw_facing((frame["across"] as Vector3) * -signf(tower_across)), "built": bool(tower.get("built", false))}
	# A TOWER THE BASE BUILDS ITSELF, where no crewed tower stands (only the island's first runway has one, Terrain.spawns):
	# a square shaft to the cab's floor and the cab on top, `tower_height` to the cab's roof, both solid.
	if out["tower"]["built"]:
		var cab: float = standards["tower_cab"]
		var high: float = standards["tower_height"]
		var shaft: float = cab * 0.5
		var t_along: float = tower["along"]
		_wall(out, frame, "tower", "tower", [t_along - shaft * 0.5, t_along + shaft * 0.5],
			[tower_across - shaft * 0.5, tower_across + shaft * 0.5], [0.0, high - cab * 0.6])
		_wall(out, frame, "tower", "tower_cab", [t_along - cab * 0.5, t_along + cab * 0.5],
			[tower_across - cab * 0.5, tower_across + cab * 0.5], [high - cab * 0.6, high])
	# THE TERMINALS: one long solid block each, its airside face toward the runway; the view draws its glazing.
	for terminal in base.get("terminals", []):
		var t_along: Array = [minf(terminal["along"][0], terminal["along"][1]), maxf(terminal["along"][0], terminal["along"][1])]
		var t_across: Array = [minf(terminal["across"][0], terminal["across"][1]), maxf(terminal["across"][0], terminal["across"][1])]
		_wall(out, frame, terminal["id"], "terminal", t_along, t_across, [0.0, float(terminal["height"])])
		out["terminals"].append({"id": terminal["id"], "along": t_along, "across": t_across, "height": float(terminal["height"]),
			"airside": -signf(float(t_across[0]) + float(t_across[1]))})
	# EVERY PARKED CRAFT ON A SPOT THE BASE HAS.
	for parked in base["parked"]:
		if not (out["spots"] as Dictionary).has(parked["spot"]):
			return _refuse(id, "a parked %s names spot %s, which the base does not have" % [parked["kind"], parked["spot"]])
	# ITS HULL, everything it lays on the ground and stands up, for the generator to keep clear (`Terrain.clearances`). A
	# piece turned by a yaw (an exit) counts by the box round it turned.
	var hull := AABB(out["tower"]["position"], Vector3.ZERO)
	for piece in (out["pavement"] as Array) + (out["boxes"] as Array):
		var half: Vector3 = piece["half_extents"]
		if piece.has("yaw"):
			var turned := Basis(Vector3.UP, float(piece["yaw"]))
			half = (turned.x * half.x).abs() + (turned.y * half.y).abs() + (turned.z * half.z).abs()
		hull = hull.merge(AABB((piece["position"] as Vector3) - half, half * 2.0))
	out["hull"] = hull
	# WHAT IT KEEPS CLEAR of rock, towns and woods (`Terrain.clearances`): every slab and every wall, each grown by the
	# taxiway obstacle clearance -- not the hull. An airport laid round two crossing runways is an L, and its hull took in the
	# empty corner of the L, where the mountain ring's north-east flank stands: kept clear as one box, it cut 2,292 of the
	# island's 332,929 rock samples down by as much as 446 m (tests/airport.gd, lane/airport 2026-09-19). A junction's pads
	# lie inside their taxiways' growth and are left out.
	var grow: float = standards["taxiway_obstacle_clearance"]
	var keep: Array[AABB] = []
	for piece in (out["pavement"] as Array) + (out["boxes"] as Array):
		if String(piece.get("kind", "")) == "pad":
			continue
		var half: Vector3 = piece["half_extents"]
		if piece.has("yaw"):
			var turned := Basis(Vector3.UP, float(piece["yaw"]))
			half = (turned.x * half.x).abs() + (turned.y * half.y).abs() + (turned.z * half.z).abs()
		keep.append(AABB((piece["position"] as Vector3) - half, half * 2.0).grow(grow))
	out["keep_clear"] = keep
	# AND THE GROUND UNDER IT ALL, level with the runway.
	var uneven: String = _uneven_ground(out, frame) if on_ground else ""
	if uneven != "":
		return _refuse(id, uneven)
	return out


## THE OTHER RUNWAYS A BASE SERVES, IN ITS FRAME, by airfield id: `{field, runs_along, centreline, threshold, far_end,
## width}` -- which of the frame's axes it runs along, where its centreline lies on the other, and where its ends are on its
## own. One lying at no quarter turn to the frame is left out, and `lay` refuses the base by name.
static func _other_runways(frame: Dictionary, others: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var centre: Vector3 = frame["centre"]
	var along: Vector3 = frame["along"]
	var across: Vector3 = frame["across"]
	for id in others:
		var other: Dictionary = others[id]
		var runs: Vector3 = other["along"]
		var runs_along: bool = absf(runs.dot(along)) > 1.0 - QUARTER_SLACK
		if not runs_along and absf(runs.dot(across)) <= 1.0 - QUARTER_SLACK:
			continue
		var own: Vector3 = along if runs_along else across
		var side: Vector3 = across if runs_along else along
		out[id] = {"field": id, "runs_along": runs_along,
			"centreline": ((other["centre"] as Vector3) - centre).dot(side),
			"threshold": ((other["threshold"] as Vector3) - centre).dot(own),
			"far_end": ((other["far_end"] as Vector3) - centre).dot(own),
			"width": float(other["width"])}
	return out


## WHICH RUNWAY A TAXIWAY'S RUN ENDS ON: "" for the base's own ("runway_edge"), an airfield id for another's
## ("<id>.edge"), or NO_JOIN.
const NO_JOIN: String = "-"


static func _joined_runway(run: Array) -> String:
	for value in run:
		if not (value is String):
			continue
		var text: String = (value as String).trim_prefix("-")
		if text.begins_with("runway_edge"):
			return ""
		if text.contains(".") and text.substr(text.get_slice(".", 0).length() + 1).begins_with("edge"):
			return text.get_slice(".", 0)
	return NO_JOIN


## A POINT OF THE FRAME, in the world, on the runway's level.
static func frame_point(frame: Dictionary, along: float, across: float) -> Vector3:
	return (frame["centre"] as Vector3) + (frame["along"] as Vector3) * along + (frame["across"] as Vector3) * across


## A RECTANGLE OF THE FRAME as a world box: its middle, and its half extents turned onto the world's axes. Exact for a
## quarter-turn bearing, which `lay` has already insisted on.
static func frame_box(frame: Dictionary, along: Array, across: Array, up: Array) -> Dictionary:
	var middle: Vector3 = frame_point(frame, (along[0] + along[1]) * 0.5, (across[0] + across[1]) * 0.5)
	var along_axis: Vector3 = (frame["along"] as Vector3).abs()
	var across_axis: Vector3 = (frame["across"] as Vector3).abs()
	var half: Vector3 = along_axis * (along[1] - along[0]) * 0.5 + across_axis * (across[1] - across[0]) * 0.5
	half = Vector3(snappedf(half.x, 0.0001), 0.0, snappedf(half.z, 0.0001))
	half.y = (up[1] - up[0]) * 0.5
	middle.y += (up[0] + up[1]) * 0.5
	return {"position": middle, "half_extents": half}


static func _pave(out: Dictionary, frame: Dictionary, id: String, kind: String, along: Array, across: Array) -> void:
	var box: Dictionary = frame_box(frame, along, across, [-PAVEMENT_HALF_HEIGHT, PAVEMENT_HALF_HEIGHT])
	box["position"] = (box["position"] as Vector3) + Vector3.UP * PAVEMENT_HALF_HEIGHT
	box.merge({"id": id, "kind": kind, "along": along, "across": across})
	out["pavement"].append(box)


static func _wall(out: Dictionary, frame: Dictionary, id: String, part: String, along: Array, across: Array,
		up: Array) -> void:
	var box: Dictionary = frame_box(frame, along, across, up)
	box.merge({"group": Terrain.Group.AIRBASE, "place": out["id"], "part": part})
	out["boxes"].append(box)
	var wall: Dictionary = box.duplicate()
	wall.merge({"of": id, "along": along, "across": across, "up": up})
	out["walls"].append(wall)


## A ROUTE NODE, named, unless one already stands within SAME_NODE of it -- then that one's name.
static func _node(out: Dictionary, frame: Dictionary, name: String, along: float, across: float) -> String:
	for existing in out["nodes"]:
		var node: Dictionary = out["nodes"][existing]
		if absf(float(node["along"]) - along) < SAME_NODE and absf(float(node["across"]) - across) < SAME_NODE:
			return existing
	out["nodes"][name] = {"along": along, "across": across, "position": frame_point(frame, along, across)}
	return name


## THE TAXILANE A SPOT OR BAY AT `along` WITH ITS NOSE ON `across` IS REACHED FROM: the nearest along-running taxilane
## whose run covers it, on the runway's side of the nose line. {} for none.
static func _taxilane_facing(lines: Array[Dictionary], along: float, across: float) -> Dictionary:
	var best: Dictionary = {}
	for line in lines:
		if line["kind"] != "taxilane" or not line["along_runs"]:
			continue
		if along < float(line["start"]) or along > float(line["end"]):
			continue
		if absf(float(line["fixed"])) >= absf(across) or signf(float(line["fixed"])) != signf(across):
			continue
		if best.is_empty() or absf(across - float(line["fixed"])) < absf(across - float(best["fixed"])):
			best = line
	return best


## THE ALONG-RUNNING TAXILANE CALLED `lane_id` WHOSE RUN COVERS `along`: what a revetment block opens onto. {} for none.
static func _taxilane_named(lines: Array[Dictionary], lane_id: String, along: float) -> Dictionary:
	for line in lines:
		if line["id"] == lane_id and line["kind"] == "taxilane" and line["along_runs"] and float(line["fixed"]) != 0.0 \
				and along >= float(line["start"]) and along <= float(line["end"]):
			return line
	return {}


## A PARKING SPOT, its mouth on its taxilane joined into the graph, and an edge from the mouth to the spot itself.
static func _spot(out: Dictionary, frame: Dictionary, lane: Dictionary, spot_id: String, along: float, nose: float,
		half_span_room: float, length_room: float, bay_of: String, nose_in: bool = false) -> bool:
	if (out["spots"] as Dictionary).has(spot_id):
		_refuse(out["id"], "spot %s is laid twice" % spot_id)
		return false
	# Facing its taxilane, or, nose in, away from it.
	var out_sign: float = -signf(nose - float(lane["fixed"])) * (-1.0 if nose_in else 1.0)
	var mouth: String = _node(out, frame, "%s.mouth" % spot_id, along, lane["fixed"])
	(lane["points"] as Array).append([along, mouth])
	var standing: String = _node(out, frame, spot_id, along, nose)
	out["edges"].append([mouth, standing, absf(nose - float(lane["fixed"]))])
	out["spots"][spot_id] = {"id": spot_id, "along": along, "nose": nose, "out": out_sign,
		"half_span_room": half_span_room, "length_room": length_room, "bay_of": bay_of, "mouth": mouth, "node": standing,
		"position": frame_point(frame, along, nose), "yaw": yaw_facing((frame["across"] as Vector3) * out_sign),
		"nose_in": nose_in}
	return true


## THE SHORTEST TAXI ROUTE over a laid base's edges, by Dijkstra, as node names from `from` to `to`; [] if there is
## none. The same search tests/airbase_taxi.gd drives a fighter along by keys; an autopilot taxis it too
## (`AirportTraffic.depart`, lane/pattern).
static func route(base: Dictionary, from: String, to: String) -> Array:
	var near: Dictionary = {}
	for edge in base["edges"]:
		for pair in [[edge[0], edge[1]], [edge[1], edge[0]]]:
			if not near.has(pair[0]):
				near[pair[0]] = []
			(near[pair[0]] as Array).append([pair[1], float(edge[2])])
	var distance: Dictionary = {from: 0.0}
	var came: Dictionary = {}
	var open: Array = [from]
	while not open.is_empty():
		open.sort_custom(func(a: String, b: String) -> bool: return float(distance[a]) < float(distance[b]))
		var at: String = open.pop_front()
		if at == to:
			break
		for step in near.get(at, []):
			var through: float = float(distance[at]) + float(step[1])
			if through < float(distance.get(step[0], INF)):
				distance[step[0]] = through
				came[step[0]] = at
				if not open.has(step[0]):
					open.append(step[0])
	if not distance.has(to):
		return []
	var path: Array = [to]
	while path[0] != from:
		path.push_front(came[path[0]])
	return path


## WHETHER A KIND FITS A SPOT: its drawn half span within the spot's half-span room and its hull's length within its
## length room, asked of the simulation's shape table (`Sim.geometry_of`), never typed here.
static func fits(spot: Dictionary, kind: int) -> bool:
	var geometry: Dictionary = Sim.geometry_of(kind)
	if geometry.is_empty():
		return false
	var extents: Vector3 = geometry.get("extents", Vector3.ONE)
	return half_span_of(kind) <= float(spot["half_span_room"]) and extents.z * 2.0 <= float(spot["length_room"])


## HALF A KIND'S WIDTH ACROSS: its drawn half span, or its hull's half-width where that is wider (a craft with no wing).
static func half_span_of(kind: int) -> float:
	var geometry: Dictionary = Sim.geometry_of(kind)
	return maxf(float(geometry.get("span", 0.0)), (geometry.get("extents", Vector3.ZERO) as Vector3).x)


## WHERE A CRAFT OF A KIND STANDS ON A SPOT: its nose on the nose line and its middle half a hull behind it, on the
## runway's level (a caller adds its own height over the ground).
static func standing_on_spot(laid: Dictionary, spot: Dictionary, kind: int) -> Vector3:
	var extents: Vector3 = Sim.geometry_of(kind).get("extents", Vector3.ONE)
	return frame_point(laid["frame"], spot["along"], float(spot["nose"]) - float(spot["out"]) * extents.z)


## THE YAW THAT POINTS A CRAFT'S NOSE ALONG `direction`: the inverse of `Terrain.nose_from_yaw`, whose nose is -Z turned
## by the yaw.
static func yaw_facing(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## WHERE THE GROUND UNDER A LAID BASE IS NOT LEVEL WITH ITS RUNWAY, in words, or "": every corner of its pavement and its
## walls, and the tower's foot.
static func _uneven_ground(laid: Dictionary, frame: Dictionary) -> String:
	var level: float = (frame["centre"] as Vector3).y
	var feet: Array = []
	for piece in (laid["pavement"] as Array) + (laid["walls"] as Array):
		for a in piece["along"]:
			for c in piece["across"]:
				feet.append([frame_point(frame, a, c), "%s at along %.0f, across %.0f" % [piece.get("id", piece.get("of")), a, c]])
	feet.append([laid["tower"]["position"], "the tower"])
	for foot in feet:
		# THE LAND, not the mountains: they are cut back from the base's own keep-out (Terrain.land_height).
		var ground: float = Terrain.land_height(foot[0])
		if absf(ground - level) > LEVEL_SLACK:
			return "the ground under %s is %.1f m from the runway's level" % [foot[1], ground - level]
	return ""
