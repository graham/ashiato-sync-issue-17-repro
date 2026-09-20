extends Node
## Headless: DOES RADAR SEE WHAT IT SHOULD AND MISS WHAT IS HIDDEN?
##
##   Godot --headless --path cockpit res://tests/radar_set.tscn
##
## REAL CRAFT IN A REAL WORLD WITH THE ISLAND'S ROCK IN IT. The craft are spawned with the server's own
## `spawn_ai_vehicle` and read back through its own `vehicle_states()`, so what is under test is the sweep against
## the simulation and not against a list this file wrote (CLAUDE.md rule 3). No session, no level, no rig: the
## question is about a sensor, and standing a whole level up would make a failure ambiguous.
##
## THE GEOMETRY IS MEASURED, NOT TYPED. The summit is found from the mountains' own pyramid, and the two aeroplanes
## are placed relative to it -- one tucked behind it below its top, one over it. A coordinate typed in here would
## stop meaning what it says the first time anybody moves a range.
##
## WHAT IT HOLDS:
##
##   1. **A CRAFT IN THE OPEN IS SEEN.** Without this, "sees nothing" passes everything below it.
##   2. **A CRAFT BEHIND A PEAK IS NOT**, from a head on the other side. This is the whole feature.
##   3. **AND THE SAME CRAFT, RAISED OVER THE PEAK, IS SEEN AGAIN** -- from the same head, in the same world, on the
##      same sweep code. The pair is the check: 2 alone would pass a radar that had simply lost that aeroplane.
##   4. **RANGE CUTS.** The open craft disappears when the reach is shortened below its slant range and comes back
##      when it is lengthened. Again a pair, for the same reason.
##   5. **A ROW DESCRIBES ITSELF AND CARRIES NO ENTITY ID.** Held against `COLUMNS`, and round-tripped through
##      `RadarSet.read` to the shape the plot already draws. A radar picture of ids would be wrong about a fifth of
##      its contacts (`radar_set.gd`), so "there is no id on the wire" is a property worth failing over.
##   6. **A TOWER IS NOT A CONTACT.** `AirPicture.NOT_TRAFFIC` is asked, not repeated.
##   7. **THE HEAD DOES NOT REPORT ITSELF**, which is what `skip` is for.
##   8. **MANNED IS THE SERVER'S ANSWER.** With nobody aboard anything, every contact reads unmanned -- and the
##      column is genuinely read, which check 5's round trip proves.
##
## Read RESULT=, not the exit code.

## How far behind the summit the hidden aeroplane sits, and how far the head stands on the other side.
const BEHIND: float = 2500.0
const HEAD_OUT: float = 2500.0
## How far below the summit the hidden one flies, and how far above it the seen one does.
const UNDER: float = 300.0
const ABOVE: float = 900.0
## Where the aeroplane in the clear stands, relative to the head: straight out over open ground, well inside reach.
const CLEAR_OUT: float = 4000.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[radar_set] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var exists: bool = ClassDB.class_exists(&"MountainRange") and ClassDB.class_has_method(&"CockpitWorld", &"set_mountains")
	_check("the_extension_has_mountains", exists, "engine %s" % Engine.get_version_info()["string"])
	if not exists:
		_finish()
		return

	var island: Object = ClassDB.instantiate(&"MountainRange")
	island.call("configure", Terrain.mountain_values())
	var world: Object = ClassDB.instantiate(&"CockpitWorld")
	world.set_tick_rate(120)
	# `start(0)` AND NOT `start(1)`: `is_server_ = client_id == 0`, and `spawn_vehicle` refuses on anything that is not
	# the server, returning 0 in silence. `tests/mountains.gd` starts its world with 1 because it only ever asks the
	# pyramid questions; a sweep needs craft in the world, so this one has to BE the authority -- which is also what
	# radar is (rule 10).
	world.start(0)
	world.set_mountains(island)

	var summit: Dictionary = _the_highest_place(island)
	var at: Vector3 = summit["at"]
	var top: float = float(summit["height"])
	_check("a_summit_was_found_to_hide_behind", top > 400.0, "%.0f m at %s" % [top, at])
	if top <= 400.0:
		_finish()
		return

	# THE HEAD ON ONE SIDE OF THE PEAK, both aeroplanes on the other.
	var head := Vector3(at.x - HEAD_OUT, top - UNDER, at.z)
	var hidden_at := Vector3(at.x + BEHIND, top - UNDER, at.z)
	var over_at := Vector3(at.x + BEHIND, top + ABOVE, at.z)
	# AND ONE IN THE CLEAR, on the head's OWN side, so no rock stands between them.
	var clear_at := Vector3(head.x - CLEAR_OUT, top - UNDER, head.z)

	var hidden: int = int(world.spawn_ai_vehicle(Sim.Kind.AIRLINER, hidden_at, 0.0, Vector3.ZERO))
	var over: int = int(world.spawn_ai_vehicle(Sim.Kind.AIRLINER, over_at, 0.0, Vector3.ZERO))
	var clear: int = int(world.spawn_ai_vehicle(Sim.Kind.AIRLINER, clear_at, 0.0, Vector3.ZERO))
	var tower: int = int(world.spawn_ai_vehicle(Sim.Kind.TOWER, clear_at + Vector3(200.0, 0.0, 0.0), 0.0, Vector3.ZERO))
	var spawned: bool = hidden != 0 and over != 0 and clear != 0 and tower != 0
	_check("three_aeroplanes_and_a_tower_were_spawned", spawned,
		"hidden=%d over=%d clear=%d tower=%d" % [hidden, over, clear, tower])
	if not spawned:
		_finish()
		return
	# ONE TICK, so there is a display pose to read: `vehicle_states()` reports the DISPLAY pose, computed once per
	# tick (`cockpit_world.cpp`), and a world that has never ticked lists nothing however much was spawned into it.
	world.tick(1.0 / 120.0)

	# WHERE THE SIMULATION ACTUALLY PUT THEM, read back rather than assumed: a spawn may be moved, and a check that
	# trusted the argument would be testing arithmetic this file did.
	var placed: Dictionary = {}
	for state_any in world.vehicle_states():
		var state := state_any as Dictionary
		placed[int(state.get("entity", 0))] = state.get("position", Vector3.ZERO)
	_check("and_the_simulation_put_them_where_it_was_asked",
		(placed.get(hidden, Vector3.ZERO) as Vector3).distance_to(hidden_at) < 50.0
			and (placed.get(over, Vector3.ZERO) as Vector3).distance_to(over_at) < 50.0,
		"hidden at %s (asked %s), over at %s" % [placed.get(hidden, Vector3.ZERO), hidden_at,
			placed.get(over, Vector3.ZERO)])

	var manned: Dictionary = RadarSet.manned_vehicles(world)
	var rows: Array = RadarSet.sweep(world, head, manned)
	var names: PackedStringArray = []
	for row in rows:
		names.append(String((row as Array)[7]))
	print("[radar_set] swept %d contact(s): %s" % [rows.size(), names])

	# ---- 1, 2, 3: the open one is seen, the hidden one is not, the raised one is ----------------
	_check("a_craft_in_the_open_is_seen", _holds(rows, placed[clear]),
		"%.1f km from the head, nothing between" % (head.distance_to(placed[clear]) / 1000.0))
	_check("a_craft_behind_a_peak_is_not_seen", not _holds(rows, placed[hidden]),
		"%.0f m under a %.0f m summit, %.1f km beyond it" % [UNDER, top, BEHIND / 1000.0])
	_check("and_the_same_craft_raised_over_the_peak_is_seen", _holds(rows, placed[over]),
		"the same place, %.0f m higher" % (ABOVE + UNDER))

	# ---- 4: range cuts, both ways ---------------------------------------------------------------
	var reach: float = head.distance_to(placed[clear])
	var short_rows: Array = RadarSet.sweep(world, head, manned, reach - 500.0)
	var long_rows: Array = RadarSet.sweep(world, head, manned, reach + 500.0)
	_check("a_craft_beyond_the_reach_is_dropped", not _holds(short_rows, placed[clear]),
		"reach %.0f m against a slant range of %.0f m" % [reach - 500.0, reach])
	_check("and_is_there_again_when_the_reach_is_lengthened", _holds(long_rows, placed[clear]),
		"reach %.0f m" % (reach + 500.0))

	# ---- 5: the row describes itself and holds no id --------------------------------------------
	var row: Array = _row_for(rows, placed[clear])
	_check("a_row_has_one_field_per_column", row.size() == RadarSet.COLUMNS.size(),
		"%d fields against %s" % [row.size(), RadarSet.COLUMNS])
	var carries_id: bool = false
	for entity in [hidden, over, clear, tower]:
		for field in row:
			if field is int and int(field) == int(entity) and int(entity) > 3:
				carries_id = true
	_check("and_carries_no_entity_id", not carries_id,
		"row %s against entities %s" % [row, [hidden, over, clear, tower]])
	var back: Dictionary = RadarSet.read(row)
	_check("and_reads_back_into_the_shape_the_plot_draws",
		(back.get("position", Vector3.ZERO) as Vector3).distance_to(placed[clear]) < 2.0
			and back.get("kind", -1) == Sim.Kind.AIRLINER and not bool(back.get("manned", true))
			and int(back.get("client", 0)) == -1,
		"read back %s" % back)
	# AND IT IS ANONYMOUS GREY, never a player's colour: radar knows somebody is aboard, never who.
	_check("and_is_drawn_in_the_anonymous_grey", Color(back.get("colour", Color.WHITE)) == AirPicture.AI,
		"colour %s against AirPicture.AI %s" % [back.get("colour", Color.WHITE), AirPicture.AI])

	# ---- 6, 7: what is not a contact ------------------------------------------------------------
	_check("a_tower_is_not_a_contact", not _holds(rows, placed[tower]),
		"a TOWER stood 200 m from an aeroplane that IS listed")
	var skipped: Array = RadarSet.sweep(world, head, manned, RadarSet.REACH_M, RadarSet.MAST_M, clear)
	_check("the_head_does_not_report_its_own_craft", not _holds(skipped, placed[clear]),
		"swept with skip=%d, %d contact(s) left" % [clear, skipped.size()])

	# ---- 8: manned is the server's answer -------------------------------------------------------
	_check("with_nobody_aboard_every_contact_is_unmanned", manned.is_empty() and _all_unmanned(rows),
		"the server listed %d manned vehicle(s)" % manned.size())

	_finish()


## Whether a sweep holds a contact at that place, by POSITION and not by id -- which is the only handle there is,
## and is the point of the row shape.
func _holds(rows: Array, at: Vector3) -> bool:
	return not _row_for(rows, at).is_empty()


func _row_for(rows: Array, at: Vector3) -> Array:
	for row_any in rows:
		var row := row_any as Array
		if Vector3(float(row[1]), float(row[2]), float(row[3])).distance_to(at) < 2.0:
			return row
	return []


func _all_unmanned(rows: Array) -> bool:
	for row_any in rows:
		if int((row_any as Array)[6]) != 0:
			return false
	return true


## THE HIGHEST PLACE THE ISLAND'S ROCK REACHES, as `tests/sight_line.gd` finds it and for the same reason.
func _the_highest_place(island: Object) -> Dictionary:
	var best: float = -INF
	var where := Vector3.ZERO
	var step: float = 500.0
	var reach: float = 12000.0
	var x: float = -reach
	while x <= reach:
		var z: float = -reach
		while z <= reach:
			var high: float = float(island.call("highest_over", x - step, z - step, x + step, z + step))
			if high > best:
				best = high
				where = Vector3(x, 0.0, z)
			z += step
		x += step
	var tight: float = float(island.call("highest_over", where.x - 60.0, where.z - 60.0, where.x + 60.0, where.z + 60.0))
	return {"at": where, "height": tight}


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
