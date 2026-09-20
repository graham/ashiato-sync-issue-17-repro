extends Node
## Headless: a player seated on the Device Yard's real Segway points a forced VR hand at
## an instanced endpoint and pulls the same trigger a controller supplies.  This must not
## call `DeviceYard.submit_endpoint` itself: the observed queue signal and later native
## page are evidence that the player-facing path is the one that ran.

const PATIENCE := 1200
const RIGHT := 1
var _failures: PackedStringArray = []
var _requests: Array[Dictionary] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[device_yard_interaction] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if get_tree().current_scene != self:
		await _run()
		return
	var watcher := Node.new()
	watcher.name = "DeviceYardInteractionWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "build with -WithCockpit")
		_finish()
		return
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	Sim.stop()
	Net.leave("device yard interaction suite")
	for i in range(10):
		await get_tree().physics_frame
	_check("the_session_may_choose_the_device_yard", Net.choose_level(DeviceYard.LEVEL_ID) == "", Net.choose_level(DeviceYard.LEVEL_ID))
	get_tree().change_scene_to_file("res://world/sky.tscn")
	var flying: FlightLevel = null
	for i in range(PATIENCE):
		flying = get_tree().current_scene as FlightLevel
		if flying != null and flying.device_yard != null and flying.rig != null and flying.rig.is_seated() \
				and flying.device_yard.room_control_online():
			break
		await get_tree().physics_frame
	var yard: DeviceYard = flying.device_yard if flying != null else null
	var rig: PilotRig = flying.rig if flying != null else null
	_check("real_level_has_online_yard_and_seated_segway", yard != null and rig != null and rig.is_seated()
		and yard.room_control_online(), "yard=%s rig=%s online=%s" % [yard, rig, yard.room_control_online() if yard != null else false])
	if yard == null or rig == null or not yard.room_control_online():
		_stop()
		_finish()
		return
	_check("yard_is_explicitly_handed_to_the_player_pointer", rig.world_pointer_targets.has(yard), "%s" % rig.world_pointer_targets)
	yard.endpoint_request_queued.connect(func(room_id: StringName, index: int, value: int):
		_requests.append({"room": room_id, "index": index, "value": value}))
	var index := 55
	var registry := yard.endpoint_registry(&"alpha")
	if index >= registry.size():
		_check("fixture_has_selected_endpoint", false, "%d endpoints" % registry.size())
		_stop()
		_finish()
		return
	var endpoint := registry[index] as Dictionary
	var target: Vector3 = (endpoint.get("position", Vector3.ZERO) as Vector3) \
		+ Vector3(0.0, DeviceYard.PODIUM.y * 0.22, -DeviceYard.PODIUM.z * 0.51)
	var hand_at := target + Vector3(0.0, 0.10, 1.20)
	# A dense MultiMesh can put another face slightly nearer along this real ray.  Keep
	# the address the yard resolves, rather than accidentally asserting a direct fixture
	# index and hiding an incorrect player-facing selection.
	var hit := yard.world_pointer_hit(hand_at, target - hand_at)
	index = int(hit.get("index", -1))
	rig.force_hand(RIGHT, Transform3D(Basis.looking_at(target - hand_at, Vector3.UP), hand_at))
	rig.force_input(RIGHT, Bind.TRIGGER, 0.0)
	await get_tree().process_frame
	_check("forced_hand_ray_selects_one_alpha_endpoint", not hit.is_empty() and index >= 0
		and yard.get_node_or_null("DevicePointerMarker") != null, "target=%s hit=%s" % [target, hit])
	var before := yard.room_state(&"alpha")
	rig.force_input(RIGHT, Bind.TRIGGER, 1.0)
	await get_tree().process_frame
	_check("player_trigger_queues_one_native_request", _requests.size() == 1
		and StringName(_requests[0].get("room", "")) == &"alpha" and int(_requests[0].get("index", -1)) == index,
		"%s" % _requests)
	_check("trigger_does_not_optimistically_change_the_panel", yard.room_state(&"alpha") == before,
		"before=%s after=%s" % [before, yard.room_state(&"alpha")])
	rig.force_input(RIGHT, Bind.TRIGGER, 0.0)
	var reflected := false
	for i in range(PATIENCE):
		await get_tree().physics_frame
		var values := yard.room_state(&"alpha")
		if index < values.size() and values[index] == 255:
			reflected = true
			break
	_check("authoritative_page_eventually_changes_the_selected_endpoint", reflected,
		"requests=%s values=%s" % [_requests, yard.room_state(&"alpha")])
	_check("bravo_stays_unchanged_from_alpha_player_press", yard.room_state(&"bravo").count(0) == yard.endpoint_count,
		"bravo=%s" % yard.room_state(&"bravo"))
	rig.force_hand(RIGHT, null)
	rig.force_input(RIGHT, Bind.TRIGGER, null)
	_stop()
	_finish()


func _stop() -> void:
	Sim.stop()
	Net.leave("device yard interaction suite over")


func _finish() -> void:
	print("[device_yard_interaction] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)
