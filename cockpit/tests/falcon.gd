extends Node
## Headless contract for the F-16A Block 15 airframe: the measured envelope, the features that make it an F-16 rather
## than a jet, a single-seat canopy with no bow in front of the pilot, a pilot room inside the drawn skin, one object,
## hinged surfaces that move the right way, winding, and the budget. Read RESULT=.
##
## THE F-16 IS KIND 27 (2026-09-18). This suite builds `FalconAirframe` from the kind's own geometry and holds the kind
## to the airframe; `tests/falcon_flight.gd` flies it through a seated pilot's controls, and the view's drawing of it
## is held there too.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, TYPED, so the reference is visible in one place and no check asks the builder's
## own constant what the builder did. Every figure is MEASURED off [CEL], the 1:100 vector three-view named in
## `craft/falcon/sources.md`, and `craft/falcon/measure_threeview.py` prints each of them from the drawing alone.
## THE DRAWN LENGTH IS PITOT TIP TO FIN CAP: the fin's tip fairing runs 0.50 m past the nozzle's exit, x 165.0 against
## 160.0, so the aeroplane's aftmost point is on the fin and not the nozzle. Radome tip to fin cap is 15.17 m.
const LENGTH := 15.694        # pitot tip x 8.06 to fin cap x 165.0
const SPAN := 9.960           # over the wingtip launcher rails, 99.60 mm
const HEIGHT := 5.424         # fin top y 5.76 over the tyres' bottoms at y 60.0
const WING_SWEEP := 38.86     # leading edge, fitted over 67 rows
const TAIL_SWEEP := 41.77
const TAIL_ANHEDRAL := 10.0   # front view
const CANOPY_LENGTH := 3.66   # windscreen foot x 36.5 to aft point x 73.1
const INTAKE_LIP_AFT := 4.474 # upper lip x 52.8, aft of the pitot tip at x 8.06
const INTAKE_BOTTOM := 0.99   # its bottom, y 50.1, over the ground
const NOSE_TYRE := 0.529
const MAIN_TYRE := 0.733
const WHEELBASE := 4.183      # x 62.21 to 104.04
const TRACK := 2.542          # front view: the mains' middles at y 100.58 and 126.00
const BOOM_HALF := 1.10       # plan: the body behind the wing's trailing edge, 11.0 mm out

## Every part a reader would name when looking at an F-16. A missing one fails by name; a duplicate would have been
## renamed `@MeshInstance3D@N` by Godot and fails `_every_visible_mesh_is_a_named_part`.
const PARTS: Array = ["Fuselage", "Intake", "WingPort", "WingStarboard", "FlaperonPort", "FlaperonStarboard",
	"StabilatorPort", "StabilatorStarboard", "TailBoomPort", "TailBoomStarboard", "Fin", "Rudder", "VentralFinPort",
	"VentralFinStarboard", "Nozzle", "Gear", "GunPort"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[falcon] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var frame := FalconAirframe.new()
	add_child(frame)
	frame.dress()
	_the_simulation_owns_the_falcon_and_seats_its_pilot_at_the_canopy(frame)
	_probe(frame)
	_every_visible_mesh_is_a_named_part(frame)
	_it_is_one_object_and_not_a_set_of_parts(frame)
	_the_drawn_aeroplane_is_the_measured_length_span_and_height(frame)
	_every_tyre_stands_on_one_ground_and_circumscribes_the_drawn_tyre(frame)
	_the_intake_is_under_the_chin(frame)
	_looking_into_the_mouth_you_see_the_throat(frame)
	_the_body_steps_in_behind_the_wing(frame)
	_the_canopy_is_one_seat_long_with_no_bow_in_front_of_the_pilot(frame)
	_the_wing_and_tail_have_the_measured_sweep_and_anhedral(frame)
	_the_pilot_sits_inside_the_drawn_skin(frame)
	_the_hinged_surfaces_move_the_right_way_and_come_back(frame)
	_every_face_is_wound_outwards(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	frame.queue_free()
	_finish()


## THE SIMULATION OWNS THE F-16 NOW. This was the clock on the draft -- red the day `Sim.Kind` named an F-16 while the
## airframe still carried its own copy of the geometry -- and it went red on 2026-09-18 when the kind arrived, as written.
## Now it holds the kind to the envelope typed here and to the airframe: the box, the rails' span, ONE seat that FLIES
## (read off the pose's own `flies`), and the seat's eye -- `CockpitStation.EYE_HEIGHT` over it -- where the airframe
## says the pilot's eye is. A seat typed in C++ that drifted from the canopy would put the pilot's head in the spine.
func _the_simulation_owns_the_falcon_and_seats_its_pilot_at_the_canopy(frame: FalconAirframe) -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.FALCON)
	var box: Vector3 = geometry.get("extents", Vector3.ZERO)
	var poses: Array = geometry.get("seat_poses", [])
	var flies: Array = []
	for pose in poses:
		flies.append(bool((pose as Dictionary).get("flies", false)))
	var eye := Vector3.INF
	if poses.size() == 1:
		eye = ((poses[0] as Dictionary)["position"] as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	_check("the_simulation_owns_the_falcon_and_seats_its_pilot_at_the_canopy",
		box.is_equal_approx(Vector3(1.10, 1.5965, 7.335)) and absf(float(geometry.get("span", 0.0)) - 4.98) < 0.001
			and flies == [true] and eye.distance_to(frame.eye()) < 0.01,
		"extents %s, half span %.2f, seats fly %s, seat's eye %s against the canopy's %s"
			% [box, float(geometry.get("span", 0.0)), flies, eye, frame.eye()])


## A PROBE BEFORE A PICTURE: every visible mesh's drawn box in the craft's frame, printed, so a part floating or drawn
## wider than it should be is a line of text before it is a picture (`lane/tank`).
func _probe(frame: Node3D) -> void:
	for mesh in _meshes(frame):
		var box := _box_of(frame, [mesh])
		print("[falcon] probe %-20s x %6.2f..%6.2f  y %6.2f..%6.2f  z %6.2f..%6.2f" % [mesh.name, box.position.x, box.end.x,
			box.position.y, box.end.y, box.position.z, box.end.z])


func _every_visible_mesh_is_a_named_part(frame: Node3D) -> void:
	var anonymous: PackedStringArray = []
	var names: Dictionary = {}
	for mesh in _meshes(frame):
		if String(mesh.name).begins_with("@"):
			anonymous.append(String(mesh.name))
		names[String(mesh.name)] = true
	var missing: PackedStringArray = []
	for part in PARTS:
		if not names.has(part):
			missing.append(part)
	_check("every_visible_mesh_is_a_named_part", anonymous.is_empty() and missing.is_empty()
		and names.size() == PARTS.size(),
		"%d meshes, anonymous %s, missing %s" % [names.size(), anonymous, missing])


## ONE OBJECT: every drawn part reaches the fuselage (`tests/drawn_parts.gd`, the algorithm `joined_parts` uses). The
## water bomber was eighteen of twenty-one parts adrift with every suite green.
func _it_is_one_object_and_not_a_set_of_parts(frame: Node3D) -> void:
	var stray: Array = DrawnParts.adrift(frame)
	var said: PackedStringArray = []
	for s in stray:
		said.append("%s %.2f m from %s" % [s["name"], s["gap"], s["nearest"]])
	_check("it_is_one_object_and_not_a_set_of_parts", stray.is_empty(),
		"%d parts, adrift: %s" % [DrawnParts.count(frame), ", ".join(said) if not said.is_empty() else "none"])


## THE ENVELOPE, from transformed vertices. The height is over the GROUND the tyres stand on, found from the drawn tyres,
## not from the model's origin: a check in its subject's own frame cannot catch the frame being wrong.
func _the_drawn_aeroplane_is_the_measured_length_span_and_height(frame: Node3D) -> void:
	var box := _box_of(frame, _meshes(frame))
	var ground: float = box.position.y
	var tall: float = box.end.y - ground
	_check("the_drawn_aeroplane_is_the_measured_length_span_and_height",
		absf(box.size.z - LENGTH) <= LENGTH * 0.01 and absf(box.size.x - SPAN) <= SPAN * 0.01
			and absf(tall - HEIGHT) <= HEIGHT * 0.01,
		"drawn %.3f m long, %.3f m span, %.3f m tall over the tyres; measured %.3f, %.3f, %.3f"
			% [box.size.z, box.size.x, tall, LENGTH, SPAN, HEIGHT])


## THE TYRES: all three bottoms on one ground, and each faceted tyre CONTAINS the drawn circle -- its extent in both
## directions at least the drawn diameter -- with its axle at HALFWAY BETWEEN ITS EXTREMES, never at a mean over the
## triangle soup, which is a mean over the winding.
func _every_tyre_stands_on_one_ground_and_circumscribes_the_drawn_tyre(frame: Node3D) -> void:
	var gear := frame.find_child("Gear", true, false) as MeshInstance3D
	var all := _box_of(frame, _meshes(frame))
	var nose := _tyre_box(frame, gear, 0.0, NOSE_TYRE)
	var port := _tyre_box(frame, gear, -1.0, MAIN_TYRE)
	var starboard := _tyre_box(frame, gear, 1.0, MAIN_TYRE)
	var bottoms: Array = [nose.position.y, port.position.y, starboard.position.y]
	var level: bool = absf(bottoms.max() - bottoms.min()) < 0.005 and absf(bottoms.min() - all.position.y) < 0.005
	var contains: bool = nose.size.y >= NOSE_TYRE * 0.999 and nose.size.z >= NOSE_TYRE * 0.999 \
		and port.size.y >= MAIN_TYRE * 0.999 and port.size.z >= MAIN_TYRE * 0.999
	var base: float = (port.get_center().z) - nose.get_center().z
	var track: float = starboard.get_center().x - port.get_center().x
	# The axle is HALFWAY BETWEEN THE EXTREMES, and a circumscribing polygon with a flat on the ground puts it exactly
	# one drawn radius up. A corner on the ground puts it higher by the corner's overhang.
	var nose_axle: float = nose.get_center().y - nose.position.y
	var main_axle: float = port.get_center().y - port.position.y
	var axles: bool = absf(nose_axle - NOSE_TYRE * 0.5) < 0.005 and absf(main_axle - MAIN_TYRE * 0.5) < 0.005
	_check("every_tyre_stands_on_one_ground_and_circumscribes_the_drawn_tyre",
		level and contains and axles and absf(base - WHEELBASE) < 0.02 and absf(track - TRACK) < 0.02,
		"tyre bottoms %s against the lowest drawn point %.3f; nose %.3f x %.3f (drawn %.3f), main %.3f x %.3f (drawn %.3f); axles %.3f and %.3f up; wheelbase %.3f against %.3f, track %.3f against %.3f"
			% [bottoms, all.position.y, nose.size.y, nose.size.z, NOSE_TYRE, port.size.y, port.size.z, MAIN_TYRE,
				nose_axle, main_axle, base, WHEELBASE, track, TRACK])


## THE CHIN INTAKE, the single most recognisable thing about an F-16: on the centreline, UNDER the forward fuselage --
## below its chine, not beside it -- with its upper lip at the measured station and a dark throat inside it. An intake
## drawn as a panel on the side would pass a count of parts and fail this.
func _the_intake_is_under_the_chin(frame: Node3D) -> void:
	var intake := frame.find_child("Intake", true, false) as MeshInstance3D
	var fuselage := frame.find_child("Fuselage", true, false) as MeshInstance3D
	var box := _box_of(frame, [intake])
	var body := _box_of(frame, [fuselage])
	var ground: float = _box_of(frame, _meshes(frame)).position.y
	# From the pitot's tip, which is the drawn aeroplane's front: the one datum here that is not the builder's constant.
	var lip_aft: float = box.position.z - body.position.z
	# The throat: a dark face looking forward, found in the drawn colours, so a mouth drawn solid grey fails.
	var dark_forward: int = 0
	var arrays: Array = intake.mesh.surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(0, colours.size(), 3):
		if colours[i].v < 0.1 and normals[i].z < -0.8:
			dark_forward += 1
	var centred: bool = absf(box.get_center().x) < 0.01
	var under: bool = box.end.y < _chine_height(frame, box.position.z + 0.3)
	_check("the_intake_is_under_the_chin", centred and under and absf(lip_aft - INTAKE_LIP_AFT) < 0.05
		and absf(box.position.y - ground - INTAKE_BOTTOM) < 0.05 and dark_forward >= 6,
		"centred %s, top %.3f under the chine %s, upper lip %.3f m aft of the pitot tip (measured %.3f), bottom %.3f m over the ground (measured %.2f), %d dark faces looking out of the mouth"
			% [centred, box.end.y, under, lip_aft, INTAKE_LIP_AFT, box.position.y - ground, INTAKE_BOTTOM, dark_forward])


## LOOKING INTO THE MOUTH YOU SEE THE THROAT. Rays fired straight aft from ahead of the intake, across its mouth, must
## meet a dark face first. Counting dark faces cannot see what is IN FRONT of them: the first build put the throat 5 mm
## deep, behind the fuselage's own step down into the duct, and that grey step stood inside the mouth over the black.
func _looking_into_the_mouth_you_see_the_throat(frame: Node3D) -> void:
	var intake := frame.find_child("Intake", true, false) as MeshInstance3D
	var box := _box_of(frame, [intake])
	var seen: Dictionary = {}
	var rays: int = 0
	for u in [-0.45, -0.2, 0.0007, 0.2, 0.45]:
		for share in [0.3, 0.5, 0.7]:
			var from := Vector3(u, lerpf(box.position.y, box.end.y, share), box.position.z - 1.0)
			var hit: Color = _first_colour(frame, from, Vector3.BACK)
			var key: String = "dark" if hit.v < 0.1 else "grey %.2f" % hit.v
			seen[key] = int(seen.get(key, 0)) + 1
			rays += 1
	_check("looking_into_the_mouth_you_see_the_throat", seen.keys() == ["dark"],
		"%d rays fired aft into the intake met %s" % [rays, seen])


## THE BODY STEPS IN BEHIND THE WING, to the tail booms' 1.10 m. The plan draws a corner at the trailing edge's root; the
## first build tapered the chine over 3.5 mm there and left a triangle of body standing proud behind the wing that every
## dimension check passed and only the plan overlay showed.
func _the_body_steps_in_behind_the_wing(frame: Node3D) -> void:
	var fuselage := frame.find_child("Fuselage", true, false) as MeshInstance3D
	var wing := _box_of(frame, [frame.find_child("WingStarboard", true, false) as MeshInstance3D])
	# SLICED, NOT SAMPLED AT VERTICES. The taper runs between two rings 0.37 m apart, and a window over vertices sees only
	# the ring at each end -- the first version of this check read 1.100 m over the tapered body and passed its mutant.
	# The plane is 10.7 cm behind the trailing edge, off every ring.
	var z: float = wing.end.z + 0.107
	var widest: float = _widest_at(frame, fuselage, z)
	_check("the_body_steps_in_behind_the_wing", widest <= BOOM_HALF + 0.005 and widest > BOOM_HALF - 0.05,
		"the fuselage is %.3f m out, sliced 10.7 cm behind the wing's trailing edge; measured %.2f" % [widest, BOOM_HALF])


## HOW FAR OUT A MESH REACHES where the plane z = `z` cuts it: every triangle edge that crosses the plane, interpolated.
func _widest_at(frame: Node3D, mesh: MeshInstance3D, z: float) -> float:
	var pts := _points(frame, mesh)
	var widest: float = 0.0
	for i in range(0, pts.size() - 2, 3):
		for e in [[0, 1], [1, 2], [2, 0]]:
			var a: Vector3 = pts[i + e[0]]
			var b: Vector3 = pts[i + e[1]]
			if (a.z - z) * (b.z - z) < 0.0:
				var t: float = (z - a.z) / (b.z - a.z)
				widest = maxf(widest, absf(lerpf(a.x, b.x, t)))
	return widest


## THE CANOPY IS A SINGLE SEAT'S AND HAS NO BOW IN FRONT OF THE PILOT. Its drawn glass runs 3.66 m; a two-seater's is half
## a metre longer. And fired DOWN the top centreline from the windscreen's foot to the eye, the first thing every ray meets
## is glass: a frame across the canopy ahead of the pilot -- a Hornet's, a Cessna's -- would be met first somewhere.
func _the_canopy_is_one_seat_long_with_no_bow_in_front_of_the_pilot(frame: FalconAirframe) -> void:
	var fuselage := frame.find_child("Fuselage", true, false) as MeshInstance3D
	var glass := _box_of_points(_surface_points(frame, fuselage, FalconAirframe.CANOPY_SURFACE))
	var hits: Dictionary = {}
	var eye_z: float = frame.eye().z
	var z: float = glass.position.z + 0.05
	var rays: int = 0
	while z < eye_z:
		var first: String = _first_down(frame, Vector3(0.0007, 10.0, z))
		hits[first] = int(hits.get(first, 0)) + 1
		rays += 1
		z += 0.05
	_check("the_canopy_is_one_seat_long_with_no_bow_in_front_of_the_pilot",
		absf(glass.size.z - CANOPY_LENGTH) < 0.08 and hits.keys() == ["Fuselage/1"] and rays >= 20,
		"glass %.3f m long (measured %.2f); %d rays down the top from the windscreen to the eye met %s"
			% [glass.size.z, CANOPY_LENGTH, rays, hits])


## THE PLANFORM against the drawing's fit: the leading edges' sweep and the tailplane's droop, read off the DRAWN
## vertices, so a builder that took the right constant and misused it fails.
func _the_wing_and_tail_have_the_measured_sweep_and_anhedral(frame: Node3D) -> void:
	# The rail under the tip is left out: its nose is well ahead of the wing's own leading edge there.
	var wing_edge := _leading_points(frame, "WingStarboard", 1.1, 4.7)
	var tail_edge := _leading_points(frame, "StabilatorStarboard", 0.9, 3.0)
	var wing: float = _slope(wing_edge, func(p: Vector3) -> float: return p.z)
	var tail: float = _slope(tail_edge, func(p: Vector3) -> float: return p.z)
	var droop: float = -_slope(tail_edge, func(p: Vector3) -> float: return p.y)
	_check("the_wing_and_tail_have_the_measured_sweep_and_anhedral",
		absf(wing - WING_SWEEP) < 0.5 and absf(tail - TAIL_SWEEP) < 0.5 and absf(droop - TAIL_ANHEDRAL) < 1.0,
		"wing leading edge %.2f deg over %d stations (measured %.2f), tailplane %.2f over %d (%.2f), tailplane droops %.2f deg (%.1f)"
			% [wing, wing_edge.size(), WING_SWEEP, tail, tail_edge.size(), TAIL_SWEEP, droop, TAIL_ANHEDRAL])


## THE PILOT IS INSIDE THE AEROPLANE. `cabin_room()` promises a box; every corner of it, and the eye, must be inside the
## drawn exterior by ray parity -- fired up and down only, both odd (`modelling_here.md` section 6: horizontal rays cross
## open seams). Ten craft in this game fail this for their seats; the glider because its station is 0.86 m wide in a
## canopy 0.25 m wide. The room here is derived from the canopy, not tuned to pass.
func _the_pilot_sits_inside_the_drawn_skin(frame: FalconAirframe) -> void:
	var room: Dictionary = frame.cabin_room()
	var box: AABB = room["room"]
	var outside: PackedStringArray = []
	var nudge := Vector3(0.0007, 0.0, 0.0007)
	var points: Array = [frame.eye() + nudge, box.get_center() + nudge]
	for i in range(8):
		# Pulled a millimetre in from each corner, and nudged off the centreline and off any ring, so a ray never runs
		# along an edge or through a vertex.
		var corner: Vector3 = box.get_endpoint(i)
		points.append(corner + (box.get_center() - corner).normalized() * 0.001 + Vector3(0.0007, 0.0, 0.0007))
	for p in points:
		if not _inside(frame, p):
			outside.append("%s" % p)
	var floor_ok: bool = float(room["floor"]) < frame.eye().y - 0.5 and float(room["floor"]) >= box.position.y - 0.001
	_check("the_pilot_sits_inside_the_drawn_skin", outside.is_empty() and floor_ok and box.size.x >= 0.5,
		"room %.2f wide x %.2f tall x %.2f long, eye %.2f m over the floor; outside the skin: %s"
			% [box.size.x, box.size.y, box.size.z, frame.eye().y - float(room["floor"]),
				"none" if outside.is_empty() else ", ".join(outside)])


## THE HINGES, driven through the airframe's own setters and read back from DRAWN vertices: right roll raises the right
## flaperon's trailing edge and lowers the left's; nose-up raises both tailplanes' trailing edges; right rudder swings the
## rudder's trailing edge to starboard; and at zero every one is back where it was drawn.
func _the_hinged_surfaces_move_the_right_way_and_come_back(frame: FalconAirframe) -> void:
	var rest: Dictionary = {}
	for part in ["FlaperonStarboard", "FlaperonPort", "StabilatorStarboard", "StabilatorPort", "Rudder"]:
		rest[part] = _trailing(frame, part)
	frame.set_flaperons(1.0)
	frame.set_stabilators(1.0)
	frame.set_rudder(1.0)
	var moved: Dictionary = {}
	for part in rest:
		moved[part] = _trailing(frame, part)
	var right: bool = (moved["FlaperonStarboard"] as Vector3).y > (rest["FlaperonStarboard"] as Vector3).y + 0.1 \
		and (moved["FlaperonPort"] as Vector3).y < (rest["FlaperonPort"] as Vector3).y - 0.1 \
		and (moved["StabilatorStarboard"] as Vector3).y > (rest["StabilatorStarboard"] as Vector3).y + 0.3 \
		and (moved["StabilatorPort"] as Vector3).y > (rest["StabilatorPort"] as Vector3).y + 0.3 \
		and (moved["Rudder"] as Vector3).x > (rest["Rudder"] as Vector3).x + 0.1
	frame.set_flaperons(0.0)
	frame.set_stabilators(0.0)
	frame.set_rudder(0.0)
	var back: bool = true
	for part in rest:
		back = back and _trailing(frame, part).distance_to(rest[part]) < 0.001
	var said: PackedStringArray = []
	for part in rest:
		said.append("%s %+.2f,%+.2f" % [part, (moved[part] as Vector3).x - (rest[part] as Vector3).x,
			(moved[part] as Vector3).y - (rest[part] as Vector3).y])
	_check("the_hinged_surfaces_move_the_right_way_and_come_back", right and back,
		"trailing edges moved (x, y): %s; back at zero %s" % [", ".join(said), back])


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


## THE BUDGET for a first exterior LOD: at most 100,000 triangles, 12 materials, 20 draw calls, and at least one fitting
## that stops drawing at range. The scope, stated: the whole FalconAirframe subtree.
func _the_exterior_meets_the_first_lod_budget(frame: Node3D) -> void:
	var triangles: int = 0
	var draws: int = 0
	var culled: int = 0
	var materials: Dictionary = {}
	for drawn in _meshes(frame):
		if drawn.visibility_range_end > 0.0:
			culled += 1
		for s in range(drawn.mesh.get_surface_count()):
			materials[drawn.material_override if drawn.material_override != null
				else drawn.get_active_material(s)] = true
			draws += 1
			triangles += (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check("the_exterior_meets_the_first_lod_budget", triangles <= 100000 and draws <= 20 and culled >= 1
		and materials.size() <= 12,
		"the whole FalconAirframe subtree: %d triangles, %d draw surfaces, %d materials, %d distance-culled"
			% [triangles, draws, materials.size(), culled])


# ---------------------------------------------------------------------------------------------------------------------

func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh != null and drawn.visible:
			out.append(drawn)
	return out


## THE DRAWN VERTICES of some meshes in the craft's frame, never `transform * get_aabb()`.
func _points(frame: Node3D, mesh: MeshInstance3D) -> PackedVector3Array:
	var into := frame.global_transform.affine_inverse() * mesh.global_transform
	var out := PackedVector3Array()
	for s in range(mesh.mesh.get_surface_count()):
		for p in (mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(into * p)
	return out


func _box_of(frame: Node3D, meshes: Array) -> AABB:
	var box := AABB()
	var any := false
	for mesh in meshes:
		for p in _points(frame, mesh):
			box = box.expand(p) if any else AABB(p, Vector3.ZERO)
			any = true
	return box


## A tyre's drawn box: the Gear mesh's DARK vertices -- rubber, not the white legs -- on one side (0 = the nose, on the
## centreline). Picking by colour rather than by a height band keeps a leg's foot, which ends at the axle, out of it.
func _tyre_box(frame: Node3D, gear: MeshInstance3D, side: float, _diameter: float) -> AABB:
	var pts := _points(frame, gear)
	var colours: PackedColorArray = gear.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var box := AABB()
	var any := false
	for i in range(pts.size()):
		var p: Vector3 = pts[i]
		var on_side: bool = absf(p.x) < 0.2 if side == 0.0 else p.x * side > 0.5
		if on_side and colours[i].v < 0.1:
			box = box.expand(p) if any else AABB(p, Vector3.ZERO)
			any = true
	return box


## The height of the fuselage's widest point at a station: where the chine is. Read from drawn vertices within 2 cm.
func _chine_height(frame: Node3D, z: float) -> float:
	var fuselage := frame.find_child("Fuselage", true, false) as MeshInstance3D
	var widest: float = -INF
	var at_y: float = 0.0
	for p in _points(frame, fuselage):
		if absf(p.z - z) < 0.3 and p.x > widest:
			widest = p.x
			at_y = p.y
	return at_y


## THE LEADING EDGE of a drawn surface: in each 5 cm band of span between `from` and `to` metres out, the most forward
## drawn point. A section's leading-edge point is on its chord line, so these carry both the sweep and the droop.
func _leading_points(frame: Node3D, part: String, from: float, to: float) -> Array:
	var mesh := frame.find_child(part, true, false) as MeshInstance3D
	var bands: Dictionary = {}
	for p in _points(frame, mesh):
		if p.x < from or p.x > to:
			continue
		var band: int = int(p.x / 0.05)
		if not bands.has(band) or p.z < (bands[band] as Vector3).z:
			bands[band] = p
	return bands.values()


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


## The drawn point furthest aft on a hinged part: its trailing edge, in the craft's frame.
func _trailing(frame: Node3D, part: String) -> Vector3:
	var mesh := frame.find_child(part, true, false) as MeshInstance3D
	var best := Vector3(0, 0, -INF)
	var sum := Vector3.ZERO
	var n: int = 0
	var pts := _points(frame, mesh)
	for p in pts:
		if p.z > best.z:
			best = p
	# The average of every point within a centimetre of the aftmost, so the answer is the edge and not one corner.
	for p in pts:
		if p.z > best.z - 0.01:
			sum += p
			n += 1
	return sum / float(n)


## Every exterior triangle a ray can meet: the fuselage, whose second surface is the canopy that closes it.
func _skin(frame: Node3D) -> Array:
	var tris: Array = []
	for part in ["Fuselage"]:
		var mesh := frame.find_child(part, true, false) as MeshInstance3D
		var pts := _points(frame, mesh)
		for i in range(0, pts.size() - 2, 3):
			tris.append([pts[i], pts[i + 1], pts[i + 2], part])
	return tris


func _inside(frame: Node3D, p: Vector3) -> bool:
	var tris := _skin(frame)
	var up: int = 0
	var down: int = 0
	for t in tris:
		var hit = Geometry3D.ray_intersects_triangle(p, Vector3.UP, t[0], t[1], t[2])
		if hit != null:
			up += 1
		hit = Geometry3D.ray_intersects_triangle(p, Vector3.DOWN, t[0], t[1], t[2])
		if hit != null:
			down += 1
	return up % 2 == 1 and down % 2 == 1


## The colour of the first face a ray meets, over every drawn part.
func _first_colour(frame: Node3D, from: Vector3, direction: Vector3) -> Color:
	var best: float = INF
	var colour := Color(1, 0, 1)
	for mesh in _meshes(frame):
		for surface in range(mesh.mesh.get_surface_count()):
			var pts := _surface_points(frame, mesh, surface)
			var colours: PackedColorArray = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			for i in range(0, pts.size() - 2, 3):
				var hit = Geometry3D.ray_intersects_triangle(from, direction, pts[i], pts[i + 1], pts[i + 2])
				if hit != null and ((hit as Vector3) - from).length() < best:
					best = ((hit as Vector3) - from).length()
					colour = colours[i]
	return colour


## The first mesh and surface a ray fired straight down from `from` meets, over every drawn part, as "Name/surface".
func _first_down(frame: Node3D, from: Vector3) -> String:
	var best: float = INF
	var name_of: String = "nothing"
	for mesh in _meshes(frame):
		for surface in range(mesh.mesh.get_surface_count()):
			var pts := _surface_points(frame, mesh, surface)
			for i in range(0, pts.size() - 2, 3):
				var hit = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, pts[i], pts[i + 1], pts[i + 2])
				if hit != null and from.y - (hit as Vector3).y < best:
					best = from.y - (hit as Vector3).y
					name_of = "%s/%d" % [mesh.name, surface]
	return name_of


## One surface's drawn vertices in the craft's frame.
func _surface_points(frame: Node3D, mesh: MeshInstance3D, surface: int) -> PackedVector3Array:
	var into := frame.global_transform.affine_inverse() * mesh.global_transform
	var out := PackedVector3Array()
	for p in (mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		out.append(into * p)
	return out


func _box_of_points(pts: PackedVector3Array) -> AABB:
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	return box


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
