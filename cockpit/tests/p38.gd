extends Node
## Headless contract for the P-38L airframe: its measured envelope against the printed one, the features that make it a
## Lightning -- two booms 96 in either side of a gondola, their fins, the tailplane between them, the wing's dihedral from
## the joint, the nose guns -- one object, and the things that MOVE: the tricycle gear folding aft into the gondola and the
## booms behind doors that stay open while it is down, every surface, and the two propellers turning OPPOSITE ways,
## outboard at the top. Each read back from DRAWN VERTICES, never from a node's transform. Read RESULT=.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, TYPED: every MEASURED figure is printed from AN 01-75FF-2's three-view alone by
## `craft/p38/measure_views.py`; the PRINTED ones are on the sheet.
const PRINTED_LENGTH := 11.530     # 37 ft 9-15/16 in
const PRINTED_SPAN := 15.850       # 52 ft 0 in
const PRINTED_BOOM_OUT := 2.438    # 96 in
const PRINTED_TRACK := 5.029       # 198 in
const PRINTED_TAILPLANE := 6.629   # 261 in
const PRINTED_PROP := 3.505        # 11 ft 6 in
const PRINTED_HEIGHT := 3.007      # 9 ft 10-3/8 in, the fin's top over the static ground
const PRINTED_ARC_HEIGHT := 3.912  # 12 ft 10 in, the propeller arc's top over the static ground (the user, 2026-09-19)
const PRINTED_GROUND_ANGLE := 5.563  # 5 deg 33 min 46 s, the static ground against the reference line
const PRINTED_DIHEDRAL := 5.667    # 5 deg 40 min, the outer panels
const WING_JOINT := 2.921          # 115 in out
const EDGES: Array = [[1.00, 3.003, 5.639], [4.00, 3.258, 5.134], [6.00, 3.434, 4.805], [7.50, 3.577, 4.422]]
const AILERON_TRAVEL := 15.0
const ELEVATOR_UP := 28.0
const ELEVATOR_DOWN := 20.0
const FLAP_TRAVEL := 45.0

const PARTS: Array = ["Gondola", "Guns", "Wells", "BoomStarboard", "BoomPort", "TurboStarboard", "TurboPort",
	"SpinnerStarboard", "SpinnerPort", "PropellerStarboard", "PropellerPort", "WingStarboard", "WingPort",
	"AileronStarboard", "AileronPort", "FlapInnerStarboard", "FlapInnerPort", "FlapOuterStarboard", "FlapOuterPort",
	"FinStarboard", "FinPort", "RudderStarboard", "RudderPort", "Tailplane", "Elevator", "MainGearStarboard",
	"MainGearPort", "MainDoorOuterStarboard", "MainDoorInnerStarboard", "MainDoorOuterPort", "MainDoorInnerPort",
	"NoseGear", "NoseDoorStarboard", "NoseDoorPort"]
const LEGS: Array = ["MainGearStarboard", "MainGearPort", "NoseGear"]
const DOORS: Array = ["MainDoorOuterStarboard", "MainDoorInnerStarboard", "MainDoorOuterPort", "MainDoorInnerPort",
	"NoseDoorStarboard", "NoseDoorPort"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[p38] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var frame := P38Airframe.new()
	add_child(frame)
	frame.dress()
	_probe(frame)
	_every_visible_mesh_is_a_named_part(frame)
	_it_is_one_object_and_not_a_set_of_parts(frame)
	_the_drawn_aeroplane_is_the_printed_length_and_span(frame)
	_the_tyres_stand_on_the_static_ground(frame)
	_it_stands_the_printed_height_on_the_static_ground(frame)
	_it_parks_on_all_three_tyres(frame)
	_the_propeller_arc_stands_12_ft_10_in_over_the_static_ground(frame)
	_two_booms_96_in_either_side_and_the_tail_between(frame)
	_the_wing_has_its_edges_and_its_dihedral_from_the_joint(frame)
	_the_propellers_turn_opposite_ways_outboard_at_the_top(frame)
	_the_doors_open_as_the_gear_comes_down_and_shut_when_it_is_up(frame)
	_no_leg_ever_passes_through_a_door(frame)
	_the_gear_folds_aft_inside_the_booms_and_the_gondola(frame)
	_the_hinged_surfaces_move_the_right_way_and_come_back(frame)
	_every_face_is_wound_outwards(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	await _the_vat_draws_the_moving_parts_where_the_parts_are(frame)
	frame.queue_free()
	_finish()


func _probe(frame: Node3D) -> void:
	for mesh in _meshes(frame):
		var box := _box_of(frame, [mesh])
		print("[p38] probe %-24s x %6.2f..%6.2f  y %6.2f..%6.2f  z %6.2f..%6.2f" % [mesh.name, box.position.x,
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
	_check("every_visible_mesh_is_a_named_part", anonymous.is_empty() and missing.is_empty() and names.size() == PARTS.size(),
		"%d meshes against %d named, anonymous %s, missing %s" % [names.size(), PARTS.size(), anonymous, missing])


func _it_is_one_object_and_not_a_set_of_parts(frame: P38Airframe) -> void:
	var said: PackedStringArray = []
	for pose in [[1.0, 0.0], [0.5, 1.0], [0.0, 1.0], [0.0, -1.0]]:
		frame.set_gear(pose[0])
		frame.set_ailerons(pose[1])
		frame.set_elevators(pose[1])
		frame.set_rudders(pose[1])
		frame.set_flaps(absf(pose[1]))
		for s in DrawnParts.adrift(frame):
			said.append("%s %.2f m from %s at gear %.1f surfaces %.1f" % [s["name"], s["gap"], s["nearest"], pose[0], pose[1]])
	_rest(frame)
	_check("it_is_one_object_and_not_a_set_of_parts", said.is_empty(),
		"%d parts, adrift: %s" % [DrawnParts.count(frame), ", ".join(said) if not said.is_empty() else "none"])


## THE ENVELOPE along the reference line: the gondola's nose to the rudders' trailing edges, and tip to tip (1 per cent
## of the printed length, 0.3 of the printed span).
func _the_drawn_aeroplane_is_the_printed_length_and_span(frame: P38Airframe) -> void:
	var box := _box_of(frame, _meshes(frame))
	_check("the_drawn_aeroplane_is_the_printed_length_and_span",
		absf(box.size.z - PRINTED_LENGTH) <= PRINTED_LENGTH * 0.01 and absf(box.size.x - PRINTED_SPAN) <= PRINTED_SPAN * 0.003,
		"drawn %.3f m long and %.3f m across; printed %.3f and %.3f" % [box.size.z, box.size.x, PRINTED_LENGTH, PRINTED_SPAN])


## THE TYRES, gear down: the main tyres' bottoms on the box's floor, the printed track apart; and the line under the nose
## tyre's and the main tyres' bottoms raked against the reference line at the printed static ground angle (a degree).
func _the_tyres_stand_on_the_static_ground(frame: P38Airframe) -> void:
	frame.set_gear(1.0)
	var s: AABB = _dark_box(frame, frame.find_child("MainGearStarboard", true, false) as MeshInstance3D)
	var p: AABB = _dark_box(frame, frame.find_child("MainGearPort", true, false) as MeshInstance3D)
	var n: AABB = _dark_box(frame, frame.find_child("NoseGear", true, false) as MeshInstance3D)
	var floor_y: float = -(frame.geometry()["extents"] as Vector3).y
	var track: float = s.get_center().x - p.get_center().x
	var rake: float = rad_to_deg(atan2(s.position.y - n.position.y, s.get_center().z - n.get_center().z))
	_check("the_tyres_stand_on_the_static_ground",
		absf(s.position.y - floor_y) < 0.005 and absf(p.position.y - floor_y) < 0.005 and absf(track - PRINTED_TRACK) < 0.01
			and absf(rake - PRINTED_GROUND_ANGLE) < 1.0,
		"main tyre bottoms %.3f and %.3f on the floor %.3f; track %.3f (printed %.3f); the static ground raked %.2f deg (printed %.2f)"
			% [s.position.y, p.position.y, floor_y, track, PRINTED_TRACK, rake, PRINTED_GROUND_ANGLE])


## THE PRINTED HEIGHT: the fins' top over the static ground, square to it (1.5 per cent). A THIRD QUANTITY: the side view
## was scaled by its length, and its heights read at that scale.
func _it_stands_the_printed_height_on_the_static_ground(frame: P38Airframe) -> void:
	frame.set_gear(1.0)
	var s: AABB = _dark_box(frame, frame.find_child("MainGearStarboard", true, false) as MeshInstance3D)
	var n: AABB = _dark_box(frame, frame.find_child("NoseGear", true, false) as MeshInstance3D)
	var a := Vector2(n.get_center().z, n.position.y)
	var b := Vector2(s.get_center().z, s.position.y)
	var rake: float = atan2(b.y - a.y, b.x - a.x)
	var highest: float = -INF
	for p in _points(frame, frame.find_child("FinStarboard", true, false) as MeshInstance3D):
		var rel := Vector2(p.z - a.x, p.y - a.y)
		highest = maxf(highest, rel.y * cos(rake) - rel.x * sin(rake))
	_check("it_stands_the_printed_height_on_the_static_ground", absf(highest - PRINTED_HEIGHT) <= PRINTED_HEIGHT * 0.015,
		"the fin's top %.3f m over the static ground (printed %.3f)" % [highest, PRINTED_HEIGHT])


## PARKED ON ALL THREE TYRES (the user, 2026-09-19: "the front wheel on the p-38 doesn't seem to be colliding with the floor
## correctly"): every tyre's lowest drawn vertex, gear down, taken through `parked()`, within 2.5 cm over the floor, and no
## drawn point of the whole aeroplane under it. THE MUTANT is the frame as built, level, which the airframe parked in
## until then: its nose tyre stands 0.26 m through the floor, and the check must fail on it.
func _it_parks_on_all_three_tyres(frame: P38Airframe) -> void:
	frame.set_gear(1.0)
	frame.set_props(0.0)
	var floor_y: float = -(frame.geometry()["extents"] as Vector3).y
	var parked: Dictionary = _stance(frame, frame.parked(), floor_y)
	var level: Dictionary = _stance(frame, Transform3D.IDENTITY, floor_y)
	var rake: float = rad_to_deg(-asin((frame.parked().basis * Vector3.BACK).y))
	_check("it_parks_on_all_three_tyres", bool(parked["ok"]) and absf(rake - PRINTED_GROUND_ANGLE) < 1.0,
		"tyres' lowest over the floor: %s; the lowest drawn point %+.3f; nose up %.2f deg (printed %.2f)"
			% [parked["said"], parked["lowest"], rake, PRINTED_GROUND_ANGLE])
	_check("the_parked_check_fails_standing_level_as_built", not bool(level["ok"]),
		"mutant, as built: %s; the lowest drawn point %+.3f" % [level["said"], level["lowest"]])


func _stance(frame: P38Airframe, stance: Transform3D, floor_y: float) -> Dictionary:
	var said: PackedStringArray = []
	var ok: bool = true
	for leg in LEGS:
		var mesh := frame.find_child(leg, true, false) as MeshInstance3D
		var colours: PackedColorArray = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var pts := _points(frame, mesh)
		var low: float = INF
		for i in range(pts.size()):
			if colours[i].v < 0.1:
				low = minf(low, (stance * pts[i]).y)
		ok = ok and low - floor_y > -0.002 and low - floor_y < 0.025
		said.append("%s %+.3f" % [leg, low - floor_y])
	var lowest: float = INF
	for mesh in _meshes(frame):
		for p in _points(frame, mesh):
			lowest = minf(lowest, (stance * p).y)
	ok = ok and lowest >= floor_y - 0.002
	return {"ok": ok, "said": "; ".join(said), "lowest": lowest - floor_y}


## THE PROPELLER ARC'S TOP over the static ground, square to it, as the user gave it (2026-09-19): "9 feet 10 inches from
## the ground to the tail fin, and 12 feet 10 inches from the ground to the tip of the propeller arc". Every drawn blade
## vertex of both propellers, turned through a whole revolution a degree at a time, so it is the drawn tip's arc and not
## the printed diameter. A THIRD QUANTITY again: neither the fin's height nor the 11 ft 6 in disc is this figure.
## HELD TO 4 PER CENT, NOT 1.5, AND WHY: the sheet's own printed 11 ft 6 in propeller on its own printed gear puts the
## hub 2.025 m over the static ground and the arc's top 3.77 m (12 ft 4-1/2 in), 3.5 per cent under the user's figure.
## To stand 3.91 the hub would have to be 14 cm higher than the sheet's printed tyres, 36 in and 27 in, allow. Both
## figures are in `craft/p38/sources.md`; the check reads "about 12 ft 10 in", which is what was asked.
func _the_propeller_arc_stands_12_ft_10_in_over_the_static_ground(frame: P38Airframe) -> void:
	frame.set_gear(1.0)
	var s: AABB = _dark_box(frame, frame.find_child("MainGearStarboard", true, false) as MeshInstance3D)
	var n: AABB = _dark_box(frame, frame.find_child("NoseGear", true, false) as MeshInstance3D)
	var a := Vector2(n.get_center().z, n.position.y)
	var b := Vector2(s.get_center().z, s.position.y)
	var rake: float = atan2(b.y - a.y, b.x - a.x)
	var highest: float = -INF
	for step in range(360):
		frame.set_props(float(step) / 360.0)
		for named in ["PropellerStarboard", "PropellerPort"]:
			for p in _points(frame, frame.find_child(named, true, false) as MeshInstance3D):
				var rel := Vector2(p.z - a.x, p.y - a.y)
				highest = maxf(highest, rel.y * cos(rake) - rel.x * sin(rake))
	frame.set_props(0.0)
	_check("the_propeller_arc_stands_12_ft_10_in_over_the_static_ground",
		absf(highest - PRINTED_ARC_HEIGHT) <= PRINTED_ARC_HEIGHT * 0.04,
		"the arc's top %.3f m over the static ground (the user's 12 ft 10 in, %.3f)" % [highest, PRINTED_ARC_HEIGHT])


## THE LIGHTNING'S OWN LAYOUT: each boom's drawn middle 96 in from the gondola's to 5 mm (the drawing's booms stand 1.7 cm
## in, and at 2 cm a model built to them passed), each with its fin and rudder on it; the gondola ending ahead of the tailplane; the tailplane the printed 261 in across, between the booms' ends.
func _two_booms_96_in_either_side_and_the_tail_between(frame: P38Airframe) -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	for side in ["Starboard", "Port"]:
		var boom := _box_of(frame, [frame.find_child("Boom" + side, true, false)])
		var fin := _box_of(frame, [frame.find_child("Fin" + side, true, false)])
		var middle: float = (boom.position.x + boom.end.x) * 0.5
		ok = ok and absf(absf(middle) - PRINTED_BOOM_OUT) < 0.005 and absf((fin.position.x + fin.end.x) * 0.5 - middle) < 0.02
		said.append("%s boom's middle %+.3f, its fin's %+.3f" % [side, middle, (fin.position.x + fin.end.x) * 0.5])
	var gondola := _box_of(frame, [frame.find_child("Gondola", true, false)])
	var tail := _box_of(frame, [frame.find_child("Tailplane", true, false)])
	ok = ok and gondola.end.z < tail.position.z and absf(tail.size.x - PRINTED_TAILPLANE) < PRINTED_TAILPLANE * 0.01
	_check("two_booms_96_in_either_side_and_the_tail_between", ok,
		"%s; the gondola ends %.2f m ahead of the tailplane; tailplane %.3f m (printed %.3f)"
			% ["; ".join(said), tail.position.z - gondola.end.z, tail.size.x, PRINTED_TAILPLANE])


## THE WING: its drawn edges at four stations of span against the plan's (both wings averaged, read square), 2 cm; FLAT
## to the joint at 115 in and then rising at the printed 5 deg 40 min.
func _the_wing_has_its_edges_and_its_dihedral_from_the_joint(frame: P38Airframe) -> void:
	var nose: float = frame.point(0.0, 0.0, 0.0).z
	var front: Dictionary = {}
	var back: Dictionary = {}
	var mids: Dictionary = {}
	for p in _points(frame, frame.find_child("WingStarboard", true, false) as MeshInstance3D):
		var band: int = int(round(p.x / 0.005))
		front[band] = minf(float(front.get(band, INF)), p.z)
		# THE FIXED WING'S TRAILING EDGE only where nothing is hinged behind it; the surfaces' own edges elsewhere.
		if P38Airframe.hinge_at(p.x) == P38Airframe.wing_te(p.x):
			back[band] = maxf(float(back.get(band, -INF)), p.z)
		var m: Array = mids.get(band, [INF, -INF])
		mids[band] = [minf(m[0], p.y), maxf(m[1], p.y)]
	for part in ["AileronStarboard", "FlapInnerStarboard", "FlapOuterStarboard"]:
		for p in _points(frame, frame.find_child(part, true, false) as MeshInstance3D):
			var band: int = int(round(p.x / 0.005))
			back[band] = maxf(float(back.get(band, -INF)), p.z)
	var worst: float = 0.0
	var said: PackedStringArray = []
	for row in EDGES:
		var le: float = _edge(front, float(row[0])) - nose
		var te: float = _edge(back, float(row[0])) - nose
		worst = maxf(worst, maxf(absf(le - float(row[1])), absf(te - float(row[2]))))
		said.append("%.1f out: %.3f-%.3f (%.3f-%.3f)" % [row[0], le, te, row[1], row[2]])
	var inner: Array = []
	var outer: Array = []
	for band in mids:
		var x: float = float(band) * 0.005
		var v := Vector3(x, (float(mids[band][0]) + float(mids[band][1])) * 0.5, 0.0)
		if x > 0.9 and x < WING_JOINT - 0.05:
			inner.append(v)
		elif x > WING_JOINT + 0.1 and x < 7.3:
			outer.append(v)
	var flat: float = _slope(inner, func(p: Vector3) -> float: return p.y)
	var dihedral: float = _slope(outer, func(p: Vector3) -> float: return p.y)
	_check("the_wing_has_its_edges_and_its_dihedral_from_the_joint",
		worst < 0.02 and absf(flat) < 0.3 and absf(dihedral - PRINTED_DIHEDRAL) < 0.3,
		"edges %s, worst %.3f m; centre section %.2f deg; outer panels %.2f deg (printed %.2f)"
			% [", ".join(said), worst, flat, dihedral, PRINTED_DIHEDRAL])


## THE PROPELLERS TURN OPPOSITE WAYS, OUTBOARD AT THE TOP [TM]: over a third of a blade's pitch the starboard's topmost
## tip moves to starboard and the port's to port; both the printed 11 ft 6 in across; three blades each.
func _the_propellers_turn_opposite_ways_outboard_at_the_top(frame: P38Airframe) -> void:
	var said: PackedStringArray = []
	var ok: bool = true
	for side in ["Starboard", "Port"]:
		frame.set_props(0.0)
		var mesh := frame.find_child("Propeller" + side, true, false) as MeshInstance3D
		var before := _points(frame, mesh)
		var hub := Vector3.ZERO
		for p in before:
			hub += p
		hub /= float(before.size())
		var top: int = 0
		var reach: float = 0.0
		for i in range(before.size()):
			if before[i].y > before[top].y:
				top = i
			reach = maxf(reach, Vector2(before[i].x - hub.x, before[i].y - hub.y).length())
		frame.set_props(0.25)
		var moved: float = _points(frame, mesh)[top].x - before[top].x
		var outboard: bool = moved * signf(hub.x) > 0.1
		ok = ok and outboard and absf(reach * 2.0 - PRINTED_PROP) < PRINTED_PROP * 0.01
		said.append("%s: %.3f m across, its top tip moved %+.2f m (outboard %s)" % [side, reach * 2.0, moved, outboard])
	frame.set_props(0.0)
	_check("the_propellers_turn_opposite_ways_outboard_at_the_top", ok, "; ".join(said))


## THE DOORS: every one shut with the gear up and open with it down, and every leg still until its doors are open (they
## open over the cycle's first fifth).
func _the_doors_open_as_the_gear_comes_down_and_shut_when_it_is_up(frame: P38Airframe) -> void:
	frame.set_gear(1.0)
	var down := _poses(frame, LEGS + DOORS)
	frame.set_gear(0.0)
	var up := _poses(frame, LEGS + DOORS)
	var ok: bool = true
	var bad: PackedStringArray = []
	for door in DOORS:
		ok = ok and _off(down[door], up[door]) > 0.1
	frame.set_gear(0.2)
	var open := _poses(frame, DOORS)
	for step in range(0, 101):
		frame.set_gear(float(step) / 100.0)
		var now := _poses(frame, LEGS + DOORS)
		for leg in LEGS:
			if _off(now[leg], up[leg]) > 0.002:
				for door in DOORS:
					if _off(now[door], open[door]) > 0.002:
						bad.append("%d%% %s" % [step, door])
	_rest(frame)
	_check("the_doors_open_as_the_gear_comes_down_and_shut_when_it_is_up", ok and bad.is_empty(),
		"doors move between up and down %s; %d steps with a leg off its stow before its doors are open %s"
			% [ok, bad.size(), bad.slice(0, 4)])


func _no_leg_ever_passes_through_a_door(frame: P38Airframe) -> void:
	var crossings: PackedStringArray = []
	for step in range(0, 101, 2):
		frame.set_gear(float(step) / 100.0)
		for door in DOORS:
			var dp := _points(frame, frame.find_child(door, true, false) as MeshInstance3D)
			for leg in LEGS:
				var lp := _points(frame, frame.find_child(leg, true, false) as MeshInstance3D)
				var hit: bool = false
				for i in range(0, lp.size() - 2, 3):
					if hit:
						break
					for e in [[lp[i], lp[i + 1]], [lp[i + 1], lp[i + 2]], [lp[i + 2], lp[i]]]:
						if hit:
							break
						for j in range(0, dp.size() - 2, 3):
							if Geometry3D.segment_intersects_triangle(e[0], e[1], dp[j], dp[j + 1], dp[j + 2]) != null:
								hit = true
								break
				if hit:
					crossings.append("%s through %s at %d%%" % [leg, door, step])
	_rest(frame)
	_check("no_leg_ever_passes_through_a_door", crossings.is_empty(), "%d crossings %s" % [crossings.size(), crossings.slice(0, 6)])


## THE GEAR UP, THE LIGHTNING'S WAY: each main tyre AFT of where it stood and every vertex of it inside its boom by ray
## parity; the nose tyre aft and inside the gondola.
func _the_gear_folds_aft_inside_the_booms_and_the_gondola(frame: P38Airframe) -> void:
	frame.set_gear(1.0)
	var down: Dictionary = {}
	for leg in LEGS:
		down[leg] = _dark_box(frame, frame.find_child(leg, true, false) as MeshInstance3D)
	frame.set_gear(0.0)
	var said: PackedStringArray = []
	var ok: bool = true
	for pair in [["MainGearStarboard", "BoomStarboard"], ["MainGearPort", "BoomPort"], ["NoseGear", "Gondola"]]:
		var up: AABB = _dark_box(frame, frame.find_child(pair[0], true, false) as MeshInstance3D)
		var skin := _solid(frame, pair[1])
		var mesh := frame.find_child(pair[0], true, false) as MeshInstance3D
		var colours: PackedColorArray = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var pts := _points(frame, mesh)
		var outside: int = 0
		for i in range(pts.size()):
			if colours[i].v < 0.1 and not _inside_of(skin, pts[i]):
				outside += 1
		var aft: bool = up.get_center().z > (down[pair[0]] as AABB).get_center().z + 0.5
		ok = ok and aft and outside == 0
		said.append("%s %.2f m aft, %d tyre vertices outside %s" % [pair[0], up.get_center().z - (down[pair[0]] as AABB).get_center().z,
			outside, pair[1]])
	_rest(frame)
	_check("the_gear_folds_aft_inside_the_booms_and_the_gondola", ok, "; ".join(said))


## THE SURFACES, ONE AXIS AT A TIME, their TRUE turns off three drawn vertices each: right roll raises the right aileron
## and lowers the left; nose-up raises the elevator, nose-down lowers it; right pedal swings both rudders' trailing edges
## to starboard; the flaps go down; at zero every one is back.
func _the_hinged_surfaces_move_the_right_way_and_come_back(frame: P38Airframe) -> void:
	_rest(frame)
	var parts: Array = ["AileronStarboard", "AileronPort", "Elevator", "RudderStarboard", "RudderPort", "FlapInnerStarboard",
		"FlapOuterPort"]
	var rest := _poses(frame, parts)
	var said: PackedStringArray = []
	var ok: bool = true
	frame.set_ailerons(1.0)
	var right: float = _turned(frame, "AileronStarboard", rest)
	var left: float = _turned(frame, "AileronPort", rest)
	ok = ok and absf(right - AILERON_TRAVEL) < 0.5 and absf(left + AILERON_TRAVEL) < 0.5
	said.append("roll right: right aileron %+.1f, left %+.1f" % [right, left])
	_rest(frame)
	frame.set_elevators(1.0)
	var up_e: float = _turned(frame, "Elevator", rest)
	frame.set_elevators(-1.0)
	var down_e: float = _turned(frame, "Elevator", rest)
	ok = ok and absf(up_e - ELEVATOR_UP) < 0.5 and absf(down_e + ELEVATOR_DOWN) < 0.5
	said.append("elevator %+.1f up, %+.1f down" % [up_e, down_e])
	_rest(frame)
	frame.set_rudders(1.0)
	for rudder in ["RudderStarboard", "RudderPort"]:
		var moved: float = _trailing(frame, rudder).x - _trailing_of(rest[rudder]).x
		ok = ok and moved > 0.15
		said.append("%s trailing edge %+.2f m to starboard" % [rudder, moved])
	_rest(frame)
	frame.set_flaps(1.0)
	for flap in ["FlapInnerStarboard", "FlapOuterPort"]:
		var turn: float = _turned(frame, flap, rest)
		ok = ok and absf(turn + FLAP_TRAVEL) < 0.5
		said.append("%s %+.1f" % [flap, turn])
	_rest(frame)
	var back: float = 0.0
	var now := _poses(frame, parts)
	for part in parts:
		back = maxf(back, _off(now[part], rest[part]))
	ok = ok and back < 1e-4
	said.append("all back within %.6f m" % back)
	_check("the_hinged_surfaces_move_the_right_way_and_come_back", ok, "; ".join(said))


## THE MOVING PARTS AS A VERTEX ANIMATION TEXTURE, held to the parts it was baked from TO A MILLIMETRE, off the grid.
func _the_vat_draws_the_moving_parts_where_the_parts_are(parts: P38Airframe) -> void:
	var cast := P38Airframe.new()
	add_child(cast)
	cast.dress()
	var before: int = DrawnParts.count(cast)
	var vat: VatCasting = await VatCasting.pour(cast, cast.features())
	var after: int = DrawnParts.count(cast)
	var worst: float = 0.0
	var worst_at: String = ""
	var names: Array = []
	for f in vat.features:
		names.append("%s/%d" % [f["name"], f["rows"]])
	for a in [0.137, 0.613, 0.853]:
		var amounts: Dictionary = {"gear": a, "pitch": 1.7 * a - 0.9, "roll": 0.9 - 1.9 * a, "rudder": a - 0.41,
			"flaps": 1.0 - a, "props": a * 0.77}
		parts.set_gear(amounts["gear"])
		parts.set_elevators(amounts["pitch"])
		parts.set_ailerons(amounts["roll"])
		parts.set_rudders(amounts["rudder"])
		parts.set_flaps(amounts["flaps"])
		parts.set_props(amounts["props"])
		var wanted: Array = []
		for f in vat.features:
			wanted.append(amounts[String(f["name"])])
		for part in ["MainGearStarboard", "NoseGear", "MainDoorOuterPort", "NoseDoorStarboard", "AileronPort", "Elevator",
				"RudderPort", "FlapOuterStarboard", "PropellerStarboard", "PropellerPort"]:
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
					worst_at = "%s at %.3f" % [part, a]
	_rest(parts)
	_check("the_vat_draws_the_moving_parts_where_the_parts_are", worst < 0.001 and after == before,
		"features %s; worst vertex %.5f m off its part (%s); drawn parts %d before the pour and %d after"
			% [names, worst, worst_at, before, after])
	cast.queue_free()


func _rest(frame: P38Airframe) -> void:
	frame.set_gear(1.0)
	frame.set_ailerons(0.0)
	frame.set_elevators(0.0)
	frame.set_rudders(0.0)
	frame.set_flaps(0.0)
	frame.set_props(0.0)


## A DRAWN EDGE between its bands: {band of 5 mm: station}, read at `x` by a straight line between the bands either side.
static func _edge(bands: Dictionary, x: float) -> float:
	var below: int = -1
	var above: int = -1
	for band in bands:
		if float(band) * 0.005 <= x + 1e-6 and (below < 0 or band > below):
			below = band
		if float(band) * 0.005 >= x - 1e-6 and (above < 0 or band < above):
			above = band
	if below < 0:
		return float(bands[above])
	if above < 0 or above == below:
		return float(bands[below])
	return lerpf(float(bands[below]), float(bands[above]), (x - float(below) * 0.005) / (float(above - below) * 0.005))


## HOW FAR A PART HAS TURNED, degrees, positive trailing edge UP, from its DRAWN vertices alone: the rigid turn that
## carries three of them -- the aftmost, the one furthest from it, and the one furthest from the line through those two --
## from where they were to where they are, its angle from the trace of the turn and its sign from which way the aftmost
## vertex moved. A chord read in the fore-and-aft plane reads a swept hinge's turn short by the sweep's cosine (the P-47's
## aileron's 15 degrees read 14.3, lane/warbirds); this reads the turn itself.
func _turned(frame: Node3D, part: String, rest: Dictionary) -> float:
	var then: PackedVector3Array = rest[part]
	var now := _points(frame, frame.find_child(part, true, false) as MeshInstance3D)
	var i0: int = 0
	for i in range(then.size()):
		if then[i].z > then[i0].z:
			i0 = i
	var i1: int = i0
	for i in range(then.size()):
		if then[i].distance_to(then[i0]) > then[i1].distance_to(then[i0]):
			i1 = i
	var line: Vector3 = (then[i1] - then[i0]).normalized()
	var i2: int = i0
	var best: float = 0.0
	for i in range(then.size()):
		var off: Vector3 = then[i] - then[i0]
		var d: float = (off - line * off.dot(line)).length()
		if d > best:
			best = d
			i2 = i
	var frame_of := func(p: PackedVector3Array) -> Basis:
		var x: Vector3 = (p[i1] - p[i0]).normalized()
		var y: Vector3 = (p[i2] - p[i0])
		y = (y - x * y.dot(x)).normalized()
		return Basis(x, y, x.cross(y))
	var turn: Basis = (frame_of.call(now) as Basis) * (frame_of.call(then) as Basis).transposed()
	var angle: float = rad_to_deg(acos(clampf((turn.x.x + turn.y.y + turn.z.z - 1.0) * 0.5, -1.0, 1.0)))
	return angle if now[i0].y >= then[i0].y else -angle


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
		"the whole P38Airframe subtree: %d triangles, %d draw surfaces, %d materials, %d distance-culled"
			% [triangles, draws, materials.size(), culled])


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


## A leg's tyre: its DARK vertices -- rubber, not the strut or the hub.
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


## The drawn trailing edge of a part: the average of every point within a centimetre of its aftmost.
func _trailing(frame: Node3D, part: String) -> Vector3:
	return _trailing_of(_points(frame, frame.find_child(part, true, false) as MeshInstance3D))


static func _trailing_of(pts: PackedVector3Array) -> Vector3:
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


## A PART'S TRIANGLES for the inside test.
func _solid(frame: Node3D, part: String) -> Array:
	var tris: Array = []
	var pts := _points(frame, frame.find_child(part, true, false) as MeshInstance3D)
	for i in range(0, pts.size() - 2, 3):
		tris.append([pts[i], pts[i + 1], pts[i + 2]])
	return tris


## Every exterior triangle a ray can meet for the inside test: the fuselage, whose second surface is the canopy.
func _skin(frame: Node3D) -> Array:
	var tris: Array = []
	var pts := _points(frame, frame.find_child("Gondola", true, false) as MeshInstance3D)
	for i in range(0, pts.size() - 2, 3):
		tris.append([pts[i], pts[i + 1], pts[i + 2]])
	return tris


static func _inside_of(tris: Array, p: Vector3) -> bool:
	var up: int = 0
	var down: int = 0
	# Nudged off the centreline: a ray exactly along it passes through the vertices every ring has there
	# (`modelling_here.md` section 6).
	var q: Vector3 = p + Vector3(0.0007, 0.0, 0.0007)
	for t in tris:
		if Geometry3D.ray_intersects_triangle(q, Vector3.UP, t[0], t[1], t[2]) != null:
			up += 1
		if Geometry3D.ray_intersects_triangle(q, Vector3.DOWN, t[0], t[1], t[2]) != null:
			down += 1
	return up % 2 == 1 and down % 2 == 1


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
