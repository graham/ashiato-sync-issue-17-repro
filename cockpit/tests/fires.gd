extends Node
## Headless: do the fires spread, does the cap hold, and does attending to one stop it?
##
##   Godot --headless --path cockpit res://tests/fires.tscn
##
## `agents.md` said for a long time that fires "grow back and they go out; they do not light
## their neighbours -- that is one constant and a cap away, and it is the thing that would
## turn nine fires into a job you can lose". `FireFront` is that constant and that cap, and
## this is what says it works.
##
## ALL OF IT ON A BARE `CockpitWorld` AND A BARE `FireFront`, ticked by hand. There is no
## scene tree, no session, no autoload and no waiting: a quarter of an hour of fire runs in
## one frame and every number below is exact rather than sampled. That seam is `tick(delta)`
## and it is the reason the front is a `RefCounted` the level owns rather than something
## with a `_physics_process` of its own.
##
## WHAT THIS CANNOT SAY is whether twenty-four columns of smoke read as losing, or whether
## thirty seconds is the right number of seconds. Those want somebody in the aeroplane; the
## constants carry their reasoning in `FireFront` and the numbers below are what they
## currently produce.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0

var _failures: PackedStringArray = []
## Sections that reached their own end. A GDScript error aborts the function it is in and
## carries on with the next, so counting only failures reports a cheerful pass over a
## section that fell over halfway.
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[fires] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_an_unattended_fire_lights_its_neighbours()
	_and_one_that_is_being_worked_does_not()
	_and_it_stops_at_the_cap()
	_and_a_fire_cannot_catch_inside_a_mountain()
	_the_board_says_how_the_job_is_going()
	_check("every_section_of_the_suite_ran", _sections == 5, "%d of 5" % _sections)
	_finish()


## ---- it spreads ---------------------------------------------------------------------

## A FIRE LEFT ALONE LIGHTS ITS NEIGHBOURS, and the rate is the constant.
##
## One fire at full strength should light one more in `SPREAD_SECONDS`, because the
## accumulator is advanced by the number of fires burning hard and there is one of them.
## Then there are two, and they light the third in half the time -- which is the shape that
## makes this a job you can lose rather than a timer.
func _an_unattended_fire_lights_its_neighbours() -> void:
	var world: Object = _a_world()
	var front := FireFront.new(_open_ground())
	world.light_fire(Vector3(0.0, 0.0, 0.0), 1.0)
	_run(world, front, FireFront.SPREAD_SECONDS * 0.8)
	_check("a_fire_alone_has_not_spread_before_its_time", _alight(world) == 1,
		"%d fire(s) after %.0f s of %.0f" % [_alight(world),
			FireFront.SPREAD_SECONDS * 0.8, FireFront.SPREAD_SECONDS])
	# STEPPED A SECOND AT A TIME FROM HERE, because the next check is about the new fire's
	# strength AT BIRTH and a fire grows back at two per cent a second. Running the whole
	# remaining twelve seconds in one go and then looking found 0.34 for a seed of 0.22,
	# which is the regrowth working exactly as it should and the measurement taken too late.
	var waited: float = FireFront.SPREAD_SECONDS * 0.8
	while _alight(world) < 2 and waited < FireFront.SPREAD_SECONDS * 2.0:
		_run(world, front, 1.0)
		waited += 1.0
	_check("and_lights_a_neighbour_when_its_time_comes", _alight(world) == 2,
		"%d fire(s) after %.0f s" % [_alight(world), waited])

	# AND THE NEW ONE IS SMALL AND SOMEWHERE ELSE. A fire that spread on top of its parent
	# is one column of smoke with two entities in it, and a fire that started at full
	# strength is one nobody could have got to in time.
	var young: Dictionary = _the_newest(world)
	_check("and_the_new_one_starts_small",
		float(young["strength"]) < FireFront.SPREAD_FROM * 0.6,
		"%.2f, seeded at %.2f a second or so ago" % [young["strength"],
			FireFront.SEEDED_AT])
	var away: float = (young["position"] as Vector3).length()
	_check("and_stands_far_enough_off_to_be_its_own_column",
		away >= FireFront.SPREAD_NEAR - 1.0 and away <= FireFront.SPREAD_FAR + 1.0,
		"%.0f m, between %.0f and %.0f" % [away, FireFront.SPREAD_NEAR,
			FireFront.SPREAD_FAR])
	# AND MOSTLY DOWNWIND, WHEN THERE IS A WIND: the smoke leans with it and the group the world
	# starts with is one big fire and its children downwind. There has been none since
	# 2026-09-14 (see `Terrain.WIND`), so a spread may go any way and there is no direction to
	# hold one young fire against.
	if Terrain.WIND.length() > 0.01:
		var with_the_wind: float = (young["position"] as Vector3).normalized().dot(
			Terrain.WIND.normalized())
		_check("and_mostly_downwind", with_the_wind > 0.0,
			"%.2f along the wind (1.0 is dead downwind)" % with_the_wind)

	# THE FRONT ACCELERATES, AND IT TAKES A MOMENT TO. This is the check that had the wrong
	# arithmetic in it first: two fires bank the clock twice as fast as one, so the obvious
	# expectation is that the third arrives in half the time -- and it does not, because a
	# fire seeded at 0.22 is not HOT until it has grown back through 0.55, which is about
	# seventeen seconds. So a new fire is a fuse rather than a second burner, and the front
	# builds rather than doubling. That is a better shape for the game than the one the test
	# assumed, and it falls out of the regrowth rather than being tuned.
	var third: float = waited
	while _alight(world) < 3 and third < waited + 180.0:
		_run(world, front, 1.0)
		third += 1.0
	_check("and_the_front_speeds_up_as_it_grows",
		_alight(world) == 3 and (third - waited) < waited,
		"%.0f s to the second fire, %.0f s to the third" % [waited, third - waited])
	world.teardown()
	_sections += 1


## ---- and attending to it stops it -----------------------------------------------------

## A FIRE BEING WORKED DOES NOT SPREAD, and nothing anywhere is watching the tanker.
##
## There is no flag. A fire below `SPREAD_FROM` is not making enough heat to light anything,
## and that is exactly the state a full load leaves one in -- so the mechanism and the
## gameplay are the same sentence. Held against the pair, because "a knocked-down fire does
## not spread" proves nothing unless an identical one at full strength does.
func _and_one_that_is_being_worked_does_not() -> void:
	# A FULL LOAD PUTS A FIRE OUT, and a fire that is out is retired from the wire -- see
	# `water`'s own check. So the attended case is not "a weaker fire", it is NO FIRE, and
	# what it lights is nothing for the rest of the session.
	var beaten: Object = _a_world()
	var beaten_front := FireFront.new(_open_ground())
	beaten.light_fire(Vector3(0.0, 0.0, 0.0), 0.005)
	_run(beaten, beaten_front, 600.0)
	_check("a_fire_a_full_load_put_out_lights_nothing_ever", _alight(beaten) == 0,
		"%d fire(s) ten minutes later" % _alight(beaten))

	var fierce: Object = _a_world()
	var fierce_front := FireFront.new(_open_ground())
	fierce.light_fire(Vector3(0.0, 0.0, 0.0), 1.0)
	_run(fierce, fierce_front, FireFront.SPREAD_SECONDS * 1.5)
	_check("and_the_same_fire_left_burning_takes_the_hillside_with_it",
		_alight(fierce) > 1,
		"%d fire(s) after %.0f s at full strength" % [_alight(fierce),
			FireFront.SPREAD_SECONDS * 1.5])

	# AND A HALF-HEARTED DROP BUYS YOU ABOUT THIRTEEN SECONDS.
	#
	# This is the one the suite got wrong first, by assuming that knocking a fire below the
	# threshold kept it there. It does not: regrowth is two per cent a second, so a fire
	# left at half the threshold is back over it in about thirteen and spreads at
	# forty-three -- which is `agents.md`'s own sentence turned into a number, that "a full
	# load spread over a hillside is a two-minute round trip for nothing".
	var half: Object = _a_world()
	var half_front := FireFront.new(_open_ground())
	half.light_fire(Vector3(0.0, 0.0, 0.0), FireFront.SPREAD_FROM * 0.5)
	var until: float = 0.0
	while _alight(half) < 2 and until < 180.0:
		_run(half, half_front, 1.0)
		until += 1.0
	_check("but_a_fire_left_half_out_is_spreading_again_within_a_minute",
		_alight(half) == 2 and until < 60.0,
		"lit its first neighbour %.0f s after the drop, against %.0f s from full strength"
		% [until, FireFront.SPREAD_SECONDS])
	beaten.teardown()
	fierce.teardown()
	half.teardown()
	_sections += 1


## ---- and it stops -----------------------------------------------------------------------

## THE CAP HOLDS, which is the losing condition and therefore the end of the job.
##
## Run for long enough that an uncapped front would have taken the island: twenty minutes at
## the rate above is hundreds of fires.
func _and_it_stops_at_the_cap() -> void:
	var world: Object = _a_world()
	var front := FireFront.new(_open_ground())
	for fire in Terrain.fires():
		world.light_fire(fire["position"], float(fire["strength"]))
	var started: int = _alight(world)
	_run(world, front, 1200.0)
	_check("the_world_starts_with_the_fires_terrain_places", started == Terrain.fires().size(),
		"%d fires" % started)
	_check("and_an_unfought_front_reaches_the_cap_and_stops",
		_alight(world) == FireFront.MAX_FIRES,
		"%d of %d after twenty minutes" % [_alight(world), FireFront.MAX_FIRES])
	# AND IT NEVER GOES PAST IT, which is the check that a `while` loop inside `tick` cannot
	# overshoot by banking more than one spread's worth in a single step.
	_run(world, front, 600.0)
	_check("and_does_not_creep_past_it_ten_minutes_later",
		_alight(world) == FireFront.MAX_FIRES,
		"%d of %d" % [_alight(world), FireFront.MAX_FIRES])
	world.teardown()
	_sections += 1


## ---- and it lands somewhere you can fly to ----------------------------------------------

## NO FIRE CATCHES INSIDE A MOUNTAIN, and none leaves the island.
##
## A fire inside a hill is worse than an aeroplane inside one: the column is 260 m of smoke
## coming out of solid rock with nothing at the bottom of it to aim at. The placed fires get
## their clearance from the generator and a fire that SPREADS has to earn the same one.
func _and_a_fire_cannot_catch_inside_a_mountain() -> void:
	var solid: Array[Dictionary] = Terrain.boxes()
	# AN EMPTY LIST IS NOTHING SOLID. `FireFront.new([])` used to fall back to the whole island, so every rate check in
	# this file -- all of them built on `_open_ground()`, which says NOTHING SOLID ANYWHERE -- ran against every
	# mountain, and would have run against anything else put on the island.
	var bare := FireFront.new(_open_ground())
	_check("a_front_handed_open_ground_keeps_no_fire_out_of_anywhere", bare.solid_count() == 0,
		"%d solid boxes, from an empty list" % bare.solid_count())
	var world: Object = _a_world()
	var front := FireFront.new(solid)
	_check("and_one_handed_the_island_keeps_them_out_of_all_of_it",
		front.solid_count() == solid.size() and solid.size() > 0,
		"%d of %d" % [front.solid_count(), solid.size()])
	for fire in Terrain.fires():
		world.light_fire(fire["position"], float(fire["strength"]))
	_run(world, front, 1200.0)
	var inside: PackedStringArray = []
	var overboard: PackedStringArray = []
	for row in world.fire_states():
		var at: Vector3 = (row as Dictionary)["position"]
		if maxf(absf(at.x), absf(at.z)) > Terrain.FIRE_REACH:
			overboard.append("(%.0f, %.0f)" % [at.x, at.z])
		elif not Terrain.can_burn(solid, at):
			inside.append("(%.0f, %.0f)" % [at.x, at.z])
	_check("no_fire_in_the_world_is_inside_the_scenery", inside.is_empty(),
		"%d fires, %s" % [_alight(world),
			"all clear" if inside.is_empty() else inside])
	_check("and_none_of_them_has_left_the_island", overboard.is_empty(),
		"reach %.0f m, %s" % [Terrain.FIRE_REACH,
			"all inside" if overboard.is_empty() else overboard])
	world.teardown()
	_sections += 1


## ---- and it says so ----------------------------------------------------------------------

## THE DEBRIEF IS A SENTENCE WITH THE NUMBERS IN IT, and it changes as the job does.
##
## Three states, because a count on its own is not a score: nine of twenty-four means nothing
## until you know that twenty-four is the end of it.
func _the_board_says_how_the_job_is_going() -> void:
	var world: Object = _a_world()
	var front := FireFront.new(_open_ground())
	world.light_fire(Vector3(0.0, 0.0, 0.0), 1.0)
	_run(world, front, 1.0)
	var burning: String = front.debrief()
	_check("the_board_says_how_many_are_alight_and_what_the_cap_is",
		burning.contains("1 fires alight") and burning.contains(str(FireFront.MAX_FIRES)),
		burning)

	# AND IT COUNTS WHAT WENT OUT. A fire is retired from the wire when its strength reaches
	# zero, so "disappeared" and "was put out" are the same event -- see `water`'s own check.
	var dying: Object = _a_world()
	var dying_front := FireFront.new(_open_ground())
	dying.light_fire(Vector3(0.0, 0.0, 0.0), 0.005)
	_run(dying, dying_front, 4.0)
	_check("and_a_fire_that_goes_out_is_counted",
		dying_front.doused() == 1 and dying_front.alight() == 0,
		"%d alight, %d put out" % [dying_front.alight(), dying_front.doused()])
	_check("and_says_so_when_they_are_all_out",
		dying_front.debrief().contains("EVERY FIRE IS OUT"), dying_front.debrief())

	# AND SAYS THE ISLAND IS LOST AT THE CAP.
	var lost: Object = _a_world()
	var lost_front := FireFront.new(_open_ground())
	for fire in Terrain.fires():
		lost.light_fire(fire["position"], float(fire["strength"]))
	_run(lost, lost_front, 1200.0)
	_check("and_says_the_island_is_lost_at_the_cap",
		lost_front.debrief().contains("LOST"), lost_front.debrief())
	world.teardown()
	dying.teardown()
	lost.teardown()
	_sections += 1


## ---- the bench ---------------------------------------------------------------------------

func _a_world() -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	return world


## NOTHING SOLID ANYWHERE, for the sections that are about the RATE rather than the place.
## A real box list would have a fire on a ridge failing six attempts and spreading slower,
## which is correct behaviour and is measured in its own section.
func _open_ground() -> Array[Dictionary]:
	return []


## Step the world and the front together, for `seconds` of simulated time. Both, because a
## fire's strength is the simulation's and the spread is the front's, and the interesting
## number is what happens when the two run against each other.
func _run(world: Object, front: FireFront, seconds: float) -> void:
	for i in range(int(seconds / TICK)):
		world.tick(TICK)
		front.tick(world, TICK)


func _alight(world: Object) -> int:
	return (world.fire_states() as Array).size()


## The smallest fire in the world, which is the one most recently lit: everything else has
## been burning and growing back.
func _the_newest(world: Object) -> Dictionary:
	var youngest: Dictionary = {}
	for row in world.fire_states():
		var fire: Dictionary = row
		if youngest.is_empty() or float(fire["strength"]) < float(youngest["strength"]):
			youngest = fire
	return youngest


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
