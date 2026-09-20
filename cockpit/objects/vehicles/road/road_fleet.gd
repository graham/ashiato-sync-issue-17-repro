@tool
extends RefCounted
class_name RoadFleet
## EVERY ROAD VEHICLE IN THE GAME, AND EVERY DIMENSION OF IT: one line per type, and the one place
## anything is allowed to know how big a car is.
##
## THESE ARE PICTURES AND NEVER THINGS. Not a kind, not an entry in `cockpit_kinds.inc`, no C++, no
## collision box, no wire, no seat, nothing the simulation ticks -- the user's own constraint on
## 2026-09-19: *"Make sure they don't think about physics, they are not craft so don't build KIND or
## make them part of the physics simulation, but let's just create models for them, we can place them
## as meshes in the levels."* They are in the same family as `Forests`' trees, which that file gets to
## call "a picture and never a thing" because an aeroplane flying through a wood is a choice somebody
## can defend. An aeroplane flying through a parked hatchback is the same choice and an easier one.
##
## There IS already a drivable `car` KIND in this game (`craft/car`, kind 3, with a steering wheel and
## a seat). **Nothing here touches it, extends it or is modelled against it.** A road vehicle from
## this catalogue cannot be flown, driven, boarded, hit or networked; it stands where a level put it.
##
## WHERE THE NUMBERS COME FROM: `cockpit/craft/road/sources.md`, with a URL and a datum for every one
## and the tag `modelling_here.md` section 3 asks for -- PUBLISHED, MEASURED or ESTIMATE. The two best
## sources on the lane are manufacturers' own specification sheets whose dimension tables ADD UP TO
## THEIR OWN OVERALL LENGTH, so each audits itself; `overhangs_close` below holds this table to the
## same standard.
##
## ONE NUMBER, ONE PLACE (CLAUDE.md rule 4), and it is worth saying which numbers are NOT in the
## table because they are computed from the ones that are:
##
## - **The rear overhang.** `length - wheelbase - front_overhang`. Typed beside the other three it
##   would be a fourth number free to disagree with them, which is what a drawn vehicle looks like
##   when its wheels are in the wrong place: right size, wrong stance, and every dimension check green.
## - **The track**, front and rear, as a share of the overall width. One ESTIMATE in one place rather
##   than eight typed numbers, and it is the softest figure on the lane -- see `sources.md`.
## - **The wheel diameter**, from the tyre size, by the published ISO formula (`Pressing.tyre`). The
##   fitment is what has to be justified; the arithmetic does not.
## - **The axle positions**, from the overhangs. Nothing may type where a wheel goes.
##
## HOW A LEVEL ASKS FOR ONE: `RoadFleet.mesh(type, paint)` for the drawn thing and `RoadFleet.pose`
## for where it stands. `world/road_vehicles.gd` is what actually puts them on a `SceneryYard` layer.
##
## **NOTHING HERE MOVES THEM, AND THAT IS DELIBERATE.** The user asked for "something we can simulate
## cars and traffic with" and this is the half that can be built without a simulation: shapes with
## real sizes, and a pose that takes a point and a heading. A lane that wants moving traffic needs
## three things this one does not build -- a route graph off `TownPlan.roads()` and `TownPlan.streets()`,
## a per-vehicle state to step, and a MultiMesh whose buffer is rewritten per frame rather than per
## cell, which is a different thing from the yard's per-cell batches. `pose` is the seam it would use.

const PRESSING := preload("res://objects/vehicles/road/pressing.gd")
const ROAD_CAR := preload("res://objects/vehicles/road/road_car.gd")
const ROAD_LORRY := preload("res://objects/vehicles/road/road_lorry.gd")
const ROAD_BUS := preload("res://objects/vehicles/road/road_bus.gd")

## ---- the shares that are ESTIMATE, in one place each -------------------------------------------
##
## TRACK AS A SHARE OF OVERALL WIDTH. ESTIMATE, and the softest number on the lane. Reasoned from the
## ONE published pair that turned up for any of these four types -- a Golf Mk8 GTI at 1,535 mm front
## and 1,513 rear against the Golf's 1,789 mm overall width, which is 0.858 and 0.846. It is a single
## ratio carried to three other cars and it is NOT a fitted trend; `modelling_here.md` section 3 is
## explicit that fitting through two ends is how `lane/prowler` lost its best finding of the morning,
## so this does not pretend to be a fit at all.
##
## WHAT THE SUITE CHECKS INSTEAD, because it must not assert a number nothing published supports: that
## the drawn tyres fall INBOARD of the drawn body and stand under their arches. That catches a wrong
## ratio in the direction that actually looks wrong -- wheels sticking out of the flanks -- without
## claiming to know the track to a millimetre.
const TRACK_FRONT_SHARE: float = 0.855
const TRACK_REAR_SHARE: float = 0.845

## THE TRACK SHARES A LORRY USES INSTEAD, and they are not the car's.
##
## A lorry is built to the legal maximum WIDTH and its axles are not: a 2.55 m body carries a steer
## track of about 2.05 m, which is 0.80 rather than the car's 0.855, and a TWINNED drive axle is
## narrower again between the centres of its two pairs because each pair is nearly 0.75 m across.
## Carrying the car's ratio onto a lorry put the outer tyre of each drive pair 132 mm OUTSIDE the
## body -- which the drawn-tyres-inboard check catches, and which is the whole reason that check
## exists in place of asserting a track figure.
const TRUCK_TRACK_FRONT_SHARE: float = 0.80
const TRUCK_TRACK_REAR_SHARE: float = 0.706


## ---- the catalogue -----------------------------------------------------------------------------
##
## `family` picks the builder. `tyre` is `[section mm, aspect per cent, rim inches]` and the diameter
## comes out of it; see `sources.md` for why each fitment was chosen and how weakly.
##
## The four cabin stations are fractions of the WHEELBASE measured back from the FRONT AXLE, which is
## the frame a car's proportions actually live in -- a cowl quoted from the nose moves when the front
## bumper changes and the cabin has not. All four are ESTIMATE; they are what makes a hatchback read
## as a hatchback rather than as a saloon, and no source read gives them:
##
##   cowl       where the bonnet meets the windscreen
##   a_top      the top of the windscreen -- the front of the roof
##   c_top      the back of the roof
##   backlight  the foot of the rear glass
##
## `belt` is the waist: where the body's sheet metal stops and the glass starts, in metres over the
## road. `clearance` is the underside of the body, likewise.
const TYPES: Array[Dictionary] = [
	# A C-SEGMENT HATCHBACK. PUBLISHED off the VW Golf Mk8: 4,284 x 1,789 x 1,456 on a 2,636 wheelbase.
	# The wheelbase corrected the lane's own step 0 figure of 2,620 before a line of geometry was written.
	{"name": &"hatchback", "family": &"car",
		"length": 4.284, "width": 1.789, "height": 1.456, "wheelbase": 2.636,
		"front_overhang": 0.875, "tyre": [205.0, 55.0, 16.0],
		"clearance": 0.145, "belt": 0.960,
		"cowl": 0.30, "a_top": 0.64, "c_top": 1.13, "backlight": 1.24,
		"bed": false, "paint": Color(0.62, 0.64, 0.66)},
	# A D-SEGMENT SALOON. PUBLISHED off the BMW 3 Series G20: 4,709 x 1,827 x 1,442 on a 2,851
	# wheelbase. The height corrected 1,435 to 1,442 from the same source.
	{"name": &"saloon", "family": &"car",
		"length": 4.709, "width": 1.827, "height": 1.442, "wheelbase": 2.851,
		"front_overhang": 0.900, "tyre": [225.0, 50.0, 17.0],
		"clearance": 0.140, "belt": 0.955,
		"cowl": 0.34, "a_top": 0.65, "c_top": 0.95, "backlight": 1.09,
		"bed": false, "paint": Color(0.14, 0.15, 0.17)},
	# A MID-SIZE CROSSOVER. PUBLISHED off the Toyota RAV4 XA50: 4,635 x 1,855 on a 2,690 wheelbase.
	# HEIGHT IS THE ONE CHOICE HERE: the source gives 1,680-1,735, and the spread is roof rails and
	# trim rather than body. 1.685 is the bottom of it plus 5 mm, because a drawn roof rail is well
	# under a pixel at any distance these are seen from and the BODY is what the silhouette is.
	{"name": &"suv", "family": &"car",
		"length": 4.635, "width": 1.855, "height": 1.685, "wheelbase": 2.690,
		"front_overhang": 0.960, "tyre": [225.0, 65.0, 17.0],
		"clearance": 0.195, "belt": 1.075,
		"cowl": 0.30, "a_top": 0.60, "c_top": 1.18, "backlight": 1.30,
		"bed": false, "paint": Color(0.30, 0.33, 0.38)},
	# A FULL-SIZE CREW-CAB PICKUP. PUBLISHED off the Ford F-150 14th generation, SuperCrew: the source
	# gives 5,885-6,185 long on a 3,693-3,993 wheelbase, and THE TWO MOVE TOGETHER because they are the
	# 5.5 ft and the 6.5 ft bed. The SHORT BED is taken, and naming the configuration is the whole of
	# the discipline -- a published dimension has a datum and a range is not one.
	#
	# AND `backlight` IS CHOSEN SO THE DRAWN BED FLOOR COMES OUT AT THE PUBLISHED 5.5 FT, rather than
	# typed from a shape somebody liked: the cab's rear wall at 0.82 wheelbases leaves **1.6617 m** of
	# floor between its liner and the tailgate, against a published 1.6764 m (5 ft 6 in), 0.87 per cent
	# under. That is `Boxcar.SILL_OVER_RAIL`'s trick -- a soft number set so that a hard one it does not
	# know about comes out right -- and `tests/road_vehicles.gd` reads the floor's length off the DRAWN
	# vertices and holds it to 5 ft 6 in, knowing nothing of this line.
	#
	# THE FIRST TRY AT IT WAS 0.90 AND THE CHECK IS WHAT SAID SO. At 0.90 the cab's rear wall left a
	# 1.366 m floor -- the figure that landed on 5 ft 6 in was `tail - backlight`, which is the bed
	# OPENING plus the tailgate and the rear bumper behind it, and is not what a bed length means. A
	# published dimension has a datum: 5 ft 6 in is the floor you can put a pallet on.
	{"name": &"pickup", "family": &"car",
		"length": 5.885, "width": 2.029, "height": 1.961, "wheelbase": 3.693,
		"front_overhang": 0.900, "tyre": [265.0, 70.0, 17.0],
		"clearance": 0.235, "belt": 1.230,
		"cowl": 0.23, "a_top": 0.48, "c_top": 0.78, "backlight": 0.82,
		"bed": true, "paint": Color(0.52, 0.16, 0.14)},

	# ---- the trucks ------------------------------------------------------------------------------
	#
	# A PANEL VAN. PUBLISHED off the Ford Transit L3 (long wheelbase): 5,980 mm long on a 3,750 mm
	# wheelbase. WIDTH IS THE BODY AND NOT THE MIRRORS -- the source's 2,052-2,126 spread is single
	# against dual rear wheels, and a van's mirrors add about 350 mm a side, which quoted as width
	# would make it wider than a heavy lorry may legally be. HEIGHT is the medium roof (H2) taken out
	# of a published 2,088-3,051 range that spans three roofs: ESTIMATE within a PUBLISHED range, and
	# the shape that reads as a van rather than as a minibus or a Luton.
	{"name": &"van", "family": &"truck", "body": &"van",
		"length": 5.980, "width": 2.052, "height": 2.550, "wheelbase": 3.750,
		"front_overhang": 1.000, "tyre": [235.0, 65.0, 16.0],
		"clearance": 0.190, "belt": 1.180,
		"cowl": 0.02, "a_top": 0.46,
		"bed": false, "paint": Color(0.86, 0.87, 0.88)},
	# A RIGID BOX LORRY, 15 t GVW. **THE BEST-SOURCED VEHICLE ON THE LANE**: Mercedes-Benz's own UK
	# specification sheet for the Atego 4x2 rigid, model 1524, which prints six dimensions that close
	# on one another exactly. See `RoadLorry._rigid` for the station list and `craft/road/sources.md`
	# for the reading that had to be corrected -- the 180 mm is at the FRONT.
	#
	# HEIGHT IS NOT TYPED: it is the frame plus the body, and the suite holds the DRAWN result under
	# the 4.00 m legal maximum. A box body is fitted by a bodybuilder and no maker publishes an
	# overall height for one, so there is nothing to type even if it were wanted.
	{"name": &"boxlorry", "family": &"truck", "body": &"rigid",
		"length": 9.065, "width": 2.550, "height": 3.555, "wheelbase": 4.760,
		"front_overhang": 1.620, "tyre": [315.0, 80.0, 22.5],
		"clearance": 0.225, "frame_height": 0.955,
		"cab_rear_behind_axle": 0.210, "cab_height": 2.850, "body_depth": 2.600,
		"track_front_share": 0.80, "track_rear_share": 0.706,
		"bed": false, "paint": Color(0.18, 0.34, 0.52)},
	# AN ARTICULATED VEHICLE: a 4x2 cabover tractor and a 13.60 m curtainsided semi-trailer, drawn as
	# ONE mesh because a parked artic is one shape. `RoadLorry.fifth_wheel_at` publishes the coupling
	# for a lane that wants it to bend; this one does not move it.
	#
	# THE TRAILER IS THE PUBLISHED PART AND THE TRACTOR IS THE ESTIMATED PART, which is the opposite
	# of what you would guess: "almost all European semi-trailers are 13.60 m" and the kingpin's
	# 1,700 mm setting is standard, while the tractor's wheelbase and front overhang are the middle
	# of Volvo FH published ranges (3,500-3,800 and 5,880-6,180 chassis).
	#
	# **AND THE KINGPIN SET-BACK IS A CONSTRAINT, NOT A CHECK.** 0.520 m is what makes the combination
	# 16.480 m and so legal, which is exactly how a haulier specs a tractor -- so the 16.5 m maximum
	# is a figure this line was FITTED TO and must never be quoted as a cross-check of it. What IS an
	# independent check is the kingpin-to-rear distance: 13.600 less 1.700 is 11.900 m against a
	# published 12.500 m maximum, published in and published out, with nothing of this lane's in it.
	{"name": &"artic", "family": &"truck", "body": &"artic",
		"length": 16.480, "width": 2.550, "height": 3.900, "wheelbase": 3.650,
		"front_overhang": 1.450, "tyre": [315.0, 80.0, 22.5],
		"clearance": 0.225, "frame_height": 0.980,
		"cab_rear_behind_axle": 0.260, "cab_height": 3.600,
		"fifth_wheel": 1.150, "kingpin_behind_drive": -0.520, "kingpin_from_front": 1.700,
		"trailer_length": 13.600, "trailer_depth": 2.750,
		"bogie_from_back": 2.300, "bogie_spread": 1.310,
		"track_front_share": 0.80, "track_rear_share": 0.706,
		"bed": false, "paint": Color(0.64, 0.20, 0.17)},

	# ---- the buses -------------------------------------------------------------------------------
	#
	# A 12 m LOW-FLOOR CITY BUS. PUBLISHED off the Mercedes-Benz Citaro O530: 12,135 x 2,550 x 3,120
	# on a 5,900 mm wheelbase.
	#
	# **THIS IS THE WORST-SOURCED VEHICLE ON THE LANE AND THE SPREAD IS RECORDED RATHER THAN HIDDEN.**
	# Three sources give the "12 m Citaro" as 12,135, 12,135 and 11,950 mm long and 3,130, 3,120 and
	# 3,076 mm high. That is not three people measuring one bus badly: a 12 m Citaro is BUILT in
	# several lengths and several roof heights, and "the 12 m one" does not name a vehicle. The
	# infobox figure is taken and the 185 mm of length and 54 mm of height are the uncertainty.
	#
	# THE WIDTH DOES NOT MOVE. 2,550 on every source, because that is the legal maximum and a city bus
	# is built to it -- which the Volvo coach below confirms from an unrelated maker's own sheet.
	#
	# `glass_floor` 0.72 is what makes it a LOW-FLOOR bus: the deck is 400 mm over the road and the
	# glass comes down nearly to the skirt, so there is no luggage band. Compare the coach.
	{"name": &"citybus", "family": &"bus", "body": &"bus",
		"length": 12.135, "width": 2.550, "height": 3.120, "wheelbase": 5.900,
		"front_overhang": 2.700, "tyre": [275.0, 70.0, 22.5],
		"clearance": 0.230, "glass_floor": 0.720, "screen_deep": 1.05,
		"rear_overhang_draw": 0.700, "doors": 2,
		"track_front_share": 0.80, "track_rear_share": 0.706,
		"bed": false, "paint": Color(0.72, 0.28, 0.12)},
	# A TOURING COACH. **The second-best-sourced vehicle on the lane**, from Volvo's own data sheet for
	# the 9700 12.4 m 4x2 Euro 6: 12,400 long, 2,550 wide, 3,650 high with air conditioning, on a
	# 6,170 wheelbase with 2,895 of front overhang and 3,335 of rear.
	#
	# **ITS DIMENSION TABLE CLOSES ON ITSELF: 2,895 + 6,170 + 3,335 = 12,400 exactly.** And the 15.0 m
	# sheet in the same family prints the SAME 2,895 front overhang, which is a second, independent
	# confirmation of the one figure a coach's nose shape depends on most.
	#
	# `glass_floor` 1.42 is the luggage hold. It is the single number that separates this from the
	# city bus above, and it is an ESTIMATE: no source read gives a coach's window sill height, but a
	# 9700's hold is quoted at 7.9-8.8 cubic metres, which over a 2.4 m usable width and 8 m of length
	# wants very nearly this much depth. Tagged in `sources.md` for what it is.
	{"name": &"coach", "family": &"bus", "body": &"bus",
		"length": 12.400, "width": 2.550, "height": 3.650, "wheelbase": 6.170,
		"front_overhang": 2.895, "tyre": [315.0, 80.0, 22.5],
		"clearance": 0.260, "glass_floor": 1.420, "screen_deep": 1.35,
		"rear_overhang_draw": 0.900, "doors": 1,
		"track_front_share": 0.80, "track_rear_share": 0.706,
		"bed": false, "paint": Color(0.22, 0.30, 0.55)},
]


## ---- reading the catalogue ---------------------------------------------------------------------

## THE LINE FOR `type`, or an empty Dictionary and a warning. A name nobody has is a caller's
## mistake and not half a vehicle (CLAUDE.md rule 7: a malformed item disables itself with a message).
static func line(type: StringName) -> Dictionary:
	for row in TYPES:
		if StringName(row["name"]) == type:
			return row
	push_warning("[roadfleet] no such road vehicle as '%s'; the catalogue has %s" % [type, names()])
	return {}


## Every type's name, in catalogue order. Read this; never type a roster beside it.
static func names() -> Array[StringName]:
	var out: Array[StringName] = []
	for row in TYPES:
		out.append(StringName(row["name"]))
	return out


## THE REAR OVERHANG, computed and never typed: what is left of the length once the wheelbase and the
## front overhang have had their share. The Atego's own specification sheet never prints its front
## overhang either -- it falls out of the other three the same way, at 1,620 mm on all four of its
## wheelbases, and four arithmetic routes to one figure is better evidence than one printed number.
static func rear_overhang(row: Dictionary) -> float:
	return float(row["length"]) - float(row["wheelbase"]) - float(row["front_overhang"])


## WHERE THE FRONT AND REAR AXLES ARE, in the vehicle's own frame: z along the vehicle with -Z
## forward, and the origin at the middle of the OVERALL LENGTH on the road surface. See `mesh`.
static func front_axle(row: Dictionary) -> float:
	return -float(row["length"]) * 0.5 + float(row["front_overhang"])


static func rear_axle(row: Dictionary) -> float:
	return float(row["length"]) * 0.5 - rear_overhang(row)


## THE TRACK, front and rear: a share of the overall width, from the one place each share lives. A
## line may name its own shares -- the trucks do, because a lorry's axles sit very differently inside
## a body built to the legal maximum than a car's do inside a body that is not.
##
## EVERY OPTIONAL TAKES ITS DEFAULT AT ITS OWN CALL SITE (CLAUDE.md rule 8), which is why these read
## the constant rather than letting a missing key fall through to zero: a track of nought is four
## wheels on the centreline, and it would look like one wheel and count as four.
static func track_front(row: Dictionary) -> float:
	return float(row["width"]) * float(row.get("track_front_share", TRACK_FRONT_SHARE))


static func track_rear(row: Dictionary) -> float:
	return float(row["width"]) * float(row.get("track_rear_share", TRACK_REAR_SHARE))


## THE TYRE'S OVERALL DIAMETER, from the fitment in the catalogue by the published ISO formula.
static func wheel_diameter(row: Dictionary) -> float:
	var size: Array = row["tyre"]
	return PRESSING.tyre(float(size[0]), float(size[1]), float(size[2]))


## A TYRE'S WIDTH IS THE FIRST NUMBER OF ITS OWN SIZE, in millimetres, and nothing else. A 205/55 R16
## is 205 mm across.
##
## IT WAS A SHARE OF THE DIAMETER -- 0.32, an ESTIMATE -- until the trucks arrived and it became
## obvious there was no need for one: the section width is PUBLISHED, it is sitting in the same
## triple the diameter is derived from, and deriving a width from a diameter when the width is the
## input is an estimate standing where a fact already was. On the cars it moves nothing (0.202 m
## against a published 0.205); on a 315/80 R22.5 it corrects 0.344 m to 0.315.
static func wheel_width(row: Dictionary) -> float:
	return float((row["tyre"] as Array)[0]) * 0.001


## WHETHER A LINE'S OWN DIMENSIONS CLOSE, the way a manufacturer's specification sheet does: front
## overhang plus wheelbase plus rear overhang is the overall length, and every part of it is positive.
##
## IT CANNOT FAIL WHILE `rear_overhang` IS A SUBTRACTION -- and it is here anyway, because the day
## somebody types a rear overhang into the table is the day it starts being able to, and a check that
## only begins to bite when the bug is introduced is the check you want in place beforehand. What it
## DOES catch today is a front overhang longer than the whole vehicle, which is a typo away.
static func overhangs_close(row: Dictionary) -> bool:
	var rear: float = rear_overhang(row)
	if float(row["front_overhang"]) <= 0.0 or rear <= 0.0 or float(row["wheelbase"]) <= 0.0:
		return false
	var sum: float = float(row["front_overhang"]) + float(row["wheelbase"]) + rear
	return absf(sum - float(row["length"])) < 0.0005


## ---- the mesh ----------------------------------------------------------------------------------

## The meshes built so far, keyed by type and paint. A street of forty hatchbacks in six colours is
## six meshes and forty instances, not forty meshes.
##
## ONE MESH PER (TYPE, PAINT) IS A STEP-1 DECISION AND IS WRITTEN DOWN AS ONE. Colour is in the
## vertices, so a different paint is a different mesh; the alternative -- one mesh a type with the
## paint in `INSTANCE_CUSTOM` and a shader that tints only the panels and leaves the glass, tyres and
## lamps alone, as `TownView` does for a building's windows -- is the right answer for a hundred cars
## and belongs with the budget measurement that justifies it, not before it.
static var _built: Dictionary = {}


## ONE VEHICLE'S MESH. **Its origin is ON THE ROAD SURFACE, centred along its overall length, with -Z
## forward.**
##
## The road surface rather than the body's middle, because everything that places one of these places
## it on the ground: a model that carries its own heights in its own frame needs no lift at all, and a
## lift is a number that ends up typed in two files and disagreeing with itself. The boxcar's origin is
## on the railhead for the same reason. The suite checks the lowest drawn point is y = 0 to a
## millimetre, which is the tyres' contact patch and nothing else.
static func mesh(type: StringName, paint: Color = Color(0, 0, 0, 0)) -> ArrayMesh:
	var row: Dictionary = line(type)
	if row.is_empty():
		return null
	var tint: Color = paint if paint.a > 0.0 else Color(row["paint"])
	var key: String = "%s|%08x" % [type, tint.to_rgba32()]
	if not _built.has(key):
		_built[key] = build(row, tint)
	return _built[key]


## BUILD ONE, from its catalogue line. `family` picks the builder, so a new body style is a line here
## and a builder there and nothing else changes.
static func build(row: Dictionary, paint: Color) -> ArrayMesh:
	match StringName(row["family"]):
		&"car":
			return ROAD_CAR.build(row, paint)
		&"truck":
			return ROAD_LORRY.build(row, paint)
		&"bus":
			return ROAD_BUS.build(row, paint)
	push_warning("[roadfleet] '%s' asks for a '%s' body and nothing draws one"
		% [row["name"], row["family"]])
	return null


## ---- where one stands ---------------------------------------------------------------------------

## A VEHICLE STANDING AT `at` WITH ITS NOSE ALONG `heading`, its wheels on the ground.
##
## `heading` is radians in the sense a vehicle's yaw is quoted in here, so it goes through
## `Terrain.nose_from_yaw` exactly as a craft's does and a vehicle and an aeroplane given the same
## number point the same way. `at` is a point ON THE ROAD: the mesh's origin is already there, so this
## adds no lift and has no height in it to get wrong.
##
## THIS IS THE SEAM A MOVING-TRAFFIC LANE WOULD USE, and it is the only concession this lane makes to
## one. Called once when a street is built, it parks a car; called once a frame with a distance along
## a route, it drives one. Nothing here does the second.
static func pose(at: Vector3, heading: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, heading), at)
