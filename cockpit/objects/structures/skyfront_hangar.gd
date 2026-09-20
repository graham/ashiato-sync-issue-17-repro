@tool
extends Node3D
class_name SkyfrontHangar
## HANGAR 03, SKYFRONT MODULAR GROUND OPERATIONS: the user's concept sheet, built as geometry.
##
## The sheet is `structures/hangar_03/hanger_v1.webp`, the user's own concept art, given on 2026-09-17 with "the fidelity
## and colours and design is important". Every number below was measured off it against the dimension arrow drawn in the
## same panel, and `structures/hangar_03/sources.md` holds those measurements, the two places where the sheet contradicts
## itself, and how each was settled. In short: the building is 32 m across its door face, 40 m deep and 12.0 m to the top
## of its roof spine, with a 24 x 8 m clear opening.
##
## MODULAR, BECAUSE THE SHEET SAYS SO ("scalable layout. same parts. new horizons."). A bay is 10 m and the depth is a
## COUNT of bays, so a longer hangar is `bays = 6` and not a second model. Nothing structural is typed twice: the ribs,
## the base housings, the roof strips and the railings are all emitted per bay, and the suite reads every dimension back
## off the welded vertices rather than off these constants (`tests/hangar.gd`).
##
## ONE WELDED MESH, ONE MATERIAL, as every ship here is drawn (`Plating`): the whole shell -- panels, ribs, towers,
## railings, door frame, roof, markings and the "03" itself -- is one `SurfaceTool` with the colour in the vertices, so
## the hangar costs triangles, which a headset has to spare, rather than draw calls, which it does not. The riveted panel
## detail is in `world/shaders/hangar_panel.gdshader`, computed in metres from the object's own vertices; COLOR.a chooses
## how much of it a surface takes. The only other draws are the emissive interior light strips and two `Label3D`s of
## small print.
##
## LOW POLY ON PURPOSE (the user, 2026-09-17; `aircraft_model_fidelity_plan.md`, "The look"): flat panels, hard creases,
## no rounded edges, and `MAST_SIDES` = 6 on the only round thing in it. A retessellation must leave every dimension the
## suite measures unchanged.
##
## THE DOOR IS OPEN AND HAS NO LEAVES. The sheet's front elevation is captioned "DOOR OPEN" and draws no leaf: the
## opening is a deep dark portal with a yellow lintel. Leaves that slide into the flanks are a later job; nothing here
## pretends to move (rule 5).
##
## WHAT IT DOES NOT DO: it is a building, not a craft. It has no authority over anything, it is not replicated, and its
## collision is the list of static boxes `boxes()` returns, which the level hands to `Sim.add_static_box` -- one list for
## the picture and the simulation, as `BriefingRoom` does it.

## ---------------------------------------------------------------------------------------------------------------------
## THE DIMENSIONS, ALL MEASURED OFF THE SHEET. See structures/hangar_03/sources.md for each measurement.
## ---------------------------------------------------------------------------------------------------------------------
## Across the door face, metres, to the OUTER faces of the corner towers and the side ribs. The sheet's own 40 m arrow
## lands on those faces in the side elevation (measured 40.2 m), so the width is read the same way.
const SPAN: float = 32.0
## One bay of the long side. Measured rib centres: 0, 10.4, 19.3, 28.6, 40.2 m.
const BAY: float = 10.0
## Bays deep unless told otherwise: 4 x 10 m = the sheet's 40 m.
const BAYS_DEFAULT: int = 4
## Bays across the 32 m faces: the rear elevation's three panels between four ribs.
const FACE_BAYS: int = 3
## Ground to the top of the raised roof spine. The sheet's title says 12 m; its two width-dimensioned elevations put the
## spine top at 12.1 m and 12.8 m, and its side elevation's "32 m (HEIGHT)" is the width repeated (sources.md).
const SPINE_TOP: float = 12.0
## Where the roof slopes stop and the spine's shoulder begins.
const SHOULDER: float = 11.0
## Top of the wall. Measured eave share of total height: 0.740, 0.703, 0.706; raised to 9.2 m so an 8 m door has a head.
const EAVE: float = 9.2
## The corner masts' tips, +0.6 m over the spine, measured.
const MAST_TOP: float = 12.6
const MAST_SIDES: int = 6
## THE CLEAR OPENING, stated twice in words on the sheet. It is drawn 6.9 m tall there; the words win (sources.md).
const OPENING_WIDE: float = 24.0
const OPENING_HIGH: float = 8.0
## The yellow lintel band over the opening, and the riveted head beam above it: 1.2 m of head in all.
const LINTEL_TALL: float = 0.4
## A structural rib: across the wall, and how far it stands proud of the wall panels.
const RIB_WIDE: float = 2.2
const RIB_PROUD: float = 0.9
## A corner tower, in plan. The two front ones are 2.8 m across instead, because a 24 m opening inside a 32 m face
## leaves each flank exactly 4.0 m: 1.2 m of jamb pillar and 2.8 m of tower.
const TOWER: float = 3.6
const JAMB_WIDE: float = 1.2
## The wall panels themselves.
const WALL: float = 0.5
## The raised armoured spine, in plan: measured 14.2 m along the top view and 12.3 m across the front elevation.
const SPINE_LONG: float = 14.0
const SPINE_WIDE: float = 12.0
## How wide the gunmetal rim round the spine's deck is. It is a rim: the light deck inside it is what the "03" is painted
## on, and a rim as wide as the deck is a lid.
const RIM_WIDE: float = 0.7
## THE WALL BANDS, ground upward, as fractions of the eave measured on the side and rear elevations. One list, drawn per
## wall, so the front flanks, the sides and the rear cannot drift apart.
const BANDS: Array = [
	[0.0, 1.9, "housing"],   # armoured service housings along the base
	[1.9, 2.4, "girder"],    # the dark girder band over them
	[2.4, 7.3, "panel"],     # the main riveted armour field, where the X bracing goes
	[7.3, 8.0, "louvre"],    # the dark strip above it
	[8.0, 8.8, "panel"],     # the upper riveted band
	[8.8, 9.2, "cap"],       # the eave cap beam
]
## How far the roof overhangs the wall face, and how thick its fascia is.
const EAVE_PROUD: float = 0.35
const FASCIA: float = 0.45
## The safety railing: how tall, how far apart its posts, and how thick.
const RAIL_TALL: float = 1.05
const RAIL_STEP: float = 2.0
const RAIL_THICK: float = 0.08
## Marking sizes. The sheet draws the wall digits 1.1 m tall in the front elevation and larger in the hero; 1.6 m on the
## 2.8 m tower face is the compromise. The roof pair is measured 4.4 m tall.
const WALL_DIGITS: float = 1.6
const ROOF_DIGITS: float = 4.4
const SIGN_WIDE: float = 1.7
const SIGN_TALL: float = 4.4

## ---------------------------------------------------------------------------------------------------------------------
## THE PAINT, sampled from the sheet with a twelve-colour median cut and patch medians (sources.md). AS sRGB, like every
## colour in this project's models, and the alpha is HOW MUCH RIVETED PANEL DETAIL the surface takes, not transparency.
## ---------------------------------------------------------------------------------------------------------------------
const PANEL := Color(0.860, 0.850, 0.836, 1.0)
const PANEL_SHADE := Color(0.780, 0.768, 0.752, 1.0)
const GUNMETAL := Color(0.175, 0.180, 0.195, 0.35)
const STEEL := Color(0.310, 0.300, 0.305, 0.35)
const DARK := Color(0.075, 0.075, 0.078, 0.20)
const YELLOW := Color(0.820, 0.580, 0.120, 0.0)
const YELLOW_DEEP := Color(0.660, 0.450, 0.090, 0.0)
const CONCRETE := Color(0.620, 0.620, 0.628, 0.55)
const LIGHT_STRIP := Color(1.0, 0.94, 0.82, 1.0)

## HOW DEEP A MARKING SITS OFF THE WALL IT IS PAINTED ON: enough that no z-fight can reach it, little enough that it
## reads as paint. A marking at 0.0 flickered against its own wall at 30 m.
const PAINT_PROUD: float = 0.03

## How many bays deep this hangar is. Set before it enters the tree, or call `rebuild`.
@export var bays: int = BAYS_DEFAULT:
	set(value):
		bays = maxi(2, value)
		if is_inside_tree():
			rebuild()
## The number on the roof and the door pillar, and the pad sign on the other pillar.
@export var hangar_number: String = "03"
@export var pad_sign: String = "H3"
## Whether the interior light strips are lit. A hangar with its lights off is still a hangar.
@export var lights_on: bool = true

var shell: MeshInstance3D = null
var strips: MeshInstance3D = null


## HOW DEEP THIS HANGAR IS, metres: the bay count times the bay. Asked, never typed beside the bay count.
func depth() -> float:
	return float(bays) * BAY


static func depth_of(bay_count: int) -> float:
	return float(maxi(2, bay_count)) * BAY


## WHERE THE SOLID IS, for `Sim.add_static_box` and for anything that wants to know what a body can hit: one list, in the
## level's own coordinates, offset by where the hangar stands. `add_static_box` has no rotation, so the hangar faces +Z
## and an offset is all a level may give it (agents.md, "A yaw is a quarter turn or nothing").
##
## The interior is left clear and so is the opening: the front wall is two flanks and a head beam, and the roof is one
## lid at the eave rather than the sloped plates, because a body inside a hangar needs a ceiling, not a wedge.
static func boxes(at: Vector3 = Vector3.ZERO, bay_count: int = BAYS_DEFAULT) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var deep: float = depth_of(bay_count)
	var half_deep: float = deep * 0.5
	var half_span: float = SPAN * 0.5
	var face_x: float = half_span - RIB_PROUD
	var face_z: float = half_deep - RIB_PROUD
	var half_high: float = EAVE * 0.5
	# The two long walls, from the rear wall to the door plane.
	for side in [-1.0, 1.0]:
		out.append({"position": at + Vector3(side * (face_x - WALL * 0.5), half_high, 0.0),
			"half_extents": Vector3(WALL * 0.5, half_high, face_z)})
	# The rear wall.
	out.append({"position": at + Vector3(0.0, half_high, -(face_z - WALL * 0.5)),
		"half_extents": Vector3(face_x, half_high, WALL * 0.5)})
	# The door face: a flank either side of the opening, and the head beam over it.
	var flank: float = face_x - OPENING_WIDE * 0.5
	for side in [-1.0, 1.0]:
		out.append({"position": at + Vector3(side * (OPENING_WIDE * 0.5 + flank * 0.5), half_high, face_z - WALL * 0.5),
			"half_extents": Vector3(flank * 0.5, half_high, WALL * 0.5)})
	out.append({"position": at + Vector3(0.0, (OPENING_HIGH + EAVE) * 0.5, face_z - WALL * 0.5),
		"half_extents": Vector3(OPENING_WIDE * 0.5, (EAVE - OPENING_HIGH) * 0.5, WALL * 0.5)})
	# The lid over the interior, at the eave: everything above it is roof.
	out.append({"position": at + Vector3(0.0, EAVE + FASCIA * 0.5, 0.0),
		"half_extents": Vector3(half_span, FASCIA * 0.5, half_deep)})
	# The four corner towers and every rib, so a body cannot walk through the structure that stands proud of the wall.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			out.append({"position": at + Vector3(sx * (half_span - TOWER * 0.5), half_high, sz * (half_deep - TOWER * 0.5)),
				"half_extents": Vector3(TOWER * 0.5, half_high, TOWER * 0.5)})
	for index in range(1, bay_count):
		var z: float = -half_deep + float(index) * BAY
		for sx in [-1.0, 1.0]:
			out.append({"position": at + Vector3(sx * (half_span - RIB_PROUD * 0.5), half_high, z),
				"half_extents": Vector3(RIB_PROUD * 0.5, half_high, RIB_WIDE * 0.5)})
	for index in range(1, FACE_BAYS):
		var x: float = -half_span + float(index) * (SPAN / float(FACE_BAYS))
		out.append({"position": at + Vector3(x, half_high, -(half_deep - RIB_PROUD * 0.5)),
			"half_extents": Vector3(RIB_WIDE * 0.5, half_high, RIB_PROUD * 0.5)})
	return out


## HOW WIDE A TOWER AT THE DOOR IS: whatever the 24 m opening leaves of the 32 m face once the jamb pillar has its
## share. Asked, never typed: the sheet draws a 3.1 m block and a 1.8 m pillar, which with a 24 m opening would make the
## face 35 m wide (sources.md).
static func front_tower_wide() -> float:
	return SPAN * 0.5 - OPENING_WIDE * 0.5 - JAMB_WIDE


## WHERE THE MARKINGS GO ON THE DOOR FACE: the middle of a front tower's own face, and how far out that face stands.
static func front_tower_middle() -> float:
	return SPAN * 0.5 - front_tower_wide() * 0.5


## THE CLEAR OPENING, as a box a craft must fit through: its centre and half-extents in the hangar's own frame. The suite
## drives a fighter-sized body through this, and the level parks nothing inside it.
static func opening(at: Vector3 = Vector3.ZERO, bay_count: int = BAYS_DEFAULT) -> Dictionary:
	var face_z: float = depth_of(bay_count) * 0.5 - RIB_PROUD
	return {"position": at + Vector3(0.0, OPENING_HIGH * 0.5, face_z),
		"half_extents": Vector3(OPENING_WIDE * 0.5, OPENING_HIGH * 0.5, WALL * 0.5)}


func _ready() -> void:
	if shell == null:
		rebuild()


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_walls(tool)
	_structure(tool)
	_portal(tool)
	_roof(tool)
	_interior(tool)
	_markings(tool)
	shell = MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = Plating.weld(tool)
	shell.material_override = armour()
	add_child(shell)
	_light_strips()
	_small_print()


## THE ONE MATERIAL THE SHELL IS DRAWN WITH: the riveted panel shader, which reads the tint and the detail strength out
## of the vertices. One `ShaderMaterial` a hangar, so two hangars in a level are two draws and not two thousand.
static func armour() -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = load("res://world/shaders/hangar_panel.gdshader") as Shader
	return paint


## ---------------------------------------------------------------------------------------------------------------------
## THE WALLS
## ---------------------------------------------------------------------------------------------------------------------

func _walls(tool: SurfaceTool) -> void:
	var half_deep: float = depth() * 0.5
	var face_x: float = SPAN * 0.5 - RIB_PROUD
	var face_z: float = half_deep - RIB_PROUD
	for band in BANDS:
		var bottom: float = band[0]
		var top: float = band[1]
		var role: String = band[2]
		var middle: float = (bottom + top) * 0.5
		var tall: float = top - bottom
		var tint: Color = _band_tint(role)
		# The two long walls.
		for side in [-1.0, 1.0]:
			Plating.box(tool, Vector3(side * (face_x - WALL * 0.5), middle, 0.0),
				Vector3(WALL, tall, face_z * 2.0), tint)
		# The rear wall.
		Plating.box(tool, Vector3(0.0, middle, -(face_z - WALL * 0.5)),
			Vector3(face_x * 2.0, tall, WALL), tint)
		# The door face, either side of the opening.
		var flank: float = face_x - OPENING_WIDE * 0.5
		for side in [-1.0, 1.0]:
			Plating.box(tool, Vector3(side * (OPENING_WIDE * 0.5 + flank * 0.5), middle, face_z - WALL * 0.5),
				Vector3(flank, tall, WALL), tint)
	# THE HEAD OVER THE OPENING: a riveted beam from the lintel to the eave, and the yellow lintel band under it.
	var head_bottom: float = OPENING_HIGH + LINTEL_TALL
	Plating.box(tool, Vector3(0.0, (head_bottom + EAVE) * 0.5, face_z - WALL * 0.5),
		Vector3(OPENING_WIDE, EAVE - head_bottom, WALL), PANEL)
	Plating.box(tool, Vector3(0.0, OPENING_HIGH + LINTEL_TALL * 0.5, face_z - WALL * 0.5 + 0.06),
		Vector3(OPENING_WIDE, LINTEL_TALL, WALL + 0.12), YELLOW)
	# THE X BRACING: the end bays of each long side and the outer bays of the rear face carry it, the middle bays a rail.
	_bracing(tool)


func _band_tint(role: String) -> Color:
	match role:
		"housing": return STEEL
		"girder": return GUNMETAL
		"louvre": return GUNMETAL
		"cap": return GUNMETAL
		"panel": return PANEL
	return PANEL


## THE CROSS BRACING, over the main panel field. Two crossed bars in the end bays of each long side and the outer bays of
## the rear, as both elevations and the rear three-quarter view draw them; the bays between get one horizontal rail.
func _bracing(tool: SurfaceTool) -> void:
	var bottom: float = float(BANDS[2][0]) + 0.25
	var top: float = float(BANDS[2][1]) - 0.25
	var face_x: float = SPAN * 0.5 - RIB_PROUD
	var face_z: float = depth() * 0.5 - RIB_PROUD
	var half_deep: float = depth() * 0.5
	var braced_side: Array[int] = [0, bays - 1]
	for index in range(bays):
		# THE BAY JOINTS ARE ON THE ENVELOPE, NOT ON THE WALL FACE: a bay is 10 m from the building's own end, and the
		# wall panels are inset from that end by the ribs' 0.9 m. Measuring bays from the inset face put the last bay's
		# brace 0.9 m past the door face and measured the building 40.99 m deep (tests/hangar.gd, 2026-09-17).
		var from_z: float = -half_deep + float(index) * BAY + (RIB_WIDE * 0.5 if index > 0 else TOWER * 0.5)
		var to_z: float = -half_deep + float(index + 1) * BAY - (RIB_WIDE * 0.5 if index < bays - 1 else TOWER * 0.5)
		for side in [-1.0, 1.0]:
			var x: float = side * (face_x - WALL - 0.12)
			if braced_side.has(index):
				_cross(tool, Vector3(x, bottom, from_z), Vector3(x, top, to_z), Vector3(1.0, 0.0, 0.0) * side)
			else:
				Plating.box(tool, Vector3(x, (bottom + top) * 0.5, (from_z + to_z) * 0.5),
					Vector3(0.22, 0.30, to_z - from_z), GUNMETAL)
	var face_step: float = SPAN / float(FACE_BAYS)
	for index in range(FACE_BAYS):
		var from_x: float = -SPAN * 0.5 + float(index) * face_step + (RIB_WIDE * 0.5 if index > 0 else TOWER * 0.5)
		var to_x: float = -SPAN * 0.5 + float(index + 1) * face_step - (RIB_WIDE * 0.5 if index < FACE_BAYS - 1 else TOWER * 0.5)
		var z: float = -(face_z - WALL - 0.12)
		if index == 0 or index == FACE_BAYS - 1:
			_cross(tool, Vector3(from_x, bottom, z), Vector3(to_x, top, z), Vector3(0.0, 0.0, -1.0))
		else:
			Plating.box(tool, Vector3((from_x + to_x) * 0.5, (bottom + top) * 0.5, z),
				Vector3(to_x - from_x, 0.30, 0.22), GUNMETAL)


## TWO CROSSED BARS over a panel, on a wall that faces `out`. The bay is given as two opposite corners of the panel.
##
## A bar is a box turned about the wall's own outward axis. On a long side (`out` along x) the bay runs along z, so the
## bar is long in z and leans about x; on the rear face (`out` along z) it runs along x and leans about z. The lean is
## the panel's own diagonal, so a wider bay makes a shallower X and nothing is typed twice.
func _cross(tool: SurfaceTool, low: Vector3, high: Vector3, out: Vector3) -> void:
	var thick: float = 0.20
	var run: float = Vector2(high.x - low.x, high.z - low.z).length()
	var rise: float = high.y - low.y
	if run < 0.5 or rise < 0.5:
		return
	var middle: Vector3 = (low + high) * 0.5
	var diagonal: float = sqrt(run * run + rise * rise)
	var lean: float = atan2(rise, run)
	var along_z: bool = absf(out.x) > 0.5
	for sense in [1.0, -1.0]:
		var turn: Basis = Basis(Vector3(1.0, 0.0, 0.0), sense * lean) if along_z \
			else Basis(Vector3(0.0, 0.0, 1.0), -sense * lean)
		var bar_size: Vector3 = Vector3(thick, thick, diagonal) if along_z else Vector3(diagonal, thick, thick)
		Plating.box(tool, middle, bar_size, GUNMETAL, turn)
	# And the plate where they cross.
	Plating.box(tool, middle, Vector3(0.26 if along_z else 0.5, 0.5, 0.5 if along_z else 0.26), STEEL)


## ---------------------------------------------------------------------------------------------------------------------
## THE STRUCTURE: ribs, corner towers, masts, base housings, railings
## ---------------------------------------------------------------------------------------------------------------------

func _structure(tool: SurfaceTool) -> void:
	var half_span: float = SPAN * 0.5
	var half_deep: float = depth() * 0.5
	# EVERY RIB DOWN THE LONG SIDES, one per bay joint, standing 0.9 m proud of the wall with a yellow edge strip and a
	# lamp bracket at the top -- and at the middle joints a capped tower head, as the sheet's side elevation draws.
	for index in range(1, bays):
		var z: float = -half_deep + float(index) * BAY
		for side in [-1.0, 1.0]:
			_rib(tool, Vector3(side * (half_span - RIB_PROUD * 0.5), 0.0, z),
				Vector3(RIB_PROUD, 0.0, RIB_WIDE), Vector3(side, 0.0, 0.0))
			# A CAPPED TOWER HEAD ON EVERY OTHER RIB, which on the sheet's 40 m puts one at 10 m and one at 30 m.
			if index % 2 == 1:
				_tower_head(tool, Vector3(side * (half_span - RIB_PROUD - 0.4), 0.0, z), 1.6)
	# AND ACROSS THE REAR FACE: three bays, so two ribs.
	for index in range(1, FACE_BAYS):
		var x: float = -half_span + float(index) * (SPAN / float(FACE_BAYS))
		_rib(tool, Vector3(x, 0.0, -(half_deep - RIB_PROUD * 0.5)),
			Vector3(RIB_WIDE, 0.0, RIB_PROUD), Vector3(0.0, 0.0, -1.0))
	# THE FOUR CORNER TOWERS, each with a mast on it. The two at the door are 2.8 m across, because the 24 m opening in a
	# 32 m face leaves 4.0 m of flank and 1.2 m of that is the jamb pillar.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var across: float = front_tower_wide() if sz > 0.0 else TOWER
			var centre := Vector3(sx * (half_span - across * 0.5), 0.0, sz * (half_deep - TOWER * 0.5))
			_corner_tower(tool, centre, Vector3(across, 0.0, TOWER))
	_base_housings(tool)
	_railings(tool)


## ONE RIB: a gunmetal buttress standing proud of the wall, with a yellow strip up its outer edge, bolt plates at the
## bands, and a bracket and a lamp at the top. `size` is its plan footprint; `out` is the way it faces.
##
## NOTHING ON A RIB STANDS OUTSIDE THE ENVELOPE. The rib's outer face IS the 32 x 40 m line the sheet dimensions, so
## every fitting on it is flush with that face or inside it, and the plates widen ALONG the wall rather than out of it.
## The first draft hung the lamp 0.18 m off the face and widened the plates 0.11 m all round, and the suite measured the
## building 34.16 m across a 32 m face -- the fitting, not the building.
func _rib(tool: SurfaceTool, at: Vector3, size: Vector3, out: Vector3) -> void:
	var top: float = EAVE + 0.5
	# The rib's two axes in plan: out of the wall, and along it.
	var facing: Vector3 = out.normalized()
	var along := Vector3(absf(facing.z), 0.0, absf(facing.x))
	var proud: float = absf(facing.x) * size.x + absf(facing.z) * size.z
	var wide: float = along.x * size.x + along.z * size.z
	var plan := func(out_deep: float, along_wide: float) -> Vector3:
		return Vector3(absf(facing.x) * out_deep + along.x * along_wide, 0.0,
			absf(facing.z) * out_deep + along.z * along_wide)
	var face: Vector3 = facing * proud * 0.5
	Plating.box(tool, at + Vector3(0.0, top * 0.5, 0.0), plan.call(proud, wide) + Vector3(0.0, top, 0.0), GUNMETAL)
	# The two flanges either side, which is what gives the sheet's ribs their doubled look.
	for side in [-1.0, 1.0]:
		Plating.box(tool, at + Vector3(0.0, top * 0.5, 0.0) + along * side * (wide * 0.5 - 0.16),
			plan.call(proud * 0.96, 0.32) + Vector3(0.0, top, 0.0), STEEL)
	# The yellow strip up the outer face: paint, so its own outer skin sits ON the envelope line and not past it.
	Plating.box(tool, at + Vector3(0.0, top * 0.5, 0.0) + face - facing * 0.03,
		plan.call(0.06, wide * 0.34) + Vector3(0.0, top, 0.0), YELLOW)
	# The bolt plates at every band joint, wider along the wall only.
	for band in BANDS:
		Plating.box(tool, at + Vector3(0.0, float(band[1]), 0.0),
			plan.call(proud, wide + 0.3) + Vector3(0.0, 0.22, 0.0), STEEL)
	# The bracket at the top, and the lamp under it that the sheet hangs on every rib, recessed into the rib's face.
	Plating.box(tool, at + Vector3(0.0, top - 0.3, 0.0),
		plan.call(proud * 0.9, wide * 0.7 + 0.3) + Vector3(0.0, 0.5, 0.0), YELLOW_DEEP)
	Plating.box(tool, at + Vector3(0.0, EAVE - 1.2, 0.0) + face - facing * 0.15,
		plan.call(0.3, 0.5) + Vector3(0.0, 0.22, 0.0), DARK)


## A CORNER TOWER: a panelled block a little over the eave, a stepped gunmetal cap, a yellow rail round it, and a
## six-sided mast. Six sides because the models here are faceted on purpose.
func _corner_tower(tool: SurfaceTool, at: Vector3, size: Vector3) -> void:
	var block_top: float = EAVE + 0.6
	Plating.box(tool, at + Vector3(0.0, block_top * 0.5, 0.0), Vector3(size.x, block_top, size.z), PANEL)
	# The vertical gunmetal corner posts, which is what makes the sheet's towers read as armoured rather than as boxes.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Plating.box(tool, at + Vector3(sx * (size.x * 0.5 - 0.16), block_top * 0.5, sz * (size.z * 0.5 - 0.16)),
				Vector3(0.36, block_top, 0.36), GUNMETAL)
	# The cap and its rail stay INSIDE the 32 x 40 m line: the tower's own face is that line, and a cap 0.15 m proud of
	# it measured the building 0.3 m wider than the sheet says (tests/hangar.gd, 2026-09-17).
	Plating.box(tool, at + Vector3(0.0, block_top + 0.2, 0.0), Vector3(size.x, 0.4, size.z), GUNMETAL)
	Plating.box(tool, at + Vector3(0.0, block_top + 0.75, 0.0), Vector3(size.x - 0.5, 0.7, size.z - 0.5), STEEL)
	_rail_ring(tool, at + Vector3(0.0, block_top + 0.4, 0.0), Vector2(size.x - 0.2, size.z - 0.2), 0.8)
	_mast(tool, at + Vector3(0.0, block_top + 1.1, 0.0), MAST_TOP - block_top - 1.1)


## A SIX-SIDED MAST, tapering, with a thin rod on top: the spires on the sheet's towers.
func _mast(tool: SurfaceTool, base: Vector3, tall: float) -> void:
	if tall <= 0.1:
		return
	var low := PackedVector2Array()
	var high := PackedVector2Array()
	for index in range(MAST_SIDES):
		var angle: float = TAU * float(index) / float(MAST_SIDES)
		low.append(Vector2(base.x + cos(angle) * 0.34, base.z + sin(angle) * 0.34))
		high.append(Vector2(base.x + cos(angle) * 0.10, base.z + sin(angle) * 0.10))
	Plating.prism(tool, low, base.y, base.y + tall * 0.55, GUNMETAL)
	Plating.prism(tool, high, base.y + tall * 0.55, base.y + tall * 0.92, GUNMETAL)
	Plating.box(tool, Vector3(base.x, base.y + tall * 0.96, base.z), Vector3(0.08, tall * 0.2, 0.08), STEEL)


## A CAPPED TOWER HEAD on a mid-side rib: the boxes with twin lamps the sheet stands at the roof shoulder.
func _tower_head(tool: SurfaceTool, at: Vector3, wide: float) -> void:
	Plating.box(tool, at + Vector3(0.0, EAVE + 0.75, 0.0), Vector3(wide, 1.5, wide), GUNMETAL)
	Plating.box(tool, at + Vector3(0.0, EAVE + 1.62, 0.0), Vector3(wide + 0.25, 0.24, wide + 0.25), STEEL)
	for side in [-1.0, 1.0]:
		Plating.box(tool, at + Vector3(side * wide * 0.26, EAVE + 1.82, 0.0), Vector3(0.42, 0.3, 0.42), DARK)


## THE ARMOURED SERVICE HOUSINGS ROUND THE BASE, one set a bay: cabinets, a taller utility box, and a yellow-marked
## hazard locker at the corners. The sheet lists "armoured service housings" and "integrated utilities (perimeter)".
func _base_housings(tool: SurfaceTool) -> void:
	var half_span: float = SPAN * 0.5
	var half_deep: float = depth() * 0.5
	var band: float = float(BANDS[0][1])
	for index in range(bays):
		var z: float = -half_deep + (float(index) + 0.5) * BAY
		for side in [-1.0, 1.0]:
			var x: float = side * (half_span + 0.55)
			Plating.box(tool, Vector3(x, band * 0.45, z - 2.2), Vector3(1.5, band * 0.9, 2.6), STEEL)
			Plating.box(tool, Vector3(x, band * 0.62, z + 1.6), Vector3(1.3, band * 1.24, 2.2), PANEL_SHADE)
			Plating.box(tool, Vector3(x - side * 0.2, band * 1.2, z + 1.6), Vector3(1.0, 0.3, 1.8), GUNMETAL)
			Plating.box(tool, Vector3(x, 0.35, z - 2.2), Vector3(1.6, 0.18, 2.7), YELLOW_DEEP)
	for index in range(FACE_BAYS):
		var x: float = -half_span + (float(index) + 0.5) * (SPAN / float(FACE_BAYS))
		Plating.box(tool, Vector3(x - 1.6, band * 0.45, -(half_deep + 0.55)), Vector3(2.6, band * 0.9, 1.5), STEEL)
		Plating.box(tool, Vector3(x + 1.7, band * 0.6, -(half_deep + 0.5)), Vector3(2.2, band * 1.2, 1.4), PANEL_SHADE)
	# THE HAZARD LOCKERS at the four corners, with the yellow cross the sheet paints on them.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var at := Vector3(sx * (half_span + 0.6), 0.0, sz * (half_deep - TOWER - 1.2))
			Plating.box(tool, at + Vector3(0.0, 1.1, 0.0), Vector3(1.6, 2.2, 2.2), GUNMETAL)
			for lean in [1.0, -1.0]:
				Plating.box(tool, at + Vector3(sx * 0.82, 1.2, 0.0), Vector3(0.1, 0.18, 2.6), YELLOW,
					Basis(Vector3(1.0, 0.0, 0.0), lean * 0.7))


## THE YELLOW SAFETY RAILINGS: round the eave, and round the spine. Welded, not instanced -- a post is twelve triangles
## and the whole run is one surface of the shell, where a MultiMesh would be a second draw for nothing.
func _railings(tool: SurfaceTool) -> void:
	var half_span: float = SPAN * 0.5 - RIB_PROUD * 0.5
	var half_deep: float = depth() * 0.5 - RIB_PROUD * 0.5
	_rail_ring(tool, Vector3(0.0, EAVE + FASCIA, 0.0), Vector2(half_span * 2.0, half_deep * 2.0), RAIL_TALL)
	_rail_ring(tool, Vector3(0.0, SPINE_TOP, 0.0), Vector2(SPINE_WIDE, SPINE_LONG), RAIL_TALL * 0.8)


## ONE RING OF RAILING round a rectangle: two rails and a post every couple of metres.
func _rail_ring(tool: SurfaceTool, at: Vector3, size: Vector2, tall: float) -> void:
	var half := size * 0.5
	var corners: Array[Vector2] = [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y),
		Vector2(-half.x, half.y)]
	for index in range(4):
		var from: Vector2 = corners[index] + Vector2(at.x, at.z)
		var to: Vector2 = corners[(index + 1) % 4] + Vector2(at.x, at.z)
		for height in [tall, tall * 0.55]:
			Plating.bar(tool, from, to, RAIL_THICK, at.y + height - RAIL_THICK, at.y + height, YELLOW)
		var run: float = from.distance_to(to)
		var posts: int = maxi(1, int(run / RAIL_STEP))
		for post in range(posts + 1):
			var place: Vector2 = from.lerp(to, float(post) / float(posts))
			Plating.box(tool, Vector3(place.x, at.y + tall * 0.5, place.y),
				Vector3(RAIL_THICK, tall, RAIL_THICK), YELLOW)


## ---------------------------------------------------------------------------------------------------------------------
## THE DOOR PORTAL
## ---------------------------------------------------------------------------------------------------------------------

## THE HEAVY DOOR PORTAL: a deep gunmetal reveal round the opening, a yellow strip up each jamb with its stencil plates,
## and the dashes across the lintel. The opening itself is left empty: the sheet's door is open and has no leaf.
func _portal(tool: SurfaceTool) -> void:
	var face_z: float = depth() * 0.5 - RIB_PROUD
	var half_wide: float = OPENING_WIDE * 0.5
	var reveal: float = 1.1
	# The reveal: three receding frames into the building, which is what gives the sheet's portal its depth.
	for step in range(3):
		var inset: float = float(step) * 0.34
		var z: float = face_z - WALL - float(step) * reveal * 0.33
		for side in [-1.0, 1.0]:
			Plating.box(tool, Vector3(side * (half_wide - inset - 0.17), OPENING_HIGH * 0.5, z),
				Vector3(0.34, OPENING_HIGH, reveal * 0.34), GUNMETAL if step == 0 else DARK)
		Plating.box(tool, Vector3(0.0, OPENING_HIGH - inset - 0.17, z),
			Vector3(OPENING_WIDE - inset * 2.0, 0.34, reveal * 0.34), GUNMETAL if step == 0 else DARK)
	# THE JAMB PILLARS either side, gunmetal with a yellow strip and dark stencil plates up it.
	for side in [-1.0, 1.0]:
		var x: float = side * (half_wide + JAMB_WIDE * 0.5)
		Plating.box(tool, Vector3(x, EAVE * 0.5, face_z - WALL * 0.5 + 0.12), Vector3(JAMB_WIDE, EAVE, WALL + 0.24),
			GUNMETAL)
		Plating.box(tool, Vector3(x, EAVE * 0.5, face_z + 0.2), Vector3(JAMB_WIDE * 0.55, EAVE - 1.2, 0.12), YELLOW)
		for plate in range(7):
			Plating.box(tool, Vector3(x, 1.4 + float(plate) * 1.05, face_z + 0.28),
				Vector3(JAMB_WIDE * 0.3, 0.42, 0.06), DARK)
	# THE DASHES ALONG THE LINTEL: the dark stencil marks the sheet runs across the yellow band.
	var dash_z: float = face_z - WALL * 0.5 + 0.13 + WALL * 0.5
	for index in range(16):
		var x: float = -half_wide + 0.9 + float(index) * (OPENING_WIDE - 1.8) / 15.0
		Plating.box(tool, Vector3(x, OPENING_HIGH + LINTEL_TALL * 0.5, dash_z), Vector3(0.5, 0.12, 0.05), DARK)
	# And the yellow warning stripe on the ground across the opening's threshold.
	Plating.box(tool, Vector3(0.0, 0.02, face_z - WALL - 0.4), Vector3(OPENING_WIDE, 0.04, 0.5), YELLOW)


## ---------------------------------------------------------------------------------------------------------------------
## THE ROOF
## ---------------------------------------------------------------------------------------------------------------------

## THE SLOPED BLAST-DEFLECTION ROOF and its raised armoured spine. Four trapezoid plates from the eave to a flat
## shoulder, the spine box standing 1.0 m over that, the dark armoured strips flanking it, and the paint: hip stripes,
## the chevrons at each end and the number on the spine. No skylights and no vents, as the sheet's feature list says.
func _roof(tool: SurfaceTool) -> void:
	var half_span: float = SPAN * 0.5 - RIB_PROUD * 0.5 + EAVE_PROUD
	var half_deep: float = depth() * 0.5 - RIB_PROUD * 0.5 + EAVE_PROUD
	var shoulder_x: float = SPINE_WIDE * 0.5
	var shoulder_z: float = SPINE_LONG * 0.5
	# The fascia round the eave, which is the thickness of the roof seen from below.
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(side * half_span, EAVE + FASCIA * 0.5, 0.0),
			Vector3(0.3, FASCIA, half_deep * 2.0), GUNMETAL)
		Plating.box(tool, Vector3(0.0, EAVE + FASCIA * 0.5, side * half_deep),
			Vector3(half_span * 2.0, FASCIA, 0.3), GUNMETAL)
	var eave_y: float = EAVE + FASCIA
	# THE FOUR PLATES. Each is a trapezoid from an eave edge up to the shoulder rectangle's matching edge.
	var corners_low: Array[Vector3] = [
		Vector3(-half_span, eave_y, -half_deep), Vector3(half_span, eave_y, -half_deep),
		Vector3(half_span, eave_y, half_deep), Vector3(-half_span, eave_y, half_deep)]
	var corners_high: Array[Vector3] = [
		Vector3(-shoulder_x, SHOULDER, -shoulder_z), Vector3(shoulder_x, SHOULDER, -shoulder_z),
		Vector3(shoulder_x, SHOULDER, shoulder_z), Vector3(-shoulder_x, SHOULDER, shoulder_z)]
	for index in range(4):
		var next: int = (index + 1) % 4
		var plate: Array = [corners_low[index], corners_low[next], corners_high[next], corners_high[index]]
		Plating.facing(tool, plate, Vector3(0.0, 1.0, 0.0), PANEL)
	# THE HIP STRIPES: a yellow line inset along each of the four hip diagonals, and the yellow edge line round the eave.
	for index in range(4):
		var low: Vector3 = corners_low[index]
		var high: Vector3 = corners_high[index]
		var inward: Vector3 = (high - low).normalized()
		var stripe_a: Vector3 = low + inward * 0.9
		var stripe_b: Vector3 = high - inward * 0.6
		_roof_stripe(tool, stripe_a, stripe_b, 0.55)
	# THE RAISED ARMOURED SPINE, with a dark strip down each of its sides and a gunmetal rim on top.
	Plating.box(tool, Vector3(0.0, (SHOULDER + SPINE_TOP) * 0.5, 0.0),
		Vector3(SPINE_WIDE, SPINE_TOP - SHOULDER, SPINE_LONG), PANEL)
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(side * (SPINE_WIDE * 0.5 + 0.04), SHOULDER + 0.45, 0.0),
			Vector3(0.12, 0.5, SPINE_LONG - 1.2), DARK)
		Plating.box(tool, Vector3(0.0, SHOULDER + 0.45, side * (SPINE_LONG * 0.5 + 0.04)),
			Vector3(SPINE_WIDE - 1.2, 0.5, 0.12), DARK)
	# THE RIM ROUND THE DECK, AND ONLY ROUND IT. This was one box the full size of the spine top, which is not a rim but a
	# lid: it buried the light armoured deck the sheet's top view draws, and with it the dark "03" painted 0.07 m above
	# it, so the roof read as a plain dark slab from directly overhead. Four bars, and the deck shows between them.
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(side * (SPINE_WIDE * 0.5 + 0.15 - RIM_WIDE * 0.5), SPINE_TOP + 0.06, 0.0),
			Vector3(RIM_WIDE, 0.12, SPINE_LONG + 0.3), GUNMETAL)
		Plating.box(tool, Vector3(0.0, SPINE_TOP + 0.06, side * (SPINE_LONG * 0.5 + 0.15 - RIM_WIDE * 0.5)),
			Vector3(SPINE_WIDE + 0.3 - RIM_WIDE * 2.0, 0.12, RIM_WIDE), GUNMETAL)
	# THE DARK ARMOURED STRIP PANELS flanking the spine on the long-side slopes, measured at 9.3-13.2 m and 26.8-30.7 m
	# along the 40 m, i.e. a 3.9 m band just outboard of each end of the spine.
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var from_z: float = sz * (shoulder_z + 0.4)
			var to_z: float = sz * (shoulder_z + 4.3)
			for strip in range(4):
				var t: float = (float(strip) + 0.5) / 4.0
				var z: float = lerpf(from_z, to_z, t)
				var across: float = lerpf(shoulder_x, half_span, 0.5)
				Plating.box(tool, Vector3(sx * across, _roof_height(sx * across, z) + 0.09, z),
					Vector3((half_span - shoulder_x) * 0.82, 0.18, 0.62), GUNMETAL)
	# THE ARMOURED HATCH ROWS at the spine edge: four dark panels a side, which the top view draws either side of "03".
	for sx in [-1.0, 1.0]:
		for index in range(4):
			var z: float = -shoulder_z * 0.62 + float(index) * shoulder_z * 0.41
			var x: float = sx * (shoulder_x + 1.9)
			Plating.box(tool, Vector3(x, _roof_height(x, z) + 0.1, z), Vector3(2.6, 0.2, 2.1), GUNMETAL)
			Plating.box(tool, Vector3(x, _roof_height(x, z) + 0.21, z), Vector3(2.2, 0.06, 1.7), DARK)
	# THE CHEVRONS at each end of the roof, pointing outboard, as the top view draws them.
	for sz in [-1.0, 1.0]:
		var nose: float = sz * (half_deep - 2.2)
		_roof_chevron(tool, nose, sz, 4.2, 3.4)
		_roof_chevron(tool, nose - sz * 2.6, sz, 3.0, 2.4)
	# AND THE TWO YELLOW LINES ALONG THE SPINE, at the measured +-5.4 m from the centreline.
	for side in [-1.0, 1.0]:
		var x: float = side * 5.4
		_roof_stripe(tool, Vector3(x, 0.0, -shoulder_z + 0.4), Vector3(x, 0.0, shoulder_z - 0.4), 0.4)


## HOW HIGH THE ROOF IS over a point in plan: the eave outside the shoulder, the shoulder inside it. One function, so the
## strips, hatches and paint all lie on the same surface instead of each guessing at it.
func _roof_height(x: float, z: float) -> float:
	var half_span: float = SPAN * 0.5 - RIB_PROUD * 0.5 + EAVE_PROUD
	var half_deep: float = depth() * 0.5 - RIB_PROUD * 0.5 + EAVE_PROUD
	var shoulder_x: float = SPINE_WIDE * 0.5
	var shoulder_z: float = SPINE_LONG * 0.5
	var eave_y: float = EAVE + FASCIA
	var across: float = clampf((absf(x) - shoulder_x) / maxf(0.001, half_span - shoulder_x), 0.0, 1.0)
	var along: float = clampf((absf(z) - shoulder_z) / maxf(0.001, half_deep - shoulder_z), 0.0, 1.0)
	return lerpf(SHOULDER, eave_y, maxf(across, along))


## A PAINTED LINE ON THE ROOF, following the surface: drawn as a few flat pieces, each sat on the slope under it, because
## one long quad across a hip would float over the crease.
func _roof_stripe(tool: SurfaceTool, from: Vector3, to: Vector3, wide: float) -> void:
	var pieces: int = 8
	for index in range(pieces):
		var a: Vector3 = from.lerp(to, float(index) / float(pieces))
		var b: Vector3 = from.lerp(to, float(index + 1) / float(pieces))
		var middle: Vector3 = (a + b) * 0.5
		var run: Vector2 = Vector2(b.x - a.x, b.z - a.z)
		if run.length() < 0.01:
			continue
		Plating.box(tool, Vector3(middle.x, _roof_height(middle.x, middle.z) + 0.07, middle.z),
			Vector3(wide, 0.06, run.length()), YELLOW, Basis(Vector3.UP, atan2(-run.x, -run.y)))


## ONE YELLOW CHEVRON on an end of the roof, pointing outboard: two arms meeting at the centreline.
func _roof_chevron(tool: SurfaceTool, at_z: float, facing: float, half_wide: float, sweep: float) -> void:
	for side in [-1.0, 1.0]:
		var tip := Vector3(0.0, 0.0, at_z)
		var wing := Vector3(side * half_wide, 0.0, at_z - facing * sweep)
		var middle: Vector3 = (tip + wing) * 0.5
		var run := Vector2(wing.x - tip.x, wing.z - tip.z)
		Plating.box(tool, Vector3(middle.x, _roof_height(middle.x, middle.z) + 0.08, middle.z),
			Vector3(0.75, 0.06, run.length()), YELLOW, Basis(Vector3.UP, atan2(-run.x, -run.y)))


## ---------------------------------------------------------------------------------------------------------------------
## THE INTERIOR
## ---------------------------------------------------------------------------------------------------------------------

## THE LIT, PANELLED INTERIOR: a ceiling at the eave with trusses across it, a column at every rib, a wainscot band round
## the walls and equipment along them. The floor is the level's apron, which this building stands on.
func _interior(tool: SurfaceTool) -> void:
	var in_x: float = SPAN * 0.5 - RIB_PROUD - WALL
	var in_z: float = depth() * 0.5 - RIB_PROUD - WALL
	# The ceiling, and a truss across it on every bay joint.
	Plating.box(tool, Vector3(0.0, EAVE + 0.1, 0.0), Vector3(in_x * 2.0, 0.2, in_z * 2.0), PANEL_SHADE)
	for index in range(bays + 1):
		var z: float = -in_z + float(index) * (in_z * 2.0 / float(bays))
		Plating.box(tool, Vector3(0.0, EAVE - 0.45, z), Vector3(in_x * 2.0, 0.7, 0.45), GUNMETAL)
		for brace in range(FACE_BAYS * 2):
			var x: float = -in_x + (float(brace) + 0.5) * (in_x * 2.0 / float(FACE_BAYS * 2))
			Plating.box(tool, Vector3(x, EAVE - 0.8, z), Vector3(0.3, 0.3, 0.42), STEEL)
	# A COLUMN AT EVERY RIB, inside: the ribs read through the wall, as they do in the sheet's interior.
	for index in range(bays + 1):
		var z: float = -in_z + float(index) * (in_z * 2.0 / float(bays))
		for side in [-1.0, 1.0]:
			Plating.box(tool, Vector3(side * (in_x - 0.3), EAVE * 0.5, z), Vector3(0.6, EAVE, 1.1), GUNMETAL)
	# The wainscot band round the inside, and the rear wall's panel joints.
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(side * (in_x - 0.12), 1.1, 0.0), Vector3(0.24, 2.2, in_z * 2.0), PANEL_SHADE)
	Plating.box(tool, Vector3(0.0, 1.1, -(in_z - 0.12)), Vector3(in_x * 2.0, 2.2, 0.24), PANEL_SHADE)
	# EQUIPMENT ALONG THE WALLS: tool cabinets, a bench and a yellow tug body a bay, kept clear of the parking box.
	for index in range(bays):
		var z: float = -in_z + (float(index) + 0.5) * (in_z * 2.0 / float(bays))
		for side in [-1.0, 1.0]:
			var x: float = side * (in_x - 1.1)
			Plating.box(tool, Vector3(x, 0.55, z - 1.4), Vector3(1.2, 1.1, 2.4), STEEL)
			Plating.box(tool, Vector3(x, 0.45, z + 1.6), Vector3(1.0, 0.9, 1.6), YELLOW_DEEP)
			Plating.box(tool, Vector3(x, 1.05, z - 1.4), Vector3(1.3, 0.1, 2.5), GUNMETAL)


## THE OVERHEAD LINEAR LIGHTS: rows of emissive bars under the trusses, and a few shadowless lamps so the interior is
## actually lit rather than merely bright in the picture. Their own surface, because emission is not the shell's shader.
func _light_strips() -> void:
	var in_x: float = SPAN * 0.5 - RIB_PROUD - WALL
	var in_z: float = depth() * 0.5 - RIB_PROUD - WALL
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = 5
	var per_row: int = bays + 1
	for row in range(rows):
		var x: float = -in_x * 0.78 + float(row) * (in_x * 1.56 / float(rows - 1))
		for index in range(per_row):
			var z: float = -in_z * 0.82 + float(index) * (in_z * 1.64 / float(per_row - 1))
			Plating.box(tool, Vector3(x, EAVE - 0.95, z), Vector3(0.28, 0.12, 2.4), LIGHT_STRIP)
	strips = MeshInstance3D.new()
	strips.name = "LightStrips"
	strips.mesh = Plating.weld(tool)
	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.vertex_color_is_srgb = true
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.95, 0.85)
	glow.emission_energy_multiplier = 2.4
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	strips.material_override = glow
	strips.visible = lights_on
	add_child(strips)
	for index in range(4):
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp%d" % index
		lamp.position = Vector3(0.0, EAVE - 1.6, -in_z * 0.6 + float(index) * in_z * 0.4)
		lamp.omni_range = 26.0
		lamp.light_energy = 1.5
		lamp.shadow_enabled = false
		lamp.visible = lights_on
		add_child(lamp)


## ---------------------------------------------------------------------------------------------------------------------
## THE MARKINGS
## ---------------------------------------------------------------------------------------------------------------------

## EVERY MARKING THE SHEET CARRIES, drawn as geometry in the shell's own mesh: the number on the door pillar and on the
## roof spine, the winged chevron, the pad sign with its arrows. Nothing is a copied pixel and nothing is a font atlas:
## the digits are seven blocks each, which is the stencil the sheet's own numbers read as at building scale, and the only
## text laid out with a font is the small print (see `_small_print`).
func _markings(tool: SurfaceTool) -> void:
	# The door face's markings sit on the TOWER faces, which stand 0.9 m proud of the wall panels at z = half the depth.
	var tower_z: float = depth() * 0.5
	var rear_z: float = depth() * 0.5 - RIB_PROUD
	var tower_x: float = front_tower_middle()
	# THE NUMBER on the right-hand tower, with the winged chevron under it.
	_glyphs(tool, hangar_number, Vector3(tower_x, 6.2, tower_z), Vector3(0.0, 0.0, 1.0), Vector3.UP, WALL_DIGITS,
		GUNMETAL)
	_wing_mark(tool, Vector3(tower_x, 4.3, tower_z), Vector3(0.0, 0.0, 1.0), Vector3.UP, 1.5, GUNMETAL)
	# AND ON THE REAR WALL, as the rear three-quarter view has it.
	_wing_mark(tool, Vector3(0.0, 5.0, -rear_z), Vector3(0.0, 0.0, -1.0), Vector3.UP, 1.8, GUNMETAL)
	# THE PAD SIGN on the left-hand tower: a dark panel with the code at its top and two chevron arrows under it.
	var sign_x: float = -tower_x
	Plating.box(tool, Vector3(sign_x, 6.4, tower_z + PAINT_PROUD), Vector3(SIGN_WIDE, SIGN_TALL, 0.06), DARK)
	_glyphs(tool, pad_sign, Vector3(sign_x, 7.7, tower_z + 0.06), Vector3(0.0, 0.0, 1.0), Vector3.UP, 0.9, YELLOW)
	for index in range(2):
		_arrow_mark(tool, Vector3(sign_x, 5.9 - float(index) * 0.85, tower_z + 0.06), Vector3(0.0, 0.0, 1.0), 0.5,
			PANEL_SHADE)
	# THE NUMBER ON THE ROOF, on the spine. Its top points across the width, which is how the sheet's top view reads it.
	_glyphs(tool, hangar_number, Vector3(0.0, SPINE_TOP + 0.13, 0.0), Vector3.UP, Vector3(1.0, 0.0, 0.0), ROOF_DIGITS,
		GUNMETAL)


## SEVEN-BLOCK GLYPHS, laid out along the face they are painted on. `out` is the way the wall faces; `up` is which way is
## up on it. A digit is 0.62 as wide as it is tall and its strokes are 0.16 of its height, which is the proportion the
## sheet's numbers are drawn at.
func _glyphs(tool: SurfaceTool, text: String, centre: Vector3, out: Vector3, up: Vector3, tall: float,
		tint: Color) -> void:
	var across: Vector3 = up.cross(out).normalized()
	var wide: float = tall * 0.62
	var gap: float = tall * 0.14
	var total: float = float(text.length()) * wide + float(maxi(0, text.length() - 1)) * gap
	var start: float = -total * 0.5
	for index in range(text.length()):
		var left: float = start + float(index) * (wide + gap)
		for piece in _glyph_blocks(text[index]):
			var rect: Rect2 = piece
			var middle: Vector3 = centre \
				+ across * (left + (rect.position.x + rect.size.x * 0.5) * wide) \
				+ up * ((rect.position.y + rect.size.y * 0.5 - 0.5) * tall) \
				+ out * PAINT_PROUD
			var corners: Array = [
				middle - across * rect.size.x * wide * 0.5 - up * rect.size.y * tall * 0.5,
				middle + across * rect.size.x * wide * 0.5 - up * rect.size.y * tall * 0.5,
				middle + across * rect.size.x * wide * 0.5 + up * rect.size.y * tall * 0.5,
				middle - across * rect.size.x * wide * 0.5 + up * rect.size.y * tall * 0.5]
			Plating.facing(tool, corners, out, tint)


## WHICH BLOCKS A CHARACTER IS MADE OF, in a unit box: seven segments, as a stencilled number on a building is. A
## character this does not know paints nothing rather than a wrong glyph.
func _glyph_blocks(letter: String) -> Array:
	var t: float = 0.17
	var top := Rect2(0.0, 1.0 - t, 1.0, t)
	var middle := Rect2(0.0, 0.5 - t * 0.5, 1.0, t)
	var bottom := Rect2(0.0, 0.0, 1.0, t)
	var upper_left := Rect2(0.0, 0.5 - t * 0.5, t, 0.5 + t * 0.5)
	var upper_right := Rect2(1.0 - t, 0.5 - t * 0.5, t, 0.5 + t * 0.5)
	var lower_left := Rect2(0.0, 0.0, t, 0.5 + t * 0.5)
	var lower_right := Rect2(1.0 - t, 0.0, t, 0.5 + t * 0.5)
	match letter.to_upper():
		"0": return [top, bottom, upper_left, upper_right, lower_left, lower_right]
		"1": return [upper_right, lower_right]
		"2": return [top, upper_right, middle, lower_left, bottom]
		"3": return [top, upper_right, middle, lower_right, bottom]
		"4": return [upper_left, upper_right, middle, lower_right]
		"5": return [top, upper_left, middle, lower_right, bottom]
		"6": return [top, upper_left, middle, lower_left, lower_right, bottom]
		"7": return [top, upper_right, lower_right]
		"8": return [top, middle, bottom, upper_left, upper_right, lower_left, lower_right]
		"9": return [top, upper_left, upper_right, middle, lower_right, bottom]
		"A": return [top, upper_left, upper_right, middle, lower_left, lower_right]
		"E": return [top, upper_left, middle, lower_left, bottom]
		"F": return [top, upper_left, middle, lower_left]
		"H": return [upper_left, upper_right, middle, lower_left, lower_right]
		"P": return [top, upper_left, upper_right, middle, lower_left]
	return []


## THE WINGED CHEVRON: a central dart with three swept feathers either side, the mark the sheet puts under every number.
## Built from flat pieces on the wall it is painted on, so it costs nothing but triangles.
func _wing_mark(tool: SurfaceTool, centre: Vector3, out: Vector3, up: Vector3, tall: float, tint: Color) -> void:
	var across: Vector3 = up.cross(out).normalized()
	var place := func(u: float, v: float, wide: float, high: float, lean: float) -> void:
		var middle: Vector3 = centre + across * u * tall + up * v * tall + out * PAINT_PROUD
		var arm: Vector3 = (across * cos(lean) + up * sin(lean)) * wide * tall * 0.5
		var rise: Vector3 = (up * cos(lean) - across * sin(lean)) * high * tall * 0.5
		Plating.facing(tool, [middle - arm - rise, middle + arm - rise, middle + arm + rise, middle - arm + rise],
			out, tint)
	# The dart down the middle.
	place.call(0.0, -0.06, 0.20, 1.05, 0.0)
	place.call(0.0, -0.52, 0.10, 0.34, 0.0)
	# Three feathers each side, shortening as they rise, swept up and out.
	for side in [-1.0, 1.0]:
		var feathers: Array = [[0.34, 0.26, 0.62, 0.38], [0.30, 0.09, 0.52, 0.44], [0.24, -0.06, 0.40, 0.50]]
		for feather in feathers:
			place.call(side * float(feather[0]), float(feather[1]), float(feather[2]), 0.14,
				side * float(feather[3]))


## A CHEVRON ARROW, pointing up: the pair under the pad sign's code.
func _arrow_mark(tool: SurfaceTool, centre: Vector3, out: Vector3, wide: float, tint: Color) -> void:
	var across := Vector3.UP.cross(out).normalized()
	for side in [-1.0, 1.0]:
		var middle: Vector3 = centre + across * side * wide * 0.5
		var arm: Vector3 = (across * side * 0.72 + Vector3.UP * -0.72) * wide * 0.72
		var thick: Vector3 = (across * side * 0.72 + Vector3.UP * 0.72) * 0.13
		Plating.facing(tool, [middle - arm - thick, middle + arm - thick, middle + arm + thick, middle - arm + thick],
			out, tint)


## THE SMALL PRINT, the only text here laid out with a font: the brand and its line, which on the sheet are a few
## centimetres tall on a 2.8 m pillar and cannot be read as blocks. Two `Label3D`s, both on the door pillar.
func _small_print() -> void:
	var face_z: float = depth() * 0.5
	var flank_middle: float = front_tower_middle()
	var brand := Label3D.new()
	brand.name = "Brand"
	brand.text = "SKYFRONT"
	brand.font_size = 96
	brand.pixel_size = 0.0032
	brand.modulate = Color(0.16, 0.17, 0.19)
	brand.position = Vector3(flank_middle, 3.25, face_z + PAINT_PROUD * 2.0)
	brand.no_depth_test = false
	brand.double_sided = false
	brand.shaded = false
	add_child(brand)
	var line := Label3D.new()
	line.name = "Promise"
	line.text = "A CLEANER\nBRIGHTER\nTOMORROW"
	line.font_size = 96
	line.pixel_size = 0.0026
	line.line_spacing = 8.0
	line.modulate = Color(0.16, 0.17, 0.19)
	line.position = Vector3(flank_middle, 2.45, face_z + PAINT_PROUD * 2.0)
	line.double_sided = false
	line.shaded = false
	add_child(line)
