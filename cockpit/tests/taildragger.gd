extends Node
## Headless: A TAILDRAGGER ON ITS THREE WHEELS, flown from the pilot's control frame (lane/warbirds2). The user: "some are
## tail dragger aircraft you'll have to make sure to handle that correctly."
##
##   Godot --headless --path cockpit res://tests/taildragger.tscn [-- --kind=p51 --trace]
##
## WHAT A TAILWHEEL PILOT IS TAUGHT, each checked from the hands -- the throttle, the stick, the pedals and the brake
## through `set_pilot_input` -- never from the functions that make it happen, and each with the mutant that must turn it
## red:
## - IT RESTS ON THREE POINTS at the rake its drawing parks at (`WarbirdAirframe.parked()`), the tail wheel and both mains
##   on the ground. Mutant: the collision hull's flat box (`ground_mutant` 2), which rests level.
## - THE TAIL COMES UP BEFORE IT LIFTS OFF: held down while the rudder has no air, raised to a nearly level attitude, then
##   flown off, down the centreline. Mutant: no elevator (`surface_mutant` 4).
## - IT CAN GROUND-LOOP, and the rudder and brakes catch it: after a kick with the tail wheel unlocked and the pedals let
##   go, the swing grows by itself, because the mains are ahead of the centre of gravity. Mutant: the wheel forces at the
##   mass centre with a nosewheel's servo (`ground_mutant` 1), where it stops.
## - NORMAL BRAKES DO NOT NOSE IT OVER; standing on them with the tail up does. Mutant: the brakes at the mass centre
##   (`ground_mutant` 1), which never pitch it.
## - A THREE-POINT LANDING AND A WHEEL LANDING are both landings to the crash rule, not a tail strike or a nose-over.
##
## THE HANDS ARE A ROBOT'S THROUGH THE CONTROL LAW (augmentation 1: the stick asks for a rate), as `cessna_book.gd`'s
## performance hand is, so a number is the aeroplane's and not the hand's; the brake tests fly raw (augmentation 0), where
## a neutral stick is a neutral elevator and does not fight the nose down.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 60
const MPH: float = 0.44704
const FEET: float = 0.3048

## THE BOOKS' TAKE-OFFS, the ground run and the lift-off speed, at the weight the game flies each kind at.
## - P-51D: AN 01-60JE-1, 1,450 ft at 9,400 lb (the game's 9,480), 15 to 20 degrees of flap; 95 mph IAS off at 9,000 lb
##   and 103 at 10,000.
## - P-47D-30: NO GROUND RUN IS PUBLISHED. The RAF card gives 1,050 yd (960 m) to clear 50 ft at its 14,600 lb maximum;
##   a ground run is about 0.6 of a distance over 50 ft, so about 575 m there, and the game flies it at 13,230 lb, a
##   tenth lighter, so about 520 m -- DERIVED, and that is why the band below is as wide as it is. Off at 120 mph: its
##   clean stall is 116 (Eng-47-1774-A) and [T3]'s take-offs were made WITHOUT FLAPS, so it cannot leave the ground
##   slower than that. ITS BAND IS WIDER, 0.6 to 2.1, and both halves of the reason are written down: the book figure is
##   derived twice (a share of a distance over 50 ft, then scaled off a different weight), so it carries its own fifth
##   either way; and the straight propeller line costs a Thunderbolt more than it costs a Mustang, because a 2,000 hp
##   engine on a 13 ft paddle-bladed propeller is where a constant-speed propeller differs most from a line. Flown:
##   1,029 m, 2.0 of the derived figure, where flightcore's constant-speed prototype takes about a third off.
const BOOK: Dictionary = {
	"p51": {"ground_run": 1450.0 * FEET, "lift_off": 99.0 * MPH},
	"p47": {"ground_run": 520.0, "lift_off": 120.0 * MPH, "run_band": Vector2(0.6, 2.1)},
}
## THE BAND a take-off run is held to, of the book's -- the default, which a kind may widen in its own row
## (`run_band`) when its book figure is itself derived. UP TO 1.7 OF IT, the Cessna's (`cessna_book.gd`), and why: the P-51
## lifts off at 1.2 x its stall, 55 m/s, where the book's 99 mph is its stall. Its wing in this model makes a CL of about
## 1.0 at the three-point attitude with no ground effect, which a real one near the runway has. And the straight propeller
## line gives 16 kN static where a real Merlin gives 20 or more (warbirds_book.md section 1). The first honest run was 692 m
## against 442: not tuned to the number, "good enough, tune later" (team-lead, 2026-09-19), and ground effect is the lever.
const RUN_LOW: float = 0.6
const RUN_HIGH: float = 1.7
## A CLOSED THROTTLE, as a hand holds one: see `_hands`.
const IDLE: float = 0.002
## HOW MUCH EARLIER THE ELEVATOR MUST BRING THE TAIL UP than the wing alone does, m/s.
const TAIL_UP_EARLIER: float = 5.0
## THE TIGHTEST TURN A TAXIING TAILDRAGGER MUST MANAGE, metres of radius: a taxiway's turn, about a wingspan. Its tail
## wheel alone steers a few degrees (49 m on the P-51), so this is the unlocked wheel and the inside brake.
const TAXI_TURN_MOST: float = 15.0

var _world: RefCounted
var _craft: int = 0
var _pilot: int = 0
var _seq: int = 0
var _input: Dictionary = {}
var _kind: int = 0
var _name: String = ""
var _frame: WarbirdAirframe = null
var _kills: Array = []
var _passed: int = 0
var _failed: int = 0
var _trace: bool = OS.get_cmdline_user_args().has("--trace")


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "no CockpitWorld")
		_finish()
		return
	var only: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--kind="):
			only = argument.trim_prefix("--kind=")
	for kind in _taildraggers():
		_kind = kind
		_name = Sim.kind_name(kind)
		if not only.is_empty() and only != _name:
			continue
		_frame = VehicleView.warbird_for(kind)
		_frame.dress()
		add_child(_frame)
		print("[taildragger] ---- %s ----" % _name)
		_it_rests_on_three_points()
		_the_tail_comes_up_before_it_lifts_off()
		_it_ground_loops_and_the_pedals_catch_it()
		_it_turns_inside_a_taxiway_on_its_brakes()
		_normal_brakes_hold_and_standing_on_them_tail_up_noses_it_over()
		_three_point_and_wheel_landings_are_landings()
		_frame.queue_free()
	_finish()


## EVERY KIND THE SIMULATION CALLS A TAILDRAGGER, asked of it and never listed here: its centre of gravity aft of its mains
## (`lifting_surfaces(kind)["taildragger"]`). The suite then insists the P-51 is among them.
func _taildraggers() -> Array:
	var out: Array = []
	var w: RefCounted = _new_world()
	for kind in Sim.Kind.values():
		if bool(w.lifting_surfaces(kind).get("taildragger", false)):
			out.append(kind)
	w.teardown()
	_check("the_p51_is_a_taildragger_by_its_own_centre_of_gravity", out.has(Sim.Kind.P51),
		"taildraggers %s" % [out.map(func(k: int) -> String: return Sim.kind_name(k))])
	return out


# ---- the checks ------------------------------------------------------------------------------------------------------

## AT REST: put down on its wheels and left alone for four seconds, it stands at the drawn three-point rake with the drawn
## tyres on the ground.
func _it_rests_on_three_points() -> void:
	var rake: float = _drawn_rake()
	var r: Dictionary = _rest_on({})
	var ok: bool = absf(float(r["pitch"]) - rake) < 0.5 and float(r["worst_tyre"]) < 0.05 and float(r["speed"]) < 0.05
	_check("%s_rests_on_three_points_at_its_drawn_rake" % _name, ok,
		"pitch %.2f deg against the drawn %.2f; the drawn tyres' bottoms %.3f m off the ground at worst; %.3f m/s"
		% [r["pitch"], rake, r["worst_tyre"], r["speed"]])
	var flat: Dictionary = _rest_on({"ground_mutant": 2.0})
	_check("%s_the_rest_check_fails_on_a_flat_box" % _name, absf(float(flat["pitch"]) - rake) > 3.0,
		"mutant: pitch %.2f deg on the collision box's flat bottom" % flat["pitch"])


func _the_tail_comes_up_before_it_lifts_off() -> void:
	var book: Dictionary = BOOK.get(_name, {})
	var rake: float = _drawn_rake()
	var stall: float = float(_stall())
	var r: Dictionary = _take_off({}, 0.0)
	_check("%s_raises_its_tail_before_it_lifts_off" % _name, bool(r["lifted"]) and float(r["least_pitch"]) < rake - 8.0,
		"pitch fell from %.1f to %.1f deg on the ground before lift-off, the tail up at %.1f m/s; lifted %s"
		% [rake, r["least_pitch"], r["tail_up_at"], r["lifted"]])
	_check("%s_lifts_off_near_its_stall" % _name,
		bool(r["lifted"]) and float(r["speed"]) > stall and float(r["speed"]) < stall * 1.35,
		"off at %.1f m/s against a stall of %.1f and the book's %.1f" % [r["speed"], stall, book.get("lift_off", 0.0)])
	var run: float = float(book.get("ground_run", 0.0))
	var band: Vector2 = book.get("run_band", Vector2(RUN_LOW, RUN_HIGH))
	_check("%s_its_ground_run_is_about_the_books" % _name,
		bool(r["lifted"]) and float(r["distance"]) > run * band.x and float(r["distance"]) < run * band.y,
		"%.0f m in %.1f s against %.0f, %.1f to %.1f of it" % [r["distance"], r["seconds"], run, band.x, band.y])
	_check("%s_holds_the_centreline" % _name, float(r["across"]) < 10.0 and float(r["swing"]) < 6.0,
		"%.1f m off the line at worst, the heading %.1f deg off at worst" % [r["across"], r["swing"]])
	# THE MUTANT, NO ELEVATOR: the tail comes up in the end whatever the elevator does, because the wing's lift unloads
	# the wheels and its own moment about the mains raises it. What the ELEVATOR does is bring it up EARLIER, and that is
	# what this holds: at least `TAIL_UP_EARLIER` m/s earlier than the wing alone manages.
	var dead: Dictionary = _take_off({"surface_mutant": 4.0}, 0.0)
	_check("%s_the_elevator_is_what_raises_the_tail" % _name,
		float(r["tail_up_at"]) > 0.0 and (float(dead["tail_up_at"]) <= 0.0
			or float(dead["tail_up_at"]) - float(r["tail_up_at"]) >= TAIL_UP_EARLIER),
		"the tail came up at %.1f m/s; with no elevator at %s (at least %.0f m/s later)"
		% [r["tail_up_at"], "never" if float(dead["tail_up_at"]) <= 0.0 else "%.1f m/s" % float(dead["tail_up_at"]),
			TAIL_UP_EARLIER])


## THE KICK: at 15 m/s with the tail down and the throttle closed, the stick PUSHED FORWARD past `kTailwheelUnlock` so the
## tail wheel castors (AN 01-60JE-1 unlocks the P-51D's with the stick full forward), the right pedal and a touch of brake
## for 0.4 s, then the feet off. The swing that follows is the aeroplane's.
func _it_ground_loops_and_the_pedals_catch_it() -> void:
	var loose: Dictionary = _kick({}, false)
	var centred: Dictionary = _kick({"ground_mutant": 1.0}, false)
	var caught: Dictionary = _kick({}, true)
	_check("%s_swings_on_by_itself_after_a_kick" % _name, float(loose["swing"]) > 25.0,
		"%.1f deg off in 3 s after the pedals were let go, from %.1f at the kick's end" % [loose["swing"], loose["kicked"]])
	_check("%s_the_ground_loop_check_fails_with_the_wheels_at_the_centre" % _name, float(centred["swing"]) < 15.0,
		"mutant: %.1f deg off in 3 s, from %.1f" % [centred["swing"], centred["kicked"]])
	_check("%s_the_pedals_and_brakes_catch_it" % _name, float(caught["final"]) < 5.0 and float(caught["swing"]) < 25.0,
		"%.1f deg off after 3 s of rudder and brake, %.1f at worst" % [caught["final"], caught["swing"]])


## A TAXI TURN: at a walking pace, the stick full forward so the tail wheel castors and the inside brake on, it must come
## round inside `TAXI_TURN_MOST`. WITH THE TAIL WHEEL LOCKED -- the stick back, its own few degrees of steering -- the same
## turn is far wider, and that is the comparison: it is why a pilot unlocks it, and why the autopilot does
## (`roll_on_a_tail_wheel`).
func _it_turns_inside_a_taxiway_on_its_brakes() -> void:
	var loose: Dictionary = _taxi_turn(true)
	var locked: Dictionary = _taxi_turn(false)
	_check("%s_turns_inside_a_taxiway_on_the_unlocked_wheel_and_its_brakes" % _name,
		float(loose["radius"]) > 0.0 and float(loose["radius"]) <= TAXI_TURN_MOST,
		"%.1f m of radius, %.0f degrees round in %.1f s (at most %.0f m)" % [loose["radius"], loose["turned"],
			loose["seconds"], TAXI_TURN_MOST])
	_check("%s_the_turn_is_the_unlocked_wheel_and_not_the_rudder" % _name,
		float(locked["radius"]) <= 0.0 or float(locked["radius"]) > float(loose["radius"]) * 2.0,
		"with the tail wheel locked: %s" % ["never came round 60 degrees" if float(locked["radius"]) <= 0.0
			else "%.1f m of radius" % float(locked["radius"])])


## ROLLING AT A WALKING PACE, then the right pedal and the inside brake held, with the stick forward (the tail wheel
## castoring) or back (locked): the radius of the turn it makes, from how far it went round and how far it travelled.
func _taxi_turn(unlocked: bool) -> Dictionary:
	var out := {"radius": 0.0, "turned": 0.0, "seconds": 0.0}
	_on_the_ground({}, 1.0)
	var t := 0.0
	while t < 30.0 and float(_read()["speed"]) < 4.0:
		var r: Dictionary = _read()
		_input = _hands()
		_input["throttle"] = 0.25
		_input["pitch"] = 0.5
		_input["rudder"] = _pedal(r, 0.0)
		_step(1)
		t += TICK
	var from: Vector3 = _read()["at"]
	var h0: float = float(_read()["heading"])
	var path := 0.0
	var last: Vector3 = from
	t = 0.0
	while t < 40.0:
		_input = _hands()
		_input["throttle"] = 0.2
		_input["pitch"] = -1.0 if unlocked else 0.8
		_input["rudder"] = 1.0
		_input["brake"] = 0.55
		_step(1)
		t += TICK
		var at: Vector3 = _read()["at"]
		path += at.distance_to(last)
		last = at
		var turned: float = absf(_angle(float(_read()["heading"]) - h0))
		if turned >= 60.0:
			out["turned"] = turned
			out["seconds"] = t
			# The radius of the arc it actually drove: the path it covered over the angle it came round.
			out["radius"] = path / deg_to_rad(turned)
			break
	if _trace:
		print("[taildragger]   taxi turn %s: %.0f deg in %.1f s, %.1f m of path" % ["unlocked" if unlocked else "locked",
			out["turned"], out["seconds"], path])
	_end()
	return out


func _normal_brakes_hold_and_standing_on_them_tail_up_noses_it_over() -> void:
	var rake: float = _drawn_rake()
	var half: Dictionary = _brake_from(30.0, false, 0.5, {})
	_check("%s_half_brake_tail_down_stops_it_and_keeps_its_tail_down" % _name,
		bool(half["stopped"]) and not bool(half["lost"]) and float(half["least_pitch"]) > rake - 3.0,
		"stopped %s in %.0f m, pitch never under %.1f deg (rake %.1f), %s"
		% [half["stopped"], half["distance"], half["least_pitch"], rake, half["rule"]])
	var hard: Dictionary = _brake_from(40.0, true, 1.0, {})
	_check("%s_full_brake_tail_up_noses_it_over" % _name,
		bool(hard["lost"]) and String(hard["rule"]).contains("nosed over"),
		"%s; pitch down to %.1f deg" % [hard["rule"], hard["least_pitch"]])
	var centred: Dictionary = _brake_from(40.0, true, 1.0, {"ground_mutant": 1.0})
	_check("%s_the_nose_over_check_fails_with_the_brakes_at_the_centre" % _name, not bool(centred["lost"]),
		"mutant: %s, pitch down to %.1f deg" % [centred["rule"] if bool(centred["lost"]) else "whole", centred["least_pitch"]])


func _three_point_and_wheel_landings_are_landings() -> void:
	var rake: float = _drawn_rake()
	var three: Dictionary = _land(true)
	_check("%s_a_three_point_landing_is_a_landing" % _name,
		bool(three["touched"]) and not bool(three["lost"]) and absf(float(three["pitch"]) - rake) < 3.0,
		"touched at %.1f deg (rake %.1f), %.2f m/s down, %.1f m/s along; %s"
		% [three["pitch"], rake, three["sink"], three["speed"], three["rule"] if bool(three["lost"]) else "whole"])
	var wheel: Dictionary = _land(false)
	_check("%s_a_wheel_landing_is_a_landing" % _name,
		bool(wheel["touched"]) and not bool(wheel["lost"]) and float(wheel["pitch"]) < rake - 5.0,
		"touched at %.1f deg (rake %.1f), %.2f m/s down, %.1f m/s along; %s"
		% [wheel["pitch"], rake, wheel["sink"], wheel["speed"], wheel["rule"] if bool(wheel["lost"]) else "whole"])


# ---- the flights -----------------------------------------------------------------------------------------------------

func _rest_on(handling: Dictionary) -> Dictionary:
	_on_the_ground(handling, 1.0)
	_input = _hands()
	_step(480)
	var r: Dictionary = _read()
	var worst: float = 0.0
	for contact in _frame.wheel_contacts():
		worst = maxf(worst, absf((_to_world(r, contact as Vector3)).y))
	_end()
	return {"pitch": r["pitch"], "worst_tyre": worst, "speed": r["speed"]}


## FULL THROTTLE over three seconds, and the hands as the manual flies it: the stick back until the rudder bites, then the
## tail raised to a fifth of the rake, then lifted off at 1.15 x the stall with the tail wheel just clear. The run is measured to the
## first tick with the wheels a metre clear; with `stop_at` it ends at that speed instead, tail up.
func _take_off(handling: Dictionary, stop_at: float) -> Dictionary:
	var out := {"lifted": false, "least_pitch": 90.0, "speed": 0.0, "distance": 0.0, "seconds": 0.0, "across": 0.0,
		"swing": 0.0, "tail_up_at": 0.0}
	_on_the_ground(handling, 1.0)
	_command(Sim.Channel.FLAPS, 85)
	var rake: float = _drawn_rake()
	var stall: float = _stall()
	var rest: Vector3 = _read()["at"]
	var level_y: float = float(Sim.geometry_of(_kind)["extents"].y)
	var t := 0.0
	while t < 60.0:
		var r: Dictionary = _read()
		var v: float = float(r["speed"])
		_input = _hands()
		_input["throttle"] = clampf(t / 3.0, IDLE, 1.0)
		_input["rudder"] = _pedal(r, 0.0)
		_input["roll"] = _level_wings(r)
		if v < 0.35 * stall:
			_input["pitch"] = 0.5
		else:
			_input["pitch"] = _attitude(r, rake * 0.2 if v < 1.15 * stall else rake - 1.5)
		_step(1)
		t += TICK
		var at: Vector3 = _read()["at"]
		var still_down: bool = at.y < level_y + 1.0
		if still_down:
			out["least_pitch"] = minf(float(out["least_pitch"]), float(_read()["pitch"]))
			if float(out["tail_up_at"]) <= 0.0 and float(_read()["pitch"]) < rake - 8.0:
				out["tail_up_at"] = v
		out["across"] = maxf(float(out["across"]), absf(at.x - rest.x))
		out["swing"] = maxf(float(out["swing"]), absf(float(_read()["heading"])))
		if _trace and fmod(t, 1.0) < TICK:
			print("[taildragger]   take-off t %.0f v %.1f pitch %.1f stick %+.2f pedal %+.2f run %.0f across %.1f"
				% [t, _read()["speed"], _read()["pitch"], _input["pitch"], _input["rudder"], rest.z - at.z, at.x - rest.x])
		if stop_at > 0.0 and float(_read()["speed"]) >= stop_at:
			out["speed"] = float(_read()["speed"])
			return out
		if not still_down:
			out["lifted"] = true
			out["speed"] = float(_read()["speed"])
			out["distance"] = Vector2(at.x - rest.x, at.z - rest.z).length()
			out["seconds"] = t
			break
	_end()
	return out


func _kick(handling: Dictionary, catch: bool) -> Dictionary:
	var out := {"swing": 0.0, "kicked": 0.0, "final": 0.0}
	_on_the_ground(handling, 1.0)
	var t := 0.0
	while t < 40.0 and float(_read()["speed"]) < 15.0:
		var r: Dictionary = _read()
		_input = _hands()
		_input["throttle"] = 0.6
		_input["pitch"] = 0.5
		_input["rudder"] = _pedal(r, 0.0)
		_step(1)
		t += TICK
	var h0: float = float(_read()["heading"])
	for i in range(int(0.4 / TICK)):
		_input = _hands()
		_input["pitch"] = -0.8
		_input["rudder"] = 1.0
		_input["brake"] = 0.5
		_step(1)
	out["kicked"] = absf(float(_read()["heading"]) - h0)
	for i in range(int(3.0 / TICK)):
		var r: Dictionary = _read()
		_input = _hands()
		if catch:
			_input["pitch"] = 0.5
			_input["rudder"] = _pedal(r, h0)
			_input["brake"] = 0.4 if absf(_angle(float(r["heading"]) - h0)) > 3.0 else 0.0
		else:
			_input["pitch"] = -0.8
		_step(1)
		var off: float = absf(_angle(float(_read()["heading"]) - h0))
		out["swing"] = maxf(float(out["swing"]), off)
		if _trace and i % 24 == 0:
			print("[taildragger]   kick %s t %.1f v %.1f heading %+.1f yaw rate %+.1f" % ["caught" if catch else "loose",
				i * TICK, _read()["speed"], off, _read()["yaw_rate"]])
	out["final"] = absf(_angle(float(_read()["heading"]) - h0))
	_end()
	return out


## FROM `speed` ON THE RUNWAY, the throttle closed and the brake held at `pedal`, raw: with the tail down and the stick held
## fully back, or with the tail up (the take-off's hands to that speed) and the stick let go to neutral.
func _brake_from(speed: float, tail_up: bool, pedal: float, handling: Dictionary) -> Dictionary:
	var out := {"stopped": false, "lost": false, "rule": "", "least_pitch": 90.0, "distance": 0.0}
	if tail_up:
		_take_off(handling, speed)
	else:
		_on_the_ground(handling, 1.0)
		var t := 0.0
		while t < 40.0 and float(_read()["speed"]) < speed:
			var r: Dictionary = _read()
			_input = _hands()
			_input["throttle"] = 1.0
			_input["pitch"] = 0.8
			_input["rudder"] = _pedal(r, 0.0)
			_step(1)
			t += TICK
	_world.set_handling(_kind, {"augmentation": 0.0})
	var from: Vector3 = _read()["at"]
	var t := 0.0
	while t < 30.0:
		var r: Dictionary = _read()
		_input = _hands()
		_input["brake"] = pedal
		_input["pitch"] = 0.0 if tail_up else 1.0
		_input["rudder"] = clampf(_pedal(r, 0.0), -0.3, 0.3)
		_step(1)
		t += TICK
		for kill in _world.take_kills():
			out["lost"] = true
			out["rule"] = String((kill as Dictionary).get("rule", ""))
		if bool(out["lost"]):
			break
		out["least_pitch"] = minf(float(out["least_pitch"]), float(_read()["pitch"]))
		if float(_read()["speed"]) < 0.3:
			out["stopped"] = true
			break
	var at: Vector3 = _read()["at"]
	out["distance"] = Vector2(at.x - from.x, at.z - from.z).length()
	_end()
	return out


## A LANDING FROM 20 m UP ON A 3-DEGREE PATH, gear and full flap down. THREE-POINT: the throttle closed at 6 m and the sink
## bled away by the stick until it settles at the stall on all three wheels. WHEEL: flown on at 1.2 x the stall with a
## little power, the attitude held under a third of the rake, and the stick eased forward once the mains are down.
func _land(three_point: bool) -> Dictionary:
	var out := {"touched": false, "lost": false, "rule": "", "pitch": 0.0, "sink": 0.0, "speed": 0.0}
	var stall: float = _stall_with_flaps()
	var rake: float = _drawn_rake()
	var approach: float = stall * (1.25 if three_point else 1.3)
	var at := Vector3(0.0, float(Sim.geometry_of(_kind)["extents"].y) + 20.0, 400.0)
	_world = _new_world()
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(40000.0, 400.0, 40000.0))
	_world.set_handling(_kind, {"augmentation": 1.0})
	var made: Dictionary = _world.spawn_pilot(CLIENT, _kind, at, 0.0,
		Vector3(0.0, -approach * 0.0524, -approach))
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_command(Sim.Channel.GEAR, 1)
	_command(Sim.Channel.FLAPS, 255)
	var t := 0.0
	var aim := 0.0
	while t < 60.0:
		var r: Dictionary = _read()
		var low: float = _wheels_up(r)
		_input = _hands()
		_input["rudder"] = _pedal(r, 0.0)
		_input["roll"] = _level_wings(r)
		var want_sink: float = approach * 0.0524
		if three_point:
			_input["throttle"] = 0.25 if low > 6.0 else IDLE
			if low < 6.0:
				want_sink = clampf(low * 0.35, 0.4, want_sink)
		else:
			_input["throttle"] = 0.3
			if low < 4.0:
				want_sink = clampf(low * 0.3, 0.3, want_sink)
		aim = clampf(aim + 2.0 * (-want_sink - float(r["vy"])) * TICK, -8.0, rake + 2.0)
		if not three_point:
			aim = minf(aim, rake * 0.33)
		_input["pitch"] = _attitude(r, aim, 2.0)
		_step(1)
		t += TICK
		for kill in _world.take_kills():
			out["lost"] = true
			out["rule"] = String((kill as Dictionary).get("rule", ""))
		if bool(out["lost"]):
			break
		if not bool(out["touched"]) and _wheels_up(_read()) < 0.03:
			var s: Dictionary = _read()
			out["touched"] = true
			out["pitch"] = s["pitch"]
			out["sink"] = -float(s["vy"])
			out["speed"] = s["speed"]
			break
	# AND THE ROLL-OUT: the stick back (forward first, after a wheel landing, while it is fast), the brake gently once
	# slow, until it stops or is lost.
	var touch_speed: float = float(out["speed"])
	t = 0.0
	while bool(out["touched"]) and not bool(out["lost"]) and t < 40.0:
		var r: Dictionary = _read()
		_input = _hands()
		_input["rudder"] = _pedal(r, 0.0)
		var fast: bool = float(r["speed"]) > 0.7 * touch_speed
		_input["pitch"] = -0.1 if (fast and not three_point) else 0.8
		_input["brake"] = 0.3 if float(r["speed"]) < 0.6 * touch_speed else 0.0
		_step(1)
		t += TICK
		for kill in _world.take_kills():
			out["lost"] = true
			out["rule"] = String((kill as Dictionary).get("rule", ""))
		if float(_read()["speed"]) < 0.5:
			break
	out["sink"] = maxf(float(out["sink"]), float(_world.touchdown_report(false).get(_craft, 0.0)))
	_end()
	return out


# ---- the hands -------------------------------------------------------------------------------------------------------

## THE HANDS AT REST, the throttle closed. CLOSED IS `IDLE` AND NOT 0: a throttle input of 0 is a hand let go, and the lever
## HOLDS where it was (`apply_pilot_input`). The first kicks and brake runs here were flown at the power the lever was
## left at, and a "half brake from 30 m/s" ran on for 1,100 m.
func _hands() -> Dictionary:
	return {"throttle": IDLE, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}


## THE PEDALS toward a heading, with the yaw rate damped: a taildragger's heading on its wheels is unstable, and the
## error alone swings it through the line.
func _pedal(r: Dictionary, heading: float) -> float:
	return clampf(0.05 * _angle(heading - float(r["heading"])) - 0.03 * float(r["yaw_rate"]), -1.0, 1.0)


## AN ATTITUDE, asked of the law as a pitch rate of six times the error a second: firmly, as the autopilot asks, since the
## law does not know the ground holds the tail's weight (`tail_up_and_off`).
func _attitude(r: Dictionary, pitch: float, gain: float = 6.0) -> float:
	var rate: float = float(_world.handling(_kind).get("pitch_rate", 1.2))
	return clampf(gain * deg_to_rad(pitch - float(r["pitch"])) / maxf(rate, 0.1), -1.0, 1.0)


func _level_wings(r: Dictionary) -> float:
	var rate: float = float(_world.handling(_kind).get("roll_rate", 1.8))
	return clampf(2.0 * deg_to_rad(-float(r["bank"])) / maxf(rate, 0.1), -1.0, 1.0)


# ---- the world -------------------------------------------------------------------------------------------------------

func _new_world() -> RefCounted:
	var w: RefCounted = ClassDB.instantiate("CockpitWorld")
	w.set_tick_rate(120.0)
	w.start(0)
	return w


## A PILOT IN IT, put down on a flat slab at the origin facing north, a hair over its level-built height: it is issued
## at its rake by the simulation (`spawn_vehicle`) and settles.
func _on_the_ground(handling: Dictionary, augmentation: float) -> void:
	_world = _new_world()
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(40000.0, 400.0, 40000.0))
	var tuned: Dictionary = handling.duplicate()
	tuned["augmentation"] = augmentation
	_world.set_handling(_kind, tuned)
	var hy: float = float(Sim.geometry_of(_kind)["extents"].y)
	var made: Dictionary = _world.spawn_pilot(CLIENT, _kind, Vector3(0.0, hy + 0.05, 0.0), 0.0, Vector3.ZERO)
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_seq = 0
	_input = _hands()
	_step(240)


func _end() -> void:
	if _world != null:
		_world.teardown()
	_world = null


func _command(channel: int, value: int) -> void:
	_seq = _seq % 3 + 1
	var frame: Dictionary = _hands()
	frame["command_channel"] = channel
	frame["command_value"] = value
	frame["command_seq"] = _seq
	for i in range(3):
		_world.set_pilot_input(_pilot, frame)
		_world.tick(TICK)


func _step(ticks: int) -> void:
	for i in range(ticks):
		_world.set_pilot_input(_pilot, _input)
		_world.tick(TICK)


func _read() -> Dictionary:
	var s: Dictionary = _world.vehicle_state(_craft)
	var q: Quaternion = s.get("basis", Quaternion())
	var b := Basis(q)
	var nose: Vector3 = b * Vector3.FORWARD
	var right: Vector3 = b * Vector3.RIGHT
	var v: Vector3 = s.get("velocity", Vector3.ZERO)
	var spin: Vector3 = s.get("spin", Vector3.ZERO)
	return {
		"at": s.get("position", Vector3.ZERO) as Vector3,
		"basis": b,
		"v": v,
		"vy": v.y,
		"speed": v.length(),
		"pitch": rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))),
		"bank": rad_to_deg(asin(clampf(-right.y, -1.0, 1.0))),
		# HEADINGS GROW TO THE RIGHT, and so does the yaw rate.
		"heading": rad_to_deg(atan2(nose.x, -nose.z)),
		"yaw_rate": rad_to_deg(-spin.y),
	}


func _to_world(r: Dictionary, local: Vector3) -> Vector3:
	return (r["at"] as Vector3) + (r["basis"] as Basis) * local


## THE LOWEST DRAWN TYRE'S BOTTOM over the slab, metres.
func _wheels_up(r: Dictionary) -> float:
	var lowest: float = INF
	for contact in _frame.wheel_contacts():
		lowest = minf(lowest, _to_world(r, contact as Vector3).y)
	return lowest


## THE RAKE THE DRAWING PARKS AT, degrees nose up: `parked()`'s turn, which stands the drawn tyres on level ground.
func _drawn_rake() -> float:
	var nose: Vector3 = _frame.parked().basis * Vector3.FORWARD
	return rad_to_deg(asin(clampf(nose.y, -1.0, 1.0)))


func _stall() -> float:
	var w: RefCounted = _new_world()
	var s: float = float(w.lifting_surfaces(_kind).get("stall", 0.0))
	w.teardown()
	return s


func _stall_with_flaps() -> float:
	var w: RefCounted = _new_world()
	var s: float = float(w.lifting_surfaces(_kind).get("stall_flaps", 0.0))
	w.teardown()
	return s


static func _angle(degrees: float) -> float:
	return wrapf(degrees, -180.0, 180.0)


# ---- the verdict -----------------------------------------------------------------------------------------------------

func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[taildragger] %s %s (%s)" % ["PASS" if ok else "FAIL", name, detail])


func _finish() -> void:
	print("[taildragger] %d passed, %d failed" % [_passed, _failed])
	print("RESULT=%s" % ("PASS" if _failed == 0 else "FAIL"))
	get_tree().quit(0 if _failed == 0 else 1)
