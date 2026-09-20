extends Node
## Headless: SAVE BANDWIDTH ON THE HOST'S iPAD TURNS THE FAR-POSE LOD ON AND OFF, AND IS KEPT.
##
##   Godot --headless --xr-mode off --fixed-fps 120 --path cockpit res://tests/save_bandwidth.tscn
##
## The user, 2026-09-18: "let's keep bandwidth saving off by default, but make it an option in the ipad." The switch is on
## TRAFFIC; the level decides (`FlightLevel.choose_save_bandwidth` -> `Sim.set_save_bandwidth`), the server does it
## (`CockpitWorld.set_pose_lod`), and the host's own settings file keeps it.
##
## WHAT IS REAL. This process flies the island alone, which makes it the machine that decides what is sent, and the
## switch is pressed by the rig's own right-hand BEAM and trigger on the glass (`force_hand`, `force_input`), as
## tests/clipboard.gd presses its switches -- never `toggled.emit`. Every answer is read off the SERVER (`pose_lod()`) and
## the file, not off the switch. The joiner's half -- that a joiner's board has no such switch -- is in
## tests/sky_peers.gd, which has a real joiner to ask.
##
##   1. It starts off, with no settings file, and the switch is offered and off.
##   2. The beam turns it on: the server's LOD is on at Sim's distances, and the file says so.
##   3. The beam turns it off again: the server's LOD is off, and the file says so.
##   4. On once more, then a RESTART stood in for: the session stopped, the setting forgotten in memory and read back from
##      the file as boot reads it, and a fresh session's server comes up with the LOD on.
##
## THE PLAYER'S OWN SETTINGS ARE NEVER TOUCHED: `Sim.host_settings_path` points at this suite's own file first, and is put
## back after.
##
## Read RESULT=, not the exit code.

const FLIGHT: String = "island"
const TEST_PATH: String = "user://test_save_bandwidth_host_settings.json"
const LOCAL_SECONDS: float = 20.0

var _failures: PackedStringArray = []
var _path_was: String = ""


func _check(label: String, ok: bool, detail: String) -> void:
	print("[save_bandwidth] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## IT SURVIVES ITS OWN SCENE CHANGE into the level, by hanging a copy of this script on the root, as sky_peers does.
func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "SaveBandwidthWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	_path_was = Sim.host_settings_path
	# UNDER A TEST SCENE THE DEFAULT IS ALREADY THE SUITE'S FOLDER, as spotting.json's is: the override below is belt
	# and braces, and this is the braces.
	_check("a_suite_never_reads_the_players_file", _path_was.begins_with(CockpitLayout.TEST_FOLDER),
		"Sim.host_settings_path %s" % _path_was)
	Sim.host_settings_path = TEST_PATH
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Sim.load_host_settings()
	_check("with_no_settings_file_it_is_off", not Sim.save_bandwidth, "Sim.save_bandwidth %s" % Sim.save_bandwidth)

	var level: FlightLevel = await _fly_alone()
	if level == null:
		_finish()
		return
	var rig: PilotRig = level.rig
	rig.clipboard.show_board(true)
	var page: ClipboardPage = rig.clipboard.page()
	page.show_tab(ClipboardPage.Tab.TRAFFIC)
	await _frames(3)
	var switch: CheckButton = page.save_bandwidth_switch()
	_check("the_switch_is_offered_on_traffic", page.offers_save_bandwidth() and switch != null
		and switch.is_visible_in_tree(), "offered %s, switch %s" % [page.offers_save_bandwidth(), switch])
	_check("and_starts_off_with_the_server_off", switch != null and not switch.button_pressed and not _lod_on(),
		"switch %s, server %s" % [switch.button_pressed if switch != null else null, Sim.server.pose_lod()])
	if switch == null:
		_finish()
		return

	# 2: THE BEAM TURNS IT ON.
	await _beam_presses(rig, switch)
	await _physics(6)
	var on: Dictionary = Sim.server.pose_lod()
	_check("the_beam_turns_the_hosts_lod_on", bool(on.get("enabled", false))
		and is_equal_approx(float(on.get("near_m", 0.0)), Sim.POSE_NEAR_M)
		and is_equal_approx(float(on.get("far_m", 0.0)), Sim.POSE_FAR_M) and switch.button_pressed,
		"server %s, switch %s" % [on, switch.button_pressed])
	_check("and_it_is_written_down", _kept() == true, "file %s" % FileAccess.get_file_as_string(TEST_PATH))

	# 3: AND OFF AGAIN.
	await _beam_presses(rig, switch)
	await _physics(6)
	_check("the_beam_turns_it_off_again", not _lod_on() and not switch.button_pressed,
		"server %s, switch %s" % [Sim.server.pose_lod(), switch.button_pressed])
	_check("and_that_is_written_down_too", _kept() == false, "file %s" % FileAccess.get_file_as_string(TEST_PATH))

	# 4: ON, AND A RESTART.
	await _beam_presses(rig, switch)
	await _physics(6)
	_check("on_once_more", _lod_on(), "server %s" % Sim.server.pose_lod())
	rig.clipboard.show_board(false)
	Sim.stop()
	Sim.save_bandwidth = false
	Sim.load_host_settings()
	_check("read_back_as_boot_reads_it_it_is_on", Sim.save_bandwidth, "Sim.save_bandwidth %s" % Sim.save_bandwidth)
	var restarted: bool = Sim.start()
	await _physics(4)
	_check("a_fresh_sessions_server_comes_up_with_it_on", restarted and Sim.server != null and _lod_on(),
		"started %s, server %s" % [restarted, Sim.server.pose_lod() if Sim.server != null else null])
	_finish()


func _fly_alone() -> FlightLevel:
	_check("the_island_is_chosen", Net.choose_level(FLIGHT) == "", "Net.level %s" % Net.level)
	Net.play_solo()
	get_tree().change_scene_to_file("res://world/sky.tscn")
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(LOCAL_SECONDS * 1000.0):
		var level := get_tree().current_scene as FlightLevel
		if level != null and level.level != null and level.level.id == FLIGHT and Sim.is_ready and level.rig != null \
				and level.rig.is_seated() and Sim.server != null:
			return level
		await get_tree().physics_frame
	_check("this_machine_is_flying_the_island", false, "scene %s" % get_tree().current_scene)
	return null


func _lod_on() -> bool:
	return Sim.server != null and bool(Sim.server.pose_lod().get("enabled", false))


## What the file says, or null when it says nothing readable.
func _kept() -> Variant:
	if not FileAccess.file_exists(TEST_PATH):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	return (parsed as Dictionary).get("save_bandwidth", null) if parsed is Dictionary else null


## THE RIGHT HAND'S BEAM ON `target` AND THE TRIGGER PULLED AND LET GO, as tests/clipboard.gd's `_beam_presses`.
func _beam_presses(rig: PilotRig, target: Control) -> void:
	var centre: Vector2 = target.get_global_rect().get_center()
	for trigger in [0.0, 0.0, 1.0, 1.0, 0.0, 0.0]:
		var panel: TouchPanel = rig.clipboard.panel()
		var screen := panel.get("_screen") as SubViewport
		var on_glass := Vector3((centre.x / float(screen.size.x) - 0.5) * panel.size.x,
			(0.5 - centre.y / float(screen.size.y)) * panel.size.y, 0.0)
		var aimed_at: Vector3 = panel.to_global(on_glass)
		var hand_at: Vector3 = aimed_at + panel.global_basis.z.normalized() * 0.30
		rig.force_hand(1, Transform3D(Basis.looking_at(aimed_at - hand_at, panel.global_basis.y.normalized()), hand_at))
		rig.force_input(1, Bind.TRIGGER, trigger)
		await get_tree().process_frame
	rig.force_input(1, Bind.TRIGGER, null)
	rig.force_hand(1, null)
	await get_tree().process_frame


func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().process_frame


func _physics(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().physics_frame


func _finish() -> void:
	if _path_was != "":
		if FileAccess.file_exists(TEST_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
		Sim.host_settings_path = _path_was
		Sim.load_host_settings()
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
