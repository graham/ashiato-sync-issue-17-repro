extends Node
## The checked-in immutable package revision is a numeric census of every fitted station.
## Runtime builds these records directly. The legacy scene comparison protects the one-time
## migration, and the package-built comparison protects the shipping path.

const FIXTURES := "res://tests/station_fixtures"
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[stations] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	CockpitStation.use_saved_layouts = false
	var mismatches: PackedStringArray = []
	var packages := 0
	var stations := 0
	var controls := 0
	var runtime_mismatches: PackedStringArray = []
	var boards := 0
	var board_faults: PackedStringArray = []
	for kind in range(Sim.Kind.size()):
		var package := AuthoredCraftPackages.read(kind)
		if package.has("error"):
			mismatches.append("%s: %s" % [Sim.kind_name(kind), package["error"]])
			continue
		packages += 1
		var craft := package["craft"] as Dictionary
		var poses := Sim.geometry_of(kind).get("seat_poses", []) as Array
		if (craft.get("stations", {}) as Dictionary).size() != poses.size():
			mismatches.append("%s: %d station documents for %d native seats" % [
				Sim.kind_name(kind), (craft.get("stations", {}) as Dictionary).size(), poses.size()])
		for seat in range(poses.size()):
			var loaded := AuthoredCraftPackages.read_station(kind, seat)
			if loaded.has("error"):
				mismatches.append("%s seat %d: %s" % [Sim.kind_name(kind), seat, loaded["error"]])
				continue
			var scene := (VehicleCatalogue.seat_scene(kind) as PackedScene).instantiate() as CockpitStation
			add_child(scene)
			var pose := poses[seat] as Dictionary
			scene.fit(seat, bool(pose.get("flies", true)), kind,
				_mirrored(poses, seat) and not VehicleCatalogue.same_hands(kind))
			var expected := loaded["station"] as Dictionary
			var actual := _station_record(kind, seat, scene)
			var difference := _first_difference(expected, actual)
			if difference != "":
				mismatches.append("%s seat %d %s" % [Sim.kind_name(kind), seat, difference])
			stations += 1
			controls += (actual.get("fitted_controls", []) as Array).size()
			scene.queue_free()
			var built := AuthoredCraftPackages.make_station(kind, seat)
			var runtime := built.get("station") as CockpitStation
			if runtime == null:
				runtime_mismatches.append("%s seat %d: %s" % [Sim.kind_name(kind), seat,
					built.get("error", "not built")])
				continue
			add_child(runtime)
			var runtime_difference := _first_difference(expected, _station_record(kind, seat, runtime))
			if runtime_difference != "":
				runtime_mismatches.append("%s seat %d %s" % [Sim.kind_name(kind), seat, runtime_difference])
			var board := runtime.get_node_or_null("Crew") as CrewBoard
			if board != null:
				boards += 1
				var slab := board.get_child(0) as MeshInstance3D
				var size: Vector3 = (slab.mesh as BoxMesh).size if slab != null and slab.mesh is BoxMesh else Vector3.ZERO
				var fault := _board_fault(board.transform, Vector2(size.x, size.y) * 0.5)
				if fault != "":
					board_faults.append("%s seat %d: %s" % [Sim.kind_name(kind), seat, fault])
			runtime.queue_free()
	_check("every_native_seat_has_an_equal_immutable_station_document",
		mismatches.is_empty() and packages == Sim.Kind.size() and stations > 20 and controls > 100,
		"%d packages, %d stations, %d fitted controls" % [packages, stations, controls]
			if mismatches.is_empty() else "\n      ".join(mismatches))
	_check("every_runtime_station_is_constructed_directly_from_its_immutable_document",
		runtime_mismatches.is_empty() and stations > 20,
		"%d package-built stations" % stations if runtime_mismatches.is_empty()
			else "\n      ".join(runtime_mismatches))
	# THE CREW BOARD IS A PLACARD, AND IT IS NOT IN THE VIEW: in every station a player is
	# built, at most BOARD_MOST across and every corner of its face more than FORWARD_CONE off
	# the nose from the seated eye. The board it replaced -- 0.34 x 0.175 m at (0.30, 1.14,
	# -0.36), square to the seat -- is the mutant, and must fail both (2026-09-18).
	var old := _board_fault(Transform3D(Basis.IDENTITY, Vector3(0.30, 1.14, -0.36)), Vector2(0.17, 0.0875))
	_check("the_crew_board_is_a_small_placard_out_of_the_forward_view",
		board_faults.is_empty() and boards > 50 and old.contains("wide") and old.contains("off the nose"),
		("%d boards within %.2f x %.2f m and over %.0f deg off the nose; the old board fails: %s"
			% [boards, BOARD_MOST.x, BOARD_MOST.y, FORWARD_CONE, old]) if board_faults.is_empty()
			else "
      ".join(board_faults))
	var crowd: Array = []
	for i in range(64):
		crowd.append({"seat": i, "station": "rider", "client": (i + 2) if i % 3 == 0 else 0, "mine": i == 40})
	var lines := CrewBoard.lines_for(crowd)
	_check("sixty_four_seats_still_fit_on_the_board",
		lines.size() <= CrewBoard.ROWS and lines[0].begins_with("1 ") and "
".join(lines).contains("YOU")
			and lines[lines.size() - 1].begins_with("+"),
		" | ".join(lines))
	_allowed_lists_match_the_native_bus()
	_malformed_packages_disable_only_themselves()
	print("[stations] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


## THE LARGEST THE CREW BOARD MAY BE, across and up, in metres.
const BOARD_MOST := Vector2(0.12, 0.06)
## HOW FAR OFF THE NOSE, in degrees from the seated eye, every corner of it must be. The view
## over the nose and out of the front quarter is what a crew sits there for.
const FORWARD_CONE: float = 40.0


## What is wrong with a crew board at `place` in its station, with a face `half` its size;
## "" when nothing is.
func _board_fault(place: Transform3D, half: Vector2) -> String:
	var faults: PackedStringArray = []
	if half.x * 2.0 > BOARD_MOST.x + 0.0001 or half.y * 2.0 > BOARD_MOST.y + 0.0001:
		faults.append("%.3f x %.3f m wide" % [half.x * 2.0, half.y * 2.0])
	var eye := Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	var nearest: float = 180.0
	for corner in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		var point: Vector3 = place * Vector3(corner.x * half.x, corner.y * half.y, 0.0)
		nearest = minf(nearest, rad_to_deg((point - eye).angle_to(Vector3.FORWARD)))
	if nearest < FORWARD_CONE:
		faults.append("a corner %.0f deg off the nose" % nearest)
	return ", ".join(faults)


func _allowed_lists_match_the_native_bus() -> void:
	# THE LAMP CHANNELS, AS `Sim.start` FITS THEM on every machine before any world, and as the package generator does:
	# every craft allows a signal lamp (lane/lampopt, 2026-09-19), and its channel is one of these.
	SignalLamp.fit_every_kind()
	var wrong: PackedStringArray = []
	var total := 0
	for kind in range(Sim.Kind.size()):
		var allowed := AuthoredCraftPackages.allowed(kind)
		if allowed != VehicleCatalogue.allowed(kind):
			wrong.append("%s catalogue allowlist differs from its package" % Sim.kind_name(kind))
		var seen: Dictionary = {}
		for part in allowed:
			seen[part] = true
			var control := ControlCatalogue.make(part)
			control.setup(0)
			if control.channel >= 0 and not CraftPackage._has_channel(kind, control.channel):
				wrong.append("%s allows %s on unfitted channel %d" % [Sim.kind_name(kind), part, control.channel])
			control.free()
			total += 1
		var poses := Sim.geometry_of(kind).get("seat_poses", []) as Array
		for seat in range(poses.size()):
			var loaded := AuthoredCraftPackages.read_station(kind, seat)
			if loaded.has("error"):
				continue
			for entry_any in (loaded["station"] as Dictionary).get("controls", []) as Array:
				var part := StringName((entry_any as Dictionary).get("part", ""))
				if not seen.has(part):
					wrong.append("%s seat %d authors disallowed %s" % [Sim.kind_name(kind), seat, part])
	_check("each_craft_explicitly_allows_its_authored_devices_and_no_unfitted_channel_device",
		wrong.is_empty() and total > Sim.Kind.size(), "%d allowed entries" % total if wrong.is_empty()
			else "\n      ".join(wrong))
	var plane := AuthoredCraftPackages.read_station(Sim.Kind.PLANE, 0)
	var layout := (plane.get("station", {}) as Dictionary).duplicate(true)
	var first_part := String(((layout.get("controls", []) as Array)[0] as Dictionary).get("part", ""))
	var narrowed: Array = (AuthoredCraftPackages.read(Sim.Kind.PLANE).get("craft", {}) as Dictionary).get(
		"allowed_devices", []).duplicate()
	narrowed.erase(first_part)
	_check("package_validation_refuses_a_device_removed_from_the_crafts_allowlist",
		CraftPackage.validate_station(Sim.Kind.PLANE, 0, layout, narrowed).contains("disallowed device"),
		"removed %s" % first_part)


func _malformed_packages_disable_only_themselves() -> void:
	var malformed := AuthoredCraftPackages.read(Sim.Kind.PLANE, "1", FIXTURES)
	var healthy := AuthoredCraftPackages.read(Sim.Kind.BOAT)
	_check("a_malformed_fixture_is_refused_without_poisoning_another_package",
		malformed.has("error") and not healthy.has("error"),
		"fixture: %s; boat: %s" % [malformed.get("error", "accepted"), healthy.get("error", "healthy")])


func _station_record(kind: int, seat: int, station: CockpitStation) -> Dictionary:
	var record := CockpitLayout.of_station(kind, seat, station)
	record["source_scene"] = String(VehicleCatalogue.of(kind).get("seat", ""))
	var shell := station.get_node_or_null("Shell") as CockpitShell
	record["shell"] = {} if shell == null else {
		"name": String(shell.name), "width": shell.width, "depth": shell.depth,
		"tint": _colour(shell.tint), "at": _triple(shell.position),
		"facing": _triple(_degrees(shell.rotation))}
	# A CRAFT'S OWN FOOTWELL, compared where its catalogue names one, as the generator writes it.
	if shell != null and not VehicleCatalogue.of(kind).get("footwell", {}).is_empty():
		record["shell"]["footwell"] = {"raise": shell.footwell_raise, "floor_width": shell.floor_width,
			"bar_width": shell.bar_width}
		if shell.reclined:
			record["shell"]["footwell"]["reclined"] = true
	var fitted: Array = []
	var furniture: Array = []
	for child in station.get_children():
		if child is VehicleControl:
			var control := child as VehicleControl
			fitted.append({"class": _class_name(control), "name": String(control.name),
				"at": _triple(control.position), "facing": _triple(_degrees(control.rotation)),
				"channel": control.channel, "range": control.channel_range,
				"scope": CockpitLayout.scope_word(control.scope)})
		elif child is Node3D and not (child is CockpitShell):
			var node := child as Node3D
			var item := {"class": _class_name(node), "name": String(node.name),
				"at": _triple(node.position), "facing": _triple(_degrees(node.rotation))}
			if node is TouchPanel:
				item.merge(AuthoredCraftPackages.panel_record(node as TouchPanel))
			furniture.append(item)
	record["fitted_controls"] = fitted
	record["furniture"] = furniture
	return record


func _first_difference(expected: Variant, actual: Variant, path: String = "station") -> String:
	if (expected is int or expected is float) and (actual is int or actual is float):
		return "" if absf(float(expected) - float(actual)) <= 0.0005 else "%s differs (%s -> %s)" % [path, expected, actual]
	if typeof(expected) != typeof(actual):
		return "%s changes type (%s -> %s)" % [path, type_string(typeof(expected)), type_string(typeof(actual))]
	if expected is Dictionary:
		for key in expected as Dictionary:
			if not (actual as Dictionary).has(key):
				return "%s.%s is missing" % [path, key]
			var found := _first_difference((expected as Dictionary)[key], (actual as Dictionary)[key], "%s.%s" % [path, key])
			if found != "": return found
		for key in actual as Dictionary:
			if not (expected as Dictionary).has(key): return "%s.%s is unexpected" % [path, key]
		return ""
	if expected is Array:
		if (expected as Array).size() != (actual as Array).size():
			return "%s has %d entries, scene has %d" % [path, (expected as Array).size(), (actual as Array).size()]
		for index in range((expected as Array).size()):
			var found := _first_difference((expected as Array)[index], (actual as Array)[index], "%s[%d]" % [path, index])
			if found != "": return found
		return ""
	return "" if expected == actual else "%s differs (%s -> %s)" % [path, expected, actual]


func _mirrored(poses: Array, seat: int) -> bool:
	var at := (poses[seat] as Dictionary).get("position", Vector3.ZERO) as Vector3
	if at.x <= 0.01: return false
	for other in range(poses.size()):
		if other == seat: continue
		var there := (poses[other] as Dictionary).get("position", Vector3.ZERO) as Vector3
		if there.x < -0.01 and absf(there.z - at.z) < 0.3: return true
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
