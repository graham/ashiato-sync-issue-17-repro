class_name LittleBirdCircuitPilot
extends RefCounted
## A SMOOTH LITTLE BIRD PILOT for the airfield circuit.
##
## FAA Helicopter Flying Handbook ch.9 and AIM 4-3-3: 500 ft AGL, closer in than
## fixed-wing, five named legs, nose along the track, a 7-12 degree final, then a
## hover a few feet up and a vertical settle. Pedals hold heading; cyclic holds
## attitude; collective holds the slope. The stick is rate-limited so it cannot
## slam a 90-degree heading error into 32 degrees of bank in one tick -- that is
## what made the first circuit look like a series of skids.
##
## Used by `littlebird_circuit.gd` (the proof) and `littlebird_circuit_reel.gd`
## (the picture). One pilot, two seats.

const IDLE: float = 0.002
const PATTERN_FT: float = 152.4
const OFFSET: float = 280.0
const RUNWAY_HALF: float = 450.0
const STRIP_HALF: float = 22.5
const CRUISE: float = 18.0
const HEADING_RATE: float = 9.0
const BANK_MOST: float = 16.0
const PITCH_MOST: float = 10.0
const SLEW_STICK: float = 0.9
const SLEW_THROTTLE: float = 0.28
const APPROACH_DEG: float = 10.0
const HOVER_AGL: float = 4.0
const PAD := Vector3(0.0, 0.0, 250.0)

var handling: Dictionary = {}
var hy: float = 1.3
var leg: String = "ground"
var lifted: bool = false
var at_height: bool = false
var on_downwind: bool = false
var landed: bool = false
var max_y: float = 0.0
var downwind_x: float = 0.0
var touch_vy: float = 0.0
var nose_ok_s: float = 0.0
var nose_fast_s: float = 0.0
var _heading_to: float = 0.0
var _pitch: float = 0.0
var _roll: float = 0.0
var _rudder: float = 0.0
var _throttle: float = IDLE
var _started: bool = false


func begin(h: Dictionary, skid_height: float, heading: float) -> void:
	handling = h
	hy = skid_height
	_heading_to = heading
	leg = "climb"


func step(r: Dictionary, dt: float) -> Dictionary:
	_note(r, dt)
	if not _started:
		_started = true
		_heading_to = float(r["heading"])
	_pick_leg(r)
	var want := _wanted(r)
	_heading_to = _slew_heading(_heading_to, float(want["heading"]), HEADING_RATE * dt)
	var pitch_to: float = clampf(float(want["pitch"]), -PITCH_MOST, PITCH_MOST)
	var bank_to: float = clampf(float(want["bank"]), -BANK_MOST, BANK_MOST)
	var thr_to: float = clampf(float(want["throttle"]), IDLE, 1.0)
	var yaw_to: float = _yaw_for_heading(r, _heading_to)
	_pitch = move_toward(_pitch, _stick(r, pitch_to, "pitch", "pitch_rate"), SLEW_STICK * dt)
	_roll = move_toward(_roll, _stick(r, bank_to, "bank", "roll_rate"), SLEW_STICK * dt)
	_rudder = move_toward(_rudder, yaw_to, SLEW_STICK * dt)
	_throttle = move_toward(_throttle, thr_to, SLEW_THROTTLE * dt)
	return {
		"throttle": _throttle, "pitch": _pitch, "roll": _roll, "rudder": _rudder, "brake": 0.0,
	}


func _pick_leg(r: Dictionary) -> void:
	var at: Vector3 = r["at"]
	var y: float = at.y - hy
	match leg:
		"climb":
			if y > PATTERN_FT * 0.85 and at.z < -RUNWAY_HALF - 80.0:
				leg = "crosswind"
		"crosswind":
			if at.x < -OFFSET + 25.0:
				leg = "downwind"
		"downwind":
			# HFH: turn when the landing point is about 45 degrees behind the abeam.
			if at.z > PAD.z + 120.0 and at.x > -OFFSET - 80.0:
				leg = "base"
		"base":
			if at.x > -40.0 and at.z > PAD.z + 40.0:
				leg = "final"
		"final":
			if at.z < PAD.z + 70.0 and absf(at.x) < 30.0 and float(r["ground_speed"]) < 6.0:
				leg = "hover"
		"hover":
			if absf(at.x - PAD.x) < 16.0 and absf(at.z - PAD.z) < 22.0 and float(r["ground_speed"]) < 2.5 and y < HOVER_AGL + 2.5:
				leg = "land"


func _wanted(r: Dictionary) -> Dictionary:
	match leg:
		"climb":
			return _cruise(r, 0.0, 0.0, PATTERN_FT, CRUISE * 0.7)
		"crosswind":
			# West in this heading: 90 is -X. Fly out to the downwind line.
			return _cruise(r, 90.0, -OFFSET, PATTERN_FT, CRUISE)
		"downwind":
			return _cruise(r, 180.0, -OFFSET, PATTERN_FT, CRUISE)
		"base":
			# East, toward the centreline: heading -90.
			return _cruise(r, -90.0, 0.0, 90.0, 14.0)
		"final":
			return _final(r)
		"hover":
			return _hover(r, PAD, HOVER_AGL)
		"land":
			return _settle(r)
	return _cruise(r, 0.0, 0.0, PATTERN_FT, CRUISE)


func _cruise(r: Dictionary, heading: float, x_hold: float, height: float, speed_to: float) -> Dictionary:
	var at: Vector3 = r["at"]
	var along: float = float(r["along"])
	var x_err: float = at.x - x_hold
	# Nose along the leg, a few degrees of intercept to hold the line. Not a turn toward a corner.
	# Heading 0 looks north: too far east (x_err > 0) wants heading toward 90 (west).
	# Heading 180 looks south: the same error wants the opposite intercept.
	var intercept: float = 0.0
	if heading == 0.0 or heading == 180.0:
		intercept = clampf(x_err * 0.14, -8.0, 8.0)
		if heading == 180.0:
			intercept = -intercept
	var heading_to: float = heading + intercept
	# Bank against the real nose, not the slewed command: a 90-degree heading change
	# used to yaw the nose while the disc kept going, which is a skid.
	var heading_err: float = rad_to_deg(angle_difference(deg_to_rad(float(r["heading"])), deg_to_rad(heading_to)))
	# This heading increases to the LEFT (0 north, 90 west). Left wing down is negative roll.
	var bank: float = clampf(-heading_err * 0.85, -BANK_MOST, BANK_MOST)
	var pitch: float = clampf(-(speed_to - along) * 0.55, -PITCH_MOST, 6.0)
	var vy_to: float = clampf(0.35 * (height - at.y), -2.2, 3.5)
	return {"heading": heading_to, "pitch": pitch, "bank": bank, "throttle": _collective(r, vy_to)}


func _final(r: Dictionary) -> Dictionary:
	# HFH: 7-12 degree slope, nose on the landing, decelerate to a brisk walk.
	var at: Vector3 = r["at"]
	var along: float = float(r["along"])
	var to_pad := Vector2(PAD.x - at.x, PAD.z - at.z)
	var dist: float = to_pad.length()
	var slope: float = tan(deg_to_rad(APPROACH_DEG))
	var height_to: float = hy + clampf(dist * slope, HOVER_AGL, PATTERN_FT)
	var heading_to: float = 0.0
	if dist > 8.0:
		heading_to = rad_to_deg(atan2(-to_pad.x, -to_pad.y))
		heading_to = clampf(heading_to, -12.0, 12.0)
	var speed_to: float = clampf(dist * 0.045, 2.5, 12.0)
	var heading_err: float = rad_to_deg(angle_difference(deg_to_rad(float(r["heading"])), deg_to_rad(heading_to)))
	var bank: float = clampf(-heading_err * 0.5 + (-at.x) * 0.08, -10.0, 10.0)
	var pitch: float = clampf(-(speed_to - along) * 0.7, -6.0, 8.0)
	var vy_to: float = clampf(0.4 * (height_to - at.y), -2.5, 1.5)
	return {"heading": heading_to, "pitch": pitch, "bank": bank, "throttle": _collective(r, vy_to)}


func _body_to(r: Dictionary, pad: Vector3) -> Vector2:
	var at: Vector3 = r["at"]
	var hdg: float = deg_to_rad(float(r["heading"]))
	var to := Vector3(pad.x - at.x, 0.0, pad.z - at.z)
	var nx := -sin(hdg)
	var nz := -cos(hdg)
	var rx := cos(hdg)
	var rz := -sin(hdg)
	return Vector2(to.x * nx + to.z * nz, to.x * rx + to.z * rz)


func _hover(r: Dictionary, pad: Vector3, agl: float) -> Dictionary:
	var to_body: Vector2 = _body_to(r, pad)
	# Aft cyclic as it closes: HFH "rate of closure equivalent to a brisk walk".
	var pitch: float = clampf(-(0.28 * to_body.x - 1.15 * float(r["along"])), -8.0, 8.0)
	var bank: float = clampf(0.28 * to_body.y - 1.15 * float(r["side"]), -8.0, 8.0)
	var vy_to: float = clampf(0.4 * (hy + agl - (r["at"] as Vector3).y), -1.0, 1.2)
	return {"heading": 0.0, "pitch": pitch, "bank": bank, "throttle": _collective(r, vy_to)}


func _settle(r: Dictionary) -> Dictionary:
	var at: Vector3 = r["at"]
	var y: float = at.y - hy
	var to_body: Vector2 = _body_to(r, PAD)
	var pitch: float = clampf(-(0.22 * to_body.x - 1.2 * float(r["along"])), -5.0, 5.0)
	var bank: float = clampf(0.22 * to_body.y - 1.2 * float(r["side"]), -5.0, 5.0)
	var vy_to: float = -0.55 if y > 1.6 else 0.0
	var thr: float = _collective(r, vy_to)
	if y > 1.6:
		thr = clampf(thr - 0.04, IDLE, 1.0)
	return {"heading": 0.0, "pitch": pitch, "bank": bank, "throttle": thr}


func _note(r: Dictionary, dt: float) -> void:
	var at: Vector3 = r["at"]
	max_y = maxf(max_y, at.y)
	if at.y > hy + 2.0:
		lifted = true
	if at.y > PATTERN_FT * 0.75:
		at_height = true
	if at.x < -OFFSET * 0.55 and float(r["ground_speed"]) > 8.0 and (r["v"] as Vector3).z > 3.0:
		on_downwind = true
		downwind_x = minf(downwind_x, at.x)
	if float(r["ground_speed"]) > 8.0:
		nose_fast_s += dt
		var track: float = rad_to_deg(atan2(-(r["v"] as Vector3).x, -(r["v"] as Vector3).z))
		var slip: float = absf(rad_to_deg(angle_difference(deg_to_rad(float(r["heading"])), deg_to_rad(track))))
		if slip < 25.0:
			nose_ok_s += dt
	if lifted and at.y < hy + 3.5 and float(r["ground_speed"]) < 4.0 and absf(float(r["vy"])) < 2.5:
		if not landed:
			touch_vy = float(r["vy"])
		landed = true


func _stick(r: Dictionary, attitude_to: float, key: String, rate_key: String) -> float:
	var rate: float = rad_to_deg(float(handling.get(rate_key, 1.0)))
	return clampf(1.4 * (attitude_to - float(r[key])) / maxf(rate, 1.0), -1.0, 1.0)


func _yaw_for_heading(r: Dictionary, heading_to: float) -> float:
	var yr: float = rad_to_deg(float(handling.get("yaw_rate", 1.0)))
	var err: float = rad_to_deg(angle_difference(deg_to_rad(float(r["heading"])), deg_to_rad(heading_to)))
	return clampf(-1.1 * err / maxf(yr, 1.0), -1.0, 1.0)


func _collective(r: Dictionary, vy_to: float) -> float:
	var hover: float = clampf((1.0 - float(handling.get("hover", 1.0))) / maxf(float(handling.get("collective_range", 1.0)), 0.01), 0.0, 1.0)
	return clampf(hover + 0.22 * (vy_to - float(r["vy"])), IDLE, 1.0)


func _slew_heading(from_deg: float, to_deg: float, step: float) -> float:
	var err: float = rad_to_deg(angle_difference(deg_to_rad(from_deg), deg_to_rad(to_deg)))
	var next: float = from_deg + clampf(err, -step, step)
	while next > 180.0:
		next -= 360.0
	while next < -180.0:
		next += 360.0
	return next
