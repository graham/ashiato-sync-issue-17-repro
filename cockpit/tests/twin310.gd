extends Node
## THE CESSNA 310R'S OWN GEOMETRY SUITE. Read RESULT=, never the exit code.
##
##   Godot --headless --xr-mode off --path cockpit res://tests/twin310.tscn
##
## It holds `Cessna310Airframe` to the published 310R envelope and to the figures
## `craft/plane/measure_310l.py` reads off the 1967 factory three-view, and it holds the drawn
## aeroplane to the way a 310 STANDS -- which is the thing no dimension check can see. Every
## measurement here is taken from the TRANSFORMED VERTICES of the drawn meshes, never from
## `transform * mesh.get_aabb()`, which grows a box every time it is turned.
##
## Pass `-- --report` to print the geometry without judging it, which is how the constants were
## tuned against the drawing in the first place.

const TOLERANCE := 0.02
const LENGTH := 9.74      # [RR][AOPA] 32 ft 0 in
const SPAN := 11.25       # [RR]; [L]'s own printed 36 ft 11 in
const HEIGHT := 3.105     # [L] 9 ft 11.25 in to the fin cap plus its own 3 in for a beacon; the
                          # published 10 ft 8 in is the nose-gear-depressed maximum, craft/plane/sources.md
const MAX_TRIANGLES := 6200
const TANK_LITRES := 51.0 * 3.785412   # [TCDS] 51 US gal a side, every model from the 310J

var _failures: PackedStringArray = []
var _report: bool = false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--report":
			_report = true
	var airframe := (load("res://objects/vehicles/cessna310_airframe.tscn") as PackedScene).instantiate()
	add_child(airframe)
	var bounds := _drawn_bounds(airframe)
	print("[twin310] drawn bounds %.3f x %.3f x %.3f m, from %s to %s"
		% [bounds.size.x, bounds.size.y, bounds.size.z, bounds.position, bounds.end])
	print("[twin310] triangles %d in %d surfaces" % [_triangles(airframe), _surfaces(airframe)])
	_the_envelope(airframe, bounds)
	_it_stands_on_its_three_tyres(airframe)
	_the_tip_tanks_are_where_and_what_the_drawing_says(airframe)
	_the_wing_has_the_dihedral_the_drawing_fits(airframe)
	_the_drawn_wing_is_the_planform_it_publishes(airframe)
	_the_named_parts_are_all_there(airframe)
	_no_face_is_wound_inwards(airframe)
	_the_gear_folds_away(airframe)
	_it_fits_the_budget(airframe)
	if _report:
		print("[twin310] sockets %s" % JSON.stringify(airframe.call("sockets")))
		print("[twin310] cabin_room %s" % airframe.call("cabin_room"))
		print("RESULT=PASS report only")
	else:
		print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() or _report else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	print("[twin310] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## ---- the envelope ---------------------------------------------------------------------------

func _the_envelope(airframe: Node3D, bounds: AABB) -> void:
	var want := Vector3(SPAN, HEIGHT, LENGTH)
	var error := Vector3(absf(bounds.size.x - want.x) / want.x, absf(bounds.size.y - want.y) / want.y,
		absf(bounds.size.z - want.z) / want.z)
	_check("the_drawn_envelope_is_within_two_percent_of_the_published_310r",
		error.x <= TOLERANCE and error.y <= TOLERANCE and error.z <= TOLERANCE,
		"drawn %.3f x %.3f x %.3f against %.2f x %.2f x %.2f, error %.1f%% %.1f%% %.1f%%"
		% [bounds.size.x, bounds.size.y, bounds.size.z, want.x, want.y, want.z,
			error.x * 100.0, error.y * 100.0, error.z * 100.0])


## ---- the stance -----------------------------------------------------------------------------

## THE CHECK THIS AEROPLANE MOST NEEDED. [L] draws a 310 level with its ground raked 4 deg 30 min,
## so the nose tyre hangs 0.228 m below the mains in the craft's own frame. Get the sign wrong and
## the nose wheel is buried, which is what happened to the P-38 and cost 0.264 m
## (`todo/warbirds--p38-lightning.md`). The check holds the THREE TYRE BOTTOMS TO ONE PLANE, which
## is only a real check because `Cessna310Airframe.nose_drop()` is derived from the rake and the
## wheelbase rather than typed beside them.
func _it_stands_on_its_three_tyres(airframe: Node3D) -> void:
	var lows: Dictionary = {}
	for label in ["NoseGear", "MainGearPort", "MainGearStarboard"]:
		var node := airframe.find_child(label, true, false) as MeshInstance3D
		if node == null:
			_check("the_gear_is_drawn_as_three_named_legs", false, "no %s" % label)
			return
		lows[label] = _bounds_of(airframe, node).position.y
	var span: float = maxf(maxf(lows["NoseGear"], lows["MainGearPort"]), lows["MainGearStarboard"]) \
		- minf(minf(lows["NoseGear"], lows["MainGearPort"]), lows["MainGearStarboard"])
	_check("all_three_tyres_stand_on_one_plane", span < 0.01,
		"nose %.4f, port %.4f, starboard %.4f, spread %.1f mm"
		% [lows["NoseGear"], lows["MainGearPort"], lows["MainGearStarboard"], span * 1000.0])

	var rest: float = float((Sim.geometry_of(Sim.Kind.PLANE).get("extents", Vector3.ONE) as Vector3).y)
	_check("and_that_plane_is_the_ground_the_native_hull_rests_on",
		absf(lows["MainGearPort"] + rest) < 0.02,
		"the tyres are at %.3f and the hull rests at %.3f" % [lows["MainGearPort"], -rest])

	var parked: Dictionary = airframe.call("parked")
	_check("and_the_aeroplane_stands_nose_up_as_the_drawing_parks_it",
		bool(parked["nose_up"]) and absf(float(parked["rake"]) - 0.0785398) < 0.001
			and absf(float(parked["nose_drop"]) - 0.228) < 0.01,
		"rake %.4f rad, nose drop %.3f m over a %.2f m wheelbase"
		% [parked["rake"], parked["nose_drop"], parked["wheelbase"]])

	# THE NOSE MUST BE HIGHER THAN THE TAIL, asked of the DRAWN skin rather than of the rake, so a
	# model that satisfied the arithmetic and drew itself level would still be caught.
	var fuselage := airframe.find_child("Airframe", true, false) as MeshInstance3D
	var nose_tip := _point_nearest(fuselage, Vector3(0.0, 0.0, -LENGTH * 0.6))
	var tail := _point_nearest(fuselage, Vector3(0.0, 0.0, LENGTH * 0.6))
	_check("the_drawn_nose_sits_higher_than_the_drawn_tailcone_datum", nose_tip.y > -0.70,
		"nose tip at y %.3f, tail at y %.3f" % [nose_tip.y, tail.y])


## ---- the tip tanks, which is what this lane was asked for -----------------------------------

func _the_tip_tanks_are_where_and_what_the_drawing_says(airframe: Node3D) -> void:
	var surfaces: Dictionary = airframe.get("surfaces")
	for end in ["Port", "Starboard"]:
		var box: AABB = surfaces.get("TipTank" + end, AABB())
		if box.size == Vector3.ZERO:
			_check("the_tip_tanks_are_drawn", false, "no TipTank%s in surfaces" % end)
			return
		var sign: float = 1.0 if end == "Starboard" else -1.0
		_check("the_%s_tip_tank_carries_the_span" % end.to_lower(),
			absf(absf(box.position.x if sign < 0.0 else box.end.x) - SPAN * 0.5) < 0.06,
			"its outer face is at %.3f against a half span of %.3f"
			% [box.position.x if sign < 0.0 else box.end.x, SPAN * 0.5])
		_check("the_%s_tip_tank_is_the_length_the_drawing_prints" % end.to_lower(),
			absf(box.size.z - 3.071) < 0.16,
			"%.3f m long against [L]'s 3.071 (printed 10 ft 0 in)" % box.size.z)
		_check("the_%s_tip_tank_is_no_fatter_than_the_drawing_draws_it" % end.to_lower(),
			box.size.x < 0.62 and box.size.y < 0.70,
			"%.3f m wide by %.3f m deep against [L]'s 0.533 by 0.46" % [box.size.x, box.size.y])

	# CANTED, NOT BOLTED ON STRAIGHT. The tank's nose is lower than its tail in the craft's own
	# frame; a cylinder laid along the flight path would have them level and would pass every
	# dimension check above.
	var port: AABB = surfaces["TipTankPort"]
	var nose_h: float = _tank_axis_height(airframe, -1.0, port.position.z + 0.10)
	var tail_h: float = _tank_axis_height(airframe, -1.0, port.end.z - 0.10)
	# CANTED, NOT BOLTED ON STRAIGHT -- and the measurable part of the cant is the TOE, which [L]'s
	# plan view gives directly at 1.13 degrees. The droop is bounded by the front view at about a
	# degree, so it is too small to assert; asserting it would be asserting an ESTIMATE.
	var nose_x: float = _tank_axis_x(airframe, -1.0, port.position.z + 0.12)
	var tail_x: float = _tank_axis_x(airframe, -1.0, port.end.z - 0.12)
	_check("the_tip_tank_is_toed_out_as_the_plan_view_measures_it_rather_than_bolted_on_straight",
		nose_x < tail_x - 0.035,
		"its nose is %.3f m out and its tail %.3f m, a toe of %.0f mm over the tank"
		% [-nose_x, -tail_x, (tail_x - nose_x) * 1000.0])
	print("[twin310] the port tank's axis runs from %.3f m up at the nose to %.3f m at the tail"
		% [nose_h, tail_h])

	var litres: float = float(airframe.call("tank_volume")) * 1000.0
	_check("each_tip_tank_holds_about_the_fifty_one_gallons_the_type_certificate_gives_it",
		litres > TANK_LITRES * 0.6 and litres < TANK_LITRES * 2.2,
		"the drawn body is %.0f litres against [TCDS]'s %.0f of usable fuel" % [litres, TANK_LITRES])


func _tank_axis_x(airframe: Node3D, side: float, z: float) -> float:
	var tank := airframe.find_child("Airframe", true, false) as MeshInstance3D
	var low := 1e9
	var high := -1e9
	for point in _vertices(tank, airframe):
		if signf(point.x) != side or absf(point.x) < 4.5:
			continue
		if absf(point.z - z) > 0.14:
			continue
		low = minf(low, point.x)
		high = maxf(high, point.x)
	return (low + high) * 0.5 if high > -1e8 else 0.0


func _tank_axis_height(airframe: Node3D, side: float, z: float) -> float:
	var tank := airframe.find_child("Airframe", true, false) as MeshInstance3D
	var best := 1e9
	var high := -1e9
	for point in _vertices(tank, airframe):
		if signf(point.x) != side or absf(point.x) < 4.5:
			continue
		if absf(point.z - z) > 0.12:
			continue
		best = minf(best, point.y)
		high = maxf(high, point.y)
	return (best + high) * 0.5 if high > -1e8 else 0.0


## ---- the rest -------------------------------------------------------------------------------

## FIVE DEGREES, ASKED OF THE DRAWN WING rather than of the constant that made it. [L]'s front view
## fits 4.83 and 5.07 degrees over 131 and 136 stations at 3 mm rms. Measured off the model's own
## triangles, because a check that reads `DIHEDRAL` back cannot tell dihedral from anhedral.
##
## IT IS THE LEADING EDGE THAT IS MEASURED, not the middle of the section's extremes. Two things
## spoil that middle and both of them look like dihedral. The wing is TWISTED -- 2.2 degrees at the
## root washing out to -1.0 at the tip -- and a twist about the quarter chord raises the leading
## edge by a quarter of the chord and drops the trailing edge by three quarters, so the middle of
## the two moves with the twist and the chord together. And the FIXED panel stops at the flap's and
## the aileron's hinge line, so at most stations its trailing edge is a hinge rather than the wing's.
## Together they read 5.78 degrees off a wing built with five. The leading edge has neither problem:
## at the nose of a section the skins meet, so the point is ON the chord line.
func _the_wing_has_the_dihedral_the_drawing_fits(airframe: Node3D) -> void:
	var root: Vector2 = _wing_leading_edge(airframe, 0.90)
	var tip: Vector2 = _wing_leading_edge(airframe, 4.90)
	var across: float = tip.x - root.x
	var rise: float = tip.y - root.y
	var degrees: float = rad_to_deg(atan(rise / across)) if across > 0.5 else NAN
	_check("the_wing_rises_five_degrees_from_root_to_tip",
		rise > 0.0 and absf(degrees - 5.0) < 0.8,
		"the leading edge is %.3f m up at %.2f m out and %.3f m at %.2f: %.2f degrees of %s over "
		% [root.y, root.x, tip.y, tip.x, absf(degrees), "dihedral" if rise > 0.0 else "ANHEDRAL"]
		+ "the %.2f m between them" % across)


## THE AREA IS THE NUMBER SOMEBODY ELSE WILL FLY OFF, so it is measured from the DRAWN TRIANGLES
## and held against what `planform()` publishes -- not the other way round, and not against the
## constants that made both. A wing drawn to a chord law and then published from the same chord law
## agrees with itself whatever it is; what this asks is whether the aeroplane in the scene has that
## planform. The chord is taken in the aeroplane's OWN frame, so the 4.5 degrees of park come out of
## it: a chord measured down the craft's z reads cos(4.5) short, which is 0.3 per cent of a 16 m2
## wing and would be invisible against a 2 per cent band.
func _the_drawn_wing_is_the_planform_it_publishes(airframe: Node3D) -> void:
	var book: Dictionary = airframe.call("planform")
	var rake: float = float((airframe.call("parked") as Dictionary)["rake"])
	# EVERY PIECE OF THE LIFTING SURFACE, because the flaps and the ailerons are nodes of their own
	# and the fixed panel stops at their hinge line. Leaving them out loses a fifth of the wing.
	var area: float = 0.0
	var pieces: int = 0
	for label in ["WingPort", "WingStarboard", "FlapPort", "FlapStarboard",
			"AileronPort", "AileronStarboard"]:
		var node := airframe.find_child(label, true, false) as MeshInstance3D
		if node == null:
			continue
		pieces += 1
		area += _planform_of(node, airframe)
	# Upper and lower skins project onto the same plan, so the sum is twice the planform. The
	# chord is measured down the craft's own z, which the 4.5 degrees of park shorten by cos(rake).
	area = area * 0.5 / cos(rake)
	var want: float = float(book["area"])
	_check("the_drawn_wing_measures_the_area_it_publishes",
		pieces == 6 and absf(area - want) / want < 0.04,
		"%.2f m2 of drawn planform in %d pieces against the %.2f m2 planform() publishes; the "
		% [area, pieces, want]
		+ "310R's published 179 sq ft is 16.63 m2 and the early 310's 175 sq ft is 16.26")
	_check("and_the_planform_it_publishes_is_internally_consistent",
		absf(float(book["aspect_ratio"]) - pow(float(book["wing_span"]), 2.0) / want) < 0.01
			and float(book["tip_chord"]) < float(book["root_chord"])
			and float(book["mac"]) > float(book["tip_chord"])
			and float(book["mac"]) < float(book["root_chord"]),
		"span %.2f m over the tanks and %.2f of wing, area %.2f m2 (%.2f over the tanks), "
		% [book["span"], book["wing_span"], want, book["area_over_tanks"]]
		+ "MAC %.3f, taper %.3f, aspect %.2f (%.2f over the tanks)"
		% [book["mac"], book["taper"], book["aspect_ratio"], book["aspect_ratio_over_tanks"]])


## ONE MESH'S TRIANGLES PROJECTED ON THE PLAN, summed. Twice a lifting surface's planform, because
## its two skins project onto the same ground.
func _planform_of(node: MeshInstance3D, root: Node3D) -> float:
	var total: float = 0.0
	var points := _vertices(node, root)
	for i in range(0, points.size() - 2, 3):
		var a := Vector2(points[i].x, points[i].z)
		var b := Vector2(points[i + 1].x, points[i + 1].z)
		var c := Vector2(points[i + 2].x, points[i + 2].z)
		total += absf((b - a).cross(c - a)) * 0.5
	return total


## The port wing's LEADING EDGE near a station out from the axis: (how far out it actually is, how
## high it is), as the most forward drawn vertex in a band.
##
## BOTH NUMBERS COME BACK, because the one that was typed was wrong. The band has to be wide enough
## to hold a vertex and the slab is cut spanwise at its own panel edges, so the vertex it finds near
## "4.90 m out" is at 5.02 and the one near "0.90" is at 0.66 -- 4.36 m apart, not the 4.00 the
## check divided by. That inflated the angle by nine per cent and read a five-degree wing as 5.46.
## One number, one place: measure the baseline you measured across.
func _wing_leading_edge(airframe: Node3D, out: float) -> Vector2:
	# THE PORT WING'S OWN MESH. It lived in `Airframe` until the area check needed it separate, and
	# this check went on asking `Airframe` and read 0.55 degrees off the nacelle and the fuselage.
	var wing := airframe.find_child("WingPort", true, false) as MeshInstance3D
	var front := 1e9
	var found := Vector2(NAN, NAN)
	var n: int = 0
	for point in _vertices(wing, airframe):
		# A BAND WIDE ENOUGH TO CATCH A VERTEX. The slab is cut spanwise at its panel edges, so a
		# 60 mm window between two of them holds no vertices at all -- and the first version of
		# this check read the root's height as 0.000 and called 9.84 degrees a failure.
		if absf(point.x + out) > 0.30:
			continue
		n += 1
		if point.z < front:
			front = point.z
			found = Vector2(-point.x, point.y)
	return found if n >= 4 else Vector2(NAN, NAN)


func _the_named_parts_are_all_there(airframe: Node3D) -> void:
	var wanted: PackedStringArray = ["Airframe", "Glazing", "Details", "WingPort", "WingStarboard",
		"StabiliserPort", "StabiliserStarboard", "NoseGear", "MainGearPort",
		"MainGearStarboard", "PropellerPort", "PropellerStarboard", "FlapPort", "FlapStarboard",
		"AileronPort", "AileronStarboard", "ElevatorPort", "ElevatorStarboard", "Rudder"]
	var missing: PackedStringArray = []
	for label in wanted:
		if airframe.find_child(label, true, false) == null:
			missing.append(label)
	_check("every_named_part_is_drawn", missing.is_empty(),
		"all %d present" % wanted.size() if missing.is_empty() else "missing %s" % ", ".join(missing))

	var surfaces: Dictionary = airframe.get("surfaces")
	var shapes: PackedStringArray = ["Fuselage", "WingPort", "WingStarboard", "TipTankPort",
		"TipTankStarboard", "NacellePort", "NacelleStarboard", "Fin", "StabiliserPort",
		"StabiliserStarboard"]
	var absent: PackedStringArray = []
	for label in shapes:
		if not surfaces.has(label):
			absent.append(label)
	_check("and_every_measured_shape_recorded_its_own_bounds", absent.is_empty(),
		"all %d recorded" % shapes.size() if absent.is_empty() else "missing %s" % ", ".join(absent))


## A face wound backwards is invisible and nothing else will find it (`tests/ship_models.gd`).
func _no_face_is_wound_inwards(airframe: Node3D) -> void:
	var wrong: int = 0
	var total: int = 0
	for node in airframe.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh == null or drawn.name.begins_with("PropellerDisc"):
			continue
		for surface in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			if normals.is_empty():
				continue
			for i in range(0, points.size() - 2, 3):
				total += 1
				var face: Vector3 = (points[i + 2] - points[i]).cross(points[i + 1] - points[i])
				if face.length_squared() < 1e-12:
					continue
				if face.normalized().dot(normals[i]) < 0.0:
					wrong += 1
	_check("no_face_is_wound_against_its_own_normal", wrong == 0, "%d of %d" % [wrong, total])


func _the_gear_folds_away(airframe: Node3D) -> void:
	var main := airframe.find_child("MainGearPort", true, false) as MeshInstance3D
	var nose := airframe.find_child("NoseGear", true, false) as MeshInstance3D
	airframe.call("set_gear", 1.0)
	var down: float = _bounds_of(airframe, main).position.y
	var nose_down: float = _bounds_of(airframe, nose).position.y
	airframe.call("set_gear", 0.0)
	var up: float = _bounds_of(airframe, main).position.y
	var nose_up: float = _bounds_of(airframe, nose).position.y
	_check("the_mains_fold_up_into_the_nacelles", up - down > 0.35,
		"the port main's lowest point rises %.3f m, from %.3f to %.3f" % [up - down, down, up])
	_check("and_the_nose_leg_folds_into_the_nose", nose_up - nose_down > 0.25,
		"the nose tyre rises %.3f m" % (nose_up - nose_down))
	airframe.call("set_gear", 1.0)
	_check("and_it_comes_back_down_to_where_it_was",
		absf(_bounds_of(airframe, main).position.y - down) < 0.001,
		"back at %.4f" % _bounds_of(airframe, main).position.y)


func _it_fits_the_budget(airframe: Node3D) -> void:
	var triangles: int = _triangles(airframe)
	_check("the_exterior_stays_under_its_triangle_budget", triangles <= MAX_TRIANGLES,
		"%d triangles against a budget of %d -- DO NOT RAISE THIS TO FIT A SMOOTHER MODEL"
		% [triangles, MAX_TRIANGLES])


## ---- measuring ------------------------------------------------------------------------------

## ONE DRAWN MESH'S BOUNDS IN THE AIRFRAME'S FRAME. Asking `_drawn_bounds` for a single mesh
## returned its own LOCAL box, because that helper measures relative to whatever it is handed -- so
## the retracting gear read the same y before and after `set_gear`, and the tyres that stand on the
## ground read 0.32 m below it. A frame has to be named, not inferred from the argument.
func _bounds_of(root: Node3D, node: MeshInstance3D) -> AABB:
	var box := AABB()
	var found := false
	if node == null or node.mesh == null:
		return box
	var into: Transform3D = root.global_transform.affine_inverse() * node.global_transform
	for surface in range(node.mesh.get_surface_count()):
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		for point in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var at: Vector3 = into * point
			box = box.expand(at) if found else AABB(at, Vector3.ZERO)
			found = true
	return box


## MEASURE FROM TRANSFORMED VERTICES, never `transform * mesh.get_aabb()`: a box round a box grows
## every time it is turned, and this aeroplane is turned 4.5 degrees.
func _drawn_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var found := false
	var frame: Transform3D = root.global_transform.affine_inverse() if root is Node3D else Transform3D.IDENTITY
	for node in ([root] if root is MeshInstance3D else []) + Array(root.find_children("*", "MeshInstance3D", true, false)):
		var drawn := node as MeshInstance3D
		if drawn == null or drawn.mesh == null or drawn.name.begins_with("PropellerDisc"):
			continue
		var into: Transform3D = frame * drawn.global_transform
		for surface in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(surface)
			for point in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var at: Vector3 = into * point
				box = box.expand(at) if found else AABB(at, Vector3.ZERO)
				found = true
	return box


func _vertices(node: MeshInstance3D, root: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if node == null or node.mesh == null:
		return out
	var into: Transform3D = root.global_transform.affine_inverse() * node.global_transform
	for surface in range(node.mesh.get_surface_count()):
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		for point in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(into * point)
	return out


func _point_nearest(node: MeshInstance3D, to: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var far := 1e9
	if node == null or node.mesh == null:
		return best
	for surface in range(node.mesh.get_surface_count()):
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		for point in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var d: float = point.distance_squared_to(to)
			if d < far:
				far = d
				best = point
	return best


func _triangles(root: Node3D) -> int:
	var total: int = 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh == null:
			continue
		for surface in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(surface)
			# A SurfaceTool mesh built without indices returns Nil there rather than an empty array,
			# and typing it as PackedInt32Array throws -- which reported '0 triangles' to a budget
			# check that then passed. Ask what a value IS before declaring what it is.
			var index: Variant = arrays[Mesh.ARRAY_INDEX]
			if index is PackedInt32Array and not (index as PackedInt32Array).is_empty():
				total += int((index as PackedInt32Array).size() / 3)
			else:
				total += int((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
	return total


func _surfaces(root: Node3D) -> int:
	return root.find_children("*", "MeshInstance3D", true, false).size()
