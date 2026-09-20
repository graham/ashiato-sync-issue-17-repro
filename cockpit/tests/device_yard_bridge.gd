extends Node
## Headless: the Device Yard is a native-state view, not a local toggle. This seam exercises the exact optional API
## that a future RoomControlBank exports, without claiming that the current extension has it.

var _failures: PackedStringArray = []

class FakeRoomControl:
	extends RefCounted
	var configured: Array[Dictionary] = []
	var submitted: Array[Dictionary] = []
	var states: Dictionary = {&"alpha": PackedByteArray([0, 0, 0]), &"bravo": PackedByteArray([0, 0, 0])}

	func room_control_configure(room_id: StringName, revision: int, count: int) -> bool:
		configured.append({"room": room_id, "revision": revision, "count": count})
		return revision == DeviceYard.ROOM_CONTROL_REVISION and count == 3

	func room_control_state(room_id: StringName, _revision: int) -> PackedByteArray:
		return states.get(room_id, PackedByteArray()) as PackedByteArray

	func room_control_submit(room_id: StringName, revision: int, index: int, value: int) -> bool:
		submitted.append({"room": room_id, "revision": revision, "index": index, "value": value})
		return room_id == &"alpha" and revision == DeviceYard.ROOM_CONTROL_REVISION and index >= 0 and index < 3


func _check(label: String, ok: bool, detail: String) -> void:
	print("[device_yard_bridge] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var yard := DeviceYard.new()
	add_child(yard)
	yard.stand_in(_chart())
	_check("an_old_extension_leaves_the_yard_offline", not bool(yard.bind_room_control(null).get("online", true))
		and not yard.submit_endpoint(&"alpha", 0, 255).get("accepted", true), "no API, no local request")
	var registry := yard.endpoint_registry(&"alpha")
	_check("the_registry_has_stable_room_scoped_addresses", registry.size() == 3
		and String((registry[0] as Dictionary).get("device_id", "")) == "alpha/000"
		and String((registry[2] as Dictionary).get("device_id", "")) == "alpha/002"
		and int((registry[0] as Dictionary).get("revision", -1)) == DeviceYard.ROOM_CONTROL_REVISION,
		"%s" % [registry])
	var native := FakeRoomControl.new()
	var connected: Dictionary = yard.bind_room_control(native)
	_check("a_complete_native_api_configures_both_room_registries", bool(connected.get("online", false))
		and native.configured.size() == 2 and yard.room_control_online(), "%s" % [native.configured])
	native.states[&"alpha"] = PackedByteArray([0, 127, 255])
	_check("authoritative_alpha_state_colours_alpha_only", yard.poll_room_control()
		and yard.room_state(&"alpha") == PackedByteArray([0, 127, 255])
		and yard.room_state(&"bravo") == PackedByteArray([0, 0, 0]), "%s / %s" % [yard.room_state(&"alpha"), yard.room_state(&"bravo")])
	var panel := yard.get_node_or_null("DevicePanels_alpha") as MultiMeshInstance3D
	_check("the_instanced_panel_receives_the_authoritative_value", panel != null and panel.multimesh != null
		and panel.multimesh.use_colors and yard.display_colour(&"alpha", 2).g > yard.display_colour(&"alpha", 0).g,
		"panel colours %s -> %s" % [yard.display_colour(&"alpha", 0), yard.display_colour(&"alpha", 2)])
	var before := yard.room_state(&"alpha")
	var sent: Dictionary = yard.submit_endpoint(&"alpha", 1, 33)
	_check("a_press_is_only_a_native_request_until_replication_returns", bool(sent.get("accepted", false))
		and native.submitted.size() == 1 and yard.room_state(&"alpha") == before, "%s" % native.submitted)
	native.states[&"alpha"] = PackedByteArray([0, 33, 255])
	yard.poll_room_control()
	_check("the_later_authoritative_echo_updates_the_view", yard.room_state(&"alpha") == PackedByteArray([0, 33, 255]),
		"%s" % yard.room_state(&"alpha"))
	native.states[&"bravo"] = PackedByteArray([8, 9])
	yard.poll_room_control()
	_check("a_short_or_stale_room_page_is_rejected_whole", yard.room_state(&"bravo") == PackedByteArray([0, 0, 0]),
		"%s" % yard.room_state(&"bravo"))
	_check("bad_addresses_cannot_enter_the_native_bridge", not bool(yard.submit_endpoint(&"bravo", 9, 1).get("accepted", true))
		and not bool(yard.submit_endpoint(&"wrong", 0, 1).get("accepted", true)), "out of bounds refused")
	yard.queue_free()
	print("[device_yard_bridge] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _chart() -> LevelChart:
	var chart := LevelChart.new()
	chart._take({"name": "Bridge fixture", "summary": "A checked bridge fixture.", "world": "room", "arrive": "segway",
		"yard_devices": 3, "spawn": {"at": [0, 0.5, 0], "yaw_degrees": 0, "apart": 1.8}})
	return chart
