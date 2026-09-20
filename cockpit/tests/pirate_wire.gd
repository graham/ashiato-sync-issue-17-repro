extends Node
## Headless: a pirate ship the server sails is where the server says on a joined machine, and so are its sails.
##
##   Godot --headless --path cockpit res://tests/pirate_wire.tscn
##
## ONLY A JOINED MACHINE QUANTISES (agents.md, "A joined pilot past 16 km ... FIXED"), so a solo or host run proves nothing
## about the wire. This stands a server world and a client world up in one process behind a fake link -- a queue with a
## delivery tick on every packet, four ticks long -- the shape `ashiato-gd/addon/tests/two_clients.gd` uses. The ship is
## the server's: an autopilot holding a course in a wandering wind. The client never simulates it: it receives the hull as
## buffered interpolation and the sails as the `Rigging` component the server publishes after each tick.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
## Ticks each packet spends on the fake link: 67 ms of round trip at 120 Hz.
const DELAY: int = 4
## HOW FAR BEHIND ITS SERVER A WATCHED CRAFT IS DRAWN, in ticks, at most: the link, and a buffer the clock settles at 7 frames
## when asked for 3 (agents.md, "THE BUFFER IS FREE ON THE WIRE"), with a tick to spare.
const DRAWN_BEHIND: int = DELAY + 7 + 1
const WEATHER := {"from": 0.5, "low": 7.0, "high": 11.0, "veer": 0.3, "seed": 21}
## A ship holding a course need not rewrite its sails more than this many times a second; the swell alone would, without
## the steps in `publish_rigging`.
const STEADY_WRITES_A_SECOND: float = 4.0

var _failures: PackedStringArray = []
var _sections: int = 0
const SECTIONS: int = 2
var _tick: int = 0
var _flight: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[pirate_wire] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_a_joined_machine_draws_the_ship_and_its_sails_where_the_server_has_them()
	_finish()


func _finish() -> void:
	_check("every_section_ran_to_its_end", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _pump(s: Object, c: Object) -> void:
	for p in s.take_outbound():
		_flight.append([_tick + DELAY, int(p["peer"]), p["bytes"], p["bits"]])
	for p in c.take_outbound():
		_flight.append([_tick + DELAY, -1, p["bytes"], p["bits"]])
	var keep: Array = []
	for e in _flight:
		if e[0] > _tick:
			keep.append(e)
		elif e[1] < 0:
			s.deliver(1, e[2], e[3])
		else:
			c.deliver(0, e[2], e[3])
	_flight = keep


func _a_joined_machine_draws_the_ship_and_its_sails_where_the_server_has_them() -> void:
	var s: Object = ClassDB.instantiate("CockpitWorld")
	var c: Object = ClassDB.instantiate("CockpitWorld")
	s.set_tick_rate(120.0)
	c.set_tick_rate(120.0)
	s.start(0)
	c.start(1)
	s.set_weather(WEATHER)
	c.set_weather(WEATHER)
	var heading: float = 0.5 - deg_to_rad(95.0)
	var nose := Vector3(sin(heading), 0.0, -cos(heading))
	var ship: int = int(s.spawn_ai_vehicle(Sim.Kind.PIRATE, Vector3(1200.0, 0.0, -900.0), -heading, nose * 3.0))
	s.hold_course(ship, heading)
	var worst_apart: float = 0.0
	var fastest: float = 0.0
	var samples: int = 0
	var rigging_seen: int = 0
	var lever_off: float = 0.0
	var fill_off: float = 0.0
	# THE SAILS ARRIVED FULL, not only equal: two sets of zeros agree too, and a ship whose rigging never reached the client
	# would read zeros on both sides of a comparison made against a slack server.
	var fullest_drawn: float = 0.0
	var least_set_drawn: float = INF
	var writes_at_settle: int = 0
	for i in range(int(90.0 / TICK)):
		_tick += 1
		s.tick(TICK)
		c.tick(TICK)
		_pump(s, c)
		if i == int(30.0 / TICK):
			writes_at_settle = int(s.rigging_writes())
		if i < int(30.0 / TICK) or i % 30 != 0:
			continue
		var theirs: int = _the_ship_on(c)
		if theirs == 0:
			continue
		var truth: Dictionary = s.vehicle_state(ship)
		var drawn: Dictionary = c.vehicle_state(theirs)
		var speed: float = (truth["velocity"] as Vector3).length()
		fastest = maxf(fastest, speed)
		worst_apart = maxf(worst_apart, ((truth["position"] as Vector3) - (drawn["position"] as Vector3)).length())
		samples += 1
		var sails: Dictionary = s.sail_report(ship)
		var rigging: Dictionary = c.vehicle_rigging(theirs)
		if rigging.is_empty():
			continue
		rigging_seen += 1
		least_set_drawn = minf(least_set_drawn, float(rigging["set"]))
		for drawn_fill in rigging["fill"] as Array:
			fullest_drawn = maxf(fullest_drawn, float(drawn_fill))
		lever_off = maxf(lever_off, maxf(absf(float(rigging["fore"]) - float(sails["fore"])),
			absf(float(rigging["main"]) - float(sails["main"]))))
		for g in range(4):
			fill_off = maxf(fill_off, absf(float((rigging["fill"] as Array)[g]) - absf(float((sails["fill"] as Array)[g]))))
	# The allowance is the ship's own travel over the ticks it is drawn behind, twice over for the swell's heave and
	# pitch, and a metre: from the numbers, not a guess.
	var allowed: float = fastest * float(DRAWN_BEHIND) * TICK * 2.0 + 1.0
	_check("the_joined_machine_draws_the_pirate_ship_where_the_server_sails_it",
		samples > 100 and worst_apart <= allowed,
		"worst %.2f m apart over %d samples, allowed %.2f m at %.1f m/s" % [worst_apart, samples, allowed, fastest])
	_check("and_nothing_about_it_was_clamped_on_the_wire", int(s.wire_clamps()) == 0, "%d clamps" % s.wire_clamps())
	_sections += 1
	# THE SAILS ARRIVE: the levers and each group's fill as the server trims them, to within the publishing steps (a
	# lever 2 of 127, a fill 6 of 255) and a quarter-second of trim moving on while the record crosses the link.
	var writes_a_second: float = float(int(s.rigging_writes()) - writes_at_settle) / 60.0
	_check("its_sails_arrive_as_the_server_trims_them",
		rigging_seen > 100 and lever_off <= 0.05 and fill_off <= 0.08 and least_set_drawn > 0.9 and fullest_drawn > 0.33,
		"%d samples with rigging; worst lever %.3f and fill %.3f off the server's; the client drew sail set %.2f at least and a group %.2f full" % [
			rigging_seen, lever_off, fill_off, least_set_drawn, fullest_drawn])
	_check("and_a_ship_holding_its_course_sends_its_sails_only_now_and_then",
		writes_a_second > 0.0 and writes_a_second <= STEADY_WRITES_A_SECOND,
		"%.2f rigging writes a second over the last minute, against 120 ticks" % writes_a_second)
	_sections += 1
	s.teardown()
	c.teardown()


static func _the_ship_on(world: Object) -> int:
	for vehicle in world.vehicle_states():
		if int((vehicle as Dictionary)["kind"]) == Sim.Kind.PIRATE:
			return int(vehicle["entity"])
	return 0
