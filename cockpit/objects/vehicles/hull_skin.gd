@tool
extends RefCounted
class_name HullSkin
## A FUSELAGE WITH HOLES IN IT, built as flat panels in one mesh.
##
## A hull used to be a single box, and a box cannot be seen out of -- which is why the whole
## airframe was hidden the moment its owner climbed in. Nothing was gained by drawing it and
## everything was lost: no nose against the horizon, no window frame against the wing, and
## nowhere to hang a door or a gear bay.
##
## So the skin is a SET OF PANELS and a window is a panel that is not emitted. There is no
## glass. `cockpit_shell.gd` settled that argument for the cockpit frame -- glass in a game
## reflects, refracts, catches the sun and hides the world, for no gain over an empty gap --
## and this is the same decision applied to the fuselage around it.
##
## ONE MESH, NOT THIRTY NODES. Every panel is appended into a single `ArrayMesh`, so a hull
## with windows is FEWER draw calls than the solid box it replaces, which matters with a
## hundred and sixty craft in the world. The panels are handed back as well: they are plain
## boxes, so "can the pilot see out" is arithmetic rather than a physics query, and the
## tests do it without a running world.
##
## `append_from` rather than hand-wound triangles. A `BoxMesh` already knows its winding,
## its normals, its UVs and its tangents; emitting those by hand is six faces of chances to
## get the winding backwards and find out only when a wall is invisible from one side.

## How thick a panel is. Thin enough to read as skin, thick enough to be a solid with an
## inside and an outside -- which is what lets back-face culling work from both.
const SKIN: float = 0.06


## THE WHOLE SKIN: `{ "mesh": ArrayMesh, "panels": Array[AABB] }`.
##
## `extents` is the half-size of the hull the simulation collides with. `cabin` is the
## greenhouse standing on top of it, in the same frame, or a zero-size box for a craft that
## does not have one. `plan` is the glazing schedule from the catalogue.
static func build(extents: Vector3, cabin: AABB, plan: Dictionary) -> Dictionary:
	var panels: Array[AABB] = _fuselage(extents, cabin)
	panels.append_array(_cabin(cabin, plan))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := BoxMesh.new()
	for panel in panels:
		box.size = panel.size
		tool.append_from(box, 0, Transform3D(Basis.IDENTITY, panel.position + panel.size * 0.5))
	return {"mesh": tool.commit(), "panels": panels}


## THE BODY OF THE AIRCRAFT: belly, two sides, two bulkheads, and a roof with a hole in it
## where the cabin comes through.
##
## Solid, all of it. Everything below the shoulders of a real aeroplane is skin and
## structure, and the windows are all in the greenhouse.
## HOW MANY STEPS THE SHOULDER TAKES, and how long it is.
##
## A fuselage whose crew sit narrower than it is wide has to GET narrower, or the flight
## deck windows open onto the inside of the aeroplane. Three steps over two and a half
## metres reads as a nose from outside and costs six panels.
const SHOULDER_STEPS: int = 3
const SHOULDER: float = 2.6


## THE BODY OF THE AIRCRAFT, in sections along its length.
##
## One section for most craft, because most of them are as wide at the front as at the back.
## An airliner is not: its crew sit within a metre of the centreline and its fuselage is
## 5.2 m across, so a flight deck the width of the hull puts the side sill two metres from
## the pilot's shoulder -- eight degrees of downward view, and no ground at all. A real nose
## TAPERS, and that is the whole of why.
static func _fuselage(extents: Vector3, cabin: AABB) -> Array[AABB]:
	var out: Array[AABB] = []
	var ex: float = extents.x
	var ey: float = extents.y
	var ez: float = extents.z
	var has_cabin: bool = cabin.size.z > 0.0
	var nose_hx: float = cabin.size.x * 0.5 if has_cabin else ex
	var cut_from: float = cabin.position.y if has_cabin else ey
	var aft_of: float = clampf(cabin.position.z + cabin.size.z, -ez, ez) if has_cabin else ez

	# The tail bulkhead, always solid, always full width.
	out.append(_slab(Vector3(-ex, -ey, ez - SKIN), Vector3(ex * 2.0, ey * 2.0, SKIN)))
	# The nose bulkhead, cut down to the cabin floor -- a windscreen with a wall behind it
	# is not a window -- and only as wide as the nose section it caps.
	out.append(_slab(Vector3(-nose_hx, -ey, -ez), Vector3(nose_hx * 2.0, cut_from + ey, SKIN)))

	for section in _sections(extents, nose_hx, aft_of):
		var hx: float = section["hx"]
		var z0: float = section["z0"]
		var z1: float = section["z1"]
		var run: float = z1 - z0
		if run <= 0.0:
			continue
		out.append(_slab(Vector3(-hx, -ey, z0), Vector3(hx * 2.0, SKIN, run)))
		# A section under the cabin is open above the cabin floor -- its sides ARE the
		# cabin's posts and its roof IS the cabin's roof. Everywhere else is closed.
		var under: bool = has_cabin and z1 <= aft_of + 0.001
		var wall: float = (cut_from + ey) if under else (ey * 2.0)
		for side in [-1.0, 1.0]:
			out.append(_slab(Vector3(side * hx - (SKIN if side > 0.0 else 0.0), -ey, z0),
				Vector3(SKIN, wall, run)))
		if not under:
			out.append(_slab(Vector3(-hx, ey - SKIN, z0), Vector3(hx * 2.0, SKIN, run)))
		# WHERE THE SECTION WIDENS, the step is a face. Without it the shoulder is a hole
		# you can see the inside of the aeroplane through.
		var widens: float = float(section.get("widens_to", hx))
		if widens > hx + 0.001:
			for side in [-1.0, 1.0]:
				var inner: float = side * hx if side > 0.0 else side * widens
				out.append(_slab(Vector3(inner, -ey, z1 - SKIN),
					Vector3(widens - hx, ey * 2.0, SKIN)))
	return out


## THE LENGTH OF THE HULL, cut into sections of constant width: the nose the crew sit in,
## a stepped shoulder, and the body. One section when the crew are as wide as the hull.
static func _sections(extents: Vector3, nose_hx: float, aft_of: float) -> Array:
	var ex: float = extents.x
	var ez: float = extents.z
	if nose_hx >= ex - 0.01 or aft_of >= ez - SHOULDER:
		return [{"z0": -ez, "z1": ez, "hx": ex}]
	var out: Array = []
	var step: float = SHOULDER / float(SHOULDER_STEPS)
	var here: float = nose_hx
	out.append({"z0": -ez, "z1": aft_of, "hx": nose_hx,
		"widens_to": nose_hx + (ex - nose_hx) / float(SHOULDER_STEPS)})
	for i in range(SHOULDER_STEPS):
		var next_hx: float = nose_hx + (ex - nose_hx) * float(i + 1) / float(SHOULDER_STEPS)
		var after: float = nose_hx + (ex - nose_hx) * float(i + 2) / float(SHOULDER_STEPS)
		out.append({"z0": aft_of + float(i) * step, "z1": aft_of + float(i + 1) * step,
			"hx": next_hx, "widens_to": minf(after, ex)})
		here = next_hx
	out.append({"z0": aft_of + SHOULDER, "z1": ez, "hx": ex})
	return out


## THE GREENHOUSE, which is where every window is.
##
## A sill along the bottom, a header along the top, a roof over it, and POSTS between the
## openings. The posts are the point: an empty rectangle reads as a missing wall, and the
## same rectangle divided by two uprights reads as a cabin you are sitting in. They are also
## what a real pilot judges bank against.
##
## The front is left open across its whole width -- a windscreen is one pane, and the thing
## that would divide it is exactly what you do not want in the middle of your view.
static func _cabin(cabin: AABB, plan: Dictionary) -> Array[AABB]:
	var out: Array[AABB] = []
	if cabin.size.z <= 0.0 or plan.is_empty():
		return out
	var post: float = float(plan.get("post", 0.14))
	var sill: float = float(plan.get("sill", 0.16))
	var header: float = float(plan.get("header", 0.14))
	var openings: int = maxi(int(plan.get("sides", 2)), 1)
	var low: float = cabin.position.y
	var high: float = cabin.position.y + cabin.size.y

	for side in [-1.0, 1.0]:
		var x: float = cabin.position.x if side < 0.0 else cabin.position.x + cabin.size.x - post
		# Sill and header, the full length of the cabin.
		out.append(_slab(Vector3(x, low, cabin.position.z), Vector3(post, sill, cabin.size.z)))
		out.append(_slab(Vector3(x, high - header, cabin.position.z),
			Vector3(post, header, cabin.size.z)))
		# THE POSTS, ONE PER OPENING, at the BACK of each -- and none at all at the front.
		#
		# The front corner of the cabin is the nose of the aircraft, and what belongs there
		# is the windscreen wrapping round it, not a pillar. With one there, a pilot looking
		# thirty degrees off the nose in the airliner was looking straight at it: they sit
		# 3.4 m aft of the glass, and at thirty degrees that lands exactly on the corner.
		# It is also what a windscreen looks like -- the post you can see is beside your
		# shoulder, not in front of your face.
		var glazed: float = high - header - (low + sill)
		var span: float = (cabin.size.z - float(openings + 1) * post) / float(openings)
		if span <= 0.0 or glazed <= 0.0:
			continue
		for i in range(1, openings + 1):
			out.append(_slab(
				Vector3(x, low + sill, cabin.position.z + float(i) * (span + post)),
				Vector3(post, glazed, post)))

	# The roof over the cabin, unless this kind is glazed overhead -- a helicopter is, and
	# looking up through it at the disc is most of what flying one looks like.
	if not bool(plan.get("roof_open", false)):
		out.append(_slab(Vector3(cabin.position.x, high - header, cabin.position.z),
			Vector3(cabin.size.x, header, cabin.size.z)))
	# The aft wall. The front is the windscreen and gets nothing at all.
	out.append(_slab(Vector3(cabin.position.x, low, cabin.position.z + cabin.size.z - post),
		Vector3(cabin.size.x, high - low, post)))
	return out


static func _slab(at: Vector3, size: Vector3) -> AABB:
	return AABB(at, size)


## IS THIS DIRECTION CLEAR, from a point inside the hull?
##
## A slab test against every panel, which is all a panel is. Used by the tests to ask the
## only question that matters about a window -- whether the pilot can see through it -- and
## it needs no physics, no world and no frame to have been drawn.
static func is_clear(panels: Array, from: Vector3, direction: Vector3, reach: float) -> bool:
	var way: Vector3 = direction.normalized()
	for panel in panels:
		if _hits(panel as AABB, from, way, reach):
			return false
	return true


static func _hits(box: AABB, from: Vector3, way: Vector3, reach: float) -> bool:
	var near: float = 0.0
	var far: float = reach
	var low: Vector3 = box.position
	var high: Vector3 = box.position + box.size
	for axis in range(3):
		if absf(way[axis]) < 1e-9:
			if from[axis] < low[axis] or from[axis] > high[axis]:
				return false
			continue
		var one: float = (low[axis] - from[axis]) / way[axis]
		var two: float = (high[axis] - from[axis]) / way[axis]
		near = maxf(near, minf(one, two))
		far = minf(far, maxf(one, two))
		if near > far:
			return false
	return true
