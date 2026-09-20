extends RefCounted
class_name Terrain
## THE WORLD, AS ONE LIST OF BOXES, GENERATED THE SAME WAY ON EVERY MACHINE.
##
## Static collision is not replicated. Every peer builds it from this file, and the
## simulation never mentions it again -- so a peer whose mountain is somewhere else does not
## get a visual glitch, it predicts its own aeroplane straight through a hillside that the
## server says is solid, and rolls back into it for ever.
##
## Three consequences, and they are the whole design of this file:
##
## 1. **One list feeds both the physics and the picture.** `FlightLevel` walks it once for
##    `Sim.add_static_box` and once for the meshes. A mountain drawn where the simulation
##    does not have one is the worst kind of bug, because it looks exactly like a
##    networking fault.
## 2. **The randomness cannot be the engine's.** `RandomNumberGenerator` is deterministic
##    for a given seed today; it is not a documented wire format, and a Godot upgrade that
##    changed it would desync every client that had not upgraded. The hash below is nine
##    lines and cannot change underneath us.
## 3. **The generator keeps its own clearances.** Where things are SPAWNED and where the
##    gates are lives in this file too, and nothing is generated into them. Hand-placing
##    scenery around hand-placed spawns works exactly until either moves; the first version
##    of this put a pod inside a mountain and blocked one of its own gates, and the smoke
##    test found both.

## The island: 14.4 km across, and everything solid lives inside it. The wire can describe
## a 32 km box (see the `ground` quantiser), so there is a long way to fly out over the sea
## before a vehicle would be clamped at the boundary.
##
## Four times across what it was, which is sixteen times the ground. At 300 kph the coast
## is a full three minutes away rather than forty-three seconds.
const WORLD_HALF: float = 7200.0
const SEA_LEVEL: float = 0.0
## The island's collision slab, as a half-extent. Its top is at y = 0.
const GROUND_HALF := Vector3(WORLD_HALF, 40.0, WORLD_HALF)


## THE GENERATED GROUND THE LEVEL STANDS ON, or null on the island: a `GroundField`, handed here once by the level before
## anything asks. A static, so a worker thread can ask without a node: `GroundField` may be read from any thread once
## configured, and never changes afterwards (ashiato-gd/src/cockpit/ground_field.hpp). cockpit-mist bakes its chart off
## the main thread through `surface_height` and relies on that (2026-09-15).
static var _field: Object = null
## `GroundField.NO_WATER`, asked of the class once rather than typed: at or below it a water query found none.
static var _no_water: int = 0

## How far past the island's edge open water begins for anything sent to sea: a boat's waypoint, a ship's spawn.
const OFFSHORE: float = 220.0
## Ticks of height in a metre, `GroundField`'s unit.
const GROUND_TICKS_PER_METRE: float = 32.0
## A catalogued site's "level" in a metre: `GroundField.catalogue()` gives every lake's, town site's and airfield's
## level in 1/1024 m (ground_field.hpp), finer than a height tick. `TownCatalogue.seat` reads a town site's with it.
const SITE_LEVEL_PER_METRE: float = 1024.0
## The rings `open_sea_near` searches outward in, and the grid it settles on round the first one found, metres.
const SEA_SEARCH_RING: float = 256.0
const SEA_SEARCH_STEP: float = 16.0

## THE ROOM A KIND'S WAYPOINT KEEPS FROM ANYTHING SOLID, metres: one number a kind for the island's boxes and the generated
## ground alike. An aeroplane arrives faster than anything else and needs room to be wrong in; a car's is the least, and the
## ground under a car is its road, so the generated ground's `overhead` for it is 0.
const WING_ROOM: float = 60.0
const HELI_ROOM: float = 30.0
const CAR_ROOM: float = 14.0
## HOW HIGH A WAYPOINT STANDS over what is under it, metres: the lowest, and the band above it a hash spreads them over.
const WING_LOW: float = 260.0
const WING_BAND: float = 620.0
const HELI_LOW: float = 35.0
const HELI_BAND: float = 95.0
## How many points a kind's pool tries, and how far out the hash spreads them, as a share of the land's reach.
const WING_POOL: int = 64
const HELI_POOL: int = 56
const CAR_POOL: int = 56
const BOAT_POOL: int = 44
const WING_SPREAD: float = 0.85
const HELI_SPREAD: float = 0.8
const CAR_SPREAD: float = 0.9
## The island's boats spread over this share of its half-width, past its edge.
const BOAT_SPREAD: float = 1.7
## HOW MANY BOAT POINTS ARE TRIED FOR EACH ONE KEPT on the generated ground, where most of the reach is land: tried in one
## batch and kept where the sea is, rather than searched outward one at a time.
const BOAT_TRIES_EACH: int = 8

## HOW FAR PAST THE FARTHEST PLACED THING the land's reach runs, metres, and how much sea past the coast ships are given.
const PLACED_MARGIN: float = 2000.0
const SEA_ROOM: float = 4000.0
## THE WATER A SHIP KEEPS UNDER ITS KEEL, metres, and how much deep water a ship under way needs ahead of it, sampled
## every SHIP_TRACK_STEP: cockpit-carrier's carrier makes 12 m/s and asked for 2 km (2026-09-15). A heading that does not
## have it is turned SHIP_TURN_STEP at a time until one does.
const SHIP_KEEL_ROOM: float = 8.0
const SHIP_TRACK: float = 2000.0
const SHIP_TRACK_STEP: float = 128.0
const SHIP_TURN_STEP: float = PI / 6.0
## THE BRIGS' SEA: a ring round the island from PIRATE_SEA_INNER metres past its edge out to `placed_reach()` -- well clear
## of the coast and of the BOAT pool's inshore water, so a brig beating about has room to tack and the look ahead for
## shoals has two minutes of warning. INSIDE THE PLACED REACH ON BOTH WORLDS (team-lead, 2026-09-15), so the level's
## boundary band, which starts PLACED_MARGIN past that reach, is where it was: a square ring out to 2.2 times the half
## width reached 22.4 km at its corners, past the island's band at 19,310 m. PIRATE_POOL points are tried and those in
## the ring kept, about half. cockpit-terrain and cockpit-levels were told.
const PIRATE_POOL: int = 48
const PIRATE_SEA_INNER: float = 1500.0
## HOW MANY BRIGS SAIL, and how fast each is put in the water: under way, so its rudder bites from the first tick.
const PIRATE_FLEET: int = 3
const PIRATE_START_SPEED: float = 3.0
## What an aeroplane launched on the generated ground must clear: the highest surface within this of it, metres. A
## kilometre, the ground it flies over in its first seconds at cruise: at 200 m a plane launched towards a rising slope
## flew 441 m and into it, and sat there with no leg (terrain_level, 2026-09-15).
const AIR_SPAWN_ROOM: float = 1000.0
## How far either side the ground's slope is read, metres: the generated function's finest spacing.
const SLOPE_REACH: float = 16.0
## A FIRE BURNS NO STEEPER THAN THIS, degrees: on a 60-degree face its column comes out of the rock.
const FIRE_STEEPEST: float = 35.0
## How far from its island place a fire is searched for somewhere to burn on the generated ground, metres.
const FIRE_SEARCH: float = 1440.0

## The level standing now, for its own airfield files; see `stand_on`.
static var _level: String = ""
## THE LEVEL'S OWN MOUNTAIN RANGES on a generated ground (`LevelChart.mountains`), and the rock made from them, for the
## field it was made on. Built while `_raising` is set, when `mountains()` answers null: the keep-outs it is made from ask
## the ground's height and where things are placed, and those ask the rock.
static var _level_ranges: Array[Dictionary] = []
## The level's own watercourses (`LevelChart.rivers`), for the walls, the keep-outs and the water.
static var _level_rivers: Array[Dictionary] = []
## How fine the level's rock is cut, metres (`LevelChart.rock_spacing`).
static var _level_rock_spacing: int = MountainRanges.SPACING
static var _level_rock: Object = null
static var _level_rock_of: Object = null
static var _raising: bool = false
## THE STAIRCASE UNDER A FINAL, for the rock's keep-outs: a step this long along it, each floored at the 34:1 height
## where it begins (so never above the surface), this much wider than the funnel either side.
const FINAL_STEP: int = 1000
const FINAL_SIDE: int = 300
## The lattice `has_sea` surveys, metres, and the field it last answered for.
const SEA_SURVEY: int = 512
static var _sea_of: Object = null
static var _has_sea: bool = true
## The field `placed_reach` and `land_reach` last worked out for, and the answers: the catalogue does not change.
static var _reach_of: Object = null
static var _land_reach: float = 0.0
static var _placed_reach: float = 0.0


## HOW FAR FROM THE MIDDLE ANYTHING IS PLACED ON LAND, metres: every town, airfield and lake the generated ground catalogues,
## and PLACED_MARGIN past the farthest; on the island, its half-width.
static func land_reach() -> float:
	if _field == null:
		return WORLD_HALF
	_work_out_the_reach()
	return _land_reach


## HOW FAR FROM THE MIDDLE ANYTHING IS PLACED AT ALL, metres, ships included: the land's reach, or SEA_ROOM past the nearest
## open sea deep enough for the deepest keel, whichever is farther; on the island, as far as its boat pool spreads. A level's
## boundary lies past it (cockpit-levels, 2026-09-15).
static func placed_reach() -> float:
	if _field == null:
		return WORLD_HALF * BOAT_SPREAD * sqrt(2.0)
	_work_out_the_reach()
	return _placed_reach


static func _work_out_the_reach() -> void:
	if _reach_of == _field:
		return
	var far: float = 0.0
	var catalogue: Dictionary = _field.call("catalogue")
	for group in ["towns", "airfields", "lakes"]:
		for site in catalogue[group]:
			far = maxf(far, Vector2(float(int(site["x"])), float(int(site["z"]))).length())
	# A LEVEL'S AIRPORTS ARE PLACED THINGS TOO, each by its farthest corner (lane/testfield).
	for pad in catalogue.get("pads", []):
		for x in [int(pad["x0"]), int(pad["x1"])]:
			for z in [int(pad["z0"]), int(pad["z1"])]:
				far = maxf(far, Vector2(float(x), float(z)).length())
	_land_reach = far + PLACED_MARGIN
	var coast: Vector3 = open_sea_near(Vector3.ZERO, ship_depth(Sim.Kind.CARRIER))
	var sea: float = Vector2(coast.x, coast.z).length() + SEA_ROOM if coast != Vector3.INF else 0.0
	_placed_reach = maxf(_land_reach, sea)
	_reach_of = _field


## Whether a kind floats: its spawns go to sea and its pools to open water.
static func is_a_ship(kind: int) -> bool:
	return kind in [Sim.Kind.BOAT, Sim.Kind.GUNBOAT, Sim.Kind.CB90, Sim.Kind.CARRIER, Sim.Kind.BATTLESHIP,
		Sim.Kind.SUBMARINE, Sim.Kind.FIREBOAT]


## THE DEPTH A SHIP'S PLACE MUST HAVE, metres below the sea's level: its draught and SHIP_KEEL_ROOM. THE DRAUGHT IS THE
## SIMULATION'S, `CockpitWorld.ai_leg_rules(kind)["draught"]` -- the draught its own legs are sounded against -- so a ship is
## placed where the ship itself would sail (cockpit-carrier's step 4c, 2026-09-15). Until then this file worked the same
## number out again from the parts; with no simulation, or one without the key, it still does, and warns.
static func ship_depth(kind: int) -> float:
	if Sim.is_available() and Sim.client != null:
		var rules: Dictionary = Sim.client.ai_leg_rules(kind)
		if rules.has("draught"):
			return float(rules["draught"]) + SHIP_KEEL_ROOM
	push_warning("[terrain] no draught from the simulation for kind %d; its place's depth is worked out from its parts" % kind)
	return _draught_from_the_parts(kind) + SHIP_KEEL_ROOM


## A KIND'S DRAUGHT FROM THE PARTS the physics collides with, for `ship_depth` with no simulation to ask: the kind's
## "waterline" -- where the sea stands in its own frame when it floats at rest -- less the lowest "bottom" of its "hull"
## parts, or of its one centred box, -extents.y, for a kind with none. The carrier's origin is on its waterline and its
## hull bottom 11.9 m under it; a box hull floats 0.625 m over its centre.
static func _draught_from_the_parts(kind: int) -> float:
	var geometry: Dictionary = Sim.geometry_of(kind)
	var lowest: float = -float((geometry.get("extents", Vector3.ZERO) as Vector3).y)
	var hulls: int = 0
	for part in geometry.get("parts", []):
		if String((part as Dictionary).get("part", "")) != "hull":
			continue
		var bottom: float = float((part as Dictionary).get("bottom", 0.0))
		lowest = bottom if hulls == 0 else minf(lowest, bottom)
		hulls += 1
	return float(geometry.get("waterline", 0.0)) - lowest


## WHERE THE BRIGS START, as `spawns` gives the rest: PIRATE_FLEET points of their own pool, taken evenly round it so
## they sail apart, each pointed across the ships' wind so it gathers way on a reach. Their pool is open sea inside the
## placed reach, so every spawn is too -- tests/pirate_ai.gd holds both. Empty where the world has no such sea.
static func pirates(grid: BoxGrid) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pool: Array[Vector3] = waypoints(Sim.Kind.PIRATE, grid)
	if pool.is_empty():
		return out
	var across: float = float(weather()["from"]) + PI * 0.5
	for i in range(mini(PIRATE_FLEET, pool.size())):
		var at: Vector3 = pool[int(float(i) * float(pool.size()) / float(PIRATE_FLEET))]
		out.append(_moving(Sim.Kind.PIRATE, Vector3(at.x, SEA_LEVEL, at.z), -across, PIRATE_START_SPEED))
	return out


## THE DEPTH A BRIG'S PLACE MUST HAVE, metres below the sea's level: its draught and SHIP_KEEL_ROOM. Not `ship_depth`, which
## reads a kind's top-level "waterline" and "hull" parts: a brig has neither, and its waterline -- where the sea stands in
## its frame, floating at rest -- is its rig's (`kind_geometry(PIRATE)["rig"]["waterline"]`), over the hull box's bottom at
## -extents.y. cockpit-terrain agreed (2026-09-15). tests/pirate_ai.gd holds it to a brig floated and measured.
static func pirate_depth() -> float:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.PIRATE)
	var rig: Dictionary = geometry.get("rig", {}) as Dictionary
	if rig.is_empty():
		push_error("Terrain.pirate_depth: the pirate kind has no rig in kind_geometry")
	var half: float = float((geometry.get("extents", Vector3.ZERO) as Vector3).y)
	return float(rig.get("waterline", 0.0)) + half + SHIP_KEEL_ROOM


## WHETHER A SHIP UNDER WAY AT `at` ON `yaw` HAS SHIP_TRACK OF OPEN SEA AHEAD at least `depth` deep, sampled every
## SHIP_TRACK_STEP. Always on the island, whose sea has no floor.
static func open_sea_track(at: Vector3, yaw: float, depth: float) -> bool:
	if _field == null:
		return true
	var nose: Vector3 = nose_from_yaw(yaw)
	var points := PackedInt32Array()
	for k in range(int(SHIP_TRACK / SHIP_TRACK_STEP) + 1):
		var ahead: Vector3 = at + nose * float(k) * SHIP_TRACK_STEP
		points.append_array([roundi(ahead.x), roundi(ahead.z)])
	var waters: PackedInt32Array = _field.call("waters_at", points)
	var heights: PackedInt32Array = _field.call("heights_at", points)
	var deepest: int = -ceili(depth * GROUND_TICKS_PER_METRE)
	for k in range(heights.size()):
		if waters[k] != 0 or heights[k] > deepest:
			return false
	return true


## THE HIGHEST SURFACE WITHIN `room` OF A POINT, metres, the ground or its water, sampled every `step`: what anything
## put in the air there must clear. 0 on the island, as its slab and sea are.
##
## `step` DEFAULTS TO `SEA_SEARCH_STEP` SO THAT NO EXISTING CALLER MOVES, and a caller that passes its own says at its
## own call site why its question tolerates a coarser answer. There are thirteen callers and only one passes it.
##
## WHY A COARSER STEP IS SAFE RATHER THAN RECKLESS, and this is the part a reader will not guess: on a generated ground
## this function asks TWO different things, and only one of them is sampled. THE LEVEL'S RANGES ARE A PYRAMID QUERY
## OVER THE WHOLE BOX (`highest_over`), which is EXACT at any step -- a range cannot be missed however coarse the grid
## is. Only the generated ground's own undulation goes through the grid, and on farmland that varies by metres between
## samples where a range varies by hundreds. So the cost of a coarser step is paid in the relief of fields, not in
## mountains, and a caller with hundreds of metres of clearance margin can afford it.
##
## THE COST IS QUADRATIC IN THE STEP, which is why this argument exists at all: the box holds
## `ceil(2 * room / step)` squared texels, so for the 600 m room the airport pilots use, 16 m is 5,625 texels and
## 3.6 ms a call, and 64 m is 352 and 225 microseconds (lane/pilotcost, 2026-09-19).
##
## NOT THE SAME AS `_highest_within`, which takes a step too and is deliberately DIFFERENT: it omits the ranges'
## pyramid, because the thermals that call it are a question about the relief of fields and not about rock. Do not
## merge the two -- one of them must miss mountains and one of them must not.
static func highest_near(at: Vector3, room: float, step: float = SEA_SEARCH_STEP) -> float:
	# ON THE ISLAND, ONE QUESTION OF THE MOUNTAINS' PYRAMID, never below the slab: never under the rock, as the leg tests'
	# answer is. Sampled a texel at a time, the holding stack's question over the whole island was 810,000 calls into the
	# mountains (2026-09-18).
	if _field == null and mountains() != null:
		return maxf(0.0, float(mountains().call("highest_over", at.x - room, at.z - room, at.x + room, at.z + room)))
	# ON A GENERATED GROUND WITH A LEVEL'S RANGES, the rock's own pyramid beside the ground's samples below.
	var rock_high: float = -INF
	if _field != null and mountains() != null:
		rock_high = float(mountains().call("highest_over", at.x - room, at.z - room, at.x + room, at.z + room))
	var texels: int = maxi(1, ceili(2.0 * room / maxf(step, 1.0)))
	var heights: PackedFloat32Array = surface_heights(Vector2(at.x - room, at.z - room), texels, 2.0 * room / float(texels))
	var high: float = rock_high
	for h in heights:
		high = maxf(high, h)
	return high


## HOW STEEP THE GROUND IS AT A POINT, degrees, from `ground_height` SLOPE_REACH either side along x and z.
static func slope_at(at: Vector3) -> float:
	var east: float = ground_height(at + Vector3(SLOPE_REACH, 0.0, 0.0)) - ground_height(at - Vector3(SLOPE_REACH, 0.0, 0.0))
	var south: float = ground_height(at + Vector3(0.0, 0.0, SLOPE_REACH)) - ground_height(at - Vector3(0.0, 0.0, SLOPE_REACH))
	var rise: float = Vector2(east, south).length() / (2.0 * SLOPE_REACH)
	return rad_to_deg(atan(rise))


## WHETHER THE GROUND LETS A LEG THROUGH, asked of the simulation's own ground (`CockpitWorld.ground_leg_is_clear`, the
## pyramid, which may call a clear leg blocked and never a blocked one clear). Always, with no world grounded.
static func _ground_clears(from: Vector3, to: Vector3, clearance: float, overhead: float) -> bool:
	if not Sim.is_available() or Sim.client == null:
		return true
	return bool(Sim.client.ground_leg_is_clear(from, to, clearance, overhead))


## THE POOL'S POINTS WITH SOMEWHERE TO GO: each kept only if a leg to another point clears the ground at the clearance and
## overhead its kind's autopilot tests a leg at, and is no shorter than the shortest leg it takes -- the simulation's own
## rules, ASKED OF IT (`CockpitWorld.ai_leg_rules`, cockpit-levels' binding), so a machine sent there can leave. A
## destination nothing can leave is a machine with no route.
##
## ASKED KIND BY KIND (team-lead, 2026-09-15): every wing but the tiltrotor is an aeroplane, 90 m and 3,000 m; a helicopter
## 40 m and 1,500 m; the tiltrotor keeps an aeroplane's clearance and its own 400 m shortest leg, so OSPREY's pool is the
## aeroplanes' or more. Before, this file MIRRORED the numbers and held every wing to 3,000 m; a helicopter pool kept to
## this file's 30 m room and no shortest leg had left one hovering 137.6 m over a valley with no leg the simulation would
## take (terrain_level, 2026-09-15).
##
## WITH NO SIMULATION EVERY POINT IS KEPT: there are no rules to ask, and `_ground_clears` calls every leg clear then anyway.
## A level always stands on its simulation, so no level's pool is built this way (team-lead, 2026-09-15).
static func _with_a_clear_leg(points: Array[Vector3], kind: int) -> Array[Vector3]:
	if not Sim.is_available() or Sim.client == null:
		return points
	var rules: Dictionary = Sim.client.ai_leg_rules(kind)
	if rules.is_empty():
		push_warning("[terrain] the simulation has no leg rules for kind %d; its pool keeps every point" % kind)
		return points
	var clearance: float = float(rules["clearance"])
	var overhead: float = float(rules["overhead"])
	var shortest: float = float(rules["shortest"])
	var out: Array[Vector3] = []
	for i in range(points.size()):
		for j in range(points.size()):
			var apart: float = Vector2(points[j].x - points[i].x, points[j].z - points[i].z).length()
			if i != j and apart >= shortest and _ground_clears(points[i], points[j], clearance, overhead):
				out.append(points[i])
				break
	return out


## A BRIG'S POOL POINTS WITH SOMEWHERE TO GO: each kept only if a hop to another point has water the whole way, by the
## sailor's own rules ASKED OF THE SIMULATION -- `CockpitWorld.ai_leg_rules`' "hop" and "wet" and `sea_leg_is_deep`, the last
## pass `choose_sea_waypoint` makes -- so no brig spawned on a point, or sent to one, is stranded there. On the alpine level
## 7 of the 35 points had no leg with water the whole way even 400 m long (team-lead, 2026-09-15: "a spawn or a later pool
## change can then never strand a brig"). Warns if fewer than two a brig are left. With no simulation every point is kept,
## as `_with_a_clear_leg` keeps them.
static func _with_a_wet_leg(points: Array[Vector3], kind: int) -> Array[Vector3]:
	if not Sim.is_available() or Sim.client == null:
		return points
	var rules: Dictionary = Sim.client.ai_leg_rules(kind)
	if float(rules.get("hop", 0.0)) <= 0.0:
		push_warning("[terrain] the simulation has no sailing leg rules for kind %d; its pool keeps every point" % kind)
		return points
	var hop: float = float(rules["hop"])
	var wet: float = float(rules["wet"])
	var out: Array[Vector3] = []
	for i in range(points.size()):
		for j in range(points.size()):
			var apart: float = Vector2(points[j].x - points[i].x, points[j].z - points[i].z).length()
			if i != j and apart >= hop and bool(Sim.client.sea_leg_is_deep(points[i], points[j], wet)):
				out.append(points[i])
				break
	# AN EMPTY POOL IS NOT A POOL THAT FAILED THE LEG TEST: with no points there is nothing to complain about "0 of 0", and a
	# world with no sea (the glider level's) honestly has none. A world WITH sea and no brig point at all is a fault, said so.
	if points.is_empty():
		if has_sea():
			push_warning("[terrain] a world with sea has no brig pool points at all: no open sea deep enough for a brig's keel")
		return out
	if out.size() < PIRATE_FLEET * 2:
		push_warning("[terrain] only %d of %d brig pool points have a leg with water the whole way" % [out.size(), points.size()])
	return out


## THE LEVEL HANDS OVER THE GROUND IT STANDS ON: a configured `GroundField`, or null for the island, and which level it is,
## so a level's own airfield files are found (`Airfield.world_here`; lane/testfield, 2026-09-19). "" for none.
static func stand_on(field: Object, level: String = "") -> void:
	_field = field
	_level = level
	# THE LIFT IS WORKED OUT AGAIN FOR EACH LEVEL, not only each field: a level lays its own thermals.
	_lift_of = null
	# THE LEVEL'S OWN RANGES, read here on the main thread: `mountains()` is asked from the mist's worker too.
	var chart: LevelChart = ChartDrawer.chart(level) if field != null and level != "" else null
	_level_ranges = chart.mountains if chart != null else ([] as Array[Dictionary])
	# THE CANYON WALLS ARE RANGES LIKE ANY OTHER, worked out from the level's rivers and the water the ground function
	# already stood in them (`Watercourse.ranges_for`). They are appended rather than kept apart because from here down
	# a wall IS a range: the same rock, the same keep-outs, the same `MountainView`, the same collision.
	_level_rivers = chart.rivers if chart != null else ([] as Array[Dictionary])
	_level_rock_spacing = chart.rock_spacing if chart != null else MountainRanges.SPACING
	if not _level_rivers.is_empty() and field != null:
		_level_ranges = _level_ranges.duplicate()
		_level_ranges.append_array(Watercourse.ranges_for(_level_rivers, field))
	# AND RAISED NOW, on the main thread, before any worker asks. Raised first by the mist's worker, its keep-outs asked
	# `AirbasePlan.bases()` while the main thread was inside it too, and both laid every base into the one list: the test
	# field had each of its three bases twice (tests/testfield.gd, 2026-09-19).
	if not _level_ranges.is_empty():
		_rock_of_the_level()
	if field != null and _no_water == 0:
		_no_water = ClassDB.class_get_integer_constant("GroundField", "NO_WATER")


static func standing_on() -> Object:
	return _field


## THE WATERCOURSES THE LEVEL ON THIS GROUND LAYS, as its file declared them. [] for a level that lays none.
static func level_rivers() -> Array[Dictionary]:
	return _level_rivers


## HOW FINE THE LEVEL'S ROCK IS CUT, metres between the mountain grid's vertices.
static func level_rock_spacing() -> int:
	return _level_rock_spacing


static func level_standing_on() -> String:
	return _level


## WHETHER THE WORLD HAS ANY SEA: the island always, and the generated ground unless every sample of a SEA_SURVEY lattice
## over its square is dry of the sea's water. A level whose ground's coast lies past its corners (`coast`, lane/testfield)
## has none, and then nothing searches for open sea at all: `open_sea_near` scanned rings out to twice the half-width,
## 260 of them, for every ship a level tried to put somewhere. Asked once a field.
static func has_sea() -> bool:
	if _field == null:
		return true
	if _sea_of != _field:
		_has_sea = sea_in(_field)
		_sea_of = _field
	return _has_sea


## WHETHER A CONFIGURED `GroundField` HAS ANY SEA, on the SEA_SURVEY lattice: for `has_sea`, and for a suite asking about a
## level it has not flown (tests/ship_legs.gd counts a dry level and skips it, as it does a room).
static func sea_in(field: Object) -> bool:
	var half: int = int((field.call("tuning") as Dictionary)["world_half"])
	var n: int = 2 * half / SEA_SURVEY + 1
	var grid := PackedInt32Array()
	for j in range(n):
		for i in range(n):
			grid.append_array([-half + i * SEA_SURVEY, -half + j * SEA_SURVEY])
	var waters: PackedInt32Array = field.call("waters_at", grid)
	var heights: PackedInt32Array = field.call("heights_at", grid)
	for k in range(waters.size()):
		if waters[k] == 0 and heights[k] < 0:
			return true
	return false


## WHAT LOW MIST LIES ON UNDER A POINT: the ground or the water standing on it, whichever is higher, in metres of world y
## (the y of `at` is not read). Asked for on 2026-09-14: the mist follows "ground and water height from a query", not the
## flat ground's constants. On the generated ground, `ground_height` against `water_height`, and finite everywhere --
## past the world's edge the function is open sea. On the island, the slab's top over it and the sea past it, both 0.
static func surface_height(at: Vector3) -> float:
	if _field != null:
		return maxf(ground_height(at), water_height(at))
	# The slab's top, y = 0, as GROUND_HALF's note says, and the mountains' rock over it.
	return maxf(ground_height(at), SEA_LEVEL)


## `surface_height` OVER A GRID, for a chart baked all at once (cockpit-mist's, 128 by 128 at 128 m): `texels` by `texels`,
## sample (i, j) at the TEXEL'S CENTRE, x = corner.x + (i + 0.5) * spacing and z = corner.y + (j + 0.5) * spacing, rows along
## z and each row along x, so index j * texels + i. On the generated ground one `heights_at` call and one `waters_at`
## call, not one call a texel; on the island the same answers `surface_height` gives. Static, and safe on a worker.
static func surface_heights(corner: Vector2, texels: int, spacing: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(texels * texels)
	var level_rock: Object = mountains() if _field != null else null
	if _field == null:
		# ON THE ISLAND, THE MOUNTAINS ASKED ONCE for every texel, not once a texel; then the slab, the sea past it, and
		# the rock over the slab, as `surface_height` answers each.
		var rock: Object = mountains()
		var points := PackedVector2Array()
		points.resize(texels * texels)
		for j in range(texels):
			for i in range(texels):
				points[j * texels + i] = Vector2(corner.x + (float(i) + 0.5) * spacing, corner.y + (float(j) + 0.5) * spacing)
		var rocks: PackedFloat32Array = rock.call("surfaces_at", points) if rock != null else PackedFloat32Array()
		for k in range(texels * texels):
			var p: Vector2 = points[k]
			var slab: float = 0.0 if absf(p.x) <= GROUND_HALF.x and absf(p.y) <= GROUND_HALF.z else -INF
			out[k] = maxf(maxf(slab, rocks[k] if slab == 0.0 and not rocks.is_empty() else slab), SEA_LEVEL)
		return out
	var points := PackedInt32Array()
	points.resize(texels * texels * 2)
	for j in range(texels):
		for i in range(texels):
			var k: int = (j * texels + i) * 2
			points[k] = roundi(corner.x + (float(i) + 0.5) * spacing)
			points[k + 1] = roundi(corner.y + (float(j) + 0.5) * spacing)
	var heights: PackedInt32Array = _field.call("heights_at", points)
	var waters: PackedInt32Array = _field.call("waters_at", points)
	var rocks := PackedFloat32Array()
	if level_rock != null:
		var flat := PackedVector2Array()
		flat.resize(texels * texels)
		for k in range(texels * texels):
			flat[k] = Vector2(float(points[2 * k]), float(points[2 * k + 1]))
		rocks = level_rock.call("surfaces_at", flat)
	for k in range(texels * texels):
		var ground: float = float(heights[k]) / GROUND_TICKS_PER_METRE
		if not rocks.is_empty():
			ground = maxf(ground, rocks[k])
		out[k] = maxf(ground, float(waters[k]) / GROUND_TICKS_PER_METRE) if waters[k] > _no_water else ground
	return out


## THE GROUND UNDER A POINT, metres: the generated function's own height at the nearest metre, or on the island the slab's
## top over it, or its mountains' rock where that stands higher, and -INF past its edge, where the island's sea has no
## floor. Between the 16 m samples the surface Box3D
## collides with is `CockpitWorld.ground_height_at`, which is what a depth under a boat should ask.
static func ground_height(at: Vector3) -> float:
	if _field != null:
		var ground: float = float(int(_field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / GROUND_TICKS_PER_METRE
		var level_rock: Object = mountains()
		return maxf(ground, float(level_rock.call("surface_at", at.x, at.z))) if level_rock != null else ground
	var land: float = land_height(at)
	if land == -INF:
		return -INF
	# AND THE MOUNTAINS' ROCK over the slab: the drawn triangle, which is the collision (range_core.hpp).
	var rock: Object = mountains()
	return maxf(land, float(rock.call("surface_at", at.x, at.z))) if rock != null else land


## THE LAND UNDER A POINT, BEFORE ANY MOUNTAIN, metres: the generated ground, whose relief IS its mountains, or the island's
## slab top and -INF past its edge. For what the mountains are cut back from and so stands on the land -- an air base asking
## whether its ground is level (AirbasePlan) -- because the mountains are made from where such things are
## (`mountain_keepouts`), so asking them from inside that would ask the mountains to exist before they are made. It went
## round in a circle until the stack ran out (tests/mountains.gd, 2026-09-18).
static func land_height(at: Vector3) -> float:
	if _field != null:
		return float(int(_field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / GROUND_TICKS_PER_METRE
	var over_the_island: bool = absf(at.x) <= GROUND_HALF.x and absf(at.z) <= GROUND_HALF.z
	return 0.0 if over_the_island else -INF


## THE WATER STANDING AT A POINT, metres: a lake's level inside its water, the sea's where the ground lies below it, or -INF
## where there is none. On the island, the sea past the slab's edge and none on it.
static func water_height(at: Vector3) -> float:
	if _field != null:
		var ticks: int = int(_field.call("water_ticks_at", roundi(at.x), roundi(at.z)))
		return float(ticks) / GROUND_TICKS_PER_METRE if ticks > _no_water else -INF
	var over_the_island: bool = absf(at.x) <= GROUND_HALF.x and absf(at.z) <= GROUND_HALF.z
	return -INF if over_the_island else SEA_LEVEL


## THE NEAREST OPEN SEA TO A POINT, at least `depth` metres deep, at the sea's level: Vector3.INF if the world has none. The
## same answer on every peer, and safe on a worker. On the generated ground, sea and not a lake with the ground `depth`
## below it, searched in rings `SEA_SEARCH_RING` apart outward from `at` and settled on a `SEA_SEARCH_STEP` grid round the
## first found. On the island, `at` itself once it is `OFFSHORE` past the edge, or the point that far out along the line
## from the middle, as a boat's waypoints are placed.
static func open_sea_near(at: Vector3, depth: float) -> Vector3:
	if _field == null:
		var flat := Vector2(at.x, at.z)
		var edge: float = WORLD_HALF + OFFSHORE
		if maxf(absf(flat.x), absf(flat.y)) > edge:
			return Vector3(at.x, SEA_LEVEL, at.z)
		if flat.length() < 1.0:
			flat = Vector2(0.0, 1.0)
		flat *= (edge + 1.0) / maxf(absf(flat.x), absf(flat.y))
		return Vector3(flat.x, SEA_LEVEL, flat.y)
	if not has_sea():
		return Vector3.INF
	var half: float = float(int((_field.call("tuning") as Dictionary)["world_half"]))
	# WHOLE TICKS ROUNDED AWAY FROM THE SURFACE, never shallower than asked: rounded to the nearest, 9.2 m was 294 ticks,
	# -9.1875 m, and a gunboat was put on water shallower than its keel needed.
	var deepest: int = -ceili(depth * GROUND_TICKS_PER_METRE)
	var found := Vector3.INF
	var ring: float = 0.0
	while ring <= 2.0 * half and found == Vector3.INF:
		var count: int = maxi(1, ceili(TAU * ring / SEA_SEARCH_RING))
		var points := PackedInt32Array()
		for k in range(count):
			var angle: float = TAU * float(k) / float(count)
			points.append_array([roundi(at.x + cos(angle) * ring), roundi(at.z + sin(angle) * ring)])
		found = _nearest_open_sea(points, at, deepest)
		ring += SEA_SEARCH_RING
	if found == Vector3.INF:
		return found
	var span: int = int(SEA_SEARCH_RING / SEA_SEARCH_STEP)
	var grid := PackedInt32Array()
	for j in range(-span, span + 1):
		for i in range(-span, span + 1):
			grid.append_array([roundi(found.x) + i * int(SEA_SEARCH_STEP), roundi(found.z) + j * int(SEA_SEARCH_STEP)])
	var settled: Vector3 = _nearest_open_sea(grid, at, deepest)
	return settled if settled != Vector3.INF else found


## The nearest of `points` (x, z pairs) to `at` that is open sea -- the sea's water, not a lake's -- with the ground at or
## below `deepest` ticks, or Vector3.INF.
static func _nearest_open_sea(points: PackedInt32Array, at: Vector3, deepest: int) -> Vector3:
	var waters: PackedInt32Array = _field.call("waters_at", points)
	var heights: PackedInt32Array = _field.call("heights_at", points)
	var best := Vector3.INF
	var best_distance: float = INF
	for k in range(heights.size()):
		if waters[k] != 0 or heights[k] > deepest:
			continue
		var x: float = float(points[2 * k])
		var z: float = float(points[2 * k + 1])
		var distance: float = Vector2(x - at.x, z - at.z).length_squared()
		if distance < best_distance:
			best_distance = distance
			best = Vector3(x, SEA_LEVEL, z)
	return best

## Rock and concrete, which is the whole material list. Kept as an index rather than a
## colour so the level can put each group in its own MultiMesh and draw the lot in two
## calls instead of two hundred.
## AUTHORED is a box from a hand-built place (`AuthoredChunks`): solid like any other, and drawn by its place's own scene,
## never by the yard.
## OILRIG is an oil platform's solid (`OilField`), drawn by the platform itself and never by the yard.
enum Group { ROCK, CONCRETE, BUILDING, AUTHORED, AIRBASE, TOWER, OILRIG }

## THE MOUNTAINS ARE `MountainRanges`' (cockpit-mountains, 2026-09-18): a ring of ranges with passes between them, three
## inland ranges and two lone mountains, drawn and collided with as one set of triangles. The ring of thirty stepped
## pyramids and its numbers are gone; see `mountains` and `ring_gaps`.

## Three ranges inland, so the middle of the map is somewhere to get lost rather than a field with a ring of mountains
## round the edge of it: each range's middle, which its ridge runs through (`MountainRanges.INLAND_BEARINGS`) and its
## thermal stands beside. The north-east one and the south-west one came 600 m inward when they became ranges, so each
## leaves a valley between itself and the ring rather than running into it (2026-09-18).
const INLAND_RANGES: Array[Vector3] = [
	Vector3(-2500.0, 0.0, 2100.0),
	Vector3(2400.0, 0.0, 2000.0),
	Vector3(-1500.0, 0.0, -2600.0),
]

## THE TOWNS are `TownCatalogue`'s, and each town's street width -- wide enough to fly down, in a city -- is a
## line in it. `TownPlan` grows them; see `boxes()`.

## Eight arches, on the cardinal points at two ranges out. Axis-aligned because
## `add_static_box` has no rotation and a gate you have to approach diagonally is not a
## gate anybody flies through.
##
## Both rings sit well inside the mountains, and each gate's corridor is a keep-out the rock is cut back from.
const GATE_RADII: Array[float] = [900.0, 2800.0]
const GATE_OPENING: float = 80.0
const GATE_HEIGHT: float = 90.0

## How much room a spawn point is given. A box, not a column: an aeroplane put in at 700 m
## does not need the mountain under it deleted.
const SPAWN_CLEAR := Vector3(90.0, 70.0, 90.0)

## HOW OFTEN THE RAILWAY IS SURVEYED FOR THE MOUNTAINS' KEEP-OUT, metres. Not RAIL_STEP: that survey is the train's route, the
## lamps' and the tests', and a shorter one for the keep-out alone leaves them exactly as they were. The keep-out is one box
## per survey point, so the chord between two points is bridged by boxes and the corridor's real width is the box plus how far
## the curve sags off its chord. Halved from 40 to 20 (was RAIL_STEP) so the corridor hugs the curve: twice the boxes, a
## quarter of the sag, and the half-box below can shrink with the step.
const RAIL_KEEP_STEP: float = 20.0
## How much room the railway is given either side of each survey point, half a box: 0.6 of RAIL_KEEP_STEP. NEIGHBOURING
## BOXES MUST OVERLAP ON A BEND, so the half-extent has to exceed half the step or a gap opens between them; 0.6 is the
## margin over that. Computed from the step, never typed beside it. It was 90 m, typed in the loop, and always 90 m PLUS the
## 108 m every keep-out is grown by in range_core.cpp; then a typed 24 m against the 40 m step.
const RAIL_CLEAR := Vector3(RAIL_KEEP_STEP * 0.6, 60.0, RAIL_KEEP_STEP * 0.6)
## HOW MUCH THE RAILWAY'S BOXES ARE GROWN BY inside the mountains, whole metres. Every other keep-out is grown by one triangle's
## reach (2.25 spacings, 108 m: `range_core.cpp`) so that the DRAWN surface, whose triangles interpolate across corners and
## jitter, stays out of it. That is the right fear beside a runway final, and the wrong one beside a railway: rock drawn a
## few metres into the corridor's edge is a mountain near a railway, which is what was asked for. Not zero, because the drawn
## surface must still stay off the embankment and the gauge (`tests/mountains.gd`, the rail checks, ask the DRAWN triangles).
## 54 m, not the 48 it was: with the box halved to 12 m, 48 left 0.70 m of drawn rock on the way (12 m: 5.6). The way, not the box, sets
## the floor: box plus margin must stay about 66 m for the drawn surface to keep off the sleepers (sweep, 2026-09-19: step 20 with
## margin 48 / 54 / 60 / 72 leaves 0.70 / 0.00 / 0.00 / 0.00 m and the nearest rock at 40 / 44 / 56 / 76 m).
const RAIL_MARGIN: int = MountainRanges.SPACING + MountainRanges.SPACING / 8
## HOW STEEPLY ROCK MAY CLIMB OUT OF THE RAILWAY'S BOX, in fifths of a metre a metre (`KeepOut.rise_fifths`): the default every other
## keep-out has is 6, 6/5, fifty degrees. What the eye reads as the mountain's foot is where the ground has risen enough to be one, not
## the keep-out's edge, and at 6/5 a 100 m wall needs 83 m of run beside the line.
const RAIL_RISE_FIFTHS: int = 15

## Cruise, which is what an aeroplane has to be spawned at. One put into the air at a
## standstill stalls before it can accelerate and mushes into the ground at full power.
const CRUISE: float = 58.0
## An airliner is a heavier wing and flies faster. Its weight comes off `camber * v^2 *
## lift` like every other wing here, and that works out at 63 m/s -- so launched at the
## light aeroplane's 58 it starts BELOW its own flying speed, mushes, drops a wing and
## spirals in. A margin over the number rather than the number itself, because an aeroplane
## exactly on its stall is not flying, it is about to stop.
const CRUISE_AIRLINER: float = 72.0
const CRUISE_OSPREY: float = 80.0


## How fast a craft of this kind has to be going to fly at all.
##
## ASKED, not remembered. The simulation already works this out -- it solves the wing for
## its stall and thrust against drag for the top end, and takes a margin over the first
## and a fraction of the second -- and an aeroplane launched at a DIFFERENT speed from the
## one its own autopilot then flies at is an aeroplane that spends its first minute
## correcting. That is exactly how the airliner ended up in the sea: 72 here, 80 there, and
## a wing that stalled at 70.
##
## The constants below are the fallback for a caller with no session yet, and they are
## deliberately conservative rather than exact. Nothing has to keep them in step.
static func cruise_for(kind: int) -> float:
	if Sim.is_available() and Sim.client != null:
		var known: float = float(Sim.client.handling(kind).get("cruise", 0.0))
		if known > 1.0:
			return known
	match kind:
		Sim.Kind.AIRLINER, Sim.Kind.JUMBO: return CRUISE_AIRLINER
		# A small, heavily loaded wing under eighteen tonnes: it needs the speed.
		Sim.Kind.OSPREY: return CRUISE_OSPREY
		_: return CRUISE


## Every solid thing in the world, as `{position, half_extents, group}`.
##
## Built fresh each call rather than cached: it is a couple of hundred dictionaries once per
## session, and a cache that outlived a constant change would be a desync nobody could see.
## THE RUNWAY, and every number about it is a constant so it can be made longer.
##
## Length is the one that matters and it is the one anybody will want to change: a Cessna
## needs a few hundred metres, an airliner rather more, and the honest way to find out is to
## try it. Everything else -- the markings, the threshold bars, the centreline, the
## clearance the scenery generator has to leave -- is derived from these three, so
## lengthening the strip lengthens the paint and moves the numbers with it.
const RUNWAY_AT := Vector3(-900.0, 0.0, 900.0)
const RUNWAY_LENGTH: float = 900.0
const RUNWAY_WIDTH: float = 45.0
## Which way it points, as a compass bearing. The aircraft parked on it face the same way.
const RUNWAY_BEARING: float = 0.0
## How far apart the centreline stripes are, and how long each one is.
const RUNWAY_STRIPE: float = 30.0
const RUNWAY_STRIPE_LENGTH: float = 18.0


## The ISLAND runway's own frame: where it starts, where it ends, and which way is across it. Every reader of the island's
## runway -- the grass, the radio's runway number, the probes' poses, smoke -- asks this, and it is the island's on either
## world; the runways a world has are `runways()`.
static func runway_axis() -> Dictionary:
	return runway_frame(RUNWAY_AT, RUNWAY_BEARING, RUNWAY_LENGTH, RUNWAY_WIDTH)


## A RUNWAY'S FRAME from where its middle is, its compass bearing, its length and its width: the island's five keys
## `centre, along, across, threshold, far_end`, and `bearing, length, width` beside them, so its paint and its lights are
## worked out from the frame alone.
static func runway_frame(centre: Vector3, bearing: float, length: float, width: float) -> Dictionary:
	var along: Vector3 = nose_from_yaw(bearing)
	var across := Vector3(-along.z, 0.0, along.x)
	return {
		"centre": centre,
		"along": along,
		"across": across,
		"threshold": centre - along * length * 0.5,
		"far_end": centre + along * length * 0.5,
		"bearing": bearing,
		"length": length,
		"width": width,
	}


## EVERY RUNWAY THE WORLD HAS. The island: its one, `runway_axis()`. The generated ground: one on each airfield strip
## `GroundField` flattened, the island runway's length and width, at the strip's level, lying along the strip -- a
## strip whose long half is along x (`half_long`, the x half-extent, is the longer) points at bearing 90 degrees, one
## along z at 0. The first is the flattest strip: GroundField takes them flattest first, and the island's runway, its
## Cessnas, glider and tower go there (team-lead, 2026-09-15).
##
## AND EVERY NEW RUNWAY AN AIRFIELD FILE LAYS ON THAT WORLD, after the world's own, so runway 0 stays the island's (lane/pattern,
## 2026-09-19: the island's second strip, on the south shore, for a flight from one airfield to another). See Airfield.
## A LEVEL WITH FILES OF ITS OWN takes only those (`Airfield.world_here`), and its ground was handed their pads, so it has
## no strips of its own either: the test field's six runways are all it has (lane/testfield).
static func runways() -> Array[Dictionary]:
	if _field == null:
		var island: Array[Dictionary] = [runway_axis()]
		island.append_array(Airfield.new_runways("island"))
		return island
	var out: Array[Dictionary] = []
	for strip in (_field.call("catalogue") as Dictionary)["airfields"]:
		var along_x: bool = int(strip["half_long"]) >= int(strip["half_wide"])
		var centre := Vector3(float(strip["x"]), float(strip["level"]) / SITE_LEVEL_PER_METRE, float(strip["z"]))
		out.append(runway_frame(centre, PI * 0.5 if along_x else 0.0, RUNWAY_LENGTH, RUNWAY_WIDTH))
	out.append_array(Airfield.new_runways(Airfield.world_here()))
	return out


## THE STRIP AND ITS PAINT, as boxes for the renderer. Generated rather than modelled, which
## is the whole point: change RUNWAY_LENGTH and the stripes, the thresholds and the
## clearance all follow. The island runway's: see `runway_marks_for`.
static func runway_marks() -> Array[Dictionary]:
	return runway_marks_for(runway_axis())


## WHETHER A POINT LIES ON A RUNWAY'S PAVEMENT, `margin` metres wider all round, in plan.
static func on_runway(frame: Dictionary, at: Vector3, margin: float = 0.0) -> bool:
	var rel: Vector3 = at - (frame["centre"] as Vector3)
	return absf(rel.dot(frame["along"])) <= float(frame["length"]) * 0.5 + margin \
		and absf(rel.dot(frame["across"])) <= float(frame["width"]) * 0.5 + margin


## WHERE TWO RUNWAYS CROSS, in plan, or Vector3.INF where they do not: the meeting of their centrelines, if it lies on both.
static func runways_cross(a: Dictionary, b: Dictionary) -> Vector3:
	var da: Vector3 = a["along"]
	var db: Vector3 = b["along"]
	var d: float = da.x * db.z - da.z * db.x
	if absf(d) < 1e-6:
		return Vector3.INF
	var w: Vector3 = (b["centre"] as Vector3) - (a["centre"] as Vector3)
	var t: float = (w.x * db.z - w.z * db.x) / d
	var at: Vector3 = (a["centre"] as Vector3) + da * t
	return at if on_runway(a, at) and on_runway(b, at) else Vector3.INF


## HOW MUCH LOWER A RUNWAY THAT CROSSES AN EARLIER ONE HAS ITS ASPHALT, metres: two slabs with one top flicker where they
## cross. Still above the air base's pavement (top 0.10), which runs onto its edge at every stub.
const CROSSING_DROP: float = 0.01


## ONE RUNWAY'S PAINT, from its frame (`runway_frame`): the asphalt, the centreline and the threshold bars, each lying on the
## frame's centre height and turned to its bearing. `under` is every runway drawn before it: where it crosses one of them
## its asphalt lies a hair lower and none of its own paint is laid on the other's, so the earlier runway's centreline runs
## through the crossing unbroken, as the busier runway's does at a real one (lane/airport, 2026-09-19).
static func runway_marks_for(frame: Dictionary, under: Array = []) -> Array[Dictionary]:
	var crossed: Array[Dictionary] = []
	for other in under:
		if runways_cross(frame, other) != Vector3.INF:
			crossed.append(other)
	var drop: float = CROSSING_DROP if not crossed.is_empty() else 0.0
	var along: Vector3 = frame["along"]
	var across: Vector3 = frame["across"]
	var centre: Vector3 = frame["centre"]
	var length: float = frame["length"]
	var width: float = frame["width"]
	var bearing: float = frame["bearing"]
	var out: Array[Dictionary] = []
	# The asphalt, a hand's breadth above the grass so the two do not share a plane and
	# flicker against each other.
	out.append({"position": centre + Vector3(0.0, 0.06 - drop * 0.5, 0.0),
		"half_extents": Vector3(width * 0.5, 0.06 - drop * 0.5, length * 0.5),
		"yaw": bearing, "colour": Color(0.13, 0.13, 0.14)})
	# THE CENTRELINE, as many stripes as the strip is long -- none on a runway it crosses.
	var stripes: int = int(floor(length / RUNWAY_STRIPE)) - 1
	for i in range(stripes):
		var at: float = (float(i) - float(stripes - 1) * 0.5) * RUNWAY_STRIPE
		var painted_on_another: bool = false
		for other in crossed:
			painted_on_another = painted_on_another or on_runway(other, centre + along * at, RUNWAY_STRIPE_LENGTH * 0.5)
		if painted_on_another:
			continue
		out.append({"position": centre + along * at + Vector3(0.0, 0.13, 0.0),
			"half_extents": Vector3(0.5, 0.02, RUNWAY_STRIPE_LENGTH * 0.5),
			"yaw": bearing, "colour": Color(0.86, 0.86, 0.84)})
	# THRESHOLD BARS at each end: the piano keys, which are what tells a pilot where the
	# runway starts rather than where the tarmac does.
	for end in [-1.0, 1.0]:
		for bar in range(6):
			var side: float = (float(bar) - 2.5) * width * 0.13
			out.append({
				"position": centre + along * (end * (length * 0.5 - 22.0))
					+ across * side + Vector3(0.0, 0.13, 0.0),
				"half_extents": Vector3(width * 0.045, 0.02, 18.0),
				"yaw": bearing, "colour": Color(0.86, 0.86, 0.84)})
	return out


## THE LIGHTS ON THE STRIP, generated from the same three numbers as the paint.
##
## A runway from the circuit is a grey stripe on a green field, and from four kilometres it is
## not there at all. Lights are what a pilot finds it by, so they are laid the way a real one
## is: white edge lights down both sides, a bar of green across each threshold with red
## inside it, a line of approach lights out along the centreline with strobes that run
## towards the threshold, and a PAPI -- four lights beside the touchdown zone that show red
## below the glidepath and white above it, two of each when you are on it.
##
## Placed off `runway_axis`, so lengthening the runway lengthens its lights too. Drawn by
## `VehicleLights`, which is where what each pattern looks like lives.
const RUNWAY_EDGE_SPACING: float = 60.0
const APPROACH_LENGTH: float = 300.0
const APPROACH_SPACING: float = 30.0
## How far along from the threshold the PAPI stands, and the four angles it is set to,
## innermost first: the light nearest the runway is set highest, so on the glidepath the two
## inboard show red and the two outboard white.
const PAPI_FROM_THRESHOLD: float = 300.0
const PAPI_ANGLES: Array[float] = [3.5, 3.17, 2.83, 2.5]

## The island runway's lights: see `runway_lights_for`.
static func runway_lights() -> Array[Dictionary]:
	return runway_lights_for(runway_axis())


## ONE RUNWAY'S LIGHTS, from its frame (`runway_frame`), laid as the island's are.
static func runway_lights_for(frame: Dictionary, others: Array = []) -> Array[Dictionary]:
	var along: Vector3 = frame["along"]
	var across: Vector3 = frame["across"]
	var threshold: Vector3 = frame["threshold"]
	var far_end: Vector3 = frame["far_end"]
	var length: float = frame["length"]
	var width: float = frame["width"]
	var white := Color(1.0, 0.95, 0.82)
	var out: Array[Dictionary] = []
	# EDGE LIGHTS, both sides, end to end.
	var spans: int = maxi(int(floor(length / RUNWAY_EDGE_SPACING)), 1)
	for i in range(spans + 1):
		var down: Vector3 = threshold + along * (length * float(i) / float(spans))
		for side in [-1.0, 1.0]:
			out.append({"position": down + across * side * (width * 0.5 + 2.0)
				+ Vector3.UP * 0.4, "colour": white, "pattern": 0, "radius": 0.3,
				"floor": 1.0})
	# THRESHOLDS, at both ends: green facing out, red facing in. The sprites have no facing,
	# so the two are separate rows a few metres apart, and each end shows both.
	for end in [threshold, far_end]:
		var outward: Vector3 = -along if end == threshold else along
		for i in range(9):
			var sideways: Vector3 = across * (float(i) - 4.0) * (width / 9.0)
			out.append({"position": (end as Vector3) + outward * 4.0 + sideways
				+ Vector3.UP * 0.4, "colour": Color(0.2, 1.0, 0.35), "pattern": 0,
				"radius": 0.3, "floor": 1.1})
			out.append({"position": (end as Vector3) - outward * 4.0 + sideways
				+ Vector3.UP * 0.4, "colour": Color(1.0, 0.12, 0.08), "pattern": 0,
				"radius": 0.3, "floor": 1.1})
	# THE APPROACH LIGHTS, out from the threshold the aircraft on it face: a white bar every
	# thirty metres, and a strobe in each that fires in sequence towards the runway.
	var bars: int = int(floor(APPROACH_LENGTH / APPROACH_SPACING))
	for b in range(1, bars + 1):
		var at: Vector3 = threshold - along * (float(b) * APPROACH_SPACING) + Vector3.UP * 1.0
		for k in [-1.0, 0.0, 1.0]:
			out.append({"position": at + across * k * 3.0, "colour": white, "pattern": 0,
				"radius": 0.3, "floor": 1.0})
		out.append({"position": at + Vector3.UP * 0.6, "colour": Color(1.0, 1.0, 1.0),
			"pattern": 3, "radius": 0.3, "floor": 2.0,
			"phase": float(bars - b) / float(bars)})
	# THE PAPI, on the left of the touchdown zone, which is the side a captain looks out of.
	var touchdown: Vector3 = threshold + along * PAPI_FROM_THRESHOLD
	for i in range(PAPI_ANGLES.size()):
		out.append({"position": touchdown - across * (width * 0.5 + 15.0 + float(i) * 9.0)
			+ Vector3.UP * 0.6, "colour": Color(1.0, 1.0, 1.0), "pattern": 4, "radius": 0.45,
			"floor": 1.5, "papi": PAPI_ANGLES[i]})
	# NONE STANDING ON A RUNWAY IT CROSSES: an edge light 0.4 m tall in the middle of the other runway is a post an aeroplane
	# rolls into. A real crossing's lights there are inset flush; these are left out.
	var crossed: Array = others.filter(func(other: Dictionary) -> bool: return runways_cross(frame, other) != Vector3.INF)
	if crossed.is_empty():
		return out
	var kept: Array[Dictionary] = []
	for light in out:
		var on_another: bool = false
		for other in crossed:
			on_another = on_another or on_runway(other, light["position"], 3.0)
		if not on_another:
			kept.append(light)
	return kept


static func boxes() -> Array[Dictionary]:
	var clear: Array[Dictionary] = _clearances()
	var out: Array[Dictionary] = []
	# ON THE GENERATED GROUND, THE SEATED TOWNS AND NOTHING ELSE: the ring and inland peaks and the gates are the island's
	# boxes on its slab, and the ground itself is the mountains there. See TownCatalogue.towns.
	if _field != null:
		TownPlan.build(out, clear)
		out.append_array(AirbasePlan.boxes())
		out.append_array(PowerStation.boxes())
		out.append_array(OilField.boxes())
		return out
	# THE MOUNTAINS ARE NOT IN THIS LIST: they are triangles, `mountains()`, handed to the simulation and the picture by
	# the level, and they keep out of the towns, not the towns out of them (`mountain_keepouts`).
	TownPlan.build(out, clear)
	# THE AIR BASES' WALLS AND ROOFS, unfiltered like the gates: a base keeps its own clearance (see `_clearances`), and on
	# a world where it does not fit it is not laid at all, so there is nothing of it to filter. See AirbasePlan.
	out.append_array(AirbasePlan.boxes())
	# THE COOLING TOWERS, on both worlds, unfiltered for the same reason a base is: a station is placed from the town it
	# serves rather than scattered, and `tests/cooling_towers.gd` holds it clear of every clearance rather than trusting
	# the placement. 33 boxes a tower, 66 for the station, on an island that files 1,014; see CoolingTower.SOLID_BANDS for
	# what shape they are and which way the approximation is allowed to be wrong. They carry Group.TOWER, which nothing
	# draws -- PowerStation draws the shell itself, and a box drawn as well would be a grey slab inside a cooling tower.
	out.append_array(PowerStation.boxes())
	# THE OIL PLATFORMS, out at sea, unfiltered: a platform is placed clear of every ship's spawn by `OilField`, and nothing
	# else stands in the sea for it to be kept clear of. Group.OILRIG, drawn by the platform, never by the yard.
	out.append_array(OilField.boxes())
	# Last, and unfiltered: the gates ARE one of the things being kept clear, so they are
	# the one thing that may stand in a clearance.
	_gates(out)
	return out


## Where every vehicle starts, as `{kind, position, yaw, velocity}`.
##
## Here rather than in the level because the generator has to know: a spawn the scenery
## does not know about is a spawn the scenery will eventually be generated on top of.
static func spawns() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Lined up on the north and south gates, because the first thing anybody does with an
	# aeroplane they have been handed is point it at whatever is in front of them.
	out.append(_air(Sim.Kind.PLANE, Vector3(0.0, 60.0, 400.0), PI))
	out.append(_air(Sim.Kind.PLANE, Vector3(0.0, 60.0, -400.0), 0.0))
	# One down the length of the near city, one high enough to see the whole ring, and one
	# a long way out, because a map this size wants somewhere to start that is not home.
	out.append(_air(Sim.Kind.PLANE, Vector3(520.0, 170.0, 200.0), PI))
	out.append(_air(Sim.Kind.PLANE, Vector3(-1400.0, 900.0, -1400.0), PI * 0.75))
	out.append(_air(Sim.Kind.PLANE, Vector3(3400.0, 260.0, -1200.0), PI))
	out.append(_air(Sim.Kind.PLANE, Vector3(-3600.0, 260.0, 300.0), 0.0))
	# AIRLINERS, which are the same wing flown from a completely different flight deck: a
	# yoke at each seat and one throttle quadrant between them.
	out.append(_air(Sim.Kind.AIRLINER, Vector3(-260.0, 220.0, 260.0), PI * 0.25))
	out.append(_air(Sim.Kind.AIRLINER, Vector3(900.0, 300.0, -900.0), PI * 1.25))
	# The 747 starts airborne: the island strip is far too short for a 70 m aeroplane of 280
	# tonnes, while the player can still select and fly it immediately.
	out.append(_air(Sim.Kind.JUMBO, Vector3(1500.0, 520.0, 1200.0), PI * 0.65))
	# The tandem fighter is a normal selectable world craft, not something that exists only
	# in its bench and builder. It starts on an autopilot leg until somebody takes a seat.
	out.append(_air(Sim.Kind.FIGHTER, Vector3(1850.0, 620.0, -1450.0), PI * 0.35))
	# AND THE SWING-WING TOMCAT, the same way, a little further out and higher: a player's F26 takes it, and until then
	# its autopilot flies it with the wings spread.
	out.append(_air(Sim.Kind.TOMCAT, Vector3(2250.0, 700.0, -1150.0), PI * 0.35))
	# AND THE F-4E, the same way, between the Tomcat and the fighter and a little lower. IT NEEDS THIS ROW FOR A
	# REASON THAT IS NOT SPAWNING: `Sky._register_issue_places` walks this table, so a kind with no row here has no
	# issue place and the CRAFT page answers `kind_no_issue_place` to anyone who asks for one. The Phantom went in
	# without a row and the failure surfaced four suites away (lane/boatcrew's checklist, step 9).
	out.append(_air(Sim.Kind.PHANTOM, Vector3(2050.0, 580.0, -1650.0), PI * 0.35))
	# AND THE SINGLE-SEAT F-16, the same way again, the other side of the fighter and lower. A kind with nothing of it in
	# the world gives its key nothing to board (`lane/tomcat`), so there is one here from the start.
	out.append(_air(Sim.Kind.FALCON, Vector3(1450.0, 560.0, -1750.0), PI * 0.35))
	# AND THE F-35B, the same way, on the far side of the F-16 and a little higher: its autopilot flies it with the nozzle
	# aft, as the Osprey's flies with its nacelles forward, and a player who takes it can put the nozzle down and hover.
	out.append(_air(Sim.Kind.LIGHTNING, Vector3(1150.0, 600.0, -2050.0), PI * 0.35))
	# AND THE A-10C, the same way, beyond the F-35B and lower than the fighters: on its autopilot until a
	# player takes it.
	out.append(_air(Sim.Kind.WARTHOG, Vector3(850.0, 580.0, -2350.0), PI * 0.35))
	# AND THE P-51D, the same way, beyond the A-10C and lower still: the first warbird, on its autopilot until a player
	# takes it (lane/warbirds2).
	out.append(_air(Sim.Kind.P51, Vector3(550.0, 520.0, -2650.0), PI * 0.35))
	# AND THE P-47D-30, beside the Mustang and a little further out: the second warbird (lane/warbirds2).
	out.append(_air(Sim.Kind.P47, Vector3(250.0, 540.0, -2850.0), PI * 0.35))
	# The four-seat Prowler starts airborne like the carrier fighters; this also registers clear issue places so either
	# front-seat player can select it through the normal craft request path.
	out.append(_air(Sim.Kind.PROWLER, Vector3(1750.0, 640.0, -2050.0), PI * 0.35))
	# A TILTROTOR, airborne with its nacelles forward, which is the configuration it crosses
	# an island in. Wind them up and it will hover.
	out.append(_air(Sim.Kind.OSPREY, Vector3(-700.0, 200.0, -300.0), PI * 0.5))
	# AND A TANDEM-ROTOR HEAVY LIFTER, parked. It hovers off the ground under its own
	# collective like any other helicopter, and there is a seat on its ramp.
	out.append(_parked(Sim.Kind.CHINOOK, Vector3(-60.0, 26.0, -20.0), 0.0))
	out.append(_parked(Sim.Kind.CHINOOK, Vector3(340.0, 26.0, -260.0), 0.0))
	# A distinct four-station UH-60 for ordinary solo and hosted sessions. Parked so a crew
	# can board it together before bringing the rotor up.
	out.append(_parked(Sim.Kind.UH60, Vector3(-130.0, 26.0, -40.0), 0.0))
	# AND AN MH-6 LITTLE BIRD beside it, doors off, for two pilots packed in close and a rider on each bench.
	out.append(_parked(Sim.Kind.LITTLEBIRD, Vector3(-170.0, 26.0, -40.0), 0.0))
	# AND AN AH-64D APACHE past it, for a pilot and a gunner in tandem: 45 m on, so its 14.6 m rotor clears the Little
	# Bird's by more than a rotor's width.
	out.append(_parked(Sim.Kind.APACHE, Vector3(-215.0, 26.0, -40.0), 0.0))
	# TWO CESSNAS ON THE RUNWAY, at the threshold, pointing down it. A light aeroplane is
	# the one aircraft here that can actually use a strip this length, and it is parked
	# rather than launched because taking off is the point of it being there.
	# OFF THE FIRST RUNWAY'S FRAME, so the same numbers stand them on the island's strip and on the generated ground's
	# flattest: across and along are the island's +x and -z at its bearing of 0, so the island's places are the ones they were.
	var runway: Dictionary = runways()[0]
	var runway_at: Vector3 = runway["centre"]
	var along: Vector3 = runway["along"]
	var across: Vector3 = runway["across"]
	var bearing: float = runway["bearing"]
	out.append(_placed(_parked(Sim.Kind.CESSNA,
		runway_at - along * (RUNWAY_LENGTH * 0.5 - 60.0) - across * 9.0 + Vector3.UP * 1.2, bearing), &"runway"))
	out.append(_placed(_parked(Sim.Kind.CESSNA,
		runway_at - along * (RUNWAY_LENGTH * 0.5 - 60.0) + across * 9.0 + Vector3.UP * 1.2, bearing), &"runway"))
	# AND THE TOWER: where the air base laid round the first runway puts it, its first seat facing the runway (see
	# AirbasePlan) -- or, on a runway with no base, off to one side of the strip, looking down it. Stood on its own
	# half-height, off the shape table: its origin is the middle of its box.
	var tower_half: float = (Sim.geometry_of(Sim.Kind.TOWER).get("extents", Vector3.ONE) as Vector3).y
	var airbase: Dictionary = AirbasePlan.on_runway(0)
	if not airbase.is_empty():
		out.append(_placed(_parked(Sim.Kind.TOWER, (airbase["tower"]["position"] as Vector3) + Vector3.UP * tower_half,
			airbase["tower"]["yaw"]), &"runway"))
	else:
		out.append(_placed(_parked(Sim.Kind.TOWER,
			runway_at + across * (RUNWAY_WIDTH * 0.5 + 55.0) + Vector3.UP * tower_half, bearing), &"runway"))
	# A PATROL BOAT: a driver in the wheelhouse and a gun at each end, each gun its own
	# seat. The first craft in the game where three people have three different jobs.
	# A GUNSHIP, up and orbiting the island the way one does. It is spawned already flying
	# like every other aeroplane -- a wing put into the air at a standstill stalls before it
	# can accelerate -- and it is out over the water, where a gun pointing down at nothing
	# is a gun that can be fired at nothing.
	out.append(_air(Sim.Kind.GUNSHIP, Vector3(1800.0, 900.0, 2600.0), PI * 0.5))
	# AND ITS UNARMED SISTER, the C-130H transport (lane/liners, 2026-09-19): the same airframe with a ramp and no guns,
	# on a leg inside the gunship's and lower, so the two are seen together from the island.
	out.append(_air(Sim.Kind.TRANSPORT, Vector3(1300.0, 700.0, 1900.0), PI * 0.5))

	# TWO TANKS, side by side and pointing down the open ground away from the city, because
	# the first thing anybody does with a gun is fire it at whatever is in front of them and
	# what is in front of them should not be a tower block.
	out.append(_parked(Sim.Kind.TANK, Vector3(-40.0, 1.3, 700.0), PI))
	out.append(_parked(Sim.Kind.TANK, Vector3(-28.0, 1.3, 712.0), PI))
	# ON THE SEA, not under it: a gunboat's origin is its design waterline (`gunboat_shape`), so it is put at the sea's
	# level and floats there. The 0.6 m it used to be sunk by was a box floating low round its middle.
	out.append(_parked(Sim.Kind.GUNBOAT, Vector3(-120.0, SEA_LEVEL, 7600.0), 0.0))
	out.append(_parked(Sim.Kind.GUNBOAT, Vector3(200.0, SEA_LEVEL, 7680.0), PI * 0.5))
	# A CB90 FAST ASSAULT CRAFT among them, off the south coast with the other small boats and well clear of the oil rig
	# in the north-east sea: two guns at the back and a box of missiles on the roof (lane/boats, 2026-09-18). Its origin
	# is its design waterline (`cb90_shape`), so it is put at the sea's level.
	out.append(_parked(Sim.Kind.CB90, Vector3(110.0, SEA_LEVEL, 7560.0), 0.0))
	# AND A FIREBOAT, 42.7 m of her, beside them and clear of the CB90's berth (lane/boatcrew, 2026-09-20). She had no row at
	# all, and a kind with no row here has no issue place (`Sky._register_issue_places` walks this table), so a player who
	# asked the CRAFT page for one was answered `kind_no_issue_place` and `tests/crew_sync.gd` found no view of kind 37. Her
	# origin is her design waterline (`fireboat_shape`), so she is put at the sea's level.
	out.append(_parked(Sim.Kind.FIREBOAT, Vector3(-30.0, SEA_LEVEL, 7480.0), 0.0))
	# TWO CAPITAL SHIPS, well out to sea and under way. OCEAN ONLY, which is what the
	# BOAT waypoint pool already means -- everything inside the island's square is a field,
	# so a hull sent there would be a hull driving up the beach.
	#
	# The carrier is UNDER WAY on purpose. A third of a kilometre of deck doing fifteen
	# metres a second is the thing that makes landing on it a landing rather than a parking
	# exercise, and it is why an aeroplane's idea of "the ground" had to stop being a
	# height and start being whatever is underneath it.
	# NAMED, because the Hawkeye parked on its deck is put by it and the level records which entity it became: an index
	# into this table would name a different spawn on the generated ground, whose arm drops entries.
	var ford: Dictionary = _named(_moving(Sim.Kind.CARRIER, Vector3(-2200.0, SEA_LEVEL + 4.0, 9200.0),
		PI * 0.5, 12.0), &"ford")
	out.append(ford)
	# AN E-2D ON THE FORD'S DECK, parked abaft the island (CarrierPlan.PARKED), carried at the ship's speed: a craft parked on
	# a ship under way is still, on the deck, and moving through the world. Put by the carrier's own spawn transform, the
	# island's placed at the same tick, so the deck is under it when it is spawned and its gear comes down on it.
	out.append(parked_on(ford, Sim.Kind.HAWKEYE))
	# A VIRGINIA-CLASS SUBMARINE, surfaced, three kilometres further out than the carrier and slower than it. Its origin is
	# its design waterline (`submarine_shape`), so it is put at the sea's level and floats there.
	out.append(_moving(Sim.Kind.SUBMARINE, Vector3(-2200.0, SEA_LEVEL, 12200.0), PI * 0.5, 6.0))
	# AND AN E-2D ON STATION, at an ordinary height rather than 25,000 ft where nobody would see it, near the carrier.
	out.append(_air(Sim.Kind.HAWKEYE, Vector3(-2200.0, 900.0, 6600.0), PI * 0.5))
	out.append(_moving(Sim.Kind.BATTLESHIP, Vector3(1800.0, SEA_LEVEL + 2.0, 9600.0),
		PI * 0.35, 10.0))
	out.append(_parked(Sim.Kind.HELI, Vector3(14.0, 26.0, -20.0), 0.0))
	out.append(_parked(Sim.Kind.HELI, Vector3(300.0, 26.0, -260.0), 0.0))
	out.append(_placed(_parked(Sim.Kind.HELI, _in_town(&"eastern", Vector3(0.0, 26.0, 0.0)), 0.0), &"town"))
	out.append(_parked(Sim.Kind.POD, Vector3(-14.0, 26.0, -20.0), 0.0))
	# Above an inland range, looking down on it.
	out.append(_parked(Sim.Kind.POD, Vector3(-2500.0, 700.0, 2100.0), 0.0))
	out.append(_parked(Sim.Kind.CAR, Vector3(6.0, 0.7, 24.0), 0.0))
	out.append(_parked(Sim.Kind.CAR, Vector3(-6.0, 0.7, 24.0), 0.0))
	# In the streets, which are wide enough to drive down and to fly down.
	out.append(_placed(_parked(Sim.Kind.CAR, _in_town(&"inner", Vector3(0.0, 0.7, 192.0)), 0.0), &"town"))
	out.append(_placed(_parked(Sim.Kind.CAR, _in_town(&"inner", Vector3(-96.0, 0.7, 0.0)), PI * 0.5), &"town"))
	out.append(_placed(_parked(Sim.Kind.CAR, _in_town(&"western", Vector3(0.0, 0.7, 192.0)), 0.0), &"town"))
	# Off the coast, because a boat needs water and the island has an edge. Put AT the sea's level: a launch's origin is its
	# design waterline (`boat_shape`), which is where it floats, so there is nothing to sink it by.
	out.append(_parked(Sim.Kind.BOAT, Vector3(0.0, SEA_LEVEL, 7600.0), 0.0))
	out.append(_parked(Sim.Kind.BOAT, Vector3(60.0, SEA_LEVEL, 7660.0), 0.0))
	# TWO GLIDERS, PARKED ON THE APRON beside the runway. Parked rather than airborne, and
	# that is the one place in this table where it matters: an aeroplane with no engine
	# cannot be launched by giving it speed, so it is left on the ground -- and the
	# take-the-next-craft button LAUNCHES a parked aeroplane, at flying speed and well clear
	# of the ground, which is the winch this game already had and did not know it.
	out.append(_placed(_parked(Sim.Kind.GLIDER,
		runway_at - across * (RUNWAY_WIDTH * 0.5 + 22.0) + along * 120.0 + Vector3.UP * 1.0, bearing), &"runway"))
	out.append(_placed(_parked(Sim.Kind.GLIDER,
		runway_at - across * (RUNWAY_WIDTH * 0.5 + 22.0) + along * 150.0 + Vector3.UP * 1.0, bearing), &"runway"))
	# TWO WATER BOMBERS, airborne over the island and pointing at the fires. Spawned in the
	# air like every other wing, and near the coast: a tanker's first move is always towards
	# water, and the shortest sortie is the one that starts beside some.
	# TWO WATER BOMBERS, airborne over the island and pointing at the fires. Spawned in the
	# air like every other wing, and near the coast: a tanker's first move is always towards
	# water, and the shortest sortie is the one that starts beside some.
	out.append(_air(Sim.Kind.TANKER, Vector3(-4200.0, 320.0, 3000.0), PI * 0.25))
	out.append(_air(Sim.Kind.TANKER, Vector3(2600.0, 320.0, -3400.0), PI * 1.15))
	return out if _field == null else _spawns_on_the_ground(out)


## THE ISLAND'S TABLE ON THE GENERATED GROUND. Every aeroplane and helicopter the table launches stands at its island
## height over the highest surface within AIR_SPAWN_ROOM of it. Every ship goes to the nearest open sea as deep as its keel
## needs, within the placed reach, and one under way is turned SHIP_TURN_STEP at a time until SHIP_TRACK of deep water lies
## ahead -- or parked, if no heading has it. A parked spawn with a "place" -- the runway's aircraft and tower, a town's cars
## and helicopter -- was placed off that place when the table was built, on the first strip or its seated town, so it stands
## as it is. A parked one with NO place:
## - a helicopter, Chinook or pod parked low takes the next of APRON_SPOTS on the first runway's apron, across the strip from
##   the gliders, resting on the strip's level at its own half-height and facing along the runway (team-lead's (a'),
##   2026-09-15): the ground by the level's spawn, where the island keeps them, is a ~41 degree mountainside, and a parked
##   machine wants somewhere flat to rest; one more than there are spots is not placed;
## - a pod parked high (its island height over RANGE_POD_FROM) stands that height over the highest surface within HELI_ROOM
##   of its own x and z, kept as "over" (team-lead's (c));
## - a car or a tank -- a road machine, which stays in its town's streets or is not placed (team-lead, 2026-09-15) -- takes the
##   next of ROAD_MACHINE_SPOTS on inner's central avenue, and one more than there are spots is not placed.
## Anything else parked with no place is left out.
static func _spawns_on_the_ground(island: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var taken: Dictionary = {}
	for spawn in island:
		var kind: int = int(spawn["kind"])
		var at: Vector3 = spawn["position"]
		var launch: Vector3 = spawn["velocity"]
		# A CRAFT PARKED ON A CARRIER stands on that carrier as THIS arm placed it -- moved to open sea, perhaps turned --
		# found by the name it refers to, never re-placed as a launched aeroplane for the ship's speed it carries. Its
		# carrier comes before it in the table. A carrier this world could not place takes the craft with it, said by name.
		if spawn.get("place", &"") == &"carrier":
			var ship: Dictionary = {}
			for placed in out:
				if placed.get("name", &"") == spawn.get("on", &""):
					ship = placed
			if ship.is_empty():
				# A WORLD WITH NO SEA drops its ships without a word (below) and their aircraft with them, and that is the
				# level's truth, not a fault: the test field and the glider level have no sea to put a carrier on. Only a
				# world that HAS sea and still did not place its carrier is worth a warning (lane/noplace, 2026-09-19:
				# testfield and gliderlevel printed one per spawn table built).
				if not has_sea():
					continue
				push_warning("Terrain: the %s parked on %s is not placed: its carrier %s was not placed on this world" % [
					Sim.kind_name(kind), spawn.get("on", &""), spawn.get("on", &"")])
				continue
			var aboard: Dictionary = parked_on(ship, kind)
			if not aboard.is_empty():
				out.append(aboard)
			continue
		if is_a_ship(kind):
			var depth: float = ship_depth(kind)
			var sea: Vector3 = open_sea_near(at, depth)
			if sea == Vector3.INF or Vector2(sea.x, sea.z).length() > placed_reach():
				continue
			var afloat: Dictionary = spawn.duplicate()
			afloat["position"] = Vector3(sea.x, at.y, sea.z)
			if launch.length() > 0.01:
				afloat["velocity"] = Vector3.ZERO
				for turn in range(roundi(TAU / SHIP_TURN_STEP)):
					var heading: float = float(spawn["yaw"]) + float(turn) * SHIP_TURN_STEP
					if open_sea_track(sea, heading, depth):
						afloat["yaw"] = heading
						afloat["velocity"] = nose_from_yaw(heading) * launch.length()
						break
			out.append(afloat)
		elif launch.length() > 1.0:
			# NO LOWER THAN THE POOL IT FLIES TO: the simulation keeps a leg only if it clears AS FLOWN -- up at the machine's
			# own climb, then level -- and a wing launched at the island's 60 m beside a range had no leg whose climb cleared
			# the ridge, and searched for ever. Every kind this table launches flies to the wings' pool.
			var up: Dictionary = spawn.duplicate()
			up["position"] = Vector3(at.x, highest_near(at, AIR_SPAWN_ROOM) + maxf(at.y, WING_LOW), at.z)
			out.append(up)
		elif spawn.has("place"):
			out.append(spawn)
		elif kind == Sim.Kind.POD and at.y > RANGE_POD_FROM:
			var hovering: Dictionary = spawn.duplicate()
			hovering["position"] = Vector3(at.x, highest_near(at, HELI_ROOM) + at.y, at.z)
			hovering["over"] = at.y
			out.append(_placed(hovering, &"ground"))
		elif kind in [Sim.Kind.HELI, Sim.Kind.UH60, Sim.Kind.LITTLEBIRD, Sim.Kind.APACHE, Sim.Kind.CHINOOK, Sim.Kind.POD]:
			var next_pad: int = int(taken.get(&"apron", 0))
			if next_pad < APRON_SPOTS.size():
				var runway: Dictionary = runways()[0]
				var spot: Vector2 = APRON_SPOTS[next_pad]
				var half_high: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
				var resting: Dictionary = spawn.duplicate()
				resting["position"] = ((runway["centre"] as Vector3) + (runway["across"] as Vector3) * spot.x
					+ (runway["along"] as Vector3) * spot.y + Vector3.UP * half_high)
				resting["yaw"] = runway["bearing"]
				out.append(_placed(resting, &"runway"))
				taken[&"apron"] = next_pad + 1
		elif ROAD_MACHINE_SPOTS.has(kind):
			var spots: Array = ROAD_MACHINE_SPOTS[kind]
			var next: int = int(taken.get(kind, 0))
			if next < spots.size():
				var driven: Dictionary = spawn.duplicate()
				driven["position"] = _in_town(&"inner", spots[next])
				out.append(_placed(driven, &"town"))
				taken[kind] = next + 1
	return out


## WHERE THE ISLAND IS BURNING, as `{position, strength}`.
##
## IN THIS FILE, WITH THE SCENERY, and for the same reason the spawns are: the generator has
## to know. A fire is a place on the ground, and a place on the ground that the generator
## does not know about is one it will eventually put a mountain on top of. These sit in the
## clearances the peaks already avoid.
##
## AND UNLIKE THE SCENERY THEY ARE REPLICATED, because they CHANGE. See FireState: a peak is
## built identically on every peer and never mentioned again; whether a fire is out is the
## one fact this whole exercise turns on, and two peers with different answers are two peers
## playing different games. So this is the list the SERVER lights them from, and every other
## machine hears about them over the wire.
##
## SPREAD OUT, AND NOT ALL THE SAME SIZE. A dozen identical fires in a row is a chore; a big
## one on a ridge with two small ones downwind of it is a decision about which to hit first.
const FIRE_GROUND: float = 3200.0

## HOW FAR OUT A FIRE MAY BE, in metres from the middle. The ring of peaks starts at about
## 4850 and the ground slab runs to 7200, so this keeps a fire on the island and off the
## beach -- the furthest one the world starts with is 4300.
const FIRE_REACH: float = 5000.0
## And how far it has to stand off a solid box. A fire inside a hill is worse than an
## aeroplane inside one: the smoke comes out of the rock and there is nothing to aim at, and
## the column is 260 m of it. See `fires()` above -- the placed ones get their clearance from
## the generator and a fire that SPREADS has to earn the same one.
const FIRE_ROOM: float = 90.0


## WHETHER A FIRE COULD BURN HERE. The solid list is handed in rather than generated, because
## the caller is asking this a few times a minute and `boxes()` builds four hundred and
## sixty-three of them.
static func can_burn(solid: Array[Dictionary], at: Vector3) -> bool:
	# ON THE GENERATED GROUND: on land and not in a lake, within the land's reach, no steeper than FIRE_STEEPEST, and clear of
	# anything solid.
	if _field != null:
		return water_height(at) == -INF and Vector2(at.x, at.z).length() <= land_reach() \
			and slope_at(at) <= FIRE_STEEPEST and _clear_of(solid, at, FIRE_ROOM)
	if maxf(absf(at.x), absf(at.z)) > FIRE_REACH:
		return false
	return _clear_of(solid, at, FIRE_ROOM) and rock_clears(at, Vector3(FIRE_ROOM, 0.0, FIRE_ROOM))


static func fires() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Two on the near hillsides, where anybody who has just taken off will see the smoke
	# before they have finished climbing.
	out.append({"position": Vector3(1250.0, 0.0, 1450.0), "strength": 1.0})
	out.append({"position": Vector3(1420.0, 0.0, 1610.0), "strength": 0.7})
	out.append({"position": Vector3(-1600.0, 0.0, 2050.0), "strength": 0.9})
	# A GROUP, which is what a fire that has been burning for an hour looks like: one big
	# one and its children downwind.
	out.append({"position": Vector3(-2900.0, 0.0, -1750.0), "strength": 1.0})
	out.append({"position": Vector3(-2720.0, 0.0, -1610.0), "strength": 0.6})
	out.append({"position": Vector3(-3080.0, 0.0, -1590.0), "strength": 0.5})
	# And three well out towards the ring, so that there is always one a long way from the
	# nearest water. That is the sortie worth flying: the one where the round trip costs
	# you something.
	out.append({"position": Vector3(4300.0, 0.0, -900.0), "strength": 1.0})
	out.append({"position": Vector3(-4100.0, 0.0, -3300.0), "strength": 0.8})
	out.append({"position": Vector3(3300.0, 0.0, 3700.0), "strength": 1.0})
	return out if _field == null else _fires_on_the_ground(out)


## THE ISLAND'S FIRES ON THE GENERATED GROUND: each at the nearest place to its island place that can burn, searched in rings
## FIRE_ROOM apart out to FIRE_SEARCH, standing at the ground's height and keeping its strength. One with nowhere to burn
## is left out. NOT ON A SEATED TOWN'S SITE: nothing solid is asked here -- the buildings are built from these fires'
## clearances, so asking `boxes()` would ask itself -- and a town site, its flat and the blend round it, is read from the
## towns instead.
static func _fires_on_the_ground(island: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var nothing_solid: Array[Dictionary] = []
	var towns: Array[Dictionary] = TownCatalogue.towns()
	for fire in island:
		var from: Vector3 = fire["position"]
		var found := Vector3.INF
		var ring: float = 0.0
		while ring <= FIRE_SEARCH and found == Vector3.INF:
			var count: int = maxi(1, ceili(TAU * ring / FIRE_ROOM))
			for k in range(count):
				var angle: float = TAU * float(k) / float(count)
				var at := Vector3(from.x + cos(angle) * ring, 0.0, from.z + sin(angle) * ring)
				at.y = ground_height(at)
				if can_burn(nothing_solid, at) and not _on_a_town_site(towns, at):
					found = at
					break
			ring += FIRE_ROOM
		if found != Vector3.INF:
			out.append({"position": found, "strength": fire["strength"]})
	return out


## Whether a point is on a seated town's site: inside its flat or the blend round it, where a fire would stand in the
## town's streets or on the slope under its edge. False on the island, whose towns carry no site.
static func _on_a_town_site(towns: Array[Dictionary], at: Vector3) -> bool:
	for town in towns:
		var site: Dictionary = town.get("site", {})
		if site.is_empty():
			continue
		var centre: Vector3 = town["centre"]
		if Vector2(at.x - centre.x, at.z - centre.z).length() < float(site["r"]) + float(site["margin"]):
			return true
	return false


## Aircraft are spawned ALREADY FLYING, along their own nose.
##
## The nose is the body's -Z turned by the yaw, which is (-sin, 0, -cos) -- NOT
## (sin, 0, -cos). That sign was wrong, and it is invisible for a vehicle spawned facing
## along an axis, because the X term is zero there. The one aeroplane in the table on a
## diagonal was spawned flying ninety degrees sideways: no airspeed along the nose means
## no lift, so it mushed straight into the sea while every test still passed.
static func nose_from_yaw(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func _air(kind: int, at: Vector3, yaw: float) -> Dictionary:
	return {"kind": kind, "position": at, "yaw": yaw,
		"velocity": nose_from_yaw(yaw) * cruise_for(kind)}


## A ship already making way. Not `_air`, which launches an aeroplane at its own flying
## speed: a hull has no stall and this is simply where it starts from.
static func _moving(kind: int, at: Vector3, yaw: float, speed: float) -> Dictionary:
	return {"kind": kind, "position": at, "yaw": yaw,
		"velocity": nose_from_yaw(yaw) * speed}


## WHERE A ROAD MACHINE WITH NO PLACE OF ITS OWN IS PUT ON THE GENERATED GROUND, by kind, in turn: on inner's central avenue
## (its street along z through the centre, 32 m wide), offsets from inner's centre, the y its island height over the street.
## The cars a few blocks up it; the tanks near the end of the avenue inside the flat (a seated street ends at the last
## crossing inside it, 480 m out for inner), pointing out of town as the island's point away from the city.
## WHERE A HELICOPTER, CHINOOK OR LOW POD WITH NO PLACE IS PUT ON THE GENERATED GROUND, in turn, on the first runway's apron:
## (across, along) from its middle in its frame, across the strip from the gliders (which stand at -44.5 across) and short of
## the tower (+77.5 across, at the middle), 60 m apart so a Chinook's rotors clear its neighbour's.
const APRON_SPOTS: Array[Vector2] = [Vector2(62.5, -330.0), Vector2(62.5, -270.0), Vector2(62.5, -210.0),
	Vector2(62.5, -150.0), Vector2(62.5, -90.0), Vector2(62.5, -30.0)]
## A POD PARKED HIGHER THAN THIS, metres, is looking down on the ground rather than resting on it: the island's one over an
## inland range stands at 700 m, its others at 26 m.
const RANGE_POD_FROM: float = 100.0

const ROAD_MACHINE_SPOTS := {
	Sim.Kind.CAR: [Vector3(6.0, 0.7, 288.0), Vector3(-6.0, 0.7, 288.0)],
	Sim.Kind.TANK: [Vector3(-6.0, 1.3, 456.0), Vector3(6.0, 1.3, 468.0)],
}


static func _parked(kind: int, at: Vector3, yaw: float) -> Dictionary:
	return {"kind": kind, "position": at, "yaw": yaw, "velocity": Vector3.ZERO}


## A spawn marked as standing on a PLACE -- &"runway" or &"town" -- that its position was worked out from, which the
## generated ground's arm keeps as it is.
static func _placed(spawn: Dictionary, place: StringName) -> Dictionary:
	spawn["place"] = place
	return spawn


## A spawn with a NAME another spawn can refer to -- the carrier an aeroplane is parked on -- which the level records as the
## entity it became (`FlightLevel.spawned_entity`).
static func _named(spawn: Dictionary, name: StringName) -> Dictionary:
	spawn["name"] = name
	return spawn


## A CRAFT PARKED ON A SHIP'S DECK at its CarrierPlan.PARKED row: over the row's spot in the ship spawn's own frame, at the
## deck's height and half a metre over the craft's own half-height, turned with the ship, and carried at the ship's
## velocity. Placed &"carrier" and naming the ship it is on, so every branch that reads "faster than 1 m/s" as "launched"
## asks the place instead. {} for a kind with no row.
static func parked_on(ship: Dictionary, kind: int) -> Dictionary:
	var row: Dictionary = {}
	for parked in CarrierPlan.PARKED:
		if String(parked["name"]) == Sim.kind_name(kind):
			row = parked
	if row.is_empty():
		return {}
	var at: Vector2 = row["at"]
	var ship_yaw: float = float(ship["yaw"])
	var half_high: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	var deck := Transform3D(Basis(Vector3.UP, ship_yaw), ship["position"] as Vector3)
	var spawn: Dictionary = _placed({"kind": kind, "position": deck * Vector3(at.x, CarrierPlan.deck_height() + half_high + 0.5, at.y),
		"yaw": ship_yaw + float(row["yaw"]), "velocity": ship["velocity"]}, &"carrier")
	spawn["on"] = ship["name"]
	return spawn


## A POINT IN A TOWN, by the town's name: its centre on the world it stands on (`TownCatalogue.towns`) and an offset from it,
## the offset's y the height over the town's ground. The island's towns stand at 0, so there it is the island's point.
static func _in_town(name: StringName, offset: Vector3) -> Vector3:
	for town in TownCatalogue.towns():
		if town["name"] == name:
			return (town["centre"] as Vector3) + offset
	push_warning("[spawns] there is no town called %s on this world; the spawn stands at the middle" % name)
	return offset


## ---- what the generator must leave alone ---------------------------------------------

## The gate corridors and the room around every spawn, as boxes.
## ---- the air ----------------------------------------------------------------------------

## THE WIND, at the surface, in metres a second: NONE, since 2026-09-14, when the user asked
## for it gone. Still a constant rather than deleted, because every peer is told it and the
## smoke, the cloud markers, the fire front and the engine sound all read it -- so zero here
## is still air everywhere at once, and nothing else has to know.
##
## It was six metres a second from the west-north-west, half again at a kilometre. What that
## cost, measured with `tests/sinking_probe.gd` over three minutes of the whole fleet: two
## light aeroplanes in formation flew into a ridge at 434 and 442 m and a leader grazed the same
## ridge at 7 m. The same run in still air hit nothing.
##
## And the grass: its gust bands roll at the speed of the vector they are handed, so on
## `SWELL_HEADING` they drift at one metre a second where the wind moved them at six.
const WIND := Vector3.ZERO
## How much more wind there is per kilometre of height, as a fraction of the surface wind.
const WIND_SHEAR: float = 0.0
## WHICH WAY THE SEA'S SWELL RUNS AND THE BANDS ROLL ACROSS THE GRASS, as a flat unit vector,
## and nothing else: it pushes no aeroplane, leans no smoke and moves no air.
##
## Its own number because those shaders need a DIRECTION and normalise what they are handed,
## and a zero vector normalised is NaN in a shader. It is the old wind's heading, so the
## scenery lies the way it did.
const SWELL_HEADING := Vector2(0.9010, -0.4338)

## THE WEATHER THE SHIPS SAIL IN, as `CockpitWorld.set_weather` takes it: a wind wandering between 5 and 12 m/s, veering
## up to 20 degrees either side, from the side the swell comes from -- so the sea's painted chop and the brigs' wind agree.
## A compass angle the wind comes FROM, in radians, off SWELL_HEADING, which the swell runs along: the wind blows along it,
## so it comes from its reverse, (sin a, -cos a) = -SWELL_HEADING. Aircraft do not feel it (the user, 2026-09-15; the level
## says so with `Sim.set_wind_on_wings`).
static func weather() -> Dictionary:
	return {"from": atan2(-SWELL_HEADING.x, SWELL_HEADING.y), "low": 5.0, "high": 12.0, "veer": 0.35, "seed": 7}

## WHERE THE AIR GOES UP, as `{position, radius, strength, top}`.
##
## In this file with the scenery, and for exactly the same reason: the ground is what makes
## a thermal. Sun on a rock face, sun on a city, a slope that faces the afternoon -- so the
## columns are generated FROM the terrain features rather than scattered independently of
## them, which means the lift is where a glider pilot would look for it.
##
## NOT REPLICATED, like the mountains: every peer builds the same list and the simulation is
## never told about it again. See the note at the top of this file.
##
## THREE KINDS OF LIFT, and they are different to fly:
##
##   THE CITIES are the strongest and the most reliable. Concrete on a hot afternoon is the
##   classic thermal source, and there is one over each of them.
##
##   THE INLAND RANGES throw the tall ones. A mountain is a big collector of sun, and the
##   column over it goes higher than anything else on the island.
##
##   THE RING is ridge lift rather than thermal: wide, weak, and standing over the windward
##   face of the peaks. It does not go very high and it never stops, which is what makes it
##   the way home when the thermals have shut down.
const THERMAL_TOP: float = 1500.0
const RIDGE_TOP: float = 700.0


static func lift_zones() -> Array[Dictionary]:
	if _field != null:
		if _lift_of != _field:
			_lift = _lift_zones_on_the_ground()
			_lift_of = _field
		return _lift
	var out: Array[Dictionary] = []
	# OVER THE TOWNS. Strong, narrow and high.
	for town in TownCatalogue.towns():
		if not bool(town["thermal"]):
			continue
		out.append({"position": (town["centre"] as Vector3) + Vector3(120.0, 0.0, -80.0),
			"radius": 260.0, "strength": 4.4, "top": THERMAL_TOP})
	# AND BESIDE THE INLAND RANGES: the tallest columns on the island, one per range, rising off the valley floor at the
	# range's foot on the side facing the middle of the island. It stood 500 m off the range's middle, which put its ring
	# -- drawn on the ground under it (LiftYard) -- up the flank once the ranges became real slopes, where it read exactly
	# as a switchback road (2026-09-18 after pictures); at 1.2 feet out from the ridge it lies on the grass.
	for r in range(INLAND_RANGES.size()):
		var bearing: float = deg_to_rad(MountainRanges.INLAND_BEARINGS[r])
		var aside := Vector3(-sin(bearing), 0.0, cos(bearing))
		if aside.dot(-INLAND_RANGES[r]) < 0.0:
			aside = -aside
		out.append({"position": INLAND_RANGES[r] + aside * MountainRanges.inland_foot(r) * 1.2,
			"radius": 320.0, "strength": 5.0, "top": THERMAL_TOP + 300.0})
	# A SCATTER OVER THE OPEN GROUND, so that crossing the middle of the island is a series
	# of decisions rather than a glide with nothing in it. Spread by the same hash the
	# waypoints use, so they do not read as a grid from the air.
	for i in range(14):
		var at := _spread(i, 1867, WORLD_HALF * 0.72)
		at.y = 0.0
		out.append({"position": at, "radius": 200.0 + _noise(i, 41) * 130.0,
			"strength": 2.6 + _noise(i, 43) * 2.0, "top": THERMAL_TOP})
	# EVERY COLUMN OFF THE ROCK, so the ring LiftYard lays on the ground under it lies on grass: twelve of these stood on
	# a range's foot once the mountains became slopes, and a ring draped up a flank reads as a road climbing it (the
	# 2026-09-18 after pictures, twice). Each is moved to the nearest place its whole ring is clear.
	for k in range(out.size()):
		out[k] = _lift_off_the_rock(out[k])
	# AND THE RIDGE, on the windward side of the ring. Wide, weak, low, and always there --
	# WHEN THERE IS A WIND, because ridge lift is the wind pushed up a slope. There has been
	# none since 2026-09-14, and a zero wind normalised is no direction at all.
	if WIND.length() < 0.01:
		return out
	var into: Vector3 = -WIND.normalized()
	for top in MountainRanges.ring_crests():
		# THE WINDWARD FACE AND NOWHERE ELSE. Ridge lift is air being pushed UP a slope by
		# the wind, so it stands on the side of the ring the wind is blowing into and there
		# is nothing at all on the other one -- which is the lee, where a glider gets sink.
		if top.normalized().dot(into) < 0.35:
			continue
		out.append({"position": top - into * 260.0,
			"radius": 420.0, "strength": 2.2, "top": RIDGE_TOP})
	return out


## HOW FAR A COLUMN OF RISING AIR IS LOOKED FOR OFF THE ROCK, and in what steps, metres.
const LIFT_OFF_ROCK_STEP: float = 90.0
const LIFT_OFF_ROCK_REACH: float = 2000.0


## A ZONE WHOSE RING WOULD LIE ON THE ISLAND'S MOUNTAINS, MOVED TO THE NEAREST PLACE IT DOES NOT: searched in rings
## LIFT_OFF_ROCK_STEP apart out to LIFT_OFF_ROCK_REACH, a candidate every step round each, first found in the same order on
## every peer, as `_fires_on_the_ground` searches. The zone as it was where its ring is already clear, or where nothing is.
static func _lift_off_the_rock(zone: Dictionary) -> Dictionary:
	var from: Vector3 = zone["position"]
	var r: float = float(zone["radius"])
	if rock_clears(from, Vector3(r, 0.0, r)):
		return zone
	var ring: float = LIFT_OFF_ROCK_STEP
	while ring <= LIFT_OFF_ROCK_REACH:
		var count: int = maxi(1, ceili(TAU * ring / LIFT_OFF_ROCK_STEP))
		for k in range(count):
			var angle: float = TAU * float(k) / float(count)
			var at := Vector3(from.x + cos(angle) * ring, from.y, from.z + sin(angle) * ring)
			if rock_clears(at, Vector3(r, 0.0, r)):
				var moved: Dictionary = zone.duplicate()
				moved["position"] = at
				# ITS CLOUD STAYS THE CLOUD IT WAS: LiftYard.cloud_type hashes a zone's place into its kind, and moving twelve
				# zones re-rolled the island's clouds into three kinds of four (tests/air.gd). The kind is the place's it came from.
				moved["cloud_seed_at"] = from
				return moved
		ring += LIFT_OFF_ROCK_STEP
	return zone


## RISING AIR ON THE GENERATED GROUND (increment B3, agreed with cockpit-mist, 2026-09-15). The island's zones stand on
## its slab at y = 0 over typed ranges; here every zone is BASED ON THE GROUND UNDER IT -- `position.y` is
## `ground_height` there -- and its `top` is a world y, because the simulation keeps a column's top and never its base
## (`CockpitWorld.add_lift_zone`, `taper`) and `LiftYard.cloud_lumps` puts the cloud's one base at `top`:
##
##   ONE THERMAL OVER EACH SEATED TOWN that has one, off its seated centre by the island's offset, as strong and as tall.
##
##   A SCATTER over the land's valley floors and slopes: tried by the island's hash across the land's reach, and kept
##   only on dry land, outside every seated town's site (the town has its own), at least THERMAL_UNDER_THE_TOPS under
##   the highest ground within THERMAL_TOPS_ROOM (sampled every THERMAL_TOPS_STEP: a summit is not a 16 m feature, and
##   at 16 m this test alone took 587 ms of a 40-try answer), so no zone stands on a summit or a plateau's top, and
##   touching no zone already kept, so two clouds are never stacked on one spot (the first answer had two 121 m apart).
##
##   THE CLOUD CLEARS THE ROCK, AND THAT WINS (cockpit-mist): a column's top is lifted until the cloud's base clears the
##   highest surface within the widest cloud's reach -- the zone's radius x `LiftYard.CLOUD_SPREAD` x the widest
##   `CloudTuning.TYPES` spread -- by CLOUD_ROCK_CLEAR, the ground a 16 m sample can miss (measured: 11.8 m at the worst
##   under today's zones' reach, against a 4 m grid). A top over a nearby summit is
##   a thermal over a sunlit slope going higher than the ridge, which is natural; a cloud base inside a mountainside
##   is a clipping bug. Nothing of a cloud is drawn under its base (both lump shaders and the fog cut it there), so
##   there is no skirt to clear. A zone no column up to THERMAL_TALLEST over its ground clears is dropped; a town's
##   thermal says so by name.
##
## REJECTED: a "sunny slope" filter. The world has no one sun: the daylight presets put it from 30.6 to 285 degrees
## round (daylight_tuning.gd), so a slope sunny at one time of day is in shade at another. And no ridge lift: there
## has been no wind since 2026-09-14.
const GROUND_THERMAL_TRIES: int = 40
const THERMAL_TOPS_ROOM: float = 1500.0
const THERMAL_UNDER_THE_TOPS: float = 150.0
const THERMAL_TOPS_STEP: float = 64.0
const CLOUD_ROCK_CLEAR: float = 30.0
const THERMAL_TALLEST: float = 3000.0
## The generated ground the zones were last worked out for, and the zones: the ground does not change under a level.
static var _lift_of: Object = null
static var _lift: Array[Dictionary] = []


static func _lift_zones_on_the_ground() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var towns: Array[Dictionary] = TownCatalogue.towns()
	# A LEVEL THAT LAYS ITS OWN THERMALS HAS THOSE, first and in its file's order, and the towns' after them: no scatter. See
	# `_level_lift`.
	var chart: LevelChart = ChartDrawer.chart(_level) if _level != "" else null
	if chart != null and not chart.lift.is_empty():
		return _level_lift(chart)
	for town in towns:
		if not bool(town["thermal"]):
			continue
		var zone: Dictionary = grounded_zone((town["centre"] as Vector3) + Vector3(120.0, 0.0, -80.0), 260.0, 4.4)
		if zone.is_empty():
			push_warning("[terrain] the thermal over %s is not placed: no column up to %.0f m clears the ground under its cloud" % [
				town["name"], THERMAL_TALLEST])
			continue
		out.append(zone)
	var land: float = land_reach()
	for i in range(GROUND_THERMAL_TRIES):
		var at := _spread(i, 1867, land * 0.72)
		if water_height(at) != -INF or _in_a_seated_town(towns, at):
			continue
		at.y = ground_height(at)
		if _highest_within(at, THERMAL_TOPS_ROOM, THERMAL_TOPS_STEP) - at.y < THERMAL_UNDER_THE_TOPS:
			continue
		var radius: float = 200.0 + _noise(i, 41) * 130.0
		if _touches_a_zone(out, at, radius):
			continue
		var zone: Dictionary = grounded_zone(at, radius, 2.6 + _noise(i, 43) * 2.0)
		if not zone.is_empty():
			out.append(zone)
	return out


## A LEVEL'S OWN THERMALS (`LevelChart.lift`; lane/gliderlevel, 2026-09-19: "we'll need lift zones that the gliders can
## fly to"), each stood on the ground by `grounded_zone` exactly as the scatter is -- based on the ground, its top
## THERMAL_TOP over it or higher until its cloud clears the rock -- and carrying its `name`. NOTHING ELSE: not the ground's
## hashed scatter, and not the towns' own thermals either, which are 260 m at 4.4 m/s -- under what a circling glider sinks
## at (`SoaringPilot.CIRCLE_SINK`), so a level for gliders that quietly added them would offer thermals nothing can climb
## in. A level that wants one over its town lays one. The FIRST zone is the level's first, which is where an arrival is
## launched: a level zone no column clears is left out with a warning in its name, and the level's own suite fails on the
## count.
##
## REJECTED: the level's zones on top of the ground's scatter. The scatter is a hash of the land's reach, so a zone laid
## as a hop between two of the level's could land on a ridge or in a gap the level designed as a glide; a level that
## says where its lift is should have that lift and no other.
static func _level_lift(chart: LevelChart) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for laid in chart.lift:
		var at: Vector2 = laid["at"]
		var zone: Dictionary = grounded_zone(Vector3(at.x, 0.0, at.y), float(laid["radius"]), float(laid["strength"]))
		if zone.is_empty():
			push_warning("[terrain] the level's thermal '%s' is not placed: no column up to %.0f m clears the ground under its cloud" % [
				laid["name"], THERMAL_TALLEST])
			continue
		zone["name"] = laid["name"]
		out.append(zone)
	return out


## A THERMAL BASED ON THE GROUND at `at`'s x and z, THERMAL_TOP tall or taller until its cloud clears the rock; {} if no
## column up to THERMAL_TALLEST does. See above. Public so terrain_level can hand it a spot beside a peak, where the column
## must rise: no zone on today's alpine world needs the raise, and a rule nothing needs is a rule nothing tests.
static func grounded_zone(at: Vector3, radius: float, strength: float) -> Dictionary:
	var base := Vector3(at.x, ground_height(at), at.z)
	var top: float = maxf(base.y + THERMAL_TOP, highest_near(base, radius * widest_cloud_reach()) + CLOUD_ROCK_CLEAR)
	if top - base.y > THERMAL_TALLEST:
		return {}
	return {"position": base, "radius": radius, "strength": strength, "top": top}


## HOW FAR A CLOUD SPREADS, in radii of its zone, for the widest kind: `LiftYard.CLOUD_SPREAD` x the largest spread in
## `CloudTuning.TYPES` ("spread", 1.2, on 2026-09-15: 2.52 radii). Asked of both, never typed here.
static func widest_cloud_reach() -> float:
	var widest: float = 0.0
	for kind in CloudTuning.TYPES:
		widest = maxf(widest, float(kind["spread"]))
	return LiftYard.CLOUD_SPREAD * widest


## THE HIGHEST SURFACE WITHIN `room` OF A POINT sampled every `step` metres: `highest_near` at a spacing of the caller's.
static func _highest_within(at: Vector3, room: float, step: float) -> float:
	var texels: int = maxi(1, ceili(2.0 * room / step))
	var high: float = -INF
	for h in surface_heights(Vector2(at.x - room, at.z - room), texels, 2.0 * room / float(texels)):
		high = maxf(high, h)
	return high


static func _touches_a_zone(zones: Array[Dictionary], at: Vector3, radius: float) -> bool:
	for zone in zones:
		var other: Vector3 = zone["position"]
		if Vector2(at.x - other.x, at.z - other.z).length() < radius + float(zone["radius"]):
			return true
	return false


static func _in_a_seated_town(towns: Array[Dictionary], at: Vector3) -> bool:
	for town in towns:
		var site: Dictionary = town.get("site", {})
		var centre: Vector3 = town["centre"]
		if Vector2(at.x - centre.x, at.z - centre.z).length() <= float(site.get("r", 0.0)) + float(site.get("margin", 0.0)):
			return true
	return false


## How much room a fire gets to itself. A fire inside a mountain is the same class of
## mistake as an aeroplane inside one, and it is worse in one way: from the air the smoke
## comes out of the rock and there is nothing to drop water on.
##
## Wide enough for the fire, the column and the run: a tanker arrives at forty-five metres a
## second and needs the approach clear, not merely the fire.
const FIRE_CLEAR := Vector3(220.0, 200.0, 220.0)
## How much ground round a hand-built place's boxes the generator leaves alone, metres: an apron's worth.
const AUTHORED_ROOM: float = 150.0


static func _clearances() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spawn in spawns():
		out.append({"position": spawn["position"], "half_extents": SPAWN_CLEAR, "why": &"spawn"})
	# AND EVERY FIRE, for the same reason -- see FIRE_CLEAR.
	for fire in fires():
		out.append({"position": (fire["position"] as Vector3) + Vector3(0.0, 60.0, 0.0),
			"half_extents": FIRE_CLEAR, "why": &"fire"})
	# THE RUNWAY gets the largest clearance in the world, and it needs it: an aeroplane on
	# short finals is low, slow and committed, so what has to be empty is not the strip but
	# the approach to both ends of it. Every runway the world has: the island's one, or one on each generated strip.
	for frame in runways():
		var length: float = frame["length"]
		# A RUNWAY THAT NAMES ITS PROTECTION keeps exactly that: its object free area down both sides and its protection
		# zones past both ends, as one box turned to it (see Airfield.PROTECTION). The island's strips keep their square.
		if frame.has("protection"):
			var keep: Dictionary = frame["protection"]
			var past: float = maxf(float(keep["ofa_beyond_end"]), float(keep["rpz_from_end"]) + float(keep["rpz_length"]))
			var half_along: float = length * 0.5 + past
			var half_across: float = maxf(float(keep["ofa_half_width"]), float(keep["rpz_outer_half"]))
			var along_axis: Vector3 = (frame["along"] as Vector3).abs()
			var across_axis: Vector3 = (frame["across"] as Vector3).abs()
			var half: Vector3 = along_axis * half_along + across_axis * half_across
			out.append({"position": (frame["centre"] as Vector3) + Vector3(0.0, 120.0, 0.0),
				"half_extents": Vector3(half.x, 260.0, half.z), "why": &"runway", "place": String(frame.get("field", ""))})
			continue
		for end in [-1.0, 1.0]:
			out.append({
				"position": (frame["centre"] as Vector3) + (frame["along"] as Vector3)
					* (end * length * 0.7) + Vector3(0.0, 120.0, 0.0),
				"half_extents": Vector3(length * 0.9, 260.0, length * 0.9), "why": &"runway"})
	# EVERY AIR BASE, from its pavement to its hangars' backs and its own taxiway obstacle clearance round that: no town, wood
	# or mountain is generated onto a taxiway or into a wingtip. On either world; a base that did not fit is not laid and
	# keeps nothing clear.
	# Each slab and wall of it grown by that clearance (`AirbasePlan.lay`'s `keep_clear`), never the hull round them all.
	for base in AirbasePlan.bases():
		for box in base["keep_clear"]:
			out.append({"position": (box as AABB).get_center(), "half_extents": (box as AABB).size * 0.5, "why": &"airbase",
				"place": String(base["id"])})
	# ON THE GENERATED GROUND, THE SPAWNS, THE FIRES, THE RUNWAYS' APPROACHES AND THE AIR BASES ONLY: the railway, the gates
	# and the hand-built places are the island's.
	if _field != null:
		return out
	# THE RAILWAY gets a corridor of its own, for the same reason the gates do: scenery
	# generated on top of it is a mountain in the four-foot, and a train has no way round.
	for at in rail_points(RAIL_KEEP_STEP):
		out.append({"position": at + Vector3(0.0, 30.0, 0.0),
			"half_extents": RAIL_CLEAR, "why": &"rail"})
	for gate in _gate_definitions():
		var across: Vector3 = gate[1]
		# HORIZONTAL only. Vector3.ONE - across.abs() keeps the Y, which made every gate
		# corridor as tall as it was long -- a 220 m column of protected air that deleted
		# six mountains off the ring before anybody noticed the box count had dropped.
		var through: Vector3 = Vector3(1.0, 0.0, 1.0) - across.abs()
		# Wide as the arch and long enough that nothing generates in the approach either.
		out.append({
			"position": (gate[0] as Vector3) + Vector3(0.0, GATE_HEIGHT * 0.6, 0.0),
			"half_extents": across.abs() * (GATE_OPENING * 0.5 + 40.0)
				+ through * 160.0 + Vector3(0.0, GATE_HEIGHT * 0.6, 0.0),
			"why": &"gate",
		})
	# AND EVERY HAND-BUILT PLACE, so no mountain, town or wood is generated into an airfield. See AuthoredChunks.
	out.append_array(AuthoredChunks.clearances(AuthoredChunks.catalogue(), AUTHORED_ROOM))
	return out


static func _clear(clear: Array[Dictionary], at: Vector3, half: Vector3) -> bool:
	return is_clear(clear, at, half)


## WHAT THE GENERATOR MUST LEAVE ALONE, for anything else that is laid on the ground: the spawns,
## the fires, the runway's approaches, the railway and the gates, as `{position, half_extents, why}`.
## `why` is &"spawn", &"fire", &"runway", &"rail", &"gate", &"authored" or &"airbase", so a caller can let one kind through: a
## road between towns crosses the railway at a level crossing, and a building may not stand on it.
## The same list `boxes()` keeps its mountains and towers out of, so a wood and a mountain are kept
## off a runway approach by one definition of where the approach is.
static func clearances() -> Array[Dictionary]:
	return _clearances()


## EVERYWHERE A THING STANDING ON THE GROUND MAY NOT STAND: every clearance, and every solid box.
##
## For scenery that is only a picture -- a forest -- and has to keep out of what is solid as well as
## what is kept clear: a tree growing out of a tower or a hillside is not a collision, it is a tree
## drawn inside a wall. Roads between towns join this list as yawed boxes (see `is_clear`) when they
## exist. `solid` IS `boxes()`, HANDED IN: the level has just built it for the simulation, and it is
## four hundred and sixty-three boxes a time -- a probe that built it every frame cost 11 ms a frame. `roads` IS
## `roads(solid)`, HANDED IN TOO, and for a bigger reason: building the roads is most of a level's boot -- 1,098 ms
## headless on the double editor and 272 ms windowed on the stock one (`tests/streaming_probe.gd`, 2026-09-14) -- and
## until then the level built them twice, once to draw and once in here for the woods.
## THE ROADS BETWEEN TOWNS, laid against `solid` -- the list the level already built. See `TownPlan.roads`.
static func roads(solid: Array[Dictionary]) -> Array[Dictionary]:
	# ON THE GENERATED GROUND, the roads between its seated towns and its airfields (increment B5): see
	# TownPlan.roads_on_the_ground.
	if _field != null:
		return TownPlan.roads_on_the_ground()
	return TownPlan.roads(solid, clearances())


static func ground_keepouts(solid: Array[Dictionary], roads: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = clearances()
	out.append_array(solid)
	# AND EVERY ROAD BETWEEN TOWNS, as a yawed corridor: a tree in the road is a tree drawn on the tarmac.
	out.append_array(TownPlan.road_keepouts(roads))
	return out


## WHETHER A BOX CENTRED `at` WITH HALF-SIZE `half` STANDS CLEAR OF THE ISLAND'S MOUNTAINS: the highest rock over its
## footprint, from the pyramid the autopilots' leg tests ask (height_pyramid.hpp), stands no higher than the box's bottom,
## or than the ground where the box reaches below it -- so a car at the slab is clear only where there is no rock at all,
## and an aeroplane at 300 m wherever the rock under it is lower. Never too generous: the pyramid is never under the rock,
## and may call a clear box blocked. Always clear with no mountains -- the generated ground, whose relief is asked of it
## directly -- since the rock the island's boxes used to be is no longer in `boxes()` for `is_clear` to see.
static func rock_clears(at: Vector3, half: Vector3) -> bool:
	var rock: Object = mountains()
	if rock == null:
		return true
	var top: float = float(rock.call("highest_over", at.x - half.x, at.z - half.z, at.x + half.x, at.z + half.z))
	return top <= maxf(at.y - half.y, 0.0)


## A deterministic value in 0..1 from two integers, for anything else generated from the ground the
## way the island is: the same answer on every machine. See `_noise`, which this is.
static func hash01(seed_value: int, salt: int) -> float:
	return _noise(seed_value, salt)


## WHETHER A BOX CENTRED `at` WITH HALF-SIZE `half` TOUCHES NONE OF `keep`.
##
## A record may carry a `yaw`, in radians about the vertical, for something that does not run
## along an axis -- a road between two towns. Absent means axis-aligned, and it is read with its
## default right here, not assumed by the caller. A yawed record is tested in its own frame with the
## query widened to its largest horizontal half-size, which can call a box near a corner touching
## when it is not, and never the other way: for a keep-out, "too careful" is the safe direction.
static func is_clear(keep: Array[Dictionary], at: Vector3, half: Vector3) -> bool:
	for box in keep:
		var to: Vector3 = at - (box["position"] as Vector3)
		var sum: Vector3 = half + (box["half_extents"] as Vector3)
		var yaw: float = float(box.get("yaw", 0.0))
		if yaw != 0.0:
			var spread: float = maxf(half.x, half.z)
			sum = Vector3(spread, half.y, spread) + (box["half_extents"] as Vector3)
			to = to.rotated(Vector3.UP, -yaw)
		if absf(to.x) < sum.x and absf(to.y) < sum.y and absf(to.z) < sum.z:
			return false
	return true


## ---- the pieces --------------------------------------------------------------------

## ---- the mountains as ranges (cockpit-mountains, 2026-09-18) ------------------------------------------------------

## HOW FAR ROUND A TOWN THE ROCK STAYS DOWN, past its radius, metres: a street's width and a verge, so the last block
## of a town does not back onto a cliff.
const TOWN_ROCK_ROOM: float = 120.0

## The island's `MountainRange`, built once a process: see `mountains`. Built under `_mountains_lock`, because the first
## to ask may be a worker -- the mist bakes its chart on one -- and two workers asking at once built it twice.
static var _mountains: Object = null
static var _mountains_lock := Mutex.new()


## THE ISLAND'S MOUNTAINS: one `MountainRange` (ashiato-gd/src/cockpit/mountain_range.hpp) configured from
## `MountainRanges`' ridges and every keep-out below, whose triangles are both what `MountainView` draws and what the
## simulation collides with. Null on the generated ground, whose mountains are the ground itself, and in a build with no
## such class. Built on first asking and kept: it is a function of this file's constants and `MountainRanges`', which do
## not change while the game runs.
static func mountains() -> Object:
	if _field != null:
		return _rock_of_the_level()
	if not ClassDB.class_exists(&"MountainRange"):
		return null
	_mountains_lock.lock()
	if _mountains == null:
		var range: Object = ClassDB.instantiate(&"MountainRange")
		var problems: PackedStringArray = range.call("configure", mountain_values())
		if not problems.is_empty():
			push_error("[terrain] the mountains would not configure: %s" % ", ".join(problems))
		_mountains = range
	_mountains_lock.unlock()
	return _mountains


## THE ISLAND'S KIND OF MOUNTAINS ON A GENERATED GROUND, from the level's own file (lane/testfield, 2026-09-19), or null
## for a level that names none. The same `MountainRange` the island's are, so the same faceted, snow-capped rock, drawn
## by the same `MountainView` and handed to the simulation by the same `Sim.set_mountains`. Its keep-outs are the
## island's -- every clearance, town and wood -- and a staircase under every final of the level's own runways
## (`_final_keepouts`), so no range the file lays can stand in an approach.
static func _rock_of_the_level() -> Object:
	if _level_ranges.is_empty() or _raising or not ClassDB.class_exists(&"MountainRange"):
		return null
	_mountains_lock.lock()
	if _level_rock_of != _field:
		_raising = true
		var rock: Object = ClassDB.instantiate(&"MountainRange")
		var lists: Dictionary = mountain_keepout_lists()
		var keep: PackedInt32Array = lists["keepouts"]
		var margins: PackedInt32Array = lists["margins"]
		var finals: PackedInt32Array = _final_keepouts()
		keep.append_array(finals)
		for f in range(finals.size() / 5):
			margins.append(-1)
		# AND THE CORRIDOR OF EVERY RIVER, so no rock stands in the floor the walls are built round. Without these the
		# two walls' feet meet in the middle and the canyon is a ridge with a river under it.
		var corridors: PackedInt32Array = Watercourse.keepouts_for(_level_rivers, _field)
		keep.append_array(corridors)
		for c in range(corridors.size() / 5):
			margins.append(-1)
		# THE LEVEL'S OWN QUALITY, and the tile's size held constant as it moves (`MountainRanges.tile_quads_for`):
		# a tile is a draw call and a culling unit, and how much world it holds should not change with the poly count.
		var problems: PackedStringArray = rock.call("configure", {"spacing": _level_rock_spacing,
			"tile_quads": MountainRanges.tile_quads_for(_level_rock_spacing), "ranges": _level_ranges,
			"keepouts": keep, "keepout_margins": margins})
		if not problems.is_empty():
			push_error("[terrain] the level's mountains would not configure: %s" % ", ".join(problems))
		_level_rock = rock
		_level_rock_of = _field
		_raising = false
	_mountains_lock.unlock()
	return _level_rock


## UNDER EVERY FINAL OF THE LEVEL'S OWN RUNWAYS, a staircase of keep-outs, five ints each as `mountain_keepouts`: from each
## pad's funnels (`Airfield.pads_for`), FINAL_STEP long, FINAL_SIDE wider than the funnel either side, each floored at the
## pad's level plus the 34:1 rise at its near end, and every pad's own rectangle at its level. The rock rises from a floor
## no steeper than fifty degrees, so a step's rock stands under the 34:1 line wherever the funnel is.
static func _final_keepouts() -> PackedInt32Array:
	var out := PackedInt32Array()
	var levels: Array = (_field.call("catalogue") as Dictionary).get("pads", [])
	var pads: Array[Dictionary] = Airfield.pads_for(_level)
	for p in range(mini(pads.size(), levels.size())):
		var level: int = int(levels[p]["level"]) / 32
		var rect: Array = pads[p]["rect"]
		out.append_array([int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]), level])
		for f in pads[p]["funnels"]:
			var x: int = int(f[0])
			var z: int = int(f[1])
			var dir: int = int(f[2])
			var half: int = int(f[4]) + FINAL_SIDE
			var along := Vector2i([1, 0, -1, 0][dir], [0, 1, 0, -1][dir])
			var across := Vector2i(absi(along.y), absi(along.x))
			for s in range(0, int(f[3]), FINAL_STEP):
				var a: Vector2i = Vector2i(x, z) + along * s - across * half
				var b: Vector2i = Vector2i(x, z) + along * (s + FINAL_STEP) + across * half
				out.append_array([mini(a.x, b.x), mini(a.y, b.y), maxi(a.x, b.x), maxi(a.y, b.y),
					level + floori(float(s) * GROUND_TICKS_PER_METRE / 34.0)])
	return out


## UNDER THE IN-USE FINAL OF EVERY ISLAND FIELD THAT NAMES NO PROTECTION OF ITS OWN, the same staircase a level's finals get
## (`_final_keepouts`: FINAL_STEP long, `Airfield.FINAL_HALF_WIDTH` and FINAL_SIDE wide either side, each step floored at the
## threshold's level plus the 34:1 rise at its near end, so the rock is cut down to a valley that widens at 50 degrees
## and not a trench). Cape's runways name their protection and keep their own box; the island's two 900 m strips kept only
## the 0.9-length square at each end, and `island_strip`'s final ran 2.6 km up x = -900 between the second lone mountain and the
## first inland range, 38 m and 5 m through the glide path either side of a centreline that cleared by 44 (`tests/airport.gd`,
## lane/throughrock, 2026-09-19). THIS IS A WORKAROUND for a strip being offered an instrument approach it should not have:
## see `todo/throughrock--who-is-sent-to-which-field.md`, and when that lands this may go. Only the end in
## use is kept: a landing from the other end meets rock, as the todo says.
static func _island_final_keepouts() -> PackedInt32Array:
	var out := PackedInt32Array()
	for field in Airfield.here():
		var frame: Dictionary = field["frame"]
		if frame.has("protection"):
			continue
		var end: String = String(field["in_use"])
		var along: Vector3 = frame["along"]
		var away: Vector3 = -along if end == "threshold" else along
		var dir := Vector2i(roundi(away.x), roundi(away.z))
		if absi(dir.x) + absi(dir.y) != 1 or Vector2(away.x, away.z).distance_to(Vector2(dir)) > 0.01:
			push_warning("[terrain] %s: its runway is not a quarter turn, so its final keeps no rock out" % field["id"])
			continue
		var at: Vector3 = frame[end]
		var level: int = roundi(at.y * GROUND_TICKS_PER_METRE)
		var half: int = Airfield.FINAL_HALF_WIDTH + FINAL_SIDE
		var across := Vector2i(absi(dir.y), absi(dir.x))
		for s in range(0, Airfield.FINAL_LENGTH, FINAL_STEP):
			var a: Vector2i = Vector2i(roundi(at.x), roundi(at.z)) + dir * s - across * half
			var b: Vector2i = Vector2i(roundi(at.x), roundi(at.z)) + dir * (s + FINAL_STEP) + across * half
			out.append_array([mini(a.x, b.x), mini(a.y, b.y), maxi(a.x, b.x), maxi(a.y, b.y),
				level + floori(float(s) * GROUND_TICKS_PER_METRE / 34.0)])
	return out


## WHAT THE MOUNTAINS ARE MADE FROM, as `MountainRange.configure` takes it.
static func mountain_values() -> Dictionary:
	var lists: Dictionary = mountain_keepout_lists()
	return {"spacing": MountainRanges.SPACING, "tile_quads": MountainRanges.TILE_QUADS,
		"ranges": MountainRanges.ranges(), "keepouts": lists["keepouts"], "keepout_margins": lists["margins"],
		"keepout_rises": lists["rises"]}


## HOW MUCH EACH KEEP-OUT OF `mountain_keepouts` IS GROWN BY, whole metres, -1 for the default: the second list of
## `mountain_keepout_lists`, which is built in the same loop as the first so the two cannot come out of step.
static func mountain_keepout_margins() -> PackedInt32Array:
	return mountain_keepout_lists()["margins"]


## WHERE NO ROCK MAY STAND, five ints each -- x0, z0, x1, z1 in whole metres and the floor in ticks of 1/32 m -- for
## `MountainRange`: every clearance this file keeps (spawns, fires, runway approaches, air bases, the railway, the gates and
## the hand-built places), at its own box's bottom, and every town to TOWN_ROCK_ROOM past its radius, at the ground. The
## rock is held under each floor and rises from it no steeper than fifty degrees (range_core.hpp, KEEP-OUTS), so a range
## that meets a runway approach is cut down to a slope rather than deleted whole, as a mountain of boxes was.
static func mountain_keepouts() -> PackedInt32Array:
	return mountain_keepout_lists()["keepouts"]


## THE KEEP-OUTS AND HOW MUCH EACH IS GROWN BY, built in ONE loop: `{"keepouts": five ints each, "margins": one int each}`,
## the margin in whole metres or -1 for range_core's default of one triangle's reach. THE MARGIN IS APPENDED BESIDE ITS BOX
## AT THE SAME LINE, never worked out afterwards from a second walk, because two lists that must stay index-aligned drift
## the day a kind is inserted into one and not the other -- and the failure would be a runway approach quietly given the
## railway's small margin. `MountainRange.configure` refuses lists of different lengths. Only the railway's box asks for less.
static func mountain_keepout_lists() -> Dictionary:
	var out := PackedInt32Array()
	var margins := PackedInt32Array()
	var rises := PackedInt32Array()
	for keep in _clearances():
		var at: Vector3 = keep["position"]
		var half: Vector3 = keep["half_extents"]
		out.append_array([floori(at.x - half.x), floori(at.z - half.z), ceili(at.x + half.x), ceili(at.z + half.z),
			maxi(floori((at.y - half.y) * GROUND_TICKS_PER_METRE), 0)])
		margins.append(RAIL_MARGIN if keep["why"] == &"rail" else -1)
		rises.append(RAIL_RISE_FIFTHS if keep["why"] == &"rail" else 0)
	for town in TownCatalogue.towns():
		var centre: Vector3 = town["centre"]
		var room: float = float(town["radius"]) + TOWN_ROCK_ROOM
		out.append_array([floori(centre.x - room), floori(centre.z - room), ceili(centre.x + room), ceili(centre.z + room), 0])
		margins.append(-1)
		rises.append(0)
	# AND THE ISLAND'S UNPROTECTED FINALS (`_island_final_keepouts`); a level's are its own, added where its rock is raised.
	if _field == null:
		var finals: PackedInt32Array = _island_final_keepouts()
		out.append_array(finals)
		for f in range(finals.size() / 5):
			margins.append(-1)
			rises.append(0)
	# AND EVERY WOOD, by the bounds of its turned rectangle: a wood is a place on the valley floor, laid by hand, and the
	# rock is kept off it as off a town. With the ranges reaching into the west wood, the simulation's leg through the
	# wood's middle 8 m up ran into a flank (tests/forest.gd, 2026-09-18). The island's stands are a table (Forests.STANDS)
	# and ask no ground, so this asks nothing of the mountains it is making.
	for stand in Forests.stands():
		var middle: Vector3 = stand["centre"]
		var along: Vector3 = stand["along"]
		var half: Vector2 = stand["half"]
		var across := Vector3(-along.z, 0.0, along.x)
		var reach := Vector2(absf(along.x) * half.y + absf(across.x) * half.x, absf(along.z) * half.y + absf(across.z) * half.x)
		out.append_array([floori(middle.x - reach.x), floori(middle.z - reach.y), ceili(middle.x + reach.x),
			ceili(middle.z + reach.y), 0])
		margins.append(-1)
		rises.append(0)
	return {"keepouts": out, "margins": margins, "rises": rises}


## THE RING'S MEASURES, asked of the mountains themselves rather than of a list of where peaks were meant to be.

## HOW LOW A PASS IS, metres: the ring is crossed at or under this along a pass, which is how far down a pilot flying
## through one is from the ground at its lowest; and where across the ring's band the crossing is looked for, and how
## finely, metres and degrees.
const PASS_LOW: float = 60.0
const RING_BAND := Vector2(4200.0, 6300.0)
const RING_BAND_STEP: float = 16.0
const RING_BEARING_STEP: float = 0.25


## THE NARROWEST AND WIDEST WAY THROUGH THE RING, metres at `MountainRanges.RING_RADIUS`: every run of bearings along which
## the highest rock from the band's inside to its outside stands at or under PASS_LOW, measured on the surface the
## simulation collides with. The ring is a ring you fly THROUGH -- at fourteen boxes a side it closed into a fence -- and
## this is what `tests/smoke.gd` holds, because from inside the ring no screenshot shows whether it is a fence. Vector2(0, 0)
## with no mountains, or no pass.
static func ring_gaps() -> Vector2:
	var rock: Object = mountains()
	if rock == null:
		return Vector2.ZERO
	var steps: int = roundi(360.0 / RING_BEARING_STEP)
	var clear: Array[bool] = []
	for k in range(steps):
		var bearing: float = deg_to_rad(float(k) * RING_BEARING_STEP)
		var points := PackedVector2Array()
		var r: float = RING_BAND.x
		while r <= RING_BAND.y:
			points.append(Vector2(cos(bearing), sin(bearing)) * r)
			r += RING_BAND_STEP
		var highest: float = 0.0
		for h in (rock.call("surfaces_at", points) as PackedFloat32Array):
			highest = maxf(highest, h)
		clear.append(highest <= PASS_LOW)
	# THE RUNS OF CLEAR BEARINGS, round the circle: start at a blocked one so no run is cut in two at 0 degrees.
	var first: int = clear.find(false)
	if first < 0:
		return Vector2.ZERO
	var tightest: float = INF
	var widest: float = 0.0
	var run: int = 0
	for k in range(1, steps + 1):
		if clear[(first + k) % steps]:
			run += 1
		elif run > 0:
			var width: float = deg_to_rad(float(run) * RING_BEARING_STEP) * MountainRanges.RING_RADIUS
			tightest = minf(tightest, width)
			widest = maxf(widest, width)
			run = 0
	return Vector2(tightest, widest) if widest > 0.0 else Vector2.ZERO


## Where every gate stands. Exposed so the smoke test can check each opening is clear
## rather than restating the layout and drifting away from it.
static func gate_centres() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for gate in _gate_definitions():
		out.append(gate[0])
	return out


## Each gate's centre, and which axis its pillars are offset along. The opening then faces
## the other way, which is the way you fly through it.
static func _gate_definitions() -> Array:
	var out: Array = []
	for radius in GATE_RADII:
		out.append([Vector3(0.0, 0.0, -radius), Vector3.RIGHT])
		out.append([Vector3(0.0, 0.0, radius), Vector3.RIGHT])
		out.append([Vector3(-radius, 0.0, 0.0), Vector3.BACK])
		out.append([Vector3(radius, 0.0, 0.0), Vector3.BACK])
	return out


## Two pillars and a lintel. Threading one at 70 m/s is the most reliably satisfying thing
## in the world so far, and it costs three boxes.
static func _gates(out: Array[Dictionary]) -> void:
	for gate in _gate_definitions():
		var centre: Vector3 = gate[0]
		var across: Vector3 = gate[1]
		var pillar: float = 14.0
		var reach: float = GATE_OPENING * 0.5 + pillar
		var through: Vector3 = Vector3(1.0, 0.0, 1.0) - across.abs()
		var thickness: Vector3 = across.abs() * pillar + through * pillar
		for side in [-1.0, 1.0]:
			out.append({
				"position": centre + across * reach * side
					+ Vector3(0.0, GATE_HEIGHT * 0.5, 0.0),
				"half_extents": Vector3(thickness.x, GATE_HEIGHT * 0.5, thickness.z),
				"group": Group.CONCRETE,
			})
		out.append({
			"position": centre + Vector3(0.0, GATE_HEIGHT + 10.0, 0.0),
			"half_extents": across.abs() * (reach + pillar) + through * pillar
				+ Vector3(0.0, 10.0, 0.0),
			"group": Group.CONCRETE,
		})


## ---- somewhere to go -------------------------------------------------------------

## How many of each kind fly or drive themselves. Twice as many in the air as on it,
## because the air is where you spend the session and an empty sky is the one that shows.
## THE BUDGET IS 52 ENTITIES AND THIS WORLD WAS BUILDING A HUNDRED AND SIXTY.
##
## `bandwidth_limit_bytes_per_tick` is 1024 and a vehicle costs about 19.6 bytes an update,
## so about fifty-two of them fit in a tick -- see "THE CEILING IS 1024 BYTES PER CLIENT PER
## TICK" in agents.md, which measured it. Past that nothing gets louder: the server rotates
## fairly and every entity simply comes round less often, at `tick_rate * 52 / entities`.
##
## Forty aeroplanes, forty helicopters, forty cars and ten boats, on top of the forty-odd
## machines the spawn table parks around the island, is about a hundred and sixty. That is
## 39 Hz of freshness on a 120 Hz clock, and what 39 Hz looks like from a cockpit is an
## aeroplane that jitters and, between updates, appears to sink.
##
## So the world starts QUIET and is filled up by hand: the board in your left hand adds
## traffic a machine at a time -- see `Sky.add_traffic` -- which also makes the cost visible.
## You can watch the sky get worse as you add to it, which is a better way to learn where
## the ceiling is than a number in a document.
##
## Twice as many in the air as on it, because the air is where you spend the session.
##
## TEN AND NOT EIGHT. Three quarters of them fly in flights of at most four, so eight gives
## two leaders and four followers per kind -- which lands exactly on the floor the formation
## check in smoke asks for, and one failed spawn puts it under. Ten leaves room.
const FLEET_AIR: int = 10
## Cars are the traffic you actually meet: they are on the ground you land on and drive
## past, so there are as many of them as there are aircraft.
const FLEET_CARS: int = 10
const FLEET_SURFACE: int = 3

## How many fly in formation, and how many machines one flight may have. Four is a flight:
## bigger than that and the tail of it is a long way from the leader it is trying to hold
## station on, which is a rejoin rather than a formation.
const FORMED_FRACTION: float = 0.75
const FLIGHT_MAX: int = 4

## Where the followers sit, in the leader's frame: right, up, BEHIND.
##
## Aeroplanes fly FINGER FOUR -- one on the right, two stepped away to the left -- which is
## the shape you can actually see from another aircraft. Helicopters fly a TRAIL, single
## file, because they are slow enough that a line reads better than a wall and they do not
## need the lookout a fighting formation is for.
const FINGER_FOUR: Array[Vector3] = [
	Vector3(48.0, -8.0, 58.0),
	Vector3(-48.0, -8.0, 58.0),
	Vector3(-98.0, -16.0, 120.0),
]
const TRAIL: Array[Vector3] = [
	Vector3(0.0, 0.0, 55.0),
	Vector3(0.0, -4.0, 110.0),
	Vector3(0.0, -8.0, 165.0),
]
## A CONVOY, nose to tail. Metres rather than tens of metres, and no vertical offset at all:
## cars keep station on the ground, where the whole formation is two dimensions and the
## spacing is a stopping distance rather than a wingspan.
const CONVOY: Array[Vector3] = [
	Vector3(0.0, 0.0, 24.0),
	Vector3(0.0, 0.0, 48.0),
	Vector3(0.0, 0.0, 72.0),
]
## And some of them run TWO ABREAST. A world in which every convoy is the same shape reads
## as a conveyor belt, and a pair running side by side is the thing that makes the others
## look like a choice.
const ABREAST: Array[Vector3] = [
	Vector3(8.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 26.0),
	Vector3(8.0, 0.0, 26.0),
]
## How many of the convoys run abreast rather than in single file.
const ABREAST_FRACTION: float = 0.3


## The shape ONE flight holds. `flight` picks between shapes where a kind has more than
## one, and is the leader's index, so a given convoy is the same shape on every peer.
static func slots_for(kind: int, flight: int = 0) -> Array[Vector3]:
	match kind:
		Sim.Kind.PLANE:
			return FINGER_FOUR
		Sim.Kind.CAR:
			return ABREAST if _noise(flight, 313) < ABREAST_FRACTION else CONVOY
		_:
			return TRAIL


## A follower's slot, put into the world from its leader's pose. Used to SPAWN them in
## formation: born in place, rather than forty aircraft spending the first minute of the
## session rejoining from wherever they happened to appear.
static func slot_world(leader_at: Vector3, yaw: float, slot: Vector3) -> Vector3:
	var forward: Vector3 = nose_from_yaw(yaw)
	var right := Vector3(-forward.z, 0.0, forward.x)
	return leader_at + right * slot.x + Vector3(0.0, slot.y, 0.0) - forward * slot.z


static func fleet_size(kind: int) -> int:
	if kind in [Sim.Kind.PLANE, Sim.Kind.FIGHTER, Sim.Kind.TOMCAT, Sim.Kind.PHANTOM, Sim.Kind.FALCON, Sim.Kind.PROWLER, Sim.Kind.HELI, Sim.Kind.UH60,
			Sim.Kind.LITTLEBIRD, Sim.Kind.APACHE]:
		return FLEET_AIR
	return FLEET_CARS if kind == Sim.Kind.CAR else FLEET_SURFACE


## SOMEWHERE FOR ONE MORE MACHINE OF THIS KIND, put into the world at a waypoint it could
## legally have flown to. For `Sky.add_traffic`, which is the board's way of filling a sky
## that now starts quiet.
##
## `which` only has to differ between calls: it picks the waypoint and the heading, so two
## presses of the same button do not stack two aeroplanes in one piece of air. The entity id
## is deliberately NOT used for it -- see the autopilot seeding note in agents.md, where
## seeding off the id meant adding two spawns reseeded all forty and broke every formation.
static func one_more(kind: int, which: int, grid: BoxGrid) -> Dictionary:
	var pool: Array[Vector3] = waypoints(kind, grid)
	if pool.is_empty():
		return {}
	var at: Vector3 = pool[(which * 7 + kind * 3) % pool.size()]
	var yaw: float = TAU * _noise(kind * 31 + which, 89)
	# IN THE AIR ALREADY, like everything else this file spawns. An aeroplane put into the
	# air at a standstill stalls before it accelerates, which is a machine that arrives and
	# immediately falls out of the sky.
	var flies: bool = kind in [Sim.Kind.PLANE, Sim.Kind.FIGHTER, Sim.Kind.TOMCAT, Sim.Kind.PHANTOM, Sim.Kind.FALCON, Sim.Kind.PROWLER, Sim.Kind.HELI, Sim.Kind.UH60,
		Sim.Kind.LITTLEBIRD, Sim.Kind.APACHE]
	var launch: Vector3 = nose_from_yaw(yaw) * (cruise_for(kind) if flies else 0.0)
	return {"kind": kind, "position": at, "yaw": yaw, "velocity": launch}

## Where autopilots may be sent, per kind.
##
## The POOL is the world's business, not the autopilot's: where the roads are, which water
## is deep enough, and how high is over the mountains are all things this file knows and
## the simulation does not. It is built here, on every peer, from the same data as the
## collision -- and the simulation then checks each leg against its own boxes before flying
## it, so a pool entry only has to be somewhere REACHABLE, not somewhere reachable from
## everywhere.
##
## HANDED THE GRID, NEVER BUILDING THE ISLAND. This rebuilt `boxes()` once per kind and asked every candidate point
## about every box, and with the towns in the world that was 1,158 ms of boot against HEAD's 306 (boot_probe,
## eight launches, 2026-09-13). The level builds the list once and files it in a `BoxGrid`; the answer is the same,
## point for point, which tests/towns.gd holds. Required: an absent grid is not quietly the whole island.
##
## AND NO SHIP IS SENT TO AN OIL PLATFORM: a point for anything that floats is dropped within `OilField.KEEP_CLEAR` of a
## platform, the offshore safety zone. A leg between two kept points can still pass one; see `OilField`.
static func waypoints(kind: int, grid: BoxGrid) -> Array[Vector3]:
	var pool: Array[Vector3] = _waypoints_any(kind, grid)
	return OilField.keep_clear(pool) if is_a_ship(kind) or kind == Sim.Kind.PIRATE else pool


static func _waypoints_any(kind: int, grid: BoxGrid) -> Array[Vector3]:
	if _field != null:
		return _waypoints_on_the_ground(kind)
	var out: Array[Vector3] = []
	match kind:
		# A TILTROTOR CROSSES AN ISLAND LIKE AN AEROPLANE, so it goes where aeroplanes go.
		# It has its own pool rather than borrowing the aeroplanes' because pools are looked
		# up by kind, and because if it ever wants its own heights this is where they go.
		#
		# EVERY WING THE SPAWN TABLE PUTS IN THE AIR HAS TO BE IN HERE, and that is not a
		# tidiness rule. An airborne spare flies ITSELF until somebody sits in it -- see
		# `Sky`, and the measurement beside it: a wing with nobody on the throttle is down
		# to 30 m/s and sinking within five seconds. A kind missing from this match gets an
		# EMPTY pool, so its autopilot is handed no destination, holds no altitude, and the
		# aeroplane descends until it hits something.
		#
		# From the ground that is "the planes are falling out of the sky", with nothing
		# anywhere saying why. The airliner, the gunship and the water bomber were all in
		# that state; `every_machine_on_its_own_picked_a_route` in smoke is what counts them.
		Sim.Kind.PLANE, Sim.Kind.FIGHTER, Sim.Kind.TOMCAT, Sim.Kind.PHANTOM, Sim.Kind.FALCON, Sim.Kind.PROWLER, Sim.Kind.OSPREY, Sim.Kind.CESSNA, \
				Sim.Kind.AIRLINER, Sim.Kind.GUNSHIP, Sim.Kind.TANKER, Sim.Kind.HAWKEYE, Sim.Kind.JUMBO, Sim.Kind.LIGHTNING, \
				Sim.Kind.WARTHOG, Sim.Kind.TRANSPORT, Sim.Kind.P51, Sim.Kind.P47:
			# OVER THE ISLAND, not out to sea. Aircraft routed across open water spend
			# most of a leg somewhere nobody is looking, and the point of them is to be
			# something you meet.
			# AND CLEAR OF EVERYTHING, which this pool alone never checked.
			#
			# The helicopter's asks for 30 m of room and the car's for 14; the aeroplane's --
			# the biggest pool, and the one most of the sky is flying to -- asked for none.
			# It happens to be clear today, and "happens to be" is the part worth fixing: a
			# waypoint inside a hill is a destination nothing can reach, which is a machine
			# with no route, holding no altitude, descending until it hits something.
			#
			# Sixty metres, because an aeroplane arrives at a waypoint faster than anything
			# else does and needs room to be wrong in.
			for i in range(WING_POOL):
				var at := _spread(i, 401, WORLD_HALF * WING_SPREAD)
				at.y = WING_LOW + _noise(i, 61) * WING_BAND
				if grid.is_clear_of(at, WING_ROOM) and rock_clears(at, Vector3.ONE * WING_ROOM):
					out.append(at)
		Sim.Kind.HELI, Sim.Kind.UH60, Sim.Kind.LITTLEBIRD, Sim.Kind.APACHE:
			# LOW. A helicopter at three hundred metres is an aeroplane with a funny
			# outline: what makes one read as a helicopter is that it is down among the
			# things it is flying over. Thirty-five to a hundred and thirty, which is over
			# the trees and under the ridgelines.
			for i in range(HELI_POOL):
				var at := _spread(i, 733, WORLD_HALF * HELI_SPREAD)
				at.y = HELI_LOW + _noise(i, 67) * HELI_BAND
				if grid.is_clear_of(at, HELI_ROOM) and rock_clears(at, Vector3.ONE * HELI_ROOM):
					out.append(at)
		Sim.Kind.CAR:
			# On the island, on the ground, and not inside a building -- AND INSIDE THE RING, on the valley floor where the
			# towns and their roads are. The old ring was thirty peaks with gaps wider than a convoy; a pass between two
			# ranges is sixteen degrees of talus, and a convoy sent through one abreast drove its followers up the slopes
			# either side, 44 m up and 1.5 km apart (smoke, 2026-09-18).
			var ring_floor: float = MountainRanges.ring_inside() if mountains() != null else INF
			for i in range(CAR_POOL):
				var at := _spread(i, 971, WORLD_HALF * CAR_SPREAD)
				at.y = 0.7
				if grid.is_clear_of(at, CAR_ROOM) and rock_clears(at, Vector3.ONE * CAR_ROOM) 						and Vector2(at.x, at.z).length() < ring_floor:
					out.append(at)
		Sim.Kind.PIRATE:
			# OUT IN THE BRIGS' RING, well off the coast: see PIRATE_SEA_INNER. The island's sea has no floor, so any point
			# past the coast is open sea as deep as a keel needs.
			var reach: float = placed_reach()
			for i in range(PIRATE_POOL):
				var at := _spread(i, 1543, reach)
				at.y = SEA_LEVEL
				if maxf(absf(at.x), absf(at.z)) > WORLD_HALF + PIRATE_SEA_INNER and Vector2(at.x, at.z).length() <= reach:
					out.append(at)
			out = _with_a_wet_leg(out, Sim.Kind.PIRATE)
		Sim.Kind.BOAT, Sim.Kind.SUBMARINE:
			# Off the coast. Anything inside the island's square is a field. The island's sea has no floor, so a point past the
			# coast is as deep as a submarine's keel needs too.
			for i in range(BOAT_POOL):
				var at := _spread(i, 1279, WORLD_HALF * BOAT_SPREAD)
				at.y = SEA_LEVEL
				if maxf(absf(at.x), absf(at.z)) > WORLD_HALF + OFFSHORE:
					out.append(at)
		_:
			pass
	return out


## THE POOLS ON THE GENERATED GROUND. A wing's and a helicopter's points stand their height over the highest surface within
## their room, spread over the land's reach, kept only where the ground clears them and a leg to another point clears it
## too; a helicopter's only over land, down among what it flies over. A boat's are open sea as deep as its keel needs,
## within the placed reach, tried BOAT_TRIES_EACH to one in a single batch. A car's pool is empty until the towns and their
## roads are seated (report 8m), so no car is sent anywhere.
static func _waypoints_on_the_ground(kind: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var land: float = land_reach()
	match kind:
		Sim.Kind.PLANE, Sim.Kind.FIGHTER, Sim.Kind.TOMCAT, Sim.Kind.PHANTOM, Sim.Kind.FALCON, Sim.Kind.PROWLER, Sim.Kind.OSPREY, Sim.Kind.CESSNA, \
				Sim.Kind.AIRLINER, Sim.Kind.GUNSHIP, Sim.Kind.TANKER, Sim.Kind.HAWKEYE, Sim.Kind.JUMBO, Sim.Kind.LIGHTNING, \
				Sim.Kind.WARTHOG, Sim.Kind.TRANSPORT, Sim.Kind.P51, Sim.Kind.P47:
			for i in range(WING_POOL):
				var at := _spread(i, 401, land * WING_SPREAD)
				at.y = highest_near(at, WING_ROOM) + WING_LOW + _noise(i, 61) * WING_BAND
				if _ground_clears(at, at, WING_ROOM, WING_ROOM):
					out.append(at)
			return _with_a_clear_leg(out, kind)
		Sim.Kind.HELI, Sim.Kind.UH60, Sim.Kind.LITTLEBIRD, Sim.Kind.APACHE:
			for i in range(HELI_POOL):
				var at := _spread(i, 733, land * HELI_SPREAD)
				if water_height(at) != -INF:
					continue
				at.y = highest_near(at, HELI_ROOM) + HELI_LOW + _noise(i, 67) * HELI_BAND
				if _ground_clears(at, at, HELI_ROOM, HELI_ROOM):
					out.append(at)
			return _with_a_clear_leg(out, kind)
		Sim.Kind.BOAT:
			var reach: float = placed_reach()
			var deepest: int = -ceili(ship_depth(Sim.Kind.BOAT) * GROUND_TICKS_PER_METRE)
			var points := PackedInt32Array()
			for i in range(BOAT_POOL * BOAT_TRIES_EACH):
				var at := _spread(i, 1279, reach)
				points.append_array([roundi(at.x), roundi(at.z)])
			var waters: PackedInt32Array = _field.call("waters_at", points)
			var heights: PackedInt32Array = _field.call("heights_at", points)
			for i in range(heights.size()):
				if out.size() >= BOAT_POOL:
					break
				var x: float = float(points[2 * i])
				var z: float = float(points[2 * i + 1])
				if waters[i] == 0 and heights[i] <= deepest and Vector2(x, z).length() <= reach:
					out.append(Vector3(x, SEA_LEVEL, z))
		Sim.Kind.SUBMARINE:
			# A SUBMARINE'S OWN POOL, not the boats' it would fall back to: points on open sea as deep as its resting place
			# needs (`ship_depth`: its draught and SHIP_KEEL_ROOM), each with a leg to another point at least the shortest leg
			# away that has the MOVING need (the simulation's `need`: its draught and the sounding's keel clearance) the whole
			# way. Two numbers on purpose, the brig's precedent. The boat model sounds the leg it takes (carrier 4c); this only
			# keeps a point from being one a submarine could reach and not leave. Not `_with_a_wet_leg`, which reads the
			# sailing model's hop and wet: 0 for a boat.
			var rules: Dictionary = Sim.client.ai_leg_rules(Sim.Kind.SUBMARINE) if Sim.client != null else {}
			var need: float = float(rules.get("need", ship_depth(Sim.Kind.SUBMARINE)))
			var shortest: float = float(rules.get("shortest", 0.0))
			var ring: float = placed_reach()
			var deep: Array[Vector3] = []
			for i in range(BOAT_POOL):
				var sea: Vector3 = open_sea_near(_spread(i, 1297, ring), ship_depth(Sim.Kind.SUBMARINE))
				if sea != Vector3.INF and Vector2(sea.x, sea.z).length() <= ring:
					deep.append(Vector3(sea.x, SEA_LEVEL, sea.z))
			for a in deep:
				for b in deep:
					if a.distance_to(b) >= shortest and a != b and Sim.client != null and bool(Sim.client.sea_leg_is_deep(a, b, need)):
						out.append(a)
						break
		Sim.Kind.PIRATE:
			# OPEN SEA A BRIG'S KEEL CLEARS, nearest each tried point within the placed reach, as cockpit-terrain asked:
			# `open_sea_near(at, pirate_depth())`, which rounds the depth in whole ticks away from the surface, and no point
			# where the world has no such sea.
			var ring: float = placed_reach()
			for i in range(PIRATE_POOL):
				var sea: Vector3 = open_sea_near(_spread(i, 1543, ring), pirate_depth())
				if sea != Vector3.INF and Vector2(sea.x, sea.z).length() <= ring:
					out.append(Vector3(sea.x, SEA_LEVEL, sea.z))
			out = _with_a_wet_leg(out, Sim.Kind.PIRATE)
		_:
			pass
	return out


## Ten of each, flying and driving themselves, to give the world something moving in it.
##
## Started ON their first waypoint pool rather than at the origin, so the traffic is spread
## across the map from the first frame instead of forty machines untangling themselves out
## of one heap.
static func ai_fleet(grid: BoxGrid) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind in [Sim.Kind.PLANE, Sim.Kind.HELI, Sim.Kind.CAR, Sim.Kind.BOAT]:
		var pool: Array[Vector3] = waypoints(kind, grid)
		if pool.is_empty():
			continue
		var count: int = fleet_size(kind)
		# Three quarters of them fly together, in flights of at most four. The rest go
		# their own way, so the sky is not entirely made of tidy diamonds.
		# CARS CONVOY TOO. A road with forty cars on it each going somewhere different is
		# forty cars; the same forty in groups of three and four is traffic.
		var formed: int = int(round(float(count) * FORMED_FRACTION)) \
			if kind != Sim.Kind.BOAT else 0
		var slots: Array[Vector3] = slots_for(kind)
		var lead_at := Vector3.ZERO
		var lead_yaw: float = 0.0
		var lead_index: int = -1
		for i in range(count):
			var in_flight: bool = i < formed
			var place: int = i % FLIGHT_MAX if in_flight else 0
			var yaw: float = TAU * _noise(kind * 31 + i, 89)
			var at: Vector3 = pool[(i * 7 + kind * 3) % pool.size()]
			var leader: int = -1
			var slot := Vector3.ZERO
			if in_flight and place == 0:
				lead_at = at
				lead_yaw = yaw
				lead_index = out.size()
				# A new flight may be a different shape from the last one.
				slots = slots_for(kind, i)
			elif in_flight:
				# Born in place, at the slot, on the leader's heading and speed.
				leader = lead_index
				slot = slots[place - 1]
				yaw = lead_yaw
				at = slot_world(lead_at, lead_yaw, slot)
			var flying: bool = kind == Sim.Kind.PLANE
			out.append({
				"kind": kind,
				"position": at,
				"yaw": yaw,
				# Aeroplanes only. Everything else can start from rest; a wing cannot.
				"velocity": nose_from_yaw(yaw) * cruise_for(kind) if flying else Vector3.ZERO,
				"leader": leader,
				"slot": slot,
			})
	return out


## A point spread over the map by a hash rather than a grid, so the pool does not read as
## a lattice from the air.
static func _spread(index: int, salt: int, reach: float) -> Vector3:
	return Vector3((_noise(index, salt) - 0.5) * 2.0 * reach, 0.0,
		(_noise(index, salt + 1) - 0.5) * 2.0 * reach)


static func _clear_of(solid: Array[Dictionary], at: Vector3, room: float) -> bool:
	for box in solid:
		var to: Vector3 = at - (box["position"] as Vector3)
		var half: Vector3 = (box["half_extents"] as Vector3) + Vector3.ONE * room
		if absf(to.x) < half.x and absf(to.y) < half.y and absf(to.z) < half.z:
			return false
	return true


## ---- the railway ---------------------------------------------------------------------

## A single loop right round the island, sampled every RAIL_STEP metres.
## INSIDE the ring of peaks, which start at about 4850 m. A railway laid through a
## mountain range is a tunnel, and there are no tunnels here.
const RAIL_RADIUS: float = 3600.0
## How much the radius wanders. NOT much: the curvature of the loop is what a train has to
## get round, and a wandering radius is a tight turn waiting to happen.
const RAIL_WANDER: float = 300.0
## THE SURVEY: the loop sampled every 40 m, which is what the scenery's corridor and the street lamps' clearance were laid
## round, and they still are, byte for byte.
const RAIL_STEP: float = 40.0
## THE TRACK THE TRAINS RIDE: the same loop sampled every 10 m (lane/trains, 2026-09-19). A train rides the straight chords
## between waypoints and the track is drawn on those same chords, so the chord IS the rail; what the step sets is the kink
## at each waypoint, which is the chord's own turn, 10 / 2588 of a radian at the sharpest bend -- 0.22 degrees, against
## 0.89 at 40 m. `tests/track_drawn.gd` holds every joint to 0.25.
const RAIL_LAID_EVERY: float = 10.0
## On a low embankment, so the track reads as track rather than as a stripe on the grass.
const RAIL_HEIGHT: float = 3.0
## What the railway is banked for, in metres a second. See rail_bank().
const RAIL_SPEED: float = 22.0
## However tight a corner gets, a railway is not a velodrome. Radians.
const RAIL_MAX_BANK: float = 0.10
## HOW MANY BOXCARS A TRAIN HAS, behind its locomotive. Asked for on 2026-09-17: "make trains
## 8-10 cars long". A RANGE rather than one number, because every train on a railway being the
## same length is the tell that there is one constant behind them; each train's own count is
## worked out from its place in the table below and both ends of the range are in use.
##
## HOW FAR APART they stand is NOT here. It is `Boxcar.SPACING`, computed from the car's own
## length and its coupler's reach, because a spacing typed beside a length is a spacing that can
## part from it -- and had: 21.0 m between 18.0 m boxes left a three-metre gap at every coupling.
const TRAIN_CARS_LEAST: int = 8
const TRAIN_CARS_MOST: int = 10


## HOW FAR THE TRACK IS ROLLED at each waypoint, in radians, matched to `rail_points()`.
##
## A railway is banked so that at the speed it is built for, the load runs down through the
## sleepers instead of sideways into the outer rail: `atan(v^2 / gR)`. Read off the
## waypoints themselves -- the radius of the circle through each point and its two
## neighbours -- so the bank is a PROPERTY OF THE TRACK and stays right if the loop is
## reshaped.
##
## Signed by which way the corner goes, and capped: this is a fast main line with
## kilometre radii, so the answer is under a degree nearly everywhere, and the machinery
## matters more than the number. Bank a tighter loop and it will lean into it properly.
static func rail_bank(step: float = RAIL_STEP) -> PackedFloat32Array:
	var points: Array[Vector3] = rail_points(step)
	var out := PackedFloat32Array()
	for i in range(points.size()):
		var a: Vector3 = points[(i - 1 + points.size()) % points.size()]
		var b: Vector3 = points[i]
		var c: Vector3 = points[(i + 1) % points.size()]
		var into := Vector2(b.x - a.x, b.z - a.z)
		var out_of := Vector2(c.x - b.x, c.z - b.z)
		if into.length() < 0.001 or out_of.length() < 0.001:
			out.append(0.0)
			continue
		# The turn between the two legs, and the radius that turn implies over their length.
		var turn: float = into.angle_to(out_of)
		var run: float = (into.length() + out_of.length()) * 0.5
		if absf(turn) < 0.00001:
			out.append(0.0)
			continue
		var radius: float = run / absf(turn)
		var lean: float = atan(RAIL_SPEED * RAIL_SPEED / (9.81 * radius))
		# Turning right leans right, which is a negative roll about a -Z nose.
		out.append(clampf(lean * signf(turn), -RAIL_MAX_BANK, RAIL_MAX_BANK))
	return out


## THE RAILWAY, as points in order, closing back on the first.
##
## TIGHT TURNS ARE THE THING TO AVOID, and on a loop that is a curvature calculation rather
## than a matter of taste: the radius wanders by two low harmonics only, so the sharpest
## bend anywhere on it is still kilometres across. Add a third harmonic or double the
## wander and it will start to look like a slalom, which a fifty-metre train cannot take.
##
## `step` is how often the one loop is sampled: RAIL_STEP for the survey everything else keeps clear of, RAIL_LAID_EVERY
## for the track itself. Both are samples of the same function, so they cannot disagree about where the railway is by
## more than a 40 m chord's sagitta, 7.7 cm at the sharpest bend.
static func rail_points(step: float = RAIL_STEP) -> Array[Vector3]:
	var out: Array[Vector3] = []
	# THE RAILWAY IS THE ISLAND'S: on the generated ground there is none, and nothing that asks keeps clear of a loop of
	# island coordinates -- a seated town's street lamps skip any pole within 8 m of these points (TownView).
	if _field != null:
		return out
	var steps: int = int(round(TAU * RAIL_RADIUS / step))
	for i in range(steps):
		var angle: float = TAU * float(i) / float(steps)
		# Two harmonics, both gentle. Three would be a slalom.
		var radius: float = RAIL_RADIUS \
			+ sin(angle * 2.0) * RAIL_WANDER \
			+ sin(angle * 3.0 + 1.1) * RAIL_WANDER * 0.45
		out.append(Vector3(cos(angle) * radius, RAIL_HEIGHT, sin(angle) * radius))
	return out


## The sharpest bend on the railway, as a RADIUS in metres. Bigger is gentler.
##
## Measured from three consecutive points: the circle through them has radius
## abc / 4A, and the smallest of those anywhere on the loop is what a train has to take.
static func tightest_curve() -> float:
	var points: Array[Vector3] = rail_points()
	var tightest: float = INF
	for i in range(points.size()):
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()]
		var c: Vector3 = points[(i + 2) % points.size()]
		var ab: float = a.distance_to(b)
		var bc: float = b.distance_to(c)
		var ca: float = c.distance_to(a)
		var area: float = absf((b - a).cross(c - a).length()) * 0.5
		if area < 0.001:
			continue
		tightest = minf(tightest, ab * bc * ca / (4.0 * area))
	return tightest


## Where the trains start, spaced round the loop so you meet one rather than chase it, and how
## many boxcars each is hauling. The count comes out of the same deterministic hash the rest of
## this file uses, so a third train added below gets a length of its own without anybody
## choosing one, and it is always within TRAIN_CARS_LEAST..TRAIN_CARS_MOST.
static func trains() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"track": 0, "distance": 0.0, "speed": 22.0},
		{"track": 0, "distance": TAU * RAIL_RADIUS * 0.5, "speed": 18.0},
	]
	for i in range(out.size()):
		out[i]["cars"] = cars_behind(i)
	return out


## HOW MANY CARS the `index`th train hauls. Its own function so a check can ask it without
## building the table, and so the range is enforced in one place rather than at every caller.
static func cars_behind(index: int) -> int:
	var spread: int = TRAIN_CARS_MOST - TRAIN_CARS_LEAST + 1
	return TRAIN_CARS_LEAST + clampi(int(_noise(index, 7717) * float(spread)), 0, spread - 1)


## ---- the numbers ---------------------------------------------------------------------

## A deterministic value in 0..1 from two integers.
##
## Written out rather than taken from the engine on purpose: see the note at the top. It is
## an integer hash, so it has no state, no seeding order to get wrong, and gives the same
## answer on every machine and every version.
static func _noise(seed_value: int, salt: int) -> float:
	var h: int = (seed_value * 374761393 + salt * 668265263) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = (h ^ (h >> 16)) & 0x7FFFFFFF
	return float(h) / 2147483647.0
