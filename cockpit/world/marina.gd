@tool
extends Node3D
class_name Marina
## A SMALL-CRAFT MARINA: a rubble-mound breakwater round the basin, floating pontoons with finger berths off them, a
## fuel dock at the entrance, a harbour office and a boatyard ashore, and a marked concrete pad for a helicopter or a
## VTOL aeroplane clear of every mast.
##
## THE USER ASKED FOR IT (2026-09-19): "a marina and a large dock for container ships are two things that we need that we
## can put near the water", with "concrete spaces to do land helicopters and other vtol planes".
##
## THE BERTHS ARE SIZED BY THE BOATS THAT LIE IN THEM, and those boats already exist. A finger berth's length and the
## width between two fingers come from `SmallCraftDraft.CLASSES` -- the 15.55 m motor yacht is the longest thing here and
## the 7.90 m trawler the widest -- so a berth is never a number somebody typed and the day a boat changes size the
## marina changes with it. That is the same rule the terminal's cranes follow from the Triple-E.
##
## AND THE POINT OF A MARINA IS THAT IT IS SHELTERED, which is a thing with a shape rather than a decoration. The
## breakwater runs round the seaward side with a gap for the entrance, and the entrance faces ALONG the shore rather than
## out to sea, so that a sea running in from seaward does not run straight through it. The pontoons lie behind it.
##
## THE DATUM. The origin is ON THE WATER at the middle of the shoreline, +x inland away from the water, +y up, so a level
## puts a marina down by saying where the shore is and which way the water lies. The basin is at negative x.
##
## THE LOOK. Flat-faced boxes, faceted, as everything here is (`modelling_here.md` section 4). A marina at a distance is
## a breakwater, a grid of pontoons and a scatter of white hulls and masts.

## ---- the water and its edge -------------------------------------------------------------------------------------------

## HOW BIG THE BASIN IS, and how deep it is dredged. A basin has to take the deepest boat with water to spare: the sloop
## draws 2.27 m and the trawler 3.20, so 4.5 m is comfortable. ESTIMATE.
const BASIN_ACROSS: float = 260.0
const BASIN_ALONG: float = 300.0
const BASIN_DEPTH: float = 4.5
## The quay wall along the shore, its deck over the water, and the paved margin behind it.
const QUAY_TOP: float = 1.8
const MARGIN: float = 90.0

## ---- the breakwater --------------------------------------------------------------------------------------------------

## A RUBBLE MOUND: how high its crest stands over the water, how wide that crest is, and the slope of its armour. A
## breakwater is a triangle in section and its footprint is decided by the slope, not by the crest. ESTIMATE, from the
## usual 1-in-2 armour slope and a crest a lorry can drive along.
const MOUND_CREST: float = 4.2
const MOUND_WIDE: float = 7.0
const MOUND_SLOPE: float = 2.0
## The entrance gap, wide enough for two boats to pass. ESTIMATE from the widest boat here.
const ENTRANCE: float = 40.0

## ---- the pontoons ----------------------------------------------------------------------------------------------------

## A FLOATING PONTOON: its freeboard, its width, and the width of a finger off it.
const PONTOON_FREEBOARD: float = 0.45
const PONTOON_WIDE: float = 2.4
const FINGER_WIDE: float = 0.9
## HOW MANY PONTOONS, and how many berths a side. The basin's size decides the rest.
const PONTOONS: int = 4
const BERTHS_A_SIDE: int = 9
## THE MARGIN A BERTH GIVES A BOAT, at each end and each side. ESTIMATE: a metre of warp at the bow and a fender's width
## between neighbours.
const BERTH_SLACK: float = 1.6

const CONCRETE := Color(0.62, 0.61, 0.58)
const ROCK := Color(0.46, 0.45, 0.43)
const ROCK_DARK := Color(0.38, 0.37, 0.36)
const PONTOON := Color(0.70, 0.70, 0.68)
const TIMBER := Color(0.55, 0.45, 0.32)
const SHED := Color(0.86, 0.85, 0.82)
const ROOF := Color(0.32, 0.36, 0.40)
const GLASS := Color(0.12, 0.16, 0.20)
const STEEL := Color(0.42, 0.44, 0.46)
const FUEL := Color(0.84, 0.62, 0.16)

var _parts: Dictionary = {}


## HOW LONG A FINGER BERTH IS: the longest boat the marina is for, plus its slack at each end. DERIVED.
static func berth_length() -> float:
	var longest: float = 0.0
	for boat in SmallCraftDraft.CLASSES:
		longest = maxf(longest, float(SmallCraftDraft.CLASSES[boat]["length"]))
	return longest + BERTH_SLACK * 2.0


## HOW WIDE A BERTH IS, between the middles of two fingers: the widest boat plus slack on each side plus a finger.
static func berth_width() -> float:
	var widest: float = 0.0
	for boat in SmallCraftDraft.CLASSES:
		widest = maxf(widest, float(SmallCraftDraft.CLASSES[boat]["beam"]))
	return widest + BERTH_SLACK * 2.0 + FINGER_WIDE


## A MARINA ON ITS OWN, for the buildings gallery and for a suite.
## BUILT ON CONSTRUCTION, NOT ON `_ready`. The buildings gallery instances a standalone through this factory and
## measures its drawn bounds; a node that waits for `_ready` has no mesh in it at that moment and measures as an
## empty box, which comes out of the arithmetic as -nan and reads like a broken model rather than an empty one.
## `OilPlatform.one` is the precedent: a factory hands back a finished thing.
static func one() -> Marina:
	var made := Marina.new()
	made._build()
	return made


func _ready() -> void:
	if get_child_count() == 0:
		_build()


## Where each part's box is, so a suite can ask of the built thing rather than of a constant.
func parts() -> Dictionary:
	if _parts.is_empty():
		_build()
	return _parts


func _build() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_parts = {}
	_the_shore(tool)
	_the_breakwater(tool)
	_the_pontoons(tool)
	_the_fuel_dock(tool)
	_the_buildings(tool)
	_the_pad(tool)
	var mesh := MeshInstance3D.new()
	mesh.name = "Marina"
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = ShipHull.painted()
	add_child(mesh)


## THE SHORE: a quay wall along the water's edge with a paved margin behind it, and a slipway at one end.
func _the_shore(tool: SurfaceTool) -> void:
	Plating.box(tool, Vector3(MARGIN * 0.5, (QUAY_TOP - BASIN_DEPTH) * 0.5, 0.0),
		Vector3(MARGIN, QUAY_TOP + BASIN_DEPTH, BASIN_ALONG + 60.0), CONCRETE)
	_parts["shore"] = AABB(Vector3(0.0, -BASIN_DEPTH, -(BASIN_ALONG + 60.0) * 0.5),
		Vector3(MARGIN, QUAY_TOP + BASIN_DEPTH, BASIN_ALONG + 60.0))
	# A SLIPWAY running down into the water at the north end, which every marina has and which reads instantly.
	var ramp_z: float = -BASIN_ALONG * 0.38
	Plating.box(tool, Vector3(-7.0, QUAY_TOP * 0.5 - 1.2, ramp_z), Vector3(26.0, 0.6, 14.0), CONCRETE,
		Basis(Vector3(0.0, 0.0, 1.0), -0.16))
	# Bollards and a ladder or two along the quay edge.
	for i in range(int(BASIN_ALONG / 20.0) + 1):
		var z: float = -BASIN_ALONG * 0.5 + float(i) * 20.0
		Plating.box(tool, Vector3(2.2, QUAY_TOP + 0.35, z), Vector3(0.5, 0.7, 0.5), STEEL)


## THE BREAKWATER: two arms of rubble mound, one running out from the shore at each end of the basin, leaving the
## entrance between them. Drawn as a trapezoid in section -- crest, then armour sloping away on both sides.
func _the_breakwater(tool: SurfaceTool) -> void:
	var toe: float = MOUND_WIDE * 0.5 + (MOUND_CREST + BASIN_DEPTH) / MOUND_SLOPE
	var seaward: float = -BASIN_ACROSS
	var arms: Array[AABB] = []
	# THE LONG ARM along the seaward side, from the south end towards the entrance.
	var along_from: float = -BASIN_ALONG * 0.5
	var along_to: float = BASIN_ALONG * 0.5 - ENTRANCE
	_a_mound(tool, Vector3(seaward, 0.0, along_from), Vector3(seaward, 0.0, along_to), toe)
	arms.append(AABB(Vector3(seaward - toe, -BASIN_DEPTH, along_from), Vector3(toe * 2.0,
		MOUND_CREST + BASIN_DEPTH, along_to - along_from)))
	# THE SOUTH ARM, running in from the seaward arm to the shore, closing the basin.
	_a_mound(tool, Vector3(seaward, 0.0, along_from), Vector3(0.0, 0.0, along_from), toe)
	arms.append(AABB(Vector3(seaward, -BASIN_DEPTH, along_from - toe),
		Vector3(-seaward, MOUND_CREST + BASIN_DEPTH, toe * 2.0)))
	# THE SHORT ARM at the north end, overlapping the long one so the ENTRANCE FACES ALONG THE SHORE and not out to
	# sea: a sea running straight in through an entrance is a marina that does not shelter anything.
	# THE LEE ARM OVERLAPS THE SEAWARD ONE rather than continuing past its head, and that overlap IS the shelter. Set
	# beyond it the two arms leave a straight gap looking out to sea, which is a pair of walls with a hole in it and
	# not a marina -- the first version put the lee arm 24 m past the seaward arm's head and `shore_structures.gd`
	# refused it. A boat now comes in past the seaward head and turns, which is what a real entrance makes you do.
	var lee_z: float = along_to - ENTRANCE * 0.35
	_a_mound(tool, Vector3(seaward * 0.75, 0.0, lee_z), Vector3(0.0, 0.0, lee_z), toe)
	arms.append(AABB(Vector3(seaward * 0.75, -BASIN_DEPTH, lee_z - toe),
		Vector3(-seaward * 0.75, MOUND_CREST + BASIN_DEPTH, toe * 2.0)))
	_parts["breakwater"] = arms
	# A LIGHT on the head of the long arm, which is where one always is.
	Plating.box(tool, Vector3(seaward, MOUND_CREST + 2.6, along_to), Vector3(1.2, 5.2, 1.2), SHED)
	Plating.box(tool, Vector3(seaward, MOUND_CREST + 5.6, along_to), Vector3(1.6, 1.2, 1.6), Color(0.16, 0.48, 0.24))


## ONE ARM OF RUBBLE MOUND from `from` to `to`: a crest and two armour slopes, as a trapezoid prism.
func _a_mound(tool: SurfaceTool, from: Vector3, to: Vector3, toe: float) -> void:
	var along: Vector3 = (to - from)
	var length: float = along.length()
	if length < 1.0:
		return
	var turn: float = atan2(along.x, along.z)
	var mid: Vector3 = (from + to) * 0.5
	var basis := Basis(Vector3.UP, turn)
	# THE ARMOUR, a wide low box to the toe, then the crest on top: two boxes read as a mound at any distance a
	# breakwater is seen from, and a real one is riprap, which is not a smooth surface anyway.
	Plating.box(tool, mid + Vector3(0.0, (MOUND_CREST - BASIN_DEPTH) * 0.5 - 0.6, 0.0),
		Vector3(toe * 2.0, MOUND_CREST + BASIN_DEPTH - 1.2, length), ROCK_DARK, basis)
	Plating.box(tool, mid + Vector3(0.0, MOUND_CREST - 0.9, 0.0),
		Vector3(MOUND_WIDE + 2.4, 1.8, length), ROCK, basis)
	Plating.box(tool, mid + Vector3(0.0, MOUND_CREST + 0.15, 0.0),
		Vector3(MOUND_WIDE, 0.5, length), ROCK, basis)


## THE PONTOONS: a main walkway out from the shore, and fingers off both sides making the berths.
func _the_pontoons(tool: SurfaceTool) -> void:
	var berth_long: float = berth_length()
	var berth_wide: float = berth_width()
	var walk_top: float = PONTOON_FREEBOARD
	var walk_length: float = berth_wide * float(BERTHS_A_SIDE)
	var first_z: float = -BASIN_ALONG * 0.34
	var spacing: float = (berth_long + PONTOON_WIDE) * 2.0 + 14.0
	var made: Array[AABB] = []
	for p in range(PONTOONS):
		var x: float = -22.0 - float(p) * spacing * 0.5
		# THE WALKWAY, running along the basin parallel to the shore.
		Plating.box(tool, Vector3(x, walk_top - 0.25, first_z + walk_length * 0.5),
			Vector3(PONTOON_WIDE, 0.5, walk_length), PONTOON)
		made.append(AABB(Vector3(x - PONTOON_WIDE * 0.5, walk_top - 0.5, first_z),
			Vector3(PONTOON_WIDE, 0.5, walk_length)))
		# THE BROW from the quay to the head of the walkway: the hinged ramp every floating pontoon needs.
		if p == 0:
			Plating.box(tool, Vector3(x * 0.5 + 1.0, (QUAY_TOP + walk_top) * 0.5, first_z),
				Vector3(absf(x) + 4.0, 0.35, 2.0), TIMBER,
				Basis(Vector3(0.0, 0.0, 1.0), atan2(QUAY_TOP - walk_top, absf(x))))
		# THE FINGERS, one between every pair of berths, on the side away from the shore.
		for b in range(BERTHS_A_SIDE + 1):
			var z: float = first_z + float(b) * berth_wide
			Plating.box(tool, Vector3(x - PONTOON_WIDE * 0.5 - berth_long * 0.5, walk_top - 0.25, z),
				Vector3(berth_long, 0.45, FINGER_WIDE), PONTOON)
			# A PILE at the outer end of every finger, which is what holds a pontoon in place.
			Plating.box(tool, Vector3(x - PONTOON_WIDE * 0.5 - berth_long, walk_top + 1.1, z),
				Vector3(0.45, BASIN_DEPTH + 3.4, 0.45), STEEL)
		# A CLEAT-AND-LOCKER POST every third berth, so the pontoon is not a bare plank.
		for b in range(0, BERTHS_A_SIDE, 3):
			Plating.box(tool, Vector3(x, walk_top + 0.55, first_z + (float(b) + 0.5) * berth_wide),
				Vector3(0.6, 1.1, 0.6), SHED)
	_parts["pontoons"] = made
	_parts["berth_length"] = berth_long
	_parts["berth_width"] = berth_wide


## THE FUEL DOCK, on its own pontoon near the entrance so a boat can come alongside without entering the berths.
func _the_fuel_dock(tool: SurfaceTool) -> void:
	var z: float = BASIN_ALONG * 0.30
	var x: float = -30.0
	Plating.box(tool, Vector3(x, PONTOON_FREEBOARD - 0.25, z), Vector3(4.0, 0.5, 26.0), PONTOON)
	Plating.box(tool, Vector3(x + 0.6, PONTOON_FREEBOARD + 1.6, z), Vector3(2.6, 3.2, 4.4), SHED)
	Plating.box(tool, Vector3(x + 0.6, PONTOON_FREEBOARD + 3.4, z), Vector3(3.4, 0.5, 5.2), ROOF)
	for pump in [-3.0, 3.0]:
		Plating.box(tool, Vector3(x - 1.0, PONTOON_FREEBOARD + 0.75, z + pump), Vector3(0.7, 1.5, 0.9), FUEL)
	_parts["fuel_dock"] = AABB(Vector3(x - 2.0, PONTOON_FREEBOARD - 0.5, z - 13.0), Vector3(4.0, 4.2, 26.0))


## ASHORE: a harbour office with a lookout over the basin, a boatyard shed with its door to the slipway, and a rack of
## boats on trailers in the yard.
func _the_buildings(tool: SurfaceTool) -> void:
	var office_z: float = BASIN_ALONG * 0.08
	Plating.box(tool, Vector3(28.0, QUAY_TOP + 4.0, office_z), Vector3(26.0, 8.0, 16.0), SHED)
	Plating.box(tool, Vector3(28.0, QUAY_TOP + 8.6, office_z), Vector3(28.0, 1.2, 18.0), ROOF)
	Plating.band(tool, Rect2(15.0, office_z - 8.0, 26.0, 16.0), QUAY_TOP + 4.6, QUAY_TOP + 7.0, GLASS, 0.5)
	# THE LOOKOUT, high enough to see over the breakwater's crest and down the basin.
	var look: float = QUAY_TOP + MOUND_CREST + 8.0
	Plating.box(tool, Vector3(18.0, (QUAY_TOP + look) * 0.5, office_z - 9.0), Vector3(6.0, look - QUAY_TOP, 6.0), SHED)
	Plating.box(tool, Vector3(18.0, look + 1.6, office_z - 9.0), Vector3(8.0, 3.2, 8.0), SHED)
	Plating.band(tool, Rect2(14.0, office_z - 13.0, 8.0, 8.0), look + 0.4, look + 2.6, GLASS, 0.25)
	Plating.box(tool, Vector3(18.0, look + 3.8, office_z - 9.0), Vector3(9.0, 0.8, 9.0), ROOF)
	# THE BOATYARD SHED, its long side to the slipway.
	var yard_z: float = -BASIN_ALONG * 0.34
	Plating.box(tool, Vector3(36.0, QUAY_TOP + 5.5, yard_z), Vector3(34.0, 11.0, 24.0), SHED)
	Plating.box(tool, Vector3(36.0, QUAY_TOP + 11.4, yard_z), Vector3(36.0, 1.0, 26.0), ROOF)
	Plating.box(tool, Vector3(19.2, QUAY_TOP + 4.0, yard_z), Vector3(0.6, 8.0, 12.0), ROOF)
	# BOATS ASHORE on their cradles, which is half of what a yard looks like. Hulls only, as blocks: a cradled boat
	# under a cover is a shape, not a model, and drawing six more sloops here would cost the frame nothing but time.
	for i in range(5):
		var at := Vector3(58.0, QUAY_TOP + 1.9, yard_z - 22.0 + float(i) * 11.0)
		Plating.box(tool, at, Vector3(3.6, 2.4, 11.0), Color(0.80, 0.79, 0.76))
		Plating.box(tool, at + Vector3(0.0, -1.7, 0.0), Vector3(1.0, 1.0, 6.0), STEEL)
	_parts["buildings"] = AABB(Vector3(15.0, QUAY_TOP, office_z - 13.0), Vector3(26.0, look + 4.6, 18.0))


## THE PAD, AT CAP 437's MINIMUM 1.0 x D, because a marina is a cramped place and this is the honest size for it -- the
## terminal, which has room, uses the preferred 1.5 x D instead. It stands at the landward edge of the margin, well back
## from the pontoons so that no mast is under the approach: the tallest thing afloat here is the sloop's 18.33 m rig, and
## `shore_structures.gd` holds the pad clear of it.
func _the_pad(tool: SurfaceTool) -> void:
	var across: float = Helipad.across_for(1.0)
	var at := Vector3(MARGIN - across * 0.5 - 4.0, QUAY_TOP, BASIN_ALONG * 0.36)
	_parts["pad"] = Helipad.build_into(tool, at, across, Vector3(-1.0, 0.0, 0.0))
	_parts["pad_across"] = across
