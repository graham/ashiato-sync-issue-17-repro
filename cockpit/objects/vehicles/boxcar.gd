@tool
extends RefCounted
class_name Boxcar
## A 40 FT STEEL BOXCAR: the car the trains on this island's railway are made of.
##
## WHAT MAKES A BOXCAR A BOXCAR, rather than a shipping container on wheels, is three things and
## none of them is the box: the DOOR in the middle of each side, the low PEAKED roof with a
## running board along its ridge, and the fact that the body sits a metre clear of the rail on
## two trucks well inboard of its ends. The old carriage was a plain 3.0 x 3.6 x 18.0 m box in
## two colours, which is 59 feet long -- half as long again as any boxcar ever built -- and had
## no door, no roof line and no wheels. It read as freight only because it was on a railway.
##
## THE NUMBERS, and where each came from. `cockpit/craft/train/sources.md` carries the full
## table; `cockpit/craft/train/measure_boxcar.py` re-derives every MEASURED one from the
## photograph alone, with nothing typed out of the write-up.
##
##   LENGTH            12.60 m   ESTIMATE. A postwar AAR / Pullman-Standard 40 ft steel boxcar is
##                               a PUBLISHED 40 ft 6 in inside; over the eaves is that plus the
##                               end framing and the roof's overhang, and no source an agent can
##                               read states it. What would settle it: an AAR box car chart.
##   WIDTH              3.20 m   ESTIMATE, 10 ft 6 in, inside the AAR clearance plate's 10 ft 8 in.
##   BODY_DEPTH         3.30 m   MEASURED: 0.2616 of the length, sill to eaves, off a true
##                               broadside (rms 2.3 px on the roof, 2.5 px on the sill).
##   DOOR_WIDE          2.13 m   MEASURED: 0.1692 of the length. See the cross-check below.
##   TRUCK_CENTRES      9.55 m   MEASURED: 0.758 of the length, +/- about 4 per cent -- the
##                               outboard end of one truck runs into the draft gear at the same
##                               black, so the two trucks measured 56 per cent apart in length.
##   WHEEL              0.838 m  PUBLISHED: 33 in, the AAR standard freight wheel.
##   TRUCK_WHEELBASE    1.676 m  PUBLISHED: 5 ft 6 in, the AAR standard freight truck.
##   SILL_OVER_RAIL     1.00 m   ESTIMATE, and see the third quantity below.
##
## TWO CROSS-CHECKS THAT NOTHING WAS FITTED TO, which is why they are worth quoting:
##
## 1. **The door comes out at 7 ft 0 in.** It was measured as a fraction of the car's length and
##    scaled by the class length, and a 40 ft boxcar was built with a 6 ft or a 7 ft door and
##    nothing else. Landing on one of the two, from a ratio and a published class, is evidence.
##    The truck centres land at 31 ft against a standard 30 ft by the same route.
## 2. **The roof lands under the clearance plate.** The MEASURED body depth of 3.30 m plus an
##    ESTIMATED 1.00 m sill height puts the eaves at 4.30 m, the ridge at 4.47 m and the top of
##    the running board on it at **4.53 m -- 14 ft 10 in** -- against AAR clearance Plate B,
##    which stops at 15 ft 1 in. Two things that never saw each other, one measured and one
##    assumed, add up to a figure a published bound can judge, and it lands 6 cm inside it.
##    That is what sets SILL_OVER_RAIL: it is chosen so the sum comes out at a real extreme
##    height rather than typed from a source, and it says so here. `tests/train_models.gd`
##    reads the height off the DRAWN vertices and holds it to the plate, and nothing in this
##    file knows the plate exists -- which is the only reason that check can catch anything.
##
## THE TESSELLATION, stated so nobody improves it later (`modelling_here.md` section 4, and the
## user on 2026-09-17: "keep a somewhat lower poly look to models, not too many very round
## edges"). **A WHEEL IS AN EIGHT-SIDED PRISM.** Nothing else here is round at all: the body,
## the roof's two slopes, the door, the ribs, the underframe and the truck frames are flat
## boxes with a hard crease at every edge. Eight wheels a car, eight sides each. Retessellating
## must not move a single dimension above; the suite measures them from the drawn vertices.
##
## ONE MESH, ONE MATERIAL, BUILT ONCE. Every car in the game is an instance of the same
## `ArrayMesh`, so ten cars behind a locomotive cost one mesh and ten draws rather than ten
## meshes. Colour is in the vertices, through `Plating`, which winds every face clockwise as
## seen and gives it its own normal -- `SurfaceTool.generate_normals` would smooth across the
## creases and hand back exactly the rounded look this model is not supposed to have.

const PLATING := preload("res://objects/vehicles/ships/plating.gd")
const PERMANENT_WAY := preload("res://world/permanent_way.gd")

## ---- the envelope. See the table above for the tag on each. ----------------------------
const LENGTH: float = 12.60
const WIDTH: float = 3.20
const BODY_DEPTH: float = 3.30
const SILL_OVER_RAIL: float = 1.00
## The roof's ridge over the eaves. A boxcar roof is a shallow peak, not a dome.
const RIDGE_RISE: float = 0.17
## How far the eaves stand out beyond the side. It has to be MORE than anything else on the
## side stands proud -- the door, its track and the ribs -- or the car's drawn width is the
## width of a door track and the check that reads it back is measuring the wrong thing.
const EAVES_OUT: float = 0.09

## HOW FAR A COUPLER REACHES past the end of the body. ESTIMATE: it is what makes the couplers
## of two cars in a rake just touch, and it is the only number the spacing needs.
const COUPLER_REACH: float = 0.44
## HOW FAR APART two cars are placed along the track. Computed, never typed: a rake whose
## spacing and whose car length disagree is a rake with gaps in it or a rake inside itself, and
## the old pair (21.0 m between 18.0 m boxes) left a three-metre gap at every coupling.
const SPACING: float = LENGTH + COUPLER_REACH * 2.0

## ---- what is on it ---------------------------------------------------------------------
const DOOR_WIDE: float = 2.13
## The door opening's own height. It stops short of the eaves: the door track runs above it.
const DOOR_HIGH: float = 2.62
## Four side ribs each side of the door, which is what a steel boxcar's side is divided into.
const RIBS_EACH_SIDE: int = 4
const RIB_WIDE: float = 0.11
const RIB_PROUD: float = 0.045

## ---- the running gear ------------------------------------------------------------------
const TRUCK_CENTRES: float = 9.55
const TRUCK_WHEELBASE: float = 1.676
const WHEEL_DIAMETER: float = 0.838
const WHEEL_WIDE: float = 0.14
## HOW MANY SIDES A WHEEL HAS. Eight. Read the tessellation note above before changing it.
const WHEEL_SIDES: int = 8
## Half the distance between the two wheels of an axle, to the middle of the tread: over the middle of each railhead,
## ASKED of the track. It was a typed 0.72 beside a track drawn at a typed 0.72, both 3.5 cm inside standard gauge.
const WHEEL_ACROSS: float = PERMANENT_WAY.RAIL_CENTRES * 0.5

## ---- the colours, sampled and stated ---------------------------------------------------
## Boxcar red. The reference car photographs at sRGB (0.447, 0.266, 0.271) under overcast, which
## carries the sky's blue in it; the blue is taken back out and nothing else is changed.
const PAINT := Color(0.43, 0.24, 0.20)
## The door and the roof are the same paint a shade down, so the door reads as a door at
## distance rather than as a line: a flat side in one colour has no door at all from 500 m.
const DOOR_PAINT := Color(0.36, 0.20, 0.17)
## Weathered galvanised roof sheet, which on every photograph of one is DARKER than the side
## and not lighter: a pale roof reads as a brim round the car from any angle above it.
const ROOF_PAINT := Color(0.235, 0.230, 0.225)
## THE TWO DARKS ARE KEPT WELL APART, and that is not a matter of taste: `SurfaceTool.commit`
## quantises vertex colour to eight bits a channel, so a check that picks the wheels out by
## their colour needs a gap it can still see afterwards. At 0.03 apart it could not, and the
## suite found no wheels at all on a car with eight of them.
const UNDER_PAINT := Color(0.13, 0.13, 0.14)
const WHEEL_PAINT := Color(0.05, 0.05, 0.06)

## Where the eaves and the ridge are, over the railhead. Computed, never typed: the check that
## the ridge clears no clearance plate is worthless if the number it reads was typed beside it.
static func eaves() -> float:
	return SILL_OVER_RAIL + BODY_DEPTH


static func ridge() -> float:
	return eaves() + RIDGE_RISE


## THE MESH, built once and handed to every car. `_shared` is the whole reason a rake of ten
## costs what one costs.
static var _shared: ArrayMesh = null


static func mesh() -> ArrayMesh:
	if _shared == null:
		_shared = build()
	return _shared


## The material every car is drawn with. Vertex colour AS SRGB: without the flag Godot reads
## vertex colour as linear and a 0.43 red comes back near orange (`ShipHull.painted`).
static func painted() -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = 0.82
	return paint


## ONE CAR, its origin ON THE RAILHEAD and centred along its own length, -Z forward.
##
## The origin is the railhead rather than the body's middle because everything on a railway is
## placed by `rail_pose`, whose lift is along the TRACK's up -- so a model that carries its own
## heights in its own frame leans out of a banked corner correctly and needs no lift at all.
## The old carriage was lifted by half its own height and the height was typed in two files.
static func build() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = LENGTH * 0.5
	var side: float = WIDTH * 0.5
	var sill: float = SILL_OVER_RAIL
	var top: float = eaves()

	# THE BODY. One box, sill to eaves.
	PLATING.box(tool, Vector3(0.0, (sill + top) * 0.5, 0.0), Vector3(WIDTH, top - sill, LENGTH), PAINT)

	# THE ROOF: two flat slopes meeting on a ridge, with a gable at each end, standing a little
	# proud of the sides. A shallow peak is the whole of a boxcar's roof and the reason one
	# never reads as a container.
	_roof(tool, half, side, top)

	# THE RUNNING BOARD along the ridge, which is what a roof of that era has on it.
	PLATING.box(tool, Vector3(0.0, ridge() + 0.03, 0.0), Vector3(0.52, 0.06, LENGTH * 0.96), ROOF_PAINT)

	# THE DOOR, on both sides, and the track it hangs from.
	for facing in [-1.0, 1.0]:
		var face: float = facing * (side + 0.03)
		PLATING.box(tool, Vector3(face, sill + DOOR_HIGH * 0.5 + 0.10, 0.0),
			Vector3(0.06, DOOR_HIGH, DOOR_WIDE), DOOR_PAINT)
		PLATING.box(tool, Vector3(face, sill + DOOR_HIGH + 0.18, 0.0),
			Vector3(0.07, 0.10, DOOR_WIDE + 0.60), ROOF_PAINT)
		# THE SIDE RIBS: RIBS_EACH_SIDE of them each side of the door, evenly over the panel
		# between the door and the corner, and never on the door itself.
		var panel_from: float = DOOR_WIDE * 0.5 + 0.25
		var panel_to: float = half - 0.20
		for end in [-1.0, 1.0]:
			for i in range(RIBS_EACH_SIDE):
				var along: float = lerpf(panel_from, panel_to,
					float(i) / float(RIBS_EACH_SIDE - 1)) * end
				PLATING.box(tool, Vector3(facing * (side + RIB_PROUD * 0.5),
					(sill + top) * 0.5, along),
					Vector3(RIB_PROUD, top - sill - 0.10, RIB_WIDE), DOOR_PAINT)

	# THE UNDERFRAME: the centre sill and the draft gear, which is what the body stands on.
	PLATING.box(tool, Vector3(0.0, sill - 0.14, 0.0), Vector3(WIDTH * 0.62, 0.28, LENGTH * 0.99),
		UNDER_PAINT)
	# AND THE COUPLERS, one at each end, because a rake of ten with gaps between them is ten
	# separate wagons rather than a train.
	for end in [-1.0, 1.0]:
		PLATING.box(tool, Vector3(0.0, sill - 0.20, end * (half + COUPLER_REACH * 0.5)),
			Vector3(0.34, 0.26, COUPLER_REACH), UNDER_PAINT)

	# THE TWO TRUCKS.
	for end in [-1.0, 1.0]:
		_truck(tool, end * TRUCK_CENTRES * 0.5)

	# THE BRAKE WHEEL at one end, high up: the one thing that tells you which way round a car is.
	PLATING.box(tool, Vector3(0.0, top - 0.30, half + 0.10), Vector3(0.44, 0.08, 0.06), UNDER_PAINT)
	PLATING.box(tool, Vector3(0.0, sill + 0.60, half + 0.06), Vector3(0.07, top - sill - 0.90, 0.07),
		UNDER_PAINT)

	# NO `generate_tangents`: nothing here is textured, so there are no UVs to generate them
	# from, and asking raised "UVs are required to generate tangents" into the suite's error
	# gate on an otherwise all-green run. A flat-shaded vertex-coloured mesh needs neither.
	return PLATING.weld(tool)


## THE ROOF. `top` is the eaves; the ridge is RIDGE_RISE above it. Four quads and two gables, so
## it is two flat planes with one crease and no curve anywhere.
static func _roof(tool: SurfaceTool, half: float, side: float, top: float) -> void:
	var out: float = side + EAVES_OUT
	var peak: float = ridge()
	for facing in [-1.0, 1.0]:
		# The slope, from the eaves out at the side up to the ridge on the centreline.
		PLATING.facing(tool, [
			Vector3(facing * out, top, -half - EAVES_OUT),
			Vector3(facing * out, top, half + EAVES_OUT),
			Vector3(0.0, peak, half + EAVES_OUT),
			Vector3(0.0, peak, -half - EAVES_OUT),
		], Vector3(facing, 1.0, 0.0).normalized(), ROOF_PAINT)
		# Under the eaves' overhang, so the roof is a lid and not a plane seen edge on.
		PLATING.facing(tool, [
			Vector3(facing * out, top, -half - EAVES_OUT),
			Vector3(facing * out, top, half + EAVES_OUT),
			Vector3(facing * side, top, half + EAVES_OUT),
			Vector3(facing * side, top, -half - EAVES_OUT),
		], Vector3.DOWN, ROOF_PAINT)
	for end in [-1.0, 1.0]:
		var z: float = end * (half + EAVES_OUT)
		_tri(tool, Vector3(-out, top, z), Vector3(out, top, z), Vector3(0.0, peak, z),
			Vector3(0.0, 0.0, end), ROOF_PAINT)


## ONE TRUCK, centred at `at` along the car: two side frames, a bolster and four wheels.
static func _truck(tool: SurfaceTool, at: float) -> void:
	var axle: float = TRUCK_WHEELBASE * 0.5
	var centre: float = WHEEL_DIAMETER * 0.5
	PLATING.box(tool, Vector3(0.0, centre + 0.30, at), Vector3(WIDTH * 0.72, 0.20, 0.46), UNDER_PAINT)
	for across in [-1.0, 1.0]:
		# THE SIDE FRAME IS SHALLOW AND SHORT ON PURPOSE. Drawn 0.44 m deep and reaching past
		# the axles it swallowed the wheels whole, and the trucks came out of the elevation as
		# two featureless dark blocks -- which is what a truck looks like when nothing of its
		# wheels shows above, below or beyond the frame. Every boxcar photograph has the wheels
		# as the clearest thing under the car, so the frame is cut back until they are.
		PLATING.box(tool, Vector3(across * WHEEL_ACROSS, centre, at),
			Vector3(0.15, 0.26, TRUCK_WHEELBASE - 0.20), UNDER_PAINT)
		for along in [-1.0, 1.0]:
			_wheel(tool, Vector3(across * WHEEL_ACROSS, centre, at + along * axle))


## A WHEEL: an eight-sided prism on an axis across the track. Eight, and the doc block says why.
##
## **IT CIRCUMSCRIBES THE REAL WHEEL, IT DOES NOT FIT INSIDE IT**, and that is the whole of what
## makes a faceted wheel the right size. An octagon drawn through the 33 in circle is only
## 0.924 of it across its flats, so it would stand 32 mm low, its tread would sit inside the
## railhead and its rolling radius would be 7.6 per cent short -- a retessellation changing a
## measured dimension, which `modelling_here.md` section 4 forbids. Drawn round the circle
## instead, the flat at the bottom touches the rail exactly where the real tread does and the
## across-flats diameter IS the published 33 in, whatever WHEEL_SIDES becomes. The half-step in
## the angle is what puts a flat at the bottom rather than a corner: a wheel resting on a point
## is a cog.
static func _wheel(tool: SurfaceTool, at: Vector3) -> void:
	var radius: float = (WHEEL_DIAMETER * 0.5) / cos(PI / float(WHEEL_SIDES))
	var half: float = WHEEL_WIDE * 0.5
	var ring: Array[Vector2] = []
	for i in range(WHEEL_SIDES):
		var angle: float = TAU * (float(i) + 0.5) / float(WHEEL_SIDES)
		ring.append(Vector2(cos(angle), sin(angle)) * radius)
	for i in range(WHEEL_SIDES):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % WHEEL_SIDES]
		# The tread: one flat facet per side, its own normal, so the wheel shows its facets.
		PLATING.facing(tool, [
			at + Vector3(-half, a.y, a.x), at + Vector3(half, a.y, a.x),
			at + Vector3(half, b.y, b.x), at + Vector3(-half, b.y, b.x),
		], Vector3(0.0, (a.y + b.y) * 0.5, (a.x + b.x) * 0.5).normalized(), WHEEL_PAINT)
		# And the two faces, as a fan from the middle.
		for face in [-1.0, 1.0]:
			_tri(tool, at + Vector3(face * half, 0.0, 0.0),
				at + Vector3(face * half, a.y, a.x), at + Vector3(face * half, b.y, b.x),
				Vector3(face, 0.0, 0.0), WHEEL_PAINT)


## A TRIANGLE facing `out`. `Plating` has no three-cornered shape -- everything on a ship is a
## quad or a prism -- and `Plating.facing` indexes its fourth corner, so handing it three raised
## "invalid access of index 3" once per gable and once per wheel face, and the first version of
## this model came out with 138 of 499 faces pointing inwards and no wheels at all.
static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3,
		tint: Color) -> void:
	var order: Array[Vector3] = [a, b, c]
	if (c - a).cross(b - a).dot(out) < 0.0:
		order = [a, c, b]
	tool.set_color(tint)
	for corner in order:
		tool.set_normal(out)
		tool.add_vertex(corner)
