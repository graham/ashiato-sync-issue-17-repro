extends Node
## Headless: a world loaded and let go gives back what it took, level after level.
##
##   Godot --headless --path cockpit res://tests/level_swap.tscn
##
## Asked for on 2026-09-15 with the levels: "loading and unloading must free the old world's scenery yard, ground
## collision and nodes, with no leak: measure memory across island -> alpine -> island." So this goes round every usable
## level the way a player does -- the level chosen on the desk, "Fly on your own", the world built and flown for a few
## seconds, then MAIN MENU's own door back to the desk -- five times, and reads the process at the desk after each.
##
## WHAT IS COMPARED is the desk after the same level, one round apart: the third visit against the first, the fifth
## against the third. The first round is not the baseline, because a first load fills caches that live for the
## process (shaders, the board's theme, `Sim`'s shape world); a leak is growth that goes on after that, round on round.
## Every usable level is in the round, so the alpine world is swapped as soon as this build can stand it.
##
## AND THE DESK HOLDS NO SIMULATION. Until 2026-09-15 MAIN MENU only changed scene, and `Sim` went on ticking the old
## world's collision under the menu.
##
## Read RESULT=, not the exit code.

const PATIENCE: int = 2400
## Frames at the desk before reading it: queued frees flushed, and a yard's worker threads given time to join.
const SETTLE: int = 90
## Seconds of flight in each world, so the yards have built round the eye and there is something to let go of.
const FLY_FRAMES: int = 360
## HOW MUCH TWO ROUNDS MAY GROW, measured before it was set (2026-09-15, island, double editor): 277 nodes, 2,537 objects
## and 0 orphans after every one of five rounds, and static memory up 95 kB and 125 kB over rounds 0-2 and 2-4. A world
## that kept its `WorldMap` in a static grew 1 object and about 1 MB a round, and passed an allowance of 64 objects and
## 4 MB: so none, and half a megabyte, four times the most measured.
##
## THE MEMORY ALLOWANCE IS PER LEVEL FLOWN, AND IT WAS A FLAT HALF-MEGABYTE UNTIL 2026-09-17. A ROUND IS EVERY USABLE
## LEVEL, so the flat number was measured when a round was ONE island and quietly became a seventh of its original
## generosity as levels were added. Measured that day on an idle desk, each figure a whole run of five rounds:
##
##   seven levels   122.48 -> 123.19 MB over rounds 0-2, then 123.19 -> 123.20 over 2-4   (0.71 then 0.01)
##   six levels     122.54 -> 122.78 MB over rounds 0-2, then 122.78 -> 123.26 over 2-4   (0.24 then 0.48)
##
## THE SAME 0.72 MB IN TOTAL EITHER WAY, differently distributed: it is a one-off fill that lands earlier when a round
## builds more worlds, and not a leak, which would have gone on growing between rounds 2 and 4 and did not. The
## seven-level run crossed a flat half-megabyte and the six-level one came within 0.02 MB of it, so the next level
## anybody added was going to trip this whichever it was.
##
## 0.25 MB a level is two and a half times the worst measured (0.71 over seven levels is 0.10 each). THE LEAK
## DETECTORS ARE THE NODE AND OBJECT COUNTS, which allow NOTHING and caught the `WorldMap` static; this number is a
## backstop against something large, not the primary check.
const NODES_MAY_GROW: int = 0
const OBJECTS_MAY_GROW: int = 0
const STATIC_MAY_GROW_PER_LEVEL: int = 256 * 1024

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[level_swap] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if get_tree().current_scene != self:
		_run()
		return
	var watcher := Node.new()
	watcher.name = "SwapWatch"
	watcher.set_script(get_script())
	get_tree().root.add_child.call_deferred(watcher)


func _run() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	var round: PackedStringArray = []
	for chart in ChartDrawer.charts():
		round.append(chart.id)
	var readings: Array[Dictionary] = []
	for visit in range(5):
		for id in round:
			var flew: bool = await _fly(id)
			if not flew:
				_check("visit_%d_to_%s_flew" % [visit, id], false, "the world never came up")
				_finish()
				return
		await _back_to_the_desk()
		var reading: Dictionary = _read_the_process()
		reading["visit"] = visit
		readings.append(reading)
		print("[level_swap] after round %d (%s): %s" % [visit, ", ".join(round), reading])
	_check("every_usable_level_was_flown", round.size() == ChartDrawer.charts().size() and not round.is_empty(),
		"%s" % [round])
	_check("the_desk_holds_no_simulation", Sim.client == null and Sim.server == null and not Net.is_in_session,
		"client %s server %s in_session %s" % [Sim.client != null, Sim.server != null, Net.is_in_session])
	for later in [2, 4]:
		var was: Dictionary = readings[later - 2]
		var now: Dictionary = readings[later]
		_check("round_%d_holds_no_more_nodes_than_round_%d" % [later, later - 2],
			int(now["nodes"]) - int(was["nodes"]) <= NODES_MAY_GROW, "%d -> %d" % [was["nodes"], now["nodes"]])
		_check("round_%d_leaves_no_more_orphan_nodes_than_round_%d" % [later, later - 2],
			int(now["orphans"]) <= int(was["orphans"]), "%d -> %d" % [was["orphans"], now["orphans"]])
		_check("round_%d_holds_no_more_objects_than_round_%d" % [later, later - 2],
			int(now["objects"]) - int(was["objects"]) <= OBJECTS_MAY_GROW,
			"%d -> %d, %d allowed" % [was["objects"], now["objects"], OBJECTS_MAY_GROW])
		var allowed: int = STATIC_MAY_GROW_PER_LEVEL * maxi(round.size(), 1)
		_check("round_%d_holds_no_more_memory_than_round_%d" % [later, later - 2],
			int(now["static"]) - int(was["static"]) <= allowed,
			"%.2f -> %.2f MB, %.2f allowed for %d levels" % [float(was["static"]) / 1048576.0,
				float(now["static"]) / 1048576.0, float(allowed) / 1048576.0, round.size()])
	_finish()


## THE WAY A PLAYER FLIES A LEVEL: at the desk, the level's button on the levels screen, then "Fly on your own" on the
## session screen, each the real button its screen built, pressed as a press emits.
func _fly(id: String) -> bool:
	if not get_tree().current_scene is DeskRoom:
		await _back_to_the_desk()
	var desk := get_tree().current_scene as DeskRoom
	var panel := desk.get("_panel") as TouchPanel if desk != null else null
	var menu := panel.shown() as SessionMenu if panel != null else null
	var shelf := desk.get("_charts") as TouchPanel if desk != null else null
	var charts := shelf.shown() as ChartMenu if shelf != null else null
	if menu == null or charts == null or not charts.level_buttons.has(id):
		return false
	(charts.level_buttons[id] as Button).pressed.emit()
	for node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == "Fly on your own":
			(node as Button).pressed.emit()
			break
	var up: bool = await _wait_for(func() -> bool:
		var level := get_tree().current_scene as FlightLevel
		return level != null and level.level != null and level.level.id == id and Sim.is_ready)
	for i in range(FLY_FRAMES):
		await get_tree().physics_frame
	return up


## MAIN MENU's own door, `Doors.to_the_desk`, and the desk given time to settle.
func _back_to_the_desk() -> void:
	Doors.to_the_desk()
	await _wait_for(func() -> bool:
		var desk := get_tree().current_scene as DeskRoom
		return desk != null and desk.get("_menu") != null)
	for i in range(SETTLE):
		await get_tree().process_frame


func _read_the_process() -> Dictionary:
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
	}


func _wait_for(until: Callable) -> bool:
	for i in range(PATIENCE):
		if until.call():
			return true
		await get_tree().physics_frame
	return until.call()


func _finish() -> void:
	Sim.stop()
	Net.leave("suite over")
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
