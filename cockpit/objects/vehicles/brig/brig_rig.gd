extends Node3D
class_name BrigRig
## A BRIG, DRAWN: a black hull with an ochre strake, two masts, yards that turn, sails that fill, and a black flag.
##
## THE SAILS DRAWN ARE THE SAILS SIMULATED. Where each sail group's force acts, how big the group is and how far its
## yard or boom can come round are the simulation's rig table (`kind_geometry(kind)["rig"]`), so a sail plan retuned in
## C++ is redrawn with no edit here, and a yard a picture shows at an angle is a yard the physics pushed at that angle.
## What is typed here is only what the physics has never heard of: how a square group's area splits into a course and a
## topsail, the hull's lines, and the colours.
##
## IT ANNOUNCES NOTHING AND ASKS NOTHING. `trim` is handed the ship's replicated rigging -- the fore and main levers, how
## much sail is set, how full each group is and where the apparent wind comes from -- and draws it. It does not know the
## wind, and on a machine that is only watching it could not: the rigging is what the server says the sails did.
##
## Built in code, like every craft here, so a headless suite can make one with `build` and measure a yard.

const FORE_SQUARE: int = 0
const MAIN_SQUARE: int = 1
const JIB: int = 2
const SPANKER: int = 3

## A SQUARE GROUP IS A COURSE AND A TOPSAIL ABOVE IT. The topsail is 0.8 the course's width and 0.9 its height; with the
## course 1.35 times as wide as it is high, the pair is 2.32 h^2, so h comes from the group's area.
const COURSE_ASPECT: float = 1.35
const TOPSAIL_SCALE := Vector2(0.8, 0.9)
## The jib's foot as a share of the bowsprit-to-mast run, and the spanker's foot and head as shares of its height.
const JIB_FOOT: float = 0.55
const SPANKER_FOOT: float = 0.95
const SPANKER_HEAD: float = 0.62

const HULL_BLACK := Color(0.07, 0.065, 0.06)
const STRAKE := Color(0.58, 0.43, 0.15)
const COPPER := Color(0.36, 0.21, 0.13)
const DECK := Color(0.42, 0.33, 0.22)
const SPAR := Color(0.24, 0.17, 0.10)
const CANVAS := Color(0.86, 0.82, 0.72)
const FLAG := Color(0.03, 0.03, 0.03)
const SAIL_SHADER: Shader = preload("res://objects/vehicles/brig/sail.gdshader")
## The mainmast's radius at the deck, which the square sails hang forward of. The foremast is a little thinner.
const MAST_RADIUS: float = 0.4

## One pivot per sail group, turned by `trim`: the yards on a mast turn together, and so do their sails.
var _pivots: Array[Node3D] = []
var _sails: Array[GeometryInstance3D] = []
var _group_of: Array[int] = []
var _groups: Array = []
var _flag_pole: Node3D = null
var _flag: MeshInstance3D = null


## `rig` is the simulation's {sails: [{area, position, square, closest, furthest}...], waterline} for this kind.
static func build(rig: Dictionary, extents: Vector3) -> BrigRig:
	var brig := BrigRig.new()
	brig.name = "Brig"
	brig._groups = rig.get("sails", []) as Array
	brig._build_hull(extents, float(rig.get("waterline", 0.0)))
	if brig._groups.size() >= 4:
		brig._build_rig(extents)
	return brig


## ---- trimming, every frame -------------------------------------------------------------

## THE SAILS AS THE RIGGING SAYS: each group's pivot to the angle its lever sets (the arithmetic of `set_angle_of` in
## sail_plan.hpp), each sail bellied by its group's fill and to leeward, slack sails shivering, and the flag along the
## apparent wind.
func trim(rigging: Dictionary) -> void:
	if _pivots.is_empty():
		return
	var apparent: float = float(rigging.get("apparent_angle", 0.0))
	# Where the air goes relative to the ship, in the body frame (z aft): it comes from `apparent` off the bow, + starboard.
	var flow := Vector3(-sin(apparent), 0.0, cos(apparent))
	var fills: Array = rigging.get("fill", []) as Array
	var set: float = float(rigging.get("set", 0.0))
	for group in range(_pivots.size()):
		var lever: float = float(rigging.get("fore" if group == FORE_SQUARE or group == JIB else "main", 0.0))
		_pivots[group].rotation.y = spar_turn(_groups[group] as Dictionary, lever)
	var to_body: Basis = global_transform.basis.inverse()
	for i in range(_sails.size()):
		var group: int = _group_of[i]
		var sail := _sails[i]
		var full: float = absf(float(fills[group])) if group < fills.size() else 0.0
		var normal: Vector3 = to_body * sail.global_transform.basis.z
		normal.y = 0.0
		sail.set_instance_shader_parameter("fill", full * set)
		sail.set_instance_shader_parameter("leeward", 1.0 if normal.dot(flow) >= 0.0 else -1.0)
		sail.set_instance_shader_parameter("luff", clampf(1.0 - full / 0.25, 0.0, 1.0))
		sail.visible = set > 0.01
	if _flag_pole != null:
		_flag_pole.rotation.y = atan2(-flow.z, flow.x)
		_flag.set_instance_shader_parameter("luff",
			clampf(float(rigging.get("apparent_speed", 0.0)) / 8.0, 0.2, 1.0))


## HOW FAR A YARD OR BOOM IS TURNED about its mast, for a lever. The line runs aft to leeward at the set angle off the
## centreline -- (side sin a, cos a) in the body's (x, z) -- and a spar built along +X turns by atan2(-z, x) to lie on it.
static func spar_turn(group: Dictionary, lever: float) -> float:
	var closest: float = float(group.get("closest", 0.78))
	var furthest: float = float(group.get("furthest", PI * 0.5))
	var angle: float = furthest - clampf(absf(lever), 0.0, 1.0) * (furthest - closest)
	var side: float = -1.0 if lever < 0.0 else 1.0
	return atan2(-cos(angle), side * sin(angle))


## For the tests: which way a group's spar lies, flat, in the body frame.
func spar_direction(group: int) -> Vector3:
	var along: Vector3 = _pivots[group].transform.basis.x
	return Vector3(along.x, 0.0, along.z).normalized()


## ---- the hull -------------------------------------------------------------------------

## THE HULL, LOFTED: stations from a fine bow to a transom, each a section from keel to rail. Each band between two
## heights is its own colour with no blend across the line, because a waterline that fades is not a waterline: copper
## below the sea, a black boot-top across it, black topsides, an ochre strake along the gunports.
func _build_hull(extents: Vector3, waterline: float) -> void:
	var stations: int = 14
	# THE BOOT-TOP REACHES WELL EITHER SIDE OF THE WATERLINE, from 0.7 below it to 0.6 above: the PLAIN sea is flat while the
	# hull heaves on the simulated swell (+-0.76 m), and a copper band showing its top edge above flat water read as a
	# ship hovering (team-lead, the first waterline picture), with the hull measured 0.49 m into that water.
	var heights := PackedFloat32Array([0.0, waterline - 0.7, waterline + 0.6, extents.y - 1.5, extents.y - 0.8, 0.0])
	var colours := [COPPER, HULL_BLACK, HULL_BLACK, STRAKE, HULL_BLACK]
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for s in range(stations):
		for band in range(colours.size()):
			for side in [-1.0, 1.0]:
				var a := _hull_point(float(s) / stations, band, heights, extents, side)
				var b := _hull_point(float(s + 1) / stations, band, heights, extents, side)
				var c := _hull_point(float(s + 1) / stations, band + 1, heights, extents, side)
				var d := _hull_point(float(s) / stations, band + 1, heights, extents, side)
				_quad(verts, cols, a, b, c, d, colours[band], side > 0.0)
	# The transom, closing the stern between the two sides.
	for band in range(colours.size()):
		var a := _hull_point(1.0, band, heights, extents, -1.0)
		var b := _hull_point(1.0, band, heights, extents, 1.0)
		var c := _hull_point(1.0, band + 1, heights, extents, 1.0)
		var d := _hull_point(1.0, band + 1, heights, extents, -1.0)
		_quad(verts, cols, a, b, c, d, colours[band], true)
	add_child(_coloured("Hull", verts, cols))
	# THE DECK, a metre under the rail, planked colour.
	var deck_verts := PackedVector3Array()
	var deck_cols := PackedColorArray()
	for s in range(stations):
		var t0: float = float(s) / stations
		var t1: float = float(s + 1) / stations
		var y0: float = _sheer(t0, extents) - 1.0
		var y1: float = _sheer(t1, extents) - 1.0
		var w0: float = _beam(t0, extents) * 0.95
		var w1: float = _beam(t1, extents) * 0.95
		_quad(deck_verts, deck_cols, Vector3(-w0, y0, _z(t0, extents)), Vector3(w0, y0, _z(t0, extents)),
			Vector3(w1, y1, _z(t1, extents)), Vector3(-w1, y1, _z(t1, extents)), DECK, false)
	add_child(_coloured("Deck", deck_verts, deck_cols))
	# GUNPORTS, six a side on the strake: the chequer that says "warship" from a mile off.
	var port := BoxMesh.new()
	port.size = Vector3(0.12, 0.5, 0.7)
	var black := _flat(HULL_BLACK)
	for side in [-1.0, 1.0]:
		for i in range(6):
			var t: float = 0.22 + 0.11 * i
			var gun := MeshInstance3D.new()
			gun.name = "GunPort%s%d" % ["Port" if side < 0.0 else "Starboard", i + 1]
			gun.mesh = port
			gun.material_override = black
			gun.position = Vector3(side * (_beam(t, extents) + 0.04), extents.y - 1.15, _z(t, extents))
			add_child(gun)
	# THE RUDDER, hung on the sternpost, most of it under the sea.
	var rudder := MeshInstance3D.new()
	rudder.name = "Rudder"
	var blade := BoxMesh.new()
	blade.size = Vector3(0.25, extents.y * 1.6, 1.4)
	rudder.mesh = blade
	rudder.material_override = _flat(COPPER)
	rudder.position = Vector3(0.0, -extents.y * 0.25, extents.z + 0.7)
	add_child(rudder)


## Where the hull's rail is along its length: rising towards both ends, and a raised quarterdeck aft.
static func _sheer(t: float, extents: Vector3) -> float:
	var ends: float = (t - 0.45) * 2.0
	return extents.y + 0.55 * ends * ends + (0.6 if t > 0.78 else 0.0)


## Half the beam at a station: fine at the bow, full amidships, and a transom 0.7 as wide.
static func _beam(t: float, extents: Vector3) -> float:
	if t < 0.35:
		return extents.x * maxf(sin(PI * 0.5 * t / 0.35), 0.04)
	var aft: float = (t - 0.35) / 0.65
	return extents.x * lerpf(1.0, 0.7, aft * aft)


## Along the hull: the bow at -z, the transom at +z.
static func _z(t: float, extents: Vector3) -> float:
	return -extents.z + 2.0 * extents.z * t


## A point on one side at a station, at one of the band heights (the last is the rail). Narrower towards the keel.
static func _hull_point(t: float, band: int, heights: PackedFloat32Array, extents: Vector3, side: float) -> Vector3:
	var keel: float = -extents.y * (lerpf(0.35, 1.0, t / 0.15) if t < 0.15 else 1.0)
	var rail: float = _sheer(t, extents)
	var y: float = rail if band >= heights.size() - 1 else maxf(heights[band], keel) if band > 0 else keel
	y = clampf(y, keel, rail)
	var up: float = clampf((y - keel) / maxf(rail - keel, 0.01), 0.0, 1.0)
	var width: float = _beam(t, extents) * sqrt(clampf(up * 1.6, 0.0, 1.0)) * (1.0 - 0.05 * up)
	return Vector3(side * width, y, _z(t, extents))


static func _quad(verts: PackedVector3Array, cols: PackedColorArray, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, colour: Color, flip: bool) -> void:
	var order: Array = [a, c, b, a, d, c] if flip else [a, b, c, a, c, d]
	for p in order:
		verts.append(p)
		cols.append(colour)


func _coloured(named: String, verts: PackedVector3Array, cols: PackedColorArray) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(verts.size()):
		st.set_color(cols[i])
		st.add_vertex(verts[i])
	st.generate_normals()
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.8
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.name = named
	node.mesh = st.commit()
	node.material_override = paint
	return node


static func _flat(colour: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = 0.8
	return paint


## ---- the rig --------------------------------------------------------------------------

func _build_rig(extents: Vector3) -> void:
	var wood := _flat(SPAR)
	var fore: Dictionary = _groups[FORE_SQUARE]
	var main: Dictionary = _groups[MAIN_SQUARE]
	var fore_top: float = _build_square(FORE_SQUARE, fore, extents, wood)
	var main_top: float = _build_square(MAIN_SQUARE, main, extents, wood)
	_mast((fore["position"] as Vector3).z, extents.y - 1.0, fore_top + 2.5, 0.35, wood)
	_mast((main["position"] as Vector3).z, extents.y - 1.0, main_top + 3.0, 0.4, wood)
	# THE BOWSPRIT, out and up over the bow, carrying the jib's tack at its end.
	var sprit_root := Vector3(0.0, _sheer(0.02, extents), -extents.z)
	var sprit_dir := Vector3(0.0, sin(0.26), -cos(0.26))
	var sprit_len: float = maxf(absf((_groups[JIB]["position"] as Vector3).z) - extents.z, 4.0) * 2.0
	var tack: Vector3 = sprit_root + sprit_dir * sprit_len
	_spar_between(sprit_root, tack, 0.28, wood)
	_build_jib(tack, Vector3(0.0, fore_top, (fore["position"] as Vector3).z), wood)
	_build_spanker(main, extents, main_top, wood)
	_build_flag(Vector3(0.0, main_top + 3.0, (main["position"] as Vector3).z))


## A course and a topsail on one pivot at the course's yard, sized so their area is the group's and their centre of
## effort is at the group's height. Returns the height of the topsail's yard, for the mast.
func _build_square(group: int, sail: Dictionary, extents: Vector3, wood: Material) -> float:
	var area: float = float(sail.get("area", 200.0))
	var centre: Vector3 = sail.get("position", Vector3.ZERO)
	var h: float = sqrt(area / (COURSE_ASPECT * (1.0 + TOPSAIL_SCALE.x * TOPSAIL_SCALE.y)))
	var course := Vector2(COURSE_ASPECT * h, h)
	var topsail := Vector2(course.x * TOPSAIL_SCALE.x, h * TOPSAIL_SCALE.y)
	var a_course: float = course.x * course.y
	var a_top: float = topsail.x * topsail.y
	# The course's yard height that puts the pair's area-weighted centre at the simulation's centre of effort.
	var yard: float = centre.y + (a_course * course.y * 0.5 - a_top * topsail.y * 0.5) / (a_course + a_top)
	var pivot := Node3D.new()
	pivot.name = "Pivot%d" % group
	pivot.position = Vector3(0.0, yard, centre.z)
	add_child(pivot)
	_pivots.append(pivot)
	# FORWARD OF THE MAST, as a square sail hangs: the yard across the front of the mast and the canvas ahead of it. Hung
	# on the mast's own axis, a sail bellying aft went through the mast, and its seam speckled in the first pictures.
	var ahead: float = -(MAST_RADIUS + 0.15)
	_sail_sheet(pivot, group, Rect2(-course.x * 0.5, -course.y, course.x, course.y), false, 1.0, ahead)
	_sail_sheet(pivot, group, Rect2(-topsail.x * 0.5, 0.0, topsail.x, topsail.y), false, 1.0, ahead)
	_spar_on(pivot, Vector3(-course.x * 0.55, 0.0, ahead + 0.1), Vector3(course.x * 0.55, 0.0, ahead + 0.1), 0.18, wood)
	_spar_on(pivot, Vector3(-topsail.x * 0.55, topsail.y, ahead + 0.1), Vector3(topsail.x * 0.55, topsail.y, ahead + 0.1), 0.14, wood)
	return yard + topsail.y


## THE JIB: a triangle whose luff is the forestay, from the bowsprit's end to the foremast head. It swings about that
## stay, so its head and tack never leave it, and the clew goes to leeward.
func _build_jib(tack: Vector3, head: Vector3, wood: Material) -> void:
	_spar_between(tack, head, 0.05, wood)
	var stay: Vector3 = (head - tack).normalized()
	var hinge := Node3D.new()
	hinge.name = "JibStay"
	hinge.position = tack
	# Local Y along the stay, X roughly aft: the swing about Y is then about the stay.
	var x_axis: Vector3 = Vector3(0.0, 0.0, 1.0) - stay * stay.z
	hinge.basis = Basis(x_axis.normalized(), stay, x_axis.normalized().cross(stay))
	add_child(hinge)
	var swing := Node3D.new()
	swing.name = "Pivot%d" % JIB
	hinge.add_child(swing)
	_pivots.append(swing)
	var luff: float = tack.distance_to(head)
	_sail_sheet(swing, JIB, Rect2(0.0, 0.0, luff * JIB_FOOT, luff), true)


## THE SPANKER: a gaff sail abaft the mainmast, hinged on the mast, its foot on a boom that swings to leeward.
func _build_spanker(main: Dictionary, extents: Vector3, main_top: float, wood: Material) -> void:
	var spanker: Dictionary = _groups[SPANKER]
	var area: float = float(spanker.get("area", 80.0))
	var boom_y: float = extents.y + 1.8
	var height: float = maxf((float((spanker["position"] as Vector3).y) - boom_y) * 2.0, 4.0)
	var foot: float = area / (height * (SPANKER_FOOT + SPANKER_HEAD) * 0.5)
	var pivot := Node3D.new()
	pivot.name = "Pivot%d" % SPANKER
	pivot.position = Vector3(0.0, boom_y, (main["position"] as Vector3).z + 0.5)
	add_child(pivot)
	_pivots.append(pivot)
	_sail_sheet(pivot, SPANKER, Rect2(0.0, 0.0, foot, height), false, SPANKER_HEAD / SPANKER_FOOT)
	_spar_on(pivot, Vector3.ZERO, Vector3(foot * 1.05, 0.0, 0.0), 0.14, wood)
	_spar_on(pivot, Vector3(0.0, height, 0.0), Vector3(foot * SPANKER_HEAD, height + 0.8, 0.0), 0.12, wood)


func _build_flag(at: Vector3) -> void:
	_flag_pole = Node3D.new()
	_flag_pole.name = "FlagPole"
	_flag_pole.position = at
	add_child(_flag_pole)
	_flag = MeshInstance3D.new()
	_flag.name = "Flag"
	_flag.mesh = _grid(Rect2(0.0, -2.0, 3.0, 2.0), false, 10, 6)
	var cloth := ShaderMaterial.new()
	cloth.shader = SAIL_SHADER
	cloth.set_shader_parameter("canvas", Vector3(FLAG.r, FLAG.g, FLAG.b))
	cloth.set_shader_parameter("depth", 0.0)
	cloth.set_shader_parameter("flag", true)
	_flag.material_override = cloth
	_flag_pole.add_child(_flag)


## A sail as a grid in the pivot's XY plane, facing +Z, u along X and v from the head down. `triangle` narrows it to a
## point at the head (a jib).
func _sail_sheet(pivot: Node3D, group: int, rect: Rect2, triangle: bool, head_share: float = 1.0,
		ahead: float = 0.0) -> MeshInstance3D:
	var sheet := MeshInstance3D.new()
	sheet.name = "Sail%d_%d" % [group, _sails.size()]
	sheet.position = Vector3(0.0, 0.0, ahead)
	sheet.mesh = _grid(rect, triangle, 8, 8, head_share)
	var canvas := ShaderMaterial.new()
	canvas.shader = SAIL_SHADER
	canvas.set_shader_parameter("canvas", Vector3(CANVAS.r, CANVAS.g, CANVAS.b))
	# A DEEPER BELLY THAN FIRST DRAWN, a seventh of the sail's width: at a ninth, from astern, a full square sail read as a
	# flat white slab. And the sheet's size, for the normal the belly bends.
	canvas.set_shader_parameter("depth", rect.size.x * 0.14)
	canvas.set_shader_parameter("sheet_size", rect.size)
	# A square sail hung forward of its mast lies against the mast when pressed aft; see `mast_notch` in sail.gdshader.
	canvas.set_shader_parameter("mast_notch", 1.0 if ahead != 0.0 else 0.0)
	sheet.material_override = canvas
	# NO SHADOW FROM A SAIL. The belly is a vertex push on a double-sided sheet, and the shadow pass drew it back onto its
	# own canvas as jagged dark patches (the first dusk picture). A sail's shadow on the deck is not worth that, or its cost.
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(sheet)
	_sails.append(sheet)
	_group_of.append(group)
	return sheet


## `head_share` narrows the head to that share of the foot (a gaff sail).
static func _grid(rect: Rect2, triangle: bool, across: int, down: int, head_share: float = 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array = []
	for j in range(down + 1):
		var row: Array = []
		var v: float = float(j) / down
		for i in range(across + 1):
			var u: float = float(i) / across
			# Head at the top edge (y = rect end) and foot at y = rect start; a triangle's head is its luff's top.
			var width_share: float = v if triangle else lerpf(head_share, 1.0, v)
			var x: float = rect.position.x + rect.size.x * u * width_share
			var y: float = rect.position.y + rect.size.y * (1.0 - v)
			row.append([Vector3(x, y, 0.0), Vector2(u, v)])
		corners.append(row)
	for j in range(down):
		for i in range(across):
			for pick in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
				var corner: Array = corners[j + pick[1]][i + pick[0]]
				st.set_uv(corner[1])
				st.set_normal(Vector3(0.0, 0.0, 1.0))
				st.add_vertex(corner[0])
	return st.commit()


func _mast(z: float, from_y: float, to_y: float, radius: float, wood: Material) -> void:
	_spar_between(Vector3(0.0, from_y, z), Vector3(0.0, to_y, z), radius, wood)


func _spar_between(a: Vector3, b: Vector3, radius: float, wood: Material) -> void:
	_spar_on(self, a, b, radius, wood)


static func _spar_on(parent: Node3D, a: Vector3, b: Vector3, radius: float, wood: Material) -> void:
	var spar := MeshInstance3D.new()
	# NUMBERED OFF THE PARENT IT IS ABOUT TO JOIN, because every mast and yard on this ship is
	# built by this one static helper and "Spar" would leave Godot to number all but the first.
	spar.name = "Spar%d" % (parent.get_child_count() + 1)
	var pole := CylinderMesh.new()
	pole.top_radius = radius * 0.7
	pole.bottom_radius = radius
	pole.height = a.distance_to(b)
	pole.radial_segments = 8
	spar.mesh = pole
	spar.material_override = wood
	var along: Vector3 = (b - a).normalized()
	var side: Vector3 = Vector3.RIGHT if absf(along.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x_axis: Vector3 = side.cross(along).normalized()
	spar.transform = Transform3D(Basis(x_axis, along, x_axis.cross(along)), (a + b) * 0.5)
	parent.add_child(spar)
