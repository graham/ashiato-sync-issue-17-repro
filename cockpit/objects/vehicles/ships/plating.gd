@tool
extends RefCounted
class_name Plating
## STEEL PLATE, CUT AND WELDED: the few shapes every ship here is drawn from, appended into one `SurfaceTool` with the
## colour in the vertices.
##
## A ship is hundreds of pieces -- a deck, an island, radar faces, catapult rails, wires, a painted 78 -- and each as a
## node of its own is a draw call of its own: the old carrier deck's fourteen centreline stripes were fourteen. Welded
## into one mesh with one material they are one draw call, and a ship's detail costs triangles, which a headset has to
## spare, rather than draw calls, which it does not.
##
## `BoxMesh` through `append_from`, which `HullSkin` uses, carries no vertex colour, so these are wound by hand. GODOT'S
## FRONT FACES ARE CLOCKWISE AS SEEN, and every face here is listed clockwise from outside and given its own normal, so a
## plate is flat-shaded and visible from the side it faces. `tests/ship_models.gd` counts faces that point inwards.

## The six faces of a box as corner signs, each clockwise seen from outside, with its outward normal.
const _FACES: Array = [
	[Vector3(0, 1, 0), [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
	[Vector3(0, -1, 0), [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, -1, -1)]],
	[Vector3(1, 0, 0), [Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1)]],
	[Vector3(-1, 0, 0), [Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(-1, -1, 1), Vector3(-1, -1, -1)]],
	[Vector3(0, 0, 1), [Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, -1, 1), Vector3(-1, -1, 1)]],
	[Vector3(0, 0, -1), [Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, -1), Vector3(1, -1, -1)]],
]


## A BOX, centred at `at`, `size` across, turned by `turn`.
static func box(tool: SurfaceTool, at: Vector3, size: Vector3, tint: Color, turn: Basis = Basis.IDENTITY) -> void:
	var half: Vector3 = size * 0.5
	tool.set_color(tint)
	for face in _FACES:
		var corners: Array[Vector3] = []
		for sign in face[1]:
			corners.append(at + turn * ((sign as Vector3) * half))
		_quad(tool, corners, turn * (face[0] as Vector3))


## A BOX STOOD ON THE DECK between two plan points: a rail, a wire, a sill. `from` and `to` are (x, z); it is `wide`
## across and runs from `bottom` to `top`.
static func bar(tool: SurfaceTool, from: Vector2, to: Vector2, wide: float, bottom: float, top: float,
		tint: Color) -> void:
	var run: Vector2 = to - from
	var length: float = run.length()
	if length <= 0.0001:
		return
	# The yaw that sends the box's -Z along the run: Basis(UP, yaw) sends -Z to (-sin yaw, 0, -cos yaw).
	var yaw: float = atan2(-run.x, -run.y)
	var middle: Vector2 = (from + to) * 0.5
	box(tool, Vector3(middle.x, (bottom + top) * 0.5, middle.y), Vector3(wide, top - bottom, length), tint,
		Basis(Vector3.UP, yaw))


## A FLAT PATCH OF PAINT lying on a deck at height `y`: any convex outline in plan, facing up.
static func paint(tool: SurfaceTool, outline: PackedVector2Array, y: float, tint: Color) -> void:
	if outline.size() < 3:
		return
	var ring: PackedVector2Array = upward(outline)
	tool.set_color(tint)
	for i in range(1, ring.size() - 1):
		tool.set_normal(Vector3.UP)
		tool.add_vertex(Vector3(ring[0].x, y, ring[0].y))
		tool.set_normal(Vector3.UP)
		tool.add_vertex(Vector3(ring[i].x, y, ring[i].y))
		tool.set_normal(Vector3.UP)
		tool.add_vertex(Vector3(ring[i + 1].x, y, ring[i + 1].y))


## A PAINTED LINE on a deck, from one plan point to another, `wide` across.
static func line(tool: SurfaceTool, from: Vector2, to: Vector2, wide: float, y: float, tint: Color) -> void:
	var run: Vector2 = to - from
	if run.length() <= 0.0001:
		return
	var across: Vector2 = Vector2(-run.y, run.x).normalized() * wide * 0.5
	paint(tool, PackedVector2Array([from - across, to - across, to + across, from + across]), y, tint)


## A DASHED LINE: `on` metres painted, `off` metres not, from `from` to `to`.
static func dashes(tool: SurfaceTool, from: Vector2, to: Vector2, wide: float, on: float, off: float, y: float,
		tint: Color) -> void:
	var length: float = from.distance_to(to)
	var way: Vector2 = (to - from) / maxf(length, 0.0001)
	var at: float = 0.0
	while at < length:
		line(tool, from + way * at, from + way * minf(at + on, length), wide, y, tint)
		at += on + off


## A BAND ROUND A BOX IN PLAN, from `low` to `high`, a hand's breadth proud of its four walls: a row of windows on a
## deckhouse, which every ship above the waterline has and which is what makes a white block read as a deck of cabins.
## `inset` is how far in from the corners the band stops, so the corners stay steel.
static func band(tool: SurfaceTool, r: Rect2, low: float, high: float, tint: Color, inset: float = 1.0) -> void:
	var off: float = 0.03
	var x0: float = r.position.x - off
	var x1: float = r.end.x + off
	var z0: float = r.position.y - off
	var z1: float = r.end.y + off
	facing(tool, [Vector3(x0 + inset, high, z0), Vector3(x1 - inset, high, z0), Vector3(x1 - inset, low, z0),
		Vector3(x0 + inset, low, z0)], Vector3.FORWARD, tint)
	facing(tool, [Vector3(x0 + inset, high, z1), Vector3(x1 - inset, high, z1), Vector3(x1 - inset, low, z1),
		Vector3(x0 + inset, low, z1)], Vector3.BACK, tint)
	for x in [x0, x1]:
		facing(tool, [Vector3(x, high, z0 + inset), Vector3(x, high, z1 - inset), Vector3(x, low, z1 - inset),
			Vector3(x, low, z0 + inset)], Vector3(signf(x - r.get_center().x), 0.0, 0.0), tint)


## A PRISM: a convex outline at `top` and at `bottom`, and a wall along every edge. What the simulation's parts are.
static func prism(tool: SurfaceTool, outline: PackedVector2Array, bottom: float, top: float, tint: Color,
		underside: bool = true) -> void:
	if outline.size() < 3 or top <= bottom:
		return
	var ring: PackedVector2Array = upward(outline)
	var n: int = ring.size()
	paint(tool, ring, top, tint)
	if underside:
		tool.set_color(tint)
		for i in range(1, n - 1):
			for corner in [ring[0], ring[i + 1], ring[i]]:
				tool.set_normal(Vector3.DOWN)
				tool.add_vertex(Vector3(corner.x, bottom, corner.y))
	tool.set_color(tint)
	for i in range(n):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % n]
		wall(tool, a, b, bottom, top)


## ONE WALL, vertical, from plan point `a` to `b`, facing out of an `upward` ring it is an edge of: its outside is to
## the right of the direction of travel, seen from above.
static func wall(tool: SurfaceTool, a: Vector2, b: Vector2, bottom: float, top: float) -> void:
	var run: Vector2 = b - a
	var out := Vector3(run.y, 0.0, -run.x).normalized()
	_quad(tool, [Vector3(a.x, bottom, a.y), Vector3(b.x, bottom, b.y), Vector3(b.x, top, b.y),
		Vector3(a.x, top, a.y)], out)


## A QUAD, its four corners clockwise as seen from the side `normal` points to.
static func quad(tool: SurfaceTool, corners: Array[Vector3], tint: Color) -> void:
	tool.set_color(tint)
	var normal: Vector3 = (corners[2] - corners[0]).cross(corners[1] - corners[0]).normalized()
	_quad(tool, corners, normal)


## A QUAD WOUND TO FACE `out`, whichever order its corners came in: the order is reversed when its own winding points
## the other way. Degenerate quads -- a stem pulled to a line -- are skipped rather than drawn edge-on. Every quad placed
## by where it faces goes through here: two hangar openings and a band of windows were drawn facing inwards, and invisible,
## before this existed.
static func facing(tool: SurfaceTool, corners: Array, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = ((corners[2] as Vector3) - (corners[0] as Vector3)).cross(
		(corners[1] as Vector3) - (corners[0] as Vector3))
	if normal.length_squared() < 1e-8:
		normal = ((corners[3] as Vector3) - (corners[1] as Vector3)).cross(
			(corners[2] as Vector3) - (corners[1] as Vector3))
		if normal.length_squared() < 1e-8:
			return
	var ordered: Array[Vector3] = []
	for c in corners:
		ordered.append(c)
	if normal.dot(out) < 0.0:
		ordered.reverse()
	quad(tool, ordered, tint)


static func _quad(tool: SurfaceTool, corners: Array, normal: Vector3) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(normal)
		tool.add_vertex(corners[index])


## THE OUTLINE WOUND SO ITS FACE LOOKS UP: a ring whose (x, z) shoelace area is positive is clockwise seen from above,
## because x cross z is -y.
static func upward(outline: PackedVector2Array) -> PackedVector2Array:
	var area: float = 0.0
	var n: int = outline.size()
	for i in range(n):
		area += outline[i].x * outline[(i + 1) % n].y - outline[(i + 1) % n].x * outline[i].y
	if area > 0.0:
		return outline
	var out := PackedVector2Array()
	for i in range(n - 1, -1, -1):
		out.append(outline[i])
	return out


## A finished mesh from a tool that has had shapes appended, or null if nothing was.
static func weld(tool: SurfaceTool) -> ArrayMesh:
	var mesh: ArrayMesh = tool.commit()
	return mesh if mesh.get_surface_count() > 0 else null
