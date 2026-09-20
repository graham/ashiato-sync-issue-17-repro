extends Node3D
class_name RoadDiesel
## AN EMD SD40-2: the road diesel the island's freights are hauled by, and the most numerous heavy locomotive ever built
## in North America. The user asked for a better locomotive on 2026-09-19 -- *"anything you find for a modern train will
## do"* -- and this is the one with a published envelope AND photographs an agent can actually read.
##
## WHAT IT REPLACES. `VehicleView._build_train_body` drew an F7A out of seven boxes: a slab side, a flat box nose, one
## black rectangle for a windscreen and a yellow stripe. It read as a red brick with a smaller brick in front of it. That
## model was an F-unit because the 2026-09-17 lane was asked for a Super Chief, and it was drawn to a published envelope
## with **no orthographic reference anywhere an agent can read** -- Commons has no drawing of an EMD carbody unit, and the
## two "builder's portraits" that look like roster broadsides are paintings (`learnings/2026-09-17-train.md`).
##
## THE SHAPE OF A HOOD UNIT, which is what makes it read as a modern diesel rather than as a box:
##   - a LOW SHORT HOOD ahead of the cab, about two-thirds the height of the long hood, with the number boards and the
##     headlight on its front;
##   - a CAB, the widest thing on it, with a big square windscreen and side windows a driver leans out of -- and a roof
##     that sits BELOW the long hood's, which is a Dash-2 recognition feature and the thing this model first got
##     backwards;
##   - a LONG HOOD running two-thirds of the length behind it, NARROWER than the cab, so a walkway runs down each side of
##     it at deck height with handrails along the outside -- the walkway and the rails either side of the hood are the
##     silhouette;
##   - a flared RADIATOR at the rear, standing proud of the hood sides and taller than it, with the cooling fans on top;
##   - a FUEL TANK slung under the frame between the trucks, and air reservoirs beside it;
##   - two three-axle HT-C trucks, which is what makes an SD40-2 an SD and not a GP.
##
## THE NUMBERS. PUBLISHED is the <https://en.wikipedia.org/wiki/EMD_SD40-2> infobox, read 2026-09-19:
##
##   LENGTH over couplers   20.98 m   PUBLISHED, 68 ft 10 in.
##   WIDTH                   3.127 m  PUBLISHED, 10 ft 3 1/8 in over the grabirons.
##   HEIGHT                  4.753 m  PUBLISHED, 15 ft 7 1/8 in -- the HOOD, not the cab: the photograph's roofline runs
##                                    at 4.70-4.79 m and its cab at 4.52-4.58.
##   TRUCK_CENTRES          13.259 m  PUBLISHED, 43 ft 6 in between the pivots.
##   TRUCK_WHEELBASE         4.140 m  PUBLISHED, 13 ft 7 in, axle 1 to axle 3, so 2.07 m between axles.
##   WHEEL                   1.016 m  PUBLISHED, 40 in.
##   Mass                  167,000 kg PUBLISHED, 368,000 lb. Not this file's: it is the simulation's.
##
## EVERYTHING ELSE IS A PROPORTION off the photographs, and each is tagged where it is used. They are read to about
## 0.15 m, which is what a station picked by eye off a gridded overlay of a 3,648 px photograph is worth, and that is
## ample for a model whose smallest feature is a 0.2 m step. `cockpit/craft/train/sources.md` carries the references,
## their licences and what could NOT be measured:
##   - **NS 3275** (Commons, CC BY-SA 3.0, 3,648 px) is the only TRUE BROADSIDE of an SD40-2 there is. It is a HIGH short
##     hood unit -- the Southern and N&W variant, whose nose is as tall as its cab -- so it settles everything aft of the
##     cab front, which the two variants share, and nothing about the nose.
##   - **ICG 6045 and 6046** (CC0, 5,184 and 4,752 px) are three-quarter views of low-nose units: the nose's proportions
##     against the cab, and nothing else, because a three-quarter view has no scale.
##   - **CNW 6847 head-on** (CC BY-SA 2.0) for the cab front and the pilot.
##   - **The running gear could not be measured at all.** On the broadside the wheels, the truck frames, the rails and
##     the shadow under the locomotive are one black at that exposure and no threshold separates them -- the same trap
##     the boxcar met in September. So the trucks are the PUBLISHED figures above and nothing is pretended otherwise.
##
## THE TESSELLATION, stated so nobody rounds it later (`modelling_here.md` section 4): every part here is a flat-sided
## box or prism with a hard crease at each edge, except a WHEEL, which is an eight-sided prism drawn ROUND its circle so
## its flat bottom touches the railhead exactly where the real tread does (the boxcar's rule, and the reason it is a
## rule: an octagon drawn THROUGH the circle stands 3 cm low). The cooling fans are eight-sided. Nothing else is round.
##
## IT STANDS ON THE TRACK, not in it: the railhead is y = 0 in this file's frame, every wheel's flat bottom is on it, and
## the wheels are `PermanentWay.RAIL_CENTRES / 2` either side of the middle, asked of the track rather than typed.

const PLATING := preload("res://objects/vehicles/ships/plating.gd")
const PERMANENT_WAY := preload("res://world/permanent_way.gd")

## ---- the published envelope ------------------------------------------------------------------
const LENGTH: float = 68.0 * 0.3048 + 10.0 * 0.0254
const WIDTH: float = 10.0 * 0.3048 + 3.125 * 0.0254
const HEIGHT: float = 15.0 * 0.3048 + 7.125 * 0.0254
const TRUCK_CENTRES: float = 43.0 * 0.3048 + 6.0 * 0.0254
const TRUCK_WHEELBASE: float = 13.0 * 0.3048 + 7.0 * 0.0254
const WHEEL_DIAMETER: float = 40.0 * 0.0254
const AXLES_EACH_TRUCK: int = 3
const WHEEL_SIDES: int = 8

## ---- the layout, measured off the photographs ---------------------------------------------------
## The deck, over the railhead. MEASURED off the broadside: the walkway's white sill stripe runs 3,073 px end to end and
## is fitted over 1,757 columns at 3.5 px rms, so with the deck 19.90 m long -- the published length over couplers less a
## coupler and its pocket at each end, which is the soft part of this -- the photograph is 154.4 px a metre, and the
## stripe stands 1.06 m over the railhead. It was first typed at 1.37 and the photograph refused it: at 1.37 the long
## hood would have stood 5.06 m over the rail, taller than the whole locomotive is published to be.
##
## IT IS BUILT AT 1.14, NOT THE MEASURED 1.06, AND A WHEEL IS WHY. A 40 in wheel's top stands 1.016 m over the railhead
## and the frame passes over it, so a deck at 1.06 with any plate under it at all is a frame drawn through its own
## wheels. The 8 cm is inside what the measurement is worth -- it rests on the deck being 19.90 m long, which is the
## published length over couplers less a coupler at each end and is this file's softest number.
const DECK: float = 1.14
## The deck PLATE's own thickness, and the deep centre sill under it. The sill runs BETWEEN THE TRUCKS only: a frame
## drawn 0.30 m deep from end to end is a frame through both sets of wheels, for the reason above.
const DECK_PLATE: float = 0.10
const SILL_DEEP: float = 0.34
## The long hood's roof, the flared radiator's above it, and the cab's BELOW it. MEASURED at 154.4 px a metre off the
## broadside, whose roofline runs flat at 4.70 to 4.79 m over the railhead along its whole length and drops to 4.52-4.58
## over the cab.
##
## **THE CAB ROOF IS LOWER THAN THE LONG HOOD**, which is a recognition feature of an EMD Dash-2 and which this model had
## the wrong way round: the published 15 ft 7 1/8 in is the HOOD's height, not the cab's, and a cab built as the tallest
## thing on the locomotive reads as a switcher.
## NOTHING STANDS ABOVE THE PUBLISHED HEIGHT: the exhaust stacks and the dynamic brake blister are what reach it, so the
## roof they stand on is below it. Built with the roof itself at 4.70, the drawn locomotive came out 4.96 m tall -- over
## a published figure that is the top of everything.
const HOOD_TOP: float = 4.62
const RADIATOR_TOP: float = 4.70
const CAB_ROOF: float = 4.55
## The short hood's top. ESTIMATE from the three-quarter views of the low-nose units: about two-thirds of the way from
## the deck to the cab roof. The broadside cannot give it -- that unit's nose is as tall as its hood.
const NOSE_TOP: float = 3.30
## Across: the hood is inboard of the walkway, the cab is the full width.
const HOOD_WIDE: float = 2.82
const CAB_WIDE: float = 3.05
const RADIATOR_WIDE: float = 3.00
## Along, from the middle, -Z forward. The pilot faces are the deck's ends; the couplers reach past them.
const DECK_END: float = LENGTH * 0.5 - 0.54
const NOSE_FRONT: float = -DECK_END + 2.35
const CAB_FRONT: float = NOSE_FRONT + 2.40
const CAB_BACK: float = CAB_FRONT + 2.80
const HOOD_BACK: float = DECK_END - 1.35
const RADIATOR_FRONT: float = HOOD_BACK - 2.95

## ---- the colours -------------------------------------------------------------------------------
## THE ISLAND'S OWN LIVERY, and no railroad's. Every railway herald, name and paint scheme is a trademark: this is the
## red the island's freight cars already wear, with a black frame and a grey roof, and it copies nobody.
const PAINT := Color(0.46, 0.15, 0.13)
const DARK := Color(0.10, 0.10, 0.11)
const ROOF := Color(0.30, 0.30, 0.31)
const GLASS := Color(0.08, 0.10, 0.13)
## The engine-room doors: the paint a shade down, so a hood side reads as panels rather than as one sheet.
const DOOR := Color(0.38, 0.12, 0.11)
const STEEL := Color(0.38, 0.38, 0.40)
const STRIPE := Color(0.88, 0.72, 0.18)
const WHEEL_PAINT := Color(0.05, 0.05, 0.06)

var _built: bool = false


## BUILT IN PLACE, after `new()`. Named parts, because `named_parts` and `joined_parts` hold every piece of a vehicle to
## a name and to touching its neighbours.
func dress() -> void:
	if _built:
		return
	_built = true
	name = "RoadDiesel"
	var paint := _material()
	_add("Frame", _frame(), paint)
	_add("FuelTank", _fuel_tank(), paint)
	_add("ShortHood", _short_hood(), paint)
	_add("Cab", _cab(), paint)
	_add("CabWindscreen", _windscreen(), paint)
	_add("LongHood", _long_hood(), paint)
	_add("Radiator", _radiator(), paint)
	_add("Handrails", _handrails(), paint)
	for end in [-1.0, 1.0]:
		var which: String = "Front" if end < 0.0 else "Rear"
		_add("Truck%s" % which, _truck(end * TRUCK_CENTRES * 0.5), paint)


## ---- the pieces ---------------------------------------------------------------------------------

## THE FRAME AND ITS TWO END PLATFORMS: one deck the whole length, the pilots at its ends, and the anticlimber plates.
func _frame() -> SurfaceTool:
	var tool := _tool()
	PLATING.box(tool, Vector3(0.0, DECK - DECK_PLATE * 0.5, 0.0), Vector3(WIDTH, DECK_PLATE, DECK_END * 2.0), DARK)
	# THE DEEP CENTRE SILL, between the trucks and nowhere else: the wheels' tops are 1.016 m up and the deck is 1.14, so
	# a sill carried over a truck is a sill drawn through six wheels.
	PLATING.box(tool, Vector3(0.0, DECK - DECK_PLATE - SILL_DEEP * 0.5, 0.0),
		Vector3(WIDTH - 0.50, SILL_DEEP, TRUCK_CENTRES - TRUCK_WHEELBASE - 1.40), DARK)
	# The walkway's tread, a shade lighter, standing just proud of the frame so the deck reads as a deck from above.
	PLATING.box(tool, Vector3(0.0, DECK + 0.02, 0.0), Vector3(WIDTH - 0.06, 0.05, DECK_END * 2.0 - 0.04), STEEL)
	# THE SAFETY STRIPE along the frame's side, which is what makes the deck line read at a distance. A BAND IS PAINT: it
	# stands a centimetre proud only so the two faces do not fight (the F7A's stripe was 3 per cent of the width).
	PLATING.box(tool, Vector3(0.0, DECK - DECK_PLATE * 0.5, 0.0),
		Vector3(WIDTH + 0.02, 0.07, DECK_END * 2.0 - 0.02), STRIPE)
	for end in [-1.0, 1.0]:
		# The pilot: a plate down the front of each end, and the coupler in the middle of it.
		PLATING.box(tool, Vector3(0.0, DECK - 0.36, end * (DECK_END - 0.08)), Vector3(WIDTH - 0.20, 0.52, 0.16), DARK)
		PLATING.box(tool, Vector3(0.0, DECK - 0.34, end * (DECK_END + 0.27)), Vector3(0.36, 0.28, 0.54), STEEL)
		# And the steps down to the ground at each corner, which every hood unit has and which say how big it is.
		for side in [-1.0, 1.0]:
			for step in range(3):
				var down: float = DECK - 0.26 - 0.27 * float(step)
				PLATING.box(tool, Vector3(side * (WIDTH * 0.5 - 0.22), down, end * (DECK_END - 0.55)),
					Vector3(0.40, 0.05, 0.62), STEEL)
	return tool


## THE FUEL TANK slung under the frame between the trucks, with an air reservoir each side of it.
func _fuel_tank() -> SurfaceTool:
	var tool := _tool()
	var bottom: float = DECK - DECK_PLATE - SILL_DEEP - 0.62
	PLATING.box(tool, Vector3(0.0, bottom + 0.36, -0.30), Vector3(2.44, 0.72, 5.20), DARK)
	# Chamfer: the tank's bottom corners are cut, which is what keeps it clear of the rails on a curve.
	PLATING.box(tool, Vector3(0.0, bottom + 0.06, -0.30), Vector3(2.10, 0.12, 5.20), DARK)
	for side in [-1.0, 1.0]:
		PLATING.box(tool, Vector3(side * 1.05, DECK - DECK_PLATE - 0.30, 3.40), Vector3(0.62, 0.52, 1.90), STEEL)
	return tool


## THE SHORT HOOD, low, with the headlight and the number boards on its front face.
func _short_hood() -> SurfaceTool:
	var tool := _tool()
	var high: float = NOSE_TOP - DECK
	var along: float = CAB_FRONT - NOSE_FRONT
	PLATING.box(tool, Vector3(0.0, DECK + high * 0.5, (NOSE_FRONT + CAB_FRONT) * 0.5),
		Vector3(HOOD_WIDE, high, along), PAINT)
	# The roof, a shade off the sides so the top face reads from above.
	PLATING.box(tool, Vector3(0.0, NOSE_TOP - 0.03, (NOSE_FRONT + CAB_FRONT) * 0.5),
		Vector3(HOOD_WIDE - 0.04, 0.06, along - 0.04), ROOF)
	# The headlight and the two number boards on the front face.
	PLATING.box(tool, Vector3(0.0, NOSE_TOP - 0.34, NOSE_FRONT - 0.03), Vector3(0.44, 0.30, 0.10), STEEL)
	for side in [-1.0, 1.0]:
		PLATING.box(tool, Vector3(side * 0.62, NOSE_TOP - 0.30, NOSE_FRONT - 0.02), Vector3(0.52, 0.26, 0.06), GLASS)
	return tool


## THE CAB: the tallest thing on the locomotive, the full width, with a windscreen and a side window each side.
func _cab() -> SurfaceTool:
	var tool := _tool()
	var high: float = CAB_ROOF - DECK
	var along: float = CAB_BACK - CAB_FRONT
	var middle: float = (CAB_FRONT + CAB_BACK) * 0.5
	PLATING.box(tool, Vector3(0.0, DECK + high * 0.5, middle), Vector3(CAB_WIDE, high, along), PAINT)
	PLATING.box(tool, Vector3(0.0, CAB_ROOF - 0.04, middle), Vector3(CAB_WIDE - 0.04, 0.08, along - 0.04), ROOF)
	for side in [-1.0, 1.0]:
		# The side window, in the cab's side, and the smaller one behind it.
		PLATING.box(tool, Vector3(side * (CAB_WIDE * 0.5 - 0.02), CAB_ROOF - 0.66, middle - 0.30),
			Vector3(0.06, 0.74, 1.10), GLASS)
		PLATING.box(tool, Vector3(side * (CAB_WIDE * 0.5 - 0.02), CAB_ROOF - 0.66, middle + 0.90),
			Vector3(0.06, 0.62, 0.56), GLASS)
	return tool


## THE WINDSCREEN, two panes either side of a centre post, standing at the cab's front face where a driver's eye is.
##
## ITS OWN PART, not welded into the cab, because two checks in `tests/train_models.gd` have to find it by name: that
## both drivers sit BEHIND it (the F7A before this drew its cab at one end and sat its drivers 12.4 m away at the
## other), and that nothing is drawn IN FRONT of it (the first F-unit model put the nose's step squarely over the glass,
## which was green on position and invisible in the picture).
func _windscreen() -> SurfaceTool:
	var tool := _tool()
	for side in [-1.0, 1.0]:
		PLATING.box(tool, Vector3(side * 0.66, CAB_ROOF - 0.62, CAB_FRONT - 0.02), Vector3(1.10, 0.86, 0.06), GLASS)
	return tool


## THE LONG HOOD, narrower than the cab so the walkway runs down each side of it, with the engine-room doors along it and
## the exhaust stacks and the dynamic brake blister on top.
func _long_hood() -> SurfaceTool:
	var tool := _tool()
	var high: float = HOOD_TOP - DECK
	var along: float = RADIATOR_FRONT - CAB_BACK
	var middle: float = (CAB_BACK + RADIATOR_FRONT) * 0.5
	PLATING.box(tool, Vector3(0.0, DECK + high * 0.5, middle), Vector3(HOOD_WIDE, high, along), PAINT)
	PLATING.box(tool, Vector3(0.0, HOOD_TOP - 0.03, middle), Vector3(HOOD_WIDE - 0.04, 0.06, along - 0.04), ROOF)
	# THE ENGINE-ROOM DOORS down each side: a row of panels, which is what a hood side is and what stops it reading as a
	# blank slab at any distance. EVERY PART BUILT IN A LOOP CARRIES THE LOOP IN ITS NAME -- but these are welded into
	# one mesh rather than added as nodes, so the name is the hood's.
	for side in [-1.0, 1.0]:
		for i in range(6):
			var at: float = CAB_BACK + 0.75 + (along - 1.5) * (float(i) + 0.5) / 6.0
			# A DOOR IS A PANEL IN THE SIDE, NOT A WINDOW. Drawn in the frame's black over 70 per cent of the hood's
			# height, six of them read as six tall sheets of glass down a locomotive that has none; they are a shade off
			# the paint, and shallower than they are wide.
			PLATING.box(tool, Vector3(side * (HOOD_WIDE * 0.5 + 0.005), DECK + high * 0.42, at),
				Vector3(0.03, high * 0.52, (along - 1.5) / 6.0 - 0.14), DOOR)
		# And the air intake grille high on the side, which every hood unit has and which breaks the long blank sheet.
		PLATING.box(tool, Vector3(side * (HOOD_WIDE * 0.5 + 0.01), HOOD_TOP - 0.42, middle + along * 0.22),
			Vector3(0.04, 0.46, along * 0.34), DARK)
	# The dynamic brake blister: a raised box on the roof over the middle of the hood.
	PLATING.box(tool, Vector3(0.0, HOOD_TOP + 0.05, middle - 0.40), Vector3(HOOD_WIDE - 0.30, 0.16, 2.60), PAINT)
	# The two exhaust stacks ahead of it.
	for i in range(2):
		PLATING.box(tool, Vector3(0.0, HEIGHT - 0.09, CAB_BACK + 1.30 + 0.70 * float(i)),
			Vector3(0.50, 0.24, 0.46), DARK)
	return tool


## THE RADIATOR at the rear: wider than the hood and taller, with the cooling fans on its roof. It is the one thing that
## says at a glance which end of the locomotive you are looking at.
func _radiator() -> SurfaceTool:
	var tool := _tool()
	var high: float = RADIATOR_TOP - DECK
	var along: float = HOOD_BACK - RADIATOR_FRONT
	var middle: float = (RADIATOR_FRONT + HOOD_BACK) * 0.5
	PLATING.box(tool, Vector3(0.0, DECK + high * 0.5, middle), Vector3(RADIATOR_WIDE, high, along), PAINT)
	PLATING.box(tool, Vector3(0.0, RADIATOR_TOP - 0.03, middle), Vector3(RADIATOR_WIDE - 0.04, 0.06, along - 0.04),
		ROOF)
	# THE RADIATOR GRILLES, one down each side under the fans, which is what the flare is for.
	for side in [-1.0, 1.0]:
		PLATING.box(tool, Vector3(side * (RADIATOR_WIDE * 0.5 + 0.01), RADIATOR_TOP - 0.55, middle),
			Vector3(0.04, 0.70, along - 0.50), DARK)
	# TWO COOLING FANS on the roof, eight-sided, sunk into it.
	for i in range(2):
		_fan(tool, Vector3(0.0, RADIATOR_TOP + 0.02, middle - 0.90 + 1.80 * float(i)), 0.60)
	return tool


## THE HANDRAILS along both walkways and round both platforms: thin bars on stanchions at waist height. They are what
## makes a hood unit read as a machine people walk about on rather than as a solid block.
func _handrails() -> SurfaceTool:
	var tool := _tool()
	var high: float = DECK + 1.06
	for side in [-1.0, 1.0]:
		var out: float = side * (WIDTH * 0.5 - 0.06)
		PLATING.box(tool, Vector3(out, high, 0.0), Vector3(0.05, 0.05, DECK_END * 2.0 - 0.20), STEEL)
		PLATING.box(tool, Vector3(out, high - 0.34, 0.0), Vector3(0.04, 0.04, DECK_END * 2.0 - 0.20), STEEL)
		for i in range(12):
			var at: float = -DECK_END + 0.60 + (DECK_END * 2.0 - 1.2) * float(i) / 11.0
			PLATING.box(tool, Vector3(out, DECK + 0.55, at), Vector3(0.05, 1.02, 0.05), STEEL)
		# And across each end, so the platform is fenced.
		for end in [-1.0, 1.0]:
			PLATING.box(tool, Vector3(side * (WIDTH * 0.25), high, end * (DECK_END - 0.08)),
				Vector3(WIDTH * 0.5, 0.05, 0.05), STEEL)
	return tool


## ONE HT-C TRUCK: a side frame each side, three axles, and six wheels standing on the railheads.
func _truck(at: float) -> SurfaceTool:
	var tool := _tool()
	var radius: float = WHEEL_DIAMETER * 0.5
	# The axles are evenly spaced, so the published wheelbase -- axle 1 to axle 3 -- is two gaps.
	var spacing: float = TRUCK_WHEELBASE / float(AXLES_EACH_TRUCK - 1)
	for side in [-1.0, 1.0]:
		# The side frame, over the axles, cut back so the wheels show above and beyond it: a frame drawn deep enough to
		# swallow them turns a truck into a featureless dark block (the boxcar's lesson).
		PLATING.box(tool, Vector3(side * (PERMANENT_WAY.RAIL_CENTRES * 0.5 + 0.10), radius + 0.30, at),
			Vector3(0.22, 0.44, TRUCK_WHEELBASE + 0.50), DARK)
	# The bolster across the middle, which is what the frame rests on.
	PLATING.box(tool, Vector3(0.0, radius + 0.42, at), Vector3(2.30, 0.30, 0.70), DARK)
	for axle in range(AXLES_EACH_TRUCK):
		var along: float = at + (float(axle) - float(AXLES_EACH_TRUCK - 1) * 0.5) * spacing
		PLATING.box(tool, Vector3(0.0, radius, along), Vector3(PERMANENT_WAY.RAIL_CENTRES - 0.30, 0.18, 0.22), DARK)
		for side in [-1.0, 1.0]:
			_wheel(tool, Vector3(side * PERMANENT_WAY.RAIL_CENTRES * 0.5, radius, along))
	return tool


## A WHEEL: an eight-sided prism on an axis across the track, drawn ROUND its circle so the flat at the bottom touches
## the railhead where the real tread does. The boxcar's rule, and the reason it is one.
func _wheel(tool: SurfaceTool, at: Vector3) -> void:
	var radius: float = (WHEEL_DIAMETER * 0.5) / cos(PI / float(WHEEL_SIDES))
	var half: float = 0.08
	var ring: Array[Vector2] = []
	for i in range(WHEEL_SIDES):
		var angle: float = TAU * (float(i) + 0.5) / float(WHEEL_SIDES)
		ring.append(Vector2(cos(angle), sin(angle)) * radius)
	for i in range(WHEEL_SIDES):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % WHEEL_SIDES]
		PLATING.facing(tool, [at + Vector3(-half, a.y, a.x), at + Vector3(half, a.y, a.x),
			at + Vector3(half, b.y, b.x), at + Vector3(-half, b.y, b.x)],
			Vector3(0.0, (a.y + b.y) * 0.5, (a.x + b.x) * 0.5).normalized(), WHEEL_PAINT)
		for face in [-1.0, 1.0]:
			_tri(tool, at + Vector3(face * half, 0.0, 0.0), at + Vector3(face * half, a.y, a.x),
				at + Vector3(face * half, b.y, b.x), Vector3(face, 0.0, 0.0), WHEEL_PAINT)


## A COOLING FAN: an eight-sided dish sunk into the radiator's roof.
func _fan(tool: SurfaceTool, at: Vector3, radius: float) -> void:
	var ring: Array[Vector3] = []
	for i in range(WHEEL_SIDES):
		var angle: float = TAU * (float(i) + 0.5) / float(WHEEL_SIDES)
		ring.append(at + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	for i in range(WHEEL_SIDES):
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % WHEEL_SIDES]
		_tri(tool, at, a, b, Vector3.UP, DARK)
		PLATING.facing(tool, [a, b, b - Vector3(0.0, 0.14, 0.0), a - Vector3(0.0, 0.14, 0.0)],
			(a - at).normalized(), STEEL)


## ---- the small change ---------------------------------------------------------------------------

static func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


func _add(title: String, tool: SurfaceTool, material: Material) -> MeshInstance3D:
	var drawn := MeshInstance3D.new()
	drawn.name = title
	drawn.mesh = PLATING.weld(tool)
	drawn.material_override = material
	add_child(drawn)
	return drawn


## ONE TRIANGLE facing `out`. `Plating.facing` indexes a fourth corner, so three cannot be handed to it.
static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var order: Array[Vector3] = [a, b, c]
	if (c - a).cross(b - a).dot(out) < 0.0:
		order = [a, c, b]
	tool.set_color(tint)
	for corner in order:
		tool.set_normal(out)
		tool.add_vertex(corner)


## The one material: colour in the vertices, and they are sRGB.
static func _material() -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = 0.62
	return paint
