extends "res://tests/handling.gd"
## Headless: DOES THE A-10C FLY LIKE AN A-10 -- off a runway, level flat out at its published speed, rolls at its rate,
## slows on its speed brake, and lands -- flown through a seated pilot's own control frame. Read RESULT=.
##
##   Godot --headless --fixed-fps 120 --path cockpit res://tests/warthog_flight.tscn
##
## THE ROBOT IS tests/handling.gd's, unchanged: this suite extends it and flies its legs on the A-10C alone, so a steady
## pilot's hands are the same hands every craft is measured with, and what differs is that here each number is HELD to the
## published figure (Wikipedia, the A-10C's specifications) instead of only printed:
## - THE WING'S STALL is 120 kt (62 m/s) in this model's sense, the book stall every floor and the autopilot read, to 2%;
## - PARKED, the model's drawn tyres on the ground the simulation stands it on, to 5 cm;
## - A TAKE-OFF: parked, full power, rotating at 1.2 of the book stall: off the ground inside `TAKE_OFF_RUN`;
## - FLAT OUT, level at 300 m for 60 s, gear up: the published 381 kt clean at sea level (196 m/s), to 3%;
## - A FULL-STICK ROLL near the A-10's ninety degrees a second, and not an F-16's;
## - THE SPEED BRAKE -- the decelerons split, the spoilers bit -- slows it at idle at least half as fast again as idle
##   alone, over the same five seconds from the same speed;
## - AND A LANDING: gear down, an approach at 1.3 of the stall, touching at under 2 m/s of sink, upright, stopped.
## The power-off stall a pilot meets (a coefficient of 0.30, well under the book stall, as on every jet here) is
## tests/handling.gd's to print, and it prints 35.9 m/s.

const PUBLISHED_STALL: float = 120.0 * 0.5144
const PUBLISHED_TOP: float = 381.0 * 0.5144
const TAKE_OFF_RUN: float = 1200.0
const ROLL_RATE: Vector2 = Vector2(80.0, 110.0)
const BRAKE_MARGIN: float = 1.5


func _warthog_check(label: String, ok: bool, detail: String) -> void:
	print("[warthog_flight] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	var kind: int = Sim.Kind.WARTHOG
	var hy: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	_begin(kind, Vector3(0.0, hy + 0.3, 0.0), 0.0, Vector3.ZERO, true)
	var stall_book: float = float(_h.get("stall_speed", 0.0))
	_warthog_check("the_wing_stalls_at_the_published_120_kt", absf(stall_book - PUBLISHED_STALL) <= PUBLISHED_STALL * 0.02,
		"book stall %.1f m/s (%.0f kt) against %.1f" % [stall_book, stall_book * 1.944, PUBLISHED_STALL])
	# ---- the take-off ----
	_input["brake"] = 1.0
	_step(2.0)
	var start: Dictionary = _read()
	var parked_y: float = (start["at"] as Vector3).y
	# THE DRAWN WHEELS ARE WHERE IT STANDS: parked on flat ground at y 0, the simulation rests the craft's origin at
	# `parked_y`; the model's tyres, dressed from the same geometry, have their lowest point at `point(0, ground(), 0)`
	# under that origin. Their bottom must be on the ground the physics stands it on.
	var frame := WarthogAirframe.new()
	add_child(frame)
	frame.dress()
	var tyres_at: float = parked_y + frame.point(0.0, WarthogAirframe.ground(), 0.0).y
	frame.queue_free()
	_warthog_check("parked_its_drawn_tyres_stand_on_the_ground", absf(tyres_at) <= 0.05 and float(start["up"]) > 0.999,
		"the origin rests %.3f m up, the drawn tyres' bottoms %.3f m off the ground, level %.4f" % [parked_y, tyres_at,
			float(start["up"])])
	var from: Vector3 = start["at"]
	_input["brake"] = 0.0
	_input["throttle"] = 1.0
	var rotate: float = stall_book * 1.2
	var lift_d: float = -1.0
	var lift_v: float = 0.0
	var t0: float = _t
	while _t - t0 < 90.0:
		var r: Dictionary = _read()
		var h: float = (r["at"] as Vector3).y - parked_y
		if lift_d < 0.0 and h > 2.0:
			lift_d = ((r["at"] as Vector3) - from).length()
			lift_v = float(r["speed"])
		if h > 30.0:
			_command(Sim.Channel.GEAR, 0)
			break
		_fly(r, 0.0 if float(r["speed"]) < rotate else 10.0, _bank_for_heading(r, 0.0, 10.0))
		_step(TICK * 4.0)
	_warthog_check("it_takes_off_from_a_runway", lift_d > 0.0 and lift_d <= TAKE_OFF_RUN and lift_v < stall_book * 1.5,
		"off the ground %s at %.1f m/s (%.0f kt), rotating at %.1f" % ["after %.0f m" % lift_d if lift_d > 0.0 else "NEVER",
			lift_v, lift_v * 1.944, rotate])
	# ---- flat out, clean ----
	# THIRTY SECONDS TO GET UP TO THE HEIGHT FIRST: the first run measured the sixty seconds from the lift-off, climbing,
	# and read 190.1 m/s still gaining 0.55 a second.
	_hold_level(LEVEL_AT, 1.0, 30.0, 0.0)
	var level: Dictionary = _hold_level(LEVEL_AT, 1.0, 60.0, 0.0)
	var top: float = float(level.get("speed", 0.0))
	var gear_up: bool = not bool((_world.craft_controls(_craft) as Dictionary).get("gear", true))
	_warthog_check("flat_out_it_is_the_published_381_kt", gear_up and absf(top - PUBLISHED_TOP) <= PUBLISHED_TOP * 0.03,
		"level at %.0f m, full power, gear %s, 60 s: %.1f m/s (%.0f kt) against %.1f; still gaining %.2f m/s a second"
			% [LEVEL_AT, "up" if gear_up else "DOWN", top, top * 1.944, PUBLISHED_TOP, float(level.get("still_gaining", 0.0))])
	# ---- the roll ----
	var roll: float = _full_roll()
	_warthog_check("a_full_stick_roll_is_an_a10s", roll >= ROLL_RATE.x and roll <= ROLL_RATE.y,
		"%.0f deg/s, wanted %.0f to %.0f" % [roll, ROLL_RATE.x, ROLL_RATE.y])
	# HOMEWARD FROM HERE ON: flat out northward the aeroplane is 25 km out, and 32 km is the wire's edge, where the
	# velocity across it is zeroed (`guard_the_wire_edge`). The first run's approach began 30 km out, lost its airspeed in
	# five seconds at 220 m and fell at 37 m/s: the edge, not the aeroplane.
	_hold_level(LEVEL_AT, 1.0, 40.0, _homeward())
	# ---- the speed brake ----
	var idle_only: float = _slowing(false)
	var braked: float = _slowing(true)
	_warthog_check("the_speed_brake_slows_it", braked >= idle_only * BRAKE_MARGIN and idle_only > 0.0,
		"five seconds at idle from level cruise: %.1f m/s lost clean, %.1f with the decelerons split (wanted %.1fx)"
			% [idle_only, braked, BRAKE_MARGIN])
	# ---- the landing ----
	# SLOWED FIRST, on the speed brake at idle, height held, to 1.4 of the stall, as a pilot joins the approach: the first
	# run began `_land` at cruise, 150 m/s, and its descent loop dived it into the ground at 42.8 m/s.
	_command(Sim.Channel.SPOILERS, 1)
	var slow_from: float = _t
	while float(_read()["speed"]) > stall_book * 1.4 and _t - slow_from < 60.0:
		_hold_level(LEVEL_AT, IDLE, 1.0, _homeward())
	_command(Sim.Channel.SPOILERS, 0)
	_hold_level(LEVEL_AT, 0.5, 2.0, _homeward())
	var landed: Dictionary = _land(stall_book, hy, kind)
	# AND COMBAT'S CRASH RULE READS IT AS A LANDING: the craft whole after it, not a wreck (lane/combat's `hull_state`).
	var hull: Dictionary = _world.hull_state(_craft) if _world.has_method("hull_state") else {}
	var rule: Dictionary = _world.crash_rule() if _world.has_method("crash_rule") else {}
	_warthog_check("it_lands_and_the_crash_rule_reads_a_landing", bool(landed.get("ok", false))
		and String(landed.get("said", "")).contains("upright") and not hull.is_empty() and not bool(hull.get("destroyed", true))
		and float(hull.get("left", 0.0)) > 0.99,
		"%s; the hull after it: %s left of %.0f points, destroyed %s (the crash rule's impact %.1f m/s)" % [
			String(landed.get("said", "")), hull.get("left", "-"), float(hull.get("whole", 0.0)), hull.get("destroyed", "-"),
			float(rule.get("impact", 0.0))])
	_end()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


## FIVE SECONDS AT IDLE FROM A SETTLED CRUISE, the height held on the stick, with the speed brake open or shut: the speed
## lost. The cruise is settled first at 60 per cent power for thirty seconds, so both runs start from the same speed.
func _slowing(brake: bool) -> float:
	_command(Sim.Channel.SPOILERS, 0)
	_hold_level(LEVEL_AT, 0.6, 30.0, _homeward())
	if brake:
		_command(Sim.Channel.SPOILERS, 1)
	var r: Dictionary = _read()
	var from: float = float(r["speed"])
	_hold_level(LEVEL_AT, IDLE, 5.0, _homeward())
	var lost: float = from - float(_read()["speed"])
	_command(Sim.Channel.SPOILERS, 0)
	_step(TICK * 4.0)
	return lost
