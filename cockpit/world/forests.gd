extends RefCounted
class_name Forests
## WHERE THE WOODS ARE: A LIST OF RECTANGLES ON THE GROUND, AND NOTHING ELSE.
##
## A forest here is a picture and never a thing. No tree is a box, no tree reaches the
## simulation, and an aeroplane flown into a wood flies through it -- the user asked for trees
## "like grass but a forest", which is visible and costs almost nothing. So this file is the
## one place a wood is decided, and what grows in it is worked out from these few numbers on
## every machine the same way, by the same integer hash `Terrain` builds the island with.
##
## THE DECISION: A RECTANGLE IN A CATALOGUE, NOT A BRUSH. A stand is a centre, a size, a
## heading, a density and a mix of conifer against broadleaf, and that is all anybody types.
## Dragging one out in the editor or drawing one in the headset can come later, on top of this
## same list. A catalogue the code reads is a `const` in a `RefCounted` here (see
## building_a_game_here.md, "Data, content, and custom resources").
##
## EVERY OPTIONAL TAKES ITS DEFAULT AT ITS OWN CALL SITE, in `stands()`, never from a clamp's
## floor. A density that fell back to the bottom of its range would grow a forest of three
## trees, in the right place and the right colour, and every counter would call it a forest.
## An entry with no centre or no size is not half a forest: it disables itself and says so.
##
## THE GROUND DECIDES WHERE A TREE MAY NOT STAND, NOT THIS FILE. A stand may overlap a
## clearance, a peak or a town; the trees inside it that would are simply not grown (see
## `Terrain.ground_keepouts`). Hand-placing a rectangle round every runway approach works
## exactly until the runway moves.
##
## HOW BIG, AND HOW MUCH IT COSTS, is not here: every number about a tree -- how many to a
## hectare, how tall, how far off it fades, on each finish -- is in `world/forest_tuning.gd`.

## The stands. `heading` is in degrees in the sense of a vehicle's yaw, so a stand's long side
## points along `Terrain.nose_from_yaw(deg_to_rad(heading))`; `size` is (across, along) in
## metres; `density` multiplies the tuning's trees per hectare; `mix` is the share of conifers.
##
## Both sit on open ground a pilot sees on the way out of the circuit, clear of the runway's
## approaches, the railway, the gates, the fires and the three cities -- and anything of theirs
## a rectangle still touches is carved out tree by tree, not by moving the rectangle.
const STANDS: Array[Dictionary] = [
	# EAST OF THE MIDDLE, between the inner east gate and the eastern range: the wood you fly
	# over on the way to the fires on the near hillsides. Mostly pine.
	{"name": "east_wood", "centre": Vector2(1900.0, 700.0), "size": Vector2(600.0, 1000.0),
		"heading": 30.0, "density": 1.0, "mix": 0.7},
	# WEST OF THE RUNWAY, under the western range and north of the far city: a broadleaf wood
	# low on a base leg, where its edge is the thing you see from the circuit.
	{"name": "west_wood", "centre": Vector2(-2650.0, 650.0), "size": Vector2(420.0, 800.0),
		"heading": -15.0, "density": 1.0, "mix": 0.3},
]

## WOODS ON THE GENERATED GROUND (increment B4, team-lead's rulings, 2026-09-15): no typed rectangles -- a changed seed would
## leave them on rock or water, the reason the towns are seated rather than typed -- but a rule the ground answers.
## GROUND_TRIES rectangles are tried by `Terrain`'s own hash across GROUND_SPREAD of the land's reach, each 400-700 m across
## and 600-1,000 m along at a heading anywhere, and sampled every STAND_SAMPLE metres in its own frame. A rectangle is KEPT
## when every sample is dry (`Terrain.water_height`: the sea and every lake), off every seated town's site and its margin
## (`TownCatalogue.towns()`), off every airfield strip and its margin (`GroundField.catalogue()`) and outside every runway
## approach (`Terrain.clearances()`) -- each keep-out asked of its owner, never copied -- when at least STAND_GENTLE_SHARE
## of its samples are no steeper than MOST_TREE_SLOPE, and when it touches no rectangle already kept (their circumscribed
## circles apart). The first ones kept, up to the floor's `most_stands`, are the woods. The slope limit also holds tree by
## tree inside a kept wood (`Woodland.plant`).
##
## MEASURED BEFORE IT WAS CHOSEN (a probe of 60 such rectangles on today's alpine world, dry and off the town sites): the
## ground is valley floors and coasts at 0-150 m with median slopes of 2-8 degrees, and mountains past about 800 m at
## medians of 36-63; at slope limits of 25 / 30 / 35 / 40 degrees 31 / 33 / 34 / 36 rectangles kept 70% of their ground.
## A TREELINE WAS REJECTED: at 1,200, 1,500, 1,800 and 2,100 m it changed nothing, every rectangle high enough to cross one
## being too steep already (agents.md, WHAT IS NOT HERE YET).
##
## THE MIX OF CONIFERS FOLLOWS HEIGHT, by one formula and never typed per stand: MIX_LOW on a wood whose median ground is at
## the sea, rising in a straight line to MIX_HIGH at MIX_FULL_HEIGHT and held there.
const GROUND_TRIES: int = 60
const GROUND_SPREAD: float = 0.72
const GROUND_SALT: int = 2311
const STAND_SAMPLE: float = 64.0
const STAND_GENTLE_SHARE: float = 0.7
const MOST_TREE_SLOPE: float = 35.0
const MIX_LOW: float = 0.3
const MIX_HIGH: float = 0.9
const MIX_FULL_HEIGHT: float = 600.0
const TUNING := preload("res://world/forest_tuning.gd")
## The ground the woods were last worked out for, the woods, and how the tries fared, for the test and the ready.
static var _ground_of: Object = null
static var _ground_stands: Array[Dictionary] = []
static var last_tally: Dictionary = {}

## What an entry is given when it does not say.
const DEFAULT_HEADING: float = 0.0
const DEFAULT_DENSITY: float = 1.0
const DEFAULT_MIX: float = 0.5
## How far a density may be asked for. A count limit, so it CLAMPS WITH A WARNING rather than
## silently: four times the tuning's number is already more trees than any chunk was sized for.
const MOST_DENSITY: float = 4.0


## EVERY STAND, READ: `{name, centre, half, along, across, heading, density, mix}`.
##
## `centre` is on the ground (y = 0); `half` is (across, along) half-sizes; `along` and `across`
## are the rectangle's own unit axes on the ground. Built fresh each call, like `Terrain.boxes`,
## because it is two dictionaries and a cache that outlived an edit here would be a wood
## somewhere other than the one this file says.
static func stands() -> Array[Dictionary]:
	var field: Object = Terrain.standing_on()
	if field != null:
		if field != _ground_of:
			_ground_stands = stands_on_the_ground(field)
			_ground_of = field
		return _ground_stands
	var out: Array[Dictionary] = []
	for i in range(STANDS.size()):
		var read: Dictionary = read_stand(STANDS[i], i)
		if not read.is_empty():
			out.append(read)
	return out


## THE WOODS THE GENERATED GROUND `field` GROWS, by the rule above. Worked out once per ground by `stands()`.
static func stands_on_the_ground(field: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var most: int = int(TUNING.for_tier(false, TUNING.asked_on_the_command_line())["most_stands"])
	var land: float = Terrain.land_reach()
	var towns: Array[Dictionary] = TownCatalogue.towns()
	var airfields: Array = (field.call("catalogue") as Dictionary).get("airfields", [])
	var approaches: Array[Dictionary] = Terrain.clearances()
	var tally := {"tried": 0, "wet": 0, "on_a_site_strip_or_approach": 0, "too_steep": 0, "touching": 0, "kept": 0, "past_the_floor": 0}
	for i in range(GROUND_TRIES):
		tally["tried"] += 1
		var seed_value: int = i * 7 + GROUND_SALT
		var at: Vector3 = Terrain._spread(i, GROUND_SALT, land * GROUND_SPREAD)
		var probe: Dictionary = read_stand({"name": "ground_wood_%d" % i, "centre": Vector2(at.x, at.z),
			"size": Vector2(lerpf(400.0, 700.0, Terrain.hash01(seed_value, 1)), lerpf(600.0, 1000.0, Terrain.hash01(seed_value, 2))),
			"heading": Terrain.hash01(seed_value, 3) * 180.0}, i)
		var half: Vector2 = probe["half"]
		var n_across: int = maxi(1, ceili(2.0 * half.x / STAND_SAMPLE))
		var n_along: int = maxi(1, ceili(2.0 * half.y / STAND_SAMPLE))
		var heights: Array[float] = []
		var gentle: int = 0
		var why: String = ""
		for a in range(n_across):
			for b in range(n_along):
				var p: Vector3 = world_of(probe, Vector2(-half.x + (float(a) + 0.5) * 2.0 * half.x / float(n_across),
					-half.y + (float(b) + 0.5) * 2.0 * half.y / float(n_along)))
				p.y = Terrain.ground_height(p)
				if Terrain.water_height(p) != -INF:
					why = "wet"
				elif is_kept_out(p, towns, airfields, approaches):
					why = "on_a_site_strip_or_approach"
				if why != "":
					break
				heights.append(p.y)
				if Terrain.slope_at(p) <= MOST_TREE_SLOPE:
					gentle += 1
			if why != "":
				break
		if why == "" and float(gentle) < STAND_GENTLE_SHARE * float(n_across * n_along):
			why = "too_steep"
		if why == "":
			for kept in out:
				if (kept["centre"] as Vector3).distance_to(probe["centre"]) < (kept["half"] as Vector2).length() + half.length():
					why = "touching"
		if why != "":
			tally[why] += 1
			continue
		if out.size() >= most:
			tally["past_the_floor"] += 1
			continue
		heights.sort()
		probe["mix"] = conifer_share(heights[heights.size() / 2])
		out.append(probe)
		tally["kept"] += 1
	last_tally = tally
	return out


## THE SHARE OF CONIFERS IN A WOOD whose median ground stands `height` metres up: see MIX_LOW above.
static func conifer_share(height: float) -> float:
	return lerpf(MIX_LOW, MIX_HIGH, clampf(height / MIX_FULL_HEIGHT, 0.0, 1.0))


## WHETHER A POINT ON THE GENERATED GROUND IS ONE NO WOOD STANDS ON: inside a seated town's site and its margin, an airfield
## strip and its margin, or a runway approach, each asked of its owner. `at.y` is the ground there.
static func is_kept_out(at: Vector3, towns: Array[Dictionary], airfields: Array, approaches: Array[Dictionary]) -> bool:
	for town in towns:
		var site: Dictionary = town.get("site", {})
		var centre: Vector3 = town["centre"]
		if Vector2(at.x - centre.x, at.z - centre.z).length() <= float(site.get("r", 0.0)) + float(site.get("margin", 0.0)):
			return true
	for strip in airfields:
		var margin: float = float(strip["margin"])
		if absf(at.x - float(strip["x"])) <= float(strip["half_long"]) + margin and absf(at.z - float(strip["z"])) <= float(strip["half_wide"]) + margin:
			return true
	return not Terrain.is_clear(approaches, at, Vector3.ONE)


## ONE ENTRY, READ, or {} if it cannot be a forest. Public so a test can hand it a broken one
## and see it refused, rather than breaking the catalogue to find out.
static func read_stand(entry: Dictionary, index: int) -> Dictionary:
	var name: String = String(entry.get("name", "stand_%d" % index))
	if not (entry.get("centre") is Vector2) or not (entry.get("size") is Vector2):
		push_warning("[forests] %s has no centre or no size, as Vector2s; it grows nothing" % name)
		return {}
	var size: Vector2 = entry["size"]
	if size.x <= 0.0 or size.y <= 0.0:
		push_warning("[forests] %s is %s m, which is no ground at all; it grows nothing" % [name, size])
		return {}
	var heading: float = float(entry.get("heading", DEFAULT_HEADING))
	var density: float = float(entry.get("density", DEFAULT_DENSITY))
	if density < 0.0 or density > MOST_DENSITY:
		push_warning("[forests] %s asks for density %.2f; held to 0..%.1f" % [name, density, MOST_DENSITY])
		density = clampf(density, 0.0, MOST_DENSITY)
	var mix: float = float(entry.get("mix", DEFAULT_MIX))
	if mix < 0.0 or mix > 1.0:
		push_warning("[forests] %s asks for mix %.2f; held to 0..1" % [name, mix])
		mix = clampf(mix, 0.0, 1.0)
	var along: Vector3 = Terrain.nose_from_yaw(deg_to_rad(heading))
	var centre: Vector2 = entry["centre"]
	return {
		"name": name,
		"index": index,
		"centre": Vector3(centre.x, 0.0, centre.y),
		"half": size * 0.5,
		"along": along,
		"across": Vector3(-along.z, 0.0, along.x),
		"heading": heading,
		"density": density,
		"mix": mix,
	}


## Where a point on the ground is in a stand's own frame: x across, y along, from its centre.
static func local_of(stand: Dictionary, at: Vector3) -> Vector2:
	var to: Vector3 = at - (stand["centre"] as Vector3)
	return Vector2(to.dot(stand["across"] as Vector3), to.dot(stand["along"] as Vector3))


## A point in a stand's own frame, put back on the ground.
static func world_of(stand: Dictionary, local: Vector2) -> Vector3:
	return (stand["centre"] as Vector3) + (stand["across"] as Vector3) * local.x \
		+ (stand["along"] as Vector3) * local.y


## Whether a point on the ground is inside a stand.
static func contains(stand: Dictionary, at: Vector3) -> bool:
	var local: Vector2 = local_of(stand, at)
	var half: Vector2 = stand["half"]
	return absf(local.x) <= half.x and absf(local.y) <= half.y
