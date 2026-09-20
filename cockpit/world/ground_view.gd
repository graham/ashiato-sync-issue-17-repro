extends Node3D
class_name GroundView
## THE GROUND, DRAWN: the C++ ground function's surface as a mesh a kilometre at a time, finer near the eye and coarser out
## to the far reach -- one levelled layer of the `SceneryYard`, its arrays worked out on worker threads.
##
## THE PICTURE IS THE COLLISION. A cell's vertices are the function's own samples, in the ticks of 1/32 m the height fields
## hold (`../ashiato-gd/src/cockpit/bedrock.hpp`), and at the finest level each square is split on the diagonal Box3D splits
## it on, from (x + 16, z) to (x, z + 16). So at the finest level the ground drawn is the ground an aeroplane lands on, and a
## coarser level's vertices are a subset of a finer one's: a level change moves no vertex it keeps (`tests/ground_view.gd`).
## A coarser square is split on the diagonal that follows the crest instead -- see `cell_arrays`.
##
## LEVELS, BY DISTANCE FROM THE EYE TO A CELL (report, 8c): 16 m within one cell, 32 m within three, 64 m within six, and
## 128 m out to the far reach the level hands in. No 256 m level: on a 60-degree face a 256 m triangle moves the ridge a
## pilot navigates by 900 m.
##
## A SKIRT DOWN EVERY EDGE, not stitching. Neighbouring cells drawn at different spacings open cracks along the edge they
## share. Each edge hangs a strip, drawn from both sides, as deep as the largest gap it can open against a neighbour at ANY
## other level: against a finer neighbour, the function sampled every 16 m along the edge against this cell's edge line;
## against a coarser one, this cell's edge vertices against each coarser level's line. Any level, not the next one:
## `SceneryYard` coarsens a cell only past its reach and a margin that grows with speed, so at 166 m/s a 16 m cell can
## stand beside a 64 m one. Stitching was rejected: a cell rebuilt whenever a neighbour changes level doubles the rebuilds
## at every ring crossing. Measured gaps on the alpine world run from 34.5 m (16 m against 32 m) to 431 m (128 m against
## 256 m), and the terrain probe's pictures showed no difference with skirts off, outward only or both ways.
##
## LIT A PIXEL AT A TIME, FROM A NORMAL MAP BAKED FOR EACH CELL (`shaders/ground_view.gdshader`), worked out on the worker
## with the rest of the cell. Per-vertex normals interpolated across 32 m and 64 m quads drew steep faces as vertical
## fluting (team-lead's picture point 2). The map was chosen by measured cost against the function in the fragment shader,
## which doubled the GPU time (report, 8l).
##
## A MAP AS FINE AS ITS LEVEL CAN SHOW: a texel every 16 m at the 16 m and 32 m levels (65 a side), every 32 m at 64 m (33)
## and every 64 m at 128 m (17) -- half the mesh spacing above the finest level, where a 128 m cell is past 6 km and a
## 16 m normal would be under a pixel. Each texel is the function's normal a texel either side, so a coarser map is the
## ground's light already filtered to its distance. One 65 by 65 map at every level cost a 128 m cell 5.94 ms of worker
## time on the double editor, against 0.75 ms without it.
##
## ONE HEIGHTS CALL A CELL for all of it, on a grid at the map's texel with a border: the map, the vertex normals, the mesh
## (every other sample above the finest level) and the crest middles (the samples between). The skirt's edges are the
## only other call.
##
## THE COLOUR BY THE SLOPE THE DRAWN TRIANGLES HAVE, in the vertex colours: rock where the ground as drawn is steep, not
## where the function is. The probe's 3 km pictures had pale beaded lines along the valleys, and `--rock=off` removed
## them: a slope stencil finer than the drawn spacing picked rock out of 16 m trench walls, and a coarse ring sampled the
## thin line into beads (report, 8c).
##
## WORKER RULES (`SceneryYard`): `work` reads the `GroundField`, which never changes after `configure` and which its
## binding says any thread may ask, and constants. It touches no node, and names this class for the static it calls. The
## ArrayMesh is made in `build`, on the main thread.
##
## No level stands on it yet: the level switch that draws a world on the ground is the next step.

## The yard's name for this layer.
const LAYER: String = "Ground"
const CELL: int = 1024
const TICKS_PER_METRE: float = 32.0
## Each level's spacing, metres, finest first.
const SPACINGS: Array[int] = [16, 32, 64, 128]
## How many cells from the eye each level but the last is drawn out to. The last goes to the far reach.
const CELLS_OUT: Array[int] = [1, 3, 6]
## The finest spacing, and the step a skirt's gaps are sampled at.
const FINEST: int = 16
const PAINT: Shader = preload("res://world/shaders/ground_view.gdshader")
## Samples along a cell's edge at the finest spacing.
const EDGE_SAMPLES: int = CELL / FINEST + 1
## How far past the largest gap a skirt reaches, metres.
const SKIRT_MARGIN: float = 0.5
## The spacing land cells are found at, and the height at or under which every sample of a cell is open sea: 20 m below
## the collision's -40 m (`Bedrock::kSeaFloorTicks`), since 64 m samples can miss a 16 m one the collision counts.
const FIND_SPACING: int = 64
const SEA_BELOW: float = -60.0
## Room a cell's bounds leave below its lowest sample for a skirt, and above its highest for the 16 m samples a 64 m look
## missed. Distance is measured on the ground, so these only widen a cell's visibility range.
const BOUNDS_BELOW: float = 500.0
const BOUNDS_ABOVE: float = 120.0

## HOW FAR INLAND, IN VERTEX SAMPLES, A POINT MAY BE FROM STANDING WATER AND STILL BE ITS BANK. Two, because the ground
## function's rim holds the land above a lake's level for about 90 m and the finest spacing is 16 m: at one sample the
## beach stopped inside the rim and read as a stripe, and at three the coarse levels painted sand over ground that is
## nowhere near a shore. How high the band reaches is the height test in `ground_colour`; this only says how far.
const WATER_REACH: int = 2

## The colours, from the terrain probe's plain shader, held still.
const GRASS := Color(0.26, 0.345, 0.18)
const MEADOW := Color(0.43, 0.425, 0.315)
const SCREE := Color(0.50, 0.47, 0.41)
const ROCK := Color(0.40, 0.38, 0.35)
const SNOW := Color(0.92, 0.93, 0.96)
const SAND := Color(0.62, 0.57, 0.42)

## Vector2i -> AABB, every cell drawn.
var _bounds: Dictionary = {}
## THE FLOOR UNDER THE WOODS (increment B4): the forest floor's uniforms, set on every cell's material as the cell is built,
## so a cell built after the woods grew -- streamed in as the eye moves, or at a new view distance -- carries it too.
##
## EACH CELL CARRIES ONLY THE WOODS THAT TOUCH IT (team-lead, 2026-09-15): `forest_count` and that many rectangles at the
## front of the arrays. Timed at 4K PLAIN, the eight alpine woods cost about +0.11 ms over the ground whatever their trees
## (7,203 or 1,865) or draws (236 or 69), two woods +0.04 and four +0.06: the cost was every ground pixel looping over every
## wood's rectangle, and with the floor left off the eight cost +0.02 to +0.04, the island's own. A pixel is painted only inside a
## rectangle and every rectangle touching its cell is in the list, so a touching cell paints what it did.
var _floor: Dictionary = {}


## LAY THE GROUND INTO `yard`: every cell of `field`'s square with a sample above `SEA_BELOW`, as one levelled layer out to
## `far` metres. Returns how many cells there are.
func show_ground(field: Object, yard: SceneryYard, far: float) -> int:
	var half: int = int((field.call("tuning") as Dictionary)["world_half"])
	var cells: int = 2 * ((half + CELL - 1) / CELL)
	var samples: int = CELL / FIND_SPACING + 1
	for row in range(cells):
		for column in range(cells):
			var cell := Vector2i(column - cells / 2, row - cells / 2)
			var heights: PackedInt32Array = field.call("heights", cell.x * CELL, cell.y * CELL, samples, samples,
				FIND_SPACING)
			heights.sort()
			var low: float = float(heights[0]) / TICKS_PER_METRE
			var high: float = float(heights[heights.size() - 1]) / TICKS_PER_METRE
			if high <= SEA_BELOW:
				continue
			_bounds[cell] = AABB(Vector3(float(cell.x * CELL), low - BOUNDS_BELOW, float(cell.y * CELL)),
				Vector3(float(CELL), high - low + BOUNDS_BELOW + BOUNDS_ABOVE, float(CELL)))
	var reaches: Array[float] = []
	for out in CELLS_OUT:
		reaches.append(float(out * CELL))
	reaches.append(maxf(far, reaches[reaches.size() - 1] + float(CELL)))
	var bounds: Dictionary = _bounds
	yard.add_level_layer(LAYER, bounds, reaches, self,
		func(cell: Vector2i, level: int) -> Dictionary:
			return GroundView.cell_arrays(field, cell, level),
		func(cell: Vector2i, level: int, done: Dictionary) -> Array[Node3D]:
			var out: Array[Node3D] = [_cell_node(cell, level, done, far)]
			return out)
	return _bounds.size()


## LAY THE FLOOR UNDER THE WOODS: `values` is `Woodland.floor_values`; every cell already built takes it now, and every cell
## built from here on as it is built.
func lay_the_floor(values: Dictionary) -> void:
	_floor = values
	for node in get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).material_override is ShaderMaterial and node.has_meta(&"cell"):
			var paint: ShaderMaterial = (node as MeshInstance3D).material_override
			var floor: Dictionary = floor_for_cell(values, node.get_meta(&"cell"))
			for key in floor:
				paint.set_shader_parameter(key, floor[key])


## THE FLOOR ONE CELL CARRIES: `values` with `forest_count` the number of its rectangles that touch `cell`'s square, those
## rectangles packed at the front of `forest_frame` and `forest_half` in their order, and the rest zero. Static and pure.
static func floor_for_cell(values: Dictionary, cell: Vector2i) -> Dictionary:
	if values.is_empty():
		return values
	var out: Dictionary = values.duplicate()
	var frames: Array = values["forest_frame"]
	var halves: Array = values["forest_half"]
	# THE PAINT'S REACH PAST A RECTANGLE (team-lead): forest_floor.gdshaderinc paints nothing outside a rectangle but FINE's
	# ragged edge, which wanders out by up to `floor_ragged`; the generated ground's cells are drawn without FINE and set
	# PLAIN's numbers, which have no `floor_ragged`, so the margin is 0 here -- asked of the values, never typed.
	var margin: float = float(values.get("floor_ragged", 0.0))
	var kept_frames: Array = []
	var kept_halves: Array = []
	for i in range(int(values["forest_count"])):
		if rectangle_touches_cell(frames[i], halves[i], cell, margin):
			kept_frames.append(frames[i])
			kept_halves.append(halves[i])
	out["forest_count"] = kept_frames.size()
	while kept_frames.size() < frames.size():
		kept_frames.append(Vector4.ZERO)
		kept_halves.append(Vector4.ZERO)
	out["forest_frame"] = kept_frames
	out["forest_half"] = kept_halves
	return out


## WHETHER A FLOOR RECTANGLE -- `frame` (centre x, centre z, across x, across z) and `half` (half across, half along) as the
## floor shader reads them -- overlaps a cell's CELL-metre square, by separating axes: the square's two and the rectangle's two.
## `margin` grows the rectangle on every side by the paint's reach past it.
static func rectangle_touches_cell(frame: Vector4, half: Vector4, cell: Vector2i, margin: float = 0.0) -> bool:
	var centre := Vector2(frame.x, frame.y)
	var across := Vector2(frame.z, frame.w)
	var along := Vector2(across.y, -across.x)
	var corner := Vector2(float(cell.x * CELL), float(cell.y * CELL))
	var middle: Vector2 = corner + Vector2.ONE * float(CELL) * 0.5
	var to: Vector2 = centre - middle
	half = Vector4(half.x + margin, half.y + margin, half.z, half.w)
	var reach_x: float = absf(across.x) * half.x + absf(along.x) * half.y
	var reach_z: float = absf(across.y) * half.x + absf(along.y) * half.y
	if absf(to.x) > float(CELL) * 0.5 + reach_x or absf(to.y) > float(CELL) * 0.5 + reach_z:
		return false
	var square_on_across: float = (absf(across.x) + absf(across.y)) * float(CELL) * 0.5
	var square_on_along: float = (absf(along.x) + absf(along.y)) * float(CELL) * 0.5
	return absf(to.dot(across)) <= half.x + square_on_across and absf(to.dot(along)) <= half.y + square_on_along


## The normal map's texel at a level, metres: the finest spacing at the finest level, half the mesh spacing above it.
static func texel_metres(level: int) -> int:
	return FINEST if level == 0 else SPACINGS[level] / 2


## ONE CELL'S GROUND AT A LEVEL, as the arrays a mesh is made from: `vertices` in the cell's own frame (the n by n grid
## first, row by row along z, then a skirt of n vertices down each edge), `normals`, `colors`, `indices`, `skirt`, the
## depth every skirt hangs, `normal_map`, RGB8 bytes, and `texels`, the map's side.
## On a worker: see the rules at the top.
static func cell_arrays(field: Object, cell: Vector2i, level: int) -> Dictionary:
	if SceneryYard.work_delay_msec > 0:
		OS.delay_msec(SceneryYard.work_delay_msec)
	var spacing: int = SPACINGS[level]
	var n: int = CELL / spacing + 1
	var w: int = n + 2
	var x0: int = cell.x * CELL
	var z0: int = cell.y * CELL
	# ONE GRID AT THE MAP'S TEXEL, with a border of one texel at the finest level and two above it, in one call. Above the
	# finest level a texel is half the mesh spacing, so the mesh's grid -- itself with a border of one sample, for the
	# slope at the edges -- is every other sample, and a square's middle is the sample between.
	var texel: int = texel_metres(level)
	var texels: int = CELL / texel + 1
	var pad: int = 1 if level == 0 else 2
	var m: int = texels + 2 * pad
	var fine: PackedInt32Array = field.call("heights", x0 - pad * texel, z0 - pad * texel, m, m, texel)
	var grid: PackedInt32Array = fine
	if level > 0:
		grid = PackedInt32Array()
		grid.resize(w * w)
		for a in range(w):
			for b in range(w):
				grid[a * w + b] = fine[2 * a * m + 2 * b]
	var step: int = spacing / texel
	# THE EDGES AT THE FINEST SPACING, for the skirt: z = 0 and z = CELL along x, then x = 0 and x = CELL along z.
	var edge_points := PackedInt32Array()
	edge_points.resize(4 * EDGE_SAMPLES * 2)
	for f in range(EDGE_SAMPLES):
		var along: int = f * FINEST
		for e in range(4):
			var at: int = (e * EDGE_SAMPLES + f) * 2
			edge_points[at] = x0 + (along if e < 2 else (0 if e == 2 else CELL))
			edge_points[at + 1] = z0 + (along if e >= 2 else (0 if e == 0 else CELL))
	var edges: PackedInt32Array = field.call("heights_at", edge_points)
	var skirt_ticks: float = 0.0
	var per: int = spacing / FINEST
	for e in range(4):
		var base: int = e * EDGE_SAMPLES
		for f in range(EDGE_SAMPLES):
			var h: float = float(edges[base + f])
			# AGAINST A FINER NEIGHBOUR: the function here against this cell's own edge line.
			var k: int = mini(f / per, n - 2)
			var line: float = lerpf(float(edges[base + k * per]), float(edges[base + (k + 1) * per]),
				float(f - k * per) / float(per))
			skirt_ticks = maxf(skirt_ticks, absf(h - line))
			# AGAINST A COARSER NEIGHBOUR AT ANY LEVEL: this cell's edge vertex against that level's line.
			if f % per != 0:
				continue
			for coarser in SPACINGS:
				if coarser <= spacing:
					continue
				var cp: int = coarser / FINEST
				var ck: int = mini(f / cp, CELL / coarser - 1)
				var coarse_line: float = lerpf(float(edges[base + ck * cp]), float(edges[base + (ck + 1) * cp]),
					float(f - ck * cp) / float(cp))
				skirt_ticks = maxf(skirt_ticks, absf(h - coarse_line))
	var skirt: float = skirt_ticks / TICKS_PER_METRE + SKIRT_MARGIN

	# THE STANDING WATER OVER THIS CELL'S OWN VERTEX GRID, for the shore. `waters_at` answers only where water actually
	# stands, so a vertex ON the bank has none; the level wanted is the level of the water it is the bank OF. So the
	# answers are spread `WATER_REACH` samples inland, and a vertex with no water near it is given the sea's 0, which is
	# what every vertex was measured against before there was a shore at all -- so nothing away from a lake moves.
	var water_points := PackedInt32Array()
	water_points.resize(n * n * 2)
	for j in range(n):
		for i in range(n):
			var wp: int = (j * n + i) * 2
			water_points[wp] = x0 + i * spacing
			water_points[wp + 1] = z0 + j * spacing
	var standing: PackedInt32Array = field.call("waters_at", water_points)
	var no_water: int = ClassDB.class_get_integer_constant("GroundField", "NO_WATER")
	var near_water := PackedFloat32Array()
	near_water.resize(n * n)
	var any_water: bool = false
	for k in range(n * n):
		if standing[k] > no_water:
			any_water = true
			break
	# A CELL WITH NO WATER IN IT AT ALL needs none of this, and that is nearly every cell in the world: the spread below
	# is skipped and every vertex takes the sea's 0, which is the number the sand band was measured against before.
	if any_water:
		# SPREAD ALONG X, THEN ALONG Z. The same answer as a square window and (2r + 1) reads a vertex instead of
		# (2r + 1) squared -- this runs on the scenery's worker threads for every cell that touches a lake.
		var along := PackedInt32Array()
		along.resize(n * n)
		for j in range(n):
			for i in range(n):
				var best: int = no_water
				for di in range(maxi(i - WATER_REACH, 0), mini(i + WATER_REACH + 1, n)):
					best = maxi(best, standing[j * n + di])
				along[j * n + i] = best
		for j in range(n):
			for i in range(n):
				var best: int = no_water
				for dj in range(maxi(j - WATER_REACH, 0), mini(j + WATER_REACH + 1, n)):
					best = maxi(best, along[dj * n + i])
				near_water[j * n + i] = 0.0 if best <= no_water else float(best) / TICKS_PER_METRE

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(n * n + 4 * n)
	normals.resize(n * n + 4 * n)
	colors.resize(n * n + 4 * n)
	for j in range(n):
		for i in range(n):
			var v: int = j * n + i
			var height: float = float(grid[(j + 1) * w + i + 1]) / TICKS_PER_METRE
			vertices[v] = Vector3(float(i * spacing), height, float(j * spacing))
			var at: int = (j * step + pad) * m + i * step + pad
			var sx: float = float(fine[at + 1] - fine[at - 1])
			var sz: float = float(fine[at + m] - fine[at - m])
			normals[v] = Vector3(-sx / TICKS_PER_METRE, 2.0 * texel, -sz / TICKS_PER_METRE).normalized()
			# THE SLOPE AS DRAWN: the neighbours at this level's own spacing.
			var dx: float = float(grid[(j + 1) * w + i + 2] - grid[(j + 1) * w + i]) / TICKS_PER_METRE
			var dz: float = float(grid[(j + 2) * w + i + 1] - grid[j * w + i + 1]) / TICKS_PER_METRE
			var steep: float = 1.0 - Vector3(-dx, 2.0 * spacing, -dz).normalized().y
			colors[v] = ground_colour(height, steep, near_water[v])
	# THE NORMAL MAP: the function's normal a texel either side of every texel, as bytes -- the texture is made on the main
	# thread.
	var normal_map := PackedByteArray()
	normal_map.resize(texels * texels * 3)
	for tj in range(texels):
		for ti in range(texels):
			var at: int = (tj + pad) * m + ti + pad
			var up := Vector3(-float(fine[at + 1] - fine[at - 1]) / TICKS_PER_METRE, 2.0 * texel,
				-float(fine[at + m] - fine[at - m]) / TICKS_PER_METRE).normalized()
			var k: int = (tj * texels + ti) * 3
			normal_map[k] = int(round((up.x * 0.5 + 0.5) * 255.0))
			normal_map[k + 1] = int(round((up.y * 0.5 + 0.5) * 255.0))
			normal_map[k + 2] = int(round((up.z * 0.5 + 0.5) * 255.0))
	# THE DIAGONAL THAT FOLLOWS THE CREST, above the finest level. The finest level is the collision's own triangles and
	# keeps Box3D's diagonal. A coarser square split on that one fixed diagonal cut a crest lying across it into
	# alternating triangles, a sawtooth along every ridge (team-lead's picture point 1, `crest_far_levels.png`). So each
	# coarser square is split on the diagonal whose middle is nearer the ground's own height at the square's middle:
	# along a crest that is the crest, and in a valley its floor. A tie keeps Box3D's.
	for j in range(n - 1):
		for i in range(n - 1):
			var a: int = j * n + i
			if level > 0:
				var middle: int = 2 * fine[(2 * j + 3) * m + 2 * i + 3]
				var boxs: int = absi(grid[(j + 1) * w + i + 2] + grid[(j + 2) * w + i + 1] - middle)
				var other: int = absi(grid[(j + 1) * w + i + 1] + grid[(j + 2) * w + i + 2] - middle)
				if other < boxs:
					# The other diagonal, (a, a + n + 1), wound as Box3D's is.
					indices.append_array([a, a + 1, a + n + 1, a, a + n + 1, a + n])
					continue
			# Box3D's square is (a, a + n, a + 1) and (a + n + 1, a + 1, a + n) anticlockwise from above; Godot's front faces
			# are clockwise.
			indices.append_array([a, a + 1, a + n, a + n + 1, a + n, a + 1])
	# THE SKIRTS, in the probe's edge order: z = 0 along x, z = CELL along x, x = 0 along z, x = CELL along z.
	var sides: Array = [[0, 0, 1, 0], [0, n - 1, 1, 0], [0, 0, 0, 1], [n - 1, 0, 0, 1]]
	for e in range(4):
		var side: Array = sides[e]
		var first: int = n * n + e * n
		for k in range(n):
			var top: int = (int(side[1]) + int(side[3]) * k) * n + int(side[0]) + int(side[2]) * k
			vertices[first + k] = vertices[top] - Vector3(0.0, skirt, 0.0)
			normals[first + k] = normals[top]
			colors[first + k] = colors[top]
		for k in range(n - 1):
			var t0: int = (int(side[1]) + int(side[3]) * k) * n + int(side[0]) + int(side[2]) * k
			var t1: int = (int(side[1]) + int(side[3]) * (k + 1)) * n + int(side[0]) + int(side[2]) * (k + 1)
			# BOTH WINDINGS: a skirt is seen from whichever side the crack is on.
			indices.append_array([t0, t1, first + k, t1, first + k + 1, first + k])
			indices.append_array([t0, first + k, t1, t1, first + k, first + k + 1])
	return {"vertices": vertices, "normals": normals, "colors": colors, "indices": indices, "skirt": skirt,
		"normal_map": normal_map, "texels": texels}


## THE GROUND'S COLOUR at a height and a steepness (1 less the drawn normal's y), after the probe's plain shader.
## `water` is the level of the water this point is the bank of, metres, and 0 -- the sea's -- where there is none near.
##
## THE SHORE IS MEASURED FROM ITS OWN WATER, NOT FROM SEA LEVEL (lane/rivers, 2026-09-20). The sand band used to be
## `smoothstep(1.5, 5.0, height)` against absolute height, which is the sea's level written as a number. Every lake the
## ground function makes stands between 13 and 126 m (`tests/rivers_survey.gd`), so NOT ONE OF THEM HAD A SHORE: grass
## ran into the water along a hard line, which is what the user meant by "near these the ground and water should look
## different on the shore". Against `height - water` the same two numbers give the sea exactly the beach it had --
## `water` is 0 out there -- and give every lake the same beach at its own level.
##
## THE HEIGHT BANDS ABOVE IT ARE STILL ABSOLUTE, and should be: meadow, scree and snow are about altitude, not about
## how far you are above the nearest puddle.
static func ground_colour(height: float, steep: float, water: float = 0.0) -> Color:
	var colour: Color = GRASS.lerp(MEADOW, smoothstep(450.0, 900.0, height) * 0.7)
	colour = colour.lerp(SCREE, smoothstep(1700.0, 2200.0, height) * 0.6)
	var rock: float = smoothstep(0.16, 0.34, steep)
	colour = colour.lerp(ROCK, rock)
	colour = colour.lerp(SNOW, smoothstep(2200.0, 2500.0, height) * (1.0 - smoothstep(0.22, 0.42, steep)))
	return colour.lerp(SAND, (1.0 - smoothstep(1.5, 5.0, height - water)) * (1.0 - rock))


## ONE CELL'S NODE, on the main thread, from the arrays its work made.
func _cell_node(cell: Vector2i, level: int, done: Dictionary, far: float) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = done["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = done["normals"]
	arrays[Mesh.ARRAY_COLOR] = done["colors"]
	arrays[Mesh.ARRAY_INDEX] = done["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = "Ground_%d_%d" % [cell.x, cell.y]
	node.mesh = mesh
	# THE MAP'S TEXTURE AND THE CELL'S OWN MATERIAL, here on the main thread: a worker hands in the bytes.
	var texels: int = done["texels"]
	var paint := ShaderMaterial.new()
	paint.shader = PAINT
	paint.set_shader_parameter("normal_map", ImageTexture.create_from_image(Image.create_from_data(texels, texels, false,
		Image.FORMAT_RGB8, done["normal_map"])))
	paint.set_shader_parameter("texels", float(texels))
	paint.set_shader_parameter("texel_metres", float(texel_metres(level)))
	var floor: Dictionary = floor_for_cell(_floor, cell)
	for key in floor:
		paint.set_shader_parameter(key, floor[key])
	node.material_override = paint
	node.position = Vector3(float(cell.x * CELL), 0.0, float(cell.y * CELL))
	node.visibility_range_end = SceneryYard.range_for(_bounds[cell], far)
	node.set_meta(&"cell", cell)
	node.set_meta(&"level", level)
	return node
