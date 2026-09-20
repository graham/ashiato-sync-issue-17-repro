extends Node
## THE SD40-2 AGAINST WHAT EMD PUBLISHED, and against the shape of a hood unit. Headless. Read RESULT=, not the exit code.
##
## Every figure below is TYPED HERE from the published source in the units it prints them in, and every measurement is
## taken off the DRAWN vertices of `RoadDiesel` -- never read back off the class, which is the tautology
## `learnings/2026-09-17-train.md` caught twice in the boxcar's own suite (a check that asks the model for the number it
## is checking moves with it).
##
## WHAT IT HOLDS, in the order a reader would want it:
##   1. the named parts a hood unit is made of, counted by name;
##   2. the drawn envelope against the published one;
##   3. THE CAB ROOF BELOW THE LONG HOOD and the short hood below both, which is what makes it a Dash-2 road diesel
##      rather than a switcher -- the thing this model had backwards until the broadside was measured;
##   4. twelve wheels, eight-sided, the published 40 in across their flats, on the railhead and over the rails;
##   5. two trucks at the published centres and wheelbase, read from the wheels themselves;
##   6. nothing floats: every part touches another, and no face is wound inwards;
##   7. the triangle budget.
##
## THE REDS IT WAS WATCHED GIVING are in `cockpit/craft/train/diesel_mutants.py`, one mutant a check.

## ---- what EMD publishes (en.wikipedia.org/wiki/EMD_SD40-2, read 2026-09-19) ----------------------
const LENGTH: float = 68.0 * 0.3048 + 10.0 * 0.0254
const WIDTH: float = 10.0 * 0.3048 + 3.125 * 0.0254
const HEIGHT: float = 15.0 * 0.3048 + 7.125 * 0.0254
const TRUCK_CENTRES: float = 43.0 * 0.3048 + 6.0 * 0.0254
const TRUCK_WHEELBASE: float = 13.0 * 0.3048 + 7.0 * 0.0254
const WHEEL: float = 40.0 * 0.0254
## Standard gauge and the rail's head, which is what sets where a wheel runs. Typed, not asked of `PermanentWay`.
const GAUGE: float = 56.5 * 0.0254
const HEAD_WIDE: float = 0.0746
## THE WALKWAY OVER THE RAILHEAD, MEASURED off the broadside and typed here: its white sill stripe stands 1.06 m up at
## the 154.4 px a metre the photograph's own deck length sets. The band allows the model the 8 cm it needs to carry a
## deck plate over a 40 in wheel, and nothing like the 1.37 m the model first typed -- which nothing else here can see,
## because the hoods are measured from the railhead and a wrong deck only makes them shorter.
const WALKWAY: float = 1.06
## The band covers two things: the 8 cm the deck plate needs to clear a 40 in wheel, and the walkway TREAD standing a
## few centimetres over the frame whose side the stripe is painted on -- the drawn tread is at 1.185.
const WALKWAY_WITHIN: float = 0.16
## A drawn dimension is within this fraction of the published one; the envelope is looser because the model carries
## fittings the figures do not (handrails outside the frame, stacks over the roof).
const WITHIN: float = 0.02
const CLOSE: float = 0.01
const WHEELS: int = 12
const WHEEL_SIDES: int = 8
const TRIANGLES: int = 3000
const PARTS: PackedStringArray = ["Frame", "FuelTank", "ShortHood", "Cab", "LongHood", "Radiator", "Handrails",
	"TruckFront", "TruckRear"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[road_diesel] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var loco := RoadDiesel.new()
	loco.dress()
	add_child(loco)
	var parts: Dictionary = _parts_of(loco)
	_it_is_made_of_the_parts_a_hood_unit_has(parts)
	if parts.is_empty():
		_finish()
		return
	var whole: AABB = _box_of(_every_vertex(loco))
	_it_is_the_size_emd_publishes(whole)
	_the_walkway_is_where_the_photograph_puts_it(parts)
	_the_cab_sits_below_the_long_hood(parts)
	var wheels: Array = _wheels_of(loco)
	_it_has_twelve_forty_inch_wheels_on_the_railhead(wheels)
	_they_are_two_trucks_at_the_published_centres(wheels)
	_nothing_floats_and_nothing_is_inside_out(loco, parts)
	_it_is_within_its_triangles(loco)
	_finish()


## ---- 1. the parts ----------------------------------------------------------------------------

func _it_is_made_of_the_parts_a_hood_unit_has(parts: Dictionary) -> void:
	var missing: PackedStringArray = []
	for wanted in PARTS:
		if not parts.has(wanted):
			missing.append(wanted)
	_check("the_locomotive_is_made_of_the_parts_a_hood_unit_has", missing.is_empty(),
		"%d parts, missing %s" % [parts.size(), "none" if missing.is_empty() else ", ".join(missing)])


## ---- 2. the envelope -------------------------------------------------------------------------

func _it_is_the_size_emd_publishes(whole: AABB) -> void:
	_check("it_is_drawn_the_length_emd_publishes", _near(whole.size.z, LENGTH),
		"%.3f m against 68 ft 10 in = %.3f" % [whole.size.z, LENGTH])
	_check("and_the_width", _near(whole.size.x, WIDTH),
		"%.3f m against 10 ft 3 1/8 in = %.3f" % [whole.size.x, WIDTH])
	# THE HEIGHT IS THE TOP OF EVERYTHING, stacks and fans included: a locomotive that clears its own published height
	# does not clear a tunnel either.
	_check("and_nothing_stands_above_the_published_height", _near(whole.size.y, HEIGHT) and whole.size.y <= HEIGHT * 1.01,
		"%.3f m against 15 ft 7 1/8 in = %.3f" % [whole.size.y, HEIGHT])
	_check("and_it_stands_on_the_railhead", absf(whole.position.y) <= 0.002,
		"its lowest drawn point is %.4f m over the rail" % whole.position.y)


## THE WALKWAY WHERE THE PHOTOGRAPH PUTS IT. Everything else here is measured from the railhead, so a deck at the wrong
## height passes every other check in this file with slightly shorter hoods on it.
func _the_walkway_is_where_the_photograph_puts_it(parts: Dictionary) -> void:
	var deck: float = (parts["Frame"] as AABB).end.y
	_check("the_walkway_stands_where_the_broadside_puts_it", absf(deck - WALKWAY) <= WALKWAY_WITHIN,
		"%.3f m over the railhead against a measured %.3f" % [deck, WALKWAY])


## ---- 3. the shape of a Dash-2 ------------------------------------------------------------------

func _the_cab_sits_below_the_long_hood(parts: Dictionary) -> void:
	var cab: float = (parts["Cab"] as AABB).end.y
	var hood: float = (parts["LongHood"] as AABB).end.y
	var nose: float = (parts["ShortHood"] as AABB).end.y
	var radiator: AABB = parts["Radiator"] as AABB
	# A ROOF ABOVE ITS HOOD IS A SWITCHER. The gap is held to at least 5 cm so a model that levels the two cannot pass.
	_check("the_cab_roof_sits_below_the_long_hood", cab < hood - 0.05,
		"the cab at %.2f m, the hood at %.2f" % [cab, hood])
	_check("and_the_short_hood_is_a_low_nose_below_the_cab", nose < cab - 0.30,
		"the nose at %.2f m, the cab at %.2f" % [nose, cab])
	# THE RADIATOR FLARES: it stands out past the hood's sides, which is what the flare is for and what says at a glance
	# which end of the locomotive you are looking at. Held on WIDTH, not height -- the hood's own box includes the stacks
	# standing on its roof, so "taller than the hood" compares the flare with a chimney.
	_check("and_the_radiator_flares_out_past_the_hood_sides",
		radiator.size.x > (parts["LongHood"] as AABB).size.x + 0.05 and radiator.end.y > cab,
		"the radiator %.2f m across and %.2f m tall, the hood %.2f across"
		% [radiator.size.x, radiator.end.y, (parts["LongHood"] as AABB).size.x])
	# AND THE CAB IS FORWARD OF THE LONG HOOD, which is the other half of the silhouette.
	var cab_at: float = (parts["Cab"] as AABB).get_center().z
	var hood_at: float = (parts["LongHood"] as AABB).get_center().z
	_check("and_the_cab_stands_ahead_of_the_long_hood", cab_at < hood_at,
		"the cab at z %.2f, the hood at %.2f (-Z is forward)" % [cab_at, hood_at])


## ---- 4 and 5. the running gear -------------------------------------------------------------------

func _it_has_twelve_forty_inch_wheels_on_the_railhead(wheels: Array) -> void:
	_check("it_has_twelve_wheels", wheels.size() == WHEELS, "%d found" % wheels.size())
	if wheels.is_empty():
		return
	var worst_flats: float = 0.0
	var worst_down: float = 0.0
	var worst_across: float = 0.0
	var sides_ok: bool = true
	var seen_sides: int = 0
	for wheel in wheels:
		var box: AABB = _box_of(wheel)
		# ACROSS THE FLATS is what a faceted wheel's diameter means, and the check has to say which it means: an
		# eight-sided prism drawn round its circle is wider corner to corner than it is flat to flat.
		worst_flats = maxf(worst_flats, absf(box.size.y - WHEEL))
		worst_down = maxf(worst_down, absf(box.position.y))
		worst_across = maxf(worst_across, absf(absf(box.get_center().x) - (GAUGE + HEAD_WIDE) * 0.5))
		var corners: Dictionary = {}
		for point in (wheel as PackedVector3Array):
			corners["%.3f,%.3f" % [point.y, point.z]] = true
		# EIGHT CORNERS AND A HUB, counted in the plane of the wheel: each corner is drawn on both faces, at one (y, z).
		seen_sides = corners.size()
		if corners.size() != WHEEL_SIDES + 1:
			sides_ok = false
	_check("and_each_is_the_published_forty_inches_across_its_flats", worst_flats <= WHEEL * CLOSE,
		"worst %.4f m off %.4f" % [worst_flats, WHEEL])
	_check("and_each_stands_on_the_railhead", worst_down <= 0.002, "worst %.4f m off it" % worst_down)
	_check("and_each_runs_over_a_railhead", worst_across <= CLOSE,
		"worst %.4f m off %.4f from the middle" % [worst_across, (GAUGE + HEAD_WIDE) * 0.5])
	# EIGHT SIDES, counted from the drawn corners rather than from the constant that made them.
	_check("and_each_is_an_eight_sided_prism_rather_than_a_smooth_cylinder", sides_ok,
		"a wheel has %d distinct corners in its own plane, wanted %d" % [seen_sides, WHEEL_SIDES + 1])


func _they_are_two_trucks_at_the_published_centres(wheels: Array) -> void:
	if wheels.size() != WHEELS:
		return
	# THE AXLES, from the wheels themselves: each axle is a pair at one station.
	var stations: Array[float] = []
	for wheel in wheels:
		var at: float = _box_of(wheel).get_center().z
		var known: bool = false
		for station in stations:
			if absf(station - at) < 0.05:
				known = true
		if not known:
			stations.append(at)
	stations.sort()
	_check("its_wheels_are_six_axles", stations.size() == 6, "%d axles" % stations.size())
	if stations.size() != 6:
		return
	var front: float = (stations[0] + stations[1] + stations[2]) / 3.0
	var rear: float = (stations[3] + stations[4] + stations[5]) / 3.0
	_check("and_two_trucks_at_the_published_centres", absf(rear - front - TRUCK_CENTRES) <= TRUCK_CENTRES * CLOSE,
		"%.3f m apart against 43 ft 6 in = %.3f" % [rear - front, TRUCK_CENTRES])
	var wheelbase: float = maxf(stations[2] - stations[0], stations[5] - stations[3])
	_check("and_each_truck_at_the_published_wheelbase", absf(wheelbase - TRUCK_WHEELBASE) <= TRUCK_WHEELBASE * CLOSE,
		"%.3f m axle to axle against 13 ft 7 in = %.3f" % [wheelbase, TRUCK_WHEELBASE])


## ---- 6. it is one object, drawn outwards ----------------------------------------------------------

## NOTHING FLOATS: the parts' boxes, joined where they meet on all three axes, make ONE group. A dimension is right
## whether or not a part is attached, and a box round a detached part still contains it -- the tanker's tail assembly
## hung in mid-air through every suite in the game (`modelling_here.md` section 6).
func _nothing_floats_and_nothing_is_inside_out(loco: Node3D, parts: Dictionary) -> void:
	var names: Array = parts.keys()
	var home: Dictionary = {}
	for title in names:
		home[title] = title
	for a in names:
		for b in names:
			if a == b:
				continue
			if _touching(parts[a], parts[b]):
				var root_a: String = _root(home, a)
				var root_b: String = _root(home, b)
				if root_a != root_b:
					home[root_b] = root_a
	var groups: Dictionary = {}
	for title in names:
		groups[_root(home, title)] = true
	_check("every_part_of_it_touches_another", groups.size() == 1,
		"%d separate groups of %d parts" % [groups.size(), names.size()])

	var wrong: int = 0
	var total: int = 0
	for found in loco.find_children("*", "MeshInstance3D", true, false):
		var drawn := found as MeshInstance3D
		for s in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in range(0, points.size() - 2, 3):
				total += 1
				var face: Vector3 = (points[i + 2] - points[i]).cross(points[i + 1] - points[i])
				if face.dot(normals[i]) < 0.0:
					wrong += 1
	_check("and_every_face_is_wound_outwards", wrong == 0 and total > 0, "%d of %d wound inwards" % [wrong, total])


func _it_is_within_its_triangles(loco: Node3D) -> void:
	var triangles: int = 0
	var materials: Dictionary = {}
	for found in loco.find_children("*", "MeshInstance3D", true, false):
		var drawn := found as MeshInstance3D
		materials[drawn.material_override] = true
		for s in range(drawn.mesh.get_surface_count()):
			triangles += (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check("it_is_within_its_triangle_budget", triangles <= TRIANGLES,
		"%d triangles against %d" % [triangles, TRIANGLES])
	_check("and_wears_one_material", materials.size() == 1, "%d materials" % materials.size())


## ---- reading the drawn locomotive ------------------------------------------------------------------

func _parts_of(loco: Node3D) -> Dictionary:
	var out: Dictionary = {}
	for found in loco.find_children("*", "MeshInstance3D", true, false):
		var drawn := found as MeshInstance3D
		if drawn.mesh == null:
			continue
		out[String(drawn.name)] = _box_of(_vertices_of(drawn))
	return out


func _vertices_of(drawn: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in range(drawn.mesh.get_surface_count()):
		for point in (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(drawn.transform * point)
	return out


func _every_vertex(loco: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for found in loco.find_children("*", "MeshInstance3D", true, false):
		out.append_array(_vertices_of(found as MeshInstance3D))
	return out


## THE WHEELS, picked out of the trucks by their paint and grouped one to a wheel by single linkage, as
## `tests/track_drawn.gd` does: a wheel's hub is 0.5 m from its rim and two wheels are never within it.
func _wheels_of(loco: Node3D) -> Array:
	var painted := PackedVector3Array()
	for found in loco.find_children("Truck*", "MeshInstance3D", true, false):
		var drawn := found as MeshInstance3D
		for s in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for i in range(points.size()):
				var c: Color = colours[i]
				if absf(c.r - RoadDiesel.WHEEL_PAINT.r) + absf(c.g - RoadDiesel.WHEEL_PAINT.g) \
						+ absf(c.b - RoadDiesel.WHEEL_PAINT.b) <= 0.02:
					painted.append(drawn.transform * points[i])
	var home := PackedInt32Array()
	home.resize(painted.size())
	for i in range(painted.size()):
		home[i] = i
	for i in range(painted.size()):
		for j in range(i + 1, painted.size()):
			# 0.6 m, not 0.5: a 40 in wheel's hub is 0.55 m from its rim, and at 0.5 every hub was a wheel of its own.
			# The nearest corners of two different wheels are 0.97 m apart.
			if painted[i].distance_to(painted[j]) < 0.6:
				var a: int = _root_of(home, i)
				var b: int = _root_of(home, j)
				if a != b:
					home[b] = a
	var by_root: Dictionary = {}
	for i in range(painted.size()):
		var root: int = _root_of(home, i)
		if not by_root.has(root):
			by_root[root] = []
		(by_root[root] as Array).append(painted[i])
	var out: Array = []
	for root in by_root:
		out.append(PackedVector3Array(by_root[root]))
	return out


func _root_of(home: PackedInt32Array, i: int) -> int:
	while home[i] != i:
		i = home[i]
	return i


func _root(home: Dictionary, key: String) -> String:
	while String(home[key]) != key:
		key = String(home[key])
	return key


## Two boxes touch when their spans meet on all three axes, within a millimetre.
func _touching(a: AABB, b: AABB) -> bool:
	var grown := AABB(a.position - Vector3.ONE * 0.001, a.size + Vector3.ONE * 0.002)
	return grown.intersects(b)


func _box_of(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	return box


func _near(value: float, published: float) -> bool:
	return absf(value - published) <= published * WITHIN


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
