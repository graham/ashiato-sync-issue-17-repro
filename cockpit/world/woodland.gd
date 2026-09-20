extends Node3D
class_name Woodland
## THE WOODS, DRAWN: EVERY TREE IN EVERY STAND IN `Forests`, AND NOTHING THE SIMULATION WILL EVER HEAR OF.
##
## A tree is a picture. It is not a box in `Terrain.boxes()`, it is never handed to `Sim`, and an
## aeroplane flown into a wood flies through it -- which is what the user asked for: trees that are
## "very cheap; they need no collision, just visible (like grass but a forest)". So this node is
## built once, from the catalogue and the ground, and never touched again: no `_process`, and no
## render state written on any frame. The trees thin and fade with distance in the vertex shader
## (`world/shaders/forest.gdshaderinc`), not by moving anything here.
##
## PLANTED BY HASH, NOT STORED. A stand is a lattice in its own frame, and each lattice point's
## rank, wander, height, kind, tint, lean and wind phase come from `Terrain.hash01` of the stand and
## the point -- so every machine grows the same wood and there is no list of trees anywhere. A
## point is a tree only if it lands inside its rectangle and its box is clear of everything
## `Terrain.ground_keepouts` names: a runway approach, the railway, a fire, a spawn, a gate, a
## mountain, a tower. Anything a stand overlaps is carved out tree by tree.
##
## PLAIN'S TREES ARE A SUBSET OF FINE'S. Both finishes plant on FINE's lattice; PLAIN keeps the
## points whose rank is under its share of FINE's trees per hectare. Switching finish adds trees
## between the ones already there instead of reshuffling the wood.
##
## CHUNKED, because a MultiMesh is culled as one box: a wood drawn as one mesh is all in or all out.
## Chunks are squares of `chunk` metres in the stand's own frame, so a narrow diagonal stand makes
## no half-empty cells; each is one MultiMeshInstance3D, one mesh, one surface, one draw. 64 m
## cells on FINE were planned and REJECTED on arithmetic: the two starting stands make 68 chunks at
## 128 m and 272 at 64 m, over the 250 draws the woods, towns and lights share before towns and
## lights draw anything. FINE's denser near ring is the shader's `near_range`/`far_share` instead.
##
## REJECTED, and why (see agents.md for the measurements):
## - ALPHA-CUT LEAF CARDS: a cut-out loses the early depth test on a tiled GPU (a standalone
##   headset's; the desktop under Forward+, the renderer since 2026-09-14, is not tiled, and this
##   was not re-measured there), and a wood of cards
##   is overdraw times two eyes times the multisampling. Grass rejected them first.
## - CAMERA-FACING BILLBOARDS: a card turned to face the head turns with the head in a headset and
##   is a different card in each eye (godot#41567).
## - OCTAHEDRAL IMPOSTORS: they need baked texture atlases, and this project has no textures at all.
## - PLACING TREES IN A PARTICLE SHADER: worth it only if tree counts outgrow buffers built here once;
##   the starting woods are about fifteen thousand FINE trees, built in a fraction of a second.
##
## SHADOWS OFF on every chunk. Instanced shadows redraw every tree into the shadow map; the forest
## floor the grass shader paints (`forest_floor.gdshaderinc`) stands in for the shade under a wood.
##
## EVERY NUMBER IS IN `world/forest_tuning.gd`, and `tests/forest.gd` changes each one in turn and
## fails if the wood does not change with it.

const TUNING := preload("res://world/forest_tuning.gd")
const PLAIN_SHADER: Shader = preload("res://world/shaders/forest.gdshader")
const FINE_SHADER: Shader = preload("res://world/shaders/forest_fine.gdshader")

## The tuning keys the tree shaders take as uniforms of the same name, on both finishes...
const TREE_UNIFORMS: Array[String] = ["fade_from", "fade_to", "near_range", "far_share",
	"conifer_width", "broadleaf_width", "trunk_share", "trunk_width", "conifer_dark",
	"conifer_light", "broadleaf_dark", "broadleaf_light", "trunk_colour"]
## ...on FINE only, whose shader has wind...
const WIND_UNIFORMS: Array[String] = ["sway", "sway_rate"]
## ...and the ones the grass shaders take for the floor, on both finishes and on FINE.
const FLOOR_UNIFORMS: Array[String] = ["floor_colour", "floor_strength", "edge_band", "edge_curve"]
const FINE_FLOOR_UNIFORMS: Array[String] = ["floor_ragged"]

## What was grown, for the probe's log and the tests: trees and chunks per finish, and how long it took.
var planted: Dictionary = {}

var _plain: Node3D = null
var _fine: Node3D = null
var _plain_paint: ShaderMaterial = null
var _fine_paint: ShaderMaterial = null
var _floor_plain: Dictionary = {}
var _floor_fine: Dictionary = {}


func _ready() -> void:
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", _wear)


## GROW EVERY STAND, ONCE. `solid` is `Terrain.boxes()`, which the level has just built for the
## simulation -- handed in rather than built again, because it is the island's four hundred-odd boxes.
## A second call does nothing: the woods are the same woods in every session.
##
## ON THE MAIN THREAD, inside `FlightLevel._build` as the level loads, and nothing hides it: both
## finishes' trees are planted and put into their MultiMeshes here, 143 to 509 ms on the desktop when the
## woods were PLAIN 5,193 and FINE 11,393 trees (the spread is the window's start-up load, not the planting);
## PLAIN 1,892 and FINE 3,768 since they were thinned on 2026-09-13.
## It happens once, before the first frame of the world, so it is a longer load and not a hitch in
## flight. If it ever needs to be one, the planting is pure and static and can move to a thread; the
## MultiMeshes cannot.
func grow(solid: Array[Dictionary], roads: Array[Dictionary]) -> void:
	if _plain != null:
		return
	var began: int = Time.get_ticks_usec()
	# NOT `[] if off else stands()`: a conditional expression hands back a plain Array, and assigning
	# that to a typed one is a script error that aborts `grow` -- which is what `--forest=off` did the
	# first time, and it looked exactly like the forest being switched off.
	var stands: Array[Dictionary] = []
	if not TUNING.switched_off():
		stands = Forests.stands()
	var overrides: Dictionary = TUNING.asked_on_the_command_line()
	var plain_tuning: Dictionary = TUNING.for_tier(false, overrides)
	var fine_tuning: Dictionary = TUNING.for_tier(true, overrides)
	var keepouts: Array[Dictionary] = Terrain.ground_keepouts(solid, roads)
	_plain_paint = paint_for(plain_tuning, false)
	_fine_paint = paint_for(fine_tuning, true)
	_plain = _grow_one("Plain", plant(stands, keepouts, plain_tuning, fine_tuning), plain_tuning,
		_plain_paint)
	_fine = _grow_one("Fine", plant(stands, keepouts, fine_tuning, fine_tuning), fine_tuning,
		_fine_paint)
	_floor_plain = floor_parameters(stands, plain_tuning, false)
	_floor_fine = floor_parameters(stands, fine_tuning, true)
	planted["milliseconds"] = float(Time.get_ticks_usec() - began) / 1000.0
	print("[forest] %d stands%s: plain %d trees in %d chunks, fine %d trees in %d chunks, grown in %.0f ms"
		% [stands.size(), " (switched off)" if TUNING.switched_off() else "",
			int(planted["plain_trees"]), int(planted["plain_chunks"]), int(planted["fine_trees"]),
			int(planted["fine_chunks"]), float(planted["milliseconds"])])
	_wear(_finish_is_fine())


## THE FLOOR UNDER EVERY STAND, onto the ground's two materials: PLAIN's numbers on the plain grass,
## FINE's on the fine. Once, after `grow`.
func paint_the_floor(plain_ground: ShaderMaterial, fine_ground: ShaderMaterial) -> void:
	for pair in [[plain_ground, _floor_plain], [fine_ground, _floor_fine]]:
		var ground: ShaderMaterial = pair[0]
		if ground == null:
			continue
		var values: Dictionary = pair[1]
		for key in values:
			ground.set_shader_parameter(key, values[key])


## Whether the woods are drawn FINE, read off the nodes and the material -- never off the tier.
func wears_fine() -> bool:
	return _fine != null and _fine.visible and not _plain.visible \
		and _fine_paint != null and _fine_paint.shader == FINE_SHADER


## How many chunks and trees the finish that is on is drawing. For the probe.
func chunks_drawn() -> int:
	var holder: Node3D = _fine if wears_fine() else _plain
	return holder.get_child_count() if holder != null else 0


func _wear(fine: bool) -> void:
	if _plain == null:
		return
	_plain.visible = not fine
	_fine.visible = fine


func _finish_is_fine() -> bool:
	var finish: Node = get_node_or_null("/root/Finish")
	return finish != null and bool(finish.call("is_fine"))


func _grow_one(label: String, chunks: Array[Dictionary], tuning: Dictionary,
		paint: ShaderMaterial) -> Node3D:
	var holder := Node3D.new()
	holder.name = label
	add_child(holder)
	var mesh: ArrayMesh = tree_mesh(tuning)
	var trees: int = 0
	for chunk in chunks:
		holder.add_child(chunk_node(chunk, mesh, paint, tuning))
		trees += (chunk["trees"] as Array).size()
	planted[label.to_lower() + "_trees"] = trees
	planted[label.to_lower() + "_chunks"] = chunks.size()
	return holder


## ---- planting -------------------------------------------------------------------------

## EVERY TREE ONE FINISH GROWS, IN CHUNKS: `[{stand, cell, centre, trees: [{position, height,
## conifer, tint, rank, phase, lean_about, lean}]}]`. `tuning` is the finish's own numbers and
## `lattice` FINE's, whose trees per hectare set the lattice both finishes plant on.
##
## Pure, and static, so a test can plant a wood with no level, change one tuning number, and see
## whether the wood changed.
static func plant(stands: Array[Dictionary], keepouts: Array[Dictionary], tuning: Dictionary,
		lattice: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var per_hectare: float = float(lattice["trees_per_hectare"])
	var share: float = float(tuning["trees_per_hectare"]) / maxf(per_hectare, 0.001)
	if share > 1.0:
		push_warning("[forest] %.0f trees a hectare is more than FINE's %.0f, which is the lattice both finishes plant on; held to FINE's"
			% [float(tuning["trees_per_hectare"]), per_hectare])
		share = 1.0
	if share <= 0.0 or per_hectare <= 0.0:
		return out
	var chunk: float = maxf(float(tuning["chunk"]), 1.0)
	var jitter: float = float(tuning["jitter"])
	var lowest: float = float(tuning["height_min"])
	var tallest: float = float(tuning["height_max"])
	var lean_max: float = float(tuning["lean_max"])
	var edge_shrink: float = float(tuning["edge_shrink"])
	# THE BOX A POINT IS CARVED WITH IS THE SAME ON BOTH FINISHES: the larger of this finish's tree and
	# the lattice's (FINE's) at that point, unshrunk. Carved by its own tree, a PLAIN tree that is the
	# larger of the two at a point (PLAIN's shortest is 10 m to FINE's 9) could be carved away beside a
	# keep-out where FINE's is kept, or FINE's wider crown carved where PLAIN's is kept -- and PLAIN's
	# wood is meant to be FINE's with trees taken out. No tree in the starting stands was measured in
	# that case (see `edge_keep` for the 10 that were); this makes it impossible rather than rare. The
	# tree drawn is never larger than the box it was tested with.
	var lattice_lowest: float = float(lattice["height_min"])
	var lattice_tallest: float = float(lattice["height_max"])
	var widest: float = maxf(tallest, lattice_tallest) * maxf(maxf(float(tuning["conifer_width"]),
		float(tuning["broadleaf_width"])), maxf(float(lattice["conifer_width"]),
		float(lattice["broadleaf_width"]))) * 0.5
	for stand in stands:
		var density: float = float(stand["density"])
		if density <= 0.0:
			continue
		var spacing: float = sqrt(10000.0 / (per_hectare * density))
		var half: Vector2 = stand["half"]
		var columns: int = int(ceil(half.x * 2.0 / spacing))
		var rows: int = int(ceil(half.y * 2.0 / spacing))
		# What could touch this stand at all, once; then what could touch each chunk, once each. A tree
		# is tested against a handful of boxes rather than every box on the island.
		var near_stand: Array[Dictionary] = _keepouts_near(keepouts, stand["centre"],
			half.length() + widest)
		var cells: Dictionary = {}
		for i in range(columns):
			for j in range(rows):
				var seed_value: int = _seed(int(stand["index"]), i, j)
				var rank: float = Terrain.hash01(seed_value, 1)
				if rank >= share:
					continue
				var local := Vector2(
					-half.x + (float(i) + 0.5 + (Terrain.hash01(seed_value, 2) - 0.5) * jitter) * spacing,
					-half.y + (float(j) + 0.5 + (Terrain.hash01(seed_value, 3) - 0.5) * jitter) * spacing)
				if absf(local.x) > half.x or absf(local.y) > half.y:
					continue
				# THE EDGE THINS, by the same rank: a tree is kept if its rank is under this finish's share
				# times the edge's chance, so a PLAIN tree near the edge is still a FINE tree there. And the
				# PATCHES AND CLUMPS are one more factor on that chance, the same number on both finishes:
				# see `thinning`.
				var edge: float = edge_keep(stand, local, tuning, lattice)
				if rank >= share * clampf(edge * thinning(stand, local, lattice), 0.0, 1.0):
					continue
				var cell := Vector2i(int(floor((local.x + half.x) / chunk)),
					int(floor((local.y + half.y) / chunk)))
				if not cells.has(cell):
					var middle: Vector3 = Forests.world_of(stand, Vector2(
						-half.x + (float(cell.x) + 0.5) * chunk, -half.y + (float(cell.y) + 0.5) * chunk))
					cells[cell] = {"stand": String(stand["name"]), "cell": cell, "centre": middle,
						"trees": [], "keepouts": _keepouts_near(near_stand, middle, chunk * 0.7072 + widest)}
				var home: Dictionary = cells[cell]
				var conifer: bool = Terrain.hash01(seed_value, 5) < float(stand["mix"])
				var grown: float = Terrain.hash01(seed_value, 4)
				var height: float = lerpf(lowest, tallest, grown) * (1.0 - edge_shrink * (1.0 - edge))
				var kind: String = "conifer_width" if conifer else "broadleaf_width"
				var carve_height: float = maxf(lerpf(lowest, tallest, grown),
					lerpf(lattice_lowest, lattice_tallest, grown))
				var carve_radius: float = carve_height * maxf(float(tuning[kind]), float(lattice[kind])) * 0.5
				var foot: Vector3 = Forests.world_of(stand, local)
				# ON THE GROUND UNDER IT (increment B4): not on water, not past the slope a wood holds, and its foot sunk to the lowest
				# ground under its trunk, so on a slope the downhill edge of the trunk stands on the ground rather than over it. The
				# trunk is the larger of the two finishes' at this point, so both finishes put a tree's foot in the same place. On the
				# island's flat slab none of it moves a tree.
				if Terrain.water_height(foot) != -INF or Terrain.slope_at(foot) > Forests.MOST_TREE_SLOPE:
					continue
				foot.y = lowest_under(foot, carve_height * maxf(float(tuning["trunk_width"]), float(lattice["trunk_width"])) * 0.5)
				if not Terrain.is_clear(home["keepouts"], foot + Vector3.UP * carve_height * 0.5,
						Vector3(carve_radius, carve_height * 0.5, carve_radius)) \
						or not Terrain.rock_clears(foot, Vector3(carve_radius, 0.0, carve_radius)):
					continue
				(home["trees"] as Array).append({
					"position": foot,
					"height": height,
					"conifer": 1.0 if conifer else 0.0,
					"tint": Terrain.hash01(seed_value, 6),
					# As a share of THIS finish's trees, so the shader's thinning runs over all of them.
					"rank": rank / share,
					"phase": Terrain.hash01(seed_value, 7),
					"lean_about": Terrain.hash01(seed_value, 8) * TAU,
					"lean": Terrain.hash01(seed_value, 9) * lean_max,
				})
		for cell in cells:
			var home: Dictionary = cells[cell]
			home.erase("keepouts")
			if not (home["trees"] as Array).is_empty():
				out.append(home)
	return out


## THE LOWEST GROUND UNDER A TRUNK `radius` metres round `at`: its middle and eight points round its edge, as `Terrain`
## answers the ground there.
static func lowest_under(at: Vector3, radius: float) -> float:
	var low: float = Terrain.ground_height(at)
	for k in range(8):
		var about: float = TAU * float(k) / 8.0
		low = minf(low, Terrain.ground_height(at + Vector3(cos(about), 0.0, sin(about)) * radius))
	return low


## WHAT THE FLOOR UNDER THE WOODS IS SET WITH, on the finish asked for: `floor_parameters` as `grow` worked them out.
func floor_values(fine: bool) -> Dictionary:
	return _floor_fine if fine else _floor_plain


## THE CHANCE A TREE IS KEPT THIS FAR IN FROM THE EDGE OF ITS STAND, 0 at a side and 1 past the band.
##
## Measured to the NEAREST side, in the stand's own frame. The band's width wanders along that side by
## up to `edge_wander` of itself, on a hash smoothed over one band's length, so the line where thinning
## starts is not a straight inner rectangle drawn a band in from the outer one.
##
## THE WANDER IS READ ON THE LATTICE'S BAND, `lattice` being FINE's numbers, on both finishes. It was
## read on each finish's own band, and PLAIN's is 60 m to FINE's 70, so the same place along a side
## read a different stretch of noise on each: 10 of 5,209 PLAIN trees near the edges stood where FINE
## had thinned its wood out. With both reading one wander, PLAIN's chance at any point is its share
## times its own curve, which never exceeds FINE's, so a PLAIN tree is always a FINE tree.
static func edge_keep(stand: Dictionary, local: Vector2, tuning: Dictionary, lattice: Dictionary) -> float:
	var band: float = float(tuning["edge_band"])
	if band <= 0.0:
		return 1.0
	var half: Vector2 = stand["half"]
	var to_x: float = half.x - absf(local.x)
	var to_y: float = half.y - absf(local.y)
	var inward: float = to_x
	var along: float = local.y
	var side: int = 0 if local.x > 0.0 else 1
	if to_y < to_x:
		inward = to_y
		along = local.x
		side = 2 if local.y > 0.0 else 3
	var wander: float = (_smooth_hash(int(stand["index"]) * 4 + side,
		along / maxf(float(lattice["edge_band"]), 0.001)) - 0.5) * 2.0
	var width: float = maxf(band * (1.0 + float(tuning["edge_wander"]) * wander), 0.001)
	return pow(clampf(inward / width, 0.0, 1.0), float(tuning["edge_curve"]))


## HOW MUCH OF THE EDGE'S CHANCE SURVIVES THE PATCHES AND THE CLUMPS HERE: the same number on both finishes, read on the
## lattice's (FINE's) numbers only. In the middle it is the patch noise, `patch_least` to 1; in the band it is also
## scaled by the clump noise, between 1 - `edge_clumps` and 1 + `edge_clumps` at the outer side and fading to 1 at the
## inner edge -- so the last trees are the ones where the clump noise is high, standing together.
##
## ONE FACTOR, AND THE LATTICE'S, so PLAIN stays a subset of FINE. PLAIN keeps rank < 0.45 x clamp(edge_p x t) and FINE
## rank < clamp(edge_f x t), the same t. Where FINE's product is under 1, PLAIN's band is 120 m to FINE's 140 and its
## curve the same, so edge_p is at most (140 / 120)^2 = 1.36 of edge_f, and PLAIN's chance at most 0.45 x 1.36 = 0.61 of
## FINE's; where FINE's is clamped to 1 it keeps every rank. The clump weight fades with the LATTICE's edge chance, not
## this finish's, for the same reason: PLAIN's narrower band would otherwise weigh its clumps differently -- the 10
## PLAIN trees outside FINE's wood that the edge's wander once put there (see `edge_keep`).
static func thinning(stand: Dictionary, local: Vector2, lattice: Dictionary) -> float:
	var seed_value: int = int(stand["index"]) * 31 + 7
	var patch: float = lerpf(float(lattice["patch_least"]), 1.0,
		_value_noise(seed_value, local / maxf(float(lattice["patch_scale"]), 0.001)))
	var inside: float = edge_keep(stand, local, lattice, lattice)
	var clump: float = _value_noise(seed_value + 1, local / maxf(float(lattice["clump_scale"]), 0.001))
	var weight: float = float(lattice["edge_clumps"]) * (1.0 - inside)
	return patch * lerpf(1.0, clump * 2.0, weight)


## Smooth noise over a plane, 0 to 1: `Terrain.hash01` at the corners of a unit cell, eased between -- the same on every
## machine. The hash masks after its multiply, so a negative cell hashes as well as a positive one.
static func _value_noise(seed_value: int, at: Vector2) -> float:
	var cell := Vector2(floor(at.x), floor(at.y))
	var part: Vector2 = at - cell
	part = part * part * (Vector2(3.0, 3.0) - 2.0 * part)
	var i: int = int(cell.x)
	var j: int = int(cell.y)
	var a: float = Terrain.hash01(seed_value * 7919 + i, j * 104729 + 3)
	var b: float = Terrain.hash01(seed_value * 7919 + i + 1, j * 104729 + 3)
	var c: float = Terrain.hash01(seed_value * 7919 + i, (j + 1) * 104729 + 3)
	var d: float = Terrain.hash01(seed_value * 7919 + i + 1, (j + 1) * 104729 + 3)
	return lerpf(lerpf(a, b, part.x), lerpf(c, d, part.x), part.y)


## A hash of `t`'s whole part, eased into the next one's: noise along a line, the same on every machine.
static func _smooth_hash(seed_value: int, t: float) -> float:
	var whole: float = floor(t)
	var part: float = t - whole
	var a: float = Terrain.hash01(seed_value, int(whole) + 50000)
	var b: float = Terrain.hash01(seed_value, int(whole) + 50001)
	return lerpf(a, b, part * part * (3.0 - 2.0 * part))


## One integer per lattice point of one stand, spread by the hash itself so neighbouring points do
## not get neighbouring seeds.
static func _seed(stand: int, i: int, j: int) -> int:
	return int(Terrain.hash01(stand * 7919 + i, j * 104729 + 17) * 2147483646.0)


## The keep-outs whose footprint comes within `reach` metres of `at`, on the ground. A yawed box is
## given the diagonal of its half-sizes, which is as far as any corner of it can reach.
static func _keepouts_near(keepouts: Array[Dictionary], at: Vector3, reach: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for box in keepouts:
		var half: Vector3 = box["half_extents"]
		var to: Vector3 = (box["position"] as Vector3) - at
		var spread := Vector2(half.x, half.z)
		if float(box.get("yaw", 0.0)) != 0.0:
			spread = Vector2.ONE * Vector2(half.x, half.z).length()
		if absf(to.x) < spread.x + reach and absf(to.z) < spread.y + reach:
			out.append(box)
	return out


## ---- drawing -----------------------------------------------------------------------------

## ONE CHUNK OF WOOD: a MultiMesh of its trees, centred on the chunk so every instance is a small
## offset, with no shadow, and culled past the far fade plus the chunk's own half-diagonal -- by
## which distance every tree in it has already shrunk to nothing in the shader.
static func chunk_node(chunk: Dictionary, mesh: Mesh, paint: ShaderMaterial,
		tuning: Dictionary) -> MultiMeshInstance3D:
	var trees: Array = chunk["trees"]
	var centre: Vector3 = chunk["centre"]
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	# BEFORE THE COUNT: a MultiMesh will not start carrying custom data once it has instances.
	many.use_custom_data = true
	many.mesh = mesh
	many.instance_count = trees.size()
	for k in range(trees.size()):
		var tree: Dictionary = trees[k]
		var about: float = float(tree["lean_about"])
		var basis := Basis.IDENTITY
		if float(tree["lean"]) > 0.0:
			basis = Basis(Vector3(cos(about), 0.0, sin(about)), float(tree["lean"]))
		many.set_instance_transform(k, Transform3D(basis.scaled(Vector3.ONE * float(tree["height"])),
			(tree["position"] as Vector3) - centre))
		many.set_instance_custom_data(k, Color(float(tree["rank"]), float(tree["conifer"]),
			float(tree["tint"]), float(tree["phase"])))
	var node := MultiMeshInstance3D.new()
	var cell: Vector2i = chunk["cell"]
	node.name = "%s_%d_%d" % [chunk["stand"], cell.x, cell.y]
	node.multimesh = many
	node.position = centre
	node.material_override = paint
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = float(tuning["fade_to"]) + float(tuning["chunk"]) * 0.7072
	# The bounds are the trees standing still; the wind moves a crown by at most `sway`, and a finish
	# with no wind in its table has none.
	node.extra_cull_margin = float(tuning.get("sway", 0.0))
	return node


## The material every chunk of one finish shares, with every tuning number the shader takes.
static func paint_for(tuning: Dictionary, fine: bool) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = FINE_SHADER if fine else PLAIN_SHADER
	var values: Dictionary = tree_parameters(tuning, fine)
	for key in values:
		paint.set_shader_parameter(key, values[key])
	return paint


static func tree_parameters(tuning: Dictionary, fine: bool) -> Dictionary:
	var out: Dictionary = {}
	for key in TREE_UNIFORMS:
		out[key] = tuning[key]
	if fine:
		for key in WIND_UNIFORMS:
			out[key] = tuning[key]
		# A heading and not the wind, which is zero: see `Terrain.SWELL_HEADING`.
		out["wind"] = Terrain.SWELL_HEADING
	return out


## How many stands the ground cannot paint a floor under: those past the tuning's `most_stands`. A
## count limit, so they are DROPPED from the floor -- there is nothing to clamp a ninth stand to -- and
## said so; their trees still grow.
static func stands_past_the_floor(stands: Array[Dictionary], tuning: Dictionary) -> int:
	return maxi(stands.size() - int(tuning["most_stands"]), 0)


## THE FLOOR'S UNIFORMS for the grass shaders: the stands as two arrays of `most_stands`, and the
## finish's floor numbers.
static func floor_parameters(stands: Array[Dictionary], tuning: Dictionary, fine: bool) -> Dictionary:
	var most: int = int(tuning["most_stands"])
	var dropped: int = stands_past_the_floor(stands, tuning)
	if dropped > 0:
		push_warning("[forest] %d stands and the ground can paint %d; %d have trees and no floor"
			% [stands.size(), most, dropped])
	var count: int = mini(stands.size(), most)
	var frames: Array = []
	var halves: Array = []
	for i in range(most):
		if i < count:
			var centre: Vector3 = stands[i]["centre"]
			var across: Vector3 = stands[i]["across"]
			var half: Vector2 = stands[i]["half"]
			frames.append(Vector4(centre.x, centre.z, across.x, across.z))
			halves.append(Vector4(half.x, half.y, 0.0, 0.0))
		else:
			frames.append(Vector4.ZERO)
			halves.append(Vector4.ZERO)
	var out: Dictionary = {"forest_count": count, "forest_frame": frames, "forest_half": halves}
	for key in FLOOR_UNIFORMS:
		out[key] = tuning[key]
	if fine:
		for key in FINE_FLOOR_UNIFORMS:
			out[key] = tuning[key]
	return out


## ---- the tree ----------------------------------------------------------------------------

## THE TREE MESH FOR ONE FINISH, unit-sized: a trunk from y = -1 to 0 and a crown from 0 to 1,
## rings of radius about 1. The shader gives it its proportions. See the note at the top of
## `forest.gdshaderinc` for what each array carries.
##
## A crown is `crown_tiers` cones on a conifer and as many lumps on a broadleaf, each a ring of
## `crown_sides` with a point above and a point below: one topology for both kinds, so the same
## triangles are either tree. Lower tiers are baked darker, which is the light a crown keeps from
## its own inside; undersides darker still.
static func tree_mesh(tuning: Dictionary) -> ArrayMesh:
	var tiers: int = maxi(int(tuning["crown_tiers"]), 1)
	var sides: int = maxi(int(tuning["crown_sides"]), 3)
	var trunk_sides: int = maxi(int(tuning["trunk_sides"]), 3)
	# PLAIN ARRAYS WHILE BUILDING, packed at the end. A packed array taken out of a dictionary and
	# appended to is a copy being appended to: the first version of this built both trees with no
	# vertices at all, and the only sign was an engine error saying `array_len == 0`.
	var build: Dictionary = {"cone": [], "cone_normal": [], "uv": [], "custom0": [], "custom1": []}
	# THE TRUNK: the same on both kinds.
	for s in range(trunk_sides):
		var a: float = TAU * float(s) / float(trunk_sides)
		var b: float = TAU * float(s + 1) / float(trunk_sides)
		var low_a := Vector3(cos(a), -1.0, sin(a))
		var low_b := Vector3(cos(b), -1.0, sin(b))
		var high_a := Vector3(cos(a), 0.0, sin(a))
		var high_b := Vector3(cos(b), 0.0, sin(b))
		var outward := Vector3(cos((a + b) * 0.5), 0.0, sin((a + b) * 0.5))
		for tri in [[low_a, high_a, high_b], [low_a, high_b, low_b]]:
			_triangle(build, tri, tri, [1.0, 1.0, 1.0], [1.0, 1.0, 1.0], outward, true)
	# THE CROWN, tier by tier: a point below, two rings, and a point above.
	#
	# TWO RINGS, NOT ONE. The first crown was one ring between two points, and from a low pass the
	# broadleaf read as a diamond standing on a stick (forest_low, 2026-09-13). Two rings on the
	# conifer's own cone line leave it a cone; on the broadleaf they round the lump.
	for k in range(tiers):
		var cone: Dictionary = _cone_tier(k, tiers)
		var lump: Dictionary = _lump_tier(k, tiers)
		var twist: float = PI * float(k) / float(sides)
		for s in range(sides):
			var a: float = TAU * float(s) / float(sides) + twist
			var b: float = TAU * float(s + 1) / float(sides) + twist
			var outward := Vector3(cos((a + b) * 0.5), 0.0, sin((a + b) * 0.5))
			var c_low_a: Vector3 = _ring_point(cone, 0, a)
			var c_low_b: Vector3 = _ring_point(cone, 0, b)
			var c_high_a: Vector3 = _ring_point(cone, 1, a)
			var c_high_b: Vector3 = _ring_point(cone, 1, b)
			var l_low_a: Vector3 = _ring_point(lump, 0, a)
			var l_low_b: Vector3 = _ring_point(lump, 0, b)
			var l_high_a: Vector3 = _ring_point(lump, 1, a)
			var l_high_b: Vector3 = _ring_point(lump, 1, b)
			var c_lit: Array = [cone["rings"][0][2], cone["rings"][1][2]]
			var l_lit: Array = [lump["rings"][0][2], lump["rings"][1][2]]
			# The underside, from the lower ring down to the point below.
			_triangle(build, [cone["bottom"], c_low_b, c_low_a], [lump["bottom"], l_low_b, l_low_a],
				[cone["under"], c_lit[0], c_lit[0]], [lump["under"], l_lit[0], l_lit[0]],
				Vector3.DOWN, false)
			# The band between the rings.
			_triangle(build, [c_low_a, c_high_a, c_high_b], [l_low_a, l_high_a, l_high_b],
				[c_lit[0], c_lit[1], c_lit[1]], [l_lit[0], l_lit[1], l_lit[1]],
				outward + Vector3.UP * 0.3, false)
			_triangle(build, [c_low_a, c_high_b, c_low_b], [l_low_a, l_high_b, l_low_b],
				[c_lit[0], c_lit[1], c_lit[0]], [l_lit[0], l_lit[1], l_lit[0]],
				outward + Vector3.UP * 0.3, false)
			# The top, from the upper ring to the point.
			_triangle(build, [cone["apex"], c_high_a, c_high_b], [lump["apex"], l_high_a, l_high_b],
				[1.0, c_lit[1], c_lit[1]], [1.0, l_lit[1], l_lit[1]],
				outward + Vector3.UP * 0.6, false)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(build["cone"])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(build["cone_normal"])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(build["uv"])
	arrays[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array(build["custom0"])
	arrays[Mesh.ARRAY_CUSTOM1] = PackedFloat32Array(build["custom1"])
	var formats: int = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, formats)
	return mesh


## A conifer's k-th tier of `tiers`: stacked cones, each narrower and higher, the top one reaching 1.
## Its two rings are on the cone's own line -- the base, and 40 per cent of the way up at 60 per cent
## of the width -- so the extra ring costs triangles and changes no silhouette.
static func _cone_tier(k: int, tiers: int) -> Dictionary:
	var base: float = 0.8 * float(k) / float(tiers)
	var apex: float = base + 1.0 - 0.8 * float(tiers - 1) / float(tiers)
	var radius: float = 1.0 - 0.7 * float(k) / float(tiers)
	var lit: float = 0.5 + 0.3 * float(k) / float(tiers)
	return {"centre": Vector2.ZERO,
		"rings": [[base, radius, lit], [base + 0.4 * (apex - base), 0.6 * radius, (lit + 1.0) * 0.5]],
		"apex": Vector3(0.0, apex, 0.0), "bottom": Vector3(0.0, base, 0.0), "under": 0.4}


## A broadleaf's k-th lump of `tiers`: one round crown when there is one tier; otherwise lumps round
## the stem low down and the last one on top. Each is widest a third of the way up and still most of
## that width two thirds up, which is what makes it a lump and not a diamond.
static func _lump_tier(k: int, tiers: int) -> Dictionary:
	var centre := Vector2.ZERO
	var bottom: float = 0.0
	var apex: float = 1.0
	var radius: float = 1.0
	var lit: float = 0.65
	if tiers > 1 and k == tiers - 1:
		bottom = 0.3
		radius = 0.8
		lit = 0.8
	elif tiers > 1:
		var about: float = TAU * float(k) / float(tiers - 1) + 0.6
		centre = Vector2(cos(about), sin(about)) * 0.42
		apex = 0.74
		radius = 0.62
		lit = 0.55
	var span: float = apex - bottom
	return {"centre": centre,
		"rings": [[bottom + 0.32 * span, radius, lit], [bottom + 0.7 * span, 0.82 * radius, (lit + 1.0) * 0.5]],
		"apex": Vector3(centre.x, apex, centre.y), "bottom": Vector3(centre.x, bottom, centre.y),
		"under": 0.45}


## A point on ring `ring` of a tier, `angle` round it.
static func _ring_point(tier: Dictionary, ring: int, angle: float) -> Vector3:
	var centre: Vector2 = tier["centre"]
	var row: Array = tier["rings"][ring]
	var radius: float = float(row[1])
	return Vector3(centre.x + cos(angle) * radius, float(row[0]), centre.y + sin(angle) * radius)


## ONE TRIANGLE, as both kinds of tree, with a flat normal each. The winding is chosen from the
## conifer's face so its front faces `outward` -- Godot's front faces are wound clockwise -- and the
## broadleaf shares it, since its lumps go round the same way.
static func _triangle(build: Dictionary, cone: Array, lump: Array, cone_lit: Array, lump_lit: Array,
		outward: Vector3, trunk: bool) -> void:
	var order: Array[int] = [0, 1, 2]
	if _face(cone[0], cone[1], cone[2]).dot(outward) < 0.0:
		order = [0, 2, 1]
	var cone_facing: Vector3 = _face(cone[order[0]], cone[order[1]], cone[order[2]])
	var lump_facing: Vector3 = _face(lump[order[0]], lump[order[1]], lump[order[2]])
	for n in order:
		(build["cone"] as Array).append(cone[n])
		(build["cone_normal"] as Array).append(cone_facing)
		(build["uv"] as Array).append(Vector2(float(cone_lit[n]), float(lump_lit[n])))
		var at: Vector3 = lump[n]
		(build["custom0"] as Array).append_array([at.x, at.y, at.z, 1.0 if trunk else 0.0])
		(build["custom1"] as Array).append_array([lump_facing.x, lump_facing.y, lump_facing.z, 0.0])


## The facing of a face wound a, b, c clockwise as seen from its front.
static func _face(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var facing: Vector3 = (c - a).cross(b - a)
	return facing.normalized() if facing.length() > 0.000001 else Vector3.UP
