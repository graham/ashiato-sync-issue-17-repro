extends Node3D
class_name SceneryYard
## THE ISLAND'S PICTURE, KEPT ROUND THE EYE: each kilometre of rock, concrete, railway, buildings and paint built as it
## comes within reach and let go once it is well out of it, a few a frame -- with the arithmetic done on worker threads,
## so a frame pays for putting finished numbers on nodes and little else.
##
## WHY IT EXISTS. The user wants a world of 30 to 70 km. The simulation keeps every static box on every peer (rule 8:
## a box is about 930 bytes and costs a tick nothing), so what is kept round the aircraft is the PICTURE -- and a
## picture of 70 km of scenery built whole is nodes, buffers and draws for ground nobody can see. The design is in the
## drafts folder beside the repository (godotgames-drafts, 2026-09-14, cockpit-streaming).
##
## LAYERS, NOT KINDS. A layer is a set of `WorldMap` cells, each with the bounds of what it will draw, a reach in metres
## and a function that builds a cell's nodes. Rock, concrete and the railway are this file's; the buildings and the
## paint are `TownView`'s, which hands its two in. The yard decides only WHEN a cell is built and let go; what a cell
## looks like is its layer's business, and nothing here knows a building from a rail. A layer is one of four, by what a
## cell needs before it can be built and how it is drawn:
## - `add_layer`: nothing. The build makes the cell from what the layer holds, on the main thread.
## - `add_worked_layer`: numbers. `work` makes them -- a MultiMesh buffer -- on a `WorkerThreadPool` task, and the build
##   puts them on nodes. Every generated layer is one: rock, concrete, the railway, the buildings and the paint.
## - `add_prepared_layer`: something the layer starts and owns -- a threaded `ResourceLoader` load, for `AuthoredChunks`
##   -- and says is ready.
## - `add_level_layer`: a worked layer drawn at a LEVEL by distance, its work and build told which: the terrain's cells,
##   coarser further out. See LEVELS below.
##
## THE RULES, each for a reason:
## - DISTANCE IS FROM THE EYE TO THE NEAREST POINT OF A CELL'S BOUNDS, on the ground. Not to its square: a mountain filed
##   in one cell leans up to 326 m into the next (`tests/world_map.gd`), and a cell measured by its square would be let
##   go while its cliff was still in reach. Not in 3D: a pilot climbing does not stop being over the ground.
## - A CELL IS BUILT WITHIN `reach`, AND LET GO ONLY BEYOND `reach + LET_GO_BEYOND` PLUS HOW FAR THE EYE GOES IN
##   `LOOK_AHEAD` AT ITS OWN SPEED, measured from the eye. Half a cell alone was not enough for an eye going round in
##   circles: see `plan_cells`.
## - WHERE THE EYE WILL BE COUNTS AS WELL AS WHERE IT IS: `LOOK_AHEAD` seconds along its own velocity, taken from how it
##   moved between two frames. A plane at 166 m/s is a cell every six seconds; ten seconds ahead builds the ground before
##   it arrives. Only for building -- a cell behind is let go by where the eye is.
## - A FEW A FRAME: `watch` stops once `ATTACH_BUDGET_USEC` have gone since it began -- the plan it asks for, the cells it
##   lets go (a quarter of the budget at most, so building is never starved) and the cells it builds -- and always takes
##   at least one cell, so a jump across the map is a few frames of filling in rather than one frame of everything.
## - THE PLAN IS WORKED OUT ON A WORKER, from copies made on the main thread, when the eye has moved `REPLAN_EVERY`
##   metres. On the island tiled to 72 km it was 2,470 us at p99 and 4,187 us at worst inside the frame (increment 3,
##   `tests/streaming_probe.gd --parts=rings`). A finished plan is used unless the eye is now more than `LET_GO_BEYOND`
##   from where it was made -- a jump -- or `fill_around` has run since: within that, every cell it lets go is still out of
##   the eye's reach and every cell it wants is still inside the margin, so a plan some hundreds of metres old is a right
##   plan. The first version dropped any plan a newer one had been asked for while it ran, and an eye that moved faster
##   than a plan could be worked out never had one used (`tests/scenery_workers.gd`: 28 dropped and 0 used across 40 km).
##   A plan asked for while one runs is started as soon as that one is taken. The task is high priority -- `add_task`
##   runs those before low ones -- so it does not queue behind a thousand cells' work.
## - A WORKED CELL'S WORK STARTS WHEN THE CELL COMES UP IN THE QUEUE, inside the budget, on a low-priority task, and the
##   cell joins the cells being worked on. Each frame those are built first, as their work finishes and in the order it
##   was started -- nearest first -- and only then is anything new started. A cell whose work is still running is asked
##   again next frame without holding up the rest, and its build is never called before the work has finished. A cell the
##   newest plan no longer wants has its work dropped, finished or not.
## - A WORKER READS, NEVER WRITES, WHAT THE MAIN THREAD OWNS. A layer's lists and bounds are complete when it is added and
##   never change size afterwards -- Godot's thread-safety page allows reading a container from several threads, not
##   resizing it -- and a task writes only into a Dictionary made for it, which the main thread reads once
##   `WorkerThreadPool.is_task_completed` says so. No work touches a node, `Sim` or the yard itself.
## - EVERY TASK IS WAITED FOR, taken or dropped: `add_task`'s own page says a task must be, for what it allocated to be
##   freed. What is still running when the yard is freed is waited for then.
## - A LET-GO CELL'S NUMBERS ARE KEPT, the last `KEEP_CELLS` of them over every worked layer, and so is finished work a
##   plan dropped: a cell wanted again is built from what was kept, and its work is not started again. A pilot turning back
##   over ground just left pays for nodes, not arithmetic. What is kept is a bounded number of cells, never a distance
##   flown (`tests/scenery_memory.gd`).
## - LEVELS. A levelled layer draws a cell at the finest level its distance allows -- level k within `reaches[k]` -- and
##   not at all past the last. FINER as soon as the nearer of the eye and the point ahead is within a finer level's reach;
##   COARSER only once the eye itself is past the drawn level's reach and the let-go margin with the swing, so an eye
##   circling on a boundary does not swap a cell back and forth. A swap is a build like any other, in the queue, inside
##   the budget and after its work, and its new level's nodes are ADDED BEFORE the old level's are freed: no frame draws the
##   cell with nothing, or with both. The old level's numbers are kept under their own level, so swapping back starts no
##   work. Every key of work in flight carries its level (Vector4i); the built cells do not, and `_level_of` says which
##   level each is drawn at (`tests/scenery_rings.gd`, `tests/scenery_memory.gd`).
## - AT BOOT IT IS ALL BUILT AT ONCE (`fill_around`): every cell's work started on every thread and waited for. A level
##   loading is a load, not a hitch, and everything that asks the picture a question on its first frame -- smoke's
##   picture-against-physics count -- finds it whole. EXCEPT A PREPARED LAYER, whose cells stream in: see the next rule.
## - A PREPARED LAYER'S CELL IS GOT READY BEFORE IT IS BUILT: `prepare` is asked once when the cell is first wanted, to
##   start a threaded load; `readiness` is asked each frame the cell is next in line, and a cell still WAITING goes to the
##   back; `release` is told when a prepared cell is let go or no longer wanted. The build is never called before READY,
##   so it may take what it prepared without blocking -- which is what `ResourceLoader.load_threaded_get` does to a load
##   that has not finished (Godot's background loading page). A cell that FAILED is warned about once and never built.
##   `fill_around` does not wait for one.
##
## THE BATCHES stand at the middle of what they draw with their instances as offsets (a MultiMesh's transforms are
## float32 whatever the engine's precision), and each is put out of the picture past its reach by
## `visibility_range_end`, measured by the engine from the camera to the middle of its box -- so a batch still in the
## tree just past its reach is not drawn either. Each is handed its whole buffer in one assignment: see `box_buffer`.
##
## `tests/scenery_yard.gd` holds the batches to the list; `tests/scenery_rings.gd` holds the rings;
## `tests/scenery_workers.gd` holds the work off the frame.

const ROCK_SHADER: Shader = preload("res://world/shaders/rock.gdshader")
## The fine finish's rock. See `wear` and `FlightLevel._wear_the_finish`.
const ROCK_FINE: Shader = preload("res://world/shaders/rock_fine.gdshader")

## Rock and concrete, each with its colours on both finishes: `[group, name, low, high, strata, grain]`.
const GROUPS: Array = [
	[Terrain.Group.ROCK, "Rock", Color(0.22, 0.21, 0.20), Color(0.46, 0.44, 0.41), 0.10, 0.55],
	# The same shader, told to be concrete: paler, flatter bedding, less grain.
	[Terrain.Group.CONCRETE, "Concrete", Color(0.44, 0.44, 0.46), Color(0.66, 0.66, 0.68), 0.03, 0.22],
]

## How far past its reach a built cell is kept, metres: half a cell.
const LET_GO_BEYOND: float = WorldMap.CELL * 0.5
## How far ahead along its own velocity the eye is looked for, seconds.
const LOOK_AHEAD: float = 10.0
## How long one `watch` may spend, microseconds. A 90 Hz headset frame is 11,111.
const ATTACH_BUDGET_USEC: int = 2000
## How far the eye moves before the plan is redrawn, metres: an eighth of a cell.
const REPLAN_EVERY: float = WorldMap.CELL * 0.125

## THE FLOATS A MULTIMESH HOLDS FOR ONE INSTANCE'S TRANSFORM: the basis's three rows, each followed by that row's origin
## component. Read from Godot 4.7's `MeshStorage::_multimesh_instance_set_transform`
## (servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp), because the class reference says nothing of the layout of
## `MultiMesh.buffer`; held to the engine by `tests/streaming_probe.gd --parts=buffers`, which fills a MultiMesh a call at
## a time on a real renderer, reads its buffer back and compares it with these, float for float.
const TRANSFORM_FLOATS: int = 12
## Colour, when a MultiMesh carries it, comes next; custom data after that. Four floats each.
const EXTRA_FLOATS: int = 4


## What a prepared layer says about a cell it was asked to prepare.
enum Readiness { WAITING, READY, FAILED }


## ONE LAYER: which cells it has, how far each is drawn, where its nodes go and how a cell's are built.
class Layer extends RefCounted:
	var name: String = ""
	var reach: float = 0.0
	var parent: Node3D = null
	## Vector2i -> AABB, the bounds of what the cell will draw.
	var bounds: Dictionary = {}
	## `func(cell: Vector2i) -> Array[Node3D]`, called on the main thread when the cell is built -- or, on a worked layer,
	## `func(cell: Vector2i, done: Dictionary) -> Array[Node3D]`, handed what `work` returned.
	var build: Callable
	## A WORKED LAYER'S: `func(cell: Vector2i) -> Dictionary`, run on a worker thread.
	var work: Callable
	## A LEVELLED LAYER'S: each level's reach, finest first and ascending; empty on any other layer. Its `work` is
	## `func(cell: Vector2i, level: int) -> Dictionary` and its `build` `func(cell: Vector2i, level: int, done: Dictionary)`.
	var reaches: Array[float] = []
	## A PREPARED LAYER'S THREE, all unset on any other:
	## `func(cell: Vector2i) -> void`, once, when the cell is first wanted;
	var prepare: Callable
	## `func(cell: Vector2i) -> int`, a `Readiness`, each frame the cell is next in line to be built;
	var readiness: Callable
	## `func(cell: Vector2i) -> void`, when a prepared cell is let go or no longer wanted, so what it started can be dropped.
	var release: Callable


var _layers: Array[Layer] = []
## Vector3i(layer, cell.x, cell.y) -> Array[Node3D]: every cell built, and what it built.
var _live: Dictionary = {}
## Vector3i -> int: the level each built cell is drawn at, 0 on a layer with no levels.
var _level_of: Dictionary = {}
## Cells wanted and not yet built, nearest first as the plan left them, read from `_queue_at` on. An index, not
## `pop_front`, which moves every key behind the one it takes: a plan on a 72 km world wants a thousand cells.
var _queue: Array[Vector4i] = []
var _queue_at: int = 0
## Built cells the plan said to let go, read the same way.
var _leaving: Array[Vector3i] = []
var _leaving_at: int = 0
## Cells whose work or load has been started, in the order it was: built from here as each is ready.
var _working: Array[Vector4i] = []
var _eye: Vector3 = Vector3.ZERO
var _eye_known: bool = false
var _velocity: Vector3 = Vector3.ZERO
var _planned_at: Vector3 = Vector3(INF, INF, INF)
var _planned_ahead: Vector3 = Vector3(INF, INF, INF)
## Whether a batch built now wears the fine material.
var _fine: bool = false
## Vector4i(layer, cell.x, cell.y, level) -> true for every cell whose work or `prepare` has been started for a level it
## is not built at yet. EVERY KEY OF WORK IN FLIGHT CARRIES ITS LEVEL -- the queue, the working list, the slots, the
## failures and the kept numbers -- and the built cells (`_live`, `_held`, the let-go list) do not: a cell is drawn at one
## level at a time, and `_level_of` says which. A layer with no levels is level 0 throughout.
var _started: Dictionary = {}
## Vector4i -> true for every cell of a prepared layer that FAILED.
var _failed: Dictionary = {}
## Vector4i -> {task: int, result: Dictionary, reaped: bool}: a worked cell's task, the Dictionary it writes its numbers
## into under "done", and whether it has been waited for.
var _slots: Dictionary = {}
## Tasks whose cell was dropped while they ran: waited for once they finish.
var _orphans: Array[int] = []
## The plan's task while one is running, and the Dictionary it writes into.
var _plan_task: int = -1
var _plan_slot: Dictionary = {}
## Which yard a plan is for, moved on by `fill_around`: a plan asked for before the level was filled is dropped.
var _plan_generation: int = 0
## Where the eye was when the running plan's copies were made.
var _plan_eye: Vector3 = Vector3.ZERO
## A plan asked for while one was running: started as soon as that one is taken.
var _plan_pending: bool = false
## True while `watch` runs, so a plan worked out on the main thread inside it is counted.
var _in_watch: bool = false

## THE ROCK AND CONCRETE MATERIALS, by group, built once and shared by every batch: `[plain mesh, fine material]`.
var _paints: Dictionary = {}

## What the rings have done, for the tests and the probe.
var built: int = 0
var let_go: int = 0
## The most microseconds any one `watch` spent, and the most one cell took inside it to build or let go.
var most_frame_usec: int = 0
var most_cell_usec: int = 0
## Plans taken from a worker and used; plans dropped because the eye had moved on while they ran; and plans worked out on
## the main thread inside `watch`, which should be none. Counted where the main-thread plan runs, so a regression that
## planned inside `watch` again would show -- a counter nothing incremented would read none for ever.
var planned_off_frame: int = 0
var plans_dropped: int = 0
var plans_on_frame: int = 0
## The most microseconds one plan took on its worker.
var most_plan_usec: int = 0
## Cells whose work was started, and cells built from numbers kept for them instead.
var works_started: int = 0
var kept_hits: int = 0
## Built cells drawn again at another level: the new level's nodes added, then the old level's freed.
var swapped: int = 0
## Vector3i -> Dictionary: the numbers every built cell of a worked layer was built from, held so they can be kept when it is
## let go. The buffer is the engine's copy's twin, and `placed` and the rest are the same Arrays the batch's metas hold.
var _held: Dictionary = {}
## Vector4i -> Dictionary: finished numbers kept for cell levels not built, oldest first -- a Dictionary keeps the order keys went
## in, so the first key is the one to drop.
var _kept: Dictionary = {}

## HOW MANY CELLS' FINISHED NUMBERS ARE KEPT, over every worked layer, for cells let go or no longer wanted.
const KEEP_CELLS: int = 512
## TEST SEAM, shipped: `KEEP_CELLS` in the game; a suite sets it to see what keeping nothing, or everything, would do.
static var keep_cells: int = KEEP_CELLS

## TEST SEAMS, shipped: milliseconds a plan and a cell's work sleep first, so a suite can make them slow enough that a
## frame waiting for either would show. Zero in the game. Read inside the work itself (`box_buffer` and the others), not
## in the task that runs it, so that work done on the main thread by any path sleeps where the frame shows it.
static var plan_delay_msec: int = 0
static var work_delay_msec: int = 0


## ---- the layers ---------------------------------------------------------------------------------

## ADD A LAYER: `bounds` is cell -> AABB of what that cell will draw, `reach` how far from the eye it is drawn, `parent`
## the node its batches go under, `build` the function that makes a cell's nodes. Returns the layer's index.
func add_layer(name: String, bounds: Dictionary, reach: float, parent: Node3D, build: Callable) -> int:
	var layer := Layer.new()
	layer.name = name
	layer.bounds = bounds
	layer.reach = reach
	layer.parent = parent
	layer.build = build
	_layers.append(layer)
	_planned_at = Vector3(INF, INF, INF)
	return _layers.size() - 1


## ADD A WORKED LAYER: `add_layer`, with each cell's numbers made by `work` on a worker thread and put on nodes by `build`,
## which is handed them. `work` is `func(cell: Vector2i) -> Dictionary` and may read only what was complete when the layer
## was added: no node, no `Sim`, no member of anything, nothing it could resize. `build` is
## `func(cell: Vector2i, done: Dictionary) -> Array[Node3D]`, on the main thread.
func add_worked_layer(name: String, bounds: Dictionary, reach: float, parent: Node3D, work: Callable,
		build: Callable) -> int:
	var index: int = add_layer(name, bounds, reach, parent, build)
	_layers[index].work = work
	return index


## ADD A LEVELLED LAYER: a worked layer drawn at a level by distance -- level 0, the finest, within `reaches[0]` of the
## eye, level k within `reaches[k]` -- and not at all past the last. `work` is `func(cell: Vector2i, level: int) ->
## Dictionary` on a worker and `build` `func(cell: Vector2i, level: int, done: Dictionary) -> Array[Node3D]`, under a
## worked layer's rules. See LEVELS at the top. Returns the layer's index, or -1 for reaches empty or not ascending.
func add_level_layer(name: String, bounds: Dictionary, reaches: Array[float], parent: Node3D, work: Callable,
		build: Callable) -> int:
	var ascending: bool = not reaches.is_empty()
	for k in range(1, reaches.size()):
		ascending = ascending and reaches[k] > reaches[k - 1]
	if not ascending:
		push_error("[yard] %s: a levelled layer needs its reaches, finest first and ascending, not %s" % [name, reaches])
		return -1
	var index: int = add_layer(name, bounds, reaches[reaches.size() - 1], parent, build)
	_layers[index].work = work
	_layers[index].reaches = reaches.duplicate()
	return index


## ADD A PREPARED LAYER: `add_layer`, and the three callables that let a cell be got ready -- loaded on a thread -- before
## it is built. See the rule at the top.
func add_prepared_layer(name: String, bounds: Dictionary, reach: float, parent: Node3D, build: Callable,
		prepare: Callable, readiness: Callable, release: Callable) -> int:
	var index: int = add_layer(name, bounds, reach, parent, build)
	_layers[index].prepare = prepare
	_layers[index].readiness = readiness
	_layers[index].release = release
	return index


## EVERY ROCK AND CONCRETE BOX IN `map`, as a worked layer each, drawn out to `reach` metres from the eye.
func draw_boxes(map: WorldMap, reach: float, fine: bool) -> void:
	_fine = fine
	for spec in GROUPS:
		var group: int = spec[0]
		_paints[group] = _paint_for(spec)
		var by_cell: Dictionary = {}
		var bounds: Dictionary = {}
		for cell in map.cells():
			var mine: Array[Dictionary] = []
			for box in map.boxes_in(cell):
				if int(box["group"]) == group:
					mine.append(box)
			if mine.is_empty():
				continue
			by_cell[cell] = mine
			bounds[cell] = _hull_of(mine)
		var label: String = spec[1]
		# THE WORK NAMES ITS CLASS for the static it calls, and reads only these two finished Dictionaries: a lambda that
		# touched the yard would be reaching into a node from a worker.
		add_worked_layer(label, bounds, reach, self,
			func(cell: Vector2i) -> Dictionary:
				return SceneryYard.box_buffer(by_cell[cell], (bounds[cell] as AABB).get_center()),
			func(cell: Vector2i, done: Dictionary) -> Array[Node3D]:
				var node := _box_batch(done, bounds[cell], group, reach)
				node.name = "%s_%d_%d" % [label, cell.x, cell.y]
				node.set_meta(&"cell", cell)
				var out: Array[Node3D] = [node]
				return out)


## THE RAILWAY'S PIECES, as world transforms of a unit mesh, as a worked layer named `layer`: filed by the cell each
## piece's middle stands in and drawn with `mesh`. The permanent way is three of these -- the rails and the bed out to the
## far plane, the ties to `PermanentWay.TIE_REACH` -- and `RAILWAY_LAYERS` names them.
func draw_railway(pieces: Array[Transform3D], mesh: Mesh, reach: float, layer: String = "Railway") -> void:
	var by_cell: Dictionary = {}
	var bounds: Dictionary = {}
	for piece in pieces:
		var cell: Vector2i = WorldMap.cell_of(piece.origin)
		var box: AABB = piece * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
		if not by_cell.has(cell):
			by_cell[cell] = [] as Array[Transform3D]
			bounds[cell] = box
		(by_cell[cell] as Array[Transform3D]).append(piece)
		bounds[cell] = (bounds[cell] as AABB).merge(box)
	add_worked_layer(layer, bounds, reach, self,
		func(cell: Vector2i) -> Dictionary:
			return SceneryYard.rail_buffer(by_cell[cell], (bounds[cell] as AABB).get_center()),
		func(cell: Vector2i, done: Dictionary) -> Array[Node3D]:
			var node := _rail_batch(done, bounds[cell], mesh, reach)
			node.name = "%s_%d_%d" % [layer, cell.x, cell.y]
			node.set_meta(&"cell", cell)
			var out: Array[Node3D] = [node]
			return out)


## ---- the rings ----------------------------------------------------------------------------------

## BUILD EVERYTHING WITHIN REACH OF `eye`, NOW, with no budget: for the level's load. The plan is worked out here, every
## worked cell's work is started at once at high priority, so every thread takes some, and waited for; a prepared layer's
## cells are asked to prepare and left to stream in.
func fill_around(eye: Vector3) -> void:
	_eye = eye
	_eye_known = true
	_velocity = Vector3.ZERO
	# WHATEVER A WORKER IS PLANNING is for somewhere else now: dropped when it is taken.
	_plan_generation += 1
	_plan_pending = false
	var plan: Dictionary = _plan_now()
	for key in (plan["let_go"] as Array):
		_detach(key)
	for key in (plan["abandon"] as Array):
		_abandon(key)
	var now: Array[Vector4i] = []
	var later: Array[Vector4i] = []
	for key in (plan["wanted"] as Array):
		var layer: Layer = _layers[key.x]
		if layer.readiness.is_valid():
			_prepare(key)
			later.append(key)
			continue
		if layer.work.is_valid() and not _slots.has(key) and not _kept.has(key):
			_start_work(key, true)
		now.append(key)
	for key in now:
		_attach(key)
	_queue.clear()
	_queue_at = 0
	_working = later
	_leaving.clear()
	_leaving_at = 0


## THE EYE, THIS FRAME. The seam the tests drive; `_process` hands it the camera.
func watch(eye: Vector3, delta: float) -> void:
	var began: int = Time.get_ticks_usec()
	_in_watch = true
	if _eye_known and delta > 0.0:
		_velocity = (eye - _eye) / delta
	_eye = eye
	_eye_known = true
	_reap_orphans()
	_take_plan(false)
	_compact_the_queues()
	var ahead: Vector3 = _eye + _velocity * LOOK_AHEAD
	if _flat(_eye).distance_to(_flat(_planned_at)) >= REPLAN_EVERY \
			or _flat(ahead).distance_to(_flat(_planned_ahead)) >= REPLAN_EVERY:
		_ask_for_a_plan()
	var at: int = Time.get_ticks_usec()
	# LET GO FIRST, with a quarter of the budget: it is what keeps a long flight's memory down, and it is cheap.
	while _leaving_at < _leaving.size() and at - began < ATTACH_BUDGET_USEC / 4:
		var leaving: Vector3i = _leaving[_leaving_at]
		_leaving_at += 1
		if not _live.has(leaving):
			continue
		_detach(leaving)
		var done_at: int = Time.get_ticks_usec()
		most_cell_usec = maxi(most_cell_usec, done_at - at)
		at = done_at
	# THEN BUILD WHAT IS READY, in the order its work was started, till the budget is gone -- always asking about one.
	var taken: int = 0
	var still: Array[Vector4i] = []
	var i: int = 0
	while i < _working.size() and (taken == 0 or at - began < ATTACH_BUDGET_USEC):
		var key: Vector4i = _working[i]
		i += 1
		# A CELL NO LONGER STARTED was dropped by a plan, or built by `fill_around`; it leaves the list here.
		if _drawn(key) or not _started.has(key):
			continue
		taken += 1
		var layer: Layer = _layers[key.x]
		var readiness: int = _readiness(key, layer)
		if readiness == Readiness.WAITING:
			still.append(key)
		elif readiness == Readiness.FAILED:
			_fail(key, layer)
		else:
			_attach(key)
		var done_at: int = Time.get_ticks_usec()
		most_cell_usec = maxi(most_cell_usec, done_at - at)
		at = done_at
	if i < _working.size():
		still.append_array(_working.slice(i))
	_working = still
	# AND START WHAT IS NEXT IN LINE, nearest first, with what is left.
	while _queue_at < _queue.size() and at - began < ATTACH_BUDGET_USEC:
		var key: Vector4i = _queue[_queue_at]
		_queue_at += 1
		if _drawn(key) or _failed.has(key) or _started.has(key):
			continue
		var layer: Layer = _layers[key.x]
		var readiness: int = _readiness(key, layer)
		if readiness == Readiness.WAITING:
			_working.append(key)
		elif readiness == Readiness.FAILED:
			_fail(key, layer)
		else:
			_attach(key)
		var done_at: int = Time.get_ticks_usec()
		most_cell_usec = maxi(most_cell_usec, done_at - at)
		at = done_at
	most_frame_usec = maxi(most_frame_usec, Time.get_ticks_usec() - began)
	_in_watch = false


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		watch(camera.global_position, delta)


## EVERY WORKER WAITED FOR AND THE PLAN TAKEN: what a few real frames would have given a suite that drives `watch`
## faster than any thread could keep up with. A seam for the tests; the game never calls it.
func catch_up() -> void:
	while _plan_task >= 0:
		_take_plan(true)
	for key in _slots:
		var slot: Dictionary = _slots[key]
		if not bool(slot["reaped"]):
			WorkerThreadPool.wait_for_task_completion(int(slot["task"]))
			slot["reaped"] = true
	for task in _orphans:
		WorkerThreadPool.wait_for_task_completion(task)
	_orphans.clear()


## How many cells have work started or a load asked for and are not built yet, for the tests and the probe.
func working_count() -> int:
	return _started.size()


## The level a layer's cell is drawn at, or -1 if it is not built: for the tests and the probe.
func level_of(layer_name: String, cell: Vector2i) -> int:
	for i in range(_layers.size()):
		if _layers[i].name == layer_name:
			return int(_level_of.get(Vector3i(i, cell.x, cell.y), -1))
	return -1


## How many cells' finished numbers are kept, for the tests and the probe.
func kept_count() -> int:
	return _kept.size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# NO TASK LEFT UNWAITED when the yard goes: none of them reaches back into it, but each must still be waited for.
		if _plan_task >= 0:
			WorkerThreadPool.wait_for_task_completion(_plan_task)
		for key in _slots:
			if not bool(_slots[key]["reaped"]):
				WorkerThreadPool.wait_for_task_completion(int(_slots[key]["task"]))
		for task in _orphans:
			WorkerThreadPool.wait_for_task_completion(task)


## ---- the plan -----------------------------------------------------------------------------------

## A PLAN, WORKED OUT FROM A SNAPSHOT (`_snapshot`): which cells to build, nearest first; which built ones to let go; and
## which started ones are no longer wanted. Static, reading only what it is handed and changing none of it, so a worker
## may run it; `fill_around` runs the same function on the main thread, so the two cannot decide differently.
##
## LET GO what is beyond reach, the margin, and as far as the eye could get in LOOK_AHEAD at the speed it is going -- from
## the eye, in any direction. Measured from the point ahead as well, an eye going round in circles swings that point round
## a circle of its own: the first version built 25 cells and let 18 go in five laps of a 300 m helicopter orbit
## (tests/scenery_rings.gd), because the swing was wider than half a cell. WANT what is within reach of either.
##
## A LEVELLED LAYER'S CELL is wanted at the level it should be drawn at: see `_level_to_draw`.
##
## Returns `{wanted: Array[Vector4i], let_go: Array[Vector3i], abandon: Array[Vector4i]}`, made inside the call.
static func plan_cells(snapshot: Dictionary) -> Dictionary:
	var bounds: Array = snapshot["bounds"]
	var reach: Array = snapshot["reach"]
	var reaches: Array = snapshot["reaches"]
	var live: Dictionary = snapshot["live"]
	var level_of: Dictionary = snapshot["level_of"]
	var failed: Dictionary = snapshot["failed"]
	var started: Dictionary = snapshot["started"]
	var eye: Vector3 = snapshot["eye"]
	var ahead: Vector3 = snapshot["ahead"]
	var margin: float = LET_GO_BEYOND + float(snapshot["swing"])
	var let_go_now: Array[Vector3i] = []
	for key in live:
		var box: AABB = (bounds[key.x] as Dictionary)[Vector2i(key.y, key.z)]
		if _ground_distance(eye, box) > float(reach[key.x]) + margin:
			let_go_now.append(key)
	var near: Array = []
	var wanted_set: Dictionary = {}
	for i in range(bounds.size()):
		var layer_bounds: Dictionary = bounds[i]
		var layer_reach: float = reach[i]
		var levels: Array = reaches[i]
		for cell in layer_bounds:
			var built := Vector3i(i, cell.x, cell.y)
			var box: AABB = layer_bounds[cell]
			var from_eye: float = _ground_distance(eye, box)
			var distance: float = minf(from_eye, _ground_distance(ahead, box))
			var level: int = -1
			if levels.is_empty():
				if not live.has(built) and distance <= layer_reach:
					level = 0
			elif live.has(built):
				level = _level_to_draw(levels, int(level_of[built]), distance, from_eye, margin)
			else:
				level = _finest_within(levels, distance)
			if level < 0:
				continue
			var key := Vector4i(i, cell.x, cell.y, level)
			if failed.has(key):
				continue
			near.append([distance, key])
			wanted_set[key] = true
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var wanted: Array[Vector4i] = []
	for row in near:
		wanted.append(row[1])
	var abandon: Array[Vector4i] = []
	for key in started:
		var built := Vector3i(key.x, key.y, key.z)
		if not wanted_set.has(key) and not (live.has(built) and int(level_of.get(built, -1)) == key.w):
			abandon.append(key)
	return {"wanted": wanted, "let_go": let_go_now, "abandon": abandon}


## The finest level whose reach `distance` is within, or -1 past the last.
static func _finest_within(levels: Array, distance: float) -> int:
	for k in range(levels.size()):
		if distance <= float(levels[k]):
			return k
	return -1


## THE LEVEL A BUILT CELL IS TO BE DRAWN AT NEXT, or -1 to leave it as it is. Finer as soon as the nearer of the eye and
## the point ahead is within a finer level's reach; coarser only once the eye itself is past the drawn level's reach and
## `margin`, the let-go margin and the swing, so an eye circling on a boundary does not swap a cell back and forth. Past
## the last reach and the margin the cell is let go instead.
static func _level_to_draw(levels: Array, drawn: int, distance: float, from_eye: float, margin: float) -> int:
	var finest: int = _finest_within(levels, distance)
	if finest >= 0 and finest < drawn:
		return finest
	if from_eye <= float(levels[drawn]) + margin:
		return -1
	for k in range(drawn + 1, levels.size()):
		if from_eye <= float(levels[k]) + margin:
			return k
	return -1


## WHAT A PLAN READS, copied here on the main thread: the layers' bounds Dictionaries (never changed once added, in an
## Array of their own so a layer added while a plan runs does not resize what it reads), their reaches, and copies of which
## cells are built, failed and started. `Dictionary.duplicate` is one C++ copy, not a GDScript loop.
func _snapshot() -> Dictionary:
	var bounds: Array = []
	var reach: Array = []
	var reaches: Array = []
	for layer in _layers:
		bounds.append(layer.bounds)
		reach.append(layer.reach)
		reaches.append(layer.reaches)
	_planned_at = _eye
	_planned_ahead = _eye + _velocity * LOOK_AHEAD
	return {"bounds": bounds, "reach": reach, "reaches": reaches, "live": _live.duplicate(),
		"level_of": _level_of.duplicate(), "failed": _failed.duplicate(),
		"started": _started.duplicate(), "eye": _eye, "ahead": _planned_ahead, "swing": _velocity.length() * LOOK_AHEAD}


## A PLAN WORKED OUT HERE AND NOW, on the main thread, for `fill_around`.
func _plan_now() -> Dictionary:
	if _in_watch:
		plans_on_frame += 1
	return plan_cells(_snapshot())


## ASK FOR A PLAN: started on a worker now unless one is running, in which case as soon as that one is taken.
func _ask_for_a_plan() -> void:
	# WHERE IT WAS ASKED FOR, so a frame waiting on a running plan does not ask again every frame.
	_planned_at = _eye
	_planned_ahead = _eye + _velocity * LOOK_AHEAD
	if _plan_task >= 0:
		_plan_pending = true
		return
	_start_plan()


func _start_plan() -> void:
	var generation: int = _plan_generation
	var snapshot: Dictionary = _snapshot()
	_plan_eye = snapshot["eye"]
	var slot: Dictionary = {}
	_plan_slot = slot
	var delay: int = plan_delay_msec
	_plan_task = WorkerThreadPool.add_task(func() -> void:
		if delay > 0:
			OS.delay_msec(delay)
		var t: int = Time.get_ticks_usec()
		slot["plan"] = SceneryYard.plan_cells(snapshot)
		slot["usec"] = Time.get_ticks_usec() - t
		slot["generation"] = generation, true, "scenery plan")


## TAKE A FINISHED PLAN, if there is one -- or, with `block`, wait for the one running. A plan the eye has jumped away
## from, or one from before `fill_around`, is dropped; any other replaces the queue and the let-go list, and has the work
## of every started cell it no longer wants dropped.
func _take_plan(block: bool) -> void:
	if _plan_task < 0 or not (block or WorkerThreadPool.is_task_completed(_plan_task)):
		return
	WorkerThreadPool.wait_for_task_completion(_plan_task)
	_plan_task = -1
	var slot: Dictionary = _plan_slot
	_plan_slot = {}
	most_plan_usec = maxi(most_plan_usec, int(slot.get("usec", 0)))
	if int(slot.get("generation", -1)) != _plan_generation or not slot.has("plan") \
			or _flat(_plan_eye).distance_to(_flat(_eye)) > LET_GO_BEYOND:
		plans_dropped += 1
	else:
		var plan: Dictionary = slot["plan"]
		_queue = plan["wanted"]
		_queue_at = 0
		_leaving = plan["let_go"]
		_leaving_at = 0
		for key in (plan["abandon"] as Array):
			_abandon(key)
		planned_off_frame += 1
	if _plan_pending:
		_plan_pending = false
		_start_plan()


## THE QUEUES, WITH WHAT HAS BEEN READ CUT OFF once it is most of them: amortised over the reads, and done at the top of
## `watch`, inside its budget.
func _compact_the_queues() -> void:
	if _queue_at >= _queue.size():
		_queue.clear()
		_queue_at = 0
	elif _queue_at > 64 and _queue_at * 2 > _queue.size():
		var rest: Array[Vector4i] = []
		rest.assign(_queue.slice(_queue_at))
		_queue = rest
		_queue_at = 0
	if _leaving_at >= _leaving.size():
		_leaving.clear()
		_leaving_at = 0


## ---- a cell ------------------------------------------------------------------------------------

## WHETHER A CELL MAY BE BUILT NOW, starting what it needs if nothing has been started for it yet.
func _readiness(key: Vector4i, layer: Layer) -> int:
	if layer.work.is_valid():
		# KEPT: ready now, with nothing to start.
		if _kept.has(key):
			return Readiness.READY
		if not _slots.has(key):
			_start_work(key, false)
			return Readiness.WAITING
		var slot: Dictionary = _slots[key]
		if bool(slot["reaped"]) or WorkerThreadPool.is_task_completed(int(slot["task"])):
			return Readiness.READY
		return Readiness.WAITING
	if layer.readiness.is_valid():
		_prepare(key)
		return int(layer.readiness.call(Vector2i(key.y, key.z)))
	return Readiness.READY


func _fail(key: Vector4i, layer: Layer) -> void:
	_failed[key] = true
	_started.erase(key)
	push_warning("[yard] %s could not prepare cell %s; it is not built" % [layer.name, Vector2i(key.y, key.z)])


func _prepare(key: Vector4i) -> void:
	if _started.has(key) or _failed.has(key):
		return
	_started[key] = true
	_layers[key.x].prepare.call(Vector2i(key.y, key.z))


## START A WORKED CELL'S WORK on a task that writes only into a Dictionary made for it here.
func _start_work(key: Vector4i, high_priority: bool) -> void:
	var work: Callable = _layers[key.x].work
	var cell := Vector2i(key.y, key.z)
	var level: int = key.w
	var levelled: bool = not _layers[key.x].reaches.is_empty()
	var result: Dictionary = {}
	var task: int = WorkerThreadPool.add_task(func() -> void:
		result["done"] = work.call(cell, level) if levelled else work.call(cell), high_priority, "scenery cell")
	_slots[key] = {"task": task, "result": result, "reaped": false}
	_started[key] = true
	works_started += 1


## A WORKED CELL'S NUMBERS, taken: waited for if its task is still running -- which only `fill_around` builds before it
## has finished -- or worked out here if nothing was started for it.
func _take_work(key: Vector4i) -> Dictionary:
	if not _slots.has(key):
		var layer: Layer = _layers[key.x]
		if layer.reaches.is_empty():
			return layer.work.call(Vector2i(key.y, key.z))
		return layer.work.call(Vector2i(key.y, key.z), key.w)
	var slot: Dictionary = _slots[key]
	_slots.erase(key)
	if not bool(slot["reaped"]):
		WorkerThreadPool.wait_for_task_completion(int(slot["task"]))
	return (slot["result"] as Dictionary).get("done", {})


## Whether a cell is built at the level a key names.
func _drawn(key: Vector4i) -> bool:
	var built_key := Vector3i(key.x, key.y, key.z)
	return _live.has(built_key) and int(_level_of[built_key]) == key.w


func _attach(key: Vector4i) -> void:
	var layer: Layer = _layers[key.x]
	var cell := Vector2i(key.y, key.z)
	var built_key := Vector3i(key.x, key.y, key.z)
	var nodes: Array[Node3D]
	var done: Dictionary = {}
	if layer.work.is_valid():
		done = _take_kept(key) if _kept.has(key) else _take_work(key)
		if layer.reaches.is_empty():
			nodes = layer.build.call(cell, done)
		else:
			nodes = layer.build.call(cell, key.w, done)
	else:
		nodes = layer.build.call(cell)
	for node in nodes:
		layer.parent.add_child(node)
	# ANOTHER LEVEL OF A CELL ALREADY BUILT: the new level is in the tree before the old one is freed, so no frame draws
	# the cell with nothing, and the old level's numbers are kept under their own level for when it is wanted again.
	if _live.has(built_key):
		var old_level: int = int(_level_of.get(built_key, 0))
		_free_nodes(_live[built_key])
		if _held.has(built_key):
			_keep(Vector4i(key.x, key.y, key.z, old_level), _held[built_key])
		swapped += 1
	else:
		built += 1
	_live[built_key] = nodes
	_level_of[built_key] = key.w
	if layer.work.is_valid():
		_held[built_key] = done
	_started.erase(key)


func _detach(key: Vector3i) -> void:
	_free_nodes(_live[key])
	_live.erase(key)
	let_go += 1
	var level: int = int(_level_of.get(key, 0))
	_level_of.erase(key)
	if _held.has(key):
		_keep(Vector4i(key.x, key.y, key.z, level), _held[key])
		_held.erase(key)
	var layer: Layer = _layers[key.x]
	if layer.release.is_valid():
		layer.release.call(Vector2i(key.y, key.z))


func _free_nodes(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			(node as Node).get_parent().remove_child(node)
			(node as Node).queue_free()


## A CELL STARTED AND NO LONGER WANTED: its work dropped, finished or not, or its layer told to release what it prepared.
func _abandon(key: Vector4i) -> void:
	if not _started.has(key) or _drawn(key):
		return
	_started.erase(key)
	if _slots.has(key):
		var slot: Dictionary = _slots[key]
		_slots.erase(key)
		# FINISHED WORK IS KEPT, not thrown away: the plan that no longer wants the cell may be undone by the next one.
		if bool(slot["reaped"]) or WorkerThreadPool.is_task_completed(int(slot["task"])):
			if not bool(slot["reaped"]):
				WorkerThreadPool.wait_for_task_completion(int(slot["task"]))
			_keep(key, (slot["result"] as Dictionary).get("done", {}))
		else:
			_orphans.append(int(slot["task"]))
		return
	var layer: Layer = _layers[key.x]
	if layer.release.is_valid():
		layer.release.call(Vector2i(key.y, key.z))


## KEEP A CELL'S FINISHED NUMBERS for when it is wanted again, dropping the oldest once more than `keep_cells` are kept.
func _keep(key: Vector4i, done: Dictionary) -> void:
	if done.is_empty() or keep_cells <= 0:
		return
	_kept.erase(key)
	_kept[key] = done
	while _kept.size() > keep_cells:
		var oldest: Vector4i = Vector4i.ZERO
		for first in _kept:
			oldest = first
			break
		_kept.erase(oldest)


func _take_kept(key: Vector4i) -> Dictionary:
	var done: Dictionary = _kept[key]
	_kept.erase(key)
	kept_hits += 1
	return done


func _reap_orphans() -> void:
	if _orphans.is_empty():
		return
	var left: Array[int] = []
	for task in _orphans:
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
		else:
			left.append(task)
	_orphans = left


## From a point to the nearest point of a box, on the ground: zero inside it.
static func _ground_distance(at: Vector3, bounds: AABB) -> float:
	var dx: float = maxf(maxf(bounds.position.x - at.x, 0.0), at.x - bounds.end.x)
	var dz: float = maxf(maxf(bounds.position.z - at.z, 0.0), at.z - bounds.end.z)
	return sqrt(dx * dx + dz * dz)


static func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)


## ---- the numbers, on a worker -------------------------------------------------------------------

## ONE CELL'S BOXES AS THE WHOLE BUFFER THEIR BATCH TAKES, and the records the tests read. Static, touching no node, no
## `Sim` and nothing it could resize, so a worker may run it. `middle` is where the batch will stand; every instance is
## an offset from it. 16 floats an instance: the transform, then the custom data.
##
## Returns `{buffer: PackedFloat32Array, placed: Array[Transform3D], customs: Array[Color]}`.
static func box_buffer(boxes: Array[Dictionary], middle: Vector3) -> Dictionary:
	if work_delay_msec > 0:
		OS.delay_msec(work_delay_msec)
	var stride: int = TRANSFORM_FLOATS + EXTRA_FLOATS
	var buffer := PackedFloat32Array()
	buffer.resize(boxes.size() * stride)
	var placed: Array[Transform3D] = []
	var customs: Array[Color] = []
	for i in range(boxes.size()):
		var half: Vector3 = boxes[i]["half_extents"]
		var at := Transform3D(Basis.IDENTITY.scaled(half * 2.0), (boxes[i]["position"] as Vector3) - middle)
		# THE VALUE HANDED OVER IS THE VALUE KEPT, both from this one variable. The first version kept a second call of
		# `rock_custom` beside the one handed to the MultiMesh, and a batch handed zeros passed the peak check with it,
		# because the check read the copy. What the GPU buffer holds cannot be read back headless (the dummy server keeps
		# none), so the probe's `buffers` part is what holds the buffer itself.
		var custom: Color = rock_custom(boxes[i])
		put_transform(buffer, i * stride, at)
		put_four(buffer, i * stride + TRANSFORM_FLOATS, custom)
		placed.append(at)
		customs.append(custom)
	return {"buffer": buffer, "placed": placed, "customs": customs}


## THE RAILWAY'S PIECES IN ONE CELL, as the buffer their batch takes: transforms only, 12 floats an instance.
static func rail_buffer(pieces: Array[Transform3D], middle: Vector3) -> Dictionary:
	if work_delay_msec > 0:
		OS.delay_msec(work_delay_msec)
	var buffer := PackedFloat32Array()
	buffer.resize(pieces.size() * TRANSFORM_FLOATS)
	var placed: Array[Transform3D] = []
	for i in range(pieces.size()):
		var at := Transform3D(pieces[i].basis, pieces[i].origin - middle)
		put_transform(buffer, i * TRANSFORM_FLOATS, at)
		placed.append(at)
	return {"buffer": buffer, "placed": placed}


## ONE TRANSFORM INTO A BUFFER AT `offset`: the one place the layout is spelled out, for every builder of a buffer.
static func put_transform(buffer: PackedFloat32Array, offset: int, at: Transform3D) -> void:
	for row in range(3):
		# ROW `row`, COLUMN `col` IS `basis[col][row]`: GDScript indexes a Basis by column.
		for col in range(3):
			buffer[offset + row * 4 + col] = at.basis[col][row]
		buffer[offset + row * 4 + 3] = at.origin[row]


## FOUR FLOATS -- a colour or custom data -- INTO A BUFFER AT `offset`.
static func put_four(buffer: PackedFloat32Array, offset: int, value: Color) -> void:
	buffer[offset] = value.r
	buffer[offset + 1] = value.g
	buffer[offset + 2] = value.b
	buffer[offset + 3] = value.a


## ---- the batches --------------------------------------------------------------------------------

func _paint_for(spec: Array) -> Array:
	var group: int = spec[0]
	var plain := ShaderMaterial.new()
	plain.shader = ROCK_SHADER
	plain.set_shader_parameter("low_colour", spec[2])
	plain.set_shader_parameter("high_colour", spec[3])
	plain.set_shader_parameter("face_colour", (spec[2] as Color).lerp(spec[3], 0.5))
	plain.set_shader_parameter("strata", spec[4])
	plain.set_shader_parameter("grain", spec[5])
	# AND THE SAME NUMBERS ON THE FINE SHADER, worn as an override when the finish asks for it. Concrete is told
	# there is no moss, no snow and no rounding: a building is a box.
	var fine_paint := ShaderMaterial.new()
	fine_paint.shader = ROCK_FINE
	for field in ["low_colour", "high_colour", "face_colour", "strata", "grain"]:
		fine_paint.set_shader_parameter(field, plain.get_shader_parameter(field))
	# RockTuning's numbers, on both finishes: the slope a step is lit as, its corners, scree, scrub and snow.
	var shading: Dictionary = RockTuning.shader_numbers()
	for field in shading:
		plain.set_shader_parameter(field, shading[field])
		fine_paint.set_shader_parameter(field, shading[field])
	fine_paint.set_shader_parameter("moss_colour", RockTuning.SCRUB_COLOUR)
	if group != Terrain.Group.ROCK:
		fine_paint.set_shader_parameter("moss_amount", 0.0)
		fine_paint.set_shader_parameter("snow_amount", 0.0)
		fine_paint.set_shader_parameter("bevel", 0.0)
	# ONE UNIT CUBE A MATERIAL, shared by every cell's batch: the half-extents ARE the scale, doubled.
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = plain
	return [mesh, fine_paint]


## ONE CELL'S BOXES OF ONE MATERIAL, as a batch standing at the middle of their hull, from what `box_buffer` made.
func _box_batch(done: Dictionary, hull: AABB, group: int, reach: float) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _paints[group][0]
	# THE PEAK EACH BOX IS PART OF, as custom data, BEFORE THE COUNT -- a MultiMesh refuses to change what it carries
	# once it has instances (see `LiftYard._batch`). The rock shaders light a step as its peak's slope from it; concrete
	# carries zeros, which both read as "no peak". Then the count, then the whole buffer in one assignment.
	multi.use_custom_data = true
	multi.instance_count = (done["placed"] as Array).size()
	multi.buffer = done["buffer"]
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.position = hull.get_center()
	node.visibility_range_end = range_for(hull, reach)
	node.material_override = _paints[group][1] if _fine else null
	# WHAT WENT IN, kept for `drawn_boxes` -- the dummy rendering server keeps no buffer to read back headless.
	node.set_meta(&"placed", done["placed"])
	node.set_meta(&"custom", done["customs"])
	node.set_meta(&"group", group)
	return node


func _rail_batch(done: Dictionary, hull: AABB, mesh: Mesh, reach: float) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = (done["placed"] as Array).size()
	multi.buffer = done["buffer"]
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.position = hull.get_center()
	node.visibility_range_end = range_for(hull, reach)
	node.set_meta(&"placed", done["placed"])
	return node


## HOW FAR A BATCH IS DRAWN: `reach` from the eye to any part of it, which from the middle of its box is `reach` plus
## half the box's diagonal.
static func range_for(hull: AABB, reach: float) -> float:
	return reach + hull.size.length() * 0.5


## ONE BOX'S PEAK, as the four numbers a MultiMesh instance can carry: the peak's centre x and z, its crown and its
## summit (`Terrain._peak`). Zeros for a box that is not part of a peak, which the rock shaders leave as they were.
static func rock_custom(box: Dictionary) -> Color:
	if not box.has("peak"):
		return Color(0.0, 0.0, 0.0, 0.0)
	var peak: Dictionary = box["peak"]
	var centre: Vector3 = peak["centre"]
	return Color(centre.x, centre.z, float(peak["crown"]), float(peak["summit"]))


static func _hull_of(boxes: Array[Dictionary]) -> AABB:
	var hull := AABB()
	for i in range(boxes.size()):
		var half: Vector3 = boxes[i]["half_extents"]
		var one := AABB((boxes[i]["position"] as Vector3) - half, half * 2.0)
		hull = one if i == 0 else hull.merge(one)
	return hull


## ---- the finish, and what is drawn ------------------------------------------------------------------

## PUT A FINISH ON EVERY ROCK AND CONCRETE BATCH, built and to be built. The railway has one finish.
func wear(fine: bool) -> void:
	_fine = fine
	for batch in box_batches():
		batch.material_override = _paints[int(batch.get_meta(&"group"))][1] if fine else null


## Whether every built rock and concrete batch wears its fine material, read off the batches. False with none built.
func wears_fine() -> bool:
	var batches: Array[MultiMeshInstance3D] = box_batches()
	if batches.is_empty():
		return false
	for batch in batches:
		if batch.material_override != _paints[int(batch.get_meta(&"group"))][1]:
			return false
	return true


## Every BUILT rock and concrete batch, and every built railway batch.
func box_batches() -> Array[MultiMeshInstance3D]:
	return built_batches(["Rock", "Concrete"])


## Every built batch of the permanent way's layers.
const RAILWAY_LAYERS: Array[String] = ["Railway", "RailwayBed", "RailwayTies"]


func rail_batches() -> Array[MultiMeshInstance3D]:
	return built_batches(RAILWAY_LAYERS)


## Every BUILT batch of the layers named, in cell order: the yard's answer to "what of this is drawn now".
func built_batches(names: Array) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	var keys: Array = _live.keys()
	keys.sort()
	for key in keys:
		if not names.has(_layers[key.x].name):
			continue
		for node in (_live[key] as Array):
			if node is MultiMeshInstance3D:
				out.append(node)
	return out


## Which cells of a layer are built, by the layer's name.
func built_cells(layer_name: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in _live:
		if _layers[key.x].name == layer_name:
			out.append(Vector2i(key.y, key.z))
	return out


## Every cell a layer has, built or not.
func cells_of(layer_name: String) -> Array[Vector2i]:
	for layer in _layers:
		if layer.name == layer_name:
			var out: Array[Vector2i] = []
			for cell in layer.bounds:
				out.append(cell)
			return out
	var none: Array[Vector2i] = []
	return none


## How many cells are built, over every layer.
func built_count() -> int:
	return _live.size()


## EVERY BOX DRAWN, as `{position, half_extents, group, custom, cell}`, from what was handed to the built batches.
func drawn_boxes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for batch in box_batches():
		var placed: Array = batch.get_meta(&"placed", [])
		var custom: Array = batch.get_meta(&"custom", [])
		for i in range(placed.size()):
			var at: Transform3D = Transform3D(Basis.IDENTITY, batch.position) * (placed[i] as Transform3D)
			out.append({"position": at.origin, "half_extents": at.basis.get_scale() * 0.5,
				"group": int(batch.get_meta(&"group")), "custom": custom[i], "cell": batch.get_meta(&"cell")})
	return out
