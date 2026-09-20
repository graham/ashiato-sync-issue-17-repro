@tool
extends RefCounted
class_name PatrolBoat
## A PATROL BOAT, UP CLOSE: the gunboat's own model -- a rub strake down each side, rails round the foredeck, a radar dome,
## two whip antennas and a searchlight on the wheelhouse roof, and an anchor on the bow -- on top of what `Superstructure`
## builds from the parts.
##
## Its hull, wheelhouse, mast and gun tubs are parts in the simulation's shape table (`gunboat_shape`, a US Navy PCF "Swift
## boat"'s lines scaled to 18 m, step 3 of the carrier lane). This adds the fittings that make one read as a patrol boat
## from the water, sized to the boat and collided with by nothing. Whatever stands on the deck stands on the part under it
## (`Superstructure.top_under`); whatever stands on the wheelhouse roof stands on its bridge part's top. The first draft
## put the radar dome over the middle of the roof, which is where the collided radar mast stands, and the mast ran up
## through it.
##
## NOT HERE YET: the twin .50 tub the PCF carried on its wheelhouse roof (the shape has no station there), its navigation
## lights, and a wake.

const HAZE := Color(0.42, 0.46, 0.50)
const DARK := Color(0.16, 0.17, 0.18)
const STEEL := Color(0.32, 0.34, 0.36)
const WHITE := Color(0.88, 0.88, 0.85)

## A RUB STRAKE: a dark band a hand high just under the deck edge, all the way round.
const STRAKE_HIGH: float = 0.18
## RAILS round the foredeck: waist-high, on a post every 1.5 m.
const RAIL_HIGH: float = 0.9
const RAIL_EVERY: float = 1.5
## The radar dome stands this far forward of the roof's middle, clear of the radar mast (`gunboat_shape`'s island part,
## 0.24 m square, 1.1 m aft of the roof's middle).
const DOME_FORWARD: float = 0.75


## THE NEAR MODEL: `{"mesh", "panels", "fittings"}` -- `Superstructure`'s from the parts with the patrol boat's fittings in
## the same mesh, the radar dome added to the panels the helm's view is checked against, and the box each fitting stands
## on the ship by.
static func build(geometry: Dictionary, helm: String) -> Dictionary:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = geometry.get("parts", []) as Array
	var panels: Array[AABB] = Superstructure.build_into(tool, geometry, helm)
	var fittings: Array[AABB] = []
	var hull: Dictionary = Superstructure.part_of(parts, "hull")
	var bridge: Dictionary = Superstructure.part_of(parts, "bridge")
	if not hull.is_empty():
		_rub_strake(tool, hull)
		_foredeck_rails(tool, parts, hull, bridge, fittings)
		_anchor(tool, parts, hull, fittings)
	if not bridge.is_empty():
		_on_the_roof(tool, bridge, panels, fittings)
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings}


## THE RUB STRAKE: a bar along every edge of the hull outline, just under its top, standing proud of the side. Outward is
## the right of the direction of travel round an `upward` ring, as `Plating.wall` has it.
static func _rub_strake(tool: SurfaceTool, hull: Dictionary) -> void:
	var outline: PackedVector2Array = Plating.upward(hull["outline"])
	var top: float = float(hull["top"])
	var n: int = outline.size()
	for i in range(n):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		var out: Vector2 = Vector2(b.y - a.y, -(b.x - a.x)).normalized() * 0.06
		Plating.bar(tool, a + out, b + out, 0.12, top - 0.1 - STRAKE_HIGH, top - 0.1, DARK)


## RAILS ROUND THE FOREDECK: a post and a top rail along each deck edge, from the bow to the wheelhouse's front.
static func _foredeck_rails(tool: SurfaceTool, parts: Array, hull: Dictionary, bridge: Dictionary,
		fittings: Array[AABB]) -> void:
	var hull_r: Rect2 = Wheelhouse.outline_rect(hull["outline"])
	var stop: float = Wheelhouse.outline_rect(bridge["outline"]).position.y if not bridge.is_empty() \
		else hull_r.get_center().y
	var z: float = hull_r.position.y + 0.8
	var last: Dictionary = {}
	while z < stop:
		var half: float = HullLoft.half_width(hull["outline"], z) - 0.12
		for side in [-1.0, 1.0]:
			var at := Vector2(side * half, z)
			var foot: float = Superstructure.top_under(parts, at)
			var post := AABB(Vector3(at.x - 0.02, foot, at.y - 0.02), Vector3(0.04, RAIL_HIGH, 0.04))
			Plating.box(tool, post.get_center(), post.size, STEEL)
			fittings.append(post)
			if last.has(side):
				Plating.bar(tool, last[side], at, 0.04, foot + RAIL_HIGH - 0.04, foot + RAIL_HIGH, STEEL)
			last[side] = at
		z += RAIL_EVERY


## THE ANCHOR, stowed on the starboard bow: a stock and two flukes, flat on the deck.
static func _anchor(tool: SurfaceTool, parts: Array, hull: Dictionary, fittings: Array[AABB]) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(hull["outline"])
	var z: float = r.position.y + 1.6
	var at := Vector2(HullLoft.half_width(hull["outline"], z) - 0.3, z)
	var foot: float = Superstructure.top_under(parts, at)
	var stock := AABB(Vector3(at.x - 0.06, foot, at.y - 0.35), Vector3(0.12, 0.08, 0.7))
	Plating.box(tool, stock.get_center(), stock.size, DARK)
	Plating.box(tool, Vector3(at.x, foot + 0.04, at.y + 0.35), Vector3(0.5, 0.08, 0.12), DARK)
	fittings.append(stock)


## ON THE WHEELHOUSE ROOF, its bridge part's top: a radar dome on a short plinth forward of the mast, two whip antennas at
## the after corners, and a searchlight at the forward starboard corner.
static func _on_the_roof(tool: SurfaceTool, bridge: Dictionary, panels: Array[AABB], fittings: Array[AABB]) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(bridge["outline"])
	var roof: float = float(bridge["top"])
	var dome_at := Vector2(r.get_center().x, r.get_center().y - DOME_FORWARD)
	var plinth := AABB(Vector3(dome_at.x - 0.25, roof, dome_at.y - 0.25), Vector3(0.5, 0.3, 0.5))
	var dome := AABB(Vector3(dome_at.x - 0.45, plinth.end.y, dome_at.y - 0.45), Vector3(0.9, 0.5, 0.9))
	Plating.box(tool, plinth.get_center(), plinth.size, STEEL)
	Plating.box(tool, dome.get_center(), dome.size, WHITE)
	fittings.append(plinth)
	panels.append(dome)
	for side in [-1.0, 1.0]:
		var whip := AABB(Vector3(r.get_center().x + side * (r.size.x * 0.5 - 0.15) - 0.015, roof, r.end.y - 0.315),
			Vector3(0.03, 3.0, 0.03))
		Plating.box(tool, whip.get_center(), whip.size, DARK)
		fittings.append(whip)
	var light := AABB(Vector3(r.get_center().x + 0.9 - 0.175, roof, r.position.y + 0.15), Vector3(0.35, 0.3, 0.4))
	Plating.box(tool, light.get_center(), light.size, STEEL)
	fittings.append(light)
