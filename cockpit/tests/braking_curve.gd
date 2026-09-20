extends Node
## Headless: THE BRAKING CURVE, FLOWN. `world/braking_curve.gd` is four lines of arithmetic, and the only way to check
## arithmetic without writing it out a second time is to USE it: every check here drives a point mass down the curve at
## a hundred and twenty a second and asks what happened, rather than comparing the formula with itself.
##
##   Godot --headless --path cockpit res://tests/braking_curve.tscn
##
## WHY (lane/flightcore, 2026-09-19): the gym found the jets flying past a waypoint by more than half the distance they
## were sent, because nothing works out when to begin slowing. The curve is the fix, ported from the train's
## `auto_driver.gd`, and it is about to be given to every aeroplane -- so it wants checks that can fail.
##
## THE TAUTOLOGY THIS AVOIDS: `assert speed_for(d) == sqrt(2 a d)` passes on any curve, including one with the sign
## wrong, because it is the same expression twice. What is held instead is what the curve is FOR:
## - a craft that flies the curve ARRIVES at the arrival speed, from four starting speeds and four decelerations;
## - it never needs more deceleration on the way than the craft has, which is the promise the margin exists to keep;
## - `begins_at` is where `speed_for` actually leaves cruise -- one number, one place, and the two are computed
##   separately, so a change to either without the other fails here;
## - a craft with nothing to brake with is told to fly the arrival speed from the start, not promised a deceleration;
## - and the level-off lead stops the climb within five metres of the height it was aimed at, over nine pairings of a
##   climb rate with the vertical acceleration that has to stop it.
##
## THE MUTANT, run inside the suite: flown against a craft with a FIFTH LESS than the plan assumed -- which is every
## craft, since the gym measured a fighter's best second at 0.517 m/s^2, its mean at idle at 0.435, and what it actually
## managed at 0.043 -- the curve planned on three quarters of what it has still arrives on the number, and the same
## curve planned on ALL of it arrives 18.0 m/s fast. That is the whole reason the margin is there, and the reason the
## train aimed short.
##
## Read RESULT=.

const TICK: float = 1.0 / 120.0
## What counts as arriving on the number: a tenth of a metre a second.
const CLOSE: float = 0.1

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[braking_curve] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_a_craft_that_flies_the_curve_arrives_at_the_arrival_speed()
	_and_never_needs_more_deceleration_than_it_has()
	_begins_at_is_where_the_curve_leaves_cruise()
	_nothing_to_brake_with_is_told_so_rather_than_promised_a_stop()
	_the_level_off_lead_stops_the_climb_on_the_height()
	_without_the_margin_it_overshoots()
	if _failures.is_empty():
		print("RESULT=PASS")
		get_tree().quit(0)
	else:
		print("RESULT=FAIL %s" % " ".join(_failures))
		get_tree().quit(1)


## FLY THE CURVE. A point mass at `speed` with `range_left` to run, which every tick asks the curve what speed it should
## be doing and changes speed toward it at no more than `can_shed` a second. Returns the speed and the range when it
## reached the marker, and the most deceleration it ever used.
func _fly(speed: float, range_left: float, arrive: float, can_shed: float, plan_with: float,
		cruise: float) -> Dictionary:
	var worst: float = 0.0
	var ticks: int = 0
	# Long enough for the slowest case to finish: the run at half the arrival speed, and half as long again. A cap that
	# is merely large stops a 116 km deceleration at 0.2 m/s^2 half way and reports the answer as a miss.
	var cap: int = int(1.5 * range_left / maxf(arrive * 0.5, 1.0) / TICK) + 1200
	while range_left > 0.0 and ticks < cap:
		var wanted: float = BrakingCurve.speed_for(range_left, arrive, plan_with, cruise)
		var step: float = clampf(wanted - speed, -can_shed * TICK, can_shed * TICK)
		worst = maxf(worst, -step / TICK)
		speed = maxf(speed + step, 0.5)
		range_left -= speed * TICK
		ticks += 1
	return {"speed": speed, "over": -range_left, "worst": worst, "seconds": float(ticks) * TICK,
		"reached": range_left <= 0.0}


func _a_craft_that_flies_the_curve_arrives_at_the_arrival_speed() -> void:
	var worst_miss: float = 0.0
	var worst_case: String = ""
	for cruise in [40.0, 70.0, 130.0, 215.0]:
		for shed in [0.2, 0.5, 2.0, 6.0]:
			var arrive: float = cruise * 0.5
			var run: float = BrakingCurve.begins_at(cruise, arrive, shed) + cruise * 4.0
			var flown: Dictionary = _fly(cruise, run, arrive, shed, shed, cruise)
			var miss: float = absf(float(flown["speed"]) - arrive)
			if miss > worst_miss:
				worst_miss = miss
				worst_case = "%.0f m/s shedding %.1f: arrived at %.2f wanting %.2f" % [
					cruise, shed, flown["speed"], arrive]
	_check("a_craft_that_flies_the_curve_arrives_at_the_arrival_speed", worst_miss <= CLOSE,
		"16 cases, worst %.3f m/s out -- %s" % [worst_miss, worst_case])


## AND NEVER ASKS FOR MORE THAN IT HAS. The margin is what makes this true: the curve is planned on three quarters of
## the deceleration, so tracking it never calls for the whole of it.
func _and_never_needs_more_deceleration_than_it_has() -> void:
	var worst_share: float = 0.0
	var worst_case: String = ""
	for cruise in [40.0, 70.0, 130.0, 215.0]:
		for shed in [0.2, 0.5, 2.0, 6.0]:
			var arrive: float = cruise * 0.5
			var run: float = BrakingCurve.begins_at(cruise, arrive, shed) + cruise * 4.0
			var flown: Dictionary = _fly(cruise, run, arrive, shed, shed, cruise)
			var share: float = float(flown["worst"]) / shed
			if share > worst_share:
				worst_share = share
				worst_case = "%.0f m/s shedding %.1f used %.3f" % [cruise, shed, flown["worst"]]
	_check("and_never_needs_more_deceleration_than_it_has", worst_share <= 1.0,
		"worst call was %.0f%% of what it has -- %s" % [100.0 * worst_share, worst_case])


## ONE NUMBER, ONE PLACE: `begins_at` says where the slowing starts, and `speed_for` is what does it. They are written
## separately, so this is a real check and not a restatement -- a change to the margin or the aim-short in one of them
## and not the other fails here.
func _begins_at_is_where_the_curve_leaves_cruise() -> void:
	var worst: float = 0.0
	var worst_case: String = ""
	for cruise in [40.0, 130.0]:
		for shed in [0.3, 2.0]:
			var arrive: float = cruise * 0.6
			var says: float = BrakingCurve.begins_at(cruise, arrive, shed)
			# Walk in from well outside until the curve first asks for less than cruise.
			var found: float = -1.0
			var d: float = says * 2.0
			while d > 0.0:
				if BrakingCurve.speed_for(d, arrive, shed, cruise) < cruise - 1e-4:
					found = d
					break
				d -= 0.05
			var out: float = absf(found - says)
			if out > worst:
				worst = out
				worst_case = "%.0f m/s shedding %.1f: says %.1f m, leaves cruise at %.1f m" % [
					cruise, shed, says, found]
	_check("begins_at_is_where_the_curve_leaves_cruise", worst <= 0.2,
		"worst disagreement %.3f m -- %s" % [worst, worst_case])


## A CRAFT WITH NOTHING TO BRAKE WITH IS TOLD SO. The gym measured seven kinds shedding almost nothing at idle, and a
## curve that promised them a stop would put the aeroplane's failure inside the planner where nobody can see it. Asked
## for a stop it cannot make, the curve says "fly the arrival speed from here" and `begins_at` says INF.
func _nothing_to_brake_with_is_told_so_rather_than_promised_a_stop() -> void:
	var now: float = BrakingCurve.speed_for(5000.0, 40.0, 0.0, 90.0)
	var begins: float = BrakingCurve.begins_at(90.0, 40.0, 0.0)
	_check("nothing_to_brake_with_is_told_so_rather_than_promised_a_stop",
		is_equal_approx(now, 40.0) and is_inf(begins),
		"asks for %.1f m/s five kilometres out, and begins at %s" % [now, begins])


## THE LEVEL-OFF STOPS ON THE HEIGHT. Climb at `climb`, begin easing `level_off_lead` below the target, and the height
## it settles at is the height it was aimed at.
func _the_level_off_lead_stops_the_climb_on_the_height() -> void:
	var worst: float = 0.0
	var worst_case: String = ""
	# THE VERTICAL AUTHORITY IS PAIRED WITH THE CLIMB, not crossed with it: a craft climbing at 13.7 m/s with half a
		# metre a second squared to stop it is not an aeroplane, it is a lift with the cable cut, and holding the curve to
		# a case nothing can fly tells us nothing about the ones that can.
	for climb in [2.7, 7.3, 13.7]:
		for share in [0.25, 0.5, 1.0]:
			var vertical: float = climb * share
			var target: float = 400.0
			var height: float = 0.0
			var rate: float = climb
			var ticks: int = 0
			while ticks < 120 * 600 and (rate > 0.01 or height < target - 1.0):
				var left: float = target - height
				var lead: float = BrakingCurve.level_off_lead(rate, vertical)
				var wanted: float = 0.0 if left <= 0.0 else (climb if left > lead else climb * (left / maxf(lead, 1e-3)))
				rate = clampf(wanted, rate - vertical * TICK, rate + vertical * TICK)
				height += rate * TICK
				ticks += 1
			var out: float = absf(height - target)
			if out > worst:
				worst = out
				worst_case = "climbing %.1f with %.1f m/s2 to spare settled at %.2f m" % [climb, vertical, height]
	_check("the_level_off_lead_stops_the_climb_on_the_height", worst <= 5.0,
		"worst %.2f m past 400 -- %s" % [worst, worst_case])


## THE MUTANT: TAKE THE MARGIN AWAY. Flown against a craft with a fifth less than the plan assumed -- which is every
## craft, because a measured limit is always optimistic by the time it is needed -- the curve planned on the WHOLE
## deceleration arrives fast and past the marker, and the one planned on three quarters does not. This is why `PLAN_ON`
## is 0.75 and why the train aimed short.
func _without_the_margin_it_overshoots() -> void:
	var cruise: float = 130.0
	var arrive: float = 60.0
	var shed: float = 1.2
	# A FIFTH LESS THAN THE PLAN ASSUMED, which is not pessimism: the gym measured a fighter's best second at 0.517
	# m/s^2 against 0.435 for its mean at idle and 0.043 for what it actually managed. A measured limit is always
	# optimistic by the time the craft needs it.
	var really: float = shed * 0.80
	var run: float = BrakingCurve.begins_at(cruise, arrive, shed) + cruise * 4.0
	var careful: Dictionary = _fly(cruise, run, arrive, really, shed, cruise)
	# The same flight with the margin spent: plan on everything it has, and aim at the marker itself.
	var bold: Dictionary = _fly(cruise, run, arrive, really, shed / BrakingCurve.PLAN_ON, cruise)
	var careful_fast: float = float(careful["speed"]) - arrive
	var bold_fast: float = float(bold["speed"]) - arrive
	_check("without_the_margin_it_overshoots", bold_fast > careful_fast + 1.0 and careful_fast <= CLOSE,
		"arrives %.3f m/s fast on three quarters of what it has, %.3f m/s fast on all of it"
			% [careful_fast, bold_fast])
