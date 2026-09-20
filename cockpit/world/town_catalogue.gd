extends RefCounted
class_name TownCatalogue
## WHERE THE TOWNS ARE, AND WHAT KIND OF PLACE EACH ONE IS: one line per town.
##
## THE EASY WAY TO HAVE A TOWN IS A LINE IN THIS TABLE. A centre, a radius and what the streets
## and the skyline are like; `TownPlan` grows the streets, the lots and the buildings from it with
## the world's own hash, so every machine builds the same town and nothing about any one building
## is stored anywhere. Roads between towns come from the same table (see `TownPlan.roads`).
##
## THE THREE CITIES ARE THE THREE GREY GRIDS THAT WERE HERE BEFORE, at the same centres, which is
## what the spawns in their streets, the thermals over them and the probe views were placed from.
## Those three points used to be typed on their own, as `Terrain.CITIES`; that constant is gone, and
## `Terrain.lift_zones` reads its thermals off this table, so moving a city moves its thermal with it.
##
## STREETS ARE STRAIGHT AND RUN NORTH-SOUTH AND EAST-WEST, because a building is a static box and a
## static box in the simulation has no rotation. A town on a slant would be a wire change for an
## argument to `add_static_box`; roads BETWEEN towns are paint and run at any angle.
##
## Every number here is a fact about a PLACE. How a building is drawn, how big a window is, how far
## apart obstruction lights are -- the numbers a finish is tuned by -- live in `TownTuning`.
##
##   centre        where the middle of the grid is; the two central avenues cross here
##   radius        how far out a block may still be built on, before the ragged edge
##   block         street centre to street centre, metres
##   street        how wide every street is; in a city, wide enough to fly an aeroplane down
##   core_height   typical height of a building at the centre, metres
##   edge_height   typical height at the radius
##   empty_near    share of lots left empty at the centre
##   empty_far     share of lots left empty at the radius
##   tower_radius  towers only stand inside this; 0 for a town with no towers
##   tower_share   share of blocks inside tower_radius that are a tower
##   tower_low     shortest tower
##   tower_high    tallest tower
##   thermal       whether a cumulus stands over it -- see `Terrain.lift_zones`

const TOWNS: Array[Dictionary] = [
	{"name": &"inner", "centre": Vector3(520.0, 0.0, -560.0), "radius": 470.0,
		"block": 96.0, "street": 32.0, "core_height": 42.0, "edge_height": 12.0,
		"empty_near": 0.12, "empty_far": 0.55, "tower_radius": 230.0, "tower_share": 0.35,
		"tower_low": 110.0, "tower_high": 250.0, "thermal": true},
	{"name": &"eastern", "centre": Vector3(3400.0, 0.0, -1900.0), "radius": 440.0,
		"block": 96.0, "street": 32.0, "core_height": 38.0, "edge_height": 11.0,
		"empty_near": 0.15, "empty_far": 0.60, "tower_radius": 200.0, "tower_share": 0.30,
		"tower_low": 110.0, "tower_high": 220.0, "thermal": true},
	{"name": &"western", "centre": Vector3(-3600.0, 0.0, -400.0), "radius": 440.0,
		"block": 96.0, "street": 32.0, "core_height": 36.0, "edge_height": 10.0,
		"empty_near": 0.15, "empty_far": 0.60, "tower_radius": 180.0, "tower_share": 0.25,
		"tower_low": 110.0, "tower_high": 200.0, "thermal": true},
	# SMALL TOWNS, with no towers: the places the roads go through on the way. On open ground and OFF the woods in
	# `Forests.STANDS`: ford stood at (1900, 450), inside east_wood, and brook at (-2300, 600), on west_wood's edge, until
	# the two catalogues were read side by side (2026-09-13). A town may cut trees out of a wood; it should not be
	# dropped in the middle of one.
	{"name": &"ford", "centre": Vector3(2200.0, 0.0, -700.0), "radius": 220.0,
		"block": 64.0, "street": 14.0, "core_height": 14.0, "edge_height": 7.0,
		"empty_near": 0.20, "empty_far": 0.65, "tower_radius": 0.0, "tower_share": 0.0,
		"tower_low": 0.0, "tower_high": 0.0, "thermal": false},
	{"name": &"hollow", "centre": Vector3(-500.0, 0.0, -2000.0), "radius": 220.0,
		"block": 64.0, "street": 14.0, "core_height": 14.0, "edge_height": 7.0,
		"empty_near": 0.20, "empty_far": 0.65, "tower_radius": 0.0, "tower_share": 0.0,
		"tower_low": 0.0, "tower_high": 0.0, "thermal": false},
	{"name": &"brook", "centre": Vector3(-2300.0, 0.0, -1000.0), "radius": 200.0,
		"block": 64.0, "street": 14.0, "core_height": 12.0, "edge_height": 7.0,
		"empty_near": 0.25, "empty_far": 0.70, "tower_radius": 0.0, "tower_share": 0.0,
		"tower_low": 0.0, "tower_high": 0.0, "thermal": false},
]

## The towns seated on the ground `Terrain` last stood on, and which ground that was (its instance id, 0 for none).
static var _seated: Array[Dictionary] = []
static var _seated_on: int = 0


## THE TOWNS THE WORLD STANDS ON, and the one thing anything should read to find a town. On the island it is `TOWNS`. On
## the generated ground it is the same lines, each SEATED on a town site `GroundField` flattened: "centre" moved to the
## site's middle at the site's level, and "site" `{index, r, margin}` beside it, the flat's radius and the blend round it.
## Read this and never `TOWNS` -- `TownPlan`, `Terrain.lift_zones`, a probe's pose, cockpit-mist's domes and valley pools:
## a town read off the constant on the alpine world stands kilometres from its own buildings.
##
## THE ORDERED TABLE IS A RULE, NOT A LIST (team-lead, 2026-09-15): the biggest plan on the biggest flat. The sites by
## radius and the towns by radius, each largest first and each tie in catalogue order, paired in order. On today's alpine
## world that seats inner (470 m, 540.5 m to its ragged edge) on the 537 m site -- 3.5 m of its edge on the first metres of
## the blend -- eastern and western on 524 and 522, ford, hollow and brook on 518, 492 and 422, and leaves the 390 m site
## nearest the spawn empty. REJECTED: the three towns on the three sites nearest the spawn, which kept a town in the first
## view from the spawn but left the 518 m site empty for no reason a pilot could see; and a typed table of names and
## coordinates, which a changed seed would leave standing on a hillside. Hand-placed sites in the ground's own catalogue
## were rejected before either (agents.md, "The island's places on the alpine world").
##
## Seated once per ground: the level stands on one `GroundField` for its life, and a level stood on another seats again.
static func towns() -> Array[Dictionary]:
	var field: Object = Terrain.standing_on()
	if field == null:
		return TOWNS
	if field.get_instance_id() != _seated_on:
		_seated = seat(TOWNS, (field.call("catalogue") as Dictionary)["towns"])
		_seated_on = field.get_instance_id()
	return _seated


## `towns` SEATED ON `sites` (`GroundField.catalogue()["towns"]`) by the rule above: a function of its two arguments and
## nothing else, so a suite can hand it a catalogue of its own. A ground with fewer sites than towns seats the largest
## towns that fit and says which it could not (CLAUDE.md, rule 8: a count limit drops and says so).
static func seat(towns: Array[Dictionary], sites: Array) -> Array[Dictionary]:
	var by_site: Array = range(sites.size())
	by_site.sort_custom(func(a: int, b: int) -> bool:
		var ra: int = int(sites[a]["r"])
		var rb: int = int(sites[b]["r"])
		return ra > rb if ra != rb else a < b)
	var by_town: Array = range(towns.size())
	by_town.sort_custom(func(a: int, b: int) -> bool:
		var ra: float = float(towns[a]["radius"])
		var rb: float = float(towns[b]["radius"])
		return ra > rb if ra != rb else a < b)
	var seat_of: Dictionary = {}
	for k in range(mini(by_site.size(), by_town.size())):
		seat_of[by_town[k]] = by_site[k]
	var out: Array[Dictionary] = []
	for t in range(towns.size()):
		if not seat_of.has(t):
			push_warning("[towns] %s has no town site to stand on: the ground found %d sites for %d towns" % [
				towns[t]["name"], sites.size(), towns.size()])
			continue
		var index: int = int(seat_of[t])
		var site: Dictionary = sites[index]
		var line: Dictionary = towns[t].duplicate()
		line["centre"] = Vector3(float(site["x"]), float(site["level"]) / Terrain.SITE_LEVEL_PER_METRE, float(site["z"]))
		line["site"] = {"index": index, "r": float(site["r"]), "margin": float(site["margin"])}
		out.append(line)
	return out
