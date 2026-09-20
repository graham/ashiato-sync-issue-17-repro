extends Node
## THE SCENERY FROM FIXED PLACES, ON EACH FINISH: a picture to look at and a frame time.
##
##   Godot --path cockpit --fixed-fps 60 res://tests/scenery_shot.tscn -- --level=watch
##   Godot --path cockpit --fixed-fps 60 res://tests/scenery_shot.tscn -- --level=watch \
##       --views=runway,fire --finishes=plain,fine --frames=300 --out=C:/somewhere
##
## NOT HEADLESS -- it renders. Headless has no rendering device, so every picture would be a
## black rectangle and every GPU time a zero, and both look like results.
##
## WHY IT EXISTS. "Is the sea better" is a question for eyes, and "can a headset afford it"
## is a question for a clock, and both have to be asked of the SAME frame from the SAME
## place on both finishes or the comparison is a comparison of two different skies. So the
## viewpoints are computed here from `Terrain` -- the runway's own axis, the widest thermal,
## the tallest rock, the first fire -- rather than flown to by hand, and a run today and a
## run next month stand in the same air.
##
## THE SWITCH IS THE REAL ONE. The finish is changed by pressing the key the `finish` action
## is bound to, through `Input.parse_input_event`, never by calling `Finish.choose`: a
## measurement of a tier the control cannot actually reach would be a measurement of nothing.
## After every press it asks the level what each surface is ACTUALLY drawn with
## (`FlightLevel.finish_worn`) and fails if any did not follow.
##
## HOW IT TIMES A FRAME. RenderingServer's own per-viewport timers, CPU and GPU, over `--frames`
## frames after the finish has had `SETTLE` frames to compile its pipelines -- a first frame
## that builds a shader is a hitch, not a cost. Vsync is switched off, because a frame capped
## at the display's rate measures the display. NOT under `--write-movie`, which encodes a PNG
## inside every frame it times.
##
## WHERE THE REST OF A FRAME GOES. The viewport timers see the renderer and nothing else, and on
## the desktop 3 to 5 ms of every frame was outside both (agents.md, "What it costs"). So every
## timed frame is also cut into four by clock stamps this probe takes itself: every
## `_physics_process` in the game (two `Bracket` nodes at the lowest and highest priority there
## are, so every other one runs between them), every `_process` the same way, the renderer from
## `frame_pre_draw` to `frame_post_draw` (which includes presenting the frame), and OTHER, which is
## whatever is left: the physics server's step, input, deferred calls and anything else the engine
## does between two frames. Inside those, `world/stopwatch.gd` names blocks of the game's own
## scripts, and `probe` is this script's own camera work, counted apart so it is never taken for
## the game's. Every frame of every run is written to `<view>-<finish>-frames.csv` beside its
## picture, with the engine's TIME_PROCESS and TIME_PHYSICS_PROCESS monitors read on the same frame.
##
## `--views=scenery` is the five views of the woods and the towns (`SCENERY_VIEWS`): a low pass along a
## forest's edge, the same forest from high, a town on the approach, down its street, and its tall
## buildings from low. Posed off the catalogues, and worked out once a run.
##
## THE POSE IS ASKED ONCE A VIEW, except for the views of something that moves. Until 2026-09-12 it
## was asked every drawn frame, and the mountains view's pose is the tallest rock, found through
## `Terrain.boxes()` -- which builds every box on the island each time it is asked. The mountains
## view was also the one that took 17 to 19 ms a frame. `--pose-every-frame` puts the old way back,
## so what it cost is measured rather than assumed.
##
## `--paused-sim` stops the simulation after the warm-up: no ticks, the fire front stopped, every
## vehicle drawn where it last was, and everything that draws still drawing. What a frame loses then
## is what the simulation cost it. `--stopwatch=off` leaves the laps unread, to price the laps.
##
## `--hold-fires` draws the same fires in every launch while the simulation ticks and the traffic flies:
## the fire front is stopped, and on every frame the fires the island starts with, at their own
## strengths, are put in place of the simulation's list, with the fire yard's clock held. Stage 1
## (2026-09-12) found the front spreading through every run and PLAIN's frame growing with it, so a view
## timed late carried more fires than one timed early -- and stopping the front alone would still leave
## each launch drawing whatever had caught by then. Timing that compares two builds needs the same fires
## on both; every view prints how many were drawn and how many were in frame.
##
## `--still` draws the same picture in every launch, to compare two builds pixel by pixel, and is not for
## timing. Stage 1 found two launches of one build differing by up to a million pixels wherever traffic or
## smoke was in frame, because the simulation is never in the same state twice. So the simulation is
## paused; every vehicle, round and carriage, the level's status text and the observer's board are
## hidden; the fires the island starts with are drawn at their own strengths in place of the
## simulation's; and the fire yard's and the lift yard's clocks are held. Shader TIME is left alone: under
## `--fixed-fps` it is the same on the same frame of every launch. Whether that is enough is measured, not
## assumed -- two STILL launches of one build have to differ by 0 pixels before any comparison counts.
##
## `--parade` is `--still` with the vehicles LEFT IN, for comparing two builds that change how a vehicle is drawn
## or spotted -- which `--still` cannot show, because it hides them. Pausing alone would freeze each vehicle
## wherever that launch's traffic happened to be, and it is never the same place twice. So after the pause every
## vehicle, in the order of its entity number, is put at a fixed place on a grid down the runway, `previous` is
## made the same as `current` so nothing interpolates, the spotting boxes are switched on, and the rounds, the
## carriages and the text are hidden. Each launch prints its vehicles' entity numbers and kinds: if two launches
## do not seed the same fleet, no picture of them can match, and that is reported, not worked around.
##
## `--no-spotting` keeps the boxes off in a parade, for measuring the red lights: the boxes are red wireframes, and
## the light measure counts every red pixel in a 9x9 box round a light. With them on, the traffic view read 58 red
## pixels a light out of 81 (2026-09-13), and thin lines lose pixels to FINE's multisampling, so FINE fell short of
## PLAIN whatever the lights did -- HEAD's lights too.
##
## `--time=day,evening,night` draws every view on every finish at each time of day asked for, through the level's own
## `choose_time` (the call the clipboard's TIME tab lands on), and names each picture `<view>-<finish>-<time>`. A run that
## draws night and day also holds night to day: the red lights, aircraft and runway, must still be findable, and the
## ground, the mountains, the forest and the towns must not go black. See `_hold_the_night`.
##
## `--drift=P` measures SHIMMER rather than time: after each view is timed, the camera turns P pixels a frame for
## `DRIFT_FRAMES` frames, as a head drifts, and every frame is read back and held to the two before it. A TURN, NOT A
## STEP: a step sideways moves a wall 30 m off seven pixels a frame and one 900 m off a fifth of one, and the first
## count (2026-09-13) was mostly near edges honestly moving; a turn moves everything the same fraction of a pixel. Inside
## the first town's outline on screen it counts the pixels that cross `LIT_LUMINANCE` either way -- a dark pane against a
## light wall by day, a lit one against a dark wall at night -- and TOGGLES, the pixels that cross and cross back on the
## next frame: an edge moving steadily crosses a pixel once, and a window too small to draw pops on and off. Toggles are
## the shimmer. Also the mean luminance change of the whole picture (`Image.compute_image_metrics`, in C++).
## On the views in `LIGHT_SHIMMER_VIEWS` it counts the red aircraft lights instead: every pixel of the box round each red
## light, projected afresh each frame, lit by the red-light measure's own rule.
## `--drift=0` is its twin: with the camera still, whatever changes is the world, not the windows. Asked with `--still`.
## `town_approach` and `town_night_lights` stand wholly past the window fade, so `town_windows`, 900 m off and asked for
## by name, is the view where a window is a pixel or two.
##
## `--fixed-fps` is what makes the pictures repeatable: TIME and every animation advance by
## exactly one sixtieth a frame whatever the machine is doing, so the smoke in the plain
## picture is at the same point in its rise as the smoke in the fine one.
##
## IT ALSO RUNS ON A COPY OF THE GAME FROM BEFORE THERE WERE FINISHES, and that is why it asks
## for `Finish`, `look_from` and `finish_worn` by name rather than naming them: the "before"
## pictures a change is judged against have to come from the committed game, which has none of
## the three. `--finishes=before` touches nothing and labels the pictures so.
##
## A probe, not a suite: a frame time has no right answer on somebody else's GPU. The one
## verdict it does give is whether the key reached every surface and the pictures were written.

## How long the world runs before anything is measured: the fleet seeded, the fires lit.
const WARM: int = 240
## How long a finish is given to build its materials before its frames count.
const SETTLE: int = 60

## How far off a lift zone's middle, and how high over the ground there, `lift_slope_<n>` stands (increment B3).
const LIFT_SLOPE_AWAY: float = 3200.0
const LIFT_SLOPE_OVER: float = 250.0
const EVERY_VIEW: Array[String] = ["runway", "runway_base", "traffic", "traffic_near", "clouds", "coast",
	"sea", "grass", "fields", "mountains", "fire"]
## THE VIEWS FOR THE WOODS AND THE TOWNS, asked for with `--views=scenery` (or by name) and not part of a
## run that names none, so every timing written down against EVERY_VIEW still stands in the same order.
## See `_pose` for where each one stands and why.
const SCENERY_VIEWS: Array[String] = ["forest_low", "forest_high", "town_approach", "town_street",
	"town_night_lights"]
## The forest catalogue, by path: a copy of the game from before there were forests has none, and a
## view of a wood that is not there reports itself missing rather than failing to parse.
const FORESTS_PATH: String = "res://world/forests.gd"

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _following: String = ""
var _out: String = "user://scenery"
var _frames: int = 240
var _views: Array[String] = EVERY_VIEW.duplicate()
var _finishes: Array[String] = []
## The 3D render scale, or -1 for the headset's own (`PilotRig.RENDER_SCALE`). Set higher only to
## make the GPU the thing a frame waits on, which is the one condition under which the wall clock
## can confirm what the GPU timer says -- see agents.md, "What it costs". THE ENGINE CLAMPS IT TO
## 0.1..2.0 (RendererViewport::viewport_set_scaling_3d_scale), silently; to load the GPU further,
## pass a larger window with --resolution as well.
var _scale: float = -1.0
## `--paused-sim`, `--pose-every-frame`, `--stopwatch=off`, `--hold-fires`, `--still`: see the top of
## the file.
var _paused: bool = false
var _pose_every_frame: bool = false
var _hold_fires: bool = false
var _still: bool = false
## True once `--still` has held the world, so `_process` holds the lift yard's clock from then on.
var _held_still: bool = false
## `--parade`: see the top of the file.
var _parade: bool = false
## `--no-spotting`: see `--parade` at the top of the file.
var _no_spotting: bool = false
## `--missiles`: on the `missiles` view, a salvo is launched just before each finish is timed. See `_launch_a_salvo`.
var _missiles: bool = false
## `--time=day,evening,night`: the times of day each view and finish is drawn at, through `FlightLevel.choose_time`.
## Empty for none asked, which draws whatever the level starts on and names the pictures as before.
var _times: Array[int] = []
## The red lights and the scenery's brightness, per `view|finish|time`, so night can be held to day. See `_hold_the_night`.
var _light_readings: Dictionary = {}
var _brightness_readings: Dictionary = {}
## `--drift=P`: pixels a frame the camera turns while shimmer is measured, or -1 for no measure. See the top of the file.
var _drift: float = -1.0
## `--strip=N`: every Nth timed frame of every view is saved as `<view>-<finish>-stripNNNN.png` as well, to see a view change
## over time -- a cloud evolving, or flown through on `cloud_fly`. Not for timing: reading a frame back costs one.
var _strip: int = 0
## THE MIST SWEEPS (`mist_nod`, `mist_climb`): which step of the sweep the pose is on, how many timed frames each step is held
## so the picture read back is the step's own, and how many steps. See `_pose_asked`.
var _sweep_step: int = 0
const SWEEP_HOLD: int = 4
const SWEEP_STEPS: int = 10
## The frame the current view's finish began settling on, for `cloud_fly`, which flies from it.
var _fly_began: int = 0
## `cloud_fly`: how far outside the cloud's lumps the pass starts when its first frame is timed, and how fast it flies, m/s.
const FLY_FROM: float = 1200.0
const FLY_SPEED: float = 140.0
## `cloud_each_<n>`: how far from each cloud's middle the camera stands, level with it, past where a cloud turns to fog. It
## was 1800 m and 250 m below, and every cloud was a small shape on the horizon among its neighbours (2026-09-14).
const CLOUD_EACH_AWAY: float = 1100.0
## How many times each pixel toggled during a drift, for the picture of where the shimmer is. See `_save_the_heat`.
var _heat: PackedInt32Array = []
## How far the drift has turned the camera from its pose, radians about the vertical, applied in `_process`.
var _drift_turn: float = 0.0
## How many frames a drift runs.
const DRIFT_FRAMES: int = 60
## THE LUMINANCE A PIXEL CROSSES TO COUNT AS A WINDOW CHANGING, on the 0..1 values of the picture. Between a pane and its
## wall at every time of day: by day glass reads about 0.1 against walls of 0.3 to 0.5; at night walls read 0.04 to 0.08
## and a lit window 0.3 and up (the town brightness readings, 2026-09-13).
const LIT_LUMINANCE: float = 0.25
## THE VIEWS WHOSE SHIMMER IS THE AIRCRAFT LIGHTS', not a town's. On these `--drift` counts, on every frame, every pixel of
## the 9x9 box round every red aircraft light on screen, and a pixel is lit by the red-light measure's own rule. A light
## is a pixel or two, which sampling every second pixel mostly misses, and a red dot on a pale day sky never crosses
## `LIT_LUMINANCE` -- the town's measure would read nothing on these views and call it steady (2026-09-14, the rim
## dither's hash).
const LIGHT_SHIMMER_VIEWS: Array[String] = ["traffic", "traffic_near", "traffic_close", "runway_base"]
## How many aeroplanes a salvo launches from, one missile each.
const SALVO: int = 8
## The fires `--hold-fires` and `--still` draw in place of the simulation's, put back every frame by
## `_process`; empty when neither is asked for.
var _fixed_fires: Array = []
var _stopwatch_wanted: bool = true
## The game's stopwatch, when this copy of the game has one: the "before" copy does not.
var _watch: Script = null
## Where the camera stands for the view being timed, asked once a view.
var _pose_now: Array = []
## EVERY STILL VIEW'S POSE, WORKED OUT ONCE A RUN. The run asks a view's pose to find out whether it exists
## and again when it starts drawing it, on every finish, and the mountains view's pose builds every box on
## the island (`Terrain.boxes()`), which cost 11 ms a frame when it was asked per frame. A moving view, and
## `--pose-every-frame`, are never cached.
var _pose_cache: Dictionary = {}

## The views whose subject moves, so their pose is asked every frame. `moon` looks along the light, and `cumulus_side` stands
## square to the sun, and a change of time of day turns both.
const MOVING_VIEWS: Array[String] = ["traffic", "traffic_near", "traffic_close", "cloud_fly", "mtn_fly", "moon", "cumulus_side", "mist_nod",
	"mist_climb", "mist_low", "mist_deck"]
const STOPWATCH_PATH: String = "res://world/stopwatch.gd"
## What `--still` holds the fire yard's and the lift yard's clocks at, in seconds. Any value, so long as
## it is the same one in every launch.
const STILL_AGE: float = 12.5
## The entity numbers `--still` gives the fires it draws: far above any the simulation hands out.
const STILL_FIRE_ENTITY: int = 900000
## The columns of a frames CSV, before one `block:<name>` column per stopwatch block.
const SPLIT_COLUMNS: Array[String] = ["wall", "gpu", "cpu", "ticks", "physics_scripts",
	"process_scripts", "probe", "render", "other", "monitor_process", "monitor_physics"]

## THIS FRAME SO FAR, in microseconds, from the clock stamps. Emptied after every timed frame.
var _physics_began: int = 0
var _physics_usec: int = 0
var _ticks: int = 0
var _process_began: int = 0
var _process_usec: int = 0
var _probe_usec: int = 0
var _draw_began: int = 0


## ONE END OF THE GAME'S SCRIPTS. Two of these, at the lowest priority there is and the highest,
## put every `_process` and every `_physics_process` in the game between a pair of clock stamps.
class Bracket extends Node:
	const EDGE: int = 1000000000
	var opens: bool = true
	var probe: Node = null

	func _init(at_start: bool, the_probe: Node) -> void:
		opens = at_start
		probe = the_probe
		name = "ScriptsBegin" if at_start else "ScriptsEnd"
		process_priority = -EDGE if at_start else EDGE
		process_physics_priority = -EDGE if at_start else EDGE

	func _process(_delta: float) -> void:
		probe.call("_scripts_edge", opens, false)

	func _physics_process(_delta: float) -> void:
		probe.call("_scripts_edge", opens, true)


func _check(label: String, ok: bool, detail: String) -> void:
	print("[scenery] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var finish: Node = get_node_or_null("/root/Finish")
	_finishes.assign(["plain", "fine"] if finish != null else ["before"])
	for argument in OS.get_cmdline_user_args():
		var bare: String = argument.lstrip("-")
		if bare == "paused-sim":
			_paused = true
			continue
		if bare == "pose-every-frame":
			_pose_every_frame = true
			continue
		if bare == "hold-fires":
			_hold_fires = true
			continue
		if bare == "still":
			_still = true
			continue
		if bare == "parade":
			_parade = true
			continue
		if bare == "no-spotting":
			_no_spotting = true
			continue
		if bare == "missiles":
			_missiles = true
			continue
		var parts: PackedStringArray = bare.split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"cloud-turn":
				_cloud_turn = int(parts[1])
			"out":
				_out = parts[1]
			"frames":
				_frames = maxi(int(parts[1]), 1)
			"views":
				_views.assign([])
				for asked in parts[1].split(",", false):
					if asked == "scenery":
						_views.append_array(SCENERY_VIEWS)
					else:
						_views.append(asked)
			"finishes":
				_finishes.assign(Array(parts[1].split(",", false)))
			"scale":
				_scale = float(parts[1])
			"stopwatch":
				_stopwatch_wanted = parts[1] != "off"
			"drift":
				_drift = maxf(float(parts[1]), 0.0)
			"strip":
				_strip = maxi(int(parts[1]), 0)
			"time":
				for asked in parts[1].split(",", false):
					var which: int = DaylightTuning.When.keys().find(asked.to_upper())
					if which < 0:
						_check("the_time_%s_is_a_time_of_day" % asked, false, "day, evening or night")
					else:
						_times.append(which)

	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	# WHICH LEVEL, AS BOOT WOULD CHOOSE IT. This probe builds the level itself, so boot never reads `--world=`; a probe that
	# did the same, tests/town_lights_shot.gd, photographed the island's town for the alpine world's (2026-09-15).
	var world: Dictionary = ChartDrawer.asked_in(OS.get_cmdline_user_args(), "none")
	if String(world["error"]) != "":
		_check("the_level_asked_for_is_a_level", false, String(world["error"]))
		_finish()
		return
	if String(world["id"]) != "":
		var why: String = Net.choose_level(String(world["id"]))
		if why != "":
			_check("the_level_asked_for_is_chosen", false, why)
			_finish()
			return
	print("[scenery] level %s, world %s" % [Net.level, ChartDrawer.chart(Net.level).world])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# AT THE HEADSET'S RENDER SCALE. A headset draws each eye at `PilotRig.RENDER_SCALE` times the
	# runtime's size, which is twice the pixels, and fill rate is what these finishes spend -- so a
	# frame timed at 1.0 would flatter every one of them by about half.
	get_viewport().scaling_3d_scale = PilotRig.RENDER_SCALE if _scale <= 0.0 else _scale
	print("[scenery] %s, %s precision, %s on %s, window %s, 3D scale %.2f, msaa_3d %d, ONE view (a headset draws two)" % [
		Engine.get_version_info()["string"], "double" if OS.has_feature("double") else "single",
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size(),
		get_viewport().scaling_3d_scale, get_viewport().msaa_3d])

	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	# A GENERATED GROUND TAKES SECONDS TO STAND, and the level builds its towns and runways after it: the warm-up counts
	# from then.
	if ChartDrawer.chart(Net.level).world != "island":
		const GROUND_PATIENCE: int = 6000
		var waited: int = 0
		while _level.ground_built_msec < 0.0 and waited < GROUND_PATIENCE:
			await get_tree().process_frame
			waited += 1
		_check("the_generated_ground_stood", _level.ground_built_msec >= 0.0,
			"in %.0f ms after %d frames; the first runway at %s, bearing %.0f" % [_level.ground_built_msec, waited,
				Terrain.runways()[0]["centre"], rad_to_deg(float(Terrain.runways()[0]["bearing"]))])
		if _level.ground_built_msec < 0.0:
			_finish()
			return
	for i in range(WARM):
		await get_tree().process_frame

	if _paused or _still or _parade:
		_pause_the_simulation()
	elif _hold_fires:
		_hold_the_fire_front()
	if _still:
		_hold_the_world_still()
	elif _parade:
		_hold_the_parade()
	_start_the_clocks()
	DirAccess.make_dir_recursive_absolute(_out)
	var viewport: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	for view in _views:
		if _pose(view).is_empty():
			_check("the_view_%s_exists" % view, false, "no such view, or nothing to see")
			continue
		_following = view
		_pose_now = []
		for finish_name in _finishes:
			await _wear(finish_name)
			# EACH TIME OF DAY ASKED FOR, through the level's own `choose_time` -- the call the clipboard's TIME tab
			# lands on -- and read back off the level. By name, for the copy of the game from before there was one.
			for time in (_times if not _times.is_empty() else [-1]):
				if time >= 0:
					if not _level.has_method("choose_time"):
						_check("there_is_a_time_of_day_to_choose", false, "no FlightLevel.choose_time")
						continue
					_level.call("choose_time", time)
					_check("the_level_has_%s_on" % DaylightTuning.name_of(time),
						int(_level.call("time_of_day")) == time, "reads %s" % _level.call("time_of_day"))
				_fly_began = Engine.get_process_frames()
				for i in range(SETTLE):
					await get_tree().process_frame
				if _missiles and view == "missiles":
					_launch_a_salvo()
				await _time_and_save(viewport, view, finish_name, time)
				if _drift >= 0.0:
					await _measure_the_shimmer(view, finish_name, time)
	_following = ""
	_hold_the_night()
	_finish()


func _process(_delta: float) -> void:
	if _following == "" or _level == null or _level.observer == null:
		return
	var began: int = Time.get_ticks_usec()
	# EVERY FRAME, AND BEFORE THE LEVEL DRAWS. The simulation replaces `Sim.fires` on every tick it runs,
	# and this node is ahead of the level in the tree, so its `_process` comes first.
	if not _fixed_fires.is_empty():
		get_node("/root/Sim").set("fires", _fixed_fires)
		_level.burning.set("_age", STILL_AGE)
	if _held_still:
		_level.lift.set("_age", STILL_AGE)
	if _pose_now.is_empty() or _pose_every_frame or _moves(_following):
		_pose_now = _pose(_following)
	if not _pose_now.is_empty():
		var eye_at: Vector3 = _pose_now[0]
		_place(eye_at, eye_at + ((_pose_now[1] as Vector3) - eye_at).rotated(Vector3.UP, _drift_turn))
	_probe_usec += Time.get_ticks_usec() - began


## STOP THE SIMULATION, AND LEAVE EVERYTHING THAT DRAWS IT DRAWING. `Sim` stops ticking and the
## level's fire front stops spreading; `previous` is made `current` so no vehicle is drawn sliding
## between two poses that will never change again. The frame loses the simulation and nothing else.
func _pause_the_simulation() -> void:
	var sim: Node = get_node_or_null("/root/Sim")
	if sim == null:
		_check("there_is_a_simulation_to_pause", false, "no Sim autoload")
		return
	sim.set_physics_process(false)
	_level.set_physics_process(false)
	sim.set("previous", sim.get("current"))
	print("[scenery] simulation paused: no ticks, no fire front, every vehicle drawn where it last was")


## THE SAME FIRES IN EVERY LAUNCH. See `--hold-fires` at the top of the file.
func _hold_the_fire_front() -> void:
	_level.set_physics_process(false)
	_fixed_fires = _the_islands_own_fires()
	print("[scenery] fire front held: the simulation ticks and the traffic flies, and the island's own %d fires are drawn in place of the simulation's, the fire yard's clock at %.1f s"
		% [_fixed_fires.size(), STILL_AGE])


## The fires the island starts with, at their own strengths, under entity numbers of their own.
func _the_islands_own_fires() -> Array:
	var fixed: Array = []
	var seeds: Array[Dictionary] = Terrain.fires()
	for i in range(seeds.size()):
		fixed.append({"entity": STILL_FIRE_ENTITY + i, "position": seeds[i]["position"],
			"strength": seeds[i]["strength"]})
	return fixed


## HOW MANY FIRES WERE DRAWN, AND HOW MANY IN FRAME -- so a comparison of what fires cost can show it had
## fires to compare. In frame is the base or the column's middle inside the picture and in front of the
## eye; a hill in the way still counts.
func _fires_in_frame() -> Array:
	var eye: Camera3D = get_viewport().get_camera_3d()
	var frame := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var seen: int = 0
	var listed: Array = get_node("/root/Sim").get("fires")
	for row in listed:
		var at: Vector3 = (row as Dictionary)["position"]
		for point in [at, at + Vector3.UP * 120.0]:
			if eye != null and not eye.is_position_behind(point) and frame.has_point(eye.unproject_position(point)):
				seen += 1
				break
	return [int(_level.burning.call("burning")), seen]


## THE SAME PICTURE IN EVERY LAUNCH. See `--still` at the top of the file. Called once the simulation
## is paused, so nothing puts back what this takes away.
func _hold_the_world_still() -> void:
	for node_name in ["Vehicles", "Shots", "Ui"]:
		var node: Node = _level.get_node_or_null(node_name)
		if node != null:
			node.set("visible", false)
	var carriages: Dictionary = _level.get("_carriages")
	for engine in carriages:
		for car in carriages[engine]:
			(car as Node3D).visible = false
	var board := _level.observer.get("_board") as CanvasItem
	if board != null:
		board.visible = false
	_fixed_fires = _the_islands_own_fires()
	get_node("/root/Sim").set("fires", _fixed_fires)
	_held_still = true
	print("[scenery] world held still: no simulation, no vehicles, rounds, carriages or text, the island's own %d fires, the yards' clocks at %.1f s"
		% [_fixed_fires.size(), STILL_AGE])


## THE SAME VEHICLES IN THE SAME PLACES IN EVERY LAUNCH. See `--parade` at the top of the file. Called once the
## simulation is paused, so nothing moves them again.
func _hold_the_parade() -> void:
	for node_name in ["Shots", "Ui"]:
		var node: Node = _level.get_node_or_null(node_name)
		if node != null:
			node.set("visible", false)
	var carriages: Dictionary = _level.get("_carriages")
	for engine in carriages:
		for car in carriages[engine]:
			(car as Node3D).visible = false
	var board := _level.observer.get("_board") as CanvasItem
	if board != null:
		board.visible = false
	var sim: Node = get_node("/root/Sim")
	_fixed_fires = _the_islands_own_fires()
	sim.set("fires", _fixed_fires)
	var was: Dictionary = sim.get("current")
	var entities: Array = was.keys()
	entities.sort()
	var posed: Dictionary = {}
	var kinds: PackedStringArray = []
	for i in range(entities.size()):
		var state: Dictionary = (was[entities[i]] as Dictionary).duplicate()
		var pose: Array = _parade_pose(i)
		state["position"] = pose[0]
		state["basis"] = Quaternion(Vector3.UP, float(pose[1]))
		state["velocity"] = Vector3.ZERO
		state["turrets"] = []
		state["has_route"] = false
		posed[entities[i]] = state
		kinds.append(str(int(state.get("kind", -1))))
	sim.set("current", posed)
	sim.set("previous", posed)
	_level.set("_spotting", not _no_spotting)
	_held_still = true
	print("[scenery] parade: entities=%d ids=%s kinds=%s" % [entities.size(), ",".join(PackedStringArray(entities.map(func(e): return str(e)))), ",".join(kinds)])


## Where the i-th vehicle stands: rows of eight down the runway from 150 m past the threshold, 110 m apart and 80 m
## across, turned a quarter at a time -- far enough out that most of them are past `VehicleView.SPOT_FROM` from the
## runway views, so their boxes are drawn.
static func _parade_pose(i: int) -> Array:
	var axis: Dictionary = Terrain.runway_axis()
	var along: Vector3 = axis["along"]
	var across: Vector3 = axis["across"]
	var threshold: Vector3 = axis["threshold"]
	var at: Vector3 = threshold + along * (150.0 + 110.0 * float(i / 8)) + across * (-280.0 + 80.0 * float(i % 8))
	at.y = threshold.y + 1.0
	return [at, float(i % 4) * PI * 0.5]


## THE CLOCK STAMPS AND THE STOPWATCH, on for the rest of the run. See the top of the file.
func _start_the_clocks() -> void:
	add_child(Bracket.new(true, self))
	add_child(Bracket.new(false, self))
	RenderingServer.frame_pre_draw.connect(_drawing_begins)
	if _stopwatch_wanted and ResourceLoader.exists(STOPWATCH_PATH):
		_watch = load(STOPWATCH_PATH) as Script
		_watch.call("run", true)
		_check("the_stopwatch_is_running", int(_watch.call("start")) != 0, STOPWATCH_PATH)
	print("[scenery] paused_sim=%s pose_every_frame=%s stopwatch=%s" % [_paused, _pose_every_frame,
		"on" if _watch != null else ("off" if not _stopwatch_wanted else "absent")])


func _scripts_edge(opening: bool, physics: bool) -> void:
	var now: int = Time.get_ticks_usec()
	if physics:
		if opening:
			_physics_began = now
			_ticks += 1
		elif _physics_began != 0:
			_physics_usec += now - _physics_began
	elif opening:
		_process_began = now
	elif _process_began != 0:
		_process_usec += now - _process_began


func _drawing_begins() -> void:
	_draw_began = Time.get_ticks_usec()


func _empty_the_split() -> void:
	_physics_usec = 0
	_process_usec = 0
	_probe_usec = 0
	_ticks = 0
	if _watch != null:
		_watch.call("take")


## THE CAMERA, HERE, LOOKING THERE. Through `Observer.look_from` when the game has it, and by
## hand on the committed game that does not -- the same arithmetic, so a before picture and an
## after picture are taken from the same place.
func _place(at: Vector3, toward: Vector3) -> void:
	var eye: Camera3D = _level.observer
	if eye.has_method("look_from"):
		eye.call("look_from", at, toward)
		return
	var ahead: Vector3 = (toward - at).normalized()
	eye.set("_chasing", 0)
	eye.set("_yaw", atan2(-ahead.x, -ahead.z))
	eye.set("_pitch", asin(clampf(ahead.y, -1.0, 1.0)))
	eye.global_position = at
	eye.rotation = Vector3(float(eye.get("_pitch")), float(eye.get("_yaw")), 0.0)


func _time_and_save(viewport: RID, view: String, finish_asked: String, time: int = -1) -> void:
	# THE TIME OF DAY IS PART OF THE NAME when one was asked for -- `plain-night` -- so every picture, CSV and log line of
	# a `--time` run says which sky it is, and a run without says what it always said.
	var finish_name: String = finish_asked if time < 0 \
		else "%s-%s" % [finish_asked, DaylightTuning.name_of(time).to_lower()]
	var gpu: PackedFloat64Array = []
	var cpu_each: PackedFloat64Array = []
	var cpu: float = 0.0
	# A WHOLE FRAME FROM HERE, so the first delta is not the back half of one, and the split starts
	# on a clean sheet.
	await RenderingServer.frame_post_draw
	_empty_the_split()
	var rows: Array[Dictionary] = []
	var block_names: Dictionary = {}
	var started: int = Time.get_ticks_usec()
	# WALL CLOCK PER FRAME, AS WELL AS THE TIMERS. The viewport's GPU and CPU timers are what the
	# renderer says it spent; the time between two frames arriving is what the machine actually
	# took. The first Part B (2026-09-12) logged only a MEAN of the wall clock, which cannot say
	# whether the GPU timer tracks it -- and a whole sea at 0.12 ms GPU was reason to ask.
	var deltas: PackedFloat64Array = []
	var last: int = started
	_sweep_step = 0
	for i in range(_frames):
		await RenderingServer.frame_post_draw
		var now_usec: int = Time.get_ticks_usec()
		var delta_ms: float = float(now_usec - last) / 1000.0
		deltas.append(delta_ms)
		last = now_usec
		var gpu_now: float = RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		gpu.append(gpu_now)
		var cpu_now: float = RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		cpu += cpu_now
		cpu_each.append(cpu_now)
		var render_ms: float = float(now_usec - _draw_began) / 1000.0 if _draw_began != 0 else -1.0
		var row: Dictionary = {"wall": delta_ms, "gpu": gpu_now, "cpu": cpu_now, "ticks": float(_ticks),
			"physics_scripts": float(_physics_usec) / 1000.0,
			"process_scripts": float(_process_usec) / 1000.0,
			"probe": float(_probe_usec) / 1000.0, "render": render_ms,
			"monitor_process": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"monitor_physics": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0}
		row["other"] = delta_ms - float(row["physics_scripts"]) - float(row["process_scripts"]) \
			- maxf(render_ms, 0.0)
		if _watch != null:
			var laps: Dictionary = _watch.call("take")
			for block in laps:
				row["block:" + String(block)] = float(laps[block]) / 1000.0
				block_names[String(block)] = true
		rows.append(row)
		if view in ["mist_nod", "mist_climb"]:
			_read_the_sweep(view, finish_name, i)
		if _strip > 0 and i % _strip == 0:
			get_viewport().get_texture().get_image().save_png("%s/%s-%s-strip%04d.png" % [_out, view, finish_name, i])
		_physics_usec = 0
		_process_usec = 0
		_probe_usec = 0
		_ticks = 0
	var wall: float = float(Time.get_ticks_usec() - started) / 1000.0 / float(_frames)
	var sorted: Array = Array(gpu)
	sorted.sort()
	var mean: float = 0.0
	for one in gpu:
		mean += one
	mean /= float(gpu.size())
	var draws: int = RenderingServer.viewport_get_render_info(viewport,
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var primitives: int = RenderingServer.viewport_get_render_info(viewport,
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	# THE MEDIAN AS WELL AS THE MEAN: one frame that compiled a late pipeline moves a mean and does
	# not move a median, and a p95 is what a headset misses a frame on.
	var cpu_sorted: Array = Array(cpu_each)
	cpu_sorted.sort()
	var wall_sorted: Array = Array(deltas)
	wall_sorted.sort()
	print("[scenery] view=%s finish=%s frames=%d gpu_ms=%.3f gpu_median_ms=%.3f gpu_p95_ms=%.3f cpu_ms=%.3f cpu_median_ms=%.3f wall_ms=%.3f wall_median_ms=%.3f wall_p95_ms=%.3f draws=%d primitives=%d"
		% [view, finish_name, _frames, mean, float(sorted[sorted.size() / 2]),
			float(sorted[int(sorted.size() * 0.95)]), cpu / float(_frames),
			float(cpu_sorted[cpu_sorted.size() / 2]), wall,
			float(wall_sorted[wall_sorted.size() / 2]),
			float(wall_sorted[int(wall_sorted.size() * 0.95)]), draws, primitives])
	_report_the_split(rows, block_names, view, finish_name)
	var fires: Array = _fires_in_frame()
	var drawn_missiles: Array = _missiles_drawn()
	print("[scenery] missiles view=%s finish=%s in_the_air=%d trail_segments=%d" % [view, finish_name, drawn_missiles[0], drawn_missiles[1]])
	print("[scenery] fires view=%s finish=%s drawn=%d in_frame=%d" % [view, finish_name, fires[0], fires[1]])
	var picture: Image = get_viewport().get_texture().get_image()
	# Not on `--still`: the aircraft whose lights it counts are hidden there.
	if not _still:
		_measure_the_lights(picture, view, finish_name, finish_asked, time)
	_measure_the_brightness(picture, view, finish_name, finish_asked, time)
	if time == DaylightTuning.When.NIGHT:
		_measure_the_stars_through_cloud(picture, view, finish_name)
	var path: String = "%s/%s-%s.png" % [_out, view, finish_name]
	var saved: int = picture.save_png(path)
	_check("saved_%s_%s" % [view, finish_name], saved == OK, path)


## WHERE EACH FRAME WENT: every frame to a CSV beside the picture, and the medians to the log.
func _report_the_split(rows: Array[Dictionary], block_names: Dictionary, view: String,
		finish_name: String) -> void:
	var blocks: Array = block_names.keys()
	blocks.sort()
	var header: PackedStringArray = PackedStringArray(SPLIT_COLUMNS)
	for block in blocks:
		header.append("block:" + String(block))
	var path: String = "%s/%s-%s-frames.csv" % [_out, view, finish_name]
	var sheet: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	_check("wrote_the_frames_%s_%s" % [view, finish_name], sheet != null, path)
	if sheet != null:
		sheet.store_line(",".join(header))
		for row in rows:
			var cells: PackedStringArray = []
			for column in header:
				cells.append("%.4f" % float(row.get(column, 0.0)))
			sheet.store_line(",".join(cells))
		sheet.close()
	var ticks: float = 0.0
	for row in rows:
		ticks += float(row["ticks"])
	print("[scenery] split view=%s finish=%s paused_sim=%s stopwatch=%s pose_every_frame=%s ticks_per_frame=%.2f physics_scripts_median_ms=%.3f process_scripts_median_ms=%.3f probe_median_ms=%.3f render_median_ms=%.3f other_median_ms=%.3f"
		% [view, finish_name, _paused, "on" if _watch != null else "off", _pose_every_frame,
			ticks / maxf(float(rows.size()), 1.0), _median_of(rows, "physics_scripts"),
			_median_of(rows, "process_scripts"), _median_of(rows, "probe"),
			_median_of(rows, "render"), _median_of(rows, "other")])
	var said: PackedStringArray = []
	for block in blocks:
		said.append("%s=%.3f" % [block, _median_of(rows, "block:" + String(block))])
	if not said.is_empty():
		print("[scenery] blocks view=%s finish=%s median_ms %s" % [view, finish_name, " ".join(said)])
	_check("the_renderer_was_stamped_%s_%s" % [view, finish_name],
		not rows.is_empty() and _median_of(rows, "render") >= 0.0, "frame_pre_draw reached the probe")
	if _paused and _watch != null:
		var ticked: Array = blocks.filter(func(block): return String(block).begins_with("sim_"))
		_check("the_simulation_stayed_paused_%s_%s" % [view, finish_name], ticked.is_empty(),
			"laps from a paused simulation: %s" % [ticked])


## The median of one column over the frames; a frame with no lap for a block counts as 0.
static func _median_of(rows: Array[Dictionary], column: String) -> float:
	if rows.is_empty():
		return 0.0
	var values: Array = []
	for row in rows:
		values.append(float(row.get(column, 0.0)))
	values.sort()
	return float(values[values.size() / 2])


## PUT THE FINISH ON, by pressing the key that is bound to it -- and only if it is not on
## already, because the key TOGGLES. "before" touches nothing.
##
## "plain2" is PLAIN again, later in the same run: two PLAIN pictures of one view differ only by
## what moved between them, which is the noise any PLAIN before-and-after has to be judged against.
##
## "fine-bare" is FINE with the blades of grass taken away, and exists only to time them: the
## blades are the one part of the fine finish that is new GEOMETRY rather than new arithmetic on
## pixels already drawn, so their cost is asked for on its own and can be dropped on its own.
func _wear(finish_name: String) -> void:
	if finish_name == "before":
		return
	var finish: Node = get_node_or_null("/root/Finish")
	if finish == null:
		_check("there_is_a_finish_to_wear", false, "no Finish autoload; use --finishes=before")
		return
	var blades := _level.get("grass") as Node3D
	var fine: bool = finish_name.begins_with("fine")
	# Whatever the last finish took away, put back before this one is worn.
	if blades != null and bool(finish.call("is_fine")):
		blades.visible = true
	get_viewport().msaa_3d = finish.call("multisampling")
	if bool(finish.call("is_fine")) != fine:
		var code: Key = KEY_NONE
		for event in InputMap.action_get_events(String(finish.get("ACTION"))):
			var key := event as InputEventKey
			if key != null:
				code = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		for down in [true, false]:
			var press := InputEventKey.new()
			press.keycode = code
			press.physical_keycode = code
			press.pressed = down
			Input.parse_input_event(press)
			await get_tree().process_frame
	_check("the_key_put_on_%s" % finish_name, bool(finish.call("is_fine")) == fine,
		"fine is %s" % finish.call("is_fine"))
	# AND THE SURFACES FOLLOWED, asked of the surfaces. See `FlightLevel.finish_worn`.
	if not _level.has_method("finish_worn"):
		return
	var worn: Dictionary = _level.call("finish_worn")
	var strays: Array = []
	for surface in worn:
		if bool(worn[surface]) != fine:
			strays.append(surface)
	if finish_name == "fine-bare" and blades != null:
		blades.visible = false
		print("[scenery] blades hidden, to time the fine finish without them")
	# "fine-nomsaa": FINE with multisampling forced off, so its share of FINE's cost is a number
	# of its own and can be dropped on its own.
	if finish_name == "fine-nomsaa":
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		print("[scenery] multisampling off, to time the fine finish without it")
	_check("every_surface_wears_%s" % finish_name, strays.is_empty() and not worn.is_empty(),
		"%s" % [worn if strays.is_empty() else "still the other finish: %s" % [strays]])


## Every aircraft's lights the level is drawing, as their MultiMeshInstance3Ds.
func _aircraft_lights() -> Array:
	var aircraft: Array = []
	for entity in Sim.current:
		var craft: VehicleView = _level.view_of(int(entity))
		if craft == null:
			continue
		var lights := craft.find_child("Lights", true, false) as MultiMeshInstance3D
		if lights != null and lights.multimesh != null:
			aircraft.append(lights)
	return aircraft


## HOW VISIBLE THE RED LIGHTS ARE, read off the picture rather than judged by eye.
##
## Two render checks (2026-09-12) showed FINE aircraft lights harder to find than PLAIN ones, and
## "at least as visible by construction" is a claim about the shader's arithmetic -- this is the
## picture. Every red light on every aircraft in front of the camera is projected to the screen
## and a 9x9 box round it is read out of the saved frame: how many pixels in it are RED (red over
## half and more than 1.8 times the larger of green and blue), and how red the reddest one is. A
## light hidden behind a mountain counts as nothing on both finishes alike. FINE's numbers must
## not fall below PLAIN's; that is the gate, and it is printed so it can be held to.
##
## EXCEPT BY DAY FAR OFF, on purpose (7fc1af3): by day a far aeroplane's lights fade to under a tenth of a red pixel a
## light on both finishes, which is what was asked for, and FINE's multisampling averages that faint dot into the sky --
## 0.03 against PLAIN's 0.08 at 2.6 km, 0.03 against 0.17 on `runway_base`. At evening and night, and near at every time,
## FINE leads on every view. See agents.md, "An aircraft's lights by distance".
##
## AND THE RUNWAY'S, on a line of its own (`runway_lights`), so the aircraft line reads what it always read. Each line
## also carries CONTRAST: the brightest pixel in a light's box over the mean of sixteen pixels on a ring `RING` px out,
## averaged over the lights. By day a red light is found by its colour against a pale sky and reads under 1; at night
## it has to be found by being brighter than what is round it, which is what `_hold_the_night` asks.
func _measure_the_lights(picture: Image, view: String, finish_name: String, finish_asked: String = "",
		time: int = -1) -> void:
	var eye: Camera3D = get_viewport().get_camera_3d()
	if eye == null:
		return
	var reading: Dictionary = _read_the_red_lights(picture, eye, _aircraft_lights())
	print("[scenery] lights view=%s finish=%s red_lights_on_screen=%d red_pixels_per_light=%.2f reddest=%.3f contrast=%.2f"
		% [view, finish_name, reading["sampled"], reading["red_pixels_per_light"], reading["reddest"],
			reading["contrast"]])
	_file_a_reading(_light_readings, "%s|aircraft|%s" % [view, finish_asked], time, reading)
	# THE SAME, BY RANGE: a view's 110 red lights stand from a few hundred metres to kilometres off, and a fade with
	# distance moves the far ones and not the near, which one number over all of them cannot say.
	var bands: PackedInt32Array = reading["bands"]
	print("[scenery] lights_by_range view=%s finish=%s near_lights=%d near_red_px=%.2f mid_lights=%d mid_red_px=%.2f far_lights=%d far_red_px=%.2f"
		% [view, finish_name, bands[0], float(bands[1]) / maxf(float(bands[0]), 1.0), bands[2],
			float(bands[3]) / maxf(float(bands[2]), 1.0), bands[4], float(bands[5]) / maxf(float(bands[4]), 1.0)])
	var runway := _level.get_node_or_null("RunwayLights") as MultiMeshInstance3D
	if runway == null or runway.multimesh == null:
		return
	var on_the_ground: Dictionary = _read_the_red_lights(picture, eye, [runway])
	print("[scenery] runway_lights view=%s finish=%s red_lights_on_screen=%d red_pixels_per_light=%.2f reddest=%.3f contrast=%.2f"
		% [view, finish_name, on_the_ground["sampled"], on_the_ground["red_pixels_per_light"],
			on_the_ground["reddest"], on_the_ground["contrast"]])
	_file_a_reading(_light_readings, "%s|runway|%s" % [view, finish_asked], time, on_the_ground)


## How far out the ring a light's contrast is read against, in pixels, and how many pixels on it.
const RING: float = 12.0
const RING_SAMPLES: int = 16
## The ranges the red lights are also read in: inside where a light starts to fade (VehicleLights.DIM_FROM, typed so the
## copy of the game from before there was one still parses), out to about where a day's fade has done its work, and past.
const RANGE_NEAR: float = 300.0
const RANGE_FAR: float = 2000.0


## DO THE STARS SHOW THROUGH THE CLOUDS AT NIGHT? The sky is drawn behind everything, so a puff of optical depth 1 or more
## should take 63 % or more of a star away. Asked by team-lead off cockpit-clouds2-40 (2026-09-17): "STARS appear across
## regions that look like cloud". A star is a pixel brighter than every pixel STAR_RING round it by STAR_LIFT; its cloud is
## the optical depth along its own ray to STAR_REACH (`PuffSky.optical_depth_between`, the field the puffs are drawn from).
## The area of sky under each is sampled on a STAR_GRID. Printed, and held: stars a thousand pixels of sky behind 1 or more
## of cloud at most STARS_THROUGH_CLOUD of those in clear sky.
const STAR_RING: int = 3
const STAR_LIFT: float = 0.06
const STAR_REACH: float = 30000.0
const STAR_GRID: int = 24
const STARS_THROUGH_CLOUD: float = 0.25
## The rows at the top of the picture the level's two status lines are written in, in picture pixels.
const STAR_HUD_TOP: int = 70


func _measure_the_stars_through_cloud(picture: Image, view: String, finish_name: String) -> void:
	var eye: Camera3D = get_viewport().get_camera_3d()
	if eye == null or _level == null or _level.puffs == null or not _level.puffs.visible:
		return
	var scale := Vector2(picture.get_size()) / get_viewport().get_visible_rect().size
	var from: Vector3 = eye.global_position
	# THE SKY'S AREA, clear and clouded, on a grid over the part of the picture that looks above the horizon.
	var area := {"clear": 0, "clouded": 0}
	for y in range(STAR_HUD_TOP + STAR_GRID / 2, picture.get_height(), STAR_GRID):
		for x in range(STAR_GRID / 2, picture.get_width(), STAR_GRID):
			var way: Vector3 = eye.project_ray_normal(Vector2(x, y) / scale)
			if way.y < 0.05:
				continue
			var depth: float = _level.puffs.optical_depth_between(from, from + way * STAR_REACH, 64)
			if depth >= 1.0:
				area["clouded"] += STAR_GRID * STAR_GRID
			elif depth < 0.1:
				area["clear"] += STAR_GRID * STAR_GRID
	var stars := {"clear": 0, "clouded": 0}
	# NOT UNDER THE STATUS LINES: their letters are bright points on a dark sky too, and the first count took 1,021 of them
	# for stars behind the cloud overhead. The grid above skips the same band.
	# NOT UNDER THE BUILD STAMP in the lower right (`BuildStamp`, 2026-09-18): it is in every picture on purpose, and its
	# letters are drawn over whatever is behind them, so they would count as stars, as the status lines did.
	var stamp: Rect2i = BuildStamp.pixels().grow(STAR_RING)
	for y in range(STAR_HUD_TOP, picture.get_height() - STAR_RING):
		for x in range(STAR_RING, picture.get_width() - STAR_RING):
			if stamp.has_point(Vector2i(x, y)):
				continue
			var here: float = _luminance(picture.get_pixel(x, y))
			if here < STAR_LIFT:
				continue
			var ring: float = 0.0
			for k in range(8):
				var angle: float = TAU * float(k) / 8.0
				ring = maxf(ring, _luminance(picture.get_pixel(x + roundi(cos(angle) * STAR_RING), y + roundi(sin(angle) * STAR_RING))))
			if here - ring < STAR_LIFT:
				continue
			var way: Vector3 = eye.project_ray_normal(Vector2(x, y) / scale)
			if way.y < 0.05:
				continue
			var depth: float = _level.puffs.optical_depth_between(from, from + way * STAR_REACH, 64)
			if depth >= 1.0:
				stars["clouded"] += 1
			elif depth < 0.1:
				stars["clear"] += 1
	var clear_rate: float = float(stars["clear"]) * 1000.0 / maxf(float(area["clear"]), 1.0)
	var clouded_rate: float = float(stars["clouded"]) * 1000.0 / maxf(float(area["clouded"]), 1.0)
	print("[scenery] stars view=%s finish=%s clear_sky_px=%d clear_stars=%d (%.3f a kpx) clouded_sky_px=%d clouded_stars=%d (%.3f a kpx)"
		% [view, finish_name, area["clear"], stars["clear"], clear_rate, area["clouded"], stars["clouded"], clouded_rate])
	if int(area["clear"]) > 20000 and int(area["clouded"]) > 20000 and int(stars["clear"]) > 10:
		_check("the_stars_are_hidden_behind_cloud_%s_%s" % [view, finish_name], clouded_rate <= clear_rate * STARS_THROUGH_CLOUD,
			"%.3f stars a kpx behind 1 or more of cloud against %.3f in clear sky, at most %.2f of it" % [clouded_rate,
				clear_rate, STARS_THROUGH_CLOUD])


## WHETHER A CLOUD HIDES A LIGHT from the eye: `LIGHT_CLOUDED` of optical depth or more between them, through the puffs the
## level draws (`PuffSky.optical_depth_between`, the field the puffs are drawn from). A light in a cloud is not on screen to
## be found, by day or at night. Found 2026-09-17 when the puff sky went in: the cloud_near view looks down on the cumulus
## deck, and the traffic flying under it read 0.00 red px a light at night on FINE against 5.27 with LiftYard's clouds. ONE,
## not two: at two the cloud_edge view -- the eye half-way into the cloud -- kept six lights behind 1 to 2 of cloud, and PLAIN
## read their contrast 2.85 against the 3.0 floor. A light behind 1 of cloud has lost 63 % of itself to the cloud, which is
## the cloud working, not the night.
const LIGHT_CLOUDED: float = 1.0
## AND A VIEW WITH TRAFFIC IN IT STILL LOOKS AT SOME: the fewest lights a view that had lights in frame must count clear of
## cloud. Without it the cloud views excused every light and the check visited nothing (team-lead, 2026-09-17: "a check
## that never visited the thing is not evidence"); their camera had been stood inside a neighbouring cumulus.
const LIGHTS_CLEAR_LEAST: int = 5
## THE VIEWS WHOSE EYE IS MEANT TO BE IN A CLOUD, where every light in frame is behind it and that is the cloud working:
## `cloud_inside`, 40 m from the cloud's middle.
const LIGHTS_IN_CLOUD_VIEWS: Array[String] = ["cloud_inside"]
## How far out along its reach the `cloud_edge` eye stands on a puff cloud: at its skin, entering.
const CLOUD_EDGE_ON_PUFFS: float = 0.9


## How many aircraft lights stand within `LIGHT_CONE` of the line from `eye` to `looking_at` and clear of cloud from `eye`.
func _lights_clear_from(eye: Vector3, looking_at: Vector3) -> int:
	var ahead: Vector3 = (looking_at - eye).normalized()
	var count: int = 0
	for node in _aircraft_lights():
		var lights := node as MultiMeshInstance3D
		for i in range(lights.multimesh.instance_count):
			var colour: Color = lights.multimesh.get_instance_color(i)
			if colour.r < 0.9 or colour.g > 0.3:
				continue
			var at: Vector3 = lights.global_transform * lights.multimesh.get_instance_transform(i).origin
			if ahead.dot((at - eye).normalized()) < cos(LIGHT_CONE):
				continue
			if _level.puffs.optical_depth_between(eye, at) < LIGHT_CLOUDED:
				count += 1
	return count


## Half the angle, round the way a cloud view looks, that `_lights_clear_from` counts lights in: inside the frame's height.
const LIGHT_CONE: float = 0.45
## The heading each thermal's puff cloud is posed from, once found. See `_cloud_frame`.
var _puff_heading: Dictionary = {}
## `--cloud-turn=N` stands every cloud view on the Nth of the twelve headings instead of the one the chooser picks, so a
## before and an after picture can be taken from the same camera when the sky has changed under the chooser (clouds3's
## towers moved it). The chosen turn is printed on every run.
var _cloud_turn: int = -1


func _behind_a_cloud(eye: Camera3D, at: Vector3) -> bool:
	if _level == null or _level.puffs == null or not _level.puffs.visible:
		return false
	return _level.puffs.optical_depth_between(eye.global_position, at) >= LIGHT_CLOUDED


## The red-light measure over every red instance of `sets` (MultiMeshInstance3Ds of VehicleLights): see above.
func _read_the_red_lights(picture: Image, eye: Camera3D, sets: Array) -> Dictionary:
	var frame := Rect2(Vector2.ZERO, Vector2(picture.get_width(), picture.get_height())).grow(-5.0)
	var ringed := frame.grow(-RING)
	# BY RANGE FROM THE EYE, as lights and red pixels in pairs: near, mid, far. See RANGE_NEAR.
	var bands: PackedInt32Array = [0, 0, 0, 0, 0, 0]
	var sampled: int = 0
	var clouded: int = 0
	var red_pixels: int = 0
	var reddest: float = 0.0
	var contrast: float = 0.0
	var contrasted: int = 0
	for node in sets:
		var lights := node as MultiMeshInstance3D
		for i in range(lights.multimesh.instance_count):
			var colour: Color = lights.multimesh.get_instance_color(i)
			if colour.r < 0.9 or colour.g > 0.3:
				continue
			var at: Vector3 = lights.global_transform * lights.multimesh.get_instance_transform(i).origin
			if eye.is_position_behind(at):
				continue
			var on_screen: Vector2 = eye.unproject_position(at)
			if not frame.has_point(on_screen):
				continue
			if _behind_a_cloud(eye, at):
				clouded += 1
				continue
			sampled += 1
			var away: float = eye.global_position.distance_to(at)
			var band: int = 0 if away < RANGE_NEAR else (1 if away < RANGE_FAR else 2)
			bands[band * 2] += 1
			var red_before: int = red_pixels
			var core: float = 0.0
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var px: Color = picture.get_pixel(int(on_screen.x) + dx, int(on_screen.y) + dy)
					reddest = maxf(reddest, px.r - maxf(px.g, px.b))
					core = maxf(core, _luminance(px))
					if px.r > 0.5 and px.r > 1.8 * maxf(px.g, px.b):
						red_pixels += 1
			bands[band * 2 + 1] += red_pixels - red_before
			if ringed.has_point(on_screen):
				var around: float = 0.0
				for k in range(RING_SAMPLES):
					var angle: float = TAU * float(k) / float(RING_SAMPLES)
					var at_ring: Vector2 = on_screen + Vector2(cos(angle), sin(angle)) * RING
					around += _luminance(picture.get_pixel(int(at_ring.x), int(at_ring.y)))
				contrast += core / maxf(around / float(RING_SAMPLES), 0.02)
				contrasted += 1
	return {"bands": bands, "sampled": sampled, "clouded": clouded, "red_pixels_per_light": float(red_pixels) / maxf(float(sampled), 1.0),
		"reddest": reddest, "contrast": contrast / maxf(float(contrasted), 1.0)}


static func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## A reading kept under `key` and the time of day, for `_hold_the_night`; nothing is kept for a run with no `--time`.
static func _file_a_reading(store: Dictionary, key: String, time: int, reading: Dictionary) -> void:
	if time < 0:
		return
	if not store.has(key):
		store[key] = {}
	(store[key] as Dictionary)[time] = reading


## WHAT EACH VIEW IS A PICTURE OF, for the brightness measure. A view not listed here is not measured.
##
## NOT `fields`: from there a fire's smoke column stands in front of the grass, and the PLAIN puffs stay pale whatever the
## light -- the first night gate read that view's "ground" at 0.131 with no moon, no ambient and no lit window at all.
const SUBJECT_OF: Dictionary = {"grass": "ground", "mountains": "mountains",
	"forest_high": "forest", "forest_low": "forest", "town_approach": "towns", "town_street": "towns",
	"town_night_lights": "towns"}

## THE LEAST MEAN LUMINANCE EACH SUBJECT MAY HAVE AT NIGHT, on the 0..1 pixel values of the saved picture: about half of
## what the darker finish read on 2026-09-13 (stock 4.7.2, d3d12, RTX 5080, 1600x900 at 3D scale 1.40) -- ground 0.057
## (FINE; PLAIN 0.128), mountains 0.060, forest 0.028, towns 0.345 (windows and walls together). By day the same
## points read 0.39 to 0.55. A night with no moon, no ambient and no lit window read under every floor (agents.md).
##
## TOWNS ARE NOT HALF. Lit windows put them at 0.35 to 0.44, and a floor under that would pass a town whose walls were
## black behind its windows. The floor is between the walls alone and nothing: HEAD's shader, with no window lit, read
## 0.044 to 0.076 on the three town views at night, and a night with no light at all 0.025 (the sky between buildings).
const NIGHT_FLOOR: Dictionary = {"ground": 0.03, "mountains": 0.03, "forest": 0.014, "towns": 0.035}
## How far below day's a red light's pixel count may fall at night: none, but for the measure's own spread.
const LIGHTS_KEPT: float = 0.9
## THE FEWEST RED PIXELS A LIGHT MAY HAVE AT NIGHT, on average. Kept beside day's because a light dim by day AND by night
## keeps night level with day: lights drawn at a tenth of their brightness read 0 red pixels a light on both and passed
## the comparison (2026-09-13). The fewest a real night gave was 0.50, the runway from `forest_high` at 2.5 km on PLAIN.
const LIGHT_PIXELS_LEAST: float = 0.25
## How much brighter than what is round it a red light must be at night to be found by it.
const LIGHT_CONTRAST_LEAST: float = 3.0


## HOW BRIGHT THE SUBJECT OF A VIEW IS: the mean luminance of a 9x9 box round each of a handful of points on it,
## projected into the saved picture. Points on the subject rather than the whole frame, because a night picture is
## mostly sky, and a dark sky over a black mountain averages to the same number as a dark sky over a lit one.
func _measure_the_brightness(picture: Image, view: String, finish_name: String, finish_asked: String,
		time: int) -> void:
	if not SUBJECT_OF.has(view):
		return
	var eye: Camera3D = get_viewport().get_camera_3d()
	if eye == null:
		return
	var frame := Rect2(Vector2.ZERO, Vector2(picture.get_width(), picture.get_height())).grow(-5.0)
	var total: float = 0.0
	var counted: int = 0
	var points: int = 0
	for at in _points_on_the_subject(view):
		if eye.is_position_behind(at):
			continue
		var on_screen: Vector2 = eye.unproject_position(at)
		if not frame.has_point(on_screen):
			continue
		points += 1
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				total += _luminance(picture.get_pixel(int(on_screen.x) + dx, int(on_screen.y) + dy))
				counted += 1
	var mean: float = total / maxf(float(counted), 1.0)
	print("[scenery] brightness view=%s finish=%s subject=%s points=%d mean_luminance=%.4f"
		% [view, finish_name, SUBJECT_OF[view], points, mean])
	_file_a_reading(_brightness_readings, "%s|%s" % [view, finish_asked], time,
		{"subject": SUBJECT_OF[view], "points": points, "mean": mean})


## Points on what a view is a picture of, in the world.
func _points_on_the_subject(view: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	match String(SUBJECT_OF.get(view, "")):
		"ground":
			# ON THE GRASS BETWEEN THE EYE AND WHERE IT LOOKS: a man's height up, so the ground runs from the bottom of the
			# frame to the horizon, and these points are the near half of it, spread either side of the line of sight.
			var pose: Array = _pose(view)
			if not pose.is_empty():
				var eye_at: Vector3 = pose[0]
				var ahead: Vector3 = (pose[1] as Vector3) - eye_at
				ahead.y = 0.0
				var side: Vector3 = ahead.normalized().cross(Vector3.UP)
				for t in [0.03, 0.06, 0.10, 0.20]:
					for s in [-1.0, 0.0, 1.0]:
						var at: Vector3 = eye_at + ahead * t + side * s * ahead.length() * t * 0.4
						out.append(Vector3(at.x, 0.05, at.z))
		"mountains":
			var peak: Dictionary = _tallest_rock()
			if not peak.is_empty():
				var centre: Vector3 = peak["position"]
				var half: Vector3 = peak["half_extents"]
				out.append(centre)
				for sx in [-0.6, 0.6]:
					for sy in [-0.6, 0.6]:
						for sz in [-0.6, 0.6]:
							out.append(centre + half * Vector3(sx, sy, sz))
		"forest":
			var stand: Dictionary = _first_stand()
			if not stand.is_empty():
				var half: Vector2 = stand["half"]
				for k in [-0.6, 0.0, 0.6]:
					for m in [-0.6, 0.0, 0.6]:
						out.append((stand["centre"] as Vector3) + (stand["along"] as Vector3) * half.y * k
							+ (stand["across"] as Vector3) * half.x * m + Vector3.UP * 8.0)
		"towns":
			# THE FIRST TOWN'S BUILDINGS, a third of the way up each: walls and windows together, which is what a town
			# at night is.
			if _level.towns != null:
				var town: Dictionary = TownCatalogue.towns()[0]
				for building in _level.towns.drawn_buildings():
					var at: Vector3 = building["position"]
					if Vector2(at.x - town["centre"].x, at.z - town["centre"].z).length() > float(town.get("radius", 900.0)):
						continue
					out.append(at + Vector3.UP * (building["half_extents"] as Vector3).y * 0.3)
					if out.size() >= 80:
						break
	return out


## NIGHT, HELD TO THE STATED FLOORS AND TO DAY, off this run's own readings. Asked only of what a `--time` run drew.
##
## THE RED LIGHTS stay findable: at night a view that had red lights on screen by day still has them, their red pixels
## a light do not fall below `LIGHTS_KEPT` of day's, and they are `LIGHT_CONTRAST_LEAST` times brighter than the ring
## round them. The lights are unshaded, so nothing about night should touch them -- which is exactly the claim a
## tonemapper, a fog or a halo blended over a dark sky could quietly break.
##
## THE SCENERY does not go black: each subject's mean luminance at night is at least its `NIGHT_FLOOR`.
func _hold_the_night() -> void:
	var night_time: int = DaylightTuning.When.NIGHT
	var day_time: int = DaylightTuning.When.DAY
	for key in _light_readings:
		var by_time: Dictionary = _light_readings[key]
		if not by_time.has(night_time):
			continue
		var night: Dictionary = by_time[night_time]
		var day: Dictionary = by_time.get(day_time, {})
		var had_day: bool = not day.is_empty() and int(day["sampled"]) > 0
		var clouded: int = int(night.get("clouded", 0))
		if clouded > 0 and not String(key).get_slice("|", 0) in LIGHTS_IN_CLOUD_VIEWS:
			_check("the_night_lights_check_still_counts_lights_clear_of_cloud_%s" % String(key).replace("|", "_"),
				int(night["sampled"]) >= LIGHTS_CLEAR_LEAST, "%d clear of cloud, %d behind %.1f or more of it, at least %d" % [
					night["sampled"], clouded, LIGHT_CLOUDED, LIGHTS_CLEAR_LEAST])
		if int(night["sampled"]) == 0 and not had_day:
			continue
		var kept: bool = not had_day \
			or float(night["red_pixels_per_light"]) >= float(day["red_pixels_per_light"]) * LIGHTS_KEPT
		_check("the_red_lights_are_findable_at_night_%s" % String(key).replace("|", "_"),
			int(night["sampled"]) > 0 and kept and float(night["red_pixels_per_light"]) >= LIGHT_PIXELS_LEAST
				and float(night["contrast"]) >= LIGHT_CONTRAST_LEAST,
			"night: %d lights, %.2f red px a light, contrast %.2f; day: %s" % [night["sampled"],
				night["red_pixels_per_light"], night["contrast"], "%d lights, %.2f red px a light, contrast %.2f" % [
					day["sampled"], day["red_pixels_per_light"], day["contrast"]] if not day.is_empty() else "not drawn"])
	for key in _brightness_readings:
		var by_time: Dictionary = _brightness_readings[key]
		if not by_time.has(night_time):
			continue
		var night: Dictionary = by_time[night_time]
		var floor_of: float = float(NIGHT_FLOOR[night["subject"]])
		var day: Dictionary = by_time.get(day_time, {})
		_check("the_%s_is_not_black_at_night_%s" % [night["subject"], String(key).replace("|", "_")],
			int(night["points"]) > 0 and float(night["mean"]) >= floor_of,
			"night %.4f over %d points against a floor of %.3f; day %s" % [night["mean"], night["points"], floor_of,
				"%.4f" % float(day["mean"]) if not day.is_empty() else "not drawn"])


## ---- a salvo, for what missiles cost ------------------------------------------------------

## WHERE A SALVO STARTS: nine hundred metres over the runway's threshold, which the `missiles` view looks at.
static func _salvo_origin() -> Vector3:
	var line: Dictionary = Terrain.runway_axis()
	return (line["threshold"] as Vector3) + Vector3.UP * 900.0


## EIGHT AEROPLANES IN A LINE ABREAST, NOBODY IN THEM, EACH LAUNCHING ONE MISSILE OFF ITS NOSE -- put there on the server
## the moment before a finish is timed, so every motor is burning and every trail being laid for the whole capture.
## `launch_missile` is the simulation's own launch for things with no hands (it honours the rails and the reload and
## ignores the master arm and the lock), so what is drawn is exactly what a launch sends. A fresh salvo per finish:
## the last one's aeroplanes have fallen out of the sky by then, and their missiles have burnt out.
func _launch_a_salvo() -> void:
	var server: Object = get_node("/root/Sim").get("server")
	if server == null or not server.has_method("launch_missile"):
		_check("there_is_a_server_to_launch_from", false, "no server, or a library without missiles")
		return
	var line: Dictionary = Terrain.runway_axis()
	var along: Vector3 = line["along"]
	var across: Vector3 = line["across"]
	var launched: int = 0
	for i in range(SALVO):
		var at: Vector3 = _salvo_origin() + across * (float(i) - float(SALVO - 1) * 0.5) * 40.0
		var craft: int = int(server.spawn_vehicle(Sim.Kind.PLANE, at, atan2(-along.x, -along.z), along * 80.0))
		if craft != 0 and int(server.launch_missile(craft, i % 2, 0)) != 0:
			launched += 1
	print("[scenery] salvo: %d of %d missiles launched" % [launched, SALVO])


## HOW MANY MISSILES AND TRAIL SEGMENTS WERE DRAWN, so a comparison of what they cost can show it had them.
func _missiles_drawn() -> Array:
	var yard: Node = _level.get_node_or_null("Missiles")
	if yard == null:
		return [0, 0]
	return [int(yard.call("in_the_air")), int(yard.call("trail_segments"))]


## ---- where to stand ------------------------------------------------------------------

## [from, toward] for a view, or [] if there is nothing to point at. Asked every frame for a view of
## something that moves, so it keeps it in frame; worked out once a run for every other view.
func _pose(view: String) -> Array:
	if _pose_every_frame or _moves(view):
		return _pose_asked(view)
	if not _pose_cache.has(view):
		_pose_cache[view] = _pose_asked(view)
	return _pose_cache[view]


## The point the mist sweeps look at: the middle of the stratus band at the time of day over `mist_under`'s patch.
func _sweep_patch() -> Vector3:
	var mist: Dictionary = MistTuning.preset(maxi(_level.time_of_day(), 0))
	var ground: float = Terrain.surface_height(Vector3(-1800.0, 0.0, 0.0))
	return Vector3(-1800.0, ground + float(mist["stratus_height"]), 0.0)


## ONE STEP OF A MIST SWEEP READ BACK, on the last timed frame it is held: the mean of the 5 by 5 pixels round the patch's
## point on the screen, the head's pitch, the eye's height over the band and the ray's angle under level, then on to the next.
func _read_the_sweep(view: String, finish_name: String, frame: int) -> void:
	if frame % SWEEP_HOLD != SWEEP_HOLD - 1 or _sweep_step >= SWEEP_STEPS:
		return
	var eye: Camera3D = _level.observer
	var patch: Vector3 = _sweep_patch()
	var picture: Image = get_viewport().get_texture().get_image()
	var at: Vector2 = eye.unproject_position(patch) * Vector2(picture.get_size()) / get_viewport().get_visible_rect().size
	var sum: float = 0.0
	var count: int = 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var px := Vector2i(int(at.x) + dx, int(at.y) + dy)
			if px.x >= 0 and px.y >= 0 and px.x < picture.get_width() and px.y < picture.get_height():
				sum += picture.get_pixelv(px).get_luminance()
				count += 1
	var ray: Vector3 = (patch - eye.global_position).normalized()
	print("[mist-sweep] view=%s finish=%s step=%d pitch_deg=%.2f eye_over_band_m=%.1f ray_under_level_deg=%.2f patch=%.4f pixel=%s" % [
		view, finish_name, _sweep_step, rad_to_deg(eye.global_rotation.x), eye.global_position.y - patch.y,
		-rad_to_deg(asin(ray.y)), sum / maxf(float(count), 1.0), at.round()])
	_sweep_step += 1


## Whether a view's pose is asked every frame: its subject moves, or it is `moon` carried aside.
static func _moves(view: String) -> bool:
	return MOVING_VIEWS.has(view) or view.begins_with("moon_at_")


func _pose_asked(view: String) -> Array:
	match view:
		"strip", "strip_base":
			# THE WORLD'S FIRST RUNWAY, whichever world: the island's, or the generated ground's flattest strip's. The same two
			# poses as "runway" and "runway_base", off `Terrain.runways()[0]` rather than the island runway's `runway_axis()`.
			var first: Dictionary = Terrain.runways()[0]
			var first_along: Vector3 = first["along"]
			var first_across: Vector3 = first["across"]
			var first_threshold: Vector3 = first["threshold"]
			if view == "strip":
				return [first_threshold - first_along * 120.0 + Vector3.UP * 8.0, (first["far_end"] as Vector3) + Vector3.UP * 2.0]
			return [first_threshold - first_along * 1200.0 + first_across * 1500.0 + Vector3.UP * 300.0, first["centre"]]
		"runway":
			# ON SHORT FINAL, 700 m from the threshold on a three-degree slope, looking at the far
			# end of the strip from just above it -- so the runway fills the lower third of the frame and
			# the edge lights run away from the eye as two converging rows.
			var final: Dictionary = Terrain.runway_axis()
			var final_along: Vector3 = final["along"]
			var final_threshold: Vector3 = final["threshold"]
			# 120 M OUT AND 8 M UP. It was 700 m and 38 m, where render_check_3 (2026-09-12) showed
			# the strip as a small trapezoid at the horizon; and then 300 m and 18 m, where
			# render_check_4 showed the approach lights as clear rows but the strip itself still a
			# narrow shape at the horizon. Closer and lower, so the runway fills the lower frame.
			return [final_threshold - final_along * 120.0 + Vector3.UP * 8.0,
				final["far_end"] + Vector3.UP * 2.0]
		"missiles":
			# BESIDE WHERE A SALVO IS LAUNCHED, half a kilometre off its line and a little below it, looking along the way
			# the missiles go -- so the motors, the bodies and the first second of every trail are in frame. The same pose
			# with and without `--missiles`, which is what makes the two comparable.
			var line: Dictionary = Terrain.runway_axis()
			var from: Vector3 = _salvo_origin()
			return [from - (line["across"] as Vector3) * 500.0 - Vector3.UP * 60.0,
				from + (line["along"] as Vector3) * 400.0]
		"runway_base":
			# ON A BASE LEG, abeam and behind the threshold and three hundred metres up. It was
			# on final, straight down the centreline from 2.4 km, and the first render check
			# (2026-09-12) showed why that is the one view that cannot judge runway lights: end
			# on, every edge light, the threshold bars and the approach line stack into one blob
			# a few pixels across. From the side the rows are rows.
			var axis: Dictionary = Terrain.runway_axis()
			var along: Vector3 = axis["along"]
			var across: Vector3 = axis["across"]
			var threshold: Vector3 = axis["threshold"]
			return [threshold - along * 1200.0 + across * 1500.0 + Vector3.UP * 300.0,
				Terrain.RUNWAY_AT]
		"traffic", "traffic_near", "traffic_close":
			# `traffic_close` is 150 m off, inside where a light starts to fade (VehicleLights.DIM_FROM): the lights of
			# an aeroplane near enough to be seen as one, which a fade with distance must leave as they were. Asked for by
			# name only, so a run that names no views times what it always timed.
			var craft: VehicleView = _first_of(Sim.Kind.AIRLINER)
			if craft == null:
				return []
			var away: float = 2600.0 if view == "traffic" else (420.0 if view == "traffic_near" else 150.0)
			var at: Vector3 = craft.global_position
			return [at + Vector3(0.7, 0.12, 0.7).normalized() * away, at]
		"clouds":
			var zone: Dictionary = _widest_thermal()
			if zone.is_empty():
				return []
			var base: Vector3 = zone["position"]
			base.y = float(zone["top"])
			return [base + Vector3(-2600.0, -420.0, 1500.0), base]
		"cloud_near", "cloud_side", "cloud_edge", "cloud_inside", "cloud_fly":
			# THE CLOUDS VIEW'S OWN CLOUD, CLOSE, for a cloud you fly into (fog near the eye on FINE), from the same side: 700 m
			# outside its lumps (approaching); that pose 200 m to one side looking the same way, so a texture on the camera
			# rather than in the world would not move (strafe); half-way in from its edge (entering); 40 m from its middle,
			# a third of the way up, looking out through the far side (inside); and a pass flown into it at `FLY_SPEED` from
			# `FLY_FROM` outside, through the mesh-to-fog fade (`cloud_fly`, moving). Off `LiftYard.cloud_lumps`, so every pose
			# stands on the cloud either kind of cloud draws. Asked for by name only; so is `cloud_at_<metres>`, below.
			var frame: Array = _cloud_frame()
			if frame.is_empty():
				return []
			var middle: Vector3 = frame[0]
			var from_side: Vector3 = frame[1]
			var across: Vector3 = frame[2]
			var reach: float = frame[3]
			if view == "cloud_fly":
				var flown: float = float(maxi(Engine.get_process_frames() - _fly_began, 0)) / 60.0 * FLY_SPEED
				var start: float = FLY_FROM + float(SETTLE) / 60.0 * FLY_SPEED
				return [middle + from_side * (reach + start - flown), middle - from_side * (reach + 2000.0)]
			match view:
				"cloud_near":
					return [middle + from_side * (reach + 700.0), middle]
				"cloud_side":
					return [middle + from_side * (reach + 700.0) + across * 200.0, middle + across * 200.0]
				"cloud_edge":
					# ON THE PUFFS' SKIN rather than 0.6 of the way in: a puff cloud's reach is its farthest puff's edge, and
					# at 0.6 of it the eye was well inside, behind 1 or more of cloud from all nine lights in frame.
					var into: float = CLOUD_EDGE_ON_PUFFS if _level != null and _level.puffs != null else 0.6
					return [middle + from_side * (reach * into), middle]
			return [middle + from_side * 40.0, middle - from_side * reach]
		"coast":
			var edge: float = Terrain.WORLD_HALF
			return [Vector3(edge - 60.0, 45.0, 120.0), Vector3(edge + 700.0, 0.0, -250.0)]
		"sea":
			var edge: float = Terrain.WORLD_HALF
			return [Vector3(edge + 300.0, 650.0, 1800.0), Vector3(edge + 3200.0, 0.0, 0.0)]
		"grass":
			# A MAN'S HEIGHT OFF THE GRASS beside the runway, which is where a parked pilot's
			# eyes are and where blades of grass either exist or do not.
			return [Terrain.RUNWAY_AT + Vector3(-140.0, 1.8, -60.0),
				Terrain.RUNWAY_AT + Vector3(-220.0, 0.0, -360.0)]
		"fields":
			return [Terrain.RUNWAY_AT + Vector3(-500.0, 260.0, 1300.0),
				Terrain.RUNWAY_AT + Vector3(-500.0, 0.0, -700.0)]
		"mountains":
			var peak: Dictionary = _tallest_rock()
			if peak.is_empty():
				return []
			var top: Vector3 = peak["position"]
			var out: Vector3 = Vector3(-top.x, 0.0, -top.z).normalized()
			return [Vector3(top.x, 0.0, top.z) + out * 1300.0 + Vector3.UP * 360.0,
				Vector3(top.x, 240.0, top.z)]
		"mtn_fly":
			# A PASS ACROSS THE ISLAND'S APPROACH, 1.5 km up at 120 m/s from the settle's first frame, looking ahead and down
			# at ranges 5 to 15 km off, where a facet is about a pixel: the moving shot that shows whether faceted light
			# shimmers at distance (`--mountain-smooth=off` draws every facet flat to compare), and the blog's reel with
			# `--strip=1`. Fixed numbers, as the other mountain views.
			var flown: float = float(maxi(Engine.get_process_frames() - _fly_began, 0)) / 60.0 * 120.0
			var eye := Vector3(-9000.0 + flown, 1500.0, 6500.0 - flown * 0.35)
			return [eye, eye + Vector3(4000.0, -900.0, -3200.0)]
		"mtn_gully":
			# UP A GULLY, CLOSE: 350 m off the south-western inland range's flank at 160 m, looking across it -- where the
			# rock shader's creeks, rims, strata and scree are big enough to see. Off `Terrain.INLAND_RANGES` and the range's
			# own bearing (MountainRanges.INLAND_BEARINGS), so it stands off the flank wherever the range is laid. No before
			# picture: the boxes had no gullies.
			var middle: Vector3 = Terrain.INLAND_RANGES[0]
			var along := Vector3(cos(deg_to_rad(MountainRanges.INLAND_BEARINGS[0])), 0.0, sin(deg_to_rad(MountainRanges.INLAND_BEARINGS[0])))
			var aside := Vector3(-along.z, 0.0, along.x)
			return [middle + aside * 1150.0 + along * 300.0 + Vector3.UP * 160.0, middle + aside * 350.0 + Vector3.UP * 170.0]
		"mtn_ring", "mtn_far", "mtn_valley", "mtn_close":
			# THE MOUNTAINS' OWN FOUR, asked for by name (cockpit-mountains, 2026-09-18): FIXED NUMBERS, never asked of the
			# generator, because they are the before-and-after of a change to the generator -- a pose worked out from the
			# tallest rock would move with the thing being judged. The ring from beside the runway; the island from 20 km
			# out at 2 km up, the background a pilot sees on the way in; low down between the north-east range and the
			# ring; and a close pass along the ring's eastern flank.
			match view:
				"mtn_ring":
					return [Terrain.RUNWAY_AT + Vector3(60.0, 30.0, 0.0), Vector3(-3700.0, 220.0, -3700.0)]
				"mtn_far":
					return [Vector3(-18500.0, 2000.0, -14500.0), Vector3(-1800.0, 250.0, -3100.0)]
				"mtn_valley":
					return [Vector3(1500.0, 110.0, 4300.0), Vector3(4200.0, 140.0, 1600.0)]
			return [Vector3(4250.0, 240.0, -1400.0), Vector3(5300.0, 200.0, 400.0)]
		"fire":
			var fires: Array[Dictionary] = Terrain.fires()
			if fires.is_empty():
				return []
			var at: Vector3 = fires[0]["position"]
			return [at + Vector3(0.0, 200.0, 560.0), at + Vector3(0.0, 70.0, 0.0)]
		"forest_low":
			# A LOW PASS DOWN THE EDGE OF THE FIRST WOOD, 25 m up and 40 m outside its long side, from 80 m
			# short of one end, looking half-way down the edge: the view a helicopter or a low aeroplane has
			# of a forest, where the trees are a wall running away beside the eye and the canopy is a horizon
			# of its own. Anything wrong with a tree's shape, its fade or the ground under it shows here first.
			# It was 35 m up, 60 m out and 250 m short, looking at the far corner, and the first look
			# (2026-09-13) showed the near end of the wood face-on, 300 m off, and no edge at all.
			var stand: Dictionary = _first_stand()
			if stand.is_empty():
				return []
			var centre: Vector3 = stand["centre"]
			# ON THE GROUND UNDER THE WOOD'S MIDDLE (increment B4): the island's is its slab, 0, so its pose is unchanged.
			centre.y = Terrain.surface_height(centre)
			var along: Vector3 = stand["along"]
			var across: Vector3 = stand["across"]
			var half: Vector2 = stand["half"]
			var low_eye: Vector3 = centre - along * (half.y + 80.0) + across * (half.x + 40.0) + Vector3.UP * 25.0
			low_eye.y = maxf(low_eye.y, Terrain.surface_height(low_eye) + 20.0)
			return [low_eye, centre + along * (half.y * 0.5) + across * (half.x - 20.0) + Vector3.UP * 12.0]
		"forest_high":
			# THE SAME WOOD FROM 800 m UP AND ABOUT TWO KILOMETRES OFF, looking down on the middle of it:
			# the whole stand in one frame, so every chunk is drawn and the draw-call count is the worst the
			# forest can make, with the ground tint and the far fade both in the picture.
			var stand: Dictionary = _first_stand()
			if stand.is_empty():
				return []
			var centre: Vector3 = stand["centre"]
			centre.y = Terrain.surface_height(centre)
			return [centre + (stand["across"] as Vector3) * 1800.0 - (stand["along"] as Vector3) * 900.0
				+ Vector3.UP * 800.0, centre]
		"wood_seam":
			# WHERE A WOOD'S EDGE CROSSES A GROUND CELL'S SEAM (increment B4, team-lead's picture check of the per-cell floor list):
			# 300 m outside that edge, 150 m over the ground there, looking at the crossing, so both cells' floor shows.
			var seam: Array = _wood_edge_on_a_seam()
			if seam.is_empty():
				return []
			var crossing: Vector3 = seam[1]
			crossing.y = Terrain.surface_height(crossing)
			var eye: Vector3 = crossing + (seam[0] as Vector3) * 300.0
			eye.y = Terrain.surface_height(eye) + 150.0
			return [eye, crossing]
		"wood_close":
			# WHERE THE TREES MEET THE SLOPE, CLOSE (increment B4, team-lead's picture): the steepest point on any wood's edge -- the
			# first look used the busiest wood, which lay on a flat valley floor and showed no slope at all -- seen from 150 m
			# outside that edge, 20 m over the ground there, looking at it 10 m over its ground, so a trunk's downhill foot shows.
			var steep: Array = _steepest_wood_edge()
			if steep.is_empty():
				return []
			var stand: Dictionary = steep[0]
			var edge: Vector3 = steep[1]
			edge.y = Terrain.surface_height(edge) + 10.0
			var eye: Vector3 = edge + (stand["across"] as Vector3) * 150.0
			eye.y = Terrain.surface_height(eye) + 20.0
			return [eye, edge]
		"road_close":
			# A ROAD CLIMBING, CLOSE (increment B5, team-lead's picture): the steepest piece of road on the ground, from 120 m to its
			# lower side and 60 m back, 25 m over the ground there, looking at it 2 m over the road, so a pitched piece shows whether
			# it lies on its slope.
			var piece: Dictionary = _steepest_road_piece()
			if piece.is_empty():
				return []
			var middle: Vector3 = ((piece["from"] as Vector3) + (piece["to"] as Vector3)) * 0.5
			var eye: Vector3 = _beside_a_road(piece["from"], piece["to"], 120.0) - _road_along(piece["from"], piece["to"]) * 60.0
			eye.y = Terrain.surface_height(eye) + 25.0
			return [eye, middle + Vector3.UP * 2.0]
		"road_far":
			# A ROAD DOWN A VALLEY FROM AFAR (increment B5): the middle of the longest straight run of road, from 1.5 km to its
			# lower side and 500 m over the higher of the ground there and the road, so the road's line across the ground shows.
			var run: Array = _longest_road_run()
			if run.is_empty():
				return []
			var middle: Vector3 = ((run[0] as Vector3) + (run[1] as Vector3)) * 0.5
			var eye: Vector3 = _beside_a_road(run[0], run[1], 1500.0)
			eye.y = maxf(Terrain.surface_height(eye), middle.y) + 500.0
			return [eye, middle]
		"town_approach":
			# THE FIRST TOWN FROM TWO AND A HALF KILOMETRES OUT AND 250 m UP, from the south, looking at its
			# middle: its outline, its far fade and its roads. Off `TownCatalogue.towns()[0]`, the first city, which
			# stands where the first of the three tower grids stood.
			var town: Vector3 = TownCatalogue.towns()[0]["centre"]
			return [town + Vector3(0.0, 250.0, 2500.0), town + Vector3(0.0, 60.0, 0.0)]
		"town_street":
			# DOWN THE MIDDLE STREET AT 25 m, from 520 m south of the centre. The grid has an even number of
			# columns, so the town's own centre line is a street, between the two middle columns.
			var town: Vector3 = TownCatalogue.towns()[0]["centre"]
			return [town + Vector3(0.0, 25.0, 520.0), town + Vector3(0.0, 25.0, -400.0)]
		"town_night_lights":
			# THE FIRST TOWN FROM LOW ON A DIAGONAL, 120 m up: tall buildings against the sky, which is where
			# obstruction lights are read from, and drawn at night with `--time=night`.
			var town: Vector3 = TownCatalogue.towns()[0]["centre"]
			return [town + Vector3(-1800.0, 120.0, 1400.0), town + Vector3(0.0, 80.0, 0.0)]
		"town_windows":
			# THE FIRST TOWN FROM 900 m SOUTH AND 120 m UP, looking at its middle: its near edge about 430 m off and its far
			# edge about 1370 m, which is the range where a window goes from a few pixels to less than one at the headset's
			# render scale -- and so where a hard-edged window shimmered (2026-09-13). Asked for by name only, so
			# `--views=scenery` is still the five views its timings were written against.
			var town: Vector3 = TownCatalogue.towns()[0]["centre"]
			return [town + Vector3(0.0, 120.0, 900.0), town + Vector3(0.0, 40.0, 0.0)]
		"mist_city":
			# THE FIRST CITY FROM THREE KILOMETRES SOUTH AND 300 m UP, looking at its middle: the haze over a town, and at night
			# its lights through it. Asked for by name only, like every mist view.
			var town: Vector3 = TownCatalogue.towns()[0]["centre"]
			return [town + Vector3(0.0, 300.0, 3000.0), town + Vector3(0.0, 40.0, 0.0)]
		"mist_valley":
			# THE FIRST INLAND RANGE FROM 600 m UP AND TWO KILOMETRES OFF, looking down into the low ground among its peaks: where
			# valley fog would lie. Off `Terrain.INLAND_RANGES`, the range's own centre.
			var range_at: Vector3 = Terrain.INLAND_RANGES[0]
			return [range_at + Vector3(1400.0, 600.0, 1500.0), range_at]
		"mist_summit":
			# THE TALLEST SUMMIT, LEVEL WITH ITS TOP, a kilometre and a half off: where a cap of cloud would sit.
			var peak: Dictionary = _tallest_rock()
			if peak.is_empty():
				return []
			var top: Vector3 = peak["position"]
			var out: Vector3 = Vector3(-top.x, 0.0, -top.z).normalized()
			var summit: float = top.y + (peak["half_extents"] as Vector3).y
			return [Vector3(top.x, summit + 40.0, top.z) + out * 1500.0, Vector3(top.x, summit - 30.0, top.z)]
		"cumulus_side":
			# THE CLOUDS VIEW'S CLOUD AND ITS NEIGHBOURS FROM TWO KILOMETRES UP, the sun square to one side of the view, whatever
			# the time of day: how a cloud's lit side, its shade and its underside read as a volume. Asked every frame, because
			# the sun moves with the time of day and the pose follows it.
			var frame: Array = _cloud_frame()
			if frame.is_empty():
				return []
			var middle: Vector3 = frame[0]
			var sun: Vector3 = DaylightTuning.towards_the_sun(maxi(_level.time_of_day(), 0))
			var flat_sun := Vector3(sun.x, 0.0, sun.z).normalized()
			var from_side: Vector3 = flat_sun.cross(Vector3.UP)
			return [Vector3(middle.x, 2000.0, middle.z) + from_side * 3200.0, middle]
	# `mist_under`: 60 m over open ground west of the runway looking 80 degrees up, under a low stratus patch (200 m over the
	# ground at night): whether stars show through a patch overhead, drawn with and without `--mist=off`. Asked for by name only.
	# THE PLACE WAS FOUND OFF THE MIST'S OWN NOISE, not by eye: the first pose, 400 m east of the runway, had no patch over it, and
	# with and without mist drew the same stars (step2-try4). (-1800, 0) has the patch whole over it and 150 m round it on both
	# finishes (the include's wrapped value noise run in float32, cover 0.94), 2.2 km from the nearest inland range and 1.1 km
	# from the nearest town.
	# THE MIST SWEEPS, for a patch of low stratus seen near level (team-lead, 2026-09-15: the stratus fades out on a ray within a
	# few degrees of level, and in a headset "a patch that appears and disappears as you nod would be worse than a thin line").
	# Both look at one point in the middle of the band over (-1800, 0) -- `mist_under`'s patch, whole there -- from 2 km west.
	# `mist_nod`: the eye still, 80 m over the band (the point 2.3 degrees under level, inside the fade), the head pitched from
	# level down to 5 degrees in `SWEEP_STEPS` steps: the patch must not change, because the fade is the ray's own direction in the
	# world. `mist_climb`: the eye climbing from 10 m to 160 m over the band, so the ray to the point goes from 0.3 to 4.6 degrees
	# through the whole fade: the patch must come in smoothly. Each step held `SWEEP_HOLD` timed frames, read by
	# `_read_the_sweep`. Asked for by name only.
	# `mist_low`: flying low beside the stratus -- the eye 30 m over the band's middle and a kilometre west of the same patch,
	# looking at it -- where the patch is within two degrees of level and must stay, because the angle fade is weighed in only
	# past 1.5 km (team-lead, 2026-09-15). Asked every frame, because the band's height is the time of day's.
	# `mist_deck`: under the same patch, looking up at its middle 20 degrees over level from 140 m under it -- flying under a
	# deck keeps its ceiling, because the angle fade lets a patch through past 9.8 degrees (team-lead, 2026-09-15).
	# `mist_lens`: cockpit-streetlights' "above" pose -- 160 m up, a kilometre south of the inner town, looking at it -- where a
	# patch near level seen from just under the band's middle was a pale lens over the town at night (their step2c
	# above/town-plain-night-clear-01km, 2026-09-15). Off `TownCatalogue.towns()`' first town, never typed: the one seam for where
	# towns are, so on alpine the pose follows the inner town's seat (cockpit-terrain's B1).
	if view == "mist_lens":
		var inner: Vector3 = TownCatalogue.towns()[0]["centre"]
		return [inner + Vector3(0.0, 160.0, 1000.0), inner + Vector3(0.0, 40.0, 0.0)]
	if view == "mist_deck":
		var deck: Vector3 = _sweep_patch()
		return [deck + Vector3(-140.0 / tan(deg_to_rad(20.0)), -140.0, 0.0), deck]
	if view == "mist_low":
		var near_patch: Vector3 = _sweep_patch()
		return [near_patch + Vector3(-1000.0, 30.0, 0.0), near_patch]
	if view == "mist_nod" or view == "mist_climb":
		var patch: Vector3 = _sweep_patch()
		var step: float = float(mini(_sweep_step, SWEEP_STEPS - 1)) / float(SWEEP_STEPS - 1)
		if view == "mist_nod":
			var still := patch + Vector3(-2000.0, 80.0, 0.0)
			var pitch: float = deg_to_rad(-5.0 * step)
			return [still, still + Vector3(cos(pitch), sin(pitch), 0.0) * 1000.0]
		return [patch + Vector3(-2000.0, lerpf(10.0, 160.0, step), 0.0), patch]
	if view == "mist_under":
		var under := Vector3(-1800.0, 60.0, 0.0)
		return [under, under + Vector3(cos(deg_to_rad(80.0)), sin(deg_to_rad(80.0)), 0.0) * 1000.0]
	# `moon`: 300 m over the runway looking straight along the level's own DirectionalLight3D, towards where the light comes
	# from -- the moon at night, the sun by day -- read off the light and not off a second copy of its direction, and asked
	# every frame (MOVING_VIEWS) because a change of time moves it. `zenith`: the same place looking up, a degree off the
	# vertical so the camera has an up, for the stars. `moon_at_<metres>`: `moon` carried that far across the way the cirrus
	# streaks lie, so a row of them finds a streak in front of the moon.
	if view.begins_with("moon_at_") and view.trim_prefix("moon_at_").is_valid_int():
		var along_streaks: Vector2 = CloudTuning.CIRRUS_HEADING.normalized()
		var aside := Vector3(-along_streaks.y, 0.0, along_streaks.x) * float(view.trim_prefix("moon_at_").to_int())
		var shown: Array = _pose_asked("moon")
		return [] if shown.is_empty() else [(shown[0] as Vector3) + aside, (shown[1] as Vector3) + aside]
	if view == "moon" or view == "zenith":
		var over_runway: Vector3 = Terrain.RUNWAY_AT + Vector3(0.0, 300.0, 0.0)
		if view == "zenith":
			return [over_runway, over_runway + Vector3(0.0, 1000.0, 17.5)]
		var light := _level.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if light == null:
			return []
		return [over_runway, over_runway + light.global_basis.z.normalized() * 1000.0]
	# `cirrus`: 300 m over the runway looking 50 degrees up along the way the cirrus streaks lie (`CloudTuning.CIRRUS_HEADING`),
	# so the sheet nine kilometres up fills the frame -- every other view looks near the horizon, where the sheet fades out.
	if view == "cirrus":
		var lie: Vector2 = CloudTuning.CIRRUS_HEADING.normalized()
		var up_from: Vector3 = Terrain.RUNWAY_AT + Vector3(0.0, 300.0, 0.0)
		return [up_from, up_from + Vector3(lie.x * cos(deg_to_rad(50.0)), sin(deg_to_rad(50.0)), lie.y * cos(deg_to_rad(50.0))) * 1000.0]
	# `cloud_at_<metres>`: the approach to the clouds view's cloud from `cloud_near`'s side, that many metres outside its lumps'
	# reach (negative is inside), looking at its middle -- a still strip through the mesh-to-fog fade.
	# `cloud_each_<n>`: the n-th lift zone's cloud from the same distance and the same side as every other one's --
	# `CLOUD_EACH_AWAY` from its middle, level with it -- so a sheet of them shows whether the clouds differ.
	# `lift_slope_<n>`: the n-th lift zone whole -- its ring on the ground, its wisps and its cloud -- from LIFT_SLOPE_AWAY off
	# its middle on the side away from the world's middle, LIFT_SLOPE_OVER over the ground there, looking at a point a third
	# of the way up its column: on the generated ground a ring draped over a slope under its own cloud (increment B3).
	if view.begins_with("lift_slope_") and view.trim_prefix("lift_slope_").is_valid_int():
		var rising: Array[Dictionary] = Terrain.lift_zones()
		var n: int = view.trim_prefix("lift_slope_").to_int()
		if n < 0 or n >= rising.size():
			return []
		var base: Vector3 = rising[n]["position"]
		var away := Vector3(base.x, 0.0, base.z).normalized() if Vector2(base.x, base.z).length() > 1.0 else Vector3.BACK
		var eye: Vector3 = base + away * LIFT_SLOPE_AWAY
		eye.y = Terrain.surface_height(eye) + LIFT_SLOPE_OVER
		return [eye, Vector3(base.x, base.y + (float(rising[n]["top"]) - base.y) / 3.0, base.z)]
	if view.begins_with("cloud_each_") and view.trim_prefix("cloud_each_").is_valid_int():
		var zones: Array[Dictionary] = Terrain.lift_zones()
		var which: int = view.trim_prefix("cloud_each_").to_int()
		if which < 0 or which >= zones.size():
			return []
		var each: Array = _cloud_frame(zones[which])
		var from_side: Vector3 = each[1]
		return [(each[0] as Vector3) + from_side * CLOUD_EACH_AWAY, each[0]]
	if view.begins_with("cloud_at_") and view.trim_prefix("cloud_at_").is_valid_int():
		var frame: Array = _cloud_frame()
		if frame.is_empty():
			return []
		var outside: float = float(view.trim_prefix("cloud_at_").to_int())
		var middle: Vector3 = frame[0]
		var from_side: Vector3 = frame[1]
		return [middle + from_side * (float(frame[3]) + outside), middle - from_side * float(frame[3])]
	return []


## THE CLOUDS VIEW'S CLOUD, AS POSES ARE STOOD ROUND IT: [its middle a third of the way up, the way the clouds view looks at it
## from, across that way, how far its lumps reach from the middle], or [] with no thermal.
func _cloud_frame(asked: Dictionary = {}) -> Array:
	var zone: Dictionary = asked if not asked.is_empty() else _widest_thermal()
	if zone.is_empty():
		return []
	var middle: Vector3 = zone["position"]
	var base_y: float = float(zone["top"])
	var reach: float = 0.0
	var top: float = base_y
	var from_side: Vector3 = Vector3(-2600.0, 0.0, 1500.0).normalized()
	# THE PUFF CLOUD THE LEVEL DRAWS OVER THIS THERMAL, where it wears the puffs (PuffSky, 2026-09-17): its own middle, reach
	# and height, since it is not laid out as LiftYard's lumps were and is squashed under the layer above it.
	if _level != null and _level.puffs != null:
		for cloud in _level.puffs.clouds:
			if cloud.get("key", Vector2i(-1, -1)) == LiftYard.cloud_key(zone):
				var m: Vector3 = PuffCloud.middle_of(cloud)
				m.y = float(cloud["base"]) + float(cloud["thickness"]) * 0.3
				var puff_reach: float = PuffCloud.reach_of(cloud)
				# FROM CLEAR AIR, WITH TRAFFIC IN SIGHT: of twelve headings round the cloud whose approach pose is in no cloud,
				# the one whose edge pose sees the most aircraft lights clear of cloud. The first try came in from the lumps'
				# heading and stood the approach camera inside a neighbouring cumulus (eye depth 0.39), behind 5.7 to 16 of
				# cloud from every light it looked for; and at the edge, a heading chosen for clear air alone kept 0 to 3 of
				# 12 lights in frame clear. Asked once a zone and kept, since the view's pose is asked every view.
				# AND THE SIDE POSE TOO (clouds3, 2026-09-18): scored on the edge pose alone, the heading chosen after the
				# F-14, F-16, Savoia and MH-6 got island spawns stood cloud_side's camera with the cloud across the whole
				# frame, 0 lights clear of it against 82 behind at night, and its floor went red. So a heading is scored by
				# the fewer of the two views' clear lights, and the side pose must stand in clear air as the approach does.
				var key: Vector2i = LiftYard.cloud_key(zone)
				if _puff_heading.has(key):
					var kept: Vector3 = _puff_heading[key]
					return [m, kept, kept.cross(Vector3.UP), puff_reach]
				var best: Vector3 = from_side
				var most: int = -1
				var chosen: int = 0
				for turn in range(12):
					var side: Vector3 = from_side.rotated(Vector3.UP, TAU * float(turn) / 12.0)
					var along: Vector3 = side.cross(Vector3.UP)
					var side_eye: Vector3 = m + side * (puff_reach + 700.0) + along * 200.0
					if _level.puffs.eye_in(m + side * (puff_reach + 700.0))["depth"] > 0.0 							or _level.puffs.eye_in(side_eye)["depth"] > 0.0:
						continue
					var seen: int = mini(_lights_clear_from(m + side * (puff_reach * CLOUD_EDGE_ON_PUFFS), m),
						_lights_clear_from(side_eye, m + along * 200.0))
					if seen > most:
						most = seen
						best = side
						chosen = turn
				if _cloud_turn >= 0:
					chosen = _cloud_turn
					best = from_side.rotated(Vector3.UP, TAU * float(chosen) / 12.0)
				print("[scenery] cloud views stand on turn %d of 12 (%s)" % [chosen, "asked" if _cloud_turn >= 0 else "chosen"])
				_puff_heading[key] = best
				return [m, best, best.cross(Vector3.UP), puff_reach]
	for lump in LiftYard.cloud_lumps(zone, Terrain.WIND):
		var t: Transform3D = lump["transform"]
		reach = maxf(reach, Vector2(t.origin.x - middle.x, t.origin.z - middle.z).length() + t.basis.x.length() * 0.5)
		top = maxf(top, t.origin.y + t.basis.y.length() * 0.5)
	middle.y = base_y + (top - base_y) * 0.3
	return [middle, from_side, from_side.cross(Vector3.UP), reach]


## ---- shimmer, for `--drift` ---------------------------------------------------------------

## HOW MUCH OF A TOWN CHANGES FROM ONE FRAME TO THE NEXT while the camera drifts sideways a little. See `--drift`.
func _measure_the_shimmer(view: String, finish_asked: String, time: int) -> void:
	var finish_name: String = finish_asked if time < 0 \
		else "%s-%s" % [finish_asked, DaylightTuning.name_of(time).to_lower()]
	# RADIANS A PIXEL, off the camera's own vertical field of view and the picture's height: near enough the same across
	# the frame for a turn this small.
	_drift_turn = 0.0
	await RenderingServer.frame_post_draw
	var before: Image = get_viewport().get_texture().get_image()
	before.convert(Image.FORMAT_RGB8)
	var eye: Camera3D = get_viewport().get_camera_3d()
	var per_pixel: float = deg_to_rad(eye.fov if eye != null else 75.0) / float(before.get_height())
	var on_lights: bool = LIGHT_SHIMMER_VIEWS.has(view)
	var area: Rect2i = _the_town_on_screen(before)
	var boxes: Array[Rect2i] = []
	_heat.resize(before.get_width() * before.get_height())
	_heat.fill(0)
	var earlier: Image = null
	var flips: int = 0
	var toggles: int = 0
	var lit: int = 0
	var mean_change: float = 0.0
	# THE PROBE HELD TO ITSELF. A picture that came back a frame late, or a camera that did not turn when asked, makes
	# every edge in the frame step back and forth -- which the toggle count cannot tell from shimmer. So each frame the
	# camera's own yaw is read back against the turn asked for, and each picture is held to the one two frames back: a
	# steady turn leaves it further from that one than from the last, and a picture nearer the one two back stepped back.
	var start_yaw: float = eye.global_rotation.y if eye != null else 0.0
	var worst_turn_error: float = 0.0
	var stepped_back: int = 0
	for i in range(DRIFT_FRAMES):
		_drift_turn = per_pixel * _drift * float(i + 1)
		await RenderingServer.frame_post_draw
		var after: Image = get_viewport().get_texture().get_image()
		# `--strip` saves the turn as well, to see what a turn does -- temporal reprojection ghosting, on the cloud views.
		if _strip > 0 and i % _strip == 0:
			after.save_png("%s/%s-%s-drift%04d.png" % [_out, view, finish_name, i])
		after.convert(Image.FORMAT_RGB8)
		if eye != null:
			worst_turn_error = maxf(worst_turn_error,
				absf(angle_difference(start_yaw + _drift_turn, eye.global_rotation.y)) / per_pixel)
		var counted: Vector3i
		if on_lights:
			# THIS FRAME'S BOXES: the turn moves a light a quarter of a pixel a frame and fifteen over the drift.
			boxes = _red_lights_on_screen(eye, after)
			counted = _red_crossings(earlier, before, after, boxes)
		else:
			counted = _crossings(earlier, before, after, area)
		flips += counted.x
		toggles += counted.y
		lit += counted.z
		var from_last: float = float(after.compute_image_metrics(before, true)["mean"])
		mean_change += from_last
		if earlier != null and float(after.compute_image_metrics(earlier, true)["mean"]) < from_last:
			stepped_back += 1
		earlier = before
		before = after
	print("[scenery] shimmer_probe view=%s turn_error_px=%.3f stepped_back=%d of %d" % [view, worst_turn_error,
		stepped_back, DRIFT_FRAMES - 1])
	_drift_turn = 0.0
	if on_lights:
		area = Rect2i()
		for box in boxes:
			area = box if area.size == Vector2i.ZERO else area.merge(box)
	_save_the_heat(before, area, "%s/%s-%s-shimmer.png" % [_out, view, finish_name], 1 if on_lights else 2)
	var frames: float = float(DRIFT_FRAMES)
	print("[scenery] shimmer view=%s finish=%s drift_px=%.3f frames=%d on=%s area=%s bright_px=%.1f flips_per_frame=%.1f toggles_per_frame=%.1f mean_change=%.4f"
		% [view, finish_name, _drift, DRIFT_FRAMES, "lights(%d)" % boxes.size() if on_lights else "town", area,
			float(lit) / frames, float(flips) / frames, float(toggles) / (frames - 1.0), mean_change / frames])


## WHERE THE SHIMMER IS: the last picture of the drift at a third of its brightness, with every sampled pixel that toggled
## painted red, brighter the more often, as a block of `step` pixels -- the sampling's own step, 2 on a town and 1 on the
## lights. A count says how much; this says whether it is far windows, near ones, a roof line or something that is not a
## window at all.
func _save_the_heat(picture: Image, area: Rect2i, path: String, step: int) -> void:
	var heat: Image = picture.duplicate()
	heat.adjust_bcs(0.33, 1.0, 0.5)
	var width: int = picture.get_width()
	for y in range(area.position.y, area.end.y, step):
		for x in range(area.position.x, area.end.x, step):
			var count: int = _heat[y * width + x]
			if count > 0:
				heat.fill_rect(Rect2i(x, y, step, step), Color(minf(0.35 + float(count) / 8.0, 1.0), 0.0, 0.0))
	heat.save_png(path)


## The first town's outline on the picture: the box round every building of it in front of the camera, in pixels, clipped
## to the picture. Empty when no building is in frame.
func _the_town_on_screen(picture: Image) -> Rect2i:
	var eye: Camera3D = get_viewport().get_camera_3d()
	var frame := Rect2(Vector2.ZERO, Vector2(picture.get_width(), picture.get_height()))
	if eye == null or _level.towns == null:
		return Rect2i()
	var town: Dictionary = TownCatalogue.towns()[0]
	var box := Rect2()
	var found: bool = false
	for building in _level.towns.drawn_buildings():
		var at: Vector3 = building["position"]
		if Vector2(at.x - town["centre"].x, at.z - town["centre"].z).length() > float(town["radius"]) * 1.2:
			continue
		var half: Vector3 = building["half_extents"]
		for corner in [Vector3(-1, -1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(1, -1, -1)]:
			var point: Vector3 = at + half * corner
			if eye.is_position_behind(point):
				continue
			var on_screen: Vector2 = eye.unproject_position(point)
			box = Rect2(on_screen, Vector2.ZERO) if not found else box.expand(on_screen)
			found = true
	if not found:
		return Rect2i()
	var clipped: Rect2 = box.intersection(frame)
	return Rect2i(clipped.position.floor(), clipped.size.floor())


## Over `area` of three RGB8 pictures in a row: the pixels that crossed `LIT_LUMINANCE` either way from `before` to
## `after`; the TOGGLES, which crossed from `earlier` to `before` and crossed back (none when `earlier` is null); and how
## many are over it in `after`. On every second row and column, never averaged, because an average of four blurs a
## one-pixel shimmer away.
func _crossings(earlier: Image, before: Image, after: Image, area: Rect2i) -> Vector3i:
	var e: PackedByteArray = earlier.get_data() if earlier != null else PackedByteArray()
	var a: PackedByteArray = before.get_data()
	var b: PackedByteArray = after.get_data()
	var width: int = after.get_width()
	var least: float = LIT_LUMINANCE * 255.0
	var flips: int = 0
	var toggles: int = 0
	var lit: int = 0
	for y in range(area.position.y, area.end.y, 2):
		var row: int = y * width
		for x in range(area.position.x, area.end.x, 2):
			var k: int = (row + x) * 3
			var now: bool = 0.2126 * b[k] + 0.7152 * b[k + 1] + 0.0722 * b[k + 2] >= least
			var was: bool = 0.2126 * a[k] + 0.7152 * a[k + 1] + 0.0722 * a[k + 2] >= least
			if now != was:
				flips += 1
				if not e.is_empty() and now == (0.2126 * e[k] + 0.7152 * e[k + 1] + 0.0722 * e[k + 2] >= least):
					toggles += 1
					_heat[row + x] += 1
			if now:
				lit += 1
	return Vector3i(flips, toggles, lit)


## The 9x9 box round every red aircraft light on the picture, as the red-light measure reads them, clipped to it.
func _red_lights_on_screen(eye: Camera3D, picture: Image) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if eye == null:
		return out
	var frame := Rect2i(Vector2i.ZERO, Vector2i(picture.get_width(), picture.get_height()))
	for node in _aircraft_lights():
		var lights := node as MultiMeshInstance3D
		for i in range(lights.multimesh.instance_count):
			var colour: Color = lights.multimesh.get_instance_color(i)
			if colour.r < 0.9 or colour.g > 0.3:
				continue
			var at: Vector3 = lights.global_transform * lights.multimesh.get_instance_transform(i).origin
			if eye.is_position_behind(at):
				continue
			var on_screen: Vector2 = eye.unproject_position(at)
			var box: Rect2i = Rect2i(Vector2i(int(on_screen.x) - 4, int(on_screen.y) - 4), Vector2i(9, 9)).intersection(frame)
			if box.size.x > 0 and box.size.y > 0:
				out.append(box)
	return out


## `_crossings` for the lights: over every pixel of every box, lit being RED by the red-light measure's rule (red over
## half, and more than 1.8 times the larger of green and blue). Boxes that overlap count their shared pixels twice, alike
## in every build.
func _red_crossings(earlier: Image, before: Image, after: Image, boxes: Array[Rect2i]) -> Vector3i:
	var e: PackedByteArray = earlier.get_data() if earlier != null else PackedByteArray()
	var a: PackedByteArray = before.get_data()
	var b: PackedByteArray = after.get_data()
	var width: int = after.get_width()
	var flips: int = 0
	var toggles: int = 0
	var lit: int = 0
	for box in boxes:
		for y in range(box.position.y, box.end.y):
			var row: int = y * width
			for x in range(box.position.x, box.end.x):
				var k: int = (row + x) * 3
				var now: bool = b[k] > 127 and float(b[k]) > 1.8 * float(maxi(b[k + 1], b[k + 2]))
				var was: bool = a[k] > 127 and float(a[k]) > 1.8 * float(maxi(a[k + 1], a[k + 2]))
				if now != was:
					flips += 1
					if not e.is_empty() and now == (e[k] > 127 and float(e[k]) > 1.8 * float(maxi(e[k + 1], e[k + 2]))):
						toggles += 1
						_heat[row + x] += 1
				if now:
					lit += 1
	return Vector3i(flips, toggles, lit)


## The airliner with the lowest entity id, so two runs follow the same one.
func _first_of(kind: int) -> VehicleView:
	var best: int = 0
	for entity in Sim.current:
		if int((Sim.current[entity] as Dictionary).get("kind", -1)) != kind:
			continue
		if best == 0 or int(entity) < best:
			best = int(entity)
	return _level.view_of(best) if best != 0 else null


## THE WIDEST THERMAL OF THE USUAL HEIGHT: its COLUMN, top less base, is THERMAL_TOP. On the island every zone is based at 0
## so that is its top; on the generated ground every zone stands on its own ground (increment B3), and a top compared with
## THERMAL_TOP there matched none and left the `clouds` view with nothing to look at.
func _widest_thermal() -> Dictionary:
	var best: Dictionary = {}
	for zone in Terrain.lift_zones():
		if is_equal_approx(float(zone["top"]) - (zone["position"] as Vector3).y, Terrain.THERMAL_TOP) and (best.is_empty()
				or float(zone["radius"]) > float(best["radius"])):
			best = zone
	return best


## THE HIGHEST POINT OF THE ISLAND'S MOUNTAINS, as `{position}`: the tallest vertex of any tile, which is where the rock
## is highest (the triangles are the rock). {} with none.
func _tallest_rock() -> Dictionary:
	var rock: Object = Terrain.mountains()
	if rock == null:
		return {}
	var best := Vector3(0.0, -INF, 0.0)
	for t in range(int(rock.call("tile_count"))):
		var tile: Dictionary = rock.call("tile", t)
		var origin: Vector2i = tile["origin"]
		for v in (tile["vertices"] as PackedVector3Array):
			if v.y > best.y:
				best = Vector3(float(origin.x) + v.x, v.y, float(origin.y) + v.z)
	return {"position": best, "half_extents": Vector3.ZERO} if best.y > 0.0 else {}


## THE FIRST POINT WHERE A WOOD'S LONG SIDE CROSSES A GROUNDVIEW CELL'S SEAM, as [outward across, point]; [] with none.
func _wood_edge_on_a_seam() -> Array:
	if not ResourceLoader.exists(FORESTS_PATH):
		return []
	for stand in (load(FORESTS_PATH) as Script).call("stands"):
		var half: Vector2 = stand["half"]
		for side in [1.0, -1.0]:
			var y: float = -half.y
			var last: Vector3 = Vector3.INF
			while y <= half.y:
				var point: Vector3 = (stand["centre"] as Vector3) + (stand["across"] as Vector3) * half.x * side + (stand["along"] as Vector3) * y
				if last != Vector3.INF and (floori(last.x / float(GroundView.CELL)) != floori(point.x / float(GroundView.CELL))
						or floori(last.z / float(GroundView.CELL)) != floori(point.z / float(GroundView.CELL))):
					return [(stand["across"] as Vector3) * side, (last + point) * 0.5]
				last = point
				y += 8.0
	return []


## THE STEEPEST POINT ON ANY WOOD'S LONG SIDES, every 32 m along them, as [stand, point on the ground]; [] with no woods. The
## `across` of the returned stand points out of the wood at that side.
## THE STEEPEST PIECE OF ROAD on the level's world, by its own ends' heights; empty with no roads.
func _steepest_road_piece() -> Dictionary:
	var best: Dictionary = {}
	var steepest: float = -1.0
	for road in Terrain.roads(_level._solid):
		var a: Vector3 = road["from"]
		var b: Vector3 = road["to"]
		var grade: float = absf(b.y - a.y) / maxf(Vector2(b.x - a.x, b.z - a.z).length(), 0.001)
		if grade > steepest:
			steepest = grade
			best = road
	return best


## THE LONGEST STRAIGHT RUN OF ROAD, `[from, to]`: pieces laid end to end on one link at one heading; empty with no roads.
func _longest_road_run() -> Array:
	var best: Array = []
	var longest: float = -1.0
	var run_from := Vector3.ZERO
	var last: Dictionary = {}
	for road in Terrain.roads(_level._solid):
		var joins: bool = not last.is_empty() and road["link"] == last["link"] \
				and (road["from"] as Vector3).is_equal_approx(last["to"]) \
				and _road_along(road["from"], road["to"]).dot(_road_along(last["from"], last["to"])) > 0.9999
		if not joins:
			run_from = road["from"]
		var length: float = Vector2(run_from.x - (road["to"] as Vector3).x, run_from.z - (road["to"] as Vector3).z).length()
		if length > longest:
			longest = length
			best = [run_from, road["to"]]
		last = road
	return best


static func _road_along(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()


## A point `away` metres to the side of the road from `a` to `b`, level with its middle, on whichever side the ground is lower.
static func _beside_a_road(a: Vector3, b: Vector3, away: float) -> Vector3:
	var middle: Vector3 = (a + b) * 0.5
	var along: Vector3 = _road_along(a, b)
	var aside := Vector3(-along.z, 0.0, along.x) * away
	return middle + aside if Terrain.surface_height(middle + aside) <= Terrain.surface_height(middle - aside) else middle - aside


func _steepest_wood_edge() -> Array:
	if not ResourceLoader.exists(FORESTS_PATH):
		return []
	var best: Array = []
	var steepest: float = -1.0
	for stand in (load(FORESTS_PATH) as Script).call("stands"):
		var half: Vector2 = stand["half"]
		for side in [1.0, -1.0]:
			var y: float = -half.y
			while y <= half.y:
				var point: Vector3 = (stand["centre"] as Vector3) + (stand["across"] as Vector3) * half.x * side + (stand["along"] as Vector3) * y
				var slope: float = Terrain.slope_at(point)
				if slope > steepest:
					steepest = slope
					var facing: Dictionary = (stand as Dictionary).duplicate()
					facing["across"] = (stand["across"] as Vector3) * side
					best = [facing, point]
				y += 32.0
	return best


## The first wood in the catalogue, read, or {} on a copy of the game that has no forests. ON THE GENERATED GROUND the
## BUSIEST wood instead (increment B4): the one with the most woods' area whose middles lie within FINE's far fade of its
## own, so `forest_high` there times the most trees a view of the alpine woods can have in range.
func _first_stand() -> Dictionary:
	if not ResourceLoader.exists(FORESTS_PATH):
		return {}
	var stands: Array = (load(FORESTS_PATH) as Script).call("stands")
	if stands.is_empty():
		return {}
	if Terrain.standing_on() == null:
		return stands[0]
	var reach: float = float((load("res://world/forest_tuning.gd") as Script).call("for_tier", true, {})["fade_to"])
	var best: Dictionary = stands[0]
	var most: float = -1.0
	for stand in stands:
		var area: float = 0.0
		for other in stands:
			if (other["centre"] as Vector3).distance_to(stand["centre"]) <= reach:
				area += (other["half"] as Vector2).x * (other["half"] as Vector2).y * 4.0
		if area > most:
			most = area
			best = stand
	return best


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
