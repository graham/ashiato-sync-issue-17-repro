@tool
extends RefCounted
class_name Launch
## A LAUNCH, UP CLOSE: the boat's own model -- the inflatable tubes a RIB is named for, with an orange band and a grab line,
## an outboard on the transom, a double jockey seat for the helm and the copilot, and an all-round white light on the
## T-top -- on top of what `Superstructure` builds from the parts with an open helm.
##
## Its hull, T-top helm, bench and stern seat are parts in the simulation's shape table (`boat_shape`, a 5.6 m centre-
## console RIB's numbers, step 3 of the carrier lane).
##
## THE TUBES ARE INSIDE THE HULL'S OUTLINE. The research's 2.4 m beam is over the tubes (tube centres at x ±0.95, 0.5 m
## across), and the collided hull is that 2.4 m, so a tube's outer face is the hull's edge. The first draft hung them
## outboard of it, and the boat was drawn 3.4 m wide round a 2.4 m collision. They are drawn and not collided with, because
## a tube is soft.
##
## THE JOCKEY SEAT IS UNDER THE SEATS the simulation places, asked of its seat poses rather than typed beside them, and it
## stands on the hull's top: asked for "the highest thing under it", it stood on the T-top's roof.
##
## NOT HERE YET: the light is drawn and unlit, and there is no wake.

const TUBE := Color(0.20, 0.21, 0.22)
const TUBE_BAND := Color(0.85, 0.40, 0.12)
const ENGINE := Color(0.12, 0.12, 0.13)
const STEEL := Color(0.55, 0.57, 0.60)
const CUSHION := Color(0.30, 0.31, 0.33)
const LAMP := Color(0.95, 0.95, 0.90)

## THE TUBES: 0.5 m across (CONFIRMED for boats this size), their tops about 0.6 m above the water (ESTIMATE).
const TUBE_WIDE: float = 0.5
const TUBE_TOP: float = 0.6
## THE JOCKEY SEAT: its cushion 0.67 m over the floor (the research's 0.60 to 0.70), a hand behind the seat poses and
## reaching a little past each.
const JOCKEY_HIGH: float = 0.55
const JOCKEY_AFT: float = 0.10
const JOCKEY_REACH: float = 0.30


## THE NEAR MODEL: `{"mesh", "panels", "fittings"}` -- `Superstructure`'s from the parts with the launch's fittings in the
## same mesh, the jockey cushion added to the panels the helm's view is checked against, and the box each fitting stands
## on the ship by.
static func build(geometry: Dictionary, helm: String) -> Dictionary:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = geometry.get("parts", []) as Array
	var panels: Array[AABB] = Superstructure.build_into(tool, geometry, helm)
	var fittings: Array[AABB] = []
	var hull: Dictionary = Superstructure.part_of(parts, "hull")
	var console: Dictionary = Superstructure.part_of(parts, "bridge")
	if not hull.is_empty():
		_tubes(tool, hull)
		_outboard(tool, hull)
	_jockey_seat(tool, parts, geometry.get("seat_poses", []) as Array, panels, fittings)
	if not console.is_empty():
		_all_round_light(tool, console, fittings)
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings}


## THE TUBES: along every edge of the hull outline but the transom, each inside the edge with its outer face on it, from
## `TUBE_WIDE` under `TUBE_TOP` to it; an orange band along the outer face and a grab line along the top. Outward is the
## right of the direction of travel round an `upward` ring, as `Plating.wall` has it.
static func _tubes(tool: SurfaceTool, hull: Dictionary) -> void:
	var outline: PackedVector2Array = Plating.upward(hull["outline"])
	var r: Rect2 = Wheelhouse.outline_rect(outline)
	var band: float = TUBE_TOP - TUBE_WIDE * 0.5
	var n: int = outline.size()
	for i in range(n):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		# NOT ACROSS THE TRANSOM, which is where the engine hangs.
		if absf(a.y - r.end.y) < 0.01 and absf(b.y - r.end.y) < 0.01:
			continue
		var out: Vector2 = Vector2(b.y - a.y, -(b.x - a.x)).normalized()
		var middle: Vector2 = -out * TUBE_WIDE * 0.5
		Plating.bar(tool, a + middle, b + middle, TUBE_WIDE, TUBE_TOP - TUBE_WIDE, TUBE_TOP, TUBE)
		Plating.bar(tool, a + out * 0.01, b + out * 0.01, 0.02, band - 0.05, band + 0.05, TUBE_BAND)
		Plating.bar(tool, a + middle, b + middle, 0.03, TUBE_TOP, TUBE_TOP + 0.03, CUSHION)


## THE OUTBOARD on the transom: a cowl above the deck, a leg down into the water and a cavitation plate. It hangs off the
## stern, so it stands on nothing and is not a fitting.
static func _outboard(tool: SurfaceTool, hull: Dictionary) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(hull["outline"])
	var z: float = r.end.y + 0.35
	var deck: float = float(hull["top"])
	Plating.box(tool, Vector3(0.0, deck + 0.35, z), Vector3(0.45, 0.6, 0.55), ENGINE)
	Plating.box(tool, Vector3(0.0, deck - 0.35, z + 0.05), Vector3(0.14, 0.8, 0.2), ENGINE)
	Plating.box(tool, Vector3(0.0, deck - 0.7, z + 0.05), Vector3(0.35, 0.03, 0.35), STEEL)


## THE JOCKEY SEAT the helm and the copilot straddle: a frame on the hull's top under the middle of the seats that fly, and
## a cushion reaching past both.
static func _jockey_seat(tool: SurfaceTool, parts: Array, poses: Array, panels: Array[AABB],
		fittings: Array[AABB]) -> void:
	var least_x: float = INF
	var most_x: float = -INF
	var z: float = 0.0
	var count: int = 0
	for entry in poses:
		if not bool(entry.get("flies", false)):
			continue
		var seat: Vector3 = entry["position"]
		least_x = minf(least_x, seat.x)
		most_x = maxf(most_x, seat.x)
		z += seat.z
		count += 1
	if count == 0:
		return
	var at := Vector2((least_x + most_x) * 0.5, z / float(count) + JOCKEY_AFT)
	var foot: float = Superstructure.top_under(parts, at)
	if is_inf(foot):
		return
	var frame := AABB(Vector3(at.x - 0.15, foot, at.y - 0.15), Vector3(0.3, JOCKEY_HIGH, 0.3))
	var cushion := AABB(Vector3(least_x - JOCKEY_REACH, frame.end.y, at.y - 0.225),
		Vector3(most_x - least_x + JOCKEY_REACH * 2.0, 0.12, 0.45))
	Plating.box(tool, frame.get_center(), frame.size, STEEL)
	Plating.box(tool, cushion.get_center(), cushion.size, CUSHION)
	fittings.append(frame)
	panels.append(cushion)


## THE ALL-ROUND WHITE on a short mast at the back of the T-top roof, which is the console part's top.
static func _all_round_light(tool: SurfaceTool, console: Dictionary, fittings: Array[AABB]) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(console["outline"])
	var roof: float = float(console["top"])
	var mast := AABB(Vector3(r.get_center().x - 0.02, roof, r.end.y - 0.17), Vector3(0.04, 0.6, 0.04))
	Plating.box(tool, mast.get_center(), mast.size, STEEL)
	Plating.box(tool, Vector3(r.get_center().x, mast.end.y + 0.06, r.end.y - 0.15), Vector3(0.1, 0.12, 0.1), LAMP)
	fittings.append(mast)
