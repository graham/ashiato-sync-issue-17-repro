extends Node
## Measures the reference-aircraft geometry players actually see. Read RESULT= rather
## than Godot's process exit code.

const TOLERANCE := 0.02
const MAX_TRIANGLES := 100_000
const MAX_MATERIAL_SLOTS := 12
const FALLBACK_DRAW_CALLS := 40

# Size is span/width, height, length in metres. Feature names are semantic contracts,
# never generated child indexes, so a primitive fallback can later become a GLB.
const AIRCRAFT := [
	# THE 172S's HEIGHT IS THE MEASURED 2.36 m TO ITS BEACON, not Textron's 2.72 m, which is labelled a maximum and which
	# neither the information manual's three-view (2.39) nor a scaled photograph (2.34) reproduces: craft/cessna/sources.md.
	{"kind": Sim.Kind.CESSNA, "source": "cessna", "size": Vector3(11.0, 2.36, 8.28),
		"features": ["Airframe", "Glazing", "Gear", "Propeller", "FlapPort", "AileronStarboard", "ElevatorPort", "Rudder"]},
	{"kind": Sim.Kind.TANKER, "source": "tanker", "size": Vector3(28.6, 9.02, 19.8),
		"features": ["WaterBomberFuselage", "WaterBomberBow", "WaterBomberWingPort", "WaterBomberWingStarboard", "WaterBomberPortFloat", "WaterBomberStarboardFloat"]},
	{"kind": Sim.Kind.OSPREY, "source": "osprey", "size": Vector3(25.8, 6.7, 17.47),
		"features": ["Fuselage", "NacellePort", "NacelleStarboard", "ProprotorPort", "ProprotorStarboard", "FinPort",
			"FinStarboard", "SponsonPort", "SponsonStarboard", "RefuellingProbe"]},
	{"kind": Sim.Kind.CHINOOK, "source": "chinook", "size": Vector3(18.3, 5.7, 30.1),
		"features": ["ChinookFuselage", "ChinookFrontRotor*", "ChinookRearRotor*", "ChinookPortSponson", "ChinookStarboardSponson"]},
	# THE GLIDER IS HELD BY `tests/sailplane.gd` since it became a Duo Discus (2026-09-18), as the F-16 and the F-14 are
	# by their own suites: its published height (1.60 m) is PARKED, tail wheel down, and a level box cannot measure it.
	{"kind": Sim.Kind.HAWKEYE, "source": "hawkeye", "size": Vector3(24.56, 5.58, 17.60),
		"features": ["Body", "Rotodome", "Panel"]},
	# THE 747-400 SINCE 2026-09-19 (lane/liners), in place of the E-6B: Boeing's printed length and jig span, Wikipedia's
	# height. The drawing it is measured from draws the 64.92 m span at maximum gross weight, 0.7 per cent over the jig's.
	{"kind": Sim.Kind.JUMBO, "source": "jumbo", "size": Vector3(64.44, 19.41, 70.67),
		"features": ["Fuselage", "WingPort", "WingStarboard", "Engine*", "Fin", "Rudder"]},
	# THE 737-800W SINCE 2026-09-19 (lane/liners): Boeing's printed span, height and length.
	{"kind": Sim.Kind.AIRLINER, "source": "airliner", "size": Vector3(35.79, 12.55, 39.47),
		"features": ["Fuselage", "WingPort", "WingStarboard", "Engine1", "Engine2", "Fin", "Rudder"]},
	# THE CESSNA 310R SINCE 2026-09-19 (lane/twin310), in place of a generic "utility twin" that
	# claimed to be no type at all. THE HEIGHT IS 9 ft 11.25 in TO THE FIN CAP PLUS THE 3 in THE
	# FACTORY SHEET SAYS A ROTATING BEACON ADDS -- not the published 10 ft 7 in / 10 ft 8 in, which
	# reproduces that sheet's OWN nose-gear-depressed figure to within an inch. The length is the
	# PARKED BOX of a 9.74 m aeroplane standing 4.5 degrees nose-up with its fin top 3.5 m over its
	# wheels; `tests/twin310.gd` holds the aeroplane's own axial length to 9.74 separately, which is
	# the check a bounding box cannot make. See craft/plane/sources.md.
	{"kind": Sim.Kind.PLANE, "source": "plane", "size": Vector3(11.25, 3.105, 9.91),
		"features": ["Airframe", "Glazing", "WingPort", "WingStarboard", "StabiliserPort",
			"StabiliserStarboard", "NoseGear", "MainGearPort", "MainGearStarboard",
			"PropellerPort", "PropellerStarboard", "Rudder", "FlapPort", "AileronStarboard"]},
]

var _failures: PackedStringArray = []


func _ready() -> void:
	for contract in AIRCRAFT:
		_measure(contract)
	_the_legacy_helicopter_and_distinct_uh60_keep_their_separate_contracts()
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _measure(contract: Dictionary) -> void:
	var kind := int(contract["kind"])
	var label := String(contract["source"])
	var source := "res://craft/%s/sources.md" % label
	_check("%s_has_a_checked_in_reference_contract" % label, FileAccess.file_exists(source), source)
	var geometry: Dictionary = Sim.geometry_of(kind)
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, kind)
	if kind in [Sim.Kind.CESSNA, Sim.Kind.TANKER, Sim.Kind.OSPREY, Sim.Kind.CHINOOK]:
		var native_hull := view.find_child("Hull", true, false) as MeshInstance3D
		_check("%s_does_not_render_its_native_collision_box" % label,
			native_hull != null and not native_hull.is_visible_in_tree(),
			"native hull hidden behind the rounded exterior")
	var bounds := _bounds(view)
	var wanted: Vector3 = contract["size"]
	var error := Vector3(absf(bounds.size.x - wanted.x) / wanted.x,
		absf(bounds.size.y - wanted.y) / wanted.y, absf(bounds.size.z - wanted.z) / wanted.z)
	_check("%s_drawn_bounds_are_within_two_percent_of_the_reference" % label,
		error.x <= TOLERANCE and error.y <= TOLERANCE and error.z <= TOLERANCE,
		"drawn %.2f x %.2f x %.2f m (%s to %s), reference %.2f x %.2f x %.2f m, error %s" % [
			bounds.size.x, bounds.size.y, bounds.size.z, bounds.position, bounds.end,
			wanted.x, wanted.y, wanted.z, error])

	var missing: PackedStringArray = []
	for pattern in contract["features"]:
		if view.find_children(String(pattern), "MeshInstance3D", true, false).is_empty():
			missing.append(String(pattern))
	_check("%s_keeps_its_recognisable_named_fittings" % label, missing.is_empty(),
		"all present" if missing.is_empty() else "missing %s" % ", ".join(missing))

	var poses: Array = geometry.get("seat_poses", [])
	var moved: PackedStringArray = []
	if view.seats.size() != poses.size():
		moved.append("%d anchors for %d poses" % [view.seats.size(), poses.size()])
	for index in range(mini(view.seats.size(), poses.size())):
		var expected: Vector3 = (poses[index] as Dictionary).get("position", Vector3.ZERO)
		if view.seats[index].position.distance_to(expected) > 0.001:
			moved.append("seat %d %s != %s" % [index, view.seats[index].position, expected])
	_check("%s_visual_work_does_not_move_native_station_anchors" % label, moved.is_empty(),
		"unchanged" if moved.is_empty() else "; ".join(moved))

	# WHETHER THE AEROPLANE IS ONE OBJECT is `tests/joined_parts.gd`'s question now, asked of every
	# kind in the game rather than of these seven, with one known-failures list instead of two.

	var budget := _budget(view)
	_check("%s_procedural_fallback_stays_inside_the_measured_render_budget" % label,
		int(budget["triangles"]) <= MAX_TRIANGLES and int(budget["materials"]) <= MAX_MATERIAL_SLOTS
			and int(budget["draw_calls"]) <= FALLBACK_DRAW_CALLS
			and int(budget["far_draw_calls"]) < int(budget["draw_calls"]),
		"%d triangles, %d material slots, %d near / %d at 1.5 km draw calls" % [budget["triangles"],
			budget["materials"], budget["draw_calls"], budget["far_draw_calls"]])
	view.queue_free()


func _the_legacy_helicopter_and_distinct_uh60_keep_their_separate_contracts() -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.HELI)
	var half: Vector3 = geometry.get("extents", Vector3.ZERO)
	var source := FileAccess.get_file_as_string("res://craft/heli/sources.md")
	var uh60: Dictionary = Sim.geometry_of(Sim.Kind.UH60)
	var uh60_half: Vector3 = uh60.get("extents", Vector3.ZERO)
	_check("the_legacy_light_helicopter_keeps_its_stable_shape_beside_the_distinct_uh60_kind",
		absf(half.z * 2.0 - 5.2) < 0.01 and absf(float(geometry.get("span", 0.0)) * 2.0 - 12.0) < 0.01
			and absf(uh60_half.z * 2.0 - 12.62) < 0.01
			and absf(float(uh60.get("span", 0.0)) * 2.0 - 16.36) < 0.01
			and source.contains("distinct `uh60` package now supplies that craft kind"),
		"legacy %.1f m / %.1f m rotor; UH-60 %.2f m / %.2f m rotor; migration recorded %s" % [
			half.z * 2.0, float(geometry.get("span", 0.0)) * 2.0, uh60_half.z * 2.0,
			float(uh60.get("span", 0.0)) * 2.0,
			source.contains("distinct `uh60` package now supplies that craft kind")])


func _budget(root: Node3D) -> Dictionary:
	var triangles := 0
	var draw_calls := 0
	var far_draw_calls := 0
	var materials: Dictionary = {}
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree():
			continue
		for surface in range(part.mesh.get_surface_count()):
			draw_calls += 1
			if AircraftVisualLod.drawn_at(part, 1500.0):
				far_draw_calls += 1
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
			triangles += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
			var material: Material = part.get_active_material(surface)
			if material != null:
				materials[material.get_instance_id()] = true
	return {"triangles": triangles, "materials": materials.size(), "draw_calls": draw_calls,
		"far_draw_calls": far_draw_calls}


func _bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var inverse := root.global_transform.affine_inverse()
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree():
			continue
		var box := part.mesh.get_aabb()
		var xform := inverse * part.global_transform
		for corner in range(8):
			var point := xform * box.get_endpoint(corner)
			result = AABB(point, Vector3.ZERO) if first else result.expand(point)
			first = false
	# A ROTOR IS MEASURED BY THE DISC IT SWEEPS, because that is what a published rotor diameter and a "rotors turning"
	# length are. A parked three-blade rotor reaches its radius along one blade and half of it the other way, so the
	# Chinook's two could only span 18.3 m across and 30.1 m along if they were drawn as planks through the hub -- which
	# they were, until `lane/rotors` gave them blades (2026-09-17). A `RotorcraftKit` rotor says how many blades it has;
	# its reach is read off its own blades' vertices, never typed.
	for found in root.find_children("*", "Node3D", true, false):
		var rotor := found as Node3D
		if not rotor.has_meta(&"blades") or not rotor.is_visible_in_tree():
			continue
		var blades := rotor.get_node_or_null(NodePath(String(rotor.name) + "Blades")) as MeshInstance3D
		if blades == null:
			continue
		var reach := 0.0
		for vertex in blades.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			reach = maxf(reach, Vector2(vertex.x, vertex.z).length())
		var xform := inverse * rotor.global_transform
		for rim in [Vector3(reach, 0, 0), Vector3(-reach, 0, 0), Vector3(0, 0, reach), Vector3(0, 0, -reach)]:
			var point: Vector3 = xform * rim
			result = AABB(point, Vector3.ZERO) if first else result.expand(point)
			first = false
	return result


func _check(label: String, okay: bool, detail: String) -> void:
	print("[aircraft_fidelity] %s %s (%s)" % ["PASS" if okay else "FAIL", label, detail])
	if not okay:
		_failures.append(label)
