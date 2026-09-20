extends RefCounted
class_name AuthoredCraftPackages
## Read-only access to immutable craft packages checked into res://craft.
## A malformed revision returns an error and never changes another craft or falls through
## to partially trusted data. `make_station` is the runtime boundary: checked-in JSON is
## authoritative, while VehicleView owns the temporary legacy-scene fallback.

const ROOT := "res://craft"
const REVISION := "1"


static func path_for(kind: int, revision: String = REVISION, root: String = ROOT) -> String:
	return root.path_join(Sim.kind_name(kind)).path_join(revision)


static func read(kind: int, revision: String = REVISION, root: String = ROOT) -> Dictionary:
	var folder := path_for(kind, revision, root)
	var result := _read_object(folder.path_join("craft.json"))
	if result.has("error"):
		return result
	var craft := result["value"] as Dictionary
	if int(craft.get("version", -1)) != CraftPackage.VERSION:
		return {"error": "unsupported craft package version"}
	if int(craft.get("kind", -1)) != kind or String(craft.get("craft", "")) != Sim.kind_name(kind):
		return {"error": "craft package identity does not match its folder"}
	if String(craft.get("simulation_contract", "")) != CraftPackage._contract_hash(kind):
		return {"error": "craft package simulation contract is stale"}
	if String(craft.get("manifest_hash", "")) != CraftPackage._manifest_hash(craft):
		return {"error": "craft package manifest hash does not match craft.json"}
	var stations: Variant = craft.get("stations", null)
	if not (stations is Dictionary):
		return {"error": "craft package stations must be an object"}
	var allowed: Variant = craft.get("allowed_devices", null)
	if not (allowed is Array):
		return {"error": "craft package allowed_devices must be an array"}
	var seen: Dictionary = {}
	for part_any in allowed as Array:
		var part := StringName(part_any)
		if not ControlCatalogue.has(part):
			return {"error": "craft package allows unknown device %s" % part}
		if seen.has(part):
			return {"error": "craft package allows device %s twice" % part}
		seen[part] = true
	if craft.has("visual"):
		var visual_why := ModelAssetDefinition.validate(craft["visual"] as Dictionary) \
			if craft["visual"] is Dictionary else "visual must be an object"
		if visual_why != "":
			return {"error": visual_why}
	return {"craft": craft, "path": folder}


static func read_station(kind: int, seat: int, revision: String = REVISION,
		root: String = ROOT) -> Dictionary:
	var package := read(kind, revision, root)
	if package.has("error"):
		return package
	var craft := package["craft"] as Dictionary
	var stations := craft["stations"] as Dictionary
	var relative := String(stations.get(str(seat), ""))
	if relative.is_empty() or relative.is_absolute_path() or relative.contains(".."):
		return {"error": "craft package has no safe station path for seat %d" % seat}
	var station_path := String(package["path"]).path_join(relative)
	var result := _read_object(station_path)
	if result.has("error"):
		return result
	var layout := result["value"] as Dictionary
	var hashes := craft.get("station_hashes", {}) as Dictionary
	if String(hashes.get(str(seat), "")) != CraftPackage._hash(FileAccess.get_file_as_string(station_path)):
		return {"error": "station %d does not match the package manifest" % seat}
	var why := CraftPackage.validate_station(kind, seat, layout,
		craft.get("allowed_devices", []) as Array)
	if why != "":
		return {"error": why}
	return {"station": layout, "craft": craft, "path": station_path}


static func allowed(kind: int, revision: String = REVISION, root: String = ROOT) -> Array[StringName]:
	var package := read(kind, revision, root)
	var result: Array[StringName] = []
	if package.has("error"):
		return result
	for part in (package["craft"] as Dictionary).get("allowed_devices", []) as Array:
		result.append(StringName(part))
	return result


## BUILD ONE IMMUTABLE AUTHORED STATION, without instantiating its source scene.
static func make_station(kind: int, seat: int, revision: String = REVISION,
		root: String = ROOT) -> Dictionary:
	var loaded := read_station(kind, seat, revision, root)
	if loaded.has("error"):
		return loaded
	var record := loaded["station"] as Dictionary
	var station := CockpitStation.new()
	station.name = "Station"
	var shell_record := record.get("shell", {}) as Dictionary
	if not shell_record.is_empty():
		var shell := CockpitShell.new()
		shell.name = String(shell_record.get("name", "Shell"))
		shell.width = float(shell_record.get("width", shell.width))
		shell.depth = float(shell_record.get("depth", shell.depth))
		shell.tint = _colour(shell_record.get("tint", []), shell.tint)
		var footwell := shell_record.get("footwell", {}) as Dictionary
		shell.footwell_raise = float(footwell.get("raise", shell.footwell_raise))
		shell.reclined = bool(footwell.get("reclined", false))
		shell.floor_width = float(footwell.get("floor_width", shell.floor_width))
		shell.bar_width = float(footwell.get("bar_width", shell.bar_width))
		_place(shell, shell_record)
		station.add_child(shell)
	var permitted := allowed(kind, revision, root)
	CockpitLayout.apply(record, station, seat, permitted, kind)
	# PintleGun is simulation-fitted and deliberately absent from the builder catalogue.
	# It is still explicit in fitted_controls, so the JSON construction path restores it.
	for item_any in record.get("fitted_controls", []) as Array:
		var item := item_any as Dictionary
		if station.get_node_or_null(String(item.get("name", ""))) != null:
			continue
		if String(item.get("class", "")) != "PintleGun":
			station.free()
			return {"error": "station %d names unsupported fitted control %s" % [seat, item.get("class", "")]}
		var gun := PintleGun.new()
		gun.name = String(item.get("name", "Stick"))
		gun.channel = int(item.get("channel", gun.channel))
		gun.channel_range = int(item.get("range", gun.channel_range))
		gun.scope = CockpitLayout.scope_from(item.get("scope"), gun.scope) as VehicleControl.Scope
		_place(gun, item)
		station.add_child(gun)
	# Child order is part of the immutable document and keeps exports/diffs deterministic.
	var control_index := 1 if not shell_record.is_empty() else 0
	for item_any in record.get("fitted_controls", []) as Array:
		var control := station.get_node_or_null(String((item_any as Dictionary).get("name", "")))
		if control != null:
			station.move_child(control, control_index)
			control_index += 1
	for item_any in record.get("furniture", []) as Array:
		var item := item_any as Dictionary
		var furniture := _furniture(String(item.get("class", "")))
		if furniture == null:
			station.free()
			return {"error": "station %d names unsupported furniture %s" % [seat, item.get("class", "")]}
		furniture.name = String(item.get("name", item.get("class", "Furniture")))
		_place(furniture, item)
		if furniture is CraftDisplay:
			var page_path := String(item.get("page", ""))
			if not page_path.is_empty():
				(furniture as CraftDisplay).page = load(page_path) as PackedScene
			if page_path.ends_with("mfd_page.tscn"):
				(furniture as CraftDisplay).size = CockpitStation.MFD_SIZE
				(furniture as CraftDisplay).pixels = 768
				(furniture as CraftDisplay).bezel = true
			# A SCREEN AUTHORED AT ITS OWN SIZE, as the F-35B's panoramic display: the package says so.
			var authored: Array = item.get("size", []) as Array if item.get("size", []) is Array else []
			if authored.size() >= 2:
				(furniture as CraftDisplay).size = Vector2(float(authored[0]), float(authored[1]))
				(furniture as CraftDisplay).pixels = int(item.get("pixels", (furniture as CraftDisplay).pixels))
		station.add_child(furniture)
	station.configure_authored(seat, kind)
	if CockpitStation.use_saved_layouts and CockpitLayout.exists(kind, seat):
		CockpitLayout.apply(CockpitLayout.read(kind, seat), station, seat, permitted, kind)
		station.setup_controls(seat)
	return {"station": station, "path": loaded["path"]}


## WHAT A PACKAGE SAYS ABOUT A SCREEN, written by `generate_authored_packages` and rebuilt by `tests/stations.gd` from
## the same function, so the two cannot disagree: its page and, only when it is not the default or an MFD's, its size
## and pixels. The package carried only the page until 2026-09-19, so the F-35B's 0.51 m panoramic display was built in
## the game at the default 0.26 m (lane/lightning); writing the size only when it is authored keeps every other package
## byte-identical.
static func panel_record(panel: TouchPanel) -> Dictionary:
	var item := {"page": panel.page.resource_path if panel.page != null else ""}
	if panel is CraftDisplay and panel.size != CraftDisplay.DEFAULT_SIZE and panel.size != CockpitStation.MFD_SIZE:
		item["size"] = [panel.size.x, panel.size.y]
		item["pixels"] = panel.pixels
	return item


static func _furniture(type: String) -> Node3D:
	match type:
		"RudderIndicator": return RudderIndicator.new()
		"CrewBoard": return CrewBoard.new()
		"CraftDisplay": return CraftDisplay.new()
		"GunSight": return GunSight.new()
		"RangeSight": return RangeSight.new()
		"LockSight": return LockSight.new()
		"HelmetSight": return HelmetSight.new()
		"TankGauge": return TankGauge.new()
	return null


static func _place(node: Node3D, record: Dictionary) -> void:
	node.position = _vector(record.get("at", []))
	var degrees := _vector(record.get("facing", []))
	node.rotation = Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))


static func _vector(value: Variant) -> Vector3:
	var numbers := value as Array if value is Array else []
	return Vector3(float(numbers[0]), float(numbers[1]), float(numbers[2])) if numbers.size() >= 3 else Vector3.ZERO


static func _colour(value: Variant, fallback: Color) -> Color:
	var numbers := value as Array if value is Array else []
	return Color(float(numbers[0]), float(numbers[1]), float(numbers[2]), float(numbers[3])) if numbers.size() >= 4 else fallback


static func _read_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "missing %s" % path}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {"error": "%s is not a JSON object" % path}
	return {"value": parsed as Dictionary}
