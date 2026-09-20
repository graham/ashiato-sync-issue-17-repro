extends Node
## Headless: A GYM FOR THE PILOTS. Every kind is given the same tasks -- level off, make a speed gate, turn onto a
## bearing, fly to a point at a height and a speed -- and scored on how well it flew them, so "the AI is jerky" becomes
## a number per kind instead of a feeling.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/vehicle_gym.tscn
##       [-- --write=<file>]   save this build's scores, one line a kind and a task
##       [-- --expect=<file>]  and fail, naming each line, where this build's differ by more than the band
##       [-- --kind=a,b]       only these kinds
##       [-- --task=a,b]       only these tasks
##       [-- --set=k=v|k*f]    retune (TuningCard) before flying
##
## AND IT SCORES TWO HOSTS AGAINST EACH OTHER. `arrive_at_speed` and `arrive_planned` are the same flight -- be at a
## place, at a speed -- flown by different hosts: the first asks for the arrival speed once the point is inside the
## autopilot's own arrival radius (`kArrived`, a flat 220 m for a Cessna and a 747 alike), which is what every host here
## does today; the second steers `world/braking_curve.gd` on the range now, re-steered every `AirportTraffic.THINK_TICKS`
## as the island's own traffic is. The curve has to arrive NEARER the asked speed on every kind, or it is not worth the
## file. It saves 267.1 m/s of arrival error across 16 kinds and makes none of them worse.
##
## WHY (lane/flightcore, from the user 2026-09-19: the pilots' actions are "very jerky and oscillate", a Cessna that
## cannot climb fast enough and a jumbo that cannot slow down enough). Every flight suite here asks whether the aircraft
## ARRIVED. None of them asks what the journey was like, and that is the complaint. `traffic_pattern` will pass a
## circuit flown with the stick sawing from stop to stop, because a circuit flown badly is still a circuit.
##
## THE FIVE SCORES, and the reason each is here:
## - OVERSHOOT, as a fraction of the error the task started with. This is the anticipation fault: the altitude loop is
##   proportional with a cap, so it holds full climb until the error is `climb / 0.45` -- 22 m at 10 m/s -- where the
##   aeroplane needs `climb^2 / 2a` to stop climbing. It goes through and comes back.
## - SETTLING TIME, seconds until it stays inside a twentieth of that error for the rest of the run, and -1 for never.
## - STEADY ERROR, the mean error over the last quarter.
## - CONTROL ACTIVITY: the throttle moved per second, and the REVERSALS a minute of throttle, roll rate and pitch rate.
##   This is the oscillation the user keeps seeing and the one number no suite here has ever measured. A pilot that
##   arrives perfectly having sawed the stick two hundred times a minute has not flown well.
## - ENVELOPE HONESTY: the task's demand against what this kind was MEASURED to manage, in three words. `did` is a
##   demand within the envelope that was met; `refused` is one outside it that was not, which is the right answer; and
##   `FAILED` is a demand inside the envelope that was missed anyway, which is the pilot's fault and nobody else's.
##
## WHAT IT MEASURES FIRST. Each kind is flown to its limits before it is given a task -- top speed at full demand, best
## sustained climb, the deceleration it can hold -- and the envelope is that measurement, not a number typed here.
## Typing book figures beside a model is what took `rotor_hold.gd` red in merge 851314da (see `../agents.md`, "A SUITE
## THAT KEEPS A FORMULA BESIDE THE MODEL"), and a gym built on typed limits would go stale the first time a model moved.
## The limitation is worth stating plainly: the envelope is measured with the SAME pilot that is then scored against it,
## as a flight test is, so it is what the aircraft and its autopilot manage together and not what the airframe could do
## in better hands. When `envelope(kind)` lands in C++ the two become a cross-check on each other.
##
## WHAT IT HOLDS, so it can fail on its own and not only against a saved file:
## - EVERY KIND FLIES EVERY TASK IT IS GIVEN AND EVERY SCORE IS FINITE.
## - EVERY POWERED KIND EVENTUALLY GETS THERE: within a quarter of the height it was asked for, and pointed within
##   thirty degrees of where it was sent. Loose on purpose -- the scores are what is interesting -- but a guidance
##   change that stops an aeroplane arriving at all cannot pass.
## - THE TWO MUTANTS, run inside the suite, because a scoreboard that cannot move is not measuring:
##   * FOUR TIMES THE DEMANDED PITCH RATE and the Cessna hunts: 2.0 reversals a minute become 406.0. If they do not,
##     control activity is reading nothing.
##   * A TWENTIETH OF THE FIN and the light twin will not hold a heading: its turn settles in 54.5 s instead of 23.9 and
##     leaves 0.0915 rad of standing error against 0.0018. If those do not move, settling and steady error read nothing.
##
## A TASK MUST NOT ASK FOR A CLIMB AT A SPEED THE MIXER WILL NOT CLIMB AT. `AircraftMixer::slow_margin` is 1.30: at
## that multiple of the stall none of the climb is allowed and below it the ceiling is a descent. `waypoint` is the only
## task that asks for a place, a height AND a speed at once, and it was asking the 747 and the Warthog to climb at 1.16
## times their stall -- telling the autopilot to climb and refusing it permission in the same breath, then scoring it for
## not arriving. Its speed is now floored HALF WAY from the slow margin up to the cruise (the allowance fades, so a floor
## at the margin itself buys nothing), with the stall asked of the model (`handling()["stall_speed"]`). It reproduces
## today's speed exactly wherever the cruise is a proper 1.45 times the stall -- the Cessna is 45.3 m/s either way -- and
## binds only where it is not. THE LEVEL TASKS ARE NOT FLOORED: doing that as well shrank the arrival task until there
## was nothing left to slow for and the braking curve's own check went red.
##
## WHAT THE FLOOR DID, BOTH WAYS, measured by lane/warbirds2 on the two kinds it binds hardest (2026-09-19):
##   P-51:  chatter 16.6 -> 0.1 a second, reversals 70 -> 10 a minute. The worst row in the fleet became an ordinary
##          one: for that aeroplane the incoherent demand was the WHOLE fault.
##   P-47:  chatter 1.4 -> 10.5, reversals 20 -> 61, and it still does not arrive. WORSE, and said so here rather than
##          left out: a coherent task is not a kinder one, and the Thunderbolt is now the only kind in the fleet that
##          fails a gym task. It closes 348 m of 2,266 in sixty seconds with the throttle between 0.60 and 1.00 and
##          never shut, which is not an aeroplane flying a leg badly, it is an aeroplane not flying the leg.
##
## WHO HAS TO RE-RECORD `tests/vehicle_gym_baseline.txt`, and it is more lanes than it first looks:
## - a lane that CHANGES A FLIGHT MODEL, which is the obvious one;
## - and a lane that ADDS A KIND, which is not. The Mustang landed on 2026-09-19 and the gym read 123 lines against the
##   118 saved: every one of the 118 identical, and five new ones that were the Mustang's. Adding a kind is a
##   re-record, not a failure -- and the READY says which lines are NEW and which MOVED, separately, so that a line
##   that moved cannot hide behind a line that was added.
##
## WHAT THE FIRST FULL RUN FOUND, 2026-09-19, and it is not what this lane expected:
## - NOBODY OVERSHOOTS. Flown from an established climb, every kind scores 0.000 to 0.008 on the level-off, and raising
##   the climb it is allowed does not change that -- the mixers ramp the climb down long before the height, and the
##   airframe is the limit anyway. That is the opposite of the guess: the pilots here are SLOW, not twitchy.
## - EIGHT FLIGHTS NEVER GET THERE, and seven of them are a speed gate. The five jets end the minute 5.6 to 5.8 m/s
##   high, the Hawkeye 3.6 and the tanker 2.0, and the airliner ends a waypoint leg 1,442 m short of a 2,186 m run.
## - AND THE SPEED GATE'S CAUSE IS THE LAST FIVE PER CENT OF THROTTLE. The jets' throttle ranges 0.00 to 0.06 and is
##   SHUT for only 7 to 12 per cent of the flight, and at 0.05 they still make enough thrust to hold their speed: they
##   shed 0.043 m/s^2 in the task against the 0.435 the same aeroplane sheds with the throttle actually closed. The
##   mixer cannot close it, because `AircraftMixer::step` adds the speed loop to a TYPED `throttle_trim = 0.45` -- the
##   same constant for every aeroplane in the game -- and the loop's integral authority is `ki x integral_limit`, which
##   is 0.008 x 20 = 0.16 of throttle. Given four minutes instead of one the tanker is still 17.2 m/s high and its
##   throttle has not moved at all. It is not slow convergence; it plateaus. `throttle_trim` is the envelope's first
##   customer: what holds cruise is the aeroplane's, not a constant.
## - THE JETS FLY PAST THE WAYPOINT by more than half the distance they were sent (overshoot 0.54, 850 m beyond after
##   the closest approach), which is the missing braking distance in one number.
## - THE HEAVIES BARELY TURN: the airliner manages 0.022 rad/s and the 747 0.054 against the 0.168 its 0.9 rad of bank
##   should buy at cruise -- 0.32 of it, which is `../todo/airport--747-turns-at-0.28.md` measured a second way.
## - THE GLIDER SHEDS NOTHING AND CLIMBS NOTHING, and tick by tick it lost 51 m/s in a second. See
##   `../todo/gliderlevel--the-gliders-polar-is-backwards.md`; it only flies the turn here, so nothing is sized from it.
## - FIVE JETS SHARE ONE SET OF NUMBERS to three decimal places (top 214-216 m/s, climb 7.27, turn 0.067-0.075): the
##   fighter, the Tomcat, the Falcon, the Prowler and the Lightning are one placeholder wearing five airframes.
##
## THE STICK ITSELF IS NOT SCORED HERE YET, AND THE READBACK NOW EXISTS. An AI vehicle has no cabin, so `crew_controls`
## is empty for it and `craft_controls` carries the throttle but not the pitch, roll and rudder the mixer just wrote.
## Throttle activity is therefore read directly and the stick's work is read through what it DID -- the reversals of
## the body rates it commanded. This doc block used to say a four-line readback of the autopilot's last `ControlInput`
## would make it direct; **lane/tracelog has since built exactly that** (`CockpitWorld::flight_controls`, on main: the
## stick an autopilot flew on its last tick, pitch/roll/rudder -1..1 and brake/throttle 0..1, read-only and outside
## rollback state).
##
## SWITCHING TO IT IS A DATED CHANGE AND NOT A FREE IMPROVEMENT, which is why it has not been done in passing:
## `reversals_per_min` and `chatter_per_s` would then count the STICK rather than the body's answer to it, so every
## line in the baseline moves and the two columns stop meaning what the recorded numbers mean. It belongs in one
## commit, with both readings taken on the same flights and the difference reported.
##
## THREE THINGS TO CHECK ON THE DAY IT IS SWITCHED, handed over by lane/tracelog who measured with it first:
## - `flight_controls` returns {} for a craft with no `AiPilot` record, so a task flown by a seated pilot reads
##   nothing. Every task here is AI-flown, so this is a check and not a problem -- but check it rather than assume it.
## - THE STICK IS STORED AFTER THE WORLD-EDGE TURN-BACK, so a craft turning at the edge of the world records the
##   EDGE's demand and not the pilot's. The gym flies in a bare world with a slab and steers at points up to 40 km
##   out; confirm no task ever reaches an edge before trusting a single stick number from one.
## - Their `hunt/s` and this suite's `reversals_per_min` are DIFFERENT MEASUREMENTS with similar-looking values: they
##   count crossings of a channel's own 2 s moving average past 5 per cent of its swing with a 0.02 floor; this counts
##   sign changes of a body rate past a 0.02 rad/s deadband. Do not put the two in one table without saying so.
##
## AND THE PROXY IS NOT LYING, which is worth recording before it is replaced. lane/tracelog measured the real stick on
## 15 kinds flying the test field at 60 Hz and got **0.00 to 0.06 hunts a second on every channel** -- the worst a
## Lightning's pitch at one crossing in 17 seconds. This suite, counting body rates with a different threshold and a
## different definition, also says the aircraft are quiet. **Two methods that share no arithmetic agreeing is worth
## more than either of them**, and it is the strongest evidence yet that "jerky and oscillating" is not the stick
## sawing: the pilots here are SLOW, not twitchy.
##
## THE 747 IS EXPECTED TO FAIL THE TURN AND TO KEEP FAILING until the heavies go onto lifting surfaces: it settles at
## about 0.28 of the turn rate its bank should give, which is the aeroplane and not the pilot. See
## `../todo/airport--747-turns-at-0.28.md`. DO NOT loosen its threshold to make the scoreboard look better; the number
## is there to be read.
##
## Read RESULT=.

const TICK: float = 1.0 / 120.0
## The island slab's half-width and depth, as `ground_stick.gd` lays it.
##
## CHECKED, NOT ASSUMED (2026-09-19, after lane/warbirds2 found two aeroplanes falling off the end of `climb.gd`'s
## slab and being clamped at the world's floor -- 106 and 132 seconds to height that were really 35.5 and 39.5). A jet
## on the flat-out flight covers 8.6 km in forty seconds and a task leg can run to 12.9, both of which leave a slab
## 7.2 km to a side. So the whole suite was re-run with the slab EIGHT TIMES WIDER: **not one of the 166 lines moved.**
## The aircraft are at height with `cruise_floor` off, so the ground under them decides nothing, and the taxi never
## goes near the edge. The number stays small because a bigger box is a bigger box.
const SLAB: float = 7200.0
## Where an aircraft is put for a task: high enough that nothing it does reaches the ground.
const AIR_HEIGHT: float = 900.0
const HOVER_HEIGHT: float = 60.0
## How far ahead a steer's point is put when the task is about a height or a speed and not about going anywhere.
const STRAIGHT_AHEAD: float = 40000.0
## How long a task is flown for, and how long each of the envelope's four flights at the limits is held.
const TASK_SECONDS: float = 60.0
const LIMIT_SECONDS: float = 40.0
## How long a craft is left to settle into the world before any limit is read off it.
const WARM_UP: float = 2.0
## How fast a taxi task rolls, metres a second: `AirportTraffic.TAXI_SPEED`, so the gym taxis at the speed the island's
## own traffic does.
const TAXI_SPEED: float = 8.5
## `AircraftMixer::slow_margin`, the multiple of the stall below which the mixer will not climb at all. See `_score`.
const SLOW_MARGIN: float = 1.30
## Below this the throttle counts as shut.
const SHUT: float = 0.05
## WHAT WAS RECORDED, read on a full run unless `--expect=` names another file. The scores are held against it, so a
## change that flies a kind worse fails -- and one that flies it BETTER fails too, until somebody records the better
## number on purpose. A scoreboard nobody has to update is a scoreboard nobody reads.
const BASELINE: String = "res://tests/vehicle_gym_baseline.txt"
## Inside a twentieth of the starting error counts as settled.
const SETTLED_SHARE: float = 0.05
## A body rate has to cross this to count as a reversal, so numerical noise about zero is not a hundred reversals.
const RATE_DEADBAND: float = 0.02
## AND A SECOND, FAR FINER BAND FOR CHATTER. lane/tracelog measured a taxiing Cessna's pitch rate crossing zero 14 times
## a SECOND at 0.01 to 0.02 rad/s on a body whose pitch never left -0.09 to +0.33 degrees -- ground contact making and
## breaking, not a controller fighting anything. Every one of those crossings is INSIDE `RATE_DEADBAND`, so the coarse
## count cannot see it: a deadband that keeps noise out of one number keeps the interesting noise out of it too.
const CHATTER_BAND: float = 0.002
const THROTTLE_DEADBAND: float = 0.002
## How much slack a measured limit is given before a demand counts as outside the envelope.
const FEASIBLE_MARGIN: float = 1.2
## What `--expect=` allows a score to move by before it is a regression: a share of the recorded value, and a floor for
## the small ones.
const EXPECT_SHARE: float = 0.25
const EXPECT_FLOOR: float = 0.5

var _failures: PackedStringArray = []
var _lines: Dictionary = {}
var _poor: PackedStringArray = []
var _never_arrived: PackedStringArray = []
var _card: TuningCard


func _check(label: String, ok: bool, detail: String) -> void:
	print("[vehicle_gym] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	_card = TuningCard.from_command_line()
	var only_kinds: PackedStringArray = []
	var only_tasks: PackedStringArray = []
	var write_to: String = ""
	var expect_from: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			only_kinds = arg.trim_prefix("--kind=").split(",", false)
		elif arg.begins_with("--task="):
			only_tasks = arg.trim_prefix("--task=").split(",", false)
		elif arg.begins_with("--write="):
			write_to = arg.trim_prefix("--write=")
		elif arg.begins_with("--expect="):
			expect_from = arg.trim_prefix("--expect=")
	var flown: int = 0
	for kind in range(Sim.Kind.size()):
		var name: String = Sim.kind_name(kind)
		if not only_kinds.is_empty() and not only_kinds.has(name):
			continue
		var geometry: Dictionary = Sim.geometry_of(kind)
		var model: int = int(geometry.get("model", -1))
		if not _is_flown(model) or not bool(geometry.get("pilotable", true)):
			continue
		flown += 1
		var envelope: Dictionary = _measure_envelope(kind, model)
		# THE STALL IS A WING'S. `handling()["stall_speed"]` runs the lift model whatever the kind is, and for a hull it
		# comes back as nonsense -- 939 m/s for the launch, 99,045 for the carrier -- so it is not printed for one. (The
		# waypoint floor was already gated on the winged models, which is why none of that reached a score.)
		var winged: bool = model == Sim.Model.AIRPLANE or model == Sim.Model.TILTROTOR
		print(("[vehicle_gym] %-12s envelope  stall %5.1f  cruise %5.1f  top %5.1f m/s  climb %5.2f m/s  "
				+ "decel %5.3f m/s2  turn %5.3f rad/s  radius %7.1f m = %5.2f lengths of %5.1f m") % [
				name, envelope["stall"] if winged else NAN, envelope["cruise"], envelope["top"], envelope["climb"],
				envelope["decel"], envelope["turn"], envelope["turn_radius"], envelope["turn_diameters"],
				envelope["length"]])
		for task in _tasks_of(kind, model):
			if not only_tasks.is_empty() and not only_tasks.has(task):
				continue
			_score(kind, model, task, envelope, {}, true)
		await get_tree().process_frame
	_check("every_kind_was_put_through_the_gym", flown > 0, "%d kinds, %d scored flights" % [flown, _lines.size()])
	_the_braking_curve_arrives_closer_than_the_host_that_waits()
	if only_kinds.is_empty():
		_a_stiffer_loop_shows_up_as_control_activity()
		_a_fin_that_will_not_hold_shows_up_as_settling()
	if not _never_arrived.is_empty():
		print("[vehicle_gym] DID NOT GET THERE AT ALL, %d of them:" % _never_arrived.size())
		for line in _never_arrived:
			print("[vehicle_gym]   %s" % line)
	if not _poor.is_empty():
		print("[vehicle_gym] KNOWN POOR, %d of them, printed and not hidden:" % _poor.size())
		for line in _poor:
			print("[vehicle_gym]   %s" % line)
	if not write_to.is_empty():
		_write(write_to)
	if expect_from.is_empty() and only_kinds.is_empty() and only_tasks.is_empty() 			and FileAccess.file_exists(BASELINE):
		expect_from = BASELINE
	if not expect_from.is_empty():
		_compare(expect_from)
	_finish()


## Which movement models are put through the gym. The pilots this is about fly, hover or float; a train is on rails, a
## tower does not move, a brig is sailed by a different mixer on a different plan, and a car and a segway are steered
## rather than flown. Each of those is a gym of its own if anybody wants one.
func _is_flown(model: int) -> bool:
	return model == Sim.Model.AIRPLANE or model == Sim.Model.TILTROTOR \
		or model == Sim.Model.HELICOPTER or model == Sim.Model.BOAT


## Which tasks a kind is given. A glider has no throttle, so a speed gate and a climb are not tasks it can be set; it is
## given the turn, which is the one thing its pilot does decide. A boat has no altitude.
func _tasks_of(kind: int, model: int) -> PackedStringArray:
	if kind == Sim.Kind.GLIDER:
		return ["turn_to_bearing"]
	match model:
		Sim.Model.AIRPLANE, Sim.Model.TILTROTOR:
			return ["level_off", "climb_beyond", "speed_gate", "turn_to_bearing", "waypoint",
				"arrive_at_speed", "arrive_planned", "taxi"]
		Sim.Model.HELICOPTER:
			return ["level_off", "climb_beyond", "turn_to_bearing", "hover_to_point", "hover_climb"]
		_:
			return ["speed_gate", "turn_to_bearing"]


## ---- the envelope, measured ---------------------------------------------------------------

## WHAT THIS KIND MANAGES, flown rather than typed. Four flights at the limits: everything it has toward a point far
## enough away that it never arrives; everything it has into a climb it cannot finish; the throttle closed from cruise;
## and a turn onto a bearing square to the one it is on. What comes back is the best the aircraft and its autopilot
## managed together, which is what a flight test measures and is the number the tasks are then SIZED from -- a task no
## kind could do would score every kind the same and tell us nothing.
func _measure_envelope(kind: int, model: int) -> Dictionary:
	var speeds: Dictionary = _speeds_of(kind)
	var cruise: float = float(speeds["cruise"])
	var height: float = _start_height(model)
	var flat_out: Dictionary = _fly(kind, model, LIMIT_SECONDS, {
		"toward": Vector3(0.0, 0.0, -STRAIGHT_AHEAD), "altitude": height, "speed": cruise * 4.0}, {})
	var climbing: Dictionary = _fly(kind, model, LIMIT_SECONDS, {
		"toward": Vector3(0.0, 0.0, -STRAIGHT_AHEAD), "altitude": height + 3000.0, "speed": cruise}, {})
	var slowing: Dictionary = _fly(kind, model, LIMIT_SECONDS, {
		"toward": Vector3(0.0, 0.0, -STRAIGHT_AHEAD), "altitude": height, "speed": cruise * 0.35}, {})
	var turning: Dictionary = _fly(kind, model, LIMIT_SECONDS, {
		"toward": Vector3(STRAIGHT_AHEAD, height, 0.0), "altitude": height, "speed": cruise}, {})
	# THE TURN AS A HULL'S OWN BOOK QUOTES IT. A ship's turn is published as a TACTICAL DIAMETER in ship lengths --
	# three to four for a loaded box boat -- and never as radians a second, so a rate is not a number anybody can check
	# against a source. Handed over for lane/seaport, whose brief names this suite and `../todo/airport--747-turns-at-
	# 0.28.md` as the warning: a craft that turns at a third of its book is the fault we already have, and they are
	# adding hulls. Printed with the envelope and NOT recorded, so nobody re-records a baseline for it.
	var rate: float = float(turning["peak_turn"])
	var at_speed: float = maxf(float(turning["turning_at"]), 0.1)
	var radius: float = at_speed / maxf(rate, 1e-4)
	var length: float = 2.0 * float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).z)
	return {
		"turn_radius": radius,
		"length": length,
		"turn_diameters": 2.0 * radius / maxf(length, 0.1),
		"cruise": cruise,
		# THE STALL, ASKED OF THE MODEL, not measured and not typed: `handling()` derives it from the lift model beside
		# the cruise, and says so ("the two derived speeds, which are not settings").
		"stall": float(speeds["stall"]),
		"top": float(flat_out["top_speed"]),
		"climb": maxf(float(climbing["best_climb"]), 0.0),
		# What it sheds a second at idle, averaged over every second of the slowing flight the throttle was shut.
		"decel": maxf(float(slowing["shed_at_idle"]), 0.0),
		"turn": float(turning["peak_turn"]),
	}


## THE TWO SPEEDS THE MODEL DERIVES: the cruise it flies at and the stall beneath it.
##
## A NOTE FOR ANYBODY RETUNING EITHER: `--set=cruise=` reaches this, but `cruise_over` CLAMPS what it is given -- down
## to the 70 m/s formation cap and up to 1.45 times the stall -- so a kind already against a clamp cannot be moved that
## way and it reads like a knob that does nothing (lane/warbirds2, 2026-09-19; measured in `../agents.md`). The stall
## cannot be set at all: it is derived from the lift model.
func _speeds_of(kind: int) -> Dictionary:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.start(0)
	_card.apply_to(world, kind)
	var h: Dictionary = world.handling(kind)
	var out := {"cruise": float(h.get("cruise", 40.0)), "stall": float(h.get("stall_speed", 0.0))}
	world.teardown()
	return out


func _start_height(model: int) -> float:
	if model == Sim.Model.BOAT:
		return 0.5
	if model == Sim.Model.HELICOPTER:
		return HOVER_HEIGHT
	return AIR_HEIGHT


## ---- the tasks ----------------------------------------------------------------------------

## ONE TASK, FLOWN AND SCORED.
##
## EVERY TASK IS SIZED FROM THE MEASURED ENVELOPE, and that is the difference between a gym and a pass/fail gate. Asked
## for three hundred metres in a minute, a Cessna scores nothing at all -- it never gets there, so there is no overshoot
## to read and no settle to time, and the same flat zero comes back for a fighter that would have made it in eight
## seconds. Asked instead for a THIRD of the climb it was measured to hold, every kind is worked equally hard and the
## scores compare.
##
## `record` is false for a mutant run, which is flown for comparison and does not belong in the table.
func _score(kind: int, model: int, task: String, envelope: Dictionary, manners: Dictionary,
		record: bool, tune: Dictionary = {}) -> Dictionary:
	var name: String = Sim.kind_name(kind)
	var cruise: float = float(envelope["cruise"])
	var climb: float = float(envelope["climb"])
	var decel: float = float(envelope["decel"])
	# THE SLOWEST A TASK THAT ALSO ASKS FOR HEIGHT MAY ASK FOR, and it applies to the `waypoint` task alone because
	# that is the only one that asks for a place, a height AND a speed together.
	#
	# `AircraftMixer::slow_margin` is 1.30: at that multiple of the stall the mixer allows NO climb, and below it the
	# ceiling it allows is a DESCENT. A task asking for less than that while also asking for height is telling the
	# autopilot to climb and refusing it permission in the same breath. TWO KINDS WERE: the 747 and the Warthog were
	# both sent to a waypoint at 0.8 of a cruise that works out at **1.16 times their stall**.
	#
	# NOT APPLIED TO THE LEVEL TASKS. A speed gate or an arrival flown at 1.16 of the stall is a slow aeroplane in
	# level flight, which is a thing aeroplanes do; flooring those as well shrank the arrival task until there was
	# nothing left to slow for, and the braking curve's own check went red because both hosts had the same trivial job.
	# A floor put in to make a task honest must not be put anywhere it makes a task empty.
	#
	# 1.30 is TYPED HERE, which is the one number in this suite that is, because `slow_margin` lives on the mixer and
	# `handling()` does not report it. It belongs in `envelope(kind)` when that lands in C++.
	# AND NOT AT THE MARGIN ITSELF, HALF WAY UP FROM IT. The mixer's climb allowance FADES: the whole of it at cruise,
	# NONE of it at `slow_margin`, so a floor set exactly there buys an aeroplane nothing. Half way from the margin to
	# the cruise is about half the climb, and it reproduces today's speed on every kind whose cruise is a proper 1.45
	# times its stall (the Cessna: 45.3 m/s either way). It binds only where the cruise is lower than the design --
	# which is the 747, the Warthog and the warbirds on lane/warbirds2's formation cap.
	var slow: float = SLOW_MARGIN * float(envelope.get("stall", 0.0)) 		if model == Sim.Model.AIRPLANE or model == Sim.Model.TILTROTOR else 0.0
	var floor_speed: float = slow + 0.5 * maxf(cruise - slow, 0.0)
	var height: float = _start_height(model)
	var seconds: float = TASK_SECONDS
	var steer: Dictionary = {}
	var watch: String = ""
	var target: float = 0.0
	var demand: Dictionary = {}
	# A task set on purpose beyond what the kind can do, to see the pilot say so rather than stall trying.
	var impossible: bool = false
	# ALREADY GOING UP when the task starts, where the task is about stopping: a level-off flown from level flight is not
	# a level-off, and the first run of this gym scored every kind 0.000 for overshoot because none of them was climbing.
	var start_climb: float = 0.0
	# HOW THE HOST RE-STEERS while the flight runs, where the task is about a host that thinks: see `_fly`.
	var policy: Dictionary = {}
	# ON ITS WHEELS ON THE SLAB, rather than in the air: the ground tasks.
	var on_wheels: bool = false
	match task:
		"level_off":
			# UP A THIRD OF THE CLIMB IT HAS, and hold it. The plainest possible anticipation test: one number to
			# reach, and nothing else asked for.
			var gain: float = clampf(climb * seconds * 0.30, 30.0, 900.0)
			steer = {"toward": Vector3(0.0, 0.0, -STRAIGHT_AHEAD), "altitude": height + gain, "speed": cruise}
			watch = "altitude"
			target = height + gain
			start_climb = climb
			demand = {"needs": gain / (seconds * 0.5), "has": climb, "what": "climb"}
		"climb_beyond":
			# THREE TIMES THE CLIMB IT HAS, which nothing can do. The right answer is to climb at its best and arrive
			# late; the wrong one is to pitch up until it stops flying. The brief asks for this case by name.
			var reach: float = maxf(climb, 0.5) * seconds * 3.0
			steer = {"toward": Vector3(0.0, 0.0, -STRAIGHT_AHEAD), "altitude": height + reach, "speed": cruise}
			watch = "altitude"
			target = height + reach
			impossible = true
			demand = {"needs": reach / (seconds * 0.5), "has": climb, "what": "climb"}
		"speed_gate":
			# SLOW BY WHAT IT CAN SHED IN A QUARTER OF THE RUN, at height. A jumbo's answer to this is the user's
			# second example, and the distance it takes is the number that example is about.
			var shed: float = clampf(decel * seconds * 0.25, cruise * 0.12, cruise * 0.45)
			steer = {"toward": Vector3(0.0, 0.0, -STRAIGHT_AHEAD), "altitude": height, "speed": cruise - shed}
			watch = "speed"
			target = cruise - shed
			demand = {"needs": shed / (seconds * 0.5), "has": decel, "what": "decel"}
		"turn_to_bearing":
			# NINETY DEGREES RIGHT, onto a point far enough off that the bearing barely moves while it turns.
			steer = {"toward": Vector3(STRAIGHT_AHEAD, height, 0.0), "altitude": height, "speed": cruise}
			watch = "bearing"
			target = 0.0
			demand = {"needs": 0.0, "has": float(envelope["turn"]), "what": "turn"}
		"waypoint":
			# EVERYTHING AT ONCE: a place, a height and a speed, which is what a route leg actually asks for. Half an
			# run's flying away, so there is time to be there AND be right when it arrives.
			var reach: float = maxf(cruise, 4.0) * seconds * 0.5
			var gain: float = clampf(climb * seconds * 0.20, 20.0, 600.0)
			steer = {"toward": Vector3(reach * 0.87, height + gain, -reach * 0.5),
				"altitude": height + gain, "speed": maxf(cruise * 0.8, floor_speed)}
			watch = "range"
			target = 0.0
			demand = {"needs": gain / (seconds * 0.5), "has": climb, "what": "climb"}
		"arrive_at_speed", "arrive_planned":
			# BE AT A PLACE, AT A SPEED. The one thing today's pilots have no way to do: there is no lever for "slow
			# down in time", so the host either flies the leg fast and slams the speed at the end or flies the whole leg
			# slow. Both tasks are the same flight; what differs is the host.
			#   arrive_at_speed -- WHAT A HOST DOES TODAY: cruise, then the arrival speed inside the autopilot's own
			#     arrival radius (`kArrived`, a flat 220 m for everything).
			#   arrive_planned  -- THE BRAKING CURVE: `v = sqrt(arrive^2 + 2 a d)` on the range now, re-steered on the
			#     rota's own interval, planned on three quarters of the deceleration the kind was MEASURED to have.
			var run: float = maxf(cruise, 4.0) * seconds * 0.65
			var arrive: float = cruise * 0.55
			steer = {"toward": Vector3(0.0, height, -run), "altitude": height, "speed": cruise}
			watch = "range"
			target = 0.0
			policy = {"arrive": arrive, "cruise": cruise, "decel": decel,
				"naive_at": 220.0 if task == "arrive_at_speed" else 0.0}
			demand = {"needs": (cruise - arrive) / (seconds * 0.5), "has": decel, "what": "decel"}
		"taxi":
			# ROLLING, NOT FLYING, and the only task that touches the ground. lane/tracelog measured a taxiing Cessna's
			# pitch rate crossing zero 14 times a second, and the tricycles going onto their own wheels will either damp
			# that or make it worse. ON THE SLAB, which is flat and seamless on purpose: what is measured here is the
			# WHEEL MODEL's own chatter, contact making and breaking, with no terrain seam to confuse it.
			seconds = 40.0
			steer = {"toward": Vector3(0.0, height, -600.0), "altitude": height, "speed": TAXI_SPEED,
				"wheels": "taxi"}
			watch = "speed"
			target = TAXI_SPEED
			on_wheels = true
			demand = {"needs": 0.0, "has": 1.0, "what": "taxi"}
		"hover_to_point":
			steer = {"toward": Vector3(0.0, height, -600.0), "altitude": height, "speed": 12.0}
			watch = "range"
			target = 0.0
			demand = {"needs": 0.0, "has": float(envelope["top"]), "what": "speed"}
		"hover_climb":
			var gain: float = clampf(climb * seconds * 0.30, 20.0, 400.0)
			steer = {"toward": Vector3(0.0, height + gain, -1200.0), "altitude": height + gain, "speed": 6.0}
			watch = "altitude"
			target = height + gain
			demand = {"needs": gain / (seconds * 0.5), "has": climb, "what": "climb"}
	var flight: Dictionary = _fly(kind, model, seconds, steer, manners, watch, target, tune, start_climb, policy,
		on_wheels)
	if flight.is_empty():
		if record:
			_check("%s_%s_could_be_flown" % [name, task], false, "it could not be spawned")
		return {}
	var start_error: float = float(flight["start_error"])
	var overshoot: float = float(flight["overshoot"]) / maxf(start_error, 1e-3)
	var honesty: String = _honesty(demand, flight)
	var scores: Dictionary = {
		"overshoot": overshoot,
		"settle": float(flight["settle"]),
		"steady": float(flight["steady"]),
		"throttle_per_s": float(flight["throttle_moved"]) / seconds,
		"shut_pct": 100.0 * float(flight["shut_share"]),
		# HOW FAST IT WAS WHEN IT GOT THERE, against how fast it was asked to be: 0 for a task with no arrival speed.
		"arrive_err": (absf(float(flight["speed_at_closest"]) - float(policy["arrive"]))
			if policy.has("arrive") else 0.0),
		"reversals_per_min": float(flight["reversals"]) * 60.0 / seconds,
		"chatter_per_s": float(flight["chatter"]) / seconds,
		"honesty": honesty,
		"finite": bool(flight["finite"]),
		"arrived": bool(flight["arrived"]),
	}
	if not record:
		return scores
	var line: String = ("%s %s overshoot=%.3f settle=%.1f steady=%.3f throttle_per_s=%.4f shut_pct=%.0f "
		+ "reversals_per_min=%.1f chatter_per_s=%.1f arrive_err=%.2f %s %s") % [
		name, task, scores["overshoot"], scores["settle"], scores["steady"], scores["throttle_per_s"],
		scores["shut_pct"], scores["reversals_per_min"], scores["chatter_per_s"], scores["arrive_err"], honesty,
		"arrived" if bool(scores["arrived"]) else "DID_NOT_ARRIVE"]
	_lines["%s %s" % [name, task]] = line
	print("[vehicle_gym] %s" % line)
	if not bool(scores["finite"]):
		_check("%s_%s_scores_are_finite" % [name, task], false, line)
	if not impossible and not bool(scores["arrived"]):
		_never_arrived.append("%s -- %s" % [line, flight.get("why", "")])
	if impossible and honesty.begins_with("did"):
		_check("%s_%s_was_asked_for_more_than_it_has" % [name, task], false,
			"it reports having done a climb of %.1f m/s, three times its measured %.2f: %s"
				% [float(demand["needs"]), climb, line])
	if honesty == "FAILED" or overshoot > 0.5 or float(scores["reversals_per_min"]) > 60.0:
		_poor.append(line)
	return scores



## THE THREE WORDS. A demand the envelope covers and the flight met is `did`; one the envelope does not cover and the
## flight did not meet is `refused`, which is the honest answer and not a fault; one the envelope covers and the flight
## missed anyway is `FAILED`, and that one is the pilot's.
func _honesty(demand: Dictionary, flight: Dictionary) -> String:
	var needs: float = float(demand.get("needs", 0.0))
	var has: float = float(demand.get("has", 0.0))
	var arrived: bool = bool(flight["arrived"])
	if needs <= 0.0:
		return "did" if arrived else "FAILED"
	if needs * FEASIBLE_MARGIN > has:
		return "refused" if not arrived else "did(beyond_measured_%s)" % demand.get("what", "?")
	return "did" if arrived else "FAILED"


## ---- one flight ---------------------------------------------------------------------------

## ONE FLIGHT IN A WORLD OF ITS OWN. Spawns the kind for the autopilot, steers it once, ticks, and watches. `watch` is
## what the task's error is measured on; with it empty the flight is one of the envelope's and only the limits matter.
func _fly(kind: int, model: int, seconds: float, steer: Dictionary, manners: Dictionary,
		watch: String = "", target: float = 0.0, tune: Dictionary = {}, start_climb: float = 0.0,
		policy: Dictionary = {}, on_wheels: bool = false) -> Dictionary:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.set_crashes(false)
	_card.apply_to(world, kind)
	if not tune.is_empty():
		var was: Dictionary = world.handling(kind)
		var tuned: Dictionary = {}
		for key in tune:
			tuned[key] = float(was.get(key, 0.0)) * float(tune[key])
		world.set_handling(kind, tuned)
	var cruise: float = float(world.handling(kind).get("cruise", 40.0))
	var height: float = _start_height(model)
	var at := Vector3(0.0, height, 0.0)
	var velocity := Vector3.ZERO
	if on_wheels:
		at.y = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y) + 0.05
	if on_wheels:
		velocity = Vector3.ZERO
	elif model == Sim.Model.AIRPLANE or model == Sim.Model.TILTROTOR:
		velocity = Vector3(0.0, 0.0, -cruise)
	elif model == Sim.Model.BOAT:
		velocity = Vector3(0.0, 0.0, -cruise * 0.5)
	velocity.y = start_climb
	if on_wheels or model != Sim.Model.BOAT:
		world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(SLAB, 400.0, SLAB))
	var craft: int = int(world.spawn_ai_vehicle(kind, at, 0.0, velocity))
	if craft == 0:
		world.teardown()
		return {}
	# Every key given, with its default where it does not apply (CLAUDE.md rule 8): a key left out keeps whatever an
	# earlier steer set, and a gym that leaked one task's steer into the next would score the wrong flight.
	var full: Dictionary = {"toward": Vector3.ZERO, "altitude": height, "speed": cruise, "wheels": "fly",
		"cruise_floor": false, "bank": 0.0, "approach": false}
	for key in steer:
		full[key] = steer[key]
	world.steer_ai(craft, full)
	if not manners.is_empty():
		world.set_ai_manners(craft, manners)
	var toward: Vector3 = full["toward"]

	var ticks: int = int(round(seconds / TICK))
	var start_signed: float = 0.0
	var overshoot: float = 0.0
	var settle: float = -1.0
	var last_outside: float = 0.0
	var steady_sum: float = 0.0
	var steady_count: int = 0
	var top_speed: float = 0.0
	var best_climb: float = -1e9
	var shed_sum: float = 0.0
	var shed_count: int = 0
	var peak_turn: float = 0.0
	var turning_at: float = 0.0
	var closest: float = 1e9
	var at_closest: float = 0.0
	var throttle_moved: float = 0.0
	var throttle_low: float = 2.0
	var throttle_high: float = -1.0
	# How long the throttle was shut, which is what says whether a craft that did not slow down was REFUSING to close it
	# or had closed it and still could not.
	var shut_ticks: int = 0
	var reversals: int = 0
	var was_throttle: float = -1.0
	# The last direction each control was moving, so a change of sign is a reversal: throttle, roll rate, pitch rate.
	var ways := Vector3i.ZERO
	var fine_way: int = 0
	var chatter: int = 0
	var was_speed: float = -1.0
	var was_height: float = 0.0
	var was_heading: float = 0.0
	var finite: bool = true
	# HOW OFTEN A HOST RE-STEERS, in ticks: `AirportTraffic.THINK_TICKS`, so a planner scored here is thinking exactly
	# as often as the one flying the island's traffic.
	const THINK: int = 12
	for i in range(ticks):
		if not policy.is_empty() and i % THINK == 0:
			var here: Dictionary = world.vehicle_state(craft)
			var flat: Vector3 = toward - (here.get("position", Vector3.ZERO) as Vector3)
			flat.y = 0.0
			var left: float = flat.length()
			var arrive: float = float(policy["arrive"])
			var ask: float = arrive
			if float(policy.get("naive_at", 0.0)) > 0.0:
				# WHAT A HOST DOES TODAY: fly the leg at cruise and ask for the arrival speed once the point is inside
				# the autopilot's own arrival radius, `CockpitWorld::kArrived`, which is a flat 220 m for a Cessna and a
				# 747 alike -- four seconds of flying for one and a second and a half for the other.
				ask = arrive if left < float(policy["naive_at"]) else float(policy["cruise"])
			else:
				ask = BrakingCurve.speed_for(left, arrive, float(policy["decel"]), float(policy["cruise"]))
			full["speed"] = ask
			world.steer_ai(craft, full)
		world.tick(TICK)
		var s: Dictionary = world.vehicle_state(craft)
		var p: Vector3 = s.get("position", Vector3.ZERO)
		var v: Vector3 = s.get("velocity", Vector3.ZERO)
		var w: Vector3 = s.get("spin", Vector3.ZERO)
		var q: Quaternion = s.get("basis", Quaternion())
		var t: float = float(i + 1) * TICK
		if not (is_finite(p.y) and is_finite(v.x) and is_finite(w.x)):
			finite = false
			break
		var basis := Basis(q)
		var speed: float = v.length()
		top_speed = maxf(top_speed, speed)
		var throttle: float = float(world.craft_controls(craft).get("throttle", 0.0))
		if t > WARM_UP:
			throttle_low = minf(throttle_low, throttle)
			throttle_high = maxf(throttle_high, throttle)
			if throttle < SHUT:
				shut_ticks += 1
		# OVER A SECOND, NEVER OVER A TICK. Measured tick by tick, the light twin's "deceleration" came back as 19.96
		# m/s^2 and the glider's as 2,567: a spawn transient and a surface stepping is not a limit anything can plan on,
		# and an envelope built from spikes made every demand look feasible -- which is how the jumbo's speed gate was
		# scored the pilot's fault when no aeroplane could have made it.
		if i % 120 == 119:
			# AND NOT THE FIRST TWO SECONDS. A craft is dropped into the world at a velocity the model has not settled
			# into yet, and the glider's "deceleration" over that first second came back as 51 m/s^2.
			if was_speed >= 0.0 and t > WARM_UP:
				best_climb = maxf(best_climb, p.y - was_height)
				# AND ONLY WHILE THE THROTTLE IS SHUT, AVERAGED, NEVER THE BEST SECOND. What a plan can spend is what
				# the aeroplane sheds at idle over the whole slowing, not its best moment: drag goes with the square of
				# the speed, so the best second is always the first one and it overstates what is left near the target.
				# The fighter's best second says 0.517 m/s^2 and what it actually manages is 0.043 -- twelve times out,
				# which is the difference between a demand the envelope calls possible and one it calls impossible.
				if throttle < SHUT:
					shed_sum += was_speed - speed
					shed_count += 1
				var swung: float = absf(wrapf(atan2(v.x, -v.z) - was_heading, -PI, PI))
				if swung > peak_turn:
					peak_turn = swung
					# AND HOW FAST IT WAS GOING WHILE IT SWUNG, which is the speed a turn radius is worked out from. The
					# flight's top speed is the wrong one: a hull loses way in a turn, so using it overstates the radius
					# and flatters the craft.
					turning_at = speed
			was_speed = speed
			was_height = p.y
			was_heading = atan2(v.x, -v.z)

		# THE CONTROLS, as far as an AI vehicle shows them: the throttle directly (read above, because the limits need
		# it), and the stick's work through the body rates it commanded.
		if was_throttle >= 0.0:
			var step: float = throttle - was_throttle
			throttle_moved += absf(step)
			var way: int = 0 if absf(step) < THROTTLE_DEADBAND else (1 if step > 0.0 else -1)
			if way != 0:
				if ways.x != 0 and way != ways.x:
					reversals += 1
				ways.x = way
		was_throttle = throttle
		var roll_way: int = _way(w.dot(-basis.z), RATE_DEADBAND)
		if roll_way != 0:
			if ways.y != 0 and roll_way != ways.y:
				reversals += 1
			ways.y = roll_way
		var pitch: float = w.dot(basis.x)
		var pitch_way: int = _way(pitch, RATE_DEADBAND)
		if pitch_way != 0:
			if ways.z != 0 and pitch_way != ways.z:
				reversals += 1
			ways.z = pitch_way
		# CHATTER: the same crossings counted a hundredth as coarsely, which is where ground contact lives.
		var fine: int = _way(pitch, CHATTER_BAND)
		if fine != 0:
			if fine_way != 0 and fine != fine_way:
				chatter += 1
			fine_way = fine

		if watch != "":
			var error: float = _error_now(watch, p, v, basis, toward, target)
			if i == 0:
				start_signed = error
			elif start_signed != 0.0:
				# Past the target and out the other side, measured in the direction the error started in.
				overshoot = maxf(overshoot, -error * signf(start_signed))
			if absf(error) < closest:
				closest = absf(error)
				at_closest = speed
			if absf(error) > SETTLED_SHARE * maxf(absf(start_signed), 1e-3):
				last_outside = t
			if t > seconds * 0.75:
				steady_sum += absf(error)
				steady_count += 1
	var final: Dictionary = world.vehicle_state(craft)
	var end_error: float = 0.0
	if watch != "":
		var fp: Vector3 = final.get("position", Vector3.ZERO)
		var fv: Vector3 = final.get("velocity", Vector3.ZERO)
		end_error = absf(_error_now(watch, fp, fv, Basis(final.get("basis", Quaternion())), toward, target))
	world.teardown()
	settle = last_outside if last_outside < seconds - 1.0 else -1.0
	if watch == "range":
		# GOING PAST IT is what overshoot means when the error is a distance: how far it was beyond the point at the
		# end, against how close it ever got. A flight that stopped on the point has none.
		overshoot = maxf(0.0, end_error - closest)
	return {
		"start_error": absf(start_signed),
		"overshoot": maxf(overshoot, 0.0),
		"settle": settle,
		"steady": steady_sum / maxf(float(steady_count), 1.0),
		"top_speed": top_speed,
		"best_climb": best_climb,
		"shed_at_idle": shed_sum / maxf(float(shed_count), 1.0),
		"shut_seconds": shed_count,
		"peak_turn": peak_turn,
		"turning_at": turning_at,
		"closest": closest,
		"speed_at_closest": at_closest,
		"throttle_moved": throttle_moved,
		"throttle_low": throttle_low if throttle_high >= 0.0 else 0.0,
		"throttle_high": maxf(throttle_high, 0.0),
		"shut_share": float(shut_ticks) / maxf(float(ticks), 1.0),
		"reversals": reversals,
		"chatter": chatter,
		"finite": finite,
		"arrived": finite and _arrived(watch, absf(start_signed), end_error, closest),
		"why": "start %.1f end %.1f closest %.1f, throttle %.2f to %.2f, shut for %.0f%% of it"
			% [absf(start_signed), end_error, closest, throttle_low if throttle_high >= 0.0 else 0.0,
			maxf(throttle_high, 0.0), 100.0 * float(shut_ticks) / maxf(float(ticks), 1.0)],
	}


## Which way a number is moving, with a deadband so that noise about zero is not a reversal a tick.
func _way(rate: float, deadband: float) -> int:
	if absf(rate) < deadband:
		return 0
	return 1 if rate > 0.0 else -1


## THE TASK'S ERROR, NOW. Signed where a sign means something, because overshoot is the error coming out the far side.
func _error_now(watch: String, p: Vector3, v: Vector3, basis: Basis, toward: Vector3, target: float) -> float:
	match watch:
		"altitude":
			return p.y - target
		"speed":
			return v.length() - target
		"bearing":
			# Where it is pointed against where the point is, as a compass angle: 0 along -Z, increasing to the right.
			# The TRACK while it is moving, because that is what takes it somewhere; the nose while it is not.
			var going: Vector3 = v if v.length() > 2.0 else -basis.z
			var heading: float = atan2(going.x, -going.z)
			var to: Vector3 = toward - p
			var bearing: float = atan2(to.x, -to.z)
			return wrapf(bearing - heading, -PI, PI)
		_:
			var flat: Vector3 = toward - p
			flat.y = 0.0
			return flat.length() - target


## WHETHER IT GOT THERE IN THE END, loosely: the scores above are what is interesting, and this is the floor beneath
## them that a guidance change cannot quietly go through.
func _arrived(watch: String, start_error: float, end_error: float, closest: float) -> bool:
	match watch:
		"":
			return true
		"bearing":
			return end_error <= deg_to_rad(30.0)
		"range":
			return closest <= maxf(0.1 * start_error, 40.0)
		_:
			return end_error <= 0.25 * maxf(start_error, 1e-3)


## THE CURVE EARNS ITS PLACE, ON EVERY KIND THAT FLIES ONE. `arrive_at_speed` and `arrive_planned` are the same flight
## with a different host: one asks for the arrival speed when the point is inside the autopilot's own arrival radius, as
## every host here does today, and the other steers the braking curve on the range now. The curve has to arrive NEARER
## the speed it was asked for, on every kind, or it is not worth the file.
##
## Measured when it landed: the Cessna 14.19 m/s out becomes 0.41, the fighter 34.97 becomes 11.36, the 747 31.54
## becomes 20.72 (its deceleration genuinely is not there -- see the throttle finding). And it is quieter as well as
## nearer: the fighter's reversals a minute fall from 36 to 9 and its throttle movement from 0.0218 to 0.0017, because a
## setpoint that slides does not kick the loop the way a setpoint that steps does.
func _the_braking_curve_arrives_closer_than_the_host_that_waits() -> void:
	var worse: PackedStringArray = []
	var pairs: int = 0
	var saved: float = 0.0
	for key in _lines:
		if not String(key).ends_with(" arrive_at_speed"):
			continue
		var kind: String = String(key).split(" ")[0]
		var planned_key: String = "%s arrive_planned" % kind
		if not _lines.has(planned_key):
			continue
		pairs += 1
		var waits: float = float(_fields(String(_lines[key])).get("arrive_err", 0.0))
		var plans: float = float(_fields(String(_lines[planned_key])).get("arrive_err", 0.0))
		saved += waits - plans
		if plans > waits:
			worse.append("%s %.2f waiting, %.2f planning" % [kind, waits, plans])
	if pairs == 0:
		# NOT FLOWN IS NOT FAILED. Under `--task=` or `--kind=` the pair may not have been run at all, and a check that
		# goes red because it was filtered out is a false red -- which this printed the first time somebody asked the
		# suite for one task (2026-09-19, measuring the ships' turning circles for lane/seaport).
		print("[vehicle_gym] SKIP the_braking_curve_arrives_closer_than_the_host_that_waits (no arrival pair was flown)")
		return
	_check("the_braking_curve_arrives_closer_than_the_host_that_waits", worse.is_empty(),
		"%d kinds, %.1f m/s of arrival error saved between them%s"
			% [pairs, saved, "" if worse.is_empty() else ": %s" % worse])


## ---- the mutants ---------------------------------------------------------------------------

## A LOOP ASKED TO BE STIFFER HUNTS, AND THE SCOREBOARD MUST SEE IT. `control_authority` is the gain of the rate servo
## the stick's demand goes through, and a loop with four times the gain it was tuned with chases its own overshoot: that
## is oscillation, and oscillation is what the user is describing. If the reversals a minute do not rise, control
## activity is not measuring anything and the rest of this suite is decoration.
##
## The stick itself is not readable on an AI vehicle (see the header), so what is counted is the work the stick did --
## the reversals of the body rates it commanded -- and this mutant is the check that the one stands in for the other.
func _a_stiffer_loop_shows_up_as_control_activity() -> void:
	var kind: int = Sim.Kind.CESSNA
	var envelope: Dictionary = _measure_envelope(kind, Sim.Model.AIRPLANE)
	var steady: Dictionary = _score(kind, Sim.Model.AIRPLANE, "turn_to_bearing", envelope, {}, false)
	var twitchy: Dictionary = _score(kind, Sim.Model.AIRPLANE, "turn_to_bearing", envelope, {}, false,
		{"pitch_rate": 4.0})
	var was: float = float(steady.get("reversals_per_min", 0.0))
	var now: float = float(twitchy.get("reversals_per_min", 0.0))
	_check("a_stiffer_loop_shows_up_as_control_activity", now > was + 1.0,
		"%.1f reversals a minute as built, %.1f at four times the demanded pitch rate" % [was, now])


## AN AEROPLANE THAT WILL NOT HOLD A HEADING TAKES LONGER TO SETTLE, AND DOES NOT GET THERE. `weathervane` is the fin's
## pull toward the airflow, and at a twentieth of it the light twin's turn settles in 54.5 seconds instead of 23.9 and
## leaves a standing error of 0.092 radians against 0.002. If those two do not move, settling time and steady error are
## not measuring the flying and the scoreboard is decoration.
##
## WHY NOT AN OVERSHOOT MUTANT, which is what this lane expected to write: because nothing overshoots. Every kind in the
## fleet scores 0.000 to 0.008 on the level-off, flown from an established climb, and raising the climb it is allowed
## does not change that -- the mixers ramp the climb down long before the height, and the airframe is the limit anyway.
## That is a real finding and it is the opposite of the guess: the pilots here are SLOW, not twitchy. What they do
## instead is fail to arrive, which is the block this suite prints and holds.
func _a_fin_that_will_not_hold_shows_up_as_settling() -> void:
	var kind: int = Sim.Kind.PLANE
	var envelope: Dictionary = _measure_envelope(kind, Sim.Model.AIRPLANE)
	var steady: Dictionary = _score(kind, Sim.Model.AIRPLANE, "turn_to_bearing", envelope, {}, false)
	var loose: Dictionary = _score(kind, Sim.Model.AIRPLANE, "turn_to_bearing", envelope, {}, false,
		{"weathervane": 0.05})
	var was_settle: float = float(steady.get("settle", 0.0))
	var now_settle: float = float(loose.get("settle", 0.0))
	var was_error: float = float(steady.get("steady", 0.0))
	var now_error: float = float(loose.get("steady", 0.0))
	_check("a_fin_that_will_not_hold_shows_up_as_settling", now_settle > was_settle + 5.0 and now_error > was_error,
		"settles in %.1f s with a standing error of %.4f rad as built, %.1f s and %.4f at a twentieth of the fin"
			% [was_settle, was_error, now_settle, now_error])


## ---- the table -----------------------------------------------------------------------------

func _write(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check("the_scores_could_be_written", false, "%s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	var keys: Array = _lines.keys()
	keys.sort()
	for key in keys:
		file.store_line(String(_lines[key]))
	file.close()
	print("[vehicle_gym] wrote %d lines to %s" % [keys.size(), path])


## EVERY SCORE WITHIN A BAND OF WHAT WAS RECORDED. A band and not the bit, because these are flown off a minute of
## flight and the last metre of a settle is not a regression: a quarter of the recorded value, with a floor under the
## small numbers so that 0.01 against 0.02 is not reported as a doubling.
func _compare(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check("the_recorded_scores_could_be_read", false,
			"%s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	var recorded: Dictionary = {}
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var words: PackedStringArray = line.split(" ", false)
		if words.size() < 2:
			continue
		recorded["%s %s" % [words[0], words[1]]] = line
	file.close()
	var moved: PackedStringArray = []
	for key in _lines:
		if not recorded.has(key):
			moved.append("%s is new" % key)
			continue
		var was: Dictionary = _fields(String(recorded[key]))
		var now: Dictionary = _fields(String(_lines[key]))
		for field in now:
			if not was.has(field):
				continue
			var a: float = float(was[field])
			var b: float = float(now[field])
			if absf(b - a) > maxf(EXPECT_SHARE * absf(a), EXPECT_FLOOR):
				moved.append("%s %s %.3f -> %.3f" % [key, field, a, b])
	for key in recorded:
		if not _lines.has(key):
			moved.append("%s was not flown" % key)
	_check("every_score_is_within_a_band_of_what_was_recorded", moved.is_empty(),
		"%d lines checked%s" % [_lines.size(), "" if moved.is_empty() else ": %s" % moved])


## The `name=value` pairs of a scored line, as floats.
func _fields(line: String) -> Dictionary:
	var out: Dictionary = {}
	for word in line.split(" ", false):
		if not word.contains("="):
			continue
		var pair: PackedStringArray = word.split("=", false, 1)
		if pair.size() == 2 and pair[1].is_valid_float():
			out[pair[0]] = pair[1].to_float()
	return out


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
		get_tree().quit(0)
	else:
		print("RESULT=FAIL %s" % " ".join(_failures))
		get_tree().quit(1)
