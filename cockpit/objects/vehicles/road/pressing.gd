@tool
extends RefCounted
class_name Pressing
## PRESSED STEEL PANEL, FOLDED AND SPOT-WELDED: the few shapes every road vehicle here is drawn from.
##
## `Plating` is the same idea for a ship, and everything it does -- boxes, bars, quads wound to face a
## given way, a prism from a plan outline -- is used here directly rather than copied. This file adds
## the two shapes a ship has no use for and a car cannot be drawn without:
##
## - **`loft`**, a box whose width and whose top and bottom vary ALONG ITS LENGTH. That one primitive
##   is the whole of a road vehicle's body: a bonnet that rises to a windscreen, a roof that runs flat
##   and falls to a boot, a nose and a tail drawn in from the flanks. A ship's `prism` cannot do it --
##   a prism's walls are vertical and its top is one flat plane, which is a shipping container.
## - **`wheel`**, an eight-sided prism on an axle across the vehicle. `Boxcar._wheel` is the same
##   wheel on the same reasoning and this is where the two of them now live; the railway's kept its
##   own while it was the only thing in the game with wheels on it.
##
## THE TESSELLATION, stated so nobody rounds it later (`modelling_here.md` section 4, and the user on
## 2026-09-17: "keep a somewhat lower poly look to models, not too many very round edges"). **A WHEEL
## IS AN EIGHT-SIDED PRISM AND NOTHING ELSE HERE IS ROUND AT ALL.** A body is a handful of flat quads
## with a hard crease at every station. Retessellating must not move a single measured dimension.
##
## EVERY FACE GETS ITS OWN NORMAL AND IS WOUND CLOCKWISE AS SEEN, through `Plating.facing`, which is
## Godot's front face. `SurfaceTool.generate_normals` smooths across every welded corner and would
## hand back exactly the rounded look these models are not supposed to have.
##
## COLOUR IS IN THE VERTICES, and the material that draws it must set `vertex_color_is_srgb` or a
## 0.43 red comes back near orange (`modelling_here.md` section 4, `ShipHull.painted`).
##
## AND KEEP TWO DARKS WELL APART. `SurfaceTool.commit` quantises vertex colour to eight bits a
## channel, so a suite that picks the wheels out of a mesh BY THEIR COLOUR needs a gap it can still
## see afterwards. The boxcar's first pair were 0.03 apart, could not be told apart after the commit,
## and the suite found no wheels at all on a car with eight of them.

const PLATING := preload("res://objects/vehicles/ships/plating.gd")

## HOW MANY SIDES A WHEEL HAS. Eight. Read the tessellation note above before changing it.
const WHEEL_SIDES: int = 8
## HOW BIG THE BRIGHT HUB IS on a wheel's face, as a share of the tyre's own radius. 0.55 leaves a
## tyre ring about as thick as the wheel it surrounds, which is what a road wheel looks like from the
## pavement. See `wheel`: drawn as one disc in the hub's colour, a car stands on four white plates.
const HUB_OF_WHEEL: float = 0.55


## A BODY LOFTED ALONG ITS LENGTH: a run of cross-sections, each a rectangle, with a flat quad
## bridging every pair and a cap at each end.
##
## `sections` is ordered FRONT TO BACK -- forward is -Z, so z ascends -- and each is
## `{z, half, low, high}`: how far out each flank stands from the centreline, and where the
## underside and the top of the body are, at that station. A section may repeat a z (a hard step)
## and may be degenerate in height or width, in which case the quads that would have no area are
## skipped rather than drawn edge-on: that is what draws a windscreen as the single raked quad
## between a cowl with no height and an A-pillar top with plenty.
##
## `tints` carries a colour per face and every key is optional: `side`, `top`, `bottom`, `front`,
## `back`. A key left out falls back to `side`, and `side` itself is the one that must be there.
## EVERY OPTIONAL TAKES ITS DEFAULT AT ITS OWN CALL SITE, never from a clamp's floor (CLAUDE.md
## rule 8) -- so a missing `side` is a push_error and nothing is drawn, rather than a black car.
##
## **A SECTION MAY OVERRIDE THE SPAN THAT FOLLOWS IT**, with `top`, `side` and `open`, and that is
## what draws a car rather than a loaf. A car's glass and its paint are not two different PARTS --
## they are the same lofted body with a different colour over three of its spans, and the windscreen
## is literally the TOP face between a cowl with no height and the top of the A-pillar. Without the
## override the roof and the windscreen are one colour, and a body drawn in one colour has no
## windscreen at all from any distance.
##
##   `top`    the colour of the top face between this section and the next
##   `side`   the colour of both flanks over that span
##   `open`   true to draw NO top face over that span, which is what makes a pickup's bed a bed
##            rather than a sealed box with a dark panel hidden inside it
static func loft(tool: SurfaceTool, sections: Array[Dictionary], tints: Dictionary) -> void:
	if sections.size() < 2:
		return
	if not tints.has("side"):
		push_error("[pressing] a loft needs at least a 'side' colour; it was handed %s" % [tints.keys()])
		return
	var side: Color = tints["side"]
	var top: Color = tints.get("top", side)
	var bottom: Color = tints.get("bottom", side)
	var front: Color = tints.get("front", side)
	var back: Color = tints.get("back", side)

	for i in range(sections.size() - 1):
		var a: Dictionary = sections[i]
		var b: Dictionary = sections[i + 1]
		var az: float = float(a["z"])
		var bz: float = float(b["z"])
		# SECTIONS RUN FRONT TO BACK AND MAY NOT GO BACKWARDS. A repeated z is a hard step and is
		# allowed; a span that runs the other way turns its four quads inside out, which draws a
		# vehicle with a length of body pointing the wrong way and every dimension check still green
		# because the bounds are unchanged. It cost this lane a hatchback whose roofline put a
		# section 80 mm behind the one after it.
		if bz < az:
			push_warning("[pressing] a loft's sections run backwards at %d: z %.3f then %.3f"
				% [i, az, bz])
			continue
		var ah: float = float(a["half"])
		var bh: float = float(b["half"])
		var alow: float = float(a["low"])
		var blow: float = float(b["low"])
		var ahigh: float = float(a["high"])
		var bhigh: float = float(b["high"])
		# THE TWO FLANKS. The outward direction is the face's own sign in x, which is all
		# `Plating.facing` needs to decide the winding; it works the true normal out itself.
		var flank: Color = a.get("side", side)
		for across in [-1.0, 1.0]:
			PLATING.facing(tool, [
				Vector3(across * ah, alow, az), Vector3(across * ah, ahigh, az),
				Vector3(across * bh, bhigh, bz), Vector3(across * bh, blow, bz),
			], Vector3(across, 0.0, 0.0), flank)
		# THE TOP AND THE UNDERSIDE.
		if not bool(a.get("open", false)):
			PLATING.facing(tool, [
				Vector3(-ah, ahigh, az), Vector3(ah, ahigh, az),
				Vector3(bh, bhigh, bz), Vector3(-bh, bhigh, bz),
			], Vector3.UP, a.get("top", top))
		PLATING.facing(tool, [
			Vector3(-ah, alow, az), Vector3(ah, alow, az),
			Vector3(bh, blow, bz), Vector3(-bh, blow, bz),
		], Vector3.DOWN, bottom)

	# THE TWO CAPS, so the body is a solid and not a trough.
	var nose: Dictionary = sections[0]
	var tail: Dictionary = sections[sections.size() - 1]
	PLATING.facing(tool, [
		Vector3(-float(nose["half"]), float(nose["low"]), float(nose["z"])),
		Vector3(float(nose["half"]), float(nose["low"]), float(nose["z"])),
		Vector3(float(nose["half"]), float(nose["high"]), float(nose["z"])),
		Vector3(-float(nose["half"]), float(nose["high"]), float(nose["z"])),
	], Vector3.FORWARD, front)
	PLATING.facing(tool, [
		Vector3(-float(tail["half"]), float(tail["low"]), float(tail["z"])),
		Vector3(float(tail["half"]), float(tail["low"]), float(tail["z"])),
		Vector3(float(tail["half"]), float(tail["high"]), float(tail["z"])),
		Vector3(-float(tail["half"]), float(tail["high"]), float(tail["z"])),
	], Vector3.BACK, back)


## A WHEEL: an eight-sided prism on an axle across the vehicle, centred at `at`, `wide` along the
## axle. `diameter` is the tyre's OVERALL diameter -- the figure a tyre size converts to.
##
## **IT CIRCUMSCRIBES THE REAL WHEEL, IT DOES NOT FIT INSIDE IT**, and that is the whole of what makes
## a faceted wheel the right size. An octagon drawn THROUGH the circle is only 0.924 of it across its
## flats, so a 632 mm tyre would stand 24 mm low, the vehicle would sit in the road rather than on it,
## and its rolling radius would be 7.6 per cent short -- a retessellation changing a measured
## dimension, which `modelling_here.md` section 4 forbids. Drawn ROUND the circle instead, the flat at
## the bottom touches the road exactly where the real contact patch is and the across-flats diameter
## IS the published one, whatever `WHEEL_SIDES` becomes.
##
## The half-step in the angle is what puts a flat at the bottom rather than a corner: a wheel resting
## on a point is a cog.
static func wheel(tool: SurfaceTool, at: Vector3, diameter: float, wide: float, tyre: Color,
		hub: Color) -> void:
	var radius: float = (diameter * 0.5) / cos(PI / float(WHEEL_SIDES))
	var half: float = wide * 0.5
	var ring: Array[Vector2] = []
	for i in range(WHEEL_SIDES):
		var angle: float = TAU * (float(i) + 0.5) / float(WHEEL_SIDES)
		ring.append(Vector2(cos(angle), sin(angle)) * radius)
	for i in range(WHEEL_SIDES):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % WHEEL_SIDES]
		# The tread: one flat facet a side, its own normal, so the wheel shows its facets.
		PLATING.facing(tool, [
			at + Vector3(-half, a.y, a.x), at + Vector3(half, a.y, a.x),
			at + Vector3(half, b.y, b.x), at + Vector3(-half, b.y, b.x),
		], Vector3(0.0, (a.y + b.y) * 0.5, (a.x + b.x) * 0.5).normalized(), tyre)
		# AND THE TWO FACES, AS A TYRE RING ROUND A SMALL HUB -- not one disc in the hub's colour.
		#
		# A road wheel is seen from the side far more often than a railway wheel is, and from the
		# side it is almost all TYRE: the wheel itself is a bright disc in the middle of a black
		# ring, and the ring is the thicker of the two. Drawn as `Boxcar` draws it, one fan from the
		# centre in the hub's colour, every car in the first picture of the line-up stood on four
		# white discs -- the tread was there, edge on, and a metre away nobody could see it.
		var inner := Vector2(a.x, a.y) * HUB_OF_WHEEL
		var inner_b := Vector2(b.x, b.y) * HUB_OF_WHEEL
		for face in [-1.0, 1.0]:
			var out := Vector3(face, 0.0, 0.0)
			PLATING.facing(tool, [
				at + Vector3(face * half, a.y, a.x), at + Vector3(face * half, b.y, b.x),
				at + Vector3(face * half, inner_b.y, inner_b.x),
				at + Vector3(face * half, inner.y, inner.x),
			], out, tyre)
			tri(tool, at + Vector3(face * half, 0.0, 0.0),
				at + Vector3(face * half, inner.y, inner.x),
				at + Vector3(face * half, inner_b.y, inner_b.x), out, hub)


## A TRIANGLE facing `out`. `Plating` has no three-cornered shape -- everything on a ship is a quad or
## a prism -- and `Plating.facing` indexes its fourth corner, so handing it three raises "invalid
## access of index 3" once per face (`Boxcar._tri`, which found it the expensive way).
static func tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3,
		tint: Color) -> void:
	var order: Array[Vector3] = [a, b, c]
	if (c - a).cross(b - a).dot(out) < 0.0:
		order = [a, c, b]
	tool.set_color(tint)
	for corner in order:
		tool.set_normal(out)
		tool.add_vertex(corner)


## THE MATERIAL EVERY ROAD VEHICLE IS DRAWN WITH. Vertex colour AS SRGB: without the flag Godot reads
## vertex colour as linear and every painted panel comes back a stop or two bright (`ShipHull.painted`,
## and `lane/carrier`'s 0.19 non-skid deck that drew at 0.47).
static func painted() -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	# A car is waxed and a lorry is not; 0.55 is between them and is one number rather than nine.
	# The gloss that tells them apart is a finish question and is not worth a material each.
	paint.roughness = 0.55
	return paint


## A TYRE SIZE CONVERTED TO AN OVERALL DIAMETER IN METRES, by the ISO metric formula and nothing else:
## `315/80 R22.5` is a 315 mm section at an 80 per cent aspect on a 22.5 inch rim, so the diameter is
## the rim plus two sidewalls.
##
## THE FORMULA IS PUBLISHED AND THE FITMENT IS NOT, and that distinction is the point of this function
## existing at all. Every caller passes a tyre size it has to justify in `craft/road/sources.md`; what
## happens to it afterwards is arithmetic nobody has to check twice. The Atego and the Volvo coach
## both print `315/80 R22.5` on their own data sheets, which is the only place on this lane a fitment
## is PUBLISHED rather than ESTIMATE -- it comes out at 1.0755 m.
static func tyre(section_mm: float, aspect_percent: float, rim_inches: float) -> float:
	return (rim_inches * 0.0254) + 2.0 * (section_mm * 0.001) * (aspect_percent * 0.01)
