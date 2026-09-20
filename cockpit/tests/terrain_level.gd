extends Node
## Headless: does the flight level stand on the generated ground when it is asked to, and is the ground it stands on the
## ground it draws and the ground it answers questions about?
##
##   Godot --headless --path cockpit res://tests/terrain_level.tscn
##
## THE WORLD IS ASKED FOR AS A LEVEL: `Net.choose_level("alpine")` before the level is added, which is what the desk's level
## row and `--world=alpine` both do (cockpit-levels, 2026-09-15). Which level a joiner stands on, and refusing one that
## differs, is tests/level_join.gd's.
##
## Every check is against something the level did not compute:
##
## - BOTH WORLDS STAND ON THE SAME GROUND: the server's and the client's `ground_report`, field for field and hash for hash.
## - NO ISLAND UNDER IT: where the generated ground lies below the sea inside the old island square, a Box3D ray down finds
##   the ground, not the island's slab at y = 0.
## - THE COLLISION IS THE GROUND: at random land points a ray down lands on `ground_height_at` within a millimetre.
## - THE GROUND IS DRAWN: GroundView's layer is in the level's yard with cells built round the eye.
## - TERRAIN ANSWERS FROM THE GROUND: `surface_height`, `ground_height` and `water_height` at a grid of points against
##   `GroundField.heights_at` and `waters_at` asked here, and `water_height` at every catalogued lake's middle against
##   the lake's level; `open_sea_near` returns sea, deep enough, with no lake's water.
## - THE TRAFFIC STANDS ON THE GROUND: launched aeroplanes clear of it, ships on deep open sea inside the placed reach,
##   every pool's points with a leg the simulation would take, fires on the ground, and every lone machine with a leg.
## - THE TOWNS ARE SEATED: every island town on a town site of its own, its buildings' floors on the ground and their
##   roofs in the simulation, its streets on its flat, no railway or road, no starting fire on a site, and a town drawn -- with
##   its street lamps, which are switched off in the game (`TownTuning.STREET_LIGHTS_ON`) and turned on for this suite.
## - EVERY STRIP HAS A RUNWAY: on its middle and ground, along it, its paint and lights on the ground and drawn, its
##   approaches kept clear of every building.
## - THE RISING AIR STANDS ON THE GROUND: a zone beside a peak raised until its cloud clears it, a thermal over every seated
##   town that has one, every zone based on the ground
##   under it and off the water, every cloud's base clear of the highest ground within its own kind's reach on an 8 m
##   grid, no two zones' columns overlapping, every zone felt by the simulation halfway up its column, and every ring
##   and wisp LiftYard draws standing on the ground under itself, not under the zone's middle, every draped piece right-handed.
## - THE WOODS STAND ON THE GROUND: every wood dry and off every town site, strip and approach, none touching; every tree's
##   foot on the lowest ground under its trunk, no slope past the woods' limit, none on water; the floor on every ground cell,
##   including cells built after the woods grew.
## - THE ROADS JOIN THE PLACES ON THE GROUND: every piece's ends on the ground and its middle off the water, no piece up a
##   cliff, and every seated town and airfield strip joined into one network.
##
## It prints how long the level took to stand the ground in both worlds.
##
## Read RESULT=, not the exit code.

## A ray is rounded to the float32 Box3D holds a position in; the slop between two float32 heights 12 km out is well under.
const WITHIN: float = 0.001
const RAYS: int = 200
## How long the level may take to stand the ground in both worlds and come up, frames.
const PATIENCE: int = 3000
## Ticks of height in a metre, `GroundField`'s unit.
const TICKS: float = 32.0

var _failures: PackedStringArray = []
var _sections: int = 0
## The island's placed reach, read before the alpine level is chosen: see `_every_level_fits_the_widest_turn`.
var _island_reach: float = 0.0
## Set by `_finish`, so a level refused while it loads and the wait that outlives it finish once.
var _finished: bool = false
var _level: FlightLevel = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[terrain_level] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var can: bool = ClassDB.class_exists("CockpitWorld") and ClassDB.class_exists("GroundField")
	_check("the_extension_has_the_ground_and_the_world", can, "engine %s, double=%s" % [
		Engine.get_version_info()["string"], OS.has_feature("double")])
	if not can:
		_finish()
		return
	# THE ISLAND'S REACH, read HERE, before a level is chosen and its ground stands: `Terrain`'s field is set when a ground
	# stands and never cleared, so a reach read later answers for alpine (cockpit-fleet, 2026-09-15).
	_island_reach = Terrain.placed_reach()
	# A LEVEL REFUSED WHILE IT LOADS says why in this suite's words: see `_on_a_session_ended`. Let go once it stands.
	Net.session_ended.connect(_on_a_session_ended)
	var chosen: String = Net.choose_level("alpine")
	_check("the_alpine_level_can_be_chosen", chosen == "", "'%s'" % chosen)
	# THE STREET LIGHTS ON FOR THE SUITE, whatever `TownTuning.STREET_LIGHTS_ON` says: they were switched off on 2026-09-15,
	# and a seated town's lamps standing on its own flat are still this level's to show. Read once, when the level draws its
	# towns, so set before it is added; put back in `_finish`. tests/night_lights.gd holds the switch as shipped.
	TownView.street_lights_in_tests = true
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	var frames: int = 0
	while frames < PATIENCE and not _finished and not (_level.ground_built_msec >= 0.0 and Sim.is_ready):
		await get_tree().process_frame
		frames += 1
	if _finished:
		return
	Net.session_ended.disconnect(_on_a_session_ended)
	_check("the_level_stands_on_the_generated_ground_and_comes_up",
		_level.ground_built_msec >= 0.0 and Sim.is_ready and Terrain.standing_on() != null,
		"after %d frames: the ground stood in both worlds in %.0f ms, sim ready %s" % [frames, _level.ground_built_msec,
			Sim.is_ready])
	if Terrain.standing_on() == null or Sim.server == null or Sim.client == null:
		_finish()
		return
	for i in range(30):
		await get_tree().process_frame
	var field: Object = Terrain.standing_on()

	_both_worlds_stand_on_the_same_ground()
	_no_island_under_it(field)
	_the_collision_is_the_ground(field)
	_the_ground_is_drawn()
	_terrain_answers_from_the_ground(field)
	await _the_towns_are_seated(field)
	_the_runways_are_on_the_strips(field)
	_the_rising_air_stands_on_the_ground(field)
	_the_woods_stand_on_the_ground(field)
	_the_roads_join_the_places_on_the_ground(field)
	_every_level_fits_the_widest_turn()
	# The machines were seeded when the build finished; give them long enough to have chosen where to go. PHYSICS frames, the
	# simulation's clock: headless, 600 process frames ran uncapped in well under a second of ticks, and two machines had not
	# chosen a leg yet (2026-09-15).
	for i in range(TRAFFIC_SETTLE_FRAMES):
		await get_tree().physics_frame
	_the_traffic_stands_on_the_ground(field)
	# EVERY SECTION, COUNTED FROM THE SECTIONS THEMSELVES: each ends on the one line `_sections += 1`, and `_sections_written`
	# counts those lines in this file, so a section added with its own line needs no second edit here (team-lead,
	# 2026-09-15: the 8 was typed twice). A source that cannot be read counts none, and that fails. WHAT IT CANNOT SEE: a
	# section whose own `_sections += 1` line is deleted lowers both counts and still passes, where a typed count would have
	# caught it. What it is for, a section or its await chain stopping early, it catches (the mutant returning early in
	# the runways section: 7 of 8). Kept as built (team-lead, 2026-09-15).
	var sections: int = _sections_written()
	_check("every_section_of_the_suite_ran", sections > 0 and _sections == sections, "%d of %d" % [_sections, sections])
	_finish()


## How many sections this suite has: the lines of its own source that are exactly `_sections += 1`, one at each section's end.
func _sections_written() -> int:
	var written: int = 0
	for line in (get_script() as GDScript).source_code.split("\n"):
		if line.strip_edges() == "_sections += 1":
			written += 1
	return written


## ---- the collision --------------------------------------------------------------------------------------------------

func _both_worlds_stand_on_the_same_ground() -> void:
	var server: Dictionary = Sim.server.ground_report()
	var client: Dictionary = Sim.client.ground_report()
	var same: bool = not server.is_empty() and int(server.get("fields", 0)) > 0
	for key in ["fields", "land_cells", "split_cells", "unheld_fields", "bytes", "hash"]:
		same = same and server.get(key) == client.get(key)
	_check("both_worlds_stand_on_the_same_ground", same, "server %s, client %s" % [server, client])
	_sections += 1


## BELOW THE SEA, THE COLLISION IS THE SEABED, and nothing else stands over it. The island's slab, its top at y = 0 across
## the old island square, would have stood over any ground below the sea there -- but on the alpine world that square is
## all land (its lowest ground stood 4.97 m up, 2026-09-15), so no ray there could tell a slab from none. The check is
## where it can fail: a shore below the sea whose cell has a height field (a sample above Bedrock's -40 m), where a ray
## from 10 m up must land on `ground_height_at`, not on a surface at the sea's level.
func _no_island_under_it(field: Object) -> void:
	var half: int = int((field.call("tuning") as Dictionary)["world_half"])
	var step: int = 256
	var n: int = 2 * half / step + 1
	var heights: PackedInt32Array = field.call("heights", -half, -half, n, n, step)
	var tried: int = 0
	var wrong: int = 0
	var worst: float = 0.0
	var first: String = ""
	for k in range(heights.size()):
		var ground: float = float(heights[k]) / TICKS
		if ground > -3.0 or ground < -30.0:
			continue
		var x: int = -half + (k % n) * step
		var z: int = -half + (k / n) * step
		# Bedrock builds a field for a cell with any sample above -40 m: ask the cell it stands in.
		var cell_x: int = int(floor(float(x) / 1024.0)) * 1024
		var cell_z: int = int(floor(float(z) / 1024.0)) * 1024
		var cell: PackedInt32Array = field.call("heights", cell_x, cell_z, 17, 17, 64)
		cell.sort()
		if float(cell[cell.size() - 1]) / TICKS <= -40.0:
			continue
		var from := Vector3(float(x), 10.0, float(z))
		var below: float = Sim.server.first_solid_below(from, 100.0)
		var wanted: float = 10.0 - float(Sim.server.ground_height_at(from.x, from.z))
		tried += 1
		var off: float = absf(below - wanted) if below >= 0.0 else INF
		worst = maxf(worst, off)
		if off > 0.01:
			wrong += 1
			if first == "":
				first = "; first at (%d, %d): found %.3f m down, the seabed is %.3f m down" % [x, z, below, wanted]
		if tried >= 40:
			break
	_check("below_the_sea_a_ray_lands_on_the_seabed_and_on_nothing_above_it", tried >= 10 and wrong == 0,
		"%d shores 3 to 30 m below the sea, %d wrong, worst %.4f m%s" % [tried, wrong, worst, first])
	_sections += 1


func _the_collision_is_the_ground(field: Object) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2718
	var rays: int = 0
	var missed: int = 0
	var worst: float = 0.0
	while rays < RAYS:
		var x: float = rng.randf_range(-12000.0, 12000.0)
		var z: float = rng.randf_range(-12000.0, 12000.0)
		if float(int(field.call("height_ticks_at", roundi(x), roundi(z)))) / TICKS < 2.0:
			continue
		# As the physics holds it: float32.
		var held := PackedFloat32Array([x, z])
		var ground: float = float(Sim.server.ground_height_at(held[0], held[1]))
		var below: float = Sim.server.first_solid_below(Vector3(held[0], ground + 50.0, held[1]), 100.0)
		rays += 1
		if below < 0.0:
			missed += 1
		else:
			worst = maxf(worst, absf(50.0 - below))
	_check("a_ray_down_lands_on_the_grounds_own_height_within_a_millimetre", missed == 0 and worst <= WITHIN,
		"%d rays over land within 12 km, %d missed, worst %.3f mm" % [rays, missed, worst * 1000.0])
	_sections += 1


## ---- the picture ----------------------------------------------------------------------------------------------------

func _the_ground_is_drawn() -> void:
	var view: GroundView = _level.ground_view
	var laid: int = _level.scenery.cells_of(GroundView.LAYER).size() if _level.scenery != null else 0
	var drawn: int = 0
	if view != null:
		for node in view.get_children():
			if node is MeshInstance3D:
				drawn += 1
	var flat := _level.get_node_or_null("Ground") as MeshInstance3D
	_check("the_generated_ground_is_drawn_and_the_flat_ground_is_not",
		view != null and laid > 0 and drawn > 0 and (flat == null or not flat.visible),
		"%d cells laid, %d drawn round the eye, flat ground %s" % [laid, drawn,
			"absent" if flat == null else ("shown" if flat.visible else "hidden")])
	_sections += 1


## ---- terrain's answers ----------------------------------------------------------------------------------------------

func _terrain_answers_from_the_ground(field: Object) -> void:
	var points := PackedInt32Array()
	for j in range(-10, 11):
		for i in range(-10, 11):
			points.append_array([i * 3100 + 17, j * 3100 - 23])
	var heights: PackedInt32Array = field.call("heights_at", points)
	var waters: PackedInt32Array = field.call("waters_at", points)
	var no_water: int = ClassDB.class_get_integer_constant("GroundField", "NO_WATER")
	var wrong: int = 0
	var first_wrong: String = ""
	for k in range(heights.size()):
		var at := Vector3(float(points[2 * k]), 0.0, float(points[2 * k + 1]))
		var ground: float = float(heights[k]) / TICKS
		var water: float = float(waters[k]) / TICKS if waters[k] > no_water else -INF
		var ok: bool = Terrain.ground_height(at) == ground and Terrain.water_height(at) == water \
			and Terrain.surface_height(at) == maxf(ground, water)
		if not ok:
			wrong += 1
			if first_wrong == "":
				first_wrong = "%s: ground %.3f/%.3f water %s/%s surface %.3f" % [at, Terrain.ground_height(at), ground,
					Terrain.water_height(at), water, Terrain.surface_height(at)]
	_check("terrain_answers_the_grounds_height_and_its_water_from_the_ground", wrong == 0,
		"%d points across the world, %d wrong %s" % [heights.size(), wrong, first_wrong])

	# THE BULK CALL, texel centres on the grid, against the point call it must agree with at every texel.
	var corner := Vector2(-8192.0 + 37.0, 5120.0 - 11.0)
	var texels: int = 48
	var spacing: float = 128.0
	var bulk: PackedFloat32Array = Terrain.surface_heights(corner, texels, spacing)
	var bulk_wrong: int = 0
	for j in range(texels):
		for i in range(texels):
			var at := Vector3(corner.x + (float(i) + 0.5) * spacing, 0.0, corner.y + (float(j) + 0.5) * spacing)
			if bulk[j * texels + i] != Terrain.surface_height(at):
				bulk_wrong += 1
	_check("and_over_a_grid_the_bulk_call_answers_what_the_point_call_does_at_every_texels_centre",
		bulk.size() == texels * texels and bulk_wrong == 0,
		"%d by %d texels at %.0f m from %s, %d wrong" % [texels, texels, spacing, corner, bulk_wrong])

	var lakes: Array = (field.call("catalogue") as Dictionary)["lakes"]
	var lakes_wrong: int = 0
	for lake in lakes:
		var middle := Vector3(float(int(lake["x"])), 0.0, float(int(lake["z"])))
		# A lake's level is in 1/1024 m; the water query answers it on the tick grid, level >> 5.
		if Terrain.water_height(middle) != float(int(lake["level"]) >> 5) / TICKS:
			lakes_wrong += 1
	_check("and_every_lakes_water_stands_at_its_level", lakes.size() > 0 and lakes_wrong == 0,
		"%d lakes, %d wrong" % [lakes.size(), lakes_wrong])

	var depth: float = 20.0
	var from_middle: Vector3 = Terrain.open_sea_near(Vector3.ZERO, depth)
	var sea_ok: bool = from_middle != Vector3.INF
	if sea_ok:
		var ticks_ground: int = int(field.call("height_ticks_at", roundi(from_middle.x), roundi(from_middle.z)))
		var ticks_water: int = int(field.call("water_ticks_at", roundi(from_middle.x), roundi(from_middle.z)))
		sea_ok = ticks_water == 0 and float(ticks_ground) / TICKS <= -depth and from_middle.y == Terrain.SEA_LEVEL
	_check("open_sea_near_the_middle_is_the_sea_and_deep_enough", sea_ok, "%s for %.0f m" % [from_middle, depth])
	_sections += 1


## ---- the towns ------------------------------------------------------------------------------------------------------

## How far a building's floor, a roof a ray lands on or a street's top may be from where it should be, metres: a tick of
## height and a little for a box held in float32 thirteen kilometres out.
const SEATED_WITHIN: float = 0.05
## How many buildings' roofs a ray is fired down onto, spread over every town, and from how far over each roof.
const ROOF_RAYS: int = 60
const ROOF_RAY_FROM: float = 20.0
## How long a seated town may take to be drawn round an eye put in its middle, frames.
const DRAWN_PATIENCE: int = 600


## THE ISLAND'S TOWNS ARE SEATED ON THE GROUND'S TOWN SITES, held against the field's own catalogue and heights and the
## simulation's own collision:
## - every island town, by name and in order, is on a site of its own, its centre the site's middle at the ground's height
##   there; no town's radius is past its site's flat, and no bigger town is on a smaller flat than a smaller town;
## - every building's floor is the ground under its middle, and a ray down onto its roof lands on the roof;
## - both ends of every street are on the ground, and there is no railway and no road on the generated ground;
## - no starting fire is on a town site;
## - a seated town is drawn, its buildings and its street lamps, round an eye put in its middle.
func _the_towns_are_seated(field: Object) -> void:
	var sites: Array = (field.call("catalogue") as Dictionary)["towns"]
	var seated: Array[Dictionary] = TownCatalogue.towns()
	var said: PackedStringArray = []
	var wrong: PackedStringArray = []
	var used: Dictionary = {}
	for t in range(seated.size()):
		var town: Dictionary = seated[t]
		var site_of: Dictionary = town.get("site", {})
		if site_of.is_empty() or t >= TownCatalogue.TOWNS.size() or town["name"] != TownCatalogue.TOWNS[t]["name"]:
			wrong.append("%s is not seated, or not in the table's order" % town["name"])
			continue
		var index: int = int(site_of["index"])
		var site: Dictionary = sites[index]
		var centre: Vector3 = town["centre"]
		if used.has(index):
			wrong.append("%s shares site %d" % [town["name"], index])
		used[index] = true
		var ground: float = float(int(field.call("height_ticks_at", int(site["x"]), int(site["z"])))) / TICKS
		if centre.x != float(site["x"]) or centre.z != float(site["z"]) or absf(centre.y - ground) > SEATED_WITHIN:
			wrong.append("%s at %s, not site %d's middle at its ground %.2f m" % [town["name"], centre, index, ground])
		if float(town["radius"]) > float(site["r"]):
			wrong.append("%s's radius %.0f m is past site %d's flat of %d m" % [town["name"], float(town["radius"]), index,
				int(site["r"])])
		said.append("%s on site %d (r %d m, %.2f m up)" % [town["name"], index, int(site["r"]), centre.y])
	for a in seated:
		for b in seated:
			if a.has("site") and b.has("site") and float(a["radius"]) > float(b["radius"]) \
					and float((a["site"] as Dictionary)["r"]) < float((b["site"] as Dictionary)["r"]):
				wrong.append("%s is on a smaller flat than %s" % [a["name"], b["name"]])
	_check("every_island_town_is_seated_on_a_town_site_of_its_own_and_no_bigger_town_on_a_smaller_flat",
		seated.size() == TownCatalogue.TOWNS.size() and wrong.is_empty(),
		"%d of %d towns on %d sites: %s; wrong %s" % [seated.size(), TownCatalogue.TOWNS.size(), sites.size(),
			", ".join(said), wrong])

	var buildings: Array[Dictionary] = []
	for box in _level._solid:
		if int(box["group"]) == Terrain.Group.BUILDING:
			buildings.append(box)
	var off: int = 0
	var worst: float = 0.0
	var worst_at := Vector3.ZERO
	for box in buildings:
		var at: Vector3 = box["position"]
		var ground: float = float(int(field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / TICKS
		var gap: float = absf(at.y - (box["half_extents"] as Vector3).y - ground)
		if gap > worst:
			worst = gap
			worst_at = at
		if gap > SEATED_WITHIN:
			off += 1
	var rays: int = 0
	var missed: int = 0
	var ray_worst: float = 0.0
	for i in range(0, buildings.size(), maxi(1, buildings.size() / ROOF_RAYS)):
		var at: Vector3 = buildings[i]["position"]
		var roof: float = at.y + (buildings[i]["half_extents"] as Vector3).y
		# As the physics holds it: float32.
		var held := PackedFloat32Array([at.x, roof + ROOF_RAY_FROM, at.z])
		var below: float = Sim.server.first_solid_below(Vector3(held[0], held[1], held[2]), ROOF_RAY_FROM * 2.0)
		rays += 1
		if below < 0.0:
			missed += 1
		else:
			ray_worst = maxf(ray_worst, absf(below - (held[1] - roof)))
	_check("every_building_stands_on_the_ground_under_it_and_the_simulation_holds_its_roof",
		buildings.size() > 0 and off == 0 and missed == 0 and ray_worst <= SEATED_WITHIN,
		"%d buildings, %d off the ground, worst %.3f m at %s; %d rays onto roofs, %d missed, worst %.3f m" % [
			buildings.size(), off, worst, worst_at, rays, missed, ray_worst])

	var streets: Array[Dictionary] = TownPlan.streets()
	var ends_off: int = 0
	var street_worst: float = 0.0
	for mark in streets:
		var at: Vector3 = mark["position"]
		var half: Vector3 = mark["half_extents"]
		var along := Vector3(half.x, 0.0, 0.0) if half.x >= half.z else Vector3(0.0, 0.0, half.z)
		for end in [at - along, at + along]:
			var ground: float = float(int(field.call("height_ticks_at", roundi(end.x), roundi(end.z)))) / TICKS
			var gap: float = absf(at.y + half.y - TownTuning.STREET_TOP - ground)
			street_worst = maxf(street_worst, gap)
			if gap > SEATED_WITHIN:
				ends_off += 1
	var rail: int = Terrain.rail_points().size()
	_check("both_ends_of_every_street_are_on_the_ground_and_there_is_no_railway",
		streets.size() > 0 and ends_off == 0 and rail == 0,
		"%d streets, %d ends off the ground, worst %.3f m; %d rail points" % [streets.size(), ends_off, street_worst, rail])

	# NO STARTING FIRE ON A TOWN SITE. Today no island fire is searched from within a site's reach, so this holds the rule
	# rather than a near miss; `nearest` says how close the nearest fire came.
	var on_a_site: Array = []
	var nearest: float = INF
	for fire in Terrain.fires():
		var at: Vector3 = fire["position"]
		for town in seated:
			var centre: Vector3 = town["centre"]
			var site_of: Dictionary = town.get("site", {})
			if site_of.is_empty():
				continue
			var away: float = Vector2(at.x - centre.x, at.z - centre.z).length() - float(site_of["r"]) - float(site_of["margin"])
			nearest = minf(nearest, away)
			if away < 0.0:
				on_a_site.append([town["name"], at])
	_check("no_starting_fire_stands_on_a_town_site", on_a_site.is_empty(),
		"%d on a site %s; the nearest %.0f m outside one" % [on_a_site.size(), on_a_site, nearest])

	var middle: Vector3 = seated[0]["centre"] if not seated.is_empty() else Vector3.ZERO
	_level.scenery.fill_around(middle)
	var near_buildings: int = 0
	var near_lamps: int = 0
	var frames: int = 0
	# LAMPS EXACTLY WHEN THE LEVEL HAS THEM: turned on for this suite in `_ready`, and none with the switch as shipped.
	var lamps_wanted: bool = TownView.street_lights_on()
	while frames < DRAWN_PATIENCE and (near_buildings == 0 or (lamps_wanted and near_lamps == 0)):
		await get_tree().process_frame
		frames += 1
		near_buildings = _instances_near(_level.towns.building_batches(), middle)
		near_lamps = _instances_near(_level.towns.street_lamp_batches(), middle)
	_check("a_seated_town_is_drawn_its_buildings_and_its_street_lamps", near_buildings > 0 and (near_lamps > 0) == lamps_wanted,
		"round %s after %d frames: %d buildings, %d street lamps drawn within 1.5 km, the street lights %s" % [middle, frames,
			near_buildings, near_lamps, "on" if lamps_wanted else "off"])
	_sections += 1


## How many instances the batches draw whose batch stands within 1.5 km of `at`, on the ground.
func _instances_near(batches: Array[MultiMeshInstance3D], at: Vector3) -> int:
	var count: int = 0
	for batch in batches:
		if batch == null or batch.multimesh == null:
			continue
		var middle: Vector3 = batch.global_position
		if Vector2(middle.x - at.x, middle.z - at.z).length() <= 1500.0:
			count += batch.multimesh.visible_instance_count if batch.multimesh.visible_instance_count >= 0 \
					else batch.multimesh.instance_count
	return count

## ---- the runways -----------------------------------------------------------------------------------------------------

## How far over the ground a runway light may stand, metres: the tallest of them, a strobe on an approach bar, is 1.6 m up.
const RUNWAY_LIGHT_HIGHEST: float = 2.0


## EVERY AIRFIELD STRIP HAS A RUNWAY ON IT, held against the field's own catalogue and heights and the level's drawn nodes:
## - one runway a strip, its middle the strip's middle at the ground's height there, lying along the strip's long axis;
## - both ends of each and every piece of its paint on the ground, and every light on it or at most 2 m over it;
## - the level draws every runway's paint in its one Runway MultiMesh, and its lights;
## - two approaches kept clear a runway, and no seated building standing in one.
func _the_runways_are_on_the_strips(field: Object) -> void:
	var strips: Array = (field.call("catalogue") as Dictionary)["airfields"]
	var frames: Array[Dictionary] = Terrain.runways()
	var wrong: PackedStringArray = []
	var said: PackedStringArray = []
	var marks_total: int = 0
	var marks_off: int = 0
	var lights_off: int = 0
	var worst: float = 0.0
	for k in range(mini(strips.size(), frames.size())):
		var strip: Dictionary = strips[k]
		var frame: Dictionary = frames[k]
		var centre: Vector3 = frame["centre"]
		var along: Vector3 = frame["along"]
		var ground: float = float(int(field.call("height_ticks_at", int(strip["x"]), int(strip["z"])))) / TICKS
		if centre.x != float(strip["x"]) or centre.z != float(strip["z"]) or absf(centre.y - ground) > SEATED_WITHIN:
			wrong.append("runway %d at %s, not strip %d's middle at its ground %.2f m" % [k, centre, k, ground])
		var strip_along_x: bool = int(strip["half_long"]) >= int(strip["half_wide"])
		if (absf(along.x) > 0.99) != strip_along_x:
			wrong.append("runway %d lies along %s on a strip along %s" % [k, along, "x" if strip_along_x else "z"])
		for end in [frame["threshold"], frame["far_end"]]:
			var at: Vector3 = end
			var under: float = float(int(field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / TICKS
			if absf(at.y - under) > SEATED_WITHIN:
				wrong.append("runway %d's end %s is %.2f m off the ground" % [k, at, at.y - under])
		var marks: Array[Dictionary] = Terrain.runway_marks_for(frame)
		marks_total += marks.size()
		for mark in marks:
			var at: Vector3 = mark["position"]
			var under: float = float(int(field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / TICKS
			var bottom: float = at.y - (mark["half_extents"] as Vector3).y
			worst = maxf(worst, absf(bottom - under))
			if bottom < under - SEATED_WITHIN or bottom > under + 0.2:
				marks_off += 1
		for light in Terrain.runway_lights_for(frame):
			var at: Vector3 = light["position"]
			var under: float = float(int(field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / TICKS
			if at.y < under - SEATED_WITHIN or at.y > under + RUNWAY_LIGHT_HIGHEST:
				lights_off += 1
		said.append("%d on (%d, %d) at %.2f m, bearing %.0f" % [k, int(strip["x"]), int(strip["z"]), centre.y,
			rad_to_deg(float(frame["bearing"]))])
	_check("every_airfield_strip_has_a_runway_lying_along_it_on_its_ground",
		strips.size() > 0 and frames.size() == strips.size() and wrong.is_empty(),
		"%d strips, %d runways: %s; wrong %s" % [strips.size(), frames.size(), ", ".join(said), wrong])

	var drawn := _level.get_node_or_null("Runway") as MultiMeshInstance3D
	var drawn_count: int = drawn.multimesh.instance_count if drawn != null and drawn.multimesh != null else 0
	var lit: bool = _level.get_node_or_null("RunwayLights") != null
	_check("every_runways_paint_and_lights_are_on_the_ground_and_drawn",
		marks_total > 0 and marks_off == 0 and lights_off == 0 and drawn_count == marks_total and lit,
		"%d pieces of paint, %d off the ground (worst %.3f m), %d lights off it; drawn %d, lights node %s" % [marks_total,
			marks_off, worst, lights_off, drawn_count, lit])

	var approaches: Array[Dictionary] = []
	for keep in Terrain.clearances():
		if keep.get("why", &"") == &"runway":
			approaches.append(keep)
	var trespass: int = 0
	for box in _level._solid:
		if int(box["group"]) == Terrain.Group.BUILDING and not Terrain.is_clear(approaches, box["position"], box["half_extents"]):
			trespass += 1
	_check("every_runways_two_approaches_are_kept_clear_and_no_building_stands_in_one",
		approaches.size() == 2 * frames.size() and trespass == 0,
		"%d approaches for %d runways, %d buildings in one" % [approaches.size(), frames.size(), trespass])
	var number: String = RadioPhrases.runway()
	var strip_along_x: bool = not strips.is_empty() and int((strips[0] as Dictionary)["half_long"]) >= int((strips[0] as Dictionary)["half_wide"])
	var names: Array = ["09", "27"] if strip_along_x else ["18", "36"]
	_check("the_radio_names_the_first_runway_by_the_strip_it_lies_on", not strips.is_empty() and names.has(number),
		"'%s' for strip 0, which lies along %s (its runway is %s)" % [number, "x" if strip_along_x else "z", " or ".join(names)])
	_sections += 1

## ---- the rising air -------------------------------------------------------------------------------------------------

## How many zones the scatter must keep at the least, beside the towns' thermals, for a glider to have a series of decisions.
const FEWEST_SCATTERED_THERMALS: int = 8
## The grid a cloud's reach is searched on for the highest ground, metres: twice as fine as Terrain's own 16 m samples.
const CLOUD_GROUND_STEP: float = 8.0
## How far the middle of a draped ring piece may stand off RING_OVER over the ground under it, metres: a straight piece laid
## over a curved slope. Its ends are held to a tick. The first run's worst was 5.33 m (48 pieces round rings up to 330 m).
const RING_SAG: float = 8.0
## How many points round a level hoop's middle circle are asked of the field.
const HOOP_SAMPLES: int = 96
## The grid the land is swept on for the spot where the ground rises most within a cloud's reach, and the samples inside
## each reach, metres: coarse, because the case wants a peak, not the exact metre of it.
const RISING_SWEEP_STEP: float = 1024.0
const RISING_SWEEP_SAMPLE: float = 64.0


func _the_rising_air_stands_on_the_ground(field: Object) -> void:
	var zones: Array[Dictionary] = Terrain.lift_zones()
	var no_water: int = ClassDB.class_get_integer_constant("GroundField", "NO_WATER")
	# A THERMAL OVER EVERY SEATED TOWN THAT HAS ONE, inside its site.
	var towns_without: Array = []
	var thermal_towns: int = 0
	for town in TownCatalogue.towns():
		if not bool(town["thermal"]):
			continue
		thermal_towns += 1
		var centre: Vector3 = town["centre"]
		var found: bool = false
		for zone in zones:
			var at: Vector3 = zone["position"]
			if Vector2(at.x - centre.x, at.z - centre.z).length() <= float(town["site"]["r"]):
				found = true
		if not found:
			towns_without.append(town["name"])
	_check("every_seated_town_that_has_a_thermal_has_one_over_its_site", thermal_towns > 0 and towns_without.is_empty()
			and zones.size() >= thermal_towns + FEWEST_SCATTERED_THERMALS,
		"%d zones: %d thermal towns, %d without one %s" % [zones.size(), thermal_towns, towns_without.size(), towns_without])
	# BASED ON THE GROUND, OFF THE WATER, AND ITS CLOUD CLEAR OF THE ROCK within its own kind's reach.
	var off_the_ground: Array = []
	var in_the_rock: Array = []
	var least_clear: float = INF
	for zone in zones:
		var at: Vector3 = zone["position"]
		var ground: float = float(int(field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / TICKS
		if absf(at.y - ground) > 1.0 / TICKS or int(field.call("water_ticks_at", roundi(at.x), roundi(at.z))) > no_water:
			off_the_ground.append([at, snappedf(at.y - ground, 0.01)])
		var reach: float = float(zone["radius"]) * LiftYard.CLOUD_SPREAD * float(LiftYard.cloud_type(zone)["spread"])
		var clear: float = float(zone["top"]) - _highest_in_a_circle(field, at, reach, no_water)
		least_clear = minf(least_clear, clear)
		if clear < 0.0 or float(zone["top"]) <= at.y:
			in_the_rock.append([at, snappedf(clear, 0.1)])
	_check("every_zone_is_based_on_the_ground_off_the_water_and_its_cloud_clears_the_rock",
		not zones.is_empty() and off_the_ground.is_empty() and in_the_rock.is_empty(),
		"%d zones, %d off the ground %s, %d clouds in the rock %s; the least clear %.1f m" % [zones.size(), off_the_ground.size(),
			off_the_ground, in_the_rock.size(), in_the_rock, least_clear])
	# NO TWO CLOUDS ON ONE SPOT: no two zones' columns overlap.
	var stacked: Array = []
	for a in range(zones.size()):
		for b in range(a + 1, zones.size()):
			var pa: Vector3 = zones[a]["position"]
			var pb: Vector3 = zones[b]["position"]
			var apart: float = Vector2(pa.x - pb.x, pa.z - pb.z).length()
			if apart < float(zones[a]["radius"]) + float(zones[b]["radius"]):
				stacked.append([pa, pb, snappedf(apart, 1.0)])
	_check("no_two_zones_columns_overlap", not zones.is_empty() and stacked.is_empty(),
		"%d zones, %d pairs overlapping %s" % [zones.size(), stacked.size(), stacked])
	# THE COLUMN RISES WHERE IT MUST, a hand-built case (team-lead, 2026-09-15): no zone on today's alpine world needs its
	# column raised (with the raise taken out every cloud still clears by 366.6 m), so the raise is proven here instead. The
	# spot on the land where the ground rises most within the widest cloud's reach of the widest zone is found on a sweep, a
	# zone is placed there by Terrain.grounded_zone, and its cloud must clear that ground -- which it can only by standing
	# taller than THERMAL_TOP.
	var widest_radius: float = 0.0
	for zone in zones:
		widest_radius = maxf(widest_radius, float(zone["radius"]))
	var widest_reach: float = widest_radius * Terrain.widest_cloud_reach()
	var span: float = Terrain.land_reach() * 0.72
	var best_rise: float = -INF
	var best_at := Vector3.ZERO
	var sweep_x: float = -span
	while sweep_x <= span:
		var sweep_z: float = -span
		while sweep_z <= span:
			if int(field.call("water_ticks_at", roundi(sweep_x), roundi(sweep_z))) <= no_water:
				var spot := Vector3(sweep_x, float(int(field.call("height_ticks_at", roundi(sweep_x), roundi(sweep_z)))) / TICKS, sweep_z)
				var rise: float = _highest_in_a_circle(field, spot, widest_reach, no_water, RISING_SWEEP_SAMPLE) - spot.y
				if rise > best_rise:
					best_rise = rise
					best_at = spot
			sweep_z += RISING_SWEEP_STEP
		sweep_x += RISING_SWEEP_STEP
	var raised: Dictionary = Terrain.grounded_zone(best_at, widest_radius, 4.0)
	var beside: float = _highest_in_a_circle(field, best_at, widest_reach, no_water)
	var rose: float = float(raised.get("top", -INF)) - best_at.y
	_check("a_zone_beside_a_peak_stands_its_column_taller_until_its_widest_cloud_clears_the_rock",
		best_rise > Terrain.THERMAL_TOP and not raised.is_empty() and float(raised["top"]) >= beside and rose > Terrain.THERMAL_TOP,
		"the ground rises %.1f m within %.0f m of (%.0f, %.1f, %.0f); the zone's column %.0f m, its top %.1f against the highest ground %.1f" % [
			best_rise, widest_reach, best_at.x, best_at.y, best_at.z, rose, float(raised.get("top", -INF)), beside])
	# THE SIMULATION HAS THEM: every zone's middle, halfway up its column -- far under the last 150 m where lift fades
	# (cockpit_world.cpp, kLiftFade) -- rises at no less than its own strength; overlapping zones only add.
	var unfelt: Array = []
	for zone in zones:
		var at: Vector3 = zone["position"]
		var halfway := Vector3(at.x, (at.y + float(zone["top"])) * 0.5, at.z)
		var up: float = float(Sim.server.rising(halfway))
		if up < float(zone["strength"]) - 0.01:
			unfelt.append([at, snappedf(up, 0.01), float(zone["strength"])])
	_check("every_zone_rises_in_the_simulation_halfway_up_its_column", not zones.is_empty() and unfelt.is_empty(),
		"%d zones, %d not felt %s" % [zones.size(), unfelt.size(), unfelt])
	# THE MARKERS ON THE GROUND UNDER THEMSELVES: what LiftYard draws, against the field.
	var hoops: int = 0
	var draped: int = 0
	var off_ground: Array = []
	var worst_end: float = 0.0
	var worst_sag: float = 0.0
	var worst_wisp: float = 0.0
	for zone in zones:
		var at: Vector3 = zone["position"]
		var placed: Dictionary = LiftYard.ring_placement(zone)
		var pieces: Array = placed["pieces"]
		if pieces.is_empty():
			hoops += 1
			var middle: float = float(zone["radius"]) * LiftYard.RING_MIDDLE
			for k in range(HOOP_SAMPLES):
				var about: float = TAU * float(k) / float(HOOP_SAMPLES)
				var under: float = _surface_at(field, at.x + cos(about) * middle, at.z + sin(about) * middle, no_water)
				var off: float = absf(under - at.y)
				worst_end = maxf(worst_end, off)
				if off > 1.0 / TICKS:
					off_ground.append(["hoop", at, snappedf(under - at.y, 0.01)])
					break
		for piece in pieces:
			draped += 1
			var t: Transform3D = piece
			if t.basis.determinant() <= 0.0:
				off_ground.append(["piece mirrored", t.origin, snappedf(t.basis.determinant(), 0.01)])
			for end in [t.origin - t.basis.x * 0.5, t.origin + t.basis.x * 0.5]:
				var over: float = (end as Vector3).y - _surface_at(field, (end as Vector3).x, (end as Vector3).z, no_water)
				worst_end = maxf(worst_end, absf(over - LiftYard.RING_OVER))
				if absf(over - LiftYard.RING_OVER) > 1.0 / TICKS + 0.01:
					off_ground.append(["piece end", end, snappedf(over, 0.01)])
			var sag: float = absf(t.origin.y - _surface_at(field, t.origin.x, t.origin.z, no_water) - LiftYard.RING_OVER)
			worst_sag = maxf(worst_sag, sag)
			if sag > RING_SAG:
				off_ground.append(["piece middle", t.origin, snappedf(sag, 0.1)])
		for w in range(LiftYard.WISPS):
			var from: Vector3 = LiftYard.wisp_ends(zone, w, Vector3.ZERO)[0]
			var over: float = from.y - _surface_at(field, from.x, from.z, no_water)
			worst_wisp = maxf(worst_wisp, absf(over - LiftYard.WISP_OVER))
			if absf(over - LiftYard.WISP_OVER) > 1.0 / TICKS + 0.01:
				off_ground.append(["wisp", from, snappedf(over, 0.01)])
	_check("every_ring_and_wisp_stands_on_the_ground_under_itself", not zones.is_empty() and off_ground.is_empty(),
		"%d level hoops, %d draped pieces, %d wisps; %d off the ground %s; the worst end or hoop point %.3f m off, piece middle %.2f m, wisp start %.3f m" % [
			hoops, draped, zones.size() * LiftYard.WISPS, off_ground.size(), off_ground.slice(0, 6), worst_end, worst_sag, worst_wisp])
	_sections += 1


## The surface, ground or the water on it, at a point, asked of the field.
func _surface_at(field: Object, x: float, z: float, no_water: int) -> float:
	var ground: float = float(int(field.call("height_ticks_at", roundi(x), roundi(z)))) / TICKS
	var water: int = int(field.call("water_ticks_at", roundi(x), roundi(z)))
	return maxf(ground, float(water) / TICKS) if water > no_water else ground


## The highest surface, ground or water, inside a circle of `reach` round `at`, on a CLOUD_GROUND_STEP grid asked of the
## field directly.
func _highest_in_a_circle(field: Object, at: Vector3, reach: float, no_water: int, step_wanted: float = CLOUD_GROUND_STEP) -> float:
	var n: int = maxi(1, ceili(2.0 * reach / step_wanted))
	var step: float = 2.0 * reach / float(n)
	var points := PackedInt32Array()
	for j in range(n):
		for i in range(n):
			var x: float = at.x - reach + (float(i) + 0.5) * step
			var z: float = at.z - reach + (float(j) + 0.5) * step
			if Vector2(x - at.x, z - at.z).length() <= reach:
				points.append_array([roundi(x), roundi(z)])
	var heights: PackedInt32Array = field.call("heights_at", points)
	var waters: PackedInt32Array = field.call("waters_at", points)
	var high: float = -INF
	for k in range(heights.size()):
		var surface: float = float(heights[k]) / TICKS
		if waters[k] > no_water:
			surface = maxf(surface, float(waters[k]) / TICKS)
		high = maxf(high, surface)
	return high


## ---- the roads ------------------------------------------------------------------------------------------------------

func _the_roads_join_the_places_on_the_ground(field: Object) -> void:
	var no_water: int = ClassDB.class_get_integer_constant("GroundField", "NO_WATER")
	var roads: Array[Dictionary] = Terrain.roads(_level._solid)
	# ON THE GROUND AND OFF THE WATER: both ends of every piece on the field's ground under them within a tick, and its middle
	# on no water.
	var off: Array = []
	var worst_end: float = 0.0
	for road in roads:
		var a: Vector3 = road["from"]
		var b: Vector3 = road["to"]
		for end in [a, b]:
			var gap: float = absf((end as Vector3).y - _ground_at(field, (end as Vector3).x, (end as Vector3).z))
			worst_end = maxf(worst_end, gap)
			if gap > 1.0 / TICKS + 0.001:
				off.append(["end", (end as Vector3).round(), snappedf(gap, 0.01)])
		var middle: Vector3 = (a + b) * 0.5
		if int(field.call("water_ticks_at", roundi(middle.x), roundi(middle.z))) > no_water:
			off.append(["on water", middle.round()])
	_check("every_alpine_road_lies_on_the_ground_and_off_the_water", not roads.is_empty() and off.is_empty(),
		"%d pieces, %d wrong %s; the worst end %.3f m off the ground" % [roads.size(), off.size(), off.slice(0, 5), worst_end])
	# NOT UP A CLIFF: no piece rises or falls more than ROAD_CLIFF of its run, by the field's heights under its ends.
	var steep: Array = []
	var steepest: float = 0.0
	for road in roads:
		var a: Vector3 = road["from"]
		var b: Vector3 = road["to"]
		var run: float = maxf(Vector2(b.x - a.x, b.z - a.z).length(), 0.001)
		var grade: float = absf(_ground_at(field, b.x, b.z) - _ground_at(field, a.x, a.z)) / run
		steepest = maxf(steepest, grade)
		if grade > TownTuning.ROAD_CLIFF + 0.0005:
			steep.append([a.round(), snappedf(grade * 100.0, 0.1)])
	_check("no_alpine_road_climbs_a_cliff", not roads.is_empty() and steep.is_empty(),
		"%d pieces steeper than %.0f%% %s; the steepest %.1f%%" % [steep.size(), TownTuning.ROAD_CLIFF * 100.0, steep.slice(0, 5),
			steepest * 100.0])
	# EVERY PLACE JOINED into one network by the links the pieces carry. The places are counted from the towns and the ground's
	# own catalogue, not from the roads: the seated towns in catalogue order, then the airfield strips.
	var towns: Array[Dictionary] = TownCatalogue.towns()
	var strips: int = ((field.call("catalogue") as Dictionary).get("airfields", []) as Array).size()
	var group: Array[int] = []
	for p in range(towns.size() + strips):
		group.append(p)
	var strange: int = 0
	for road in roads:
		var link: Vector2i = road["link"]
		if mini(link.x, link.y) < 0 or maxi(link.x, link.y) >= group.size():
			strange += 1
			continue
		group[_group_of(group, link.x)] = _group_of(group, link.y)
	var apart: Array[String] = []
	for p in range(group.size()):
		if _group_of(group, p) != _group_of(group, 0):
			apart.append(String(towns[p]["name"]) if p < towns.size() else "strip %d" % (p - towns.size()))
	_check("every_seated_town_and_airfield_is_joined_by_road", towns.size() > 1 and strips > 0 and apart.is_empty() and strange == 0,
		"%d towns and %d strips, %d not joined %s, %d links naming no place; %s" % [towns.size(), strips, apart.size(), apart, strange,
			TownPlan.last_tally])
	_sections += 1


func _group_of(group: Array[int], p: int) -> int:
	while group[p] != p:
		p = group[p]
	return p


## ---- the woods ------------------------------------------------------------------------------------------------------

## How far the eye is moved to have GroundView build cells after the woods grew, as a share of the land's reach.
const LATER_CELLS_AT: float = 0.6
## How far under the ground at its middle a tree's foot may be sunk, metres: a trunk half a metre wide on a 35 degree slope
## sinks about 0.4 m, and the ground is answered to the metre. A foot deeper than this is a tree buried, not stood.
const MOST_TREE_SINK: float = 1.5


func _the_woods_stand_on_the_ground(field: Object) -> void:
	var no_water: int = ClassDB.class_get_integer_constant("GroundField", "NO_WATER")
	var tuning: GDScript = load("res://world/forest_tuning.gd")
	var plain: Dictionary = tuning.call("for_tier", false, {})
	var fine: Dictionary = tuning.call("for_tier", true, {})
	var most: int = int(plain["most_stands"])
	var towns: Array[Dictionary] = TownCatalogue.towns()
	var airfields: Array = (field.call("catalogue") as Dictionary).get("airfields", [])
	var approaches: Array[Dictionary] = Terrain.clearances()
	# THE WOODS: at least one and no more than the floor paints, each dry and off every site, strip and approach on a grid twice
	# as fine as the rule's, and no two touching.
	var stands: Array[Dictionary] = Forests.stands()
	var wrong_stands: Array = []
	for stand in stands:
		var half: Vector2 = stand["half"]
		var step: float = Forests.STAND_SAMPLE * 0.5
		var x: float = -half.x + step * 0.5
		while x < half.x:
			var y: float = -half.y + step * 0.5
			while y < half.y:
				var p: Vector3 = Forests.world_of(stand, Vector2(x, y))
				p.y = float(int(field.call("height_ticks_at", roundi(p.x), roundi(p.z)))) / TICKS
				if int(field.call("water_ticks_at", roundi(p.x), roundi(p.z))) > no_water or _kept_out_here(p, towns, airfields, approaches):
					wrong_stands.append([stand["name"], p])
					break
				y += step
			x += step
	for a in range(stands.size()):
		for b in range(a + 1, stands.size()):
			if (stands[a]["centre"] as Vector3).distance_to(stands[b]["centre"]) < (stands[a]["half"] as Vector2).length() + (stands[b]["half"] as Vector2).length():
				wrong_stands.append([stands[a]["name"], stands[b]["name"], "touching"])
	# AND THE KEEP-OUT ITSELF, BY HAND: the woods' rule must say no at every seated town's middle and every strip's middle,
	# whether or not a wood happened to be tried there -- on today's ground the rule's first eight woods would be the same
	# with the sites or the strips taken out of it, so without these cases the keep-outs would be unproven.
	for town in towns:
		var middle: Vector3 = town["centre"]
		if not Forests.is_kept_out(middle, towns, airfields, approaches):
			wrong_stands.append(["the rule lets a wood onto", town["name"]])
	# A STRIP BY ITS OWN ARM: every runway approach on today's ground covers its strip and the strip's margin, so the rule's
	# strip keep-out is asked with no approaches at all, at each strip's middle -- or taking the strips out of the rule would
	# pass unseen behind the approaches (it did, 2026-09-15).
	for strip in airfields:
		var middle := Vector3(float(strip["x"]), float(strip["level"]) / 1024.0, float(strip["z"]))
		if not Forests.is_kept_out(middle, towns, airfields, [] as Array[Dictionary]):
			wrong_stands.append(["the rule lets a wood onto the strip at", middle])
	_check("every_alpine_wood_is_dry_and_off_every_town_site_strip_and_approach_and_no_two_touch",
		stands.size() >= 1 and stands.size() <= most and wrong_stands.is_empty(),
		"%d woods (the floor paints %d); the tries: %s; wrong %s" % [stands.size(), most, Forests.last_tally, wrong_stands.slice(0, 6)])
	# EVERY TREE ON THE GROUND: its foot within a tick of the lowest ground under its trunk, no ground round its trunk's edge
	# below its foot (the downhill edge), no steeper than the woods' slope limit, and not on water. Planted as the level
	# planted them, from the level's own boxes, on both finishes.
	var solid: Array[Dictionary] = []
	for box in _level.get("_solid"):
		solid.append(box)
	var keepouts: Array[Dictionary] = Terrain.ground_keepouts(solid, [])
	var said: PackedStringArray = []
	var wrong_trees: Array = []
	var worst_foot: float = 0.0
	var worst_edge: float = 0.0
	var steepest: float = 0.0
	var deepest_sink: float = 0.0
	for tier in [["plain", plain], ["fine", fine]]:
		var chunks: Array[Dictionary] = Woodland.plant(stands, keepouts, tier[1], fine)
		var trees: int = 0
		for chunk in chunks:
			for tree in chunk["trees"]:
				trees += 1
				var foot: Vector3 = tree["position"]
				var radius: float = float(tree["height"]) * float((tier[1] as Dictionary)["trunk_width"]) * 0.5
				var under: float = _ground_at(field, foot.x, foot.z)
				var low: float = under
				for k in range(8):
					var about: float = TAU * float(k) / 8.0
					var edge: float = _ground_at(field, foot.x + cos(about) * radius, foot.z + sin(about) * radius)
					low = minf(low, edge)
					worst_edge = maxf(worst_edge, foot.y - edge)
				worst_foot = maxf(worst_foot, foot.y - low)
				deepest_sink = maxf(deepest_sink, under - foot.y)
				var east: float = _ground_at(field, foot.x + 16.0, foot.z) - _ground_at(field, foot.x - 16.0, foot.z)
				var south: float = _ground_at(field, foot.x, foot.z + 16.0) - _ground_at(field, foot.x, foot.z - 16.0)
				var slope: float = rad_to_deg(atan(Vector2(east, south).length() / 32.0))
				steepest = maxf(steepest, slope)
				if foot.y - low > 1.0 / TICKS + 0.001 or under - foot.y > MOST_TREE_SINK or slope > Forests.MOST_TREE_SLOPE + 0.001 \
						or int(field.call("water_ticks_at", roundi(foot.x), roundi(foot.z))) > no_water:
					wrong_trees.append([tier[0], foot, snappedf(foot.y - low, 0.01), snappedf(slope, 0.1)])
		said.append("%s %d trees in %d chunks" % [tier[0], trees, chunks.size()])
	var planted: Dictionary = (_level.get("woodland") as Woodland).planted if _level.get("woodland") != null else {}
	_check("every_alpine_tree_stands_on_the_ground_under_its_trunk_on_a_slope_its_wood_holds",
		not said.is_empty() and wrong_trees.is_empty() and int(planted.get("plain_trees", 0)) > 0,
		"%s; the level grew plain %d in %d chunks and fine %d in %d in %.0f ms; %d wrong %s; the most a foot stood over the lowest ground under its trunk %.3f m, the most an edge lay under a foot %.3f m, the deepest sink %.2f m, the steepest %.1f degrees" % [
			", ".join(said), int(planted.get("plain_trees", 0)), int(planted.get("plain_chunks", 0)), int(planted.get("fine_trees", 0)),
			int(planted.get("fine_chunks", 0)), float(planted.get("milliseconds", -1.0)), wrong_trees.size(), wrong_trees.slice(0, 6), worst_foot,
			worst_edge, deepest_sink, steepest])
	# THE FLOOR ON THE GENERATED GROUND: every cell GroundView has built carries the floor's rectangles, and so does every cell
	# it builds after the woods grew -- here, cells built round an eye moved across the land.
	var view: GroundView = _level.ground_view
	var wanted: Dictionary = (_level.get("woodland") as Woodland).floor_values(false)
	var seen: Dictionary = {}
	var bare: Array = []
	if view != null:
		for node in view.get_children():
			if node is MeshInstance3D:
				seen[node.name] = true
				if not _floored(node as MeshInstance3D, wanted):
					bare.append(node.name)
		var land: float = Terrain.land_reach()
		_level.scenery.fill_around(Vector3(land * LATER_CELLS_AT, 2000.0, -land * LATER_CELLS_AT))
	var later: int = 0
	if view != null:
		for node in view.get_children():
			if node is MeshInstance3D and not seen.has(node.name):
				later += 1
				if not _floored(node as MeshInstance3D, wanted):
					bare.append(node.name)
	_check("every_ground_cell_carries_the_floor_under_the_woods_and_so_does_every_cell_built_after",
		view != null and seen.size() > 0 and later > 0 and bare.is_empty() and int(wanted.get("forest_count", 0)) == mini(stands.size(), most),
		"%d cells built round the spawn, %d built after round (%.0f, %.0f); %d floor rectangles, each cell carrying only those that touch it; %d cells wrong %s" % [seen.size(), later,
			Terrain.land_reach() * LATER_CELLS_AT, -Terrain.land_reach() * LATER_CELLS_AT, int(wanted.get("forest_count", 0)), bare.size(), bare.slice(0, 4)])
	_sections += 1


## Whether a point is inside a seated town's site and margin, an airfield strip and its margin, or a runway approach: asked
## here of each owner's own numbers, not of the woods' rule, so the rule can be caught leaving one out.
func _kept_out_here(at: Vector3, towns: Array[Dictionary], airfields: Array, approaches: Array[Dictionary]) -> bool:
	for town in towns:
		var centre: Vector3 = town["centre"]
		if Vector2(at.x - centre.x, at.z - centre.z).length() <= float(town["site"]["r"]) + float(town["site"]["margin"]):
			return true
	for strip in airfields:
		if absf(at.x - float(strip["x"])) <= float(strip["half_long"]) + float(strip["margin"]) \
				and absf(at.z - float(strip["z"])) <= float(strip["half_wide"]) + float(strip["margin"]):
			return true
	return not Terrain.is_clear(approaches, at, Vector3.ONE)


func _ground_at(field: Object, x: float, z: float) -> float:
	return float(int(field.call("height_ticks_at", roundi(x), roundi(z)))) / TICKS


## Whether a ground cell's material carries the floor `wanted` sets FOR THAT CELL: exactly the woods whose rectangles touch
## its square, in order -- worked out here from the rectangles' corners, not by GroundView's own test -- so a touching cell
## paints what the whole list painted and a cell no wood touches loops over nothing.
func _floored(node: MeshInstance3D, wanted: Dictionary) -> bool:
	var paint := node.material_override as ShaderMaterial
	if paint == null or not node.has_meta(&"cell"):
		return false
	var cell: Vector2i = node.get_meta(&"cell")
	var frames: Array = wanted.get("forest_frame", [])
	var halves: Array = wanted.get("forest_half", [])
	# Grown by the paint's reach past a rectangle, as the floor's own values say it (FINE's `floor_ragged`; none on PLAIN).
	var margin: float = float(wanted.get("floor_ragged", 0.0))
	var expected: Array = []
	for i in range(int(wanted.get("forest_count", 0))):
		if _rectangle_meets_square(frames[i], halves[i] + Vector4(margin, margin, 0.0, 0.0), cell):
			expected.append(frames[i])
	var count: Variant = paint.get_shader_parameter("forest_count")
	var carried: Variant = paint.get_shader_parameter("forest_frame")
	if count == null or int(count) != expected.size() or not (carried is Array):
		return false
	for i in range(expected.size()):
		if not (carried[i] as Vector4).is_equal_approx(expected[i]):
			return false
	return true


## Whether a floor rectangle meets a GroundView cell's square: some corner of either inside the other, or an edge of the
## rectangle crossing the square (tested on 32 points along each edge).
func _rectangle_meets_square(frame: Vector4, half: Vector4, cell: Vector2i) -> bool:
	var centre := Vector2(frame.x, frame.y)
	var across := Vector2(frame.z, frame.w)
	var along := Vector2(across.y, -across.x)
	var low := Vector2(float(cell.x * GroundView.CELL), float(cell.y * GroundView.CELL))
	var high: Vector2 = low + Vector2.ONE * float(GroundView.CELL)
	var corners: Array[Vector2] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			corners.append(centre + across * half.x * sx + along * half.y * sy)
	for k in range(4):
		var a: Vector2 = corners[[0, 1, 3, 2][k]]
		var b: Vector2 = corners[[1, 3, 2, 0][k]]
		for s in range(33):
			var p: Vector2 = a.lerp(b, float(s) / 32.0)
			if p.x >= low.x and p.x <= high.x and p.y >= low.y and p.y <= high.y:
				return true
	for q in [low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]:
		var to: Vector2 = (q as Vector2) - centre
		if absf(to.dot(across)) <= half.x and absf(to.dot(along)) <= half.y:
			return true
	return false


## ---- the traffic -----------------------------------------------------------------------------------------------------

## How far over the highest surface near it an aeroplane launched on the generated ground must stand, metres: the island
## table's lowest launch, 60 m, less a little for sampling.
const AIR_CLEAR: float = 55.0
## The fewest points a pool may keep and still be a pool.
const FEWEST_IN_A_POOL: int = 8
## How high over the ground a parked spawn may stand, metres: the island table's highest parked one on a place, a
## helicopter put 26 m up, and a little.
const PARKED_HIGHEST: float = 27.0
## How near a ground spawn's height is to the highest surface near it plus its island height, metres: this suite samples the
## field on its own texel grid, Terrain on its, so they may differ by part of a texel's rise.
const HALF_A_METRE: float = 0.5
## How near a runway's middle, and a town's centre, a spawn on that place stands, metres: within the strip the runway lies
## on (1,800 m long) and within a seated town's flat.
const ON_A_RUNWAY_WITHIN: float = 900.0
## AT REST, after the settle: how far a parked machine is looked for from where it was put, and how far it may have slid, how
## far tipped, how fast it may still be moving and spinning. Set from the first run's worst readings (see the check's detail).
const REST_SEARCH: float = 60.0
const REST_SLID: float = 5.0
const REST_TIPPED: float = 12.0
const REST_MOVING: float = 0.3
const REST_SPINNING: float = 0.2
## PHYSICS FRAMES the traffic runs before it is judged, after the sections before it: at this project's 120 a second, 5 s of
## simulation at the least. On the generated ground the Ford's autopilot turns 4.6 degrees in it, which slid a parked
## Hawkeye 6.64 m while the deck ignored the ship's turn, so the rest check prints the carrier's turn beside it;
## fleet_shapes holds a whole turn.
const TRAFFIC_SETTLE_FRAMES: int = 600


## THE TABLE, THE POOLS AND THE FIRES STAND ON THE GROUND, held against the field asked here:
## - every aeroplane the table launches stands AIR_CLEAR over the highest surface within `Terrain.AIR_SPAWN_ROOM` of it;
##   every ship floats on open sea as deep as its keel needs and inside the placed reach; every parked spawn stands over the
##   ground of the place it names -- a runway's aircraft and tower on the first strip, a town's cars and helicopter in it --
##   no lower than that ground and no higher than PARKED_HIGHEST over it;
## - every wing's and helicopter's waypoint stands its kind's lowest height over the highest surface within its room and
##   has a leg to another that the simulation's ground clears; every boat's is open sea as deep as a boat needs;
## - every fire stands on the ground and not on water;
## - every machine the level set going on its own has somewhere to be.
func _the_traffic_stands_on_the_ground(field: Object) -> void:
	var no_water: int = ClassDB.class_get_integer_constant("GroundField", "NO_WATER")
	var reach: float = Terrain.placed_reach()
	var air: int = 0
	var low: Array = []
	var ships: int = 0
	var shallow: Array = []
	var parked: int = 0
	var off_their_place: Array = []
	# THE APRON FULL: the island keeps five helicopters, Chinooks and a low pod by its spawn, and on the generated ground they
	# go on the first runway's apron, one to each of Terrain.APRON_SPOTS -- so as many of them stand on the runway as there
	# are spots. A rule that left them out would otherwise leave every placed spawn on its place and pass.
	var on_the_apron: int = 0
	# A SHIP'S PLACE IS AS DEEP AS ITS DRAUGHT AND THE KEEL ROOM, for every kind that floats, the draught WORKED OUT HERE from
	# the kind's own geometry -- its waterline less the lowest bottom of its hull parts, or -extents.y with none -- and not
	# asked of the simulation Terrain now reads, which would compare a number with itself (team-lead, carrier's note).
	var draughts: Array = []
	var wrong_depths: Array = []
	for kind in Sim.Kind.values():
		if not Terrain.is_a_ship(kind):
			continue
		var geometry: Dictionary = Sim.geometry_of(kind)
		var lowest: float = -float((geometry.get("extents", Vector3.ZERO) as Vector3).y)
		var bottoms: Array[float] = []
		for part in geometry.get("parts", []):
			if String((part as Dictionary).get("part", "")) == "hull":
				bottoms.append(float((part as Dictionary).get("bottom", 0.0)))
		if not bottoms.is_empty():
			lowest = bottoms.min()
		var draught: float = float(geometry.get("waterline", 0.0)) - lowest
		draughts.append([Sim.kind_name(kind), snappedf(draught, 0.001)])
		if draught <= 0.0 or absf(Terrain.ship_depth(kind) - (draught + Terrain.SHIP_KEEL_ROOM)) > 0.001:
			wrong_depths.append([Sim.kind_name(kind), snappedf(Terrain.ship_depth(kind), 0.001)])
	_check("every_ships_place_is_as_deep_as_its_draught_and_the_keel_room", wrong_depths.is_empty(),
		"draughts from each kind's geometry %s, keel room %.1f m; wrong %s" % [draughts, Terrain.SHIP_KEEL_ROOM, wrong_depths])
	for spawn in Terrain.spawns():
		var at: Vector3 = spawn["position"]
		var kind: int = int(spawn["kind"])
		if Terrain.is_a_ship(kind):
			ships += 1
			if not _open_sea_at(field, at, Terrain.ship_depth(kind)) or Vector2(at.x, at.z).length() > reach:
				shallow.append([Sim.kind_name(kind), at])
		elif spawn.get("place", &"") == &"carrier":
			# ON ITS CARRIER'S DECK, in the carrier's frame, not "a launched aeroplane too low over the sea" for the ship's
			# speed it carries: over the deck in plan (CarrierPlan.is_on_deck), and standing between the deck and half a
			# metre over its own half-height above it, where `Terrain.parked_on` put it.
			parked += 1
			var ship: Dictionary = _named_spawn(spawn.get("on", &""))
			var on_deck: bool = false
			if not ship.is_empty():
				var local: Vector3 = Transform3D(Basis(Vector3.UP, float(ship["yaw"])), ship["position"] as Vector3).affine_inverse() * at
				var half_high: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
				var over_deck: float = local.y - CarrierPlan.deck_height()
				on_deck = CarrierPlan.is_on_deck(Vector2(local.x, local.z)) and over_deck > 0.0 and over_deck < half_high + 1.0
			if not on_deck:
				off_their_place.append([Sim.kind_name(kind), "carrier", at, "not over its carrier's deck"])
		elif (spawn["velocity"] as Vector3).length() > 1.0:
			air += 1
			var clear: float = at.y - _highest_surface(field, at, Terrain.AIR_SPAWN_ROOM, no_water)
			if clear < AIR_CLEAR:
				low.append([Sim.kind_name(kind), at, snappedf(clear, 0.1)])
		else:
			parked += 1
			var place: StringName = spawn.get("place", &"")
			var under: float = float(int(field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / TICKS
			var over: float = at.y - under
			var on_its_place: bool = place != &"" and _on_the_place(place, at)
			if place == &"runway" and kind in [Sim.Kind.HELI, Sim.Kind.UH60, Sim.Kind.LITTLEBIRD, Sim.Kind.APACHE, Sim.Kind.CHINOOK, Sim.Kind.POD]:
				on_the_apron += 1
			# A GROUND SPAWN stands its island height ("over") over the highest surface within Terrain.HELI_ROOM of it -- asked
			# here of the field over the same square -- so its y is that surface plus "over", and it is never under the ground.
			var off: bool = over < -SEATED_WITHIN or over > PARKED_HIGHEST
			if place == &"ground":
				var wanted: float = _highest_surface(field, at, Terrain.HELI_ROOM, no_water) + float(spawn.get("over", -1000.0))
				off = over < -SEATED_WITHIN or absf(at.y - wanted) > HALF_A_METRE
			if off or not on_its_place:
				off_their_place.append([Sim.kind_name(kind), String(place), at, snappedf(over, 0.01)])
	_check("every_aeroplane_launched_clears_the_ground_every_ship_floats_on_deep_open_sea_and_every_parked_one_stands_on_its_place",
		air > 0 and low.is_empty() and ships > 0 and shallow.is_empty() and parked > 0 and off_their_place.is_empty()
			and on_the_apron == Terrain.APRON_SPOTS.size(),
		"%d launched, %d too low %s; %d ships, %d not on deep open sea inside %.0f m %s; %d parked, %d off their place %s; %d of %d apron spots taken" % [
			air, low.size(), low, ships, shallow.size(), reach, shallow, parked, off_their_place.size(), off_their_place,
			on_the_apron, Terrain.APRON_SPOTS.size()])

	# AT REST WHERE IT WAS PUT. The table's parked machines were seeded when the build finished and have had the settle
	# above; each is found among the simulation's vehicles by kind, nearest, and must be where it was put, upright and still.
	var states: Array = Sim.server.vehicle_states()
	var rested: int = 0
	var restless: Array = []
	var worst_rest := [0.0, 0.0, 0.0, 0.0]
	var aboard_said: Array[String] = []
	for spawn in Terrain.spawns():
		var kind: int = int(spawn["kind"])
		var aboard: bool = spawn.get("place", &"") == &"carrier"
		if ((spawn["velocity"] as Vector3).length() > 1.0 and not aboard) or Terrain.is_a_ship(kind):
			continue
		var put: Vector3 = spawn["position"]
		# A CRAFT PARKED ON A CARRIER is at rest ON THE DECK while the ship makes way: where it was put is the carrier's
		# CURRENT transform times the deck spot, asked of the simulation through the entity the level recorded for the
		# carrier's name -- never predicted from where the carrier was put, since its autopilot steers and the sea heaves it
		# -- and its speed, spin and tilt are measured against the carrier's, within the same REST_* limits.
		var carrier_now: Dictionary = {}
		if aboard:
			var ship: Dictionary = _named_spawn(spawn.get("on", &""))
			carrier_now = Sim.server.vehicle_state(_level.spawned_entity(spawn.get("on", &""))) if not ship.is_empty() else {}
			if carrier_now.is_empty():
				restless.append([Sim.kind_name(kind), put, "its carrier %s is not in the simulation" % spawn.get("on", &"")])
				continue
			var local: Vector3 = Transform3D(Basis(Vector3.UP, float(ship["yaw"])), ship["position"] as Vector3).affine_inverse() * put
			put = Transform3D(Basis(carrier_now["basis"] as Quaternion), carrier_now["position"] as Vector3) * local
		var nearest: Dictionary = {}
		var apart: float = REST_SEARCH
		for state in states:
			var p: Vector3 = (state as Dictionary)["position"]
			var d: float = Vector2(p.x - put.x, p.z - put.z).length()
			if int((state as Dictionary)["kind"]) == kind and d < apart:
				apart = d
				nearest = state
		if nearest.is_empty():
			restless.append([Sim.kind_name(kind), put, "not found within %.0f m" % REST_SEARCH])
			continue
		# ITS OWN LEVERS, FOR A CRAFT PARKED ON A CARRIER: the gear down on the deck and a Hawkeye's wings folded, as
		# `spawn_vehicle` set them when its ray found the deck of a carrier made the same tick (team-lead, 2026-09-15); and how
		# far round the carrier has come since it was put, so the watch is seen to hold a turn.
		if aboard:
			var levers: Dictionary = Sim.server.craft_controls(int(nearest["entity"]))
			var folded: bool = bool(levers.get("fold", false)) or kind != Sim.Kind.HAWKEYE
			var turned: float = rad_to_deg(absf(angle_difference(float(_named_spawn(spawn.get("on", &""))["yaw"]),
				_heading_of(carrier_now))))
			aboard_said.append("%s on %s: gear %s, fold %s; the carrier turned %.1f degrees since it was put" % [
				Sim.kind_name(kind), spawn.get("on", &""), levers.get("gear"), levers.get("fold"), turned])
			if not bool(levers.get("gear", false)) or not folded:
				restless.append([Sim.kind_name(kind), put, "on the deck with gear %s, fold %s" % [levers.get("gear"),
					levers.get("fold")]])
				continue
		var up: Vector3 = (nearest["basis"] as Quaternion) * Vector3.UP
		var level_up: Vector3 = (carrier_now["basis"] as Quaternion) * Vector3.UP if aboard else Vector3.UP
		var tilt: float = rad_to_deg(acos(clampf(up.dot(level_up), -1.0, 1.0)))
		# THE DECK'S VELOCITY WHERE IT STANDS: the carrier's middle's plus its turn across the arm (spin x r), since a ship
		# turning under way moves a spot abaft its island faster than its middle.
		var deck_moving: Vector3 = Vector3.ZERO
		if aboard:
			# THE DECK'S TRUE VELOCITY THERE: from the carrier's CENTRE OF MASS, whose velocity the simulation's is and whose
			# spin it is, and with the WHOLE spin. The wheels' grip holds a craft to the turn in plan (`deck_under`), but the
			# deck it stands on carries it through the roll too: judged against the turn in plan alone, the Ford's parked
			# Hawkeye read 0.475 m/s while 0.25 m from its spot.
			var mass: Dictionary = Sim.server.body_mass(_level.spawned_entity(spawn.get("on", &"")))
			var centre: Vector3 = (carrier_now["position"] as Vector3) \
				+ (carrier_now["basis"] as Quaternion) * (mass.get("centre", Vector3.ZERO) as Vector3)
			deck_moving = (carrier_now["velocity"] as Vector3) + (carrier_now["spin"] as Vector3).cross(put - centre)
		var speed: float = ((nearest["velocity"] as Vector3) - deck_moving).length()
		var spin: float = ((nearest["spin"] as Vector3) - (carrier_now.get("spin", Vector3.ZERO) as Vector3)).length()
		worst_rest = [maxf(worst_rest[0], apart), maxf(worst_rest[1], tilt), maxf(worst_rest[2], speed), maxf(worst_rest[3], spin)]
		if apart > REST_SLID or tilt > REST_TIPPED or speed > REST_MOVING or spin > REST_SPINNING:
			restless.append([Sim.kind_name(kind), put, snappedf(apart, 0.01), snappedf(tilt, 0.1), snappedf(speed, 0.001),
				snappedf(spin, 0.001)])
		else:
			rested += 1
	# EVERY NAMED CARRIER, AND EVERYTHING PARKED ON IT, IS PLACED on this world. The generated ground's arm drops a ship with
	# no open sea and takes whatever is parked on it with it, saying so by name; the island's table never drops. So no real
	# level may drop one: asserted here from what was placed, not from whether a warning printed.
	var named: Array[StringName] = []
	var orphans: Array = []
	for spawn in Terrain.spawns():
		if spawn.has("name"):
			named.append(spawn["name"])
	for spawn in Terrain.spawns():
		if spawn.get("place", &"") == &"carrier" and not (spawn.get("on", &"") in named):
			orphans.append([Sim.kind_name(int(spawn["kind"])), spawn.get("on", &"")])
	_check("every_named_carrier_and_what_is_parked_on_it_is_placed", named.has(&"ford") and orphans.is_empty(),
		"named %s; parked on a carrier that is not placed: %s" % [named, orphans])
	_check("every_parked_machine_is_at_rest_where_it_was_put_after_settling",
		rested > 0 and restless.is_empty() and not aboard_said.is_empty(),
		"%d at rest, %d not %s; the worst: %.2f m from where it was put, %.1f degrees tilted, %.3f m/s, %.3f rad/s; on a carrier: %s; watched at least %.0f s" % [
			rested, restless.size(), restless, worst_rest[0], worst_rest[1], worst_rest[2], worst_rest[3], aboard_said,
			float(TRAFFIC_SETTLE_FRAMES) / float(Engine.physics_ticks_per_second)])

	var nothing_solid: Array[Dictionary] = []
	var grid := BoxGrid.new(nothing_solid)
	var said: PackedStringArray = []
	var wrong: int = 0
	# [kind, room, lowest height]. The leg rules each pool is held to are asked of the SERVER's simulation, kind by kind --
	# the tiltrotor's own 400 m shortest leg among them -- never read back off Terrain, which asks the client's.
	for row in [[Sim.Kind.PLANE, Terrain.WING_ROOM, Terrain.WING_LOW], [Sim.Kind.OSPREY, Terrain.WING_ROOM, Terrain.WING_LOW],
			[Sim.Kind.HELI, Terrain.HELI_ROOM, Terrain.HELI_LOW]]:
		var rules: Dictionary = Sim.server.ai_leg_rules(int(row[0]))
		if rules.is_empty():
			wrong += 1
			said.append("%s has no leg rules in the simulation" % Sim.kind_name(int(row[0])))
			continue
		var pool: Array[Vector3] = Terrain.waypoints(int(row[0]), grid)
		var under: int = 0
		var stranded: int = 0
		for at in pool:
			if at.y - _highest_surface(field, at, float(row[1]), no_water) < float(row[2]) - 0.5:
				under += 1
			var leg: bool = false
			for other in pool:
				var apart: float = Vector2(other.x - at.x, other.z - at.z).length()
				if other != at and apart >= float(rules["shortest"]) and bool(Sim.server.ground_leg_is_clear(at, other,
						float(rules["clearance"]), float(rules["overhead"]))):
					leg = true
					break
			if not leg:
				stranded += 1
		wrong += under + stranded + (1 if pool.size() < FEWEST_IN_A_POOL else 0)
		said.append("%s %d points, %d under their height, %d with no clear leg (%.0f m clear, %.0f m at least)" % [
			Sim.kind_name(int(row[0])), pool.size(), under, stranded, float(rules["clearance"]), float(rules["shortest"])])
	var boats: Array[Vector3] = Terrain.waypoints(Sim.Kind.BOAT, grid)
	var ashore: int = 0
	for at in boats:
		if not _open_sea_at(field, at, Terrain.ship_depth(Sim.Kind.BOAT)):
			ashore += 1
	said.append("boat %d points, %d not on deep open sea" % [boats.size(), ashore])
	_check("every_waypoint_stands_its_height_over_the_ground_with_a_clear_leg_and_every_boat_one_is_open_sea",
		wrong == 0 and boats.size() >= FEWEST_IN_A_POOL and ashore == 0, "; ".join(said))

	# AND EVERY BRIG'S POINT HAS A LEG WITH WATER THE WHOLE WAY, by the sailor's own rules asked of the SERVER's simulation
	# (team-lead, 2026-09-15): a point with none strands a brig spawned on it, and on this level 7 of 35 had none.
	var sail_rules: Dictionary = Sim.server.ai_leg_rules(Sim.Kind.PIRATE)
	var hop: float = float(sail_rules.get("hop", 0.0))
	var wet: float = float(sail_rules.get("wet", 0.0))
	var brig_pool: Array[Vector3] = Terrain.waypoints(Sim.Kind.PIRATE, grid)
	var dry: Array[Vector3] = []
	for at in brig_pool:
		var leg: bool = false
		for other in brig_pool:
			if other != at and Vector2(other.x - at.x, other.z - at.z).length() >= hop \
					and bool(Sim.server.sea_leg_is_deep(at, other, wet)):
				leg = true
				break
		if not leg:
			dry.append(at)
	_check("every_brig_pool_point_has_a_leg_with_water_the_whole_way",
		hop > 0.0 and brig_pool.size() >= Terrain.PIRATE_FLEET * 2 and dry.is_empty(),
		"%d points, %d with no leg of %.0f m or more with %.1f m of water the whole way: %s" % [brig_pool.size(), dry.size(),
			hop, wet, dry.slice(0, 3)])

	var fires: Array[Dictionary] = Terrain.fires()
	var misplaced: Array = []
	for fire in fires:
		var at: Vector3 = fire["position"]
		var ground: float = float(int(field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / TICKS
		if absf(at.y - ground) > 0.5 or int(field.call("water_ticks_at", roundi(at.x), roundi(at.z))) > no_water:
			misplaced.append(at)
	_check("every_fire_stands_on_the_ground_and_not_on_water", fires.size() > 0 and misplaced.is_empty(),
		"%d fires, %d off the ground or on water %s" % [fires.size(), misplaced.size(), misplaced])

	var lone: int = 0
	var routed: int = 0
	var nowhere: Array = []
	for state in Sim.server.vehicle_states():
		var route: Dictionary = Sim.server.ai_destination(int(state["entity"]))
		if route.is_empty() or bool(route.get("following", false)):
			continue
		lone += 1
		if int(route.get("legs", 0)) >= 1:
			routed += 1
		else:
			var at: Vector3 = state["position"]
			var why: String = "%.1f m over the ground" % [at.y - float(Sim.server.ground_height_at(at.x, at.z))]
			# A SHIP WITH NO LEG SAYS WHY: how many of its own pool's points lie a leg's length off with its need the whole
			# way from where it is, asked of the simulation's rules.
			if Terrain.is_a_ship(int(state["kind"])):
				var rules: Dictionary = Sim.server.ai_leg_rules(int(state["kind"]))
				var need: float = float(rules.get("need", 0.0))
				var pool: Array[Vector3] = Terrain.waypoints(int(state["kind"]), grid)
				var deep: int = 0
				for point in pool:
					if Vector2(point.x - at.x, point.z - at.z).length() >= float(rules.get("shortest", 0.0)) \
							and bool(Sim.server.sea_leg_is_deep(at, point, need)):
						deep += 1
				why += "; %d of its %d pool points a leg away with %.2f m the whole way" % [deep, pool.size(), need]
			nowhere.append([Sim.kind_name(int(state["kind"])), at, why])
	_check("every_machine_on_its_own_has_somewhere_to_be_on_the_ground", lone > 0 and routed == lone,
		"%d of %d independents have a leg; none: %s" % [routed, lone, nowhere])
	_sections += 1


## ---- the soft edge ---------------------------------------------------------------------------------------------------

## EVERY LEVEL FITS THE WIDEST TURN ANY POWERED WING NEEDS. A level's soft edge is a band as deep as that turn, and a level
## whose band start plus two such turns reaches the wire's last resort is refused when it loads (`WorldEdge.band_for`). No
## other suite builds the REAL levels' bands -- world_edge builds its own -- so a wing whose top speed or autopilot bank made
## the widest turn wider would refuse alpine only when somebody loaded it. The E-2D made it 2,624 m, at its real 180 m/s
## and the default bank; an airliner-like 0.44 rad is 7,023 m, and refuses both levels, the island by 1,087 m and alpine by
## 6,098 m (measured with that case built in, cockpit-fleet, 2026-09-15).
## Both rows use the simulation's own radii and wire; only the reach differs, the island's read before the level stood.
func _every_level_fits_the_widest_turn() -> void:
	# ASKED OF A WORLD WITH NO SESSION: the radii come from the handling and model tables its constructor builds, and the last
	# resort is the wire's, so a level refused while it loads -- which ends the session -- is still judged in words.
	var world: Object = ClassDB.instantiate("CockpitWorld")
	var radii: Array = world.turn_radii()
	var fastest: float = 0.0
	var widest: String = ""
	var worst: float = float(world.worst_turn_radius())
	for row in radii:
		fastest = maxf(fastest, float((row as Dictionary)["speed"]))
		if is_equal_approx(float((row as Dictionary)["radius"]), worst):
			widest = Sim.kind_name(int((row as Dictionary)["kind"]))
	var guard_from: float = float((world.boundary() as Dictionary)["guard_from"])
	var alpine_reach: float = Terrain.placed_reach()
	var refused: Array[String] = []
	var said: Array[String] = []
	for level in [["island", _island_reach], ["alpine", alpine_reach]]:
		var band: Dictionary = WorldEdge.band_for(float(level[1]), worst, guard_from, fastest)
		var margin: float = guard_from - (float(band["start"]) + 2.0 * worst)
		print("[terrain_level] the %s: placed within %.0f m, the band from %.0f m and %.0f m deep, fits by %.0f m" % [
			level[0], level[1], band["start"], band["depth"], margin])
		said.append("%s fits by %.0f m" % [level[0], margin])
		if String(band["error"]) != "":
			refused.append("%s: %s" % [level[0], band["error"]])
	_check("every_level_fits_the_widest_turn", refused.is_empty() and not is_equal_approx(_island_reach, alpine_reach),
		"the widest is the %s's %.0f m; %s; the island's reach %.0f m is not alpine's %.0f m%s" % [widest, worst,
			", ".join(said), _island_reach, alpine_reach, "" if refused.is_empty() else "; REFUSED %s" % [refused]])
	_sections += 1


## A vehicle's heading from its simulation state, radians, as a spawn's yaw is: 0 has the nose to -Z.
func _heading_of(state: Dictionary) -> float:
	var nose: Vector3 = (state["basis"] as Quaternion) * Vector3.FORWARD
	return atan2(-nose.x, -nose.z)


## The spawn in `Terrain.spawns()` with this name, or {}: the carrier a craft is parked on.
func _named_spawn(name: StringName) -> Dictionary:
	for spawn in Terrain.spawns():
		if spawn.get("name", &"") == name:
			return spawn
	return {}


## Whether a spawn at `at` stands on the place it names: a runway's, within ON_A_RUNWAY_WITHIN of the first runway's middle;
## a town's, inside some seated town's flat.
func _on_the_place(place: StringName, at: Vector3) -> bool:
	if place == &"ground":
		return true
	if place == &"runway":
		var middle: Vector3 = Terrain.runways()[0]["centre"]
		return Vector2(at.x - middle.x, at.z - middle.z).length() <= ON_A_RUNWAY_WITHIN
	for town in TownCatalogue.towns():
		var site: Dictionary = town.get("site", {})
		var centre: Vector3 = town["centre"]
		if not site.is_empty() and Vector2(at.x - centre.x, at.z - centre.z).length() <= float(site["r"]):
			return true
	return false


## Whether a point is open sea -- the sea's water, not a lake's -- with the ground at least `depth` below the sea's level.
func _open_sea_at(field: Object, at: Vector3, depth: float) -> bool:
	var ground: float = float(int(field.call("height_ticks_at", roundi(at.x), roundi(at.z)))) / TICKS
	return int(field.call("water_ticks_at", roundi(at.x), roundi(at.z))) == 0 and ground <= -depth


## The highest surface, the ground or its water, within `room` of a point, at texel centres every 16 m or so, asked of the
## field here.
func _highest_surface(field: Object, at: Vector3, room: float, no_water: int) -> float:
	var n: int = maxi(1, ceili(2.0 * room / 16.0))
	var step: float = 2.0 * room / float(n)
	var points := PackedInt32Array()
	for j in range(n):
		for i in range(n):
			points.append_array([roundi(at.x - room + (float(i) + 0.5) * step), roundi(at.z - room + (float(j) + 0.5) * step)])
	var heights: PackedInt32Array = field.call("heights_at", points)
	var waters: PackedInt32Array = field.call("waters_at", points)
	var high: float = -INF
	for k in range(heights.size()):
		var surface: float = float(heights[k]) / TICKS
		if waters[k] > no_water:
			surface = maxf(surface, float(waters[k]) / TICKS)
		high = maxf(high, surface)
	return high


## A LEVEL REFUSED ON LOADING: a widest turn past its allowance ends the session from the level (`_mark_the_edge`), and the
## desk's deferred scene change took this suite with it, which then hung to its deadline with nothing printed
## (cockpit-fleet's mutant, a 0.44 rad Hawkeye bank case). So the refusal fails the level check with its reason and runs
## the widest turn's own check, whose red says which level and by how much, before the desk arrives.
func _on_a_session_ended(reason: String) -> void:
	if _finished:
		return
	_check("the_level_stands_on_the_generated_ground_and_comes_up", false, "the session ended while it loaded: %s" % reason)
	if Terrain.standing_on() != null:
		_every_level_fits_the_widest_turn()
	_finish()


func _finish() -> void:
	_finished = true
	TownView.street_lights_in_tests = false
	Sim.stop()
	Net.leave("suite over")
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
