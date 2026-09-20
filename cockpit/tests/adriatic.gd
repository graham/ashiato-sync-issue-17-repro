extends Node
## Headless: does the Adriatic level stand -- a small home island in a lot of sea, other islands and sea stacks laid as
## mountain ranges on the alpine world, a Savoia afloat in the cove?
##
##   Godot --headless --path cockpit res://tests/adriatic.tscn
##
## THE LEVEL IS ASKED FOR AS A PLAYER ASKS: `Net.choose_level`, then the real flight level. Every check is against
## something the level did not compute itself. The pictures are `tests/adriatic_shot.gd`.
##
## Read RESULT=, not the exit code.

const LEVEL: String = "adriatic"
const PATIENCE: int = 3000
const TICKS: float = 32.0
## A spur's foot stands out at most this many feet (range_core.hpp); a fly-through gap is the space between two such.
const FOOT_REACH: float = 1.175
## How far a stack or island must rise above the generated ground under it, metres: these are Mediterranean, not Alps.
const ROCK_RELIEF: float = 40.0
## The fly-throughs this file laid, named, as pairs of range salts; the gap is computed from the file, never typed again.
const GAPS: Array[Dictionary] = [
	{"name": "the needle channel", "salts": [5310, 5311], "least": 5.0, "most": 22.0},
	{"name": "the twin fangs", "salts": [5312, 5313], "least": 5.0, "most": 22.0},
	{"name": "the sisters' tight gap", "salts": [5314, 5315], "least": 5.0, "most": 22.0},
	{"name": "the sisters' wide gap", "salts": [5315, 5316], "least": 5.0, "most": 22.0},
]

var _failures: PackedStringArray = []
var _sections: int = 0
var _finished: bool = false
var _level: FlightLevel = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[adriatic] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var can: bool = ClassDB.class_exists("CockpitWorld") and ClassDB.class_exists("GroundField")
	_check("the_extension_has_the_ground_and_the_world", can, "engine %s, double=%s" % [
		Engine.get_version_info()["string"], OS.has_feature("double")])
	if not can:
		_finish()
		return
	_the_level_is_on_the_desk()
	Net.session_ended.connect(_on_a_session_ended)
	var chosen: String = Net.choose_level(LEVEL)
	_check("the_adriatic_can_be_chosen", chosen == "", "'%s'" % chosen)
	if chosen != "":
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	var frames: int = 0
	while frames < PATIENCE and not _finished and not (_level.ground_built_msec >= 0.0 and Sim.is_ready):
		await get_tree().process_frame
		frames += 1
	if _finished:
		return
	Net.session_ended.disconnect(_on_a_session_ended)
	var field: Object = Terrain.standing_on()
	_check("the_adriatic_stands_and_comes_up", _level.ground_built_msec >= 0.0 and Sim.is_ready and field != null,
		"after %d frames: the ground stood in both worlds in %.0f ms" % [frames, _level.ground_built_msec])
	if field == null or Sim.server == null or Sim.client == null:
		_finish()
		return
	for i in range(30):
		await get_tree().process_frame
	_there_is_a_sea(field)
	_the_spawn_is_on_the_water(field)
	_the_islands_and_stacks_stand(field)
	_the_gaps_are_wide_enough_to_fly()
	_the_arrival_is_a_savoia_afloat()
	_the_woods_that_grew()
	var sections: int = _sections_written()
	_check("every_section_of_the_suite_ran", _sections == sections, "%d of %d" % [_sections, sections])
	_finish()


func _sections_written() -> int:
	var written: int = 0
	for line in (get_script() as GDScript).source_code.split("\n"):
		if line.strip_edges() == "_sections += 1":
			written += 1
	return written


func _the_level_is_on_the_desk() -> void:
	var found: LevelChart = null
	for chart in ChartDrawer.charts():
		if (chart as LevelChart).id == LEVEL:
			found = chart
	var kinds: Array[int] = []
	if found != null:
		kinds.assign(found.craft)
	_check("the_drawer_lists_the_adriatic_usable", found != null and found.usable()
		and found.world == "alpine" and found.arrive_kind == Sim.Kind.SAVOIA and kinds.has(Sim.Kind.SAVOIA)
		and int(found.ground.get("coast", 0)) == 16 and int(found.ground.get("seed", -1)) == 80
		and found.mountains.size() >= 8 and found.refusal == "",
		"%s" % ("not listed" if found == null else "%s: world %s, arrive %s, craft %s, coast %s, seed %s, %d ranges, refusal '%s'" % [
			found.name, found.world, found.arrive_kind, found.craft, found.ground.get("coast", "?"),
			found.ground.get("seed", "?"), found.mountains.size(), found.refusal]))
	_sections += 1


func _there_is_a_sea(field: Object) -> void:
	var coast: Vector3 = Terrain.open_sea_near(Vector3.ZERO, 1.0)
	var sheet := _level.get_node_or_null("Sea") as Node3D
	var drawn: bool = (sheet != null and sheet.visible) or (_level.swell != null and _level.swell.visible)
	_check("there_is_a_sea_to_take_off_from", Terrain.has_sea() and coast != Vector3.INF,
		"has_sea %s, open sea %s, a sea sheet drawn %s; tuning %s" % [
			Terrain.has_sea(), coast, drawn, field.call("tuning")])
	_sections += 1


func _the_spawn_is_on_the_water(field: Object) -> void:
	var chart: LevelChart = _level.level
	var at: Vector3 = chart.spawn_at
	var ground_ticks: int = int(field.call("height_ticks_at", roundi(at.x), roundi(at.z)))
	var water_ticks: int = int(field.call("water_ticks_at", roundi(at.x), roundi(at.z)))
	var wet: bool = water_ticks == 0 and ground_ticks < 0
	_check("the_spawn_stands_on_the_water_in_the_cove", wet and chart.spawn_at.y < Sim.ARRIVE_FLYING_OVER
		and chart.arrive_kind == Sim.Kind.SAVOIA,
		"at (%.0f, %.0f): ground %.1f m, water ticks %d, spawn y %.1f, arrive %s" % [
			at.x, at.z, float(ground_ticks) / TICKS, water_ticks, chart.spawn_at.y, Sim.kind_name(chart.arrive_kind)])
	_sections += 1


func _the_islands_and_stacks_stand(field: Object) -> void:
	var rock: Object = Terrain.mountains()
	var words: PackedStringArray = []
	var standing: int = 0
	var above_sea: int = 0
	var ranges: Array[Dictionary] = _level.level.mountains
	for range in ranges:
		var points: PackedInt32Array = range["points"]
		var peak := Vector3.ZERO
		var best: float = -INF
		# THE CREST OF THIS RANGE, not the neighbour's: an 8 m ring round each control point is
		# this range's rock. A box over the whole foot catches a neighbour in a tight pair.
		if rock != null:
			for k in range(0, points.size(), 4):
				var cx: float = float(points[k])
				var cz: float = float(points[k + 1])
				var d: float = -32.0
				while d <= 32.0:
					var e: float = -32.0
					while e <= 32.0:
						var h: float = float(rock.call("surface_at", cx + d, cz + e))
						if h > best:
							best = h
							peak = Vector3(cx + d, h, cz + e)
						e += 8.0
					d += 8.0
		var ground: float = float(int(field.call("height_ticks_at", roundi(peak.x), roundi(peak.z)))) / TICKS
		var below: float = float(Sim.server.first_solid_below(peak + Vector3.UP * 50.0, 200.0))
		var hit: float = peak.y + 50.0 - below if below >= 0.0 else -INF
		var stands: bool = best - ground >= ROCK_RELIEF and absf(hit - best) < 8.0
		standing += 1 if stands else 0
		above_sea += 1 if best >= 40.0 else 0
		words.append("salt %d: top %.0f m at (%.0f, %.0f), %.0f m over the ground, ray %.1f" % [
			int(range["salt"]), best, peak.x, peak.z, best - ground, hit])
	_check("every_island_and_stack_stands_in_the_rock_and_the_collision",
		rock != null and ranges.size() >= 8 and standing == ranges.size() and above_sea == ranges.size(),
		"%d of %d standing, %d above the sea; %s" % [standing, ranges.size(), above_sea, "; ".join(words)])
	_sections += 1


func _the_gaps_are_wide_enough_to_fly() -> void:
	var by_salt: Dictionary = {}
	for range in _level.level.mountains:
		by_salt[int(range["salt"])] = range
	var words: PackedStringArray = []
	var right: int = 0
	for gap in GAPS:
		var a: Dictionary = by_salt.get(int(gap["salts"][0]), {})
		var b: Dictionary = by_salt.get(int(gap["salts"][1]), {})
		if a.is_empty() or b.is_empty():
			words.append("%s: missing a range" % gap["name"])
			continue
		var pa: PackedInt32Array = a["points"]
		var pb: PackedInt32Array = b["points"]
		var ax := Vector2(float(pa[0]), float(pa[1]))
		var bx := Vector2(float(pb[0]), float(pb[1]))
		var width: float = ax.distance_to(bx) - FOOT_REACH * float(pa[3]) - FOOT_REACH * float(pb[3])
		var ok: bool = width >= float(gap["least"]) and width <= float(gap["most"])
		right += 1 if ok else 0
		words.append("%s: %.1f m (centres %.0f m apart)" % [gap["name"], width, ax.distance_to(bx)])
	_check("the_fly_through_gaps_are_the_widths_the_file_laid", right == GAPS.size(), "; ".join(words))
	_sections += 1


func _the_arrival_is_a_savoia_afloat() -> void:
	var craft: int = 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", 0)) == Sim.local_client_id():
			craft = int((pilot as Dictionary).get("vehicle", 0))
	var kind: int = -1
	var at := Vector3.ZERO
	for vehicle in Sim.server.vehicle_states():
		if int((vehicle as Dictionary).get("entity", 0)) == craft and craft != 0:
			kind = int((vehicle as Dictionary).get("kind", -1))
			at = vehicle.get("position", Vector3.ZERO)
	var wet: bool = Terrain.water_height(at) != -INF
	_check("the_player_arrives_in_a_savoia_afloat", kind == Sim.Kind.SAVOIA and wet and at.y < 8.0,
		"a %s at %s, water %s, %.1f m over the surface" % [
			Sim.kind_name(kind), at.snapped(Vector3.ONE * 0.1), wet, at.y - Terrain.surface_height(at)])
	_sections += 1


func _the_woods_that_grew() -> void:
	var stands: Array[Dictionary] = Forests.stands()
	var tally: Dictionary = Forests.last_tally
	var words: PackedStringArray = []
	for stand in stands:
		var c: Vector3 = stand.get("centre", Vector3.ZERO)
		words.append("%s at (%.0f, %.0f)" % [stand.get("name", "?"), c.x, c.z])
	# A REPORT, not a floor: forest is automatic on alpine, and a bare island is a slope or a stand landing elsewhere.
	print("[adriatic] woods: %d stands kept of %s tries (%s); %s" % [
		stands.size(), tally.get("tried", "?"), tally, ", ".join(words) if not words.is_empty() else "none"])
	_check("the_ground_was_asked_for_woods", not tally.is_empty(), "%s" % [tally])
	_sections += 1


func _on_a_session_ended(reason: String) -> void:
	if _finished:
		return
	_check("the_adriatic_stands_and_comes_up", false, "the session ended while it loaded: %s" % reason)
	_finish()


func _finish() -> void:
	_finished = true
	Sim.stop()
	Net.leave("suite over")
	Net.choose_level(ChartDrawer.DEFAULT)
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
