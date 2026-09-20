@tool
extends RefCounted
class_name RoadCar
## THE FOUR CARS: a hatchback, a saloon, a crossover and a crew-cab pickup, drawn from one shape.
##
## WHAT MAKES A CAR A CAR, from five hundred feet and from a cockpit waiting at a hold, is not
## detail. It is four things and none of them is a door handle:
##
## 1. **A GREENHOUSE NARROWER THAN THE BODY IT STANDS ON.** A box with windows painted on it is a
##    van. The tumblehome is what says "car" before anything else resolves.
## 2. **A RAKED WINDSCREEN AND BACKLIGHT.** Here they are not parts: they are the TOP face of the
##    lofted greenhouse over its first and last span, between a cowl with almost no height and the
##    top of a pillar with plenty (`Pressing.loft`, and the per-span `top` override exists for this
##    one reason).
## 3. **THE ROOFLINE.** A hatchback's roof runs back to 1.13 wheelbases from the front axle and drops
##    almost vertically onto a tailgate 140 mm from the bumper; a saloon's stops at 0.95 and falls at
##    39 degrees onto a 0.70 m boot; a crossover's runs furthest, to 1.18, and stays high; a crew
##    cab's stops at 0.78, well short of the rear axle, and 1.66 m of bed follows it. **Those four
##    numbers are the whole difference between the four silhouettes in this file**, and
##    `tests/road_vehicles.gd` holds each type to the deck its body style wants, because four cars
##    drawn from one shape table is exactly the arrangement in which they all quietly become one car.
## 4. **WHEELS AT THE RIGHT TRACK AND WHEELBASE, WITH TYRE SHOWING.** The arch is a real opening cut
##    into the underside of the body, not a dark rectangle painted on it: the body runs at the ground
##    clearance under the nose and the tail and sweeps up to a SILL at two thirds of a wheel diameter
##    between them. Drawn the other way -- one flat underside at the published ground clearance, which
##    is a real number and the wrong one -- 145 mm of a 632 mm tyre showed and the car read as a brick
##    on stubs. See `_body`: every check in the suite passed on that version, and a picture did not.
##
## THE TESSELLATION, stated so nobody subdivides it later (`modelling_here.md` section 4): the body is
## SEVEN cross-sections -- eight on a pickup, which has a cab's rear wall the others have not -- the
## greenhouse FOUR, the rocker TWO, and a wheel is an EIGHT-SIDED PRISM. Nothing is round.
## A whole car is 378 triangles, 390 for the pickup, against the boxcar's 900 and the Hawkeye's 2,700,
## which is the right order for a thing there may be a hundred of. Retessellating must not move a
## measured dimension: the suite reads every one of them off the drawn vertices.
##
## **NO MIRRORS, AND THAT IS A MEASUREMENT DECISION RATHER THAN A LAZY ONE.** Every published width
## behind this catalogue EXCLUDES mirrors -- a van's add roughly 350 mm a side, which would make a
## Transit 2.76 m wide, wider than the legal maximum for a lorry. Drawing them puts the model's drawn
## envelope permanently at odds with the source it is checked against, for two triangles that are
## under a pixel from anywhere these are seen. `craft/road/sources.md` says so where the widths are.
##
## THE LAMPS STAND 4 mm PROUD of the nose and the tail, and the drawn length is therefore 8 mm over
## the published one: 0.09 per cent on the shortest car here, well inside the 20 mm the suite allows
## and named here so nobody reads it as drift. A lens flush with a cap the loft has already drawn
## z-fights, and a real lens is not flush either.

const PRESSING := preload("res://objects/vehicles/road/pressing.gd")
const PLATING := preload("res://objects/vehicles/ships/plating.gd")

## ---- the colours that are NOT the paint ---------------------------------------------------------
##
## KEPT WELL APART ON PURPOSE. `SurfaceTool.commit` quantises vertex colour to eight bits a channel,
## so a suite that picks the glass out of a mesh by its colour needs a gap it can still see
## afterwards -- the boxcar's first pair were 0.03 apart, could not be told apart after the commit,
## and its suite found no wheels at all on a car with eight of them. The darks here are kept at least
## 0.03 apart in some channel, which is 8 steps of 255 -- and see `UNDER` for the harder half of this,
## which is that a colour DERIVED from a paint somebody else picks cannot be kept apart from anything.
##
## GLASS IS NOT BLACK. A black window is a hole; glass is a dark blue-grey that keeps a little of the
## sky in it, and from above -- which is how most of these are seen -- the greenhouse is most of what
## you can see of a car at all.
const GLASS := Color(0.075, 0.095, 0.120)
const TYRE := Color(0.030, 0.030, 0.032)
## The wheel's two faces. Bright, because a wheel seen from ahead or from the pavement is mostly its
## face, and a face the colour of the tread is a black disc with no wheel in it (`Boxcar`, the same).
const HUB := Color(0.55, 0.56, 0.58)
## **THE UNDERSIDE IS A FIXED COLOUR AND NOT A DARKENED PAINT, and that is a bug's worth of reason.**
## It was `paint * 0.35` and the rocker's floor `paint * 0.30`, on the sound argument that a floor pan
## is a shadowed version of whatever the car is. But a DERIVED colour can land on a FIXED one, and the
## crossover's blue-grey (0.30, 0.33, 0.38) times 0.30 is (0.090, 0.099, 0.114) -- inside two
## hundredths of `GLASS` on all three channels. `tests/road_vehicles.gd` found "glass" 195 mm over the
## road, which is the underside, and said the crossover's windows started at its floor pan.
##
## The lesson generalises past this file: **keeping the FIXED palette well separated proves nothing
## about colours computed from a colour somebody else chooses.** A car's paint is picked per instance
## and can be anything, so any shade of it can be anything, and no amount of care over the constants
## constrains it. So nothing here darkens the paint any more: the underside is this, and the rocker is
## the paint itself, which is what a real car's rocker is painted anyway. The one collision left --
## somebody painting a car the colour of its own glass -- is a single comparison, and the suite makes
## it.
const UNDER := Color(0.105, 0.100, 0.098)
const BUMPER := Color(0.205, 0.210, 0.220)
const LAMP := Color(0.88, 0.86, 0.74)
const TAIL_LAMP := Color(0.60, 0.09, 0.08)
## A pickup's bed floor and its inner walls: a ribbed steel liner, weathered.
const BED := Color(0.27, 0.28, 0.29)

## ---- the shape, as shares of something measured -------------------------------------------------
##
## Every one of these is ESTIMATE and every one is a share of a PUBLISHED dimension, never a typed
## metre figure, so a car of a different size gets a shape of the same character rather than a
## hatchback's proportions on a pickup's envelope.
##
## THE GREENHOUSE'S TUMBLEHOME: how much narrower the cabin is than the body under it. This is item 1
## at the top -- the single cue that separates a car from a van -- and 0.88 is what a modern car's
## roof measures against its own widest point, read off the fact that a 1.789 m Golf has about 1.57 m
## across its roof rails.
const TUMBLEHOME: float = 0.88
## And the cabin draws in a little more at each end, so the A- and C-pillars rake inwards in PLAN as
## well as in profile. A greenhouse with parallel sides is a bus.
const CABIN_FRONT_DRAW: float = 0.90
const CABIN_REAR_DRAW: float = 0.92
## HOW FAR THE NOSE AND TAIL ARE DRAWN IN from the flanks, in plan, and how far back the full width is
## reached. A car's corners are cut; a box's are not.
const END_DRAW: float = 0.80
const SHOULDER_ALONG: float = 0.22
## **THE SILL, AS A SHARE OF THE WHEEL'S OWN DIAMETER.** Where the full-width body starts over the
## road, and so how much tyre shows. Two thirds is what a real car measures: a Golf on 632 mm tyres
## carries its rocker about 420 mm up. Derived from the wheel rather than typed per type, so a pickup
## on 803 mm tyres gets a 530 mm sill and the stance comes out right without anybody choosing it. See
## `_body` for the picture that made this constant exist.
const SILL_OF_WHEEL: float = 0.66
## HOW LONG THE ARCH OPENING IS, as a share of the wheel's diameter. A real arch is a little longer
## than its wheel; this is where the underside leaves the sill and sweeps down to the valance.
const ARCH_SPAN: float = 1.16
## How far inboard of the flanks the rocker panel sits.
const ROCKER_IN: float = 0.86
## The bumper: a band across the nose and the tail, as a share of the body's width and standing from
## just over the road to just under the lamps.
##
## IT MUST BE NARROWER THAN `END_DRAW`, because that is how far in the body's own corner is drawn and
## a bumper wider than the panel it is bolted to hangs out past the corner in mid air. It was 0.84
## against an END_DRAW of 0.80 and did exactly that, at all four corners of all four cars.
const BUMPER_WIDE: float = 0.76
const BUMPER_LOW: float = 0.02
const BUMPER_HIGH: float = 0.30
## The lamps: how far out from the centreline each pair sits, how big, and how far proud. See the
## doc block -- the 4 mm is the whole of the 8 mm the drawn length runs over its published one.
const LAMP_OUT: float = 0.56
const LAMP_WIDE: float = 0.30
const LAMP_TALL: float = 0.15
const LAMP_PROUD: float = 0.004
## A pickup's bed: how deep below the rail its floor lies, and how far inside the body its walls are.
const BED_DEEP: float = 0.44
const BED_INSET: float = 0.075


## ONE CAR, from its catalogue line. Origin on the road, centred along the overall length, -Z forward.
static func build(row: Dictionary, paint: Color) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var length: float = float(row["length"])
	var half_wide: float = float(row["width"]) * 0.5
	var height: float = float(row["height"])
	var wheelbase: float = float(row["wheelbase"])
	var clearance: float = float(row["clearance"])
	var belt: float = float(row["belt"])
	var nose: float = -length * 0.5
	var tail: float = length * 0.5
	var front_axle: float = RoadFleet.front_axle(row)
	# THE FOUR CABIN STATIONS, out of the wheelbase and measured back from the FRONT AXLE. Never from
	# the nose: a cowl quoted from the bumper moves when the bumper does and the cabin has not.
	var cowl: float = front_axle + float(row["cowl"]) * wheelbase
	var a_top: float = front_axle + float(row["a_top"]) * wheelbase
	var c_top: float = front_axle + float(row["c_top"]) * wheelbase
	var backlight: float = front_axle + float(row["backlight"]) * wheelbase
	var open_bed: bool = bool(row["bed"])

	# THE SILL: where the full-width body begins, over the road. Derived from the WHEEL, never typed,
	# so a taller vehicle on bigger tyres gets a higher sill without anybody choosing one. See `_body`.
	var wheel: float = RoadFleet.wheel_diameter(row)
	var sill: float = wheel * SILL_OF_WHEEL
	var rear_axle: float = RoadFleet.rear_axle(row)
	_body(tool, paint, nose, tail, half_wide, clearance, sill, belt, cowl, backlight,
		front_axle, rear_axle, wheel, open_bed)
	_rocker(tool, paint, half_wide, clearance, sill, front_axle, rear_axle, wheel)
	_greenhouse(tool, paint, half_wide, belt, height, cowl, a_top, c_top, backlight)
	_running_gear(tool, row)
	_ends(tool, nose, tail, half_wide, clearance, belt)
	if open_bed:
		_bed(tool, backlight, tail, half_wide, clearance, belt)

	# NO `generate_tangents`: nothing here is textured, so there are no UVs to generate them from, and
	# asking raises "UVs are required to generate tangents" into a suite's error gate on an otherwise
	# green run (`Boxcar`, which met it first).
	return PLATING.weld(tool)


## THE LOWER BODY, AND THE THING THAT DECIDES WHETHER IT READS AS A CAR AT ALL: **the underside is
## not flat.** It runs at the ground clearance under the nose and the tail and sweeps UP TO THE SILL
## between the arches, so a wheel stands in an opening instead of against a wall.
##
## THIS WAS WRONG FIRST AND ONLY A PICTURE SAID SO. Drawn with the underside flat at the ground
## clearance -- 145 mm on a hatchback, which is a real car's real ground clearance -- every check in
## `tests/road_vehicles.gd` passed: right length, right width, right height, right wheelbase, four
## contact patches at y = 0, tyres inboard of the flanks, eight facets a wheel. And the picture showed
## four bricks on white stubs, because **only 145 mm of a 632 mm tyre was outside the body.** A real
## car's rocker sits at about two thirds of a wheel diameter and the arch cuts higher again: the
## published ground clearance is the lowest point of the FLOOR PAN, not of the bodywork, and reading
## one as the other is `modelling_here.md`'s own trap -- a real number quoted against the wrong place
## on the object. CLAUDE.md rule 2, and it cost nothing but a look.
##
## `open_bed` opens the top over the rear spans, so a pickup's bed is a bed and not a sealed box with
## a dark panel hidden inside it.
static func _body(tool: SurfaceTool, paint: Color, nose: float, tail: float, half_wide: float,
		clearance: float, sill: float, belt: float, cowl: float, backlight: float,
		front_axle: float, rear_axle: float, wheel: float, open_bed: bool) -> void:
	var shoulder: float = tail - SHOULDER_ALONG
	var arch: float = wheel * ARCH_SPAN * 0.5
	var sections: Array[Dictionary] = [
		{"z": nose, "half": half_wide * END_DRAW, "low": clearance + 0.06, "high": belt - 0.14},
		{"z": nose + SHOULDER_ALONG, "half": half_wide * 0.98, "low": clearance, "high": belt - 0.08},
		# THE FRONT ARCH'S LEADING EDGE. Between here and the section before it the underside sweeps
		# up from the valance to the sill, which is the line under a real car's front wing.
		{"z": front_axle - arch, "half": half_wide, "low": sill, "high": belt - 0.02},
		{"z": cowl, "half": half_wide, "low": sill, "high": belt},
	]
	# THE BED'S FRONT WALL IS A SECTION OF THE BODY, AND ONLY A PICKUP HAS ONE. A saloon or a
	# hatchback wants no station at its backlight at all -- the body does not change shape there --
	# and inserting one anyway is what put a hatchback's section 80 mm BEHIND the one after it, on a
	# roofline that runs almost to the rear bumper. Sections that run backwards draw a length of body
	# inside out and leave every dimension check green.
	if open_bed and backlight < rear_axle + arch:
		sections.append({"z": backlight, "half": half_wide, "low": sill, "high": belt,
			"open": true})
		sections.append({"z": rear_axle + arch, "half": half_wide, "low": sill, "high": belt - 0.02,
			"open": true})
		sections.append({"z": shoulder, "half": half_wide * 0.98, "low": clearance,
			"high": belt - 0.04, "open": true})
	else:
		sections.append({"z": rear_axle + arch, "half": half_wide, "low": sill, "high": belt - 0.02})
		sections.append({"z": shoulder, "half": half_wide * 0.98, "low": clearance,
			"high": belt - 0.04})
	sections.append({"z": tail, "half": half_wide * END_DRAW, "low": clearance + 0.06,
		"high": belt - 0.12})
	PRESSING.loft(tool, sections, {"side": paint, "top": paint, "bottom": UNDER,
		"front": paint, "back": paint})


## THE ROCKER: the panel between the two arches, from the floor pan up to the sill and set inboard of
## the flanks. It closes the car underneath now that the body no longer reaches the ground, and the
## step where it sets in from the flanks is what makes the sill read as a line rather than as the
## bottom of a slab.
static func _rocker(tool: SurfaceTool, paint: Color, half_wide: float, clearance: float, sill: float,
		front_axle: float, rear_axle: float, wheel: float) -> void:
	var arch: float = wheel * ARCH_SPAN * 0.5
	var from: float = front_axle + arch
	var to: float = rear_axle - arch
	if to <= from or sill <= clearance:
		return
	# NO TOP FACE. The rocker's top and the body's underside are both at the sill, exactly coplanar,
	# and two coplanar faces z-fight: the first picture of it had a sawtooth running the length of
	# every car along the sill line. `open` exists for this. The rocker's top is inside the body and
	# there is nothing there to see.
	var panel: Array[Dictionary] = [
		{"z": from, "half": half_wide * ROCKER_IN, "low": clearance, "high": sill, "open": true},
		{"z": to, "half": half_wide * ROCKER_IN, "low": clearance, "high": sill},
	]
	# IN THE PAINT, not a shade of it: see `UNDER`. The step where the rocker sets in from the flank
	# is what makes the sill read as a line, and it is a real step that catches real light, so it does
	# not need a painted-on shadow to help it.
	PRESSING.loft(tool, panel, {"side": paint, "top": paint, "front": paint, "back": paint,
		"bottom": UNDER})


## THE GREENHOUSE: four cross-sections, narrower than the body and standing on it.
##
## The first and last are only 20 mm tall, which does two things. It puts the foot of the windscreen
## and of the backlight at the waist exactly, so the raked quad between there and the pillar top IS
## the glass; and it keeps the greenhouse's own underside 20 mm INSIDE the body's top face, where a
## coincident pair would z-fight along the whole length of the car.
static func _greenhouse(tool: SurfaceTool, paint: Color, half_wide: float, belt: float,
		height: float, cowl: float, a_top: float, c_top: float, backlight: float) -> void:
	var cabin: float = half_wide * TUMBLEHOME
	var foot: float = belt - 0.02
	var sections: Array[Dictionary] = [
		# The cowl. Its flanks are the A-pillars, painted; its TOP over the next span is the windscreen.
		{"z": cowl, "half": cabin * CABIN_FRONT_DRAW, "low": foot, "high": belt,
			"side": paint, "top": GLASS},
		# The front of the roof. Flanks are the side windows; the top is the roof itself.
		{"z": a_top, "half": cabin, "low": foot, "high": height,
			"side": GLASS, "top": paint},
		# The back of the roof. Flanks are the C-pillars; the top over the last span is the backlight.
		{"z": c_top, "half": cabin, "low": foot, "high": height,
			"side": paint, "top": GLASS},
		{"z": backlight, "half": cabin * CABIN_REAR_DRAW, "low": foot, "high": belt},
	]
	PRESSING.loft(tool, sections, {"side": GLASS, "top": paint, "bottom": paint,
		"front": GLASS, "back": GLASS})


## THE FOUR WHEELS. Both axles are ASKED of the catalogue rather than worked out here: a model that
## computes where its own wheels go is a second opinion about the wheelbase, and two opinions about
## one number is how a vehicle ends up the right size with the wrong stance.
##
## THERE IS NO PAINTED ARCH ANY MORE. The first version set a dark panel 60 mm inside the flank to
## stand in for one, because the body reached the ground and there was no opening for a wheel to be
## in at all. `_body` cuts a real one now, and a flat dark rectangle behind a tyre that already fills
## its own opening is two triangles drawing nothing.
static func _running_gear(tool: SurfaceTool, row: Dictionary) -> void:
	var diameter: float = RoadFleet.wheel_diameter(row)
	var wide: float = RoadFleet.wheel_width(row)
	var axles: Array = [
		[RoadFleet.front_axle(row), RoadFleet.track_front(row)],
		[RoadFleet.rear_axle(row), RoadFleet.track_rear(row)],
	]
	for axle in axles:
		for across in [-1.0, 1.0]:
			PRESSING.wheel(tool, Vector3(across * float(axle[1]) * 0.5, diameter * 0.5,
				float(axle[0])), diameter, wide, TYRE, HUB)


## THE BUMPERS AND THE LAMPS. A car with no lamps reads as a model of a car; two pale patches at the
## nose and two red ones at the tail are what a driver's eye finds first at dusk, and they cost eight
## triangles.
static func _ends(tool: SurfaceTool, nose: float, tail: float, half_wide: float, clearance: float,
		belt: float) -> void:
	for end in [[nose, -1.0, LAMP, belt - 0.14], [tail, 1.0, TAIL_LAMP, belt - 0.12]]:
		var z: float = float(end[0])
		var way: float = float(end[1])
		var lamp: Color = end[2]
		var top: float = float(end[3])
		# SET 8 mm INSIDE THE CAP, never flush with it. The bumper's outer face and the body's end cap
		# were both exactly at the nose and at the tail, and two coplanar faces z-fight: the picture
		# had a sawtooth chevron under the tail lamps of every car. Eight millimetres is invisible at
		# any distance one of these is seen from and is a hundred times the depth precision at it.
		PLATING.box(tool, Vector3(0.0, clearance + (BUMPER_LOW + BUMPER_HIGH) * 0.5,
			z - way * (SHOULDER_ALONG * 0.35 + 0.008)),
			Vector3(half_wide * 2.0 * BUMPER_WIDE, BUMPER_HIGH - BUMPER_LOW, SHOULDER_ALONG * 0.7),
			BUMPER)
		for across in [-1.0, 1.0]:
			var middle: float = across * half_wide * END_DRAW * LAMP_OUT
			var lens: float = z + way * LAMP_PROUD
			var high: float = top - 0.04
			PLATING.facing(tool, [
				Vector3(middle - LAMP_WIDE * 0.5, high - LAMP_TALL, lens),
				Vector3(middle + LAMP_WIDE * 0.5, high - LAMP_TALL, lens),
				Vector3(middle + LAMP_WIDE * 0.5, high, lens),
				Vector3(middle - LAMP_WIDE * 0.5, high, lens),
			], Vector3(0.0, 0.0, way), lamp)


## A PICKUP'S BED, drawn as the cavity it is: a floor well below the rail and four walls facing INTO
## it. The body's top is already open over these two spans (`_body`), so this is what is seen from
## above -- and from above is where a pickup is told from a saloon at all.
static func _bed(tool: SurfaceTool, from: float, to: float, half_wide: float, clearance: float,
		belt: float) -> void:
	var inner: float = half_wide - BED_INSET
	var front: float = from + BED_INSET
	var back: float = to - SHOULDER_ALONG
	var floor_at: float = belt - BED_DEEP
	if floor_at <= clearance or back <= front:
		return
	PLATING.paint(tool, PackedVector2Array([
		Vector2(-inner, front), Vector2(inner, front), Vector2(inner, back), Vector2(-inner, back),
	]), floor_at, BED)
	# The four walls, each facing in towards the middle of the bed.
	for across in [-1.0, 1.0]:
		PLATING.facing(tool, [
			Vector3(across * inner, floor_at, front), Vector3(across * inner, belt, front),
			Vector3(across * inner, belt, back), Vector3(across * inner, floor_at, back),
		], Vector3(-across, 0.0, 0.0), BED)
	for end in [[front, 1.0], [back, -1.0]]:
		PLATING.facing(tool, [
			Vector3(-inner, floor_at, float(end[0])), Vector3(inner, floor_at, float(end[0])),
			Vector3(inner, belt, float(end[0])), Vector3(-inner, belt, float(end[0])),
		], Vector3(0.0, 0.0, float(end[1])), BED)
