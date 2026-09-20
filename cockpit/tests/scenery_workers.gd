extends Node
## Headless: does the yard do its work off the frame -- each cell's buffer on a worker, the plan on a worker -- and still
## draw exactly the list, and never build a cell that only an out-of-date plan wanted?
##
##   Godot --headless --path cockpit res://tests/scenery_workers.tscn
##
## Increment 4 moved `SceneryYard`'s two main-thread costs onto `WorkerThreadPool`: a re-plan, which on the island tiled to
## 72 km was 2,470 us at p99 and 4,187 us at worst inside the frame, and a cell's batch, up to 674 us
## (tests/streaming_probe.gd --parts=rings, before). A timing threshold in a headless suite is a threshold on the machine
## (testing_godot_headless.md), so every verdict here is something the yard cannot pass by being quick, and the timings
## are printed beside it for a person:
##
## - OFF THE FRAME: every cell's work slowed to 50 ms by the yard's own seam (`work_delay_msec`, read inside the work, so
##   work done on the main thread by any path sleeps too). No `watch` may take as long as one cell's work, and the cells
##   must still arrive. Then the eye goes off the map, and no cell is left being worked on.
## - STREAMED IN, THE LIST: nothing filled, every rock and concrete cell on the island left to arrive through `watch`, and
##   what is drawn is every box the list has, once, the size and in the place it says, carrying its own peak -- read from
##   the boxes here, not from the yard's function.
## - THE PLAN OFF THE FRAME: across 10 km over the island tiled five by five at the plane's top speed, paced at four times
##   real time, no plan is worked out inside `watch` and the plans the workers make are used. PACED, because a worker
##   takes real time and a suite's frames do not: unpaced, 21,686 frames went by in a second, the eye crossed 40 km in it,
##   and nearly every plan was 512 m out of date by the time it was finished.
## - A STALE PLAN: with the plan slowed by `plan_delay_msec`, the eye jumps 60 km and back inside one plan's run. The plan
##   for where it jumped to is dropped, and nothing is built or let go for it. (A plan only some hundreds of metres old is
##   used: the section before this one holds that a moving eye has its plans used at all.)
##
## Read RESULT=, not the exit code.

const REACH: float = 24000.0
const FRAME: float = 1.0 / 90.0
const PLANE: float = 166.0
const TILES: int = 5
const WORK_MSEC: int = 50
const FLIGHT: float = 10000.0
const SPEEDUP: float = 4.0


const RockLattice = preload("res://tests/rock_lattice.gd")
var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[scenery_workers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var island: Array[Dictionary] = Terrain.boxes()
	var tiled: Array[Dictionary] = []
	var span: float = Terrain.WORLD_HALF * 2.0
	for i in range(TILES):
		for j in range(TILES):
			var offset := Vector3((float(i) - float(TILES / 2)) * span, 0.0, (float(j) - float(TILES / 2)) * span)
			for box in island:
				var copy: Dictionary = box.duplicate()
				copy["position"] = (box["position"] as Vector3) + offset
				tiled.append(copy)
	# AND ROCK ALL OVER IT, a box a kilometre: see rock_lattice.gd for why it is laid here.
	tiled.append_array(RockLattice.laid(span * float(TILES)))
	var big := WorldMap.new(tiled)
	await _the_work_is_off_the_frame(big)
	await _cells_streamed_in_by_watch_draw_the_list(WorldMap.new(island))
	await _the_plan_is_off_the_frame(big)
	await _a_stale_plan_is_dropped(big)
	SceneryYard.work_delay_msec = 0
	SceneryYard.plan_delay_msec = 0
	_check("every_section_of_the_suite_ran", _sections == 4, "%d of 4" % _sections)
	_finish()


func _yard(map: WorldMap) -> SceneryYard:
	var yard := SceneryYard.new()
	add_child(yard)
	yard.set_process(false)
	yard.draw_boxes(map, REACH, false)
	return yard


## ---- off the frame -------------------------------------------------------------------------------------

func _the_work_is_off_the_frame(map: WorldMap) -> void:
	var yard := _yard(map)
	yard.fill_around(Vector3(-30000.0, 500.0, -30000.0))
	yard.most_cell_usec = 0
	SceneryYard.work_delay_msec = WORK_MSEC
	var there := Vector3(30000.0, 500.0, 30000.0)
	var worst_usec: int = 0
	var frames: int = 0
	var before: int = yard.built
	while frames < 3000 and yard.built - before < 20:
		var t: int = Time.get_ticks_usec()
		yard.watch(there, FRAME)
		worst_usec = maxi(worst_usec, Time.get_ticks_usec() - t)
		await get_tree().process_frame
		frames += 1
	SceneryYard.work_delay_msec = 0
	_check("with_every_cells_work_slowed_to_50_ms_no_watch_waits_for_one_and_the_cells_still_arrive",
		worst_usec < WORK_MSEC * 1000 and yard.built - before >= 20,
		"%d cells built over %d frames; the worst watch %d us, against one cell's work of %d us (the budget and the largest cell: %d us)"
			% [yard.built - before, frames, worst_usec, WORK_MSEC * 1000, SceneryYard.ATTACH_BUDGET_USEC + yard.most_cell_usec])
	# OFF THE MAP: 200 km away nothing is wanted, so once that plan is taken every cell still being worked on is dropped --
	# and not built. The first version of this check counted only what was left being worked on, and a yard that never
	# dropped anything passed it by building all 147 cells on the frames after.
	var working_there: int = yard.working_count()
	var off := Vector3(0.0, 500.0, 200000.0)
	yard.watch(off, FRAME)
	yard.catch_up()
	var built_then: int = yard.built
	for i in range(4):
		yard.watch(off, FRAME)
		yard.catch_up()
	_check("and_once_the_eye_is_off_the_map_no_cell_is_left_being_worked_on_or_built",
		working_there > 0 and yard.working_count() == 0 and yard.built == built_then,
		"%d cells being worked on before, %d after; %d built after the plan that no longer wanted them was taken" % [
			working_there, yard.working_count(), yard.built - built_then])
	yard.queue_free()
	_sections += 1


## ---- streamed in, the list -----------------------------------------------------------------------------------

func _cells_streamed_in_by_watch_draw_the_list(map: WorldMap) -> void:
	var yard := _yard(map)
	var every: int = yard.cells_of("Rock").size() + yard.cells_of("Concrete").size()
	var frames: int = 0
	while frames < 3000 and yard.box_batches().size() < every:
		yard.watch(Vector3.ZERO, FRAME)
		await get_tree().process_frame
		frames += 1
	var wanted: Dictionary = {}
	for cell in map.cells():
		for box in map.boxes_in(cell):
			var group: int = int(box["group"])
			if group != Terrain.Group.ROCK and group != Terrain.Group.CONCRETE:
				continue
			var peak := Color(0.0, 0.0, 0.0, 0.0)
			if box.has("peak"):
				var record: Dictionary = box["peak"]
				peak = Color((record["centre"] as Vector3).x, (record["centre"] as Vector3).z, float(record["crown"]),
					float(record["summit"]))
			_count(wanted, _key(box["position"], box["half_extents"], group, peak))
	var got: Dictionary = {}
	for box in yard.drawn_boxes():
		_count(got, _key(box["position"], box["half_extents"], int(box["group"]), box["custom"]))
	var differ: PackedStringArray = []
	for key in wanted:
		if int(got.get(key, 0)) != int(wanted[key]):
			differ.append("%s: %d drawn, %d listed" % [key, int(got.get(key, 0)), int(wanted[key])])
	for key in got:
		if not wanted.has(key):
			differ.append("%s: drawn, not listed" % key)
	_check("every_box_streamed_in_by_watch_is_drawn_once_the_size_and_in_the_place_the_list_says_with_its_peak",
		differ.is_empty() and frames > 1 and yard.box_batches().size() == every and yard.plans_on_frame == 0,
		"%d of %d cells after %d frames, %d boxes drawn, %d listed, %d plans inside watch%s" % [yard.box_batches().size(),
			every, frames, _total(got), _total(wanted), yard.plans_on_frame,
			"" if differ.is_empty() else ": %s" % [str(Array(differ).slice(0, 4))]])
	yard.queue_free()
	_sections += 1


## ---- the plan off the frame -----------------------------------------------------------------------------------

func _the_plan_is_off_the_frame(map: WorldMap) -> void:
	var yard := _yard(map)
	var eye := Vector3(-30000.0, 600.0, -2000.0)
	yard.fill_around(eye)
	var velocity := Vector3(PLANE, 0.0, 0.0)
	var spent: Array[int] = []
	var frames: int = int(FLIGHT / PLANE / FRAME)
	var start: int = Time.get_ticks_usec()
	for f in range(frames):
		eye += velocity * FRAME
		var t: int = Time.get_ticks_usec()
		yard.watch(eye, FRAME)
		spent.append(Time.get_ticks_usec() - t)
		await get_tree().process_frame
		var due: int = start + int(float(f + 1) * FRAME * 1000000.0 / SPEEDUP)
		var now: int = Time.get_ticks_usec()
		if due > now:
			OS.delay_usec(due - now)
	spent.sort()
	_check("across_10_km_over_a_72_km_world_no_plan_is_worked_out_inside_watch_and_the_workers_plans_are_used",
		yard.plans_on_frame == 0 and yard.planned_off_frame > 10 and yard.planned_off_frame > yard.plans_dropped,
		"%d plans taken from workers, %d dropped, %d inside watch, the longest %d us on its worker; watch p50 %d us, p99 %d us, worst %d us over %d frames" % [
			yard.planned_off_frame, yard.plans_dropped, yard.plans_on_frame, yard.most_plan_usec, spent[spent.size() / 2],
			spent[int(spent.size() * 0.99)], spent.back(), frames])
	yard.queue_free()
	_sections += 1


## ---- a stale plan ------------------------------------------------------------------------------------------

func _a_stale_plan_is_dropped(map: WorldMap) -> void:
	var yard := _yard(map)
	var home := Vector3(-30000.0, 500.0, 0.0)
	var away := Vector3(30000.0, 500.0, 0.0)
	yard.fill_around(home)
	# EVERYTHING WITHIN REACH OF HOME IS BUILT, so from here on any build or let-go is some plan's doing, and a plan for
	# home wants neither.
	var built_before: int = yard.built
	var let_go_before: int = yard.let_go
	SceneryYard.plan_delay_msec = 200
	# AWAY, AND BACK INSIDE ONE PLAN'S RUN: the plan for `away` is still being worked out when the eye is home again.
	yard.watch(away, FRAME)
	yard.watch(home, FRAME)
	# ON THE CLOCK, not by frames: two plans of 200 ms each are a few thousand headless frames. Thirty more after, so
	# anything a wrongly used plan queued has frames to be built in.
	var frames: int = 0
	var give_up: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < give_up and not (yard.plans_dropped >= 1 and yard.planned_off_frame >= 1):
		yard.watch(home, FRAME)
		await get_tree().process_frame
		frames += 1
	for i in range(30):
		yard.watch(home, FRAME)
		await get_tree().process_frame
		frames += 1
	SceneryYard.plan_delay_msec = 0
	_check("a_plan_the_eye_has_outrun_is_dropped_and_nothing_is_built_or_let_go_for_it",
		yard.plans_dropped >= 1 and yard.planned_off_frame >= 1 and yard.built == built_before
			and yard.let_go == let_go_before,
		"%d plans dropped, %d taken, over %d frames; %d built and %d let go since the eye came home" % [yard.plans_dropped,
			yard.planned_off_frame, frames, yard.built - built_before, yard.let_go - let_go_before])
	yard.queue_free()
	_sections += 1


## ---- keys ----------------------------------------------------------------------------------------

static func _key(at: Vector3, half: Vector3, group: int, custom: Color) -> String:
	return "%d|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f|%.2f,%.2f,%.3f,%.3f" % [group, at.x, at.y, at.z, half.x, half.y, half.z,
		custom.r, custom.g, custom.b, custom.a]


static func _count(into: Dictionary, key: String) -> void:
	into[key] = int(into.get(key, 0)) + 1


static func _total(counts: Dictionary) -> int:
	var sum: int = 0
	for key in counts:
		sum += int(counts[key])
	return sum


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
