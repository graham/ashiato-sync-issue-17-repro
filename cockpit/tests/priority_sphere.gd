extends Node
## Headless: THE HOST SENDS EACH MACHINE WHAT IS NEAR IT MORE OFTEN THAN WHAT IS FAR AWAY.
##
##   Godot --headless --xr-mode off --path cockpit res://tests/priority_sphere.tscn
##
## THE RULE. `CockpitWorld::set_priority_sphere` gives every replicated thing within a radius of a CLIENT'S OWN CRAFT
## the inside priority and everything else the outside one; sync's scheduler then chooses an entity with priority k
## about k times as often as one with priority 1 whenever a client's per-tick budget cannot carry everything that
## changed (see agents.md, "THE PRIORITY SPHERE"). Priority is a RATE and never a filter: nothing but a cabin is ever
## zero, because zero or less is sync's way of withholding (NaN before 8fa08cf) and a withheld craft freezes on the
## client for good.
##
## WHAT IS REAL HERE. A server and three client CockpitWorlds joined over an exact tick-queue pump, pilots made with
## the real `spawn_pilot`, a crew seat taken with the real `seat_client`, and a cabin found on the server's own sync
## trace. `priority_of(client, entity)` is the very function the prioritizer calls, asked directly as well as
## through its effect.
##
## WHAT IT HOLDS, each checked, not printed:
##   * a craft 9.9 km from a client gets the inside priority and one 10.1 km away the outside;
##   * the same craft gets different answers for two clients in different places;
##   * a client with no craft gets the outside priority for everything;
##   * a pilot takes the answer of the craft it sits in, and a copilot's pilot is inside for the pilot;
##   * a cabin still goes to its owner at the largest float and to everybody else as zero, which sync filters (NaN
##     until ashiato-sync 8fa08cf, where NaN began to throw in an assert build);
##   * no craft or pilot is ever NaN, for any client;
##   * a linear falloff is the outside priority at the edge and the inside at the centre;
##   * a changed radius changes the answer at once, and a bad value is refused and changes nothing;
##   * switched off, everything but a cabin is 1.0, which is the prioritizer as it was;
##   * the game's numbers are Sim.PRIORITY_*, and the command line changes them;
##   AND WHAT IT DOES, on a STARVED server -- a per-client budget cut until only a few of 62 moving craft fit a tick:
##   * 30 craft inside the game's radius are sent more often than 30 outside it, by the ratio sync's own accumulator
##     arithmetic predicts for the sends this run actually made, tick by tick, whole ticks and all;
##   * with the sphere OFF the two groups are sent alike, which is the control that stops the above passing for the
##     wrong reason;
##   * `Sim.set_priority_sphere` changes it live: inside 4 -> 1 flattens the ratio within the run;
##   * `--priority-inside=1` on a command line flattens it too, in a child process started through the real parser.
##
## COUNTED ON THE CLIENT, NOT THE SERVER. sync's `component_sent` trace event is written while an entity is SERIALISED
## (server.cpp, `serialize_entity`), and the scheduler serialises every dirty candidate every tick before it asks whether
## the record fits the budget. Measured at 67 B a tick over 61 moving planes: 62 `component_sent` a tick on the server,
## 50 bytes a tick on the wire, and about one `component_received` a tick on the client. So a craft counts as sent here
## when the CLIENT's own trace says a VehicleState record for it arrived. (That was sync up to 90f50bf. Since 8fa08cf
## `component_sent` waits until the record is in a packet; a packet can still be lost, so arrival is still the count.)
##
## WHY THE PREDICTION IS REPLAYED AND NOT k. With every entry dirty an entity of priority p is chosen every A/p ticks,
## A = (k * N_inside + N_outside) / updates that fit a tick, so the continuous answer is exactly k. But a send happens
## on a whole tick, an accumulator only holds whole multiples of p, and the budget fits a varying number of records a
## tick: at 31 inside, 30 outside and k = 4, 20 updates a tick gives 3.33 and 22 gives 2.58. So the suite records how
## many craft the server really sent each tick and replays sync's accumulator over exactly that sequence -- add, stable
## sort, send the top M, zero -- and holds the measured ratio to that replay. Both numbers are printed.
##
## THE GEOMETRY. The client flies at twice the radius from the world origin; the inside group is 0.2 to 0.8 of the
## radius from it, and the outside group is within 0.3 of the radius of the ORIGIN. So a sphere mistakenly centred on the
## origin swaps the two groups over and the ratio falls below 1, rather than merely blurring.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 120.0
const TICK_HZ: float = 120.0
const PLANE: int = 1
const LINK: int = 1
const FLAT: int = 0
const LINEAR: int = 1
## The rule's own numbers, chosen here to be told apart from each other and from the game's defaults, which are
## `Sim.PRIORITY_*` and checked separately: a test of the rule that passed only at the default would not say which.
const RADIUS: float = 10000.0
const INSIDE: float = 4.0
const OUTSIDE: float = 1.0
## Where the two flying clients are. Inside the wire's +/-32.768 km, and far enough apart that no craft is near both.
const A_AT := Vector3(15000.0, 1500.0, 0.0)
const B_AT := Vector3(-15000.0, 1500.0, 0.0)
## Everybody flies the same way at the same speed, so the distances the checks are about hold while they are asked.
const HEADING := Vector3(0.0, 0.0, -60.0)
## THE STARVED SERVER. Two groups of craft, how long to let the accumulators settle, how long to count, and roughly how
## many updates a tick the budget is cut to carry: fewer than half of the 62 dirty entities, deep enough that each group
## goes several ticks between sends. The budget is found from one calibration run rather than typed as bytes.
const GROUP: int = 30
const SETTLE_TICKS: int = 240
const MEASURE_TICKS: int = 1200
const UPDATES_A_TICK: float = 9.0
const CALIBRATION_BUDGET: int = 30000
## How far the measured ratio may sit from the replay of sync's arithmetic, and how far apart the two groups may be with
## the sphere off. Measured 2026-09-17 at 33,750 B/s and 9 updates a tick: 3.749 against a replay of 3.753 on, 1.005 off,
## 1.005 after a live change and 1.005 in a child given --priority-inside=1.
const REPLAY_TOLERANCE: float = 0.03
const FLAT_TOLERANCE: float = 0.05
## Past this the effect's geometry does not fit the wire's +/-32.768 km, and the suite says so rather than blurring.
const LARGEST_TESTABLE_RADIUS: float = 14000.0
## How far a craft may have drifted from where it was put, before a check that relies on the distance says so.
const DRIFT_M: float = 50.0

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _clients: Array = []
var _tick: int = 0
## [[due_tick, to_peer (0 is the server), from_peer, bytes, bits], ...]
var _in_flight: Array = []
## client -> the cabin entity the server's trace says it sent that client. See `_run`.
var _cabins: Dictionary = {}
## WHAT ONE CLIENT RECEIVED, while `_recording`: its own entity -> ticks a VehicleState arrived on, and how many
## entities arrived each tick. Read off the client's trace; see "COUNTED ON THE CLIENT" above.
var _recording: bool = false
var _sent_count: Dictionary = {}
var _sent_each_tick: PackedInt32Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[priority_sphere] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("cockpit_world_is_registered", false, "the ashiato extension did not load")
		_finish()
		return
	var probe: RefCounted = ClassDB.instantiate("CockpitWorld")
	for method in ["set_priority_sphere", "priority_sphere", "priority_of"]:
		_check("the_world_has_%s" % method, probe.has_method(method), "bound on CockpitWorld")
	if not _failures.is_empty():
		_finish()
		return
	# THE CHILD: one starved run with whatever this process's own command line gave Sim, and a line for the parent.
	if OS.get_cmdline_user_args().has("--effect-only"):
		var budget: int = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--budget="):
				budget = int(argument.get_slice("=", 1))
		var child: Dictionary = _starve(Sim.priority_sphere, budget)
		print("SPHERE_EFFECT ratio=%.3f inside=%.3f replay=%.3f" % [child["ratio"], float(Sim.priority_sphere["inside"]),
			child["replay_ratio"]])
		_finish()
		return
	_rules()
	_tunables()
	_effect()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## ---- the rule, asked directly --------------------------------------------------------------------------------------

func _rules() -> void:
	_stand_up(3)
	var a: int = int(_clients[0].local_client_id())
	var b: int = int(_clients[1].local_client_id())
	var nobody: int = int(_clients[2].local_client_id())
	_check("three_clients_joined", a > 0 and b > 0 and nobody > 0, "clients %d, %d, %d" % [a, b, nobody])
	var flying_a: Dictionary = _server.spawn_pilot(a, PLANE, A_AT, 0.0, HEADING)
	var flying_b: Dictionary = _server.spawn_pilot(b, PLANE, B_AT, 0.0, HEADING)
	var near: int = _server.spawn_vehicle(PLANE, A_AT + Vector3(9900.0, 0.0, 0.0), 0.0, HEADING)
	var beyond: int = _server.spawn_vehicle(PLANE, A_AT + Vector3(-10100.0, 0.0, 0.0), 0.0, HEADING)
	var half: int = _server.spawn_vehicle(PLANE, A_AT + Vector3(0.0, 0.0, 5000.0), 0.0, HEADING)
	_run(4)

	# OFF, which is how every CockpitWorld starts: the prioritizer as it was before the sphere existed.
	var off: Dictionary = _server.priority_sphere()
	_check("a_new_world_starts_with_the_sphere_off", not bool(off.get("enabled", true)), str(off))
	_check("off_a_near_craft_is_one", is_equal_approx(_server.priority_of(a, near), 1.0),
		"%.3f" % _server.priority_of(a, near))

	_check("the_sphere_is_accepted", _server.set_priority_sphere(true, RADIUS, INSIDE, OUTSIDE, FLAT),
		str(_server.priority_sphere()))
	var at_a: Vector3 = _position(int(flying_a["vehicle"]))
	var d_near: float = _position(near).distance_to(at_a)
	var d_beyond: float = _position(beyond).distance_to(at_a)
	_check("the_craft_are_where_they_were_put", absf(d_near - 9900.0) < DRIFT_M and absf(d_beyond - 10100.0) < DRIFT_M,
		"%.0f m and %.0f m from A" % [d_near, d_beyond])
	_check("a_craft_9_9_km_away_is_inside", is_equal_approx(_server.priority_of(a, near), INSIDE),
		"%.3f at %.0f m" % [_server.priority_of(a, near), d_near])
	_check("a_craft_10_1_km_away_is_outside", is_equal_approx(_server.priority_of(a, beyond), OUTSIDE),
		"%.3f at %.0f m" % [_server.priority_of(a, beyond), d_beyond])
	_check("the_same_craft_is_far_from_somebody_else", is_equal_approx(_server.priority_of(b, near), OUTSIDE),
		"A %.3f, B %.3f" % [_server.priority_of(a, near), _server.priority_of(b, near)])
	_check("each_client_is_inside_its_own_sphere",
		is_equal_approx(_server.priority_of(a, int(flying_a["vehicle"])), INSIDE)
			and is_equal_approx(_server.priority_of(b, int(flying_b["vehicle"])), INSIDE),
		"A's craft to A %.3f, B's craft to B %.3f" % [_server.priority_of(a, int(flying_a["vehicle"])),
			_server.priority_of(b, int(flying_b["vehicle"]))])
	_check("a_client_with_no_craft_gets_the_outside_priority",
		is_equal_approx(_server.priority_of(nobody, near), OUTSIDE)
			and is_equal_approx(_server.priority_of(nobody, int(flying_a["vehicle"])), OUTSIDE),
		"%.3f and %.3f" % [_server.priority_of(nobody, near), _server.priority_of(nobody, int(flying_a["vehicle"]))])
	_check("a_pilot_is_where_its_craft_is",
		is_equal_approx(_server.priority_of(a, int(flying_a["pilot"])), INSIDE)
			and is_equal_approx(_server.priority_of(a, int(flying_b["pilot"])), OUTSIDE),
		"A's pilot to A %.3f, B's pilot to A %.3f" % [_server.priority_of(a, int(flying_a["pilot"])),
			_server.priority_of(a, int(flying_b["pilot"]))])

	# LINEAR: the outside priority at the edge, the inside at the centre, and halfway between at half the radius.
	_server.set_priority_sphere(true, RADIUS, INSIDE, OUTSIDE, LINEAR)
	var d_half: float = _position(half).distance_to(at_a)
	var expected_half: float = OUTSIDE + (INSIDE - OUTSIDE) * (1.0 - d_half / RADIUS)
	_check("linear_falls_off_towards_the_edge", absf(_server.priority_of(a, half) - expected_half) < 0.02,
		"%.3f at %.0f m, expected %.3f" % [_server.priority_of(a, half), d_half, expected_half])
	_check("linear_is_near_outside_just_inside_the_edge", _server.priority_of(a, near) < OUTSIDE + 0.1,
		"%.3f at %.0f m" % [_server.priority_of(a, near), d_near])

	# A SMALLER RADIUS, at once: the next refresh asks this same function.
	_server.set_priority_sphere(true, 3000.0, INSIDE, OUTSIDE, FLAT)
	_check("a_smaller_radius_puts_a_5_km_craft_outside", is_equal_approx(_server.priority_of(a, half), OUTSIDE),
		"%.3f at %.0f m" % [_server.priority_of(a, half), d_half])
	_server.set_priority_sphere(true, RADIUS, INSIDE, OUTSIDE, FLAT)
	_check("and_the_radius_back_puts_it_inside", is_equal_approx(_server.priority_of(a, half), INSIDE),
		"%.3f" % _server.priority_of(a, half))

	# REFUSED, AND NOTHING CHANGES. Zero and below withhold outright since ashiato-sync 8fa08cf, and never accumulated
	# before it: a freeze either way.
	var before: Dictionary = _server.priority_sphere()
	var refusals: Array = [
		["zero_inside", [true, RADIUS, 0.0, OUTSIDE, FLAT]],
		["negative_outside", [true, RADIUS, INSIDE, -1.0, FLAT]],
		["nan_inside", [true, RADIUS, NAN, OUTSIDE, FLAT]],
		["infinite_radius", [true, INF, INSIDE, OUTSIDE, FLAT]],
		["negative_radius", [true, -1.0, INSIDE, OUTSIDE, FLAT]],
		["unknown_falloff", [true, RADIUS, INSIDE, OUTSIDE, 7]],
		["a_priority_past_the_ceiling", [true, RADIUS, 1.0e9, OUTSIDE, FLAT]],
	]
	for refusal in refusals:
		var args: Array = refusal[1]
		var accepted: bool = _server.callv("set_priority_sphere", args)
		_check("refuses_%s" % refusal[0], not accepted and _server.priority_sphere() == before,
			"accepted %s, now %s" % [accepted, str(_server.priority_sphere())])

	# A CREW: B boards A's craft as copilot. B's centre is now A's craft, and B is given a cabin.
	_check("b_takes_the_copilot_seat", _server.seat_client(b, int(flying_a["vehicle"]), 1), "seat_client")
	_run(30)
	var cabins: Dictionary = _cabins
	_check("the_server_sent_both_crew_their_cabins", cabins.has(a) and cabins.has(b), str(cabins))
	if cabins.has(a) and cabins.has(b):
		var mine: int = int(cabins[b])
		_check("a_cabin_goes_to_its_owner_first", _server.priority_of(b, mine) > 1.0e30,
			"above 1e30: %s" % (_server.priority_of(b, mine) > 1.0e30))
		_check("and_to_nobody_else", _server.priority_of(a, mine) == 0.0 and _server.priority_of(nobody, mine) == 0.0,
			"to A %s, to nobody %s" % [_server.priority_of(a, mine), _server.priority_of(nobody, mine)])
	_check("a_copilot_sees_the_craft_it_sits_in_as_inside", is_equal_approx(_server.priority_of(b, near), INSIDE),
		"%.3f" % _server.priority_of(b, near))

	# NEVER NaN for anything that is not a cabin, for any client, on or off.
	var things: Array = []
	for vehicle in _server.vehicle_states():
		things.append(int((vehicle as Dictionary)["entity"]))
	for pilot in _server.pilot_states():
		things.append(int((pilot as Dictionary)["entity"]))
	var nans: int = 0
	var asked: int = 0
	for enabled in [true, false]:
		_server.set_priority_sphere(enabled, RADIUS, INSIDE, OUTSIDE, FLAT)
		for client in [a, b, nobody]:
			for entity in things:
				asked += 1
				var priority: float = _server.priority_of(client, entity)
				if is_nan(priority) or priority <= 0.0:
					nans += 1
	_check("no_craft_or_pilot_is_ever_withheld", nans == 0 and things.size() >= 5,
		"%d of %d answers NaN or not above zero, %d things" % [nans, asked, things.size()])
	_tear_down()


## ---- the game's numbers ----------------------------------------------------------------------------------------------

func _tunables() -> void:
	var plain: Dictionary = Sim.priority_sphere_asked(PackedStringArray())
	_check("the_game_asks_for_its_constants", plain == {"enabled": Sim.PRIORITY_SPHERE_ON,
		"radius_m": Sim.PRIORITY_RADIUS_M, "inside": Sim.PRIORITY_INSIDE, "outside": Sim.PRIORITY_OUTSIDE,
		"falloff": Sim.PRIORITY_FALLOFF}, str(plain))
	_check("the_game_starts_with_the_sphere_on_at_10_km", Sim.PRIORITY_SPHERE_ON and Sim.PRIORITY_RADIUS_M == 10000.0,
		"on %s, radius %.0f m" % [Sim.PRIORITY_SPHERE_ON, Sim.PRIORITY_RADIUS_M])
	var flagged: Dictionary = Sim.priority_sphere_asked(PackedStringArray(["--priority-radius=5000",
		"--priority-inside=8", "--priority-outside=0.5", "--priority-falloff=linear", "--priority-off"]))
	_check("the_command_line_changes_every_number", flagged == {"enabled": false, "radius_m": 5000.0, "inside": 8.0,
		"outside": 0.5, "falloff": Sim.Falloff.LINEAR}, str(flagged))
	var typo: Dictionary = Sim.priority_sphere_asked(PackedStringArray(["--priority-radius=ten", "--priority-inside=0"]))
	_check("a_bad_value_on_the_command_line_leaves_the_constant",
		float(typo["radius_m"]) == Sim.PRIORITY_RADIUS_M and float(typo["inside"]) == Sim.PRIORITY_INSIDE, str(typo))
	var world: RefCounted = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(TICK_HZ)
	world.start(0)
	_check("the_game_constants_are_a_setting_the_world_accepts", world.set_priority_sphere(Sim.PRIORITY_SPHERE_ON,
		Sim.PRIORITY_RADIUS_M, Sim.PRIORITY_INSIDE, Sim.PRIORITY_OUTSIDE, Sim.PRIORITY_FALLOFF), str(world.priority_sphere()))
	world.teardown()


## ---- what it does to the wire -----------------------------------------------------------------------------------------

func _effect() -> void:
	var game: Dictionary = Sim.priority_sphere
	var radius: float = float(game["radius_m"])
	_check("the_game_radius_fits_this_geometry", radius > 0.0 and radius <= LARGEST_TESTABLE_RADIUS,
		"%.0f m; past %.0f m the groups would leave the wire's range" % [radius, LARGEST_TESTABLE_RADIUS])
	if radius <= 0.0 or radius > LARGEST_TESTABLE_RADIUS:
		return
	var off: Dictionary = game.duplicate()
	off["enabled"] = false

	# THE BUDGET, from one run: how many updates a tick CALIBRATION_BUDGET carried, scaled to UPDATES_A_TICK.
	var calibration: Dictionary = _starve(off, CALIBRATION_BUDGET)
	var budget: int = maxi(8000, int(round(float(CALIBRATION_BUDGET) * UPDATES_A_TICK / maxf(calibration["updates_a_tick"], 0.5))))
	print("[priority_sphere] budget %d B/s (%.0f B a tick): %d B/s carried %.2f updates a tick" % [budget,
		float(budget) / TICK_HZ, CALIBRATION_BUDGET, calibration["updates_a_tick"]])

	var control: Dictionary = _starve(off, budget)
	var on: Dictionary = _starve(game, budget)
	var dirty: int = 2 * GROUP + 1
	_check("the_server_is_starved", float(on["updates_a_tick"]) <= 0.5 * dirty and float(control["updates_a_tick"]) <= 0.5 * dirty,
		"%.2f updates a tick on, %.2f off, of %d moving craft" % [on["updates_a_tick"], control["updates_a_tick"], dirty])
	_check("off_both_groups_are_sent_alike", absf(float(control["ratio"]) - 1.0) <= FLAT_TOLERANCE,
		"inside %.2f Hz, outside %.2f Hz, ratio %.3f" % [control["inside_hz"], control["outside_hz"], control["ratio"]])
	_check("on_craft_inside_the_sphere_are_sent_more_often", float(on["ratio"]) >= 2.0,
		"inside %.2f Hz, outside %.2f Hz, ratio %.3f; continuous arithmetic %.1f" % [on["inside_hz"], on["outside_hz"],
			on["ratio"], float(game["inside"]) / float(game["outside"])])
	_check("on_the_ratio_is_what_the_accumulator_arithmetic_predicts",
		absf(float(on["ratio"]) / maxf(float(on["replay_ratio"]), 0.001) - 1.0) <= REPLAY_TOLERANCE,
		"measured %.3f, replayed %.3f (inside %.2f Hz, outside %.2f Hz), continuous %.1f" % [on["ratio"], on["replay_ratio"],
			on["replay_inside_hz"], on["replay_outside_hz"], float(game["inside"]) / float(game["outside"])])
	_check("off_the_replay_agrees_too", absf(float(control["replay_ratio"]) - 1.0) <= FLAT_TOLERANCE,
		"replayed %.3f" % control["replay_ratio"])

	# LIVE: inside 4 for the first half, `Sim.set_priority_sphere` to 1 through the game's own call, and the second half.
	var flattened: Dictionary = game.duplicate()
	flattened["inside"] = flattened["outside"]
	var live: Dictionary = _starve(game, budget, flattened)
	_check("live_before_the_change_inside_is_sent_more_often", float(live["ratio"]) >= 2.0,
		"ratio %.3f" % live["ratio"])
	_check("live_sim_set_priority_sphere_is_accepted", String(live["said"]) == "", "said '%s'" % live["said"])
	_check("live_after_the_change_both_groups_are_sent_alike", absf(float(live["after_ratio"]) - 1.0) <= FLAT_TOLERANCE * 1.5,
		"ratio %.3f after setting inside to %.1f" % [live["after_ratio"], flattened["inside"]])

	# THE COMMAND LINE, through the real parser in a process of its own.
	var output: Array = []
	var project: String = ProjectSettings.globalize_path("res://")
	OS.execute(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--path", project,
		"res://tests/priority_sphere.tscn", "--", "--effect-only", "--budget=%d" % budget, "--priority-inside=1"], output, true)
	var said: String = "\n".join(output)
	var ratio: float = -1.0
	var child_inside: float = -1.0
	for line in said.split("\n"):
		if line.begins_with("SPHERE_EFFECT "):
			ratio = float(line.get_slice("ratio=", 1).get_slice(" ", 0))
			child_inside = float(line.get_slice("inside=", 1).get_slice(" ", 0))
	_check("the_command_line_reaches_the_host", child_inside == 1.0, "the child's Sim asked for inside %.1f" % child_inside)
	_check("and_flattens_the_ratio", ratio > 0.0 and absf(ratio - 1.0) <= FLAT_TOLERANCE,
		"child ratio %.3f with --priority-inside=1" % ratio)


## ONE STARVED SESSION: a server with `budget` bytes a second for its one client, the client's craft at twice the radius
## from the origin, GROUP craft inside the sphere and GROUP near the origin, all flying. `sphere` is set before the
## settle; if `then` is given, the first half of the count is taken, `then` goes in through `Sim.set_priority_sphere`,
## and the second half is counted separately. Returns rates and the replay of sync's arithmetic.
func _starve(sphere: Dictionary, budget: int, then: Dictionary = {}) -> Dictionary:
	var radius: float = float(sphere["radius_m"])
	var centre := Vector3(2.0 * radius, 1500.0, 0.0)
	_server = ClassDB.instantiate("CockpitWorld")
	_server.set_tick_rate(TICK_HZ)
	_server.set_tracing(true)
	if budget > 0:
		_server.set_send_budget(budget)
	# BEFORE start, as a session that starts with it would have it: then the only change made while the server runs is
	# the live one below, and a setter that ignored a running server would redden only the live checks.
	_server.set_priority_sphere(bool(sphere["enabled"]), radius, float(sphere["inside"]), float(sphere["outside"]),
		int(sphere["falloff"]))
	_server.start(0)
	_clients.clear()
	_in_flight.clear()
	_cabins.clear()
	_tick = 0
	var world: RefCounted = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(TICK_HZ)
	world.set_tracing(true)
	world.start(2)
	_clients.append(world)
	_run(int(1.5 * TICK_HZ))
	var client: int = int(world.local_client_id())
	var mine: Dictionary = _server.spawn_pilot(client, PLANE, centre, 0.0, HEADING)
	var inside: Array[int] = []
	var outside: Array[int] = []
	# Interleaved, so neither group owns the low slots sync breaks its ties with.
	for i in range(GROUP):
		var turn: float = float(i) * 2.39996
		var near_r: float = radius * (0.2 + 0.6 * float(i) / float(GROUP - 1))
		var far_r: float = radius * (0.05 + 0.25 * float(i) / float(GROUP - 1))
		var lift: float = 150.0 * float(i % 5)
		inside.append(_server.spawn_vehicle(PLANE, centre + Vector3(cos(turn) * near_r, lift, sin(turn) * near_r), 0.0, HEADING))
		outside.append(_server.spawn_vehicle(PLANE, Vector3(cos(turn) * far_r, 1500.0 + lift, sin(turn) * far_r), 0.0, HEADING))
	_run(SETTLE_TICKS)
	var halves: Array[Dictionary] = []
	var said: String = ""
	var windows: Array = [MEASURE_TICKS] if then.is_empty() else [MEASURE_TICKS / 2, MEASURE_TICKS / 2]
	for w in range(windows.size()):
		if w == 1:
			Sim.server = _server
			said = Sim.set_priority_sphere(bool(then["enabled"]), float(then["radius_m"]), float(then["inside"]),
				float(then["outside"]), int(then["falloff"]))
			Sim.server = null
			# The refresh bucket (4 ticks) and the accumulators the old setting left behind.
			_run(SETTLE_TICKS / 2)
		# WHAT THE SETTING SAYS EACH GROUP SHOULD GET, from the Dictionary this run was configured with and never from
		# `priority_of`, which is the code under test: read back from it, a sphere that ignored its inside priority replayed
		# 1.006 against 1.005 measured and the replay check passed (2026-09-17). The groups were placed by distance, so
		# with the sphere on the inside group and the client's own craft are `inside` and the outside group is `outside`
		# (flat; a linear falloff would need each craft's distance, and this geometry does not use one).
		var setting: Dictionary = sphere if w == 0 else then
		var on: bool = bool(setting["enabled"])
		var inside_priority: float = float(setting["inside"]) if on else 1.0
		var outside_priority: float = float(setting["outside"]) if on else 1.0
		var own_priority: float = inside_priority
		_sent_count.clear()
		_sent_each_tick.clear()
		_recording = true
		_run(int(windows[w]))
		_recording = false
		halves.append(_rates(world, centre, radius, {"inside": inside, "outside": outside,
			"own": int(mine.get("vehicle", 0)), "given": [inside_priority, outside_priority, own_priority]}, int(windows[w])))
	_tear_down()
	var out: Dictionary = halves[0]
	out["said"] = said
	if halves.size() == 2:
		out["after_ratio"] = halves[1]["ratio"]
	print("[priority_sphere] starved at %d B/s, sphere %s x%.1f: %.2f updates a tick, inside %.2f Hz, outside %.2f Hz, ratio %.3f, replay %.3f%s" % [
		budget, "on" if bool(sphere["enabled"]) else "off", float(sphere["inside"]) / float(sphere["outside"]),
		out["updates_a_tick"], out["inside_hz"], out["outside_hz"], out["ratio"], out["replay_ratio"],
		("; after the change, ratio %.3f" % out["after_ratio"]) if out.has("after_ratio") else ""])
	return out


## Rates over one counted window, and SYNC'S ACCUMULATOR REPLAYED over the very number of entities received each tick.
##
## The client's craft are sorted into the groups by where the CLIENT draws them: within the radius of `centre` is the
## inside group, within half the radius of the origin the outside one, and the client's own predicted craft is its own.
##
## THE REPLAY RUNS IN THE SERVER'S ORDER. sync's sort is stable over its dirty queue, which is in slot order, and slots are
## handed out as the server creates entities: the pilot's craft, then inside and outside in turn. Replayed in the CLIENT's
## entity order instead -- the order records happened to arrive in -- the same run predicted 3.975 against 3.749
## measured, because at k = 4 whole accumulators tie often and the tie decides who waits a tick. In server order it is
## within about a per cent. `server` is {inside, outside, own, given: [inside, outside, own priority]}, where the
## priorities are the CONFIGURED ones, never read back from the world: the replay's only inputs are the run's per-tick
## receipt counts and the setting, so a world that misapplies the setting cannot make the replay agree with it.
func _rates(world: RefCounted, centre: Vector3, radius: float, server: Dictionary, ticks: int) -> Dictionary:
	var inside: Array[int] = []
	var outside: Array[int] = []
	for vehicle in world.vehicle_states():
		var entity: int = int((vehicle as Dictionary)["entity"])
		var at: Vector3 = (vehicle as Dictionary)["position"]
		if bool((vehicle as Dictionary).get("predicted", false)):
			continue
		elif at.distance_to(centre) < radius:
			inside.append(entity)
		elif at.length() < radius * 0.5:
			outside.append(entity)
	var priorities: Dictionary = {int(server["own"]): float(server["given"][2])}
	for entity in server["inside"]:
		priorities[int(entity)] = float(server["given"][0])
	for entity in server["outside"]:
		priorities[int(entity)] = float(server["given"][1])
	if inside.size() != GROUP or outside.size() != GROUP:
		_check("the_client_draws_both_groups_where_they_were_put", false,
			"%d inside and %d outside of %d each" % [inside.size(), outside.size(), GROUP])
		return {"updates_a_tick": 0.0, "inside_hz": 0.0, "outside_hz": 0.0, "ratio": 0.0, "replay_inside_hz": 0.0,
			"replay_outside_hz": 0.0, "replay_ratio": 0.0}
	var seconds: float = float(ticks) / TICK_HZ
	var group_hz := func(group: Array[int], counts: Dictionary) -> float:
		var total: int = 0
		for entity in group:
			total += int(counts.get(entity, 0))
		return float(total) / float(group.size()) / seconds
	var inside_hz: float = group_hz.call(inside, _sent_count)
	var outside_hz: float = group_hz.call(outside, _sent_count)
	var sent: int = 0
	for n in _sent_each_tick:
		sent += n
	# The replay: every entity this window's priorities name, in the server's entity order (see above), accumulating every tick and zeroed when sent, the top M sent each tick where M is
	# what the server really sent that tick. Run twice over the sequence and counted on the second, so it starts settled.
	var order: Array = priorities.keys()
	order.sort()
	var accumulated: Dictionary = {}
	var replayed: Dictionary = {}
	for entity in order:
		accumulated[entity] = 0.0
		replayed[entity] = 0
	for pass_number in range(2):
		for m in _sent_each_tick:
			for entity in order:
				accumulated[entity] += float(priorities[entity])
			var ranked: Array = order.duplicate()
			ranked.sort_custom(func(x, y): return accumulated[x] > accumulated[y] or (accumulated[x] == accumulated[y] and x < y))
			for i in range(mini(m, ranked.size())):
				accumulated[ranked[i]] = 0.0
				if pass_number == 1:
					replayed[ranked[i]] += 1
	var server_inside: Array[int] = []
	var server_outside: Array[int] = []
	server_inside.assign(server["inside"])
	server_outside.assign(server["outside"])
	var replay_inside_hz: float = group_hz.call(server_inside, replayed)
	var replay_outside_hz: float = group_hz.call(server_outside, replayed)
	return {
		"updates_a_tick": float(sent) / float(maxi(ticks, 1)),
		"inside_hz": inside_hz,
		"outside_hz": outside_hz,
		"ratio": inside_hz / maxf(outside_hz, 0.001),
		"replay_inside_hz": replay_inside_hz,
		"replay_outside_hz": replay_outside_hz,
		"replay_ratio": replay_inside_hz / maxf(replay_outside_hz, 0.001),
	}


## ---- the session -----------------------------------------------------------------------------------------------------

func _stand_up(clients: int) -> void:
	_server = ClassDB.instantiate("CockpitWorld")
	_server.set_tick_rate(TICK_HZ)
	# BEFORE start: the tracer is attached as the server is built, and set afterwards it records nothing.
	_server.set_tracing(true)
	_server.start(0)
	_clients.clear()
	_in_flight.clear()
	_cabins.clear()
	_tick = 0
	for i in range(clients):
		var world: RefCounted = ClassDB.instantiate("CockpitWorld")
		world.set_tick_rate(TICK_HZ)
		world.start(i + 2)
		_clients.append(world)
	# The handshake is not instant: every client introduces itself and the server accepts.
	_run(int(1.5 * TICK_HZ))


func _tear_down() -> void:
	for world in _clients:
		world.teardown()
	_server.teardown()
	_clients.clear()
	_server = null


func _position(entity: int) -> Vector3:
	for vehicle in _server.vehicle_states():
		if int((vehicle as Dictionary)["entity"]) == entity:
			return (vehicle as Dictionary)["position"]
	return Vector3(INF, INF, INF)


## ONE TICK FOR EVERYBODY over an exact link: a packet sent after tick T is delivered before the receiver's tick
## T + LINK.
func _run(ticks: int) -> void:
	for n in range(ticks):
		_tick += 1
		var waiting: Array = []
		for flight in _in_flight:
			if int(flight[0]) > _tick:
				waiting.append(flight)
			elif int(flight[1]) == 0:
				_server.deliver(int(flight[2]), flight[3], flight[4])
			else:
				_clients[int(flight[1]) - 2].deliver(0, flight[3], flight[4])
		_in_flight = waiting
		_server.tick(DT)
		for world in _clients:
			world.tick(DT)
		for packet in _server.take_outbound():
			_in_flight.append([_tick + LINK, int(packet["peer"]), 0, packet["bytes"], packet["bits"]])
		for i in range(_clients.size()):
			for packet in _clients[i].take_outbound():
				_in_flight.append([_tick + LINK, 0, i + 2, packet["bytes"], packet["bits"]])
		for event in _server.take_trace_events():
			if String(event.get("type", "")) == "component_sent" and String(event.get("component", "")) == "CabinOwner":
				_cabins[int(event.get("client", -1))] = int(event.get("entity", 0))
		# Drained every tick whether or not it is being counted: the world keeps at most 4,096 events.
		var this_tick: Dictionary = {}
		for world in _clients:
			for event in world.take_trace_events():
				if _recording and String(event.get("type", "")) == "component_received" \
						and String(event.get("component", "")) == "VehicleState":
					this_tick[int(event.get("entity", 0))] = true
		if _recording:
			# AN ENTITY SENT, not a component: a craft's record carries several, and each is its own trace event.
			for entity in this_tick:
				_sent_count[entity] = int(_sent_count.get(entity, 0)) + 1
			_sent_each_tick.append(this_tick.size())
