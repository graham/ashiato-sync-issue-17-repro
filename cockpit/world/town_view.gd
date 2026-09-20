extends Node3D
class_name TownView
## THE TOWNS, DRAWN FROM THE BOXES THE SIMULATION WAS GIVEN: the buildings a kilometre at a time, their lights from far
## off, and every street and road on the island as paint, likewise -- each kilometre built when the `SceneryYard` says it
## is within reach.
##
## HANDED THE LIST, NEVER GENERATING ONE. `FlightLevel._build` walks `Terrain.boxes()` once for
## `Sim.add_static_box` and files the same array in a `WorldMap`, which this is handed, and this keeps the entries
## whose group is BUILDING -- so a building is drawn exactly where, and exactly as big as, the box the simulation
## has. `tests/smoke.gd` holds what this handed each MultiMesh (`drawn_buildings`) to the list, and asks the
## simulation's own copy about every wall of every one.
##
## TWO LAYERS OF THE YARD'S, not batches of its own, since 2026-09-14. The yard decides when a kilometre is built and
## when it is let go; this decides what a kilometre of town looks like, and hands the yard a function that builds one.
## A building belongs to the one cell its centre stands in, and each cell's batch stands at the middle of the
## buildings it draws, with the instances as offsets from there: a MultiMesh's transforms are float32 whatever the
## engine's precision. It was one MultiMesh a town until then, culled as one box, which drew every block of a town
## whenever any block was in frame.
##
## THE FAR LIGHTS, since 2026-09-15: a point for every two windows by two on every wall, carrying their light
## (`world/shaders/town_lights.gdshaderinc`), built by the same work and the same build as the kilometre of buildings
## they stand on, so the two are built and let go on the same frame. The wall hands its lights to them across the band before `windows_to`, from one
## function both shaders include. Until then a town's lights faded out by 1.4 km (PLAIN) or 2.2 km (FINE) to dim orange
## blocks, and were gone in the fog by 10 km (agents.md, "How far a town's lights are seen").
##
## THE OBSTRUCTION LIGHTS, since 2026-09-15: red lamps at the roof corners of every building over
## `TownTuning.OBSTRUCTION_HIGH`, and at levels down its corners, as ICAO Annex 14 lays them out (`obstruction_lights_on`),
## drawn by `world/shaders/lamp.gdshaderinc` and flashing together on the phase `show_flash` hands over from the tick. On a
## layer of their own over the kilometres with a tall building, reaching `lamp_reach`, so they outlast their walls.
##
## THE STREET LIGHTS, built on 2026-09-15 and switched off the same day for what they cost in a headset: lamps along every
## town street with their poles and sodium pools, worked out by the same work as the paint they stand on. Behind
## `TownTuning.STREET_LIGHTS_ON`, read once in `draw_towns`; off, nothing of theirs is made -- no material, mesh, buffer or
## batch -- and the obstruction lights keep the lamps' material, which is theirs too.
##
## SIZE IN THE BASIS, THE REST IN INSTANCE_CUSTOM: x the roof (`TownPlan.Roof`), y a 0..1 hash of
## the seed, z the storey count, w unused (FINE's roof dressing will cut the box there). A unit box
## scaled per instance, as the rock and concrete batches are.
##
## THE FINISH: the plain material is on the mesh and the fine one is worn as an override, as the rock
## batches do it, so wearing PLAIN is clearing the override. The far lights wear one of their two as an override always.
## `worn()` reads that back. A kilometre built after the finish changed is built wearing it.

const PLAIN_SHADER: Shader = preload("res://world/shaders/building.gdshader")
const FINE_SHADER: Shader = preload("res://world/shaders/building_fine.gdshader")
const LIGHTS_PLAIN_SHADER: Shader = preload("res://world/shaders/town_lights.gdshader")
const LIGHTS_FINE_SHADER: Shader = preload("res://world/shaders/town_lights_fine.gdshader")
const LAMP_SHADER: Shader = preload("res://world/shaders/lamp.gdshader")
const POOL_SHADER: Shader = preload("res://world/shaders/lamp_pool.gdshader")

## What a lamp is, as `lamp.gdshaderinc` reads it in INSTANCE_CUSTOM.y: a street lamp, a steady red (ICAO low-intensity
## Type B) or a flashing one (medium-intensity Type B).
const STREET_LAMP: int = 0
const STEADY_RED: int = 1
const FLASHING_RED: int = 2

## The yard's names for this file's two layers. A kilometre of buildings carries its far lights.
const BUILDINGS: String = "Buildings"
const ROADS: String = "Roads"
## The obstruction lights' own layer, over the kilometres that have a building over `TownTuning.OBSTRUCTION_HIGH`.
const OBSTRUCTION: String = "Obstruction"

## The four walls a building has, by the way each faces.
const WALLS: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]

var _yard: SceneryYard = null
var _plain: ShaderMaterial = null
var _fine: ShaderMaterial = null
var _lights_plain: ShaderMaterial = null
var _lights_fine: ShaderMaterial = null
## Whether a batch built now wears the fine material.
var _fine_on: bool = false
## The fog density last handed to the far lights, so an unchanged fog writes nothing.
var _fog_handed: float = -1.0
## The lamps' material, the same on both finishes, and the flash phase last handed to it.
var _lamps: ShaderMaterial = null
var _flash_handed: float = -1.0
## The street lamps' pools and their poles, the same on both finishes.
var _pools: ShaderMaterial = null
var _poles: StandardMaterial3D = null

## TEST SEAM, shipped: the street lights built whatever `TownTuning.STREET_LIGHTS_ON` says, so the code behind the switch is
## still driven while it is off (tests/night_lights.gd), and can be looked at (`tests/town_lights_shot.gd --street-lights=on`).
## False in the game. Read once, when `draw_towns` files the streets.
static var street_lights_in_tests: bool = false


## Whether a town drawn now has street lights: the switch, or a test that turned them on.
static func street_lights_on() -> bool:
	return TownTuning.STREET_LIGHTS_ON or street_lights_in_tests


## Hand the yard every town, its lights and the paint, as two layers. `map` files the list the simulation was just
## given; `reach` is how far from the eye a kilometre of town is drawn. `lamp_reach` is how far its obstruction lights are, and
## under 0 is `reach`: the level hands the camera's far for both today, and a player's shorter view distance for the buildings
## would leave the reds at the camera's far.
func draw_towns(map: WorldMap, paint: Array[Dictionary], reach: float, yard: SceneryYard, lamp_reach: float = -1.0) -> void:
	_yard = yard
	_plain = ShaderMaterial.new()
	_plain.shader = PLAIN_SHADER
	_fine = ShaderMaterial.new()
	_fine.shader = FINE_SHADER
	for material in [_plain, _fine]:
		material.set_shader_parameter("storey", TownTuning.STOREY)
		material.set_shader_parameter("far_glow", TownTuning.FAR_GLOW)
		material.set_shader_parameter("window_pixels_least", TownTuning.WINDOW_PIXELS_LEAST)
		material.set_shader_parameter("light_pixels_least", TownTuning.LIGHT_PIXELS_LEAST)
	# EVERY WINDOW NUMBER, PER FINISH, once. Until 2026-09-13 none of these were handed over, so both finishes drew the
	# shader's own defaults and FINE's larger windows and longer fade in TownTuning reached nothing. tests/scenery.gd
	# reads them back.
	_plain.set_shader_parameter("bay", TownTuning.PLAIN_BAY)
	_plain.set_shader_parameter("window_wide", TownTuning.PLAIN_WINDOW_WIDE)
	_plain.set_shader_parameter("window_tall", TownTuning.PLAIN_WINDOW_TALL)
	_plain.set_shader_parameter("windows_to", TownTuning.PLAIN_WINDOWS_TO)
	_fine.set_shader_parameter("bay", TownTuning.FINE_BAY)
	_fine.set_shader_parameter("window_wide", TownTuning.FINE_WINDOW_WIDE)
	_fine.set_shader_parameter("window_tall", TownTuning.FINE_WINDOW_TALL)
	_fine.set_shader_parameter("windows_to", TownTuning.FINE_WINDOWS_TO)
	_plain.set_shader_parameter("window_light", TownTuning.PLAIN_WINDOW_LIGHT)
	_fine.set_shader_parameter("window_warm", TownTuning.FINE_WINDOW_WARM)
	_fine.set_shader_parameter("window_cool", TownTuning.FINE_WINDOW_COOL)
	_fine.set_shader_parameter("window_cool_share", TownTuning.FINE_WINDOW_COOL_SHARE)
	_fine.set_shader_parameter("window_light_least", TownTuning.FINE_WINDOW_LIGHT_LEAST)
	_lights_plain = ShaderMaterial.new()
	_lights_plain.shader = LIGHTS_PLAIN_SHADER
	_lights_fine = ShaderMaterial.new()
	_lights_fine.shader = LIGHTS_FINE_SHADER
	# THE FAR LIGHTS ARE HANDED THE SAME NUMBERS AS THEIR FINISH'S WALLS, from the wall's own material, so the two sides of
	# the handover cannot disagree about a window's size, its colour or where the handover is.
	for pair in [[_plain, _lights_plain], [_fine, _lights_fine]]:
		var wall: ShaderMaterial = pair[0]
		var lights: ShaderMaterial = pair[1]
		for uniform in ["window_wide", "window_tall", "windows_to", "window_light", "window_warm", "window_cool",
				"window_cool_share", "window_light_least"]:
			if wall.get_shader_parameter(uniform) != null:
				lights.set_shader_parameter(uniform, wall.get_shader_parameter(uniform))
		lights.set_shader_parameter("point_pixels", TownTuning.FAR_LIGHT_PIXELS)
		lights.set_shader_parameter("point_least", TownTuning.FAR_LIGHT_LEAST)
		lights.set_shader_parameter("point_spacing", TownTuning.FAR_LIGHT_SPACING)
	# THE LAMPS, every number from TownTuning, handed over here and never left to a shader default.
	_lamps = ShaderMaterial.new()
	_lamps.shader = LAMP_SHADER
	_lamps.set_shader_parameter("light_per_candela", TownTuning.LIGHT_PER_CANDELA)
	_lamps.set_shader_parameter("point_pixels", TownTuning.FAR_LIGHT_PIXELS)
	_lamps.set_shader_parameter("peak_most", TownTuning.LAMP_PEAK_MOST)
	_lamps.set_shader_parameter("grow_most", TownTuning.LAMP_GROW_MOST)
	_lamps.set_shader_parameter("seen_lux", TownTuning.LAMP_SEEN_LUX)
	_lamps.set_shader_parameter("seen_band", TownTuning.LAMP_SEEN_BAND)
	_lamps.set_shader_parameter("seen_peak", TownTuning.LAMP_SEEN_PEAK)
	_lamps.set_shader_parameter("obstruction_red", TownTuning.OBSTRUCTION_RED)
	var cycle: float = 60.0 / TownTuning.OBSTRUCTION_FLASHES_A_MINUTE
	_lamps.set_shader_parameter("flash_on", TownTuning.OBSTRUCTION_FLASH_ON / cycle)
	_lamps.set_shader_parameter("flash_ease", TownTuning.OBSTRUCTION_FLASH_EASE / cycle)
	_lamps.set_shader_parameter("street_colour", TownTuning.STREET_LIGHT_COLOUR)
	_lamps.set_shader_parameter("street_side_share", TownTuning.STREET_LIGHT_SIDE_SHARE)
	_lamps.set_shader_parameter("road_reflectance", TownTuning.ROAD_REFLECTANCE)
	_lamps.set_shader_parameter("pool_to", TownTuning.POOL_TO)
	_lamps.set_shader_parameter("night_adaptation", TownTuning.night_adaptation())
	# THE STREET LIGHTS' OWN MATERIALS, made only when they are switched on: the point of the switch is what they cost, so off
	# is nothing made, never something made and hidden (2026-09-15).
	var streets_lit: bool = TownView.street_lights_on()
	if streets_lit:
		_pools = ShaderMaterial.new()
		_pools.shader = POOL_SHADER
		_pools.set_shader_parameter("light_per_candela", TownTuning.LIGHT_PER_CANDELA)
		_pools.set_shader_parameter("street_candela", TownTuning.STREET_LIGHT_CANDELA)
		_pools.set_shader_parameter("road_reflectance", TownTuning.ROAD_REFLECTANCE)
		_pools.set_shader_parameter("pool_reach", TownTuning.POOL_REACH)
		_pools.set_shader_parameter("pool_to", TownTuning.POOL_TO)
		_pools.set_shader_parameter("pool_lift", TownTuning.POOL_LIFT)
		_pools.set_shader_parameter("pool_pull", TownTuning.POOL_PULL)
		_pools.set_shader_parameter("night_adaptation", TownTuning.night_adaptation())
		_pools.set_shader_parameter("street_colour", TownTuning.STREET_LIGHT_COLOUR)
		_poles = StandardMaterial3D.new()
		_poles.albedo_color = TownTuning.STREET_POLE_COLOUR
		_poles.metallic = 0.4
		_poles.roughness = 0.55
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = _plain

	var buildings: Dictionary = {}
	var building_bounds: Dictionary = {}
	for cell in map.cells():
		var mine: Array[Dictionary] = []
		for box in map.boxes_in(cell):
			if int(box["group"]) == Terrain.Group.BUILDING:
				mine.append(box)
		if mine.is_empty():
			continue
		var hull := AABB()
		for i in range(mine.size()):
			var half: Vector3 = mine[i]["half_extents"]
			var one := AABB((mine[i]["position"] as Vector3) - half, half * 2.0)
			hull = one if i == 0 else hull.merge(one)
		buildings[cell] = mine
		building_bounds[cell] = hull
	# WORKED LAYERS: each kilometre's buffer made on a worker from these finished Dictionaries, put on a node by the yard's
	# frame. The work names its class for the static it calls; it touches nothing of this node's.
	# ONE WORKED LAYER FOR A KILOMETRE'S BUILDINGS AND ITS FAR LIGHTS TOGETHER: one work makes both buffers on a worker and
	# one build puts both on nodes, so the two arrive, are kept and are let go on the same frame, and the wall never hands its
	# lights to a kilometre whose lights are not built. Two layers on the same bounds would be two queue entries, split by
	# the frame budget and by work that finishes at different times.
	var point := QuadMesh.new()
	point.size = Vector2(2.0, 2.0)
	yard.add_worked_layer(BUILDINGS, building_bounds, reach, self,
		func(cell: Vector2i) -> Dictionary:
			var middle: Vector3 = (building_bounds[cell] as AABB).get_center()
			var done: Dictionary = TownView.building_buffer(buildings[cell], middle)
			done["lights"] = TownView.lights_buffer(buildings[cell], middle)
			return done,
		func(cell: Vector2i, done: Dictionary) -> Array[Node3D]:
			var out: Array[Node3D] = [_building_batch(done, building_bounds[cell], mesh, reach, cell),
				_lights_batch(done["lights"], building_bounds[cell], point, reach, cell)]
			return out)

	# THE OBSTRUCTION LIGHTS ON A LAYER OF THEIR OWN, drawn and kept to `lamp_reach`, so a tower's reds stay when its walls are
	# let go -- a player's view distance is to shorten the buildings' reach, not the camera's far. They were built by the
	# buildings' own work until the street lights' step 3 (2026-09-15), which let the reds go with the walls. The far lights stay
	# one layer with their walls because a wall hands its light to them; a red has no wall-side twin, so the two layers' queue
	# entries arriving a frame apart draw nothing wrong. Only the kilometres with a building over the height are in it.
	var tall: Dictionary = {}
	var tall_bounds: Dictionary = {}
	for cell in buildings:
		var high: Array[Dictionary] = []
		for building in buildings[cell]:
			if (building["half_extents"] as Vector3).y * 2.0 > TownTuning.OBSTRUCTION_HIGH:
				high.append(building)
		if high.is_empty():
			continue
		var tall_hull := AABB()
		for i in range(high.size()):
			var tall_half: Vector3 = high[i]["half_extents"]
			var box := AABB((high[i]["position"] as Vector3) - tall_half, tall_half * 2.0)
			tall_hull = box if i == 0 else tall_hull.merge(box)
		tall[cell] = high
		tall_bounds[cell] = tall_hull
	var reds_reach: float = reach if lamp_reach < 0.0 else lamp_reach
	yard.add_worked_layer(OBSTRUCTION, tall_bounds, reds_reach, self,
		func(cell: Vector2i) -> Dictionary:
			return TownView.obstruction_buffer(tall[cell], (tall_bounds[cell] as AABB).get_center()),
		func(cell: Vector2i, done: Dictionary) -> Array[Node3D]:
			var out: Array[Node3D] = [_obstruction_batch(done, tall_bounds[cell], point, reds_reach, cell)]
			return out)

	var marks: Dictionary = {}
	var mark_bounds: Dictionary = {}
	var lit: Dictionary = {}
	# THE RAILWAY, asked of Terrain once, so no pole stands on the track where a street crosses it. Complete before the layer is
	# added and read, never resized, by the workers.
	var rail := PackedVector3Array()
	var pole: Mesh = null
	var pool: PlaneMesh = null
	if streets_lit:
		rail = PackedVector3Array(Terrain.rail_points())
		pole = TownView.pole_mesh()
		pool = PlaneMesh.new()
		pool.size = Vector2(2.0, 2.0)
	for mark in paint:
		var cell: Vector2i = WorldMap.cell_of(mark["position"])
		# A MARK IS SIZED IN ITS OWN AXES -- across, up, along -- so it is turned, then pitched about its own across axis, and
		# scaled in its own frame. `Basis.scaled` scales in the world's: a road at a yaw of 0.7 rad drew 64.7 m across instead of
		# 9, and one along x drew along z (increment B5, 2026-09-15). A street has no yaw, so it is drawn as it was.
		var turned := Basis(Vector3.UP, float(mark.get("yaw", 0.0))) * Basis(Vector3.RIGHT, float(mark.get("pitch", 0.0)))
		var shape := Transform3D(turned.scaled_local((mark["half_extents"] as Vector3) * 2.0), mark["position"])
		var one: AABB = shape * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
		if not marks.has(cell):
			marks[cell] = []
			mark_bounds[cell] = one
		(marks[cell] as Array).append([shape, mark.get("colour", TownTuning.ASPHALT)])
		mark_bounds[cell] = (mark_bounds[cell] as AABB).merge(one)
		# A TOWN'S GRID STREET IS LIT, and carries its town's block to say so (`TownPlan.streets`); a road between towns is not.
		# Switched off, no street is filed as lit, so no kilometre's work makes lamps and no build puts any on nodes.
		if streets_lit and mark.has("block"):
			if not lit.has(cell):
				lit[cell] = []
			(lit[cell] as Array).append(mark)
	var block := BoxMesh.new()
	block.size = Vector3.ONE
	var asphalt := StandardMaterial3D.new()
	asphalt.vertex_color_use_as_albedo = true
	asphalt.roughness = 0.95
	yard.add_worked_layer(ROADS, mark_bounds, reach, self,
		func(cell: Vector2i) -> Dictionary:
			var middle: Vector3 = (mark_bounds[cell] as AABB).get_center()
			var done: Dictionary = TownView.paint_buffer(marks[cell], middle)
			# THE STREET LIGHTS BY THE SAME WORK AS THE PAINT THEY STAND ON, so the two arrive and are let go on the same frame.
			if lit.has(cell):
				done["lamps"] = TownView.street_lights_buffer(lit[cell], middle, rail)
			return done,
		func(cell: Vector2i, done: Dictionary) -> Array[Node3D]:
			var out: Array[Node3D] = [_paint_batch(done, mark_bounds[cell], block, asphalt, reach, cell)]
			if done.has("lamps") and int(done["lamps"]["count"]) > 0:
				out.append_array(_street_light_batches(done["lamps"], mark_bounds[cell], point, pole, pool, reach, cell))
			return out)


## ONE KILOMETRE OF BUILDINGS AS THE BUFFER ITS BATCH TAKES, on a worker: a transform and the custom data the building
## shaders read, 16 floats an instance (`SceneryYard.box_buffer` has the layout). `middle` is where the batch will stand.
static func building_buffer(mine: Array[Dictionary], middle: Vector3) -> Dictionary:
	if SceneryYard.work_delay_msec > 0:
		OS.delay_msec(SceneryYard.work_delay_msec)
	var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
	var buffer := PackedFloat32Array()
	buffer.resize(mine.size() * stride)
	var placed: Array[Transform3D] = []
	for i in range(mine.size()):
		var half: Vector3 = mine[i]["half_extents"]
		var at := Transform3D(Basis.IDENTITY.scaled(half * 2.0), (mine[i]["position"] as Vector3) - middle)
		SceneryYard.put_transform(buffer, i * stride, at)
		SceneryYard.put_four(buffer, i * stride + SceneryYard.TRANSFORM_FLOATS, building_custom(mine[i]))
		placed.append(at)
	return {"buffer": buffer, "placed": placed}


## THE FOUR NUMBERS A BUILDING'S SHADER READS: x the roof, y a 0..1 hash of the seed, z the storey count, w unused.
static func building_custom(building: Dictionary) -> Color:
	var half: Vector3 = building["half_extents"]
	return Color(float(building["roof"]), fposmod(float(int(building["seed"]) & 0xFFFF) * 0.618034, 1.0),
		round(half.y * 2.0 / TownTuning.STOREY), 0.0)


## ONE KILOMETRE OF A TOWN'S FAR LIGHTS AS THE BUFFER THEIR BATCH TAKES, on a worker: a point for every
## `TownTuning.FAR_LIGHT_WINDOWS` windows a side of every wall of every building, 16 floats an instance -- its transform
## (along the wall, up, out of it) and the four numbers `town_lights.gdshaderinc` reads.
##
## Returns `{buffer: PackedFloat32Array, count: int}` AND NOTHING ELSE: the yard keeps a let-go cell's numbers, and an
## Array of Transform3D and one of Color beside the buffer -- for the tests alone -- took the 220 km memory flight's static
## memory from 67 MB to 207 (tests/scenery_memory.gd, 2026-09-15); on the double build every transform in an Array is a
## heap Variant. The tests read the buffer itself, which is also the value handed over.
static func lights_buffer(mine: Array[Dictionary], middle: Vector3) -> Dictionary:
	if SceneryYard.work_delay_msec > 0:
		OS.delay_msec(SceneryYard.work_delay_msec)
	var placed: Array[Transform3D] = []
	var customs: Array[Color] = []
	for building in mine:
		for wall in range(WALLS.size()):
			lights_on_a_wall(building, wall, middle, placed, customs)
	var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
	var buffer := PackedFloat32Array()
	buffer.resize(placed.size() * stride)
	for i in range(placed.size()):
		SceneryYard.put_transform(buffer, i * stride, placed[i])
		SceneryYard.put_four(buffer, i * stride + SceneryYard.TRANSFORM_FLOATS, customs[i])
	return {"buffer": buffer, "count": placed.size()}


## THE FAR LIGHTS OF ONE WALL, appended to `placed` and `customs`: the wall cut into cells of `FAR_LIGHT_WINDOWS` bays by as
## many storeys, from its middle along and from the ground up -- where the wall's own window grid lies -- and a point off
## the middle of every cell at least half a bay wide and half a storey tall. Custom: x the cell's wall area in square
## metres (the shader takes the window's share of it), y the hash that lights it, z the hash that thins it, w its colour's.
## The hashes are `Terrain.hash01` of the building's seed, the wall, the column and the row, so every machine lights the
## same points and none depends on the engine's RNG.
static func lights_on_a_wall(building: Dictionary, wall: int, middle: Vector3, placed: Array[Transform3D],
		customs: Array[Color]) -> void:
	var half: Vector3 = building["half_extents"]
	var centre: Vector3 = building["position"]
	var out: Vector3 = WALLS[wall]
	var along: Vector3 = Vector3.UP.cross(out)
	var wide: float = 2.0 * (absf(along.x) * half.x + absf(along.z) * half.z)
	var deep: float = absf(out.x) * half.x + absf(out.z) * half.z
	var tall: float = half.y * 2.0
	var bay: float = TownTuning.PLAIN_BAY
	var step_along: float = bay * TownTuning.FAR_LIGHT_WINDOWS
	var step_up: float = TownTuning.STOREY * TownTuning.FAR_LIGHT_WINDOWS
	var seed: int = int(building["seed"])
	for column in range(floori(-wide * 0.5 / step_along), ceili(wide * 0.5 / step_along)):
		var left: float = maxf(column * step_along, -wide * 0.5)
		var right: float = minf((column + 1) * step_along, wide * 0.5)
		if right - left < bay * 0.5:
			continue
		for row in range(ceili(tall / step_up)):
			var low: float = row * step_up
			var high: float = minf(low + step_up, tall)
			if high - low < TownTuning.STOREY * 0.5:
				continue
			var at: Vector3 = centre + out * (deep + TownTuning.FAR_LIGHT_OFF_WALL) + along * ((left + right) * 0.5) \
				+ Vector3.UP * ((low + high) * 0.5 - half.y) - middle
			placed.append(Transform3D(Basis(along, Vector3.UP, out), at))
			var key: int = (seed * 73856093 + wall * 19349663 + column * 83492791 + row * 50331653) & 0x7FFFFFFF
			customs.append(Color((right - left) * (high - low), Terrain.hash01(key, 1), Terrain.hash01(key, 2),
				Terrain.hash01(key, 3)))


## ONE KILOMETRE OF OBSTRUCTION LIGHTS AS THE BUFFER THEIR BATCH TAKES, on a worker: every light `obstruction_lights_on`
## puts on each building, 16 floats an instance. Returns `{buffer, count}` and nothing else, for the far lights' reason.
static func obstruction_buffer(mine: Array[Dictionary], middle: Vector3) -> Dictionary:
	if SceneryYard.work_delay_msec > 0:
		OS.delay_msec(SceneryYard.work_delay_msec)
	var placed: Array[Transform3D] = []
	var customs: Array[Color] = []
	for building in mine:
		obstruction_lights_on(building, middle, placed, customs)
	var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
	var buffer := PackedFloat32Array()
	buffer.resize(placed.size() * stride)
	for i in range(placed.size()):
		SceneryYard.put_transform(buffer, i * stride, placed[i])
		SceneryYard.put_four(buffer, i * stride + SceneryYard.TRANSFORM_FLOATS, customs[i])
	return {"buffer": buffer, "count": placed.size()}


## THE OBSTRUCTION LIGHTS OF ONE BUILDING, appended to `placed` and `customs`, if it is taller than
## `TownTuning.OBSTRUCTION_HIGH`: a light on each of its four vertical corners at its top, and at levels spaced as equally as
## they can be down to its own ground, no more than `OBSTRUCTION_LEVELS_APART` apart -- the top flashing, the levels below
## it steady and flashing by turns (ICAO Annex 14 Vol I 6.3.11, 6.3.14 and 6.3.17). Each stands exactly on its corner, its out
## axis the diagonal away from the building; the shader stands it off. Custom: x candela, y `STEADY_RED` or
## `FLASHING_RED`, z the lantern, w 1 at the top (it rises off the roof) and 0 below.
##
## THE HEIGHTS ARE THE BUILDING'S OWN, from the top of its box down: a building on ground that is not at y = 0 carries its
## lights on its own corners.
static func obstruction_lights_on(building: Dictionary, middle: Vector3, placed: Array[Transform3D],
		customs: Array[Color]) -> void:
	var half: Vector3 = building["half_extents"]
	var centre: Vector3 = building["position"]
	var tall: float = half.y * 2.0
	if tall <= TownTuning.OBSTRUCTION_HIGH:
		return
	var top: float = centre.y + half.y
	var levels: int = ceili(tall / TownTuning.OBSTRUCTION_LEVELS_APART)
	for level in range(levels):
		var kind: int = FLASHING_RED if level % 2 == 0 else STEADY_RED
		var candela: float = TownTuning.OBSTRUCTION_MEDIUM_CANDELA if kind == FLASHING_RED \
			else TownTuning.OBSTRUCTION_LOW_CANDELA
		var y: float = top - tall * float(level) / float(levels)
		for side in [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(-1.0, -1.0), Vector2(1.0, -1.0)]:
			var out := Vector3(side.x, 0.0, side.y).normalized()
			var at := Vector3(centre.x + side.x * half.x, y, centre.z + side.y * half.z) - middle
			placed.append(Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), at))
			customs.append(Color(candela, float(kind), TownTuning.OBSTRUCTION_LANTERN, 1.0 if level == 0 else 0.0))


## ONE KILOMETRE OF STREET LIGHTS AS THE BUFFER THEIR THREE BATCHES TAKE, on a worker -- the lamps, their poles and their
## pools are one buffer drawn three ways, 16 floats a lamp. `streets` are the lit streets filed in the cell, `rail` the
## railway's points. Returns `{buffer, count}` and nothing else, for the far lights' reason.
static func street_lights_buffer(streets: Array, middle: Vector3, rail: PackedVector3Array) -> Dictionary:
	if SceneryYard.work_delay_msec > 0:
		OS.delay_msec(SceneryYard.work_delay_msec)
	var placed: Array[Transform3D] = []
	var customs: Array[Color] = []
	for street in streets:
		street_lights_along(street, middle, rail, placed, customs)
	var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
	var buffer := PackedFloat32Array()
	buffer.resize(placed.size() * stride)
	for i in range(placed.size()):
		SceneryYard.put_transform(buffer, i * stride, placed[i])
		SceneryYard.put_four(buffer, i * stride + SceneryYard.TRANSFORM_FLOATS, customs[i])
	return {"buffer": buffer, "count": placed.size()}


## THE LAMPS ALONG ONE STREET, appended to `placed` and `customs`. The street is a town's grid street, crossed every `block`
## metres from its middle; between each two crossings its lamps stand evenly, as near `STREET_LIGHT_SPACING_PER_HEIGHT`
## mounting heights apart as whole lamps allow, `STREET_LIGHT_JUNCTION_CLEAR` clear of the crossing street, on one side,
## staggered or both by the street's width over the height, and none within `STREET_LIGHT_RAIL_CLEAR` of the railway. A
## lamp's origin is its head, over the street by its arm; its basis is along the street, UP SCALED TO THE MOUNTING HEIGHT
## -- so local y = -1 is the top of the street, where the pole stands and the pool lies -- and out towards the street's
## middle. Custom: x candela, y `STREET_LAMP`, z the lantern, w 1 (it rises off the street under it).
##
## THE STREET'S OWN HEIGHT, from its mark: a street on ground that is not at y = 0 carries its lamps on its own top.
static func street_lights_along(street: Dictionary, middle: Vector3, rail: PackedVector3Array, placed: Array[Transform3D],
		customs: Array[Color]) -> void:
	var half: Vector3 = street["half_extents"]
	var centre: Vector3 = street["position"]
	var block: float = float(street["block"])
	var along_x: bool = half.x >= half.z
	var along: Vector3 = Vector3.RIGHT if along_x else Vector3.BACK
	var aside: Vector3 = Vector3.BACK if along_x else Vector3.RIGHT
	var run: float = maxf(half.x, half.z)
	var wide: float = 2.0 * minf(half.x, half.z)
	var top: float = centre.y + half.y
	var high: float = street_light_height(wide)
	var spacing: float = high * TownTuning.STREET_LIGHT_SPACING_PER_HEIGHT
	var sides: Array[float] = [1.0]
	if wide > high * TownTuning.STREET_LIGHT_ONE_SIDE:
		sides.append(-1.0)
	var staggered: bool = sides.size() == 2 and wide <= high * TownTuning.STREET_LIGHT_STAGGERED
	var near_rail: PackedVector3Array = _rail_near(rail, centre, half, TownTuning.STREET_LIGHT_RAIL_CLEAR)
	# AN EVEN PITCH ALONG THE WHOLE STREET, junctions and all: as many lamps a block as keep the pitch nearest the height's
	# spacing, each half a pitch in from a junction. Laid evenly between junctions instead, a city street's lamps stood 18.7 m
	# apart within a block and 58 m across a junction, and 4,862 lamps where the spacing asked for about 3,500 (2026-09-15).
	var count: int = maxi(roundi(block / spacing), 1)
	var pitch: float = block / float(count)
	# A CORNER IS LIT ONCE. A lamp half a pitch in from a junction can stand on its corner, at the crossing street's edge; the
	# street running along x keeps it, and one along z keeps its lamps `STREET_LIGHT_JUNCTION_CLEAR` clear of the crossing,
	# so no corner has two poles a metre apart and the corner pole serves both streets' kerbs.
	var clear: float = wide * 0.5 + (0.0 if along_x else TownTuning.STREET_LIGHT_JUNCTION_CLEAR)
	var spans: int = roundi(run / block)
	for k in range(-spans, spans):
		for i in range(count):
			var offset: float = pitch * (float(i) + 0.5)
			if minf(offset, block - offset) < clear - 0.001:
				continue
			var s: float = float(k) * block + offset
			for n in range(sides.size()):
				if staggered and (k + i + n) % 2 != 0:
					continue
				var side: float = sides[n]
				var foot: Vector3 = centre + along * s + aside * (side * (wide * 0.5 - TownTuning.STREET_LIGHT_KERB))
				foot.y = top
				if _within_of_rail(near_rail, foot, TownTuning.STREET_LIGHT_RAIL_CLEAR):
					continue
				var out: Vector3 = -aside * side
				var head: Vector3 = foot + out * TownTuning.STREET_LIGHT_ARM + Vector3.UP * high
				placed.append(Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP * high, out), head - middle))
				customs.append(Color(TownTuning.STREET_LIGHT_CANDELA, float(STREET_LAMP), TownTuning.STREET_LIGHT_LANTERN, 1.0))


## How high a street's lamps stand, by how wide it is: a main road's taller than a side street's.
static func street_light_height(wide: float) -> float:
	return TownTuning.STREET_LIGHT_TALL if wide >= TownTuning.STREET_LIGHT_WIDE else TownTuning.STREET_LIGHT_LOW


## The railway's segments, as pairs of points, whose box comes within `clear` of a street's.
static func _rail_near(rail: PackedVector3Array, centre: Vector3, half: Vector3, clear: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(rail.size()):
		var a: Vector3 = rail[i]
		var b: Vector3 = rail[(i + 1) % rail.size()]
		if minf(a.x, b.x) > centre.x + half.x + clear or maxf(a.x, b.x) < centre.x - half.x - clear:
			continue
		if minf(a.z, b.z) > centre.z + half.z + clear or maxf(a.z, b.z) < centre.z - half.z - clear:
			continue
		out.append(a)
		out.append(b)
	return out


## Whether `at` is within `clear` of any segment in `pairs`, on the ground.
static func _within_of_rail(pairs: PackedVector3Array, at: Vector3, clear: float) -> bool:
	var p := Vector2(at.x, at.z)
	for i in range(0, pairs.size(), 2):
		var a := Vector2(pairs[i].x, pairs[i].z)
		var ab: Vector2 = Vector2(pairs[i + 1].x, pairs[i + 1].z) - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if p.distance_to(a + ab * t) < clear:
			return true
	return false


## A STREET LAMP'S POLE, ARM AND HEAD, in the lamp's own space: the head at the origin, the pole `STREET_LIGHT_ARM` behind it
## from y = -1 (the street) to 0, which the instance's basis stretches to the mounting height. Three boxes; the arm's and
## the head's thickness are shares of a unit height, so a lower lamp's are a little thinner.
static func pole_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	var arm: float = TownTuning.STREET_LIGHT_ARM
	for part in [[Vector3(0.18, 1.0, 0.18), Vector3(0.0, -0.5, -arm)], [Vector3(0.1, 0.012, arm), Vector3(0.0, -0.006, -arm * 0.5)],
			[Vector3(0.3, 0.02, 0.6), Vector3(0.0, -0.01, 0.0)]]:
		var box := BoxMesh.new()
		box.size = part[0]
		tool.append_from(box, 0, Transform3D(Basis.IDENTITY, part[1]))
	return tool.commit()


## ONE KILOMETRE OF STREETS AND ROADS AS THE BUFFER ITS BATCH TAKES, on a worker: a transform and the slab's colour, 16
## floats an instance. `marks` is the cell's `[shape: Transform3D, colour: Color]` pairs as `draw_towns` files them.
static func paint_buffer(marks: Array, middle: Vector3) -> Dictionary:
	if SceneryYard.work_delay_msec > 0:
		OS.delay_msec(SceneryYard.work_delay_msec)
	var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
	var buffer := PackedFloat32Array()
	buffer.resize(marks.size() * stride)
	var placed: Array[Transform3D] = []
	for i in range(marks.size()):
		var shape: Transform3D = marks[i][0]
		var at := Transform3D(shape.basis, shape.origin - middle)
		SceneryYard.put_transform(buffer, i * stride, at)
		SceneryYard.put_four(buffer, i * stride + SceneryYard.TRANSFORM_FLOATS, marks[i][1])
		placed.append(at)
	return {"buffer": buffer, "placed": placed}


## ONE KILOMETRE OF BUILDINGS, standing at the middle of their hull, from what `building_buffer` made.
func _building_batch(done: Dictionary, hull: AABB, mesh: Mesh, reach: float, cell: Vector2i) -> MultiMeshInstance3D:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	# BEFORE THE COUNT: see VehicleLights.build. Then the count, then the whole buffer.
	many.use_custom_data = true
	many.mesh = mesh
	many.instance_count = (done["placed"] as Array).size()
	many.buffer = done["buffer"]
	var node := MultiMeshInstance3D.new()
	node.name = "Buildings_%d_%d" % [cell.x, cell.y]
	node.multimesh = many
	node.position = hull.get_center()
	node.visibility_range_end = SceneryYard.range_for(hull, reach)
	node.material_override = _fine if _fine_on else null
	# WHAT WAS HANDED IN, kept for `drawn_buildings` -- see the note there.
	node.set_meta(&"placed", done["placed"])
	node.set_meta(&"cell", cell)
	return node


## ONE KILOMETRE OF FAR LIGHTS, standing where its buildings' batch stands, from what `lights_buffer` made. Unshaded,
## additive and casting nothing; drawn out to the buildings' own range, and never culled with a box that holds only the
## quads before the shader moves them (`TownTuning.FAR_LIGHT_CULL_MARGIN`).
func _lights_batch(done: Dictionary, hull: AABB, point: Mesh, reach: float, cell: Vector2i) -> MultiMeshInstance3D:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = point
	many.instance_count = int(done["count"])
	many.buffer = done["buffer"]
	var node := MultiMeshInstance3D.new()
	node.name = "TownLights_%d_%d" % [cell.x, cell.y]
	node.multimesh = many
	node.position = hull.get_center()
	# THE HULL GROWN BY HOW FAR A LIGHT STANDS OFF ITS WALL: measured from the buildings' hull alone, a kilometre's lights
	# ended 0.6 m short of their furthest point (tests/town_lights.gd, 24,107 m against 24,108).
	node.visibility_range_end = SceneryYard.range_for(hull.grow(TownTuning.FAR_LIGHT_OFF_WALL), reach)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = TownTuning.FAR_LIGHT_CULL_MARGIN
	node.material_override = _lights_fine if _fine_on else _lights_plain
	# THE BUFFER HANDED OVER, kept as the meta the tests read: the dummy renderer keeps none to read back headless.
	node.set_meta(&"buffer", done["buffer"])
	node.set_meta(&"cell", cell)
	node.set_meta(&"lights", true)
	return node


## ONE KILOMETRE OF OBSTRUCTION LIGHTS, standing where its buildings' batch stands, from what `obstruction_buffer` made:
## drawn as far as the far lights, and culled with the same margin, since the shader moves the quads off their corners.
func _obstruction_batch(done: Dictionary, hull: AABB, point: Mesh, reach: float, cell: Vector2i) -> MultiMeshInstance3D:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = point
	many.instance_count = int(done["count"])
	many.buffer = done["buffer"]
	var node := MultiMeshInstance3D.new()
	node.name = "Obstruction_%d_%d" % [cell.x, cell.y]
	node.multimesh = many
	node.position = hull.get_center()
	node.visibility_range_end = SceneryYard.range_for(hull.grow(TownTuning.FAR_LIGHT_OFF_WALL), reach)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = TownTuning.FAR_LIGHT_CULL_MARGIN
	node.material_override = _lamps
	node.set_meta(&"buffer", done["buffer"])
	node.set_meta(&"cell", cell)
	node.set_meta(&"obstruction", true)
	return node


## ONE KILOMETRE OF STREET LIGHTS, three batches over the one buffer `street_lights_buffer` made, standing where the
## paint's batch stands: the lamps drawn as far as the paint (a lamp is its own far light), the poles to `POLES_TO` and the
## pools to `POOL_TO` beyond the kilometre's middle, where the pool has handed its light to the lamp. Metas `street_lamps`,
## `poles` and `pools` tell them from the paint.
func _street_light_batches(done: Dictionary, hull: AABB, point: Mesh, pole: Mesh, pool: Mesh, reach: float,
		cell: Vector2i) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var half_diagonal: float = hull.size.length() * 0.5
	var full: float = SceneryYard.range_for(hull.grow(TownTuning.STREET_LIGHT_TALL), reach)
	for kind in [&"street_lamps", &"poles", &"pools"]:
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.use_custom_data = true
		many.mesh = point if kind == &"street_lamps" else (pole if kind == &"poles" else pool)
		many.instance_count = int(done["count"])
		many.buffer = done["buffer"]
		var node := MultiMeshInstance3D.new()
		node.name = "%s_%d_%d" % [String(kind).capitalize().replace(" ", ""), cell.x, cell.y]
		node.multimesh = many
		node.position = hull.get_center()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		match kind:
			&"street_lamps":
				node.visibility_range_end = full
				node.extra_cull_margin = TownTuning.FAR_LIGHT_CULL_MARGIN
				node.material_override = _lamps
			&"poles":
				node.visibility_range_end = minf(TownTuning.POLES_TO + half_diagonal, full)
				node.material_override = _poles
			&"pools":
				node.visibility_range_end = minf(TownTuning.POOL_TO + half_diagonal, full)
				# The shader spreads each quad to its pool's reach, past the 2 m mesh the engine sizes the box from.
				node.extra_cull_margin = TownTuning.POOL_REACH * TownTuning.STREET_LIGHT_TALL
				node.material_override = _pools
		node.set_meta(&"buffer", done["buffer"])
		node.set_meta(&"cell", cell)
		node.set_meta(kind, true)
		out.append(node)
	return out


## ONE KILOMETRE OF STREETS AND ROADS, as flat slabs the way the runway's paint is drawn: each slab in the cell its
## middle stands in. A road between towns is kilometres long and leans into the cells beside its own, which its batch's
## box grows to hold.
func _paint_batch(done: Dictionary, hull: AABB, block: Mesh, asphalt: Material, reach: float, cell: Vector2i) -> MultiMeshInstance3D:
	var slabs := MultiMesh.new()
	slabs.transform_format = MultiMesh.TRANSFORM_3D
	slabs.use_colors = true
	slabs.mesh = block
	slabs.instance_count = (done["placed"] as Array).size()
	slabs.buffer = done["buffer"]
	var node := MultiMeshInstance3D.new()
	node.name = "Roads_%d_%d" % [cell.x, cell.y]
	node.multimesh = slabs
	node.material_override = asphalt
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = hull.get_center()
	node.visibility_range_end = SceneryYard.range_for(hull, reach)
	node.set_meta(&"placed", done["placed"])
	node.set_meta(&"cell", cell)
	return node


## LIGHT THE WINDOWS: `share` of them, at `glow`, on both finishes' walls and far lights. Called by the level once per
## change of the time of day (`DaylightTuning`), never per frame -- two uniforms on four materials, and which
## window is lit is a hash in the shader of the same building record the box came from.
func light_windows(share: float, glow: float) -> void:
	for material in _materials() + _light_materials():
		material.set_shader_parameter("windows_lit", share)
		material.set_shader_parameter("window_glow", glow)
	# AND THE LAMPS, BY THE SAME SHARE: none by day, all at night, and at evening the share of night's windows evening lights.
	# Worked out from the windows' number, never typed beside it, so the two cannot disagree about when it is dark.
	for material in _lamp_materials():
		material.set_shader_parameter("lamps", lamps_for(share))


## HOW MUCH OF A LAMP'S LIGHT THE TIME OF DAY SHOWS, from the share of windows it lights: that share over night's.
static func lamps_for(share: float) -> float:
	return clampf(share / float(DaylightTuning.NIGHT["windows_lit"]), 0.0, 1.0)


## THE FOG THE ENVIRONMENT HAS, handed to the far lights and the lamps, which take it themselves: see
## town_lights.gdshaderinc. The level hands it every frame; it is written only when it changed.
func show_fog(density: float) -> void:
	if density == _fog_handed:
		return
	_fog_handed = density
	for material in _light_materials() + _lamp_materials():
		material.set_shader_parameter("fog_density", density)


## WHERE THE TOWN'S FLASH IS, handed to the lamps from the simulation's tick: `ticks` ticks of `tick_dt` seconds. The level
## hands it every frame; it is written only when it changed, which is once a tick. ONE PHASE FOR EVERY LIGHT, so a town's
## medium-intensity lights flash together (ICAO Annex 14 6.3.32), and a function of the tick alone, so two views of the
## same tick draw the same flash whenever they are drawn.
func show_flash(ticks: int, tick_dt: float) -> void:
	var phase: float = flash_phase(ticks, tick_dt)
	if phase == _flash_handed or _lamps == null:
		return
	_flash_handed = phase
	_lamps.set_shader_parameter("flash_phase", phase)


## Where in its cycle an obstruction light's flash is after `ticks` ticks of `tick_dt` seconds, 0..1.
static func flash_phase(ticks: int, tick_dt: float) -> float:
	return fposmod(float(ticks) * tick_dt * TownTuning.OBSTRUCTION_FLASHES_A_MINUTE / 60.0, 1.0)


## The lamps' material, for the tests: the same on both finishes.
func lamp_material() -> ShaderMaterial:
	return _lamps


## The street lamps' pools' material, for the tests: the same on both finishes.
func pool_material() -> ShaderMaterial:
	return _pools


## The lamps' and the pools' materials, which both take the time of day's share and the fog.
func _lamp_materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for material in [_lamps, _pools]:
		if material != null:
			out.append(material)
	return out


## Both finishes' materials, for the tests and for `light_windows`. Kept here, not read off a batch: a batch may not be
## built.
func _materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	if _plain != null:
		out.append(_plain)
	if _fine != null:
		out.append(_fine)
	return out


## Both finishes' far-light materials, PLAIN first, likewise.
func _light_materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	if _lights_plain != null:
		out.append(_lights_plain)
	if _lights_fine != null:
		out.append(_lights_fine)
	return out


## What share of windows each finish's material is lighting, for the tests: read off the materials.
func windows_lit() -> Array[float]:
	var out: Array[float] = []
	for material in _materials():
		out.append(float(material.get_shader_parameter("windows_lit")))
	return out


func wear(fine: bool) -> void:
	_fine_on = fine
	for batch in building_batches():
		batch.material_override = _fine if fine else null
	for batch in light_batches():
		batch.material_override = _lights_fine if fine else _lights_plain


## Whether every built kilometre of town, and of its far lights, is drawn with the fine material. Read off the nodes,
## never off `Finish`.
func worn() -> bool:
	var batches: Array[MultiMeshInstance3D] = building_batches()
	if batches.is_empty():
		return false
	for batch in batches:
		if batch.material_override != _fine:
			return false
	for batch in light_batches():
		if batch.material_override != _lights_fine:
			return false
	return true


## The BUILT buildings' batches, their far lights', their obstruction lights' and the paint's, one a kilometre each, for the
## tests and the probe. A kilometre of buildings is two or three nodes, told apart by the `lights` and `obstruction` metas.
func building_batches() -> Array[MultiMeshInstance3D]:
	return _of_the_buildings_layer(&"")


func light_batches() -> Array[MultiMeshInstance3D]:
	return _of_the_buildings_layer(&"lights")


func obstruction_batches() -> Array[MultiMeshInstance3D]:
	return _yard.built_batches([OBSTRUCTION]) if _yard != null else [] as Array[MultiMeshInstance3D]


## The built batches of the buildings' layer that carry the meta `kind`, or neither meta for `&""`.
func _of_the_buildings_layer(kind: StringName) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	if _yard == null:
		return out
	for batch in _yard.built_batches([BUILDINGS]):
		var lights: bool = bool(batch.get_meta(&"lights", false))
		var obstruction: bool = bool(batch.get_meta(&"obstruction", false))
		var its: StringName = &"lights" if lights else (&"obstruction" if obstruction else &"")
		if its == kind:
			out.append(batch)
	return out


## The paint's batches alone: a kilometre of streets is also its lamps', poles' and pools' batches, told apart by their metas.
func paint_batches() -> Array[MultiMeshInstance3D]:
	return _of_the_roads_layer(&"")


func street_lamp_batches() -> Array[MultiMeshInstance3D]:
	return _of_the_roads_layer(&"street_lamps")


func pole_batches() -> Array[MultiMeshInstance3D]:
	return _of_the_roads_layer(&"poles")


func pool_batches() -> Array[MultiMeshInstance3D]:
	return _of_the_roads_layer(&"pools")


## The built batches of the roads' layer that carry the meta `kind`, or none of the street lights' metas for `&""`.
func _of_the_roads_layer(kind: StringName) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	if _yard == null:
		return out
	for batch in _yard.built_batches([ROADS]):
		var its: StringName = &""
		for one in [&"street_lamps", &"poles", &"pools"]:
			if batch.has_meta(one):
				its = one
		if its == kind:
			out.append(batch)
	return out


## Every building instance drawn, as `{position, half_extents}`, from the transforms handed to the
## MultiMeshes -- for the test that holds the picture to the collision.
##
## KEPT AS THEY ARE SET, NOT READ BACK. Headless, `MultiMesh.get_instance_transform` answers from the
## dummy rendering server, which keeps no buffer: the first run of smoke's check read all 377 buildings
## back at the origin with no size. So what is recorded is the transform exactly as it went in -- after
## the per-cell filing, the offset from the batch's middle and the half-extent doubling this file does, which
## are the parts that can go wrong here -- and the simulation's own copy is asked about each one separately.
func drawn_buildings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for batch in building_batches():
		for placed in (batch.get_meta(&"placed", []) as Array):
			var at: Transform3D = batch.global_transform * (placed as Transform3D)
			out.append({"position": at.origin, "half_extents": at.basis.get_scale() * 0.5})
	return out
