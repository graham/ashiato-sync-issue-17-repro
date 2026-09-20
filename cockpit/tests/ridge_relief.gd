extends Node
## Headless: THE ISLAND'S ROCK AS PICTURES, WITHOUT A RENDERING DEVICE -- a shaded relief from above, and the skyline from
## each quarter of the compass.
##
##   Godot --headless --path cockpit res://tests/ridge_relief.tscn -- --out=C:/somewhere --step=32
##
## WHY IT EXISTS. Judging a change to the mountains means looking at them, and a windowed run wants the GPU slot, a level
## to stand up and a minute of wall clock. This asks the library for heights and draws them itself, so a change to the
## generator can be looked at in a few seconds, as often as it takes, while somebody else holds the machine. It is not a
## replacement for the in-game pictures -- it has no shader, no haze and no sky, and `seeing_the_game.md`'s rule stands:
## the real picture decides. It is the fast loop that gets a change ready to be photographed.
##
## THE RELIEF is a hillshade: the surface sampled on a square grid, lit from the north-west at forty-five degrees, with the
## height laid under it as a tint. Gullies, spurs, shoulders and the shape of a foot all read in it.
##
## THE SKYLINE is what the lane was asked about. From each of four bearings the rock is projected on a vertical plane --
## for every column across the view, the highest rock behind it -- which is the silhouette a pilot sees from the runway or
## from out at sea, with no perspective to argue about. A range of one character shows as an even band; a range with a
## massif in it and hills beside it shows as a line that rises and falls. The evenness is printed as a number too: the
## spread of the skyline's height divided by its mean, over the columns that have rock in them.
##
## Every height is the library's own `surfaces_at`, asked a row at a time.
##
## Read RESULT=, not the exit code.

## How far out the island is sampled, metres either side of the middle, and how far apart the samples are by default.
## `--reach=` and `--centre=x,z` move and shrink the window, so one range can be looked at closely -- at 8 m over 1,500 m
## a single spur and the gullies either side of it fill the picture, which is where the plan form is actually judged.
const REACH: float = 7200.0
const STEP_DEFAULT: float = 32.0
## The bearings the skyline is taken from, degrees from +x towards +z, and how tall a skyline picture is in pixels.
const SKYLINE_FROM: Array[float] = [0.0, 45.0, 90.0, 135.0]
const SKYLINE_TALL: int = 220
## The sun the relief is lit by: from the north-west, forty-five degrees up.
const SUN_BEARING: float = 135.0
const SUN_HEIGHT: float = 45.0

var _out: String = "user://relief"
var _step: float = STEP_DEFAULT
var _label: String = "island"
var _reach: float = REACH
var _centre := Vector2.ZERO
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ridge_relief] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"out":
				_out = parts[1]
			"step":
				_step = maxf(float(parts[1]), 4.0)
			"label":
				_label = parts[1]
			"reach":
				_reach = maxf(float(parts[1]), 100.0)
			"centre":
				var two: PackedStringArray = parts[1].split(",", false)
				if two.size() == 2:
					_centre = Vector2(float(two[0]), float(two[1]))
	if not ClassDB.class_exists(&"MountainRange"):
		_check("the_extension_has_mountains", false, "no MountainRange")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var island: Object = Terrain.mountains()
	_check("the_island_is_configured", bool(island.call("is_configured")), str(island.call("report")))
	var began: int = Time.get_ticks_usec()
	var heights: Array[PackedFloat32Array] = _sample(island)
	print("[ridge_relief] %d by %d samples %.0f m apart, in %.0f ms; %s" % [heights.size(), heights[0].size(), _step,
		float(Time.get_ticks_usec() - began) / 1000.0, island.call("report")])
	_draw_the_relief(heights)
	for bearing in SKYLINE_FROM:
		_draw_the_skyline(heights, bearing)
	if is_equal_approx(_reach, REACH) and _centre.is_zero_approx():
		_what_a_change_to_the_data_can_break()
	_finish()


## THE THREE THINGS THE RANGES' NUMBERS OWE THE REST OF THE ISLAND, PRINTED so a change to `MountainRanges` can be
## judged against them in the fast loop rather than at the gate. Printed and not checked: `smoke` holds the passes and
## `forest` the room inside the ring, and a probe that gave a second verdict on either would be a second place to
## change when the real one moved.
##
## THE PASSES: the ring is a ring you fly THROUGH, and at fourteen boxes a side the old one closed into a fence, so
## `smoke` holds the tightest way through it. THE ROOM INSIDE: the woods and the car pool are kept within
## `MountainRanges.ring_inside()`, so a foot that reaches further in takes ground off them. AND THE TALLEST PEAK, which
## sets how far a keep-out's talus has to be looked for (`range_core.cpp`).
func _what_a_change_to_the_data_can_break() -> void:
	# PRINTED, NOT JUDGED. `smoke` owns the verdict on the passes and `forest` on the room inside the ring; a second
	# opinion here would be a second place to change when the real one moved, and this file is a probe.
	var gaps: Vector2 = Terrain.ring_gaps()
	print("[ridge_relief] the ring's tightest pass is %.0f m and its widest %.0f m (smoke wants over 120)" % [gaps.x,
		gaps.y])
	print("[ridge_relief] the rock can reach %.0f m from the middle; the woods and the car pool stay inside that"
		% MountainRanges.ring_inside())
	var tallest: int = 0
	var counted: int = 0
	for one in MountainRanges.ranges():
		tallest = maxi(tallest, int(one["peak"]))
		counted += 1
	print("[ridge_relief] %d ranges, tallest envelope %d m" % [counted, tallest])


func _finish() -> void:
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## THE SURFACE ON A GRID, row by row along z: `heights[j][i]` is the rock at (x0 + i*step, z0 + j*step), metres, 0 for none.
func _sample(island: Object) -> Array[PackedFloat32Array]:
	var side: int = int(_reach * 2.0 / _step) + 1
	var out: Array[PackedFloat32Array] = []
	for j in range(side):
		var row := PackedVector2Array()
		row.resize(side)
		var z: float = _centre.y - _reach + float(j) * _step
		for i in range(side):
			row[i] = Vector2(_centre.x - _reach + float(i) * _step, z)
		out.append(island.call("surfaces_at", row))
	return out


## Where grid column `i`, row `j` stands in the world, metres.
func _world_at(i: int, j: int) -> Vector2:
	return Vector2(_centre.x - _reach + float(i) * _step, _centre.y - _reach + float(j) * _step)


## ---- the relief from above ------------------------------------------------------------------------------------------

func _draw_the_relief(heights: Array[PackedFloat32Array]) -> void:
	var side: int = heights.size()
	var tallest: float = 0.0
	for row in heights:
		for h in row:
			tallest = maxf(tallest, h)
	var picture := Image.create(side, side, false, Image.FORMAT_RGB8)
	var sun := Vector3(cos(deg_to_rad(SUN_BEARING)) * cos(deg_to_rad(SUN_HEIGHT)), sin(deg_to_rad(SUN_HEIGHT)),
		sin(deg_to_rad(SUN_BEARING)) * cos(deg_to_rad(SUN_HEIGHT))).normalized()
	for j in range(side):
		for i in range(side):
			var here: float = heights[j][i]
			if here <= 0.0:
				# THE SEA AND THE PLAIN, so the foot of a range reads against them.
				picture.set_pixel(i, j, Color(0.36, 0.44, 0.31))
				continue
			# THE NORMAL from the neighbours, at the grid's own spacing.
			var east: float = heights[j][mini(i + 1, side - 1)]
			var west: float = heights[j][maxi(i - 1, 0)]
			var south: float = heights[mini(j + 1, side - 1)][i]
			var north: float = heights[maxi(j - 1, 0)][i]
			var normal := Vector3(west - east, 2.0 * _step, north - south).normalized()
			var light: float = clampf(normal.dot(sun), 0.0, 1.0)
			# The height as a tint under the light: dark rock low, pale high, so both the shading and the massing read.
			var up: float = clampf(here / maxf(tallest, 1.0), 0.0, 1.0)
			var tone: float = 0.18 + 0.82 * light
			picture.set_pixel(i, j, Color(tone * (0.42 + 0.58 * up), tone * (0.40 + 0.56 * up), tone * (0.38 + 0.60 * up)))
	var path: String = "%s/%s-relief.png" % [_out, _label]
	_check("wrote_the_relief", picture.save_png(path) == OK,
		"%s, %.0f m either side of %v at %.0f m a pixel, tallest %.0f m" % [path, _reach, _centre, _step, tallest])


## ---- the skyline from a bearing --------------------------------------------------------------------------------------

## THE SILHOUETTE FROM `bearing`: the rock projected on a vertical plane square to it -- for every column across the view,
## the highest rock anywhere behind that column. No perspective, so two ranges at different distances are compared by
## their true heights, which is what "one even band" means.
func _draw_the_skyline(heights: Array[PackedFloat32Array], bearing: float) -> void:
	var side: int = heights.size()
	var look := Vector2(cos(deg_to_rad(bearing)), sin(deg_to_rad(bearing)))
	var across := Vector2(-look.y, look.x)
	var columns := PackedFloat32Array()
	columns.resize(side)
	for j in range(side):
		for i in range(side):
			var here: float = heights[j][i]
			if here <= 0.0:
				continue
			var at: Vector2 = _world_at(i, j) - _centre
			# WHICH COLUMN: how far across the view the point lies, over the same span the grid covers.
			var column: int = clampi(int((at.dot(across) + _reach) / _step), 0, side - 1)
			columns[column] = maxf(columns[column], here)
	var tallest: float = 0.0
	for c in columns:
		tallest = maxf(tallest, c)
	var picture := Image.create(side, SKYLINE_TALL, false, Image.FORMAT_RGB8)
	picture.fill(Color(0.62, 0.70, 0.82))
	for x in range(side):
		var top: int = SKYLINE_TALL - 1 - int(columns[x] / maxf(tallest, 1.0) * float(SKYLINE_TALL - 12))
		for y in range(top, SKYLINE_TALL):
			picture.set_pixel(x, y, Color(0.30, 0.31, 0.34))
	var path: String = "%s/%s-skyline-%03d.png" % [_out, _label, int(bearing)]
	# HOW EVEN THE SKYLINE IS: the spread of the standing rock's height over its mean. A band of one height reads low.
	var standing := PackedFloat32Array()
	for c in columns:
		if c > 1.0:
			standing.append(c)
	var mean: float = 0.0
	for c in standing:
		mean += c
	mean /= maxf(float(standing.size()), 1.0)
	var spread: float = 0.0
	for c in standing:
		spread += (c - mean) * (c - mean)
	spread = sqrt(spread / maxf(float(standing.size()), 1.0))
	_check("wrote_the_skyline_%03d" % int(bearing), picture.save_png(path) == OK,
		"%s; %d columns with rock, mean %.0f m, tallest %.0f m, evenness %.3f" % [path, standing.size(), mean, tallest,
			spread / maxf(mean, 1.0)])
