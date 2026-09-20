extends Node
## Headless: a level is a folder, a broken one takes itself off the desk and says why, a joiner and a host can agree on
## one by its hash, `--world=` names one, and the desk's level row chooses one with a real mouse click and flies there.
##
##   Godot --headless --path cockpit res://tests/levels.tscn
##
## Asked for on 2026-09-15: "let's have multiple levels that can load." The folder is `levels/`, read by `ChartDrawer`
## and `LevelChart`; the session's level is `Net.level`.
##
## THE MALFORMED LEVELS ARE REAL FOLDERS, in `tests/level_fixtures/`, read from disk by the same scan the game does: a
## folder with no file, a file that is not JSON, a misspelt key, a world nothing builds, a folder name that is not an id,
## a level with nowhere to put anybody, a generated world wider than the wire, and a `_`-prefixed folder that is skipped rather than refused. Two good ones
## stand beside them, so the scan is shown to keep what it should while refusing the rest.
##
## THE DESK SECTION STARTS AT THE MOUSE. A real `InputEventMouseButton` at the level button's centre, projected through
## the desk camera and the viewport's final transform (the helpers `tests/desk_screens.gd` proved), then another on "Fly
## on your own", and then the question is asked of the WORLD: which level did it build, and where did it put this
## machine's pod. The second good level spawns 580 m from the first, so a desk that ignored the press flies the pod to
## the wrong place, and the check says how far.
##
## IT SURVIVES ITS OWN SCENE CHANGE the way tests/session.gd does: the scene's root hangs a copy of this script on /root.
##
## Read RESULT=, not the exit code.

const FIXTURES: String = "res://tests/level_fixtures"
## Frames to wait for a scene and a session: ten seconds at the project's 120 Hz.
const PATIENCE: int = 1200
## The bare host a refused joiner knocks on: the lane's own range, off every other suite's.
## 47952 of this checkout's block (`TestPorts`), asked silently at load whether anything holds it: a fixed
## number was the same socket in every lane. Held, and the suite says PORT BUSY at once rather than timing out.
static var REFUSED_PORT: int = TestPorts.first_free(47952, 1)

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[levels] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if REFUSED_PORT == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(47952, 1))
		get_tree().quit(1)
		return
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "LevelsWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	_the_game_s_levels_are_its_folders()
	_a_malformed_level_disables_itself_with_a_message()
	_the_hash_is_of_what_the_file_says()
	_the_command_line_names_a_level()
	if ClassDB.class_exists("CockpitWorld"):
		await _the_desk_chooses_a_level_with_the_mouse_and_flies_there()
		await _a_joiner_refused_in_the_world_is_taken_back_to_the_desk_and_told_why()
		await _a_joiner_whose_host_leaves_is_taken_back_to_the_desk_and_told_so()
	else:
		_check("extension_loaded", false, "CockpitWorld missing")
	_check("every_section_of_the_suite_ran", _sections == 7, "%d of 7" % _sections)
	_finish()


## ---- 1: the game's own folder ------------------------------------------------------------------------------------

func _the_game_s_levels_are_its_folders() -> void:
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	var usable: Array[LevelChart] = ChartDrawer.charts()
	var refused: Array[LevelChart] = ChartDrawer.refused()
	var folders: PackedStringArray = []
	for id in DirAccess.get_directories_at(ChartDrawer.FOLDER):
		if not id.begins_with("_"):
			folders.append(id)
	folders.sort()
	var read: PackedStringArray = []
	for chart in usable + refused:
		read.append(chart.id)
	read.sort()
	_check("every_level_folder_is_read_as_a_level", read == folders, "folders %s, read %s" % [folders, read])
	_check("and_the_default_is_on_the_desk_and_first", not usable.is_empty() and usable[0].id == ChartDrawer.DEFAULT,
		"usable %s" % [_ids(usable)])
	var incomplete: PackedStringArray = []
	var hex := RegEx.create_from_string("^[0-9a-f]{64}$")
	for chart in usable:
		if chart.name == "" or chart.summary == "" or hex.search(chart.content_hash) == null:
			incomplete.append(chart.id)
	_check("and_every_usable_one_has_a_name_a_summary_and_a_hash", incomplete.is_empty(), "%s" % [incomplete])
	var silent: PackedStringArray = []
	for chart in refused:
		print("[levels] refused %s: %s" % [chart.id, chart.refusal])
		if chart.refusal == "":
			silent.append(chart.id)
	_check("and_every_refused_one_says_why", silent.is_empty(), "%d refused, %s silent" % [refused.size(), silent])
	var island: LevelChart = ChartDrawer.chart(ChartDrawer.DEFAULT)
	var island_file: String = FileAccess.get_file_as_string(ChartDrawer.FOLDER.path_join(ChartDrawer.DEFAULT).path_join(
		LevelChart.FILE))
	_check("and_the_island_still_says_nothing_about_water", island != null and island.water.is_empty()
		and not island_file.contains("\"water\""),
		"water %s in %s" % [island.water if island != null else "-", ChartDrawer.DEFAULT])
	_sections += 1


## ---- 2: the broken ones ------------------------------------------------------------------------------------------

func _a_malformed_level_disables_itself_with_a_message() -> void:
	ChartDrawer.open_at(FIXTURES)
	_check("the_good_levels_beside_the_broken_ones_are_kept", _ids(ChartDrawer.charts()) == PackedStringArray(
		["good_a", "good_b"]), "%s" % [_ids(ChartDrawer.charts())])
	var expected: Dictionary = {
		"Bad-Id": "is not a level id",
		"no_file": "there is no level.json",
		"not_json": "is not JSON",
		"typo_key": "'spwan' is not a key a level has",
		"unknown_world": "its world 'mars' is not one this build stands a level on",
		"no_spawn": "it has no spawn",
		"bad_ground": "its ground will not stand: world_half 99999 clamped to",
	}
	var said: Dictionary = {}
	for chart in ChartDrawer.refused():
		said[chart.id] = chart.refusal
	for id in expected:
		_check("%s_is_refused_in_words" % String(id).to_lower().replace("-", "_"),
			String(said.get(id, "")).contains(String(expected[id])), "'%s'" % said.get(id, "(not refused)"))
	_check("and_every_refusal_is_one_of_those", said.size() == expected.size(), "%s" % [said.keys()])
	_check("and_an_underscore_folder_is_skipped_not_refused",
		not said.has("_parked") and ChartDrawer.chart("_parked") == null, "refused %s" % [said.keys()])
	var b: LevelChart = ChartDrawer.chart("good_b")
	_check("and_a_level_says_where_its_first_pod_goes",
		b != null and b.spawn_at == Vector3(412.0, 60.0, -388.0) and is_equal_approx(b.spawn_yaw, PI * 0.5),
		"at %s yaw %s" % [b.spawn_at if b != null else "-", b.spawn_yaw if b != null else "-"])
	_a_level_may_name_the_seas_colours()
	_sections += 1


## THE SEA'S COLOURS, as `haze` and `cloud_cover` are: optional, in the level's own words when refused, and a
## misspelling is a refusal because a key the file does not know would otherwise fly on navy blue.
func _a_level_may_name_the_seas_colours() -> void:
	var named := LevelChart.new()
	named._take(_sheet({"water": {"deep": [0.012, 0.078, 0.102], "crest": [0.035, 0.155, 0.140],
		"foam": [0.88, 0.93, 0.92]}}))
	_check("a_level_may_name_the_seas_colours", named.usable()
		and (named.water.get("deep", Vector3.INF) as Vector3).is_equal_approx(Vector3(0.012, 0.078, 0.102))
		and (named.water.get("crest", Vector3.INF) as Vector3).is_equal_approx(Vector3(0.035, 0.155, 0.140))
		and (named.water.get("foam", Vector3.INF) as Vector3).is_equal_approx(Vector3(0.88, 0.93, 0.92)),
		"water %s, '%s'" % [named.water, named.refusal])
	var partial := LevelChart.new()
	partial._take(_sheet({"water": {"deep": [0.2, 0.3, 0.4]}}))
	_check("and_a_missing_channel_is_the_shaders_own", partial.usable()
		and (partial.water.get("deep", Vector3.INF) as Vector3).is_equal_approx(Vector3(0.2, 0.3, 0.4))
		and not partial.water.has("crest") and not partial.water.has("foam"),
		"water %s, '%s'" % [partial.water, partial.refusal])
	var empty := LevelChart.new()
	empty._take(_sheet({"water": {}}))
	_check("and_an_empty_water_object_names_none", empty.usable() and empty.water.is_empty(), "'%s'" % empty.refusal)
	var silent := LevelChart.new()
	silent._take(_sheet({}))
	_check("and_a_level_that_says_nothing_has_no_colours", silent.usable() and silent.water.is_empty(),
		"water %s, '%s'" % [silent.water, silent.refusal])
	var watre := LevelChart.new()
	watre._take(_sheet({"watre": {"deep": [0.1, 0.2, 0.3]}}))
	_check("a_misspelt_watre_is_refused_in_words", not watre.usable() and watre.refusal.contains("'watre' is not a key"),
		"'%s'" % watre.refusal)
	var glow := LevelChart.new()
	glow._take(_sheet({"water": {"glow": [0.1, 0.2, 0.3]}}))
	_check("an_unknown_channel_is_refused_in_words", not glow.usable() and glow.refusal.contains("'glow' is not a key"),
		"'%s'" % glow.refusal)
	var two := LevelChart.new()
	two._take(_sheet({"water": {"deep": [0.1, 0.2]}}))
	_check("a_channel_that_is_not_three_numbers_is_refused", not two.usable() and two.refusal.contains("deep"),
		"'%s'" % two.refusal)
	var past := LevelChart.new()
	past._take(_sheet({"water": {"deep": [0.0, 0.0, 1.1]}}))
	_check("a_channel_past_one_is_refused", not past.usable() and past.refusal.contains("from 0 to 1"),
		"'%s'" % past.refusal)
	var words := LevelChart.new()
	words._take(_sheet({"water": "blue"}))
	_check("a_water_that_is_not_an_object_is_refused", not words.usable() and words.refusal.contains("not an object"),
		"'%s'" % words.refusal)
	var with_water := _sheet({"water": {"deep": [0.1, 0.2, 0.3]}})
	var without := _sheet({})
	_check("the_colours_are_part_of_what_a_joiner_checks",
		LevelChart.canonical_hash(with_water) != LevelChart.canonical_hash(without),
		"%s against %s" % [LevelChart.canonical_hash(with_water).left(8), LevelChart.canonical_hash(without).left(8)])


## ---- 3: the hash ------------------------------------------------------------------------------------------------

## WHAT THE FILE SAYS, NOT ITS BYTES: a checkout with CRLF line ends and different indentation agrees with the LF one,
## key order means nothing, and a spawn moved by a metre is a different level.
func _the_hash_is_of_what_the_file_says() -> void:
	var a: Dictionary = {"name": "X", "summary": "Y", "world": "island", "spawn": {"at": [1, 2, 3], "yaw_degrees": 0}}
	var b: Dictionary = {"spawn": {"yaw_degrees": 0, "at": [1, 2, 3]}, "world": "island", "summary": "Y", "name": "X"}
	_check("the_hash_ignores_key_order", LevelChart.canonical_hash(a) == LevelChart.canonical_hash(b), "")
	var moved: Dictionary = a.duplicate(true)
	(moved["spawn"] as Dictionary)["at"] = [1, 2, 4]
	_check("and_sees_a_value_changed", LevelChart.canonical_hash(a) != LevelChart.canonical_hash(moved), "")
	ChartDrawer.open_at(FIXTURES)
	var on_disk: LevelChart = ChartDrawer.chart("good_a")
	var text: String = FileAccess.get_file_as_string(FIXTURES.path_join("good_a").path_join(LevelChart.FILE))
	var windows: String = text.replace("\r\n", "\n").replace("\t", "    ").replace("\n", "\r\n")
	var parsed: Variant = JSON.parse_string(windows)
	_check("and_a_crlf_checkout_of_the_same_file_agrees",
		on_disk != null and parsed is Dictionary and windows != text
			and LevelChart.canonical_hash(parsed as Dictionary) == on_disk.content_hash,
		"%s against %s" % [LevelChart.canonical_hash(parsed as Dictionary) if parsed is Dictionary else "unparsed",
			on_disk.content_hash if on_disk != null else "no good_a"])
	_sections += 1


## ---- 4: the command line --------------------------------------------------------------------------------------

func _the_command_line_names_a_level() -> void:
	ChartDrawer.open_at(FIXTURES)
	var cases: Array = [
		[["--world=good_b"], "none", "good_b", ""],
		[["--host=5000", "--world=good_b"], "host", "good_b", ""],
		[["--level=world", "--kind=cessna"], "none", "", ""],
		[["--world=nowhere"], "none", "", "--world=nowhere is not a level: good_a, good_b"],
		[["--world=good_a"], "join", "", "--world= cannot go with a join: a joiner flies the host's level"],
		[["--world=good_a"], "steam_code", "", "--world= cannot go with a join: a joiner flies the host's level"],
	]
	for case in cases:
		var got: Dictionary = ChartDrawer.asked_in(PackedStringArray(case[0]), String(case[1]))
		_check("world_flag_%s_%s" % [" ".join(case[0]).replace("-", "").replace("=", "_").replace(" ", "_"), case[1]],
			String(got["id"]) == String(case[2]) and String(got["error"]) == String(case[3]), "%s" % [got])
	_sections += 1


## ---- 5: the desk ---------------------------------------------------------------------------------------------------

func _the_desk_chooses_a_level_with_the_mouse_and_flies_there() -> void:
	ChartDrawer.open_at(FIXTURES)
	Sim.stop()
	Net.leave("suite")
	var took: String = Net.choose_level("good_a")
	_check("a_level_can_be_chosen_before_a_session", took == "" and Net.level == "good_a", "'%s'" % took)
	await _open("res://world/desk.tscn")
	for i in range(6):
		await get_tree().process_frame
	var desk := get_tree().current_scene as DeskRoom
	var panel: TouchPanel = desk.get("_panel") as TouchPanel if desk != null else null
	var menu := panel.shown() as SessionMenu if panel != null else null
	# THE LEVELS ARE ON A SCREEN OF THEIR OWN since 2026-09-15 (`ChartMenu`), left of the session screen.
	var shelf: TouchPanel = desk.get("_charts") as TouchPanel if desk != null else null
	var charts := shelf.shown() as ChartMenu if shelf != null else null
	var rig: PilotRig = desk.get("_rig") as PilotRig if desk != null else null
	if menu == null or charts == null or rig == null:
		_check("the_desk_has_its_session_and_levels_screens", false, "desk %s menu %s levels %s rig %s" % [desk, menu,
			charts, rig])
		_sections += 1
		return
	_check("the_levels_screen_offers_every_usable_level_and_no_other",
		charts.level_buttons.keys() == ["good_a", "good_b"], "%s" % [charts.level_buttons.keys()])
	await _click(rig, shelf, charts.level_buttons.get("good_b") as Button)
	_check("a_mouse_click_on_a_level_chooses_it", Net.level == "good_b", "Net.level %s" % Net.level)
	var chosen := charts.level_buttons.get("good_b") as Button
	_check("and_the_chosen_level_is_drawn_amber_even_hovered",
		chosen != null and chosen.get_theme_color("font_hover_color") == ChartMenu.AMBER
			and (charts.level_buttons.get("good_a") as Button).get_theme_color("font_color") != ChartMenu.AMBER,
		"good_b hover %s" % [chosen.get_theme_color("font_hover_color") if chosen != null else "-"])
	var said := charts.get("_said") as Label
	_check("and_the_screen_says_it_is_the_level_the_next_session_flies",
		said != null and said.text.contains(ChartDrawer.chart("good_b").name), "'%s'" % [said.text if said != null else "-"])
	await _click(rig, panel, _button(menu, "Fly on your own"))
	var arrived: bool = await _wait_for(func() -> bool:
		return get_tree().current_scene is FlightLevel and Sim.is_ready and _my_pod() != 0)
	var level := get_tree().current_scene as FlightLevel
	_check("and_flying_solo_lands_in_a_world_on_that_level",
		arrived and level != null and level.level != null and level.level.id == "good_b",
		"arrived %s level %s" % [arrived, level.level.id if level != null and level.level != null else "-"])
	var pod: int = _my_pod()
	var at: Vector3 = (Sim.current.get(pod, {}) as Dictionary).get("position", Vector3.INF)
	var off: float = Vector2(at.x - 412.0, at.z + 388.0).length()
	_check("and_this_machine_s_pod_is_put_at_that_level_s_spawn", off < 20.0,
		"pod %d at %s, %.1f m from the spawn across the ground" % [pod, at, off])
	_sections += 1


## ---- 6: refused in the world --------------------------------------------------------------------------------

## A JOINER REFUSED AFTER IT HAS LOADED GOES BACK TO THE DESK, AND THE DESK SAYS WHY (team-lead, 2026-09-15). The host
## is a bare socket on the loopback and speaks through `Net.hear_hello`: it names a level the joiner has, the joiner's
## world comes up, and then the host refuses it the way a host with other ground does. Before, the joiner stayed in a
## world with no simulation and a status line.
func _a_joiner_refused_in_the_world_is_taken_back_to_the_desk_and_told_why() -> void:
	ChartDrawer.open_at(FIXTURES)
	Sim.stop()
	Net.leave("suite")
	var host := ENetMultiplayerPeer.new()
	var err: int = host.create_server(REFUSED_PORT, 4)
	Net.join("127.0.0.1", REFUSED_PORT)
	var asking: bool = false
	for i in range(PATIENCE):
		host.poll()
		if String(Net.get("_stage")) == "hello":
			asking = true
			break
		await get_tree().physics_frame
	var good_a: LevelChart = ChartDrawer.chart("good_a")
	Net.hear_hello(1, JSON.stringify({"say": "level", "protocol": Net.PROTOCOL, "level": good_a.id,
		"hash": good_a.content_hash, "name": good_a.name}).to_utf8_buffer())
	get_tree().change_scene_to_file("res://world/sky.tscn")
	var flying: bool = false
	for i in range(PATIENCE):
		host.poll()
		if get_tree().current_scene is FlightLevel and (get_tree().current_scene as FlightLevel).level != null:
			flying = true
			break
		await get_tree().physics_frame
	_check("a_joiner_told_a_level_it_has_is_flying_it", err == OK and asking and flying and Net.is_in_session,
		"host %s, asking %s, flying %s, in session %s" % [error_string(err), asking, flying, Net.is_in_session])
	var why: String = "The ground under your Good A is not the host's: the two builds make it differently."
	Net.hear_hello(1, JSON.stringify({"say": "refused", "why": why}).to_utf8_buffer())
	var back: bool = false
	for i in range(PATIENCE):
		host.poll()
		var arrived := get_tree().current_scene as DeskRoom
		if arrived != null and arrived.get("_menu") != null:
			back = true
			break
		await get_tree().physics_frame
	for i in range(6):
		await get_tree().process_frame
	var desk := get_tree().current_scene as DeskRoom
	var said := (desk.get("_menu") as SessionMenu).get("_said") as Label if back else null
	_check("and_refused_there_it_is_taken_back_to_the_desk", back and not Net.is_in_session,
		"scene %s, in session %s" % [get_tree().current_scene, Net.is_in_session])
	_check("and_the_desk_says_why", said != null and said.text == why, "'%s'" % [said.text if said != null else "-"])
	_check("and_says_it_once", Net.parting_words == "", "'%s'" % Net.parting_words)
	for i in range(10):
		host.poll()
		await get_tree().physics_frame
	host.close()
	_sections += 1


## ---- 7: the host gone -------------------------------------------------------------------------------------------

## A JOINER WHOSE HOST LEAVES GOES BACK TO THE DESK, AND THE DESK SAYS SO: the same door as a refusal, since neither was
## the player's choice. The bare host drops the joiner's peer while it flies; Net hears `server_disconnected`.
func _a_joiner_whose_host_leaves_is_taken_back_to_the_desk_and_told_so() -> void:
	ChartDrawer.open_at(FIXTURES)
	Sim.stop()
	Net.leave("suite")
	for i in range(10):
		await get_tree().physics_frame
	var host := ENetMultiplayerPeer.new()
	var err: int = host.create_server(REFUSED_PORT, 4)
	var arrived: Array[int] = []
	host.peer_connected.connect(func(id: int) -> void: arrived.append(id))
	Net.join("127.0.0.1", REFUSED_PORT)
	for i in range(PATIENCE):
		host.poll()
		if String(Net.get("_stage")) == "hello" and not arrived.is_empty():
			break
		await get_tree().physics_frame
	var good_a: LevelChart = ChartDrawer.chart("good_a")
	Net.hear_hello(1, JSON.stringify({"say": "level", "protocol": Net.PROTOCOL, "level": good_a.id,
		"hash": good_a.content_hash, "name": good_a.name}).to_utf8_buffer())
	get_tree().change_scene_to_file("res://world/sky.tscn")
	var flying: bool = false
	for i in range(PATIENCE):
		host.poll()
		if get_tree().current_scene is FlightLevel and (get_tree().current_scene as FlightLevel).level != null:
			flying = true
			break
		await get_tree().physics_frame
	_check("a_joiner_is_flying_its_hosts_level", err == OK and flying and not arrived.is_empty() and Net.is_in_session,
		"host %s, flying %s, peers %s, in session %s" % [error_string(err), flying, arrived, Net.is_in_session])
	if not arrived.is_empty():
		host.disconnect_peer(arrived[0])
	var back: bool = false
	for i in range(PATIENCE):
		host.poll()
		var there := get_tree().current_scene as DeskRoom
		if there != null and there.get("_menu") != null:
			back = true
			break
		await get_tree().physics_frame
	for i in range(6):
		await get_tree().process_frame
	var desk := get_tree().current_scene as DeskRoom
	var said := (desk.get("_menu") as SessionMenu).get("_said") as Label if back else null
	_check("and_when_its_host_leaves_it_is_taken_back_to_the_desk", back and not Net.is_in_session,
		"scene %s, in session %s" % [get_tree().current_scene, Net.is_in_session])
	# THE HOST WENT WITHOUT A WORD (a bare socket dropping the peer), and the desk says exactly that, with where. It said
	# "Host left" until the handshake (2026-09-18), which read as though the host had said something.
	_check("and_the_desk_says_the_host_left", said != null and said.text.begins_with(
		"Lost the host at 127.0.0.1:%d without a reason" % REFUSED_PORT),
		"'%s'" % [said.text if said != null else "-"])
	host.close()
	for i in range(10):
		await get_tree().physics_frame
	_sections += 1


## ---- the machinery -------------------------------------------------------------------------------------------

func _my_pod() -> int:
	var me: int = Sim.local_client_id()
	for row in Sim.pilots:
		if me != 0 and int((row as Dictionary).get("client", 0)) == me:
			return int((row as Dictionary).get("vehicle", 0))
	return 0


## A VALID LEVEL DICTIONARY, with optional extra keys, so each refusal below starts from the same sheet.
static func _sheet(extra: Dictionary = {}) -> Dictionary:
	var data := {"name": "A level", "summary": "A level for a test.", "world": "island",
		"spawn": {"at": [0, 30, 0], "yaw_degrees": 0}}
	for key in extra:
		data[key] = extra[key]
	return data


func _ids(charts: Array[LevelChart]) -> PackedStringArray:
	var out: PackedStringArray = []
	for chart in charts:
		out.append(chart.id)
	return out


func _button(within: Node, starting: String) -> Button:
	for node in within.find_children("*", "Button", true, false):
		if String((node as Button).text).begins_with(starting):
			return node as Button
	return null


## A REAL CLICK: the mouse moved to the button's centre on its glass, in window coordinates, pressed and let go. The
## projection is `tests/desk_screens.gd`'s.
func _click(rig: PilotRig, panel: TouchPanel, button: Button) -> void:
	if button == null:
		_check("there_is_a_button_to_click", false, "none")
		return
	var screen := panel.get("_screen") as SubViewport
	var pixel: Vector2 = button.get_global_rect().get_center()
	var on_glass := Vector3((pixel.x / float(screen.size.x) - 0.5) * panel.size.x,
		(0.5 - pixel.y / float(screen.size.y)) * panel.size.y, 0.0)
	var camera: Camera3D = rig.desktop_camera
	var window_at: Vector2 = camera.get_viewport().get_final_transform() * camera.unproject_position(
		panel.to_global(on_glass))
	var motion := InputEventMouseMotion.new()
	motion.position = window_at
	motion.global_position = window_at
	Input.parse_input_event(motion)
	for i in range(2):
		await get_tree().process_frame
	for down in [true, false]:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = down
		press.position = window_at
		press.global_position = window_at
		Input.parse_input_event(press)
		for i in range(2):
			await get_tree().process_frame


func _wait_for(until: Callable) -> bool:
	for i in range(PATIENCE):
		if until.call():
			return true
		await get_tree().physics_frame
	return until.call()


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)
	for i in range(PATIENCE):
		await get_tree().physics_frame
		var now: Node = get_tree().current_scene
		if now != null and now.scene_file_path == path:
			await get_tree().physics_frame
			return


func _finish() -> void:
	Sim.stop()
	Net.leave("suite over")
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
