extends RefCounted
class_name TownPlan
## A TOWN'S STREETS AND BUILDINGS, AND THE ROADS BETWEEN TOWNS, grown from `TownCatalogue` with the
## world's own hash.
##
## ONE BUILDING IS ONE RECORD IS ONE BOX. A record is the dictionary `Terrain.boxes()` hands out --
## `{position, half_extents, group, roof, seed, town}` -- so the collision the level gives the
## simulation, the instance the town is drawn with and the red lights on its roof are all read off
## the same dictionary, and none of them can be somewhere the others are not.
##
## THE RANDOMNESS IS `Terrain.hash01`, for the reason the note at the top of Terrain gives: static
## collision is not replicated, and a town that grew differently on one peer is a peer flying
## through a tower the server says is there.
##
## THE GRID: streets on every multiple of the town's `block` from its centre, both ways, so two
## avenues cross at the centre; a block between four streets; a block split into one or four lots;
## a building on a lot unless the hash leaves it empty. How likely a lot is to be empty, how tall
## its building is and how likely a block is to be split all move from the centre's number to the
## edge's along a smoothstep of distance over radius. Towers take a whole block and stand only
## inside `tower_radius`.
##
## A building is kept or dropped WHOLE: one that meets a clearance or a mountain is not built at
## all, which is how `_city` treated its towers and how `_peak` treats a mountain.

enum Roof { FLAT, PLANT, PITCHED, SETBACK }


## EVERY BUILDING IN EVERY TOWN, appended to `out`. `out` already holds the mountains, which a
## building must also stand clear of; `clear` is the list nothing may be generated into.
static func build(out: Array[Dictionary], clear: Array[Dictionary]) -> void:
	var standing: Array[Dictionary] = out.duplicate()
	var towns: Array[Dictionary] = TownCatalogue.towns()
	var built: int = 0
	for t in range(towns.size()):
		built += _town(out, clear, standing, towns, t, TownTuning.MOST_BUILDINGS - built)


## How many blocks out from the centre a town's grid may reach, either way.
static func blocks_out(town: Dictionary) -> int:
	return int(ceil(float(town["radius"]) * (1.0 + TownTuning.RAGGED) / float(town["block"])))


static func _town(out: Array[Dictionary], clear: Array[Dictionary], standing: Array[Dictionary],
		towns: Array[Dictionary], t: int, room: int) -> int:
	var town: Dictionary = towns[t]
	var centre: Vector3 = town["centre"]
	var block: float = town["block"]
	var radius: float = town["radius"]
	var inside: float = block - float(town["street"])
	var reach: int = blocks_out(town)
	var built: int = 0
	# ONLY WHAT IS NEAR THIS TOWN IS ASKED ABOUT. Every candidate building was tested against all 621 clearances and
	# every mountain box, and Terrain.boxes() went from 42.5 ms to 163.7 ms with the towns in it (boot_probe,
	# 2026-09-13) -- most of those tests against a railway sample or a spawn kilometres away. A keep-out that cannot
	# touch the town's square cannot touch a building in it.
	var square := {"position": centre + Vector3(0.0, 200.0, 0.0),
		"half_extents": Vector3(float(reach) * block, 200.0, float(reach) * block)}
	clear = _touching(clear, square)
	standing = _touching(standing, square)
	for i in range(-reach, reach):
		for j in range(-reach, reach):
			var offset := Vector2((float(i) + 0.5) * block, (float(j) + 0.5) * block)
			var middle: Vector3 = centre + Vector3(offset.x, 0.0, offset.y)
			var salt: int = _salt(t, i, j, 0)
			var edge: float = radius * (1.0 + TownTuning.RAGGED * (2.0 * Terrain.hash01(salt, 1) - 1.0))
			var away: float = offset.length()
			if away > edge:
				continue
			var out_t: float = clampf(away / radius, 0.0, 1.0)
			var ease: float = smoothstep(0.0, 1.0, out_t)
			if away < float(town["tower_radius"]) and Terrain.hash01(salt, 2) < float(town["tower_share"]):
				var tall: float = lerpf(float(town["tower_low"]), float(town["tower_high"]),
					Terrain.hash01(salt, 3))
				var margin: float = _margin(salt, 4)
				built += _put(out, clear, standing, room - built, middle,
					Vector2(inside * 0.5 - margin, inside * 0.5 - _margin(salt, 5)), tall, Roof.SETBACK, salt, t,
					town["name"])
				continue
			var split: int = 2 if Terrain.hash01(salt, 6) < lerpf(TownTuning.SPLIT_NEAR, TownTuning.SPLIT_FAR, ease) else 1
			var lot: float = (inside - TownTuning.ALLEY * float(split - 1)) / float(split)
			for a in range(split):
				for b in range(split):
					var lot_salt: int = _salt(t, i, j, 1 + a * 2 + b)
					if Terrain.hash01(lot_salt, 7) < lerpf(float(town["empty_near"]), float(town["empty_far"]), ease):
						continue
					var at: Vector3 = middle + Vector3(
						(float(a) - float(split - 1) * 0.5) * (lot + TownTuning.ALLEY), 0.0,
						(float(b) - float(split - 1) * 0.5) * (lot + TownTuning.ALLEY))
					var high: float = lerpf(float(town["core_height"]), float(town["edge_height"]), ease) \
						* (0.55 + 0.9 * Terrain.hash01(lot_salt, 8))
					var half := Vector2(lot * 0.5 - _margin(lot_salt, 9), lot * 0.5 - _margin(lot_salt, 10))
					built += _put(out, clear, standing, room - built, at, half, high,
						_roof_for(high, half, lot_salt), lot_salt, t, town["name"])
	return built


## ONE BUILDING, if it may stand here: whole or not at all. It stands on `at.y`, its town's ground: the island's slab
## at 0, or on the generated ground the level of the site the town is seated on (`TownCatalogue.towns`).
static func _put(out: Array[Dictionary], clear: Array[Dictionary], standing: Array[Dictionary],
		room: int, at: Vector3, half: Vector2, high: float, roof: int, salt: int, t: int, town_name: StringName) -> int:
	var storeys: float = maxf(ceil(high / TownTuning.STOREY), 2.0)
	var tall: float = storeys * TownTuning.STOREY
	var extents := Vector3(half.x, tall * 0.5, half.y)
	var centre := Vector3(at.x, at.y + tall * 0.5, at.z)
	if half.x < 2.0 or half.y < 2.0:
		return 0
	if not Terrain.is_clear(clear, centre, extents) or not Terrain.is_clear(standing, centre, extents):
		return 0
	if room <= 0:
		# A COUNT LIMIT DROPS AND SAYS SO. See TownTuning.MOST_BUILDINGS.
		push_warning("[towns] %s: the world is at its %d buildings; this one is not built" % [
			town_name, TownTuning.MOST_BUILDINGS])
		return 0
	out.append({"position": centre, "half_extents": extents, "group": Terrain.Group.BUILDING,
		"roof": roof, "seed": salt, "town": t})
	return 1


## The boxes of `keep` that overlap `area`, with any yaw widened the way `Terrain.is_clear` widens it.
static func _touching(keep: Array[Dictionary], area: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var half: Vector3 = area["half_extents"]
	for box in keep:
		if not Terrain.is_clear([box], area["position"], half):
			out.append(box)
	return out


static func _roof_for(high: float, half: Vector2, salt: int) -> int:
	if high <= TownTuning.PITCHED_HIGH and minf(half.x, half.y) * 2.0 <= TownTuning.PITCHED_WIDE:
		return Roof.PITCHED
	if high > TownTuning.PLANT_HIGH and Terrain.hash01(salt, 11) < TownTuning.PLANT_SHARE:
		return Roof.PLANT
	return Roof.FLAT


static func _margin(salt: int, which: int) -> float:
	return lerpf(TownTuning.LOT_MARGIN_MIN, TownTuning.LOT_MARGIN_MAX, Terrain.hash01(salt, which))


## A seed no other part of the world uses: towns start well above the peaks' and gates' salts.
static func _salt(t: int, i: int, j: int, lot: int) -> int:
	return 500000 + t * 100000 + (i + 64) * 1000 + (j + 64) * 8 + lot


## ---- streets ----------------------------------------------------------------------------

## EVERY STREET IN EVERY TOWN, as flat paint for the renderer: `{position, half_extents, yaw,
## colour}`, the shape `Terrain.runway_marks` uses. Each street runs as far as a block beside it
## could have been built, so the grid ends where the town does rather than in a square of empty
## streets round it.
static func streets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for town in TownCatalogue.towns():
		var centre: Vector3 = town["centre"]
		var block: float = town["block"]
		var width: float = town["street"]
		var reach: int = blocks_out(town)
		var edge: float = float(town["radius"]) * (1.0 + TownTuning.RAGGED)
		# ON A SEATED TOWN, NO STREET PAST ITS FLAT. The ground holds the site's level only out to the site's radius, and a street
		# is one level mark -- TownView's lamps stand on its top and their pools lie flat on it -- so a street run on into the
		# blend would float over falling ground or sink into rising ground: rounded up to the block, eastern's reached 576 m on
		# a 524 m flat. It ends at the last crossing inside the flat instead. The island's towns carry no site, and are as they were.
		var flat: float = float((town["site"] as Dictionary)["r"]) if town.has("site") else INF
		for k in range(-reach, reach + 1):
			var across: float = float(k) * block
			if absf(across) > edge or absf(across) > flat:
				continue
			var run: float = ceil(sqrt(edge * edge - across * across) / block) * block
			if flat < INF:
				run = minf(run, floor(sqrt(flat * flat - across * across) / block) * block)
			if run <= 0.0:
				continue
			out.append({"position": centre + Vector3(0.0, TownTuning.STREET_TOP * 0.5, across),
				"half_extents": Vector3(run, TownTuning.STREET_TOP * 0.5, width * 0.5),
				"yaw": 0.0, "colour": TownTuning.ASPHALT, "block": block})
			out.append({"position": centre + Vector3(across, TownTuning.STREET_TOP * 0.5, 0.0),
				"half_extents": Vector3(width * 0.5, TownTuning.STREET_TOP * 0.5, run),
				"yaw": 0.0, "colour": TownTuning.ASPHALT, "block": block})
	return out


## ---- roads ------------------------------------------------------------------------------

## EVERY ROAD BETWEEN TOWNS, as straight lengths `{from, to, width, link}`: a spanning tree over the
## town centres, so every town can be driven to, plus `EXTRA_LINKS` of the shortest links left over,
## so there is a loop to fly along.
##
## A ROAD LEAVES A TOWN DOWN ITS CENTRAL AVENUE, at the end of the grid on the side facing the other
## town, so it is the street carried on rather than a line that stops short of it. A link that meets
## a clearance, a mountain, a building or another town is tried again through a dogleg either side
## of its middle; one that finds no way is dropped with a warning, and `tests/towns.gd` fails if that
## leaves any town cut off.
##
## Clearances tagged `rail` do not stop a road. Two cities sit on the railway loop, so a road that
## could not cross it could not leave them: it crosses at a level crossing.
static func roads(solid: Array[Dictionary], clear: Array[Dictionary]) -> Array[Dictionary]:
	var towns: Array[Dictionary] = TownCatalogue.towns()
	var out: Array[Dictionary] = []
	if towns.size() < 2:
		return out
	var keep_out: Array[Dictionary] = []
	for keep in clear:
		if keep.get("why", &"") != &"rail":
			keep_out.append(keep)
	# PRIM'S, from the first town, in catalogue order on ties, so it is the same tree everywhere.
	var joined: Array[int] = [0]
	var links: Array[Vector2i] = []
	while joined.size() < towns.size():
		var best := Vector2i(-1, -1)
		var best_length: float = INF
		for a in joined:
			for b in range(towns.size()):
				if joined.has(b):
					continue
				var length: float = _between(a, b)
				if length < best_length:
					best_length = length
					best = Vector2i(a, b)
		joined.append(best.y)
		links.append(best)
	var spare: Array[Vector2i] = []
	for a in range(towns.size()):
		for b in range(a + 1, towns.size()):
			if not links.has(Vector2i(a, b)) and not links.has(Vector2i(b, a)) \
					and _between(a, b) <= TownTuning.EXTRA_LINK_LONGEST:
				spare.append(Vector2i(a, b))
	spare.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return _between(p.x, p.y) < _between(q.x, q.y))
	var extras: int = 0
	for link in links:
		if not _lay(out, link, solid, keep_out):
			push_warning("[towns] no road could be laid from %s to %s" % [towns[link.x]["name"], towns[link.y]["name"]])
	for link in spare:
		if extras >= TownTuning.EXTRA_LINKS:
			break
		if _lay(out, link, solid, keep_out):
			extras += 1
	return out


## THE ROADS AS PAINT, in the runway's `{position, half_extents, yaw, colour}`: one slab per straight
## length, turned to lie along it. The yaw is the one `Terrain.nose_from_yaw` reads back, so a slab's
## long axis is the road's.
static func road_marks(roads: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for road in roads:
		var a: Vector3 = road["from"]
		var b: Vector3 = road["to"]
		var d: Vector3 = b - a
		var mark: Dictionary = {"position": (a + b) * 0.5 + Vector3(0.0, TownTuning.ROAD_TOP * 0.5, 0.0),
			"half_extents": Vector3(float(road["width"]) * 0.5, TownTuning.ROAD_TOP * 0.5, d.length() * 0.5),
			"yaw": atan2(-d.x, -d.z), "colour": TownTuning.ASPHALT}
		# A PIECE ON A SLOPE is pitched to lie along it, nose up by its rise over its run about its own across axis (TownView
		# turns it so); a level road -- every road on the island -- carries no pitch (increment B5).
		if d.y != 0.0:
			mark["pitch"] = atan2(d.y, Vector2(d.x, d.z).length())
		out.append(mark)
	return out


## THE GROUND EVERY ROAD NEEDS KEPT CLEAR, for anything grown on the ground after the towns --
## forests -- as yawed boxes `{position, half_extents, yaw}` in the shape `Terrain.is_clear` reads.
## Half-width is the road's and its verge; the yaw is the paint's, so the corridor and the drawn road
## lie along the same line.
static func road_keepouts(roads: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var marks: Array[Dictionary] = road_marks(roads)
	for i in range(marks.size()):
		var mark: Dictionary = marks[i]
		var half: Vector3 = mark["half_extents"]
		# A PITCHED PIECE'S CORRIDOR stands over both its ends: taller by half its rise (increment B5; a level road's is as it was).
		var rise: float = absf((roads[i]["to"] as Vector3).y - (roads[i]["from"] as Vector3).y)
		out.append({"position": (mark["position"] as Vector3) + Vector3(0.0, 2.0, 0.0),
			"half_extents": Vector3(half.x + TownTuning.ROAD_VERGE, 2.0 + rise * 0.5, half.z),
			"yaw": float(mark["yaw"])})
	return out


## ---- roads on the generated ground (increment B5) ----------------------------------------------------------------

## The generated ground the roads were last worked out for, and the roads.
static var _ground_roads_of: Object = null
static var _ground_roads: Array[Dictionary] = []
## What the last working-out found, for the test's detail and the commit: places, links laid, links left out by name,
## pairs no road reached, grid steps walked at the pieces' points and those found too steep, pieces, kilometres, the
## steepest piece as a share of its run, and milliseconds.
static var last_tally: Dictionary = {}
## How many times a link's route may be found again round the steep steps found on it before the link is left out.
const ROAD_REPAIRS: int = 24
## Why `_road_for` last found no road, for the warning about a place no road reaches.
static var _refusal: String = ""
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1),
	Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## ROADS ON THE GENERATED GROUND (increment B5, team-lead, 2026-09-15): between the seated towns and the airfield strips,
## lying on the ground, off the water and never up a cliff, by the simplest routing that looks right.
##
## THE PLACES are the seated towns in catalogue order and then the strips, and the pieces' `link`s number them so. They are
## joined SHORTEST PAIR FIRST by straight distance (Kruskal's): a pair not yet joined is routed, and joined if a road reaches,
## so a pair no road reaches gives way to the next shortest. Prim's tree over the same distances, as the island's towns
## use, left hollow and a strip apart when its one link found only a 56 km way round (2026-09-15). A road leaves a town
## down its central avenue (`road_end`) and meets a strip ROAD_STRIP_SIDE off whichever long side faces the other place.
##
## EACH LINK is routed by A* on a ROAD_GRID grid of the ground: never onto a cell with water anywhere on it, into another
## place's ground (a town's site and margin, a strip and its margin), or up a step that rises more than ROAD_GRADE of its
## run, costing more the steeper it climbs, and giving up past ROAD_DETOUR times the straight distance. The grid's route
## is then PULLED STRAIGHT -- from each point, on to the
## farthest later point a straight line reaches keeping the same three rules -- so a road runs down a valley in long
## straights rather than a grid's 45-degree staircase. The line is cut into ROAD_PIECE pieces whose ends stand on the
## ground.
##
## NO PIECE CLIMBS MORE THAN ROAD_CLIFF OF ITS RUN, and the grid cannot see that: its points straddle banks and gullies.
## The first alpine routes left 6 of 9 links out, each with 11 to 36 pieces rising 59 to 97 %, mid-route on valley floors
## (2026-09-15). So every step of a found route is walked at the pieces' own points (`_steepest_between`), each steep step
## is forbidden, for every later route too, and the route found again, at most ROAD_REPAIRS times; a straight is walked the same way. A
## link with a piece's middle on water, a steep piece still left, or no route is not laid; a place no road reaches is warned of.
## Worked out once per ground.
static func roads_on_the_ground() -> Array[Dictionary]:
	var field: Object = Terrain.standing_on()
	if field == null:
		return []
	if field == _ground_roads_of:
		return _ground_roads
	var began: int = Time.get_ticks_usec()
	_ground_roads_of = field
	_ground_roads = []
	var places: Array[Dictionary] = _places_on_the_ground(field)
	var left_out: Array[String] = []
	last_tally = {"places": places.size(), "laid": 0, "left_out": left_out, "not_reached": 0, "steep_steps": 0}
	if places.size() < 2:
		return _ground_roads
	# THE GRID, square about the middle over the land's reach: the ground's height at each point, and whether a cell has water
	# anywhere the half-grid over it sees -- its middle, its corners and its edges' middles -- so a step between two dry
	# points does not cross a shore the grid missed. One `heights_at` call and one `waters_at` call.
	var n: int = ceili(2.0 * Terrain.land_reach() / TownTuning.ROAD_GRID)
	var corner := Vector2(-0.5, -0.5) * TownTuning.ROAD_GRID * float(n)
	var points := PackedInt32Array()
	points.resize(n * n * 2)
	for j in range(n):
		for i in range(n):
			var at: Vector3 = _grid_point(corner, i, j)
			points[(j * n + i) * 2] = roundi(at.x)
			points[(j * n + i) * 2 + 1] = roundi(at.z)
	var ticks: PackedInt32Array = field.call("heights_at", points)
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for k in range(n * n):
		heights[k] = float(ticks[k]) / Terrain.GROUND_TICKS_PER_METRE
	var m: int = 2 * n + 1
	var half_grid: float = TownTuning.ROAD_GRID * 0.5
	var fine := PackedInt32Array()
	fine.resize(m * m * 2)
	for j in range(m):
		for i in range(m):
			fine[(j * m + i) * 2] = roundi(corner.x + float(i) * half_grid)
			fine[(j * m + i) * 2 + 1] = roundi(corner.y + float(j) * half_grid)
	var waters: PackedInt32Array = field.call("waters_at", fine)
	var no_water: int = ClassDB.class_get_integer_constant("GroundField", "NO_WATER")
	var wet := PackedByteArray()
	wet.resize(n * n)
	for j in range(n):
		for i in range(n):
			for dj in range(3):
				for di in range(3):
					if waters[(2 * j + dj) * m + 2 * i + di] > no_water:
						wet[j * n + i] = 1
	# THE LINKS, SHORTEST FIRST (Kruskal's): every pair of places by straight distance; a pair not yet joined is routed, and
	# joined if a road reaches, so a pair no road reaches gives way to the next shortest that does.
	var pairs: Array[Vector2i] = []
	for a in range(places.size()):
		for b in range(a + 1, places.size()):
			pairs.append(Vector2i(a, b))
	pairs.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return _pair_length(places, p) < _pair_length(places, q))
	var group: Array[int] = []
	for p in range(places.size()):
		group.append(p)
	# THE STEPS WALKED, and those found steep, kept for every pair: a step is a bank whichever road walks it.
	var walked: Dictionary = {}
	var forbidden: Dictionary = {}
	var refusals: Array = []
	for link in pairs:
		if _group_of(group, link.x) == _group_of(group, link.y):
			continue
		var pieces: Array[Dictionary] = _road_for(link, places, heights, wet, corner, n, walked, forbidden)
		if pieces.is_empty():
			last_tally["not_reached"] = int(last_tally["not_reached"]) + 1
			refusals.append([link, "%s to %s: %s" % [places[link.x]["name"], places[link.y]["name"], _refusal]])
			continue
		group[_group_of(group, link.x)] = _group_of(group, link.y)
		_ground_roads.append_array(pieces)
		last_tally["laid"] = int(last_tally["laid"]) + 1
	for p in range(places.size()):
		if _group_of(group, p) != _group_of(group, 0):
			var why: Array[String] = []
			for refusal in refusals:
				if (refusal[0] as Vector2i).x == p or (refusal[0] as Vector2i).y == p:
					why.append(String(refusal[1]))
			push_warning("[roads] no road reaches %s at %s from %s; nearest first: %s" % [places[p]["name"], (places[p]["at"] as Vector3).round(),
				places[0]["name"], "; ".join(why.slice(0, 4))])
			left_out.append(String(places[p]["name"]))
	last_tally["steep_steps"] = forbidden.size()
	last_tally["steps_walked"] = walked.size()
	var metres: float = 0.0
	var steepest: float = 0.0
	for road in _ground_roads:
		var run: float = _flat(road["from"]).distance_to(_flat(road["to"]))
		metres += run
		steepest = maxf(steepest, absf((road["to"] as Vector3).y - (road["from"] as Vector3).y) / maxf(run, 0.001))
	last_tally["pieces"] = _ground_roads.size()
	last_tally["km"] = snappedf(metres / 1000.0, 0.1)
	last_tally["steepest"] = snappedf(steepest, 0.001)
	last_tally["ms"] = roundi(float(Time.get_ticks_usec() - began) / 1000.0)
	return _ground_roads


## ONE LINK'S ROAD, as pieces, or empty if no road reaches: routed on the grid round the other places, found again round
## every steep step at most ROAD_REPAIRS times, pulled straight and cut into pieces. `walked` and `forbidden` are the steps
## already asked of the ground and those found steep, shared by every pair.
static func _road_for(link: Vector2i, places: Array[Dictionary], heights: PackedFloat32Array, wet: PackedByteArray, corner: Vector2,
		n: int, walked: Dictionary, forbidden: Dictionary) -> Array[Dictionary]:
	var from: Dictionary = places[link.x]
	var to: Dictionary = places[link.y]
	var start: Vector3 = _end_at(from, to)
	var finish: Vector3 = _end_at(to, from)
	var keeps: Array[Rect2] = []
	var blocked := PackedByteArray()
	blocked.resize(n * n)
	for p in range(places.size()):
		if p != link.x and p != link.y:
			keeps.append(places[p]["keep"])
			_block(blocked, corner, n, places[p]["keep"])
	var most_cost: float = TownTuning.ROAD_DETOUR * _flat(start).distance_to(_flat(finish)) + 2.0 * TownTuning.ROAD_GRID
	var cells := PackedInt32Array()
	for attempt in range(ROAD_REPAIRS):
		cells = _route(heights, wet, blocked, n, _grid_cell(corner, n, start), _grid_cell(corner, n, finish), forbidden, most_cost)
		var steep: int = 0
		for k in range(cells.size() - 1):
			var key: int = _edge_key(cells[k], cells[k + 1], n)
			if walked.has(key):
				continue
			walked[key] = true
			var here: Vector3 = _grid_point(corner, cells[k] % n, _row(cells[k], n))
			var there: Vector3 = _grid_point(corner, cells[k + 1] % n, _row(cells[k + 1], n))
			if _steepest_between(here, there) > TownTuning.ROAD_CLIFF:
				forbidden[key] = true
				steep += 1
		if cells.is_empty() or steep == 0:
			break
	var pieces: Array[Dictionary] = []
	if cells.is_empty():
		_refusal = "no route off the water and the other places, under %.0f%% a grid step and %.0f times the straight distance" % [
			TownTuning.ROAD_GRADE * 100.0, TownTuning.ROAD_DETOUR]
		return pieces
	var line: Array[Vector3] = [start]
	for cell in cells:
		line.append(_grid_point(corner, cell % n, _row(cell, n)))
	line.append(finish)
	_refusal = _cut_into_pieces(_pulled_straight(line, keeps), link, pieces)
	if _refusal != "":
		pieces.clear()
	return pieces


static func _pair_length(places: Array[Dictionary], pair: Vector2i) -> float:
	return _flat(places[pair.x]["at"]).distance_to(_flat(places[pair.y]["at"]))


## The group a place belongs to, following each place's group to the one that is its own.
static func _group_of(group: Array[int], p: int) -> int:
	while group[p] != p:
		p = group[p]
	return p


## The places the roads join, in the order their links number them: each seated town, its site and margin kept, and then
## each airfield strip, the strip and its margin kept, met ROAD_STRIP_SIDE off whichever long side faces the other place.
static func _places_on_the_ground(field: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var towns: Array[Dictionary] = TownCatalogue.towns()
	for t in range(towns.size()):
		var centre: Vector3 = towns[t]["centre"]
		var site: Dictionary = towns[t].get("site", {})
		var room: float = float(site.get("r", towns[t]["radius"])) + float(site.get("margin", 0.0))
		out.append({"name": String(towns[t]["name"]), "at": centre, "town": t,
			"keep": Rect2(centre.x - room, centre.z - room, 2.0 * room, 2.0 * room)})
	var strips: Array = (field.call("catalogue") as Dictionary).get("airfields", [])
	for s in range(strips.size()):
		var strip: Dictionary = strips[s]
		var middle := Vector2(float(strip["x"]), float(strip["z"]))
		var half_x: float = float(strip["half_long"])
		var half_z: float = float(strip["half_wide"])
		var margin: float = float(strip.get("margin", 0.0))
		var side := Vector2(0.0, half_z + TownTuning.ROAD_STRIP_SIDE) if half_x >= half_z else Vector2(half_x + TownTuning.ROAD_STRIP_SIDE, 0.0)
		out.append({"name": "strip %d" % s, "at": Vector3(middle.x, 0.0, middle.y), "side": Vector3(side.x, 0.0, side.y), "town": -1,
			"keep": Rect2(middle.x - half_x - margin, middle.y - half_z - margin, 2.0 * (half_x + margin), 2.0 * (half_z + margin))})
	return out


static func _end_at(place: Dictionary, toward: Dictionary) -> Vector3:
	if int(place["town"]) >= 0:
		return road_end(int(place["town"]), toward["at"])
	var side: Vector3 = place["side"]
	var facing: bool = ((toward["at"] as Vector3) - (place["at"] as Vector3)).dot(side) >= 0.0
	return (place["at"] as Vector3) + (side if facing else -side)


static func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)


static func _grid_point(corner: Vector2, i: int, j: int) -> Vector3:
	return Vector3(corner.x + (float(i) + 0.5) * TownTuning.ROAD_GRID, 0.0, corner.y + (float(j) + 0.5) * TownTuning.ROAD_GRID)


static func _grid_cell(corner: Vector2, n: int, at: Vector3) -> int:
	var i: int = clampi(floori((at.x - corner.x) / TownTuning.ROAD_GRID), 0, n - 1)
	var j: int = clampi(floori((at.z - corner.y) / TownTuning.ROAD_GRID), 0, n - 1)
	return j * n + i


static func _row(cell: int, n: int) -> int:
	return floori(float(cell) / float(n))


## Every cell whose middle is inside `keep`, marked in `blocked`.
static func _block(blocked: PackedByteArray, corner: Vector2, n: int, keep: Rect2) -> void:
	var first := Vector2i(clampi(floori((keep.position.x - corner.x) / TownTuning.ROAD_GRID), 0, n - 1),
		clampi(floori((keep.position.y - corner.y) / TownTuning.ROAD_GRID), 0, n - 1))
	var last := Vector2i(clampi(floori((keep.end.x - corner.x) / TownTuning.ROAD_GRID), 0, n - 1),
		clampi(floori((keep.end.y - corner.y) / TownTuning.ROAD_GRID), 0, n - 1))
	for j in range(first.y, last.y + 1):
		for i in range(first.x, last.x + 1):
			if keep.has_point(_flat(_grid_point(corner, i, j))):
				blocked[j * n + i] = 1


## A* ON THE GRID from `start` to `goal`: the cells in order, or empty if there is no way. A step may not end on water or in
## a blocked cell (the goal excepted), be `forbidden`, or rise or fall more than ROAD_GRADE of its run; it costs its run, up to twice that
## the steeper it is. The search gives up once the cheapest way still open would cost more than `most_cost`.
static func _route(heights: PackedFloat32Array, wet: PackedByteArray, blocked: PackedByteArray, n: int, start: int, goal: int,
		forbidden: Dictionary, most_cost: float) -> PackedInt32Array:
	var best := PackedFloat32Array()
	best.resize(n * n)
	best.fill(INF)
	var came := PackedInt32Array()
	came.resize(n * n)
	came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(n * n)
	var heap_cost: Array[float] = []
	var heap_cell: Array[int] = []
	best[start] = 0.0
	_heap_push(heap_cost, heap_cell, _estimate(start, goal, n), start)
	while not heap_cell.is_empty() and heap_cost[0] <= most_cost:
		var cell: int = _heap_pop(heap_cost, heap_cell)
		if closed[cell] == 1:
			continue
		closed[cell] = 1
		if cell == goal:
			break
		for d in NEIGHBOURS:
			var i: int = cell % n + d.x
			var j: int = _row(cell, n) + d.y
			if i < 0 or j < 0 or i >= n or j >= n:
				continue
			var next: int = j * n + i
			if closed[next] == 1 or wet[next] == 1 or (blocked[next] == 1 and next != goal) \
					or forbidden.has(_edge_key(cell, next, n)):
				continue
			var run: float = TownTuning.ROAD_GRID * (1.41421356 if d.x != 0 and d.y != 0 else 1.0)
			var grade: float = absf(heights[next] - heights[cell]) / run
			if grade > TownTuning.ROAD_GRADE:
				continue
			var cost: float = best[cell] + run * (1.0 + grade / TownTuning.ROAD_GRADE)
			if cost < best[next]:
				best[next] = cost
				came[next] = cell
				_heap_push(heap_cost, heap_cell, cost + _estimate(next, goal, n), next)
	if closed[goal] == 0:
		return PackedInt32Array()
	var backwards := PackedInt32Array([goal])
	while backwards[backwards.size() - 1] != start:
		backwards.append(came[backwards[backwards.size() - 1]])
	backwards.reverse()
	return backwards


static func _estimate(cell: int, goal: int, n: int) -> float:
	var dx: int = absi(cell % n - goal % n)
	var dz: int = absi(_row(cell, n) - _row(goal, n))
	return TownTuning.ROAD_GRID * (float(maxi(dx, dz)) + 0.41421356 * float(mini(dx, dz)))


static func _heap_push(costs: Array[float], cells: Array[int], cost: float, cell: int) -> void:
	costs.append(cost)
	cells.append(cell)
	var k: int = costs.size() - 1
	while k > 0:
		var parent: int = (k - 1) >> 1
		if costs[parent] <= costs[k]:
			break
		_heap_swap(costs, cells, parent, k)
		k = parent


static func _heap_pop(costs: Array[float], cells: Array[int]) -> int:
	var top: int = cells[0]
	var last: int = costs.size() - 1
	_heap_swap(costs, cells, 0, last)
	costs.remove_at(last)
	cells.remove_at(last)
	var k: int = 0
	while true:
		var least: int = k
		for child in [2 * k + 1, 2 * k + 2]:
			if child < costs.size() and costs[child] < costs[least]:
				least = child
		if least == k:
			break
		_heap_swap(costs, cells, least, k)
		k = least
	return top


static func _heap_swap(costs: Array[float], cells: Array[int], p: int, q: int) -> void:
	var cost: float = costs[p]
	costs[p] = costs[q]
	costs[q] = cost
	var cell: int = cells[p]
	cells[p] = cells[q]
	cells[q] = cell


## THE GRID'S ROUTE PULLED STRAIGHT: from each point on to the farthest later point a straight line reaches by `_straight_is_open`.
static func _pulled_straight(line: Array[Vector3], keeps: Array[Rect2]) -> Array[Vector3]:
	var out: Array[Vector3] = [line[0]]
	var i: int = 0
	while i < line.size() - 1:
		var j: int = i + 1
		while j + 1 < line.size() and _straight_is_open(line[i], line[j + 1], keeps):
			j += 1
		out.append(line[j])
		i = j
	return out


## Whether a straight road may run from `p` to `q` by the grid's own rules: no water at any point of it half a grid apart, none
## inside a kept place, no rise between points a grid apart of more than ROAD_GRADE of the run, and no piece past ROAD_CLIFF.
static func _straight_is_open(p: Vector3, q: Vector3, keeps: Array[Rect2]) -> bool:
	var half_grid: float = TownTuning.ROAD_GRID * 0.5
	var steps: int = maxi(2, ceili(_flat(p).distance_to(_flat(q)) / half_grid))
	var last: Vector3 = p
	var last_height: float = Terrain.ground_height(p)
	for s in range(1, steps + 1):
		var at: Vector3 = p.lerp(q, float(s) / float(steps))
		if Terrain.water_height(at) != -INF:
			return false
		for keep in keeps:
			if keep.has_point(_flat(at)):
				return false
		if s % 2 == 0 or s == steps:
			var height: float = Terrain.ground_height(at)
			if absf(height - last_height) > TownTuning.ROAD_GRADE * maxf(_flat(at).distance_to(_flat(last)), half_grid):
				return false
			last = at
			last_height = height
	return _steepest_between(p, q) <= TownTuning.ROAD_CLIFF


## THE STEEPEST PIECE a straight road from `p` to `q` would be cut into, as rise over run: the very points `_cut_into_pieces`
## stands its pieces' ends on, asked of the ground in one `heights_at` call.
static func _steepest_between(p: Vector3, q: Vector3) -> float:
	var run: float = _flat(p).distance_to(_flat(q))
	if run < 0.5:
		return 0.0
	var count: int = maxi(1, ceili(run / TownTuning.ROAD_PIECE))
	var points := PackedInt32Array()
	points.resize((count + 1) * 2)
	for c in range(count + 1):
		var at: Vector3 = p.lerp(q, float(c) / float(count))
		points[c * 2] = roundi(at.x)
		points[c * 2 + 1] = roundi(at.z)
	var ticks: PackedInt32Array = Terrain.standing_on().call("heights_at", points)
	var steepest: float = 0.0
	for c in range(count):
		steepest = maxf(steepest, absf(float(ticks[c + 1] - ticks[c])) / Terrain.GROUND_TICKS_PER_METRE / (run / float(count)))
	return steepest


## One key for the grid step between two cells, whichever way it is walked.
static func _edge_key(a: int, b: int, n: int) -> int:
	return mini(a, b) * n * n + maxi(a, b)


## THE LINE CUT INTO PIECES no longer than ROAD_PIECE, each end on the ground under it, appended to `pieces`; or why the link
## is left out: a piece's middle on water, or a piece steeper than ROAD_CLIFF.
static func _cut_into_pieces(line: Array[Vector3], link: Vector2i, pieces: Array[Dictionary]) -> String:
	var steepest: float = 0.0
	var steepest_at := Vector3.ZERO
	var steepest_along: float = 0.0
	var over: int = 0
	var along: float = 0.0
	for k in range(line.size() - 1):
		var run: float = _flat(line[k]).distance_to(_flat(line[k + 1]))
		if run < 0.5:
			continue
		var count: int = maxi(1, ceili(run / TownTuning.ROAD_PIECE))
		var p: Vector3 = line[k]
		p.y = Terrain.ground_height(p)
		for c in range(count):
			var q: Vector3 = line[k].lerp(line[k + 1], float(c + 1) / float(count))
			q.y = Terrain.ground_height(q)
			if Terrain.water_height((p + q) * 0.5) != -INF:
				return "a piece at %s is on water" % ((p + q) * 0.5).round()
			var grade: float = absf(q.y - p.y) / (run / float(count))
			if grade > TownTuning.ROAD_CLIFF:
				over += 1
			if grade > steepest:
				steepest = grade
				steepest_at = (p + q) * 0.5
				steepest_along = along + run * (float(c) + 0.5) / float(count)
			pieces.append({"from": p, "to": q, "width": TownTuning.ROAD_WIDTH, "link": link})
			p = q
		along += run
	if steepest > TownTuning.ROAD_CLIFF:
		return "%d pieces rise more than the %.0f%% of their run a road may, the steepest %.0f%% at %s, %.0f m along its %.0f m" % [over,
			TownTuning.ROAD_CLIFF * 100.0, steepest * 100.0, steepest_at.round(), steepest_along, along]
	return ""


static func _between(a: int, b: int) -> float:
	var towns: Array[Dictionary] = TownCatalogue.towns()
	return (towns[a]["centre"] as Vector3).distance_to(towns[b]["centre"] as Vector3)


## Where a road leaves town `t` heading for `toward`: the end of the central avenue on that side.
static func road_end(t: int, toward: Vector3) -> Vector3:
	var town: Dictionary = TownCatalogue.towns()[t]
	var centre: Vector3 = town["centre"]
	var d: Vector3 = toward - centre
	var out: float = float(blocks_out(town)) * float(town["block"])
	if absf(d.x) >= absf(d.z):
		return centre + Vector3(signf(d.x) * out, 0.0, 0.0)
	return centre + Vector3(0.0, 0.0, signf(d.z) * out)


static func _lay(out: Array[Dictionary], link: Vector2i, solid: Array[Dictionary],
		keep_out: Array[Dictionary]) -> bool:
	var towns: Array[Dictionary] = TownCatalogue.towns()
	var a: Vector3 = road_end(link.x, towns[link.y]["centre"])
	var b: Vector3 = road_end(link.y, towns[link.x]["centre"])
	if _road_is_clear(a, b, link, solid, keep_out):
		out.append({"from": a, "to": b, "width": TownTuning.ROAD_WIDTH, "link": link})
		return true
	var middle: Vector3 = (a + b) * 0.5
	var along: Vector3 = (b - a).normalized()
	var aside := Vector3(-along.z, 0.0, along.x)
	var first: float = 1.0 if Terrain.hash01(link.x * 31 + link.y, 1709) < 0.5 else -1.0
	for step in [1.0, 2.0, 3.0]:
		for side in [first, -first]:
			var bend: Vector3 = middle + aside * (side * step * TownTuning.DOGLEG_STEP)
			if _road_is_clear(a, bend, link, solid, keep_out) and _road_is_clear(bend, b, link, solid, keep_out):
				out.append({"from": a, "to": bend, "width": TownTuning.ROAD_WIDTH, "link": link})
				out.append({"from": bend, "to": b, "width": TownTuning.ROAD_WIDTH, "link": link})
				return true
	return false


## Whether a straight length of road may be laid: sampled closer than its own half-width, each
## sample a flat box on the ground tested against what it must avoid, and never inside a town it is
## not joining.
static func _road_is_clear(a: Vector3, b: Vector3, link: Vector2i, solid: Array[Dictionary],
		keep_out: Array[Dictionary]) -> bool:
	var reach: float = TownTuning.ROAD_WIDTH * 0.5 + TownTuning.ROAD_VERGE
	var half := Vector3(reach, 1.0, reach)
	var length: float = a.distance_to(b)
	var samples: int = maxi(int(ceil(length / TownTuning.ROAD_SAMPLE)), 1)
	var town_count: int = TownCatalogue.towns().size()
	for s in range(samples + 1):
		var at: Vector3 = a.lerp(b, float(s) / float(samples)) + Vector3(0.0, 1.0, 0.0)
		if not Terrain.is_clear(keep_out, at, half) or not Terrain.is_clear(solid, at, half) \
				or not Terrain.rock_clears(at, half):
			return false
		for t in range(town_count):
			if t == link.x or t == link.y:
				continue
			if _inside_town(t, at, reach):
				return false
	return true


static func _inside_town(t: int, at: Vector3, room: float) -> bool:
	var town: Dictionary = TownCatalogue.towns()[t]
	var out: float = float(blocks_out(town)) * float(town["block"]) + room
	var to: Vector3 = at - (town["centre"] as Vector3)
	return absf(to.x) < out and absf(to.z) < out
