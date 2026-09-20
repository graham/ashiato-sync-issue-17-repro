extends Node
## CONTRAILS, PHOTOGRAPHED FROM PLACES WORKED OUT HERE, HOW LONG THEY ARE AGAINST A MISSILE'S, AND WHAT THEY COST.
##
##   Godot --path cockpit --fixed-fps 60 res://tests/contrail_shot.tscn -- --level=watch
##   Godot --path cockpit --fixed-fps 60 res://tests/contrail_shot.tscn -- --level=watch \
##       --views=contrail_behind,contrail_side,lengths,contrail_cost --finishes=plain,fine --time=day \
##       --traffic=20 --frames=240 --out=C:/somewhere
##
## NOT HEADLESS -- it renders, and headless pictures are black rectangles. The STOCK editor: the double build cannot
## draw a window on this machine.
##
## WHY IT IS NOT A `scenery_shot` VIEW. Those are places that stand still; a contrail is behind an aeroplane that flies
## away, and the trap is photographing a craft that has left the frame. So a contrail is posed and FROZEN: the
## simulation stops ticking and the level stops drawing, which stops the missile yard's clock -- the clock every trail
## segment is aged on -- and the camera is put on the aeroplane where it got to, not where it was meant to be.
##
##   contrail_behind / contrail_side   an unpiloted aeroplane put `UP` metres over the threshold at its cruise, flown
##                                      `FLY` seconds, frozen, and photographed from astern and abeam.
##   contrail_climb / contrail_ageing  A STRIP, because a contrail is transient and one frame cannot show how it comes
##                                      and goes: an aeroplane climbing through the band, or flying above it and then
##                                      taken away, photographed from one place that holds still at `STRIP_AT` seconds,
##                                      `<view>-<finish>-<time>-<n>.png`, each with a `.json` of where on the screen the
##                                      aeroplane's path runs, so the trail's brightness along it can be read off.
##   lengths                           every winged kind's cruise times a contrail's life, and a radar and a heat
##                                      missile's trail measured from launch to burnout, in metres.
##   contrail_cost                     the island's own traffic and `--traffic` more winged aircraft, flying: the
##                                      `contrails` lap and the frame with the contrails and without, alternating three
##                                      times on each finish.
##
## Pictures go to `--out` (default `user://contrail_shots`), `<view>-<finish>[-<time>].png`.

const OUT := "user://contrail_shots"
const WARM: int = 240
const FLY: float = 7.0
const UP: float = 700.0
## The winged kinds `--traffic` adds, in turn, and the ones `lengths` reads a cruise for.
const WINGED: Array[int] = [Sim.Kind.PLANE, Sim.Kind.AIRLINER, Sim.Kind.CESSNA, Sim.Kind.OSPREY, Sim.Kind.TANKER]
const STOPWATCH_PATH: String = "res://world/stopwatch.gd"

var _level: FlightLevel = null
var _views: Array[String] = ["contrail_behind", "contrail_side"]
var _finishes: Array[String] = ["plain", "fine"]
var _times: Array[int] = []
var _frames: int = 240
var _traffic: int = 0
var _out: String = OUT
## `--old_shaders=<folder>`: `contrail_cost` alternates the trail shaders in that folder against the project's, both arms
## drawing contrails, instead of contrails against none. A change to a shader is timed against what it replaced, in one
## process on one sky.
var _old_shaders: String = ""
var _failures: PackedStringArray = []
var _pose: Array = []
var _watch: Script = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[contrail_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
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
			"traffic":
				_traffic = maxi(int(parts[1]), 0)
			"out":
				_out = parts[1]
			"old_shaders":
				_old_shaders = parts[1]
			"time":
				for asked in parts[1].split(",", false):
					var which: int = DaylightTuning.When.keys().find(asked.to_upper())
					if which >= 0:
						_times.append(which)
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed on the stock editor")
		_finish()
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("[contrail_shot] %s, %s precision, %s on %s, window %s" % [Engine.get_version_info()["string"],
		"double" if OS.has_feature("double") else "single", RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size()])
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
	if ResourceLoader.exists(STOPWATCH_PATH):
		_watch = load(STOPWATCH_PATH) as Script
		_watch.call("run", true)
	DirAccess.make_dir_recursive_absolute(_out)
	for view in _views:
		match view:
			"contrail_behind", "contrail_side":
				await _a_contrail(view)
			"contrail_band", "contrail_ageing":
				await _a_strip(view)
			"lengths":
				await _lengths()
			"contrail_cost":
				await _what_contrails_cost()
			_:
				_check("the_view_%s_exists" % view, false, "no such view")
	_finish()


func _process(_delta: float) -> void:
	if not _pose.is_empty() and _level != null and _level.observer != null:
		_level.observer.look_from(_pose[0], _pose[1])


## ---- a contrail -----------------------------------------------------------------------

func _a_contrail(view: String) -> void:
	for finish_name in _finishes:
		await _wear(finish_name)
		for time in (_times if not _times.is_empty() else [-1]):
			if time >= 0:
				_level.choose_time(time)
			_run()
			var line: Dictionary = Terrain.runway_axis()
			var along: Vector3 = line["along"]
			var across: Vector3 = line["across"]
			var speed: float = Terrain.cruise_for(Sim.Kind.PLANE)
			var start: Vector3 = (line["threshold"] as Vector3) - along * 600.0 + Vector3.UP * UP
			var craft: int = Sim.spawn_vehicle(Sim.Kind.PLANE, start, atan2(-along.x, -along.z), along * speed)
			# FOLLOWED WHILE IT FLIES, so the frozen picture is taken from where it got to.
			var seconds: float = 0.0
			var at: Vector3 = start
			while seconds < FLY:
				at = _drawn_nearest(start + along * speed * seconds, at)
				_pose = [at - along * 120.0 + Vector3.UP * 20.0 + across * 25.0, at]
				await get_tree().process_frame
				seconds += get_process_delta_time()
			_freeze()
			var trail: float = speed * _level.contrails.lasts()
			# ASTERN, ABOVE AND TO ONE SIDE, LOOKING AT THE AEROPLANE, so its two trails run from under the eye to the wings.
			# Looking back down the trail instead put the ribbon a few metres under the eye as a white smear, with no
			# aeroplane in the picture (first look, 2026-09-14). ABEAM at 250 m and 120 m BELOW, which at this field of view
			# is about 380 m of sky across with the trail against blue: from 430 m the trail was a hairline, and from level
			# with it the trail lay along the band of clouds at the horizon and could not be told from them.
			if view == "contrail_behind":
				_pose = [at - along * 160.0 + Vector3.UP * 40.0 + across * 60.0, at]
			else:
				_pose = [at + across * 250.0 - Vector3.UP * 120.0 - along * trail * 0.35, at - along * trail * 0.35]
			print("[contrail_shot] %s finish=%s at %v, %.0f m up, %.0f m/s, contrail %.1f s = %.0f m, %d segments laid"
				% [view, finish_name, at, at.y, speed, _level.contrails.lasts(), trail,
					_level.contrails.contrail_segments()])
			await _save(view, finish_name, time)
			Sim.server.despawn_vehicle(craft)
			_pose = []
	_run()


## ---- a strip of a contrail coming and going -----------------------------------------------

## WHEN EACH PICTURE OF A STRIP IS TAKEN. The band strip is taken by HEIGHT, on the way down: an unpiloted aeroplane
## cannot be made to climb through the band -- put up at 240 m climbing at 12 m/s it had shed the climb by 2 s and was
## sinking by 5 (258, 260, 251, 242 m at 4, 5.5, 8.5 and 10 s, 2026-09-14) -- but one put `BAND_FROM` above the
## band sinking at `BAND_SINK` goes down through it, which is the same band and the same fade the other way round. The
## ageing strip is by time: the aeroplane is taken away at `AGEING_GONE` and the trail left to fade.
const STRIP_AT: Dictionary = {
	"contrail_band": [325.0, 310.0, 300.0, 290.0, 270.0],
	"contrail_ageing": [5.0, 6.0, 7.0, 8.5, 10.0],
}
const BAND_FROM: float = 30.0
const BAND_SINK: float = 10.0
const AGEING_GONE: float = 5.0


func _a_strip(view: String) -> void:
	var by_height: bool = view == "contrail_band"
	for finish_name in _finishes:
		await _wear(finish_name)
		for time in (_times if not _times.is_empty() else [-1]):
			if time >= 0:
				_level.choose_time(time)
			_run()
			var line: Dictionary = Terrain.runway_axis()
			var along: Vector3 = line["along"]
			var across: Vector3 = line["across"]
			var speed: float = Terrain.cruise_for(Sim.Kind.PLANE)
			var height: float = TrailTuning.CONTRAIL_ALTITUDE + BAND_FROM if by_height else UP
			var start: Vector3 = (line["threshold"] as Vector3) - along * 600.0 + Vector3.UP * height
			var sink: Vector3 = Vector3.DOWN * (BAND_SINK if by_height else 0.0)
			Sim.spawn_vehicle(Sim.Kind.PLANE, start, atan2(-along.x, -along.z), along * speed + sink)
			var path: Array = []
			var seconds: float = 0.0
			var at: Vector3 = start
			var craft: int = 0
			var gone: bool = false
			# ONE PLACE FOR THE WHOLE STRIP, abeam of what it shows, so picture to picture only the trail changes: where the
			# band is crossed (310 m at 8.7 s and 290 m at 11.1 s after the aeroplane is put up, 2026-09-14), or the middle
			# of an ageing trail. The trail stays where it was laid, so the aeroplane is let fly out of the picture.
			# A band strip holds still from where the aeroplane really is as it drops through 315 m: worked out from the spawn
			# and the cruise, the first try looked at empty sky with the aeroplane at the picture's edge.
			var middle: Vector3 = start + along * speed * AGEING_GONE * 0.6
			var eye: Vector3 = middle + across * 260.0 - Vector3.UP * 45.0
			var placed: bool = not by_height
			var shots: Array = STRIP_AT[view]
			for n in range(shots.size()):
				while (at.y > float(shots[n]) if by_height else seconds < float(shots[n])) and seconds < 40.0:
					at = _drawn_nearest(at + (along * speed + sink) * get_process_delta_time(), at)
					craft = _drawn_entity_nearest(at)
					if not gone:
						path.append(at)
					if not placed:
						middle = at + along * speed * 1.0
						eye = middle + across * 230.0 - Vector3.UP * 40.0
						placed = at.y < TrailTuning.CONTRAIL_ALTITUDE + 15.0
					_pose = [eye, middle]
					await get_tree().process_frame
					seconds += get_process_delta_time()
					if not by_height and not gone and seconds >= AGEING_GONE:
						Sim.server.despawn_vehicle(craft)
						gone = true
				_freeze()
				print("[contrail_shot] %s finish=%s shot=%d at %.1f s: aeroplane %.0f m up, strength %.2f, %d segments laid"
					% [view, finish_name, n, seconds, at.y, _level.contrails.strength_of(craft),
						_level.contrails.contrail_segments()])
				var called: String = await _save("%s-%d" % [view, n], finish_name, time)
				_save_the_path(called, path)
				_run()
			if not gone:
				Sim.server.despawn_vehicle(craft)
			_pose = []
	_run()


## WHERE THE AEROPLANE'S PATH IS ON THE SCREEN, every twentieth point, for reading the trail's brightness along it.
func _save_the_path(picture: String, path: Array) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var points: Array = []
	for i in range(0, path.size(), 2):
		var p: Vector3 = path[i]
		if camera.is_position_behind(p):
			continue
		var s: Vector2 = camera.unproject_position(p)
		points.append([snappedf(s.x, 0.1), snappedf(s.y, 0.1)])
	var file := FileAccess.open(picture.get_basename() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"screen": points, "size": [get_viewport().get_visible_rect().size.x,
		get_viewport().get_visible_rect().size.y]}))


## ---- how long ---------------------------------------------------------------------------

## A CONTRAIL'S LENGTH at each winged kind's cruise, and a missile trail's, measured: an aeroplane `UP` metres up
## launches one missile off each of its first two rails, and each missile's place is read at its first motor tick and
## its last. The trail is laid only while the motor burns, so that is its length.
func _lengths() -> void:
	_run()
	for kind in WINGED:
		print("[contrail_shot] lengths kind=%s cruise=%.1f m/s contrail plain=%.0f m fine=%.0f m" % [Sim.kind_name(kind),
			Terrain.cruise_for(kind), Terrain.cruise_for(kind) * TrailTuning.missile_life(false) * TrailTuning.CONTRAIL_SHARE,
			Terrain.cruise_for(kind) * TrailTuning.missile_life(true) * TrailTuning.CONTRAIL_SHARE])
	var line: Dictionary = Terrain.runway_axis()
	var along: Vector3 = line["along"]
	var across: Vector3 = line["across"]
	var from: Vector3 = (line["threshold"] as Vector3) + Vector3.UP * UP
	# ONE AEROPLANE A STATION, as `scenery_shot`'s salvo launches them: a second launch from the same aeroplane, on the
	# same tick or a second later, was refused both times (2026-09-14), and the salvo's eight from eight aeroplanes never is.
	var crafts: Array[int] = []
	for station in range(2):
		var craft: int = Sim.spawn_vehicle(Sim.Kind.PLANE, from + across * 60.0 * float(station),
			atan2(-along.x, -along.z), along * Terrain.cruise_for(Sim.Kind.PLANE))
		crafts.append(craft)
		Sim.server.launch_missile(craft, station, 0)
	var lit: Dictionary = {}
	var out: Dictionary = {}
	for i in range(60 * 10):
		await get_tree().physics_frame
		for row in Sim.missiles:
			var entity: int = int(row.get("entity", 0))
			var at: Vector3 = row.get("position", Vector3.ZERO) as Vector3
			if bool(row.get("motor", false)):
				if not lit.has(entity):
					lit[entity] = {"type": int(row.get("type", -1)), "from": at}
				(lit[entity] as Dictionary)["to"] = at
			elif lit.has(entity) and not out.has(entity):
				out[entity] = true
	for entity in lit:
		var one: Dictionary = lit[entity]
		print("[contrail_shot] lengths missile=%d type=%d trail=%.0f m (launch to burnout)" % [entity, one["type"],
			(one["from"] as Vector3).distance_to(one.get("to", one["from"]) as Vector3)])
	_check("two_missiles_burned_out", out.size() == 2, "%d of %d" % [out.size(), lit.size()])
	for craft in crafts:
		Sim.server.despawn_vehicle(craft)


## ---- what contrails cost ------------------------------------------------------------------

## THE ISLAND'S OWN TRAFFIC AND `--traffic` MORE, alternating the level with its contrail yard and without it. The
## camera stands high over the middle of the island so the trails are drawn in frame as well as laid.
func _what_contrails_cost() -> void:
	_run()
	for i in range(_traffic):
		_level.add_traffic(WINGED[i % WINGED.size()])
	_pose = [Vector3(0.0, 1400.0, 3000.0), Vector3(0.0, 500.0, 0.0)]
	var yard: ContrailYard = _level.contrails
	for finish_name in _finishes:
		await _wear(finish_name)
		for i in range(600):
			await get_tree().process_frame
		if not _old_shaders.is_empty():
			await _old_against_new(finish_name, yard)
			continue
		for launch in range(3):
			_level.contrails = yard
			yard.visible = true
			var drawn: Dictionary = await _time_frames(_frames)
			# COUNTED NOW, at the end of the arm that lays them: after the arm with no contrails four seconds of them have
			# faded, and the first count read 624 of an expected 1,716 (2026-09-14).
			var in_use: int = yard.segments_in_use()
			var trailing: int = 0
			var above: int = 0
			for entity in Sim.current:
				if yard.strength_of(int(entity)) > 0.0:
					trailing += 1
				if ((Sim.current[entity] as Dictionary).get("position", Vector3.ZERO) as Vector3).y > TrailTuning.CONTRAIL_ALTITUDE:
					above += 1
			_level.contrails = null
			yard.visible = false
			var bare: Dictionary = await _time_frames(_frames)
			print("[contrail_shot] contrail_cost finish=%s launch=%d machines=%d above_300m=%d trailing=%d segments_in_use=%d of %d with: cpu %.3f gpu %.3f contrails_lap %.3f ms; without: cpu %.3f gpu %.3f ms"
				% [finish_name, launch, Sim.current.size(), above, trailing, in_use,
					TrailTuning.CONTRAIL_SEGMENTS, drawn["cpu"], drawn["gpu"], drawn["contrails"], bare["cpu"], bare["gpu"]])
		_level.contrails = yard
		yard.visible = true


## THE PROJECT'S TRAIL SHADER AGAINST THE ONE IN `--old_shaders`, new first, three times, on the material the contrails
## are wearing. The same yard lays in both arms, so what moves between them is the shader.
func _old_against_new(finish_name: String, yard: ContrailYard) -> void:
	var worn: ShaderMaterial = _level.missiles.trail_material(finish_name == "fine")
	var new_shader: Shader = worn.shader
	var old_shader := Shader.new()
	old_shader.code = FileAccess.get_file_as_string(_old_shaders.path_join(new_shader.resource_path.get_file()))
	_check("the_old_shader_is_there_to_time", not old_shader.code.is_empty(), "%s" % _old_shaders)
	for launch in range(3):
		var arms: Dictionary = {}
		for arm in ["new", "old"]:
			worn.shader = new_shader if arm == "new" else old_shader
			arms[arm] = await _time_frames(_frames)
		worn.shader = new_shader
		print("[contrail_shot] contrail_ab finish=%s launch=%d trailing_segments=%d new: cpu %.3f gpu %.3f ms; old: cpu %.3f gpu %.3f ms"
			% [finish_name, launch, yard.segments_in_use(), arms["new"]["cpu"], arms["new"]["gpu"], arms["old"]["cpu"],
				arms["old"]["gpu"]])


## ---- the machinery -------------------------------------------------------------------------

## Where this machine has the vehicle nearest a point, or `otherwise`.
func _drawn_nearest(near: Vector3, otherwise: Vector3) -> Vector3:
	var best: Vector3 = otherwise
	var nearest: float = 300.0
	for entity in Sim.current:
		var at: Vector3 = ((Sim.current[entity] as Dictionary).get("position", Vector3.ZERO) as Vector3)
		if at.distance_to(near) < nearest:
			nearest = at.distance_to(near)
			best = at
	return best


## The entity this machine draws nearest a point, within 300 m, or 0: the id a yard knows it by, which is not the id a
## spawn returns.
func _drawn_entity_nearest(near: Vector3) -> int:
	var best: int = 0
	var nearest: float = 300.0
	for entity in Sim.current:
		var away: float = ((Sim.current[entity] as Dictionary).get("position", Vector3.ZERO) as Vector3).distance_to(near)
		if away < nearest:
			nearest = away
			best = int(entity)
	return best


## STOP EVERYTHING THAT MOVES: the simulation and the level's drawing, which is the missile yard's clock.
func _freeze() -> void:
	Sim.set_physics_process(false)
	Sim.previous = Sim.current
	_level.set_physics_process(false)
	_level.set_process(false)


func _run() -> void:
	Sim.set_physics_process(true)
	_level.set_physics_process(true)
	_level.set_process(true)


func _save(view: String, finish_name: String, time: int) -> String:
	for i in range(6):
		await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	var called: String = view + "-" + finish_name
	if time >= 0:
		called += "-" + DaylightTuning.name_of(time).to_lower()
	var file: String = "%s/%s.png" % [_out, called]
	shot.save_png(file)
	print("[contrail_shot] saved %s" % ProjectSettings.globalize_path(file))
	return ProjectSettings.globalize_path(file)


## Medians over `frames` frames: the viewport's CPU and GPU render time and the stopwatch's `contrails` lap, in ms.
func _time_frames(frames: int) -> Dictionary:
	var viewport: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var cpu: PackedFloat64Array = []
	var gpu: PackedFloat64Array = []
	var trails: PackedFloat64Array = []
	await RenderingServer.frame_post_draw
	if _watch != null:
		_watch.call("take")
	for i in range(frames):
		await RenderingServer.frame_post_draw
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		var laps: Dictionary = _watch.call("take") if _watch != null else {}
		trails.append(float(laps.get(&"contrails", 0)) / 1000.0)
	return {"cpu": _median(cpu), "gpu": _median(gpu), "contrails": _median(trails)}


static func _median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


## THE FINISH, by the real key, read off the InputMap; and the samples read back off the viewport.
func _wear(finish_name: String) -> void:
	var fine: bool = finish_name == "fine"
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
