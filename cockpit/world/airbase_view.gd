extends Node3D
class_name AirbaseView
## AN AIR BASE, DRAWN: its pavement and paint, its revetments and its hangars, from what `AirbasePlan` laid and nothing
## else.
##
## ONE LAID BASE, ONE VIEW, standing at its runway's middle with every instance an offset from there (a MultiMesh's
## transforms are float32 whatever the engine's precision; see SceneryYard). Three draw calls for a whole base: the
## pavement and its paint as one MultiMesh of coloured unit boxes, as the runway's are (`FlightLevel._draw_runway`); every
## wall, roof slab, door leaf and seam as another; and the hangars' pitched and arched roofs as one merged mesh.
##
## NO COLLISION HERE. The pavement needs none -- the island's slab is the floor under it, as it is under the runway. The
## walls and flat roofs the simulation collides with are `AirbasePlan`'s boxes, given to it with the island's in
## `Terrain.boxes()`; this draws those same boxes first, and everything else on top of them is a picture: the earth on a
## revetment, the seams between its bins, a hangar's pilasters, plinth, fascia, door leaves and its roof's pitch.
##
## THE PAINT is what a pilot taxis by, laid the way the FAA's Advisory Circular 150/5340-1 lays it, in yellow: a
## continuous centreline down every taxiway and taxilane; a hold bar across every stub at the hold node -- two solid lines
## on the taxiway side and two dashed on the runway side; and at each parking spot a lead-in line from its mouth and a
## stop bar across its nose line. Widths are the enhanced 12 in (0.30 m) lines rather than the plain 6 in, which are
## sub-pixel from any height an aeroplane is flown at here.

## THE COLOURS ARE sRGB, AS WRITTEN (`vertex_color_is_srgb`): the first pictures took them as linear, and a concrete of
## 0.50 and then 0.36 both read as white beside the runway's asphalt (2026-09-17).
## THE PAVEMENT'S COLOUR: a military taxiway and apron are portland cement concrete, paler than the runway's asphalt.
const CONCRETE := Color(0.56, 0.56, 0.53)
## THE PAVEMENT'S TWO SHADERS. The slabs and their paint wear one of these; the revetments, hangars and roofs keep the
## plain vertex-coloured material, because they are structures and not pavement. How near their detail comes in is
## `DetailReach`, the same bands the runway's asphalt uses -- "when is surface detail worth drawing" has one answer
## and it does not depend on what the surface is made of.
const PAVEMENT: Shader = preload("res://world/shaders/concrete.gdshader")
const PAVEMENT_FINE: Shader = preload("res://world/shaders/concrete_fine.gdshader")
## Taxiway yellow.
const YELLOW := Color(0.86, 0.68, 0.12)
## A painted line's width and thickness, metres; and how far above the pavement's top its middle stands.
const LINE: float = 0.30
const PAINT_HALF_HEIGHT: float = 0.015
const PAINT_RISE: float = 0.01
## THE HOLD BAR: four lines LINE wide and LINE apart, and the dashes on the runway side of it.
const HOLD_LINES: int = 4
const HOLD_DASH: float = 0.9
## THE SPOT'S STOP BAR, across the nose line: this long.
const STOP_BAR: float = 6.0

## THE STRUCTURES' COLOURS. A steel bin revetment is corrugated galvanised steel filled with earth; a hangar is pale
## cladding over a darker plinth, with steel pilasters, sliding door leaves and a dark roof.
const STEEL := Color(0.50, 0.50, 0.44)
const EARTH := Color(0.40, 0.33, 0.24)
const SEAM := Color(0.36, 0.36, 0.32)
const CLADDING := Color(0.70, 0.69, 0.64)
const PILASTER := Color(0.56, 0.56, 0.54)
const PLINTH := Color(0.34, 0.34, 0.33)
const ROOF := Color(0.34, 0.37, 0.40)
const TRIM := Color(0.22, 0.23, 0.24)
const DOOR := Color(0.40, 0.47, 0.50)
const DOOR_RIB := Color(0.30, 0.35, 0.37)
const GLASS := Color(0.16, 0.20, 0.25)

## A STEEL BIN REVETMENT'S MODULE, metres: the AFCESA history's bins are 10 ft long, so a seam every 3.05 m.
const BIN_LENGTH: float = 3.05
## A seam's width and how far it stands proud of the wall.
const SEAM_WIDTH: float = 0.10
const SEAM_PROUD: float = 0.04
## THE EARTH ON TOP OF A BIN WALL, mounded a little above the steel.
const EARTH_CAP: float = 0.30

## A HANGAR'S STRUCTURAL BAY: a pilaster every 20 ft (6.10 m) down its sides and back, this wide and this proud.
const PILASTER_BAY: float = 6.10
const PILASTER_WIDTH: float = 0.45
const PILASTER_PROUD: float = 0.25
## The dark plinth round a hangar's foot, and how proud of the cladding it stands.
const PLINTH_HIGH: float = 1.0
const PLINTH_PROUD: float = 0.08
## The fascia along a hangar's eaves and over its door.
const FASCIA_HIGH: float = 0.6
const FASCIA_PROUD: float = 0.2
## HOW FAR A ROOF OVERHANGS its walls, metres; a gable roof's pitch, degrees; and how high an arched roof rises over its
## span, as a share of the span. Neither is in the Navy's table, which gives clear heights: these are the shallow pitched
## roof and the segmental barrel vault common on standard hangars, chosen by eye, and they are pictures only -- the solid
## roof is the flat box at the clear height.
const OVERHANG: float = 0.6
const GABLE_PITCH: float = 10.0
const ARCH_RISE: float = 0.20
const ARCH_SEGMENTS: int = 16
## THE DOORS: sliding leaves stacked open at each end of the opening, just inside it, each stepped back behind and out
## from the one in front.
const LEAVES_A_SIDE: int = 4
const LEAF_THICK: float = 0.25
const LEAF_STEP_IN: float = 0.35
const LEAF_STEP_OUT: float = 0.6
## Ribs across the front leaf's face, as shares of its height, and the window band near its top.
const LEAF_RIBS: Array[float] = [0.25, 0.5, 0.75]
const RIB_HIGH: float = 0.12
const WINDOW_BAND := Vector2(0.82, 0.93)

var laid: Dictionary = {}
## The pavement's two materials, made once when the ground is drawn and swapped by `wear`.
var _ground_plain: ShaderMaterial = null
var _ground_fine: ShaderMaterial = null
## Every solid box this view handed its structures' batch, as `{position, half_extents}`: see `drawn_solid`.
var _solid_drawn: Array[Dictionary] = []


## THE VIEW OF ONE LAID BASE, built and ready to add to the tree.
static func build(base: Dictionary) -> AirbaseView:
	var view := AirbaseView.new()
	view.name = "Airbase_%s" % base["id"]
	view.laid = base
	view.position = base["frame"]["centre"]
	view._draw_the_ground()
	view._draw_the_structures()
	return view


## ---- the ground -----------------------------------------------------------------------------------------------------

## EVERY SLAB OF PAVEMENT AND EVERY LINE OF PAINT, as `{position, half_extents, colour}` in the world: the pavement as
## `AirbasePlan` laid it, and the paint worked out here from the taxiways, the route nodes and the spots.
static func ground_pieces(base: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slab in base["pavement"]:
		out.append({"position": slab["position"], "half_extents": slab["half_extents"], "colour": CONCRETE,
			"yaw": float(slab.get("yaw", 0.0))})
	var frame: Dictionary = base["frame"]
	var width: float = base["standards"]["taxiway_width"]
	var top: float = AirbasePlan.PAVEMENT_HALF_HEIGHT * 2.0 + PAINT_RISE
	var paint: Array = [top - PAINT_HALF_HEIGHT, top + PAINT_HALF_HEIGHT]
	# EACH HIGH-SPEED EXIT'S CENTRELINE, turned to its angle as its slab is.
	for exit in base.get("exits", []):
		var from: Vector3 = (base["nodes"][exit["start"]] as Dictionary)["position"]
		var to: Vector3 = (base["nodes"][exit["join"]] as Dictionary)["position"]
		out.append({"position": (from + to) * 0.5 + Vector3.UP * top, "yaw": float(exit["yaw"]), "colour": YELLOW,
			"half_extents": Vector3(LINE * 0.5, PAINT_HALF_HEIGHT, from.distance_to(to) * 0.5)})
	# THE CENTRELINES, end to end of each taxiway's centreline.
	for line in base["taxiways"]:
		var fixed: float = line["fixed"]
		if line["along_runs"]:
			out.append(_piece(frame, [line["start"], line["end"]], [fixed - LINE * 0.5, fixed + LINE * 0.5], paint, YELLOW))
		else:
			out.append(_piece(frame, [fixed - LINE * 0.5, fixed + LINE * 0.5], [line["start"], line["end"]], paint, YELLOW))
	# THE HOLD BARS, across each stub at its hold node, solid on the taxiway's side and dashed on the runway's.
	# On a stub to the base's own runway the lines lie along the frame; on one to a crossing runway, across it.
	for name in base.get("holds", {}):
		var hold: Dictionary = base["holds"][name]
		var node: Dictionary = base["nodes"][name]
		var runs_along: bool = hold["along_runs"]
		var at: float = float(node["along"]) if runs_along else float(node["across"])
		var fixed: float = float(node["across"]) if runs_along else float(node["along"])
		var outward: float = float(hold["side"])
		for k in range(HOLD_LINES):
			var here: float = at + outward * (float(k) - float(HOLD_LINES - 1) * 0.5) * LINE * 2.0
			var line_on: Array = [here - LINE * 0.5, here + LINE * 0.5]
			var spans: Array = []
			if k >= HOLD_LINES / 2:
				spans.append([fixed - width * 0.5, fixed + width * 0.5])
			else:
				for d in range(int(floor(width / (HOLD_DASH * 2.0)))):
					var from: float = fixed - width * 0.5 + HOLD_DASH * 0.5 + float(d) * HOLD_DASH * 2.0
					spans.append([from, from + HOLD_DASH])
			for span in spans:
				out.append(_piece(frame, line_on, span, paint, YELLOW) if runs_along else _piece(frame, span, line_on, paint, YELLOW))
	# EACH SPOT: a lead-in line from its mouth to its nose line, and a stop bar across the nose line.
	for id in base["spots"]:
		var spot: Dictionary = base["spots"][id]
		var mouth: Dictionary = base["nodes"][spot["mouth"]]
		var along: float = spot["along"]
		var nose: float = spot["nose"]
		out.append(_piece(frame, [along - LINE * 0.5, along + LINE * 0.5],
			[minf(float(mouth["across"]), nose), maxf(float(mouth["across"]), nose)], paint, YELLOW))
		out.append(_piece(frame, [along - STOP_BAR * 0.5, along + STOP_BAR * 0.5], [nose - LINE * 0.5, nose + LINE * 0.5],
			paint, YELLOW))
	return out


func _draw_the_ground() -> void:
	var node: MultiMeshInstance3D = _boxes(ground_pieces(laid), "Ground")
	# A slab a hand's breadth thick throws no shadow worth a pass.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# THE PAVEMENT, on whichever tier is on. Only the ground: `_boxes` is shared with the structures, and a hangar
	# wall is not pavement -- a slab grid drawn up the side of one would be a joint every 6.10 m of nothing.
	_ground_plain = pavement_paint(PAVEMENT)
	_ground_fine = pavement_paint(PAVEMENT_FINE)
	node.material_override = _ground_plain
	add_child(node)


## A PAVEMENT MATERIAL ON ONE OF THE TWO SHADERS, carrying the ranges `DetailReach` holds and nothing typed here.
## Only the ranges the shader actually declares: PLAIN has no grain and so no `grain_fade`, and a ShaderMaterial will
## happily hold a parameter its shader never reads, which would make a test that asked the material what range it
## carries pass on a shader that cannot use it.
static func pavement_paint(which: Shader) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = which
	var wanted: Dictionary = DetailReach.pavement_numbers()
	var declared: Dictionary = {}
	for uniform in which.get_shader_uniform_list():
		declared[String(uniform["name"])] = true
	for named in wanted:
		if declared.has(named):
			paint.set_shader_parameter(named, wanted[named])
	return paint


## WEAR A FINISH. Called by the level, which owns every air base on the world -- the bases do not listen to `Finish`
## for themselves because they are the level's scenery, the way the sea and the ground are (`Sky._wear_the_finish`).
func wear(fine: bool) -> void:
	var node := get_node_or_null("Ground") as MultiMeshInstance3D
	if node != null and _ground_plain != null:
		node.material_override = _ground_fine if fine else _ground_plain


## WHICH TIER THE PAVEMENT IS ACTUALLY WEARING, read off the node and never off `Finish`. A check that asked the tier
## what the tier was would pass with every base unplugged.
func wears_fine() -> bool:
	var node := get_node_or_null("Ground") as MultiMeshInstance3D
	if node == null or not (node.material_override is ShaderMaterial):
		return false
	return (node.material_override as ShaderMaterial).shader == PAVEMENT_FINE


## ---- the structures -------------------------------------------------------------------------------------------------

## THE WALLS, THE ROOFS AND THE DOORS, and the pitched and arched roofs over them.
func _draw_the_structures() -> void:
	var pieces: Array[Dictionary] = structure_pieces(laid)
	add_child(_boxes(pieces, "Structures"))
	# The solid boxes are the batch's first pieces, one a wall, in the plan's order (`structure_pieces`).
	_solid_drawn = pieces.slice(0, (laid["walls"] as Array).size())
	var roofs := MeshInstance3D.new()
	roofs.name = "Roofs"
	roofs.mesh = roof_mesh(laid, position)
	roofs.material_override = _vertex_colour()
	add_child(roofs)


## EVERY SOLID BOX THIS VIEW DREW, as handed to its batch: what a check that the picture is the physics counts.
func drawn_solid() -> Array[Dictionary]:
	return _solid_drawn


## EVERY STRUCTURAL BOX, as `{position, half_extents, colour}` in the world: the solid walls first, exactly as laid, then
## the detail worked out here.
static func structure_pieces(base: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var frame: Dictionary = base["frame"]
	for wall in base["walls"]:
		var colour: Color = STEEL
		if wall["part"] == "hangar":
			# The flat roof slab is the one hangar box that starts at the clear height and is as thin as the walls.
			var roof: bool = float(wall["up"][0]) > 0.0 and float(wall["up"][1]) - float(wall["up"][0]) < 1.0
			colour = ROOF if roof else CLADDING
		elif wall["part"] in ["terminal", "tower"]:
			colour = CLADDING
		elif wall["part"] == "tower_cab":
			colour = GLASS
		out.append({"position": wall["position"], "half_extents": wall["half_extents"], "colour": colour})
	for wall in base["walls"]:
		if wall["part"] == "revetment":
			out.append_array(_revetment_detail(frame, wall))
	for hangar in base["hangars"]:
		out.append_array(_hangar_detail(frame, hangar))
	for terminal in base.get("terminals", []):
		out.append_array(_terminal_detail(frame, terminal))
	if bool(base["tower"].get("built", false)):
		out.append_array(_tower_detail(frame, base))
	return out


## A TERMINAL'S FACE: two bands of glazing along its airside wall, one a storey, a plinth under them, and a fascia and a
## flat roof's trim along the top -- enough, low-poly, to read as a building with people in it from an aeroplane taxiing
## past, rather than a concrete block.
const STOREY: float = 7.5
const GLAZING_HIGH: float = 4.2
const TERMINAL_PIER: float = 12.0


static func _terminal_detail(frame: Dictionary, terminal: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var along: Array = terminal["along"]
	var across: Array = terminal["across"]
	var airside: float = terminal["airside"]
	var face: float = across[1] if airside > 0.0 else across[0]
	var proud: Array = _outside(face, airside, 0.12)
	var high: float = terminal["height"]
	var storeys: int = maxi(int(floor(high / STOREY)), 1)
	for s in range(storeys):
		var sill: float = float(s) * STOREY + 1.6
		# THE GLAZING, broken by a mullion pier every TERMINAL_PIER metres, as a curtain wall is.
		var panes: int = maxi(int(floor((float(along[1]) - float(along[0])) / TERMINAL_PIER)), 1)
		var pane: float = (float(along[1]) - float(along[0])) / float(panes)
		for p in range(panes):
			var from: float = float(along[0]) + float(p) * pane + PILASTER_WIDTH
			out.append(_piece(frame, [from, from + pane - PILASTER_WIDTH * 2.0], proud, [sill, sill + GLAZING_HIGH], GLASS))
	out.append(_piece(frame, along, _outside(face, airside, PLINTH_PROUD), [0.0, PLINTH_HIGH], PLINTH))
	out.append(_piece(frame, along, _outside(face, airside, FASCIA_PROUD), [high - FASCIA_HIGH, high], TRIM))
	out.append(_piece(frame, along, across, [high, high + 0.4], ROOF))
	return out


## A BUILT TOWER'S DETAIL: a gallery slab round the cab's floor and a dark roof over it, so the glass reads as a cab.
static func _tower_detail(frame: Dictionary, base: Dictionary) -> Array[Dictionary]:
	var tower: Dictionary = base["tower"]
	var cab: float = base["standards"]["tower_cab"]
	var high: float = base["standards"]["tower_height"]
	var along: float = tower["along"]
	var across: float = tower["across"]
	var floor_at: float = high - cab * 0.6
	var reach: float = cab * 0.5 + 1.2
	return [_piece(frame, [along - reach, along + reach], [across - reach, across + reach], [floor_at - 0.6, floor_at], PLINTH),
		_piece(frame, [along - reach + 0.6, along + reach - 0.6], [across - reach + 0.6, across + reach - 0.6],
			[high, high + 0.8], TRIM)]


## A REVETMENT WALL'S EARTH AND SEAMS: earth heaped along its top, and a seam at every bin down both long faces.
static func _revetment_detail(frame: Dictionary, wall: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var along: Array = wall["along"]
	var across: Array = wall["across"]
	var high: float = wall["up"][1]
	out.append(_piece(frame, along, across, [high, high + EARTH_CAP], EARTH))
	var runs_along: bool = float(along[1]) - float(along[0]) > float(across[1]) - float(across[0])
	var run: Array = along if runs_along else across
	var faces: Array = across if runs_along else along
	var seams: int = int(floor((float(run[1]) - float(run[0])) / BIN_LENGTH))
	for k in range(1, seams + 1):
		var at: float = float(run[0]) + float(k) * BIN_LENGTH
		var strip: Array = [at - SEAM_WIDTH * 0.5, at + SEAM_WIDTH * 0.5]
		for proud in [[float(faces[0]) - SEAM_PROUD, float(faces[0])], [float(faces[1]), float(faces[1]) + SEAM_PROUD]]:
			out.append(_piece(frame, strip if runs_along else proud, proud if runs_along else strip, [0.0, high], SEAM))
	return out


## A HANGAR'S DETAIL: pilasters down its sides and back, a plinth, fascia along its eaves and over its door, panel lines
## on its header, and its door leaves stacked open.
static func _hangar_detail(frame: Dictionary, hangar: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var along: float = hangar["along"]
	var width: float = hangar["width"]
	var half_width: float = width * 0.5
	var door: float = hangar["door"]
	var inward: float = hangar["inward"]
	var back: float = door + inward * float(hangar["depth"])
	var near: float = minf(door, back)
	var far: float = maxf(door, back)
	var clear: float = hangar["clear_height"]
	var skin: float = hangar["skin"]
	var door_half: float = float(hangar["door_width"]) * 0.5
	var door_high: float = hangar["door_height"]
	# PILASTERS down both sides, on their outer faces, and across the back.
	var bays: int = maxi(1, int(round((far - near) / PILASTER_BAY)))
	for k in range(bays + 1):
		var at: float = near + (far - near) * float(k) / float(bays)
		for side in [-1.0, 1.0]:
			out.append(_piece(frame, _outside(along + side * half_width, side, PILASTER_PROUD),
				[at - PILASTER_WIDTH * 0.5, at + PILASTER_WIDTH * 0.5], [0.0, clear], PILASTER))
	var back_bays: int = maxi(1, int(round(width / PILASTER_BAY)))
	for k in range(back_bays + 1):
		var at: float = along - half_width + width * float(k) / float(back_bays)
		out.append(_piece(frame, [at - PILASTER_WIDTH * 0.5, at + PILASTER_WIDTH * 0.5],
			_outside(back, inward, PILASTER_PROUD), [0.0, clear], PILASTER))
	# THE PLINTH round the sides and back.
	for side in [-1.0, 1.0]:
		out.append(_piece(frame, _outside(along + side * half_width, side, PLINTH_PROUD), [near, far], [0.0, PLINTH_HIGH],
			PLINTH))
	out.append(_piece(frame, [along - half_width, along + half_width], _outside(back, inward, PLINTH_PROUD),
		[0.0, PLINTH_HIGH], PLINTH))
	# THE FASCIA along both eaves, under the roof's overhang, and across the front at the top of the door's header.
	var eave: float = clear + skin
	for side in [-1.0, 1.0]:
		out.append(_piece(frame, _outside(along + side * half_width, side, OVERHANG),
			[near - OVERHANG, far + OVERHANG], [eave - FASCIA_HIGH, eave], TRIM))
	out.append(_piece(frame, [along - half_width, along + half_width], _outside(door, -inward, FASCIA_PROUD),
		[clear - FASCIA_HIGH, clear], TRIM))
	# THE HEADER'S PANEL LINES, one over each leaf joint, where the door is lower than the roof.
	var leaf: float = float(hangar["door_width"]) / float(LEAVES_A_SIDE * 2)
	if clear - door_high > 0.01:
		for k in range(1, LEAVES_A_SIDE * 2):
			var at: float = along - door_half + float(k) * leaf
			out.append(_piece(frame, [at - 0.06, at + 0.06], _outside(door, -inward, 0.05), [door_high, clear - FASCIA_HIGH],
				TRIM))
	# THE DOOR LEAVES, stacked open at each end of the opening, each stepped in behind and out from the one in front.
	for side in [-1.0, 1.0]:
		var edge: float = along + side * door_half
		for k in range(LEAVES_A_SIDE):
			var inner: float = edge - side * leaf + side * float(k) * LEAF_STEP_OUT
			var outer: float = edge + side * float(k) * LEAF_STEP_OUT
			var face: float = door + inward * (0.15 + float(k) * LEAF_STEP_IN)
			var span: Array = [minf(inner, outer), maxf(inner, outer)]
			out.append(_piece(frame, span, _outside(face, inward, LEAF_THICK), [0.0, door_high - 0.05], DOOR))
			if k != 0:
				continue
			var front: Array = _outside(face, -inward, 0.04)
			for share in LEAF_RIBS:
				out.append(_piece(frame, span, front, [door_high * share - RIB_HIGH * 0.5, door_high * share + RIB_HIGH * 0.5],
					DOOR_RIB))
			out.append(_piece(frame, [float(span[0]) + 0.3, float(span[1]) - 0.3], front,
				[door_high * WINDOW_BAND.x, door_high * WINDOW_BAND.y], GLASS))
	return out


## An interval from a face outwards, `direction` being +1 or -1 along its axis.
static func _outside(face: float, direction: float, thick: float) -> Array:
	return [minf(face, face + direction * thick), maxf(face, face + direction * thick)]


static func _piece(frame: Dictionary, along: Array, across: Array, up: Array, colour: Color) -> Dictionary:
	var box: Dictionary = AirbasePlan.frame_box(frame, along, across, up)
	box["colour"] = colour
	return box


## ---- the roofs ------------------------------------------------------------------------------------------------------

## EVERY HANGAR'S ROOF AND ITS GABLE OR ARCH ENDS, merged into one mesh with its vertices relative to `origin`: a gable of
## GABLE_PITCH, or a segmental vault rising ARCH_RISE of the width, each overhanging by OVERHANG, over the flat solid roof.
static func roof_mesh(base: Dictionary, origin: Vector3) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frame: Dictionary = base["frame"]
	for hangar in base["hangars"]:
		var along: float = hangar["along"]
		var half: float = float(hangar["width"]) * 0.5
		var door: float = hangar["door"]
		var back: float = door + float(hangar["inward"]) * float(hangar["depth"])
		var near: float = minf(door, back)
		var far: float = maxf(door, back)
		var eave: float = float(hangar["clear_height"]) + float(hangar["skin"])
		var inside: Vector3 = _at(frame, along, (near + far) * 0.5, eave * 0.5) - origin
		# The roof's cross-section across the width, eave to eave, as [along offset, height] points.
		var section: Array[Vector2] = []
		var span: float = half + OVERHANG
		if hangar["roof"] == "arch":
			var rise: float = float(hangar["width"]) * ARCH_RISE
			var radius: float = (span * span + rise * rise) / (2.0 * rise)
			var reach: float = asin(span / radius)
			for k in range(ARCH_SEGMENTS + 1):
				var angle: float = -reach + 2.0 * reach * float(k) / float(ARCH_SEGMENTS)
				section.append(Vector2(sin(angle) * radius, eave + rise - radius + cos(angle) * radius))
		elif hangar["roof"] == "gable":
			var ridge: float = eave + span * tan(deg_to_rad(GABLE_PITCH))
			section.append_array([Vector2(-span, eave), Vector2(0.0, ridge), Vector2(span, eave)])
		else:
			continue
		# THE ROOF: a strip of quads down the depth, overhanging front and back.
		for k in range(section.size() - 1):
			var a: Vector2 = section[k]
			var b: Vector2 = section[k + 1]
			var p: Vector3 = _at(frame, along + a.x, near - OVERHANG, a.y) - origin
			var q: Vector3 = _at(frame, along + b.x, near - OVERHANG, b.y) - origin
			var r: Vector3 = _at(frame, along + b.x, far + OVERHANG, b.y) - origin
			var s: Vector3 = _at(frame, along + a.x, far + OVERHANG, a.y) - origin
			_triangle(tool, p, q, r, inside, ROOF)
			_triangle(tool, p, r, s, inside, ROOF)
		# THE ENDS above the walls, front and back: a fan from the middle of the eave line, within the walls' width.
		for end in [near, far]:
			var middle: Vector3 = _at(frame, along, end, eave) - origin
			for k in range(section.size() - 1):
				var a_along: float = clampf(section[k].x, -half, half)
				var b_along: float = clampf(section[k + 1].x, -half, half)
				if absf(b_along - a_along) < 0.001:
					continue
				_triangle(tool, middle, _at(frame, along + a_along, end, _height_on(section, a_along)) - origin,
					_at(frame, along + b_along, end, _height_on(section, b_along)) - origin, inside, CLADDING)
	return tool.commit()


## A section's height at an along offset, by straight lines between its points.
static func _height_on(section: Array[Vector2], along: float) -> float:
	for k in range(section.size() - 1):
		var a: Vector2 = section[k]
		var b: Vector2 = section[k + 1]
		if along >= a.x - 0.0001 and along <= b.x + 0.0001:
			return lerpf(a.y, b.y, 0.0 if absf(b.x - a.x) < 0.0001 else (along - a.x) / (b.x - a.x))
	return section[0].y


static func _at(frame: Dictionary, along: float, across: float, up: float) -> Vector3:
	return AirbasePlan.frame_point(frame, along, across) + Vector3.UP * up


## ONE TRIANGLE, facing away from `inside`. Godot's front faces wind clockwise seen from the front, so the cross product of
## a front face's first two edges points into the building; the normal given is the outward one.
static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, colour: Color) -> void:
	var outward: Vector3 = ((a + b + c) / 3.0 - inside).normalized()
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
	var normal: Vector3 = -(b - a).cross(c - a).normalized()
	for corner in [a, b, c]:
		tool.set_color(colour)
		tool.set_normal(normal)
		tool.add_vertex(corner)


static func _vertex_colour() -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = 0.92
	return paint


## A MULTIMESH OF COLOURED UNIT BOXES, one a piece, each an offset from this view's position.
func _boxes(pieces: Array[Dictionary], called: String) -> MultiMeshInstance3D:
	var slabs := MultiMesh.new()
	var block := BoxMesh.new()
	block.size = Vector3.ONE
	slabs.transform_format = MultiMesh.TRANSFORM_3D
	slabs.use_colors = true
	slabs.mesh = block
	slabs.instance_count = pieces.size()
	for i in range(pieces.size()):
		var piece: Dictionary = pieces[i]
		# TURNED IN ITS OWN FRAME, then scaled: an exit's slab and its line lie at 30 degrees to everything else.
		slabs.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(piece.get("yaw", 0.0)))
			* Basis.from_scale((piece["half_extents"] as Vector3) * 2.0), (piece["position"] as Vector3) - position))
		slabs.set_instance_color(i, piece["colour"])
	var node := MultiMeshInstance3D.new()
	node.name = called
	node.multimesh = slabs
	node.material_override = _vertex_colour()
	return node
