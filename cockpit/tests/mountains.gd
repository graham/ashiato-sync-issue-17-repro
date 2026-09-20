extends Node
## Headless: are the island's mountains the mountains recorded, held inside their envelope, clear of every keep-out -- and
## is what Box3D collides with the triangles that are drawn?
##
##   Godot --headless --path cockpit res://tests/mountains.tscn
##
## THE MOUNTAINS ARE NOT REPLICATED (agents.md, RULES 8): every peer builds them from `MountainRanges` and `Terrain`, so a
## peer whose ridge is a tick elsewhere predicts itself into the server's. And they are drawn from the SAME triangles the
## simulation collides with (ashiato-gd/src/cockpit/range_core.hpp), so a mountain drawn where the simulation has none --
## the one fault that looks exactly like a networking fault -- would take a change to one side that this suite catches.
##
## - THE RECORDED ISLAND. The mountains' own hash over every tile's vertices and indices, and Box3D's over every mesh it
##   built from them, against numbers recorded on the stock and the double editor, which must agree.
## - THE SAME AGAIN, AND ON A WORKER: a second build, and one on a thread, give the same hash.
## - THE COLLISION IS THE PICTURE: rays cast down through a real `CockpitWorld` at 2,000 hash-chosen points on the rock
##   land on the triangle the tile arrays -- the ones `MountainView` draws -- put there, within a centimetre; and the
##   library's own `surface_at`, which the level asks for heights, agrees with both.
## - THE ENVELOPE HOLDS: a range whose crest is typed above its peak stands at its peak on the ridge, one typed below its
##   saddle at its saddle, and no vertex of any range rises above its own range's peak.
## - NO ROCK IN A KEEP-OUT: the drawn surface over every keep-out stands no higher than its floor.
## - THE PYRAMID IS NEVER LOW: the highest rock over a square, as the autopilots' leg tests ask it, is never under the
##   surface sampled inside it.
## - WHAT IT COSTS: triangles, tiles, bytes, build time and the cost of a ray, printed beside the boxes they replace.
## - THE LEVEL DRAWS WHAT IT COLLIDES WITH: the island level itself is stood up, and rays cast through its own simulation
##   land on the triangles read back out of the meshes its `MountainView` drew -- the real picture, not the arrays it was
##   handed -- and every tile the ranges have is drawn, with no rock box left in the world beside them.
##
## Read RESULT=, not the exit code.

## THE ISLAND'S RECORDED HASHES: `MountainRange.hash()` over the tiles, and `CockpitWorld.mountains_report()["hash"]` over
## Box3D's meshes. A change to `MountainRanges`, to `Terrain`'s keep-outs or to range_core.cpp moves them, and moves them
## here in the same commit.
##
## RE-RECORDED 2026-09-19 on both editors, BECAUSE THE ISLAND'S SHAPE CHANGED ON PURPOSE. Until then all six ring arcs
## were one formula with a different salt and all five inland things another, and every range on the island fell away
## from its ridge through the same seven fractions of its own crest, agreeing across the eleven to within four per cent
## (`tests/ridge_variety.gd`). Each arc and each inland range now carries its own envelope, crest, foot and wander, and
## three branch ridges leave their parents at a shared control point. The island went from 39,582 triangles in 40 tiles
## to 36,324 in 37 -- FEWER, because the character is got mostly from the crest and the envelope, and no arc's foot
## reaches further than the old ring's widest did. They were 6469667651213179958 and 9218849931042331911, recorded
## 2026-09-18.
##
## RE-RECORDED AGAIN 2026-09-19 (lane/throughrock), BECAUSE THE ISLAND'S UNPROTECTED FINALS NOW KEEP ROCK OUT
## (`Terrain._island_final_keepouts`): `island_strip`'s in-use final is cut to a 34:1 valley through the first inland range and
## the second lone mountain, and `south_shore`'s over the sea. The ranges are untouched; 37 meshes still, 36,302 triangles
## where there were 36,324. They were -5611238836685052277 and -2554325947133074383.
##
## RE-RECORDED A THIRD TIME 2026-09-20 (lane/railgap), BECAUSE THE MOUNTAINS NOW COME CLOSE TO THE RAILWAY: its keep-out is a
## 24 m half-width box (`Terrain.RAIL_CLEAR`, was 90 m) grown by one spacing (`Terrain.RAIL_MARGIN`, was the 108 m every keep-out
## is grown by). 38,578 triangles where there were 36,302; the nearest drawn rock to the track went from 204 m to 52 m. Recorded
## on the STOCK and the DOUBLE editor, which agree. They were -5038692014120995923 and 1480130860845280016.
##
## RE-RECORDED A FOURTH TIME 2026-09-19 (lane/railnearer), BECAUSE THE RAIL KEEP-OUT IS SURVEYED EVERY 20 M (`Terrain.RAIL_KEEP_STEP`, was
## the 40 m RAIL_STEP): 1,131 boxes of 12 m half-width (`RAIL_CLEAR`, was 24) grown by 54 m (`RAIL_MARGIN`, was 48). 38,632 triangles where
## there were 38,578; the nearest drawn rock to the track went from 52 m to 44 m. Recorded on the DOUBLE and the STOCK editor, which agree.
## They were -3637309692606226398 and -7918933811793989947.
##
## RE-RECORDED A FIFTH TIME 2026-09-20 (lane/railnearer), BECAUSE ROCK NOW CLIMBS OUT OF THE RAIL KEEP-OUT AT THREE TO ONE, not 6/5
## (`Terrain.RAIL_RISE_FIFTHS` = 15, `KeepOut.rise_fifths` in range_core.cpp): the same 38,632 triangles, the ground standing 100 m over the
## track 116 m out where it stood 164 m. Recorded on the DOUBLE and the STOCK editor, which agree. They were -7033104859958061381 and
## -5752378652266360260.
const RECORDED_HASH: int = -6757110950092194504
const RECORDED_BOX3D_HASH: int = 6584400273856577611
## How far a ray's landing may be from the drawn triangle, metres.
const LANDS_WITHIN: float = 0.01
const RAY_POINTS: int = 2000

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[mountains] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var exists: bool = ClassDB.class_exists(&"MountainRange") and ClassDB.class_has_method(&"CockpitWorld", &"set_mountains")
	_check("the_extension_has_mountains", exists, "engine %s, double=%s" % [Engine.get_version_info()["string"],
		OS.has_feature("double")])
	if not exists:
		_finish()
		return
	var values: Dictionary = Terrain.mountain_values()
	var island: Object = ClassDB.instantiate(&"MountainRange")
	var problems: PackedStringArray = island.call("configure", values)
	var report: Dictionary = island.call("report")
	_check("the_island_configures_with_no_complaint", problems.is_empty() and island.call("is_configured"),
		"%s; %s" % [problems, report])
	await _the_recorded_island(island, values)
	_the_collision_is_the_picture(island)
	_the_envelope_holds()
	_no_rock_in_a_keep_out(island, values["keepouts"], values["keepout_margins"])
	_a_margin_list_of_the_wrong_length_is_refused(values)
	_how_near_the_rock_comes_to_the_rail(island)
	_the_rail_corridor_has_no_gap()
	_the_pyramid_is_never_low(island)
	await _the_level_draws_what_it_collides_with()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## ---- the recorded island -------------------------------------------------------------------------------------------

func _the_recorded_island(island: Object, values: Dictionary) -> void:
	var hash: int = int(island.call("hash"))
	_check("the_mountains_are_the_recorded_mountains", hash == RECORDED_HASH,
		"hash %d, recorded %d" % [hash, RECORDED_HASH])
	var again: Object = ClassDB.instantiate(&"MountainRange")
	again.call("configure", values)
	var on_a_worker: Array = [0]
	var thread := Thread.new()
	thread.start(func() -> void:
		var there: Object = ClassDB.instantiate(&"MountainRange")
		there.call("configure", values)
		on_a_worker[0] = int(there.call("hash")))
	thread.wait_to_finish()
	_check("a_second_build_and_a_worker_build_the_same", int(again.call("hash")) == hash and int(on_a_worker[0]) == hash,
		"%d, %d and %d" % [hash, int(again.call("hash")), int(on_a_worker[0])])
	var world: Object = _world(island)
	var built: Dictionary = world.mountains_report()
	_check("box3d_built_the_recorded_meshes", int(built.get("hash", 0)) == RECORDED_BOX3D_HASH \
			and int(built.get("degenerate", -1)) == 0,
		"%s, recorded %d" % [built, RECORDED_BOX3D_HASH])


## ---- the collision is the picture ---------------------------------------------------------------------------------

## THE TRIANGLES AS THE PICTURE HAS THEM, filed by the spacing's square each one's bounds touch, in world metres: the arrays
## `MountainRange.tile()` hands `MountainView`, not the library's own query -- that is the other side of the comparison.
func _drawn_triangles(island: Object) -> Dictionary:
	var spacing: float = float(MountainRanges.SPACING)
	var squares: Dictionary = {}
	for t in range(int(island.call("tile_count"))):
		var tile: Dictionary = island.call("tile", t)
		var origin := Vector3(float((tile["origin"] as Vector2i).x), 0.0, float((tile["origin"] as Vector2i).y))
		var vertices: PackedVector3Array = tile["vertices"]
		var indices: PackedInt32Array = tile["indices"]
		for k in range(0, indices.size(), 3):
			var tri: Array[Vector3] = [origin + vertices[indices[k]], origin + vertices[indices[k + 1]],
				origin + vertices[indices[k + 2]]]
			var lo := Vector2i(floori(minf(minf(tri[0].x, tri[1].x), tri[2].x) / spacing),
				floori(minf(minf(tri[0].z, tri[1].z), tri[2].z) / spacing))
			var hi := Vector2i(floori(maxf(maxf(tri[0].x, tri[1].x), tri[2].x) / spacing),
				floori(maxf(maxf(tri[0].z, tri[1].z), tri[2].z) / spacing))
			for j in range(lo.y, hi.y + 1):
				for i in range(lo.x, hi.x + 1):
					var key := Vector2i(i, j)
					if not squares.has(key):
						squares[key] = []
					(squares[key] as Array).append(tri)
	return squares


## The drawn height at (x, z) from the filed triangles, or NAN where no triangle covers the point.
static func _drawn_height(squares: Dictionary, x: float, z: float) -> float:
	var key := Vector2i(floori(x / float(MountainRanges.SPACING)), floori(z / float(MountainRanges.SPACING)))
	for tri in squares.get(key, []):
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var area: float = (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if is_zero_approx(area):
			continue
		var wb: float = ((x - a.x) * (c.z - a.z) - (c.x - a.x) * (z - a.z)) / area
		var wc: float = ((b.x - a.x) * (z - a.z) - (x - a.x) * (b.z - a.z)) / area
		var wa: float = 1.0 - wb - wc
		if wa >= -1e-9 and wb >= -1e-9 and wc >= -1e-9:
			return wa * a.y + wb * b.y + wc * c.y
	return NAN


func _the_collision_is_the_picture(island: Object) -> void:
	var squares: Dictionary = _drawn_triangles(island)
	var keys: Array = squares.keys()
	var world: Object = _world(island)
	var worst_ray: float = 0.0
	var worst_query: float = 0.0
	var tested: int = 0
	var missed: int = 0
	var k: int = 0
	var began: int = Time.get_ticks_usec()
	var ray_usec: int = 0
	while tested < RAY_POINTS and k < RAY_POINTS * 20:
		var square: Vector2i = keys[int(Terrain.hash01(k, 5101) * float(keys.size())) % keys.size()]
		var x: float = (float(square.x) + Terrain.hash01(k, 5102)) * float(MountainRanges.SPACING)
		var z: float = (float(square.y) + Terrain.hash01(k, 5103)) * float(MountainRanges.SPACING)
		k += 1
		var drawn: float = _drawn_height(squares, x, z)
		if is_nan(drawn) or drawn < 1.0:
			continue
		tested += 1
		var cast: int = Time.get_ticks_usec()
		var below: float = world.first_solid_below(Vector3(x, drawn + 50.0, z), 100.0)
		ray_usec += Time.get_ticks_usec() - cast
		if below < 0.0:
			missed += 1
			continue
		worst_ray = maxf(worst_ray, absf(drawn + 50.0 - below - drawn))
		worst_query = maxf(worst_query, absf(float(island.call("surface_at", x, z)) - drawn))
		worst_query = maxf(worst_query, absf(float(world.ground_height_at(x, z)) - drawn))
	_check("the_collision_is_the_picture", tested >= RAY_POINTS and missed == 0 and worst_ray <= LANDS_WITHIN,
		"%d rays onto drawn rock, %d found nothing, worst landing %.4f m from the drawn triangle; %.2f us a ray" % [
			tested, missed, worst_ray, float(ray_usec) / maxf(float(tested), 1.0)])
	_check("the_heights_asked_are_the_heights_drawn", tested >= RAY_POINTS and worst_query <= LANDS_WITHIN,
		"surface_at and the world's ground_height_at, worst %.4f m from the drawn triangle over %d points" % [
			worst_query, tested])
	print("[mountains] cost: %s; %s; checked in %.0f ms" % [island.call("report"), world.mountains_report(),
		float(Time.get_ticks_usec() - began) / 1000.0])


## ---- the envelope -------------------------------------------------------------------------------------------------

## TWO RANGES OF THE SUITE'S OWN, so the clamp is what is tested and not the game's numbers: one typed 1,400 m against a
## 600 m peak -- twice the peak, because the noise along a ridge carries a crest between half and 1.4 times its typed
## height, and a first draft typed 700 m and stood at 467 m without the clamp ever acting -- and one typed 90 m against
## a 200 m saddle. On a control point the ridge passes exactly and the crest is the
## height; so the first must stand at 600 m there and the second at 200 m.
func _the_envelope_holds() -> void:
	var over := {"salt": 7, "peak": 600, "saddle": 150, "points": PackedInt32Array([0, 0, 1400, 800, 2000, 0, 1400, 800])}
	var under := {"salt": 8, "peak": 600, "saddle": 200, "points": PackedInt32Array([0, 6000, 90, 600])}
	var range: Object = ClassDB.instantiate(&"MountainRange")
	range.call("configure", {"spacing": MountainRanges.SPACING, "tile_quads": MountainRanges.TILE_QUADS,
		"ranges": [over, under], "keepouts": PackedInt32Array()})
	var capped: float = float(range.call("height_ticks_at", 0, 0)) / Terrain.GROUND_TICKS_PER_METRE
	var floored: float = float(range.call("height_ticks_at", 0, 6000)) / Terrain.GROUND_TICKS_PER_METRE
	# AT ITS PEAK, OR BROKEN BELOW IT BY A CRAG: the tallest summits are cragged by up to a sixth of their height
	# (range_core.cpp, CRAGS), never over the peak.
	_check("a_crest_over_its_peak_stands_at_its_peak", capped <= 600.0 + 0.001 and capped >= 500.0, "%.2f m" % capped)
	_check("a_crest_under_its_saddle_stands_at_its_saddle", is_equal_approx(floored, 200.0), "%.2f m" % floored)
	# AND ON THE ISLAND: each range alone, no vertex above its own peak.
	var over_peak: Array[String] = []
	var tallest: Array[float] = []
	for one in MountainRanges.ranges():
		var alone: Object = ClassDB.instantiate(&"MountainRange")
		alone.call("configure", {"spacing": MountainRanges.SPACING, "tile_quads": MountainRanges.TILE_QUADS,
			"ranges": [one], "keepouts": PackedInt32Array()})
		var top: float = 0.0
		for t in range(int(alone.call("tile_count"))):
			for v in (alone.call("tile", t)["vertices"] as PackedVector3Array):
				top = maxf(top, v.y)
		tallest.append(snappedf(top, 1.0))
		if top > float(one["peak"]) + 0.001:
			over_peak.append("salt %d: %.1f over %d" % [int(one["salt"]), top, int(one["peak"])])
	_check("no_range_rises_over_its_peak", over_peak.is_empty(), "tallest of each %s %s" % [tallest, over_peak])


## ---- keep-outs and the pyramid ------------------------------------------------------------------------------------

## EVERY KEEP-OUT BUT THE RAILWAY'S, which was let draw rock a little inside its box on purpose (`Terrain.RAIL_MARGIN`) and is
## held by the two rail checks below instead, against the drawn triangles over the track itself.
func _no_rock_in_a_keep_out(island: Object, keepouts: PackedInt32Array, margins: PackedInt32Array) -> void:
	var inside: Array[String] = []
	var sampled: int = 0
	var lenient: int = 0
	for k in range(0, keepouts.size(), 5):
		if k / 5 < margins.size() and margins[k / 5] >= 0:
			lenient += 1
			continue
		var floor_m: float = float(keepouts[k + 4]) / Terrain.GROUND_TICKS_PER_METRE
		var step: float = 16.0
		var x: float = float(keepouts[k])
		while x <= float(keepouts[k + 2]):
			var z: float = float(keepouts[k + 1])
			while z <= float(keepouts[k + 3]):
				var h: float = float(island.call("surface_at", x, z))
				sampled += 1
				if h > floor_m + 0.01 and inside.size() < 5:
					inside.append("%.1f m at (%.0f, %.0f) over a floor of %.1f" % [h, x, z, floor_m])
				z += step
			x += step
	_check("no_rock_stands_in_a_keep_out", inside.is_empty() and sampled > 1000,
		"%d keep-outs, %d of them the railway's and left to the rail checks, %d samples %s" % [keepouts.size() / 5, lenient,
			sampled, inside])


func _the_pyramid_is_never_low(island: Object) -> void:
	var low: Array[String] = []
	var checked: int = 0
	for k in range(400):
		var at := Vector2((Terrain.hash01(k, 5201) - 0.5) * 12000.0, (Terrain.hash01(k, 5202) - 0.5) * 12000.0)
		var reach: float = 20.0 + Terrain.hash01(k, 5203) * 400.0
		var top: float = float(island.call("highest_over", at.x - reach, at.y - reach, at.x + reach, at.y + reach))
		var sampled: float = 0.0
		for j in range(9):
			for i in range(9):
				sampled = maxf(sampled, float(island.call("surface_at", at.x - reach + reach * float(i) / 4.0,
					at.y - reach + reach * float(j) / 4.0)))
		checked += 1 if sampled > 0.0 else 0
		if top < sampled - 0.001:
			low.append("%.1f under %.1f at %v" % [top, sampled, at])
	_check("the_pyramid_is_never_under_the_rock", low.is_empty() and checked > 40,
		"%d squares with rock in them %s" % [checked, low.slice(0, 3)])


## ---- the level ----------------------------------------------------------------------------------------------------

## THE ISLAND LEVEL, STOOD UP AS A PLAYER GETS IT, and its own picture read back: each tile's MeshInstance3D's surface
## arrays, in the world by the node's own transform, filed as `_drawn_triangles` files the library's. Then rays through
## the level's own simulation at hash-chosen points on that picture.
func _the_level_draws_what_it_collides_with() -> void:
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(180):
		await get_tree().physics_frame
	var drawn: MountainView = level.mountains
	var expected: int = int(Terrain.mountains().call("tile_count"))
	var rock_boxes: int = 0
	for box in Terrain.boxes():
		rock_boxes += 1 if int(box.get("group", -1)) == Terrain.Group.ROCK else 0
	_check("the_level_draws_every_tile_and_no_rock_box", drawn != null and drawn.drawn_tiles().size() == expected \
			and rock_boxes == 0,
		"%d of %d tiles drawn, %d rock boxes" % [drawn.drawn_tiles().size() if drawn != null else -1, expected, rock_boxes])
	if drawn == null or Sim.client == null:
		level.queue_free()
		return
	var squares: Dictionary = {}
	var spacing: float = float(MountainRanges.SPACING)
	for node in drawn.drawn_tiles():
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var place: Transform3D = node.global_transform
		for k in range(0, indices.size(), 3):
			var tri: Array[Vector3] = [place * vertices[indices[k]], place * vertices[indices[k + 1]],
				place * vertices[indices[k + 2]]]
			var key := Vector2i(floori(tri[0].x / spacing), floori(tri[0].z / spacing))
			for j in range(key.y - 2, key.y + 3):
				for i in range(key.x - 2, key.x + 3):
					var near := Vector2i(i, j)
					if not squares.has(near):
						squares[near] = []
					(squares[near] as Array).append(tri)
	var keys: Array = squares.keys()
	var worst: float = 0.0
	var tested: int = 0
	var missed: int = 0
	var k: int = 0
	while tested < 500 and k < 10000:
		var square: Vector2i = keys[int(Terrain.hash01(k, 5301) * float(keys.size())) % keys.size()]
		var x: float = (float(square.x) + Terrain.hash01(k, 5302)) * spacing
		var z: float = (float(square.y) + Terrain.hash01(k, 5303)) * spacing
		k += 1
		var height: float = _drawn_height(squares, x, z)
		if is_nan(height) or height < 1.0:
			continue
		tested += 1
		var below: float = Sim.client.first_solid_below(Vector3(x, height + 50.0, z), 100.0)
		if below < 0.0:
			missed += 1
			continue
		worst = maxf(worst, absf(height + 50.0 - below - height))
	_check("the_level_collides_with_the_picture_it_draws", tested >= 500 and missed == 0 and worst <= LANDS_WITHIN,
		"%d rays at the drawn meshes, %d found nothing, worst %.4f m off; the simulation's %s" % [tested, missed, worst,
			Sim.client.mountains_report()])
	level.queue_free()
	await get_tree().process_frame
	Sim.stop()


## ---- helpers ------------------------------------------------------------------------------------------------------

func _world(island: Object) -> Object:
	var world: Object = ClassDB.instantiate(&"CockpitWorld")
	world.set_tick_rate(120)
	world.start(1)
	world.set_mountains(island)
	return world


## A MARGIN LIST THAT DOES NOT MATCH THE KEEP-OUTS IS A BUG AND IS SAID SO, not made good by defaulting the tail: a margin on the
## wrong keep-out is a runway approach quietly given the railway's. And the island's own two lists come out the same length.
func _a_margin_list_of_the_wrong_length_is_refused(values: Dictionary) -> void:
	var lists: Dictionary = Terrain.mountain_keepout_lists()
	var short: Dictionary = values.duplicate()
	short["keepout_margins"] = (lists["margins"] as PackedInt32Array).slice(1)
	var rock: Object = ClassDB.instantiate(&"MountainRange")
	var problems: PackedStringArray = rock.call("configure", short)
	var steep: Dictionary = values.duplicate()
	steep["keepout_rises"] = (lists["rises"] as PackedInt32Array).slice(1)
	var steep_rock: Object = ClassDB.instantiate(&"MountainRange")
	var steep_problems: PackedStringArray = steep_rock.call("configure", steep)
	_check("a_rise_list_of_the_wrong_length_is_refused", steep_problems.size() == 1 and not steep_rock.call("is_configured")
			and (lists["rises"] as PackedInt32Array).size() == (lists["margins"] as PackedInt32Array).size(),
		"%s" % [steep_problems])
	_check("a_margin_list_of_the_wrong_length_is_refused", problems.size() == 1 and not rock.call("is_configured")
			and (lists["keepouts"] as PackedInt32Array).size() == (lists["margins"] as PackedInt32Array).size() * 5,
		"%s" % [problems])


## ---- the rail ------------------------------------------------------------------------------------------------------

## HOW NEAR THE ROCK COMES to the railway's centreline, and THAT THE DRAWN ROCK STAYS OFF THE PERMANENT WAY. Both ask the
## triangles `MountainView` draws (`_drawn_height`), never `Terrain.mountain_keepouts` and never the box: the margin the rail
## keep-out is grown by (`Terrain.RAIL_MARGIN`) exists because a drawn triangle reaches across a keep-out's edge, so a check
## against the keep-out would pass while rock stood through the sleepers (learnings/2026-09-18-mountains.md).
##
## ROCK is drawn ground more than ROCK_IS_ABOVE metres over the embankment's foot, found outward from each survey point in
## sixteen directions at 4 m steps. THE WAY is what the bank, ballast and ties cover: PERMANENT_WAY_HALF each side of every
## laid point (the bank's foot is 9 m out at 2:1 from a 3 m top), and rock over it must stand under WAY_UNDER.
const ROCK_IS_ABOVE: float = 5.0
const PERMANENT_WAY_HALF: float = 12.0
const WAY_UNDER: float = 1.0
## HOW CLOSE THE ROCK MUST NOW COME: the closest drawn rock to any survey point, against the 204 m it stood at when the rail
## keep-out was 90 m and grown by 108, and the 52 m it stood at with a 24 m box on a 40 m survey (lane/railgap). Either fails this.
const ROCK_COMES_WITHIN: float = 40.0
## AND HOW CLOSE IT MUST STAND MOUNTAIN-HIGH: the nearest drawn ground 100 m over the track, against the 164 m it stood at with rock
## climbing out of the box at 6/5 (`Terrain.RAIL_RISE_FIFTHS`). A restored default rise fails this; a rise of 3:1 gives 116 m.
const MOUNTAIN_COMES_WITHIN: float = 130.0

func _how_near_the_rock_comes_to_the_rail(island: Object) -> void:
	var squares: Dictionary = _drawn_triangles(island)
	var nearest: PackedFloat32Array = []
	# THE NEAREST DRAWN GROUND over ROCK_IS_ABOVE, 30 and 100 m, over every survey point and bearing: "the rock is near" and
	# "it reads as a mountain" are different numbers, and steepening the rise moves the second more than the first.
	var thresholds: Array[float] = [ROCK_IS_ABOVE, 30.0, 100.0]
	var closest: Array[float] = [INF, INF, INF]
	for at in Terrain.rail_points():
		var best: float = INF
		for a in range(16):
			var dir := Vector2.from_angle(TAU * float(a) / 16.0)
			var d: float = 0.0
			while d < 700.0:
				var h: float = _drawn_height(squares, at.x + dir.x * d, at.z + dir.y * d)
				if not is_nan(h):
					for t in range(3):
						if h > thresholds[t] and d < closest[t]:
							closest[t] = d
					if h > ROCK_IS_ABOVE and d < best:
						best = d
				if d >= closest[2] and d >= best:
					break
				d += 4.0
		nearest.append(best)
	var sorted: PackedFloat32Array = nearest.duplicate()
	sorted.sort()
	var reached: int = 0
	for v in sorted:
		reached += 1 if v < INF else 0
	_check("the_drawn_rock_comes_close_to_the_railway", sorted[0] <= ROCK_COMES_WITHIN,
		"nearest %.0f m (must be within %.0f), median %.0f m, %d of %d survey points have rock within 700 m" % [
			sorted[0], ROCK_COMES_WITHIN, sorted[sorted.size() / 2], reached, sorted.size()])
	_check("the_ground_rises_to_a_mountain_close_to_the_railway", closest[2] <= MOUNTAIN_COMES_WITHIN,
		"drawn ground 100 m over the track at %.0f m (must be within %.0f)" % [closest[2], MOUNTAIN_COMES_WITHIN])
	print("[mountains] the nearest drawn ground over the track: %.0f m high at %.0f m, %.0f m high at %.0f m, %.0f m high at %.0f m" % [
		thresholds[0], closest[0], thresholds[1], closest[1], thresholds[2], closest[2]])
	# THE WAY: every laid point and the middle of every chord, out to the bank's foot either side, in 2 m steps across.
	var laid: Array[Vector3] = Terrain.rail_points(Terrain.RAIL_LAID_EVERY)
	var worst: float = 0.0
	var worst_at := Vector3.ZERO
	var samples: int = 0
	for i in range(laid.size()):
		var here: Vector3 = laid[i]
		var next: Vector3 = laid[(i + 1) % laid.size()]
		var along: Vector3 = (next - here).normalized()
		var across := Vector3(-along.z, 0.0, along.x)
		for f in [0.0, 0.5]:
			var on: Vector3 = here.lerp(next, f)
			var w: float = -PERMANENT_WAY_HALF
			while w <= PERMANENT_WAY_HALF:
				var p: Vector3 = on + across * w
				var h: float = _drawn_height(squares, p.x, p.z)
				samples += 1
				if not is_nan(h) and h > worst:
					worst = h
					worst_at = p
				w += 2.0
	_check("no_drawn_rock_stands_on_the_permanent_way", worst <= WAY_UNDER and samples > 10000,
		"%d samples out to %.0f m either side of the track, highest drawn rock %.2f m at %v (must be under %.1f)" % [
			samples, PERMANENT_WAY_HALF, worst, worst_at, WAY_UNDER])


## NO GAP IN THE CORRIDOR ON A BEND. The keep-out is one box per survey point and the boxes must overlap, or rock stands in the
## chord between two of them. Asked of the RAW boxes (the one place that is right to ask them: a gap is a fact about where the
## boxes are, the margin they are grown by is a fact about the drawn surface) at every laid point, 10 m apart, and at each
## midpoint, so a chord sagging off the survey is caught. The relation is also asserted where it is defined: half a box over
## half the step.
func _the_rail_corridor_has_no_gap() -> void:
	var half: float = Terrain.RAIL_CLEAR.x
	_check("the_rail_box_is_over_half_its_step", half > Terrain.RAIL_KEEP_STEP * 0.5 and is_equal_approx(half, Terrain.RAIL_CLEAR.z),
		"half box %.1f m against a %.1f m step" % [half, Terrain.RAIL_KEEP_STEP])
	var boxes: Array[Vector3] = []
	for keep in Terrain._clearances():
		if keep["why"] == &"rail":
			boxes.append(keep["position"])
	var laid: Array[Vector3] = Terrain.rail_points(Terrain.RAIL_LAID_EVERY)
	var uncovered: int = 0
	var first := Vector3.ZERO
	for i in range(laid.size()):
		for f in [0.0, 0.5]:
			var p: Vector3 = laid[i].lerp(laid[(i + 1) % laid.size()], f)
			var inside: bool = false
			for b in boxes:
				if absf(p.x - b.x) <= half and absf(p.z - b.z) <= half:
					inside = true
					break
			if not inside:
				uncovered += 1
				first = p
	_check("no_gap_in_the_rail_corridor", uncovered == 0 and boxes.size() > 1000,
		"%d rail boxes, %d of %d laid points and midpoints outside every one (first at %v)" % [
			boxes.size(), uncovered, laid.size() * 2, first])
