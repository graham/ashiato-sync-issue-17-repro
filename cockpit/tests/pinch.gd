extends Node
## Headless: WHICH FINGER TAKES WHICH CONTROL -- the grab and the pinch.
##
##   Godot --headless --path cockpit res://tests/pinch.tscn
##
## THE GATE FOR plan.md ITEM 14, WRITTEN BEFORE THE CHANGE. Asked for as "some devices
## should be grabbable by the grab button, and others should use the trigger button, it's
## more natural to grab joysticks or wheels and 'pinch' buttons and switches."
##
## READ THIS BEFORE BELIEVING THE PINCH IS OLD. There was no pinch anywhere in this game
## until this suite failed. `Bind`'s own doc block said it plainly -- "GRIP is always
## take-hold-of-this, everywhere, on every control" -- and it was true: one grab took a
## flight stick, a bat switch and an MFD key alike. So this file is the pinch's ORIGIN and
## not an adjustment to one.
##
## ---------------------------------------------------------------------------------
## WHAT IT HOLDS, AND WHAT IT CANNOT
## ---------------------------------------------------------------------------------
##
## It cannot say whether a pinch FEELS like a pinch. That wants a headset and this machine
## has none (plan.md item 0), so nothing here claims it. What it can say is the half that
## breaks: that a stick answers the grip and ignores the trigger, that a switch answers the
## trigger and ignores the grip, that a hand between the two takes the one its closing
## finger can take even when the other is NEARER, that the finger doing the pinching is not
## also braking, and that the two gestures differ in their RELEASE -- the fist latches on a
## tap and the pinch never does.
##
## EVERY GRAB GOES THROUGH THE RIG, never through `VehicleControl.offer_hand` directly.
## `offer_hand` is the layer BELOW the thing that decides anything: the choice of control,
## the one-hand-one-control rule and the latch all live in `PilotRig`. A suite that called
## `offer_hand` with a number would be testing the number it typed. `force_hand`,
## `force_grip` and `force_input` are the rig's own seams and are what a headset drives too.
##
## THE RED READING, against the code as it stood the moment before the rig was wired
## (2026-09-15). The two lines worth keeping are the fourth and the last:
##
##   FAIL the_arm_switch_is_not_taken_by_a_closed_fist (held_by 0 with the fist closed)
##   FAIL and_a_pinched_switch_is_taken_by_the_trigger (held_by -1 with the trigger at 1.0)
##   FAIL and_a_pinched_switch_can_be_flicked_on (position 0, was 0)
##   FAIL and_the_craft_is_asked_to_arm (master asked for 0 of 1)
##   FAIL a_closing_trigger_takes_the_switch_even_though_the_stick_is_nearer
##        (switch held_by -1, stick held_by -1, stick 0.040 m and switch 0.060 m away)
##   FAIL a_closing_fist_takes_the_stick_even_though_the_switch_is_nearer
##        (stick held_by -1, switch held_by 0, stick 0.060 m and switch 0.040 m away)
##   FAIL and_with_both_fingers_closed_the_grip_wins (stick held_by -1, switch held_by 0)
##   FAIL the_pinching_hand_is_holding_the_switch (held_by -1)
##   FAIL and_that_hand_is_not_also_braking (brake 1.00 while holding the switch)
##
## Nine of the nineteen checks the suite had then. The fist closing four centimetres from a
## stick took the SWITCH two centimetres further off, because nearest was the only question
## anybody asked; and the finger that will do the pinching was braking at 1.00 the whole
## time, which is what the reservation in
## `PilotRig._bindings_for` is for. `a_stick_is_taken_by_a_closed_fist` and
## `an_empty_hands_trigger_is_still_the_brake` passed then and must pass now -- they are
## here so the change cannot quietly cost the grab or the brake it is built beside.
##
## Read RESULT=, not the exit code.

const TEST_KIND: Sim.Kind = Sim.Kind.PLANE
const TEST_SEAT: int = 0
## THE LEFT HAND THROUGHOUT, and the right parked out of the world.
##
## The left on purpose: its empty-hand trigger is the BRAKE (`PilotRig._global_bindings`),
## which is the finger this whole item now also asks to pinch with. If a pinched switch
## were going to brake the aeroplane it would do it on this hand.
const HAND: int = 0
const OTHER: int = 1

## HOW FAR APART THE BENCH PAIR'S GRIPS ARE, in metres. Comfortably inside one
## `VehicleControl.REACH`, so a hand between them is within reach of BOTH and the question
## "which one" is a real question rather than an arithmetic accident.
const BENCH_GAP: float = 0.10

var _failures: PackedStringArray = []
## Sections that reached their own end. A GDScript error aborts the function it is in and
## carries on with the next, so counting only failures reports a cheerful pass over a
## section that fell over halfway.
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[pinch] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	# THE COCKPITS AS AUTHORED. `user://cockpits` is the player's, and a layout saved while
	# playing moves the very controls this suite reaches for. Same reason `tests/fit.gd`
	# turns it off.
	CockpitStation.use_saved_layouts = false
	_every_part_says_which_finger_takes_it()
	await _a_stick_answers_the_fist_and_not_the_trigger()
	await _the_arm_switch_in_the_aeroplane_is_pinched_and_not_grabbed()
	await _a_hand_that_could_take_either_takes_the_one_its_finger_can()
	await _the_finger_that_is_pinching_is_not_also_braking()
	await _the_grip_latches_and_the_pinch_never_does()
	_check("every_section_of_the_suite_ran", _sections == 6, "%d of 6" % _sections)
	_finish()


## ---- the two sets ---------------------------------------------------------------------

## EVERY PART IN THE BIN SAYS WHICH FINGER TAKES IT, and the two sets are the ones a person
## would name out loud.
##
## The list is here rather than derived because this is the place the INTENT is written
## down: "joysticks or wheels" against "buttons and switches" is the user's own sentence,
## and a suite that computed the answer from the code would agree with whatever the code
## said. A new part arriving in `ControlCatalogue.PARTS` fails this until somebody decides
## which hand takes it, which is exactly the moment to decide.
func _every_part_says_which_finger_takes_it() -> void:
	# THINGS YOU WRAP A HAND ROUND. Sticks, yokes, wheels, levers, quadrants, a gun grip --
	# and the pedals, which no hand takes at all and which default with the rest.
	var pinched: PackedStringArray = []
	var grabbed: PackedStringArray = []
	var displays: PackedStringArray = []
	var unsaid: PackedStringArray = []
	for part in ControlCatalogue.PARTS:
		var made: VehicleControl = ControlCatalogue.make(part)
		if made == null:
			unsaid.append(String(part))
			continue
		match made.taken_by():
			Bind.Take.NONE: displays.append(String(part))
			Bind.Take.PINCH: pinched.append(String(part))
			Bind.Take.GRIP: grabbed.append(String(part))
			_: unsaid.append(String(part))
		made.free()
	var want_pinched: PackedStringArray = ["CrewButton", "CommandButton", "ToggleSwitch", "GuardedToggleSwitch", "RotaryKnob",
		"DetentDial", "TimeOfDayDial", "MfdPanel"]
	_check("every_part_in_the_bin_says_which_finger_takes_it", unsaid.is_empty(),
		"unsaid: %s" % ", ".join(unsaid))
	_check("the_fingertip_parts_are_the_buttons_switches_knobs_and_screens",
		pinched == want_pinched, "%s" % ", ".join(pinched))
	_check("and_a_read_only_map_screen_takes_neither_finger", displays == PackedStringArray(["MapScreen"]),
		"%s" % ", ".join(displays))
	_check("and_everything_a_hand_wraps_round_takes_the_grip", not grabbed.is_empty()
		and grabbed.has("FlightStick") and grabbed.has("SteeringWheel")
		and grabbed.has("ThrottleLever") and grabbed.has("GunTrigger"),
		"%s" % ", ".join(grabbed))
	_sections += 1


## ---- one control, one finger -----------------------------------------------------------

## A JOYSTICK IS TAKEN BY A CLOSED FIST AND IGNORES A PULLED TRIGGER.
##
## The trigger half is the new half and is the one that was RED. The fist half is here so
## the change cannot quietly cost the grab it is built on top of: a stick that stopped
## answering the grip would be an aeroplane nobody can fly.
func _a_stick_answers_the_fist_and_not_the_trigger() -> void:
	var kit: Dictionary = await _a_bench()
	var rig: PilotRig = kit["rig"]
	var stick: VehicleControl = kit["stick"]

	_hand_on(rig, stick)
	rig.force_input(HAND, Bind.TRIGGER, 1.0)
	await _frames(6)
	_check("a_stick_ignores_a_pulled_trigger", not stick.is_held(),
		"held_by %d with the trigger at 1.0" % stick.held_by)

	rig.force_input(HAND, Bind.TRIGGER, null)
	rig.force_grip(HAND, 1.0)
	await _frames(6)
	_check("a_stick_is_taken_by_a_closed_fist", stick.held_by == HAND,
		"held_by %d with the fist closed" % stick.held_by)
	await _open_the_hand(rig, stick)
	_forget(kit)
	_sections += 1


## THE USER'S OWN EXAMPLE, ON THE AEROPLANE'S OWN SWITCH.
##
## `CockpitStation._fit_the_missiles` bolts a MASTER ARM `ToggleSwitch` to the glareshield of
## every plane seat that can launch, which is the switch the request names. So this is the
## real part on the real station, taken the real way and then FLICKED -- because a switch
## that can be pinched and not thrown is half an answer.
func _the_arm_switch_in_the_aeroplane_is_pinched_and_not_grabbed() -> void:
	var kit: Dictionary = await _a_bench()
	var rig: PilotRig = kit["rig"]
	var arm := (kit["station"] as CockpitStation).get_node_or_null("MasterArm") as ToggleSwitch
	if arm == null:
		_check("the_aeroplane_has_a_master_arm_switch", false,
			"no MasterArm at seat %d of a %s" % [TEST_SEAT, TEST_KIND])
		_forget(kit)
		_sections += 1
		return
	_check("the_aeroplane_has_a_master_arm_switch", true, "on the glareshield")

	# A CLOSED FIST DOES NOTHING TO IT. This is the sentence the item asked for.
	_hand_on(rig, arm)
	rig.force_grip(HAND, 1.0)
	await _frames(6)
	_check("the_arm_switch_is_not_taken_by_a_closed_fist", not arm.is_held(),
		"held_by %d with the fist closed" % arm.held_by)
	rig.force_grip(HAND, -1.0)
	await _frames(2)

	# AND THE TRIGGER TAKES IT.
	rig.force_input(HAND, Bind.TRIGGER, 1.0)
	await _frames(6)
	_check("and_a_pinched_switch_is_taken_by_the_trigger", arm.held_by == HAND,
		"held_by %d with the trigger at 1.0" % arm.held_by)

	# AND IT THROWS. Forward is on -- see `ToggleSwitch` -- so the hand goes -Z in the
	# switch's own frame, by its own throw, asked of the class rather than typed.
	var was: int = arm.at_position()
	await _hand_follows(rig, arm, Vector3(0.0, 0.0, -ToggleSwitch.THROW), 8)
	_check("and_a_pinched_switch_can_be_flicked_on", arm.is_on(),
		"position %d, was %d" % [arm.at_position(), was])
	# AND WHAT IT IS NOW ASKING THE BUS FOR. A switch's whole job is the value it asks its
	# channel to take, and one that moves on the panel while `command_value` stays put is a
	# switch that has moved and done nothing. On a bench there is no craft to answer, so
	# what is held is the ask.
	_check("and_the_craft_is_asked_to_arm",
		arm.channel == Sim.Channel.MASTER and arm.command_value() == arm.channel_range,
		"%s asked for %d of %d" % [Sim.channel_name(arm.channel), arm.command_value(),
			arm.channel_range])
	rig.force_input(HAND, Bind.TRIGGER, null)
	await _frames(4)
	_check("and_letting_the_trigger_go_lets_the_switch_go", not arm.is_held(),
		"held_by %d" % arm.held_by)
	_forget(kit)
	_sections += 1


## ---- the hard part: both could apply ---------------------------------------------------

## A HAND WITHIN REACH OF A STICK AND A SWITCH AT ONCE.
##
## ---------------------------------------------------------------------------------
## THE RULE, AND THE ONE IT BEAT
## ---------------------------------------------------------------------------------
##
## THE FINGER THAT IS CLOSING DECIDES WHICH CONTROLS ARE EVEN CANDIDATES, and only then
## does nearest choose between them. A closing trigger can see nothing but pinched parts; a
## closing fist can see nothing but grabbed ones. So a hand resting between a stick and a
## switch takes whichever one it asked for with its hand, and the other may be a centimetre
## nearer without winning.
##
## AND WITH BOTH FINGERS CLOSED, THE GRIP WINS. An index finger rests ON a trigger and that
## trigger is the brake, the gun and the beam's press besides; a fist is closed only on
## purpose. So the deliberate gesture beats the incidental one.
##
## REJECTED: NEAREST DECIDES, AND THE FINGER ONLY SAYS WHETHER TO TAKE IT. That is what the
## code did before this item and it is why the request exists -- with the stick 4 cm away
## and the switch 6 cm away, `_nearest_to` answered "stick" and a pulled trigger was offered
## to a control that does not answer triggers. The hand had said which one it meant and the
## geometry overruled it. Millimetres should not settle a question a finger has answered.
func _a_hand_that_could_take_either_takes_the_one_its_finger_can() -> void:
	var kit: Dictionary = await _a_bench()
	var rig: PilotRig = kit["rig"]
	var stick: VehicleControl = kit["bench_stick"]
	var switch: VehicleControl = kit["bench_switch"]

	# NEARER THE STICK: 40% of the way along, so the stick is 4 cm off and the switch 6 cm.
	_hand_between(rig, stick, switch, 0.4)
	await _frames(2)
	rig.force_input(HAND, Bind.TRIGGER, 1.0)
	await _frames(6)
	_check("a_closing_trigger_takes_the_switch_even_though_the_stick_is_nearer",
		switch.held_by == HAND and not stick.is_held(),
		"switch held_by %d, stick held_by %d, stick %.3f m and switch %.3f m away"
			% [switch.held_by, stick.held_by, _from_hand(rig, stick), _from_hand(rig, switch)])
	rig.force_input(HAND, Bind.TRIGGER, null)
	await _frames(4)

	# AND THE OTHER WAY ROUND: 60% along, so the switch is the near one.
	_hand_between(rig, stick, switch, 0.6)
	await _frames(2)
	rig.force_grip(HAND, 1.0)
	await _frames(6)
	_check("a_closing_fist_takes_the_stick_even_though_the_switch_is_nearer",
		stick.held_by == HAND and not switch.is_held(),
		"stick held_by %d, switch held_by %d, stick %.3f m and switch %.3f m away"
			% [stick.held_by, switch.held_by, _from_hand(rig, stick), _from_hand(rig, switch)])
	await _open_the_hand(rig, stick)
	await _frames(2)

	# AND BOTH AT ONCE, from the spot where the SWITCH is nearer, so nothing but the rule
	# can be what chooses the stick.
	_hand_between(rig, stick, switch, 0.6)
	rig.force_grip(HAND, 1.0)
	rig.force_input(HAND, Bind.TRIGGER, 1.0)
	await _frames(6)
	_check("and_with_both_fingers_closed_the_grip_wins",
		stick.held_by == HAND and not switch.is_held(),
		"stick held_by %d, switch held_by %d" % [stick.held_by, switch.held_by])
	rig.force_input(HAND, Bind.TRIGGER, null)
	await _open_the_hand(rig, stick)
	_forget(kit)
	_sections += 1


## ---- the finger is busy ------------------------------------------------------------------

## A HAND PINCHING A SWITCH IS NOT ALSO BRAKING WITH THE SAME FINGER.
##
## The empty left hand's trigger is the brake. Give the trigger a second job -- taking hold
## of switches -- and without a rule it does both at once: throw the master arm on final
## approach and the aeroplane brakes. The rule is the one `Bind` already states about the
## grip, extended: THE FINGER THAT IS HOLDING A CONTROL IS NOT ALSO FREE TO DO SOMETHING
## ELSE. See `PilotRig._bindings_for`.
##
## DRIVEN, NOT READ. `_work_the_hands` is the function that turns the live tables into a
## control frame, so this asks it for a frame rather than restating the table -- and asks it
## FIRST with an empty hand, where the brake must be full on. Without that half, a suite
## that simply found no brake would pass on a rig that had lost the brake altogether.
func _the_finger_that_is_pinching_is_not_also_braking() -> void:
	var kit: Dictionary = await _a_bench()
	var rig: PilotRig = kit["rig"]
	var switch: VehicleControl = kit["bench_switch"]

	# AN EMPTY HAND, MILES FROM ANYTHING, with the trigger pulled: full brake.
	rig.force_hand(HAND, Transform3D(Basis.IDENTITY, Vector3(0.0, -40.0, 0.0)))
	rig.force_input(HAND, Bind.TRIGGER, 1.0)
	await _frames(4)
	var empty: Dictionary = {"buttons": 0}
	rig.call("_work_the_hands", empty)
	_check("an_empty_hands_trigger_is_still_the_brake",
		is_equal_approx(float(empty.get("brake", 0.0)), 1.0),
		"brake %.2f" % float(empty.get("brake", 0.0)))

	# THE SAME FINGER, PINCHING A SWITCH.
	_hand_on(rig, switch)
	await _frames(6)
	_check("the_pinching_hand_is_holding_the_switch", switch.held_by == HAND,
		"held_by %d" % switch.held_by)
	var pinching: Dictionary = {"buttons": 0}
	rig.call("_work_the_hands", pinching)
	_check("and_that_hand_is_not_also_braking",
		is_zero_approx(float(pinching.get("brake", 0.0))),
		"brake %.2f while holding the switch" % float(pinching.get("brake", 0.0)))
	rig.force_input(HAND, Bind.TRIGGER, null)
	_forget(kit)
	_sections += 1


## ---- the two gestures differ in their RELEASE ---------------------------------------------

## A GRIP LATCHES AND A PINCH NEVER DOES, which is the other half of item 14 and the half
## that is easiest to get almost right.
##
## THE USER'S OWN WORDS, 2026-09-15: "there is no 'quick tap to grab' with grip, long press
## and release will release but quick grab on/off should hold until the grab button is hit
## again, this is different with pinch, any release is a full release, this makes working with
## switches (which you only want to grab until you have the setting you want) easier."
##
## AND THE REASON IS IN THE SENTENCE. A switch is something you take hold of only until it is
## at the setting you want. A latch is right for a lever you fly with for an hour and wrong
## for a switch you flick: a latched switch is a hand stuck to the switch after every flick,
## and the only way off it is a second tap nobody asked to make.
##
## ---------------------------------------------------------------------------------
## TWO RED READINGS, AND THE FIRST ONE WAS A REAL BUG
## ---------------------------------------------------------------------------------
##
## RED 1, against the code as this section first ran on 2026-09-15 -- a bug this section found
## and nothing else would have:
##
##   FAIL and_a_grip_tapped_while_pinching_latches_nothing
##        (switch held_by -1, stick held_by 0)
##
## The latch pinned a hand to WHATEVER it was holding, and a hand pinching a switch is holding
## something. So a fist tapped while pinching latched onto a switch no fist had hold of, and
## the fist it left closed was still closed on the frame the trigger let the switch go: the
## hand let go of the switch and took the STICK beside it, having been told to do neither.
## Fixed by `PilotRig._in_the_fist` -- the latch may only pin what a FIST is holding.
##
## RED 2. The most likely bug here is a pinch that quietly inherited the latch, because it
## would feel almost right: the switch would move, and the hand would simply not come off it.
## So the rig was deliberately given a pinch with its own tap-to-latch, run, and reverted:
##
##   FAIL and_letting_the_trigger_go_lets_the_switch_go (held_by 0)
##   FAIL a_closing_fist_takes_the_stick_even_though_the_switch_is_nearer
##        (stick held_by -1, switch held_by 0, stick 0.060 m and switch 0.040 m away)
##   FAIL and_with_both_fingers_closed_the_grip_wins (stick held_by -1, switch held_by 0)
##   FAIL a_pinch_let_go_of_inside_the_tap_window_is_a_full_release
##        (held_by 0 after a 1 ms pull, against a tap window of 350 ms)
##   FAIL and_the_switch_stays_where_the_finger_left_it (position 1, held_by 0)
##   FAIL and_a_long_pinch_released_is_also_a_full_release (held_by 0 after a 500 ms pinch)
##
## One millisecond against a window of 350 is as far inside a tap as a reading gets, so the
## fourth line is the whole of it. The two middle lines are the damage a latched pinch does
## somewhere else entirely: the hand never came off the switch, so sections that had nothing
## to do with latching failed too, with a fist that could no longer take anything. That is
## what "feels almost right" looks like from a suite.
##
## ROUTING `_pinch_of` THROUGH `_grip_of` WAS TRIED FIRST AND IS NOT THE EXPERIMENT. The two
## fingers would then share one latch state, so the mutation broke the FIST
## (`and_a_second_tap_lets_go_of_it`) and never reached the pinch at all. A mutation that
## fails the wrong check has not tested anything.
##
## THE TAP MUST BE MEASURED AND NOT ASSUMED. `_grip_of` times the tap on the WALL clock, and a
## suite at `--fixed-fps` runs frames far faster than wall time -- so a "quick" pull that
## happened to take longer than `TAP_SECONDS` would release even from a latching rig, and the
## check would pass for the wrong reason. The pull is timed, and the reading says how long it
## was against the window it has to be inside.
func _the_grip_latches_and_the_pinch_never_does() -> void:
	var kit: Dictionary = await _a_bench()
	var rig: PilotRig = kit["rig"]
	var stick: VehicleControl = kit["bench_stick"]
	var switch: ToggleSwitch = kit["bench_switch"]

	# ---- the fist: a quick tap on, and it stays shut -------------------------------------
	_hand_on(rig, stick)
	rig.force_grip(HAND, 1.0)
	await _frames(4)
	rig.force_grip(HAND, 0.0)
	await _frames(4)
	_check("a_fist_tapped_on_a_stick_holds_it_with_the_hand_open", stick.held_by == HAND,
		"held_by %d with the grip at 0.0" % stick.held_by)

	# AND A SECOND TAP LETS GO.
	rig.force_grip(HAND, 1.0)
	await _frames(4)
	rig.force_grip(HAND, 0.0)
	await _frames(4)
	_check("and_a_second_tap_lets_go_of_it", not stick.is_held(),
		"held_by %d" % stick.held_by)

	# AND A LONG PRESS RELEASED IS A RELEASE, not a latch. The other half of the fist, and the
	# reason `TAP_SECONDS` is a window rather than an edge.
	rig.force_grip(HAND, 1.0)
	var squeezed: int = await _hold_past_the_tap()
	_check("and_a_stick_squeezed_and_held_is_held", stick.held_by == HAND,
		"held_by %d after %d ms" % [stick.held_by, squeezed])
	rig.force_grip(HAND, 0.0)
	await _frames(4)
	_check("and_letting_a_long_squeeze_go_releases_it", not stick.is_held(),
		"held_by %d after a %d ms squeeze, against a tap window of %d ms"
			% [stick.held_by, squeezed, int(PilotRig.TAP_SECONDS * 1000.0)])
	rig.force_grip(HAND, -1.0)
	await _frames(2)

	# ---- the pinch: any release is a full release ----------------------------------------
	_hand_on(rig, switch)
	await _frames(2)
	var pulled_at: int = Time.get_ticks_msec()
	rig.force_input(HAND, Bind.TRIGGER, 1.0)
	await _frames(4)
	var took: bool = switch.held_by == HAND
	# THROWN WHILE IT IS HELD, because that is what the switch was taken for -- and because a
	# release measured on a switch nobody moved proves nothing about the gesture people make.
	await _hand_follows(rig, switch, Vector3(0.0, 0.0, -ToggleSwitch.THROW), 6)
	rig.force_input(HAND, Bind.TRIGGER, null)
	var pulled_for: int = Time.get_ticks_msec() - pulled_at
	await _frames(4)
	_check("the_trigger_takes_the_switch_and_throws_it", took and switch.is_on(),
		"took %s, position %d" % [took, switch.at_position()])
	_check("and_the_pull_was_well_inside_the_tap_window",
		float(pulled_for) < PilotRig.TAP_SECONDS * 1000.0,
		"%d ms against a window of %d ms" % [pulled_for,
			int(PilotRig.TAP_SECONDS * 1000.0)])
	_check("a_pinch_let_go_of_inside_the_tap_window_is_a_full_release", not switch.is_held(),
		"held_by %d after a %d ms pull, against a tap window of %d ms"
			% [switch.held_by, pulled_for, int(PilotRig.TAP_SECONDS * 1000.0)])
	# AND THE SETTING STAYS. Letting go of a switch is not undoing it -- the whole point of
	# holding one is to leave it somewhere.
	_check("and_the_switch_stays_where_the_finger_left_it",
		switch.is_on() and not switch.is_held(),
		"position %d, held_by %d" % [switch.at_position(), switch.held_by])

	# AND A LONG PINCH RELEASED IS ALSO A FULL RELEASE. "Any release", which means the length
	# of the pull must make no difference at all -- the one thing that separates it from the
	# fist above, where the same two pulls mean opposite things.
	_hand_on(rig, switch)
	rig.force_input(HAND, Bind.TRIGGER, 1.0)
	var pinched: int = await _hold_past_the_tap()
	_check("and_a_switch_pinched_and_held_is_held", switch.held_by == HAND,
		"held_by %d after %d ms" % [switch.held_by, pinched])
	rig.force_input(HAND, Bind.TRIGGER, null)
	await _frames(4)
	_check("and_a_long_pinch_released_is_also_a_full_release", not switch.is_held(),
		"held_by %d after a %d ms pinch" % [switch.held_by, pinched])

	# ---- and the two gestures do not leak into one another -------------------------------
	#
	# A FIST TAPPED WHILE THE TRIGGER IS PINCHING SOMETHING LATCHES NOTHING. The latch pins a
	# hand to what it is holding, and what this hand is holding is not something a fist can
	# hold -- so there is nothing for the tap to take. Left alone, the tap latched anyway, and
	# the fist it left closed was still closed on the frame the trigger let the switch go: the
	# hand let go of the switch and took the stick beside it, having been told to do neither.
	_hand_between(rig, stick, switch, 0.6)
	rig.force_input(HAND, Bind.TRIGGER, 1.0)
	await _frames(4)
	rig.force_grip(HAND, 1.0)
	await _frames(3)
	rig.force_grip(HAND, 0.0)
	await _frames(3)
	rig.force_input(HAND, Bind.TRIGGER, null)
	await _frames(6)
	_check("and_a_grip_tapped_while_pinching_latches_nothing",
		not switch.is_held() and not stick.is_held(),
		"switch held_by %d, stick held_by %d" % [switch.held_by, stick.held_by])
	rig.force_grip(HAND, -1.0)
	_forget(kit)
	_sections += 1


## HOLD WHATEVER IS CLOSED PAST `PilotRig.TAP_SECONDS`, and say how many milliseconds it took.
##
## ON THE WALL CLOCK, because `_grip_of` is: a run at `--fixed-fps` gets through frames far
## faster than real time, so a count of frames typed here would be a "long press" of four
## milliseconds. Frames go on running throughout, so the rig sees the finger held.
func _hold_past_the_tap() -> int:
	var closed_at: int = Time.get_ticks_msec()
	var window: int = int((PilotRig.TAP_SECONDS + 0.15) * 1000.0)
	while Time.get_ticks_msec() - closed_at < window:
		await _frames(1)
	return Time.get_ticks_msec() - closed_at


## ---- the bench ---------------------------------------------------------------------------

## A RIG AT A PLANE'S PILOT STATION, plus a stick and a switch standing together out on
## their own.
##
## The station is the game's own -- a seat on a plinth and `take_station`, exactly what the
## hall of cockpits does -- so the MASTER ARM switch the request names is the real one.
##
## THE BENCH PAIR IS WELL CLEAR OF THE COCKPIT and `BENCH_GAP` apart, because the ambiguous
## case has to be arranged: every authored cockpit keeps its grips at least one
## `VehicleControl.REACH` apart (`tests/fit.gd`), which is the whole point of that gate and
## also means no authored pair can pose the question. A control named anything at all is
## picked up by `CockpitStation.controls()` and reached by the rig, so these arrive the same
## way a part the builder added does.
func _a_bench() -> Dictionary:
	var plinth := Node3D.new()
	add_child(plinth)
	var station := VehicleCatalogue.seat_scene(TEST_KIND).instantiate() as CockpitStation
	plinth.add_child(station)
	station.fit(TEST_SEAT, true, TEST_KIND, false)

	var bench_stick := FlightStick.new()
	bench_stick.name = "BenchStick"
	bench_stick.position = Vector3(1.40, 0.0, 0.0)
	station.add_child(bench_stick)
	bench_stick.setup(TEST_SEAT)
	# THE SWITCH BESIDE IT, PLACED BY ITS GRIP AND NOT BY ITS ORIGIN. A stick's grip is
	# 22 cm up its own shaft and a switch's is the ball on its bat, so two origins
	# `BENCH_GAP` apart would be two GRIPS a quarter of a metre apart -- and the hand
	# between them would be within reach of neither.
	var bench_switch := ToggleSwitch.new()
	bench_switch.name = "BenchSwitch"
	station.add_child(bench_switch)
	bench_switch.setup(TEST_SEAT)
	bench_switch.position = bench_stick.position + bench_stick._grab_point() \
		+ Vector3(BENCH_GAP, 0.0, 0.0) - bench_switch._grab_point()

	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.take_station(station)
	# THE OTHER HAND OUT OF THE WAY, open and a long way off. Both hands are offered every
	# frame, and a right hand parked at the origin picks up whatever is nearest to it.
	rig.force_grip(OTHER, 0.0)
	rig.force_hand(OTHER, Transform3D(Basis.IDENTITY, Vector3(0.0, -40.0, 0.0)))
	rig.force_grip(HAND, -1.0)
	await _frames(2)
	return {"rig": rig, "station": station, "plinth": plinth,
		"stick": station.controls().get("stick") as VehicleControl,
		"bench_stick": bench_stick, "bench_switch": bench_switch}


## Put the working hand exactly on a control's grip.
func _hand_on(rig: PilotRig, control: VehicleControl) -> void:
	rig.force_hand(HAND, control.global_transform
		* Transform3D(Basis.IDENTITY, control._grab_point()))


## Put the working hand `along` of the way from one control's grip to the other's.
func _hand_between(rig: PilotRig, from: VehicleControl, to: VehicleControl,
		along: float) -> void:
	rig.force_hand(HAND, Transform3D(Basis.IDENTITY,
		from.grip_global().lerp(to.grip_global(), along)))


## How far the working hand is from a control's grip, for a report line.
func _from_hand(rig: PilotRig, control: VehicleControl) -> float:
	var pad: Node3D = rig.left_hand if HAND == 0 else rig.right_hand
	return pad.global_position.distance_to(control.grip_global())


## Walk the hand to a place in the control's OWN frame, a frame at a time, so the drag is
## read as travel rather than as a teleport.
func _hand_follows(rig: PilotRig, control: VehicleControl, local: Vector3,
		frames: int) -> void:
	var from: Vector3 = control._grab_point()
	for i in range(frames):
		var at: Vector3 = from.lerp(from + local, float(i + 1) / float(frames))
		rig.force_hand(HAND, control.global_transform * Transform3D(Basis.IDENTITY, at))
		await get_tree().process_frame


## OPEN THE FIST, AS A SQUEEZE ENDING AND NOT AS A TAP. A grip opened within
## `PilotRig.TAP_SECONDS` of closing is a LATCH, timed on the wall clock, which a run at
## `--fixed-fps` gets through far faster than frames. So the hand stays shut, where it is,
## until that much real time has passed, and taps once more if it latched anyway.
##
## THE PINCH HAS NO LATCH -- see `PilotRig._grip_of`, which is the grip's alone -- so
## nothing like this is needed to let a switch go.
func _open_the_hand(rig: PilotRig, control: VehicleControl) -> void:
	var closed_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - closed_at < int((PilotRig.TAP_SECONDS + 0.15) * 1000.0):
		await _frames(1)
	rig.force_grip(HAND, 0.0)
	await _frames(4)
	if control.held_by == HAND:
		rig.force_grip(HAND, 1.0)
		await _frames(2)
		rig.force_grip(HAND, 0.0)
		await _frames(4)
	rig.force_grip(HAND, -1.0)


func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().process_frame


func _forget(kit: Dictionary) -> void:
	(kit["rig"] as Node).queue_free()
	(kit["plinth"] as Node).queue_free()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
