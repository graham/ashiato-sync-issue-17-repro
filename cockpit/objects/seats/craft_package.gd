extends RefCounted
class_name CraftPackage
## A versioned cockpit package: presentation data plus the native craft contract it needs.
## Seat poses and the flight schema are copied for inspection and compatibility only.  Native
## code remains authoritative until a pre-session CustomCraftRegistry can install a package
## identically on every rollback peer.
##
## THE CONTRACT HASH LEAVES THE GENERIC CHANNELS OUT (lane/lightgun, 2026-09-18). `Sim.fit_channels` adds channels
## from `first_generic_channel` up to a kind at boot -- every seat's signal lamp is one (`SignalLamp`) -- and
## `craft_schema` lists them beside the named ones. The simulation reads none of them: `apply_command` stores a
## generic value on a page and nothing in the flight model looks at it. So they are not part of the craft's flight
## contract, and hashing them made every authored package read "simulation contract is stale" the moment the lamps
## were fitted. The named channels -- flaps, gear, trim and the rest, whose ranges the physics does read -- and the
## geometry are still hashed, and `tests/lamp_wire.gd` holds both halves: a generic-only change leaves the hash
## where it was, and moving a seat moves it. Two builds with different generic channels are two commits, and the
## handshake refuses a joiner on a different commit, so the hash is not what keeps them apart.

const PLAYER_ROOT := "user://cockpit_packages"
const TEST_ROOT := "user://test_cockpit_packages"
const VERSION := 1
const DEFAULT_VERSION := "default"
const MOST_CONTROLS := 512

## Suites must never overwrite a designer's package.  This mirrors CockpitLayout's
## command-line-derived test folder: a test run may be started directly, so no optional
## runner flag is trusted to keep it away from player data.
static var folder: String = folder_for(OS.get_cmdline_args(), OS.get_cmdline_user_args())

static func folder_for(args: PackedStringArray, user_args: PackedStringArray = []) -> String:
	for arg in args:
		if arg.begins_with("res://tests/") or arg.begins_with("res://marshalling/tests/") \
				or arg == "--builder-test-files=1":
			return TEST_ROOT + CockpitLayout.test_slot()
	for arg in user_args:
		if arg == "--builder-test-files=1":
			return TEST_ROOT + CockpitLayout.test_slot()
	return PLAYER_ROOT

static func path_for(kind: int, version: String = DEFAULT_VERSION) -> String:
	return "%s/%s/%s" % [folder, Sim.kind_name(kind), _safe_version(version)]

static func write_station(kind: int, seat: int, station: Node3D, version: String = DEFAULT_VERSION) -> Dictionary:
	if kind < 0 or seat < 0:
		return {"error": "sit in a craft before saving a package"}
	var root := path_for(kind, version)
	if DirAccess.make_dir_recursive_absolute(root.path_join("stations")) != OK:
		return {"error": "could not create the package folder"}
	var layout := CockpitLayout.of_station(kind, seat, station)
	if (layout.get("controls", []) as Array).size() > MOST_CONTROLS:
		return {"error": "a station may contain at most %d devices" % MOST_CONTROLS}
	if not _write_json(root.path_join("stations/seat%d.json" % seat), layout):
		return {"error": "could not write station %d" % seat}
	var craft := _craft_record(kind, root)
	if craft.is_empty() or not _write_json(root.path_join("craft.json"), craft):
		return {"error": "could not write craft.json"}
	return {"path": root, "hash": String(craft["manifest_hash"]), "controls": (layout.get("controls", []) as Array).size()}

static func read_station(kind: int, seat: int, version: String = DEFAULT_VERSION) -> Dictionary:
	var root := path_for(kind, version)
	var craft := _read_json(root.path_join("craft.json"))
	if craft.is_empty() or int(craft.get("version", -1)) != VERSION:
		return {"error": "no compatible craft package"}
	if int(craft.get("kind", -1)) != kind:
		return {"error": "this package belongs to %s" % String(craft.get("craft", "another craft"))}
	if String(craft.get("simulation_contract", "")) != _contract_hash(kind):
		return {"error": "this package was made for a different simulation contract"}
	var station_path := root.path_join("stations/seat%d.json" % seat)
	var layout := _read_json(station_path)
	if layout.is_empty():
		return {"error": "this package has no station %d" % seat}
	var recorded_hashes := craft.get("station_hashes", {}) as Dictionary
	if String(recorded_hashes.get(str(seat), "")) != _hash(FileAccess.get_file_as_string(station_path)):
		return {"error": "station %d no longer matches its package manifest" % seat}
	var why := validate_station(kind, seat, layout, craft.get("allowed_devices", []) as Array)
	return {"error": why} if why != "" else {"layout": layout, "hash": String(craft.get("manifest_hash", ""))}

static func validate_station(kind: int, seat: int, layout: Dictionary, allowed: Array = []) -> String:
	if int(layout.get("kind", -1)) != kind or int(layout.get("seat", -1)) != seat:
		return "station belongs to a different craft or seat"
	# A FOOTWELL OVERRIDE, where a station carries one, within `CockpitShell`'s limits.
	var footwell := (layout.get("shell", {}) as Dictionary).get("footwell", {}) as Dictionary
	if not footwell.is_empty():
		var why := CockpitShell.footwell_refused(float(footwell.get("raise", NAN)),
			float(footwell.get("floor_width", NAN)), float(footwell.get("bar_width", NAN)),
			bool(footwell.get("reclined", false)))
		if why != "":
			return why
	var controls := layout.get("controls", []) as Array
	if controls.size() > MOST_CONTROLS:
		return "station has more than %d devices" % MOST_CONTROLS
	var names: Dictionary = {}
	var device_ids: Dictionary = {}
	for entry_any in controls:
		if not (entry_any is Dictionary): return "station contains a non-device entry"
		var entry := entry_any as Dictionary
		var part := StringName(entry.get("part", ""))
		if not ControlCatalogue.has(part): return "station names an unknown device %s" % part
		if not allowed.is_empty() and not allowed.has(String(part)) and not allowed.has(part):
			return "station names disallowed device %s" % part
		var name := String(entry.get("name", ""))
		if name.is_empty() or names.has(name): return "station has a missing or duplicate device id"
		names[name] = true
		var device_id := String(entry.get("device_id", "seat%d/%s" % [seat, name]))
		if device_id.is_empty() or device_ids.has(device_id):
			return "station has a missing or duplicate stable device id"
		device_ids[device_id] = true
		if int(entry.get("channel", -1)) >= 0 and not _has_channel(kind, int(entry["channel"])):
			return "%s is bound to an unfitted channel" % name
		var binding := entry.get("binding", {}) as Dictionary
		if not binding.is_empty():
			if int(entry.get("channel", -1)) != int(binding.get("channel", -2)):
				return "%s binding channel disagrees with device channel" % name
			var resolved := DeviceSignalRouter.resolve(kind, {"device_id": device_id, "binding": binding},
				{"device_id": device_id, "binding": String(binding.get("id", "")), "phase": "change", "value": 0.0})
			if resolved.has("error"):
				return "%s has invalid binding: %s" % [name, String(resolved["error"])]
	return ""

static func _craft_record(kind: int, root: String) -> Dictionary:
	var geometry := Sim.geometry_of(kind)
	var schema := Sim.schema_of(kind)
	if geometry.is_empty() or schema.is_empty(): return {}
	var record := {"version": VERSION, "craft": Sim.kind_name(kind), "kind": kind,
		"units": "metres; seat poses are relative to the craft model origin; -Z is forward, +Y is up",
		"model": {"native_model": geometry.get("model_name", ""), "presentation_body": VehicleCatalogue.Body.keys()[VehicleCatalogue.body(kind)]},
		"seat_poses": geometry.get("seat_poses", []), "simulation_contract": _contract_hash(kind),
		"stations": _station_paths(root), "station_hashes": _station_hashes(root),
		"allowed_devices": VehicleCatalogue.allowed(kind)}
	record["manifest_hash"] = _manifest_hash(record)
	return record

static func _station_paths(root: String) -> Dictionary:
	var result: Dictionary = {}; var dir := DirAccess.open(root.path_join("stations"))
	if dir == null: return result
	var files: PackedStringArray = []
	dir.list_dir_begin(); var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.begins_with("seat") and file.ends_with(".json"):
			files.append(file)
		file = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for station_file in files:
		result[station_file.trim_prefix("seat").trim_suffix(".json")] = "stations/" + station_file
	return result

static func _station_hashes(root: String) -> Dictionary:
	var result: Dictionary = {}
	for seat in _station_paths(root):
		var relative := String(_station_paths(root)[seat])
		result[seat] = _hash(FileAccess.get_file_as_string(root.path_join(relative)))
	return result

static func _contract_hash(kind: int) -> String:
	# Canonical JSON rather than raw engine Variants.  The shipping double-precision editor
	# and the stock editor expose the same native table with different last float digits;
	# hashing those digits made an authored package valid on the machine that wrote it and
	# stale on the other build.  A micrometre is well below the millimetre authoring grid and
	# still catches a meaningful seat, model or flight-contract change.
	return _hash(JSON.stringify(_contract_value({
		"kind": kind, "geometry": Sim.geometry_of(kind), "schema": _flight_schema(kind)})))


## THE SCHEMA WITHOUT ITS GENERIC CHANNELS: what the flight model reads. See the note at the top.
static func _flight_schema(kind: int) -> Dictionary:
	var schema: Dictionary = Sim.schema_of(kind).duplicate(true)
	var named: Array = []
	for row_any in schema.get("channels", []) as Array:
		if not bool((row_any as Dictionary).get("generic", false)):
			named.append(row_any)
	if schema.has("channels"):
		schema["channels"] = named
	return schema


static func _manifest_hash(record: Dictionary) -> String:
	var unsigned := record.duplicate(true)
	unsigned.erase("manifest_hash")
	# One JSON round trip also normalizes StringName and integer/float representations, so
	# hashing before a write and after a read produces the same manifest.
	var encoded := JSON.stringify(_contract_value(unsigned))
	return _hash(JSON.stringify(JSON.parse_string(encoded)))


static func _contract_value(value: Variant) -> Variant:
	if value is float:
		var snapped := snappedf(float(value), 0.000001)
		return int(round(snapped)) if is_equal_approx(snapped, round(snapped)) else snapped
	if value is Vector2:
		var pair := value as Vector2
		return [_contract_value(pair.x), _contract_value(pair.y)]
	if value is Vector3:
		var triple := value as Vector3
		return [_contract_value(triple.x), _contract_value(triple.y), _contract_value(triple.z)]
	if value is Color:
		var colour := value as Color
		return [_contract_value(colour.r), _contract_value(colour.g),
			_contract_value(colour.b), _contract_value(colour.a)]
	if value is Array:
		var array: Array = []
		for item in value as Array:
			array.append(_contract_value(item))
		return array
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key in value as Dictionary:
			dictionary[key] = _contract_value((value as Dictionary)[key])
		return dictionary
	return value
static func _has_channel(kind: int, channel: int) -> bool:
	for item_any in Sim.schema_of(kind).get("channels", []) as Array:
		if int((item_any as Dictionary).get("channel", -1)) == channel: return true
	return false
static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}
static func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, "  ")); file.close(); return true
static func _hash(text: String) -> String:
	# Git checks JSON out with the platform's line endings, while package generation may
	# run on another OS.  The document is unchanged by that checkout conversion, so its
	# manifest must be unchanged too.  Hash LF text on every platform.
	text = text.replace("\r\n", "\n").replace("\r", "\n")
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	hash.update(text.to_utf8_buffer()); return hash.finish().hex_encode()
static func _safe_version(version: String) -> String:
	var cleaned := version.strip_edges().to_lower().replace(" ", "_")
	return cleaned.validate_filename() if not cleaned.is_empty() else DEFAULT_VERSION
