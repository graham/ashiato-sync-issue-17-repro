extends Node
## Headless: HOW FAST A ROTORCRAFT ANSWERS A FULL STICK OR A FULL PEDAL, in pitch, roll and yaw, at a hover and at sixty
## knots, for the Chinook, the light helicopter and the Osprey with its nacelles up -- and the Chinook held to a floor.
##
##   Godot --headless --path cockpit res://tests/rotor_rates.tscn [-- --variants=<abs path to json>]
##
## Asked for on 2026-09-15: "the chinook has far too little pitch/roll/rudder authority, let's make it much more agile".
## A rate is a thing a person feels and a headless run can measure, so this measures it rather than reading the handling
## table: a model's answer is the commanded rate, the torque the controls may use for it, the body's inertia about that
## axis and Box3D's angular damping taken together, and none of those four alone says what the pilot gets. Before the
## change the Chinook settled at 0.061, 0.397 and 0.106 rad/s in pitch, roll and yaw -- 3.5, 22.8 and 6.1 degrees a
## second -- because 90 000 N m per rad/s against 350 000 kg m2 is 0.26 per second and 2.2 of damping took nine tenths
## of what the stick asked for (cockpit/agents.md, "Authority is not the same question as rate").
##
## EACH STEP IS FLOWN BY A PILOT ON A CLIENT, beside its server over a same-tick link, as tests/world_edge.gd flies one:
## the control frame `client.set_input` takes is the one `PilotRig.read_controls` hands `Sim.set_input` from a stick, a
## key or a pedal, so what reaches the physics is what a hand would have sent. The collective is held where the craft's
## weight is carried (`(1 - hover) / collective_range`), everything is held at zero for two seconds, and then one axis
## goes to full deflection for STEP_SECONDS. Read on the SERVER, about the craft's own axes:
## - the PEAK rate, and the rate it SETTLES at over the last quarter second;
## - the time to 63 % of the peak, which is the time constant a first-order answer would have;
## - the OVERSHOOT, peak over settled;
## - the first tenth of a second's ANGULAR ACCELERATION, which is what a hand feels first.
## Sixty knots reads the same as the hover: the helicopter model has no speed term in its controls.
##
## THE VERDICT, with no arguments: at a hover the Chinook settles at no less than FLOOR on each axis, reaches 63 % in
## pitch and yaw within SLOWEST_T63, overshoots by no more than MOST_OVERSHOOT, and is slower than the light helicopter
## measured in the same run on every axis -- asked, not typed, so it stays the big one. THE SAME JUDGEMENT IS THEN MADE OF
## THE CHINOOK AS IT WAS (`BEFORE`), applied with `set_handling`, and must fail: a floor the old handling passes is a floor
## that cannot see what the user saw.
##
## `--variants=` names a JSON file of {variant: {kind_name: {handling field: value}, "only": [kind names], "autopilot":
## bool, "edge": bool}}, each flown in its own worlds with `set_handling` before the craft is spawned, so a proposal is
## measured before any C++ is built. "autopilot" adds two minutes of the Chinook's own autopilot round a square from a
## hover, counting pitch- and yaw-rate sign changes; "edge" flies a Chinook held at a hover out through a soft edge. No
## verdict is given in that mode.
##
## Read RESULT=, not the exit code.

const TICK_HZ: float = 60.0
const DT: float = 1.0 / TICK_HZ
const HEIGHT: float = 1500.0
## Sixty knots, in metres a second.
const CRUISE: float = 30.87
const SETTLE_TICKS: int = 120
const STEP_SECONDS: float = 1.5
const AXES: Array[String] = ["pitch", "roll", "rudder"]

## THE CHINOOK'S FLOOR, rad/s settled at full deflection at a hover: 26, 52 and 34 degrees a second. ADS-33E-PRF's Level 1
## hover minimums for moderate agility, which is what it holds a cargo helicopter to, are 13, 50 and 22 (Table VI), and a
## CH-53G in flight test reached about 31 to 36 in roll and 31 in yaw (DLR, ERF32-FM12). The handling of 2026-09-15
## measured 0.527, 1.036 and 0.713, so these sit about a seventh under it: room for a retune, none for the old 0.061.
const FLOOR: Dictionary = {"pitch": 0.45, "roll": 0.90, "rudder": 0.60}
## Seconds to 63 % in pitch and yaw. Measured 0.28 and 0.27; the Osprey's are 0.32, and the old Chinook's 0.43. Roll is
## not held to one: its inertia is a seventh of pitch's under the same `control_authority`, and it answers in 0.08.
const SLOWEST_T63: float = 0.35
## A rate controller with a clamp should not overshoot at all; every craft measured 0 to 1 %.
const MOST_OVERSHOOT: float = 0.10
## THE CHINOOK AS IT WAS until 2026-09-15, for the mutant.
const BEFORE: Dictionary = {"pitch_rate": 0.6, "roll_rate": 0.9, "yaw_rate": 1.0, "control_authority": 90000.0,
	"angular_damping": 2.2}

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[rotor_rates] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var has: bool = ClassDB.class_exists("CockpitWorld")
	_check("the_extension_is_loaded", has, "CockpitWorld")
	if not has:
		_finish()
		return
	var variants: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variants="):
			var text: String = FileAccess.get_file_as_string(arg.substr("--variants=".length()))
			var parsed: Variant = JSON.parse_string(text)
			_check("the_variants_file_reads", parsed is Dictionary, arg)
			if parsed is Dictionary:
				variants = parsed
	if variants.is_empty():
		_judge_the_chinook()
	else:
		for variant in variants:
			_fly_variant(variant, variants[variant])
	_finish()


## THE VERDICT: the Chinook as built against its floor and against the light helicopter, and the Chinook as it was against
## the same judgement, which must fail.
func _judge_the_chinook() -> void:
	var built: Dictionary = _fly_variant("as_built", {})
	var short: PackedStringArray = _short_of_the_floor(built)
	var chinook: Dictionary = built["chinook"]["hover"]
	_check("the_chinook_answers_a_full_stick_and_pedal_quickly_and_still_slower_than_the_light_helicopter",
		short.is_empty(), "; ".join(short) if not short.is_empty() else
			"settles at %.3f, %.3f and %.3f rad/s in pitch, roll and yaw, 63 %% in %.2f and %.2f s" % [
				chinook["pitch"]["settled"], chinook["roll"]["settled"], chinook["rudder"]["settled"],
				chinook["pitch"]["t63"], chinook["rudder"]["t63"]])
	var before: Dictionary = _fly_variant("before", {"only": ["chinook"], "chinook": BEFORE})
	before["heli"] = built["heli"]
	var old_short: PackedStringArray = _short_of_the_floor(before)
	_check("and_the_chinook_as_it_was_before_2026_09_15_fails_the_same_judgement", not old_short.is_empty(),
		"; ".join(old_short) if not old_short.is_empty() else "it passed, so the floor cannot see the fault")


## Everything a set of hover measurements falls short of, in words; empty when the Chinook meets its floor.
func _short_of_the_floor(measured: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var chinook: Dictionary = measured["chinook"]["hover"]
	var heli: Dictionary = measured["heli"]["hover"]
	for axis in AXES:
		var got: Dictionary = chinook[axis]
		if float(got["settled"]) < float(FLOOR[axis]):
			out.append("%s settles at %.3f rad/s, under %.2f" % [axis, got["settled"], FLOOR[axis]])
		if float(got["settled"]) >= float(heli[axis]["settled"]):
			out.append("%s at %.3f is not slower than the light helicopter's %.3f" % [axis, got["settled"],
				heli[axis]["settled"]])
		if axis != "roll" and (float(got["t63"]) < 0.0 or float(got["t63"]) > SLOWEST_T63):
			out.append("%s takes %.2f s to 63 %%, over %.2f" % [axis, got["t63"], SLOWEST_T63])
		if float(got["overshoot"]) > MOST_OVERSHOOT:
			out.append("%s overshoots by %.0f %%" % [axis, float(got["overshoot"]) * 100.0])
	return out


## ONE SET OF HANDLING, flown and printed: every kind (or the ones in "only"), at a hover and at sixty knots, on every
## axis. Returns {kind_name: {"hover"|"cruise": {axis: step}}}.
func _fly_variant(variant: String, tune: Dictionary) -> Dictionary:
	print("[rotor_rates] ==== %s %s" % [variant, JSON.stringify(tune)])
	var out: Dictionary = {}
	for kind in [Sim.Kind.CHINOOK, Sim.Kind.HELI, Sim.Kind.OSPREY]:
		var name: String = Sim.kind_name(kind)
		if tune.has("only") and not (tune["only"] as Array).has(name):
			continue
		_report_inertia(kind, tune)
		out[name] = {}
		for speed in [0.0, CRUISE]:
			var row: Dictionary = {}
			for axis in AXES:
				var got: Dictionary = _step(kind, speed, axis, tune)
				row[axis] = got
				print("[rotor_rates] %-8s %-7s %-6s peak %5.3f rad/s (%5.1f deg/s)  settled %5.3f  t63 %4.2f s  overshoot %4.0f %%  accel %5.2f rad/s2  speed %4.1f m/s  sank %5.1f m" % [
					variant, name, axis, got["peak"], rad_to_deg(got["peak"]), got["settled"], got["t63"],
					got["overshoot"] * 100.0, got["accel"], got["speed"], got["sank"]])
			out[name]["hover" if speed == 0.0 else "cruise"] = row
	if bool(tune.get("autopilot", false)):
		var hunt: Dictionary = _autopilot(Sim.Kind.CHINOOK, tune)
		print("[rotor_rates] %-8s chinook autopilot round a square from a hover: sign changes pitch rate %d, yaw rate %d; largest pitch rate %.3f, yaw rate %.3f rad/s, tilt %.1f deg; height %.0f to %.0f m; travelled %.0f m" % [
			variant, hunt["pitch_flips"], hunt["yaw_flips"], hunt["pitch_largest"], hunt["yaw_largest"], hunt["tilt"],
			hunt["lowest"], hunt["highest"], hunt["travelled"]])
	if bool(tune.get("edge", false)):
		var edge: Dictionary = _edge(Sim.Kind.CHINOOK, tune)
		print("[rotor_rates] %-8s chinook held at a hover, flown out through a soft edge at 30 m/s: %.0f m past the start, nose within 10 deg of home at %.1f s, swung up to %.1f deg off it after, ends %.1f deg off, largest bank %.1f deg" % [
			variant, edge["over"], edge["facing_at"], edge["swung"], edge["off"], edge["bank"]])
	return out


## THE BODY'S INERTIA about pitch, roll and yaw, from the shape and mass the simulation will build, so a table of rates
## can be read against what the torque has to move. A solid box of the shape's half extents, as Box3D builds it.
func _report_inertia(kind: int, tune: Dictionary) -> void:
	var shape: Dictionary = Sim.geometry_of(kind)
	var world: Object = _world(0)
	_tune(world, tune)
	var h: Dictionary = world.handling(kind)
	_let_go(world)
	var half: Vector3 = shape.get("extents", Vector3.ONE)
	var mass: float = float(shape.get("mass", 1.0))
	var pitch_i: float = mass / 3.0 * (half.y * half.y + half.z * half.z)
	var roll_i: float = mass / 3.0 * (half.x * half.x + half.y * half.y)
	var yaw_i: float = mass / 3.0 * (half.x * half.x + half.z * half.z)
	print("[rotor_rates] %s: %.0f kg, half extents %s, box inertia pitch %.0f roll %.0f yaw %.0f kg m2; handling pitch_rate %s roll_rate %s yaw_rate %s control_authority %s angular_damping %s hover %s collective_range %s" % [
		Sim.kind_name(kind), mass, half, pitch_i, roll_i, yaw_i, h.get("pitch_rate"), h.get("roll_rate"),
		h.get("yaw_rate"), h.get("control_authority"), h.get("angular_damping"), h.get("hover"),
		h.get("collective_range")])


## ONE STEP: a fresh server and client, the kind flown from `HEIGHT` at `speed` along +X, held level for SETTLE_TICKS,
## then `axis` at full deflection for STEP_SECONDS.
func _step(kind: int, speed: float, axis: String, tune: Dictionary) -> Dictionary:
	var server: Object = _world(0)
	var client: Object = _world(1)
	_tune(server, tune)
	_tune(client, tune)
	for i in range(90):
		_step_pair(server, client)
	var h: Dictionary = server.handling(kind)
	var collective: float = (1.0 - float(h.get("hover", 0.5))) / maxf(float(h.get("collective_range", 1.0)), 0.01)
	server.spawn_pilot(int(client.local_client_id()), kind, Vector3(0.0, HEIGHT, 0.0), -PI * 0.5, Vector3(speed, 0.0, 0.0))
	var craft: int = -1
	var rates: PackedFloat32Array = []
	var started_at: Vector3 = Vector3.ZERO
	var speed_at_step: float = 0.0
	var step_ticks: int = int(STEP_SECONDS * TICK_HZ)
	for i in range(SETTLE_TICKS + step_ticks):
		var held: Dictionary = {"throttle": collective}
		if i >= SETTLE_TICKS:
			held[axis] = 1.0
		client.set_input(_controls(held))
		if kind == Sim.Kind.OSPREY:
			# NACELLES UP, which is the helicopter half of a tiltrotor. Latched, so once is enough; sent through the
			# settle because a command rides a few frames and a seat has to exist first.
			client.send_command(Sim.Channel.TILT, 255)
		_step_pair(server, client)
		if craft < 0:
			var all: Array = server.vehicle_states()
			craft = int(all[0]["entity"]) if all.size() == 1 else -1
			continue
		var state: Dictionary = server.vehicle_state(craft)
		if i == SETTLE_TICKS - 1:
			started_at = state.get("position", Vector3.ZERO)
			speed_at_step = (state.get("velocity", Vector3.ZERO) as Vector3).length()
		if i >= SETTLE_TICKS:
			rates.append(_rate(state, axis))
	var ended_at: Vector3 = server.vehicle_state(craft).get("position", Vector3.ZERO) if craft >= 0 else Vector3.ZERO
	_let_go(server)
	_let_go(client)
	var peak: float = 0.0
	for r in rates:
		peak = maxf(peak, r)
	var tail: int = int(0.25 * TICK_HZ)
	var settled: float = 0.0
	for j in range(maxi(rates.size() - tail, 0), rates.size()):
		settled += rates[j] / float(tail)
	var t63: float = -1.0
	for j in range(rates.size()):
		if rates[j] >= 0.63 * peak:
			t63 = float(j + 1) * DT
			break
	var tenth: int = mini(int(0.1 * TICK_HZ), rates.size()) - 1
	return {
		"peak": peak,
		"settled": settled,
		"t63": t63,
		"overshoot": (peak - settled) / settled if settled > 1e-4 else 0.0,
		"accel": rates[tenth] / (float(tenth + 1) * DT) if tenth >= 0 else 0.0,
		"speed": speed_at_step,
		"sank": started_at.y - ended_at.y,
	}


## THE RATE ABOUT THE CRAFT'S OWN AXIS, signed so that the full deflection asked for reads positive: +pitch is nose up
## (about +X), +roll is right wing down (about the nose, -Z), +rudder is nose right (about -Y).
func _rate(state: Dictionary, axis: String) -> float:
	var basis := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
	var spin: Vector3 = state.get("spin", Vector3.ZERO)
	match axis:
		"pitch":
			return spin.dot(basis.x)
		"roll":
			return spin.dot(-basis.z)
		_:
			return -spin.dot(basis.y)


## TWO MINUTES OF THE CRAFT'S OWN AUTOPILOT from a hover round a square of waypoints 2.5 km on a side, on one world, so it
## has to accelerate, hold a tilt and turn. Counts how often its pitch and yaw rates change sign by more than a dither: a
## loop tuned against the old answer hunts against a quicker one, and a steady cruise alone cannot show it (the first
## version watched only the cruise and read 0.000 rad/s on every variant).
func _autopilot(kind: int, tune: Dictionary) -> Dictionary:
	var world: Object = _world(0)
	_tune(world, tune)
	for corner in [Vector3(2500.0, HEIGHT, 0.0), Vector3(2500.0, HEIGHT, 2500.0), Vector3(0.0, HEIGHT, 2500.0),
			Vector3(0.0, HEIGHT, 0.0)]:
		world.add_ai_waypoint(kind, corner)
	var craft: int = int(world.spawn_ai_vehicle(kind, Vector3(0.0, HEIGHT, 0.0), -PI * 0.5, Vector3.ZERO))
	var counts: Dictionary = {"pitch": 0, "rudder": 0}
	var was: Dictionary = {"pitch": 0, "rudder": 0}
	var largest: Dictionary = {"pitch": 0.0, "rudder": 0.0}
	var tilt: float = 0.0
	var lowest: float = INF
	var highest: float = -INF
	var travelled: float = 0.0
	var last: Vector3 = Vector3(0.0, HEIGHT, 0.0)
	for i in range(int(120.0 * TICK_HZ)):
		world.tick(DT)
		var state: Dictionary = world.vehicle_state(craft)
		if state.is_empty() or i < int(TICK_HZ):
			continue
		var at: Vector3 = state.get("position", last)
		travelled += at.distance_to(last)
		last = at
		lowest = minf(lowest, at.y)
		highest = maxf(highest, at.y)
		var nose: Vector3 = -Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion).z
		tilt = maxf(tilt, rad_to_deg(absf(asin(clampf(nose.y, -1.0, 1.0)))))
		for axis in ["pitch", "rudder"]:
			var r: float = _rate(state, axis)
			largest[axis] = maxf(float(largest[axis]), absf(r))
			var sign: int = 1 if r > 0.05 else (-1 if r < -0.05 else 0)
			if sign != 0 and int(was[axis]) != 0 and sign != int(was[axis]):
				counts[axis] = int(counts[axis]) + 1
			if sign != 0:
				was[axis] = sign
	_let_go(world)
	return {"pitch_flips": counts["pitch"], "yaw_flips": counts["rudder"], "pitch_largest": largest["pitch"],
		"yaw_largest": largest["rudder"], "tilt": tilt, "lowest": lowest, "highest": highest, "travelled": travelled}


## A PILOT WHO HOLDS ONLY THE COLLECTIVE, flown out through a soft edge at 30 m/s on a client beside its server.
## tests/world_edge.gd flies the powered wings; this is the helicopter's half, for a proposal.
func _edge(kind: int, tune: Dictionary) -> Dictionary:
	var START: float = 18000.0
	var DEPTH: float = 2598.0
	var server: Object = _world(0)
	var client: Object = _world(1)
	for world in [server, client]:
		_tune(world, tune)
		world.set_boundary(START, DEPTH)
	for i in range(90):
		_step_pair(server, client)
	var h: Dictionary = server.handling(kind)
	var collective: float = (1.0 - float(h.get("hover", 0.5))) / maxf(float(h.get("collective_range", 1.0)), 0.01)
	server.spawn_pilot(int(client.local_client_id()), kind, Vector3(START - 200.0, HEIGHT, 0.0), -PI * 0.5,
		Vector3(30.0, 0.0, 0.0))
	# A HELICOPTER IS YAWED HOME, NOT FLOWN HOME, AND ONLY TO SIXTY DEGREES OFF IT: the turn-back puts in rudder and levels
	# the wings, leaves the pitch to its pilot, and is weighted by `clamp(1 - 2 cos(off))`, which is zero at sixty
	# degrees. Held at a hover, a Chinook coasted to a stop 61.7 degrees off home as built and 59.8 with the handling of
	# 2026-09-15. The first version asked whether the VELOCITY pointed home and read false for a craft that had stopped.
	var craft: int = -1
	var furthest: float = 0.0
	var facing_at: float = -1.0
	var swung_past: float = 0.0
	var bank: float = 0.0
	var off: float = 0.0
	for i in range(int(90.0 * TICK_HZ)):
		client.set_input(_controls({"throttle": collective}))
		_step_pair(server, client)
		if craft < 0:
			var all: Array = server.vehicle_states()
			craft = int(all[0]["entity"]) if all.size() == 1 else -1
			continue
		var state: Dictionary = server.vehicle_state(craft)
		var at: Vector3 = state.get("position", Vector3.ZERO)
		var basis := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
		furthest = maxf(furthest, maxf(absf(at.x), absf(at.z)))
		bank = maxf(bank, rad_to_deg(absf(asin(clampf(basis.x.y, -1.0, 1.0)))))
		var nose := Vector2(-basis.z.x, -basis.z.z)
		var home := Vector2(-at.x, -at.z)
		off = rad_to_deg(absf(nose.angle_to(home))) if nose.length() > 0.01 and home.length() > 1.0 else 0.0
		if facing_at < 0.0 and off < 10.0:
			facing_at = float(i) * DT
		if facing_at >= 0.0:
			swung_past = maxf(swung_past, off)
	_let_go(server)
	_let_go(client)
	return {"over": furthest - START, "facing_at": facing_at, "off": off, "swung": swung_past, "bank": bank}


func _tune(world: Object, tune: Dictionary) -> void:
	for kind in [Sim.Kind.CHINOOK, Sim.Kind.HELI, Sim.Kind.OSPREY]:
		var name: String = Sim.kind_name(kind)
		if tune.has(name):
			world.set_handling(kind, tune[name])


func _world(client_id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(TICK_HZ)
	world.start(client_id)
	return world


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _step_pair(server: Object, client: Object) -> void:
	server.tick(DT)
	client.tick(DT)
	for packet in server.take_outbound():
		client.deliver(0, packet["bytes"], packet["bits"])
	for packet in client.take_outbound():
		server.deliver(1, packet["bytes"], packet["bits"])


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


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
