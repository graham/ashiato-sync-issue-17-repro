@tool
extends RefCounted
class_name Submarine
## A VIRGINIA-CLASS SUBMARINE, NEAR: a round black hull, a sail with its fillet, a bridge well on top, retractable bow
## planes, a cruciform stern and a pump-jet shroud, welded into one vertex-coloured mesh.
##
## THE PARTS ARE THE AUTHORITY, AS THEY ARE FOR THE CARRIER. Length, beam, keel, deck, the sail's place and height and the
## bridge's room all come from `kind_geometry`'s parts; a size that is in none of them belongs to a fitting and says
## where it came from. The fact sheet is `research-submarine.md` in godotgames-drafts/2026-09-15/cockpit-fleet; tags in
## brackets are its sources, MEASURED means taken off the Commons profile drawing D1 (scale-checked to 0.9 % on L/D).
##
## A SUBMARINE IS ROUND, which is why this does not use `HullLoft`: that lofts a ship's lines, flat-bottomed, flared, with
## a red boot-top at the waterline. A Virginia in service shows no red at all (photos P1, P4, P5) and its section is a
## circle 10.36 m across [S1][S3], so the skin is rings about the hull's axis.

const BLACK := Color(0.055, 0.058, 0.062)
## A faint seam every few stations: the anechoic coating reads as panels in photographs P1 and P5.
const SEAM := Color(0.085, 0.088, 0.092)
const WELL := Color(0.02, 0.02, 0.02)
const WHITE := Color(0.86, 0.86, 0.82)
const RAIL := Color(0.60, 0.62, 0.64)

## Twenty sides to a ring and eighty stations stem to stern: a round hull 115 m long reads as round from the bridge.
const RING: int = 20
const STATIONS: int = 80

## THE HULL'S LINES, MEASURED on D1: full diameter from about 60 ft aft of the bow tip to about 100 ft forward of the aft
## tip; the stern cone comes down to about 10 ft across at the control surfaces.
const BOW_FULL_AT: float = 18.3
const STERN_FULL_TO: float = 30.5
const CONE_END_RADIUS: float = 1.52
## THE PUMP-JET SHROUD, MEASURED on D1, low confidence: about 5.7 m across and 4.0 m long at the very end.
const SHROUD_RADIUS: float = 2.85
const SHROUD_WALL: float = 0.30
const SHROUD_LENGTH: float = 4.0
## THE CRUCIFORM STERN [S9][S26], MEASURED on D1: the upper rudder's tip 7.3 m above the axis, the lower's 5.5 m below,
## about 2.7 m of chord, standing 8.5 to 11.6 m forward of the aft tip. How far the stern planes reach is not measured:
## ESTIMATE, the mean of the two rudders.
const RUDDER_UP: float = 7.3
const RUDDER_DOWN: float = 5.5
const PLANE_OUT: float = 6.4
const FIN_CHORD: float = 2.7
const FIN_THICK: float = 0.35
const FINS_AFT_OF_CENTRE: float = 10.05
## THE BOW PLANES, retractable on the hull [S24][S25], MEASURED on D1: centred 16.7 m aft of the bow tip and 1.5 m above
## the axis, 2.7 m of root chord. Their span is not published, so they are drawn housed: a panel line on the hull side.
const BOW_PLANE_AFT: float = 16.7
const BOW_PLANE_UP: float = 1.5
const BOW_PLANE_CHORD: float = 2.7
## THE SAIL'S FILLET, MEASURED on D1: 1.4 m high a foot forward of the leading edge, 0.7 m at 1.2 m, 0.24 m at 2.3 m.
## The fillet toe is the island part's forward end, so the vertical leading edge is `FILLET_RUN` aft of it.
const FILLET_RUN: float = 2.3
const FILLET: Array = [[2.3, 0.24], [1.2, 0.7], [0.3, 1.4]]
## A domed top [D1, P1, P2]: a shallow second tier, inset.
const DOME_INSET: float = 0.25
const DOME_RISE: float = 0.18
## THE BRIDGE'S RAILS, rigged on the surface only: stanchions "about waist height" (photo P3) to the watch, who stands on a
## grating 0.1 m under the sail top. So 0.77 m over the rim is 0.87 m over their feet. ESTIMATE.
## - The first pictures had them at 1.0 m over a rim 0.39 m under the eye: a doorway, with the casing hidden.
## - At 0.9 m, ship_models' "deck ahead" line from the seated eye crossed the forward rail 2 cm under its top (carrier step
##   4a), seen only by a raised head. At 0.77 m it clears by 8 cm.
const RAIL_HIGH: float = 0.77
const RAIL_BAR: float = 0.05
const FLAGSTAFF_HIGH: float = 2.4
## DRAUGHT MARKS: a column of white numerals forward of the sail and on the upper rudder (D1, P4, P5). Drawn as ticks a
## foot high every two feet, which is how draught marks are spaced.
const MARK_STEP: float = 0.61
const MARK_HIGH: float = 0.15
const MARK_WIDE: float = 0.45
const MARKS_AHEAD_OF_SAIL: float = 3.0


## THE MODEL: `{"mesh": ArrayMesh, "panels": Array[AABB]}`, or {} for a geometry with no hull part. `panels` are what a
## seated head must keep clear of: the sail, and the bridge's rails.
## `helm` is the catalogue's ("well"), as `ShipHull.models` hands every ship's own builder since carrier step 4a.
## `fittings` is the box each fitting stands on the ship by, which tests/ship_models.gd holds to the part under it.
## The hull's appendages -- bow planes, rudders, stern planes, shroud -- and its painted marks are the hull, not fittings
## standing on a top, and are not reported, as the patrol boat does not report its rub strake.
static func build(geometry: Dictionary, helm: String = "well") -> Dictionary:
	var hull: Dictionary = span_of(geometry, "hull")
	if hull.is_empty():
		return {}
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var panels: Array[AABB] = []
	var fittings: Array[AABB] = []
	var parts: Array = geometry.get("parts", []) as Array
	_hull(tool, hull)
	var sail: Dictionary = span_of(geometry, "island")
	if not sail.is_empty():
		_sail(tool, sail, panels)
		_marks_ahead_of(tool, hull, float(sail["z_bow"]) + FILLET_RUN - MARKS_AHEAD_OF_SAIL,
			float(geometry.get("waterline", 0.0)))
	var bridge: Dictionary = span_of(geometry, "bridge")
	if not bridge.is_empty():
		# The RIM is the sail's top, not the bridge part's: the part is the room a seated watch occupies, which starts at
		# its grating a little under the rim and rises above it.
		_bridge(tool, parts, bridge, float(sail["top"]) if not sail.is_empty() else float(bridge["bottom"]), panels,
			fittings)
		_masts(tool, parts, bridge, panels, fittings)
	_bow_planes(tool, hull)
	_stern(tool, hull)
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings}


## WHERE A ROLE'S PARTS REACH: `{bottom, top, z_bow, z_stern, half}` over every part with that role, or {} with none.
static func span_of(geometry: Dictionary, role: String) -> Dictionary:
	var found: Dictionary = {}
	for part in geometry.get("parts", []) as Array:
		if String(part.get("part", "")) != role:
			continue
		var outline: PackedVector2Array = part.get("outline", PackedVector2Array()) as PackedVector2Array
		if found.is_empty():
			found = {"bottom": INF, "top": -INF, "z_bow": INF, "z_stern": -INF, "half": 0.0}
		found["bottom"] = minf(found["bottom"], float(part.get("bottom", 0.0)))
		found["top"] = maxf(found["top"], float(part.get("top", 0.0)))
		for p in outline:
			found["z_bow"] = minf(found["z_bow"], p.y)
			found["z_stern"] = maxf(found["z_stern"], p.y)
			found["half"] = maxf(found["half"], absf(p.x))
	return found


## THE HULL'S RADIUS at `z`: an ellipsoidal bow, the parallel middle body, a smooth cone aft and the hub inside the shroud.
static func radius_at(hull: Dictionary, z: float) -> float:
	var full: float = (float(hull["top"]) - float(hull["bottom"])) * 0.5
	var from_bow: float = z - float(hull["z_bow"])
	var to_tail: float = float(hull["z_stern"]) - z
	if from_bow < BOW_FULL_AT:
		var u: float = 1.0 - clampf(from_bow / BOW_FULL_AT, 0.0, 1.0)
		return full * sqrt(maxf(1.0 - u * u, 0.0))
	if to_tail < SHROUD_LENGTH:
		return CONE_END_RADIUS * clampf(to_tail / SHROUD_LENGTH, 0.0, 1.0)
	if to_tail < STERN_FULL_TO:
		var v: float = clampf((STERN_FULL_TO - to_tail) / (STERN_FULL_TO - SHROUD_LENGTH), 0.0, 1.0)
		return lerpf(full, CONE_END_RADIUS, v * v * (3.0 - 2.0 * v))
	return full


static func axis_y(hull: Dictionary) -> float:
	return (float(hull["top"]) + float(hull["bottom"])) * 0.5


static func _hull(tool: SurfaceTool, hull: Dictionary) -> void:
	var y0: float = axis_y(hull)
	var z_bow: float = float(hull["z_bow"])
	var z_stern: float = float(hull["z_stern"])
	for s in range(STATIONS):
		var za: float = lerpf(z_bow, z_stern, float(s) / STATIONS)
		var zb: float = lerpf(z_bow, z_stern, float(s + 1) / STATIONS)
		var ra: float = radius_at(hull, za)
		var rb: float = radius_at(hull, zb)
		var tint: Color = SEAM if s % 6 == 0 else BLACK
		for k in range(RING):
			var a0: float = TAU * float(k) / RING
			var a1: float = TAU * float(k + 1) / RING
			var mid: float = (a0 + a1) * 0.5
			Plating.facing(tool, [
				Vector3(ra * sin(a0), y0 + ra * cos(a0), za), Vector3(ra * sin(a1), y0 + ra * cos(a1), za),
				Vector3(rb * sin(a1), y0 + rb * cos(a1), zb), Vector3(rb * sin(a0), y0 + rb * cos(a0), zb)],
				Vector3(sin(mid), cos(mid), 0.0), tint)


## THE SAIL: a rounded leading edge, near-parallel sides and a vertical trailing edge, with a domed top and the fillet at
## its forward base. It stands on the hull's crown, which is the island part's bottom.
static func _sail(tool: SurfaceTool, sail: Dictionary, panels: Array[AABB]) -> void:
	var half: float = float(sail["half"])
	var face: float = float(sail["z_bow"]) + FILLET_RUN
	var aft: float = float(sail["z_stern"])
	var bottom: float = float(sail["bottom"])
	var top: float = float(sail["top"]) - DOME_RISE
	Plating.prism(tool, _sail_plan(half, face, aft), bottom, top, BLACK)
	Plating.prism(tool, _sail_plan(half - DOME_INSET, face + DOME_INSET, aft - DOME_INSET), top, top + DOME_RISE, BLACK)
	# THE FILLET IN FINE STEPS along the measured profile: three slabs, one per measured point, read as a staircase in the
	# first pictures. Ten, each as high as the profile where it starts, read as a fairing at any distance that matters.
	const STEPS := 10
	for i in range(STEPS):
		var ahead: float = FILLET_RUN * float(i + 1) / STEPS
		Plating.prism(tool, _sail_plan(half * 0.9, face - ahead, face + half), bottom - 0.4,
			bottom + fillet_height(ahead - FILLET_RUN / STEPS), BLACK, false)
	panels.append(AABB(Vector3(-half, bottom, face), Vector3(half * 2.0, top + DOME_RISE - bottom, aft - face)))


## THE FILLET'S HEIGHT `ahead` metres forward of the sail's face, straight between the measured points and down to the
## deck at `FILLET_RUN`. At the face itself it is the first measured height.
static func fillet_height(ahead: float) -> float:
	var points: Array = [[0.0, float(FILLET[2][1])], [float(FILLET[2][0]), float(FILLET[2][1])],
		[float(FILLET[1][0]), float(FILLET[1][1])], [float(FILLET[0][0]), float(FILLET[0][1])], [FILLET_RUN + 0.05, 0.0]]
	for i in range(points.size() - 1):
		var a: Array = points[i]
		var b: Array = points[i + 1]
		if ahead <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((ahead - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0))
	return 0.0


## The sail in plan: a half-circle nose of the sail's half-width, then sides tapering to 0.85 of it at the trailing edge.
static func _sail_plan(half: float, face: float, aft: float) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for i in range(9):
		var a: float = PI * float(i) / 8.0
		ring.append(Vector2(-half * cos(a), face + half - half * sin(a)))
	ring.append(Vector2(half * 0.85, aft))
	ring.append(Vector2(-half * 0.85, aft))
	return ring


## THE BRIDGE: its well dark in the sail top, stanchions and a rail round it, and a flagstaff at its after edge.
static func _bridge(tool: SurfaceTool, parts: Array, bridge: Dictionary, rim: float, panels: Array[AABB],
		fittings: Array[AABB]) -> void:
	var half: float = float(bridge["half"])
	var fore: float = float(bridge["z_bow"])
	var aft: float = float(bridge["z_stern"])
	# THE WELL HAS A FLOOR where the watch stands, at the bridge part's bottom, and dark walls up to the rim. ship_models
	# wants an upward face under every flying seat within 35 cm of its floor (carrier, df73a529); a dark patch painted on
	# the rim, which this drew first, is 10 cm ABOVE the seats.
	var grating: float = float(bridge["bottom"])
	var plan := PackedVector2Array([Vector2(-half, fore), Vector2(half, fore), Vector2(half, aft), Vector2(-half, aft)])
	Plating.paint(tool, plan, grating, WELL)
	for i in range(4):
		var a: Vector2 = plan[i]
		var b: Vector2 = plan[(i + 1) % 4]
		var inward := Vector3(-(a.x + b.x) * 0.5, 0.0, -((a.y + b.y) * 0.5 - (fore + aft) * 0.5))
		Plating.facing(tool, [Vector3(a.x, grating, a.y), Vector3(b.x, grating, b.y), Vector3(b.x, rim, b.y),
			Vector3(a.x, rim, a.y)], inward, WELL)
	# THE RAIL: a post at each corner and a rail between.
	# - Each post stands on the rim box under it (`Superstructure.top_under`), set 3 cm outboard of the well's edge so
	#   it stands on that box and not on the line between two parts. It is reported as a fitting.
	# - Each rail is a thin panel of its own. One box over the whole well would block lines that pass over the rails.
	var corners: Array[Vector2] = [Vector2(-half - 0.03, fore - 0.03), Vector2(half + 0.03, fore - 0.03),
		Vector2(half + 0.03, aft + 0.03), Vector2(-half - 0.03, aft + 0.03)]
	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var foot: float = Superstructure.top_under(parts, a)
		if foot == -INF:
			foot = rim
		var post := AABB(Vector3(a.x - RAIL_BAR * 0.5, foot, a.y - RAIL_BAR * 0.5), Vector3(RAIL_BAR, RAIL_HIGH, RAIL_BAR))
		Plating.box(tool, post.get_center(), post.size, RAIL)
		fittings.append(post)
		panels.append(post)
		Plating.bar(tool, a, b, RAIL_BAR, rim + RAIL_HIGH - RAIL_BAR, rim + RAIL_HIGH, RAIL)
		panels.append(AABB(Vector3(minf(a.x, b.x) - RAIL_BAR * 0.5, rim + RAIL_HIGH - RAIL_BAR, minf(a.y, b.y) - RAIL_BAR * 0.5),
			Vector3(absf(b.x - a.x) + RAIL_BAR, RAIL_BAR, absf(b.y - a.y) + RAIL_BAR)))
	# THE FLAGSTAFF, a hand aft of the well, on the rim box there.
	var staff_at := Vector2(0.0, aft + 0.1)
	var staff := AABB(Vector3(-RAIL_BAR * 0.5, Superstructure.top_under(parts, staff_at), staff_at.y - RAIL_BAR * 0.5),
		Vector3(RAIL_BAR, FLAGSTAFF_HIGH, RAIL_BAR))
	Plating.box(tool, staff.get_center(), staff.size, RAIL)
	fittings.append(staff)
	panels.append(staff)


## THE MASTS, RAISED ON THE SURFACE: two AN/BVS-1 photonics masts and a Universal Modular Mast [S4][S33][S32]. They
## telescope, and none goes through the pressure hull.
## - HEIGHT: MEASURED at 5 to 7 m above the sail (drawing D1, photo P2), low confidence. The photonics masts are drawn at
##   the low end, 5 m; the modular mast is an ESTIMATE, 4.2 m.
## - PLACE: aft of the watch. Photos P1, P2 and P5 show the watch at the sail's forward end, with the raised masts just
##   aft of them.
## - SECTIONS: ESTIMATES.
## Each row is [x, metres aft of the well, section, height]. A Virginia has NO sail planes [S22][S23]: its diving planes
## are on the hull.
const MASTS: Array = [[-0.35, 1.6, 0.45, 5.0], [0.35, 1.6, 0.45, 5.0], [0.0, 3.0, 0.30, 4.2]]
const MAST_HEAD := Vector3(0.6, 0.5, 0.6)


## THE MASTS, each standing on the sail top under it (`Superstructure.top_under`), with a sensor head on each photonics
## mast. They are reported as fittings, and as panels for the watch's view and head checks.
static func _masts(tool: SurfaceTool, parts: Array, bridge: Dictionary, panels: Array[AABB], fittings: Array[AABB]) -> void:
	var well_aft: float = float(bridge["z_stern"])
	for mast in MASTS:
		var at := Vector2(float(mast[0]), well_aft + float(mast[1]))
		var foot: float = Superstructure.top_under(parts, at)
		if foot == -INF:
			continue
		var side: float = float(mast[2])
		var body := AABB(Vector3(at.x - side * 0.5, foot, at.y - side * 0.5), Vector3(side, float(mast[3]), side))
		Plating.box(tool, body.get_center(), body.size, BLACK)
		fittings.append(body)
		panels.append(body)
		if side > 0.4:
			var head := AABB(Vector3(at.x - MAST_HEAD.x * 0.5, body.end.y, at.y - MAST_HEAD.z * 0.5), MAST_HEAD)
			Plating.box(tool, head.get_center(), head.size, SEAM)
			panels.append(head)


static func _bow_planes(tool: SurfaceTool, hull: Dictionary) -> void:
	var z: float = float(hull["z_bow"]) + BOW_PLANE_AFT
	var r: float = radius_at(hull, z)
	var y: float = axis_y(hull) + BOW_PLANE_UP
	var x: float = sqrt(maxf(r * r - BOW_PLANE_UP * BOW_PLANE_UP, 0.0)) + 0.02
	for side in [1.0, -1.0]:
		Plating.box(tool, Vector3(side * x, y, z), Vector3(0.06, 0.30, BOW_PLANE_CHORD), SEAM)


## THE CRUCIFORM STERN and the shroud behind it.
static func _stern(tool: SurfaceTool, hull: Dictionary) -> void:
	var y0: float = axis_y(hull)
	var tail: float = float(hull["z_stern"])
	var z: float = tail - FINS_AFT_OF_CENTRE
	var r: float = radius_at(hull, z)
	Plating.box(tool, Vector3(0.0, y0 + (r + RUDDER_UP) * 0.5, z), Vector3(FIN_THICK, RUDDER_UP - r, FIN_CHORD), BLACK)
	Plating.box(tool, Vector3(0.0, y0 - (r + RUDDER_DOWN) * 0.5, z), Vector3(FIN_THICK, RUDDER_DOWN - r, FIN_CHORD), BLACK)
	for side in [1.0, -1.0]:
		Plating.box(tool, Vector3(side * (r + PLANE_OUT) * 0.5, y0, z), Vector3(PLANE_OUT - r, FIN_THICK, FIN_CHORD), BLACK)
	# Draught ticks on both faces of the upper rudder, from where the rudder leaves the hull to its tip.
	var y: float = y0 + r + MARK_STEP
	while y < y0 + RUDDER_UP - MARK_HIGH:
		for side in [1.0, -1.0]:
			Plating.box(tool, Vector3(side * (FIN_THICK * 0.5 + 0.01), y, z + FIN_CHORD * 0.25),
				Vector3(0.01, MARK_HIGH, MARK_WIDE), WHITE)
		y += MARK_STEP
	var front: float = tail - SHROUD_LENGTH
	var inner: float = SHROUD_RADIUS - SHROUD_WALL
	for k in range(RING):
		var a0: float = TAU * float(k) / RING
		var a1: float = TAU * float(k + 1) / RING
		var mid: float = (a0 + a1) * 0.5
		var out := Vector3(sin(mid), cos(mid), 0.0)
		for pair in [[SHROUD_RADIUS, 1.0], [inner, -1.0]]:
			var rad: float = float(pair[0])
			Plating.facing(tool, [
				Vector3(rad * sin(a0), y0 + rad * cos(a0), front), Vector3(rad * sin(a1), y0 + rad * cos(a1), front),
				Vector3(rad * sin(a1), y0 + rad * cos(a1), tail), Vector3(rad * sin(a0), y0 + rad * cos(a0), tail)],
				out * float(pair[1]), BLACK)
		for end in [[front, -1.0], [tail, 1.0]]:
			var ze: float = float(end[0])
			Plating.facing(tool, [
				Vector3(inner * sin(a0), y0 + inner * cos(a0), ze), Vector3(SHROUD_RADIUS * sin(a0), y0 + SHROUD_RADIUS * cos(a0), ze),
				Vector3(SHROUD_RADIUS * sin(a1), y0 + SHROUD_RADIUS * cos(a1), ze), Vector3(inner * sin(a1), y0 + inner * cos(a1), ze)],
				Vector3(0.0, 0.0, float(end[1])), BLACK)


## THE DRAUGHT MARKS forward of the sail, from the design waterline up to the crown, on both sides of the hull. The
## waterline is the geometry's (`waterline`), never a typed 0: the sea moves under it (ocean C1's wind waves), and the
## marks are painted on the hull where the design puts the sea. Passed in, not kept in a static: a static set at the end
## of `build` was read by the marks drawn before it, which the first version of this did.
static func _marks_ahead_of(tool: SurfaceTool, hull: Dictionary, z: float, waterline: float) -> void:
	var y0: float = axis_y(hull)
	var r: float = radius_at(hull, z)
	var y: float = waterline
	while y < y0 + r - MARK_HIGH:
		var lift: float = y - y0
		var x: float = sqrt(maxf(r * r - lift * lift, 0.0)) + 0.01
		for side in [1.0, -1.0]:
			Plating.box(tool, Vector3(side * x, y, z), Vector3(0.01, MARK_HIGH, MARK_WIDE), WHITE)
		y += MARK_STEP
