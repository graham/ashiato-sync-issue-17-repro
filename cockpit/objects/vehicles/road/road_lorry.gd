@tool
extends RefCounted
class_name RoadLorry
## THE THREE TRUCKS: a panel van, a rigid box lorry and an articulated tractor with its trailer.
##
## WHAT MAKES A TRUCK A TRUCK, from the air and from a cockpit at a hold, is the opposite of what
## makes a car a car. A car is one shape with a narrower greenhouse on it; **a truck is TWO VOLUMES
## OF DIFFERENT HEIGHTS, and the joint between them is the whole silhouette.**
##
## 1. **THE CAB IS SHORTER AND NARROWER THAN THE BODY BEHIND IT**, and the body is taller. A lorry
##    drawn as one box is a shipping container on wheels; the step down from box to cab is what says
##    "lorry" before anything else resolves. The van is the exception that proves it -- its cab and
##    its box ARE one volume, which is exactly why a van reads as a van and not as a small lorry.
## 2. **A CABOVER'S WINDSCREEN IS NEARLY VERTICAL** and stands over the front axle, because there is
##    no bonnet in front of it. A raked screen on a flat nose is a car's cue on a lorry's body and it
##    reads as neither.
## 3. **THE BODY SITS ON A FRAME, WELL CLEAR OF THE ROAD.** The Atego's frame is a PUBLISHED 955 mm
##    over the road at the front axle unladen, so there is most of a metre of daylight and running
##    gear under a box body. Drawn down to the road it is a skip.
## 4. **WHEELS IN PAIRS AT THE BACK.** A lorry's drive axle is twinned, and from behind or from the
##    air a twinned wheel is the clearest single thing that separates a lorry from a large van.
##
## THE NUMBERS, and where each came from: `cockpit/craft/road/sources.md`. The rigid's are the best
## on this lane -- Mercedes-Benz's own UK specification sheet for the Atego 4x2 rigid, which prints
## six figures that close on one another exactly, and which is also where this lane got a reading
## wrong and had to correct it. Read that file's Atego section before changing any dimension here.
##
## THE TESSELLATION, stated so nobody subdivides it later (`modelling_here.md` section 4): every
## volume is a `Pressing.loft` of three or four cross-sections, a wheel is an EIGHT-SIDED PRISM, and
## nothing is round. Retessellating must not move a measured dimension.

const PRESSING := preload("res://objects/vehicles/road/pressing.gd")
const PLATING := preload("res://objects/vehicles/ships/plating.gd")
const ROAD_CAR := preload("res://objects/vehicles/road/road_car.gd")

## ---- the colours that are NOT the paint ---------------------------------------------------------
##
## The glass, the tyres and the hubs are the car's, because they are the same things and a second set
## of constants a shade apart is two numbers for one fact. See `RoadCar` for why the darks are kept
## apart, and for the harder half: **nothing here derives a colour from the paint.**
const GLASS := ROAD_CAR.GLASS
const TYRE := ROAD_CAR.TYRE
const HUB := ROAD_CAR.HUB
const UNDER := ROAD_CAR.UNDER
const LAMP := ROAD_CAR.LAMP
const TAIL_LAMP := ROAD_CAR.TAIL_LAMP
## The chassis frame, the fifth wheel and the underrun bars: bare steel, darker than any livery.
const FRAME := Color(0.155, 0.150, 0.150)
## A box body's skin, when it is not liveried: aluminium, lighter than the cab it stands behind, which
## is what most box bodies actually are and what makes the joint at the cab read.
const BOX := Color(0.74, 0.745, 0.75)
## The curtain on a curtainsider trailer, and the roll-up shutter at a box body's back.
const SHUTTER := Color(0.42, 0.43, 0.45)

## ---- the shape, as shares of something measured -------------------------------------------------
##
## THE CAB IS NARROWER THAN THE BODY, as a share of the vehicle's overall width. A 2.55 m body on a
## 2.35 m cab is what the step at the back of a lorry's cab measures; drawn flush the two volumes are
## one volume and item 1 at the top is gone.
const CAB_WIDE: float = 0.92
## HOW FAR THE CAB'S WINDSCREEN LEANS BACK, as a share of the cab's own length. A cabover's screen is
## nearly upright: 0.10 is about 8 degrees off vertical on the rigid, against a car's 61.
const SCREEN_RAKE: float = 0.10
## Where the glass starts on a cab, as a share of the cab's height over the road.
const CAB_BELT: float = 0.62
## How far the roof is drawn in from the flanks, and the nose from the front, so the corners are cut.
const CAB_DRAW: float = 0.94
## A twinned rear wheel: how far apart the two tyres of a pair sit, as a share of one tyre's width.
const TWIN_GAP: float = 1.25
## The frame rails, as a share of the overall width, and how deep they are drawn.
const FRAME_WIDE: float = 0.34
const FRAME_DEEP: float = 0.26


## ONE TRUCK, from its catalogue line. Origin on the road, centred along the OVERALL length of the
## whole vehicle -- for the artic that is the tractor and the trailer together -- with -Z forward.
static func build(row: Dictionary, paint: Color) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match StringName(row["body"]):
		&"van":
			_van(tool, row, paint)
		&"rigid":
			_rigid(tool, row, paint)
		&"artic":
			_artic(tool, row, paint)
		_:
			push_warning("[roadfleet] '%s' asks for a '%s' truck body and nothing draws one"
				% [row["name"], row["body"]])
			return null
	return PLATING.weld(tool)


## ---- the van ------------------------------------------------------------------------------------

## A PANEL VAN: one volume, cab and load space together, which is the whole difference between a van
## and a small lorry. The windscreen is raked like a car's because a van's is -- it has a short bonnet
## and the driver sits behind rather than over the front axle -- and the roof runs flat to the back
## doors at the full height.
##
## THE SHAPE IS FOUR CROSS-SECTIONS: a dropped nose, the foot of the windscreen, the top of the
## windscreen, and the back. The load box's own roof is the top face from the screen's top aft.
static func _van(tool: SurfaceTool, row: Dictionary, paint: Color) -> void:
	var length: float = float(row["length"])
	var half: float = float(row["width"]) * 0.5
	var height: float = float(row["height"])
	var nose: float = -length * 0.5
	var tail: float = length * 0.5
	var clearance: float = float(row["clearance"])
	var wheel: float = RoadFleet.wheel_diameter(row)
	var sill: float = wheel * ROAD_CAR.SILL_OF_WHEEL
	var belt: float = float(row["belt"])
	var front_axle: float = RoadFleet.front_axle(row)
	var rear_axle: float = RoadFleet.rear_axle(row)
	var arch: float = wheel * ROAD_CAR.ARCH_SPAN * 0.5
	# THE BONNET AND THE SCREEN, as fractions of the wheelbase back from the front axle, exactly as a
	# car's cabin stations are. A van's bonnet is short and its screen steep.
	var cowl: float = front_axle + float(row["cowl"]) * float(row["wheelbase"])
	var a_top: float = front_axle + float(row["a_top"]) * float(row["wheelbase"])

	var sections: Array[Dictionary] = [
		{"z": nose, "half": half * 0.84, "low": clearance + 0.05, "high": belt - 0.10},
		{"z": nose + 0.20, "half": half * 0.98, "low": clearance, "high": belt - 0.04},
		{"z": front_axle - arch, "half": half, "low": sill, "high": belt},
		# The cowl: the bonnet meets the screen, and the TOP over the next span IS the windscreen.
		{"z": cowl, "half": half, "low": sill, "high": belt, "top": GLASS},
		# The top of the screen. From here aft the body is at full height and the top is the roof.
		{"z": a_top, "half": half, "low": sill, "high": height},
		{"z": rear_axle + arch, "half": half, "low": sill, "high": height},
		{"z": tail - 0.10, "half": half, "low": clearance, "high": height},
		{"z": tail, "half": half * 0.99, "low": clearance, "high": height - 0.04, "back": SHUTTER},
	]
	PRESSING.loft(tool, sections, {"side": paint, "top": paint, "bottom": UNDER,
		"front": paint, "back": SHUTTER})
	# THE SIDE GLASS, as its own thin band on the cab's flanks only -- a van is glazed at the front
	# and blind behind, which is the second cue after its single volume.
	for across in [-1.0, 1.0]:
		PLATING.facing(tool, [
			Vector3(across * (half + 0.004), belt, cowl),
			Vector3(across * (half + 0.004), belt, a_top + 0.35),
			Vector3(across * (half + 0.004), belt + 0.52, a_top + 0.35),
			Vector3(across * (half + 0.004), belt + 0.52, cowl),
		], Vector3(across, 0.0, 0.0), GLASS)
	_rocker(tool, paint, half, clearance, sill, front_axle, rear_axle, wheel)
	axle(tool, row, front_axle, RoadFleet.track_front(row), false)
	axle(tool, row, rear_axle, RoadFleet.track_rear(row), false)
	lamps(tool, nose, tail, half, clearance + 0.30, belt - 0.16)


## ---- the rigid box lorry --------------------------------------------------------------------------

## A RIGID BOX LORRY: a cabover cab, a frame, and a box body standing on the frame behind it.
##
## **THE GEOMETRY IS THE ATEGO'S SPECIFICATION SHEET AND EVERY STATION IS PRINTED ON IT**, which makes
## this the best-sourced vehicle on the lane. Measured from the front of the vehicle:
##
##   0       the front fascia
##   180     the bumper datum the sheet's `H` is measured from -- see the warning below
##   1,620   the front axle (`D - A - C`, and 1,620 on all four of the sheet's wheelbases)
##   1,830   the cab's rear wall (`= front axle + I`, and `I` is a printed 210)
##   6,380   the drive axle (`= front axle + A`)
##   9,065   the end of the frame AND the overall length `D`, which land on the same millimetre
##
## **THE 180 mm IS AT THE FRONT AND THIS LANE FIRST PUT IT AT THE REAR.** `H + G` falls 180 mm short
## of the overall length on all four wheelbases, which is real -- and a residual that appears
## consistently tells you something is missing, NOT where it is. Read as a rear underrun bar it gives
## a cab rear 30 mm from the front axle, against the sheet's printed `I` of 210. Read as a front
## fascia it gives exactly 210 and closes the frame on the overall length. Six printed figures, and
## only one reading satisfies all six. `sources.md` has the table; do not "restore" the other reading.
##
## THE BOX BODY IS THEREFORE `G` LONG, 7,235 mm, which is PRINTED rather than derived -- and that is
## what `tests/road_vehicles.gd` holds the drawn body to. Nothing in this file knows the figure is
## being checked.
static func _rigid(tool: SurfaceTool, row: Dictionary, paint: Color) -> void:
	var length: float = float(row["length"])
	var half: float = float(row["width"]) * 0.5
	var nose: float = -length * 0.5
	var front_axle: float = RoadFleet.front_axle(row)
	var rear_axle: float = RoadFleet.rear_axle(row)
	var cab_rear: float = front_axle + float(row["cab_rear_behind_axle"])
	var frame_top: float = float(row["frame_height"])
	var cab_high: float = float(row["cab_height"])
	var wheel: float = RoadFleet.wheel_diameter(row)

	_cab(tool, row, paint, nose, cab_rear, half, cab_high, frame_top)
	_frame(tool, half, frame_top, cab_rear - 0.30, length * 0.5)
	# THE BODY: from the cab's rear wall to the end of the frame, which is the tail. Its floor is the
	# frame's top and its height is the catalogue's, so the overall height falls out rather than being
	# typed twice -- and the suite holds THAT against the 4.00 m legal maximum.
	var body_top: float = frame_top + float(row["body_depth"])
	PRESSING.loft(tool, [
		{"z": cab_rear, "half": half, "low": frame_top, "high": body_top},
		{"z": length * 0.5, "half": half, "low": frame_top, "high": body_top},
	] as Array[Dictionary], {"side": BOX, "top": BOX, "bottom": UNDER, "front": BOX,
		"back": SHUTTER})
	axle(tool, row, front_axle, RoadFleet.track_front(row), false)
	axle(tool, row, rear_axle, RoadFleet.track_rear(row), true)
	# THE REAR UNDERRUN BAR, which IS a real fitting on a real lorry even though it is not what the
	# 180 mm was: a bar under the tail, well below the body, required on every rigid over 3.5 t.
	PLATING.box(tool, Vector3(0.0, wheel * 0.55, length * 0.5 - 0.20),
		Vector3(half * 1.7, 0.14, 0.10), FRAME)
	lamps(tool, nose, length * 0.5, half, frame_top * 0.55, cab_high * 0.42)


## ---- the articulated vehicle -----------------------------------------------------------------------

## A TRACTOR UNIT AND ITS SEMI-TRAILER, drawn as ONE MESH because a parked artic is one shape.
##
## A traffic lane that wanted it to bend at the coupling would need two meshes and a hinge at the
## fifth wheel, and `fifth_wheel_at` below is where that hinge goes. This lane does not move anything,
## so it does not build one.
##
## THE COMBINATION IS MEASURED FROM THE TRACTOR'S FRONT. The trailer's kingpin sits over the tractor's
## drive axle and the trailer reaches back from there; the overall length is the tractor's front
## overhang plus the trailer's own length less the overlap, and the catalogue states it so the suite
## can hold it to the legal maximum without anything being fitted to one.
static func _artic(tool: SurfaceTool, row: Dictionary, paint: Color) -> void:
	var length: float = float(row["length"])
	var half: float = float(row["width"]) * 0.5
	var nose: float = -length * 0.5
	var front_axle: float = RoadFleet.front_axle(row)
	var drive_axle: float = front_axle + float(row["wheelbase"])
	var cab_rear: float = front_axle + float(row["cab_rear_behind_axle"])
	var frame_top: float = float(row["frame_height"])
	var cab_high: float = float(row["cab_height"])
	var deck: float = float(row["fifth_wheel"])
	var kingpin: float = drive_axle + float(row["kingpin_behind_drive"])
	var trailer_from: float = kingpin - float(row["kingpin_from_front"])
	var trailer_to: float = trailer_from + float(row["trailer_length"])
	var wheel: float = RoadFleet.wheel_diameter(row)

	_cab(tool, row, paint, nose, cab_rear, half, cab_high, frame_top)
	_frame(tool, half, frame_top, cab_rear - 0.30, drive_axle + 0.9)
	# THE FIFTH WHEEL: the plate the trailer rests on, over the drive axle.
	PLATING.box(tool, Vector3(0.0, deck - 0.06, kingpin), Vector3(half * 1.5, 0.12, 1.0), FRAME)
	# THE TRAILER, a curtainsided box on its own legs and bogie.
	var roof: float = deck + float(row["trailer_depth"])
	PRESSING.loft(tool, [
		{"z": trailer_from, "half": half, "low": deck, "high": roof},
		{"z": trailer_to, "half": half, "low": deck, "high": roof},
	] as Array[Dictionary], {"side": SHUTTER, "top": BOX, "bottom": UNDER, "front": BOX,
		"back": SHUTTER})
	# THE TRAILER'S BOGIE: two axles near its back, and the landing legs that hold the nose up when
	# it is dropped. Both are what tell a trailer from a lorry's body at any distance.
	var bogie: float = trailer_to - float(row["bogie_from_back"])
	for k in [0.0, 1.0]:
		axle(tool, row, bogie + k * float(row["bogie_spread"]), RoadFleet.track_rear(row), true)
	for across in [-1.0, 1.0]:
		PLATING.box(tool, Vector3(across * half * 0.62, deck * 0.5, trailer_from + 1.6),
			Vector3(0.14, deck, 0.18), FRAME)
	axle(tool, row, front_axle, RoadFleet.track_front(row), false)
	axle(tool, row, drive_axle, RoadFleet.track_rear(row), true)
	lamps(tool, nose, trailer_to, half, frame_top * 0.55, cab_high * 0.42)


## WHERE A TRAILER'S KINGPIN IS, in the vehicle's own frame: the hinge an articulating traffic lane
## would put its coupling at, published so nothing has to work it out from the drawing.
static func fifth_wheel_at(row: Dictionary) -> Vector3:
	if not row.has("kingpin_behind_drive"):
		return Vector3.ZERO
	var drive_axle: float = RoadFleet.front_axle(row) + float(row["wheelbase"])
	return Vector3(0.0, float(row["fifth_wheel"]), drive_axle + float(row["kingpin_behind_drive"]))


## ---- the pieces every truck is made of --------------------------------------------------------------

## A CABOVER CAB: four cross-sections from the fascia to the rear wall, with a nearly upright
## windscreen. It stands on the frame and reaches down past it to the bumper.
static func _cab(tool: SurfaceTool, row: Dictionary, paint: Color, nose: float, cab_rear: float,
		half: float, cab_high: float, frame_top: float) -> void:
	var cab_half: float = half * CAB_WIDE
	var belt: float = cab_high * CAB_BELT
	var run: float = cab_rear - nose
	var screen: float = nose + run * SCREEN_RAKE
	var low: float = float(row["clearance"])
	PRESSING.loft(tool, [
		# The fascia and the bumper, drawn in at the corners.
		{"z": nose, "half": cab_half * 0.90, "low": low + 0.06, "high": belt, "top": GLASS},
		# The foot of the windscreen. The TOP over the next span is the glass, and because the rake is
		# only a tenth of the cab's length that quad is nearly vertical, which is what a cabover has.
		# NO `side` OVERRIDE HERE. It carried GLASS at first, meaning "the side windows are along this
		# span" -- but a loft's flank runs the FULL HEIGHT of its section, so it glazed the cab from
		# the windscreen down to 225 mm over the road, and the suite duly reported a lorry glazed at
		# its own axle line. The side windows are their own band, drawn below.
		{"z": screen, "half": cab_half, "low": low, "high": cab_high},
		{"z": screen + run * 0.18, "half": cab_half, "low": low, "high": cab_high},
		{"z": cab_rear, "half": cab_half * CAB_DRAW, "low": frame_top, "high": cab_high},
	] as Array[Dictionary], {"side": paint, "top": paint, "bottom": UNDER, "front": paint,
		"back": paint})
	# THE SIDE WINDOWS, a band on each flank of the cab behind the screen.
	for across in [-1.0, 1.0]:
		PLATING.facing(tool, [
			Vector3(across * (cab_half + 0.004), belt, screen + run * 0.10),
			Vector3(across * (cab_half + 0.004), belt, cab_rear - run * 0.10),
			Vector3(across * (cab_half + 0.004), cab_high - 0.22, cab_rear - run * 0.10),
			Vector3(across * (cab_half + 0.004), cab_high - 0.22, screen + run * 0.10),
		], Vector3(across, 0.0, 0.0), GLASS)


## THE CHASSIS FRAME: two rails from behind the cab to the back, at the frame height. A box body with
## nothing under it floats; this is what it stands on.
static func _frame(tool: SurfaceTool, half: float, frame_top: float, from: float,
		to: float) -> void:
	if to <= from:
		return
	for across in [-1.0, 1.0]:
		PLATING.box(tool, Vector3(across * half * FRAME_WIDE, frame_top - FRAME_DEEP * 0.5,
			(from + to) * 0.5), Vector3(0.12, FRAME_DEEP, to - from), FRAME)


## ONE AXLE'S WHEELS, twinned or not. A lorry's drive axle carries two tyres a side, and from behind
## or from the air that pair is the clearest single thing that separates a lorry from a large van.
##
## PUBLIC, because `RoadBus` needs the same thing: a bus's drive axle is twinned and its steer axle
## is not, which is a lorry's arrangement exactly. A second copy a shade different would be two
## definitions of one fact, and this file is where the fact already lives.
static func axle(tool: SurfaceTool, row: Dictionary, at: float, track: float,
		twinned: bool) -> void:
	var diameter: float = RoadFleet.wheel_diameter(row)
	var wide: float = RoadFleet.wheel_width(row)
	for across in [-1.0, 1.0]:
		var middle: float = across * track * 0.5
		var places: Array = [middle]
		if twinned:
			places = [middle - across * wide * TWIN_GAP * 0.5,
				middle + across * wide * TWIN_GAP * 0.5]
		for x in places:
			PRESSING.wheel(tool, Vector3(float(x), diameter * 0.5, at), diameter, wide, TYRE, HUB)


## The rocker between the arches, as a car has one. Only the van wants it: a lorry's frame and its
## running gear are what fill that space, and they are drawn.
static func _rocker(tool: SurfaceTool, paint: Color, half: float, clearance: float, sill: float,
		front_axle: float, rear_axle: float, wheel: float) -> void:
	var arch: float = wheel * ROAD_CAR.ARCH_SPAN * 0.5
	var from: float = front_axle + arch
	var to: float = rear_axle - arch
	if to <= from or sill <= clearance:
		return
	PRESSING.loft(tool, [
		{"z": from, "half": half * ROAD_CAR.ROCKER_IN, "low": clearance, "high": sill,
			"open": true},
		{"z": to, "half": half * ROAD_CAR.ROCKER_IN, "low": clearance, "high": sill},
	] as Array[Dictionary], {"side": paint, "top": paint, "front": paint, "back": paint,
		"bottom": UNDER})


## HEAD AND TAIL LAMPS. Set 8 mm inside the ends rather than flush, for the reason `RoadCar._ends`
## gives: two coplanar faces z-fight and it shows as a sawtooth. PUBLIC for `RoadBus`, as `axle` is.
static func lamps(tool: SurfaceTool, nose: float, tail: float, half: float, low: float,
		high: float) -> void:
	for end in [[nose, -1.0, LAMP], [tail, 1.0, TAIL_LAMP]]:
		var z: float = float(end[0]) - float(end[1]) * 0.008
		for across in [-1.0, 1.0]:
			var middle: float = across * half * 0.62
			PLATING.facing(tool, [
				Vector3(middle - 0.19, low, z), Vector3(middle + 0.19, low, z),
				Vector3(middle + 0.19, high, z), Vector3(middle - 0.19, high, z),
			], Vector3(0.0, 0.0, float(end[1])), end[2])
