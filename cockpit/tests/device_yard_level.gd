extends Node
## Headless: the real session path loads the Device Yard, seats a player in a Segway, and puts both endpoint banks in
## the same world. This complements device_yard.gd's pure layout checks; a builder that only constructs off-tree can be
## correct while `Sky` still instantiates the briefing room.

const PATIENCE := 1200
var _failures: PackedStringArray = []

func _check(label: String, ok: bool, detail: String) -> void:
	print("[device_yard_level] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: _failures.append(label)

func _ready() -> void:
	if get_tree().current_scene != self:
		await _run()
		return
	var watcher := Node.new()
	watcher.name = "DeviceYardLevelWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)

func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	Sim.stop()
	Net.leave("device yard suite")
	for i in range(10): await get_tree().physics_frame
	_check("the_session_may_choose_the_device_yard", Net.choose_level(DeviceYard.LEVEL_ID) == "", Net.choose_level(DeviceYard.LEVEL_ID))
	get_tree().change_scene_to_file("res://world/sky.tscn")
	var flying: FlightLevel = null
	for i in range(PATIENCE):
		flying = get_tree().current_scene as FlightLevel
		if flying != null and flying.device_yard != null and flying.rig != null and flying.rig.is_seated():
			break
		await get_tree().physics_frame
	var yard: DeviceYard = flying.device_yard if flying != null else null
	var rig_kind: int = flying.rig.vehicle_view().kind if flying != null and flying.rig != null and flying.rig.vehicle_view() != null else -1
	_check("the_real_level_seats_the_player_in_a_segway", rig_kind == Sim.Kind.SEGWAY, Sim.kind_name(rig_kind))
	_check("the_real_level_instantiates_two_room_banks", yard != null and flying.room == null
		and yard.get_node_or_null("DeviceBodies_alpha") != null and yard.get_node_or_null("DeviceBodies_bravo") != null,
		"yard %s, briefing room %s" % [yard, flying.room])
	var report: Dictionary = yard.report() if yard != null else {}
	_check("the_default_level_exposes_100_endpoints_per_room", int(report.get("endpoints_per_room", 0)) == 100
		and int(report.get("endpoints_total", 0)) == 200, "%s" % report)
	Sim.stop()
	Net.leave("device yard suite over")
	_finish()

func _finish() -> void:
	print("[device_yard_level] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)
