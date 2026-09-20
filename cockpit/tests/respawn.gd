extends Node
## Headless: WHEN YOUR CRAFT IS DESTROYED -- the pieces fall, you watch the wreck from a still stand with a line saying
## what happened, and after the host's wait you are back in a fresh craft of the same kind, in the same seat, as the
## same one pilot (lane/combat, 2026-09-18).
##
##   Godot --headless --path cockpit res://tests/respawn.tscn
##
## THE REAL LEVEL AND THE REAL PATH: the player asks for a light aeroplane the way the clipboard does, and the host
## destroys it as a burst of rounds would (`apply_damage`, the one call a test makes that a gun does not). Everything
## after that is the game's own: the cue and the pieces on this machine, the overview this machine shows, the host's
## `CrewRespawn` and the simulation's `respawn_crew`.
##
## WHAT IS HELD:
## - the craft comes apart into pieces (`WreckPieces`), and they fall;
## - the rig is handed to the overview's stand, not left in a seat, and the panel says it was shot down;
## - within `CrewRespawn.SECONDS` and a margin the rig is in a fresh light aeroplane, not the wreck, and the overview is
##   gone;
## - in the same seat, with ONE pilot for this client on the host and on this machine -- `spawn_pilot` for a client who
##   has one makes a second (lightgun's S-1), and the respawn must not.
##
## Read RESULT=, not the exit code.

var _failures: PackedStringArray = []
var _level: FlightLevel = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[respawn] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld") or not ClassDB.class_has_method("CockpitWorld", "respawn_crew"):
		_check("the_library_respawns_crews", false, "no respawn_crew")
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	for i in range(240):
		await get_tree().physics_frame
	await _shot_down_and_back_in_the_air(_level.rig)
	_finish()


func _shot_down_and_back_in_the_air(rig: PilotRig) -> void:
	rig.ask_for_kind(Sim.Kind.PLANE)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == Sim.Kind.PLANE:
			break
	_check("the_player_is_in_a_light_aeroplane", view != null and view.kind == Sim.Kind.PLANE, "%s" % [view])
	if view == null or view.kind != Sim.Kind.PLANE:
		return
	var seat: int = rig.seat_index()
	var craft: int = _hosts_craft()
	var wreck_view: int = view.entity
	for i in range(60):
		await get_tree().physics_frame
	var broken_before: int = _level.damage.pieces.broken
	Sim.server.apply_damage(craft, 10000.0)

	var shown_at: int = -1
	for i in range(60):
		await get_tree().process_frame
		if _level.overview.is_showing() and rig.get_parent() == _level.overview.stand:
			shown_at = i
			break
	_check("the_craft_comes_apart_into_falling_pieces", _level.damage.pieces.broken > broken_before
		and _level.damage.pieces.thrown >= 3, "%d broken, %d pieces, %s" % [_level.damage.pieces.broken,
		_level.damage.pieces.thrown, _level.damage.pieces.counts()])
	_check("the_rig_watches_the_wreck_from_a_still_stand", shown_at >= 0, "in %d frames" % shown_at)
	_check("and_the_panel_says_what_happened", _level.overview.words.begins_with("Shot down"),
		"'%s'" % _level.overview.words)
	var stand_at: Vector3 = _level.overview.stand.global_position if _level.overview.stand != null else Vector3.ZERO
	await get_tree().create_timer(1.0).timeout
	var still: bool = _level.overview.stand != null and _level.overview.stand.global_position == stand_at
	_check("and_the_stand_does_not_move", still, "")

	var back_at: float = -1.0
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < int((CrewRespawn.SECONDS + 6.0) * 1000.0):
		await get_tree().physics_frame
		var now: VehicleView = rig.vehicle_view()
		if now != null and now.entity != wreck_view and now.kind == Sim.Kind.PLANE and not now.wrecked \
				and not _level.overview.is_showing():
			back_at = float(Time.get_ticks_msec() - began) / 1000.0
			break
	_check("the_player_is_back_in_a_fresh_light_aeroplane_after_the_wait", back_at >= 0.0,
		"%.1f s after the overview began, the host's wait %.1f s" % [back_at, CrewRespawn.SECONDS])
	_check("in_the_same_seat", rig.seat_index() == seat, "seat %d, was %d" % [rig.seat_index(), seat])
	var mine: int = Sim.local_client_id()
	var on_host: int = Sim.server.pilot_states().filter(func(p: Dictionary) -> bool: return int(p["client"]) == mine).size()
	var here: int = Sim.pilots.filter(func(p: Dictionary) -> bool: return int(p["client"]) == mine).size()
	_check("as_the_same_one_pilot", on_host == 1 and here == 1, "%d on the host, %d here" % [on_host, here])
	var fresh: int = _hosts_craft()
	_check("and_the_new_craft_is_whole_and_flying", fresh != craft and not bool(Sim.server.hull_state(fresh)
		.get("destroyed", true)) and (Sim.server.vehicle_state(fresh).get("velocity", Vector3.ZERO) as Vector3).length()
		> 20.0, "craft %d -> %d" % [craft, fresh])


func _hosts_craft() -> int:
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			return int((pilot as Dictionary).get("vehicle", 0))
	return 0


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
