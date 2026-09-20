extends Node
## Headless: HOW EACH HELICOPTER FLIES, flown by a scripted pilot through a client's controls, printed as numbers a person
## reads to say how it handles. Asserts nothing; `tests/rotor_rates.gd` holds the rates. Read RESULT=.
##
##   Godot --headless --path cockpit res://tests/rotor_flight_probe.tscn [-- --kind=heli]
##
## THE PILOT IS A PERSON'S HANDS, NOT AN AUTOPILOT: collective, stick and pedals, each a simple feedback on what a pilot
## watches -- the vertical speed, the attitude, the heading -- sent through `client.set_input` in the frame
## `PilotRig.read_controls` builds, beside a server over a same-tick link, as `rotor_rates` flies. Every craft gets the
## same hands, so the differences in the log are the craft's.
##
## THE FLIGHT, from a hover at HEIGHT: hands off for five seconds (does it sit still?); hover held; nose down ten degrees
## for twenty seconds (how fast, how soon?); a level turn at twenty degrees of bank for fifteen (how quickly round?);
## nose up to stop (how far?); and a let-down at two metres a second to the ground or thirty seconds (does it settle?).

const TICK_HZ: float = 60.0
const DT: float = 1.0 / TICK_HZ
const HEIGHT: float = 400.0

var _log: PackedStringArray = []
## `--assist`: PROTOTYPE OF THE COORDINATED-TURN TERM (`lane/rotors` option b), with no C++. The rate the term would add
## to what the stick asks for -- w = g tan(bank) / v about the world's up, taken into body pitch and yaw, faded in
## across translational lift -- is added to the pilot's own pitch and pedal, divided by the kind's `pitch_rate` and
## `yaw_rate`, which is exactly the commanded rate `apply_controls` would then hold. It lacks the feed-forward torque the
## C++ would add against `angular_damping`, so it UNDER-states the fix.
var _assist: bool = false
## Translational lift, where the term fades in: nothing under FADE.x m/s, all of it over FADE.y.
const FADE := Vector2(8.0, 16.0)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL the native library is not loaded")
		get_tree().quit(1)
		return
	var only: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			only = arg.trim_prefix("--kind=")
		elif arg == "--assist":
			_assist = true
	for kind in [Sim.Kind.HELI, Sim.Kind.UH60, Sim.Kind.CHINOOK]:
		if only.is_empty() or Sim.kind_name(kind) == only:
			_fly(kind)
	print("RESULT=PASS")
	get_tree().quit(0)


func _fly(kind: int) -> void:
	var name: String = Sim.kind_name(kind)
	var server: Object = _world(0)
	var client: Object = _world(1)
	for i in range(90):
		_pair(server, client)
	var h: Dictionary = server.handling(kind)
	var hover: float = (1.0 - float(h.get("hover", 0.5))) / maxf(float(h.get("collective_range", 1.0)), 0.01)
	print("[rotor_flight] ==== %s: %.0f kg, hover collective %.2f, handling %s" % [name,
		float(Sim.geometry_of(kind).get("mass", 0.0)), hover, JSON.stringify(h)])
	server.spawn_pilot(int(client.local_client_id()), kind, Vector3(0.0, HEIGHT, 0.0), 0.0, Vector3.ZERO)
	var craft: int = -1
	while craft < 0:
		client.set_input(_controls({"throttle": hover}))
		_pair(server, client)
		var all: Array = server.vehicle_states()
		craft = int(all[0]["entity"]) if all.size() == 1 else -1
	var pilot := {"hover": hover, "heading": 0.0, "pitch_rate": float(h.get("pitch_rate", 1.0)),
		"yaw_rate": float(h.get("yaw_rate", 1.0))}
	print("[rotor_flight] %s flown %s" % [name, "WITH the coordinated-turn term prototyped" if _assist else "as built"])
	# HANDS OFF: collective where the weight is carried, nothing else.
	var start: Dictionary = server.vehicle_state(craft)
	var worst_tilt: float = 0.0
	for i in range(int(5.0 * TICK_HZ)):
		client.set_input(_controls({"throttle": hover}))
		_pair(server, client)
		worst_tilt = maxf(worst_tilt, _tilt(server.vehicle_state(craft)))
	var now: Dictionary = server.vehicle_state(craft)
	print("[rotor_flight] %-7s hands off 5 s at the hover collective: moved %.1f m (%.1f m vertically), tilted at most %.1f deg" % [
		name, _at(now).distance_to(_at(start)), _at(now).y - _at(start).y, worst_tilt])
	# HOVER HELD, then NOSE DOWN TEN DEGREES.
	_hold(server, client, craft, pilot, 5.0, 0.0, 0.0, 0.0)
	var began: Vector3 = _at(server.vehicle_state(craft))
	var reached_20: float = -1.0
	var top: float = 0.0
	var lowest: float = INF
	for i in range(int(20.0 * TICK_HZ)):
		_hands(server, client, craft, pilot, -10.0, 0.0, 0.0)
		var state: Dictionary = server.vehicle_state(craft)
		var speed: float = _ground_speed(state)
		top = maxf(top, speed)
		lowest = minf(lowest, _at(state).y)
		if reached_20 < 0.0 and speed >= 20.0:
			reached_20 = float(i) * DT
	var cruise: Dictionary = server.vehicle_state(craft)
	print("[rotor_flight] %-7s nose down 10 deg for 20 s: %.1f m/s (%.0f kt) at the end, 20 m/s after %.1f s, %.0f m covered, height held within %.1f m" % [
		name, top, top * 1.944, reached_20, _at(cruise).distance_to(began), HEIGHT - lowest])
	# A TURN AT TWENTY DEGREES OF BANK, PEDALS STILL, then THE SAME TURN WITH THE PEDALS KEEPING THE NOSE ON THE TRACK, as a
	# pilot keeps the ball in the middle. The first is what a player who has never flown does; the second is flying.
	for coordinated in [false, true]:
		var entry: Dictionary = server.vehicle_state(craft)
		var heading_in: float = _heading(entry)
		var track_in: float = _track(entry)
		var bank_reached: float = -1.0
		for i in range(int(15.0 * TICK_HZ)):
			_hands(server, client, craft, pilot, -6.0, 20.0, 0.0, true, coordinated)
			if bank_reached < 0.0 and _bank(server.vehicle_state(craft)) >= 18.0:
				bank_reached = float(i) * DT
		var turned: Dictionary = server.vehicle_state(craft)
		var swung: float = rad_to_deg(wrapf(_heading(turned) - heading_in, -PI, PI))
		var tracked: float = rad_to_deg(wrapf(_track(turned) - track_in, -PI, PI))
		print("[rotor_flight] %-7s 20 deg bank for 15 s, %s: 18 deg of bank in %.1f s, nose swung %.0f deg, track swung %.0f deg (%.1f deg/s), sideslip %.0f deg, %.1f m/s, %.1f m of height lost" % [
			name, "pedals keeping the nose on the track" if coordinated else "pedals still", bank_reached, swung,
			tracked, absf(tracked) / 15.0, _slip(turned), _ground_speed(turned), _at(entry).y - _at(turned).y])
		# WINGS LEVEL AND NOSE BACK ON THE TRACK before the next.
		for i in range(int(6.0 * TICK_HZ)):
			pilot["heading"] = _track(server.vehicle_state(craft))
			_hands(server, client, craft, pilot, -6.0, 0.0, 0.0)
	# FULL RIGHT PEDAL, WINGS LEVEL, FOR THREE SECONDS: the yaw rate as a share of `yaw_rate`. A fix that turns the
	# nose with the bank must not take the pedal away -- `lane/handling` rejected a strong fin because it did.
	var yaw_peak: float = 0.0
	for i in range(int(3.0 * TICK_HZ)):
		var st: Dictionary = server.vehicle_state(craft)
		var b := Basis(st.get("basis", Quaternion.IDENTITY) as Quaternion)
		var spin: Vector3 = st.get("spin", Vector3.ZERO)
		var nose_up: float = rad_to_deg(asin(clampf(-b.z.y, -1.0, 1.0)))
		var right_down: float = rad_to_deg(asin(clampf(-b.x.y, -1.0, 1.0)))
		var vs: float = (st.get("velocity", Vector3.ZERO) as Vector3).y
		var sp: float = clampf((-6.0 - nose_up) * 0.08 - spin.dot(b.x) * 0.6, -1.0, 1.0)
		var sr: float = clampf(-right_down * 0.06 - spin.dot(-b.z) * 0.4, -1.0, 1.0)
		var added: Vector2 = _coordinated(st, pilot) if _assist else Vector2.ZERO
		client.set_input(_controls({"throttle": clampf(float(pilot["hover"]) - vs * 0.12, 0.0, 1.0),
			"pitch": clampf(sp + added.x, -1.0, 1.0), "roll": sr, "rudder": clampf(1.0 + added.y, -1.0, 1.0)}))
		_pair(server, client)
		yaw_peak = maxf(yaw_peak, -(server.vehicle_state(craft).get("spin", Vector3.ZERO) as Vector3).dot(
			Basis(server.vehicle_state(craft).get("basis", Quaternion.IDENTITY) as Quaternion).y))
	print("[rotor_flight] %-7s full right pedal, wings level, at speed: %.2f rad/s, %.0f %% of its yaw_rate %.2f" % [
		name, yaw_peak, yaw_peak / float(pilot["yaw_rate"]) * 100.0, float(pilot["yaw_rate"])])
	var turned: Dictionary = server.vehicle_state(craft)
	# STOP: flare against the speed along the nose and bank against the speed across it, as a pilot does.
	pilot["heading"] = _heading(turned)
	var stop_from: Vector3 = _at(turned)
	var stop_time: float = -1.0
	for i in range(int(40.0 * TICK_HZ)):
		var state: Dictionary = server.vehicle_state(craft)
		var body: Vector3 = Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion).inverse() 			* (state.get("velocity", Vector3.ZERO) as Vector3)
		_hands(server, client, craft, pilot, clampf(-body.z * 0.8, -15.0, 15.0), clampf(-body.x * 0.8, -15.0, 15.0), 0.0)
		if _ground_speed(state) < 1.0:
			stop_time = float(i) * DT
			break
	var stopped: Dictionary = server.vehicle_state(craft)
	print("[rotor_flight] %-7s flare to a stop: %.1f s, %.0f m, %.1f m of height gained" % [name, stop_time,
		Vector2(_at(stopped).x - stop_from.x, _at(stopped).z - stop_from.z).length(), _at(stopped).y - stop_from.y])
	# LET DOWN at two metres a second.
	var down_from: float = _at(stopped).y
	var drift: Vector3 = _at(stopped)
	var landed: float = -1.0
	for i in range(int(30.0 * TICK_HZ)):
		_hands(server, client, craft, pilot, 0.0, 0.0, -2.0)
		var state: Dictionary = server.vehicle_state(craft)
		if landed < 0.0 and (state.get("velocity", Vector3.ZERO) as Vector3).length() < 0.05 and i > 60:
			landed = float(i) * DT
	var down: Dictionary = server.vehicle_state(craft)
	print("[rotor_flight] %-7s let down at 2 m/s for 30 s: %.1f m descended, drifted %.1f m, tilt %.1f deg at the end%s" % [
		name, down_from - _at(down).y, Vector2(_at(down).x - drift.x, _at(down).z - drift.z).length(), _tilt(down),
		", at rest after %.1f s" % landed if landed >= 0.0 else ""])
	_let_go(server)
	_let_go(client)


## A HOVER, or any attitude, held for `seconds`.
func _hold(server: Object, client: Object, craft: int, pilot: Dictionary, seconds: float, pitch: float, bank: float,
		climb: float) -> void:
	for i in range(int(seconds * TICK_HZ)):
		_hands(server, client, craft, pilot, pitch, bank, climb)


## ONE FRAME OF A PILOT'S HANDS: stick to the attitude asked for (degrees, + nose up, + right bank), collective to the
## climb asked for (m/s), pedals to hold the heading -- or, in a turn, to keep the nose with the turn.
func _hands(server: Object, client: Object, craft: int, pilot: Dictionary, pitch: float, bank: float, climb: float,
		turning: bool = false, coordinated: bool = false) -> void:
	var state: Dictionary = server.vehicle_state(craft)
	var basis := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
	var spin: Vector3 = state.get("spin", Vector3.ZERO)
	var nose_up: float = rad_to_deg(asin(clampf(-basis.z.y, -1.0, 1.0)))
	var right_down: float = rad_to_deg(asin(clampf(-basis.x.y, -1.0, 1.0)))
	var vs: float = (state.get("velocity", Vector3.ZERO) as Vector3).y
	var stick_pitch: float = clampf((pitch - nose_up) * 0.08 - spin.dot(basis.x) * 0.6, -1.0, 1.0)
	var stick_roll: float = clampf((bank - right_down) * 0.06 - spin.dot(-basis.z) * 0.4, -1.0, 1.0)
	var off: float = rad_to_deg(wrapf(_heading(state) - float(pilot["heading"]), -PI, PI))
	var pedal: float = 0.0 if turning else clampf(-off * 0.05 + spin.dot(basis.y) * 0.5, -1.0, 1.0)
	if coordinated:
		pedal = clampf(_slip(state) * 0.05, -1.0, 1.0)
	if turning:
		pilot["heading"] = _heading(state)
	var collective: float = clampf(float(pilot["hover"]) + (climb - vs) * 0.12, 0.0, 1.0)
	if _assist:
		var added: Vector2 = _coordinated(state, pilot)
		stick_pitch = clampf(stick_pitch + added.x, -1.0, 1.0)
		pedal = clampf(pedal + added.y, -1.0, 1.0)
	client.set_input(_controls({"throttle": collective, "pitch": stick_pitch, "roll": stick_roll, "rudder": pedal}))
	_pair(server, client)


## THE TERM, as stick and pedal: w = g (-right.y) / max(up.y, 0.35) / max(along, FADE.y), faded in across FADE and to
## nothing inverted; pitch rate -w right.y and yaw rate -w up.y (lane/handling's formula, cockpit/agents.md), as the
## share of `pitch_rate` and `yaw_rate` a stick and pedal would ask for.
func _coordinated(state: Dictionary, pilot: Dictionary) -> Vector2:
	var basis := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
	var along: float = -(state.get("velocity", Vector3.ZERO) as Vector3).dot(basis.z)
	if basis.y.y < 0.1:
		return Vector2.ZERO
	var w: float = 9.81 * -basis.x.y / maxf(basis.y.y, 0.35) / maxf(along, FADE.y) * smoothstep(FADE.x, FADE.y, along)
	# +pitch is nose up about +right; the pedal's commanded yaw is -rudder * yaw_rate about up.
	return Vector2(-w * basis.x.y / float(pilot["pitch_rate"]), w * basis.y.y / float(pilot["yaw_rate"]))


func _at(state: Dictionary) -> Vector3:
	return state.get("position", Vector3.ZERO)


func _ground_speed(state: Dictionary) -> float:
	var v: Vector3 = state.get("velocity", Vector3.ZERO)
	return Vector2(v.x, v.z).length()


## HEADING, radians, 0 along -Z and increasing to the right.
func _heading(state: Dictionary) -> float:
	var nose: Vector3 = -Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion).z
	return atan2(nose.x, -nose.z)


## THE TRACK, radians, the way the craft is going over the ground, measured as `_heading` is.
func _track(state: Dictionary) -> float:
	var v: Vector3 = state.get("velocity", Vector3.ZERO)
	return atan2(v.x, -v.z)


## SIDESLIP, degrees: how far the track is to the right of the nose. Positive wants right pedal.
func _slip(state: Dictionary) -> float:
	if _ground_speed(state) < 3.0:
		return 0.0
	return rad_to_deg(wrapf(_track(state) - _heading(state), -PI, PI))


func _bank(state: Dictionary) -> float:
	var basis := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
	return rad_to_deg(absf(asin(clampf(basis.x.y, -1.0, 1.0))))


func _tilt(state: Dictionary) -> float:
	var basis := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
	return rad_to_deg(acos(clampf(basis.y.y, -1.0, 1.0)))


func _world(client_id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(TICK_HZ)
	world.start(client_id)
	return world


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _pair(server: Object, client: Object) -> void:
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
