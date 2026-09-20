extends Node
## Headless: do the towns grow where they may, along streets an aeroplane fits down, joined by roads
## that go somewhere -- and does a building stop what a building should?
##
##   Godot --headless --path cockpit res://tests/towns.tscn
##
## TWO KINDS OF QUESTION, answered two ways. What the GENERATOR decided -- where a building stands,
## how tall, whether a road meets a clearance -- is asked of `Terrain.boxes()` and `Terrain.roads(solid)`
## with arithmetic written here, not borrowed from the generator. What the SIMULATION made of it --
## whether a street is open, whether a shell stops, whether a seeker sees -- is asked of a real
## CockpitWorld built with the whole island, the way `FlightLevel._build` builds it, so a building the
## list has and the physics does not is a failure here rather than a wall nobody can see.
##
## Every check that could pass over nothing has a twin that must FAIL on purpose: the row of blocks
## beside an open avenue, the shell with its building taken away, the seeker with the building taken
## away.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
## How high the avenue legs fly: under the lowest building a town can have (two storeys), so the
## twin through the blocks is blocked by ANY building in its row rather than only by a tall one. The
## first version flew both at sixty metres, and four of six rows of blocks were "open" because no
## building in them was that tall.
const STREET_LEG_UP: float = 5.0
## THE LEAST GAP between two buildings, or a building and a mountain, metres. Two boxes that touch share a face plane:
## two walls drawn at the same depth with different windows on them, which flicker against each other in any light. The
## strict overlap check passes a pair that touches, so this asks for a gap. Far under the 2 m two lot margins give.
const LEAST_GAP: float = 0.5

var _failures: PackedStringArray = []
var _sections: int = 0
const SECTIONS: int = 7


func _check(label: String, ok: bool, detail: String) -> void:
	print("[towns] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	var solid: Array[Dictionary] = Terrain.boxes()
	_the_towns_grow_the_same_every_time(solid)
	_the_buildings_stand_where_they_may(solid)
	_the_towns_have_a_skyline(solid)
	_the_roads_join_the_towns(solid)
	_the_simulation_has_every_street_and_every_road(solid)
	_a_building_stops_a_shell_and_hides_a_target(solid)
	_the_grid_answers_as_the_walk_does(solid)
	_check("every_section_of_the_suite_ran", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	_finish()


static func _buildings(solid: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for box in solid:
		if int(box["group"]) == Terrain.Group.BUILDING:
			out.append(box)
	return out


static func _overlap(a: Dictionary, b: Dictionary, room: float = 0.0) -> bool:
	var to: Vector3 = (a["position"] as Vector3) - (b["position"] as Vector3)
	var sum: Vector3 = (a["half_extents"] as Vector3) + (b["half_extents"] as Vector3) + Vector3.ONE * room
	return absf(to.x) < sum.x and absf(to.y) < sum.y and absf(to.z) < sum.z


## ---- the generator ------------------------------------------------------------------------

func _the_towns_grow_the_same_every_time(solid: Array[Dictionary]) -> void:
	var here: Array[Dictionary] = _buildings(solid)
	var again: Array[Dictionary] = _buildings(Terrain.boxes())
	var same: bool = here.size() == again.size()
	for i in range(here.size()):
		if not same:
			break
		same = (here[i]["position"] as Vector3).is_equal_approx(again[i]["position"]) \
			and (here[i]["half_extents"] as Vector3).is_equal_approx(again[i]["half_extents"]) \
			and int(here[i]["seed"]) == int(again[i]["seed"])
	_check("the_towns_grow_the_same_every_time", same and here.size() > 0,
		"%d buildings, built twice and matching" % here.size())
	var per_town: Array[int] = []
	per_town.resize(TownCatalogue.towns().size())
	for box in here:
		per_town[int(box["town"])] += 1
	var empty: Array[String] = []
	for t in range(per_town.size()):
		if per_town[t] < 10:
			empty.append(String(TownCatalogue.towns()[t]["name"]))
	_check("and_every_town_in_the_catalogue_has_buildings", empty.is_empty(),
		"%s%s" % [per_town, "" if empty.is_empty() else " -- nearly empty: %s" % ", ".join(empty)])
	_check("and_the_island_is_under_its_building_limit", here.size() <= TownTuning.MOST_BUILDINGS,
		"%d of %d" % [here.size(), TownTuning.MOST_BUILDINGS])
	_sections += 1


func _the_buildings_stand_where_they_may(solid: Array[Dictionary]) -> void:
	var buildings: Array[Dictionary] = _buildings(solid)
	var clear: Array[Dictionary] = Terrain.clearances()
	var trespass: Array[String] = []
	for box in buildings:
		for keep in clear:
			if _overlap(box, keep):
				trespass.append("%s in %s at %s" % [TownCatalogue.towns()[int(box["town"])]["name"],
					keep.get("why", "?"), keep["position"]])
				break
	_check("no_building_stands_in_a_clearance", trespass.is_empty(),
		"%d buildings against %d clearances%s" % [buildings.size(), clear.size(),
			"" if trespass.is_empty() else ": " + "; ".join(trespass.slice(0, 4))])
	# AGAINST EVERY OTHER SOLID THING, a mountain or another building of the same town.
	var crowded: int = 0
	var others: Array[Dictionary] = []
	for box in solid:
		if int(box["group"]) != Terrain.Group.BUILDING:
			others.append(box)
	for i in range(buildings.size()):
		for other in others:
			if _overlap(buildings[i], other):
				crowded += 1
		for j in range(i + 1, buildings.size()):
			if int(buildings[j]["town"]) == int(buildings[i]["town"]) and _overlap(buildings[i], buildings[j]):
				crowded += 1
	_check("and_none_stands_inside_a_mountain_or_another_building", crowded == 0,
		"%d overlaps" % crowded)
	# AND NONE TOUCHES ONE, in any town: see LEAST_GAP. When the windows shimmered (2026-09-13) the first suspect was two
	# walls in one plane, and none were -- every lot stands back LOT_MARGIN_MIN from its edge -- so this holds that gap
	# rather than finding a fault. RED: LOT_MARGIN_MIN and ALLEY both 0.
	var touching: Array[String] = []
	for i in range(buildings.size()):
		for other in others:
			if _overlap(buildings[i], other, LEAST_GAP):
				touching.append("%s building at %s by a mountain" % [
					TownCatalogue.towns()[int(buildings[i]["town"])]["name"], buildings[i]["position"]])
		for j in range(i + 1, buildings.size()):
			if _overlap(buildings[i], buildings[j], LEAST_GAP):
				touching.append("%s buildings at %s and %s" % [TownCatalogue.towns()[int(buildings[i]["town"])]["name"],
					buildings[i]["position"], buildings[j]["position"]])
	_check("and_none_comes_within_a_wall_of_another", touching.is_empty(),
		"%d pairs closer than %.1f m%s" % [touching.size(), LEAST_GAP,
			"" if touching.is_empty() else ": " + "; ".join(touching.slice(0, 4))])
	var odd: int = 0
	for box in buildings:
		var storeys: float = (box["half_extents"] as Vector3).y * 2.0 / TownTuning.STOREY
		if absf(storeys - round(storeys)) > 0.001:
			odd += 1
	_check("and_every_building_is_a_whole_number_of_storeys", odd == 0,
		"%d of %d are not" % [odd, buildings.size()])
	_sections += 1


func _the_towns_have_a_skyline(solid: Array[Dictionary]) -> void:
	var buildings: Array[Dictionary] = _buildings(solid)
	var rows: Array[String] = []
	var flat: Array[String] = []
	var strays: Array[String] = []
	for t in range(TownCatalogue.towns().size()):
		var town: Dictionary = TownCatalogue.towns()[t]
		var centre: Vector3 = town["centre"]
		var inner: Array[float] = []
		var outer: Array[float] = []
		for box in buildings:
			if int(box["town"]) != t:
				continue
			var at: Vector3 = box["position"]
			var away: float = Vector2(at.x - centre.x, at.z - centre.z).length() / float(town["radius"])
			var tall: float = (box["half_extents"] as Vector3).y * 2.0
			if away < 0.34:
				inner.append(tall)
			elif away > 0.66:
				outer.append(tall)
			# A TOWER IS A THING THE MIDDLE OF A TOWN HAS: anything as tall as the town's shortest tower
			# stands inside its tower radius, plus the block it stands in.
			var lowest: float = float(town["tower_low"]) if float(town["tower_radius"]) > 0.0 else INF
			if tall >= lowest and away * float(town["radius"]) > float(town["tower_radius"]) + float(town["block"]):
				strays.append("%s %.0f m tall %.0f m out" % [town["name"], tall, away * float(town["radius"])])
		var near: float = _mean(inner)
		var far: float = _mean(outer)
		rows.append("%s %.0f/%.0f m" % [town["name"], near, far])
		if not near > far:
			flat.append(String(town["name"]))
	_check("every_town_is_taller_in_the_middle_than_at_the_edge", flat.is_empty(),
		"mean height inner third / outer third: %s" % ", ".join(rows))
	_check("and_its_towers_stand_near_its_centre", strays.is_empty(),
		"none out of place" if strays.is_empty() else "; ".join(strays.slice(0, 4)))
	_sections += 1


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum: float = 0.0
	for v in values:
		sum += v
	return sum / float(values.size())


func _the_roads_join_the_towns(solid: Array[Dictionary]) -> void:
	var roads: Array[Dictionary] = Terrain.roads(solid)
	# WHICH TOWNS CAN BE DRIVEN TO FROM THE FIRST, over the roads as laid -- not over the tree the
	# generator meant to lay, which is the half a dropped link would not show.
	var reached: Dictionary = {0: true}
	var grew: bool = true
	while grew:
		grew = false
		for road in roads:
			var link: Vector2i = road["link"]
			if reached.has(link.x) != reached.has(link.y):
				reached[link.x] = true
				reached[link.y] = true
				grew = true
	_check("every_town_can_be_driven_to", reached.size() == TownCatalogue.towns().size(),
		"%d of %d towns reached over %d lengths of road" % [reached.size(), TownCatalogue.towns().size(), roads.size()])
	var crossing: Array[String] = []
	var crossings: int = 0
	var clear: Array[Dictionary] = Terrain.clearances()
	for road in roads:
		var a: Vector3 = road["from"]
		var b: Vector3 = road["to"]
		var steps: int = maxi(int(ceil(a.distance_to(b) / 5.0)), 1)
		var hit_rail: bool = false
		for s in range(steps + 1):
			var at: Dictionary = {"position": a.lerp(b, float(s) / float(steps)) + Vector3.UP,
				"half_extents": Vector3(float(road["width"]) * 0.5, 1.0, float(road["width"]) * 0.5)}
			for keep in clear:
				if not _overlap(at, keep):
					continue
				if keep.get("why", &"") == &"rail":
					hit_rail = true
				else:
					crossing.append("%s at %s" % [keep.get("why", "?"), (at["position"] as Vector3).round()])
		if hit_rail:
			crossings += 1
	_check("no_road_crosses_a_clearance_but_the_railway", crossing.is_empty(),
		"%d lengths, %d crossing the railway%s" % [roads.size(), crossings,
			"" if crossing.is_empty() else ": " + "; ".join(crossing.slice(0, 4))])
	_sections += 1


## ---- the simulation -------------------------------------------------------------------------

## A server world holding the island exactly as `FlightLevel._build` gives it, less `leave_out`.
static func _world(solid: Array[Dictionary], leave_out: Dictionary = {}) -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -Terrain.GROUND_HALF.y, 0.0), Terrain.GROUND_HALF)
	for box in solid:
		if box == leave_out:
			continue
		world.add_static_box(box["position"], box["half_extents"])
	return world


func _the_simulation_has_every_street_and_every_road(solid: Array[Dictionary]) -> void:
	var world: Object = _world(solid)
	var shut: Array[String] = []
	var blocked_beside: int = 0
	var cities: int = 0
	for t in range(TownCatalogue.towns().size()):
		var town: Dictionary = TownCatalogue.towns()[t]
		if float(town["tower_radius"]) <= 0.0:
			continue
		cities += 1
		var centre: Vector3 = town["centre"]
		var run: float = float(town["radius"])
		var room: float = float(town["street"]) * 0.5 - 4.0
		# DOWN BOTH CENTRAL AVENUES at street level, with four metres to spare either side.
		for along in [Vector3.RIGHT, Vector3.BACK]:
			var from: Vector3 = centre - along * run + Vector3.UP * STREET_LEG_UP
			var to: Vector3 = centre + along * run + Vector3.UP * STREET_LEG_UP
			if not bool(world.leg_is_clear(from, to, room, 0.0)):
				shut.append("%s along %s" % [town["name"], along])
			# THE TWIN THAT MUST FAIL: the same leg down the middle of a row of blocks beside it -- either
			# side, because one side may be empty for a reason. The railway runs north-south through the
			# western city, and its corridor leaves the row at x = -3552 with no building from end to end.
			var aside := Vector3(along.z, 0.0, along.x) * float(town["block"]) * 0.5
			if not bool(world.leg_is_clear(from + aside, to + aside, room, 0.0)) 					or not bool(world.leg_is_clear(from - aside, to - aside, room, 0.0)):
				blocked_beside += 1
	_check("a_car_or_an_aeroplane_fits_down_every_citys_central_avenues", shut.is_empty() and cities > 0,
		"%d cities at %.0f m up, %s" % [cities, STREET_LEG_UP, "all open" if shut.is_empty() else "shut: " + "; ".join(shut)])
	_check("and_not_down_the_middle_of_its_blocks", blocked_beside == cities * 2,
		"%d of %d avenues have a blocked row of blocks beside them" % [blocked_beside, cities * 2])
	var through: Array[String] = []
	for road in Terrain.roads(solid):
		# A CAR'S LEG, with nothing below it counted and three metres either side.
		if not bool(world.leg_is_clear((road["from"] as Vector3) + Vector3.UP * 0.7,
				(road["to"] as Vector3) + Vector3.UP * 0.7, 3.0, 0.0)):
			through.append("%s to %s" % [(road["from"] as Vector3).round(), (road["to"] as Vector3).round()])
	_check("no_road_runs_through_a_building_or_a_mountain", through.is_empty(),
		"all clear" if through.is_empty() else "; ".join(through.slice(0, 4)))
	world.teardown()
	_sections += 1


## A BUILDING STOPS A SHELL AND HIDES A TARGET, and without it neither happens.
func _a_building_stops_a_shell_and_hides_a_target(solid: Array[Dictionary]) -> void:
	var wall: Dictionary = _a_wall_with_open_ground_in_front(solid)
	_check("there_is_a_building_with_room_to_shoot_at_it", not wall.is_empty(), "%s" % [wall.get("detail", "none")])
	if wall.is_empty():
		_sections += 1
		return
	var building: Dictionary = wall["building"]
	var face: Vector3 = wall["face"]
	var toward: Vector3 = wall["toward"]
	var with: Dictionary = _fire_at(solid, {}, wall)
	var stopped: float = ((with.get("impact", Vector3.INF) as Vector3) - face).dot(toward)
	_check("a_shell_fired_at_a_building_stops_at_its_wall",
		int(with.get("surface", -1)) == Ammunition.GROUND and absf(stopped) < 0.5,
		"surface %s at %s, %.3f m past the wall" % [with.get("surface", "-"), with.get("impact", "-"), stopped])
	var without: Dictionary = _fire_at(solid, building, wall)
	var flew_on: float = ((without.get("impact", face) as Vector3) - face).dot(toward)
	_check("and_with_that_building_taken_away_it_flies_on", flew_on > 5.0,
		"at %s, %.0f m past where the wall was" % [without.get("impact", "-"), flew_on])
	var hidden: bool = _missile_guided(solid, {}, wall)
	var seen: bool = _missile_guided(solid, building, wall)
	_check("a_seeker_cannot_see_a_target_behind_a_building", not hidden, "guided %s" % hidden)
	_check("and_with_that_building_taken_away_it_can", seen, "guided %s" % seen)
	_sections += 1


## SHOOTER, WALL AND TARGET IN A LINE, found rather than guessed: a building at least thirty metres
## tall, faced from any of the four sides it has, with eighty metres of open ground in front of that
## face at gun height, forty metres of open ground behind the far face for a target, and a missile's
## line from seven hundred metres further out that is open everywhere but through this building --
## all asked of the simulation. The first version only looked from the west, wanted a hundred and
## twenty metres, and found no building in any town with that much open ground in front of it.
func _a_wall_with_open_ground_in_front(solid: Array[Dictionary]) -> Dictionary:
	var world: Object = _world(solid)
	var found: Dictionary = {}
	var rejected: Dictionary = {"short": 0, "narrow": 0, "front": 0, "behind": 0, "misses": 0, "line": 0}
	for box in _buildings(solid):
		var at: Vector3 = box["position"]
		var half: Vector3 = box["half_extents"]
		if half.y * 2.0 < 30.0:
			rejected["short"] += 1
			continue
		for toward in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			var deep: float = absf((half * toward).length())
			var wide: float = absf((half * Vector3(toward.z, 0.0, toward.x)).length())
			if wide < 6.0:
				rejected["narrow"] += 1
				continue
			var face: Vector3 = Vector3(at.x, 0.0, at.z) - toward * deep
			var shooter: Vector3 = face - toward * 80.0 + Vector3.UP * 1.3
			var target: Vector3 = Vector3(at.x, 6.0, at.z) + toward * (deep + 40.0)
			# THE LEGS STOP FOUR METRES SHORT OF THE WALL, because a leg is fattened by its clearance: the first
			# version stopped one metre short with three to spare, and every one of 172 faces was "blocked" by
			# the building it was looking at.
			if not bool(world.leg_is_clear(shooter + Vector3.UP, face - toward * 4.0 + Vector3.UP * 2.3, 3.0, 0.0)):
				rejected["front"] += 1
				continue
			if not bool(world.leg_is_clear(Vector3(at.x, 6.0, at.z) + toward * (deep + 4.0), target + toward * 10.0, 3.0, 0.0)):
				rejected["behind"] += 1
				continue
			var launch: Vector3 = shooter - toward * 700.0 + Vector3.UP * 25.0
			var span: Vector2 = _through(launch, target, at, half)
			if span.x >= span.y:
				rejected["misses"] += 1
				continue
			if not bool(world.leg_is_clear(launch, launch.lerp(target, span.x - 0.002), 0.5, 0.0)) \
					or not bool(world.leg_is_clear(launch.lerp(target, span.y + 0.002), target, 0.5, 0.0)):
				rejected["line"] += 1
				continue
			found = {"building": box, "face": face, "toward": toward, "shooter": shooter, "target": target,
				"launch": launch, "detail": "%.0f m tall at %s, shot from %s" % [half.y * 2.0, at.round(), toward]}
			break
		if not found.is_empty():
			break
	if found.is_empty():
		print("[towns] no wall found; rejected: %s" % [rejected])
	world.teardown()
	return found


## The yaw whose nose (`Terrain.nose_from_yaw`) points along `toward`.
static func _yaw_along(toward: Vector3) -> float:
	return atan2(-toward.x, -toward.z)


func _fire_at(solid: Array[Dictionary], leave_out: Dictionary, wall: Dictionary) -> Dictionary:
	var world: Object = _world(solid, leave_out)
	var tank: int = int(world.spawn_vehicle(Sim.Kind.TANK, wall["shooter"], _yaw_along(wall["toward"]), Vector3.ZERO))
	for i in range(30):
		world.tick(TICK)
	var result: Dictionary = {}
	if int(world.fire_gun(tank, 0)) != 0:
		for i in range(600):
			world.tick(TICK)
			var shots: Array = world.shot_states()
			if shots.is_empty():
				break
			if not bool((shots[0] as Dictionary)["flying"]):
				result = {"impact": shots[0]["impact"], "surface": int(shots[0]["surface"])}
				break
	world.teardown()
	return result


## Whether a radar missile, launched low at a target parked behind the building, is still guiding
## a third of a second after it leaves the rail. `seen_from` is the one function a seat's lock and a
## missile's seeker both ask, so this is the seat's question too.
func _missile_guided(solid: Array[Dictionary], leave_out: Dictionary, wall: Dictionary) -> bool:
	var world: Object = _world(solid, leave_out)
	var radar: int = _type_named(world, "radar")
	world.set_missile_type(radar, {"ground": true})
	var toward: Vector3 = wall["toward"]
	var launcher: int = int(world.spawn_vehicle(Sim.Kind.PLANE, wall["launch"], _yaw_along(toward), toward * 120.0))
	var target: int = int(world.spawn_vehicle(Sim.Kind.TOWER, wall["target"], 0.0, Vector3.ZERO))
	world.tick(TICK)
	var missile: int = int(world.launch_missile(launcher, _station_named(world, "radar"), target))
	var guided: bool = false
	for i in range(40):
		world.tick(TICK)
	for row in world.missile_states():
		if int(row["entity"]) == missile:
			guided = bool(row["guided"])
	world.teardown()
	return guided


## Where the segment a..b is inside the box, as fractions along it, (enter, leave); enter >= leave
## when it misses. The slab test, written here rather than borrowed from the simulation it checks.
static func _through(a: Vector3, b: Vector3, centre: Vector3, half: Vector3) -> Vector2:
	var enter: float = 0.0
	var leave: float = 1.0
	var d: Vector3 = b - a
	for axis in range(3):
		var lo: float = centre[axis] - half[axis]
		var hi: float = centre[axis] + half[axis]
		if absf(d[axis]) < 0.000001:
			if a[axis] < lo or a[axis] > hi:
				return Vector2(1.0, 0.0)
			continue
		var t1: float = (lo - a[axis]) / d[axis]
		var t2: float = (hi - a[axis]) / d[axis]
		enter = maxf(enter, minf(t1, t2))
		leave = minf(leave, maxf(t1, t2))
	return Vector2(enter, leave)


## ---- the grid the level asks where a machine may go -------------------------------------

## THE BOX GRID GIVES THE WALK'S ANSWERS. `BoxGrid` exists to make boot cheap (see its header), and a cheaper answer
## that is a different answer is a waypoint inside a building; so the grid is held to `Terrain._clear_of` itself.
func _the_grid_answers_as_the_walk_does(solid: Array[Dictionary]) -> void:
	var grid := BoxGrid.new(solid)
	# EVERY WAYPOINT POOL, both ways: the pool the grid builds against the one the plain walk builds, point for point.
	var differ: Array[String] = []
	for kind in [Sim.Kind.PLANE, Sim.Kind.HELI, Sim.Kind.CAR, Sim.Kind.BOAT, Sim.Kind.OSPREY, Sim.Kind.CESSNA]:
		var filed: Array[Vector3] = Terrain.waypoints(kind, grid)
		var walked: Array[Vector3] = Terrain.waypoints(kind, _WalkEverything.new(solid))
		if filed != walked:
			differ.append("%s: %d against %d" % [Sim.kind_name(kind), filed.size(), walked.size()])
	_check("the_waypoints_are_the_same_filed_by_place_as_walked_box_by_box", differ.is_empty(),
		"six pools identical" if differ.is_empty() else "; ".join(differ))
	# AND FOUR THOUSAND POINTS NOBODY CHOSE, near buildings and cell edges as often as not: every one of them the same
	# answer, at rooms from nothing to beyond a cell.
	var disagree: int = 0
	var blocked: int = 0
	for i in range(4000):
		var box: Dictionary = solid[i % solid.size()]
		var near: Vector3 = (box["position"] as Vector3) + Vector3(
			(Terrain.hash01(i, 8101) - 0.5) * 2.0 * ((box["half_extents"] as Vector3).x + 80.0),
			(Terrain.hash01(i, 8102) - 0.5) * 2.0 * ((box["half_extents"] as Vector3).y + 40.0),
			(Terrain.hash01(i, 8103) - 0.5) * 2.0 * ((box["half_extents"] as Vector3).z + 80.0))
		var room: float = Terrain.hash01(i, 8104) * 300.0
		var walked: bool = Terrain._clear_of(solid, near, room)
		if not walked:
			blocked += 1
		if grid.is_clear_of(near, room) != walked:
			disagree += 1
	_check("and_so_is_every_answer_about_four_thousand_points_nobody_chose", disagree == 0 and blocked > 1000,
		"%d disagree; %d of 4000 blocked, so both answers were asked" % [disagree, blocked])
	_sections += 1


## The plain walk wearing the grid's one method, so `Terrain.waypoints` can be asked both ways. Duck-typed: waypoints
## takes a BoxGrid, so this EXTENDS BoxGrid and overrides the method.
class _WalkEverything extends BoxGrid:
	var _all: Array[Dictionary]
	func _init(solid: Array[Dictionary]) -> void:
		var nothing: Array[Dictionary] = []
		super(nothing)
		_all = solid
	func is_clear_of(at: Vector3, room: float) -> bool:
		return Terrain._clear_of(_all, at, room)


static func _type_named(world: Object, wanted: String) -> int:
	for row in world.missile_types():
		if String(row["name"]) == wanted:
			return int(row["id"])
	return -1


static func _station_named(world: Object, wanted: String) -> int:
	for station in (world.missile_schema(Sim.Kind.PLANE) as Dictionary).get("stations", []):
		if String(station["name"]) == wanted:
			return int(station["station"])
	return -1


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
