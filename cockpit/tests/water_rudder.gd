extends Node
## Headless: does a flying boat on the water turn when the pilot pushes a pedal, and go straight when they don't?
##
##   Godot --headless --path cockpit res://tests/water_rudder.tscn
##
## THE USER, 2026-09-18: "Let's make sure the two planes that can land in the water have some rudder steering when in the
## water." Before this, the pedals afloat worked only through `apply_controls`' fin, whose authority fades with airspeed
## towards a 12 per cent floor, and through `steer_on_the_ground`, which steers through WHEELS and never runs afloat --
## so a water bomber taxiing at 6 m/s barely turned at all.
##
## EVERY RUN IS FLOWN THROUGH `set_pilot_input`, the frame a seated player's rig sends: throttle to hold a taxi speed
## through the water, and the pedals. Nothing is placed or spun by hand.
##
## THE TWO FLYING BOATS: the water bomber, and Porco Rosso's Savoia -- which also has to float upright and take off from
## the water, the user's own description of it ("can land on water and drive around like a boat").
##
## WHAT IS HELD, and why each is the user's words and not an implementation:
## - AFLOAT, FULL PEDAL AT TAXI SPEED TURNS A FULL CIRCLE in CIRCLE_SECONDS -- "some rudder steering".
## - AFLOAT, PEDALS CENTRED, IT GOES STRAIGHT -- steering that wanders is not steering.
## - STILL IN THE WATER THROUGHOUT (`hull_wet` above zero every tick), or the circle was flown, not taxied.
## - ON WHEELS ON LAND THE TURN IS WHAT IT WAS: the rate measured on the library before the water rudder, typed below.
##   Flight is `tests/water.gd`'s: the hull reads exactly zero wet in the air, and the water rudder lives behind it.
##
## Read RESULT=.

const TICK: float = 1.0 / 120.0
const TANKER: int = 16
## Where the island's slab ends; beyond it there is only sea.
const COAST: float = 7200.0
## TAXI SPEED THROUGH THE WATER, m/s: the middle of the 5-8 the request names.
const TAXI: float = 6.5
## A FULL CIRCLE AT TAXI SPEED, seconds: the request's "say, 20-40 s".
const CIRCLE_SECONDS: Vector2 = Vector2(20.0, 40.0)
## AND THE SAVOIA'S: a 10 m racer on a 1.26 m hull turns tighter than a 20 m water bomber, and the user wants it nimble
## ("it's important this plane can do what it needs to with regards to manoeuvring"). Measured 15.2 s, 30 m across; 23.9 s
## and 48 m since 2026-09-18, when the fin's help at taxi speed began to fade with dynamic pressure (lane/groundroll).
const SAVOIA_CIRCLE_SECONDS: Vector2 = Vector2(10.0, 30.0)
## STRAIGHT: how far the heading may wander over STRAIGHT_SECONDS with the pedals centred.
const STRAIGHT_SECONDS: float = 40.0
const STRAIGHT_DEGREES: float = 5.0
## ON LAND, BEFORE THE WATER RUDDER: the tanker's steady turn on its nosewheel at 6.5 m/s with full pedal, measured on
## main 04432573's library (and 2df596b4's before it, the same to three places) by this suite's own
## `_on_land_the_turn_is_unchanged`. A water rudder must not move it.
const LAND_RATE_BEFORE: float = 16.662
const LAND_TOLERANCE: float = 0.05  # of the rate

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[water_rudder] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_afloat_full_pedal_turns_a_circle_at_taxi_speed()
	_afloat_with_the_pedals_centred_it_goes_straight()
	_on_land_the_turn_is_unchanged()
	_the_savoia_floats_upright_and_turns_on_the_water()
	_the_savoia_takes_off_from_the_water()
	_finish()


## A WORLD WITH THE ISLAND'S SLAB, and a tanker either out at sea, settled for ten seconds, or on the slab's top.
func _world() -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
	return world


func _heading(world: Object, craft: int) -> float:
	var turned := Basis(world.vehicle_state(craft).get("basis", Quaternion.IDENTITY) as Quaternion)
	var ahead: Vector3 = -turned.z
	return atan2(ahead.x, -ahead.z)


## THE PILOT'S HANDS: throttle held on the speed along the hull, the pedals as asked, the stick level.
func _taxi(world: Object, craft: int, pilot: int, rudder: float) -> float:
	var state: Dictionary = world.vehicle_state(craft)
	var turned := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
	var along: float = (state.get("velocity", Vector3.ZERO) as Vector3).dot(-turned.z)
	world.set_pilot_input(pilot, {"throttle": clampf(0.15 + (TAXI - along) * 0.25, 0.002, 1.0), "rudder": rudder,
		"pitch": 0.0, "roll": 0.0})
	return along


## TURN AND MEASURE: `seconds` of taxiing with `rudder`, and the steady turn rate over the last half, in degrees a second
## (positive to the right), with the mean speed and the least wetness seen.
func _turn(world: Object, craft: int, pilot: int, rudder: float, seconds: float, want_wet: bool) -> Dictionary:
	var turned: float = 0.0
	var last: float = _heading(world, craft)
	var speed_sum: float = 0.0
	var samples: int = 0
	var driest: float = INF
	var ticks: int = int(seconds / TICK)
	for i in range(ticks):
		var along: float = _taxi(world, craft, pilot, rudder)
		world.tick(TICK)
		var now: float = _heading(world, craft)
		var step: float = wrapf(now - last, -PI, PI)
		last = now
		if want_wet:
			driest = minf(driest, float(world.hull_wet(craft)))
		if i >= ticks / 2:
			turned += step
			speed_sum += along
			samples += 1
	return {"rate": rad_to_deg(turned) / (seconds * 0.5), "speed": speed_sum / maxf(samples, 1), "driest": driest}


func _afloat(world: Object, id: int, kind: int = TANKER) -> Dictionary:
	var made: Dictionary = world.spawn_pilot(id, kind, Vector3(0.0, 1.0, COAST + 1200.0), 0.0, Vector3.ZERO)
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	world.set_pilot_input(pilot, {"throttle": 0.002})
	for i in range(int(10.0 / TICK)):
		world.tick(TICK)
	return {"craft": craft, "pilot": pilot}


## AFLOAT, FULL RIGHT PEDAL AT TAXI SPEED: a full circle in 20 to 40 seconds, the hull in the water all the way round.
## Twenty seconds to get up to speed and settle into the turn, then forty measured.
func _afloat_full_pedal_turns_a_circle_at_taxi_speed() -> void:
	var world: Object = _world()
	var made: Dictionary = _afloat(world, 80)
	var craft: int = made["craft"]
	var pilot: int = made["pilot"]
	_turn(world, craft, pilot, 0.0, 20.0, true)
	var got: Dictionary = _turn(world, craft, pilot, 1.0, 60.0, true)
	var rate: float = float(got["rate"])
	var circle: float = 360.0 / absf(rate) if absf(rate) > 1e-3 else INF
	var across: float = float(got["speed"]) * circle / PI
	_check("afloat_full_pedal_turns_a_full_circle_at_taxi_speed",
		circle >= CIRCLE_SECONDS.x and circle <= CIRCLE_SECONDS.y and rate > 0.0 and float(got["driest"]) > 0.0,
		"%.2f deg/s to the %s at %.1f m/s through the water: a circle in %.1f s and %.0f m across, wanted %.0f-%.0f s; hull never drier than %.3f"
			% [rate, "right" if rate > 0.0 else "left", got["speed"], circle, across, CIRCLE_SECONDS.x, CIRCLE_SECONDS.y,
				got["driest"]])
	world.teardown()


## AFLOAT, PEDALS CENTRED: after the same twenty seconds to taxi speed, forty seconds straight, the heading within
## STRAIGHT_DEGREES of where it started.
func _afloat_with_the_pedals_centred_it_goes_straight() -> void:
	var world: Object = _world()
	var made: Dictionary = _afloat(world, 81)
	var craft: int = made["craft"]
	var pilot: int = made["pilot"]
	_turn(world, craft, pilot, 0.0, 20.0, true)
	var start: float = _heading(world, craft)
	var got: Dictionary = _turn(world, craft, pilot, 0.0, STRAIGHT_SECONDS, true)
	var drift: float = rad_to_deg(wrapf(_heading(world, craft) - start, -PI, PI))
	_check("afloat_with_the_pedals_centred_it_goes_straight",
		absf(drift) <= STRAIGHT_DEGREES and float(got["speed"]) > TAXI * 0.8 and float(got["driest"]) > 0.0,
		"heading wandered %.2f deg in %.0f s at %.1f m/s, allowed %.1f" % [drift, STRAIGHT_SECONDS, got["speed"],
			STRAIGHT_DEGREES])
	world.teardown()


## ON THE ISLAND'S SLAB, ON ITS WHEELS: the same taxi and full pedal, and the steady turn is the rate measured before
## there was a water rudder. `water_under` is false on land, so nothing new should reach it.
func _on_land_the_turn_is_unchanged() -> void:
	var world: Object = _world()
	var made: Dictionary = world.spawn_pilot(82, TANKER, Vector3(0.0, 3.0, 0.0), 0.0, Vector3.ZERO)
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	world.set_pilot_input(pilot, {"throttle": 0.002})
	for i in range(int(3.0 / TICK)):
		world.tick(TICK)
	_turn(world, craft, pilot, 0.0, 10.0, false)
	var got: Dictionary = _turn(world, craft, pilot, 1.0, 30.0, false)
	var wet: float = float(world.hull_wet(craft))
	var rate: float = float(got["rate"])
	var same: bool = not is_nan(LAND_RATE_BEFORE) and absf(rate - LAND_RATE_BEFORE) <= absf(LAND_RATE_BEFORE) * LAND_TOLERANCE
	_check("on_land_on_its_wheels_the_turn_is_what_it_was_before", same and wet == 0.0,
		"%.3f deg/s at %.1f m/s, before the water rudder %.3f; hull wet %.3f on land" % [rate, got["speed"],
			LAND_RATE_BEFORE, wet])
	world.teardown()


## ---- the second flying boat --------------------------------------------------------------------------------------

## PORCO ROSSO'S SAVOIA, the other plane the user meant: set down on the sea it floats the right way up with its hull in
## the water, and at taxi speed full pedal turns it a full circle in 10-30 s, tighter than the tanker. Nothing here is Savoia-specific in
## the simulation -- it is an amphibian kind, so the water rudder reaches it by where it is.
func _the_savoia_floats_upright_and_turns_on_the_water() -> void:
	var world: Object = _world()
	var made: Dictionary = _afloat(world, 83, Sim.Kind.SAVOIA)
	var craft: int = made["craft"]
	var pilot: int = made["pilot"]
	var state: Dictionary = world.vehicle_state(craft)
	var at: Vector3 = state.get("position", Vector3.ZERO)
	var up: float = Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion).y.y
	var wet: float = float(world.hull_wet(craft))
	_check("the_savoia_set_down_on_the_sea_floats_upright_in_it", wet > 0.0 and up > 0.95 and at.y > -3.0,
		"after 10 s: hull %.3f wet, up axis %.3f of vertical, origin at h %.2f" % [wet, up, at.y])
	_turn(world, craft, pilot, 0.0, 20.0, true)
	var got: Dictionary = _turn(world, craft, pilot, 1.0, 60.0, true)
	var rate: float = float(got["rate"])
	var circle: float = 360.0 / absf(rate) if absf(rate) > 1e-3 else INF
	_check("the_savoia_afloat_full_pedal_turns_a_full_circle_at_taxi_speed",
		circle >= SAVOIA_CIRCLE_SECONDS.x and circle <= SAVOIA_CIRCLE_SECONDS.y and rate > 0.0 and float(got["driest"]) > 0.0,
		"%.2f deg/s at %.1f m/s through the water: a circle in %.1f s, %.0f m across, wanted %.0f-%.0f s; hull never drier than %.3f"
			% [rate, got["speed"], circle, float(got["speed"]) * circle / PI, SAVOIA_CIRCLE_SECONDS.x, SAVOIA_CIRCLE_SECONDS.y,
				got["driest"]])
	world.teardown()


## AND IT TAKES OFF FROM THE WATER: full throttle from rest on the sea, the stick level until it is going fast enough to
## fly, then a climb asked of the stick. Within a minute it must be dry and 30 m up.
func _the_savoia_takes_off_from_the_water() -> void:
	var world: Object = _world()
	var made: Dictionary = _afloat(world, 84, Sim.Kind.SAVOIA)
	var craft: int = made["craft"]
	var pilot: int = made["pilot"]
	var start: float = float((world.vehicle_state(craft).get("position", Vector3.ZERO) as Vector3).y)
	var unstuck: float = -1.0
	var unstuck_speed: float = 0.0
	var high: float = -INF
	for i in range(int(60.0 / TICK)):
		var going: Vector3 = world.vehicle_state(craft).get("velocity", Vector3.ZERO)
		var pitch: float = clampf((0.0 - going.y) * 0.1, -0.3, 0.0)
		if going.length() >= 45.0:
			pitch = clampf((5.0 - going.y) * 0.08, -0.3, 0.4)
		world.set_pilot_input(pilot, {"throttle": 1.0, "pitch": pitch, "roll": 0.0, "rudder": 0.0})
		world.tick(TICK)
		if unstuck < 0.0 and float(world.hull_wet(craft)) == 0.0:
			unstuck = float(i + 1) * TICK
			unstuck_speed = (world.vehicle_state(craft).get("velocity", Vector3.ZERO) as Vector3).length()
		high = maxf(high, float((world.vehicle_state(craft).get("position", Vector3.ZERO) as Vector3).y))
	var dry: bool = float(world.hull_wet(craft)) == 0.0
	_check("the_savoia_takes_off_from_the_water", unstuck > 0.0 and dry and high - start > 30.0,
		"off the water %.1f s after full power doing %.1f m/s, %.0f m up after a minute, dry %s" % [unstuck, unstuck_speed,
			high - start, dry])
	world.teardown()


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
