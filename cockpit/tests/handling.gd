extends Node
## Headless: HOW DOES EVERY CRAFT FLY, DRIVE OR SAIL, when somebody sits in it and works the controls?
##
##   Godot --headless --path cockpit res://tests/handling.tscn [-- --kind=cessna]
##
## NOBODY HAD FLOWN ONE. `climb` and `trim` hand an aeroplane to its AUTOPILOT, `air` drops one with nobody in it,
## `soaring` measures a sink rate -- and the user's standard of 2026-09-17 makes "flies well" the second of four things
## every craft must be. So this sits a pilot in each kind and flies a circuit through the pilot's own control frame
## (`set_pilot_input`, the frame the wire carries from a seated player's rig -- stick as pitch and roll, twist or
## pedals as rudder, the lever as throttle, and a bus command for tilt), the way a steady human would:
##
##   AEROPLANE    parked, full power, rotate at 1.2 x the stall, climb at 10 degrees nose-up, level at 300 m, full
##                power level for the top speed, a full-stick roll, a 45-degree level turn, a power-off slow-down
##                for the stall, and an approach and landing on the same flat ground.
##   HELICOPTER   off the ground on the collective, full-collective climb, nose down for the top speed, a
##                30-degree turn, hands off for five seconds, and a vertical landing.
##   TILTROTOR    up as a helicopter, nacelles forward, the aeroplane's level, roll and turn, and back.
##   GROUND       full throttle for the top speed and 0-15 m/s, a full-lock turning circle, and a stop.
##   SHIP         full ahead for the top speed, a full-rudder turning circle. A sailing ship in a 10 m/s wind.
##
## THE ROBOT IS A STEADY PILOT, NOT A GOOD ONE: proportional loops on pitch, bank and heading with the gains written
## here and never tuned per craft. A craft that a plain loop cannot fly is one a person in a headset will fight, which
## is the finding. Where the robot and the craft disagree about a sign, the log says so: every leg records what the
## machine did, not what it was told.
##
## A REPORT, AND A GATE ONLY FOR SHIPS. It prints numbers and a one-line verdict per craft, and fails if a kind it should
## have flown produced no measurement at all -- or, since lane/boats (2026-09-18), if a powered hull capsizes, porpoises,
## or leans the wrong way: a boat with `lean` in its handling must lean INTO a full-rudder turn and come back upright,
## and a ship without it must not lean in at all (`_ship`, the gates at its end). What "fun" means is said in `craft_review.md`, from these numbers.
## THE TRAIN IS DRIVEN on a straight 60 km track laid for it, with a driver seated in the cab: the tower is a building.
##
## THE GEAR COMES UP after take-off and goes down for the approach, through the GEAR channel as a pilot's switch would
## (2026-09-17, `lane/handling`). Until then the robot flew every retractable aeroplane with its wheels hanging, and the
## gear's drag was nearly all of why the F/A-18 topped out at 104 m/s: 8.5 + 11 of drag against 196 kN is 100.
##
## THE TABLE AT THE END is the one `craft_review.md` item 1 and 3 are judged by: per aeroplane, thrust-to-weight, the
## top speed clean, the 45-degree turn held on the horizon as a share of g tan(bank) / v, the same turn pulled, and the
## time for a STEEP 360 (70 degrees of bank, pulled, height held), and the g of the stick yanked fully back at speed.
##
## `-- --set=key*2,key=0.5` RETUNES whatever it flies through `set_handling` before the craft is spawned (a factor with
## `*`, a value with `=`), so a handling number can be measured without a C++ build. Use it with `--kind=`.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const GROUND_HALF: float = 40000.0
const CLIENT: int = 60
## Loop gains, one set for every craft. Stick is a RATE demand in this game (`command_rate`), so each is "per second
## of error": a 10-degree error asks for 10 x gain degrees a second, as a fraction of the craft's own full rate.
const K_PITCH: float = 2.5
const K_BANK: float = 2.5
const K_HEADING: float = 1.2
## Altitude hold: degrees of nose per metre of error, and per m/s of climb.
const K_ALT: float = 0.25
const K_VY: float = 1.2
## A HAND THAT TRIMS, for a stick that is a SURFACE rather than a rate (a kind on its lifting surfaces flown raw,
## `augmentation` under a half: lane/flightmodel). There a centred stick is a centred elevator, and holding a nose-high
## attitude takes a steady back pressure a proportional hand never supplies: the first raw Cessna "could not hold its
## height below 34.9 m/s" against a stall of 26.1 because the robot let the nose sag, not because the wing gave up. A pilot
## holds the pressure and trims it out, and this is that: the pitch error integrated, stick per degree-second, capped at
## full travel. Zero, and nothing changes, for every craft whose stick asks for a rate.
const K_TRIM: float = 0.05
## AND AN ELEVATOR'S GAIN on such a stick, stick per degree: full stick for twelve degrees of pitch error. `K_PITCH` is
## scaled by the kind's pitch RATE, which a surface has none of, and on the raw Cessna it came to a third of this: the
## nose lagged a power-off slow-down from 66 m/s until it sank past 2 m/s at 35.6, where a trace of the same aeroplane
## flown by a firmer hand broke at 26 m/s and 16 to 18 degrees of alpha -- its stall.
const K_PITCH_SURFACE: float = 0.08
## AND THE DAMPING ON IT, stick per degree a second of pitch rate: the nose moving is what a hand answers before the
## attitude has gone (`_fly`).
const K_PITCH_DAMP: float = 0.02
const LEVEL_AT: float = 300.0
## The power-off stall is flown up here, with the height to recover under it.
const STALL_AT: float = 1000.0
## THE LEVER PULLED TO ITS STOP. A frame throttle at or under 0.001 is "the hand is not on it" and the lever HOLDS where
## it was (`cockpit_world.cpp`, "A CONTINUOUS THROTTLE INPUT MOVES THE LEVER"), so a robot that sends 0.0 to close the
## throttle leaves it open. The first run did exactly that: no aeroplane slowed for its stall, no approach came down and
## every helicopter climbed 900 m on a collective set to "hold". A hand dragging a lever shut passes through the small
## numbers on its way, and this is the last of them.
const IDLE: float = 0.002
## THE SHIP GATES (lane/boats, 2026-09-18). A planing hull leans INTO a full-rudder turn at speed by at least this many
## degrees, and is back within `LEAN_SETTLED` 6-10 s after the helm centres. A hull over `SMALL_BOAT_MASS` (every
## ship) may lean into a turn by no more than `NO_LEAN_IN`: the carrier heels out by 5 as its turn starts and settles
## 2.4 INTO it (measured before the lean existed, 2026-09-18), and that is what it keeps.
## A hull lighter than this is a small boat, which must lean: the patrol boat is 14 t and the combat boat 20, the lightest
## ship (the brig) 220 and the submarine thousands.
const SMALL_BOAT_MASS: float = 100000.0
const LEAN_AT_LEAST: float = 6.0
const LEAN_SETTLED: float = 2.0
## AND A SMALL BOAT CARVES: its leeway through that turn under this many degrees, `cockpit_loopback`'s number for the
## launch ("it tracks, it does not slide").
const LEEWAY_MOST: float = 8.0
const NO_LEAN_IN: float = 4.0
## The most the pitch may swing over the last 20 s flat out, degrees. The swell alone swings the launch 2.3 and the
## patrol boat 4.1 (before the lean, 2026-09-18); a hull porpoising on its own swings far more.
const PORPOISE_MOST: float = 6.0

var _world: Object = null
var _pilot: int = 0
var _craft: int = 0
var _kind: int = 0
var _h: Dictionary = {}
## The trimming hand's integral, stick units. Cleared for each craft.
var _trim: float = 0.0
## A TAILDRAGGER'S three-point rake, degrees, while one is being flown; 0 for every tricycle.
var _rake: float = 0.0
## The pitch at the last look, for the hand's rate term.
var _last_pitch: float = 0.0
var _t: float = 0.0
var _seq: int = 0
var _input: Dictionary = {}
var _failures: PackedStringArray = []
var _verdicts: PackedStringArray = []
var _measured: int = 0
## `--set=` retunes: key -> [is_factor, number].
var _overrides: Dictionary = {}
var _table: PackedStringArray = []


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	var only: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			only = arg.trim_prefix("--kind=")
		if arg.begins_with("--set="):
			for pair in arg.trim_prefix("--set=").split(",", false):
				var factor: bool = pair.contains("*")
				var bits: PackedStringArray = pair.split("*" if factor else "=")
				_overrides[bits[0]] = [factor, float(bits[1])]
			print("[handling] retuned through set_handling: %s" % str(_overrides))
	var expected: int = 0
	for kind in range(Sim.Kind.size()):
		var name: String = Sim.kind_name(kind)
		if not only.is_empty() and name != only:
			continue
		var model: int = int(Sim.geometry_of(kind).get("model", -1))
		# A CRAFT NOBODY MAY BOARD has no pilot's view of its handling: `spawn_pilot` refuses it by design (the brig
		# is the AI's ship). `sailing` measures how the AI sails it.
		if not bool(Sim.geometry_of(kind).get("pilotable", true)):
			print("[handling] %-10s not flown here: not pilotable, by design -- nobody may board it" % name)
			continue
		match model:
			Sim.Model.AIRPLANE:
				expected += 1
				if _thrust_of(kind) <= 0.0:
					_glider(kind)
				else:
					_aeroplane(kind)
			Sim.Model.HELICOPTER:
				expected += 1
				_helicopter(kind)
			Sim.Model.TILTROTOR:
				expected += 1
				_tiltrotor(kind)
			Sim.Model.CAR, 9, Sim.Model.HOVER:
				expected += 1
				_ground(kind, model)
			Sim.Model.BOAT, Sim.Model.SAIL:
				expected += 1
				_ship(kind, model)
			Sim.Model.TRAIN:
				expected += 1
				_train(kind)
			_:
				print("[handling] %-10s not flown here (model %d: a rail or a building)" % [name, model])
		await get_tree().process_frame
	if not _table.is_empty():
		print("[handling] ---- aeroplanes: speed and turns ----")
		print("[handling]   %-10s %5s %8s %7s %8s %10s  %-26s %6s %8s" % ["kind", "T/W", "top m/s", "held %", "pulled %", "steep 360", "steep turn", "yank g", "rudder %"])
		for line in _table:
			print("[handling]   " + line)
	print("[handling] ---- verdicts ----")
	for line in _verdicts:
		print("[handling]   " + line)
	var ok: bool = _measured == expected and expected > 0
	print("[handling] %s every_kind_was_taken_out_and_measured (%d of %d)" % ["PASS" if ok else "FAIL", _measured, expected])
	if not ok:
		_failures.append("every_kind_was_taken_out_and_measured")
	ok = ok and _failures.is_empty()
	print("RESULT=%s" % ("PASS" if ok else "FAIL " + "; ".join(_failures)))
	get_tree().quit(0 if ok else 1)


## An aeroplane with no engine is a sailplane, asked of the handling table rather than of its name.
func _thrust_of(kind: int) -> float:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var thrust: float = float((world.handling(kind) as Dictionary).get("thrust", 0.0))
	world.teardown()
	return thrust


## ---- the world, the seat and the frame ----------------------------------------------------------------------------

func _begin(kind: int, at: Vector3, yaw: float, velocity: Vector3, ground: bool, wind: Vector3 = Vector3.ZERO) -> bool:
	_end()
	_kind = kind
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	if ground:
		_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(GROUND_HALF, 400.0, GROUND_HALF))
	if wind != Vector3.ZERO:
		_world.set_wind(wind, 0.0)
	if not _overrides.is_empty():
		var now: Dictionary = _world.handling(kind)
		var tuned: Dictionary = {}
		for key in _overrides:
			var o: Array = _overrides[key]
			tuned[key] = float(now.get(key, 0.0)) * float(o[1]) if bool(o[0]) else float(o[1])
		_world.set_handling(kind, tuned)
	_h = _world.handling(kind)
	var made: Dictionary = _world.spawn_pilot(CLIENT, kind, at, yaw, velocity)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_t = 0.0
	_seq = 0
	_trim = 0.0
	_input = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	return _craft != 0 and _pilot != 0


func _end() -> void:
	if _world != null:
		_world.teardown()
		_world = null


## A BUS COMMAND, sent on a new sequence number. NEVER 0, and restarted with every world: the server takes a command
## whose number differs from the last it saw from that client, and a fresh world has seen 0. The counter used to run
## on across craft and wrap through 0, so in a fleet run whichever craft drew it never got its gear up -- the airliner
## read 88 m/s and the Hawkeye 121 in the fleet, 112 and 166 flown alone.
func _command(channel: int, value: int) -> void:
	_seq = _seq % 3 + 1
	_input["command_channel"] = channel
	_input["command_value"] = value
	_input["command_seq"] = _seq


func _step(seconds: float = TICK) -> void:
	var n: int = maxi(1, int(round(seconds / TICK)))
	for i in range(n):
		_world.set_pilot_input(_pilot, _input)
		_world.tick(TICK)
		_t += TICK


func _state() -> Dictionary:
	return _world.vehicle_state(_craft) if _world != null else {}


## The craft's attitude and motion, in the words a pilot uses.
func _read() -> Dictionary:
	var s: Dictionary = _state()
	if s.is_empty():
		return {}
	var b := Basis(s.get("basis", Quaternion()) as Quaternion)
	var nose: Vector3 = b * Vector3.FORWARD
	var right: Vector3 = b * Vector3.RIGHT
	var v: Vector3 = s.get("velocity", Vector3.ZERO)
	var flat := Vector3(v.x, 0.0, v.z)
	return {
		"at": s.get("position", Vector3.ZERO) as Vector3,
		"v": v,
		"speed": v.length(),
		"along": v.dot(nose),
		"ground_speed": flat.length(),
		"vy": v.y,
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"bank": rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))),
		"heading": rad_to_deg(atan2(-nose.x, -nose.z)),
		# WHERE IT IS GOING rather than where it points: a helicopter banked with its feet still slides sideways.
		"track": rad_to_deg(atan2(-v.x, -v.z)) if flat.length() > 0.5 else rad_to_deg(atan2(-nose.x, -nose.z)),
		"side": v.dot(right),
		"up": (b * Vector3.UP).y,
	}


## THE ROBOT'S HANDS: stick to hold a pitch and a bank, rudder or bank to hold a heading. All proportional.
func _fly(r: Dictionary, pitch_to: float, bank_to: float, pull: bool = false) -> void:
	var pr: float = rad_to_deg(float(_h.get("pitch_rate", 1.0)))
	var rr: float = rad_to_deg(float(_h.get("roll_rate", 1.0)))
	var ff: float = 0.0
	if pull:
		# A PILOT IN A TURN PULLS, AND FEEDS IN RUDDER. The stick is a RATE demand: centred, it asks for no pitch rate,
		# and a level turn at bank b needs the body to pitch at w sin b and yaw at w cos b (w = g tan b / v). Held on
		# the horizon by attitude alone, a craft is asking its flight controls to resist the turn -- see `_level_turn`.
		# ONLY WHAT THE AEROPLANE DOES NOT ALREADY DO: since lane/handling step 2 a human's bank asks for its own
		# turn in C++ (`coordinated_turn`, `turn_coordination` of it), and feeding it in again here pulled twice.
		var b: float = deg_to_rad(float(r["bank"]))
		var w: float = 9.81 * tan(b) / maxf(float(r["speed"]), 5.0) * (1.0 - clampf(float(_h.get("turn_coordination", 0.0)), 0.0, 1.0))
		ff = rad_to_deg(w * sin(b)) / maxf(pr, 1.0)
		_input["rudder"] = clampf(rad_to_deg(w * cos(b)) / maxf(rad_to_deg(float(_h.get("yaw_rate", 1.0))), 1.0), -1.0, 1.0)
	var error: float = pitch_to - float(r["pitch"])
	if _stick_is_a_surface():
		_trim = clampf(_trim + K_TRIM * error * TICK * 4.0, -1.0, 1.0)
	var gain: float = K_PITCH_SURFACE if _stick_is_a_surface() else K_PITCH / maxf(pr, 1.0)
	# AND A HAND FEELS THE NOSE MOVING. A pure attitude gain with a trimming integral drove a powerful elevator to its
	# stop and back: the P-51 porpoised through 25 degrees in level flight and span in out of a 45-degree turn, where the
	# same hand flies the Cessna steadily, because a fighter's elevator is worth several times as much (lane/warbirds2).
	# The rate is measured from the last look, as a pilot reads the nose against the horizon.
	var rate: float = (float(r["pitch"]) - _last_pitch) / maxf(TICK * 4.0, 1e-3)
	_last_pitch = float(r["pitch"])
	_input["pitch"] = clampf(ff + gain * error - K_PITCH_DAMP * rate + _trim, -1.0, 1.0)
	_input["roll"] = clampf(K_BANK * (bank_to - float(r["bank"])) / maxf(rr, 1.0), -1.0, 1.0)


## Whether this craft's stick moves its surfaces rather than asking for a rate (see `K_TRIM`).
func _stick_is_a_surface() -> bool:
	return float(_h.get("surfaces", 0.0)) > 0.5 and float(_h.get("augmentation", 1.0)) < 0.5


## THE HEADING BACK TO WHERE IT STARTED. The two long legs at the end fly this, because the wire's edge is
## 32 km out and `guard_the_wire_edge` zeroes the velocity across it: with its gear up and six more legs, the Hawkeye
## reached it flying straight north, lost its airspeed at 1,021 m and fell to the ground in twenty seconds.
func _homeward() -> float:
	var at: Vector3 = _read().get("at", Vector3.ZERO)
	return rad_to_deg(atan2(at.x, at.z))


func _bank_for_heading(r: Dictionary, heading_to: float, most: float) -> float:
	# HEADING GROWS TO THE LEFT (a nose at (-sin yaw, 0, -cos yaw)) and a positive bank is the right wing down, so a
	# heading short of the target wants the left wing down: the sign is minus.
	var err: float = rad_to_deg(angle_difference(deg_to_rad(float(r["heading"])), deg_to_rad(heading_to)))
	return clampf(-K_HEADING * err, -most, most)


func _pitch_for_height(r: Dictionary, height_to: float, base: float, most: float) -> float:
	return clampf(base + K_ALT * (height_to - (r["at"] as Vector3).y) - K_VY * float(r["vy"]), -most, most)


func _verdict(kind: int, line: String) -> void:
	_verdicts.append("%-10s %s" % [Sim.kind_name(kind), line])
	_measured += 1


func _say(kind: int, what: String) -> void:
	print("[handling] %-10s %s" % [Sim.kind_name(kind), what])


## ---- an aeroplane ---------------------------------------------------------------------------------------------------

func _aeroplane(kind: int) -> void:
	var hy: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	var glider: bool = false
	_begin(kind, Vector3(0.0, hy + 0.3, 0.0), 0.0, Vector3.ZERO, true)
	glider = float(_h.get("thrust", 0.0)) <= 0.0
	var stall_book: float = float(_h.get("stall_speed", 0.0))
	# A TAILDRAGGER'S THREE-POINT RAKE, degrees, or 0 for a tricycle (`lifting_surfaces`, lane/warbirds2).
	var wing: Dictionary = _world.lifting_surfaces(kind)
	_rake = rad_to_deg(float(wing.get("rest_pitch", 0.0))) if bool(wing.get("taildragger", false)) else 0.0
	var mass: float = float((_world.body_mass(_craft) as Dictionary).get("mass", 0.0))
	_say(kind, "mass %.0f kg, thrust-to-weight %.2f" % [mass, float(_h.get("thrust", 0.0)) / maxf(mass * 9.81, 1.0)])
	_say(kind, "handling: thrust %.0f, pitch %.0f, roll %.0f, yaw %.0f deg/s, stall(book) %.1f m/s, control_reference %.1f"
		% [float(_h.get("thrust", 0.0)), rad_to_deg(float(_h.get("pitch_rate", 0.0))),
			rad_to_deg(float(_h.get("roll_rate", 0.0))), rad_to_deg(float(_h.get("yaw_rate", 0.0))), stall_book,
			float(_h.get("control_reference", 0.0))])
	var notes: PackedStringArray = []
	var flew_off: bool = false
	var take_off: String = "no engine: launched in the air"
	if not glider:
		_input["brake"] = 1.0
		_step(2.0)
		var start: Dictionary = _read()
		var parked_y: float = (start["at"] as Vector3).y
		var from: Vector3 = start["at"]
		_input["brake"] = 0.0
		_input["throttle"] = 1.0
		var lift_t: float = -1.0
		var lift_v: float = 0.0
		var lift_d: float = 0.0
		var rotate: float = maxf(stall_book * 1.2, 15.0)
		var fastest_on_ground: float = 0.0
		var last_heading: float = 0.0
		var t0: float = _t
		while _t - t0 < 90.0:
			var r: Dictionary = _read()
			if r.is_empty():
				break
			var h: float = (r["at"] as Vector3).y - parked_y
			if lift_t < 0.0:
				fastest_on_ground = maxf(fastest_on_ground, float(r["speed"]))
			if lift_t < 0.0 and h > 2.0:
				lift_t = _t - t0
				lift_v = float(r["speed"])
				lift_d = ((r["at"] as Vector3) - from).length()
			if h > 30.0:
				flew_off = true
				# GEAR UP, as a pilot does once climbing away: the squat switch refuses it with weight on the wheels.
				_command(Sim.Channel.GEAR, 0)
				break
			var pitch_to: float = 0.0 if float(r["speed"]) < rotate else 10.0
			if _rake > 0.0:
				# A TAILDRAGGER IS FLOWN OFF AS ITS MANUAL SAYS (lane/warbirds2): the stick back while the rudder has no air
				# over it, then the tail raised to a fifth of its three-point rake, and the pedals holding the runway
				# heading. Flown as a tricycle -- a level attitude asked for from the start, the pedals never touched -- the
				# stick went full forward, which UNLOCKS a P-51's tail wheel, and it ground-looped at 32 m/s every time.
				pitch_to = _rake * 0.2 if float(r["speed"]) < rotate else _rake - 1.5
				_fly(r, pitch_to, 0.0)
				if float(r["speed"]) < 0.35 * stall_book:
					_input["pitch"] = 0.5
				# THE PEDALS HOLD THE RUNWAY HEADING, damped by how fast it is swinging: a taildragger's heading on its
				# wheels is unstable, and an error alone swings it through the line. HEADING GROWS TO THE LEFT here, and a
				# positive rudder yaws the nose right, so the sign is plus.
				var swing: float = rad_to_deg(angle_difference(deg_to_rad(last_heading), deg_to_rad(float(r["heading"]))))
				last_heading = float(r["heading"])
				_input["rudder"] = clampf(0.05 * float(r["heading"]) + 0.9 * swing, -1.0, 1.0)
			else:
				_fly(r, pitch_to, _bank_for_heading(r, 0.0, 10.0))
			_step(TICK * 4.0)
		if flew_off:
			take_off = "off the ground in %.1f s and %.0f m at %.1f m/s" % [lift_t, lift_d, lift_v]
		else:
			take_off = "NEVER LEFT THE GROUND in 90 s (fastest %.1f m/s on the runway, rotate at %.1f)" % [fastest_on_ground, rotate]
			notes.append("cannot take off")
		_say(kind, "take-off: " + take_off)
	if not flew_off:
		var cruise: float = float(_h.get("cruise", maxf(stall_book * 2.0, 40.0)))
		_begin(kind, Vector3(0.0, LEVEL_AT, 0.0), 0.0, Vector3(0.0, 0.0, -maxf(cruise, stall_book * 1.6)), true)
		_input["throttle"] = 1.0
	# ---- climb ----
	var climb: String = "not measured"
	if not glider:
		var t0: float = _t
		var from_y: float = -1.0
		var from_t: float = 0.0
		var slowest: float = INF
		var r: Dictionary = _read()
		while _t - t0 < 150.0 and not r.is_empty() and (r["at"] as Vector3).y < LEVEL_AT:
			var sp: float = float(r["speed"])
			var pitch_to: float = 10.0 - maxf(0.0, (stall_book * 1.3 - sp)) * 2.0
			_fly(r, pitch_to, _bank_for_heading(r, 0.0, 15.0))
			_step(TICK * 4.0)
			r = _read()
			if r.is_empty():
				break
			if (r["at"] as Vector3).y > 50.0 and from_y < 0.0:
				from_y = (r["at"] as Vector3).y
				from_t = _t
			if from_y >= 0.0:
				slowest = minf(slowest, float(r["speed"]))
		if from_y >= 0.0 and not r.is_empty() and _t > from_t + 1.0:
			var rate: float = ((r["at"] as Vector3).y - from_y) / (_t - from_t)
			climb = "%.1f m/s at 10 degrees nose-up, slowest %.0f m/s, %s" % [rate, slowest,
				"reached %.0f m" % LEVEL_AT if (r["at"] as Vector3).y >= LEVEL_AT - 1.0 else "did NOT reach %.0f m in 150 s" % LEVEL_AT]
			if (r["at"] as Vector3).y < LEVEL_AT - 1.0:
				notes.append("weak climb")
		else:
			climb = "never climbed past 50 m"
			notes.append("cannot climb")
		_say(kind, "climb: " + climb)
	# ---- level, full power ----
	# SIXTY SECONDS, because a heavy aeroplane is still accelerating at thirty: the Hawkeye read 103 m/s after 30 s and
	# was doing 128 by the end of its turns (first run, 2026-09-17).
	var level: Dictionary = _hold_level(LEVEL_AT if not glider else (_read()["at"] as Vector3).y, 1.0, 60.0, 0.0)
	var top: float = float(level.get("speed", 0.0))
	_say(kind, "level, full power, 60 s: %.1f m/s (%.0f kt), height swing %.1f m over the last 15 s, pitch %.1f"
		% [top, top * 1.944, float(level.get("swing", 0.0)), float(level.get("pitch", 0.0))])
	var still: float = float(level.get("still_gaining", 0.0))
	if still > 0.3:
		_say(kind, "  and still gaining %.1f m/s every second at the end of it" % still)
	if float(level.get("swing", 0.0)) > 30.0:
		notes.append("porpoises")
	# ---- full-stick roll ----
	var roll_rate: float = _full_roll()
	_say(kind, "full-stick roll: %.0f deg/s" % roll_rate)
	_hold_level(LEVEL_AT, 1.0, 10.0, 0.0)
	# ---- 45-degree turn ----
	var turn: Dictionary = _level_turn(45.0, 30.0)
	_say(kind, "45-degree turn HELD ON THE HORIZON, stick only: %.0f%% of the rate the bank should give"
		% (100.0 * float(turn["rate"]) / maxf(float(turn["ideal"]), 0.01)))
	_say(kind, "45-degree level turn, full power: %.1f deg/s (a level turn at the %.0f degrees held and %.0f m/s is %.1f), radius %.0f m, %.0f s for a 360, lost %.1f m/s and %.0f m"
		% [float(turn["rate"]), float(turn["bank"]), float(turn["speed"]), float(turn["ideal"]), float(turn["radius"]),
			360.0 / maxf(float(turn["rate"]), 0.01), float(turn["speed_lost"]), float(turn["height_lost"])])
	_hold_level(LEVEL_AT, 1.0, 12.0, 0.0)
	var pulled: Dictionary = _level_turn(45.0, 30.0, true)
	_say(kind, "45-degree turn PULLED, with rudder fed in: %.1f deg/s (ideal %.1f), radius %.0f m, %.0f s for a 360, lost %.1f m/s and %.0f m"
		% [float(pulled["rate"]), float(pulled["ideal"]), float(pulled["radius"]), 360.0 / maxf(float(pulled["rate"]), 0.01),
			float(pulled["speed_lost"]), float(pulled["height_lost"])])
	turn["pulled"] = pulled
	_hold_level(LEVEL_AT, 1.0, 12.0, 0.0)
	var hard: Dictionary = _hard_turn(70.0, 120.0)
	_say(kind, "STEEP 360 -- 70 degrees of bank pulled, height held, full power: %s, %+.0f m, slowest %.0f m/s"
		% ["%.1f s" % float(hard["seconds"]) if float(hard["seconds"]) > 0.0 else "only %.0f degrees in 120 s" % float(hard["turned"]),
			-float(hard["height_lost"]), float(hard["slowest"])])
	_hold_level(LEVEL_AT, 1.0, 15.0, 0.0)
	var yank: float = _yank()
	_say(kind, "stick yanked fully back for a second, wings level: %.1f g" % yank)
	_hold_level(LEVEL_AT, 1.0, 20.0, 0.0)
	var pedal: Dictionary = _full_rudder()
	_say(kind, "full rudder, wings held level, 3 s: yaws at %.1f deg/s of the %.0f asked (%.0f%%), %.1f degrees of slip"
		% [float(pedal["rate"]), rad_to_deg(float(_h.get("yaw_rate", 0.0))),
			100.0 * float(pedal["rate"]) / maxf(rad_to_deg(float(_h.get("yaw_rate", 0.0))), 0.01), float(pedal["slip"])])
	_hold_level(LEVEL_AT, 1.0, 15.0, 0.0)
	# ---- the stall, power off ----
	# GEAR DOWN FIRST: a landing-configuration stall, as the review's numbers were, and the approach follows it. With the
	# gear left up the Hawkeye came out of the steep turn at 199 m/s, bled for a minute, stalled, and lost 322 of its 324 m
	# recovering -- the "landing" that followed was the recovery meeting the ground. One second gear-down was not enough:
	# still entering at 199 m/s it bled for a minute, mushed to 10 m/s nose-high and lost the same 322 m. Twenty seconds
	# level with the gear hanging did not help either: the Hawkeye still stalled to 13 m/s and lost 321 m, which is a
	# finding about the Hawkeye (craft_review.md) and not a landing. So the stall is flown at STALL_AT, with room under
	# it to recover, and what the recovery cost is reported.
	_command(Sim.Channel.GEAR, 255)
	_hold_level(STALL_AT, 1.0, 80.0, _homeward())
	var stall: Dictionary = _stall()
	_say(kind, "  the lever read %.3f during the power-off leg" % float(stall.get("lever", -1.0)))
	_say(kind, "power-off stall: %s; %.0f m to recover"
		% ["cannot hold its height below %.1f m/s" % float(stall["slowest"]) if bool(stall["broke"]) else "held its height for 150 s power off",
			float(stall["recovery_lost"])])
	# ---- approach and landing ----
	# BACK DOWN TO LEVEL_AT AND SETTLED, part power, before the approach: begun from STALL_AT the heavies dived in (the
	# Hawkeye touched at 79 m/s down, the Mercury at 31).
	_hold_level(LEVEL_AT, 0.4, 120.0, _homeward())
	var land: Dictionary = _land(maxf(float(stall["slowest"]), stall_book), hy, kind)
	_say(kind, "landing: " + String(land["said"]))
	if not bool(land["ok"]):
		notes.append("landing: " + String(land["short"]))
	_end()
	var fun: String = _aeroplane_feel(roll_rate, turn, top, stall, notes)
	_table.append("%-10s %5.2f %8.1f %7.0f %8.0f %10s  %-26s %6s %8.0f" % [Sim.kind_name(kind),
		float(_h.get("thrust", 0.0)) / maxf(mass * 9.81, 1.0), top,
		100.0 * float(turn["rate"]) / maxf(float(turn["ideal"]), 0.01),
		100.0 * float(pulled["rate"]) / maxf(float(pulled["ideal"]), 0.01),
		"%.1f" % float(hard["seconds"]) if float(hard["seconds"]) > 0.0 else "> 120",
		"%+.0f m, slowest %.0f m/s" % [-float(hard["height_lost"]), float(hard["slowest"])], "%.1f" % yank,
		100.0 * float(pedal["rate"]) / maxf(rad_to_deg(float(_h.get("yaw_rate", 0.0))), 0.01)])
	_verdict(kind, "%s | take-off %s | climb %s | top %.0f m/s | roll %.0f deg/s | 45-deg turn %.1f deg/s nose-held, %.1f pulled (r %.0f m) | stall %.0f m/s | landing %s | %s"
		% ["FLIES" if notes.is_empty() else "FLIES, BUT: " + "; ".join(notes), take_off.get_slice(" at ", 0), climb.get_slice(",", 0),
			top, roll_rate, float(turn["rate"]), float(pulled["rate"]), float(pulled["radius"]), float(stall["slowest"]),
			String(land["short"]), fun])


func _aeroplane_feel(roll: float, turn: Dictionary, top: float, stall: Dictionary, notes: PackedStringArray) -> String:
	var words: PackedStringArray = []
	if roll < 30.0:
		words.append("sluggish in roll")
	elif roll > 200.0:
		words.append("twitchy in roll")
	else:
		words.append("roll %s" % ("brisk" if roll > 90.0 else "steady"))
	var pulled: Dictionary = turn.get("pulled", turn)
	if float(pulled["rate"]) < 5.0:
		words.append("turns wide even pulled")
	if float(turn["rate"]) < 0.7 * float(turn["ideal"]):
		words.append("a bank alone turns it at %.0f%% of the rate" % (100.0 * float(turn["rate"]) / maxf(float(turn["ideal"]), 0.01)))
	if top > 0.0 and float(stall["slowest"]) > 0.0:
		words.append("speed range %.1fx" % (top / float(stall["slowest"])))
	return ", ".join(words)


## LEVEL FLIGHT for `seconds` at `throttle`, holding `height` and heading. Returns the settled speed and the height swing.
func _hold_level(height: float, throttle: float, seconds: float, heading: float) -> Dictionary:
	_input["throttle"] = throttle
	_input["rudder"] = 0.0
	var t0: float = _t
	var lo: float = INF
	var hi: float = -INF
	var speeds: Array[float] = []
	var r: Dictionary = _read()
	while _t - t0 < seconds and not r.is_empty():
		_fly(r, _pitch_for_height(r, height, 2.0, 15.0), _bank_for_heading(r, heading, 30.0))
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		if OS.get_cmdline_user_args().has("--trace") and int(round((_t - t0) / (TICK * 4.0))) % 300 == 0:
			_say(_kind, "  level t%.0f h %.0f v %.1f vy %.1f pitch %.1f bank %.0f" % [_t - t0, (r["at"] as Vector3).y,
				float(r["speed"]), float(r["vy"]), float(r["pitch"]), float(r["bank"])])
		if _t - t0 > seconds * 0.5:
			var y: float = (r["at"] as Vector3).y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		if _t - t0 > seconds - 5.0:
			speeds.append(float(r["speed"]))
	var mean: float = 0.0
	for s in speeds:
		mean += s
	return {"speed": mean / maxf(1.0, float(speeds.size())), "swing": hi - lo if hi > lo else 0.0,
		"still_gaining": (speeds[speeds.size() - 1] - speeds[0]) / 5.0 if speeds.size() > 1 else 0.0,
		"pitch": float(r.get("pitch", 0.0))}


func _full_roll() -> float:
	var fastest: float = 0.0
	var r: Dictionary = _read()
	var was: float = float(r.get("bank", 0.0))
	var t0: float = _t
	_input["pitch"] = 0.0
	while _t - t0 < 1.5 and not r.is_empty():
		_input["roll"] = 1.0
		_step(TICK * 2.0)
		r = _read()
		if r.is_empty():
			break
		var bank: float = float(r["bank"])
		fastest = maxf(fastest, (bank - was) / (TICK * 2.0))
		was = bank
		if bank > 75.0:
			break
	_input["roll"] = 0.0
	return fastest


func _level_turn(bank: float, seconds: float, pull: bool = false) -> Dictionary:
	_input["throttle"] = 1.0
	var r: Dictionary = _read()
	var v0: float = float(r["speed"])
	var y0: float = (r["at"] as Vector3).y
	var t0: float = _t
	var heading_was: float = float(r["heading"])
	var turned: float = 0.0
	var counted: float = 0.0
	var speeds: float = 0.0
	var banks: float = 0.0
	var n: int = 0
	while _t - t0 < seconds and not r.is_empty():
		_fly(r, _pitch_for_height(r, y0, 3.0, 20.0), bank, pull)
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		var hd: float = float(r["heading"])
		var d: float = rad_to_deg(angle_difference(deg_to_rad(heading_was), deg_to_rad(hd)))
		heading_was = hd
		if _t - t0 > seconds * 0.5:
			turned += absf(d)
			counted += TICK * 4.0
			speeds += float(r["speed"])
			banks += absf(float(r["bank"]))
			n += 1
	_input["rudder"] = 0.0
	var rate: float = turned / maxf(counted, 0.01)
	var speed: float = speeds / maxf(1.0, float(n))
	var held: float = banks / maxf(1.0, float(n))
	# WHAT PHYSICS SAYS A LEVEL TURN AT THAT BANK AND SPEED IS: g tan(bank) / v. A craft far under it is not
	# pulling the lift a level turn needs, which is the difference between a turn and a skid.
	var ideal: float = rad_to_deg(9.81 * tan(deg_to_rad(held)) / maxf(speed, 1.0))
	return {"rate": rate, "bank": held, "ideal": ideal, "speed": speed, "radius": speed / maxf(deg_to_rad(rate), 0.0001),
		"speed_lost": v0 - float(r.get("speed", 0.0)),
		"height_lost": y0 - (r.get("at", Vector3.ZERO) as Vector3).y}


## A STEEP 360: 70 degrees of bank, pulled with rudder fed in (`_fly(..., pull = true)`) and the height held, full power,
## until the flight path has come round 360 degrees or `most` seconds pass. Counted on the TRACK, where it is going. The
## clock starts at the roll-in, as a player's does. Physics puts it at 2.9 g and 2 pi v / (g tan 70) seconds, so an
## aeroplane that can hold it is judged by its speed, and one that cannot shows it here first.
##
## NOT A FULL-STICK TURN, AND THAT WAS TRIED FIRST. The stick asks for `pitch_rate` whatever the speed and no aeroplane
## here has a g limit, so stick fully back at 157 m/s is a 20 g pull: the robot's fighter and airliner went over the top
## and tumbled (bank through -38 degrees, 120 m lost in a second), and with the height held on the bank alone the
## fighter "turned 360" in 5.9 s by counting half-loops. `_yank` measures that load instead.
func _hard_turn(bank: float, most: float) -> Dictionary:
	_input["throttle"] = 1.0
	var r: Dictionary = _read()
	var y0: float = (r["at"] as Vector3).y
	var t0: float = _t
	var track_was: float = float(r["track"])
	var turned: float = 0.0
	var slowest: float = INF
	while _t - t0 < most and turned < 360.0 and not r.is_empty():
		_fly(r, _pitch_for_height(r, y0, 3.0, 30.0), bank, true)
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		var tr: float = float(r["track"])
		turned += rad_to_deg(absf(angle_difference(deg_to_rad(track_was), deg_to_rad(tr))))
		track_was = tr
		slowest = minf(slowest, float(r["speed"]))
		if OS.get_cmdline_user_args().has("--trace") and int(round((_t - t0) / (TICK * 4.0))) % 60 == 0:
			_say(_kind, "  steep t%.0f h %+.0f v %.0f vy %.1f bank %.0f pitch %.0f turned %.0f" % [_t - t0,
				(r["at"] as Vector3).y - y0, float(r["speed"]), float(r["vy"]), float(r["bank"]), float(r["pitch"]), turned])
	_input["rudder"] = 0.0
	return {"seconds": _t - t0 if turned >= 360.0 else -1.0, "turned": turned, "slowest": slowest if slowest < INF else 0.0,
		"height_lost": y0 - (r.get("at", Vector3.ZERO) as Vector3).y}


## FULL RUDDER for three seconds with the wings held level: how fast the nose swings, against the `yaw_rate` the pedal
## asks for, and the sideslip it holds. The price of a strong fin is paid here -- a fin that swings the nose into a turn
## also fights a pedal that swings it out -- so any retune of `weathervane` is read against this line.
func _full_rudder() -> Dictionary:
	var r: Dictionary = _read()
	var t0: float = _t
	var heading_was: float = float(r["heading"])
	var turned: float = 0.0
	var counted: float = 0.0
	var slip: float = 0.0
	while _t - t0 < 3.0 and not r.is_empty():
		_input["rudder"] = 1.0
		_input["roll"] = clampf(K_BANK * (0.0 - float(r["bank"])) / maxf(rad_to_deg(float(_h.get("roll_rate", 1.0))), 1.0), -1.0, 1.0)
		_input["pitch"] = clampf(K_PITCH * (_pitch_for_height(r, LEVEL_AT, 2.0, 10.0) - float(r["pitch"]))
			/ maxf(rad_to_deg(float(_h.get("pitch_rate", 1.0))), 1.0), -1.0, 1.0)
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		var hd: float = float(r["heading"])
		var d: float = rad_to_deg(absf(angle_difference(deg_to_rad(heading_was), deg_to_rad(hd))))
		heading_was = hd
		if _t - t0 > 1.5:
			turned += d
			counted += TICK * 4.0
			slip = maxf(slip, rad_to_deg(asin(clampf(absf(float(r["side"])) / maxf(float(r["speed"]), 1.0), 0.0, 1.0))))
	_input["rudder"] = 0.0
	return {"rate": turned / maxf(counted, 0.01), "slip": slip}


## THE STICK YANKED FULLY BACK for one second, wings level, at whatever speed it has: the most load the craft puts on its
## crew, from the change of velocity (lift and thrust, gravity taken out). There is no g limit anywhere in the flight
## model, so this is `pitch_rate` times the speed, whatever the wing.
func _yank() -> float:
	var r: Dictionary = _read()
	var was: Vector3 = r["v"]
	var most: float = 0.0
	var t0: float = _t
	while _t - t0 < 1.0 and not r.is_empty():
		_input["roll"] = clampf(K_BANK * (0.0 - float(r["bank"])) / maxf(rad_to_deg(float(_h.get("roll_rate", 1.0))), 1.0), -1.0, 1.0)
		_input["pitch"] = 1.0
		_step(TICK * 2.0)
		r = _read()
		if r.is_empty():
			break
		var a: Vector3 = ((r["v"] as Vector3) - was) / (TICK * 2.0)
		was = r["v"]
		most = maxf(most, (a - Vector3(0.0, -9.81, 0.0)).length() / 9.81)
	_input["pitch"] = 0.0
	return most


## POWER OFF, NOSE UP TO HOLD THE HEIGHT, until the height cannot be held. The slowest speed at which it still was is the
## stall a pilot meets. Then full power and the nose down, and the height it cost.
func _stall() -> Dictionary:
	_input["throttle"] = IDLE
	var r: Dictionary = _read()
	var y0: float = (r["at"] as Vector3).y
	var slowest: float = INF
	var broke: bool = false
	var t0: float = _t
	var heading: float = float(r["heading"])
	# THE STALL A PILOT MEETS: the airspeed at which, nose as high as 25 degrees and power off, the height can no
	# longer be held -- the first moment it is sinking at 2 m/s. The first version took the slowest speed seen while
	# within 10 m of the start, and read 12 m/s for a Cessna that was already falling nose-high through it.
	var next_trace: float = _t
	while _t - t0 < 150.0 and not r.is_empty():
		_fly(r, _pitch_for_height(r, y0, 4.0, 25.0), _bank_for_heading(r, heading, 5.0))
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		if _t >= next_trace and OS.get_cmdline_user_args().has("--trace"):
			next_trace = _t + 10.0
			_say(_kind, "  power off t%.0f h %.0f v %.1f vy %.1f pitch %.1f" % [_t - t0, (r["at"] as Vector3).y, float(r["speed"]),
				float(r["vy"]), float(r["pitch"])])
		if float(r["vy"]) < -2.0 and _t - t0 > 2.0:
			slowest = float(r["speed"])
			broke = true
			break
	var low: float = (r.get("at", Vector3.ZERO) as Vector3).y
	var lever: float = float((_world.craft_controls(_craft) as Dictionary).get("throttle", -1.0))
	_input["throttle"] = 1.0
	var t1: float = _t
	while _t - t1 < 25.0 and not r.is_empty():
		var sp: float = float(r["speed"])
		_fly(r, -5.0 if sp < slowest * 1.3 else 5.0, 0.0)
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		low = minf(low, (r["at"] as Vector3).y)
		if sp > slowest * 1.4 and float(r["vy"]) > 0.0:
			break
	return {"slowest": slowest if slowest < INF else 0.0, "broke": broke, "recovery_lost": y0 - low, "lever": lever}


## AN APPROACH AND A LANDING on the flat ground under it: pitch for a 3 m/s descent, throttle for 1.3 x the stall a
## steady pilot just met, a flare at 8 m to a metre a second, then idle and brakes.
func _land(stall: float, hy: float, kind: int = -1) -> Dictionary:
	var approach: float = maxf(stall * 1.3, 20.0)
	# GEAR DOWN for the approach. A craft with no gear channel ignores it.
	_command(Sim.Channel.GEAR, 255)
	var integral: float = 0.0
	var r: Dictionary = _read()
	var t0: float = _t
	var touched: bool = false
	var touch_vy: float = 0.0
	var touch_speed: float = 0.0
	var touch_at := Vector3.ZERO
	var bounce: float = 0.0
	var heading: float = float(r["heading"])
	var lowest: float = INF
	var next_trace: float = _t
	while _t - t0 < 400.0 and not r.is_empty():
		if kind >= 0 and _t >= next_trace and OS.get_cmdline_user_args().has("--trace"):
			next_trace = _t + 5.0
			_say(kind, "  approach t%.0f h %.0f v %.1f vy %.1f pitch %.1f thr %.2f" % [_t - t0, (r["at"] as Vector3).y - hy,
				float(r["speed"]), float(r["vy"]), float(r["pitch"]), float(_input["throttle"])])
		var y: float = (r["at"] as Vector3).y - hy
		var sp: float = float(r["speed"])
		if not touched:
			var sink_to: float = -0.7 if y < 4.0 else (-2.0 if y < 25.0 else -4.0)
			var err: float = sink_to - float(r["vy"])
			integral = clampf(integral + err * TICK * 2.0, -20.0, 20.0)
			_fly(r, clampf(2.0 + 3.0 * err + 1.5 * integral, -12.0, 15.0), _bank_for_heading(r, heading, 15.0))
			_input["throttle"] = clampf(0.35 + 0.15 * (approach - sp), IDLE, 1.0) if y > 3.0 else IDLE
		else:
			_input["throttle"] = IDLE
			_input["brake"] = 1.0
			_fly(r, 0.0, 0.0)
		_step(TICK * 2.0)
		r = _read()
		if r.is_empty():
			break
		y = (r["at"] as Vector3).y - hy
		lowest = minf(lowest, y)
		if not touched and y < 0.6:
			touched = true
			touch_vy = float(r["vy"])
			touch_speed = float(r["speed"])
			touch_at = r["at"]
		elif touched:
			bounce = maxf(bounce, y)
			if float(r["speed"]) < 0.5:
				break
	if not touched:
		return {"ok": false, "short": "never reached the ground", "said": "never reached the ground in 400 s (lowest %.0f m, ending at %.1f m/s, %.1f m/s vertical)"
			% [lowest, float(r.get("speed", 0.0)), float(r.get("vy", 0.0))]}
	if r.is_empty():
		return {"ok": false, "short": "craft gone at touchdown", "said": "the craft was gone after touchdown"}
	var roll: float = ((r["at"] as Vector3) - touch_at).length()
	var upright: bool = float(r["up"]) > 0.9
	var hard: bool = touch_vy < -3.0
	var ok: bool = upright and not hard and bounce < 3.0
	var said: String = "touched at %.1f m/s down, %.1f m/s along, %s, rolled %.0f m to a stop, %s" % [-touch_vy, touch_speed,
		"bounced %.1f m" % bounce if bounce > 0.8 else "no bounce", roll, "upright" if upright else "NOT upright (up %.2f)" % float(r["up"])]
	return {"ok": ok, "short": ("clean, %.1f m/s sink, %.0f m roll" % [-touch_vy, roll]) if ok else
		("HARD %.1f m/s" % -touch_vy if hard else ("bounced %.1f m" % bounce if bounce >= 3.0 else "not upright")), "said": said}


## ---- a helicopter ---------------------------------------------------------------------------------------------------

func _hover_throttle() -> float:
	return clampf((1.0 - float(_h.get("hover", 1.0))) / maxf(float(_h.get("collective_range", 1.0)), 0.01), 0.0, 1.0)


## Collective for a vertical speed, around the hover setting.
func _collective(r: Dictionary, vy_to: float) -> float:
	return clampf(_hover_throttle() + 0.25 * (vy_to - float(r["vy"])), IDLE, 1.0)


func _yaw_for_heading(r: Dictionary, heading_to: float) -> float:
	var yr: float = rad_to_deg(float(_h.get("yaw_rate", 1.0)))
	var err: float = rad_to_deg(angle_difference(deg_to_rad(float(r["heading"])), deg_to_rad(heading_to)))
	return clampf(-2.0 * err / maxf(yr, 1.0), -1.0, 1.0)


func _helicopter(kind: int) -> void:
	var hy: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	_begin(kind, Vector3(0.0, hy + 0.3, 0.0), 0.0, Vector3.ZERO, true)
	_say(kind, "handling: hover %.2f, collective_range %.2f (hover at %.2f of the lever), pitch %.0f, roll %.0f, yaw %.0f deg/s"
		% [float(_h.get("hover", 0.0)), float(_h.get("collective_range", 0.0)), _hover_throttle(),
			rad_to_deg(float(_h.get("pitch_rate", 0.0))), rad_to_deg(float(_h.get("roll_rate", 0.0))),
			rad_to_deg(float(_h.get("yaw_rate", 0.0)))])
	var notes: PackedStringArray = []
	_step(1.0)
	var y0: float = (_read()["at"] as Vector3).y
	# ---- full collective, straight up ----
	var t0: float = _t
	var r: Dictionary = _read()
	var best_vy: float = 0.0
	var lift_t: float = -1.0
	while _t - t0 < 20.0 and not r.is_empty() and (r["at"] as Vector3).y < y0 + 100.0:
		_input["throttle"] = 1.0
		_fly(r, 0.0, 0.0)
		_input["rudder"] = _yaw_for_heading(r, 0.0)
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		best_vy = maxf(best_vy, float(r["vy"]))
		if lift_t < 0.0 and (r["at"] as Vector3).y > y0 + 1.0:
			lift_t = _t - t0
	var up: bool = not r.is_empty() and (r["at"] as Vector3).y > y0 + 20.0
	_say(kind, "full collective: %s, best climb %.1f m/s" % ["off in %.1f s" % lift_t if lift_t >= 0.0 else "NEVER LIFTED", best_vy])
	if not up:
		notes.append("cannot lift off")
		_begin(kind, Vector3(0.0, 150.0, 0.0), 0.0, Vector3.ZERO, true)
		r = _read()
	# ---- hover, hands off the cyclic ----
	var hold_y: float = (r["at"] as Vector3).y
	t0 = _t
	while _t - t0 < 15.0 and not r.is_empty():
		_input["throttle"] = _collective(r, clampf(0.4 * (hold_y - (r["at"] as Vector3).y), -3.0, 3.0))
		_fly(r, clampf(2.0 * float(r["along"]), -10.0, 10.0), clampf(-2.0 * float(r["side"]), -10.0, 10.0))
		_input["rudder"] = _yaw_for_heading(r, 0.0)
		_step(TICK * 4.0)
		r = _read()
	hold_y = (r["at"] as Vector3).y
	var p0: Dictionary = r
	t0 = _t
	var drift_pitch: float = 0.0
	var drift_bank: float = 0.0
	while _t - t0 < 5.0 and not r.is_empty():
		_input["throttle"] = _collective(r, clampf(0.4 * (hold_y - (r["at"] as Vector3).y), -3.0, 3.0))
		_input["pitch"] = 0.0
		_input["roll"] = 0.0
		_input["rudder"] = 0.0
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		drift_pitch = maxf(drift_pitch, absf(float(r["pitch"]) - float(p0["pitch"])))
		drift_bank = maxf(drift_bank, absf(float(r["bank"]) - float(p0["bank"])))
	var wander: float = ((r["at"] as Vector3) - (p0["at"] as Vector3)).length() if not r.is_empty() else 0.0
	_say(kind, "hands off at the hover, 5 s: attitude wandered %.1f deg pitch, %.1f deg bank; drifted %.1f m"
		% [drift_pitch, drift_bank, wander])
	# ---- nose down for speed ----
	var fastest: float = 0.0
	t0 = _t
	while _t - t0 < 30.0 and not r.is_empty():
		_input["throttle"] = _collective(r, clampf(0.3 * (hold_y - (r["at"] as Vector3).y), -3.0, 3.0))
		_fly(r, -15.0, 0.0)
		_input["rudder"] = _yaw_for_heading(r, 0.0)
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		fastest = maxf(fastest, float(r["ground_speed"]))
	var held: float = (r["at"] as Vector3).y - hold_y if not r.is_empty() else 0.0
	_say(kind, "15 degrees nose down, 30 s: %.1f m/s (%.0f kt), height %+.0f m" % [fastest, fastest * 1.944, held])
	# ---- a 30-degree turn at speed ----
	var turn_r: Dictionary = _heli_turn(r, hold_y)
	r = _read()
	_say(kind, "30-degree bank, feet still, -10 degrees pitch: flight path turns %.1f deg/s, radius %.0f m" % [float(turn_r["rate"]), float(turn_r["radius"])])
	var pedal: Dictionary = _heli_turn(r, hold_y, -0.5)
	r = _read()
	_say(kind, "the same with half left pedal: flight path turns %.1f deg/s, radius %.0f m" % [float(pedal["rate"]), float(pedal["radius"])])
	if float(turn_r["rate"]) < 2.0:
		notes.append("banking alone does not turn it (%.1f deg/s; %.1f with pedal)" % [float(turn_r["rate"]), float(pedal["rate"])])
	# ---- slow down and land vertically ----
	var land: Dictionary = _heli_land(hy)
	_say(kind, "landing: " + String(land["said"]))
	if not bool(land["ok"]):
		notes.append("landing: " + String(land["short"]))
	if drift_pitch > 10.0 or drift_bank > 10.0:
		notes.append("unstable hands-off")
	_end()
	_verdict(kind, "%s | climb %.1f m/s | top %.0f m/s | hover hands-off drift %.0f/%.0f deg, %.0f m | turn %.1f deg/s banked, %.1f with pedal | landing %s"
		% ["FLIES" if notes.is_empty() else "FLIES, BUT: " + "; ".join(notes), best_vy, fastest, drift_pitch, drift_bank, wander,
			float(turn_r["rate"]), float(pedal["rate"]), String(land["short"])])


func _heli_turn(r: Dictionary, hold_y: float, rudder: float = 0.0) -> Dictionary:
	var t0: float = _t
	var heading_was: float = float(r["track"])
	var turned: float = 0.0
	var counted: float = 0.0
	var speeds: float = 0.0
	var n: int = 0
	while _t - t0 < 20.0 and not r.is_empty():
		_input["throttle"] = _collective(r, clampf(0.3 * (hold_y - (r["at"] as Vector3).y), -3.0, 3.0))
		_fly(r, -10.0, 30.0)
		_input["rudder"] = rudder
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		var hd: float = float(r["track"])
		var d: float = rad_to_deg(angle_difference(deg_to_rad(heading_was), deg_to_rad(hd)))
		heading_was = hd
		if _t - t0 > 10.0:
			turned += absf(d)
			counted += TICK * 4.0
			speeds += float(r["ground_speed"])
			n += 1
	var rate: float = turned / maxf(counted, 0.01)
	return {"rate": rate, "radius": (speeds / maxf(1.0, float(n))) / maxf(deg_to_rad(rate), 0.0001)}


func _heli_land(hy: float) -> Dictionary:
	var r: Dictionary = _read()
	var t0: float = _t
	# Slow to a hover first.
	while _t - t0 < 30.0 and not r.is_empty() and float(r["ground_speed"]) > 2.0:
		_input["throttle"] = _collective(r, 0.0)
		var along: float = float(r["along"])
		_fly(r, clampf(1.5 * along, -5.0, 20.0), 0.0)
		_input["rudder"] = 0.0
		_step(TICK * 4.0)
		r = _read()
	var touched: bool = false
	var touch_vy: float = 0.0
	t0 = _t
	while _t - t0 < 200.0 and not r.is_empty():
		var y: float = (r["at"] as Vector3).y - hy
		var sink: float = -3.0 if y > 15.0 else -0.8
		_input["throttle"] = _collective(r, sink) if not touched else IDLE
		_fly(r, clampf(1.5 * float(r["along"]), -5.0, 10.0), 0.0)
		_step(TICK * 2.0)
		r = _read()
		if r.is_empty():
			break
		y = (r["at"] as Vector3).y - hy
		if not touched and y < 0.6:
			touched = true
			touch_vy = float(r["vy"])
			t0 = _t - 195.0
	if not touched or r.is_empty():
		return {"ok": false, "short": "never reached the ground", "said": "never reached the ground"}
	var upright: bool = float(r["up"]) > 0.9
	var hard: bool = touch_vy < -2.5
	return {"ok": upright and not hard, "short": ("clean, %.1f m/s sink" % -touch_vy) if upright and not hard
		else ("HARD %.1f m/s" % -touch_vy if hard else "NOT upright"),
		"said": "touched at %.1f m/s down, %s" % [-touch_vy, "upright" if upright else "NOT upright"]}


## ---- a tiltrotor ------------------------------------------------------------------------------------------------------

func _tiltrotor(kind: int) -> void:
	var hy: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	_begin(kind, Vector3(0.0, hy + 0.3, 0.0), 0.0, Vector3.ZERO, true)
	var notes: PackedStringArray = []
	# NACELLES UP, as a pilot would for a vertical take-off: the TILT channel, full.
	_command(Sim.Channel.TILT, 255)
	_step(2.0)
	var tilt: float = float((_world.craft_controls(_craft) as Dictionary).get("tilt", -1.0))
	_say(kind, "handling: hover %.2f, collective_range %.2f, thrust %.0f; nacelles read %.2f after TILT 255"
		% [float(_h.get("hover", 0.0)), float(_h.get("collective_range", 0.0)), float(_h.get("thrust", 0.0)), tilt])
	var y0: float = (_read()["at"] as Vector3).y
	var r: Dictionary = _read()
	var t0: float = _t
	var best_vy: float = 0.0
	while _t - t0 < 25.0 and not r.is_empty() and (r["at"] as Vector3).y < y0 + 120.0:
		_input["throttle"] = 1.0
		_fly(r, 0.0, 0.0)
		_input["rudder"] = _yaw_for_heading(r, 0.0)
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		best_vy = maxf(best_vy, float(r["vy"]))
	var up: bool = not r.is_empty() and (r["at"] as Vector3).y > y0 + 30.0
	_say(kind, "vertical take-off, full power: %s, best climb %.1f m/s" % ["up" if up else "NEVER LIFTED", best_vy])
	if not up:
		notes.append("cannot take off vertically")
		_begin(kind, Vector3(0.0, LEVEL_AT, 0.0), 0.0, Vector3(0.0, 0.0, -80.0), true)
	# ---- transition: nacelles forward over 20 s, nose a little down, height held on the power ----
	var hold_y: float = (_read()["at"] as Vector3).y
	for step in range(21):
		_command(Sim.Channel.TILT, int(255.0 * (1.0 - float(step) / 20.0)))
		t0 = _t
		r = _read()
		while _t - t0 < 1.0 and not r.is_empty():
			_input["throttle"] = 1.0
			_fly(r, _pitch_for_height(r, maxf(hold_y, LEVEL_AT), 0.0, 12.0), _bank_for_heading(r, 0.0, 10.0))
			_step(TICK * 4.0)
			r = _read()
	var level: Dictionary = _hold_level(LEVEL_AT, 1.0, 40.0, 0.0)
	_say(kind, "nacelles forward, level, full power: %.1f m/s (%.0f kt), swing %.1f m" % [float(level["speed"]),
		float(level["speed"]) * 1.944, float(level["swing"])])
	var roll_rate: float = _full_roll()
	_hold_level(LEVEL_AT, 1.0, 10.0, 0.0)
	var turn: Dictionary = _level_turn(45.0, 30.0)
	_hold_level(LEVEL_AT, 1.0, 10.0, 0.0)
	var pulled: Dictionary = _level_turn(45.0, 30.0, true)
	_say(kind, "full-stick roll %.0f deg/s; 45-degree turn %.1f deg/s nose-held, %.1f pulled (ideal %.1f), radius %.0f m"
		% [roll_rate, float(turn["rate"]), float(pulled["rate"]), float(pulled["ideal"]), float(pulled["radius"])])
	_hold_level(LEVEL_AT, 0.5, 15.0, 0.0)
	# ---- back to the hover and down ----
	for step in range(21):
		_command(Sim.Channel.TILT, int(255.0 * float(step) / 20.0))
		t0 = _t
		r = _read()
		while _t - t0 < 1.0 and not r.is_empty():
			_input["throttle"] = _collective(r, clampf(0.3 * (LEVEL_AT - (r["at"] as Vector3).y), -3.0, 3.0))
			_fly(r, _pitch_for_height(r, LEVEL_AT, 3.0, 12.0), 0.0)
			_step(TICK * 4.0)
			r = _read()
	var land: Dictionary = _heli_land(hy)
	_say(kind, "nacelles up, vertical landing: " + String(land["said"]))
	if not bool(land["ok"]):
		notes.append("landing: " + String(land["short"]))
	_end()
	_verdict(kind, "%s | VTOL climb %.1f m/s | top %.0f m/s | roll %.0f deg/s | 45-deg turn %.1f deg/s nose-held, %.1f pulled | landing %s"
		% ["FLIES" if notes.is_empty() else "FLIES, BUT: " + "; ".join(notes), best_vy, float(level["speed"]), roll_rate,
			float(turn["rate"]), float(pulled["rate"]), String(land["short"])])


## ---- on the ground ----------------------------------------------------------------------------------------------------

func _ground(kind: int, model: int) -> void:
	var hy: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	_begin(kind, Vector3(0.0, hy + 0.3, 0.0), 0.0, Vector3.ZERO, true)
	_step(2.0)
	var from: Vector3 = _read()["at"]
	var segway: bool = model == 9
	var r: Dictionary = _read()
	var t0: float = _t
	var to15: float = -1.0
	var fastest: float = 0.0
	while _t - t0 < 30.0 and not r.is_empty():
		_input["throttle"] = 1.0
		if segway:
			_input["pitch"] = -1.0
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		fastest = maxf(fastest, float(r["ground_speed"]))
		if to15 < 0.0 and float(r["ground_speed"]) >= 15.0:
			to15 = _t - t0
	var y_end: float = (r["at"] as Vector3).y - from.y if not r.is_empty() else 0.0
	_say(kind, "full throttle 30 s: %.1f m/s (%.0f km/h), 0-15 m/s %s, height change %+.1f m" % [fastest, fastest * 3.6,
		"%.1f s" % to15 if to15 >= 0.0 else "never", y_end])
	# ---- full lock at 10 m/s (or what it can do) ----
	var target: float = minf(10.0, fastest * 0.7)
	t0 = _t
	var heading_was: float = float(r["heading"])
	var turned: float = 0.0
	var counted: float = 0.0
	var speeds: float = 0.0
	var n: int = 0
	while _t - t0 < 25.0 and not r.is_empty():
		var sp: float = float(r["ground_speed"])
		_input["throttle"] = clampf(0.3 + 0.3 * (target - sp), 0.0, 1.0)
		_input["brake"] = 1.0 if sp > target + 3.0 else 0.0
		if segway:
			_input["pitch"] = clampf(-0.3 - 0.3 * (target - sp), -1.0, 1.0)
		_input["rudder"] = 1.0
		_step(TICK * 4.0)
		r = _read()
		if r.is_empty():
			break
		var hd: float = float(r["heading"])
		var d: float = rad_to_deg(angle_difference(deg_to_rad(heading_was), deg_to_rad(hd)))
		heading_was = hd
		if _t - t0 > 10.0:
			turned += absf(d)
			counted += TICK * 4.0
			speeds += float(r["ground_speed"])
			n += 1
	var rate: float = turned / maxf(counted, 0.01)
	var radius: float = (speeds / maxf(1.0, float(n))) / maxf(deg_to_rad(rate), 0.0001)
	_say(kind, "full lock at %.0f m/s: %.1f deg/s, turning circle %.0f m across" % [target, rate, radius * 2.0])
	# ---- stop from full speed ----
	_input["rudder"] = 0.0
	t0 = _t
	while _t - t0 < 15.0 and not r.is_empty():
		_input["throttle"] = 1.0
		_input["brake"] = 0.0
		if segway:
			_input["pitch"] = -1.0
		_step(TICK * 4.0)
		r = _read()
	var v0: float = float(r.get("ground_speed", 0.0))
	var at0: Vector3 = r.get("at", Vector3.ZERO)
	t0 = _t
	while _t - t0 < 30.0 and not r.is_empty() and float(r["ground_speed"]) > 0.3:
		_input["throttle"] = IDLE
		_input["brake"] = 1.0
		_input["pitch"] = 0.0
		_step(TICK * 4.0)
		r = _read()
	var stop: float = ((r.get("at", Vector3.ZERO) as Vector3) - at0).length()
	_say(kind, "stop from %.1f m/s: %.0f m, %s" % [v0, stop, "upright" if float(r.get("up", 0.0)) > 0.9 else "NOT upright"])
	_end()
	var notes: PackedStringArray = []
	if fastest < 3.0:
		notes.append("DOES NOT MOVE")
	if absf(y_end) > 5.0:
		notes.append("left the ground by %.0f m" % y_end)
	_verdict(kind, "%s | top %.0f m/s | 0-15 %s | full-lock circle %.0f m | stop %.0f m"
		% ["DRIVES" if notes.is_empty() else "DRIVES, BUT: " + "; ".join(notes), fastest,
			"%.1f s" % to15 if to15 >= 0.0 else "never", radius * 2.0, stop])


## ---- on the water --------------------------------------------------------------------------------------------------

func _ship(kind: int, model: int) -> void:
	var sail: bool = model == Sim.Model.SAIL
	var notes: PackedStringArray = []
	var fastest: float = 0.0
	var trim_said: String = ""
	var name: String = Sim.kind_name(kind)
	# A SMALL BOAT PLANES AND LEANS INTO ITS TURNS; A SHIP DOES NOT (lane/boats, 2026-09-18). Which is which is its
	# DISPLACEMENT, asked of the kind's shape -- never of its name, and never of the `lean` in its handling, because a
	# gate that reads the number it is checking cannot fail: the first draft did, and zeroing the launch's lean moved it
	# quietly onto the ship gate and passed.
	var leans: bool = float(Sim.geometry_of(kind).get("mass", 0.0)) < SMALL_BOAT_MASS
	var bow_up: float = 0.0
	var to_top: float = -1.0
	var porpoise: float = 0.0
	if sail:
		# A BRIG ON A BEAM REACH in a steady 10 m/s wind from the north (the air going +Z), nose to the west. The stick
		# trims the main and fore yards (`sail_ship`: pitch the main, roll the fore), so a player finds the trim; the
		# robot tries five and keeps the best, which is what a player does by feel.
		var best_trim: float = 0.0
		for trim in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var seated: bool = _begin(kind, Vector3.ZERO, PI * 0.5, Vector3.ZERO, false)
			_world.set_weather({"from": 0.0, "low": 10.0, "high": 10.0, "veer": 0.0, "seed": 1})
			_input["throttle"] = 1.0
			_input["pitch"] = trim
			_input["roll"] = trim
			_step(60.0)
			var r: Dictionary = _read()
			var sp: float = float(r.get("ground_speed", 0.0))
			_say(kind, "  yards %+.1f: %.1f m/s after 60 s (seated %s, state %s, sail set %.2f)" % [trim, sp, seated,
				"present" if not r.is_empty() else "EMPTY", float((_world.sail_report(_craft) as Dictionary).get("set", -1.0))])
			if sp > fastest:
				fastest = sp
				best_trim = trim
		trim_said = ", best with the yards at %+.1f" % best_trim
		_input["pitch"] = best_trim
		_input["roll"] = best_trim
		_begin(kind, Vector3.ZERO, PI * 0.5, Vector3.ZERO, false)
		_world.set_weather({"from": 0.0, "low": 10.0, "high": 10.0, "veer": 0.0, "seed": 1})
		_input["pitch"] = best_trim
		_input["roll"] = best_trim
		_input["throttle"] = 1.0
		_step(60.0)
	else:
		_begin(kind, Vector3.ZERO, 0.0, Vector3.ZERO, false)
		_step(5.0)
		# THE LEVEL IT FLOATS AT, so the bow rise is measured from the hull's own trim and not from a hull that happens to
		# sit a degree bow-down at rest.
		var rest_pitch: float = float(_read().get("pitch", 0.0))
		_input["throttle"] = 1.0
		var t0: float = _t
		var speeds: Array = []
		var pitches: Array = []
		while _t - t0 < 90.0:
			_step(TICK * 8.0)
			var r: Dictionary = _read()
			if r.is_empty():
				break
			fastest = maxf(fastest, float(r["ground_speed"]))
			bow_up = maxf(bow_up, float(r["pitch"]) - rest_pitch)
			speeds.append([_t - t0, float(r["ground_speed"])])
			pitches.append(float(r["pitch"]))
		# 0 TO 90 PER CENT OF THE TOP: the time a driver waits for the boat to be going, which a flat-out top speed that
		# creeps up its last metre a second for a minute does not hide.
		for s in speeds:
			if float(s[1]) >= 0.9 * fastest:
				to_top = float(s[0])
				break
		# PORPOISING, as the pitch's swing over the last twenty seconds flat out: a planing hull that bounces its bow up
		# and down on its own is the runaway to rule out.
		var tail: Array = pitches.slice(maxi(0, pitches.size() - int(20.0 / (TICK * 8.0))))
		if not tail.is_empty():
			porpoise = float(tail.max()) - float(tail.min())
	var r: Dictionary = _read()
	if r.is_empty():
		_say(kind, "the ship was gone after its run")
		_end()
		_verdict(kind, "GONE -- the ship did not survive a straight run")
		return
	_say(kind, "full ahead%s: %.1f m/s (%.0f kt)%s" % [" on a beam reach in 10 m/s" if sail else " 90 s", fastest,
		fastest * 1.944, trim_said])
	if not sail:
		_say(kind, "  0 to 90%% of top in %.1f s, bow rise %.1f deg, pitch swing flat out %.2f deg" % [to_top, bow_up, porpoise])
	var t1: float = _t
	var heading_was: float = float(r["heading"])
	var turned: float = 0.0
	var counted: float = 0.0
	var sp_sum: float = 0.0
	var n: int = 0
	var heel: float = 0.0
	# THE LEAN, SIGNED: positive is INTO the turn. The right side down is a positive bank, so the lean into a right turn
	# is the bank itself and into a left turn is minus it; which way it turned is read off what the heading did (the
	# heading grows to the left), not assumed from the helm.
	var lean_sum: float = 0.0
	var lean_n: int = 0
	# THE LEEWAY, the angle between where it points and where it goes, through the settled turn: a boat carves, and a
	# keel that gives up under the rudder sends it sideways (`cockpit_loopback`'s "the boat follows its bow", which is
	# where this lane's first launch was caught skidding at 35 degrees).
	var leeway_sum: float = 0.0
	var lowest_up: float = 1.0
	var right_turn: float = 0.0
	while _t - t1 < 90.0:
		_input["rudder"] = 1.0
		_step(TICK * 8.0)
		r = _read()
		if r.is_empty():
			break
		var hd: float = float(r["heading"])
		var d: float = rad_to_deg(angle_difference(deg_to_rad(heading_was), deg_to_rad(hd)))
		heading_was = hd
		heel = maxf(heel, absf(float(r["bank"])))
		lowest_up = minf(lowest_up, float(r["up"]))
		if _t - t1 > 30.0:
			turned += absf(d)
			right_turn += -d
			counted += TICK * 8.0
			sp_sum += float(r["ground_speed"])
			lean_sum += float(r["bank"])
			leeway_sum += absf(rad_to_deg(atan2(float(r["side"]), maxf(absf(float(r["along"])), 0.1))))
			lean_n += 1
			n += 1
	var rate: float = turned / maxf(counted, 0.01)
	var radius: float = (sp_sum / maxf(1.0, float(n))) / maxf(deg_to_rad(rate), 0.0001)
	var lean: float = (lean_sum / maxf(1.0, float(lean_n))) * (1.0 if right_turn >= 0.0 else -1.0)
	var leeway: float = leeway_sum / maxf(1.0, float(lean_n))
	# AND THE HELM CENTRED: the turn stops, and so must the lean. Averaged over 6 to 10 s after, so the swell's own roll
	# (a degree or three on the patrol boat, either way) cancels rather than landing on one sample.
	var settled: float = 0.0
	if not r.is_empty():
		_input["rudder"] = 0.0
		_step(6.0)
		var after_sum: float = 0.0
		var after_n: int = 0
		for i in range(30):
			_step(4.0 / 30.0)
			var after: Dictionary = _read()
			if after.is_empty():
				break
			after_sum += float(after["bank"])
			after_n += 1
			lowest_up = minf(lowest_up, float(after["up"]))
		settled = absf(after_sum / maxf(1.0, float(after_n)))
	_say(kind, "full rudder: %.2f deg/s, turning circle %.0f m across, most heel %.1f deg, lean into the turn %+.1f deg, %.1f deg 6-10 s after the helm centred, leeway %.1f deg"
		% [rate, radius * 2.0, heel, lean, settled, leeway])
	_end()
	if fastest < 1.0:
		notes.append("DOES NOT MOVE")
	if rate < 0.3:
		notes.append("barely turns")
	_verdict(kind, "%s | top %.1f m/s (%.0f kt)%s | full-rudder circle %.0f m | %.0f s for a 360 | heel %.0f deg, lean into the turn %+.0f"
		% ["SAILS" if notes.is_empty() else "SAILS, BUT: " + "; ".join(notes), fastest, fastest * 1.944,
			"" if sail else " in %.0f s to 90%%, bow up %.0f deg" % [to_top, bow_up], radius * 2.0, 360.0 / maxf(rate, 0.001),
			heel, lean])
	if sail:
		return
	# ---- THE GATES (lane/boats, 2026-09-18) -------------------------------------------------------------------------
	# A SMALL BOAT leans INTO a full-rudder turn at speed by at least `LEAN_AT_LEAST`, and comes back upright when the
	# helm centres. A SHIP keeps the few degrees it always settled at. EVERY
	# powered hull stays upright (its mast never past 45 degrees from vertical) and none porpoises flat out.
	if leans:
		_gate(lean >= LEAN_AT_LEAST, "%s leans into a full-rudder turn by %.1f deg, wanted at least %.0f" % [name, lean, LEAN_AT_LEAST])
		_gate(leeway <= LEEWAY_MOST, "%s follows its bow through a full-rudder turn (%.1f deg of leeway, wanted under %.0f)" % [name, leeway, LEEWAY_MOST])
		_gate(settled <= LEAN_SETTLED, "%s is %.1f deg over 6-10 s after the helm centred, wanted under %.0f" % [name, settled, LEAN_SETTLED])
	else:
		_gate(lean <= NO_LEAN_IN, "%s leans into its turn by %.1f deg, wanted under %.0f: a ship does not bank like a boat" % [name, lean, NO_LEAN_IN])
	_gate(lowest_up >= cos(deg_to_rad(45.0)), "%s stayed upright (its mast at least %.2f of vertical, wanted %.2f)" % [name, lowest_up, cos(deg_to_rad(45.0))])
	_gate(porpoise <= PORPOISE_MOST, "%s holds its trim flat out (pitch swing %.2f deg, wanted under %.1f)" % [name, porpoise, PORPOISE_MOST])


## A gate the ship section holds: a failure makes the suite red, and a pass is printed with its number.
func _gate(ok: bool, what: String) -> void:
	print("[handling] %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


## ---- a sailplane -----------------------------------------------------------------------------------------------------

## NO ENGINE, SO NO TAKE-OFF: released at 600 m and 30 m/s as off a winch or a tow. Glide for the sink rate at a steady
## nose attitude, roll, a 30-degree thermalling turn, and a landing.
func _glider(kind: int) -> void:
	var hy: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	_begin(kind, Vector3(0.0, 600.0, 0.0), 0.0, Vector3(0.0, 0.0, -30.0), true)
	var notes: PackedStringArray = []
	_say(kind, "handling: pitch %.0f, roll %.0f deg/s, control_reference %.1f" % [rad_to_deg(float(_h.get("pitch_rate", 0.0))),
		rad_to_deg(float(_h.get("roll_rate", 0.0))), float(_h.get("control_reference", 0.0))])
	var best_sink: float = -INF
	var best_at: float = 0.0
	var best_speed: float = 0.0
	for nose in [-2.0, -4.0, -6.0, -8.0]:
		var t0: float = _t
		var r: Dictionary = _read()
		var y_from: float = 0.0
		while _t - t0 < 20.0 and not r.is_empty():
			_fly(r, nose, _bank_for_heading(r, 0.0, 10.0))
			_step(TICK * 4.0)
			r = _read()
			if _t - t0 > 8.0 and y_from == 0.0:
				y_from = (r["at"] as Vector3).y
		var sink: float = ((r["at"] as Vector3).y - y_from) / 12.0
		if sink > best_sink:
			best_sink = sink
			best_at = nose
			best_speed = float(r["speed"])
	_say(kind, "best glide: %.2f m/s of sink at %.1f m/s, nose %.0f degrees -- a glide ratio of %.0f" % [-best_sink, best_speed,
		best_at, best_speed / maxf(-best_sink, 0.01)])
	var roll_rate: float = _full_roll()
	var r: Dictionary = _read()
	var t1: float = _t
	while _t - t1 < 6.0 and not r.is_empty():
		_fly(r, best_at, 0.0)
		_step(TICK * 4.0)
		r = _read()
	# A THERMALLING TURN: 30 degrees of bank at the best-glide attitude, the tightest circle it flies at that sink.
	var heading_was: float = float(r["heading"])
	var turned: float = 0.0
	var counted: float = 0.0
	var sp_sum: float = 0.0
	var y0: float = (r["at"] as Vector3).y
	t1 = _t
	while _t - t1 < 30.0 and not r.is_empty():
		_fly(r, best_at + 1.0, 30.0, true)
		_step(TICK * 4.0)
		r = _read()
		var hd: float = float(r["heading"])
		var d: float = rad_to_deg(angle_difference(deg_to_rad(heading_was), deg_to_rad(hd)))
		heading_was = hd
		if _t - t1 > 10.0:
			turned += absf(d)
			counted += TICK * 4.0
			sp_sum += float(r["speed"])
	var rate: float = turned / maxf(counted, 0.01)
	var radius: float = (sp_sum / maxf(counted / (TICK * 4.0), 1.0)) / maxf(deg_to_rad(rate), 0.0001)
	_input["rudder"] = 0.0
	var turn_sink: float = ((r["at"] as Vector3).y - y0) / 30.0
	_say(kind, "full-stick roll %.0f deg/s; 30-degree turn %.1f deg/s, circle %.0f m across, sinking %.2f m/s in it"
		% [roll_rate, rate, radius * 2.0, -turn_sink])
	var land: Dictionary = _land(best_speed / 1.3 * 0.9, hy)
	_say(kind, "landing: " + String(land["said"]))
	if not bool(land["ok"]):
		notes.append("landing: " + String(land["short"]))
	_end()
	_verdict(kind, "%s | sink %.2f m/s at %.0f m/s, L/D %.0f | roll %.0f deg/s | 30-deg circle %.0f m, %.2f m/s sink | landing %s"
		% ["FLIES" if notes.is_empty() else "FLIES, BUT: " + "; ".join(notes), -best_sink, best_speed,
			best_speed / maxf(-best_sink, 0.01), roll_rate, radius * 2.0, -turn_sink, String(land["short"])])


## ---- on rails ------------------------------------------------------------------------------------------------------

## A LOCOMOTIVE ON A STRAIGHT 60 KM TRACK, with a driver in the cab. `run_on_rails` reads the seated driver's own frame
## -- throttle and brake straight off `ControlInput`, not the lever -- so this seats a client exactly as the take-the-next
## -- craft button does (`seat_client`) and works that frame. Asked for by team-lead on 2026-09-17, when `lane/train` took
## the F7A from 84 to 112.2 t and reasoned, without driving it, that the top speed holds and acceleration and braking
## get about a third gentler.
func _train(kind: int) -> void:
	_end()
	_kind = kind
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	_h = _world.handling(kind)
	for i in range(301):
		_world.add_rail_point(0, Vector3(0.0, 0.0, -200.0 * float(i)), 0.0)
	# A RAILWAY IS A LOOP: `close_rail` joins the last point to the first and fixes the length, and until it is called the
	# track is 0 m long and `spawn_train` refuses it. Out and back along the same line, 120 km round; nothing here gets
	# near the far end.
	_world.close_rail(0)
	var made: Dictionary = _world.spawn_pilot(CLIENT, Sim.Kind.POD, Vector3(500.0, 50.0, 500.0), 0.0, Vector3.ZERO)
	_pilot = int(made.get("pilot", 0))
	_craft = int(_world.spawn_train(0, 100.0, 0.0))
	var seated: bool = _craft != 0 and bool(_world.seat_client(CLIENT, _craft, 0))
	_t = 0.0
	_input = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	var mass: float = float((_world.body_mass(_craft) as Dictionary).get("mass", 0.0)) if _craft != 0 else 0.0
	_say(kind, "mass %.1f t, drawbar pull %.0f kN, power %.0f kW, brake %.0f kN, rolling %.1f kN, track %.0f m, driver seated %s"
		% [mass / 1000.0, float(_h.get("thrust", 0.0)) / 1000.0, float(_h.get("rail_power", 0.0)) / 1000.0,
			float(_h.get("brake", 0.0)) / 1000.0, float(_h.get("rolling_resistance", 0.0)) / 1000.0,
			float(_world.rail_length(0)), seated])
	if not seated:
		# NOT a verdict: `_verdict` counts a measurement, and this is the absence of one, so the run fails.
		_say(kind, "NOT MEASURED -- no driver could be seated in the locomotive")
		_end()
		return
	# ---- full throttle from a stand ----
	var marks: Dictionary = {10.0: -1.0, 20.0: -1.0, 30.0: -1.0}
	var speed: float = 0.0
	var was: float = 0.0
	var gaining: float = INF
	var start_d: float = float(_world.rail_state(_craft).get("distance", 0.0))
	_input["throttle"] = 1.0
	while _t < 900.0:
		_step(1.0)
		speed = float(_world.rail_state(_craft).get("speed", 0.0))
		for mark in marks:
			if float(marks[mark]) < 0.0 and speed >= float(mark):
				marks[mark] = _t
		gaining = speed - was
		was = speed
		if _t > 60.0 and gaining < 0.005:
			break
	var run: float = float(_world.rail_state(_craft).get("distance", 0.0)) - start_d
	_say(kind, "full throttle from a stand: 10 m/s in %s, 20 in %s, 30 in %s; top %.1f m/s (%.0f km/h, %.0f mph) after %.0f s and %.1f km, gaining %.3f m/s each second at the end"
		% [_secs(marks[10.0]), _secs(marks[20.0]), _secs(marks[30.0]), speed, speed * 3.6, speed * 2.237, _t, run / 1000.0, gaining])
	var top: float = speed
	# ---- the emergency stop from the top ----
	var stop: Dictionary = _train_stop(1.0)
	_say(kind, "full brake from %.1f m/s: stopped in %.0f s and %.0f m" % [top, float(stop["seconds"]), float(stop["metres"])])
	# ---- a station stop from 20 m/s, full brake and half brake ----
	var station: Dictionary = _train_from(20.0, 1.0)
	var gentle: Dictionary = _train_from(20.0, 0.5)
	_say(kind, "from 20 m/s (72 km/h): full brake %.0f s and %.0f m; half brake %.0f s and %.0f m"
		% [float(station["seconds"]), float(station["metres"]), float(gentle["seconds"]), float(gentle["metres"])])
	# ---- coasting ----
	var coast: Dictionary = _train_from(top * 0.95, 0.0, 60.0)
	_say(kind, "coasting from %.1f m/s, no power and no brake: %.1f m/s after a minute" % [top * 0.95, float(coast["speed"])])
	var decel: float = 20.0 / maxf(float(station["seconds"]), 0.01)
	_end()
	var notes: PackedStringArray = []
	if float(stop["metres"]) > 1500.0:
		notes.append("needs %.1f km to stop from the top" % (float(stop["metres"]) / 1000.0))
	_verdict(kind, "%s | top %.0f m/s (%.0f km/h) | 0-20 %s | 0-30 %s | full brake from the top %.0f m in %.0f s | from 72 km/h %.0f m (%.2f m/s2)"
		% ["DRIVES" if notes.is_empty() else "DRIVES, BUT: " + "; ".join(notes), top, top * 3.6, _secs(marks[20.0]),
			_secs(marks[30.0]), float(stop["metres"]), float(stop["seconds"]), float(station["metres"]), decel])


func _secs(value: Variant) -> String:
	return "never" if float(value) < 0.0 else "%.0f s" % float(value)


## Brake at `brake` with the power off until the train stands. Seconds and metres.
func _train_stop(brake: float, most: float = 600.0) -> Dictionary:
	_input["throttle"] = 0.0
	_input["brake"] = brake
	var t0: float = _t
	var d0: float = float(_world.rail_state(_craft).get("distance", 0.0))
	var speed: float = float(_world.rail_state(_craft).get("speed", 0.0))
	while _t - t0 < most and (brake > 0.0 and speed > 0.05 or brake <= 0.0):
		_step(TICK * 12.0)
		speed = float(_world.rail_state(_craft).get("speed", 0.0))
	_input["brake"] = 0.0
	return {"seconds": _t - t0, "metres": float(_world.rail_state(_craft).get("distance", 0.0)) - d0, "speed": speed}


## Up to `speed` on the power, then brake at `brake` (or coast `most` seconds at 0). A fresh stretch of the same train.
func _train_from(speed: float, brake: float, most: float = 600.0) -> Dictionary:
	_input["brake"] = 0.0
	_input["throttle"] = 1.0
	var t0: float = _t
	while _t - t0 < 900.0 and float(_world.rail_state(_craft).get("speed", 0.0)) < speed:
		_step(TICK * 12.0)
	# Held there a moment at whatever throttle keeps it, so the stop starts from `speed`.
	return _train_stop(brake, most)
