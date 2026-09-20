extends Node
## THE TEST FIELD UNDER LOAD, ON REQUEST: its `stress` traffic, scaled, and what it costs and what the airports do.
##
##   Godot --headless --fixed-fps 120 --xr-mode off --path cockpit res://tests/testfield_stress.tscn -- --traffic=stress
##       --traffic-scale=2                                          the numbers, one scale a run
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/testfield_stress.tscn -- --level=watch
##       --traffic=stress --traffic-scale=2 --scene=pictures --out=C:/somewhere        the pictures
##
## The user, 2026-09-19: "let's have the basic test in testfield, but also have a stress test that increases the amount of
## ai traffic on that map (not by default but runnable on request)". A PROBE, NOT A SUITE: it is not a row of suites.txt,
## and nothing runs it unless asked. `tools/testfield_stress.ps1` runs it at each scale and writes the table.
##
## `--scene=numbers` (the default): the level with `--traffic=stress --traffic-scale=K`, WARM_S of simulation to let the
## aeroplanes spread out, then MEASURE_S with the simulation's own tick breakdown on (`CockpitWorld.tick_breakdown`, per
## tick, microseconds), and the airports watched once a second:
## - go-arounds, summed over every pilot's record;
## - holds, the seconds any departure spent holding short, and why;
## - RUNWAY CONFLICTS, which there must be none of: two aircraft on one runway's pavement at once, either of them faster
##   than a taxi -- a landing or a take-off with somebody else on it;
## - losses, every craft the simulation lost, with its rule.
## One line, `STRESS scale=... aircraft=... tick_ms=... forces_ms=... step_ms=...`, is the table's row.
##
## AND WHAT THE SAME WINDOW SAYS ABOUT HOW IT FLEW AND WHAT IT COST, so one run answers every question asked of it:
## - `STRESS flying kind=...`: height above ground and airspeed, min / mean / max over the window and how much each
##   WANDERED a second, one row a kind, beside that kind's own stall and cruise. See `_sample`.
## - `STRESS wandered most in agl|speed`: the one aeroplane worth handing to a trace, named.
## - `STRESS flagged=N`: every aeroplane that ended the window low for its leg, or outside the band its kind can fly,
##   and how many craft were LOST and so not judged -- a destroyed craft keeps its leg and reads as one standing still
##   at height, which is what six of eight flags were the first time this ran.
## - `STRESS rota <window> kind=...`: what each CHORE KIND cost, because the breakdown's `chores_ms` is all of them in
##   one number. See `_print_the_rota`.
## - `STRESS split block=...`: where one airport pilot's look spends its time, over a shorter window with the game's
##   lap timer on. See `_split`.
##
## `--scene=lapse`, windowed under `--write-movie`: West International from 2 km while the traffic flies, for a
## time-lapse.
##
## `--scene=pictures`, windowed: after PICTURE_AFTER_S of flying, the whole map straight down with every track drawn,
## the busiest airport from 2 km, and SIDE-ON TO THE AEROPLANE FLYING NEAREST THE GROUND (`_clearance_view`), which is
## the only one of the three with any height in it. A time-lapse is the same scene under `--write-movie`, see the tool.
##
## NEVER A CAPTURE OF THE DESKTOP: every picture is the viewport's own image.

const WARM_S: float = 60.0
const MEASURE_S: float = 120.0
## AND THEN A SHORTER WINDOW WITH THE STOPWATCH ON, to split the airport pilots' thinking into the parts of a look:
## separate from the measured window because the laps themselves cost, and the row of the table must not carry them.
const SPLIT_S: float = 30.0
## The game's own lap timer, which `AirportTraffic` puts round every part of a look that walks the other aeroplanes or
## asks the ground. See `world/stopwatch.gd`.
const STOPWATCH := preload("res://world/stopwatch.gd")
const PICTURE_AFTER_S: float = 240.0
## Faster than this on a runway is not taxiing, metres a second.
const MOVING: float = AirportTraffic.TAXI_SPEED + 1.5

## ---- HOW EVERY AEROPLANE IS FLYING, BESIDE WHAT IT COSTS ----------------------------------------------------------
##
## The user, 2026-09-19: "can we keep track of altitude and velocity as well so that we don't have to trace it?" So one
## run answers both questions: the timings and how the traffic actually flew, in the same printed table and in the same
## window. A SUMMARY CHEAP ENOUGH TO BE ALWAYS ON -- the deep per-craft trace with the inputs, and the level that
## replays it, is lane/tracelog's, and this points at the aeroplane worth tracing rather than tracing it.
##
## SAMPLED AT THE RATE THE ROTA LOOKS AT A PILOT (`AirportTraffic.THINK_TICKS`) and never every tick: a hundred aircraft
## at 10 Hz is about eight `vehicle_state` calls a tick, and it is taken in the probe's own await loop, OUTSIDE the
## server tick, so nothing it costs lands in the tick breakdown the table reports.
const SAMPLE_TICKS: int = AirportTraffic.THINK_TICKS

## THE LEGS THAT SHOULD BE AT PATTERN HEIGHT OR ABOVE. An aeroplane on one of these below `TrafficPattern.GATE` above
## the ground at the end of the window is flagged: the gate is the stabilised-approach height ([AFH] 9), so it is the
## one height in this game already agreed to mean "low", and it is not a number typed here. A landing, a take-off, a
## departure and a go-around are legitimately below it, and a taxi is on the ground, so none of them is in this list.
const SHOULD_BE_HIGH: Array[String] = ["downwind", "base", "crossing", "outbound", "to_entry", "entry", "turn_away",
	"enroute", "departing", "climb_out", "crosswind", "vectors"]
## And the legs that are in the air at all, which is where a speed band means anything.
const AIRBORNE: Array[String] = ["final", "straight_in", "go_around", "departure"]

var _level: FlightLevel = null
var _scene: String = "numbers"
var _out: String = "user://testfield_stress"
var _losses: Array[String] = []
var _conflicts: Array[String] = []
var _held_s: float = 0.0
var _held_for: Dictionary = {}
var _tracks: Dictionary = {}
## Entity -> how it flew over the measured window. See `_sample`.
var _flew: Dictionary = {}
var _sampling: bool = false
## EVERY CRAFT THE SIMULATION LOST, as a set of entities. A craft destroyed mid-window keeps its pilot record and its
## leg, and its state goes to a zero velocity, so it reads as an aeroplane standing still at height on its approach:
## six of the eight speed flags at a hundred aircraft were the eight losses, not eight aeroplanes flying badly. What it
## flew BEFORE it was lost is still worth summing, so it stays in the per-kind rows and is left out of the flags and of
## the search for the one worth tracing.
var _lost: Dictionary = {}


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			_scene = argument.trim_prefix("--scene=")
		elif argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	Net.choose_level("testfield")
	Sim.craft_lost.connect(func(kill: Dictionary) -> void:
		_losses.append("%s %s" % [kill.get("kind_name", "?"), kill.get("rule", "")])
		_lost[int(kill.get("victim", -1))] = true)
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	while _level.ground_built_msec < 0.0 or not Sim.is_ready or _level.traffic_plan == null:
		await get_tree().process_frame
	if _scene == "pictures":
		await _pictures()
	elif _scene == "lapse":
		await _lapse()
	else:
		await _numbers()
	print("RESULT=PASS")
	get_tree().quit(0)


func _numbers() -> void:
	await _fly(WARM_S)
	Sim.server.set_tick_breakdown(true)
	Sim.server.reset_chore_report()
	var began: int = Time.get_ticks_msec()
	var frames: int = Engine.get_process_frames()
	_sampling = true
	await _fly(MEASURE_S)
	_sampling = false
	var wall: float = float(Time.get_ticks_msec() - began) / 1000.0
	var b: Dictionary = Sim.server.tick_breakdown()
	var go_arounds: int = 0
	var landed: int = 0
	for entity in _level.traffic_plan.flights:
		go_arounds += int(_level.airport_traffic.record_of(int(entity)).get("go_arounds", 0))
		landed += int(_level.traffic_plan.flights[entity]["landings"])
	var held_for: PackedStringArray = []
	for why in _held_for:
		held_for.append("%s %.0f s" % [why, float(_held_for[why])])
	print("STRESS scale=%d aircraft=%d vehicles=%d tick_ms=%.3f forces_ms=%.3f step_ms=%.3f control_ms=%.3f ground_ms=%.3f chores_ms=%.3f wall_per_sim=%.2f frame_ms=%.2f go_arounds=%d landings=%d held_s=%.0f conflicts=%d losses=%d" % [
		TrafficPlan.scale_asked(), _level.traffic_plan.flights.size(), Sim.server.vehicle_states().size(),
		float(b.get("tick", 0.0)) / 1000.0, float(b.get("forces", 0.0)) / 1000.0, float(b.get("step", 0.0)) / 1000.0,
		float(b.get("control", 0.0)) / 1000.0, float(b.get("ground", 0.0)) / 1000.0, float(b.get("chores", 0.0)) / 1000.0,
		wall / MEASURE_S, wall * 1000.0 / float(maxi(1, Engine.get_process_frames() - frames)), go_arounds, landed,
		_held_s, _conflicts.size(), _losses.size()])
	print("STRESS held for: %s" % ", ".join(held_for))
	print("STRESS conflicts: %s" % "; ".join(_conflicts.slice(0, 8)))
	print("STRESS losses: %s" % "; ".join(_losses.slice(0, 8)))
	_print_the_flying()
	_print_the_rota("measured")
	await _split()


## ONE LOOK AT HOW EVERY AEROPLANE IS FLYING: its height above the ground and its airspeed, and how much each MOVED
## since the last look. Height above ground and not altitude, because the test field's relief is its mountains and a
## number above sea level says nothing about whether an aeroplane is about to fly into a ridge; `Terrain.ground_height`
## is the land and the level's rock over it, which is what a craft has to clear, and it is two cheap calls.
##
## THE WANDER IS A MEAN ABSOLUTE CHANGE A SECOND and not a standard deviation: a deviation about the mean calls a steady
## climb unstable and a slow porpoise steady, and it is the CHANGE that says an aeroplane is hunting. Summed here and
## divided by the span at the end, so a craft that appears part-way through the window is still divided by its own span.
func _sample() -> void:
	var now: int = Engine.get_physics_frames()
	for entity in _level.traffic_plan.flights:
		var e: int = int(entity)
		var state: Dictionary = Sim.server.vehicle_state(e)
		if state.is_empty():
			continue
		var at: Vector3 = state["position"]
		var agl: float = at.y - Terrain.ground_height(at)
		var speed: float = (state["velocity"] as Vector3).length()
		var row: Dictionary = _flew.get(e, {})
		if row.is_empty():
			row = {"kind": int((_level.traffic_plan.flights[entity] as Dictionary)["kind"]), "looks": 0,
				"agl_min": INF, "agl_max": -INF, "agl_sum": 0.0, "agl_moved": 0.0,
				"speed_min": INF, "speed_max": -INF, "speed_sum": 0.0, "speed_moved": 0.0,
				"last_agl": agl, "last_speed": speed, "last_tick": now, "span": 0.0, "phase": "?",
				"agl_min_flying": INF, "flying_looks": 0}
			_flew[e] = row
		var leg: String = String(_level.airport_traffic.record_of(e).get("phase", &"?"))
		# THE LOWEST ANY AEROPLANE GOT WHILE ACTUALLY FLYING, which is a different question from the lowest it got.
		# `agl_min` counts a craft standing on its stand, so it reads 1 to 5 m for every heavy and says nothing; this
		# one counts only the legs that are in the air, and it is the number that answers "did anything skim the
		# ground" when the terrain sampling is made coarser (team-lead's condition on the sampling step, 2026-09-19).
		if SHOULD_BE_HIGH.has(leg) or AIRBORNE.has(leg):
			row["agl_min_flying"] = minf(float(row["agl_min_flying"]), agl)
			row["flying_looks"] = int(row["flying_looks"]) + 1
		row["looks"] = int(row["looks"]) + 1
		row["agl_min"] = minf(float(row["agl_min"]), agl)
		row["agl_max"] = maxf(float(row["agl_max"]), agl)
		row["agl_sum"] = float(row["agl_sum"]) + agl
		row["speed_min"] = minf(float(row["speed_min"]), speed)
		row["speed_max"] = maxf(float(row["speed_max"]), speed)
		row["speed_sum"] = float(row["speed_sum"]) + speed
		var span: float = float(now - int(row["last_tick"])) / float(Engine.physics_ticks_per_second)
		if span > 0.0:
			row["agl_moved"] = float(row["agl_moved"]) + absf(agl - float(row["last_agl"]))
			row["speed_moved"] = float(row["speed_moved"]) + absf(speed - float(row["last_speed"]))
			row["span"] = float(row["span"]) + span
		row["last_agl"] = agl
		row["last_speed"] = speed
		row["last_tick"] = now
		row["agl"] = agl
		row["speed"] = speed
		row["phase"] = leg


## HOW THE TRAFFIC FLEW, one row a kind, then the one aeroplane that wandered most in each of height and speed, then
## every aeroplane that ended the window low or outside the speed band its own kind can fly.
##
## THE BAND IS THE SIMULATION'S OWN and is not a roster kept here: `Sim.handling_of` derives `stall_speed` from the lift
## model and `cruise` from thrust against drag, so both follow a retune of the kind instead of going stale beside it.
## Slower than its own stall while airborne is not flying; the top is the cruise plus the stabilised gate's own
## tolerance for fast (`AirportTraffic.FAST_BY`, +10 kt, [AFH] 9), because a 3-degree descent legitimately runs a little
## past a level-flight cruise and nothing here should invent a number for how much.
func _print_the_flying() -> void:
	var by_kind: Dictionary = {}
	for e in _flew:
		var row: Dictionary = _flew[e]
		var kind: int = int(row["kind"])
		var sum: Dictionary = by_kind.get(kind, {})
		if sum.is_empty():
			sum = {"craft": 0, "looks": 0, "agl_min": INF, "agl_max": -INF, "agl_sum": 0.0, "agl_moved": 0.0,
				"speed_min": INF, "speed_max": -INF, "speed_sum": 0.0, "speed_moved": 0.0, "span": 0.0,
				"agl_min_flying": INF}
			by_kind[kind] = sum
		sum["craft"] = int(sum["craft"]) + 1
		for key in ["looks", "agl_sum", "agl_moved", "speed_sum", "speed_moved", "span"]:
			sum[key] = float(sum[key]) + float(row[key])
		sum["agl_min"] = minf(float(sum["agl_min"]), float(row["agl_min"]))
		sum["agl_min_flying"] = minf(float(sum["agl_min_flying"]), float(row["agl_min_flying"]))
		sum["agl_max"] = maxf(float(sum["agl_max"]), float(row["agl_max"]))
		sum["speed_min"] = minf(float(sum["speed_min"]), float(row["speed_min"]))
		sum["speed_max"] = maxf(float(sum["speed_max"]), float(row["speed_max"]))
	for kind in by_kind:
		var sum: Dictionary = by_kind[kind]
		var looks: float = maxf(float(sum["looks"]), 1.0)
		var span: float = maxf(float(sum["span"]), 0.0001)
		var numbers: Dictionary = Sim.handling_of(int(kind))
		print(("STRESS flying kind=%s craft=%d agl_min=%.0f agl_min_flying=%s agl_mean=%.0f agl_max=%.0f "
			+ "agl_wander=%.2f speed_min=%.1f speed_mean=%.1f speed_max=%.1f speed_wander=%.2f stall=%.1f "
			+ "cruise=%.1f looks=%d") % [
			Sim.kind_name(int(kind)), int(sum["craft"]), float(sum["agl_min"]),
			"never flew" if is_inf(float(sum["agl_min_flying"])) else "%.0f" % float(sum["agl_min_flying"]),
			float(sum["agl_sum"]) / looks,
			float(sum["agl_max"]), float(sum["agl_moved"]) / span,
			float(sum["speed_min"]), float(sum["speed_sum"]) / looks, float(sum["speed_max"]),
			float(sum["speed_moved"]) / span, float(numbers.get("stall_speed", 0.0)),
			float(numbers.get("cruise", 0.0)), int(looks)])
	# THE ONE WORTH TRACING, in each of height and speed: named so lane/tracelog can trace that one craft rather than
	# every craft. Per second of its own span, so a craft that flew for ten seconds of the window is judged on those ten.
	for what in ["agl", "speed"]:
		var worst: int = -1
		var worst_rate: float = -1.0
		for e in _flew:
			if _lost.has(int(e)):
				continue
			var row: Dictionary = _flew[e]
			var rate: float = float(row[what + "_moved"]) / maxf(float(row["span"]), 0.0001)
			if rate > worst_rate:
				worst_rate = rate
				worst = int(e)
		if worst >= 0:
			var row: Dictionary = _flew[worst]
			print("STRESS wandered most in %s: entity=%d kind=%s %s_wander=%.2f a second over %.0f s, ended %s at %.0f m agl and %.1f m/s" % [
				what, worst, Sim.kind_name(int(row["kind"])), what, worst_rate, float(row["span"]),
				String(row["phase"]), float(row.get("agl", 0.0)), float(row.get("speed", 0.0))])
	# AND THE ONE THAT CAME NEAREST THE GROUND WHILE FLYING, named. This is the number that answers whether a change to
	# how the terrain is sampled has let an aeroplane skim something it used to clear: a picture cannot -- a top-down
	# has no height in it and a still from two kilometres cannot tell 300 m of clearance from 30.
	var lowest: int = -1
	var lowest_agl: float = INF
	for e in _flew:
		if _lost.has(int(e)):
			continue
		var row: Dictionary = _flew[e]
		if float(row["agl_min_flying"]) < lowest_agl:
			lowest_agl = float(row["agl_min_flying"])
			lowest = int(e)
	if lowest >= 0 and not is_inf(lowest_agl):
		var low: Dictionary = _flew[lowest]
		print("STRESS nearest the ground while flying: entity=%d kind=%s %.0f m agl over %d flying looks, ended %s" % [
			lowest, Sim.kind_name(int(low["kind"])), lowest_agl, int(low["flying_looks"]), String(low["phase"])])
	var flagged: PackedStringArray = []
	for e in _flew:
		if _lost.has(int(e)):
			continue
		var row: Dictionary = _flew[e]
		var phase: String = String(row["phase"])
		var high_leg: bool = SHOULD_BE_HIGH.has(phase)
		if not high_leg and not AIRBORNE.has(phase):
			continue
		var numbers: Dictionary = Sim.handling_of(int(row["kind"]))
		var stall: float = float(numbers.get("stall_speed", 0.0))
		var top: float = float(numbers.get("cruise", INF)) + AirportTraffic.FAST_BY
		var agl: float = float(row.get("agl", INF))
		var speed: float = float(row.get("speed", 0.0))
		var why: PackedStringArray = []
		if high_leg and agl < TrafficPattern.GATE:
			why.append("%.0f m agl on %s" % [agl, phase])
		if stall > 0.0 and speed < stall:
			why.append("%.1f m/s under a %.1f stall" % [speed, stall])
		if speed > top:
			why.append("%.1f m/s over a %.1f cruise" % [speed, float(numbers.get("cruise", 0.0))])
		if not why.is_empty():
			flagged.append("%s %d: %s" % [Sim.kind_name(int(row["kind"])), int(e), ", ".join(why)])
	print("STRESS flagged=%d of %d flying, %d lost and not judged: %s" % [flagged.size(),
		_flew.size() - _lost.size(), _lost.size(), "; ".join(flagged.slice(0, 10))])


## WHICH CHORE KIND SPENT THE `chores_ms`. The tick breakdown has one number for every chore there is -- a wing's look
## ahead, its leg check, a ship's sailor and each airport pilot's look -- and the rota's own per-kind timer is the only
## thing that says which of them it was. Serves a tick against the target says whether the budget is what sets the rate
## or the target is; overruns say a budget too small for the work.
func _print_the_rota(when: String) -> void:
	var report: Dictionary = Sim.server.chore_report()
	var kinds: Dictionary = report.get("kinds", {})
	for name in kinds:
		var row: Dictionary = kinds[name]
		print(("STRESS rota %s kind=%s registered=%d served_a_tick=%.2f usec_a_tick=%.1f usec_worst_tick=%.1f "
			+ "usec_a_serve=%.1f budget=%d target=%d limit=%d mean_interval=%.1f worst_interval=%d overruns=%d") % [
			when, name, int(row["registered"]), float(row["served_per_tick"]), float(row["usec_per_tick"]),
			float(row["usec_worst_tick"]),
			float(row["usec_per_tick"]) / maxf(float(row["served_per_tick"]), 0.0001),
			int(row["budget"]), int(row["target_ticks"]), int(row["max_ticks"]), float(row["mean_interval"]),
			int(row["worst_interval"]), int(row["overruns"])])


## THE PARTS OF A LOOK, over a second window with the laps on: each block's microseconds a tick, how many times it ran a
## tick, and what one of them cost. THE BLOCKS NEST -- `think` is the whole of one pilot's look and everything else is
## inside it -- so they are printed against `think` and not summed. `look:<phase>` counts the looks each leg of the
## circuit took, which is what says whether the cost is in the air or on the ground.
func _split() -> void:
	AirportTraffic.take_tally()
	STOPWATCH.run(true)
	Sim.server.reset_chore_report()
	var from: int = Engine.get_physics_frames()
	await _fly(SPLIT_S)
	var ticks: float = float(maxi(1, Engine.get_physics_frames() - from))
	var spent: Dictionary = STOPWATCH.take()
	var counted: Dictionary = AirportTraffic.take_tally()
	STOPWATCH.run(false)
	var blocks: Array = spent.keys()
	blocks.sort_custom(func(a: StringName, b: StringName) -> bool: return int(spent[a]) > int(spent[b]))
	for block in blocks:
		var ran: float = float(int(counted.get(block, 0))) / ticks
		print("STRESS split block=%s usec_a_tick=%.1f ran_a_tick=%.2f usec_a_run=%.2f" % [block,
			float(int(spent[block])) / ticks, ran, float(int(spent[block])) / ticks / maxf(ran, 0.0001)])
	var looks: PackedStringArray = []
	for block in counted:
		if String(block).begins_with("look:"):
			looks.append("%s %.2f" % [String(block).trim_prefix("look:"), float(int(counted[block])) / ticks])
	looks.sort()
	print("STRESS split looks a tick by leg: %s" % ", ".join(looks))
	print("STRESS split ground_samples_a_tick=%.2f" % (float(int(counted.get(&"ground_samples", 0))) / ticks))
	# HOW NEAR THE CLIMB RULE CAME, which is the only thing that tells a sky with nothing in the way from a rule that
	# has stopped watching. Slack is metres of climb still to spare at the tightest look anybody took.
	var climb: Dictionary = AirportTraffic.take_climb_watch()
	print("STRESS split climb_fired=%d least_slack_m=%s" % [int(climb["fired"]),
		"none looked" if is_inf(float(climb["slack"])) else "%.1f" % float(climb["slack"])])
	# AND THE ROTA AGAIN OVER THE SAME WINDOW, with the laps on: the difference between the two is what the laps cost.
	_print_the_rota("lapped")


## FLY FOR `seconds` OF SIMULATION, watching the airports once a second.
func _fly(seconds: float) -> void:
	var ticks: int = int(seconds * float(Engine.physics_ticks_per_second))
	for tick in range(ticks):
		await get_tree().physics_frame
		if _sampling and tick % SAMPLE_TICKS == 0:
			_sample()
		if tick % Engine.physics_ticks_per_second == 0:
			_watch()


func _watch() -> void:
	var on_runway: Dictionary = {}
	for entity in _level.traffic_plan.flights:
		var state: Dictionary = Sim.server.vehicle_state(int(entity))
		if state.is_empty():
			continue
		var at: Vector3 = state["position"]
		# A PACKED ARRAY IS A VALUE: appended through `get_or_add` it grew a copy, and the first top-down had no tracks.
		var track: PackedVector3Array = _tracks.get(entity, PackedVector3Array())
		track.append(at)
		_tracks[entity] = track
		var pilot: Dictionary = _level.airport_traffic.record_of(int(entity))
		if pilot.get("phase", &"") == &"hold_short":
			_held_s += 1.0
			var why: String = String(pilot.get("holding_for", ""))
			_held_for[why] = float(_held_for.get(why, 0.0)) + 1.0
		for i in range(Terrain.runways().size()):
			var frame: Dictionary = Terrain.runways()[i]
			if at.y - (frame["centre"] as Vector3).y < 15.0 and Terrain.on_runway(frame, at, 0.0):
				(on_runway.get_or_add(i, []) as Array).append([entity, (state["velocity"] as Vector3).length(),
					pilot.get("phase", &"?")])
	for i in on_runway:
		var there: Array = on_runway[i]
		if there.size() < 2:
			continue
		var fast: bool = there.any(func(one: Array) -> bool: return float(one[1]) > MOVING)
		if fast:
			_conflicts.append("runway %s: %s" % [Terrain.runways()[i].get("field", i),
				", ".join(there.map(func(one: Array) -> String: return "%s %.0f m/s" % [one[2], one[1]]))])


func _pictures() -> void:
	if DisplayServer.get_name() == "headless" or _level.observer == null:
		print("[testfield_stress] pictures need a window and --level=watch")
		return
	DirAccess.make_dir_recursive_absolute(_out)
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	var camera: Camera3D = _level.observer
	# THE BUSY AIRPORT WHILE IT FILLS, then the whole map with every track.
	await _fly(PICTURE_AFTER_S * 0.5)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 50.0
	camera.look_from(Vector3(-17100.0, 800.0, 1700.0), Vector3(-18000.0, Terrain.land_height(Vector3(-18000.0, 0, 0)), 0.0))
	await _fly(4.0)
	_save("stress-west-close")
	# SIDE-ON TO THE AEROPLANE FLYING NEAREST THE GROUND, before the tracks are drawn over everything.
	await _clearance_view(camera)
	await _fly(PICTURE_AFTER_S * 0.5)
	_draw_the_tracks()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 50000.0
	camera.far = 20000.0
	camera.look_from(Vector3(0.0, 9000.0, 0.0), Vector3(0.0, 0.0, -0.001))
	await _fly(2.0)
	_save("stress-top-down")


## HOW FAR ABEAM THE CLEARANCE VIEW STANDS, metres, and how far DOWN the gap between aeroplane and ground its eye sits
## and looks -- both as SHARES OF THAT GAP and not as fixed distances, which is the whole lesson of the first attempt.
##
## THE FIRST CUT PUT THE EYE A FLAT 220 m BELOW THE AEROPLANE AND 1,800 m ABEAM, and produced a picture of the
## underside of the world: the lowest-flying aeroplane was 136 m above the ground, so 220 m below it is UNDERGROUND,
## and at 1,800 m a Cessna is fourteen pixels. The view was broken for exactly the case it exists for -- a LOW
## aeroplane -- and nothing said so until somebody looked at the image.
##
## So the eye drops a share of the gap, which can never take it under the ground, and stands off near enough that the
## gap fills the frame: at 400 m a 136 m gap subtends about 19 degrees of a 40-degree lens, and an 11 m wing is 60
## pixels rather than 14.
const CLEARANCE_OFF: float = 400.0
const CLEARANCE_DOWN: float = 0.4
const CLEARANCE_AIM_DOWN: float = 0.6


## SIDE-ON TO THE AEROPLANE FLYING NEAREST THE GROUND, SO THE AIR BETWEEN IT AND THE GROUND IS WHAT THE PICTURE IS OF.
##
## Every other view this probe takes is a top-down or a field from two kilometres, and NEITHER HAS ANY HEIGHT IN IT: a
## top-down cannot show clearance at all, and a still from 2 km cannot tell 300 m of it from 30. So when the terrain
## sampling changes -- a coarser grid could in principle let an aeroplane skim a rise it used to clear -- this is the
## only view that shows the thing in question. `agl_min_flying` in the numbers is the EVIDENCE; this is what a person
## can look at, and the two are meant to be read together.
##
## It picks the aeroplane, rather than a place: whichever is flying lowest above the ground when the picture is taken,
## which is the one worth looking at and is the same craft in two runs of a simulation that is deterministic. The eye
## stands abeam of its track so the track runs across the frame, and a little below it, looking at a point four tenths
## of the way down to the ground so the aeroplane sits high in the frame and the ground sits low.
func _clearance_view(camera: Camera3D) -> void:
	# SETTLE THE SCENERY FIRST AND AIM LAST. Aiming and then flying four seconds drifted the subject to the edge of the
	# frame -- a Cessna covers 160 m in that time -- so the wait happens before the aeroplane is chosen, and the picture
	# is taken as soon after aiming as a frame allows.
	await _fly(4.0)
	var lowest: int = -1
	var lowest_agl: float = INF
	for entity in _level.traffic_plan.flights:
		var e: int = int(entity)
		var leg: String = String(_level.airport_traffic.record_of(e).get("phase", &"?"))
		if not (SHOULD_BE_HIGH.has(leg) or AIRBORNE.has(leg)):
			continue
		var craft: Dictionary = Sim.server.vehicle_state(e)
		if craft.is_empty():
			continue
		var where: Vector3 = craft["position"]
		var high: float = where.y - Terrain.ground_height(where)
		if high < lowest_agl:
			lowest_agl = high
			lowest = e
	if lowest < 0:
		print("[testfield_stress] no aeroplane was airborne for the clearance view")
		return
	var state: Dictionary = Sim.server.vehicle_state(lowest)
	var at: Vector3 = state["position"]
	var flat := Vector3((state["velocity"] as Vector3).x, 0.0, (state["velocity"] as Vector3).z)
	var going: Vector3 = flat.normalized() if flat.length() > 1.0 else Vector3.FORWARD
	var abeam := Vector3(going.z, 0.0, -going.x)
	var eye: Vector3 = at + abeam * CLEARANCE_OFF
	# A SHARE OF THE GAP, so the eye is always above the ground however low the aeroplane is flying.
	eye.y = at.y - lowest_agl * CLEARANCE_DOWN
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40.0
	camera.look_from(eye, at - Vector3.UP * lowest_agl * CLEARANCE_AIM_DOWN)
	print("[testfield_stress] clearance view: entity=%d kind=%s %.0f m agl on %s" % [lowest,
		Sim.kind_name(int(_level.airport_traffic.record_of(lowest).get("kind", -1))), lowest_agl,
		String(_level.airport_traffic.record_of(lowest).get("phase", &"?"))])
	await _fly(0.25)
	_save("stress-clearance")


## THE TIME-LAPSE: the busiest airport from 2 km for LAPSE_S of simulation, for `--write-movie` at `--fixed-fps 15`; every
## LAPSE_KEEP-th frame is kept when the movie is made (tools/testfield_stress.ps1 -Lapse), so it plays at ten times.
const LAPSE_S: float = 360.0
## The orbit's radius round West International's middle, and its height over the field, metres.
const LAPSE_ORBIT: float = 4500.0
const LAPSE_HEIGHT: float = 1600.0


func _lapse() -> void:
	if _level.observer == null:
		print("[testfield_stress] a lapse needs --level=watch")
		return
	for board in _level.observer.find_children("*", "CanvasItem", true, false):
		(board as CanvasItem).visible = false
	var words := _level.get_node_or_null("Ui") as CanvasLayer
	if words != null:
		words.visible = false
	var camera: Camera3D = _level.observer
	camera.fov = 50.0
	# A SLOW ORBIT, one turn over the lapse, round the middle of the field: with the camera still, the frames between
	# two aeroplanes' moves are near copies, and a time-lapse is judged by how few of its frames are.
	var middle := Vector3(-18000.0, Terrain.land_height(Vector3(-18000.0, 0.0, 0.0)), 0.0)
	var ticks: int = int(LAPSE_S * float(Engine.physics_ticks_per_second))
	for tick in range(ticks):
		if tick % 8 == 0:
			var angle: float = TAU * float(tick) / float(ticks) + 0.9
			camera.look_from(middle + Vector3(cos(angle) * LAPSE_ORBIT, LAPSE_HEIGHT, sin(angle) * LAPSE_ORBIT), middle)
		await get_tree().physics_frame
		if tick % Engine.physics_ticks_per_second == 0:
			_watch()


## EVERY TRACK AS A RIBBON TRACK_WIDE metres wide, unshaded, drawn over everything and untouched by the fog, one colour
## a kind. A 1-pixel line strip was the first try: at 50 km across the frame it vanished, and the haze took the rest.
const TRACK_WIDE: float = 90.0


func _draw_the_tracks() -> void:
	var mesh := ImmediateMesh.new()
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.disable_fog = true
	paint.no_depth_test = true
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	for entity in _tracks:
		var track: PackedVector3Array = _tracks[entity]
		if track.size() < 2:
			continue
		var colour := Color.from_hsv(fmod(float(int(_level.traffic_plan.flights[entity]["kind"])) * 0.137, 1.0), 0.9, 1.0)
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, paint)
		for k in range(track.size()):
			var ahead: Vector3 = track[mini(k + 1, track.size() - 1)] - track[maxi(k - 1, 0)]
			var side := Vector3(-ahead.z, 0.0, ahead.x).normalized() * TRACK_WIDE * 0.5
			mesh.surface_set_color(colour)
			mesh.surface_add_vertex(track[k] + side + Vector3.UP * 200.0)
			mesh.surface_set_color(colour)
			mesh.surface_add_vertex(track[k] - side + Vector3.UP * 200.0)
		mesh.surface_end()
	var ribbons := MeshInstance3D.new()
	ribbons.mesh = mesh
	_level.add_child(ribbons)


func _save(name: String) -> void:
	var path: String = _out.path_join(name + ".png")
	print("[testfield_stress] saved %s %s" % [path, get_viewport().get_texture().get_image().save_png(path) == OK])
