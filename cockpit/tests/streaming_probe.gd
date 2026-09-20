extends Node
## WHAT THE ISLAND COSTS TO BUILD, WHAT IT LEAVES LOADED, AND WHAT A FLIGHT ACROSS IT DOES TO THE FRAME.
##
##   Godot --headless --path cockpit res://tests/streaming_probe.tscn -- --level=watch
##   Godot --path cockpit res://tests/streaming_probe.tscn -- --level=watch --parts=build,views,flight
##   Godot --path cockpit res://tests/streaming_probe.tscn -- --level=watch --parts=flight \
##       --seconds=240 --speed=170 --altitude=700 --out=C:/somewhere --finish=fine
##
## WHY IT EXISTS. The user asked for large maps that load and unload round the aircraft, from a brief written
## for a game made of authored tile scenes. This one is not: the island is GENERATED on every machine from
## `Terrain`, its static collision is not replicated (agents.md, RULES 8), and it is drawn as a handful of
## MultiMeshes. So before anything is designed to stream, this says what there is to stream: where the
## build's time goes, what it leaves in memory and on the GPU, and whether flying across it hitches today.
##
## FIVE PARTS, each asked for by name with `--parts=`:
##
## - `build`: the level loaded the way the game loads it (cold, so it carries script loading), and then each
##   piece of `FlightLevel._build` timed again on its own, warm, off the same pure functions the level calls:
##   the boxes, the grid, the roads, the keep-outs, the waypoint pools, the simulation's static boxes in a
##   throwaway world, the woods planted and put into MultiMeshes, and the towns put into theirs. Headless the
##   MultiMeshes go to the dummy rendering server, which keeps no buffers, so their GPU upload is only in a
##   windowed run's numbers.
## - `scale`: the simulation half of a bigger world. The island tiled five by five (72 km across, 25 times
##   the boxes) in one throwaway world against the island alone in another: the time to add the boxes, the
##   time of 10,000 `leg_is_clear` -- a straight walk of every box, which is what an autopilot's terrain check
##   is -- and a tick's cost with the same aircraft in both, interleaved A B A B.
## - `speeds`: every kind's thrust, forward drag and cruise from the simulation's own table, and the level top
##   speed thrust and forward drag imply, sqrt(thrust / drag). An estimate: it leaves out induced drag.
## - `views`: windowed only. Draw calls, primitives, objects and video memory from fixed places, worked out
##   from the catalogues so a run today and a run next month stand in the same air.
## - `flight`: a camera flown round the island at `--speed` m/s and `--altitude` m for `--seconds`, diagonals
##   and edges, crossing hundreds of 512 m cells. Every frame's wall time and pipeline compilations, and once
##   a second the memory, node, draw and primitive monitors, into `flight.csv` under `--out`. The simulation
##   runs, the traffic flies; this probe's camera is the observer's, posed with `look_from`.
##
## THE PROCESS'S OWN MEMORY IS NOT HERE. `MEMORY_STATIC` is what Godot's allocator holds; the extension's
## Box3D and ashiato allocate outside it. Sample the working set from outside the process for that.
##
## TWO MORE, for proving a change to how the island is built did not change what is built:
##
## - `boot`: only the level, loaded as above, with what it left in the tree. For timing a build change launch by launch.
## - `dump`: the generated world written out whole to `world.txt` under `--out` -- `boxes()`, the roads, the keep-outs
##   and both finishes' tree placements, one `var_to_str` record a line -- with each list's count and SHA-256 printed.
##   Two builds that print the same hashes built the same island, record for record, not merely as many of each.
##
## AND ONE FOR THE RINGS:
##
## - `rings`: what keeping the picture round the eye costs a frame, headless. The level's own yard and town layers are
##   built from the island, and then from the island tiled five by five, and the eye is flown round the flight's route
##   at `--speed` for `--seconds` of 120 Hz frames through `SceneryYard.watch`, each call timed: mean, p50, p99 and worst
##   in microseconds, how many frames re-planned, and what was built and let go. A re-plan walks every cell of every
##   layer, so the tiled world is where that shows. Since increment 4 the plan and each cell's buffer are made on worker
##   threads; after each timed `watch` the probe calls `catch_up`, untimed, so the workers keep up as a flight's frames
##   would let them, and prints how many plans were taken, dropped and worked out on the frame.
##
## AND ONE FOR AN APPROACH, which is the circuit's opposite question:
##
## - `approach`: one descent onto the island's runway, 1.5 km out at 80 m down to the roll, flown once and reported
##   in exactly `flight`'s format under the name `approach`. The circuit averages over the whole world as cells are
##   built and let go; an approach holds ONE surface in frame and gets closer to it, which is the axis a
##   distance-faded surface is judged on and the one a circuit cannot see. What a given surface's detail costs
##   against itself without it is a different question again and needs arms -- that is `tests/pavement_cost.gd`.
##
## AND ONE FOR THE FAR BAND:
##
## - `far`: windowed only. What drawing the scenery from 8 km to the level's 24 km costs, before anything is built to draw
##   it more cheaply: the island tiled five by five, its rock, concrete, buildings and paint in a yard of their own under a
##   bare camera and a sun, drawn once out to 24 km and once cut at 8 km, A B A B, from a low pose and a high one. The draw
##   calls, primitives and objects the engine counted, and the viewport's GPU and CPU render time, median over the frames,
##   with a picture of each on the first lap. The level's fog (density 0.00016) leaves 28 % of what stands at 8 km and 5 %
##   by 18.7 km, which is what an impostor there would be drawn through.
##
## AND ONE FOR THE WORKERS' BUFFERS:
##
## - `buffers`: windowed only. `MultiMesh.buffer`'s layout is not in the class reference; the yard's was read from the
##   engine's source. This fills MultiMeshes the documented way, a call an instance, reads the real renderer's buffer back,
##   and compares it with `SceneryYard.box_buffer`, `SceneryYard.rail_buffer`, `TownView.building_buffer` and
##   `TownView.paint_buffer` for the same instances, float for float. Headless the dummy server keeps no buffer.
##
## A probe, not a suite: none of these numbers has a right answer on somebody else's machine, and the timing
## ones move with whatever else is running. The one verdict it gives is whether every part it was asked for ran.

const WARM: int = 240
## How long a view is given to settle before its monitors are averaged, and over how many frames.
const VIEW_SETTLE: int = 45
const VIEW_FRAMES: int = 60
## The cell the flight counts crossings of. The brief's larger starting size; the design picks the real one.
const FLIGHT_CELL: float = 512.0
## The island tiled this many times each way in `scale`. Odd, so the island itself is the middle tile.
const TILES: int = 5
const TILE_SPAN: float = Terrain.WORLD_HALF * 2.0
const LEGS: int = 10000
const SCALE_AIRCRAFT: int = 24
const SCALE_BLOCK_TICKS: int = 300
const TICK: float = 1.0 / 120.0

var _failures: PackedStringArray = []
var _parts: Array[String] = []
var _ran: Array[String] = []
var _out: String = "user://streaming"
var _seconds: float = 240.0
var _speed: float = 170.0
var _altitude: float = 700.0
var _level: FlightLevel = null

## THE FLIGHT, while it is flying. See `_process`.
var _flying: bool = false
var _flown: float = 0.0
var _route: Array[Vector3] = []
var _route_length: float = 0.0
## WHICH LEG IS BEING FLOWN, as the word every line of the report is tagged with: `flight` for the circuit round the
## island, `approach` for the descent onto a runway. The only thing that differs between the two reports -- every
## format string below is the one `flight` has always used, so a number from either stands beside every frame time
## this project has already taken.
var _leg: String = "flight"
## Whether the route runs round and round (the circuit) or once and stops (the approach). An approach that looped
## would teleport back to the initial point every pass and count the jump as a frame.
var _route_loops: bool = true
var _last_usec: int = 0
var _frame_ms: Array[float] = []
var _compiles_last: int = 0
var _compile_frames: int = 0
var _compile_frame_ms: Array[float] = []
var _samples: Array[Dictionary] = []
var _next_sample: float = 0.0
var _cells: Dictionary = {}
var _crossings: int = 0
var _cell_now := Vector2i(1 << 30, 1 << 30)


func _check(label: String, ok: bool, detail: String) -> void:
	print("[streaming] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var headless: bool = DisplayServer.get_name() == "headless"
	_parts.assign(["build", "scale", "speeds", "flight"] if headless else ["build", "views", "flight"])
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"parts":
				_parts.assign(Array(parts[1].split(",", false)))
			"out":
				_out = parts[1]
			"seconds":
				_seconds = maxf(float(parts[1]), 1.0)
			"speed":
				_speed = maxf(float(parts[1]), 1.0)
			"altitude":
				_altitude = float(parts[1])
	if not headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("[streaming] %s, %s precision, %s, %s on %s, parts %s" % [Engine.get_version_info()["string"],
		"double" if OS.has_feature("double") else "single", DisplayServer.get_name(),
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(),
		",".join(PackedStringArray(_parts))])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	# THE ROOT IS BUSY ADDING THIS NODE during its own _ready, so the level goes in a frame later.
	await get_tree().process_frame

	if _parts.has("dump"):
		_write_the_world()
		_ran.append("dump")
	var needs_level: bool = _parts.has("boot") or _parts.has("build") or _parts.has("views") or _parts.has("flight") or _parts.has("approach")
	if needs_level:
		await _load_the_level()
		if _level == null:
			_finish()
			return
	if _parts.has("boot"):
		_ran.append("boot")
	if _parts.has("rings"):
		_time_the_rings()
		_ran.append("rings")
	if _parts.has("far"):
		if headless:
			_check("far_renders", false, "headless has no rendering device; run it windowed")
		else:
			await _price_the_far_band()
			_ran.append("far")
	if _parts.has("buffers"):
		if headless:
			_check("buffers_render", false, "headless keeps no MultiMesh buffer to read back; run it windowed")
		else:
			_hold_the_buffers_to_the_engine()
			_ran.append("buffers")
	if _parts.has("build"):
		_time_the_pieces()
		_ran.append("build")
	if _parts.has("scale"):
		_price_a_bigger_world()
		_ran.append("scale")
	if _parts.has("speeds"):
		_list_the_speeds()
		_ran.append("speeds")
	if _parts.has("views"):
		if headless:
			_check("views_render", false, "headless has no rendering device; run it windowed")
		else:
			await _count_the_views()
			_ran.append("views")
	if _parts.has("flight"):
		await _fly_round_the_island()
		_ran.append("flight")
	if _parts.has("approach"):
		await _fly_an_approach()
		_ran.append("approach")
	_check("every_part_asked_for_ran", _ran.size() == _parts.size(),
		"%s of %s" % [",".join(PackedStringArray(_ran)), ",".join(PackedStringArray(_parts))])
	_finish()


## ---- build ------------------------------------------------------------------------------

## THE LEVEL, LOADED AS THE GAME LOADS IT: the scene read, instanced, added, and then frames until the island is in the
## simulation. Cold, so the first of these carries every script and shader resource the level preloads.
func _load_the_level() -> void:
	var before: Dictionary = _monitors()
	var began: int = Time.get_ticks_usec()
	var packed := load("res://world/sky.tscn") as PackedScene
	var loaded: int = Time.get_ticks_usec()
	_level = packed.instantiate() as FlightLevel
	var instanced: int = Time.get_ticks_usec()
	get_tree().root.add_child(_level)
	var added: int = Time.get_ticks_usec()
	var frames: int = 0
	while (_level.get("_solid") as Array).is_empty() and frames < 600:
		await get_tree().process_frame
		frames += 1
	var built: int = Time.get_ticks_usec()
	await get_tree().process_frame
	var first_frame: int = Time.get_ticks_usec()
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_level = null
		return
	print("[streaming] level: load %.1f ms, instantiate %.1f ms, add_child (its _ready) %.1f ms, %d frames until the island was in (%.1f ms), next frame %.1f ms; %.1f ms in all"
		% [_ms(began, loaded), _ms(loaded, instanced), _ms(instanced, added), frames, _ms(added, built),
			_ms(built, first_frame), _ms(began, first_frame)])
	for i in range(WARM):
		await get_tree().process_frame
	var after: Dictionary = _monitors()
	print("[streaming] loaded, after %d frames: %s" % [WARM, _monitor_line(after, before)])
	_count_the_tree()


## WHAT THE LEVEL LEFT IN THE TREE: nodes by class, every MultiMesh and its instances, and the static boxes.
func _count_the_tree() -> void:
	var classes: Dictionary = {}
	var multimeshes: int = 0
	var instances: int = 0
	var ranged: int = 0
	var biggest: Array = []
	var stack: Array[Node] = [_level]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		classes[node.get_class()] = int(classes.get(node.get_class(), 0)) + 1
		var many := node as MultiMeshInstance3D
		if many != null and many.multimesh != null:
			multimeshes += 1
			instances += many.multimesh.instance_count
			biggest.append([many.multimesh.instance_count, String(_level.get_path_to(many))])
		var geometry := node as GeometryInstance3D
		if geometry != null and geometry.visibility_range_end > 0.0:
			ranged += 1
		for child in node.get_children():
			stack.append(child)
	var rows: Array = []
	for name in classes:
		rows.append([int(classes[name]), String(name)])
	rows.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	biggest.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var solid: Array = _level.get("_solid")
	print("[streaming] tree: %d nodes under the level; by class %s" % [_sum_counts(rows), _first(rows, 10)])
	print("[streaming] tree: %d MultiMeshInstance3D holding %d instances, largest %s; %d geometry nodes with a visibility range end"
		% [multimeshes, instances, _first(biggest, 8), ranged])
	var groups: Dictionary = {}
	for box in solid:
		var group: int = int((box as Dictionary)["group"])
		groups[group] = int(groups.get(group, 0)) + 1
	print("[streaming] static boxes: %d in the simulation (the island's %d and the ground slab), by group %s"
		% [solid.size() + 1, solid.size(), groups])


## EACH PIECE OF `FlightLevel._build` ON ITS OWN, warm, off the functions the level calls.
func _time_the_pieces() -> void:
	var t: int = Time.get_ticks_usec()
	var solid: Array[Dictionary] = Terrain.boxes()
	var boxes_ms: float = _since(t)
	t = Time.get_ticks_usec()
	var grid := BoxGrid.new(solid)
	var grid_ms: float = _since(t)
	t = Time.get_ticks_usec()
	var map := WorldMap.new(solid)
	var map_ms: float = _since(t)
	var most: int = 0
	var reaching: float = 0.0
	for cell in map.cells():
		most = maxi(most, map.boxes_in(cell).size())
		var square: Rect2 = WorldMap.square_of(cell)
		var bounds: AABB = map.bounds_of(cell)
		reaching = maxf(reaching, maxf(maxf(square.position.x - bounds.position.x, bounds.end.x - square.end.x),
			maxf(square.position.y - bounds.position.z, bounds.end.z - square.end.y)))
	t = Time.get_ticks_usec()
	var roads: Array[Dictionary] = Terrain.roads(solid)
	var roads_ms: float = _since(t)
	t = Time.get_ticks_usec()
	var keepouts: Array[Dictionary] = Terrain.ground_keepouts(solid, roads)
	var keepouts_ms: float = _since(t)
	t = Time.get_ticks_usec()
	var pooled: int = 0
	for kind in [Sim.Kind.PLANE, Sim.Kind.HELI, Sim.Kind.CAR, Sim.Kind.BOAT, Sim.Kind.OSPREY, Sim.Kind.CESSNA]:
		pooled += Terrain.waypoints(kind, grid).size()
	var pools_ms: float = _since(t)
	t = Time.get_ticks_usec()
	var zones: int = Terrain.lift_zones().size()
	var rail: int = Terrain.rail_points().size()
	var air_ms: float = _since(t)
	print("[streaming] pieces: WorldMap %d boxes into %d cells of %.0f m in %.2f ms, at most %d boxes a cell, bounds reaching %.0f m past a square"
		% [map.filed(), map.cells().size(), WorldMap.CELL, map_ms, most, reaching])
	print("[streaming] pieces: boxes() %d in %.1f ms, BoxGrid %.1f ms, roads %d in %.1f ms, keep-outs %d in %.1f ms, six waypoint pools %d points in %.1f ms, lift zones %d and rail %d points in %.1f ms"
		% [solid.size(), boxes_ms, grid_ms, roads.size(), roads_ms, keepouts.size(), keepouts_ms, pooled,
			pools_ms, zones, rail, air_ms])

	# THE SIMULATION'S HALF, in a world of its own so the running session is untouched.
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.call("start", 0)
	t = Time.get_ticks_usec()
	world.call("add_static_box", Vector3(0.0, -Terrain.GROUND_HALF.y, 0.0), Terrain.GROUND_HALF)
	for box in solid:
		world.call("add_static_box", box["position"], box["half_extents"])
	print("[streaming] pieces: %d add_static_box into a fresh server world in %.2f ms" % [solid.size() + 1, _since(t)])
	_let_go(world)

	# THE WOODS: planted (pure GDScript), then built into chunk MultiMeshes the way `Woodland._grow_one` does.
	var tuning: Script = load("res://world/forest_tuning.gd")
	var stands: Array[Dictionary] = Forests.stands()
	for fine in [false, true]:
		var mine: Dictionary = tuning.call("for_tier", fine, {})
		var lattice: Dictionary = tuning.call("for_tier", true, {})
		t = Time.get_ticks_usec()
		var chunks: Array[Dictionary] = Woodland.plant(stands, keepouts, mine, lattice)
		var plant_ms: float = _since(t)
		t = Time.get_ticks_usec()
		var mesh: ArrayMesh = Woodland.tree_mesh(mine)
		var paint: ShaderMaterial = Woodland.paint_for(mine, fine)
		var trees: int = 0
		var holder := Node3D.new()
		for chunk in chunks:
			holder.add_child(Woodland.chunk_node(chunk, mesh, paint, mine))
			trees += (chunk["trees"] as Array).size()
		var build_ms: float = _since(t)
		print("[streaming] pieces: woods %s %d trees in %d chunks, planted %.1f ms, built into MultiMeshes %.1f ms (%.1f us a tree)"
			% ["FINE" if fine else "PLAIN", trees, chunks.size(), plant_ms, build_ms,
				(plant_ms + build_ms) * 1000.0 / maxf(float(trees), 1.0)])
		holder.free()

	# THE TOWNS, the way the level draws them.
	# Counted off the transforms the view kept, NOT `drawn_buildings()`: that reads `global_transform`, which a view
	# outside the tree answers with an error per building -- 377 errors with backtraces, inside the timing, the first run.
	t = Time.get_ticks_usec()
	var towns := TownView.new()
	var yard := SceneryYard.new()
	# Drawn to the cameras' far plane, as the level draws them (`FlightLevel._far`), and all of it built at once.
	towns.draw_towns(map, TownPlan.streets() + TownPlan.road_marks(roads), 24000.0, yard)
	yard.fill_around(Vector3.ZERO)
	var towns_ms: float = _since(t)
	var buildings: int = 0
	for batch in towns.building_batches():
		buildings += (batch.get_meta(&"placed", []) as Array).size()
	print("[streaming] pieces: TownView.draw_towns %d buildings in %d cell batches in %.1f ms" % [buildings,
		towns.get_child_count(), towns_ms])
	towns.free()
	yard.free()
	print("[streaming] pieces: process working set %.0f MB" % _working_set_mb())


## ---- dump -------------------------------------------------------------------------------

## THE GENERATED WORLD, WRITTEN OUT WHOLE, by the calls the level makes, in the order it makes them. Before the level is
## loaded, so nothing a session does can reach it.
func _write_the_world() -> void:
	var solid: Array[Dictionary] = Terrain.boxes()
	var roads: Array[Dictionary] = Terrain.roads(solid)
	var keepouts: Array[Dictionary] = Terrain.ground_keepouts(solid, roads)
	var tuning: Script = load("res://world/forest_tuning.gd")
	var fine: Dictionary = tuning.call("for_tier", true, {})
	var plain: Dictionary = tuning.call("for_tier", false, {})
	var stands: Array[Dictionary] = Forests.stands()
	var lists: Array = [
		["boxes", solid],
		["roads", roads],
		["keepouts", keepouts],
		["plain_trees", Woodland.plant(stands, keepouts, plain, fine)],
		["fine_trees", Woodland.plant(stands, keepouts, fine, fine)],
	]
	var path: String = ProjectSettings.globalize_path(_out.path_join("world.txt"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check("the_world_was_written", false, path)
		return
	for pair in lists:
		var records: PackedStringArray = []
		for record in (pair[1] as Array):
			records.append(var_to_str(record).replace("\n", " "))
		var text: String = "\n".join(records)
		var trees: int = 0
		if String(pair[0]).ends_with("_trees"):
			for chunk in (pair[1] as Array):
				trees += ((chunk as Dictionary)["trees"] as Array).size()
		print("[streaming] dump: %-11s %5d records%s, sha256 %s" % [pair[0], records.size(),
			(" (%d trees)" % trees) if trees > 0 else "", text.sha256_text()])
		file.store_line("## %s %d" % [pair[0], records.size()])
		file.store_line(text)
	file.close()
	print("[streaming] dump: written to %s" % path)


## ---- rings ------------------------------------------------------------------------------

## WHAT THE RINGS COST A FRAME: the island, then the island tiled, each with its yard and town layers, the eye flown round
## the flight's route through `watch`, every call timed.
func _time_the_rings() -> void:
	var island: Array[Dictionary] = Terrain.boxes()
	var tiled: Array[Dictionary] = []
	for i in range(TILES):
		for j in range(TILES):
			var offset := Vector3((float(i) - float(TILES / 2)) * TILE_SPAN, 0.0, (float(j) - float(TILES / 2)) * TILE_SPAN)
			for box in island:
				var copy: Dictionary = box.duplicate()
				copy["position"] = (box["position"] as Vector3) + offset
				tiled.append(copy)
	var roads: Array[Dictionary] = Terrain.roads(island)
	for pair in [["island", island], ["25 tiles", tiled]]:
		var map := WorldMap.new(pair[1])
		var yard := SceneryYard.new()
		add_child(yard)
		yard.set_process(false)
		yard.draw_boxes(map, 24000.0, false)
		var towns := TownView.new()
		add_child(towns)
		towns.draw_towns(map, TownPlan.streets() + TownPlan.road_marks(roads), 24000.0, yard)
		var edge: float = Terrain.WORLD_HALF + 300.0
		var route: Array[Vector3] = [Vector3(-edge, _altitude, -edge), Vector3(edge, _altitude, edge),
			Vector3(edge, _altitude, -edge), Vector3(-edge, _altitude, edge), Vector3(-edge, _altitude, -edge)]
		var length: float = 0.0
		for i in range(route.size() - 1):
			length += route[i].distance_to(route[i + 1])
		var began: int = Time.get_ticks_usec()
		yard.fill_around(route[0])
		var fill_ms: float = _since(began)
		var built_at_fill: int = yard.built
		var frames: int = int(_seconds * 120.0)
		var spent: Array[float] = []
		var replans: int = 0
		var flown: float = 0.0
		for f in range(frames):
			flown += _speed / 120.0
			var along: float = fmod(flown, length)
			var at: Vector3 = route[0]
			for i in range(route.size() - 1):
				var span: float = route[i].distance_to(route[i + 1])
				if along <= span:
					at = route[i] + (route[i + 1] - route[i]).normalized() * along
					break
				along -= span
			var planned_before: Vector3 = yard.get("_planned_at")
			var t: int = Time.get_ticks_usec()
			yard.watch(at, 1.0 / 120.0)
			spent.append(float(Time.get_ticks_usec() - t))
			yard.catch_up()
			if yard.get("_planned_at") != planned_before:
				replans += 1
		var sorted_spent: Array[float] = spent.duplicate()
		sorted_spent.sort()
		var total: float = 0.0
		for s in spent:
			total += s
		var layer_cells: int = 0
		for name in ["Rock", "Concrete", TownView.BUILDINGS, TownView.ROADS]:
			layer_cells += yard.cells_of(name).size()
		print("[streaming] rings, %s: %d cells over four layers; fill_around %.1f ms built %d; %d frames of watch at %.0f m/s: mean %.0f us, p50 %.0f, p99 %.0f, worst %.0f; %d frames re-planned; %d built and %d let go in flight"
			% [pair[0], layer_cells, fill_ms, built_at_fill, frames, _speed, total / maxf(float(frames), 1.0),
				_percentile(sorted_spent, 0.5), _percentile(sorted_spent, 0.99), sorted_spent.back() if not sorted_spent.is_empty() else 0.0,
				replans, yard.built - built_at_fill, yard.let_go])
		print("[streaming] rings, %s: %d plans taken from workers, %d dropped, %d worked out inside watch; the most one watch spent %d us, the most one cell %d us"
			% [pair[0], yard.planned_off_frame, yard.plans_dropped, yard.plans_on_frame, yard.most_frame_usec,
				yard.most_cell_usec])
		towns.free()
		yard.free()


## ---- far --------------------------------------------------------------------------------

## THE FAR BAND'S PRICE: see the part's note at the top.
func _price_the_far_band() -> void:
	var island: Array[Dictionary] = Terrain.boxes()
	var tiled: Array[Dictionary] = []
	for i in range(TILES):
		for j in range(TILES):
			var offset := Vector3((float(i) - float(TILES / 2)) * TILE_SPAN, 0.0, (float(j) - float(TILES / 2)) * TILE_SPAN)
			for box in island:
				var copy: Dictionary = box.duplicate()
				copy["position"] = (box["position"] as Vector3) + offset
				tiled.append(copy)
	var map := WorldMap.new(tiled)
	var paint: Array[Dictionary] = TownPlan.streets() + TownPlan.road_marks(Terrain.roads(island))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(sun)
	var camera := Camera3D.new()
	camera.far = 24000.0
	add_child(camera)
	camera.make_current()
	var viewport: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	# A LOW POSE looking along the ground across tiles, and a HIGH one looking down across the map's middle.
	var poses: Array = [["low", Vector3(3000.0, 600.0, 2000.0), Vector3(20000.0, 300.0, 2000.0)],
		["high", Vector3(-4000.0, 3000.0, -4000.0), Vector3(12000.0, 0.0, 12000.0)]]
	for lap in range(2):
		for reach in [24000.0, 8000.0]:
			var yard := SceneryYard.new()
			add_child(yard)
			yard.set_process(false)
			yard.draw_boxes(map, reach, false)
			var towns := TownView.new()
			add_child(towns)
			towns.draw_towns(map, paint, reach, yard)
			for pose in poses:
				camera.look_at_from_position(pose[1], pose[2], Vector3.UP)
				yard.fill_around(pose[1])
				for f in range(VIEW_SETTLE):
					await get_tree().process_frame
				var gpu: Array[float] = []
				var cpu: Array[float] = []
				var draws: int = 0
				var primitives: int = 0
				var objects: int = 0
				for f in range(VIEW_FRAMES):
					await get_tree().process_frame
					gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
					cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
					draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
					primitives = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
					objects = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
				gpu.sort()
				cpu.sort()
				print("[streaming] far: lap %d pose %s reach %.0f m: %d cells built, draws %d, primitives %d, objects %d, gpu median %.3f ms, cpu median %.3f ms"
					% [lap, pose[0], reach, yard.built_count(), draws, primitives, objects, _percentile(gpu, 0.5),
						_percentile(cpu, 0.5)])
				if lap == 0:
					get_viewport().get_texture().get_image().save_png("%s/far-%s-%d.png" % [_out, pose[0], int(reach)])
			towns.free()
			yard.free()
			await get_tree().process_frame
			await get_tree().process_frame
	camera.free()
	sun.free()


## ---- buffers ----------------------------------------------------------------------------

## THE BUFFERS THE WORKERS MAKE, HELD TO THE ENGINE'S. Every rock and concrete cell on the island; a run of the loop's
## railway, pieces laid as `tests/scenery_yard.gd` lays them and banked so that no basis is its own transpose; and made-up
## buildings and yawed slabs, for custom data and colour. Each filled the documented way and read back, against ours.
func _hold_the_buffers_to_the_engine() -> void:
	var mesh := BoxMesh.new()
	var rows: Array = []
	var map := WorldMap.new(Terrain.boxes())
	for cell in map.cells():
		for group in [Terrain.Group.ROCK, Terrain.Group.CONCRETE]:
			var mine: Array[Dictionary] = []
			for box in map.boxes_in(cell):
				if int(box["group"]) == group:
					mine.append(box)
			if mine.is_empty():
				continue
			var hull := AABB()
			for i in range(mine.size()):
				var half: Vector3 = mine[i]["half_extents"]
				var one := AABB((mine[i]["position"] as Vector3) - half, half * 2.0)
				hull = one if i == 0 else hull.merge(one)
			var middle: Vector3 = hull.get_center()
			var rock := _engine_multimesh(mesh, mine.size(), false, true)
			for i in range(mine.size()):
				var half: Vector3 = mine[i]["half_extents"]
				rock.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(half * 2.0),
					(mine[i]["position"] as Vector3) - middle))
				rock.set_instance_custom_data(i, SceneryYard.rock_custom(mine[i]))
			rows.append(["%s %s" % [Terrain.Group.keys()[group].to_lower(), cell], rock.buffer,
				SceneryYard.box_buffer(mine, middle)["buffer"]])
	var points: Array[Vector3] = Terrain.rail_points()
	var pieces: Array[Transform3D] = []
	for i in range(mini(points.size(), 64)):
		var along: Vector3 = points[(i + 1) % points.size()] - points[i]
		pieces.append(Transform3D(Basis.looking_at(along.normalized(), Vector3.UP).rotated(along.normalized(), 0.05 * float(i))
			.scaled(Vector3(1.44, 0.16, along.length())), points[i] + along * 0.5))
	var rail_middle: Vector3 = pieces[0].origin
	var rail := _engine_multimesh(mesh, pieces.size(), false, false)
	for i in range(pieces.size()):
		rail.set_instance_transform(i, Transform3D(pieces[i].basis, pieces[i].origin - rail_middle))
	rows.append(["railway", rail.buffer, SceneryYard.rail_buffer(pieces, rail_middle)["buffer"]])
	var buildings: Array[Dictionary] = []
	for i in range(40):
		buildings.append({"position": Vector3(37.0 * i, 3.0 * i, -11.0 * i),
			"half_extents": Vector3(6.0 + i, TownTuning.STOREY * float(1 + i % 7) * 0.5, 9.0), "roof": i % 3, "seed": 7919 * i})
	var town := _engine_multimesh(mesh, buildings.size(), false, true)
	for i in range(buildings.size()):
		var half: Vector3 = buildings[i]["half_extents"]
		town.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(half * 2.0), buildings[i]["position"]))
		town.set_instance_custom_data(i, TownView.building_custom(buildings[i]))
	rows.append(["buildings", town.buffer, TownView.building_buffer(buildings, Vector3.ZERO)["buffer"]])
	var marks: Array = []
	for i in range(40):
		marks.append([Transform3D(Basis(Vector3.UP, 0.3 * float(i)).scaled(Vector3(4.0 + i, 0.05, 30.0)),
			Vector3(50.0 * i, 0.02, 13.0 * i)), Color(0.1 * float(i % 10), 0.5, 0.02 * float(i), 1.0)])
	var slabs := _engine_multimesh(mesh, marks.size(), true, false)
	for i in range(marks.size()):
		slabs.set_instance_transform(i, marks[i][0])
		slabs.set_instance_color(i, marks[i][1])
	rows.append(["paint", slabs.buffer, TownView.paint_buffer(marks, Vector3.ZERO)["buffer"]])
	var floats: int = 0
	var worst: float = 0.0
	var wrong: PackedStringArray = []
	for row in rows:
		var theirs: PackedFloat32Array = row[1]
		var ours: PackedFloat32Array = row[2]
		if theirs.size() != ours.size() or ours.is_empty():
			wrong.append("%s: the engine's %d floats against our %d" % [row[0], theirs.size(), ours.size()])
			continue
		floats += ours.size()
		for k in range(ours.size()):
			var off: float = absf(theirs[k] - ours[k])
			worst = maxf(worst, off)
			if off > 0.0001 * maxf(1.0, absf(theirs[k])):
				wrong.append("%s float %d: the engine's %f, ours %f" % [row[0], k, theirs[k], ours[k]])
				break
	print("[streaming] buffers: %d batches, %d floats, the worst difference %.9f" % [rows.size(), floats, worst])
	_check("every_buffer_the_workers_make_is_the_engines_float_for_float", wrong.is_empty() and rows.size() > 4,
		"%d batches, %d floats%s" % [rows.size(), floats, "" if wrong.is_empty() else ": %s" % [str(Array(wrong).slice(0, 4))]])


static func _engine_multimesh(mesh: Mesh, count: int, colours: bool, custom: bool) -> MultiMesh:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = colours
	multi.use_custom_data = custom
	multi.mesh = mesh
	multi.instance_count = count
	return multi


## ---- scale ------------------------------------------------------------------------------

## THE SIMULATION HALF OF A WORLD 25 TIMES THE ISLAND. Only what a bigger GENERATED world costs the C++ as it stands:
## every box added to every world, every leg walked against every box.
func _price_a_bigger_world() -> void:
	var solid: Array[Dictionary] = Terrain.boxes()
	var small: Object = ClassDB.instantiate("CockpitWorld")
	var large: Object = ClassDB.instantiate("CockpitWorld")
	small.call("start", 0)
	large.call("start", 0)
	var set_before: float = _working_set_mb()
	var t: int = Time.get_ticks_usec()
	_add_the_island(small, solid, Vector3.ZERO)
	var small_ms: float = _since(t)
	var set_small: float = _working_set_mb()
	t = Time.get_ticks_usec()
	var tiles: int = 0
	for i in range(TILES):
		for j in range(TILES):
			var offset := Vector3((float(i) - float(TILES / 2)) * TILE_SPAN, 0.0, (float(j) - float(TILES / 2)) * TILE_SPAN)
			_add_the_island(large, solid, offset)
			tiles += 1
	var large_ms: float = _since(t)
	var set_large: float = _working_set_mb()
	print("[streaming] scale: the island %d boxes added in %.2f ms; %d tiles, %d boxes, %.0f km across, added in %.2f ms"
		% [solid.size() + 1, small_ms, tiles, (solid.size() + 1) * tiles, TILE_SPAN * TILES / 1000.0, large_ms])
	print("[streaming] scale: process working set %.0f MB before, %+.1f MB after the island's boxes, %+.1f MB after the 25 tiles' (%.0f bytes a box)"
		% [set_before, set_small - set_before, set_large - set_small,
			(set_large - set_small) * 1048576.0 / maxf(float((solid.size() + 1) * tiles), 1.0)])

	# THE SAME LEGS IN BOTH, inside the middle tile: 200 m to 3 km long, 40 m to 700 m up, by the island's own hash.
	var legs: Array = []
	for i in range(LEGS):
		var from := Vector3((Terrain.hash01(i, 5101) - 0.5) * TILE_SPAN, 40.0 + Terrain.hash01(i, 5102) * 660.0,
			(Terrain.hash01(i, 5103) - 0.5) * TILE_SPAN)
		var heading: float = TAU * Terrain.hash01(i, 5104)
		var reach: float = 200.0 + Terrain.hash01(i, 5105) * 2800.0
		legs.append([from, from + Vector3(cos(heading) * reach, (Terrain.hash01(i, 5106) - 0.5) * 200.0, sin(heading) * reach)])
	for round_index in range(2):
		for pair in [["island", small], ["25 tiles", large]]:
			var world: Object = pair[1]
			var clear: int = 0
			t = Time.get_ticks_usec()
			for leg in legs:
				if bool(world.call("leg_is_clear", leg[0], leg[1], 60.0, 0.0)):
					clear += 1
			var legs_ms: float = _since(t)
			print("[streaming] scale: round %d, %s: %d leg_is_clear in %.1f ms (%.1f us a leg), %d clear"
				% [round_index + 1, pair[0], LEGS, legs_ms, legs_ms * 1000.0 / float(LEGS), clear])

	# A TICK WITH THE SAME AIRCRAFT IN BOTH, well above every box, so what differs is only what the world holds.
	for world in [small, large]:
		for i in range(SCALE_AIRCRAFT):
			var at := Vector3((float(i % 6) - 2.5) * 400.0, 1100.0, (float(i / 6) - 1.5) * 400.0)
			world.call("spawn_vehicle", Sim.Kind.PLANE, at, 0.0, Terrain.nose_from_yaw(0.0) * 60.0)
		world.call("tick", TICK)
	var medians: Dictionary = {"island": [], "25 tiles": []}
	for block in range(4):
		for pair in [["island", small], ["25 tiles", large]]:
			var spent: Array[float] = []
			for i in range(SCALE_BLOCK_TICKS):
				t = Time.get_ticks_usec()
				(pair[1] as Object).call("tick", TICK)
				spent.append(_since(t))
			spent.sort()
			(medians[pair[0]] as Array).append(_percentile(spent, 0.5))
	print("[streaming] scale: tick median per block of %d, %d aircraft, interleaved: island %s ms, 25 tiles %s ms"
		% [SCALE_BLOCK_TICKS, SCALE_AIRCRAFT, _rounded(medians["island"], 4), _rounded(medians["25 tiles"], 4)])
	_let_go(small)
	_let_go(large)


func _add_the_island(world: Object, solid: Array[Dictionary], offset: Vector3) -> void:
	world.call("add_static_box", offset + Vector3(0.0, -Terrain.GROUND_HALF.y, 0.0), Terrain.GROUND_HALF)
	for box in solid:
		world.call("add_static_box", (box["position"] as Vector3) + offset, box["half_extents"])


## ---- speeds -----------------------------------------------------------------------------

func _list_the_speeds() -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	var fastest: float = 0.0
	var fastest_kind: String = ""
	for kind in range(Sim.Kind.size()):
		var h: Dictionary = world.call("handling", kind)
		var thrust: float = float(h.get("thrust", 0.0))
		var drag: float = float(h.get("drag_forward", 0.0))
		var top: float = sqrt(thrust / drag) if drag > 0.0 and thrust > 0.0 else 0.0
		print("[streaming] speeds: %-10s thrust %9.0f N, drag_forward %8.3f, cruise %6.1f m/s, sqrt(thrust/drag) %6.1f m/s (%4.0f kph)"
			% [Sim.kind_name(kind), thrust, drag, float(h.get("cruise", 0.0)), top, top * 3.6])
		if top > fastest and top < 2000.0:
			fastest = top
			fastest_kind = Sim.kind_name(kind)
	print("[streaming] speeds: fastest by that estimate %s at %.0f m/s, %.0f kph" % [fastest_kind, fastest, fastest * 3.6])
	_let_go(world)


## ---- views ------------------------------------------------------------------------------

func _count_the_views() -> void:
	var town: Dictionary = TownCatalogue.towns()[0]
	var town_at: Vector3 = town["centre"]
	var stands: Array[Dictionary] = Forests.stands()
	var wood_at: Vector3 = stands[0]["centre"] if not stands.is_empty() else Vector3(1900.0, 0.0, 700.0)
	var peak_at: Vector3 = MountainRanges.ring_crests()[2]
	peak_at.y = 0.0
	var views: Array = [
		["island_high", Vector3(0.0, 2500.0, 7600.0), Vector3.ZERO],
		["island_middle", Vector3(0.0, 400.0, 0.0), Vector3(3000.0, 150.0, 3000.0)],
		["town_low", town_at + Vector3(0.0, 60.0, 900.0), town_at + Vector3(0.0, 40.0, 0.0)],
		["forest_low", wood_at + Vector3(0.0, 40.0, -1100.0), wood_at],
		["ring_peak", peak_at * 0.7 + Vector3(0.0, 250.0, 0.0), peak_at + Vector3(0.0, 250.0, 0.0)],
		["carrier_out", Vector3(-2200.0, 80.0, 9800.0), Vector3.ZERO],
	]
	print("[streaming] views: finish worn %s" % _level.finish_worn())
	for view in views:
		_level.observer.look_from(view[1], view[2])
		for i in range(VIEW_SETTLE):
			await get_tree().process_frame
		var sums: Dictionary = {"draws": 0.0, "primitives": 0.0, "objects": 0.0}
		for i in range(VIEW_FRAMES):
			_level.observer.look_from(view[1], view[2])
			await get_tree().process_frame
			sums["draws"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			sums["primitives"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			sums["objects"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		print("[streaming] view %-14s draws %6.0f, primitives %9.0f, objects %5.0f; %s" % [view[0],
			float(sums["draws"]) / VIEW_FRAMES, float(sums["primitives"]) / VIEW_FRAMES,
			float(sums["objects"]) / VIEW_FRAMES, _monitor_line(_monitors(), {})])


## ---- flight -----------------------------------------------------------------------------

## ROUND THE ISLAND: corner to corner, along an edge, corner to corner again and home, a little outside the coast at
## each corner so the far side of the map is crossed as well as the middle.
func _fly_round_the_island() -> void:
	var edge: float = Terrain.WORLD_HALF + 300.0
	_route.assign([Vector3(-edge, _altitude, -edge), Vector3(edge, _altitude, edge), Vector3(edge, _altitude, -edge),
		Vector3(-edge, _altitude, edge), Vector3(-edge, _altitude, -edge)])
	_route_length = 0.0
	for i in range(_route.size() - 1):
		_route_length += _route[i].distance_to(_route[i + 1])
	_frame_ms.clear()
	_samples.clear()
	_compile_frame_ms.clear()
	_compile_frames = 0
	_compiles_last = _compilations()
	_flown = 0.0
	_next_sample = 0.0
	_last_usec = Time.get_ticks_usec()
	_flying = true
	var began: int = Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - began) / 1000000.0 < _seconds:
		await get_tree().process_frame
	_flying = false
	_report_the_flight(float(Time.get_ticks_usec() - began) / 1000000.0)


## AN APPROACH ONTO A RUNWAY, ONCE, REPORTED IN THE SAME SHAPE AS THE CIRCUIT.
##
## WHY IT IS A DIFFERENT QUESTION FROM `flight`, and why both are worth having. The circuit flies the edges and
## diagonals of the whole island at a constant height and averages over the entire world -- which is the right
## question for streaming, because what it measures is cells being built and let go as the eye crosses them. An
## approach does the opposite: it holds one surface in frame and gets closer to it, from 1.5 km out down to the
## roll. Nothing new comes into view and nothing is let go; what changes is how many pixels one piece of ground
## covers and how much detail it is asked for. That is precisely the axis a distance-faded surface is judged on, and
## a circuit cannot see it because it never approaches anything.
##
## SO A CHANGE THAT COSTS NOTHING ROUND THE ISLAND CAN STILL COST SOMETHING HERE, and the reverse. Run both.
##
## EVERY FORMAT STRING IS THE CIRCUIT'S, unchanged, with only the leg's name differing, so the two stand beside each
## other and beside every frame time already recorded in this project. p99 AND worst are both reported and they are
## not the same claim: a fade that costs nothing at p99 and doubles the worst frame is a single hitch as it engages,
## which on short final is the worst possible moment for it and is invisible in a mean.
##
## ONCE AND NOT ROUND AND ROUND (`_route_loops`). A looping approach would teleport from the roll back to 1.5 km out
## every pass and count the jump as a frame -- which would land in `worst`, the one number this leg exists to get
## right.
##
## WINDOWED OR IT MEANS NOTHING, like `flight`: headless has no rendering device, so `draws` and `primitives` come
## back 0 and the frame times are the simulation's alone. Run it with a window when the question is a surface.
##
## IT DOES NOT SWAP MATERIALS AND IT IS NOT AN A/B RIG. What a surface's detail costs AGAINST THE SURFACE WITHOUT IT
## is a difference between two frame times taken seconds apart, which needs arms, interleaving and a way of throwing
## out rounds the machine spoiled; that is `tests/pavement_cost.gd`. This leg answers "what does an approach cost",
## which is a scene-level number and the one that is comparable across the project.
func _fly_an_approach() -> void:
	var frames: Array[Dictionary] = Terrain.runways()
	if frames.is_empty():
		_check("there_is_a_runway_to_approach", false, "no runways on this world")
		return
	# THE ISLAND'S OWN STRIP, and the route in its frame, so the leg is the same leg on any world: 1.5 km out at
	# 80 m -- a three degree slope, near enough -- down to the threshold and along to the far end on the deck.
	var frame: Dictionary = frames[0]
	var threshold: Vector3 = frame["threshold"]
	var along: Vector3 = frame["along"]
	var length: float = float(frame["length"])
	_route.assign([
		threshold - along * 1500.0 + Vector3.UP * 80.0,
		threshold - along * 300.0 + Vector3.UP * 16.0,
		threshold + Vector3.UP * 3.0,
		threshold + along * length + Vector3.UP * 2.0,
	])
	_route_length = 0.0
	for i in range(_route.size() - 1):
		_route_length += _route[i].distance_to(_route[i + 1])
	_route_loops = false
	_leg = "approach"
	# THE HEIGHT COLUMN IS THE CIRCUIT'S CONSTANT and this leg descends, so it is set to the height the approach
	# STARTS at rather than left reading 700 m, which would be false on every frame. The format is `flight`'s and
	# stays `flight`'s; what is put in the column is this leg's business.
	var was_altitude: float = _altitude
	_altitude = 80.0
	_frame_ms.clear()
	_samples.clear()
	_compile_frame_ms.clear()
	_compile_frames = 0
	_compiles_last = _compilations()
	_flown = 0.0
	_next_sample = 0.0
	_last_usec = Time.get_ticks_usec()
	_flying = true
	var began: int = Time.get_ticks_usec()
	# UNTIL THE ROUTE RUNS OUT, or the deadline, whichever comes first: `_process` drops `_flying` at the far end.
	while _flying and float(Time.get_ticks_usec() - began) / 1000000.0 < _seconds:
		await get_tree().process_frame
	_flying = false
	_report_the_flight(float(Time.get_ticks_usec() - began) / 1000000.0)
	_route_loops = true
	_leg = "flight"
	_altitude = was_altitude


func _process(delta: float) -> void:
	if not _flying or _level == null or _level.observer == null:
		return
	var now: int = Time.get_ticks_usec()
	var spent: float = float(now - _last_usec) / 1000.0
	_last_usec = now
	_frame_ms.append(spent)
	var compiles: int = _compilations()
	if compiles != _compiles_last:
		_compile_frames += 1
		_compile_frame_ms.append(spent)
		_compiles_last = compiles
	_flown += _speed * delta
	if not _route_loops and _flown >= _route_length:
		_flying = false
		return
	var along: float = fmod(_flown, _route_length)
	var at: Vector3 = _route[0]
	var heading := Vector3.FORWARD
	for i in range(_route.size() - 1):
		var span: float = _route[i].distance_to(_route[i + 1])
		if along <= span:
			heading = (_route[i + 1] - _route[i]).normalized()
			at = _route[i] + heading * along
			break
		along -= span
	_level.observer.look_from(at, at + heading * 1000.0 + Vector3.DOWN * 120.0)
	var cell := Vector2i(floori(at.x / FLIGHT_CELL), floori(at.z / FLIGHT_CELL))
	if cell != _cell_now:
		_cell_now = cell
		_crossings += 1
		_cells[cell] = true
	_next_sample -= delta
	if _next_sample <= 0.0:
		_next_sample += 1.0
		var row: Dictionary = _monitors()
		row["flown_m"] = _flown
		row["x"] = at.x
		row["z"] = at.z
		row["compilations"] = compiles
		_samples.append(row)


func _report_the_flight(elapsed: float) -> void:
	var sorted: Array[float] = _frame_ms.duplicate()
	sorted.sort()
	var median: float = _percentile(sorted, 0.5)
	var long_frames: int = 0
	var very_long: int = 0
	for spent in _frame_ms:
		if spent > median * 2.0:
			long_frames += 1
		if spent > 33.3:
			very_long += 1
	var compile_sorted: Array[float] = _compile_frame_ms.duplicate()
	compile_sorted.sort()
	print("[streaming] %s: %.0f s at %.0f m/s and %.0f m, %.1f km flown, %d frames, %d crossings of %.0f m cells, %d distinct cells"
		% [_leg, elapsed, _speed, _altitude, _flown / 1000.0, _frame_ms.size(), _crossings, FLIGHT_CELL, _cells.size()])
	print("[streaming] %s: frame ms p50 %.2f, p90 %.2f, p99 %.2f, p99.9 %.2f, worst %.2f; %d frames over twice the median, %d over 33 ms"
		% [_leg, median, _percentile(sorted, 0.9), _percentile(sorted, 0.99), _percentile(sorted, 0.999),
			sorted.back() if not sorted.is_empty() else 0.0, long_frames, very_long])
	print("[streaming] %s: %d frames compiled a pipeline, their ms p50 %.2f worst %.2f"
		% [_leg, _compile_frames, _percentile(compile_sorted, 0.5), compile_sorted.back() if not compile_sorted.is_empty() else 0.0])
	if _samples.is_empty():
		return
	var first: Dictionary = _samples[0]
	var last: Dictionary = _samples.back()
	var most: Dictionary = {}
	for row in _samples:
		for key in ["static_mb", "video_mb", "nodes", "objects"]:
			most[key] = maxf(float(most.get(key, -INF)), float(row[key]))
	print("[streaming] %s: first sample %s" % [_leg, _monitor_line(first, {})])
	print("[streaming] %s: last sample  %s" % [_leg, _monitor_line(last, first)])
	print("[streaming] %s: most static %.1f MB, video %.1f MB, nodes %d, objects %d"
		% [_leg, most["static_mb"], most["video_mb"], int(most["nodes"]), int(most["objects"])])
	var path: String = ProjectSettings.globalize_path(_out.path_join("%s.csv" % _leg))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check("the_%s_log_was_written" % _leg, false, path)
		return
	var keys: Array = first.keys()
	file.store_line(",".join(PackedStringArray(keys)))
	for row in _samples:
		var cells: PackedStringArray = []
		for key in keys:
			cells.append(str(row[key]))
		file.store_line(",".join(cells))
	file.close()
	print("[streaming] flight: one row a second in %s" % path)


## ---- the numbers --------------------------------------------------------------------------

func _monitors() -> Dictionary:
	return {
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"buffer_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		"texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	}


func _monitor_line(now: Dictionary, against: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in now:
		var value: float = float(now[key])
		var text: String = ("%.1f" % value) if key.ends_with("_mb") else str(int(value))
		if against.has(key):
			text += " (%+.1f)" % (value - float(against[key]))
		parts.append("%s %s" % [key, text])
	return ", ".join(parts)


func _compilations() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))


## THE WHOLE PROCESS'S RESIDENT MEMORY, in MB, for what Godot's own allocator cannot see: Box3D and ashiato allocate
## outside it. Windows asks PowerShell, which blocks the main thread for a few hundred ms, so it is read only between
## parts, never during the flight; Linux reads /proc. -1 anywhere else.
static func _working_set_mb() -> float:
	if OS.get_name() == "Windows":
		var said: Array = []
		OS.execute("powershell", ["-NoProfile", "-Command", "(Get-Process -Id %d).WorkingSet64" % OS.get_process_id()], said)
		return float(String(said[0]).strip_edges()) / 1048576.0 if not said.is_empty() else -1.0
	var status := FileAccess.open("/proc/self/status", FileAccess.READ)
	if status == null:
		return -1.0
	for line in status.get_as_text().split("\n"):
		if line.begins_with("VmRSS:"):
			return float(line.split(":")[1].strip_edges().split(" ")[0]) / 1024.0
	return -1.0


static func _percentile(sorted: Array, share: float) -> float:
	if sorted.is_empty():
		return 0.0
	return float(sorted[clampi(int(round(share * float(sorted.size() - 1))), 0, sorted.size() - 1)])


static func _ms(from: int, to: int) -> float:
	return float(to - from) / 1000.0


static func _since(from: int) -> float:
	return float(Time.get_ticks_usec() - from) / 1000.0


static func _rounded(values: Array, digits: int) -> String:
	var out: PackedStringArray = []
	for value in values:
		out.append(String.num(float(value), digits))
	return "[%s]" % ", ".join(out)


static func _first(rows: Array, count: int) -> String:
	var out: PackedStringArray = []
	for i in range(mini(count, rows.size())):
		out.append("%s %s" % [rows[i][1], rows[i][0]])
	return ", ".join(out)


static func _sum_counts(rows: Array) -> int:
	var total: int = 0
	for row in rows:
		total += int(row[0])
	return total


## A throwaway world, stopped and released. A CockpitWorld is an Object, not a RefCounted, unless it says otherwise.
static func _let_go(world: Object) -> void:
	if world == null:
		return
	if world.has_method("stop"):
		world.call("stop")
	if not (world is RefCounted):
		world.free()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
