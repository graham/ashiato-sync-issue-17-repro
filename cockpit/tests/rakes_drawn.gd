extends Node
## EVERY LOCOMOTIVE ON THE ISLAND IS DRAWN HAULING ITS RAKE. Headless. Read RESULT=, not the exit code.
##
## WHY THIS EXISTS. On 2026-09-17 every carriage in the game stopped being drawn, on a commit that went
## nowhere near the railway. `Sky._draw_carriages` looked the trains up in the CLIENT's registry by the ids
## `Sim.spawn_train` returned, which are the SERVER's, and the two worlds number their entities in different
## orders -- the client as records arrive, the server as it spawns. So the lookup worked while the orders
## happened to agree, and emptied every train the moment an unrelated change reordered the spawns. It is
## fixed: `_the_trains_being_drawn()` finds them by kind in `Sim.current`. See `learnings/2026-09-17-train.md`.
##
## AND NOTHING COULD HAVE NOTICED. The only tests that touched `_carriages` were `scenery_shot`,
## `town_lights_shot` and `train_shot`, and the first two walk it to HIDE the cars before a picture.
## **Walking an empty dictionary hides nothing and passes.** A check whose job is to turn something off
## cannot tell you the something was never on. `train_shot` does assert a rake -- but it is a probe that
## renders, and it is not in the gate. This is the check that is.
##
## WHAT IT HOLDS, from outside the code that draws the rake:
##   - the level runs as many trains as it lays, and is drawing a rake behind EVERY locomotive it has --
##     the locomotives counted HERE by kind, not asked of `_the_trains_being_drawn()`, because a check that
##     reused that method would agree with it when it was wrong;
##   - eight to ten cars behind each, the range typed here and not read off `Terrain`;
##   - every car SHOWN, since hiding is exactly what the other three tests do to them;
##   - and each car standing behind its own engine, one boxcar length after the last -- measured as a
##     straight-line distance against a boxcar's length typed here, never through `rail_pose` or
##     `Boxcar.SPACING`, which are what place the cars and so cannot be what judges them.
##
## THE RED IT WAS WATCHED GIVING: the original bug put back -- the trains looked up by the ids the spawn
## returned -- and a rake drawn one car length too far apart. See the commit that adds this file.

## How many frames the level is given to come up, and then to draw. A rake is built the first time the
## level DRAWS it, a frame after the spawn.
const PATIENCE: int = 3000
const SETTLE: int = 30

## EIGHT TO TEN CARS, what the user asked for on 2026-09-17. Typed here, not read off `Terrain`: a check
## that asks the code for the number it checks cannot catch that number being wrong.
const CARS_LEAST: int = 8
const CARS_MOST: int = 10

## ONE CAR TO THE NEXT, straight line, metres. A 40 ft boxcar is 12.2 m over its body and about 13 m over
## its couplers (`cockpit/craft/train/sources.md`). The band is wide on purpose -- on a curve the chord
## between two cars is a little shorter than the track between them -- and narrow enough that a rake laid
## one car length too far apart, or piled on its engine, cannot pass.
const CAR_GAP_LEAST: float = 11.0
const CAR_GAP_MOST: float = 16.0
## AND THE FIRST CAR CLEAR OF ITS ENGINE: from the locomotive's middle, at least half an F7A plus half a
## boxcar, or the two bodies are drawn through each other. Typed from the published lengths -- 50 ft 8 in
## and the 40 ft car's 12.60 m -- and not from `Boxcar` or the shape, for the reason above. The first
## version of this file allowed 9 m here and would have passed the very fault it then found: the level
## spaced the first car like any other, 13.48 m from the engine's middle, which drew it 0.54 m INSIDE the
## F7A (and 1.82 m inside the 18 m box before it). The most allows the two couplers and slack.
const FIRST_CAR_LEAST: float = (50.0 * 0.3048 + 8.0 * 0.0254) * 0.5 + 12.60 * 0.5
const FIRST_CAR_MOST: float = FIRST_CAR_LEAST + 4.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _finished: bool = false


func _check(label: String, ok: bool, detail: String) -> void:
	print("[rakes_drawn] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("the_native_library_is_loaded", false, "no CockpitWorld")
		_finish()
		return
	var chosen: String = Net.choose_level("island")
	_check("the_island_can_be_chosen", chosen == "", "'%s'" % chosen)
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	var frames: int = 0
	while frames < PATIENCE and not (Sim.is_ready and Sim.client != null and not Sim.current.is_empty()):
		await get_tree().process_frame
		frames += 1
	_check("the_island_comes_up", Sim.is_ready and Sim.client != null,
		"after %d frames, sim ready %s" % [frames, Sim.is_ready])
	if not Sim.is_ready or Sim.client == null:
		_finish()
		return
	for i in range(SETTLE):
		await get_tree().process_frame

	var engines: Array[int] = _locomotives()
	var rakes: Dictionary = _level.get("_carriages") as Dictionary
	_every_locomotive_hauls_a_rake(engines, rakes)
	_of_eight_to_ten_cars_all_shown(engines, rakes)
	_each_car_one_length_behind_the_last(engines, rakes)
	_finish()


## THE LOCOMOTIVES, counted here by kind -- the level's own `_the_trains_being_drawn()` is what this checks,
## so it is not what this uses.
func _locomotives() -> Array[int]:
	var out: Array[int] = []
	for entity in Sim.current:
		if int((Sim.current[entity] as Dictionary).get("kind", -1)) == Sim.Kind.TRAIN:
			out.append(int(entity))
	out.sort()
	return out


func _every_locomotive_hauls_a_rake(engines: Array[int], rakes: Dictionary) -> void:
	var laid: int = Terrain.trains().size()
	_check("the_level_runs_every_train_it_lays", engines.size() == laid and laid > 0,
		"%d locomotive(s) in the client's world, %d laid" % [engines.size(), laid])
	var without: PackedStringArray = []
	for engine in engines:
		if not rakes.has(engine) or (rakes[engine] as Array).is_empty():
			without.append(str(engine))
	# `not engines.is_empty()` is what stops an island with no trains at all passing this for want of
	# anything to find wrong.
	_check("and_draws_a_rake_behind_every_one_of_them", not engines.is_empty() and without.is_empty(),
		"%d rake(s) for %d locomotive(s)%s" % [rakes.size(), engines.size(),
			"" if without.is_empty() else "; none behind %s" % ", ".join(without)])


func _of_eight_to_ten_cars_all_shown(engines: Array[int], rakes: Dictionary) -> void:
	var counts: PackedStringArray = []
	var within: bool = not engines.is_empty()
	var hidden: int = 0
	for engine in engines:
		var cars: Array = rakes.get(engine, []) as Array
		counts.append(str(cars.size()))
		within = within and cars.size() >= CARS_LEAST and cars.size() <= CARS_MOST
		for car in cars:
			if not (car as Node3D).is_visible_in_tree():
				hidden += 1
	_check("each_rake_is_eight_to_ten_cars", within,
		"%s car(s) against %d..%d" % [", ".join(counts), CARS_LEAST, CARS_MOST])
	_check("and_every_car_is_shown", not engines.is_empty() and hidden == 0, "%d hidden" % hidden)


func _each_car_one_length_behind_the_last(engines: Array[int], rakes: Dictionary) -> void:
	var worst: String = ""
	var placed: bool = not engines.is_empty()
	for engine in engines:
		var loco: VehicleView = _level.view_of(engine)
		var cars: Array = rakes.get(engine, []) as Array
		if loco == null or cars.is_empty():
			placed = false
			worst = "locomotive %d has no drawn view or no cars" % engine
			continue
		var previous: Vector3 = loco.global_position
		for i in range(cars.size()):
			var at: Vector3 = (cars[i] as Node3D).global_position
			var gap: float = at.distance_to(previous)
			var ok: bool = gap >= CAR_GAP_LEAST and gap <= CAR_GAP_MOST
			if i == 0:
				ok = gap >= FIRST_CAR_LEAST and gap <= FIRST_CAR_MOST
			# AND BEHIND: each car further from its engine than the one before it, so a rake folded
			# back on itself or laid ahead of the locomotive cannot pass on its gaps alone.
			if i > 0:
				ok = ok and at.distance_to(loco.global_position) \
					> (cars[i - 1] as Node3D).global_position.distance_to(loco.global_position)
			if not ok and placed:
				worst = "engine %d, car %d: %.2f m from the %s" % [engine, i, gap,
					"engine" if i == 0 else "car before it"]
			placed = placed and ok
			previous = at
	_check("and_each_car_stands_one_boxcar_behind_the_last", placed,
		"every gap within %.0f..%.0f m" % [CAR_GAP_LEAST, CAR_GAP_MOST] if placed else worst)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	Sim.stop()
	Net.leave("suite over")
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
