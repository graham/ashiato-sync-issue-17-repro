extends Node
## THE PIRATE SHIP, PHOTOGRAPHED: close at the waterline, on a beam reach, from astern running, mid-tack, from 2 km up, and
## at dusk, on each finish.
##
##   Godot --path cockpit --fixed-fps 120 res://tests/pirate_shot.tscn -- --level=watch --out=C:/somewhere
##   Godot --path cockpit --fixed-fps 120 res://tests/pirate_shot.tscn -- --level=watch --views=waterline --finishes=plain
##   Godot --path cockpit --fixed-fps 120 res://tests/pirate_shot.tscn -- --level=watch --views=waterline --shadows=off
##   Godot --path cockpit --fixed-fps 120 res://tests/pirate_shot.tscn -- --level=watch --views=mid_tack,tack_later --finishes=plain
##   Godot --path cockpit --fixed-fps 120 res://tests/pirate_shot.tscn -- --level=watch --views=sea_low_evening --finishes=fine --scale=1.4 --shadows=off --ground=off
##
## `--shadows=off` turns every sun's shadow off, to tell a shadow on a sail from anything else. `tack_later` is the
## tacking ship six seconds after `mid_tack`'s head to wind, asked for after it in the same launch and on one finish.
##
## NOT HEADLESS -- it renders; headless draws black rectangles. A PROBE: a picture has no assertion, and whether the sails
## read as sails and the hull sits in the sea is for eyes. What it does check is that it photographed what it meant to:
## each ship is where it was sent, on the point of sail asked for, and the finish the key put on is the finish every
## surface wears.
##
## THE SHIPS ARE THE SERVER'S, sailed by their own helmsmen (`hold_course`) in a steady ten-metre wind, far out on the sea's
## negative side, where the drawn swell and the simulated swell disagreed before the wrap was fixed -- so a "before" and
## an "after" picture at the waterline are of the same water. A ship is followed by the observer's camera every frame
## (`_process`), placed off the ship's own drawn pose, so a picture of a moving ship is not a picture of where it was.
##
## THE FINISH IS CHANGED BY ITS KEY through `Input.parse_input_event`, as `tests/scenery_shot.gd` does, never by a call.

const WIND: float = 10.0
const FROM: float = 0.0
## Where the ships sail: far past the island's square on the negative side of both axes.
const SEA := Vector3(-11000.0, 0.0, -11000.0)
## How long the ships sail before the first picture, so each is settled on its point of sail, heeled and making way.
const SAIL_FIRST: float = 70.0
## Frames a finish is given to compile its pipelines before a picture.
const SETTLE: int = 90
const VIEWS: Array[String] = ["waterline", "beam_reach", "running_astern", "mid_tack", "two_km", "dusk"]

var _out: String = "C:/Users/Graham/godotgames-drafts/2026-09-15/cockpit-pirate"
var _tag: String = ""
var _views: Array[String] = []
var _finishes: Array[String] = ["plain", "fine"]
var _level: FlightLevel = null
var _failures: PackedStringArray = []
## Server entity of each ship, by what it is for.
var _ships: Dictionary = {}
## The view being followed this frame, and the pose worked out for it off the ship's drawn transform.
var _following: String = ""
## `--shadows=off`: every DirectionalLight3D in the level draws no shadow, to tell a shadow on a sail from anything else.
var _shadows: bool = true
## How long after head to wind `tack_later` is taken: the square yards have swung through and the sails are filling on
## the new tack (the tack table in tests/sailing.gd: at 21 s the main is across and the fore still aback).
const TACK_LATER_SECONDS: float = 6.0
## MIST'S sea_low POSE (cockpit-mist, 2026-09-15): 400 m off the island's edge on z = 0, 14 m up, looking east and 11.3
## degrees down. From there mist saw a vertical seam down PLAIN's water (the world line z = 0) and a dark straight-edged
## wedge in FINE's evening water, with and without the mist. A fixed camera: it follows no ship.
const SEA_LOW_EYE := Vector3(7600.0, 14.0, 0.0)
const SEA_LOW_AT := Vector3(7670.0, 0.0, 0.0)
## `--scale=`: the 3D render scale, or -1 to leave the viewport's own. Mist's pictures were at 1.40.
var _scale: float = -1.0
## `--ground=off`: every node named Ground or TerrainPatch is hidden, to tell the ground's shadow on the sea from the sea.
var _ground: bool = true


func _check(label: String, ok: bool, detail: String) -> void:
	print("[pirate_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_views.assign(VIEWS)
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"out": _out = parts[1]
			"tag": _tag = "-" + parts[1]
			"views": _views.assign(Array(parts[1].split(",", false)))
			"finishes": _finishes.assign(Array(parts[1].split(",", false)))
			"shadows": _shadows = parts[1] != "off"
			"scale": _scale = float(parts[1])
			"ground": _ground = parts[1] != "off"
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null or Sim.server == null:
		_check("there_is_a_server_and_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	if _scale > 0.0:
		get_viewport().scaling_3d_scale = _scale
	if not _ground:
		# `Ground` is the island's slab and `GroundView` the generated ground's (sky.gd); TerrainPatch the probes' own.
		for node in _level.find_children("Ground*", "Node3D", true, false) + _level.find_children("TerrainPatch*", "Node3D", true, false):
			(node as Node3D).visible = false
			print("[pirate_shot] ground off: hid %s" % node.get_path())
	if not _shadows:
		for light in _level.find_children("*", "DirectionalLight3D", true, false):
			(light as DirectionalLight3D).shadow_enabled = false
		print("[pirate_shot] shadows off on every DirectionalLight3D")
	for world in [Sim.server, Sim.client]:
		if world != null:
			world.set_weather({"from": FROM, "low": WIND, "high": WIND, "veer": 0.0, "seed": 1})
	# THE SHIPS: a beam reach, a run, and one close-hauled that will be put about, each a kilometre apart.
	_ships["beam"] = _sail(SEA, FROM - PI * 0.5)
	_ships["run"] = _sail(SEA + Vector3(1000.0, 0.0, 0.0), FROM - PI)
	_ships["tack"] = _sail(SEA + Vector3(0.0, 0.0, 1000.0), FROM - deg_to_rad(65.0))
	for i in range(int(SAIL_FIRST * 120.0)):
		await get_tree().physics_frame
	for view in _views:
		for finish_name in _finishes:
			await _wear(finish_name)
			await _photograph(view, finish_name)
	_following = ""
	_finish()


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _sail(at: Vector3, heading: float) -> int:
	var nose := Vector3(sin(heading), 0.0, -cos(heading))
	var ship: int = Sim.spawn_ai_vehicle(Sim.Kind.PIRATE, at, -heading, nose * 3.0)
	Sim.server.hold_course(ship, heading)
	return ship


## THE SHIP ON THIS MACHINE'S CLIENT for a server ship: entity ids are per world, so it is the pirate drawn nearest the
## server's position.
func _drawn(server_ship: int) -> int:
	var truth: Vector3 = (Sim.server.vehicle_state(server_ship) as Dictionary).get("position", Vector3.ZERO)
	var best: int = 0
	var nearest: float = INF
	for entity in Sim.current:
		var state: Dictionary = Sim.current[entity]
		if int(state.get("kind", -1)) != Sim.Kind.PIRATE:
			continue
		var apart: float = ((state["position"] as Vector3) - truth).length()
		if apart < nearest:
			nearest = apart
			best = int(entity)
	return best


func _photograph(view: String, finish_name: String) -> void:
	var ship: int = _ship_for(view)
	if view == "dusk" or view == "sea_low_evening":
		_level.call("choose_time", DaylightTuning.When.EVENING)
	if view == "mid_tack":
		# PUT ABOUT, and wait for the bow to be within a few degrees of the wind: the picture is head to wind.
		var heading: float = FROM + deg_to_rad(65.0)
		Sim.server.hold_course(ship, heading)
		var waited: int = 0
		while waited < 120 * 60:
			await get_tree().physics_frame
			waited += 1
			var basis: Quaternion = (Sim.server.vehicle_state(ship) as Dictionary)["basis"]
			var nose: Vector3 = basis * Vector3.FORWARD
			if absf(wrapf(atan2(nose.x, -nose.z) - FROM, -PI, PI)) < deg_to_rad(4.0):
				break
		_check("the_tacking_ship_is_head_to_wind", waited < 120 * 60, "after %.1f s" % (waited / 120.0))
	if view == "tack_later":
		# ASKED AFTER mid_tack in the same launch: the ship is already put about and past head to wind.
		for i in range(int(TACK_LATER_SECONDS * 120.0)):
			await get_tree().physics_frame
	_following = view
	for i in range(SETTLE):
		await get_tree().process_frame
	var report: Dictionary = Sim.server.sail_report(ship)
	print("[pirate_shot] %s %s: way %.2f m/s, heel %.1f deg, apparent %.0f deg, fill %s" % [view, finish_name,
		float(report.get("way", 0.0)), rad_to_deg(float(report.get("heel", 0.0))),
		rad_to_deg(float(report.get("apparent_angle", 0.0))), report.get("fill", [])])
	# WHERE EVERYTHING IS, beside the picture, so a hull that looks wrong against the water can be told apart from a camera
	# that is: the ship as drawn, the camera, and both seas' nodes.
	var drawn_ship: int = _drawn(ship)
	var sea := _level.get_node_or_null("Sea") as Node3D
	var swell := _level.get("swell") as Node3D
	print("[pirate_shot] %s %s: ship drawn at y %.2f, camera at y %.2f, plain sea node y %s, fine sea node y %s" % [view,
		finish_name, Sim.vehicle_transform(drawn_ship).origin.y, _level.observer.global_position.y,
		"%.2f (visible %s)" % [sea.global_position.y, sea.is_visible_in_tree()] if sea != null else "none",
		"%.2f (visible %s)" % [swell.global_position.y, swell.is_visible_in_tree()] if swell != null else "none"])
	var path: String = "%s/pirate-%s-%s%s.png" % [_out, view, finish_name, _tag]
	var saved: int = get_viewport().get_texture().get_image().save_png(path)
	_check("saved_%s_%s" % [view, finish_name], saved == OK, path)
	_following = ""
	if view == "dusk" or view == "sea_low_evening":
		_level.call("choose_time", DaylightTuning.When.DAY)


## THE CAMERA, every frame, off the ship's drawn transform: the ship moves, and a pose worked out once is a pose of
## where it was.
func _process(_delta: float) -> void:
	if _following == "" or _level == null:
		return
	if _following == "sea_low" or _following == "sea_low_evening":
		_place(SEA_LOW_EYE, SEA_LOW_AT)
		return
	var ship: int = _ship_for(_following)
	var drawn: int = _drawn(ship)
	if drawn == 0:
		return
	var pose: Transform3D = Sim.vehicle_transform(drawn)
	var at: Vector3 = pose.origin
	# FLAT, or a heeled ship tips the camera into the sea: at -7.6 degrees of heel the ship's right axis rises 0.13 a metre,
	# and 70 m to leeward along it put the beam-reach camera 9.3 m lower, just under the water (the first "before" set).
	var right: Vector3 = Vector3(pose.basis.x.x, 0.0, pose.basis.x.z).normalized()
	var aft: Vector3 = Vector3(pose.basis.z.x, 0.0, pose.basis.z.z).normalized()
	match _following:
		"waterline":
			_place(at + right * 14.0 + aft * 4.0 + Vector3(0.0, 1.2, 0.0), at + aft * 2.0)
		"beam_reach", "dusk":
			# From leeward, where the heel lays the deck and the full sails towards the camera.
			_place(at - right * 70.0 + Vector3(0.0, 9.0, 0.0), at + Vector3(0.0, 9.0, 0.0))
		"running_astern":
			_place(at + aft * 90.0 + right * 12.0 + Vector3(0.0, 12.0, 0.0), at + Vector3(0.0, 10.0, 0.0))
		"mid_tack", "tack_later":
			_place(at + right * 60.0 - aft * 40.0 + Vector3(0.0, 14.0, 0.0), at + Vector3(0.0, 10.0, 0.0))
		"two_km":
			_place(at + Vector3(1400.0, 1200.0, 900.0), at)


## Which ship a view photographs: the one put about for the tack's two views, the run from astern, the beam reach else.
func _ship_for(view: String) -> int:
	if view == "mid_tack" or view == "tack_later":
		return _ships["tack"]
	return _ships["run"] if view == "running_astern" else _ships["beam"]


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


## THE FINISH, BY ITS KEY, and every surface asked what it wears. The same as `tests/scenery_shot.gd`'s.
func _wear(finish_name: String) -> void:
	var finish: Node = get_node_or_null("/root/Finish")
	if finish == null:
		return
	var fine: bool = finish_name == "fine"
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
	get_viewport().msaa_3d = finish.call("multisampling")
	_check("the_key_put_on_%s" % finish_name, bool(finish.call("is_fine")) == fine, "fine is %s" % finish.call("is_fine"))
