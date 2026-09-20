@tool
extends RefCounted
class_name HullLoft
## A SHIP'S HULL, LOFTED: stations along its length, each a section from the deck edge down to the keel, and the skin
## run between them.
##
## The simulation's `hull` part is a prism -- vertical sides, a flat bottom, a blunt octagon in plan -- because that is
## what collides and floats. Drawn like that a hull reads as a barge. A real one is full amidships and fines away to a
## raked stem at the bow and a cut-up counter at the stern, and it is wider at the deck edge than at the keel. So this
## draws the same outline, AT THE TOP, exactly as the part has it, and takes the sections below it in: a width factor
## and how far the stem and stern have pulled in, per row. The waterline row is the part's outline too, so the ship
## floats where it looks as if it floats.
##
## THE WATERLINE READS ON BOTH FINISHES because of a black boot-top band at it and antifouling red below, which is what
## every ship's hull is painted: the band is what the eye takes as "where the sea is", in a flat PLAIN light as much as
## in FINE's.

## HOW FAR THE BLACK BOOT-TOP BAND REACHES EITHER SIDE OF THE WATERLINE, metres. A DEFAULT, NOT A LAW: 0.8 was chosen
## against warships with eight metres of freeboard, where 1.6 m of black at the waterline is a stripe. On a boat with
## 2.4 m of freeboard it is most of the topside, and the fireboat -- whose whole identity is that she is RED -- came
## out as a black boat with a red stripe over it (lane/fireboat, 2026-09-19). A caller whose hull is small passes its
## own; every existing ship leaves it alone and is unchanged.
const BOOT_TOP: float = 0.8
const ABOVE := Color(0.45, 0.48, 0.51)
const BAND := Color(0.07, 0.07, 0.08)
const BELOW := Color(0.42, 0.13, 0.11)

## How many stations run from stem to stern. Forty sections of eight quads a side is under a thousand triangles, and a
## carrier's flare and a patrol boat's bow both read at it.
##
## A CALLER MAY ASK FOR FEWER, and the merchant ships do: the house look is low-poly and faceted, a hull being flat plating
## with hard chines and knuckles rather than a smooth round (the E-2D's airframe is the reference, 8 rows by 20 sides).
## Forty is what every warship here was drawn with and keeps.
const STATIONS: int = 40


## THE SKIN, appended to `tool`. `outline` is the hull part's plan outline and is taken to be symmetric about x = 0.
## `rows` run from the top down, each `[y, width, stem_in, stern_in]`: the height of the row, its half-width as a
## fraction of the outline's there, and how many metres the stem and the stern have come in from the outline's ends.
##
## `centre_x` IS THE AXIS THE OUTLINE IS SYMMETRIC ABOUT, for a hull that is not on the ship's centreline: a catamaran's
## demihull (`Ferry`). `paint` is `[above, band, below]` for a hull not painted haze grey (`CrudeCarrier`, `Ferry`).
## `sheer` IS HOW FAR THE TOP ROW RISES AT THE BOW AND AT THE STERN over its height amidships, in metres: a destroyer's
## main deck is 2.7 m higher at the stem than at amidships, and a deck drawn flat reads as a barge and fails a sheer
## check that asks whether the freeboard falls aft (`Destroyer`, cockpit-fleet3). It lifts the TOP ROW ONLY and by a
## parabola through the two ends, so the sections below it are untouched and the hull keeps its drawn draught.
## `deck_tint` PLATES THE TOP ROW, and a hull with `sheer` needs it: the caller cannot close a sheared deck with
## `Plating.paint`, which lays one flat polygon at one height, and a flat deck over a sheared hull is both a lie and the
## thing `_top_over` actually finds -- so the sheer would be invisible to the checks and to the eye
## (`Destroyer`, cockpit-fleet3, 2026-09-17). Left transparent, nothing is drawn and the caller plates it as before.
## EVERY DEFAULT TAKES THE PATH THIS FUNCTION HAD BEFORE IT EXISTED, not an equal one: an offset of 0 added to every
## vertex turns -0.0 into +0.0, and every warship's mesh is held to its old bytes (cockpit-fleet3, 2026-09-17).
static func build(tool: SurfaceTool, outline: PackedVector2Array, rows: Array, centre_x: float = 0.0,
		paint: Array = [], stations: int = STATIONS, sheer: Vector2 = Vector2.ZERO,
		deck_tint: Color = Color(0.0, 0.0, 0.0, 0.0), boot: float = BOOT_TOP) -> void:
	var moved: bool = centre_x != 0.0
	if moved:
		var local := PackedVector2Array()
		for p in outline:
			local.append(Vector2(p.x - centre_x, p.y))
		outline = local
	var z_bow: float = INF
	var z_stern: float = -INF
	for p in outline:
		z_bow = minf(z_bow, p.y)
		z_stern = maxf(z_stern, p.y)
	# THE WHOLE SKIN IS BUILT ABOUT x = 0 and put where the hull is at the end, into a tool of its own when it moves.
	var into: SurfaceTool = tool
	if moved:
		into = SurfaceTool.new()
		into.begin(Mesh.PRIMITIVE_TRIANGLES)
	# THE GRID: points[row][station] is the starboard point; port is its mirror.
	var points: Array = []
	var raised: bool = sheer != Vector2.ZERO
	for r_at in range(rows.size()):
		var row: Array = rows[r_at]
		var y: float = row[0]
		var line: Array[Vector3] = []
		for s in range(stations + 1):
			var t: float = float(s) / float(stations)
			var z: float = lerpf(z_bow + float(row[2]), z_stern - float(row[3]), t)
			var reference: float = lerpf(z_bow, z_stern, t)
			# THE TOP ROW ONLY, and by a parabola in each half so the deck is flat amidships and rises to each end.
			# THE UNSHEARED PATH DOES NOT ADD ANYTHING AT ALL, rather than adding zero: `y + 0.0` turns -0.0 into
			# +0.0 and every warship's mesh is held to its old bytes. This is the same trap `centre_x` and `paint`
			# were written round in this file three hours earlier, walked into again (cockpit-fleet3, 2026-09-17).
			var at_y: float = y
			if raised and r_at == 0:
				var from_mid: float = absf(t - 0.5) * 2.0
				at_y = y + (sheer.x if t < 0.5 else sheer.y) * from_mid * from_mid
			line.append(Vector3(half_width(outline, reference) * float(row[1]), at_y, z))
		points.append(line)
	for r in range(rows.size() - 1):
		var tint: Color = _paint_at((float(rows[r][0]) + float(rows[r + 1][0])) * 0.5, paint, boot)
		for s in range(stations):
			var a: Vector3 = points[r][s]
			var b: Vector3 = points[r][s + 1]
			var c: Vector3 = points[r + 1][s + 1]
			var d: Vector3 = points[r + 1][s]
			for side in [1.0, -1.0]:
				var m := Vector3(side, 1.0, 1.0)
				_facing(into, [a * m, b * m, c * m, d * m], Vector3(side, 0.0, 0.0), tint)
		# THE STEM AND THE TRANSOM: the section at each end, closed across.
		for end in [0, stations]:
			var out: Vector3 = Vector3(0.0, 0.0, -1.0 if end == 0 else 1.0)
			var top: Vector3 = points[r][end]
			var low: Vector3 = points[r + 1][end]
			_facing(into, [top, Vector3(-top.x, top.y, top.z), Vector3(-low.x, low.y, low.z), low], out, tint)
	# THE DECK, across the top row, when the caller asked for one. Two triangles a station between the starboard point
	# and its mirror, so a sheared deck is closed at the height its sheer actually puts it.
	if deck_tint.a > 0.0:
		var sheer_row: Array = points[0]
		for s in range(stations):
			var a: Vector3 = sheer_row[s]
			var b: Vector3 = sheer_row[s + 1]
			_facing(into, [Vector3(-a.x, a.y, a.z), Vector3(-b.x, b.y, b.z), b, a], Vector3.UP, deck_tint)
	# THE BOTTOM, flat under the keel row.
	var keel: Array = points[rows.size() - 1]
	var bottom_paint: Color = BELOW if paint.size() < 3 else paint[2]
	for s in range(stations):
		var a: Vector3 = keel[s]
		var b: Vector3 = keel[s + 1]
		_facing(into, [a, b, Vector3(-b.x, b.y, b.z), Vector3(-a.x, a.y, a.z)], Vector3.DOWN, bottom_paint)
	if moved:
		_append_moved(tool, into, Vector3(centre_x, 0.0, 0.0))


## THE OUTLINE'S HALF-WIDTH at `z`: where a line across the ship there leaves the outline to starboard.
static func half_width(outline: PackedVector2Array, z: float) -> float:
	var widest: float = 0.0
	var n: int = outline.size()
	for i in range(n):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		if (a.y - z) * (b.y - z) > 0.0 or is_equal_approx(a.y, b.y):
			if is_equal_approx(a.y, z):
				widest = maxf(widest, maxf(a.x, b.x))
			continue
		widest = maxf(widest, lerpf(a.x, b.x, (z - a.y) / (b.y - a.y)))
	return widest


static func _paint_at(y: float, paint: Array = [], boot: float = BOOT_TOP) -> Color:
	if paint.size() >= 3:
		return paint[0] if y > boot else (paint[1] if y > -boot else paint[2])
	if y > boot:
		return ABOVE
	if y > -boot:
		return BAND
	return BELOW


## A SKIN BUILT ABOUT x = 0, COPIED INTO `tool` MOVED BY `by`: every vertex with its own normal and colour, in the order it
## was wound, so the copy is wound as the original was.
static func _append_moved(tool: SurfaceTool, built: SurfaceTool, by: Vector3) -> void:
	var arrays: Array = built.commit_to_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if points.is_empty():
		return
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in range(points.size()):
		tool.set_color(colours[i])
		tool.set_normal(normals[i])
		tool.add_vertex(points[i] + by)


static func _facing(tool: SurfaceTool, corners: Array, out: Vector3, tint: Color) -> void:
	Plating.facing(tool, corners, out, tint)
