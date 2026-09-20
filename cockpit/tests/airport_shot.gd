extends Node
## CAPE INTERNATIONAL, LOOKED AT: the island's airliner airport from the air, on the real island, for eyes and for the
## user's proof.
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/airport_shot.tscn -- --level=watch
##       --clouds=none --scene=look --out=C:/somewhere
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). Whether the airport keeps
## its clearances, fits the 747 and leaves the rock alone is tests/airport.gd's; this is for eyes.
## NEVER A CAPTURE OF THE DESKTOP: every picture is the viewport's own image.
##
## `--scene=look`: stills from the air -- the terminal and its gates from the south-west, the crossing from the east, and
## the whole airport straight down -- each `airport-look-<name>.png` in `--out`.
##
## `--scene=trip`: the user's "takeoff and land" with the 747, as the Cessna's trip was shown (lane/pattern). A 747 on a
## remote stand taxis to 09, takes off, departs out over the sea, flies back and is vectored onto the instrument final for
## 36, lands, turns off and taxis in to a gate. As it comes down the final, a 737 taxis out for 09 and holds short while the
## 747 lands on the crossing runway, then goes. Seen from behind the 747 (a chase camera), with its leg, height and speed on
## the banner; timelapse it with `--write-movie x.avi --fixed-fps 3` (see pattern_shot for why not `time_scale`). At the
## end, `airport-trip-top.png`: the whole flight from straight down, both tracks drawn, and `airport-trip-tracks.txt`.
## `--no-picture` flies the same headless, as fast as the machine goes, for setting the flight up.

## THE VIEWS OF `look`: where the camera stands and what it looks at, in the frame of runway 09/27 as the airport's file
## is laid (along toward 09's threshold in the west, across to the north), metres, with the camera's height; and a
## straight-down view's middle and how much ground it shows.
const LOOKS: Array[Dictionary] = [
	{"name": "gates", "from": Vector3(1250.0, 170.0, 250.0), "at": Vector3(700.0, 0.0, -300.0), "fov": 50.0},
	{"name": "terminal", "from": Vector3(1150.0, 60.0, -150.0), "at": Vector3(760.0, 8.0, -320.0), "fov": 55.0},
	{"name": "crossing", "from": Vector3(-1900.0, 520.0, -900.0), "at": Vector3(-500.0, 0.0, 0.0), "fov": 50.0},
	{"name": "approach", "from": Vector3(-500.0, 260.0, -5200.0), "at": Vector3(-500.0, 0.0, -2200.0), "fov": 55.0},
]
const DOWN: Dictionary = {"name": "plan", "middle": Vector2(300.0, -1300.0), "metres": 3600.0}

## THE TRIP. How long before the 747 touches down on 36 the 737 is sent to taxi from remote.1 to 09's bar: its taxi, about
## 300 s in the first trip, and a minute of holding for the 747 on short final; sent 16 km out on the final instead, it
## reached the bar with the 747 already turning off, and never held. Then the chase camera, behind and above along its
## track and eased; the colours of the tracks, 747 first.
const SEND_THE_737_S: float = 330.0
const CHASE_BACK: float = 150.0
const CHASE_UP: float = 38.0
const CHASE_EASE: float = 0.05
const TRACK_COLOURS: Array[Color] = [Color(1.0, 0.25, 0.2), Color(0.2, 0.75, 1.0)]
const TRACK_EVERY: int = 30
## A drawn line's width in pixels of the top-down picture, and how much ground that picture shows across its height.
const LINE_PIXELS: float = 4.0
const RUNWAY_COLOUR := Color(1.0, 0.9, 0.3)
const IFR_COLOUR := Color(0.55, 1.0, 0.55, 0.9)

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://airport_shot"
var _scene: String = "look"
var _pictures: bool = true
var _seconds: float = 3000.0
var _speed: String = ""
var _traffic: AirportTraffic = null
var _planes: Array[int] = []
var _tracks: Array = []
var _banner: Label = null
var _chase_at := Vector3.INF
## The farthest out, per axis, the 747 flew: the world's soft edge begins at the placed reach plus 2 km.
var _widest: float = 0.0


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--scene="):
			_scene = argument.trim_prefix("--scene=")
		elif argument.begins_with("--seconds="):
			_seconds = argument.trim_prefix("--seconds=").to_float()
		elif argument.begins_with("--speed="):
			_speed = argument.trim_prefix("--speed=")
	_pictures = not OS.get_cmdline_user_args().has("--no-picture")
	if _pictures and DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	await _frames(60)
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false
	var base: Dictionary = {}
	for laid in AirbasePlan.bases():
		if String(laid["id"]) == "cape_international":
			base = laid
	_check("the_airport_is_laid", not base.is_empty(), AirbasePlan.last_refusal)
	if base.is_empty():
		_finish()
		return
	if _scene == "look":
		_park(base)
		await _frames(30)
		await _look(base)
	elif _scene == "trip":
		await _trip(base)
	_finish()


## ---- the trip ------------------------------------------------------------------------------------------------------

func _trip(base: Dictionary) -> void:
	var from: Dictionary = Airfield.named("cape_09_27")
	var to: Dictionary = Airfield.named("cape_18_36")
	_traffic = AirportTraffic.new()
	_traffic.recording = true
	add_child(_traffic)
	var jumbo: int = _parked_on(base, "remote.2", Sim.Kind.JUMBO)
	_check("the_747_stands_on_its_remote_stand", jumbo != 0, "")
	if jumbo == 0:
		return
	_traffic.depart(jumbo, from, Sim.Kind.JUMBO, "remote.2", "", to)
	_planes.append(jumbo)
	_tracks.append(PackedVector3Array())
	if _pictures:
		var camera: Camera3D = _level.observer
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 60.0
		camera.far = 30000.0
		_banner = Label.new()
		_banner.add_theme_font_size_override("font_size", 26)
		_banner.add_theme_color_override("font_color", Color.WHITE)
		_banner.add_theme_color_override("font_outline_color", Color.BLACK)
		_banner.add_theme_constant_override("outline_size", 6)
		_banner.position = Vector2(24, 18)
		var layer := CanvasLayer.new()
		layer.add_child(_banner)
		add_child(layer)
	# THIRTY PHYSICS TICKS A FRAME at `--fixed-fps 4`, and the loop must be let run them (pattern_shot).
	Engine.max_physics_steps_per_frame = 64
	var started: float = Time.get_ticks_msec()
	var tick: int = 0
	var liner: int = 0
	var b737: Dictionary = {}
	var held_s: float = 0.0
	var held_for: String = ""
	while float(tick) / 120.0 < _seconds:
		await get_tree().physics_frame
		tick += 1
		var me: Dictionary = _traffic.record_of(jumbo)
		var state: Dictionary = Sim.server.vehicle_state(jumbo)
		if me.is_empty() or state.is_empty() or bool(Sim.server.hull_state(jumbo).get("destroyed", false)):
			_check("the_747_is_still_flying", false, "lost at tick %d, phase %s" % [tick, me.get("phase", "?")])
			break
		_widest = maxf(_widest, WorldEdge.out(state["position"]))
		# THE 737, sent as the 747 comes down 36's final.
		if liner == 0 and String(me["field"]) == "cape_18_36" and _seconds_to_touchdown(me, state) < SEND_THE_737_S:
			liner = _parked_on(base, "remote.1", Sim.Kind.AIRLINER)
			if liner != 0:
				_traffic.depart(liner, from, Sim.Kind.AIRLINER, "remote.1")
				# ITS RECORD KEPT HERE: `release` erases it from the traffic once it has departed, and the first trip
				# reported the 737 with no legs at all.
				b737 = _traffic.record_of(liner)
				_planes.append(liner)
				_tracks.append(PackedVector3Array())
		if not b737.is_empty() and b737["phase"] == &"hold_short":
			held_s += 1.0 / 120.0
			if String(b737.get("holding_for", "")) != "":
				held_for = b737["holding_for"]
		if tick % TRACK_EVERY == 0:
			_follow()
		# PROGRESS, every 30 simulated seconds: a trip is 20 minutes of flying, and a headless run that says nothing until
		# its deadline says nothing about where it stuck.
		if tick % 3600 == 0:
			print("[airport_shot] %.0f s: 747 %s at %s, %.0f m/s; wall %.0f s" % [float(tick) / 120.0, me["phase"],
				str((state["position"] as Vector3).round()), (state["velocity"] as Vector3).length(),
				(Time.get_ticks_msec() - started) / 1000.0])
		if _pictures:
			_chase(state)
		if me["phase"] == &"parked" and b737.has("lift_off"):
			break
	_follow()
	var me: Dictionary = _traffic.record_of(jumbo)
	print("[airport_shot] 747 legs %s" % str(me.get("legs", [])))
	print("[airport_shot] 747 gate %s, go-arounds %d, gear at the touch %s, farthest out %.1f km per axis" % [
		me.get("gate", "none"), int(me.get("go_arounds", 0)), me.get("gear_at_touch", "?"), _widest / 1000.0])
	print("[airport_shot] 737 legs %s, held short %.0f s for \"%s\", lifted off %s" % [str(b737.get("legs", [])), held_s,
		held_for, b737.has("lift_off")])
	_check("the_737_held_short_for_the_747_and_went", held_s > 5.0 and b737.has("lift_off"),
		"held %.0f s, lifted off %s" % [held_s, b737.has("lift_off")])
	print("[airport_shot] %.0f simulated seconds in %.0f s" % [float(tick) / 120.0, (Time.get_ticks_msec() - started) / 1000.0])
	_check("the_747_flew_the_whole_trip", me.get("phase") == &"parked" and (me.get("legs", []) as Array).has(&"take_off") \
		and int(me.get("go_arounds", 0)) == 0, "phase %s" % me.get("phase", "?"))
	# NEVER INTO THE EDGE'S WARNING BAND, the level's own (`Sim.edge`, sky.gd `_mark_the_edge`): an approach that warned its
	# pilot to turn back would be one the island is too small for (team-lead, 2026-09-19).
	var warn: float = float((Sim.edge as Dictionary).get("warn_from", INF))
	_check("it_never_enters_the_worlds_warning_band", _widest < warn,
		"farthest %.1f km per axis against the warning from %.1f" % [_widest / 1000.0, warn / 1000.0])
	_write_the_tracks()
	if _pictures:
		await _top_down()


## HOW LONG BEFORE THE 747 TOUCHES DOWN ON 36, seconds at its speed: the vectors' fixes still to fly and the final from the
## last of them, or the final alone; INF before it is on its way to 36.
func _seconds_to_touchdown(me: Dictionary, state: Dictionary) -> float:
	var speed: float = maxf((state["velocity"] as Vector3).length(), 1.0)
	var p: TrafficPattern = me["pattern"]
	if me["phase"] in [&"final", &"straight_in"]:
		return _traffic._path_left(me) / speed
	if me["phase"] != &"vectors":
		return INF
	var fixes: PackedVector3Array = me["fixes"]
	var path: float = 0.0
	var from: Vector3 = state["position"]
	for k in range(int(me["fix_next"]), fixes.size()):
		path += Vector2(fixes[k].x - from.x, fixes[k].z - from.z).length()
		from = fixes[k]
	return (path + Vector2(p.threshold.x - from.x, p.threshold.z - from.z).length()) / speed


## A CRAFT ON A STAND, on its brakes.
func _parked_on(base: Dictionary, id: String, kind: int) -> int:
	var spot: Dictionary = (base["spots"] as Dictionary).get(id, {})
	if spot.is_empty():
		return 0
	var extents: Vector3 = Sim.geometry_of(kind).get("extents", Vector3.ONE)
	var at: Vector3 = AirbasePlan.standing_on_spot(base, spot, kind) + Vector3.UP * (extents.y + 0.3)
	var entity: int = Sim.spawn_ai_vehicle(kind, at, float(spot["yaw"]), Vector3.ZERO)
	if entity != 0:
		Sim.server.steer_ai(entity, {"toward": at, "altitude": at.y, "speed": 0.0, "wheels": "hold"})
	return entity


## THE CHASE: behind and above the 747 along its track (along its nose while it is too slow to have one), eased so a
## turn swings the view rather than jerking it; nearer on the ground, where a taxi is slow and the airport is close.
func _chase(state: Dictionary) -> void:
	var at: Vector3 = state["position"]
	var v: Vector3 = state["velocity"]
	var going := Vector3(v.x, 0.0, v.z)
	if going.length() < 3.0:
		going = (Basis(state["basis"] as Quaternion) * Vector3.FORWARD) * Vector3(1.0, 0.0, 1.0)
	var down: bool = at.y - maxf(Terrain.surface_height(at), 0.0) < 30.0
	var back: float = CHASE_BACK * (0.8 if down else 1.0)
	var want: Vector3 = at - going.normalized() * back + Vector3.UP * CHASE_UP
	_chase_at = want if _chase_at == Vector3.INF else _chase_at.lerp(want, CHASE_EASE)
	_level.observer.look_from(_chase_at, at + Vector3.UP * 4.0)


## EVERY `TRACK_EVERY` TICKS: each aeroplane's track, and the banner.
func _follow() -> void:
	var words := PackedStringArray()
	for i in range(_planes.size()):
		var state: Dictionary = Sim.server.vehicle_state(_planes[i])
		var me: Dictionary = _traffic.record_of(_planes[i])
		if state.is_empty():
			continue
		# A PACKED ARRAY IS A VALUE: appended through a cast, the point goes into a copy.
		var points: PackedVector3Array = _tracks[i]
		points.append(state["position"])
		_tracks[i] = points
		if me.is_empty():
			continue
		var at: Vector3 = state["position"]
		var leg: String = String(me["phase"]).to_upper().replace("_", " ")
		var ground: float = maxf(Terrain.surface_height(at), 0.0)
		var runway: String = "09" if String(me["field"]) == "cape_09_27" else "36"
		words.append("%s %s (%s): %s  |  %d m  |  %d kt" % ["747" if i == 0 else "737", ["RED", "BLUE"][i], runway, leg,
			roundi(at.y - ground), roundi((state["velocity"] as Vector3).length() * 1.944)])
	if _banner != null:
		_banner.text = "Cape International  |  %s%s" % ["     ".join(words), ("  |  x" + _speed) if _speed != "" else ""]


func _write_the_tracks() -> void:
	var file := FileAccess.open(_out.path_join("airport-trip-tracks.txt"), FileAccess.WRITE)
	if file == null:
		return
	file.store_line("entity tick phase x y z speed climb")
	for entity in _planes:
		for look in _traffic.record_of(entity).get("track", []):
			var at: Vector3 = look["at"]
			var v: Vector3 = look["v"]
			file.store_line("%d %d %s %.0f %.1f %.0f %.1f %.2f" % [entity, int(look["tick"]), look["phase"], at.x, at.y, at.z,
				v.length(), v.y])


## THE WHOLE FLIGHT FROM STRAIGHT DOWN: both tracks, the two runways' outlines and the instrument final into 36, over all
## the ground the 747 flew, and a closer one of the airport with the taxiing.
func _top_down() -> void:
	var bounds := AABB()
	var first := true
	for points in _tracks:
		for p in points:
			bounds = AABB(p, Vector3.ZERO) if first else bounds.expand(p)
			first = false
	var middle: Vector3 = bounds.get_center()
	var metres: float = maxf(bounds.size.z, bounds.size.x * 900.0 / 1600.0) * 1.1
	await _draw_and_save(middle, metres, "airport-trip-top")
	var airport: Vector3 = AirbasePlan.frame_point(AirbasePlan.bases().filter(func(b: Dictionary) -> bool:
		return String(b["id"]) == "cape_international")[0]["frame"], -300.0, -1200.0)
	await _draw_and_save(airport, 4200.0, "airport-trip-airport")


var _drawn: Array[Node] = []


func _draw_and_save(middle: Vector3, metres: float, name: String) -> void:
	for node in _drawn:
		node.queue_free()
	_drawn.clear()
	var width: float = LINE_PIXELS * metres / 900.0
	for i in range(_tracks.size()):
		_ribbon(_tracks[i], TRACK_COLOURS[i % TRACK_COLOURS.size()], width)
	for id in ["cape_09_27", "cape_18_36"]:
		var frame: Dictionary = Airfield.named(id)["frame"]
		var half_l: Vector3 = (frame["along"] as Vector3) * float(frame["length"]) * 0.5
		var half_w: Vector3 = (frame["across"] as Vector3) * float(frame["width"]) * 0.5
		var c: Vector3 = frame["centre"]
		_ribbon(PackedVector3Array([c - half_l - half_w, c + half_l - half_w, c + half_l + half_w, c - half_l + half_w,
			c - half_l - half_w]), RUNWAY_COLOUR, width * 0.6)
	var p36: TrafficPattern = Airfield.pattern_for(Airfield.named("cape_18_36"), Sim.Kind.JUMBO)
	var ifr := InstrumentApproach.make(p36, Airfield.numbers_of(Sim.Kind.JUMBO))
	_ribbon(PackedVector3Array([p36.point(-ifr.established_out(), 0.0), p36.threshold]), IFR_COLOUR, width * 0.6)
	var faf: Vector3 = p36.threshold - p36.along * InstrumentApproach.FAF_OUT
	_ribbon(PackedVector3Array([faf + p36.across * 600.0, faf - p36.across * 600.0]), IFR_COLOUR, width * 0.6)
	if _banner != null:
		_banner.text = "Cape International: the 747's trip (red), 09 to 36, and the 737 (blue) that held short for it on 09"
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = metres
	camera.far = 8000.0
	camera.look_from(middle * Vector3(1, 0, 1) + Vector3.UP * 3000.0, middle * Vector3(1, 0, 1) + Vector3(0.0, 0.0, -0.001))
	await _frames(45)
	_save(name)


func _ribbon(points: PackedVector3Array, colour: Color, width: float) -> void:
	if points.size() < 2:
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var a := Vector3(points[i].x, 5.0, points[i].z)
		var b := Vector3(points[i + 1].x, 5.0, points[i + 1].z)
		var along := b - a
		if along.length() < 0.01:
			continue
		var side: Vector3 = Vector3(-along.z, 0.0, along.x).normalized() * width * 0.5
		var reach: Vector3 = along.normalized() * width * 0.5
		for v in [a - reach - side, b + reach - side, a - reach + side, a - reach + side, b + reach - side, b + reach + side]:
			mesh.surface_add_vertex(v)
	mesh.surface_end()
	var drawn := MeshInstance3D.new()
	drawn.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 10
	drawn.material_override = material
	add_child(drawn)
	_drawn.append(drawn)


## WHAT STANDS AT THE GATES FOR THE PICTURE: a 747 at every other stand laid for one and a 737 at every other 737 gate,
## each on its brakes -- an autopilot on its wheels with nothing asked of it takes off (lane/pattern).
func _park(base: Dictionary) -> void:
	var k := 0
	for id in base["spots"]:
		k += 1
		if k % 2 == 0:
			continue
		var spot: Dictionary = base["spots"][id]
		var kind: int = Sim.Kind[spot.get("craft", "JUMBO")]
		var extents: Vector3 = Sim.geometry_of(kind).get("extents", Vector3.ONE)
		var at: Vector3 = AirbasePlan.standing_on_spot(base, spot, kind) + Vector3.UP * (extents.y + 0.3)
		var entity: int = Sim.spawn_ai_vehicle(kind, at, float(spot["yaw"]), Vector3.ZERO)
		if entity != 0:
			Sim.server.steer_ai(entity, {"toward": at, "altitude": at.y, "speed": 0.0, "wheels": "hold"})


func _look(base: Dictionary) -> void:
	var frame: Dictionary = base["frame"]
	var camera: Camera3D = _level.observer
	for look in LOOKS:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = look["fov"]
		camera.far = 30000.0
		var from: Vector3 = look["from"]
		var at: Vector3 = look["at"]
		camera.look_from(AirbasePlan.frame_point(frame, from.x, from.z) + Vector3.UP * from.y,
			AirbasePlan.frame_point(frame, at.x, at.z) + Vector3.UP * at.y)
		await _frames(45)
		_save("airport-look-%s" % look["name"])
	var middle: Vector2 = DOWN["middle"]
	var centre: Vector3 = AirbasePlan.frame_point(frame, middle.x, middle.y)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = DOWN["metres"]
	camera.far = 8000.0
	camera.look_from(centre + Vector3.UP * 3000.0, centre + Vector3(0.0, 0.0, -0.001))
	await _frames(45)
	_save("airport-look-%s" % DOWN["name"])


func _save(name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	print("[airport_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
