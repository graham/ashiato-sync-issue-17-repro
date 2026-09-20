extends Node
## Headless: every finger and flight-page row makes sense for the craft it belongs to.
##
##   Godot --headless --path cockpit res://tests/sense.tscn
##
## Built from every pilotable kind's real schema and real cockpit controls. A shared
## throttle is deliberately allowed to advertise aeroplane bindings; the rig must remove
## commands the current craft cannot execute. The page must do the same with its rows, and
## both surfaces must use the bus's craft-specific name.

const RIGHT: int = 1

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[sense] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	CockpitStation.use_saved_layouts = false
	var bad_bindings: PackedStringArray = []
	var bad_rows: PackedStringArray = []
	var bad_names: PackedStringArray = []
	var controls: int = 0
	var pages: int = 0
	var removed: int = 0
	for kind in VehicleCatalogue.pilotable_kinds():
		var view := _craft(kind)
		if view == null:
			bad_bindings.append("%s: no view" % Sim.kind_name(kind))
			continue
		var schema: Array = (Sim.schema_of(kind).get("channels", []) as Array)
		var fitted: Dictionary = view.channel_names()
		for entry in schema:
			var row := entry as Dictionary
			var channel: int = int(row.get("channel", -1))
			var called: String = String(row.get("name", ""))
			var said: String = Bind.says(Bind.step(channel, 1), fitted)
			if not said.begins_with(called):
				bad_names.append("%s %s -> %s" % [Sim.kind_name(kind), called, said])
		var seen: Dictionary = {}
		for seat in range(view.seats.size()):
			for role in view.controls_for(seat):
				var control := view.controls_for(seat)[role] as VehicleControl
				if control == null or seen.has(control):
					continue
				seen[control] = true
				controls += 1
				var own: Dictionary = control.bindings()
				for input in own:
					var before: Array[int] = _commands(own[input])
					var after: Variant = PilotRig._only_fitted_commands(own[input], view)
					var left: Array[int] = _commands(after)
					for channel in before:
						if view.channel_range(channel) <= 0:
							removed += 1
							if channel in left:
								bad_bindings.append("%s seat %d %s %s -> %s (not fitted)" % [
									Sim.kind_name(kind), seat, role, Bind.input_name(input), Sim.channel_name(channel)])
		var page := FlightPage.new()
		add_child(page)
		await get_tree().process_frame
		page.render({"fitted": schema})
		pages += 1
		for channel in FlightPage.CHANNEL_ROWS:
			var key: String = FlightPage.CHANNEL_ROWS[channel]
			var line := page._lines.get(key) as Control
			var wanted: bool = fitted.has(channel)
			if line == null or line.visible != wanted:
				bad_rows.append("%s %s visible %s, fitted %s" % [
					Sim.kind_name(kind), key, line.visible if line != null else "missing", wanted])
			elif wanted:
				var label := page._labels.get(key) as Label
				if label == null or label.text != String(fitted[channel]).to_upper():
					bad_names.append("%s page %s -> %s" % [Sim.kind_name(kind), fitted[channel],
						label.text if label != null else "missing"])
		page.queue_free()
		view.queue_free()
	_check("every_control_command_is_fitted_to_its_craft", bad_bindings.is_empty() and controls > 50 and removed > 0,
		"%d controls, %d inappropriate shared actions removed" % [controls, removed] if bad_bindings.is_empty()
		else "\n      ".join(bad_bindings))
	_check("flight_page_only_shows_fitted_control_rows", bad_rows.is_empty() and pages > 10,
		"%d craft pages" % pages if bad_rows.is_empty() else "\n      ".join(bad_rows))
	_check("player_facing_words_use_each_crafts_channel_names", bad_names.is_empty(),
		"all fitted names" if bad_names.is_empty() else "\n      ".join(bad_names))
	_check("known_overloaded_channels_keep_their_meaning",
		_named(Sim.Kind.CHINOOK, Sim.Channel.GEAR) == "ramp"
			and _named(Sim.Kind.CAR, Sim.Channel.GEAR) == "handbrake"
			and _named(Sim.Kind.TANK, Sim.Channel.GEAR) == "parking brake",
		"Chinook %s, car %s, tank %s" % [_named(Sim.Kind.CHINOOK, Sim.Channel.GEAR),
			_named(Sim.Kind.CAR, Sim.Channel.GEAR), _named(Sim.Kind.TANK, Sim.Channel.GEAR)])
	await _real_rig_uses_the_filtered_named_table()
	_finish()


func _craft(kind: int) -> VehicleView:
	var scene := load("res://objects/vehicles/craft_plane.tscn") as PackedScene
	var view := scene.instantiate() as VehicleView
	if view == null:
		return null
	add_child(view)
	view.preview_kind = kind as Sim.Kind
	view._show_in_editor()
	return view


func _commands(action: Variant) -> Array[int]:
	var found: Array[int] = []
	if action is Array:
		for one in action:
			found.append_array(_commands(one))
	elif action is Dictionary and int((action as Dictionary).get("kind", -1)) == Bind.Kind.COMMAND:
		found.append(int((action as Dictionary).get("channel", -1)))
	return found


func _named(kind: int, channel: int) -> String:
	for entry in (Sim.schema_of(kind).get("channels", []) as Array):
		if int((entry as Dictionary).get("channel", -1)) == channel:
			return String((entry as Dictionary).get("name", ""))
	return ""


## THE PLAYER PATH, starting at a real seated rig rather than the helper underneath it.
## This is what makes deleting the filter call from `_bindings_for` turn the suite red.
func _real_rig_uses_the_filtered_named_table() -> void:
	var level := load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(240):
		await get_tree().physics_frame
	var rig: PilotRig = level.rig
	var boat: VehicleView = await _sit_in(rig, Sim.Kind.BOAT)
	var boat_table: Dictionary = {}
	var boat_legend: String = ""
	if boat != null:
		var throttle := boat.controls_for(rig.seat_index()).get("throttle") as VehicleControl
		if throttle != null:
			throttle.held_by = RIGHT
			boat_table = rig._bindings_for(RIGHT)
			boat_legend = str(rig.legend())
			throttle.held_by = -1
	_check("the_real_boat_rig_drops_flaps_and_gear_from_its_throttle",
		boat != null and not Sim.Channel.FLAPS in _commands(boat_table.get(Bind.THUMB_HIGH))
			and not Sim.Channel.GEAR in _commands(boat_table.get(Bind.STICK_CLICK))
			and not boat_legend.contains("flaps") and not boat_legend.contains("gear"),
		"thumb high '%s', click '%s'" % [Bind.says(boat_table.get(Bind.THUMB_HIGH)),
			Bind.says(boat_table.get(Bind.STICK_CLICK))])
	var chinook: VehicleView = await _sit_in(rig, Sim.Kind.CHINOOK)
	var ramp_says: String = ""
	if chinook != null:
		var collective := chinook.controls_for(rig.seat_index()).get("throttle") as VehicleControl
		if collective != null:
			collective.held_by = RIGHT
			var table: Dictionary = rig._bindings_for(RIGHT)
			ramp_says = Bind.says(table.get(Bind.STICK_CLICK), chinook.channel_names())
			collective.held_by = -1
	_check("and_the_real_chinook_rig_calls_gear_its_ramp", ramp_says.contains("ramp"), ramp_says)
	level.queue_free()


func _sit_in(rig: PilotRig, kind: int) -> VehicleView:
	rig.ask_for_kind(kind)
	for i in range(900):
		await get_tree().physics_frame
		var view: VehicleView = rig.vehicle_view()
		if view != null and view.kind == kind and rig.seat_index() == 0:
			# The rig claims the new station on its next process pass after the seat changes.
			for settle in range(3):
				await get_tree().physics_frame
			return view
	return null


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
