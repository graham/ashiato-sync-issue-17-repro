extends Node
## Headless contract for the two airliners, the 737-800 (kind `airliner`) and the 747-400 (kind `jumbo`): each one's
## drawn envelope against its published one, the parts that make it that aeroplane, a flight deck inside the drawn skin
## with glass in front of both pilots, one object, and what MOVES -- the gear's doors opening before a leg moves and
## shutting after, the flaps, spoilers and the stick's surfaces -- each read back from DRAWN VERTICES, never from a node's
## transform. Read RESULT=.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, TYPED from the published figures, so no check asks the builder's own constant what
## the builder did. The MEASURED figures are printed from Boeing's airport-planning drawings alone by
## `craft/airliner/measure_views.py` (and `craft/jumbo/measure_views.py`).

## [ACAPS] 737-800W, section 2.2.6: 129 ft 6 in, 117 ft 5 in, 41 ft 2 in; the fuselage 3.76 m [WP].
const B737 := {"class": "Boeing737", "length": 39.47, "span": 35.79, "height": 12.55, "width": 3.76,
	# MEASURED off the drawing: the wing's leading edge outboard of its kink, fitted over 475 rows a side.
	"wing_sweep": 27.26, "wing_band": [5.6, 17.05],
	# The tailplane's, over 2.6 to 6.6 m out.
	"tail_sweep": 35.73, "tail_band": [1.5, 7.3],
	# The wheelbase and the main gear's track, printed: 51 ft 2 in and 18 ft 9 in.
	"wheelbase": ["NoseGear", ["MainGearStarboard", "MainGearPort"], 15.60],
	"tracks": [["MainGearStarboard", "MainGearPort", 5.72]],
	"roll": ["AileronStarboard", "AileronPort"], "flaps": ["FlapOutboardStarboard", "FlapInboardPort"],
	"spoilers": ["SpoilersOutboardStarboard", "SpoilersInboardPort"],
	"parts": ["Fuselage", "WingToBodyFairing", "WingStarboard", "WingPort", "FlapInboardStarboard", "FlapInboardPort",
		"FlapOutboardStarboard", "FlapOutboardPort", "AileronStarboard", "AileronPort", "SpoilersInboardStarboard", "SpoilersOutboardStarboard", "SpoilersInboardPort", "SpoilersOutboardPort",
		"TailplaneStarboard", "TailplanePort", "ElevatorStarboard",
		"ElevatorPort", "Engine1", "Engine2", "Fin", "Rudder", "NoseGear", "MainGearStarboard",
		"MainGearPort", "NoseDoorStarboard", "NoseDoorPort"],
	"legs": ["NoseGear", "MainGearStarboard", "MainGearPort"],
	"well_doors": ["NoseDoorStarboard", "NoseDoorPort"],
	# The 737's mains fold into the belly with no doors: their tyres are seen there, so only the nose leg is held inside.
	"stowed_inside": ["NoseGear"],
	"engines": 2}

## [ACAPS] 747-400, section 2.2.1: 231 ft 10.25 in, and the span 211 ft 5 in in the jig (the drawing draws the 213 ft 0 in
## at maximum gross weight, 0.7 per cent over it); the height Wikipedia's, 63 ft 8 in; the fuselage 21 ft 4 in.
const B747 := {"class": "Boeing747", "length": 70.67, "span": 64.44, "height": 19.41, "width": 6.50,
	# MEASURED: the wing's leading edge inboard of its kink at 21.6 m out, 42.4 degrees over 230 rows; the tailplane's.
	"wing_sweep": 42.38, "wing_band": [3.5, 21.0],
	"tail_sweep": 42.70, "tail_band": [2.0, 11.1],
	# The nose gear to the body gear, 84 ft 0 in; the body gear's track 12 ft 7 in and the wing gear's 36 ft 1 in.
	"wheelbase": ["NoseGear", ["BodyGearStarboard", "BodyGearPort"], 25.60],
	"tracks": [["BodyGearStarboard", "BodyGearPort", 3.84], ["WingGearStarboard", "WingGearPort", 11.00]],
	"roll": ["AileronOutboardStarboard", "AileronOutboardPort"], "flaps": ["FlapOutboardStarboard", "FlapInboardPort"],
	"spoilers": ["SpoilersOutboardStarboard", "SpoilersInboardPort"],
	"parts": ["Fuselage", "WingToBodyFairing", "UpperDeckFloor", "WingStarboard", "WingPort", "FlapInboardStarboard",
		"FlapInboardPort", "FlapOutboardStarboard", "FlapOutboardPort", "AileronInboardStarboard", "AileronInboardPort",
		"AileronOutboardStarboard", "AileronOutboardPort", "SpoilersInboardStarboard", "SpoilersOutboardStarboard", "SpoilersInboardPort", "SpoilersOutboardPort",
		"TailplaneStarboard", "TailplanePort", "ElevatorStarboard", "ElevatorPort", "Engine1", "Engine2", "Engine3",
		"Engine4", "Fin", "Rudder", "NoseGear", "WingGearStarboard",
		"WingGearPort", "BodyGearStarboard", "BodyGearPort", "NoseDoorStarboard", "NoseDoorPort",
		"WingGearDoorStarboard", "WingGearDoorPort", "BodyGearDoorStarboard", "BodyGearDoorPort"],
	"legs": ["NoseGear", "WingGearStarboard", "WingGearPort", "BodyGearStarboard", "BodyGearPort"],
	"well_doors": ["NoseDoorStarboard", "NoseDoorPort", "WingGearDoorStarboard", "WingGearDoorPort",
		"BodyGearDoorStarboard", "BodyGearDoorPort"],
	"stowed_inside": ["NoseGear"],
	"engines": 4}

var _failures: PackedStringArray = []
var _tag: String = ""
## The suite's name in its lines: this one's, or the one that extends it.
var _suite: String = "airliners"


func _check(label: String, ok: bool, detail: String) -> void:
	print("[%s] %s %s %s (%s)" % [_suite, "PASS" if ok else "FAIL", _tag, label, detail])
	if not ok:
		_failures.append(_tag + " " + label)


func _ready() -> void:
	for plan in [B737, B747]:
		_common(plan).queue_free()
	_finish()


## THE CHECKS EVERY AIRFRAME ON THIS BUILDER OWES, for one plan; the airframe is handed back, still in the tree, for a
## suite's own checks after them.
func _common(plan: Dictionary) -> JetlinerAirframe:
	_tag = String(plan["class"])
	var frame: JetlinerAirframe = _build(plan)
	_probe(frame)
	_every_visible_mesh_is_a_named_part(frame, plan)
	_it_is_one_object_and_not_a_set_of_parts(frame)
	_the_drawn_aeroplane_is_the_published_size(frame, plan)
	_every_tyre_stands_on_the_ground(frame, plan)
	_the_wing_and_tail_have_the_measured_sweep(frame, plan)
	_both_pilots_sit_inside_the_drawn_skin_behind_glass(frame)
	_the_gear_doors_open_before_a_leg_moves_and_shut_after(frame, plan)
	_the_hinged_surfaces_move_the_right_way_and_come_back(frame, plan)
	_every_face_is_wound_outwards(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	return frame


func _build(plan: Dictionary) -> JetlinerAirframe:
	var frame: JetlinerAirframe = _make(plan)
	add_child(frame)
	frame.dress()
	return frame


## THE AIRFRAME A PLAN NAMES, not yet dressed: a suite that extends this one supplies its own.
func _make(plan: Dictionary) -> JetlinerAirframe:
	var frame: JetlinerAirframe
	match String(plan["class"]):
		"Boeing737":
			frame = Boeing737Airframe.new()
		"Boeing747":
			frame = Boeing747Airframe.new()
	return frame


## A PROBE BEFORE A PICTURE: every visible mesh's drawn box in the craft's frame, printed.
func _probe(frame: Node3D) -> void:
	for mesh in _meshes(frame):
		var box := _box_of(frame, [mesh])
		print("[airliners] probe %-22s x %6.2f..%6.2f  y %6.2f..%6.2f  z %6.2f..%6.2f" % [mesh.name, box.position.x,
			box.end.x, box.position.y, box.end.y, box.position.z, box.end.z])


func _every_visible_mesh_is_a_named_part(frame: Node3D, plan: Dictionary) -> void:
	var anonymous: PackedStringArray = []
	var names: Dictionary = {}
	for mesh in _meshes(frame):
		if String(mesh.name).begins_with("@"):
			anonymous.append(String(mesh.name))
		names[String(mesh.name)] = true
	var missing: PackedStringArray = []
	for part in plan["parts"]:
		if not names.has(part):
			missing.append(part)
	var extra: PackedStringArray = []
	for part in names:
		if not (plan["parts"] as Array).has(part):
			extra.append(part)
	_check("every_visible_mesh_is_a_named_part", anonymous.is_empty() and missing.is_empty() and extra.is_empty(),
		"%d meshes against %d named, anonymous %s, missing %s, unlisted %s" % [names.size(), (plan["parts"] as Array).size(),
			anonymous, missing, extra])


## ONE OBJECT: every drawn part reaches the fuselage (`DrawnParts.adrift`, the algorithm `joined_parts` uses), with the
## gear down, halfway and up, and the flaps and spoilers out: a surface that swings away from its wing is adrift.
func _it_is_one_object_and_not_a_set_of_parts(frame: JetlinerAirframe) -> void:
	var said: PackedStringArray = []
	for pose in [[1.0, 0.0], [0.5, 1.0], [0.0, 1.0]]:
		frame.set_gear(pose[0])
		frame.set_flaps(pose[1])
		frame.set_spoilers(pose[1])
		for s in DrawnParts.adrift(frame):
			said.append("%s %.2f m from %s at gear %.1f flaps %.1f" % [s["name"], s["gap"], s["nearest"], pose[0], pose[1]])
	frame.set_gear(1.0)
	frame.set_flaps(0.0)
	frame.set_spoilers(0.0)
	_check("it_is_one_object_and_not_a_set_of_parts", said.is_empty(),
		"%d parts, adrift: %s" % [DrawnParts.count(frame), ", ".join(said) if not said.is_empty() else "none"])


## THE ENVELOPE, from transformed vertices, against the published length, span and height (2 per cent), and the
## fuselage's width at its widest ring against the published width (1 per cent).
func _the_drawn_aeroplane_is_the_published_size(frame: JetlinerAirframe, plan: Dictionary) -> void:
	frame.set_gear(1.0)
	var box := _box_of(frame, _meshes(frame))
	var length: float = box.size.z
	var span: float = box.size.x
	var height: float = box.size.y
	var body := _box_of(frame, [frame.find_child("Fuselage", true, false)])
	var ok: bool = absf(length - float(plan["length"])) <= float(plan["length"]) * 0.02 \
		and absf(span - float(plan["span"])) <= float(plan["span"]) * 0.02 \
		and absf(height - float(plan["height"])) <= float(plan["height"]) * 0.02 \
		and absf(body.size.x - float(plan["width"])) <= float(plan["width"]) * 0.01
	_check("the_drawn_aeroplane_is_the_published_size", ok,
		"drawn %.3f m long (published %.2f, %+.2f%%), %.3f across (%.2f, %+.2f%%), %.3f tall over the tyres (%.2f, %+.2f%%); fuselage %.3f wide (%.2f)"
			% [length, plan["length"], 100.0 * (length / float(plan["length"]) - 1.0), span, plan["span"],
				100.0 * (span / float(plan["span"]) - 1.0), height, plan["height"],
				100.0 * (height / float(plan["height"]) - 1.0), body.size.x, plan["width"]])


## THE TYRES, gear down: every tyre's bottom on one ground, which is the lowest drawn point of the aeroplane and the box's
## bottom; and the wheelbase and each track between the tyres' middles against the printed ones (2 per cent).
func _every_tyre_stands_on_the_ground(frame: JetlinerAirframe, plan: Dictionary) -> void:
	frame.set_gear(1.0)
	var all := _box_of(frame, _meshes(frame))
	var bottoms: Array = []
	var centres: Dictionary = {}
	for leg in plan["legs"]:
		var tyres := _dark_box(frame, frame.find_child(leg, true, false) as MeshInstance3D)
		bottoms.append(snappedf(tyres.position.y, 0.0001))
		centres[leg] = tyres.get_center()
	var ground: float = frame.point(0.0, 0.0, 0.0).y
	var level: bool = absf(float(bottoms.max()) - float(bottoms.min())) < 0.005 \
		and absf(float(bottoms.min()) - all.position.y) < 0.005 and absf(float(bottoms.min()) - ground) < 0.005
	var said: PackedStringArray = []
	var ok: bool = level
	var base: Array = plan["wheelbase"]
	var mains: Array = base[1]
	var wheelbase: float = ((centres[mains[0]] as Vector3).z + (centres[mains[1]] as Vector3).z) * 0.5 \
		- (centres[base[0]] as Vector3).z
	ok = ok and absf(wheelbase - float(base[2])) <= float(base[2]) * 0.02
	said.append("wheelbase %.3f m (printed %.2f)" % [wheelbase, base[2]])
	for track in plan["tracks"]:
		var across: float = (centres[track[0]] as Vector3).x - (centres[track[1]] as Vector3).x
		ok = ok and absf(across - float(track[2])) <= float(track[2]) * 0.02
		said.append("track %.3f (%.2f)" % [across, track[2]])
	_check("every_tyre_stands_on_the_ground", ok,
		"tyre bottoms %s, the lowest drawn point %.3f, the ground %.3f; %s"
			% [bottoms, all.position.y, ground, ", ".join(said)])


## THE PLANFORM against the drawing's fits: the wing's and the tailplane's leading-edge sweep, read off the DRAWN vertices
## over the same span the fit took, so a builder that took the right constant and misused it fails.
func _the_wing_and_tail_have_the_measured_sweep(frame: Node3D, plan: Dictionary) -> void:
	var wing_band: Array = plan["wing_band"]
	var tail_band: Array = plan["tail_band"]
	var wing_edge := _leading_points(frame, "WingStarboard", float(wing_band[0]), float(wing_band[1]))
	var tail_edge := _leading_points(frame, "TailplaneStarboard", float(tail_band[0]), float(tail_band[1]))
	var wing: float = _slope(wing_edge, func(p: Vector3) -> float: return p.z)
	var tail: float = _slope(tail_edge, func(p: Vector3) -> float: return p.z)
	_check("the_wing_and_tail_have_the_measured_sweep",
		absf(wing - float(plan["wing_sweep"])) < 0.5 and absf(tail - float(plan["tail_sweep"])) < 0.7,
		"wing leading edge %.2f deg over %d bands (measured %.2f), tailplane %.2f over %d (%.2f)"
			% [wing, wing_edge.size(), plan["wing_sweep"], tail, tail_edge.size(), plan["tail_sweep"]])


## BOTH PILOTS ARE INSIDE THE AEROPLANE AND CAN SEE OUT. Every corner of `cabin_room()`'s box and both eyes are inside the
## drawn fuselage by ray parity, fired up and down only, both odd (`modelling_here.md` section 6); and from each eye, rays
## fired level ahead and 30 degrees to that pilot's side meet GLASS (the fuselage's second surface) before anything else.
func _both_pilots_sit_inside_the_drawn_skin_behind_glass(frame: JetlinerAirframe) -> void:
	var room: Dictionary = frame.cabin_room()
	var box: AABB = room["room"]
	var tris := _skin(frame)
	var outside: PackedStringArray = []
	var points: Array = [frame.eye(), frame.first_officer_eye(), box.get_center()]
	for i in range(8):
		var corner: Vector3 = box.get_endpoint(i)
		points.append(corner + (box.get_center() - corner).normalized() * 0.001)
	for p in points:
		if not _inside_of(tris, (p as Vector3) + Vector3(0.0007, 0.0, 0.0007)):
			outside.append("%s" % p)
	var seen: Dictionary = {}
	for pair in [[frame.eye(), -1.0], [frame.first_officer_eye(), 1.0]]:
		for turn in [0.0, 30.0]:
			var ahead: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, -float(pair[1]) * deg_to_rad(turn))
			var first: String = _first_hit(frame, (pair[0] as Vector3) + Vector3(0.0007, 0.0007, 0.0), ahead)
			seen[first] = int(seen.get(first, 0)) + 1
	var floor_ok: bool = float(room["floor"]) < frame.eye().y - 0.5 and float(room["floor"]) >= box.position.y - 0.001
	_check("both_pilots_sit_inside_the_drawn_skin_behind_glass",
		outside.is_empty() and floor_ok and box.size.x >= 1.2 and seen.keys() == ["Fuselage/1"],
		"room %.2f wide x %.2f tall x %.2f long, eyes %.2f m over the floor, %.2f apart; outside the skin: %s; four rays from the eyes met %s"
			% [box.size.x, box.size.y, box.size.z, frame.eye().y - float(room["floor"]),
				frame.first_officer_eye().x - frame.eye().x, "none" if outside.is_empty() else ", ".join(outside), seen])


## THE GEAR'S SEQUENCE: DOORS OPEN, THEN THE LEGS MOVE, THEN THE DOORS SHUT. Stepped through the whole cycle in 1 per cent
## steps, each well door and each leg read back from its drawn vertices against its own two ends: at no step may a leg be
## off both of its ends while any well door is short of fully open; with the gear down and up the well doors are shut; and
## the order is seen both ways, the doors moving FIRST from each end. And the gear up is inside the skin.
func _the_gear_doors_open_before_a_leg_moves_and_shut_after(frame: JetlinerAirframe, plan: Dictionary) -> void:
	var legs: Array = plan["legs"]
	var doors: Array = plan["well_doors"]
	frame.set_gear(1.0)
	var down: Dictionary = _poses(frame, legs + doors)
	frame.set_gear(0.0)
	var up: Dictionary = _poses(frame, legs + doors)
	frame.set_gear(0.5)
	var open: Dictionary = _poses(frame, doors)
	var faults: PackedStringArray = []
	var first_door: float = -1.0
	var first_leg: float = -1.0
	for step in range(101):
		var amount: float = float(step) / 100.0
		frame.set_gear(amount)
		var now: Dictionary = _poses(frame, legs + doors)
		var legs_moving: bool = false
		for leg in legs:
			if _off(now[leg], down[leg]) > 0.001 and _off(now[leg], up[leg]) > 0.001:
				legs_moving = true
		var doors_open: bool = true
		var doors_moved: bool = false
		for door in doors:
			doors_open = doors_open and _off(now[door], open[door]) < 0.001
			doors_moved = doors_moved or _off(now[door], up[door]) > 0.001
		if legs_moving and not doors_open:
			faults.append("%.2f" % amount)
		if doors_moved and first_door < 0.0:
			first_door = amount
		if legs_moving and first_leg < 0.0:
			first_leg = amount
	var shut_down := true
	for door in doors:
		shut_down = shut_down and _off(down[door], up[door]) < 0.001
	# THE LEGS THE PLAN NAMES ARE INSIDE THE SKIN WITH THE GEAR UP (the nose leg; the 737's mains are seen in its belly,
	# and a 747 main's stowed tyres stand in its fairing, which is not the fuselage); every leg has left the ground by
	# most of its length.
	frame.set_gear(0.0)
	var tris := _skin(frame)
	var nose_out: int = 0
	for leg in plan["stowed_inside"]:
		for p in _points(frame, frame.find_child(leg, true, false) as MeshInstance3D):
			if not _inside_of(tris, p + Vector3(0.0007, 0.0, 0.0007)):
				nose_out += 1
	var lowest_up: float = INF
	for leg in legs:
		lowest_up = minf(lowest_up, _box_of(frame, [frame.find_child(leg, true, false)]).position.y)
	var ground: float = frame.point(0.0, 0.0, 0.0).y
	frame.set_gear(1.0)
	_check("the_gear_doors_open_before_a_leg_moves_and_shut_after",
		faults.is_empty() and shut_down and first_door >= 0.0 and first_leg > first_door and nose_out == 0
			and lowest_up - ground > 0.8,
		"legs moving with a well door short of open at amounts %s; the well doors shut both down and up %s; from gear up the doors first move at %.2f and the legs at %.2f; stowed, %d nose-leg vertices outside the skin and the lowest leg %.2f m off the ground"
			% ["none" if faults.is_empty() else ", ".join(faults), shut_down, first_door, first_leg, nose_out,
				lowest_up - ground])


## THE STICK'S SURFACES AND THE LEVERS', ONE AT A TIME, read back from DRAWN vertices (the F-16 lane's lesson: two axes at
## once hide a swapped one): right roll raises the starboard aileron's trailing edge and lowers the port one's; nose-up
## raises both elevators'; right pedal swings the rudder's to starboard; the flaps lower both flaps' trailing edges; the
## spoilers raise theirs; and at zero every one is back where it was drawn.
func _the_hinged_surfaces_move_the_right_way_and_come_back(frame: JetlinerAirframe, plan: Dictionary) -> void:
	var r: Array = plan["roll"]
	var f: Array = plan["flaps"]
	# A C-130 HAS NO SPOILERS: its plan names none, and the check stands in the elevators for them.
	var sp: Array = plan["spoilers"] if not (plan["spoilers"] as Array).is_empty() else ["ElevatorStarboard", "ElevatorPort"]
	var spoiled: bool = not (plan["spoilers"] as Array).is_empty()
	var parts: Array = [r[0], r[1], "ElevatorStarboard", "ElevatorPort", "Rudder", f[0], f[1], sp[0], sp[1]]
	var rest: Dictionary = {}
	for part in parts:
		rest[part] = _trailing(frame, part)
	var moved := func() -> Dictionary:
		var d: Dictionary = {}
		for part in parts:
			d[part] = _trailing(frame, part) - (rest[part] as Vector3)
		return d
	frame.set_ailerons(1.0)
	var roll: Dictionary = moved.call()
	frame.set_ailerons(0.0)
	frame.set_elevators(1.0)
	var pitch: Dictionary = moved.call()
	frame.set_elevators(0.0)
	frame.set_rudder(1.0)
	var yaw: Dictionary = moved.call()
	frame.set_rudder(0.0)
	frame.set_flaps(1.0)
	var flaps: Dictionary = moved.call()
	frame.set_flaps(0.0)
	frame.set_spoilers(1.0)
	var spoilers: Dictionary = moved.call()
	frame.set_spoilers(0.0)
	var y := func(d: Dictionary, part: String) -> float: return (d[part] as Vector3).y
	var ok: bool = y.call(roll, r[0]) > 0.1 and y.call(roll, r[1]) < -0.1 \
		and absf(y.call(roll, "ElevatorStarboard")) < 0.001 \
		and y.call(pitch, "ElevatorStarboard") > 0.1 and y.call(pitch, "ElevatorPort") > 0.1 \
		and absf(y.call(pitch, r[0])) < 0.001 \
		and (yaw["Rudder"] as Vector3).x > 0.1 \
		and y.call(flaps, f[0]) < -0.3 and y.call(flaps, f[1]) < -0.3 \
		and absf(y.call(flaps, r[1])) < 0.001 \
		and (not spoiled or (y.call(spoilers, sp[0]) > 0.1 and y.call(spoilers, sp[1]) > 0.1))
	var back := true
	for part in parts:
		back = back and _trailing(frame, part).distance_to(rest[part]) < 0.001
	_check("the_hinged_surfaces_move_the_right_way_and_come_back", ok and back,
		"roll: ailerons %+.2f / %+.2f; pitch: elevators %+.2f / %+.2f; yaw: rudder %+.2f; flaps %+.2f / %+.2f; spoilers %+.2f / %+.2f; back at zero %s"
			% [y.call(roll, r[0]), y.call(roll, r[1]), y.call(pitch, "ElevatorStarboard"),
				y.call(pitch, "ElevatorPort"), (yaw["Rudder"] as Vector3).x, y.call(flaps, f[0]),
				y.call(flaps, f[1]), y.call(spoilers, sp[0]), y.call(spoilers, sp[1]),
				back])


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


## THE BUDGET for a first exterior LOD: at most 100,000 triangles and 12 materials, draw surfaces at most 60 as parts (the
## VAT pours them into one), and at least three fittings that stop drawing at range. The scope: the whole airframe subtree.
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
	_check("the_exterior_meets_the_first_lod_budget", triangles <= 100000 and draws <= 60 and culled >= 3
		and materials.size() <= 12,
		"the whole airframe subtree: %d triangles, %d draw surfaces, %d materials, %d distance-culled"
			% [triangles, draws, materials.size(), culled])


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


func _surface_points(frame: Node3D, mesh: MeshInstance3D, surface: int) -> PackedVector3Array:
	var into := frame.global_transform.affine_inverse() * mesh.global_transform
	var out := PackedVector3Array()
	for p in (mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
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


## A leg's tyres: its DARK vertices -- rubber, not the strut.
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


func _poses(frame: Node3D, parts: Array) -> Dictionary:
	var out: Dictionary = {}
	for part in parts:
		out[part] = _points(frame, frame.find_child(part, true, false) as MeshInstance3D)
	return out


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


## Every exterior triangle of the fuselage, whose second surface is the flight deck's glass, for the inside test.
func _skin(frame: Node3D) -> Array:
	var tris: Array = []
	var pts := _points(frame, frame.find_child("Fuselage", true, false) as MeshInstance3D)
	for i in range(0, pts.size() - 2, 3):
		tris.append([pts[i], pts[i + 1], pts[i + 2]])
	return tris


static func _inside_of(tris: Array, p: Vector3) -> bool:
	var up: int = 0
	var down: int = 0
	for t in tris:
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
		for surface in range(mesh.mesh.get_surface_count()):
			var pts := _surface_points(frame, mesh, surface)
			for i in range(0, pts.size() - 2, 3):
				var hit = Geometry3D.ray_intersects_triangle(from, direction, pts[i], pts[i + 1], pts[i + 2])
				if hit != null and ((hit as Vector3) - from).length() < best:
					best = ((hit as Vector3) - from).length()
					name_of = "%s/%d" % [mesh.name, surface]
	return name_of


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
