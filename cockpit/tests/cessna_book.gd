extends Node
## Headless: THE CESSNA AGAINST ITS BOOK, on its lifting surfaces (lane/cessnafm).
##
##   Godot --headless --path cockpit res://tests/cessna_book.tscn [-- --set=key=value,... --probe]
##
## `tests/surfaces.gd` proves the surfaces behave like an aeroplane's (a stall that breaks, adverse yaw, a pedal that
## banks it). This holds the Cessna on them to the numbers a 172S pilot would check it against, each flown through the
## pilot's control frame or its own autopilot, and each against a PUBLISHED figure, never against the model's formula:
##
## - the turn a bank buys, flown by the autopilot: rate over g tan(bank) / v. A real aeroplane in a steady, level,
##   coordinated turn is at 1 by definition. The lumped wing's autopilot measured 0.53 (lane/pattern), and every circuit
##   in the game was sized on that shortfall;
## - top speed, climb at Vy, the glide, the take-off roll and the roll rate, from the 172S POH and the handling-qualities
##   books, scaled from the POH's 2,550 lb to the game's 1,000 kg where the weight matters.
##
## THE BOOK IS AT 1,157 KG AND THE GAME'S CESSNA IS 1,000, so each target says how it was scaled, and the bands are wide
## enough for that and for "exact specs matter less" (the user). The table at the end prints target and flown side by
## side. `--probe` prints the table and passes whatever it says.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 60
const KIND: int = Sim.Kind.CESSNA
const KNOT: float = 0.514444
## [POH] Cessna 172S Pilot's Operating Handbook, section 5, at 2,550 lb (1,157 kg), sea level, standard day.
const POH_MASS: float = 1157.0
const GAME_MASS: float = 1000.0
## Maximum speed at sea level, full throttle: 126 KTAS (section 1). Weight barely moves it.
const TOP_SPEED: float = 126.0 * KNOT
## Vy, the best rate of climb, 74 KIAS; the rate there, 730 ft/min at 2,550 lb. Excess power over weight: at 1,000 kg the
## same excess power is 16 per cent more climb, and a lighter wing's induced drag is less, so about 4.5 m/s.
const VY: float = 74.0 * KNOT
const CLIMB_AT_VY: float = 730.0 * 0.3048 / 60.0 * POH_MASS / GAME_MASS
## Best glide, 68 KIAS, and about 9 to 1 with the propeller windmilling (section 3, "maximum glide": 1.5 NM a 1,000 ft).
const BEST_GLIDE: float = 68.0 * KNOT
const GLIDE_RATIO: float = 1.5 * 1852.0 / 304.8
## Take-off ground roll, 960 ft at 2,550 lb with ten degrees of flap (the chart's configuration, lifting off at 51 KIAS).
## A roll goes with the square of the weight.
const GROUND_ROLL: float = 960.0 * 0.3048 * pow(GAME_MASS / POH_MASS, 2.0)
## The roll-performance parameter pb/2V at full aileron. 0.07 to 0.09 is the classic figure for a light aeroplane
## (Perkins and Hage; Roskam, Airplane Flight Dynamics I); the Cessna is at the gentle end of it.
const PB2V_LOW: float = 0.05
const PB2V_HIGH: float = 0.10
const SPAN: float = 11.0

var _world: RefCounted
var _craft: int = 0
var _pilot: int = 0
var _input: Dictionary = {}
var _seq: int = 0
var _card: TuningCard = TuningCard.from_command_line()
var _probe: bool = OS.get_cmdline_user_args().has("--probe")
var _passed: int = 0
var _failed: int = 0
var _table: Array[String] = []
## False only while the turn's mutant flies: the Cessna on its lumped wing.
var _mutant_surfaces: bool = true


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "no CockpitWorld")
		_finish()
		return
	print("[cessna_book] card %s" % str(_card.retune))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--circles="):
			_circles(argument.trim_prefix("--circles="))
			_finish()
			return
	if OS.get_cmdline_user_args().has("--descent"):
		_autopilot_descent(36.5)
		_finish()
		return
	_the_turn_a_bank_buys()
	_top_speed()
	_climb_at_vy()
	_the_glide()
	_the_take_off_roll()
	_the_roll_rate()
	_stalls()
	print("[cessna_book] ---- the book against the flown ----")
	for line in _table:
		print("[cessna_book]   %s" % line)
	_finish()


# ---- the checks ------------------------------------------------------------------------------------------------------

## THE AUTOPILOT'S OWN TURN, level, at 20, 30 and 45 degrees of bank: the heading's rate over g tan(bank) / v, with the
## bank and speed it actually flew.
func _the_turn_a_bank_buys() -> void:
	for degrees in [20.0, 30.0, 45.0]:
		var r: Dictionary = _autopilot_turn(deg_to_rad(degrees))
		_table.append("turn at %.0f deg (AI): %.2f of g tan(bank)/v, bank flown %.1f, %.1f m/s, %.2f deg/s, height %+.1f m"
			% [degrees, r["ratio"], r["bank"], r["speed"], r["rate"], r["height"]])
		_check("the_autopilot_turns_at_the_rate_its_bank_buys_at_%d_deg" % int(degrees),
			float(r["ratio"]) > 0.9 and float(r["ratio"]) < 1.1 and absf(float(r["height"])) < 15.0,
			"%.2f of g tan(bank)/v at %.1f deg flown, height %+.1f m over the measured 15 s (a real one is at 1)"
			% [r["ratio"], r["bank"], r["height"]])
	# THE MUTANT: the lumped wing and its rate servo, which lane/pattern measured at 0.53. A check it passes is measuring
	# something else.
	_mutant_surfaces = false
	var old: Dictionary = _autopilot_turn(deg_to_rad(30.0))
	_mutant_surfaces = true
	_table.append("turn at 30 deg (AI) on the LUMPED wing: %.2f of g tan(bank)/v" % old["ratio"])
	_check("the_turn_check_fails_on_the_lumped_wing", float(old["ratio"]) < 0.9,
		"mutant: %.2f of g tan(bank)/v at %.1f deg with surfaces off" % [old["ratio"], old["bank"]])


func _top_speed() -> void:
	var top: float = _level_full_power()
	_table.append("top speed: %.1f m/s (%.0f kn) against the POH's %.0f kn" % [top, top / KNOT, TOP_SPEED / KNOT])
	_check("its_top_speed_is_the_books", absf(top / TOP_SPEED - 1.0) < 0.06,
		"%.1f m/s level at full throttle against %.1f (126 KTAS), within 6%%" % [top, TOP_SPEED])


func _climb_at_vy() -> void:
	var climb: float = _held_speed(VY, 1.0, 40.0)
	_table.append("climb at Vy 74 KIAS, full throttle: %.2f m/s against %.1f (730 ft/min at 2,550 lb, scaled)" % [climb, CLIMB_AT_VY])
	_check("it_climbs_at_vy_as_the_book_says", climb > CLIMB_AT_VY * 0.75 and climb < CLIMB_AT_VY * 1.35,
		"%.2f m/s at %.1f m/s against %.2f, 0.75 to 1.35 of it" % [climb, VY, CLIMB_AT_VY])


## BY ENERGY, never by height alone: a hold that is still slowing down reads as a flatter glide than it is, and a model
## that makes energy from nothing reads as the best glider in the world (lane/sailplane's finding on the lumped wing).
func _the_glide() -> void:
	var r: Dictionary = _glide(BEST_GLIDE)
	_table.append("glide at 68 KIAS, idle: %.1f to 1 by energy (%.2f m/s sink) against about %.1f; energy lost %.0f m"
		% [r["ratio"], r["sink"], GLIDE_RATIO, r["lost"]])
	_check("it_loses_energy_gliding", float(r["lost"]) > 0.0, "%.0f m of energy height lost over the measured 40 s" % r["lost"])
	_check("it_glides_about_as_far_as_the_book_says", float(r["ratio"]) > GLIDE_RATIO * 0.8 and float(r["ratio"]) < GLIDE_RATIO * 1.35,
		"%.1f to 1 against %.1f, 0.8 to 1.35 of it" % [r["ratio"], GLIDE_RATIO])


func _the_take_off_roll() -> void:
	var r: Dictionary = _take_off()
	_table.append("take-off: off the ground after %.0f m and %.1f s at %.1f m/s, against %.0f m (960 ft at 2,550 lb, scaled)"
		% [r["distance"], r["seconds"], r["speed"], GROUND_ROLL])
	# UP TO 1.7 OF IT, and that is the drawing, not the engine. The POH lifts off at 51 KIAS, a CL of about 1.6 and so
	# its own stall, nose high. The drawn tail, measured off [IM], touches the runway at 8.55 degrees of rotation about the
	# mains, where this wing's CL with ten degrees of flap is about 1.0, so it lifts off at 1.1 x its stall: 337 m. The
	# acceleration to there is the book's. (Until lane/cessnafm the collision hull touched at 7.6 degrees: 358 m.)
	_check("its_take_off_roll_is_about_the_books", float(r["distance"]) > GROUND_ROLL * 0.6 and float(r["distance"]) < GROUND_ROLL * 1.7,
		"%.0f m against %.0f, 0.6 to 1.7 of it" % [r["distance"], GROUND_ROLL])


func _the_roll_rate() -> void:
	var speed: float = 50.0
	var rate: float = _full_roll(speed)
	var pb2v: float = deg_to_rad(rate) * SPAN / (2.0 * speed)
	_table.append("full aileron at %.0f m/s: %.0f deg/s, pb/2V %.3f against %.2f to %.2f" % [speed, rate, pb2v, PB2V_LOW, PB2V_HIGH])
	_check("it_rolls_like_a_light_aeroplane", pb2v >= PB2V_LOW and pb2v <= PB2V_HIGH,
		"pb/2V %.3f (%.0f deg/s at %.0f m/s) against %.2f to %.2f" % [pb2v, rate, speed, PB2V_LOW, PB2V_HIGH])


func _stalls() -> void:
	var s: Dictionary = _surfaces_report()
	_table.append("book stall from the wing: %.1f m/s clean, %.1f with full flap (surfaces.gd flies them)"
		% [float(s.get("stall", 0.0)), float(s.get("stall_flaps", 0.0))])
	_table.append("the autopilot's Vy: %.1f m/s against the POH's %.1f (74 KIAS); its climb budget there %.1f m/s"
		% [float(s.get("best_climb_speed", 0.0)), VY, float(s.get("climb_budget", 0.0))])


# ---- the flights -----------------------------------------------------------------------------------------------------

## `--circles=<file>`: the autopilot at 30 degrees of bank and 55 m/s on each model, 130 s of it, its track written as
## "model x z" lines every half second after the first 20 s. A probe for the before-and-after picture of the turn's
## radius (lane/cessnafm), not a check.
func _circles(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	for surfaces in [0.0, 1.0]:
		_world = _new_world()
		_world.set_handling(KIND, {"surfaces": surfaces})
		_craft = int(_world.spawn_ai_vehicle(KIND, Vector3(0.0, 800.0, 0.0), 0.0, Vector3(0.0, 0.0, -55.0)))
		_world.set_ai_manners(_craft, {"bank": deg_to_rad(30.0)})
		for i in range(int(130.0 / TICK)):
			var now: Dictionary = _read()
			if i % 60 == 0:
				var nose: Vector3 = now["nose"]
				var right := Vector3(-nose.z, 0.0, nose.x).normalized()
				_world.steer_ai(_craft, {"toward": (now["at"] as Vector3) + right * 20000.0, "altitude": 800.0,
					"speed": 55.0})
				if i >= int(20.0 / TICK):
					var at: Vector3 = now["at"]
					file.store_line("%s %.1f %.1f %.1f %.1f" % ["surfaces" if surfaces > 0.5 else "lumped", at.x, at.z,
						now["speed"], now["bank"]])
			_world.tick(TICK)
		_end()
	file.close()


## `--descent`: the autopilot at the pattern's base speed asked down 150 m, traced every quarter second. A probe, not a
## check: what lane/cessnafm looked at when the surface Cessna's descents hunted.
func _autopilot_descent(speed: float) -> void:
	_world = _new_world()
	_apply_card()
	_craft = int(_world.spawn_ai_vehicle(KIND, Vector3(0.0, 800.0, 0.0), 0.0, Vector3(0.0, 0.0, -speed)))
	for i in range(int(40.0 / TICK)):
		var now: Dictionary = _read()
		if i % 30 == 0:
			var asked: float = 800.0 if i < int(20.0 / TICK) else 650.0
			_world.steer_ai(_craft, {"toward": (now["at"] as Vector3) + (now["nose"] as Vector3) * 20000.0,
				"altitude": asked, "speed": speed})
			if i >= int(18.0 / TICK):
				var levers: Dictionary = _world.vehicle_state(_craft)
				print("[cessna_book]   descent t %.2f y %.1f vy %+.2f v %.1f pitch %.1f throttle %.2f" % [i * TICK,
					(now["at"] as Vector3).y, now["vy"], now["speed"], now["pitch"], float(levers.get("throttle", -1.0))])
		_world.tick(TICK)
	_end()


## The autopilot, told to turn for ever at `bank`: 25 s to settle, then 15 s measured.
func _autopilot_turn(bank: float) -> Dictionary:
	_world = _new_world()
	_apply_card()
	var cruise: float = float(_world.handling(KIND).get("cruise", 0.0))
	if cruise <= 0.0:
		cruise = 55.0
	_craft = int(_world.spawn_ai_vehicle(KIND, Vector3(0.0, 800.0, 0.0), 0.0, Vector3(0.0, 0.0, -cruise)))
	_world.set_ai_manners(_craft, {"bank": bank})
	var out := {"ratio": 0.0, "bank": 0.0, "speed": 0.0, "rate": 0.0, "height": 0.0}
	if _craft == 0:
		_end()
		return out
	var banks := 0.0
	var speeds := 0.0
	var n := 0
	var start_heading := 0.0
	var turned := 0.0
	var last_heading := 0.0
	var start_height := 0.0
	var ticks: int = int(40.0 / TICK)
	for i in range(ticks):
		if i % 60 == 0:
			var now: Dictionary = _read()
			# A POINT A LONG WAY OFF 90 DEGREES TO THE RIGHT, re-aimed every half second: the heading error never closes.
			var nose: Vector3 = now["nose"]
			var right := Vector3(-nose.z, 0.0, nose.x).normalized()
			_world.steer_ai(_craft, {"toward": (now["at"] as Vector3) + right * 20000.0, "altitude": 800.0,
				"speed": cruise})
		_world.tick(TICK)
		if i == int(25.0 / TICK):
			var r0: Dictionary = _read()
			last_heading = float(r0["heading"])
			start_height = (r0["at"] as Vector3).y
		elif i > int(25.0 / TICK):
			var r: Dictionary = _read()
			turned += wrapf(float(r["heading"]) - last_heading, -180.0, 180.0)
			last_heading = float(r["heading"])
			banks += float(r["bank"])
			speeds += float(r["speed"])
			n += 1
			out["height"] = (r["at"] as Vector3).y - start_height
	var seconds: float = n * TICK
	var mean_bank: float = banks / maxf(n, 1)
	var mean_speed: float = speeds / maxf(n, 1)
	var rate: float = turned / maxf(seconds, 0.001)
	var book: float = rad_to_deg(9.81 * tan(deg_to_rad(absf(mean_bank))) / maxf(mean_speed, 1.0))
	out["ratio"] = absf(rate) / maxf(book, 0.001)
	out["bank"] = mean_bank
	out["speed"] = mean_speed
	out["rate"] = rate
	_end()
	return out


## Level at full throttle for 90 s, the hand holding the height: the speed it ends at.
func _level_full_power() -> float:
	if not _spawn(Vector3(0.0, 800.0, 0.0), Vector3(0.0, 0.0, -55.0)):
		return 0.0
	var t := 0.0
	while t < 90.0:
		var r: Dictionary = _read()
		_input["throttle"] = 1.0
		_fly(r, _pitch_for_height(r, 800.0), 0.0)
		_step(4)
		t += TICK * 4.0
	var top: float = float(_read()["speed"])
	_end()
	return top


## The speed held by the stick at `speed` and the throttle at `throttle`, wings level: the mean climb rate over the last
## `watch` seconds of 25 + watch.
func _held_speed(speed: float, throttle: float, watch: float) -> float:
	if not _spawn(Vector3(0.0, 800.0, 0.0), Vector3(0.0, 0.0, -speed)):
		return 0.0
	var aim := 3.0
	var t := 0.0
	var from_y := 0.0
	while t < 25.0 + watch:
		var r: Dictionary = _read()
		_input["throttle"] = throttle
		# The pitch the speed wants: nose up when fast. A slow integrator on the attitude, so it settles on the path.
		aim = clampf(aim + 0.6 * (float(r["speed"]) - speed) * TICK * 4.0, -20.0, 25.0)
		_fly(r, aim + 0.8 * (float(r["speed"]) - speed), 0.0)
		_step(4)
		t += TICK * 4.0
		if absf(t - 25.0) < TICK * 2.0:
			from_y = (_read()["at"] as Vector3).y
	var climb: float = ((_read()["at"] as Vector3).y - from_y) / watch
	_end()
	return climb


## Idle, the speed held by the stick: distance flown over energy height lost, for 40 s after 25 s of settling.
func _glide(speed: float) -> Dictionary:
	var out := {"ratio": 0.0, "sink": 0.0, "lost": 0.0}
	if not _spawn(Vector3(0.0, 1500.0, 0.0), Vector3(0.0, 0.0, -speed)):
		return out
	var aim := -4.0
	var t := 0.0
	var e0 := 0.0
	var p0 := Vector3.ZERO
	while t < 65.0:
		var r: Dictionary = _read()
		_input["throttle"] = 0.0
		aim = clampf(aim + 0.6 * (float(r["speed"]) - speed) * TICK * 4.0, -25.0, 15.0)
		_fly(r, aim + 0.8 * (float(r["speed"]) - speed), 0.0)
		_step(4)
		t += TICK * 4.0
		if absf(t - 25.0) < TICK * 2.0:
			var s: Dictionary = _read()
			p0 = s["at"]
			e0 = p0.y + pow(float(s["speed"]), 2.0) / (2.0 * 9.81)
	var e: Dictionary = _read()
	var at: Vector3 = e["at"]
	var lost: float = e0 - (at.y + pow(float(e["speed"]), 2.0) / (2.0 * 9.81))
	var flat: float = Vector2(at.x - p0.x, at.z - p0.z).length()
	out["lost"] = lost
	out["sink"] = lost / 40.0
	out["ratio"] = flat / maxf(lost, 0.01)
	_end()
	return out


## From a standstill on a flat slab, full throttle, ten degrees of flap, the hand rotating at 47 KIAS to 8.3 degrees:
## the distance run to the first tick with the wheels a metre clear.
func _take_off() -> Dictionary:
	var out := {"distance": 0.0, "seconds": 0.0, "speed": 0.0}
	_world = _new_world()
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(40000.0, 400.0, 40000.0))
	_apply_card()
	_world.set_handling(KIND, {"augmentation": 0.0})
	var made: Dictionary = _world.spawn_pilot(CLIENT, KIND, Vector3(0.0, 2.0, 0.0), 0.0, Vector3.ZERO)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_input = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	# TEN DEGREES OF FLAP, the POH's own take-off configuration for its chart: a third of the lever's 30.
	_command(Sim.Channel.FLAPS, 85)
	_step(240)
	var rest: Vector3 = _read()["at"]
	var t := 0.0
	while t < 60.0:
		var r: Dictionary = _read()
		_input["throttle"] = 1.0
		_input["brake"] = 0.0
		# A PILOT'S HANDS, raw, as the POH flies its chart: stick neutral to the lift-off speed (51 KIAS at 2,550 lb, so
		# 47 at 1,000 kg), then firmly back to 8.3 degrees, just short of the drawn tail at 8.55, and held there. Not the
		# law: on the wheels the ground holds the pitch rate at nothing, and a rate asked of the law through the stick
		# never learns why (the first cut lifted off at 43.9 m/s after 704 m).
		var rotate: bool = float(r["speed"]) > 51.0 * KNOT * sqrt(GAME_MASS / POH_MASS)
		_input["pitch"] = clampf(0.25 + 0.3 * (8.3 - float(r["pitch"])), -1.0, 1.0) if rotate else 0.0
		_input["roll"] = clampf(0.03 * (0.0 - float(r["bank"])), -1.0, 1.0)
		_step(1)
		t += TICK
		var at: Vector3 = _read()["at"]
		if OS.get_cmdline_user_args().has("--trace") and fmod(t, 1.0) < TICK:
			var s: Dictionary = _read()
			print("[cessna_book]   take-off t %.0f v %.1f pitch %.1f stick %+.2f up %.2f run %.0f"
				% [t, s["speed"], s["pitch"], _input["pitch"], at.y - rest.y, Vector2(at.x - rest.x, at.z - rest.z).length()])
		if at.y > rest.y + 1.0:
			out["distance"] = Vector2(at.x - rest.x, at.z - rest.z).length()
			out["seconds"] = t
			out["speed"] = float(_read()["speed"])
			break
	_end()
	return out


## Full right stick from level at a speed, feet still, raw: the fastest roll rate in the first 1.5 s, deg/s.
func _full_roll(speed: float) -> float:
	if not _spawn(Vector3(0.0, 1500.0, 0.0), Vector3(0.0, 0.0, -speed), 0.0):
		return 0.0
	var t := 0.0
	while t < 3.0:
		var r: Dictionary = _read()
		_input["throttle"] = 0.5
		_fly(r, _pitch_for_height(r, 1500.0), 0.0)
		_step(4)
		t += TICK * 4.0
	var fastest := 0.0
	var last: float = float(_read()["bank"])
	t = 0.0
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


# ---- the hand and the world ------------------------------------------------------------------------------------------

## A RATE STICK (the law), so a performance number is the aeroplane's and not the hand's: the stick asks for a pitch rate
## of two and a half times the attitude error a second, as `tests/surfaces.gd` flies one.
func _fly(r: Dictionary, pitch_to: float, bank_to: float) -> void:
	_input["pitch"] = clampf(2.5 * (pitch_to - float(r["pitch"])) / rad_to_deg(1.2), -1.0, 1.0)
	_input["roll"] = clampf(2.5 * (bank_to - float(r["bank"])) / rad_to_deg(2.0), -1.0, 1.0)
	_input["rudder"] = 0.0


func _pitch_for_height(r: Dictionary, height: float) -> float:
	return clampf(4.0 + 0.25 * (height - (r["at"] as Vector3).y) - 1.2 * float(r["vy"]), -10.0, 25.0)


func _new_world() -> RefCounted:
	var w: RefCounted = ClassDB.instantiate("CockpitWorld")
	w.set_tick_rate(120.0)
	w.start(0)
	return w


## THE CARD, and the Cessna on its surfaces unless the card says otherwise.
func _apply_card() -> void:
	var tuned: Dictionary = {"surfaces": 1.0 if _mutant_surfaces else 0.0}
	var now: Dictionary = _world.handling(KIND)
	var retune: Dictionary = _card.retune if _mutant_surfaces else {}
	for key in retune:
		var o: Array = retune[key]
		tuned[key] = float(now.get(key, 0.0)) * float(o[1]) if bool(o[0]) else float(o[1])
	_world.set_handling(KIND, tuned)


## A PILOT in a Cessna in the air. `augmentation` 1 (the stick asks the law for a rate) unless a raw stick is asked for.
func _spawn(at: Vector3, velocity: Vector3, augmentation: float = 1.0) -> bool:
	_world = _new_world()
	_apply_card()
	_world.set_handling(KIND, {"augmentation": augmentation})
	var made: Dictionary = _world.spawn_pilot(CLIENT, KIND, at, 0.0, velocity)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_seq = 0
	_input = {"throttle": 0.4, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	return _craft != 0 and _pilot != 0


func _surfaces_report() -> Dictionary:
	_world = _new_world()
	_apply_card()
	var s: Dictionary = _world.lifting_surfaces(KIND)
	_end()
	return s


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
	var v: Vector3 = s.get("velocity", Vector3.ZERO)
	return {
		"at": s.get("position", Vector3.ZERO) as Vector3,
		"v": v,
		"nose": nose,
		"speed": v.length(),
		"vy": v.y,
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"bank": rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))),
		# HEADINGS GROW TO THE RIGHT here, so a turn to the right is a positive change.
		"heading": rad_to_deg(atan2(nose.x, -nose.z)),
	}


# ---- the verdict -----------------------------------------------------------------------------------------------------

func _check(name: String, ok: bool, detail: String) -> void:
	if ok or _probe:
		_passed += 1
	else:
		_failed += 1
	print("[cessna_book] %s %s (%s)" % ["PASS" if ok else "FAIL", name, detail])


func _finish() -> void:
	print("[cessna_book] %d passed, %d failed%s" % [_passed, _failed, " (probe: nothing held)" if _probe else ""])
	print("RESULT=%s" % ("PASS" if _failed == 0 else "FAIL"))
	get_tree().quit(0 if _failed == 0 else 1)
