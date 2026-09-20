extends Node
## A BIG EXPLOSION PHOTOGRAPHED, AND WHAT IT COSTS THE WORST FRAME -- a heavy shell's, a barrage of them, a missile
## volley, and the very first one after the level loads.
##
##   Godot --path cockpit res://tests/fx_shot.tscn -- --level=watch --views=impact,missile --finishes=plain,fine \
##       --times=day,night --at=0.35,4.0 --out=C:/somewhere
##   Godot --path cockpit res://tests/fx_shot.tscn -- --level=watch --views=first --finishes=fine --times=night
##
## `--times`, NOT `--time`: the level reads `--time=` for itself at start, and a list there is "not a time of day" --
## the first picture run warned on every launch (2026-09-14). This picks the times it walks; the level starts on day.
##   Godot --path cockpit res://tests/fx_shot.tscn -- --level=watch --views=single,barrage,volley --finishes=plain
##
## NOT HEADLESS -- it renders, and headless pictures are black rectangles. Either editor on the Windows workstation: the
## double build draws on Forward+ since 2026-09-14 (agents.md, "And one thing about looking at it on this machine"). No
## `--fixed-fps` for the timing views: they time real frames, vsync off.
##
## WHY IT EXISTS. "As long as they are not a weird perf hit when created" (2026-09-13) is a question about the WORST
## frame, not the average: a pool grown on the first hit, a material made in the frame, or a pipeline compiled the first
## time a burst is drawn are each one long frame in a thousand, and a median never sees them. So every timing view
## reports the median, the 99th percentile and the single worst frame, beside the same count of frames with no
## explosion in them just before.
##
## EVERYTHING GOES OFF THROUGH THE LEVEL'S OWN DOORS, called by name so this same script photographs and times the
## explosions from before they were rebuilt: a heavy shell is a landed row handed to `ShotYard._land`, a missile is
## `MissileYard._end`. A picture tool asks the drawing to draw; `tests/bursts` is where the rules are checked.
##
##   impact    a 105 mm round landing on the ground by the runway, photographed at each `--at` second of its life.
##   missile   an air burst 900 m over the threshold, at each `--at`.
##   first     THE FIRST EXPLOSION AFTER LOAD: run it as the only view of its launch. The frames around it, against as
##             many before it.
##   single    one 105 after the first has come and gone.
##   barrage   `BARRAGE` 105s, one every `BARRAGE_EVERY` seconds, around the threshold.
##   volley    `VOLLEY` missiles at once in a ring.
##
## Pictures and a log line per shot go to `--out` (default `user://fx_shots`), named `<view>-<finish>[-<time>][-<at>].png`.

const OUT := "user://fx_shots"
const WARM: int = 240
const SETTLE: int = 30
const BURST_UP: float = 900.0
const BURST_OFF: float = 180.0
const IMPACT_OFF: float = 260.0
const VOLLEY: int = 8
const VOLLEY_RING: float = 120.0
const BARRAGE: int = 10
const BARRAGE_EVERY: float = 0.5
const HOWITZER: int = 6
## An entity number far above any the simulation hands out, for the explosions this sets off.
const FAKE_ENTITY: int = 900000
## `MissileYard.FUSED`: an air burst.
const AIR_BURST: int = 5

var _level: FlightLevel = null
var _views: Array[String] = ["impact", "missile"]
var _finishes: Array[String] = ["plain", "fine"]
var _times: Array[int] = []
var _ats: Array[float] = [0.35, 4.0]
var _frames: int = 240
var _out: String = OUT
var _failures: PackedStringArray = []
var _pose: Array = []
var _next_fake: int = FAKE_ENTITY


func _check(label: String, ok: bool, detail: String) -> void:
	print("[fx_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"views":
				_views.assign(Array(parts[1].split(",", false)))
			"finishes":
				_finishes.assign(Array(parts[1].split(",", false)))
			"frames":
				_frames = maxi(int(parts[1]), 1)
			"out":
				_out = parts[1]
			"at":
				_ats.assign(Array(parts[1].split(",", false)).map(func(s): return float(s)))
			"times":
				for asked in parts[1].split(",", false):
					var which: int = DaylightTuning.When.keys().find(asked.to_upper())
					if which >= 0:
						_times.append(which)
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed on the stock editor")
		_finish()
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("[fx_shot] %s, %s precision, %s on %s, window %s, heavy bursts %s" % [
		Engine.get_version_info()["string"], "double" if OS.has_feature("double") else "single",
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(),
		DisplayServer.window_get_size(), "yes" if ClassDB.class_exists("BurstYard") or _has_burst_yard_script() else "no"])
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	# THE FINISH AND THE TIME FIRST, and then the warm frames: the first explosion is timed against a level that has
	# already drawn itself in the look it is judged in.
	await _wear(_finishes[0])
	if not _times.is_empty():
		_level.choose_time(_times[0])
	for i in range(WARM):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	for view in _views:
		match view:
			"impact":
				await _pictures(view)
			"missile":
				await _pictures(view)
			"first", "single":
				await _time_one(view)
			"barrage":
				await _time_barrage()
			"volley":
				await _time_volley()
			_:
				_check("the_view_%s_exists" % view, false, "no such view")
	_finish()


func _process(_delta: float) -> void:
	if not _pose.is_empty() and _level != null and _level.observer != null:
		_level.observer.look_from(_pose[0], _pose[1])


## ---- pictures --------------------------------------------------------------------------

func _pictures(view: String) -> void:
	var line: Dictionary = Terrain.runway_axis()
	var along: Vector3 = line["along"]
	var across: Vector3 = line["across"]
	var threshold: Vector3 = line["threshold"]
	var at: Vector3 = threshold + Vector3.UP * BURST_UP if view == "missile" else threshold + along * 120.0
	if view == "missile":
		_pose = [at - across * BURST_OFF - along * BURST_OFF * 0.3 - Vector3.UP * 30.0, at + Vector3.UP * 10.0]
	else:
		_pose = [at - across * IMPACT_OFF + Vector3.UP * 45.0, at + Vector3.UP * 12.0]
	for finish_name in _finishes:
		await _wear(finish_name)
		for time in (_times if not _times.is_empty() else [-1]):
			if time >= 0:
				_level.choose_time(time)
			for second in _ats:
				_run()
				for i in range(SETTLE):
					await get_tree().process_frame
				if view == "missile":
					_missile_at(at)
				else:
					_shell_at(at)
				var waited: float = 0.0
				while waited < second:
					await get_tree().process_frame
					waited += get_process_delta_time()
				_freeze()
				await _save(view, finish_name, time, "%.2fs" % second)
				_run()
				# EVERY EXPLOSION GONE before the next picture, so each is the only one in its frame.
				for i in range(int(15.0 / maxf(get_process_delta_time(), 1.0 / 240.0))):
					await get_tree().process_frame
					if i > 60 and _nothing_going():
						break
	_pose = []


## ---- timing -----------------------------------------------------------------------------

## ONE 105, timed: the frames from the moment it lands to when its fireball has cooled, against as many before it. As
## `first`, the explosion is the first of the launch.
func _time_one(view: String) -> void:
	await _stand_by_the_threshold()
	for finish_name in _finishes:
		await _wear(finish_name)
		for time in (_times if not _times.is_empty() else [-1]):
			if time >= 0:
				_level.choose_time(time)
			if view == "single":
				_shell_at(_by_the_threshold(0))
				await _until_nothing_is_going()
			var none: Dictionary = await _time_frames(_frames)
			_shell_at(_by_the_threshold(1))
			var one: Dictionary = await _time_frames(_frames)
			_report(view, finish_name, time, none, one)
			await _until_nothing_is_going()


func _time_barrage() -> void:
	await _stand_by_the_threshold()
	for finish_name in _finishes:
		await _wear(finish_name)
		for time in (_times if not _times.is_empty() else [-1]):
			if time >= 0:
				_level.choose_time(time)
			var none: Dictionary = await _time_frames(_frames)
			var fired: Array = [0]
			var clock: Array = [0.0]
			var shells := func(delta: float) -> void:
				clock[0] += delta
				while fired[0] < BARRAGE and clock[0] >= float(fired[0]) * BARRAGE_EVERY:
					_shell_at(_by_the_threshold(fired[0]))
					fired[0] += 1
			var barrage: Dictionary = await _time_frames(maxi(_frames, int(BARRAGE * BARRAGE_EVERY * 120.0)), shells)
			_report("barrage", finish_name, time, none, barrage)
			_say_what_the_pool_gave_up("barrage")
			await _until_nothing_is_going()


func _time_volley() -> void:
	var line: Dictionary = Terrain.runway_axis()
	var across: Vector3 = line["across"]
	var along: Vector3 = line["along"]
	var middle: Vector3 = (line["threshold"] as Vector3) + Vector3.UP * BURST_UP
	_pose = [middle - across * 520.0 - Vector3.UP * 60.0, middle]
	for finish_name in _finishes:
		await _wear(finish_name)
		for time in (_times if not _times.is_empty() else [-1]):
			if time >= 0:
				_level.choose_time(time)
			_run()
			var none: Dictionary = await _time_frames(_frames)
			for i in range(VOLLEY):
				var round_to: float = TAU * float(i) / float(VOLLEY)
				_missile_at(middle + (across * cos(round_to) + along * sin(round_to)) * VOLLEY_RING)
			var volley: Dictionary = await _time_frames(_frames)
			_report("volley", finish_name, time, none, volley)
			_say_what_the_pool_gave_up("volley")
			await _until_nothing_is_going()


func _report(view: String, finish_name: String, time: int, none: Dictionary, with: Dictionary) -> void:
	print("[fx_shot] %s finish=%s time=%s frames=%d | none: frame med %.2f p99 %.2f worst %.2f ms, cpu %.2f gpu %.2f | with: frame med %.2f p99 %.2f worst %.2f ms, cpu %.2f gpu %.2f | worst %+.2f ms"
		% [view, finish_name, DaylightTuning.name_of(time).to_lower() if time >= 0 else "-", int(with["frames"]),
			none["median"], none["p99"], none["worst"], none["cpu"], none["gpu"],
			with["median"], with["p99"], with["worst"], with["cpu"], with["gpu"],
			float(with["worst"]) - float(none["worst"])])


## HOW MANY EXPLOSIONS TOOK BACK A BURST STILL GOING, on a level with a burst yard; "-" on one from before it.
func _say_what_the_pool_gave_up(view: String) -> void:
	var yard: Object = _level.get("bursts")
	print("[fx_shot] pool after %s: %s taken back while still going, %s going" % [view,
		yard.call("stolen") if yard != null else "-", yard.call("going") if yard != null else "-"])


## ---- the machinery -------------------------------------------------------------------------

func _stand_by_the_threshold() -> void:
	var line: Dictionary = Terrain.runway_axis()
	var at: Vector3 = (line["threshold"] as Vector3) + (line["along"] as Vector3) * 120.0
	_pose = [at - (line["across"] as Vector3) * 700.0 + Vector3.UP * 150.0, at]
	_run()
	for i in range(SETTLE):
		await get_tree().process_frame


## The `n`th of a row of impacts along the runway, forty metres apart.
func _by_the_threshold(n: int) -> Vector3:
	var line: Dictionary = Terrain.runway_axis()
	return (line["threshold"] as Vector3) + (line["along"] as Vector3) * (60.0 + 40.0 * float(n % 10)) \
		+ (line["across"] as Vector3) * (20.0 * float((n * 7) % 5) - 40.0)


## A 105 LANDING at `at`, as the level's shot yard is handed one.
func _shell_at(at: Vector3) -> void:
	_next_fake += 1
	var row: Dictionary = {"entity": _next_fake, "from": at + Vector3(0.0, 400.0, -300.0),
		"velocity": Vector3(0.0, -300.0, 200.0), "ammo": HOWITZER, "ammo_name": "105mm", "drag": 0.0,
		"surface": Ammunition.GROUND, "flying": false, "impact": at, "shooter": -1}
	_level.shots.call("_land", _next_fake, row)


## A MISSILE GOING OFF in the air at `at`, through the yard's own end.
func _missile_at(at: Vector3) -> void:
	_next_fake += 1
	_level.missiles.call("_end", _next_fake, AIR_BURST, at)


func _nothing_going() -> bool:
	var yard: Object = _level.get("bursts")
	if yard != null and int(yard.call("going")) > 0:
		return false
	for owner in [_level.shots, _level.missiles]:
		for child in (owner as Node).get_children():
			if child.has_method("wind_on") and (child as Node3D).visible:
				return false
	return true


func _until_nothing_is_going() -> void:
	for i in range(6000):
		await get_tree().process_frame
		if _nothing_going():
			return


## STOP EVERYTHING THAT MOVES: the simulation, the level's drawing, the burst yard's clock, and any burst from before
## with a clock of its own.
func _freeze() -> void:
	Sim.set_physics_process(false)
	Sim.previous = Sim.current
	_level.set_physics_process(false)
	_level.set_process(false)
	var yard: Object = _level.get("bursts")
	if yard != null:
		(yard as Node).set_process(false)
	for owner in [_level.shots, _level.missiles]:
		for child in (owner as Node).get_children():
			if child.has_method("wind_on"):
				child.set_process(false)


func _run() -> void:
	Sim.set_physics_process(true)
	_level.set_physics_process(true)
	_level.set_process(true)
	var yard: Object = _level.get("bursts")
	if yard != null:
		(yard as Node).set_process(true)
	for owner in [_level.shots, _level.missiles]:
		for child in (owner as Node).get_children():
			if child.has_method("wind_on"):
				child.set_process((child as Node3D).visible)


func _save(view: String, finish_name: String, time: int, at: String) -> void:
	for i in range(6):
		await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	var called: String = view + "-" + finish_name
	if time >= 0:
		called += "-" + DaylightTuning.name_of(time).to_lower()
	if at != "":
		called += "-" + at
	var file: String = "%s/%s.png" % [_out, called]
	shot.save_png(file)
	print("[fx_shot] saved %s" % ProjectSettings.globalize_path(file))


## `frames` DRAWN FRAMES, TIMED: the wall time between one frame's draw and the next (what a player waits), and the
## viewport's CPU and GPU render time. `each` is called with the frame's delta before it is drawn. Median, 99th
## percentile and worst, in ms.
func _time_frames(frames: int, each: Callable = Callable()) -> Dictionary:
	var viewport: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var wall: PackedFloat64Array = []
	var cpu: PackedFloat64Array = []
	var gpu: PackedFloat64Array = []
	await RenderingServer.frame_post_draw
	var last: int = Time.get_ticks_usec()
	for i in range(frames):
		if each.is_valid():
			each.call(get_process_delta_time())
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		wall.append(float(now - last) / 1000.0)
		last = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	var sorted: PackedFloat64Array = wall.duplicate()
	sorted.sort()
	return {"frames": frames, "median": sorted[sorted.size() / 2],
		"p99": sorted[mini(sorted.size() - 1, int(float(sorted.size()) * 0.99))], "worst": sorted[sorted.size() - 1],
		"cpu": _median(cpu), "gpu": _median(gpu)}


static func _median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


static func _has_burst_yard_script() -> bool:
	return ResourceLoader.exists("res://objects/weapons/burst_yard.gd")


func _wear(finish_name: String) -> void:
	var fine: bool = finish_name == "fine"
	get_viewport().msaa_3d = Finish.multisampling()
	if Finish.is_fine() != fine:
		var code: Key = KEY_NONE
		for event in InputMap.action_get_events(SceneryFinish.ACTION):
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
	get_viewport().msaa_3d = Finish.multisampling()
	_check("the_key_put_on_%s" % finish_name, Finish.is_fine() == fine, "fine is %s" % Finish.is_fine())


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
