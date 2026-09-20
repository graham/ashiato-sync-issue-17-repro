extends Node
## THE CHORE ROTA: every wing's look ahead and leg re-check, served on a budget and held to their limits.
##
##   Godot --headless --fixed-fps 120 --path cockpit res://tests/rota.tscn
##
## Asked for on 2026-09-14: AI work that runs "roughly every 10 ticks but not more than 60", spread out so that adding
## machines does not load every tick, with a callback. Before this each autopilot kept two float countdowns of its own
## -- a look every half second and a leg re-check every three -- with nothing anywhere to say how many ran on one tick.
## `ChoreRota` in ../ashiato-gd/src/cockpit/chore_rota.hpp is the scheduler; this is what it promises, held against the
## real autopilots rather than a mock of them:
##
##   * UNCONTENDED, a chore comes round about on its target, and none is served over budget;
##   * NO INTERVAL IS EVER LONGER THAN THE KIND'S LIMIT, however little budget there is;
##   * SQUEEZED, the waits stretch towards that limit; STARVED, a chore is forced at exactly the limit and every one
##     served over budget is counted;
##   * TWO WORLDS BUILT ALIKE SERVE THE SAME CHORES ON THE SAME TICKS, and moving one aeroplane changes that -- the
##     second half is what shows the digest can tell two worlds apart at all;
##   * A CLIENT SERVES NOTHING, and a retired aeroplane leaves the rota.
##
## WORLDS BUILT AND TICKED BY HAND, with no session: a CockpitWorld is started as a server, given flat ground and a ring
## of waypoints, and filled with aeroplanes already flying. The limits and targets are read off the report, not typed
## here, so the test holds the rule and not today's numbers.
##
## Read RESULT=, not the exit code.

const HZ: float = 120.0
const HOLD: float = 600.0
const GROUND_HALF := Vector3(12000.0, 400.0, 12000.0)
## Every wing on the rota: two chores each. Mixed, so a limit that only held for one kind's look would show.
const WINGS: Array[int] = [Sim.Kind.PLANE, Sim.Kind.AIRLINER, Sim.Kind.TANKER, Sim.Kind.OSPREY]
const CHORES: Array[String] = ["look_ahead", "leg_check"]
## A sky about the size of the real one, which the default budgets are sized to serve without contention.
const UNCONTENDED: int = 48
const UNCONTENDED_SECONDS: float = 40.0
## A crowd that wants four looks a tick at a 60-tick target: three a tick stretches it to about 80, one a tick cannot
## keep up even at the limit, so the limit does the serving.
const CROWD: int = 240
const SQUEEZED_BUDGET: int = 3
const STARVED_BUDGET: int = 1
## One eightieth of the crowd a tick: three of 240, the same squeeze as a share, and two of the 120 left after half retire.
const SHARE: float = 0.0125
## Four times the look's shipped limit: 240 wings at one look a tick want 240 ticks, past 120 and inside this.
const LONG_LIMIT: int = 480
const REGIME_SECONDS: float = 20.0
const SETTLE_SECONDS: float = 4.0
## Uncontended, the mean interval is the target to within this share. The jitter is symmetric and hashed, so the only
## thing that moves the mean is a chore held a tick by a tick that had more due than its budget.
const NEAR_TARGET: float = 0.05
## Squeezed, the mean has moved at least this far past the target: 240 wings at three a tick want 80 ticks, not 60.
const STRETCHED: float = 1.2

const SECTIONS: int = 6
## Serving while callbacks change the rota: three chores on one stream come due on the same tick in id order.
const PAIR_FIRST: int = 1
const PAIR_REMOVED: int = 2
const PAIR_LAST: int = 3
const PAIR_FLAGGED: int = 4
const PAIR_STREAM: int = 77
const REMOVES_ON_CALL: int = 5
const RETIMES_ON_CALL: int = 7
const GROWER: int = 10
const GROWS_ON_CALL: int = 3
const RETUNED_TO: int = 2
const RETUNE_AT: float = 1.0
const MUTATION_SECONDS: float = 6.0
const ORPHAN_FREED_AT: float = 2.0
## A SCRIPT'S OWN KIND: roughly every ten ticks and never more than sixty, the user's own numbers, for two hundred ids at
## five a tick. They want twenty a tick, so the wait stretches to about forty, still inside the limit.
const THINKERS: int = 200
const THINK_TARGET: int = 10
const THINK_LIMIT: int = 60
const THINK_BUDGET: int = 5
const THINK_SECONDS: float = 30.0
## The one flagged urgent, half way through, and the one that takes itself off the rota on its third call.
const URGENT_ID: int = 1000
const QUITTER_ID: int = 1001
const QUITS_AFTER: int = 3
## A thousand ids on a kind whose callback does nothing, with no budget: what a call into GDScript costs.
const TALLIES: int = 1000

var _failed: bool = false
var _said: Array[String] = []
var _sections: int = 0


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("[rota] CockpitWorld not registered")
		print("RESULT=FAIL extension_missing")
		get_tree().quit(1)
		return
	_uncontended()
	_squeezed()
	_the_same_twice()
	_a_script_is_served_on_the_same_budget()
	_a_callback_may_change_the_rota_while_it_is_served()
	_a_client_serves_nothing()
	# EVERY SECTION REACHED ITS END, or the run fails. Run first against the library before the rota, this suite printed
	# RESULT=PASS: each section threw on its first call to a method that library does not have, the error ended the
	# function, and a suite that only counts failures had none. See "A test that dies silently PASSES" in agents.md.
	_check("every_section_ran_to_its_end", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


func _uncontended() -> void:
	var world = _world(UNCONTENDED, Vector3.ZERO)
	_run(world, UNCONTENDED_SECONDS)
	var kinds: Dictionary = world.chore_report().get("kinds", {})
	for chore in CHORES:
		var row: Dictionary = kinds.get(chore, {})
		var target: float = float(row.get("target_ticks", 0))
		var limit: int = int(row.get("max_ticks", 0))
		var mean: float = float(row.get("mean_interval", 0.0))
		_check("every_wing_has_a_%s_on_the_rota_and_it_is_served" % chore,
			int(row.get("registered", 0)) == UNCONTENDED and int(row.get("intervals", 0)) >= UNCONTENDED,
			"%d registered of %d wings, %d served, %d intervals" % [int(row.get("registered", 0)), UNCONTENDED,
				int(row.get("served", 0)), int(row.get("intervals", 0))])
		_check("an_uncontended_%s_comes_round_on_its_target" % chore,
			target > 0.0 and absf(mean - target) <= target * NEAR_TARGET and int(row.get("overruns", -1)) == 0,
			"mean %.2f ticks against a target of %.0f, worst %d, limit %d, %d over budget, most in a tick %d of %d" % [
				mean, target, int(row.get("worst_interval", 0)), limit, int(row.get("overruns", -1)),
				int(row.get("served_most_in_a_tick", 0)), int(row.get("budget", 0))])
		_check("no_uncontended_%s_waits_past_its_limit" % chore,
			limit > 0 and int(row.get("worst_interval", 0)) <= limit,
			"worst %d ticks, limit %d" % [int(row.get("worst_interval", 0)), limit])
		# THE DEFAULT DOES NOT BIND A SKY THIS SIZE, so a flight suite run against main measures moving the countdowns onto
		# the rota and not a squeeze. A share, so it grows with the sky; what share is the simulation's business.
		_check("the_default_%s_budget_is_a_share_and_does_not_bind_today" % chore,
			float(row.get("share", 0.0)) > 0.0 and int(row.get("overruns", -1)) == 0
				and float(row.get("served_per_tick", 0.0)) < float(row.get("budget", 0)),
			"share %.4f is %d a tick for %d registered; %.2f served a tick, most %d, %d over budget" % [
				float(row.get("share", 0.0)), int(row.get("budget", 0)), int(row.get("registered", 0)),
				float(row.get("served_per_tick", 0.0)), int(row.get("served_most_in_a_tick", 0)), int(row.get("overruns", -1))])

	# ONE NUMBER, ONE PLACE: the look reaches as far again as the longest wait for the next one. What is left over is the
	# climb's own look, which the simulation keeps between 12 and 40 seconds.
	var look_limit: float = float((kinds.get("look_ahead", {}) as Dictionary).get("max_ticks", 0)) / HZ
	var shortest: float = INF
	var longest: float = -INF
	for entity in _wings(world):
		var own: float = float(world.ai_destination(entity).get("look_seconds", 0.0)) - look_limit
		shortest = minf(shortest, own)
		longest = maxf(longest, own)
	_check("the_look_reaches_past_the_longest_wait_for_the_next_one",
		look_limit > 0.0 and shortest >= 12.0 - 0.001 and longest <= 40.0 + 0.001,
		"look less the %.2f s limit: %.2f to %.2f s" % [look_limit, shortest, longest])

	# AND ONE THAT GOES TAKES ITS CHORES WITH IT.
	var gone: int = _wings(world)[0]
	world.despawn_vehicle(gone)
	world.tick(1.0 / HZ)
	var after: Dictionary = world.chore_report().get("kinds", {})
	_check("a_retired_aeroplane_leaves_the_rota",
		int((after.get("look_ahead", {}) as Dictionary).get("registered", 0)) == UNCONTENDED - 1
			and int((after.get("leg_check", {}) as Dictionary).get("registered", 0)) == UNCONTENDED - 1,
		"look %d, leg %d registered after retiring one of %d" % [
			int((after.get("look_ahead", {}) as Dictionary).get("registered", 0)),
			int((after.get("leg_check", {}) as Dictionary).get("registered", 0)), UNCONTENDED])
	world.teardown()
	_sections += 1


func _squeezed() -> void:
	var world = _world(CROWD, Vector3.ZERO)
	_run(world, SETTLE_SECONDS)

	# SQUEEZED: less budget than the crowd wants at the target, more than it needs at the limit.
	world.set_chore_budget("look_ahead", SQUEEZED_BUDGET)
	_run(world, SETTLE_SECONDS)
	world.reset_chore_report()
	_run(world, REGIME_SECONDS)
	var look: Dictionary = world.chore_report()["kinds"]["look_ahead"]
	var target: float = float(look["target_ticks"])
	var limit: int = int(look["max_ticks"])
	_check("a_squeezed_look_waits_longer_and_never_past_its_limit",
		float(look["mean_interval"]) >= target * STRETCHED and int(look["worst_interval"]) <= limit
			and float(look["served_per_tick"]) >= SQUEEZED_BUDGET * 0.95,
		"%d wings at %d a tick: mean %.1f ticks against a target of %.0f, worst %d, limit %d, %.2f served a tick, %d over budget" % [
			CROWD, SQUEEZED_BUDGET, float(look["mean_interval"]), target, int(look["worst_interval"]), limit,
			float(look["served_per_tick"]), int(look["overruns"])])

	# STARVED: less than the limit itself needs, so the limit serves them, and says so.
	world.set_chore_budget("look_ahead", STARVED_BUDGET)
	world.set_chore_budget("leg_check", 0)
	_run(world, SETTLE_SECONDS)
	world.reset_chore_report()
	_run(world, REGIME_SECONDS)
	var kinds: Dictionary = world.chore_report()["kinds"]
	look = kinds["look_ahead"]
	_check("a_starved_look_is_forced_at_its_limit_and_counted",
		int(look["worst_interval"]) == limit and float(look["mean_interval"]) >= limit * 0.95
			and int(look["overruns"]) > 0 and int(look["served_most_in_a_tick"]) > STARVED_BUDGET,
		"%d wings at %d a tick: mean %.1f, worst %d, limit %d, %d served, %d over budget, most in a tick %d" % [
			CROWD, STARVED_BUDGET, float(look["mean_interval"]), int(look["worst_interval"]), limit, int(look["served"]),
			int(look["overruns"]), int(look["served_most_in_a_tick"])])
	var leg: Dictionary = kinds["leg_check"]
	_check("a_leg_check_with_no_budget_runs_only_at_its_limit_and_every_one_is_an_overrun",
		int(leg["served"]) > 0 and int(leg["overruns"]) == int(leg["served"])
			and int(leg["worst_interval"]) == int(leg["max_ticks"]) and float(leg["mean_interval"]) == float(leg["max_ticks"]),
		"%d served, %d over budget, mean %.1f, worst %d, limit %d" % [int(leg["served"]), int(leg["overruns"]),
			float(leg["mean_interval"]), int(leg["worst_interval"]), int(leg["max_ticks"])])

	# A LONGER LIMIT. The look still starved at one a tick, its limit raised from 120 to 480: it waits past the old limit,
	# never past the new one, is forced nowhere, and every wing's look reaches as far again as the new limit.
	var shipped_limit: int = int(look["max_ticks"])
	var refused_limit: bool = not world.set_chore_limit("look_ahead", int(look["target_ticks"]) - 1)
	world.set_chore_limit("look_ahead", LONG_LIMIT)
	world.set_chore_budget("leg_check", -1)
	_run(world, SETTLE_SECONDS)
	world.reset_chore_report()
	_run(world, REGIME_SECONDS)
	look = world.chore_report()["kinds"]["look_ahead"]
	var reach: float = float(world.ai_destination(_wings(world)[0]).get("look_seconds", 0.0)) - float(LONG_LIMIT) / HZ
	_check("a_longer_limit_lets_a_starved_look_wait_past_the_old_one_and_the_look_reaches_with_it",
		refused_limit and int(look["max_ticks"]) == LONG_LIMIT and float(look["mean_interval"]) > float(shipped_limit)
			and int(look["worst_interval"]) <= LONG_LIMIT and int(look["overruns"]) == 0
			and reach >= 12.0 - 0.001 and reach <= 40.0 + 0.001,
		"%d wings at %d a tick with a limit of %d: mean %.1f, worst %d, %d over budget; look less the limit %.2f s; a limit under the target refused: %s" % [
			CROWD, STARVED_BUDGET, int(look["max_ticks"]), float(look["mean_interval"]), int(look["worst_interval"]),
			int(look["overruns"]), reach, refused_limit])
	world.set_chore_limit("look_ahead", shipped_limit)

	# A SHARE: "only do some percentage of the planes per tick". One eightieth of 240 is three a tick, the squeeze above.
	var refused_shares: bool = not world.set_chore_budget("look_ahead", 1.5) and not world.set_chore_budget("look_ahead", 0.0)
	world.set_chore_budget("look_ahead", SHARE)
	world.set_chore_budget("leg_check", -1)
	_run(world, SETTLE_SECONDS)
	world.reset_chore_report()
	_run(world, REGIME_SECONDS)
	look = world.chore_report()["kinds"]["look_ahead"]
	_check("a_share_of_the_crowd_is_a_budget_of_that_many_a_tick",
		refused_shares and int(look["budget"]) == int(ceil(CROWD * SHARE)) and absf(float(look["share"]) - SHARE) < 0.000001
			and float(look["mean_interval"]) >= target * STRETCHED and int(look["worst_interval"]) <= limit,
		"share %.4f of %d is %d a tick: mean %.1f against %.0f, worst %d of %d; 1.5 and 0 refused: %s" % [
			float(look["share"]), int(look["registered"]), int(look["budget"]), float(look["mean_interval"]), target,
			int(look["worst_interval"]), limit, refused_shares])
	var wings: Array[int] = _wings(world)
	for i in range(wings.size() / 2):
		world.despawn_vehicle(wings[i])
	world.tick(1.0 / HZ)
	look = world.chore_report()["kinds"]["look_ahead"]
	_check("and_the_share_follows_the_crowd_when_half_of_it_goes",
		int(look["registered"]) == CROWD / 2 and int(look["budget"]) == int(ceil(CROWD / 2 * SHARE)),
		"%d registered, budget %d a tick" % [int(look["registered"]), int(look["budget"])])
	world.teardown()
	_sections += 1


## Two worlds built alike and ticked in turn, one tick each, so anything the two shared -- a static, a global -- would
## make them disagree. And a third with one aeroplane moved sixteen metres, whose seed and so whose schedule move.
func _the_same_twice() -> void:
	var one = _world(64, Vector3.ZERO)
	var two = _world(64, Vector3.ZERO)
	var moved = _world(64, Vector3(16.0, 0.0, 0.0))
	for i in range(int(REGIME_SECONDS * HZ)):
		one.tick(1.0 / HZ)
		two.tick(1.0 / HZ)
		moved.tick(1.0 / HZ)
	var a: Dictionary = one.chore_report()
	var b: Dictionary = two.chore_report()
	var c: Dictionary = moved.chore_report()
	var served: int = int(a["kinds"]["look_ahead"]["served"]) + int(a["kinds"]["leg_check"]["served"])
	_check("two_worlds_built_alike_serve_the_same_chores_on_the_same_ticks",
		served > 0 and String(a["digest"]) == String(b["digest"]) and int(a["frame"]) == int(b["frame"]),
		"%d serves to frame %d: %s and %s" % [served, int(a["frame"]), a["digest"], b["digest"]])
	_check("and_moving_one_aeroplane_changes_when_it_is_served",
		String(a["digest"]) != String(c["digest"]),
		"%s against %s" % [a["digest"], c["digest"]])
	for world in [one, two, moved]:
		world.teardown()
	_sections += 1


## A SCRIPTED AI STATE MACHINE ON THE ROTA: a Callable called with (id, ticks waited), on the budget, under the limit,
## sooner while urgent, and able to take itself off. Counted by the callback itself, so a report that claimed serves the
## script never saw would not pass.
func _a_script_is_served_on_the_same_budget() -> void:
	var world = _world(0, Vector3.ZERO)
	var clock: Array[int] = [0]
	var seen: Dictionary = {"calls": 0, "most": 0, "worst_waited": 0, "urgent_waits": [], "quitter": 0}
	var this_tick: Array[int] = [0, -1]
	var think := func(id: int, waited: int) -> void:
		seen["calls"] = int(seen["calls"]) + 1
		if this_tick[1] != clock[0]:
			this_tick[0] = 0
			this_tick[1] = clock[0]
		this_tick[0] += 1
		seen["most"] = maxi(int(seen["most"]), this_tick[0])
		seen["worst_waited"] = maxi(int(seen["worst_waited"]), waited)
		if id == URGENT_ID and clock[0] > int(THINK_SECONDS * HZ * 0.5) + THINK_LIMIT:
			(seen["urgent_waits"] as Array).append(waited)
		if id == QUITTER_ID:
			seen["quitter"] = int(seen["quitter"]) + 1
			if int(seen["quitter"]) == QUITS_AFTER:
				world.remove_chore("think", QUITTER_ID)
	var refused: Array[String] = []
	if world.add_chore_kind("look_ahead", 10, 60, 5, think):
		refused.append("a name the autopilots already use")
	if world.add_chore_kind("never", 0, 60, 5, think):
		refused.append("a target of none")
	if world.add_chore_kind("backwards", 30, 20, 5, think):
		refused.append("a limit shorter than the target")
	if world.add_chore_kind("nobody", 10, 60, 5, Callable()):
		refused.append("a callback that cannot be called")
	if world.add_chore("nothing_by_that_name", 1):
		refused.append("a chore of a kind nobody added")
	_check("a_kind_that_cannot_keep_its_promise_is_refused", refused.is_empty(),
		"accepted: %s" % ", ".join(refused) if not refused.is_empty() else "all five refused")
	var added: bool = world.add_chore_kind("think", THINK_TARGET, THINK_LIMIT, THINK_BUDGET, think)
	var on: int = 0
	for i in range(THINKERS):
		on += 1 if world.add_chore("think", URGENT_ID + i) else 0
	for tick in range(int(THINK_SECONDS * HZ)):
		clock[0] = tick
		if tick == int(THINK_SECONDS * HZ * 0.5):
			world.set_chore_urgent("think", URGENT_ID, true)
		world.tick(1.0 / HZ)
	var row: Dictionary = world.chore_report()["kinds"].get("think", {})
	_check("a_script_adds_a_kind_and_every_serve_calls_it",
		added and on == THINKERS and int(seen["calls"]) > 0 and int(seen["calls"]) == int(row.get("served", -1)),
		"%d on the rota, %d calls counted by the callback, %d served by the report" % [on, int(seen["calls"]),
			int(row.get("served", -1))])
	_check("a_scripted_kind_is_served_on_its_budget_and_under_its_limit",
		int(seen["most"]) <= THINK_BUDGET and int(row.get("overruns", -1)) == 0
			and int(seen["worst_waited"]) <= THINK_LIMIT and float(row.get("mean_interval", 0.0)) >= THINK_TARGET * STRETCHED,
		"%d ids wanting %d a tick at %d: most in one tick %d, mean %.1f ticks, worst waited %d of %d, %d over budget" % [
			THINKERS, THINKERS / THINK_TARGET, THINK_BUDGET, int(seen["most"]), float(row.get("mean_interval", 0.0)),
			int(seen["worst_waited"]), THINK_LIMIT, int(row.get("overruns", -1))])
	var urgent_waits: Array = seen["urgent_waits"]
	var urgent_limit: int = int(row.get("urgent_max_ticks", 0))
	_check("an_urgent_chore_is_served_within_its_urgent_limit_on_a_contended_rota",
		urgent_waits.size() >= 10 and urgent_limit > 0 and urgent_limit < THINK_LIMIT and urgent_waits.max() <= urgent_limit,
		"%d serves once urgent, waits %s ticks, urgent limit %d against %d, the crowd's mean %.1f" % [urgent_waits.size(),
			urgent_waits.slice(0, 8), urgent_limit, THINK_LIMIT, float(row.get("mean_interval", 0.0))])
	_check("a_callback_can_take_its_own_chore_off_the_rota",
		int(seen["quitter"]) == QUITS_AFTER and int(row.get("registered", 0)) == THINKERS - 1,
		"called %d times, asked to stop after %d; %d still registered" % [int(seen["quitter"]), QUITS_AFTER,
			int(row.get("registered", 0))])

	# WHAT A CALL COSTS. A callback that does nothing, a thousand of them every ten ticks with no budget, timed by the
	# simulation around each call; printed and not held, since a microsecond has no right answer under five other lanes.
	var tallies: Array[int] = [0]
	world.add_chore_kind("tally", THINK_TARGET, THINK_LIMIT, -1, func(_id: int, _waited: int) -> void: tallies[0] += 1)
	for i in range(TALLIES):
		world.add_chore("tally", 5000 + i)
	_run(world, 1.0)
	world.reset_chore_report()
	_run(world, 5.0)
	var tally: Dictionary = world.chore_report()["kinds"]["tally"]
	var per_call: float = float(tally["usec_per_tick"]) / maxf(float(tally["served_per_tick"]), 0.001)
	print("[rota] a Callable that does nothing: %.3f us a call, %.1f calls a tick, %.1f us a tick" % [per_call,
		float(tally["served_per_tick"]), float(tally["usec_per_tick"])])
	_check("a_thousand_scripted_chores_are_all_called", tallies[0] > 0 and float(tally["served_per_tick"]) >= TALLIES / THINK_TARGET * 0.95,
		"%.1f a tick against %d ids every %d ticks" % [float(tally["served_per_tick"]), TALLIES, THINK_TARGET])
	world.teardown()
	_sections += 1


## Something a Callable can point at and then stop existing. A Callable on a RefCounted does not keep it alive.
class Listener:
	extends RefCounted
	var heard: int = 0

	func hear(_id: int, _waited: int) -> void:
		heard += 1


## A CALLBACK THAT CHANGES THE ROTA WHILE IT IS BEING SERVED: removes another chore in its own batch, adds chores and a
## whole kind, changes its kind's budget, and has its object freed under it. None of it may skip another chore or serve
## one that is gone. An ERROR inside a callback is not here, and on purpose: Godot reports it and `call` returns, but the
## runner fails a suite on any SCRIPT ERROR on stderr, and its allowlist is for messages the C++ provokes.
func _a_callback_may_change_the_rota_while_it_is_served() -> void:
	var world = _world(0, Vector3.ZERO)
	var clock: Array[int] = [0]
	var calls: Dictionary = {}
	var retuned_ticks: Dictionary = {}
	var retuned: Array[bool] = [false]
	var count := func(id: int) -> int:
		calls[id] = int(calls.get(id, 0)) + 1
		return int(calls[id])
	calls["last_ticks"] = []
	calls["flagged_ticks"] = []
	var pair := func(id: int, _waited: int) -> void:
		var n: int = count.call(id)
		if id == PAIR_LAST:
			(calls["last_ticks"] as Array).append(clock[0])
		if id == PAIR_FLAGGED:
			(calls["flagged_ticks"] as Array).append(clock[0])
		if id == PAIR_FIRST and n == REMOVES_ON_CALL:
			world.remove_chore("pair", PAIR_REMOVED)
		# FLAGGING AND RE-TIMING CHORES STILL IN THIS TICK'S BATCH: both move their generation, and a batch checked by
		# generation would pass over the two chores behind this one on its stream.
		if id == PAIR_FIRST and n == RETIMES_ON_CALL:
			calls["retimed_at"] = clock[0]
			world.set_chore_urgent("pair", PAIR_FLAGGED, true)
			world.set_chore_limit("pair", 60)
	var grow := func(id: int, waited: int) -> void:
		calls["worst_waited"] = maxi(int(calls.get("worst_waited", 0)), waited)
		if count.call(id) == GROWS_ON_CALL and id == GROWER:
			for extra in range(1, 11):
				world.add_chore("grow", GROWER + extra)
			world.add_chore_kind("late", 10, 60, -1, func(late_id: int, _w: int) -> void: count.call(late_id))
			world.add_chore("late", 40)
	var retune := func(id: int, _waited: int) -> void:
		count.call(id)
		if not retuned[0] and clock[0] >= int(RETUNE_AT * HZ):
			retuned[0] = world.set_chore_budget("retune", RETUNED_TO)
			retuned_ticks["at"] = clock[0]
		elif retuned[0] and clock[0] > int(retuned_ticks["at"]):
			retuned_ticks[clock[0]] = int(retuned_ticks.get(clock[0], 0)) + 1
	var listener := Listener.new()
	var added: bool = world.add_chore_kind("pair", 10, 60, -1, pair) and world.add_chore_kind("grow", 10, 60, -1, grow) \
		and world.add_chore_kind("retune", 10, 60, -1, retune) \
		and world.add_chore_kind("orphan", 10, 60, -1, Callable(listener, "hear"))
	for id in [PAIR_FIRST, PAIR_REMOVED, PAIR_LAST, PAIR_FLAGGED]:
		added = world.add_chore("pair", id, PAIR_STREAM) and added
	added = world.add_chore("grow", GROWER) and added
	for i in range(50):
		added = world.add_chore("retune", 100 + i) and added
	for i in range(5):
		added = world.add_chore("orphan", 200 + i) and added
	var heard_before_freeing: int = -1
	for tick in range(int(MUTATION_SECONDS * HZ)):
		clock[0] = tick
		if tick == int(ORPHAN_FREED_AT * HZ):
			heard_before_freeing = listener.heard
			listener = null
		world.tick(1.0 / HZ)
	var kinds: Dictionary = world.chore_report()["kinds"]
	_check("a_callback_removing_another_chore_in_its_batch_skips_only_that_one",
		added and int(calls.get(PAIR_REMOVED, 0)) == REMOVES_ON_CALL - 1 and int(calls.get(PAIR_FIRST, 0)) > REMOVES_ON_CALL * 4
			and int(calls.get(PAIR_LAST, 0)) == int(calls.get(PAIR_FIRST, 0)),
		"first %d calls, removed on the first's call %d and called %d times, last %d calls" % [
			int(calls.get(PAIR_FIRST, 0)), REMOVES_ON_CALL, int(calls.get(PAIR_REMOVED, 0)), int(calls.get(PAIR_LAST, 0))])
	var retimed_at: int = int(calls.get("retimed_at", -1))
	_check("a_callback_flagging_or_re_timing_chores_in_its_batch_still_has_them_served_that_tick",
		retimed_at >= 0 and (calls["last_ticks"] as Array).has(retimed_at) and (calls["flagged_ticks"] as Array).has(retimed_at),
		"re-timed at tick %d on the first chore's call %d; the third served then: %s, the flagged fourth served then: %s" % [
			retimed_at, RETIMES_ON_CALL, (calls["last_ticks"] as Array).has(retimed_at),
			(calls["flagged_ticks"] as Array).has(retimed_at)])
	var grown: int = 0
	for extra in range(1, 11):
		grown += 1 if int(calls.get(GROWER + extra, 0)) > 0 else 0
	_check("a_callback_adding_chores_and_a_kind_mid_serve_has_them_all_served",
		grown == 10 and int(calls.get(40, 0)) > 0 and int((kinds.get("grow", {}) as Dictionary).get("registered", 0)) == 11
			and int(calls.get("worst_waited", 999)) <= 60,
		"%d of 10 added chores served, the added kind's chore %d times, worst wait %d" % [grown,
			int(calls.get(40, 0)), int(calls.get("worst_waited", 999))])
	var most_after: int = 0
	for key in retuned_ticks:
		if key is int:
			most_after = maxi(most_after, int(retuned_ticks[key]))
	var retune_row: Dictionary = kinds.get("retune", {})
	_check("a_callback_changing_its_budget_mid_serve_holds_from_the_next_tick",
		retuned[0] and most_after <= RETUNED_TO and int(retune_row.get("budget", 0)) == RETUNED_TO
			and int(retune_row.get("overruns", -1)) == 0 and int(retune_row.get("worst_interval", 999)) <= 60,
		"retuned to %d at tick %s; most in a tick after %d, %d over budget, worst %d" % [RETUNED_TO,
			retuned_ticks.get("at", "never"), most_after, int(retune_row.get("overruns", -1)),
			int(retune_row.get("worst_interval", 999))])
	var orphan: Dictionary = kinds.get("orphan", {})
	_check("a_callback_whose_object_is_gone_is_passed_over_and_nothing_else_stops",
		heard_before_freeing > 0 and not bool(orphan.get("scripted", true))
			and int(calls.get(PAIR_FIRST, 0)) >= int(MUTATION_SECONDS * HZ / 60.0) * 4,
		"heard %d before it was freed, still callable afterwards: %s; the pair's first chore called %d times" % [
			heard_before_freeing, orphan.get("scripted", "?"), int(calls.get(PAIR_FIRST, 0))])
	world.teardown()
	_sections += 1


func _a_client_serves_nothing() -> void:
	var world = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(HZ)
	world.start(1)
	for i in range(30):
		world.tick(1.0 / HZ)
	var kinds: Dictionary = world.chore_report().get("kinds", {})
	_check("a_client_has_no_rota_and_refuses_a_budget_or_a_script",
		kinds.is_empty() and not world.set_chore_budget("look_ahead", 1)
			and not world.add_chore_kind("think", 10, 60, 5, func(_id: int, _waited: int) -> void: pass)
			and not world.add_chore("look_ahead", 1),
		"%d kinds on a client" % kinds.size())
	world.teardown()
	_sections += 1


func _world(count: int, nudge: Vector3):
	var world = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(HZ)
	world.start(0)
	world.add_static_box(Vector3(0.0, -GROUND_HALF.y, 0.0), GROUND_HALF)
	for kind in WINGS:
		for i in range(8):
			var bearing: float = TAU * float(i) / 8.0
			world.add_ai_waypoint(kind, Vector3(sin(bearing) * 8000.0, HOLD, cos(bearing) * 8000.0))
	for i in range(count):
		var kind: int = WINGS[i % WINGS.size()]
		var at := Vector3((float(i % 20) - 9.5) * 400.0, HOLD + float(i % 3) * 60.0, (float(i / 20) - 6.0) * 400.0)
		if i == 0:
			at += nudge
		var yaw: float = TAU * float(i % 8) / 8.0
		var cruise: float = float(world.handling(kind).get("cruise", 60.0))
		world.spawn_ai_vehicle(kind, at, yaw, Terrain.nose_from_yaw(yaw) * cruise)
	return world


func _wings(world) -> Array[int]:
	var found: Array[int] = []
	for state in world.vehicle_states():
		if WINGS.has(int(state["kind"])):
			found.append(int(state["entity"]))
	found.sort()
	return found


func _run(world, seconds: float) -> void:
	for i in range(int(seconds * HZ)):
		world.tick(1.0 / HZ)


func _check(name: String, passed: bool, detail: String) -> void:
	print("[rota] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true
		_said.append(name)
