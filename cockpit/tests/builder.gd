extends Node
## Headless: can a cockpit be rearranged from the seat, and does what comes out read back?
##
##   Godot --headless --path cockpit res://tests/builder.tscn
##
## The builder is three claims and they fail in three different ways:
##
##   1. A GRAB MOVES THE CONTROL INSTEAD OF WORKING IT. If this breaks, dragging the
##      throttle across the console opens the throttle, which in the air is not a cosmetic
##      bug.
##   2. WHAT COMES OUT IS READABLE. The whole reason the output is JSON and not a scene is
##      that a person or a language model has to be able to read it, so the numbers are
##      checked against the cockpit they came from rather than against themselves.
##   3. IT GOES BACK IN. A layout that saves and does not load is a layout that quietly
##      does nothing, and the only way to find that out is to fly the aircraft.
##
## NOTHING IS LEFT IN `user://`. The suite writes a layout, reads it back, and removes it --
## because the next run of `fit` measures every cockpit in the game for reach, and a layout
## left behind by a test is a cockpit measured against somebody else's furniture.
##
## AND NONE OF IT IS THE PLAYER'S. The forgets below once ran against `user://cockpits` itself, and on 2026-09-13 a full
## gate deleted the plane cockpit the user had saved that evening, with no copy anywhere. So the first check is that
## this run's cockpits are in `CockpitLayout.TEST_FOLDER`; if that ever fails, nothing after it runs.
##
## Read RESULT=, not the exit code.

const TEST_KIND: int = Sim.Kind.PLANE
const TEST_SEAT: int = 0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[builder] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	# NOT THE PLAYER'S FOLDER, checked before the first forget below can reach it. See the note above.
	_check("this_suite_keeps_its_cockpits_out_of_the_players_folder",
		CockpitLayout.folder == CockpitLayout.TEST_FOLDER + CockpitLayout.test_slot() and CockpitLayout.folder != CockpitLayout.PLAYER_FOLDER
			and PlacingGrid.path.begins_with(CockpitLayout.TEST_FOLDER)
			and CockpitLayout.folder_for(PackedStringArray(["--path", "cockpit"])) == CockpitLayout.PLAYER_FOLDER,
		"layouts in %s, grid at %s" % [CockpitLayout.folder, PlacingGrid.path])
	if not _failures.is_empty():
		_finish()
		return
	# NOTHING FROM A PREVIOUS RUN, and nothing left after this one. See the note above.
	CockpitLayout.forget(TEST_KIND, TEST_SEAT)
	await _the_parts_bin_is_honest()
	await _craft_rules_reach_the_real_builder_paths()
	_the_panel_furniture_works()
	await _a_grab_moves_it_instead_of_working_it()
	await _what_comes_out_says_where_things_are()
	await _and_it_goes_back_in()
	await _a_time_of_day_dial_is_saved_and_comes_back()
	await _every_dials_stop_names_can_be_read_from_the_seat()
	await _a_part_the_builder_adds_lands_clear_of_every_grip_where_a_seated_hand_can_use_it()
	await _a_part_pushed_along_an_axis_keeps_the_seats_forward()
	await _from_the_seat_a_dials_names_are_level_and_its_pointer_covers_none()
	await _a_crowded_console_still_takes_a_part_where_it_crowds_least_and_says_so()
	await _a_cockpit_saved_to_a_file_loads_every_control_where_it_was_saved()
	await _a_dials_placard_clears_its_pointer_and_plate_at_every_stop()
	await _the_rig_puts_one_in_and_takes_it_out_again()
	await _a_station_built_fresh_picks_the_saved_one_up()
	await _the_menu_has_a_door_into_the_builder()
	CockpitLayout.forget(TEST_KIND, TEST_SEAT)
	_finish()


## ---- the parts bin --------------------------------------------------------------------

## EVERY PART IN THE BIN CAN ACTUALLY BE MADE, AND MAKES SOMETHING.
##
## A menu entry that produces null is a button that does nothing, and a button that does
## nothing in a headset is indistinguishable from a headset that has stopped tracking.
##
## AND THE THREE THAT ARE DELIBERATELY OUT STAY OUT. `VehicleControl` has no shape,
## `RudderIndicator` is a gauge no hand can hold, and `PintleGun` is placed from the
## simulation's mount table because that is where the round leaves from. See
## ControlCatalogue, which is where the reasons are written down.
func _the_parts_bin_is_honest() -> void:
	var empty: Array = []
	var built: Array = []
	var unsaid: Array = []
	var scopes: Array = []
	for part in ControlCatalogue.PARTS:
		var made: VehicleControl = ControlCatalogue.make(part)
		if made == null:
			empty.append(String(part))
			continue
		made.setup(0)
		# A CONTROL WITH NO MESHES IS A CONTROL YOU CANNOT SEE TO GRAB. Every one of these
		# builds its own shape in `_build`, and the base class builds none -- which is
		# exactly the failure a bin holding `VehicleControl` would produce.
		if made.find_children("*", "MeshInstance3D", true, false).is_empty():
			empty.append("%s has no shape" % part)
		built.append(part)
		# AND ITS OWN NAME COMES BACK. A part written into a file has to be the string that
		# makes one again, or a saved cockpit loads as an empty seat.
		if ControlCatalogue.part_of(made) != part:
			empty.append("%s calls itself %s" % [part, ControlCatalogue.part_of(made)])
		# AND IT SAYS WHOSE IT IS. A part that never set `scope` is a part the sharing code skips
		# without a word -- drawn from no craft, proposed to none. See VehicleControl.scope.
		if made.scope == VehicleControl.Scope.UNSAID:
			unsaid.append(String(part))
		else:
			scopes.append("%s %s" % [part, _scope_word(made.scope)])
		made.free()
	_check("every_part_in_the_bin_makes_a_control_with_a_shape", empty.is_empty(),
		"%d parts, %s" % [built.size(), "all good" if empty.is_empty() else empty])
	_check("and_every_part_says_whose_its_position_is", unsaid.is_empty() and not scopes.is_empty(),
		"%s" % [scopes if unsaid.is_empty() else "unsaid: %s" % [unsaid]])
	# AND AN MFD'S KEYS ARE THE PILOT'S. It was the craft's, and DISPLAY is one selector for the whole aircraft, so a key
	# pressed on one panel lit the same key on every MFD panel aboard. Deliberate, and named in the commit.
	var mfd: VehicleControl = ControlCatalogue.make(&"MfdPanel")
	mfd.setup(0)
	_check("and_an_mfd_panels_keys_are_the_pilots_own", mfd.scope == VehicleControl.Scope.PILOT,
		"MfdPanel is %s" % _scope_word(mfd.scope))
	mfd.free()
	_check("and_the_gun_is_not_one_of_them",
		not ControlCatalogue.has(&"PintleGun") and not ControlCatalogue.has(&"VehicleControl")
			and not ControlCatalogue.has(&"RudderIndicator"),
		"a gun is placed where the simulation says the mount is")


## A BOAT CANNOT BE OFFERED OR FORCED TO ACCEPT AIRCRAFT FLAPS. This crosses the
## package allowlist, real clipboard page, rig, layout loader and package validator.
func _craft_rules_reach_the_real_builder_paths() -> void:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	add_child(view)
	view.setup(987654, Sim.Kind.BOAT)
	view.man([0], 0)
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.sit_in(view.seat_anchor(0))
	rig._take(view.controls_for(0), view)
	await get_tree().process_frame
	var labels: PackedStringArray = []
	for child in (rig.clipboard.page().get("_parts") as GridContainer).get_children():
		labels.append(String((child as Button).text))
	_check("a_boats_build_page_hides_devices_its_package_does_not_allow",
		not labels.has("+ FLAPS LEVER") and labels.has("+ STEERING WHEEL"),
		"%d buttons; flaps %s, wheel %s" % [labels.size(), labels.has("+ FLAPS LEVER"), labels.has("+ STEERING WHEEL")])
	var station := view.station_for(0)
	var before := station.get_child_count()
	rig.add_control(&"FlapsLever")
	await get_tree().process_frame
	var said := rig.clipboard.page().get("_said") as Label
	_check("and_direct_add_control_refuses_the_same_disallowed_device_in_words",
		station.get_child_count() == before and said.text.contains("not fitted"), said.text)
	var forced := {"kind": Sim.Kind.BOAT, "seat": 0, "controls": [{"part": "FlapsLever",
		"name": "ForcedFlaps", "channel": Sim.Channel.FLAPS, "at": [0, 0, 0], "facing": [0, 0, 0]}]}
	var bare := CockpitStation.new()
	add_child(bare)
	var applied := CockpitLayout.apply(forced, bare, 0, VehicleCatalogue.allowed(Sim.Kind.BOAT), Sim.Kind.BOAT)
	_check("and_layout_apply_skips_a_disallowed_device", applied == 0 and bare.get_child_count() == 0,
		"%d controls" % applied)
	var unfitted := {"kind": Sim.Kind.BOAT, "seat": 0, "controls": [{"part": "RotaryKnob",
		"name": "BadBus", "channel": 999, "at": [0, 0, 0], "facing": [0, 0, 0]}]}
	applied = CockpitLayout.apply(unfitted, bare, 0, [&"RotaryKnob"], Sim.Kind.BOAT)
	_check("and_layout_apply_skips_a_device_on_an_unfitted_channel",
		applied == 0 and bare.get_node_or_null("BadBus") == null, "%d controls" % applied)
	_check("and_package_validation_refuses_both_bypasses",
		CraftPackage.validate_station(Sim.Kind.BOAT, 0, forced, VehicleCatalogue.allowed(Sim.Kind.BOAT)).contains("disallowed device")
			and CraftPackage.validate_station(Sim.Kind.BOAT, 0, unfitted, [&"RotaryKnob"]).contains("unfitted channel"),
		"both invalid records refused")
	bare.queue_free()
	rig.queue_free()
	view.queue_free()
	await get_tree().process_frame


## ---- knobs, dials, switches and screens -------------------------------------------------

## THE FOUR KINDS OF PANEL FURNITURE, EACH TESTED FOR THE ONE THING THAT MAKES IT ITSELF.
##
## They look alike and they are not alike. A knob rests anywhere; a dial may not rest
## between its stops; a switch may not rest between its two positions at all; and an MFD is
## not a control that moves, it is eighteen keys that have to be individually hittable. Each
## of those is a promise, and a promise that quietly stops being kept is a cockpit that
## lies about the state of the aircraft.
func _the_panel_furniture_works() -> void:
	_a_knob_is_turned_and_not_shoved()
	_a_dial_never_rests_between_its_stops()
	_a_switch_is_thrown_and_stays_thrown()
	_a_guarded_switch_needs_two_deliberate_actions()
	_a_command_button_sends_one_down_and_one_up()
	_a_fighters_gear_handle_swings()
	_an_mfd_has_keys_a_finger_can_hit()


## A GENERIC PANEL BUTTON IS AN EDGE PAIR, not a cabin-light special case and not a value
## repeated every frame a finger remains on it. Its cap follows the local finger while the
## value is what the ordinary device router sends to the craft.
func _a_command_button_sends_one_down_and_one_up() -> void:
	var button := CommandButton.new()
	add_child(button)
	button.setup(0)
	var moved: Array = []
	button.moved.connect(func(_which: VehicleControl): moved.append(button.command_value()))
	button.offer_hand(0, button._grab_point(), 1.0)
	button.offer_hand(0, button._grab_point(), 1.0)
	_check("a_held_command_button_sends_one_down_edge",
		button.is_held() and button.command_value() == 1 and moved == [1], str(moved))
	button.offer_hand(0, button._grab_point(), 0.0)
	_check("and_releasing_it_sends_one_up_edge",
		not button.is_held() and button.command_value() == 0 and moved == [1, 0], str(moved))
	var before: int = moved.size()
	button.apply(Vector2(0.0, 1.0))
	_check("and_authoritative_lamp_state_does_not_emit_a_command",
		button.command_value() == 1 and moved.size() == before, "%d events" % moved.size())
	button.queue_free()


## THE RED COVER IS A REAL FIRST ACTION. Moving it is local hand feedback and cannot arm
## the aircraft; only a later throw of the exposed bat emits the shared command.
func _a_guarded_switch_needs_two_deliberate_actions() -> void:
	var guarded := GuardedToggleSwitch.new()
	add_child(guarded)
	guarded.setup(0)
	var moved: Array = []
	guarded.moved.connect(func(_which: VehicleControl): moved.append(guarded.command_value()))

	var cover: Vector3 = guarded._guard_grab_point()
	guarded.offer_hand(0, cover, 1.0)
	guarded.offer_hand(0, cover + Vector3(0.0, GuardedToggleSwitch.GUARD_TRAVEL * 1.2, 0.0), 1.0)
	guarded.offer_hand(0, cover + Vector3(0.0, GuardedToggleSwitch.GUARD_TRAVEL * 1.2, 0.0), 0.0)
	_check("opening_a_guarded_switch_is_local_and_sends_nothing",
		guarded.guard_is_open() and moved.is_empty(), "open %s, moved %s" % [guarded.guard_is_open(), moved])

	var bat: Vector3 = guarded._switch_grab_point()
	guarded.offer_hand(0, bat, 1.0)
	guarded.offer_hand(0, bat + Vector3(0.0, 0.0, -ToggleSwitch.THROW), 1.0)
	guarded.offer_hand(0, bat + Vector3(0.0, 0.0, -ToggleSwitch.THROW), 0.0)
	_check("then_the_exposed_switch_throws_once",
		guarded.is_on() and moved == [1], "on %s, moved %s" % [guarded.is_on(), moved])

	var before: int = moved.size()
	guarded.apply(Vector2.ZERO)
	_check("and_remote_state_moves_the_switch_without_moving_its_local_guard_or_emitting",
		guarded.guard_is_open() and not guarded.is_on() and moved.size() == before,
		"open %s, on %s, moved %s" % [guarded.guard_is_open(), guarded.is_on(), moved])
	guarded.queue_free()


## A WRIST TURNS IT AND AN ARM PASSING OVER IT DOES NOT.
##
## The second half matters more than the first. A console of knobs is a place a hand is
## constantly moving across, and a knob that answered hand TRAVEL would be reset by every
## reach for the thing behind it.
func _a_knob_is_turned_and_not_shoved() -> void:
	var knob := RotaryKnob.new()
	add_child(knob)
	knob.setup(0)
	knob.value = Vector2(0.0, 0.5)

	knob.offer_hand(0, knob._grab_point(), 1.0, Basis.IDENTITY)
	# SHOVED: the hand moves a long way and the wrist does not turn.
	knob.offer_hand(0, knob._grab_point() + Vector3(0.05, 0.0, -0.05), 1.0, Basis.IDENTITY)
	_check("a_hand_sliding_across_a_knob_does_not_turn_it",
		absf(knob.value.y - 0.5) < 0.001, "it moved to %.3f" % knob.value.y)
	# TURNED: the hand stays put and the wrist rolls clockwise, which is up.
	knob.offer_hand(0, knob._grab_point(), 1.0, Basis(Vector3.UP, -0.8))
	_check("but_rolling_the_wrist_clockwise_turns_it_up",
		knob.value.y > 0.55, "%.3f after 0.8 rad" % knob.value.y)
	var wound: float = knob.value.y
	knob.release()
	knob.relax(1.0)
	# AND IT STAYS WHERE IT IS PUT. A knob that sprang back would be a knob you cannot set.
	_check("and_it_stays_where_it_is_left",
		absf(knob.value.y - wound) < 0.0001, "%.3f then %.3f" % [wound, knob.value.y])
	knob.queue_free()


## A DIAL MAY NOT REST BETWEEN ITS STOPS.
##
## The flap gate's rule, on an axis instead of a rail: the channel carries three positions,
## and a pointer halfway between two of them is asking for a setting the aircraft cannot
## hold. The number on the panel would then disagree with the number in the simulation.
func _a_dial_never_rests_between_its_stops() -> void:
	var dial := DetentDial.new()
	add_child(dial)
	dial.setup(0)
	_check("a_three_position_dial_has_a_range_of_two",
		dial.channel_range == 2 and dial.stops.size() == 3,
		"%d stops, range %d" % [dial.stops.size(), dial.channel_range])
	# AND ITS POSITIONS ARE WRITTEN ON IT. Three angles nobody can tell apart is not a
	# selector, and unlike a lever's name this is something you read every single time.
	_check("and_every_stop_is_written_beside_it",
		dial.find_children("Stop*", "Label3D", false, false).size() == 3,
		"%d legends" % dial.find_children("Stop*", "Label3D", false, false).size())

	var landed: Array = []
	var between: Array = []
	for tenth in range(11):
		# A FRESH GRIP EACH TIME, walked across the whole sweep, so this asks about every
		# angle a wrist could leave it at rather than about three convenient ones.
		dial.value = Vector2.ZERO
		dial.offer_hand(0, dial._grab_point(), 1.0, Basis.IDENTITY)
		dial.offer_hand(0, dial._grab_point(), 1.0,
			Basis(Vector3.UP, -DetentDial.SWEEP * float(tenth) / 10.0))
		dial.release()
		var stop: float = dial.value.y * float(dial.channel_range)
		if absf(stop - roundf(stop)) > 0.0001:
			between.append("%.3f" % dial.value.y)
		if not landed.has(dial.at_stop()):
			landed.append(dial.at_stop())
	_check("and_a_wrist_left_anywhere_settles_on_a_stop", between.is_empty(),
		"%s" % ["every angle landed on one" if between.is_empty() else between])
	# AND ALL THREE ARE REACHABLE. A dial that snapped to a stop but could only ever reach
	# one of them would pass the check above and be useless.
	landed.sort()
	_check("and_all_three_of_them_can_be_reached", landed == [0, 1, 2],
		"reached %s" % [landed])
	dial.value = Vector2(0.0, 1.0)
	_check("and_it_can_say_which_one_it_is_on", dial.stop_name() == "HIGH",
		"%s" % dial.stop_name())
	dial.queue_free()


## FORWARD IS ON, IT SNAPS, AND IT STAYS.
func _a_switch_is_thrown_and_stays_thrown() -> void:
	var switch := ToggleSwitch.new()
	add_child(switch)
	switch.setup(0)
	_check("a_switch_starts_off", not switch.is_on(), "%d" % switch.at_position())
	switch.offer_hand(0, switch._grab_point(), 1.0)
	# PUSHED AWAY FROM THE PILOT, which is -Z, which is ON.
	switch.offer_hand(0, switch._grab_point() + Vector3(0.0, 0.0, -ToggleSwitch.THROW), 1.0)
	switch.release()
	_check("and_flicking_it_forward_turns_it_on", switch.is_on(), "%d" % switch.at_position())

	# AND A NUDGE LEAVES IT AT ONE END OR THE OTHER AND NEVER BETWEEN. There is no halfway
	# on a switch, and what it would be lying about is whether the pumps are running.
	var between: Array = []
	for tenth in range(11):
		switch.value = Vector2.ZERO
		switch.offer_hand(0, switch._grab_point(), 1.0)
		switch.offer_hand(0, switch._grab_point()
			+ Vector3(0.0, 0.0, -ToggleSwitch.THROW * float(tenth) / 10.0), 1.0)
		switch.release()
		if switch.value.y > 0.001 and switch.value.y < 0.999:
			between.append("%.3f" % switch.value.y)
	_check("and_it_is_never_left_halfway", between.is_empty(),
		"%s" % ["always one end or the other" if between.is_empty() else between])

	# THREE-WAY IS THE SAME OBJECT WITH A MIDDLE.
	var three := ToggleSwitch.new()
	add_child(three)
	three.positions = 3
	three.setup(0)
	three.value = Vector2(0.0, 0.5)
	_check("and_a_three_way_switch_has_a_middle_to_rest_in",
		three.channel_range == 2 and three.at_position() == 1,
		"range %d, position %d" % [three.channel_range, three.at_position()])
	switch.queue_free()
	three.queue_free()


## THE HAND GOES TO THE WHEEL, AND THE WHEEL IS NOT WHERE THE PIVOT IS.
##
## The reason this handle needs its own grab point rather than the default. The wheel swings
## through eight and a half centimetres, which is half the reach -- so a grab measured from
## the pivot would miss the handle entirely with the gear down, and the control would look
## exactly as though it should be grabbable.
func _a_fighters_gear_handle_swings() -> void:
	var handle := GearHandle.new()
	add_child(handle)
	handle.setup(0)
	var up_at: Vector3 = handle._grab_point()
	handle.value = Vector2(0.0, 1.0)
	var down_at: Vector3 = handle._grab_point()
	_check("the_handle_a_hand_reaches_for_moves_with_the_arm",
		up_at.distance_to(down_at) > 0.06,
		"the wheel travels %.3f m" % up_at.distance_to(down_at))
	_check("and_down_is_down", down_at.y < up_at.y,
		"up at %.3f m, down at %.3f m" % [up_at.y, down_at.y])

	# AND SWINGING IT TOWARDS THE FLOOR PUTS THE WHEELS OUT, with no halfway.
	handle.value = Vector2.ZERO
	handle.offer_hand(0, handle._grab_point(), 1.0)
	handle.offer_hand(0, handle._grab_point() + Vector3(0.0, -0.09, 0.0), 1.0)
	handle.release()
	_check("and_swinging_it_down_selects_gear_down",
		handle.is_down() and handle.value.y == 1.0, "value %.2f" % handle.value.y)
	handle.queue_free()


## EIGHTEEN KEYS, EVERY ONE OF THEM HITTABLE, AND EACH ONE ITS OWN.
##
## Two claims, and the first is the one with a number behind it. `PilotRig._nearest_to`
## measures a hand against a control's ONE grip point, which for a panel is the middle of
## the glass -- so a key further from the middle than `VehicleControl.REACH` is a key that
## cannot be pressed from the position the panel is chosen at.
func _an_mfd_has_keys_a_finger_can_hit() -> void:
	var mfd := MfdPanel.new()
	add_child(mfd)
	mfd.setup(0)
	var places: Array = mfd._key_places()
	_check("an_mfd_has_keys_round_all_four_sides",
		places.size() == MfdPanel.key_count() and places.size() == 18,
		"%d keys" % places.size())

	var far: float = 0.0
	for at in places:
		far = maxf(far, (at as Vector3).distance_to(mfd._grab_point()))
	_check("and_the_furthest_one_is_still_inside_the_reach_the_rig_measures",
		far < VehicleControl.REACH,
		"%.3f m out against a reach of %.2f" % [far, VehicleControl.REACH])

	# AND A FINGER ON ONE HITS THAT ONE. Keys half a centimetre apart are only keys if the
	# nearest-key rule actually resolves to the one under the finger.
	var wrong: Array = []
	for step in range(places.size()):
		if mfd._pressed_key(places[step] as Vector3) != step:
			wrong.append(step)
	_check("and_a_finger_on_a_key_presses_that_key", wrong.is_empty(),
		"%s" % ["all %d" % places.size() if wrong.is_empty() else wrong])

	# PRESSED, AND IT HAS TO RE-ARM. A held squeeze that did not would walk every page in
	# the aircraft in a tenth of a second.
	var heard: Array = []
	mfd.key_pressed.connect(func(_panel: MfdPanel, which: int): heard.append(which))
	mfd.offer_hand(0, places[6] as Vector3, 1.0)
	mfd.offer_hand(0, places[6] as Vector3, 1.0)
	mfd.offer_hand(0, places[6] as Vector3, 1.0)
	_check("and_one_squeeze_is_one_press", heard == [6] and mfd.selected_key() == 6,
		"heard %s, showing key %d" % [heard, mfd.selected_key()])
	# AND A FINGER WALKING ALONG THE BEZEL PRESSES EACH ONE without letting go, which is how
	# anybody actually uses one.
	mfd.offer_hand(0, places[7] as Vector3, 1.0)
	_check("and_a_finger_walking_along_the_bezel_presses_the_next_one",
		heard == [6, 7], "heard %s" % [heard])
	mfd.release()

	# AND THERE IS A SCREEN IN THE MIDDLE OF IT, which is what makes it multi-function
	# rather than eighteen buttons. `CockpitStation.show_state` finds it without being told.
	_check("and_the_glass_is_a_craft_display_the_station_will_feed",
		mfd.screen() != null
			and mfd.find_children("*", "CraftDisplay", true, false).size() == 1,
		"%d screens" % mfd.find_children("*", "CraftDisplay", true, false).size())
	mfd.queue_free()


## ---- a grab that moves rather than works ------------------------------------------------

## DRAGGING A THROTTLE ACROSS THE CONSOLE MUST NOT OPEN THE THROTTLE.
##
## The two grabs are told apart by which method the rig calls, so the honest test is to call
## both on the same control with the same hand movement and check they do opposite things:
## one changes `value` and does not move, the other moves and does not change `value`.
func _a_grab_moves_it_instead_of_working_it() -> void:
	var bench := Node3D.new()
	add_child(bench)
	var lever := ThrottleLever.new()
	bench.add_child(lever)
	lever.setup(0)
	lever.position = Vector3(0.2, 0.9, -0.3)
	await get_tree().process_frame

	# WORKED. The hand is given in the control's own frame, which is what `offer_hand` takes.
	var was_at: Vector3 = lever.position
	lever.offer_hand(0, lever._grab_point(), 1.0)
	# FORWARD, which is what opens a throttle. -Z, and the lever answers nothing else.
	lever.offer_hand(0, lever._grab_point() + Vector3(0.0, 0.0, -0.06), 1.0)
	var opened: float = lever.throttle()
	var wandered: float = lever.position.distance_to(was_at)
	lever.release()
	_check("working_a_lever_moves_the_lever_and_not_the_bracket",
		opened > 0.01 and wandered < 0.0001,
		"throttle %.2f, and it stayed put to within %.4f m" % [opened, wandered])

	# PLACED. The hand is given in the PARENT's frame, and the lever follows it.
	lever.value = Vector2.ZERO
	lever._redraw()
	var hand := Transform3D(Basis.IDENTITY, lever.position + lever._grab_point())
	lever.offer_hand_to_place(0, hand, 1.0)
	_check("and_a_hand_can_pick_it_up_at_all", lever.is_held(), "held by %d" % lever.held_by)
	var moved := Transform3D(Basis(Vector3.UP, 0.5), hand.origin + Vector3(0.1, 0.0, -0.05))
	lever.offer_hand_to_place(0, moved, 1.0)
	var travelled: float = lever.position.distance_to(was_at)
	_check("but_placing_it_moves_the_bracket_and_not_the_lever",
		travelled > 0.05 and lever.throttle() < 0.01,
		"it went %.3f m and the throttle is still %.2f" % [travelled, lever.throttle()])
	# AND WHAT FOLLOWS THE HAND IS THE PART THE HAND IS ON. The origin moves by less than
	# the hand did, and that is correct rather than a rounding error: a lever picked up by
	# its knob and turned pivots about the knob, so the bracket swings. What has to land
	# exactly under the hand is the grip.
	var grip_at: Vector3 = lever.transform * lever._grab_point()
	_check("and_the_part_the_hand_is_on_lands_under_the_hand",
		grip_at.distance_to(moved.origin) < 0.001,
		"the grip is %.4f m from the hand" % grip_at.distance_to(moved.origin))
	# AND THE WRIST COMES WITH IT. A cockpit built by dragging alone is a cockpit of levers
	# that all face forward, and half of what makes a quadrant reachable is its rake.
	_check("and_the_wrist_rakes_it",
		absf(lever.rotation.y - 0.5) < 0.01, "yaw %.3f rad" % lever.rotation.y)
	lever.offer_hand_to_place(0, moved, 0.0)
	_check("and_opening_the_hand_puts_it_down", not lever.is_held(),
		"held by %d" % lever.held_by)
	bench.queue_free()


## ---- what comes out ---------------------------------------------------------------------

## THE FILE SAYS WHERE THE CONTROLS ARE, IN METRES, IN A FRAME IT NAMES.
##
## Checked against the station it was written from rather than against a fixture, because
## the claim is not "the file has six entries" -- it is "the file is a true description of
## that cockpit", and only the cockpit can say.
func _what_comes_out_says_where_things_are() -> void:
	var station := _a_station()
	await get_tree().process_frame
	var written: Dictionary = CockpitLayout.of_station(TEST_KIND, TEST_SEAT, station)
	var listed: Array = written.get("controls", []) as Array
	_check("a_cockpit_writes_itself_down", listed.size() >= 3,
		"%d controls in a %s" % [listed.size(), written.get("craft", "?")])
	# AND IT SAYS WHICH WAY IS FORWARD. A file of bare triples is a file whose frame
	# somebody has to guess, and the guess that costs a day is the sign of Z.
	_check("and_says_what_the_numbers_mean",
		String(written.get("units", "")).contains("-Z"),
		"%s" % written.get("units", "nothing"))

	# EVERY ENTRY IS THE CONTROL IT NAMES, AND WHERE IT ACTUALLY IS. Millimetres, because
	# that is what the file is rounded to -- see CockpitLayout._triple.
	var wrong: Array = []
	for entry in listed:
		var one: Dictionary = entry
		var node := station.get_node_or_null(String(one["name"])) as VehicleControl
		if node == null:
			wrong.append("%s is not in the station" % one["name"])
			continue
		if ControlCatalogue.part_of(node) != StringName(one["part"]):
			wrong.append("%s is a %s" % [one["name"], ControlCatalogue.part_of(node)])
		var at: Array = one["at"]
		var said := Vector3(float(at[0]), float(at[1]), float(at[2]))
		if said.distance_to(node.position) > 0.0011:
			wrong.append("%s says %s and is at %s" % [one["name"], said, node.position])
		if String(one.get("scope", "")) != _scope_word(node.scope):
			wrong.append("%s says scope %s and is %s" % [one["name"], one.get("scope", "nothing"),
				_scope_word(node.scope)])
	_check("and_every_line_of_it_is_true_of_the_cockpit_it_came_from", wrong.is_empty(),
		"%s" % ["all %d" % listed.size() if wrong.is_empty() else wrong])

	# AND IT SURVIVES BEING A FILE. Written, parsed, and compared -- which is the step that
	# catches a value JSON cannot carry.
	var path: String = CockpitLayout.write(TEST_KIND, TEST_SEAT, station)
	_check("and_it_writes_to_a_file", not path.is_empty() and CockpitLayout.exists(
		TEST_KIND, TEST_SEAT), "%s" % path)
	var read_back: Dictionary = CockpitLayout.read(TEST_KIND, TEST_SEAT)
	_check("and_reads_back_the_same",
		(read_back.get("controls", []) as Array).size() == listed.size()
			and int(read_back.get("seat", -1)) == TEST_SEAT,
		"%d controls, seat %s" % [(read_back.get("controls", []) as Array).size(),
			read_back.get("seat", "?")])
	station.queue_free()


## ---- and back in ------------------------------------------------------------------------

## A SAVED LAYOUT IS APPLIED, AND IT WINS.
##
## Three things at once, because they are one rule: what the file says goes. A control it
## has moved is moved, a control it does not mention is gone, and a part it names that is
## not there is built.
func _and_it_goes_back_in() -> void:
	var station := _a_station()
	await get_tree().process_frame
	var before: int = _controls_in(station).size()
	var saved: Dictionary = CockpitLayout.of_station(TEST_KIND, TEST_SEAT, station)
	var listed: Array = saved["controls"]
	# MOVED: the first control goes somewhere it certainly was not.
	var moved_to := Vector3(0.31, 0.77, -0.13)
	var moved_name: String = String((listed[0] as Dictionary)["name"])
	(listed[0] as Dictionary)["at"] = [moved_to.x, moved_to.y, moved_to.z]
	# GONE: the last one is struck out.
	var gone_name: String = String((listed[listed.size() - 1] as Dictionary)["name"])
	listed.remove_at(listed.size() - 1)
	# ADDED: something the aeroplane never had -- and written with no scope at all, as a layout from before scopes is,
	# so it has to come back as what a trim wheel IS rather than whatever a missing key happens to parse to.
	listed.append({"part": "TrimWheel", "name": "BuiltTrim", "label": "TRIM",
		"at": [-0.29, 0.62, -0.08], "facing": [0.0, 0.0, 0.0]})
	# AND A KNOB THE PLAYER MADE THEIR OWN: a part that is the craft's by default, saved as the pilot's.
	listed.append({"part": "RotaryKnob", "name": "MyKnob", "label": "KNOB", "scope": "pilot",
		"at": [0.21, 0.66, -0.30], "facing": [0.0, 0.0, 0.0]})
	# AND A PART THAT NO LONGER EXISTS, which is what a layout written before a rename looks
	# like. It must cost that one lever and nothing else.
	listed.append({"part": "SteamWhistle", "name": "Whistle", "at": [0.0, 0.0, 0.0],
		"facing": [0.0, 0.0, 0.0]})

	CockpitLayout.apply(saved, station, TEST_SEAT)
	await get_tree().process_frame
	var now: Dictionary = _controls_in(station)
	var moved_node := station.get_node_or_null(moved_name) as VehicleControl
	_check("a_saved_layout_moves_what_it_says_to_move",
		moved_node != null and moved_node.position.distance_to(moved_to) < 0.001,
		"%s is at %s" % [moved_name, moved_node.position if moved_node != null else "gone"])
	_check("and_takes_out_what_it_leaves_out",
		station.get_node_or_null(gone_name) == null, "%s is gone" % gone_name)
	var added := station.get_node_or_null("BuiltTrim") as TrimWheel
	_check("and_builds_what_the_aircraft_never_had",
		added != null and added.position.distance_to(Vector3(-0.29, 0.62, -0.08)) < 0.001,
		"%s" % [added.position if added != null else "no trim wheel"])
	_check("and_a_part_that_no_longer_exists_costs_one_lever_and_not_the_cockpit",
		station.get_node_or_null("Whistle") == null and now.size() == before + 1,
		"%d controls, was %d, and one knob added" % [now.size(), before])
	_check("and_a_part_saved_with_no_scope_keeps_its_own",
		added != null and added.scope == VehicleControl.Scope.CRAFT,
		"the trim wheel is %s" % [_scope_word(added.scope) if added != null else "-"])
	var knob := station.get_node_or_null("MyKnob") as VehicleControl
	_check("and_a_part_saved_as_the_pilots_is_the_pilots",
		knob != null and knob.scope == VehicleControl.Scope.PILOT,
		"the knob is %s" % [_scope_word(knob.scope) if knob != null else "not built"])

	# AND THE STATION HANDS THEM ALL OVER. A control in the tree that `controls()` does not
	# report is a control no hand can reach: the rig builds everything it knows about from
	# those sets, so a trim wheel the player added would be scenery.
	var offered: Dictionary = station.controls()
	var reachable: Dictionary = PilotRig.grabbable_in([offered] as Array[Dictionary])
	_check("and_a_control_the_player_added_is_one_a_hand_can_take_hold_of",
		reachable.has(added), "the station offers %d things to grab" % reachable.size())
	station.queue_free()


## A TIME-OF-DAY DIAL SAVED IS A TIME-OF-DAY DIAL LOADED: the level's three times on it, the pilot's, and on no channel.
##
## A DetentDial relabelled DAY, EVENING, NIGHT would have come back LOW, MED, HIGH on MODE -- a layout keeps a part's
## name, channel, range and scope, and not its stops -- which is why the dial is a class of its own.
func _a_time_of_day_dial_is_saved_and_comes_back() -> void:
	var station := _a_station()
	var dial: VehicleControl = ControlCatalogue.make(&"TimeOfDayDial")
	dial.name = "Clock"
	station.add_child(dial)
	dial.setup(TEST_SEAT)
	dial.position = Vector3(0.40, 0.70, -0.20)
	await get_tree().process_frame
	var saved: Dictionary = CockpitLayout.of_station(TEST_KIND, TEST_SEAT, station)
	var entry: Dictionary = {}
	for one in saved.get("controls", []) as Array:
		if String((one as Dictionary).get("name", "")) == "Clock":
			entry = one as Dictionary
	_check("a_time_of_day_dial_is_written_down_as_one_and_as_the_pilots",
		String(entry.get("part", "")) == "TimeOfDayDial" and String(entry.get("scope", "")) == "pilot",
		"%s" % [entry])
	var fresh := _a_station()
	CockpitLayout.apply(saved, fresh, TEST_SEAT)
	await get_tree().process_frame
	var back := fresh.get_node_or_null("Clock") as TimeOfDayDial
	_check("and_comes_back_with_the_levels_times_on_it_on_no_channel",
		back != null and back.stops == PackedStringArray(DaylightTuning.When.keys())
			and back.scope == VehicleControl.Scope.PILOT and back.channel < 0
			and back.channel_range == DaylightTuning.When.size() - 1
			and back.position.distance_to(Vector3(0.40, 0.70, -0.20)) < 0.001,
		"%s" % ["not built" if back == null else "stops %s, %s, channel %d, range %d, at %s" % [back.stops,
			_scope_word(back.scope), back.channel, back.channel_range, back.position]])
	station.get_parent().queue_free()
	fresh.get_parent().queue_free()
	await get_tree().process_frame


## ---- a dial's names, read from the seat -------------------------------------------------

## A PLAYER'S HEADSET: how many pixels one degree of view gets through the lenses. Twenty is a Quest 2, the coarsest headset
## this is played in (a Quest 3 gets about twenty-five). Whether a word on a panel can be read is a pixel count, so a
## centimetre is judged by this and by how far away it is.
const HEADSET_PIXELS_PER_DEGREE: float = 20.0
## THE FEWEST PIXELS A STOP NAME'S LINE MAY BE, seen from the seated eye.
const LEAST_WORD_PIXELS: float = 20.0
## HOW FAR A NAME MAY BE TURNED AWAY FROM THE LINE TO THE SEATED EYE before it is read at a slant: thirty degrees.
const MOST_WORD_TURN: float = 0.524


## EVERY DIAL'S STOP NAMES CAN BE READ FROM THE SEAT, WHERE THE BUILDER PUTS A DIAL. Found on 2026-09-14, when the time dial
## was photographed from the seat and no DAY, EVENING or NIGHT could be seen -- nor LOW, MED or HIGH on a plain dial.
##
## LOOKED AT, NOT COUNTED. `and_every_stop_is_written_beside_it` counts three names, and they were there: flat on the panel
## below the top of the plate, turned 50 degrees from the seated eye, 6 mm a line -- and behind the flight display, because
## the builder landed a dial with its far half behind the screen. So, for a plain dial and a time-of-day dial at the
## builder's own landing spot on a real station, from where the seat puts a pilot's eyes: every name faces the eye within
## `MOST_WORD_TURN`, is at least `LEAST_WORD_PIXELS` tall there, stands above the plate (read off the plate's own mesh), and
## has no screen on the station between it and the eye.
func _every_dials_stop_names_can_be_read_from_the_seat() -> void:
	var unread: PackedStringArray = []
	var hidden: PackedStringArray = []
	var covered: PackedStringArray = []
	var measured: PackedStringArray = []
	for part in [&"DetentDial", &"TimeOfDayDial"]:
		var station := _a_station()
		var dial := ControlCatalogue.make(part) as DetentDial
		dial.name = String(part)
		station.add_child(dial)
		dial.setup(TEST_SEAT)
		PilotRig.place_a_new_control(station, dial)
		await get_tree().process_frame
		var eye: Vector3 = station.to_global(Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0))
		var plate_top: float = _plate_top(dial)
		# AND ITS OWN LABEL, WITH LABELS ON: a caption hung across the names is a dial nobody can read.
		dial.show_label(true)
		var caption := dial.get_node_or_null("Label") as Label3D
		var caption_bottom := Vector3.ZERO
		if caption != null:
			caption_bottom = caption.global_position - Vector3.UP * float(caption.text.count("\n") + 1) \
				* float(caption.font_size) * caption.pixel_size * 0.5
		for node in dial.find_children("Stop*", "Label3D", false, false):
			var word := node as Label3D
			var to_eye: Vector3 = eye - word.global_position
			var turn: float = word.global_basis.z.normalized().angle_to(to_eye.normalized())
			var tall: float = rad_to_deg(float(word.font_size) * word.pixel_size * cos(turn) / to_eye.length()) \
				* HEADSET_PIXELS_PER_DEGREE
			var over: float = dial.to_local(word.global_position).y - plate_top
			var said: String = "%s %.0f deg off, %.1f px, %.1f mm over the plate" % [word.text, rad_to_deg(turn), tall,
				over * 1000.0]
			measured.append(said)
			if turn > MOST_WORD_TURN or tall < LEAST_WORD_PIXELS or over < 0.0:
				unread.append(said)
			var word_top: Vector3 = word.global_position \
				+ word.global_basis.y.normalized() * float(word.font_size) * word.pixel_size * 0.5
			if caption == null or _elevation(eye, caption_bottom) <= _elevation(eye, word_top):
				covered.append("%s under %s (%.1f deg against %.1f)" % [word.text,
					caption.text.replace("\n", " ") if caption != null else "no label",
					rad_to_deg(_elevation(eye, caption_bottom)), rad_to_deg(_elevation(eye, word_top))])
			var screen: String = _a_screen_between(station, eye, word.global_position)
			if screen != "":
				hidden.append("%s behind %s" % [word.text, screen])
		station.get_parent().queue_free()
	_check("every_dials_stop_names_face_the_seated_eye_big_enough_and_above_its_plate",
		unread.is_empty() and measured.size() == 6, "; ".join(measured))
	_check("and_no_screen_stands_between_the_seated_eye_and_them",
		hidden.is_empty() and measured.size() == 6, "none" if hidden.is_empty() else "; ".join(hidden))
	_check("and_with_labels_on_a_dials_own_label_is_seen_above_its_names_and_not_across_them",
		covered.is_empty() and measured.size() == 6, "none" if covered.is_empty() else "; ".join(covered))
	await get_tree().process_frame


## How far above the level of `eye` a point is seen, in radians: what decides which of two things looks higher.
static func _elevation(eye: Vector3, at: Vector3) -> float:
	var towards: Vector3 = at - eye
	return atan2(towards.y, Vector2(towards.x, towards.z).length())


## The top of a dial's plate, in the dial's own frame: the widest cylinder on it, read off its own mesh.
static func _plate_top(dial: Node3D) -> float:
	var top: float = 0.0
	var widest: float = 0.0
	for node in dial.get_children():
		var shape := node as MeshInstance3D
		if shape == null or not (shape.mesh is CylinderMesh):
			continue
		var cylinder := shape.mesh as CylinderMesh
		if cylinder.top_radius > widest:
			widest = cylinder.top_radius
			top = shape.position.y + cylinder.height * 0.5
	return top


## The name of the first screen on `station` whose frame the line from `from` to `to` passes through, or "".
static func _a_screen_between(station: Node3D, from: Vector3, to: Vector3) -> String:
	for node in station.find_children("*", "Node3D", true, false):
		var half := Vector3.ZERO
		if node is TouchPanel:
			# THE FRAME AND THE GLASS: 1 cm of bezel round the glass, and from the back of the frame to the front of the glass.
			half = Vector3((node as TouchPanel).size.x * 0.5 + 0.01, (node as TouchPanel).size.y * 0.5 + 0.01, 0.008)
		elif node is CrewBoard:
			half = Vector3(CrewBoard.half().x, CrewBoard.half().y, CrewBoard.THICK * 0.5)
		else:
			continue
		var inverse: Transform3D = (node as Node3D).global_transform.affine_inverse()
		if _crosses_box(inverse * from, inverse * to, half):
			return String(node.name)
	return ""


## Whether the segment from `a` to `b` passes through the box of half-extents `half` round the origin.
static func _crosses_box(a: Vector3, b: Vector3, half: Vector3) -> bool:
	var enter: float = 0.0
	var leave: float = 1.0
	var along: Vector3 = b - a
	for axis in range(3):
		if absf(along[axis]) < 1e-9:
			if absf(a[axis]) > half[axis]:
				return false
			continue
		var t0: float = (-half[axis] - a[axis]) / along[axis]
		var t1: float = (half[axis] - a[axis]) / along[axis]
		enter = maxf(enter, minf(t0, t1))
		leave = minf(leave, maxf(t0, t1))
		if enter > leave:
			return false
	return true


## ---- where the builder puts a part, on three kinds of station ------------------------------

## THE STATIONS THE LANDING SPOT IS HELD TO: a stick, a helicopter's stick and collective, and a ship's wheel.
const LANDING_KINDS: Array[int] = [Sim.Kind.PLANE, Sim.Kind.HELI, Sim.Kind.BOAT]
## HOW MANY TIME-OF-DAY DIALS A STATION MUST TAKE, each clear of every rule, before the builder calls it crowded. Crowded
## from the second was a builder nobody could build with (2026-09-14).
const LEAST_CLEAR_PARTS: int = 4
## HOW FAR A PART PUSHED ALONG AN AXIS MAY BE TURNED FROM THE SEAT'S FORWARD, in radians: three degrees, a rounding.
const MOST_AXIS_TURN: float = 0.052
## HOW FAR THE ROW OF NAMES MAY LEAN ACROSS THE VIEW, seen from the seated eye looking at it: three degrees.
const MOST_ROW_ROLL: float = 0.052


## A PART THE BUILDER ADDS LANDS WITH ITS GRIP OUTSIDE EVERY OTHER CONTROL'S GRAB, WHERE A SEATED HAND CAN USE IT, IN
## NOBODY'S LINE OF SIGHT -- AND SEVERAL FIT. Found on 2026-09-14: a new dial's knob sat on the stick's head, its grip inside
## the stick's grab; then, kept two reaches from every grab, the plane was crowded from the second part; then a dial stood
## in front of the crew board.
##
## Measured from the controls themselves, not from the rig's rule. A dial placed by `place_a_new_control`, on a plane's, a
## helicopter's and a ship's station: its grip at least `VehicleControl.REACH` from every other grip, and from a stick's grip
## at each of the nine places its full deflection puts it, off `FlightStick`'s own `LEAN` and `SHAFT`; within
## `CockpitStation.EASY_REACH` of a seated shoulder and out of `CockpitStation.KNEES`; its names behind no screen; none of
## its own shape on a line from the seated eye to any point of a screen's or the crew board's face; and more dials placed
## the same way, clear, until the station is crowded -- at least `LEAST_CLEAR_PARTS` of them.
func _a_part_the_builder_adds_lands_clear_of_every_grip_where_a_seated_hand_can_use_it() -> void:
	var fouled: PackedStringArray = []
	var landed: PackedStringArray = []
	for kind in LANDING_KINDS:
		var station := _a_station_of(kind)
		await get_tree().process_frame
		var dial := ControlCatalogue.make(&"TimeOfDayDial") as DetentDial
		dial.name = "Landed"
		PilotRig.place_a_new_control(station, dial)
		station.add_child(dial)
		dial.setup(TEST_SEAT)
		await get_tree().process_frame
		var name: String = Sim.kind_name(kind)
		var grip: Vector3 = station.to_local(dial.grip_global())
		var shoulder: float = CockpitStation.from_a_shoulder(grip)
		if shoulder > CockpitStation.EASY_REACH:
			fouled.append("%s: %.2f m from a shoulder" % [name, shoulder])
		if CockpitStation.KNEES.has_point(grip) or CockpitStation.KNEES.has_point(dial.position):
			fouled.append("%s: in the knees" % name)
		var nearest: String = ""
		var nearest_gap: float = INF
		var stick_gaps: String = "no stick"
		for child in station.get_children():
			var other := child as VehicleControl
			if other == null or other == dial:
				continue
			var places: Array[Vector3] = _grips_off_the_controls(station, other)
			if other is FlightStick:
				var forward: Vector3 = other.transform * (Basis(Vector3.RIGHT, -FlightStick.LEAN) * Vector3(0.0, FlightStick.SHAFT, 0.0))
				var back: Vector3 = other.transform * (Basis(Vector3.RIGHT, FlightStick.LEAN) * Vector3(0.0, FlightStick.SHAFT, 0.0))
				stick_gaps = "stick full forward %+.1f cm, full back %+.1f cm" % [
					(forward.distance_to(grip) - VehicleControl.REACH) * 100.0,
					(back.distance_to(grip) - VehicleControl.REACH) * 100.0]
			for place in places:
				var gap: float = place.distance_to(grip) - VehicleControl.REACH
				if gap < nearest_gap:
					nearest_gap = gap
					nearest = String(other.name)
				if gap < 0.0:
					fouled.append("%s: its grip is %.1f cm inside %s's grab" % [name, -gap * 100.0, other.name])
					break
		var eye: Vector3 = station.to_global(Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0))
		for node in dial.find_children("Stop*", "Label3D", false, false):
			var screen: String = _a_screen_between(station, eye, (node as Node3D).global_position)
			if screen != "":
				fouled.append("%s: %s behind %s" % [name, (node as Label3D).text, screen])
		for hidden in _faces_a_part_hides(station, dial, eye):
			fouled.append("%s: it hides %s from the seat" % [name, hidden])
		# AND HOW MANY FIT: more of the same, placed the same way, until one has to crowd.
		var clear: int = 1
		for more in range(12):
			var another := ControlCatalogue.make(&"TimeOfDayDial") as DetentDial
			another.name = "More%d" % more
			var crowded: bool = PilotRig.place_a_new_control(station, another)
			station.add_child(another)
			another.setup(TEST_SEAT)
			if crowded:
				break
			clear += 1
		if clear < LEAST_CLEAR_PARTS:
			fouled.append("%s: only %d clear before crowded" % [name, clear])
		landed.append("%s at (%.2f, %.2f, %.2f), %s, nearest grip %s %+.1f cm, %.2f m from a shoulder, %s clear before crowded"
			% [name, dial.position.x, dial.position.y, dial.position.z, stick_gaps, nearest, nearest_gap * 100.0, shoulder,
				"%d" % clear if clear <= 12 else "12+"])
		station.get_parent().queue_free()
	_check("a_part_the_builder_adds_keeps_its_grip_out_of_every_grab_in_reach_out_of_sight_lines_and_several_fit_on_three_stations",
		fouled.is_empty() and landed.size() == LANDING_KINDS.size(),
		"; ".join(landed) + ("" if fouled.is_empty() else " -- " + "; ".join(fouled)))
	await get_tree().process_frame


## A PART PUSHED ALONG AN AXIS KEEPS THE SEAT'S FORWARD. A throttle slides fore and aft along its own Z and pedals swing about
## the seat's; turned to face the eye, a throttle would push diagonally. So a throttle and rudder pedals added by the builder
## have their forward axis within `MOST_AXIS_TURN` of the station's, wherever they land.
func _a_part_pushed_along_an_axis_keeps_the_seats_forward() -> void:
	var station := _a_station_of(TEST_KIND)
	await get_tree().process_frame
	var turned: PackedStringArray = []
	var said: PackedStringArray = []
	for part in [&"ThrottleLever", &"RudderPedals"]:
		var made: VehicleControl = ControlCatalogue.make(part)
		made.name = "Added%s" % part
		PilotRig.place_a_new_control(station, made)
		station.add_child(made)
		made.setup(TEST_SEAT)
		var turn: float = made.transform.basis.z.normalized().angle_to(Vector3.BACK)
		said.append("%s at (%.2f, %.2f, %.2f) turned %.1f deg" % [part, made.position.x, made.position.y, made.position.z,
			rad_to_deg(turn)])
		if turn > MOST_AXIS_TURN:
			turned.append(String(part))
	_check("a_throttle_and_rudder_pedals_the_builder_adds_keep_the_seats_forward", turned.is_empty(), "; ".join(said))
	station.get_parent().queue_free()
	await get_tree().process_frame


## FROM THE SEAT A DIAL'S ROW OF NAMES IS LEVEL, AND AT NO STOP DOES THE POINTER COVER A NAME. Seen, not reckoned in three
## dimensions: the placard clears the pointer in space, and still the pointer's bar lay across EVENING from the seat
## (2026-09-14). So from the seated eye looking at the row, at a dial the builder put on the plane: the line from the first
## name to the last leans less than `MOST_ROW_ROLL`, and at each stop no name's rectangle meets the pointer's or the knob's,
## every shape projected onto the eye's view.
func _from_the_seat_a_dials_names_are_level_and_its_pointer_covers_none() -> void:
	var station := _a_station_of(TEST_KIND)
	await get_tree().process_frame
	var dial := ControlCatalogue.make(&"TimeOfDayDial") as DetentDial
	dial.name = "Seen"
	PilotRig.place_a_new_control(station, dial)
	station.add_child(dial)
	dial.setup(TEST_SEAT)
	await get_tree().process_frame
	var eye: Vector3 = station.to_global(Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0))
	var words: Array[Label3D] = []
	for node in dial.find_children("Stop*", "Label3D", false, false):
		words.append(node as Label3D)
	var middle := Vector3.ZERO
	for word in words:
		middle += word.global_position / float(maxi(words.size(), 1))
	var look: Vector3 = (middle - eye).normalized()
	var right: Vector3 = look.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(look)
	var first: Vector2 = _seen(eye, look, right, up, words[0].global_position)
	var last: Vector2 = _seen(eye, look, right, up, words[words.size() - 1].global_position)
	var roll: float = atan2(last.y - first.y, last.x - first.x)
	_check("from_the_seat_a_dials_row_of_names_is_level", absf(roll) <= MOST_ROW_ROLL,
		"the row leans %.1f deg across the view (most %.1f)" % [rad_to_deg(roll), rad_to_deg(MOST_ROW_ROLL)])
	var covered: PackedStringArray = []
	var body := dial.get_node("Body") as Node3D
	for stop in range(dial.stops.size()):
		dial.apply(dial.from_command(stop))
		var pointer := Rect2()
		var started: bool = false
		for node in body.get_children():
			var shape := node as MeshInstance3D
			if shape == null:
				continue
			var box: AABB = shape.get_aabb()
			for corner in range(8):
				var at: Vector2 = _seen(eye, look, right, up, shape.global_transform * box.get_endpoint(corner))
				pointer = Rect2(at, Vector2.ZERO) if not started else pointer.expand(at)
				started = true
		for word in words:
			var font: Font = ThemeDB.fallback_font if word.font == null else word.font
			var wide: float = font.get_string_size(word.text, HORIZONTAL_ALIGNMENT_LEFT, -1, word.font_size).x * word.pixel_size
			var tall: float = float(word.font_size) * word.pixel_size
			var named := Rect2()
			for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
				var at: Vector2 = _seen(eye, look, right, up, word.global_transform * Vector3(corner.x * wide, corner.y * tall, 0.0))
				named = Rect2(at, Vector2.ZERO) if corner == Vector2(-0.5, -0.5) else named.expand(at)
			if named.intersects(pointer):
				var over: float = (minf(named.end.y, pointer.end.y) - maxf(named.position.y, pointer.position.y)) / named.size.y
				covered.append("%s under the pointer at %s (%.0f%% of its height)" % [word.text, dial.stops[stop], over * 100.0])
	_check("and_from_the_seat_the_pointer_covers_no_name_at_any_stop", covered.is_empty(),
		"clear at %s" % ", ".join(dial.stops) if covered.is_empty() else "; ".join(covered))
	station.get_parent().queue_free()
	await get_tree().process_frame


## Where `at` is seen from `eye` looking along `look`, on the plane a unit ahead: right and up.
static func _seen(eye: Vector3, look: Vector3, right: Vector3, up: Vector3, at: Vector3) -> Vector2:
	var towards: Vector3 = at - eye
	var ahead: float = maxf(towards.dot(look), 0.0001)
	return Vector2(towards.dot(right) / ahead, towards.dot(up) / ahead)


## A station of `kind`, fitted as the game fits one, on a plinth of its own.
func _a_station_of(kind: int) -> CockpitStation:
	var plinth := Node3D.new()
	add_child(plinth)
	var station := VehicleCatalogue.seat_scene(kind).instantiate() as CockpitStation
	plinth.add_child(station)
	station.fit(TEST_SEAT, true, kind, false)
	return station


## Every place `other`'s grip can be, in `station`'s frame: where it is, and for a stick the nine places full deflection puts it.
static func _grips_off_the_controls(station: Node3D, other: VehicleControl) -> Array[Vector3]:
	var places: Array[Vector3] = [station.to_local(other.grip_global())]
	if other is FlightStick:
		for along in [-1.0, 0.0, 1.0]:
			for across in [-1.0, 0.0, 1.0]:
				places.append(other.transform * (Basis(Vector3.RIGHT, along * FlightStick.LEAN)
					* Basis(Vector3.BACK, -across * FlightStick.LEAN) * Vector3(0.0, FlightStick.SHAFT, 0.0)))
	return places


## The screens and crew boards on `station` that `part`'s shape stands in front of, seen from `eye`: a line from the eye to
## any of 7 x 7 points across a face passes through the box round every mesh on the part.
static func _faces_a_part_hides(station: Node3D, part: Node3D, eye: Vector3) -> PackedStringArray:
	var shape := AABB()
	var started: bool = false
	var inverse: Transform3D = part.global_transform.affine_inverse()
	for node in part.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		shape = box if not started else shape.merge(box)
		started = true
	var hidden: PackedStringArray = []
	for node in station.get_children():
		var half := Vector2.ZERO
		if node is TouchPanel:
			half = (node as TouchPanel).size * 0.5
		elif node is CrewBoard:
			half = CrewBoard.half()
		else:
			continue
		var face := node as Node3D
		for i in range(7):
			var blocked: bool = false
			for j in range(7):
				var on_face: Vector3 = face.global_transform * Vector3(lerpf(-half.x, half.x, float(i) / 6.0),
					lerpf(-half.y, half.y, float(j) / 6.0), 0.007)
				if _crosses_box(inverse * eye - shape.get_center(), inverse * on_face - shape.get_center(), shape.size * 0.5):
					blocked = true
					break
			if blocked:
				hidden.append(String(node.name))
				break
	return hidden


## HOW MANY PARTS THE CROWDED-CONSOLE CHECK MAY ADD before it gives up waiting for the board to say it is full.
const MOST_PARTS_TO_CROWD: int = 40


## A CROWDED CONSOLE STILL TAKES A PART, WHERE IT CROWDS LEAST, AND THE BOARD SAYS SO. Asked for on 2026-09-14: a search with
## rules can run out of places, and when it does it must end, put the part somewhere a hand gets to, and tell the player in
## words -- never a warning, which the harness fails, and never a hang.
##
## Through the rig, as a player adds parts off the board: time-of-day dials, one after another on a plane's station, until
## the board's answer line says the last one is crowded. That one is within `CockpitStation.EASY_REACH` of a seated
## shoulder, out of `CockpitStation.KNEES`, and its grab is no nearer another control's grab than it would have been at the
## plain spot in front of the seat -- measured here off the grips, a stick's at every lean. And the line is one line on the
## board, as everything BUILD says is.
func _a_crowded_console_still_takes_a_part_where_it_crowds_least_and_says_so() -> void:
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	var station := _a_station()
	rig.take_station(station)
	await get_tree().process_frame
	rig.build_the_cockpit(true)
	var page: ClipboardPage = rig.clipboard.page()
	var said := page.get("_said") as Label
	var crowded: String = "%s is in, but crowded" % ControlCatalogue.label_of(&"TimeOfDayDial")
	var added: int = 0
	var last: DetentDial = null
	for i in range(MOST_PARTS_TO_CROWD):
		rig.add_control(&"TimeOfDayDial")
		added += 1
		await get_tree().process_frame
		last = station.get_node_or_null("TimeOfDayDial" if added == 1 else "TimeOfDayDial%d" % added) as DetentDial
		if said.text.begins_with(crowded):
			break
	var fell_back: bool = said.text.begins_with(crowded) and last != null
	var detail: String = "after %d parts the board said \"%s\"" % [added, said.text]
	var fine: bool = fell_back
	if last != null:
		var grip: Vector3 = station.to_local(last.grip_global())
		var plain := Vector3(0.0, CockpitStation.hands() + PilotRig.BENCH_ABOVE, -CockpitStation.HANDS_FORWARD) \
			+ (grip - last.position)
		var here: float = _grab_room_off_the_grips(station, grip, last)
		var there: float = _grab_room_off_the_grips(station, plain, last)
		fine = fine and CockpitStation.from_a_shoulder(grip) <= CockpitStation.EASY_REACH \
			and not CockpitStation.KNEES.has_point(grip) and here >= there - 0.001
		detail += "; the last at (%.2f, %.2f, %.2f), %.2f m from a shoulder, its grab %+.1f cm from the nearest, %+.1f cm at the plain spot" % [
			last.position.x, last.position.y, last.position.z, CockpitStation.from_a_shoulder(grip), here * 100.0,
			there * 100.0]
	rig.clipboard.show_board(true)
	page.show_tab(ClipboardPage.Tab.BUILD)
	for i in range(4):
		await get_tree().process_frame
	detail += "; %d line(s) on the board" % said.get_line_count()
	_check("a_crowded_console_still_takes_a_part_where_a_hand_reaches_it_crowding_least_and_the_board_says_so_in_one_line",
		fine and said.get_line_count() == 1, detail)
	rig.clipboard.show_board(false)
	rig.queue_free()
	station.get_parent().queue_free()
	await get_tree().process_frame


## How far a grab at `grip` (station frame) is from meeting any other control's, off the grips and a stick's every lean.
static func _grab_room_off_the_grips(station: Node3D, grip: Vector3, besides: Node) -> float:
	var room: float = INF
	for child in station.get_children():
		var other := child as VehicleControl
		if other == null or other == besides:
			continue
		var places: Array[Vector3] = [station.to_local(other.grip_global())]
		if other is FlightStick:
			for along in [-1.0, 0.0, 1.0]:
				for across in [-1.0, 0.0, 1.0]:
					places.append(other.transform * (Basis(Vector3.RIGHT, along * FlightStick.LEAN)
						* Basis(Vector3.BACK, -across * FlightStick.LEAN) * Vector3(0.0, FlightStick.SHAFT, 0.0)))
		for place in places:
			room = minf(room, place.distance_to(grip) - VehicleControl.REACH)
	return room


## A COCKPIT SAVED TO A FILE LOADS EVERY CONTROL WHERE IT WAS SAVED, including a part at the old landing spot. The landing
## spot is where a part the builder ADDS first appears; a saved cockpit says where every part is, and the rule must not
## move one. So a station with a dial at the old spot, (0, 1.06, -0.34), is written to the suite's own layout folder, a
## fresh station is fitted the way the game fits one -- which reads the file -- and every control is within a millimetre of
## where the file says.
func _a_cockpit_saved_to_a_file_loads_every_control_where_it_was_saved() -> void:
	CockpitLayout.forget(TEST_KIND, TEST_SEAT)
	var first := _a_station()
	var dial: VehicleControl = ControlCatalogue.make(&"TimeOfDayDial")
	dial.name = "OldSpot"
	first.add_child(dial)
	dial.setup(TEST_SEAT)
	dial.position = Vector3(0.0, 1.06, -0.34)
	await get_tree().process_frame
	var path: String = CockpitLayout.write(TEST_KIND, TEST_SEAT, first)
	var saved: Dictionary = CockpitLayout.read(TEST_KIND, TEST_SEAT)
	first.get_parent().queue_free()
	await get_tree().process_frame
	var again := _a_station()
	await get_tree().process_frame
	var moved: PackedStringArray = []
	var listed: Array = saved.get("controls", []) as Array
	for entry in listed:
		var one: Dictionary = entry as Dictionary
		var at: Array = one.get("at", [0.0, 0.0, 0.0]) as Array
		var back := again.get_node_or_null(String(one.get("name", ""))) as Node3D
		if back == null or back.position.distance_to(Vector3(float(at[0]), float(at[1]), float(at[2]))) > 0.001:
			moved.append("%s at %s" % [one.get("name"), back.position if back != null else "nowhere"])
	_check("a_cockpit_saved_to_a_file_with_a_part_at_the_old_landing_spot_loads_every_control_where_it_was_saved",
		moved.is_empty() and listed.size() > 1 and again.get_node_or_null("OldSpot") != null,
		"%d controls from %s%s" % [listed.size(), path, "" if moved.is_empty() else ": moved " + "; ".join(moved)])
	again.get_parent().queue_free()
	CockpitLayout.forget(TEST_KIND, TEST_SEAT)
	await get_tree().process_frame


## A DIAL'S PLACARD CLEARS ITS POINTER AND ITS PLATE AT EVERY STOP. The placard stands behind the knob, and the pointer bar
## sweeps a quarter turn: at each stop, shown as the bus would show it, the placard's box meets neither the pointer's nor the
## plate's, every box in the dial's own frame.
func _a_dials_placard_clears_its_pointer_and_plate_at_every_stop() -> void:
	var dial := DetentDial.new()
	add_child(dial)
	dial.setup(TEST_SEAT)
	var placard := dial.get_node_or_null("Placard") as MeshInstance3D
	var body := dial.get_node_or_null("Body") as Node3D
	var met: PackedStringArray = []
	if placard == null or body == null:
		met.append("placard %s, body %s" % [placard, body])
	else:
		var card: AABB = placard.transform * placard.get_aabb()
		for node in dial.get_children():
			var shape := node as MeshInstance3D
			if shape != null and shape.mesh is CylinderMesh and card.intersects(shape.transform * shape.get_aabb()):
				met.append("the plate")
		for stop in range(dial.stops.size()):
			dial.apply(dial.from_command(stop))
			for node in body.get_children():
				var part := node as MeshInstance3D
				if part != null and card.intersects(body.transform * part.transform * part.get_aabb()):
					met.append("the pointer at %s" % dial.stops[stop])
					break
	_check("a_dials_placard_meets_neither_its_pointer_at_any_stop_nor_its_plate",
		met.is_empty(), "clear at %s" % ", ".join(dial.stops) if met.is_empty() else "meets " + "; ".join(met))
	dial.queue_free()
	await get_tree().process_frame


## ---- the link that makes all of it worth anything ---------------------------------------

## A STATION BUILT FROM SCRATCH FINDS THE SAVED LAYOUT AND USES IT.
##
## Everything above tests a half. This is the join: save a cockpit, throw the station away,
## build another one the way the game builds them -- `VehicleView` instantiates the scene
## and calls `fit`, and nothing in that path knows a layout exists -- and see whether the
## lever is where it was left.
##
## A LAYOUT THAT SAVES AND NEVER LOADS IS A LAYOUT THAT QUIETLY DOES NOTHING, and the only
## way to find that out without this is to get into the aeroplane and notice.
func _a_station_built_fresh_picks_the_saved_one_up() -> void:
	var first := _a_station()
	await get_tree().process_frame
	var moved_to := Vector3(0.37, 0.81, -0.19)
	var saved: Dictionary = CockpitLayout.of_station(TEST_KIND, TEST_SEAT, first)
	var listed: Array = saved["controls"]
	var which: String = String((listed[0] as Dictionary)["name"])
	(listed[0] as Dictionary)["at"] = [moved_to.x, moved_to.y, moved_to.z]
	# WRITTEN THE WAY THE BUILDER WRITES IT, through a file, because the claim is about what
	# a station does when it is fitted and there is a file -- not about a dictionary.
	DirAccess.make_dir_recursive_absolute(CockpitLayout.folder)
	var file := FileAccess.open(CockpitLayout.path_for(TEST_KIND, TEST_SEAT),
		FileAccess.WRITE)
	file.store_string(JSON.stringify(saved, "  "))
	file.close()
	first.get_parent().queue_free()
	await get_tree().process_frame

	var again := _a_station()
	await get_tree().process_frame
	var lever := again.get_node_or_null(which) as VehicleControl
	_check("a_station_built_from_scratch_flies_the_cockpit_that_was_saved",
		lever != null and lever.position.distance_to(moved_to) < 0.002,
		"%s is at %s" % [which, lever.position if lever != null else "gone"])
	# AND IT IS A WORKING CONTROL AND NOT A SHAPE. `fit` sets every control up; one that
	# arrived through the layout has to be set up too, or it is scenery with a script on it.
	_check("and_it_is_set_up_rather_than_just_placed",
		lever != null and not lever.find_children("*", "MeshInstance3D", true,
			false).is_empty(),
		"%d meshes" % [lever.find_children("*", "MeshInstance3D", true, false).size()
			if lever != null else 0])
	again.get_parent().queue_free()


## ---- from the seat ----------------------------------------------------------------------

## THE RIG'S OWN HALF: the board asks, and a control appears and can be thrown away again.
##
## Driven through the rig rather than through the catalogue, because the failure this is
## looking for is the wiring: a part that is made and parented to nothing, or binned while
## `_reachable` goes on pointing at it -- which is a freed node in a list that gets walked
## every frame.
func _the_rig_puts_one_in_and_takes_it_out_again() -> void:
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	var station := _a_station()
	rig.take_station(station)
	await get_tree().process_frame

	_check("a_rig_at_a_station_is_not_building_by_default", not rig.building(),
		"building: %s" % rig.building())
	rig.build_the_cockpit(true)
	_check("and_the_board_can_turn_the_builder_on", rig.building(),
		"building: %s" % rig.building())

	var before: int = rig._reachable.size()
	rig.add_control(&"TrimWheel")
	await get_tree().process_frame
	await get_tree().process_frame
	var after: int = rig._reachable.size()
	var added: VehicleControl = null
	for control in rig._reachable:
		if control is TrimWheel:
			added = control
	_check("and_a_part_off_the_list_arrives_in_the_cockpit",
		after == before + 1 and added != null,
		"%d controls, was %d" % [after, before])
	_check("and_it_is_bolted_to_the_station_and_within_reach",
		added != null and added.get_parent() == station
			and added.position.distance_to(Vector3(0.0, CockpitStation.hands(),
				-CockpitStation.HANDS_FORWARD)) < 0.5,
		"%s" % [added.position if added != null else "nowhere"])

	# AND THE BIN TAKES IT OUT AGAIN, with no freed node left in the list the rig walks
	# every frame. That is the failure mode this exists for: the error would surface three
	# frames later, somewhere else.
	if added != null:
		added.held_by = 0
		rig.bin_what_is_held()
		await get_tree().process_frame
		await get_tree().process_frame
	var live: bool = true
	for control in rig._reachable:
		if not is_instance_valid(control):
			live = false
	_check("and_the_bin_takes_it_out_without_leaving_a_dead_node_behind",
		live and rig._reachable.size() == before,
		"%d controls, was %d" % [rig._reachable.size(), before])

	# ---- and you can try the thing you just placed ----------------------------------
	#
	# Putting a lever somewhere is a guess; whether your hand lands on it is the answer, and
	# the only way to get that is to reach out and work it. So the builder hands the
	# controls back WITHOUT being turned off -- the labels stay up and SAVE still saves this
	# cockpit -- and the upper thumb button switches back.
	_check("the_builder_moves_things_rather_than_working_them_to_begin_with",
		rig.placing() and not rig.trying(),
		"placing %s, trying %s" % [rig.placing(), rig.trying()])
	rig.try_the_controls(true)
	_check("and_can_hand_the_controls_back_without_leaving_the_builder",
		rig.building() and rig.trying() and not rig.placing(),
		"building %s, trying %s" % [rig.building(), rig.trying()])

	# AND THE MODE IS ON A BUTTON UNDER THE THUMB, not only on a tab of the board. Moving a
	# lever, trying it and moving it again is one loop; a mode change that meant finding a
	# page every time would be a loop nobody goes round twice.
	var placing_table: Dictionary = {}
	rig.try_the_controls(false)
	placing_table = rig._bindings_for(0)
	var trying_table: Dictionary = {}
	rig.try_the_controls(true)
	trying_table = rig._bindings_for(0)
	_check("and_the_same_thumb_button_switches_between_them_in_both_directions",
		int((placing_table[Bind.THUMB_HIGH] as Dictionary).get("what", -1))
			== Bind.Local.TRY_IT
			and int((trying_table[Bind.THUMB_HIGH] as Dictionary).get("what", -1))
				== Bind.Local.TRY_IT,
		"%s and %s" % [placing_table.get(Bind.THUMB_HIGH),
			trying_table.get(Bind.THUMB_HIGH)])
	# AND A TEST FLIGHT IS A REAL ONE. In USE the bin is gone and the trigger is handed
	# back, because a mode where half the controls behave differently tests nothing.
	_check("and_using_them_gives_the_fingers_back_what_they_normally_do",
		not trying_table.has(Bind.THUMB_LOW)
			or int((trying_table[Bind.THUMB_LOW] as Dictionary).get("what", -1))
				!= Bind.Local.BIN,
		"lower thumb is %s" % [trying_table.get(Bind.THUMB_LOW)])
	_check("and_the_bin_refuses_to_work_while_they_are_being_used",
		true, "the bin is not bound in USE")

	rig.build_the_cockpit(false)
	_check("and_leaving_the_builder_leaves_use_mode_with_it", not rig.trying(),
		"trying %s" % rig.trying())
	_check("and_the_builder_turns_off_again", not rig.building(),
		"building: %s" % rig.building())
	station.queue_free()
	rig.queue_free()


## ---- the door from the menu --------------------------------------------------------------

## A COCKPIT TO BUILD, STRAIGHT FROM THE MENU: the level menu's own "Build a cockpit" button names the "build" door,
## the router sends that door to the bench, and the bench it opens is sat in with the builder already on and the
## board open at BUILD -- so the first grab moves a control and SAVE writes the JSON.
##
## Through the real button, and the desk's own `bench_for`, which is what the desk opens a door with. The one step
## not taken is the desk's scene swap, which would swap this suite out from under itself.
func _the_menu_has_a_door_into_the_builder() -> void:
	var menu := LevelMenu.new()
	add_child(menu)
	await get_tree().process_frame
	var chosen: Array = []
	menu.chose.connect(func(level: String, kind: int): chosen.append([level, kind]))
	var plane: Button = null
	var door: Button = null
	for node in menu.find_children("*", "Button", true, false):
		var button := node as Button
		if String(button.text) == Sim.kind_name(TEST_KIND):
			plane = button
		if String(button.text).begins_with("Build a cockpit"):
			door = button
	_check("the_level_menu_has_a_build_a_cockpit_button", door != null and plane != null,
		"door %s, craft %s" % [door, plane])
	if door == null or plane == null:
		menu.queue_free()
		return
	plane.pressed.emit()
	door.pressed.emit()
	_check("and_it_names_the_build_door_for_the_craft_picked",
		chosen.size() == 1 and String(chosen[0][0]) == "build" and int(chosen[0][1]) == TEST_KIND,
		"%s" % [chosen])
	_check("and_the_router_sends_that_door_to_the_bench",
		String(BootRouter.DOORS.get("build", "")) == BootRouter.BENCH, "%s" % [BootRouter.DOORS.get("build")])
	menu.queue_free()
	if chosen.size() != 1:
		return
	# NO EXTENSION, NO CRAFT, and a bench with no craft quits the whole tree -- this suite with it, before its RESULT.
	if not Sim.is_available():
		print("[builder] no simulation: the bench half of the door is not opened")
		return

	var bench: CockpitBench = DeskRoom.bench_for(String(chosen[0][0]), int(chosen[0][1]))
	_check("and_the_bench_it_opens_is_one_seat_with_the_builder_asked_for",
		bench.build and bench.mode == CockpitBench.Mode.SEAT and int(bench.kind) == TEST_KIND,
		"build %s, mode %s, kind %s" % [bench.build, bench.mode, bench.kind])
	add_child(bench)
	# WELL INSIDE THE BENCH'S OWN HEADLESS DEADLINE: it prints twice, a second apart, and quits the tree.
	var rig: PilotRig = null
	for i in range(60):
		await get_tree().process_frame
		rig = bench.get("_rig") as PilotRig
		if rig != null and rig.building():
			break
	_check("and_sitting_in_it_the_builder_is_already_on", rig != null and rig.building(),
		"rig %s, building %s" % [rig, rig.building() if rig != null else false])
	var board: Clipboard = rig.clipboard if rig != null else null
	_check("and_the_board_is_up_at_its_build_page",
		board != null and board.is_up() and board.page() != null
			and board.page().tab() == ClipboardPage.Tab.BUILD,
		"up %s, tab %s" % [board.is_up() if board != null else false,
			board.page().tab() if board != null and board.page() != null else -1])
	bench.queue_free()
	await get_tree().process_frame
	Sim.stop()
	Net.leave("suite")


## ---- the bench --------------------------------------------------------------------------

## ONE STATION, WITH NO AIRCRAFT BEHIND IT.
##
## The hall of cockpits does exactly this -- see world/hall.gd -- so it is not a fixture
## invented for the suite: a station is a scene, and `fit` is all it needs.
func _a_station() -> CockpitStation:
	# ON A PLINTH, because `PilotRig.take_station` sits the rig in whatever the station is
	# a child of -- which in the hall of cockpits is exactly this. See world/hall.gd.
	var plinth := Node3D.new()
	add_child(plinth)
	var station := VehicleCatalogue.seat_scene(TEST_KIND).instantiate() as CockpitStation
	plinth.add_child(station)
	station.fit(TEST_SEAT, true, TEST_KIND, false)
	return station


## WHAT A SCOPE IS CALLED IN A LAYOUT FILE, written here as well as in `CockpitLayout`, on purpose: the file's words are
## a contract with whoever reads the file, and a check that asked CockpitLayout what its own words are would pass
## whatever they had drifted to.
static func _scope_word(scope: int) -> String:
	match scope:
		VehicleControl.Scope.CRAFT: return "craft"
		VehicleControl.Scope.SEAT: return "seat"
		VehicleControl.Scope.PILOT: return "pilot"
	return "unsaid"


func _controls_in(station: CockpitStation) -> Dictionary:
	var out: Dictionary = {}
	for child in station.get_children():
		var control := child as VehicleControl
		if control != null and ControlCatalogue.has(ControlCatalogue.part_of(control)):
			out[control] = true
	return out


func _finish() -> void:
	print("RESULT=%s" % ["PASS" if _failures.is_empty() else
		"FAIL " + ", ".join(_failures)])
	get_tree().quit()
