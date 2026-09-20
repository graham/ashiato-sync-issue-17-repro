extends RefCounted
class_name OilPlatform
## A FIXED STEEL-JACKET PRODUCTION PLATFORM, the North Sea kind: a four-by-two lattice jacket piled to the seabed, three
## decks of process modules on it, a drilling derrick, two pedestal cranes, a flare boom leaning out over the sea, the
## living quarters at the far end with the helideck on their roof, and lifeboats on davits under it.
##
## WHY THIS TYPE AND NOT ANOTHER (lane/oilrig, 2026-09-18). The user asked for "an oil platform ... that can sit in the
## water". Of the types the Wikipedia article lists, the fixed jacket is the one a person pictures, and it sits in the water
## by construction: it stands on the sea floor and rises through the surface, so nothing about it needs a buoyancy model
## to look right. A semi-submersible floats, moors and heaves, and drawn standing still it would be a fixed platform
## pretending. Both worlds' open sea is about 150 m deep (`Seabed.depth`), which is inside the fixed jacket's range --
## Thistle Alpha stands in 162 m -- so the one builder serves both, handed the depth it stands in.
##
## THE REFERENCES, and what each gave. Photographs are for study, never incorporated; the table with licences is
## `cockpit/research/oil_platform.md`. Tags as `modelling_here.md` section 3: [W] PUBLISHED on Wikipedia, [M] MEASURED
## off the Montrose Alpha broadside (CC0), [E] ESTIMATE, with what it was reasoned from.
## - [W] Thistle Alpha: "a conventional steel tower structure approximately 183 meters tall with a base measuring 85 meters
##   by 82 meters", four main legs, "36 modules arranged on 3 deck levels", living quarters "and the helideck" at one end.
## - [W] Montrose oil field: a "horizontal 455 feet (139 m) long flare bridge" from the platform to the flare. It is the
##   only length in the Montrose picture, and it gives about 6.9 px a metre -- but it is a bridge that runs AWAY from the
##   camera (its tripod stands 1.19 times nearer than the platform, by the rows the two meet the sea at below the horizon),
##   so the scale at the platform's own station is uncertain by about that much. It is cross-checked below.
## - [M] off the Montrose broadside, at the platform's own station, as ratios to its cellar deck's underside (152 px over
##   the water): jacket top frame 0.44 of it, jacket top across its outer legs 2.45, module roofs 2.3, helideck 2.8,
##   derrick crown 3.6. `research/oil_platform.md` has every pick. THE ABSOLUTE SCALE IS [E]: a cellar deck 22 m over the
##   sea, the North Sea's usual air gap, which the bridge's scale gives within 1 m -- two readings that never saw each other.
##
## THE DATUM. The origin is ON THE SEA'S SURFACE at the middle of the jacket's top frame: +y up, +x along the platform's
## length towards the quarters and the helideck, the derrick and the flare boom towards -x. Everything above the water is
## typed from that datum; everything below it is derived from the depth the platform is handed, so the same builder stands
## in 70 m (Ula, Valhall) or 162 m (Thistle) and its jacket spreads with its batter as a real one does.
##
## THE LOOK, AND ITS SEGMENT COUNTS, so nobody subdivides it (`modelling_here.md` section 4): legs are 8-sided, braces,
## conductors and risers 6, pipes and lattice lacing 4; decks, modules and the quarters are flat-faced boxes; every face
## carries its own normal, so every edge stays hard. The Hawkeye's nacelle is 20 sides and its rotodome lens 32: nothing
## here is rounder than a third of that, because a platform is read at two kilometres as a silhouette of struts.
##
## ONE MESH, TWO SURFACES. Surface 0 is all the painted steel with its colour in its vertices; surface 1 is the quarters'
## windows, alone so the time of day can light them. Every part is built into its own tool and appended in order, and
## `build` returns where each part's vertices are in surface 0, so a suite can ask "where is the helideck" of the drawn
## triangles rather than of a constant, and a part that comes adrift can be named.

## ---- the jacket ---------------------------------------------------------------------------------------------------

## THE JACKET'S TOP FRAME above the sea, metres. [M] 0.44 of the cellar deck's height on the Montrose broadside = 9.7 m.
const JACKET_TOP: float = 10.0
## THE LEGS' PLAN AT THE TOP FRAME: four along the length, two across. [M] 54 m across the outer legs broadside
## (373 px at 6.9 px a metre); the spacing across is [E], set so the base at Thistle's depth comes out at Thistle's
## nearly square 85 x 82 m -- a jacket much narrower than it is long does not stand in 160 m of water.
const LEG_X: Array[float] = [-27.0, -9.0, 9.0, 27.0]
const LEG_Z: Array[float] = [-18.0, 18.0]
## THE BATTER: how far a leg leans out for every metre it goes down. [E] 1 in 10 along the length and 1 in 7.5 across,
## inside the 1:7 to 1:12 usual for a four-legged North Sea jacket, and chosen to meet Thistle's base (see the check):
## at 162 m of water the base is 54 + 2 x 17.2 = 88 m long and 36 + 2 x 22.9 = 82 m across. The inner legs lean
## across only, as the inner frames of a real jacket do.
const BATTER_ALONG: float = 10.0
const BATTER_ACROSS: float = 7.5
## Diameters, metres. [M] a Montrose leg reads 15 px, 2.2 m; braces about half of that. [E] beyond.
const LEG_DIAMETER: float = 2.4
const BRACE_DIAMETER: float = 1.1
const CONDUCTOR_DIAMETER: float = 0.76
## THE FIRST BAY UNDER THE TOP FRAME, metres, and how much taller each bay below is than the one above: a jacket's bays
## grow with depth because the wave load falls off with it. [E] from the Eko 2-4R and Chiwan jackets out of the water, which
## both show four or five bays with the deepest roughly twice the shallowest.
const FIRST_BAY: float = 22.0
const BAY_GROWTH: float = 1.35
## THE SPLASH ZONE, metres either side of the still water: where a jacket is wetted by every wave, painted dark and
## rusting, the band every photograph of a platform shows at the water. Below it, what grows on steel in the sea.
const SPLASH: float = 3.0
## Sides round a member. See the doc block.
const LEG_SIDES: int = 8
const BRACE_SIDES: int = 6
const THIN_SIDES: int = 4

## ---- the topsides -------------------------------------------------------------------------------------------------

## THE DECKS, as the tops of their plates above the sea. [M] the cellar deck's underside is 152 px over the water at
## Montrose, which the doc block's scale makes 22 m; the module roofs 2.3 of that, the weather deck under them.
## Deck girders are GIRDER deep under each plate.
const CELLAR_DECK: float = 22.0
const PRODUCTION_DECK: float = 31.0
const WEATHER_DECK: float = 40.0
const GIRDER: float = 1.6
## Each deck's plan, x from/to and half-width across. [M] 84 m overall broadside at the cellar deck's cantilevers; the
## decks above step in, as they do at Montrose, Ula and Valhall.
const CELLAR_PLAN := Rect2(-34.0, -23.0, 68.0, 46.0)
const PRODUCTION_PLAN := Rect2(-33.0, -21.0, 66.0, 42.0)
const WEATHER_PLAN := Rect2(-33.0, -21.0, 51.0, 42.0)
## THE LIVING QUARTERS: a block at the +x end from the production deck up, the helideck on its roof. [W] Thistle's
## "living quarters (LQ) ... and the helideck" are at one end; Valhall's accommodation is a white block of window rows.
const QUARTERS := Rect2(18.0, -16.0, 15.0, 32.0)
const QUARTERS_ROOF: float = 57.0
const STOREY: float = 3.25
## THE HELIDECK. [M] 2.8 cellar decks at Montrose is 61.6 m. Its size is the D-value of the largest helicopter it takes;
## [E] 24 m across the flats of an octagon, a deck for a machine the size of an S-92 or a UH-60 (19.8 m overall).
const HELIDECK_TOP: float = 61.0
const HELIDECK_ACROSS: float = 24.0
const HELIDECK_THICK: float = 0.8
## Where its middle stands in plan: out over the quarters' end, so most of it overhangs the sea.
const HELIDECK_AT := Vector2(38.0, 0.0)
## THE OBSTACLE-FREE SECTOR, degrees either side of its bisector, which points +x: 210 degrees in all, the offshore
## helideck's clear approach. Nothing the platform draws may stand above the deck inside it.
const CLEAR_SECTOR_HALF: float = 105.0
## THE SAFETY NET round the deck's edge: how far out, and how far it falls over that.
const NET_OUT: float = 1.5
const NET_FALL: float = 0.25

## ---- the drilling ---------------------------------------------------------------------------------------------------

## THE DRILL FLOOR, a clad substructure on the weather deck over the conductors. [E] the Montrose derrick stands on a
## drill floor about 9 m over its module roofs.
const DRILL_FLOOR := Rect2(-22.0, -8.0, 16.0, 16.0)
const DRILL_FLOOR_TOP: float = 49.0
## THE DERRICK: a tapering lattice tower on the drill floor. [E] 40 m, base 10 m square, 3 m at the crown -- the brief's
## 40-60 m and the Montrose derrick's crown at 3.6 cellar decks (79 m) both put it here.
const DERRICK_HEIGHT: float = 40.0
const DERRICK_BASE: float = 10.0
const DERRICK_TOP: float = 3.0
## THE CONDUCTORS: the well casings, a grid of pipes from the seabed up through the jacket into the cellar deck under the
## drill floor, held by guide frames at every level of the jacket.
const CONDUCTOR_X: Array[float] = [-20.0, -17.0, -14.0, -11.0, -8.0]
const CONDUCTOR_Z: Array[float] = [-3.0, 3.0]

## ---- the cranes and the flare --------------------------------------------------------------------------------------

## THE TWO PEDESTAL CRANES, one each side: where the pedestal stands, how it is slewed (degrees from +x, towards +z), the
## boom's length and its elevation. [E] the Deepsea and Ula cranes' booms are about as long as the deck is wide.
const CRANES: Array[Dictionary] = [
	{"name": "North", "at": Vector2(4.0, -18.5), "slew": -120.0, "boom": 40.0, "rise": 42.0},
	{"name": "South", "at": Vector2(-26.0, 18.5), "slew": 150.0, "boom": 40.0, "rise": 36.0},
]
const PEDESTAL_TOP: float = 48.0
const PEDESTAL_DIAMETER: float = 3.6
## THE FLARE BOOM, from the -x end of the weather deck out over the sea. [E] 60 m at 30 degrees; the Montrose flare stands
## 139 m off on its own bridge, an inclined boom is what the brief asked for and what Brent-era platforms carry.
const FLARE_ROOT := Vector3(-33.0, WEATHER_DECK, -8.0)
const FLARE_LENGTH: float = 60.0
const FLARE_RISE: float = 30.0
## The flare boom's heading, degrees from -x towards -z: out and a little aside, clear of the derrick's crown.
const FLARE_AWAY: float = 15.0
const FLARE_STACK: float = 4.0

## ---- the colours, as painted: vertex colours read as sRGB ------------------------------------------------------------

const JACKET_PAINT := Color(0.58, 0.33, 0.20)
const SPLASH_RUST := Color(0.22, 0.15, 0.11)
const SEA_GROWTH := Color(0.19, 0.23, 0.17)
const DECK_STEEL := Color(0.66, 0.34, 0.19)
const DECK_PLATE := Color(0.44, 0.44, 0.42)
const GRATING := Color(0.36, 0.37, 0.36)
const HANDRAIL := Color(0.90, 0.72, 0.12)
const MODULE_YELLOW := Color(0.86, 0.67, 0.16)
const MODULE_GREY := Color(0.70, 0.71, 0.69)
const MODULE_WHITE := Color(0.87, 0.87, 0.84)
const MODULE_BLUE := Color(0.34, 0.42, 0.52)
const MODULE_ORANGE := Color(0.86, 0.42, 0.13)
const QUARTERS_WHITE := Color(0.90, 0.90, 0.87)
const QUARTERS_TRIM := Color(0.80, 0.28, 0.14)
const WINDOW := Color(0.13, 0.16, 0.21)
const HELIDECK_GREEN := Color(0.22, 0.28, 0.24)
const MARK_WHITE := Color(0.93, 0.93, 0.90)
const MARK_YELLOW := Color(0.96, 0.80, 0.12)
const NET := Color(0.16, 0.17, 0.16)
const DERRICK_GREY := Color(0.76, 0.76, 0.73)
const DERRICK_RED := Color(0.72, 0.16, 0.12)
const CRANE_YELLOW := Color(0.92, 0.70, 0.10)
const LIFEBOAT := Color(1.0, 0.45, 0.05)
const PIPE_GREY := Color(0.55, 0.56, 0.55)


## ---- the answers the rest of the game asks --------------------------------------------------------------------------

## THE JACKET'S FRAME LEVELS, top down, ending at the seabed: y of each horizontal frame. `depth` is positive metres of
## water. The bays grow by BAY_GROWTH; a last bay that would be less than 0.6 of the one above is folded into it, so the
## deepest bay is never a sliver.
static func frame_levels(depth: float) -> PackedFloat64Array:
	var out := PackedFloat64Array([JACKET_TOP])
	var bay: float = FIRST_BAY
	var y: float = JACKET_TOP
	while true:
		var next: float = y - bay
		if next - (-depth) < bay * BAY_GROWTH * 0.6:
			out.append(-depth)
			break
		out.append(next)
		y = next
		bay *= BAY_GROWTH
	return out


## WHERE LEG (i along, j across) IS at height `y`, in plan: its top-frame place, leaned out by the batter below the top.
static func leg_at(i: int, j: int, y: float) -> Vector3:
	var down: float = maxf(JACKET_TOP - y, 0.0)
	var x: float = LEG_X[i]
	if i == 0 or i == LEG_X.size() - 1:
		x += signf(x) * down / BATTER_ALONG
	var z: float = LEG_Z[j] + signf(LEG_Z[j]) * down / BATTER_ACROSS
	return Vector3(x, y, z)


## THE HELIDECK'S MIDDLE, on its surface.
static func helideck_centre() -> Vector3:
	return Vector3(HELIDECK_AT.x, HELIDECK_TOP, HELIDECK_AT.y)


## The octagon's corners in plan, flats facing the four axes.
static func helideck_outline(grow: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r: float = (HELIDECK_ACROSS * 0.5 + grow) / cos(PI / 8.0)
	for k in range(8):
		var a: float = PI / 8.0 + TAU * float(k) / 8.0
		out.append(HELIDECK_AT + Vector2(cos(a), sin(a)) * r)
	return out


## HOW FAR THE HELIDECK'S EDGE REACHES along x at `z` across, on the side `sign` (+1 east, -1 west): the octagon's
## flat, or its corner flat once `z` is past the flat's half-length. West is returned negated, as a distance from +x 0.
static func helideck_reach(z: float, sign: float) -> float:
	var a: float = HELIDECK_ACROSS * 0.5
	var edge: float = a - maxf(0.0, absf(z - HELIDECK_AT.y) - a * tan(PI / 8.0))
	return HELIDECK_AT.x + edge if sign > 0.0 else -(HELIDECK_AT.x - edge)


## THE FLARE TIP, where the flame stands: the top of the stack at the boom's end.
static func flare_tip() -> Vector3:
	return _flare_end() + Vector3.UP * FLARE_STACK


static func _flare_end() -> Vector3:
	var away: float = deg_to_rad(FLARE_AWAY)
	var rise: float = deg_to_rad(FLARE_RISE)
	var flat := Vector3(-cos(away), 0.0, -sin(away))
	return FLARE_ROOT + flat * FLARE_LENGTH * cos(rise) + Vector3.UP * FLARE_LENGTH * sin(rise)


## THE DERRICK'S CROWN: the middle of its top.
static func derrick_crown() -> Vector3:
	var middle: Vector2 = DRILL_FLOOR.get_center()
	return Vector3(middle.x, DRILL_FLOOR_TOP + DERRICK_HEIGHT, middle.y)


## A CRANE'S BOOM FOOT AND TIP, from its row in CRANES.
static func boom_of(crane: Dictionary) -> Array[Vector3]:
	var at: Vector2 = crane["at"]
	var slew: float = deg_to_rad(float(crane["slew"]))
	var rise: float = deg_to_rad(float(crane["rise"]))
	var foot := Vector3(at.x, PEDESTAL_TOP + 2.0, at.y) + Vector3(cos(slew), 0.0, sin(slew)) * 1.4
	var tip: Vector3 = foot + Vector3(cos(slew) * cos(rise), sin(rise), sin(slew) * cos(rise)) * float(crane["boom"])
	return [foot, tip]


## ---- the solid ------------------------------------------------------------------------------------------------------

## THE PLATFORM'S SOLID, for `Terrain.boxes()`: axis-aligned boxes standing on `at` (the jacket's middle on the sea's
## surface), `depth` metres of water under it.
##
## WHICH WAY THE APPROXIMATION MAY BE WRONG (the cooling tower's rule, `CoolingTower.SOLID_BANDS`). A box proud of what is
## drawn is an invisible wall in open air; a box inside it lets a body clip the steel before it is stopped. So every box
## here is INSIDE what the platform draws: a jacket bay's box is the leg-centre envelope at the bay's TOP, where the
## battered legs are closest; the decks' box is inside the smallest of the three plates; the helideck is the octagon's
## inscribed square and two inscribed bars, as the tower's solid is its inscribed cross. The top of the helideck's boxes
## IS the drawn deck's top, to the millimetre, so a helicopter set down on it rests on what the player sees.
##
## WHAT IS NOT SOLID, said so nobody finds it by flying into it: the crane booms, the flare boom and the derrick's lattice
## above its lower half are thin trusses a box would either miss or overfill, and the lifeboats hang outboard. A pilot can
## fly through a boom. Through the jacket's bracing, which fills its faces, a pilot cannot.
static func collision_boxes(at: Vector3, depth: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var levels: PackedFloat64Array = frame_levels(depth)
	for b in range(levels.size() - 1):
		var top: float = float(levels[b])
		var bottom: float = float(levels[b + 1])
		var corner: Vector3 = leg_at(LEG_X.size() - 1, 1, top)
		out.append(_solid(at, Vector3(0.0, (top + bottom) * 0.5, 0.0), Vector3(corner.x, (top - bottom) * 0.5, corner.z)))
	# The deck legs, from the top frame to the cellar deck's girders.
	var legs_top: float = CELLAR_DECK - GIRDER
	out.append(_solid(at, Vector3(0.0, (JACKET_TOP + legs_top) * 0.5, 0.0),
		Vector3(LEG_X[LEG_X.size() - 1], (legs_top - JACKET_TOP) * 0.5, LEG_Z[1])))
	# The decks, from the cellar deck's girders to the weather deck's plate, inside the smallest plate.
	var smallest: Rect2 = CELLAR_PLAN.intersection(PRODUCTION_PLAN).intersection(
		Rect2(WEATHER_PLAN.position, Vector2(QUARTERS.end.x - WEATHER_PLAN.position.x, WEATHER_PLAN.size.y)))
	out.append(_solid_rect(at, smallest, legs_top, WEATHER_DECK))
	# The quarters, and the frame the helideck stands on.
	out.append(_solid_rect(at, QUARTERS, WEATHER_DECK, HELIDECK_TOP - HELIDECK_THICK))
	# The helideck: its inscribed square and two bars, each a flat slab whose top is the deck's.
	var a: float = HELIDECK_ACROSS * 0.5
	for half in [Vector2(a, a * (sqrt(2.0) - 1.0)), Vector2(a * (sqrt(2.0) - 1.0), a), Vector2(a, a) / sqrt(2.0)]:
		out.append(_solid(at, Vector3(HELIDECK_AT.x, HELIDECK_TOP - HELIDECK_THICK * 0.5, HELIDECK_AT.y),
			Vector3(half.x, HELIDECK_THICK * 0.5, half.y)))
	# The drill floor, and the derrick's lower half inside its legs at mid-height.
	out.append(_solid_rect(at, DRILL_FLOOR, WEATHER_DECK, DRILL_FLOOR_TOP))
	var mid_half: float = lerpf(DERRICK_BASE, DERRICK_TOP, 0.5) * 0.5
	var crown: Vector3 = derrick_crown()
	out.append(_solid(at, Vector3(crown.x, DRILL_FLOOR_TOP + DERRICK_HEIGHT * 0.25, crown.z),
		Vector3(mid_half, DERRICK_HEIGHT * 0.25, mid_half)))
	# The crane pedestals, inside their eight flats.
	for crane in CRANES:
		var p: Vector2 = crane["at"]
		var r: float = PEDESTAL_DIAMETER * 0.5 * cos(PI / 8.0) / sqrt(2.0)
		out.append(_solid(at, Vector3(p.x, (WEATHER_DECK + PEDESTAL_TOP) * 0.5, p.y),
			Vector3(r, (PEDESTAL_TOP - WEATHER_DECK) * 0.5, r)))
	return out


static func _solid(at: Vector3, middle: Vector3, half: Vector3) -> Dictionary:
	return {"position": at + middle, "half_extents": half}


static func _solid_rect(at: Vector3, plan: Rect2, bottom: float, top: float) -> Dictionary:
	var middle: Vector2 = plan.get_center()
	return _solid(at, Vector3(middle.x, (bottom + top) * 0.5, middle.y),
		Vector3(plan.size.x * 0.5, (top - bottom) * 0.5, plan.size.y * 0.5))


## ---- the lights -----------------------------------------------------------------------------------------------------

## THE PLATFORM'S LIGHTS, in its own frame, in `VehicleLights.build`'s shape: red obstruction beacons on the derrick's
## crown, both crane tips, the flare boom's end and the quarters' roof corners, and the helideck's green perimeter and
## yellow touchdown circle. Lit day and night. The deck floods are `floods()`, because they are not.
static func lights() -> Array[Dictionary]:
	var red := VehicleLights.RED
	var out: Array[Dictionary] = []
	var crown: Vector3 = derrick_crown()
	for side in [-1.0, 1.0]:
		out.append(_lamp(crown + Vector3(side * DERRICK_TOP * 0.5, 1.2, 0.0), red, VehicleLights.Pattern.BEACON, 0.8, 0.0))
	for crane in CRANES:
		out.append(_lamp(boom_of(crane)[1] + Vector3.UP * 0.6, red, VehicleLights.Pattern.BEACON, 0.7, 0.3))
	out.append(_lamp(_flare_end() + Vector3(0.0, 1.0, 1.4), red, VehicleLights.Pattern.BEACON, 0.7, 0.6))
	for x in [QUARTERS.position.x, QUARTERS.end.x]:
		for z in [QUARTERS.position.y, QUARTERS.end.y]:
			out.append(_lamp(Vector3(x, QUARTERS_ROOF + 0.5, z), red, VehicleLights.Pattern.STEADY, 0.5, 0.0))
	# THE HELIDECK: green round its edge, yellow round its touchdown circle, as offshore decks are lit.
	var edge: PackedVector2Array = helideck_outline(0.2)
	for k in range(edge.size()):
		for share in [0.0, 0.5]:
			var p: Vector2 = edge[k].lerp(edge[(k + 1) % edge.size()], share)
			out.append(_lamp(Vector3(p.x, HELIDECK_TOP + 0.25, p.y), VehicleLights.GREEN, VehicleLights.Pattern.STEADY,
				0.35, 0.0))
	var circle: float = HELIDECK_ACROSS * 0.25 + 0.5
	for k in range(12):
		var a: float = TAU * float(k) / 12.0
		out.append(_lamp(helideck_centre() + Vector3(cos(a) * circle, 0.12, sin(a) * circle),
			Color(1.0, 0.82, 0.2), VehicleLights.Pattern.STEADY, 0.25, 0.0))
	return out


## THE DECK FLOODS: warm white every 8 m along the edge of each deck, a little under the deck above, which are what makes
## a platform at night a lit-up block on a black sea. OFF BY DAY, as they are: drawn on the runway's material they read
## as a rash of white dots over a daylit platform (cockpit-oilrig-01, 2026-09-18), so `OilField` shows them only after
## dark.
static func floods() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# THE FLARE AS A LAMP: a large orange point in the flame, on the runway's material, which holds a least angle, so the
	# flare is still a bright dot from kilometres off, where its flame is a few pixels.
	# ITS COLOUR IS THE FLAME'S WHITE-HOT CORE, not its orange: an orange lamp read as a DARK disc inside the flame close up,
	# where the flame's own colour is past white (cockpit-oilrig-08, 2026-09-18).
	out.append(_lamp(flare_tip() + Vector3.UP * 5.0, Color(1.0, 0.9, 0.62), VehicleLights.Pattern.STEADY, 2.5, 0.0))
	var warm := Color(1.0, 0.86, 0.62)
	for deck in [[CELLAR_PLAN, PRODUCTION_DECK - GIRDER - 0.6], [PRODUCTION_PLAN, WEATHER_DECK - GIRDER - 0.6],
			[WEATHER_PLAN, WEATHER_DECK + 6.0]]:
		var plan: Rect2 = deck[0]
		var y: float = deck[1]
		var corners: Array[Vector2] = [plan.position, Vector2(plan.end.x, plan.position.y), plan.end,
			Vector2(plan.position.x, plan.end.y)]
		for k in range(4):
			var a2: Vector2 = corners[k]
			var b2: Vector2 = corners[(k + 1) % 4]
			var n: int = maxi(1, int(a2.distance_to(b2) / 8.0))
			for s in range(n):
				var p2: Vector2 = a2.lerp(b2, (float(s) + 0.5) / float(n))
				out.append(_lamp(Vector3(p2.x, y, p2.y), warm, VehicleLights.Pattern.STEADY, 0.45, 0.0))
	return out


static func _lamp(at: Vector3, colour: Color, pattern: int, radius: float, phase: float) -> Dictionary:
	return {"position": at, "colour": colour, "pattern": pattern, "radius": radius, "floor": 1.0, "phase": phase}


## ---- the mesh -------------------------------------------------------------------------------------------------------

## THE PARTS, in the order they are drawn: a name and the function that builds it. A part's vertices are contiguous in
## surface 0 and `build` says where, so a check can hold ONE part to the drawn triangles.
const PARTS: Array[String] = [
	"Jacket", "Conductors", "Risers", "BoatLanding", "DeckLegs", "CellarDeck", "ProductionDeck", "WeatherDeck",
	"Modules", "Handrails", "Stairs", "Quarters", "Helideck", "HelideckNet", "DrillFloor", "Derrick",
	"CraneNorth", "CraneSouth", "FlareBoom", "Lifeboats",
]


## THE WHOLE PLATFORM FOR `depth` METRES OF WATER: `{"mesh": ArrayMesh, "parts": {name: Vector2i(first, count)}}`, where
## `first` and `count` are vertex indices in surface 0. Surface 1 is the windows.
static func build(depth: float) -> Dictionary:
	var whole := SurfaceTool.new()
	whole.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Dictionary = {}
	var first: int = 0
	for name in PARTS:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var built: bool = _build_part(name, tool, depth)
		var piece: ArrayMesh = tool.commit() if built else null
		if piece == null or piece.get_surface_count() == 0:
			push_warning("OilPlatform: part '%s' drew nothing." % name)
			parts[name] = Vector2i(first, 0)
			continue
		var count: int = (piece.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		whole.append_from(piece, 0, Transform3D.IDENTITY)
		parts[name] = Vector2i(first, count)
		first += count
	var mesh: ArrayMesh = whole.commit()
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_windows(glass)
	glass.commit(mesh)
	return {"mesh": mesh, "parts": parts}


static func _build_part(name: String, tool: SurfaceTool, depth: float) -> bool:
	match name:
		"Jacket": _jacket(tool, depth)
		"Conductors": _conductors(tool, depth)
		"Risers": _risers(tool, depth)
		"BoatLanding": _boat_landing(tool)
		"DeckLegs": _deck_legs(tool)
		"CellarDeck": _deck(tool, CELLAR_PLAN, CELLAR_DECK)
		"ProductionDeck": _deck(tool, PRODUCTION_PLAN, PRODUCTION_DECK)
		"WeatherDeck": _deck(tool, WEATHER_PLAN, WEATHER_DECK)
		"Modules": _modules(tool)
		"Handrails": _handrails(tool)
		"Stairs": _stairs(tool)
		"Quarters": _quarters(tool)
		"Helideck": _helideck(tool)
		"HelideckNet": _helideck_net(tool)
		"DrillFloor": _drill_floor(tool)
		"Derrick": _derrick(tool)
		"CraneNorth": _crane(tool, CRANES[0])
		"CraneSouth": _crane(tool, CRANES[1])
		"FlareBoom": _flare_boom(tool)
		"Lifeboats": _lifeboats(tool)
		_: return false
	return true


## The steel's material: vertex colour read as sRGB (`modelling_here.md` section 4), one-sided, unshiny.
static func steel_material() -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = 0.85
	paint.metallic = 0.0
	return paint


## THE WINDOWS' MATERIAL, lit by `glow` 0..: dark glass by day, warm lit rooms at night.
static func window_material(glow: float) -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = WINDOW
	glass.roughness = 0.2
	glass.emission_enabled = glow > 0.0
	glass.emission = Color(1.0, 0.80, 0.52)
	glass.emission_energy_multiplier = glow
	return glass


## ---- the jacket -----------------------------------------------------------------------------------------------------

static func _jacket(tool: SurfaceTool, depth: float) -> void:
	var levels: PackedFloat64Array = frame_levels(depth)
	var nx: int = LEG_X.size()
	# THE LEGS, a length a bay so each bay's piece is a straight tube between two frames.
	for i in range(nx):
		for j in range(LEG_Z.size()):
			for b in range(levels.size() - 1):
				_member(tool, leg_at(i, j, float(levels[b])), leg_at(i, j, float(levels[b + 1])),
					LEG_DIAMETER * 0.5, LEG_SIDES)
			# A PILE SLEEVE CLUSTER at each corner leg's foot, where the piles go down into the seabed.
			if i == 0 or i == nx - 1:
				var foot: Vector3 = leg_at(i, j, -depth)
				for k in range(3):
					var a: float = TAU * float(k) / 3.0
					var off := Vector3(cos(a) * 2.6, 0.0, sin(a) * 2.6)
					_member(tool, foot + off, foot + off + Vector3.UP * 9.0, 0.9, BRACE_SIDES)
					_member(tool, foot + off * 0.3 + Vector3.UP * 6.0, foot + off + Vector3.UP * 6.0, 0.35, THIN_SIDES)
	for level in levels:
		var y: float = float(level)
		# THE FRAME: round the outside, across at every leg line, and the conductor guides.
		for j in range(LEG_Z.size()):
			for i in range(nx - 1):
				_member(tool, leg_at(i, j, y), leg_at(i + 1, j, y), BRACE_DIAMETER * 0.5, BRACE_SIDES)
		for i in range(nx):
			_member(tool, leg_at(i, 0, y), leg_at(i, 1, y), BRACE_DIAMETER * 0.5, BRACE_SIDES)
		# Plan diagonals in the two end bays, which is what keeps a jacket square.
		_member(tool, leg_at(0, 0, y), leg_at(1, 1, y), BRACE_DIAMETER * 0.4, BRACE_SIDES)
		_member(tool, leg_at(nx - 1, 0, y), leg_at(nx - 2, 1, y), BRACE_DIAMETER * 0.4, BRACE_SIDES)
		# The conductor guides, the length of the jacket so they meet every transverse frame.
		for z in CONDUCTOR_Z:
			_member(tool, Vector3(leg_at(0, 0, y).x, y, z), Vector3(leg_at(nx - 1, 0, y).x, y, z),
				BRACE_DIAMETER * 0.35, BRACE_SIDES)
	# THE X-BRACING in every face and inner frame, each bay.
	for b in range(levels.size() - 1):
		var hi: float = float(levels[b])
		var lo: float = float(levels[b + 1])
		for j in range(LEG_Z.size()):
			for i in range(nx - 1):
				_member(tool, leg_at(i, j, hi), leg_at(i + 1, j, lo), BRACE_DIAMETER * 0.5, BRACE_SIDES)
				_member(tool, leg_at(i + 1, j, hi), leg_at(i, j, lo), BRACE_DIAMETER * 0.5, BRACE_SIDES)
		for i in range(nx):
			_member(tool, leg_at(i, 0, hi), leg_at(i, 1, lo), BRACE_DIAMETER * 0.5, BRACE_SIDES)
			_member(tool, leg_at(i, 1, hi), leg_at(i, 0, lo), BRACE_DIAMETER * 0.5, BRACE_SIDES)


## THE CONDUCTORS: the wells, from the seabed up through every guide frame to the cellar deck under the drill floor.
static func _conductors(tool: SurfaceTool, depth: float) -> void:
	for x in CONDUCTOR_X:
		for z in CONDUCTOR_Z:
			_member(tool, Vector3(x, -depth, z), Vector3(x, CELLAR_DECK, z), CONDUCTOR_DIAMETER * 0.5, BRACE_SIDES)


## THE RISERS: two export pipes clamped down the outside of a leg, from the cellar deck to the seabed, and bent out at
## the foot along the sea floor as a pipeline leaves a platform.
static func _risers(tool: SurfaceTool, depth: float) -> void:
	var levels: PackedFloat64Array = frame_levels(depth)
	for k in range(2):
		var path: Array[Vector3] = [Vector3(LEG_X[1], CELLAR_DECK, LEG_Z[0] - 1.6 - float(k) * 1.1)]
		for level in levels:
			var leg: Vector3 = leg_at(1, 0, float(level))
			path.append(Vector3(leg.x, float(level), leg.z - 1.6 - float(k) * 1.1))
		var foot: Vector3 = path[path.size() - 1]
		path.append(foot + Vector3(0.0, 0.0, -30.0))
		for p in range(path.size() - 1):
			_member(tool, path[p], path[p + 1], 0.45, BRACE_SIDES)
		# Clamps at each frame, from the riser to the leg.
		for level in levels:
			var leg: Vector3 = leg_at(1, 0, float(level))
			_member(tool, leg + Vector3(0.0, 1.0, 0.0), Vector3(leg.x, float(level) + 1.0, leg.z - 1.6 - float(k) * 1.1),
				0.2, THIN_SIDES)


## THE BOAT LANDING: a steel cage with a grating platform and bumpers on the south-east corner leg, at the water, where a
## supply boat's crew would step off. A splash-zone detail every close photograph of a jacket shows.
static func _boat_landing(tool: SurfaceTool) -> void:
	var leg: Vector3 = leg_at(LEG_X.size() - 1, 1, 0.0)
	var out: float = 3.2
	var z0: float = leg.z
	var z1: float = leg.z + out
	var x0: float = leg.x - 9.0
	var x1: float = leg.x
	for x in [x0, (x0 + x1) * 0.5, x1]:
		_member(tool, Vector3(x, -6.0, z0), Vector3(x, -6.0, z1), 0.25, THIN_SIDES)
		_member(tool, Vector3(x, -6.0, z1), Vector3(x, 5.0, z1), 0.3, BRACE_SIDES)
		_member(tool, Vector3(x, 5.0, z0), Vector3(x, 5.0, z1), 0.25, THIN_SIDES)
		_member(tool, Vector3(x, 2.0, z0), Vector3(x, 2.0, z1), 0.25, THIN_SIDES)
	for y in [-6.0, 2.0, 5.0]:
		_member(tool, Vector3(x0, y, z1), Vector3(x1, y, z1), 0.25, THIN_SIDES)
		_member(tool, Vector3(x0, y, z0), Vector3(x1, y, z0), 0.25, THIN_SIDES)
	Plating.box(tool, Vector3((x0 + x1) * 0.5, 5.2, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.2, out), GRATING)
	# The ladder up the leg to the cellar deck, and the bumpers on the outside.
	_member(tool, Vector3(x1 - 2.0, 5.2, z0 + 0.2), Vector3(x1 - 2.0, CELLAR_DECK - GIRDER, z0 + 0.2), 0.12, THIN_SIDES)
	_member(tool, Vector3(x1 - 2.6, 5.2, z0 + 0.2), Vector3(x1 - 2.6, CELLAR_DECK - GIRDER, z0 + 0.2), 0.12, THIN_SIDES)
	for x in [x0 + 1.0, x1 - 1.0]:
		Plating.box(tool, Vector3(x, -1.0, z1 + 0.35), Vector3(0.7, 7.0, 0.7), Color(0.12, 0.12, 0.12))


## THE DECK LEGS: the jacket's legs carried on up from the top frame to the cellar deck's girders, with knee braces.
static func _deck_legs(tool: SurfaceTool) -> void:
	var top: float = CELLAR_DECK - GIRDER
	for i in range(LEG_X.size()):
		for j in range(LEG_Z.size()):
			var foot: Vector3 = leg_at(i, j, JACKET_TOP)
			_member(tool, foot, Vector3(foot.x, top, foot.z), LEG_DIAMETER * 0.45, LEG_SIDES)
			var inward: float = -signf(foot.z) * 5.0
			_member(tool, foot + Vector3.UP * 3.0, Vector3(foot.x, top, foot.z + inward), BRACE_DIAMETER * 0.35,
				BRACE_SIDES)
	# A frame between the legs' heads, under the cellar deck's girders.
	for j in range(LEG_Z.size()):
		_member(tool, Vector3(LEG_X[0], top - 0.8, LEG_Z[j]), Vector3(LEG_X[LEG_X.size() - 1], top - 0.8, LEG_Z[j]),
			BRACE_DIAMETER * 0.4, BRACE_SIDES)


## ---- the decks ------------------------------------------------------------------------------------------------------

## ONE DECK: a plate, the girders under it round its edge and across it, painted edge beams.
static func _deck(tool: SurfaceTool, plan: Rect2, top: float) -> void:
	var middle: Vector2 = plan.get_center()
	Plating.box(tool, Vector3(middle.x, top - 0.15, middle.y), Vector3(plan.size.x, 0.3, plan.size.y), DECK_PLATE)
	var g: float = GIRDER
	var y: float = top - 0.3 - g * 0.5
	for z in [plan.position.y + 0.4, plan.end.y - 0.4]:
		Plating.box(tool, Vector3(middle.x, y, z), Vector3(plan.size.x, g, 0.8), DECK_STEEL)
	for x in [plan.position.x + 0.4, plan.end.x - 0.4]:
		Plating.box(tool, Vector3(x, y, middle.y), Vector3(0.8, g, plan.size.y - 1.6), DECK_STEEL)
	# The girders across, over every leg line, and one along the middle.
	for x in LEG_X:
		if x > plan.position.x and x < plan.end.x:
			Plating.box(tool, Vector3(x, y, middle.y), Vector3(0.7, g, plan.size.y - 1.6), DECK_STEEL.darkened(0.15))
	Plating.box(tool, Vector3(middle.x, y, 0.0), Vector3(plan.size.x - 1.6, g, 0.7), DECK_STEEL.darkened(0.15))


## THE PROCESS MODULES, on the three decks: separators, tanks, compression, a turbine house with its exhausts, pipe
## racks. Placed on the deck plate they stand on and never typed a height (`modelling_here.md` section 5): each module's
## foot is its deck's top.
static func _modules(tool: SurfaceTool) -> void:
	var cellar: float = CELLAR_DECK
	var clear_c: float = PRODUCTION_DECK - GIRDER - 0.3 - CELLAR_DECK - 0.4
	# THE CELLAR DECK: the wellhead area under the drill floor is left open; separators and pumps east of it.
	for k in range(3):
		var z: float = -14.0 + float(k) * 6.5
		_vessel(tool, Vector3(2.0, cellar, z), 14.0, 3.4, MODULE_WHITE)
	_block(tool, Rect2(18.0, -20.0, 12.0, 9.0), cellar, clear_c, MODULE_YELLOW)
	_block(tool, Rect2(18.0, 10.0, 13.0, 10.0), cellar, clear_c * 0.8, MODULE_GREY)
	for k in range(4):
		_tank(tool, Vector3(-28.0 + float(k) * 4.2, cellar, 16.0), 1.6, clear_c - 0.5, MODULE_GREY.darkened(0.1))
	# THE PRODUCTION DECK: compression and a switchgear house, and the pipe rack along the middle.
	var prod: float = PRODUCTION_DECK
	var clear_p: float = WEATHER_DECK - GIRDER - 0.3 - PRODUCTION_DECK - 0.4
	_block(tool, Rect2(-30.0, -19.0, 16.0, 13.0), prod, clear_p, MODULE_YELLOW)
	_block(tool, Rect2(-30.0, 6.0, 14.0, 13.0), prod, clear_p * 0.85, MODULE_BLUE)
	_block(tool, Rect2(-8.0, -19.0, 20.0, 10.0), prod, clear_p, MODULE_GREY)
	_block(tool, Rect2(-8.0, 9.0, 11.0, 10.0), prod, clear_p * 0.7, MODULE_ORANGE)
	for k in range(2):
		_vessel(tool, Vector3(8.0, prod, 8.0 + float(k) * 5.0), 9.0, 2.8, MODULE_WHITE)
	_pipe_rack(tool, Vector2(-32.0, 0.0), Vector2(17.5, 0.0), prod, 4.0)
	# THE WEATHER DECK: the turbine house with its twin exhausts, a vent stack, and a laydown area left clear for the
	# cranes. Its modules' roofs are the Montrose broadside's 2.3 cellar decks.
	var weather: float = WEATHER_DECK
	_block(tool, Rect2(-2.0, -15.0, 14.0, 9.0), weather, 8.5, MODULE_WHITE)
	for x in [2.0, 7.0]:
		_member(tool, Vector3(x, weather + 8.5, -10.5), Vector3(x, weather + 14.5, -10.5), 0.9, LEG_SIDES,
			MODULE_GREY.darkened(0.35))
	_block(tool, Rect2(-2.0, 7.0, 10.0, 12.0), weather, 6.0, MODULE_GREY)
	_block(tool, Rect2(-30.0, -19.0, 7.0, 9.0), weather, 5.0, MODULE_ORANGE)
	_member(tool, Vector3(12.0, weather, 16.0), Vector3(12.0, weather + 22.0, 16.0), 0.45, BRACE_SIDES, PIPE_GREY)


## A MODULE: a flat-faced box with a darker band round its foot and a roof edge, standing on `floor`.
static func _block(tool: SurfaceTool, plan: Rect2, floor: float, tall: float, tint: Color) -> void:
	var middle: Vector2 = plan.get_center()
	Plating.box(tool, Vector3(middle.x, floor + tall * 0.5, middle.y), Vector3(plan.size.x, tall, plan.size.y), tint)
	Plating.band(tool, plan, floor + tall - 0.5, floor + tall, tint.darkened(0.25), 0.0)
	Plating.band(tool, plan, floor, floor + 0.6, tint.darkened(0.4), 0.0)


## A PRESSURE VESSEL lying along x on two saddles: a separator.
static func _vessel(tool: SurfaceTool, foot: Vector3, length: float, across: float, tint: Color) -> void:
	var y: float = foot.y + 0.8 + across * 0.5
	_member(tool, Vector3(foot.x - length * 0.5, y, foot.z), Vector3(foot.x + length * 0.5, y, foot.z), across * 0.5,
		LEG_SIDES, tint, true)
	for s in [-0.3, 0.3]:
		Plating.box(tool, Vector3(foot.x + length * s, foot.y + 0.6, foot.z), Vector3(0.6, 1.2, across * 0.8), DECK_STEEL)


## A STANDING TANK.
static func _tank(tool: SurfaceTool, foot: Vector3, radius: float, tall: float, tint: Color) -> void:
	_member(tool, foot, foot + Vector3.UP * tall, radius, LEG_SIDES, tint, true)


## A PIPE RACK: a row of portal frames with a bundle of pipes along it.
static func _pipe_rack(tool: SurfaceTool, from: Vector2, to: Vector2, floor: float, high: float) -> void:
	var n: int = maxi(2, int(from.distance_to(to) / 7.0))
	for k in range(n + 1):
		var p: Vector2 = from.lerp(to, float(k) / float(n))
		for s in [-1.2, 1.2]:
			Plating.box(tool, Vector3(p.x, floor + high * 0.5, p.y + s), Vector3(0.35, high, 0.35), DECK_STEEL)
		Plating.box(tool, Vector3(p.x, floor + high, p.y), Vector3(0.35, 0.35, 2.8), DECK_STEEL)
	for k in range(4):
		var z: float = -0.9 + float(k) * 0.6
		var tint: Color = [PIPE_GREY, MODULE_YELLOW, PIPE_GREY, Color(0.3, 0.5, 0.35)][k]
		_member(tool, Vector3(from.x, floor + high + 0.45, from.y + z), Vector3(to.x, floor + high + 0.45, to.y + z),
			0.25, THIN_SIDES, tint)


## THE HANDRAILS round every deck's open edge: a top rail, a knee rail and posts every 2.5 m, yellow as they are painted.
static func _handrails(tool: SurfaceTool) -> void:
	for deck in [[CELLAR_PLAN, CELLAR_DECK], [PRODUCTION_PLAN, PRODUCTION_DECK], [WEATHER_PLAN, WEATHER_DECK]]:
		var plan: Rect2 = deck[0]
		var floor: float = deck[1]
		var c: Array[Vector2] = [plan.position + Vector2(0.2, 0.2), Vector2(plan.end.x - 0.2, plan.position.y + 0.2),
			plan.end - Vector2(0.2, 0.2), Vector2(plan.position.x + 0.2, plan.end.y - 0.2)]
		for k in range(4):
			var a: Vector2 = c[k]
			var b: Vector2 = c[(k + 1) % 4]
			# The weather deck's +x edge is the quarters' wall, and has no rail.
			if plan == WEATHER_PLAN and is_equal_approx(a.x, b.x) and a.x > 0.0:
				continue
			Plating.bar(tool, a, b, 0.07, floor + 1.02, floor + 1.1, HANDRAIL)
			Plating.bar(tool, a, b, 0.05, floor + 0.5, floor + 0.56, HANDRAIL)
			var n: int = maxi(1, int(a.distance_to(b) / 2.5))
			for s in range(n + 1):
				var p: Vector2 = a.lerp(b, float(s) / float(n))
				Plating.box(tool, Vector3(p.x, floor + 0.55, p.y), Vector3(0.07, 1.1, 0.07), HANDRAIL)


## THE STAIRS: an open flight between each pair of decks at the north-west corner, a landing at each deck, a stringer and
## a rail each side.
static func _stairs(tool: SurfaceTool) -> void:
	var floors: Array[float] = [CELLAR_DECK, PRODUCTION_DECK, WEATHER_DECK]
	for k in range(floors.size() - 1):
		var low: float = floors[k]
		var high: float = floors[k + 1]
		var x0: float = -20.0 + float(k) * 12.0
		var run: float = (high - low) / tan(deg_to_rad(40.0))
		var z: float = PRODUCTION_PLAN.position.y + 0.9
		var foot := Vector3(x0, low, z)
		var head := Vector3(x0 + run, high, z)
		for side in [-0.6, 0.6]:
			_member(tool, foot + Vector3(0.0, 0.2, side), head + Vector3(0.0, -0.1, side), 0.12, THIN_SIDES, DECK_STEEL)
			_member(tool, foot + Vector3(0.0, 1.1, side), head + Vector3(0.0, 1.0, side), 0.04, THIN_SIDES, HANDRAIL)
		var steps: int = int((high - low) / 0.2)
		for s in range(0, steps, 3):
			var p: Vector3 = foot.lerp(head, float(s) / float(steps))
			Plating.box(tool, p + Vector3(0.0, 0.2, 0.0), Vector3(0.3, 0.06, 1.2), GRATING)


## ---- the quarters and the helideck --------------------------------------------------------------------------------

## THE LIVING QUARTERS: a white block of cabins from the production deck to the roof, orange-red bands at every other
## floor, and the frame the helideck stands on. The windows themselves are surface 1 (`_windows`).
static func _quarters(tool: SurfaceTool) -> void:
	var r: Rect2 = QUARTERS
	var middle: Vector2 = r.get_center()
	var bottom: float = PRODUCTION_DECK
	Plating.box(tool, Vector3(middle.x, (bottom + QUARTERS_ROOF) * 0.5, middle.y),
		Vector3(r.size.x, QUARTERS_ROOF - bottom, r.size.y), QUARTERS_WHITE)
	var floors: int = int((QUARTERS_ROOF - bottom) / STOREY)
	for f in range(0, floors, 2):
		var y: float = bottom + float(f) * STOREY
		Plating.band(tool, r, y, y + 0.4, QUARTERS_TRIM, 0.0)
	Plating.band(tool, r, QUARTERS_ROOF - 0.9, QUARTERS_ROOF, QUARTERS_TRIM, 0.0)
	# A radio mast on the roof's west edge, out of the helideck's clear sector.
	_member(tool, Vector3(r.position.x + 1.0, QUARTERS_ROOF, r.end.y - 2.0),
		Vector3(r.position.x + 1.0, QUARTERS_ROOF + 12.0, r.end.y - 2.0), 0.25, THIN_SIDES, MODULE_WHITE)
	# THE HELIDECK'S SUPPORT: posts from the roof and struts from the quarters' east wall out to the deck's far edge.
	# Every post and strut ends under the deck's own outline, asked of `helideck_reach`, so none stands out in air.
	var under: float = HELIDECK_TOP - HELIDECK_THICK
	for z in [-9.0, -3.0, 3.0, 9.0]:
		var west: float = -helideck_reach(z, -1.0) + 0.8
		for x in [maxf(west, r.position.x + 1.0), r.end.x - 1.0]:
			_member(tool, Vector3(x, QUARTERS_ROOF, z), Vector3(x, under, z), 0.35, BRACE_SIDES, DECK_STEEL)
		var reach: float = helideck_reach(z, 1.0) - 0.8
		_member(tool, Vector3(r.end.x, QUARTERS_ROOF - 7.0, z), Vector3(reach, under, z), 0.4, BRACE_SIDES,
			DECK_STEEL)
		_member(tool, Vector3(r.end.x - 1.0, under, z), Vector3(reach, under, z), 0.35, BRACE_SIDES, DECK_STEEL)


## THE WINDOWS: rows of panes on the quarters' four walls, one row a storey, a hand's breadth proud of the wall.
static func _windows(tool: SurfaceTool) -> void:
	var r: Rect2 = QUARTERS
	var floors: int = int((QUARTERS_ROOF - 1.0 - PRODUCTION_DECK) / STOREY)
	for f in range(floors):
		var y: float = PRODUCTION_DECK + float(f) * STOREY + 1.2
		Plating.band(tool, r, y, y + 1.1, WINDOW, 1.2)


## THE HELIDECK: an octagonal plate, dark green, with its markings painted on its top -- the white perimeter line, the
## yellow touchdown circle and the white H lying along the clear sector's bisector, which is +x -- and a skirt of steel
## under its edge.
static func _helideck(tool: SurfaceTool) -> void:
	var outline: PackedVector2Array = helideck_outline()
	Plating.prism(tool, outline, HELIDECK_TOP - HELIDECK_THICK, HELIDECK_TOP, HELIDECK_GREEN)
	var y: float = HELIDECK_TOP + 0.02
	var inner: PackedVector2Array = helideck_outline(-0.8)
	var outer: PackedVector2Array = helideck_outline(-0.4)
	for k in range(8):
		Plating.paint(tool, PackedVector2Array([outer[k], outer[(k + 1) % 8], inner[(k + 1) % 8], inner[k]]), y,
			MARK_WHITE)
	# The touchdown circle: its inner edge half the D-value across, a metre wide, in 24 flat segments.
	var c: Vector2 = HELIDECK_AT
	var r0: float = HELIDECK_ACROSS * 0.25
	var r1: float = r0 + 1.0
	for k in range(24):
		var a0: float = TAU * float(k) / 24.0
		var a1: float = TAU * float(k + 1) / 24.0
		Plating.paint(tool, PackedVector2Array([c + Vector2(cos(a0), sin(a0)) * r1, c + Vector2(cos(a1), sin(a1)) * r1,
			c + Vector2(cos(a1), sin(a1)) * r0, c + Vector2(cos(a0), sin(a0)) * r0]), y, MARK_YELLOW)
	# THE H: 4 m wide, 6 m tall, its bars 0.75 m. Its uprights lie along the bisector, so it reads upright on approach.
	var tall: float = 3.0
	var wide: float = 2.0
	var bar: float = 0.375
	for s in [-1.0, 1.0]:
		_paint_rect(tool, Rect2(c.x - tall, c.y + s * wide - bar, tall * 2.0, bar * 2.0), y + 0.01, MARK_WHITE)
	_paint_rect(tool, Rect2(c.x - bar, c.y - wide, bar * 2.0, wide * 2.0), y + 0.01, MARK_WHITE)


static func _paint_rect(tool: SurfaceTool, r: Rect2, y: float, tint: Color) -> void:
	Plating.paint(tool, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)]), y, tint)


## THE SAFETY NET round the helideck: a dark mesh sloping out and down from under the deck's edge, on a light frame.
static func _helideck_net(tool: SurfaceTool) -> void:
	var edge: PackedVector2Array = helideck_outline()
	var far: PackedVector2Array = helideck_outline(NET_OUT)
	var top: float = HELIDECK_TOP - 0.1
	var low: float = top - NET_FALL
	for k in range(8):
		var a: Vector2 = edge[k]
		var b: Vector2 = edge[(k + 1) % 8]
		var fa: Vector2 = far[k]
		var fb: Vector2 = far[(k + 1) % 8]
		var out2: Vector2 = ((fa + fb) * 0.5 - (a + b) * 0.5).normalized()
		Plating.facing(tool, [Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(fb.x, low, fb.y),
			Vector3(fa.x, low, fa.y)], Vector3(out2.x * 0.2, 1.0, out2.y * 0.2), NET)
		Plating.facing(tool, [Vector3(a.x, top - 0.02, a.y), Vector3(b.x, top - 0.02, b.y), Vector3(fb.x, low - 0.02, fb.y),
			Vector3(fa.x, low - 0.02, fa.y)], Vector3(0.0, -1.0, 0.0), NET)
		_member(tool, Vector3(fa.x, low, fa.y), Vector3(fb.x, low, fb.y), 0.06, THIN_SIDES, MODULE_GREY)


## ---- the drilling ---------------------------------------------------------------------------------------------------

## THE DRILL FLOOR: a clad substructure over the conductors, grey, with a V-door ramp down to the pipe deck on its
## south side.
static func _drill_floor(tool: SurfaceTool) -> void:
	_block(tool, DRILL_FLOOR, WEATHER_DECK, DRILL_FLOOR_TOP - WEATHER_DECK, MODULE_GREY.darkened(0.1))
	var middle: Vector2 = DRILL_FLOOR.get_center()
	# The pipe deck and catwalk on the south side, with the ramp up to the V-door.
	Plating.box(tool, Vector3(middle.x, WEATHER_DECK + 1.5, DRILL_FLOOR.end.y + 4.5), Vector3(12.0, 3.0, 9.0),
		DECK_STEEL.darkened(0.1))
	Plating.facing(tool, [Vector3(middle.x - 1.2, WEATHER_DECK + 3.0, DRILL_FLOOR.end.y + 4.0),
		Vector3(middle.x + 1.2, WEATHER_DECK + 3.0, DRILL_FLOOR.end.y + 4.0),
		Vector3(middle.x + 1.2, DRILL_FLOOR_TOP, DRILL_FLOOR.end.y),
		Vector3(middle.x - 1.2, DRILL_FLOOR_TOP, DRILL_FLOOR.end.y)], Vector3(0.0, 1.0, 1.0), GRATING)
	for k in range(5):
		_member(tool, Vector3(middle.x - 5.0, WEATHER_DECK + 3.3, DRILL_FLOOR.end.y + 1.5 + float(k) * 0.6),
			Vector3(middle.x + 5.0, WEATHER_DECK + 3.3, DRILL_FLOOR.end.y + 1.5 + float(k) * 0.6), 0.25, THIN_SIDES,
			PIPE_GREY)


## THE DERRICK: four legs tapering from DERRICK_BASE to DERRICK_TOP, girts and X-bracing in every face, a windwall of
## cladding round its lower quarter, the monkey board, and the crown block painted red.
static func _derrick(tool: SurfaceTool) -> void:
	var middle: Vector2 = DRILL_FLOOR.get_center()
	var foot := Vector3(middle.x, DRILL_FLOOR_TOP, middle.y)
	_lattice(tool, foot, foot + Vector3.UP * DERRICK_HEIGHT, DERRICK_BASE, DERRICK_TOP, Vector3.RIGHT, 8, 0.32, 0.14,
		DERRICK_GREY)
	# The windwall: flat cladding round the lowest quarter, inside the legs.
	var wall_top: float = DERRICK_HEIGHT * 0.25
	var half0: float = DERRICK_BASE * 0.5 - 0.35
	var half1: float = lerpf(DERRICK_BASE, DERRICK_TOP, 0.25) * 0.5 - 0.35
	for k in range(4):
		var a: float = PI * 0.5 * float(k)
		var u := Vector3(cos(a), 0.0, sin(a))
		var v := Vector3(-sin(a), 0.0, cos(a))
		Plating.facing(tool, [foot + u * half0 - v * half0, foot + u * half0 + v * half0,
			foot + Vector3.UP * wall_top + u * half1 + v * half1, foot + Vector3.UP * wall_top + u * half1 - v * half1],
			u, MODULE_GREY.darkened(0.2))
	# The monkey board, two thirds up, and the crown.
	var board_y: float = DRILL_FLOOR_TOP + DERRICK_HEIGHT * 0.62
	var board_half: float = lerpf(DERRICK_BASE, DERRICK_TOP, 0.62) * 0.5
	Plating.box(tool, Vector3(middle.x - board_half - 0.8, board_y, middle.y), Vector3(1.6, 0.3, board_half * 1.6),
		DERRICK_GREY)
	var crown: Vector3 = derrick_crown()
	Plating.box(tool, crown + Vector3.UP * 1.0, Vector3(DERRICK_TOP + 0.8, 2.0, DERRICK_TOP + 0.8), DERRICK_RED)
	Plating.box(tool, crown + Vector3(0.0, 2.6, 0.0), Vector3(1.4, 1.2, DERRICK_TOP), DERRICK_RED.darkened(0.2))


## A LATTICE TOWER OR BOOM from `foot` to `tip`, square in section, `wide_foot` across at the foot and `wide_tip` at the
## tip, one face square to `across`: four chords, a girt and an X in every one of `bays` panels on every face.
static func _lattice(tool: SurfaceTool, foot: Vector3, tip: Vector3, wide_foot: float, wide_tip: float,
		across: Vector3, bays: int, chord: float, lace: float, tint: Color) -> void:
	var along: Vector3 = (tip - foot).normalized()
	var u: Vector3 = (across - along * across.dot(along)).normalized()
	var v: Vector3 = along.cross(u).normalized()
	var corner := func(t: float, k: int) -> Vector3:
		var half: float = lerpf(wide_foot, wide_tip, t) * 0.5
		var su: float = 1.0 if k == 0 or k == 3 else -1.0
		var sv: float = 1.0 if k < 2 else -1.0
		return foot.lerp(tip, t) + u * su * half + v * sv * half
	for k in range(4):
		_member(tool, corner.call(0.0, k), corner.call(1.0, k), chord, THIN_SIDES, tint)
	for b in range(bays + 1):
		var t: float = float(b) / float(bays)
		for k in range(4):
			_member(tool, corner.call(t, k), corner.call(t, (k + 1) % 4), lace, THIN_SIDES, tint)
	for b in range(bays):
		var t0: float = float(b) / float(bays)
		var t1: float = float(b + 1) / float(bays)
		for k in range(4):
			_member(tool, corner.call(t0, k), corner.call(t1, (k + 1) % 4), lace, THIN_SIDES, tint)
			_member(tool, corner.call(t0, (k + 1) % 4), corner.call(t1, k), lace, THIN_SIDES, tint)


## ---- the cranes, the flare and the lifeboats -------------------------------------------------------------------------

## A PEDESTAL CRANE: an eight-sided pedestal on the weather deck, the slewing house and cab on it, a tapering lattice
## boom raised over the side, the gantry and pendant lines to its tip, and the hook hanging from it.
static func _crane(tool: SurfaceTool, crane: Dictionary) -> void:
	var at: Vector2 = crane["at"]
	var slew: float = deg_to_rad(float(crane["slew"]))
	var base := Vector3(at.x, WEATHER_DECK, at.y)
	_member(tool, base, base + Vector3.UP * (PEDESTAL_TOP - WEATHER_DECK), PEDESTAL_DIAMETER * 0.5, LEG_SIDES,
		MODULE_ORANGE, true)
	var turn := Basis(Vector3.UP, -slew)
	var house: Vector3 = base + Vector3.UP * (PEDESTAL_TOP - WEATHER_DECK + 1.6)
	Plating.box(tool, house - turn * Vector3(1.2, 0.0, 0.0), Vector3(6.0, 3.2, 3.8), CRANE_YELLOW, turn)
	Plating.box(tool, house + turn * Vector3(1.6, 0.2, 2.4), Vector3(2.4, 2.4, 1.6), CRANE_YELLOW.darkened(0.3), turn)
	var boom: Array[Vector3] = boom_of(crane)
	_lattice(tool, boom[0], boom[1], 1.8, 0.8, Vector3.UP, 10, 0.16, 0.07, CRANE_YELLOW)
	# The gantry on the house and the pendants from its head to the boom's tip.
	var gantry: Vector3 = house - turn * Vector3(3.2, -7.0, 0.0)
	_member(tool, house - turn * Vector3(3.2, -1.6, 1.2), gantry, 0.18, THIN_SIDES, CRANE_YELLOW)
	_member(tool, house - turn * Vector3(3.2, -1.6, -1.2), gantry, 0.18, THIN_SIDES, CRANE_YELLOW)
	_member(tool, gantry, boom[1], 0.05, THIN_SIDES, Color(0.2, 0.2, 0.2))
	# The hook: a fall of wire from the tip and a block on it.
	var hook: Vector3 = boom[1] + Vector3.DOWN * 14.0
	_member(tool, boom[1], hook, 0.05, THIN_SIDES, Color(0.2, 0.2, 0.2))
	Plating.box(tool, hook + Vector3.DOWN * 0.6, Vector3(0.9, 1.2, 0.6), CRANE_YELLOW.darkened(0.2))


## THE FLARE BOOM: a lattice truss leaning out over the sea from the weather deck's -x end, a walkway along its top,
## and the flare stack at its end. The flame is not steel and is `OilField`'s, at `flare_tip()`.
static func _flare_boom(tool: SurfaceTool) -> void:
	var end: Vector3 = _flare_end()
	_lattice(tool, FLARE_ROOT + Vector3.UP * 2.0, end, 4.0, 2.2, Vector3.UP, 12, 0.3, 0.12, DECK_STEEL)
	_member(tool, end, flare_tip(), 0.55, BRACE_SIDES, Color(0.25, 0.23, 0.22), true)
	Plating.box(tool, end + Vector3.UP * 0.2, Vector3(4.0, 0.25, 4.0), GRATING)
	# The boom's foot is a frame down to the deck, so it stands on what is under it.
	_member(tool, FLARE_ROOT + Vector3(2.0, 0.0, -2.0), FLARE_ROOT + Vector3(0.0, 2.0, 0.0), 0.4, BRACE_SIDES, DECK_STEEL)
	_member(tool, FLARE_ROOT + Vector3(2.0, 0.0, 2.0), FLARE_ROOT + Vector3(0.0, 2.0, 0.0), 0.4, BRACE_SIDES, DECK_STEEL)


## THE LIFEBOATS: four enclosed orange boats, two a side of the quarters, each hanging from a pair of davit arms over the
## sea at the production deck.
static func _lifeboats(tool: SurfaceTool) -> void:
	# OUTBOARD OF THE PRODUCTION DECK'S EDGE, hanging over the sea, so a boat lowered goes straight down to the water.
	for side in [-1.0, 1.0]:
		for x in [22.0, 31.0]:
			var edge_z: float = side * (PRODUCTION_PLAN.size.y * 0.5 - 0.3)
			var boat := Vector3(x, PRODUCTION_DECK + 1.2, side * (PRODUCTION_PLAN.size.y * 0.5 + 2.0))
			_lifeboat(tool, boat)
			for s in [-2.6, 2.6]:
				var post := Vector3(x + s, PRODUCTION_DECK, edge_z)
				var head := Vector3(x + s, PRODUCTION_DECK + 6.0, boat.z)
				_member(tool, post, post + Vector3.UP * 6.0, 0.22, THIN_SIDES, MODULE_GREY)
				_member(tool, post + Vector3.UP * 6.0, head, 0.2, THIN_SIDES, MODULE_GREY)
				_member(tool, head, Vector3(x + s, boat.y + 1.6, boat.z), 0.04, THIN_SIDES, Color(0.2, 0.2, 0.2))


static func _lifeboat(tool: SurfaceTool, at: Vector3) -> void:
	# A hull as an elongated octagon, tapered at both ends, and a cabin top on it.
	var hull := PackedVector2Array([Vector2(-4.2, -0.4), Vector2(-3.4, -1.4), Vector2(3.4, -1.4), Vector2(4.2, -0.4),
		Vector2(4.2, 0.4), Vector2(3.4, 1.4), Vector2(-3.4, 1.4), Vector2(-4.2, 0.4)])
	var moved := PackedVector2Array()
	for p in hull:
		moved.append(Vector2(at.x, at.z) + p)
	Plating.prism(tool, moved, at.y - 1.0, at.y + 0.6, LIFEBOAT)
	var cabin := PackedVector2Array()
	for p in hull:
		cabin.append(Vector2(at.x, at.z) + p * Vector2(0.85, 0.8))
	Plating.prism(tool, cabin, at.y + 0.6, at.y + 1.6, LIFEBOAT.lightened(0.1))
	Plating.box(tool, at + Vector3(2.2, 2.0, 0.0), Vector3(1.4, 0.8, 1.2), LIFEBOAT.lightened(0.1))


## ---- the small helpers ----------------------------------------------------------------------------------------------

## A STRAIGHT MEMBER from `a` to `b`: a prism of `sides` flat faces, square to its own axis. With no `tint`, the jacket's
## paint by height -- split where it crosses the splash zone, so the band at the water is dark and what is under it grown
## over, whichever member crosses it. `capped` closes both ends, for a vessel or a stack whose end is seen.
static func _member(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float, sides: int,
		tint: Color = Color(-1, -1, -1), capped: bool = false) -> void:
	if tint.r >= 0.0:
		_tube(tool, a, b, radius, sides, tint, capped)
		return
	var cuts: Array[float] = [0.0, 1.0]
	for y in [SPLASH, -SPLASH]:
		if (a.y - y) * (b.y - y) < 0.0:
			cuts.append((y - a.y) / (b.y - a.y))
	cuts.sort()
	for k in range(cuts.size() - 1):
		var p: Vector3 = a.lerp(b, cuts[k])
		var q: Vector3 = a.lerp(b, cuts[k + 1])
		var mid: float = (p.y + q.y) * 0.5
		var paint: Color = JACKET_PAINT if mid > SPLASH else (SPLASH_RUST if mid > -SPLASH else SEA_GROWTH)
		_tube(tool, p, q, radius, sides, paint, capped and (k == 0 or k == cuts.size() - 2))


static func _tube(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float, sides: int, tint: Color,
		capped: bool) -> void:
	var axis: Vector3 = b - a
	if axis.length_squared() < 1e-8:
		return
	var d: Vector3 = axis.normalized()
	var u: Vector3 = d.cross(Vector3.UP) if absf(d.y) < 0.95 else d.cross(Vector3.RIGHT)
	u = u.normalized()
	var v: Vector3 = d.cross(u).normalized()
	var ring: Array[Vector3] = []
	for k in range(sides):
		var ang: float = TAU * (float(k) + 0.5) / float(sides)
		ring.append((u * cos(ang) + v * sin(ang)) * radius)
	for k in range(sides):
		var p: Vector3 = ring[k]
		var q: Vector3 = ring[(k + 1) % sides]
		_quad(tool, a + p, a + q, b + q, b + p, (p + q).normalized(), tint)
	if capped:
		for k in range(1, sides - 1):
			_face(tool, a + ring[0], a + ring[k], a + ring[k + 1], -d, tint)
			_face(tool, b + ring[0], b + ring[k], b + ring[k + 1], d, tint)


## ONE FLAT QUAD, both triangles wound to face `out` -- `CoolingTower._quad`'s convention, which is Godot's clockwise.
static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, tint: Color) -> void:
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
