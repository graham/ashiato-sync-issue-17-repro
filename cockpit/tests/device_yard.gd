extends Node
## Headless: the Device Yard's hashed level contract, two room boundaries and configurable endpoint density.
##
## This intentionally does not try to toggle a device: before the native RoomControlBank exists, that would test a local
## fake. It proves the preparatory contract the native implementation receives: exact room names, density bounds,
## deterministic placements, two sets of static collision boxes and GPU-instanced endpoint counts.

const LEVEL_PATH := "res://levels/device_yard"
const COUNTS: PackedInt32Array = [100, 250, 500]
var _failures: PackedStringArray = []

func _check(label: String, ok: bool, detail: String) -> void:
	print("[device_yard] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)

func _ready() -> void:
	var chart := LevelChart.read(LEVEL_PATH)
	_check("the_device_yard_level_is_usable", chart.usable(), chart.refusal)
	_check("it_arrives_players_in_segways", chart.arrive_kind == Sim.Kind.SEGWAY, Sim.kind_name(chart.arrive_kind))
	_check("its_default_density_is_hashed_level_content", chart.yard_devices == 100 and chart.content_hash != "",
		"%d endpoints, hash %s" % [chart.yard_devices, chart.content_hash.left(12)])
	_check("the_density_presets_and_bounded_custom_counts_are_valid", _densities_are_sensible(),
		"presets %s; 1..500 allowed" % [DeviceYard.PRESETS])
	_check("invalid_density_refuses_the_chart", _bad_density_refuses(), "0 and 501 refused")
	_check("the_two_rooms_have_separate_closed_collision_shells", _separate_shells(chart),
		"%d boxes" % DeviceYard.boxes(chart).size())
	for count in COUNTS:
		_check("%d_endpoints_have_stable_unique_places_in_each_room" % count, _places_are_stable(count),
			"%d alpha + %d bravo" % [count, count])
		await _draw_count(count)
	print("[device_yard] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _densities_are_sensible() -> bool:
	for count in COUNTS:
		if not DeviceYard.is_valid_density(count): return false
	return DeviceYard.is_valid_density(1) and DeviceYard.is_valid_density(417) and DeviceYard.is_valid_density(500) \
		and not DeviceYard.is_valid_density(0) and not DeviceYard.is_valid_density(501)

func _bad_density_refuses() -> bool:
	for count in [0, 501, 2.5]:
		if _chart_with_density(count).usable(): return false
	return true

func _chart_with_density(count: Variant) -> LevelChart:
	var chart := LevelChart.new()
	chart._take({"name": "Yard fixture", "summary": "A checked yard fixture.", "world": "room", "arrive": "segway",
		"yard_devices": count, "spawn": {"at": [0, 0.5, 0], "yaw_degrees": 0, "apart": 1.8}})
	return chart

func _separate_shells(chart: LevelChart) -> bool:
	var boxes := DeviceYard.boxes(chart)
	if boxes.size() != 10: return false
	var alpha := 0
	var bravo := 0
	for box in boxes:
		if StringName(box.get("room", "")) == &"alpha": alpha += 1
		if StringName(box.get("room", "")) == &"bravo": bravo += 1
	return alpha == 5 and bravo == 5

func _places_are_stable(count: int) -> bool:
	var alpha_a := DeviceYard.endpoint_places(&"alpha", count)
	var alpha_b := DeviceYard.endpoint_places(&"alpha", count)
	var bravo := DeviceYard.endpoint_places(&"bravo", count)
	if alpha_a.size() != count or bravo.size() != count or alpha_a != alpha_b: return false
	var seen: Dictionary = {}
	for place in alpha_a + bravo:
		var key := "%0.4f,%0.4f,%0.4f" % [place.x, place.y, place.z]
		if seen.has(key): return false
		seen[key] = true
	return true

func _draw_count(count: int) -> void:
	var yard := DeviceYard.new()
	add_child(yard)
	yard.stand_in(_chart_with_density(count))
	await get_tree().process_frame
	var alpha := yard.get_node_or_null("DeviceBodies_alpha") as MultiMeshInstance3D
	var bravo := yard.get_node_or_null("DeviceBodies_bravo") as MultiMeshInstance3D
	var report := yard.report()
	_check("%d_endpoints_per_room_are_instanced_not_node_spammed" % count,
		alpha != null and bravo != null and alpha.multimesh.instance_count == count and bravo.multimesh.instance_count == count
		and int(report.get("endpoints_total", 0)) == count * 2,
		"alpha %d, bravo %d, total %d" % [alpha.multimesh.instance_count if alpha != null else -1,
			bravo.multimesh.instance_count if bravo != null else -1, int(report.get("endpoints_total", 0))])
	yard.queue_free()
	await get_tree().process_frame
