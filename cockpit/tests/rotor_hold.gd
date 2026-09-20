extends Node
## Headless: AN AI-FLOWN ROTORCRAFT WITH NOWHERE TO GO HOLDS THE HEIGHT IT IS GIVEN. Read RESULT=.
##
##   Godot --headless --path cockpit res://tests/rotor_hold.tscn
##
## THE FAULT (the user, watching the light helicopter's reel on 2026-09-17: "it doesn't appear to be above the ground
## at the end"): the fly bench spawns every craft's autopilot at 520 m with no waypoints, on the belief that 520 m is
## where an autopilot with nowhere to go holds. It is -- for an AEROPLANE. `CockpitWorld::recovery_height` sends a
## helicopter to 220 m over the ground, so the heli, UH-60 and Chinook each left 520 m at 12 m/s and were at 250 m after
## 24 s, straight through the reel's stage ground at 400 m. Measured here, as built and with the fix. Not a throttle
## fault: the autopilot flies its collective, and it was flying it DOWN to where it was told to be.
##
## THE FIX IS THE REAL PATH THE WORLD ALREADY HAS: `set_ai_altitude`, which `HoldingStack` gives each aircraft in a
## stack. The bench now hands its autopilot the height it spawned it at (`CockpitBench.FLY_HEIGHT`).
##
## HELD: each rotorcraft, spawned as the bench spawns it and held, ends 24 s within HOLD_WITHIN of its start and never
## below it by more. UNHELD, the same craft must still go down -- if a later autopilot holds its spawn height on its
## own, the bench's hold is redundant and this says so rather than passing quietly.

const DT := 1.0 / 60.0
const SECONDS := 24.0
const HOLD_WITHIN := 10.0
const KINDS: Array = [Sim.Kind.HELI, Sim.Kind.UH60, Sim.Kind.CHINOOK, Sim.Kind.LITTLEBIRD, Sim.Kind.APACHE, Sim.Kind.OSPREY]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[rotor_hold] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("the_native_library_is_loaded", false, "CockpitWorld missing")
		_finish()
		return
	var held_said: PackedStringArray = []
	var held_ok := true
	var free_said: PackedStringArray = []
	var rotors_sink := true
	for kind in KINDS:
		var free: Vector2 = _fly(kind, false)
		var held: Vector2 = _fly(kind, true)
		held_ok = held_ok and absf(held.x - CockpitBench.FLY_HEIGHT) <= HOLD_WITHIN \
			and held.y >= CockpitBench.FLY_HEIGHT - HOLD_WITHIN
		held_said.append("%s ends %.1f m, lowest %.1f" % [Sim.kind_name(kind), held.x, held.y])
		free_said.append("%s %.0f m" % [Sim.kind_name(kind), free.x])
		if kind != Sim.Kind.OSPREY:
			rotors_sink = rotors_sink and free.x < CockpitBench.FLY_HEIGHT - 100.0
	_check("a_rotorcraft_the_bench_holds_ends_24_s_within_10_m_of_its_start_height", held_ok,
		"from %.0f m: %s" % [CockpitBench.FLY_HEIGHT, "; ".join(held_said)])
	_check("and_unheld_the_helicopters_still_go_down_to_their_own_recovery_height", rotors_sink,
		"after 24 s unheld: %s" % ", ".join(free_said))
	_the_collective_is_on_the_bus_and_the_height_follows_the_command()
	_finish()


## THE COLLECTIVE IS A LEVER ON THE BUS, AND THE HEIGHT FOLLOWS A COMMAND. The user asked that the reel's pilot "uses
## throttle to keep the craft in the air". The autopilot does: it flies its own collective and `publish_levers` writes it
## to the craft's `CraftControls.throttle` -- the same lever a player's hand moves and a copilot watches. Read here off
## the SERVER's bus and a CLIENT's replicated copy, as a player on another machine would see it:
## - held, the lever settles within 0.03 of the collective THAT CARRIES THE WEIGHT IN THE MODEL THE KIND FLIES, and a
##   client's copy agrees within 0.02. On the weight-fraction thruster that is `(1 - hover) / collective_range`; on a
##   rotor disc (`Handling::rotors`, the Little Bird) it is asked of the disc itself with `probe_rotor`, AT THE SPEED
##   AND HEIGHT THE CRAFT IS HOLDING, because a disc makes more thrust at the same collective once it is going fast
##   enough for translational lift: the Little Bird holds its height on 0.32 of the lever where the thruster's
##   arithmetic says 0.47, and the difference is exactly the disc's 18 per cent at full translational lift
##   (1 / 1.18 x 0.47 + a little). This check is about THE BUS -- that the lever the physics reads is the lever on the
##   wire and on a client's copy -- so what it holds the lever to has to be the physics the kind has, not the physics it
##   used to have (lane/flightcore, 2026-09-19: red on main from 851314da, the merge that gave the Little Bird its
##   disc).
## - asked 60 m higher, the craft climbs and settles within CLIMB_WITHIN of the new height inside CLIMB_SECONDS, the
##   lever going more than 0.05 over the weight's setting; asked back down, the same, with the lever 0.05 under it.
const STEP := 60.0
const CLIMB_SECONDS := 30.0
const CLIMB_WITHIN := 3.0


func _the_collective_is_on_the_bus_and_the_height_follows_the_command() -> void:
	var said: PackedStringArray = []
	var ok := true
	for kind in [Sim.Kind.HELI, Sim.Kind.UH60, Sim.Kind.CHINOOK, Sim.Kind.LITTLEBIRD, Sim.Kind.APACHE]:
		var server: Object = _world(0)
		var client: Object = _world(1)
		for i in range(90):
			_pair(server, client)
		var h: Dictionary = server.handling(kind)
		var craft: int = int(server.spawn_ai_vehicle(kind, Vector3(0.0, CockpitBench.FLY_HEIGHT, 0.0), 0.0,
			Vector3(0.0, 0.0, -Terrain.cruise_for(kind))))
		server.set_ai_altitude(craft, CockpitBench.FLY_HEIGHT)
		var legs: Array = []
		for target in [CockpitBench.FLY_HEIGHT, CockpitBench.FLY_HEIGHT + STEP, CockpitBench.FLY_HEIGHT]:
			server.set_ai_altitude(craft, target)
			var settled_at: float = -1.0
			var lever_high: float = -1.0
			var lever_low: float = 2.0
			var lever: float = -1.0
			var client_lever: float = -1.0
			var fastest: float = 0.0
			for i in range(int(CLIMB_SECONDS / DT)):
				_pair(server, client)
				var state: Dictionary = server.vehicle_state(craft)
				var y: float = (state.get("position", Vector3.ZERO) as Vector3).y
				fastest = maxf(fastest, absf((state.get("velocity", Vector3.ZERO) as Vector3).y))
				lever = float(server.craft_controls(craft).get("throttle", -1.0))
				lever_high = maxf(lever_high, lever)
				lever_low = minf(lever_low, lever)
				if settled_at < 0.0 and absf(y - target) <= CLIMB_WITHIN:
					settled_at = float(i) * DT
				elif absf(y - target) > CLIMB_WITHIN:
					settled_at = -1.0
			for state in client.vehicle_states():
				if int((state as Dictionary).get("kind", -1)) == kind:
					client_lever = float(client.craft_controls(int((state as Dictionary).get("entity", 0))).get("throttle", -1.0))
			var end: float = (server.vehicle_state(craft).get("position", Vector3.ZERO) as Vector3).y
			var flown: Vector3 = server.vehicle_state(craft).get("velocity", Vector3.ZERO)
			legs.append({"target": target, "end": end, "settled": settled_at, "lever": lever, "high": lever_high, "low": lever_low,
				"client_lever": client_lever, "fastest": fastest, "along": flown.length()})
		# Leg 0 holds, leg 1 climbs 60 m, leg 2 comes back down.
		var hold: Dictionary = legs[0]
		# WHAT CARRIES THE WEIGHT IN THIS KIND'S OWN MODEL, at the speed and height it just held at.
		var hover: float = _lever_that_carries(server, kind, h, float(hold["along"]), float(hold["end"]))
		var up: Dictionary = legs[1]
		var down: Dictionary = legs[2]
		var here: bool = absf(float(hold["end"]) - CockpitBench.FLY_HEIGHT) <= CLIMB_WITHIN 			and absf(float(hold["lever"]) - hover) <= 0.03 and absf(float(hold["client_lever"]) - float(hold["lever"])) <= 0.02 			and float(up["settled"]) >= 0.0 and float(up["high"]) > hover + 0.05 			and float(down["settled"]) >= 0.0 and float(down["low"]) < hover - 0.05
		ok = ok and here
		said.append("%s, weight carried at %.2f: held, the lever reads %.2f (a client sees %.2f) at %.1f m; +%.0f m settled in %.1f s with the lever up to %.2f, climbing at up to %.1f m/s; back down settled in %.1f s with it down to %.2f, at up to %.1f m/s" % [
			Sim.kind_name(kind), hover, hold["lever"], hold["client_lever"], hold["end"], STEP, up["settled"], up["high"],
			up["fastest"], down["settled"], down["low"], down["fastest"]])
		_let_go(server)
		_let_go(client)
	_a_disc_needs_less_collective_once_it_is_flying()
	_check("the_collective_is_a_lever_on_the_bus_that_holds_climbs_and_descends_on_command", ok, "
      ".join(said))


## AND WHY THE ONE ABOVE HAS TO ASK THE MODEL: a disc carries the weight on LESS collective once it is going fast
## enough for translational lift, and a formula beside it cannot know that. Held here on the disc itself, with the
## mutant that takes translational lift away (`rotor_mutant` 2) as the proof it is measuring it: without it, the two
## collectives must be the same.
##
## This is the check that was missing when the Little Bird moved onto its disc: `rotor_hold` went on comparing the
## flown lever with the thruster's arithmetic, wanted 0.47 from a helicopter that holds its height on 0.32, and was red
## on main from 851314da until 2026-09-19.
const TRANSLATIONAL: float = 24.0


func _a_disc_needs_less_collective_once_it_is_flying() -> void:
	var world: Object = _world(0)
	var kind: int = Sim.Kind.LITTLEBIRD
	var h: Dictionary = world.handling(kind)
	var standing: float = _lever_that_carries(world, kind, h, 0.0, CockpitBench.FLY_HEIGHT)
	var flying: float = _lever_that_carries(world, kind, h, TRANSLATIONAL, CockpitBench.FLY_HEIGHT)
	world.set_handling(kind, {"rotor_mutant": 2.0})
	var mutant_standing: float = _lever_that_carries(world, kind, h, 0.0, CockpitBench.FLY_HEIGHT)
	var mutant_flying: float = _lever_that_carries(world, kind, h, TRANSLATIONAL, CockpitBench.FLY_HEIGHT)
	world.set_handling(kind, {"rotor_mutant": 0.0})
	_let_go(world)
	_check("a_disc_carries_the_weight_on_less_collective_once_it_is_flying",
		flying < standing - 0.02 and absf(mutant_flying - mutant_standing) <= 0.005,
		"the little bird needs %.3f of the lever standing still and %.3f at %.0f m/s; with translational lift taken away, %.3f and %.3f"
			% [standing, flying, TRANSLATIONAL, mutant_standing, mutant_flying])


## THE COLLECTIVE THAT CARRIES THE WEIGHT, in the model this kind actually flies, at the speed and height it is flying
## at. A weight-fraction thruster's is arithmetic: `(1 - hover) / collective_range`. A rotor disc's is asked of the disc
## (`probe_rotor`), by bisection, because its thrust at a collective depends on the air going through it -- ground
## effect below about a rotor diameter, and translational lift once it is moving.
##
## ASKED OF THE MODEL, NOT OF A FORMULA BESIDE IT. That is what went wrong here: the Little Bird moved onto the disc and
## this check went on using the thruster's arithmetic, so it wanted 0.47 from a helicopter that holds its height on 0.32.
func _lever_that_carries(world: Object, kind: int, handling: Dictionary, along: float, height: float) -> float:
	var thruster: float = (1.0 - float(handling.get("hover", 0.5))) / maxf(float(handling.get("collective_range", 1.0)), 0.01)
	var disc: Dictionary = world.rotor_disc(kind) if world.has_method("rotor_disc") else {}
	if disc.is_empty() or not bool(disc.get("switched_on", false)) or not world.has_method("probe_rotor"):
		return thruster
	var weight: float = float(disc.get("mass", 0.0)) * 9.81
	var agl: float = maxf(height - float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y), 0.0)
	var low: float = 0.0
	var high: float = 1.0
	for i in range(40):
		var middle: float = 0.5 * (low + high)
		var thrust: float = float(world.probe_rotor(kind, middle, along, 0.0, agl).get("thrust", 0.0))
		if thrust > weight:
			high = middle
		else:
			low = middle
	return 0.5 * (low + high)


func _world(id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(60.0)
	world.start(id)
	return world


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _pair(server: Object, client: Object) -> void:
	server.tick(DT)
	client.tick(DT)
	for packet in server.take_outbound():
		client.deliver(0, packet["bytes"], packet["bits"])
	for packet in client.take_outbound():
		server.deliver(1, packet["bytes"], packet["bits"])


## One craft, spawned as the bench spawns it, flown 24 s: (end height, lowest height).
func _fly(kind: int, hold: bool) -> Vector2:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(60.0)
	world.start(0)
	var craft: int = int(world.spawn_ai_vehicle(kind, Vector3(0.0, CockpitBench.FLY_HEIGHT, 0.0), 0.0,
		Vector3(0.0, 0.0, -Terrain.cruise_for(kind))))
	if hold:
		world.set_ai_altitude(craft, CockpitBench.FLY_HEIGHT)
	var lowest: float = INF
	var y: float = 0.0
	for i in range(int(SECONDS / DT)):
		world.tick(DT)
		y = (world.vehicle_state(craft).get("position", Vector3.ZERO) as Vector3).y
		lowest = minf(lowest, y)
	world.teardown()
	if not (world is RefCounted):
		world.free()
	return Vector2(y, lowest)


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
