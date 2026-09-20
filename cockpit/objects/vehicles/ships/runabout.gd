@tool
extends RefCounted
class_name Runabout
## A TRIPLE-COCKPIT MAHOGANY RUNABOUT, NEAR: one vertex-coloured mesh on the shape's parts.
##
## THE PARTS ARE THE AUTHORITY (`RunaboutDraft` until the kind is C++): length, beam, draught, the deck and the three
## cockpit wells are theirs, and this adds what nothing collides with -- the planked deck and its seams, the coamings,
## the benches, the windscreen, the engine hatch and every piece of chrome. `craft/runabout/sources.md` says where each
## figure came from and how much of it is estimated, which on this boat is most of it and is said so.
##
## THE BOAT TYPE AND NOT THE BOAT. No builder's name, no script logo, no hull graphic. The gold `Chris*Craft` script on
## the topsides of every reference photograph is a trademark and is deliberately not drawn.
##
## ## WHAT MAKES IT READ AS A CHRIS-CRAFT AND NOT AS A BROWN BOAT
##
## Four things, in the order a viewer notices them, and every one of them is a COLOUR rather than a shape:
##
## 1. **The wood is VARNISHED, not painted**, so it is a deep warm red-brown that swings enormously with the light.
##    `MAHOGANY` is the measured hue at a judged level -- see below.
## 2. **The deck is the same wood as the topsides.** It reads much lighter in every photograph and the model must NOT
##    bake that in: a photograph's pixel is albedo times light and a vertex colour is albedo alone, so a deck drawn
##    lighter would be lighter AGAIN once the game lit it, and a mahogany deck would come out tan.
## 3. **What actually distinguishes the deck is the WALNUT king plank and covering board and the WHITE seams between
##    the planks.** [S] publishes the materials in those words. The planks are drawn as geometry rather than painted on,
##    because they taper into the covering board along the boat's own curve and a stripe cannot.
## 4. **Chrome, and a lot of it**: the rub rail down the sheer, the cutwater on the stem, the transom band, the
##    engine-compartment vents, the cleats and the windscreen frame [S].
##
## **THE TOPSIDE SEAMS RUN DARK AND THE DECK SEAMS RUN PALE, and they are not the same detail.** The pale seam is deck
## caulking compound. The hull is seam-and-batten planked and its topside seams read as fine dark lines in the two
## sharp reference frames. Pale seams down the topsides would be the deck's detail on the wrong surface -- which was
## the first draft's mistake, from the brief rather than from a photograph.
##
## ## THE COLOURS, AND WHERE THEY CAME FROM
##
## `craft/runabout/measure_photos.py` re-derives every one of them from three CC BY 2.0 photographs and reads neither
## this file nor `sources.md`, so all three can disagree and two of them be wrong. Eight mahogany patches on two boats
## in two lights give a chromaticity of **G:R 0.185 (sd 16 per cent), B:R 0.095 (sd 26 per cent)**, and the residual is
## printed by the script rather than described. **The LEVEL is a judgement and is said to be one**: only the overcast
## frame is lit flatly enough to stand for a paint chip, so its topside sets how bright the wood is and the two sunlit
## frames set only the hue.
##
## COLOURS ARE sRGB because `ShipHull.painted()` sets `vertex_color_is_srgb`. Read as linear they come out near white.
## EVERY PAIR HERE IS AT LEAST 0.03 APART IN SOME CHANNEL, because `SurfaceTool.commit` quantises vertex colour to
## eight bits and every suite in this workshop finds a part BY its colour. `WALNUT` was moved cooler and `ANTIFOUL`
## darker for exactly that reason: at the first draft's (0.24, 0.13, 0.09) and (0.26, 0.12, 0.08) they were two
## hundredths apart on all three channels, and no check could have told a covering board from the bottom paint.
##
## ## TESSELLATION -- DO NOT SUBDIVIDE
##
## The house look is faceted and low-poly and the E-2D Hawkeye's airframe is the reference (the user, 2026-09-17).
## `HULL_STATIONS` is 8 a hull part, `DECK_STATIONS` is 16 along the whole boat, a cleat is a box and the windscreen
## is two flat panes. The sizes are published; the facets are the style.

## THE PALETTE. See the doc block for what is measured and what is judged.
const MAHOGANY := Color(0.46, 0.20, 0.13)
const WALNUT := Color(0.26, 0.16, 0.12)
const SEAM := Color(0.72, 0.69, 0.62)
const STRIPE := Color(0.90, 0.90, 0.88)
const ANTIFOUL := Color(0.22, 0.13, 0.05)
const CHROME := Color(0.74, 0.76, 0.78)
const VINYL := Color(0.55, 0.44, 0.29)
const GLASS := Color(0.32, 0.38, 0.44)
const MAT := Color(0.09, 0.09, 0.10)
## THE TOPSIDE SEAM, a shade of the wood rather than a colour of its own -- a seam is the wood in shadow between two
## planks. Kept 0.04 off `WALNUT` in red so a check can still tell a covering board from a seam.
const TOPSIDE_SEAM := Color(0.20, 0.09, 0.06)
## THE WHEEL'S RIM: a dark bakelite ring on a chrome column, which is what a banjo wheel is.
const WHEEL := Color(0.14, 0.11, 0.10)

## WHAT THE SILHOUETTE IS PAINTED, for `ShipHull.far_mesh`. A runabout is not haze grey at any distance, and at the
## range where the near model gives way she is a dark warm speck with a pale line at the water.
const FAR: Dictionary = {
	"hull": MAHOGANY,
	"deck": MAHOGANY,
	"island": MAHOGANY,
	"bridge": MAT,
}

## HALF THE WIDTH OF THE PAINTED WATERLINE STRIPE. A DEFAULT WOULD RUIN HER: `HullLoft.BOOT_TOP` is 0.8 m, chosen
## against warships with eight metres of freeboard, and on a boat with 0.62 m of freeboard it would paint the entire
## topside white -- which is the fault the fireboat met and wrote down (lane/fireboat, 2026-09-19).
const BOOT: float = 0.080

## THE HULL'S SECTIONS, top row first: [depth as a fraction of the draught, half-width as a fraction of the outline's,
## how far the stem has come in, how far the transom has], the last two as fractions of the length. A hard-chine
## planing hull stays WIDE to the bottom -- flat after sections are what lift it -- and fines away sharply forward,
##
## **TWO OF THESE ROWS EXIST ONLY TO MAKE THE WHITE STRIPE APPEAR, and without them it silently does not.**
## `HullLoft` paints a row GAP, and picks its colour by asking `_paint_at` for that gap's MIDPOINT. So a boot-top band
## is drawn only where some gap's midpoint lands inside +/-`BOOT` of the waterline -- and the first set of rows, which
## were perfectly sensible sections, ran from the sheer straight down to -0.52 of the draught and stepped clean over
## it. The stripe was not thin, nor hidden by the sea, nor the wrong colour: **it was never drawn at all**, and
## nothing looking at the hull could have noticed, because the hull was right. The two rows at +/-0.103 straddle the
## waterline symmetrically, so their gap's midpoint is 0 whatever the draught turns out to be, and their neighbours'
## midpoints fall 0.27 above and 0.10 below -- both outside the 0.08 m boot. Move any of the three and the stripe goes.
##
## AND THE STRIPE'S WIDTH IS THE ROW SPACING, NOT `BOOT`. That is the second half of the same trap and it cost a
## second picture: once the gap's midpoint is inside the boot, the band is painted over the WHOLE gap, so widening
## `BOOT` does nothing and narrowing it only risks losing the stripe altogether. The first pair of rows sat at
## +/-0.206 of the draught -- 0.14 m apart -- and painted 0.14 m of white on a boat with 0.50 m of freeboard, which is
## a hull banded like a lifebuoy rather than a boot-top. The pair is 0.07 m apart now.
##
## THE CHINE ROW SITS JUST UNDER THE STRIPE, not half way to the keel. A runabout's hard chine runs at about the
## waterline, and with the chine drawn deep the topside was one unbroken slab from the paint to the deck edge -- which
## is what made the first three pictures read as a launch. The crease has to be where the eye expects it.
## THE KEEL ROW IS NARROW ON PURPOSE AND IT IS NOT THE BOTTOM'S WIDTH. `HullLoft` lays each row at ONE height right
## across the boat, so it cannot draw deadrise -- a vee bottom -- at all. Drawn honestly at a planing hull's real
## bottom width (0.72 of the beam) she came out as a flat-bottomed slab with a chamfer, and the first bow picture read
## as a barge. Pulling the keel row in to 0.50 puts the crease where a chine is and lets the panel below it fall away
## to a narrow keel, which is what a shallow vee looks like from outside. It is a DRAWING of deadrise and not deadrise,
## and it is written down here so nobody later "corrects" it back to the true bottom width.
const ROWS: Array = [
	[0.00, 1.000, 0.006, 0.002],
	[0.103, 0.997, 0.028, 0.004],
	[-0.103, 0.992, 0.058, 0.007],
	[-0.500, 0.940, 0.098, 0.016],
	[-1.00, 0.480, 0.152, 0.030],
]

## Stations along one hull part, and along the whole deck. DO NOT SUBDIVIDE -- see the doc block.
const HULL_STATIONS: int = 20
const DECK_STATIONS: int = 14
## How many plan points a side the hull's outline is sampled at.
const PLAN_POINTS: int = 20

## THE DECK'S ACROSS-SHIP LAYOUT, in metres. `COVER` is the covering board at the sheer and `KING` the half-width of
## the king plank on the centreline, both stained walnut [S]; `SEAM_WIDE` is the caulked seam between planks and
## `PLANKS` how many planks lie each side between the two.
const COVER: float = 0.100
const KING: float = 0.085
const SEAM_WIDE: float = 0.012
const PLANKS: int = 7
## How much the deck crowns at the centreline over its edge. ESTIMATE: a flat deck reads as a lid and sheds no water.
const CROWN: float = 0.028

## THE CHROME RUB RAIL AT THE SHEER, and it is drawn INSIDE the hull's outline with its outer face ON the sheer --
## not proud of it. A PUBLISHED BEAM IS MEASURED OVER THE RAIL, not over the planking, so a rail hung outboard of the
## sheer makes the boat wider than the figure it was built from: 0.022 m a side put the drawn beam at 2.228 m against
## a published 2.184, which is 2.0 per cent and failed her own size check. This is `Launch`'s tube lesson again --
## "the collided hull is that 2.4 m, so a tube's outer face is the hull's edge" -- met a second time, on a different
## fitting, for the same reason.
## THE TOPSIDE PLANK SEAMS: how far under the sheer each one runs, and how deep it is drawn. Three of them, because a
## real topside carries a dozen and three is what reads at a distance without turning her side into corduroy.
const SEAM_DROPS: Array = [0.15, 0.27, 0.39]
const TOPSIDE_SEAM_WIDE: float = 0.008
## THE BANJO WHEEL [S]: an eight-sided ring, faceted rather than round, as every circle in this workshop is.
const WHEEL_SIDES: int = 8
const WHEEL_ACROSS: float = 0.175
const WHEEL_RIM: float = 0.035
const WHEEL_RAKE: float = 0.07

const RAIL_DEEP: float = 0.032
const RAIL_WIDE: float = 0.030


## THE NEAR MODEL: `{"mesh", "panels", "fittings"}`, in the shape `ShipHull.models` hands on.
static func build(geometry: Dictionary, _helm: String = "open") -> Dictionary:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = geometry.get("parts", []) as Array
	var panels: Array[AABB] = []
	var fittings: Array[AABB] = []
	var bow: float = INF
	var stern: float = -INF
	for part in parts:
		if String(part["part"]) != "hull":
			continue
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		bow = minf(bow, r.position.y)
		stern = maxf(stern, r.end.y)
	# THE SKIN, LOFTED AS ONE PIECE AND NOT AS THE THREE PARTS THE SIMULATION COLLIDES WITH. Lofting each part
	# separately drew a closing section across BOTH ends of every one of them, so the two internal joins had a pair of
	# coincident faces buried in the hull -- and on a boat 8 m long they z-fought into two black lines straight down
	# her topsides, which the first side elevation showed plainly. A hull is one surface; the parts are a collision
	# shape. The plan outline is sampled from `RunaboutDraft.half_beam_at`, which is the same authority the deck, the
	# coamings, the rub rail and the fittings all ask, so there is no second copy of the boat's plan anywhere.
	var top: float = -INF
	var bottom: float = INF
	for part in parts:
		if String(part["part"]) != "hull":
			continue
		top = maxf(top, float(part["top"]))
		bottom = minf(bottom, float(part["bottom"]))
	HullLoft.build(tool, _plan_outline(bow, stern), _rows_for(top, bottom, true, true), 0.0,
		[MAHOGANY, STRIPE, ANTIFOUL], HULL_STATIONS,
		Vector2(RunaboutDraft.sheer_rise_at(bow), RunaboutDraft.sheer_rise_at(stern)),
		Color(0.0, 0.0, 0.0, 0.0), BOOT)
	var wells: Array = _wells(parts)
	_planked_deck(tool, bow, stern, wells)
	for well in wells:
		panels.append_array(_cockpit(tool, well, fittings))
	_engine_hatch(tool, fittings)
	_rub_rail(tool, bow, stern)
	_cutwater(tool, bow, fittings)
	_transom(tool, stern, fittings)
	_windscreen(tool, wells, panels, fittings)
	_deck_fittings(tool, bow, stern, fittings)
	_topside_seams(tool, bow, stern)
	_helm(tool, wells)
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings}


## THE SECTIONS OF ONE HULL PART IN METRES, `ROWS` turned against this part's own top, bottom and the boat's length --
## the one place that conversion happens.
static func _rows_for(top: float, bottom: float, fines_at_bow: bool, fines_at_stern: bool) -> Array:
	var out: Array = [[top, 1.0, 0.0, 0.0]]
	for row in ROWS:
		if is_zero_approx(float(row[0])):
			continue
		out.append([-float(row[0]) * bottom, float(row[1]),
			float(row[2]) * RunaboutDraft.LENGTH if fines_at_bow else 0.0,
			float(row[3]) * RunaboutDraft.LENGTH if fines_at_stern else 0.0])
	return out


## THE WHOLE BOAT'S PLAN OUTLINE, starboard side from the stem aft and port side back, sampled off the one authority
## rather than written down a second time. `PLAN_POINTS` a side is ample for a hull this size and keeps the faceting
## where the eye reads it -- along the sheer -- rather than in the sections.
static func _plan_outline(bow: float, stern: float) -> PackedVector2Array:
	var starboard: Array[Vector2] = []
	for i in range(PLAN_POINTS + 1):
		var z: float = lerpf(bow, stern, float(i) / float(PLAN_POINTS))
		starboard.append(Vector2(RunaboutDraft.half_beam_at(z), z))
	var ring := PackedVector2Array()
	for p in starboard:
		ring.append(p)
	for i in range(starboard.size() - 1, -1, -1):
		ring.append(Vector2(-starboard[i].x, starboard[i].y))
	return ring


## THE THREE COCKPIT WELLS out of the parts, each with the name the shape gave it, forward first.
static func _wells(parts: Array) -> Array:
	var wells: Array = []
	for part in parts:
		if part.has("cockpit"):
			wells.append(part)
	wells.sort_custom(_forward_of)
	return wells


## WHICH OF TWO WELLS IS THE FURTHER FORWARD, for the sort. A named function rather than a lambda, because a lambda
## body cannot be wrapped onto a second line and one of these does not fit on the first.
static func _forward_of(a: Dictionary, b: Dictionary) -> bool:
	return Wheelhouse.outline_rect(a["outline"]).position.y < Wheelhouse.outline_rect(b["outline"]).position.y


## THE DECK, PLANKED. Fore-and-aft planks between a walnut covering board at the sheer and a walnut king plank on the
## centreline, with a white caulked seam between every pair, laid on the sheer line the hull was lofted to and crowned
## to the middle. The three cockpit openings are CUT OUT OF IT by clipping each plank against the well it crosses,
## rather than by drawing the deck round them -- so an opening can be moved without redrawing anything.
##
## THE PLANKS ARE PARAMETERISED BY A FRACTION OF THE HALF-WIDTH, so they taper into the covering board as the boat
## narrows, which is what a laid deck does and what makes the foredeck read as wood rather than as a painted shape.
static func _planked_deck(tool: SurfaceTool, bow: float, stern: float, wells: Array) -> void:
	for s in range(DECK_STATIONS):
		var z0: float = lerpf(bow, stern, float(s) / float(DECK_STATIONS))
		var z1: float = lerpf(bow, stern, float(s + 1) / float(DECK_STATIONS))
		var open: float = _opening_half(wells, z0, z1)
		var at0: Array = _across_at(z0)
		var at1: Array = _across_at(z1)
		for i in range(mini(at0.size(), at1.size()) - 1):
			var tint: Color = _cell_tint(i)
			# THE KING PLANK STRADDLES THE CENTRELINE and is drawn once; every other cell is drawn twice, a side each.
			if i == 0:
				if open > 0.0:
					continue
				_deck_quad(tool, z0, z1, -float(at0[1]), float(at0[1]), -float(at1[1]), float(at1[1]), tint)
				continue
			var a0: float = float(at0[i])
			var b0: float = float(at0[i + 1])
			var a1: float = float(at1[i])
			var b1: float = float(at1[i + 1])
			if maxf(b0, b1) <= open:
				continue
			for side in [1.0, -1.0]:
				_deck_quad(tool, z0, z1, maxf(a0, open) * side, b0 * side, maxf(a1, open) * side, b1 * side, tint)


## ONE PLANK'S QUAD between two stations. The two ends carry their OWN across-ship positions, so a plank tapers with
## the boat instead of stepping: taking both ends at the narrower station -- which the first draft did, to keep every
## cell inside the sheer -- made each station's cells jump sideways from the last, and eighteen stations of that read
## as a dotted red-and-white chequer rather than as laid planking.
static func _deck_quad(tool: SurfaceTool, z0: float, z1: float, a0: float, b0: float, a1: float, b1: float,
		tint: Color) -> void:
	var p0: Vector3 = _deck_point(a0, z0)
	var p1: Vector3 = _deck_point(b0, z0)
	var p2: Vector3 = _deck_point(b1, z1)
	var p3: Vector3 = _deck_point(a1, z1)
	_facet_up(tool, p0, p1, p2, tint)
	_facet_up(tool, p0, p2, p3, tint)


## ONE TRIANGLE, WOUND AND NORMALLED TO FACE UP, and it exists because `Plating.facing` cannot be used on a WARPED
## quad. A crowned, sheered deck puts its four corners on four different heights, so a deck cell is not planar --
## and `Plating.quad` takes ONE normal off corners 0, 1 and 2 and gives it to both triangles, while the second
## triangle is corners 0, 2, 3 and on a warped quad can genuinely wind the other way. That is not a colour or a size
## and no picture shows it: it read as 14 faces of 1,388 wound against their normal, and only `_wound_outwards`
## could ever have said so. Each triangle gets its OWN normal here, which is also the faceted look the house asks for.
static func _facet_up(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-12:
		return
	if normal.y < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	normal = normal.normalized()
	tool.set_color(tint)
	for corner in [a, b, c]:
		tool.set_normal(normal)
		tool.add_vertex(corner)


## A POINT ON THE DECK: the sheer at that station, plus the crown, which falls to nothing at the deck edge.
static func _deck_point(x: float, z: float) -> Vector3:
	var half: float = maxf(RunaboutDraft.half_beam_at(z), 0.001)
	var across: float = clampf(absf(x) / half, 0.0, 1.0)
	return Vector3(x, RunaboutDraft.FREEBOARD + RunaboutDraft.sheer_rise_at(z)
		+ CROWN * (1.0 - across * across), z)


## THE DECK'S ACROSS-SHIP BOUNDARIES at one station, in metres from the centreline: the king plank's edge first, then
## alternating seam and plank out to the covering board, then the sheer. `_cell_tint` says what the cell between two
## of them is; the two lists are indexed the same way at every station, which is what lets a plank be one strip.
##
## THE COVERING BOARD KEEPS ITS WIDTH and the planks take up the slack, which is how a deck is really laid: a
## covering board is a plank of its own following the sheer, and the boards inboard of it are tapered to fit.
static func _across_at(z: float) -> Array:
	# THE DECK ENDS WHERE THE HULL DOES, at every station including the stem. The first version floored the
	# half-width at `KING + 0.02` so the king plank always had room -- which drew a covering board 0.105 m out on a
	# boat 0.048 m wide at her forward band, six centimetres of planking hanging over the side of the stem. It is
	# invisible in every picture, because six centimetres at the sharp end of a boat looks like a boat. Where she is
	# too narrow for a king plank she gets a proportional one, and where she is too narrow for anything at all every
	# cell comes out zero-width and is skipped.
	var half: float = maxf(RunaboutDraft.half_beam_at(z), 0.001)
	var king: float = minf(KING, half * 0.5)
	var cover: float = minf(COVER, half - king)
	var bounds: Array = [0.0, king]
	var field_out: float = maxf(half - cover, king)
	var plank: float = maxf((field_out - king - SEAM_WIDE * float(PLANKS + 1)) / float(PLANKS), 0.0)
	var at: float = king
	for i in range(PLANKS):
		# EVERY BOUNDARY IS CLAMPED TO THE COVERING BOARD, and without it the deck turns inside out at the stem. Where
		# the boat is 0.03 m across there is no room for seven planks and eight seams: `plank` clamps to its 3 mm floor,
		# the boundaries walk out to 0.19 m on a deck whose field ends at 0.095, and the last cells are drawn BACKWARDS
		# -- which showed up as two faces of 1,416 wound against their normal and as nothing at all in any picture.
		# Clamped, those cells come out zero-width and `Plating.facing` skips them.
		at = minf(at + SEAM_WIDE, field_out)
		bounds.append(at)
		at = minf(at + plank, field_out)
		bounds.append(at)
	bounds.append(field_out)
	bounds.append(half)
	return bounds


## WHAT THE CELL BETWEEN BOUNDARY `i` AND `i + 1` IS PAINTED. Index 0 is the king plank, the last is the covering
## board, and the field alternates seam, plank, seam, plank starting with a seam.
static func _cell_tint(i: int) -> Color:
	if i == 0:
		return WALNUT
	if i >= PLANKS * 2 + 2:
		return WALNUT
	return SEAM if i % 2 == 1 else MAHOGANY


## HOW FAR OUT THE DECK IS OPEN between two stations: the half-width of whichever cockpit well covers them, or 0 for a
## span of closed deck. A well counts if it covers ANY of the span, so a plank that only clips the corner of an
## opening is cut rather than left hanging over it.
static func _opening_half(wells: Array, z0: float, z1: float) -> float:
	var widest: float = 0.0
	for well in wells:
		var r: Rect2 = Wheelhouse.outline_rect(well["outline"])
		if z1 > r.position.y and z0 < r.end.y:
			widest = maxf(widest, r.size.x * 0.5)
	return widest


## ONE COCKPIT: the coaming standing round the opening, the well's mahogany lining down to the sole, a black rubber
## mat on the sole [S] and a tan vinyl bench across its after end [S]. Returns the panels the helm's view is judged
## against.
static func _cockpit(tool: SurfaceTool, well: Dictionary, fittings: Array[AABB]) -> Array[AABB]:
	var r: Rect2 = Wheelhouse.outline_rect(well["outline"])
	var sole: float = float(well["bottom"])
	var lip: float = float(well["top"])
	var panels: Array[AABB] = []
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var deck_a: float = _deck_point(a.x, a.y).y
		var deck_b: float = _deck_point(b.x, b.y).y
		var into: Vector3 = _inward(a, b, r)
		# THE LINING, from the sole up to the deck, facing INTO the well -- which is the opposite way round from every
		# other wall in this file, because a cockpit is a hole and its walls are seen from inside.
		Plating.facing(tool, [Vector3(a.x, sole, a.y), Vector3(b.x, sole, b.y), Vector3(b.x, deck_b, b.y),
			Vector3(a.x, deck_a, a.y)], into, MAHOGANY)
		# THE COAMING, a walnut lip standing proud of the deck all round, SEEN FROM BOTH SIDES: it is a lip and not a
		# wall, so a viewer outside the boat sees its outer face and the crew see its inner one.
		var proud: float = lip - RunaboutDraft.FREEBOARD
		for out in [into, -into]:
			Plating.facing(tool, [Vector3(a.x, deck_a, a.y), Vector3(b.x, deck_b, b.y),
				Vector3(b.x, deck_b + proud, b.y), Vector3(a.x, deck_a + proud, a.y)], out, WALNUT)
	Plating.paint(tool, well["outline"], sole, MAT)
	# THE BENCH across the after end, its cushion a hand's breadth below the deck so a head sits above the coaming.
	var bench_z: float = r.end.y - 0.30
	var bench := AABB(Vector3(r.position.x, sole, bench_z - 0.24), Vector3(r.size.x, 0.42, 0.48))
	Plating.box(tool, bench.get_center(), bench.size, VINYL)
	fittings.append(bench)
	panels.append(AABB(Vector3(r.position.x, sole, r.position.y), Vector3(r.size.x, lip - sole, r.size.y)))
	return panels


## THE ENGINE HATCH, flush in the deck between the middle and the aft cockpits [SO]: two caulked seams across the deck
## where its edges are, and a chrome vent each side, which is what [S] lists among the polished hardware.
static func _engine_hatch(tool: SurfaceTool, fittings: Array[AABB]) -> void:
	var bow: float = -RunaboutDraft.LENGTH * 0.5
	var from: float = bow + RunaboutDraft.LENGTH * 0.600
	var to: float = bow + RunaboutDraft.LENGTH * 0.795
	for z in [from, to]:
		var half: float = RunaboutDraft.half_beam_at(z) - COVER
		var y: float = _deck_point(0.0, z).y + 0.004
		Plating.line(tool, Vector2(-half, z), Vector2(half, z), 0.014, y, SEAM)
	var middle: float = (from + to) * 0.5
	for side in [1.0, -1.0]:
		var x: float = (RunaboutDraft.half_beam_at(middle) - COVER) * 0.72 * side
		var vent := AABB(Vector3(x - 0.055, _deck_point(x, middle).y, middle - 0.11),
			Vector3(0.11, 0.075, 0.22))
		Plating.box(tool, vent.get_center(), vent.size, CHROME)
		fittings.append(vent)


## THE CHROME RUB RAIL down the sheer, both sides, following the sheer line the deck is laid on. It is the single
## brightest thing on the boat at any distance and it is what draws her line: both reference boats carry one, and on
## the one with no painted stripe it is the only thing at the deck edge at all.
static func _rub_rail(tool: SurfaceTool, bow: float, stern: float) -> void:
	for s in range(DECK_STATIONS):
		var z0: float = lerpf(bow, stern, float(s) / float(DECK_STATIONS))
		var z1: float = lerpf(bow, stern, float(s + 1) / float(DECK_STATIONS))
		for side in [1.0, -1.0]:
			var x0: float = RunaboutDraft.half_beam_at(z0) * side
			var x1: float = RunaboutDraft.half_beam_at(z1) * side
			var top0: float = _deck_point(x0, z0).y
			var top1: float = _deck_point(x1, z1).y
			var out := Vector3(side, 0.0, 0.0)
			var a := Vector3(x0, top0, z0)
			var b := Vector3(x1, top1, z1)
			var in_a := Vector3(x0 - RAIL_WIDE * side, top0, z0)
			var in_b := Vector3(x1 - RAIL_WIDE * side, top1, z1)
			Plating.facing(tool, [a, b, b - Vector3(0.0, RAIL_DEEP, 0.0), a - Vector3(0.0, RAIL_DEEP, 0.0)],
				out, CHROME)
			# WARPED FOR THE SAME REASON AS A DECK CELL -- the sheer lifts its two forward corners -- so it goes
			# through `_facet_up` rather than `Plating.facing`.
			_facet_up(tool, in_a, in_b, b, CHROME)
			_facet_up(tool, in_a, b, a, CHROME)


## THE CUTWATER: a chrome strip down the stem, from the sheer to the waterline. It is on [S]'s list of polished
## hardware by name and it is the first thing that catches the light on a boat coming at you.
static func _cutwater(tool: SurfaceTool, bow: float, _fittings: Array[AABB]) -> void:
	var top: float = _deck_point(0.0, bow).y
	var steps: int = 4
	for i in range(steps):
		var y0: float = lerpf(top, 0.0, float(i) / float(steps))
		var y1: float = lerpf(top, 0.0, float(i + 1) / float(steps))
		# The stem rakes aft as it goes down, by the same tuck the forward sections are lofted with.
		var z0: float = bow + RunaboutDraft.LENGTH * 0.088 * (1.0 - y0 / maxf(top, 0.001)) * 0.55
		var z1: float = bow + RunaboutDraft.LENGTH * 0.088 * (1.0 - y1 / maxf(top, 0.001)) * 0.55
		for side in [1.0, -1.0]:
			Plating.facing(tool, [Vector3(0.0, y0, z0 - 0.012), Vector3(0.048 * side, y0, z0 + 0.010),
				Vector3(0.048 * side, y1, z1 + 0.010), Vector3(0.0, y1, z1 - 0.012)],
				Vector3(side, 0.0, -1.0).normalized(), CHROME)
	# NOT REPORTED AS A FITTING. `fittings` is the list of things a check holds to a surface they stand ON, and a
	# cutwater is a strip screwed down the STEM -- it stands on nothing, by construction, and reporting it would make
	# the check that finds a floating part go red over a part that is doing its job.


## THE TRANSOM: a chrome band round its top edge, which is what the reference photographs show and what stops the
## after end reading as a cut-off box.
static func _transom(tool: SurfaceTool, stern: float, _fittings: Array[AABB]) -> void:
	var half: float = RunaboutDraft.half_beam_at(stern)
	var top: float = _deck_point(half, stern).y
	var band := AABB(Vector3(-half, top - 0.05, stern - 0.03), Vector3(half * 2.0, 0.05, 0.06))
	Plating.box(tool, band.get_center(), band.size, CHROME)
	# NOT A FITTING either, and for the cutwater's reason: it is let into the transom's top edge, not stood on a deck.


## THE WINDSCREEN, standing on the forward coaming of the helm cockpit: a chrome frame and a single raked pane each
## side of a centre post, which is what a Custom 309 carries [S]. Two flat panes and not a curve -- the house look is
## faceted, and a runabout's screen really is two flat lights in a vee.
static func _windscreen(tool: SurfaceTool, wells: Array, panels: Array[AABB], fittings: Array[AABB]) -> void:
	if wells.is_empty():
		return
	var r: Rect2 = Wheelhouse.outline_rect(wells[0]["outline"])
	var at: float = r.position.y - 0.03
	var half: float = r.size.x * 0.5
	# THE SCREEN STANDS ON THE DECK AT EVERY POINT ALONG ITS FOOT, not on the deck's height at the centreline. The
	# deck is CROWNED, so a foot taken once on the middle and drawn level left the outboard ends hanging in the air
	# over a deck that had fallen away under them -- a gap 28 mm at the ends and visible in the first bow picture. The
	# TOP edge is level, because a real screen's frame is; only the foot follows the camber.
	var high: float = _deck_point(0.0, at).y + 0.055 + 0.30
	var rake: float = 0.14
	var mid := Vector3(0.0, high, at - rake * 0.4)
	for side in [1.0, -1.0]:
		var outboard := Vector3(half * side, high, at - rake)
		var corners: Array = [Vector3(0.0, _deck_point(0.0, at).y, at),
			Vector3(half * side, _deck_point(half * side, at).y, at), outboard, mid]
		Plating.facing(tool, corners, Vector3(0.0, 0.0, -1.0), GLASS)
		Plating.facing(tool, corners, Vector3(0.0, 0.0, 1.0), GLASS)
		# THE FRAME along the top edge and up the outboard post, in chrome.
		Plating.facing(tool, [mid, outboard, outboard + Vector3(0.0, 0.028, 0.0), mid + Vector3(0.0, 0.028, 0.0)],
			Vector3(0.0, 0.0, -1.0), CHROME)
		Plating.facing(tool, [mid, outboard, outboard + Vector3(0.0, 0.028, 0.0), mid + Vector3(0.0, 0.028, 0.0)],
			Vector3(0.0, 0.0, 1.0), CHROME)
	var foot: float = _deck_point(half, at).y
	var box := AABB(Vector3(-half, foot, at - rake), Vector3(half * 2.0, high - foot + 0.03, rake + 0.03))
	panels.append(box)
	fittings.append(box)


## WHAT ELSE IS SCREWED TO THE DECK: chocks and cleats forward and aft, and a flagstaff at the transom. All of them
## are on [S]'s list of polished hardware; all of them are boxes, because the look is faceted.
static func _deck_fittings(tool: SurfaceTool, bow: float, stern: float, fittings: Array[AABB]) -> void:
	var places: Array = [bow + 0.55, bow + 1.25, stern - 0.42]
	for z in places:
		for side in [1.0, -1.0]:
			var x: float = (RunaboutDraft.half_beam_at(z) - COVER * 1.4) * side
			if absf(x) < 0.12:
				continue
			var cleat := AABB(Vector3(x - 0.045, _deck_point(x, z).y, z - 0.075), Vector3(0.09, 0.055, 0.15))
			Plating.box(tool, cleat.get_center(), cleat.size, CHROME)
			fittings.append(cleat)
	var staff_at: float = stern - 0.16
	var staff := AABB(Vector3(-0.016, _deck_point(0.0, staff_at).y, staff_at - 0.016), Vector3(0.032, 0.62, 0.032))
	Plating.box(tool, staff.get_center(), staff.size, CHROME)
	fittings.append(staff)


## THE TOPSIDE PLANK SEAMS, as fine DARK lines parallel to the sheer. She is seam-and-batten planked and her topside
## seams read dark in both sharp reference frames -- which is the opposite of the deck's, where the compound is pale,
## and drawing them pale would be the deck's detail on the wrong surface.
##
## THEY CANNOT COME OUT OF `HullLoft`, which carries three colours and paints per row gap, so they are laid ON the
## skin: at a fixed drop under the sheer, so they follow it, and 6 mm proud so they are not in a z-fight with it.
##
## AND THEY STOP 1.4 m ABAFT THE STEM. Below the sheer the hull tucks AFT as well as in -- 0.23 m of it by the second
## row -- so a line drawn on the plan outline near the stem is drawn where the hull no longer is, and it would hang
## in the air off the bow. Past 1.4 m the plan is straight enough that the error is under a millimetre in x.
##
## AND 3 mm PROUD, NOT 6. A seam is a decal on the skin and the skin's width is a PUBLISHED figure: at 6 mm a side the
## drawn beam went from 2.184 m to 2.194, eating a fifth of the 2 per cent the size check allows on a number a source
## actually prints. 3 mm is still clear of the z-fight and costs 0.3 per cent instead of 0.5. A decoration may not
## spend a measurement's tolerance.
static func _topside_seams(tool: SurfaceTool, bow: float, stern: float) -> void:
	var from: float = bow + 1.40
	var to: float = stern - 0.18
	for drop in SEAM_DROPS:
		for s in range(DECK_STATIONS):
			var z0: float = lerpf(from, to, float(s) / float(DECK_STATIONS))
			var z1: float = lerpf(from, to, float(s + 1) / float(DECK_STATIONS))
			var y0: float = RunaboutDraft.FREEBOARD + RunaboutDraft.sheer_rise_at(z0) - drop
			var y1: float = RunaboutDraft.FREEBOARD + RunaboutDraft.sheer_rise_at(z1) - drop
			if y0 < TOPSIDE_SEAM_WIDE or y1 < TOPSIDE_SEAM_WIDE:
				continue
			for side in [1.0, -1.0]:
				var x0: float = (RunaboutDraft.half_beam_at(z0) * 0.999 + 0.003) * side
				var x1: float = (RunaboutDraft.half_beam_at(z1) * 0.999 + 0.003) * side
				Plating.facing(tool, [Vector3(x0, y0, z0), Vector3(x1, y1, z1),
					Vector3(x1, y1 - TOPSIDE_SEAM_WIDE, z1), Vector3(x0, y0 - TOPSIDE_SEAM_WIDE, z0)],
					Vector3(side, 0.0, 0.0), TOPSIDE_SEAM)


## THE HELM, in the forward cockpit: a walnut dashboard across its forward end and a banjo wheel on a raked column in
## front of the starboard seat. [S] names both -- "an automobile-style steering wheel, throttle controls, a dashboard
## with gauges and a floor-mounted gearshift" -- and they are the only things a viewer can see inside the boat that
## say she is driven rather than rowed.
##
## THE WHEEL IS AN EIGHT-SIDED RING and not a circle. The house look is faceted and the Hawkeye's rotodome is the
## reference: a turning ring "shows only in its facets".
##
## NEITHER IS REPORTED AS A FITTING. The dash hangs off the forward coaming and the wheel stands on its column, so
## neither stands on a drawn surface, and reporting them would turn the check that finds a floating part red over
## two parts doing their job -- the cutwater's and the transom band's case exactly.
static func _helm(tool: SurfaceTool, wells: Array) -> void:
	if wells.is_empty():
		return
	var r: Rect2 = Wheelhouse.outline_rect(wells[0]["outline"])
	var sole: float = float(wells[0]["bottom"])
	var deck: float = _deck_point(0.0, r.position.y).y
	# THE DASH, across the forward end of the well and standing on nothing: it is a bulkhead panel.
	var dash_top: float = deck - 0.06
	var dash_low: float = maxf(sole + 0.26, dash_top - 0.26)
	Plating.box(tool, Vector3(0.0, (dash_low + dash_top) * 0.5, r.position.y + 0.06),
		Vector3(r.size.x, dash_top - dash_low, 0.08), WALNUT)
	# THE WHEEL, in front of the starboard seat, raked back as a car's is.
	var at := Vector3(0.38, dash_low + 0.30, r.position.y + 0.30)
	Plating.box(tool, Vector3(at.x, (dash_low + at.y) * 0.5, at.z - 0.06),
		Vector3(0.035, at.y - dash_low, 0.035), CHROME)
	var sides: int = WHEEL_SIDES
	for i in range(sides):
		var a: float = TAU * float(i) / float(sides)
		var b: float = TAU * float(i + 1) / float(sides)
		var p0 := at + Vector3(cos(a) * WHEEL_ACROSS, sin(a) * WHEEL_ACROSS, sin(a) * WHEEL_RAKE)
		var p1 := at + Vector3(cos(b) * WHEEL_ACROSS, sin(b) * WHEEL_ACROSS, sin(b) * WHEEL_RAKE)
		var i0 := at + Vector3(cos(a) * (WHEEL_ACROSS - WHEEL_RIM), sin(a) * (WHEEL_ACROSS - WHEEL_RIM),
			sin(a) * WHEEL_RAKE)
		var i1 := at + Vector3(cos(b) * (WHEEL_ACROSS - WHEEL_RIM), sin(b) * (WHEEL_ACROSS - WHEEL_RIM),
			sin(b) * WHEEL_RAKE)
		for out in [Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0)]:
			Plating.facing(tool, [i0, p0, p1, i1], out, WHEEL)


## WHICH WAY IS INTO THE WELL, for the edge from `a` to `b` of the rectangle `r`.
static func _inward(a: Vector2, b: Vector2, r: Rect2) -> Vector3:
	var middle: Vector2 = (a + b) * 0.5
	var centre: Vector2 = r.get_center()
	if absf(middle.x - centre.x) > absf(middle.y - centre.y):
		return Vector3(signf(centre.x - middle.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(centre.y - middle.y))
