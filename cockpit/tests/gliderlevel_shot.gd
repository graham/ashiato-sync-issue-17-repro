extends Node
## THE GLIDER LEVEL, LOOKED AT: the ridge country from where a glider pilot sits, for eyes and for the user's proof.
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/gliderlevel_shot.tscn -- --level=watch
##       --scene=look --out=C:/somewhere
##   ... --fixed-fps 5 --write-movie C:/somewhere/reel.avi ... -- --level=watch --scene=reel --out=C:/somewhere
##   ... -- --level=watch --scene=map --out=C:/somewhere
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (seeing_the_game.md). Whether the level stands,
## where its thermals are and how many clouds it holds is tests/gliderlevel.gd's; this is for eyes. NEVER A CAPTURE OF
## THE DESKTOP: every picture is the viewport's own image.
##
## `--scene=look`: stills from the air, each `gliderlevel-look-<name>.png` in `--out`, every eye placed over the ground
## under it and every target named by what it is, read off the level rather than typed: the start's cumulus from where an
## arrival is launched, 1,000 ft up; the cloud field from a thermal's top looking along the loop; the north ridge from
## under the north-ridge thermal; the lone peak from under its own thermal; and a high oblique of the whole sixteen
## kilometres from the south.
##
## `--scene=reel`: a robot glider flown by `SoaringPilot`, chased from a wingman's place while it circles in the start's
## thermal, leaves under the cloud and glides to the next one. Recorded through MovieWriter at a low `--fixed-fps` and
## played back at 30, which is the only way a 1.8 m/s climb is something to watch.
##
## `--scene=map`: the whole level from straight up, orthographic, with every machine of the level's air traffic drawing
## its own track behind it -- where the thermals are, where the ridges are, and where the traffic actually went.

## Frames given to the ground and its scenery to stream in round a new eye before the picture.
const SETTLE: int = 240
## A glider pilot's height at the launch, over the ground: 1,000 ft.
const LAUNCH_OVER: float = 304.8
## THE REEL: how far under the cloud base the robot starts (a climb from 1,000 ft to the cloud is a quarter of an hour of
## simulation), how long it is followed, and where the chase camera sits -- beside and behind, never straight behind.
const REEL_UNDER: float = 700.0
const REEL_SECONDS: float = 420.0
const CHASE_SIDE: float = 28.0
const CHASE_BACK: float = 26.0
const CHASE_UP: float = 6.0
## THE MAP: how wide the frame is, how high the eye is, how long the tracks are drawn for, and how they are drawn. The
## eye is UNDER THE CLOUD (an orthographic camera frames the same square at any height, and from over the sky the whole
## picture was cloud tops and nothing else) and over the tallest ridge, and the map is drawn with `--clouds=none`.
const MAP_METRES: float = 17000.0
const MAP_UP: float = 1500.0
const MAP_SECONDS: float = 300.0
const MAP_TRACKS_AT: float = 1300.0
const MAP_TRACK_WIDTH: float = 60.0
## A colour per kind, so a track says what drew it: gliders white, Cessnas amber, light twins green, helicopters blue,
## airliners red.
const TRACK_COLOUR: Dictionary = {"glider": Color(1.0, 1.0, 1.0), "cessna": Color(1.0, 0.72, 0.2),
	"plane": Color(0.4, 1.0, 0.45), "heli": Color(0.45, 0.7, 1.0), "airliner": Color(1.0, 0.4, 0.4)}

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = "user://gliderlevel_shot"
var _scene: String = "look"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--scene="):
			_scene = argument.trim_prefix("--scene=")
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var chosen: String = Net.choose_level("gliders")
	_check("the_glider_level_can_be_chosen", chosen == "", chosen)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	while _level.ground_built_msec < 0.0 or not Sim.is_ready:
		await _frames(1)
	await _frames(60)
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false
	match _scene:
		"look":
			await _look()
		"reel":
			await _reel()
		"map":
			await _map()
		_:
			_check("the_scene_is_one_this_probe_draws", false, "'%s': look, reel or map" % _scene)
	_finish()


## THE VIEWS, from the level's own zones: each `{name, from, at, fov}`, world metres.
func _views() -> Array[Dictionary]:
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var named: Dictionary = {}
	for zone in zones:
		named[String(zone.get("name", ""))] = zone
	var start: Dictionary = named["the start"]
	var p: Vector3 = start["position"]
	var out: Array[Dictionary] = []
	# FROM THE LAUNCH: 1,000 ft over the ground, 1.2 km south of the start's middle, looking at its cloud's base.
	var launch := Vector3(p.x, 0.0, p.z + 1200.0)
	launch.y = Terrain.ground_height(launch) + LAUNCH_OVER
	out.append({"name": "launch", "from": launch, "at": Vector3(p.x, float(start["top"]), p.z), "fov": 70.0})
	# THE CLOUD FIELD from the start's top less a hundred metres, looking north-west along the loop to the gliding club.
	var club: Vector3 = named["the gliding club"]["position"]
	var high := Vector3(p.x, float(start["top"]) - 100.0, p.z)
	out.append({"name": "cloud-field", "from": high, "at": Vector3(club.x, float(start["top"]) - 300.0, club.z), "fov": 70.0})
	# THE NORTH RIDGE from under its thermal, looking north at the crest.
	var north: Vector3 = named["under the north ridge"]["position"]
	var under := Vector3(north.x + 800.0, 0.0, north.z + 1500.0)
	under.y = Terrain.ground_height(under) + 600.0
	out.append({"name": "north-ridge", "from": under, "at": Vector3(north.x, 700.0, north.z - 1900.0), "fov": 65.0})
	# THE LONE PEAK in the south-west, from under its own thermal, a kilometre up.
	var peak: Vector3 = named["under the lone peak"]["position"]
	var eye := Vector3(peak.x + 2600.0, 0.0, peak.z + 2200.0)
	eye.y = Terrain.ground_height(eye) + 1000.0
	out.append({"name": "lone-peak", "from": eye, "at": Vector3(-5200.0, 650.0, 5000.0), "fov": 60.0})
	# THE WHOLE LEVEL from the south, high: 9 km out and 5 km up, looking at the middle.
	out.append({"name": "whole", "from": Vector3(0.0, 5000.0, 12000.0), "at": Vector3(0.0, 0.0, -1000.0), "fov": 60.0})
	return out


func _look() -> void:
	var camera: Camera3D = _level.observer
	for view in _views():
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = view["fov"]
		camera.look_from(view["from"], view["at"])
		await _frames(SETTLE)
		_save("gliderlevel-look-%s" % view["name"])


func _save(name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	_check("saved_%s" % name, get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	print("[gliderlevel_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()


## ---- the reel and the map (lane/gliderlevel S4) ----------------------------------------------------------------

## A ROBOT GLIDER FLOWN BY `SoaringPilot`, chased from a wingman's place: circling in the start's thermal, leaving under
## the cloud and gliding to the next one between the cumulus. A TIMELAPSE, because a climb of 1.8 m/s is not a thing to
## watch at one times: MovieWriter at `--fixed-fps 5` is 24 physics ticks a rendered frame, played back at 30 for 6x
## (learnings/2026-09-19-pattern.md: `Engine.time_scale` does NOT do this).
##
## NEVER STRAIGHT BEHIND: a wingman's place, off to one side, because an aeroplane's wingtip trails stream past a lens
## put right behind it (lane/combat).
func _reel() -> void:
	Engine.max_physics_steps_per_frame = 64
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var start: Dictionary = zones[0]
	var at: Vector3 = start["position"]
	at.y = float(start["top"]) - REEL_UNDER
	var yaw: float = 0.0
	var robot: int = Sim.spawn_ai_vehicle(Sim.Kind.GLIDER, at, yaw,
		Terrain.nose_from_yaw(yaw) * Terrain.cruise_for(Sim.Kind.GLIDER))
	var pilot := SoaringPilot.new()
	pilot.name = "ReelSoaringPilot"
	add_child(pilot)
	pilot.fly(robot, 0)
	var banner := Label.new()
	banner.add_theme_font_size_override("font_size", 26)
	banner.add_theme_color_override("font_color", Color.WHITE)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 6)
	banner.position = Vector2(24, 18)
	var layer := CanvasLayer.new()
	layer.add_child(banner)
	add_child(layer)
	var camera: Camera3D = _level.observer
	var hz: int = Engine.physics_ticks_per_second
	var was: float = at.y
	var climb: float = 0.0
	for tick in range(int(REEL_SECONDS * float(hz))):
		await get_tree().physics_frame
		var state: Dictionary = Sim.server.vehicle_state(robot)
		if state.is_empty() or not pilot.gliders.has(robot):
			break
		var p: Vector3 = state["position"]
		var v: Vector3 = state["velocity"]
		# THE WINGMAN'S PLACE: out to the right of the glider's own track and a little behind and above it.
		var along := Vector3(v.x, 0.0, v.z).normalized()
		var side := Vector3(-along.z, 0.0, along.x)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 60.0
		camera.look_from(p + side * CHASE_SIDE - along * CHASE_BACK + Vector3.UP * CHASE_UP, p)
		if tick % hz == 0:
			climb = p.y - was
			was = p.y
			var record: Dictionary = pilot.gliders[robot]
			var zone: Dictionary = zones[int(record["zone"])]
			banner.text = "%s %s · %d m over the ground · %+0.1f m/s" % [
				"circling" if String(record["phase"]) == "climb" else "gliding to",
				zone.get("name", "?"), roundi(p.y - Terrain.ground_height(p)), climb]
	var record: Dictionary = pilot.gliders.get(robot, {})
	var climbs: Array = record.get("climbs", [])
	var words: PackedStringArray = []
	for one in climbs:
		words.append("%s %+.0f m in %.0f s" % [one["name"], float(one["to"]) - float(one["from"]), float(one["seconds"])])
	_check("the_robot_glider_flew_the_reel", pilot.gliders.has(robot),
		"%s, now %s zone %d" % [", ".join(words) if not words.is_empty() else "no climb finished",
			record.get("phase", "?"), int(record.get("zone", -1))])


## THE WHOLE LEVEL FROM STRAIGHT UP, with every machine's track drawn behind it: the thermals' clouds, the ridges and
## where the traffic actually went. Orthographic, so a kilometre is a kilometre anywhere in the frame.
func _map() -> void:
	Engine.max_physics_steps_per_frame = 64
	# AND THE AIR TAKEN OUT OF IT: sixteen kilometres seen through the level's own haze from 1,500 m is a grey sheet with
	# tracks on it. A map is a drawing, not a view.
	var air := _level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if air != null and air.environment != null:
		air.environment.fog_enabled = false
	if _level.mist != null:
		_level.mist.visible = false
	var camera: Camera3D = _level.observer
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = MAP_METRES
	camera.far = 4000.0
	camera.look_from(Vector3(0.0, MAP_UP, 0.0), Vector3(0.0, 0.0, -0.001))
	var traffic: AirTraffic = _level.air_traffic
	var tracks: Dictionary = {}
	var lines: Dictionary = {}
	var hz: int = Engine.physics_ticks_per_second
	for tick in range(int(MAP_SECONDS * float(hz))):
		await get_tree().physics_frame
		if tick % (hz / 2) != 0 or traffic == null:
			continue
		for entity in traffic.machines:
			var state: Dictionary = Sim.server.vehicle_state(int(entity))
			if state.is_empty():
				continue
			if not tracks.has(entity):
				# A PACKED ARRAY IS A VALUE (lane/pattern): it is put back into the Dictionary after every append.
				tracks[entity] = PackedVector3Array()
				var mesh := ImmediateMesh.new()
				var drawn := MeshInstance3D.new()
				drawn.mesh = mesh
				var kind: int = int((traffic.machines[entity] as Dictionary)["kind"])
				drawn.material_override = _flat(TRACK_COLOUR.get(Sim.kind_name(kind), Color.WHITE))
				add_child(drawn)
				lines[entity] = mesh
			var points: PackedVector3Array = tracks[entity]
			# DRAWN AT ONE HEIGHT, over everything: a track is a plan, not a path through the air, and two at their own
			# heights would be read as one crossing the other.
			var p: Vector3 = state["position"]
			points.append(Vector3(p.x, MAP_TRACKS_AT, p.z))
			tracks[entity] = points
			var mesh: ImmediateMesh = lines[entity]
			mesh.clear_surfaces()
			_ribbon_into(mesh, points, MAP_TRACK_WIDTH)
	_save("gliderlevel-map-tracks")
	_check("the_map_drew_tracks", tracks.size() > 20, "%d machines tracked over %.0f s" % [tracks.size(), MAP_SECONDS])


func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## A FLAT RIBBON through `points`, `width` metres wide, facing up: a line that stays a few pixels wide from 12 km up.
static func _ribbon_into(mesh: ImmediateMesh, points: PackedVector3Array, width: float) -> void:
	if points.size() < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
		if along.length() < 0.01:
			continue
		var side: Vector3 = Vector3(-along.z, 0.0, along.x).normalized() * width * 0.5
		var reach: Vector3 = along.normalized() * width * 0.5
		for corner in [a - reach - side, a - reach + side, b + reach + side, a - reach - side, b + reach + side,
				b + reach - side]:
			mesh.surface_add_vertex(corner)
	mesh.surface_end()
