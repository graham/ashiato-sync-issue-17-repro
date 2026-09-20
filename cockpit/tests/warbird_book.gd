extends Node
## Headless: THE WARBIRDS AGAINST THEIR BOOKS, on their lifting surfaces (lane/warbirds2).
##
##   Godot --headless --path cockpit res://tests/warbird_book.tscn [-- --kind=p51 --probe]
##
## `cessna_book.gd`'s checks, one row a kind, each flown through the pilot's control frame or its own autopilot and
## each against a PUBLISHED figure at sea level (the only height the model has), never against the model's formula. The
## books, their sources and the fits are `research/warbirds_book.md` and `research/warbirds_sources.md`:
## - the turn a bank buys, flown by the autopilot: rate over g tan(bank) / v, at 1 by definition. The lumped wing is the
##   mutant;
## - the top speed at sea level on military power, level, at full throttle;
## - the climb at the best-climb speed on military power;
## - the roll: pb/2V at full aileron at a speed the book's roll data covers.
## The take-off run and the landing are a taildragger's own, in `tests/taildragger.gd`. The stall, which the book fixes
## CLmax by, is reported: `surfaces.gd` is where a flown stall is judged.
##
## `--probe` prints the table and passes whatever it says. Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 60
const MPH: float = 0.44704
const FPM: float = 0.00508

## THE BOOKS, one a kind, the figures at sea level on military power (`warbirds_sources.md` has each one's source):
## - top: level flat out, m/s;
## - vy and climb: the best-climb speed and the climb there;
## - pb2v: the band a full aileron's roll is held to, at `roll_at` m/s;
## - span: the drawn span, for pb/2V;
## - height: where it is flown, well clear of the ground.
const BOOKS: Dictionary = {
	# THE P-51D: Wright Field's 364 mph at 9,760 lb (TSCEP5E-1908); NAA's 3,030 ft/min on military (NA-46-130) at 170 mph,
	# which is an ESTIMATE of its best-climb speed (none is published); NACA TR 868's P-51B, about 94 deg/s at 300 mph
	# with 50 lb of stick, pb/2V about 0.07, and a fighter's full aileron at a slower 80 m/s between 0.06 and 0.10.
	"p51": {"top": 364.0 * MPH, "vy": 170.0 * MPH, "climb": 3030.0 * FPM, "pb2v": Vector2(0.06, 0.10), "roll_at": 80.0,
		"span": 11.286, "height": 1500.0},
	# THE P-47D-30: Wright Field's 299 mph on military power at 13,230 lb, read off Eng-47-1774-A's Fig. 2 (GRAPH, +/-3
	# mph); its best-climb speed is TN 2675's 158 mph trim point, and NO SEA-LEVEL MILITARY CLIMB IS PUBLISHED FOR IT, so
	# the climb is held BETWEEN TWO FIGURES THAT ARE: over the 2,030 ft/min it made at 12,000 ft on the same 52 in Hg
	# (same power, same drag at the same EAS, 20 per cent more true airspeed to drag through, so sea level must beat it),
	# and under the 3,260 ft/min best rate it made at 10,000 ft on 65 in WET, which is a quarter more power again.
	# TN 2675 prints a maximum pb/2V of 0.074 at 30 lb of stick; the band allows a fifth either side of it.
	"p47": {"top": 299.0 * MPH, "vy": 158.0 * MPH, "climb": Vector2(2030.0 * FPM, 3260.0 * FPM),
		"pb2v": Vector2(0.059, 0.089), "roll_at": 80.0, "span": 12.429, "height": 1500.0},
}

var _world: RefCounted
var _craft: int = 0
var _pilot: int = 0
var _input: Dictionary = {}
var _kind: int = 0
var _name: String = ""
var _book: Dictionary = {}
var _card: TuningCard = TuningCard.from_command_line()
var _probe: bool = OS.get_cmdline_user_args().has("--probe")
var _passed: int = 0
var _failed: int = 0
var _table: Array[String] = []
## False only while the turn's mutant flies: the kind on its lumped wing.
var _mutant_surfaces: bool = true


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "no CockpitWorld")
		_finish()
		return
	var only: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--kind="):
			only = argument.trim_prefix("--kind=")
	print("[warbird_book] card %s" % str(_card.retune))
	for kind in Sim.Kind.values():
		var name: String = Sim.kind_name(kind)
		if not BOOKS.has(name) or (not only.is_empty() and only != name):
			continue
		_kind = kind
		_name = name
		_book = BOOKS[name]
		_table.append("---- %s ----" % name)
		_the_turn_a_bank_buys()
		_top_speed()
		_climb_at_vy()
		_the_roll_rate()
		_stalls()
	print("[warbird_book] ---- the book against the flown ----")
	for line in _table:
		print("[warbird_book]   %s" % line)
	_finish()


# ---- the checks ------------------------------------------------------------------------------------------------------

func _the_turn_a_bank_buys() -> void:
	for degrees in [30.0, 45.0]:
		var r: Dictionary = _autopilot_turn(deg_to_rad(degrees))
		_table.append("turn at %.0f deg (AI): %.2f of g tan(bank)/v, bank flown %.1f, %.1f m/s, height %+.1f m"
			% [degrees, r["ratio"], r["bank"], r["speed"], r["height"]])
		_check("%s_the_autopilot_turns_at_the_rate_its_bank_buys_at_%d_deg" % [_name, int(degrees)],
			float(r["ratio"]) > 0.9 and float(r["ratio"]) < 1.1 and absf(float(r["height"])) < 20.0,
			"%.2f of g tan(bank)/v at %.1f deg flown, height %+.1f m over the measured 15 s" % [r["ratio"], r["bank"], r["height"]])
	_mutant_surfaces = false
	var old: Dictionary = _autopilot_turn(deg_to_rad(30.0))
	_mutant_surfaces = true
	_table.append("turn at 30 deg (AI) on the LUMPED wing: %.2f of g tan(bank)/v" % old["ratio"])
	_check("%s_the_turn_check_fails_on_the_lumped_wing" % _name, float(old["ratio"]) < 0.9,
		"mutant: %.2f of g tan(bank)/v at %.1f deg with surfaces off" % [old["ratio"], old["bank"]])


func _top_speed() -> void:
	var top: float = _level_full_power()
	var book: float = float(_book["top"])
	_table.append("top speed at sea level: %.1f m/s (%.0f mph) against the book's %.0f mph" % [top, top / MPH, book / MPH])
	_check("%s_its_top_speed_is_the_books" % _name, absf(top / book - 1.0) < 0.05,
		"%.1f m/s level at full throttle against %.1f, within 5%%" % [top, book])


## THE CLIMB AT ITS BEST-CLIMB SPEED. A book figure is either ONE NUMBER, held to 0.85 to 1.15 of it, or a BAND
## (Vector2) of two published numbers the answer must lie BETWEEN -- which is how a kind with no sea-level military climb
## in print is still held to something that can fail. See the P-47's row.
func _climb_at_vy() -> void:
	var vy: float = float(_book["vy"])
	var climb: float = _held_speed(vy, 1.0, 30.0)
	var band: Vector2 = _book["climb"] if _book["climb"] is Vector2 		else Vector2(float(_book["climb"]) * 0.85, float(_book["climb"]) * 1.15)
	_table.append("climb at %.0f mph, full throttle: %.2f m/s (%.0f ft/min) against %.0f to %.0f ft/min"
		% [vy / MPH, climb, climb / FPM, band.x / FPM, band.y / FPM])
	_check("%s_it_climbs_as_the_book_says" % _name, climb > band.x and climb < band.y,
		"%.2f m/s at %.1f m/s, held between %.2f and %.2f" % [climb, vy, band.x, band.y])


func _the_roll_rate() -> void:
	var speed: float = float(_book["roll_at"])
	var rate: float = _full_roll(speed)
	var pb2v: float = deg_to_rad(rate) * float(_book["span"]) / (2.0 * speed)
	var band: Vector2 = _book["pb2v"]
	_table.append("full aileron at %.0f m/s: %.0f deg/s, pb/2V %.3f against %.2f to %.2f" % [speed, rate, pb2v, band.x, band.y])
	_check("%s_it_rolls_like_the_book" % _name, pb2v >= band.x and pb2v <= band.y,
		"pb/2V %.3f (%.0f deg/s at %.0f m/s) against %.2f to %.2f" % [pb2v, rate, speed, band.x, band.y])


func _stalls() -> void:
	var s: Dictionary = _surfaces_report()
	_table.append("book stall from the wing: %.1f m/s clean, %.1f with gear and full flap; cruise %.1f; tail %.2f deg"
		% [float(s.get("stall", 0.0)), float(s.get("stall_flaps", 0.0)), float(s.get("cruise", 0.0)),
			rad_to_deg(float(s.get("tail_incidence", 0.0)))])
	_table.append("the autopilot's Vy %.1f m/s, its climb budget there %.1f m/s; the roll's time constant %.3f s"
		% [float(s.get("best_climb_speed", 0.0)), float(s.get("climb_budget", 0.0)), float(s.get("roll_time_constant", 0.0))])


# ---- the flights -----------------------------------------------------------------------------------------------------

## THE AUTOPILOT, told to turn for ever at `bank` at its own cruise: 25 s to settle, then 15 s measured. `cessna_book.gd`'s.
func _autopilot_turn(bank: float) -> Dictionary:
	_world = _new_world()
	_apply_card()
	var height: float = float(_book["height"])
	var cruise: float = float(_world.lifting_surfaces(_kind).get("cruise", 0.0))
	if cruise <= 0.0:
		cruise = 60.0
	_craft = int(_world.spawn_ai_vehicle(_kind, Vector3(0.0, height, 0.0), 0.0, Vector3(0.0, 0.0, -cruise)))
	_world.set_ai_manners(_craft, {"bank": bank})
	var out := {"ratio": 0.0, "bank": 0.0, "speed": 0.0, "rate": 0.0, "height": 0.0}
	if _craft == 0:
		_end()
		return out
	var banks := 0.0
	var speeds := 0.0
	var n := 0
	var turned := 0.0
	var last_heading := 0.0
	var start_height := 0.0
	for i in range(int(40.0 / TICK)):
		if i % 60 == 0:
			var now: Dictionary = _read()
			# A POINT A LONG WAY OFF 90 DEGREES TO THE RIGHT, re-aimed every half second: the heading error never closes.
			var nose: Vector3 = now["nose"]
			var right := Vector3(-nose.z, 0.0, nose.x).normalized()
			_world.steer_ai(_craft, {"toward": (now["at"] as Vector3) + right * 20000.0, "altitude": height,
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


func _level_full_power() -> float:
	var height: float = float(_book["height"])
	if not _spawn(Vector3(0.0, height, 0.0), Vector3(0.0, 0.0, -float(_book["top"]) * 0.85)):
		return 0.0
	var t := 0.0
	while t < 120.0:
		var r: Dictionary = _read()
		_input["throttle"] = 1.0
		_fly(r, _pitch_for_height(r, height), 0.0)
		_step(4)
		t += TICK * 4.0
	var top: float = float(_read()["speed"])
	_end()
	return top


func _held_speed(speed: float, throttle: float, watch: float) -> float:
	var height: float = float(_book["height"])
	if not _spawn(Vector3(0.0, height, 0.0), Vector3(0.0, 0.0, -speed)):
		return 0.0
	var aim := 5.0
	var t := 0.0
	var from_y := 0.0
	while t < 25.0 + watch:
		var r: Dictionary = _read()
		_input["throttle"] = throttle
		aim = clampf(aim + 0.6 * (float(r["speed"]) - speed) * TICK * 4.0, -20.0, 30.0)
		_fly(r, aim + 0.8 * (float(r["speed"]) - speed), 0.0)
		_step(4)
		t += TICK * 4.0
		if absf(t - 25.0) < TICK * 2.0:
			from_y = (_read()["at"] as Vector3).y
	var climb: float = ((_read()["at"] as Vector3).y - from_y) / watch
	_end()
	return climb


## Full right stick from level at a speed, feet still, raw: the fastest roll rate in the first 1.5 s, deg/s.
func _full_roll(speed: float) -> float:
	var height: float = float(_book["height"])
	if not _spawn(Vector3(0.0, height, 0.0), Vector3(0.0, 0.0, -speed), 0.0):
		return 0.0
	var t := 0.0
	while t < 3.0:
		var r: Dictionary = _read()
		_input["throttle"] = 0.6
		_fly_raw(r, _pitch_for_height(r, height))
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

## A RATE STICK (the law): the stick asks for a pitch rate of two and a half times the attitude error a second.
func _fly(r: Dictionary, pitch_to: float, bank_to: float) -> void:
	var h: Dictionary = _world.handling(_kind)
	_input["pitch"] = clampf(2.5 * deg_to_rad(pitch_to - float(r["pitch"])) / float(h.get("pitch_rate", 1.2)), -1.0, 1.0)
	_input["roll"] = clampf(2.5 * deg_to_rad(bank_to - float(r["bank"])) / float(h.get("roll_rate", 1.8)), -1.0, 1.0)
	_input["rudder"] = 0.0


## A RAW HAND for the roll's settling, wings level and the pitch toward an attitude: an elevator-sized gain.
func _fly_raw(r: Dictionary, pitch_to: float) -> void:
	_input["pitch"] = clampf(0.05 * (pitch_to - float(r["pitch"])), -1.0, 1.0)
	_input["roll"] = clampf(0.03 * (0.0 - float(r["bank"])), -1.0, 1.0)
	_input["rudder"] = 0.0


func _pitch_for_height(r: Dictionary, height: float) -> float:
	return clampf(2.0 + 0.25 * (height - (r["at"] as Vector3).y) - 1.2 * float(r["vy"]), -10.0, 20.0)


func _new_world() -> RefCounted:
	var w: RefCounted = ClassDB.instantiate("CockpitWorld")
	w.set_tick_rate(120.0)
	w.start(0)
	return w


func _apply_card() -> void:
	var tuned: Dictionary = {"surfaces": 1.0 if _mutant_surfaces else 0.0}
	var now: Dictionary = _world.handling(_kind)
	var retune: Dictionary = _card.retune if _mutant_surfaces else {}
	for key in retune:
		var o: Array = retune[key]
		tuned[key] = float(now.get(key, 0.0)) * float(o[1]) if bool(o[0]) else float(o[1])
	_world.set_handling(_kind, tuned)


func _spawn(at: Vector3, velocity: Vector3, augmentation: float = 1.0) -> bool:
	_world = _new_world()
	_apply_card()
	_world.set_handling(_kind, {"augmentation": augmentation})
	var made: Dictionary = _world.spawn_pilot(CLIENT, _kind, at, 0.0, velocity)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_input = {"throttle": 0.6, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	return _craft != 0 and _pilot != 0


func _surfaces_report() -> Dictionary:
	_world = _new_world()
	_apply_card()
	var s: Dictionary = _world.lifting_surfaces(_kind)
	_end()
	return s


func _end() -> void:
	if _world != null:
		_world.teardown()
	_world = null


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
		"nose": nose,
		"v": v,
		"speed": v.length(),
		"vy": v.y,
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"bank": rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))),
		"heading": rad_to_deg(atan2(nose.x, -nose.z)),
	}


# ---- the verdict -----------------------------------------------------------------------------------------------------

func _check(name: String, ok: bool, detail: String) -> void:
	if ok or _probe:
		_passed += 1
	else:
		_failed += 1
	print("[warbird_book] %s %s (%s)" % ["PASS" if ok else "FAIL", name, detail])


func _finish() -> void:
	print("[warbird_book] %d passed, %d failed%s" % [_passed, _failed, " (probe: nothing held)" if _probe else ""])
	print("RESULT=%s" % ("PASS" if _failed == 0 else "FAIL"))
	get_tree().quit(0 if _failed == 0 else 1)
