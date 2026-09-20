extends Node
## THE OIL PLATFORM'S SHAPE, ITS PLACE AND ITS SOLID, ASKED OF WHAT IS DRAWN AND OF WHAT A BODY HITS.
##
##   Godot --headless --path cockpit --xr-mode off res://tests/oil_platform.tscn
##
## WHAT IT IS FOR. `OilPlatform` is a lattice built from its constants, and every one of those constants can be right while
## the drawing is wrong: a jacket built for a depth nobody asked, a crane boom slewed across the helideck's clear approach,
## a helideck whose solid sits under its paint so a helicopter settles into the deck. So the checks take the MESH -- each
## named part's own vertices, from where `build` says they are -- and a bare simulation with the platform's boxes in it,
## and ask those.
##
## THE REFERENCES ARE TYPED HERE, not read from the builder: Thistle Alpha's base [W], the Montrose broadside's heights
## [M] at the doc block's scale (`world/oil_platform.gd`), the island's sea floor as `tests/seabed.gd` sounded it, and a
## UH-60's length [W]. A check that read `OilPlatform.CELLAR_DECK` to judge the cellar deck would be the file agreeing
## with itself.

## [W] Thistle Alpha: "a base measuring 85 meters by 82 meters", in 162 m of water.
const THISTLE_BASE := Vector2(85.0, 82.0)
const THISTLE_DEPTH: float = 162.0
## How far the drawn base may be from Thistle's, as a share. A typical batter spread is a design choice, not a copy.
const BASE_SHARE: float = 0.06
## [M] off the Montrose broadside at 6.9 px a metre: the cellar deck's underside 22 m over the sea and the helideck at
## 61.6 m; `research/oil_platform.md` has the picks. The scale is good to about a metre at the platform's station.
const MONTROSE_CELLAR_UNDERSIDE: float = 22.0
const MONTROSE_HELIDECK: float = 61.6
const MONTROSE_TOLERANCE: float = 2.5
## The island's open sea, as `tests/seabed.gd` sounds it: 150.00 m.
const ISLAND_SEA_DEPTH: float = 150.0
## [W] UH-60 Black Hawk, length 19.76 m (64 ft 10 in) overall with its rotors turning; an offshore helideck is at least one
## D-value across -- the largest helicopter's overall length -- and this is the biggest helicopter in the game that flies
## crews to a platform.
const UH60_OVERALL: float = 19.76
## The brief's ranges for a derrick above its drill floor, metres.
const DERRICK_LEAST: float = 40.0
const DERRICK_MOST: float = 60.0
## THE TRIPWIRE, not a frame budget: 14,800 triangles measured on 2026-09-18 with 2 surfaces; this is what catches a
## quiet subdivision. The Ford carrier's near model is 7,546 triangles, and a platform is a lattice.
const MOST_TRIANGLES: int = 16500
## `aircraft_model_fidelity_plan.md`'s first-LOD draw budget.
const FIRST_LOD_DRAWS: int = 20
## How far a vertex may stand above the helideck and still not be an obstacle, metres: its own markings and lights.
const OVER_THE_DECK: float = 0.3
## How far out the clear sector is asked about, metres: further than anything the platform draws.
const SECTOR_REACH: float = 500.0

const FLY_HZ: float = 120.0
## HOW FAR FROM THE STILL WATER THE DARK SPLASH BAND MAY BE DRAWN: 3 m of splash zone either way, plus a leg's radius,
## because a member is cut square to its own axis where it crosses +-3 m and its cut ring leans past the plane by up to
## its radius (measured 3.48 m on the first run, a brace's 0.55 m radius on a steep diagonal).
const SPLASH_REACH: float = 4.2
## Where the bare world's piece of slab stands, and its half-size.
const SLAB_AT := Vector3(-1500.0, 0.0, 0.0)
const SLAB_HALF := Vector3(60.0, 20.0, 60.0)

var failures: PackedStringArray = []


func check(label: String, ok: bool, detail: String = "") -> void:
	print("[oil_platform] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures.append(label)


func _ready() -> void:
	var built: Dictionary = OilPlatform.build(ISLAND_SEA_DEPTH)
	var mesh: ArrayMesh = built["mesh"]
	var parts: Dictionary = built["parts"]
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	_every_part_is_drawn_and_named(parts)
	_the_platform_is_one_structure(parts, verts)
	_every_face_is_wound_outwards(verts, normals)
	_the_island_platform_stands_on_the_island_sea_floor()
	_the_jacket_stands_on_the_seabed_and_rises_through_the_water(parts, verts)
	_at_thistles_depth_the_base_is_thistles()
	_the_decks_and_helideck_stand_where_montrose_has_them(parts, verts)
	_the_derrick_stands_on_its_drill_floor(parts, verts)
	_the_helideck_is_flat_level_and_big_enough(parts, verts, normals)
	_nothing_stands_in_the_helidecks_clear_sector(parts, verts)
	_the_solid_is_inside_the_drawing_and_the_deck_is_its_top(verts)
	_the_world_lists_the_platform_clear_of_shipping()
	_on_the_generated_ground_it_stands_on_that_sea_floor()
	_a_world_with_no_sea_builds_no_platform_and_says_nothing()
	_a_shallow_jacket_is_drawn_sensibly()
	_a_helicopter_set_down_on_the_helideck_rests_on_it()
	_a_fighter_flown_at_the_platform_is_stopped()
	_it_costs_little(mesh)
	_the_sea_reflects_the_flare_and_nothing_lies_on_it()
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


## ---- one object, every part named -----------------------------------------------------------------------------------

func _every_part_is_drawn_and_named(parts: Dictionary) -> void:
	var empty: PackedStringArray = []
	for name in OilPlatform.PARTS:
		if not parts.has(name) or (parts[name] as Vector2i).y == 0:
			empty.append(name)
	var unique: Dictionary = {}
	for name in OilPlatform.PARTS:
		unique[name] = true
	check("every_part_is_drawn_and_named", empty.is_empty() and unique.size() == OilPlatform.PARTS.size()
		and parts.size() == OilPlatform.PARTS.size(),
		"%d parts, %d unique, empty: %s" % [parts.size(), unique.size(), empty])


## ONE STRUCTURE: union-find over the parts' drawn boxes, joined where they meet within a centimetre on all three axes
## (`modelling_here.md` section 6, `_nothing_floats`). A part that comes off makes a group of its own and names itself.
## BOX-BASED, SO IT CANNOT SEE A PART MOVED WITHIN ITS NEIGHBOURS' BOXES (lane/falcon's finding): it catches the part
## that has left, not the one that has slid.
func _the_platform_is_one_structure(parts: Dictionary, verts: PackedVector3Array) -> void:
	var names: Array = parts.keys()
	var boxes: Array[AABB] = []
	for name in names:
		boxes.append(_part_box(parts[name], verts))
	var group: Array[int] = []
	for i in range(names.size()):
		group.append(i)
	var root := func(i: int) -> int:
		while group[i] != i:
			i = group[i]
		return i
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			if boxes[i].grow(0.01).intersects(boxes[j]):
				group[root.call(i)] = root.call(j)
	var groups: Dictionary = {}
	for i in range(names.size()):
		var r: int = root.call(i)
		var members: Array = groups.get(r, [])
		members.append(names[i])
		groups[r] = members
	var smallest: Array = []
	for r in groups:
		if smallest.is_empty() or (groups[r] as Array).size() < smallest.size():
			smallest = groups[r]
	check("the_platform_is_one_structure", groups.size() == 1,
		"%d groups; the smallest is %s" % [groups.size(), smallest])


## EVERY FACE AGREES WITH ITS OWN NORMAL. As `ship_models.gd:_wound_outwards`; lane/falcon notes it cannot see a face
## wound backwards WITH its normal flipped, which is why the helideck's up-normals are asked separately below.
func _every_face_is_wound_outwards(verts: PackedVector3Array, normals: PackedVector3Array) -> void:
	var against: int = 0
	for t in range(0, verts.size(), 3):
		var face: Vector3 = (verts[t + 2] - verts[t]).cross(verts[t + 1] - verts[t])
		if face.length_squared() > 1e-12 and face.dot(normals[t]) < 0.0:
			against += 1
	check("every_face_is_wound_outwards", against == 0, "%d of %d faces against their normal" % [against, verts.size() / 3])


## ---- standing in the sea ---------------------------------------------------------------------------------------------

## THE ISLAND'S PLATFORM IS BUILT FOR THE ISLAND'S SEA, which is the depth `Seabed` lays its floor at, sounded by
## `tests/seabed.gd` at 150.00 m -- not a depth typed beside it.
func _the_island_platform_stands_on_the_island_sea_floor() -> void:
	var sites: Array[Dictionary] = OilField.sites()
	var ok: bool = sites.size() == OilField.PLATFORMS.size()
	var said: PackedStringArray = []
	for site in sites:
		ok = ok and absf(float(site["depth"]) - ISLAND_SEA_DEPTH) < 0.5 and absf((site["position"] as Vector3).y) < 0.01
		said.append("%s in %.2f m at %v" % [site["name"], float(site["depth"]), site["position"]])
	check("the_island_platform_stands_on_the_island_sea_floor", ok, ", ".join(said))


## THE JACKET'S FEET ARE ON THE SEABED AND IT RISES THROUGH THE WATER: its lowest drawn vertex within a leg's radius of the
## floor, its top frame above the sea, and the splash zone -- the dark band -- drawn at the water line and only there.
func _the_jacket_stands_on_the_seabed_and_rises_through_the_water(parts: Dictionary, verts: PackedVector3Array) -> void:
	var jacket: AABB = _part_box(parts["Jacket"], verts)
	var built: Dictionary = OilPlatform.build(ISLAND_SEA_DEPTH)
	var colours: PackedColorArray = (built["mesh"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var range_: Vector2i = parts["Jacket"]
	var band_low: float = INF
	var band_high: float = -INF
	var wet_crossings: int = 0
	for i in range(range_.x, range_.x + range_.y):
		if _same_paint(colours[i], OilPlatform.SPLASH_RUST):
			band_low = minf(band_low, verts[i].y)
			band_high = maxf(band_high, verts[i].y)
	# How many drawn members cross the still water: a leg or brace with a piece either side of y = 0.
	for i in range(range_.x, range_.x + range_.y, 3):
		var ys: Array[float] = [verts[i].y, verts[i + 1].y, verts[i + 2].y]
		if ys.min() < 0.0 and ys.max() > 0.0:
			wet_crossings += 1
	# CONTINUOUS FROM THE FLOOR TO THE TOP FRAME: steel drawn across every 5 m of height. The lowest vertex alone is not
	# enough -- a jacket built for 100 m with its pile sleeves still on the 150 m floor has its lowest vertex there and
	# 40 m of open water above them, and that mutant passed the first version of this check.
	var empty_bands: PackedStringArray = []
	var filled: Dictionary = {}
	# BY TRIANGLE, NOT BY VERTEX: a 40 m leg has vertices only at its two ends, so a vertex bucket reads it as empty
	# water (the second version of this check did, and lane/falcon met the same thing slicing a wing).
	for t in range(range_.x, range_.x + range_.y, 3):
		var lo: float = minf(verts[t].y, minf(verts[t + 1].y, verts[t + 2].y)) + ISLAND_SEA_DEPTH
		var hi: float = maxf(verts[t].y, maxf(verts[t + 1].y, verts[t + 2].y)) + ISLAND_SEA_DEPTH
		for band in range(floori(lo / 5.0), floori(hi / 5.0) + 1):
			filled[band] = true
	for band in range(int(ceilf((ISLAND_SEA_DEPTH + 10.0) / 5.0))):
		if not filled.has(band):
			empty_bands.append("%.0f" % (float(band) * 5.0 - ISLAND_SEA_DEPTH))
	var feet: float = jacket.position.y + ISLAND_SEA_DEPTH
	check("the_jacket_stands_on_the_seabed_and_rises_through_the_water",
		absf(feet) < 1.0 and jacket.end.y > 5.0 and empty_bands.is_empty() and band_low >= -SPLASH_REACH
			and band_high <= SPLASH_REACH and band_high > 2.9 and wet_crossings > 40,
		("lowest steel %.2f m from the floor at -%.0f, top %.1f m over the sea, no steel in the 5 m bands from %s; the "
			+ "splash band runs %.2f to %.2f; %d faces cross the water line")
			% [feet, ISLAND_SEA_DEPTH, jacket.end.y, empty_bands if not empty_bands.is_empty() else "none", band_low,
				band_high, wet_crossings])


## AT THISTLE'S DEPTH THE BASE IS THISTLE'S. The batter is the one thing that decides how a jacket spreads with depth, and
## it is held to a real jacket in the depth that jacket stands in, measured off the legs' drawn vertices at the floor.
func _at_thistles_depth_the_base_is_thistles() -> void:
	var built: Dictionary = OilPlatform.build(THISTLE_DEPTH)
	var verts: PackedVector3Array = (built["mesh"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var r: Vector2i = built["parts"]["Jacket"]
	var low_x := Vector2(INF, -INF)
	var low_z := Vector2(INF, -INF)
	for i in range(r.x, r.x + r.y):
		# THE LEG CENTRES AT THE FLOOR: vertices within a leg's radius of it, pile sleeves excluded by the leg's radius.
		if verts[i].y < -THISTLE_DEPTH + OilPlatform.LEG_DIAMETER:
			low_x = Vector2(minf(low_x.x, verts[i].x), maxf(low_x.y, verts[i].x))
			low_z = Vector2(minf(low_z.x, verts[i].z), maxf(low_z.y, verts[i].z))
	# The outermost steel at the floor is a pile sleeve, 2.6 m out plus its radius; the base is quoted across the legs.
	var sleeve: float = 2.6 + 0.9
	var long: float = low_x.y - low_x.x - 2.0 * sleeve
	var across: float = low_z.y - low_z.x - 2.0 * sleeve
	check("at_thistles_depth_the_base_is_thistles",
		absf(long / THISTLE_BASE.x - 1.0) < BASE_SHARE and absf(across / THISTLE_BASE.y - 1.0) < BASE_SHARE,
		"%.1f x %.1f m across the legs at %.0f m, against Thistle's %.0f x %.0f" % [long, across, THISTLE_DEPTH,
			THISTLE_BASE.x, THISTLE_BASE.y])


func _the_decks_and_helideck_stand_where_montrose_has_them(parts: Dictionary, verts: PackedVector3Array) -> void:
	var cellar: AABB = _part_box(parts["CellarDeck"], verts)
	var deck: AABB = _part_box(parts["Helideck"], verts)
	var weather: AABB = _part_box(parts["WeatherDeck"], verts)
	var production: AABB = _part_box(parts["ProductionDeck"], verts)
	var ordered: bool = cellar.end.y < production.end.y and production.end.y < weather.end.y and weather.end.y < deck.end.y
	check("the_decks_and_helideck_stand_where_montrose_has_them",
		absf(cellar.position.y - MONTROSE_CELLAR_UNDERSIDE) < MONTROSE_TOLERANCE
			and absf(deck.end.y - MONTROSE_HELIDECK) < MONTROSE_TOLERANCE and ordered
			and cellar.size.x >= 40.0 and cellar.size.x <= 80.0,
		"cellar deck's underside %.1f m (Montrose %.1f), helideck %.1f m (%.1f), decks %.1f < %.1f < %.1f, cellar deck %.0f x %.0f m"
			% [cellar.position.y, MONTROSE_CELLAR_UNDERSIDE, deck.end.y, MONTROSE_HELIDECK, cellar.end.y, production.end.y,
				weather.end.y, cellar.size.x, cellar.size.z])


func _the_derrick_stands_on_its_drill_floor(parts: Dictionary, verts: PackedVector3Array) -> void:
	var derrick: AABB = _part_box(parts["Derrick"], verts)
	var floor: AABB = _part_box(parts["DrillFloor"], verts)
	var tall: float = derrick.end.y - floor.end.y
	check("the_derrick_stands_on_its_drill_floor",
		absf(derrick.position.y - floor.end.y) < 0.5 and tall >= DERRICK_LEAST and tall <= DERRICK_MOST,
		"its feet %.2f m from the drill floor's top, %.1f m tall over it" % [derrick.position.y - floor.end.y, tall])


## ---- the helideck ---------------------------------------------------------------------------------------------------

## FLAT, LEVEL, AND AT LEAST ONE D-VALUE ACROSS: every upward face of the deck plate at one height, and the plate at least
## a UH-60's overall length across its flats, measured off those faces.
func _the_helideck_is_flat_level_and_big_enough(parts: Dictionary, verts: PackedVector3Array,
		normals: PackedVector3Array) -> void:
	var colours: PackedColorArray = (OilPlatform.build(ISLAND_SEA_DEPTH)["mesh"] as ArrayMesh).surface_get_arrays(0)[
		Mesh.ARRAY_COLOR]
	var r: Vector2i = parts["Helideck"]
	var high := Vector2(INF, -INF)
	var across_x := Vector2(INF, -INF)
	var across_z := Vector2(INF, -INF)
	var up_faces: int = 0
	var tilted: int = 0
	for i in range(r.x, r.x + r.y):
		if not _same_paint(colours[i], OilPlatform.HELIDECK_GREEN):
			continue
		if normals[i].y > 0.999:
			up_faces += 1
			high = Vector2(minf(high.x, verts[i].y), maxf(high.y, verts[i].y))
			across_x = Vector2(minf(across_x.x, verts[i].x), maxf(across_x.y, verts[i].x))
			across_z = Vector2(minf(across_z.x, verts[i].z), maxf(across_z.y, verts[i].z))
		elif normals[i].y > 0.05:
			tilted += 1
	var flats: float = minf(across_x.y - across_x.x, across_z.y - across_z.x)
	check("the_helideck_is_flat_level_and_big_enough",
		up_faces > 0 and high.y - high.x < 0.001 and tilted == 0 and flats >= UH60_OVERALL,
		"%d upward plate vertices spanning %.4f m in height, %d tilted, %.1f m across its flats for a %.2f m helicopter"
			% [up_faces, high.y - high.x, tilted, flats, UH60_OVERALL])


## THE OBSTACLE-FREE SECTOR: nothing the platform draws stands higher than the deck within 105 degrees either side of the
## approach, out to SECTOR_REACH. Asked of every drawn vertex that is not the deck or its net.
func _nothing_stands_in_the_helidecks_clear_sector(parts: Dictionary, verts: PackedVector3Array) -> void:
	var centre: Vector3 = OilPlatform.helideck_centre()
	var own: Array[Vector2i] = [parts["Helideck"], parts["HelideckNet"]]
	var worst: String = ""
	var intruders: int = 0
	for i in range(verts.size()):
		var mine: bool = false
		for r in own:
			mine = mine or (i >= r.x and i < r.x + r.y)
		if mine or verts[i].y <= centre.y + OVER_THE_DECK:
			continue
		var flat := Vector2(verts[i].x - centre.x, verts[i].z - centre.z)
		if flat.length() > SECTOR_REACH:
			continue
		if absf(rad_to_deg(flat.angle())) <= OilPlatform.CLEAR_SECTOR_HALF:
			intruders += 1
			if worst == "":
				worst = "%v in %s" % [verts[i], _part_of(parts, i)]
	check("nothing_stands_in_the_helidecks_clear_sector", intruders == 0,
		"%d vertices above the deck inside the %.0f-degree sector%s" % [intruders, OilPlatform.CLEAR_SECTOR_HALF * 2.0,
			"" if worst == "" else ", first " + worst])


## ---- the solid ------------------------------------------------------------------------------------------------------

## EVERY BOX INSIDE WHAT IS DRAWN, and the helideck's boxes topped at the drawn deck to the millimetre -- the thing a
## helicopter actually lands on.
func _the_solid_is_inside_the_drawing_and_the_deck_is_its_top(verts: PackedVector3Array) -> void:
	var drawn := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		drawn = drawn.expand(v)
	var solid: Array[Dictionary] = OilPlatform.collision_boxes(Vector3.ZERO, ISLAND_SEA_DEPTH)
	var outside: int = 0
	var deck_tops: Array[float] = []
	var centre: Vector3 = OilPlatform.helideck_centre()
	for box in solid:
		var at: Vector3 = box["position"]
		var half: Vector3 = box["half_extents"]
		if not drawn.grow(0.001).encloses(AABB(at - half, half * 2.0)):
			outside += 1
		if absf(at.x - centre.x) < 0.01 and absf(at.z - centre.z) < 0.01:
			deck_tops.append(at.y + half.y)
	var drawn_deck: float = _drawn_deck_top(verts)
	var level: bool = deck_tops.size() >= 3
	for top in deck_tops:
		level = level and absf(top - drawn_deck) < 0.001
	check("the_solid_is_inside_the_drawing_and_the_deck_is_its_top", outside == 0 and level,
		"%d of %d boxes outside the drawn bounds; the helideck's %d boxes top out at %s against the drawn deck's %.3f m"
			% [outside, solid.size(), deck_tops.size(), deck_tops, drawn_deck])


## THE WORLD'S OWN SOLID LIST CARRIES THE PLATFORM, and every platform stands clear of every ship's spawn.
func _the_world_lists_the_platform_clear_of_shipping() -> void:
	var listed: int = 0
	for box in Terrain.boxes():
		listed += 1 if int(box.get("group", -1)) == Terrain.Group.OILRIG else 0
	var sites: Array[Dictionary] = OilField.sites()
	var want: int = 0
	for site in sites:
		want += OilPlatform.collision_boxes(site["position"], float(site["depth"])).size()
	var nearest: float = INF
	var nearest_kind: String = ""
	for spawn in Terrain.spawns():
		if not Terrain.is_a_ship(int(spawn["kind"])) and int(spawn["kind"]) != Sim.Kind.PIRATE:
			continue
		for site in sites:
			var d: float = Vector2((spawn["position"] as Vector3).x - (site["position"] as Vector3).x,
				(spawn["position"] as Vector3).z - (site["position"] as Vector3).z).length()
			if d < nearest:
				nearest = d
				nearest_kind = Sim.Kind.keys()[int(spawn["kind"])]
	var near_point: float = _nearest_ship_waypoint(sites, BoxGrid.new(Terrain.boxes()))
	# AND THE ZONE CAN DROP A POINT: today no pool reaches it, so a pool built to -- one point on the platform, one 500 m
	# off, one 2 km off -- must come back with only the far one. Without this, the filter is proved by never running.
	var p0: Vector3 = sites[0]["position"] if not sites.is_empty() else Vector3.ZERO
	var tried: Array[Vector3] = [p0, p0 + Vector3(500.0, 0.0, 0.0), p0 + Vector3(0.0, 0.0, 2000.0)]
	var kept: Array[Vector3] = OilField.keep_clear(tried)
	var zone_works: bool = kept.size() == 1 and kept[0] == tried[2]
	check("the_world_lists_the_platform_clear_of_shipping", listed == want and want > 0
			and nearest >= OilField.SHIPPING_CLEAR and near_point >= OilField.KEEP_CLEAR and zone_works,
		("%d OILRIG boxes listed of %d; the nearest ship spawn is a %s %.0f m off, the nearest ship waypoint %.0f m; of "
			+ "points 0, 500 and 2,000 m off the platform the zone kept %d") % [listed, want, nearest_kind, nearest,
			near_point, kept.size()])


## THE NEAREST POINT ANY SHIP IS SENT TO, from any platform, over every kind that floats.
func _nearest_ship_waypoint(sites: Array[Dictionary], grid: BoxGrid) -> float:
	var nearest: float = INF
	for kind in [Sim.Kind.BOAT, Sim.Kind.GUNBOAT, Sim.Kind.CARRIER, Sim.Kind.BATTLESHIP, Sim.Kind.SUBMARINE,
			Sim.Kind.PIRATE]:
		for at in Terrain.waypoints(kind, grid):
			for site in sites:
				var p: Vector3 = site["position"]
				nearest = minf(nearest, Vector2(at.x - p.x, at.z - p.z).length())
	return nearest


## ON THE GENERATED GROUND IT STANDS ON THAT GROUND'S SEA FLOOR: the site `OilField` finds there is open sea, the depth
## it is built for is the ground's own function under it, inside the range a fixed jacket is built for, and it stands
## clear of every ship's spawn on that world too. The ground is the level's: a `GroundField` on `GroundTuning.values()`.
func _on_the_generated_ground_it_stands_on_that_sea_floor() -> void:
	var ground: Object = ClassDB.instantiate("GroundField")
	ground.call("configure", GroundTuning.values())
	Terrain.stand_on(ground)
	var sites: Array[Dictionary] = OilField.sites()
	var said: PackedStringArray = []
	var ok: bool = sites.size() == OilField.PLATFORMS.size()
	for site in sites:
		var at: Vector3 = site["position"]
		var floor: float = Terrain.ground_height(at)
		var sea: float = Terrain.water_height(at)
		# THE JACKET'S FEET, where the drawing puts them for this depth, against the ground under each: none may stand
		# above the floor (a leg in open water), and none be buried deeper than a pile sleeve is tall.
		var feet: float = sea - float(site["depth"])
		var proud: float = -INF
		var buried: float = -INF
		for i in [0, OilPlatform.LEG_X.size() - 1]:
			for j in [0, 1]:
				var leg: Vector3 = at + OilPlatform.leg_at(i, j, -float(site["depth"]))
				var bed: float = Terrain.ground_height(leg)
				proud = maxf(proud, feet - bed)
				buried = maxf(buried, bed - feet)
		var out: float = maxf(absf(at.x), absf(at.z))
		ok = ok and sea != -INF and proud <= 0.05 and buried < 9.0 and out <= Terrain.placed_reach() 			and float(site["depth"]) >= OilField.MIN_DEPTH and float(site["depth"]) <= OilField.MAX_DEPTH
		said.append("%s at %v in %.1f m over a floor at %.2f; no foot stands proud of the bed by more than %.2f m or is sunk "
			% [site["name"], at, float(site["depth"]), floor, maxf(proud, 0.0)]
			+ "more than %.2f m; %.0f m out against a placed reach of %.0f" % [buried, out, Terrain.placed_reach()])
	var nearest: float = INF
	for spawn in Terrain.spawns():
		if Terrain.is_a_ship(int(spawn["kind"])) or int(spawn["kind"]) == Sim.Kind.PIRATE:
			for site in sites:
				nearest = minf(nearest, Vector2((spawn["position"] as Vector3).x - (site["position"] as Vector3).x,
					(spawn["position"] as Vector3).z - (site["position"] as Vector3).z).length())
	var near_point: float = _nearest_ship_waypoint(sites, null)
	Terrain.stand_on(null)
	check("on_the_generated_ground_it_stands_on_that_sea_floor", ok and nearest >= OilField.SHIPPING_CLEAR
			and near_point >= OilField.KEEP_CLEAR,
		"%s; the nearest ship spawn %.0f m off, the nearest ship waypoint %.0f m" % [", ".join(said), nearest, near_point])


## A HELICOPTER SET DOWN ON THE HELIDECK RESTS ON IT: a UH-60 dropped from 3 m over the deck with no collective comes to
## rest as high over the deck as the same helicopter dropped on the island's slab rests over the slab -- the game's own
## answer for "standing on something", not a number typed beside it. The control is the same drop 60 m out over the sea,
## which must fall past the deck, so a run that stops has stopped for the reason claimed.
func _a_helicopter_set_down_on_the_helideck_rests_on_it() -> void:
	if not Sim.is_available():
		check("a_helicopter_set_down_on_the_helideck_rests_on_it", false, "no simulation")
		return
	var world: Object = _bare_world()
	var centre: Vector3 = OilPlatform.helideck_centre()
	var runs: Array = [["on the deck", centre + Vector3.UP * 3.0], ["on the slab", SLAB_AT + Vector3.UP * 3.0],
		["over the sea", centre + Vector3(60.0, 3.0, 0.0)]]
	var client: int = 80
	var inputs: Dictionary = {}
	for run in runs:
		client += 1
		var seat: Dictionary = world.spawn_pilot(client, Sim.Kind.UH60, run[1], 0.0, Vector3.ZERO)
		run.append(int(seat.get("vehicle", 0)))
		inputs[int(seat.get("pilot", 0))] = _controls()
	for tick in range(int(8.0 * FLY_HZ)):
		for pilot in inputs:
			world.set_pilot_input(pilot, inputs[pilot])
		world.tick(1.0 / FLY_HZ)
	var rest: Array[float] = []
	var speed: Array[float] = []
	for run in runs:
		var state: Dictionary = world.vehicle_state(run[2])
		rest.append((state.get("position", Vector3.INF) as Vector3).y)
		speed.append((state.get("velocity", Vector3.ZERO) as Vector3).length())
	_let_go(world)
	var over_deck: float = rest[0] - centre.y
	var over_slab: float = rest[1]
	check("a_helicopter_set_down_on_the_helideck_rests_on_it",
		absf(over_deck - over_slab) < 0.3 and speed[0] < 0.3 and rest[2] < centre.y - 20.0,
		"it rests %.2f m over the deck at %.2f m/s, %.2f m over the slab beside; the control over the sea fell to %.1f m"
			% [over_deck, speed[0], over_slab, rest[2]])


## A FIGHTER FLOWN AT THE PLATFORM IS STOPPED: straight along +x at the height of its decks, and a control run offset
## clear of it passes. The cooling tower's arrangement (`tests/cooling_towers.gd`).
func _a_fighter_flown_at_the_platform_is_stopped() -> void:
	if not Sim.is_available():
		check("a_fighter_flown_at_the_platform_is_stopped", false, "no simulation")
		return
	var world: Object = _bare_world()
	# NO CRASH RULE (lane/combat): what is asked is whether the platform's collision stops a fighter, and the control
	# goes on past it -- flown hands off from 30 m it meets the sea on the way, which the rule would end it in.
	if world.has_method("set_crashes"):
		world.set_crashes(false)
	var runs: Array = [["at the decks", 0.0], ["clear of it", 300.0]]
	var inputs: Dictionary = {}
	var client: int = 90
	for run in runs:
		client += 1
		var seat: Dictionary = world.spawn_pilot(client, Sim.Kind.FIGHTER, Vector3(-700.0, 30.0, float(run[1])),
			PI * 0.5, Vector3(140.0, 0.0, 0.0))
		run.append(int(seat.get("vehicle", 0)))
		run.append(-INF)
		inputs[int(seat.get("pilot", 0))] = _controls({"throttle": 0.8})
	for tick in range(int(9.0 * FLY_HZ)):
		for pilot in inputs:
			world.set_pilot_input(pilot, inputs[pilot])
		world.tick(1.0 / FLY_HZ)
		for run in runs:
			var where: Vector3 = (world.vehicle_state(run[2]) as Dictionary).get("position", Vector3.ZERO)
			run[3] = maxf(float(run[3]), where.x)
	_let_go(world)
	var far_side: float = OilPlatform.HELIDECK_AT.x + OilPlatform.HELIDECK_ACROSS
	check("a_fighter_flown_at_the_platform_is_stopped", float(runs[0][3]) < 0.0 and float(runs[1][3]) > far_side,
		"flown at the decks it reached x %.1f (under 0 is short of the jacket's middle); the control reached %.1f"
			% [float(runs[0][3]), float(runs[1][3])])


## ---- the cost -------------------------------------------------------------------------------------------------------

func _it_costs_little(mesh: ArrayMesh) -> void:
	var triangles: int = 0
	for s in range(mesh.get_surface_count()):
		triangles += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	var platform: Node3D = OilField.one(ISLAND_SEA_DEPTH)
	var draws: int = 0
	for node in platform.find_children("*", "GeometryInstance3D", true, false):
		var drawn := node as MeshInstance3D
		draws += drawn.mesh.get_surface_count() if drawn != null else 1
	var lights: int = platform.find_children("*", "Light3D", true, false).size()
	platform.free()
	check("it_costs_little", triangles <= MOST_TRIANGLES and draws <= FIRST_LOD_DRAWS and lights <= 2,
		"%d triangles (tripwire %d), %d draws, %d engine lights" % [triangles, MOST_TRIANGLES, draws, lights])


## ---- the flare on the sea at night --------------------------------------------------------------------------------

## THE SEA REFLECTS THE FLARE, AND NOTHING IS PAINTED ON THE WATER UNDER IT. Until 2026-09-18 a 120 m disc of noise lay on
## the sea under the flame and read as a lit floor (lane/flaresea); the reflection is now the ocean shaders' own glint
## (`sea_glint.gdshaderinc`), handed its numbers by `OilField.glint_numbers`. So: no mesh of the platform but its structure
## stands within 5 m of the water; by day nothing is reflected and after dark the flare is, from where the HALO is drawn --
## the flame as drawn, read off the node -- with the deck lamps at four of the floods drawn, spread across the deck; both
## ocean finishes add the glint; and the project declares every number handed. The picture of the path, measured as warm
## light in a band under the flame, is `tests/oil_platform_shot.gd`'s.
func _the_sea_reflects_the_flare_and_nothing_lies_on_it() -> void:
	var platform: Node3D = OilField.one(ISLAND_SEA_DEPTH)
	var at := Vector3(6000.0, 0.0, -10500.0)
	add_child(platform)
	platform.global_position = at
	var low: Array[String] = []
	for node in platform.find_children("*", "MeshInstance3D", true, false):
		if node.name != &"Structure" and (node as Node3D).global_position.y - at.y < 5.0:
			low.append(String(node.name))
	check("nothing_is_painted_on_the_water_under_the_flare", low.is_empty(), "meshes on the water: %s" % [low])
	var day: Dictionary = OilField.glint_numbers(platform, DaylightTuning.look_of(DaylightTuning.When.DAY))
	var night: Dictionary = OilField.glint_numbers(platform, DaylightTuning.look_of(DaylightTuning.When.NIGHT))
	var nobody: Dictionary = OilField.glint_numbers(null, DaylightTuning.look_of(DaylightTuning.When.NIGHT))
	check("by_day_and_with_no_platform_the_sea_reflects_nothing",
		(day[&"sea_glint_flare_colour"] as Vector4).w == 0.0 and (day[&"sea_glint_lamps_colour"] as Vector4).w == 0.0
		and (nobody[&"sea_glint_flare_colour"] as Vector4).w == 0.0,
		"day %s, none %s" % [day[&"sea_glint_flare_colour"], nobody[&"sea_glint_flare_colour"]])
	var halo: Vector3 = (platform.get_node("Flare/Halo") as Node3D).global_position
	var flare: Vector4 = night[&"sea_glint_flare"]
	var lit: Vector4 = night[&"sea_glint_flare_colour"]
	check("after_dark_the_sea_reflects_the_flame_where_it_is_drawn",
		lit.w > 0.0 and lit.x > lit.z and Vector3(flare.x, flare.y, flare.z).distance_to(halo) < 0.01,
		"reflected from %s, the halo drawn at %s, colour %s" % [flare, halo, lit])
	var floods: Array[Vector3] = []
	for lamp in OilPlatform.floods():
		floods.append(at + (lamp["position"] as Vector3))
	var lamps: Projection = night[&"sea_glint_lamps"]
	var drawn: int = 0
	var spread: float = INF
	for i in range(4):
		var p := Vector3(lamps[i].x, lamps[i].y, lamps[i].z)
		for f in floods:
			if f.distance_to(p) < 0.01:
				drawn += 1
				break
		for j in range(i + 1, 4):
			spread = minf(spread, p.distance_to(Vector3(lamps[j].x, lamps[j].y, lamps[j].z)))
	check("the_deck_lamps_reflected_are_four_floods_across_the_deck",
		drawn == 4 and spread > 20.0 and (night[&"sea_glint_lamps_colour"] as Vector4).w > 0.0,
		"%d of 4 at a drawn flood, nearest two %.1f m apart" % [drawn, spread])
	platform.free()
	var finishes: Array[String] = []
	for path in ["res://world/shaders/ocean.gdshader", "res://world/shaders/ocean_fine.gdshader"]:
		var code: String = (load(path) as Shader).code
		if not (code.contains("sea_glint.gdshaderinc") and code.contains("EMISSION = sea_glints(")):
			finishes.append(path.get_file())
	var undeclared: Array[String] = []
	for field in night.keys():
		if not ProjectSettings.has_setting("shader_globals/%s" % field):
			undeclared.append(String(field))
	check("both_ocean_finishes_reflect_it_and_every_number_is_declared", finishes.is_empty() and undeclared.is_empty(),
		"finishes without the glint %s, undeclared %s" % [finishes, undeclared])


## ---- helpers --------------------------------------------------------------------------------------------------------

func _part_box(r: Vector2i, verts: PackedVector3Array) -> AABB:
	var box := AABB(verts[r.x], Vector3.ZERO)
	for i in range(r.x, r.x + r.y):
		box = box.expand(verts[i])
	return box


## WHETHER A DRAWN VERTEX CARRIES A PAINT: within two steps of eight bits, because a mesh stores its vertex colours
## compressed and `is_equal_approx` against the constant finds nothing (the first run of this suite, 2026-09-18).
func _same_paint(drawn: Color, paint: Color) -> bool:
	return absf(drawn.r - paint.r) < 0.008 and absf(drawn.g - paint.g) < 0.008 and absf(drawn.b - paint.b) < 0.008


func _part_of(parts: Dictionary, i: int) -> String:
	for name in parts:
		var r: Vector2i = parts[name]
		if i >= r.x and i < r.x + r.y:
			return name
	return "?"


## The drawn helideck plate's top: the highest vertex of the Helideck part that is not paint.
func _drawn_deck_top(verts: PackedVector3Array) -> float:
	var built: Dictionary = OilPlatform.build(ISLAND_SEA_DEPTH)
	var r: Vector2i = built["parts"]["Helideck"]
	var colours: PackedColorArray = (built["mesh"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var top: float = -INF
	for i in range(r.x, r.x + r.y):
		if _same_paint(colours[i], OilPlatform.HELIDECK_GREEN):
			top = maxf(top, verts[i].y)
	return top


## A BARE WORLD with the island's slab, the sea floor and the platform's solid, nothing else: the platform at the origin.
func _bare_world() -> Object:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(FLY_HZ)
	world.start(0)
	# A PIECE OF THE ISLAND'S SLAB, a kilometre west of the platform so the two cannot touch, its top at y = 0.
	world.add_static_box(SLAB_AT + Vector3(0.0, -SLAB_HALF.y, 0.0), SLAB_HALF)
	world.add_static_box(Vector3(0.0, -ISLAND_SEA_DEPTH - 25.0, 0.0), Vector3(5000.0, 25.0, 5000.0))
	# THE PLATFORM, at the origin.
	for box in OilPlatform.collision_boxes(Vector3.ZERO, ISLAND_SEA_DEPTH):
		world.add_static_box(box["position"], box["half_extents"])
	return world


func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input := {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0, "head": Vector3.ZERO,
		"head_basis": Quaternion.IDENTITY, "left": Vector3.ZERO, "left_basis": Quaternion.IDENTITY, "right": Vector3.ZERO,
		"right_basis": Quaternion.IDENTITY, "grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
		"kind_wanted": Sim.NO_KIND}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _let_go(world: Object) -> void:
	world.teardown()
	if not (world is RefCounted):
		world.free()


## A WORLD WITH NO SEA BUILDS NO PLATFORM AND SAYS NOTHING (the user, 2026-09-19: "limit this restriction so that oil rigs can
## be more easily placed"): the test field's ground has its coast past its corners, so no depth could place a rig there and
## the warning would only be noise. The control is the alpine ground, which has sea and does build one.
func _a_world_with_no_sea_builds_no_platform_and_says_nothing() -> void:
	var dry: Object = ClassDB.instantiate("GroundField")
	dry.call("configure", {"world_half": 32768, "peak_height": 300, "seed": 0, "coast": 96, "sites_within": 20500})
	Terrain.stand_on(dry)
	OilField.refusals = PackedStringArray()
	var none: Array[Dictionary] = OilField.sites()
	var quiet: bool = OilField.refusals.is_empty()
	var dry_sea: bool = Terrain.has_sea()
	Terrain.stand_on(null)
	var wet: Object = ClassDB.instantiate("GroundField")
	wet.call("configure", GroundTuning.values())
	Terrain.stand_on(wet)
	var built: Array[Dictionary] = OilField.sites()
	Terrain.stand_on(null)
	check("a_world_with_no_sea_builds_no_platform_and_says_nothing",
		not dry_sea and none.is_empty() and quiet and built.size() == OilField.PLATFORMS.size() and OilField.refusals.is_empty(),
		"dry world: has_sea %s, %d sites, refusals %s; sea world: %d sites" % [dry_sea, none.size(), OilField.refusals, built.size()])


## A JACKET IN SHALLOW WATER IS STILL A JACKET: from the floor's 10 m to 60 m the frame levels run from the top frame down to
## the seabed in at least one bay, strictly downward, no leg's foot above the water line, and the deck stays over the sea.
func _a_shallow_jacket_is_drawn_sensibly() -> void:
	var ok: bool = true
	var said: PackedStringArray = []
	for depth in [OilField.MIN_DEPTH, 15.0, 30.0, 60.0]:
		var levels: PackedFloat64Array = OilPlatform.frame_levels(depth)
		var down: bool = levels.size() >= 2 and is_equal_approx(levels[levels.size() - 1], -depth)
		for k in range(1, levels.size()):
			down = down and levels[k] < levels[k - 1]
		var mesh: ArrayMesh = OilPlatform.build(depth)["mesh"]
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var low: float = INF
		for v in verts:
			low = minf(low, v.y)
		ok = ok and down and absf(low + depth) < 3.5 and OilPlatform.CELLAR_DECK > 0.0
		said.append("%.0f m: %d levels, lowest vertex %.2f" % [depth, levels.size(), low])
	check("a_shallow_jacket_is_drawn_sensibly", ok, "; ".join(said))
