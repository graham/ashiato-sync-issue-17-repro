@tool
extends RefCounted
class_name Superstructure
## ANY SHIP, UP CLOSE, FROM ITS PARTS ALONE: a lofted hull, its decks and superstructure as prisms, a room round every helm
## and a tub round every gun position.
##
## The carrier has a model of its own (`Carrier`). The battleship, the patrol boat and the launch did not, and their crews
## sat on the deck with nothing round them: a chair on a box. The request that brought this was "the pilot seats should be
## higher and part of the boat as well", so a helm is a `bridge` part in the simulation's shape table, the seat is placed
## on its floor (`seat_in`), and this draws the room that part is. It is what every ship with parts gets until it has a
## builder of its own, and what a ship's own builder draws its bridge with.
##
## TWO KINDS OF HELM. A ship is conned from behind glass (`Wheelhouse`), glazed forward and to both sides. A launch is
## driven from an OPEN console under a T-top: a console at the helm's knees with a windscreen on it, four posts and a roof
## to keep the sun off. Which one a kind has is the catalogue's to say (`VehicleCatalogue.helm`), not a guess from how big
## the room is -- presentation beside the paint, not a rule hidden in a size.

const HAZE := Color(0.45, 0.48, 0.51)
const DECK := Color(0.30, 0.31, 0.30)
const STEEL := Color(0.32, 0.34, 0.36)
const CONSOLE := Color(0.18, 0.19, 0.21)
const SCREEN := Color(0.08, 0.10, 0.12)
## How far under the sheer a lofted hull's top is plated: under a room's floor laid on the deck, and nothing a foot can
## find.
const SHEER_DROP: float = 0.02

## The hull's sections for a ship with no rows of its own, top down, as fractions: `[height, width, stem_in, stern_in]`,
## where height runs from the part's top (1) through the waterline (0) to its keel (-1), and stem and stern come in by a
## share of the part's length. A fine bow and a fuller stern, which is most displacement hulls.
const ROWS: Array = [
	[1.0, 1.0, 0.0, 0.0],
	[0.35, 0.99, 0.02, 0.01],
	[0.08, 0.97, 0.05, 0.03],
	[-0.08, 0.95, 0.06, 0.035],
	[-0.55, 0.80, 0.10, 0.06],
	[-1.0, 0.40, 0.18, 0.12],
]


## THE NEAR MODEL: `{"mesh": ArrayMesh, "panels": Array[AABB]}` -- the panels being every room's walls and posts and every
## solid superstructure part, as boxes for the see-out checks. `helm` is "glazed" or "open".
static func build(geometry: Dictionary, helm: String) -> Dictionary:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var panels: Array[AABB] = build_into(tool, geometry, helm)
	return {"mesh": Plating.weld(tool), "panels": panels}


## THE SAME, INTO A TOOL SOMEBODY ELSE IS WELDING: a ship with fittings of its own (`Battleship`, `PatrolBoat`, `Launch`) builds its
## parts here and adds its fittings to the same tool, which is one mesh and needs no second one copied into it. Returns
## the panels.
static func build_into(tool: SurfaceTool, geometry: Dictionary, helm: String) -> Array[AABB]:
	var parts: Array = geometry.get("parts", []) as Array
	var panels: Array[AABB] = []
	var waterline: float = float(geometry.get("waterline", 0.0))
	# THE SHIP'S OWN BOW AND STERN, over every hull part. A hull built in lengths -- the battleship's forecastle and main
	# deck -- fines away at these and nowhere else: lofted as if each length's ends were the ship's, both pulled in at
	# their joint and left a 12 m gap in the side at the forecastle's break (tests/ship_models.gd, 2026-09-15).
	var bow: float = INF
	var stern: float = -INF
	for part in parts:
		if String(part.get("part", "")) == "hull":
			var ends: Rect2 = Wheelhouse.outline_rect(part.get("outline", PackedVector2Array()))
			bow = minf(bow, ends.position.y)
			stern = maxf(stern, ends.end.y)
	for part in parts:
		var outline: PackedVector2Array = part.get("outline", PackedVector2Array())
		var bottom: float = float(part.get("bottom", 0.0))
		var top: float = float(part.get("top", 0.0))
		match String(part.get("part", "")):
			"hull":
				var ends: Rect2 = Wheelhouse.outline_rect(outline)
				HullLoft.build(tool, outline, rows_for(outline, bottom, top, waterline,
					is_equal_approx(ends.position.y, bow), is_equal_approx(ends.end.y, stern)))
				# THE HULL'S TOP, plated. The loft is sides, ends and a keel, and a ship with a deck part covers its top
				# with that; the launch has none -- its hull's top IS its deck -- and its helm stood over the sea
				# (tests/ship_models.gd, 2026-09-15). `SHEER_DROP` under the sheer, so a room's floor laid on the deck,
				# as the patrol boat's wheelhouse is, does not fight it for the same pixels.
				Plating.paint(tool, outline, top - SHEER_DROP, DECK)
			"deck":
				Plating.prism(tool, outline, bottom, top, DECK)
			"island":
				Plating.prism(tool, outline, bottom, top, HAZE, false)
				var r: Rect2 = Wheelhouse.outline_rect(outline)
				panels.append(AABB(Vector3(r.position.x, bottom, r.position.y), Vector3(r.size.x, top - bottom, r.size.y)))
			"bridge":
				if helm == "open":
					panels.append_array(open_helm(tool, part))
				else:
					panels.append_array(Wheelhouse.build(tool, part, ["fore", "port", "starboard"], HAZE, STEEL))
			"station":
				gun_tub(tool, part)
	return panels


## A HULL PART'S ROWS in metres, from `ROWS`: its top, the waterline, its keel, and its length. `fines_at_bow` and
## `fines_at_stern` say whether that end of the part is an end of the ship; an end that meets another hull part keeps its
## full section, so the two lengths meet side to side.
static func rows_for(outline: PackedVector2Array, bottom: float, top: float, waterline: float, fines_at_bow: bool,
		fines_at_stern: bool) -> Array:
	var length: float = Wheelhouse.outline_rect(outline).size.y
	var out: Array = []
	for row in ROWS:
		var share: float = float(row[0])
		var y: float = lerpf(waterline, top, share) if share >= 0.0 else lerpf(waterline, bottom, -share)
		out.append([y, float(row[1]), float(row[2]) * length if fines_at_bow else 0.0,
			float(row[3]) * length if fines_at_stern else 0.0])
	return out


## THE SHIP'S OUTSIDE UNDER A PLAN POINT: the highest top of any hull, deck or island part whose outline holds `at`, or
## -INF over the sea. A ship's own model stands its fittings on this and types no heights: the battleship's first draft
## typed the research's, over a shape whose decks were not where those heights assumed, and its turrets, mounts and
## launchers stood inside the forecastle or in the air. A ROOM IS NOT HERE: a bridge part's top is its roof and its bottom
## is its floor, so a fitting on a wheelhouse roof or a seat in a T-top asks that part by name -- asked this way, the
## launch's jockey seat stood on its T-top.
static func top_under(parts: Array, at: Vector2) -> float:
	var top: float = -INF
	for part in parts:
		if not (String(part.get("part", "")) in ["hull", "deck", "island"]):
			continue
		if Geometry2D.is_point_in_polygon(at, part.get("outline", PackedVector2Array())):
			top = maxf(top, float(part.get("top", 0.0)))
	return top


## The first part in `parts` with `role`, or an empty Dictionary.
static func part_of(parts: Array, role: String) -> Dictionary:
	for part in parts:
		if String(part.get("part", "")) == role:
			return part
	return {}


## AN OPEN HELM: the console at the helm's knees with its windscreen, four posts and a T-top roof over the part. The seat
## stands behind the console, which is at the part's front; the posts are at its corners, out of the helm's line forward.
static func open_helm(tool: SurfaceTool, part: Dictionary) -> Array[AABB]:
	var r: Rect2 = Wheelhouse.outline_rect(part.get("outline", PackedVector2Array()))
	var floor_at: float = float(part.get("bottom", 0.0))
	var roof: float = float(part.get("top", floor_at + 2.0))
	var panels: Array[AABB] = []
	# THE CONSOLE: a metre high, across the middle of the part's front, and the helm's instruments on its sloped top.
	var console := AABB(Vector3(r.get_center().x - 0.30, floor_at, r.position.y), Vector3(0.60, 1.0, 0.55))
	panels.append(console)
	Plating.box(tool, console.get_center(), console.size, CONSOLE)
	Plating.box(tool, Vector3(r.get_center().x, floor_at + 1.02, r.position.y + 0.35), Vector3(0.50, 0.04, 0.30), SCREEN)
	# THE WINDSCREEN, low on the console's front edge, AS A FRAME: a rail along its top and a post at each end, and the glass
	# between them a gap, as every window here is. Drawn first as a solid pane 1.0 to 1.25 m up, it stood across the seated
	# helm's line to the foredeck, which passes it 1.14 m above the floor (tests/ship_models.gd, 2026-09-15).
	var left: float = r.get_center().x - 0.32
	var right: float = r.get_center().x + 0.32
	var front: float = r.position.y
	var frame: Array[AABB] = [
		AABB(Vector3(left, floor_at + 1.22, front), Vector3(right - left, 0.03, 0.03)),
		AABB(Vector3(left, floor_at + 1.0, front), Vector3(0.02, 0.25, 0.03)),
		AABB(Vector3(right - 0.02, floor_at + 1.0, front), Vector3(0.02, 0.25, 0.03)),
	]
	for bar in frame:
		panels.append(bar)
		Plating.box(tool, bar.get_center(), bar.size, SCREEN)
	# FOUR POSTS AND A ROOF, the T-top.
	for x in [r.position.x + 0.03, r.end.x - 0.03]:
		for z in [r.position.y + 0.03, r.end.y - 0.03]:
			var post := AABB(Vector3(x - 0.025, floor_at, z - 0.025), Vector3(0.05, roof - floor_at - 0.06, 0.05))
			panels.append(post)
			Plating.box(tool, post.get_center(), post.size, STEEL)
	var top := AABB(Vector3(r.position.x, roof - 0.06, r.position.y), Vector3(r.size.x, 0.06, r.size.y))
	panels.append(top)
	Plating.box(tool, top.get_center(), top.size, HAZE)
	return panels


## A GUN TUB: a platform and a waist-high ring of plate round a `station` part. The gun on its pintle is VehicleView's.
static func gun_tub(tool: SurfaceTool, part: Dictionary) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(part.get("outline", PackedVector2Array()))
	var floor_at: float = float(part.get("bottom", 0.0))
	Plating.box(tool, Vector3(r.get_center().x, floor_at - 0.05, r.get_center().y), Vector3(r.size.x, 0.1, r.size.y), STEEL)
	var ring: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in range(4):
		Plating.bar(tool, ring[i], ring[(i + 1) % 4], 0.06, floor_at, floor_at + 0.95, HAZE)
