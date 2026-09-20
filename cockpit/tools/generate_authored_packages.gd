extends Node
## Regenerates the initial checked-in package revision from the still-authoritative scenes.
## It is deliberately explicit and opt-in: normal tests only compare, and never rewrite.
## Run from cockpit with: Godot --headless res://tools/generate_authored_packages.tscn

const ROOT := "res://craft"
const REVISION := "1"


func _ready() -> void:
	CockpitStation.use_saved_layouts = false
	# THE LAMP CHANNELS, which `Sim.start` fits on every machine before a world is made, and nothing here starts one.
	# Unfitted, `_allowed_for` finds the signal lamp's channel on no craft and leaves the lamp out of every bin.
	SignalLamp.fit_every_kind()
	for kind in range(Sim.Kind.size()):
		_write_kind(kind)
	print("[authored_packages] RESULT=PASS wrote %d craft revisions" % Sim.Kind.size())
	get_tree().quit()


func _write_kind(kind: int) -> void:
	var root := AuthoredCraftPackages.path_for(kind)
	DirAccess.make_dir_recursive_absolute(root.path_join("stations"))
	var geometry := Sim.geometry_of(kind)
	var poses := geometry.get("seat_poses", []) as Array
	var stations: Dictionary = {}
	var hashes: Dictionary = {}
	for seat in range(poses.size()):
		var station := (VehicleCatalogue.seat_scene(kind) as PackedScene).instantiate() as CockpitStation
		add_child(station)
		var pose := poses[seat] as Dictionary
		station.fit(seat, bool(pose.get("flies", true)), kind, _mirrored(poses, seat) and not VehicleCatalogue.same_hands(kind))
		var record := _station_record(kind, seat, station)
		var relative := "stations/seat%d.json" % seat
		_write_json(root.path_join(relative), record)
		stations[str(seat)] = relative
		hashes[str(seat)] = CraftPackage._hash(FileAccess.get_file_as_string(root.path_join(relative)))
		station.free()
	var entry := VehicleCatalogue.of(kind)
	var record := {
		"version": CraftPackage.VERSION,
		"revision": REVISION,
		"craft": Sim.kind_name(kind),
		"kind": kind,
		"units": "metres; seat poses are relative to the craft model origin; -Z is forward, +Y is up",
		"model": {
			"native_model": geometry.get("model_name", ""),
			"presentation_body": VehicleCatalogue.Body.keys()[VehicleCatalogue.body(kind)],
		},
		"presentation": {
			"seat_scene": String(entry.get("seat", "")),
			"paint": _colour(entry.get("paint", Color.WHITE) as Color),
			"drawn": bool(entry.get("drawn", true)),
			"helm": String(entry.get("helm", "glazed")),
			"shared_throttle": bool(entry.get("shared_throttle", false)),
			"plunger": bool(entry.get("plunger", false)),
		},
		"seat_poses": _json_value(poses),
		"simulation_contract": CraftPackage._contract_hash(kind),
		"stations": stations,
		"station_hashes": hashes,
		"allowed_devices": _allowed_for(kind),
	}
	if entry.has("visual"):
		record["visual"] = (entry["visual"] as Dictionary).duplicate(true)
	record["manifest_hash"] = CraftPackage._manifest_hash(record)
	_write_json(root.path_join("craft.json"), record)


func _station_record(kind: int, seat: int, station: CockpitStation) -> Dictionary:
	var record := CockpitLayout.of_station(kind, seat, station)
	record["source_scene"] = String(VehicleCatalogue.of(kind).get("seat", ""))
	record["shell"] = _shell(station)
	record["fitted_controls"] = _fitted_controls(station)
	record["furniture"] = _furniture(station)
	return record


func _shell(station: CockpitStation) -> Dictionary:
	var shell := station.get_node_or_null("Shell") as CockpitShell
	if shell == null:
		return {}
	var record := {"name": String(shell.name), "width": shell.width, "depth": shell.depth,
		"tint": _colour(shell.tint), "at": _triple(shell.position),
		"facing": _triple(_degrees(shell.rotation))}
	# A CRAFT'S OWN FOOTWELL, written only where one is named, so every other package is byte for byte what it was.
	if not VehicleCatalogue.of(station.craft_kind).get("footwell", {}).is_empty():
		record["footwell"] = {"raise": shell.footwell_raise, "floor_width": shell.floor_width,
			"bar_width": shell.bar_width}
		# Written only where a craft declares it, so the Little Bird's package is what it was.
		if shell.reclined:
			record["footwell"]["reclined"] = true
	return record


func _fitted_controls(station: CockpitStation) -> Array:
	var result: Array = []
	for child in station.get_children():
		var control := child as VehicleControl
		if control == null:
			continue
		result.append({"class": _class_name(control), "name": String(control.name),
			"at": _triple(control.position), "facing": _triple(_degrees(control.rotation)),
			"channel": control.channel, "range": control.channel_range,
			"scope": CockpitLayout.scope_word(control.scope)})
	return result


func _furniture(station: CockpitStation) -> Array:
	var result: Array = []
	for child in station.get_children():
		if not (child is Node3D) or child is VehicleControl or child is CockpitShell:
			continue
		var node := child as Node3D
		var item := {"class": _class_name(node), "name": String(node.name),
			"at": _triple(node.position), "facing": _triple(_degrees(node.rotation))}
		if node is TouchPanel:
			item.merge(AuthoredCraftPackages.panel_record(node as TouchPanel))
		result.append(item)
	return result


func _allowed_for(kind: int) -> Array:
	var channels: Dictionary = {}
	for row_any in Sim.schema_of(kind).get("channels", []) as Array:
		channels[int((row_any as Dictionary).get("channel", -1))] = true
	var result: Array = []
	for part in ControlCatalogue.PARTS:
		var control := ControlCatalogue.make(part)
		control.setup(0)
		# Generic panel furniture is allowed everywhere; a device wired to a native
		# channel is useful only on craft whose authoritative bus fits that channel.
		if control.channel < 0 or channels.has(control.channel):
			result.append(String(part))
		control.free()
	return result


func _mirrored(poses: Array, seat: int) -> bool:
	var mine := poses[seat] as Dictionary
	var at := mine.get("position", Vector3.ZERO) as Vector3
	if at.x <= 0.01:
		return false
	for other in range(poses.size()):
		if other == seat:
			continue
		var there := (poses[other] as Dictionary).get("position", Vector3.ZERO) as Vector3
		if there.x < -0.01 and absf(there.z - at.z) < 0.3:
			return true
	return false


func _class_name(node: Object) -> String:
	var script := node.get_script() as GDScript
	return String(script.get_global_name()) if script != null else node.get_class()


func _degrees(rotation: Vector3) -> Vector3:
	return Vector3(rad_to_deg(rotation.x), rad_to_deg(rotation.y), rad_to_deg(rotation.z))


func _triple(value: Vector3) -> Array:
	return [snappedf(value.x, 0.001), snappedf(value.y, 0.001), snappedf(value.z, 0.001)]


func _colour(value: Color) -> Array:
	return [value.r, value.g, value.b, value.a]


func _json_value(value: Variant) -> Variant:
	if value is Vector3:
		return _triple(value as Vector3)
	if value is Color:
		return _colour(value as Color)
	if value is Array:
		var array: Array = []
		for item in value as Array:
			array.append(_json_value(item))
		return array
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key in value as Dictionary:
			dictionary[key] = _json_value((value as Dictionary)[key])
		return dictionary
	return value


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s" % path)
		return
	file.store_string(JSON.stringify(value, "  "))
	file.close()
