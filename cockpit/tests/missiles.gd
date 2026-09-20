extends Node
## Headless: a missile, from the pilot's finger to the smoke it leaves -- through the level, the rig and the keys,
## against the real simulation.
##
##   Godot --headless --path cockpit res://tests/missiles.tscn
##
## THE REAL PATH, START TO FINISH. The player gets into a plane the way the clipboard asks for one; master arm, the
## lock and the launch are the desk's own keys, pressed as key events with both codes set; what comes back is the
## simulation's own lock state and missile list; and what is checked on screen is what the level's own MissileYard
## and the seat's own LockSight did with them. Nothing here calls `launch_missile`, and nothing here builds a lock
## state or a missile row for the drawing to be tested against -- a drawing tested against rows this file wrote
## would pass whatever the simulation sends.
##
## THE HEADSET'S HALF IS THE BINDING TABLE, read through a hand actually closed on the stick. On a desk the rig throws
## away what a forced finger would put on the input frame (see `PilotRig.read_controls`), so the frame bits from a
## headset cannot be driven headless; what can be checked is that the hand on this stick is bound to LOCK and LAUNCH,
## and that the help page says so -- which is the table the frame bits are read out of.
##
## Read RESULT=, not the exit code.

const PLANE: int = Sim.Kind.PLANE
## The clipboard suite, for the one question both ask: does the board fit. See `measure_the_board`.
const CLIPBOARD_SUITE := preload("res://tests/clipboard.gd")

var _failures: PackedStringArray = []
var _level: FlightLevel = null
## The surface a missile was seen ending on, wherever in the suite that happened: -1 until then.
var _ended_on: int = -1
## Sections that reached their own end. See the note in tests/feel.gd.
var _sections: int = 0
const SECTIONS: int = 15
## Every missile cue this machine was handed, as it arrived: printed beside the launch, NOT judged here.
## tests/missile_cues judges the launch cue on a launch of its own, because a check in this suite once passed only
## because a later launch happened to get the cue sync was losing. See agents.md,
## "A LAUNCH FROM THE SEAT WAS NEVER HANDED ITS LAUNCH CUE".
var _missile_cues: PackedStringArray = []
## `-- --shot=<dir>`: where a windowed run saves its pictures of the minigun firing, and what the next one is called.
var _shot_dir: String = ""
var _shot_name: String = ""


func _check(label: String, ok: bool, detail: String) -> void:
	print("[missiles] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			_shot_dir = argument.trim_prefix("--shot=")
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(240):
		await get_tree().physics_frame
	# NOT A SKIP. A library without missiles is the thing this suite exists to notice.
	var wired: bool = Sim.client != null and Sim.client.has_method("missile_states") \
		and Sim.client.has_method("lock_states") and Sim.client.has_method("missile_schema")
	_check("the_library_has_missiles", wired, "missile_states, lock_states, missile_schema")
	if not wired:
		_finish()
		return
	var rig: PilotRig = _level.rig
	if not await _the_player_gets_into_a_plane(rig):
		_finish()
		return
	var view: VehicleView = rig.vehicle_view()
	_the_seat_is_fitted_for_missiles(rig, view)
	await _the_board_fits_in_a_whole_aeroplane(rig)
	await _a_hand_on_the_stick_is_bound_to_lock_and_launch(rig, view)
	await _the_board_turns_the_button_labels_off_and_on(rig, view)
	await _in_the_builder_the_controller_says_what_the_builder_binds(rig, view)
	await _safe_refuses_and_says_so(rig, view)
	await _a_heat_seeker_locks_up_a_tailpipe(rig, view)
	await _the_heat_seeker_takes_by_its_cone_and_holds_by_its_gimbal(rig, view)
	await _armed_it_locks_and_the_sight_follows(rig, view)
	var missile: int = await _a_held_launch_key_is_one_missile_off_the_rail(rig, view)
	if missile != 0:
		await _the_motor_burns_lays_a_trail_and_goes_out(missile)
		await _it_ends_once(missile)
	await _the_minigun_is_the_third_station_and_the_trigger_fires_what_is_selected(rig, view)
	_check("every_section_of_the_suite_ran", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	_finish()


## ---- getting into one -------------------------------------------------------------------

func _the_player_gets_into_a_plane(rig: PilotRig) -> bool:
	rig.ask_for_kind(PLANE)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == PLANE and rig.seat_index() == 0:
			break
	var ok: bool = view != null and view.kind == PLANE and rig.seat_index() == 0
	_check("the_player_gets_into_a_plane_at_its_pilot_seat", ok,
		"kind %s, seat %d" % [view.kind if view != null else "-", rig.seat_index()])
	var schema: Dictionary = Sim.missile_schema(PLANE)
	_check("and_the_simulation_says_that_seat_launches",
		(schema.get("launch_seats", []) as Array).has(0) and not (schema.get("stations", []) as Array).is_empty(),
		"%s" % [schema])
	_sections += 1
	return ok


## ---- the cockpit ------------------------------------------------------------------------

## A LAUNCH SEAT GETS A LOCK SIGHT, A MASTER ARM SWITCH AND A STICK THAT LAUNCHES -- and a seat the simulation does
## not name gets none of them. The negative half is the airliner: a column with a launch button on it would be a
## dead switch, which this project already has a rule about.
func _the_seat_is_fitted_for_missiles(rig: PilotRig, view: VehicleView) -> void:
	var station: CockpitStation = view.station_for(rig.seat_index())
	var sight: Node = station.find_child("LockSight", true, false) if station != null else null
	var arm := station.get_node_or_null("MasterArm") as ToggleSwitch if station != null else null
	var stick := station.controls().get("stick") as FlightStick if station != null else null
	_check("a_launch_seat_has_a_lock_sight", sight is LockSight, "%s" % [sight])
	_check("and_a_master_arm_switch_on_the_arm_channel",
		arm != null and arm.channel == Sim.Channel.MASTER, "%s" % [arm])
	_check("and_a_stick_that_launches", stick != null and stick.launches, "%s" % [stick])
	# THE AIRLINER'S OWN STATION SCENE, fitted as the airliner fits it: a bare CockpitStation has none of the controls
	# `fit` walks, and would pass by having nothing to fit anything to.
	var airliner := (load("res://objects/seats/seat_airliner.tscn") as PackedScene).instantiate() as CockpitStation
	add_child(airliner)
	airliner.fit(0, true, Sim.Kind.AIRLINER)
	_check("and_a_seat_the_simulation_does_not_name_gets_nothing",
		not airliner.launches() and airliner.get_node_or_null("MasterArm") == null,
		"launches %s" % airliner.launches())
	airliner.queue_free()
	_sections += 1


## THE BOARD FITS IN A WHOLE AEROPLANE. The clipboard suite measures a board at one console; a rig sitting in the
## plane is handed every control it can reach across the craft, and the first screenshot of that (2026-09-13) had FEEL
## running off the bottom of the board while the one-console check passed. Same measurement, `measure_the_board`.
func _the_board_fits_in_a_whole_aeroplane(rig: PilotRig) -> void:
	var fits: Dictionary = await CLIPBOARD_SUITE.measure_the_board(rig, self)
	_check("in_a_whole_aeroplane_nothing_on_the_board_runs_off_the_glass",
		(fits["over"] as PackedStringArray).is_empty() and int(fits["measured"]) > 0,
		"%d visible controls%s" % [fits["measured"], "" if (fits["over"] as PackedStringArray).is_empty()
			else ": " + "; ".join((fits["over"] as PackedStringArray).slice(0, 8))])
	_check("and_only_the_pages_that_say_they_scroll_do", (fits["undeclared"] as PackedStringArray).is_empty(),
		"scrolling: %s; declared: %s" % [fits["scrolling"], fits["declared"]])
	_sections += 1


## THROUGH A HAND ACTUALLY CLOSED ON THE STICK: the rig's own grab, then the rig's own binding table.
func _a_hand_on_the_stick_is_bound_to_lock_and_launch(rig: PilotRig, view: VehicleView) -> void:
	var station: CockpitStation = view.station_for(rig.seat_index())
	var stick := station.controls().get("stick") as FlightStick
	# THE HAND PUT BACK ON THE GRIP EVERY FRAME, grip closed: the aeroplane flies out from under a hand placed once (see
	# agents.md). This passed while it ran early in the suite and stopped taking hold when a section went before it.
	for i in range(6):
		rig.force_hand(1, Transform3D(Basis.IDENTITY, stick.to_global(stick._grab_point())))
		rig.force_grip(1, 1.0)
		await get_tree().physics_frame
	rig.force_hand(1, Transform3D(Basis.IDENTITY, stick.to_global(stick._grab_point())))
	var held: bool = stick.is_held()
	var table: Dictionary = rig._bindings_for(1)
	_check("the_right_hand_takes_hold_of_the_stick", held, "held by %d" % stick.held_by)
	_check("and_its_upper_thumb_locks", _bit_of(table.get(Bind.THUMB_HIGH)) == Sim.BUTTON_LOCK,
		"%s" % Bind.says(table.get(Bind.THUMB_HIGH)))
	# WHICHEVER FINGER THIS SEAT LAUNCHES WITH: the trigger, or the lower thumb on a seat whose trigger fires a gun.
	# Either way there has to be one, and it has to put the launch bit on the frame -- so the finger is PRESSED, and
	# the frame the rig's own hand pass builds is read, which is the pass `read_controls` runs in a headset.
	var launch_input: int = Bind.TRIGGER if stick.launch_on_trigger else Bind.THUMB_LOW
	var launch_on: Variant = table.get(launch_input)
	_check("and_one_of_its_fingers_launches", _bit_of(launch_on) == Sim.BUTTON_LAUNCH,
		"%s on the %s (gun on the trigger: %s)" % [Bind.says(launch_on), Bind.input_name(launch_input),
			not stick.launch_on_trigger])
	for input in [launch_input, Bind.THUMB_HIGH]:
		rig.force_input(1, input, 1.0 if input == Bind.TRIGGER else true)
		var frame: Dictionary = {"buttons": 0}
		rig._work_the_hands(frame)
		rig.force_input(1, input, 0.0 if input == Bind.TRIGGER else false)
		rig._work_the_hands({"buttons": 0})
		rig.force_input(1, input, null)
		var wanted: int = Sim.BUTTON_LAUNCH if input == launch_input else Sim.BUTTON_LOCK
		_check("and_pressing_the_%s_puts_%s_on_the_frame" % [Bind.input_name(input).replace(" ", "_"),
			"launch" if wanted == Sim.BUTTON_LAUNCH else "lock"],
			(int(frame.get("buttons", 0)) & wanted) != 0, "buttons %d" % int(frame.get("buttons", 0)))
	# AND THE CONTROLLER IN THAT HAND SAYS SO, beside every finger: what the same live table says each one does. And
	# the two it was asked for by name -- the launch and the lock -- as `Bind` names those bits, not as this file spells
	# them, so a label that showed the wrong finger's words or a stale table fails here.
	for i in range(3):
		await get_tree().process_frame
	var model: ControllerModel = rig.controller_model(1)
	var wrong: PackedStringArray = []
	var labelled: int = 0
	for input in Bind.inputs():
		var written: String = Bind.says(table.get(input))
		var shows: String = model.says(input) if model != null else "<no controller>"
		if shows != written:
			wrong.append("%s shows '%s' where the table says '%s'" % [Bind.input_name(input), shows, written])
		if shows != "":
			labelled += 1
	_check("the_controller_in_that_hand_writes_every_finger_off_its_binding_table",
		model != null and wrong.is_empty() and labelled >= 3,
		"%d fingers labelled%s" % [labelled, "" if wrong.is_empty() else ": " + "; ".join(wrong)])
	var launch_says: String = model.says(launch_input) if model != null else ""
	var lock_says: String = model.says(Bind.THUMB_HIGH) if model != null else ""
	# CONTAINS, because on the fighter the same finger fires the minigun too, and the label says both.
	_check("and_its_launch_finger_says_launch_and_its_upper_thumb_says_lock",
		launch_says.contains(Bind.says(Bind.frame(Sim.BUTTON_LAUNCH))) and lock_says == Bind.says(Bind.frame(Sim.BUTTON_LOCK)),
		"%s: '%s'; upper thumb button: '%s'" % [Bind.input_name(launch_input), launch_says, lock_says])
	var empty: ControllerModel = rig.controller_model(0)
	_check("and_the_empty_left_hand_writes_nothing", empty != null and not empty.is_labelled(),
		"left controller %s, labelled %s" % [empty, empty.is_labelled() if empty != null else null])
	rig.clipboard.show_board(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var said: String = rig.clipboard.page().help_text()
	_check("and_the_help_page_says_so", said.contains("lock the target ahead") and said.contains("launch a missile"),
		"%d lines" % said.split("\n", false).size())
	rig.clipboard.show_board(false)
	await _let_go_of_the_stick(rig, stick)
	await get_tree().process_frame
	_check("and_letting_go_of_the_stick_takes_the_labels_away",
		model != null and not stick.is_held() and not model.is_labelled() and model.says(launch_input) == "",
		"held %s, labelled %s" % [stick.is_held(), model.is_labelled() if model != null else null])
	_sections += 1


## IN THE BUILDER, THE CONTROLLER SAYS WHAT THE BUILDER BINDS. The labels are the hand's live table, and the builder
## merges its own over whatever the hand holds -- so a hand on the stick in the builder is labelled with the builder's
## fingers, not the flight's. Checked against the builder's own table and, for the lower thumb, against what `Bind`
## calls a BIN, so a label source that was flight-only, or that took the builder's words from the table it was checking,
## fails here. Asked for because the builder is getting a snap button and a snap step on the stick, which must be
## labelled the same way.
func _in_the_builder_the_controller_says_what_the_builder_binds(rig: PilotRig, view: VehicleView) -> void:
	var station: CockpitStation = view.station_for(rig.seat_index())
	var stick := station.controls().get("stick") as FlightStick
	rig.build_the_cockpit(true)
	for i in range(6):
		await get_tree().physics_frame
	await _take_hold_of_the_stick(rig, stick)
	var model: ControllerModel = rig.controller_model(1)
	var building: Dictionary = rig._building_bindings(1)
	var wrong: PackedStringArray = []
	for input in building:
		var shows: String = model.says(input) if model != null else "<no controller>"
		if shows != Bind.says(building[input]):
			wrong.append("%s shows '%s' where the builder binds '%s'" % [Bind.input_name(input), shows,
				Bind.says(building[input])])
	_check("in_the_builder_the_controller_writes_the_builders_fingers",
		stick.is_held() and model != null and model.is_labelled() and wrong.is_empty() and building.size() >= 2,
		"held %s, %d builder entries%s" % [stick.is_held(), building.size(),
			"" if wrong.is_empty() else ": " + "; ".join(wrong)])
	var bin: String = Bind.says(Bind.local(Bind.Local.BIN))
	_check("and_its_lower_thumb_says_it_bins_what_you_hold",
		model != null and model.says(Bind.THUMB_LOW) == bin and bin != "",
		"lower thumb button: '%s', a bin is '%s'" % [model.says(Bind.THUMB_LOW) if model != null else "", bin])
	await _let_go_of_the_stick(rig, stick)
	rig.build_the_cockpit(false)
	for i in range(6):
		await get_tree().physics_frame
	_sections += 1


## THE BOARD'S BUTTON LABELS SWITCH, pressed the way a player presses it: the right hand's beam on the switch and a pull
## of the trigger. Off, a hand closed on the stick shows no labels -- while its table still says it launches, so the
## labels went and not the binding. On again, every label is back and reads what the table says.
func _the_board_turns_the_button_labels_off_and_on(rig: PilotRig, view: VehicleView) -> void:
	var station: CockpitStation = view.station_for(rig.seat_index())
	var stick := station.controls().get("stick") as FlightStick
	var switch: CheckButton = null
	for node in rig.clipboard.page().find_children("*", "CheckButton", true, false):
		if (node as CheckButton).text == "BUTTON LABELS":
			switch = node as CheckButton
	_check("the_board_has_a_button_labels_switch_and_it_starts_on", switch != null and switch.button_pressed,
		"%s, on %s" % [switch, switch.button_pressed if switch != null else null])
	if switch == null or stick == null:
		_sections += 1
		return
	await _press_on_the_board_with_the_beam(rig, switch)
	_check("the_right_hands_beam_and_trigger_turn_it_off", not switch.button_pressed, "on %s" % switch.button_pressed)
	var off: Dictionary = await _grab_the_stick_and_read_the_labels(rig, stick)
	_check("off_a_hand_on_the_stick_shows_no_labels_though_its_table_still_launches",
		not bool(off["labelled"]) and int(off["shown"]) == 0 and bool(off["launches"]), "%s" % [off])
	await _press_on_the_board_with_the_beam(rig, switch)
	var on: Dictionary = await _grab_the_stick_and_read_the_labels(rig, stick)
	_check("on_again_every_label_is_back_and_reads_the_table",
		switch.button_pressed and bool(on["labelled"]) and (on["wrong"] as PackedStringArray).is_empty()
			and int(on["shown"]) >= 3, "%s" % [on])
	_sections += 1


## THE BOARD UP, the right hand aimed at `control` on its glass, one pull of the trigger, and the board away again.
##
## RE-AIMED EVERY FRAME. The board is in the left hand of an aeroplane flying at 64 m/s, and a pose worked out once and
## held for six frames points a metre behind the glass by the time the trigger is pulled -- the first run of this pressed
## nothing, while tests/clipboard's same press, on a rig standing still, worked.
func _press_on_the_board_with_the_beam(rig: PilotRig, control: Control) -> void:
	var board: Clipboard = rig.clipboard
	board.show_board(true)
	for i in range(3):
		await get_tree().process_frame
	# down on the third frame, up on the fifth, the hand on the control every frame
	for i in range(8):
		_aim_the_right_hand_at(rig, control)
		if i == 3:
			rig.force_input(1, Bind.TRIGGER, 1.0)
		elif i == 5:
			rig.force_input(1, Bind.TRIGGER, 0.0)
		await get_tree().process_frame
	rig.force_input(1, Bind.TRIGGER, null)
	rig.force_hand(1, null)
	board.show_board(false)
	for i in range(2):
		await get_tree().process_frame


## THE RIGHT HAND 30 cm IN FRONT OF `control` ON THE BOARD'S GLASS, pointing at it, from where the glass is NOW.
func _aim_the_right_hand_at(rig: PilotRig, control: Control) -> void:
	var panel: TouchPanel = rig.clipboard.panel()
	var screen := panel.get("_screen") as SubViewport
	var centre: Vector2 = control.get_global_rect().get_center()
	var on_glass := Vector3((centre.x / float(screen.size.x) - 0.5) * panel.size.x,
		(0.5 - centre.y / float(screen.size.y)) * panel.size.y, 0.0)
	var aimed_at: Vector3 = panel.to_global(on_glass)
	var normal: Vector3 = panel.global_basis.z.normalized()
	var hand_at: Vector3 = aimed_at + normal * 0.30
	rig.force_hand(1, Transform3D(Basis.looking_at(aimed_at - hand_at, panel.global_basis.y.normalized()), hand_at))


## TAKE HOLD OF THE STICK THE WAY A HAND DOES: a TAP of the grip, which latches (`PilotRig.TAP_SECONDS`), with the hand
## put back on the stick's grip every frame -- a forced pose is a place in the world, and the aeroplane flies on out of
## it at 64 m/s. The first run of the label checks held the grip for six frames and then let it open, which is a tap: the
## stick stayed latched in the hand after every "let go".
func _take_hold_of_the_stick(rig: PilotRig, stick: FlightStick) -> void:
	for i in range(8):
		rig.force_hand(1, Transform3D(Basis.IDENTITY, stick.to_global(stick._grab_point())))
		rig.force_grip(1, 1.0 if i < 4 else 0.0)
		await get_tree().physics_frame
	for i in range(3):
		rig.force_hand(1, Transform3D(Basis.IDENTITY, stick.to_global(stick._grab_point())))
		await get_tree().process_frame


## AND LET GO THE WAY A LATCHED HAND DOES: a second tap, and only if it is still held -- a grip held past the tap time
## lets go by opening. Then the hand is handed back.
func _let_go_of_the_stick(rig: PilotRig, stick: FlightStick) -> void:
	rig.force_grip(1, 0.0)
	for i in range(2):
		rig.force_hand(1, Transform3D(Basis.IDENTITY, stick.to_global(stick._grab_point())))
		await get_tree().physics_frame
	if stick.is_held():
		for i in range(8):
			rig.force_hand(1, Transform3D(Basis.IDENTITY, stick.to_global(stick._grab_point())))
			rig.force_grip(1, 1.0 if i < 4 else 0.0)
			await get_tree().physics_frame
	rig.force_hand(1, null)
	for i in range(4):
		await get_tree().physics_frame


## THE RIGHT HAND CLOSED ON THE STICK, what its controller says beside each finger against what its table says, and let
## go again.
func _grab_the_stick_and_read_the_labels(rig: PilotRig, stick: FlightStick) -> Dictionary:
	await _take_hold_of_the_stick(rig, stick)
	var model: ControllerModel = rig.controller_model(1)
	var table: Dictionary = rig._bindings_for(1)
	var wrong: PackedStringArray = []
	var shown: int = 0
	for input in Bind.inputs():
		var says: String = model.says(input) if model != null else ""
		if says != "":
			shown += 1
		if says != Bind.says(table.get(input)):
			wrong.append("%s shows '%s', table '%s'" % [Bind.input_name(input), says, Bind.says(table.get(input))])
	var launches: bool = false
	for input in Bind.inputs():
		if _bit_of(table.get(input)) == Sim.BUTTON_LAUNCH:
			launches = true
	var read: Dictionary = {"held": stick.is_held(), "labelled": model != null and model.is_labelled(), "shown": shown,
		"wrong": wrong, "launches": launches}
	await _let_go_of_the_stick(rig, stick)
	read["let_go"] = not stick.is_held()
	return read


## ---- the target --------------------------------------------------------------------------

## ONE AEROPLANE, STRAIGHT DOWN THE NOSE AND A LITTLE ABOVE IT, put there on the server just before the lock is asked
## for. NOT one flying itself: the first run spawned an autopilot, which turned and climbed away to its recovery height
## and was 0.69 rad off the nose -- outside the radar's cone -- by the time the lock was pressed. An aeroplane with
## nobody in it falls about eleven metres in the second and a half a radar lock takes, which at six hundred metres is
## two hundredths of a radian.
func _a_target_ahead(view: VehicleView) -> void:
	# THE SERVER'S OWN POSE OF THE PLAYER'S AEROPLANE, which is what the seeker looks along -- not the drawn one, and not
	# a nose flattened to the horizon: a second run put the target level with the aeroplane while the aeroplane was in
	# the air with its nose wherever the autopilot-less trim had left it.
	var mine: Dictionary = {}
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			mine = Sim.server.vehicle_state(int((pilot as Dictionary).get("vehicle", 0)))
	var at: Vector3 = mine.get("position", view.global_position) as Vector3
	var facing := Basis(mine.get("basis", view.global_basis.get_rotation_quaternion()) as Quaternion)
	var nose: Vector3 = -facing.z
	var moving: Vector3 = mine.get("velocity", Vector3.ZERO) as Vector3
	# ALONG THE NOSE AND GOING THE SAME WAY AT THE SAME SPEED, so it stays in the cone for as long as a lock takes.
	var where: Vector3 = at + nose * 1200.0 + facing.y * 20.0
	var target: int = int(Sim.server.spawn_vehicle(PLANE, where, atan2(-nose.x, -nose.z), moving))
	var off: float = nose.angle_to(where - at)
	_check("a_target_is_put_ahead", target != 0,
		"server entity %d, %.0f m out, %.3f rad off the server's nose, moving %.0f m/s with it" % [target,
			(where - at).length(), off, moving.length()])
	for i in range(12):
		await get_tree().physics_frame
	_sections += 1


## ---- refused, then armed ----------------------------------------------------------------

## SAFE: THE LAUNCH KEY IS REFUSED, THE SEAT'S LOCK STATE SAYS WHY, AND THE SIGHT SHOWS IT. The refusal is the
## server's; the words on the glass are the server's `why_name`.
func _safe_refuses_and_says_so(rig: PilotRig, view: VehicleView) -> void:
	var before: int = _mine().size()
	await _hold("lock", 3)
	for i in range(30):
		await get_tree().physics_frame
	await _hold("launch", 3)
	for i in range(60):
		await get_tree().physics_frame
	var lock: Dictionary = _my_lock(view, rig)
	_check("safe_the_launch_key_launches_nothing", _mine().size() == before, "%d missile(s)" % _mine().size())
	_check("and_the_seat_is_told_why", not lock.is_empty() and int(lock.get("why", 0)) != 0,
		"why %s (%s)" % [lock.get("why", "-"), lock.get("why_name", "-")])
	var says: String = _sight(view, rig).says()
	_check("and_the_sight_says_safe", says.contains("SAFE"), says.replace("\n", " | "))
	_sections += 1


func _armed_it_locks_and_the_sight_follows(rig: PilotRig, view: VehicleView) -> void:
	# ARMED ALREADY, by the heat section's press -- and not pressed again, which would disarm it.
	_check("and_it_is_still_armed_for_the_radar", bool(Sim.client.craft_systems(view.entity).get("master", false)),
		"%s" % [Sim.client.craft_systems(view.entity).get("master")])
	# THE RADAR STATION, chosen on the station key: it is the seeker that must have a lock before it will launch, so
	# the launch below is the lock's consequence rather than a boresight shot that would go without one.
	var schema: Dictionary = Sim.missile_schema(PLANE)
	var radar: int = -1
	for station in (schema.get("stations", []) as Array):
		if String((station as Dictionary).get("name", "")) == "radar":
			radar = int((station as Dictionary).get("station", -1))
	for press in range(4):
		if int(Sim.client.craft_systems(view.entity).get("weapon", -1)) == radar:
			break
		await _hold("weapon_station", 2)
		for i in range(30):
			await get_tree().physics_frame
	_check("the_station_key_selects_the_radar_station",
		radar >= 0 and int(Sim.client.craft_systems(view.entity).get("weapon", -1)) == radar,
		"weapon %s, radar is station %d" % [Sim.client.craft_systems(view.entity).get("weapon"), radar])
	await get_tree().process_frame
	_check("and_the_sight_names_it", _sight(view, rig).says().contains("RADAR"), _sight(view, rig).says().replace("\n", " | "))
	await _a_target_ahead(view)
	# A LOCK BROKEN BY THE SECOND PRESS IS A LOCK TO ASK FOR AGAIN: press until it is on its way.
	var saw_locking: bool = false
	var said_locking: bool = false
	var locked: bool = false
	for attempt in range(3):
		if int(_my_lock(view, rig).get("phase", 0)) < LockSight.Phase.LOCKING:
			await _hold("lock", 3)
		for i in range(420):
			await get_tree().process_frame
			var phase: int = int(_my_lock(view, rig).get("phase", 0))
			if phase == LockSight.Phase.LOCKING:
				saw_locking = true
				said_locking = said_locking or _sight(view, rig).says().contains("LOCKING")
			if phase == LockSight.Phase.LOCKED:
				locked = true
				break
		if locked:
			break
	_check("pressed_the_lock_goes_through_locking", saw_locking, "phase seen LOCKING")
	_check("and_the_sight_counts_it_up", said_locking, _sight(view, rig).says().replace("\n", " | "))
	_check("and_locks", locked, "phase %s; %s" % [_my_lock(view, rig).get("phase_name", "-"), _where_the_target_is(view)])
	# THE SIGHT FOLLOWS THE LOCK ONE FEED LATER: the station is handed the craft's state after the tick that changed
	# it, so the words are waited for -- a second and a half at most -- rather than read on the same frame.
	var sight: LockSight = _sight(view, rig)
	for i in range(90):
		if sight.says().contains("LOCKED") and sight.shows_the_diamond() and sight.says().contains("SHOOT"):
			break
		await get_tree().process_frame
	_check("and_the_sight_says_locked_with_the_diamond_on_the_glass",
		sight.says().contains("LOCKED") and sight.shows_the_diamond(), sight.says().replace("\n", " | "))
	_check("and_the_server_would_take_a_launch", int(_my_lock(view, rig).get("why", 1)) == 0
		and sight.says().contains("SHOOT"), "why %s" % _my_lock(view, rig).get("why_name", "-"))
	_sections += 1


## ---- heat ------------------------------------------------------------------------------

## A HEAT SEEKER LOCKS AN AEROPLANE FLYING AWAY DOWN ITS NOSE, AND ONE COMING AT IT -- and not one further off than its
## heat can be seen. The heat seeker is ALL-ASPECT, by the lead's decision (ashiato 441b790).
##
## Its own section, and before the radar's, because moving every lock check to the radar would have hidden whether heat
## works at all. The first run pointed heat at an autopilot 0.69 rad off the nose -- ten cones wide -- and it sat in
## SEARCH for a reason that had nothing to do with heat.
##
## What a seeker sees is `heat * aspect / km^2` against the table's `heat_min` (cockpit_world.cpp, `seen_from`): heat is
## 0.15 at idle on anything with an engine, so an unpiloted aeroplane is warm; aspect rises to the table's tail bonus
## looking up the tailpipe. The numbers are printed for both targets so that answer can be checked against them.
func _a_heat_seeker_locks_up_a_tailpipe(rig: PilotRig, view: VehicleView) -> void:
	# THE ARM KEY IS PRESSED ONCE IN THE WHOLE SUITE, HERE. It is a step on the bus, so a second press is SAFE again: the
	# radar section used to press it too, after this section had armed, and eight checks downstream of it failed on
	# "not armed" with every one of their own mechanisms working.
	await _hold("master_arm", 2)
	for i in range(30):
		await get_tree().physics_frame
	_check("the_arm_key_arms_it_on_the_wire", bool(Sim.client.craft_systems(view.entity).get("master", false)),
		"%s" % [Sim.client.craft_systems(view.entity).get("master")])
	var schema: Dictionary = Sim.missile_schema(PLANE)
	var heat: int = -1
	for station in (schema.get("stations", []) as Array):
		if String((station as Dictionary).get("name", "")) == "heat":
			heat = int((station as Dictionary).get("station", -1))
	for press in range(4):
		if int(Sim.client.craft_systems(view.entity).get("weapon", -1)) == heat:
			break
		await _hold("weapon_station", 2)
		for i in range(30):
			await get_tree().physics_frame
	_check("the_station_key_selects_the_heat_station",
		heat >= 0 and int(Sim.client.craft_systems(view.entity).get("weapon", -1)) == heat,
		"weapon %s, heat is station %d" % [Sim.client.craft_systems(view.entity).get("weapon"), heat])

	# TAIL-ON: on the server's nose, going the same way at the same speed, so the seeker looks up its tailpipe.
	var tail: int = _put_a_target_on_the_nose(view, 1200.0, false)
	var locked: bool = await _lock_within(view, rig, 3.0)
	var said: String = _sight(view, rig).says()
	for i in range(90):
		if said.contains("LOCKED") and said.contains("SHOOT"):
			break
		await get_tree().process_frame
		said = _sight(view, rig).says()
	# ON THE AEROPLANE IT WAS POINTED AT: the server's own lock row, whose `target` is in the same numbers as
	# `spawn_vehicle`'s answer. The first run never took a target away, so the head-on case below "locked" with the tail-on
	# aeroplane still sitting down the nose, and its numbers described an aeroplane nobody was locked on.
	var on: int = int(_server_lock().get("target", 0))
	_check("a_heat_seeker_locks_a_target_flying_away_down_its_nose", locked and said.contains("SHOOT") and on == tail,
		"%s; server lock on %d, the target is %d; %s" % [said.replace("\n", " | "), on, tail, _heat_of(view, tail)])
	# LET GO OF IT, so the next target is designated by a press rather than a lock broken by one.
	await _let_go_of_the_lock()
	_despawn(tail)
	for i in range(12):
		await get_tree().physics_frame

	var lock_s: float = float(Sim.missile_type(0).get("lock_s", -1.0))
	# HEAD-ON AND IDLE, 1200 m: SEEN. The tailpipe triples the signature and the nose does not blind it. The first run
	# printed this rather than judging it, and the head-on "lock" it printed was on the tail-on aeroplane, never taken away.
	var head: int = _put_a_target(view, PLANE, 1200.0, 0.0, true)
	var near: Dictionary = await _press_and_watch(2.0)
	_check("a_heat_seeker_locks_an_idle_aeroplane_coming_straight_at_it",
		int(near["phase"]) == LockSight.Phase.LOCKED and int(near["target"]) == head,
		"%s, the target is %d; %s" % [near, head, _heat_of(view, head)])
	# IN THE TABLE'S LOCK TIME, counted from the key going down: never less, and a round trip more at most.
	_check("and_it_locks_in_the_tables_lock_time",
		float(near["locked_after"]) >= lock_s - 0.001 and float(near["locked_after"]) <= lock_s + 0.5,
		"locked %.3f s after the press, lock_s %.2f" % [float(near["locked_after"]), lock_s])
	print("[missiles] HEAD-ON heat: %s" % _heat_of(view, head))
	await _let_go_of_the_lock()
	_despawn(head)
	for i in range(12):
		await get_tree().physics_frame

	# AND NOT FROM 2900 m: idle heat 0.15 is seen head-on to sqrt(0.15 / heat_min) km, 2739 m, and 0.15 / 2.9^2 = 0.0178.
	# Watched for half a second only. A seeker looks for something new only on the press, but an aeroplane coming the
	# other way closes at twice the speed, and a check that watched long enough would not know which it was testing.
	var far: int = _put_a_target(view, PLANE, 2900.0, 0.0, true)
	var faint: String = _heat_of(view, far)
	var nothing: Dictionary = await _press_and_watch(0.5)
	_check("but_not_from_further_than_its_heat_is_seen",
		far != 0 and not bool(nothing["locking"]) and int(nothing["target"]) == 0,
		"%s; at the press %s" % [nothing, faint])
	await _let_go_of_the_lock()
	_despawn(far)
	for i in range(12):
		await get_tree().physics_frame
	_sections += 1


## ---- the cone and the gimbal --------------------------------------------------------------

## THE CONE TAKES A LOCK, THE GIMBAL HOLDS IT, AND A GLIDER IS NEVER SEEN -- each edge of the heat row, on the server's
## own geometry. The cone is asked only when the key is pressed (`best_target`); every tick after that a lock is held
## while its target is inside the gimbal, and LOST a grace after it leaves (cockpit_world.cpp, `step_the_lock`). The
## angles are the table's own cone either side of it, not typed: a cone that changes moves them.
func _the_heat_seeker_takes_by_its_cone_and_holds_by_its_gimbal(rig: PilotRig, view: VehicleView) -> void:
	var row: Dictionary = Sim.missile_type(0)
	var cone: float = float(row.get("cone", -1.0))
	var gimbal: float = float(row.get("gimbal", -1.0))
	_check("the_heat_row_names_a_cone_and_a_wider_gimbal", cone > 0.0 and gimbal > cone,
		"cone %s, gimbal %s" % [row.get("cone"), row.get("gimbal")])
	await _let_go_of_the_lock()

	# OUTSIDE THE CONE AT THE PRESS: nothing, however long it sits there.
	var wide: int = _put_a_target(view, PLANE, 1200.0, cone + 0.03, false)
	var wide_at: float = _angle_off(view, wide)
	var missed: Dictionary = await _press_and_watch(1.0)
	_check("the_cone_takes_nothing_outside_it_at_the_press",
		wide != 0 and not bool(missed["locking"]) and int(missed["target"]) == 0,
		"%s; %.3f rad off the nose at the press, cone %.2f" % [missed, wide_at, cone])
	await _let_go_of_the_lock()
	_despawn(wide)
	for i in range(12):
		await get_tree().physics_frame

	# INSIDE IT AT THE PRESS, AND DRIFTING OUT SIDEWAYS: taken, then held long after the cone is behind it, then lost.
	var drifter: int = _put_a_target(view, PLANE, 1200.0, cone - 0.02, false, DRIFT)
	var drifter_at: float = _angle_off(view, drifter)
	var took: Dictionary = await _press_and_watch(2.0)
	_check("and_takes_a_target_inside_it",
		int(took["phase"]) == LockSight.Phase.LOCKED and int(took["target"]) == drifter,
		"%s, the target is %d; %.3f rad off the nose at the press, cone %.2f" % [took, drifter, drifter_at, cone])
	var held: int = 0
	var dropped: String = ""
	var out_after: float = -1.0
	var ended_after: float = -1.0
	var ended_as: int = -1
	var widest: float = 0.0
	var t: float = 0.0
	while t < 15.0 and int(took["target"]) == drifter:
		await get_tree().physics_frame
		t += Sim.tick_dt()
		var angle: float = _angle_off(view, drifter)
		var phase: int = int(_server_lock().get("phase", 0))
		widest = maxf(widest, angle)
		if out_after < 0.0 and angle >= 0.3 and angle <= 0.5:
			if phase == LockSight.Phase.LOCKED:
				held += 1
			elif dropped == "":
				dropped = "phase %d at %.3f rad" % [phase, angle]
		if out_after < 0.0 and angle > gimbal:
			out_after = t
		if phase != LockSight.Phase.LOCKED:
			ended_after = t
			ended_as = phase
			if out_after < 0.0 and dropped == "":
				dropped = "phase %d at %.3f rad, inside the gimbal" % [phase, angle]
			break
	_check("the_gimbal_holds_a_lock_far_outside_the_cone", held > 0 and dropped == "",
		"%d ticks LOCKED between 0.3 and 0.5 rad; dropped: %s" % [held, dropped if dropped != "" else "never"])
	var dt: float = Sim.tick_dt()
	_check("and_loses_it_a_grace_after_the_target_leaves_the_gimbal",
		out_after >= 0.0 and ended_as == LockSight.Phase.LOST
			and ended_after >= out_after + LOCK_GRACE - 1.5 * dt and ended_after <= out_after + LOCK_GRACE + 0.1,
		"outside the %.2f rad gimbal at %.3f s, phase %d at %.3f s, grace %.2f; widest %.3f rad" % [gimbal, out_after,
			ended_as, ended_after, LOCK_GRACE, widest])
	await _let_go_of_the_lock()
	_despawn(drifter)
	for i in range(12):
		await get_tree().physics_frame

	# THE GRACE, BOTH WAYS: a lock survives its target out of sight for less than `kLockGrace` and is LOST after. No server
	# call puts a vehicle at a pose, and a target on a straight line relative to the launcher leaves the gimbal only once,
	# so it cannot be taken out by angle and brought back. Out of sight is out of sight whatever the reason, though:
	# `seen_from` casts a ray that any hull stops, so an aeroplane put in the line of sight for exactly so long and then
	# taken away is a target unseen for exactly so long. The first check fails on a grace under 0.1 s, the second on one of
	# 0.4 s or more; the gimbal check above pins it between.
	var shy: int = _put_a_target(view, PLANE, 1200.0, 0.0, false)
	var shy_taken: Dictionary = await _press_and_watch(2.0)
	var blink: Dictionary = await _hide_the_target_for(view, shy, BRIEF_HIDE, 1.0)
	_check("a_lock_survives_its_target_out_of_sight_for_less_than_the_grace",
		int(shy_taken["phase"]) == LockSight.Phase.LOCKED and int(shy_taken["target"]) == shy
			and bool(blink["hid"]) and int(blink["first_not_locked"]) == -1,
		"%s; hidden %.2f s behind an aeroplane, then watched 1 s: %s" % [shy_taken, BRIEF_HIDE, blink])
	var eclipse: Dictionary = await _hide_the_target_for(view, shy, LONG_HIDE, 0.0)
	var tick: float = Sim.tick_dt()
	_check("and_is_lost_when_it_stays_out_of_sight_longer",
		bool(eclipse["hid"]) and int(eclipse["first_not_locked"]) == LockSight.Phase.LOST
			and float(eclipse["lost_after"]) >= LOCK_GRACE - 1.5 * tick and float(eclipse["lost_after"]) <= LONG_HIDE + tick,
		"hidden %.2f s: %s, grace %.2f" % [LONG_HIDE, eclipse, LOCK_GRACE])
	await _let_go_of_the_lock()
	_despawn(shy)
	for i in range(12):
		await get_tree().physics_frame

	# A GLIDER HAS NO HEAT AT ANY ASPECT: `seen_from` gives heat only to a kind with thrust. Tail-on close in, then head-on.
	var glider: int = _put_a_target(view, Sim.Kind.GLIDER, 800.0, 0.0, false)
	var cold: Dictionary = await _press_and_watch(1.5)
	await _let_go_of_the_lock()
	_despawn(glider)
	for i in range(12):
		await get_tree().physics_frame
	var oncoming: int = _put_a_target(view, Sim.Kind.GLIDER, 1000.0, 0.0, true)
	var cold_head: Dictionary = await _press_and_watch(0.5)
	await _let_go_of_the_lock()
	_despawn(oncoming)
	for i in range(12):
		await get_tree().physics_frame
	_check("and_never_sees_a_glider",
		glider != 0 and oncoming != 0 and not bool(cold["locking"]) and int(cold["target"]) == 0
			and not bool(cold_head["locking"]) and int(cold_head["target"]) == 0,
		"tail-on at 800 m %s; head-on at 1000 m %s" % [cold, cold_head])
	_check("every_target_was_taken_away_before_the_next", _refused_despawns.is_empty(),
		"refused: %s" % [", ".join(_refused_despawns)])
	_sections += 1


## THIS PLAYER'S SEEKER AS THE SERVER HOLDS IT, whose `target` is a server entity -- the client's row names the same
## aeroplane by the client's own id, which nothing a test spawns on the server can be compared with.
func _server_lock() -> Dictionary:
	for row in Sim.server.lock_states():
		if int((row as Dictionary).get("client", -1)) == Sim.local_client_id():
			return row
	return {}


## HOW FAST THE GIMBAL'S TARGET DRIFTS SIDEWAYS, m/s: out of a 0.07 rad cone within a lock time, and past a 0.8 rad
## gimbal at 1200 m in about six seconds.
const DRIFT: float = 200.0
## HOW LONG A LOCK SURVIVES ITS TARGET OUTSIDE THE GIMBAL: `kLockGrace` in cockpit_world.cpp, which is not in the table.
const LOCK_GRACE: float = 0.25
var _refused_despawns: PackedStringArray = []
## HOW LONG A HELD TARGET IS HIDDEN, s: well under the grace, and well over it.
const BRIEF_HIDE: float = 0.1
const LONG_HIDE: float = 0.4
## HOW FAR OUT THE AEROPLANE THAT HIDES IT IS PUT, m: clear of this aeroplane's hull and of the target's.
const HIDE_AT: float = 300.0
var _launch_frame: int = -1


## THE MISSILE CUES ON THE WIRE, for the print beside the launch. Read after Sim has drained the tick's list (an autoload
## runs first), and never drained here.
func _physics_process(_delta: float) -> void:
	for row in Sim.cues:
		var cue: Dictionary = row
		var what: int = int(cue.get("what", -1))
		if what == Sim.Cue.MISSILE_LAUNCH or what == Sim.Cue.MISSILE_END:
			_missile_cues.append("%s entity %d value %d frame %d at physics frame %d" % [
				"LAUNCH" if what == Sim.Cue.MISSILE_LAUNCH else "END", int(cue.get("entity", 0)),
				int(cue.get("value", 0)), int(cue.get("frame", 0)), Engine.get_physics_frames()])


## AN AEROPLANE IN THE LINE OF SIGHT to `target` for `hide` seconds of simulation, `HIDE_AT` out and going this
## aeroplane's way at its speed, then taken away and the lock watched for `then` more. Returns whether it was put there,
## the first phase other than LOCKED seen (-1 for none) and when, from the moment it went up.
func _hide_the_target_for(view: VehicleView, target: int, hide: float, then: float) -> Dictionary:
	var out: Dictionary = {"hid": false, "first_not_locked": -1, "lost_after": -1.0}
	var mine: Dictionary = _my_server_state(view)
	var theirs: Dictionary = Sim.server.vehicle_state(target)
	if mine.is_empty() or theirs.is_empty():
		return out
	var from: Vector3 = mine["position"] as Vector3
	var los: Vector3 = ((theirs["position"] as Vector3) - from).normalized()
	var nose: Vector3 = -Basis(mine["basis"] as Quaternion).z
	var screen: int = int(Sim.server.spawn_vehicle(PLANE, from + los * HIDE_AT, atan2(-nose.x, -nose.z),
		mine.get("velocity", Vector3.ZERO) as Vector3))
	out["hid"] = screen != 0
	var t: float = 0.0
	while t < hide + then:
		await get_tree().physics_frame
		t += Sim.tick_dt()
		if screen != 0 and t >= hide:
			_despawn(screen)
			screen = 0
		var phase: int = int(_server_lock().get("phase", 0))
		if phase != LockSight.Phase.LOCKED and int(out["first_not_locked"]) == -1:
			out["first_not_locked"] = phase
			out["lost_after"] = t
	if screen != 0:
		_despawn(screen)
	return out


## A TARGET `out` metres from the server's pose of this aeroplane, `off` radians round from its nose about its own up,
## going the same way at the same speed -- or, `facing` true, turned round and coming the other way -- plus `sideways`
## m/s along its right wing. Returns the SERVER's entity.
func _put_a_target(view: VehicleView, kind: int, out: float, off: float, facing: bool, sideways: float = 0.0) -> int:
	var mine: Dictionary = _my_server_state(view)
	var at: Vector3 = mine.get("position", view.global_position) as Vector3
	var facing_basis := Basis(mine.get("basis", view.global_basis.get_rotation_quaternion()) as Quaternion)
	var nose: Vector3 = (-facing_basis.z).rotated(facing_basis.y.normalized(), off)
	var moving: Vector3 = mine.get("velocity", Vector3.ZERO) as Vector3
	var heading: Vector3 = -nose if facing else nose
	var velocity: Vector3 = (-moving if facing else moving) + facing_basis.x * sideways
	return int(Sim.server.spawn_vehicle(kind, at + nose * out, atan2(-heading.x, -heading.z), velocity))


## HOW FAR OFF THE NOSE A TARGET IS, as `seen_from` measures it: -Z of the server's pose of this aeroplane against the
## line to the target. -1 when either is gone.
func _angle_off(view: VehicleView, target: int) -> float:
	var mine: Dictionary = _my_server_state(view)
	var theirs: Dictionary = Sim.server.vehicle_state(target)
	if mine.is_empty() or theirs.is_empty():
		return -1.0
	var nose: Vector3 = -Basis(mine["basis"] as Quaternion).z
	return nose.angle_to((theirs["position"] as Vector3) - (mine["position"] as Vector3))


## TAKEN AWAY, and a refusal remembered: `despawn_vehicle` refuses an occupied craft or one already gone, and a refused
## removal would leave the old target down the nose for the next check to lock.
func _despawn(target: int) -> void:
	if not bool(Sim.server.despawn_vehicle(target)):
		_refused_despawns.append(str(target))


## A SEEKER WITH NOTHING DESIGNATED: a press breaks a lock that is on its way or held, and a press on anything else would
## designate, so it is pressed only for those two.
func _let_go_of_the_lock() -> void:
	var phase: int = int(_server_lock().get("phase", 0))
	if phase == LockSight.Phase.LOCKING or phase == LockSight.Phase.LOCKED:
		await _hold("lock", 3)
	for i in range(30):
		await get_tree().physics_frame


## PRESS LOCK ONCE AND WATCH THE SERVER'S ROW for up to `seconds` of simulation: the phase it ended on, the target it
## named, whether it was ever on its way, and how long after the key went down it was LOCKED (-1 if never).
func _press_and_watch(seconds: float) -> Dictionary:
	var code: Key = _key_of("lock")
	_key(code, true)
	var seen: Dictionary = {"phase": 0, "target": 0, "locking": false, "locked_after": -1.0}
	var watched: float = 0.0
	var frames: int = 0
	while watched < seconds:
		await get_tree().physics_frame
		watched += Sim.tick_dt()
		frames += 1
		if frames == 3:
			_key(code, false)
		var row: Dictionary = _server_lock()
		var phase: int = int(row.get("phase", 0))
		seen["phase"] = phase
		seen["target"] = int(row.get("target", 0))
		if phase == LockSight.Phase.LOCKING or phase == LockSight.Phase.LOCKED:
			seen["locking"] = true
		if phase == LockSight.Phase.LOCKED:
			seen["locked_after"] = watched
			break
	_key(code, false)
	return seen


## An unpiloted aeroplane on the server's own nose, `out` metres ahead and a little above it, going the same way at the
## same speed -- or, `facing` true, turned round and coming the other way. Returns the SERVER's entity.
func _put_a_target_on_the_nose(view: VehicleView, out: float, facing: bool) -> int:
	var mine: Dictionary = _my_server_state(view)
	var at: Vector3 = mine.get("position", view.global_position) as Vector3
	var facing_basis := Basis(mine.get("basis", view.global_basis.get_rotation_quaternion()) as Quaternion)
	var nose: Vector3 = -facing_basis.z
	var moving: Vector3 = mine.get("velocity", Vector3.ZERO) as Vector3
	var where: Vector3 = at + nose * out + facing_basis.y * 20.0
	var heading: Vector3 = -nose if facing else nose
	var target: int = int(Sim.server.spawn_vehicle(PLANE, where, atan2(-heading.x, -heading.z),
		-moving if facing else moving))
	return target


func _my_server_state(view: VehicleView) -> Dictionary:
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			return Sim.server.vehicle_state(int((pilot as Dictionary).get("vehicle", 0)))
	return {}


## Up to `seconds` for this seat's lock to reach LOCKED, pressing LOCK when it is not on its way.
func _lock_within(view: VehicleView, rig: PilotRig, seconds: float) -> bool:
	if int(_my_lock(view, rig).get("phase", 0)) < LockSight.Phase.LOCKING:
		await _hold("lock", 3)
	var frames: int = int(seconds * Engine.physics_ticks_per_second)
	for i in range(frames):
		await get_tree().physics_frame
		if int(_my_lock(view, rig).get("phase", 0)) == LockSight.Phase.LOCKED:
			return true
	return false


## WHAT A HEAT SEEKER AT THIS SEAT SHOULD SEE OF THAT TARGET, in `seen_from`'s own terms, off the server: range, angle
## off the nose, the target's throttle, the aspect, and the signature against the table's heat_min.
func _heat_of(view: VehicleView, target: int) -> String:
	var mine: Dictionary = _my_server_state(view)
	var theirs: Dictionary = Sim.server.vehicle_state(target)
	if mine.is_empty() or theirs.is_empty():
		return "no state for the target"
	var from: Vector3 = mine["position"]
	var nose: Vector3 = -Basis(mine["basis"] as Quaternion).z
	var d: Vector3 = (theirs["position"] as Vector3) - from
	var los: Vector3 = d.normalized()
	var their_nose: Vector3 = -Basis(theirs["basis"] as Quaternion).z
	var row: Dictionary = Sim.missile_type(0)
	var throttle: float = float(Sim.server.craft_controls(target).get("throttle", 0.0))
	var tail: float = maxf(0.0, their_nose.dot(los))
	var aspect: float = 1.0 + (float(row.get("tail_bonus", 1.0)) - 1.0) * tail
	var km: float = d.length() / 1000.0
	var signature: float = (0.15 + 0.85 * clampf(throttle, 0.0, 1.0)) * aspect / (km * km)
	return "range %.0f m, %.3f rad off the nose (cone %.2f), throttle %.2f, aspect %.2f, signature %.3f against heat_min %.3f" % [
		d.length(), nose.angle_to(d), float(row.get("cone", 0.0)), throttle, aspect, signature,
		float(row.get("heat_min", 0.0))]


## ---- the launch ---------------------------------------------------------------------------

## HELD FOR A SECOND, ONE MISSILE -- and drawn leaving the pylon rather than thirty metres behind it.
func _a_held_launch_key_is_one_missile_off_the_rail(rig: PilotRig, view: VehicleView) -> int:
	var yard: MissileYard = _level.missiles
	var before: int = _mine().size()
	var stores_before: int = int(Sim.client.craft_systems(view.entity).get("stores", 0))
	var code: Key = _key_of("launch")
	_key(code, true)
	_launch_frame = Engine.get_physics_frames()
	print("[missiles] launch key down at physics frame %d" % _launch_frame)
	var first_drawn: Vector3 = Vector3.INF
	var rail_then: Vector3 = Vector3.INF
	var entity: int = 0
	var schema: Dictionary = Sim.missile_schema(PLANE)
	for i in range(120):
		await get_tree().process_frame
		if entity == 0 and not _mine().is_empty() and _mine().size() > before:
			entity = int((_mine()[_mine().size() - 1] as Dictionary)["entity"])
		if entity != 0 and not first_drawn.is_finite():
			first_drawn = yard.drawn_at(entity)
			# THE PYLON WHERE IT IS ON THIS SAME FRAME: the aeroplane is flying, and a pylon read a second later is
			# seventy metres further on. The first run of this compared against that and failed a missile that had come
			# off its rail exactly.
			if first_drawn.is_finite():
				rail_then = view.global_transform * MissileYard.pylon_of(schema, int(_row(entity).get("pylon", -1)))
	_key(code, false)
	for i in range(30):
		await get_tree().physics_frame
	_check("a_launch_key_held_a_second_is_one_missile", _mine().size() == before + 1,
		"%d missile(s) from this client" % (_mine().size() - before))
	var stores_after: int = int(Sim.client.craft_systems(view.entity).get("stores", 0))
	_check("and_its_pylon_is_empty_on_this_machine",
		_bits(stores_after) == _bits(stores_before) - 1, "stores %d then %d" % [stores_before, stores_after])
	var emptied: int = int(_row(entity).get("pylon", -1)) if entity != 0 else -1
	var nearest: float = first_drawn.distance_to(rail_then) if first_drawn.is_finite() and rail_then.is_finite() else INF
	_check("and_the_pylon_it_names_is_the_one_that_emptied",
		emptied >= 0 and (stores_before & (1 << emptied)) != 0 and (stores_after & (1 << emptied)) == 0,
		"pylon %d; stores %d then %d" % [emptied, stores_before, stores_after])
	# AND BY WHICH ROAD THE RAIL WAS FOUND -- printed, not judged here: tests/missile_cues judges it on a launch of its own.
	print("[missiles] rail found by %s; missile cues seen: %s" % [yard.rail_found_by(entity), ", ".join(_missile_cues)])
	_check("and_it_is_first_drawn_on_its_rail", nearest < 3.0 and yard.came_off_a_rail(entity),
		"%.1f m from the emptied pylon; taken off a rail: %s; row %s" % [nearest, yard.came_off_a_rail(entity),
			_row(entity)])
	_sections += 1
	return entity


## THE MOTOR IS THE SIMULATION'S: drawn exactly while `motor` is true, laying trail while it burns, and neither once
## it has gone out.
func _the_motor_burns_lays_a_trail_and_goes_out(entity: int) -> void:
	var yard: MissileYard = _level.missiles
	var disagreed: int = 0
	var burning_frames: int = 0
	var laid_at_start: int = yard.trail_segments()
	var laid_at_burnout: int = -1
	var out_frames: int = 0
	var timer := Time.get_ticks_msec()
	_ended_on = -1
	for i in range(3600):
		await get_tree().process_frame
		var row: Dictionary = _row(entity)
		if not row.is_empty() and not bool(row.get("flying", true)):
			_ended_on = int(row.get("surface", -1))
		if row.is_empty() or not bool(row.get("flying", false)):
			break
		var motor: bool = bool(row.get("motor", false))
		# ONE FRAME'S GRACE at each edge: the state is captured on the physics frame and drawn on the next render one.
		if motor != yard.is_burning(entity):
			disagreed += 1
		if motor:
			burning_frames += 1
		elif laid_at_burnout < 0:
			laid_at_burnout = yard.trail_segments()
		else:
			out_frames += 1
			if out_frames > 60:
				break
	_check("the_motor_is_drawn_while_the_simulation_says_it_burns", burning_frames > 30 and disagreed <= 2,
		"%d burning frame(s), %d disagreement(s), %d ms" % [burning_frames, disagreed, Time.get_ticks_msec() - timer])
	_check("and_it_lays_trail_while_it_burns", laid_at_burnout > laid_at_start,
		"%d segment(s) laid" % (laid_at_burnout - laid_at_start))
	_check("and_none_once_it_is_out", laid_at_burnout >= 0 and yard.trail_segments() == laid_at_burnout,
		"%d at burnout, %d a second later" % [laid_at_burnout, yard.trail_segments()])
	# AND THE FINISH REACHES THE TRAIL, pressed on the key the way a player presses it.
	var was: bool = yard.wears_fine()
	await _hold(SceneryFinish.ACTION, 2)
	await get_tree().process_frame
	_check("the_finish_key_changes_what_the_trail_wears", yard.wears_fine() != was,
		"fine %s then %s" % [was, yard.wears_fine()])
	await _hold(SceneryFinish.ACTION, 2)
	_sections += 1


## IT ENDS, AND THE YARD STOPS DRAWING IT.
func _it_ends_once(entity: int) -> void:
	var yard: MissileYard = _level.missiles
	var surface: int = _ended_on
	for i in range(4200):
		if surface >= 0 and _row(entity).is_empty():
			break
		await get_tree().physics_frame
		var row: Dictionary = _row(entity)
		if not row.is_empty() and not bool(row.get("flying", true)):
			surface = int(row.get("surface", -1))
	await get_tree().process_frame
	# SEEN ENDING, not merely gone: an ended missile lingers on the wire with `flying` false and its surface, and a row
	# that simply vanished would be a missile retired without its end ever being sent.
	_check("the_missile_ends_on_the_wire_with_a_surface", surface >= 0, "surface %d" % surface)
	_check("and_the_yard_stops_drawing_it", yard.in_the_air() == 0, "%d in the air" % yard.in_the_air())
	_sections += 1


## ---- the minigun ---------------------------------------------------------------------------

## THE MINIGUN IS A STATION, AND THE TRIGGER FIRES WHATEVER IS SELECTED. Plan item 4, asked for on 2026-09-15: "the
## fighter plane with missiles should have a minigun on the front and selecting is one of the options cycling through,
## guns, heat seeker, radar missile." Every press is a desk key, and every count is of rounds with THIS client's name
## on them as they arrived in `Sim.shots` -- nothing here calls `fire_gun`.
##
## FOUR THINGS, each of which would read to a pilot as "the cannons don't work" (item 16) if it were wrong: the station
## key reaches the gun, the sight says so, the fire key fires at the gun's own rate there -- and fires NOTHING on a
## missile station or while SAFE, so the finger that launches a missile never also sprays the sky.
func _the_minigun_is_the_third_station_and_the_trigger_fires_what_is_selected(rig: PilotRig, view: VehicleView) -> void:
	var guns: Dictionary = {}
	var heat: int = -1
	for entry in (Sim.missile_schema(PLANE).get("stations", []) as Array):
		if bool((entry as Dictionary).get("gun", false)):
			guns = entry
		elif String((entry as Dictionary).get("name", "")) == "heat":
			heat = int((entry as Dictionary).get("station", -1))
	_check("the_fighter_carries_a_gun_on_its_weapon_selector", not guns.is_empty() and heat >= 0,
		"guns %s, heat station %d" % [guns, heat])
	if guns.is_empty():
		_sections += 1
		return
	var station: CockpitStation = view.station_for(rig.seat_index())
	var stick := station.controls().get("stick") as FlightStick
	var on_trigger: Variant = stick.bindings().get(Bind.TRIGGER) if stick != null else null
	var fires: bool = on_trigger is Array
	for action in Bind.fire():
		fires = fires and (on_trigger as Array).has(action)
	_check("and_the_sticks_trigger_fires_as_well_as_launching", fires and _bit_of(on_trigger) == Sim.BUTTON_LAUNCH,
		Bind.says(on_trigger))
	# ARMED, so that the only thing between the key and a round is the station.
	if not bool(Sim.client.craft_systems(view.entity).get("master", false)):
		await _hold("master_arm", 2)
		for i in range(30):
			await get_tree().physics_frame
	# ON THE HEAT STATION, THE FIRE KEY FIRES NOTHING.
	await _select_station(view, heat)
	_shot_name = "heat"
	var on_heat: int = await _rounds_while_held("fire", 120)
	_check("on_a_missile_station_the_fire_key_fires_no_round", on_heat == 0, "%d round(s) in a second" % on_heat)
	# THE STATION KEY REACHES THE GUN, and the sight says GUNS with a cross where the seeker was.
	var gun_station: int = int(guns.get("station", -1))
	await _select_station(view, gun_station)
	_check("the_station_key_selects_the_guns",
		int(Sim.client.craft_systems(view.entity).get("weapon", -1)) == gun_station,
		"weapon %s, guns are station %d" % [Sim.client.craft_systems(view.entity).get("weapon"), gun_station])
	for i in range(10):
		await get_tree().process_frame
	var sight := _sight(view, rig)
	_check("and_the_sight_says_guns_with_a_cross", sight.says().begins_with("GUNS") and sight.shows_the_gun_cross(),
		"%s, cross %s" % [sight.says().replace("\n", " | "), sight.shows_the_gun_cross()])
	# A SECOND OF THE FIRE KEY IS A SECOND OF THE GUN'S OWN RATE. Two ticks a round at 120 Hz is 60; the window allows
	# the first and last partial ticks and nothing like a gun that fires once per press.
	var rate: float = 1.0 / float(guns.get("reload", 1.0))
	var missiles_before: int = _mine().size()
	_shot_name = "guns"
	var fired: int = await _rounds_while_held("fire", 120)
	_check("a_second_of_the_fire_key_on_the_guns_is_the_guns_rate", absf(float(fired) - rate) <= rate * 0.15,
		"%d rounds, wanted %.0f" % [fired, rate])
	# AND THE LAUNCH KEY ON THE GUN STATION LAUNCHES NO MISSILE -- a headset's trigger sends both.
	await _hold("launch", 3)
	for i in range(60):
		await get_tree().physics_frame
	_check("and_the_launch_key_on_the_guns_launches_no_missile", _mine().size() == missiles_before,
		"%d then %d missile(s)" % [missiles_before, _mine().size()])
	# SAFE, THE GUN IS SAFE, and the sight says so in the server's words.
	await _hold("master_arm", 2)
	for i in range(30):
		await get_tree().physics_frame
	_shot_name = "safe"
	var safe: int = await _rounds_while_held("fire", 60)
	for i in range(10):
		await get_tree().process_frame
	_check("safe_the_guns_fire_nothing_and_the_sight_says_so", safe == 0 and sight.says().contains("SAFE")
		and sight.says().contains("NOT ARMED"), "%d round(s); %s" % [safe, sight.says().replace("\n", " | ")])
	_sections += 1


## THE STATION KEY, PRESSED UNTIL THE SELECTOR IS ON `wanted` -- or four presses, which is more than round the three.
func _select_station(view: VehicleView, wanted: int) -> void:
	for press in range(4):
		if int(Sim.client.craft_systems(view.entity).get("weapon", -1)) == wanted:
			return
		await _hold("weapon_station", 2)
		for i in range(30):
			await get_tree().physics_frame


## HOW MANY ROUNDS WITH THIS CLIENT'S NAME ON THEM WERE BORN while `action`'s key was held for `frames` physics frames,
## counting the rounds still arriving for half a second after it came up.
func _rounds_while_held(action: String, frames: int) -> int:
	var seen: Dictionary = {}
	for row in Sim.shots:
		seen[int((row as Dictionary).get("entity", 0))] = true
	var born: int = 0
	var code: Key = _key_of(action)
	_key(code, true)
	for i in range(frames + 60):
		if i == frames:
			_key(code, false)
		await get_tree().physics_frame
		# A PICTURE, IF ONE WAS ASKED FOR AND THIS IS A WINDOW: `-- --shot=<dir>`, from the pilot's own eyes half way
		# through the burst. Headless has no rendering device and takes none.
		if i == frames / 2 and _shot_dir != "" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var picture: String = _shot_dir.path_join("missiles-%s-%s.png" % [action, _shot_name])
			get_viewport().get_texture().get_image().save_png(picture)
			print("[missiles] picture %s" % picture)
		for row in Sim.shots:
			var shot: Dictionary = row
			var entity: int = int(shot.get("entity", 0))
			if seen.has(entity):
				continue
			seen[entity] = true
			if int(shot.get("shooter", -1)) == Sim.local_client_id():
				born += 1
	return born


## ---- reading the wire ---------------------------------------------------------------------

## WHERE EVERY OTHER AIRCRAFT IS FROM THIS NOSE, for a lock that did not come: range and angle off the boresight, as
## this machine draws them.
func _where_the_target_is(view: VehicleView) -> String:
	var nose: Vector3 = -view.global_basis.z
	var seen: Array = []
	for entity in Sim.current:
		if int(entity) == view.entity:
			continue
		var row: Dictionary = Sim.current[entity]
		var to: Vector3 = (row.get("position", Vector3.ZERO) as Vector3) - view.global_position
		seen.append([nose.angle_to(to), to.length(), int(row.get("kind", -1))])
	seen.sort_custom(func(a, b): return a[0] < b[0])
	var parts: PackedStringArray = []
	for one in seen.slice(0, 5):
		parts.append("kind %d at %.0f m, %.3f rad off the nose" % [one[2], one[1], one[0]])
	return "the five nearest the nose: " + "; ".join(parts)

## Every missile this client launched, as of the last tick.
func _mine() -> Array:
	var out: Array = []
	for row in Sim.missiles:
		if int((row as Dictionary).get("client", -1)) == Sim.local_client_id():
			out.append(row)
	return out


func _row(entity: int) -> Dictionary:
	for row in Sim.missiles:
		if int((row as Dictionary).get("entity", 0)) == entity:
			return row
	return {}


func _my_lock(view: VehicleView, rig: PilotRig) -> Dictionary:
	for row in Sim.locks_for(view.entity):
		if int((row as Dictionary).get("seat", -1)) == rig.seat_index():
			return row
	return {}


func _sight(view: VehicleView, rig: PilotRig) -> LockSight:
	return view.station_for(rig.seat_index()).find_child("LockSight", true, false) as LockSight


## THE FIRST FRAME BIT IN A BINDING, which may be one action or a list: a fighter's trigger carries the launch AND the
## gun (plan item 4), and the launch is its first.
static func _bit_of(action: Variant) -> int:
	if action is Array:
		for one in (action as Array):
			if _bit_of(one) != 0:
				return _bit_of(one)
		return 0
	return int((action as Dictionary).get("bit", 0)) if action is Dictionary \
		and int((action as Dictionary).get("kind", -1)) == Bind.Kind.FRAME_BIT else 0


static func _bits(mask: int) -> int:
	var count: int = 0
	for i in range(16):
		if mask & (1 << i):
			count += 1
	return count


## ---- the keyboard ------------------------------------------------------------------------

## THE KEY AN ACTION IS BOUND TO, off the InputMap, so a key moved in `DESK_KEYS` moves this finger with it.
func _key_of(action: String) -> Key:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	_check("the_%s_action_is_bound_to_a_key" % action, false, "nothing bound")
	return KEY_NONE


func _key(code: Key, down: bool) -> void:
	if code == KEY_NONE:
		return
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = down
	Input.parse_input_event(press)


## Held for `frames` physics frames, then let go.
func _hold(action: String, frames: int) -> void:
	var code: Key = _key_of(action)
	_key(code, true)
	for i in range(frames):
		await get_tree().physics_frame
	_key(code, false)
	await get_tree().physics_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL " + ", ".join(_failures))
	get_tree().quit()
