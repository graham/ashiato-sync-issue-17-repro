extends Node
## HOW FAR OUT THE SIMULATION AND THE WIRE STAY RIGHT, measured through the real CockpitWorld: a craft sent to a client,
## an aeroplane parked, one taxiing, one flying and one chocked on a carrier under way, each put down at 0, 8, 16, 24,
## 32 and 64 km along one axis.
##
##   Godot --headless --path cockpit res://tests/far_out.tscn
##
## WHY. The map is becoming 64 km across -- 32 km to an edge, 45 km to a corner -- and the headset plays the double build.
## That build makes Godot's side of the line exact (`tests/jitter.gd`), and its GPU path steadies ordinary meshes
## (`tests/shake_shot.gd`). Everything BELOW the line is float32 or quantised whatever the engine's precision: Box3D's
## body positions, `VehicleState`, the display pose, and the wire's `ground` and `height` ranges
## (`ashiato-gd/src/cockpit/cockpit_components.hpp`, `ground` and `height`). Nothing had measured that half past the
## 16 km the island reaches.
##
## DISTANCES ARE PER AXIS, which is the worst case for a radial distance: a float's step is set by its largest coordinate,
## and a corner of a 64 km map is 32 km on both axes.
##
## HOW NOISE IS READ. A smooth path has a third difference near zero; a position rounded onto a grid of step q every tick
## adds a third difference of about 1.29 q RMS (uniform rounding, sqrt(20) / sqrt(12)). `_noise_mm` divides that back out,
## so it prints the position noise itself. The bound it is held to is what an eye can tell of ground 2.5 m away, half an
## arcminute: 0.36 mm. A bound relative to the origin, for creep and drift, is the origin's own reading plus a margin.
##
## A SUITE SINCE THE WIRE WAS WIDENED (2026-09-14). As a probe it was red past the wire's 16 km and 2,000 m: a remote craft
## 24 km out drawn 7.4 km from the server's path, one at 2,500 m 573 m off, a client's own aeroplane 24 km out rolled back
## on 360 ticks of 360. The wire now holds +-32,768 m and -200 to 41,700 m (`cockpit_components.hpp`, `ground` and
## `height`, read from `ground_core.hpp`), and every check inside the world has to pass. 64 km is past the edge on purpose: there the wire must clamp the
## craft AND count the clamp for `CockpitWorld`'s warning, and the client's own flight is not flown, since a predicted craft
## past the edge is resimulated from its clamp every tick by design.
##
## Differences are taken as scalars, never as `Vector3` sums: on the stock editor a `Vector3` is float32, and `3 * p` 32 km
## out would round in this file rather than in the thing measured.
##
## Read RESULT=, not the exit code.

const TICK_HZ: float = 60.0
const DT: float = 1.0 / TICK_HZ
## Kinds, matching kKind* in cockpit_world.cpp.
const PLANE: int = 1
const CARRIER: int = 12
## 30 km by name: a client's own aeroplane there is corrected, and the correction compares positions after the wire
## (`should_roll_back`), so it is where a range too narrow for the world would show first.
const DISTANCES: Array[float] = [0.0, 8000.0, 16000.0, 24000.0, 30000.0, 32000.0, 64000.0]
## Heights for the wire's `height` range: the island's highest flying, the new alps' peaks, and above them.
const HEIGHTS: Array[float] = [1500.0, 2500.0, 3200.0, 4500.0, 20000.0]
## The wire's edge on either horizontal axis, its floor and its ceiling, metres, asked of `CockpitWorld.wire_range()` in
## `_ready` and never typed here: they are read from the ground's own bounds (`ground_core.hpp`). A distance past the edge
## is flown to see the clamp, not the craft.
var WORLD_EDGE: float = 0.0
var FLOOR: float = 0.0
var CEILING: float = 0.0
## Below this a position is on the wire to the centimetre: half its 1 cm step, and float32's step at 41,700 m besides.
const WIRE_WITHIN_M: float = 0.006
## Half an arcminute at 2.5 m, in millimetres: ground under a taxiing wheel, a deck under a parked one.
const EYE_CAN_TELL_MM: float = 0.36
## A client's drawn craft this close to the server's path is the same craft: the wire's 1 cm grid, twice.
const SAME_PLACE_M: float = 0.02
## Client ids nobody claims, for the helms and taxiing pilots this file drives itself.
var _next_spare: int = 200
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[far_out] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	print("[far_out] engine real_t is %s" % ["double" if _real_is_double() else "float"])
	var ranges: Object = _world(0)
	var wire: Dictionary = ranges.wire_range() if ranges.has_method("wire_range") else {}
	_let_go(ranges)
	_check("the_wire_says_its_ranges", wire.has("ground_max") and wire.has("height_min") and wire.has("height_max"),
		"%s" % [wire])
	if not wire.has("ground_max"):
		_finish()
		return
	WORLD_EDGE = float(wire["ground_max"])
	FLOOR = float(wire["height_min"])
	CEILING = float(wire["height_max"])
	_the_wire_floor_is_under_the_deepest_ground()
	_the_wire_holds_its_extremes_and_counts_a_clamp()
	_the_wire_carries_a_craft_where_it_is()
	_a_client_flying_its_own_craft_far_out_is_not_rolled_back()
	_a_parked_aeroplane_stays_still()
	_the_ground_under_a_taxiing_aeroplane_is_steady()
	_a_flying_aeroplane_draws_a_smooth_path()
	_an_aeroplane_chocked_on_a_carrier_under_way_stays_put()
	_finish()


func _finish() -> void:
	print("RESULT=%s %d failed%s" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size(),
		"" if _failures.is_empty() else ": " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)


## ---- 1. the wire ----------------------------------------------------------------------------------------------------

## THE WIRE'S FLOOR IS UNDER THE DEEPEST GROUND, with room for a hull resting on it. The game's own world is asked at its
## corner, which is open sea at its deepest, and a craft on that floor must come back from the wire exact. Before, the
## floor was a typed -100 m over a sea floor at -150 m: a round into the open sea, or a craft sunk to the bed, clamped.
func _the_wire_floor_is_under_the_deepest_ground() -> void:
	if not ClassDB.class_exists("GroundField"):
		_check("the_extension_has_a_ground_field", false, "no GroundField")
		return
	var ground: Object = ClassDB.instantiate("GroundField")
	var problems: PackedStringArray = ground.call("configure", GroundTuning.values())
	var half: int = int(GroundTuning.values()["world_half"])
	var deepest: float = float(int(ground.call("height_ticks_at", half, half))) / 32.0
	var world: Object = _world(0)
	var before: int = int(world.wire_clamps())
	var on_the_bed := Vector3(float(half), deepest, float(half))
	var back: Vector3 = world.wire_round_trip(on_the_bed)
	var clamps: int = int(world.wire_clamps()) - before
	_let_go(world)
	_check("the_wires_floor_is_under_the_open_seas_floor_and_a_craft_on_it_comes_back_exact",
		problems.is_empty() and half <= int(WORLD_EDGE) and deepest > FLOOR and clamps == 0
			and absf(float(back.y) - deepest) <= WIRE_WITHIN_M,
		"sea floor %.2f m at the corner of a %d m half-width, wire floor %.0f m, came back at %.3f m, %d clamps" % [
			deepest, half, FLOOR, float(back.y), clamps])

## A SERVER AND A CLIENT, ONE CRAFT, AND WHERE THE CLIENT DRAWS IT. The client's drawn position is held against the
## server's path over the last second and a half, as the nearest point on any segment of it, so the interpolation buffer's
## delay and a fraction of a tick both read as zero. A clamped range reads as the distance to the clamp.
func _the_wire_carries_a_craft_where_it_is() -> void:
	for d in DISTANCES:
		var flown: Array = _worst_miss_on_a_client(Vector3(d, 1500.0, 0.0))
		if d <= WORLD_EDGE:
			_check("the_wire_carries_a_craft_%d_km_out" % int(d / 1000.0),
				float(flown[0]) <= SAME_PLACE_M and int(flown[1]) == 0,
				"drawn %.3f m from the server's path at x = %.0f m, %d clamps" % [flown[0], d, flown[1]])
		else:
			_check("a_craft_%d_km_out_is_past_the_edge_so_the_wire_clamps_it_and_counts_the_clamp" % int(d / 1000.0),
				float(flown[0]) > 100.0 and int(flown[1]) > 0,
				"drawn %.1f m from the server's path at x = %.0f m, %d clamps" % [flown[0], d, flown[1]])
	for h in HEIGHTS:
		var flown: Array = _worst_miss_on_a_client(Vector3(0.0, h, 0.0))
		_check("the_wire_carries_a_craft_%d_m_up" % int(h), float(flown[0]) <= SAME_PLACE_M and int(flown[1]) == 0,
			"drawn %.3f m from the server's path at y = %.0f m, %d clamps" % [flown[0], h, flown[1]])


## THE WIRE'S OWN EDGES, through `wire_round_trip`, which quantises a position exactly as every position on the wire is
## quantised. The world's four corners at the lowest height and the ceiling come back to the centimetre and count no clamp;
## a position past all three edges comes back at the edge, and counts one clamp a coordinate. The flights above measure
## what a client draws; this holds the ranges themselves, which agents.md states.
func _the_wire_holds_its_extremes_and_counts_a_clamp() -> void:
	var world: Object = _world(0)
	if not world.has_method("wire_round_trip"):
		_check("the_wire_can_be_asked_about_its_extremes", false, "CockpitWorld has no wire_round_trip")
		_let_go(world)
		return
	var corners: Array[Vector3] = [Vector3(-WORLD_EDGE, FLOOR, -WORLD_EDGE), Vector3(WORLD_EDGE, CEILING, WORLD_EDGE),
		Vector3(-WORLD_EDGE, CEILING, WORLD_EDGE), Vector3(WORLD_EDGE, FLOOR, -WORLD_EDGE)]
	var before: int = int(world.wire_clamps())
	var worst: float = 0.0
	for at in corners:
		var back: Vector3 = world.wire_round_trip(at)
		worst = maxf(worst, maxf(absf(float(back.x) - float(at.x)),
			maxf(absf(float(back.y) - float(at.y)), absf(float(back.z) - float(at.z)))))
	var counted_inside: int = int(world.wire_clamps()) - before
	_check("the_wires_corners_its_floor_and_its_ceiling_come_back_to_the_centimetre_with_no_clamp",
		worst <= WIRE_WITHIN_M and counted_inside == 0,
		"worst %.4f m over %d corners at %.0f m and %.0f m, %d clamps" % [worst, corners.size(), FLOOR, CEILING,
			counted_inside])
	var past := Vector3(WORLD_EDGE + 132.0, CEILING + 150.0, -WORLD_EDGE - 232.0)
	before = int(world.wire_clamps())
	var held: Vector3 = world.wire_round_trip(past)
	var counted: int = int(world.wire_clamps()) - before
	var at_the_edge: bool = absf(float(held.x) - WORLD_EDGE) <= WIRE_WITHIN_M \
		and absf(float(held.y) - CEILING) <= WIRE_WITHIN_M and absf(float(held.z) + WORLD_EDGE) <= WIRE_WITHIN_M
	_check("a_position_past_every_edge_comes_back_at_the_edge_and_counts_a_clamp_a_coordinate",
		at_the_edge and counted == 3, "%s came back as %s, %d clamps" % [past, held, counted])
	_let_go(world)


## Where a client draws a craft flown level at `at`, against the server's path: [the worst miss in metres, the clamps the
## wire counted while it flew]. The clamp count is the whole process's, so only this flight's two worlds add to it.
func _worst_miss_on_a_client(at: Vector3) -> Array:
	var server: Object = _world(0)
	var client: Object = _world(1)
	for i in range(90):
		_step_pair(server, client)
	# PAST THE EDGE ON PURPOSE, SAID SO: the server expects the clamps and counts them in silence, where anywhere else a
	# clamp is an error the suites' gate fails on.
	if server.has_method("expect_wire_clamps"):
		server.expect_wire_clamps(absf(at.x) > WORLD_EDGE or absf(at.z) > WORLD_EDGE or at.y > CEILING or at.y < FLOOR)
	var clamps_before: int = int(server.wire_clamps()) if server.has_method("wire_clamps") else 0
	# Level along -X at 166 m/s, the fastest anything here flies, so the far coordinate is the one that moves.
	var craft: int = int(server.spawn_vehicle(PLANE, at, PI * 0.5, Vector3(-166.0, 0.0, 0.0)))
	for i in range(120):
		_step_pair(server, client)
	# THE WHOLE PATH FIRST, THEN THE COMPARISON. A client draws a remote craft behind the server's clock by its buffer or
	# ahead of it by its lead, and the first version, which held each drawn point against the server's past alone, read
	# 4.8 m at the origin: the client was drawing a tick and a half AHEAD. So both are recorded over six seconds and each
	# drawn point of the middle two is held against the server's whole path, earlier and later.
	var path: Array[Vector3] = []
	var drawn_path: Array[Vector3] = []
	for i in range(360):
		_step_pair(server, client)
		path.append(server.vehicle_state(craft).get("position", Vector3.ZERO))
		var drawn: Array = client.vehicle_states()
		drawn_path.append(drawn[0]["position"] if drawn.size() == 1 else Vector3.INF)
	var clamps: int = (int(server.wire_clamps()) if server.has_method("wire_clamps") else 0) - clamps_before
	_let_go(server)
	_let_go(client)
	var worst: float = 0.0
	for i in range(120, 240):
		if drawn_path[i] == Vector3.INF:
			return [INF, clamps]
		worst = maxf(worst, _distance_to_path(drawn_path[i], path))
	return [worst, clamps]


## A CLIENT FLYING ITS OWN AEROPLANE, predicted, at each distance: how many times it was rolled back over six seconds of
## level flight, and where it drew itself against the server's path. `should_roll_back` compares the predicted and the
## authoritative state after both went through the wire (`cockpit_components.hpp`, VehicleState, 0.04 m), so a clamped
## range agrees with itself -- what a clamp does to a predicted craft is the resimulation starting from the clamp.
func _a_client_flying_its_own_craft_far_out_is_not_rolled_back() -> void:
	var at_origin: int = -1
	for d in DISTANCES:
		# PAST THE EDGE a predicted craft is clamped on the wire and resimulated from the clamp every tick, by design; the
		# clamp itself is held in the wire's own section.
		if d > WORLD_EDGE:
			continue
		var server: Object = _world(0)
		var client: Object = _world(1)
		for i in range(90):
			_step_pair(server, client)
		var mine: int = int(client.local_client_id())
		var flying: Dictionary = _controls({"throttle": 0.8})
		server.spawn_pilot(mine, PLANE, Vector3(d, 1500.0, 0.0), PI * 0.5, Vector3(-166.0, 0.0, 0.0))
		for i in range(120):
			client.set_input(flying)
			_step_pair(server, client)
		var before: int = int(client.resim_stats().get("count", 0))
		var path: Array[Vector3] = []
		var drawn_path: Array[Vector3] = []
		var server_craft: int = -1
		for i in range(360):
			client.set_input(flying)
			_step_pair(server, client)
			if server_craft < 0:
				var all: Array = server.vehicle_states()
				server_craft = int(all[0]["entity"]) if all.size() == 1 else -1
			path.append(server.vehicle_state(server_craft).get("position", Vector3.ZERO))
			var drawn: Array = client.vehicle_states()
			drawn_path.append(drawn[0]["position"] if drawn.size() == 1 else Vector3.INF)
		var rolled: int = int(client.resim_stats().get("count", 0)) - before
		_let_go(server)
		_let_go(client)
		var worst: float = 0.0
		for i in range(120, 240):
			worst = INF if drawn_path[i] == Vector3.INF else maxf(worst, _distance_to_path(drawn_path[i], path))
		if at_origin < 0:
			at_origin = rolled
		print("[far_out] own craft %5.0f km: %d rollbacks in 6 s, drawn %.3f m from the server's path" % [d / 1000.0,
			rolled, worst])
		_check("a_client_flying_its_own_craft_%d_km_out_is_rolled_back_no_more_than_at_the_origin" % int(d / 1000.0),
			rolled <= at_origin + 2, "%d against %d" % [rolled, at_origin])
		_check("and_draws_it_where_the_server_has_it_%d_km_out" % int(d / 1000.0), worst <= 0.05,
			"%.3f m" % worst)


func _step_pair(server: Object, client: Object) -> void:
	server.tick(DT)
	client.tick(DT)
	for packet in server.take_outbound():
		client.deliver(0, packet["bytes"], packet["bits"])
	for packet in client.take_outbound():
		server.deliver(1, packet["bytes"], packet["bits"])


## ---- 2. parked ------------------------------------------------------------------------------------------------------

## AN AEROPLANE WITH NOBODY IN IT, CHOCKED ON A SLAB, for twenty seconds after it has settled: how far it went and how
## much it shook. Box3D's contact solver works from float32 body positions in float mode, where the step 32 km out is
## 1.95 mm and 64 km out 3.9 mm, against a linear slop of 5 mm (`box3d/include/box3d/constants.h`, B3_LINEAR_SLOP).
func _a_parked_aeroplane_stays_still() -> void:
	var world: Object = _world(0)
	var half: float = _half_height(world, PLANE)
	var crafts: Dictionary = {}
	for d in DISTANCES:
		world.add_static_box(Vector3(d, -2.0, 0.0), Vector3(400.0, 2.0, 400.0))
		crafts[d] = int(world.spawn_vehicle(PLANE, Vector3(d, half + 0.05, 0.0), 0.0, Vector3.ZERO))
	var tracks: Dictionary = _fly(world, crafts, 180, 1200, {})
	var at_origin: Array = _creep_and_noise(tracks[0.0])
	for d in DISTANCES:
		var here: Array = _creep_and_noise(tracks[d])
		print("[far_out] parked %5.0f km: creep %.2f mm in 20 s, noise %.3f mm" % [d / 1000.0, here[0], here[1]])
		_check("a_parked_aeroplane_%d_km_out_creeps_no_more_than_at_the_origin" % int(d / 1000.0),
			here[0] <= at_origin[0] + 1.0, "%.2f mm against %.2f mm" % [here[0], at_origin[0]])
		_check("and_shakes_less_than_an_eye_can_tell_%d_km_out" % int(d / 1000.0),
			here[1] <= EYE_CAN_TELL_MM, "%.3f mm noise" % here[1])
	_let_go(world)


## ---- 3. taxiing -----------------------------------------------------------------------------------------------------

## FIVE PER CENT THROTTLE ALONG A SLAB, which rolled 399 m in the twenty seconds measured. The noise here is the aeroplane against the ground, and the
## pilot is 2.5 m above that ground: this is the case where a float grid under the simulation becomes a shimmer.
func _the_ground_under_a_taxiing_aeroplane_is_steady() -> void:
	var world: Object = _world(0)
	var half: float = _half_height(world, PLANE)
	var crafts: Dictionary = {}
	var inputs: Dictionary = {}
	for d in DISTANCES:
		world.add_static_box(Vector3(d, -2.0, 0.0), Vector3(400.0, 2.0, 400.0))
		var spawned: Dictionary = world.spawn_pilot(_spare(), PLANE, Vector3(d + 300.0, half + 0.05, 0.0), PI * 0.5,
			Vector3.ZERO)
		crafts[d] = int(spawned.get("vehicle", 0))
		inputs[int(spawned.get("pilot", 0))] = _controls({"throttle": 0.05})
	var tracks: Dictionary = _fly(world, crafts, 120, 1200, inputs)
	for d in DISTANCES:
		var here: Array = _creep_and_noise(tracks[d])
		print("[far_out] taxiing %5.0f km: %.1f m rolled, noise %.3f mm" % [d / 1000.0, here[0] / 1000.0, here[1]])
		_check("the_ground_under_a_taxiing_aeroplane_%d_km_out_is_steady_to_the_eye" % int(d / 1000.0),
			here[1] <= EYE_CAN_TELL_MM, "%.3f mm noise at %.1f m rolled" % [here[1], here[0] / 1000.0])
	_let_go(world)


## ---- 4. flying ------------------------------------------------------------------------------------------------------

## LEVEL AT 166 m/s, nobody aboard, for four seconds. Held to half an arcminute at 10 m -- a wingman in close formation,
## or a tanker's drogue -- because nothing is nearer an aeroplane in the air than that.
func _a_flying_aeroplane_draws_a_smooth_path() -> void:
	var world: Object = _world(0)
	var crafts: Dictionary = {}
	for d in DISTANCES:
		crafts[d] = int(world.spawn_vehicle(PLANE, Vector3(d, 1500.0, 0.0), PI * 0.5, Vector3(-166.0, 0.0, 0.0)))
	var tracks: Dictionary = _fly(world, crafts, 30, 240, {})
	for d in DISTANCES:
		var here: Array = _creep_and_noise(tracks[d])
		print("[far_out] flying %5.0f km: %.0f m flown, noise %.3f mm" % [d / 1000.0, here[0] / 1000.0, here[1]])
		_check("a_flying_aeroplane_%d_km_out_draws_a_path_as_smooth_as_a_wingman_can_tell" % int(d / 1000.0),
			here[1] <= EYE_CAN_TELL_MM * 4.0, "%.3f mm noise" % here[1])
	_let_go(world)


## ---- 5. on a carrier ------------------------------------------------------------------------------------------------

## A CARRIER MAKING WAY, AN AEROPLANE CHOCKED ON ITS DECK, read in the ship's own frame for twenty seconds: the deck
## support in `roll_on_wheels` and the deck lookup in `deck_under` both work from float32 world positions differenced
## against the ship's (`ashiato-gd/src/cockpit/cockpit_world.cpp`), so this is the case a craft-local frame would change.
## EVERY CARRIER SAILS THE ORIGIN'S SEA. A carrier under way meets the simulation's swell, and an aeroplane chocked on its
## deck slides with the sea it meets, so carriers on different stretches of swell drift by as much as their seas differ:
## 384 mm at the origin, 284 at 24 km and 452 at 30 km (2026-09-15), which is two seas compared and not a float's step.
## The swell is a whole number of waves across its tile (`swell_shape`), so a carrier a whole number of tiles out sails
## exactly the origin's sea, and the margin compares precision alone. Each is put down at its distance rounded down to a
## whole tile, the tile asked of the world.
## The origin's carrier still reads about 12 mm more (384.5 mm at x 0, 378.3 at 2,048, 372.3 at 30,720, the same in
## either spawn order): Box3D's float32 positions round finer near the origin, 12 mm of the 50 mm margin.
func _an_aeroplane_chocked_on_a_carrier_under_way_stays_put() -> void:
	var world: Object = _world(0)
	var tile: float = float(world.swell_shape()["tile"])
	var inputs: Dictionary = {}
	var ships: Dictionary = {}
	for d in DISTANCES:
		var out: float = floorf(d / tile) * tile
		var helm: Dictionary = world.spawn_pilot(_spare(), CARRIER, Vector3(out, 0.0, 0.0), 0.0, Vector3(0.0, 0.0, -12.0))
		ships[d] = int(helm.get("vehicle", 0))
		inputs[int(helm.get("pilot", 0))] = _controls({"throttle": 1.0})
	for i in range(240):
		_tick_with(world, inputs)
	var parked: Dictionary = {}
	var carrier_half: float = _half_height(world, CARRIER)
	var plane_half: float = _half_height(world, PLANE)
	for d in DISTANCES:
		var ship: Dictionary = world.vehicle_state(ships[d])
		var deck: Vector3 = ship.get("position", Vector3.ZERO)
		parked[d] = int(world.spawn_vehicle(PLANE,
			Vector3(deck.x - 12.0, deck.y + carrier_half + plane_half + 0.3, deck.z - 40.0), 0.0,
			ship.get("velocity", Vector3.ZERO)))
	for i in range(60):
		_tick_with(world, inputs)
	var tracks: Dictionary = {}
	for d in DISTANCES:
		tracks[d] = []
	for i in range(1200):
		_tick_with(world, inputs)
		for d in DISTANCES:
			(tracks[d] as Array).append(_on_the_ship(world, parked[d], ships[d]))
	var at_origin: Array = _creep_and_noise(tracks[0.0])
	for d in DISTANCES:
		var here: Array = _creep_and_noise(tracks[d])
		var speed: float = (world.vehicle_state(ships[d]).get("velocity", Vector3.ZERO) as Vector3).length()
		print("[far_out] on deck %5.0f km (put down at x %.0f m): drift %.1f mm in 20 s at %.1f m/s, noise %.3f mm" % [
			d / 1000.0, floorf(d / tile) * tile, here[0], speed, here[1]])
		_check("an_aeroplane_chocked_on_a_carrier_%d_km_out_drifts_no_more_than_at_the_origin" % int(d / 1000.0),
			here[0] <= at_origin[0] + 50.0, "%.1f mm against %.1f mm" % [here[0], at_origin[0]])
		_check("and_the_deck_under_it_is_steady_to_the_eye_%d_km_out" % int(d / 1000.0),
			here[1] <= EYE_CAN_TELL_MM, "%.3f mm noise" % here[1])
	_let_go(world)


## Where a vehicle is in the ship's own frame, differenced as scalars (see the header).
func _on_the_ship(world: Object, vehicle: int, ship: int) -> Array:
	var craft: Vector3 = world.vehicle_state(vehicle).get("position", Vector3.ZERO)
	var hull: Dictionary = world.vehicle_state(ship)
	var middle: Vector3 = hull.get("position", Vector3.ZERO)
	var dx: float = float(craft.x) - float(middle.x)
	var dy: float = float(craft.y) - float(middle.y)
	var dz: float = float(craft.z) - float(middle.z)
	var local: Vector3 = (hull.get("basis", Quaternion.IDENTITY) as Quaternion).inverse() * Vector3(dx, dy, dz)
	return [float(local.x), float(local.y), float(local.z)]


## ---- helpers --------------------------------------------------------------------------------------------------------

func _world(client_id: int) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(TICK_HZ)
	world.start(client_id)
	return world


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _spare() -> int:
	_next_spare += 1
	return _next_spare


func _half_height(world: Object, kind: int) -> float:
	return (world.kind_geometry(kind).get("extents", Vector3.ONE) as Vector3).y


func _tick_with(world: Object, inputs: Dictionary) -> void:
	for pilot in inputs:
		world.set_pilot_input(pilot, inputs[pilot])
	world.tick(DT)


## Settle, then record every craft's raw position as three scalars a tick.
func _fly(world: Object, crafts: Dictionary, settle: int, ticks: int, inputs: Dictionary) -> Dictionary:
	for i in range(settle):
		_tick_with(world, inputs)
	var tracks: Dictionary = {}
	for key in crafts:
		tracks[key] = []
	for i in range(ticks):
		_tick_with(world, inputs)
		for key in crafts:
			var p: Vector3 = world.vehicle_state(crafts[key]).get("position", Vector3.ZERO)
			(tracks[key] as Array).append([float(p.x), float(p.y), float(p.z)])
	return tracks


## [how far it went end to end, in mm; the position noise, in mm]. See the header for the noise.
func _creep_and_noise(track: Array) -> Array:
	if track.size() < 4:
		return [INF, INF]
	var first: Array = track[0]
	var last: Array = track[track.size() - 1]
	var gone: float = 0.0
	for axis in range(3):
		var moved: float = float(last[axis]) - float(first[axis])
		gone += moved * moved
	var sum: float = 0.0
	var count: int = 0
	for i in range(track.size() - 3):
		for axis in range(3):
			var a: float = float(track[i + 1][axis]) - float(track[i][axis])
			var b: float = float(track[i + 2][axis]) - float(track[i + 1][axis])
			var c: float = float(track[i + 3][axis]) - float(track[i + 2][axis])
			var third: float = c - 2.0 * b + a
			sum += third * third
			count += 1
	var third_rms: float = sqrt(sum / float(count))
	return [sqrt(gone) * 1000.0, third_rms / sqrt(20.0) * 1000.0]


func _distance_to_path(point: Vector3, path: Array[Vector3]) -> float:
	var best: float = INF
	for i in range(path.size() - 1):
		var from: Vector3 = path[i]
		var along: Vector3 = path[i + 1] - from
		var length_squared: float = along.length_squared()
		var t: float = 0.0 if length_squared <= 0.0 else clampf((point - from).dot(along) / length_squared, 0.0, 1.0)
		best = minf(best, point.distance_to(from + along * t))
	if path.size() == 1:
		best = point.distance_to(path[0])
	return best


## Whether this editor's real_t is a double: 2^24 + 1 survives in a Vector3 only if it is.
func _real_is_double() -> bool:
	return Vector3(16777217.0, 0.0, 0.0).x == 16777217.0


## A complete control frame, as the loopback builds it: a merged input keeps any key it is not given.
func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input
