extends Node
## Headless: DOES THE CESSNA FLY ON ITS SURFACES THE WAY AN AEROPLANE DOES? (lane/flightmodel, step 1)
##
##   Godot --headless --path cockpit res://tests/surfaces.tscn
##
## `lifting_surfaces.hpp` gives an aeroplane a wing in two panels, a tailplane and a fin, each making its own lift from the
## air where it is, and lets the stick move the surfaces (`cockpit/research/flight_model_plan.md`). Nothing in it types a
## stability, a damping, an adverse yaw or a stall break: they are meant to come out. This suite flies the Cessna with
## `surfaces` switched on, through the pilot's own control frame (`set_pilot_input`, the frame a seated player's rig
## sends), and holds each of those to something the model was NOT given:
##
## - a figure from outside it: the drawn airframe's own planform (`SkyhawkAirframe`'s edge functions, integrated here),
##   and the published flaps-down stall ([W] "Cessna 172": 47 kn CAS power off at 1,111 kg);
## - a sign: the nose swings AWAY from a roll made without rudder; a pedal alone banks the aeroplane its own way; the
##   nose falls through at the stall; the tailplane rotates it on the take-off roll;
## - or a ratio of two flights: the trim speed falls as the elevator goes back; the roll rate grows with airspeed.
##
## AND EVERY CHECK HAS ITS MUTANT, which takes the physics it names away (`aero::Mutant` through `surface_mutant`, or the
## old rate-servo model with `surfaces` 0) and must turn it red. A mutant that stays green means the check was measuring
## something else, and the run fails.
##
## THE STALL IS NOT FULLY INDEPENDENT, and it says so: the Cessna's CLmax with flaps was CHOSEN from that same published
## stall. What the flown check proves is that the airframe reaches the CLmax it was given -- the tailplane can hold the
## nose there, the tail does not stall first, and nothing in the hand-off from the stick loses it -- not that the number
## is right.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 60
const KIND: int = Sim.Kind.CESSNA
## [W] "Cessna 172", specifications (172R): stall 47 kn CAS power off, flaps down, at the 1,111 kg gross weight. At the
## game's 1,000 kg a stall goes with the square root of the weight.
const PUBLISHED_STALL_FLAPS: float = 47.0 * 0.514444
const PUBLISHED_WEIGHT: float = 1111.0
## How close the drawn planform and the simulated one must be. The areas are integrated from the airframe's own edge
## functions, where C++ was typed from a hand reading of the same constants: two routes to one drawing.
const AREA_BAND: float = 0.10
const ARM_BAND: float = 0.30
## THE HAND. A proportional attitude hold on a stick that is a surface, with an integral that trims it out: full stick for
## twelve degrees of error, as `tests/handling.gd` flies a raw craft (`K_PITCH_SURFACE`, `K_TRIM`).
const K_PITCH: float = 0.08
const K_TRIM: float = 0.05
const K_BANK: float = 0.03
## The Cessna's rates at full stick through the law (`default_handling`: pitch_rate 1.2, roll_rate 2.0 rad/s).
const PITCH_RATE: float = 1.2
const ROLL_RATE: float = 2.0

var _world: RefCounted
var _craft: int = 0
var _pilot: int = 0
var _input: Dictionary = {}
var _seq: int = 0
var _trim: float = 0.0
## Whether the craft being flown has its stick through the control law (`augmentation` of a half or more).
var _rate_stick: bool = false
var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "no CockpitWorld")
		_finish()
		return
	_the_simulated_surfaces_are_the_drawn_ones()
	_it_is_not_too_stiff_to_simulate()
	_it_stalls_where_the_book_says_with_flaps_down()
	_the_trim_speed_follows_the_elevator()
	_the_roll_rate_grows_with_airspeed()
	_a_roll_without_rudder_swings_the_nose_away()
	_a_pedal_alone_banks_it()
	_the_stall_breaks_and_recovers()
	_it_rotates_on_the_take_off_roll()
	_the_control_law_never_beats_the_air()
	_finish()


# ---- the checks ------------------------------------------------------------------------------------------------------

func _the_simulated_surfaces_are_the_drawn_ones() -> void:
	var w: RefCounted = _new_world()
	w.set_handling(KIND, {"surfaces": 1.0})
	var sim: Dictionary = w.lifting_surfaces(KIND)
	w.teardown()
	var list: Array = sim.get("surfaces", [])
	if list.size() < 4:
		_check("the_simulated_surfaces_are_the_drawn_ones", false, "no surfaces: %s" % sim)
		return
	# THE DRAWING'S OWN PLANFORM, integrated from its edge functions in steps of a centimetre.
	var wing_area := 0.0
	var x := 0.0
	while x < SkyhawkAirframe.WING_FAIRING_X:
		wing_area += 2.0 * 0.01 * (SkyhawkAirframe.wing_trailing_edge(x + 0.005) - SkyhawkAirframe.wing_leading_edge(x + 0.005))
		x += 0.01
	var tail_area := 0.0
	var tail_moment := 0.0
	x = 0.0
	while x < SkyhawkAirframe.STAB_TIP_X:
		var le: float = SkyhawkAirframe.stab_leading_edge(x + 0.005)
		var chord: float = SkyhawkAirframe.elevator_trailing_edge(x + 0.005) - le
		tail_area += 2.0 * 0.01 * chord
		tail_moment += 2.0 * 0.01 * chord * (le + 0.25 * chord)
		x += 0.01
	var tail_station: float = tail_moment / maxf(tail_area, 0.01)
	var fin_area := 0.0
	var h: float = SkyhawkAirframe.FIN_ROOT_H
	while h < SkyhawkAirframe.FIN_CAP_H.x:
		fin_area += 0.01 * (SkyhawkAirframe._along(SkyhawkAirframe.RUDDER_TE, h + 0.005)
			- SkyhawkAirframe._along(SkyhawkAirframe.FIN_LE, h + 0.005))
		h += 0.01
	var sim_wing: float = float(list[0]["area"]) + float(list[1]["area"])
	var sim_tail: float = float(list[2]["area"])
	var sim_fin: float = float(list[3]["area"])
	# The simulation's places are body axes from the hull's middle; the drawing's stations are from the spinner.
	var sim_tail_station: float = (list[2]["at"] as Vector3).z + SkyhawkAirframe.LENGTH * 0.5
	var ok: bool = absf(sim_wing / wing_area - 1.0) < AREA_BAND and absf(sim_tail / tail_area - 1.0) < AREA_BAND \
		and absf(sim_fin / fin_area - 1.0) < AREA_BAND * 1.5 and absf(sim_tail_station - tail_station) < ARM_BAND
	_check("the_simulated_surfaces_are_the_drawn_ones", ok,
		("wing %.2f m2 simulated against %.2f drawn; tailplane %.2f against %.2f, its quarter chord %.2f m aft against %.2f; "
		+ "fin %.2f against %.2f") % [sim_wing, wing_area, sim_tail, tail_area, sim_tail_station, tail_station, sim_fin, fin_area])
	# And what was derived, for the record.
	var centre: Vector3 = sim.get("centre", Vector3.ZERO)
	print("[surfaces] derived: centre of gravity %.2f m aft of the spinner, tailplane incidence %.2f deg, stall %.1f m/s clean and %.1f with flaps, trimmed at %.1f m/s, inertia %s"
		% [centre.z + SkyhawkAirframe.LENGTH * 0.5, rad_to_deg(float(sim.get("tail_incidence", 0.0))),
			float(sim.get("stall", 0.0)), float(sim.get("stall_flaps", 0.0)), float(sim.get("cruise", 0.0)), sim.get("inertia")])


func _it_is_not_too_stiff_to_simulate() -> void:
	# THE STIFFNESS GUARD (the plan's section 2): roll damping from the air, applied once a tick, on a roll inertia small
	# enough that it closes inside a couple of ticks is the edge of stability. Three ticks at 120 Hz is the floor.
	var w: RefCounted = _new_world()
	w.set_handling(KIND, {"surfaces": 1.0})
	var tau: float = float(w.lifting_surfaces(KIND).get("roll_time_constant", 0.0))
	w.teardown()
	_check("its_roll_is_not_too_stiff_to_simulate", tau >= 3.0 * TICK,
		"roll time constant %.3f s at its cruise, floor %.3f (three ticks)" % [tau, 3.0 * TICK])


## FLOWN THROUGH THE CONTROL LAW, and only counted at the wing's own stall. The first cut flew it raw with the suite's
## hand and took the first 2 m/s of sink, and a trace showed neither run stalled: the hand let the nose lag, and it was
## sinking at alpha 10.9 degrees with flaps and 12.8 clean, where the wing stalls at 15.8. The law holds the attitude the
## height asks for, and can never ask the air for more than full elevator gets (`the_control_law_never_beats_the_air`), so
## the speed where it can no longer hold the height, with alpha at the stall, is the wing's.
func _it_stalls_where_the_book_says_with_flaps_down() -> void:
	var book: float = PUBLISHED_STALL_FLAPS * sqrt(1000.0 / PUBLISHED_WEIGHT)
	var flaps: float = _stall_flown({"surfaces": 1.0, "augmentation": 1.0}, 1.0)
	var clean: float = _stall_flown({"surfaces": 1.0, "augmentation": 1.0}, 0.0)
	_check("it_stalls_where_the_book_says_with_flaps_down", absf(flaps / book - 1.0) < 0.10,
		"flown %.1f m/s with full flap against the published %.1f at 1,000 kg (47 kn at 1,111 kg), within 10%%" % [flaps, book])
	_check("the_flaps_lower_the_stall", flaps < clean - 1.5, "flown %.1f m/s with flaps, %.1f clean" % [flaps, clean])
	var mutant: float = _stall_flown({"surfaces": 1.0, "augmentation": 1.0, "flap_clmax": 0.0}, 1.0)
	_mutant("the_flaps_lower_the_stall", "flap_clmax 0", mutant < clean - 1.5, "flown %.1f with dead flaps, %.1f clean" % [mutant, clean])


func _the_trim_speed_follows_the_elevator() -> void:
	var speeds: Array = []
	var dead: Array = []
	for back in [0.0, 0.15, 0.30]:
		speeds.append(_trimmed_speed({"surfaces": 1.0}, back))
		dead.append(_trimmed_speed({"surfaces": 1.0, "surface_mutant": 4.0}, back))
	var ok: bool = float(speeds[0]) > float(speeds[1]) + 2.0 and float(speeds[1]) > float(speeds[2]) + 2.0
	_check("the_trim_speed_follows_the_elevator", ok,
		"hands off at 0.4 throttle: %.1f, %.1f and %.1f m/s with 0, 0.15 and 0.30 of back stick" % speeds)
	var still: bool = float(dead[0]) > float(dead[1]) + 2.0 and float(dead[1]) > float(dead[2]) + 2.0
	_mutant("the_trim_speed_follows_the_elevator", "no elevator", still, "%.1f, %.1f and %.1f m/s" % dead)


func _the_roll_rate_grows_with_airspeed() -> void:
	var slow: float = _full_roll({"surfaces": 1.0}, 30.0)
	var fast: float = _full_roll({"surfaces": 1.0}, 60.0)
	var ratio: float = fast / maxf(slow, 0.1)
	_check("the_roll_rate_grows_with_airspeed", ratio > 1.3 and ratio < 2.2,
		"full stick, raw: %.0f deg/s at 30 m/s and %.0f at 60, a ratio of %.2f (1.3 to 2.2; a real aileron's rate goes with the speed)"
		% [slow, fast, ratio])
	var old_slow: float = _full_roll({"surfaces": 0.0}, 30.0)
	var old_fast: float = _full_roll({"surfaces": 0.0}, 60.0)
	var old_ratio: float = old_fast / maxf(old_slow, 0.1)
	_mutant("the_roll_rate_grows_with_airspeed", "the old rate servo", old_ratio > 1.3 and old_ratio < 2.2,
		"%.0f and %.0f deg/s, a ratio of %.2f" % [old_slow, old_fast, old_ratio])


## ADVERSE YAW IS THE NOSE FALLING BEHIND THE FLIGHT PATH as a roll starts: the aileron that goes down drags its wing
## back, and the aeroplane slips toward the rising wing's side -- rolling right, the air comes from the right of the nose.
## So it is measured as SIDESLIP over the first 0.4 s, while the bank is under twenty degrees.
##
## TWO MEASURES WERE WRONG FIRST, and both are worth knowing. A heading over half a second saw the turn the bank starts,
## which swamps it (+0.59 degrees toward the roll). And the body's own yaw rate goes TOWARD the roll at first, correctly:
## an aeroplane rolls about its flight path, which is alpha below its nose, so a roll right has a body yaw of p tan(alpha)
## to the right with no yaw about the flight path at all. Adverse yaw is defined against the flight path, and sideslip is
## that.
func _a_roll_without_rudder_swings_the_nose_away() -> void:
	var slip: float = _slip_as_a_roll_starts({"surfaces": 1.0})
	_check("a_roll_without_rudder_swings_the_nose_away", slip > 0.3,
		"full right stick, feet still, 40 m/s: %.2f deg of sideslip from the right in the first 0.4 s (the nose behind the flight path)" % slip)
	var mutant: float = _slip_as_a_roll_starts({"surfaces": 0.0})
	_mutant("a_roll_without_rudder_swings_the_nose_away", "the old rate servo", mutant > 0.3, "%.2f deg" % mutant)


func _a_pedal_alone_banks_it() -> void:
	var bank: float = _bank_from_pedal({"surfaces": 1.0})
	_check("a_pedal_alone_banks_it", bank > 5.0,
		"full right pedal, stick centred, 45 m/s: %+.1f deg of bank after 3 s (the dihedral and the high wing)" % bank)
	var mutant: float = _bank_from_pedal({"surfaces": 1.0, "surface_mutant": 2.0})
	_mutant("a_pedal_alone_banks_it", "no dihedral, wing at the centre of gravity", mutant > 5.0, "%+.1f deg" % mutant)


## THE BREAK IS THE LIFT FALLING WHILE THE ANGLE STILL RISES, measured directly: the lift coefficient from the body's own
## acceleration along its up, m (a + g) . up / (q S). The first cut asked only that the nose fall with the stick held
## back, and it falls with no break at all, as the speed decays and the flight path curves down (the mutant that holds
## CLmax past the stall fell at 11.7 deg/s).
func _the_stall_breaks_and_recovers() -> void:
	var r: Dictionary = _stall_break({"surfaces": 1.0})
	var ok: bool = bool(r["broke"]) and bool(r["recovered"])
	_check("the_stall_breaks_and_recovers", ok,
		"stick held back power off: CL peaked at %.2f, then fell to %.2f with alpha up to %.1f deg; released, flying again in %.1f s, %.0f m lower"
		% [r["cl_peak"], r["cl_after"], r["alpha"], r["recover_s"], r["lost"]])
	var m: Dictionary = _stall_break({"surfaces": 1.0, "surface_mutant": 16.0})
	_mutant("the_stall_breaks_and_recovers", "no lift lost past the stall", bool(m["broke"]) and bool(m["recovered"]),
		"CL peaked at %.2f, then %.2f, alpha %.1f" % [m["cl_peak"], m["cl_after"], m["alpha"]])


## THE ELEVATOR ROTATES IT: full back stick against a centred one over the same first second and a half of a take-off
## roll from 1.1 x the stall. The first cut held the back-stick run alone to five degrees, and the wing lifting the nose
## as the speed built did that by itself -- 9.7 degrees with no elevator at all.
func _it_rotates_on_the_take_off_roll() -> void:
	var back: Dictionary = _rotation({"surfaces": 1.0}, 1.0)
	var centred: Dictionary = _rotation({"surfaces": 1.0}, 0.0)
	var gained: float = float(back["pitch"]) - float(centred["pitch"])
	_check("it_rotates_on_the_take_off_roll", gained > 5.0,
		"from %.0f m/s on the runway, 1.5 s: %.1f deg nose up with full back stick and %.1f centred"
		% [back["from"], back["pitch"], centred["pitch"]])
	var m_back: Dictionary = _rotation({"surfaces": 1.0, "surface_mutant": 4.0}, 1.0)
	var m_centred: Dictionary = _rotation({"surfaces": 1.0, "surface_mutant": 4.0}, 0.0)
	var m_gained: float = float(m_back["pitch"]) - float(m_centred["pitch"])
	_mutant("it_rotates_on_the_take_off_roll", "no elevator", m_gained > 5.0,
		"%.1f back, %.1f centred" % [m_back["pitch"], m_centred["pitch"]])


func _the_control_law_never_beats_the_air() -> void:
	# THROUGH THE LAW (fly-by-wire) THE STICK ASKS FOR THE KIND'S roll_rate; slow, the ailerons cannot give it, and the law
	# must get no more than full aileron gets.
	var raw: float = _full_roll({"surfaces": 1.0}, 30.0)
	var law: float = _full_roll({"surfaces": 1.0, "augmentation": 1.0}, 30.0)
	_check("the_control_law_never_beats_the_air", law <= raw * 1.05 + 1.0,
		"full stick at 30 m/s: %.0f deg/s through the law against %.0f with full aileron" % [law, raw])
	var m: float = _full_roll({"surfaces": 1.0, "augmentation": 1.0, "surface_mutant": 8.0}, 30.0)
	_mutant("the_control_law_never_beats_the_air", "the law unclamped", m <= raw * 1.05 + 1.0, "%.0f deg/s" % m)


# ---- the flights -----------------------------------------------------------------------------------------------------

## THE STALL AS IT IS FLOWN FOR A CERTIFICATE: from level at 1.4 x the book stall, power managed to lose a metre a second
## each second, height held by the hand; the stall is the speed at which it first sinks at 2 m/s.
func _stall_flown(sets: Dictionary, flaps: float) -> float:
	var stall: float = _book_stall(sets, flaps)
	if not _spawn(sets, Vector3(0.0, 1000.0, 0.0), Vector3(0.0, 0.0, -stall * 1.4)):
		return 0.0
	_command(Sim.Channel.FLAPS, int(round(flaps * 255.0)))
	_hold(1000.0, 0.0, stall * 1.4, 4.0)
	var stall_alpha: float = _stall_alpha()
	var r: Dictionary = _read()
	var target: float = float(r["speed"])
	var t := 0.0
	while t < 60.0:
		target -= TICK * 4.0
		r = _read()
		_input["throttle"] = clampf(0.25 + 0.15 * (target - float(r["speed"])), 0.002, 1.0)
		_fly(r, _pitch_for_height(r, 1000.0), 0.0)
		_step(4)
		t += TICK * 4.0
		r = _read()
		if OS.get_cmdline_user_args().has("--trace") and fmod(t, 1.0) < TICK * 4.0:
			print("[surfaces]   stall, flaps %.0f: t %.0f v %.1f vy %+.2f pitch %.1f alpha %.1f stick %+.2f throttle %.2f"
				% [flaps, t, r["speed"], r["vy"], r["pitch"], r["alpha"], _input["pitch"], _input["throttle"]])
		if float(r["vy"]) < -2.0 and float(r["alpha"]) > stall_alpha - 2.0:
			_end()
			return float(r["speed"])
	_end()
	return 0.0


## Hands off at a fixed throttle and a fixed stick, wings held level: the speed it settles at over the last 30 of 90 s.
func _trimmed_speed(sets: Dictionary, back: float) -> float:
	if not _spawn(sets, Vector3(0.0, 1500.0, 0.0), Vector3(0.0, 0.0, -45.0)):
		return 0.0
	var sum := 0.0
	var n := 0
	var t := 0.0
	while t < 90.0:
		var r: Dictionary = _read()
		_input["throttle"] = 0.4
		_input["pitch"] = back
		_input["roll"] = clampf(K_BANK * (0.0 - float(r["bank"])), -1.0, 1.0)
		_step(4)
		t += TICK * 4.0
		if t > 60.0:
			sum += float(_read()["speed"])
			n += 1
	_end()
	return sum / maxf(n, 1)


## Full right stick from level at a speed, feet still: the fastest roll rate in the first 1.5 s, deg/s.
func _full_roll(sets: Dictionary, speed: float) -> float:
	if not _spawn(sets, Vector3(0.0, 1500.0, 0.0), Vector3(0.0, 0.0, -speed)):
		return 0.0
	_hold(1500.0, 0.0, speed, 3.0)
	var fastest := 0.0
	var last: float = float(_read()["bank"])
	var t := 0.0
	while t < 1.5:
		_input["roll"] = 1.0
		_input["rudder"] = 0.0
		_step(1)
		t += TICK
		var bank: float = float(_read()["bank"])
		fastest = maxf(fastest, (bank - last) / TICK)
		last = bank
		if bank > 80.0:
			break
	_end()
	return fastest


## Full right stick, feet still, from level at 40 m/s: the most sideslip from the right in the first 0.4 s while the
## bank is under twenty degrees, degrees.
func _slip_as_a_roll_starts(sets: Dictionary) -> float:
	if not _spawn(sets, Vector3(0.0, 1500.0, 0.0), Vector3(0.0, 0.0, -40.0)):
		return 0.0
	_hold(1500.0, 0.0, 40.0, 3.0)
	var most := -90.0
	var t := 0.0
	while t < 0.4:
		_input["roll"] = 1.0
		_input["rudder"] = 0.0
		_step(1)
		t += TICK
		var r: Dictionary = _read()
		if absf(float(r["bank"])) < 20.0:
			most = maxf(most, float(r["slip"]))
	_end()
	return most


## Full right pedal, stick centred, from level at 45 m/s: the bank after three seconds.
func _bank_from_pedal(sets: Dictionary) -> float:
	if not _spawn(sets, Vector3(0.0, 1500.0, 0.0), Vector3(0.0, 0.0, -45.0)):
		return 0.0
	_hold(1500.0, 0.0, 45.0, 3.0)
	var t := 0.0
	while t < 3.0:
		_input["rudder"] = 1.0
		_input["roll"] = 0.0
		_input["pitch"] = _trim
		_step(1)
		t += TICK
	var bank: float = float(_read()["bank"])
	_end()
	return bank


## Stick held fully back with the power off for 8 s from 35 m/s, then let go for 12.
func _stall_break(sets: Dictionary) -> Dictionary:
	var out := {"broke": false, "recovered": false, "alpha": 0.0, "cl_peak": 0.0, "cl_after": 0.0, "recover_s": -1.0,
		"lost": 0.0}
	if not _spawn(sets, Vector3(0.0, 1500.0, 0.0), Vector3(0.0, 0.0, -35.0)):
		return out
	_hold(1500.0, 0.0, 35.0, 2.0)
	var stall_alpha: float = _stall_alpha()
	var sim: Dictionary = _world.lifting_surfaces(KIND)
	var area := 0.0
	for surface in sim.get("surfaces", []):
		if (surface["normal"] as Vector3).y > 0.5 and absf((surface["at"] as Vector3).x) > 0.5:
			area += float(surface["area"])
	var y0: float = (_read()["at"] as Vector3).y
	var most_alpha := -90.0
	var cl_peak := 0.0
	var cl_after := 99.0
	var v_was: Vector3 = _read()["v"]
	var t := 0.0
	while t < 8.0:
		_input["throttle"] = 0.002
		_input["pitch"] = 1.0
		_input["roll"] = clampf(K_BANK * (0.0 - float(_read()["bank"])), -1.0, 1.0)
		_step(1)
		t += TICK
		var r: Dictionary = _read()
		var v: Vector3 = r["v"]
		var lift: float = 1000.0 * ((v - v_was) / TICK + Vector3(0.0, 9.81, 0.0)).dot(r["up"] as Vector3)
		v_was = v
		var cl: float = lift / maxf(0.5 * 1.225 * v.length_squared() * area, 1.0)
		most_alpha = maxf(most_alpha, float(r["alpha"]))
		if float(r["alpha"]) < stall_alpha:
			cl_peak = maxf(cl_peak, cl)
		elif float(r["alpha"]) > stall_alpha + 4.0:
			cl_after = minf(cl_after, cl)
	var low: float = y0
	t = 0.0
	while t < 12.0:
		_input["pitch"] = 0.0
		_input["throttle"] = 0.002
		_input["roll"] = clampf(K_BANK * (0.0 - float(_read()["bank"])), -1.0, 1.0)
		_step(1)
		t += TICK
		var r: Dictionary = _read()
		low = minf(low, (r["at"] as Vector3).y)
		if out["recover_s"] < 0.0 and float(r["alpha"]) < stall_alpha * 0.7 and float(r["speed"]) > _book_stall({"surfaces": 1.0}, 0.0) * 1.1:
			out["recover_s"] = t
	out["alpha"] = most_alpha
	out["cl_peak"] = cl_peak
	out["cl_after"] = cl_after if cl_after < 99.0 else cl_peak
	out["broke"] = most_alpha > stall_alpha + 4.0 and float(out["cl_after"]) < 0.8 * cl_peak
	out["recovered"] = float(out["recover_s"]) >= 0.0
	out["lost"] = y0 - low
	_end()
	return out


## On a runway at 1.1 x the book stall with full power and the stick where it is put: the most nose-up in 1.5 s.
func _rotation(sets: Dictionary, stick: float) -> Dictionary:
	var out := {"pitch": 0.0, "from": 0.0}
	var from: float = _book_stall(sets, 0.0) * 1.1
	out["from"] = from
	# THE GROUND: a slab, as every suite that parks an aeroplane uses, and the craft standing on it at the speed.
	if not _spawn(sets, Vector3(0.0, 0.8499, 0.0), Vector3(0.0, 0.0, -from), true):
		return out
	var most := 0.0
	var t := 0.0
	while t < 1.5:
		_input["throttle"] = 1.0
		_input["pitch"] = stick
		_step(1)
		t += TICK
		most = maxf(most, float(_read()["pitch"]))
	out["pitch"] = most
	_end()
	return out


# ---- the hand and the world ------------------------------------------------------------------------------------------

## Level for `seconds` at a height and a speed, the hand holding the pitch and trimming, the throttle holding the speed.
func _hold(height: float, bank_to: float, speed: float, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		var r: Dictionary = _read()
		_input["throttle"] = clampf(0.4 + 0.1 * (speed - float(r["speed"])), 0.002, 1.0)
		_fly(r, _pitch_for_height(r, height), bank_to)
		_step(4)
		t += TICK * 4.0


func _fly(r: Dictionary, pitch_to: float, bank_to: float) -> void:
	var error: float = pitch_to - float(r["pitch"])
	if _rate_stick:
		# The stick asks the law for a pitch rate: two and a half times the error a second, as `tests/handling.gd` flies
		# every rate stick, and nothing to trim.
		_input["pitch"] = clampf(2.5 * error / rad_to_deg(PITCH_RATE), -1.0, 1.0)
		_input["roll"] = clampf(2.5 * (bank_to - float(r["bank"])) / rad_to_deg(ROLL_RATE), -1.0, 1.0)
		_input["rudder"] = 0.0
		return
	_trim = clampf(_trim + K_TRIM * error * TICK * 4.0, -1.0, 1.0)
	_input["pitch"] = clampf(K_PITCH * error + _trim, -1.0, 1.0)
	_input["roll"] = clampf(K_BANK * (bank_to - float(r["bank"])), -1.0, 1.0)
	_input["rudder"] = 0.0


func _pitch_for_height(r: Dictionary, height: float) -> float:
	return clampf(4.0 + 0.25 * (height - (r["at"] as Vector3).y) - 1.2 * float(r["vy"]), -10.0, 25.0)


func _book_stall(sets: Dictionary, flaps: float) -> float:
	var w: RefCounted = _new_world()
	w.set_handling(KIND, sets)
	var s: Dictionary = w.lifting_surfaces(KIND)
	w.teardown()
	return float(s.get("stall_flaps" if flaps > 0.5 else "stall", 30.0))


## The wing's stall as a body angle of attack, degrees: its stall angle less its own zero-lift angle.
func _stall_alpha() -> float:
	var list: Array = _world.lifting_surfaces(KIND).get("surfaces", [])
	if list.is_empty():
		return 15.0
	return rad_to_deg(float(list[0]["stall"]) - float(list[0]["alpha0"]))


func _new_world() -> RefCounted:
	var w: RefCounted = ClassDB.instantiate("CockpitWorld")
	w.set_tick_rate(120.0)
	w.start(0)
	return w


func _spawn(sets: Dictionary, at: Vector3, velocity: Vector3, ground: bool = false) -> bool:
	_world = _new_world()
	if ground:
		_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(40000.0, 400.0, 40000.0))
	_world.set_handling(KIND, sets)
	var made: Dictionary = _world.spawn_pilot(CLIENT, KIND, at, 0.0, velocity)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_seq = 0
	_trim = 0.0
	_rate_stick = float(sets.get("augmentation", 0.0)) >= 0.5
	_input = {"throttle": 0.4, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	return _craft != 0 and _pilot != 0


func _end() -> void:
	if _world != null:
		_world.teardown()
	_world = null


func _command(channel: int, value: int) -> void:
	_seq = _seq % 3 + 1
	_input["command_channel"] = channel
	_input["command_value"] = value
	_input["command_seq"] = _seq


func _step(ticks: int) -> void:
	for i in range(ticks):
		_world.set_pilot_input(_pilot, _input)
		_world.tick(TICK)


func _read() -> Dictionary:
	var s: Dictionary = _world.vehicle_state(_craft)
	var b := Basis(s.get("basis", Quaternion()) as Quaternion)
	var nose: Vector3 = b * Vector3.FORWARD
	var right: Vector3 = b * Vector3.RIGHT
	var up: Vector3 = b * Vector3.UP
	var v: Vector3 = s.get("velocity", Vector3.ZERO)
	var speed: float = v.length()
	var spin: Vector3 = s.get("spin", Vector3.ZERO)
	return {
		"at": s.get("position", Vector3.ZERO) as Vector3,
		"v": v,
		"up": up,
		# Yaw about the body's up, positive to the RIGHT (the axis's own sign is nose left).
		"yaw_rate": rad_to_deg(-spin.dot(up)),
		# Sideslip, positive when the air comes from the right of the nose (the craft moving to its right).
		"slip": rad_to_deg(asin(clampf(v.dot(right) / speed, -1.0, 1.0))) if speed > 1.0 else 0.0,
		"speed": speed,
		"vy": v.y,
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"bank": rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))),
		# HEADINGS GROW TO THE RIGHT here, so a turn to the right is a positive change.
		"heading": rad_to_deg(atan2(nose.x, -nose.z)),
		# The wing's angle of attack: how far the airflow is below the nose, in the body's plane of symmetry.
		"alpha": rad_to_deg(atan2(-v.dot(up), maxf(v.dot(nose), 0.1))) if speed > 1.0 else 0.0,
	}


# ---- the verdict -----------------------------------------------------------------------------------------------------

func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[surfaces] %s %s (%s)" % ["PASS" if ok else "FAIL", name, detail])


## A MUTANT that still passes the check it was made for is a check measuring something else: that is a failure.
func _mutant(name: String, what: String, still_passes: bool, detail: String) -> void:
	_check("%s_fails_with_%s" % [name, what.replace(" ", "_")], not still_passes, "mutant: %s" % detail)


func _finish() -> void:
	print("[surfaces] %d passed, %d failed" % [_passed, _failed])
	print("RESULT=%s" % ("PASS" if _failed == 0 else "FAIL"))
	get_tree().quit(0 if _failed == 0 else 1)
