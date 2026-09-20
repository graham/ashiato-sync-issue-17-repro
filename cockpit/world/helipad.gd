@tool
extends RefCounted
class_name Helipad
## A MARKED CONCRETE PAD FOR A HELICOPTER OR A VTOL AEROPLANE, and the one place the size of such a pad is decided.
##
## THE USER ASKED FOR THIS (2026-09-19): "since it's likely that helicopters might land there, make sure there concrete
## spaces to do land helicopters and other vtol planes". Both shore structures carry one, and both get it from here
## rather than each typing a number -- a pad at the marina and a pad at the terminal that disagreed about how big a
## Chinook is would be two different bugs waiting.
##
## THE SIZE COMES FROM THE D-VALUE, which is the standard's own rule and not an invention. CAP 437 (UK CAA, *Standards
## for Offshore Helicopter Landing Areas*) defines the D-value as THE LARGEST OVERALL DIMENSION OF THE HELICOPTER WITH
## ITS ROTORS TURNING -- normally from the most forward point of the main rotor's tip path to the most rearward point of
## the tail rotor's -- and requires the usable landing area to be at least 1.0 x D across, with 1.5 x D preferred for
## margin. ICAO Annex 14 Volume II carries the same idea for onshore heliports.
##
## AND THE D-VALUE IS DERIVED FROM THE GAME'S OWN AIRCRAFT, NOT TYPED. `d_value_of` reads the hub positions and rotor
## diameter each airframe already declares, because a pad sized against a number somebody typed is a pad that stops being
## right the day an airframe is re-measured. The brief was explicit about this and it paid immediately:
##
##   THE CHINOOK GOVERNS. `ChinookAirframe` puts its hubs at z -5.90 and +5.90 and its rotors at 18.3 m across, so its
##   overall dimension with the rotors turning is 5.90 + 5.90 + 18.30 = **30.10 m**. CAP 437's own table gives the
##   CH-47 a D-value of **30 m**. Two figures that never saw each other, 0.3 per cent apart -- the workshop's favourite
##   kind of evidence (`modelling_here.md` section 3), and the reason this pad's size can be trusted.
##
## Everything else that may use these pads is smaller and is dominated rather than measured: the Osprey is 25.77 m
## across its rotors (`OspreyAirframe.WIDTH`), the UH-60's rotor is 16.36 m, the Little Bird's 8.35 m, and the F-35B is a
## 15.6 m aeroplane. A pad that takes a Chinook takes all of them, which is why the largest is the only one that has to
## be got exactly right.
##
## THE PAD IS DRAWN, NOT JUST SIZED: a concrete slab, the D-circle painted round the touchdown point, the letter H in the
## middle, and a chevron at the pad's edge marking the obstacle-free approach. Markings are what give a flat slab its
## scale -- a carrier helm picture once read as a few metres off the deck because the deck had none
## (`modelling_here.md` section 7).

const CONCRETE := Color(0.62, 0.61, 0.58)
const CONCRETE_DARK := Color(0.54, 0.53, 0.50)
const MARKING := Color(0.92, 0.92, 0.90)
const CHEVRON := Color(0.88, 0.72, 0.16)
## The slab's thickness, and how far the paint stands over it so it does not fight the concrete for the same pixels.
const SLAB: float = 0.35
const PAINT_UP: float = 0.02
## The D-circle's stroke, and the H's.
const CIRCLE_WIDE: float = 0.75
const LETTER_WIDE: float = 0.90
## How many sides the D-circle is drawn on. Low-poly on purpose (`modelling_here.md` section 4): the Hawkeye's rotodome
## lens is 32 and nothing here is rounder than half of that.
const CIRCLE_SIDES: int = 16


## THE D-VALUE OF THE LARGEST THING THAT MAY LAND HERE, in metres, worked out from the airframes themselves.
##
## A TANDEM ROTOR IS ITS TWO DISCS END TO END: hub separation plus one rotor diameter, because the discs overlap in plan
## and the outer edges are what the pad has to hold. A single main rotor is dominated by the Chinook here and is not
## computed, which is stated rather than hidden -- if a bigger single-rotor machine is ever added this function is where
## it goes, and `shore_structures.gd` will fail until it does.
static func governing_d_value() -> float:
	var tandem: float = absf(ChinookAirframe.REAR_HUB.z - ChinookAirframe.FRONT_HUB.z) + ChinookAirframe.ROTOR_DIAMETER
	return maxf(tandem, OspreyAirframe.WIDTH)


## HOW WIDE A PAD HAS TO BE, at a given multiple of D. CAP 437 asks 1.0 x D as a minimum and prefers 1.5 x D; a shore
## structure with room uses the preferred figure and one without uses the minimum, and both say which they used.
static func across_for(multiple: float) -> float:
	return governing_d_value() * multiple


## THE PAD, BUILT INTO A CALLER'S TOOL: a square slab `across` metres on a side, centred on (x, z) with its TOP at `top`,
## with the D-circle, the H and an approach chevron on it. Returns the slab's box so the caller can report it and a suite
## can ask how big it is and what stands over it.
static func build_into(tool: SurfaceTool, at: Vector3, across: float, facing: Vector3 = Vector3.FORWARD) -> AABB:
	var half: float = across * 0.5
	Plating.box(tool, Vector3(at.x, at.y - SLAB * 0.5, at.z), Vector3(across, SLAB, across), CONCRETE)
	# A DARKER APRON RING inside the edge, so the slab does not read as one flat colour from the air.
	Plating.box(tool, Vector3(at.x, at.y - SLAB * 0.5 + 0.01, at.z),
		Vector3(across * 0.86, SLAB * 0.9, across * 0.86), CONCRETE_DARK)
	var paint_at: float = at.y + PAINT_UP
	# THE D-CIRCLE, at 0.9 of the usable width so it sits inside the edge as the standard draws it.
	_ring(tool, Vector3(at.x, paint_at, at.z), half * 0.90, CIRCLE_WIDE, MARKING)
	_letter_h(tool, Vector3(at.x, paint_at, at.z), half * 0.42)
	# THE APPROACH CHEVRON on the side the pad is entered from, which is also what tells a pilot the pad's heading.
	var along: Vector3 = facing.normalized()
	var side: Vector3 = Vector3.UP.cross(along).normalized()
	var nose: Vector3 = Vector3(at.x, paint_at, at.z) + along * (half * 0.94)
	for wing in [-1.0, 1.0]:
		var out: Vector3 = nose + side * (wing * half * 0.30) - along * (half * 0.22)
		Plating.quad(tool, [nose, nose - along * 0.9, out - along * 0.9, out], CHEVRON)
	return AABB(Vector3(at.x - half, at.y - SLAB, at.z - half), Vector3(across, SLAB, across))


## A PAINTED RING, drawn as a band of flat quads on the deck.
static func _ring(tool: SurfaceTool, at: Vector3, radius: float, wide: float, tint: Color) -> void:
	var inner: float = radius - wide * 0.5
	var outer: float = radius + wide * 0.5
	for i in range(CIRCLE_SIDES):
		var a: float = TAU * float(i) / float(CIRCLE_SIDES)
		var b: float = TAU * float(i + 1) / float(CIRCLE_SIDES)
		Plating.quad(tool, [
			at + Vector3(cos(a) * outer, 0.0, sin(a) * outer),
			at + Vector3(cos(b) * outer, 0.0, sin(b) * outer),
			at + Vector3(cos(b) * inner, 0.0, sin(b) * inner),
			at + Vector3(cos(a) * inner, 0.0, sin(a) * inner)], tint)
	return


## THE LETTER H, three bars, `arm` being half its height.
static func _letter_h(tool: SurfaceTool, at: Vector3, arm: float) -> void:
	var span: float = arm * 0.72
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(at.x + side * span, at.y, at.z), Vector3(LETTER_WIDE, 0.04, arm * 2.0), MARKING)
	Plating.box(tool, Vector3(at.x, at.y, at.z), Vector3(span * 2.0, 0.04, LETTER_WIDE), MARKING)
