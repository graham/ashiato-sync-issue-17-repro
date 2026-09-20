extends Node
## THE SKY AT ANY TIME, FROM ONE PLACE: a picture a time, or a time-lapse's frames, for a human to look at.
##
##   Godot --path cockpit --xr-mode off --resolution 1600x900 res://tests/daytime_shot.tscn -- --level=watch \
##       --clock-rate=0 --view=west --times=18:30,19:15,19:45,20:15,21:00 --out=C:/somewhere
##   ... --view=over --lapse=04:00,22:00,2 --out=C:/somewhere/frames     (a frame every 2 minutes of the clock)
##   Godot ... --write-movie C:/somewhere/reel.avi res://tests/daytime_shot.tscn -- --level=watch --reel=17:00
##
## THE REEL (`--reel=HH:MM`): the whole day from that time, ON THE SESSION'S OWN CLOCK at the time-lapse rate
## (`Net.CLOCK_RATE_LAPSE`, a day in ten seconds, set through the level's own `choose_rate` as the TIME tab's TIMELAPSE button
## sets it), in two halves of one picture -- EAST on the left, where the sun and the moon rise, and WEST on the right, where
## the sun sets -- because this moon rises at 18:52 in the east-north-east while the sun sets at 19:44 in the west-north-west,
## and one camera cannot hold both. The clock is written across the top. Under `--write-movie` the engine runs at the movie's
## frame rate, so the clock runs a day in ten seconds of the movie; the reel is a day and a quarter of a second long.
##
## NOT HEADLESS -- it renders. A PROBE, because whether a sunset looks like one has no assertion; tests/daytime.gd holds that
## the looks blend and that DAY, EVENING and NIGHT are what they were.
##
## THE TIME IS SET THROUGH THE LEVEL'S OWN `choose_clock` -- the call the TIME tab's clock row lands on -- with the clock
## frozen (`--clock-rate=0`), and the probe waits `SETTLE` frames after each so the sky's radiance and every yard have been
## told. The level's text, the observer's board and the rounds are hidden, and the simulation runs: aircraft are in the
## pictures as they fly.
##
## THE VIEWS are worked out from the sky, not typed: `west` looks from over the island toward where the sun sets (its
## bearing at the clock's sunset), a few degrees down, so a sunset sequence keeps the sun, the glow and the land in one frame;
## `east` the same toward sunrise; `over` looks down across the island from 900 m toward the south; `moon` looks at the moon
## at each time; `up` looks straight up.
##
## Read RESULT=, not the exit code.

## Frames to wait after the level has been built, and after each time is set.
const WARM: int = 240
const SETTLE: int = 30
## Where the eye stands over the island, metres.
const EYE := Vector3(-600.0, 420.0, 900.0)

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://daytime_shot"
var _view: String = "west"
var _times: Array[float] = []
var _lapse: Vector3 = Vector3(-1.0, -1.0, -1.0)
var _reel_from: float = -1.0
var _measure_frames: int = 0
var _clock_label: Label = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[daytime_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"out":
				_out = parts[1]
			"view":
				_view = parts[1]
			"times":
				for text in parts[1].split(",", false):
					var minutes: float = Orrery.minutes_of(text)
					if minutes < 0.0:
						_check("the_time_%s_is_a_time" % text, false, "HH:MM")
					else:
						_times.append(minutes)
			"measure":
				_measure_frames = maxi(parts[1].to_int(), 10)
			"reel":
				_reel_from = Orrery.minutes_of(parts[1])
				if _reel_from < 0.0:
					_check("the_reel_starts_at_a_time", false, parts[1])
			"lapse":
				var three: PackedStringArray = parts[1].split(",", false)
				if three.size() == 3 and Orrery.minutes_of(three[0]) >= 0.0 and Orrery.minutes_of(three[1]) >= 0.0:
					_lapse = Vector3(Orrery.minutes_of(three[0]), Orrery.minutes_of(three[1]), maxf(three[2].to_float(), 0.1))
				else:
					_check("the_lapse_is_from_to_and_a_step", false, parts[1])
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	for i in range(WARM):
		await get_tree().process_frame
	for node_name in ["Shots", "Ui"]:
		var node: Node = _level.get_node_or_null(node_name)
		if node != null:
			node.set("visible", false)
	var board := _level.observer.get("_board") as CanvasItem
	if board != null:
		board.visible = false
	DirAccess.make_dir_recursive_absolute(_out)
	if _measure_frames > 0:
		await _measure(_measure_frames)
		_finish()
		return
	if _reel_from >= 0.0:
		await _roll_the_reel()
		_finish()
		return
	if _lapse.x >= 0.0:
		var span: float = fposmod(_lapse.y - _lapse.x, Orrery.DAY_LONG)
		var count: int = int(floor(span / _lapse.z)) + 1
		for i in range(count):
			await _shoot(_lapse.x + float(i) * _lapse.z, "%s/frame%05d.png" % [_out, i], 4 if i > 0 else SETTLE)
	for minutes in _times:
		await _shoot(minutes, "%s/%s-%s.png" % [_out, _view, Orrery.words(minutes).replace(":", "")], SETTLE)
	_finish()


## ONE PICTURE at `minutes`, after `settle` frames.
func _shoot(minutes: float, path: String, settle: int) -> void:
	_level.choose_clock(minutes)
	var pose: Array = _pose(minutes)
	for i in range(settle):
		_level.observer.call("look_from", pose[0], pose[1])
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var saved: int = picture.save_png(path)
	var look: Dictionary = _level.daylight.look
	_check("saved_%s" % path.get_file(), saved == OK and absf(_level.clock() - minutes) < 0.01,
		"%s, sun %.1f up, %s, the level at %s" % [Orrery.words(minutes), float(look.get("sun_height", 0.0)),
			DaylightTuning.sky_words(look) if not look.is_empty() else "?", Orrery.words(_level.clock())])


## THE MEASUREMENT (`--measure=N`): what a step of the clock costs a frame, in the renderer's own timers, from one place
## (`--view=`), vsync off. Four rounds of N frames:
##   frozen        the clock stopped at 17:45
##   step          the same sky told again EVERY frame -- 17:45 and 17:45 and a hundredth, alternately -- which is what a
##                 time-lapse does to the renderer, with nothing else about the picture changed
##   frozen_again  as the first, so a drifting machine shows
##   lapse         the real TIMELAPSE rate from 17:45, for the record: the sky itself changes, so it is not an A/B
## The tenth percentile and the median of each round's GPU and CPU frame times (`viewport_get_measured_render_time_*`): the
## tenth percentile because a median carries every hitch the machine had (running_a_team_here.md, section 4). The step's own
## CPU -- the look, the writes and every consumer -- is `Daylight.step_usec`, beside it.
func _measure(frames: int) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var viewport: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	const AT: float = 17.0 * 60.0 + 45.0
	var pose: Array = _pose(AT)
	for round in ["frozen", "step", "frozen_again", "lapse"]:
		_level.choose_rate(0.0)
		_level.choose_clock(AT)
		_level.daylight.follows_the_clock = round != "step"
		if round == "lapse":
			_level.choose_rate(Net.CLOCK_RATE_LAPSE)
		for i in range(SETTLE):
			_level.observer.call("look_from", pose[0], pose[1])
			await get_tree().process_frame
		var gpu: Array[float] = []
		var cpu: Array[float] = []
		var steps: int = _level.daylight.steps
		var usec: int = _level.daylight.step_usec
		_level.daylight.step_usec_worst = 0
		for i in range(frames):
			if round == "step":
				_level.daylight.show_clock(AT + (0.5 if i % 2 == 0 else 0.0), false)
			_level.observer.call("look_from", pose[0], pose[1])
			await get_tree().process_frame
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		gpu.sort()
		cpu.sort()
		var stepped: int = _level.daylight.steps - steps
		print("MEASURE %s frames=%d gpu_p10=%.3f gpu_p50=%.3f cpu_p10=%.3f cpu_p50=%.3f steps=%d step_us=%.0f worst_step_us=%d" % [
			round, frames, gpu[frames / 10], gpu[frames / 2], cpu[frames / 10], cpu[frames / 2], stepped,
			float(_level.daylight.step_usec - usec) / maxf(float(stepped), 1.0), _level.daylight.step_usec_worst])
		print("MEASURE %s by part, mean/worst us: %s" % [round, _level.daylight.costs_said()])
		_level.daylight.costs.clear()
	_level.daylight.follows_the_clock = true
	_level.choose_rate(0.0)


## THE REEL: two views of the one world side by side, and the clock over them, for a day and a little more of the session's
## own clock at the time-lapse rate. The main camera looks east as the left half does, so everything that asks the
## viewport's camera where the eye is -- the mist, the clouds giving way -- is asked about the same place.
func _roll_the_reel() -> void:
	var size: Vector2i = get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	add_child(layer)
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 4)
	halves.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(halves)
	var bearings: Array[float] = [REEL_EAST, REEL_WEST]
	for bearing in bearings:
		var box := SubViewportContainer.new()
		box.stretch = true
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		halves.add_child(box)
		var view := SubViewport.new()
		view.size = Vector2i(size.x / 2 - 2, size.y)
		view.world_3d = get_viewport().world_3d
		view.msaa_3d = get_viewport().msaa_3d
		box.add_child(view)
		var eye := Camera3D.new()
		eye.fov = REEL_FOV
		eye.far = _level.observer.far
		view.add_child(eye)
		var ahead := Vector3(sin(deg_to_rad(bearing)), tan(deg_to_rad(REEL_UP)), -cos(deg_to_rad(bearing)))
		eye.look_at_from_position(EYE, EYE + ahead, Vector3.UP)
		eye.current = true
	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 40)
	_clock_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_clock_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_clock_label.add_theme_constant_override("outline_size", 8)
	_clock_label.position = Vector2(24.0, 16.0)
	layer.add_child(_clock_label)
	var sides := Label.new()
	sides.text = "EAST                                                                                                        WEST"
	sides.add_theme_font_size_override("font_size", 26)
	sides.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	sides.add_theme_color_override("font_outline_color", Color.BLACK)
	sides.add_theme_constant_override("outline_size", 6)
	sides.position = Vector2(24.0, float(size.y) - 56.0)
	layer.add_child(sides)
	_level.observer.call("look_from", EYE, EYE + Vector3(1000.0, 0.0, 0.0))
	_level.choose_rate(0.0)
	_level.choose_clock(_reel_from)
	for i in range(SETTLE):
		await get_tree().process_frame
	_level.choose_rate(Net.CLOCK_RATE_LAPSE)
	# WHERE THE DAY BEGINS IN THE MOVIE, for cutting the warm-up off the front of it: the movie writes one frame a drawn frame.
	print("REEL_FROM_FRAME %d" % Engine.get_frames_drawn())
	var began: float = Net.clock_now()
	var last: float = began
	var ran: float = 0.0
	var frames: int = 0
	while ran < Orrery.DAY_LONG + REEL_MORE and frames < REEL_MOST_FRAMES:
		_level.observer.call("look_from", EYE, EYE + Vector3(1000.0, 0.0, 0.0))
		_clock_label.text = "%s   %s" % [Orrery.words(Net.clock_now()),
			DaylightTuning.sky_words(_level.daylight.look) if not _level.daylight.look.is_empty() else ""]
		await get_tree().process_frame
		frames += 1
		# THE CLOCK RUN SO FAR, unwrapped across midnight.
		var now: float = Net.clock_now()
		ran += fposmod(now - last, Orrery.DAY_LONG)
		last = now
	_check("the_reel_ran_a_day", frames > 60,
		"%d frames from %s, %d steps; a step %.0f us on the mean, the worst %d us" % [frames, Orrery.words(began),
			_level.daylight.steps, float(_level.daylight.step_usec) / maxf(float(_level.daylight.steps), 1.0),
			_level.daylight.step_usec_worst])


## THE REEL'S TWO BEARINGS, degrees on the island's compass: east, where the sun rises (95) and the moon rises (81); and
## west-north-west, where the sun sets (300). Each half is `REEL_FOV` degrees tall, a little over the horizon.
const REEL_EAST: float = 88.0
const REEL_WEST: float = 300.0
const REEL_FOV: float = 62.0
const REEL_UP: float = 9.0
## How far past a whole day the reel runs, minutes of the clock: none, so it ends where it began.
const REEL_MORE: float = 0.0
## A guard, in frames, against a reel that never ends: two days at sixty frames a second of a day in ten seconds.
const REEL_MOST_FRAMES: int = 1300


## WHERE THE EYE IS AND WHAT IT LOOKS AT, for `_view` at `minutes`.
func _pose(minutes: float) -> Array:
	match _view:
		"west", "east":
			var at: float = Orrery.when_the_sun_is(-0.83, _view == "east")
			var flat: Vector3 = Orrery.sun(at) * Vector3(1.0, 0.0, 1.0)
			var toward: Vector3 = flat.normalized() * 4000.0 + Vector3(0.0, -260.0, 0.0)
			return [EYE, EYE + toward]
		"over":
			return [Vector3(0.0, 900.0, 3800.0), Vector3(0.0, 0.0, -1200.0)]
		"moon":
			return [EYE, EYE + Orrery.moon(minutes) * 1000.0]
		"up":
			return [EYE, EYE + Vector3(0.001, 1000.0, 0.0)]
	return [EYE, EYE + Vector3(0.0, 0.0, -1000.0)]
