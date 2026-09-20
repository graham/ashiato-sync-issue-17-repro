extends Node
## Headless: THE ROAD VEHICLES, held to their published envelopes and to bounds from outside them.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/road_vehicles.tscn
##
## Asked for on 2026-09-19: *"We need a selection of cars, trucks and busses, something we can
## simulate cars and traffic with. Make sure they don't think about physics, they are not craft so
## don't build KIND or make them part of the physics simulation, but let's just create models for
## them, we can place them as meshes in the levels."*
##
## THE FIGURES AT THE TOP ARE THE SOURCES, typed here as an independent statement of what each model
## is supposed to be -- `craft/road/sources.md` is the write-up with the URLs. **They are NOT read off
## `RoadFleet`**, and that is the whole point of them: a check that asks the code for the number it is
## checking cannot catch that number being wrong (`modelling_here.md` section 6, and the 18 m box that
## was a "boxcar" for as long as there was a train).
##
## WHAT IT HOLDS:
##
##   - every type in the catalogue is DRAWN AT ALL, and the list is enumerated rather than typed, so a
##     type added without a builder fails here rather than going missing quietly;
##   - each is drawn at its published length, width and height, MEASURED FROM ITS OWN VERTICES and
##     never from `transform * get_aabb()`, which grows a box every time it is turned;
##   - **it STANDS ON THE ROAD**: its lowest drawn point is the flat under its tyres at y = 0, and
##     nothing at all is below that. A vehicle sunk into the tarmac or hovering over it is the single
##     most obvious fault a placed mesh can have and no other check here would see it;
##   - four wheels at the published WHEELBASE, measured from the contact patches themselves -- not
##     from the hubs, which on a faceted wheel are not where the geometry touches;
##   - **the tyres stand INBOARD of the body.** This is the check that stands in for a track figure
##     nothing published supports: it catches the error in the direction that looks wrong rather than
##     asserting a millimetre nobody can source (`sources.md`, "Track");
##   - a wheel is an EIGHT-SIDED prism, counted from the DRAWN NORMALS, so replacing it with a smooth
##     cylinder fails; `modelling_here.md` section 4 asks for the counts to be stated and nothing else
##     in this project yet checks that they are kept;
##   - **the greenhouse is narrower than the body under it.** Tumblehome is the one cue that separates
##     a car from a van at any distance, and a body drawn without it passes every dimension check;
##   - there is GLASS, and it is above the waist and reaches the roof;
##   - **the four silhouettes are actually different**, by the deck behind the rear glass: a saloon has
##     a boot, a hatchback and a crossover have almost nothing, and a pickup has a bed. Four types
##     drawn from one shape table is exactly the arrangement in which they all quietly become the same
##     car, and nothing about their envelopes would say so;
##   - **THE PICKUP'S BED FLOOR IS 5 FT 6 IN.** This is the check anchored outside the model: it is a
##     published bed length, no part of the model was built from it, and the model does not know it
##     exists. `Boxcar`'s AAR clearance plate is the same idea;
##   - every catalogue line's overhangs CLOSE on its own length, the way a manufacturer's specification
##     sheet does;
##   - **and NOTHING HERE IS SOLID.** No static box, no collision, no `boxes()` to answer for. That is
##     the user's constraint, it is the one thing about this lane that a later session is most likely
##     to undo by copying a template that has one, and it is asserted rather than assumed.
##
## IDENTIFYING A PART BY THE MODEL'S OWN COLOUR IS ALLOWED; ASSERTING A DIMENSION FROM THE MODEL'S OWN
## NUMBER IS NOT. The glass is found with `RoadCar.GLASS` because a mesh has no other way to say which
## quad is a window -- `tests/train_models.gd` picks the boxcar's wheels out the same way. Every
## MEASUREMENT below is then made from vertices and compared against a figure typed in this file.
##
## Read RESULT=, not the exit code.

## ---- what the sources say each vehicle is. See cockpit/craft/road/sources.md. ------------------
## Metres. PUBLISHED: the Wikipedia infobox for each authority, quoted there with its URL.
const CARS: Array[Dictionary] = [
	## VW Golf Mk8.
	{"name": &"hatchback", "length": 4.284, "width": 1.789, "height": 1.456, "wheelbase": 2.636,
		"deck": 0.14, "triangles": 420},
	## BMW 3 Series G20.
	{"name": &"saloon", "length": 4.709, "width": 1.827, "height": 1.442, "wheelbase": 2.851,
		"deck": 0.70, "triangles": 420},
	## Toyota RAV4 XA50, at the bottom of its published height range plus 5 mm -- see `sources.md`.
	{"name": &"suv", "length": 4.635, "width": 1.855, "height": 1.685, "wheelbase": 2.690,
		"deck": 0.18, "triangles": 420},
	## Ford F-150 14th generation, SuperCrew, SHORT BED.
	{"name": &"pickup", "length": 5.885, "width": 2.029, "height": 1.961, "wheelbase": 3.693,
		"deck": 1.96, "triangles": 440},
]

## AND THE TRUCKS. `deck` has no meaning for these -- they are checked by the list below instead.
const TRUCKS: Array[Dictionary] = [
	## Ford Transit L3, medium roof.
	{"name": &"van", "length": 5.980, "width": 2.052, "height": 2.550, "wheelbase": 3.750,
		"triangles": 560},
	## Mercedes-Benz Atego 4x2 rigid, 1524, day cab. Every figure printed on the maker's own sheet.
	{"name": &"boxlorry", "length": 9.065, "width": 2.550, "height": 3.555, "wheelbase": 4.760,
		"triangles": 820},
	## A 4x2 cabover tractor and a 13.60 m semi-trailer.
	{"name": &"artic", "length": 16.480, "width": 2.550, "height": 3.900, "wheelbase": 3.650,
		"triangles": 1120},
]

## AND THE BUSES.
const BUSES: Array[Dictionary] = [
	## Mercedes-Benz Citaro O530, 12 m. The worst-sourced vehicle on the lane -- see `sources.md`.
	{"name": &"citybus", "length": 12.135, "width": 2.550, "height": 3.120, "wheelbase": 5.900,
		"triangles": 460},
	## Volvo 9700 12.4 m 4x2 Euro 6, from the maker's own data sheet, which closes on itself.
	{"name": &"coach", "length": 12.400, "width": 2.550, "height": 3.650, "wheelbase": 6.170,
		"triangles": 460},
]

## **HOW HIGH THE LOWEST LEGITIMATE PANE OF GLASS IS, IN METRES.** Knee height. Both checks that use
## it were first written as a share of the vehicle's own height and both failed the low-floor city
## bus, correctly and unhelpfully: its sill is 0.72 m on a 3.12 m body, and coming down that far is
## what "low-floor" MEANS. A proportion demanded the most clearance from the tallest vehicles, which
## is backwards. The fault being guarded against -- the crossover's underbody drawn in the glass
## colour -- sat at 0.195 m, so half a metre separates the two cleanly and means something on its own.
const GLASS_CLEARS_ROAD: float = 0.50

## A TWO-AXLE BUS MAY BE 13.5 m, which is 96/53/EC's own figure for one and is not the 12 m a rigid
## GOODS vehicle is held to. Using the goods limit on a bus would be checking the right vehicle
## against the wrong law -- and it would pass, which is worse, because both buses here are under 12.5.
const MAX_TWO_AXLE_BUS: float = 13.50

## ---- the bounds that come from OUTSIDE every model here -------------------------------------------
##
## Council Directive 96/53/EC, Annex I. **No dimension in `RoadFleet` was chosen to satisfy any of
## these, with ONE stated exception**, and the exception is why the list is split in two.
const MAX_WIDTH: float = 2.55
const MAX_HEIGHT: float = 4.00
const MAX_RIGID: float = 12.00
## The hard one. EUR-Lex read through an agent's fetch conflated the articulated limit with the road
## train's and gave 18.75 m for both; 16.5 m for an articulated vehicle comes from secondary readings.
## So the suite checks the figure that cannot be wrong.
const MAX_ROAD_TRAIN: float = 18.75
## **THE ARTIC'S OVERALL LENGTH IS NOT CHECKED AGAINST 16.5 m AND MUST NOT BE.** Its kingpin set-back
## was chosen to make the combination legal, which is what a haulier does and which makes 16.5 m a
## figure the model was FITTED TO. A check against it would be the model asking itself.
##
## THIS IS THE ONE THAT SURVIVES: kingpin to the rear of the semi-trailer, 12.5 m. It comes out of a
## PUBLISHED trailer length (13.600 m) less a PUBLISHED kingpin setting (1.700 m) and nothing else --
## published in, published out, no figure of this lane's anywhere in it.
const MAX_KINGPIN_TO_REAR: float = 12.50

## THE BOX BODY IS `G`, PRINTED. Mercedes-Benz's sheet states back-of-cab to end-of-frame as 7,235 mm
## for the 1524, and the drawn body is held to it. It is not derived here and not derived there.
const ATEGO_BODY: float = 7.235
## Within this, because the body's front face is drawn at the cab's rear wall and its back at the
## frame's end, and both of those are stations rather than surfaces.
const BODY_WITHIN: float = 0.05

## THE BOUND FROM OUTSIDE THE MODEL: a Ford F-150's 5.5 ft bed, which is a published floor length, is
## not a dimension of anything in `RoadFleet`, and which no part of the model was built from. A cab
## that crept backwards would pass every envelope check here and fail this one.
const SHORT_BED: float = 5.5 * 0.3048
## How close the drawn bed floor has to come. Three per cent of 1.68 m is 50 mm; the floor is drawn
## between a liner and a tailgate whose thicknesses are both ESTIMATE, so a tighter band would be
## measuring those rather than the bed.
const BED_WITHIN: float = 0.03

## HOW MANY SIDES A WHEEL IS DRAWN WITH, and HOW MANY WHEELS A CAR HAS. Typed HERE, not read off
## `Pressing`, and that is the whole point of them: `modelling_here.md` section 4 forbids a
## retessellation moving a measured dimension, and this is the check that would notice. 8 is that
## section's low-poly direction, against the Hawkeye's 20 on a nacelle round.
const WHEEL_SIDES: int = 8
const WHEELS: int = 4

## How close a drawn dimension has to be to its published one. Twenty millimetres is 0.47 per cent of
## the shortest car here, and it is comfortably wider than the 8 mm the two lamp lenses add to the
## length by standing 4 mm proud of the nose and the tail (`RoadCar`, which says so).
const CLOSE: float = 0.02

## THE GREENHOUSE MUST BE THIS MUCH NARROWER THAN THE BODY, at least. The model aims at 0.88 and this
## asks only that it is under 0.94, because the claim being made is "a car is not a van", not "the
## tumblehome is 0.88". A bound wide enough to be honest and narrow enough to fail a box.
const TUMBLEHOME_AT_MOST: float = 0.94

## A car is ONE mesh: a street of forty must not be forty draw calls a colour.
const SURFACES: int = 1
## THE TRIANGLE BUDGET IS PER TYPE, in the tables above, because ONE NUMBER FOR NINE VEHICLES IS NOT
## A BUDGET. A car is about 380, a van 460, a rigid box lorry 700 and an articulated vehicle a
## thousand -- it is two vehicles with six twinned wheels between them -- and a single ceiling loose
## enough for the artic would let a hatchback triple in size unnoticed, which is the only thing a
## budget is for. Against the boxcar's 900 and the Hawkeye's 2,700.
##
## THE CARS' WAS 400 AND THEN 480, and the 128 in between bought the wheels: a wheel's side face was
## one fan in the hub's colour, as `Boxcar` draws it, which is right for a railway wheel seen end on
## at 30 m/s and wrong for a road wheel parked at a kerb -- every car stood on four white discs.
## Budgets move when something is bought with them; this records what was bought.

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[road_vehicles] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_every_catalogue_line_closes_on_its_own_length()
	_the_catalogue_and_this_suite_describe_the_same_fleet()
	for reference in CARS:
		_measure(reference)
	for reference in TRUCKS:
		_measure(reference)
	for reference in BUSES:
		_measure(reference)
	_the_four_silhouettes_are_actually_different()
	_every_truck_is_inside_the_law()
	_the_two_buses_are_two_different_buses()
	_the_box_lorrys_body_is_the_length_its_maker_prints()
	_no_two_colours_in_one_vehicle_are_indistinguishable()
	_nothing_here_is_solid()
	_check("every_section_of_this_suite_reached_its_own_end", _sections == 8 + CARS.size() + TRUCKS.size() + BUSES.size(),
		"%d of %d" % [_sections, 8 + CARS.size() + TRUCKS.size() + BUSES.size()])
	print("RESULT=%s" % ["PASS" if _failures.is_empty() else "FAIL"])
	if not _failures.is_empty():
		print("[road_vehicles] failed: %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## ---- the catalogue itself ----------------------------------------------------------------------

## A MANUFACTURER'S SPECIFICATION SHEET ADDS UP TO ITS OWN OVERALL LENGTH, and so must this table.
## Front overhang plus wheelbase plus rear overhang is the length, every part positive.
func _every_catalogue_line_closes_on_its_own_length() -> void:
	var open: PackedStringArray = []
	for row in RoadFleet.TYPES:
		if not RoadFleet.overhangs_close(row):
			open.append("%s: %.3f + %.3f + %.3f against %.3f" % [row["name"],
				row["front_overhang"], row["wheelbase"], RoadFleet.rear_overhang(row),
				row["length"]])
	_check("every_catalogue_line_closes_on_its_own_length", open.is_empty(),
		"%s" % ["all %d" % RoadFleet.TYPES.size() if open.is_empty() else open])
	_sections += 1


## THE FLEET IS ENUMERATED, NEVER COPIED. A type added to the catalogue with no reference here, or a
## reference here for a type nobody draws, is drift -- and the quietest kind, because a suite that
## walks its own list is green over a vehicle nobody checks.
func _the_catalogue_and_this_suite_describe_the_same_fleet() -> void:
	var catalogue: Array[StringName] = RoadFleet.names()
	var mine: Array[StringName] = []
	for reference in CARS:
		mine.append(StringName(reference["name"]))
	for reference in TRUCKS:
		mine.append(StringName(reference["name"]))
	for reference in BUSES:
		mine.append(StringName(reference["name"]))
	var unchecked: PackedStringArray = []
	for name in catalogue:
		if not mine.has(name):
			unchecked.append(String(name))
	var ghosts: PackedStringArray = []
	for name in mine:
		if not catalogue.has(name):
			ghosts.append(String(name))
	_check("every_type_in_the_catalogue_has_a_reference_in_this_suite", unchecked.is_empty(),
		"%d in the catalogue, %d checked here%s" % [catalogue.size(), mine.size(),
			"" if unchecked.is_empty() else ": %s unchecked" % unchecked])
	_check("and_this_suite_checks_nothing_that_is_not_in_the_catalogue", ghosts.is_empty(),
		"%s" % ["none" if ghosts.is_empty() else ghosts])
	_sections += 1


## ---- one vehicle -------------------------------------------------------------------------------

func _measure(reference: Dictionary) -> void:
	var name: StringName = StringName(reference["name"])
	var mesh: ArrayMesh = RoadFleet.mesh(name)
	if mesh == null:
		_check("%s_is_drawn_at_all" % name, false, "RoadFleet.mesh() returned nothing")
		return
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		points.append_array(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		normals.append_array(arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		colours.append_array(arrays[Mesh.ARRAY_COLOR] as PackedColorArray)
	var bounds: AABB = _drawn_bounds(points)

	_it_is_one_surface_within_its_triangles(name, reference, mesh, points)
	_it_is_wound_outwards(name, points, normals)
	_it_is_the_size_its_sources_say(name, reference, bounds)
	_it_stands_on_the_road(name, points, bounds)
	_its_wheels_are_where_the_wheelbase_says(name, reference, points, bounds)
	_a_wheel_is_an_eight_sided_prism(name, reference, points, normals)
	# TUMBLEHOME IS A CAR'S CUE AND NOT A TRUCK'S. A van IS a box with windows in it -- that is what
	# makes it read as a van -- and a lorry's cab is narrower than its BODY rather than than itself.
	# Asking a truck to have a narrower greenhouse would be asserting the thing that is false about
	# it, so the check that applies to every vehicle here is the one below it: there is glass, and it
	# is up where a windscreen is.
	if _is_a_car(name):
		_its_greenhouse_is_narrower_than_its_body(name, points, colours, bounds)
	else:
		_it_is_glazed_where_a_windscreen_goes(name, points, colours, bounds)
	_sections += 1


## Whether this type is one of the cars, asked of the SUITE's own two lists rather than of the
## catalogue: the thing being checked must not be the thing that decides which check applies.
func _is_a_car(name: StringName) -> bool:
	for reference in CARS:
		if StringName(reference["name"]) == name:
			return true
	return false


## A TRUCK IS GLAZED, AND ITS GLASS IS UP AT THE FRONT. A cab with no windscreen is a shipping
## container with lamps on it, and nothing else in this suite would notice.
func _it_is_glazed_where_a_windscreen_goes(name: StringName, points: PackedVector3Array,
		colours: PackedColorArray, bounds: AABB) -> void:
	var glass: Array[Vector3] = []
	for i in range(points.size()):
		if _is(colours[i], RoadCar.GLASS):
			glass.append(points[i])
	_check("the_%s_has_glass_in_it" % name, glass.size() >= 12,
		"%d glazed vertices of %d" % [glass.size(), points.size()])
	if glass.is_empty():
		return
	var forward: float = INF
	var lowest: float = INF
	for point in glass:
		forward = minf(forward, point.z)
		lowest = minf(lowest, point.y)
	# The glass must start in the front third of the vehicle, and must be clear of the road.
	#
	# **CLEAR OF THE ROAD IS AN ABSOLUTE HEIGHT, NOT A SHARE OF THE VEHICLE'S OWN.** It was a share --
	# a thirtieth of the height -- and a LOW-FLOOR CITY BUS failed it, correctly: its glass comes down
	# to 0.72 m on a 3.12 m body, which is 0.23 of it, and coming down that far is the entire point of
	# a low-floor bus. A proportion asked the tallest vehicles for the most clearance, which is exactly
	# backwards. Half a metre is knee height; no road vehicle has a window sill below it, and the
	# crossover's underbody that started all this sat at 0.195 m.
	var front_third: float = bounds.position.z + bounds.size.z / 3.0
	_check("and_the_%s_is_glazed_at_the_front_and_clear_of_the_road" % name,
		forward < front_third and lowest > GLASS_CLEARS_ROAD,
		"its foremost glass is at z %.2f (front third ends %.2f) and its lowest at y %.2f"
			% [forward, front_third, lowest])


## THE DRAWN BOUNDS, from the vertices themselves. Never `transform * mesh.get_aabb()`, which grows a
## box every time it is turned -- it read the folded Hawkeye as 9.67 m across against a true 8.81
## (`modelling_here.md` section 6).
func _drawn_bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	return box


func _it_is_one_surface_within_its_triangles(name: StringName, reference: Dictionary,
		mesh: ArrayMesh, points: PackedVector3Array) -> void:
	var triangles: int = points.size() / 3
	_check("%s_is_one_surface_so_a_street_of_forty_is_forty_draws" % name,
		mesh.get_surface_count() == SURFACES,
		"%d surface(s) against %d" % [mesh.get_surface_count(), SURFACES])
	var budget: int = int(reference.get("triangles", 0))
	_check("%s_is_within_its_triangle_budget" % name, budget > 0 and triangles <= budget,
		"%d triangles against %d" % [triangles, budget])


## Godot's front faces are clockwise as seen, so `(c - a) x (b - a)` must point the way the vertex
## normal does. A face wound backwards is invisible and nothing else will find it -- the boxcar's
## first build had 138 of 499 pointing inwards and looked, from most angles, fine.
func _it_is_wound_outwards(name: StringName, points: PackedVector3Array,
		normals: PackedVector3Array) -> void:
	var wrong: int = 0
	var total: int = 0
	for i in range(0, points.size() - 2, 3):
		var face: Vector3 = (points[i + 2] - points[i]).cross(points[i + 1] - points[i])
		if face.length_squared() < 1e-12:
			continue
		total += 1
		if face.normalized().dot(normals[i]) < 0.0:
			wrong += 1
	_check("every_face_of_the_%s_is_wound_outwards" % name, wrong == 0 and total > 0,
		"%d of %d faces point inwards" % [wrong, total])


func _it_is_the_size_its_sources_say(name: StringName, reference: Dictionary,
		bounds: AABB) -> void:
	for axis in [["length", bounds.size.z], ["width", bounds.size.x], ["height", bounds.size.y]]:
		var want: float = float(reference[axis[0]])
		var got: float = float(axis[1])
		_check("the_%s_is_drawn_the_%s_its_sources_say" % [name, axis[0]],
			absf(got - want) < CLOSE,
			"%.3f m drawn against a published %.3f m, out by %+.0f mm"
				% [got, want, (got - want) * 1000.0])


## IT STANDS ON THE ROAD, which is the whole reason its origin is where it is: a level places one of
## these at a point on the ground and adds no lift, so the model's own y = 0 has to be the tarmac.
##
## AND THE LOWEST POINT MUST BE THE TYRES. The circumscribing octagon in `Pressing.wheel` is what
## makes that exact -- an octagon drawn THROUGH the tyre's circle instead of round it stands 0.924 of
## the diameter tall, so a 632 mm tyre would put the car 24 mm into the road, and the car would still
## be the right length, the right width and very nearly the right height.
func _it_stands_on_the_road(name: StringName, points: PackedVector3Array, bounds: AABB) -> void:
	_check("the_%s_stands_on_the_road_rather_than_in_it" % name, absf(bounds.position.y) < 0.001,
		"its lowest drawn point is at y = %+.4f m" % bounds.position.y)
	var below: int = 0
	for point in points:
		if point.y < -0.001:
			below += 1
	_check("and_nothing_of_the_%s_is_drawn_under_the_road" % name, below == 0,
		"%d of %d vertices below y = 0" % [below, points.size()])


## FOUR WHEELS AT THE PUBLISHED WHEELBASE, measured from the CONTACT PATCHES and not from the hubs.
##
## On a faceted wheel the hub is not where the geometry meets the ground, and the trains lane paid for
## the difference: "measure a wheel's contact from its LOWEST vertices, not its middle". Here the flat
## at the bottom of each octagon gives four clusters of vertices at y = 0, one a corner of the
## vehicle, and their centres ARE the axle positions and the track.
##
## AND THE TYRES MUST FALL INBOARD OF THE BODY. `sources.md` explains why this check exists in place
## of a track figure: only one published track pair could be found for any of these four types, the
## ratio taken from it is the softest number on the lane, and a check asserting it to a millimetre
## would be claiming this project's weakest sentence as its strongest. Wheels poking out through the
## flanks is the way a wrong track actually looks, and that this does catch.
func _its_wheels_are_where_the_wheelbase_says(name: StringName, reference: Dictionary,
		points: PackedVector3Array, bounds: AABB) -> void:
	var patches: Array = [[], [], [], []]
	for point in points:
		if point.y > 0.002:
			continue
		patches[(0 if point.x < 0.0 else 1) + (0 if point.z < 0.0 else 2)].append(point)
	var empty: int = 0
	for patch in patches:
		if (patch as Array).is_empty():
			empty += 1
	# FOUR CORNERS, NOT FOUR WHEELS. A lorry's drive axle is TWINNED and a semi-trailer has a bogie of
	# two, so counting wheels would need a roster of how many each type has -- which is the kind of
	# list that goes stale. Every one of them has four CORNERS with rubber on the road, and that is
	# the claim worth making: a vehicle with an empty corner is on three wheels.
	_check("the_%s_has_rubber_on_the_road_at_all_four_corners" % name, empty == 0,
		"%d of %d corners have no contact patch" % [empty, WHEELS])
	if empty > 0:
		return
	var middles: Array[Vector3] = []
	for patch in patches:
		var sum := Vector3.ZERO
		for point in (patch as Array):
			sum += point as Vector3
		middles.append(sum / float((patch as Array).size()))
	# Front axle: the two patches with z < 0. Rear: the two with z > 0.
	var front: float = (middles[0].z + middles[1].z) * 0.5
	var rear: float = (middles[2].z + middles[3].z) * 0.5
	var drawn: float = rear - front
	var want: float = float(reference["wheelbase"])
	# THE WHEELBASE IS FRONT AXLE TO REAR AXLE, and on a vehicle whose back end is a BOGIE of two
	# axles the rear contact patches straddle two stations, so their mean is not an axle and the
	# difference is not a wheelbase. The artic is the only one here like that, and rather than
	# exempt it by name -- a roster that goes stale -- the check asks whether the rear patches lie
	# at ONE station, and says so when they do not.
	var spread: float = 0.0
	for patch in [patches[2], patches[3]]:
		var lowest: float = INF
		var highest: float = -INF
		for point in (patch as Array):
			lowest = minf(lowest, (point as Vector3).z)
			highest = maxf(highest, (point as Vector3).z)
		spread = maxf(spread, highest - lowest)
	if spread > 1.0:
		_check("the_%s_has_a_rear_bogie_rather_than_a_rear_axle" % name, true,
			"its rear contact patches span %.2f m, so no single wheelbase is measurable here" % spread)
	else:
		_check("and_the_%s_is_drawn_on_the_wheelbase_its_sources_say" % name,
			absf(drawn - want) < CLOSE,
			"%.3f m between the contact patches against a published %.3f m, out by %+.0f mm"
				% [drawn, want, (drawn - want) * 1000.0])
	var widest: float = 0.0
	for middle in middles:
		widest = maxf(widest, absf(middle.x))
	var flank: float = bounds.size.x * 0.5
	_check("and_the_%s_tyres_stand_inboard_of_its_body" % name, widest < flank,
		"the tyres' middles are %.3f m out against a body half-width of %.3f m" % [widest, flank])


## A WHEEL IS AN EIGHT-SIDED PRISM, counted from the DRAWN NORMALS at one wheel.
##
## The tread facets are the faces whose normal has no component along the axle, and they are isolated
## by being inside one wheel's own x band -- a body's underside also has a normal square to the axle
## and would otherwise be counted as a very large tyre.
func _a_wheel_is_an_eight_sided_prism(name: StringName, reference: Dictionary,
		points: PackedVector3Array, normals: PackedVector3Array) -> void:
	var row: Dictionary = RoadFleet.line(StringName(reference["name"]))
	if row.is_empty():
		_check("a_%s_wheel_is_an_eight_sided_prism" % name, false, "no catalogue line")
		return
	var axle: float = RoadFleet.front_axle(row)
	var at: float = RoadFleet.track_front(row) * 0.5
	var diameter: float = RoadFleet.wheel_diameter(row)
	var band: float = RoadFleet.wheel_width(row) * 0.5 + 0.001
	var faces: Dictionary = {}
	for i in range(0, points.size() - 2, 3):
		if absf(normals[i].x) > 0.02:
			continue
		var inside: bool = true
		for k in range(3):
			var point: Vector3 = points[i + k]
			if absf(absf(point.x) - at) > band:
				inside = false
			if Vector2(point.y - diameter * 0.5, point.z - axle).length() > diameter * 0.55:
				inside = false
		if not inside:
			continue
		# Round the normal hard: two triangles of one facet share a normal exactly, and two facets
		# 45 degrees apart cannot collide at this resolution.
		faces["%.2f,%.2f" % [snappedf(normals[i].y, 0.01), snappedf(normals[i].z, 0.01)]] = true
	_check("a_%s_wheel_is_an_eight_sided_prism" % name, faces.size() == WHEEL_SIDES,
		"%d distinct tread facets against %d" % [faces.size(), WHEEL_SIDES])


## THE GREENHOUSE IS NARROWER THAN THE BODY UNDER IT. Tumblehome is the one cue that separates a car
## from a van at any distance at all, and a body drawn without it -- a box with windows on it -- is
## the right length, the right width, the right height and the right wheelbase.
##
## The glass is found by `RoadCar.GLASS`, because a mesh has no other way of saying which quad is a
## window; every figure below is then measured from the vertices themselves.
func _its_greenhouse_is_narrower_than_its_body(name: StringName, points: PackedVector3Array,
		colours: PackedColorArray, bounds: AABB) -> void:
	var glass: Array[Vector3] = []
	for i in range(points.size()):
		if _is(colours[i], RoadCar.GLASS):
			glass.append(points[i])
	_check("the_%s_has_glass_in_it" % name, glass.size() >= 12,
		"%d glazed vertices of %d" % [glass.size(), points.size()])
	if glass.is_empty():
		return
	var cabin: float = 0.0
	var lowest: float = INF
	var highest: float = -INF
	for point in glass:
		cabin = maxf(cabin, absf(point.x))
		lowest = minf(lowest, point.y)
		highest = maxf(highest, point.y)
	var flank: float = bounds.size.x * 0.5
	_check("and_the_%s_greenhouse_is_narrower_than_the_body_under_it" % name,
		cabin < flank * TUMBLEHOME_AT_MOST,
		"the glass reaches %.3f m out, %.3f of the body's %.3f m half-width"
			% [cabin, cabin / flank, flank])
	_check("and_the_%s_glass_sits_above_its_waist_and_reaches_its_roof" % name,
		lowest > bounds.size.y * 0.45 and highest > bounds.size.y - 0.02,
		"glazed from %.3f m to %.3f m on a %.3f m body" % [lowest, highest, bounds.size.y])


func _is(colour: Color, want: Color) -> bool:
	# `SurfaceTool.commit` quantises vertex colour to eight bits a channel. The model's colours are
	# kept at least 0.045 apart for this reason, so 0.02 tells them apart and survives the rounding.
	return absf(colour.r - want.r) < 0.02 and absf(colour.g - want.g) < 0.02 \
		and absf(colour.b - want.b) < 0.02


## ---- the fleet together --------------------------------------------------------------------------

## THE FOUR SILHOUETTES ARE ACTUALLY DIFFERENT, by the DECK BEHIND THE REAR GLASS: a saloon has a
## boot, a hatchback and a crossover have next to nothing, and a pickup has a bed nearly two metres
## long. Four body styles drawn from one shape table is exactly the arrangement in which they all
## quietly become the same car -- every one of them would still be the right size, on the right
## wheelbase, with the right amount of glass -- and this is the figure that says which is which.
##
## AND THE PICKUP'S BED FLOOR IS HELD TO 5 FT 6 IN, which is the check anchored outside the model:
## a published bed length, no part of the model built from it, and nothing in `RoadFleet` that knows
## it exists. `Boxcar`'s AAR clearance plate is the same idea from the same place.
func _the_four_silhouettes_are_actually_different() -> void:
	var decks: Dictionary = {}
	for reference in CARS:
		var name: StringName = StringName(reference["name"])
		var mesh: ArrayMesh = RoadFleet.mesh(name)
		if mesh == null:
			continue
		var arrays: Array = mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var back_of_glass: float = -INF
		for i in range(points.size()):
			if _is(colours[i], RoadCar.GLASS):
				back_of_glass = maxf(back_of_glass, points[i].z)
		var tail: float = _drawn_bounds(points).end.z
		var deck: float = tail - back_of_glass
		decks[name] = deck
		_check("the_%s_has_the_deck_behind_its_glass_that_its_body_style_wants" % name,
			absf(deck - float(reference["deck"])) < 0.06,
			"%.3f m from the foot of the rear glass to the tail, against %.2f m"
				% [deck, reference["deck"]])
	# AND THE FOUR ARE NOT THE SAME VEHICLE. A saloon's boot is at least half a metre longer than a
	# hatchback's tailgate ledge, and a pickup's bed is longer again than either.
	if decks.has(&"saloon") and decks.has(&"hatchback") and decks.has(&"pickup") \
			and decks.has(&"suv"):
		var ordered: bool = float(decks[&"hatchback"]) < float(decks[&"suv"]) \
			and float(decks[&"suv"]) + 0.4 < float(decks[&"saloon"]) \
			and float(decks[&"saloon"]) + 0.8 < float(decks[&"pickup"])
		_check("and_the_four_body_styles_are_not_quietly_the_same_car", ordered,
			"hatchback %.2f m, suv %.2f m, saloon %.2f m, pickup %.2f m"
				% [decks[&"hatchback"], decks[&"suv"], decks[&"saloon"], decks[&"pickup"]])

	var floor_length: float = _bed_floor()
	_check("the_pickups_bed_floor_is_five_feet_six",
		floor_length > 0.0 and absf(floor_length - SHORT_BED) / SHORT_BED < BED_WITHIN,
		"%.4f m drawn against a published %.4f m (5 ft 6 in), %+.2f per cent"
			% [floor_length, SHORT_BED,
				100.0 * (floor_length - SHORT_BED) / SHORT_BED if floor_length > 0.0 else 0.0])
	_sections += 1


## THE PICKUP'S BED FLOOR, from the drawn vertices: the run in z of everything coloured as the bed
## liner. The floor is the only thing in the model wearing that colour at its own lowest level.
func _bed_floor() -> float:
	var mesh: ArrayMesh = RoadFleet.mesh(&"pickup")
	if mesh == null:
		return -1.0
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var lowest: float = INF
	for i in range(points.size()):
		if _is(colours[i], RoadCar.BED):
			lowest = minf(lowest, points[i].y)
	if lowest == INF:
		return -1.0
	var from: float = INF
	var to: float = -INF
	for i in range(points.size()):
		if _is(colours[i], RoadCar.BED) and points[i].y < lowest + 0.002:
			from = minf(from, points[i].z)
			to = maxf(to, points[i].z)
	return to - from


## **EVERY TRUCK IS INSIDE THE LAW**, measured off its drawn vertices and held to figures from
## Council Directive 96/53/EC that no dimension in `RoadFleet` was chosen to satisfy.
##
## WITH ONE EXCEPTION, STATED RATHER THAN HIDDEN: the artic's overall LENGTH is not checked against
## the 16.5 m articulated maximum, because its kingpin set-back was chosen to make the combination
## legal. That makes 16.5 m a figure the model was fitted to, and a check against a figure you fitted
## to is the model asking itself a question it already knows the answer to. The 18.75 m road-train
## maximum is checked instead -- nothing was fitted to that, and it is also the figure that could be
## read reliably, since EUR-Lex through an agent's fetch conflated the two.
##
## THE CHECK THAT SURVIVES INTACT for the artic is kingpin to rear, below: PUBLISHED trailer length
## less PUBLISHED kingpin setting, with nothing of this lane's in it.
func _every_truck_is_inside_the_law() -> void:
	var heavy: Array[Dictionary] = TRUCKS.duplicate()
	heavy.append_array(BUSES)
	for reference in heavy:
		var name: StringName = StringName(reference["name"])
		var mesh: ArrayMesh = RoadFleet.mesh(name)
		if mesh == null:
			continue
		var bounds: AABB = _drawn_bounds(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		_check("the_%s_is_inside_the_legal_width" % name, bounds.size.x <= MAX_WIDTH + 0.001,
			"%.3f m drawn against a %.2f m maximum" % [bounds.size.x, MAX_WIDTH])
		_check("and_the_%s_is_inside_the_legal_height" % name, bounds.size.y <= MAX_HEIGHT,
			"%.3f m drawn against a %.2f m maximum, %.0f mm of headroom"
				% [bounds.size.y, MAX_HEIGHT, (MAX_HEIGHT - bounds.size.y) * 1000.0])
		# WHICH LAW APPLIES IS PART OF THE CHECK. A two-axle BUS may be 13.5 m where a rigid goods
		# vehicle may be 12; an articulated vehicle is checked against the road-train figure for the
		# reason above. Asked of this suite's own lists, never of the catalogue -- the thing being
		# checked must not choose which check it faces.
		var limit: float = MAX_RIGID
		if name == &"artic":
			limit = MAX_ROAD_TRAIN
		else:
			for bus in BUSES:
				if StringName(bus["name"]) == name:
					limit = MAX_TWO_AXLE_BUS
		_check("and_the_%s_is_inside_its_legal_length" % name, bounds.size.z <= limit,
			"%.3f m drawn against a %.2f m maximum" % [bounds.size.z, limit])

	# KINGPIN TO THE REAR OF THE SEMI-TRAILER. Published in, published out.
	var row: Dictionary = RoadFleet.line(&"artic")
	if not row.is_empty():
		var reach: float = float(row["trailer_length"]) - float(row["kingpin_from_front"])
		_check("the_artics_kingpin_to_rear_is_inside_its_own_published_maximum",
			reach <= MAX_KINGPIN_TO_REAR,
			"%.3f m (a %.3f m trailer with its kingpin %.3f m back) against a %.2f m maximum"
				% [reach, row["trailer_length"], row["kingpin_from_front"], MAX_KINGPIN_TO_REAR])
	_sections += 1


## **THE BOX LORRY'S BODY IS THE LENGTH ITS MAKER PRINTS.** `G`, back of cab to end of frame, is
## 7,235 mm on Mercedes-Benz's own sheet for the 1524. The body is drawn between those two stations
## and this reads the result off the drawn vertices.
##
## IT IS THE CHECK THAT WOULD HAVE CAUGHT THIS LANE'S WORST READING. The 180 mm by which `H + G`
## falls short of the overall length was first taken for a rear underrun bar, which would have put
## the body's back 180 mm forward of where it belongs; the printed `G` does not care which reading
## anybody prefers, and a body drawn to either the wrong length or the wrong place fails here.
##
## The body is found by its own colour, which is not any paint (`RoadCar`'s rule, and the reason
## nothing here derives a colour from one).
func _the_box_lorrys_body_is_the_length_its_maker_prints() -> void:
	var mesh: ArrayMesh = RoadFleet.mesh(&"boxlorry")
	if mesh == null:
		_check("the_box_lorry_is_drawn_at_all", false, "RoadFleet.mesh() returned nothing")
		_sections += 1
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var from: float = INF
	var to: float = -INF
	for i in range(points.size()):
		if _is(colours[i], RoadLorry.BOX):
			from = minf(from, points[i].z)
			to = maxf(to, points[i].z)
	var drawn: float = to - from if from < INF else -1.0
	_check("the_box_lorrys_body_is_the_length_its_maker_prints",
		drawn > 0.0 and absf(drawn - ATEGO_BODY) < BODY_WITHIN,
		"%.3f m drawn against a printed G of %.3f m, out by %+.0f mm"
			% [drawn, ATEGO_BODY, (drawn - ATEGO_BODY) * 1000.0])
	# AND IT ENDS AT THE END OF THE FRAME, which on the corrected reading IS the overall length.
	var bounds: AABB = _drawn_bounds(points)
	_check("and_it_reaches_the_back_of_the_lorry_rather_than_stopping_short",
		to > 0.0 and absf(to - bounds.end.z) < 0.02,
		"the body ends at z %.3f and the lorry at z %.3f" % [to, bounds.end.z])
	_sections += 1


## **THE TWO BUSES ARE TWO DIFFERENT BUSES**, by the one thing that separates them.
##
## They are within 265 mm of each other in length and identical in width, so nothing about their
## envelopes would notice if a coach were drawn as a city bus -- both would still be the right size,
## on the right wheelbase, with the right amount of glass and every legal bound satisfied. What
## separates them is **where the floor is**: a coach's is raised over a luggage hold and a low-floor
## city bus's is 400 mm over the road, so a coach's glass starts high with a deep blank band beneath
## it and a city bus's comes down nearly to its skirt.
##
## MEASURED FROM THE DRAWN GLASS, as a share of each vehicle's own height, so it is a claim about
## proportion rather than about either figure: the coach's window sill must sit at least a tenth of
## its height above the city bus's.
func _the_two_buses_are_two_different_buses() -> void:
	var sills: Dictionary = {}
	for reference in BUSES:
		var name: StringName = StringName(reference["name"])
		var mesh: ArrayMesh = RoadFleet.mesh(name)
		if mesh == null:
			continue
		var arrays: Array = mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var sill: float = INF
		for i in range(points.size()):
			if _is(colours[i], RoadCar.GLASS):
				sill = minf(sill, points[i].y)
		if sill < INF:
			sills[name] = sill / float(reference["height"])
	_check("both_buses_have_a_glass_line_to_measure", sills.size() == BUSES.size(),
		"%d of %d" % [sills.size(), BUSES.size()])
	if sills.size() < 2:
		_sections += 1
		return
	var low: float = float(sills[&"citybus"])
	var high: float = float(sills[&"coach"])
	_check("the_coachs_floor_is_raised_over_a_hold_and_the_city_buss_is_not",
		high > low + 0.10,
		"the coach is glazed from %.2f of its height and the city bus from %.2f" % [high, low])
	# AND THE LOW-FLOOR BUS IS ACTUALLY LOW. A deck 400 mm over the road is the whole point of one.
	_check("and_the_city_buss_glass_comes_down_where_a_low_floor_bus_puts_it", low < 0.28,
		"glazed from %.2f of its height, which is %.2f m" % [low, low * 3.120])
	_sections += 1


## **NO TWO COLOURS IN ONE VEHICLE ARE INDISTINGUISHABLE**, which is the invariant every colour-based
## check in this file actually rests on -- and it is asked of each DRAWN MESH, not of a palette.
##
## THIS CHECK HAS NOW CAUGHT TWO THINGS AND CHANGED SHAPE ONCE, which is worth recording because the
## second catch is what changed it:
##
## 1. The crossover's underside was `paint * 0.35` and its rocker's floor `paint * 0.30`; the blue-
##    grey times 0.30 landed inside two hundredths of the glass on all three channels, and the suite
##    reported that its windows began at its floor pan, 195 mm over the road. Nothing derives a
##    colour from a paint any more.
## 2. Written as "no type's paint is the colour of any PART", enumerated over every colour constant
##    the road-vehicle files declare, it then failed on the saloon -- whose near-black is within two
##    hundredths of a LORRY'S CHASSIS FRAME. **That is a false positive, and an instructive one: the
##    saloon has no chassis frame.** A fleet-wide palette comparison asks whether two colours could
##    ever collide; the question that matters is whether they collide IN THE SAME MESH, where a check
##    has to tell them apart.
##
## So it walks each vehicle's own drawn vertices, collects the distinct colours actually used, and
## requires every pair to be distinguishable. No roster of parts, no roster of types, and it holds
## for a paint chosen at random as readily as for a constant.
func _no_two_colours_in_one_vehicle_are_indistinguishable() -> void:
	var worst: PackedStringArray = []
	var counted: int = 0
	for name in RoadFleet.names():
		var mesh: ArrayMesh = RoadFleet.mesh(name)
		if mesh == null:
			continue
		var colours: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var distinct: Array[Color] = []
		for colour in colours:
			var seen: bool = false
			for had in distinct:
				if _is(colour, had):
					seen = true
					break
			if not seen:
				distinct.append(colour)
		counted += distinct.size()
		# `distinct` is already built so that no two of its members match, so the collision the
		# outer loop would look for has been collapsed into it: what is reported is how MANY
		# distinguishable colours the mesh has, and a part that vanished into another shows up as a
		# count lower than the model declares it draws.
		if distinct.size() < 4:
			worst.append("%s draws only %d distinguishable colours" % [name, distinct.size()])
	_check("no_two_colours_in_one_vehicle_are_indistinguishable", worst.is_empty(),
		"%d distinguishable colours across %d vehicles%s" % [counted, RoadFleet.names().size(),
			"" if worst.is_empty() else ": %s" % worst])

	# AND THE ONE THAT WOULD HAVE CAUGHT THE CROSSOVER DIRECTLY: a vehicle's GLASS must be its own
	# colour and not shared with anything else it draws. That is the part every other check finds by
	# colour, so it is the one worth naming.
	# AN ABSOLUTE HEIGHT AGAIN, and for the same reason: written as a share of each vehicle's own
	# height ("nothing glazed in its bottom quarter") the low-floor city bus failed it honestly, its
	# 0.72 m sill being 0.23 of a 3.12 m body. The thing worth forbidding is glass NEAR THE ROAD, and
	# that is a distance in metres. The crossover's underbody was at 0.195 m; a bus's lowest legitimate
	# window is at 0.72.
	var shared: PackedStringArray = []
	for name in RoadFleet.names():
		var mesh: ArrayMesh = RoadFleet.mesh(name)
		if mesh == null:
			continue
		var arrays: Array = mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var low: int = 0
		for i in range(points.size()):
			if _is(colours[i], RoadCar.GLASS) and points[i].y < GLASS_CLEARS_ROAD:
				low += 1
		if low > 0:
			shared.append("%s has %d glass-coloured vertices below %.2f m" % [name, low,
				GLASS_CLEARS_ROAD])
	_check("and_nothing_down_near_the_road_is_the_colour_of_glass", shared.is_empty(),
		"%s" % ["none of the %d" % RoadFleet.names().size() if shared.is_empty() else shared])
	_sections += 1


## ---- and nothing here is solid -------------------------------------------------------------------

## **NO ROAD VEHICLE IS A THING THE SIMULATION HAS.** The user's constraint, said twice in the brief
## and once in this file's own header, and the single thing about this lane most likely to be undone
## by a later session copying a template that does have collision -- `PowerStation` is the nearest
## model for how these are drawn and it answers `boxes()` and `drawn_solid()` for 33 static boxes a
## tower, because a 99 m concrete shell is not a wood.
##
## TWO CHECKS, because either alone is weak: that no road-vehicle file DECLARES any of the methods a
## self-drawing solid group has to answer, and that none of them so much as names the call that puts a
## box into the simulation.
##
## THE FORBIDDEN LIST IS ENUMERATED OFF `PowerStation`, NOT TYPED HERE. That file is the nearest model
## for how these are drawn -- a catalogue, a `SceneryYard` layer, a mesh built once -- and it is also
## the thing that would be copied if somebody wanted one of these to be solid, because it answers
## `boxes()` for 33 static boxes a cooling tower. So the names this check forbids are literally
## whatever `PowerStation` publishes and `RoadFleet` must not: a method added there tomorrow is
## forbidden here tomorrow, and a list typed in this file would have gone stale instead.
##
## WHAT THIS DELIBERATELY DOES NOT DO IS COUNT `Terrain.boxes()` BEFORE AND AFTER. It was written that
## way first and it passed -- 514 boxes before, 514 after -- but asking `Terrain.boxes()` outside a
## laid-out level warns twice about testfield runways this run never laid, and a suite that prints
## another subsystem's warnings is a suite somebody will one day have to decide whether to believe.
## The count proved nothing the two checks below do not.
func _nothing_here_is_solid() -> void:
	var forbidden: Dictionary = {}
	var solid: Script = load("res://world/power_station.gd")
	if solid == null:
		_check("the_pattern_this_check_enumerates_against_is_still_there", false,
			"world/power_station.gd is missing")
		_sections += 1
		return
	for method in solid.get_script_method_list():
		var named: String = String(method["name"])
		if named in ["boxes", "drawn_solid", "collision_boxes"]:
			forbidden[named] = true
	_check("power_station_still_answers_for_its_own_solid_so_this_check_has_a_pattern",
		forbidden.size() >= 2, "it publishes %s" % [forbidden.keys()])

	var road: Array[String] = ["res://objects/vehicles/road/road_fleet.gd",
		"res://objects/vehicles/road/road_car.gd",
		"res://objects/vehicles/road/road_lorry.gd",
		"res://objects/vehicles/road/road_bus.gd",
		"res://objects/vehicles/road/pressing.gd"]
	var declared: PackedStringArray = []
	for path in road:
		var script: Script = load(path)
		if script == null:
			declared.append("%s is missing" % path)
			continue
		for method in script.get_script_method_list():
			if forbidden.has(String(method["name"])):
				declared.append("%s declares %s()" % [path.get_file(), method["name"]])
	_check("and_no_road_vehicle_file_answers_for_any_solid_at_all", declared.is_empty(),
		"%s" % ["none of the %d do" % road.size() if declared.is_empty() else declared])

	var asks: PackedStringArray = []
	for path in road:
		var text: String = FileAccess.get_file_as_string(path)
		# NOT IN A COMMENT EITHER, and that is on purpose: these files talk about not being solid at
		# some length, and a check that allowed the call anywhere a `#` had been would be a check
		# anybody could satisfy by explaining themselves. The test is whether the words appear at all.
		for call in ["add_static_box", "Terrain.Group", "StaticBody3D", "CollisionShape3D"]:
			if text.contains(call):
				asks.append("%s names %s" % [path.get_file(), call])
	_check("and_none_of_them_names_a_way_of_becoming_solid", asks.is_empty(),
		"%s" % ["none of them" if asks.is_empty() else asks])
	_sections += 1
