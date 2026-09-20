extends Node
## Headless: does every light of every kind stand on its own craft's drawn skin, and does every kind that should carry
## lights carry them where a real aircraft does?
##
##   Godot --headless --path cockpit res://tests/lights_on_skin.tscn
##
## Asked for on 2026-09-17: "some vehicles have their anti collision lights not on the plane". They were not: every winged
## craft but the fighter had its lights worked out from the collision box and the aerodynamic span, and the airframes
## were rebuilt round them. The gunship's wingtip lights hung 20.2 m out in the air, the Mercury's top beacon 6.2 m over
## its fin, the airliner's 5.7, the sailplane's 5.2, the Osprey's 3.9, the utility twin's 3.1, and the Cessna's 2.4 m
## off the beacon rod it draws. See `VehicleLights.for_view` for what places them now.
##
## ANCHORED OUTSIDE THE LIGHTS. The distance is from each light's centre to the nearest DRAWN TRIANGLE of its own view,
## worked out here with Ericson's closest point on a triangle (Real-Time Collision Detection 5.1.5) over the mesh faces
## of every shown MeshInstance3D -- never a `transform * get_aabb()`, which would put a light "on" the air inside a box
## round a swept wing. The lights are read off the built node (`VehicleLights.lamps`) because a MultiMesh on the headless
## renderer reads every instance back as zero.
##
## - ON THE SKIN. Every light within `VehicleLights.ON_SKIN` of a drawn triangle.
## - WHERE A REAL ONE IS. Red left of the centreline and green right; the white tail light aft of the tips; the top red
##   beacon with no drawn skin over it.
## - CONTRAILS FROM A WING. A craft with a wing hands `ContrailYard` its two tips, where its red and green stand; a craft
##   without one, a helicopter among them, hands none.
## - EVERY KIND VISITED. All of `Sim.Kind`, and every kind `carries_lights` names had lights to measure: a check that never
##   visited a craft is not evidence about it. Nothing that drives or sails carries any.
## - THE MUTANT. One light of a real craft moved half a metre off its skin, and the same measurement reads it off.
##
## Read RESULT=, not the exit code.

## How far aft of the nav lights the tail light must be, metres: the UH-60's nav lights are on its stabilator, 0.48 m
## ahead of its tail light.
const TAIL_AFT_OF_TIPS: float = 0.25
## How far round the top beacon no drawn point may stand above it, metres: a beacon tucked under a wing or a fin's overhang
## is on a skin and still cannot be seen from above.
const OPEN_ABOVE: float = 0.3

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lights_on_skin] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL the native library is not loaded")
		get_tree().quit(1)
		return
	var visited: PackedStringArray = []
	var lit: PackedStringArray = []
	var off: PackedStringArray = []
	var wrong: PackedStringArray = []
	var worst: float = 0.0
	var worst_of: String = ""
	var mutant_caught: bool = false
	var mutant_detail: String = ""
	for kind in range(Sim.Kind.size()):
		var label: String = Sim.kind_name(kind)
		var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
		add_child(view)
		view.setup(0, kind)
		visited.append(label)
		var lamps: Array = lamps_of(view)
		var faces: PackedVector3Array = drawn_faces(view)
		if lamps.is_empty():
			if VehicleLights.carries_lights(kind):
				wrong.append("%s: carries no lights" % label)
		else:
			lit.append(label)
			if not VehicleLights.carries_lights(kind):
				wrong.append("%s: drives or sails, and carries lights" % label)
		print("[lights_on_skin] %s: %d lights, %d triangles" % [label, lamps.size(), faces.size() / 3])
		for lamp in lamps:
			var distance: float = nearest(lamp["position"], faces)
			if distance > worst:
				worst = distance
				worst_of = "%s %s %s" % [label, lamp["what"], lamp["pattern"]]
			print("[lights_on_skin]   %-6s %-7s at (%6.2f, %6.2f, %6.2f)  %.3f m off the skin" % [lamp["what"],
				lamp["pattern"], lamp["position"].x, lamp["position"].y, lamp["position"].z, distance])
			if distance > VehicleLights.ON_SKIN:
				off.append("%s %s %s %.2f m off" % [label, lamp["what"], lamp["pattern"], distance])
		if not lamps.is_empty():
			wrong.append_array(_where_a_real_one_is(label, lamps, faces))
		# CONTRAILS FROM A WING'S TIPS ONLY: the view's `wingtips()` is where `ContrailYard` lays them, and a helicopter's red
		# and green on its stabiliser are not a wing's.
		var tips: Array[Vector3] = view.wingtips()
		if VehicleLights.has_a_wing(kind) != (tips.size() == 2):
			wrong.append("%s: %d wingtips for contrails, and it %s a wing" % [label, tips.size(),
				"has" if VehicleLights.has_a_wing(kind) else "has not"])
		# THE MUTANT, on the first craft with lights: its first light moved half a metre straight out from the craft.
		if not lamps.is_empty() and mutant_detail.is_empty():
			var at: Vector3 = lamps[0]["position"]
			var moved: Vector3 = at + Vector3(signf(at.x) if absf(at.x) > 0.01 else 0.0, 0.0 if absf(at.x) > 0.01
				else 1.0, 0.0) * 0.5
			var moved_off: float = nearest(moved, faces)
			mutant_caught = moved_off > VehicleLights.ON_SKIN
			mutant_detail = "%s's %s light moved 0.5 m out reads %.2f m off" % [label, lamps[0]["what"], moved_off]
		remove_child(view)
		view.free()
	_check("every_kind_was_visited", visited.size() == Sim.Kind.size(),
		"%d of %d: %s" % [visited.size(), Sim.Kind.size(), ", ".join(visited)])
	_check("every_light_of_every_kind_stands_on_its_own_drawn_skin", off.is_empty() and not lit.is_empty(),
		"; ".join(off) if not off.is_empty() else "the worst %.3f m (%s), within %.2f, on %s" % [worst, worst_of,
			VehicleLights.ON_SKIN, ", ".join(lit)])
	_check("and_they_are_where_a_real_one_is_and_only_on_what_flies", wrong.is_empty(),
		"; ".join(wrong) if not wrong.is_empty() else "%d kinds lit, none that drives or sails" % lit.size())
	_check("and_a_light_moved_off_its_skin_is_caught", mutant_caught, mutant_detail)
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## RED LEFT AND GREEN RIGHT, the tail light aft, a red beacon open to the sky: what a pilot reads off a craft's lights at
## night.
func _where_a_real_one_is(label: String, lamps: Array, faces: PackedVector3Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var red: Array = lamps.filter(func(l: Dictionary) -> bool: return l["what"] == "red" and l["pattern"] == "steady")
	var green: Array = lamps.filter(func(l: Dictionary) -> bool: return l["what"] == "green" and l["pattern"] == "steady")
	var tail: Array = lamps.filter(func(l: Dictionary) -> bool: return l["what"] == "white" and l["pattern"] == "steady")
	var beacons: Array = lamps.filter(func(l: Dictionary) -> bool: return l["pattern"] == "beacon")
	if red.size() != 1 or green.size() != 1 or tail.size() != 1 or beacons.is_empty():
		out.append("%s: %d red, %d green, %d tail, %d beacons" % [label, red.size(), green.size(), tail.size(),
			beacons.size()])
		return out
	var port: Vector3 = red[0]["position"]
	var starboard: Vector3 = green[0]["position"]
	if port.x >= 0.0 or starboard.x <= 0.0:
		out.append("%s: red at x %.2f and green at %.2f" % [label, port.x, starboard.x])
	var z_tips: float = maxf(port.z, starboard.z)
	if (tail[0]["position"] as Vector3).z < z_tips + TAIL_AFT_OF_TIPS:
		out.append("%s: the tail light at z %.2f, not aft of the tips at %.2f" % [label, tail[0]["position"].z, z_tips])
	# THE TOP BEACON OPEN TO THE SKY: no drawn point within `OPEN_ABOVE` of it, horizontally, stands above it.
	var top: Vector3 = Vector3(0.0, -INF, 0.0)
	for beacon in beacons:
		if (beacon["position"] as Vector3).y > top.y:
			top = beacon["position"]
	var over: float = -INF
	for p in faces:
		if Vector2(p.x - top.x, p.z - top.z).length() < OPEN_ABOVE:
			over = maxf(over, p.y)
	if over > top.y:
		out.append("%s: the top beacon at %s has the skin %.2f m over it" % [label, top, over - top.y])
	return out


## Every light the view hung, in the view's own frame, as the built node holds them.
static func lamps_of(view: VehicleView) -> Array:
	var out: Array = []
	for node in view.find_children("*", "MultiMeshInstance3D", true, false):
		var lights := node as VehicleLights
		if lights == null:
			continue
		var frame: Transform3D = VehicleLights.frame_in(lights, view)
		for lamp in lights.lamps:
			var colour: Color = lamp.get("colour", VehicleLights.WHITE)
			out.append({"position": frame * (lamp["position"] as Vector3),
				"what": "red" if colour == VehicleLights.RED else "green" if colour == VehicleLights.GREEN else "white",
				"pattern": ["steady", "beacon", "strobe", "rabbit", "papi"][int(lamp.get("pattern", 0))]})
	return out


## Every triangle the view draws, in its own frame: every MeshInstance3D shown in the tree, rotors and wheels too, less
## what `DrawnParts` stops at -- a casting, which overlaps the parts it was poured from, and a control or a station.
static func drawn_faces(view: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree() or DrawnParts.inside_a_named_part(part):
			continue
		var frame: Transform3D = VehicleLights.frame_in(part, view)
		for vertex in part.mesh.get_faces():
			out.append(frame * vertex)
	return out


static func nearest(point: Vector3, faces: PackedVector3Array) -> float:
	var best: float = INF
	for i in range(0, faces.size() - 2, 3):
		# `<` AND NOT `minf`: a degenerate triangle's closest point is NaN, and `minf(best, NaN)` is NaN, which then lets
		# the next triangle's distance through whatever it is. The gunship's and the Mercury's lights read 19 m off their
		# wingtips that way while they stood 0.06 m from them.
		var d: float = point.distance_to(closest_on_triangle(point, faces[i], faces[i + 1], faces[i + 2]))
		if d < best:
			best = d
	return best


## Ericson, Real-Time Collision Detection 5.1.5: the point of triangle abc nearest p.
static func closest_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var ap: Vector3 = p - a
	var d1: float = ab.dot(ap)
	var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp: Vector3 = p - b
	var d3: float = ab.dot(bp)
	var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc: float = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp: Vector3 = p - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	if is_zero_approx(va + vb + vc):
		return a
	var denom: float = 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)
