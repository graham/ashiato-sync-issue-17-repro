extends Node
## Headless: does a ship under sail go where the wind lets it, and nowhere it does not?
##
##   Godot --headless --path cockpit res://tests/sailing.tscn
##
## THE POLAR IS MEASURED BY SAILING, NOT READ BACK. A polar diagram -- how fast a ship goes at
## each angle to the wind -- is what a ship DOES, and typing one into the simulation and then
## checking the simulation against it is the tautology `testing_godot_headless.md` is about.
## So nothing here reads a coefficient. Brigs are put on courses at every ten degrees off a
## ten-metre wind, their own autopilot steers and trims them (`hold_course`, the helmsman the AI
## sails by), and what they make good over two minutes is the polar. The limits are sailing's
## own, not the model's: a beam reach at six to nine knots, a square-rigger that cannot point
## inside about forty-five degrees of the wind, a broad reach faster than a dead run, and a ship
## that goes about through the wind and keeps way on doing it.
##
## Every world is ticked by hand at 120 Hz, far out at sea over nothing but the swell.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const KNOT: float = 0.514444
## The wind every ship here is measured in, and where it comes from: north, so the air goes +Z.
const WIND: float = 10.0
const FROM: float = 0.0
## A beam reach at six to nine knots in a ten-metre wind is the brief, and what a brig did.
const BEAM_SLOWEST: float = 6.0 * KNOT
const BEAM_FASTEST: float = 9.0 * KNOT
## CLOSER THAN THIS TO THE WIND, A SQUARE-RIGGER MAKES NO WAY ALONG ITS HEADING. Inside it the
## ship may drift, fall off or lie in irons; what it may not do is go where it is pointed.
const NO_GO_DEG: float = 45.0
## And it has to be able to sail upwind at all: some course this close makes real way.
const POINTS_BY_DEG: float = 70.0
## "Making way": metres a second along the commanded heading.
const MAKING_WAY: float = 1.0
## Inside the no-go zone, the most it may make along its heading.
const NO_WAY: float = 0.3
## How long each ship on the polar sails, and from when its speed counts.
const POLAR_SECONDS: float = 150.0
const POLAR_SETTLED: float = 60.0

var _failures: PackedStringArray = []
var _sections: int = 0
const SECTIONS: int = 8


func _check(label: String, ok: bool, detail: String) -> void:
	print("[sailing] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	# EACH SECTION COUNTS ITSELF ON ITS LAST LINE, not here after the call: a GDScript error ends
	# the function and the caller carries on, which is how nobody_aboard.gd's first draft passed
	# with two sections dead.
	_the_wind_wanders_inside_its_limits_and_every_world_agrees()
	_the_polar()
	_a_ship_goes_about_through_the_wind_and_keeps_way_on()
	_it_heels_to_leeward_and_further_in_more_wind()
	_it_floats_on_the_swell_for_ten_minutes()
	_the_swell_has_no_seam_where_its_wrap_flips()
	_two_worlds_built_alike_sail_alike()
	_a_ship_with_nobody_sailing_it_goes_nowhere()
	_finish()


func _finish() -> void:
	_check("every_section_ran_to_its_end", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _world(weather: Dictionary) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.set_weather(weather)
	var tune: Dictionary = _tuning()
	if not tune.is_empty():
		world.set_handling(Sim.Kind.PIRATE, tune)
	return world


## `--tune=key=value;key=value` after the bare `--`: the ship's handling for every world here, so
## a sail plan can be swept with no rebuild (ashiato-gd/LEARNINGS.md, "A tuning constant in C++
## is a tuning constant you will not tune"). Every key is read back and a misspelt one fails the
## run, because `set_handling` takes a typo as absent.
static func _tuning() -> Dictionary:
	var out: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--tune="):
			continue
		for pair in argument.trim_prefix("--tune=").split(";", false):
			var parts: PackedStringArray = pair.split("=")
			if parts.size() == 2:
				out[parts[0]] = float(parts[1])
	return out


func _steady(speed: float) -> Dictionary:
	return {"from": FROM, "low": speed, "high": speed, "veer": 0.0, "seed": 1}


## A BRIG on a compass heading, already making a little way along it: `spawn_vehicle`'s yaw puts
## the nose along (-sin yaw, 0, -cos yaw), which is a compass heading of minus the yaw.
func _ship(world: Object, at: Vector3, heading: float, way: float) -> int:
	var nose := Vector3(sin(heading), 0.0, -cos(heading))
	var ship: int = int(world.spawn_ai_vehicle(Sim.Kind.PIRATE, at, -heading, nose * way))
	world.hold_course(ship, heading)
	return ship


## THE SIMULATION'S SWELL at a point, from the shape it hands out: floor-wrapped, as `swell_height` is since 2026-09-15.
static func _sea_at(at: Vector3, shape: Dictionary) -> float:
	var tile: float = float(shape["tile"])
	var p := Vector2(at.x - tile * floor(at.x / tile), at.z - tile * floor(at.z / tile))
	return sin(p.dot(shape["first"] as Vector2)) * float(shape["height"]) \
		+ sin(p.dot(shape["second"] as Vector2)) * float(shape["second_height"]) + _wind_sea_at(p, shape)


## THE WIND-SEA THE BOATS FEEL (C1), at a position already wrapped at the tile: each of the shape's `wind_waves`, as
## (x, z, height), summed as `swell_height` sums them.
static func _wind_sea_at(p: Vector2, shape: Dictionary) -> float:
	var height: float = 0.0
	for wave in (shape.get("wind_waves", []) as Array):
		height += sin(p.dot(Vector2((wave as Vector3).x, (wave as Vector3).y))) * (wave as Vector3).z
	return height


static func _heading_of(state: Dictionary) -> float:
	var nose: Vector3 = (state["basis"] as Quaternion) * Vector3.FORWARD
	return atan2(nose.x, -nose.z)


static func _wrap(angle: float) -> float:
	return wrapf(angle, -PI, PI)


## ---- the wind ------------------------------------------------------------------------

## THE WIND IS A FUNCTION OF THE FRAME: inside its limits, actually wandering, and the same on
## two worlds told the same weather. A second seed is a different afternoon.
func _the_wind_wanders_inside_its_limits_and_every_world_agrees() -> void:
	var weather := {"from": 0.8, "low": 5.0, "high": 12.0, "veer": deg_to_rad(25.0), "seed": 7}
	var one: Object = _world(weather)
	var two: Object = _world(weather)
	var other: Object = _world({"from": 0.8, "low": 5.0, "high": 12.0, "veer": deg_to_rad(25.0), "seed": 8})
	var slowest: float = INF
	var fastest: float = 0.0
	var leftmost: float = INF
	var rightmost: float = -INF
	var disagreed: int = 0
	var differs: int = 0
	var samples: int = 0
	# Thirty minutes of weather, a sample every ten seconds.
	for i in range(int(1800.0 / TICK)):
		one.tick(TICK)
		two.tick(TICK)
		other.tick(TICK)
		if i % 1200 != 0:
			continue
		samples += 1
		var a: Dictionary = one.weather()
		var b: Dictionary = two.weather()
		var c: Dictionary = other.weather()
		slowest = minf(slowest, float(a["speed"]))
		fastest = maxf(fastest, float(a["speed"]))
		leftmost = minf(leftmost, float(a["from"]))
		rightmost = maxf(rightmost, float(a["from"]))
		if float(a["speed"]) != float(b["speed"]) or float(a["from"]) != float(b["from"]):
			disagreed += 1
		if absf(float(a["speed"]) - float(c["speed"])) > 0.05:
			differs += 1
		var air: Vector3 = one.wind(0.0)
		# Where it GOES is away from where it comes from.
		var going := atan2(-air.x, air.z)
		if absf(_wrap(going - float(a["from"]))) > 0.001 or absf(air.length() - float(a["speed"])) > 0.001:
			disagreed += 1
	_check("the_wind_stays_between_five_and_twelve_metres_a_second",
		slowest >= 5.0 - 0.001 and fastest <= 12.0 + 0.001,
		"%.2f to %.2f m/s over thirty minutes" % [slowest, fastest])
	_check("and_it_wanders_rather_than_standing_still",
		fastest - slowest > 2.0 and rad_to_deg(rightmost - leftmost) > 10.0,
		"%.2f m/s of range and %.1f degrees of veer" % [fastest - slowest, rad_to_deg(rightmost - leftmost)])
	_check("and_two_worlds_told_the_same_weather_have_the_same_wind_and_say_it_one_way",
		disagreed == 0 and samples > 100, "%d of %d samples disagreed" % [disagreed, samples])
	_check("and_a_different_seed_is_a_different_afternoon", differs > samples / 2,
		"%d of %d samples differ by more than 0.05 m/s" % [differs, samples])
	# A WORLD TOLD NOTHING HAS STILL AIR, which is every world before there was weather.
	var still: Object = ClassDB.instantiate("CockpitWorld")
	still.start(0)
	_check("and_a_world_told_nothing_has_still_air", (still.wind(0.0) as Vector3).length() < 0.001,
		"%v" % still.wind(0.0))
	# AND A WEATHER THAT IS NOT A WIND IS REFUSED, not clamped into a different one.
	_check("and_a_top_speed_under_the_bottom_one_is_refused",
		not bool(still.set_weather({"low": 8.0, "high": 4.0})), "low 8, high 4")
	for world in [one, two, other, still]:
		world.teardown()
	_sections += 1


## ---- the polar --------------------------------------------------------------------------

## EVERY TEN DEGREES OFF THE WIND, from thirty to dead downwind, on the starboard tack.
func _the_polar() -> void:
	var world: Object = _world(_steady(WIND))
	var ships: Dictionary = {}
	for angle in range(30, 190, 10):
		# The wind comes from FROM; a ship with the wind `angle` degrees on its starboard bow heads
		# `angle` degrees to port of it.
		var heading: float = _wrap(FROM - deg_to_rad(float(angle)))
		var at := Vector3(float(angle) * 60.0, 0.0, 0.0)
		ships[angle] = {"entity": _ship(world, at, heading, 2.0), "heading": heading, "start": Vector3.ZERO,
			"errors": 0.0, "samples": 0, "leeway": 0.0, "heel": 0.0, "lowest": INF, "highest": -INF}
	var settled_at: int = int(POLAR_SETTLED / TICK)
	for i in range(int(POLAR_SECONDS / TICK)):
		world.tick(TICK)
		if i == settled_at:
			for angle in ships:
				ships[angle]["start"] = (world.vehicle_state(int(ships[angle]["entity"]))["position"] as Vector3)
		if i > settled_at and i % 30 == 0:
			for angle in ships:
				var row: Dictionary = ships[angle]
				var state: Dictionary = world.vehicle_state(int(row["entity"]))
				var report: Dictionary = world.sail_report(int(row["entity"]))
				row["errors"] = float(row["errors"]) + absf(_wrap(_heading_of(state) - float(row["heading"])))
				row["leeway"] = float(row["leeway"]) + absf(float(report.get("leeway", 0.0)))
				row["heel"] = float(row["heel"]) + float(report.get("heel", 0.0))
				row["samples"] = int(row["samples"]) + 1
	var counted: float = POLAR_SECONDS - POLAR_SETTLED
	print("[sailing] polar in a %.0f m/s wind: angle off the wind, knots made good along the heading, mean heading error, leeway, heel" % WIND)
	var made: Dictionary = {}
	for angle in ships:
		var row: Dictionary = ships[angle]
		var end: Vector3 = world.vehicle_state(int(row["entity"]))["position"]
		var heading: float = float(row["heading"])
		var along := Vector3(sin(heading), 0.0, -cos(heading))
		var good: float = (end - (row["start"] as Vector3)).dot(along) / counted
		var samples: int = maxi(int(row["samples"]), 1)
		made[angle] = {"good": good, "error": rad_to_deg(float(row["errors"]) / samples),
			"leeway": rad_to_deg(float(row["leeway"]) / samples), "heel": rad_to_deg(float(row["heel"]) / samples)}
		print("[sailing]   %3d deg  %5.2f kn  error %5.1f deg  leeway %4.1f deg  heel %5.1f deg" % [angle,
			good / KNOT, made[angle]["error"], made[angle]["leeway"], made[angle]["heel"]])
	world.teardown()

	var beam: float = float(made[90]["good"])
	_check("on_a_beam_reach_in_a_ten_metre_wind_it_makes_six_to_nine_knots",
		beam >= BEAM_SLOWEST and beam <= BEAM_FASTEST, "%.2f kn" % (beam / KNOT))
	var inside: Array[String] = []
	for angle in made:
		if float(angle) < NO_GO_DEG and float(made[angle]["good"]) > NO_WAY:
			inside.append("%d deg %.2f m/s" % [angle, made[angle]["good"]])
	_check("inside_the_no_go_zone_it_makes_no_way_along_its_heading", inside.is_empty(),
		"%s" % ["30 and 40 degrees: %.2f and %.2f m/s" % [made[30]["good"], made[40]["good"]] if inside.is_empty() else inside])
	var closest: int = 999
	for angle in made:
		if float(made[angle]["good"]) >= MAKING_WAY:
			closest = mini(closest, int(angle))
	_check("and_it_points_no_closer_than_the_no_go_angle_but_it_can_sail_upwind",
		closest >= int(NO_GO_DEG) and closest <= int(POINTS_BY_DEG),
		"closest course making %.1f m/s: %d degrees off the wind" % [MAKING_WAY, closest])
	var broad: float = maxf(float(made[130]["good"]), maxf(float(made[140]["good"]), float(made[150]["good"])))
	var run: float = float(made[180]["good"])
	_check("a_broad_reach_is_faster_than_a_dead_run", broad > run + 0.2,
		"broad reach %.2f kn against a run %.2f kn" % [broad / KNOT, run / KNOT])
	var wandered: Array[String] = []
	for angle in made:
		if int(angle) >= 60 and float(made[angle]["error"]) > 5.0:
			wandered.append("%d deg %.1f" % [angle, made[angle]["error"]])
	_check("and_it_holds_every_course_it_can_sail_to_a_few_degrees", wandered.is_empty(),
		"%s" % ["every course from 60 degrees within 5" if wandered.is_empty() else wandered])
	var leeway: float = float(made[90]["leeway"])
	_check("and_slides_to_leeward_a_little_on_a_reach", leeway > 0.5 and leeway < 8.0,
		"%.1f degrees of leeway on a beam reach" % leeway)
	_sections += 1


## ---- a tack ---------------------------------------------------------------------------

## GOING ABOUT: close-hauled on the starboard tack, the helm put over for the same angle on the
## port tack. The bow has to cross the wind -- not wear round the long way -- and the ship has to
## come out the other side still moving forwards and then pick up way again.
func _a_ship_goes_about_through_the_wind_and_keeps_way_on() -> void:
	var world: Object = _world(_steady(WIND))
	var close: float = deg_to_rad(65.0)
	var ship: int = _ship(world, Vector3.ZERO, _wrap(FROM - close), 3.0)
	for i in range(int(90.0 / TICK)):
		world.tick(TICK)
	var before: float = float(world.sail_report(ship)["way"])
	var new_course: float = _wrap(FROM + close)
	world.hold_course(ship, new_course)
	var crossed: bool = false
	var wore: bool = false
	var slowest: float = INF
	var round_in: float = -1.0
	var time: float = 0.0
	var drive_head_to_wind: float = INF
	var aback_head_to_wind: int = 0
	# How far round towards the new course the bow has got, at its furthest, and the most it has
	# fallen back from that. Turning is measured from the old course towards the new, through
	# the wind.
	var furthest_round: float = -INF
	var fell_back: float = 0.0
	var old_course: float = _wrap(FROM - close)
	for i in range(int(120.0 / TICK)):
		world.tick(TICK)
		time += TICK
		var state: Dictionary = world.vehicle_state(ship)
		var heading: float = _heading_of(state)
		var off: float = _wrap(heading - FROM)
		var report: Dictionary = world.sail_report(ship)
		if i % 360 == 0:
			print("[sailing]   tack %5.1f s  heading %6.1f deg off the wind  way %5.2f m/s  apparent %6.1f deg  fore %5.2f main %5.2f  fill %s" % [
				time, rad_to_deg(off), float(report["way"]), rad_to_deg(float(report["apparent_angle"])),
				float(report["fore"]), float(report["main"]), report["fill"]])
		# HEAD TO WIND: the sails push the ship nowhere forwards, and some of them are aback.
		if absf(off) < deg_to_rad(5.0):
			crossed = true
			drive_head_to_wind = minf(drive_head_to_wind, float(report["drive"]))
			for fill in report["fill"]:
				if float(fill) < 0.0:
					aback_head_to_wind += 1
					break
		# Wearing round is turning the stern through the wind instead: past the beam the wrong way.
		if absf(off) > deg_to_rad(120.0):
			wore = true
		slowest = minf(slowest, float(world.sail_report(ship)["way"]))
		if round_in < 0.0:
			var round: float = _wrap(heading - old_course)
			furthest_round = maxf(furthest_round, round)
			fell_back = maxf(fell_back, furthest_round - round)
		if round_in < 0.0 and absf(_wrap(heading - new_course)) < deg_to_rad(10.0):
			round_in = time
	var after: float = float(world.sail_report(ship)["way"])
	world.teardown()
	_check("a_ship_goes_about_with_its_bow_through_the_wind", crossed and not wore,
		"crossed the wind %s, wore round %s" % [crossed, wore])
	_check("and_is_on_the_new_tack_within_a_minute", round_in >= 0.0 and round_in <= 60.0,
		"within 10 degrees of the new course after %.1f s" % round_in)
	# WITH STEERAGE: the bow keeps coming round -- it never falls back more than ten degrees from
	# the furthest it got -- and any sternboard in stays is a short one. A brig in stays often
	# gathers a little sternway, and the helm is shifted for it; one that drifts astern at a knot
	# has missed stays. NOT "never astern at all": that failed a tack a sailor would call clean
	# (-0.31 m/s for about six seconds, on the new tack in 27 s).
	_check("and_keeps_steerage_through_it", slowest > -0.5 and fell_back < deg_to_rad(10.0),
		"slowest %.2f m/s of way from %.2f before, fell back %.1f degrees at worst" % [slowest, before,
			rad_to_deg(fell_back)])
	# NOT "LUFFING": head to wind a square sail is not slack, it is ABACK, pressed back against the
	# mast. What is true of every sail at that moment is that none of them drives the ship forwards.
	_check("and_head_to_wind_its_sails_drive_it_nowhere_and_some_are_aback",
		crossed and drive_head_to_wind <= 0.0 and aback_head_to_wind > 0,
		"least forward push head to wind %.0f N, %d ticks with a sail aback" % [drive_head_to_wind, aback_head_to_wind])
	_check("and_it_picks_up_way_again_on_the_new_tack", after > 1.5,
		"%.2f m/s two minutes later" % after)
	_sections += 1


## ---- heel ------------------------------------------------------------------------------

## HEEL RISES WITH THE WIND and is to LEEWARD: a beam reach in five, ten and fourteen metres a
## second. Wind on the starboard side lays the masts over to port, which is a negative heel.
func _it_heels_to_leeward_and_further_in_more_wind() -> void:
	var heels: Array[float] = []
	for speed in [5.0, 10.0, 14.0]:
		var world: Object = _world(_steady(speed))
		var ship: int = _ship(world, Vector3.ZERO, _wrap(FROM - PI * 0.5), 3.0)
		var sum: float = 0.0
		var count: int = 0
		for i in range(int(90.0 / TICK)):
			world.tick(TICK)
			if i > int(45.0 / TICK) and i % 30 == 0:
				sum += float(world.sail_report(ship)["heel"])
				count += 1
		heels.append(rad_to_deg(sum / maxi(count, 1)))
		world.teardown()
	_check("it_heels_to_leeward", heels[1] < 0.0, "%.1f degrees in ten metres a second" % heels[1])
	_check("and_further_the_more_wind_there_is", absf(heels[0]) < absf(heels[1]) and absf(heels[1]) < absf(heels[2]),
		"%.1f, %.1f and %.1f degrees in 5, 10 and 14 m/s" % [heels[0], heels[1], heels[2]])
	_check("and_visibly_in_a_ten_metre_breeze_without_laying_over",
		absf(heels[1]) >= 3.0 and absf(heels[2]) <= 25.0,
		"%.1f degrees at 10 m/s, %.1f at 14" % [heels[1], heels[2]])
	_sections += 1


## ---- floating ---------------------------------------------------------------------------

## TEN MINUTES ON A BEAM REACH OVER THE SWELL, sampled twice a second: always wet, never flying,
## never with its deck under, never laid over, and moved by the swell rather than dead level.
func _it_floats_on_the_swell_for_ten_minutes() -> void:
	var world: Object = _world({"from": FROM, "low": 7.0, "high": 12.0, "veer": deg_to_rad(20.0), "seed": 3})
	var ship: int = _ship(world, Vector3(900.0, 0.0, -700.0), _wrap(FROM - PI * 0.5), 3.0)
	var extents: Vector3 = world.kind_geometry(Sim.Kind.PIRATE)["extents"]
	var rig: Dictionary = world.kind_geometry(Sim.Kind.PIRATE).get("rig", {})
	var shape: Dictionary = Sim.swell_shape()
	var lowest_sea: float = INF
	var highest_sea: float = -INF
	var sea_sum: float = 0.0
	var lowest: float = INF
	var highest: float = -INF
	var dry: int = 0
	var steepest: float = 0.0
	var heights: Array[float] = []
	var started: Vector3 = world.vehicle_state(ship)["position"]
	for i in range(int(600.0 / TICK)):
		world.tick(TICK)
		if i < int(20.0 / TICK) or i % 60 != 0:
			continue
		var state: Dictionary = world.vehicle_state(ship)
		var y: float = (state["position"] as Vector3).y
		lowest = minf(lowest, y)
		highest = maxf(highest, y)
		heights.append(y)
		if not bool(world.sail_report(ship)["afloat"]):
			dry += 1
		var up: Vector3 = (state["basis"] as Quaternion) * Vector3.UP
		steepest = maxf(steepest, rad_to_deg(acos(clampf(up.y, -1.0, 1.0))))
		# WHERE THE SEA MEETS THE HULL: the simulation's own swell at midships, above the centre of mass along the mast.
		if not shape.is_empty():
			var centre: Vector3 = state["position"]
			var on_hull: float = (_sea_at(centre, shape) - centre.y) / maxf(up.y, 0.5)
			lowest_sea = minf(lowest_sea, on_hull)
			highest_sea = maxf(highest_sea, on_hull)
			sea_sum += on_hull
	var mean: float = 0.0
	for y in heights:
		mean += y
	mean /= maxf(float(heights.size()), 1.0)
	var spread: float = 0.0
	for y in heights:
		spread += (y - mean) * (y - mean)
	spread = sqrt(spread / maxf(float(heights.size()), 1.0))
	var travelled: float = ((world.vehicle_state(ship)["position"] as Vector3) - started).length()
	world.teardown()
	_check("it_floats_for_ten_minutes_and_is_never_out_of_the_water", dry == 0,
		"%d samples dry of %d" % [dry, heights.size()])
	_check("and_never_rises_clear_of_the_sea_or_takes_its_deck_under",
		highest + (-extents.y) < 0.5 and lowest + extents.y > 0.5,
		"the middle of the hull from %.2f to %.2f m, keel %.2f m below it" % [lowest, highest, extents.y])
	_check("and_never_lays_over", steepest < 30.0, "most %.1f degrees off upright" % steepest)
	_check("and_rides_the_swell_rather_than_sitting_dead_level", spread > 0.02,
		"%.3f m of heave, having sailed %.0f m" % [spread, travelled])
	# THE SEA ON THE DRAWN HULL. A picture made a brig look clear of the water, so where the water is on the hull the
	# drawing builds is measured, off the simulation's own swell (`Sim.swell_shape`, floor-wrapped as `swell_height` is),
	# against the drawn keel and rail and the rig's waterline. A BRIG'S WATERLINE IS MORE THAN HALF WAY UP ITS HULL: HMS
	# Beagle drew 3.8 m, and this hull's 3.3 m of draught under 2.2 m of freeboard amidships is 60 per cent up from the keel.
	var waterline: float = float(rig.get("waterline", NAN))
	var keel: float = -extents.y
	var rail: float = extents.y
	var share_up: float = (waterline - keel) / (rail - keel)
	var mean_sea: float = sea_sum / maxf(float(heights.size()), 1.0)
	_check("the_sea_stays_on_the_drawn_hull_between_its_keel_and_its_rail",
		not shape.is_empty() and lowest_sea > keel + 0.5 and highest_sea < rail - 0.5,
		"the sea from %.2f to %.2f m above the centre of mass; keel %.2f, rail %.2f" % [lowest_sea, highest_sea, keel, rail])
	_check("and_it_averages_the_rigs_waterline", absf(mean_sea - waterline) < 0.35,
		"mean %.2f m against the rig's %.2f" % [mean_sea, waterline])
	_check("which_is_a_brigs_waterline_more_than_half_and_under_seven_tenths_up_the_hull",
		share_up > 0.5 and share_up < 0.7,
		"%.0f per cent up from the keel: %.1f m of draught and %.1f m of freeboard amidships" % [share_up * 100.0,
			waterline - keel, rail - waterline])
	_sections += 1


## ---- determinism ------------------------------------------------------------------------

## THE SWELL HAS NO SEAM WHERE ITS WRAP FLIPS, asked of the simulation's own `swell_height` through `swell_height_at`.
## The position is wrapped at the tile, so at x = 0, z = 0 and x, z = +-2,048 a swell that is not a whole number of waves
## across the tile steps. The first vectors did: 0.37 m at z = +-2,048 under fmod, and under floor 0.82 m across z = 0 and
## 1.21 m across x = 0, which tilted carrier_shape's carrier 2.67 degrees against 1.5. Pairs a centimetre apart straddle
## each seam all along it, against the most the honest swell can change in a centimetre (under 0.3 mm).
const SEAM_STEP: float = 0.002

func _the_swell_has_no_seam_where_its_wrap_flips() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	var shape: Dictionary = world.swell_shape()
	var tile: float = float(shape["tile"])
	var first: Vector2 = shape["first"]
	var second: Vector2 = shape["second"]
	var steepest: float = first.length() * float(shape["height"]) + second.length() * float(shape["second_height"])
	for wave in (shape.get("wind_waves", []) as Array):
		steepest += Vector2((wave as Vector3).x, (wave as Vector3).y).length() * (wave as Vector3).z
	var worst: float = 0.0
	var worst_at: String = "nowhere"
	var lowest: float = INF
	var highest: float = -INF
	var pairs: int = 0
	for seam in [-tile, 0.0, tile]:
		var along: float = -3000.0
		while along <= 3000.0:
			for across_x in [true, false]:
				var a: Vector2 = Vector2(seam - 0.005, along) if across_x else Vector2(along, seam - 0.005)
				var b: Vector2 = Vector2(seam + 0.005, along) if across_x else Vector2(along, seam + 0.005)
				var height_a: float = world.swell_height_at(a.x, a.y)
				var height_b: float = world.swell_height_at(b.x, b.y)
				lowest = minf(lowest, height_a)
				highest = maxf(highest, height_a)
				pairs += 1
				if absf(height_b - height_a) > worst:
					worst = absf(height_b - height_a)
					worst_at = "%s to %s" % [a, b]
			along += 37.0
	_check("the_swell_does_not_step_across_x_or_z_zero_or_the_tile_edge", worst < SEAM_STEP,
		"worst %.4f m in a centimetre, %s, over %d pairs; the steepest swell changes %.5f m in one" % [worst, worst_at,
			pairs, steepest * 0.01])
	# AND IT IS A SWELL: a flat or dead swell_height has no seam either.
	_check("and_those_samples_rise_and_fall_by_more_than_its_height", highest - lowest > float(shape["height"]),
		"%.2f to %.2f m" % [lowest, highest])
	# AND IT IS THE SWELL BOTH SEAS ARE HANDED: the shape `SeaSwell.hand_the_swell` gives the shaders, evaluated here with
	# the shaders' wrap, against the simulation's height at points on all four quadrants and either side of a tile edge.
	var apart: float = 0.0
	for at in [Vector2(-5000.3, 123.4), Vector2(900.0, -700.0), Vector2(2047.9, -2048.1), Vector2(-13.0, 7777.0)]:
		var p: Vector2 = at - Vector2(tile, tile) * (at / tile).floor()
		var painted: float = sin(p.dot(first)) * float(shape["height"]) + sin(p.dot(second)) * float(shape["second_height"]) \
			+ _wind_sea_at(p, shape)
		apart = maxf(apart, absf(painted - float(world.swell_height_at(at.x, at.y))))
	_check("and_it_is_the_swell_both_seas_are_handed", apart < 0.001, "%.5f m apart at worst" % apart)
	# AND A HULL LONG ENOUGH TO RIDE THROUGH THE WIND-SEA FLOATS ON THE SWELL ALONE (team-lead's decision, C1, 2026-09-15): from
	# three of the longest wind waves, read off each kind's waterline in the simulation, and every shorter hull on the swell and
	# the wind-sea. Each floating kind says where it falls.
	var longest: float = 0.0
	for wave in (shape.get("wind_waves", []) as Array):
		longest = maxf(longest, TAU / maxf(Vector2((wave as Vector3).x, (wave as Vector3).y).length(), 0.000001))
	var long_hull: float = float(shape.get("long_hull", 0.0))
	var sided: PackedStringArray = []
	var wrong: int = 0
	var carrier_long: bool = false
	for kind in [Sim.Kind.BOAT, Sim.Kind.GUNBOAT, Sim.Kind.PIRATE, Sim.Kind.SUBMARINE, Sim.Kind.BATTLESHIP, Sim.Kind.CARRIER]:
		var length: float = float(world.hull_length_of(kind))
		var is_long: bool = length >= long_hull
		var off_swell: float = 0.0
		var off_sea: float = 0.0
		for i in range(64):
			var at := Vector2(-3000.0 + 97.3 * float(i), 1500.0 - 61.7 * float(i))
			var p: Vector2 = at - Vector2(tile, tile) * (at / tile).floor()
			var swell: float = sin(p.dot(first)) * float(shape["height"]) + sin(p.dot(second)) * float(shape["second_height"])
			var floats_on: float = float(world.hull_sea_at(kind, at.x, at.y))
			off_swell = maxf(off_swell, absf(floats_on - swell))
			off_sea = maxf(off_sea, absf(floats_on - float(world.swell_height_at(at.x, at.y))))
		if kind == Sim.Kind.CARRIER:
			carrier_long = is_long
		if (is_long and off_swell > 0.001) or (not is_long and off_sea > 0.001):
			wrong += 1
		sided.append("%s %.1f m %s, %.3f m off the swell and %.3f off the whole sea" % [Sim.Kind.keys()[kind], length,
			"long" if is_long else "short", off_swell, off_sea])
	_check("and_a_hull_three_wind_waves_long_floats_on_the_swell_alone",
		longest > 0.0 and absf(long_hull - 3.0 * longest) < 0.01 and carrier_long and wrong == 0,
		"from %.1f m (the longest wind wave %.1f m): %s" % [long_hull, longest, "; ".join(sided)])
	_sections += 1

## TWO WORLDS BUILT ALIKE, IN A WANDERING WIND, END IN THE SAME STATE TO THE BIT. Three ships on
## three points of sail, fifty seconds.
func _two_worlds_built_alike_sail_alike() -> void:
	var weather := {"from": 0.4, "low": 6.0, "high": 11.0, "veer": deg_to_rad(20.0), "seed": 11}
	var hashes: Array[int] = []
	var moved: float = 0.0
	for run in range(2):
		var world: Object = _world(weather)
		var ships: Array[int] = []
		for i in range(3):
			ships.append(_ship(world, Vector3(400.0 * i, 0.0, 0.0), _wrap(0.4 - deg_to_rad(70.0 + 50.0 * i)), 2.0))
		for i in range(int(50.0 / TICK)):
			world.tick(TICK)
		var bytes := PackedByteArray()
		for ship in ships:
			var state: Dictionary = world.vehicle_state(ship)
			bytes.append_array(var_to_bytes([state["position"], state["basis"], state["velocity"], state["spin"]]))
			if run == 0:
				moved += (state["position"] as Vector3).length()
		hashes.append(hash(bytes))
		world.teardown()
	_check("two_worlds_built_alike_sail_to_the_same_state_to_the_bit", hashes[0] == hashes[1] and moved > 300.0,
		"hashes %x and %x, the ships %.0f m from the origin between them" % [hashes[0], hashes[1], moved])
	_sections += 1


## ---- nobody sailing it -------------------------------------------------------------------

## A SHIP WITH NOBODY SAILING IT HAS NO SAIL SET, and so goes nowhere in a wind: no autopilot, no
## crew, the sails furled. What would move a ship nobody sails is a sail force that ignored the
## levers, and that is the fault this is for.
func _a_ship_with_nobody_sailing_it_goes_nowhere() -> void:
	var world: Object = _world(_steady(12.0))
	var ship: int = int(world.spawn_vehicle(Sim.Kind.PIRATE, Vector3.ZERO, PI * 0.5, Vector3.ZERO))
	for i in range(int(60.0 / TICK)):
		world.tick(TICK)
	var state: Dictionary = world.vehicle_state(ship)
	var drift: float = Vector2((state["position"] as Vector3).x, (state["position"] as Vector3).z).length()
	var report: Dictionary = world.sail_report(ship)
	world.teardown()
	_check("a_ship_nobody_sails_has_no_sail_set_and_barely_drifts",
		float(report.get("set", 1.0)) == 0.0 and drift < 30.0,
		"sail set %.2f, drifted %.1f m in a minute of a 12 m/s wind" % [float(report.get("set", 1.0)), drift])
	_sections += 1
