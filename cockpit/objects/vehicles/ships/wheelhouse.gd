@tool
extends RefCounted
class_name Wheelhouse
## THE ROOM ROUND A HELM: a floor, a sill, windows with posts between them, a header and a roof, built round a ship's
## `bridge` part.
##
## Every boat here used to seat its crew on the deck, on a chair with nothing round it -- the carrier's pilot on the
## flight deck beside the island, the battleship's in the open on the forecastle, the patrol boat's on the hull roof. A
## ship is conned from a BRIDGE, high up and behind glass, and the view from it is what the job is: the bow ahead, the
## deck below, the sea round it. So the helm is placed in a `bridge` part in the simulation's shape table (`seat_in`),
## and this draws the room that part is, from the same numbers. A seat and the room round it cannot disagree because
## there is only one room.
##
## NO GLASS, which `cockpit_shell.gd` and `HullSkin` settled for aircraft and which holds here: a window is a gap between
## posts. The panels are handed back as boxes, so "can the helm see the bow" and "does anything touch the head" are
## arithmetic (`HullSkin.is_clear`), with no world running.

## Where the glazing runs, measured from the floor. The sill is below a seated eye (`CockpitStation.EYE_HEIGHT`, 1.35) by
## enough to see the deck ahead of the bow, and the header is above a standing one.
const SILL: float = 0.95
const HEADER: float = 2.35
## How thick a wall is, how wide a window post, and the most glass between two posts.
const WALL: float = 0.14
## A POST IS A MULLION, 7 cm along the glass and as deep as the wall. The first version built it with `_strip`, which gives
## every strip at least a wall's thickness BOTH ways, and from the carrier's helm, 1.2 m behind the glass, a 14 cm post was
## seven degrees of pillar in front of the bow (tests/ship_shot.gd, 2026-09-15).
const POST: float = 0.07
const PANE: float = 1.5


## THE ROOM, appended to `tool`, and its panels as boxes in the ship's frame. `part` is a `bridge` part from
## `kind_geometry`; `glazed` names the sides with windows, of "fore", "aft", "port" and "starboard". A side that is not
## glazed is solid from floor to roof.
static func build(tool: SurfaceTool, part: Dictionary, glazed: Array, paint: Color, trim: Color) -> Array[AABB]:
	var r: Rect2 = outline_rect(part.get("outline", PackedVector2Array()) as PackedVector2Array)
	var floor_at: float = float(part.get("bottom", 0.0))
	var top: float = float(part.get("top", floor_at + 3.0))
	var panels: Array[AABB] = []
	# THE HEADER FITS THE ROOM. A patrol boat's wheelhouse is 2 m floor to roof, and a header at the fixed 2.35 m stood above
	# the roof's underside: a strip of negative height, which a box draws inside out -- 24 of the gunboat's faces wound
	# against their normal (tests/ship_models.gd, 2026-09-15) -- and posts through the roof. So the glazing stops 10 cm under
	# the roof in a low room, and never below a hand's width over the sill.
	var header: float = clampf(top - 0.25 - 0.10 - floor_at, SILL + 0.30, HEADER)
	# The floor under the helm and the roof over it.
	panels.append(AABB(Vector3(r.position.x, floor_at - 0.2, r.position.y), Vector3(r.size.x, 0.2, r.size.y)))
	panels.append(AABB(Vector3(r.position.x, top - 0.25, r.position.y), Vector3(r.size.x, 0.25, r.size.y)))
	# THE SIDES, each a strip of wall along one edge of the outline: (from, to) in plan, and which way is out.
	var sides: Dictionary = {
		"fore": [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(0.0, -1.0)],
		"aft": [Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(0.0, 1.0)],
		"port": [Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Vector2(-1.0, 0.0)],
		"starboard": [Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(1.0, 0.0)],
	}
	for side in sides:
		var from: Vector2 = sides[side][0]
		var to: Vector2 = sides[side][1]
		var out: Vector2 = sides[side][2]
		# The wall stands INSIDE the outline, its outer face on the outline's edge.
		var inset: Vector2 = -out * WALL * 0.5
		var a: Vector2 = from + inset
		var b: Vector2 = to + inset
		if not (side in glazed):
			panels.append(_strip(a, b, floor_at, top - 0.25))
			continue
		panels.append(_strip(a, b, floor_at, floor_at + SILL))
		panels.append(_strip(a, b, floor_at + header, top - 0.25))
		# POSTS at each end and between the panes, evenly.
		var length: float = a.distance_to(b)
		var panes: int = maxi(int(ceil(length / PANE)), 1)
		var runs_along_x: bool = absf(b.x - a.x) > absf(b.y - a.y)
		var post_size := Vector3(POST if runs_along_x else WALL, header - SILL, WALL if runs_along_x else POST)
		for i in range(panes + 1):
			var at: Vector2 = a.lerp(b, float(i) / float(panes))
			panels.append(AABB(Vector3(at.x - post_size.x * 0.5, floor_at + SILL, at.y - post_size.z * 0.5), post_size))
	# A CHART SHELF along the inside of the front windows at sill height: the thing a bridge has under its glass, and
	# what stops the room reading as a greenhouse.
	if "fore" in glazed:
		panels.append(AABB(Vector3(r.position.x + WALL, floor_at + SILL - 0.06, r.position.y + WALL),
			Vector3(r.size.x - WALL * 2.0, 0.06, 0.35)))
	for panel in panels:
		Plating.box(tool, panel.get_center(), panel.size, trim if panel.size.y < 0.3 else paint)
	return panels


## A WALL STRIP between two plan points, from `bottom` to `top`, as an axis-aligned box: walls here run along x or z.
static func _strip(a: Vector2, b: Vector2, bottom: float, top: float) -> AABB:
	var low := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var high := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	var thick := Vector2(maxf(high.x - low.x, WALL), maxf(high.y - low.y, WALL))
	var centre: Vector2 = (low + high) * 0.5
	return AABB(Vector3(centre.x - thick.x * 0.5, bottom, centre.y - thick.y * 0.5),
		Vector3(thick.x, top - bottom, thick.y))


static func outline_rect(outline: PackedVector2Array) -> Rect2:
	if outline.is_empty():
		return Rect2()
	var r := Rect2(outline[0], Vector2.ZERO)
	for p in outline:
		r = r.expand(p)
	return r
