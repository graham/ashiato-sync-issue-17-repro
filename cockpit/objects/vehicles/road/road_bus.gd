@tool
extends RefCounted
class_name RoadBus
## THE TWO BUSES: a low-floor city bus and a touring coach.
##
## WHAT SEPARATES THEM, and it is not size -- they are within 265 mm of each other in length and
## identical in width. A coach and a city bus are **the same box at two different heights off the
## road**, and every cue follows from that one fact:
##
## 1. **THE COACH'S FLOOR IS RAISED OVER A LUGGAGE HOLD; THE CITY BUS'S IS NOT.** A coach carries
##    bags under its passengers in a bay that runs most of its length between the axles, so its
##    windows start high and there is a deep blank band beneath them. A low-floor city bus has its
##    floor 400 mm over the road -- that is the whole point of one -- so its glass comes down almost
##    to its skirt and there is no band at all. Drawn without the band a coach IS a city bus.
## 2. **THE CITY BUS HAS DOORS IN ITS SIDE AND THE COACH HAS ONE AT THE FRONT.** Two wide doorways
##    breaking the glass line is what a bus looks like from a pavement, and a coach has an entrance
##    ahead of its front axle and nothing else.
## 3. **THE COACH'S WINDSCREEN IS DEEP AND RAKED; THE CITY BUS'S IS UPRIGHT AND SHALLOW.**
## 4. **NEITHER HAS A BONNET.** Both are rear-engined with the driver over the front axle, so the
##    nose is a flat panel with a screen above it -- which is why a car's cabin stations mean nothing
##    here and these are drawn from their own overhangs instead.
##
## THE NUMBERS: `cockpit/craft/road/sources.md`. The coach's are the second-best set on the lane --
## Volvo's own data sheet for the 9700 12.4 m, whose overhangs and wheelbase add up to its printed
## overall length exactly (2,895 + 6,170 + 3,335 = 12,400). The city bus's are the WORST set on the
## lane, and it is worth knowing which: three sources give the "12 m Citaro" three different lengths
## and four different heights, because it is built in several of each.
##
## **THE ONE THING BOTH AGREE ON IS 2,550 mm ACROSS**, from two unrelated manufacturers' own sheets,
## which is exactly the legal maximum. A bus is built to the width it is allowed and no further.
##
## THE TESSELLATION (`modelling_here.md` section 4): every volume is a `Pressing.loft` of three or
## four cross-sections, a wheel is an EIGHT-SIDED PRISM, and nothing is round.

const PRESSING := preload("res://objects/vehicles/road/pressing.gd")
const PLATING := preload("res://objects/vehicles/ships/plating.gd")
const ROAD_CAR := preload("res://objects/vehicles/road/road_car.gd")
const ROAD_LORRY := preload("res://objects/vehicles/road/road_lorry.gd")

## The shared parts, from the files that already own them -- see `RoadLorry` for why there is not a
## second set of constants a shade apart.
const GLASS := ROAD_CAR.GLASS
const TYRE := ROAD_CAR.TYRE
const HUB := ROAD_CAR.HUB
const UNDER := ROAD_CAR.UNDER
const LAMP := ROAD_CAR.LAMP
const TAIL_LAMP := ROAD_CAR.TAIL_LAMP
const FRAME := ROAD_LORRY.FRAME
## A door leaf: darker than any livery and lighter than the glass, so a doorway reads as an opening
## rather than as a window or a hole.
const DOOR := Color(0.245, 0.250, 0.262)
## The skirt below the glass line, and a coach's luggage-bay doors along it.
const SKIRT := Color(0.325, 0.330, 0.340)

## ---- the shape, as shares of something measured -------------------------------------------------
##
## HOW DEEP THE GLASS BAND IS, as a share of the vehicle's height: the same for both, because a
## passenger's head needs the same room whatever it is sitting in. What differs is where the band
## STARTS, which is item 1 at the top and is the catalogue's `glass_floor`.
const GLAZING_DEEP: float = 0.30
## How far the roof is drawn in from the flanks, and the nose from the front. A bus's corners are
## cut but barely -- it is built to the legal width and there is nothing to spare.
const ROOF_DRAW: float = 0.97
const NOSE_DRAW: float = 0.93
## How far back the nose reaches before the body is at full width, as a share of the front overhang.
const NOSE_ALONG: float = 0.30
## A door's width and how far the pair are set along the body, as shares of the wheelbase.
const DOOR_WIDE: float = 0.20
## The skirt: how far below the glass the painted panel runs before the underfloor begins.
const SKIRT_DOWN: float = 0.20

## **HOW FAR THE GLAZING STANDS PROUD OF THE PILLARS BEHIND IT -- AND THE BODY IS DRAWN NARROWER BY
## EXACTLY THAT, so the glass is the widest thing on the bus and the drawn width is the published
## one.**
##
## THIS IS A REAL CONSTRAINT AND IT CAUGHT THE FIRST DRAFT. A bus is built to 2,550 mm because that
## is the legal maximum and there is nothing to spare: glazing drawn 4 mm proud of a body already at
## 2,550 makes the vehicle 2,558 across and ILLEGAL, which is exactly what the suite reported. Every
## other vehicle here had room for a proud detail -- a hatchback is 1,789 mm wide and no law cares --
## and a bus does not. **A vehicle at its legal limit has no room for decoration, so the decoration
## has to be part of the limit.**
##
## It is also what a modern bus actually is: flush bonded glazing sits proud of the pillars and IS
## the outer surface. The model and the law agree once it is drawn the right way round.
const GLAZE_PROUD: float = 0.004


## ONE BUS, from its catalogue line. Origin on the road, centred along the overall length, -Z forward.
static func build(row: Dictionary, paint: Color) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var length: float = float(row["length"])
	# THE BODY IS NARROWER THAN THE VEHICLE by the glazing's own thickness: see `GLAZE_PROUD`. The
	# published width is what the GLASS measures across, not what the pillars behind it do.
	var outer: float = float(row["width"]) * 0.5
	var half: float = outer - GLAZE_PROUD
	var height: float = float(row["height"])
	var nose: float = -length * 0.5
	var tail: float = length * 0.5
	var clearance: float = float(row["clearance"])
	var front_axle: float = RoadFleet.front_axle(row)
	var rear_axle: float = RoadFleet.rear_axle(row)
	# THE GLASS LINE: where the windows start over the road. This one number is the whole difference
	# between the two vehicles in this file -- a coach's floor is raised over its luggage hold and a
	# low-floor city bus's is not.
	var glass_floor: float = float(row["glass_floor"])
	var glass_top: float = glass_floor + height * GLAZING_DEEP
	var screen_top: float = glass_floor + height * GLAZING_DEEP * float(row["screen_deep"])

	# THE BODY: one box from nose to tail, drawn in a little at each end, standing on its underfloor.
	PRESSING.loft(tool, [
		{"z": nose, "half": half * NOSE_DRAW, "low": clearance + 0.10, "high": screen_top,
			"top": GLASS},
		{"z": nose + float(row["front_overhang"]) * NOSE_ALONG, "half": half, "low": clearance,
			"high": height},
		{"z": tail - float(row["rear_overhang_draw"]), "half": half, "low": clearance,
			"high": height},
		{"z": tail, "half": half * NOSE_DRAW, "low": clearance + 0.10, "high": height - 0.05},
	] as Array[Dictionary], {"side": paint, "top": paint, "bottom": UNDER, "front": paint,
		"back": paint})

	_glazing(tool, row, outer, nose, tail, glass_floor, glass_top, front_axle)
	_skirt(tool, row, paint, outer, nose, tail, glass_floor)
	_doors(tool, row, outer, nose, glass_floor, glass_top, front_axle, rear_axle)
	# THE WHEELS. A bus's drive axle is twinned like a lorry's, and its steer axle is not.
	ROAD_LORRY.axle(tool, row, front_axle, RoadFleet.track_front(row), false)
	ROAD_LORRY.axle(tool, row, rear_axle, RoadFleet.track_rear(row), true)
	ROAD_LORRY.lamps(tool, nose, tail, outer, clearance + 0.18, clearance + 0.62)

	# NO `generate_tangents`: nothing here is textured. See `RoadCar.build`.
	return PLATING.weld(tool)


## THE GLASS BAND ALONG BOTH FLANKS, and the windscreen at the nose.
##
## A bus is mostly window and the band is what says so from any distance. It sits at the vehicle's
## OUTER half-width, with the body drawn `GLAZE_PROUD` narrower behind it -- so the two are never
## coplanar (which would z-fight along a 12 m flank) and the widest thing on the bus is its glass,
## which keeps the drawn width on the published figure. See `GLAZE_PROUD`.
static func _glazing(tool: SurfaceTool, row: Dictionary, outer: float, nose: float, tail: float,
		glass_floor: float, glass_top: float, front_axle: float) -> void:
	var from: float = nose + float(row["front_overhang"]) * 0.55
	var to: float = tail - float(row["rear_overhang_draw"]) * 0.6
	for across in [-1.0, 1.0]:
		var face: float = across * outer
		PLATING.facing(tool, [
			Vector3(face, glass_floor, from), Vector3(face, glass_floor, to),
			Vector3(face, glass_top, to), Vector3(face, glass_top, from),
		], Vector3(across, 0.0, 0.0), GLASS)


## THE SKIRT: the painted panel under the glass line. On a coach this is the luggage hold and it is
## deep; on a low-floor city bus the glass comes down so far that there is barely one. Drawn a shade
## off the livery so the line reads -- **not derived from the paint**, for the reason `RoadCar.UNDER`
## gives at length: a colour computed from one somebody else picks can land on any other.
static func _skirt(tool: SurfaceTool, row: Dictionary, paint: Color, outer: float, nose: float,
		tail: float, glass_floor: float) -> void:
	var top: float = glass_floor - 0.02
	var bottom: float = maxf(top - SKIRT_DOWN, float(row["clearance"]) + 0.05)
	if top <= bottom:
		return
	for across in [-1.0, 1.0]:
		var face: float = across * (outer - 0.001)
		PLATING.facing(tool, [
			Vector3(face, bottom, nose + float(row["front_overhang"]) * 0.5),
			Vector3(face, bottom, tail - float(row["rear_overhang_draw"]) * 0.5),
			Vector3(face, top, tail - float(row["rear_overhang_draw"]) * 0.5),
			Vector3(face, top, nose + float(row["front_overhang"]) * 0.5),
		], Vector3(across, 0.0, 0.0), SKIRT)


## THE DOORS. **This is item 2 at the top and it is the cue a passenger uses**: a city bus has two
## wide doorways breaking its glass line on the nearside, and a coach has one entrance ahead of its
## front axle and nothing else. `doors` in the catalogue says which, and it is the only place the
## difference is stated.
##
## NEARSIDE ONLY, which on the roads this game's towns are laid out for is the LEFT of the vehicle's
## own frame as it faces forward. A bus with doors on both sides is a tram.
static func _doors(tool: SurfaceTool, row: Dictionary, outer: float, nose: float, glass_floor: float,
		glass_top: float, front_axle: float, rear_axle: float) -> void:
	var wide: float = float(row["wheelbase"]) * DOOR_WIDE
	var places: Array[float] = []
	match int(row["doors"]):
		1:
			places.append(front_axle - wide * 1.1)
		2:
			places.append(front_axle - wide * 1.1)
			places.append(rear_axle - wide * 1.6)
	var face: float = -(outer - 0.0005)
	for at in places:
		PLATING.facing(tool, [
			Vector3(face, float(row["clearance"]) + 0.05, at - wide * 0.5),
			Vector3(face, float(row["clearance"]) + 0.05, at + wide * 0.5),
			Vector3(face, glass_top, at + wide * 0.5),
			Vector3(face, glass_top, at - wide * 0.5),
		], Vector3(-1.0, 0.0, 0.0), DOOR)
