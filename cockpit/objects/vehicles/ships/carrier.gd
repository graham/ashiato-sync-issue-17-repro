@tool
extends RefCounted
class_name Carrier
## THE FORD, UP CLOSE: everything a carrier has that its silhouette does not, welded into one mesh.
##
## `ShipHull` draws every ship from the simulation's parts, and at a few kilometres that is the ship. Nearer, a Ford
## is a flared hull with a black boot-top, a dark flight deck painted with a landing area angled 9 degrees to port, four
## catapult tracks and their blast deflectors, three wires, three elevators outlined in yellow, a 78 at the bow, and an
## island with a glazed bridge, a mast and six radar faces. Every position comes from the parts (the deck, the elevators,
## the island, the bridge, the gun tubs) or from `CarrierPlan` (the paint and the fittings), never from here, and every
## size that is not in either is a fitting's own -- a radar face, a launcher, a light -- sourced where the sheet has it.
##
## WHAT IS UNVERIFIED IS SAID SO. The sheet found no source for where the Ford's weapons stand or its island's radar
## faces sit; they are placed where Nimitz-class practice puts them and where a person looking would expect them, and
## that is written beside each.

const HAZE := Color(0.45, 0.48, 0.51)
const DECK := Color(0.21, 0.22, 0.23)
const RUBBER := Color(0.13, 0.13, 0.14)
const WHITE := Color(0.88, 0.88, 0.85)
const YELLOW := Color(0.93, 0.76, 0.16)
const RED := Color(0.78, 0.13, 0.11)
const BLACK := Color(0.06, 0.06, 0.07)
const STEEL := Color(0.32, 0.34, 0.36)
const GLASS := Color(0.07, 0.09, 0.11)
const OPENING := Color(0.05, 0.05, 0.06)

## How far above the deck the paint lies. Enough that a reverse-Z depth buffer keeps it in front at the near model's
## furthest, and nothing a wheel could catch on.
const PAINT_UP: float = 0.03

## The hull's sections, top down: `[y, width, stem_in, stern_in]` (see HullLoft). The hangar deck and the gallery above it
## are as wide as the part; the stem rakes aft and the stern cuts up under the fantail; the bilge turns in below the
## waterline to a keel a little under half the beam.
const ROWS: Array = [
	[13.0, 1.0, 0.0, 0.0],
	[7.5, 1.0, 1.5, 3.0],
	[0.8, 0.99, 4.0, 9.0],
	[-0.8, 0.98, 4.6, 10.5],
	[-6.0, 0.88, 7.0, 17.0],
	[-11.9, 0.46, 12.0, 28.0],
]


## THE NEAR MODEL: `{"mesh": ArrayMesh, "panels": Array[AABB]}`, the panels being what stands above the deck -- island,
## bridge, mast -- as boxes for the see-out checks.
static func build(geometry: Dictionary) -> Dictionary:
	var parts: Array = geometry.get("parts", []) as Array
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck_top: float = float((geometry.get("extents", Vector3.ZERO) as Vector3).y)
	var panels: Array[AABB] = []
	for part in parts:
		match String(part.get("part", "")):
			"hull":
				HullLoft.build(tool, part["outline"], ROWS)
			"deck":
				Plating.prism(tool, part["outline"], float(part["bottom"]), float(part["top"]), DECK)
	_hangar_openings(tool, parts)
	_landing_area(tool, deck_top)
	_catapults(tool, deck_top)
	_wires(tool, deck_top)
	_elevators(tool, parts, deck_top)
	_number_on_the_deck(tool, deck_top)
	panels.append_array(_island(tool, parts))
	_weapons(tool, deck_top)
	_gun_tubs(tool, parts)
	_lso_platform(tool, deck_top)
	return {"mesh": Plating.weld(tool), "panels": panels}


## ---- the hull ----------------------------------------------------------------------------------------------------

## THE HANGAR OPENINGS: where an elevator stands, the hull side under it is open onto the hangar deck, and from outside that
## dark doorway is what says the platform is an elevator and not a balcony. The fantail is open the same way.
static func _hangar_openings(tool: SurfaceTool, parts: Array) -> void:
	var hull: Dictionary = _first(parts, "hull")
	var floor_at: float = 7.5
	var ceiling: float = float(hull.get("top", 13.0)) - 0.4
	for part in parts:
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		if String(part["part"]) != "deck" or not _is_elevator(r):
			continue
		var side: float = signf(r.get_center().x)
		var x: float = side * (HullLoft.half_width(hull["outline"], r.get_center().y) + 0.03)
		var z0: float = r.position.y + 1.0
		var z1: float = r.end.y - 1.0
		Plating.facing(tool, [Vector3(x, ceiling, z0), Vector3(x, ceiling, z1), Vector3(x, floor_at, z1),
			Vector3(x, floor_at, z0)], Vector3(side, 0.0, 0.0), OPENING)
	var stern: float = Wheelhouse.outline_rect(hull["outline"]).end.y + 0.03
	Plating.facing(tool, [Vector3(-11.0, ceiling, stern), Vector3(11.0, ceiling, stern), Vector3(11.0, floor_at, stern),
		Vector3(-11.0, floor_at, stern)], Vector3.BACK, OPENING)


## ---- the paint on the deck --------------------------------------------------------------------------------------

## THE LANDING AREA: its two edges in white, a dashed centreline, a red-and-white foul line outboard of its starboard
## edge, the rubber of every trap laid down between the wires, and the ramp striped across at the stern.
static func _landing_area(tool: SurfaceTool, deck: float) -> void:
	var along: Vector2 = CarrierPlan.landing_direction()
	var across := Vector2(-along.y, along.x)
	var length: float = CarrierPlan.RAMP.distance_to(CarrierPlan.LANDING_OFF)
	var y: float = deck + PAINT_UP
	# The rubber, under the lines: from short of the first wire to past the last.
	var from_ramp: float = CarrierPlan.WIRES_FROM_RAMP[0] - 20.0
	var to_ramp: float = CarrierPlan.WIRES_FROM_RAMP[CarrierPlan.WIRES_FROM_RAMP.size() - 1] + 45.0
	var a: Vector2 = CarrierPlan.RAMP + along * from_ramp
	var b: Vector2 = CarrierPlan.RAMP + along * to_ramp
	Plating.paint(tool, PackedVector2Array([a - across * 6.0, b - across * 6.0, b + across * 6.0, a + across * 6.0]),
		y - 0.01, RUBBER)
	for edge in [-1.0, 1.0]:
		_on_deck_line(tool, CarrierPlan.RAMP + across * edge * CarrierPlan.LANDING_HALF_WIDE,
			CarrierPlan.LANDING_OFF + across * edge * CarrierPlan.LANDING_HALF_WIDE, 0.45, y, WHITE)
	# THE FOUL LINE, three metres outboard of the starboard edge: nothing parked may stand inside it while a jet lands.
	# `across` is the landing direction turned a quarter to starboard, so it points to the island's side of the deck.
	var foul: float = signf(across.x) * (CarrierPlan.LANDING_HALF_WIDE + 3.0)
	var step: float = 0.0
	while step < length:
		var p: Vector2 = CarrierPlan.RAMP + along * step + across * foul
		var q: Vector2 = CarrierPlan.RAMP + along * minf(step + 3.0, length) + across * foul
		if CarrierPlan.is_on_deck(p) and CarrierPlan.is_on_deck(q):
			Plating.line(tool, p, q, 0.35, y, RED if int(step / 3.0) % 2 == 0 else WHITE)
		step += 3.0
	Plating.dashes(tool, CarrierPlan.RAMP + along * 6.0, CarrierPlan.LANDING_OFF, 0.6, 7.0, 7.0, y, WHITE)
	# The ramp, striped across the landing area's width at the round-down.
	for i in range(8):
		var s: float = float(i) * 1.8
		var p: Vector2 = CarrierPlan.RAMP + along * (1.0 + s) - across * CarrierPlan.LANDING_HALF_WIDE
		var q: Vector2 = CarrierPlan.RAMP + along * (1.0 + s) + across * CarrierPlan.LANDING_HALF_WIDE
		Plating.line(tool, p, q, 0.9, y, WHITE if i % 2 == 0 else BLACK)


## A painted line, only where both ends of each short run of it are over the deck.
static func _on_deck_line(tool: SurfaceTool, from: Vector2, to: Vector2, wide: float, y: float, tint: Color) -> void:
	var length: float = from.distance_to(to)
	var way: Vector2 = (to - from) / maxf(length, 0.001)
	var at: float = 0.0
	while at < length:
		var p: Vector2 = from + way * at
		var q: Vector2 = from + way * minf(at + 4.0, length)
		if CarrierPlan.is_on_deck(p) and CarrierPlan.is_on_deck(q):
			Plating.line(tool, p, q, wide, y, tint)
		at += 4.0


## FOUR CATAPULTS: the slot, a white line either side for the nosewheel to be steered between, the shuttle's yellow
## start line, and the blast deflector lying flush in its recess behind it.
static func _catapults(tool: SurfaceTool, deck: float) -> void:
	var y: float = deck + PAINT_UP
	for i in range(CarrierPlan.CATAPULTS.size()):
		var cat: Dictionary = CarrierPlan.CATAPULTS[i]
		var start: Vector2 = cat["start"]
		var end: Vector2 = cat["end"]
		var along: Vector2 = CarrierPlan.track_direction(i)
		var across := Vector2(-along.y, along.x)
		Plating.line(tool, start - along * 4.0, end, 0.45, y + 0.004, BLACK)
		for side in [-1.0, 1.0]:
			Plating.line(tool, start + across * side * 2.6, end + across * side * 2.6, 0.22, y, WHITE)
		Plating.line(tool, start - across * 3.8, start + across * 3.8, 0.5, y + 0.002, YELLOW)
		var hinge: Vector2 = CarrierPlan.deflector_at(i)
		var back: Vector2 = hinge + along * CarrierPlan.DEFLECTOR_TALL
		var half: Vector2 = across * CarrierPlan.DEFLECTOR_WIDE * 0.5
		Plating.paint(tool, PackedVector2Array([hinge - half, back - half, back + half, hinge + half]), y + 0.006,
			STEEL)


## THREE WIRES across the landing area, each a steel cable a hand's height off the deck on a sheave at each end.
static func _wires(tool: SurfaceTool, deck: float) -> void:
	for w in range(CarrierPlan.WIRES_FROM_RAMP.size()):
		var ends: Array[Vector2] = CarrierPlan.wire_ends(w)
		Plating.bar(tool, ends[0], ends[1], 0.07, deck + 0.05, deck + 0.12, BLACK)
		for at in ends:
			Plating.box(tool, Vector3(at.x, deck + 0.18, at.y), Vector3(0.6, 0.36, 0.6), STEEL)


## THE ELEVATORS: each platform edged in yellow on the deck, and the gap round it that says it is a separate plate.
static func _elevators(tool: SurfaceTool, parts: Array, deck: float) -> void:
	for part in parts:
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		if String(part["part"]) != "deck" or not _is_elevator(r):
			continue
		var y: float = deck + PAINT_UP
		var inner: Rect2 = r.grow(-0.4)
		var corners: Array[Vector2] = [inner.position, Vector2(inner.end.x, inner.position.y), inner.end,
			Vector2(inner.position.x, inner.end.y)]
		# The gap: a dark hairline round the platform's edge, outside the yellow.
		var outer: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in range(4):
			Plating.line(tool, corners[i], corners[(i + 1) % 4], 0.35, y, YELLOW)
			Plating.line(tool, outer[i], outer[(i + 1) % 4], 0.12, y + 0.002, BLACK)


## THE HULL NUMBER on the bow, in white, reading the right way up for an aeroplane coming in from astern.
static func _number_on_the_deck(tool: SurfaceTool, deck: float) -> void:
	var tall: float = CarrierPlan.NUMBER_TALL
	var wide: float = tall * 0.55
	var gap: float = tall * 0.2
	var digits: String = CarrierPlan.NUMBER
	var total: float = float(digits.length()) * wide + float(digits.length() - 1) * gap
	for i in range(digits.length()):
		var left: float = -total * 0.5 + float(i) * (wide + gap)
		# Read from astern: the reader's right is +x and their up is -z.
		var origin := Vector2(CarrierPlan.NUMBER_AT.x + left, CarrierPlan.NUMBER_AT.y + tall * 0.5)
		for segment in segments_of(digits[i]):
			var p: Vector2 = segment[0]
			var q: Vector2 = segment[1]
			Plating.line(tool, origin + Vector2(p.x * wide, -p.y * tall), origin + Vector2(q.x * wide, -q.y * tall),
				tall * 0.14, deck + PAINT_UP, WHITE)


## A DIGIT AS STROKES in a unit box, (0, 0) its bottom left and (1, 1) its top right. Seven segments is all a hull number
## painted in straight lines needs.
static func segments_of(digit: String) -> Array:
	var a := [Vector2(0.0, 1.0), Vector2(1.0, 1.0)]
	var b := [Vector2(1.0, 1.0), Vector2(1.0, 0.5)]
	var c := [Vector2(1.0, 0.5), Vector2(1.0, 0.0)]
	var d := [Vector2(0.0, 0.0), Vector2(1.0, 0.0)]
	var e := [Vector2(0.0, 0.5), Vector2(0.0, 0.0)]
	var f := [Vector2(0.0, 1.0), Vector2(0.0, 0.5)]
	var g := [Vector2(0.0, 0.5), Vector2(1.0, 0.5)]
	match digit:
		"0": return [a, b, c, d, e, f]
		"1": return [b, c]
		"2": return [a, b, g, e, d]
		"3": return [a, b, g, c, d]
		"4": return [f, g, b, c]
		"5": return [a, f, g, c, d]
		"6": return [a, f, g, e, c, d]
		"7": return [a, b, c]
		"8": return [a, b, c, d, e, f, g]
		"9": return [a, b, c, d, f, g]
	return []


## ---- the island -------------------------------------------------------------------------------------------------

## THE ISLAND: its blocks, the glazed navigation bridge on its forward face, Pri-Fly's windows looking aft over the landing
## area, the six Dual Band Radar faces, the mast, and a 78 on each side. Returns what stands above the deck as boxes.
## WHICH FACES OF A DECKHOUSE ARE GLAZED, asked of what stands against it rather than typed per
## room. A navigation bridge looks forward down the deck, so it is glazed fore, port and starboard.
## The flag plot abaft it has the bridge's own back wall against its forward face -- a window there
## would look into the bridge -- so it is glazed AFT, port and starboard instead, and an operator
## who looks up from the plot table sees the landing area, which is the view that makes the room
## worth sitting in (lane/awacs, 2026-09-17).
##
## DERIVED, so a third deckhouse added between them needs no edit here: a room is glazed forward
## unless another deckhouse's after face is up against its forward face, and glazed aft when one is.
static func _glazing_for(part: Dictionary, parts: Array) -> Array:
	var mine: Rect2 = Wheelhouse.outline_rect(part["outline"])
	for other in parts:
		if String(other["part"]) != "bridge" or other == part:
			continue
		var theirs: Rect2 = Wheelhouse.outline_rect(other["outline"])
		var abuts: bool = absf(theirs.end.y - mine.position.y) < 0.05
		var overlaps: bool = minf(theirs.end.x, mine.end.x) - maxf(theirs.position.x, mine.position.x) > 0.5
		if abuts and overlaps:
			return ["aft", "port", "starboard"]
	return ["fore", "port", "starboard"]


static func _island(tool: SurfaceTool, parts: Array) -> Array[AABB]:
	var panels: Array[AABB] = []
	var blocks: Array = []
	var mast: Dictionary = {}
	for part in parts:
		var role: String = String(part["part"])
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		if role == "island" and r.size.x < 4.0:
			mast = part
		elif role == "island":
			blocks.append(part)
			Plating.prism(tool, part["outline"], float(part["bottom"]), float(part["top"]), HAZE, false)
			panels.append(AABB(Vector3(r.position.x, float(part["bottom"]), r.position.y),
				Vector3(r.size.x, float(part["top"]) - float(part["bottom"]), r.size.y)))
		elif role == "bridge":
			panels.append_array(Wheelhouse.build(tool, part, _glazing_for(part, parts), HAZE, STEEL))
	if blocks.is_empty():
		return panels
	var upper: Dictionary = blocks[blocks.size() - 1]
	var u: Rect2 = Wheelhouse.outline_rect(upper["outline"])
	var roof: float = float(upper["top"])
	# PRI-FLY, the air boss's glazed tower, at the top of the island looking aft and to port over the landing area: a band of
	# windows round its aft and port faces, two metres below the roof.
	var fly_low: float = roof - 5.2
	var fly_high: float = roof - 2.6
	Plating.facing(tool, [Vector3(u.end.x, fly_high, u.end.y + 0.02), Vector3(u.position.x, fly_high, u.end.y + 0.02),
		Vector3(u.position.x, fly_low, u.end.y + 0.02), Vector3(u.end.x, fly_low, u.end.y + 0.02)], Vector3.BACK, GLASS)
	Plating.facing(tool, [Vector3(u.position.x - 0.02, fly_high, u.end.y), Vector3(u.position.x - 0.02, fly_high,
		u.position.y), Vector3(u.position.x - 0.02, fly_low, u.position.y), Vector3(u.position.x - 0.02, fly_low,
		u.end.y)], Vector3.LEFT, GLASS)
	# THE DUAL BAND RADAR: three SPY-4 volume-search faces (about 4 m square; ESTIMATE) and three SPY-3 faces above them
	# (2.72 by 2.08 m; CONFIRMED), one set forward and one on each after corner, which covers the whole sky between them.
	# Where on the island each face sits is UNVERIFIED.
	var mid_x: float = u.get_center().x
	var faces: Array = [
		[Vector3(mid_x, 0.0, u.position.y - 0.35), 0.0],
		[Vector3(u.position.x + 0.6, 0.0, u.end.y - 0.6), deg_to_rad(135.0)],
		[Vector3(u.end.x - 0.6, 0.0, u.end.y - 0.6), deg_to_rad(-135.0)],
	]
	for face in faces:
		var at: Vector3 = face[0]
		var turn := Basis(Vector3.UP, float(face[1]))
		Plating.box(tool, at + Vector3(0.0, fly_low - 2.6, 0.0), Vector3(4.0, 4.0, 0.7), STEEL, turn)
		Plating.box(tool, at + Vector3(0.0, fly_high + 1.3, 0.0), Vector3(2.72, 2.08, 0.64), STEEL, turn)
	# THE MAST, tapering, with two yards and a pole to the sheet's 64 m above the waterline.
	if not mast.is_empty():
		var m: Rect2 = Wheelhouse.outline_rect(mast["outline"])
		var foot: float = float(mast["bottom"])
		var head: float = float(mast["top"])
		var steps: int = 4
		for i in range(steps):
			var t0: float = float(i) / float(steps)
			var t1: float = float(i + 1) / float(steps)
			var shrink: float = 1.0 - t0 * 0.55
			var y0: float = lerpf(foot, head - 6.0, t0)
			var y1: float = lerpf(foot, head - 6.0, t1)
			Plating.box(tool, Vector3(m.get_center().x, (y0 + y1) * 0.5, m.get_center().y),
				Vector3(m.size.x * shrink, y1 - y0, m.size.y * shrink), HAZE)
		Plating.box(tool, Vector3(m.get_center().x, head - 3.0, m.get_center().y), Vector3(0.3, 6.0, 0.3), STEEL)
		for yard in [0.45, 0.72]:
			var y: float = lerpf(foot, head - 6.0, yard)
			Plating.box(tool, Vector3(m.get_center().x, y, m.get_center().y), Vector3(9.0 - yard * 5.0, 0.25, 0.4),
				STEEL)
		panels.append(AABB(Vector3(m.position.x, foot, m.position.y), Vector3(m.size.x, head - foot, m.size.y)))
	# THE HULL NUMBER on both sides of the island, below the bridge.
	var lower: Dictionary = blocks[0]
	var l: Rect2 = Wheelhouse.outline_rect(lower["outline"])
	var tall: float = 5.5
	var middle_y: float = float(lower["bottom"]) + (float(lower["top"]) - float(lower["bottom"])) * 0.55
	for side in [-1.0, 1.0]:
		_number_on_a_wall(tool, CarrierPlan.NUMBER, l.get_center().x + side * (l.size.x * 0.5 + 0.03), l.get_center().y,
			middle_y, tall, side)
	return panels


## A HULL NUMBER on a wall facing `side` (+1 starboard, -1 port), centred at (x, y, z), read by somebody standing outside
## it: their right is towards the bow on the starboard side and towards the stern on the port side.
static func _number_on_a_wall(tool: SurfaceTool, digits: String, x: float, z: float, y: float, tall: float,
		side: float) -> void:
	var wide: float = tall * 0.55
	var gap: float = tall * 0.2
	var total: float = float(digits.length()) * wide + float(digits.length() - 1) * gap
	var right: float = -side
	for i in range(digits.length()):
		var left: float = -total * 0.5 + float(i) * (wide + gap)
		for segment in segments_of(digits[i]):
			var p: Vector2 = segment[0]
			var q: Vector2 = segment[1]
			var a := Vector3(x, y - tall * 0.5 + p.y * tall, z + right * (left + p.x * wide))
			var b := Vector3(x, y - tall * 0.5 + q.y * tall, z + right * (left + q.x * wide))
			var thick: float = tall * 0.07
			var run: Vector3 = b - a
			var up: Vector3 = Vector3(0.0, 1.0, 0.0) if absf(run.y) < 0.01 else Vector3(0.0, 0.0, 1.0)
			var spread: Vector3 = run.cross(Vector3(side, 0.0, 0.0)).normalized() * thick
			if spread.length_squared() < 1e-6:
				spread = up * thick
			var corners: Array[Vector3] = [a + spread, b + spread, b - spread, a - spread]
			var normal: Vector3 = (corners[2] - corners[0]).cross(corners[1] - corners[0])
			if normal.dot(Vector3(side, 0.0, 0.0)) < 0.0:
				corners.reverse()
			Plating.quad(tool, corners, WHITE)


## ---- the weapons, the gun tubs and the LSO ------------------------------------------------------------------------

## THE FORD'S DEFENCES on their sponsons: two Mk 29 ESSM launchers, two Mk 49 RAM launchers and three Phalanx mounts
## (CONFIRMED as a fit). WHERE they stand is UNVERIFIED -- the sheet found only "RAM on the forward sponson" -- so they are
## at the corners of the flight deck, the Nimitz-class arrangement, each on a platform below the deck edge.
static func _weapons(tool: SurfaceTool, deck: float) -> void:
	var sponsons: Array = [
		["essm", Vector2(31.0, -90.0)], ["essm", Vector2(-22.5, 154.0)],
		["ram", Vector2(-22.5, -121.0)], ["ram", Vector2(31.0, 144.0)],
		["ciws", Vector2(-21.0, -142.0)], ["ciws", Vector2(30.5, 118.0)], ["ciws", Vector2(9.0, 163.0)],
	]
	for entry in sponsons:
		var at: Vector2 = entry[1]
		var y: float = deck - 4.5
		Plating.box(tool, Vector3(at.x, y - 0.5, at.y), Vector3(6.0, 1.0, 7.0), HAZE)
		Plating.box(tool, Vector3(at.x, y - 2.2, at.y), Vector3(1.2, 2.4, 1.2), HAZE)
		match String(entry[0]):
			"essm":
				Plating.box(tool, Vector3(at.x, y + 1.4, at.y), Vector3(2.6, 2.4, 3.6), HAZE)
				Plating.box(tool, Vector3(at.x, y + 2.7, at.y - 1.9), Vector3(2.4, 0.3, 0.3), BLACK)
			"ram":
				Plating.box(tool, Vector3(at.x, y + 0.6, at.y), Vector3(1.6, 1.2, 1.6), HAZE)
				Plating.box(tool, Vector3(at.x, y + 1.9, at.y - 0.3), Vector3(1.4, 1.2, 2.6), HAZE)
			"ciws":
				Plating.box(tool, Vector3(at.x, y + 0.7, at.y), Vector3(1.8, 1.4, 1.8), HAZE)
				Plating.box(tool, Vector3(at.x, y + 2.3, at.y), Vector3(1.3, 1.9, 1.3), WHITE)
				Plating.box(tool, Vector3(at.x, y + 1.4, at.y - 1.6), Vector3(0.25, 0.25, 2.0), BLACK)


## THE GUN TUBS the two 12.7 mm gunners stand in: a platform and a waist-high ring of plate round each `station` part.
## The gun on its pintle is drawn by VehicleView, over the seat, as every ship's is.
static func _gun_tubs(tool: SurfaceTool, parts: Array) -> void:
	for part in parts:
		if String(part["part"]) != "station":
			continue
		var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
		var floor_at: float = float(part["bottom"])
		Plating.box(tool, Vector3(r.get_center().x, floor_at - 0.1, r.get_center().y), Vector3(r.size.x, 0.2, r.size.y),
			STEEL)
		var ring: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in range(4):
			Plating.bar(tool, ring[i], ring[(i + 1) % 4], 0.08, floor_at, floor_at + 1.05, HAZE)
		Plating.box(tool, Vector3(r.get_center().x, floor_at - 1.2, r.get_center().y), Vector3(0.4, 2.0, 0.4), HAZE)


## THE LANDING SIGNAL OFFICER'S PLATFORM on the port deck edge abeam the wires, a metre below the deck, with a windscreen
## on its forward side against the wind over the deck.
static func _lso_platform(tool: SurfaceTool, deck: float) -> void:
	var r: Rect2 = CarrierPlan.LSO
	var y: float = deck - 1.1
	Plating.box(tool, Vector3(r.get_center().x, y - 0.1, r.get_center().y), Vector3(r.size.x, 0.2, r.size.y), STEEL)
	Plating.bar(tool, Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), 0.1, y, y + 1.3, GLASS)
	Plating.bar(tool, Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), 0.08, y, y + 1.0, HAZE)


## ---- helpers ------------------------------------------------------------------------------------------------------

static func _first(parts: Array, role: String) -> Dictionary:
	for part in parts:
		if String(part.get("part", "")) == role:
			return part
	return {}


## An elevator is a deck part the size of one: 25.9 by 15.8 m.
static func _is_elevator(r: Rect2) -> bool:
	return absf(r.size.y - 25.9) < 0.5 and absf(r.size.x - 15.8) < 0.5
