extends Node
## Headless: does a segway go where the stick points, stay on the ground, and never lean?
##
##   Godot --headless --path cockpit res://tests/segway.tscn
##
## THE SEGWAY IS HOW A PLAYER WALKS, decided on 2026-09-15:
##
##   "just put them in an invisible vehicle called a segway that way they can move around and they
##   are still in a vehicle (but just make it a sphere at their feet."
##
## which settles the lobby's hard part. This game has no walking and every rig is seated, so a player
## on foot would be a second kind of moving thing for replication, rollback, the crew manifest and
## boarding each to get wrong. A segway is a VEHICLE, so all of that comes for nothing -- and what
## has to be proved is only that this particular vehicle behaves like a person rather than a craft.
##
## FOUR THINGS, AND EACH ONE IS A WAY IT COULD BE WRONG:
##   it goes where the stick points, forward AND sideways, which `Model::Car` cannot do;
##   it stays on the ground, which `Model::Hover` does not;
##   it stops when the stick is let go, which nothing driven by thrust against drag does;
##   it never pitches or rolls, however it is shoved.
##
## AGAINST A BARE `CockpitWorld` with a floor, the way tests/air.gd weighs a wing: no level, no
## session, no rig. What is under test is the model, and a model is answerable in eight seconds of
## ticks. Whether a PLAYER can drive one is 2b's, and wants the rig's own seams.
##
## Read RESULT=, not the exit code.

## The simulation's own tick, and how long a case runs for.
const TICK: float = 1.0 / 120.0
const SECONDS: float = 3.0
## How fast `ride_segway` walks, and the tolerance a measured speed is held to. Asked of the
## geometry rather than typed, so a number changed in the C++ cannot leave this test asserting the
## old one -- except the walk itself, which the C++ does not publish; see `_walk_speed`.
const WALK: float = 3.2
## A speed this far from the walk is the same speed. Generous on purpose: what is being held is "it
## walks", not a number to three places.
const SPEED_SLACK: float = 0.6
## Where the floor is, and the segway's own half-height, so it starts resting rather than falling.
const FLOOR_TOP: float = 0.0
const SEGWAY_HY: float = 0.35

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[segway] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_the_simulation_knows_what_a_segway_is()
	await _it_walks_where_the_stick_points()
	await _it_stops_when_the_stick_is_let_go()
	await _it_never_leans_and_stays_on_the_ground()
	await _a_pod_given_the_same_drive_does_none_of_that()
	_check("every_section_of_the_suite_ran", _sections == 5, "%d of 5" % _sections)
	_finish()


## ---- 1: the kind and its shape ---------------------------------------------------------------

## THE SHAPE TABLE IS THE AUTHORITY, so this asks it rather than restating it. A sphere at the feet,
## one seat, and light enough that walking into the furniture does not move the furniture.
func _the_simulation_knows_what_a_segway_is() -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.SEGWAY)
	_check("the_simulation_has_a_segway_kind", String(geometry.get("name", "")) == "segway",
		"kind %d is '%s'" % [Sim.Kind.SEGWAY, geometry.get("name", "")])
	_check("and_it_is_its_own_movement_model_rather_than_a_hovering_pod",
		String(geometry.get("model_name", "")) == "segway", "model '%s'" % geometry.get("model_name", ""))
	# A SPHERE, which is what makes it slide along a wall instead of catching on it, and what the
	# user asked for in as many words.
	# `extents`, which is what the shape table publishes -- asking for "hx" got a silent zero and a
	# check that failed for the wrong reason (2026-09-15).
	var box: Vector3 = geometry.get("extents", Vector3.ZERO)
	_check("and_it_is_a_sphere_at_the_feet",
		is_equal_approx(box.x, box.y) and is_equal_approx(box.y, box.z) and box.x > 0.2 and box.x < 0.6,
		"half-extents %s" % [box])
	_check("and_it_has_exactly_one_seat", int(geometry.get("seats", 0)) == 1,
		"%d seat(s)" % int(geometry.get("seats", 0)))
	# A PERSON'S MASS. A 300 kg pod standing in a briefing room shoves the furniture about.
	_check("and_it_weighs_what_a_person_weighs", float(geometry.get("mass", 0.0)) < 150.0,
		"%.0f kg" % float(geometry.get("mass", 0.0)))
	_sections += 1


## ---- 2: it goes where the stick points ---------------------------------------------------------

## FORWARD, BACK AND BOTH WAYS SIDEWAYS, each at a walk.
##
## THE SIDEWAYS CASES ARE THE POINT. A car cannot strafe -- it steers -- so a segway that had been
## given `Model::Car` would pass the forward case and fail these two, which is exactly the mistake
## this is here to catch.
func _it_walks_where_the_stick_points() -> void:
	var cases: Array = [
		{"what": "forward", "controls": {"pitch": -1.0}, "axis": Vector3(0.0, 0.0, -1.0)},
		{"what": "back", "controls": {"pitch": 1.0}, "axis": Vector3(0.0, 0.0, 1.0)},
		{"what": "left", "controls": {"roll": -1.0}, "axis": Vector3(-1.0, 0.0, 0.0)},
		{"what": "right", "controls": {"roll": 1.0}, "axis": Vector3(1.0, 0.0, 0.0)},
	]
	var said: PackedStringArray = []
	var wrong: int = 0
	for case in cases:
		var went: Vector3 = await _walk(case["controls"] as Dictionary)
		var along: float = went.dot(case["axis"] as Vector3)
		var across: float = (went - (case["axis"] as Vector3) * along).length()
		var speed: float = along / SECONDS
		said.append("%s %.2f m along, %.2f m across, %.2f m/s" % [case["what"], along, across, speed])
		# It went the way it was asked, at about a walk, and did not wander.
		if absf(speed - WALK) > SPEED_SLACK or across > 0.5:
			wrong += 1
	_check("it_walks_forward_back_and_both_ways_sideways_at_a_walking_pace", wrong == 0,
		"wanted %.1f m/s each: %s" % [WALK, "; ".join(said)])
	_sections += 1


## ---- 3: it stops ------------------------------------------------------------------------------

## A PERSON DOES NOT COAST, and this is the whole reason the model commands a velocity rather than
## applying a thrust. Walked for three seconds, then let go for three: whatever it does in the
## second half, it must not still be going.
func _it_stops_when_the_stick_is_let_go() -> void:
	var world: Object = _a_floor()
	var pilot: Dictionary = world.spawn_pilot(9001, Sim.Kind.SEGWAY,
		Vector3(0.0, FLOOR_TOP + SEGWAY_HY, 0.0), 0.0, Vector3.ZERO)
	var entity: int = int(pilot.get("pilot", 0))
	for i in range(int(SECONDS / TICK)):
		world.set_pilot_input(entity, _controls({"pitch": -1.0}))
		world.tick(TICK)
	var walking: Vector3 = _speed_of(world, pilot)
	for i in range(int(1.0 / TICK)):
		world.set_pilot_input(entity, _controls())
		world.tick(TICK)
	var stopped: Vector3 = _speed_of(world, pilot)
	world.teardown()
	await get_tree().process_frame
	_check("it_stops_within_a_second_of_the_stick_being_let_go",
		walking.length() > WALK - SPEED_SLACK and stopped.length() < 0.35,
		"%.2f m/s walking, %.2f m/s a second after letting go" % [walking.length(), stopped.length()])
	_sections += 1


## ---- 4: upright, and on the ground -------------------------------------------------------------

## IT NEVER LEANS AND IT NEVER TAKES OFF.
##
## Driven hard in every axis at once for three seconds -- including the pitch and roll a craft would
## fly with -- and then asked how far from upright it is and how high it got. A hovering pod given
## these controls climbs and tumbles; a segway does neither, and that difference is the model.
func _it_never_leans_and_stays_on_the_ground() -> void:
	var world: Object = _a_floor()
	var pilot: Dictionary = world.spawn_pilot(9002, Sim.Kind.SEGWAY,
		Vector3(0.0, FLOOR_TOP + SEGWAY_HY, 0.0), 0.0, Vector3.ZERO)
	var entity: int = int(pilot.get("pilot", 0))
	var highest: float = -1000.0
	var worst_lean: float = 0.0
	for i in range(int(SECONDS / TICK)):
		# Everything at once, throttle included: nothing a stick can say may make it fly.
		world.set_pilot_input(entity, _controls({"pitch": -1.0, "roll": 1.0, "rudder": 1.0,
			"throttle": 1.0}))
		world.tick(TICK)
		var state: Dictionary = world.vehicle_state(int(pilot.get("vehicle", 0)))
		highest = maxf(highest, float((state.get("position", Vector3.ZERO) as Vector3).y))
		worst_lean = maxf(worst_lean, _lean_of(state))
	world.teardown()
	await get_tree().process_frame
	# A tenth of a radian is under six degrees, which is a shove being corrected rather than a lean.
	_check("it_stays_upright_however_it_is_driven", worst_lean < 0.1,
		"worst lean %.3f rad (%.1f degrees)" % [worst_lean, rad_to_deg(worst_lean)])
	# It may ride up a few centimetres over the floor; it may not climb.
	_check("and_it_never_leaves_the_ground_whatever_the_throttle_says",
		highest < FLOOR_TOP + SEGWAY_HY + 0.25,
		"highest %.2f m, started at %.2f" % [highest, FLOOR_TOP + SEGWAY_HY])
	_sections += 1


## ---- 5: and the checks above can tell a segway from a craft ---------------------------------------

## THE SAME DRIVE, THE SAME FLOOR, A POD INSTEAD -- AND EVERY ONE OF THE CLAIMS ABOVE MUST BREAK.
##
## THIS IS THE RED. A suite that only ever watches the thing it is describing passes just as happily
## when the thing does nothing at all, and the usual way to prove otherwise here is to break the code
## and watch it fail. Breaking it means editing C++ and rebuilding twice, and the proof evaporates
## the moment the build is reverted -- so instead the contrast is KEPT, as a section.
##
## A pod is `Model::Hover`: the nearest thing the simulation already had, and what a segway would
## have been given if nobody had written a model for it (`model_of`'s default is Hover). Driven with
## the same stick on the same floor it climbs, or leans, or is still moving after the stick is let
## go. If a future change quietly makes a segway hover, section 4 goes red; if it makes this suite
## toothless, THIS section goes red, because a pod would start behaving like a segway.
func _a_pod_given_the_same_drive_does_none_of_that() -> void:
	var world: Object = _a_floor()
	var pilot: Dictionary = world.spawn_pilot(9003, Sim.Kind.POD,
		Vector3(0.0, FLOOR_TOP + 1.0, 0.0), 0.0, Vector3.ZERO)
	var entity: int = int(pilot.get("pilot", 0))
	var highest: float = -1000.0
	var worst_lean: float = 0.0
	for i in range(int(SECONDS / TICK)):
		world.set_pilot_input(entity, _controls({"pitch": -1.0, "roll": 1.0, "rudder": 1.0,
			"throttle": 1.0}))
		world.tick(TICK)
		var state: Dictionary = world.vehicle_state(int(pilot.get("vehicle", 0)))
		highest = maxf(highest, float((state.get("position", Vector3.ZERO) as Vector3).y))
		worst_lean = maxf(worst_lean, _lean_of(state))
	# And it is still going a second after the stick is let go, which a segway is not.
	for i in range(int(1.0 / TICK)):
		world.set_pilot_input(entity, _controls())
		world.tick(TICK)
	var coasting: float = _speed_of(world, pilot).length()
	world.teardown()
	await get_tree().process_frame
	var climbed: bool = highest > FLOOR_TOP + 1.0 + 0.25
	var leaned: bool = worst_lean > 0.1
	_check("a_pod_on_the_same_floor_with_the_same_stick_flies_or_leans_or_coasts",
		climbed or leaned or coasting > 0.35,
		"climbed to %.2f m (%s), worst lean %.1f degrees (%s), %.2f m/s a second after letting go"
			% [highest, "yes" if climbed else "no", rad_to_deg(worst_lean), "yes" if leaned else "no",
				coasting])
	_sections += 1


## ---- the machinery ------------------------------------------------------------------------------

## A WORLD WITH A FLOOR IN IT AND NOTHING ELSE. The floor is a static box the way tests/air.gd's
## road is, because a segway that cannot feel the ground under it never moves at all.
func _a_floor() -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, FLOOR_TOP - 20.0, 0.0), Vector3(400.0, 20.0, 400.0))
	return world


## HOW FAR A SEGWAY GOES IN `SECONDS` held at `controls`, from a standstill on the floor.
func _walk(controls: Dictionary) -> Vector3:
	var world: Object = _a_floor()
	var pilot: Dictionary = world.spawn_pilot(9000, Sim.Kind.SEGWAY,
		Vector3(0.0, FLOOR_TOP + SEGWAY_HY, 0.0), 0.0, Vector3.ZERO)
	var entity: int = int(pilot.get("pilot", 0))
	var from: Vector3 = _place_of(world, pilot)
	for i in range(int(SECONDS / TICK)):
		world.set_pilot_input(entity, _controls(controls))
		world.tick(TICK)
	var went: Vector3 = _place_of(world, pilot) - from
	world.teardown()
	await get_tree().process_frame
	return went


func _place_of(world: Object, pilot: Dictionary) -> Vector3:
	return (world.vehicle_state(int(pilot.get("vehicle", 0))) as Dictionary).get("position",
		Vector3.ZERO)


func _speed_of(world: Object, pilot: Dictionary) -> Vector3:
	var flat: Vector3 = (world.vehicle_state(int(pilot.get("vehicle", 0))) as Dictionary).get(
		"velocity", Vector3.ZERO)
	flat.y = 0.0
	return flat


## HOW FAR FROM UPRIGHT, in radians: the angle between the body's own up and the world's.
func _lean_of(state: Dictionary) -> float:
	var turn: Quaternion = state.get("basis", Quaternion.IDENTITY)
	var up: Vector3 = (Basis(turn) * Vector3.UP).normalized()
	return acos(clampf(up.dot(Vector3.UP), -1.0, 1.0))


## ONE INPUT FRAME, with everything a pilot could be holding at rest unless it is named.
func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
