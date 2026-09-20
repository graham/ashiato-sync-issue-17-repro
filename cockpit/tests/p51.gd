extends Node
## Headless contract for the P-51D airframe: its measured envelope against the published and the printed one, the features
## that make it a Mustang, one object, and the things that MOVE -- the gear's inner doors opening before a leg moves and
## shutting after, the mains folding INWARD into the wing's root and the tail wheel forward into the fuselage, every
## surface on the stick, the pedals and the flap lever, and the propeller turning clockwise seen from behind -- each read
## back from DRAWN VERTICES, never from a node's transform. Read RESULT=.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, TYPED, so the reference is visible in one place and no check asks the builder's
## own constant what the builder did. Every MEASURED figure is printed from AN 01-60-3's three-view alone by
## `craft/p51/measure_views.py`; the published ones are Wikipedia's for the P-51D; the PRINTED ones are on the sheet.
const PUBLISHED_LENGTH := 9.83
const PUBLISHED_SPAN := 11.28
const PUBLISHED_HEIGHT := 4.08     # 13 ft 4-1/2 in, tail down, a blade vertical
const PRINTED_LENGTH := 9.838      # 32 ft 3-5/16 in, spinner to rudder
const PRINTED_SPAN := 11.286       # 37 ft 0-5/16 in
const PRINTED_TRACK := 3.607       # 142 in
const PRINTED_PROP := 3.404        # 11 ft 2 in
const PRINTED_TAILPLANE := 4.016   # 13 ft 2-1/8 in
const PRINTED_GROUND_ANGLE := 13.6 # 13 deg 36 min, the three-point attitude
const WING_LE_SLOPE := 0.0671      # station a metre out, the port wing's 340 rows, 6.4 mm rms
const WING_TE_SLOPE := -0.1886     # both wings' 340 rows, 2.7 and 2.5 mm rms
const DIHEDRAL := 5.7              # degrees, the front view's middle surface 2.0 to 5.4 m out (5 printed)
const DRAWN_WING_AREA := 22.44     # m2, the drawn planform, 2.8 per cent over [WP]'s 21.8
const SCOOP_BOTTOM := -1.17        # m under the thrust line, the side view's deepest; the front view's -1.165
const CANOPY_TOP := 0.943          # m over the thrust line, the side view's highest
const FIN_TOP := 1.782             # m over the thrust line, the side view at its vertical scale
const GUN_OUTS: Array = [2.06, 2.23, 2.41]   # the front view's three muzzles a wing
const AILERON_TRAVEL := 15.0       # printed "10, 12 or 15 degrees max"
const ELEVATOR_UP := 30.0          # printed
const ELEVATOR_DOWN := 20.0        # printed
const RUDDER_TRAVEL := 30.0        # printed
const FLAP_TRAVEL := 47.0          # printed

## Every part a reader would name when looking at a P-51D.
const PARTS: Array = ["Fuselage", "Coaming", "Spinner", "Propeller", "ChinIntake", "Exhausts", "Scoop", "Mast", "Wells",
	"WingStarboard", "WingPort", "GunsStarboard", "GunsPort", "AileronStarboard", "AileronPort", "FlapStarboard",
	"FlapPort", "ElevatorStarboard", "ElevatorPort", "Tailplane", "Fin", "Rudder", "MainGearStarboard", "MainGearPort",
	"InnerDoorStarboard", "InnerDoorPort", "TailGear", "TailDoorStarboard", "TailDoorPort"]
const LEGS: Array = ["MainGearStarboard", "MainGearPort", "TailGear"]
const INNER_DOORS: Array = ["InnerDoorStarboard", "InnerDoorPort"]
const TAIL_DOORS: Array = ["TailDoorStarboard", "TailDoorPort"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[p51] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var frame := P51Airframe.new()
	add_child(frame)
	frame.dress()
	_probe(frame)
	_every_visible_mesh_is_a_named_part(frame)
	_it_is_one_object_and_not_a_set_of_parts(frame)
	_the_drawn_aeroplane_is_the_published_length_and_span(frame)
	_the_tyres_stand_on_the_ground_level_and_three_point(frame)
	_it_stands_the_published_height_tail_down(frame)
	_it_parks_tail_down_on_three_points(frame)
	_the_wing_has_the_measured_edges_dihedral_and_area(frame)
	_it_has_the_mustangs_scoop_canopy_fin_and_guns(frame)
	_the_propeller_is_the_printed_size_and_turns_clockwise(frame)
	_the_inner_doors_open_before_a_leg_moves_and_shut_after(frame)
	_no_leg_ever_passes_through_a_door(frame)
	_the_mains_fold_inward_and_the_tail_wheel_forward_inside_the_skin(frame)
	_the_hinged_surfaces_move_the_right_way_and_come_back(frame)
	_every_face_is_wound_outwards(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	await _the_vat_draws_the_moving_parts_where_the_parts_are(frame)
	frame.queue_free()
	_finish()


## A PROBE BEFORE A PICTURE: every visible mesh's drawn box in the craft's frame, printed.
func _probe(frame: Node3D) -> void:
	for mesh in _meshes(frame):
		var box := _box_of(frame, [mesh])
		print("[p51] probe %-20s x %6.2f..%6.2f  y %6.2f..%6.2f  z %6.2f..%6.2f" % [mesh.name, box.position.x,
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


## ONE OBJECT: every drawn part reaches the fuselage (`DrawnParts.adrift`), with the gear down, half-way and up, and every
## surface at its stop.
func _it_is_one_object_and_not_a_set_of_parts(frame: P51Airframe) -> void:
	var said: PackedStringArray = []
	for pose in [[1.0, 0.0], [0.5, 1.0], [0.0, 1.0], [0.0, -1.0]]:
		frame.set_gear(pose[0])
		frame.set_ailerons(pose[1])
		frame.set_elevators(pose[1])
		frame.set_rudders(pose[1])
		frame.set_flaps(absf(pose[1]))
		for s in DrawnParts.adrift(frame):
			said.append("%s %.2f m from %s at gear %.1f surfaces %.1f" % [s["name"], s["gap"], s["nearest"], pose[0],
				pose[1]])
	_rest(frame)
	_check("it_is_one_object_and_not_a_set_of_parts", said.is_empty(),
		"%d parts, adrift: %s" % [DrawnParts.count(frame), ", ".join(said) if not said.is_empty() else "none"])


## THE ENVELOPE, from transformed vertices: the spinner's tip to the rudder's trailing edge against the published and the
## printed length, and tip to tip against the published and printed span (2 per cent of the published, 1 of the printed).
func _the_drawn_aeroplane_is_the_published_length_and_span(frame: P51Airframe) -> void:
	var box := _box_of(frame, _meshes(frame))
	var length: float = box.size.z
	var span: float = box.size.x
	_check("the_drawn_aeroplane_is_the_published_length_and_span",
		absf(length - PUBLISHED_LENGTH) <= PUBLISHED_LENGTH * 0.02 and absf(span - PUBLISHED_SPAN) <= PUBLISHED_SPAN * 0.02
			and absf(length - PRINTED_LENGTH) <= PRINTED_LENGTH * 0.01 and absf(span - PRINTED_SPAN) <= PRINTED_SPAN * 0.01,
		"drawn %.3f m long and %.3f m across; published %.2f and %.2f, printed %.3f and %.3f; %.3f m tall level on the mains"
			% [length, span, PUBLISHED_LENGTH, PUBLISHED_SPAN, PRINTED_LENGTH, PRINTED_SPAN, box.size.y])


## THE TYRES, gear down: both main tyres' bottoms on the level ground, which is the lowest drawn point of the aeroplane
## and the box's floor; the main tyres the printed track apart, middle to middle; and the tail wheel's bottom and the
## main tyres' on one straight line raked at the printed ground angle (a degree either way), which is the aeroplane parked.
func _the_tyres_stand_on_the_ground_level_and_three_point(frame: P51Airframe) -> void:
	frame.set_gear(1.0)
	var all := _box_of(frame, _meshes(frame))
	var mains: Array = []
	for leg in ["MainGearStarboard", "MainGearPort"]:
		mains.append(_dark_box(frame, frame.find_child(leg, true, false) as MeshInstance3D))
	var tail: AABB = _dark_box(frame, frame.find_child("TailGear", true, false) as MeshInstance3D)
	var floor_y: float = -frame.geometry()["extents"].y
	var level: bool = absf((mains[0] as AABB).position.y - floor_y) < 0.005 and absf((mains[1] as AABB).position.y - floor_y) < 0.005 \
		and absf(all.position.y - floor_y) < 0.005
	var track: float = (mains[0] as AABB).get_center().x - (mains[1] as AABB).get_center().x
	# THE RAKE: the lower common tangent of the main tyre's and the tail wheel's drawn circles, as the side view draws it.
	var main_c: Vector3 = (mains[0] as AABB).get_center()
	var tail_c: Vector3 = tail.get_center()
	var r_main: float = (mains[0] as AABB).size.y * 0.5
	var r_tail: float = tail.size.y * 0.5
	var d: float = Vector2(tail_c.z - main_c.z, tail_c.y - main_c.y).length()
	var rake: float = rad_to_deg(atan2(tail_c.y - main_c.y, tail_c.z - main_c.z) + asin((r_main - r_tail) / d))
	_check("the_tyres_stand_on_the_ground_level_and_three_point",
		level and absf(track - PRINTED_TRACK) < 0.01 and absf(rake - PRINTED_GROUND_ANGLE) < 1.0,
		"main tyre bottoms %.3f and %.3f, the lowest drawn point %.3f, the box's floor %.3f; track %.3f m (printed %.3f); three-point rake %.2f deg (printed %.1f)"
			% [(mains[0] as AABB).position.y, (mains[1] as AABB).position.y, all.position.y, floor_y, track,
				PRINTED_TRACK, rake, PRINTED_GROUND_ANGLE])


## THE PUBLISHED HEIGHT IS TAIL DOWN, "a blade vertical" [WP]: every drawn vertex, the propeller turned so a blade stands
## straight up, taken into the three-point attitude by the rake the tyres give, and its height over the raked ground. A
## THIRD QUANTITY: the drawing's heights were scaled by its two printed heights and its length by its own, and neither
## is this figure. 2 per cent.
func _it_stands_the_published_height_tail_down(frame: P51Airframe) -> void:
	frame.set_gear(1.0)
	frame.set_props(0.0)
	var main: AABB = _dark_box(frame, frame.find_child("MainGearStarboard", true, false) as MeshInstance3D)
	var tail: AABB = _dark_box(frame, frame.find_child("TailGear", true, false) as MeshInstance3D)
	var a := Vector2(main.get_center().z, main.position.y)
	var b := Vector2(tail.get_center().z, tail.position.y)
	var rake: float = atan2(b.y - a.y, b.x - a.x)
	var highest: float = -INF
	for mesh in _meshes(frame):
		for p in _points(frame, mesh):
			# Height over the raked line through the two tyres' bottoms, square to it.
			var rel := Vector2(p.z - a.x, p.y - a.y)
			highest = maxf(highest, rel.y * cos(rake) - rel.x * sin(rake))
	_check("it_stands_the_published_height_tail_down", absf(highest - PUBLISHED_HEIGHT) <= PUBLISHED_HEIGHT * 0.02,
		"%.3f m over the three-point ground, raked %.2f deg; published %.2f tail down with a blade vertical"
			% [highest, rad_to_deg(rake), PUBLISHED_HEIGHT])


## PARKED, THE REAL WAY: every drawn vertex, gear down and a blade vertical, taken through `parked()`. Both main tyres and
## the tail wheel then touch the level floor (the box's), nothing is below it, and the nose is up by the printed ground
## angle (a degree either way). A tyre is ten facets, so its lowest vertex may stand a little off a circle's bottom: 2.5 cm
## is allowed, the most is r(1 - cos 18 deg), 2.1 cm on the P-47's main. Built level and pictured so, the aeroplane sat
## on its mains with the tail wheel in the air (team-lead, 2026-09-19).
func _it_parks_tail_down_on_three_points(frame: P51Airframe) -> void:
	frame.set_gear(1.0)
	frame.set_props(0.0)
	var stance: Transform3D = frame.parked()
	var floor_y: float = -frame.geometry()["extents"].y
	var said: PackedStringArray = []
	var ok: bool = true
	for leg in ["MainGearStarboard", "MainGearPort", "TailGear"]:
		var mesh := frame.find_child(leg, true, false) as MeshInstance3D
		var colours: PackedColorArray = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var pts := _points(frame, mesh)
		var low: float = INF
		for i in range(pts.size()):
			if colours[i].v < 0.1:
				low = minf(low, (stance * pts[i]).y)
		ok = ok and absf(low - floor_y) < 0.025
		said.append("%s %+.3f" % [leg, low - floor_y])
	var lowest: float = INF
	for mesh in _meshes(frame):
		for p in _points(frame, mesh):
			lowest = minf(lowest, (stance * p).y)
	var rake: float = rad_to_deg(-asin((stance.basis * Vector3.BACK).y))
	ok = ok and lowest >= floor_y - 0.002 and absf(rake - PRINTED_GROUND_ANGLE) < 1.0
	_rest(frame)
	_check("it_parks_tail_down_on_three_points", ok,
		"tyres' lowest over the floor: %s; the lowest drawn point %+.3f; nose up %.2f deg (printed %.1f)"
			% ["; ".join(said), lowest - floor_y, rake, PRINTED_GROUND_ANGLE])


## THE WING'S EDGES, DIHEDRAL AND AREA, from its drawn vertices: the leading edge's slope outboard of the root extension
## and the trailing edge's (the flaps' and aileron's drawn ends) over the loft's sections from 1.2 to 5.4 m out, against
## the plan's fits; the middle surface's rise
## against the front view's; and the planform, the fixed wing and the surfaces behind it with the root chord carried to
## the centreline, against the drawn 22.4 m2.
func _the_wing_has_the_measured_edges_dihedral_and_area(frame: P51Airframe) -> void:
	var le: Array = []
	var mid: Array = []
	var bands: Dictionary = {}
	for p in _points(frame, frame.find_child("WingStarboard", true, false) as MeshInstance3D):
		var band: int = int(round(p.x / 0.01))
		var b: Array = bands.get(band, [INF, -INF, INF, -INF])
		bands[band] = [minf(b[0], p.z), maxf(b[1], p.z), minf(b[2], p.y), maxf(b[3], p.y)]
	for band in bands:
		var x: float = float(band) * 0.01
		var b: Array = bands[band]
		if x >= 1.19 and x <= 5.41:
			le.append(Vector3(x, b[0], 0.0))
			mid.append(Vector3(x, (float(b[2]) + float(b[3])) * 0.5, 0.0))
	var te: Array = []
	for part in ["FlapStarboard", "AileronStarboard"]:
		var aft: Dictionary = {}
		for p in _points(frame, frame.find_child(part, true, false) as MeshInstance3D):
			var band: int = int(round(p.x / 0.01))
			aft[band] = maxf(float(aft.get(band, -INF)), p.z)
		for band in aft:
			if float(band) * 0.01 >= 1.19 and float(band) * 0.01 <= 5.41:
				te.append(Vector3(float(band) * 0.01, aft[band], 0.0))
	var le_slope: float = tan(deg_to_rad(_slope(le, func(p: Vector3) -> float: return p.y)))
	var te_slope: float = tan(deg_to_rad(_slope(te, func(p: Vector3) -> float: return p.y)))
	var dihedral: float = _slope(mid, func(p: Vector3) -> float: return p.y)
	# THE AREA: the starboard planform integrated every centimetre from the root out, between the drawn leading edge (the
	# wing's foremost point at each of its sections, straight between them) and the drawn trailing edge (the wing's
	# aftmost where nothing is hinged behind it, the flap's and aileron's aftmost where something is); inboard of the
	# fuselage's side, 0.47 m out, the chord there is carried to the centreline, as a reference area is.
	var front: Dictionary = {}
	var back: Dictionary = {}
	for p in _points(frame, frame.find_child("WingStarboard", true, false) as MeshInstance3D):
		var band: int = int(round(p.x / 0.005))
		front[band] = minf(float(front.get(band, INF)), p.z)
		var hinged: bool = (p.x > P51Airframe.FLAP.x + 0.01 and p.x < P51Airframe.FLAP.y - 0.01) or \
			(p.x > P51Airframe.AILERON.x + 0.01 and p.x < P51Airframe.AILERON.y - 0.01)
		if not hinged:
			back[band] = maxf(float(back.get(band, -INF)), p.z)
	for part in ["FlapStarboard", "AileronStarboard"]:
		for p in _points(frame, frame.find_child(part, true, false) as MeshInstance3D):
			var band: int = int(round(p.x / 0.005))
			back[band] = maxf(float(back.get(band, -INF)), p.z)
	var area: float = 0.0
	var x: float = 0.47
	area += (_edge(back, 0.47) - _edge(front, 0.47)) * 0.47
	while x < 5.64:
		var c0: float = _edge(back, x) - _edge(front, x)
		var c1: float = _edge(back, minf(x + 0.01, 5.64)) - _edge(front, minf(x + 0.01, 5.64))
		area += (c0 + c1) * 0.5 * (minf(x + 0.01, 5.64) - x)
		x += 0.01
	area *= 2.0
	_check("the_wing_has_the_measured_edges_dihedral_and_area",
		absf(le_slope - WING_LE_SLOPE) < 0.006 and absf(te_slope - WING_TE_SLOPE) < 0.006 and absf(dihedral - DIHEDRAL) < 0.5
			and absf(area - DRAWN_WING_AREA) <= DRAWN_WING_AREA * 0.02,
		"leading edge %.4f m aft a metre out over %d bands (measured %.4f); trailing edge %.4f over %d (%.4f); dihedral %.2f deg (%.1f); area %.2f m2 (drawn %.2f, published 21.8)"
			% [le_slope, le.size(), WING_LE_SLOPE, te_slope, te.size(), WING_TE_SLOPE, dihedral, DIHEDRAL, area,
				DRAWN_WING_AREA])


## THE MUSTANG'S OWN SHAPES, from drawn vertices against the drawing's: the radiator scoop's bottom and where it hangs
## (behind the wing's leading edge, under the belly); the bubble canopy's top; the fin's top; the tailplane's span
## against the printed 13 ft 2-1/8 in; and SIX guns, three muzzles a wing at the front view's distances out, each ahead of
## its wing's drawn leading edge. Heights over the thrust line are `point(0, 0, 0)`'s.
func _it_has_the_mustangs_scoop_canopy_fin_and_guns(frame: P51Airframe) -> void:
	_rest(frame)
	var thrust: float = frame.point(0.0, 0.0, 0.0).y
	var nose: float = frame.point(0.0, 0.0, 0.0).z
	var scoop := _box_of(frame, [frame.find_child("Scoop", true, false)])
	var glass_top: float = -INF
	var fuselage := frame.find_child("Fuselage", true, false) as MeshInstance3D
	for p in _surface_points(frame, fuselage, 1):
		glass_top = maxf(glass_top, p.y)
	var fin := _box_of(frame, [frame.find_child("Fin", true, false)])
	var tail := _box_of(frame, [frame.find_child("Tailplane", true, false), frame.find_child("ElevatorStarboard", true, false),
		frame.find_child("ElevatorPort", true, false)])
	var muzzles: Array = []
	for side in ["Starboard", "Port"]:
		var guns := frame.find_child("Guns" + side, true, false) as MeshInstance3D
		var wing_le: float = _box_of(frame, [frame.find_child("Wing" + side, true, false)]).position.z
		# EACH BARREL, its vertices grouped by the drawn distance out they sit at (barrels are 0.17 m apart and 0.044 m
		# across); its muzzle the foremost of them, at the middle of the group's span.
		var groups: Dictionary = {}
		for p in _points(frame, guns):
			var key: int = int(round(absf(p.x) / 0.17))
			var g: Array = groups.get(key, [INF, INF, -INF])
			groups[key] = [minf(float(g[0]), p.z), minf(float(g[1]), absf(p.x)), maxf(float(g[2]), absf(p.x))]
		for key in groups:
			muzzles.append([side, (float(groups[key][1]) + float(groups[key][2])) * 0.5, float(groups[key][0])])
	var guns_ok: bool = muzzles.size() == 6
	var said: PackedStringArray = []
	for m in muzzles:
		var nearest: float = INF
		for o in GUN_OUTS:
			nearest = minf(nearest, absf(float(m[1]) - float(o)))
		var le_there: float = _leading_edge_at(frame, String(m[0]), float(m[1]))
		guns_ok = guns_ok and nearest < 0.03 and float(m[2]) < le_there - 0.03
		said.append("%s %.2f out, %.2f ahead of the edge" % [m[0], m[1], le_there - float(m[2])])
	var scoop_bottom: float = scoop.position.y - thrust
	_check("it_has_the_mustangs_scoop_canopy_fin_and_guns",
		absf(scoop_bottom - SCOOP_BOTTOM) < 0.03 and scoop.position.z - nose > 3.8 and absf(glass_top - thrust - CANOPY_TOP) < 0.02
			and absf(fin.end.y - thrust - FIN_TOP) < 0.02 and absf(tail.size.x - PRINTED_TAILPLANE) < PRINTED_TAILPLANE * 0.01
			and guns_ok,
		"scoop bottom %.3f (measured %.2f) from station %.2f; canopy top %.3f (%.3f); fin top %.3f (%.3f); tailplane %.3f m (printed %.3f); %d muzzles: %s"
			% [scoop_bottom, SCOOP_BOTTOM, scoop.position.z - nose, glass_top - thrust, CANOPY_TOP, fin.end.y - thrust,
				FIN_TOP, tail.size.x, PRINTED_TAILPLANE, muzzles.size(), ", ".join(said)])


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


## The drawn wing's leading edge, as a station in the craft's frame, `out` metres out on `side`.
func _leading_edge_at(frame: Node3D, side: String, out: float) -> float:
	# THE LOFT'S SECTIONS, each its foremost point, and the edge between the two either side of `out`.
	var edge: Dictionary = {}
	for p in _points(frame, frame.find_child("Wing" + side, true, false) as MeshInstance3D):
		var band: int = int(round(absf(p.x) / 0.005))
		edge[band] = minf(float(edge.get(band, INF)), p.z)
	var below: int = -1
	var above: int = -1
	for band in edge:
		if float(band) * 0.005 <= out and (below < 0 or band > below):
			below = band
		if float(band) * 0.005 >= out and (above < 0 or band < above):
			above = band
	if below < 0 or above < 0 or below == above:
		return float(edge.get(below, INF))
	return lerpf(float(edge[below]), float(edge[above]), (out - float(below) * 0.005) / (float(above - below) * 0.005))


## THE PROPELLER: its drawn blades' tips the printed 3.404 m across (1 per cent), four blades; a quarter of the phase turns
## blade 0 clockwise seen from behind (from the tip at the top towards starboard), and a whole phase -- one blade's pitch
## -- brings every tip back onto a tip.
func _the_propeller_is_the_printed_size_and_turns_clockwise(frame: P51Airframe) -> void:
	frame.set_props(0.0)
	var mesh := frame.find_child("Propeller", true, false) as MeshInstance3D
	var hub: Vector3 = frame.point(0.0, 0.0, P51Airframe.PROP_STATION)
	var before := _points(frame, mesh)
	var reach: float = 0.0
	var top := Vector3.ZERO
	for p in before:
		var r: float = Vector2(p.x - hub.x, p.y - hub.y).length()
		if r > reach:
			reach = r
		if p.y - hub.y > top.y - hub.y:
			top = p
	frame.set_props(0.25)
	var turned := _points(frame, mesh)
	var top_after: Vector3 = turned[before.find(top)]
	frame.set_props(1.0 - 1e-6)
	var whole := _points(frame, mesh)
	var worst: float = 0.0
	for p in whole:
		var nearest: float = INF
		for q in before:
			nearest = minf(nearest, p.distance_to(q))
		worst = maxf(worst, nearest)
	frame.set_props(0.0)
	var clockwise: bool = top_after.x > top.x + 0.1
	_check("the_propeller_is_the_printed_size_and_turns_clockwise",
		absf(reach * 2.0 - PRINTED_PROP) < PRINTED_PROP * 0.01 and clockwise and worst < 0.005,
		"tips %.3f m across (printed %.3f); the top tip moved %+.2f m to starboard over a quarter pitch; a whole pitch puts every vertex %.4f m from one drawn before"
			% [reach * 2.0, PRINTED_PROP, top_after.x - top.x, worst])


## THE GEAR'S SEQUENCE: THE INNER DOORS OPEN, THEN THE LEGS MOVE, THEN THE INNER DOORS SHUT. Stepped through the cycle in
## 1 per cent steps, each door and leg read back from its drawn vertices against its own two ends: at no step may a leg
## be off both of its ends while an inner door is short of fully open; with the gear down and up the inner doors are
## shut; and the tail wheel's doors are open with it down and shut with it up.
func _the_inner_doors_open_before_a_leg_moves_and_shut_after(frame: P51Airframe) -> void:
	frame.set_gear(1.0)
	var down := _poses(frame, LEGS + INNER_DOORS + TAIL_DOORS)
	frame.set_gear(0.0)
	var up := _poses(frame, LEGS + INNER_DOORS + TAIL_DOORS)
	frame.set_gear(0.5)
	var open_pose := _poses(frame, INNER_DOORS)
	var bad: PackedStringArray = []
	for step in range(101):
		frame.set_gear(float(step) / 100.0)
		var now := _poses(frame, LEGS + INNER_DOORS)
		var moving: bool = false
		for leg in LEGS:
			if _off(now[leg], down[leg]) > 0.002 and _off(now[leg], up[leg]) > 0.002:
				moving = true
		if moving:
			for door in INNER_DOORS:
				if _off(now[door], open_pose[door]) > 0.002:
					bad.append("%d%% %s" % [step, door])
	var shut_both: bool = true
	for door in INNER_DOORS:
		shut_both = shut_both and _off(down[door], up[door]) < 0.002 and _off(down[door], open_pose[door]) > 0.2
	var tail_opens: bool = true
	for door in TAIL_DOORS:
		tail_opens = tail_opens and _off(down[door], up[door]) > 0.05
	_rest(frame)
	_check("the_inner_doors_open_before_a_leg_moves_and_shut_after", bad.is_empty() and shut_both and tail_opens,
		"%d steps with a leg moving past a door short of open %s; inner doors shut down and up %s; tail doors open only down %s"
			% [bad.size(), bad.slice(0, 4), shut_both, tail_opens])


## NO LEG EVER PASSES THROUGH A DOOR. At every 2 per cent of the cycle, every edge of every leg's drawn triangles is asked
## whether it crosses any triangle of any door.
func _no_leg_ever_passes_through_a_door(frame: P51Airframe) -> void:
	var crossings: PackedStringArray = []
	for step in range(0, 101, 2):
		frame.set_gear(float(step) / 100.0)
		for door in INNER_DOORS + TAIL_DOORS:
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
	_check("no_leg_ever_passes_through_a_door", crossings.is_empty(),
		"%d crossings %s" % [crossings.size(), crossings.slice(0, 6)])


## THE GEAR UP, THE P-51D'S WAY: each main tyre FOLDED INWARD -- its middle a metre inboard of where it stood with the
## gear down and within 0.8 m of the centreline, lying flat -- and every vertex of it over the underside the inner doors close, so it is
## in the wing's root and not hanging under it; and the tail wheel FORWARD of where it stood and every drawn vertex of it
## inside the fuselage by ray parity.
func _the_mains_fold_inward_and_the_tail_wheel_forward_inside_the_skin(frame: P51Airframe) -> void:
	frame.set_gear(1.0)
	var down: Dictionary = {}
	for leg in LEGS:
		down[leg] = _dark_box(frame, frame.find_child(leg, true, false) as MeshInstance3D)
	frame.set_gear(0.0)
	var said: PackedStringArray = []
	var ok: bool = true
	for leg in ["MainGearStarboard", "MainGearPort"]:
		var up: AABB = _dark_box(frame, frame.find_child(leg, true, false) as MeshInstance3D)
		var inward: bool = absf(up.get_center().x) < absf((down[leg] as AABB).get_center().x) - 1.0 and absf(up.get_center().x) < 0.8
		var flat: bool = up.size.y < up.size.x * 0.5
		var lowest: float = up.position.y
		var door_line: float = _box_of(frame, [frame.find_child("InnerDoorStarboard", true, false)]).position.y
		var hidden: bool = lowest > door_line
		# EVERY VERTEX OF THE STOWED TYRE INSIDE THE DRAWN SKIN -- the fuselage's or the wing's, each by ray parity on
		# its own -- so no part of it shows through: the first well, at the drawing's dashed circles, put both tyres'
		# fronts through the root's thin forward skin, which the picture from below showed and no number here did.
		var tyre := frame.find_child(leg, true, false) as MeshInstance3D
		var colours: PackedColorArray = tyre.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var pts := _points(frame, tyre)
		var skin := _skin(frame)
		var wing := _solid(frame, "WingStarboard" if leg.ends_with("Starboard") else "WingPort")
		var poking: int = 0
		for i in range(pts.size()):
			if colours[i].v < 0.1 and not _inside_of(skin, pts[i]) and not _inside_of(wing, pts[i]):
				poking += 1
		ok = ok and inward and flat and hidden and poking == 0
		said.append("%s centre %.2f out (down %.2f), %.2f thick against %.2f across, lowest %.3f over the shut doors' %.3f, %d tyre vertices outside the skin"
			% [leg, up.get_center().x, (down[leg] as AABB).get_center().x, up.size.y, up.size.x, lowest, door_line, poking])
	var tail: AABB = _dark_box(frame, frame.find_child("TailGear", true, false) as MeshInstance3D)
	var outside: int = 0
	var skin := _skin(frame)
	for p in _points(frame, frame.find_child("TailGear", true, false) as MeshInstance3D):
		if not _inside_of(skin, p):
			outside += 1
	var forward: bool = tail.get_center().z < (down["TailGear"] as AABB).get_center().z - 0.3
	ok = ok and outside == 0 and forward
	said.append("tail wheel %.2f forward of down, %d vertices outside the fuselage" % [(down["TailGear"] as AABB).get_center().z
		- tail.get_center().z, outside])
	_rest(frame)
	_check("the_mains_fold_inward_and_the_tail_wheel_forward_inside_the_skin", ok, "; ".join(said))


## THE SURFACES, ONE AXIS AT A TIME, read back from DRAWN vertices: right roll raises the right aileron's trailing edge
## and lowers the left's, by the printed travel; nose-up raises both elevators' by the printed 30 and nose-down lowers
## them by the printed 20; right pedal swings the rudder's to starboard by 30; the flaps go down 47; and at zero every one
## is back where it was drawn.
func _the_hinged_surfaces_move_the_right_way_and_come_back(frame: P51Airframe) -> void:
	_rest(frame)
	var rest := _poses(frame, ["AileronStarboard", "AileronPort", "ElevatorStarboard", "ElevatorPort", "Rudder",
		"FlapStarboard", "FlapPort"])
	var said: PackedStringArray = []
	var ok: bool = true
	frame.set_ailerons(1.0)
	var right: float = _turned(frame, "AileronStarboard", rest)
	var left: float = _turned(frame, "AileronPort", rest)
	ok = ok and absf(right - AILERON_TRAVEL) < 0.5 and absf(left + AILERON_TRAVEL) < 0.5
	said.append("roll right: right aileron %+.1f, left %+.1f deg (trailing edge up +)" % [right, left])
	_rest(frame)
	frame.set_elevators(1.0)
	var up_e: float = _turned(frame, "ElevatorStarboard", rest)
	var up_p: float = _turned(frame, "ElevatorPort", rest)
	frame.set_elevators(-1.0)
	var down_e: float = _turned(frame, "ElevatorStarboard", rest)
	ok = ok and absf(up_e - ELEVATOR_UP) < 0.5 and absf(up_p - ELEVATOR_UP) < 0.5 and absf(down_e + ELEVATOR_DOWN) < 0.5
	said.append("elevators %+.1f / %+.1f up, %+.1f down" % [up_e, up_p, down_e])
	_rest(frame)
	frame.set_rudders(1.0)
	var rudder := _trailing(frame, "Rudder")
	var rudder_rest: Vector3 = _trailing_of(rest["Rudder"])
	ok = ok and rudder.x > rudder_rest.x + 0.2
	said.append("rudder trailing edge %+.2f m to starboard" % [rudder.x - rudder_rest.x])
	_rest(frame)
	frame.set_flaps(1.0)
	var flap: float = _turned(frame, "FlapStarboard", rest)
	var flap_p: float = _turned(frame, "FlapPort", rest)
	ok = ok and absf(flap + FLAP_TRAVEL) < 0.5 and absf(flap_p + FLAP_TRAVEL) < 0.5
	said.append("flaps %+.1f / %+.1f" % [flap, flap_p])
	_rest(frame)
	var back: float = 0.0
	var now := _poses(frame, rest.keys())
	for part in rest:
		back = maxf(back, _off(now[part], rest[part]))
	ok = ok and back < 1e-4
	said.append("all back within %.6f m" % back)
	_check("the_hinged_surfaces_move_the_right_way_and_come_back", ok, "; ".join(said))


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
		"the whole P51Airframe subtree: %d triangles, %d draw surfaces, %d materials, %d distance-culled"
			% [triangles, draws, materials.size(), culled])


## THE MOVING PARTS AS A VERTEX ANIMATION TEXTURE, held to the parts it was baked from TO A MILLIMETRE, at amounts OFF THE
## GRID with every feature moving at once (`tests/warthog.gd`'s check).
func _the_vat_draws_the_moving_parts_where_the_parts_are(parts: P51Airframe) -> void:
	var cast := P51Airframe.new()
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
		for part in ["MainGearStarboard", "TailGear", "InnerDoorPort", "TailDoorStarboard", "AileronPort", "ElevatorPort",
				"Rudder", "FlapStarboard", "Propeller"]:
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
		"features %s; worst vertex %.5f m off its part (%s), by the CPU copy of the shader; drawn parts %d before the pour and %d after"
			% [names, worst, worst_at, before, after])
	cast.queue_free()


func _rest(frame: P51Airframe) -> void:
	frame.set_gear(1.0)
	frame.set_ailerons(0.0)
	frame.set_elevators(0.0)
	frame.set_rudders(0.0)
	frame.set_flaps(0.0)
	frame.set_props(0.0)


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
	var pts := _points(frame, frame.find_child("Fuselage", true, false) as MeshInstance3D)
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
