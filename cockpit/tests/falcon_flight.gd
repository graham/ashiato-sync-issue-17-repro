extends Node
## Headless: DOES THE F-16 FLY WELL, flown through a seated pilot's own control frame. Read RESULT=.
##
##   Godot --headless --path cockpit res://tests/falcon_flight.tscn
##
## THE USER'S STANDARD (2026-09-17): every craft must "look good and fly well and do the thing we want them to". For a
## fighter that is: it gets off a runway, it climbs, it is in the fighter's class for speed and NO FASTER (the world's
## soft edge is sized on the widest turn at the fastest wing's top speed, `lane/handling`), and it is the NIMBLE one --
## it rolls faster and pulls harder than the F/A-18F beside it, and holds its height in a hard turn.
##
## THROUGH THE REAL PATH. `set_pilot_input` is the frame the wire carries from a seated player's rig (stick as pitch and
## roll, rudder, the lever as throttle, a bus command beside them) -- the same frame `tests/handling.gd` flies every
## craft with, and nothing below it is called. The robot's hands are handling's: proportional loops, never tuned here.
##
## JUDGED AGAINST THE F/A-18F FLOWN THE SAME WAY in the same run, not against numbers typed from the F-16's own table:
## "rolls faster than the fighter" read off two aeroplanes is a claim about the aeroplanes; "rolls at roll_rate" read
## off the table the stick is scaled by would be the table agreeing with itself.
##
## AND THE SURFACES ARE SEEN TO MOVE WITH THE STICK: a `VehicleView` of the kind is handed a linkage with the stick over
## and back, as `draw` hands it one, and the drawn flaperons and stabilators are read back from their vertices.

const TICK: float = 1.0 / 120.0
const GROUND_HALF: float = 40000.0
const CLIENT: int = 60
const K_PITCH: float = 2.5
const K_BANK: float = 2.5
const K_HEADING: float = 1.2
const K_ALT: float = 0.25
const K_VY: float = 1.2
## The fighter's class, and the ceiling the world's edge puts on it (`cockpit/agents.md`, "THE FASTEST WING SIZES THE
## WORLD": alpine leaves room for the F/A-18F's 221 m/s and no more).
const TOP_SPEED: Vector2 = Vector2(200.0, 225.0)
## A 9 g aeroplane, pulled fully back for a second at speed.
const YANK_G: Vector2 = Vector2(8.5, 10.0)

var _world: Object = null
var _pilot: int = 0
var _craft: int = 0
var _h: Dictionary = {}
var _t: float = 0.0
var _seq: int = 0
var _input: Dictionary = {}
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[falcon_flight] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	var falcon: Dictionary = _fly(Sim.Kind.FALCON)
	var fighter: Dictionary = _fly(Sim.Kind.FIGHTER)
	_end()
	print("[falcon_flight] falcon  %s" % falcon)
	print("[falcon_flight] fighter %s" % fighter)
	_check("it_gets_off_a_runway_and_climbs", float(falcon.get("lift_m", INF)) < 250.0
		and float(falcon.get("climb", 0.0)) > 20.0,
		"off the ground in %.0f m, climbing %.1f m/s at 10 degrees nose-up" % [float(falcon.get("lift_m", INF)),
			float(falcon.get("climb", 0.0))])
	_check("it_is_in_the_fighters_class_for_speed_and_no_faster",
		float(falcon.get("top", 0.0)) >= TOP_SPEED.x and float(falcon.get("top", 0.0)) <= TOP_SPEED.y,
		"%.1f m/s level at full power, the F/A-18F %.1f; wanted %.0f to %.0f" % [float(falcon.get("top", 0.0)),
			float(fighter.get("top", 0.0)), TOP_SPEED.x, TOP_SPEED.y])
	_check("it_rolls_faster_and_pulls_harder_than_the_hornet",
		float(falcon.get("roll", 0.0)) > float(fighter.get("roll", 0.0)) * 1.2
			and float(falcon.get("yank", 0.0)) > float(fighter.get("yank", 0.0))
			and float(falcon.get("yank", 0.0)) >= YANK_G.x and float(falcon.get("yank", 0.0)) <= YANK_G.y,
		"roll %.0f deg/s against the F/A-18F's %.0f; a full pull %.1f g against its %.1f, wanted %.1f to %.1f"
			% [float(falcon.get("roll", 0.0)), float(fighter.get("roll", 0.0)), float(falcon.get("yank", 0.0)),
				float(fighter.get("yank", 0.0)), YANK_G.x, YANK_G.y])
	_check("it_holds_its_height_through_a_hard_turn", absf(float(falcon.get("turn_dh", INF))) < 60.0
		and float(falcon.get("turn_deg", 0.0)) >= 360.0,
		"%.0f degrees of heading at 70 degrees of bank, pulled, in %.1f s, height %+.0f m"
			% [float(falcon.get("turn_deg", 0.0)), float(falcon.get("turn_s", 0.0)), float(falcon.get("turn_dh", INF))])
	_the_drawn_surfaces_follow_the_stick()
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)


## ONE AEROPLANE, off the ground and round the sky: take-off distance, climb, top speed, roll rate, a full pull and a
## steep level 360. Every number is read off the vehicle's own state.
func _fly(kind: int) -> Dictionary:
	var out: Dictionary = {}
	var hy: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	_begin(kind, Vector3(0.0, hy + 0.3, 0.0))
	var stall: float = float(_h.get("stall_speed", 30.0))
	_input["brake"] = 1.0
	_step(2.0)
	var from: Vector3 = _read()["at"]
	_input["brake"] = 0.0
	_input["throttle"] = 1.0
	var t0: float = _t
	while _t - t0 < 60.0:
		var r: Dictionary = _read()
		var h: float = (r["at"] as Vector3).y - from.y
		if h > 2.0 and not out.has("lift_m"):
			out["lift_m"] = ((r["at"] as Vector3) - from).length()
		if h > 30.0:
			_command(Sim.Channel.GEAR, 0)
			break
		_hands(r, 0.0 if float(r["speed"]) < stall * 1.2 else 10.0, _bank_for(r, 0.0))
		_step(TICK * 4.0)
	# CLIMB at 10 degrees from 50 m to 300 m.
	var r2: Dictionary = _read()
	var y_from: float = -1.0
	var t_from: float = 0.0
	t0 = _t
	while _t - t0 < 120.0 and (r2["at"] as Vector3).y < 300.0:
		_hands(r2, 10.0, _bank_for(r2, 0.0))
		_step(TICK * 4.0)
		r2 = _read()
		if (r2["at"] as Vector3).y > 50.0 and y_from < 0.0:
			y_from = (r2["at"] as Vector3).y
			t_from = _t
	out["climb"] = ((r2["at"] as Vector3).y - y_from) / maxf(_t - t_from, 0.01) if y_from >= 0.0 else 0.0
	# LEVEL AT 300 m, full power, sixty seconds: the top speed.
	t0 = _t
	while _t - t0 < 60.0:
		var r: Dictionary = _read()
		_hands(r, _pitch_for(r, 300.0), _bank_for(r, 0.0))
		_step(TICK * 4.0)
	out["top"] = float(_read()["speed"])
	# A FULL-STICK ROLL: the fastest bank rate seen over a second and a half of full right stick.
	var last: float = float(_read()["bank"])
	var fastest: float = 0.0
	t0 = _t
	while _t - t0 < 1.5:
		_input["roll"] = 1.0
		_input["pitch"] = 0.0
		_step(TICK * 2.0)
		var bank: float = float(_read()["bank"])
		var rate: float = rad_to_deg(angle_difference(deg_to_rad(last), deg_to_rad(bank))) / (TICK * 2.0)
		fastest = maxf(fastest, absf(rate))
		last = bank
	out["roll"] = fastest
	# WINGS LEVEL AGAIN, back to 300 m, then the stick yanked fully back for a second.
	t0 = _t
	while _t - t0 < 20.0:
		var r: Dictionary = _read()
		_hands(r, _pitch_for(r, 300.0), 0.0)
		_step(TICK * 4.0)
	out["yank"] = _yank()
	# BACK TO LEVEL, then A STEEP 360: 70 degrees of bank, pulled round, height held, full power.
	t0 = _t
	while _t - t0 < 25.0:
		var r: Dictionary = _read()
		_hands(r, _pitch_for(r, 300.0), 0.0)
		_step(TICK * 4.0)
	var start: Dictionary = _read()
	var turned: float = 0.0
	var heading: float = float(start["heading"])
	t0 = _t
	while _t - t0 < 120.0 and turned < 360.0:
		var r: Dictionary = _read()
		_hands(r, _pitch_for(r, (start["at"] as Vector3).y), 70.0, true)
		_step(TICK * 4.0)
		var now: float = float(_read()["heading"])
		turned += absf(rad_to_deg(angle_difference(deg_to_rad(heading), deg_to_rad(now))))
		heading = now
	out["turn_deg"] = turned
	out["turn_s"] = _t - t0
	out["turn_dh"] = (_read()["at"] as Vector3).y - (start["at"] as Vector3).y
	return out


## THE F-16'S SURFACES, drawn from a linkage as `VehicleView.draw` hands them one, ONE AXIS AT A TIME. Roll alone moves
## the flaperons apart (the right one up); pitch alone raises both tailplanes and leaves the flaperons where they are;
## rudder alone swings the rudder to starboard; centred, everything is back; the bus's gear bit stows the gear.
##
## ONE AXIS AT A TIME BECAUSE THE FIRST VERSION WAS BLIND. It pushed the stick fully right AND fully back at once, and a
## mutant that fed the PITCH axis into the flaperons stayed green: with both axes at 1 the swap changes nothing.
func _the_drawn_surfaces_follow_the_stick() -> void:
	var view := (load("res://objects/vehicles/craft_falcon.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var frame := view.find_child("Falcon", true, false) as FalconAirframe
	if frame == null:
		_check("the_drawn_surfaces_follow_the_stick", false, "the view drew no FalconAirframe")
		view.queue_free()
		return
	var rest: Dictionary = _trailing_edges(frame)
	view.draw_the_falcon_from({"gear": true}, {"linked_stick": Vector2(1.0, 0.0)})
	var rolled: Dictionary = _moved(rest, _trailing_edges(frame))
	view.draw_the_falcon_from({"gear": true}, {"linked_stick": Vector2(0.0, 1.0)})
	var pitched: Dictionary = _moved(rest, _trailing_edges(frame))
	view.draw_the_falcon_from({"gear": true}, {"linked_rudder": 1.0})
	var yawed: Dictionary = _moved(rest, _trailing_edges(frame))
	view.draw_the_falcon_from({"gear": false}, {})
	var gear_up: bool = not (frame.find_child("Gear", true, false) as Node3D).visible
	var back: Dictionary = _moved(rest, _trailing_edges(frame))
	var roll_ok: bool = rolled["FlaperonStarboard"].y > 0.1 and rolled["FlaperonPort"].y < -0.1
	var pitch_ok: bool = pitched["StabilatorStarboard"].y > 0.1 and pitched["StabilatorPort"].y > 0.1 \
		and absf(pitched["FlaperonStarboard"].y) < 0.01 and absf(pitched["FlaperonPort"].y) < 0.01
	var yaw_ok: bool = yawed["Rudder"].x > 0.1 and absf(yawed["FlaperonStarboard"].y) < 0.01
	var returned: bool = true
	for part in back:
		returned = returned and (back[part] as Vector3).length() < 0.001
	_check("the_drawn_surfaces_follow_the_stick", roll_ok and pitch_ok and yaw_ok and returned and gear_up,
		"roll alone: flaperons %+.2f / %+.2f m; pitch alone: tailplanes %+.2f / %+.2f m, flaperons %+.3f; rudder alone: %+.2f m; centred again %s; gear stowed on the bus's word %s"
			% [rolled["FlaperonStarboard"].y, rolled["FlaperonPort"].y, pitched["StabilatorStarboard"].y,
				pitched["StabilatorPort"].y, pitched["FlaperonStarboard"].y, yawed["Rudder"].x, returned, gear_up])
	view.queue_free()


func _moved(rest: Dictionary, now: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for part in rest:
		out[part] = (now[part] as Vector3) - (rest[part] as Vector3)
	return out


func _trailing_edges(frame: Node3D) -> Dictionary:
	var out: Dictionary = {}
	for part in ["FlaperonStarboard", "FlaperonPort", "StabilatorStarboard", "StabilatorPort", "Rudder"]:
		var mesh := frame.find_child(part, true, false) as MeshInstance3D
		var into := frame.global_transform.affine_inverse() * mesh.global_transform
		var best := Vector3(0, 0, -INF)
		var pts: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for p in pts:
			var q: Vector3 = into * p
			if q.z > best.z:
				best = q
		var sum := Vector3.ZERO
		var n: int = 0
		for p in pts:
			var q: Vector3 = into * p
			if q.z > best.z - 0.01:
				sum += q
				n += 1
		out[part] = sum / float(n)
	return out


# ---- the world, the seat and the hands (handling.gd's, not tuned here) --------------------------------------------

func _begin(kind: int, at: Vector3) -> void:
	_end()
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(GROUND_HALF, 400.0, GROUND_HALF))
	_h = _world.handling(kind)
	var made: Dictionary = _world.spawn_pilot(CLIENT, kind, at, 0.0, Vector3.ZERO)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_t = 0.0
	_seq = 0
	_input = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}


func _end() -> void:
	if _world != null:
		_world.teardown()
		_world = null


func _command(channel: int, value: int) -> void:
	_seq = _seq % 200 + 1
	_input["command_channel"] = channel
	_input["command_value"] = value
	_input["command_seq"] = _seq


func _step(seconds: float) -> void:
	for i in range(maxi(1, int(round(seconds / TICK)))):
		_world.set_pilot_input(_pilot, _input)
		_world.tick(TICK)
		_t += TICK


func _read() -> Dictionary:
	var s: Dictionary = _world.vehicle_state(_craft)
	var b := Basis(s.get("basis", Quaternion()) as Quaternion)
	var nose: Vector3 = b * Vector3.FORWARD
	var right: Vector3 = b * Vector3.RIGHT
	var v: Vector3 = s.get("velocity", Vector3.ZERO)
	return {
		"at": s.get("position", Vector3.ZERO) as Vector3, "v": v, "speed": v.length(), "vy": v.y,
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"bank": rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))),
		"heading": rad_to_deg(atan2(-nose.x, -nose.z)),
	}


func _hands(r: Dictionary, pitch_to: float, bank_to: float, pull: bool = false) -> void:
	var pr: float = rad_to_deg(float(_h.get("pitch_rate", 1.0)))
	var rr: float = rad_to_deg(float(_h.get("roll_rate", 1.0)))
	var ff: float = 0.0
	_input["rudder"] = 0.0
	if pull:
		var b: float = deg_to_rad(float(r["bank"]))
		var w: float = 9.81 * tan(b) / maxf(float(r["speed"]), 5.0) \
			* (1.0 - clampf(float(_h.get("turn_coordination", 0.0)), 0.0, 1.0))
		ff = rad_to_deg(w * sin(b)) / maxf(pr, 1.0)
		_input["rudder"] = clampf(rad_to_deg(w * cos(b)) / maxf(rad_to_deg(float(_h.get("yaw_rate", 1.0))), 1.0), -1.0, 1.0)
	_input["pitch"] = clampf(ff + K_PITCH * (pitch_to - float(r["pitch"])) / maxf(pr, 1.0), -1.0, 1.0)
	_input["roll"] = clampf(K_BANK * (bank_to - float(r["bank"])) / maxf(rr, 1.0), -1.0, 1.0)


func _bank_for(r: Dictionary, heading_to: float) -> float:
	var err: float = rad_to_deg(angle_difference(deg_to_rad(float(r["heading"])), deg_to_rad(heading_to)))
	return clampf(-K_HEADING * err, -15.0, 15.0)


func _pitch_for(r: Dictionary, height_to: float) -> float:
	return clampf(2.0 + K_ALT * (height_to - (r["at"] as Vector3).y) - K_VY * float(r["vy"]), -15.0, 15.0)


func _yank() -> float:
	var r: Dictionary = _read()
	var was: Vector3 = r["v"]
	var most: float = 0.0
	var t0: float = _t
	while _t - t0 < 1.0:
		_input["roll"] = clampf(K_BANK * (0.0 - float(r["bank"])) / maxf(rad_to_deg(float(_h.get("roll_rate", 1.0))), 1.0),
			-1.0, 1.0)
		_input["pitch"] = 1.0
		_step(TICK * 2.0)
		r = _read()
		var a: Vector3 = ((r["v"] as Vector3) - was) / (TICK * 2.0)
		was = r["v"]
		most = maxf(most, (a - Vector3(0.0, -9.81, 0.0)).length() / 9.81)
	_input["pitch"] = 0.0
	return most
