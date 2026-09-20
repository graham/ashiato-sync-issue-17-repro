extends Node
## Headless: A BANKED HELICOPTER TURNS, AND ITS PEDALS STILL TURN IT. Read RESULT=.
##
##   Godot --headless --path cockpit res://tests/rotor_turn.tscn
##
## THE FAULT (lane/rotors, 2026-09-17, tests/rotor_flight_probe.gd): `fly_helicopter` had no term that yaws a helicopter
## into its flight path, so a player who banked and left the pedals alone slid sideways -- at 20 degrees of bank the nose
## moved 1 degree in 15 s while the track swung about 50, at 47-51 degrees of sideslip. The fix blends lane/handling's
## `coordinated_turn` into a HUMAN pilot's rate demands above translational lift (8 to 16 m/s along the nose).
##
## FLOWN AS A PERSON FLIES IT: a pilot seated on a client, their stick and pedals sent through `client.set_input` in the
## frame `PilotRig.read_controls` builds, beside a server over a same-tick link; read on the server. For each helicopter:
## - AT SPEED, BANKED, PEDALS STILL: 10 degrees nose down to cruise, then 20 degrees of bank held for 15 s with the
##   pedals centred. The nose must come round at least MIN_SHARE of g tan(bank) / v, and the sideslip at the end must be
##   under MAX_SLIP. Before the fix: 1 degree of nose and 47-51 of slip.
## - AT SPEED, FULL PEDAL, WINGS LEVEL: at least MIN_PEDAL of `yaw_rate`. A fin that turned the nose with the bank would
##   have taken this away (lane/handling measured 1-4 % at `weathervane` x50); the term adds to the pedal instead.
## - AT A HOVER, BANKED, PEDALS STILL: the nose stays within HOVER_DRIFT degrees in 3 s. Below translational lift a bank is
##   a sideways slide, as it is in a real helicopter hovering, and nothing turns the nose.

const DT := 1.0 / 60.0
const BANK := 20.0
const MIN_SHARE := 0.70
const MAX_SLIP := 12.0
const MIN_PEDAL := 0.60
const HOVER_DRIFT := 4.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[rotor_turn] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("the_native_library_is_loaded", false, "CockpitWorld missing")
		_finish()
		return
	var turn_said: PackedStringArray = []
	var turn_ok := true
	var pedal_said: PackedStringArray = []
	var pedal_ok := true
	var hover_said: PackedStringArray = []
	var hover_ok := true
	for kind in [Sim.Kind.HELI, Sim.Kind.UH60, Sim.Kind.CHINOOK, Sim.Kind.LITTLEBIRD, Sim.Kind.APACHE]:
		var got: Dictionary = _fly(kind)
		var name: String = Sim.kind_name(kind)
		turn_ok = turn_ok and float(got["share"]) >= MIN_SHARE and absf(float(got["slip"])) <= MAX_SLIP
		turn_said.append("%s nose %.0f deg in 15 s, %.0f %% of g tan(b)/v, slip %.0f deg at %.1f m/s" % [name,
			got["swung"], float(got["share"]) * 100.0, got["slip"], got["speed"]])
		pedal_ok = pedal_ok and float(got["pedal"]) >= MIN_PEDAL
		pedal_said.append("%s %.0f %%" % [name, float(got["pedal"]) * 100.0])
		hover_ok = hover_ok and absf(float(got["hover_drift"])) <= HOVER_DRIFT
		hover_said.append("%s %.1f deg" % [name, got["hover_drift"]])
	_check("a_helicopter_banked_at_speed_with_the_pedals_still_turns_with_its_nose_on_the_track", turn_ok,
		"; ".join(turn_said))
	_check("and_full_pedal_at_speed_still_yaws_it_at_most_of_its_yaw_rate", pedal_ok, ", ".join(pedal_said))
	_check("and_banked_at_a_hover_its_nose_stays_put", hover_ok, "in 3 s: " + ", ".join(hover_said))
	_finish()


func _fly(kind: int) -> Dictionary:
	var server: Object = _world(0)
	var client: Object = _world(1)
	for i in range(90):
		_pair(server, client)
	var h: Dictionary = server.handling(kind)
	var hover: float = (1.0 - float(h.get("hover", 0.5))) / maxf(float(h.get("collective_range", 1.0)), 0.01)
	server.spawn_pilot(int(client.local_client_id()), kind, Vector3(0.0, 600.0, 0.0), 0.0, Vector3.ZERO)
	var craft: int = -1
	while craft < 0:
		client.set_input(_controls({"throttle": hover}))
		_pair(server, client)
		var all: Array = server.vehicle_states()
		craft = int(all[0]["entity"]) if all.size() == 1 else -1
	var out: Dictionary = {}
	# AT A HOVER, BANKED: two seconds to settle, then the bank for three.
	_hold(server, client, craft, hover, 0.0, 0.0, 0.0, 2.0)
	var before: float = _heading(server.vehicle_state(craft))
	_hold(server, client, craft, hover, 0.0, BANK, 0.0, 3.0)
	out["hover_drift"] = rad_to_deg(wrapf(_heading(server.vehicle_state(craft)) - before, -PI, PI))
	# LEVEL, THEN TO CRUISE, pedals holding the heading as a pilot does.
	_hold(server, client, craft, hover, 0.0, 0.0, 0.0, 4.0)
	_hold(server, client, craft, hover, -10.0, 0.0, 0.0, 20.0, true)
	# BANKED, PEDALS STILL, integrating what the bank asks for as it goes.
	var entry: Dictionary = server.vehicle_state(craft)
	var heading_in: float = _heading(entry)
	var asked: float = 0.0
	for i in range(int(15.0 / DT)):
		_hands(server, client, craft, hover, -6.0, BANK, 0.0)
		var state: Dictionary = server.vehicle_state(craft)
		var basis := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
		var along: float = maxf(-(state.get("velocity", Vector3.ZERO) as Vector3).dot(basis.z), 1.0)
		asked += 9.81 * tan(asin(clampf(-basis.x.y, -1.0, 1.0))) / along * DT
	var turned: Dictionary = server.vehicle_state(craft)
	out["swung"] = rad_to_deg(wrapf(_heading(turned) - heading_in, -PI, PI))
	out["share"] = deg_to_rad(float(out["swung"])) / maxf(asked, 1e-4)
	out["slip"] = rad_to_deg(wrapf(_track(turned) - _heading(turned), -PI, PI))
	out["speed"] = Vector2((turned.get("velocity", Vector3.ZERO) as Vector3).x,
		(turned.get("velocity", Vector3.ZERO) as Vector3).z).length()
	# WINGS LEVEL, THEN FULL RIGHT PEDAL for three seconds.
	_hold(server, client, craft, hover, -6.0, 0.0, 0.0, 4.0)
	var yaw_peak: float = 0.0
	for i in range(int(3.0 / DT)):
		_hands(server, client, craft, hover, -6.0, 0.0, 0.0, false, 1.0)
		var st: Dictionary = server.vehicle_state(craft)
		yaw_peak = maxf(yaw_peak, -(st.get("spin", Vector3.ZERO) as Vector3).dot(
			Basis(st.get("basis", Quaternion.IDENTITY) as Quaternion).y))
	out["pedal"] = yaw_peak / maxf(float(h.get("yaw_rate", 1.0)), 1e-4)
	_let_go(server)
	_let_go(client)
	return out


func _hold(server: Object, client: Object, craft: int, hover: float, pitch: float, bank: float, climb: float,
		seconds: float, keep_heading: bool = false) -> void:
	var heading: float = _heading(server.vehicle_state(craft))
	for i in range(int(seconds / DT)):
		_hands(server, client, craft, hover, pitch, bank, climb, keep_heading, NAN, heading)


## A PILOT'S HANDS for one frame: the stick to the attitude asked for (degrees, + nose up, + right bank), the collective
## to the climb asked for, and the pedals either centred, held at `pedal`, or holding `heading`.
func _hands(server: Object, client: Object, craft: int, hover: float, pitch: float, bank: float, climb: float,
		keep_heading: bool = false, pedal: float = NAN, heading: float = NAN) -> void:
	var state: Dictionary = server.vehicle_state(craft)
	var basis := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
	var spin: Vector3 = state.get("spin", Vector3.ZERO)
	var nose_up: float = rad_to_deg(asin(clampf(-basis.z.y, -1.0, 1.0)))
	var right_down: float = rad_to_deg(asin(clampf(-basis.x.y, -1.0, 1.0)))
	var vs: float = (state.get("velocity", Vector3.ZERO) as Vector3).y
	var rudder: float = 0.0
	if not is_nan(pedal):
		rudder = pedal
	elif keep_heading and not is_nan(heading):
		var off: float = rad_to_deg(wrapf(_heading(state) - heading, -PI, PI))
		rudder = clampf(-off * 0.05 + spin.dot(basis.y) * 0.5, -1.0, 1.0)
	client.set_input(_controls({
		"throttle": clampf(hover + (climb - vs) * 0.12, 0.0, 1.0),
		"pitch": clampf((pitch - nose_up) * 0.08 - spin.dot(basis.x) * 0.6, -1.0, 1.0),
		"roll": clampf((bank - right_down) * 0.06 - spin.dot(-basis.z) * 0.4, -1.0, 1.0),
		"rudder": rudder}))
	_pair(server, client)


## HEADING and TRACK, radians, 0 along -Z and increasing to the right.
func _heading(state: Dictionary) -> float:
	var nose: Vector3 = -Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion).z
	return atan2(nose.x, -nose.z)


func _track(state: Dictionary) -> float:
	var v: Vector3 = state.get("velocity", Vector3.ZERO)
	return atan2(v.x, -v.z)


func _world(id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(60.0)
	world.start(id)
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


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
