extends Node
## THE FLIGHT RECORDER WRITES WHAT WAS FLOWN, and the file reads back: a real Cessna on its autopilot flies five seconds
## with `CraftTrace` on, and the file is opened again and judged.
##
##   Godot --headless --fixed-fps 120 --xr-mode off --path cockpit res://tests/trace_log.tscn
##
## THE DATUM IS THE SIMULATION'S OWN `vehicle_states()`, recorded here on the same tick and compared with the file's line for
## that tick; the recorder is not asked what it wrote. The sample count is worked out from the rate and the seconds, typed
## here. Nothing is written into the repository: the folder is under the run's temp directory.
##
## Read RESULT=, not the exit code.

const SECONDS: float = 5.0
const RATE: float = 60.0
const TICK_HZ: float = 120.0

var _failed := false
var _said: Array[String] = []
var _seen: Array = []
var _recording := false
var _cessna := 0
var _plane := 0


func _ready() -> void:
	if not Sim.is_available():
		_check("the_extension_is_there", false, "no CockpitWorld")
		_finish()
		return
	var folder: String = OS.get_environment("TEMP").path_join("trace_log_%d" % OS.get_process_id()).replace("\\", "/")
	await _start()
	Sim.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(7200.0, 400.0, 7200.0))
	_refusals(folder)
	_off(folder)
	await _flight(folder)
	await _cap(folder + "_cap")
	_finish()


## ---- A REFUSAL IS IN WORDS, and no recorder starts -----------------------------------------------------------------

func _refusals(folder: String) -> void:
	var bad_rate: CraftTrace = CraftTrace.make("cessna", folder, "abc")
	_check("a_rate_that_is_no_number_is_refused", bad_rate.refusal.contains("--trace-hz"), bad_rate.refusal)
	var fast: CraftTrace = CraftTrace.make("cessna", folder, "500")
	_check("a_rate_above_the_tick_is_refused", fast.refusal.contains("above the tick"), fast.refusal)
	var zero: CraftTrace = CraftTrace.make("cessna", folder, "0")
	_check("a_zero_rate_is_refused", not zero.refusal.is_empty(), zero.refusal)
	var nobody: CraftTrace = CraftTrace.make("wombat", folder, "")
	_check("a_craft_that_is_nothing_is_refused", nobody.refusal.contains("names no craft"), nobody.refusal)
	# A FILE where the folder should be: a directory cannot be made on it.
	var blocker: String = folder + "_blocker"
	var made := FileAccess.open(blocker, FileAccess.WRITE)
	made.store_string("x")
	made.close()
	var unwritable: CraftTrace = CraftTrace.make("cessna", blocker.path_join("inside"), "")
	_check("a_folder_that_cannot_be_made_is_refused", unwritable.refusal.contains("is a file"), unwritable.refusal)
	for one in [bad_rate, fast, zero, nobody, unwritable]:
		one.free()
	DirAccess.remove_absolute(blocker)


## ---- OFF WRITES NOTHING, and there is nothing there to cost anything -----------------------------------------------

func _off(folder: String) -> void:
	_check("no_flag_is_no_recorder", CraftTrace.from_command_line(PackedStringArray(["--set=x=1"])) == null,
		"from_command_line without --trace-craft")
	_check("no_recorder_node_exists_when_off", Sim.get_node_or_null("CraftTrace") == null and Sim.trace == null,
		"the tree holds nothing to tick")
	_check("off_writes_no_folder", not DirAccess.dir_exists_absolute(folder), "%s was not made" % folder)


## ---- ON: THE FILE, READ BACK ---------------------------------------------------------------------------------------

func _flight(folder: String) -> void:
	var cruise: float = Terrain.cruise_for(Sim.Kind.CESSNA)
	_cessna = Sim.spawn_ai_vehicle(Sim.Kind.CESSNA, Vector3(0.0, 600.0, 0.0), 0.0, Vector3(0.0, 0.0, -cruise))
	_plane = Sim.spawn_ai_vehicle(Sim.Kind.PLANE, Vector3(800.0, 600.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -Terrain.cruise_for(Sim.Kind.PLANE)))
	var recorder: CraftTrace = CraftTrace.install(Sim, "cessna", folder, str(int(RATE)))
	_check("a_good_request_starts_a_recorder", recorder != null and recorder.refusal.is_empty(), "refusal: " + recorder.refusal)
	_recording = true
	for i in int(SECONDS * TICK_HZ):
		await get_tree().physics_frame
	_recording = false
	recorder.close()
	# A CLOSED RECORDER IS DONE: ticks that pass now must not reopen (and truncate) the file it wrote.
	for i in 10:
		await get_tree().physics_frame
	_check("only_the_asked_kind_was_traced", recorder.paths.size() == 1 and recorder.paths.has(_cessna)
		and not recorder.paths.has(_plane), "traced entities %s (cessna %d, plane %d)" % [recorder.paths.keys(), _cessna, _plane])
	var path: String = String(recorder.paths.get(_cessna, ""))
	_check("the_file_is_where_the_recorder_says", FileAccess.file_exists(path), path)
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n", false)
	var header: Variant = JSON.parse_string(lines[0]) if lines.size() > 0 else null
	_check("the_first_line_is_a_header_naming_the_rate", header is Dictionary and int(header.get("trace", 0)) == 1
		and is_equal_approx(float(header.get("hz", 0.0)), RATE) and header.get("kind") == "cessna", str(header))
	var samples: Array = []
	var unparsed := 0
	for i in range(1, lines.size()):
		var row: Variant = JSON.parse_string(lines[i])
		if row is Dictionary:
			samples.append(row)
		else:
			unparsed += 1
	_check("every_line_parses", unparsed == 0, "%d of %d lines did not" % [unparsed, lines.size()])
	var expected: int = int(SECONDS * RATE)
	_check("the_sample_count_follows_rate_and_duration", absi(samples.size() - expected) <= 1,
		"%d samples for %.0f s at %.0f Hz, expected %d" % [samples.size(), SECONDS, RATE, expected])
	var stride: int = int(TICK_HZ / RATE)
	var worst := 0.0
	var compared := 0
	for row in samples:
		var tick: int = int(row["tick"])
		if tick >= _seen.size():
			continue
		var at: Vector3 = _seen[tick]
		var got := Vector3(float(row["pos"][0]), float(row["pos"][1]), float(row["pos"][2]))
		worst = maxf(worst, got.distance_to(at))
		compared += 1
	_check("the_positions_are_the_simulations_own", compared >= expected - 1 and worst < 0.001,
		"%d samples compared, worst %.5f m" % [compared, worst])
	var ticks_ok := samples.size() > 2
	for i in range(1, samples.size()):
		ticks_ok = ticks_ok and int(samples[i]["tick"]) - int(samples[i - 1]["tick"]) == stride
	_check("samples_are_a_stride_apart", ticks_ok, "stride %d ticks" % stride)
	var last: Dictionary = samples.back() if not samples.is_empty() else {}
	_check("the_flight_moved", samples.size() > 1 and Vector3(samples[0]["pos"][0], samples[0]["pos"][1],
		samples[0]["pos"][2]).distance_to(Vector3(last["pos"][0], last["pos"][1], last["pos"][2])) > 100.0,
		"it should have covered 5 s at cruise")
	_check("levers_and_attitude_are_written", last.has("levers") and last["levers"].has("throttle") and last.has("euler")
		and last.has("quat") and last.has("aoa"), str(last.keys()))
	_check("an_autopilot_is_written_as_ai", last.get("flown") == "ai" and last.has("goal"),
		"flown %s goal %s" % [last.get("flown"), last.get("goal")])
	if Sim.server.has_method("flight_controls"):
		_check("the_stick_is_written", last.has("stick") and last["stick"].has("pitch") and last["stick"].has("roll")
			and header.get("stick") == "flight_controls", str(last.get("stick")))
	else:
		print("[trace_log] NOTE this library has no flight_controls: the stick is absent, and the header says so: %s"
			% [header.get("stick")])
		_check("a_library_without_the_stick_says_so", header.get("stick") == "absent" and not last.has("stick"), str(header))
	recorder.queue_free()


## ---- A CROWD IS CAPPED AND SAYS SO ----------------------------------------------------------------------------------

func _cap(folder: String) -> void:
	for i in CraftTrace.FILES_MOST + 4:
		Sim.spawn_ai_vehicle(Sim.Kind.CESSNA, Vector3(-3000.0 + 60.0 * float(i), 700.0, -2000.0), 0.0,
			Vector3(0.0, 0.0, -Terrain.cruise_for(Sim.Kind.CESSNA)))
	var recorder: CraftTrace = CraftTrace.install(Sim, "ai", folder, "10")
	for i in 60:
		await get_tree().physics_frame
	recorder.close()
	var summary: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("trace_summary.json")))
	_check("a_crowd_is_capped_at_the_most_files", recorder.paths.size() == CraftTrace.FILES_MOST and DirAccess.get_files_at(folder).size() == CraftTrace.FILES_MOST + 1,
		"%d written, %d files in the folder (the extra one is the summary)" % [recorder.paths.size(), DirAccess.get_files_at(folder).size()])
	_check("the_summary_says_how_many_matched_and_how_many_were_written", summary is Dictionary and int(summary["written"]) == CraftTrace.FILES_MOST
		and int(summary["matched"]) >= CraftTrace.FILES_MOST + 4 and int(summary["cap"]) == CraftTrace.FILES_MOST, str(summary))
	recorder.queue_free()


func _physics_process(_delta: float) -> void:
	if _recording and Sim.server != null:
		for state in Sim.server.vehicle_states():
			if int(state["entity"]) == _cessna:
				_seen.append(state["position"])


func _finish() -> void:
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


func _check(name: String, passed: bool, detail: String) -> void:
	print("[trace_log] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true
		_said.append(name)


func _start() -> void:
	var waiting: Array = [not Sim.is_ready]
	if bool(waiting[0]):
		Sim.sim_ready.connect(func(): waiting[0] = false, CONNECT_ONE_SHOT)
	Net.play_solo()
	Sim.start()
	var patience := 600
	while bool(waiting[0]) and patience > 0:
		patience -= 1
		await get_tree().physics_frame
