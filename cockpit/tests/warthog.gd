extends Node
## Headless contract for the A-10C airframe: its measured envelope against the published one, the features that make it
## an A-10, a pilot room inside the drawn skin, one object, and the things that MOVE -- the GAU-8's barrels about the
## barrel on the centreline, the gear's nose doors opening before a leg moves and shutting after, the mains folding
## forward and staying half out of their pods, and every surface on the stick, the pedals, the flap lever and the speed
## brake, the decelerons split open -- each read back from DRAWN VERTICES, never from a node's transform. Read RESULT=.
##
## THE ENVELOPE AS CONSTANTS AT THE TOP, TYPED, so the reference is visible in one place and no check asks the builder's
## own constant what the builder did. Every MEASURED figure is printed from Kaboldy's three-view alone by
## `craft/warthog/measure_views.py`; the published ones are Wikipedia's for the A-10C.
const PUBLISHED_LENGTH := 16.26
const PUBLISHED_SPAN := 17.53
const PUBLISHED_HEIGHT := 4.47
const MEASURED_LENGTH := 16.20   # the plan's muzzle to the tail cone, 3,238 px at 199.83 px a metre
const MEASURED_SPAN := 17.53     # the FRONT view, tip to tip, 3,503 px (the plan's sets the scale, and agrees to the pixel)
const WING_LE_SLOPE := 0.1056    # station a metre out, fitted over 250 rows each side, 16 mm rms
const WING_TE_SLOPE := -0.0653   # 7 mm rms
const DIHEDRAL := 6.5            # degrees, the front view's middle surface outboard of the break
const PUBLISHED_WING_AREA := 47.0  # m2, Wikipedia's A-10C specifications; the drawn planform integrates to 46.93
const CENTRE_CHORD := 3.06       # m, the plan's constant centre-section chord (leading edge 6.84 on 30 rows, trailing 9.90)
const TAPER := 0.70              # the outer panel's chord at 8.2 m out over its chord at the break, 2.10 / 2.99
const GUN_DEPRESSION := 2.0      # degrees below the line of flight, the GAU-8 article
const MUZZLE_OFF := 0.01         # how far the drawn firing barrel's muzzle may be from `gun_port()`

## Every part a reader would name when looking at an A-10. A missing one fails by name; a duplicate would have been
## renamed `@MeshInstance3D@N` by Godot and fails `_every_visible_mesh_is_a_named_part`.
const PARTS: Array = ["Fuselage", "Wells", "BellyPylons", "WingPort", "WingStarboard", "DeceleronUpperPort",
	"DeceleronUpperStarboard", "DeceleronLowerPort", "DeceleronLowerStarboard", "FlapInnerPort", "FlapInnerStarboard",
	"FlapOuterPort", "FlapOuterStarboard", "NacellePort", "NacelleStarboard", "NacellePylonPort", "NacellePylonStarboard",
	"GearPodPort", "GearPodStarboard", "WingPylonsPort", "WingPylonsStarboard", "SlatPort", "SlatStarboard", "ElevatorPort", "ElevatorStarboard", "FinPort", "FinStarboard", "RudderPort",
	"RudderStarboard", "Tailplane", "GunBarrels", "NoseGear", "MainGearPort", "MainGearStarboard", "NoseDoorInner",
	"NoseDoorOuter", "Coaming"]
const LEGS: Array = ["NoseGear", "MainGearPort", "MainGearStarboard"]
const MAINS: Array = ["MainGearPort", "MainGearStarboard"]
const WELL_DOORS: Array = ["NoseDoorInner", "NoseDoorOuter"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[warthog] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var frame := WarthogAirframe.new()
	add_child(frame)
	frame.dress()
	_probe(frame)
	_every_visible_mesh_is_a_named_part(frame)
	_it_is_one_object_and_not_a_set_of_parts(frame)
	_the_drawn_aeroplane_is_the_published_length_and_span(frame)
	_every_tyre_stands_on_the_ground(frame)
	_the_wing_has_the_measured_edges_and_dihedral(frame)
	_the_wing_has_its_area_and_its_structure(frame)
	_the_pilot_sits_inside_the_drawn_skin(frame)
	_the_airframe_says_inside_where_the_drawn_skin_is(frame)
	_the_gun_fires_from_the_barrel_on_the_centreline(frame)
	_the_barrels_turn_about_the_cluster(frame)
	_the_gear_doors_open_before_a_leg_moves_and_shut_after(frame)
	_no_leg_ever_passes_through_a_door(frame)
	_the_nose_gear_stows_inside_the_skin_and_the_mains_half_out(frame)
	_the_hinged_surfaces_move_the_right_way_and_come_back(frame)
	_the_decelerons_split_open_and_ride_the_roll(frame)
	_every_face_is_wound_outwards(frame)
	_the_exterior_meets_the_first_lod_budget(frame)
	await _the_vat_draws_the_moving_parts_where_the_parts_are(frame)
	frame.queue_free()
	_the_pilot_sees_over_the_nose_past_the_cockpit()
	_finish()


## A PROBE BEFORE A PICTURE: every visible mesh's drawn box in the craft's frame, printed.
func _probe(frame: Node3D) -> void:
	for mesh in _meshes(frame):
		var box := _box_of(frame, [mesh])
		print("[warthog] probe %-24s x %6.2f..%6.2f  y %6.2f..%6.2f  z %6.2f..%6.2f" % [mesh.name, box.position.x,
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
## gear down, half-way and up, and every surface at its stop: a surface that swings away from its aeroplane is adrift.
func _it_is_one_object_and_not_a_set_of_parts(frame: WarthogAirframe) -> void:
	var said: PackedStringArray = []
	for pose in [[1.0, 0.0], [0.5, 1.0], [0.0, 1.0], [0.0, -1.0]]:
		frame.set_gear(pose[0])
		frame.set_ailerons(pose[1])
		frame.set_elevators(pose[1])
		frame.set_rudders(pose[1])
		frame.set_flaps(absf(pose[1]))
		frame.set_speedbrake(absf(pose[1]))
		for s in DrawnParts.adrift(frame):
			said.append("%s %.2f m from %s at gear %.1f surfaces %.1f" % [s["name"], s["gap"], s["nearest"], pose[0],
				pose[1]])
	_rest(frame)
	_check("it_is_one_object_and_not_a_set_of_parts", said.is_empty(),
		"%d parts, adrift: %s" % [DrawnParts.count(frame), ", ".join(said) if not said.is_empty() else "none"])


## THE ENVELOPE, from transformed vertices, against the published length and span (2 per cent) and the drawing's own
## (1 per cent). THE HEIGHT IS NOT CHECKED HERE, and that is deliberate: the drawing draws the gear up and its ground
## lines stand the fin 2.9 per cent over the published height, so the ground is put under the fin tip at the published
## 4.47 m (`WarthogAirframe.CLEARANCE`) and a height check would be the model agreeing with itself. The ground is held
## instead to the tyres (`_every_tyre_stands_on_the_ground`), and the height is printed.
func _the_drawn_aeroplane_is_the_published_length_and_span(frame: Node3D) -> void:
	var box := _box_of(frame, _meshes(frame))
	_check("the_drawn_aeroplane_is_the_published_length_and_span",
		absf(box.size.z - PUBLISHED_LENGTH) <= PUBLISHED_LENGTH * 0.02 and absf(box.size.x - PUBLISHED_SPAN) <= PUBLISHED_SPAN * 0.02
			and absf(box.size.z - MEASURED_LENGTH) <= MEASURED_LENGTH * 0.01 and absf(box.size.x - MEASURED_SPAN) <= MEASURED_SPAN * 0.01,
		"drawn %.3f m long and %.3f m across; published %.2f and %.2f, measured off the drawing %.2f and %.2f; %.3f m tall over the tyres, BUILT to the published %.2f"
			% [box.size.z, box.size.x, PUBLISHED_LENGTH, PUBLISHED_SPAN, MEASURED_LENGTH, MEASURED_SPAN, box.size.y,
				PUBLISHED_HEIGHT])


## THE TYRES, gear down: all three bottoms on one ground, which is the lowest drawn point of the aeroplane.
func _every_tyre_stands_on_the_ground(frame: WarthogAirframe) -> void:
	frame.set_gear(1.0)
	var all := _box_of(frame, _meshes(frame))
	var bottoms: Array = []
	for leg in LEGS:
		bottoms.append(_dark_box(frame, frame.find_child(leg, true, false) as MeshInstance3D).position.y)
	var level: bool = absf(float(bottoms.max()) - float(bottoms.min())) < 0.005 \
		and absf(float(bottoms.min()) - all.position.y) < 0.005
	var ground: float = frame.point(0.0, WarthogAirframe.ground(), 0.0).y
	_check("every_tyre_stands_on_the_ground", level and absf(float(bottoms.min()) - ground) < 0.005,
		"tyre bottoms %s, the lowest drawn point %.3f, the ground %.3f" % [bottoms, all.position.y, ground])


## THE WING'S EDGES AND DIHEDRAL, from its drawn vertices: the leading and trailing edges' slopes against the fits over
## 250 rows of the plan, and the middle surface's rise outboard of the kink against the front view's.
func _the_wing_has_the_measured_edges_and_dihedral(frame: WarthogAirframe) -> void:
	var le: Array = []
	var te: Array = []
	var mid: Array = []
	var bands: Dictionary = {}
	for p in _points(frame, frame.find_child("WingStarboard", true, false) as MeshInstance3D):
		if p.x < 3.3 or p.x > 8.1:
			continue
		var band: int = int(round(p.x / 0.01))
		var b: Array = bands.get(band, [INF, -INF, INF, -INF])
		bands[band] = [minf(b[0], p.z), maxf(b[1], p.z), minf(b[2], p.y), maxf(b[3], p.y)]
	for band in bands:
		var b: Array = bands[band]
		var x: float = float(band) * 0.01
		le.append(Vector3(x, b[0], 0.0))
		mid.append(Vector3(x, (float(b[2]) + float(b[3])) * 0.5, 0.0))
	# THE TRAILING EDGE where the wing's is the flaps' and the aileron's: the aftmost drawn point of each in every
	# 1 cm band of span (the wing's own fixed trailing edge outboard of the surfaces is too short a run to fit).
	var aft: Dictionary = {}
	for part in ["DeceleronUpperStarboard", "FlapOuterStarboard"]:
		for p in _points(frame, frame.find_child(part, true, false) as MeshInstance3D):
			# THE OUTER PANEL'S ONLY: inboard of the break the trailing edge is the centre section's, square across.
			if p.x < WarthogAirframe.WING_BREAK + 0.05:
				continue
			var band: int = int(round(p.x / 0.01))
			aft[band] = maxf(float(aft.get(band, -INF)), p.z)
	for band in aft:
		te.append(Vector3(float(band) * 0.01, aft[band], 0.0))
	var le_slope: float = tan(deg_to_rad(_slope(le, func(p: Vector3) -> float: return p.y)))
	var dihedral: float = _slope(mid, func(p: Vector3) -> float: return p.y)
	var te_slope: float = tan(deg_to_rad(_slope(te, func(p: Vector3) -> float: return p.y)))
	_check("the_wing_has_the_measured_edges_and_dihedral",
		absf(le_slope - WING_LE_SLOPE) < 0.005 and absf(te_slope - WING_TE_SLOPE) < 0.005 and absf(dihedral - DIHEDRAL) < 0.5,
		"leading edge %.4f m aft a metre out over %d bands (measured %.4f); trailing edge %.4f over %d points (%.4f); dihedral %.2f deg (%.1f)"
			% [le_slope, le.size(), WING_LE_SLOPE, te_slope, te.size(), WING_TE_SLOPE, dihedral, DIHEDRAL])


## THE A-10'S OWN WING, from its drawn vertices: the PLANFORM'S AREA, integrated section by section over the drawn wing and
## the flaps and ailerons behind it with the root chord carried to the centreline, against the published 47.0 m2 to 2
## per cent; a CENTRE SECTION of constant chord, flat, from the root to the break; an OUTER PANEL that tapers to the
## drawing's ratio; TIPS THAT DROOP below the panel's line; and SLATS on the leading edge of the outer panels' inner ends.
func _the_wing_has_its_area_and_its_structure(frame: WarthogAirframe) -> void:
	var wing := frame.find_child("WingStarboard", true, false) as MeshInstance3D
	# EACH HINGED SURFACE'S TRAILING EDGE, as the straight line between its two drawn ends: [x0, z0, x1, z1].
	var edges: Array = []
	for part in ["FlapInnerStarboard", "FlapOuterStarboard", "DeceleronUpperStarboard"]:
		var ends: Dictionary = {}
		for q in _points(frame, frame.find_child(part, true, false) as MeshInstance3D):
			var k: int = int(round(q.x * 1000.0))
			ends[k] = maxf(float(ends.get(k, -INF)), q.z)
		var ks: Array = ends.keys()
		ks.sort()
		edges.append([float(ks[0]) / 1000.0, float(ends[ks[0]]), float(ks[-1]) / 1000.0, float(ends[ks[-1]])])
	var wing_back: Dictionary = {}
	for q in _points(frame, wing):
		var k: int = int(round(q.x * 1000.0))
		wing_back[k] = maxf(float(wing_back.get(k, -INF)), q.z)
	var sections: Dictionary = {}
	for p in _points(frame, wing):
		var key: int = int(round(p.x * 1000.0))
		var here: Array = sections.get(key, [INF, INF, -INF])
		sections[key] = [minf(here[0], p.z), minf(here[1], p.y), maxf(here[2], p.y)]
	var xs: Array = sections.keys()
	xs.sort()
	# THE CHORD AT A DRAWN SECTION: its leading edge to whichever is further aft, the wing's own drawn trailing edge there
	# or a surface's edge line where one is hinged behind it (its ends are 2 cm inside the wing's breaks).
	var chord_at := func(x: float, le: float) -> float:
		var te: float = float(wing_back.get(int(round(x * 1000.0)), -INF))
		for e in edges:
			if x >= float(e[0]) - 0.025 and x <= float(e[2]) + 0.025:
				te = maxf(te, lerpf(float(e[1]), float(e[3]), clampf((x - float(e[0])) / (float(e[2]) - float(e[0])), 0.0, 1.0)))
		return te - le
	var area: float = 0.0
	var last_x: float = 0.0
	var last_c: float = 0.0
	var root_c: float = 0.0
	var centre_les: Array = []
	var centre_mids: Array = []
	var break_c: float = 0.0
	var outer_c: float = 0.0
	for key in xs:
		var x: float = float(key) / 1000.0
		var c: float = chord_at.call(x, float(sections[key][0]))
		if last_x == 0.0:
			root_c = c
			area += c * x
		else:
			area += (c + last_c) * 0.5 * (x - last_x)
		if x <= WarthogAirframe.WING_BREAK + 0.001:
			centre_les.append(float(sections[key][0]))
			centre_mids.append((float(sections[key][1]) + float(sections[key][2])) * 0.5)
		if absf(x - (WarthogAirframe.WING_BREAK + 0.01)) < 0.001:
			break_c = c
		if absf(x - WarthogAirframe.WING_OUTER) < 0.001:
			outer_c = c
		last_x = x
		last_c = c
	area *= 2.0
	var le_spread: float = float(centre_les.max()) - float(centre_les.min())
	var mid_spread: float = float(centre_mids.max()) - float(centre_mids.min())
	var tip_drop: float = frame.point(0.0, WarthogAirframe.wing_mid(WarthogAirframe.WING_OUTER)
		+ WarthogAirframe.WING_MID.y * (WarthogAirframe.WING_TIP - WarthogAirframe.WING_OUTER), 0.0).y \
		- float(sections[xs[-1]][2])
	var slat := frame.find_child("SlatStarboard", true, false) as MeshInstance3D
	var slat_box: AABB = _box_of(frame, [slat])
	var le_at_slat: float = frame.point(0.0, 0.0, WarthogAirframe.wing_le(slat_box.get_center().x)).z
	_check("the_wing_has_its_area_and_its_structure",
		absf(area - PUBLISHED_WING_AREA) <= PUBLISHED_WING_AREA * 0.02 and absf(root_c - CENTRE_CHORD) < 0.03
		and le_spread < 0.001 and mid_spread < 0.001 and absf(outer_c / break_c - TAPER) < 0.02 and tip_drop > 0.1
		and slat_box.position.z < le_at_slat and slat_box.position.x > WarthogAirframe.WING_BREAK,
		"planform %.2f m2 (published %.1f); centre chord %.3f m (drawn %.2f), its leading edge within %.4f m and its middle within %.4f m from root to break; outer panel %.2f m at the break to %.2f at 8.2 m out, %.2f (drawn %.2f); the tip's top %.2f m under the panel's line; slat %.2f to %.2f m out, ahead of the leading edge"
			% [area, PUBLISHED_WING_AREA, root_c, CENTRE_CHORD, le_spread, mid_spread, break_c, outer_c,
				outer_c / maxf(break_c, 0.001), TAPER, tip_drop, slat_box.position.x, slat_box.end.x])


## THE PILOT IS INSIDE THE AEROPLANE. Every corner of `cabin_room()`'s box, and the eye, inside the drawn fuselage by ray
## parity fired up and down only, both odd (`modelling_here.md` section 6); and the eye sees out: straight up and 30
## degrees either side of it, the first thing met is the canopy's glass.
func _the_pilot_sits_inside_the_drawn_skin(frame: WarthogAirframe) -> void:
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
	var sees: Dictionary = {}
	for look in [Vector3.UP, Vector3(0.5, 0.866, 0.0), Vector3(-0.5, 0.866, 0.0), Vector3(0.0, 0.5, -0.866)]:
		var hit: String = _first_hit(frame, frame.eye() + Vector3(0.0007, 0.0, 0.0007), look)
		sees[hit] = int(sees.get(hit, 0)) + 1
	_check("the_pilot_sits_inside_the_drawn_skin", outside.is_empty() and floor_ok and box.size.x >= 0.6
		and sees.keys() == ["Fuselage/1"],
		"room %.2f wide x %.2f tall x %.2f long, eye %.2f m over the floor; outside the skin: %s; looking up, up and out and up and ahead the eye meets %s"
			% [box.size.x, box.size.y, box.size.z, frame.eye().y - float(room["floor"]),
				"none" if outside.is_empty() else ", ".join(outside), sees])


## WHAT THE AIRFRAME SAYS IS INSIDE, THE DRAWN SKIN SAYS IS INSIDE: `encloses` is what fences the signal lamp's holster
## (`VehicleView.holster_fits`), and it answers from the sections, not the triangles. So every 5 cm box it calls inside,
## on a grid over the cockpit from the panel to the bubble's tail, 0.6 to 2.3 m over the datum and the fuselage's width
## across, has all eight corners inside the drawn fuselage and canopy by ray parity; and it calls the pilot's room
## inside, and enough of the grid that it is not simply refusing everything. MEASURED (2026-09-19): 1,692 boxes inside
## and none out; an `encloses` that said yes to everything called 2,970 inside and 1,265 of them had a corner out; the
## two rings' sections blended rather than the drawn triangles read put one corner out, at the bubble's tail, port.
func _the_airframe_says_inside_where_the_drawn_skin_is(frame: WarthogAirframe) -> void:
	var fore: Vector3 = frame.point(0.0, 0.0, WarthogAirframe.PANEL)
	var aft: Vector3 = frame.point(0.0, 0.0, WarthogAirframe.CANOPY.y)
	# ONLY THE TRIANGLES A VERTICAL RAY OVER THE COCKPIT CAN MEET, so the parity is the same and a tenth of the work.
	var near: Array = []
	for t in _skin(frame):
		var lo: float = minf(minf(t[0].z, t[1].z), t[2].z)
		var hi: float = maxf(maxf(t[0].z, t[1].z), t[2].z)
		if hi >= fore.z - 0.1 and lo <= aft.z + 0.1:
			near.append(t)
	var said: int = 0
	var wrong: PackedStringArray = []
	var s: float = WarthogAirframe.PANEL + 0.05
	while s < WarthogAirframe.CANOPY.y - 0.05:
		for i in range(15):
			for j in range(18):
				var at: Vector3 = frame.point(-0.70 + 0.1 * float(i) + 0.0007, 0.60 + 0.1 * float(j), s)
				var box := AABB(at - Vector3.ONE * 0.025, Vector3.ONE * 0.05)
				if not frame.encloses(box):
					continue
				said += 1
				for corner in range(8):
					if not _inside_of(near, box.get_endpoint(corner)):
						wrong.append("%s" % box.get_endpoint(corner))
						break
		s += 0.2
	var room: AABB = frame.cabin_room()["room"]
	var room_in: bool = frame.encloses(room.grow(-0.001))
	_check("the_airframe_says_inside_where_the_drawn_skin_is", wrong.is_empty() and said >= 400 and room_in,
		"%d boxes said inside, %d of them with a corner outside the drawn skin%s; the pilot's room %s" % [said,
			wrong.size(), "" if wrong.is_empty() else " (%s)" % ", ".join(wrong.slice(0, 4)),
			"inside" if room_in else "NOT inside"])


## THE GUN'S PORT IS THE BARREL ON THE CENTRELINE: `gun_port()` is on the centreline, and one drawn barrel's muzzle face
## -- the middle of its six front corners -- is within a centimetre of it, at rest and a barrel's pitch later (the next
## barrel has come round into the same place); the cluster points the published 2 degrees down.
func _the_gun_fires_from_the_barrel_on_the_centreline(frame: WarthogAirframe) -> void:
	var said: PackedStringArray = []
	var ok: bool = absf(frame.gun_port().x) < 0.001
	for phase in [0.0, 1.0 - 1e-6]:
		frame.set_gun(phase)
		var muzzles: Array = _muzzles(frame)
		var nearest: float = INF
		for m in muzzles:
			nearest = minf(nearest, (m as Vector3).distance_to(frame.gun_port()))
		ok = ok and nearest <= MUZZLE_OFF and muzzles.size() == WarthogAirframe.GUN_BARRELS
		said.append("phase %.2f: %d muzzles, the nearest %.4f m from the port" % [phase, muzzles.size(), nearest])
	frame.set_gun(0.0)
	var down: float = rad_to_deg(Vector3.FORWARD.angle_to(_barrel_axis(frame)))
	ok = ok and absf(down - GUN_DEPRESSION) < 0.1
	_check("the_gun_fires_from_the_barrel_on_the_centreline", ok,
		"port %s; %s; the drawn barrels point %.2f deg off the line of flight (published %.1f)"
			% [frame.gun_port(), ", ".join(said), down, GUN_DEPRESSION])


## THE BARRELS TURN ABOUT THE CLUSTER: half a barrel's pitch moves every muzzle round by half of 360/7 degrees about the
## cluster's axis, and the axis itself stays where it was.
func _the_barrels_turn_about_the_cluster(frame: WarthogAirframe) -> void:
	frame.set_gun(0.0)
	var before: Array = _muzzles(frame)
	var centre_before := Vector3.ZERO
	for m in before:
		centre_before += m
	centre_before /= float(before.size())
	frame.set_gun(0.5)
	var after: Array = _muzzles(frame)
	var centre_after := Vector3.ZERO
	for m in after:
		centre_after += m
	centre_after /= float(after.size())
	var least: float = INF
	for i in range(before.size()):
		least = minf(least, (before[i] as Vector3).distance_to(after[i]))
	frame.set_gun(0.0)
	# A barrel 0.075 m from the axis moved through 25.7 degrees travels 2 x 0.075 x sin(12.86) = 0.0334 m.
	var wanted: float = 2.0 * WarthogAirframe.GUN_CIRCLE * sin(PI / float(WarthogAirframe.GUN_BARRELS) * 0.5)
	_check("the_barrels_turn_about_the_cluster", before.size() == 7 and absf(least - wanted) < 0.002
		and centre_before.distance_to(centre_after) < 0.001,
		"half a barrel's pitch moved every muzzle at least %.4f m (a turn of 360/14 deg is %.4f); the axis moved %.5f m"
			% [least, wanted, centre_before.distance_to(centre_after)])


## THE GEAR'S SEQUENCE: DOORS OPEN, THEN THE LEGS MOVE, THEN THE DOORS SHUT. Stepped through the whole cycle in 1 per cent
## steps, each well door and each leg read back from its drawn vertices against its own two ends: at no step may a leg be
## off both of its ends while any well door is short of fully open; with the gear down and up the well doors are shut; and
## the order is seen both ways, the doors moving FIRST from each end.
func _the_gear_doors_open_before_a_leg_moves_and_shut_after(frame: WarthogAirframe) -> void:
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
## whether it crosses any triangle of either nose well door.
func _no_leg_ever_passes_through_a_door(frame: WarthogAirframe) -> void:
	var hits: Dictionary = {}
	for step in range(51):
		var amount: float = float(step) / 50.0
		frame.set_gear(amount)
		var door_tris: Array = []
		for door in WELL_DOORS:
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


## THE GEAR UP: every drawn vertex of the nose leg inside the fuselage's skin by ray parity, so nothing hangs out under a
## shut door; and each MAIN wheel folded FORWARD and HALF OUT OF ITS POD, which is the A-10's and is the point -- its
## tyre's bottom at least 0.2 m under the pod's, its axle ahead of where it stood with the gear down, and its strut's top
## inside the pod.
func _the_nose_gear_stows_inside_the_skin_and_the_mains_half_out(frame: WarthogAirframe) -> void:
	frame.set_gear(1.0)
	var down_axles: Dictionary = {}
	for leg in MAINS:
		down_axles[leg] = _dark_box(frame, frame.find_child(leg, true, false) as MeshInstance3D).get_center()
	frame.set_gear(0.0)
	var tris := _skin(frame)
	var outside: int = 0
	var total: int = 0
	var seen: Dictionary = {}
	for p in _points(frame, frame.find_child("NoseGear", true, false) as MeshInstance3D):
		var key: String = "%.3f %.3f %.3f" % [p.x, p.y, p.z]
		if seen.has(key):
			continue
		seen[key] = true
		total += 1
		if not _inside_of(tris, p + Vector3(0.0007, 0.0, 0.0007)):
			outside += 1
	var mains: PackedStringArray = []
	var mains_ok := true
	for leg in MAINS:
		var named: String = String(leg).trim_prefix("MainGear")
		var tyre := _dark_box(frame, frame.find_child(leg, true, false) as MeshInstance3D)
		var pod := _box_of(frame, [frame.find_child("GearPod" + named, true, false)])
		var below: float = pod.position.y - tyre.position.y
		var forward: float = (down_axles[leg] as Vector3).z - tyre.get_center().z
		mains_ok = mains_ok and below > 0.2 and below < tyre.size.y * 0.75 and forward > 1.0
		mains.append("%s tyre %.2f m under its pod, %.2f m ahead of where it stands down" % [leg, below, forward])
	frame.set_gear(1.0)
	_check("the_nose_gear_stows_inside_the_skin_and_the_mains_half_out", outside == 0 and total > 0 and mains_ok,
		"%d of %d distinct nose leg vertices outside the fuselage with the gear up; %s" % [outside, total, ", ".join(mains)])


## THE SURFACES, ONE AXIS AT A TIME, read back from DRAWN vertices (the F-16 lane's lesson: two axes at once hide a
## swapped one): right roll raises the right aileron's trailing edge and lowers the left's; nose-up raises both
## elevators'; right pedal swings both rudders' to starboard; flaps lower all four flaps and nothing else; and at zero
## every one is back where it was drawn.
func _the_hinged_surfaces_move_the_right_way_and_come_back(frame: WarthogAirframe) -> void:
	var parts: Array = ["DeceleronUpperStarboard", "DeceleronUpperPort", "ElevatorStarboard", "ElevatorPort",
		"RudderStarboard", "RudderPort", "FlapInnerStarboard", "FlapOuterPort"]
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
	frame.set_rudders(1.0)
	var yaw: Dictionary = moved.call()
	frame.set_rudders(0.0)
	frame.set_flaps(1.0)
	var flaps: Dictionary = moved.call()
	frame.set_flaps(0.0)
	var ok: bool = (roll["DeceleronUpperStarboard"] as Vector3).y > 0.1 and (roll["DeceleronUpperPort"] as Vector3).y < -0.1 \
		and absf((roll["ElevatorStarboard"] as Vector3).y) < 0.001 \
		and (pitch["ElevatorStarboard"] as Vector3).y > 0.1 and (pitch["ElevatorPort"] as Vector3).y > 0.1 \
		and absf((pitch["DeceleronUpperStarboard"] as Vector3).y) < 0.001 \
		and (yaw["RudderStarboard"] as Vector3).x > 0.1 and (yaw["RudderPort"] as Vector3).x > 0.1 \
		and absf((yaw["ElevatorStarboard"] as Vector3).y) < 0.001 \
		and (flaps["FlapInnerStarboard"] as Vector3).y < -0.1 and (flaps["FlapOuterPort"] as Vector3).y < -0.1 \
		and absf((flaps["DeceleronUpperStarboard"] as Vector3).y) < 0.001
	var back := true
	for part in parts:
		back = back and _trailing(frame, part).distance_to(rest[part]) < 0.001
	_check("the_hinged_surfaces_move_the_right_way_and_come_back", ok and back,
		"roll: ailerons %+.2f / %+.2f; pitch: elevators %+.2f / %+.2f; yaw: rudders %+.2f / %+.2f; flaps %+.2f / %+.2f; back at zero %s"
			% [(roll["DeceleronUpperStarboard"] as Vector3).y, (roll["DeceleronUpperPort"] as Vector3).y,
				(pitch["ElevatorStarboard"] as Vector3).y, (pitch["ElevatorPort"] as Vector3).y,
				(yaw["RudderStarboard"] as Vector3).x, (yaw["RudderPort"] as Vector3).x,
				(flaps["FlapInnerStarboard"] as Vector3).y, (flaps["FlapOuterPort"] as Vector3).y, back])


## THE DECELERONS: the speed brake opens each aileron's upper half UP and its lower half DOWN, on both wings alike, by
## the same amount; and with a roll held, the brake opens about the rolled aileron, so both halves on the rising side
## end up higher than on the falling side.
func _the_decelerons_split_open_and_ride_the_roll(frame: WarthogAirframe) -> void:
	_rest(frame)
	var halves: Array = ["DeceleronUpperStarboard", "DeceleronLowerStarboard", "DeceleronUpperPort", "DeceleronLowerPort"]
	var rest: Dictionary = {}
	for part in halves:
		rest[part] = _trailing(frame, part)
	frame.set_speedbrake(1.0)
	var open: Dictionary = {}
	for part in halves:
		open[part] = (_trailing(frame, part) - (rest[part] as Vector3)).y
	var gap_s: float = _trailing(frame, "DeceleronUpperStarboard").y - _trailing(frame, "DeceleronLowerStarboard").y
	frame.set_ailerons(0.5)
	var rolled_s: float = (_trailing(frame, "DeceleronUpperStarboard") + _trailing(frame, "DeceleronLowerStarboard")).y * 0.5
	var rolled_p: float = (_trailing(frame, "DeceleronUpperPort") + _trailing(frame, "DeceleronLowerPort")).y * 0.5
	var gap_rolled: float = _trailing(frame, "DeceleronUpperStarboard").y - _trailing(frame, "DeceleronLowerStarboard").y
	_rest(frame)
	var ok: bool = float(open["DeceleronUpperStarboard"]) > 0.3 and float(open["DeceleronLowerStarboard"]) < -0.3 \
		and float(open["DeceleronUpperPort"]) > 0.3 and float(open["DeceleronLowerPort"]) < -0.3 \
		and absf(float(open["DeceleronUpperStarboard"]) + float(open["DeceleronLowerStarboard"])) < 0.02 \
		and absf(gap_rolled - gap_s) < 0.06 and rolled_s - rolled_p > 0.3
	_check("the_decelerons_split_open_and_ride_the_roll", ok,
		"brake open: upper %+.2f / lower %+.2f starboard, %+.2f / %+.2f port, the split %.2f m; with half right roll the split is %.2f m and the right pair's middle stands %.2f m over the left's"
			% [open["DeceleronUpperStarboard"], open["DeceleronLowerStarboard"], open["DeceleronUpperPort"],
				open["DeceleronLowerPort"], gap_s, gap_rolled, rolled_s - rolled_p])


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
					print("[warthog] wound in %s at %s" % [drawn.name, (points[i] + points[i + 1] + points[i + 2]) / 3.0])
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
		"the whole WarthogAirframe subtree: %d triangles, %d draw surfaces, %d materials, %d distance-culled"
			% [triangles, draws, materials.size(), culled])


## THE MOVING PARTS AS A VERTEX ANIMATION TEXTURE, held to the parts it was baked from TO A MILLIMETRE. A `VatCasting` is
## poured from a second airframe with the airframe's own `features()`, and every vertex of the moving parts is played by
## the CPU copy of the shader (`VatCasting.played_point`) at amounts OFF THE GRID (`vat`'s lesson: a check at a row reads
## 0.00000 m whatever the row count), against where the parts draw it -- with a roll and the speed brake at once, since
## the deceleron halves ride both.
func _the_vat_draws_the_moving_parts_where_the_parts_are(parts: WarthogAirframe) -> void:
	var cast := WarthogAirframe.new()
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
	for a in [0.137, 0.613, 0.853]:
		var amounts: Dictionary = {"gear": a, "pitch": 1.7 * a - 0.9, "roll": 0.9 - 1.9 * a, "rudder": a - 0.41,
			"flaps": 1.0 - a, "speedbrake": a * 0.93, "gun": a * 0.77}
		parts.set_gear(amounts["gear"])
		parts.set_elevators(amounts["pitch"])
		parts.set_ailerons(amounts["roll"])
		parts.set_rudders(amounts["rudder"])
		parts.set_flaps(amounts["flaps"])
		parts.set_speedbrake(amounts["speedbrake"])
		parts.set_gun(amounts["gun"])
		var wanted: Array = []
		for f in vat.features:
			wanted.append(amounts[String(f["name"])])
		for part in ["MainGearStarboard", "NoseGear", "NoseDoorOuter", "DeceleronUpperPort", "DeceleronLowerStarboard",
				"ElevatorPort", "RudderStarboard", "FlapOuterStarboard", "GunBarrels"]:
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


## THE PILOT SEES OVER THE NOSE, PAST THE COCKPIT: the game's A-10 with its station manned, and from the pilot's eye rays
## every 2.5 degrees from 2.5 to 35 below level and every 5 degrees to 20 either side of ahead, fired once at the airframe
## alone and once at everything the view draws. Every ray the airframe's glass leaves open must stay open with the cockpit
## in it. WHY: the first station was the fighter's, its flight display 0.21 m under the eye and 0.36 m ahead, dead across
## the view over the nose (team-lead, off the pilot's-eye picture); the V-22 had the same fault, and this is its check
## (tests/osprey.gd). AND the pilot sees the face of every screen in the station, a ray to its middle and four corners
## meeting it first, turned to within 60 degrees of the eye: moved out of the view, a screen must not also be moved out
## of reading.
func _the_pilot_sees_over_the_nose_past_the_cockpit() -> void:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, Sim.Kind.WARTHOG)
	view.man([0], 0)
	var airframe: Node = view.find_children("*", "WarthogAirframe", true, false)[0]
	var eye: Vector3 = view.seat_anchor(0).position + Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	var blocked: PackedStringArray = []
	var open: int = 0
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
				blocked.append("%.1f down %+.0f: %s" % [down, yaw, with_cockpit])
	_check("the_pilot_sees_over_the_nose_past_the_cockpit", blocked.is_empty() and open >= 60,
		"%d rays the glass leaves open from the eye, %s" % [open, "every one still open with the cockpit in"
			if blocked.is_empty() else "blocked by the cockpit: " + ", ".join(blocked.slice(0, 6))])
	var hidden: PackedStringArray = []
	var screens: int = 0
	var anchor: Node3D = view.seat_anchor(0)
	for found in anchor.find_children("*", "TouchPanel", true, false):
		var screen := found as TouchPanel
		screens += 1
		var own: Dictionary = {}
		for mesh in screen.find_children("*", "MeshInstance3D", true, false):
			own[String(mesh.name)] = true
		var into: Transform3D = view.global_transform.affine_inverse() * screen.global_transform
		var turned: float = rad_to_deg(acos(clampf(into.basis.z.normalized().dot((eye - into.origin).normalized()), -1.0, 1.0)))
		if turned > 60.0:
			hidden.append("%s turned %.0f degrees from the eye" % [screen.get_parent().name, turned])
		for corner in [Vector2.ZERO, Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
			var at: Vector3 = into * Vector3(corner.x * screen.size.x, corner.y * screen.size.y, 0.0)
			var hit: String = _first_hit_in(view, eye, (at - eye).normalized(), null)
			if not own.has(hit.get_slice("/", hit.get_slice_count("/") - 2)):
				hidden.append("%s at %s: %s" % [screen.get_parent().name, corner, hit])
	_check("and_sees_the_face_of_every_screen_in_the_station", hidden.is_empty() and screens >= 1,
		"%d screens, %s" % [screens, "every one on its glass, facing the eye" if hidden.is_empty()
			else "hidden: " + ", ".join(hidden.slice(0, 6))])
	# AND BELOW THE GLASS HE SEES THE COAMING, NOT INTO THE NOSE: from the eye, every 5 degrees from level to 50 below and
	# to 15 either side, the first thing met is the glass (and the world through it), the coaming, or the cockpit -- never
	# the fuselage's own skin, which from the eye is the inside of the hollow nose, and never a gun. And the view draws one
	# gun, the airframe's. WHY: the canopy is one closed solid with the nose, and 20 degrees under the eye looked past the
	# windscreen's foot into it, where the fighter's six-barrel stand-in was drawn beside the GAU-8 (team-lead, 2026-09-19).
	var into_nose: PackedStringArray = []
	var cockpit: Dictionary = {}
	for mesh in anchor.find_children("*", "MeshInstance3D", true, false):
		cockpit[String(mesh.name) if not String(mesh.name).begins_with("@") else String(view.get_path_to(mesh))] = true
	for step in range(0, 11):
		for yaw in [-15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 15.0]:
			var ray: Vector3 = (Vector3.FORWARD.rotated(Vector3.RIGHT, -deg_to_rad(5.0 * step))).rotated(Vector3.UP,
				deg_to_rad(yaw))
			var met: String = _first_hit_in(view, eye, ray, null)
			if met == "Fuselage/1" or met == "nothing" or met.begins_with("Coaming/") 					or cockpit.has(met.substr(0, met.rfind("/"))):
				continue
			into_nose.append("%d down %+.0f: %s" % [5 * step, yaw, met])
	var guns: int = view.find_children("NoseGun", "", true, false).size()
	_check("and_sees_the_coaming_and_not_into_the_nose", into_nose.is_empty() and guns == 0,
		"77 rays from the eye, %s; %d stand-in guns drawn beside the GAU-8" % ["every one on the glass, the coaming or the cockpit"
			if into_nose.is_empty() else "into the nose: " + ", ".join(into_nose.slice(0, 8)), guns])
	# AND EVERY CONTROL HE REACHES FOR, AND EVERY SCREEN, IS INSIDE THE DRAWN SKIN AND SEEN AGAINST IT: its grip (or a
	# screen's middle) inside the fuselage and its canopy by ray parity, and the line from the eye on through it meets the
	# aeroplane's opaque skin first, never the glass -- a control drawn against the sky is a control on nothing. WHY: the
	# seat authored no master arm, so the station fitted its generic one at a fighter's glareshield, 0.30 m outboard and
	# 0.07 m under the eye. It was inside the A-10's bubble, so parity alone passed it, but nothing was under it, and the
	# pilot's-eye picture showed it standing in the sky over the hills (team-lead, 2026-09-19).
	var tris: Array = _skin(airframe)
	var into_frame: Transform3D = (airframe as Node3D).global_transform.affine_inverse()
	var out_of_skin: PackedStringArray = []
	var fitted: int = 0
	for found in anchor.find_children("*", "", true, false):
		var at: Vector3
		if found is VehicleControl:
			at = (found as VehicleControl).global_transform * (found as VehicleControl)._grab_point()
		elif found is TouchPanel:
			at = (found as Node3D).global_position
		else:
			continue
		fitted += 1
		var local: Vector3 = into_frame * at + Vector3(0.0007, 0.0, 0.0007)
		var eye_in_frame: Vector3 = into_frame * (view.global_transform * eye)
		var behind: String = _first_hit(airframe as Node3D, local, (local - eye_in_frame).normalized())
		var inside: bool = _inside_of(tris, local)
		if not inside or behind == "Fuselage/1" or behind == "nothing":
			var from_eye: Vector3 = (view.global_transform.affine_inverse() * at) - eye
			out_of_skin.append("%s %s from the eye, %s, seen against %s" % [found.name,
				from_eye.snapped(Vector3.ONE * 0.01), "inside" if inside else "OUTSIDE the skin", behind])
	_check("and_every_control_and_screen_he_reaches_is_inside_the_canopy", out_of_skin.is_empty() and fitted >= 8,
		"%d controls and screens, %s" % [fitted, "every one inside the drawn skin and seen against it"
			if out_of_skin.is_empty() else "wrong: " + ", ".join(out_of_skin)])
	view.queue_free()


## The first mesh and surface a ray meets among everything a view draws (or only what `within` draws), as
## "Name/surface", in the view's frame. tests/osprey.gd's: indexed meshes read through their index.
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
					# AN UNNAMED MESH IS NAMED BY WHERE IT HANGS, so a blocker can be found.
					name_of = ("%s/%d" % [mesh.name, surface]) if not String(mesh.name).begins_with("@") 						else "%s/%d" % [view.get_path_to(mesh), surface]
	return name_of


# ---------------------------------------------------------------------------------------------------------------------

func _rest(frame: WarthogAirframe) -> void:
	frame.set_gear(1.0)
	frame.set_ailerons(0.0)
	frame.set_elevators(0.0)
	frame.set_rudders(0.0)
	frame.set_flaps(0.0)
	frame.set_speedbrake(0.0)
	frame.set_gun(0.0)


## THE DRAWN MUZZLES: the middle of each barrel's black bore on its muzzle face -- a hexagon fanned from the barrel's own
## axis, so the middle of its distinct vertices is the axis -- grouped by bore. A bore's vertices are within 27 mm of each
## other and two bores' 39 mm apart at their nearest, so a 30 mm test cannot mix them.
func _muzzles(frame: WarthogAirframe) -> Array:
	var mesh := frame.find_child("GunBarrels", true, false) as MeshInstance3D
	var pts := _points(frame, mesh)
	var colours: PackedColorArray = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var groups: Array = []
	for i in range(pts.size()):
		if colours[i].v > 0.1:
			continue
		var placed := false
		for g in groups:
			if ((g as Array)[0] as Vector3).distance_to(pts[i]) < 0.03:
				(g as Array).append(pts[i])
				placed = true
				break
		if not placed:
			groups.append([pts[i]])
	var out: Array = []
	for g in groups:
		var unique: Dictionary = {}
		for p in g:
			unique["%.4f %.4f %.4f" % [p.x, p.y, p.z]] = p
		var c := Vector3.ZERO
		for p in unique.values():
			c += p
		out.append(c / float(unique.size()))
	return out


## THE CLUSTER'S AXIS, from the drawn barrels: the line from the mean of the muzzle ends to the mean of the breech ends,
## reversed, read off the gunmetal vertices by their extreme along the craft's length.
func _barrel_axis(frame: WarthogAirframe) -> Vector3:
	var mesh := frame.find_child("GunBarrels", true, false) as MeshInstance3D
	var pts := _points(frame, mesh)
	var colours: PackedColorArray = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var fore: float = INF
	var aft: float = -INF
	for i in range(pts.size()):
		if _gunmetal(colours[i]):
			fore = minf(fore, pts[i].z)
			aft = maxf(aft, pts[i].z)
	var front := Vector3.ZERO
	var back := Vector3.ZERO
	var nf: int = 0
	var nb: int = 0
	for i in range(pts.size()):
		if not _gunmetal(colours[i]):
			continue
		if pts[i].z < fore + 0.01:
			front += pts[i]
			nf += 1
		elif pts[i].z > aft - 0.01:
			back += pts[i]
			nb += 1
	return (front / float(nf) - back / float(nb)).normalized()


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


func _surface_points(frame: Node3D, mesh: MeshInstance3D, surface: int) -> PackedVector3Array:
	var into := frame.global_transform.affine_inverse() * mesh.global_transform
	var out := PackedVector3Array()
	for p in (mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		out.append(into * p)
	return out


## A barrel's colour, read back from a mesh whose colours are stored at eight bits a channel.
static func _gunmetal(c: Color) -> bool:
	var g: Color = WarthogAirframe.GUNMETAL
	return absf(c.r - g.r) < 0.01 and absf(c.g - g.g) < 0.01 and absf(c.b - g.b) < 0.01


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
