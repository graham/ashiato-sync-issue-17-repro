@tool
extends RefCounted
class_name PermanentWay
## THE TRACK A TRAIN RUNS ON: two rails, the ties under them, the ballast they are packed in and the bank that carries it
## all over the ground. A railwayman calls the lot the permanent way, and this is the one place its every dimension lives.
##
## WHAT WAS WRONG, measured and photographed on 2026-09-19 (`screenshots/2026-09-19/cockpit-trains-01..05-before-*`):
##
## 1. **THE RAILS WERE DRAWN IN DASHES.** `FlightLevel._draw_railway` sized each 12 m piece with `facing.scaled(...)`, and
##    `Basis.scaled` is a GLOBAL scale: it multiplies the matrix's rows, so the 12 m went along the world's Z whichever way
##    the track ran. A rail heading east was drawn 0.12 m long, a diagonal one sheared, and from the air the loop was a
##    dotted line wherever it ran east-west. The local scale is `scaled_local`. `cockpit/agents.md` already had this bug
##    twice -- the towns' road marks and the runways painted across their own centrelines -- and the railway was the third.
## 2. **The wheels were 16 cm down inside the rails.** The waypoints are the railhead, which is what every wheel stands on,
##    and the rails were drawn UP from there to +0.16.
## 3. **The ties were slabs**: 2.44 m across and 3.6 m along the track, one every 12 m. A mainline tie is 0.23 m wide and
##    there is one every 0.495 m.
## 4. **The railway floated 3 m over the grass** with nothing under it: the waypoints stand at `Terrain.RAIL_HEIGHT` over
##    the island's slab, and no embankment was drawn, so every train threw its shadow metres to one side of itself.
## 5. **The rails were 1.44 m apart between centres.** Standard gauge, 1,435 mm, is measured between the INSIDE faces of
##    the heads, so the centres are a head's width further apart: 1.510 m. The wheels were drawn at the same wrong 1.44.
##
## SO EVERYTHING IS MEASURED DOWN FROM THE RAILHEAD, which is y = 0 in this file's frame and is the waypoint: the rail's
## top is at 0, its foot at -RAIL_HIGH on the tie, the tie on the ballast, the ballast on the bank, and the bank on the
## ground. Across is x, and the track runs along z. `Boxcar` and the locomotive put their wheels' treads at
## `RAIL_CENTRES / 2` either side, read from here.
##
## THE NUMBERS, tagged as `modelling_here.md` section 3 says:
##
##   GAUGE          1.435 m    PUBLISHED: 4 ft 8 1/2 in, between the heads' inside faces.
##   The rail       136RE      PUBLISHED, AREMA's 136 lb/yd heavy-haul section, ArcelorMittal's TR68 sheet: 185.7 mm high,
##                             head 74.6 mm wide and 49.2 mm deep, web 17.5 mm, foot 152.4 mm wide.
##   FOOT_DEEP      0.030 m    ESTIMATE: the sheet gives no foot thickness; 136RE's flange tapers from about 1.2 in at the
##                             web to under an inch at its edge, and this is the edge.
##   The tie        7 x 9 in x 8 ft 6 in at 19 1/2 in centres, PUBLISHED: the AREMA mainline wood tie and the spacing
##                             quoted with it.
##   BALLAST_UNDER  0.305 m    PUBLISHED: 12 in of ballast under the tie on a main line.
##   SHOULDER       0.305 m    ESTIMATE: 12 in of ballast beyond each tie end, the common mainline figure.
##   The slopes     2 across to 1 down, ballast and bank alike: ESTIMATE, the usual side slope for both.
##   CRIB_DOWN      0.05 m     ESTIMATE: how far the ballast between the ties lies below their tops, so they show.
##
## THE TESSELLATION, stated so nobody rounds it later (`modelling_here.md` section 4): a rail is three flat boxes -- head,
## web and foot -- and nothing on the permanent way is round. A tie is one box. The bank is a trapezoid with a hard crease
## at the shoulder and another at the toe of the ballast.
##
## ONE MESH EACH, UNIT LONG, laid by instancing: a length of rail is `rails()` turned by `rail_pose`'s basis and stretched
## along its own z by `scaled_local` -- never `scaled` -- from one waypoint to the next, so the drawn rail IS the chord the
## wheels ride and not a sample of it. `tests/track_drawn.gd` reads every figure above back off the DRAWN instances.

const PLATING := preload("res://objects/vehicles/ships/plating.gd")

## ---- the rail and its gauge ------------------------------------------------------------------
const GAUGE: float = 1.435
const RAIL_HIGH: float = 0.1857
const HEAD_WIDE: float = 0.0746
const HEAD_DEEP: float = 0.0492
const WEB_WIDE: float = 0.0175
const FOOT_WIDE: float = 0.1524
const FOOT_DEEP: float = 0.030
## BETWEEN THE RAILS' MIDDLES, and so between the middles of a pair of wheel treads: the gauge plus one head.
const RAIL_CENTRES: float = GAUGE + HEAD_WIDE

## ---- the ties -------------------------------------------------------------------------------
const TIE_LONG: float = 102.0 * 0.0254
const TIE_WIDE: float = 9.0 * 0.0254
const TIE_DEEP: float = 7.0 * 0.0254
const TIE_SPACING: float = 19.5 * 0.0254
## HOW FAR OFF THE TIES ARE DRAWN. Past about 600 m a 9 in tie is under a pixel across in a 1600-wide, 45-degree view,
## and 46,000 of them round the loop would be most of the railway's triangles; the ballast's dark middle band carries the
## look of the ties beyond that. See `ballast_band`.
const TIE_REACH: float = 600.0

## ---- the ballast and the bank ---------------------------------------------------------------
const BALLAST_UNDER: float = 0.3048
const SHOULDER: float = 0.3048
const CRIB_DOWN: float = 0.05
## Across for every metre down, on the ballast's sides and the bank's.
const SLOPE: float = 2.0

## ---- the colours ----------------------------------------------------------------------------
## Rail steel: rust on the web and foot, the head worn bright where the wheels run.
const RUST := Color(0.30, 0.20, 0.14)
const HEAD := Color(0.52, 0.50, 0.48)
## Creosoted wood, weathered.
const TIE_PAINT := Color(0.20, 0.16, 0.13)
## Crushed stone, and the darker band of it between and under the ties that is what a track reads as from the air.
const BALLAST := Color(0.42, 0.39, 0.35)
const BALLAST_BAND := Color(0.27, 0.24, 0.21)
## The bank's sides: grassed-over earth, a shade off the island's own grass so the bank reads as a bank.
const BANK := Color(0.33, 0.35, 0.21)


## ---- heights under the railhead -------------------------------------------------------------

static func tie_top() -> float:
	return -RAIL_HIGH


static func tie_bottom() -> float:
	return -RAIL_HIGH - TIE_DEEP


static func ballast_top() -> float:
	return tie_top() - CRIB_DOWN


## THE FORMATION: the top of the bank, where the ballast stops and the earth begins.
static func formation() -> float:
	return tie_bottom() - BALLAST_UNDER


## Half the ballast's top across: half a tie and a shoulder.
static func ballast_half() -> float:
	return TIE_LONG * 0.5 + SHOULDER


## Half the formation across, at the ballast's toe.
static func formation_half() -> float:
	return ballast_half() + (ballast_top() - formation()) * SLOPE


## ---- the meshes -------------------------------------------------------------------------------

## BOTH RAILS, one metre long along z from -0.5 to +0.5, their tops at y = 0 and their middles `RAIL_CENTRES` apart.
static func rails() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var x: float = side * RAIL_CENTRES * 0.5
		PLATING.box(tool, Vector3(x, -HEAD_DEEP * 0.5, 0.0), Vector3(HEAD_WIDE, HEAD_DEEP, 1.0), HEAD)
		var web_high: float = RAIL_HIGH - HEAD_DEEP - FOOT_DEEP
		PLATING.box(tool, Vector3(x, -HEAD_DEEP - web_high * 0.5, 0.0), Vector3(WEB_WIDE, web_high, 1.0), RUST)
		PLATING.box(tool, Vector3(x, -RAIL_HIGH + FOOT_DEEP * 0.5, 0.0), Vector3(FOOT_WIDE, FOOT_DEEP, 1.0), RUST)
	return _finished(tool)


## ONE TIE, centred on the track at z = 0, under the rails' feet.
static func tie() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	PLATING.box(tool, Vector3(0.0, (tie_top() + tie_bottom()) * 0.5, 0.0), Vector3(TIE_LONG, TIE_DEEP, TIE_WIDE),
		TIE_PAINT)
	return _finished(tool)


## THE BALLAST AND THE BANK UNDER IT, one metre long, down to `ground`: y of the ground under the railhead, in this file's
## frame, so -Terrain.RAIL_HEIGHT on the island's slab. Where the ground is higher than the formation there is no bank,
## only ballast.
##
## Its top is ballast, with the ties' own dark band down the middle, so a track seen from past `TIE_REACH` still reads as
## a track and not as a grey stripe. No bottom and no ends: the bottom lies on the ground and the ends on the next length.
static func bed(ground: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: float = ballast_top()
	var toe: float = maxf(formation(), ground)
	var half: float = ballast_half()
	var toe_half: float = half + (top - toe) * SLOPE
	var band: float = TIE_LONG * 0.5
	# The top in three strips: shoulder, the band the ties lie in, shoulder.
	for strip in [[-half, -band, BALLAST], [-band, band, BALLAST_BAND], [band, half, BALLAST]]:
		_flat(tool, strip[0], strip[1], top, strip[2])
	for side in [-1.0, 1.0]:
		_slope(tool, side, half, top, toe_half, toe, BALLAST)
		if ground < toe:
			_slope(tool, side, toe_half, toe, toe_half + (toe - ground) * SLOPE, ground, BANK)
	return _finished(tool)


## How far out from the middle the bank's toe meets the ground, `ground` as in `bed`.
static func bank_half(ground: float) -> float:
	var toe: float = maxf(formation(), ground)
	return ballast_half() + (ballast_top() - toe) * SLOPE + maxf(toe - ground, 0.0) * SLOPE


## THE ONE MATERIAL every piece of the permanent way is drawn with: its colour is in its vertices, and they are sRGB.
static func painted() -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	# Vertex colour is LINEAR unless this says otherwise: a 0.19 deck drew at about 0.47 (`modelling_here.md` section 4).
	paint.vertex_color_is_srgb = true
	# ROUGH AND UNPOLISHED. At 0.92 with the default specular, the ballast and the bank took a sheen off the sky and read
	# as a BLUE band down the side of the track in every shaded frame -- crushed stone and grassed earth reflect nothing.
	paint.roughness = 1.0
	paint.metallic_specular = 0.08
	return paint


## ---- laying it -------------------------------------------------------------------------------

## WHERE EVERY PIECE GOES, round a closed railway given as its waypoints in order.
##
## `pose_at` is `func(distance: float) -> Dictionary`, `rail_pose` with no bogies and no lift -- the one function the
## locomotive and the carriages are posed by. A length of rail and of bed runs from each waypoint to the next: it is posed
## at the chord's middle, where both of `rail_pose`'s tangent samples fall on that one chord so its basis is the chord's
## own, and stretched along its own z to the chord's length. The ties are stepped along each chord at TIE_SPACING,
## carried on from one chord to the next, and take the chord's basis.
##
## Returns `{"rails": [Transform3D], "bed": [...], "ties": [...]}`, each ready for a unit mesh above.
static func lay(points: Array[Vector3], pose_at: Callable) -> Dictionary:
	var rails_at: Array[Transform3D] = []
	var bed_at: Array[Transform3D] = []
	var ties_at: Array[Transform3D] = []
	var reached: float = 0.0
	var next_tie: float = TIE_SPACING * 0.5
	for i in range(points.size()):
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()]
		var run: float = a.distance_to(b)
		if run < 0.001:
			continue
		var pose: Dictionary = pose_at.call(reached + run * 0.5)
		if pose.is_empty():
			reached += run
			continue
		var facing := Basis(pose["basis"] as Quaternion)
		var middle: Vector3 = pose["position"]
		# STRETCHED IN ITS OWN FRAME. `scaled` would stretch along the world's z: see 1 at the top.
		rails_at.append(Transform3D(facing.scaled_local(Vector3(1.0, 1.0, run)), middle))
		# THE BANK IS LEVEL; only the track on it leans. A railway is superelevated by packing the ballast deeper under the
		# outer rail, never by tipping the embankment -- and a bank tipped with the rails put its toes 6.8 m out 13 cm in
		# the air on one side and 13 cm in the ground on the other at the sharpest bend's 1.1 degrees.
		var nose: Vector3 = -facing.z
		var right: Vector3 = nose.cross(Vector3.UP).normalized()
		var level := Basis(right, right.cross(nose).normalized(), -nose)
		bed_at.append(Transform3D(level.scaled_local(Vector3(1.0, 1.0, run)), middle))
		# -Z is forward, so a point `along` past the chord's start is at +run/2 - along on its own z.
		while next_tie < reached + run:
			var along: float = next_tie - reached
			ties_at.append(Transform3D(facing, middle + facing * Vector3(0.0, 0.0, run * 0.5 - along)))
			next_tie += TIE_SPACING
		reached += run
	return {"rails": rails_at, "bed": bed_at, "ties": ties_at}


## ---- the pieces of a mesh -------------------------------------------------------------------

## A flat strip across the track from x0 to x1 at height y, facing up.
static func _flat(tool: SurfaceTool, x0: float, x1: float, y: float, tint: Color) -> void:
	PLATING.facing(tool, [Vector3(x0, y, -0.5), Vector3(x1, y, -0.5), Vector3(x1, y, 0.5), Vector3(x0, y, 0.5)],
		Vector3.UP, tint)


## One side's slope, from (x_in, y_in) out and down to (x_out, y_out), `side` -1 port or +1 starboard, facing out and up.
static func _slope(tool: SurfaceTool, side: float, x_in: float, y_in: float, x_out: float, y_out: float,
		tint: Color) -> void:
	var inner := Vector2(side * x_in, y_in)
	var outer := Vector2(side * x_out, y_out)
	var run: Vector2 = outer - inner
	# Out of the slope's face: its run turned a quarter, toward up.
	var out := Vector3(-run.y * side, run.x * side, 0.0).normalized()
	if out.y < 0.0:
		out = -out
	PLATING.facing(tool, [Vector3(inner.x, inner.y, -0.5), Vector3(outer.x, outer.y, -0.5),
		Vector3(outer.x, outer.y, 0.5), Vector3(inner.x, inner.y, 0.5)], out, tint)


static func _finished(tool: SurfaceTool) -> ArrayMesh:
	var mesh: ArrayMesh = tool.commit()
	mesh.surface_set_material(0, painted())
	return mesh
