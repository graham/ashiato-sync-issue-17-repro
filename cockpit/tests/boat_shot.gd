extends Node
## A SMALL BOAT DRIVEN HARD, PHOTOGRAPHED: flat out and then hard over, on open sea in the watch level, seen from a chase
## camera that rides the boat's heading but not its roll, so a lean into the turn reads against the horizon.
##
##   Godot --path cockpit --resolution 1600x900 res://tests/boat_shot.tscn -- --level=watch --clouds=none --kind=boat
##   ... -- --level=watch --clouds=none --kind=gunboat --views=straight,turn,turn_side --before --out=C:/somewhere
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device. How far a boat leans, how fast it goes and
## whether it stays upright are held headless by `tests/handling.gd`; this is what that looks like from outside.
##
## DRIVEN THROUGH THE REAL CONTROLS: a pilot is spawned in the kind with `spawn_pilot` and its control frame is written
## every physics frame with `set_pilot_input`, the frame a seated player's rig sends (throttle on the lever, the helm on
## the rudder).
##
## `--before` retunes the kind to the numbers it had before lane/boats (2026-09-18) through `Sim.set_handling` before the
## boat is spawned, so the before and after are the same probe, the same sea and the same camera, and differ only in the
## handling. `BEFORE` is copied from main at efb2ef3d's `default_handling`.
##
##   straight     flat out, from astern and a little above, level with the horizon.
##   turn         hard over at full speed, from astern: the lean shows as the hull tilted against the horizon.
##   turn_side    the same turn from abeam on the outside, low: the lean shows as the deck turned toward the camera.
##   chase        flat out, a three-quarter chase from astern and to port, high enough to see the wall of spray behind.
##   broadside    flat out, from abeam and low: the hull's lines, the wheelhouse and what is on its roof.
##   reel         the chase camera from the first frame, and hard over for 5 s after the run-up: for `--write-movie`.
##   launch_ship  the same, at a patrol boat under way on the water ahead, on the radar row that sees ships.
##   dive         (lane/seakeep) flat out ALONG THE WIND-SEA (+X or -X, whichever leads away from the island), from a
##                camera abeam and ahead of the bow at a FIXED height over the sea, so the hull's heave and pitch read
##                against the water rather than riding with the lens. Without `--at=` it watches `DIVE_WINDOW` seconds
##                after the run-up and prints when the bow was deepest under the drawn sea; with `--at=T` it saves the
##                picture T seconds after the helm went to full throttle, so a before and an after are the same moment.
##                Filmed from the first frame, so it is also the reel under `--write-movie`.
##   launch       FOR A KIND THAT CARRIES MISSILES: an aircraft put ahead and above, the master arm and the selector thrown
##                and LOCK and LAUNCH pressed on the helm's own input frame, and the missile photographed leaving its box.
##
## Pictures go to `--out` (default `user://boat_shots`), `<kind>-<view>[-before].png`.

const OUT := "user://boat_shots"
const CLIENT: int = 203
## How long it runs flat out before the first picture, and how long it has been hard over at the turn pictures.
const RUN_UP: float = 12.0
const HARD_OVER: float = 4.0
## How close to where it was put a drawn craft of the kind must be to be this probe's boat, metres.
const FOUND_WITHIN: float = 20.0
## The handling each small boat had before lane/boats, for `--before`.
const BEFORE: Dictionary = {
	"boat": {"thrust": 7000.0, "hull_speed": 14.0, "wave_drag": 400.0, "lean": 0.0, "bow_rise": 0.0},
	"gunboat": {"thrust": 90000.0, "hull_speed": 18.0, "wave_drag": 5000.0, "water_drag": 140000.0, "keel_limit": 200000.0,
		"rudder_force": 34.0, "lean": 0.0, "bow_rise": 0.0},
}

var _level: FlightLevel = null
var _out: String = OUT
var _kind_name: String = "boat"
var _views: PackedStringArray = ["straight", "turn", "turn_side"]
var _seq: int = 0
var _before: bool = false
var _failures: PackedStringArray = []
var _pilot: int = 0
var _input: Dictionary = {}
var _ship: VehicleView = null
var _from_local: Vector3 = Vector3.ZERO
var _toward_local: Vector3 = Vector3.ZERO
## `dive`: the camera's height is the sea's, not the boat's, and the moment to save at (-1 watches instead).
var _level_camera: bool = false
var _at: float = -1.0
## `--throttle=`: the lever through the run, 1 unless told (0 photographs a ship lying stopped).
var _throttle: float = 1.0
## `--eye=`: how high over the sea `dive`'s camera stands, metres. A low eye looks across the near crests, which can hide a
## small hull that is not under at all (the launch's first after picture).
var _eye: float = 1.8
## How long `dive` watches after the run-up, seconds.
const DIVE_WINDOW: float = 20.0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[boat_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument == "--before":
			_before = true
			continue
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"kind":
				_kind_name = parts[1]
			"views":
				_views = parts[1].split(",", false)
			"out":
				_out = parts[1]
			"at":
				_at = float(parts[1])
			"throttle":
				_throttle = float(parts[1])
			"eye":
				_eye = float(parts[1])
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().scaling_3d_scale = PilotRig.RENDER_SCALE
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	await _frames(60)
	# THE OBSERVER STANDS DOWN: it chases a craft of its own every frame (the level reads `--kind=` too, and chose one),
	# and its `_process` ran after this probe's and put the camera back behind a launch moored in the bay. Every overlay
	# hidden with it, its board included (ocean_shot's lesson).
	_level.observer.set_process(false)
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var kind: int = Sim.Kind.get(_kind_name.to_upper(), -1)
	_check("the_kind_is_known", kind >= 0, _kind_name)
	if kind < 0:
		_finish()
		return
	if _before:
		_check("there_are_before_numbers", BEFORE.has(_kind_name), _kind_name)
		Sim.set_handling(kind, BEFORE.get(_kind_name, {}))
	# OPEN SEA, clear of the island and of anything moored there.
	var sea: Vector3 = Terrain.open_sea_near(Vector3.ZERO, 20.0)
	_check("there_is_open_sea", sea != Vector3.INF, "")
	if sea == Vector3.INF:
		_finish()
		return
	var outward: Vector3 = Vector3(sea.x, 0.0, sea.z).normalized()
	var along: Vector3 = outward.cross(Vector3.UP).normalized()
	var start: Vector3 = sea + outward * 700.0
	if "dive" in _views:
		along = Vector3(1.0 if start.x >= 0.0 else -1.0, 0.0, 0.0)
	var made: Dictionary = Sim.server.spawn_pilot(CLIENT, kind, start, atan2(-along.x, -along.z), Vector3.ZERO)
	_pilot = int(made.get("pilot", 0))
	_check("a_pilot_is_at_the_helm", _pilot != 0, str(made))
	_input = _controls({"throttle": _throttle})
	# THE BOAT THIS PILOT IS IN: the one of its kind drawn within `FOUND_WITHIN` of where it was put. NOT the id
	# `spawn_pilot` returns, which is the server's and names some other craft on the client (the second draft followed an
	# AI launch cruising at 15.3 m/s under that id); and not merely the nearest thing drawn, which the first draft took
	# half a second in and which can be a craft moored there before this one reaches the client.
	var craft: int = 0
	for i in range(600):
		await get_tree().physics_frame
		craft = _drawn_near(start, kind)
		if craft != 0 and _level.view_of(craft) != null:
			break
	_ship = _level.view_of(craft) if craft != 0 else null
	_check("the_boat_is_drawn", _ship != null, "entity %d" % craft)
	if _ship == null:
		_finish()
		return
	var half: Vector3 = Sim.geometry_of(kind).get("extents", Vector3.ONE)
	var length: float = half.z * 2.0
	# A REEL: the chase camera from the first frame, so a run under `--write-movie` is one continuous shot of the boat
	# getting onto the plane, running flat out, and hard over, before whatever views follow.
	if "reel" in _views:
		_from_local = Vector3(-(length * 0.9 + 6.0), length * 0.45 + 3.0, length * 1.7 + 10.0)
		_toward_local = Vector3(0.0, 1.0, -length * 0.2)
	if "dive" in _views:
		await _dive(kind, length)
		_finish()
		return
	await _seconds(RUN_UP)
	if "reel" in _views:
		# HARD TO PORT, toward the camera's side, so the wall trails away from the lens rather than between it and the boat.
		_input = _controls({"throttle": 1.0, "rudder": -1.0})
		await _seconds(5.0)
		_input = _controls({"throttle": 1.0})
		await _seconds(4.0)
	var suffix: String = "-before" if _before else ""
	if "chase" in _views:
		_from_local = Vector3(-(length * 0.9 + 6.0), length * 0.45 + 3.0, length * 1.7 + 10.0)
		_toward_local = Vector3(0.0, 1.0, -length * 0.2)
		await _frames(4)
		_report("chase")
		await _save("%s-chase%s" % [_kind_name, suffix])
	if "broadside" in _views:
		_from_local = Vector3(-(length * 1.4 + 8.0), 2.5, 0.0)
		_toward_local = Vector3(0.0, 1.5, 0.0)
		await _frames(4)
		_report("broadside")
		await _save("%s-broadside%s" % [_kind_name, suffix])
	if "launch" in _views:
		await _a_launch(kind, length, suffix)
	if "launch_ship" in _views:
		await _a_launch(kind, length, suffix, true)
	if "straight" in _views:
		_from_local = Vector3(length * 0.35, length * 0.35 + 1.5, length * 2.2 + 6.0)
		_toward_local = Vector3(0.0, 0.5, -length * 0.3)
		await _frames(4)
		_report("straight")
		await _save("%s-straight%s" % [_kind_name, suffix])
	_input = _controls({"throttle": 1.0, "rudder": 1.0})
	await _seconds(HARD_OVER)
	if "turn" in _views:
		_from_local = Vector3(0.0, length * 0.25 + 1.2, length * 2.0 + 6.0)
		_toward_local = Vector3(0.0, 0.8, -length * 0.3)
		await _frames(4)
		_report("turn")
		await _save("%s-turn%s" % [_kind_name, suffix])
	if "turn_side" in _views:
		# ON THE OUTSIDE of a turn to the right and a little AHEAD, the camera on the boat's left and 5 m up: abeam and
		# 2 m up, the CB90's first picture was taken from under a swell, and astern it was inside its own wall of spray.
		_from_local = Vector3(-(length * 1.6 + 8.0), 5.0, -length * 0.6)
		_toward_local = Vector3(0.0, 1.0, 0.0)
		await _frames(4)
		_report("turn_side")
		await _save("%s-turn_side%s" % [_kind_name, suffix])
	_finish()


## What the boat is doing at the picture, in the words `handling.gd` uses: positive bank is the right side down, and a
## turn to the right leans INTO it when the bank is positive.
func _report(view: String) -> void:
	var state: Dictionary = Sim.current.get(_ship.entity, {})
	var b := Basis(state.get("basis", Quaternion()) as Quaternion)
	var right: Vector3 = b * Vector3.RIGHT
	var nose: Vector3 = b * Vector3.FORWARD
	print("[boat_shot] %s %s%s: %.1f m/s, bank %+.1f deg (right side down is +), pitch %+.1f deg, spraying %.2f, wall %.1f m" % [
		_kind_name, view, " (before)" if _before else "", (state.get("velocity", Vector3.ZERO) as Vector3).length(),
		rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))), rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		_level.spray.strength_of(_ship.entity), _level.spray.wall_height_of(_ship.entity)])


## A MISSILE, LOCKED AND LAUNCHED THROUGH THE HELM: an aircraft ahead of the boat and above it, the master arm and the
## radar station thrown as bus commands on the frame, LOCK held until the simulation says locked, LAUNCH pressed, and the
## picture from astern and above as the missile leaves the box.
func _a_launch(kind: int, length: float, suffix: String, at_a_ship: bool = false) -> void:
	var stations: Array = Sim.missile_schema(kind).get("stations", []) as Array
	_check("the_%s_carries_missiles" % _kind_name, not stations.is_empty(), "")
	if stations.is_empty():
		return
	# THE RADAR STATION, whichever radar row the kind carries: the light twin's, or the CB90's that also sees ships.
	var radar: int = 0
	for entry in stations:
		if String((entry as Dictionary).get("name", "")).ends_with("radar"):
			radar = int(entry.get("station", 0))
	var pose: Transform3D = _ship.global_transform
	var ahead: Vector3 = -pose.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var at: Vector3 = pose.origin + ahead * 1400.0 + Vector3.UP * 520.0
	if at_a_ship:
		# A PATROL BOAT ON THE WATER, 900 m ahead and running across the bow.
		var across: Vector3 = ahead.cross(Vector3.UP)
		at = Vector3(pose.origin.x, 0.0, pose.origin.z) + ahead * 900.0
		Sim.server.spawn_vehicle(Sim.Kind.GUNBOAT, at, atan2(-across.x, -across.z), across * 12.0)
	else:
		Sim.server.spawn_vehicle(Sim.Kind.PLANE, at, atan2(-ahead.x, -ahead.z), ahead * 55.0)
	_command(Sim.Channel.MASTER, 1)
	await _seconds(0.2)
	_command(Sim.Channel.WEAPON, radar)
	await _seconds(0.2)
	_input["buttons"] = Sim.BUTTON_LOCK
	await _seconds(0.1)
	_input["buttons"] = 0
	var phase: String = ""
	for i in range(360):
		await get_tree().physics_frame
		for row in Sim.server.lock_states():
			if int((row as Dictionary).get("client", -1)) == CLIENT:
				phase = String(row.get("phase_name", ""))
		if phase == "locked":
			break
	_check("the_helm_locks_the_%s" % ("ship" if at_a_ship else "aircraft"), phase == "locked", "phase %s" % phase)
	_input["buttons"] = Sim.BUTTON_LAUNCH
	await _seconds(0.1)
	_input["buttons"] = 0
	await _seconds(0.45)
	_check("a_missile_is_flying", not (Sim.server.missile_states() as Array).is_empty(), "")
	_from_local = Vector3(-(length * 0.5 + 3.0), length * 0.25 + 4.0, length * 1.1 + 6.0)
	_toward_local = Vector3(0.0, 9.0, -length * 1.2)
	await _frames(3)
	if at_a_ship:
		# LOW AND ASTERN, the camera looking over the wheelhouse at the ship the missile is going for.
		await _seconds(0.9)
		_from_local = Vector3(-(length * 0.4 + 2.0), length * 0.2 + 3.0, length * 1.3 + 8.0)
		_toward_local = Vector3(0.0, 2.0, -length * 6.0)
		await _frames(3)
	_report("launch_ship" if at_a_ship else "launch")
	await _save("%s-%s%s" % [_kind_name, "launch_ship" if at_a_ship else "launch", suffix])


## FLAT OUT ALONG THE WIND-SEA, watched from abeam and ahead at the sea's own height (lane/seakeep). The bow's depth under
## the DRAWN sea is read as `tests/seakeeping.gd` reads it: the hull part's bow corner at its top, against
## `swell_height_at` there.
func _dive(kind: int, length: float) -> void:
	_level_camera = true
	_from_local = Vector3(-(length * 0.8 + 4.0), _eye, -length * 0.5)
	_toward_local = Vector3(0.0, 0.6, -length * 0.1)
	var bow := Vector3(0.0, 1.0, -length * 0.5)
	for part in (Sim.geometry_of(kind).get("parts", []) as Array):
		if String((part as Dictionary).get("part", "")) == "hull":
			var front: float = INF
			for c in ((part as Dictionary)["outline"] as PackedVector2Array):
				front = minf(front, c.y)
			bow = Vector3(0.0, float((part as Dictionary)["top"]), front)
	var gone: float = 0.0
	var worst: float = -INF
	var worst_at: float = 0.0
	var end: float = _at if _at >= 0.0 else RUN_UP + DIVE_WINDOW
	while gone < end:
		await get_tree().physics_frame
		gone += get_physics_process_delta_time()
		var state: Dictionary = Sim.current.get(_ship.entity, {})
		if state.is_empty():
			continue
		var pose := Transform3D(Basis(state.get("basis", Quaternion()) as Quaternion), state.get("position", Vector3.ZERO) as Vector3)
		var p: Vector3 = pose * bow
		var under: float = float(Sim.server.swell_height_at(p.x, p.z)) - p.y
		if gone > RUN_UP and under > worst:
			worst = under
			worst_at = gone
	if _at < 0.0:
		print("[boat_shot] %s dive: deepest bow %.2f m under the drawn sea at %.2f s (watched %.0f-%.0f s)" % [
			_kind_name, worst, worst_at, RUN_UP, RUN_UP + DIVE_WINDOW])
		return
	_report("dive")
	var state_now: Dictionary = Sim.current.get(_ship.entity, {})
	var pose_now := Transform3D(Basis(state_now.get("basis", Quaternion()) as Quaternion), state_now.get("position", Vector3.ZERO) as Vector3)
	var q: Vector3 = pose_now * bow
	print("[boat_shot] %s dive at %.2f s: bow %.2f m under the drawn sea" % [_kind_name, gone,
		float(Sim.server.swell_height_at(q.x, q.z)) - q.y])
	await _save("%s-dive-%s%s" % [_kind_name, str(snappedf(_at, 0.01)).replace(".", "_"), "-before" if _before else ""])


## A BUS COMMAND on a new sequence number, never 0 (`tests/handling.gd`, `_command`).
func _command(channel: int, value: int) -> void:
	_seq = _seq % 3 + 1
	_input["command_channel"] = channel
	_input["command_value"] = value
	_input["command_seq"] = _seq


func _physics_process(_delta: float) -> void:
	if _pilot != 0 and not _input.is_empty():
		Sim.server.set_pilot_input(_pilot, _input)


func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input


## The entity of `kind` drawn within FOUND_WITHIN of `near`, or 0.
func _drawn_near(near: Vector3, kind: int) -> int:
	for entity in Sim.current:
		var state: Dictionary = Sim.current[entity]
		if int(state.get("kind", -1)) == kind and (state.get("position", Vector3.ZERO) as Vector3).distance_to(near) < FOUND_WITHIN:
			return int(entity)
	return 0


## THE CAMERA, re-placed every frame in a LEVEL frame that turns with the boat's heading and never rolls with it.
func _process(_delta: float) -> void:
	if _level == null or _level.observer == null or _ship == null or not is_instance_valid(_ship):
		return
	# NOT UNTIL THE FIRST VIEW HAS PLACED IT: an eye on its own target is an engine error every frame.
	if _from_local.is_equal_approx(_toward_local):
		return
	var eye: Camera3D = _level.observer
	eye.fov = 50.0
	var pose: Transform3D = _ship.global_transform
	var ahead: Vector3 = -pose.basis.z
	var level := Basis.looking_at(Vector3(ahead.x, 0.0, ahead.z).normalized(), Vector3.UP)
	var frame := Transform3D(level, Vector3(pose.origin.x, 0.0, pose.origin.z) if _level_camera else pose.origin)
	eye.global_transform = Transform3D(Basis.IDENTITY, frame * _from_local).looking_at(frame * _toward_local, Vector3.UP)


func _save(called: String) -> void:
	for i in range(6):
		await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(called + ".png")
	_check("saved_%s" % called, picture.save_png(path) == OK, ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _seconds(count: float) -> void:
	var gone: float = 0.0
	while gone < count:
		await get_tree().physics_frame
		gone += get_physics_process_delta_time()


func _finish() -> void:
	_ship = null
	_pilot = 0
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
