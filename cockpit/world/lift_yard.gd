extends Node3D
class_name LiftYard
## WHERE THE AIR IS GOING UP, MADE VISIBLE -- WHICH IS THE WHOLE POINT OF HAVING IT.
##
## Rising air is invisible, and a game where it is invisible is a game where a glider pilot
## flies in circles hoping. Real pilots do not do that. They read the sky: a thermal that has
## reached the condensation level grows a CUMULUS CLOUD on top of itself, and that cloud is a
## sign saying "lift, here, up to about this height". Working a good cloud street is flying
## from one marker to the next, and it is the most legible thing in the sport.
##
## So every lift zone in the world gets one. The cloud is drawn at the TOP of the column and
## sized by the column, so the sky itself is the map: a big cloud is a strong wide thermal, a
## low flat one is the ridge, and clear sky between them is sink.
##
## THREE MARKS, EACH FOR A DIFFERENT DISTANCE.
##
##   THE CLOUD, from kilometres away, which is what you turn towards.
##   THE COLUMN of faint rising wisps, from a few hundred metres, which is what you aim at
##   once you are close enough to have to be accurate.
##   THE RING on the ground under it, which is what you circle over -- the one mark that
##   says exactly where the core is when you are inside the thermal and looking down.
##
## NOTHING HERE IS ON THE WIRE. A lift zone is built identically on every peer from the same
## generator, exactly like a mountain, so this is fed from `Terrain.lift_zones()` directly --
## the renderer is reading the same table the simulation was given.
##
## And nothing here is a light. Same rule as the fires and the explosions.

## How many pieces make a cumulus, and how many wisps make a column.
const LUMPS: int = CloudTuning.LUMPS
const WISPS: int = 7
## THE MARKERS STAND ON THE GROUND UNDER THEMSELVES (increment B3, team-lead's ruling, 2026-09-15): the ring RING_OVER over
## the surface and every wisp's start WISP_OVER over it. Both were put off the ground under the zone's CENTRE, which on the
## island's flat slab is the same thing; on a slope that buried the uphill side of the ring and the uphill wisps and left
## the downhill side floating (found by cockpit-mist reading B3). A ring over uneven ground is DRAPED, RING_PIECES straight
## pieces round its middle circle, each end on the surface under it; a ring over level ground is today's one hoop. REJECTED:
## keeping lift to near-level ground -- slopes are where lift is.
const RING_OVER: float = 2.0
## WHETHER THE GROUND RINGS ARE DRAWN. Off since 2026-09-19 at the user's word: a pale yellow hoop on the ground under
## every cloud read as a stray shape in every screenshot. The wisps and the cloud still mark the lift.
const SHOW_RINGS: bool = false
const WISP_OVER: float = 6.0
const RING_PIECES: int = 48
## THE HOOP, in radii of its zone: the torus's inner and outer radius, named once (cockpit-mist's review) so that a thicker
## hoop moves the draped pieces with it -- the pieces run round the tube's middle circle and are as wide and as thick as it.
const RING_INNER: float = 0.88
const RING_OUTER: float = 1.0
const RING_MIDDLE: float = (RING_INNER + RING_OUTER) * 0.5
const RING_TUBE: float = RING_OUTER - RING_INNER
## How fast a wisp climbs, as a fraction of the column's own strength. They are not tracked
## particles -- each one is a fraction of the way up, all the time, and it wraps.
const WISP_RATE: float = 0.055
## HOW ROUND A WISP IS, its height against its width, and the sphere it is drawn on. They were 0.35 on an 8 by 4 sphere,
## and from the clouds, mountains and fire views (2026-09-12 to 2026-09-14) every one of them read as a flat translucent
## octagon hanging in mid-air rather than as rising air -- the lead asked what the discs were. A 16 by 8 sphere is 153
## vertices a wisp against 45, and there are seven a column.
const WISP_ROUND: float = 0.7
const WISP_SEGMENTS: int = 16
const WISP_RINGS: int = 8
## HOW FAR FROM THE EYE A WISP IS STILL SEEN: whole out to the first distance, gone by the second. A column of rising air is
## a mark for somebody close enough to aim at the thermal (see the note at the top); from a peak two kilometres off it was
## a scatter of discs over the whole island, some of them between the eye and a mountain.
const WISP_SEEN := Vector2(600.0, 2500.0)
## THE WISP'S OWN MATERIAL: haze with a soft rim and a soft bottom rather than one alpha all over. See the shader's note.
const WISP_SHADER: Shader = preload("res://world/shaders/wisp.gdshader")
const WISP_TINT := Color(0.86, 0.90, 0.96)
const WISP_RIM: float = 1.5
const WISP_SOFT_BOTTOM: float = 0.45
## How wide a cloud is against the column under it. A cumulus is far wider than the thermal
## that made it, which is why it is the part you can see.
const CLOUD_SPREAD: float = 2.1
## How far the whole column leans per metre of height, per metre a second of wind. The same
## lean the smoke gets, for the same reason: it is the air doing it.
const LEAN: float = 0.055

## THE CLOUD ON THE FINE FINISH: the same lumps, in the same places, drawn with a shape. See the
## note at the top of the shader. Both finishes are lit by cloud_light.gdshaderinc, from `cloud_light`.
const CUMULUS: Shader = preload("res://world/shaders/cumulus.gdshader")
## THE CLOUD ON THE PLAIN FINISH: the same spheres, cut flat at the cloud's base and lit per vertex. See the shader.
const CUMULUS_PLAIN: Shader = preload("res://world/shaders/cumulus_plain.gdshader")
## EACH FINISH'S RIM: the soft edge round the lumps, blended, the next pass of that finish's material, lit with every number the
## core is. See world/shaders/cumulus_lump.gdshaderinc for why it replaced a stipple.
const CUMULUS_RIM: Shader = preload("res://world/shaders/cumulus_rim.gdshader")
const CUMULUS_PLAIN_RIM: Shader = preload("res://world/shaders/cumulus_plain_rim.gdshader")
## Laps for the scenery probe; nothing unless it is running. See `world/stopwatch.gd`.
const STOPWATCH := preload("res://world/stopwatch.gd")
## Rings and segments of the sphere a fine lump is displaced on. The plain one has 12 by 8 and
## nothing to displace; this one needs enough vertices for a lump to have lumps on it, and no more
## -- 279 of them in the sky at once.
const LUMPY_SEGMENTS: int = 24
const LUMPY_RINGS: int = 14

## THREE MULTIMESHES AND NOTHING ELSE, which is what the scenery already does with the
## mountains: a lift zone drawn as nodes is seventeen meshes, and thirty-one zones is five
## hundred draw calls for something nobody is looking at most of the time. One instance per
## cloud lump, one per wisp, one per ring, in three batches.
##
## The wisps are the only part that moves, and a MultiMesh transform is cheap to rewrite --
## so the animation costs one buffer update a frame rather than two hundred node transforms.
var _clouds: MultiMeshInstance3D = null
var _wisps: MultiMeshInstance3D = null
var _rings: MultiMeshInstance3D = null
## The pieces of every ring draped over uneven ground, in the rings' own material.
var _draped: MultiMeshInstance3D = null
## Where each wisp runs from and to, and how fast: everything `_process` needs, flat, in the
## same order as the instances in the mesh above.
var _runs: Array = []
var _zones: Array[Dictionary] = []
var _age: float = 0.0
## How many wisps the batch was last told to draw, so `visible_instance_count` is written when it changes and not every frame.
var _wisps_shown: int = -1
## Whether the mesh clouds are drawn: false with no clouds in the session's sky, or on a probe that asked for none. The
## wisps and rings stay either way. See `show_clouds`.
var draws_clouds: bool = true
## `cloud_key(zone)` -> {"first": its first instance in the batch, "lumps": `cloud_lumps` as drawn}, so one cloud's lumps can
## be faded without knowing where the others are.
var _cloud_at: Dictionary = {}
## `cloud_key` -> the fog share last shown, for the tests: headless answers a default for every instance read back.
var _fog_shares: Dictionary = {}
## How deep in a cloud the eye is, 0 to 1, as the level last said. The rings and wisps fade out by it.
var _eye_depth: float = 0.0


## Both ways of drawing a cloud, built once and swapped between. See `_wear`.
var _plain_lump: Mesh = null
var _fine_lump: Mesh = null
var _plain_paint: Material = null
var _fine_paint: Material = null
## EVERY CLOUD'S ENVELOPE, in the order of the batch -- (centre, 0) and (radii, 0) -- written onto both lump materials, so each
## lump is lit through its own cloud (`world/shaders/cloud_envelopes.gdshaderinc`). Kept for a material made later.
var _envelope_at := PackedVector4Array()
var _envelope_radii := PackedVector4Array()


func _ready() -> void:
	set_process(false)
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", _wear)


## CLOUDS OR NONE, told by the level (`FlightLevel._show_the_clouds`, plan item 17): kept for the next `show_lift` and put on
## the batch now. Hiding the batch rather than rebuilding it, so turning them back on costs nothing and every lump's fog
## share and light are where they were.
func show_clouds(on: bool) -> void:
	draws_clouds = on
	if _clouds != null:
		_clouds.visible = on


## HOW THE SMOKE AND THE COLUMNS LEAN. Not used here directly -- see `show_lift`, which takes
## the wind -- and kept as the one place the number lives.
func lean_of(wind: Vector3) -> Vector3:
	return wind * LEAN


## BUILD THE SKY. `zones` is `Terrain.lift_zones()` and `wind` is what the simulation was
## told, so the clouds lean the way the air is actually moving.
func show_lift(zones: Array, wind: Vector3) -> void:
	for old in [_clouds, _wisps, _rings, _draped]:
		if old != null:
			old.queue_free()
	_runs.clear()
	_wisps_shown = -1
	_zones.clear()
	_cloud_at.clear()
	_fog_shares.clear()
	for row in zones:
		_zones.append(row)
	# ONE PLAIN CLOUD MATERIAL for the yard's life, as the fine one is: a rebuild that made a new one would leave the
	# light the level last wrote on the old one.
	if _plain_paint == null:
		_plain_paint = _cloud_paint(CUMULUS_PLAIN, CUMULUS_PLAIN_RIM)
	_clouds = _batch(_cloud_mesh(), _plain_paint, zones.size() * LUMPS, false, true)
	_clouds.visible = draws_clouds
	_wisps = _batch(_puff_mesh(), _wisp_paint(),
		zones.size() * WISPS, true)
	var placed_rings: Array[Dictionary] = []
	var level_rings: int = 0
	var ring_pieces: int = 0
	for row in zones:
		var placed: Dictionary = ring_placement(row)
		placed_rings.append(placed)
		if (placed["pieces"] as Array).is_empty():
			level_rings += 1
		else:
			ring_pieces += (placed["pieces"] as Array).size()
	_rings = _batch(_ring_mesh(), _haze(Color(0.98, 0.92, 0.70), 0.20, true), level_rings)
	_draped = _batch(_ring_piece_mesh(), _rings.material_override, ring_pieces)
	# THE RINGS ARE HIDDEN FOR NOW (the user, 2026-09-19: "remove the yellow ring around lift zones for now, it makes
	# screenshots weird"). Still placed, so everything that measures them holds; `SHOW_RINGS` brings them back.
	_rings.visible = SHOW_RINGS
	_draped.visible = SHOW_RINGS
	var level_at: int = 0
	var piece_at: int = 0
	var lean: Vector3 = lean_of(wind)
	var cloud_at: int = 0
	var wisp_at: int = 0
	_envelope_at = PackedVector4Array()
	_envelope_radii = PackedVector4Array()
	if zones.size() > CloudTuning.MOST_CLOUDS:
		push_warning("[lift] %d clouds and the lumps' shaders carry envelopes for %d; the rest are lit as shells"
			% [zones.size(), CloudTuning.MOST_CLOUDS])
	for i in range(zones.size()):
		var zone: Dictionary = zones[i]
		var at: Vector3 = zone["position"]
		var radius: float = float(zone["radius"])
		var stands: float = float(zone["top"]) - at.y
		var strength: float = float(zone["strength"])
		# THE RING on the ground: the footprint, and the one mark that says where the core
		# is when you are directly over it and the cloud is behind your own wing.
		var placed_ring: Dictionary = placed_rings[i]
		if (placed_ring["pieces"] as Array).is_empty():
			_rings.multimesh.set_instance_transform(level_at, placed_ring["level"])
			level_at += 1
		for piece in placed_ring["pieces"]:
			_draped.multimesh.set_instance_transform(piece_at, piece)
			piece_at += 1
		# THE WISPS, climbing. Faint on purpose: this is air, and air you can see clearly is
		# smoke. Enough to be unmistakable from a few hundred metres and not enough to hide
		# the hillside behind it.
		for w in range(WISPS):
			var ends: Array[Vector3] = wisp_ends(zone, w, lean)
			_runs.append({"index": wisp_at, "from": ends[0],
				"to": ends[1],
				"at": float(w) / float(WISPS), "rate": 0.7 + strength * 0.1,
				"wide": radius * 0.5})
			wisp_at += 1
		# AND THE CLOUD ON TOP, which is the part you can see from the other side of the
		# island. A cumulus is a heap of lumps with a FLAT BOTTOM: the flat bottom is the
		# height the air stopped being able to hold its water, and it is the same height for
		# every cloud in the sky -- which is exactly what the top of a lift zone is.
		var pieces: Array[Dictionary] = cloud_lumps(zone, wind)
		_cloud_at[cloud_key(zone)] = {"first": cloud_at, "lumps": pieces, "bounds": cloud_bounds(pieces)}
		if i < CloudTuning.MOST_CLOUDS:
			var envelope: Dictionary = cloud_envelope(pieces)
			var centre: Vector3 = envelope["centre"]
			var radii: Vector3 = envelope["radii"]
			_envelope_at.append(Vector4(centre.x, centre.y, centre.z, 0.0))
			_envelope_radii.append(Vector4(radii.x, radii.y, radii.z, 0.0))
		for piece in pieces:
			_clouds.multimesh.set_instance_transform(cloud_at, piece["transform"])
			_clouds.multimesh.set_instance_custom_data(cloud_at, piece["custom"])
			cloud_at += 1
	_write_the_envelopes()
	_wear(_finish_is_fine())
	_dim_the_markers()
	set_process(not _runs.is_empty())
	_process(0.0)


## WHERE A ZONE'S RING IS DRAWN: `{level, pieces}`. Over level ground -- every one of RING_PIECES points round its middle
## circle on the surface at the zone's own height -- `level` is today's hoop, RING_OVER over the zone's position, and
## `pieces` is empty. Otherwise `pieces` holds RING_PIECES transforms of `_ring_piece_mesh`, each a straight piece from
## one of those points to the next, both ends RING_OVER over the surface under them (`Terrain.surface_height`, the
## ground or the water on it), as wide and as thick as the hoop's tube. Static and pure, like `cloud_lumps`. LEVEL MEANS
## EXACTLY LEVEL: the test is float equality, which is what keeps every island hoop byte for byte; a flat within float noise
## drapes instead, into 48 pieces that lie flat, which is harmless.
static func ring_placement(zone: Dictionary) -> Dictionary:
	var at: Vector3 = zone["position"]
	var radius: float = float(zone["radius"])
	var middle: float = radius * RING_MIDDLE
	var ends: Array[Vector3] = []
	var level: bool = true
	for k in range(RING_PIECES):
		var about: float = TAU * float(k) / float(RING_PIECES)
		var point := Vector3(at.x + cos(about) * middle, 0.0, at.z + sin(about) * middle)
		point.y = Terrain.surface_height(point) + RING_OVER
		level = level and point.y == at.y + RING_OVER
		ends.append(point)
	if level:
		return {"level": Transform3D(Basis.IDENTITY.scaled(Vector3(radius, 1.0, radius)), at + Vector3(0.0, RING_OVER, 0.0)),
			"pieces": []}
	var pieces: Array[Transform3D] = []
	for k in range(RING_PIECES):
		var a: Vector3 = ends[k]
		var b: Vector3 = ends[(k + 1) % RING_PIECES]
		var along: Vector3 = b - a
		var outward := Vector3((a.x + b.x) * 0.5 - at.x, 0.0, (a.z + b.z) * 0.5 - at.z).normalized()
		var up: Vector3 = outward.cross(along).normalized()
		if up.y < 0.0:
			up = -up
		# RIGHT-HANDED WHATEVER WAY THE CIRCLE IS WALKED (cockpit-mist's review): `outward` as the third column after the flip
		# made every piece's basis a mirror, unseen under today's unculled, unshaded ring material and inside out the day it
		# gains culling or light. The box is symmetric, so the picture is the same.
		var across: Vector3 = along.cross(up).normalized() * radius * RING_TUBE
		pieces.append(Transform3D(Basis(along, up, across), (a + b) * 0.5))
	return {"level": Transform3D(), "pieces": pieces}


## WHERE WISP `w` OF A ZONE RISES FROM AND TO: [from, to]. It starts WISP_OVER over the surface under its own start, out
## round the zone as it always was, and climbs straight to the zone's top, leaning with the wind by `lean` times the
## column. Static and pure.
static func wisp_ends(zone: Dictionary, w: int, lean: Vector3) -> Array[Vector3]:
	var at: Vector3 = zone["position"]
	var radius: float = float(zone["radius"])
	var stands: float = float(zone["top"]) - at.y
	var about: float = TAU * float(w) / float(WISPS)
	var out: float = radius * (0.20 + 0.45 * float(w % 3) / 2.0)
	var lift: float = Terrain.surface_height(Vector3(at.x + cos(about) * out, 0.0, at.z + sin(about) * out)) - at.y
	var from: Vector3 = at + Vector3(cos(about) * out, WISP_OVER + lift, sin(about) * out)
	return [from, from + Vector3(0.0, stands - WISP_OVER - lift, 0.0) + lean * stands]


## ONE CLOUD, AS LUMPS: `{transform, custom}` for each of `LUMPS`, from the zone it stands over.
##
## STATIC AND PURE, so a test can ask it what it drew -- headless has a dummy rendering server, and a MultiMesh
## answers a default for every instance read back off it -- and so the MultiMesh, the fog and the test are fed by one function.
##
## SEEDED BY WHERE THE ZONE IS, through `Terrain.hash01`, so a cloud is the same on every launch and every machine.
## A picture only -- nothing here reaches the simulation.
##
## A CLOUD HAS A CHARACTER (2026-09-14, "can you make the shapes different cloud to cloud"): a kind from `cloud_type`, drawn
## from the seed among the kinds the thermal's strength allows, and from its row of `CloudTuning.TYPES` its proportions, its
## own heading to be long along, how its towers lean, how its top shears, its crown bumps, its skirt and its shreds. Every
## lump is stretched along that heading, so a cloud's outline is not a union of round balls. Before it, every cloud was a core,
## up to three towers and a skirt of eleven, and a sheet of the island's clouds read as one family of stacked domes.
##
## `custom` is (base height, thickness, seed, 0), which both cloud shaders cut the lumps level at and light by.
static func cloud_lumps(zone: Dictionary, wind: Vector3) -> Array[Dictionary]:
	var at: Vector3 = zone["position"]
	var radius: float = float(zone["radius"])
	var stands: float = float(zone["top"]) - at.y
	# THE CLOUD'S OWN SHAPE FROM ITS FIRST PLACE, as its kind is (`cloud_type`); the lumps stand over where the zone is.
	var seed_at: Vector3 = zone.get("cloud_seed_at", at)
	var seed_value: int = int(seed_at.x * 0.37 + seed_at.z * 1.91) + 7919
	var kind: Dictionary = cloud_type(zone)
	var reach: float = radius * CLOUD_SPREAD * float(kind["spread"])
	var base: Vector3 = at + Vector3(0.0, stands, 0.0) + wind * LEAN * stands
	var flat: float = lerpf((kind["flatten"] as Vector2).x, (kind["flatten"] as Vector2).y, Terrain.hash01(seed_value, 3))
	var long: float = sqrt(lerpf((kind["elongation"] as Vector2).x, (kind["elongation"] as Vector2).y,
		Terrain.hash01(seed_value, 4)))
	var heading: float = TAU * Terrain.hash01(seed_value, 5)
	var along := Vector3(cos(heading), 0.0, sin(heading))
	var across := Vector3(-sin(heading), 0.0, cos(heading))
	var leaning: float = heading + (Terrain.hash01(seed_value, 6) - 0.5) * PI
	var lean_way := Vector3(cos(leaning), 0.0, sin(leaning))
	var shear: float = float(kind["shear"])
	var pieces: Array[Dictionary] = []
	var aloft: Array[int] = []
	# A POINT IN THE CLOUD'S OWN PLAN -- x along its heading, z across, y up from the base -- in the world: stretched along the
	# heading and pinched across it by the same share, and carried sideways with height by the shear.
	var place := func(local: Vector3) -> Vector3:
		return base + along * local.x * long + across * local.z / long + Vector3.UP * local.y + lean_way * shear * local.y
	# A LUMP TAKES THE SQUARE ROOT OF THE CLOUD'S STRETCH: the whole of it made every lump of a long cloud a saucer from under
	# it (d2-after, the clouds view); the cloud is still as long, by where its lumps stand.
	var lump_long: float = sqrt(long)
	var lump := func(centre_local: Vector3, fat: float, tall: float, stretch: float) -> Transform3D:
		return Transform3D(Basis(along * fat * lump_long * stretch, Vector3.UP * tall, across * fat / lump_long),
			place.call(centre_local))
	# THE CORE: sat on the base in the middle.
	var core_fat: float = reach * lerpf((kind["core"] as Vector2).x, (kind["core"] as Vector2).y, Terrain.hash01(seed_value, 1))
	var core_tall: float = core_fat * flat
	var core_at := Vector3(0.0, core_tall * (0.5 - lerpf(CloudTuning.SINK.x, CloudTuning.SINK.y, Terrain.hash01(seed_value, 2))), 0.0)
	pieces.append({"transform": lump.call(core_at, core_fat, core_tall, 1.0), "local": core_at, "fat": core_fat, "tall": core_tall})
	# TOWERS: each on the last, a share of its width, stepped up and off to the lean.
	var towers: int = int(round(lerpf(float((kind["towers"] as Vector2i).x), float((kind["towers"] as Vector2i).y),
		Terrain.hash01(seed_value, 7))))
	var under_local: Vector3 = core_at
	var under_fat: float = core_fat
	var under_tall: float = core_tall
	for w in range(towers):
		var fat: float = under_fat * lerpf(CloudTuning.TOWER_SIZE.x, CloudTuning.TOWER_SIZE.y, Terrain.hash01(seed_value, 10 + w))
		var tall: float = fat * float(kind["tower_tall"])
		var off: float = TAU * Terrain.hash01(seed_value, 20 + w)
		# A THIRD OF A WIDTH OFF THE ONE BELOW, not a sixth: straight up, three or more towers read as a column of beads.
		var step := Vector3(cos(off), 0.0, sin(off)) * fat * 0.33 + Vector3(1.0, 0.0, 0.0) * fat * float(kind["lean"])
		# A QUARTER OF ITS OWN HEIGHT above the step, not a third: at 0.35 four towers were four beads on a string (d2-round,
		# cloud_each_3 and _4).
		var centre: Vector3 = under_local + step + Vector3.UP * (under_tall * float(kind.get("tower_step", CloudTuning.TOWER_STEP)) + tall * 0.25)
		aloft.append(pieces.size())
		pieces.append({"transform": lump.call(centre, fat, tall, 1.0), "local": centre, "fat": fat, "tall": tall})
		under_local = centre
		under_fat = fat
		under_tall = tall
	# CROWN BUMPS: on the upper side of the core or a tower, so the top is lumpy rather than one dome.
	var upper: int = pieces.size()
	for c in range(int(kind["crown"])):
		var parent: Dictionary = pieces[int(Terrain.hash01(seed_value, 70 + c) * float(upper)) % upper]
		var round_about: float = TAU * Terrain.hash01(seed_value, 80 + c)
		var up_share: float = lerpf(0.45, 0.85, Terrain.hash01(seed_value, 90 + c))
		var dir := Vector3(cos(round_about) * sqrt(1.0 - up_share * up_share), up_share, sin(round_about) * sqrt(1.0 - up_share * up_share))
		var p_fat: float = parent["fat"]
		var p_tall: float = parent["tall"]
		# A THIRD TO HALF THE PARENT, HALFWAY OUT: at a quarter and 0.42 of the way most bumps were inside the dome they sat on.
		var fat: float = p_fat * lerpf(0.32, 0.50, Terrain.hash01(seed_value, 100 + c))
		var centre: Vector3 = (parent["local"] as Vector3) + Vector3(dir.x * p_fat * 0.5, dir.y * p_tall * 0.5, dir.z * p_fat * 0.5)
		if centre.y - fat * flat * 0.5 > 0.0:
			aloft.append(pieces.size())
		pieces.append({"transform": lump.call(centre, fat, fat * lerpf(0.6, 0.9, flat), 1.0), "local": centre, "fat": fat,
			"tall": fat * lerpf(0.6, 0.9, flat)})
	# SHREDS: small, flat and drawn out along the heading, broken away past the rim; on a cloud with towers one in three is
	# torn from a tower's top instead, carried down the shear.
	var ragged: float = float(kind["ragged"])
	for r in range(int(kind["shreds"])):
		if pieces.size() >= CloudTuning.LUMPS:
			break
		var fat: float = reach * lerpf(0.05, 0.13, Terrain.hash01(seed_value, 110 + r))
		# PUFFS, NOT BLADES: at a third as tall as wide and drawn out to 2.6 a torn tower top was a glassy shard (d2-after,
		# cloud_at_300).
		var tall: float = fat * 0.55
		var centre: Vector3
		if towers > 0 and r % 3 == 2:
			centre = under_local + Vector3(under_fat * lerpf(0.5, 0.9, Terrain.hash01(seed_value, 120 + r)), under_tall * 0.55 + tall, 0.0)
			aloft.append(pieces.size())
		else:
			var round_about: float = TAU * Terrain.hash01(seed_value, 130 + r)
			var out: float = reach * lerpf(0.85, 1.05 + 0.15 * ragged, Terrain.hash01(seed_value, 140 + r))
			centre = Vector3(cos(round_about) * out, tall * 0.2, sin(round_about) * out)
		pieces.append({"transform": lump.call(centre, fat, tall, lerpf(1.1, 1.7, Terrain.hash01(seed_value, 150 + r))),
			"local": centre, "fat": fat, "tall": tall})
	# THE SKIRT: every lump left, round the core, sizes drawn squared so most are small; further out and more uneven the more
	# ragged the kind. Sunk into the base, so the cut gives the cloud its flat bottom.
	var s: int = 0
	while pieces.size() < CloudTuning.LUMPS:
		var round_about: float = TAU * (float(s) * 0.618 + Terrain.hash01(seed_value, 30 + s) * (0.35 + 0.4 * ragged))
		var out: float = reach * lerpf(CloudTuning.SKIRT_REACH.x, CloudTuning.SKIRT_REACH.y + 0.25 * ragged,
			Terrain.hash01(seed_value, 40 + s))
		var drawn: float = Terrain.hash01(seed_value, 50 + s)
		var fat: float = reach * lerpf(CloudTuning.SKIRT_SIZE.x * 0.7, CloudTuning.SKIRT_SIZE.y, drawn * drawn)
		var tall: float = fat * flat
		var centre := Vector3(cos(round_about) * out, tall * (0.5 - lerpf(CloudTuning.SINK.x, CloudTuning.SINK.y,
			Terrain.hash01(seed_value, 60 + s))), sin(round_about) * out)
		pieces.append({"transform": lump.call(centre, fat, tall, 1.0), "local": centre, "fat": fat, "tall": tall})
		s += 1
	# NO WIDER THAN ITS THERMAL ALLOWS (`CloudTuning.PLAN_MOST`): measured as the fog's box, and past it every lump is drawn in
	# towards the middle and narrowed by one share, in plan only, so heights and the one base stay.
	var laid: Array[Dictionary] = []
	for piece in pieces:
		laid.append({"transform": piece["transform"], "custom": Color(base.y, 1.0, 0.0, 0.0)})
	var box: AABB = cloud_bounds(laid)
	var squeeze: float = minf(1.0, CloudTuning.PLAN_MOST * radius / maxf(maxf(box.size.x, box.size.z), 1.0))
	if squeeze < 1.0:
		var middle := Vector3(box.get_center().x, 0.0, box.get_center().z)
		for piece in pieces:
			var t: Transform3D = piece["transform"]
			var flat_in := Vector3(squeeze, 1.0, squeeze)
			var origin := Vector3(middle.x + (t.origin.x - middle.x) * squeeze, t.origin.y, middle.z + (t.origin.z - middle.z) * squeeze)
			piece["transform"] = Transform3D(Basis(t.basis.x * flat_in, t.basis.y * flat_in, t.basis.z * flat_in), origin)
	var top: float = 0.0
	for piece in pieces:
		var t: Transform3D = piece["transform"]
		top = maxf(top, t.origin.y - base.y + t.basis.y.length() * 0.5)
	var thickness: float = maxf(top, 1.0)
	var seed_share: float = Terrain.hash01(seed_value, 99)
	var out: Array[Dictionary] = []
	for piece in pieces:
		out.append({"transform": piece["transform"], "custom": Color(base.y, thickness, seed_share, 0.0)})
	return out


## WHAT KIND OF CLOUD A ZONE GROWS: a row of `CloudTuning.TYPES`, drawn by the zone's seed among the kinds whose strength range
## holds the thermal's, each by its weight. Static and pure.
static func cloud_type(zone: Dictionary) -> Dictionary:
	# A ZONE MOVED OFF THE ISLAND'S MOUNTAINS keeps the kind its first place gave it (Terrain._lift_off_the_rock); any other
	# zone's kind is its own place's.
	var at: Vector3 = zone.get("cloud_seed_at", zone["position"])
	var strength: float = float(zone["strength"])
	var seed_value: int = int(at.x * 0.37 + at.z * 1.91) + 7919
	var allowed: Array[Dictionary] = []
	var total: float = 0.0
	for kind in CloudTuning.TYPES:
		var band: Vector2 = kind["strength"]
		if strength >= band.x and strength <= band.y:
			allowed.append(kind)
			total += float(kind["weight"])
	if allowed.is_empty():
		return CloudTuning.TYPES[0]
	# HASHED TWICE: `Terrain.hash01` is one mixing round, and with one salt the zones' neighbouring seeds drew spread -- the
	# lightest kind -- for six clouds of eleven strong thermals and congestus for none (tests/air.gd, 2026-09-14).
	var pick: float = Terrain.hash01(int(Terrain.hash01(seed_value, 200) * 1000003.0) + seed_value * 7, 211) * total
	for kind in allowed:
		pick -= float(kind["weight"])
		if pick <= 0.0:
			return kind
	return allowed[-1]


## WHICH CLOUD A ZONE'S IS, as a key that does not depend on how many zones there are or in what order: its position on the
## ground to the metre. CloudBank keys its fog by the same function.
static func cloud_key(zone: Dictionary) -> Vector2i:
	var at: Vector3 = zone["position"]
	return Vector2i(roundi(at.x), roundi(at.z))


## HOW MUCH OF ONE CLOUD IS DRAWN AS FOG NOW, 0 to 1, announced by the CloudBank and handed here by the level. The fine lumps
## dissolve in their own dithered cells as it rises (INSTANCE_CUSTOM.a, see `world/shaders/cumulus.gdshader`); a cloud that is
## all fog has its lumps shrunk to a millimetre, so they draw no pixel at all, and they keep their places in the batch.
func show_fog_share(key: Vector2i, share: float) -> void:
	_fog_shares[key] = share
	if _clouds == null or not _cloud_at.has(key):
		return
	var entry: Dictionary = _cloud_at[key]
	var first: int = entry["first"]
	var pieces: Array = entry["lumps"]
	for l in range(pieces.size()):
		var custom: Color = pieces[l]["custom"]
		custom.a = clampf(share, 0.0, 1.0)
		_clouds.multimesh.set_instance_custom_data(first + l, custom)
		var drawn: Transform3D = pieces[l]["transform"]
		if share >= 1.0:
			drawn = Transform3D(Basis.from_scale(Vector3.ONE * 0.001), drawn.origin)
		_clouds.multimesh.set_instance_transform(first + l, drawn)


## The fog share last shown for a cloud, 0 for one never told, for the tests.
func fog_share_shown(key: Vector2i) -> float:
	return float(_fog_shares.get(key, 0.0))


## THE BOX ROUND ONE CLOUD: every lump, swollen by `FOG_SWELL` so the noise has room to erode, from the cloud's one base
## up. Static and pure: the fog volume is this box, and the question "is the eye in a cloud" starts with it.
static func cloud_bounds(lumps: Array[Dictionary]) -> AABB:
	var base: float = (lumps[0]["custom"] as Color).r
	var box := AABB()
	for i in range(lumps.size()):
		var t: Transform3D = lumps[i]["transform"]
		# THE BOX ROUND A TURNED LUMP: each world axis gets every column's share of it, so a lump stretched along a heading
		# that is not an axis is still inside.
		var b: Basis = t.basis
		var half: Vector3 = Vector3(absf(b.x.x) + absf(b.y.x) + absf(b.z.x), absf(b.x.y) + absf(b.y.y) + absf(b.z.y),
			absf(b.x.z) + absf(b.y.z) + absf(b.z.z)) * 0.5 * CloudTuning.FOG_SWELL
		var one := AABB(t.origin - half, half * 2.0)
		box = one if i == 0 else box.merge(one)
	var top: float = box.end.y
	box.position.y = base
	box.size.y = maxf(top - base, 1.0)
	return box


## THE ELLIPSOID A CLOUD IS LIT THROUGH: {"centre", "radii"}, of the same mass and spread as its lumps -- each lump weighed by its
## volume, its centre and its own spread along each world axis -- so a cloud leaning on its towers has its envelope lean with
## it, and a skirt of small lumps barely widens it. A solid ellipsoid's spread along an axis is a fifth of its half-width
## squared, which is how the radii come back out. Static and pure: both lump materials and the fog are handed it, and the test.
static func cloud_envelope(lumps: Array[Dictionary]) -> Dictionary:
	var weight: float = 0.0
	var mean := Vector3.ZERO
	for lump in lumps:
		var t: Transform3D = lump["transform"]
		var w: float = maxf(t.basis.x.length() * t.basis.y.length() * t.basis.z.length(), 1e-6)
		mean += t.origin * w
		weight += w
	mean /= maxf(weight, 1e-6)
	var spread := Vector3.ZERO
	for lump in lumps:
		var t: Transform3D = lump["transform"]
		var b: Basis = t.basis
		var w: float = maxf(b.x.length() * b.y.length() * b.z.length(), 1e-6)
		# A LUMP'S HALF-WIDTH ALONG EACH WORLD AXIS: a unit-diameter sphere through its basis, turned and stretched.
		var half: Vector3 = Vector3(Vector3(b.x.x, b.y.x, b.z.x).length(), Vector3(b.x.y, b.y.y, b.z.y).length(),
			Vector3(b.x.z, b.y.z, b.z.z).length()) * 0.5
		var off: Vector3 = t.origin - mean
		spread += (half * half / 5.0 + off * off) * w
	spread /= maxf(weight, 1e-6)
	var least: float = CloudTuning.ENVELOPE_LEAST
	return {"centre": mean, "radii": Vector3(maxf(sqrt(spread.x * 5.0), least), maxf(sqrt(spread.y * 5.0), least),
		maxf(sqrt(spread.z * 5.0), least))}


## HOW MANY METRES OF AN ENVELOPE LIE BETWEEN A POINT AND THE SUN: `envelope_sun_depth` in cloud_light.gdshaderinc, in GDScript.
static func envelope_sun_depth(envelope: Dictionary, point: Vector3, towards: Vector3) -> float:
	var radii: Vector3 = (envelope["radii"] as Vector3).max(Vector3.ONE)
	var o: Vector3 = (point - (envelope["centre"] as Vector3)) / radii
	var d: Vector3 = towards / radii
	var a: float = d.dot(d)
	var b: float = o.dot(d)
	var disc: float = b * b - a * (o.dot(o) - 1.0)
	if disc <= 0.0:
		return 0.0
	var s: float = sqrt(disc)
	return maxf((-b + s) / a - maxf((-b - s) / a, 0.0), 0.0)


## THE SHARE OF THE SUN THAT REACHES A POINT THIS DEEP IN A CLOUD: `sun_through` in cloud_light.gdshaderinc, in GDScript.
static func sun_through(depth: float) -> float:
	return maxf(exp(-depth * CloudTuning.SUN_EXTINCTION),
		CloudTuning.SCATTER_FLOOR * exp(-depth * CloudTuning.SUN_EXTINCTION * CloudTuning.SCATTER_REACH))


## Every cloud's envelope onto whichever lump materials exist.
func _write_the_envelopes() -> void:
	for paint in _paints():
		if paint is ShaderMaterial:
			_envelopes_onto(paint)


func _envelopes_onto(paint: ShaderMaterial) -> void:
	# THE ARRAY IS ALWAYS WRITTEN WHOLE, padded to the shader's length, so a cloud past the list reads no envelope rather than
	# the one the last rebuild left.
	var at := _envelope_at.duplicate()
	var radii := _envelope_radii.duplicate()
	at.resize(CloudTuning.MOST_CLOUDS)
	radii.resize(CloudTuning.MOST_CLOUDS)
	paint.set_shader_parameter("envelope_at", at)
	paint.set_shader_parameter("envelope_radii", radii)
	paint.set_shader_parameter("lumps_a_cloud", LUMPS)


## HOW MUCH OF A CLOUD'S ENVELOPE A POINT IS IN, 0 to 1, before the noise: the fog shader's `cloud_shape`, in GDScript.
static func shape_at(lumps: Array[Dictionary], point: Vector3) -> float:
	var base: float = (lumps[0]["custom"] as Color).r
	var best: float = 0.0
	for lump in lumps:
		var t: Transform3D = lump["transform"]
		# THROUGH THE LUMP'S OWN BASIS: a lump is a unit sphere of radius 0.5 turned and stretched, so its inverse takes the
		# point into that sphere's frame, and twice that over the swell is where the fog shader's ellipsoid is.
		var d: Vector3 = t.basis.inverse() * (point - t.origin) * 2.0 / CloudTuning.FOG_SWELL
		best = maxf(best, 1.0 - smoothstep(CloudTuning.FOG_LUMP_SOFT, 1.0, d.dot(d)))
	return best * smoothstep(0.0, CloudTuning.FOG_BASE_SOFT, point.y - base)


## HOW DENSE A CLOUD IS AT A POINT, 0 to 1: the fog shader's `cloud_density` of that envelope with the noise at its mean of
## 0.5 -- the envelope less the margin the erosion takes off it, rather than a copy of the noise. A mesh cloud and a fog one
## answer the same, so PLAIN's whiteout begins where FINE's fog would.
static func cloud_density_at(lumps: Array[Dictionary], point: Vector3) -> float:
	var shape: float = shape_at(lumps, point)
	return clampf((shape - 0.5 * CloudTuning.FOG_EROSION) / maxf(1.0 - CloudTuning.FOG_EROSION, 0.05), 0.0, 1.0)


## WHERE AN EYE IS AMONG THE CLOUDS: {"depth": how dense the densest cloud it is in is there, 0 to 1, "key": that cloud's
## `cloud_key`, or (0, 0) for none}. Only a cloud whose box holds the eye is asked about its lumps, so a sky of clouds costs
## a box test each.
func eye_in_cloud(eye: Vector3) -> Dictionary:
	var depth: float = 0.0
	var found: Vector2i = Vector2i.ZERO
	for key in _cloud_at:
		var entry: Dictionary = _cloud_at[key]
		if not (entry["bounds"] as AABB).has_point(eye):
			continue
		var here: float = cloud_density_at(entry["lumps"], eye)
		if here > depth:
			depth = here
			found = key
	return {"depth": depth, "key": found}


## THE EYE IS IN A CLOUD, as deep as this, handed over by the level. The rings and wisps are additive and unshaded, so
## neither fog nor depth fog hides them: from inside the clouds view's cloud the ring on the ground 1.5 km below still
## showed (cloud_inside, 2026-09-14). They fade out with the depth, on both finishes.
func show_eye_in_cloud(depth: float) -> void:
	_eye_depth = clampf(depth, 0.0, 1.0)
	_dim_the_markers()


## THE COLOUR OF A CLOUD FROM INSIDE IT at a time of day: `cloud_light.gdshaderinc` in GDScript, half-way up a cloud of the
## middle thickness, facing up, no lining -- what the depth fog is pulled to when there is no fog to fly into. Worked in
## linear light as the shader works it, and handed back as the colour a property takes. HALF-WAY INTO ITS ENVELOPE, too: buried
## 0.5, with half the middle thickness of cloud between it and the sun, which is where an eye flown into a cloud's heart is.
static func cloud_colour(look: Dictionary) -> Color:
	var light: Dictionary = cloud_light(look)
	var sun: Color = (light["sun_light"] as Color).srgb_to_linear()
	var sky: Color = (light["sky_light"] as Color).srgb_to_linear()
	var towards: Vector3 = light["towards_sun"]
	var rise: float = 0.5
	var thickness: float = (CloudTuning.THICK.x + CloudTuning.THICK.y) * 0.5
	var facing: float = clampf(Vector3.UP.dot(towards) * 0.5 + 0.5, 0.0, 1.0)
	var base_share: float = lerpf(CloudTuning.BASE_BRIGHT.x, CloudTuning.BASE_BRIGHT.y,
		smoothstep(CloudTuning.THICK.x, CloudTuning.THICK.y, thickness))
	var depth_light: float = lerpf(base_share, 1.0, smoothstep(0.0, 0.7, rise))
	var sun_share: float = lerpf(CloudTuning.AWAY, CloudTuning.SUNLIT, facing * facing) * depth_light \
		* sun_through(thickness * 0.5)
	var hollow: float = lerpf(1.0, CloudTuning.CORE_SHADE, smoothstep(0.0, 0.7, 0.5))
	var ambient_share: float = lerpf(base_share, 1.0, rise) * CloudTuning.AMBIENT * hollow
	var mixed := Color(sun.r * sun_share + sky.r * ambient_share, sun.g * sun_share + sky.g * ambient_share,
		sun.b * sun_share + sky.b * ambient_share, 1.0)
	return mixed.linear_to_srgb()


## HOW A CLOUD IS LIT BY A LOOK (`DaylightTuning.look_at`), worked out from its own numbers -- the light, the ambient, the
## sky and the fog -- so a cloud cannot disagree with the sky round it. Static, for the test. The ambient is the sky's
## middle colour, the ambient colour, or between as the look's `ambient_sky` says, as the engine mixes them.
static func cloud_light(p: Dictionary) -> Dictionary:
	var energy: float = float(p["ambient_energy"])
	var sky: Color = ((p["ambient_colour"] as Color) * energy).lerp(
		(p["sky_top"] as Color).lerp(p["sky_horizon"], 0.5) * energy, float(p["ambient_sky"]))
	return {
		"sun_light": (p["sun_colour"] as Color) * float(p["sun_energy"]),
		"towards_sun": p["towards_light"],
		"sky_light": sky,
		"shade_light": (p["ground_horizon"] as Color).lerp(p["fog_colour"], CloudTuning.SHADE_FROM_FOG) * energy,
	}


## THE SHARES OF THAT LIGHT A CLOUD TAKES, as the uniforms of `cloud_light.gdshaderinc`: every material a cloud is drawn
## with sets these -- both mesh finishes and CloudBank's fog -- so the fog near the eye is the colour of the lumps it
## replaces. Static, for the bank.
static func cloud_light_shares() -> Dictionary:
	return {"base_bright": CloudTuning.BASE_BRIGHT, "thick_range": CloudTuning.THICK, "sunlit": CloudTuning.SUNLIT,
		"away": CloudTuning.AWAY, "ambient_share": CloudTuning.AMBIENT, "lining": CloudTuning.LINING,
		"lining_tightness": CloudTuning.LINING_TIGHTNESS, "sun_extinction": CloudTuning.SUN_EXTINCTION,
		"scatter_floor": CloudTuning.SCATTER_FLOOR, "scatter_reach": CloudTuning.SCATTER_REACH,
		"core_shade": CloudTuning.CORE_SHADE, "translucent": CloudTuning.TRANSLUCENT}


## The wisps rise, and nothing else moves. A cloud that drifted would have to drift
## somewhere, and a thermal is where it is -- the whole thing is a marker.
func _process(delta: float) -> void:
	_age += delta
	if _wisps == null:
		return
	var watch: int = STOPWATCH.start()
	# FROM THE CAMERA THE VIEWPORT IS DRAWN WITH, which in a headset is the midpoint of the eyes: the same fade in both.
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var seeing: bool = camera != null
	var eye: Vector3 = camera.global_position if seeing else Vector3.ZERO
	# ONLY THE WISPS THAT CAN BE SEEN ARE DRAWN: the rest are packed off the end of the batch by `visible_instance_count`,
	# because a wisp faded to nothing is still a hundred and fifty vertices of work in both eyes. Written when it changes.
	var shown: int = 0
	for run in _runs:
		var one: Dictionary = run
		var up: float = fposmod(float(one["at"]) + _age * WISP_RATE * float(one["rate"]),
			1.0)
		var fat: float = float(one["wide"]) * (0.4 + up * 0.9)
		var at: Vector3 = (one["from"] as Vector3).lerp(one["to"] as Vector3, up)
		var alpha: float = wisp_alpha(up, at.distance_to(eye) if seeing else 0.0)
		if alpha <= 0.0005:
			continue
		_wisps.multimesh.set_instance_transform(shown, Transform3D(
			Basis.IDENTITY.scaled(Vector3(fat, fat * WISP_ROUND, fat)), at))
		_wisps.multimesh.set_instance_color(shown, Color(1.0, 1.0, 1.0, alpha))
		shown += 1
	if shown != _wisps_shown:
		_wisps.multimesh.visible_instance_count = shown
		_wisps_shown = shown
	STOPWATCH.lap(&"lift_wisps", watch)


## HOW STRONG A WISP IS DRAWN, `up` of the way up its column and `distance` metres from the eye, 0 to 1 of the material's
## alpha. Brightest in the middle of the climb -- a wisp that appeared and vanished at full strength would blink at the bottom
## and the top -- and faded out with distance (`WISP_SEEN`). Static and pure, so a test can ask it.
static func wisp_alpha(up: float, distance: float) -> float:
	return sin(up * PI) * (1.0 - smoothstep(WISP_SEEN.x, WISP_SEEN.y, distance))


## How many zones are drawn, for the tests.
func columns() -> int:
	return _zones.size()


## ---- the time of day -----------------------------------------------------------------

## How bright the rings and the wisps are drawn, against how they were drawn before there was a night. See
## `DaylightTuning`'s "markers".
const RING_ALPHA: float = 0.20
const WISP_ALPHA: float = 0.12
var _markers: float = 1.0
## The look the clouds were last lit by, or {} before the level has said.
var _look: Dictionary = {}
## How many times a cloud material has been lit, ever: tests/scenery.gd holds it still for sixty frames, because a
## light written every frame looks exactly like one written once.
var light_writes: int = 0


## HOW BRIGHT THE MARKERS ARE, handed over by the level once per change of the time of day. They are unshaded --
## light rather than substance -- so the sun going down does nothing to them, and at night the pale wisps and the
## yellow rings were the brightest things on the island (2026-09-13). One alpha on each of two materials, once.
##
## AND HOW THE CLOUDS ARE LIT: both finishes' clouds are unshaded and light themselves from `cloud_light`, written onto
## their two materials here, once.
func show_daylight(look: Dictionary) -> void:
	_look = look
	_markers = float(look["markers"])
	_dim_the_markers()
	_light_the_clouds()


func _light_the_clouds() -> void:
	if _look.is_empty():
		return
	var light: Dictionary = cloud_light(_look)
	for paint in _paints():
		if paint == null:
			continue
		for field in light:
			(paint as ShaderMaterial).set_shader_parameter(field, light[field])
		light_writes += 1


## What each finish's cloud is lit with now, PLAIN then FINE, read off the materials, for the tests. Null for a finish
## whose material has not been made yet.
func cloud_lit_with(field: String) -> Array:
	var out: Array = []
	for paint in [_plain_paint, _fine_paint]:
		out.append((paint as ShaderMaterial).get_shader_parameter(field) if paint is ShaderMaterial else null)
	return out


## ONE CLOUD MATERIAL, either finish: the shader, `CloudTuning`'s shares, and the light for the time of day if the level
## has said one.
func _cloud_paint(shader: Shader, rim_shader: Shader) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = shader
	var shares: Dictionary = cloud_light_shares()
	for field in shares:
		paint.set_shader_parameter(field, shares[field])
	if not _look.is_empty():
		var light: Dictionary = cloud_light(_look)
		for field in light:
			paint.set_shader_parameter(field, light[field])
	_envelopes_onto(paint)
	# AND ITS RIM, the next pass, made the same way with the same numbers.
	if rim_shader != null:
		paint.next_pass = _cloud_paint(rim_shader, null)
	return paint


## EVERY MATERIAL A CLOUD IS DRAWN WITH: each finish's core and its rim, those that exist.
func _paints() -> Array:
	var out: Array = []
	for paint in [_plain_paint, _fine_paint]:
		if paint is ShaderMaterial:
			out.append(paint)
			if (paint as ShaderMaterial).next_pass is ShaderMaterial:
				out.append((paint as ShaderMaterial).next_pass)
	return out


## How bright the markers are drawn now, read off the ring material, for the tests.
func markers() -> float:
	if _rings == null:
		return _markers
	return (_rings.material_override as StandardMaterial3D).albedo_color.a / RING_ALPHA


func _dim_the_markers() -> void:
	if _rings != null:
		(_rings.material_override as StandardMaterial3D).albedo_color.a = RING_ALPHA * _markers * (1.0 - _eye_depth)
	if _wisps != null:
		(_wisps.material_override as ShaderMaterial).set_shader_parameter("tint",
			Color(WISP_TINT.r, WISP_TINT.g, WISP_TINT.b, WISP_ALPHA * _markers * (1.0 - _eye_depth)))


## WHETHER THE CLOUDS ARE DRAWN FINE, read off the material they actually have -- which is what
## a test has to ask, rather than what the tier says they should have.
func wears_fine() -> bool:
	# BY WHICH MATERIAL, not by its type: both finishes' clouds are ShaderMaterials now.
	return _clouds != null and _fine_paint != null and _clouds.material_override == _fine_paint


## ---- the finish ----------------------------------------------------------------------

## PUT A FINISH ON THE CLOUDS. The instances stay exactly where they are; the mesh they are all
## drawn with and the material change, which is one assignment each for the whole sky.
func _wear(fine: bool) -> void:
	if _clouds == null:
		return
	if _plain_lump == null:
		_plain_lump = _clouds.multimesh.mesh
		_plain_paint = _clouds.material_override
	if fine and _fine_lump == null:
		var ball := SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.0
		ball.radial_segments = LUMPY_SEGMENTS
		ball.rings = LUMPY_RINGS
		_fine_lump = ball
		# Made after the time of day may already have been set, so `_cloud_paint` lights it now.
		_fine_paint = _cloud_paint(CUMULUS, CUMULUS_RIM)
	_clouds.multimesh.mesh = _fine_lump if fine else _plain_lump
	_clouds.material_override = _fine_paint if fine else _plain_paint


func _finish_is_fine() -> bool:
	var finish: Node = get_node_or_null("/root/Finish")
	return finish != null and bool(finish.call("is_fine"))


## ---- the batches ---------------------------------------------------------------------

func _batch(mesh: Mesh, paint: Material, count: int,
		tinted: bool = false, carries_cloud: bool = false) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = mesh
	# BEFORE THE COUNT, AND THAT ORDER IS THE WHOLE OF IT. A MultiMesh refuses to change
	# whether it carries colours once it has any instances -- "Instance count must be 0 to
	# toggle whether colors are used" -- so setting `use_colors` after the count is a call
	# that fails, and every `set_instance_color` after it fails too. The wisps then all draw
	# at the material's flat alpha, the fade in `_process` does nothing, and the only sign
	# of it is an error per wisp per frame on stderr, which nothing was reading.
	many.use_colors = tinted
	# AND THE SAME FOR CUSTOM DATA, which is where a cloud lump carries its cloud's base and thickness.
	many.use_custom_data = carries_cloud
	many.instance_count = maxi(count, 0)
	node.multimesh = many
	node.material_override = paint
	# NEVER CULLED. Every instance in a batch shares one set of bounds, and a cloud two
	# kilometres downwind of the zone that made it is a long way outside them -- so the
	# whole sky would wink out as the aeroplane turned.
	node.extra_cull_margin = 16384.0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## PLAIN'S LUMP: a 24 by 12 sphere, not 12 by 8. With a blended rim the outline is the mesh's own polygon -- the rim's alpha does
## not reach nothing along an edge between two silhouette vertices -- and at 12 by 8 a lump overhead read as a faceted ellipsoid
## (step1-final, before-over-after-clouds-plain-day-crop.png), which the old hashed stipple had hidden.
func _cloud_mesh() -> Mesh:
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 24
	ball.rings = 12
	return ball


func _puff_mesh() -> Mesh:
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = WISP_SEGMENTS
	ball.rings = WISP_RINGS
	return ball


## ONE PIECE OF A DRAPED RING: a unit box as thick as the hoop's tube, stretched from end to end and across by its transform.
func _ring_piece_mesh() -> Mesh:
	var piece := BoxMesh.new()
	piece.size = Vector3(1.0, RING_TUBE, 1.0)
	return piece


func _ring_mesh() -> Mesh:
	var hoop := TorusMesh.new()
	hoop.inner_radius = RING_INNER
	hoop.outer_radius = RING_OUTER
	hoop.rings = 24
	hoop.ring_segments = 6
	return hoop


## AIR, DRAWN. Unshaded and additive for the warm marks -- the ring and the wisps are light
## rather than substance -- and never culled, because a cloud whose origin has left the
## frustum is a cloud that vanishes while you are turning towards it.
## THE WISPS' ONE MATERIAL: the wisp shader with its tint at the markers' brightness, its rim and its soft bottom.
func _wisp_paint() -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = WISP_SHADER
	paint.set_shader_parameter("tint", Color(WISP_TINT.r, WISP_TINT.g, WISP_TINT.b, WISP_ALPHA * _markers))
	paint.set_shader_parameter("rim_power", WISP_RIM)
	paint.set_shader_parameter("soft_bottom", WISP_SOFT_BOTTOM)
	return paint


func _haze(tint: Color, alpha: float, additive: bool) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive \
		else BaseMaterial3D.BLEND_MODE_MIX
	paint.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	# PER-INSTANCE COLOUR, which is how a batch of two hundred wisps can fade one at a time.
	# Without this the multimesh's colours are carried and then ignored, and every wisp in
	# the sky is the same brightness at every height -- which is a column of beads again.
	paint.vertex_color_use_as_albedo = true
	return paint

