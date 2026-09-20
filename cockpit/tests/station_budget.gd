extends Node
## Headless: A MANNED CRAFT'S STATIONS ARE BUILT OVER FRAMES IN A FLIGHT, THIS MACHINE'S SEAT FIRST.
##
##   Godot --headless --xr-mode off --path cockpit res://tests/station_budget.tscn
##
## `VehicleView.man` builds a station for every seat of a manned craft. A station is about 18 ms, and a Chinook fitted
## with sixty-four seats was 1.15 s in one frame when the first person sat down (learnings/2026-09-18-seats.md). A
## frame that long is a machine that sends no ACKs for a second, and ashiato-sync 8fa08cf never recovers an entity whose
## baseline goes that stale: lane/lightgun's staged craft froze for good on the machine that stalled (S-12,
## ErikGoldman/ashiato-sync#12). So in a flight `station_build_budget_ms` is `VehicleView.GAME_BUILD_MS`.
##
## WHAT IS REAL: the game's own vehicle scene, set up for the kind, fitted with sixty-four seats through `Sim.fit_seats`,
## and `man` called once a frame with a crew as sky.gd calls it. Every call is timed.
##
## WHAT IT HOLDS:
##   * with no budget -- the editor's and every suite's -- one call builds all sixty-four, as before (the control, and
##     the "before" number);
##   * with the game's budget, no call is longer than the budget plus the slowest single station, this machine's own seat
##     is built by the first call, the other seat somebody is in by the second, and every seat is built in the end;
##   * the flight level sets the budget on every view it makes.
##
## Read RESULT=, not the exit code.

const KIND: int = Sim.Kind.CHINOOK
const MANY: int = 64
## This machine's seat, and another seat somebody is in: deliberately not the first two, so the order is what is tested.
const MINE: int = 37
const OTHER: int = 50

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[station_budget] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld missing")
		_finish()
		return
	var fitted: Dictionary = Sim.fit_seats(KIND, _cabin(MANY))
	_check("sixty_four_seats_are_fitted", int(fitted.get("fitted", 0)) == MANY, str(fitted))

	# THE CONTROL: no budget, one call, every station.
	var whole: VehicleView = _view()
	var began: int = Time.get_ticks_usec()
	whole.man([MINE, OTHER], MINE)
	var whole_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	_check("with_no_budget_one_call_builds_every_station", whole.stations().size() == MANY,
		"%d stations in one call of %.1f ms" % [whole.stations().size(), whole_ms])
	whole.queue_free()
	await get_tree().process_frame

	# THE GAME'S BUDGET, one call a frame.
	var spread: VehicleView = _view()
	spread.station_build_budget_ms = VehicleView.GAME_BUILD_MS
	var calls: PackedFloat64Array = []
	var built_after: PackedInt32Array = []
	var mine_first := false
	var other_by_second := false
	var slowest_single: float = 0.0
	for frame in range(MANY * 2):
		var before: int = spread.stations().size()
		began = Time.get_ticks_usec()
		spread.man([MINE, OTHER], MINE)
		var ms: float = float(Time.get_ticks_usec() - began) / 1000.0
		calls.append(ms)
		var now: int = spread.stations().size()
		built_after.append(now)
		if now - before == 1:
			slowest_single = maxf(slowest_single, ms)
		if frame == 0:
			mine_first = _has_station(spread, MINE)
		if frame == 1:
			other_by_second = _has_station(spread, OTHER)
		await get_tree().process_frame
		if now >= MANY:
			break
	var worst: float = 0.0
	for ms in calls:
		worst = maxf(worst, ms)
	print("[station_budget] %d stations: %.1f ms in one call before; with a %.1f ms budget, %d calls, worst %.1f ms, slowest single station %.1f ms"
		% [MANY, whole_ms, VehicleView.GAME_BUILD_MS, calls.size(), worst, slowest_single])
	_check("this_machines_seat_is_built_first", mine_first, "seat %d after the first call: %s" % [MINE, mine_first])
	_check("the_other_occupied_seat_by_the_second", other_by_second, "seat %d after two calls: %s" % [OTHER, other_by_second])
	_check("every_seat_is_built_in_the_end", spread.stations().size() == MANY,
		"%d of %d after %d calls" % [spread.stations().size(), MANY, calls.size()])
	_check("no_call_is_longer_than_the_budget_and_one_station",
		worst <= VehicleView.GAME_BUILD_MS + slowest_single + 1.0,
		"worst %.1f ms against %.1f + %.1f + 1" % [worst, VehicleView.GAME_BUILD_MS, slowest_single])
	_check("and_far_shorter_than_building_them_all", worst < whole_ms / 4.0,
		"worst %.1f ms against %.1f ms in one call" % [worst, whole_ms])
	spread.queue_free()
	Sim.fit_seats(KIND, [])

	# THE FLIGHT LEVEL SETS IT on every view it makes, read off its source rather than asserted by hand here.
	var sky_source: String = FileAccess.get_file_as_string("res://world/sky.gd")
	_check("the_flight_level_sets_the_budget_on_its_views",
		sky_source.contains("view.station_build_budget_ms = VehicleView.GAME_BUILD_MS"), "world/sky.gd, _view_for")
	_finish()


func _view() -> VehicleView:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(0, KIND)
	return view


func _has_station(view: VehicleView, seat: int) -> bool:
	return (view.get("_stations") as Dictionary).has(seat)


## FOUR ABREAST DOWN THE CABIN, the pilot first, as tests/many_seats_shot.gd fits them.
static func _cabin(count: int) -> Array:
	var seats: Array = []
	for seat in range(count):
		seats.append({"position": Vector3(-1.2 + 0.8 * float(seat % 4), -0.4, -4.0 + 0.7 * float(seat / 4)),
			"yaw": 0.0, "station": "pilot" if seat == 0 else "operator"})
	return seats


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
