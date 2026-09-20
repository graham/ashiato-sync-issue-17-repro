@tool
extends RefCounted
class_name Fireboat
## A FIREBOAT, UP CLOSE: the FDNY *Three Forty Three*'s hull and superstructure, built round the parts the simulation
## floats and seats her by (`fireboat_shape`), in the faceted house style.
##
## THE WORD IS MONITOR. A fireboat's "water gun" is a **monitor** -- a deluge gun -- the trainable nozzle bolted to the
## deck or the mast; a hose is the flexible thing a firefighter carries. She carries three, two forward on the open
## foredeck and one aft on the after deckhouse, as the user asked; the real boat has eleven.
##
## THE MONITORS ARE THE SIMULATION'S THREE TURRET MOUNTS, which is why they cost nothing on the wire. `kMaxTurrets`
## is 3 and `CraftSystems.turret_yaw/pitch` has carried three aims since the gunship -- replicated, rolled back and
## interpolated already -- and a monitor is a `Gun` in that table's terms: a place, a barrel, train and elevation
## limits, a slew rate and a muzzle speed, which for water is the nozzle's exit velocity. What it is NOT is something
## that fires a round, and `Gun::water` is what says so: without it a turret seat's trigger reaches `fire_round`
## unconditionally and the first pull puts tracer out of a fire hose. `monitor()` below draws one; the mount is
## aimed by `VehicleView.draw_turrets_at` like any other.
##
## WHAT MAKES ONE READ AS A FIREBOAT FROM THE WATER, off the photographs in `cockpit/craft/fireboat/sources.md`: a deep
## RED hull with WHITE upperworks, which is the livery of nearly every fireboat afloat; a tall bluff bow with a lot of
## flare and a black rub strake wrapped round it; an OPEN FOREDECK inside a white bulwark, with the boat's name on the
## RED topside below it; the deckhouse and wheelhouse aft of amidships; a red machinery casing abaft that carrying
## FOUR RAKED EXHAUST STACKS -- one per engine, and the photograph and the published "4 x MTU 2,000 hp" agree on the
## count without either being asked; and an open after deck.
##
## THE FOREDECK IS OPEN, AND IT TOOK TWO RED CHECKS TO HEAR THAT. Drawn with a deckhouse running forward to z -15 she
## looked perfectly plausible and `tests/ship_models.gd` failed four ways: from both helms neither the bow nor the
## deck ahead was in sight. Stepping that house down fixed the BOW and left the DECK AHEAD hidden -- and the second
## failure is the one that mattered, because it sent me back to the photograph rather than to the arithmetic. There is
## no forward deckhouse on this boat. What reads as one in a profile is a white bulwark round an open deck, and the
## two forward monitors stand on it. **The fix was to delete a part, not to tune one.**
##
## THE HULL IS LOFTED HERE rather than by `Superstructure`, for the CB90's reason: the rows below are this boat's, a
## full bluff bow above water fining to a narrow keel, over TWENTY stations rather than forty, which is the house look.
## The top row and the waterline row are the part's own outline, so she floats where she looks as if she floats.
##
## SEGMENT COUNTS, so nobody subdivides her later (`modelling_here.md` section 4): the hull is 20 STATIONS BY 6 ROWS,
## where the warships use 40 stations. EVERYTHING ELSE IS A FLAT BOX -- stacks, bollards, mast, radomes, stanchions,
## rails, searchlights -- because `Plating.box` gives every face its own normal and a boat read at two kilometres is a
## silhouette of blocks. Nothing here is round at all, which is further than the Hawkeye's 20-side nacelle goes and is
## deliberate: there is no cylinder anywhere on her.
##
## EVERY COLOUR IS AT LEAST 0.03 FROM EVERY OTHER in some channel, because `SurfaceTool.commit` quantises vertex colour
## to eight bits and every check here finds a part BY its colour (`modelling_here.md` section 4). `RED_FITTING` and
## `HULL_RED` differ by 0.07 in red on purpose: a monitor must be tellable from the hull it stands on.
##
## ONE MESH, ONE DRAW CALL, like every ship here (`Plating`).

## WHAT SHE IS AT A DISTANCE. A fireboat is not haze grey at any range, so her silhouette takes her own paint rather
## than `ShipHull.PAINT`'s warship colours -- the same reason the tanker and the ferry carry one.
const FAR: Dictionary = {
	"hull": Color(0.55, 0.09, 0.09),
	"deck": Color(0.42, 0.42, 0.40),
	"island": Color(0.86, 0.87, 0.88),
	"bridge": Color(0.10, 0.12, 0.13),
}

## THE LIVERY. Judged from the photographs rather than sampled out of them: a photograph's exposure and its shadows are
## not the paint, and the sunlit and shaded faces of this hull read 0.33 and 0.12 in red on one frame.
const HULL_RED := Color(0.55, 0.09, 0.09)
const RED_FITTING := Color(0.62, 0.11, 0.10)
const BOOT := Color(0.07, 0.07, 0.08)
const ANTIFOUL := Color(0.36, 0.12, 0.10)
const WHITE := Color(0.86, 0.87, 0.88)
const DECK := Color(0.42, 0.42, 0.40)
const STRIPE := Color(0.94, 0.55, 0.10)
const DARK := Color(0.12, 0.13, 0.13)
const STEEL := Color(0.30, 0.32, 0.34)
## THE GLAZING'S TRIM. It was (0.10, 0.12, 0.13) and `tests/fireboat.gd` failed it: 0.02 from `DARK` on every
## channel, where the doc block above claims 0.03. The check caught this file's own sentence being untrue, which
## is the only thing that ever catches a sentence. Pushed bluer and darker so the two part in blue.
const GLASS_TRIM := Color(0.06, 0.10, 0.16)

## THE HULL'S SECTIONS, top down: `[y, width share, stem in, stern in]`. A POSITIVE y is a fraction of the deck height
## and a negative one is metres below the waterline, which is `CombatBoat`'s convention and is kept so the two boats
## read alike. Six of them: the deck edge; the topside; the top and the bottom of the boot-top band 0.30 m either side
## of the waterline; the turn of the bilge; the keel. The stem comes in 0.9 m by the waterline and 3.6 m by the keel,
## which is the raked forefoot the photographs show.
const ROWS: Array = [
	[1.00, 1.00, 0.00, 0.00],
	[0.35, 0.99, 0.35, 0.02],
	[0.125, 0.97, 0.80, 0.05],
	[-0.30, 0.95, 1.00, 0.06],
	[-1.30, 0.86, 1.95, 0.20],
	[-2.74, 0.30, 3.60, 0.70],
]
const STATIONS: int = 20
## HOW FAR THE BLACK BOOT-TOP REACHES EITHER SIDE OF THE WATERLINE, metres, and it is under half `HullLoft`'s default.
##
## THE FIRST PICTURE OF HER WAS A BLACK BOAT WITH A RED STRIPE. `HullLoft.BOOT_TOP` is 0.8 m, chosen against warships
## with eight metres of freeboard, where 1.6 m of black at the waterline IS a stripe. She has 2.4 m of freeboard, so
## the same band swallowed most of her topside -- and being RED is the whole of what a fireboat looks like. The two
## rows at +0.30 and -0.30 were added so a band this narrow has somewhere to land: without them no row midpoint falls
## inside it and she would have had no waterline at all. Nothing but a picture would have caught either.
const BOOT_BAND: float = 0.35
## HOW MUCH THE DECK EDGE RISES AT THE BOW over its height amidships, metres. [M] the deck edge stands 2.88 m over the
## water forward and 2.25 m aft; the part's top is 2.40, so the bow is lifted and the stern left alone. It is an UPPER
## BOUND rather than a measurement -- see `sources.md`, "a confound that cannot be resolved from one photograph": the
## fitted waterline falls aft too, and the bow wave alone would do that.
const SHEER_BOW: float = 0.50
## The black rub strake wrapped round the sheer, its depth and how far it stands proud.
const STRAKE_HIGH: float = 0.45
const STRAKE_OUT: float = 0.10
## Bulwarks: how high the plating stands above the deck where there is no deckhouse.
const BULWARK: float = 1.05
## THE D-SECTION FENDERS: how far they stand OUTSIDE the hull, and how thick. They stand outside the published beam on
## purpose, because that is where a fender is -- a published beam is the MOULDED beam and a rubbing fender is bolted to
## the outside of it. It is why `tests/fireboat.gd` measures the beam off the HULL'S OWN COLOUR rather than off the
## whole drawn box: measured over everything, she reads 4 per cent fat and the wrong thing gets blamed.
const FENDER_PROUD: float = 0.22
const FENDER_THICK: float = 0.34
## Rails on the superstructure: waist high, a stanchion every 1.8 m.
const RAIL_HIGH: float = 1.05
const RAIL_EVERY: float = 1.8
## THE FOUR EXHAUST STACKS, one per engine: how far apart they stand across the casing, how tall, and how far they rake
## aft over their height. They are what the model declares as `exhaust_ports()`.
const STACK_ACROSS: float = 1.05
const STACK_HIGH: float = 2.60
const STACK_RAKE: float = 0.85
const STACK_WIDE: float = 0.34


## THE NEAR MODEL: `{"mesh", "panels", "fittings"}`, as every ship builder returns it.
static func build(geometry: Dictionary, helm: String) -> Dictionary:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = geometry.get("parts", []) as Array
	var panels: Array[AABB] = []
	var fittings: Array[AABB] = []
	var hull: Dictionary = Superstructure.part_of(parts, "hull")
	var room: Dictionary = Superstructure.part_of(parts, "bridge")
	# THE ISLANDS ARE TAKEN FORWARD TO AFT, and which one is the casing is asked of `casing_of` rather than of a slot.
	# There are four today -- the low forward house, the wheelhouse base, the casing and the after house -- and there
	# were three yesterday, which is the whole argument against counting them.
	var islands: Array = []
	for part in parts:
		if String(part.get("part", "")) == "island":
			islands.append(part)
	islands.sort_custom(func(a, b): return _middle_z(a) < _middle_z(b))
	if not hull.is_empty():
		var outline: PackedVector2Array = hull["outline"]
		var top: float = float(hull["top"])
		var rows: Array = []
		for row in ROWS:
			rows.append([lerpf(0.0, top, float(row[0])) if float(row[0]) >= 0.0 else float(row[0]),
				float(row[1]), float(row[2]), float(row[3])])
		# THE DECK IS PLATED BY THE LOFT, not by `Plating.paint`: with sheer on the top row a flat polygon at one height
		# is both a lie and the thing a "what stands under this" check actually finds (`HullLoft`, cockpit-fleet3).
		HullLoft.build(tool, outline, rows, 0.0, [HULL_RED, BOOT, ANTIFOUL], STATIONS,
			Vector2(SHEER_BOW, 0.0), DECK, BOOT_BAND)
		_rub_strake(tool, outline, top)
		_bulwarks(tool, outline, top, islands)
		_deck_rails(tool, outline, top, islands, fittings)
		_bollards(tool, outline, top)
		_fenders(tool, outline, top)
	var casing: Dictionary = casing_of(parts)
	for island in islands:
		# THE CASING IS THE RED ONE and the rest are white. Which is which is asked of the SHAPE -- `casing_of` takes
		# the TALLEST island, because a funnel housing stands higher than accommodation -- and never of an index into
		# the table. An index was the first version and it broke the same day: the deckhouse had to be split in two to
		# let the helm see the bow, the casing moved from slot 1 to slot 2, and the boat's funnels would have been
		# painted onto her accommodation.
		var is_casing: bool = not casing.is_empty() and is_equal_approx(_middle_z(island), _middle_z(casing))
		_block(tool, island, RED_FITTING if is_casing else WHITE, panels, fittings)
		if is_casing:
			_stacks(tool, island, fittings)
		else:
			_stripe(tool, island)
	if not room.is_empty():
		panels.append_array(Wheelhouse.build(tool, room, ["fore", "port", "starboard"], WHITE, GLASS_TRIM))
		_on_the_roof(tool, room, fittings)
	_rails(tool, parts, islands, fittings)
	# THE PORTS RIDE WITH THE MESH THAT HAS THEM. A ship's model is a scriptless node, so nothing can be asked a method
	# the way an airframe is (`VehicleView.exhaust_ports`); handing them back here means they go through `ShipHull`'s
	# ONE dispatch on the shape's name and are cached with the mesh. A second `match` over ship names, purely to find
	# an exhaust, would be exactly the roster this workshop keeps deleting.
	return {"mesh": Plating.weld(tool), "panels": panels, "fittings": fittings,
		"ports": exhaust_ports(geometry)}


## WHERE THE EXHAUST LEAVES HER, in the craft's own frame: the top of each of the four stacks, raked aft. Read by
## `VehicleView.exhaust_ports`, which is what keeps `tests/exhaust.gd`'s ratchet where it is -- a kind with thrust and
## no ports owes one. Four, because she has four engines: the photographs show four raked stacks in a row and the
## published figure is "4 x MTU 2,000 hp", two facts that never saw each other.
static func exhaust_ports(geometry: Dictionary) -> Array:
	var out: Array = []
	var casing: Dictionary = casing_of(geometry.get("parts", []) as Array)
	if casing.is_empty():
		return out
	var r: Rect2 = Wheelhouse.outline_rect(casing["outline"])
	var roof: float = float(casing["top"])
	for i in range(4):
		var x: float = (float(i) - 1.5) * STACK_ACROSS
		# A DICTIONARY, NOT A POINT: `ExhaustYard.lay` casts every port to one, and this returned bare `Vector3`s until
		# 2026-09-20, which was 279 script errors a run in `crew_sync` from the moment anybody boarded her. The gas leaves
		# up the funnel's own rake. `FAN` and not `JET`: a diesel stack throws a haze and no burner core, and the yard
		# reads which layers to draw off the KIND (`ExhaustTuning.layers_of`).
		out.append({"at": Vector3(x, roof + STACK_HIGH, r.get_center().y - STACK_RAKE),
			"axis": Vector3(0.0, STACK_HIGH, STACK_RAKE).normalized(), "radius": STACK_WIDE * 0.5,
			"kind": ExhaustTuning.Kind.FAN, "heat": 0.4})
	return out


## THE MACHINERY CASING: the TALLEST island. ONE PLACE, because the builder paints it red and `exhaust_ports` stands
## the funnels on it, and two answers to "which block is the casing" is two answers that can disagree. Asked as a
## property of the shape rather than as a slot in it, a block added or reordered later sorts itself.
static func casing_of(parts: Array) -> Dictionary:
	var best: Dictionary = {}
	for part in parts:
		if String(part.get("part", "")) != "island":
			continue
		if best.is_empty() or float(part.get("top", 0.0)) > float(best.get("top", 0.0)):
			best = part
	return best


static func _middle_z(part: Dictionary) -> float:
	return Wheelhouse.outline_rect(part.get("outline", PackedVector2Array())).get_center().y


## THE RUB STRAKE: the black band round the sheer, proud of the side, which on the real boat is a heavy rubber fender
## wrapped from bow to quarter. It is the single most recognisable thing about her bow.
static func _rub_strake(tool: SurfaceTool, outline: PackedVector2Array, top: float) -> void:
	var ring: PackedVector2Array = Plating.upward(outline)
	var n: int = ring.size()
	for i in range(n):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % n]
		var out: Vector2 = Vector2(b.y - a.y, -(b.x - a.x)).normalized() * STRAKE_OUT
		Plating.bar(tool, a + out, b + out, 0.14, top - 0.06 - STRAKE_HIGH, top - 0.06, DARK)


## BULWARKS where the deck is open: a plate standing on the deck edge round the forecastle and the after deck, so the
## crew are not walking on a raft. Left out where a deckhouse already stands on the edge.
static func _bulwarks(tool: SurfaceTool, outline: PackedVector2Array, top: float, islands: Array) -> void:
	# WHERE THE DECKHOUSE STARTS. The bulwark is the FOREDECK'S breakwater and stops there; abaft it the deck edge
	# carries rails, which is what the photographs show and what keeps her from reading as a barge.
	var house_from: float = INF
	for island in islands:
		house_from = minf(house_from, Wheelhouse.outline_rect(island["outline"]).position.y)
	if house_from == INF:
		return
	# WALKED IN SHORT STEPS ALONG THE SHEER, not segment by segment round the outline -- and that is the fix rather
	# than a tidy-up. The hull has eight plan corners, so one segment runs from the shoulder all the way to the
	# transom; testing whether a SEGMENT lies abaft the deckhouse is therefore false for almost every segment, and
	# the first version drew a 1.05 m white bulwark down the WHOLE LENGTH of the boat. Every check stayed green --
	# it is plate at the deck edge wherever it is -- and she read as a barge with high white sides. Stepping the
	# walk lets the test be asked per metre, which is the question that was meant all along.
	var ring: PackedVector2Array = Plating.upward(outline)
	var n: int = ring.size()
	for i in range(n):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % n]
		var along: float = a.distance_to(b)
		var steps: int = maxi(1, int(ceil(along / 1.2)))
		for s_at in range(steps):
			var p: Vector2 = a.lerp(b, float(s_at) / float(steps))
			var q: Vector2 = a.lerp(b, float(s_at + 1) / float(steps))
			if (p.y + q.y) * 0.5 > house_from:
				continue
			Plating.bar(tool, p, q, 0.10, top, top + BULWARK, WHITE)
			var mid: Vector2 = (p + q) * 0.5
			Plating.box(tool, Vector3(mid.x, top + BULWARK + 0.035, mid.y),
				Vector3(absf(q.x - p.x) + 0.16, 0.07, absf(q.y - p.y) + 0.16), DARK)


## BOLLARDS down each side, where a boat is made fast: an eight-sided post with a collar, on the deck edge.
static func _bollards(tool: SurfaceTool, outline: PackedVector2Array, top: float) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(outline)
	for z in [r.position.y + 3.0, r.position.y + 9.0, 0.0, r.end.y - 9.0, r.end.y - 3.0]:
		var half: float = HullLoft.half_width(outline, z) - 0.45
		if half <= 0.0:
			continue
		for side in [-1.0, 1.0]:
			var at := Vector3(side * half, top + BULWARK, z)
			var post := AABB(at - Vector3(0.14, 0.0, 0.14), Vector3(0.28, 0.42, 0.28))
			Plating.box(tool, post.get_center(), post.size, DARK)
			Plating.box(tool, at + Vector3(0.0, 0.44, 0.0), Vector3(0.40, 0.07, 0.40), DARK)


## THE BIG D-SECTION FENDERS down the sheer, which every working boat carries and which read as scale up close.
static func _fenders(tool: SurfaceTool, outline: PackedVector2Array, top: float) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(outline)
	var z: float = r.position.y + 6.0
	while z < r.end.y - 3.0:
		var half: float = HullLoft.half_width(outline, z)
		for side in [-1.0, 1.0]:
			# PLACED BY ITS CENTRE, and that is not a tidy-up. Built as an AABB from a corner at `side * half - 0.10`
			# it came out ASYMMETRIC: 0.24 m proud to starboard and 0.10 m sunk INTO the hull to port, because the
			# corner moves with the sign and the size does not. No dimension check can see it -- the drawn beam is
			# whatever the wider side says -- and on the water it would read as a boat with fenders down one side.
			Plating.box(tool, Vector3(side * (half + FENDER_PROUD - FENDER_THICK * 0.5), top - 1.20, z),
				Vector3(FENDER_THICK, 0.90, 0.64), DARK)
		z += 5.5


## A SUPERSTRUCTURE BLOCK: its plated sides, a window strip where it is accommodation, and a darker cap so the roof
## reads as a roof rather than as the top of a slab.
static func _block(tool: SurfaceTool, part: Dictionary, tint: Color, panels: Array[AABB],
		fittings: Array[AABB]) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
	var low: float = float(part["bottom"])
	var high: float = float(part["top"])
	Plating.prism(tool, part["outline"], low, high, tint)
	# THE ROOF CAP, inset, so the top is angled plate and not a lid. `modelling_here.md` section 6: a rim as wide as the
	# thing it rims IS a lid and no vertex check can see it, so this one is deliberately narrower than the block.
	var cap := AABB(Vector3(r.position.x + 0.30, high, r.position.y + 0.30),
		Vector3(r.size.x - 0.60, 0.08, r.size.y - 0.60))
	Plating.box(tool, cap.get_center(), cap.size, STEEL)
	fittings.append(cap)
	panels.append(AABB(Vector3(r.position.x, low, r.position.y), Vector3(r.size.x, high - low, r.size.y)))


## THE ORANGE STRIPE along a white block, which is the FDNY band the photographs show, and a row of windows under it.
static func _stripe(tool: SurfaceTool, part: Dictionary) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(part["outline"])
	var low: float = float(part["bottom"])
	var high: float = float(part["top"])
	var band: float = lerpf(low, high, 0.62)
	Plating.band(tool, r.grow(0.02), band, band + 0.22, STRIPE)
	Plating.band(tool, r.grow(0.03), lerpf(low, high, 0.72), lerpf(low, high, 0.90), GLASS_TRIM)


## THE FOUR EXHAUST STACKS on the casing roof, raked aft: flat-sided blades rather than pipes, which is what the
## photographs show and what a modern boat has. Their tops are `exhaust_ports`.
static func _stacks(tool: SurfaceTool, casing: Dictionary, fittings: Array[AABB]) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(casing["outline"])
	var roof: float = float(casing["top"])
	var rake := Basis(Vector3.RIGHT, atan2(STACK_RAKE, STACK_HIGH))
	for i in range(4):
		var x: float = (float(i) - 1.5) * STACK_ACROSS
		var middle := Vector3(x, roof + STACK_HIGH * 0.5, r.get_center().y - STACK_RAKE * 0.5)
		Plating.box(tool, middle, Vector3(STACK_WIDE, STACK_HIGH, 0.70), DARK, rake)
		fittings.append(AABB(middle - Vector3(STACK_WIDE, STACK_HIGH, 0.70) * 0.5,
			Vector3(STACK_WIDE, STACK_HIGH, 0.70)))


## ON THE WHEELHOUSE ROOF: the mast, two radomes, the aerials and the searchlights. A fireboat's roof is busy and it is
## most of what tells her from a tug at a distance.
static func _on_the_roof(tool: SurfaceTool, room: Dictionary, fittings: Array[AABB]) -> void:
	var r: Rect2 = Wheelhouse.outline_rect(room["outline"])
	var roof: float = float(room["top"])
	var mast_at := Vector2(0.0, r.get_center().y + 0.40)
	var mast := AABB(Vector3(mast_at.x - 0.10, roof, mast_at.y - 0.10), Vector3(0.20, 3.40, 0.20))
	Plating.box(tool, mast.get_center(), mast.size, WHITE)
	fittings.append(mast)
	# TWO RADOMES on a crosstree, which every harbour boat carries and which read at a kilometre.
	Plating.box(tool, Vector3(0.0, roof + 2.40, mast_at.y), Vector3(2.60, 0.12, 0.20), WHITE)
	for side in [-1.0, 1.0]:
		# NOT A FITTING THAT STANDS: a radome hangs on the MAST 2.5 m up, not on the roof, so it is not held to a
		# part's top -- the same distinction the CB90 draws for its waterjet buckets.
		var dome := AABB(Vector3(side * 1.10 - 0.26, roof + 2.52, mast_at.y - 0.26), Vector3(0.52, 0.46, 0.52))
		Plating.box(tool, dome.get_center(), dome.size, WHITE)
		var whip := AABB(Vector3(side * (r.size.x * 0.5 - 0.20), roof, r.end.y - 0.30), Vector3(0.05, 2.20, 0.05))
		Plating.box(tool, whip.get_center(), whip.size, DARK)
		fittings.append(whip)
		# SEARCHLIGHTS on the forward corners, which a fireboat works by at night.
		var lamp := AABB(Vector3(side * (r.size.x * 0.5 - 0.35), roof, r.position.y + 0.30), Vector3(0.36, 0.34, 0.40))
		Plating.box(tool, lamp.get_center(), lamp.size, STEEL)
		fittings.append(lamp)


## RAILS round every superstructure roof: square stanchions and two rails, in the boat's own red, which is what the
## photographs show and what makes her read as a working deck rather than a block of flats.
static func _rails(tool: SurfaceTool, parts: Array, islands: Array, fittings: Array[AABB]) -> void:
	for island in islands:
		var r: Rect2 = Wheelhouse.outline_rect(island["outline"])
		var roof: float = float(island["top"])
		var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in range(4):
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			var along: float = a.distance_to(b)
			var steps: int = maxi(1, int(along / RAIL_EVERY))
			for s in range(steps + 1):
				var at: Vector2 = a.lerp(b, float(s) / float(steps))
				# A ROOF THAT SOMETHING ELSE STANDS ON GETS NO RAIL THERE, because the post would be drawn inside the
				# wall above it. Asked of every part that STANDS ON THIS ROOF -- bridge included, which is why this is
				# not `Superstructure.top_under`: that helper looks at hull, deck and island only, so the wheelhouse is
				# invisible to it and eight stanchions would have been posted inside the wheelhouse's walls with every
				# check green (nothing holds a fitting against a BRIDGE it is buried in; `ship_models` exempts the
				# bridge from its "buried" test on purpose, because a seated crew's heads are inside one).
				if _something_stands_here(parts, at, roof):
					continue
				var post := AABB(Vector3(at.x - 0.035, roof, at.y - 0.035), Vector3(0.07, RAIL_HIGH, 0.07))
				Plating.box(tool, post.get_center(), post.size, RED_FITTING)
				fittings.append(post)
			for height in [RAIL_HIGH, RAIL_HIGH * 0.55]:
				Plating.bar(tool, a, b, 0.05, roof + height - 0.05, roof + height, RED_FITTING)


## WHETHER ANOTHER BLOCK STANDS ON THIS ROOF AT THIS PLAN POINT: any island or bridge whose floor is at or above it.
## Its own roof does not count as standing on itself.
static func _something_stands_here(parts: Array, at: Vector2, roof: float) -> bool:
	for part in parts:
		if not (String(part.get("part", "")) in ["island", "bridge"]):
			continue
		if float(part.get("bottom", 0.0)) < roof - 0.05:
			continue
		if Geometry2D.is_point_in_polygon(at, part.get("outline", PackedVector2Array())):
			return true
	return false


## ---- the monitors ---------------------------------------------------------------------------------------------
##
## A MONITOR, drawn at its mount's origin and pointing down the craft's nose at rest, which is where `Gun::rest_yaw`
## of zero puts it. `VehicleView` turns the mount by `Basis(UP, yaw) * Basis(RIGHT, pitch)`, so a barrel drawn along
## -Z swings with the train and lifts with the elevation, and positive pitch raises it.
##
## THE PEDESTAL IS NOT PART OF THIS. It is drawn by `monitor_pedestal` as a SIBLING of the mount, for the same reason
## the pintle gun's post is: a pedestal is bolted to the deck and does not elevate with the barrel. Drawn as a child
## it would lie over on its side every time the crew depressed the monitor.
##
## FACETED, LIKE THE REST OF HER: two stacked boxes for the taper rather than a cone, and a ring at the nozzle. There
## is no cylinder anywhere on this boat.
static func monitor(barrel: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# EVERY PART OF IT SCALES WITH THE BARREL, so `Gun::barrel` makes the whole mount bigger rather than growing one
	# long thin pipe out of a small box. The first version had the body typed at 0.56 m against a 1.6 m barrel and on
	# a 42.7 m boat the monitors read as door furniture -- the one thing she is FOR, invisible at any distance.
	var g: float = barrel / 2.20
	# THE SWIVEL BODY at the trunnion, which is the origin the mount turns about.
	Plating.box(tool, Vector3.ZERO, Vector3(0.82 * g, 0.74 * g, 0.82 * g), RED_FITTING)
	# THE CHEEKS the barrel is trunnioned between, so it reads as a mount and not as a pipe stuck in a box.
	for side in [-1.0, 1.0]:
		Plating.box(tool, Vector3(side * 0.50 * g, 0.0, -0.14 * g),
			Vector3(0.17 * g, 0.62 * g, 0.66 * g), STEEL)
	# THE BARREL, in two steps so it tapers without a cone.
	Plating.box(tool, Vector3(0.0, 0.0, -barrel * 0.30),
		Vector3(0.44 * g, 0.44 * g, barrel * 0.60), RED_FITTING)
	Plating.box(tool, Vector3(0.0, 0.0, -barrel * 0.76),
		Vector3(0.31 * g, 0.31 * g, barrel * 0.40), RED_FITTING)
	# THE NOZZLE at the end of it, which is where the water leaves and what `muzzle_at` reports.
	Plating.box(tool, Vector3(0.0, 0.0, -barrel), Vector3(0.38 * g, 0.38 * g, 0.18 * g), DARK)
	# THE SUPPLY ELBOW under the swivel, the big bore coming up out of the deck.
	Plating.box(tool, Vector3(0.0, -0.50 * g, 0.14 * g),
		Vector3(0.50 * g, 0.44 * g, 0.50 * g), RED_FITTING)
	return Plating.weld(tool)


## THE PEDESTAL A MONITOR STANDS ON: a column from whatever it is bolted to up to the mount, and a base flange. Drawn
## as a sibling of the mount and never turned. `stands_on` is the top of the part under it, so the column reaches the
## deck rather than a typed height (`modelling_here.md` section 5).
static func monitor_pedestal(mount_y: float, stands_on: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var high: float = maxf(mount_y - stands_on - 0.40, 0.10)
	Plating.box(tool, Vector3(0.0, stands_on + high * 0.5, 0.0), Vector3(0.56, high, 0.56), RED_FITTING)
	Plating.box(tool, Vector3(0.0, stands_on + 0.06, 0.0), Vector3(0.94, 0.12, 0.94), STEEL)
	return Plating.weld(tool)


## WHERE THE WATER LEAVES A MONITOR, in the mount's own frame: exactly `barrel` along its forward, and NOTHING ELSE.
##
## THAT IS WHAT `Gun::barrel` ALREADY MEANS -- "how far the muzzle is out along the barrel from the mount" -- and it
## is the only way the drawn nozzle, the drawer that launches the stream and the SIMULATION that works out where the
## water lands can all agree. The first version put the barrel 0.09 m above the trunnion because it looked better,
## which would have meant the C++ douse and the GDScript stream disagreed about where the water was by that much,
## for ever, with nothing to say so. The barrel is drawn on the axis instead.
static func muzzle_at(barrel: float) -> Vector3:
	return Vector3(0.0, 0.0, -barrel)


## RAILS ALONG THE AFTER DECK, where the foredeck's bulwark stops. A working deck aft is railed, not plated: that is
## what the photographs show, and it is also what keeps a 42 m boat from reading as a barge with high white sides.
## The two are complementary by construction -- the bulwark is drawn forward of the deckhouse and these abaft it, off
## the same `house_from`/`house_to`, so no length of the sheer gets both and none gets neither.
static func _deck_rails(tool: SurfaceTool, outline: PackedVector2Array, top: float, islands: Array,
		fittings: Array[AABB]) -> void:
	var house_to: float = -INF
	for island in islands:
		house_to = maxf(house_to, Wheelhouse.outline_rect(island["outline"]).end.y)
	if house_to == -INF:
		return
	var ring: PackedVector2Array = Plating.upward(outline)
	var n: int = ring.size()
	for i in range(n):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % n]
		var along: float = a.distance_to(b)
		var steps: int = maxi(1, int(ceil(along / RAIL_EVERY)))
		var last := Vector2.ZERO
		var have := false
		for s_at in range(steps + 1):
			var p: Vector2 = a.lerp(b, float(s_at) / float(steps))
			if p.y < house_to:
				have = false
				continue
			var post := AABB(Vector3(p.x - 0.035, top, p.y - 0.035), Vector3(0.07, RAIL_HIGH, 0.07))
			Plating.box(tool, post.get_center(), post.size, RED_FITTING)
			fittings.append(post)
			if have:
				for height in [RAIL_HIGH, RAIL_HIGH * 0.55]:
					Plating.bar(tool, last, p, 0.05, top + height - 0.05, top + height, RED_FITTING)
			last = p
			have = true
