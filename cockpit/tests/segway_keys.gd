extends Node
## Headless: does a person at a KEYBOARD walk a segway with WASD, without breaking what those keys
## already do in a craft?
##
##   Godot --headless --path cockpit res://tests/segway_keys.tscn
##
## Asked for on 2026-09-15: "they should be able to move forward/back/strafe-left/strafe-right with
## 'wasd' and the left little joystick on the left vr controller, and rotate with the joystick on the
## right controller (or use the mouse in 2d)."
##
## THE DESK IS TESTED AND THE HEADSET IS READ. Item 0 of the plan says everything must be workable
## and testable outside VR, and this machine has no headset -- so the keyboard path is pressed for
## real, through `Input.parse_input_event` and the rig's own `read_controls`, and the headset path is
## held by reading the LIVE binding table rather than by restating it. A table that said the right
## thing and a rig that ignored it would pass the second kind of check; that is why `reading_a_segway`
## and the key layer get the first kind.
##
## WHAT WAS ACTUALLY MISSING. Three of the four keys already worked, which is the point of making a
## segway a vehicle: W and S are `pitch_down` and `pitch_up`, A is `roll_left`, and `ride_segway`
## reads pitch as ahead and roll as sideways. Only D was taken -- it has been `spot`, the red boxes
## round distant aircraft, since long before there was anything to walk. So a segway lays a LAYER
## over the desk keys, and the two halves of that layer are what this holds: D strafes in a segway,
## and D still spots in a craft.
##
## Read RESULT=, not the exit code.

const RIG := preload("res://player/pilot_rig.tscn")
const VEHICLE := preload("res://objects/vehicles/vehicle_view.tscn")

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[segway_keys] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	await _wasd_walks_a_segway()
	await _and_d_still_spots_in_a_craft()
	_the_headset_sticks_already_do_it()
	_check("every_section_of_the_suite_ran", _sections == 3, "%d of 3" % _sections)
	_finish()


## ---- 1: the keyboard, pressed for real ---------------------------------------------------------

## W, A, S AND D ON A SEGWAY, each read off the frame the rig would send to the simulation.
##
## `read_controls` is the seam every other keyboard suite uses, and the frame is what
## `ride_segway` is handed: pitch negative is ahead, roll positive is to the right.
func _wasd_walks_a_segway() -> void:
	var kit: Dictionary = await _a_rig_in(Sim.Kind.SEGWAY)
	var rig: PilotRig = kit["rig"]
	_check("the_rig_knows_it_is_reading_a_segway", rig.reading_a_segway(),
		"in a %s" % Sim.kind_name((kit["view"] as VehicleView).kind))
	var cases: Array = [
		{"key": KEY_W, "field": "pitch", "wanted": -1.0, "does": "ahead"},
		{"key": KEY_S, "field": "pitch", "wanted": 1.0, "does": "back"},
		{"key": KEY_A, "field": "roll", "wanted": -1.0, "does": "left"},
		{"key": KEY_D, "field": "roll", "wanted": 1.0, "does": "right"},
	]
	var said: PackedStringArray = []
	var wrong: int = 0
	for case in cases:
		var frame: Dictionary = await _frame_with(rig, case["key"] as Key)
		var got: float = float(frame.get(String(case["field"]), 0.0))
		said.append("%s -> %s %.1f" % [OS.get_keycode_string(case["key"] as Key), case["field"], got])
		if not is_equal_approx(got, float(case["wanted"])):
			wrong += 1
	_check("wasd_sends_ahead_back_and_both_ways_sideways", wrong == 0,
		"wanted pitch -1/+1 and roll -1/+1: %s" % "; ".join(said))
	# AND Q AND E TURN IT, which were already the rudder and needed nothing.
	var turning: Dictionary = await _frame_with(rig, KEY_E)
	_check("and_e_turns_it_without_anything_being_added", float(turning.get("rudder", 0.0)) > 0.5,
		"rudder %.1f" % float(turning.get("rudder", 0.0)))
	_free(kit)
	_sections += 1


## ---- 2: and the key it borrowed still belongs to the craft --------------------------------------

## D IN AN AEROPLANE IS STILL THE SPOTTING BOXES, AND NOT A ROLL.
##
## This is the half that makes the layer a layer rather than a rebinding. Taking D off the spotting
## boxes would have fixed a briefing room by changing what every pilot's keyboard does; instead the
## key has one owner at a time, and `PilotRig.reading_a_segway` is the single predicate both the rig
## and `FlightLevel` ask. RED if the rig lets D roll a craft: the frame reads roll 1.0 in a plane.
func _and_d_still_spots_in_a_craft() -> void:
	var kit: Dictionary = await _a_rig_in(Sim.Kind.PLANE)
	var rig: PilotRig = kit["rig"]
	_check("a_rig_in_an_aeroplane_is_not_reading_a_segway", not rig.reading_a_segway(),
		"in a %s" % Sim.kind_name((kit["view"] as VehicleView).kind))
	var frame: Dictionary = await _frame_with(rig, KEY_D)
	_check("and_d_does_not_roll_it", is_zero_approx(float(frame.get("roll", 0.0))),
		"roll %.1f" % float(frame.get("roll", 0.0)))
	# AND THE SPOTTING ACTION IS STILL THE ONE D PRESSES, which is what the level reads.
	_check("and_d_is_still_the_spotting_key", InputMap.has_action("spot")
		and _action_has_key("spot", KEY_D), "spot keys %s" % [_keys_of("spot")])
	_free(kit)
	_sections += 1


## ---- 3: the headset, read off the live table ----------------------------------------------------

## THE STICKS ALREADY DID IT, WHICH IS THE WHOLE POINT OF MAKING IT A VEHICLE.
##
## Nothing was added for the headset. The global binding set has given the left stick pitch and roll
## and the right stick rudder since long before there was a segway, because that is the arrangement
## every stick-and-throttle setup uses -- and a segway reads pitch as ahead, roll as sideways and
## rudder as turn. So the user's "left little joystick to move, right to rotate" is what the rig
## already does, and what this holds is that it is STILL true, off the live table.
##
## READ, NOT PRESSED, and that is stated rather than hidden: this machine has no headset, so what a
## thumbstick does can only be asserted from the table the rig reads it through. `_bindings_for` is
## that table. A rig that ignored its own table would pass this and fail in a headset, which is why
## section 1 presses real keys instead.
func _the_headset_sticks_already_do_it() -> void:
	var rig := RIG.instantiate() as PilotRig
	add_child(rig)
	var left: Dictionary = rig.call("_global_bindings", 0)
	var right: Dictionary = rig.call("_global_bindings", 1)
	var left_stick: Variant = left.get(Bind.STICK, null)
	var right_stick: Variant = right.get(Bind.STICK, null)
	_check("the_left_stick_is_bound_to_pitch_and_roll_so_it_walks_a_segway",
		_axes_of(left_stick).has("pitch") and _axes_of(left_stick).has("roll"),
		"left stick drives %s" % [_axes_of(left_stick)])
	_check("and_the_right_stick_to_rudder_so_it_turns_one",
		_axes_of(right_stick).has("rudder"), "right stick drives %s" % [_axes_of(right_stick)])
	rig.queue_free()
	_sections += 1


## Which control fields a stick binding writes to, as a list of names.
func _axes_of(binding: Variant) -> PackedStringArray:
	var names: PackedStringArray = []
	if binding == null:
		return names
	var entries: Array = binding if binding is Array else [binding]
	for entry in entries:
		if entry is Dictionary and (entry as Dictionary).has("axis"):
			names.append(String((entry as Dictionary)["axis"]))
	return names


## ---- the machinery -------------------------------------------------------------------------------

## A RIG SITTING IN ONE VEHICLE OF `kind`, built the way the flight level builds one: a `VehicleView`
## told its kind, and the rig bolted to the view's own first seat.
func _a_rig_in(kind: int) -> Dictionary:
	var view := VEHICLE.instantiate() as VehicleView
	add_child(view)
	view.setup(1, kind)
	await get_tree().process_frame
	var rig := RIG.instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	if not view.seats.is_empty():
		rig.sit_in(view.seats[0])
	await get_tree().process_frame
	return {"rig": rig, "view": view}


func _free(kit: Dictionary) -> void:
	(kit["rig"] as Node).queue_free()
	(kit["view"] as Node).queue_free()


## THE FRAME THE RIG WOULD SEND with one key held, through the real event queue.
##
## The key goes down, a couple of frames pass so `Input` has it, `read_controls` is asked, and the key
## goes up again -- a key left down would leak into the next case. Both `keycode` and
## `physical_keycode` are set (CLAUDE.md, rule 9).
func _frame_with(rig: PilotRig, key: Key) -> Dictionary:
	_press(key, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var frame: Dictionary = rig.read_controls()
	_press(key, false)
	await get_tree().process_frame
	return frame


func _press(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func _action_has_key(action: String, key: Key) -> bool:
	return _keys_of(action).has(OS.get_keycode_string(key))


func _keys_of(action: String) -> PackedStringArray:
	var keys: PackedStringArray = []
	if not InputMap.has_action(action):
		return keys
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			keys.append(OS.get_keycode_string((event as InputEventKey).physical_keycode))
	return keys


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
