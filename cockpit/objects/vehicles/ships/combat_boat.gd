@tool
extends RefCounted
class_name CombatBoat
## A CB90 FAST ASSAULT CRAFT, UP CLOSE: its own model, built round the parts the simulation floats and seats it by
## (`cb90_shape`: the hull, the wheelhouse and the two after gun tubs), in the faceted house style.
##
## WHAT MAKES ONE READ AS A CB90 FROM THE WATER, off the photographs in `cockpit/craft/cb90/sources.md`: a hard-chined
## hull, slab-sided right up to the knuckle at the bow, with the bow cut off square and raked where the landing ramp is;
## a low, angular wheelhouse forward of amidships with a visor over its windows; the flat after deck troops ride on,
## railed; the two waterjet housings on the transom; and Swedish splinter camouflage. On top of those, the user's: two
## heavy machine guns at the back (the tubs are parts; the guns are VehicleView's, from `Sim.gun_of`) and a box of
## missiles on the wheelhouse roof.
##
## THE HULL IS LOFTED HERE, NOT BY `Superstructure`, whose rows are a displacement hull's: fine at the bow, round in the
## bilge. A planing assault craft is flat plate and hard chines, so the rows below are a deep-V's -- a knuckle, a chine
## and a keel -- over FOURTEEN stations rather than forty, which is the house look (the E-2D is the reference: flat
## plating, hard edges). The top row and the waterline row are the part's own outline, so it floats where it looks as
## if it floats.
##
## THE LAUNCHER IS WHERE THE SIMULATION LAUNCHES FROM: its rails are `Sim.missile_schema`'s pylons, and it is tilted by
## the schema's `launcher_pitch`, so a missile leaves out of the end of the box that is drawn and not out of the roof
## beside it. It is an open frame -- two cheeks, a top and a floor -- so the missiles MissileYard hangs on the rails show
## from ahead and astern.
##
## ONE MESH, ONE DRAW CALL, like every ship here (`Plating`): the camouflage is vertex colour on plates laid a few mm
## proud of the side, not a texture.

const OLIVE := Color(0.31, 0.35, 0.28)
const SPLINTER_DARK := Color(0.17, 0.21, 0.16)
const SPLINTER_BROWN := Color(0.36, 0.31, 0.23)
const SPLINTER_BLACK := Color(0.09, 0.10, 0.09)
const BOOT := Color(0.07, 0.07, 0.08)
const BOTTOM := Color(0.16, 0.17, 0.16)
const DECK := Color(0.24, 0.26, 0.22)
const STEEL := Color(0.26, 0.28, 0.25)
const DARK := Color(0.12, 0.13, 0.12)
const GLASS_TRIM := Color(0.10, 0.12, 0.13)

## THE HULL'S SECTIONS, top down, in metres over the waterline: `[y, width share, stem in, stern in]`. The deck edge; the
## knuckle, where the slab side ends; the waterline; the chine; the keel. The stem comes in 0.9 m by the waterline and
## 3.2 m by the keel, which is the raked bow the ramp lies on.
const ROWS: Array = [
	[1.00, 1.00, 0.00, 0.00],
	[0.45, 1.00, 0.25, 0.00],
	[0.00, 0.97, 0.90, 0.05],
	[-0.35, 0.88, 1.80, 0.08],
	[-0.80, 0.10, 3.20, 0.25],
]
const STATIONS: int = 14
## A rub strake a hand under the deck edge, all round.
const STRAKE_HIGH: float = 0.16
## Rails: waist-high, a post every 1.4 m.
const RAIL_HIGH: float = 0.95
const RAIL_EVERY: float = 1.4
## THE VISOR over the wheelhouse's front windows: how far it juts forward of the front wall and how far it drops.
const VISOR_OUT: float = 0.35
const VISOR_DROP: float = 0.22
## The waterjets' housings on the transom: centres either side, and how far they stand proud of it.
const JET_X: float = 0.72
const JET_OUT: float = 0.45
## THE SPLINTERS, on each side between the knuckle and the deck edge: `[z_from, z_to, slant, colour index]`, the slant
## being how far the aft edge leans (metres over the band's height). Irregular on purpose.
const SPLINTERS: Array = [
	[-5.4, -3.6, 0.6, 0], [-3.0, -1.4, -0.5, 1], [-0.9, 0.6, 0.4, 2], [1.2, 3.1, -0.7, 0],
	[3.6, 4.9, 0.5, 1], [5.3, 7.2, -0.4, 2],
]


## THE NEAR MODEL: `{"mesh", "panels", "fittings"}`, as every ship builder returns it.
static func build(geometry: Dictionary, helm: String) -> Dictionary:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = geometry.get("parts", []) as Array
	var panels: Array[AABB] = []
	var fittings: Array[AABB] = []
	var hull: Dictionary = Superstructure.part_of(parts, "hull")
	var room: Dictionary = Superstructure.part_of(parts, "bridge")
	if not hull.is_empty():
		var outline: PackedVector2Array = hull["outline"]
		var top: float = float(hull["top"])
		var rows: Array = []
		for row in ROWS:
			rows.append([lerpf(0.0, top, float(row[0])) if float(row[0]) >= 0.0 else float(row[0]),
				float(row[1]), float(row[2]), float(row[3])])
		HullLoft.build(tool, outline, rows, 0.0, [OLIVE, BOOT, BOTTOM], STATIONS)
		Plating.paint(tool, outline, top - Superstructure.SHEER_DROP, DECK)
		_splinters(tool, outline, top)
		_rub_strake(tool, outline, top)
		_ramp(tool, outline, top, fittings)
		_waterjets(tool, outline)
		_troop_hatches(tool, top, room, fittings)
		_rails(tool, parts, outline, room, fittings)
	for part in parts:
		if String(part.get("part", "")) == "station":
			_gun_tub(tool, part)
	if not room.is_empty():
		panels.append_array(Wheelhouse.build(tool, room, ["fore", "port", "starboard"], OLIVE, GLASS_TRIM))
		_visor(tool, room, panels)
		_on_the_roof(tool, room, panels, fittings)
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings}


## THE SPLINTER CAMOUFLAGE: slanted plates of dark green, brown and black on each slab side, 5 mm proud of it, between
## the knuckle and the deck edge where the side is flat and vertical.
static func _splinters(tool: SurfaceTool, outline: PackedVector2Array, top: float) -> void:
	var low: float = top * 0.45 + 0.03
	var high: float = top - 0.04
	var tints: Array = [SPLINTER_DARK, SPLINTER_BROWN, SPLINTER_BLACK]
	for side in [-1.0, 1.0]:
		for s in SPLINTERS:
			var z0: float = float(s[0])
			var z1: float = float(s[1])
			var lean: float = float(s[2])
			var x0: float = side * (HullLoft.half_width(outline, z0) + 0.005)
			var x1: float = side * (HullLoft.half_width(outline, z1) + 0.005)
			var corners: Array = [Vector3(x0, low, z0), Vector3(x1, low, z1),
				Vector3(x1, high, z1 + lean), Vector3(x0, high, z0 + lean * 0.3)]
			Plating.facing(tool, corners, Vector3(side, 0.0, 0.0), tints[int(s[3]) % tints.size()])


## A RUB STRAKE: a dark bar along every edge of the deck outline, just under its top, proud of the side.
static func _rub_strake(tool: SurfaceTool, outline: PackedVector2Array, top: float) -> void:
	var ring: PackedVector2Array = Plating.upward(outline)
	var n: int = ring.size()
	for i in range(n):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % n]
		var out: Vector2 = Vector2(b.y - a.y, -(b.x - a.x)).normalized() * 0.05
		Plating.bar(tool, a + out, b + out, 0.10, top - 0.08 - STRAKE_HIGH, top - 0.08, DARK)


## THE BOW RAMP: the door troops go ashore over, hinged at the deck edge and lying on the raked bow when it is shut -- a
## slab across the bow's flat, its two hinge knuckles, and the chains' stanchions either side.
static func _ramp(tool: SurfaceTool, outline: PackedVector2Array, top: float, fittings: Array[AABB]) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(outline)
	var bow: float = r.position.y
	var half: float = HullLoft.half_width(outline, bow + 0.05) - 0.08
	# THE DOOR ITSELF, laid down the rake from the deck edge to the waterline, 0.9 m back at the bottom as the loft has it.
	var corners: Array = [Vector3(-half, top + 0.02, bow - 0.03), Vector3(half, top + 0.02, bow - 0.03),
		Vector3(half * 0.85, top * 0.15, bow + 0.62), Vector3(-half * 0.85, top * 0.15, bow + 0.62)]
	Plating.facing(tool, corners, Vector3(0.0, 0.35, -1.0).normalized(), STEEL)
	for side in [-1.0, 1.0]:
		var hinge := AABB(Vector3(side * half * 0.6 - 0.12, top, bow + 0.02), Vector3(0.24, 0.12, 0.16))
		Plating.box(tool, hinge.get_center(), hinge.size, DARK)
		fittings.append(hinge)
		var stanchion := AABB(Vector3(side * half - 0.03, top, bow + 0.25), Vector3(0.06, 0.75, 0.06))
		Plating.box(tool, stanchion.get_center(), stanchion.size, STEEL)
		fittings.append(stanchion)


## THE WATERJETS: two housings on the transom, each with its steering nozzle and the reversing bucket over it.
static func _waterjets(tool: SurfaceTool, outline: PackedVector2Array) -> void:
	var stern: float = Wheelhouse.outline_rect(outline).end.y
	for side in [-1.0, 1.0]:
		var housing := AABB(Vector3(side * JET_X - 0.28, -0.30, stern), Vector3(0.56, 0.62, JET_OUT))
		Plating.box(tool, housing.get_center(), housing.size, DARK)
		var bucket := AABB(Vector3(side * JET_X - 0.24, 0.08, stern + JET_OUT - 0.05), Vector3(0.48, 0.30, 0.22))
		# NOT A FITTING THAT STANDS: it hangs on the transom under the deck, so it is not held to a part's top.
		Plating.box(tool, bucket.get_center(), bucket.size, STEEL, Basis(Vector3.RIGHT, -0.35))


## THE TROOP COMPARTMENT'S ROOF on the after deck: a low coaming with two square hatches, between the wheelhouse and the
## gun tubs.
static func _troop_hatches(tool: SurfaceTool, top: float, room: Dictionary, fittings: Array[AABB]) -> void:
	var from_z: float = Wheelhouse.outline_rect(room["outline"]).end.y + 0.6 if not room.is_empty() else 0.8
	var coaming := AABB(Vector3(-1.15, top, from_z), Vector3(2.3, 0.22, 3.6))
	Plating.box(tool, coaming.get_center(), coaming.size, STEEL)
	fittings.append(coaming)
	for z in [from_z + 0.9, from_z + 2.6]:
		var hatch := AABB(Vector3(-0.35, coaming.end.y, z - 0.35), Vector3(0.7, 0.06, 0.7))
		Plating.box(tool, hatch.get_center(), hatch.size, DARK)


## RAILS: waist-high posts and a top rail down each side, from the bow to the wheelhouse's front and from the
## wheelhouse's back to the gun tubs.
static func _rails(tool: SurfaceTool, parts: Array, outline: PackedVector2Array, room: Dictionary,
		fittings: Array[AABB]) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(outline)
	var house: Rect2 = Wheelhouse.outline_rect(room["outline"]) if not room.is_empty() else Rect2(0.0, 0.0, 0.0, 0.0)
	var runs: Array = [[r.position.y + 0.7, house.position.y - 0.2], [house.end.y + 0.3, r.end.y - 2.4]]
	for run in runs:
		var last: Dictionary = {}
		var z: float = float(run[0])
		while z <= float(run[1]):
			var half: float = HullLoft.half_width(outline, z) - 0.10
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


## A GUN TUB in the boat's own paint: a platform and a waist-high ring of plate round a `station` part, as
## `Superstructure.gun_tub` draws a warship's -- whose haze grey read as two white crates on an olive deck.
static func _gun_tub(tool: SurfaceTool, part: Dictionary) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(part.get("outline", PackedVector2Array()))
	var floor_at: float = float(part.get("bottom", 0.0))
	Plating.box(tool, Vector3(r.get_center().x, floor_at - 0.05, r.get_center().y), Vector3(r.size.x, 0.1, r.size.y), DECK)
	var ring: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in range(4):
		Plating.bar(tool, ring[i], ring[(i + 1) % 4], 0.06, floor_at, floor_at + 0.95, OLIVE)


## THE VISOR: a raked plate from the roof's front edge out over the front windows, which is most of what makes the
## wheelhouse read as the CB90's and not a shed's.
static func _visor(tool: SurfaceTool, room: Dictionary, panels: Array[AABB]) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(room["outline"])
	var roof: float = float(room["top"])
	var front: float = r.position.y
	var corners: Array = [Vector3(r.position.x, roof, front), Vector3(r.end.x, roof, front),
		Vector3(r.end.x - 0.15, roof - VISOR_DROP, front - VISOR_OUT), Vector3(r.position.x + 0.15, roof - VISOR_DROP, front - VISOR_OUT)]
	Plating.facing(tool, corners, Vector3(0.0, 1.0, -0.6).normalized(), OLIVE)
	Plating.facing(tool, corners, Vector3(0.0, -1.0, 0.6).normalized(), DARK)
	# AND THE ROOF'S EDGES CHAMFERED: a narrower cap on the roof, so the top reads as angled plate, not a lid.
	var cap := AABB(Vector3(r.position.x + 0.25, roof, r.position.y + 0.25), Vector3(r.size.x - 0.5, 0.05, r.size.y - 0.5))
	Plating.box(tool, cap.get_center(), cap.size, OLIVE)
	panels.append(AABB(Vector3(r.position.x, roof - VISOR_DROP, front - VISOR_OUT), Vector3(r.size.x, VISOR_DROP, VISOR_OUT)))


## ON THE WHEELHOUSE ROOF: the missile box on its pedestal where the simulation's rails are, a mast with a radar bar
## abaft it, two whips, and a searchlight forward.
static func _on_the_roof(tool: SurfaceTool, room: Dictionary, panels: Array[AABB], fittings: Array[AABB]) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(room["outline"])
	# ON THE ROOF ITSELF, the bridge part's top, which is what a fitting is held to stand on (`tests/ship_models.gd`); the
	# chamfered cap is a skin 5 cm thick that they stand through.
	var roof: float = float(room["top"])
	var schema: Dictionary = Sim.missile_schema(Sim.Kind.CB90)
	var rails: Array = schema.get("pylons", []) as Array
	if not rails.is_empty():
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for rail in rails:
			low = low.min(rail as Vector3)
			high = high.max(rail as Vector3)
		var middle: Vector3 = (low + high) * 0.5
		var pitch: float = float(schema.get("launcher_pitch", 0.0))
		var turn := Basis(Vector3.RIGHT, pitch)
		var wide: float = high.x - low.x + 0.50
		var tall: float = high.y - low.y + 0.40
		var long: float = 1.9
		# THE PEDESTAL, from the roof up to the box's floor.
		# NEVER NEGATIVE: a pedestal of -5 cm, when the box's floor came lower than a roof raised by the cap, is a box drawn
		# inside out -- eight faces wound against their normals in `ship_models`, the first build.
		var foot := AABB(Vector3(middle.x - 0.2, roof, middle.z - 0.2), Vector3(0.4, maxf(middle.y - tall * 0.5 - roof, 0.05), 0.4))
		Plating.box(tool, foot.get_center(), foot.size, DARK)
		fittings.append(foot)
		# THE BOX, open at both ends: its two cheeks, its top and its floor, all turned up by the launcher's pitch.
		for side in [-1.0, 1.0]:
			Plating.box(tool, middle + turn * Vector3(side * wide * 0.5, 0.0, 0.0), Vector3(0.05, tall, long), STEEL, turn)
		for level in [-1.0, 1.0]:
			Plating.box(tool, middle + turn * Vector3(0.0, level * tall * 0.5, 0.0), Vector3(wide, 0.05, long), STEEL, turn)
		# A DARK BAND round each end, the frames the tubes are held in, so the box reads as a launcher and not a sign.
		for end in [-1.0, 1.0]:
			Plating.box(tool, middle + turn * Vector3(0.0, 0.0, end * (long * 0.5 - 0.06)), Vector3(wide + 0.04, tall + 0.04, 0.12), DARK, turn)
		panels.append(AABB(middle - Vector3(wide, tall, long) * 0.5, Vector3(wide, tall, long)))
	# THE MAST, abaft the box, with a radar bar across its head, and two whips at the after corners.
	var mast_at := Vector2(0.0, r.end.y - 0.35)
	var mast := AABB(Vector3(mast_at.x - 0.05, roof, mast_at.y - 0.05), Vector3(0.10, 1.6, 0.10))
	Plating.box(tool, mast.get_center(), mast.size, DARK)
	fittings.append(mast)
	Plating.box(tool, Vector3(mast_at.x, mast.end.y, mast_at.y), Vector3(1.1, 0.10, 0.18), DARK)
	for side in [-1.0, 1.0]:
		var whip := AABB(Vector3(side * (r.size.x * 0.5 - 0.12) - 0.015, roof, r.end.y - 0.2), Vector3(0.03, 2.6, 0.03))
		Plating.box(tool, whip.get_center(), whip.size, DARK)
		fittings.append(whip)
	var lamp := AABB(Vector3(0.9 - 0.15, roof, r.position.y + 0.35), Vector3(0.30, 0.26, 0.34))
	Plating.box(tool, lamp.get_center(), lamp.size, STEEL)
	fittings.append(lamp)
