@tool
extends Node3D
class_name ContainerTerminal
## A CONTAINER TERMINAL ON A QUAY: the quay wall and its apron, ship-to-shore gantry cranes on their rails, blocks of
## containers stacked ashore, two straddle carriers, a terminal building, and a marked concrete pad for a helicopter or
## a VTOL aeroplane clear of every crane boom.
##
## THE USER ASKED FOR IT (2026-09-19): "a marina and a large dock for container ships are two things that we need that we
## can put near the water", with "concrete spaces to do land helicopters and other vtol planes".
##
## THE CRANE IS SIZED BY THE SHIP, AND THAT IS THE WHOLE IDEA. A ship-to-shore gantry is not a thing with a size of its
## own -- it is built to reach across the largest ship that will lie under it, and every serious figure about it falls out
## of that ship. So `OUTREACH` and `LIFT` are computed from `ContainerShipDraft.CLASSES["container_large"]`: the outreach
## is the 23 published rows at the ISO box's pitch plus the standoff between hull and quay, and the lift height is the
## ship's own deck over the water plus nine tiers of 2.591 m box plus clearance for the spreader. Type either one and the
## day somebody changes the ship the crane silently stops reaching it.
##
## THE PUBLISHED CROSS-CHECK, and where it disagrees. Super-post-Panamax cranes are described as reaching "about 50 m"
## and lifting "about 40 m", over 22 container rows, on a 100 ft (30.48 m) rail gauge (Wikipedia, *Container crane*). The
## derivation here gives a longer reach than that, and it should: those figures describe cranes built for 22-row ships,
## and a Triple-E is 23 rows and 58.6 m in the beam. A crane that reached 50 m could not work this ship, which is exactly
## why the newest cranes are bigger than the old ones. The rail gauge is taken from the published 30.48 m, because that
## one is a property of the crane and not of the ship.
##
## THE DATUM. The origin is ON THE WATER at the middle of the quay face, +x inland away from the water, -z along the quay
## towards the first crane, +y up. Everything is placed from that, so a level puts a terminal down by saying where the
## quay face is and which way the water lies.
##
## THE LOOK. Flat-faced boxes and 8-sided legs, faceted, as everything here is (`modelling_here.md` section 4). A gantry
## crane at two kilometres is a silhouette of legs and a boom, and that silhouette is what has to be right.

## ---- the quay -------------------------------------------------------------------------------------------------------

## HOW HIGH THE QUAY DECK STANDS OVER THE WATER, and how deep the wall goes. A container quay is dredged to take the
## deepest ship on its berth; the Triple-E draws 16 m, so 17.5 m of water is the least that is any use. ESTIMATE, from
## that draught plus the under-keel clearance a loaded ship wants alongside.
const QUAY_TOP: float = 4.5
const QUAY_DEPTH: float = 17.5
## How far back from the water's edge the paved apron runs, and how long the berth is. The berth takes the largest ship
## with room to moor: her 399.2 m plus a ship's length again for the lines and the next berth. ESTIMATE.
const APRON: float = 220.0
const BERTH: float = 520.0
## THE STANDOFF: how far the ship's side lies off the quay face when she is alongside, fenders and all. ESTIMATE.
const STANDOFF: float = 3.5

## ---- the gantry cranes -----------------------------------------------------------------------------------------------

## THE RAIL GAUGE, from the published 100 ft. This is the crane's own dimension, not the ship's.
const RAIL_GAUGE: float = 30.48
## How high the portal's underside is, so a lorry and a straddle carrier pass under the crane. ESTIMATE.
const PORTAL_CLEAR: float = 16.0
## The legs' section, the boom's depth, and how far the boom reaches back over the yard to balance the outreach.
const LEG_SIDE: float = 2.6
const BOOM_DEEP: float = 3.4
const BACKREACH: float = 24.0
## How many cranes stand on the berth, and how far apart. Two cranes cannot work closer than their own portals.
const CRANES: int = 3
const CRANE_SPACING: float = 95.0
## Clearance over the highest stack for the spreader and the headblock. ESTIMATE.
const SPREADER: float = 6.0

## ---- the yard -------------------------------------------------------------------------------------------------------

## THE STACKS ASHORE: how many tiers a yard stacks, and the gaps a straddle carrier needs to drive between blocks.
const YARD_TIERS: int = 4
const YARD_ROWS: int = 6
const YARD_BAYS: int = 7
const LANE: float = 16.0

## The colours. A terminal is concrete, painted steel and boxes.
const CONCRETE := Color(0.60, 0.59, 0.56)
const QUAY_FACE := Color(0.48, 0.47, 0.45)
const FENDER := Color(0.12, 0.12, 0.13)
const CRANE := Color(0.82, 0.55, 0.14)
const CRANE_DARK := Color(0.62, 0.41, 0.11)
const STEEL := Color(0.40, 0.42, 0.44)
const SHED := Color(0.78, 0.78, 0.76)
const GLASS := Color(0.12, 0.16, 0.20)
const STRIPE := Color(0.90, 0.88, 0.32)

var _parts: Dictionary = {}


## HOW FAR A CRANE MUST REACH OVER THE WATER: the standoff, then the largest ship's beam-worth of container rows at the
## ISO pitch, then a little to get the spreader outboard of the last row. DERIVED, never typed.
static func outreach() -> float:
	var ship: Dictionary = ContainerShipDraft.CLASSES["container_large"]
	var rows: int = int(ship["rows"])
	var pitch: float = ContainerShipDraft.BOX_WIDE + ContainerShipDraft.LASH
	return STANDOFF + float(rows - 1) * pitch + ContainerShipDraft.BOX_WIDE + 2.0


## HOW HIGH IT MUST LIFT over the quay deck: the ship's own weather deck over the water, plus her full deck stack, plus
## the spreader, less the quay's own height. DERIVED from the same ship the outreach comes from.
static func lift_height() -> float:
	var ship: Dictionary = ContainerShipDraft.CLASSES["container_large"]
	var deck: float = float(ship["depth"]) - float(ship["draught"])
	var stack: float = float(ContainerShip.TIERS_FULL) * ContainerShipDraft.BOX_HIGH
	return deck + stack + SPREADER - QUAY_TOP


## A TERMINAL ON ITS OWN, for the buildings gallery and for a suite: the whole thing with nothing else in the scene.
## BUILT ON CONSTRUCTION, NOT ON `_ready`. The buildings gallery instances a standalone through this factory and
## measures its drawn bounds; a node that waits for `_ready` has no mesh in it at that moment and measures as an
## empty box, which comes out of the arithmetic as -nan and reads like a broken model rather than an empty one.
## `OilPlatform.one` is the precedent: a factory hands back a finished thing.
static func one() -> ContainerTerminal:
	var made := ContainerTerminal.new()
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
	_the_quay(tool)
	_the_cranes(tool)
	_the_yard(tool)
	_the_buildings(tool)
	_the_pad(tool)
	var mesh := MeshInstance3D.new()
	mesh.name = "Terminal"
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = ShipHull.painted()
	add_child(mesh)


## THE QUAY: a wall from the dredged bottom to the deck, a paved apron behind it, the crane rails, a bollard every
## 25 m and a fender every 12 along the face.
func _the_quay(tool: SurfaceTool) -> void:
	var half: float = BERTH * 0.5
	# The wall, its face ON the datum so x = 0 is the water's edge.
	Plating.box(tool, Vector3(APRON * 0.5, (QUAY_TOP - QUAY_DEPTH) * 0.5, 0.0),
		Vector3(APRON, QUAY_TOP + QUAY_DEPTH, BERTH), CONCRETE)
	Plating.box(tool, Vector3(0.6, (QUAY_TOP - QUAY_DEPTH) * 0.5, 0.0),
		Vector3(1.2, QUAY_TOP + QUAY_DEPTH, BERTH), QUAY_FACE)
	_parts["quay"] = AABB(Vector3(0.0, -QUAY_DEPTH, -half), Vector3(APRON, QUAY_TOP + QUAY_DEPTH, BERTH))
	# FENDERS down the face at the waterline, and BOLLARDS along the edge.
	var fender: float = 12.0
	var count: int = int(BERTH / fender)
	for i in range(count + 1):
		var z: float = -half + float(i) * fender
		Plating.box(tool, Vector3(-0.35, 1.2, z), Vector3(0.9, 3.2, 1.6), FENDER)
	for i in range(int(BERTH / 25.0) + 1):
		var z: float = -half + float(i) * 25.0
		Plating.box(tool, Vector3(3.0, QUAY_TOP + 0.5, z), Vector3(0.9, 1.0, 0.9), STEEL)
	# THE CRANE RAILS, one at the water's edge and one a gauge inland, painted so the apron reads as a working surface.
	for rail in [5.0, 5.0 + RAIL_GAUGE]:
		Plating.box(tool, Vector3(rail, QUAY_TOP + 0.12, 0.0), Vector3(0.7, 0.24, BERTH), STEEL)
	# A painted edge line the length of the quay.
	Plating.box(tool, Vector3(2.0, QUAY_TOP + 0.03, 0.0), Vector3(0.5, 0.06, BERTH), STRIPE)


## THE GANTRY CRANES: a portal on eight legs straddling two rails, a boom reaching out over the ship and back over the
## yard, a machinery house on top and a trolley under the boom.
func _the_cranes(tool: SurfaceTool) -> void:
	var reach: float = outreach()
	var lift: float = lift_height()
	var sea_rail: float = 5.0
	var land_rail: float = 5.0 + RAIL_GAUGE
	var boom_y: float = QUAY_TOP + lift + BOOM_DEEP * 0.5
	var first: float = -CRANE_SPACING * float(CRANES - 1) * 0.5
	var boxes: Array[AABB] = []
	for c in range(CRANES):
		var z: float = first + CRANE_SPACING * float(c)
		# EIGHT LEGS: two rails, two sides of the portal, and a pair at each corner.
		for rail in [sea_rail, land_rail]:
			for side in [-1.0, 1.0]:
				var at_z: float = z + side * 9.0
				Plating.box(tool, Vector3(rail, (QUAY_TOP + boom_y) * 0.5, at_z),
					Vector3(LEG_SIDE, boom_y - QUAY_TOP, LEG_SIDE), CRANE)
				# The sill beam under the portal, which is what the clearance is measured to.
				Plating.box(tool, Vector3(rail, QUAY_TOP + PORTAL_CLEAR, at_z),
					Vector3(LEG_SIDE * 1.3, 1.6, LEG_SIDE * 1.3), CRANE_DARK)
		# THE PORTAL BEAM across the two rails, and the girder along the quay tying the two sides.
		for side in [-1.0, 1.0]:
			Plating.box(tool, Vector3((sea_rail + land_rail) * 0.5, boom_y, z + side * 9.0),
				Vector3(RAIL_GAUGE + LEG_SIDE, BOOM_DEEP, LEG_SIDE * 1.1), CRANE)
		# THE BOOM, from the backreach over the yard out to the outreach over the water. Its landward end is the
		# counterweight's; its seaward end is what has to clear the outermost row of the largest ship.
		var boom_from: float = land_rail + BACKREACH
		var boom_to: float = -reach
		Plating.box(tool, Vector3((boom_from + boom_to) * 0.5, boom_y + BOOM_DEEP, z),
			Vector3(boom_from - boom_to, BOOM_DEEP, 3.2), CRANE)
		# THE A-FRAME over the portal and the stays down to each end of the boom: what holds a 90 m boom up.
		var apex: float = boom_y + BOOM_DEEP * 0.5 + 22.0
		Plating.box(tool, Vector3(land_rail - 4.0, (boom_y + apex) * 0.5, z), Vector3(2.2, apex - boom_y, 2.2), CRANE)
		for end_x in [boom_to + 6.0, boom_from - 4.0]:
			var mid := Vector3((land_rail - 4.0 + end_x) * 0.5, (apex + boom_y + BOOM_DEEP) * 0.5, z)
			var run: float = absf(end_x - (land_rail - 4.0))
			var rise: float = apex - boom_y - BOOM_DEEP
			Plating.box(tool, mid, Vector3(sqrt(run * run + rise * rise), 0.9, 0.9), STEEL,
				Basis(Vector3(0.0, 0.0, 1.0), atan2(-rise, end_x - (land_rail - 4.0))))
		# THE MACHINERY HOUSE on the landward side, and the TROLLEY out over the water where it works.
		Plating.box(tool, Vector3(boom_from - 12.0, boom_y + BOOM_DEEP * 2.0, z), Vector3(14.0, 5.0, 10.0), SHED)
		Plating.box(tool, Vector3(-reach * 0.45, boom_y - 1.2, z), Vector3(5.0, 3.0, 4.0), CRANE_DARK)
		boxes.append(AABB(Vector3(boom_to, QUAY_TOP, z - 10.0),
			Vector3(boom_from - boom_to, apex - QUAY_TOP, 20.0)))
	_parts["cranes"] = boxes


## THE YARD: blocks of containers stacked ashore, in the ISO box, with lanes between them for the straddles.
func _the_yard(tool: SurfaceTool) -> void:
	var wide: float = ContainerShipDraft.BOX_WIDE + ContainerShipDraft.LASH
	var long: float = ContainerShipDraft.BOX_40 + ContainerShipDraft.BAY_GAP
	var high: float = ContainerShipDraft.BOX_HIGH
	var block_x: float = float(YARD_ROWS) * wide
	var block_z: float = float(YARD_BAYS) * long
	var from_quay: float = 5.0 + RAIL_GAUGE + BACKREACH + 14.0
	var stacks: Array[AABB] = []
	for bx in range(3):
		for bz in range(3):
			var ox: float = from_quay + float(bx) * (block_x + LANE)
			var oz: float = -block_z * 1.5 - LANE + float(bz) * (block_z + LANE)
			for row in range(YARD_ROWS):
				for bay in range(YARD_BAYS):
					# A YARD IS NOT FULL. Every third slot is left empty, by a hash of its own place so the terminal
					# looks the same every time it is drawn, because a block stacked solid reads as one painted box.
					if absi(hash(Vector2i(bx * 97 + row, bz * 89 + bay))) % 3 == 0:
						continue
					var tiers: int = 2 + absi(hash(Vector2i(row * 31 + bx, bay * 17 + bz))) % (YARD_TIERS - 1)
					for tier in range(tiers):
						var pick: int = absi(hash(Vector2i(row * 7 + tier, bay * 13 + bx))) % ContainerShip.BOX_PAINT.size()
						Plating.box(tool, Vector3(ox + float(row) * wide, QUAY_TOP + high * (float(tier) + 0.5),
							oz + float(bay) * long), Vector3(ContainerShipDraft.BOX_WIDE, high,
							ContainerShipDraft.BOX_40), ContainerShip.BOX_PAINT[pick])
			stacks.append(AABB(Vector3(ox - wide * 0.5, QUAY_TOP, oz - long * 0.5),
				Vector3(block_x, high * float(YARD_TIERS), block_z)))
	_parts["yard"] = stacks
	# TWO STRADDLE CARRIERS in a lane: a portal on eight wheels tall enough to carry a box over a stack of three.
	for i in range(2):
		var at := Vector3(from_quay + block_x + LANE * 0.5, QUAY_TOP, -60.0 + float(i) * 120.0)
		_a_straddle(tool, at)


## A STRADDLE CARRIER: a portal frame on legs, with a box slung inside it.
func _a_straddle(tool: SurfaceTool, at: Vector3) -> void:
	var high: float = ContainerShipDraft.BOX_HIGH * 3.4
	var wide: float = ContainerShipDraft.BOX_WIDE + 2.2
	var long: float = ContainerShipDraft.BOX_40 + 1.6
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Plating.box(tool, Vector3(at.x + sx * wide * 0.5, at.y + high * 0.5, at.z + sz * long * 0.45),
				Vector3(0.7, high, 0.8), CRANE)
	Plating.box(tool, Vector3(at.x, at.y + high, at.z), Vector3(wide + 0.7, 1.4, long), CRANE)
	Plating.box(tool, Vector3(at.x, at.y + high * 0.72, at.z),
		Vector3(ContainerShipDraft.BOX_WIDE, ContainerShipDraft.BOX_HIGH, ContainerShipDraft.BOX_40),
		ContainerShip.BOX_PAINT[3])


## THE TERMINAL'S OWN BUILDINGS: an operations block with a tower that can see the whole berth, and a maintenance shed.
func _the_buildings(tool: SurfaceTool) -> void:
	var back: float = APRON - 34.0
	Plating.box(tool, Vector3(back, QUAY_TOP + 5.0, -BERTH * 0.30), Vector3(48.0, 10.0, 26.0), SHED)
	Plating.band(tool, Rect2(back - 24.0, -BERTH * 0.30 - 13.0, 48.0, 26.0), QUAY_TOP + 6.0, QUAY_TOP + 8.6, GLASS, 0.4)
	# THE CONTROL TOWER, high enough to see over a crane's portal beam.
	var tower: float = QUAY_TOP + PORTAL_CLEAR + 12.0
	Plating.box(tool, Vector3(back - 10.0, (QUAY_TOP + tower) * 0.5, -BERTH * 0.30 + 16.0),
		Vector3(9.0, tower - QUAY_TOP, 9.0), SHED)
	Plating.box(tool, Vector3(back - 10.0, tower + 2.0, -BERTH * 0.30 + 16.0), Vector3(13.0, 4.0, 13.0), SHED)
	Plating.band(tool, Rect2(back - 16.5, -BERTH * 0.30 + 9.5, 13.0, 13.0), tower + 0.6, tower + 3.4, GLASS, 0.3)
	Plating.box(tool, Vector3(back, QUAY_TOP + 6.0, BERTH * 0.33), Vector3(40.0, 12.0, 30.0), SHED)
	_parts["buildings"] = AABB(Vector3(back - 24.0, QUAY_TOP, -BERTH * 0.30 - 13.0), Vector3(48.0, tower + 4.0, 26.0))


## THE PAD, AT THE PREFERRED 1.5 x D, because a terminal has the room for it. It stands at the landward end of the apron
## WELL CLEAR OF THE CRANES: a gantry's boom reaches `BACKREACH` inland of the landward rail and its A-frame stands
## higher than anything else here, so the pad goes beyond both and its approach is left open over the water.
func _the_pad(tool: SurfaceTool) -> void:
	var across: float = Helipad.across_for(1.5)
	var at := Vector3(APRON - 42.0, QUAY_TOP, BERTH * 0.06)
	_parts["pad"] = Helipad.build_into(tool, at, across, Vector3(-1.0, 0.0, 0.0))
	_parts["pad_across"] = across
