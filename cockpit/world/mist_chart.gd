extends RefCounted
class_name MistChart
## A CHART OF THE GROUND THE MIST LIES ON, ROUND THE EYE: one float texel a `MistTuning.CHART_SPAN` / `CHART_TEXELS` square, the
## height of the ground or the water under its middle, which `world/shaders/mist.gdshaderinc` reads to lay the haze and the
## stratus over the ground rather than over a number.
##
## THE GROUND IS ASKED, NEVER TYPED. `bake` is handed the function that answers "how high is what lies under this grid" -- the
## level hands it `Terrain.surface_heights`, cockpit-terrain's bulk form of `surface_height` (texel centres, rows along z, one
## call to the generated ground rather than one a texel) -- so a chart is whatever the world says, and tests/mist.gd can hand it
## a slope and see the slope come back.
##
## STATIC AND PURE, SO IT RUNS ON A WORKER. It reads the function it is given and writes an Image it made; nothing the main
## thread owns (the rule `SceneryYard` keeps). `MistLayer` starts it on a `WorkerThreadPool` task and uploads what it finished.

## Where a chart round an eye is centred: the eye snapped to `CHART_RECENTRE`, so the chart moves in steps, never with every
## metre flown, and an eye is always at least half a span less a step from its edge.
static func middle_for(eye: Vector3) -> Vector3:
	return Vector3(snappedf(eye.x, MistTuning.CHART_RECENTRE), 0.0, snappedf(eye.z, MistTuning.CHART_RECENTRE))


## ONE CHART: {"image": an Image of FORMAT_RGF, red the height and green the RELIEF (below), "frame": Vector4(least x, least z,
## span, 0), "ground_range": Vector2(lowest, highest), "relief_range": Vector2(lowest, highest), "middle", "thread": the thread
## it was baked on}. `heights` is `Terrain.surface_heights`' shape: (corner: Vector2, texels: int, spacing: float) ->
## PackedFloat32Array, sample (i, j) at the texel's centre, index j * texels + i.
##
## EVERY CHART IS RGF, THE FIRST INCLUDED: MistLayer creates the texture from the first and `update`s it with every later one, and
## an update refuses a change of format.
static func bake(middle: Vector3, span: float, texels: int, heights: Callable) -> Dictionary:
	var least := Vector2(middle.x - span * 0.5, middle.z - span * 0.5)
	var grid: PackedFloat32Array = heights.call(least, texels, span / float(texels))
	var lowest: float = INF
	var highest: float = -INF
	for ground in grid:
		lowest = minf(lowest, ground)
		highest = maxf(highest, ground)
	var relief: PackedFloat32Array = relief_of(grid, texels, MistTuning.RELIEF_TEXELS)
	var both := PackedFloat32Array()
	both.resize(grid.size() * 2)
	var least_relief: float = INF
	var most_relief: float = -INF
	for k in range(grid.size()):
		both[2 * k] = grid[k]
		both[2 * k + 1] = relief[k]
		least_relief = minf(least_relief, relief[k])
		most_relief = maxf(most_relief, relief[k])
	var image := Image.create_from_data(texels, texels, false, Image.FORMAT_RGF, both.to_byte_array())
	return {"image": image, "frame": Vector4(least.x, least.y, span, 0.0), "ground_range": Vector2(lowest, highest),
		"relief_range": Vector2(least_relief, most_relief), "middle": middle, "thread": OS.get_thread_caller_id()}


## THE RELIEF OF A GRID OF HEIGHTS: each texel's height less the heights round it, blurred -- below zero on a valley floor or in a
## bowl, above on a ridge or a summit, zero on any flat or steady slope. The blur is a box `radius` texels each way, along the
## rows and then the columns, twice over (close to a Gaussian); a texel past the edge is the edge's own, so a flat edge stays
## flat. Running sums, so a 128-texel chart is a few passes of 16,384 adds on the worker. Static and pure.
static func relief_of(grid: PackedFloat32Array, texels: int, radius: int) -> PackedFloat32Array:
	var blurred: PackedFloat32Array = grid
	for pass_index in range(2):
		blurred = _box(_box(blurred, texels, radius, true), texels, radius, false)
	var out := PackedFloat32Array()
	out.resize(grid.size())
	for k in range(grid.size()):
		out[k] = grid[k] - blurred[k]
	return out


## ONE BOX BLUR along the rows (`along_rows`) or the columns, `radius` texels each way, edges clamped.
static func _box(grid: PackedFloat32Array, texels: int, radius: int, along_rows: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(grid.size())
	var width: float = float(2 * radius + 1)
	for line in range(texels):
		var sum: float = 0.0
		for k in range(-radius, radius + 1):
			sum += grid[_index(line, clampi(k, 0, texels - 1), texels, along_rows)]
		for i in range(texels):
			out[_index(line, i, texels, along_rows)] = sum / width
			sum += grid[_index(line, clampi(i + radius + 1, 0, texels - 1), texels, along_rows)]
			sum -= grid[_index(line, clampi(i - radius, 0, texels - 1), texels, along_rows)]
	return out


static func _index(line: int, i: int, texels: int, along_rows: bool) -> int:
	return line * texels + i if along_rows else i * texels + line
