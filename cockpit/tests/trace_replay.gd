extends Node
## THE TRACE LEVEL REPLAYS A FLIGHT AS IT WAS FLOWN: it loads a trace, and the craft drawn at three stated times is where the
## file says it was.
##
##   Godot --headless --fixed-fps 120 --xr-mode off --path cockpit res://tests/trace_replay.tscn
##
## THE DATUM IS THE FILE, WRITTEN HERE BY FORMULA and not by the recorder: a Cessna on a circle of 500 m radius at 300 m, once round
## in 20 s, sampled at 20 Hz, its nose along the circle and its stick a 2 Hz sine. The expected pose at any time is worked out from
## the circle, not asked of the level. Nothing is written into the repository; the file is under the run's temp directory.
##
## Read RESULT=, not the exit code.

const RADIUS: float = 500.0
const HEIGHT: float = 300.0
const PERIOD: float = 20.0
const HZ: float = 20.0
const LEVEL: String = "trace"
const PATIENCE: int = 3000

var _failed := false
var _said: Array[String] = []
var _level: FlightLevel = null
var _dir: String = ""


func _ready() -> void:
	if not Sim.is_available():
		_check("the_extension_is_there", false, "no CockpitWorld")
		_finish()
		return
	_dir = OS.get_environment("TEMP").path_join("trace_replay_%d" % OS.get_process_id()).replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(_dir)
	_refusals()
	# THE LEVEL WITH NO TRACE GIVEN, first: it comes up, says why, and has nothing to play.
	await _bring_up("")
	var bare: TraceLevel = _level.trace_level
	_check("the_level_comes_up_with_no_trace", bare != null and not bare.has_flight() and Sim.is_ready,
		"trace_level %s, ready %s" % [bare, Sim.is_ready])
	_check("and_says_what_to_pass", bare != null and bare.refusal.contains("--trace-in"), bare.refusal if bare != null else "")
	await _take_down()
	var good: String = _write_circle(_dir.path_join("circle.jsonl"))
	await _bring_up(good)
	await _replay()
	await _take_down()
	_finish()


## ---- THE FILE, IN WORDS, WHEN IT WILL NOT READ ---------------------------------------------------------------------

func _refusals() -> void:
	var head: String = '{"trace":1,"kind":"cessna","hz":20,"stick":"flight_controls"}'
	var row0: String = '{"tick":0,"t":0.0,"pos":[0,0,0],"quat":[0,0,0,1]}'
	var row1: String = '{"tick":6,"t":0.05,"pos":[1,0,0],"quat":[0,0,0,1]}'
	var cases: Array = [
		["no_file_named", "", "no trace was named"],
		["a_missing_file", _dir.path_join("nothing.jsonl"), "does not exist"],
		["a_file_that_is_no_trace", _put("plain.jsonl", "hello\nworld\n"), "not a trace header"],
		["a_kind_nobody_knows", _put("kind.jsonl", '{"trace":1,"kind":"wombat"}\n%s\n%s\n' % [row0, row1]), "'wombat'"],
		["one_sample_is_not_a_flight", _put("one.jsonl", "%s\n%s\n" % [head, row0]), "at least two"],
		["a_sample_without_a_position", _put("nopos.jsonl", '%s\n%s\n{"tick":6,"t":0.05,"quat":[0,0,0,1]}\n' % [head, row0]), "line 3 has no time, position or attitude"],
		["time_going_backward", _put("back.jsonl", '%s\n%s\n%s\n%s\n' % [head, row0, row1, row0]), "goes back in time"],
		["a_bad_line_in_the_middle", _put("mid.jsonl", "%s\n%s\n{oops\n%s\n" % [head, row0, row1]), "line 3 is not JSON"],
	]
	for one in cases:
		var got: Dictionary = TraceLevel.read(String(one[1]))
		_check("refused_" + String(one[0]), String(got["error"]).contains(String(one[2])), String(got["error"]))
	# A KILLED RUN'S LAST LINE IS CUT SHORT, and that one is forgiven, and said.
	var cut: Dictionary = TraceLevel.read(_put("cut.jsonl", "%s\n%s\n%s\n{\"tick\":12,\"t\":0.1,\"po" % [head, row0, row1]))
	_check("a_cut_short_last_line_is_dropped_not_fatal", String(cut["error"]).is_empty() and (cut["rows"] as Array).size() == 2
		and int(cut["dropped"]) == 1, str(cut.get("error", "")) + " rows " + str((cut.get("rows", []) as Array).size()))


func _put(name: String, text: String) -> String:
	var path: String = _dir.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


## ---- THE FLIGHT, AND WHERE IT IS DRAWN -----------------------------------------------------------------------------

## Where the file's circle puts the craft at `t`, in the file's own coordinates.
func _expected(t: float) -> Transform3D:
	var angle: float = TAU * t / PERIOD
	var at := Vector3(RADIUS * cos(angle), HEIGHT, RADIUS * sin(angle))
	# Its nose (-Z) along the direction of travel, (-sin, 0, cos): a yaw of PI - angle turns -Z to (-sin(yaw), 0, -cos(yaw)).
	return Transform3D(Basis(Quaternion(Vector3.UP, PI - angle)), at)


func _write_circle(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line(JSON.stringify({"trace": 1, "kind": "cessna", "entity": 1, "hz": HZ, "tick_hz": 120.0,
		"stick": "flight_controls", "selector": "cessna"}))
	var count: int = int(PERIOD * HZ)
	for i in count + 1:
		var t: float = float(i) / HZ
		var pose: Transform3D = _expected(t)
		var q: Quaternion = pose.basis.get_rotation_quaternion()
		file.store_line(JSON.stringify({"tick": i * 6, "t": t, "pos": [pose.origin.x, pose.origin.y, pose.origin.z],
			"quat": [q.x, q.y, q.z, q.w], "speed": TAU * RADIUS / PERIOD, "vel": [0.0, 0.0, 0.0], "flown": "ai",
			"euler": {"pitch": 0.0, "yaw": 0.0, "roll": 15.0 * sin(TAU * 2.0 * t)},
			"stick": {"pitch": sin(TAU * 2.0 * t), "roll": 0.2, "rudder": 0.0, "brake": 0.0, "throttle": 0.6},
			"levers": {"throttle": 0.6, "flaps": 0.0, "trim": 0.0}, "goal": null}))
	file.close()
	return path


func _replay() -> void:
	var trace: TraceLevel = _level.trace_level
	_check("the_level_read_the_file", trace != null and trace.has_flight() and trace.rows.size() == int(PERIOD * HZ) + 1
		and Sim.kind_name(trace.kind) == "cessna", "%d rows, kind %s, refusal '%s'" % [trace.rows.size(), Sim.kind_name(trace.kind), trace.refusal])
	trace.playing = false
	# THE PATH: the right number of points, and a mark for every second, in the mesh that is drawn.
	var arrays: Array = (trace._path.mesh as ArrayMesh).surface_get_arrays(0)
	var line_vertices: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	_check("the_path_has_a_point_for_every_sample", trace.path_vertex_count == 401 and line_vertices == 800,
		"%d points, %d line vertices for 401 samples" % [trace.path_vertex_count, line_vertices])
	_check("the_path_is_marked_every_second", trace.mark_every == 1.0 and trace.mark_count == 21, "every %.0f s, %d marks" % [trace.mark_every, trace.mark_count])
	# THE PUPPET AT THREE TIMES, drawn by the ordinary drawing, against the circle: 7.325 s is between two samples (the samples are 0.05 s apart).
	for t in [0.0, 7.325, 20.0]:
		trace.seek(t)
		for i in 3:
			await get_tree().process_frame
		var drawn: Transform3D = trace.drawn_pose()
		var expected: Transform3D = _expected(t)
		var wanted: Vector3 = expected.origin - Vector3(trace.centre.x, 0.0, trace.centre.y)
		var off: float = drawn.origin.distance_to(wanted)
		var turn: float = drawn.basis.get_rotation_quaternion().angle_to(expected.basis.get_rotation_quaternion())
		_check("the_drawn_pose_matches_the_file_at_%s_s" % str(t), off < 0.05 and turn < 0.001,
			"%.4f m and %.5f rad off; drawn %s, expected %s" % [off, turn, drawn.origin.snapped(Vector3.ONE * 0.1), wanted.snapped(Vector3.ONE * 0.1)])
	# NOTHING FLIES IT: the level put the puppet where the file says, and the simulation holds no craft of that kind.
	var flown: int = 0
	for state in Sim.server.vehicle_states():
		if int(state["entity"]) == TraceLevel.PUPPET:
			flown += 1
	_check("the_puppet_is_not_in_the_simulation", flown == 0 and _level.view_of(TraceLevel.PUPPET) != null, "%d in vehicle_states" % flown)
	_check("the_level_says_it_is_a_puppet", trace._label.text.contains("PUPPET") and trace.panel._banner_lines()[0].contains("NOT A SIMULATION"),
		trace._label.text)
	# THE INPUTS, at the current sample.
	trace.seek(5.0)
	var strip: Array[Dictionary] = trace.strip_channels()
	_check("the_stick_is_on_the_strip", strip.size() == 4 and strip[0]["label"] == "stick pitch", str(strip.size()))
	_check("the_sample_shown_is_the_one_at_the_time", is_equal_approx(float(trace.row_at(5.0)["t"]), 5.0)
		and is_equal_approx(float(trace.row_at(5.04)["t"]), 5.0), "row at 5.04 is %s" % trace.row_at(5.04)["t"])
	# PLAYBACK KEYS, pressed through the viewport as a hand would.
	trace.seek(0.0)
	trace.playing = false
	await _press(KEY_SPACE)
	_check("space_plays", trace.playing, "playing %s" % trace.playing)
	for i in 30:
		await get_tree().physics_frame
	var moved: float = trace.clock
	_check("a_playing_clock_advances", moved > 0.05, "clock %.3f s after 30 physics frames" % moved)
	await _press(KEY_SPACE)
	_check("space_pauses", not trace.playing, "playing %s" % trace.playing)
	var held: float = trace.clock
	for i in 10:
		await get_tree().process_frame
	_check("a_paused_clock_holds", is_equal_approx(trace.clock, held), "%.4f then %.4f" % [held, trace.clock])
	await _press(KEY_PERIOD)
	_check("period_is_faster", trace.rate == 2.0, "%sx" % str(trace.rate))
	await _press(KEY_COMMA)
	await _press(KEY_COMMA)
	_check("comma_is_slower", trace.rate == 0.5, "%sx" % str(trace.rate))
	await _press(KEY_5)
	_check("a_digit_jumps_to_that_tenth", is_equal_approx(trace.clock, 10.0), "clock %.2f" % trace.clock)
	await _press(KEY_RIGHT)
	_check("right_goes_on_five_seconds", is_equal_approx(trace.clock, 15.0), "clock %.2f" % trace.clock)
	await _press(KEY_HOME)
	_check("home_goes_to_the_start", is_equal_approx(trace.clock, 0.0), "clock %.2f" % trace.clock)
	# THE TIMELINE, clicked a quarter of the way along.
	var bar: Rect2 = trace.panel.timeline_rect()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	# The window may be stretched (the project's base size is not the headless window's): the event is in WINDOW pixels.
	click.position = get_viewport().get_final_transform() * (trace.panel.get_global_transform_with_canvas() * (bar.position + Vector2(bar.size.x * 0.25, 4.0)))
	get_viewport().push_input(click)
	await get_tree().process_frame
	_check("a_click_on_the_timeline_jumps_there", absf(trace.clock - 5.0) < 0.2, "clock %.2f for a click at a quarter; panel %s, bar %s, click %s" % [trace.clock, trace.panel.size, bar, click.position])
	# THE CAMERA FOLLOWS: it stays the level's distance from the craft as the craft moves.
	trace.seek(3.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var here: float = trace.camera.global_position.distance_to(trace.pose_at(3.0).origin)
	trace.seek(12.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var there: float = trace.camera.global_position.distance_to(trace.pose_at(12.0).origin)
	_check("the_camera_follows_the_craft", absf(here - trace._distance) < 0.5 and absf(there - trace._distance) < 0.5,
		"%.1f and %.1f m from the craft, asked %.1f" % [here, there, trace._distance])


func _press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame


func _bring_up(path: String) -> void:
	TraceLevel.forced_path = path
	var chosen: String = Net.choose_level(LEVEL)
	_check("the_trace_level_can_be_chosen_%s" % ("with_a_file" if not path.is_empty() else "bare"), chosen == "", "'%s'" % chosen)
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	var frames: int = 0
	while frames < PATIENCE and not (_level.ground_built_msec >= 0.0 and Sim.is_ready and _level.trace_level != null):
		await get_tree().process_frame
		frames += 1
	for i in 10:
		await get_tree().process_frame


func _take_down() -> void:
	Sim.stop()
	Net.leave("suite step over")
	if _level != null:
		get_tree().root.remove_child(_level)
		_level.queue_free()
		_level = null
	for i in 20:
		await get_tree().process_frame


func _finish() -> void:
	TraceLevel.forced_path = ""
	Sim.stop()
	Net.leave("suite over")
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


func _check(name: String, passed: bool, detail: String) -> void:
	print("[trace_replay] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true
		_said.append(name)
