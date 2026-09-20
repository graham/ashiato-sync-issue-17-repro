extends Node
## WHERE DOES THE TIME GO AT 300 KPH?
##
##   Godot --headless --path cockpit res://tests/hitch_probe.tscn
##
## Headless, so there is no renderer in the way: what this measures is the simulation
## alone, which is the half a player cannot see and the half that stops the renderer
## keeping time when it goes wrong. A physics frame that misses its budget makes Godot run
## two ticks in one drawn frame, and the world jumps -- which looks exactly like a
## networking problem and is not one.
##
## It reports three things, because they fail differently:
##
##   1. **Tick cost**, as a distribution rather than a mean. A hitch is a p99, and an
##      average hides it perfectly.
##   2. **Rollbacks**, and what they COST -- the ticks replayed, not the count. A rollback
##      replays every frame from the correction to now, inside the frame that received it.
##   3. **What the sync tracer saw**, which is the only thing that can say WHY a rollback
##      happened rather than that one did.

## ---------------------------------------------------------------------------------
## AND IT IS A SUITE NOW, NOT ONLY A PROBE
## ---------------------------------------------------------------------------------
##
## It was a probe for a long time and it should not have been. What it measures is the
## three numbers that would catch the most expensive bug this project has had -- the
## correction offset that was A TICK OF TRAVEL, which read as the world stepping while the
## cockpit stayed perfectly steady and took a day of guessing to find -- and those numbers
## were recorded in `agents.md` as pass conditions in all but name. A regression in any of
## them was caught only if somebody remembered to run this by hand.
##
## MEASURED ON 2026-09-11, on the double-precision engine, and these are the numbers the
## thresholds below are set against:
##
## | | 60 Hz | 120 Hz |
## |---|---|---|
## | tick cost, median | 0.178 ms | 0.065 ms |
## | tick cost, p99 | 0.214 ms | 0.083 ms |
## | ticks over budget | 0 of 1800 | 0 of 1800 |
## | worst drawn step, corrected tick | 2897% | **0.0%** |
## | ticks stepped more than 15% off | 29 | **0** |
## | worst unexplained rotation | 0.0300 deg | **0.0007 deg** |
## | rollbacks | 31.5/s | **0.5/s** |
##
## and the whole game at 71 vehicles: server and client together 0.273 ms median, 0.318 p99;
## the client alone 0.084 ms.
##
## THE SMOOTHNESS THRESHOLDS ARE HELD AT 120 Hz ONLY, and that is not a dodge. This game
## runs at 120 and `agents.md` says why in capitals: at 60 Hz the 44 kN aeroplane (20 kN since lane/handling,
## 2026-09-17, and not re-measured at 60 Hz) produces
## about thirty rollbacks a second and steps visibly, which is a documented property of the
## aeroplane rather than a fault, and holding a 60 Hz run to a 120 Hz number would be a
## suite that fails for a reason the file already explains. The COST thresholds are held at
## both, because a tick that costs more is a tick that costs more whatever the clock.
##
## TWICE THE MEASUREMENT, EXCEPT WHERE THE MEASUREMENT IS ZERO. Twice nothing is nothing, so
## the four that currently read zero get a floor chosen from what the FAILURE looks like
## instead: the correction-offset bug stalled the picture for a whole tick (100%), so 30% is
## a third of the bug and infinitely more than today's 0.0%; and a whole-world rotation
## becomes something you can see rather than something only a probe finds at about a tenth
## of a degree, which is where `_turn_spikes` already counts.

## Tick cost, MEDIAN, in milliseconds. Twice the measurement at each rate.
##
## THE MEDIAN AND NOT THE p99, which is the opposite of what this file says everywhere else
## and is right here for a reason that was measured rather than assumed. A hitch IS a p99
## and an average hides it perfectly -- that is why the probe prints the whole distribution
## and always will. But a p99 THRESHOLD is a threshold on the machine as much as on the
## code: six runs of this identical, deterministic simulation on a workstation with two
## other agents running Godot suites read p99 0.188, 0.192, 0.194, 0.202, 0.209 and 0.454 ms
## at 60 Hz, and a worst of 1.065 against a usual 0.27. The median over the same six runs
## read 0.171, 0.172, 0.173, 0.175, 0.175, 0.178 -- a four per cent spread against a
## hundred and forty.
##
## So the tail stays in the output, where a person reads it, and the verdict is taken off
## the number that is about the code. The tail's invariant is held separately and exactly:
## `over budget`, which has a hundredfold margin and cannot be moved by scheduling noise.
const MEDIAN_BUDGET_MS: Dictionary = {60: 0.36, 120: 0.13}
## How many of 1800 ticks may miss the budget. One per cent: today it is none of them, and
## the margin against the budget is a hundredfold, so a single late tick is scheduling noise
## on a shared machine rather than a regression.
const OVER_BUDGET_ALLOWED: int = 18
## How far the picture may step on a corrected tick, as a fraction of one tick of travel.
## See the note above: 100% is the picture stalling completely, which is what the bug did.
const WORST_STEP_ALLOWED: float = 0.30
## How many ticks of 1800 may step more than 15% off. Zero today; four is small enough that
## the correction bug (29 of them, and 29 at 60 Hz still) cannot hide under it.
const STEP_SPIKES_ALLOWED: int = 4
## How far the world may rotate in one tick beyond what the vehicle's own spin explains, in
## degrees. A tenth is where it becomes visible; a hundredth is ten times better than that
## and fourteen times today's measurement.
const WORST_TURN_ALLOWED_DEG: float = 0.010
## And none at all may cross the visible tenth of a degree.
const TURN_SPIKES_ALLOWED: int = 0
## Rollbacks a second at 120 Hz. Six times today's half a second, because the rate is set by
## how often the server's answer differs enough to matter and that is a property of the
## flight model -- a tightened controller moves it legitimately.
const ROLLBACKS_ALLOWED: float = 3.0
## The whole game, 71 vehicles, server and client in one process, and the client on its own.
## Both medians, both twice the measurement (0.259-0.273 ms and 0.079-0.080 over six runs).
const WORLD_MEDIAN_MS: float = 0.55
const CLIENT_MEDIAN_MS: float = 0.16

var _failures: PackedStringArray = []
## Sections that reached their own end. A GDScript error aborts the function it is in and
## carries on with the next, so a suite that counts only failures reports a cheerful pass
## over a section that fell over.
var _judged: int = 0

var TICK_HZ: float = 60.0
var DT: float = 1.0 / TICK_HZ
## Four ticks each way, which is a 133 ms round trip: worse than a local session and about
## as bad as a real one.
const LINK_DELAY: int = 4
const CRUISE: float = 83.0   # 300 kph
const SETTLE: int = 240
const SAMPLE: int = 1800     # 30 seconds


var _flight: Array = []
var _tick: int = 0
var _spikes: Array = []
var _turn_spikes: int = 0
var _peak_spin: float = 0.0
var _kicks: Array = []


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("[hitch] CockpitWorld not registered; build with -WithCockpit")
		get_tree().quit(1)
		return
	var probe = ClassDB.instantiate("CockpitWorld")
	print("[hitch] tracing built in: %s" % probe.tracing_available())
	probe.teardown()

	for hz in [60.0, 120.0]:
		TICK_HZ = hz
		DT = 1.0 / hz
		_run("the whole world at %.0f Hz" % hz, true)
	TICK_HZ = 60.0
	DT = 1.0 / 60.0
	_run("bare ground at 60 Hz, for comparison", false)
	_render_frame_cost()
	_full_world_cost()
	_check("every_run_was_judged", _judged == 4, "%d of 4" % _judged)
	_finish()


func _check(label: String, ok: bool, detail: String) -> void:
	print("[hitch] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## WHAT A HUNDRED AND NINETEEN VEHICLES ACTUALLY COST.
##
## Ticked by hand, because that is the only way to find out: headless paces its main loop
## to real time, so timing a physics frame from inside the scene tree measures the frame
## period and would report the budget exactly, whatever the work in it was.
##
## Both worlds, as the game runs them -- and a client is the interesting half, because it
## PREDICTS one vehicle and receives the other hundred and eighteen as interpolation.
## Computing lift, drag and tyre loads for vehicles whose answer is about to be overwritten
## from the buffer is pure waste, so it does not.
func _full_world_cost() -> void:
	_flight = []
	_tick = 0
	TICK_HZ = 120.0
	DT = 1.0 / TICK_HZ
	var server = ClassDB.instantiate("CockpitWorld")
	var client = ClassDB.instantiate("CockpitWorld")
	# THE ISLAND BUILT ONCE and filed by place, as the level does it -- see BoxGrid.
	var solid: Array[Dictionary] = Terrain.boxes()
	var grid := BoxGrid.new(solid)
	for world in [server, client]:
		world.set_tick_rate(TICK_HZ)
		world.start(0 if world == server else 1)
		world.add_static_box(Vector3(0.0, -Terrain.GROUND_HALF.y, 0.0),
			Terrain.GROUND_HALF)
		for box in solid:
			world.add_static_box(box["position"], box["half_extents"])
		for kind in [Sim.Kind.PLANE, Sim.Kind.HELI, Sim.Kind.CAR, Sim.Kind.BOAT]:
			for at in Terrain.waypoints(kind, grid):
				world.add_ai_waypoint(kind, at)
	_advance(server, client, 90, {})
	for spawn in Terrain.spawns():
		server.spawn_vehicle(int(spawn["kind"]), spawn["position"], float(spawn["yaw"]),
			spawn["velocity"])
	var fleet: Array[Dictionary] = Terrain.ai_fleet(grid)
	var entities: PackedInt64Array = []
	for machine in fleet:
		entities.append(server.spawn_ai_vehicle(int(machine["kind"]), machine["position"],
			float(machine["yaw"]), machine["velocity"]))
	for i in range(fleet.size()):
		var leader: int = int(fleet[i].get("leader", -1))
		if leader >= 0:
			server.set_ai_leader(entities[i], entities[leader], fleet[i]["slot"])
	server.spawn_pilot(client.local_client_id(), 1, Vector3(0.0, 700.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -CRUISE))
	_advance(server, client, 240, {"throttle": 1.0})

	var whole: PackedFloat32Array = []
	var client_only: PackedFloat32Array = []
	for i in range(1200):
		client.set_input(_controls({"throttle": 1.0}))
		_tick += 1
		var started: int = Time.get_ticks_usec()
		server.tick(DT)
		var split: int = Time.get_ticks_usec()
		client.tick(DT)
		var done: int = Time.get_ticks_usec()
		whole.append(float(done - started) / 1000.0)
		client_only.append(float(done - split) / 1000.0)
		_pump(server, client)
	whole.sort()
	client_only.sort()

	print("")
	print("[hitch] ---- the whole game, %d vehicles, %d solid boxes ----" % [
		client.vehicle_states().size(), solid.size() + 1])
	print("[hitch] server + client per tick: median %.3f ms  p99 %.3f  worst %.3f"
		% [_at(whole, 0.5), _at(whole, 0.99), _at(whole, 1.0)])
	print("[hitch] the client alone: median %.3f ms  p99 %.3f  (it predicts one vehicle)"
		% [_at(client_only, 0.5), _at(client_only, 0.99)])
	print("[hitch] budget at %.0f Hz: %.2f ms" % [TICK_HZ, 1000.0 / TICK_HZ])
	_check("the_whole_world_fits_in_a_tick",
		_at(whole, 0.50) <= WORLD_MEDIAN_MS,
		"server+client median %.3f ms against %.2f allowed, p99 %.3f, budget %.2f"
		% [_at(whole, 0.50), WORLD_MEDIAN_MS, _at(whole, 0.99), 1000.0 / TICK_HZ])
	# AND THE CLIENT IS THE ONE THAT MATTERS, because that is what a player's machine runs.
	# It is cheap because it does not simulate what it is only watching.
	_check("and_a_client_pays_for_the_one_vehicle_it_predicts",
		_at(client_only, 0.50) <= CLIENT_MEDIAN_MS,
		"median %.3f ms against %.2f allowed, over %d vehicles"
		% [_at(client_only, 0.50), CLIENT_MEDIAN_MS, client.vehicle_states().size()])
	_judged += 1
	server.teardown()
	client.teardown()


## What the RENDER frame used to pay to find out what to draw.
##
## The simulation turned out to be nowhere near the budget, so the hitch was never in it.
## This is the other half: the level's _process ran at the DISPLAY rate and asked the
## simulation to rebuild the entire world state twice, every drawn frame, for a list that
## changes at the tick rate. Each call builds a Dictionary per entity with eight or ten
## keys in it, and none of them are new.
func _render_frame_cost() -> void:
	var server = ClassDB.instantiate("CockpitWorld")
	var client = ClassDB.instantiate("CockpitWorld")
	_flight = []
	_tick = 0
	for world in [server, client]:
		world.set_tick_rate(TICK_HZ)
		world.start(0 if world == server else 1)
		world.add_static_box(Vector3(0.0, -Terrain.GROUND_HALF.y, 0.0),
			Terrain.GROUND_HALF)
	_advance(server, client, 90, {})
	for spawn in Terrain.spawns():
		server.spawn_vehicle(int(spawn["kind"]), spawn["position"], float(spawn["yaw"]),
			spawn["velocity"])
	server.spawn_pilot(client.local_client_id(), 1, Vector3(0.0, 300.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -CRUISE))
	_advance(server, client, 120, {"throttle": 1.0})

	var vehicles: int = client.vehicle_states().size()
	var rounds: int = 2000

	var started: int = Time.get_ticks_usec()
	for i in range(rounds):
		for state in client.vehicle_states():
			var _kind: int = int(state["kind"])
		for state in client.pilot_states():
			var _who: int = int(state["client"])
	var asking: float = float(Time.get_ticks_usec() - started) / float(rounds)

	# What the renderer does now: read what the physics frame already captured.
	var captured: Dictionary = {}
	for state in client.vehicle_states():
		captured[int(state["entity"])] = state
	var riders: Array = client.pilot_states()
	started = Time.get_ticks_usec()
	for i in range(rounds):
		for entity in captured:
			var _kind: int = int((captured[entity] as Dictionary)["kind"])
		for state in riders:
			var _who: int = int(state["client"])
	var reading: float = float(Time.get_ticks_usec() - started) / float(rounds)

	print("")
	print("[hitch] ---- what one drawn frame paid to find out what to draw ----")
	print("[hitch] %d vehicles, %d pilots" % [vehicles, riders.size()])
	print("[hitch] asking the simulation again: %.1f us per frame" % asking)
	print("[hitch] reading what the tick captured: %.1f us per frame" % reading)
	print("[hitch] saved %.1f us per drawn frame (%.1f ms/s at 90 Hz)" % [
		asking - reading, (asking - reading) * 90.0 / 1000.0])
	server.teardown()
	client.teardown()


func _run(label: String, scenery: bool) -> void:
	_flight = []
	_tick = 0
	var server = ClassDB.instantiate("CockpitWorld")
	var client = ClassDB.instantiate("CockpitWorld")
	for world in [server, client]:
		world.set_tick_rate(TICK_HZ)
		# BEFORE start(): the tracer is attached as the client or server is built.
		world.set_tracing(true)
		world.start(0 if world == server else 1)
		world.add_static_box(Vector3(0.0, -Terrain.GROUND_HALF.y, 0.0),
			Terrain.GROUND_HALF)
	var solid: int = 0
	if scenery:
		for box in Terrain.boxes():
			server.add_static_box(box["position"], box["half_extents"])
			client.add_static_box(box["position"], box["half_extents"])
			solid += 1

	# Let the handshake finish before anything is spawned: a client only reaches Ready
	# when it receives an update, and the server only sends updates about replicated
	# entities.
	_advance(server, client, 90, {})

	# Along its own nose. Given a velocity that was not, this aeroplane flew sideways, made
	# no lift, and spent the whole sample scraping the ground at 82 m/s -- which is where
	# the "unexplained" 200 deg/s of rotation was coming from. It was a crash.
	var heading: float = PI * 0.5
	var pilot: Dictionary = server.spawn_pilot(client.local_client_id(), 1,
		Vector3(-1500.0, 600.0, 0.0), heading,
		Terrain.nose_from_yaw(heading) * CRUISE)
	_advance(server, client, SETTLE, {"throttle": 1.0})

	# Straight and level across the map at cruise, which is the case that hitches.
	var costs: PackedFloat32Array = []
	var before: Dictionary = client.resim_stats()
	var kinds: Dictionary = {}
	var reasons: Array = []
	# THE THING A PLAYER ACTUALLY SEES. Each tick the drawn position should advance by
	# velocity times dt; anything else is the world stepping. A correction that freezes the
	# picture for a tick shows up here as a step near zero, and one that yanks it shows as a
	# step near double -- neither of which any amount of tick-cost measurement would find.
	var own: int = _own_vehicle(client)
	var last_drawn: Vector3 = _drawn(client, own)
	var worst_step: float = 0.0
	var worst_at: float = 0.0
	var worst_corrected: float = 0.0
	var worst_quiet: float = 0.0
	var worst_detail: String = "none"
	# THE ATTITUDE, measured the same way and for the same reason. The whole world pivots
	# around the pilot's head when the aeroplane pitches, so a rotation drawn in steps is
	# far more obvious than a position drawn in steps.
	var last_spun: Quaternion = _drawn_basis(client, own)
	var worst_turn: float = 0.0
	var worst_turn_corrected: float = 0.0
	var worst_turn_detail: String = "none"
	for i in range(SAMPLE):
		# The spin BEFORE the step as well as after, because an aeroplane genuinely
		# accelerates in pitch and the rotation it makes over a tick is the AVERAGE of the
		# two, not the one it ended on. Comparing against the end alone calls honest
		# angular acceleration a glitch.
		var spin_before: Vector3 = client.vehicle_state(own).get("spin", Vector3.ZERO)
		var started: int = Time.get_ticks_usec()
		_step(server, client, {"throttle": 1.0})
		costs.append(float(Time.get_ticks_usec() - started) / 1000.0)
		var now: Vector3 = _drawn(client, own)
		var expected: float = (client.vehicle_state(own).get("velocity", Vector3.ZERO)
			as Vector3).length() * DT
		if expected > 0.001:
			var stepped: float = last_drawn.distance_to(now)
			var error: float = absf(stepped - expected) / expected
			var was_corrected: bool = _was_corrected(client, own)
			if error > worst_step:
				worst_step = error
				worst_at = absf(stepped - expected)
				worst_detail = "%s tick %d of %d: stepped %.3f m, expected %.3f m" % [
					"corrected" if was_corrected else "quiet", i, SAMPLE, stepped,
					expected]
			if error > 0.15:
				_spikes.append("tick %d %s step %.3f expected %.3f speed %.1f" % [
					i, "CORRECTED" if was_corrected else "quiet", stepped, expected,
					(client.vehicle_state(own).get("velocity", Vector3.ZERO)
						as Vector3).length()])
			if was_corrected:
				worst_corrected = maxf(worst_corrected, error)
			else:
				worst_quiet = maxf(worst_quiet, error)
		last_drawn = now

		var spun: Quaternion = _drawn_basis(client, own)
		# A wingtip's chord, not Quaternion.angle_to: angle_to is acos of a dot product
		# that is almost exactly 1, and its noise floor is bigger than a tick of an
		# aeroplane's pitch change.
		var turned: float = maxf((spun * Vector3.FORWARD - last_spun * Vector3.FORWARD)
			.length(), (spun * Vector3.RIGHT - last_spun * Vector3.RIGHT).length())
		var spin: float = ((spin_before
			+ (client.vehicle_state(own).get("spin", Vector3.ZERO) as Vector3)) * 0.5
			).length() * DT
		# In DEGREES of excess, not as a ratio. A ratio is meaningless when the aircraft is
		# barely rotating: twice nothing is still nothing, and what the eye reacts to is
		# how far the world actually moved that it should not have.
		var excess: float = rad_to_deg(absf(turned - spin))
		var spin_now: Vector3 = client.vehicle_state(own).get("spin", Vector3.ZERO)
		_peak_spin = maxf(_peak_spin, spin_now.length())
		if spin_now.length() - spin_before.length() > 0.5 and _kicks.size() < 6:
			var at: Dictionary = client.vehicle_state(own)
			_kicks.append("tick %d at %v speed %.1f: spin %v -> %v" % [i,
				(at.get("position", Vector3.ZERO) as Vector3).snapped(Vector3.ONE),
				(at.get("velocity", Vector3.ZERO) as Vector3).length(),
				spin_before.snapped(Vector3.ONE * 0.01),
				spin_now.snapped(Vector3.ONE * 0.01)])
		if excess > worst_turn:
			worst_turn = excess
			worst_turn_detail = ("%s tick %d: turned %.4f deg, expected %.4f, "
				% ["corrected" if _was_corrected(client, own) else "quiet", i,
					rad_to_deg(turned), rad_to_deg(spin)]
				+ "spin %.3f -> %.3f rad/s" % [spin_before.length(), spin_now.length()])
		if _was_corrected(client, own):
			worst_turn_corrected = maxf(worst_turn_corrected, excess)
		# A tenth of a degree is roughly where a whole-world rotation stops being
		# something you can only find with a probe.
		if excess > 0.1:
			_turn_spikes += 1
		last_spun = spun
		for event in client.take_trace_events():
			var type: String = String(event["type"])
			kinds[type] = int(kinds.get(type, 0)) + 1
			if (type == "rollback_reason" or type == "rollback_conflict") \
					and reasons.size() < 6:
				reasons.append("%s %s %s" % [type, event["component"], event["detail"]])
		server.take_trace_events()

	var after: Dictionary = client.resim_stats()
	var flown: Dictionary = client.vehicle_state(_own_vehicle(client))
	costs.sort()

	print("")
	print("[hitch] ---- %s (%d solid boxes) ----" % [label, solid])
	print("[hitch] flew %.0f m/s, %.0f kph" % [
		(flown.get("velocity", Vector3.ZERO) as Vector3).length(),
		(flown.get("velocity", Vector3.ZERO) as Vector3).length() * 3.6])
	print("[hitch] tick cost ms: median %.3f  p95 %.3f  p99 %.3f  worst %.3f  (budget %.2f)"
		% [_at(costs, 0.50), _at(costs, 0.95), _at(costs, 0.99), _at(costs, 1.0),
			1000.0 / TICK_HZ])
	print("[hitch] over budget: %d of %d ticks (%.1f s of simulation)" % [
		_over(costs, 1000.0 / TICK_HZ), SAMPLE, float(SAMPLE) / TICK_HZ])
	print("[hitch] worst drawn step error %.1f%% of a tick (%.3f m) -- 100%% is the picture "
		% [worst_step * 100.0, worst_at] + "stalling for a whole tick")
	print("[hitch]   worst on a corrected tick %.1f%%, worst on a quiet tick %.1f%%" % [
		worst_corrected * 100.0, worst_quiet * 100.0])
	print("[hitch]   %s" % worst_detail)
	for i in range(mini(_spikes.size(), 10)):
		print("[hitch]   spike: %s" % _spikes[i])
	print("[hitch]   %d ticks stepped more than 15%% off" % _spikes.size())
	# KEPT BEFORE THEY ARE CLEARED. The counters are reset here so the next run starts
	# clean, and the verdict below is computed from the same numbers that were printed
	# rather than from whatever survived the reset.
	var step_spikes: int = _spikes.size()
	_spikes.clear()
	print("[hitch] worst UNEXPLAINED world rotation %.4f deg in one tick "
		% worst_turn + "(on corrected ticks %.4f deg)" % worst_turn_corrected)
	print("[hitch]   %s" % worst_turn_detail)
	print("[hitch]   %d of %d ticks rotated more than 0.1 deg beyond their spin" % [
		_turn_spikes, SAMPLE])
	print("[hitch]   peak angular velocity while flying hands-off: %.3f rad/s (%.0f deg/s)"
		% [_peak_spin, rad_to_deg(_peak_spin)])
	for kick in _kicks:
		print("[hitch]   kick: %s" % kick)
	_kicks.clear()
	var turn_spikes: int = _turn_spikes
	_turn_spikes = 0
	_peak_spin = 0.0
	var rolled_per_second: float = float(int(after["count"]) - int(before["count"])) \
		/ (float(SAMPLE) / TICK_HZ)
	print("[hitch] rollbacks %d in %.0f s (%.1f/s), ticks replayed %d, worst span %d" % [
		int(after["count"]) - int(before["count"]), float(SAMPLE) / TICK_HZ,
		rolled_per_second,
		int(after["ticks"]) - int(before["ticks"]), int(after["worst_span"])])
	var seen: PackedStringArray = []
	for type in kinds:
		seen.append("%s=%d" % [type, kinds[type]])
	seen.sort()
	print("[hitch] trace: %s" % ", ".join(seen))
	for reason in reasons:
		print("[hitch]   %s" % reason)
	print("[hitch] trace events dropped: %d" % int(client.trace_events_dropped()))

	# ---- and the verdict ----------------------------------------------------------------
	#
	# The numbers above stay whatever this says. A threshold that swallowed the measurement
	# would be a suite you cannot investigate a failure from, and the whole reason this file
	# was worth promoting is that its output IS the investigation.
	var rate: int = int(TICK_HZ)
	var at: String = "%d Hz" % rate
	_check("a_tick_costs_what_it_did_at_%d" % rate,
		_at(costs, 0.50) <= float(MEDIAN_BUDGET_MS.get(rate, 1.0)),
		"median %.3f ms against %.2f allowed, p99 %.3f, budget %.2f" % [_at(costs, 0.50),
			MEDIAN_BUDGET_MS.get(rate, 1.0), _at(costs, 0.99), 1000.0 / TICK_HZ])
	_check("and_hardly_a_tick_misses_its_budget_at_%d" % rate,
		_over(costs, 1000.0 / TICK_HZ) <= OVER_BUDGET_ALLOWED,
		"%d of %d over %.2f ms at %s" % [_over(costs, 1000.0 / TICK_HZ), SAMPLE,
			1000.0 / TICK_HZ, at])
	# THE SMOOTHNESS HALF IS HELD AT 120 ONLY. See the note at the top of this file: at
	# 60 Hz this aeroplane rolls back thirty times a second and steps visibly, which is a
	# documented property of 44 kN of thrust and the reason the game runs at 120.
	if rate == 120:
		_check("the_picture_does_not_stall_when_a_correction_lands",
			worst_corrected <= WORST_STEP_ALLOWED,
			"worst %.1f%% of a tick against %.0f%% allowed (%s)"
			% [worst_corrected * 100.0, WORST_STEP_ALLOWED * 100.0, worst_detail])
		_check("and_almost_nothing_steps_off_its_own_speed",
			step_spikes <= STEP_SPIKES_ALLOWED,
			"%d of %d ticks more than 15%% off, %d allowed"
			% [step_spikes, SAMPLE, STEP_SPIKES_ALLOWED])
		# ALREADY IN DEGREES. `excess` is compared against 0.1 twenty lines up with the
		# comment "a tenth of a degree", and the line that prints it does not convert
		# either. A `rad_to_deg` here read 0.0402 for a measurement of 0.0007 and failed a
		# threshold that was right -- which is the whole argument for printing the number
		# beside the verdict rather than only the verdict.
		_check("and_the_world_does_not_rotate_for_a_reason_it_cannot_explain",
			worst_turn <= WORST_TURN_ALLOWED_DEG,
			"worst %.4f deg against %.3f allowed" % [worst_turn, WORST_TURN_ALLOWED_DEG])
		_check("and_none_of_it_is_a_tenth_of_a_degree",
			turn_spikes <= TURN_SPIKES_ALLOWED,
			"%d of %d ticks, %d allowed" % [turn_spikes, SAMPLE, TURN_SPIKES_ALLOWED])
		_check("and_a_predicting_client_hardly_rewinds_at_120",
			rolled_per_second <= ROLLBACKS_ALLOWED,
			"%.1f/s against %.1f allowed, worst span %d ticks"
			% [rolled_per_second, ROLLBACKS_ALLOWED, int(after["worst_span"])])
	_judged += 1

	server.teardown()
	client.teardown()


## ---- the harness ---------------------------------------------------------------------

func _step(server, client, input: Dictionary) -> void:
	client.set_input(_controls(input))
	_tick += 1
	server.tick(DT)
	client.tick(DT)
	_pump(server, client)


func _advance(server, client, ticks: int, input: Dictionary) -> void:
	for i in range(ticks):
		_step(server, client, input)


func _pump(server, client) -> void:
	for packet in server.take_outbound():
		_flight.append([_tick + LINK_DELAY, true, packet["bytes"], packet["bits"]])
	for packet in client.take_outbound():
		_flight.append([_tick + LINK_DELAY, false, packet["bytes"], packet["bits"]])
	var still: Array = []
	for entry in _flight:
		if entry[0] > _tick:
			still.append(entry)
		elif entry[1]:
			client.deliver(0, entry[2], entry[3])
		else:
			server.deliver(1, entry[2], entry[3])
	_flight = still


func _controls(overrides: Dictionary) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _own_vehicle(client) -> int:
	for pilot in client.pilot_states():
		if int(pilot["client"]) == client.local_client_id():
			return int(pilot.get("vehicle", 0))
	return 0


## Whether the display says this vehicle was corrected on the tick just simulated.
func _was_corrected(client, entity: int) -> bool:
	for state in client.vehicle_states():
		if int(state["entity"]) == entity:
			return bool(state.get("corrected", false))
	return false


## The attitude a vehicle is DRAWN at, offset and all.
func _drawn_basis(client, entity: int) -> Quaternion:
	for state in client.vehicle_states():
		if int(state["entity"]) == entity:
			return state["basis"]
	return Quaternion.IDENTITY


## Where a vehicle is DRAWN -- the display pose, with the correction offset in it, which
## is not the same as where the simulation says it is.
func _drawn(client, entity: int) -> Vector3:
	for state in client.vehicle_states():
		if int(state["entity"]) == entity:
			return state["position"]
	return Vector3.ZERO


## A percentile of an already-sorted list.
func _at(sorted_costs: PackedFloat32Array, fraction: float) -> float:
	if sorted_costs.is_empty():
		return 0.0
	var index: int = clampi(int(floor(fraction * float(sorted_costs.size() - 1))), 0,
		sorted_costs.size() - 1)
	return sorted_costs[index]


func _over(sorted_costs: PackedFloat32Array, budget: float) -> int:
	var count: int = 0
	for cost in sorted_costs:
		if cost > budget:
			count += 1
	return count
