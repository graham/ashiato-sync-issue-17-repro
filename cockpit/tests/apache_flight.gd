extends Node
## Headless: THE AH-64D APACHE FLIES, through the pilot's own controls. Read RESULT=.
##
##   Godot --headless --path cockpit res://tests/apache_flight.tscn
##
## THE USER'S SECOND STANDARD (2026-09-17): a craft must fly well. The brief named the manoeuvres for this one -- lift-off,
## a hover, a cruise near the published figure, a coordinated turn and a clean touchdown on the tailwheel gear -- so a
## pilot is seated in the Apache and flies them through the frame the wire carries from a seated player's rig
## (`set_pilot_input`: the collective on the lever, the cyclic as pitch and roll, the pedals as rudder), with the same
## steady proportional robot and gains as `tests/handling.gd` and `tests/littlebird_flight.gd`. Each manoeuvre has a floor.
##
## THE FLOORS, and what they are reasoned from:
##   LIFT       off the ground on the collective in under 3 s, and a best climb of at least 6 m/s -- [W] gives a vertical
##              climb of 1,775 ft/min (9.0 m/s) on a standard day.
##   HOVER      hands off the cyclic and the pedals for 5 s at the hover: attitude wanders under 8 degrees and the
##              craft drifts under 8 m.
##   SPEED      15 degrees nose down for 45 s, height held on the collective: between 65 and 90 m/s. [W] gives a 143 kt
##              (73.6 m/s) cruise and a 158 kt (81.3 m/s) top speed.
##   TURN       a 30-degree bank at speed with the feet still: the flight path must turn at at least 85 per cent of a
##              coordinated turn's g tan(bank) / v at the speed it is flying (lane/rotors' helicopter turn).
##   LANDING    slowed to a hover, let down at 0.8 m/s for the last 15 m: touches under 2 m/s, upright, at rest on its
##              wheels at its box's floor.
##
## A number this suite prints that sits under its floor is the finding, not the floor's.

const TICK: float = 1.0 / 120.0
const GROUND_HALF: float = 40000.0
const CLIENT: int = 60
const K_PITCH: float = 2.5
const K_BANK: float = 2.5
const IDLE: float = 0.002

const LIFT_SECONDS: float = 3.0
const CLIMB_AT_LEAST: float = 6.0
const HOVER_WANDER_DEG: float = 8.0
const HOVER_DRIFT_M: float = 8.0
const SPEED_BETWEEN: Vector2 = Vector2(65.0, 90.0)
const TURN_SHARE: float = 0.85
const TOUCH_UNDER: float = 2.0

var _world: Object = null
var _pilot: int = 0
var _craft: int = 0
var _h: Dictionary = {}
var _t: float = 0.0
var _input: Dictionary = {}
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[apache_flight] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	var kind: int = Sim.Kind.APACHE
	var hy: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	var seated: bool = _begin(kind, Vector3(0.0, hy + 0.3, 0.0))
	_check("a_pilot_is_seated_in_the_apache", seated and int(Sim.geometry_of(kind).get("model", -1)) == Sim.Model.HELICOPTER,
		"vehicle %d, pilot %d, model %s" % [_craft, _pilot, Sim.geometry_of(kind).get("model_name", "?")])
	if not seated:
		_finish()
		return
	_step(1.0)
	var r: Dictionary = _read()
	var y0: float = (r["at"] as Vector3).y
	# ---- LIFT: full collective, straight up to 60 m ----
	var t0: float = _t
	var lift_t: float = -1.0
	var best_vy: float = 0.0
	while _t - t0 < 20.0 and (r["at"] as Vector3).y < y0 + 60.0:
		_input["throttle"] = 1.0
		_fly(r, 0.0, 0.0)
		_input["rudder"] = _yaw_for_heading(r, 0.0)
		_step(TICK * 4.0)
		r = _read()
		best_vy = maxf(best_vy, float(r["vy"]))
		if lift_t < 0.0 and (r["at"] as Vector3).y > y0 + 1.0:
			lift_t = _t - t0
	_check("it_lifts_off_on_the_collective_and_climbs", lift_t >= 0.0 and lift_t < LIFT_SECONDS and best_vy >= CLIMB_AT_LEAST,
		"off the ground in %.2f s (under %.1f), best climb %.1f m/s (at least %.1f)" % [lift_t, LIFT_SECONDS, best_vy, CLIMB_AT_LEAST])
	# ---- HOVER: settle, then hands off the cyclic and pedals ----
	var hold_y: float = (r["at"] as Vector3).y
	t0 = _t
	# SETTLED FIRST: the hands come off a craft at rest in the air, not one still sliding from the climb. The first run
	# took them off after a fixed 12 s and blamed the aircraft for 10.6 m of drift the settle had left it with.
	while _t - t0 < 40.0 and (_t - t0 < 8.0 or float(r["ground_speed"]) > 0.2 or absf(float(r["vy"])) > 0.2):
		_input["throttle"] = _collective(r, clampf(0.4 * (hold_y - (r["at"] as Vector3).y), -3.0, 3.0))
		_fly(r, clampf(2.0 * float(r["along"]), -10.0, 10.0), clampf(-2.0 * float(r["side"]), -10.0, 10.0))
		_input["rudder"] = _yaw_for_heading(r, 0.0)
		_step(TICK * 4.0)
		r = _read()
	var p0: Dictionary = r
	var wander: float = 0.0
	t0 = _t
	while _t - t0 < 5.0:
		_input["throttle"] = _collective(r, clampf(0.4 * (hold_y - (r["at"] as Vector3).y), -3.0, 3.0))
		_input["pitch"] = 0.0
		_input["roll"] = 0.0
		_input["rudder"] = 0.0
		_step(TICK * 4.0)
		r = _read()
		wander = maxf(wander, maxf(absf(float(r["pitch"]) - float(p0["pitch"])), absf(float(r["bank"]) - float(p0["bank"]))))
	var drift: float = ((r["at"] as Vector3) - (p0["at"] as Vector3)).length()
	_check("it_holds_a_hover_hands_off", wander < HOVER_WANDER_DEG and drift < HOVER_DRIFT_M,
		"5 s hands off at %.0f m: attitude wandered %.1f deg (under %.0f), drifted %.1f m (under %.0f)"
			% [hold_y - y0, wander, HOVER_WANDER_DEG, drift, HOVER_DRIFT_M])
	# ---- FORWARD FLIGHT: 15 degrees nose down, height held on the collective ----
	var fastest: float = 0.0
	t0 = _t
	while _t - t0 < 45.0:
		_input["throttle"] = _collective(r, clampf(0.3 * (hold_y - (r["at"] as Vector3).y), -3.0, 3.0))
		_fly(r, -15.0, 0.0)
		_input["rudder"] = _yaw_for_heading(r, 0.0)
		_step(TICK * 4.0)
		r = _read()
		fastest = maxf(fastest, float(r["ground_speed"]))
	var height_kept: float = (r["at"] as Vector3).y - hold_y
	_check("it_flies_forward_at_an_apaches_speed", fastest >= SPEED_BETWEEN.x and fastest <= SPEED_BETWEEN.y,
		"15 degrees nose down for 45 s: %.1f m/s (%.0f kt; between %.0f and %.0f m/s), height %+.0f m"
			% [fastest, fastest * 1.944, SPEED_BETWEEN.x, SPEED_BETWEEN.y, height_kept])
	# ---- A BANKED TURN: feet still, then half pedal into it ----
	var banked: Dictionary = _turn(hold_y, 0.0)
	var pedal: Dictionary = _turn(hold_y, 0.5)
	# A COORDINATED TURN'S RATE IS g tan(bank) / v, so the floor is a share of it at the speed actually flown: a fixed
	# 6 deg/s, written for 50 m/s, failed a turn at 68 m/s that was 99 per cent coordinated.
	var coordinated: float = rad_to_deg(9.81 * tan(deg_to_rad(30.0)) / maxf(float(banked["speed"]), 1.0))
	_check("a_bank_turns_it_with_the_feet_still", float(banked["rate"]) >= TURN_SHARE * coordinated,
		"30 degrees of bank at %.0f m/s, feet still: the flight path turns %.1f deg/s, %.0f %% of the coordinated %.1f (at least %.0f %%), radius %.0f m; with half pedal %.1f deg/s"
			% [float(banked["speed"]), float(banked["rate"]), 100.0 * float(banked["rate"]) / coordinated, coordinated,
				100.0 * TURN_SHARE, float(banked["radius"]), float(pedal["rate"])])
	# ---- LANDING: slow to a hover, let down, touch ----
	var land: Dictionary = _land(hy)
	_check("it_lands_on_its_wheels", bool(land["ok"]), String(land["said"]))
	_end()
	_finish()


## ---- the world and the pilot's frame, as `tests/handling.gd` has them --------------------------------------------------

func _begin(kind: int, at: Vector3) -> bool:
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(GROUND_HALF, 400.0, GROUND_HALF))
	_h = _world.handling(kind)
	var made: Dictionary = _world.spawn_pilot(CLIENT, kind, at, 0.0, Vector3.ZERO)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_input = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	return _craft != 0 and _pilot != 0


func _end() -> void:
	if _world != null:
		_world.teardown()
		_world = null


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
	var flat := Vector3(v.x, 0.0, v.z)
	return {
		"at": s.get("position", Vector3.ZERO) as Vector3, "v": v, "along": v.dot(nose), "ground_speed": flat.length(),
		"vy": v.y, "side": v.dot(right), "up": (b * Vector3.UP).y,
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"bank": rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))),
		"heading": rad_to_deg(atan2(-nose.x, -nose.z)),
		"track": rad_to_deg(atan2(-v.x, -v.z)) if flat.length() > 0.5 else rad_to_deg(atan2(-nose.x, -nose.z)),
	}


func _fly(r: Dictionary, pitch_to: float, bank_to: float) -> void:
	var pr: float = rad_to_deg(float(_h.get("pitch_rate", 1.0)))
	var rr: float = rad_to_deg(float(_h.get("roll_rate", 1.0)))
	_input["pitch"] = clampf(K_PITCH * (pitch_to - float(r["pitch"])) / maxf(pr, 1.0), -1.0, 1.0)
	_input["roll"] = clampf(K_BANK * (bank_to - float(r["bank"])) / maxf(rr, 1.0), -1.0, 1.0)


func _hover_throttle() -> float:
	return clampf((1.0 - float(_h.get("hover", 1.0))) / maxf(float(_h.get("collective_range", 1.0)), 0.01), 0.0, 1.0)


func _collective(r: Dictionary, vy_to: float) -> float:
	return clampf(_hover_throttle() + 0.25 * (vy_to - float(r["vy"])), IDLE, 1.0)


func _yaw_for_heading(r: Dictionary, heading_to: float) -> float:
	var yr: float = rad_to_deg(float(_h.get("yaw_rate", 1.0)))
	var err: float = rad_to_deg(angle_difference(deg_to_rad(float(r["heading"])), deg_to_rad(heading_to)))
	return clampf(-2.0 * err / maxf(yr, 1.0), -1.0, 1.0)


## 20 s at 30 degrees of right bank, 10 degrees nose down, height held; the rate is the flight path's over the last 10 s.
## `rudder` is the pedal, positive into the turn.
func _turn(hold_y: float, rudder: float) -> Dictionary:
	var r: Dictionary = _read()
	var t0: float = _t
	var was: float = float(r["track"])
	var turned: float = 0.0
	var counted: float = 0.0
	var speeds: float = 0.0
	var n: int = 0
	while _t - t0 < 20.0:
		_input["throttle"] = _collective(r, clampf(0.3 * (hold_y - (r["at"] as Vector3).y), -3.0, 3.0))
		_fly(r, -10.0, 30.0)
		_input["rudder"] = rudder
		_step(TICK * 4.0)
		r = _read()
		var d: float = rad_to_deg(angle_difference(deg_to_rad(was), deg_to_rad(float(r["track"]))))
		was = float(r["track"])
		if _t - t0 > 10.0:
			turned += absf(d)
			counted += TICK * 4.0
			speeds += float(r["ground_speed"])
			n += 1
	var rate: float = turned / maxf(counted, 0.01)
	var speed: float = speeds / maxf(1.0, float(n))
	return {"rate": rate, "speed": speed, "radius": speed / maxf(deg_to_rad(rate), 0.0001)}


func _land(hy: float) -> Dictionary:
	var r: Dictionary = _read()
	var t0: float = _t
	while _t - t0 < 40.0 and float(r["ground_speed"]) > 1.5:
		_input["throttle"] = _collective(r, 0.0)
		_fly(r, clampf(1.5 * float(r["along"]), -5.0, 20.0), clampf(-2.0 * float(r["side"]), -10.0, 10.0))
		_input["rudder"] = 0.0
		_step(TICK * 4.0)
		r = _read()
	var touched: bool = false
	var touch_vy: float = 0.0
	var touch_speed: float = 0.0
	t0 = _t
	while _t - t0 < 200.0:
		var y: float = (r["at"] as Vector3).y - hy
		_input["throttle"] = _collective(r, -3.0 if y > 15.0 else -0.8) if not touched else IDLE
		_fly(r, clampf(1.5 * float(r["along"]), -5.0, 10.0), clampf(-2.0 * float(r["side"]), -10.0, 10.0))
		_step(TICK * 2.0)
		r = _read()
		y = (r["at"] as Vector3).y - hy
		if not touched and y < 0.6:
			touched = true
			touch_vy = float(r["vy"])
			touch_speed = float(r["ground_speed"])
			t0 = _t - 195.0
	var rest: float = (r["at"] as Vector3).y - hy
	var upright: bool = float(r["up"]) > 0.95
	var ok: bool = touched and touch_vy > -TOUCH_UNDER and upright and absf(rest) < 0.3
	return {"ok": ok, "said": "touched %s at %.2f m/s down (under %.1f) and %.1f m/s across; at rest %.2f m off its wheels' height, %s"
		% ["down" if touched else "NEVER", -touch_vy, TOUCH_UNDER, touch_speed, rest, "upright" if upright else "NOT upright"]}


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
