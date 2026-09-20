extends Node
## Headless contract for the V-22 airframe: its measured envelope against the published one, the parts that make it a
## V-22, one object in every pose, a crew inside the drawn skin who can see out through glass, and what MOVES -- the
## nacelles through the SIMULATION'S travel, and the proprotors, whose discs clear the fuselage at every angle -- each read
## back from DRAWN VERTICES, never from a node's transform. And the game draws it: the VehicleView of kind OSPREY builds
## this airframe and swings its nacelles from the bus. Read RESULT=.

## THE ENVELOPE AS CONSTANTS AT THE TOP, TYPED, so the reference is visible in one place and no check asks the builder's
## own constant what the builder did. The published ones are Wikipedia's V-22 specifications; every MEASURED one is
## printed from [JJ]'s six views alone by `craft/osprey/measure_views.py`.
const PUBLISHED_LENGTH := 17.48
const PUBLISHED_WIDTH := 25.77     # "including rotors"
const PUBLISHED_ROTOR := 11.61
const PUBLISHED_SPAN := 13.97
const PUBLISHED_HEIGHT := 6.73     # "engine nacelles vertical"
const PUBLISHED_FIN_TOP := 5.38    # "to top of tailfins"
const MEASURED_SWEEP := -6.6       # the leading edge, degrees: FORWARD, fitted over 146 rows at 28 mm rms
const MEASURED_DIHEDRAL := 4.5     # the front view's top and bottom lines, 11 mm rms
const PUBLISHED_TRAVEL_DEG := 97.5 # "can rotate past vertical to 97.5" [WP, Norton p. 97]

## Every part a reader would name when looking at a V-22. A missing one fails by name.
const PARTS: Array = ["Fuselage", "RefuellingProbe", "Wing", "Tailplane", "SponsonPort", "SponsonStarboard", "FinPort",
	"FinStarboard", "NacellePort", "NacelleStarboard", "ProprotorPort", "ProprotorStarboard", "NoseGear", "MainGearPort",
	"MainGearStarboard", "NoseDoorPort", "NoseDoorStarboard", "MainDoorPort", "MainDoorStarboard", "Wells", "Ramp",
	"RampDoor", "CrewDoorUpper", "CrewDoorLower", "CabinFloor", "CabinLining", "ChinTurret"]
const LEGS: Array = ["NoseGear", "MainGearStarboard", "MainGearPort"]
const WELL_DOORS: Array = ["NoseDoorStarboard", "NoseDoorPort", "MainDoorStarboard", "MainDoorPort"]
## [JJ]'s side windows, over the belly: where a pilot's eye belongs.
const WINDOW_BAND := Vector2(1.70, 2.47)
## What the nacelles' discs must never touch.
const STRUCTURE: Array = ["Fuselage", "Wing", "Tailplane", "SponsonPort", "SponsonStarboard", "FinPort", "FinStarboard",
	"RefuellingProbe"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[osprey] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var frame := OspreyAirframe.new()
	add_child(frame)
	frame.dress(Sim.geometry_of(Sim.Kind.OSPREY))
	_every_visible_mesh_is_a_named_part(frame)
	_it_is_one_object_in_every_pose(frame)
	_the_drawn_aircraft_is_the_published_size(frame)
	_every_tyre_stands_on_the_ground(frame)
	_the_wing_is_swept_forward_with_its_dihedral(frame)
	_both_pilots_sit_inside_the_skin_and_see_out_through_glass(frame)
	_the_nacelles_stand_where_the_simulation_turns_the_thrust(frame)
	_the_proprotors_clear_the_airframe_at_every_angle(frame)
	_the_proprotors_turn_in_opposite_senses_and_come_back(frame)
	_the_pilot_flies_from_the_right_hand_seat(frame)
	_the_gear_doors_open_before_a_leg_moves_and_shut_after(frame)
	_no_leg_ever_passes_through_a_door(frame)
	_the_stowed_gear_is_inside_the_skin(frame)
	_the_ramp_shuts_the_cabin_and_lowers_to_the_ground_through_nothing(frame)
	_the_crew_door_shuts_the_side_and_opens_through_nothing(frame)
	_every_face_is_wound_outwards(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	await _the_vat_draws_the_moving_parts_where_the_parts_are(frame)
	frame.queue_free()
	_the_game_draws_this_airframe_and_swings_it_from_the_bus()
	_both_pilots_see_over_the_nose_past_their_own_cockpits()
	_finish()


func _every_visible_mesh_is_a_named_part(frame: Node3D) -> void:
	var missing: PackedStringArray = []
	for part in PARTS:
		if frame.find_child(part, true, false) == null:
			missing.append(part)
	var strays: PackedStringArray = []
	for mesh in _meshes(frame):
		if not PARTS.has(String(mesh.name)):
			strays.append(String(mesh.name))
	_check("every_visible_mesh_is_a_named_part", missing.is_empty() and strays.is_empty(),
		"%d parts; missing %s; unnamed %s" % [PARTS.size(), missing, strays])


## ONE OBJECT: every drawn part reaches the fuselage (`DrawnParts.adrift`, the algorithm `joined_parts` uses), with the
## nacelles forward, half way and up: a nacelle that swings away from its wing tip is adrift.
func _it_is_one_object_in_every_pose(frame: OspreyAirframe) -> void:
	var said: PackedStringArray = []
	for tilt in [0.0, 0.5, 1.0]:
		frame.set_tilt(tilt)
		for s in DrawnParts.adrift(frame):
			said.append("%s %.2f m from %s at tilt %.1f" % [s["name"], s["gap"], s["nearest"], tilt])
	frame.set_tilt(1.0)
	_check("it_is_one_object_in_every_pose", said.is_empty(),
		"%d parts, adrift: %s" % [DrawnParts.count(frame), ", ".join(said) if not said.is_empty() else "none"])


## THE ENVELOPE, from transformed vertices, against the published figures (2 per cent): the length nose tip to fins, the
## width across the turning proprotors (a blade pointing outboard each side), each disc's diameter, the conversion axes'
## spacing against the published span, the height with the nacelles vertical to the spinners' tops, and the fins' tops,
## both over the ground the tyres stand on.
func _the_drawn_aircraft_is_the_published_size(frame: OspreyAirframe) -> void:
	frame.set_tilt(PI * 0.5 / OspreyAirframe.travel())
	frame.set_spin(0.0)
	var body: AABB = _box_of(frame, [_mesh(frame, "Fuselage"), _mesh(frame, "FinPort"), _mesh(frame, "FinStarboard")])
	var all: AABB = _box_of(frame, _meshes(frame))
	var ground: float = _box_of(frame, [_mesh(frame, "NoseGear"), _mesh(frame, "MainGearPort")]).position.y
	var fins: AABB = _box_of(frame, [_mesh(frame, "FinPort")])
	var discs: Array[float] = []
	for named in ["Port", "Starboard"]:
		var rotor := _mesh(frame, "Proprotor" + named)
		var hub: Vector3 = _mesh_hub(frame, named)
		var reach: float = 0.0
		for p in _points(frame, rotor):
			reach = maxf(reach, Vector2(p.x - hub.x, p.z - hub.z).length())
		discs.append(reach * 2.0)
	var axes: float = frame.pivot(1.0).x - frame.pivot(-1.0).x
	var length_off: float = body.size.z / PUBLISHED_LENGTH - 1.0
	var width_off: float = all.size.x / PUBLISHED_WIDTH - 1.0
	var height_off: float = (all.end.y - ground) / PUBLISHED_HEIGHT - 1.0
	var fin_off: float = (fins.end.y - ground) / PUBLISHED_FIN_TOP - 1.0
	var disc_off: float = maxf(absf(discs[0] / PUBLISHED_ROTOR - 1.0), absf(discs[1] / PUBLISHED_ROTOR - 1.0))
	var span_off: float = axes / PUBLISHED_SPAN - 1.0
	frame.set_tilt(1.0)
	_check("the_drawn_aircraft_is_the_published_size", absf(length_off) < 0.02 and absf(width_off) < 0.02
		and absf(height_off) < 0.02 and absf(fin_off) < 0.02 and disc_off < 0.02 and absf(span_off) < 0.02,
		"length %.3f m (%+.1f%%), width %.3f (%+.1f%%), discs %.3f and %.3f, conversion axes %.3f apart against the %.2f"
			% [body.size.z, length_off * 100.0, all.size.x, width_off * 100.0, discs[0], discs[1], axes, PUBLISHED_SPAN]
			+ " span (%+.1f%%), height %.3f (%+.1f%%), fins' tops %.3f (%+.1f%%), all over the tyres' ground"
			% [span_off * 100.0, all.end.y - ground, height_off * 100.0, fins.end.y - ground, fin_off * 100.0])


## THE TYRES all stand on one ground, the lowest drawn point of the aircraft, which is the collision box's floor: where
## the physics puts the ground.
func _every_tyre_stands_on_the_ground(frame: OspreyAirframe) -> void:
	var bottoms: Array[float] = []
	for part in ["NoseGear", "MainGearPort", "MainGearStarboard"]:
		bottoms.append(_box_of(frame, [_mesh(frame, part)]).position.y)
	var lowest: float = _box_of(frame, _meshes(frame)).position.y
	var floor_y: float = -(Sim.geometry_of(Sim.Kind.OSPREY).get("extents", Vector3.ONE) as Vector3).y
	var spread: float = bottoms.max() - bottoms.min()
	_check("every_tyre_stands_on_the_ground", spread < 0.01 and absf(bottoms.min() - lowest) < 0.01
		and absf(lowest - floor_y) < 0.02,
		"tyre bottoms %s, the lowest drawn point %.3f, the collision box's floor %.3f" % [bottoms, lowest, floor_y])


## THE WING against [JJ]'s fits, read off the DRAWN vertices: its leading edge swept forward, and its dihedral from the
## drawn top surface either side of the fuselage.
func _the_wing_is_swept_forward_with_its_dihedral(frame: OspreyAirframe) -> void:
	# The loft's sections stand at a handful of stations out; each one's most forward point and its highest.
	var bands: Dictionary = {}
	var high: Dictionary = {}
	for p in _points(frame, _mesh(frame, "Wing")):
		if p.x < 1.2 or p.x > 6.5:
			continue
		var band: int = int(round(p.x / 0.01))
		if not bands.has(band) or p.z < (bands[band] as Vector3).z:
			bands[band] = p
		if not high.has(band) or p.y > (high[band] as Vector3).y:
			high[band] = p
	var lead: Array = bands.values()
	var tops: Array = high.values()
	var sweep: float = _slope(lead, func(p: Vector3) -> float: return -p.z)
	var dihedral: float = _slope(tops, func(p: Vector3) -> float: return p.y)
	# A forward sweep brings the leading edge FORWARD (-z) as it goes out, so -z rises with x: the angle is negative in
	# the usual sense of "sweep back".
	_check("the_wing_is_swept_forward_with_its_dihedral", absf(-sweep - MEASURED_SWEEP) < 0.5
		and absf(dihedral - MEASURED_DIHEDRAL) < 0.5,
		"leading edge swept %.2f degrees (measured %.1f), dihedral %.2f (measured %.1f), from %d drawn points"
			% [-sweep, MEASURED_SWEEP, dihedral, MEASURED_DIHEDRAL, lead.size()])


## BOTH PILOTS SIT INSIDE THE AIRCRAFT AND SEE OUT THROUGH GLASS. Each flying seat's eye -- the simulation's seat pose plus
## `CockpitStation.EYE_HEIGHT` -- and every corner of `cabin_room()`'s box are inside the drawn fuselage by ray parity
## fired up and down only (`modelling_here.md` section 6); and from each eye, looking level ahead and 30 degrees either
## side, the first thing a ray meets is the glazing, never a painted panel.
func _both_pilots_sit_inside_the_skin_and_see_out_through_glass(frame: OspreyAirframe) -> void:
	var outside: PackedStringArray = []
	var blind: PackedStringArray = []
	var eyes: Array[Vector3] = []
	for pose in Sim.geometry_of(Sim.Kind.OSPREY).get("seat_poses", []):
		if bool((pose as Dictionary).get("flies", false)):
			eyes.append(((pose as Dictionary)["position"] as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0))
	var room: Dictionary = frame.cabin_room()
	var box: AABB = room["room"]
	var points: Array = []
	for eye in eyes:
		points.append(eye)
	for i in range(8):
		var corner: Vector3 = box.get_endpoint(i)
		points.append(corner + (box.get_center() - corner).normalized() * 0.001)
	for p in points:
		if not _inside(frame, (p as Vector3) + Vector3(0.0007, 0.0, 0.0007)):
			outside.append("(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])
	for eye in eyes:
		for yaw in [0.0, 30.0, -30.0]:
			var ahead: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(yaw))
			var hit: String = _first_hit(frame, eye, ahead)
			if hit != "Fuselage/1":
				blind.append("eye x %+.2f at %+.0f deg met %s" % [eye.x, yaw, hit])
	_check("both_pilots_sit_inside_the_skin_and_see_out_through_glass", eyes.size() == 2 and outside.is_empty()
		and blind.is_empty(),
		"%d flying eyes; room %.2f wide x %.2f tall x %.2f long; outside the skin: %s; blind: %s" % [eyes.size(),
			box.size.x, box.size.y, box.size.z, "none" if outside.is_empty() else ", ".join(outside),
			"none" if blind.is_empty() else ", ".join(blind)])


## THE NACELLES STAND WHERE THE SIMULATION TURNS THE THRUST. At 0, a half and 1 of the lever, the DRAWN rotor axis --
## the line from the conversion axis to the middle of the drawn proprotor's vertices -- is turned up from its aeroplane-
## mode direction by the lever times the KIND'S travel, read from the simulation's handling (`vector_travel`), never from
## the airframe. And that travel is the published 97.5 degrees.
func _the_nacelles_stand_where_the_simulation_turns_the_thrust(frame: OspreyAirframe) -> void:
	var handling: Dictionary = Sim.handling_of(Sim.Kind.OSPREY)
	var travel: float = float(handling.get("vector_travel", NAN))
	var said: PackedStringArray = []
	var worst: float = 0.0
	frame.set_tilt(0.0)
	var forward: Vector3 = _mesh_hub(frame, "Starboard") - frame.pivot(1.0)
	for amount in [0.0, 0.5, 1.0]:
		frame.set_tilt(amount)
		for named in ["Starboard", "Port"]:
			var side: float = 1.0 if named == "Starboard" else -1.0
			var now: Vector3 = _mesh_hub(frame, named) - frame.pivot(side)
			var drawn: float = atan2(now.y, -now.z) - atan2(forward.y, -forward.z)
			worst = maxf(worst, absf(drawn - amount * travel))
			said.append("%s %.2f: %.2f deg" % [named.left(4), amount, rad_to_deg(drawn)])
	frame.set_tilt(1.0)
	_check("the_nacelles_stand_where_the_simulation_turns_the_thrust",
		worst < deg_to_rad(0.1) and absf(rad_to_deg(travel) - PUBLISHED_TRAVEL_DEG) < 0.1,
		"the simulation's vector_travel %.2f deg, worst drawn error %.3f deg: %s" % [rad_to_deg(travel),
			rad_to_deg(worst), ", ".join(said)])


## THE DISCS NEVER TOUCH THE AIRFRAME, at every twentieth of the travel: no drawn vertex of the fuselage, wing, tail,
## sponsons or probe lies within the swept disc -- its radius plus 0.15 m, and 0.30 m either side of the blades' plane.
## THE GROUND IS REPORTED, NOT ASSERTED past helicopter mode: a real V-22 cannot land in aeroplane mode, and neither the
## simulation nor the drawing stops a pilot trying; the lowest angle at which the discs clear the ground is printed.
func _the_proprotors_clear_the_airframe_at_every_angle(frame: OspreyAirframe) -> void:
	var structure: PackedVector3Array = PackedVector3Array()
	for part in STRUCTURE:
		structure.append_array(_points(frame, _mesh(frame, part)))
	var ground: float = frame.point(0.0, OspreyAirframe.ground(), 0.0).y
	var touched: PackedStringArray = []
	var clears_from: float = -1.0
	var nearest: float = INF
	for step in range(21):
		var amount: float = float(step) / 20.0
		frame.set_tilt(amount)
		var lowest: float = INF
		for named in ["Starboard", "Port"]:
			var hub: Vector3 = _mesh_hub(frame, named)
			var hinge := frame.find_child("Proprotor" + named + "Hinge", true, false) as Node3D
			var axis: Vector3 = (frame.global_transform.affine_inverse().basis * hinge.global_transform.basis
				* Vector3.FORWARD).normalized()
			for p in structure:
				var along: float = (p - hub).dot(axis)
				var across: float = ((p - hub) - axis * along).length()
				if absf(along) < 0.30:
					nearest = minf(nearest, across - OspreyAirframe.ROTOR_RADIUS)
					if across < OspreyAirframe.ROTOR_RADIUS + 0.15:
						touched.append("%s at tilt %.2f: (%.2f, %.2f, %.2f)" % [named, amount, p.x, p.y, p.z])
						break
			# The disc's lowest point: the hub less the radius times how far the disc's plane stands from level.
			lowest = minf(lowest, hub.y - OspreyAirframe.ROTOR_RADIUS * sqrt(maxf(0.0, 1.0 - axis.y * axis.y)))
		if clears_from < 0.0 and lowest > ground:
			clears_from = amount
	frame.set_tilt(1.0)
	var travel: float = OspreyAirframe.travel()
	_check("the_proprotors_clear_the_airframe_at_every_angle", touched.is_empty()
		and clears_from >= 0.0 and clears_from * travel <= PI * 0.5,
		"%s; the nearest structure in the blades' plane is %.2f m outside a disc; the discs clear the ground from %.0f"
			% ["nothing inside a disc" if touched.is_empty() else ", ".join(touched.slice(0, 4)), nearest,
				rad_to_deg(clears_from * travel)]
			+ " degrees (%.2f of the lever), and meet it below" % clears_from)


## THE PROPROTORS TURN, OPPOSITE WAYS, AND COME BACK. A third of a turn's phase moves each rotor's first blade tip round
## its own axis by the same angle in opposite senses (read from drawn vertices), and phase 1 draws exactly phase 0.
func _the_proprotors_turn_in_opposite_senses_and_come_back(frame: OspreyAirframe) -> void:
	frame.set_tilt(0.0)
	frame.set_spin(0.0)
	var rest: Dictionary = {}
	for named in ["Starboard", "Port"]:
		rest[named] = _points(frame, _mesh(frame, "Proprotor" + named))
	frame.set_spin(0.25)
	var turned: Dictionary = {}
	for named in ["Starboard", "Port"]:
		var hub: Vector3 = _mesh_hub(frame, named)
		var a: PackedVector3Array = rest[named]
		var b: PackedVector3Array = _points(frame, _mesh(frame, "Proprotor" + named))
		# The farthest vertex from the hub, before and after: its angle round the forward axis, seen from ahead.
		var far: int = 0
		for i in range(a.size()):
			if (a[i] - hub).length() > (a[far] - hub).length():
				far = i
		var before: float = atan2(a[far].y - hub.y, a[far].x - hub.x)
		var after: float = atan2(b[far].y - hub.y, b[far].x - hub.x)
		turned[named] = rad_to_deg(wrapf(after - before, -PI, PI))
	frame.set_spin(1.0)
	var back: float = 0.0
	for named in ["Starboard", "Port"]:
		back = maxf(back, _off(rest[named], _points(frame, _mesh(frame, "Proprotor" + named))))
	frame.set_spin(0.0)
	frame.set_tilt(1.0)
	var starboard: float = turned["Starboard"]
	var port: float = turned["Port"]
	_check("the_proprotors_turn_in_opposite_senses_and_come_back", absf(absf(starboard) - 30.0) < 0.5
		and absf(starboard + port) < 0.5 and back < 0.001,
		"a quarter of the phase turns the starboard rotor %.2f deg and the port %.2f deg; phase 1 is %.4f m off phase 0"
			% [starboard, port, back])


func _every_face_is_wound_outwards(frame: Node3D) -> void:
	var wrong: int = 0
	var total: int = 0
	var worst: Dictionary = {}
	for drawn in _meshes(frame):
		for surface in range(drawn.mesh.get_surface_count()):
			var arrays: Array = drawn.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in range(0, points.size() - 2, 3):
				var face: Vector3 = (points[i + 2] - points[i]).cross(points[i + 1] - points[i])
				if face.length_squared() < 1e-12:
					continue
				total += 1
				if face.dot(normals[i]) <= 0.0:
					wrong += 1
					worst[String(drawn.name)] = int(worst.get(String(drawn.name), 0)) + 1
	_check("every_face_is_wound_outwards", wrong == 0 and total > 0,
		"%d of %d faces wound against their normal %s" % [wrong, total, worst])


## THE BUDGET for a first exterior LOD: at most 100,000 triangles, 12 materials and 40 draw surfaces as parts (the VAT
## pours them into one), and at least three fittings that stop drawing at range. The scope: the whole airframe subtree,
## the discs included.
func _the_exterior_meets_the_first_lod_budget(frame: Node3D) -> void:
	var triangles: int = 0
	var draws: int = 0
	var culled: int = 0
	var materials: Dictionary = {}
	for node in frame.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.visibility_range_end > 0.0:
			culled += 1
		for s in range(drawn.mesh.get_surface_count()):
			materials[drawn.material_override if drawn.material_override != null
				else drawn.get_active_material(s)] = true
			draws += 1
			triangles += (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check("the_exterior_meets_the_first_lod_budget", triangles <= 100000 and draws <= 40 and culled >= 3
		and materials.size() <= 12,
		"the whole OspreyAirframe subtree: %d triangles, %d draw surfaces, %d materials, %d distance-culled"
			% [triangles, draws, materials.size(), culled])


## THE MOVING PARTS AS A VERTEX ANIMATION TEXTURE, held to the parts it was baked from. A `VatCasting` is poured from a
## second airframe with the airframe's own `features()` (its discs left out, `OspreyAirframe.unpoured`), and every vertex
## of both nacelles and both proprotors is played by the CPU copy of the shader at amounts OFF THE GRID -- the proprotor
## moved by both features, the spin inside the tilt -- against where the parts draw it.
func _the_vat_draws_the_moving_parts_where_the_parts_are(parts: OspreyAirframe) -> void:
	var cast := OspreyAirframe.new()
	add_child(cast)
	cast.dress(Sim.geometry_of(Sim.Kind.OSPREY))
	# POURED WITH THE ROTORS RUNNING, the discs shown: a view poured while they are hidden skips them anyway, and a craft
	# that spawns running is the case the filter is for.
	cast.set_rotors(true, 0.5, 0.0)
	var before: int = DrawnParts.count(cast)
	var vat: VatCasting = await VatCasting.pour(cast, cast.features(), OspreyAirframe.unpoured)
	var after: int = DrawnParts.count(cast)
	var worst: float = 0.0
	var worst_at: String = ""
	var names: Array = []
	for f in vat.features:
		names.append(f["name"])
	for amounts in [[0.137, 0.613, 0.291, 0.377, 0.163], [0.471, 0.089, 0.557, 0.719, 0.641], [0.853, 0.911, 0.853, 0.911, 0.853]]:
		parts.set_tilt(amounts[0])
		parts.set_spin(amounts[1])
		parts.set_gear(amounts[2])
		parts.set_ramp(amounts[3])
		parts.set_door(amounts[4])
		var wanted: Array = amounts
		for part in ["NacelleStarboard", "NacellePort", "ProprotorStarboard", "ProprotorPort", "NoseGear",
				"MainGearPort", "MainDoorStarboard", "NoseDoorPort", "Ramp", "RampDoor", "CrewDoorLower", "CrewDoorUpper"]:
			var truth_part := parts.find_child(part, true, false) as MeshInstance3D
			var column: int = vat.columns.find(cast.find_child(part, true, false))
			if column < 0:
				worst = INF
				worst_at = "%s was not poured" % part
				continue
			var tags: Vector2i = vat.features_of(column)
			for vertex in (truth_part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var truth: Vector3 = parts.global_transform.affine_inverse() * truth_part.global_transform * vertex
				var played: Vector3 = vat.played_point(column, vat.rest_poses[column] * vertex, tags.x, tags.y, wanted)
				if played.distance_to(truth) > worst:
					worst = played.distance_to(truth)
					worst_at = "%s at %s" % [part, amounts]
	parts.set_tilt(OspreyAirframe.vertical())
	parts.set_spin(0.0)
	parts.set_gear(1.0)
	parts.set_ramp(0.0)
	parts.set_door(0.0)
	var discs_left: int = 0
	for node in cast.find_children("*Disc", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).layers != 0:
			discs_left += 1
	_check("the_vat_draws_the_moving_parts_where_the_parts_are", worst < 0.003 and after == before and discs_left == 2,
		"features %s; worst vertex %.5f m off its part (%s), by the CPU copy of the shader; drawn parts %d before the pour and %d after; %d discs left as parts"
			% [names, worst, worst_at, before, after, discs_left])
	cast.queue_free()


## THE GAME DRAWS THIS AIRFRAME. A VehicleView of kind OSPREY builds an OspreyAirframe (and none of the old tiltrotor's
## planks), hides its collision box, and handed a bus with the nacelles part way, stands the drawn nacelles at that
## lever times the simulation's travel; with somebody aboard, its proprotors run.
func _the_game_draws_this_airframe_and_swings_it_from_the_bus() -> void:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, Sim.Kind.OSPREY)
	var airframes: Array = view.find_children("*", "OspreyAirframe", true, false)
	var old: Array = view.find_children("Tiltrotor*", "", true, false) + view.find_children("Osprey?*", "MeshInstance3D",
		true, false)
	var hull := view.find_child("Hull", true, false) as MeshInstance3D
	var ok: bool = airframes.size() == 1 and old.is_empty() and hull != null and not hull.is_visible_in_tree()
	var detail: String = "%d OspreyAirframe, %d old parts, hull %s" % [airframes.size(), old.size(),
		"hidden" if hull != null and not hull.is_visible_in_tree() else "SHOWN"]
	if airframes.size() == 1:
		var frame := airframes[0] as OspreyAirframe
		view.draw_the_osprey_from({"tilt": 0.3, "throttle": 0.0, "gear": true, "drop": false}, PackedInt64Array([7]),
			Vector3.ZERO, 0.0, 1.25)
		var angle: float = frame.tilt_angle()
		var travel: float = float(Sim.handling_of(Sim.Kind.OSPREY).get("vector_travel", NAN))
		ok = ok and absf(angle - 0.3 * travel) < 1e-5 and frame.rotors_running()
		detail += "; bus tilt 0.3 drew %.2f deg against %.2f, rotors %s" % [rad_to_deg(angle), rad_to_deg(0.3 * travel),
			"running" if frame.rotors_running() else "PARKED"]
		# THE GEAR AND THE RAMP EASE TOWARD THE BUS'S BITS: half a cycle after the bits flip, each is half way; a whole
		# cycle after, each is there.
		var bus: Dictionary = {"tilt": 0.3, "gear": false, "drop": true}
		view.draw_the_osprey_from(bus, PackedInt64Array([7]), Vector3.ZERO, OspreyAirframe.GEAR_SECONDS * 0.5, 1.25)
		var half_gear: float = frame.gear()
		view.draw_the_osprey_from(bus, PackedInt64Array([7]), Vector3.ZERO, OspreyAirframe.RAMP_SECONDS, 1.25)
		ok = ok and absf(half_gear - 0.5) < 0.01 and frame.gear() == 0.0 and frame.ramp() == 1.0
		detail += "; gear up and ramp down on the bus: gear %.2f half a cycle on, %.2f after, ramp %.2f" % [half_gear,
			frame.gear(), frame.ramp()]
	_check("the_game_draws_this_airframe_and_swings_it_from_the_bus", ok, detail)
	view.queue_free()

## THE PILOT FLIES FROM THE RIGHT, the copilot from the left, as in every V-22: read from the simulation's own seat poses,
## by station. And each flying eye stands in the drawn side windows' band, [JJ]'s 1.70 to 2.47 m over the belly.
func _the_pilot_flies_from_the_right_hand_seat(frame: OspreyAirframe) -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	var belly: float = frame.point(0.0, 0.0, 0.0).y
	for pose in Sim.geometry_of(Sim.Kind.OSPREY).get("seat_poses", []):
		var p: Dictionary = pose
		if not bool(p.get("flies", false)):
			continue
		var at: Vector3 = p["position"]
		var eye: float = at.y + CockpitStation.EYE_HEIGHT - belly
		var station: String = String(p.get("station", ""))
		said.append("%s at x %+.2f, eye %.2f m over the belly" % [station, at.x, eye])
		ok = ok and eye > WINDOW_BAND.x and eye < WINDOW_BAND.y
		if station == "pilot":
			ok = ok and at.x > 0.0
		elif station == "copilot":
			ok = ok and at.x < 0.0
	_check("the_pilot_flies_from_the_right_hand_seat", ok and said.size() == 2, ", ".join(said))


## THE GEAR'S SEQUENCE: DOORS OPEN, THEN THE LEGS MOVE, THEN THE DOORS SHUT. Stepped through the whole cycle in 1 per cent
## steps, each door and each leg read back from its DRAWN vertices against its own two ends: at no step may a leg be off
## both of its ends while any door is short of fully open; with the gear down and up the doors are shut; and the doors
## move FIRST from each end.
func _the_gear_doors_open_before_a_leg_moves_and_shut_after(frame: OspreyAirframe) -> void:
	frame.set_gear(1.0)
	var down: Dictionary = _poses(frame, LEGS + WELL_DOORS)
	frame.set_gear(0.0)
	var up: Dictionary = _poses(frame, LEGS + WELL_DOORS)
	frame.set_gear(0.5)
	var open: Dictionary = _poses(frame, WELL_DOORS)
	var bad: PackedStringArray = []
	for step in range(101):
		var amount: float = float(step) / 100.0
		frame.set_gear(amount)
		var now: Dictionary = _poses(frame, LEGS + WELL_DOORS)
		var moving: bool = false
		for leg in LEGS:
			moving = moving or (_off(now[leg], down[leg]) > 0.005 and _off(now[leg], up[leg]) > 0.005)
		var shut_ish: bool = false
		for door in WELL_DOORS:
			shut_ish = shut_ish or _off(now[door], open[door]) > 0.005
		if moving and shut_ish:
			bad.append("%.2f" % amount)
	# THE DOORS MOVE FIRST from each end, and are shut at both.
	frame.set_gear(0.05)
	var first_up: bool = _off(_poses(frame, LEGS)[LEGS[0]], up[LEGS[0]]) < 0.001 \
		and _off(_poses(frame, WELL_DOORS)[WELL_DOORS[0]], up[WELL_DOORS[0]]) > 0.01
	frame.set_gear(0.95)
	var first_down: bool = _off(_poses(frame, LEGS)[LEGS[0]], down[LEGS[0]]) < 0.001 \
		and _off(_poses(frame, WELL_DOORS)[WELL_DOORS[0]], down[WELL_DOORS[0]]) > 0.01
	var shut_both: bool = true
	for door in WELL_DOORS:
		shut_both = shut_both and _off(up[door], down[door]) < 0.001
	frame.set_gear(1.0)
	_check("the_gear_doors_open_before_a_leg_moves_and_shut_after", bad.is_empty() and first_up and first_down
		and shut_both,
		"a leg moving with a door short of open at %s; doors first from up %s, from down %s; shut at both ends %s"
			% ["no step" if bad.is_empty() else ", ".join(bad.slice(0, 6)), first_up, first_down, shut_both])


## NO LEG EVER PASSES THROUGH A DOOR. At every 2 per cent of the cycle, every edge of every leg's drawn triangles is asked
## whether it crosses any triangle of any well door. The sequence check above asks WHEN the legs move; this asks WHERE.
func _no_leg_ever_passes_through_a_door(frame: OspreyAirframe) -> void:
	var hits: PackedStringArray = []
	for step in range(51):
		var amount: float = float(step) / 50.0
		frame.set_gear(amount)
		var doors: Array = []
		for door in WELL_DOORS:
			doors.append_array(_triangles(frame, [door]))
		for leg in LEGS:
			var crossing: String = _first_crossing(frame, [leg], doors)
			if not crossing.is_empty():
				hits.append("%s at %.2f: %s" % [leg, amount, crossing])
				break
	frame.set_gear(1.0)
	_check("no_leg_ever_passes_through_a_door", hits.is_empty(),
		"legs against the four well doors at 51 amounts: %s" % ["no crossing" if hits.is_empty() else ", ".join(hits.slice(0, 4))])


## THE GEAR UP IS INSIDE THE AIRCRAFT: every drawn vertex of the nose leg inside the fuselage, and of each main leg inside
## its sponson, by ray parity fired up and down. So nothing hangs out under a shut door.
func _the_stowed_gear_is_inside_the_skin(frame: OspreyAirframe) -> void:
	frame.set_gear(0.0)
	var out: PackedStringArray = []
	for pair in [["NoseGear", "Fuselage"], ["MainGearStarboard", "SponsonStarboard"], ["MainGearPort", "SponsonPort"]]:
		var skin: Array = _triangles(frame, [pair[1]])
		var outside: int = 0
		var pts := _points(frame, _mesh(frame, pair[0]))
		for p in pts:
			if not _inside_of(skin, p + Vector3(0.0007, 0.0, 0.0007)):
				outside += 1
		if outside > 0:
			out.append("%s: %d of %d outside %s" % [pair[0], outside, pts.size(), pair[1]])
	frame.set_gear(1.0)
	_check("the_stowed_gear_is_inside_the_skin", out.is_empty(), "none outside" if out.is_empty() else ", ".join(out))


## THE RAMP: SHUT, IT CLOSES THE CABIN; OPEN, IT IS ON THE GROUND; AND ON THE WAY NOTHING PASSES THROUGH ANYTHING.
## - Shut, a point in the aft cabin is inside the fuselage, ramp and upper door taken together (ray parity), and open it
##   is not: the panels are what closes it.
## - Open, the ramp's lowest drawn point is on the ground (2 cm).
## - At every 2 per cent of the travel, no drawn vertex of either panel is below the ground, and no edge of either
##   crosses a triangle of the fuselage or the cabin floor.
func _the_ramp_shuts_the_cabin_and_lowers_to_the_ground_through_nothing(frame: OspreyAirframe) -> void:
	var aft: Vector3 = frame.point(0.0007, 1.99, 15.0007)
	frame.set_ramp(0.0)
	var shut: bool = _inside_of(_triangles(frame, ["Fuselage", "Ramp", "RampDoor"]), aft)
	frame.set_ramp(1.0)
	var opened: bool = not _inside_of(_triangles(frame, ["Fuselage", "Ramp", "RampDoor"]), aft)
	var ground: float = frame.point(0.0, OspreyAirframe.ground(), 0.0).y
	var lowest: float = _box_of(frame, [_mesh(frame, "Ramp")]).position.y
	var skin: Array = _near(_triangles(frame, ["Fuselage", "CabinFloor"]), frame.point(0.0, 0.0, 10.4).z,
		frame.point(0.0, 0.0, 16.4).z)
	var bad: PackedStringArray = []
	for step in range(51):
		var amount: float = float(step) / 50.0
		frame.set_ramp(amount)
		var low: float = _box_of(frame, [_mesh(frame, "Ramp"), _mesh(frame, "RampDoor")]).position.y
		if low < ground - 0.01:
			bad.append("below the ground by %.2f at %.2f" % [ground - low, amount])
			break
		var crossing: String = _first_crossing(frame, ["Ramp", "RampDoor"], skin)
		if not crossing.is_empty():
			bad.append("through the skin at %.2f: %s" % [amount, crossing])
			break
	frame.set_ramp(0.0)
	_check("the_ramp_shuts_the_cabin_and_lowers_to_the_ground_through_nothing", shut and opened
		and absf(lowest - ground) < 0.02 and bad.is_empty(),
		"the aft cabin enclosed shut %s, open to the air open %s; the ramp lowered %.1f degrees, its lowest point %.3f m over the ground; %s"
			% [shut, opened, rad_to_deg(frame.ramp_travel()), lowest - ground,
				"nothing through anything" if bad.is_empty() else ", ".join(bad)])


## THE CREW DOOR: shut, a ray fired out of the cabin at its middle meets a door half first; open, it meets nothing
## of the aircraft, the lower half hangs below its sill and clear of the ground; and at every 5 per cent neither half
## crosses the fuselage.
func _the_crew_door_shuts_the_side_and_opens_through_nothing(frame: OspreyAirframe) -> void:
	var middle: float = (OspreyAirframe.CREW_DOOR.x + OspreyAirframe.CREW_DOOR.y) * 0.5
	var from: Vector3 = frame.point(0.5, 1.10, middle + 0.0007)
	frame.set_door(0.0)
	var shut_hit: String = _first_hit(frame, from, Vector3.RIGHT)
	frame.set_door(1.0)
	var open_hit: String = _first_hit(frame, from, Vector3.RIGHT)
	var lower: AABB = _box_of(frame, [_mesh(frame, "CrewDoorLower")])
	var sill: float = frame.point(0.0, 0.15 * 2.6, 0.0).y
	var ground: float = frame.point(0.0, OspreyAirframe.ground(), 0.0).y
	var skin: Array = _near(_triangles(frame, ["Fuselage"]), frame.point(0.0, 0.0, 2.8).z, frame.point(0.0, 0.0, 4.9).z)
	var bad: PackedStringArray = []
	for step in range(21):
		var amount: float = float(step) / 20.0
		frame.set_door(amount)
		var crossing: String = _first_crossing(frame, ["CrewDoorLower", "CrewDoorUpper"], skin)
		if not crossing.is_empty():
			bad.append("at %.2f: %s" % [amount, crossing])
			break
	frame.set_door(0.0)
	_check("the_crew_door_shuts_the_side_and_opens_through_nothing", shut_hit.begins_with("CrewDoor")
		and open_hit == "nothing" and lower.end.y < sill + 0.05 and lower.position.y > ground and bad.is_empty(),
		"shut, the ray out meets %s; open, %s; the open lower half from %.2f to %.2f m against the sill's %.2f and the ground's %.2f; %s"
			% [shut_hit, open_hit, lower.position.y, lower.end.y, sill, ground,
				"nothing through the skin" if bad.is_empty() else ", ".join(bad)])


## BOTH PILOTS SEE OVER THE NOSE, PAST THEIR OWN COCKPITS. The game's craft with every station manned: from each flying
## eye, rays every 2.5 degrees from 2.5 to 35 below level, and every 5 degrees to 20 either side of ahead, are fired
## twice: once at the airframe alone and once at everything the view draws. Every ray the airframe's glass leaves open
## -- one that meets the glazing first, or nothing -- must meet the glazing or nothing with the cockpit in it too: no
## display, lever or placard may stand across a view the glass gives. WHY: the first station stood its flight display
## 0.21 m under the eye and 0.36 m ahead, across the view down over the nose (team-lead, off the pilot's-eye picture);
## it is low and tilted now, as the Little Bird's is. Rows 5 degrees apart missed it: its top edge fell between them.
## The airframe's own paint closes the view below about 20 degrees, which is the glass's business, not this check's.
func _both_pilots_see_over_the_nose_past_their_own_cockpits() -> void:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, Sim.Kind.OSPREY)
	view.man([0, 1, 2, 3], 0)
	var airframe: Node = view.find_children("*", "OspreyAirframe", true, false)[0]
	var blocked: PackedStringArray = []
	var open: int = 0
	var poses: Array = Sim.geometry_of(Sim.Kind.OSPREY).get("seat_poses", [])
	for seat in range(poses.size()):
		if not bool((poses[seat] as Dictionary).get("flies", false)):
			continue
		var eye: Vector3 = view.seat_anchor(seat).position + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
		for step in range(1, 15):
			var down: float = 2.5 * step
			for yaw in [-20.0, -15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 15.0, 20.0]:
				var along: Vector3 = (Vector3.FORWARD.rotated(Vector3.RIGHT, -deg_to_rad(down))).rotated(Vector3.UP,
					deg_to_rad(yaw))
				var glass_alone: String = _first_hit_in(view, eye, along, airframe)
				if glass_alone != "Fuselage/1" and glass_alone != "nothing":
					continue
				open += 1
				var with_cockpit: String = _first_hit_in(view, eye, along, null)
				if with_cockpit != "Fuselage/1" and with_cockpit != "nothing":
					blocked.append("seat %d %.0f down %+.0f: %s" % [seat, down, yaw, with_cockpit])
	_check("both_pilots_see_over_the_nose_past_their_own_cockpits", blocked.is_empty() and open >= 100,
		"%d rays the glass leaves open from the two eyes, %s" % [open, "every one still open with the cockpit in"
			if blocked.is_empty() else "blocked by the cockpit: " + ", ".join(blocked.slice(0, 6))])
	_and_each_sees_the_face_of_every_screen_in_their_station(view, poses)
	view.queue_free()


## AND EACH SEES THE FACE OF EVERY SCREEN IN THEIR STATION: from each flying eye, a ray to the middle and to four points
## near the corners of each glass in that seat's station -- the flight display and the moving map -- meets that glass
## first, and the glass faces the eye to within 60 degrees. WHY: moved out of the view over the nose, the first answer
## stood the display 0.62 m ahead and 0.78 up, wholly behind the shell's firewall bar (0.94 m up at 0.51 m ahead): clear
## of the view, and unreadable. The second copied the Little Bird's place and its matrix, and the matrix turns the glass
## 43 degrees FACE DOWN (`facing` +43 about x carries a panel's +z face to (0, -0.68, 0.73)): 97 degrees from the eye.
func _and_each_sees_the_face_of_every_screen_in_their_station(view: VehicleView, poses: Array) -> void:
	var hidden: PackedStringArray = []
	var rays: int = 0
	var screens_seen: int = 0
	for seat in range(poses.size()):
		if not bool((poses[seat] as Dictionary).get("flies", false)):
			continue
		var anchor: Node3D = view.seat_anchor(seat)
		var eye: Vector3 = anchor.position + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
		for found in anchor.find_children("*", "TouchPanel", true, false):
			var screen := found as TouchPanel
			screens_seen += 1
			var own: Dictionary = {}
			for mesh in screen.find_children("*", "MeshInstance3D", true, false):
				own[String(mesh.name)] = true
			var into: Transform3D = view.global_transform.affine_inverse() * screen.global_transform
			var to_eye: Vector3 = (eye - into.origin).normalized()
			var turned: float = rad_to_deg(acos(clampf(into.basis.z.normalized().dot(to_eye), -1.0, 1.0)))
			if turned > 60.0:
				hidden.append("seat %d's %s turned %.0f degrees from the eye" % [seat, screen.get_parent().name, turned])
			# Corners 80 per cent of the way out, so a ray grazing the glass's own edge is not the question.
			for corner in [Vector2.ZERO, Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
				var at: Vector3 = into * Vector3(corner.x * screen.size.x, corner.y * screen.size.y, 0.0)
				var hit: String = _first_hit_in(view, eye, (at - eye).normalized(), null)
				rays += 1
				if not own.has(hit.get_slice("/", 0)):
					hidden.append("seat %d's %s at %s: %s" % [seat, screen.get_parent().name, corner, hit])
	_check("and_each_sees_the_face_of_every_screen_in_their_station", hidden.is_empty() and screens_seen == 4,
		"%d screens, %d rays from the two eyes, %s" % [screens_seen, rays, "every one on its glass, facing the eye"
			if hidden.is_empty() else "hidden: " + ", ".join(hidden.slice(0, 6))])


## The first mesh and surface a ray meets among everything a view draws (or only what `within` draws), as
## "Name/surface", in the view's frame.
func _first_hit_in(view: Node3D, from: Vector3, direction: Vector3, within: Node) -> String:
	var best: float = INF
	var name_of: String = "nothing"
	for node in (within if within != null else view).find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var into := view.global_transform.affine_inverse() * mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var pts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = index.size() if not index.is_empty() else pts.size()
			for i in range(0, count - 2, 3):
				var a: Vector3 = into * pts[index[i] if not index.is_empty() else i]
				var b: Vector3 = into * pts[index[i + 1] if not index.is_empty() else i + 1]
				var c: Vector3 = into * pts[index[i + 2] if not index.is_empty() else i + 2]
				var hit = Geometry3D.ray_intersects_triangle(from, direction, a, b, c)
				if hit != null and ((hit as Vector3) - from).length() < best:
					best = ((hit as Vector3) - from).length()
					name_of = "%s/%d" % [mesh.name, surface]
	return name_of


# ---- crossings --------------------------------------------------------------------------------------------------------

## Every drawn triangle of some parts, in the craft's frame.
func _triangles(frame: Node3D, parts: Array) -> Array:
	var tris: Array = []
	for part in parts:
		var pts := _points(frame, _mesh(frame, part))
		for i in range(0, pts.size() - 2, 3):
			tris.append([pts[i], pts[i + 1], pts[i + 2]])
	return tris


## The triangles with any corner between two stations along the craft (z from `from` to `to`).
static func _near(tris: Array, from: float, to: float) -> Array:
	var out: Array = []
	for t in tris:
		for p in t:
			if (p as Vector3).z >= from and (p as Vector3).z <= to:
				out.append(t)
				break
	return out


## WHETHER ANY EDGE OF SOME PARTS CROSSES ANY OF `tris`, a crossing within 2 cm of the edge's own ends excepted (a panel's
## hinge line lies on the skin it is hinged to). "" for none, else where.
func _first_crossing(frame: Node3D, parts: Array, tris: Array) -> String:
	for part in parts:
		var pts := _points(frame, _mesh(frame, part))
		for i in range(0, pts.size() - 2, 3):
			for e in [[pts[i], pts[i + 1]], [pts[i + 1], pts[i + 2]], [pts[i + 2], pts[i]]]:
				var a: Vector3 = e[0]
				var b: Vector3 = e[1]
				for t in tris:
					var hit = Geometry3D.segment_intersects_triangle(a, b, t[0], t[1], t[2])
					if hit == null:
						continue
					var h: Vector3 = hit
					if h.distance_to(a) < 0.02 or h.distance_to(b) < 0.02:
						continue
					return "%s edge through a triangle at (%.2f, %.2f, %.2f)" % [part, h.x, h.y, h.z]
	return ""


## Where some parts are drawn now: each one's drawn vertices, to compare with another pose by `_off`.
func _poses(frame: Node3D, parts: Array) -> Dictionary:
	var out: Dictionary = {}
	for part in parts:
		out[part] = _points(frame, _mesh(frame, part))
	return out


static func _inside_of(tris: Array, p: Vector3) -> bool:
	var up: int = 0
	var down: int = 0
	for t in tris:
		if Geometry3D.ray_intersects_triangle(p, Vector3.UP, t[0], t[1], t[2]) != null:
			up += 1
		if Geometry3D.ray_intersects_triangle(p, Vector3.DOWN, t[0], t[1], t[2]) != null:
			down += 1
	return up % 2 == 1 and down % 2 == 1


# ---------------------------------------------------------------------------------------------------------------------

func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh != null and drawn.is_visible_in_tree() and not Casting._owned(drawn):
			out.append(drawn)
	return out


func _mesh(frame: Node3D, part: String) -> MeshInstance3D:
	return frame.find_child(part, true, false) as MeshInstance3D


## THE DRAWN VERTICES of a mesh in the craft's frame, never `transform * get_aabb()`.
func _points(frame: Node3D, mesh: MeshInstance3D) -> PackedVector3Array:
	var into := frame.global_transform.affine_inverse() * mesh.global_transform
	var out := PackedVector3Array()
	for s in range(mesh.mesh.get_surface_count()):
		for p in (mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(into * p)
	return out


## THE MIDDLE OF A DRAWN PROPROTOR: the mean of its blades' vertices, which three blades a third of a turn apart put on
## the rotor's axis, a little ahead of the blades' plane.
func _mesh_hub(frame: Node3D, named: String) -> Vector3:
	var pts := _points(frame, _mesh(frame, "Proprotor" + named))
	var sum := Vector3.ZERO
	for p in pts:
		sum += p
	return sum / float(pts.size())


func _box_of(frame: Node3D, meshes: Array) -> AABB:
	var box := AABB()
	var any := false
	for mesh in meshes:
		for p in _points(frame, mesh):
			box = box.expand(p) if any else AABB(p, Vector3.ZERO)
			any = true
	return box


static func _off(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var most: float = 0.0
	for i in range(a.size()):
		most = maxf(most, a[i].distance_to(b[i]))
	return most


## The slope of `v` against x over some points, by least squares over every point, as an angle in degrees.
static func _slope(rows: Array, v: Callable) -> float:
	if rows.size() < 2:
		return NAN
	var mx: float = 0.0
	var mv: float = 0.0
	for r in rows:
		mx += (r as Vector3).x
		mv += float(v.call(r))
	mx /= rows.size()
	mv /= rows.size()
	var num: float = 0.0
	var den: float = 0.0
	for r in rows:
		num += ((r as Vector3).x - mx) * (float(v.call(r)) - mv)
		den += ((r as Vector3).x - mx) * ((r as Vector3).x - mx)
	return rad_to_deg(atan(num / maxf(den, 1e-9)))


## Every exterior triangle of the fuselage for the inside test: its skin and its glazing, one closed solid.
func _skin(frame: Node3D) -> Array:
	var tris: Array = []
	var pts := _points(frame, _mesh(frame, "Fuselage"))
	for i in range(0, pts.size() - 2, 3):
		tris.append([pts[i], pts[i + 1], pts[i + 2]])
	return tris


func _inside(frame: Node3D, p: Vector3) -> bool:
	var up: int = 0
	var down: int = 0
	for t in _skin(frame):
		if Geometry3D.ray_intersects_triangle(p, Vector3.UP, t[0], t[1], t[2]) != null:
			up += 1
		if Geometry3D.ray_intersects_triangle(p, Vector3.DOWN, t[0], t[1], t[2]) != null:
			down += 1
	return up % 2 == 1 and down % 2 == 1


## The first mesh and surface a ray meets, as "Name/surface".
func _first_hit(frame: Node3D, from: Vector3, direction: Vector3) -> String:
	var best: float = INF
	var name_of: String = "nothing"
	for mesh in _meshes(frame):
		var into := frame.global_transform.affine_inverse() * mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			var pts: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for i in range(0, pts.size() - 2, 3):
				var hit = Geometry3D.ray_intersects_triangle(from, direction, into * pts[i], into * pts[i + 1],
					into * pts[i + 2])
				if hit != null and ((hit as Vector3) - from).length() < best:
					best = ((hit as Vector3) - from).length()
					name_of = "%s/%d" % [mesh.name, surface]
	return name_of


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
