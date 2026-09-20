extends Node
## Headless: does a round leave the barrel, fly the right way, and land where it should?
##
##   Godot --headless --path cockpit res://tests/shots.tscn
##
## The gun is the first thing in this game whose result is a THING rather than a pose, and
## almost none of it can be judged by looking: a shell is in the air for two thirds of a
## second and covers a kilometre, so a screenshot catches one round in ten and tells you
## nothing about where it went. Every claim about a gun is a number, and they are here.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const TANK: int = 14
const GUNSHIP: int = 15
const HELI: int = 4
const CHINOOK: int = 8
const GUNBOAT: int = 9
const CARRIER: int = 12
const BATTLESHIP: int = 13

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[shots] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_the_tables_agree()
	_the_barrel_is_the_one_it_fires_from()
	await _a_round_goes_where_it_is_pointed()
	await _the_yard_draws_it()
	await _the_gunship_shoots_out_of_its_left_side()
	_the_gunner_gets_a_sight_and_the_driver_does_not()
	_a_gun_in_each_door()
	_every_ship_gunner_has_a_heavy_machine_gun()
	await _the_stops_hold_where_the_gun_rests()
	await _the_gun_goes_where_the_hands_go()
	await _it_fires_a_belt_and_not_a_tank_shell()
	_past_the_break_a_gun_fires_at_its_own_rate()
	_a_remote_round_is_wound_on_by_the_lag_the_clock_holds()
	_finish()


## ---- a remote round starts where it has got to ---------------------------------------

## A ROUND SOMEBODY ELSE FIRED IS WOUND FORWARD BY THE LAG THE CLOCK IS HOLDING -- the live one, and only that.
##
## `ShotYard` winds a birth record forward by `Sim.drawing_late()` once, at birth. That read the interpolation depth
## that was ASKED for, three frames, and on a real link sync's automatic clock holds more, because it sizes the lag to
## cover the link. So this builds a link: a server and a client in one process, packets carried by hand four ticks each
## way the way `cockpit_loopback` carries them, the client's interpolation set exactly as `Sim.start` sets it. And it
## asks the REAL `Sim.drawing_late()`, with `Sim.client` pointed at that client for one synchronous call.
##
## IT CAN FAIL both ways: the depth that was asked for is not the lag held, and the latency added on top of the lag
## would count the link twice.
##
## AND IT NEEDS SOMETHING TO INTERPOLATE. Sync only moves the lag while the client holds buffered entities
## (ashiato-sync `client_clock.cpp`, `record_buffered_timing`): the first run of this spawned only the client's own
## pilot, which is predicted, and the lag sat at the three frames asked for over a 4.5-frame link -- the old and the new
## function gave the same number and the test could not tell them apart. So an aeroplane nobody on this client flies
## is put in the world too, which is what every other aircraft in a real session is.
func _a_remote_round_is_wound_on_by_the_lag_the_clock_holds() -> void:
	const DELAY: int = 4
	var step: float = Sim.tick_dt()
	# UNTYPED, as `cockpit_loopback` keeps its worlds: the client is handed to `Sim.client` below, which is typed as
	# the RefCounted the extension class is, and an Object-typed local would be a downcast the analyser can refuse.
	var server = ClassDB.instantiate("CockpitWorld")
	var client = ClassDB.instantiate("CockpitWorld")
	server.set_tick_rate(Sim.tick_hz)
	client.set_tick_rate(Sim.tick_hz)
	client.set_interpolation(Sim.buffer_frames, true)
	server.start(0)
	client.start(1)
	for world in [server, client]:
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(400.0, 2.0, 400.0))
	var in_flight: Array = []
	var tick: int = 0
	var spawned: bool = false
	for i in range(1800):
		tick += 1
		server.tick(step)
		client.tick(step)
		for packet in server.take_outbound():
			in_flight.append([tick + DELAY, 1, packet["bytes"], packet["bits"]])
		for packet in client.take_outbound():
			in_flight.append([tick + DELAY, 0, packet["bytes"], packet["bits"]])
		var still: Array = []
		for entry in in_flight:
			if int(entry[0]) > tick:
				still.append(entry)
			elif int(entry[1]) == 0:
				server.deliver(1, entry[2], entry[3])
			else:
				client.deliver(0, entry[2], entry[3])
		in_flight = still
		# SOMETHING TO SEND, once the client has introduced itself.
		if not spawned and int(client.local_client_id()) > 0:
			server.spawn_pilot(int(client.local_client_id()), 0, Vector3(0.0, 40.0, 0.0), 0.0)
			# SOMEBODY ELSE'S AEROPLANE, interpolated on this client, so the clock has a reason to hold a lag.
			server.spawn_vehicle(1, Vector3(60.0, 120.0, 0.0), 0.0, Vector3(0.0, 0.0, -40.0))
			spawned = true
	# THE ENVIRONMENT FIRST, so a red below is about the function and not about a link that never got going: something
	# on this client is interpolated rather than predicted, which is what lets the lag move at all.
	var interpolated: int = 0
	for row in client.vehicle_states():
		if not bool((row as Dictionary).get("predicted", true)):
			interpolated += 1
	_check("and_the_client_interpolates_something", interpolated >= 1,
		"%d interpolated of %d vehicle(s)" % [interpolated, (client.vehicle_states() as Array).size()])
	var held: Dictionary = client.timing()
	var latency: float = float(held.get("latency_frames", 0.0))
	var lag: float = float(held.get("buffer_frames", 0.0))
	# THE REAL FUNCTION, on the delayed client, for one call and no frame in between.
	var was: Variant = Sim.client
	Sim.client = client
	var late: float = Sim.drawing_late()
	Sim.client = was
	_check("a_delayed_link_grows_the_lag_past_the_depth_asked_for",
		spawned and latency >= float(DELAY) * 0.75 and lag > float(Sim.buffer_frames),
		"%.1f frame(s) one way, lag held %.0f, asked for %d" % [latency, lag, Sim.buffer_frames])
	# WHAT `ShotYard` IS HANDED, against the live link: the whole lag held, which covers the latency.
	_check("and_a_remote_round_is_wound_on_by_the_lag_held",
		absf(late - lag * step) < 0.0001 and late >= latency * step,
		"drawing_late %.4f s; lag held %.0f frame(s) = %.4f s; one-way latency %.1f frame(s) = %.4f s"
			% [late, lag, lag * step, latency, latency * step])
	_check("and_the_link_is_not_counted_twice", late < (lag + latency * 0.5) * step,
		"%.4f s, where lag plus latency would be %.4f s" % [late, (lag + latency) * step])
	server.teardown()
	client.teardown()


## ---- the trigger is a finger and not a switch ------------------------------------

## HOW HARD THE TRIGGER IS PULLED IS HOW FAST THE GUN FIRES.
##
## PAST THE BREAK, THE GUN'S OWN RATE -- AND UNDER IT, NOTHING.
##
## The trigger under an index finger reports how far it is pulled, and for a while that was
## spent on a rate: a light pull walked a gun down to a quarter of its rate. In a headset a
## trigger rests part-pulled, so a door gun held with a relaxed finger fired a third as
## fast as it should and felt broken -- "mostly automatic, not one shot", 2026-09-13. A gun
## has one rate and a sear: past `kTriggerBreak` it fires at the rate, under it not at all.
##
## MEASURED AS ROUNDS IN TWO SECONDS OF SIMULATION at each pull, because that is the only
## thing a rate of fire IS.
func _past_the_break_a_gun_fires_at_its_own_rate() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	# NO CRASH RULE HERE (lane/combat): this helicopter falls through a world with nothing in it for twelve seconds of
	# trigger pulls, and an empty world's sea has no floor -- so once its settling was over it was "in the water",
	# destroyed, and fired nothing at a light pull (0.00 against 12.00). What is measured is a gun's rate, not a flight.
	if world.has_method("set_crashes"):
		world.set_crashes(false)
	var heli: int = int(world.spawn_vehicle(HELI, Vector3(0.0, 40.0, 0.0), 0.0, Vector3.ZERO))
	var reload: float = float((Sim.gun_of(HELI, 0) as Dictionary)["reload"])
	var full: float = _rounds_a_second(world, heli, 1.0)
	var half: float = _rounds_a_second(world, heli, 0.5)
	var light: float = _rounds_a_second(world, heli, 0.2)
	var under: float = _rounds_a_second(world, heli, 0.1)
	print("[shots] door gun rounds a second: full pull %.2f, half pull %.2f, a fifth %.2f, a tenth %.2f (rated %.2f)"
		% [full, half, light, under, 1.0 / reload])
	_check("a_squeezed_trigger_fires_at_the_guns_own_rate", absf(full - 1.0 / reload) <= 0.5,
		"%.2f a second, rated %.2f" % [full, 1.0 / reload])
	_check("and_a_half_pull_fires_at_the_same_rate", absf(half - full) <= 0.5,
		"%.2f against %.2f" % [half, full])
	_check("and_so_does_a_light_one_past_the_break", absf(light - full) <= 0.5,
		"%.2f against %.2f" % [light, full])
	_check("and_under_the_break_it_does_not_fire", under == 0.0, "%.2f a second" % under)
	world.teardown()


## Rounds a second the gun on mount 0 fires at `pull`, over two seconds of ticks.
func _rounds_a_second(world: Object, craft: int, pull: float) -> float:
	# THE GUN LOADED FIRST, so one pull's leftover reload is not counted against the next.
	for _wait in range(240):
		world.tick(TICK)
	var rounds: int = 0
	for _tick in range(240):
		if int(world.fire_gun_pulled(craft, 0, pull)) != 0:
			rounds += 1
		world.tick(TICK)
	return float(rounds) / (240.0 * TICK)


## ---- the two tables, which are keyed by the same number ---------------------------

## THE SIMULATION'S ROUNDS AND THE RENDERER'S ARE THE SAME ROUNDS.
##
## One table says how a round flies and the other says what it looks like -- see
## Ammunition -- and they are indexed by the same number off the wire. Two tables keyed by
## one number are two tables that drift apart, and the way it shows is ammunition 3 flying
## like canister and exploding like a shaped charge.
func _the_tables_agree() -> void:
	var gun: Dictionary = Sim.gun_of(TANK, 0)
	var wrong: Array[String] = []
	for row in (gun.get("rounds", []) as Array):
		var ammo: int = int(row["ammo"])
		var look: Dictionary = Ammunition.look(ammo)
		if String(look.get("name", "")) != String(row["name"]):
			wrong.append("%d is %s to the simulation and %s to the renderer"
				% [ammo, row["name"], look.get("name", "?")])
	_check("both_tables_name_the_same_rounds", wrong.is_empty(),
		"%s" % ["%d rounds" % (gun.get("rounds", []) as Array).size() if wrong.is_empty()
			else wrong])

	# AND THE FOUR OF THEM ARE ACTUALLY FOUR. A table whose rows differ by a scale factor
	# is a table that did not need to exist: the point of choosing a round is that the
	# choice shows, in the air and at the far end.
	var flat: float = float(Ammunition.look(0)["fireball"])
	var big: float = float(Ammunition.look(2)["fireball"])
	var shot_far: float = 0.0
	var shot_near: float = 0.0
	for row in (gun.get("rounds", []) as Array):
		if String(row["name"]) == "sabot":
			shot_far = float(row["drag"])
		elif String(row["name"]) == "canister":
			shot_near = float(row["drag"])
	_check("a_dart_has_no_fireball_and_a_shell_does", flat == 0.0 and big > 4.0,
		"sabot %.1f m, he %.1f m" % [flat, big])
	_check("and_a_dart_shoots_flat_where_canister_does_not", shot_near > shot_far * 20.0,
		"drag %.5f against %.5f" % [shot_near, shot_far])


## ---- the barrel ---------------------------------------------------------------------

## THE DRAWN BARREL IS THE ONE THE ROUND COMES OUT OF.
##
## The gun's length is in the simulation's table, because that is where the round is fired
## from. A renderer with its own idea of how long a barrel is draws a tank whose shells
## appear out of thin air a metre and a half past the end of the gun.
func _the_barrel_is_the_one_it_fires_from() -> void:
	var gun: Dictionary = Sim.gun_of(TANK, 0)
	var craft := (load("res://objects/vehicles/craft_tank.tscn") as PackedScene) \
		.instantiate() as VehicleView
	add_child(craft)
	craft._show_in_editor()
	var barrels: Array[float] = []
	for turret in craft.find_children("Turret*", "Node3D", true, false):
		for part in (turret as Node3D).get_children():
			var tube := (part as MeshInstance3D)
			if tube != null and tube.mesh is CylinderMesh:
				barrels.append((tube.mesh as CylinderMesh).height)
	var wanted: float = float(gun["barrel"])
	var matched: bool = false
	for length in barrels:
		if absf(length - wanted) < 0.01:
			matched = true
	_check("the_drawn_barrel_is_the_gun_the_simulation_fires", matched,
		"%.2f m wanted, drawn %s" % [wanted, barrels])
	craft.queue_free()


## ---- and the round itself -------------------------------------------------------------

## A LEVEL GUN, TWO AND A QUARTER METRES UP, ON A FLAT FIELD.
##
## Everything about this one is checkable against the back of an envelope, which is why it
## is the first test: the round falls 2.25 m under gravity, which takes 0.677 s, and in
## that time a 1700 m/s round with a fifth of a per cent of drag covers about 1.1 km.
func _a_round_goes_where_it_is_pointed() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	# The world's own ground: one enormous box with its top at zero, exactly as sky.gd
	# builds it.
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(16000.0, 400.0, 16000.0))
	var tank: int = int(world.spawn_vehicle(TANK, Vector3(0.0, 1.3, 0.0), 0.0, Vector3.ZERO))
	for i in range(30):
		world.tick(TICK)

	var fired: int = int(world.fire_gun(tank, 0))
	_check("the_gun_fires", fired != 0, "round %d" % fired)
	_check("and_will_not_fire_again_while_it_is_loading",
		int(world.fire_gun(tank, 0)) == 0, "refused, %.0f s to load" %
			float((Sim.gun_of(TANK, 0) as Dictionary)["reload"]))

	var flew: float = 0.0
	var impact := Vector3.ZERO
	var surface: int = -1
	for i in range(600):
		world.tick(TICK)
		flew += TICK
		var shots: Array = world.shot_states()
		if shots.is_empty():
			break
		var round_now: Dictionary = shots[0]
		if not bool(round_now["flying"]):
			impact = round_now["impact"]
			surface = int(round_now["surface"])
			break
	_check("and_the_round_lands", surface == Ammunition.GROUND,
		"surface %d after %.3f s at %s" % [surface, flew, impact])
	# The drop is the one number that cannot be argued with: 2.25 m under gravity.
	_check("after_the_time_it_takes_to_fall_that_far",
		absf(flew - sqrt(2.0 * 2.25 / 9.81)) < 0.02,
		"%.3f s against %.3f" % [flew, sqrt(2.0 * 2.25 / 9.81)])
	_check("a_kilometre_downrange", impact.z < -1050.0 and impact.z > -1160.0,
		"%.0f m" % absf(impact.z))
	# STRAIGHT. A round fired down the barrel of a tank pointing north lands north, and a
	# sideways drift of more than a hand's width over a kilometre is a sign error waiting.
	_check("and_dead_ahead", absf(impact.x) < 0.2, "%.3f m off the line" % impact.x)

	# ONE PACKET AT THE MUZZLE AND ONE AT THE IMPACT, and nothing in between: the whole
	# claim of the birth record. What is checked here is the half that is checkable without
	# a network -- that the record STOPS being reported once it is spent.
	#
	# NOT BEFORE ITS IMPACT CAN HAVE REACHED EVERY CLIENT. A landed round stays listed for the world's own spent time:
	# retired after three ticks, sync dropped an impact it had not yet found room to send, and a joined machine saw
	# no missile end at all. Asked of the world, not typed here.
	var kept: int = int(ceil(float(world.spent_seconds()) / TICK)) if world.has_method("spent_seconds") else 3
	for i in range(maxi(kept - 2, 0)):
		world.tick(TICK)
	_check("and_stays_long_enough_for_its_impact_to_reach_every_client",
		world.has_method("spent_seconds") and not (world.shot_states() as Array).is_empty(),
		"%d listed %d ticks after landing, of %d kept" % [(world.shot_states() as Array).size(), maxi(kept - 2, 0),
			kept])
	for i in range(4):
		world.tick(TICK)
	_check("and_is_taken_off_the_wire_once_it_has_landed",
		(world.shot_states() as Array).is_empty(),
		"%d still there" % (world.shot_states() as Array).size())
	world.teardown()
	await get_tree().process_frame


## ---- and somebody watching it ---------------------------------------------------------

## THE THING A PLAYER ACTUALLY SEES: a tracer in the air and a burst at the end of it.
##
## Drawn from the birth record by whoever is looking -- which is every machine, not just
## the shooter's -- so this drives the yard the way the world drives it and asks what it is
## holding.
func _the_yard_draws_it() -> void:
	var yard := ShotYard.new()
	add_child(yard)
	var shot: Dictionary = {
		"entity": 7, "from": Vector3(0.0, 2.0, 0.0), "velocity": Vector3(0.0, 0.0, -1700.0),
		"ammo": 0, "drag": 0.00005, "surface": Ammunition.FLYING, "flying": true,
		"impact": Vector3.ZERO,
	}
	yard.draw_shots([shot], Vector3(0.0, 2.0, 40.0), TICK)
	_check("a_round_in_the_air_is_drawn", yard.in_the_air() == 1,
		"%d drawn" % yard.in_the_air())

	# AND IT MOVES, at the speed it was fired at rather than at some speed of the
	# renderer's own.
	var was: Vector3 = Vector3.ZERO
	for node in yard.get_children():
		if node is MeshInstance3D:
			was = (node as MeshInstance3D).global_position
	yard.draw_shots([shot], Vector3(0.0, 2.0, 40.0), 0.1)
	var now: Vector3 = Vector3.ZERO
	for node in yard.get_children():
		if node is MeshInstance3D:
			now = (node as MeshInstance3D).global_position
	_check("and_it_travels_at_the_speed_it_was_fired_at",
		absf(was.distance_to(now) - 170.0) < 12.0,
		"%.0f m in a tenth of a second" % was.distance_to(now))

	shot["flying"] = false
	shot["surface"] = Ammunition.GROUND
	shot["impact"] = Vector3(0.0, 0.0, -1100.0)
	yard.draw_shots([shot], Vector3(0.0, 2.0, 40.0), TICK)
	_check("and_the_tracer_goes_out_when_it_lands", yard.in_the_air() == 0,
		"%d still drawn" % yard.in_the_air())
	var bursts: int = 0
	for node in yard.get_children():
		if node is Burst and (node as Burst).visible:
			bursts += 1
	_check("and_something_happens_where_it_hit", bursts == 1, "%d bursts" % bursts)

	# A ROUND THAT EXPIRED IN THE AIR DOES NOT EXPLODE. Fired at the sky, it simply stops
	# being a round, and inventing a fireball for it puts explosions over the whole map
	# every time a gunship misses.
	var spent: Dictionary = shot.duplicate()
	spent["entity"] = 8
	spent["surface"] = Ammunition.SPENT
	yard.draw_shots([spent], Vector3.ZERO, TICK)
	var lit: int = 0
	for node in yard.get_children():
		if node is Burst and (node as Burst).visible:
			lit += 1
	_check("and_a_round_that_expired_in_the_air_does_not", lit == 1,
		"%d bursts, the one from before" % lit)
	yard.queue_free()
	await get_tree().process_frame


## ---- and the aeroplane with three of them --------------------------------------------

## THREE GUNS, THREE GUNNERS, AND ALL OF IT OUT OF THE LEFT SIDE.
##
## The claim that matters is the one a picture would not settle: that a round fired from a
## gunship flying north goes WEST. Everything about this aircraft follows from that -- the
## seats face left, the mounts rest left, the pilot flies a left orbit -- and one sign error
## anywhere in it produces an aeroplane that shoots itself down.
func _the_gunship_shoots_out_of_its_left_side() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(16000.0, 400.0, 16000.0))
	# Straight and level at 900 m, pointing north -- which in this game's axes is -Z.
	var ship: int = int(world.spawn_vehicle(GUNSHIP, Vector3(0.0, 900.0, 0.0), 0.0,
		Vector3(0.0, 0.0, -68.0)))
	for i in range(10):
		world.tick(TICK)

	var guns: Array[String] = []
	var muzzles: Array[float] = []
	for mount in range(3):
		var gun: Dictionary = Sim.gun_of(GUNSHIP, mount)
		if bool(gun.get("fitted", false)):
			guns.append(String(Ammunition.look(int(gun["ammo"]))["name"]))
			muzzles.append(float(gun["reload"]))
	_check("it_has_three_guns_and_they_are_three_different_guns",
		guns.size() == 3 and guns[0] != guns[1] and guns[1] != guns[2], "%s" % [guns])
	# A rotary cannon and a field howitzer are two orders apart in rate, and that is most of
	# what makes them feel like different weapons.
	_check("and_they_fire_at_wildly_different_rates",
		muzzles.size() == 3 and muzzles[2] > muzzles[0] * 100.0,
		"%.3f s, %.2f s and %.1f s between rounds" % [muzzles[0], muzzles[1], muzzles[2]])

	var fired: int = int(world.fire_gun(ship, 0))
	_check("the_cannon_fires", fired != 0, "round %d" % fired)
	var shots: Array = world.shot_states()
	var went := Vector3.ZERO
	var left_of_the_hull: float = 0.0
	if not shots.is_empty():
		var round_now: Dictionary = shots[0]
		went = round_now["velocity"]
		left_of_the_hull = (round_now["from"] as Vector3).x
	# WEST. Facing -Z with +X to the right, the left side is -X, and a round leaving a gun
	# bolted in that side has to be going that way.
	_check("and_the_round_goes_out_of_the_left_side",
		went.x < -600.0 and absf(went.z + 68.0) < 40.0,
		"velocity %s" % went)
	_check("and_it_leaves_from_the_left_side_of_the_hull", left_of_the_hull < -1.5,
		"%.2f m off the centreline" % left_of_the_hull)
	# AND IT CARRIES THE AEROPLANE WITH IT. A round fired sideways out of something doing
	# 68 m/s is doing 68 m/s forwards as well, and a shot that forgot it would miss by the
	# width of the orbit.
	_check("and_it_carries_the_aeroplanes_own_speed", absf(went.z + 68.0) < 8.0,
		"%.1f m/s along the aircraft" % went.z)

	# THE 25 MM IS A STREAM. Thirty a second, which is what makes it a different thing from
	# the howitzer rather than a smaller version of it.
	var rounds: int = 0
	for i in range(120):
		world.tick(TICK)
		if int(world.fire_gun(ship, 0)) != 0:
			rounds += 1
	_check("and_the_cannon_is_a_stream_rather_than_a_series_of_bangs",
		rounds >= 28 and rounds <= 32, "%d rounds in a second" % rounds)
	world.teardown()
	await get_tree().process_frame


## ---- and the seat in front of the gun -------------------------------------------------

## A SIGHT AND A TRIGGER GO TO THE SEATS WITH GUNS, and to no others.
##
## One station scene serves every seat in a craft, so what a seat GETS is fitted rather than
## authored -- the same mechanism that puts two displays in front of a gunner and none in
## front of a pilot. The thing to check is that it lands on the right seats: a tank's
## commander drives and does not want a reticle across his windscreen, and a gunship's three
## gunners each want their OWN gun rather than three views of the first one.
func _the_gunner_gets_a_sight_and_the_driver_does_not() -> void:
	var craft := (load("res://objects/vehicles/craft_tank.tscn") as PackedScene) \
		.instantiate() as VehicleView
	add_child(craft)
	craft._show_in_editor()
	var sights: Array[int] = []
	var triggers: Array[int] = []
	for station in craft.stations():
		var seat: int = (station as CockpitStation).seat
		if station.get_node_or_null("Sight") != null:
			sights.append(seat)
		if station.get_node_or_null("Trigger") != null:
			triggers.append(seat)
	sights.sort()
	# Seat 0 drives. Seat 1 has the gun. Seat 2 is a turret seat with nothing on its mount,
	# and it gets nothing -- a sight for a gun that does not exist is worse than no sight.
	_check("the_gunner_gets_a_sight_and_nobody_else_does", sights == [1],
		"seats %s" % [sights])
	_check("and_a_trigger_with_it", triggers == sights, "seats %s" % [triggers])
	craft.queue_free()

	var ship := (load("res://objects/vehicles/craft_gunship.tscn") as PackedScene) \
		.instantiate() as VehicleView
	add_child(ship)
	ship._show_in_editor()
	var mounts: Array[int] = []
	for station in ship.stations():
		var sight := station.get_node_or_null("Sight") as GunSight
		if sight != null:
			mounts.append(sight.mount)
	mounts.sort()
	# THREE SIGHTS, THREE MOUNTS, one each. Mounts are counted in seat order -- the rule
	# the simulation aims and fires by -- and a sight that showed mount 0 to everybody
	# would have two of the three gunners watching somebody else's gun.
	_check("and_a_gunship_gives_its_three_gunners_three_different_guns",
		mounts == [0, 1, 2], "mounts %s" % [mounts])

	# AND THEY LAY THEM WITH A JOYSTICK. One station scene serves every seat in a craft, so
	# the gunship's three gun positions were handed the flight deck's YOKE -- a two-handed
	# wheel on a column, which is what you fly an airliner with and nothing at all like what
	# you traverse a gun with. Fitted per seat now, for the same reason the sight is.
	var flying: Array[String] = []
	for station in ship.stations():
		var here: CockpitStation = station as CockpitStation
		var control: VehicleControl = here.controls().get("stick") as VehicleControl
		var what: String = "nothing"
		if control is FlightStick:
			what = "a stick"
		elif control is ControlYoke:
			what = "a yoke"
		flying.append("%d flies with %s" % [here.seat, what])
	flying.sort()
	# The flight deck keeps its yoke. This is not "gunships get sticks", it is "a seat that
	# lays a gun gets a stick", and seat 0 flies the aeroplane.
	_check("and_the_gunners_lay_them_with_a_joystick_rather_than_the_flight_decks_yoke",
		flying == ["0 flies with a yoke", "1 flies with a stick",
			"2 flies with a stick", "3 flies with a stick"],
		"%s" % [flying])

	# AND THE GRIP IS ON THE GUNNER'S SIDE OF THE GRIP.
	#
	# The seat faces -Z, so a grab point at -Z of the control's own origin is on the FAR
	# side of it: you reach through the body of the thing for a part that was never visible
	# in the first place. That is exactly what the trigger did -- a red blade on the far
	# face of a grey block, three centimetres beyond it -- and every existing check passed
	# throughout, because the control was in the right PLACE and only pointing the wrong way.
	#
	# ASKED OF THE TRIGGER AND NOT OF EVERY CONTROL, which was the first thing tried and is
	# wrong: a yoke's rim really is at the far end of its own column, because a yoke is a
	# thin column with the wheel out at arm's length and nothing of it hides anything else.
	# A pistol grip is a solid block and the rule is about solid blocks. What covers the
	# general case is looking, which is what tests/station_shot.gd is for.
	var wrong_way: Array[String] = []
	for station in ship.stations():
		var gun := (station as Node3D).get_node_or_null("Trigger") as VehicleControl
		if gun == null:
			continue
		# IN THE CONTROL'S OWN FRAME, which is the gunner's. A world-space subtraction was
		# the first attempt and reported every gunship seat as 0.000 m wrong: those seats
		# are YAWED NINETY DEGREES to face the guns down the left side, so the gunner's
		# "toward me" is the world's X and the Z it measured was noise.
		var reach: Vector3 = gun.to_local(gun.grip_global())
		if reach.z < 0.0:
			wrong_way.append("seat %d, %.3f m the wrong side"
				% [(station as CockpitStation).seat, -reach.z])
	_check("and_the_gun_is_taken_hold_of_from_the_gunners_side_of_it",
		wrong_way.is_empty(),
		"%s" % ["every grip faces the seat" if wrong_way.is_empty() else wrong_way])
	ship.queue_free()


## ---- the door guns ---------------------------------------------------------------------

## A GUN IN EACH DOOR OF THE HELICOPTER, AND ONE ON THE CHINOOK'S RAMP.
##
## The table is the claim: which craft carry one, which mount is which seat's, and which
## way each of them points before anybody touches it. A door gun that rested down the nose
## would be a door gun firing through the cabin wall on its first round.
func _a_gun_in_each_door() -> void:
	var left: Dictionary = Sim.gun_of(HELI, 0)
	var right: Dictionary = Sim.gun_of(HELI, 1)
	_check("the_helicopter_has_a_gun_in_each_door",
		bool(left.get("fitted", false)) and bool(right.get("fitted", false)),
		"mounts %s and %s" % [left.get("fitted", false), right.get("fitted", false)])
	# +pi/2 is the aircraft's left -- forward is -Z and +X is right -- so the two rest
	# angles are a quarter turn either way, and the two mounts are outside the cabin on
	# opposite sides. One sign wrong here is a gun pointing across its own cockpit.
	var rests := Vector2(float((left.get("rest", Vector2.ZERO) as Vector2).x),
		float((right.get("rest", Vector2.ZERO) as Vector2).x))
	_check("and_they_rest_pointing_out_of_opposite_sides",
		absf(rests.x - PI * 0.5) < 0.01 and absf(rests.y + PI * 0.5) < 0.01,
		"%.2f and %.2f rad" % [rests.x, rests.y])
	_check("and_hang_outside_the_cabin_on_the_side_they_shoot_from",
		(left.get("at", Vector3.ZERO) as Vector3).x < -0.95
			and (right.get("at", Vector3.ZERO) as Vector3).x > 0.95,
		"%.2f m and %.2f m off the centreline" % [
			(left.get("at", Vector3.ZERO) as Vector3).x,
			(right.get("at", Vector3.ZERO) as Vector3).x])
	# AND THE SEATS TURNED OUT TO MEET THEM. A door gunner faces the door: there is nothing
	# out of the front of a helicopter for them and the whole side is open beside them.
	var yaws: Array[float] = []
	for pose in (Sim.geometry_of(HELI).get("seat_poses", []) as Array):
		yaws.append(float((pose as Dictionary).get("yaw", 0.0)))
	_check("and_the_back_seats_are_turned_out_of_the_doors_to_reach_them",
		yaws.size() == 4 and absf(yaws[0]) < 0.01 and absf(yaws[1]) < 0.01
			and absf(yaws[2] - PI * 0.5) < 0.01 and absf(yaws[3] + PI * 0.5) < 0.01,
		"seat yaws %s" % [yaws])

	# THE CHINOOK CARRIES ONE, ON THE RAMP, AND MOUNTS ARE COUNTED IN SEAT ORDER -- so the
	# ramp is mount 1 and the mid-cabin turret seat, which has no gun, is mount 0. A craft
	# whose only gun was assumed to be mount 0 would arm the wrong seat.
	_check("the_chinook_carries_one_on_the_ramp_and_nothing_amidships",
		not bool((Sim.gun_of(CHINOOK, 0) as Dictionary).get("fitted", false))
			and bool((Sim.gun_of(CHINOOK, 1) as Dictionary).get("fitted", false)),
		"mount 0 %s, mount 1 %s" % [
			(Sim.gun_of(CHINOOK, 0) as Dictionary).get("fitted", false),
			(Sim.gun_of(CHINOOK, 1) as Dictionary).get("fitted", false)])
	_check("and_it_points_where_that_seat_is_already_looking",
		absf(absf(float((Sim.gun_of(CHINOOK, 1).get("rest", Vector2.ZERO) as Vector2).x))
			- PI) < 0.01
			and absf(absf(float((Sim.geometry_of(CHINOOK).get("seat_poses", [])[3]
				as Dictionary).get("yaw", 0.0))) - PI) < 0.01,
		"gun and seat both aft")
	# AND THEY ARE SWUNG BY HAND, which is what puts the gun itself in the cockpit instead
	# of a joystick. The gunship's are not: those are powered mounts on a fuselage.
	_check("a_door_gun_is_hand_swung_and_a_gunships_guns_are_not",
		bool(left.get("pintle", false))
			and not bool((Sim.gun_of(GUNSHIP, 0) as Dictionary).get("pintle", false)),
		"door %s, gunship %s" % [left.get("pintle", false),
			(Sim.gun_of(GUNSHIP, 0) as Dictionary).get("pintle", false)])
	# AND IT TRAINS FASTER THAN A MOTOR DOES, because it is somebody's arms.
	_check("and_it_trains_faster_than_a_powered_mount",
		float(left.get("slew", 0.0)) > float((Sim.gun_of(GUNSHIP, 0) as Dictionary)
			.get("slew", 99.0)) * 2.0,
		"%.1f rad/s against %.1f" % [left.get("slew", 0.0),
			(Sim.gun_of(GUNSHIP, 0) as Dictionary).get("slew", 0.0)])


## EVERY SHIP'S GUNNER HAS A GUN, AND IT IS AT THEIR HANDS.
##
## The gunboat, the battleship and the carrier were each built with a gunner fore and aft and
## given nothing to shoot: `gun_of` had no row for them, so a player in either seat pulled a
## trigger that did nothing (found 2026-09-13, asked for as "ships with machine guns"). Every
## turret seat on each is checked for a fitted, hand-swung 12.7 pointing where the seat looks --
## and then a real station is built and the grips measured against a seated pair of hands, the
## same measurement the door guns answer to, because a gun placed from a seat table is only
## right if the seat table and the cockpit agree about where the hands are.
##
## NOT THE BATTLESHIP ANY MORE: its turret seats work its sixteen-inch turrets (plan item 22), held in tests/big_guns.gd.
func _every_ship_gunner_has_a_heavy_machine_gun() -> void:
	for kind in [GUNBOAT, CARRIER]:
		var poses: Array = Sim.geometry_of(kind).get("seat_poses", []) as Array
		var armed: Array[String] = []
		var wrong: Array[String] = []
		# HOW MANY GUNNERS THIS SHIP HAS IS THE SHIP'S ANSWER, not a number typed here. It WAS
		# `armed.size() == 2`, true of both ships while both had two tubs crewed; the carrier's
		# port-quarter seat went to the flag plot on 2026-09-17 and a typed 2 would have had to
		# become a typed table of per-kind counts -- a second roster of something the shape table
		# already knows (CLAUDE.md rule 4). A kind with NO turret seat still fails, because a
		# check that passes on a ship with no gunners passes on anything.
		var gunners: int = 0
		for pose in poses:
			gunners += 1 if String((pose as Dictionary).get("station", "")) == "turret" else 0
		for seat in range(poses.size()):
			var mount: int = Sim.mount_of_seat(kind, seat)
			if mount < 0:
				continue
			var gun: Dictionary = Sim.gun_of(kind, mount)
			var ammo: int = int(gun.get("ammo", -1))
			var rest: float = float((gun.get("rest", Vector2.ZERO) as Vector2).x)
			var yaw: float = float((poses[seat] as Dictionary).get("yaw", 0.0))
			if not bool(gun.get("fitted", false)) or not bool(gun.get("pintle", false)) \
					or String(Ammunition.look(ammo).get("name", "")) != "12.7mm" \
					or absf(angle_difference(rest, yaw)) > 0.01:
				wrong.append("seat %d: fitted %s, pintle %s, %s, rests at %.2f facing %.2f" % [seat,
					gun.get("fitted", false), gun.get("pintle", false), Ammunition.look(ammo).get("name", "?"), rest, yaw])
			else:
				armed.append("seat %d" % seat)
		_check("every_%s_gunner_has_a_hand_swung_12_7_pointing_where_the_seat_looks" % Sim.kind_name(kind),
			wrong.is_empty() and gunners > 0 and armed.size() == gunners,
			"armed %s of the ship's %d turret seats%s" % [armed, gunners,
				"" if wrong.is_empty() else "; %s" % [wrong]])
		_reachable_and_clear(kind, null, null)


## THE STOPS HOLD EVEN WHERE THE ARC STRADDLES THE WRAP.
##
## The Chinook's ramp gun rests pointing AFT, so its arc runs from 2.09 to 4.19 radians
## while the angle being clamped wraps at 3.14. Clamped against those two numbers, then
## wrapped, the barrel jumped from one end of the arc to the other every tick it was pushed
## past due aft -- a gun that flips round to face forwards when you traverse it.
##
## Held hard against each stop for two seconds, which is twice as long as it takes to get
## there: the answer is the same at both ends and it is inside the arc.
func _the_stops_hold_where_the_gun_rests() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var made: Dictionary = world.spawn_pilot(70, CHINOOK, Vector3(0.0, 200.0, 0.0), 0.0,
		Vector3.ZERO)
	var craft: int = int(made.get("vehicle", 0))
	var gunner: int = int(made.get("pilot", 0))
	# ONTO THE RAMP, which is seat 3 and mount 1.
	world.seat_client(70, craft, 3)
	var gun: Dictionary = Sim.gun_of(CHINOOK, 1)
	var span: float = float(gun.get("yaw_span", 0.0))
	var rest: float = float((gun.get("rest", Vector2.ZERO) as Vector2).x)
	var ends: Array[float] = []
	var worst: float = 0.0
	for way in [1.0, -1.0]:
		world.set_pilot_input(gunner, {"roll": way, "pitch": 0.0})
		for i in range(240):
			world.tick(TICK)
			var now: float = float((world.craft_systems(craft).get("turrets", [])[1]
				as Vector2).x)
			worst = maxf(worst, absf(wrapf(now - rest, -PI, PI)))
		ends.append(float((world.craft_systems(craft).get("turrets", [])[1] as Vector2).x))
	_check("a_gun_resting_aft_stays_inside_its_own_arc",
		worst <= span + 0.02, "%.2f rad off the rest, arc is %.2f" % [worst, span])
	# AND THE TWO ENDS ARE THE TWO ENDS, a full arc apart and neither of them the rest.
	# A gun that had flipped would come back with both ends the same, or with the second
	# one on top of the first.
	var apart: float = absf(wrapf(ends[0] - ends[1], -PI, PI))
	_check("and_the_two_stops_are_a_full_arc_apart",
		absf(apart - span * 2.0) < 0.05, "%.2f rad between the stops, wanted %.2f" % [
			apart, span * 2.0])
	world.teardown()
	await get_tree().process_frame


## WHERE THE GRIPS ENDED UP, asked of a station that has a gun in it.
##
## Two things, pulling in opposite directions. A gun is bolted where the SIMULATION says the
## mount is -- it has to be, or the barrel everybody outside can see is not the one in the
## gunner's hands -- and it still has to land within reach of a seated pair of arms. Move
## the mount in the gun table and this is what says whether anybody can still get hold of it.
##
## AND CLEAR OF EVERY OTHER CONTROL IN THE STATION, which is the crowding rule the whole
## cockpit obeys: two grips closer than two REACHes share a place a hand can be, and which
## one it gets is then down to iteration order. The smoke suite checks that for the controls
## a seat scene AUTHORS. A gun is fitted at runtime out of the gun table, so it is invisible
## to that check and can only be made here.
##
## `station` and `gun` are handed in when the caller already has them; otherwise the craft
## is built here, which is the whole of what the second call needs.
func _reachable_and_clear(kind: int, station: CockpitStation, gun: PintleGun) -> void:
	var view: VehicleView = null
	if station == null:
		view = (load("res://objects/vehicles/craft_%s.tscn" % Sim.kind_name(kind))
			as PackedScene).instantiate() as VehicleView
		add_child(view)
		view._show_in_editor()
		for one in view.stations():
			var here := one as CockpitStation
			var held := here.controls().get("stick") as PintleGun
			if held != null:
				station = here
				gun = held
	if station == null or gun == null:
		_check("the_%s_has_a_gun_to_reach_for" % Sim.kind_name(kind), false, "none fitted")
		if view != null:
			view.queue_free()
		return
	var grip: Vector3 = station.to_local(gun.grip_global())
	_check("the_%s_gunners_grips_are_where_their_hands_are" % Sim.kind_name(kind),
		absf(grip.y - CockpitStation.hands()) < 0.12 and grip.z < 0.0
			and Vector2(grip.x, grip.z).length() < 0.55,
		"grips %.2f m up and %.2f m out, hands at %.2f" % [
			grip.y, Vector2(grip.x, grip.z).length(), CockpitStation.hands()])
	var crowded: Array[String] = []
	for role in station.controls():
		var other := station.controls()[role] as VehicleControl
		if other == null or other == gun:
			continue
		var apart: float = other.grip_global().distance_to(gun.grip_global())
		if apart < VehicleControl.REACH * 2.0:
			crowded.append("%s %.2f m away" % [other.name, apart])
	_check("and_nothing_else_in_the_%s_is_within_one_hand_of_them" % Sim.kind_name(kind),
		crowded.is_empty(), "%s" % ["clear" if crowded.is_empty() else crowded])
	if view != null:
		view.queue_free()


## THE GUN GOES WHERE THE HANDS GO, END TO END.
##
## Everything from a hand in a cockpit to a barrel on a helicopter, in one loop: the station
## draws the gun at the angle the simulation says it is, the hand asks for a demand against
## THAT angle, the demand goes onto the control frame the same way a stick's does, and the
## mount moves. Every sign in the chain has to agree or the gun runs away from the hand.
##
## The hand is held STILL, off to one side of the grips, and the claim is that the gun ends
## up with its grips under it and stops -- which is the whole of what a swivel does and
## something no rate-driven stick can do at all.
func _the_gun_goes_where_the_hands_go() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var made: Dictionary = world.spawn_pilot(71, HELI, Vector3(0.0, 200.0, 0.0), 0.0,
		Vector3.ZERO)
	var craft: int = int(made.get("vehicle", 0))
	var gunner: int = int(made.get("pilot", 0))
	# THE LEFT-HAND DOOR, which is seat 2 and mount 0.
	world.seat_client(71, craft, 2)

	var view := (load("res://objects/vehicles/craft_heli.tscn") as PackedScene) \
		.instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var station: CockpitStation = null
	for one in view.stations():
		if (one as CockpitStation).seat == 2:
			station = one as CockpitStation
	var gun := (station.controls().get("stick") if station != null else null) as PintleGun
	_check("a_door_gunner_is_given_the_gun_rather_than_a_joystick", gun != null,
		"seat 2 holds %s" % [station.controls().get("stick") if station != null else null])
	if gun == null:
		world.teardown()
		await get_tree().process_frame
		return
	# AND IT IS THE THING THAT FIRES, so a player at a keyboard -- who has no hands to hold
	# anything with -- can still shoot it.
	_check("and_the_gun_is_its_own_trigger", station.controls().get("trigger") == gun,
		"%s" % [station.controls().get("trigger")])
	_reachable_and_clear(HELI, station, gun)
	# AND THE SAME ASKED OF THE CHINOOK'S RAMP, which is the other station in the game with
	# a gun in it and a different seat pose entirely: at the back, turned right round, and
	# a metre and a half lower in the hull.
	_reachable_and_clear(CHINOOK, null, null)

	# THE LOOP. A hand held still, out to the gunner's right of the grips and a little
	# above them, for two seconds of simulated time.
	var rest := Vector3(0.0, PintleGun.GRIP_RISE, PintleGun.GRIP_BACK)
	var hand: Vector3 = rest + Vector3(0.10, 0.06, 0.0)
	var was: Vector2 = world.craft_systems(craft).get("turrets", [])[0]
	for i in range(240):
		station.aim_the_gun(world.craft_systems(craft).get("turrets", []))
		gun.offer_hand(1, hand, 1.0)
		world.set_pilot_input(gunner, {"roll": gun.roll(), "pitch": gun.pitch()})
		world.tick(TICK)
	var now: Vector2 = world.craft_systems(craft).get("turrets", [])[0]

	# WHERE IT SHOULD HAVE ENDED UP: with the grips under the hand. That is an angle either
	# way from the rest, and it is arithmetic rather than a fitted number -- the bearing of
	# the hand from the trunnion, against the bearing of the grips.
	var wanted_yaw: float = atan2(rest.z, rest.x) - atan2(hand.z, hand.x)
	var wanted_pitch: float = atan2(rest.y, rest.z) - atan2(hand.y, hand.z)
	_check("the_gun_swings_until_its_grips_are_under_the_hand",
		absf(wrapf(now.x - (was.x + wanted_yaw), -PI, PI)) < 0.03,
		"traversed %.3f rad, wanted %.3f" % [wrapf(now.x - was.x, -PI, PI), wanted_yaw])
	# AND PUSHING THE GRIPS UP PUTS THE MUZZLE DOWN, which is what a gun hinged in the
	# middle does and the single most confusing thing about one if it is got backwards.
	_check("and_lifting_the_grips_depresses_the_barrel",
		now.y < was.y - 0.05
			and absf(now.y - (was.y - absf(wanted_pitch))) < 0.05,
		"elevation %.3f rad from %.3f" % [now.y, was.y])
	# AND THEN IT STOPS. A rate-driven stick held off centre traverses for ever; a hand on
	# a swivel is an error, and an error that has been answered is zero.
	_check("and_then_stops_rather_than_traversing_for_ever",
		Vector2(gun.roll(), gun.pitch()).length() < 0.05,
		"still asking for %.3f" % Vector2(gun.roll(), gun.pitch()).length())
	# AND LETTING GO STOPS IT DEAD, rather than leaving the last demand on the frame.
	gun.offer_hand(1, hand, 0.0)
	_check("and_letting_go_asks_for_nothing_at_all",
		Vector2(gun.roll(), gun.pitch()).length() < 0.001,
		"asking for %.3f" % Vector2(gun.roll(), gun.pitch()).length())
	view.queue_free()
	world.teardown()
	await get_tree().process_frame


## A BELT, NOT A READY RACK.
##
## Two claims, and the second one is a bug this gun found in every other gun in the game.
## Eleven rounds a second is what makes a machine gun a machine gun. And what comes out of
## it is 7.62 -- not the tank's sabot round, which is what the `Weapon` bus selector was
## quietly loading into every gun aboard every craft, because that selector starts at zero
## and zero is the first round in a tank's rack.
func _it_fires_a_belt_and_not_a_tank_shell() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(16000.0, 400.0, 16000.0))
	var heli: int = int(world.spawn_vehicle(HELI, Vector3(0.0, 300.0, 0.0), 0.0,
		Vector3.ZERO))
	for i in range(10):
		world.tick(TICK)
	var rounds: int = 0
	var loaded: int = -1
	for i in range(120):
		world.tick(TICK)
		var fired: int = int(world.fire_gun(heli, 0))
		if fired == 0:
			continue
		rounds += 1
		for shot in (world.shot_states() as Array):
			if int((shot as Dictionary)["entity"]) == fired:
				loaded = int((shot as Dictionary)["ammo"])
	_check("a_door_gun_fires_a_belt_rather_than_one_round_at_a_time",
		rounds >= 10 and rounds <= 13, "%d rounds in a second" % rounds)
	_check("and_what_comes_out_of_it_is_the_round_the_gun_is_fed",
		loaded >= 0 and String(Ammunition.look(loaded)["name"]) == "7.62mm",
		"fired %s" % [Ammunition.look(loaded)["name"] if loaded >= 0 else "nothing"])
	world.teardown()
	await get_tree().process_frame

	# AND THE SAME FIX SEEN FROM THE GUNSHIP: three guns whose selector says which of them
	# is HOT, not which round is loaded. Every one of them was firing a tank's dart.
	var over: Object = ClassDB.instantiate("CockpitWorld")
	over.set_tick_rate(120.0)
	over.start(0)
	over.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(16000.0, 400.0, 16000.0))
	var ship: int = int(over.spawn_vehicle(GUNSHIP, Vector3(0.0, 900.0, 0.0), 0.0,
		Vector3.ZERO))
	for i in range(10):
		over.tick(TICK)
	var shell: int = -1
	var cannon: int = int(over.fire_gun(ship, 0))
	for shot in (over.shot_states() as Array):
		if int((shot as Dictionary)["entity"]) == cannon:
			shell = int((shot as Dictionary)["ammo"])
	_check("and_a_25_mm_cannon_fires_25_mm",
		shell >= 0 and String(Ammunition.look(shell)["name"]) == "25mm",
		"fired %s" % [Ammunition.look(shell)["name"] if shell >= 0 else "nothing"])
	over.teardown()
	await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
