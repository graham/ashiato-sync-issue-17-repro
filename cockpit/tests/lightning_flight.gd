extends Node
## Headless: DOES THE F-35B DO WHAT AN F-35B IS FOR -- go straight up, hover, turn into an aeroplane, come back, and land
## straight down, on the ground and on a ship -- flown through a seated pilot's own control frame. Read RESULT=.
##
##   Godot --headless --fixed-fps 120 --path cockpit res://tests/lightning_flight.tscn
##
## THROUGH THE REAL PATH. `set_pilot_input` is the frame the wire carries from a seated player's rig: the stick as pitch
## and roll, the rudder, the lever as throttle, and the NOZZLE as a bus command on the tilt channel, which is where the
## nozzle lever in the cockpit sends it. Nothing below that is called. The robot's hands are `tests/handling.gd`'s
## proportional loops with its gains; a craft a plain loop cannot hover is one a person in a headset will fight.
##
## EACH CHECK IS A MEASUREMENT WITH A STATED TOLERANCE, and each prints what it measured so the numbers can be argued
## with:
## - A VERTICAL TAKE-OFF: nozzle down, full power, off flat ground: 30 m within 20 s.
## - A HOVER HELD: at 50 m, ten seconds after five to settle, height within HOVER_HEIGHT of the mark and the drift over
##   the ground under HOVER_DRIFT.
## - A TRANSITION: from that hover, the nozzle wound aft over fifteen seconds at full power, height held on the stick:
##   wing-borne at the end, the nozzle aft and faster than the wing's own flying speed, never lower than 20 m.
## - A SHORT TAKE-OFF: the nozzle at half its travel, full power, down a runway: off the ground in under 0.6 of the roll a
##   conventional take-off needs, both measured here.
## - A VERTICAL LANDING ON THE GROUND and ON THE CARRIER'S DECK: from a hover, down at a metre a second, touching at
##   under VL_SINK and resting upright where it touched. The sink it touched at is printed: it is the number the
##   combat lane's crash rule is told, so a vertical landing counts as a landing.
## And the AI flying it conventionally is `tests/climb.gd`'s, which hands every Airplane and Tiltrotor kind to its
## autopilot, from the ground and from the air: the F-35B is one of them from kind 32.

const TICK: float = 1.0 / 120.0
const GROUND_HALF: float = 40000.0
const CLIENT: int = 60
const K_PITCH: float = 2.5
const K_BANK: float = 2.5
const K_HEADING: float = 1.2
const HOVER_AT: float = 50.0
const HOVER_HEIGHT: float = 1.0
const HOVER_DRIFT: float = 2.0
const VL_SINK: float = 2.0

var _world: Object = null
var _pilot: int = 0
var _craft: int = 0
var _h: Dictionary = {}
var _t: float = 0.0
var _seq: int = 0
var _input: Dictionary = {}
var _failures: PackedStringArray = []
var _hy: float = 0.0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lightning_flight] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	_hy = float((Sim.geometry_of(Sim.Kind.LIGHTNING).get("extents", Vector3.ONE) as Vector3).y)
	_a_vertical_take_off()
	_a_hover_held_then_a_transition()
	_a_short_take_off()
	_a_vertical_landing_on_the_ground()
	_a_vertical_landing_on_the_carrier()
	_end()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


## ---- the checks ------------------------------------------------------------------------------------------------------

func _a_vertical_take_off() -> void:
	_begin(Vector3(0.0, _hy + 0.1, 0.0), Vector3.ZERO, true)
	_command(Sim.Channel.TILT, _hover_tilt())
	_step(1.0)
	var y0: float = (_read()["at"] as Vector3).y
	var r: Dictionary = _read()
	var t0: float = _t
	var best_vy: float = 0.0
	var at30: float = -1.0
	while _t - t0 < 20.0:
		_input["throttle"] = 1.0
		_hands(r, 0.0, 0.0)
		_step(TICK * 4.0)
		r = _read()
		best_vy = maxf(best_vy, float(r["vy"]))
		if at30 < 0.0 and (r["at"] as Vector3).y > y0 + 30.0:
			at30 = _t - t0
	_check("a_vertical_take_off", at30 > 0.0,
		"nozzle down, full power: 30 m up after %s, best climb %.1f m/s; the LiftSystem's 186 kN over %.0f kg is %.3f g"
			% ["%.1f s" % at30 if at30 > 0.0 else "NEVER", best_vy, _mass(), _lift_margin()])


func _a_hover_held_then_a_transition() -> void:
	_begin(Vector3(0.0, HOVER_AT, 0.0), Vector3.ZERO, true)
	_command(Sim.Channel.TILT, _hover_tilt())
	var r: Dictionary = _read()
	var mark: Vector3 = r["at"]
	# FIVE SECONDS TO SETTLE, then ten measured, the robot holding height on the throttle and position on the stick.
	_hover_to(mark, 5.0)
	var low: float = INF
	var high: float = -INF
	var drift: float = 0.0
	var t0: float = _t
	while _t - t0 < 10.0:
		_hover_to(mark, TICK * 4.0)
		r = _read()
		var at: Vector3 = r["at"]
		low = minf(low, at.y - mark.y)
		high = maxf(high, at.y - mark.y)
		drift = maxf(drift, Vector2(at.x - mark.x, at.z - mark.z).length())
	_check("a_hover_held", maxf(absf(low), absf(high)) <= HOVER_HEIGHT and drift <= HOVER_DRIFT,
		"at %.0f m for 10 s: height %+.2f to %+.2f m (within %.1f), drift over the ground %.2f m (within %.1f), throttle %.2f"
			% [HOVER_AT, low, high, HOVER_HEIGHT, drift, HOVER_DRIFT, float(_input["throttle"])])
	# THE TRANSITION: the nozzle wound aft a step a second over fifteen seconds, full power, the nose held level-ish and
	# the height held on the stick.
	var lowest: float = INF
	for step in range(16):
		_command(Sim.Channel.TILT, int(round(float(_hover_tilt()) * (1.0 - float(step) / 15.0))))
		t0 = _t
		while _t - t0 < 1.0:
			_input["throttle"] = 1.0
			r = _read()
			_hands(r, _pitch_for(r, mark.y, 10.0), 0.0)
			_step(TICK * 4.0)
			lowest = minf(lowest, (_read()["at"] as Vector3).y)
	# And ten seconds more at full power, wing-borne, height held.
	t0 = _t
	while _t - t0 < 10.0:
		_input["throttle"] = 1.0
		r = _read()
		_hands(r, _pitch_for(r, mark.y, 10.0), 0.0)
		_step(TICK * 4.0)
		lowest = minf(lowest, (_read()["at"] as Vector3).y)
	r = _read()
	var tilt: float = float((_world.craft_controls(_craft) as Dictionary).get("tilt", -1.0))
	var flying: float = _flying_speed()
	_check("a_transition_to_wing_borne_flight", tilt < 0.01 and float(r["along"]) > flying and lowest > 20.0,
		"nozzle %.2f after 15 s wound aft; flying at %.1f m/s against the wing's flying speed of %.1f; lowest %.1f m"
			% [tilt, float(r["along"]), flying, lowest])


## THE SHORT TAKE-OFF, against the conventional one flown the same way on the same runway.
func _a_short_take_off() -> void:
	var conventional: float = _roll_to_lift(0)
	var short: float = _roll_to_lift(128)
	_check("a_short_take_off", short > 0.0 and conventional > 0.0 and short < 0.6 * conventional,
		"full power, rotating at once: off the ground after %.0f m with the nozzle at half its travel, %.0f m with it aft (%.0f%%)"
			% [short, conventional, 100.0 * short / maxf(conventional, 1.0)])


## How far the aeroplane rolls before its wheels are 3 m up, with the nozzle at `tilt`/255, the stick back for 10 degrees.
func _roll_to_lift(tilt: int) -> float:
	_begin(Vector3(0.0, _hy + 0.1, 0.0), Vector3.ZERO, true)
	_command(Sim.Channel.TILT, tilt)
	_step(1.0)
	var from: Vector3 = _read()["at"]
	var t0: float = _t
	while _t - t0 < 60.0:
		_input["throttle"] = 1.0
		var r: Dictionary = _read()
		_hands(r, 10.0, 0.0)
		_step(TICK * 4.0)
		var at: Vector3 = _read()["at"]
		if at.y > from.y + 3.0:
			return Vector2(at.x - from.x, at.z - from.z).length()
	return -1.0


func _a_vertical_landing_on_the_ground() -> void:
	_begin(Vector3(0.0, 30.0, 0.0), Vector3.ZERO, true)
	var land: Dictionary = _land_vertically(0.0)
	_check("a_vertical_landing_on_the_ground", bool(land["ok"]), String(land["said"]))


## ON THE CARRIER: a Ford sitting in the sea, the F-35B hovering 25 m over its deck, and down.
func _a_vertical_landing_on_the_carrier() -> void:
	_begin(Vector3(0.0, 80.0, 0.0), Vector3.ZERO, false)
	var ship: int = int(_world.spawn_ai_vehicle(Sim.Kind.CARRIER, Vector3(0.0, 0.0, 0.0), 0.0, Vector3.ZERO))
	_step(3.0)
	var s: Dictionary = _world.vehicle_state(ship)
	if s.is_empty():
		_check("a_vertical_landing_on_the_carrier", false, "no carrier")
		return
	var deck_box: Vector3 = Sim.geometry_of(Sim.Kind.CARRIER).get("extents", Vector3.ONE)
	var deck: float = (s["position"] as Vector3).y + deck_box.y
	# OVER THE DECK, at the landing spot's height plus 25 m, moved there by setting the aeroplane's own state is not the
	# real path; so it is spawned there instead, in a fresh world with the carrier.
	_begin(Vector3(0.0, deck + 25.0 + _hy, -30.0), Vector3.ZERO, false)
	ship = int(_world.spawn_ai_vehicle(Sim.Kind.CARRIER, Vector3(0.0, 0.0, 0.0), 0.0, Vector3.ZERO))
	var land: Dictionary = _land_vertically(deck, ship)
	_check("a_vertical_landing_on_the_carrier", bool(land["ok"]), "deck %.1f m over the sea; %s" % [deck, land["said"]])


## A VERTICAL LANDING from wherever the aeroplane is: nozzle down, hold the spot, come down at a metre a second, and
## after touching stay there five seconds. `floor` is the surface's height; `ship` a vehicle whose motion is subtracted.
func _land_vertically(floor: float, ship: int = 0) -> Dictionary:
	_command(Sim.Channel.TILT, _hover_tilt())
	var mark: Vector3 = _read()["at"]
	_hover_to(mark, 4.0)
	var sink: float = -1.0
	var t0: float = _t
	var touched_at := Vector3.ZERO
	# THE SINK IT TOUCHES AT is the fastest it came down over the last second before its descent stopped within a metre of
	# the surface. Not "when its box reaches the surface": with power still on, the aeroplane stands on its gear 0.57 m
	# over the height its box rests at with the engine idle (measured), so a touch is the descent stopping, not a height.
	var recent: Array[float] = []
	while _t - t0 < 60.0:
		var r: Dictionary = _read()
		var at: Vector3 = r["at"]
		var height: float = at.y - _hy - floor
		var vy: float = float(r["vy"]) - (float((_world.vehicle_state(ship).get("velocity", Vector3.ZERO) as Vector3).y) if ship != 0 else 0.0)
		recent.append(-vy)
		if recent.size() > 30:
			recent.pop_front()
		if height < 1.0 and vy > -0.05 and recent.max() > 0.3:
			sink = float(recent.max())
			touched_at = at
			break
		# Down at a metre a second, slowing to half that for the last two metres.
		var want: float = -1.0 if height > 2.0 else -0.5
		_input["throttle"] = _collective(vy, want)
		_hold_spot(r, Vector3(mark.x, at.y, mark.z))
		_step(TICK * 4.0)
	# Throttle to idle, hands off, five seconds on the surface.
	var t1: float = _t
	while _t - t1 < 5.0:
		_input["throttle"] = 0.002
		_input["pitch"] = 0.0
		_input["roll"] = 0.0
		_input["rudder"] = 0.0
		_step(TICK * 4.0)
	var r: Dictionary = _read()
	var at: Vector3 = r["at"]
	var upright: bool = float(r["up"]) > 0.95
	var rest: float = (r["v"] as Vector3).length() if ship == 0 else ((r["v"] as Vector3) - (_world.vehicle_state(ship).get("velocity", Vector3.ZERO) as Vector3)).length()
	var on: bool = absf(at.y - _hy - floor) < 0.6
	var ok: bool = sink >= 0.0 and sink <= VL_SINK and upright and on and rest < 0.5
	return {"ok": ok, "sink": sink,
		"said": "touched at %s down, %s, resting %.2f m over the surface at %.2f m/s, %.1f m from where it touched"
			% ["%.2f m/s" % sink if sink >= 0.0 else "NEVER", "upright" if upright else "NOT UPRIGHT (up %.2f)" % float(r["up"]),
				at.y - _hy - floor, rest, Vector2(at.x - touched_at.x, at.z - touched_at.z).length()]}


## ---- the robot's hands ------------------------------------------------------------------------------------------------

## HOLD A POINT IN THE HOVER: height on the throttle, position on the stick (nose down to go forward, bank to slide), the
## heading on the rudder -- for `seconds`.
func _hover_to(mark: Vector3, seconds: float) -> void:
	var t0: float = _t
	while _t - t0 < seconds - 0.0001:
		var r: Dictionary = _read()
		var at: Vector3 = r["at"]
		_input["throttle"] = _collective(float(r["vy"]), clampf(0.6 * (mark.y - at.y), -2.0, 2.0))
		_hold_spot(r, mark)
		_step(TICK * 4.0)


## The stick and rudder that move the aeroplane towards `mark` over the ground, as a helicopter's would: a tilt of the
## thrust for a velocity wanted, which is a distance wanted times a gain.
func _hold_spot(r: Dictionary, mark: Vector3) -> void:
	var at: Vector3 = r["at"]
	var v: Vector3 = r["v"]
	var basis: Basis = r["basis"]
	var to: Vector3 = Vector3(mark.x - at.x, 0.0, mark.z - at.z)
	var want_v: Vector3 = to.limit_length(8.0) * 0.4
	var error: Vector3 = want_v - Vector3(v.x, 0.0, v.z)
	var forward: Vector3 = basis * Vector3.FORWARD
	var right: Vector3 = basis * Vector3.RIGHT
	# Degrees of pitch and bank for a velocity error: nose down (negative pitch) to go forward.
	var pitch_to: float = clampf(-error.dot(Vector3(forward.x, 0.0, forward.z).normalized()) * 2.0, -10.0, 10.0)
	var bank_to: float = clampf(error.dot(Vector3(right.x, 0.0, right.z).normalized()) * 2.0, -10.0, 10.0)
	_hands(r, pitch_to, bank_to)
	_input["rudder"] = clampf(-float(r["heading"]) * K_HEADING / 30.0, -1.0, 1.0)


## A THROTTLE FOR A VERTICAL SPEED, around the hover's own point on the lever: `hover + throttle x collective_range`
## is the thrust as a share of the weight, so the lever that holds 1 g is (1 - hover) / collective_range.
func _collective(vy: float, vy_to: float) -> float:
	var hold: float = (1.0 - float(_h.get("hover", 0.0))) / maxf(float(_h.get("collective_range", 1.0)), 0.01)
	return clampf(hold + 0.25 * (vy_to - vy), 0.002, 1.0)


func _hands(r: Dictionary, pitch_to: float, bank_to: float) -> void:
	var rates: Vector2 = Vector2(rad_to_deg(float(_h.get("pitch_rate", 1.0))), rad_to_deg(float(_h.get("roll_rate", 1.0))))
	_input["pitch"] = clampf((pitch_to - float(r["pitch"])) * K_PITCH / rates.x, -1.0, 1.0)
	_input["roll"] = clampf((bank_to - float(r["bank"])) * K_BANK / rates.y, -1.0, 1.0)


func _pitch_for(r: Dictionary, height_to: float, most: float) -> float:
	return clampf(0.25 * (height_to - (r["at"] as Vector3).y) - 1.2 * float(r["vy"]), -most, most)


## ---- the world ----------------------------------------------------------------------------------------------------

func _begin(at: Vector3, velocity: Vector3, ground: bool) -> void:
	_end()
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	if ground:
		_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(GROUND_HALF, 400.0, GROUND_HALF))
	_h = _world.handling(Sim.Kind.LIGHTNING)
	var made: Dictionary = _world.spawn_pilot(CLIENT, Sim.Kind.LIGHTNING, at, 0.0, velocity)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_t = 0.0
	_seq = 0
	_input = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}


func _end() -> void:
	if _world != null:
		_world.teardown()
		_world = null


## A BUS COMMAND on a new sequence number, never 0 (handling.gd's `_command`, and its reason).
func _command(channel: int, value: int) -> void:
	_seq = _seq % 3 + 1
	_input["command_channel"] = channel
	_input["command_value"] = value
	_input["command_seq"] = _seq


func _step(seconds: float) -> void:
	var n: int = maxi(1, int(round(seconds / TICK)))
	for i in range(n):
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
		"at": s.get("position", Vector3.ZERO) as Vector3, "v": v, "vy": v.y, "along": v.dot(nose), "basis": b,
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"bank": rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))),
		"heading": rad_to_deg(atan2(-nose.x, -nose.z)),
		"up": (b * Vector3.UP).y,
	}


## THE LEVER THAT POINTS THE THRUST STRAIGHT UP: 90 degrees of the kind's `vector_travel`, as a byte on the tilt channel.
## A PILOT HOVERS HERE, NOT AT THE STOP. At the full 95 degrees the thrust leans 5 degrees aft, 8.7 per cent of the weight
## pushing the aeroplane backwards, and the first run of this suite drifted 8.4 m in ten seconds against a proportional
## hold, as a real one would if its pilot did not trim. The stop is for backing up, as the Osprey's 97.5 is.
func _hover_tilt() -> int:
	return int(round(255.0 * (PI * 0.5) / float(_h.get("vector_travel", PI * 0.5))))


func _mass() -> float:
	return float(Sim.geometry_of(Sim.Kind.LIGHTNING).get("mass", 1.0))


## The most the thrust can be with the nozzle down, as a share of the weight: `hover + collective_range`.
func _lift_margin() -> float:
	return float(_h.get("hover", 0.0)) + float(_h.get("collective_range", 0.0))


## THE WING'S FLYING SPEED, the simulation's own definition (`flying_speed` in cockpit_world.cpp): the speed at which the
## wing carries the weight with the nose on the horizon, weight = camber x v^2 x lift, and 15 per cent over it. Asked of
## the handling the world uses, so the transition's bar moves with the wing and not with a typed number.
func _flying_speed() -> float:
	return sqrt(_mass() * 9.81 / maxf(float(_h.get("camber", 0.0)) * float(_h.get("lift", 1.0)), 0.0001)) * 1.15
