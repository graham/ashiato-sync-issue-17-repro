extends RefCounted
class_name Airfield
## AN AIRFIELD: a runway, which end of it is in use, and which side each end's traffic pattern lies on. Read from one
## file, like everything else here that is content.
##
## Asked for on 2026-09-19 with the traffic pattern ("usually entering a traffic pattern either on the right or left"),
## and the side is a fact about a RUNWAY END, not about an airport or an aeroplane: charts publish right-hand traffic
## as "RP" and the runway numbers it applies to ([AIM] 4-3-3 b; `research/traffic_pattern.md`). So it is data here,
## beside the runway it belongs to, and nothing that flies has a side of its own.
##
## CONTENT IS A FOLDER SCANNED AT BOOT (building_a_game_here.md, rule 7): `res://world/airfields/<id>/airfield.json`, the
## folder name is the id, `_` folders are skipped, and a file that cannot be read refuses itself in words.
##
## A FILE EITHER NAMES A RUNWAY THE WORLD ALREADY HAS (`"runway": 0`, an index into `Terrain.runways()`) OR LAYS A NEW
## ONE (`"runway": {"centre": [...], "bearing_degrees": ...}`). The island's first strip is the first kind: its
## numbers stay `Terrain`'s RUNWAY_* constants, one number in one place. A new one takes the island's length and width
## unless it gives its own (`length_m`, `width_m`: an airliner's runway is 3,500 m, lane/airport), and gives where it is
## and which way it lies -- the same yaw `Terrain.runway_frame` takes, so 90 lies along x
## with its threshold at the east end. `Terrain.runways()` adds every new one on its world after the world's own, so
## its paint, its lights and the clearance the scenery and the mountains keep off its approaches all follow from the
## loops that already draw and clear every runway, and runway 0 is still the island's.

const FOLDER: String = "res://world/airfields"
const SIDES := {"left": -1.0, "right": 1.0}
const ENDS: Array[String] = ["threshold", "far_end"]
const WORLDS: Array[String] = ["island", "generated"]
## A FILE'S `world` MAY ALSO NAME A LEVEL (lane/testfield, 2026-09-19): `"world": "testfield"` lays the runway on that level
## only, where "generated" lays it on every level on the generated ground. A level with files of its own takes only its own
## (`world_here`), and its ground is handed a PAD for each airport they make (`pads_for`), so the ground makes room for the
## runway where the file says rather than the runway being put where the ground happens to be flat. Checked against the
## levels folder, so a misspelt level is a refusal and not a runway nobody ever sees.
const LEVELS_FOLDER: String = "res://levels"
## A LEVEL'S AIRPORT, AS THE GROUND IS ASKED TO FLATTEN IT: each runway's pavement, grown by its object free area (or these
## when it names no protection), and runways whose grown boxes come within AIRPORT_JOIN of each other are one airport on
## one level. The pad blends back to the ground over PAD_MARGIN, and each runway end's approach is kept clear to 34:1 for
## FINAL_LENGTH (10 NM) and FINAL_HALF_WIDTH either side, the half-width lane/airport cleared its finals to.
const OFA_HALF_DEFAULT: float = 150.0
const OFA_BEYOND_DEFAULT: float = 300.0
const AIRPORT_JOIN: float = 1500.0
const PAD_MARGIN: int = 800
const FINAL_LENGTH: int = 18520
const FINAL_HALF_WIDTH: int = 600
## WHAT A RUNWAY THAT NAMES ITS OWN PROTECTION KEEPS CLEAR, metres (`Terrain._clearances`): the runway object free area
## either side of its centreline and past each end, then the runway protection zone beyond it, as wide as its outer end
## (FAA AC 150/5300-13B, table G-11 and paragraph 3.13). A runway without it keeps the island's square, 0.9 of its length
## each way round each end: at 3,500 m that square is 6.3 km across, and it would have cut the northern ring away
## (lane/airport, 2026-09-19).
const PROTECTION: Array[String] = ["ofa_half_width", "ofa_beyond_end", "rpz_from_end", "rpz_length", "rpz_outer_half"]

## Why the last file refused was refused, in its warning's words, for a test.
static var last_refusal: String = ""
static var _read: Array[Dictionary] = []
static var _read_ready: bool = false
## HELD WHILE THE FOLDER IS READ: `Terrain.runways()` asks this, and the island's mountains are first built on the mist's
## worker, whose keep-outs walk the runways (see `Sim.geometry_of`), so the first read may come from either thread.
static var _reading := Mutex.new()


## EVERY AIRFIELD THE GAME HAS, read and checked for shape, in id order. Read once.
static func catalogue() -> Array[Dictionary]:
	_reading.lock()
	if not _read_ready:
		var read: Array[Dictionary] = []
		if DirAccess.dir_exists_absolute(FOLDER):
			var ids: PackedStringArray = DirAccess.get_directories_at(FOLDER)
			ids.sort()
			for id in ids:
				if id.begins_with("_"):
					continue
				var field: Dictionary = read_field(FOLDER.path_join(id))
				if not field.is_empty():
					read.append(field)
		_read = read
		_read_ready = true
	_reading.unlock()
	return _read


## ONE FILE, READ AND CHECKED FOR SHAPE, or {} with a warning. Public so a test can hand it a broken one.
static func read_field(path: String) -> Dictionary:
	var id: String = path.get_file()
	var file := FileAccess.open(path.path_join("airfield.json"), FileAccess.READ)
	if file == null:
		return _refuse(id, "there is no airfield.json")
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return _refuse(id, "airfield.json is not a JSON object (line %d: %s)" % [json.get_error_line(),
			json.get_error_message()])
	var data: Dictionary = json.data
	var world: String = String(data.get("world", ""))
	if not WORLDS.has(world) and not FileAccess.file_exists(LEVELS_FOLDER.path_join(world).path_join("level.json")):
		return _refuse(id, "`world` is not one of %s, nor a level in %s" % [", ".join(WORLDS), LEVELS_FOLDER])
	var runway: Variant = data.get("runway")
	if runway is float or runway is int:
		if int(runway) < 0:
			return _refuse(id, "`runway` is a negative index")
	elif runway is Dictionary:
		var centre: Variant = (runway as Dictionary).get("centre")
		if not (centre is Array and (centre as Array).size() == 3) \
				or not ((runway as Dictionary).get("bearing_degrees") is float):
			return _refuse(id, "a new `runway` needs `centre` [x, y, z] and `bearing_degrees`")
		for key in ["length_m", "width_m"]:
			var size: Variant = (runway as Dictionary).get(key, 1.0)
			if not (size is float or size is int) or float(size) <= 0.0:
				return _refuse(id, "`runway.%s` is not a positive number of metres" % key)
		var keep: Variant = (runway as Dictionary).get("protection", {})
		if not (keep is Dictionary):
			return _refuse(id, "`runway.protection` is not an object")
		for key in (keep as Dictionary):
			if not PROTECTION.has(key) or not ((keep as Dictionary)[key] is float or (keep as Dictionary)[key] is int):
				return _refuse(id, "`runway.protection.%s` is not one of %s with a number" % [key, ", ".join(PROTECTION)])
		if not (keep as Dictionary).is_empty() and (keep as Dictionary).size() != PROTECTION.size():
			return _refuse(id, "`runway.protection` needs all of %s" % ", ".join(PROTECTION))
	else:
		return _refuse(id, "`runway` is neither an index nor a new runway")
	var ends: Variant = data.get("ends")
	if not (ends is Dictionary):
		return _refuse(id, "there are no `ends`")
	for end in ENDS:
		var side: String = String(((ends as Dictionary).get(end, {}) as Dictionary).get("pattern", ""))
		if not SIDES.has(side):
			return _refuse(id, "the %s end's `pattern` is not left or right" % end)
	if not ENDS.has(String(data.get("in_use", ""))):
		return _refuse(id, "`in_use` is not threshold or far_end")
	data["id"] = id
	return data


static func _refuse(id: String, why: String) -> Dictionary:
	last_refusal = why
	push_warning("[airfield] %s: %s; it is left out" % [id, why])
	return {}


## THE NEW RUNWAYS THE FILES LAY ON A WORLD ("island" or "generated"), as frames, in id order: what `Terrain.runways()`
## adds after the world's own.
static func new_runways(world: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for field in catalogue():
		if String(field["world"]) != world or not (field["runway"] is Dictionary):
			continue
		out.append(_frame_of(field))
	return out


static func _frame_of(field: Dictionary) -> Dictionary:
	var runway: Dictionary = field["runway"]
	var c: Array = runway["centre"]
	var centre := Vector3(float(c[0]), float(c[1]), float(c[2]))
	# ON A LEVEL'S OWN GROUND THE RUNWAY STANDS AT ITS PAD'S LEVEL, which the ground found: the file's y would be a second
	# number for the same height. The LAND's, not `ground_height`, which asks the level's mountains: they are made from the
	# air bases' keep-outs, and the air bases are laid on these frames, so asking the rock here laid every base twice.
	if not WORLDS.has(String(field["world"])) and Terrain.standing_on() != null:
		centre.y = Terrain.land_height(centre)
	var frame: Dictionary = Terrain.runway_frame(centre,
		deg_to_rad(float(runway["bearing_degrees"])), float(runway.get("length_m", Terrain.RUNWAY_LENGTH)),
		float(runway.get("width_m", Terrain.RUNWAY_WIDTH)))
	frame["field"] = String(field["id"])
	if not (runway.get("protection", {}) as Dictionary).is_empty():
		frame["protection"] = runway["protection"]
	return frame


## EVERY AIRFIELD ON THE WORLD THE TERRAIN STANDS ON NOW, each with its runway `frame` and that runway's `index` in
## `Terrain.runways()`. A file naming a runway this world has not got is left out.
static func here() -> Array[Dictionary]:
	var world: String = world_here()
	var runways: Array[Dictionary] = Terrain.runways()
	var out: Array[Dictionary] = []
	for field in catalogue():
		if String(field["world"]) != world:
			continue
		var frame: Dictionary = {}
		var index: int = -1
		if field["runway"] is Dictionary:
			frame = _frame_of(field)
			for i in range(runways.size()):
				if (runways[i]["centre"] as Vector3).distance_to(frame["centre"]) < 1.0:
					index = i
		else:
			index = int(field["runway"])
			if index < runways.size():
				frame = runways[index]
		if index < 0 or frame.is_empty():
			_refuse(String(field["id"]), "this world has no runway %s" % str(field["runway"]))
			continue
		var laid: Dictionary = field.duplicate()
		laid["frame"] = frame
		laid["index"] = index
		out.append(laid)
	return out


## THE AIRFIELD CALLED `id` on this world, or {}.
static func named(id: String) -> Dictionary:
	for field in here():
		if String(field["id"]) == id:
			return field
	return {}


## THE PATTERN SIDE OF ONE END, -1 left and +1 right.
static func side_of(field: Dictionary, end: String) -> float:
	return float(SIDES[String(((field["ends"] as Dictionary)[end] as Dictionary)["pattern"])])


## THE TRAFFIC PATTERN `kind` FLIES to land on `field` from `end` (the one in use unless given), sized from what the
## simulation says the kind does: its stall and cruise (`handling`), its autopilot's bank (`turn_radii`) and its mass.
## `turn` is how much of a coordinated turn the kind gets from a bank (`TrafficPattern.turn`), which whoever flies it
## measures: 1 is the textbook's.
static func pattern_for(field: Dictionary, kind: int, end: String = "", turn: float = 1.0) -> TrafficPattern:
	var which: String = end if end != "" else String(field["in_use"])
	var numbers: Dictionary = numbers_of(kind)
	numbers["turn"] = turn
	return TrafficPattern.make(field["frame"], which == "far_end", side_of(field, which), numbers)


## WHAT A KIND FLIES A PATTERN ON, asked of the library: `stall`, `cruise`, `bank`, `mass`.
static func numbers_of(kind: int) -> Dictionary:
	var h: Dictionary = Sim.handling_of(kind)
	var bank: float = TrafficPattern.BANK
	if Sim.server != null:
		for row in Sim.server.turn_radii():
			if int((row as Dictionary)["kind"]) == kind:
				bank = float((row as Dictionary)["bank"])
	return {"stall": float(h.get("stall_speed", 30.0)), "cruise": float(h.get("cruise", 50.0)), "bank": bank,
		"mass": float(Sim.geometry_of(kind).get("mass", 1000.0))}


## WHICH FILES THE WORLD STANDING NOW TAKES: the level's own id when any file names it, else "island" or "generated".
static func world_here() -> String:
	var level: String = Terrain.level_standing_on()
	if level != "" and level_has_its_own(level):
		return level
	return "island" if Terrain.standing_on() == null else "generated"


## Whether any file names this level as its world.
static func level_has_its_own(level: String) -> bool:
	for field in catalogue():
		if String(field["world"]) == level:
			return true
	return false


## THE PADS A LEVEL'S GROUND IS HANDED, as `GroundField.configure` takes them (`ground_core.hpp`, `Pad`): one per airport
## its own files make, each the rectangle round its runways' grown boxes and a funnel off every runway end, outward along
## the runway. [] for a level with no files of its own. A runway that is not a quarter turn is left out with a warning,
## since a funnel runs along an axis.
static func pads_for(level: String) -> Array[Dictionary]:
	var boxes: Array[Rect2] = []
	var ends: Array[Array] = []
	for field in catalogue():
		if String(field["world"]) != level or not (field["runway"] is Dictionary):
			continue
		var frame: Dictionary = _frame_of(field)
		var along: Vector3 = frame["along"]
		var dir: int = _axis_of(along)
		if dir < 0:
			_refuse(String(field["id"]), "its runway is not a quarter turn, so the ground cannot clear its approaches")
			continue
		var keep: Dictionary = (field["runway"] as Dictionary).get("protection", {})
		var beyond: float = float(frame["length"]) * 0.5 + float(keep.get("ofa_beyond_end", OFA_BEYOND_DEFAULT))
		var half_wide: float = float(keep.get("ofa_half_width", OFA_HALF_DEFAULT))
		var centre: Vector3 = frame["centre"]
		var across: Vector3 = frame["across"]
		var reach := Vector2(absf(along.x) * beyond + absf(across.x) * half_wide,
			absf(along.z) * beyond + absf(across.z) * half_wide)
		boxes.append(Rect2(Vector2(centre.x, centre.z) - reach, reach * 2.0))
		var threshold: Vector3 = frame["threshold"]
		var far_end: Vector3 = frame["far_end"]
		ends.append([[roundi(threshold.x), roundi(threshold.z), _axis_of(-along), FINAL_LENGTH, FINAL_HALF_WIDTH],
			[roundi(far_end.x), roundi(far_end.z), dir, FINAL_LENGTH, FINAL_HALF_WIDTH]])
	# AND EVERY AIR BASE LAID ROUND THEM, by its hull: an apron, a terminal or a hangar stands off the runway's own box --
	# the air base's hangars 560 m from its centreline -- and stood on an unflattened hillside (lane/testfield, S3).
	var frames: Dictionary = {}
	for field in catalogue():
		if String(field["world"]) == level and field["runway"] is Dictionary:
			frames[String(field["id"])] = _frame_of(field)
	for base in AirbasePlan.catalogue():
		if not (base["runway"] is String) or not frames.has(String(base["runway"])):
			continue
		var others: Dictionary = {}
		for other in base.get("also_runways", []):
			if frames.has(String(other)):
				others[String(other)] = frames[String(other)]
		var laid: Dictionary = AirbasePlan.lay(base, frames[String(base["runway"])], others, false)
		if laid.is_empty():
			continue
		var hull: AABB = laid["hull"]
		boxes.append(Rect2(Vector2(hull.position.x, hull.position.z), Vector2(hull.size.x, hull.size.z)))
		ends.append([])
	# ONE AIRPORT PER CLUSTER: a runway joins the first airport whose box, grown by AIRPORT_JOIN, it touches; a runway that
	# touches two joins them. Files are read in id order, so every peer groups them the same.
	var airports: Array[Dictionary] = []
	for k in range(boxes.size()):
		var joined: Array[int] = []
		for a in range(airports.size()):
			if (airports[a]["box"] as Rect2).grow(AIRPORT_JOIN).intersects(boxes[k]):
				joined.append(a)
		var airport: Dictionary = {"box": boxes[k], "funnels": ends[k].duplicate()}
		for a in range(joined.size() - 1, -1, -1):
			var other: Dictionary = airports[joined[a]]
			airport["box"] = (airport["box"] as Rect2).merge(other["box"])
			(airport["funnels"] as Array).append_array(other["funnels"])
			airports.remove_at(joined[a])
		airports.append(airport)
	var out: Array[Dictionary] = []
	for airport in airports:
		var box: Rect2 = airport["box"]
		out.append({"rect": [floori(box.position.x), floori(box.position.y), ceili(box.end.x), ceili(box.end.y)],
			"margin": PAD_MARGIN, "funnels": airport["funnels"]})
	return out


## Which axis a flat unit vector lies along, within AirbasePlan's own slack for a quarter turn: 0 is +x, 1 is +z, 2 is -x, 3 is -z, as a funnel's `dir`; -1 for none.
static func _axis_of(v: Vector3) -> int:
	for dir in range(4):
		var axis := Vector3([1.0, 0.0, -1.0, 0.0][dir], 0.0, [0.0, 1.0, 0.0, -1.0][dir])
		if v.dot(axis) > cos(AirbasePlan.QUARTER_SLACK):
			return dir
	return -1

