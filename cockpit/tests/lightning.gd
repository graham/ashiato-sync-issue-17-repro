extends Node
## Headless contract for the F-35B airframe: its measured envelope against the published one, the features that make it
## an F-35B, a canopy with no bow, a pilot room inside the drawn skin, one object, and the four things that MOVE -- the
## nozzle through 95 degrees with the lift fan's doors open, the gear's doors opening before a leg moves and shutting after,
## the weapons bays' doors, and the stick's surfaces -- each read back from DRAWN VERTICES, never from a node's transform.
## Read RESULT=.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, TYPED, so the reference is visible in one place and no check asks the builder's
## own constant what the builder did. Every MEASURED figure is printed from the three JSF renders alone by
## `craft/lightning/measure_views.py`; the published ones are Wikipedia's for the B.
const PUBLISHED_LENGTH := 15.6
const PUBLISHED_SPAN := 10.7
const PUBLISHED_HEIGHT := 4.36
const MEASURED_LENGTH := 15.60   # the plan's nose tip to the tailplanes' inner trailing corners, 2,791 px
const MEASURED_SPAN := 10.68     # the FRONT view, tip to tip, 1,911 px (the plan's sets the scale)
const WING_SWEEP := 34.0         # the leading edge, fitted over 131 rows each side at 4 mm rms
const TAIL_SWEEP := 37.1         # the tailplane's leading edge
const FIN_CANT := 20.2           # the front view: root 1.65 m out at 1.9 m up, tip 2.22 at 3.45
const CANOPY_LENGTH := 2.25      # the plan's gold glazing, 1.95 to 4.20
const NOZZLE_TRAVEL := 95.0      # Rolls-Royce: "able to rotate through 95 degrees"

## Every part a reader would name when looking at an F-35B. A missing one fails by name; a duplicate would have been
## renamed `@MeshInstance3D@N` by Godot and fails `_every_visible_mesh_is_a_named_part`.
const PARTS: Array = ["Fuselage", "Wells", "IntakePort", "IntakeStarboard", "WingPort", "WingStarboard", "FlaperonPort",
	"FlaperonStarboard", "TailplanePort", "TailplaneStarboard", "TailBoomPort", "TailBoomStarboard", "FinPort",
	"FinStarboard", "RudderPort", "RudderStarboard", "Nozzle", "LiftFanDoor", "LiftFan", "AuxInletDoorPort",
	"AuxInletDoorStarboard", "LouvreDoorPort", "LouvreDoorStarboard", "RollPostDoorPort", "RollPostDoorStarboard",
	"BayInnerDoorPort", "BayInnerDoorStarboard", "BayOuterDoorPort", "BayOuterDoorStarboard", "NoseGear",
	"MainGearPort", "MainGearStarboard", "NoseDoorPort", "NoseDoorStarboard", "MainDoorPort", "MainDoorStarboard", "GunPod"]
const LEGS: Array = ["NoseGear", "MainGearPort", "MainGearStarboard"]
const WELL_DOORS: Array = ["NoseDoorPort", "NoseDoorStarboard", "MainDoorPort", "MainDoorStarboard"]
const FAN_DOORS: Array = ["LiftFanDoor", "AuxInletDoorPort", "AuxInletDoorStarboard", "LouvreDoorPort",
	"LouvreDoorStarboard", "RollPostDoorPort", "RollPostDoorStarboard"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lightning] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var frame := LightningAirframe.new()
	add_child(frame)
	frame.dress()
	_the_simulation_owns_the_lightning_and_seats_its_pilot_at_the_canopy(frame)
	_probe(frame)
	_every_visible_mesh_is_a_named_part(frame)
	_it_is_one_object_and_not_a_set_of_parts(frame)
	_the_drawn_aeroplane_is_the_published_length_and_span(frame)
	_every_tyre_stands_on_the_ground(frame)
	_the_wing_tail_and_fins_have_the_measured_sweep_and_cant(frame)
	_the_canopy_is_one_piece_with_no_bow_in_front_of_the_pilot(frame)
	_looking_into_each_mouth_you_see_the_throat(frame)
	_the_pilot_sits_inside_the_drawn_skin(frame)
	_the_nozzle_points_where_the_thrust_does(frame)
	_the_lift_fan_doors_open_with_the_nozzle(frame)
	_the_gear_doors_open_before_a_leg_moves_and_shut_after(frame)
	_no_leg_ever_passes_through_a_door(frame)
	_the_stowed_gear_is_inside_the_skin(frame)
	_each_bay_opens_on_its_own(frame)
	_the_hinged_surfaces_move_the_right_way_and_come_back(frame)
	_every_face_is_wound_outwards(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	await _the_vat_draws_the_moving_parts_where_the_parts_are(frame)
	frame.queue_free()
	_the_view_draws_the_nozzle_at_once_and_eases_the_gear()
	_the_game_builds_the_panoramic_display_and_mounts_the_master_arm_on_it()
	_finish()


## THE SIMULATION OWNS THE F-35B: kind 32's box is the drawing's (the intakes' 1.80 m half-width, the ground to the
## canopy's top, the nose to the tailplanes' trailing edge), its half-span the published 10.7 m's, ONE seat that flies,
## and that seat's eye -- `CockpitStation.EYE_HEIGHT` over it -- where the airframe draws the pilot's helmet. A seat typed
## in C++ that drifted from the canopy would put the pilot's head in the spine.
func _the_simulation_owns_the_lightning_and_seats_its_pilot_at_the_canopy(frame: LightningAirframe) -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.LIGHTNING)
	var box: Vector3 = geometry.get("extents", Vector3.ZERO)
	var poses: Array = geometry.get("seat_poses", [])
	var flies: Array = []
	for pose in poses:
		flies.append(bool((pose as Dictionary).get("flies", false)))
	var eye := Vector3.INF
	if poses.size() == 1:
		eye = ((poses[0] as Dictionary)["position"] as Vector3) + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	var model: int = int(geometry.get("model", -1))
	_check("the_simulation_owns_the_lightning_and_seats_its_pilot_at_the_canopy",
		box.is_equal_approx(Vector3(1.80, 1.56, 7.79)) and absf(float(geometry.get("span", 0.0)) - PUBLISHED_SPAN * 0.5) < 0.001
			and flies == [true] and eye.distance_to(frame.eye()) < 0.01 and model == Sim.Model.TILTROTOR,
		"extents %s, half span %.2f, model %d (tiltrotor %d), seats fly %s, the seat's eye %s against the canopy's %s"
			% [box, float(geometry.get("span", 0.0)), model, Sim.Model.TILTROTOR, flies, eye, frame.eye()])


## THE VIEW DRAWS THE NOZZLE AT ONCE AND EASES THE GEAR. A `VehicleView` of the kind draws a `LightningAirframe`, and is
## handed a bus as `draw` hands it one: the nozzle is where the tilt channel says on the same frame, because the thrust
## is (an eased nozzle would be drawn somewhere the thrust is not); and the gear, told up, is half way through its cycle
## after half of `GEAR_SECONDS` and fully up after all of it, and back down the same way.
func _the_view_draws_the_nozzle_at_once_and_eases_the_gear() -> void:
	var view := (load("res://objects/vehicles/craft_lightning.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view._show_in_editor()
	var drawn := view.find_child("Lightning", true, false) as LightningAirframe
	if drawn == null:
		_check("the_view_draws_the_nozzle_at_once_and_eases_the_gear", false, "the view drew no LightningAirframe")
		view.queue_free()
		return
	var half: float = LightningAirframe.GEAR_SECONDS * 0.5
	view.draw_the_lightning_from({"tilt": 0.6, "gear": false}, {}, 0.0, 0.0)
	var nozzle: float = drawn.nozzle()
	view.draw_the_lightning_from({"tilt": 0.6, "gear": false}, {}, half, 0.0)
	var mid: float = drawn.gear()
	view.draw_the_lightning_from({"tilt": 0.6, "gear": false}, {}, half, 0.0)
	var up: float = drawn.gear()
	view.draw_the_lightning_from({"tilt": 0.0, "gear": true}, {}, LightningAirframe.GEAR_SECONDS, 0.0)
	var down: float = drawn.gear()
	_check("the_view_draws_the_nozzle_at_once_and_eases_the_gear",
		absf(nozzle - 0.6) < 0.001 and absf(mid - 0.5) < 0.001 and up < 0.001 and down > 0.999 and drawn.nozzle() < 0.001,
		"tilt 0.6 drawn at once as %.3f; gear told up: %.3f after %.1f s, %.3f after %.1f; told down again: %.3f"
			% [nozzle, mid, half, up, half * 2.0, down])
	# THE BAYS, EASED TOWARD THE SERVER'S BITS over the same second the server waits before a missile moves: the port bit
	# (1 << 1) opens the port bay's doors, half way in half the time, and never the starboard's; a clear bit shuts them.
	var bay_half: float = LightningAirframe.BAY_SECONDS * 0.5
	var bus := {"tilt": 0.0, "gear": true}
	view.draw_the_lightning_from(bus, {}, bay_half, 0.0, {"bays": 2})
	var port_mid: float = drawn.bay(-1.0)
	var starboard_mid: float = drawn.bay(1.0)
	view.draw_the_lightning_from(bus, {}, bay_half, 0.0, {"bays": 2})
	var port_open: float = drawn.bay(-1.0)
	view.draw_the_lightning_from(bus, {}, LightningAirframe.BAY_SECONDS, 0.0, {"bays": 0})
	var port_shut: float = drawn.bay(-1.0)
	_check("the_view_eases_each_bay_toward_its_bit",
		absf(port_mid - 0.5) < 0.001 and starboard_mid < 0.001 and port_open > 0.999 and port_shut < 0.001,
		"port bit set: port %.3f and starboard %.3f after %.1f s, port %.3f after %.1f; bit clear: port %.3f"
			% [port_mid, starboard_mid, bay_half, port_open, bay_half * 2.0, port_shut])
	view.queue_free()

## THE STATION THE GAME BUILDS -- from the craft package, not the scene -- has the panoramic display at the size the seat
## authors, and the master arm stands on that display's bezel. The package carried only the page until 2026-09-19, so
## the game drew the B's 0.51 m display at the default 0.26 m, and the master arm, placed by the generic rule on a
## glareshield the B does not have, floated in the air over the left sill (team-lead, step 2's pilot's-eye picture).
func _the_game_builds_the_panoramic_display_and_mounts_the_master_arm_on_it() -> void:
	var authored := (VehicleCatalogue.seat_scene(Sim.Kind.LIGHTNING) as PackedScene).instantiate() as Node3D
	var wanted: Vector2 = (authored.get_node("Display") as CraftDisplay).size
	authored.free()
	var built: Dictionary = AuthoredCraftPackages.make_station(Sim.Kind.LIGHTNING, 0)
	var station := built.get("station") as Node3D
	if station == null:
		_check("the_game_builds_the_panoramic_display_and_mounts_the_master_arm_on_it", false, "no station: %s" % built)
		return
	add_child(station)
	var screen := station.get_node_or_null("Display") as CraftDisplay
	var arm := station.get_node_or_null("MasterArm") as Node3D
	var size: Vector2 = screen.size if screen != null else Vector2.ZERO
	# ON THE BEZEL: within its width, and standing on its top edge, not above it or behind it.
	var on_it := false
	var said := "no master arm"
	if screen != null and arm != null:
		var local: Vector3 = arm.position - screen.position
		on_it = absf(local.x) <= size.x * 0.5 and absf(local.y - size.y * 0.5) <= 0.02 and absf(local.z) <= 0.02
		said = "master arm %.3f across, %.3f over the top edge, %.3f behind the glass" % [local.x, local.y - size.y * 0.5, local.z]
	_check("the_game_builds_the_panoramic_display_and_mounts_the_master_arm_on_it",
		size.is_equal_approx(wanted) and wanted.x > 0.5 and on_it,
		"the package's display %.2f x %.2f m against the seat's %.2f x %.2f; %s" % [size.x, size.y, wanted.x, wanted.y, said])
	station.queue_free()


## A PROBE BEFORE A PICTURE: every visible mesh's drawn box in the craft's frame, printed.
func _probe(frame: Node3D) -> void:
	for mesh in _meshes(frame):
		var box := _box_of(frame, [mesh])
		print("[lightning] probe %-22s x %6.2f..%6.2f  y %6.2f..%6.2f  z %6.2f..%6.2f" % [mesh.name, box.position.x,
			box.end.x, box.position.y, box.end.y, box.position.z, box.end.z])


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
		"%d meshes against %d named, anonymous %s, missing %s" % [names.size(), PARTS.size(), anonymous, missing])


## ONE OBJECT: every drawn part reaches the fuselage (`DrawnParts.adrift`, the algorithm `joined_parts` uses), with the
## gear down, the doors open and the nozzle down as well as all shut: a door that opens away from its aeroplane is adrift.
func _it_is_one_object_and_not_a_set_of_parts(frame: LightningAirframe) -> void:
	var said: PackedStringArray = []
	for pose in [[1.0, 0.0, 0.0], [0.5, 1.0, 1.0], [0.0, 1.0, 0.0]]:
		frame.set_gear(pose[0])
		frame.set_nozzle(pose[1])
		frame.set_bay(1.0, pose[2])
		frame.set_bay(-1.0, pose[2])
		for s in DrawnParts.adrift(frame):
			said.append("%s %.2f m from %s at gear %.1f nozzle %.1f" % [s["name"], s["gap"], s["nearest"], pose[0], pose[1]])
	frame.set_gear(1.0)
	frame.set_nozzle(0.0)
	frame.set_bay(1.0, 0.0)
	frame.set_bay(-1.0, 0.0)
	_check("it_is_one_object_and_not_a_set_of_parts", said.is_empty(),
		"%d parts, adrift: %s" % [DrawnParts.count(frame), ", ".join(said) if not said.is_empty() else "none"])


## THE ENVELOPE, from transformed vertices, against the published length and span (2 per cent) and the renders' own
## (1 per cent). THE HEIGHT IS NOT CHECKED HERE, and that is deliberate: the renders draw the gear up, so the ground is
## put under the fin tip at the published 4.36 m (`LightningAirframe.CLEARANCE`) and a height check would be the model
## agreeing with itself. The ground is held instead to the tyres (`_every_tyre_stands_on_the_ground`).
func _the_drawn_aeroplane_is_the_published_length_and_span(frame: Node3D) -> void:
	var box := _box_of(frame, _meshes(frame))
	var nose: float = _box_of(frame, [frame.find_child("Fuselage", true, false)]).position.z
	var length: float = box.end.z - nose
	_check("the_drawn_aeroplane_is_the_published_length_and_span",
		absf(length - PUBLISHED_LENGTH) <= PUBLISHED_LENGTH * 0.02 and absf(box.size.x - PUBLISHED_SPAN) <= PUBLISHED_SPAN * 0.02
			and absf(length - MEASURED_LENGTH) <= MEASURED_LENGTH * 0.01 and absf(box.size.x - MEASURED_SPAN) <= MEASURED_SPAN * 0.01,
		"drawn %.3f m long and %.3f m across; published %.2f and %.2f, measured off the renders %.2f and %.2f; %.3f m tall over the tyres, BUILT to the published %.2f"
			% [length, box.size.x, PUBLISHED_LENGTH, PUBLISHED_SPAN, MEASURED_LENGTH, MEASURED_SPAN, box.size.y,
				PUBLISHED_HEIGHT])


## THE TYRES, gear down: all three bottoms on one ground, which is the lowest drawn point of the aeroplane.
func _every_tyre_stands_on_the_ground(frame: LightningAirframe) -> void:
	frame.set_gear(1.0)
	var all := _box_of(frame, _meshes(frame))
	var bottoms: Array = []
	for leg in LEGS:
		bottoms.append(_dark_box(frame, frame.find_child(leg, true, false) as MeshInstance3D).position.y)
	var level: bool = absf(float(bottoms.max()) - float(bottoms.min())) < 0.005 \
		and absf(float(bottoms.min()) - all.position.y) < 0.005
	var ground: float = frame.point(0.0, LightningAirframe.ground(), 0.0).y
	_check("every_tyre_stands_on_the_ground", level and absf(float(bottoms.min()) - ground) < 0.005,
		"tyre bottoms %s, the lowest drawn point %.3f, the ground %.3f" % [bottoms, all.position.y, ground])


## THE PLANFORM against the renders' fits: the wing's and tailplane's leading-edge sweeps and the fins' cant, read off the
## DRAWN vertices, so a builder that took the right constant and misused it fails.
func _the_wing_tail_and_fins_have_the_measured_sweep_and_cant(frame: Node3D) -> void:
	var wing_edge := _leading_points(frame, "WingStarboard", 2.55, 5.4)
	var tail_edge := _leading_points(frame, "TailplaneStarboard", 1.6, 3.7)
	var wing: float = _slope(wing_edge, func(p: Vector3) -> float: return p.z)
	var tail: float = _slope(tail_edge, func(p: Vector3) -> float: return p.z)
	# THE FIN'S CANT: its drawn points' spread out against up, by least squares over every vertex of the fin.
	var fin_points: Array = []
	for p in _points(frame, frame.find_child("FinStarboard", true, false) as MeshInstance3D):
		fin_points.append(Vector3(p.y, p.x, 0.0))
	var cant: float = _slope(fin_points, func(p: Vector3) -> float: return p.y)
	_check("the_wing_tail_and_fins_have_the_measured_sweep_and_cant",
		absf(wing - WING_SWEEP) < 0.5 and absf(tail - TAIL_SWEEP) < 0.7 and absf(cant - FIN_CANT) < 1.0,
		"wing leading edge %.2f deg over %d stations (measured %.1f), tailplane %.2f over %d (%.1f), fin canted %.2f deg (%.1f)"
			% [wing, wing_edge.size(), WING_SWEEP, tail, tail_edge.size(), TAIL_SWEEP, cant, FIN_CANT])


## THE CANOPY IS ONE PIECE WITH NO BOW. Its drawn glass runs the renders' 2.25 m, and fired DOWN the top centreline from
## the windscreen's foot to the eye, every ray meets glass first: a frame across the canopy ahead of the pilot would be
## met first somewhere.
func _the_canopy_is_one_piece_with_no_bow_in_front_of_the_pilot(frame: LightningAirframe) -> void:
	var fuselage := frame.find_child("Fuselage", true, false) as MeshInstance3D
	var glass := _box_of_points(_surface_points(frame, fuselage, 1))
	var hits: Dictionary = {}
	var z: float = glass.position.z + 0.05
	var rays: int = 0
	while z < frame.eye().z:
		var first: String = _first_down(frame, Vector3(0.0007, 10.0, z))
		hits[first] = int(hits.get(first, 0)) + 1
		rays += 1
		z += 0.05
	_check("the_canopy_is_one_piece_with_no_bow_in_front_of_the_pilot",
		absf(glass.size.z - CANOPY_LENGTH) < 0.08 and hits.keys() == ["Fuselage/1"] and rays >= 20,
		"glass %.3f m long (measured %.2f); %d rays down the top from the windscreen to the eye met %s"
			% [glass.size.z, CANOPY_LENGTH, rays, hits])


## LOOKING INTO EACH MOUTH YOU SEE THE THROAT. Rays fired straight aft from ahead of each intake, across its mouth, must
## meet a dark face first: a mouth drawn as a grey panel, or a throat with the body's own skin in front of it, fails.
func _looking_into_each_mouth_you_see_the_throat(frame: LightningAirframe) -> void:
	var seen: Dictionary = {}
	var rays: int = 0
	for side in [1.0, -1.0]:
		for share in [[0.35, 0.3], [0.5, 0.5], [0.6, 0.75], [0.45, 0.6]]:
			# A point inside the mouth's quadrilateral, by its two shares across and up.
			var m: Array = LightningAirframe.MOUTH
			var low: Vector2 = Vector2(float(m[0][0]), float(m[0][1])).lerp(Vector2(float(m[1][0]), float(m[1][1])), share[0])
			var high: Vector2 = Vector2(float(m[3][0]), float(m[3][1])).lerp(Vector2(float(m[2][0]), float(m[2][1])), share[0])
			var at: Vector2 = low.lerp(high, share[1])
			var from: Vector3 = frame.point(side * at.x, at.y, 3.0) + Vector3(0.0007, 0.0007, 0.0)
			var hit: Color = _first_colour(frame, from, Vector3.BACK)
			var key: String = "dark" if hit.v < 0.1 else "grey %.2f" % hit.v
			seen[key] = int(seen.get(key, 0)) + 1
			rays += 1
	_check("looking_into_each_mouth_you_see_the_throat", seen.keys() == ["dark"],
		"%d rays fired aft into the two intakes met %s" % [rays, seen])


## THE PILOT IS INSIDE THE AEROPLANE. Every corner of `cabin_room()`'s box, and the eye, inside the drawn fuselage by ray
## parity fired up and down only, both odd (`modelling_here.md` section 6).
func _the_pilot_sits_inside_the_drawn_skin(frame: LightningAirframe) -> void:
	var room: Dictionary = frame.cabin_room()
	var box: AABB = room["room"]
	var outside: PackedStringArray = []
	var points: Array = [frame.eye() + Vector3(0.0007, 0.0, 0.0007), box.get_center() + Vector3(0.0007, 0.0, 0.0007)]
	for i in range(8):
		var corner: Vector3 = box.get_endpoint(i)
		points.append(corner + (box.get_center() - corner).normalized() * 0.001 + Vector3(0.0007, 0.0, 0.0007))
	for p in points:
		if not _inside(frame, p):
			outside.append("%s" % p)
	var floor_ok: bool = float(room["floor"]) < frame.eye().y - 0.5 and float(room["floor"]) >= box.position.y - 0.001
	_check("the_pilot_sits_inside_the_drawn_skin", outside.is_empty() and floor_ok and box.size.x >= 0.6,
		"room %.2f wide x %.2f tall x %.2f long, eye %.2f m over the floor; outside the skin: %s"
			% [box.size.x, box.size.y, box.size.z, frame.eye().y - float(room["floor"]),
				"none" if outside.is_empty() else ", ".join(outside)])


## THE NOZZLE POINTS WHERE THE THRUST DOES, at 0, a half and 1 of its lever. The DRAWN nozzle's axis -- the line from its
## root ring's middle to its exit's, never the hinge node -- must be the exact opposite of the thrust the simulation
## pushes the aeroplane along at that lever (`Sim.thrust_axis_of`, the expression `fly_tiltrotor` uses), to half a degree;
## and at the stop both must be the published 95 degrees. One number, one place: the drawing reads the kind's
## `vector_travel`, and a nozzle drawn anywhere the thrust is not is red here.
func _the_nozzle_points_where_the_thrust_does(frame: LightningAirframe) -> void:
	var nozzle := frame.find_child("Nozzle", true, false) as MeshInstance3D
	frame.set_nozzle(0.0)
	var rest: PackedVector3Array = _points(frame, nozzle)
	# Which drawn vertices are the root ring and which the exit, decided once at rest by station and kept by index.
	var fore: float = INF
	var aft: float = -INF
	for p in rest:
		fore = minf(fore, p.z)
		aft = maxf(aft, p.z)
	var said: PackedStringArray = []
	var ok := true
	for amount in [0.0, 0.5, 1.0]:
		frame.set_nozzle(amount)
		var pts: PackedVector3Array = _points(frame, nozzle)
		var root := Vector3.ZERO
		var exit := Vector3.ZERO
		var nr: int = 0
		var ne: int = 0
		for i in range(rest.size()):
			if rest[i].z < fore + 0.01:
				root += pts[i]
				nr += 1
			elif rest[i].z > aft - 0.11:
				exit += pts[i]
				ne += 1
		var axis: Vector3 = exit / float(ne) - root / float(nr)
		var angle: float = rad_to_deg(atan2(-axis.y, axis.z))
		var thrust: Vector3 = Sim.thrust_axis_of(Sim.Kind.LIGHTNING, amount)
		var apart: float = rad_to_deg(axis.normalized().angle_to(-thrust)) if thrust != Vector3.ZERO else 180.0
		ok = ok and apart < 0.5
		if amount == 1.0:
			ok = ok and absf(angle - NOZZLE_TRAVEL) < 0.5
		said.append("lever %.1f: drawn %.2f deg down, %.2f deg from the thrust's reverse %s" % [amount, angle, apart, thrust])
	frame.set_nozzle(0.0)
	_check("the_nozzle_points_where_the_thrust_does", ok, ", ".join(said) + "; published %.0f at the stop" % NOZZLE_TRAVEL)


## THE LIFT FAN'S DOORS OPEN WITH THE NOZZLE and are open by the time it has turned a tenth: the big door's front edge
## stands up, the auxiliary doors rise, the louvre and roll-post doors drop. Shut again at 0, every one where it was drawn.
func _the_lift_fan_doors_open_with_the_nozzle(frame: LightningAirframe) -> void:
	frame.set_nozzle(0.0)
	var shut: Dictionary = {}
	for door in FAN_DOORS:
		shut[door] = _box_of(frame, [frame.find_child(door, true, false)])
	frame.set_nozzle(0.1)
	var said: PackedStringArray = []
	var ok := true
	for door in FAN_DOORS:
		var open: AABB = _box_of(frame, [frame.find_child(door, true, false)])
		var before: AABB = shut[door]
		var moved: float = (open.end.y - before.end.y) if (door as String).begins_with("LiftFan") \
			or (door as String).begins_with("AuxInlet") else (before.position.y - open.position.y)
		ok = ok and moved > 0.15
		said.append("%s %.2f m" % [door, moved])
	frame.set_nozzle(0.0)
	var back := true
	for door in FAN_DOORS:
		back = back and _box_of(frame, [frame.find_child(door, true, false)]).is_equal_approx(shut[door])
	_check("the_lift_fan_doors_open_with_the_nozzle", ok and back,
		"at a tenth of the nozzle's travel each door has moved out of the skin by %s; shut again at 0 %s"
			% [", ".join(said), back])


## THE GEAR'S SEQUENCE: DOORS OPEN, THEN THE LEGS MOVE, THEN THE DOORS SHUT. Stepped through the whole cycle in 1 per cent
## steps, each well door and each leg read back from its drawn vertices against its own two ends: at no step may a leg be
## off both of its ends while any well door is short of fully open; with the gear down and up the well doors are shut; and
## the order is seen both ways, the doors moving FIRST from each end.
func _the_gear_doors_open_before_a_leg_moves_and_shut_after(frame: LightningAirframe) -> void:
	frame.set_gear(1.0)
	var down: Dictionary = _poses(frame, LEGS + WELL_DOORS)
	frame.set_gear(0.0)
	var up: Dictionary = _poses(frame, LEGS + WELL_DOORS)
	frame.set_gear(0.5)
	var open: Dictionary = _poses(frame, WELL_DOORS)
	var faults: PackedStringArray = []
	var first_door: float = -1.0
	var first_leg: float = -1.0
	for step in range(101):
		var amount: float = float(step) / 100.0
		frame.set_gear(amount)
		var now: Dictionary = _poses(frame, LEGS + WELL_DOORS)
		var legs_moving: bool = false
		for leg in LEGS:
			if _off(now[leg], down[leg]) > 0.001 and _off(now[leg], up[leg]) > 0.001:
				legs_moving = true
		var doors_open: bool = true
		var doors_moved: bool = false
		for door in WELL_DOORS:
			doors_open = doors_open and _off(now[door], open[door]) < 0.001
			doors_moved = doors_moved or _off(now[door], up[door]) > 0.001
		if legs_moving and not doors_open:
			faults.append("%.2f" % amount)
		if doors_moved and first_door < 0.0:
			first_door = amount
		if legs_moving and first_leg < 0.0:
			first_leg = amount
	var shut_down := true
	for door in WELL_DOORS:
		shut_down = shut_down and _off(down[door], up[door]) < 0.001
	frame.set_gear(1.0)
	_check("the_gear_doors_open_before_a_leg_moves_and_shut_after",
		faults.is_empty() and shut_down and first_door >= 0.0 and first_leg > first_door,
		"legs moving with a well door short of open at amounts %s; the well doors shut both down and up %s; from gear up the doors first move at %.2f and the legs at %.2f"
			% ["none" if faults.is_empty() else ", ".join(faults), shut_down, first_door, first_leg])


## NO LEG EVER PASSES THROUGH A DOOR. At every 2 per cent of the cycle, every edge of every leg's drawn triangles is asked
## whether it crosses any triangle of any well door or bay door. The sequence check above asks WHEN the legs move; this
## asks WHERE, so a leg built to come down beside its open door rather than into it is held to that too.
func _no_leg_ever_passes_through_a_door(frame: LightningAirframe) -> void:
	var doors: Array = WELL_DOORS + ["BayInnerDoorPort", "BayInnerDoorStarboard", "BayOuterDoorPort",
		"BayOuterDoorStarboard"]
	var hits: Dictionary = {}
	for step in range(51):
		var amount: float = float(step) / 50.0
		frame.set_gear(amount)
		var door_tris: Array = []
		for door in doors:
			var pts := _points(frame, frame.find_child(door, true, false) as MeshInstance3D)
			for i in range(0, pts.size() - 2, 3):
				door_tris.append([pts[i], pts[i + 1], pts[i + 2], door])
		for leg in LEGS:
			var pts := _points(frame, frame.find_child(leg, true, false) as MeshInstance3D)
			for i in range(0, pts.size() - 2, 3):
				for e in [[0, 1], [1, 2], [2, 0]]:
					var a: Vector3 = pts[i + e[0]]
					var b: Vector3 = pts[i + e[1]]
					for t in door_tris:
						if Geometry3D.segment_intersects_triangle(a, b, t[0], t[1], t[2]) != null:
							var key: String = "%s through %s" % [leg, t[3]]
							if not hits.has(key):
								hits[key] = "%.2f" % amount
	frame.set_gear(1.0)
	_check("no_leg_ever_passes_through_a_door", hits.is_empty(),
		"at 51 steps of the cycle, legs crossing doors: %s" % ["none" if hits.is_empty() else str(hits)])


## THE GEAR UP IS INSIDE THE AEROPLANE: with the gear up, every drawn vertex of every leg -- strut, tyre and the leg's own
## door -- is inside the fuselage's skin by ray parity, so nothing hangs out under a shut door.
func _the_stowed_gear_is_inside_the_skin(frame: LightningAirframe) -> void:
	frame.set_gear(0.0)
	var tris := _skin(frame)
	var out: Dictionary = {}
	var total: int = 0
	for leg in LEGS:
		var seen: Dictionary = {}
		for p in _points(frame, frame.find_child(leg, true, false) as MeshInstance3D):
			var key: String = "%.3f %.3f %.3f" % [p.x, p.y, p.z]
			if seen.has(key):
				continue
			seen[key] = true
			total += 1
			if not _inside_of(tris, p + Vector3(0.0007, 0.0, 0.0007)):
				out[leg] = int(out.get(leg, 0)) + 1
				out[leg + " e.g."] = "%s" % p
	frame.set_gear(1.0)
	_check("the_stowed_gear_is_inside_the_skin", out.is_empty(),
		"%d distinct leg vertices with the gear up, outside the fuselage: %s" % [total, "none" if out.is_empty() else str(out)])


## EACH BAY OPENS ON ITS OWN: opening the starboard bay drops both its doors most of their width below the belly and leaves the
## port bay's where they were drawn; and shut again, both are back.
func _each_bay_opens_on_its_own(frame: LightningAirframe) -> void:
	var doors: Array = ["BayInnerDoorStarboard", "BayOuterDoorStarboard", "BayInnerDoorPort", "BayOuterDoorPort"]
	var shut: Dictionary = {}
	for door in doors:
		shut[door] = _box_of(frame, [frame.find_child(door, true, false)])
	frame.set_bay(1.0, 1.0)
	var drop: Array = []
	for door in doors:
		drop.append((shut[door] as AABB).position.y - _box_of(frame, [frame.find_child(door, true, false)]).position.y)
	frame.set_bay(1.0, 0.0)
	var back := true
	for door in doors:
		back = back and _box_of(frame, [frame.find_child(door, true, false)]).is_equal_approx(shut[door])
	# A door hinged along one edge and swung near vertical hangs about its own width: 80 per cent of it, derived.
	var inner_width: float = LightningAirframe.BAY_EDGES.y - LightningAirframe.BAY_EDGES.x
	var outer_width: float = LightningAirframe.BAY_EDGES.z - LightningAirframe.BAY_EDGES.y
	_check("each_bay_opens_on_its_own", float(drop[0]) > 0.8 * inner_width and float(drop[1]) > 0.8 * outer_width
		and absf(float(drop[2])) < 0.001
		and absf(float(drop[3])) < 0.001 and back,
		"the starboard bay open drops its doors %.2f and %.2f m, the port bay's move %.3f and %.3f; shut again %s"
			% [drop[0], drop[1], drop[2], drop[3], back])


## THE STICK'S SURFACES, ONE AXIS AT A TIME, read back from DRAWN vertices (the F-16 lane's lesson: two axes at once hide
## a swapped one): right roll raises the right flaperon's trailing edge and lowers the left's; nose-up raises both
## tailplanes'; right pedal swings both rudders' to starboard; and at zero every one is back where it was drawn.
func _the_hinged_surfaces_move_the_right_way_and_come_back(frame: LightningAirframe) -> void:
	var parts: Array = ["FlaperonStarboard", "FlaperonPort", "TailplaneStarboard", "TailplanePort", "RudderStarboard",
		"RudderPort"]
	var rest: Dictionary = {}
	for part in parts:
		rest[part] = _trailing(frame, part)
	var moved := func() -> Dictionary:
		var d: Dictionary = {}
		for part in parts:
			d[part] = _trailing(frame, part) - (rest[part] as Vector3)
		return d
	frame.set_flaperons(1.0)
	var roll: Dictionary = moved.call()
	frame.set_flaperons(0.0)
	frame.set_tailplanes(1.0)
	var pitch: Dictionary = moved.call()
	frame.set_tailplanes(0.0)
	frame.set_rudders(1.0)
	var yaw: Dictionary = moved.call()
	frame.set_rudders(0.0)
	var ok: bool = (roll["FlaperonStarboard"] as Vector3).y > 0.1 and (roll["FlaperonPort"] as Vector3).y < -0.1 \
		and (roll["TailplaneStarboard"] as Vector3).y > 0.05 and (roll["TailplanePort"] as Vector3).y < -0.05 \
		and (pitch["TailplaneStarboard"] as Vector3).y > 0.2 and (pitch["TailplanePort"] as Vector3).y > 0.2 \
		and absf((pitch["FlaperonStarboard"] as Vector3).y) < 0.001 \
		and (yaw["RudderStarboard"] as Vector3).x > 0.1 and (yaw["RudderPort"] as Vector3).x > 0.1 \
		and absf((yaw["TailplaneStarboard"] as Vector3).y) < 0.001
	var back := true
	for part in parts:
		back = back and _trailing(frame, part).distance_to(rest[part]) < 0.001
	_check("the_hinged_surfaces_move_the_right_way_and_come_back", ok and back,
		"roll: flaperons %+.2f / %+.2f, tailplanes %+.2f / %+.2f; pitch: tailplanes %+.2f / %+.2f; yaw: rudders %+.2f / %+.2f; back at zero %s"
			% [(roll["FlaperonStarboard"] as Vector3).y, (roll["FlaperonPort"] as Vector3).y,
				(roll["TailplaneStarboard"] as Vector3).y, (roll["TailplanePort"] as Vector3).y,
				(pitch["TailplaneStarboard"] as Vector3).y, (pitch["TailplanePort"] as Vector3).y,
				(yaw["RudderStarboard"] as Vector3).x, (yaw["RudderPort"] as Vector3).x, back])


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
## pours them into one), and at least three fittings that stop drawing at range. The scope: the whole airframe subtree.
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
	_check("the_exterior_meets_the_first_lod_budget", triangles <= 100000 and draws <= 40 and culled >= 3
		and materials.size() <= 12,
		"the whole LightningAirframe subtree: %d triangles, %d draw surfaces, %d materials, %d distance-culled"
			% [triangles, draws, materials.size(), culled])


## THE MOVING PARTS AS A VERTEX ANIMATION TEXTURE, held to the parts it was baked from. A `VatCasting` is poured from a
## second airframe with the airframe's own `features()`, and every vertex of the nozzle, the lift fan's door, a main leg
## and its door and a bay door is played by the CPU copy of the shader (`VatCasting.played_point`) at amounts OFF THE
## GRID (`vat`'s lesson: a check at a row reads 0.00000 m whatever the row count), against where the parts draw it.
func _the_vat_draws_the_moving_parts_where_the_parts_are(parts: LightningAirframe) -> void:
	var cast := LightningAirframe.new()
	add_child(cast)
	cast.dress()
	var before: int = DrawnParts.count(cast)
	var vat: VatCasting = await VatCasting.pour(cast, cast.features())
	var after: int = DrawnParts.count(cast)
	var worst: float = 0.0
	var worst_at: String = ""
	var names: Array = []
	for f in vat.features:
		names.append(f["name"])
	for amounts in [[0.137, 0.613], [0.471, 0.089], [0.853, 0.911]]:
		parts.set_nozzle(amounts[0])
		parts.set_gear(amounts[1])
		parts.set_bay(1.0, amounts[0])
		var wanted: Array = []
		for f in vat.features:
			match String(f["name"]):
				"nozzle", "bay_starboard":
					wanted.append(amounts[0])
				"gear":
					wanted.append(amounts[1])
				"pitch", "roll", "rudder":
					wanted.append(0.0)
				_:
					wanted.append(0.0)
		for part in ["Nozzle", "LiftFanDoor", "MainGearStarboard", "MainDoorStarboard", "BayOuterDoorStarboard",
				"NoseGear"]:
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
					worst_at = "%s at nozzle %.3f, gear %.3f" % [part, amounts[0], amounts[1]]
	parts.set_nozzle(0.0)
	parts.set_gear(1.0)
	parts.set_bay(1.0, 0.0)
	_check("the_vat_draws_the_moving_parts_where_the_parts_are", worst < 0.003 and after == before,
		"features %s; worst vertex %.5f m off its part (%s), by the CPU copy of the shader; drawn parts %d before the pour and %d after"
			% [names, worst, worst_at, before, after])
	cast.queue_free()


# ---------------------------------------------------------------------------------------------------------------------

func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh != null and drawn.is_visible_in_tree() and not Casting._owned(drawn):
			out.append(drawn)
	return out


## THE DRAWN VERTICES of a mesh in the craft's frame, never `transform * get_aabb()`.
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


## A leg's tyre: its DARK vertices -- rubber, not the white strut.
func _dark_box(frame: Node3D, mesh: MeshInstance3D) -> AABB:
	var pts := _points(frame, mesh)
	var colours: PackedColorArray = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var box := AABB()
	var any := false
	for i in range(pts.size()):
		if colours[i].v < 0.1:
			box = box.expand(pts[i]) if any else AABB(pts[i], Vector3.ZERO)
			any = true
	return box


## Where some parts are drawn now: each one's drawn vertices, to compare with another pose by `_off`.
func _poses(frame: Node3D, parts: Array) -> Dictionary:
	var out: Dictionary = {}
	for part in parts:
		out[part] = _points(frame, frame.find_child(part, true, false) as MeshInstance3D)
	return out


## The furthest any vertex is between two poses of one part.
static func _off(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var most: float = 0.0
	for i in range(a.size()):
		most = maxf(most, a[i].distance_to(b[i]))
	return most


## THE LEADING EDGE of a drawn surface: in each 5 cm band of span between `from` and `to` metres out, the most forward
## drawn point.
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


## The drawn trailing edge of a hinged part: the average of every point within a centimetre of its aftmost.
func _trailing(frame: Node3D, part: String) -> Vector3:
	var mesh := frame.find_child(part, true, false) as MeshInstance3D
	var pts := _points(frame, mesh)
	var best: float = -INF
	for p in pts:
		best = maxf(best, p.z)
	var sum := Vector3.ZERO
	var n: int = 0
	for p in pts:
		if p.z > best - 0.01:
			sum += p
			n += 1
	return sum / float(n)


## Every exterior triangle a ray can meet for the inside test: the fuselage, whose second surface is the canopy.
func _skin(frame: Node3D) -> Array:
	var tris: Array = []
	var pts := _points(frame, frame.find_child("Fuselage", true, false) as MeshInstance3D)
	for i in range(0, pts.size() - 2, 3):
		tris.append([pts[i], pts[i + 1], pts[i + 2]])
	return tris


func _inside(frame: Node3D, p: Vector3) -> bool:
	return _inside_of(_skin(frame), p)


static func _inside_of(tris: Array, p: Vector3) -> bool:
	var up: int = 0
	var down: int = 0
	for t in tris:
		if Geometry3D.ray_intersects_triangle(p, Vector3.UP, t[0], t[1], t[2]) != null:
			up += 1
		if Geometry3D.ray_intersects_triangle(p, Vector3.DOWN, t[0], t[1], t[2]) != null:
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


## The first mesh and surface a ray fired straight down from `from` meets, as "Name/surface".
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
