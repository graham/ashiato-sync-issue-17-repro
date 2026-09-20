extends RefCounted
class_name CoolingTower
## A NATURAL-DRAUGHT HYPERBOLIC COOLING TOWER, DRAWN FROM FOUR PUBLISHED DIMENSIONS AND ONE MEASURED SHAPE.
##
## WHY THE WAIST IS THE WHOLE JOB. A cooling tower is recognised by one thing and nothing else: the
## hyperboloid of one sheet, wide at the ring beam, pinched about four fifths of the way up, and flared
## again at the lip. Put the waist in the middle and you have drawn an egg-timer that nobody has ever
## seen; put it at the top and you have drawn a chimney. So this file's real content is three numbers --
## `throat_height`, `throat_radius` and `waist_constant` -- and every one of them is DERIVED from the
## published envelope rather than typed, because a number typed beside another number is the one thing
## that can quietly stop agreeing with it (building_a_game_here.md, "one number, one place").
##
## THE ENVELOPE, PUBLISHED. Film Cooling Towers Limited, the British contractor that built most of the
## CEGB's reinforced-concrete towers, records one job with a COMPLETE and internally consistent set of
## four dimensions from a single authority:
##
##   [FCT] en.wikipedia.org/wiki/Film_Cooling_Towers_Limited, "Design and construct for BP Chemicals at
##         its Baglan Bay chemicals plant, two natural draught hyperbolic cooling towers. Dimensions:
##         height 296 ft., ring beam diameter 244 ft.; throat diameter 124 ft.; top diameter 131 ft."
##
## That set is used verbatim, in feet, converted here. It was preferred over the better-known stations
## because those give two numbers and no datum. The same [FCT] table says "Didcot 6 x 11.4 m3/s, RC 114 m
## high 91 m diam" -- and does not say WHERE the 91 m is measured. `modelling_here.md` section 3: a
## published dimension has a datum, and if the source does not say what it is, it is not yet evidence.
## Taken as a ring beam diameter it puts this shape's throat at two thirds of the base, against 0.47 and
## 0.51 from the two sources that do give a complete set. So it is recorded and not used.
##
##   [PS] powerstations.uk/ferrybridge-c-power-station-west-yorkshire: Ferrybridge C, "Each cooling tower
##        was 350ft high, with diameters at the base of 350ft, at the throat 165ft and at the top 180ft."
##        A SECOND complete set, used ONLY as a cross-check, never as a dimension here. Its height
##        disagrees with Hansard's and Wikipedia's 375 ft for the same towers, and those towers were
##        exceptionally wide for their height -- three of them fell in the gale of 1 November 1965 -- so
##        they are the wrong tower to copy and the right one to check a ratio against.
##
## THE SHAPE, MEASURED, AND IT SETTLES WHAT THE PUBLISHED HEIGHT MEANS. A hyperboloid of one sheet is
## `r(y) = r_throat * sqrt(1 + ((y - y_throat) / b)^2)`, and `b` -- how sharply the waist is drawn -- is the
## parameter a plausible-looking wrong tower hides. It was measured off a Commons photograph rather than
## assumed:
##
##   [EGG] commons.wikimedia.org, "Eggborough cooling towers - geograph.org.uk - 6003681.jpg", CC BY-SA 2.0,
##         1280 x 887, a long-lens near-level elevation of the eight Eggborough towers in silhouette. The
##         left tower's outline was taken by thresholding sky (252 +/- 1) against shell (78 +/- 9) at 200,
##         and its LEFT edge fitted over 299 rows, y = 232..530, by least squares on r^2 against
##         (1, y, y^2) -- the exact linear form of the hyperbola, so the fit is closed-form and cannot
##         wander. Result: r_throat 101.82 px, y_throat 330.7 px, b 249.1 px, rms residual 0.38 px,
##         worst row 1.02 px. The RIGHT edge, fitted independently over 407 rows down to y = 662, gives
##         r_throat 101.81 px and b 255.7 px -- two edges of the same tower that were fitted separately
##         agreeing on the throat radius to 0.015 px. The camera is 3.6 degrees off level, measured from
##         the rim ellipse (7 px deep against a 112 px semi-major), so vertical foreshortening is 0.2 per
##         cent -- below the pixel, and evaluated rather than assumed.
##
##         ONE PIXEL IS WORTH about 0.19 m at this scale (101.8 px for a 18.9 m throat radius), so nothing
##         off it is better than about 0.2 m, which is ample for a shape ratio and useless for a fitting.
##
##         The measurement is a RATIO, `b / r_throat = 2.4465`, and carries no scale -- the tower's base is
##         behind trees in that photograph and its height was never measured. That is what makes it an
##         independent check rather than a second opinion on the same numbers.
##
## AND THAT RATIO CHOSE THE DATUM. The whole measurement is re-derived from the photograph alone, with
## nothing typed out of the write-up, by `measure_tower.py` beside the references in
## `~/godotgames-drafts/2026-09-17/cockpit-cooling/research/`, which also draws the overlay.
## [FCT]'s "height 296 ft." does not say whether it is measured from the
## pond or from the ring beam, and the two readings are not a detail: read as the SHELL height, ring beam
## to lip, the published set implies `b / r_throat = 2.3456`, which is 4.1 per cent from the measured
## 2.4465; read as the OVERALL height with the columns inside it, it implies 2.1116, 13.7 per cent away.
## The photograph never saw Baglan Bay and the table never saw Eggborough, so this is two references that
## could not influence each other agreeing on a third quantity (`modelling_here.md` section 3), and it is
## why `SHELL_HEIGHT_FT` is the shell and the columns are added below it.
##
## THREE ROUTES TO THE WAIST, WHICH IS THE ONE NUMBER WORTH ARGUING ABOUT. As a fraction of the shell's own
## height the throat sits at 0.8326 here (from [FCT]'s four numbers), 0.8110 from [PS]'s four, and the
## [EGG] silhouette puts it at 0.8148 once its base is taken at the ratio those two agree on. A tower whose waist is
## anywhere outside 0.80 to 0.85 is the wrong shape, and `tests/cooling_towers.gd` says so in those words.
##
## WHAT IS NOT MEASURED, AND WHAT WOULD SETTLE IT. `COLUMN_HEIGHT` is an ESTIMATE: no source read here gives
## the height of the raked columns that carry the ring beam, and the one photograph good enough to measure
## them on has its tower bases behind a treeline. A photograph in which a tower's column bay is clear against
## sky, or any published ring-beam level, would settle it; until then the overall height of this tower is its
## published shell height plus a guess, and it is the guess that decides how much air shows under the shell.
##
## LOW POLY, AND THE COUNTS ARE HERE SO NOBODY "IMPROVES" THEM. `modelling_here.md` section 4: flat panels,
## hard creases, few segments on anything round. `SIDES` is 20, which is the Hawkeye's nacelle count, and
## `RINGS` is 11 bands. Every face carries its own normal -- `SurfaceTool.generate_normals` would smooth
## across every crease and give back exactly the rounded look the house style asks against -- and the colour
## is in the vertices, so the material must set `vertex_color_is_srgb` or a 0.62 concrete draws at 0.84.
##
## RINGS ARE SPACED IN THE HYPERBOLA'S OWN PARAMETER, not in height. `y = y_throat + b * sinh(t)` walked in
## equal steps of `t` puts rings close together where the curve bends -- at the waist -- and far apart up the
## nearly straight flanks, which is where a faceted hyperboloid either reads as a tower or reads as a cone.
## A ring sits exactly ON the throat: see `ring_heights`, where walking the span in equal steps of `t` and
## nothing else put the narrowest drawn ring 1.6 m above the waist the envelope solves to.
##
## THE SHELL IS ONE SURFACE, DRAWN FROM BOTH SIDES. A cooling tower is a hollow shell open at the top, and an
## aeroplane at two thousand feet looks into it. Two-sided by `CULL_DISABLED` on the material rather than by a
## second set of triangles: the inside is the same 440 triangles seen from behind, lit flat, which at the
## distance anything here is seen from is the difference between a tower and a tower-shaped hole.

## THE PUBLISHED ENVELOPE [FCT], in the feet it was published in. Converted once, below, and never retyped.
const SHELL_HEIGHT_FT: float = 296.0
const RING_BEAM_DIAMETER_FT: float = 244.0
const THROAT_DIAMETER_FT: float = 124.0
const TOP_DIAMETER_FT: float = 131.0
const FOOT: float = 0.3048

## HOW HIGH THE RING BEAM STANDS ON ITS RAKED COLUMNS, metres. ESTIMATE -- see the doc block. It is the one
## number here with no source behind it, and it is the only thing that separates the published shell height
## from the tower's overall height.
const COLUMN_HEIGHT: float = 9.0
## How many raked A-frames carry the ring beam, and how thick each leg is. ESTIMATE, from [EGG]'s column bays.
const COLUMNS: int = 20
const COLUMN_THICKNESS: float = 1.1
## How far round the tower each A-frame's feet are splayed either side of its head, in degrees. The X pattern
## every photograph of one of these shows is two neighbouring frames' legs crossing, not one frame's.
const COLUMN_SPLAY_DEG: float = 9.0

## THE POND the tower stands in: a low ring wall a little wider than the shell, which is what makes the
## columns read as columns rather than as a fringe. ESTIMATE.
const POND_MARGIN: float = 7.0
const POND_WALL: float = 2.2

## TESSELLATION. See the doc block; state these, do not raise them.
const SIDES: int = 20
const RINGS: int = 11

## ---- what the simulation may hit --------------------------------------------------------------
##
## A COOLING TOWER IS A CURVE AND A STATIC BOX HAS NO ROTATION, so the solid is an approximation and the
## only honest question is WHICH WAY IT IS ALLOWED TO BE WRONG. It is allowed to be wrong INWARDS only:
## every box is strictly inside the drawn shell, so a pilot may clip the skin before the collision
## registers, and can never hit anything where there is nothing to see. The other way round -- a box that
## sticks out past the shell -- is an invisible wall in open air, which is both worse to fly into and,
## more to the point here, **unfindable**: "no box corner is outside the drawn mesh" is a thing a check can
## assert from the drawn vertices, and "the invisible wall is not too bad" is not.
##
## SO THE SHAPE WAS CHOSEN BY MEASURING BOTH ERRORS, not by picking a number. Metres of penetration into
## the drawn shell before a box stops you, worst over every band and every bearing, against metres by which
## anything is claimed outside the drawn 20-gon:
##
##     one inscribed square a band      11 boxes   14.18 m in   0.000 m out
##     one "equal error" square a band  11 boxes    9.74 m in   5.690 m OUT  <- rejected: invisible wall
##     three boxes a band, all at 45    33 boxes   12.81 m in   0.000 m out
##     three boxes a band, 22.5/45/67.5 33 boxes   11.01 m in   0.000 m out  <- chosen
##
## The cross of three buys 3.2 m over the single square for three times the boxes and keeps the guarantee.
## Its three rectangles have their corners at 22.5, 45 and 67.5 degrees, which is why nothing is claimed
## outside: cos^2 + sin^2 = 1 for each pair below.
##
## THE BANDS ARE THE DRAWN RINGS, AND THAT IS WHAT MAKES THE CLAIM EXACT RATHER THAN NEARLY EXACT. Cutting
## the solid on heights of its own choosing meant a band end could fall between two drawn rings, so the
## check had to compare a box against a CHORD of the drawn mesh -- and a chord under a convex curve sags,
## by about 0.17 m here, which is the same size as the thing being checked. Cut on `ring_heights()` there is
## nothing to interpolate: a band's radius IS a drawn ring's radius, and
## `tests/cooling_towers.gd:every_collision_box_is_inside_the_drawn_shell` compares boxes to vertices with
## no arithmetic in between. It also means a retessellation moves the solid with the shape.
##
## AND THE RADII ARE THE 20-GON'S, NOT THE CIRCLE'S. What is drawn is a twenty-sided prism per band whose
## flats lie `cos(PI / SIDES)` inside the circle, which is 1.23 per cent -- 0.46 m at the ring beam. A box
## fitted to the circle would poke through its own flats by that much, so `SOLID_POLY` takes it off.
##
## WHAT IT COSTS, MEASURED AND NOT FELT: 33 boxes a tower, 66 for the pair. The island files **1,014**
## boxes today (`tests/world_map.gd`), so the station is **6.5 per cent** on top of it, and CLAUDE.md
## rule 8 prices a box at about 930 bytes and a tick at nothing.
##
## THE COLUMN BAY IS NOT SOLID, AND THAT IS THE SAME RULE APPLIED HONESTLY. The shell springs from its ring
## beam at `COLUMN_HEIGHT`; below that are twenty raked legs and a great deal of air. Filling it would claim
## solid where nothing is drawn. So there is a 9.0 m gap under a 99 m tower that an aircraft can fly
## through, which is what the drawn model says and what a real tower does.
##
## AND THE INSIDE IS SOLID, which a hollow shell is not. Modelling the skin as a wall needs boxes tangent to
## a curve and an axis-aligned box cannot be one. A pilot who flies in through a 40 m opening 99 m up has
## earned whatever happens next.

## The three boxes of a band, as (x, z) shares of that band's narrowest drawn radius. Corners at 22.5, 45
## and 67.5 degrees, each exactly on the circle.
const SOLID_CROSS: Array[Vector2] = [
	Vector2(0.92388, 0.38268),
	Vector2(0.38268, 0.92388),
	Vector2(0.70711, 0.70711),
]

## HOW FAR INSIDE ITS OWN CIRCLE A DRAWN RING'S FLATS LIE: `cos(PI / SIDES)`, 1.23 per cent at 20 sides.
## Typed rather than computed because a `const` cannot call `cos`, and held to `cos(PI / SIDES)` by
## `tests/cooling_towers.gd` so it cannot go stale if anybody changes `SIDES`.
const SOLID_POLY: float = 0.98769

## Weathered concrete, and the streaking that makes a 90 m blank wall read as 90 m rather than as grey paper.
## THESE WERE 0.62 / 0.44 / 0.55 AND THE FIRST PICTURE CAME BACK LOOKING LIKE WHITE PLASTIC. Under the
## island's sun a 0.62 shell reads as near-white against green, and a cooling tower that has stood in the
## weather for fifty years is a dirty grey with the rain streaked down the last third of it. Nothing moved
## in any check; screenshots/2026-09-17/cockpit-cooling-01-first-look-concrete-too-pale.png is the before.
const CONCRETE: Color = Color(0.50, 0.50, 0.48)
const CONCRETE_DARK: Color = Color(0.30, 0.30, 0.30)
const COLUMN_TINT: Color = Color(0.44, 0.43, 0.42)
const POND_TINT: Color = Color(0.38, 0.39, 0.38)


## ---- the profile: the one authority for what radius this tower has at what height ----------------

## The published envelope in metres. Everything else asks these four; nothing types a metre.
static func shell_height() -> float:
	return SHELL_HEIGHT_FT * FOOT


static func ring_beam_radius() -> float:
	return RING_BEAM_DIAMETER_FT * FOOT * 0.5


static func throat_radius() -> float:
	return THROAT_DIAMETER_FT * FOOT * 0.5


static func top_radius() -> float:
	return TOP_DIAMETER_FT * FOOT * 0.5


## The whole tower, pond to lip. The published height is the SHELL -- see the doc block on the datum.
static func overall_height() -> float:
	return COLUMN_HEIGHT + shell_height()


## `b`, THE WAIST CONSTANT: how far up the shell the radius grows by a factor of sqrt(2) from the throat.
## Solved from the envelope, never typed. The shell height is the sum of the two half-heights the ring beam
## radius and the top radius each imply, and both are `b` times a pure number, so `b` falls straight out.
static func waist_constant() -> float:
	var below: float = sqrt(pow(ring_beam_radius() / throat_radius(), 2.0) - 1.0)
	var above: float = sqrt(pow(top_radius() / throat_radius(), 2.0) - 1.0)
	return shell_height() / (below + above)


## HOW FAR THE WAIST IS ABOVE THE RING BEAM, metres. The number the whole model is judged on.
static func throat_height() -> float:
	return waist_constant() * sqrt(pow(ring_beam_radius() / throat_radius(), 2.0) - 1.0)


## THE PROFILE. `y` is metres above the RING BEAM, so 0 is the widest point of the shell and
## `shell_height()` is the lip. Ask this; do not keep a table of radii beside it.
static func radius_at(y: float) -> float:
	var offset: float = (y - throat_height()) / waist_constant()
	return throat_radius() * sqrt(1.0 + offset * offset)


## THE HEIGHTS THE RINGS ARE DRAWN AT, walked in the hyperbola's own parameter so they crowd the waist.
## Exported because the suite has to check the spacing is what the doc block claims without recomputing it.
static func ring_heights() -> PackedFloat64Array:
	var b: float = waist_constant()
	var throat: float = throat_height()
	var from_t: float = _asinh(-throat / b)
	var to_t: float = _asinh((shell_height() - throat) / b)
	# A RING SITS EXACTLY ON THE THROAT, and the bands are shared out either side of it in proportion to
	# how much of the parameter each side takes. Walking the whole span in equal steps put the narrowest
	# DRAWN ring 1.6 m above the throat -- 0.8507 of the shell against the 0.8326 the envelope solves to --
	# so the model's own crease was in a different place from the number it is judged on
	# (`tests/cooling_towers.gd:the_narrowest_drawn_ring_is_the_throat`, red before this).
	var below: int = clampi(int(round(float(RINGS) * (-from_t) / (to_t - from_t))), 1, RINGS - 1)
	var out: PackedFloat64Array = []
	for i in range(below + 1):
		out.append(throat + b * _sinh(from_t * (1.0 - float(i) / float(below))))
	for i in range(1, RINGS - below + 1):
		out.append(throat + b * _sinh(to_t * float(i) / float(RINGS - below)))
	return out


## The two hyperbolic functions this needs, written out. Godot 4.7's global scope has `sinh` and `asinh`
## in some builds and not in others, and a model that stops building on the stock editor because of a
## one-line convenience is not a convenience (`working_with_godot.md`: never rely on training data for a
## 4.x signature -- so where it is one line, write the line).
static func _sinh(t: float) -> float:
	return (exp(t) - exp(-t)) * 0.5


static func _asinh(x: float) -> float:
	return log(x + sqrt(x * x + 1.0))


## WHAT A BODY CAN HIT, as `{position, half_extents}` in the same shape `Sim.add_static_box` and
## `SkyfrontHangar.boxes()` use, offset to where the tower stands. See the note above the constants for why
## it is this shape and what it costs; `tests/cooling_towers.gd` holds every box inside the drawn mesh.
##
## A BAND TAKES THE NARROWER OF ITS TWO DRAWN RINGS, which is all a band needs: the mesh between two rings
## is a straight prism, so its narrowest cross-section is one end or the other and there is no curve in
## between to miss. `ring_heights()` already puts a ring exactly on the throat.
static func collision_boxes(at: Vector3 = Vector3.ZERO) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var heights: PackedFloat64Array = ring_heights()
	for band in range(heights.size() - 1):
		var low: float = float(heights[band])
		var high: float = float(heights[band + 1])
		var narrowest: float = minf(radius_at(low), radius_at(high)) * SOLID_POLY
		var middle: float = COLUMN_HEIGHT + (low + high) * 0.5
		for share in SOLID_CROSS:
			out.append({
				"position": at + Vector3(0.0, middle, 0.0),
				"half_extents": Vector3(narrowest * share.x, (high - low) * 0.5, narrowest * share.y),
			})
	return out


## ---- the mesh ------------------------------------------------------------------------------------

## ONE TOWER, ONE MESH, ONE SURFACE, with the pond's rim at y = 0 and the lip at `overall_height()`.
static func build() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_shell(tool)
	_columns(tool)
	_pond(tool)
	return tool.commit()


## The material the shell wants: two-sided, unshiny, and told that its vertex colours are already sRGB.
static func concrete_material() -> StandardMaterial3D:
	var skin := StandardMaterial3D.new()
	skin.vertex_color_use_as_albedo = true
	skin.vertex_color_is_srgb = true
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	skin.roughness = 0.95
	skin.metallic = 0.0
	return skin


## THE SHELL: `RINGS` bands of `SIDES` flat quads, each quad its own four vertices and one normal.
static func _shell(tool: SurfaceTool) -> void:
	var heights: PackedFloat64Array = ring_heights()
	for band in range(RINGS):
		var y0: float = float(heights[band])
		var y1: float = float(heights[band + 1])
		var r0: float = radius_at(y0)
		var r1: float = radius_at(y1)
		# Streaking: the bands nearest the lip are the ones the rain runs down, and they are darker.
		var wet: float = clampf((y0 - throat_height()) / maxf(shell_height() - throat_height(), 0.001), 0.0, 1.0)
		var tint: Color = CONCRETE.lerp(CONCRETE_DARK, wet * 0.8)
		# THE RING BEAM IS AT `COLUMN_HEIGHT`, not at the ground: `ring_heights` and `radius_at` are both
		# measured from the ring beam, because that is the datum the published diameters are quoted at, and
		# the tower's own origin is the pond. Drawing the shell without this offset stood it in the water.
		var base0: float = COLUMN_HEIGHT + y0
		var base1: float = COLUMN_HEIGHT + y1
		for k in range(SIDES):
			var a0: float = TAU * float(k) / float(SIDES)
			var a1: float = TAU * float(k + 1) / float(SIDES)
			var out: Vector3 = Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
			_quad(tool,
				_on(a0, r0, base0), _on(a1, r0, base0), _on(a1, r1, base1), _on(a0, r1, base1),
				out, tint.darkened(0.06 * float(k % 3)))


## THE RAKED COLUMNS: `COLUMNS` A-frames under the ring beam, each a pair of legs splayed either side of its
## head, so neighbouring frames' legs cross in the X every photograph of one of these shows. Four flat faces
## a leg and no caps -- a leg's ends are buried in the pond and in the ring beam.
static func _columns(tool: SurfaceTool) -> void:
	# THE HEADS ARE TUCKED INSIDE THE RING BEAM by a leg's thickness, so that nothing a column draws is
	# wider than the shell it carries and "the tower is widest at the ring beam" stays a thing a check can
	# ask of the drawn vertices. The feet splay outwards, which is what makes the X read from the ground.
	var head_r: float = ring_beam_radius() - COLUMN_THICKNESS
	var foot_r: float = ring_beam_radius() + 1.2
	var splay: float = deg_to_rad(COLUMN_SPLAY_DEG)
	for k in range(COLUMNS):
		var a: float = TAU * float(k) / float(COLUMNS)
		for side in [-1.0, 1.0]:
			var head: Vector3 = _on(a, head_r, COLUMN_HEIGHT)
			var foot: Vector3 = _on(a + splay * side, foot_r, 0.0)
			_leg(tool, foot, head, COLUMN_THICKNESS, COLUMN_TINT)


## THE POND WALL: a plain ring a little wider than the shell, which is what gives the columns something to
## stand in. Outer face and rim only; nobody here ever sees the water.
static func _pond(tool: SurfaceTool) -> void:
	var r: float = ring_beam_radius() + POND_MARGIN
	for k in range(SIDES):
		var a0: float = TAU * float(k) / float(SIDES)
		var a1: float = TAU * float(k + 1) / float(SIDES)
		var out: Vector3 = Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		_quad(tool, _on(a0, r, 0.0), _on(a1, r, 0.0), _on(a1, r, POND_WALL), _on(a0, r, POND_WALL),
			out, POND_TINT)
		_quad(tool, _on(a0, r, POND_WALL), _on(a1, r, POND_WALL),
			_on(a1, r - 1.6, POND_WALL), _on(a0, r - 1.6, POND_WALL), Vector3.UP, POND_TINT.lightened(0.1))


## ---- the small helpers -----------------------------------------------------------------------------

## A point on a ring: `angle` round the tower's axis, `radius` out, `y` up.
static func _on(angle: float, radius: float, y: float) -> Vector3:
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)


## ONE FLAT QUAD as two triangles, both wound so their faces look along `out`, each carrying the quad's own
## normal. Copied from `HawkeyeAirframe._fan`'s convention -- `(c - a).cross(b - a)` is the face -- because
## a model that is wound the other way is invisible and nothing else will find it.
static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		out: Vector3, tint: Color) -> void:
	_face(tool, a, b, c, out, tint)
	_face(tool, a, c, d, out, tint)


static func _face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-12:
		return
	if normal.dot(out) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	tool.set_color(tint)
	for corner in [a, b, c]:
		tool.set_normal(normal.normalized())
		tool.add_vertex(corner)


## ONE RAKED LEG: a square prism from `foot` to `head`, four flat faces, no caps.
static func _leg(tool: SurfaceTool, foot: Vector3, head: Vector3, thickness: float, tint: Color) -> void:
	# THE CROSS-SECTION IS HORIZONTAL, not square to the leg, so a raked leg is a sheared prism. Square to
	# the leg is the more honest solid and it puts the foot's lower corners 0.31 m UNDER the pond and the
	# head's upper corners 0.31 m over the ring beam, which makes the model's drawn bounds 0.6 m taller
	# than the tower and un-checkable against the published envelope. At 1.1 m thick and a few degrees of
	# rake the difference in the picture is nothing; the difference in what can be asserted is everything.
	var along: Vector3 = (head - foot)
	var flat: Vector3 = Vector3(along.x, 0.0, along.z)
	if flat.length_squared() < 1e-9:
		flat = Vector3(head.x, 0.0, head.z)
	if flat.length_squared() < 1e-9:
		flat = Vector3.RIGHT
	flat = flat.normalized() * (thickness * 0.5)
	var side: Vector3 = Vector3(-flat.z, 0.0, flat.x)
	var corners: Array[Vector3] = [flat + side, flat - side, -flat - side, -flat + side]
	for i in range(4):
		var p: Vector3 = corners[i]
		var q: Vector3 = corners[(i + 1) % 4]
		var out: Vector3 = ((p + q) * 0.5).normalized()
		_quad(tool, foot + p, foot + q, head + q, head + p, out, tint)
