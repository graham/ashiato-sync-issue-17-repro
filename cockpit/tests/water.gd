extends Node
## Headless: does the water leave the aeroplane, land in a line, and put a fire out?
##
##   Godot --headless --path cockpit res://tests/water.tscn
##
## THE SAME PROBLEM THE GUN HAD, and the same answer. Almost nothing about a water bomber
## can be judged by looking: a drop is over in five seconds, the load is eighty separate
## masses of water falling at different times, and whether the fire went out is a number
## nobody can read off a screenshot. So every claim about this aeroplane is measured here.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const TANKER: int = 16
## How long a full tank takes to empty, and to fill. The simulation's numbers -- see
## kDropSeconds and kScoopSeconds -- restated here because a test that read them off the
## thing it is testing would agree with any answer at all.
const DROP_SECONDS: float = 5.0
const SCOOP_SECONDS: float = 12.0
## Where the island stops. Outside this there is nothing solid underneath, which is what
## makes a scooping run a scooping run.
const COAST: float = 7200.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[water] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_an_aeroplane_built_round_a_tank()
	await _the_doors_empty_it()
	await _the_water_lands_in_a_line_and_puts_a_fire_out()
	await _a_fire_left_alone_comes_back()
	await _it_fills_from_the_sea_and_not_from_a_field()
	_it_floats_at_rest_and_fills_nothing()
	_in_the_air_the_hull_does_nothing()
	_it_takes_off_from_the_water()
	_it_lands_on_the_water_and_comes_to_rest()
	_on_land_at_sea_level_it_is_not_in_the_water()
	_the_cockpit_has_a_handle_for_it()
	_a_gauge_at_both_seats_says_what_is_left()
	_the_room_it_promises_is_inside_the_skin_it_draws()
	_a_client_asks_and_everybody_sees_it()
	await _the_level_draws_a_release_it_is_told_about()
	_finish()


## ---- the aeroplane -------------------------------------------------------------------

## SEVENTEEN KINDS, AND THE SEVENTEENTH COST A BIT ON THE WIRE.
##
## `VehicleKind` was four bits and sixteen kinds filled it exactly. This is the check that
## the widening actually happened on both sides of the wire rather than only in the table:
## a kind of 16 written into a four-bit field is silently dropped, and what comes out the
## other end is a POD -- which is a bug that looks like a networking fault.
func _an_aeroplane_built_round_a_tank() -> void:
	# THE TWO TABLES OF KINDS AGREE, which is the check worth making rather than "there are
	# seventeen of them": the enum in `Sim` and the table in the C++ are two lists that have
	# to be the same length, and a kind that exists in one and not the other is a craft the
	# game can ask for and the simulation has never heard of.
	var world: Object = ClassDB.instantiate("CockpitWorld")
	_check("the_game_and_the_simulation_agree_about_how_many_kinds_there_are",
		Sim.Kind.size() == int(world.kind_count()),
		"%d in the enum, %d in the table, last is %s" % [Sim.Kind.size(),
			int(world.kind_count()), Sim.kind_name(Sim.Kind.size() - 1)])
	var geometry: Dictionary = Sim.geometry_of(TANKER)
	_check("the_seventeenth_is_the_water_bomber",
		String(geometry.get("name", "")) == "tanker",
		"kind %d is %s" % [TANKER, geometry.get("name", "?")])
	# AND THE SENTINEL MOVED WITH IT. "No kind in particular" was 15, which is the gunship
	# the moment there are seventeen kinds -- and `switch_kind` reads anything below the
	# number of kinds as a kind somebody named. A player pressing "next craft" would have
	# been taken to a gunship every time.
	_check("and_no_kind_in_particular_is_out_of_range_of_every_kind",
		Sim.NO_KIND >= Sim.Kind.size(), "%d against %d kinds" % [Sim.NO_KIND,
			Sim.Kind.size()])
	# THE DOORS ARE ON THE BUS, and they are the only control on this aeroplane that no
	# other aeroplane has.
	var fitted: Array = Sim.schema_of(TANKER).get("channels", [])
	var doors: String = ""
	for entry in fitted:
		if int((entry as Dictionary).get("channel", -1)) == Sim.Channel.DROP:
			doors = String((entry as Dictionary).get("name", ""))
	_check("and_it_is_fitted_with_tank_doors", doors != "",
		"the bus carries %s" % ["nothing on channel 6" if doors == "" else doors])
	# AND NO OTHER CRAFT HAS TANK DOORS. A channel a craft is not fitted with is REFUSED rather
	# than quietly doing nothing, so a lever that turned up on every aeroplane would be a lever
	# that does nothing on all but one of them. The V-22's ramp is on the same channel -- the
	# doors a load leaves by -- and it is fitted as the ramp, with no tank behind it: another
	# craft on channel 6 must be named for something else and carry no water.
	var elsewhere: Array[String] = []
	for kind in range(Sim.Kind.size()):
		if kind == TANKER:
			continue
		for entry in (Sim.schema_of(kind).get("channels", []) as Array):
			if int((entry as Dictionary).get("channel", -1)) == Sim.Channel.DROP \
					and (String((entry as Dictionary).get("name", "")) == doors or Sim.carries_water(kind)):
				elsewhere.append(Sim.kind_name(kind))
	_check("and_no_other_craft_is", elsewhere.is_empty(),
		"%s" % ["only the tanker" if elsewhere.is_empty() else elsewhere])


## ---- the drop ------------------------------------------------------------------------

## THE DOORS EMPTY THE TANK IN FIVE SECONDS, AND MAKE WATER WHILE THEY DO.
##
## The tank is a byte on the wire and a float on the server, and the reason for the second
## one is this test: a five-second drop at 120 Hz moves the gauge by four tenths of a step
## per tick, so a tank held in the byte alone rounds back to full every tick and never
## empties at all. That is exactly what the first version did.
func _the_doors_empty_it() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
	var made: Dictionary = world.spawn_pilot(40, TANKER, Vector3(0.0, 300.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -60.0))
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	_check("a_tanker_starts_full", absf(float(world.tank_load(craft)) - 1.0) < 0.01,
		"%.2f of a tank" % world.tank_load(craft))
	_check("and_a_craft_with_no_tank_says_so", float(world.tank_load(
		int(world.spawn_vehicle(1, Vector3(500.0, 300.0, 0.0), 0.0, Vector3.ZERO)))) < 0.0,
		"a light aeroplane has no tank")

	world.set_pilot_input(pilot, {"command_channel": Sim.Channel.DROP,
		"command_value": 1, "command_seq": 1})
	var half: float = -1.0
	var emptied: float = -1.0
	var made_water: int = 0
	for i in range(int(8.0 / TICK)):
		world.tick(TICK)
		made_water = maxi(made_water, (world.shot_states() as Array).size())
		var now: float = float(world.tank_load(craft))
		if half < 0.0 and now <= 0.5:
			half = float(i) * TICK
		if emptied < 0.0 and now <= 0.0:
			emptied = float(i) * TICK
	_check("opening_the_doors_empties_it", emptied > 0.0,
		"empty after %.1f s" % emptied)
	_check("and_it_takes_as_long_as_the_tank_says",
		absf(emptied - DROP_SECONDS) < 0.4 and absf(half - DROP_SECONDS * 0.5) < 0.4,
		"half gone at %.1f s, empty at %.1f, wanted %.1f" % [half, emptied, DROP_SECONDS])
	# AND WHAT CAME OUT IS WATER. Sixteen masses a second for five seconds, of which a
	# good few are in the air at once -- and every one of them is the round the tank is
	# fed rather than something from a gun's table.
	_check("and_what_leaves_it_is_water", made_water > 8,
		"%d masses of water in the air at once" % made_water)
	var loaded: String = ""
	for shot in (world.shot_states() as Array):
		loaded = String((shot as Dictionary).get("ammo_name", ""))
	_check("and_the_two_tables_agree_about_what_that_is",
		loaded == "" or (loaded == "water"
			and String(Ammunition.look(8)["name"]) == "water"),
		"the simulation says %s and the renderer says %s" % [loaded,
			Ammunition.look(8)["name"]])
	# AND THE DOORS SHUT AGAIN. A lever, not a button: what is on the bus is where the
	# handle IS, so closing it has to stop the water.
	world.set_pilot_input(pilot, {"command_channel": Sim.Channel.DROP,
		"command_value": 0, "command_seq": 2})
	for i in range(60):
		world.tick(TICK)
	var quiet: int = (world.shot_states() as Array).size()
	for i in range(240):
		world.tick(TICK)
	_check("and_shutting_them_stops_it",
		(world.shot_states() as Array).size() <= quiet,
		"%d masses still falling, none new" % (world.shot_states() as Array).size())
	world.teardown()
	await get_tree().process_frame


## A DROP IS A RUN, NOT A BOMB.
##
## The two claims that make this aeroplane what it is. What lands is a SWATHE -- long along
## the track and narrow across it, because the water leaves over five seconds while the
## aeroplane keeps flying -- and a fire under that swathe goes out while a fire two hundred
## metres to one side of it does not.
##
## That second half is the whole game. A soft-edged douse would make a sloppy pass worth
## something everywhere; what this aeroplane is about is putting the water ON the fire.
func _the_water_lands_in_a_line_and_puts_a_fire_out() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
	# THREE FIRES ALONG THE TRACK and one well off to the side, all lit before the run so
	# that every one of them is burning while the water is in the air.
	var on_track: Array[int] = []
	for z in [-200.0, -300.0, -400.0]:
		on_track.append(int(world.light_fire(Vector3(0.0, 0.0, z), 1.0)))
	var beside: int = int(world.light_fire(Vector3(240.0, 0.0, -300.0), 1.0))

	var made: Dictionary = world.spawn_pilot(41, TANKER, Vector3(0.0, 55.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -55.0))
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	world.set_pilot_input(pilot, {"command_channel": Sim.Channel.DROP,
		"command_value": 1, "command_seq": 1})
	# WHERE IT ALL LANDED, collected as it happens: a landed record is on the wire for a
	# few ticks and then the round is retired, so a list taken at the end would be empty.
	var wet: Array[Vector3] = []
	for i in range(int(14.0 / TICK)):
		world.tick(TICK)
		for shot in (world.shot_states() as Array):
			var one: Dictionary = shot
			if not bool(one["flying"]) and String(one.get("ammo_name", "")) == "water":
				var at: Vector3 = one["impact"]
				if not wet.has(at):
					wet.append(at)
	_check("a_drop_reaches_the_ground", wet.size() > 20,
		"%d masses of water landed" % wet.size())
	var along := Vector2(1e9, -1e9)
	var across := Vector2(1e9, -1e9)
	for at in wet:
		along = Vector2(minf(along.x, at.z), maxf(along.y, at.z))
		across = Vector2(minf(across.x, at.x), maxf(across.y, at.x))
	var length: float = along.y - along.x
	var width: float = across.y - across.x
	_check("and_what_lands_is_a_swathe_rather_than_a_splash",
		length > 100.0 and width < length * 0.25,
		"%.0f m along the track and %.0f m across it" % [length, width])

	var left: Array[float] = []
	for fire in on_track:
		left.append(_strength_of(world, fire))
	var out_or_nearly: int = 0
	for one in left:
		if one < 0.35:
			out_or_nearly += 1
	_check("and_a_fire_under_it_goes_out", out_or_nearly >= 1,
		"the three on the track are left at %s" % [left])
	_check("and_a_fire_beside_it_does_not", _strength_of(world, beside) > 0.9,
		"the one 240 m to one side is at %.2f" % _strength_of(world, beside))
	# AND THE TANK IS THE LIMIT. One pass is one load: an aeroplane that could keep
	# dropping would make the flight back to the sea pointless, which is most of the game.
	_check("and_the_tank_is_empty_afterwards", float(world.tank_load(craft)) <= 0.01,
		"%.2f of a tank left" % world.tank_load(craft))
	world.teardown()
	await get_tree().process_frame


## A FIRE LEFT ALONE COMES BACK, which is what makes a half-hearted drop worth nothing.
##
## Slower than the round trip to the sea, deliberately: a fire you have knocked down is one
## you have time to come back and finish, not one that races you.
func _a_fire_left_alone_comes_back() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var fire: int = int(world.light_fire(Vector3(0.0, 0.0, 0.0), 0.4))
	var was: float = _strength_of(world, fire)
	for i in range(int(20.0 / TICK)):
		world.tick(TICK)
	var now: float = _strength_of(world, fire)
	_check("a_fire_left_alone_grows_back", now > was + 0.2,
		"%.2f after twenty seconds, from %.2f" % [now, was])
	_check("but_not_faster_than_a_tanker_can_turn_round", now < was + 0.6,
		"it gained %.2f in twenty seconds" % (now - was))
	# AND A FIRE THAT IS OUT IS GONE. Not a flame at one step above zero that nothing can
	# ever put out: the wire quantises strength to a sixty-fourth, so "out" has to be a
	# threshold and the entity has to be retired when it is crossed.
	var doused: int = int(world.light_fire(Vector3(400.0, 0.0, 0.0), 0.01))
	# AND ITS SPENT TIME AFTER THAT: a fire that has gone out stays on the wire as long as a landed round does, so every
	# client hears that it went out before sync forgets it (`spent_seconds`). Asked of the world, not typed here.
	var kept: int = int(ceil(float(world.spent_seconds()) / TICK)) if world.has_method("spent_seconds") else 3
	for i in range(20 + kept):
		world.tick(TICK)
	_check("and_a_fire_that_is_out_is_taken_off_the_wire",
		_strength_of(world, doused) < 0.0, "%d fires left" % (world.fire_states() as Array).size())
	world.teardown()
	await get_tree().process_frame


## ---- and filling it again --------------------------------------------------------------

## IT FILLS FROM THE SEA AND NOT FROM A FIELD.
##
## Three conditions and all of them together: low, inside the speed band, and with nothing
## solid underneath. Any two of them is an aeroplane doing something else -- fast and low
## over the sea is a transit, and slow and low over the land is a landing.
##
## The last of the three is asked of the PHYSICS rather than of the terrain: a ray straight
## down that finds nothing is over water, because the island is a solid slab and the sea is
## not. So the simulation needs to know nothing about where the coast is -- which is as
## well, because the coast is generated in the game layer and is not replicated at all.
func _it_fills_from_the_sea_and_not_from_a_field() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
	# THE RULE FIRST, asked of four aeroplanes put into four situations and ticked once.
	# Sharper than watching a gauge: what is being checked is the three conditions, and
	# three conditions are three separate ways to be wrong.
	_check("a_low_slow_run_over_open_water_is_a_scooping_run",
		_would_scoop(world, 50, Vector3(0.0, 8.0, COAST + 1200.0), 45.0),
		"eight metres up, 45 m/s, no ground underneath")
	_check("and_the_same_run_over_a_field_is_not",
		not _would_scoop(world, 51, Vector3(0.0, 8.0, 0.0), 45.0),
		"the island is solid and you cannot scoop a field")
	_check("and_neither_is_one_too_high_to_touch_the_water",
		not _would_scoop(world, 52, Vector3(2000.0, 90.0, COAST + 1200.0), 45.0),
		"ninety metres up")
	_check("and_neither_is_one_going_too_fast_to_scoop",
		not _would_scoop(world, 53, Vector3(4000.0, 8.0, COAST + 1200.0), 110.0),
		"a hundred and ten metres a second is a transit, not a run")

	# AND THEN THE RATE. Flown for real: the aeroplane is emptied on the way in, the doors
	# are shut, and what it picks up is measured against how long it actually spent in the
	# water. Nothing holds it on the line -- it climbs gently out of the scoop, which is
	# what an aeroplane at full power close to the surface does and is the reason a real
	# run is a thing pilots practise.
	var made: Dictionary = world.spawn_pilot(54, TANKER,
		Vector3(-4000.0, 3.0, COAST + 1200.0), 0.0, Vector3(0.0, 0.0, -45.0))
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	# HELD ON THE WATER, WHICH IS WHAT THE RUN ACTUALLY IS.
	#
	# An aeroplane at forty-five metres a second is comfortably above its own stall, so left
	# alone it flies gently up and out of the sea; held down with forward stick it goes in.
	# A scooping run is a pilot doing neither for twelve seconds, so the test flies it --
	# badly, on two gains and a height -- because what is being measured is how fast the
	# tank fills and not how well a tanker holds a line by accident.
	world.set_pilot_input(pilot, {"throttle": 0.5,
		"command_channel": Sim.Channel.DROP, "command_value": 1, "command_seq": 1})
	for i in range(int(6.0 / TICK)):
		_hold_it_down(world, craft, pilot)
		world.tick(TICK)
	_check("a_tanker_over_the_sea_can_empty_itself_first",
		float(world.tank_load(craft)) <= 0.01, "%.2f left" % world.tank_load(craft))
	world.set_pilot_input(pilot, {"command_channel": Sim.Channel.DROP,
		"command_value": 0, "command_seq": 2})
	var was: float = float(world.tank_load(craft))
	var lowest: float = 1e9
	var scooping: int = 0
	for i in range(int(10.0 / TICK)):
		_hold_it_down(world, craft, pilot)
		world.tick(TICK)
		lowest = minf(lowest, float((world.vehicle_state(craft) as Dictionary)
			.get("position", Vector3.ZERO).y))
		if bool(world.is_scooping_now(craft)):
			scooping += 1
	var gained: float = float(world.tank_load(craft)) - was
	var wet_seconds: float = float(scooping) * TICK
	_check("skimming_the_sea_fills_the_tank", gained > 0.1 and wet_seconds > 1.0,
		"%.2f of a tank in %.1f s on the water, and it got down to %.1f m" % [
			gained, wet_seconds, lowest])
	# AND AT THE RATE THE AEROPLANE SAYS: twelve seconds for a full tank, which is the real
	# machine's number and the reason a sortie is a round trip rather than a hover.
	_check("and_it_fills_at_the_rate_the_aeroplane_says",
		absf(gained - wet_seconds / SCOOP_SECONDS) < 0.05,
		"%.2f gained against %.2f wanted" % [gained, wet_seconds / SCOOP_SECONDS])
	world.teardown()
	await get_tree().process_frame


## FLY THE RUN, badly and on purpose: hold six metres with the elevator, on the height
## error and the climb rate. Two gains and no integral -- it is not trying to be an
## autopilot, it is standing in for the pilot who would be flying this.
const SKIM_HEIGHT: float = 6.0



## ---- and it floats at rest, and a floating tanker fills nothing -------------------------

## WHERE THE CREW STAND AND WHERE THE HULL IS DEEPEST, in the craft's own frame. TYPED, not
## read off `tanker_shape` or the airframe: the pilot's seat pose is (-0.55, -0.50, -7.40) and a
## station's origin IS its floor; the drawn hull's lowest point is at its widest section, h -1.68
## at z -3.76. A check that read these off the code that places the waterline would move with it.
##
## THE WATERLINE BETWEEN THEM IS A CHOICE, AND THE BRACKET IS THE FACT. `tanker_shape` puts the
## sea at h -1.09, midway, because nobody has measured a CL-415 at rest and those two are the only
## things this model promises about it (craft/tanker/sources.md). This suite does not check -1.09.
## It checks the bracket, off the physics after it settles, because the bracket is what can be
## wrong: a floor under the sea is a flooded cabin, and a keel over it is an aeroplane hovering.
const PILOT_FLOOR := Vector3(-0.55, -0.50, -7.40)
## THE KEEL LINE, bow to stern: the bottom of each drawn section (centre height less half-height,
## off the loft's stations) and of the planing keel under it. A LINE AND NOT A POINT, and that was
## learnt by failing: the first version checked one point, the deepest one on a LEVEL hull, and the
## aeroplane floats a few degrees nose-up -- as a stepped flying-boat hull does -- so that point rose
## out of the water while the stern sat deep, and the check called a floating aeroplane "hovering".
## What has to be wet is the hull's lowest point IN THE ATTITUDE IT IS ACTUALLY IN.
const KEEL_LINE: Array[Vector3] = [
	Vector3(0.0, -1.44, -8.22), Vector3(0.0, -1.68, -3.76), Vector3(0.0, -1.61, 0.35),
	Vector3(0.0, -1.45, 3.37), Vector3(0.0, -1.61, 7.00)]
## How long to let a dropped aeroplane settle, and how still it must be for the last second.
const SETTLE_SECONDS: int = 20
const STILL: float = 0.05
## How long the doors are open first, to leave room in the tank to prove nothing refills it.
const DRAIN_SECONDS: float = 2.0
## HOW FAR FROM THE SURFACE "IN THE WATER" AND "ABOVE IT" MAY REACH. A bracket with only one side
## is a check that passes vacuously: the first red run of this suite reported the keel "in the water"
## while it was 1,328 m under it, sinking. Three metres is more than this hull is deep (2.9 m, keel
## to crown), so a keel further down than that has taken the whole aeroplane with it, and a floor
## further up than that is an aeroplane in the air.
const NEAR_THE_SURFACE: float = 3.0


## A WATER BOMBER SET DOWN ON THE SEA FLOATS THERE, AND FILLS NOTHING.
##
## THE USER'S RULING, BOTH HALVES. On 2026-09-17: landing on the water floats the aeroplane and
## fills nothing; refilling stays the scoop run, 25 to 62 m/s, exactly as `is_scooping` requires.
## The reason is balance and not physics -- it preserves the round trip `FireFront.SPREAD_SECONDS`
## was tuned against, and it keeps the skill in the manoeuvre. The scoop half is held above by
## `_it_fills_from_the_sea_and_not_from_a_field`; this is the half that is new.
##
## AND THE BEFORE, which was `tests/afloat_probe.gd` and is retired by this: a stopped tanker a
## metre over the sea was in FREE FALL -- 4.83 m in the first second, g to two figures -- and 506 m
## under the sea by the eleventh, because `sail_boat` was dispatched on `Model::Boat` and a water
## bomber is `Model::Airplane`. Nothing in the simulation knew the sea was there.
##
## WITH A CONTROL THAT MUST STILL SINK. "It did not fall through" is also exactly what a spawn that
## never moved looks like, so an ordinary aeroplane is put on the same sea at the same moment and
## has to go under -- `lane/cooling`'s lesson from a cooling tower an aeroplane flew straight
## through, where the check that found it was the one that said WHERE the thing went.
func _it_floats_at_rest_and_fills_nothing() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
	var made: Dictionary = world.spawn_pilot(70, TANKER,
		Vector3(0.0, 1.0, COAST + 1200.0), 0.0, Vector3.ZERO)
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	# THE CONTROL, 400 m away so the two never meet: a light aeroplane, which has no hull.
	var control: Dictionary = world.spawn_pilot(71, Sim.Kind.PLANE,
		Vector3(400.0, 1.0, COAST + 1200.0), 0.0, Vector3.ZERO)
	var plane: int = int(control.get("vehicle", 0))
	world.set_pilot_input(int(control.get("pilot", 0)), {"throttle": 0.0})
	# THE DOORS OPEN FOR TWO SECONDS FIRST, so the tank has room in it: a full tank cannot show
	# whether something is filling it.
	world.set_pilot_input(pilot, {"throttle": 0.0, "command_channel": Sim.Channel.DROP,
		"command_value": 1, "command_seq": 1})
	var track: PackedStringArray = []
	var control_track: PackedStringArray = []
	var drained_to: float = -1.0
	var scooped: bool = false
	var last_y: float = 1.0
	var moved: float = INF
	for second in range(SETTLE_SECONDS):
		var before: float = float((world.vehicle_state(craft).get("position", Vector3.ZERO) as Vector3).y)
		for i in range(int(1.0 / TICK)):
			world.tick(TICK)
			if float(second) + float(i) * TICK >= DRAIN_SECONDS and drained_to < 0.0:
				world.set_pilot_input(pilot, {"throttle": 0.0,
					"command_channel": Sim.Channel.DROP, "command_value": 0, "command_seq": 2})
				drained_to = float(world.tank_load(craft))
			if drained_to >= 0.0 and bool(world.is_scooping_now(craft)):
				scooped = true
		var at: Vector3 = world.vehicle_state(craft).get("position", Vector3.ZERO)
		var drift: Vector3 = world.vehicle_state(craft).get("velocity", Vector3.ZERO)
		moved = absf(at.y - before)
		last_y = at.y
		track.append("t+%ds h %.2f drifting %.2f m/s" % [second + 1, at.y,
			Vector2(drift.x, drift.z).length()])
		control_track.append("t+%ds h %.1f" % [second + 1,
			(world.vehicle_state(plane).get("position", Vector3.ZERO) as Vector3).y])
	var state: Dictionary = world.vehicle_state(craft)
	var at: Vector3 = state.get("position", Vector3.ZERO)
	var turned := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
	var sea: float = _sea_at(world, at)
	var floor_at: Vector3 = at + turned * PILOT_FLOOR - Vector3(0.0, sea, 0.0)
	var keel_low: float = _keel_low(at, turned) - sea
	var load_now: float = float(world.tank_load(craft))
	var plane_at: Vector3 = world.vehicle_state(plane).get("position", Vector3.ZERO)
	print("[water] a stopped tanker released 1 m over the sea: %s; at rest %.1f degrees nose-up, on a swell standing at h %.2f"
		% [", ".join(track), _nose_up(turned), sea])
	print("[water] and the control aeroplane beside it: %s" % ", ".join(control_track))

	_check("a_water_bomber_set_down_on_the_sea_floats_there_rather_than_sinking",
		last_y > -5.0 and moved < STILL,
		"h %.2f after %d s, moved %.3f m in the last second" % [last_y, SETTLE_SECONDS, moved])
	_check("with_the_crews_floor_above_the_sea",
		floor_at.y > 0.0 and floor_at.y < NEAR_THE_SURFACE,
		"the pilot's floor is at h %.2f, %.2f m %s the sea" % [floor_at.y, absf(floor_at.y),
			"above" if floor_at.y > 0.0 else "UNDER"])
	_check("and_its_keel_in_it",
		keel_low < 0.0 and keel_low > -NEAR_THE_SURFACE,
		"the hull's lowest point is at h %.2f, %.2f m %s the sea, floating %.1f degrees nose-up"
			% [keel_low, absf(keel_low), "under" if keel_low < 0.0 else "ABOVE -- it is hovering",
				_nose_up(turned)])
	_check("and_it_floats_the_right_way_up", turned.y.y > 0.95,
		"its up axis is %.3f of vertical" % turned.y.y)
	# THE RULING'S NEW HALF: nothing refills a tank on an aeroplane that is sitting on the water.
	_check("and_a_floating_tanker_fills_nothing",
		drained_to >= 0.0 and drained_to < 0.9 and absf(load_now - drained_to) < 0.005 and not scooped,
		"drained to %.2f, %.2f after floating, scooping %s" % [drained_to, load_now, scooped])
	# AND THE CONTROL. Without this every check above would pass for a craft that never moved.
	# SINKS, OR SINCE lane/combat IS DESTROYED BY THE SEA IT HAS GONE INTO: an aeroplane that does not float is judged the
	# tick its box goes under water (`judge_impacts`) and frozen there as a wreck, which is the same proof that nothing
	# was holding it up -- the rule reads the same "under the water" this control was put here to show.
	var drowned: bool = world.has_method("hull_state") and String(world.hull_state(plane).get("cause_name", "")) == "water"
	_check("while_an_aeroplane_that_is_not_a_boat_still_sinks_beside_it", plane_at.y < -20.0 or drowned,
		"the light aeroplane is at h %.1f%s" % [plane_at.y, ", destroyed by the sea" if drowned else ""])
	world.teardown()



## ---- and it is still an aeroplane -----------------------------------------------------

## THE USER'S WORDS SET THE BAR, AND FLOATING IS ONLY HALF OF IT: "fix the buoyancy problem and
## have it make the plane work correctly -- both as a plane and floats on water." The checks below
## are the half that is easy to break, because a buoyancy term that leaked into flight would change
## how the aeroplane climbs and turns while every existing flight suite stayed green.

## THE HULL'S READOUT, asked by name so that a library without it fails cleanly rather than
## stopping the suite dead on a missing method (which hangs, and reports nothing).
func _can_read_the_hull(world: Object) -> bool:
	return world.has_method("hull_wet")


## IN THE AIR, THE HULL DOES NOTHING -- EXACTLY NOTHING, NOT A LITTLE.
##
## `alight` runs after `fly_airplane` on every tick of every flying boat, and returns before a
## single force is touched when no probe is under the sea. That is a claim about code, so it is
## held here as a claim about a number: `hull_wet` is what `alight` returned, and in flight it has
## to be ZERO, not small. A tolerance here would let a buoyancy term leak into the climb and the
## turn at a size nothing else notices.
##
## FLOWN, NOT PLACED: throttle, pitch and roll through the pilot's input, a climb and a turn, for
## thirty seconds from three hundred metres.
func _in_the_air_the_hull_does_nothing() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
	if not _can_read_the_hull(world):
		_check("the_simulation_says_how_wet_a_flying_boats_hull_is", false,
			"CockpitWorld has no hull_wet -- this library predates the flying boat")
		world.teardown()
		return
	var made: Dictionary = world.spawn_pilot(72, TANKER,
		Vector3(0.0, 300.0, COAST + 1200.0), 0.0, Vector3(0.0, 0.0, -55.0))
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	var most: float = 0.0
	var lowest: float = INF
	var steepest: float = 0.0
	for i in range(int(30.0 / TICK)):
		var state: Dictionary = world.vehicle_state(craft)
		var going: Vector3 = state.get("velocity", Vector3.ZERO)
		var facing := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
		var bank: float = rad_to_deg(asin(clampf(-facing.x.y, -1.0, 1.0)))
		steepest = maxf(steepest, absf(bank))
		# A GENTLE CLIMB, WITH A TWENTY-DEGREE TURN HELD IN THE MIDDLE TEN SECONDS. A BANK HELD, not a
		# roll held: the stick commands a roll RATE, and the first version of this held it open for ten
		# seconds, rolled the aeroplane over and spiralled it into the sea -- where its hull got wet, and
		# this check blamed the buoyancy for a pilot's mistake.
		var wanted: float = 20.0 if i * TICK >= 10.0 and i * TICK < 20.0 else 0.0
		world.set_pilot_input(pilot, {"throttle": 0.8,
			"pitch": clampf((3.0 - going.y) * 0.08, -0.4, 0.4),
			"roll": clampf((wanted - bank) * 0.02, -0.3, 0.3)})
		world.tick(TICK)
		most = maxf(most, float(world.hull_wet(craft)))
		lowest = minf(lowest, float((world.vehicle_state(craft).get("position", Vector3.ZERO) as Vector3).y))
	_check("in_the_air_a_flying_boats_hull_does_exactly_nothing", most == 0.0 and lowest > 50.0,
		"the most the hull was wet in thirty seconds of climbing and a %.0f-degree turn was %s, never below h %.0f"
			% [steepest, most, lowest])
	world.teardown()


## HOW FAST IT HAS TO BE GOING BEFORE THE PILOT PULLS BACK, m/s. The tanker stalls at 40
## (`stall_speed`, cockpit_world.cpp); a rotation at forty-five is the margin a pilot flies to.
const ROTATE_AT: float = 45.0
## HOW HARD A HAND-OVER MAY BE, as a change of vertical speed over a tenth of a second, in g. A
## transport's rotation is a tenth to a fifth of a g on top of one; half a g in a tenth of a
## second is the hull being flung off the water by its springs, which is a jolt anybody would feel.
const NO_JOLT_G: float = 0.5


## IT TAKES OFF FROM THE WATER, AND THE SEA HANDS OVER TO THE WING WITHOUT A JOLT.
##
## THE CHECK THAT SAYS WHETHER THE EXTRACTION IS RIGHT. A hull held to the sea by four springs and
## a drag that never lets go can refuse to unstick: forty-eight kilonewtons of thrust against it is
## an aeroplane taxiing for ever. `alight` scales the drag by how wet the hull is, so drag and
## buoyancy fade together as the wing takes the weight. If that is wrong, this is where it shows.
##
## FROM REST, THROUGH THE PILOT'S HANDS: settled on the sea, full throttle, nose held level until
## it is doing ROTATE_AT, then a climb asked of the stick.
func _it_takes_off_from_the_water() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
	if not _can_read_the_hull(world):
		world.teardown()
		return
	# OUT TO SEA, for the reason the landing below gives: a take-off run is several hundred metres.
	var made: Dictionary = world.spawn_pilot(73, TANKER,
		Vector3(0.0, 1.0, COAST + 1200.0), PI, Vector3.ZERO)
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	world.set_pilot_input(pilot, {"throttle": 0.0})
	for i in range(int(10.0 / TICK)):
		world.tick(TICK)
	var afloat_before: float = float(world.hull_wet(craft))
	var unstuck_at: float = -1.0
	var unstuck_speed: float = 0.0
	var touched_again: bool = false
	var worst_jolt: float = 0.0
	var history: Array[float] = []
	var track: PackedStringArray = []
	var went: float = 0.0
	var dry: bool = false
	var hops: Array[Dictionary] = []
	var flew_at: float = -1.0
	for i in range(int(90.0 / TICK)):
		var state: Dictionary = world.vehicle_state(craft)
		var going: Vector3 = state.get("velocity", Vector3.ZERO)
		var speed: float = going.length()
		# ON THE STEP UNTIL ROTATION: a little forward stick holding the climb at nothing, which is how
		# a seaplane's take-off run is flown. With the stick merely left alone, the hull skipped 0.90 m
		# clear of a swell crest at 37.7 m/s -- below the stall -- and came back down before it flew.
		var pitch: float = clampf((0.0 - going.y) * 0.1 - 0.05, -0.3, 0.0)
		if speed >= ROTATE_AT:
			pitch = clampf((4.0 - going.y) * 0.08, -0.3, 0.4)
		world.set_pilot_input(pilot, {"throttle": 1.0, "pitch": pitch})
		world.tick(TICK)
		var wet: float = float(world.hull_wet(craft))
		var now_going: Vector3 = world.vehicle_state(craft).get("velocity", Vector3.ZERO)
		history.append(now_going.y)
		var t: float = float(i + 1) * TICK
		var here_at: Vector3 = world.vehicle_state(craft).get("position", Vector3.ZERO)
		var here_turned := Basis(world.vehicle_state(craft).get("basis", Quaternion.IDENTITY) as Quaternion)
		var clear: float = _clearance(world, here_at, here_turned)
		if wet == 0.0 and not dry:
			dry = true
			hops.append({"from": t, "speed": now_going.length(), "rose": clear, "for": 0.0})
		elif wet == 0.0 and dry:
			hops[-1]["rose"] = maxf(float(hops[-1]["rose"]), clear)
			hops[-1]["for"] = t - float(hops[-1]["from"])
		elif wet > 0.0:
			dry = false
		if unstuck_at < 0.0 and wet == 0.0:
			unstuck_at = t
			unstuck_speed = now_going.length()
		if flew_at < 0.0 and clear > OUT_OF_THE_WATER:
			flew_at = t
		elif flew_at >= 0.0 and wet > 0.0:
			touched_again = true
		# THE JOLT: vertical speed changed over a tenth of a second, around the hand-over.
		if unstuck_at >= 0.0 and t - unstuck_at <= 3.0 and history.size() > 12:
			worst_jolt = maxf(worst_jolt, absf(history[-1] - history[-13]) / 0.1 / 9.81)
		if i % int(10.0 / TICK) == 0:
			var at: Vector3 = world.vehicle_state(craft).get("position", Vector3.ZERO)
			track.append("t+%ds %.0f m/s h %.1f wet %.2f" % [int(t), now_going.length(), at.y, wet])
	var end_at: Vector3 = world.vehicle_state(craft).get("position", Vector3.ZERO)
	went = end_at.y
	print("[water] a take-off from the sea at full power: %s; unstuck at %.1f s doing %.1f m/s, worst hand-over %.2f g"
		% [", ".join(track), unstuck_at, unstuck_speed, worst_jolt])
	var said: PackedStringArray = []
	for hop in hops:
		said.append("at %.1f s doing %.1f m/s, clear %.2f m for %.2f s" % [hop["from"], hop["speed"],
			hop["rose"], hop["for"]])
	print("[water] every time it left the water: %s" % " | ".join(said))
	_check("a_flying_boat_afloat_at_rest_is_actually_in_the_water_before_it_starts",
		afloat_before > 0.0, "the hull was %.3f wet before the throttle went up" % afloat_before)
	_check("and_at_full_power_it_unsticks_from_the_water",
		unstuck_at > 0.0 and unstuck_at < 60.0,
		"unstuck %.1f s after full power, doing %.1f m/s" % [unstuck_at, unstuck_speed]
			if unstuck_at > 0.0 else "still on the water after ninety seconds")
	# ONCE IT HAS FLOWN -- cleared the water by more than the hull sits in it -- IT STAYS FLOWN. Breaking
	# contact by less than that before then is the hull riding the sea; see OUT_OF_THE_WATER.
	_check("and_once_it_has_flown_it_does_not_come_back_down_onto_the_water",
		flew_at > 0.0 and not touched_again,
		"flying from %.1f s (clear by more than its %.2f m draught), and never back on the water"
			% [flew_at, OUT_OF_THE_WATER] if flew_at > 0.0 and not touched_again
			else "it came back down onto the water after it had flown" if flew_at > 0.0
			else "it never cleared the water by its own draught")
	_check("and_the_sea_hands_over_to_the_wing_without_a_jolt", worst_jolt < NO_JOLT_G,
		"the sharpest change of climb within three seconds of leaving was %.2f g, against %.1f"
			% [worst_jolt, NO_JOLT_G])
	_check("and_it_climbs_away", went > 50.0, "h %.0f ninety seconds after full power" % went)
	world.teardown()


## A LANDING APPROACH: how high it starts, how fast, and the descent it is flown down at.
const APPROACH_HEIGHT: float = 25.0
const APPROACH_SPEED: float = 45.0
const SINK_RATE: float = 1.5
## HOW SLOW TO HOLD IT OFF TO, m/s: a little over the tanker's 40 m/s stall (`stall_speed`).
const HOLD_OFF_UNTIL: float = 42.0
## HOW LONG IT MAY TAKE TO STOP, and how slow counts as stopped.
const STOP_WITHIN: float = 120.0
const AT_REST: float = 1.0


## IT LANDS ON THE WATER, AND COMES TO REST FLOATING -- NOT BOUNCING OFF, NOT DIVING UNDER.
##
## Flown down: throttle back, a sink rate held with the stick, and on touchdown the throttle closed
## and the stick left alone. The stopping distance is PRINTED and not asserted, because the hull's
## drag is the boat defaults every `Handling` carries and nobody has measured a CL-415's run-out;
## what is asserted is that it stops at all, which a hull with no drag along it would never do.
func _it_lands_on_the_water_and_comes_to_rest() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
	if not _can_read_the_hull(world):
		world.teardown()
		return
	# HEADING OUT TO SEA, AWAY FROM THE ISLAND. The first version flew towards it, and nine hundred
	# metres of approach plus a five-hundred-metre run-out put the aeroplane at rest ON THE LAND, dry,
	# a metre and seven up -- which this suite read as a flying boat that had bounced off the water.
	var start := Vector3(0.0, APPROACH_HEIGHT, COAST + 1200.0)
	var made: Dictionary = world.spawn_pilot(74, TANKER, start, PI,
		Vector3(0.0, 0.0, APPROACH_SPEED))
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	var touched_at: float = -1.0
	var touched_speed: float = 0.0
	var touched_where := Vector3.ZERO
	var bounced: float = 0.0
	var deepest: float = INF
	var rested_at: float = -1.0
	var rested_where := Vector3.ZERO
	var track: PackedStringArray = []
	for i in range(int((STOP_WITHIN + 40.0) / TICK)):
		var state: Dictionary = world.vehicle_state(craft)
		var going: Vector3 = state.get("velocity", Vector3.ZERO)
		var at: Vector3 = state.get("position", Vector3.ZERO)
		var turned := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
		# THE LOWEST POINT OF THE HULL, not one point on it: a flare puts the nose up and the stern
		# down, and a single forward keel point read that as the aeroplane rising out of the water.
		var keel: float = _clearance(world, at, turned)
		var t: float = float(i) * TICK
		if touched_at < 0.0:
			# THE APPROACH, FLOWN AT A SPEED AND NOT A THROTTLE SETTING: the first version held a
			# fixed quarter-throttle, let the aeroplane gather speed down the slope, and put it on the
			# water at 54.7 m/s -- fifteen over its stall, which is flying speed, so it flew off again.
			# Held at APPROACH_SPEED down to the flare, and eased to half a metre a second at the end.
			if keel > 3.0:
				world.set_pilot_input(pilot, {
					"throttle": clampf(0.3 + (APPROACH_SPEED - going.length()) * 0.05, 0.01, 1.0),
					"pitch": clampf((-SINK_RATE - going.y) * 0.08, -0.4, 0.4)})
			else:
				# THE FLARE, WITH THE POWER OFF AND HELD OFF: the throttle closed ON THE LEVER, and the
				# aeroplane held just clear of the water -- no sink at all -- until the speed has bled
				# to HOLD_OFF_UNTIL, then let down. The first version kept approach power into the flare
				# and touched at 48 m/s, eight over the stall, which is flying speed, and it ballooned
				# 1.86 m back out; the second closed the power but let it straight down and touched at
				# 45.4, still skipping 1.13 m. A flying boat is landed as slowly as it will fly.
				var sink_now: float = 0.0 if going.length() > HOLD_OFF_UNTIL else 0.3
				world.set_pilot_input(pilot, {"command_channel": Sim.Channel.THROTTLE,
					"command_value": 0, "command_seq": 50 + i,
					"pitch": clampf((-sink_now - going.y) * 0.08, -0.4, 0.4)})
		else:
			# DOWN, AND KEPT DOWN: throttle closed and the stick holding the climb at nothing, which is
			# what a pilot does on a water landing while the hull takes the speed off.
			#
			# CLOSED ON THE LEVER, THROUGH THE THROTTLE CHANNEL -- not with `"throttle": 0.0`, which
			# means LET GO and leaves the lever where it was ("Let go and the lever HOLDS",
			# `apply_pilot_input`). The first version did that, left the approach's 0.14 on the
			# quadrant, and the aeroplane taxied on at 3.8 m/s for ever -- exactly the speed at which
			# 0.14 of 48 kN balances the hull's drag. Two theories about the water and the wind were
			# measured and thrown out before the lever was looked at. Drive the real path.
			world.set_pilot_input(pilot, {"command_channel": Sim.Channel.THROTTLE,
				"command_value": 0, "command_seq": 100 + i,
				"pitch": clampf((-0.3 - going.y) * 0.08, -0.4, 0.0)})
			bounced = maxf(bounced, keel)
			deepest = minf(deepest, keel)
		world.tick(TICK)
		var wet: float = float(world.hull_wet(craft))
		if touched_at < 0.0 and wet > 0.0:
			touched_at = t
			touched_speed = going.length()
			touched_where = at
		if touched_at >= 0.0 and rested_at < 0.0 and going.length() < AT_REST:
			rested_at = t
			rested_where = at
		if i % int(10.0 / TICK) == 0:
			# IN THE AEROPLANE'S OWN AXES: along, across and up. A single speed hid that the "4 m/s it
			# never stopped at" was a direction the hull's drag does not act in.
			var local: Vector3 = turned.transposed() * going
			track.append("t+%ds %.1f m/s (along %.1f across %.1f up %.1f) h %.1f wet %.2f"
				% [int(t), going.length(), -local.z, local.x, local.y, at.y, wet])
	var state: Dictionary = world.vehicle_state(craft)
	var at: Vector3 = state.get("position", Vector3.ZERO)
	var turned := Basis(state.get("basis", Quaternion.IDENTITY) as Quaternion)
	var sea_end: float = _sea_at(world, at)
	var floor_at: Vector3 = at + turned * PILOT_FLOOR - Vector3(0.0, sea_end, 0.0)
	var keel_end: float = _keel_low(at, turned) - sea_end
	var run_out: float = Vector2(rested_where.x - touched_where.x,
		rested_where.z - touched_where.z).length() if rested_at > 0.0 else -1.0
	print("[water] a landing on the sea from %.0f m at %.0f m/s: %s; touched at %.1f s doing %.1f m/s, stopped at %.1f s, %.0f m of water run-out"
		% [APPROACH_HEIGHT, APPROACH_SPEED, ", ".join(track), touched_at, touched_speed, rested_at, run_out])
	_check("a_flying_boat_flown_down_onto_the_sea_touches_it",
		touched_at > 0.0, "touched the water at %.1f s doing %.1f m/s" % [touched_at, touched_speed])
	# A BOUNCE IS RISING BACK OUT BY MORE THAN THE HULL SITS IN THE WATER -- the same line the take-off
	# draws between riding a wave and flying. See OUT_OF_THE_WATER.
	_check("and_does_not_bounce_off_it", bounced < OUT_OF_THE_WATER,
		"its hull rose at most %.2f m out of the water after touching, against its %.2f m draught"
			% [bounced, OUT_OF_THE_WATER])
	_check("and_does_not_dive_under_it", deepest > -NEAR_THE_SURFACE,
		"its keel went no deeper than h %.2f" % deepest)
	_check("and_comes_to_rest", rested_at > 0.0 and rested_at - touched_at < STOP_WITHIN,
		"stopped %.1f s after touching down, %.0f m on" % [rested_at - touched_at, run_out]
			if rested_at > 0.0 else "still moving %.0f s after touching down" % STOP_WITHIN)
	_check("and_ends_up_floating_with_its_floor_dry_and_its_keel_wet",
		floor_at.y > 0.0 and floor_at.y < NEAR_THE_SURFACE
			and keel_end < 0.0 and keel_end > -NEAR_THE_SURFACE,
		"floor h %.2f, the hull's lowest point h %.2f, %.1f degrees nose-up"
			% [floor_at.y, keel_end, _nose_up(turned)])
	world.teardown()



## WHERE THE SEA ACTUALLY IS, under this craft: the swell the simulation floats hulls on, asked
## exactly as the buoyancy probes ask it. THE SEA IS NOT AT y = 0, and this suite first assumed it
## was: the standing swell had the surface raised under the spawn point, so a hull floating
## correctly on the real water read as hovering 0.23 m above a flat sea that is not there. It is the
## datum and not the thing under test -- where the water IS is an input to buoyancy, not its output
## -- and it is what the sea shader draws, so a check against it is a check against what is seen.
func _sea_at(world: Object, at: Vector3) -> float:
	return float(world.hull_sea_at(TANKER, at.x, at.z)) if world.has_method("hull_sea_at") else 0.0


## HOW FAR OUT OF THE WATER COUNTS AS OUT OF IT, m: the hull's own design draught, the depth it sits
## in the sea at rest (waterline -1.09 against the keel's -1.68, craft/tanker/sources.md). Clearing the
## water by more than the hull sits in it is a hop; less is the hull riding a wave.
##
## THE AIRCRAFT'S NUMBER, AND IT REPLACED ONE I FITTED. The first line drawn here was the sea's summed
## wave relief, 1.41 m, with a comment claiming the 0.90 m take-off hop it was meant to catch was "well
## over it" -- which was false, and a landing that rose 1.13 m then passed only because the line had
## moved from 1.0. A threshold chosen after the result is a threshold chosen by the result. By this one
## the take-off's 0.05 m graze over a swell crest is the hull riding the sea, the old 0.90 m hop is
## caught, and a landing that skips 1.13 m back out of the water fails, which is true.
const OUT_OF_THE_WATER: float = 0.59


## THE LOWEST POINT OF THE HULL, in the world, in the attitude it is in. See KEEL_LINE.
func _keel_low(at: Vector3, turned: Basis) -> float:
	var low: float = INF
	for point in KEEL_LINE:
		low = minf(low, (at + turned * point).y)
	return low


## HOW FAR THE HULL IS OUT OF THE WATER, m -- negative when it is in it. Each keel point against THE
## SEA UNDER THAT POINT, not under the craft's middle: the hull is 19.8 m long and the wind-sea on it
## is short enough that the water at the bow and at the stern differ, so one sea height for the whole
## hull would be wrong by up to a wave at either end.
func _clearance(world: Object, at: Vector3, turned: Basis) -> float:
	var clear: float = INF
	for point in KEEL_LINE:
		var there: Vector3 = at + turned * point
		clear = minf(clear, there.y - _sea_at(world, there))
	return clear


## HOW FAR THE NOSE IS UP, in degrees, off the craft's forward axis (-Z).
func _nose_up(turned: Basis) -> float:
	return rad_to_deg(asin(clampf(-turned.z.y, -1.0, 1.0)))



## ON A RUNWAY AT SEA LEVEL, A FLYING BOAT IS ON LAND -- NOT AFLOAT.
##
## The sea's forces are asked only whether a probe is below the sea's HEIGHT, and on a runway at sea
## level, parked on its gear, the hull's probes are. The first build therefore floated the tanker ON
## THE TARMAC: 33 kN of hull drag held it to the runway, and `tests/climb.gd`'s tanker "never left the
## ground" where it had been 60 m up at 38.5 s -- found by the full gate, not by this file. So the
## simulation now asks the undercarriage (`stands_on_something`) before the sea, and this holds it to
## that directly: parked on the island's sea-level ground, the hull is not wet at all. `climb` holds
## the take-off that the bug had stopped.
func _on_land_at_sea_level_it_is_not_in_the_water() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
	if not _can_read_the_hull(world):
		world.teardown()
		return
	# ON THE ISLAND, whose top is at y 0 -- which is also where the sea stands.
	var made: Dictionary = world.spawn_pilot(75, TANKER, Vector3(0.0, 2.5, 0.0), 0.0, Vector3.ZERO)
	var craft: int = int(made.get("vehicle", 0))
	var most: float = 0.0
	for i in range(int(10.0 / TICK)):
		world.tick(TICK)
		most = maxf(most, float(world.hull_wet(craft)))
	var at: Vector3 = world.vehicle_state(craft).get("position", Vector3.ZERO)
	_check("parked_on_land_at_sea_level_a_flying_boats_hull_is_not_in_the_water", most == 0.0,
		"the most its hull was wet in ten seconds parked at h %.2f on sea-level ground was %s"
			% [at.y, most])
	world.teardown()


func _hold_it_down(world: Object, craft: int, pilot: int) -> void:
	var state: Dictionary = world.vehicle_state(craft)
	if state.is_empty():
		return
	var at: Vector3 = state.get("position", Vector3.ZERO)
	var going: Vector3 = state.get("velocity", Vector3.ZERO)
	world.set_pilot_input(pilot, {"pitch": clampf(
		(SKIM_HEIGHT - at.y) * 0.05 - going.y * 0.10, -0.5, 0.5)})


## WOULD THIS AEROPLANE, PUT HERE AT THIS SPEED, BE SCOOPING? One tick, so that the state
## exists and the physics has had a chance to answer the ray cast underneath it.
func _would_scoop(world: Object, client: int, at: Vector3, speed: float) -> bool:
	var made: Dictionary = world.spawn_pilot(client, TANKER, at, 0.0,
		Vector3(0.0, 0.0, -speed))
	world.tick(TICK)
	return bool(world.is_scooping_now(int(made.get("vehicle", 0))))


## ---- and the handle that opens it ------------------------------------------------------

## A LEVER BETWEEN THE PILOTS, and not a button on the yoke.
##
## Six tonnes takes five seconds to leave, so what the pilot is doing is HOLDING the
## aeroplane over a fire while the load goes -- and the control that says that is a handle
## that stays where it is put. It is on the CONSOLE because it belongs to the aircraft
## rather than to either seat: one flies the run, the other drops.
func _the_cockpit_has_a_handle_for_it() -> void:
	var view := (load("res://objects/vehicles/craft_tanker.tscn") as PackedScene) \
		.instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var lever := view.controls_for(0).get("drop") as DropLever
	_check("the_water_bomber_has_a_drop_lever", lever != null,
		"seat 0 can reach %s" % [lever])
	if lever == null:
		view.queue_free()
		return
	_check("and_it_works_the_tank_doors", lever.channel == Sim.Channel.DROP
		and lever.channel_range == 1,
		"channel %d, range %d" % [lever.channel, lever.channel_range])
	# BOTH PILOTS. A console control is spliced into every seat's set and is the SAME node
	# each time, which is what makes two people's hands land on one handle.
	_check("and_the_copilot_reaches_the_same_one",
		view.controls_for(1).get("drop") == lever, "one handle, not two")
	# PULLED BACK IS OPEN, which is the way every emergency handle in an aircraft works and
	# the one thing about this control nobody should have to think about at fifty feet.
	lever.offer_hand(1, lever._grab_point(), 1.0)
	lever.offer_hand(1, lever._grab_point() + Vector3(0.0, 0.0, DropLever.TRAVEL), 1.0)
	_check("and_pulling_it_back_opens_the_doors", lever.is_open(),
		"the lever reads %.0f" % lever.value.y)
	lever.offer_hand(1, lever._grab_point() - Vector3(0.0, 0.0, DropLever.TRAVEL), 1.0)
	_check("and_pushing_it_forward_shuts_them_again", not lever.is_open(),
		"the lever reads %.0f" % lever.value.y)
	lever.release()
	# AND IT IS CLEAR OF EVERY OTHER CONTROL IN THE COCKPIT. The crowding rule the whole
	# game obeys: two grips closer than two REACHes share a place a hand can be, and which
	# one it gets is then down to iteration order. The console is where that is tightest --
	# three handles in the gap between two seats.
	var crowded: Array[String] = []
	for role in view.controls_for(0):
		var other := view.controls_for(0)[role] as VehicleControl
		if other == null or other == lever:
			continue
		var apart: float = other.grip_global().distance_to(lever.grip_global())
		if apart < VehicleControl.REACH * 2.0:
			crowded.append("%s %.2f m away" % [other.name, apart])
	_check("and_nothing_else_is_within_one_hand_of_it", crowded.is_empty(),
		"%s" % ["clear" if crowded.is_empty() else crowded])
	view.queue_free()


## ---- small shared things ----------------------------------------------------------------

## How hard one fire is burning, or -1 if it has been put out and retired.
func _strength_of(world: Object, entity: int) -> float:
	for fire in (world.fire_states() as Array):
		if int((fire as Dictionary)["entity"]) == entity:
			return float((fire as Dictionary)["strength"])
	return -1.0


## ---- and the moment it starts ------------------------------------------------------------

## A CLIENT PULLS THE LEVER, THE SERVER SAYS SO, AND EVERY MACHINE PLAYS IT.
##
## The whole path, end to end, over a real link: a command on a client's input frame, applied
## by the server inside the frame that command belongs to, a CUE emitted there, and both
## clients -- the one that pulled the lever and one that is only watching -- playing it.
##
## THE FRAME IS THE POINT. A cue carries the frame it happened on, so an effect started from
## one runs from the same instant on every machine rather than from whenever each of them
## happened to hear about it. `late` is the difference, and it is what a burst is wound
## forward by so that it does not lag the wire.
##
## AND IT IS A MOMENT, NOT A STATE. The doors being open is a bit on the bus and stays true
## for the next five seconds -- anybody joining mid-drop sees open doors and a half-empty
## tank. What the bit cannot say is "and it happened just now", which is the gush.
func _a_client_asks_and_everybody_sees_it() -> void:
	var server: Object = ClassDB.instantiate("CockpitWorld")
	var flier: Object = ClassDB.instantiate("CockpitWorld")
	var watcher: Object = ClassDB.instantiate("CockpitWorld")
	for world in [server, flier, watcher]:
		world.set_tick_rate(120.0)
	server.start(0)
	flier.start(1)
	watcher.start(2)
	# NOBODY IS ADMITTED BY HAND. A client announces itself over the link and the server
	# assigns it an id, which is the same handshake the game does -- so this is ticked until
	# it has happened rather than short-circuited.
	_link(server, flier, watcher, 120, {})

	_check("the_flying_client_was_given_an_id", int(flier.local_client_id()) > 0,
		"client %d, and the watcher is %d" % [int(flier.local_client_id()),
			int(watcher.local_client_id())])
	var made: Dictionary = server.spawn_pilot(int(flier.local_client_id()), TANKER,
		Vector3(0.0, 400.0, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	var craft: int = int(made.get("vehicle", 0))
	_link(server, flier, watcher, 60, {})
	# FOUND BY KIND, NOT BY NUMBER. Entity ids are per WORLD -- the server's tanker and the
	# client's copy of it are different numbers, and sync maps between them -- so a test that
	# carried the server's id across would be asking each client about an entity it has
	# never heard of. That mapping is also why the cue below arrives naming the LOCAL one.
	var mine_is: int = _the_tanker_on(flier)
	var theirs_is: int = _the_tanker_on(watcher)
	_check("both_clients_can_see_the_tanker", mine_is != 0 and theirs_is != 0,
		"the server calls it %d, the two clients call it %d and %d" % [craft, mine_is,
			theirs_is])
	# NOTHING HAS HAPPENED YET, and a machine that has not been told about a moment has an
	# empty list rather than a stale one.
	_check("and_neither_has_been_told_about_anything_yet",
		(flier.take_cues() as Array).is_empty()
			and (watcher.take_cues() as Array).is_empty(), "no cues")

	# THE COMMAND, FROM THE CLIENT THAT IS FLYING IT. Exactly what the drop lever sends:
	# a channel, a value and a sequence number on this client's own input frame.
	var pulled: Array = []
	var seen: Array = []
	for i in range(int(3.0 / TICK)):
		if i == 10:
			# THE COMMAND ITSELF, sent exactly as the drop lever sends it: the client bumps
			# a sequence number and the next input frame carries the channel and the value
			# along with the sticks. The server applies it once, on the tick the sequence
			# changes, and ignores every repeat -- including the repeats a rollback replays.
			flier.send_command(Sim.Channel.DROP, 1)
		_link(server, flier, watcher, 1, {"throttle": 0.5})
		for cue in (flier.take_cues() as Array):
			pulled.append(cue)
		for cue in (watcher.take_cues() as Array):
			seen.append(cue)
	_check("the_client_that_pulled_the_lever_is_told_about_the_release",
		pulled.size() == 1, "%d cues" % pulled.size())
	_check("and_so_is_a_client_that_is_only_watching", seen.size() == 1,
		"%d cues" % seen.size())
	if pulled.is_empty() or seen.is_empty():
		_teardown([server, flier, watcher])
		return
	var mine: Dictionary = pulled[0]
	var theirs: Dictionary = seen[0]
	# AND IT NAMES EACH MACHINE'S OWN COPY of the aeroplane, which is what makes a cue
	# usable at the far end: the renderer looks a vehicle up by its local id.
	_check("and_it_is_the_water_release_on_that_aeroplane",
		int(mine["what"]) == Sim.Cue.WATER_RELEASE and int(mine["entity"]) == mine_is
			and int(theirs["entity"]) == theirs_is,
		"cue %d on entity %d here and %d there" % [int(mine["what"]),
			int(mine["entity"]), int(theirs["entity"])])
	# A FULL TANK, which is what the effect is sized by: a quarter tank does not make the
	# same mess as a full one.
	_check("and_it_says_how_much_was_in_the_tank", int(mine["value"]) > 240,
		"%d of 255" % int(mine["value"]))
	# THE SAME FRAME ON BOTH MACHINES. This is the whole reason a cue carries one: an
	# animation started from it runs from one instant everywhere, rather than from whenever
	# each machine happened to hear about it.
	_check("and_both_machines_file_it_under_the_same_frame",
		int(mine["frame"]) == int(theirs["frame"]) and int(mine["frame"]) > 0,
		"frame %d and frame %d" % [int(mine["frame"]), int(theirs["frame"])])
	# AND HOW LATE EACH OF THEM IS, which is how far INTO the effect to start it.
	_check("and_each_of_them_knows_how_late_it_is",
		float(mine["late"]) >= 0.0 and float(mine["late"]) < 1.0
			and float(theirs["late"]) >= 0.0 and float(theirs["late"]) < 1.0,
		"%.3f s and %.3f s behind" % [float(mine["late"]), float(theirs["late"])])
	# AND IT IS PLAYED ONCE. A cue read twice is a gush of water drawn twice, which is why
	# the list is drained by the reading.
	_check("and_the_list_is_emptied_by_the_reading",
		(flier.take_cues() as Array).is_empty(), "nothing left to play")
	# WHILE THE DOORS STAY OPEN AND THE TANK GOES ON EMPTYING, which is the half of this
	# that is a STATE rather than a moment -- and there is exactly one moment, not one a
	# tick for five seconds.
	_link(server, flier, watcher, 120, {"throttle": 0.5})
	var during: int = (flier.take_cues() as Array).size()
	_check("and_a_five_second_drop_is_one_moment_and_not_six_hundred", during == 0,
		"%d more cues while the water was leaving" % during)
	_check("and_the_tank_is_emptying_all_the_while",
		float(flier.tank_load(mine_is)) < 0.9 and float(flier.tank_load(mine_is)) > 0.0,
		"%.2f of a tank a second into the drop" % flier.tank_load(mine_is))
	_teardown([server, flier, watcher])


## WHAT THIS MACHINE CALLS THE TANKER, or 0 if it cannot see one. Entity ids are per world.
## THE LEVEL DRAWS A RELEASE IT IS TOLD ABOUT -- the half the section above cannot see.
##
## Everything above is `CockpitWorld` below the level: it shows the cue reaching every machine under the right frame.
## Nothing in it asks whether the LEVEL plays it, and for as long as the water bomber existed it did not:
## `FlightLevel._play_the_cues` was written with it (b347981) and never called, and `Sim.cues` is replaced every
## physics frame, so every release was delivered and thrown away. Found on 2026-09-13 by the missile work, whose
## launch cues were never played either.
##
## Through the real level and the real player: into a tanker the way the clipboard asks for one, the doors opened with
## the command the drop lever sends, and the check is the burst `ShotYard.release` lights at the belly.
func _the_level_draws_a_release_it_is_told_about() -> void:
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(240):
		await get_tree().physics_frame
	var rig: PilotRig = level.rig
	rig.ask_for_kind(TANKER)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == TANKER:
			break
	_check("the_player_gets_into_a_tanker", view != null and view.kind == TANKER,
		"kind %s" % [view.kind if view != null else "-"])
	if view == null or view.kind != TANKER:
		return
	var lit_before: int = _bursts_lit(level)
	Sim.send_command(Sim.Channel.DROP, 1)
	var lit: int = lit_before
	for i in range(180):
		await get_tree().process_frame
		lit = maxi(lit, _bursts_lit(level))
		if lit > lit_before:
			break
	_check("and_the_level_draws_the_release_at_the_belly", lit > lit_before,
		"%d burst(s) going before the doors opened, %d after; tank %.2f" % [lit_before, lit, Sim.tank_load(view.entity)])
	Sim.send_command(Sim.Channel.DROP, 0)


## How many of the level's bursts are going right now.
func _bursts_lit(level: FlightLevel) -> int:
	var going: int = 0
	if level.shots == null:
		return 0
	for child in level.shots.get_children():
		if child is Burst and (child as Burst).visible:
			going += 1
	return going


func _the_tanker_on(world: Object) -> int:
	for state in (world.vehicle_states() as Array):
		if int((state as Dictionary).get("kind", -1)) == TANKER:
			return int((state as Dictionary)["entity"])
	return 0


## ONE TICK OF A THREE-MACHINE SESSION, `times` over, with `input` from the flying client.
##
## Packets are handed straight across rather than delayed: what is being measured here is
## whether a moment reaches everybody and under which frame, not how a link behaves.
func _link(server: Object, flier: Object, watcher: Object, times: int,
		input: Dictionary) -> void:
	for i in range(times):
		if not input.is_empty():
			flier.set_input(input)
		server.tick(TICK)
		flier.tick(TICK)
		watcher.tick(TICK)
		for packet in (server.take_outbound() as Array):
			var to: Object = flier if int(packet["peer"]) == 1 else watcher
			to.deliver(0, packet["bytes"], packet["bits"])
		for packet in (flier.take_outbound() as Array):
			server.deliver(1, packet["bytes"], packet["bits"])
		for packet in (watcher.take_outbound() as Array):
			server.deliver(2, packet["bytes"], packet["bits"])


func _teardown(worlds: Array) -> void:
	for world in worlds:
		world.teardown()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## ---- and the gauge that says what is in it -----------------------------------------------

## THE PILOT'S EYE, in the seat's own frame. TYPED, not read off `CockpitStation.EYE_HEIGHT`:
## a check that asks the constant the code places against moves with it, and would call a
## gauge on the floor correct as long as the pilot's eye had been lowered to the floor too.
const SEATED_EYE := Vector3(0.0, 1.35, 0.0)
## WHERE A PANEL INSTRUMENT MAY BE, from the seated eye: degrees below its level line,
## degrees off the nose, and metres away. Windows and not values, and each has a thing either
## side of it that would fail. DOWN: the glareshield over the flight display is 11 degrees and
## the space under it, on the control column, is 43 -- the placement this gauge started in and
## was moved out of. ACROSS: 0 is the windscreen and the column; past 50 is a head turn rather
## than a glance, and the map screen on the other console is at 46. AWAY: 0.60 m is a seated
## arm, and past it the numerals are guesswork.
const PANEL_DOWN: Vector2 = Vector2(22.0, 38.0)
const PANEL_ACROSS: Vector2 = Vector2(25.0, 50.0)
const PANEL_REACH: Vector2 = Vector2(0.40, 0.60)


## A GAUGE OF THE TANK LEVEL, AT BOTH SEATS, WHERE IT CAN BE SEEN, SHOWING WHAT THE
## AEROPLANE SAYS.
##
## The user asked for this in these words: "make sure there is a gauge of the tank full level
## in the cockpit and visible to the pilot and copilot". That is three claims, and each one is
## held against something OUTSIDE the gauge -- a gauge measured against its own constants
## describes a gauge in the wrong place perfectly.
##
## - AT BOTH SEATS: asked of the stations the built aeroplane has, not of a scene file.
## - VISIBLE: the sight line from a seated eye to five points on the face, against the DRAWN
##   boxes of everything else in that station -- the yoke, the flight display, the crew board,
##   the map screen, the rudder strip. `lane/skyhawk` is the lesson this is copied from:
##   `fit.gd` measured the station against the pilot and never looked at the aeroplane, and
##   `fighter.gd` measured the aeroplane against its three-view and never looked at the
##   station, and both were green while every craft's seats stood outside its own skin.
##   Anchor the check outside the thing it is checking.
## - SHOWING WHAT THE AEROPLANE SAYS: the state dictionary `VehicleView` publishes, handed to
##   the STATION the way the game hands it -- `show_state` -- and the answer read as the LENGTH
##   OF THE DRAWN BAR rather than as the number that was passed in. A gauge that stored what it
##   was told and drew nothing would pass the second and fail this.
func _a_gauge_at_both_seats_says_what_is_left() -> void:
	var view := (load("res://objects/vehicles/craft_tanker.tscn") as PackedScene) \
		.instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var gauges: Array[TankGauge] = []
	var stations: Array[CockpitStation] = []
	for index in [0, 1]:
		var station := view.station_for(index)
		if station == null:
			continue
		var gauge := station.get_node_or_null("TankGauge") as TankGauge
		if gauge != null:
			stations.append(station)
			gauges.append(gauge)
	_check("both_pilots_of_the_water_bomber_have_a_water_gauge", gauges.size() == 2,
		"%d of the two flying seats carry one" % gauges.size())
	if gauges.size() != 2:
		view.queue_free()
		return
	# ONE INSTRUMENT AUTHORED ONCE, AND THE SAME ONE REFLECTED. Every two-crew cockpit ever
	# built is symmetric about its centre line, and this is the check that says this one is: the
	# copilot's gauge is the pilot's about x, outboard on his own side of his own panel rather
	# than a second copy that could drift. A fitted station is reflected by `_mirror_the_layout`
	# and an authored package's right-hand seat arrives already reflected; a part that placed
	# itself at a signed x would be wrong under one of those two, which is why the gauge reads
	# its side off the crew board that is already in the station under both.
	var pilot: Vector3 = gauges[0].position
	var copilot: Vector3 = gauges[1].position
	_check("and_each_of_them_has_it_outboard_on_his_own_side_of_his_own_panel",
		absf(pilot.x + copilot.x) < 0.001 and absf(pilot.x) > 0.10
			and absf(pilot.y - copilot.y) < 0.001 and absf(pilot.z - copilot.z) < 0.001,
		"pilot at (%.3f, %.3f, %.3f), copilot at (%.3f, %.3f, %.3f)" % [
			pilot.x, pilot.y, pilot.z, copilot.x, copilot.y, copilot.z])

	# ---- where it is, from the eye that reads it -----------------------------------------
	var face: AABB = _drawn_box(gauges[0], stations[0])
	var middle: Vector3 = face.position + face.size * 0.5
	var down: float = rad_to_deg(atan2(SEATED_EYE.y - middle.y, -middle.z))
	var across: float = rad_to_deg(atan2(absf(middle.x), -middle.z))
	var far_off: float = SEATED_EYE.distance_to(middle)
	_check("and_it_is_on_the_panel_where_a_seated_pilot_reads_it",
		down > PANEL_DOWN.x and down < PANEL_DOWN.y
			and across > PANEL_ACROSS.x and across < PANEL_ACROSS.y
			and far_off > PANEL_REACH.x and far_off < PANEL_REACH.y,
		"%.1f degrees below the eye's level line and %.1f off its nose, at %.2f m, in a face %.3f by %.3f m" % [
			down, across, far_off, face.size.x, face.size.y])
	# AND NOTHING OF IT STANDS BETWEEN THE EYES AND THE HORIZON. The rule the whole cockpit is
	# built on. At level flight the horizon IS the eye's level line, so the test is the top of
	# the drawn face against it -- with a tenth of a metre to spare, because a pilot's head
	# moves and a gauge that only just cleared it would rise into the view with the first lean.
	_check("and_nothing_of_it_stands_between_the_eyes_and_the_horizon",
		face.end.y < SEATED_EYE.y - 0.10,
		"its top is h %.3f, %.3f m below the eye at h %.2f" % [
			face.end.y, SEATED_EYE.y - face.end.y, SEATED_EYE.y])

	# ---- and can it be SEEN from there ---------------------------------------------------
	#
	# EVERY OTHER DRAWN BOX IN THE STATION, and the sight line to five points on the face.
	# The yoke is the one that matters -- it stands between this seat and its own panel -- and
	# it is precisely the thing a check written from the gauge's own constants cannot know
	# about.
	var others: Dictionary = _other_boxes(stations[0], gauges[0])
	var blocked: PackedStringArray = []
	for corner in _face_points(face):
		for what in others:
			if _ray_hits(others[what] as AABB, SEATED_EYE, corner):
				blocked.append(String(what))
				break
	_check("and_nothing_else_in_the_cockpit_stands_between_the_eye_and_its_face",
		blocked.is_empty(),
		"%d other drawn parts checked (%s), none in the way"
			% [others.size(), ", ".join(PackedStringArray(others.keys()))]
			if blocked.is_empty() else "hidden by %s" % ", ".join(blocked))
	# AND THE CHECK WOULD NOTICE ONE THAT WAS. A mutant face, put where this gauge started: on
	# the seat's centreline under the flight display, where the control column lies. If this
	# passes, the check above proves nothing.
	var on_the_column := AABB(
		Vector3(-face.size.x * 0.5, 0.955, -0.391), Vector3(face.size.x, 0.070, 0.012))
	var caught: bool = false
	for corner in _face_points(on_the_column):
		for what in others:
			if _ray_hits(others[what] as AABB, SEATED_EYE, corner):
				caught = true
				break
	_check("and_a_gauge_on_the_centreline_under_the_display_would_be_caught", caught,
		"the same face at x 0, h 0.99, z -0.385 is %s"
			% ["hidden, as it was measured to be" if caught else "STILL CLEAR"])
	# AND IT DOES NOT SIT ON TOP OF ANYTHING. Occlusion is about the eye; this is about the
	# panel -- two instruments in one place is a drawing nobody can read whichever way they
	# look at it.
	var shared: PackedStringArray = []
	for what in others:
		if (others[what] as AABB).intersects(face):
			shared.append(String(what))
	_check("and_it_shares_its_place_on_the_panel_with_nothing", shared.is_empty(),
		"clear of all %d" % others.size() if shared.is_empty()
			else "inside %s" % ", ".join(shared))

	# ---- and what it draws ---------------------------------------------------------------
	#
	# THROUGH THE STATION, which is how the game feeds it: `VehicleView` publishes one state
	# dictionary and hands it to every seat, so the pilot's gauge and the copilot's cannot
	# disagree. Read back as the LENGTH OF THE BAR, off the scene.
	var lengths: Array[float] = []
	for level in [1.0, 0.62, 0.05]:
		for station in stations:
			station.show_state({"tank": level, "scooping": false, "dropping": false}, [])
		lengths.append(gauges[0].bar_length())
		_check("and_both_gauges_read_the_same_tank_at_%d_percent" % int(level * 100.0),
			absf(gauges[0].bar_length() - gauges[1].bar_length()) < 0.0005
				and absf(gauges[0].showing() - level) < 0.001,
			"pilot %.4f m, copilot %.4f m" % [gauges[0].bar_length(), gauges[1].bar_length()])
	# A FULL TANK IS A FULL TRACK, AND THE REST ARE THAT MUCH OF IT. The shares are typed here
	# rather than taken off `TankGauge.WIDTH`, so a mutant that changed the gauge's width or
	# its margin moves the drawing and not this arithmetic.
	_check("and_the_bar_is_as_long_as_the_tank_is_full",
		lengths[0] > 0.15 and absf(lengths[1] / lengths[0] - 0.62) < 0.01
			and absf(lengths[2] / lengths[0] - 0.05) < 0.01,
		"full %.4f m, 62 per cent %.4f m (%.3f of it), 5 per cent %.4f m (%.3f of it)" % [
			lengths[0], lengths[1], lengths[1] / lengths[0],
			lengths[2], lengths[2] / lengths[0]])
	# AND NEARLY EMPTY IS AMBER, on the one figure the flight display warns on too. Typed
	# either side of a tenth of a tank: at 9 per cent the gauge is amber and at 11 it is not.
	for station in stations:
		station.show_state({"tank": 0.09, "scooping": false, "dropping": false}, [])
	var low: Color = gauges[0].reading_colour()
	for station in stations:
		station.show_state({"tank": 0.11, "scooping": false, "dropping": false}, [])
	var fine: Color = gauges[0].reading_colour()
	_check("and_a_tenth_of_a_tank_left_is_amber_and_more_than_that_is_not",
		low == TankGauge.AMBER and fine != TankGauge.AMBER
			and absf(TankGauge.LOW - 0.10) < 0.0001,
		"at 9 per cent %s, at 11 per cent %s, on a warning line of %.2f"
			% [low, fine, TankGauge.LOW])
	# AND THE ONE WORD A PILOT FLYING A SCOOPING RUN NEEDS. The sea and a lake look identical
	# at fifty feet and the only difference that matters is whether the gauge is moving.
	for station in stations:
		station.show_state({"tank": 0.40, "scooping": true, "dropping": false}, [])
	var filling: String = gauges[1].word()
	for station in stations:
		station.show_state({"tank": 0.40, "scooping": false, "dropping": true}, [])
	var emptying: String = gauges[1].word()
	for station in stations:
		station.show_state({"tank": 0.40, "scooping": false, "dropping": false}, [])
	_check("and_it_says_which_way_the_water_is_going_and_nothing_when_it_is_not",
		filling == "FILL" and emptying == "DROP" and gauges[1].word() == "",
		"scooping '%s', doors open '%s', level flight '%s'"
			% [filling, emptying, gauges[1].word()])
	view.queue_free()

	_and_a_craft_with_no_tank_has_no_gauge()


## AND NO CRAFT WITHOUT A TANK CARRIES ONE, which is the half of this that is easy to leave
## out. `VehicleView` leaves `tank` out of the state of a craft with no tank rather than
## publishing zero, because a gauge reading EMPTY on an aeroplane that carries no water is a
## gauge saying something false -- and the cheapest way to say something false is to fit the
## instrument everywhere and let it read what it likes.
##
## ASKED OF EVERY KIND, not of a chosen few, and through the same station the game builds.
func _and_a_craft_with_no_tank_has_no_gauge() -> void:
	var wrong: PackedStringArray = []
	var right: PackedStringArray = []
	for kind in range(Sim.Kind.size()):
		var view := (load("res://objects/vehicles/craft_tanker.tscn") as PackedScene) \
			.instantiate() as VehicleView
		add_child(view)
		view.preview_kind = kind
		view._show_in_editor()
		var carries: bool = not view.find_children("*", "TankGauge", true, false).is_empty()
		if carries:
			right.append(Sim.kind_name(kind))
		if carries != (kind == TANKER):
			wrong.append("%s %s" % [Sim.kind_name(kind),
				"has one and has no tank" if carries else "has a tank and no gauge"])
		view.queue_free()
	_check("and_the_only_craft_with_a_water_gauge_is_the_one_with_a_water_tank",
		wrong.is_empty(),
		"%d of %d kinds carry one: %s" % [right.size(), Sim.Kind.size(), ", ".join(right)]
			if wrong.is_empty() else ", ".join(wrong))


## ---- measuring a station -----------------------------------------------------------------

## THE BOX A NODE'S OWN MESHES FILL, in the station's frame, from the corners of each mesh
## transformed one at a time. Not `transform * get_aabb()`, which grows a box every time it is
## turned and would hand every check below a part bigger than the thing it draws.
func _drawn_box(part: Node3D, station: Node3D) -> AABB:
	var box := AABB()
	var started: bool = false
	var parts: Array[Node] = [part]
	parts.append_array(part.find_children("*", "", true, false))
	for node in parts:
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var local: AABB = mesh.mesh.get_aabb()
		var into: Transform3D = station.global_transform.affine_inverse() * mesh.global_transform
		for corner in range(8):
			var at: Vector3 = into * local.get_endpoint(corner)
			if not started:
				box = AABB(at, Vector3.ZERO)
				started = true
			else:
				box = box.expand(at)
	return box


## Every OTHER drawn part of this station, by name, in the station's frame.
func _other_boxes(station: CockpitStation, skip: Node3D) -> Dictionary:
	var boxes: Dictionary = {}
	for child in station.get_children():
		var part := child as Node3D
		if part == null or part == skip:
			continue
		var box: AABB = _drawn_box(part, station)
		if box.get_volume() > 0.0:
			boxes[part.name] = box
	return boxes


## The middle of a face and its four corners, a hair proud of it so a ray aimed at a corner
## does not end inside the gauge's own box.
func _face_points(face: AABB) -> Array[Vector3]:
	var middle: Vector3 = face.position + face.size * 0.5
	var out: Array[Vector3] = [middle]
	for sx in [-0.48, 0.48]:
		for sy in [-0.48, 0.48]:
			out.append(middle + Vector3(face.size.x * sx, face.size.y * sy, face.size.z * 0.5))
	return out


## Does the segment from `from` to `to` pass through this box? The slab test, clipped to the
## segment, so a part BEHIND the gauge does not count as being in the way.
func _ray_hits(box: AABB, from: Vector3, to: Vector3) -> bool:
	var along: Vector3 = to - from
	var near: float = 0.0
	var far_end: float = 1.0
	for axis in range(3):
		var step: float = along[axis]
		var lo: float = box.position[axis]
		var hi: float = box.end[axis]
		if absf(step) < 0.000001:
			if from[axis] < lo or from[axis] > hi:
				return false
			continue
		var t0: float = (lo - from[axis]) / step
		var t1: float = (hi - from[axis]) / step
		near = maxf(near, minf(t0, t1))
		far_end = minf(far_end, maxf(t0, t1))
		if near > far_end:
			return false
	# A GRAZE IS NOT A BLOCK. A millimetre of overlap at the very edge of a bezel is the
	# tolerance every mesh here is drawn to, not something standing in the way.
	return (far_end - near) * along.length() > 0.002


## ---- and the room it promises round its crew ---------------------------------------------

## HOW MANY SAMPLES ACROSS EACH FACE OF THE ROOM. 13 x 13 on six faces is 1,014 points, which is
## the same order `tests/skyhawk.gd` uses on the Cessna and dense enough that a corner poking
## through the skin cannot slip between two of them: the room is about 1.3 m by 2.2 m by 4.0 m,
## so the samples are at worst 0.33 m apart and the skin is nowhere flat over that distance.
const ROOM_SAMPLES: int = 13
## A sample within this of the skin is ON it rather than through it, in metres.
const SKIN_TOLERANCE: float = 0.02


## THE ROOM THE WATER BOMBER PROMISES ROUND ITS CREW, HELD AGAINST THE TRIANGLES IT DRAWS.
##
## `VehicleView.cabin_room` says: every point inside this box is inside the skin I draw. That is a
## promise another part of the game can act on carrying no geometry of its own, and it is worth
## exactly as much as the check that holds it to the drawing.
##
## THE DATUM IS THE DRAWN VERTEX, AND IT HAS TO BE. On the Cessna the room is five typed numbers
## and the skin is emitted from a different set, so `tests/skyhawk.gd` can play them against each
## other: a mutant that moves the promise is caught by the figures, one that moves the drawing is
## caught by the box. Here the room is COMPUTED from the same loft the skin is built from, so that
## trick is not available -- move a hull station and both move together, agreeing perfectly about
## a different aeroplane. So this fires rays at the triangles instead. **Each is a way of getting
## an independent datum; what is not allowed is having neither.**
##
## HOW "INSIDE" IS DECIDED: a ray straight up AND a ray straight down from the sample must each
## cross the skin an odd number of times. Two rays and not one, because the fuselage is a lofted
## TUBE with no end caps -- a single ray would call a point beyond the nose inside, having crossed
## nothing at all.
func _the_room_it_promises_is_inside_the_skin_it_draws() -> void:
	var view := (load("res://objects/vehicles/craft_tanker.tscn") as PackedScene) \
		.instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var promise: Dictionary = view.cabin_room()
	var room: AABB = promise.get("room", AABB())
	_check("the_water_bomber_declares_the_room_round_its_crew_and_says_where_it_came_from",
		bool(promise.get("drawn", false)) and String(promise.get("why_not", "x")) == ""
			and String(promise.get("source", "")).length() > 20 and room.get_volume() > 1.0,
		"drawn %s, %.2f m3 (%.2f x %.2f x %.2f), source %s" % [promise.get("drawn", false),
			room.get_volume(), room.size.x, room.size.y, room.size.z,
			String(promise.get("source", "")).substr(0, 48)])
	if not bool(promise.get("drawn", false)):
		view.queue_free()
		return

	var skin: PackedVector3Array = _fuselage_triangles(view)
	_check("and_the_fuselage_it_is_measured_against_is_the_one_on_the_aeroplane", skin.size() >= 300,
		"%d drawn triangles in WaterBomberFuselage" % (skin.size() / 3))
	var kept: Dictionary = _samples_outside(skin, room)
	_check("and_every_point_of_that_room_is_inside_the_skin_the_aeroplane_draws",
		int(kept["outside"]) == 0 and int(kept["tested"]) > 900,
		"%d samples over its six faces, none outside" % kept["tested"]
			if int(kept["outside"]) == 0 else
			"%d of %d outside; worst at (%.2f, %.2f, %.2f)" % [kept["outside"], kept["tested"],
				kept["where"].x, kept["where"].y, kept["where"].z])
	# AND THE CHECK WOULD NOTICE A ROOM THAT WAS NOT. One mutant, definitely wrong on every face:
	# a third wider and a third taller than the promise, which on this hull puts its top corners
	# through the cabin roof and its sides through the planing bottom.
	var swollen := AABB(room.position - Vector3(room.size.x, room.size.y, 0.0) * 0.165,
		room.size * Vector3(1.33, 1.33, 1.0))
	var wrong: Dictionary = _samples_outside(_fuselage_triangles(view), swollen)
	_check("and_a_room_a_third_bigger_than_the_cabin_is_caught", int(wrong["outside"]) > 40,
		"%d of %d samples outside" % [wrong["outside"], wrong["tested"]])

	# AND THE CREW ARE IN IT, which is the point of the whole interface and the check `lane/skyhawk`
	# could only print because the Cessna's seats were outside its own cabin. Every seat pose the
	# SIMULATION publishes, and the eye `CockpitStation` puts above it -- the two authorities, met
	# in a box that was computed from one of them and measured against the drawing.
	var poses: Array = Sim.geometry_of(TANKER).get("seat_poses", []) as Array
	var outside: PackedStringArray = []
	for seat in range(poses.size()):
		var at: Vector3 = (poses[seat] as Dictionary).get("position", Vector3.ZERO) as Vector3
		var eye := Vector3(at.x, at.y + CockpitStation.EYE_HEIGHT, at.z)
		if not room.has_point(at):
			outside.append("seat %d's floor (%.2f, %.2f, %.2f)" % [seat, at.x, at.y, at.z])
		if not room.has_point(eye):
			outside.append("seat %d's eye at h %.2f, %.2f m over the room's roof"
				% [seat, eye.y, eye.y - room.end.y])
	_check("and_every_seat_and_every_eye_in_this_aeroplane_is_inside_it", outside.is_empty(),
		"%d seats, floors and eyes all in a room of %.2f..%.2f x, %.2f..%.2f y, %.2f..%.2f z"
			% [poses.size(), room.position.x, room.end.x, room.position.y, room.end.y,
				room.position.z, room.end.z]
			if outside.is_empty() else ", ".join(outside))
	# AND THE FLOOR IS PUBLISHED BESIDE THE ROOM AND NOT INSIDE IT. Two facts: where the crew
	# stand, and how much room can be promised round them. On this aeroplane the room reaches
	# BELOW the floor, because the hull is a boat and its planing bottom is well under the cabin
	# sole -- the opposite way round from the Cessna, where the belly pinches in above it. A
	# consumer that read either one as the other would be wrong on one of the two aeroplanes.
	var floor_y: float = float(promise.get("floor", NAN))
	_check("and_the_floor_is_published_beside_the_room_because_the_hull_is_deeper_than_the_cabin",
		is_finite(floor_y) and floor_y > room.position.y and floor_y < room.end.y,
		"the crew stand at h %.2f, %.2f m above the room's own bottom at h %.2f"
			% [floor_y, floor_y - room.position.y, room.position.y])
	view.queue_free()


## THE DRAWN SKIN, as triangles in the craft's frame, off the fuselage this aeroplane is wearing.
func _fuselage_triangles(view: VehicleView) -> PackedVector3Array:
	var out := PackedVector3Array()
	var part := view.find_child("WaterBomberFuselage", true, false) as MeshInstance3D
	if part == null or part.mesh == null:
		return out
	var into: Transform3D = view.global_transform.affine_inverse() * part.global_transform
	for surface in range(part.mesh.get_surface_count()):
		var arrays: Array = part.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for vertex in vertices:
				out.append(into * vertex)
		else:
			for index in indices:
				out.append(into * vertices[index])
	return out


## Sample the six faces of a box and count how many of them are not inside the skin.
func _samples_outside(skin: PackedVector3Array, box: AABB) -> Dictionary:
	var outside: int = 0
	var tested: int = 0
	var where := Vector3.ZERO
	for face in range(6):
		var axis: int = face / 2
		var far_side: bool = (face % 2) == 1
		var one: int = (axis + 1) % 3
		var two: int = (axis + 2) % 3
		for a in range(ROOM_SAMPLES):
			for b in range(ROOM_SAMPLES):
				var at := Vector3.ZERO
				at[axis] = box.end[axis] if far_side else box.position[axis]
				at[one] = box.position[one] + box.size[one] * float(a) / float(ROOM_SAMPLES - 1)
				at[two] = box.position[two] + box.size[two] * float(b) / float(ROOM_SAMPLES - 1)
				tested += 1
				if _inside(skin, at):
					continue
				outside += 1
				where = at
	return {"outside": outside, "tested": tested, "where": where}


## IS THIS POINT INSIDE THE LOFTED SKIN? A ray straight up and a ray straight down must each cross
## it an odd number of times. See the doc block above for why it is those two and not one.
func _inside(skin: PackedVector3Array, at: Vector3) -> bool:
	var up: int = 0
	var down: int = 0
	var triangle: int = 0
	while triangle + 2 < skin.size():
		var hit: float = _ray_crosses(at, skin[triangle], skin[triangle + 1], skin[triangle + 2])
		if is_finite(hit):
			if absf(hit) <= SKIN_TOLERANCE:
				return true
			if hit > 0.0:
				up += 1
			else:
				down += 1
		triangle += 3
	return up % 2 == 1 and down % 2 == 1


## WHERE A VERTICAL LINE THROUGH `at` CROSSES ONE TRIANGLE, as a signed height above it, or NAN if
## it misses. Barycentric in the xz plane, which is all a vertical ray needs and is a good deal
## cheaper than Moller-Trumbore for a thousand samples against five hundred triangles.
func _ray_crosses(at: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var v0 := Vector2(c.x - a.x, c.z - a.z)
	var v1 := Vector2(b.x - a.x, b.z - a.z)
	var v2 := Vector2(at.x - a.x, at.z - a.z)
	var denominator: float = v0.x * v1.y - v1.x * v0.y
	if absf(denominator) < 0.0000001:
		return NAN
	var u: float = (v2.x * v1.y - v1.x * v2.y) / denominator
	var v: float = (v0.x * v2.y - v2.x * v0.y) / denominator
	if u < 0.0 or v < 0.0 or u + v > 1.0:
		return NAN
	return (a.y + u * (c.y - a.y) + v * (b.y - a.y)) - at.y
