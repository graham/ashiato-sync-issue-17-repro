extends Node
## Headless contract for Porco Rosso's red flying boat, `SavoiaAirframe`: the measured envelope, the features that make
## it that aeroplane and a flying boat -- a planing step, floats that sit just clear of the water, a nacelle over the wing
## with a tractor propeller that clears everything, two guns in the nose -- an open cockpit whose pilot can see forward
## through the slot under the nacelle, one object, hinges that move the right way, faces that face out, and the budget.
## Read RESULT=.
##
## THE AIRFRAME ON ITS OWN, off `Sim.Kind.SAVOIA`'s geometry, so it can be posed and measured without a world. How it
## floats, taxis and steers on the water is `tests/water_rudder.gd`'s; how it flies is `tests/handling.gd`'s, with the fleet.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, TYPED, so no check asks the builder's own constant what the builder did. [KIT] is
## FineMolds' published 21.5 cm span at 1/48; [PLAN] and [SIDE] are measured off two photographs of finished kits, good to
## about 0.1 m (`craft/savoia/sources.md`).
const LENGTH := 8.75          # muzzles 0.12 m ahead of the hull's nose to the rudder's trailing edge at 8.63 [PLAN, SIDE]
const SPAN := 10.32           # [KIT]
const HEIGHT := 3.26          # keel to nacelle top [SIDE]
const STEP_AT := 4.05         # aft of the nose [PLAN 4.00, SIDE 4.05]
const STEP_JUMP := 0.10       # the least a planing step can be and still break the water off
const FLOAT_OUT := 3.25       # [PLAN]
const FLOAT_KEEL := 0.28      # over the hull's keel [SIDE]
const WING_SWEEP := 7.0       # leading edge [PLAN]
const WING_OVER_HULL := 0.15  # the least open air between the hull's top and the wing's underside: the struts are seen
const PROP_CLEAR := 0.20      # the least a blade tip clears the hull's top by, at any angle

## Every part a reader would name looking at the film's aeroplane. A missing one fails by name; a duplicate would have
## been renamed `@MeshInstance3D@N` by Godot and fails too.
const PARTS: Array = ["Hull", "Cockpit", "Windscreen", "WingPort", "WingStarboard", "AileronPort", "AileronStarboard",
	"FloatPort", "FloatStarboard", "Nacelle", "Spinner", "Propeller", "Fin", "Rudder", "Tailplane", "Elevator", "Guns",
	"Seat"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[savoia] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_simulation_owns_the_savoia_and_it_is_a_flying_boat_with_guns()
	var frame := SavoiaAirframe.new()
	add_child(frame)
	frame.dress()
	_probe(frame)
	_every_visible_mesh_is_a_named_part(frame)
	_it_is_one_object_and_not_a_set_of_parts(frame)
	_the_drawn_aeroplane_is_the_measured_length_span_and_height(frame)
	_the_hull_has_a_planing_step(frame)
	_the_floats_ride_just_clear_of_the_water_the_hull_floats_in(frame)
	_the_sea_pushes_on_the_floats_where_they_are_drawn(frame)
	_the_wing_stands_on_struts_and_the_nacelle_over_it(frame)
	_the_propeller_is_a_tractor_that_clears_everything(frame)
	_the_guns_are_in_the_nose_and_point_forward(frame)
	_the_pilot_sees_forward_through_the_slot_under_the_nacelle(frame)
	_the_cockpit_is_open_and_the_room_is_inside_its_tub(frame)
	_the_hinged_surfaces_move_the_right_way_and_come_back(frame)
	_every_face_looks_out_of_the_hull(frame)
	_every_face_is_wound_to_its_normal(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	frame.queue_free()
	_the_trigger_fires_the_nose_guns_only_with_the_master_arm_on()
	_finish()


## THE SIMULATION OWNS THE SAVOIA. This was the clock on the draft -- red the day `Sim.Kind` named a Savoia while the
## airframe still carried its own copy of the geometry -- and it went red on 2026-09-18 when the kind arrived, as written.
## Now it holds the kind to the envelope typed here: the box, the span, ONE seat that flies, and a gun station for the
## trigger (`Sim.missile_schema`, which the seat reads to fit the trigger and the master arm).
func _the_simulation_owns_the_savoia_and_it_is_a_flying_boat_with_guns() -> void:
	var geometry: Dictionary = Sim.geometry_of(Sim.Kind.SAVOIA)
	var box: Vector3 = geometry.get("extents", Vector3.ZERO)
	var flies: Array = []
	for pose in geometry.get("seat_poses", []):
		flies.append(bool((pose as Dictionary).get("flies", true)))
	var schema: Dictionary = Sim.missile_schema(Sim.Kind.SAVOIA)
	var guns: int = 0
	for station in schema.get("stations", []):
		if bool((station as Dictionary).get("gun", false)):
			guns += 1
	_check("the_simulation_owns_the_savoia_and_it_is_a_flying_boat_with_guns",
		box.is_equal_approx(Vector3(0.63, 1.63, 4.315)) and absf(float(geometry.get("span", 0.0)) - SPAN * 0.5) < 0.001
			and flies == [true] and guns == 1 and (schema.get("launch_seats", []) as Array).has(0),
		"extents %s, half span %.2f, seats fly %s, gun stations %d, launch seats %s" % [box,
			float(geometry.get("span", 0.0)), flies, guns, schema.get("launch_seats", [])])


## A PROBE BEFORE A PICTURE: every visible mesh's drawn box in the craft's frame (`lane/tank`).
func _probe(frame: Node3D) -> void:
	for mesh in _meshes(frame):
		var box := _box_of(frame, [mesh])
		print("[savoia] probe %-18s x %6.2f..%6.2f  y %6.2f..%6.2f  z %6.2f..%6.2f  %5d tris" % [mesh.name, box.position.x,
			box.end.x, box.position.y, box.end.y, box.position.z, box.end.z, _points(frame, mesh).size() / 3])


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
	_check("every_visible_mesh_is_a_named_part", anonymous.is_empty() and missing.is_empty() and names.size() == PARTS.size(),
		"%d meshes, anonymous %s, missing %s" % [names.size(), anonymous, missing])


## ONE OBJECT: every drawn part reaches the hull (`DrawnParts`, the algorithm `joined_parts` uses).
func _it_is_one_object_and_not_a_set_of_parts(frame: Node3D) -> void:
	var stray: Array = DrawnParts.adrift(frame)
	var said: PackedStringArray = []
	for s in stray:
		said.append("%s %.2f m from %s" % [s["name"], s["gap"], s["nearest"]])
	_check("it_is_one_object_and_not_a_set_of_parts", stray.is_empty(),
		"%d parts, adrift: %s" % [DrawnParts.count(frame), ", ".join(said) if not said.is_empty() else "none"])


## THE ENVELOPE, from transformed vertices, with the height over the lowest drawn point -- the keel -- and not over the
## model's origin.
func _the_drawn_aeroplane_is_the_measured_length_span_and_height(frame: Node3D) -> void:
	var box := _box_of(frame, _meshes(frame))
	_check("the_drawn_aeroplane_is_the_measured_length_span_and_height",
		absf(box.size.z - LENGTH) <= LENGTH * 0.01 and absf(box.size.x - SPAN) <= SPAN * 0.01
			and absf(box.size.y - HEIGHT) <= HEIGHT * 0.01,
		"drawn %.3f m long, %.3f m span, %.3f m tall over the keel; measured %.3f, %.3f, %.3f"
			% [box.size.z, box.size.x, box.size.y, LENGTH, SPAN, HEIGHT])


## THE STEP: under the centreline, the drawn bottom just aft of the step is at least STEP_JUMP higher than just ahead of
## it, and the step is where the photographs put it. Rays fired up from under the hull, so it is the SKIN that is read.
func _the_hull_has_a_planing_step(frame: Node3D) -> void:
	var keel := _box_of(frame, _meshes(frame)).position.y
	var nose_z: float = _box_of(frame, [frame.find_child("Hull", true, false)]).position.z
	var bottom := func(s: float) -> float:
		return _first_up(frame, Vector3(0.0007, keel - 1.0, nose_z + s), "Hull")
	var ahead: float = float(bottom.call(STEP_AT - 0.05)) - keel
	var behind: float = float(bottom.call(STEP_AT + 0.05)) - keel
	# And the step is the break: 0.3 m further forward the bottom is still on the keel.
	var forward: float = float(bottom.call(STEP_AT - 0.30)) - keel
	_check("the_hull_has_a_planing_step", ahead < 0.01 and forward < 0.01 and behind - ahead >= STEP_JUMP,
		"bottom over the keel %.3f m at 0.30 m ahead of %.2f, %.3f at 0.05 ahead, %.3f at 0.05 behind: a %.3f m step"
			% [forward, STEP_AT, ahead, behind, behind - ahead])


## THE FLOATS: centred FLOAT_OUT out each side, their keels FLOAT_KEEL over the hull's, so a hull floating at a draught of
## 0.3 m or so has a float just touching the water, and neither float is lower than the hull (it would take the weight
## on land and on the water).
func _the_floats_ride_just_clear_of_the_water_the_hull_floats_in(frame: Node3D) -> void:
	var keel := _box_of(frame, _meshes(frame)).position.y
	var said: PackedStringArray = []
	var ok := true
	for named in ["FloatPort", "FloatStarboard"]:
		var box := _box_of(frame, [frame.find_child(named, true, false)])
		# The float's own keel: the lowest drawn point, which is below its struts.
		var over: float = box.position.y - keel
		ok = ok and absf(over - FLOAT_KEEL) < 0.03 and absf(_float_middle(frame, named) - FLOAT_OUT) < 0.05
		said.append("%s keel %.3f m over the hull's, centred %.2f m out" % [named, over, _float_middle(frame, named)])
	_check("the_floats_ride_just_clear_of_the_water_the_hull_floats_in", ok, ", ".join(said))


## THE SEA PUSHES ON THE FLOATS WHERE THEY ARE DRAWN (lane/floats, 2026-09-18). The simulation's wingtip floats
## (`kind_geometry`'s "floats", which `float_the_wingtips` pushes up on) are typed in `savoia_shape` off this airframe,
## so this holds them to it: each keel within 3 cm of the drawn float's lowest point and centre line, inside its length,
## and as tall as the drawn float. A float moved in the drawing and not in the physics would hold a wing up from the air.
func _the_sea_pushes_on_the_floats_where_they_are_drawn(frame: Node3D) -> void:
	var wet: Array = Sim.geometry_of(Sim.Kind.SAVOIA).get("floats", []) as Array
	if wet.size() != 2:
		_check("the_sea_pushes_on_the_floats_where_they_are_drawn", false, "%d floats in the simulation" % wet.size())
		return
	var said: PackedStringArray = []
	var ok := true
	for i in range(2):
		var named: String = "FloatPort" if i == 0 else "FloatStarboard"
		var box := _box_of(frame, [frame.find_child(named, true, false)])
		var keel: Vector3 = (wet[i] as Dictionary)["keel"]
		var tall: float = float((wet[i] as Dictionary)["height"])
		var middle: float = _float_middle(frame, named) * (-1.0 if i == 0 else 1.0)
		# The drawn float's top, below its struts: the highest point within the float's own depth.
		var top: float = box.position.y
		for p in _points(frame, frame.find_child(named, true, false)):
			if p.y < box.position.y + 0.6:
				top = maxf(top, p.y)
		ok = ok and absf(keel.x - middle) < 0.03 and absf(keel.y - box.position.y) < 0.03 \
			and keel.z > box.position.z and keel.z < box.end.z and absf(tall - (top - box.position.y)) < 0.05
		said.append("%s: simulation keel (%.2f, %.3f, %.2f) %.2f m tall, drawn (%.2f, %.3f, %.2f..%.2f) %.2f m tall"
			% [named, keel.x, keel.y, keel.z, tall, middle, box.position.y, box.position.z, box.end.z,
				top - box.position.y])
	_check("the_sea_pushes_on_the_floats_where_they_are_drawn", ok, ", ".join(said))


## THE WING ON STRUTS, THE NACELLE ON STRUTS OVER IT: open air under the wing's root over the hull's top, and open air
## between the wing's top and the nacelle's belly, read by rays straight down the centreline through the drawn parts.
func _the_wing_stands_on_struts_and_the_nacelle_over_it(frame: Node3D) -> void:
	var nacelle := _box_of(frame, [frame.find_child("Nacelle", true, false)])
	var from := Vector3(0.0007, nacelle.end.y + 1.0, _wing_middle_z(frame))
	var hits: Array = _all_down(frame, from)
	# Expect, from the top: nacelle (in and out), wing (in and out), hull.
	var order: PackedStringArray = []
	for h in hits:
		order.append("%s@%.2f" % [h[1], h[0]])
	var names: Array = []
	for h in hits:
		if names.is_empty() or names[-1] != h[1]:
			names.append(h[1])
	var gap_under_wing: float = NAN
	var gap_over_wing: float = NAN
	for i in range(hits.size() - 1):
		if hits[i][1] == "WingStarboard" or hits[i][1] == "WingPort":
			if hits[i + 1][1] == "Hull":
				gap_under_wing = float(hits[i][0]) - float(hits[i + 1][0])
		if hits[i][1] == "Nacelle" and (hits[i + 1][1] == "WingStarboard" or hits[i + 1][1] == "WingPort"):
			gap_over_wing = float(hits[i][0]) - float(hits[i + 1][0])
	_check("the_wing_stands_on_struts_and_the_nacelle_over_it",
		names.size() >= 3 and names[0] == "Nacelle" and gap_under_wing >= WING_OVER_HULL and gap_over_wing >= WING_OVER_HULL,
		"down the centreline at mid-chord: %s; %.2f m of air under the wing, %.2f m over it"
			% [", ".join(order), gap_under_wing, gap_over_wing])


## THE PROPELLER: its plane ahead of the wing's leading edge and behind the hull's nose, on the nacelle's front, and
## turned through a whole turn its blade tips never come within PROP_CLEAR of the hull.
func _the_propeller_is_a_tractor_that_clears_everything(frame: SavoiaAirframe) -> void:
	var blades := frame.find_child("Propeller", true, false) as MeshInstance3D
	var wing := _box_of(frame, [frame.find_child("WingStarboard", true, false)])
	var nacelle := _box_of(frame, [frame.find_child("Nacelle", true, false)])
	var hull := frame.find_child("Hull", true, false) as MeshInstance3D
	var hull_points := _points(frame, hull)
	var worst: float = INF
	var disc := AABB()
	for step in range(24):
		frame.set_propeller(true, 0.0, float(step) / 24.0 / SavoiaAirframe.PROP_TURNS / 0.2)
		var prop := _box_of(frame, [blades])
		disc = prop if step == 0 else disc.merge(prop)
		for p in _points(frame, blades):
			# The hull's top under the blade: the highest hull vertex within 0.3 m of it in plan.
			var top: float = -INF
			for q in hull_points:
				if absf(q.x - p.x) < 0.3 and absf(q.z - p.z) < 0.6:
					top = maxf(top, q.y)
			if top > -INF:
				worst = minf(worst, p.y - top)
	frame.set_propeller(false, 0.0, 0.0)
	var ahead_of_wing: float = wing.position.z - disc.end.z
	var on_nacelle: bool = disc.get_center().z < nacelle.position.z + 0.1 and disc.get_center().y > nacelle.position.y
	_check("the_propeller_is_a_tractor_that_clears_everything", ahead_of_wing > 0.2 and on_nacelle and worst >= PROP_CLEAR
		and disc.size.y > 1.9,
		"disc %.2f m across, %.2f m ahead of the wing's leading edge, on the nacelle's front %s; tips clear the hull by %.2f m"
			% [disc.size.y, ahead_of_wing, on_nacelle, worst])


## THE GUNS: two barrels either side of the stem, the frontmost thing drawn, pointing straight ahead; and the sockets the
## simulation will fire from are at the drawn muzzles.
func _the_guns_are_in_the_nose_and_point_forward(frame: SavoiaAirframe) -> void:
	var guns := frame.find_child("Guns", true, false) as MeshInstance3D
	var all := _box_of(frame, _meshes(frame))
	var hull := _box_of(frame, [frame.find_child("Hull", true, false)])
	var sockets: Dictionary = frame.sockets()
	var said: PackedStringArray = []
	var ok := true
	for side in [1.0, -1.0]:
		var box := AABB()
		var any := false
		for p in _points(frame, guns):
			if p.x * side > 0.0:
				box = box.expand(p) if any else AABB(p, Vector3.ZERO)
				any = true
		var socket: Vector3 = sockets["gun_starboard" if side > 0.0 else "gun_port"]
		var muzzle := Vector3(box.get_center().x, box.get_center().y, box.position.z)
		# Straight ahead: the barrel's box is long and thin along z.
		var straight: bool = box.size.z > 0.6 and box.size.x < 0.12 and box.size.y < 0.12
		ok = ok and straight and muzzle.distance_to(socket) < 0.02 and absf(box.position.z - all.position.z) < 0.001
		said.append("%s muzzle %.2f m ahead of the hull, %.2f out, socket off by %.3f" % ["starboard" if side > 0.0 else "port",
			hull.position.z - box.position.z, absf(muzzle.x), muzzle.distance_to(socket)])
	_check("the_guns_are_in_the_nose_and_point_forward", ok, ", ".join(said))


## THE PILOT CAN SEE WHERE THE AEROPLANE IS GOING. From the eye, level rays straight ahead and 10 and 20 degrees either
## side meet NOTHING drawn -- through the slot between the wing and the nacelle, past the struts -- and a ray 8 degrees
## down meets the wing, which is the point of sitting behind it. An eye put under the wing sees the inside of a wing.
func _the_pilot_sees_forward_through_the_slot_under_the_nacelle(frame: SavoiaAirframe) -> void:
	var eye: Vector3 = frame.eye() + Vector3(0.0007, 0.0, 0.0)
	var blocked: PackedStringArray = []
	for yaw in [0.0, 10.0, -10.0, 20.0, -20.0]:
		var direction: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3.FORWARD
		var hit: Array = _first_hit(frame, eye, direction, ["PropellerDisc"])
		if not hit.is_empty():
			blocked.append("%+.0f deg meets %s at %.2f m" % [yaw, hit[1], hit[0]])
	var down: Array = _first_hit(frame, eye, Basis(Vector3.RIGHT, deg_to_rad(-8.0)) * Vector3.FORWARD, [])
	var wing_below: bool = not down.is_empty() and String(down[1]).begins_with("Wing")
	_check("the_pilot_sees_forward_through_the_slot_under_the_nacelle", blocked.is_empty() and wing_below,
		"eye %.2f m over the keel; level rays blocked: %s; 8 deg down meets %s"
			% [eye.y - _box_of(frame, _meshes(frame)).position.y, "none" if blocked.is_empty() else ", ".join(blocked),
				"nothing" if down.is_empty() else "%s at %.2f m" % [down[1], down[0]]])


## THE OPEN COCKPIT. `cabin_room()` promises a box; from its middle, the drawn TUB is no nearer than the box's own faces
## on every side and underneath (the SEAT stands in the room, as a seat does, and is not a wall of it), and straight up there is nothing at all (it is open). The eye is 1.35 m over the floor,
## as `CockpitStation` puts it, and the room is wide enough for a player's hips (0.40 m).
func _the_cockpit_is_open_and_the_room_is_inside_its_tub(frame: SavoiaAirframe) -> void:
	var room: Dictionary = frame.cabin_room()
	var box: AABB = room["room"]
	var middle: Vector3 = box.get_center() + Vector3(0.0007, 0.0, 0.0007)
	var faults: PackedStringArray = []
	var reach: Dictionary = {}
	var half: Vector3 = box.size * 0.5
	for pair in [[Vector3.RIGHT, half.x], [Vector3.LEFT, half.x], [Vector3.FORWARD, half.z], [Vector3.BACK, half.z],
			[Vector3.DOWN, half.y]]:
		var hit: Array = _first_hit(frame, middle, pair[0], ["Seat"])
		var d: float = INF if hit.is_empty() else float(hit[0])
		reach[str(pair[0])] = d
		if d < float(pair[1]) - 0.001:
			faults.append("%s meets %s at %.3f, inside the box's %.3f" % [pair[0], hit[1], d, pair[1]])
		# Low in the tub a ray must meet the tub, never leave the aeroplane through a hole in it.
		if pair[0] != Vector3.DOWN:
			var low: Vector3 = middle + Vector3.DOWN * half.y * 0.8
			var low_hit: Array = _first_hit(frame, low, pair[0], ["Seat"])
			if low_hit.is_empty() or low_hit[1] != "Cockpit":
				faults.append("low %s leaves through %s" % [pair[0], "nothing" if low_hit.is_empty() else low_hit[1]])
	var up: Array = _first_hit(frame, middle, Vector3.UP, [])
	if not up.is_empty():
		faults.append("up meets %s at %.2f" % [up[1], up[0]])
	var eye_over_floor: float = frame.eye().y - float(room["floor"])
	_check("the_cockpit_is_open_and_the_room_is_inside_its_tub",
		faults.is_empty() and absf(eye_over_floor - 1.35) < 0.02 and box.size.x >= 0.40,
		"room %.2f wide x %.2f tall x %.2f long, eye %.2f m over the floor; %s"
			% [box.size.x, box.size.y, box.size.z, eye_over_floor, "clear" if faults.is_empty() else "; ".join(faults)])


## THE HINGES, driven through the airframe's setters and read back from DRAWN vertices: right roll raises the right
## aileron's trailing edge and lowers the left's; nose-up raises the elevators'; right rudder swings the rudder's to
## starboard; and at zero every one is back where it was drawn.
func _the_hinged_surfaces_move_the_right_way_and_come_back(frame: SavoiaAirframe) -> void:
	var rest: Dictionary = {}
	for part in ["AileronStarboard", "AileronPort", "Elevator", "Rudder"]:
		rest[part] = _trailing(frame, part)
	frame.set_ailerons(1.0)
	frame.set_elevator(1.0)
	frame.set_rudder(1.0)
	var moved: Dictionary = {}
	for part in rest:
		moved[part] = _trailing(frame, part)
	var right: bool = (moved["AileronStarboard"] as Vector3).y > (rest["AileronStarboard"] as Vector3).y + 0.1 \
		and (moved["AileronPort"] as Vector3).y < (rest["AileronPort"] as Vector3).y - 0.1 \
		and (moved["Elevator"] as Vector3).y > (rest["Elevator"] as Vector3).y + 0.1 \
		and (moved["Rudder"] as Vector3).x > (rest["Rudder"] as Vector3).x + 0.1
	frame.set_ailerons(0.0)
	frame.set_elevator(0.0)
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


## EVERY HULL FACE LOOKS OUT OF THE HULL, judged by where it IS, not by the normal it carries: its front face (Godot's is
## clockwise as seen) must point away from the hull's axis at that station, or aft or forward for the step's riser and the
## end fans. The winding check below asks whether a face agrees with its own normal, and a face flipped along with its
## normal passes that (`lane/falcon`); this one cannot be passed that way.
func _every_face_looks_out_of_the_hull(frame: Node3D) -> void:
	var hull := frame.find_child("Hull", true, false) as MeshInstance3D
	var pts := _points(frame, hull)
	var box := _box_of(frame, [hull])
	var inward: int = 0
	var total: int = 0
	for i in range(0, pts.size() - 2, 3):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var c: Vector3 = pts[i + 2]
		var face: Vector3 = (c - a).cross(b - a)
		if face.length_squared() < 1e-12:
			continue
		total += 1
		var mid: Vector3 = (a + b + c) / 3.0
		var n: Vector3 = face.normalized()
		if absf(n.z) > 0.9:
			# The step's riser faces aft; the nose fan forward; the tail fan aft.
			var expect: float = -1.0 if mid.z < box.position.z + 0.2 else 1.0
			if n.z * expect < 0.0:
				inward += 1
			continue
		# The axis: halfway up the hull's own section at this station.
		var axis_y: float = _hull_axis_y(pts, mid.z)
		if Vector2(n.x, n.y).dot(Vector2(mid.x, mid.y - axis_y)) < 0.0:
			inward += 1
	_check("every_face_looks_out_of_the_hull", inward == 0 and total > 0, "%d of %d hull faces look inwards" % [inward, total])


func _every_face_is_wound_to_its_normal(frame: Node3D) -> void:
	var wrong: int = 0
	var total: int = 0
	var worst: Dictionary = {}
	for drawn in _meshes(frame):
		var arrays: Array = drawn.mesh.surface_get_arrays(0)
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
	_check("every_face_is_wound_to_its_normal", wrong == 0 and total > 0,
		"%d of %d faces wound against their normal %s" % [wrong, total, worst])


## THE BUDGET for a first exterior LOD: at most 100,000 triangles, 12 materials, 20 draw calls, at least one fitting that
## stops drawing at range. The scope: the whole SavoiaAirframe subtree as parked (the propeller's disc hidden).
func _the_exterior_meets_the_first_lod_budget(frame: Node3D) -> void:
	var triangles: int = 0
	var draws: int = 0
	var culled: int = 0
	var materials: Dictionary = {}
	for drawn in _meshes(frame):
		if drawn.visibility_range_end > 0.0:
			culled += 1
		materials[drawn.material_override] = true
		for s in range(drawn.mesh.get_surface_count()):
			draws += 1
			triangles += (drawn.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check("the_exterior_meets_the_first_lod_budget", triangles <= 100000 and draws <= 20 and culled >= 1
		and materials.size() <= 12,
		"the whole SavoiaAirframe subtree: %d triangles, %d draw surfaces, %d materials, %d distance-culled"
			% [triangles, draws, materials.size(), culled])


## THE GUNS FIRE, through the real path: a Savoia flying at 300 m, the pilot's trigger held for a second through
## `set_pilot_input`, first with the master arm off and then on (`Sim.Channel.MASTER`, as the seat's switch sends it).
## Safe, nothing; armed, the machine guns' rate -- a round every sixth tick, 20 in a second -- with every round going
## the way the aeroplane points.
func _the_trigger_fires_the_nose_guns_only_with_the_master_arm_on() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("the_trigger_fires_the_nose_guns_only_with_the_master_arm_on", false, "no CockpitWorld")
		return
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var made: Dictionary = world.spawn_pilot(90, Sim.Kind.SAVOIA, Vector3(0.0, 300.0, 0.0), 0.0, Vector3(0.0, 0.0, -80.0))
	var pilot: int = int(made.get("pilot", 0))
	var hold := func(seconds: float) -> int:
		var seen: Dictionary = {}
		for i in range(int(seconds * 120.0)):
			world.set_pilot_input(pilot, {"throttle": 0.8, "trigger": 1.0})
			world.tick(1.0 / 120.0)
			for shot in (world.shot_states() as Array):
				seen[int((shot as Dictionary).get("entity", 0))] = shot
		return seen.size()
	var safe: int = hold.call(1.0)
	world.set_pilot_input(pilot, {"throttle": 0.8, "command_channel": Sim.Channel.MASTER, "command_value": 1,
		"command_seq": 1})
	world.tick(1.0 / 120.0)
	var armed: int = hold.call(1.0)
	# FORWARD: the aeroplane flies along -z at 80 m/s and the rounds leave its nose at 745 m/s more.
	var ahead: bool = not (world.shot_states() as Array).is_empty()
	for shot in (world.shot_states() as Array):
		ahead = ahead and ((shot as Dictionary).get("velocity", Vector3.ZERO) as Vector3).z < -600.0
	world.teardown()
	_check("the_trigger_fires_the_nose_guns_only_with_the_master_arm_on", safe == 0 and armed >= 15 and armed <= 25 and ahead,
		"safe: %d rounds in a second; armed: %d (a machine gun's 20); every round going forward %s" % [safe, armed, ahead])


# ---------------------------------------------------------------------------------------------------------------------

func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var drawn := node as MeshInstance3D
		if drawn.mesh != null and drawn.is_visible_in_tree():
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


## The float's middle, out from the centreline: halfway between its drawn extremes below the wing's struts' feet.
func _float_middle(frame: Node3D, named: String) -> float:
	var box := AABB()
	var any := false
	var keel: float = _box_of(frame, [frame.find_child(named, true, false)]).position.y
	for p in _points(frame, frame.find_child(named, true, false)):
		if p.y < keel + 0.3:
			box = box.expand(p) if any else AABB(p, Vector3.ZERO)
			any = true
	return absf(box.get_center().x)


## Halfway along the wing's root chord, as a z.
func _wing_middle_z(frame: Node3D) -> float:
	var wing := _box_of(frame, [frame.find_child("WingStarboard", true, false)])
	var root := AABB()
	var any := false
	for p in _points(frame, frame.find_child("WingStarboard", true, false)):
		if p.x < 0.05:
			root = root.expand(p) if any else AABB(p, Vector3.ZERO)
			any = true
	return root.get_center().z if any else wing.get_center().z


## The hull's axis height at a station: halfway between its highest and lowest drawn points within 5 cm.
func _hull_axis_y(points: PackedVector3Array, z: float) -> float:
	var low: float = INF
	var high: float = -INF
	for p in points:
		if absf(p.z - z) < 0.25:
			low = minf(low, p.y)
			high = maxf(high, p.y)
	return (low + high) * 0.5


## The drawn point furthest aft on a hinged part: its trailing edge, averaged over every point within a centimetre.
func _trailing(frame: Node3D, part: String) -> Vector3:
	var mesh := frame.find_child(part, true, false) as MeshInstance3D
	var best := Vector3(0, 0, -INF)
	var sum := Vector3.ZERO
	var n: int = 0
	var pts := _points(frame, mesh)
	for p in pts:
		if p.z > best.z:
			best = p
	for p in pts:
		if p.z > best.z - 0.01:
			sum += p
			n += 1
	return sum / float(n)


## Every hit of a ray over every drawn part, [distance, part name], nearest first.
func _hits(frame: Node3D, from: Vector3, direction: Vector3, skip: Array) -> Array:
	var out: Array = []
	for mesh in _meshes(frame):
		if skip.has(String(mesh.name)):
			continue
		var pts := _points(frame, mesh)
		for i in range(0, pts.size() - 2, 3):
			var hit = Geometry3D.ray_intersects_triangle(from, direction, pts[i], pts[i + 1], pts[i + 2])
			if hit != null:
				out.append([((hit as Vector3) - from).length(), String(mesh.name)])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out


func _first_hit(frame: Node3D, from: Vector3, direction: Vector3, skip: Array) -> Array:
	var all: Array = _hits(frame, from, direction, skip)
	return [] if all.is_empty() else all[0]


## Every hit of a ray fired straight down, as [height, part name], highest first.
func _all_down(frame: Node3D, from: Vector3) -> Array:
	var out: Array = []
	for h in _hits(frame, from, Vector3.DOWN, []):
		out.append([from.y - float(h[0]), h[1]])
	return out


## The height of the first face of one part a ray fired straight up from `from` meets.
func _first_up(frame: Node3D, from: Vector3, part: String) -> float:
	var mesh := frame.find_child(part, true, false) as MeshInstance3D
	var pts := _points(frame, mesh)
	var best: float = INF
	for i in range(0, pts.size() - 2, 3):
		var hit = Geometry3D.ray_intersects_triangle(from, Vector3.UP, pts[i], pts[i + 1], pts[i + 2])
		if hit != null:
			best = minf(best, (hit as Vector3).y)
	return best


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
