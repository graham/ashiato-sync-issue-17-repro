extends Node
## Headless: THE TRAIN'S ROLLING STOCK, held to what was measured off a photograph and to bounds
## that came from outside the model.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/train_models.tscn
##
## Asked for on 2026-09-17: the train to be hauled by a Santa Fe Super Chief locomotive with
## "boxcars for box cars, make trains 8-10 cars long". This suite is the boxcar's half of that
## and the rake's. The figures at the top are the SOURCES -- `cockpit/craft/train/sources.md`
## and `measure_boxcar.py`, which re-derives the measured ones from the photograph alone -- and
## they are typed here as an independent statement of what the model is supposed to be, exactly
## as `tests/fleet_shapes.gd` types the Hawkeye's fact sheet.
##
## WHAT IT HOLDS:
##   - the car is DRAWN at its stated size, measured from its own vertices and never from a
##     constant or from `get_aabb`;
##   - it STANDS ON THE RAILHEAD: its lowest drawn point is the bottom of its wheels, at y = 0
##     in its own frame, so the level needs no lift and no half-a-height fudge;
##   - **its roof clears the AAR clearance plate.** This is the check that is anchored outside
##     the model: Plate B stops at 15 ft 1 in, the ridge is a MEASURED body depth plus an
##     ESTIMATED sill height, and nothing in the model knows about the plate. A car that grew
##     until it fouled the loading gauge would pass every dimension check and fail this one;
##   - **the roof is a peak and the door is proud of the side**, which are the two things that
##     make it a boxcar rather than a shipping container on wheels. Both are asked of the drawn
##     vertices: a flat lid is the right length, the right width, the right depth and clears
##     the loading gauge, and passes every other check here;
##   - the door is the 7 ft opening that was measured, on both sides, below its own track;
##   - eight wheels, each an eight-sided prism, standing where the trucks were measured. The
##     facet count is taken from the DRAWN NORMALS, so replacing the prism with a smooth
##     cylinder fails it; `modelling_here.md` section 4 asks for the counts to be stated and
##     nothing yet checks that they are kept;
##   - **A RAKE HAS NO GAP AND NO OVERLAP**: the car's drawn length over its couplers is
##     exactly the spacing the level places cars at. The pair this replaced put 18.0 m boxes
##     21.0 m apart and left three metres of daylight at every coupling;
##   - every train is 8 to 10 cars, and both ends of that range are in use -- a range with only
##     one value ever chosen is a constant wearing a range's clothes;
##   - one surface, so a rake of ten costs ten draw calls and not a hundred.
##
## Read RESULT=, not the exit code.

## ---- what the sources say the car is. See cockpit/craft/train/sources.md. ----------------
## A 40 ft AAR boxcar over its eaves, and over its sides.
const LENGTH: float = 12.60
const WIDTH: float = 3.20
## Sill to eaves: MEASURED as 0.2616 of the length off the broadside.
const BODY_DEPTH: float = 3.30
## The door opening: MEASURED as 0.1692 of the length, which is 7 ft 0 in.
const DOOR_WIDE: float = 2.13
## Truck centres: MEASURED as 0.758 of the length, +/- about 4 per cent.
const TRUCK_CENTRES: float = 9.55
## PUBLISHED, the AAR standard freight truck and wheel.
const TRUCK_WHEELBASE: float = 1.676
const WHEEL_DIAMETER: float = 0.838

## HOW MANY SIDES A WHEEL IS DRAWN WITH, and HOW LONG A TRAIN IS. Typed HERE, not read off
## `Boxcar` and `Terrain`, and that is the whole point of them: a check that asks the code for
## the number it is checking cannot catch the number being wrong. Both were written that way
## first and both mutants -- a 24-sided wheel and the old five-car train -- walked straight
## through them green. `modelling_here.md`: a check that shares its subject's frame of
## reference cannot catch the frame being wrong.
##
## 8 is `modelling_here.md` section 4's low-poly direction, against the Hawkeye's 20 on a
## nacelle round; 8 to 10 is what was asked for on 2026-09-17.
const WHEEL_SIDES: int = 8
const CARS_LEAST: int = 8
const CARS_MOST: int = 10

## THE BOUND FROM OUTSIDE THE MODEL: AAR clearance Plate B, 15 ft 1 in above the railhead. It is
## a published loading gauge, it is not a dimension of this car, and no part of the model was
## built from it -- which is the entire reason it can catch the model being wrong.
const AAR_PLATE_B: float = 15.0 * 0.3048 + 1.0 * 0.0254
## And a car that is not nearly that tall is not a boxcar. A 40 ft car is 14 ft or more.
const A_BOXCAR_IS_AT_LEAST: float = 14.0 * 0.3048

## How close a drawn dimension has to be to its stated one. Two centimetres on a 12.6 m car is
## 0.16 per cent, which is tighter than any of the sources behind these numbers.
const CLOSE: float = 0.02

## The car is ONE mesh: a rake of ten must not be a hundred draw calls.
const SURFACES: int = 1
## And within this many triangles, which is what a low-poly car of this size costs. Stated so a
## retessellation has something to be judged against rather than a feeling.
const TRIANGLES: int = 900

## ---- what the sources say the LOCOMOTIVE is: an EMD SD40-2. See cockpit/craft/train/sources.md. ----
## PUBLISHED, en.wikipedia.org/wiki/EMD_SD40-2, typed in the units the source prints them in so a
## reader can check them against it. NEVER read back off `train_shape()`: a check that asks the
## code for its own number cannot catch that number being wrong, and the 18 m box this lineage
## started from was precisely that number being wrong, for as long as there was a train.
##
## It was an F7A -- 50 ft 8 in by 10 ft 7 in by 15 ft -- until 2026-09-19, when the user asked for
## a modern locomotive. `tests/road_diesel.gd` holds the MODEL to the same published figures on its
## own; this file holds the SIMULATION's shape to them, and the two to each other.
const SD40_LENGTH: float = 68.0 * 0.3048 + 10.0 * 0.0254
const SD40_WIDTH: float = 10.0 * 0.3048 + 3.125 * 0.0254
## Over the rail, which is where the collision box stands and the model is measured up from.
const SD40_HEIGHT: float = 15.0 * 0.3048 + 7.125 * 0.0254
## THE 2 PER CENT DRAWN-BOUNDS RULE. Every source behind these three is quoted to the inch --
## under 0.2 per cent on the shortest -- so 2 per cent is a rule about the MODEL, not the source.
const WITHIN: float = 0.02
## A DRIVER SITS IN THE CAB: behind the windscreen, and not far behind it. An SD40-2's cab is
## about 2.8 m deep; a seat further aft of the glass than this is in the engine room.
const CAB_DEEP: float = 3.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[train_models] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var mesh: ArrayMesh = Boxcar.build()
	if mesh == null:
		_check("the_boxcar_was_built_at_all", false, "Boxcar.build() returned nothing")
		_finish()
		return
	var points: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colours: PackedColorArray = PackedColorArray()
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		points.append_array(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		normals.append_array(arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		colours.append_array(arrays[Mesh.ARRAY_COLOR] as PackedColorArray)

	_it_is_one_surface_within_its_triangles(mesh, points)
	_it_is_wound_outwards(points, normals)
	var bounds: AABB = _drawn_bounds(points)
	_it_is_the_size_the_sources_say(bounds)
	_it_stands_on_the_railhead(bounds, points)
	_its_roof_clears_the_loading_gauge(bounds)
	_the_roof_is_peaked(points)
	_the_door_is_the_opening_that_was_measured(points)
	_eight_wheels_of_eight_sides_where_the_trucks_were_measured(points, normals, colours)
	_a_rake_has_no_gap_and_no_overlap(bounds)
	_every_train_is_eight_to_ten_cars()
	_the_locomotive_is_an_sd40_2_and_its_drivers_sit_in_its_cab()
	_finish()


## THE DRAWN BOUNDS, from the vertices themselves. Never `transform * mesh.get_aabb()`, which
## grows a box every time it is turned (`modelling_here.md` section 6).
func _drawn_bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	return box


func _it_is_one_surface_within_its_triangles(mesh: ArrayMesh, points: PackedVector3Array) -> void:
	var triangles: int = points.size() / 3
	_check("the_boxcar_is_one_surface_so_a_rake_of_ten_is_ten_draws",
		mesh.get_surface_count() == SURFACES,
		"%d surface(s) against %d" % [mesh.get_surface_count(), SURFACES])
	_check("and_it_is_within_its_triangle_budget", triangles <= TRIANGLES,
		"%d triangles against %d" % [triangles, TRIANGLES])


## Godot's front faces are clockwise as seen, so `(c - a) x (b - a)` must point the way the
## vertex normal does. A face wound backwards is invisible and nothing else will find it.
func _it_is_wound_outwards(points: PackedVector3Array, normals: PackedVector3Array) -> void:
	var wrong: int = 0
	var total: int = 0
	for i in range(0, points.size() - 2, 3):
		var face: Vector3 = (points[i + 2] - points[i]).cross(points[i + 1] - points[i])
		if face.length_squared() < 1e-12:
			continue
		total += 1
		if face.normalized().dot(normals[i]) < 0.0:
			wrong += 1
	_check("every_face_of_the_boxcar_is_wound_outwards", wrong == 0 and total > 0,
		"%d of %d faces point inwards" % [wrong, total])


func _it_is_the_size_the_sources_say(bounds: AABB) -> void:
	# ALONG THE TRACK the widest thing is the couplers, and across it the roof's eaves.
	var over_couplers: float = bounds.size.z
	var over_eaves: float = bounds.size.x
	_check("the_boxcar_is_drawn_the_length_the_sources_say",
		absf(over_couplers - (LENGTH + Boxcar.COUPLER_REACH * 2.0)) < CLOSE,
		"%.3f m over the couplers, a %.2f m body reaching %.2f m at each end"
			% [over_couplers, LENGTH, Boxcar.COUPLER_REACH])
	_check("and_the_width_the_sources_say",
		absf(over_eaves - (WIDTH + Boxcar.EAVES_OUT * 2.0)) < CLOSE,
		"%.3f m over the eaves, a %.2f m body with %.2f m of overhang each side"
			% [over_eaves, WIDTH, Boxcar.EAVES_OUT])
	_check("and_the_body_is_as_deep_as_it_was_measured",
		absf(Boxcar.eaves() - Boxcar.SILL_OVER_RAIL - BODY_DEPTH) < CLOSE,
		"sill %.2f m to eaves %.2f m is %.3f m against a measured %.2f m"
			% [Boxcar.SILL_OVER_RAIL, Boxcar.eaves(), Boxcar.eaves() - Boxcar.SILL_OVER_RAIL,
				BODY_DEPTH])


## The car's origin is ON THE RAILHEAD, which is what lets the level place it with no lift and
## keeps a banked corner leaning the car exactly as it leans the rails.
func _it_stands_on_the_railhead(bounds: AABB, points: PackedVector3Array) -> void:
	_check("the_boxcar_stands_on_the_railhead_rather_than_in_it",
		absf(bounds.position.y) < 0.005,
		"its lowest drawn point is at y = %+.4f m" % bounds.position.y)
	# And nothing is below it: a wheel touches, the frame does not.
	var below: int = 0
	for point in points:
		if point.y < -0.005:
			below += 1
	_check("and_nothing_is_drawn_under_the_rail", below == 0,
		"%d of %d vertices below y = 0" % [below, points.size()])


## THE CHECK ANCHORED OUTSIDE THE MODEL. Nothing in `Boxcar` knows the plate exists.
func _its_roof_clears_the_loading_gauge(bounds: AABB) -> void:
	var tall: float = bounds.end.y
	_check("the_boxcar_clears_the_aar_loading_gauge",
		tall < AAR_PLATE_B and tall > A_BOXCAR_IS_AT_LEAST,
		"%.3f m (%.1f ft) over the rail, against Plate B's %.3f m and a boxcar's own %.3f m"
			% [tall, tall / 0.3048, AAR_PLATE_B, A_BOXCAR_IS_AT_LEAST])


## THE ROOF IS A PEAK, from the drawn vertices: the car is TALLER ON ITS CENTRELINE than at its
## sides. A flat lid passes every dimension check in this file -- it is the right length, the
## right width, the right depth, and it clears the loading gauge with room to spare -- and it is
## a shipping container. The peak and the door are the two things that make it a boxcar, so both
## are asked of the drawing rather than assumed from a constant.
func _the_roof_is_peaked(points: PackedVector3Array) -> void:
	var over_the_middle: float = -INF
	var over_the_side: float = -INF
	for point in points:
		if absf(point.x) < 0.15:
			over_the_middle = maxf(over_the_middle, point.y)
		elif absf(point.x) > WIDTH * 0.5 - 0.05:
			over_the_side = maxf(over_the_side, point.y)
	_check("the_boxcar_s_roof_is_a_peak_and_not_a_flat_lid",
		over_the_middle - over_the_side > Boxcar.RIDGE_RISE * 0.5,
		"%.3f m over the centreline against %.3f m over the side, a rise of %.3f m"
			% [over_the_middle, over_the_side, over_the_middle - over_the_side])


## THE DOOR, from the drawn vertices: whatever stands proud of the side, below the door's own
## track, is the door. A flush side has none of it and reads as a shipping container.
func _the_door_is_the_opening_that_was_measured(points: PackedVector3Array) -> void:
	var face: float = WIDTH * 0.5 + 0.05
	var ceiling: float = Boxcar.SILL_OVER_RAIL + Boxcar.DOOR_HIGH + 0.05
	var each_side: Dictionary = {-1: [], 1: []}
	for point in points:
		if absf(point.x) > face and point.y < ceiling and point.y > Boxcar.SILL_OVER_RAIL:
			(each_side[signi(int(signf(point.x)))] as Array).append(point.z)
	var widths: Array[float] = []
	for side in [-1, 1]:
		var zs: Array = each_side[side]
		if zs.is_empty():
			widths.append(0.0)
			continue
		var lo: float = zs[0]
		var hi: float = zs[0]
		for z in zs:
			lo = minf(lo, z)
			hi = maxf(hi, z)
		widths.append(hi - lo)
	_check("the_boxcar_has_a_door_proud_of_both_sides",
		widths[0] > 0.0 and widths[1] > 0.0,
		"port %.2f m, starboard %.2f m" % [widths[0], widths[1]])
	_check("and_each_is_the_seven_foot_opening_that_was_measured",
		absf(widths[0] - DOOR_WIDE) < CLOSE and absf(widths[1] - DOOR_WIDE) < CLOSE,
		"%.3f m and %.3f m against a measured %.2f m (%.1f ft)"
			% [widths[0], widths[1], DOOR_WIDE, DOOR_WIDE / 0.3048])


## EIGHT WHEELS, EIGHT SIDES EACH, and where the trucks were measured. The facet count comes
## off the drawn normals: a smooth cylinder put here instead would fail it, which is the whole
## point of writing the segment counts down.
func _eight_wheels_of_eight_sides_where_the_trucks_were_measured(points: PackedVector3Array,
		normals: PackedVector3Array, colours: PackedColorArray) -> void:
	var wheels: Dictionary = {}
	for i in range(points.size()):
		# NOT is_equal_approx: `SurfaceTool.commit` quantises vertex colour to eight bits a
		# channel, so an exact compare finds nothing at all. Half a step of that quantisation
		# is 0.002, and the two darks in the model are 0.08 apart.
		if colours.size() <= i or _far_from(colours[i], Boxcar.WHEEL_PAINT) > 0.01:
			continue
		var key: String = "%.2f_%.2f" % [snappedf(points[i].x, 0.05), snappedf(points[i].z, 0.05)]
		# A wheel is keyed by the middle of its tread, which every one of its vertices is
		# within a radius of; group by the nearest existing key instead of an exact one.
		var found: String = ""
		for existing in wheels:
			var seat: Vector2 = (wheels[existing] as Dictionary)["at"]
			if Vector2(points[i].x, points[i].z).distance_to(seat) < Boxcar.WHEEL_DIAMETER * 0.75:
				found = existing
				break
		if found == "":
			wheels[key] = {"at": Vector2(points[i].x, points[i].z), "low": points[i].y,
				"high": points[i].y, "faces": {}}
			found = key
		var wheel: Dictionary = wheels[found]
		wheel["low"] = minf(wheel["low"], points[i].y)
		wheel["high"] = maxf(wheel["high"], points[i].y)
		# The tread's facets: the normals with no sideways component, rounded so two vertices
		# of the same facet count once.
		if absf(normals[i].x) < 0.01:
			(wheel["faces"] as Dictionary)["%.2f_%.2f" % [snappedf(normals[i].y, 0.02),
				snappedf(normals[i].z, 0.02)]] = true
	_check("the_boxcar_has_eight_wheels", wheels.size() == 8, "%d found" % wheels.size())
	var facets: Array[int] = []
	var tall: Array[float] = []
	var ats: Array[Vector2] = []
	for key in wheels:
		facets.append((wheels[key]["faces"] as Dictionary).size())
		tall.append(float(wheels[key]["high"]) - float(wheels[key]["low"]))
		ats.append(wheels[key]["at"])
	var sides_ok: bool = not facets.is_empty()
	for count in facets:
		sides_ok = sides_ok and count == WHEEL_SIDES
	_check("and_each_is_drawn_as_an_eight_sided_prism_rather_than_a_smooth_cylinder", sides_ok,
		"facet counts %s against %d a wheel" % [facets, WHEEL_SIDES])
	var diameter_ok: bool = not tall.is_empty()
	for height in tall:
		diameter_ok = diameter_ok and absf(height - WHEEL_DIAMETER) < CLOSE
	# ACROSS THE FLATS, which is the diameter that matters: it is what the tread rolls on and
	# what decides how high the car stands. An eight-sided wheel drawn INSIDE the 33 in circle
	# would read 0.774 m here, 7.6 per cent low, and would ride with its tread in the railhead.
	_check("and_each_is_the_thirty_three_inch_aar_wheel_across_its_flats", diameter_ok,
		"%s against %.3f m" % [tall, WHEEL_DIAMETER])
	# WHERE THE TRUCKS WERE MEASURED: two axles a truck, TRUCK_WHEELBASE apart, the trucks
	# TRUCK_CENTRES apart. Read off the wheels' own positions, not off the constants.
	var alongs: Array[float] = []
	for at in ats:
		var z: float = snappedf(at.y, 0.01)
		if not alongs.has(z):
			alongs.append(z)
	alongs.sort()
	var spread: bool = alongs.size() == 4
	if spread:
		var near_truck: float = alongs[1] - alongs[0]
		var far_truck: float = alongs[3] - alongs[2]
		var centres: float = 0.5 * (alongs[2] + alongs[3]) - 0.5 * (alongs[0] + alongs[1])
		_check("and_they_stand_on_two_trucks_at_the_measured_wheelbase_and_spacing",
			absf(near_truck - TRUCK_WHEELBASE) < CLOSE and absf(far_truck - TRUCK_WHEELBASE) < CLOSE
				and absf(centres - TRUCK_CENTRES) < CLOSE,
			"wheelbases %.3f m and %.3f m against %.3f; truck centres %.3f m against %.2f"
				% [near_truck, far_truck, TRUCK_WHEELBASE, centres, TRUCK_CENTRES])
	else:
		_check("and_they_stand_on_two_trucks_at_the_measured_wheelbase_and_spacing", false,
			"%d distinct axle positions, not 4: %s" % [alongs.size(), alongs])


## A RAKE HAS NO GAP AND NO OVERLAP: the drawn car, couplers and all, is exactly as long as the
## step the level takes between cars. One number, one place -- `Boxcar.SPACING` is computed from
## the car's own length, and this asks the DRAWN car whether that came out right.
func _a_rake_has_no_gap_and_no_overlap(bounds: AABB) -> void:
	_check("a_rake_of_boxcars_has_no_gap_and_no_overlap_at_a_coupling",
		absf(bounds.size.z - Boxcar.SPACING) < CLOSE,
		"the car is drawn %.3f m over its couplers and the level steps %.3f m between cars"
			% [bounds.size.z, Boxcar.SPACING])


## EIGHT TO TEN CARS, and BOTH ENDS OF THE RANGE IN USE. A range only ever answering one value
## is a constant in a range's clothes, and nothing would have noticed.
func _every_train_is_eight_to_ten_cars() -> void:
	var counts: Array[int] = []
	for train in Terrain.trains():
		counts.append(int(train.get("cars", 0)))
	var within: bool = not counts.is_empty()
	for count in counts:
		within = within and count >= CARS_LEAST and count <= CARS_MOST
	_check("every_train_on_the_railway_is_eight_to_ten_boxcars_long", within,
		"%s against %d..%d" % [counts, CARS_LEAST, CARS_MOST])
	# Asked of the deriving function over a longer run than the table has, so the range is
	# shown to be a range rather than shown to contain the two values somebody happened to get.
	var reached: Dictionary = {}
	for i in range(64):
		reached[Terrain.cars_behind(i)] = true
	_check("and_both_ends_of_that_range_are_reached",
		reached.has(CARS_LEAST) and reached.has(CARS_MOST),
		"%d trains' worth reaches %s" % [64, reached.keys()])


## How far apart two colours are, as the largest difference in any channel. See the note where
## it is used: vertex colour is eight bits by the time it reaches a committed mesh.
func _far_from(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


## THE LOCOMOTIVE, WHICH NOTHING ASSERTED UNTIL NOW.
##
## `train_shape()` said 18.00 x 3.10 x 4.00 m for as long as there was a train, and nothing in
## any suite could have noticed that no locomotive EMD ever built is that size. The only thing
## downstream of those numbers was the craft package's HASH -- and a hash that changes does not
## fail anybody, it is simply regenerated. So the dimensions were not load-bearing: put the 18 m
## box back and every suite stayed green. These four make them load-bearing, and each was
## watched going red on the old shape before it was trusted on the new one.
func _the_locomotive_is_an_sd40_2_and_its_drivers_sit_in_its_cab() -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.TRAIN)
	var size: Vector3 = (geometry.get("extents", Vector3.ZERO) as Vector3) * 2.0
	_check("the_locomotive_collides_as_the_sd40_2_the_sources_publish",
		_near(size.z, SD40_LENGTH) and _near(size.x, SD40_WIDTH) and _near(size.y, SD40_HEIGHT),
		"collides %.2f x %.2f x %.2f m against %.2f x %.2f x %.2f published"
			% [size.z, size.x, size.y, SD40_LENGTH, SD40_WIDTH, SD40_HEIGHT])

	var view := (load("res://objects/vehicles/craft_plane.tscn") as PackedScene).instantiate() \
		as VehicleView
	add_child(view)
	view.preview_kind = Sim.Kind.TRAIN
	view._show_in_editor()

	# FROM THE DRAWN, VISIBLE VERTICES ONLY. The train draws its body OVER a collision cuboid
	# that is switched off; counting that cuboid would make the drawn bounds equal the extents
	# by construction, and this check would pass for any body at all.
	var drawn: AABB = _drawn_bounds(_every_shown_point(view))
	_check("and_it_is_drawn_the_size_the_sources_publish",
		_near(drawn.size.z, SD40_LENGTH) and _near(drawn.size.x, SD40_WIDTH)
			and _near(drawn.size.y, SD40_HEIGHT),
		"drawn %.2f x %.2f x %.2f m against %.2f x %.2f x %.2f published"
			% [drawn.size.z, drawn.size.x, drawn.size.y, SD40_LENGTH, SD40_WIDTH, SD40_HEIGHT])

	# WHERE THE DRIVERS SIT, against where the glass they look through is DRAWN. -Z is forward,
	# so the windscreen must be AHEAD of each seat -- more negative -- and not far ahead of it.
	# This is the check that would have caught the drivers sitting 12.4 m ahead of their cab.
	var glass := view.find_child("CabWindscreen", true, false) as MeshInstance3D
	var poses: Array = geometry.get("seat_poses", []) as Array
	var in_cab: bool = glass != null and poses.size() >= 2
	var said: PackedStringArray = []
	# THE GLASS'S DRAWN MIDDLE, not its node's position: a part welded in place sits at its parent's origin and carries
	# its geometry in its vertices, so `glass.position.z` is 0 and every seat reads as 3 m behind a windscreen at the
	# locomotive's middle.
	var pane_at: float = _bounds_of(view, glass).get_center().z if glass != null else 0.0
	if glass == null:
		said.append("no CabWindscreen is drawn at all")
	else:
		for seat in [0, 1]:
			if seat >= poses.size():
				break
			var at: Vector3 = (poses[seat] as Dictionary).get("position", Vector3.ZERO) as Vector3
			var aft: float = at.z - pane_at
			in_cab = in_cab and aft > 0.0 and aft <= CAB_DEEP
			said.append("seat %d sits %+.2f m aft of the windscreen" % [seat, aft])
	_check("and_both_drivers_sit_in_the_cab_behind_its_windscreen", in_cab, ", ".join(said))

	# AND THE WINDSCREEN CAN BE SEEN FROM AHEAD. The check above asks where the glass IS; this one
	# asks whether anything is drawn IN FRONT of it. The first version of this very model put the
	# nose's upper step squarely over the windscreen, so the glass stood at exactly the right place
	# and was invisible from outside -- green on position, and found only by looking at the picture.
	# A part covers the glass if it spans the glass's middle across and up AND reaches further
	# forward than the glass's own front face.
	var hidden_by: String = ""
	if glass != null:
		var pane: AABB = _bounds_of(view, glass)
		var middle: Vector3 = pane.get_center()
		for child in view.find_children("*", "MeshInstance3D", true, false):
			var other := child as MeshInstance3D
			if other == glass or other.mesh == null or not _shown(view, other):
				continue
			var box: AABB = _bounds_of(view, other)
			var spans: bool = middle.x > box.position.x and middle.x < box.end.x \
				and middle.y > box.position.y and middle.y < box.end.y
			if spans and box.position.z < pane.position.z:
				hidden_by = str(other.name)
				break
	_check("and_its_windscreen_can_be_seen_from_ahead", glass != null and hidden_by == "",
		"nothing is drawn ahead of it" if hidden_by == "" else "it is hidden behind %s" % hidden_by)

	# AND THE ENGINEER ON THE RIGHT. American practice, and -Z forward makes the right +x.
	var engineer: Dictionary = (poses[0] as Dictionary) if poses.size() > 0 else {}
	var engineer_x: float = (engineer.get("position", Vector3.ZERO) as Vector3).x
	_check("and_the_engineer_sits_on_the_right_as_american_practice_has_it",
		str(engineer.get("station", "")) == "pilot" and engineer_x > 0.0,
		"seat 0 is '%s' at x = %+.2f" % [engineer.get("station", "?"), engineer_x])

	view.queue_free()


## Within the 2 per cent drawn-bounds rule of a published figure.
func _near(value: float, published: float) -> bool:
	return published > 0.0 and absf(value - published) / published <= WITHIN


## EVERY VERTEX A VIEWER COULD SEE, in the view's own frame. A part that is not shown -- the
## switched-off collision cuboid above all -- contributes nothing, and a mesh is read through
## `Mesh`, never `ArrayMesh`: `surface_get_primitive_type` is ArrayMesh's alone, and asked of a
## BoxMesh it returns null and would silently drop every box, which here is every part.
func _every_shown_point(root: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var part := child as MeshInstance3D
		if part.mesh == null or not _shown(root, part):
			continue
		var into := Transform3D.IDENTITY
		var cursor: Node3D = part
		while cursor != root and cursor != null:
			into = cursor.transform * into
			cursor = cursor.get_parent() as Node3D
		for surface in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			for point in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(into * point)
	return out


## ONE PART'S DRAWN BOUNDS, in the root's frame, from its own vertices -- never the part's AABB
## turned by its transform, which grows a box every time it is rotated (`modelling_here.md` s. 6).
func _bounds_of(root: Node3D, part: MeshInstance3D) -> AABB:
	var into := Transform3D.IDENTITY
	var cursor: Node3D = part
	while cursor != root and cursor != null:
		into = cursor.transform * into
		cursor = cursor.get_parent() as Node3D
	var points := PackedVector3Array()
	for surface in range(part.mesh.get_surface_count()):
		for point in part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			points.append(into * point)
	return _drawn_bounds(points)


## Whether every node from a part up to the root is visible.
func _shown(root: Node3D, part: Node3D) -> bool:
	var cursor: Node3D = part
	while cursor != null:
		if not cursor.visible:
			return false
		if cursor == root:
			return true
		cursor = cursor.get_parent() as Node3D
	return true


func _finish() -> void:
	print("RESULT=%s" % ["PASS" if _failures.is_empty() else "FAIL"])
	if not _failures.is_empty():
		print("[train_models] failed: %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
