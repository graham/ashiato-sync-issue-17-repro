extends Node
## A TRAIN THAT IS ACTUALLY DRIVEN, and one that is not. Headless. Read RESULT=, not the exit code.
##
## WHY THIS EXISTS. Two things about the island's trains had never been run, only reasoned about:
##
## 1. **Nothing drives them.** `run_on_rails` applies a drawbar pull only when somebody is in the driving seat, and the
##    level spawns its trains empty, so the rolling resistance and the drag were the only forces on them: measured
##    below, a locomotive left alone lost its speed steadily and came to a stand in about ten minutes. A quarter of an
##    hour into a session the island had two stopped trains on it and nothing said why. An unmanned train now holds the
##    speed it is running at, which costs no new state and no wire change -- see `run_on_rails`.
## 2. **The locomotive's mass rose 49 per cent** when the F7A became an SD40-2 (112.2 t to the published 167 t), and the
##    only thing said about it was arithmetic. `learnings/2026-09-17-train.md` put "a check that DRIVES the locomotive"
##    at the top of its What's next for exactly this reason: pull is `min(thrust, rail_power / pace)` and resistance is
##    `1600 N + 8 v^2`, neither of which depends on mass, so the top speed cannot move and only the acceleration and the
##    stopping distance can -- **reasoned, not driven**, and the user's rule is to verify the function.
##
## IT RUNS ITS OWN WORLD, as `tests/air.gd` does: a `CockpitWorld` of its own with one circular railway on it, so the
## numbers are the simulation's and nothing about the island's traffic, scenery or weather is in them. A driver is a
## pilot moved into the locomotive's seat with `seat_client`, which is what the take-the-next-craft button does.
##
## THE NUMBERS ARE PRINTED whatever the verdict, because this file is also how the two libraries were compared when the
## mass changed. Run it against another `ashiato_gd.double.dll` and the same lines come out for that one.

## The rate the world is ticked at, and how long a train is left alone.
const TICK: float = 1.0 / 120.0
const LEFT_ALONE: float = 60.0
## What the island spawns its trains at.
const SPAWN_SPEED: float = 22.0
## HOW MUCH SPEED AN UNMANNED TRAIN MAY LOSE in a minute. It is not zero, because a curve's bank and the float's own
## rounding are in there; it is far inside the 2 m/s the old resistance took off it.
const KEEPS_WITHIN: float = 0.01
## The pace an acceleration run is timed to, and the loose bounds the two driven measurements are held to. They are
## wide on purpose: this check exists to prove the locomotive still DRIVES, not to pin a feel that is tuned elsewhere.
const UP_TO: float = 20.0
const REACHES_IT_WITHIN: float = 180.0
const STOPS_WITHIN: float = 1200.0
## A railway to run on: a circle big enough that its bank is the island's own order, sampled as the island samples it.
const LOOP_RADIUS: float = 2000.0
const LOOP_STEP: float = 10.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[train_runs] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("the_native_library_is_loaded", false, "no CockpitWorld")
		_finish()
		return
	_an_unmanned_train_keeps_running()
	await get_tree().process_frame
	_a_driven_train_pulls_away_and_stops()
	_finish()


## ---- 1. left alone ---------------------------------------------------------------------------

func _an_unmanned_train_keeps_running() -> void:
	var world: Object = _a_world()
	var train: int = int(world.spawn_train(0, 0.0, SPAWN_SPEED))
	if train == 0:
		_check("a_train_can_be_put_on_the_railway", false, "spawn_train returned nothing")
		world.teardown()
		return
	var began: float = float((world.rail_state(train) as Dictionary).get("speed", 0.0))
	for i in range(int(LEFT_ALONE / TICK)):
		world.tick(TICK)
	var after: float = float((world.rail_state(train) as Dictionary).get("speed", 0.0))
	var lost: float = began - after
	# AND WHAT THAT MEANS IN MINUTES, which is the number anybody would ask for next.
	var to_a_stand: String = "it holds its speed"
	if lost > 0.001:
		to_a_stand = "at that rate it would stand still in %.1f minutes" % (began / lost)
	world.teardown()
	_check("a_train_nobody_is_driving_still_runs_a_minute_later", absf(lost) <= KEEPS_WITHIN,
		"%.3f m/s after %.0f s against %.3f at the start; %s" % [after, LEFT_ALONE, began, to_a_stand])


## ---- 2. driven -------------------------------------------------------------------------------

## FULL REGULATOR FROM A STAND, then full brake from `UP_TO`. Both numbers are printed, because they are what moved when
## the locomotive's mass did and the point of measuring is to say by how much.
func _a_driven_train_pulls_away_and_stops() -> void:
	var world: Object = _a_world()
	var train: int = int(world.spawn_train(0, 0.0, 0.0))
	var driver: int = _a_driver_in(world, train)
	if train == 0 or driver == 0:
		_check("a_driver_can_take_the_locomotive", false, "train %d, driver %d" % [train, driver])
		world.teardown()
		return
	world.set_pilot_input(driver, {"throttle": 1.0, "brake": 0.0})
	var pulling: float = 0.0
	var start: float = float((world.rail_state(train) as Dictionary).get("distance", 0.0))
	var ticks: int = 0
	while ticks < int(REACHES_IT_WITHIN / TICK):
		world.tick(TICK)
		ticks += 1
		if float((world.rail_state(train) as Dictionary).get("speed", 0.0)) >= UP_TO:
			break
	pulling = float(ticks) * TICK
	var ran: float = float((world.rail_state(train) as Dictionary).get("distance", 0.0)) - start
	var got_to: float = float((world.rail_state(train) as Dictionary).get("speed", 0.0))
	_check("a_driven_train_pulls_away_from_a_stand", got_to >= UP_TO,
		"%.1f m/s after %.0f s and %.0f m, the first %.1f m/s in %.1f s"
		% [got_to, pulling, ran, UP_TO, pulling])

	world.set_pilot_input(driver, {"throttle": 0.0, "brake": 1.0})
	var braked_from: float = got_to
	var at: float = float((world.rail_state(train) as Dictionary).get("distance", 0.0))
	ticks = 0
	while ticks < int(600.0 / TICK):
		world.tick(TICK)
		ticks += 1
		if float((world.rail_state(train) as Dictionary).get("speed", 0.0)) <= 0.05:
			break
	var stopping: float = float((world.rail_state(train) as Dictionary).get("distance", 0.0)) - at
	var left: float = float((world.rail_state(train) as Dictionary).get("speed", 0.0))
	world.teardown()
	_check("and_stops_when_its_brake_is_put_on", left <= 0.05 and stopping <= STOPS_WITHIN,
		"%.0f m and %.1f s from %.1f m/s, ending at %.3f m/s"
		% [stopping, float(ticks) * TICK, braked_from, left])


## ---- the world it runs in ----------------------------------------------------------------------

## A WORLD WITH ONE RAILWAY ON IT: a circle, laid the way `FlightLevel` lays the island's, so the bank and the chords
## are the same machinery. No ground, no scenery and no weather -- a train is not a free body and touches none of it.
func _a_world() -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var steps: int = int(round(TAU * LOOP_RADIUS / LOOP_STEP))
	for i in range(steps):
		var angle: float = TAU * float(i) / float(steps)
		world.add_rail_point(0, Vector3(cos(angle) * LOOP_RADIUS, 3.0, sin(angle) * LOOP_RADIUS), 0.0)
	world.close_rail(0)
	return world


## A PILOT IN THE LOCOMOTIVE'S SEAT. There is no call that makes a pilot without a craft -- by design, since a pilot
## with nowhere to sit is a state nothing knows how to draw -- so one is spawned in a craft of its own and then moved
## into the train with `seat_client`, which is exactly what the take-the-next-craft button does.
func _a_driver_in(world: Object, train: int) -> int:
	var made: Dictionary = world.spawn_pilot(1, Sim.Kind.PLANE, Vector3(0.0, 400.0, 0.0), 0.0, Vector3.ZERO)
	var driver: int = int(made.get("pilot", 0))
	if driver == 0 or not bool(world.seat_client(1, train, 0)):
		return 0
	return driver


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
