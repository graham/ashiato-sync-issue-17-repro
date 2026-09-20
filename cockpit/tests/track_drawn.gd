extends Node
## THE TRACK AS IT IS DRAWN ON THE ISLAND, against the standards it is built to. Headless. Read RESULT=, not the exit code.
##
## WHY THIS EXISTS. On 2026-09-19 the user said "the tracks also seem to be not aligned correctly", and they were not, five
## ways at once (`PermanentWay`'s doc block): the rails drawn in dashes because `Basis.scaled` stretched each one along the
## world's z instead of its own, the wheels 16 cm down inside the rails, 3.6 m slab ties every 12 m, the railway floating
## 3 m over the grass on nothing, and the rails 3.5 cm inside standard gauge. **Every suite was green through all five**,
## because nothing had ever read the drawn railway back: the one test of the railway layer (`scenery_yard`) counted pieces
## and asked where their middles were, and a piece stretched the wrong way has its middle in the right place.
##
## WHAT IT HOLDS, and against what. Every figure is TYPED HERE from the standard it comes from, never read off
## `PermanentWay` -- a check that asks the code for the number it checks cannot catch that number being wrong. Every
## measurement is taken off the DRAWN instances, vertex by vertex through their own transforms, in the frame of the
## WAYPOINTS (`Terrain.rail_points`), which are what the train rides and so what the track must agree with. Nothing is
## measured along the drawn basis, which is the thing that was wrong.
##
##   1. the rails: each length runs from one waypoint to the next and no further, its head on the waypoints' line, and
##      the gauge between the two heads' inside faces is standard gauge to 2 mm -- at the sharpest bend on the loop;
##   2. the ties: 8 ft 6 in by 9 in, at 19 1/2 in centres, and the rails' feet standing on them;
##   3. the bed: the ballast under the ties, and the bank's toe on the ground, at the sharpest bend and at three other
##      places a quarter of the loop apart;
##   4. no kink between two drawn lengths of rail over 0.25 degrees;
##   5. the wheels on the rails: every wheel of a boxcar posed at the sharpest bend exactly as the level poses one, and of
##      the locomotive wherever it is, has its lowest point on the railhead and its tread over the rail's middle;
##   6. the rake is drawn evenly through a tick, which is what stops it juddering behind a locomotive that is not.
##
## THE REDS IT WAS WATCHED GIVING, one mutant each, are in the commit that adds it.

const PATIENCE: int = 3000
const SETTLE: int = 30

## ---- the standards, typed here ----------------------------------------------------------------
## Standard gauge, 4 ft 8 1/2 in, between the inside faces of the two heads.
const GAUGE: float = 56.5 * 0.0254
const GAUGE_WITHIN: float = 0.002
## AREMA 136RE: 185.7 mm high, the head 74.6 mm across.
const RAIL_HIGH: float = 0.1857
const HEAD_WIDE: float = 0.0746
## The AREMA mainline wood tie and its spacing.
const TIE_LONG: float = 102.0 * 0.0254
const TIE_WIDE: float = 9.0 * 0.0254
const TIE_SPACING: float = 19.5 * 0.0254
## A drawn length, a middle or a height is right to this.
const CLOSE: float = 0.01
## THE KINK a joint may have. Sampled every 10 m, the loop's tightest bend turns 0.245 degrees at one waypoint -- sharper
## than the 2,588 m the 40 m survey reports, which averages over four times the length. The 40 m waypoints the track was
## laid on before turned about four times as much.
const KINK_MOST_DEG: float = 0.30
## A wheel's lowest point to the railhead, and its tread's middle to the rail's.
const WHEEL_ON: float = 0.01
## How far round the sharpest bend the rails, ties and wheels are read.
const NEAR: float = 150.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _finished: bool = false
## The track the trains ride, and each waypoint's distance along it.
var _points: Array[Vector3] = []
var _reach: PackedFloat64Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[track_drawn] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("the_native_library_is_loaded", false, "no CockpitWorld")
		_finish()
		return
	var chosen: String = Net.choose_level("island")
	_check("the_island_can_be_chosen", chosen == "", "'%s'" % chosen)
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	var frames: int = 0
	while frames < PATIENCE and not (Sim.is_ready and Sim.client != null and not Sim.current.is_empty()):
		await get_tree().process_frame
		frames += 1
	_check("the_island_comes_up", Sim.is_ready and Sim.client != null and _level.scenery != null,
		"after %d frames, sim ready %s, scenery %s" % [frames, Sim.is_ready, _level.scenery != null])
	if not Sim.is_ready or Sim.client == null or _level.scenery == null:
		_finish()
		return
	for i in range(SETTLE):
		await get_tree().process_frame

	_points = Terrain.rail_points(Terrain.RAIL_LAID_EVERY)
	_reach.resize(_points.size() + 1)
	_reach[0] = 0.0
	for i in range(_points.size()):
		_reach[i + 1] = _reach[i] + _points[i].distance_to(_points[(i + 1) % _points.size()])
	var sharpest: int = _sharpest_waypoint()
	print("[track_drawn] %d waypoints, %.0f m round; the sharpest bend is at waypoint %d, %.0f m along, radius %.0f m"
		% [_points.size(), _reach[_points.size()], sharpest, _reach[sharpest], _radius_at(sharpest)])

	# WHAT IS DRAWN ROUND THE SHARPEST BEND, built now and read in the same frame: the yard lets the ties go past their
	# reach of wherever the level's own eye is on the next frame.
	_level.scenery.fill_around(_points[sharpest])
	var drawn: Dictionary = _drawn_near(_points[sharpest])
	_the_rails_run_waypoint_to_waypoint_at_standard_gauge(drawn["Railway"])
	_the_ties_are_mainline_ties_under_the_rails(drawn["RailwayTies"])
	_no_joint_is_kinked(drawn["Railway"])
	_the_bank_stands_on_the_ground(drawn["RailwayBed"], "the_sharpest_bend")
	_a_boxcar_at_the_sharpest_bend_has_its_wheels_on_the_rails(sharpest, drawn["Railway"])
	_the_locomotive_has_its_wheels_on_the_rails()
	_a_rake_is_drawn_evenly_through_a_tick()
	for quarter in range(1, 4):
		var at: int = (sharpest + _points.size() * quarter / 4) % _points.size()
		_level.scenery.fill_around(_points[at])
		_the_bank_stands_on_the_ground(_drawn_near(_points[at])["RailwayBed"], "a_quarter_round_x%d" % quarter)
	_finish()


## ---- reading the drawn railway -----------------------------------------------------------------

## EVERY DRAWN INSTANCE of each permanent-way layer within NEAR of `at`, as its world-space vertices, keyed by layer.
func _drawn_near(at: Vector3) -> Dictionary:
	var out: Dictionary = {"Railway": [], "RailwayTies": [], "RailwayBed": []}
	for batch in _level.scenery.rail_batches():
		var layer: String = String(batch.name).get_slice("_", 0)
		if not out.has(layer):
			continue
		var multi: MultiMesh = batch.multimesh
		var local: PackedVector3Array = multi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		# THE BATCH'S OWN RECORD OF WHAT IT PUT IN ITS BUFFER, not `get_instance_transform`: headless, the dummy renderer
		# keeps no MultiMesh buffer and hands back the identity for every instance, which put every piece at its batch's
		# middle on the first run. `SceneryYard` files `placed` from the same transforms it writes into the buffer.
		var placed_all: Array = batch.get_meta(&"placed", [])
		for k in range(placed_all.size()):
			var placed: Transform3D = batch.global_transform * (placed_all[k] as Transform3D)
			if Vector2(placed.origin.x - at.x, placed.origin.z - at.z).length() > NEAR:
				continue
			var world := PackedVector3Array()
			world.resize(local.size())
			for v in range(local.size()):
				world[v] = placed * local[v]
			(out[layer] as Array).append(world)
	return out


## THE WAYPOINT CHORD a point is on or beside, as `{index, a, b, along, across, up}`: `along` the chord from a to b,
## `across` level and to its right, `up` world up. The frame every measurement is taken in.
func _chord_of(point: Vector3) -> Dictionary:
	var best: int = 0
	var best_off: float = INF
	for i in range(_points.size()):
		var a: Vector3 = _points[i]
		var b: Vector3 = _points[(i + 1) % _points.size()]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t: float = clampf(Vector2(point.x - a.x, point.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var off: float = Vector2(point.x - a.x, point.z - a.z).distance_to(ab * t)
		if off < best_off:
			best_off = off
			best = i
	var a2: Vector3 = _points[best]
	var b2: Vector3 = _points[(best + 1) % _points.size()]
	var along: Vector3 = (b2 - a2).normalized()
	return {"index": best, "a": a2, "b": b2, "along": along,
		"across": along.cross(Vector3.UP).normalized(), "up": Vector3.UP}


## A point in a chord's frame: x across, y up from the chord's line under it, z along from `a`.
func _in_chord(chord: Dictionary, point: Vector3) -> Vector3:
	var from: Vector3 = point - (chord["a"] as Vector3)
	var z: float = from.dot(chord["along"])
	var line: Vector3 = (chord["a"] as Vector3) + (chord["along"] as Vector3) * z
	return Vector3(from.dot(chord["across"]), point.y - line.y, z)


## ---- 1. the rails ---------------------------------------------------------------------------------

func _the_rails_run_waypoint_to_waypoint_at_standard_gauge(rails: Array) -> void:
	var lengths_wrong: int = 0
	var worst_length: String = ""
	var worst_gauge: float = 0.0
	var gauge_read: float = 0.0
	var worst_height: float = 0.0
	var worst_centre: float = 0.0
	var chords: Dictionary = {}
	for rail in rails:
		var points: PackedVector3Array = rail
		var middle := Vector3.ZERO
		for p in points:
			middle += p
		middle /= float(points.size())
		var chord: Dictionary = _chord_of(middle)
		var run: float = (chord["a"] as Vector3).distance_to(chord["b"])
		chords[int(chord["index"])] = int(chords.get(int(chord["index"]), 0)) + 1
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for p in points:
			var c: Vector3 = _in_chord(chord, p)
			low = low.min(c)
			high = high.max(c)
		# FROM ONE WAYPOINT TO THE NEXT: its ends at 0 and at the chord's length along it.
		if absf(low.z) > CLOSE or absf(high.z - run) > CLOSE:
			lengths_wrong += 1
			worst_length = "chord %d, %.2f m long: drawn from %.3f to %.3f along it" % [chord["index"], run, low.z, high.z]
		# THE HEADS: the vertices within 5 mm of the top, split by side; each head's inside face is its x nearest the
		# middle, and each rail's middle is halfway between its head's two faces.
		var top: float = high.y
		# EACH HEAD'S TOP FROM ITS OWN SIDE'S HIGHEST POINT: on a banked curve the low head's top is 2.8 cm under the high
		# one's, and one threshold across both found no low head at all on the first run.
		var port_top: float = -INF
		var starboard_top: float = -INF
		for p in points:
			var c: Vector3 = _in_chord(chord, p)
			if c.x < 0.0:
				port_top = maxf(port_top, c.y)
			else:
				starboard_top = maxf(starboard_top, c.y)
		var port_inside: float = -INF
		var port_outside: float = INF
		var starboard_inside: float = INF
		var starboard_outside: float = -INF
		for p in points:
			var c: Vector3 = _in_chord(chord, p)
			if c.y < (port_top if c.x < 0.0 else starboard_top) - 0.005:
				continue
			if c.x < 0.0:
				port_inside = maxf(port_inside, c.x)
				port_outside = minf(port_outside, c.x)
			else:
				starboard_inside = minf(starboard_inside, c.x)
				starboard_outside = maxf(starboard_outside, c.x)
		var gauge: float = starboard_inside - port_inside
		gauge_read = gauge
		worst_gauge = maxf(worst_gauge, absf(gauge - GAUGE))
		worst_centre = maxf(worst_centre, absf((port_inside + port_outside + starboard_inside + starboard_outside) * 0.25))
		# THE HEAD'S TOP ON THE WAYPOINTS' LINE, which is the railhead the wheels are put on. The bank lifts one head
		# and drops the other by the same, so the two tops' mean is the line.
		worst_height = maxf(worst_height, absf(top - _bank_lift(chord, points, top)))
	var n: int = rails.size()
	_check("the_island_draws_rails_round_the_sharpest_bend", n >= 20, "%d lengths within %.0f m" % [n, NEAR])
	_check("each_length_of_rail_runs_from_one_waypoint_to_the_next", n > 0 and lengths_wrong == 0,
		"%d of %d wrong%s" % [lengths_wrong, n, "" if worst_length == "" else "; " + worst_length])
	var doubled: int = 0
	for index in chords:
		if int(chords[index]) != 1:
			doubled += 1
	_check("and_each_chord_has_exactly_one", n > 0 and doubled == 0, "%d chords with none or two" % doubled)
	_check("the_gauge_between_the_drawn_heads_is_standard", n > 0 and worst_gauge <= GAUGE_WITHIN,
		"%.4f m between the inside faces, worst %.4f off %.4f" % [gauge_read, worst_gauge, GAUGE])
	_check("and_the_track_is_centred_on_the_waypoints", n > 0 and worst_centre <= CLOSE,
		"worst %.4f m off" % worst_centre)
	_check("and_the_railhead_is_the_waypoints_line", n > 0 and worst_height <= CLOSE,
		"worst %.4f m off it" % worst_height)


## THE MEAN HEIGHT OF THE TWO HEADS' TOPS over the chord's line: what the bank cannot move.
func _bank_lift(chord: Dictionary, points: PackedVector3Array, top: float) -> float:
	var port: float = -INF
	var starboard: float = -INF
	for p in points:
		var c: Vector3 = _in_chord(chord, p)
		if c.x < 0.0:
			port = maxf(port, c.y)
		else:
			starboard = maxf(starboard, c.y)
	return top - (port + starboard) * 0.5


## ---- 2. the ties ----------------------------------------------------------------------------------

func _the_ties_are_mainline_ties_under_the_rails(ties: Array) -> void:
	var centres: Array[float] = []
	var worst_long: float = 0.0
	var worst_wide: float = 0.0
	var worst_top: float = 0.0
	var reference: Dictionary = {}
	for tie in ties:
		var points: PackedVector3Array = tie
		var middle := Vector3.ZERO
		for p in points:
			middle += p
		middle /= float(points.size())
		var chord: Dictionary = _chord_of(middle)
		if reference.is_empty():
			reference = chord
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for p in points:
			var c: Vector3 = _in_chord(chord, p)
			low = low.min(c)
			high = high.max(c)
		worst_long = maxf(worst_long, absf(high.x - low.x - TIE_LONG))
		worst_wide = maxf(worst_wide, absf(high.z - low.z - TIE_WIDE))
		# THE RAILS' FEET STAND ON IT: its top a rail's height under the railhead. The two ends' tops are averaged, because
		# on a banked curve the tie leans with the rails and one end stands 2.5 cm higher than the other.
		var port_top: float = -INF
		var starboard_top: float = -INF
		for p in points:
			var c: Vector3 = _in_chord(chord, p)
			if c.x < 0.0:
				port_top = maxf(port_top, c.y)
			else:
				starboard_top = maxf(starboard_top, c.y)
		worst_top = maxf(worst_top, absf((port_top + starboard_top) * 0.5 + RAIL_HIGH))
		centres.append(_reach[int(chord["index"])] + (low.z + high.z) * 0.5)
	centres.sort()
	var worst_gap: float = 0.0
	for i in range(1, centres.size()):
		worst_gap = maxf(worst_gap, absf(centres[i] - centres[i - 1] - TIE_SPACING))
	var n: int = ties.size()
	_check("the_island_draws_ties_round_the_sharpest_bend", n >= int(NEAR / TIE_SPACING),
		"%d within %.0f m" % [n, NEAR])
	_check("each_tie_is_eight_foot_six_by_nine_inches", n > 0 and worst_long <= CLOSE and worst_wide <= CLOSE,
		"worst %.4f m off the length, %.4f off the width" % [worst_long, worst_wide])
	_check("at_nineteen_and_a_half_inch_centres", n > 1 and worst_gap <= CLOSE,
		"worst %.4f m off %.4f" % [worst_gap, TIE_SPACING])
	_check("and_the_rails_stand_on_them", n > 0 and worst_top <= CLOSE,
		"worst %.4f m off a rail's height under the head" % worst_top)


## ---- 3. the bed -----------------------------------------------------------------------------------

## THE BANK REACHES THE GROUND: under every length of bed, the lowest vertices on EACH side on the ground Terrain says is
## there -- each side on its own, because a bank tipped with the track has one toe in the air and the other in the ground,
## and the lowest of the two would read as fine -- and its top below the ties' tops, where the crib lies.
func _the_bank_stands_on_the_ground(beds: Array, where: String) -> void:
	var worst_toe: float = 0.0
	var worst_top: float = -INF
	for bed in beds:
		var points: PackedVector3Array = bed
		var middle := Vector3.ZERO
		var highest: float = -INF
		for p in points:
			middle += p
			highest = maxf(highest, p.y)
		middle /= float(points.size())
		var chord: Dictionary = _chord_of(middle)
		for side in [-1.0, 1.0]:
			var lowest := Vector3(0.0, INF, 0.0)
			for p in points:
				if _in_chord(chord, p).x * side > 0.0 and p.y < lowest.y:
					lowest = p
			worst_toe = maxf(worst_toe, absf(lowest.y - Terrain.ground_height(lowest)))
		worst_top = maxf(worst_top, highest - ((chord["a"] as Vector3).y - RAIL_HIGH))
	var n: int = beds.size()
	_check("at_%s_the_bank_stands_on_the_ground" % where, n > 0 and worst_toe <= 0.02,
		"%d lengths, the worst toe %.3f m off the ground" % [n, worst_toe])
	_check("at_%s_the_ballast_lies_below_the_ties_tops" % where, n > 0 and worst_top < 0.0,
		"its top %.3f m against a tie's top" % worst_top)


## ---- 4. the joints --------------------------------------------------------------------------------

func _no_joint_is_kinked(rails: Array) -> void:
	# EACH LENGTH'S DIRECTION, off its own drawn vertices: the line from the middle of its first end to its last.
	var by_chord: Dictionary = {}
	for rail in rails:
		var points: PackedVector3Array = rail
		var middle := Vector3.ZERO
		for p in points:
			middle += p
		middle /= float(points.size())
		var chord: Dictionary = _chord_of(middle)
		var first := Vector3.ZERO
		var last := Vector3.ZERO
		var firsts: int = 0
		var lasts: int = 0
		var run: float = (chord["a"] as Vector3).distance_to(chord["b"])
		for p in points:
			var z: float = _in_chord(chord, p).z
			if z < run * 0.5:
				first += p
				firsts += 1
			else:
				last += p
				lasts += 1
		if firsts > 0 and lasts > 0:
			by_chord[int(chord["index"])] = (last / float(lasts) - first / float(firsts)).normalized()
	var worst: float = 0.0
	var worst_chords: float = 0.0
	var joints: int = 0
	var n: int = _points.size()
	for index in by_chord:
		var next: int = (int(index) + 1) % n
		if by_chord.has(next):
			worst = maxf(worst, rad_to_deg((by_chord[index] as Vector3).angle_to(by_chord[next])))
			var into: Vector3 = _points[next] - _points[int(index)]
			var out_of: Vector3 = _points[(next + 1) % n] - _points[next]
			worst_chords = maxf(worst_chords, rad_to_deg(into.angle_to(out_of)))
			joints += 1
	_check("no_joint_between_two_lengths_of_rail_is_kinked", joints > 10 and worst <= KINK_MOST_DEG,
		"%d joints, the worst drawn turns %.3f degrees, where the waypoints' chords turn %.3f"
		% [joints, worst, worst_chords])


## ---- 5. the wheels --------------------------------------------------------------------------------

## A BOXCAR AT THE SHARPEST BEND, posed as `_draw_carriages` poses every car -- `rail_pose` over its truck centres --
## and its own drawn wheels held to the drawn rails under them.
func _a_boxcar_at_the_sharpest_bend_has_its_wheels_on_the_rails(sharpest: int, rails: Array) -> void:
	var pose: Dictionary = Sim.client.rail_pose(0, _reach[sharpest], Boxcar.TRUCK_CENTRES, 0.0)
	var car := MeshInstance3D.new()
	car.mesh = Boxcar.mesh()
	add_child(car)
	car.global_transform = Transform3D(Basis(pose["basis"] as Quaternion), pose["position"])
	var wheels: Array = _wheels_of_mesh(car, Boxcar.WHEEL_PAINT)
	_wheels_on_the_rails("a_boxcar_at_the_sharpest_bend", wheels, rails)
	car.queue_free()


func _the_locomotive_has_its_wheels_on_the_rails() -> void:
	var engine: int = -1
	for entity in Sim.current:
		if int((Sim.current[entity] as Dictionary).get("kind", -1)) == Sim.Kind.TRAIN:
			engine = int(entity)
			break
	var view: VehicleView = _level.view_of(engine) if engine >= 0 else null
	var wheels: Array = []
	var rails: Array = []
	if view != null:
		_level.scenery.fill_around(view.global_position)
		rails = _drawn_near(view.global_position)["Railway"]
		# A WHEEL IS EITHER ITS OWN NODE OR A PATCH OF WHEEL PAINT IN A TRUCK. The old F7A drew each wheel as a named
		# `TrainWheel...` child; `RoadDiesel` welds its twelve into two `Truck` meshes, as `Boxcar` does, so a check
		# that knew only about names found none at all on the new locomotive and read as the locomotive having no
		# wheels. Both are asked, and the two cannot both be empty.
		for found in view.find_children("*Wheel*", "MeshInstance3D", true, false):
			var part := found as MeshInstance3D
			var points := PackedVector3Array()
			for s in range(part.mesh.get_surface_count()):
				for v in part.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					points.append(part.global_transform * (v as Vector3))
			wheels.append(points)
		for found in view.find_children("*Truck*", "MeshInstance3D", true, false):
			wheels.append_array(_wheels_of_mesh(found as MeshInstance3D, RoadDiesel.WHEEL_PAINT))
	_wheels_on_the_rails("the_locomotive", wheels, rails)


## THE WHEELS IN ONE MESH, picked out by their paint and split into one group of vertices per wheel by where they are.
func _wheels_of_mesh(drawn: MeshInstance3D, paint: Color) -> Array:
	var arrays: Array = drawn.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var painted := PackedVector3Array()
	for i in range(vertices.size()):
		var c: Color = colours[i]
		if absf(c.r - paint.r) + absf(c.g - paint.g) + absf(c.b - paint.b) <= 0.02:
			painted.append(vertices[i])
	# ONE GROUP PER WHEEL by single linkage at 0.6 m: a wheel's hub, the middle of the fan each face is drawn as, is 0.45 m
	# from the rim of a 33 in boxcar wheel and 0.55 m from a 40 in locomotive's, and the nearest corners of two different
	# wheels are 0.77 m apart. At 0.4 m every hub was a wheel of its own, and at 0.5 the locomotive's were -- twenty-four
	# wheels, twelve of them a single point half a metre over the rail. Grouped round each group's first vertex instead,
	# every wheel split in two, because a first vertex on the rim is a diameter from the far rim.
	var home := PackedInt32Array()
	home.resize(painted.size())
	for i in range(painted.size()):
		home[i] = i
	for i in range(painted.size()):
		for j in range(i + 1, painted.size()):
			if painted[i].distance_to(painted[j]) < 0.6:
				var a: int = _root_of(home, i)
				var b: int = _root_of(home, j)
				if a != b:
					home[b] = a
	# INTO AN Array, NOT A PackedVector3Array: a packed array is a VALUE, so appending to one fetched out of a Dictionary
	# appends to a copy, and the first run found sixteen wheels with nothing in them.
	var by_root: Dictionary = {}
	for i in range(painted.size()):
		var root: int = _root_of(home, i)
		if not by_root.has(root):
			by_root[root] = []
		(by_root[root] as Array).append(drawn.global_transform * painted[i])
	var out: Array = []
	for root in by_root:
		out.append(PackedVector3Array(by_root[root]))
	return out


func _root_of(home: PackedInt32Array, i: int) -> int:
	while home[i] != i:
		i = home[i]
	return i


## EVERY WHEEL ON ITS RAIL: where it touches -- its lowest vertices, which on a wheel drawn round its circle are the flat
## at the bottom -- on the top of the DRAWN head under it, and across over that head's middle. Against the drawn rail on
## the wheel's own side, not the waypoints' centreline: on a banked bend each head stands 1.4 cm above or below the line,
## and so does the wheel that rolls on it. And the contact, not the wheel's middle: the middle is the hub, 0.42 m up, and
## the bank rolls it 7.9 mm across.
func _wheels_on_the_rails(who: String, wheels: Array, rails: Array) -> void:
	var heads: Dictionary = _heads_of(rails)
	var worst_down: float = 0.0
	var worst_across: float = 0.0
	var off_the_drawn: int = 0
	for wheel in wheels:
		var points: PackedVector3Array = wheel
		var lowest: float = INF
		for p in points:
			lowest = minf(lowest, p.y)
		var contact := Vector3.ZERO
		var touching: int = 0
		for p in points:
			if p.y <= lowest + 0.005:
				contact += p
				touching += 1
		contact /= float(touching)
		var chord: Dictionary = _chord_of(contact)
		var index: int = int(chord["index"])
		if not heads.has(index):
			off_the_drawn += 1
			continue
		var at: Vector3 = _in_chord(chord, contact)
		var head: Vector2 = (heads[index] as Dictionary)["port" if at.x < 0.0 else "starboard"]
		worst_down = maxf(worst_down, absf(at.y - head.y))
		worst_across = maxf(worst_across, absf(at.x - head.x))
	var found: bool = wheels.size() >= 8 and off_the_drawn == 0
	_check("%s_stands_its_wheels_on_the_railheads" % who, found and worst_down <= WHEEL_ON,
		"%d wheels, %d over no drawn rail, the worst %.4f m off its head" % [wheels.size(), off_the_drawn, worst_down])
	_check("%s_runs_its_treads_over_the_rails" % who, found and worst_across <= WHEEL_ON,
		"the worst contact %.4f m across from its head's middle" % worst_across)


## EACH DRAWN LENGTH OF RAIL'S TWO HEADS, keyed by its chord: `{"port": Vector2(middle across, top), "starboard": ...}`
## in the chord's frame.
func _heads_of(rails: Array) -> Dictionary:
	var out: Dictionary = {}
	for rail in rails:
		var points: PackedVector3Array = rail
		var middle := Vector3.ZERO
		for p in points:
			middle += p
		middle /= float(points.size())
		var chord: Dictionary = _chord_of(middle)
		var sides: Dictionary = {}
		for side in ["port", "starboard"]:
			var top: float = -INF
			for p in points:
				var c: Vector3 = _in_chord(chord, p)
				if (c.x < 0.0) == (side == "port"):
					top = maxf(top, c.y)
			var low_x: float = INF
			var high_x: float = -INF
			for p in points:
				var c: Vector3 = _in_chord(chord, p)
				if (c.x < 0.0) == (side == "port") and c.y >= top - 0.005:
					low_x = minf(low_x, c.x)
					high_x = maxf(high_x, c.x)
			sides[side] = Vector2((low_x + high_x) * 0.5, top)
		out[int(chord["index"])] = sides
	return out


## ---- 6. smoothness ---------------------------------------------------------------------------------

## A RAKE MOVES EVENLY THROUGH A TICK, and the whole of it at the locomotive's own speed.
##
## THE USER, 2026-09-19: *"The train has a fair amount of jitter in it ... train position is not 100% critical but
## smoothness is."* Every boxcar was placed from the CURRENT tick's distance while the locomotive ahead of it was drawn
## between its two simulated poses, so the rake stood still through each tick and jumped 0.183 m at its end -- 22 m/s at
## 120 Hz -- opening and closing every coupling 120 times a second.
##
## WALKED BY HAND, as `smoke`'s `drawing_walks_the_tick_evenly` walks a vehicle's. Headless steps physics and drawing
## together, so the real loop reports perfect smoothness whatever the drawing does; handing `Sim.rail_distance` its own
## alpha is the only way to see it. Nine slices of a tick: each must carry the train a ninth of what its speed says, and
## the eight steps must be the same to within a twentieth.
func _a_rake_is_drawn_evenly_through_a_tick() -> void:
	var engine: int = -1
	for entity in Sim.current:
		if int((Sim.current[entity] as Dictionary).get("kind", -1)) == Sim.Kind.TRAIN:
			engine = int(entity)
			break
	var state: Dictionary = Sim.client.rail_state(engine) if engine >= 0 else {}
	var speed: float = float(state.get("speed", 0.0))
	var walked: Array[float] = []
	for i in range(9):
		walked.append(Sim.rail_distance(engine, float(i) / 8.0))
	var smallest: float = INF
	var largest: float = -INF
	for i in range(8):
		var step: float = walked[i + 1] - walked[i]
		smallest = minf(smallest, step)
		largest = maxf(largest, step)
	var over_a_tick: float = walked[8] - walked[0]
	var wanted: float = speed * Sim.tick_dt()
	_check("a_rake_is_drawn_evenly_through_a_tick", engine >= 0 and smallest > 0.0 and largest / smallest < 1.05,
		"eight slices of a tick range %.6f to %.6f m" % [smallest, largest])
	_check("and_a_whole_tick_of_it_is_the_trains_own_speed",
		speed > 0.0 and absf(over_a_tick - wanted) < 0.001,
		"%.4f m drawn against %.4f m at %.2f m/s" % [over_a_tick, wanted, speed])


## ---- the loop's own geometry ----------------------------------------------------------------------

## The waypoint with the tightest circle through it and its two neighbours.
func _sharpest_waypoint() -> int:
	var best: int = 0
	var tightest: float = INF
	for i in range(_points.size()):
		var r: float = _radius_at(i)
		if r < tightest:
			tightest = r
			best = i
	return best


func _radius_at(i: int) -> float:
	var n: int = _points.size()
	var a: Vector3 = _points[(i - 1 + n) % n]
	var b: Vector3 = _points[i]
	var c: Vector3 = _points[(i + 1) % n]
	var area: float = (b - a).cross(c - a).length() * 0.5
	return INF if area < 1e-6 else a.distance_to(b) * b.distance_to(c) * c.distance_to(a) / (4.0 * area)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	Sim.stop()
	Net.leave("suite over")
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
