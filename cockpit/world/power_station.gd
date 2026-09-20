extends Node3D
class_name PowerStation
## WHERE THE COOLING TOWERS STAND, AND THE PICTURE OF THEM: a couple of towers beside a town, drawn as
## scenery and steaming.
##
## THE DECISION: A STATION IS AN OFFSET FROM A TOWN, NOT A POINT ON A MAP. A power station is beside the
## place it powers, so this catalogue names a TOWN and says how far out of it the station sits, and
## `sites()` asks `TownCatalogue.towns()` where that town actually is. That is the difference between a
## station that works on both worlds and one that works on the island only: the island's towns are typed
## and the alpine world's are SEATED on whatever flats the generated ground offered, kilometres from the
## constant (`world/town_catalogue.gd` says so in capitals). A typed pair of coordinates here would put
## two ninety-metre towers in the sea the first time the seed changed, and every check would still pass.
## Rule 4 in CLAUDE.md: ask the authority, do not keep a roster.
##
## THE GROUND IS ASKED TOO, per tower, not per station. `Terrain.ground_height` is the authority for what
## a tower stands on, and two towers 112 m apart on generated ground are not at the same level.
##
## A TOWER IS SOLID, AND ONE LIST OF PLACES FEEDS BOTH HALVES. `Forests` gets to say "a forest here is a
## picture and never a thing" because an aeroplane flying through a wood is a choice somebody can defend;
## a 99 m concrete shell is not a wood. `boxes()` hands `Terrain.boxes()` 33 static boxes a tower and both
## it and `draw_stations` read the same `sites()`, so the picture and the physics cannot disagree about
## where a tower is. `sky.gd` says why that matters: scenery drawn where the simulation has none "looks
## exactly like a networking fault". The shape of the solid, what it costs and which way it is allowed to
## be wrong are all in `world/cooling_tower.gd` above `SOLID_BANDS`.
##
## WHAT IS DRAWN, AND BY WHOM. The towers go on a plain `SceneryYard` layer -- `add_layer`, not
## `add_worked_layer`: a worked layer exists so a kilometre of a thousand buildings can have its MultiMesh
## buffer made off the main thread, and this is two meshes. They are built when the eye comes within the
## scenery's reach and let go beyond it like everything else. The steam is a child of each tower, so it
## arrives and leaves with it and nothing has to keep a list of plumes.

## THE STATIONS. `town` is a name in `TownCatalogue`; `offset` is metres east and metres SOUTH of that
## town's centre, in the world's own axes; `bearing` is the line the row of towers stands along, in
## degrees clockwise from north, the same sense a vehicle's yaw is quoted in.
##
## ONE STATION, TWO TOWERS, which is what the user asked for and also what the tower's own source
## describes -- Film Cooling Towers' Baglan Bay job was "two natural draught hyperbolic cooling towers".
## It stands south-east of the eastern city, out on open ground: off `Forests.STANDS` (east_wood is
## centred (1900, 700) and west_wood (-2650, 650), both far from here), outside the town's own 440 m
## radius and its ragged edge, and well clear of the runway and its approaches over on the west side.
const STATIONS: Array[Dictionary] = [
	{"name": &"eastern_power", "town": &"eastern", "offset": Vector2(420.0, 820.0), "bearing": 55.0},
]

## HOW MANY TOWERS A STATION HAS, and how far apart they stand as a multiple of a tower's own ring beam
## DIAMETER. Real stations put them between about 1.3 and 1.8 diameters centre to centre; Ferrybridge C's
## were "constructed closer together than was usual", which is one of the things named in the inquiry into
## the three that fell in 1965, so the middle of that range is the safe place to sit. Derived from the
## tower rather than typed in metres, so a change to the model moves the pair with it: 1.5 x 74.37 m is
## 111.6 m between centres, which leaves 37 m of daylight between two shells.
const TOWERS_EACH: int = 2
const APART_IN_DIAMETERS: float = 1.5

## The layer the towers are drawn on, named so the suite and the yard's own reporting can find it.
const TOWERS: String = "cooling_towers"

var _sites: Array[Dictionary] = []
## The sites this node actually put on a layer, which is what `drawn_solid` answers for. Not the same as
## `_sites`: a site off the filed ground is warned about and skipped, and the picture owes nothing for it.
var _laid: Array[Dictionary] = []
var _drawn: Array[Node3D] = []
var _drift: Vector3 = Vector3.ZERO


## WHERE EVERY TOWER IN THE WORLD STANDS, as `{"station", "index", "position"}` with the position seated on
## the ground. STATIC AND PURE apart from the two authorities it asks, so a suite can compare it against
## the towns without building anything.
static func sites() -> Array[Dictionary]:
	var towns: Array[Dictionary] = TownCatalogue.towns()
	var out: Array[Dictionary] = []
	for station in STATIONS:
		var centre: Vector3 = Vector3.INF
		for town in towns:
			if StringName(town["name"]) == StringName(station["town"]):
				centre = town["centre"]
				break
		# A STATION WHOSE TOWN IS NOT ON THIS WORLD DISABLES ITSELF AND SAYS SO, rather than standing at the
		# origin. On a ground with fewer town sites than towns, `TownCatalogue.seat` drops the smallest
		# towns, so this is a thing that happens rather than a thing that cannot.
		if centre == Vector3.INF:
			push_warning("PowerStation: no town called '%s' on this world, so '%s' is not built."
				% [station["town"], station["name"]])
			continue
		var offset: Vector2 = station["offset"]
		var middle := Vector3(centre.x + offset.x, 0.0, centre.z + offset.y)
		var along: Vector3 = Terrain.nose_from_yaw(deg_to_rad(float(station["bearing"])))
		var apart: float = CoolingTower.ring_beam_radius() * 2.0 * APART_IN_DIAMETERS
		for i in range(TOWERS_EACH):
			var step: float = (float(i) - float(TOWERS_EACH - 1) * 0.5) * apart
			var at: Vector3 = middle + along * step
			at.y = Terrain.ground_height(at)
			out.append({"station": station["name"], "index": i, "position": at})
	return out


## EVERY TOWER'S SOLID, for `Terrain.boxes()`, in the same `{position, half_extents}` shape everything else
## in that list uses. Static and pure apart from the two authorities `sites()` asks, and it reads `sites()`
## rather than this node's `_sites`, because the simulation is built on a peer that may never draw a tower.
##
## THE PICTURE AND THE PHYSICS COME FROM ONE LIST OF PLACES. `sky.gd` warns that scenery drawn where the
## simulation has none "looks exactly like a networking fault"; both halves here call `sites()`, so there is
## no second roster of where a tower is and nothing to keep in step.
static func boxes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for site in sites():
		for box in CoolingTower.collision_boxes(site["position"]):
			# THE GROUP IS PUT ON HERE, NOT IN `CoolingTower`, because a group is a fact about the scenery
			# list rather than about a cooling tower, and the model has no other reason to know `Terrain`
			# exists. `Group.TOWER` is drawn by nothing -- this node draws the shell itself.
			#
			# AND A BOX WITHOUT ONE IS NOT MERELY UNCOUNTED. `SceneryYard.draw_boxes` reads
			# `int(box["group"])`, and a missing key is null, which `int` makes 0, which is `Group.ROCK`:
			# sixty-six invisible boulders inside two cooling towers. The first version of this function
			# left the key off, and what found it was the fighter -- `Terrain.boxes()` reported 0 tower
			# boxes and the aeroplane flew 514 m out the far side (2026-09-17).
			box["group"] = Terrain.Group.TOWER
			out.append(box)
	return out


## THE PICTURE, HANDED THE SAME YARD THE TOWNS AND THE ROCK ARE DRAWN BY. Mirrors `TownView.draw_towns`:
## this node keeps what it needs, the yard decides when a cell is built and let go.
func draw_stations(map: WorldMap, reach: float, yard: SceneryYard) -> void:
	_sites = sites()
	var by_cell: Dictionary = {}
	var bounds: Dictionary = {}
	for site in _sites:
		var at: Vector3 = site["position"]
		var cell: Vector2i = WorldMap.cell_of(at)
		if not map.has_cell(cell):
			# The yard only plans cells the map has. A tower off the filed ground is a tower nobody would
			# ever see built, and saying so is cheaper than finding an empty layer later.
			push_warning("PowerStation: '%s' tower %d is outside the filed ground at %s."
				% [site["station"], site["index"], at])
			continue
		var mine: Array = by_cell.get(cell, [])
		mine.append(site)
		by_cell[cell] = mine
		_laid.append(site)
		var spread: float = CoolingTower.ring_beam_radius() + CoolingTower.POND_MARGIN
		var box := AABB(at - Vector3(spread, 0.0, spread),
			Vector3(spread * 2.0, CoolingTower.overall_height(), spread * 2.0))
		bounds[cell] = box if not bounds.has(cell) else (bounds[cell] as AABB).merge(box)
	if by_cell.is_empty():
		return
	var shell: ArrayMesh = CoolingTower.build()
	var concrete: StandardMaterial3D = CoolingTower.concrete_material()
	yard.add_layer(TOWERS, bounds, reach, self,
		func(cell: Vector2i) -> Array[Node3D]:
			var out: Array[Node3D] = []
			for site in (by_cell[cell] as Array):
				out.append(_one_tower(site, shell, concrete))
			return out)


## WHAT THIS NODE HAS UNDERTAKEN TO DRAW, in solid boxes, for `tests/smoke.gd`'s count of the picture
## against the physics. Every self-drawing group answers one of these -- `AuthoredChunks.boxes`,
## `TownView.drawn_buildings`, `AirbaseView.drawn_solid` -- because the boxes they own never reach the
## yard's own batches and would otherwise read as solid that nothing draws.
##
## AND THAT CHECK IS THE ONE THAT CAUGHT THIS. The first version of the static boxes went into
## `Terrain.boxes()` with nothing answering for them, and `smoke.gd:the_picture_is_the_same_list_as_the
## _physics` went red on the count -- which is the check `sky.gd` says exists because "scenery drawn where
## the simulation does not have any looks exactly like a networking fault". It is the same rule from the
## other side: solid the picture does not answer for.
##
## IT ANSWERS FOR WHAT IT LAID ON A LAYER, not for what is instantiated this frame. The yard builds a cell
## when the eye comes within reach and lets it go beyond it, so a count of live nodes would depend on where
## somebody was standing; `AuthoredChunks.boxes(places)` answers from the catalogue for the same reason.
func drawn_solid() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for site in _laid:
		out.append_array(CoolingTower.collision_boxes(site["position"]))
	return out


## HOW THE STEAM LEANS, from the same wind the fires' smoke leans on. Kept, so a plume built after the
## wind was handed over still gets it.
func set_drift(wind: Vector3) -> void:
	_drift = wind
	for tower in _drawn:
		if is_instance_valid(tower):
			for plume in tower.find_children("*", "TowerPlume", true, false):
				(plume as TowerPlume).set_drift(wind)


## ONE TOWER AND ITS PLUME, READY TO STAND ANYWHERE, AND IT NEEDS NO LEVEL. No `Sim`, no spawn, no
## `Terrain`, no town: a mesh, a material and a plume, built from statics. That is deliberate and it is for
## `lane/buildings`' gallery -- `merchant_shot.gd` is the pattern, and being buildable in isolation is what
## let the destroyer be photographed before its C++ landed. A gallery wants:
##
##     var tower: Node3D = PowerStation.one()
##
## and nothing else. `PowerStation.sites()` is the part that needs a world, and a gallery does not call it.
##
## THE PLUME IS WHOLE ON THE FIRST FRAME and needs no settling frames -- see `TowerPlume`, which is a pure
## function of its clock rather than an emitter. A gallery may photograph this on the frame it made it.
static func one(with_steam: bool = true) -> Node3D:
	var tower := Node3D.new()
	tower.name = "CoolingTower"
	var drawn := MeshInstance3D.new()
	drawn.name = "Shell"
	drawn.mesh = CoolingTower.build()
	drawn.material_override = CoolingTower.concrete_material()
	# NO SHADOW OFF A 99 M SHELL. A cooling tower is the tallest thing for a kilometre and its shadow would
	# be cast the whole depth of the directional light's cascade for a piece of scenery nobody lands beside.
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tower.add_child(drawn)
	if with_steam:
		var plume := TowerPlume.new()
		plume.name = "Plume"
		tower.add_child(plume)
		plume.stand_on(CoolingTower.overall_height(), CoolingTower.top_radius())
	return tower


## ONE TOWER, stood on the ground at its site, named for the station it belongs to. The BUILDING is `one()`;
## this adds only the things a place gives it, so the gallery and the world cannot drift apart.
func _one_tower(site: Dictionary, shell: ArrayMesh, concrete: StandardMaterial3D) -> Node3D:
	var tower: Node3D = one()
	tower.name = "CoolingTower_%s_%d" % [site["station"], int(site["index"])]
	tower.position = site["position"]
	# THE MESH AND THE MATERIAL ARE THE STATION'S, not each tower's: `one()` builds its own so a gallery
	# needs nothing, and a station of eight would otherwise build eight identical 840-triangle meshes.
	var drawn := tower.get_node("Shell") as MeshInstance3D
	drawn.mesh = shell
	drawn.material_override = concrete
	(tower.get_node("Plume") as TowerPlume).set_drift(_drift)
	_drawn.append(tower)
	return tower
