extends Node
## Headless: every finger on both controllers moves the part it presses and turns it amber, lets it back to rest when
## it lets go, and a controller nobody is touching writes nothing -- in a flying aeroplane, with nothing held and with
## the stick held.
##
##   Godot --headless --path cockpit res://tests/hands.tscn
##
## THE REAL PATH. A finger goes in through `PilotRig.force_input` and `force_grip`, the seams a headset's readings arrive
## by, and the rig's own `_process` hands them to `ControllerModel.show_input`; nothing here calls `show_input`. What is
## checked is what is DRAWN -- each part's transform and material -- against the model's stated travel, and which way it
## went is checked against a hand rather than against the model's own arithmetic: the trigger's blade back towards the
## grip (+Z), the grip button in towards the middle of the handle, a stick pushed right leaning to the controller's right
## on BOTH hands, and the grip showing closed at the squeeze that takes hold of a control (`VehicleControl.GRAB_ON`).
##
## EMPTY HANDS OUT OF REACH, every frame. A desk welds both hands in front of the panel, a squeeze there takes hold of the
## stick, and a squeeze shorter than `PilotRig.TAP_SECONDS` LATCHES (agents.md, "Two traps in every test that holds
## something"). So an empty hand is put two metres above the floor of the seat -- and put back every frame, because the
## aeroplane flies out of a pose placed once.
##
## Read RESULT=, not the exit code.

const PLANE: int = Sim.Kind.PLANE
## How close a drawn angle, travel and colour must be to what the model says: well inside what an eye could tell apart
## and well outside float noise.
const ANGLE_SLACK: float = 0.5
const TRAVEL_SLACK: float = 0.0002
const COLOUR_SLACK: float = 0.02
## Frames a finger is given to reach the drawing: the grip is read on the physics clock and drawn on the render one.
const SETTLE: int = 6
## Frames a controller is left alone to show it writes nothing.
const IDLE_FRAMES: int = 60

var _failures: PackedStringArray = []
## Sections that reached their own end. See the note in tests/feel.gd.
var _sections: int = 0
const SECTIONS: int = 5


func _check(label: String, ok: bool, detail: String) -> void:
	print("[hands] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	var level := load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(240):
		await get_tree().physics_frame
	var rig: PilotRig = level.rig
	if not await _into_a_plane(rig):
		_finish()
		return
	var stick := rig.vehicle_view().station_for(rig.seat_index()).controls().get("stick") as FlightStick
	var away := func() -> void:
		_put_out_of_reach(rig, 0)
		_put_out_of_reach(rig, 1)
	for hand in range(2):
		await _every_finger_shows(rig, hand, "with_nothing_held", away)
		_sections += 1
	await _take_hold_of_the_stick(rig, stick)
	_check("the_right_hand_takes_hold_of_the_stick", stick.is_held(), "held by %d" % stick.held_by)
	var on_the_stick := func() -> void:
		rig.force_hand(1, Transform3D(Basis.IDENTITY, stick.to_global(stick._grab_point())))
		_put_out_of_reach(rig, 0)
	if stick.is_held():
		for hand in range(2):
			await _every_finger_shows(rig, hand, "with_the_stick_in_the_right", on_the_stick)
			_sections += 1
	await _let_go_of_the_stick(rig, stick)
	_check("every_section_of_the_suite_ran", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	_finish()


func _into_a_plane(rig: PilotRig) -> bool:
	rig.ask_for_kind(PLANE)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == PLANE and rig.seat_index() == 0:
			break
	var ok: bool = view != null and view.kind == PLANE and rig.seat_index() == 0 \
		and view.station_for(0).controls().get("stick") is FlightStick
	_check("the_player_gets_into_a_plane_with_a_stick", ok,
		"kind %s, seat %d" % [view.kind if view != null else "-", rig.seat_index()])
	_sections += 1
	return ok


## ---- one hand ---------------------------------------------------------------------------

## EVERY FINGER OF `hand`, pressed and let go through the rig, and then nothing for a second. `place` puts both hands
## where this part of the suite holds them, and is called every frame.
func _every_finger_shows(rig: PilotRig, hand: int, where: String, place: Callable) -> void:
	var tag: String = "%s_hand_%s" % ["left" if hand == 0 else "right", where]
	var model: ControllerModel = rig.controller_model(hand)
	_check("%s_has_a_controller" % tag, model != null, "%s" % [model])
	if model == null:
		return
	await _settle(place)
	var writes_before: int = model.writes()
	await _the_trigger(rig, hand, tag, model, place)
	await _the_grip(rig, hand, tag, model, place)
	for input in [Bind.THUMB_HIGH, Bind.THUMB_LOW]:
		await _a_thumb_button(rig, hand, tag, model, place, input)
	await _the_stick(rig, hand, tag, model, place)
	var pressed_writes: int = model.writes() - writes_before

	# AND NOTHING, for a second: not one transform or colour written. The count has to have MOVED while the fingers were
	# working, or a count that never counts would pass this.
	await _settle(place)
	var idle_from: int = model.writes()
	for i in range(IDLE_FRAMES):
		place.call()
		await get_tree().process_frame
	var idle_writes: int = model.writes() - idle_from
	_check("%s_left_alone_for_%d_frames_writes_nothing" % [tag, IDLE_FRAMES], idle_writes == 0 and pressed_writes > 0,
		"%d writes idle, %d while the fingers worked" % [idle_writes, pressed_writes])


func _the_trigger(rig: PilotRig, hand: int, tag: String, model: ControllerModel, place: Callable) -> void:
	var hinge := model.get_node("TriggerHinge") as Node3D
	var blade := hinge.get_node("Trigger") as MeshInstance3D
	var rest: Transform3D = hinge.transform
	var rest_blade: Vector3 = rest * blade.position
	var rest_colour: Color = _colour(blade)
	rig.force_input(hand, Bind.TRIGGER, 1.0)
	await _settle(place)
	var turn: Quaternion = (rest.basis.inverse() * hinge.transform.basis).get_rotation_quaternion()
	var turned: float = rad_to_deg(turn.get_angle())
	var blade_went: Vector3 = hinge.transform * blade.position - rest_blade
	var pulled_colour: Color = _colour(blade)
	rig.force_input(hand, Bind.TRIGGER, 0.0)
	await _settle(place)
	var back: bool = hinge.transform.is_equal_approx(rest) and _near(_colour(blade), ControllerModel.REST)
	rig.force_input(hand, Bind.TRIGGER, null)
	_check("%s_a_full_pull_swings_the_trigger_back_by_its_stated_angle_and_turns_it_amber" % tag,
		absf(turned - ControllerModel.TRIGGER_PULL_DEGREES) < ANGLE_SLACK and absf(turn.get_axis().x) > 0.99
			and blade_went.z > 0.001 and _near(rest_colour, ControllerModel.REST)
			and _near(pulled_colour, ControllerModel.WORKED),
		"turned %.2f of %.1f deg about %s, blade went %s, %s -> %s" % [turned, ControllerModel.TRIGGER_PULL_DEGREES,
			turn.get_axis(), blade_went, rest_colour, pulled_colour])
	_check("%s_and_let_go_the_trigger_is_back_at_rest" % tag, back, "%s, %s" % [hinge.transform.basis, _colour(blade)])


## A SQUEEZE SHORT OF TAKING HOLD, then past it, then open. On a hand already latched onto something the grip is held
## closed by the latch whatever the finger does, and that is what is checked instead.
func _the_grip(rig: PilotRig, hand: int, tag: String, model: ControllerModel, place: Callable) -> void:
	var button := model.get_node("GripButton") as MeshInstance3D
	if rig._held_by(hand) != null:
		var went_in: float = absf(model.get("_grip_rest").x) - absf(button.position.x)
		_check("%s_a_hand_latched_on_shows_its_grip_closed" % tag,
			absf(went_in - ControllerModel.GRIP_TRAVEL) < TRAVEL_SLACK and _near(_colour(button), ControllerModel.WORKED),
			"in %.4f of %.4f m, %s" % [went_in, ControllerModel.GRIP_TRAVEL, _colour(button)])
		return
	var rest: Vector3 = button.position
	var light: float = VehicleControl.GRAB_ON * 0.6
	rig.force_grip(hand, light)
	await _settle(place)
	var light_in: float = absf(rest.x) - absf(button.position.x)
	var light_colour: Color = _colour(button)
	rig.force_grip(hand, 1.0)
	await _settle(place)
	var full_in: float = absf(rest.x) - absf(button.position.x)
	var full_colour: Color = _colour(button)
	rig.force_grip(hand, 0.0)
	await _settle(place)
	var back: bool = button.position.is_equal_approx(rest) and _near(_colour(button), ControllerModel.REST)
	rig.force_grip(hand, -1.0)
	await _settle(place)
	_check("%s_a_squeeze_short_of_taking_hold_moves_the_grip_button_in_and_leaves_it_grey" % tag,
		absf(light_in - light * ControllerModel.GRIP_TRAVEL) < TRAVEL_SLACK and _near(light_colour, ControllerModel.REST),
		"squeeze %.2f against %.2f to take hold: in %.4f m, %s" % [light, VehicleControl.GRAB_ON, light_in, light_colour])
	_check("%s_a_squeeze_past_taking_hold_moves_it_its_whole_travel_and_turns_it_amber" % tag,
		absf(full_in - ControllerModel.GRIP_TRAVEL) < TRAVEL_SLACK and _near(full_colour, ControllerModel.WORKED),
		"in %.4f of %.4f m, %s" % [full_in, ControllerModel.GRIP_TRAVEL, full_colour])
	_check("%s_and_opened_the_grip_button_is_back_at_rest_holding_nothing" % tag, back and rig._held_by(hand) == null,
		"%s, holding %s" % [button.position, rig._held_by(hand)])


func _a_thumb_button(rig: PilotRig, hand: int, tag: String, model: ControllerModel, place: Callable, input: int) -> void:
	var button := model.get_node("ThumbHigh" if input == Bind.THUMB_HIGH else "ThumbLow") as MeshInstance3D
	var rest: Vector3 = button.position
	rig.force_input(hand, input, true)
	await _settle(place)
	var sank: float = rest.y - button.position.y
	var colour: Color = _colour(button)
	rig.force_input(hand, input, false)
	await _settle(place)
	var back: bool = button.position.is_equal_approx(rest) and _near(_colour(button), ControllerModel.REST)
	rig.force_input(hand, input, null)
	_check("%s_its_%s_goes_down_while_pressed_and_turns_amber_and_comes_back" % [tag,
		Bind.input_name(input).replace(" ", "_")],
		absf(sank - ControllerModel.THUMB_TRAVEL) < TRAVEL_SLACK and _near(colour, ControllerModel.WORKED) and back,
		"down %.4f of %.4f m, %s, back %s" % [sank, ControllerModel.THUMB_TRAVEL, colour, back])


## THE STICK, pushed right, pushed forward, centred, clicked. RIGHT IS +X ON BOTH HANDS: the left controller's parts are
## mirrored and its stick's axes are not, so a mirror applied to the lean as well would fail here on the left hand.
func _the_stick(rig: PilotRig, hand: int, tag: String, model: ControllerModel, place: Callable) -> void:
	var pivot := model.get_node("Stick") as Node3D
	var cap := pivot.get_node("StickCap") as MeshInstance3D
	var rest: Transform3D = pivot.transform
	var cap_rest: Vector3 = rest * cap.position
	rig.force_input(hand, Bind.STICK, Vector2(1.0, 0.0))
	await _settle(place)
	var right_lean: float = rad_to_deg(pivot.transform.basis.y.angle_to(Vector3.UP))
	var right_went: Vector3 = pivot.transform * cap.position - cap_rest
	var right_colour: Color = _colour(cap)
	rig.force_input(hand, Bind.STICK, Vector2(0.0, 1.0))
	await _settle(place)
	var forward_went: Vector3 = pivot.transform * cap.position - cap_rest
	rig.force_input(hand, Bind.STICK, Vector2.ZERO)
	await _settle(place)
	var centred: bool = pivot.transform.is_equal_approx(rest) and _near(_colour(cap), ControllerModel.REST)
	rig.force_input(hand, Bind.STICK, null)
	# THE PARTS ARE MIRRORED: the stick on the inside of the head -- +X on the left hand -- and the thumbs outside it.
	var inside: float = 1.0 if hand == 0 else -1.0
	var thumb := model.get_node("ThumbHigh") as Node3D
	_check("%s_its_stick_sits_on_the_inside_and_its_thumb_buttons_outside" % tag,
		signf(rest.origin.x) == inside and signf(thumb.position.x) == -inside,
		"stick at x %.3f, upper thumb at x %.3f" % [rest.origin.x, thumb.position.x])
	_check("%s_its_stick_pushed_right_leans_right_by_its_stated_angle_and_turns_amber" % tag,
		absf(right_lean - ControllerModel.STICK_TILT_DEGREES) < ANGLE_SLACK and right_went.x > 0.002
			and absf(right_went.z) < 0.0005 and _near(right_colour, ControllerModel.WORKED),
		"leant %.2f of %.1f deg, cap went %s, %s" % [right_lean, ControllerModel.STICK_TILT_DEGREES, right_went,
			right_colour])
	_check("%s_pushed_forward_it_leans_forward" % tag, forward_went.z < -0.002 and absf(forward_went.x) < 0.0005,
		"cap went %s" % forward_went)
	_check("%s_centred_it_stands_up_grey_again" % tag, centred, "%s, %s" % [pivot.transform, _colour(cap)])
	rig.force_input(hand, Bind.STICK_CLICK, true)
	await _settle(place)
	var sank: float = rest.origin.y - pivot.transform.origin.y
	var clicked_colour: Color = _colour(cap)
	rig.force_input(hand, Bind.STICK_CLICK, false)
	await _settle(place)
	var back: bool = pivot.transform.is_equal_approx(rest) and _near(_colour(cap), ControllerModel.REST)
	rig.force_input(hand, Bind.STICK_CLICK, null)
	_check("%s_its_stick_clicked_sinks_and_turns_amber_and_comes_back" % tag,
		absf(sank - ControllerModel.STICK_CLICK_TRAVEL) < TRAVEL_SLACK and _near(clicked_colour, ControllerModel.WORKED)
			and back,
		"sank %.4f of %.4f m, %s, back %s" % [sank, ControllerModel.STICK_CLICK_TRAVEL, clicked_colour, back])


## ---- helpers ----------------------------------------------------------------------------

func _settle(place: Callable) -> void:
	for i in range(SETTLE):
		place.call()
		await get_tree().process_frame


## TWO METRES ABOVE THE FLOOR OF THE SEAT, where no control in any cockpit is.
func _put_out_of_reach(rig: PilotRig, hand: int) -> void:
	rig.force_hand(hand, Transform3D(Basis.IDENTITY, rig.origin.global_transform * Vector3(-0.3 + 0.6 * hand, 2.0, 0.0)))


static func _colour(part: MeshInstance3D) -> Color:
	return (part.material_override as StandardMaterial3D).albedo_color


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < COLOUR_SLACK and absf(a.g - b.g) < COLOUR_SLACK and absf(a.b - b.b) < COLOUR_SLACK


## TAKE HOLD OF THE STICK THE WAY A HAND DOES: a tap of the grip, which latches, with the hand put back on the stick's grip
## every frame. `tests/missiles.gd`'s, for the reasons written there.
func _take_hold_of_the_stick(rig: PilotRig, stick: FlightStick) -> void:
	for i in range(8):
		rig.force_hand(1, Transform3D(Basis.IDENTITY, stick.to_global(stick._grab_point())))
		_put_out_of_reach(rig, 0)
		rig.force_grip(1, 1.0 if i < 4 else 0.0)
		await get_tree().physics_frame
	for i in range(3):
		rig.force_hand(1, Transform3D(Basis.IDENTITY, stick.to_global(stick._grab_point())))
		_put_out_of_reach(rig, 0)
		await get_tree().process_frame


## AND LET GO THE WAY A LATCHED HAND DOES: a second tap, and only if it is still held.
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
	rig.force_grip(1, -1.0)
	rig.force_hand(0, null)
	rig.force_hand(1, null)
	for i in range(4):
		await get_tree().physics_frame
