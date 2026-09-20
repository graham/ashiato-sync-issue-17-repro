extends RefCounted
class_name RockTuning
## EVERY NUMBER THE MOUNTAINS ARE SHADED BY, IN ONE PLACE: how much a step is lit as the slope it is part of, how
## dark an inner corner is, where the scree, the scrub and the snow lie, and how the walls are stained.
##
## THE DECISION (lead, 2026-09-13): SHADING, NOT GEOMETRY. Every mountain is boxes, and every box is also collision;
## a smooth surface drawn over them would sit 18 to 38 m clear of the rock you hit on the ring (the envelope's
## largest gap, tread x riser / hypot), so a shell's burst would land inside visible rock and be hidden by it.
## So the picture is the boxes, lit as the slope they make: `Terrain._peak` hands each box its peak (centre,
## crown, summit), and both rock shaders read it from the MultiMesh's custom data, written once at build.
##
## WHAT WENT WRONG BEFORE (2026-09-13 day screenshots): each box lit on its own, eight flat faces and a knife edge,
## the same grey from foot to summit -- stepped grey pyramids. FINE's bevels rolled the light at an edge but kept
## every tread as bright as the one above it.
##
## A file, not a slider, as `DaylightTuning` and `CloudTuning`. Both finishes read these; FINE only adds to them.

## HOW MUCH A FACE IS LIT AS THE SLOPE rather than as itself: a little near, where the steps are the shape you are
## flying past, and most of it far, where the steps are a few pixels and the mountainside is what reads.
const SLOPE_NEAR: float = 0.30
const SLOPE_FAR: float = 0.80
const SLOPE_FROM: float = 300.0
const SLOPE_TO: float = 3000.0
## The sharpness of a peak's plan: 2 is a round cone, higher is squarer. The layers are rectangles, so a square-ish
## plan puts each flank's light on the flank.
const PLAN_POWER: float = 4.0

## THE INNER CORNER: rock this far under the slope, in risers, is this much darker. The corner a tread makes with
## the wall above it gets little sky, and it is what turns a stack of boxes into ledges.
const CORNER_FROM: float = 0.25
const CORNER_TO: float = 1.0
const CORNER_DARK: float = 0.55

## SCREE: broken rock fallen off the wall above, lying on the inner part of a tread. Paler and warmer than the rock.
const SCREE_COLOUR := Color(0.47, 0.44, 0.39)
const SCREE_FROM: float = 0.45
const SCREE_AMOUNT: float = 0.65

## SCRUB on the low treads' open lips, fading out with height.
const SCRUB_COLOUR := Color(0.24, 0.28, 0.17)
const SCRUB_UNDER: float = 160.0
const SCRUB_GONE: float = 320.0

## SNOW on treads above the line, deepest in the sheltered inner corner and thinnest on an exposed lip. Lower than
## FINE's old 470 m, where only the tallest few of thirty ring peaks (260 to 560 m) carried any.
const SNOW_LINE: float = 400.0
const SNOW_BLEND: float = 40.0

## STAINS down a wall from the ledge above, FINE only: how dark, and how narrow against how long.
const STREAK_DARK: float = 0.22
const STREAK_ACROSS: float = 0.09
const STREAK_DOWN: float = 0.006


## ---- THE MOUNTAINS (cockpit-mountains, 2026-09-18) ----------------------------------------------------------------
##
## THE MOUNTAINS ARE NO LONGER BOXES: they are faceted ranges whose triangles are also their collision (range_core.hpp),
## drawn by `MountainView` with `shaders/mountain.gdshaderinc`, which reads these. The numbers above now shade only what is
## still a box -- no box carries a peak since, so the stepped-slope light has nothing to light.

## Rock from the foot to the top, the colour of a bed of strata, and the creek at the bottom of a gully.
const MOUNTAIN_LOW := Color(0.30, 0.28, 0.26)
const MOUNTAIN_HIGH := Color(0.55, 0.53, 0.50)
const BAND_COLOUR := Color(0.40, 0.36, 0.32)
const CREEK_COLOUR := Color(0.10, 0.12, 0.14)
const SNOW_COLOUR := Color(0.90, 0.92, 0.95)
## Metres a top-to-bottom shade runs over, and the broad noise's say in it.
const SHADE := Vector2(620.0, 0.35)
## STRATA: metres between beds, how strong, how far a bed wanders.
const STRATA := Vector3(26.0, 0.30, 30.0)
## SCRUB's facet: the flattest it grows on (normal y).
const SCRUB_FACET: float = 0.80
## SCREE: how far down the flank it starts (0 at the crest, 1 at the foot) and the facet it needs.
const SCREE_DOWN := Vector2(0.72, 0.55)
## THE GULLY RIMS -- the valley edges: where across a gully the line lies, how wide, how dark.
const RIM := Vector3(0.45, 0.10, 0.25)
## THE CREEK: how deep in a gully it runs, how far down the flank a gully must be to carry one, and how dark.
const CREEK := Vector3(0.86, 0.22, 0.65)
## SNOW: the flattest facet it lies on (normal y), and how much lower it lies in a gully's shade, metres.
const SNOW_FACET: float = 0.62
const SNOW_IN_A_GULLY: float = 90.0
## Metres over which a facet's flat light blends to the smooth normal, and the fine grain fades.
const SMOOTH_FROM := Vector2(2500.0, 7000.0)
const GRAIN_FADE := Vector2(300.0, 2000.0)
## ONE TONE A FACET, how far each facet's colour wanders from its neighbour's -- the low-poly look -- and how much darker
## the bottom of a gully is than the spur beside it, which is what shows the spurs and gullies from kilometres off.
const FACET_TONE: float = 0.07
const GULLY_SHADE: float = 0.28
## THE FOOT: the heights over which a facet turns from rock to the island's grass.
const FOOT_BLEND := Vector2(2.0, 30.0)
## THE HAZE, thinner with height: by this many metres up, the world's fog density is thinned to this share of itself.
## 0.12 by 300 m: from 18 km out most of the rock a pilot sees is lower flank, 100 to 300 m up, and thinning that began
## there left 0.3 of the world's density by 700 m showing the crests alone -- the ranges "barely there" (team-lead,
## 2026-09-18: "the crests should cut the skyline"). A test paint of pure red showed through at about a tenth then, and
## as a solid silhouette with these numbers; the foot is still thinned by nothing, so it fades as the grass does.
const HAZE_THIN := Vector2(300.0, 0.12)
## THE FAR BLUE: past FAR_BLUE.x metres the rock turns toward FAR_COLOUR, by FAR_SHARE at FAR_BLUE.y -- the blue-grey of a
## distant range, darker than the sky over it, so what the thinner haze shows is a silhouette and not pale snow on pale sky.
const FAR_COLOUR := Color(0.30, 0.36, 0.46)
const FAR_BLUE := Vector2(6000.0, 16000.0)
const FAR_SHARE: float = 0.7


## THE MOUNTAINS' NUMBERS, by the name of the uniform `mountain.gdshaderinc` reads each as -- set on each material once,
## at build, by `MountainView`.
static func mountain_numbers() -> Dictionary:
	return {
		"low_colour": MOUNTAIN_LOW,
		"high_colour": MOUNTAIN_HIGH,
		"band_colour": BAND_COLOUR,
		"scree_colour": SCREE_COLOUR,
		"scrub_colour": SCRUB_COLOUR,
		"creek_colour": CREEK_COLOUR,
		"snow_colour": SNOW_COLOUR,
		"shade": SHADE,
		"strata": STRATA,
		"scrub": Vector3(SCRUB_UNDER, SCRUB_GONE, SCRUB_FACET),
		"scree": SCREE_DOWN,
		"rim": RIM,
		"creek": CREEK,
		"snow": Vector4(SNOW_LINE, SNOW_BLEND, SNOW_FACET, SNOW_IN_A_GULLY),
		"smooth_from": SMOOTH_FROM,
		"grain_fade": GRAIN_FADE,
		"foot_blend": FOOT_BLEND,
		"facet_tone": FACET_TONE,
		"gully_shade": GULLY_SHADE,
		"haze_thin": HAZE_THIN,
		"far_colour": FAR_COLOUR,
		"far_blue": FAR_BLUE,
		"far_share": FAR_SHARE,
	}


## EVERY NUMBER ABOVE, by the name of the uniform both rock shaders read it as -- set on each material once, at
## build, by `SceneryYard.draw_boxes`. The slope itself is `Terrain`'s, because the generator makes it.
static func shader_numbers() -> Dictionary:
	return {
		# THE STEPPED SLOPE, which nothing carries any more: the rock shaders light a box by its peak only when it has one.
		"envelope_slope": 1.0,
		"plan_power": PLAN_POWER,
		"slope_share": Vector4(SLOPE_NEAR, SLOPE_FAR, SLOPE_FROM, SLOPE_TO),
		"corner": Vector3(CORNER_FROM, CORNER_TO, CORNER_DARK),
		"scree_colour": SCREE_COLOUR,
		"scree": Vector2(SCREE_FROM, SCREE_AMOUNT),
		"scrub_colour": SCRUB_COLOUR,
		"scrub_height": Vector2(SCRUB_UNDER, SCRUB_GONE),
		"snow_height": Vector2(SNOW_LINE, SNOW_BLEND),
		"streak": Vector3(STREAK_DARK, STREAK_ACROSS, STREAK_DOWN),
	}
