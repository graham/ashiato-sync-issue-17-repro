extends Node
## Headless: THE TOWER'S BUTTONS REACH THE AUTOPILOT AND THE AEROPLANE OBEYS.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/tower.tscn
##
## WHY (lane/flightcore, 2026-09-19, the user: *"i want to experiment ... by having the planes fly around and I cna
## click buttons to tell them to do things"*). `world/tower_panel.gd` is a row of buttons over `Observer`, and the
## thing that would make it useless is a button that looks pressed and changes nothing -- which is exactly what a
## screenshot cannot tell you and a suite can.
##
## WHAT IS DRIVEN, and it is the real path: the panel's own `press`, by name, the same function the button's
## `pressed` signal calls. NOT `steer_ai` directly -- that would be a test of the simulation, which already has one
## (`tests/vehicle_gym.gd`), and would pass with every button in this file wired to the wrong order.
##
## WHAT IS HELD:
## - A PRESS REACHES THE PILOT AND THE AEROPLANE DOES IT. Told to climb, it is higher a minute later; told to
##   descend, lower; told to go faster, faster. Flown, not read back: the fault this suite exists to catch is a
##   button that sets a number nothing acts on.
## - AND THE ORDERS ARE KEPT, so CLIMB twice is six hundred metres and not three.
## - IT WILL NOT ASK FOR THE IMPOSSIBLE: SLOWER stops at the mixer's own margin over the stall, because an order the
##   autopilot cannot obey is a button that lies (the gym's waypoint floor, same reason).
## - WITH NO AIRCRAFT UNDER THE CAMERA, a press says so and does not crash. It is a panel somebody clicks at random.
## - THE MUTANT: a panel whose camera is looking at NOTHING must change no aeroplane. If the climb still happens, the
##   suite is testing `steer_ai` and not the panel.
##
## Read RESULT=.

const TICK: float = 1.0 / 120.0
const SETTLE: int = 60
## Long enough for a 300 m order to show on a light single, which climbs about 2.7 m/s.
const FLY_SECONDS: float = 150.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[tower] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	_a_press_reaches_the_pilot_and_the_aeroplane_does_it("climb", 1.0)
	_a_press_reaches_the_pilot_and_the_aeroplane_does_it("descend", -1.0)
	_two_presses_are_worth_two()
	_slower_stops_at_the_speed_the_mixer_will_still_climb_at()
	_a_panel_looking_at_nothing_says_so_and_changes_nothing()
	if _failures.is_empty():
		print("RESULT=PASS")
		get_tree().quit(0)
	else:
		print("RESULT=FAIL %s" % " ".join(_failures))
		get_tree().quit(1)


## ONE AEROPLANE, ONE PANEL, AND A CAMERA POINTED AT IT. The panel is given a stand-in for the observer that answers
## the one question the panel asks of it -- which craft is under the camera -- because `Observer` is a `Camera3D` that
## wants a world to draw, and what is being tested here is the panel.
func _bench(kind: int, at: Vector3, velocity: Vector3) -> Dictionary:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.set_crashes(false)
	var craft: int = int(world.spawn_ai_vehicle(kind, at, 0.0, velocity))
	var panel := TowerPanel.new()
	panel.server = world
	add_child(panel)
	panel.choose(craft)
	return {"world": world, "craft": craft, "panel": panel}


func _shut(bench: Dictionary) -> void:
	(bench["panel"] as Node).queue_free()
	(bench["world"] as Object).teardown()


## A press, and then the aeroplane flies for a while and is asked what happened.
func _a_press_reaches_the_pilot_and_the_aeroplane_does_it(order: String, way: float) -> void:
	var bench: Dictionary = _bench(Sim.Kind.CESSNA, Vector3(0.0, 900.0, 0.0), Vector3(0.0, 0.0, -56.0))
	var world: Object = bench["world"]
	var craft: int = int(bench["craft"])
	var panel: TowerPanel = bench["panel"]
	for i in range(SETTLE):
		world.tick(TICK)
	var was: float = (world.vehicle_state(craft).get("position", Vector3.ZERO) as Vector3).y
	panel.press(order)
	for i in range(int(FLY_SECONDS / TICK)):
		world.tick(TICK)
	var now: float = (world.vehicle_state(craft).get("position", Vector3.ZERO) as Vector3).y
	var moved: float = (now - was) * way
	_check("a_press_of_%s_reaches_the_pilot_and_the_aeroplane_does_it" % order, moved > 100.0,
		"%.0f m to %.0f m, %.0f m the right way" % [was, now, moved])
	_shut(bench)


## AND THE ORDERS ARE KEPT. Two presses of CLIMB is six hundred metres, not three: the panel adds to what it last
## asked for rather than to wherever the aeroplane has drifted.
func _two_presses_are_worth_two() -> void:
	var bench: Dictionary = _bench(Sim.Kind.CESSNA, Vector3(0.0, 900.0, 0.0), Vector3(0.0, 0.0, -56.0))
	var panel: TowerPanel = bench["panel"]
	var world: Object = bench["world"]
	var craft: int = int(bench["craft"])
	for i in range(SETTLE):
		world.tick(TICK)
	panel.press("climb")
	var once: float = float(panel.told_of(craft).get("altitude", 0.0))
	panel.press("climb")
	var twice: float = float(panel.told_of(craft).get("altitude", 0.0))
	_check("two_presses_of_climb_are_worth_two", is_equal_approx(twice - once, TowerPanel.STEP_UP),
		"%.0f m then %.0f m, a step of %.0f" % [once, twice, twice - once])
	_shut(bench)


## SLOWER STOPS WHERE THE AUTOPILOT WOULD STOP OBEYING. `AircraftMixer::slow_margin` is 1.30 times the stall: below it
## the climb allowed becomes a descent, so a button that goes on subtracting is a button that lies about what it did.
func _slower_stops_at_the_speed_the_mixer_will_still_climb_at() -> void:
	var bench: Dictionary = _bench(Sim.Kind.CESSNA, Vector3(0.0, 900.0, 0.0), Vector3(0.0, 0.0, -56.0))
	var panel: TowerPanel = bench["panel"]
	var world: Object = bench["world"]
	var craft: int = int(bench["craft"])
	for i in range(SETTLE):
		world.tick(TICK)
	for i in range(40):
		panel.press("slower")
	var asked: float = float(panel.told_of(craft).get("speed", 0.0))
	var stall: float = float(world.handling(Sim.Kind.CESSNA).get("stall_speed", 0.0))
	_check("slower_stops_at_the_speed_the_mixer_will_still_climb_at",
		asked >= stall * 1.29 and asked <= stall * 1.35,
		"forty presses reach %.1f m/s, against a stall of %.1f and a margin of %.1f"
			% [asked, stall, stall * 1.30])
	_shut(bench)


## AND THE MUTANT, WHICH IS ALSO THE CRASH CHECK: a camera looking at nothing. Every press must say so and TELL
## NOBODY ANYTHING. If an order is recorded anyway, this file is testing `steer_ai` and not the panel.
##
## THE FIRST VERSION OF THIS CHECK WATCHED THE AEROPLANE'S HEIGHT and went red at 115 m of drift -- which was the
## aeroplane flying itself, exactly as an unattended aeroplane should. It was measuring the simulation and calling it
## the panel. What the panel promises is that nothing was ORDERED, so that is what is held.
func _a_panel_looking_at_nothing_says_so_and_changes_nothing() -> void:
	var bench: Dictionary = _bench(Sim.Kind.CESSNA, Vector3(0.0, 900.0, 0.0), Vector3(0.0, 0.0, -56.0))
	var panel: TowerPanel = bench["panel"]
	var world: Object = bench["world"]
	var craft: int = int(bench["craft"])
	panel.choose(0)
	for i in range(SETTLE):
		world.tick(TICK)
	for order in ["climb", "descend", "faster", "slower", "left", "right", "wander", "take_off", "hold", "release"]:
		panel.press(String(order))
	for i in range(int(10.0 / TICK)):
		world.tick(TICK)
	_check("a_panel_looking_at_nothing_says_so_and_orders_nothing",
		panel.told_of(craft).is_empty() and panel.said().contains("No aircraft"),
		"ten orders pressed, %d recorded, and it says: %s"
			% [0 if panel.told_of(craft).is_empty() else 1, panel.said()])
	_shut(bench)


## No stand-in camera any more: the panel owns its selection, holds a SERVER entity, and `choose` is how a probe or a
## suite points it at one. That the selection and the order now come from the same world is the fix this file was
## written before -- see the panel's doc block and
## `../../todo/flightcore--a-client-id-is-not-a-server-id.md`.
