extends RefCounted
class_name DioramaMiniature
## A TINY MODEL OF A CRAFT, built out of the numbers the simulation already holds about it: a fuselage, wings, a
## tailplane and a fin for an aeroplane; a pod, a boom and a rotor disc for a helicopter; a hull for a ship. Forty-odd
## triangles, faceted, one mesh per KIND and never one per contact.
##
## THE USER ASKED FOR THESE, 2026-09-20: *"can you make sure you use tiny models for the planes?"*
##
## ---------------------------------------------------------------------------------------------------
## WHY NOT THE REAL CRAFT MODELS, WHICH DO EXIST
## ---------------------------------------------------------------------------------------------------
##
## `VehicleView.setup(0, kind)` builds the actual exterior of any kind with no simulation running, and it was the first
## thing tried. **It is the wrong tool here and the reason is a measurement.** `../craft_model_audit.md` counts the
## drawn triangles per kind: a Cessna is about 40,000, a UH-60 about 47,000, a Chinook 69,000, an Osprey 118,000 and a
## Hawkeye about 164,000. A controller's board routinely carries seventy-five contacts, so real models would put
## **three to twelve million triangles** on the one screen whose entire justification is that it is cheap -- the user's
## own words were *"that way it doesn't incur the same 3d drawing issues and distance calculations"*. It would have
## destroyed the thing they asked for in order to satisfy the thing they asked for.
##
## ### So the model is built from the shape table instead
##
## `Sim.geometry_of(kind)` gives `extents` (the HALF extents of the body, in metres) and `span` (the HALF wingspan),
## and those two numbers are enough to draw something that unmistakably reads as the right sort of aircraft. They are
## the simulation's own figures, so **nothing here keeps a roster of thirty-nine shapes** (rule 4) and a kind added in
## the C++ gets a miniature with no edit to this file -- exactly the property `VehicleCatalogue.group` gives the board
## for choosing WHICH shape to build.
##
## Checked against the published aeroplanes as a sanity test of the convention: the jumbo's `extents.z` of 35.33
## doubles to 70.7 m, which is a 747-400's length to the decimetre, and its `span` of 32.46 doubles to 64.9 m against a
## published 64.4. The Cessna's 5.50 doubles to 11.0 m, which is a 172's span exactly.
##
## **ONE KIND'S FIGURES LOOK LIKE THEY ARE IN THE OTHER CONVENTION.** The Phantom's `span` is 11.71, and an F-4's
## published wingspan is 11.77 m -- so that entry appears to hold the FULL span where the jumbo and the Cessna hold the
## half. Rather than special-case a kind here, `_wing_half` clamps a wing to `WING_LONGEST` of the body's half length,
## which keeps any kind whose figure is in the other convention looking like an aeroplane instead of a dart board. It
## is a display clamp and it is not a fix: the figures themselves are the simulation's and are not this file's to
## change. Worth somebody's time separately.
##
## ### Faceted, because that is the house look
##
## Flat normals throughout (`modelling_here.md`: models here stay faceted and low poly, and the Hawkeye airframe is the
## reference). At the size these are drawn a facet is what makes a shape read at all -- a smooth-shaded 20 mm aeroplane
## is a grey smudge.

## HOW A MINIATURE IS PROPORTIONED. All fractions of the craft's own figures, so they hold for a Cessna and a jumbo
## alike rather than being tuned for one aeroplane.
##
## A wing's chord, as a fraction of the body's LENGTH, and where along the body it sits (0 at the nose, 1 at the tail).
const WING_CHORD: float = 0.26
const WING_AT: float = 0.52
## How far back the tips are swept, as a fraction of the chord.
const WING_SWEEP: float = 0.55
## The tailplane, as fractions of the wing's own half span and chord, and where it sits.
const TAIL_SPAN: float = 0.38
const TAIL_CHORD: float = 0.62
const TAIL_AT: float = 0.94
## The fin: how tall as a fraction of the body's half height, and its chord as a fraction of the tailplane's.
const FIN_TALL: float = 2.3
const FIN_CHORD: float = 1.05
## How thick a flying surface is, as a fraction of the body's half height. Thin, but never zero: a plate with no
## thickness disappears edge-on, which on a board you look across is most of the time.
const SURFACE_THICK: float = 0.22
## THE LONGEST A WING MAY BE, as a fraction of the body's half length. See the doc block -- this is the clamp that keeps
## a kind whose `span` is in the other convention looking like an aeroplane.
const WING_LONGEST: float = 1.05

## A helicopter's rotor: its disc radius as a fraction of `span`, how thin the disc is, and how many segments. Twelve
## is enough to read as a circle at 20 mm and is 24 triangles.
const ROTOR_THIN: float = 0.05
const ROTOR_STEPS: int = 12
## Its tail boom, as fractions of the body.
const BOOM_THICK: float = 0.30
const BOOM_TO: float = 1.72

## THE COLOURS OF A MINIATURE, by role. Not a livery: every radar contact is anonymous (`world/radar_set.gd`), so these
## are the greys of a pewter wargame piece, told apart only by facing the light.
const BODY := Color(0.62, 0.65, 0.69)
const WING := Color(0.55, 0.58, 0.62)
const TRIM := Color(0.44, 0.47, 0.51)


## THE MINIATURE FOR A KIND, in the craft's OWN metres, nose towards -Z and the origin at the middle of the body.
## `group` is `VehicleCatalogue.group(kind)`, handed in rather than asked for, so the board and the miniature cannot
## disagree about what sort of thing a kind is.
##
## The caller scales it: `DioramaBoard` sizes a piece to be READ and not to be right, which is the whole token rule.
static func of(kind: int, group: String) -> ArrayMesh:
	var geometry: Dictionary = Sim.geometry_of(kind)
	var extents: Vector3 = geometry.get("extents", Vector3.ONE)
	var span: float = float(geometry.get("span", 0.0))
	var build := SurfaceTool.new()
	build.begin(Mesh.PRIMITIVE_TRIANGLES)
	match group:
		"aeroplanes":
			_an_aeroplane(build, extents, span)
		"helicopters":
			_a_helicopter(build, extents, span)
		"ships":
			_a_ship(build, extents, geometry.get("parts", []) as Array)
		_:
			_a_box(build, extents, BODY)
	build.generate_normals()
	return build.commit()


## HOW LONG A WING IS on each side, metres, from the kind's own `span` under the clamp. See the doc block.
static func _wing_half(extents: Vector3, span: float) -> float:
	var asked: float = span if span > 0.0 else extents.x * 3.0
	return minf(asked, extents.z * WING_LONGEST)


## AN AEROPLANE: a tapered fuselage with a pointed nose, a swept wing, a tailplane and a fin.
static func _an_aeroplane(build: SurfaceTool, extents: Vector3, span: float) -> void:
	var long: float = extents.z
	var wide: float = extents.x
	var tall: float = extents.y
	# THE FUSELAGE, drawn as a six-sided solid: a POINT at the nose and a rectangular tail, which is what makes a
	# twenty-millimetre grey shape read as an aeroplane going somewhere rather than as a lozenge.
	var nose := Vector3(0.0, 0.0, -long)
	var tail: float = long * 0.86
	_hexa(build, nose, -long * 0.35, tail, wide, tall, BODY)

	var wing_half: float = _wing_half(extents, span)
	var chord: float = long * 2.0 * WING_CHORD
	var at: float = -long + long * 2.0 * WING_AT
	var thick: float = tall * SURFACE_THICK
	_flat_wing(build, at, chord, wing_half, thick, 0.0, WING_SWEEP, WING)

	# THE TAILPLANE AND THE FIN. A miniature without them reads as a dart; with them it reads as an aeroplane, and they
	# are four triangles each.
	var tail_at: float = -long + long * 2.0 * TAIL_AT
	var tail_half: float = wing_half * TAIL_SPAN
	var tail_chord: float = chord * TAIL_CHORD
	_flat_wing(build, tail_at, tail_chord, tail_half, thick, 0.0, WING_SWEEP, TRIM)
	_upright_fin(build, tail_at, tail_chord * FIN_CHORD, tall * FIN_TALL, thick, TRIM)


## A HELICOPTER: a pod, a tail boom, a main rotor disc over it and a fin. The disc is what tells it from an aeroplane
## at this size, and nothing else does.
static func _a_helicopter(build: SurfaceTool, extents: Vector3, span: float) -> void:
	var long: float = extents.z
	_hexa(build, Vector3(0.0, 0.0, -long), -long * 0.55, long * 0.35, extents.x, extents.y, BODY)
	# THE BOOM, a thin box running aft.
	var boom: float = extents.x * BOOM_THICK
	_box_between(build, Vector3(-boom, -boom, long * 0.30), Vector3(boom, boom, long * BOOM_TO), TRIM)
	_upright_fin(build, long * BOOM_TO * 0.93, long * 0.30, extents.y * 1.5, boom, TRIM)
	# THE DISC, over the pod, thin. Its radius is the kind's own `span` -- a rotor IS the span of a helicopter.
	var reach: float = span if span > 0.0 else long * 1.2
	var over: float = extents.y * 1.15
	_disc(build, Vector3(0.0, over, -long * 0.1), reach, reach * ROTOR_THIN, WING)


## A SHIP. Where the simulation holds a part list -- and every ship in this game does -- the hull is the workshop's own
## `ShipHull.far_mesh`, the prism silhouette that file already builds for a ship seen from more than 1,800 m away. That
## is precisely the job here, it is already measured (a destroyer's near model is 1,396 triangles and its far one far
## fewer), and building a second idea of a ship's outline beside it would be a second idea of a ship's outline.
static func _a_ship(build: SurfaceTool, extents: Vector3, parts: Array) -> void:
	if not parts.is_empty():
		var far: ArrayMesh = ShipHull.far_mesh(parts)
		if far != null and far.get_surface_count() > 0:
			var arrays: Array = far.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			# COLOURS AND INDICES MAY BOTH BE ABSENT, which is not an edge case: `Plating.weld` returns an INDEXED mesh
			# and a plain `commit()` does not, so `arrays[Mesh.ARRAY_INDEX]` is genuinely `null` for some ships and
			# typing it `PackedInt32Array` threw on every one of them. Read as Variant, then decide.
			var colours: Variant = arrays[Mesh.ARRAY_COLOR]
			var index: Variant = arrays[Mesh.ARRAY_INDEX]
			var tinted: PackedColorArray = colours if colours is PackedColorArray else PackedColorArray()
			var order: Array = []
			if index is PackedInt32Array and not (index as PackedInt32Array).is_empty():
				order = Array(index as PackedInt32Array)
			else:
				order = range(points.size())
			for step in order:
				build.set_color(tinted[step] if step < tinted.size() else BODY)
				build.add_vertex(points[step])
			return
	# A HULL FOR ANYTHING WITHOUT PARTS -- the sailing pirate is the only one -- as a pointed prism, which is a boat.
	_hexa(build, Vector3(0.0, 0.0, -extents.z), -extents.z * 0.45, extents.z * 0.92, extents.x, extents.y, BODY)


static func _a_box(build: SurfaceTool, extents: Vector3, tint: Color) -> void:
	_box_between(build, -extents, extents, tint)


## A SOLID WITH A POINTED NOSE: a point at `nose`, a full-width section at `shoulder` and a rectangular end at `tail`.
## Six faces, twelve triangles, and the cheapest shape that reads as "the front is that way".
static func _hexa(build: SurfaceTool, nose: Vector3, shoulder: float, tail: float, wide: float, tall: float,
		tint: Color) -> void:
	var front := [
		Vector3(-wide, -tall, shoulder), Vector3(wide, -tall, shoulder),
		Vector3(wide, tall, shoulder), Vector3(-wide, tall, shoulder)]
	var back := [
		Vector3(-wide, -tall, tail), Vector3(wide, -tall, tail),
		Vector3(wide, tall, tail), Vector3(-wide, tall, tail)]
	# THE NOSE CONE: a triangle from the point to each edge of the shoulder.
	for step in range(4):
		_triangle(build, nose, front[step], front[(step + 1) % 4], tint)
	# THE BODY between shoulder and tail.
	for step in range(4):
		var a: Vector3 = front[step]
		var b: Vector3 = front[(step + 1) % 4]
		_triangle(build, a, back[step], back[(step + 1) % 4], tint)
		_triangle(build, a, back[(step + 1) % 4], b, tint)
	# AND THE TAIL CAP.
	_triangle(build, back[0], back[2], back[1], tint)
	_triangle(build, back[0], back[3], back[2], tint)


## A FLYING SURFACE: a thin swept plate reaching `half` each side of the body at `at` along z.
static func _flat_wing(build: SurfaceTool, at: float, chord: float, half: float, thick: float, lift: float,
		sweep: float, tint: Color) -> void:
	var back: float = at + chord
	var tip_front: float = at + chord * sweep
	var tip_back: float = tip_front + chord * 0.42
	for side in [-1.0, 1.0]:
		var root_a := Vector3(0.0, lift, at)
		var root_b := Vector3(0.0, lift, back)
		var tip_a := Vector3(half * side, lift, tip_front)
		var tip_b := Vector3(half * side, lift, tip_back)
		for up in [thick, -thick]:
			var lift_by := Vector3(0.0, up, 0.0)
			_triangle(build, root_a + lift_by, tip_a + lift_by, tip_b + lift_by, tint)
			_triangle(build, root_a + lift_by, tip_b + lift_by, root_b + lift_by, tint)
		# THE EDGE, so the wing is a solid and not a sheet: seen edge-on across a board, a sheet vanishes.
		_quad(build, tip_a + Vector3(0.0, thick, 0.0), tip_b + Vector3(0.0, thick, 0.0),
			tip_b - Vector3(0.0, thick, 0.0), tip_a - Vector3(0.0, thick, 0.0), tint)


## THE FIN: the same plate stood on its edge, above the body.
static func _upright_fin(build: SurfaceTool, at: float, chord: float, tall: float, thick: float, tint: Color) -> void:
	var back: float = at + chord * 0.9
	var top_front: float = at + chord * 0.55
	for side in [thick, -thick]:
		_triangle(build, Vector3(side, 0.0, at), Vector3(side, tall, top_front), Vector3(side, tall, back), tint)
		_triangle(build, Vector3(side, 0.0, at), Vector3(side, tall, back), Vector3(side, 0.0, back), tint)
	_quad(build, Vector3(thick, tall, top_front), Vector3(thick, tall, back),
		Vector3(-thick, tall, back), Vector3(-thick, tall, top_front), tint)


## A THIN DISC, for a rotor.
static func _disc(build: SurfaceTool, middle: Vector3, reach: float, thick: float, tint: Color) -> void:
	for step in range(ROTOR_STEPS):
		var one: float = TAU * float(step) / float(ROTOR_STEPS)
		var two: float = TAU * float(step + 1) / float(ROTOR_STEPS)
		var a := middle + Vector3(cos(one) * reach, 0.0, sin(one) * reach)
		var b := middle + Vector3(cos(two) * reach, 0.0, sin(two) * reach)
		var up := Vector3(0.0, thick, 0.0)
		_triangle(build, middle + up, a + up, b + up, tint)
		_triangle(build, middle - up, b - up, a - up, tint)


static func _box_between(build: SurfaceTool, low: Vector3, high: Vector3, tint: Color) -> void:
	var points := [
		Vector3(low.x, low.y, low.z), Vector3(high.x, low.y, low.z),
		Vector3(high.x, high.y, low.z), Vector3(low.x, high.y, low.z),
		Vector3(low.x, low.y, high.z), Vector3(high.x, low.y, high.z),
		Vector3(high.x, high.y, high.z), Vector3(low.x, high.y, high.z)]
	var faces := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [2, 3, 7, 6], [0, 4, 7, 3], [1, 2, 6, 5]]
	for face in faces:
		_quad(build, points[face[0]], points[face[1]], points[face[2]], points[face[3]], tint)


static func _quad(build: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color) -> void:
	_triangle(build, a, b, c, tint)
	_triangle(build, a, c, d, tint)


static func _triangle(build: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	for point in [a, b, c]:
		build.set_color(tint)
		build.add_vertex(point)
