extends Node
## A REEL OF THE A-10C's GAU-8: the pilot rolls in on a target on the ground, arms, and fires -- the barrels turning, the
## tracers leaving the nose, the rounds landing on the target -- in the real level, from the real simulation, through the
## pilot's own desk keys. A picture probe, not a suite: `tests/warthog_seat.gd` holds everything here to a number.
##
##   <editor>.console.exe --path cockpit --xr-mode off --resolution 1600x900 --write-movie <out.avi> --fixed-fps 30
##       res://tests/warthog_reel.tscn -- --out=<folder>
##
## NOTHING IS PLACED BUT THE TARGET. The A-10 is the level's, boarded as the clipboard boards it; the dive is the stick
## (`pitch_down` / `pitch_up` held as a proportional hand); master arm is U and the trigger SPACE. The target -- a tank on
## land, a gunboat on the sea -- is put where the drawn gun's bore meets the ground once the dive is steady, which is what
## a pilot rolling in on it does the other way round. MovieWriter records this probe's own window, never the desktop.
##
## The caption burns in what the simulation says: the time, the dive angle, the height, the drum's count, the drawn
## barrels' speed, and the rounds that have struck, so a reader can hold the picture to the numbers.
##
## `--eye`: ONE STILL FROM THE PILOT'S OWN EYE, crewed in the level, `EYE_AT` seconds after boarding with the wings held
## level: the seated rig's camera, no caption, nothing placed. The station gallery's picture of the same seat carries the
## gallery's centre marker and reference blocks, and its screens read dashes because the gallery runs no world; this one
## is what a pilot sees, with the flight page live: level, and then with the head tipped down to the screens.
## `--eye --lamp`: AND A SIGNAL LAMP ADDED as "+ SIGNAL LAMP" adds one (`PilotRig._add_a_lamp`), and a third still with the
## head turned down and right to its holster, which must stand inside the glass (lane/lampfix, 2026-09-19).

## THE SCRIPT, seconds from boarding: level with the gear up to 4, rolled in to `DIVE` by 9, armed at 9, the target placed
## and the trigger held from 10 for `BURST`, then pulled out.
const LEVEL_UNTIL: float = 5.0
const DIVE: float = -20.0
const FIRE_AT: float = 10.0
const BURST: float = 2.5
const PULL_AT: float = FIRE_AT + BURST + 2.0
const END_AT: float = 22.0
## STILLS: [seconds, name].
const EYE_AT: float = 3.0
const STILLS: Array = [[2.0, "gear-up-in-flight"], [FIRE_AT + 0.6, "gau8-firing-barrels-turning"],
	[FIRE_AT + 1.4, "tracers-from-the-nose"], [FIRE_AT + 2.3, "rounds-on-the-target"]]

var out := ""
var _eye: bool = false
var _lamp: bool = false
## The seated rig's own camera, held once it is found. THE TIPPED CAMERA IS ITS CHILD: placed once, it was 60 m behind
## by the picture; re-placed every `_process`, it was still drawn a physics step late, 2.5 m behind the eye at 150 m/s,
## and the picture was the back of the pilot's own ACES II.
var _eye_camera: Camera3D = null
var _level: FlightLevel = null
var _view: VehicleView = null
var _camera: Camera3D = null
var _caption: Label = null
var _t: float = -1.0
var _armed: bool = false
var _target: int = 0
var _target_at := Vector3.ZERO
## The first round's direction, flattened: which way the fire comes in over the target.
var _target_along := Vector3.FORWARD
var _firing: bool = false
var _stills_taken: int = 0
var _hits: int = 0
var _seen: Dictionary = {}


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		elif argument == "--eye":
			_eye = true
		elif argument == "--lamp":
			_lamp = true
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	for i in range(3):
		await get_tree().process_frame
	for i in range(240):
		await get_tree().physics_frame
	var rig: PilotRig = _level.rig
	rig.ask_for_kind(Sim.Kind.WARTHOG)
	for i in range(900):
		await get_tree().physics_frame
		_view = rig.vehicle_view()
		if _view != null and _view.kind == Sim.Kind.WARTHOG and rig.seat_index() == 0:
			break
	if _view == null or _view.kind != Sim.Kind.WARTHOG:
		print("[warthog_reel] RESULT=FAIL never boarded")
		get_tree().quit(1)
		return
	if _eye and _lamp:
		# THE RIG SITS A FEW FRAMES AFTER THE VIEW SAYS IT HAS BOARDED: pressed at once, it had no station to put a lamp in.
		for i in range(300):
			if rig.get("_my_station") != null and _view.station_for(0) != null:
				break
			await get_tree().physics_frame
		rig.call("_add_a_lamp")
		if SignalLamp.in_station(_view.station_for(0)) == null:
			print("[warthog_reel] RESULT=FAIL + SIGNAL LAMP put no lamp in the pilot's station")
			get_tree().quit(1)
			return
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 20000.0
	get_tree().root.add_child(_camera)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.position = Vector2(24, 18)
	layer.add_child(_caption)
	# THE LEVEL'S STATUS LINES OFF: `Ui` is a CanvasLayer, not a CanvasItem, so `set` and not a cast (modelling_here.md).
	var ui: Node = _level.get_node_or_null("Ui")
	if ui != null:
		ui.set("visible", false)
	_t = 0.0


func _physics_process(delta: float) -> void:
	if _t < 0.0 or _view == null:
		return
	_t += delta
	var pitch: float = rad_to_deg(asin(clampf((-_view.global_basis.z).y, -1.0, 1.0)))
	# THE HAND ON THE STICK: level, then the dive, then the pull-out, as a proportional hand on the desk's pitch keys.
	var want: float = 0.0 if _t < LEVEL_UNTIL else (DIVE if _t < PULL_AT else 15.0)
	var stick: float = clampf((want - pitch) * 0.08, -1.0, 1.0)
	Input.action_release("pitch_up")
	Input.action_release("pitch_down")
	if stick > 0.02:
		Input.action_press("pitch_up", stick)
	elif stick < -0.02:
		Input.action_press("pitch_down", -stick)
	# AND THE WINGS HELD LEVEL on the roll keys: the level's A-10 is boarded in whatever turn its autopilot was flying,
	# and the first reel dived in a 70-degree bank, its tracers curving away from the target.
	var right: Vector3 = _view.global_basis.x
	var bank: float = rad_to_deg(asin(clampf(-right.y, -1.0, 1.0)))
	var roll: float = clampf(-bank * 0.04, -1.0, 1.0)
	Input.action_release("roll_left")
	Input.action_release("roll_right")
	if roll > 0.02:
		Input.action_press("roll_right", roll)
	elif roll < -0.02:
		Input.action_press("roll_left", -roll)
	if _eye:
		if _t >= EYE_AT + (2.3 if _lamp else 1.5):
			print("[warthog_reel] RESULT=PASS the pilot's eye, into %s" % out)
			get_tree().quit(0)
		return
	if not _armed and _t >= FIRE_AT - 1.0:
		_armed = true
		_press_key("master_arm", true)
	elif _armed and _t >= FIRE_AT - 0.9 and _t < FIRE_AT - 0.8:
		_press_key("master_arm", false)
	if _target == 0 and _firing:
		_place_the_target()
	if not _firing and _t >= FIRE_AT and _t < FIRE_AT + BURST:
		_firing = true
		_press_key("fire", true)
	elif _firing and _t >= FIRE_AT + BURST:
		_firing = false
		_press_key("fire", false)
	_count_hits()
	if OS.get_cmdline_user_args().has("--trace") and _firing and int(_t * 120.0) % 30 == 0:
		_trace_tracers()
	if _t >= END_AT:
		print("[warthog_reel] RESULT=PASS %d stills, %d rounds struck, into %s" % [_stills_taken, _hits, out])
		get_tree().quit(0)


func _process(_delta: float) -> void:
	if _t < 0.0 or _view == null or _camera == null:
		return
	if _eye:
		_caption.visible = false
		var current: Camera3D = get_viewport().get_camera_3d()
		if current != null and current != _camera:
			_eye_camera = current
		if _stills_taken == 0 and _t >= EYE_AT:
			_stills_taken = 1
			_still("pilot-eye")
		elif _stills_taken == 1 and _t >= EYE_AT + 0.4 and _eye_camera != null and _camera.get_parent() != _eye_camera:
			# THEN THE HEAD TIPPED 25 DEGREES DOWN from the same eye, to the screens under the sight line.
			_camera.fov = _eye_camera.fov
			_camera.reparent(_eye_camera, false)
			_camera.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-25.0)), Vector3.ZERO)
			_camera.make_current()
		if _stills_taken == 1 and _t >= EYE_AT + 0.8:
			_stills_taken = 2
			_still("pilot-eye-screens")
		elif _lamp and _stills_taken == 2 and _t >= EYE_AT + 1.2:
			# THEN THE HEAD TURNED TO THE HOLSTER, from the same eye: the lamp a little left of the middle of the frame, so
			# the canopy's sill and glass beside it are in the picture too.
			var lamp: SignalLamp = SignalLamp.in_station(_view.station_for(0))
			_camera.fov = 70.0
			_camera.look_at(lamp.global_position + _view.global_basis * Vector3(0.10, -0.02, 0.0), _view.global_basis.y)
			_stills_taken = 3
		elif _stills_taken == 3 and _t >= EYE_AT + 1.6:
			_stills_taken = 4
			_still("pilot-eye-lamp-holstered")
		return
	# THE CAMERA, re-taken every frame: the seated rig makes its own camera current (`modelling_here.md`, the hangar trap).
	var frame: Transform3D = _view.global_transform
	for sight in _view.find_children("*", "LockSight", true, false):
		(sight as Node3D).visible = false
	if _t < LEVEL_UNTIL:
		# BESIDE AND BELOW, gear up in flight: the mains half out of their pods.
		_aim(frame * Vector3(-14.0, -3.0, -2.0), frame * Vector3(0.0, -0.5, -1.0), frame.basis.y)
	elif _t < FIRE_AT + 0.9:
		# CLOSE ON THE NOSE from low and to port, the GAU-8's barrels in frame.
		_aim(frame * Vector3(-4.0, -1.6, -13.5), frame * Vector3(0.0, -0.3, -7.0), frame.basis.y)
	elif _t < FIRE_AT + 2.0:
		# OVER THE SHOULDER, the tracers streaming out ahead to the target.
		_aim(frame * Vector3(3.5, 3.5, 16.0), frame * Vector3(0.0, -0.4, -60.0), frame.basis.y)
	elif _t < PULL_AT + 1.0 and _target != 0:
		# AT THE TARGET, as a gun camera sees it: up the line of fire from the tank, above it and a little to one side,
		# looking down on it, so the tracers run away from the lens and into the target. From beside the tank, and then from
		# downrange, the streaks crossing the frame read as rounds going somewhere else (they were within 1.5 m of the
		# server's rounds' paths, measured with `--trace`).
		var side: Vector3 = _target_along.cross(Vector3.UP).normalized()
		_aim(_target_at - _target_along * 70.0 + side * 12.0 + Vector3.UP * 40.0, _target_at, Vector3.UP)
	else:
		_aim(frame * Vector3(-8.0, 3.0, 22.0), frame * Vector3(0.0, 0.0, -20.0), frame.basis.y)
	var rounds: int = int(Sim.client.gun_rounds(_view.entity)) if Sim.client.has_method("gun_rounds") else -1
	var height: float = _view.global_position.y
	_caption.text = "A-10C  GAU-8/A   %4.1f s   dive %+5.1f deg   height %5.0f m   drum %4d   barrels %3.0f%%   rounds struck %d" % [
		_t, rad_to_deg(asin(clampf((-_view.global_basis.z).y, -1.0, 1.0))), height, rounds,
		_view.warthog_gun_spin() * 100.0, _hits]
	if _stills_taken < STILLS.size() and _t >= float(STILLS[_stills_taken][0]):
		var name: String = String(STILLS[_stills_taken][1])
		_stills_taken += 1
		_still(name)


func _aim(from: Vector3, at: Vector3, up: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(at, up)
	_camera.make_current()


## THE TARGET WHERE THE ROUNDS MEET THE GROUND: the first round of the burst with this client's name on it, followed out
## along its own velocity -- the bore's direction at 1,013 m/s PLUS the aeroplane's own, which is why the first reel,
## which placed the tank on the bore line itself, watched every round go over it -- until it is under the ground or the
## sea, and a tank there on land or a gunboat on the water. Placed on the tick the first round exists; it arrives about
## half a second later.
func _place_the_target() -> void:
	var first: Dictionary = {}
	for row in Sim.server.shot_states():
		if int((row as Dictionary).get("shooter", -1)) == Sim.local_client_id():
			first = row
			break
	if first.is_empty():
		return
	var at: Vector3 = first["from"]
	var along: Vector3 = (first["velocity"] as Vector3).normalized()
	_target_along = Vector3(along.x, 0.0, along.z).normalized()
	for i in range(600):
		at += along * 5.0
		if at.y <= maxf(Terrain.ground_height(at), 0.0):
			break
	var ground: float = Terrain.ground_height(at)
	# A TANK ON FLAT GROUND, A GUNBOAT ON THE SEA, AND THE CONTROL TOWER ON A SLOPE: an unmanned tank is not chocked, and
	# the first reels' tank, put on a mountainside, slid thirty metres down it while the burst was in the air, so the
	# rounds that had struck it went on landing where it had been.
	var slope: float = 0.0
	for d in [Vector3(4, 0, 0), Vector3(-4, 0, 0), Vector3(0, 0, 4), Vector3(0, 0, -4)]:
		slope = maxf(slope, absf(Terrain.ground_height(at + d) - ground) / 4.0)
	var kind: int = Sim.Kind.GUNBOAT if ground <= 0.5 else (Sim.Kind.TANK if slope < 0.12 else Sim.Kind.TOWER)
	var hy: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	_target_at = Vector3(at.x, maxf(ground, 0.0) + (hy if kind != Sim.Kind.GUNBOAT else 0.0), at.z)
	_target = int(Sim.server.spawn_vehicle(kind, _target_at, atan2(-along.x, -along.z) + PI * 0.5, Vector3.ZERO))
	print("[warthog_reel] target %s placed %.0f m down the first round's path, at %s" % [Sim.kind_name(kind),
		(first["from"] as Vector3).distance_to(_target_at), _target_at])


## `--trace`: how far each tracer the level draws is from the nearest of this client's live server rounds' paths (each a
## ray from its birth along its velocity; gravity and drag bend it by under a metre in the first half second).
func _trace_tracers() -> void:
	var rays: Array = []
	for row in Sim.server.shot_states():
		var shot: Dictionary = row
		if int(shot.get("shooter", -1)) == Sim.local_client_id() and int(shot.get("surface", 0)) == 0:
			rays.append([shot["from"], (shot["velocity"] as Vector3).normalized()])
	var said: PackedStringArray = []
	var count: int = 0
	for node in _level.shots.get_children():
		if not (node is MeshInstance3D and (node as MeshInstance3D).visible):
			continue
		count += 1
		var p: Vector3 = (node as Node3D).global_position
		var near: float = INF
		for r in rays:
			var o: Vector3 = r[0]
			var d: Vector3 = r[1]
			var t: float = maxf((p - o).dot(d), 0.0)
			near = minf(near, (o + d * t).distance_to(p))
		if said.size() < 6:
			said.append("%.1f" % near)
	print("[warthog_reel] t %.2f: %d tracers drawn, %d live rounds; each tracer's distance from the nearest round's path (m): %s"
		% [_t, count, rays.size(), ", ".join(said)])


func _count_hits() -> void:
	for row in Sim.server.shot_states():
		var shot: Dictionary = row
		var entity: int = int(shot.get("entity", 0))
		if _seen.has(entity) or int(shot.get("shooter", -1)) != Sim.local_client_id():
			continue
		# A ROUND STILL FLYING has surface 0 and an impact of zero; only an ENDED one (the ground, the water, a craft) is
		# counted, and a strike is one that ended on a craft within 12 m of the target.
		var surface: int = int(shot.get("surface", 0))
		if surface == 0:
			continue
		_seen[entity] = true
		var impact: Vector3 = shot.get("impact", Vector3.INF)
		if _seen.size() <= 4:
			print("[warthog_reel] round %d ended on surface %d at %s, %.1f m from the target" % [entity, surface, impact,
				impact.distance_to(_target_at)])
		if _target != 0 and surface == 3 and impact.distance_to(_target_at) < 12.0:
			_hits += 1


func _press_key(action: String, down: bool) -> void:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			var press := InputEventKey.new()
			press.keycode = code
			press.physical_keycode = code
			press.pressed = down
			Input.parse_input_event(press)
			return


func _still(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = out.path_join("warthog-reel-%s.png" % name)
	get_viewport().get_texture().get_image().save_png(path)
	print("[warthog_reel] still %s" % path)

