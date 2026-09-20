extends Node
## Headless: does every building over the height carry obstruction lights where ICAO Annex 14 puts them, on its own
## ground, flashing together from the tick, dark by day, drawn as far as the building and worked out off the frame?
##
##   Godot --headless --path cockpit res://tests/night_lights.tscn
##
## Asked for on 2026-09-15: "street lights and obstruction lights on buildings, absolutely, yes". `TownView` puts the lights
## on (`obstruction_lights_on`) and `world/shaders/lamp.gdshaderinc` draws them. What a picture cannot be trusted to show,
## and is held here against something the lights did not compute:
##
## - WHERE. Every light stands on a vertical corner of a building in the list taller than `OBSTRUCTION_HIGH`, facing out
##   along its diagonal; every such building has four at its top, flashing; its levels are no more than
##   `OBSTRUCTION_LEVELS_APART` apart down to its ground, steady and flashing by turns; and no lower building has any --
##   worked out here from the boxes, never from `TownView.obstruction_lights_on`.
## - ON ITS OWN GROUND. The same, with every building lifted by a different height, so a light that assumed y = 0 is found.
## - TOGETHER, FROM THE TICK. No light carries a flash of its own; the shader flashes on the one phase handed over and never
##   reads TIME; two views handed the same tick at different moments hand the same phase; half a cycle's ticks later it is
##   half a cycle on.
## - BY THE TIME OF DAY. The lamps are 0 of their light by day, all of it at night and evening's share of night's windows at
##   evening, through the level's own call; and the shader multiplies the light by it.
## - THE REACH. Each kilometre's obstruction lights are drawn at least as far as its buildings.
## - THE FAR HANDOVER, FLOWN. With the buildings and paint at 4 km and the reds at 24 km, 14 km out and back: a tower's reds stay
##   while its walls are let go, no red within its reach less a kilometre is ever missing and none is doubled; and every built
##   lit kilometre of paint has one lamps', one poles' and one pools' batch, none without its paint.
## - OFF THE FRAME. Every cell's work slowed to 50 ms, and no `watch` takes that long while the lights arrive.
## - THE BUDGET. Each kilometre's street lights and obstruction lights worked out under `CELL_BUILD_MSEC`, each timed
##   `BUDGET_TRIES` times and the fastest kept (tests/town_lights.gd says why, with the load that made one timing read 15 ms).
## - SWITCHED OFF, NOTHING MADE. The street lights were switched off on 2026-09-15 for what they cost in a headset
##   (`TownTuning.STREET_LIGHTS_ON`). With the switch as shipped, towns drawn with every lit street build no lamps', poles' or
##   pools' batch and make no pool or pole material, while their paint, far lights and reds are built. Every other street-light
##   check here runs with `TownView.street_lights_in_tests` on, so the code behind the switch cannot rot while it is off.
##
## Read RESULT=, not the exit code.

const FAR: float = 24000.0
const WAIT_MSEC: int = 20000
const FRAME: float = 1.0 / 90.0
const WORK_MSEC: int = 50
const SAME: float = 0.01
## The reach a flight's buildings and paint are drawn to: short enough that a 14 km leg lets them go and builds them again.
const FLOWN_REACH: float = 4000.0
## The plane's speed, metres a second, for the flights.
const PLANE: float = 166.0
## The budget, as tests/town_lights.gd holds the far lights to it: one kilometre worked out in under this many milliseconds,
## and the island tiled TILED times -- tests/scenery_memory.gd's 72 km world -- in under TILED_MB of instance data.
const CELL_BUILD_MSEC: float = 10.0
const TILED: int = 25
const TILED_MB: float = 20.0
## What the main thread may pay to put the densest kilometre of street lights on nodes, warm, microseconds.
const BUILD_MOST_USEC: int = 500
## How many times each kilometre's street and obstruction work is timed for the budget, the fastest kept, for the reason
## tests/town_lights.gd's THE BUDGET gives with its numbers: one timing on a busy machine is the work and whatever preempted it.
const BUDGET_TRIES: int = 5

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[night_lights] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var solid: Array[Dictionary] = Terrain.boxes()
	var buildings: Array[Dictionary] = _buildings_of(solid)
	# THE PAINT AS THE LEVEL HANDS IT: every town street, which is lit, and every road between towns, which is not.
	var streets: Array[Dictionary] = TownPlan.streets()
	var paint: Array[Dictionary] = streets + TownPlan.road_marks(Terrain.roads(solid))
	# THE SWITCH AS SHIPPED, before anything turns the street lights on; then on for every street-light check after it.
	TownView.street_lights_in_tests = false
	_the_street_lights_are_made_only_when_switched_on(WorldMap.new(solid), paint)
	TownView.street_lights_in_tests = true
	var pair: Array = _towns(WorldMap.new(solid), FAR, paint)
	(pair[0] as SceneryYard).fill_around(Vector3.ZERO)
	_the_obstruction_lights_stand_where_icao_puts_them("", buildings, pair[1])
	_every_kilometres_obstruction_lights_are_drawn_as_far_as_its_buildings(pair[1])
	_the_lamps_show_as_the_time_of_day_says(pair[1])
	_street_lights_stand_along_the_streets("", streets, buildings, pair[1])
	_the_pools_take_their_numbers_and_hand_their_light_over_by_one_function(pair[1])
	(pair[0] as Node).queue_free()
	(pair[1] as Node).queue_free()
	# THE STREETS ON THEIR OWN GROUND, 250 m up, with the roads between towns beside them.
	var raised_streets: Array[Dictionary] = []
	for mark in streets:
		var copy: Dictionary = mark.duplicate()
		copy["position"] = (mark["position"] as Vector3) + Vector3.UP * 250.0
		raised_streets.append(copy)
	var high_pair: Array = _towns(WorldMap.new(solid), FAR, raised_streets)
	(high_pair[0] as SceneryYard).fill_around(Vector3.ZERO)
	_street_lights_stand_along_the_streets("_on_ground_that_is_not_at_nought", raised_streets, buildings, high_pair[1])
	(high_pair[0] as Node).queue_free()
	(high_pair[1] as Node).queue_free()
	await _the_street_lights_are_worked_off_the_frame(WorldMap.new(solid), paint)
	await _the_street_lights_fit_their_budget(WorldMap.new(solid), paint)
	_the_obstruction_lights_fit_their_budget(WorldMap.new(solid))
	# ON THEIR OWN GROUND: every building lifted by its own height, 37 to 437 m, as ground that rises would stand it.
	var lifted: Array[Dictionary] = []
	for box in solid:
		var copy: Dictionary = box.duplicate()
		if int(box["group"]) == Terrain.Group.BUILDING:
			copy["position"] = (box["position"] as Vector3) + Vector3.UP * (37.0 + fposmod(float(int(box["seed"])) * 7.3, 400.0))
		lifted.append(copy)
	var raised: Array = _towns(WorldMap.new(lifted))
	(raised[0] as SceneryYard).fill_around(Vector3.ZERO)
	_the_obstruction_lights_stand_where_icao_puts_them("_on_ground_that_is_not_at_nought", _buildings_of(lifted), raised[1])
	(raised[0] as Node).queue_free()
	(raised[1] as Node).queue_free()
	await _a_town_flashes_together_from_the_tick(WorldMap.new(solid))
	await _the_obstruction_lights_are_worked_off_the_frame(WorldMap.new(solid))
	await _flown_out_and_back_the_reds_stay_while_their_walls_go(WorldMap.new(solid))
	await _flown_out_and_back_every_lit_kilometre_has_its_lamps_poles_and_pools_once(WorldMap.new(solid), paint)
	SceneryYard.work_delay_msec = 0
	TownView.street_lights_in_tests = false
	_check("every_section_of_the_suite_ran", _sections == 15, "%d of 15" % _sections)
	_finish()


static func _buildings_of(solid: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for box in solid:
		if int(box["group"]) == Terrain.Group.BUILDING:
			out.append(box)
	return out


func _towns(map: WorldMap, reach: float = FAR, paint: Array[Dictionary] = [], lamp_reach: float = -1.0) -> Array:
	var yard := SceneryYard.new()
	add_child(yard)
	yard.set_process(false)
	var towns := TownView.new()
	add_child(towns)
	towns.draw_towns(map, paint, reach, yard, lamp_reach)
	return [yard, towns]


## Every obstruction light, as `{at, out, candela, kind, rise}` in the world, read out of the very buffer each batch was
## handed (`SceneryYard.put_transform`'s layout: row `row` of the basis at `row * 4`, its origin after it).
static func _lights(towns: TownView) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
	for batch in towns.obstruction_batches():
		var buffer: PackedFloat32Array = batch.get_meta(&"buffer", PackedFloat32Array())
		for i in range(buffer.size() / stride):
			var o: int = i * stride
			var c: int = o + SceneryYard.TRANSFORM_FLOATS
			out.append({"at": batch.position + Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11]),
				"out": Vector3(buffer[o + 2], buffer[o + 6], buffer[o + 10]), "candela": buffer[c], "kind": int(buffer[c + 1]),
				"rise": buffer[c + 3]})
	return out


## ---- where ---------------------------------------------------------------------------------------

func _the_obstruction_lights_stand_where_icao_puts_them(suffix: String, buildings: Array[Dictionary], towns: TownView) -> void:
	var lights: Array[Dictionary] = _lights(towns)
	# EACH LIGHT TO THE BUILDING WHOSE VERTICAL CORNER IT STANDS ON, asked of the boxes.
	var on: Dictionary = {}
	var astray: Array[String] = []
	var facing_in: int = 0
	for light in lights:
		var at: Vector3 = light["at"]
		var found: int = -1
		for b in range(buildings.size()):
			var centre: Vector3 = buildings[b]["position"]
			var half: Vector3 = buildings[b]["half_extents"]
			if absf(absf(at.x - centre.x) - half.x) < SAME and absf(absf(at.z - centre.z) - half.z) < SAME \
					and at.y <= centre.y + half.y + SAME and at.y > centre.y - half.y + SAME:
				found = b
				var away := Vector3(signf(at.x - centre.x), 0.0, signf(at.z - centre.z)).normalized()
				if (light["out"] as Vector3).distance_to(away) > SAME:
					facing_in += 1
				break
		if found < 0:
			astray.append("%s" % at.round())
			continue
		if not on.has(found):
			on[found] = []
		(on[found] as Array).append(light)
	var wrong: Array[String] = []
	var tall: int = 0
	for b in range(buildings.size()):
		var half: Vector3 = buildings[b]["half_extents"]
		var top: float = (buildings[b]["position"] as Vector3).y + half.y
		var high: float = half.y * 2.0
		var mine: Array = on.get(b, [])
		if high <= TownTuning.OBSTRUCTION_HIGH:
			if not mine.is_empty():
				wrong.append("%.1f m building %d has %d" % [high, b, mine.size()])
			continue
		tall += 1
		# THE LEVELS, top down: four corners each, the top flashing and rising off the roof, then steady and flashing by turns.
		var by_height: Dictionary = {}
		for light in mine:
			var key: int = roundi(float((light["at"] as Vector3).y) * 10.0)
			if not by_height.has(key):
				by_height[key] = []
			(by_height[key] as Array).append(light)
		var heights: Array = by_height.keys()
		heights.sort()
		heights.reverse()
		if heights.is_empty() or absf(float(heights[0]) / 10.0 - top) > 0.1:
			wrong.append("%.1f m building %d has no lights at its top (%.1f)" % [high, b, top])
			continue
		var last: float = top
		for level in range(heights.size()):
			var row: Array = by_height[heights[level]]
			var y: float = float(heights[level]) / 10.0
			var kinds: Array = row.map(func(l: Dictionary) -> int: return int(l["kind"]))
			var want: int = TownView.FLASHING_RED if level % 2 == 0 else TownView.STEADY_RED
			if row.size() != 4 or kinds.any(func(k: int) -> bool: return k != want):
				wrong.append("building %d level %.1f m has %d lights of kinds %s" % [b, y, row.size(), kinds])
			if last - y > TownTuning.OBSTRUCTION_LEVELS_APART + 0.1:
				wrong.append("building %d levels %.1f and %.1f are %.1f m apart" % [b, last, y, last - y])
			last = y
		var ground: float = top - high
		if last - ground > TownTuning.OBSTRUCTION_LEVELS_APART + 0.1:
			wrong.append("building %d lowest level %.1f m is %.1f m over its ground" % [b, last, last - ground])
	_check("obstruction_lights_stand_on_the_corners_of_every_building_over_%.0f_m_and_no_other%s" % [
			TownTuning.OBSTRUCTION_HIGH, suffix],
		tall > 0 and lights.size() > tall * 4 and astray.is_empty() and facing_in == 0 and wrong.is_empty(),
		"%d lights on %d of %d buildings; %d on no corner %s; %d facing in%s" % [lights.size(), tall, buildings.size(),
			astray.size(), astray.slice(0, 3), facing_in, "" if wrong.is_empty() else "; " + "; ".join(wrong.slice(0, 4))])
	_sections += 1


## ---- the reach -----------------------------------------------------------------------------------

func _every_kilometres_obstruction_lights_are_drawn_as_far_as_its_buildings(towns: TownView) -> void:
	# THE REDS' OWN REACH, FROM THEIR OWN FURTHEST LIGHT: a kilometre's obstruction batch drawn at least `FAR` beyond the
	# furthest light it holds, measured from the batch's middle. Their layer's box is the tall buildings' alone since step 3, so
	# "as far as its buildings' batch" -- whose box holds every building of the kilometre -- was a stand-in that read 24,122 m
	# against 24,559 m for lights drawn to their full reach (2026-09-15).
	var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
	var short: Array[String] = []
	var cells: Dictionary = {}
	for batch in towns.obstruction_batches():
		var cell: Vector2i = batch.get_meta(&"cell")
		cells[cell] = int(cells.get(cell, 0)) + 1
		var buffer: PackedFloat32Array = batch.get_meta(&"buffer", PackedFloat32Array())
		var furthest: float = 0.0
		for i in range(buffer.size() / stride):
			var o: int = i * stride
			furthest = maxf(furthest, Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11]).length())
		if buffer.is_empty() or batch.visibility_range_end < FAR + furthest - SAME:
			short.append("%s ends at %.0f, wants %.0f" % [cell, batch.visibility_range_end, FAR + furthest])
	var doubled: int = cells.values().filter(func(n: int) -> bool: return n > 1).size()
	_check("every_kilometres_obstruction_lights_are_one_batch_drawn_to_their_reach_from_their_furthest_light",
		not cells.is_empty() and short.is_empty() and doubled == 0,
		"%d obstruction batches, %d doubled%s" % [cells.size(), doubled, "" if short.is_empty() else ": %s" % [short.slice(0, 3)]])
	_sections += 1


## ---- the time of day -----------------------------------------------------------------------------

func _the_lamps_show_as_the_time_of_day_says(towns: TownView) -> void:
	var read: Array[float] = []
	for which in [DaylightTuning.When.DAY, DaylightTuning.When.EVENING, DaylightTuning.When.NIGHT]:
		var p: Dictionary = DaylightTuning.preset(which)
		towns.light_windows(float(p["windows_lit"]), float(p["window_glow"]))
		read.append(float(towns.lamp_material().get_shader_parameter("lamps")))
	# EVERY NUMBER THE LAMPS ARE DRAWN BY IS TOWNTUNING'S, read back off the material: a number left to the shader's default
	# looks exactly like tuning that makes no difference.
	var cycle: float = 60.0 / TownTuning.OBSTRUCTION_FLASHES_A_MINUTE
	var wanted: Dictionary = {"light_per_candela": TownTuning.LIGHT_PER_CANDELA, "point_pixels": TownTuning.FAR_LIGHT_PIXELS,
		"peak_most": TownTuning.LAMP_PEAK_MOST, "grow_most": TownTuning.LAMP_GROW_MOST, "seen_lux": TownTuning.LAMP_SEEN_LUX,
		"seen_band": TownTuning.LAMP_SEEN_BAND, "seen_peak": TownTuning.LAMP_SEEN_PEAK,
		"flash_on": TownTuning.OBSTRUCTION_FLASH_ON / cycle, "flash_ease": TownTuning.OBSTRUCTION_FLASH_EASE / cycle}
	var unhanded: Array[String] = []
	for uniform in wanted:
		var got: Variant = towns.lamp_material().get_shader_parameter(uniform)
		if got == null or not is_equal_approx(float(got), float(wanted[uniform])):
			unhanded.append("%s reads %s, not %s" % [uniform, got, wanted[uniform]])
	_check("every_number_the_lamps_are_drawn_by_is_town_tunings", unhanded.is_empty(),
		"%d numbers%s" % [wanted.size(), "" if unhanded.is_empty() else ": " + "; ".join(unhanded)])
	var evening: float = float(DaylightTuning.EVENING["windows_lit"]) / float(DaylightTuning.NIGHT["windows_lit"])
	var code: String = FileAccess.get_file_as_string("res://world/shaders/lamp.gdshaderinc")
	_check("the_lamps_are_dark_by_day_all_lit_at_night_and_at_evening_the_share_of_nights_windows",
		read[0] == 0.0 and absf(read[1] - evening) < 0.0001 and read[2] == 1.0 and code.contains("* lamps *"),
		"day %.3f, evening %.3f (wants %.3f), night %.3f; the shader %s the light by it" % [read[0], read[1], evening, read[2],
			"multiplies" if code.contains("* lamps *") else "does NOT multiply"])
	_sections += 1


## ---- together, from the tick ---------------------------------------------------------------------

func _a_town_flashes_together_from_the_tick(map: WorldMap) -> void:
	var wrong: Array[String] = []
	var first: Array = _towns(map)
	(first[0] as SceneryYard).fill_around(Vector3.ZERO)
	# NO LIGHT CARRIES A FLASH OF ITS OWN: every flashing light's numbers are the same as every other's.
	var flashing: Dictionary = {}
	for light in _lights(first[1]):
		if int(light["kind"]) == TownView.FLASHING_RED:
			flashing["%.3f %.3f" % [light["candela"], light["rise"]]] = true
	if flashing.size() > 2:
		wrong.append("flashing lights differ in %d ways: %s" % [flashing.size(), flashing.keys().slice(0, 4)])
	var code: String = FileAccess.get_file_as_string("res://world/shaders/lamp.gdshaderinc")
	var body: String = code.substr(code.find("uniform"))
	if body.contains("TIME") or not body.contains("lamp_flash(flash_phase)"):
		wrong.append("the shader does not flash on flash_phase alone")
	var second: Array = _towns(map)
	var dt: float = 1.0 / 60.0
	var ticks: int = 123457
	(first[1] as TownView).show_flash(ticks, dt)
	var a: float = float((first[1] as TownView).lamp_material().get_shader_parameter("flash_phase"))
	# THE SAME TICK, A MOMENT LATER BY THE CLOCK ON THE WALL -- a real delay: a timer runs on the game's clock, and under
	# --fixed-fps 120 its 0.37 s took 1 ms of the wall's, so the wall-clock mutant went red only on the half-cycle check.
	OS.delay_msec(370)
	(second[1] as TownView).show_flash(ticks, dt)
	var b: float = float((second[1] as TownView).lamp_material().get_shader_parameter("flash_phase"))
	var cycle_ticks: int = roundi(60.0 / TownTuning.OBSTRUCTION_FLASHES_A_MINUTE / dt)
	(second[1] as TownView).show_flash(ticks + cycle_ticks / 2, dt)
	var c: float = float((second[1] as TownView).lamp_material().get_shader_parameter("flash_phase"))
	if absf(a - b) > 0.000001:
		wrong.append("the same tick %.0f ms apart hands %.4f and %.4f" % [370.0, a, b])
	if absf(fposmod(c - b, 1.0) - 0.5) > 0.001:
		wrong.append("half a cycle's %d ticks later hands %.4f after %.4f" % [cycle_ticks / 2, c, b])
	_check("a_town_flashes_together_on_one_phase_from_the_tick_whenever_it_is_drawn", wrong.is_empty(),
		"; ".join(wrong) if not wrong.is_empty() else "%d kinds of flashing light; tick %d hands %.4f in both views, %.4f half a cycle on" % [
			flashing.size(), ticks, a, c])
	for pair in [first, second]:
		(pair[0] as Node).queue_free()
		(pair[1] as Node).queue_free()
	await get_tree().process_frame
	_sections += 1


## ---- off the frame -------------------------------------------------------------------------------

func _the_obstruction_lights_are_worked_off_the_frame(map: WorldMap) -> void:
	var pair: Array = _towns(map)
	var yard: SceneryYard = pair[0]
	var towns: TownView = pair[1]
	yard.fill_around(Vector3(0.0, 500.0, 60000.0))
	SceneryYard.work_delay_msec = WORK_MSEC
	var worst_usec: int = 0
	var frames: int = 0
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < WAIT_MSEC and (towns.building_batches().size() < yard.cells_of(TownView.BUILDINGS).size()
			or towns.obstruction_batches().size() < yard.cells_of(TownView.OBSTRUCTION).size()):
		var t: int = Time.get_ticks_usec()
		yard.watch(Vector3(0.0, 500.0, 0.0), FRAME)
		worst_usec = maxi(worst_usec, Time.get_ticks_usec() - t)
		await get_tree().process_frame
		frames += 1
	SceneryYard.work_delay_msec = 0
	_check("with_every_cells_work_slowed_to_50_ms_the_obstruction_lights_arrive_and_no_watch_waits_for_one",
		towns.building_batches().size() == yard.cells_of(TownView.BUILDINGS).size()
			and towns.obstruction_batches().size() == yard.cells_of(TownView.OBSTRUCTION).size() and not towns.obstruction_batches().is_empty()
			and worst_usec < WORK_MSEC * 1000,
		"%d of %d kilometres built, %d with obstruction lights, over %d frames; the worst watch %d us against one cell's work of %d us" % [
			towns.building_batches().size(), yard.cells_of(TownView.BUILDINGS).size(), towns.obstruction_batches().size(), frames,
			worst_usec, WORK_MSEC * 1000])
	yard.queue_free()
	towns.queue_free()
	await get_tree().process_frame
	_sections += 1


## ---- the switch ----------------------------------------------------------------------------------

## SWITCHED OFF, NOTHING MADE: towns drawn as the level draws them, every lit street in the paint, with the switch as
## `TownTuning` ships it. Off: no lamps', poles' or pools' batch and no pool or pole material -- and the paint, the far lights
## and the reds all built, so the zero is not an empty town. On: every lit kilometre has its three and both materials.
func _the_street_lights_are_made_only_when_switched_on(map: WorldMap, paint: Array[Dictionary]) -> void:
	var pair: Array = _towns(map, FAR, paint)
	var yard: SceneryYard = pair[0]
	var towns: TownView = pair[1]
	yard.fill_around(Vector3.ZERO)
	var on: bool = TownTuning.STREET_LIGHTS_ON
	var lit: int = _lit_cells(paint).size()
	var wanted: int = lit if on else 0
	var batches: Array[int] = [towns.street_lamp_batches().size(), towns.pole_batches().size(), towns.pool_batches().size()]
	var made: bool = towns.pool_material() != null or towns.get("_poles") != null
	var rest: Array[int] = [towns.paint_batches().size(), towns.light_batches().size(), towns.obstruction_batches().size()]
	_check("with_the_street_lights_switch_as_shipped_%s_%s" % ["on" if on else "off",
			"every_lit_kilometre_has_its_lamps_poles_and_pools" if on else "no_lamp_pole_or_pool_batch_or_material_is_made"],
		batches == [wanted, wanted, wanted] and made == on and lit > 0 and not rest.has(0),
		"STREET_LIGHTS_ON %s: %s lamps', poles' and pools' batches against %d each, of %d lit kilometres in the paint; pool or pole material made %s; %s paint, far lights' and obstruction batches built" % [
			on, batches, wanted, lit, made, rest])
	yard.queue_free()
	towns.queue_free()
	_sections += 1


## ---- street lights -------------------------------------------------------------------------------

## Every street lamp, as `{head, up, out, cell}` in the world, out of the very buffer its batch was handed: `up` is the basis's
## y column, the mounting height long.
static func _street_lamps(towns: TownView) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
	for batch in towns.street_lamp_batches():
		var buffer: PackedFloat32Array = batch.get_meta(&"buffer", PackedFloat32Array())
		for i in range(buffer.size() / stride):
			var o: int = i * stride
			out.append({"head": batch.position + Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11]),
				"up": Vector3(buffer[o + 1], buffer[o + 5], buffer[o + 9]), "out": Vector3(buffer[o + 2], buffer[o + 6], buffer[o + 10]),
				"kind": int(buffer[o + SceneryYard.TRANSFORM_FLOATS + 1]), "cell": batch.get_meta(&"cell")})
	return out


func _street_lights_stand_along_the_streets(suffix: String, streets: Array[Dictionary], buildings: Array[Dictionary],
		towns: TownView) -> void:
	var lamps: Array[Dictionary] = _street_lamps(towns)
	var rail: Array[Vector3] = Terrain.rail_points()
	var wrong: Array[String] = []
	var astray: int = 0
	var on_buildings: int = 0
	var on_rail: int = 0
	var in_carriageways: int = 0
	var feet: Array[Vector3] = []
	var lit_streets: Dictionary = {}
	for lamp in lamps:
		var up: Vector3 = lamp["up"]
		var out: Vector3 = lamp["out"]
		var foot: Vector3 = (lamp["head"] as Vector3) - out * TownTuning.STREET_LIGHT_ARM - up
		feet.append(foot)
		var found: int = -1
		for s in range(streets.size()):
			var centre: Vector3 = streets[s]["position"]
			var half: Vector3 = streets[s]["half_extents"]
			var along_x: bool = half.x >= half.z
			var wide: float = 2.0 * minf(half.x, half.z)
			var across: float = (foot.z - centre.z) if along_x else (foot.x - centre.x)
			var along: float = (foot.x - centre.x) if along_x else (foot.z - centre.z)
			if absf(absf(across) - (wide * 0.5 - TownTuning.STREET_LIGHT_KERB)) > SAME or absf(along) > maxf(half.x, half.z) + SAME \
					or absf(foot.y - (centre.y + half.y)) > SAME:
				continue
			found = s
			var high: float = TownView.street_light_height(wide)
			var aside := Vector3.BACK if along_x else Vector3.RIGHT
			if absf(up.length() - high) > SAME or absf(up.normalized().y - 1.0) > SAME \
					or out.distance_to(-aside * signf(across)) > SAME:
				wrong.append("lamp at %s is %.1f m tall or faces %s" % [foot.round(), up.length(), out])
			lit_streets[s] = true
			break
		if found < 0:
			astray += 1
			continue
		# NOT IN ANOTHER STREET'S CARRIAGEWAY: inside any other street's paint by more than half a metre.
		for s in range(streets.size()):
			if s == found:
				continue
			var c: Vector3 = streets[s]["position"]
			var h: Vector3 = streets[s]["half_extents"]
			if absf(foot.x - c.x) < h.x - 0.5 and absf(foot.z - c.z) < h.z - 0.5:
				in_carriageways += 1
				break
		for building in buildings:
			var c: Vector3 = building["position"]
			var h: Vector3 = building["half_extents"]
			if absf(foot.x - c.x) < h.x + 1.0 and absf(foot.z - c.z) < h.z + 1.0:
				on_buildings += 1
				break
		for i in range(rail.size()):
			var a := Vector2(rail[i].x, rail[i].z)
			var ab: Vector2 = Vector2(rail[(i + 1) % rail.size()].x, rail[(i + 1) % rail.size()].z) - a
			var p := Vector2(foot.x, foot.z)
			var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if p.distance_to(a + ab * t) < TownTuning.STREET_LIGHT_RAIL_CLEAR - SAME:
				on_rail += 1
				break
	# NO TWO POLES WITHIN 3 m: a corner lit twice.
	var doubled: int = 0
	var near: Dictionary = {}
	for foot in feet:
		var key := Vector2i(floori(foot.x / 3.0), floori(foot.z / 3.0))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for other in (near.get(key + Vector2i(dx, dz), []) as Array):
					if Vector2(foot.x, foot.z).distance_to(Vector2((other as Vector3).x, (other as Vector3).z)) < 3.0:
						doubled += 1
		if not near.has(key):
			near[key] = []
		(near[key] as Array).append(foot)
	# THE SPACING ALONG EVERY KERB, whoever's pole it is: every foot within 1.5 m of a kerb line and along the street, in order,
	# and no gap between neighbours outside three quarters to five quarters of its height's spacing -- except where the rail
	# took a pole out.
	var gaps: Array[float] = []
	for s in range(streets.size()):
		var centre: Vector3 = streets[s]["position"]
		var half: Vector3 = streets[s]["half_extents"]
		var along_x: bool = half.x >= half.z
		var wide: float = 2.0 * minf(half.x, half.z)
		var spacing: float = TownView.street_light_height(wide) * TownTuning.STREET_LIGHT_SPACING_PER_HEIGHT
		for side in [1.0, -1.0]:
			var row: Array[float] = []
			for foot in feet:
				var across: float = (foot.z - centre.z) if along_x else (foot.x - centre.x)
				var along: float = (foot.x - centre.x) if along_x else (foot.z - centre.z)
				if absf(across - side * (wide * 0.5 - TownTuning.STREET_LIGHT_KERB)) < 1.5 and absf(along) <= maxf(half.x, half.z) \
						and absf(foot.y - (centre.y + half.y)) < SAME:
					row.append(along)
			row.sort()
			for i in range(1, row.size()):
				var gap: float = row[i] - row[i - 1]
				var mid := Vector2(centre.x, centre.z) + (Vector2((row[i] + row[i - 1]) * 0.5, side * wide * 0.5) if along_x
					else Vector2(side * wide * 0.5, (row[i] + row[i - 1]) * 0.5))
				if _rail_within(rail, mid, gap):
					continue
				gaps.append(gap)
				if gap > spacing * 1.25 or gap < spacing * 0.75:
					wrong.append("a gap of %.1f m on street %d's %+d kerb against a spacing of %.1f" % [gap, s, int(side), spacing])
	gaps.sort()
	var unlit: int = 0
	for s in range(streets.size()):
		if not lit_streets.has(s):
			unlit += 1
	_check("street_lights_stand_at_the_kerbs_of_the_town_streets_at_their_spacing_clear_of_junctions_buildings_and_rail%s" % suffix,
		lamps.size() > 2000 and astray == 0 and on_buildings == 0 and on_rail == 0 and in_carriageways == 0 and doubled == 0
			and wrong.is_empty() and unlit == 0,
		"%d lamps on %d of %d streets; %d on no street, %d by a building, %d by the rail, %d in a carriageway, %d doubled; gaps along the kerbs %.1f to %.1f m%s" % [
			lamps.size(), lit_streets.size(), streets.size(), astray, on_buildings, on_rail, in_carriageways, doubled,
			gaps.front() if not gaps.is_empty() else 0.0, gaps.back() if not gaps.is_empty() else 0.0,
			"" if wrong.is_empty() else "; " + "; ".join(wrong.slice(0, 4))])
	_sections += 1


## Whether the railway passes within `reach` of `at`, on the ground.
static func _rail_within(rail: Array[Vector3], at: Vector2, reach: float) -> bool:
	for i in range(rail.size()):
		var a := Vector2(rail[i].x, rail[i].z)
		var ab: Vector2 = Vector2(rail[(i + 1) % rail.size()].x, rail[(i + 1) % rail.size()].z) - a
		var t: float = clampf((at - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if at.distance_to(a + ab * t) < reach:
			return true
	return false


## ---- the pools ------------------------------------------------------------------------------------

func _the_pools_take_their_numbers_and_hand_their_light_over_by_one_function(towns: TownView) -> void:
	var wrong: Array[String] = []
	var pools: Dictionary = {"light_per_candela": TownTuning.LIGHT_PER_CANDELA, "street_candela": TownTuning.STREET_LIGHT_CANDELA,
		"road_reflectance": TownTuning.ROAD_REFLECTANCE, "pool_reach": TownTuning.POOL_REACH, "pool_to": TownTuning.POOL_TO,
		"pool_lift": TownTuning.POOL_LIFT, "pool_pull": TownTuning.POOL_PULL, "night_adaptation": TownTuning.night_adaptation()}
	var lamps: Dictionary = {"street_side_share": TownTuning.STREET_LIGHT_SIDE_SHARE,
		"road_reflectance": TownTuning.ROAD_REFLECTANCE, "pool_to": TownTuning.POOL_TO, "night_adaptation": TownTuning.night_adaptation()}
	for pair in [[towns.pool_material(), pools], [towns.lamp_material(), lamps]]:
		for uniform in pair[1]:
			var got: Variant = (pair[0] as ShaderMaterial).get_shader_parameter(uniform) if pair[0] != null else null
			if got == null or not is_equal_approx(float(got), float(pair[1][uniform])):
				wrong.append("%s reads %s, not %s" % [uniform, got, pair[1][uniform]])
	for material in [towns.pool_material(), towns.lamp_material()]:
		var colour: Variant = material.get_shader_parameter("street_colour") if material != null else null
		if colour == null or not (colour as Color).is_equal_approx(TownTuning.STREET_LIGHT_COLOUR):
			wrong.append("street_colour reads %s" % colour)
	# ONE BAND: the pool gives up exactly the share the lamp's point takes, from one function, and nothing works it out beside it.
	var lamp_code: String = FileAccess.get_file_as_string("res://world/shaders/lamp.gdshaderinc")
	var pool_code: String = FileAccess.get_file_as_string("res://world/shaders/lamp_pool.gdshader")
	var band: String = FileAccess.get_file_as_string("res://world/shaders/lamp_pool.gdshaderinc")
	if lamp_code.count("lamp_pool_far_share(away, pool_to)") != 1:
		wrong.append("the lamp does not take lamp_pool_far_share(away, pool_to) once")
	if pool_code.count("(1.0 - lamp_pool_far_share(away, pool_to))") != 1:
		wrong.append("the pool does not take 1 - lamp_pool_far_share(away, pool_to) once")
	for text in [lamp_code, pool_code]:
		if text.contains("pool_to *"):
			wrong.append("a shader works the band out beside the function")
	if band.count("smoothstep(") != 1:
		wrong.append("the band is not one smoothstep")
	# AND THE POOLS BY THE TIME OF DAY, as the lamps.
	var read: Array[float] = []
	for which in [DaylightTuning.When.DAY, DaylightTuning.When.NIGHT]:
		var p: Dictionary = DaylightTuning.preset(which)
		towns.light_windows(float(p["windows_lit"]), float(p["window_glow"]))
		read.append(float(towns.pool_material().get_shader_parameter("lamps")))
	if read != [0.0, 1.0]:
		wrong.append("the pools read %s by day and at night" % [read])
	_check("the_pools_take_town_tunings_numbers_the_time_of_day_and_hand_their_light_to_the_lamps_by_one_function",
		wrong.is_empty(), "; ".join(wrong) if not wrong.is_empty() else "%d numbers; one band in both shaders" % [pools.size() + lamps.size() + 1])
	_sections += 1


## ---- off the frame, and the budget ----------------------------------------------------------------

## The cells of the paint with a lit street in them, and those streets, as `TownView.draw_towns` files them.
static func _lit_cells(paint: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for mark in paint:
		if not mark.has("block"):
			continue
		var cell: Vector2i = WorldMap.cell_of(mark["position"])
		if not out.has(cell):
			out[cell] = []
		(out[cell] as Array).append(mark)
	return out


func _the_street_lights_are_worked_off_the_frame(map: WorldMap, paint: Array[Dictionary]) -> void:
	var pair: Array = _towns(map, FAR, paint)
	var yard: SceneryYard = pair[0]
	var towns: TownView = pair[1]
	var wanted: int = _lit_cells(paint).size()
	yard.fill_around(Vector3(0.0, 500.0, 60000.0))
	SceneryYard.work_delay_msec = WORK_MSEC
	var worst_usec: int = 0
	var frames: int = 0
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < WAIT_MSEC and towns.street_lamp_batches().size() < wanted:
		var t: int = Time.get_ticks_usec()
		yard.watch(Vector3(0.0, 500.0, 0.0), FRAME)
		worst_usec = maxi(worst_usec, Time.get_ticks_usec() - t)
		await get_tree().process_frame
		frames += 1
	SceneryYard.work_delay_msec = 0
	var three: bool = towns.pole_batches().size() == wanted and towns.pool_batches().size() == wanted
	_check("with_every_cells_work_slowed_to_50_ms_the_street_lights_arrive_with_their_poles_and_pools_and_no_watch_waits",
		towns.street_lamp_batches().size() == wanted and three and wanted > 0 and worst_usec < WORK_MSEC * 1000,
		"%d of %d lit kilometres, %d poles' and %d pools' batches, over %d frames; the worst watch %d us against one cell's work of %d us" % [
			towns.street_lamp_batches().size(), wanted, towns.pole_batches().size(), towns.pool_batches().size(), frames,
			worst_usec, WORK_MSEC * 1000])
	yard.queue_free()
	towns.queue_free()
	await get_tree().process_frame
	_sections += 1


func _the_street_lights_fit_their_budget(map: WorldMap, paint: Array[Dictionary]) -> void:
	var rail := PackedVector3Array(Terrain.rail_points())
	var stride: int = SceneryYard.TRANSFORM_FLOATS + SceneryYard.EXTRA_FLOATS
	var total: int = 0
	var densest: int = 0
	var slowest_msec: float = 0.0
	var rows: PackedStringArray = []
	var lit: Dictionary = _lit_cells(paint)
	for cell in lit:
		var done: Dictionary = {}
		var msec: float = INF
		for attempt in range(BUDGET_TRIES):
			var began: int = Time.get_ticks_usec()
			done = TownView.street_lights_buffer(lit[cell], Vector3.ZERO, rail)
			msec = minf(msec, float(Time.get_ticks_usec() - began) / 1000.0)
		total += int(done["count"])
		densest = maxi(densest, int(done["count"]))
		slowest_msec = maxf(slowest_msec, msec)
		rows.append("%s: %d streets, %d lamps, %.0f KB, %.2f ms fastest of %d" % [cell, (lit[cell] as Array).size(), done["count"],
			float((done["buffer"] as PackedFloat32Array).size() * 4) / 1024.0, msec, BUDGET_TRIES])
	print("[night_lights] street lights by kilometre: %s" % "; ".join(rows))
	var island_mb: float = float(total * stride * 4) / 1048576.0
	# AND WHAT THE MAIN THREAD PAYS TO PUT THE DENSEST KILOMETRE ON NODES: its three batches made and added to the tree, the
	# first time (cold) and the median of the next five (warm), against BUILD_MOST_USEC (asked for on 2026-09-15, when the
	# worst watch read 1.5 ms: that watch is the yard's whole 2 ms budget, lit or not, and this is the lamps' own share).
	var densest_cell: Vector2i = Vector2i.ZERO
	for cell in lit:
		if (lit[cell] as Array).size() > (lit.get(densest_cell, []) as Array).size():
			densest_cell = cell
	var hull := AABB()
	for mark in lit[densest_cell]:
		var one := AABB((mark["position"] as Vector3) - (mark["half_extents"] as Vector3), (mark["half_extents"] as Vector3) * 2.0)
		hull = one if hull.size == Vector3.ZERO else hull.merge(one)
	var pair: Array = _towns(map, FAR, paint)
	var towns: TownView = pair[1]
	var dense: Dictionary = TownView.street_lights_buffer(lit[densest_cell], hull.get_center(), rail)
	var point := QuadMesh.new()
	var pole: Mesh = TownView.pole_mesh()
	var pool := PlaneMesh.new()
	var builds: Array[int] = []
	for round_ in range(6):
		var began: int = Time.get_ticks_usec()
		var nodes: Array[Node3D] = towns.call("_street_light_batches", dense, hull, point, pole, pool, FAR, densest_cell)
		for node in nodes:
			towns.add_child(node)
		builds.append(Time.get_ticks_usec() - began)
		for node in nodes:
			node.queue_free()
		await get_tree().process_frame
	var warm: Array[int] = builds.slice(1)
	warm.sort()
	print("[night_lights] the densest kilometre %s, %d lamps, put on nodes in %s us" % [densest_cell, dense["count"], builds])
	(pair[0] as Node).queue_free()
	towns.queue_free()
	_check("and_the_densest_kilometres_street_lights_go_on_nodes_warm_under_%d_us" % BUILD_MOST_USEC, warm[warm.size() / 2] < BUILD_MOST_USEC,
		"%d lamps: cold %d us, warm median %d us (%s)" % [dense["count"], builds[0], warm[warm.size() / 2], warm])
	_check("every_kilometres_street_lights_are_worked_out_inside_the_budget_and_the_72_km_world_holds_them_in_it",
		total > 0 and slowest_msec < CELL_BUILD_MSEC and island_mb * TILED < TILED_MB,
		"%d lamps on the island in %d kilometres, the densest %d; %.2f MB of instance data, %.1f MB tiled %d times (under %.0f); the slowest kilometre %.2f ms (under %.0f)" % [
			total, rows.size(), densest, island_mb, island_mb * TILED, TILED, TILED_MB, slowest_msec, CELL_BUILD_MSEC])
	_sections += 1


## EVERY KILOMETRE'S OBSTRUCTION LIGHTS WORKED OUT INSIDE THE BUDGET: each kilometre of buildings, `BUDGET_TRIES` timings of
## `TownView.obstruction_buffer` and the fastest kept, under `CELL_BUILD_MSEC`. Printed for the kilometres that have any.
func _the_obstruction_lights_fit_their_budget(map: WorldMap) -> void:
	var total: int = 0
	var slowest_msec: float = 0.0
	var rows: PackedStringArray = []
	for cell in map.cells():
		var mine: Array[Dictionary] = _buildings_of(map.boxes_in(cell))
		if mine.is_empty():
			continue
		var done: Dictionary = {}
		var msec: float = INF
		for attempt in range(BUDGET_TRIES):
			var began: int = Time.get_ticks_usec()
			done = TownView.obstruction_buffer(mine, Vector3.ZERO)
			msec = minf(msec, float(Time.get_ticks_usec() - began) / 1000.0)
		total += int(done["count"])
		slowest_msec = maxf(slowest_msec, msec)
		if int(done["count"]) > 0:
			rows.append("%s: %d buildings, %d lights, %.3f ms fastest of %d" % [cell, mine.size(), done["count"], msec, BUDGET_TRIES])
	print("[night_lights] obstruction lights by kilometre: %s" % "; ".join(rows))
	_check("every_kilometres_obstruction_lights_are_worked_out_inside_the_budget",
		total > 0 and slowest_msec < CELL_BUILD_MSEC,
		"%d lights in %d kilometres; the slowest kilometre %.3f ms (under %.0f), fastest of %d" % [total, rows.size(), slowest_msec,
			CELL_BUILD_MSEC, BUDGET_TRIES])
	_sections += 1


## ---- the far handover, flown ---------------------------------------------------------------------

## THE REDS OUTREACH THEIR WALLS: towns drawn with the buildings at FLOWN_REACH and the lamps at FAR, flown 14 km out along x
## and back, eight frames a step with eight frames' time. Every step: every tall cell whose bounds come within FAR - the let-go
## margin of the eye on the ground has its obstruction batch (no hole), no cell has two (no double), and at some point a tall
## cell's reds are built while its buildings are not -- the thing the separate layer is for.
func _flown_out_and_back_the_reds_stay_while_their_walls_go(map: WorldMap) -> void:
	var pair: Array = _towns(map, FLOWN_REACH, [] as Array[Dictionary], FAR)
	var yard: SceneryYard = pair[0]
	var towns: TownView = pair[1]
	var eye := Vector3(0.0, 500.0, 0.0)
	yard.fill_around(eye)
	var holes: int = 0
	var doubles: int = 0
	var reds_without_walls: int = 0
	var let_go_before: int = yard.let_go
	var frames: int = 0
	var began: int = Time.get_ticks_msec()
	for leg in [Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0)]:
		var travelled: float = 0.0
		while travelled < 14000.0:
			eye += (leg as Vector3) * PLANE * FRAME * 8.0
			travelled += PLANE * FRAME * 8.0
			yard.watch(eye, FRAME * 8.0)
			if frames % 8 == 0:
				yard.catch_up()
			frames += 1
			var walls: Dictionary = {}
			for batch in towns.building_batches():
				walls[batch.get_meta(&"cell")] = true
			# NO HOLE: every tall kilometre whose square is within the reds' reach, less a kilometre for the queue, is built.
			for cell in yard.cells_of(TownView.OBSTRUCTION):
				var square: Rect2 = WorldMap.square_of(cell)
				var nearest := Vector2(clampf(eye.x, square.position.x, square.end.x), clampf(eye.z, square.position.y, square.end.y))
				if nearest.distance_to(Vector2(eye.x, eye.z)) < FAR - WorldMap.CELL and not yard.built_cells(TownView.OBSTRUCTION).has(cell):
					holes += 1
			var reds: Dictionary = {}
			for batch in towns.obstruction_batches():
				var cell: Vector2i = batch.get_meta(&"cell")
				if reds.has(cell):
					doubles += 1
				reds[cell] = true
				if not walls.has(cell):
					reds_without_walls += 1
			await get_tree().process_frame
	# AND AT HOME AGAIN, SETTLED, every tall kilometre is built.
	for settle in range(120):
		yard.watch(eye, 0.0)
		yard.catch_up()
	var missing: Array[Vector2i] = []
	for cell in yard.cells_of(TownView.OBSTRUCTION):
		if not yard.built_cells(TownView.OBSTRUCTION).has(cell):
			missing.append(cell)
	_check("flown_14_km_out_and_back_a_towers_reds_stay_while_its_walls_are_let_go_and_none_is_doubled",
		holes == 0 and doubles == 0 and reds_without_walls > 0 and missing.is_empty() and yard.let_go > let_go_before,
		"%d frames in %d ms; %d steps with reds on let-go walls; %d holes, %d doubles; %d tall kilometres not built at home" % [frames,
			Time.get_ticks_msec() - began, reds_without_walls, holes, doubles, missing.size()])
	yard.queue_free()
	towns.queue_free()
	await get_tree().process_frame
	_sections += 1


## THE STREETS' LIGHTS ARRIVE AND LEAVE WITH THEIR PAINT: the roads at FLOWN_REACH, flown 14 km out and back. Every step, every
## built paint kilometre with lit streets has one lamps', one poles' and one pools' batch; none of those without its paint; and
## the flight really streamed (let go and built again).
func _flown_out_and_back_every_lit_kilometre_has_its_lamps_poles_and_pools_once(map: WorldMap, paint: Array[Dictionary]) -> void:
	var pair: Array = _towns(map, FLOWN_REACH, paint)
	var yard: SceneryYard = pair[0]
	var towns: TownView = pair[1]
	var lit: Dictionary = _lit_cells(paint)
	var eye := Vector3(0.0, 500.0, 0.0)
	yard.fill_around(eye)
	var holes: int = 0
	var doubles: int = 0
	var orphans: int = 0
	var let_go_before: int = yard.let_go
	var built_before: int = yard.built
	var frames: int = 0
	for leg in [Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0)]:
		var travelled: float = 0.0
		while travelled < 14000.0:
			eye += (leg as Vector3) * PLANE * FRAME * 8.0
			travelled += PLANE * FRAME * 8.0
			yard.watch(eye, FRAME * 8.0)
			if frames % 8 == 0:
				yard.catch_up()
			frames += 1
			var paint_cells: Dictionary = {}
			for batch in towns.paint_batches():
				paint_cells[batch.get_meta(&"cell")] = true
			for kind in [towns.street_lamp_batches(), towns.pole_batches(), towns.pool_batches()]:
				var seen: Dictionary = {}
				for batch in kind:
					var cell: Vector2i = batch.get_meta(&"cell")
					if seen.has(cell):
						doubles += 1
					seen[cell] = true
					if not paint_cells.has(cell):
						orphans += 1
				for cell in paint_cells:
					if lit.has(cell) and not seen.has(cell):
						holes += 1
			await get_tree().process_frame
	_check("flown_14_km_out_and_back_every_lit_kilometre_has_its_lamps_poles_and_pools_once",
		holes == 0 and doubles == 0 and orphans == 0 and yard.let_go > let_go_before and yard.built > built_before,
		"%d frames, %d let go and %d built on the way; %d holes, %d doubles, %d lights with no paint" % [frames,
			yard.let_go - let_go_before, yard.built - built_before, holes, doubles, orphans])
	yard.queue_free()
	towns.queue_free()
	await get_tree().process_frame
	_sections += 1


func _finish() -> void:
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
