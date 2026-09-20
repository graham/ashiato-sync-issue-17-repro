extends Node
## Headless: what the player FEELS and HEARS, which until now was nothing at all.
##
##   Godot --headless --path cockpit res://tests/feel.tscn
##
## Two senses, one suite, because they are one gap. A review of this project counted zero
## `trigger_haptic_pulse` calls across twenty-five control classes in a game whose entire
## interaction is closing a hand around a lever, and zero `AudioStreamPlayer` of any kind in
## a flight simulator. Neither is a polish item: an engine note is how a pilot holds a power
## setting without looking at anything, and a grab that produces no pulse is a grab you are
## not sure happened.
##
## WHAT A HEADLESS MACHINE CAN AND CANNOT SAY ABOUT EITHER. It cannot tell you whether a
## pulse feels right or whether an engine sounds like an engine -- those want a headset and
## a pair of ears, and they are said so in the report. What it CAN say is the half that
## actually breaks: that the call is made, that it is made ONCE, that the mapping from
## throttle and airspeed to pitch and level is monotonic and bounded, and that a silent
## machine stays silent. Every one of those is a thing that has been wrong in this project
## in some other domain and was found by counting.
##
## Read RESULT=, not the exit code.

const TEST_KIND: Sim.Kind = Sim.Kind.PLANE
const TEST_SEAT: int = 0

var _failures: PackedStringArray = []
## Sections that reached their own end. A GDScript error aborts the function it is in and
## carries on with the next, so counting only failures reports a cheerful pass over a
## section that fell over halfway.
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[feel] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	await _a_hand_is_told_when_it_takes_hold()
	await _a_detent_clicks_once_per_stop()
	await _a_round_kicks_and_a_pull_does_not()
	await _a_free_hand_feels_the_edge_of_reach()
	await _a_hand_moving_between_neighbours_is_told_once()
	await _a_hand_flickering_at_the_edge_is_not_a_rumble()
	_the_note_follows_the_throttle_and_the_speed()
	_a_craft_sounds_like_its_own_size()
	await _a_manned_craft_gets_a_voice_and_an_empty_one_does_not()
	_check("every_section_of_the_suite_ran", _sections == 9, "%d of 9" % _sections)
	_finish()


## ---- haptics ---------------------------------------------------------------------------

## THROUGH THE RIG, WHICH IS THE POINT.
##
## Every other grab test in this project calls `VehicleControl.offer_hand` directly, which
## is the layer BELOW the thing that decides anything: the latch, the choice of nearest
## control, the one-hand-one-control rule and the pulse all live in `PilotRig`, and none of
## them was reachable from a suite until `force_grip` existed. So this closes a hand at the
## rig and lets the rig work out the rest.
##
## ON THE STICK AND NOT ON THE SELECTOR, since 2026-09-15. The latch below is the GRIP's
## alone -- `PilotRig._taking_finger` says why -- and a selector is pinched, so a fist closed
## on one now does nothing at all. The stick is the nearest grabbed thing to a hand on its own
## grip: every authored cockpit keeps its grips a reach apart (`tests/fit.gd`), which is what
## makes "put the hand on it" an unambiguous instruction.
func _a_hand_is_told_when_it_takes_hold() -> void:
	var kit: Dictionary = await _a_rig_at_a_console(false)
	var rig: PilotRig = kit["rig"]
	var dial: VehicleControl = kit["stick"]
	rig.forget_pulses()

	_put_the_hand_on(rig, dial, 0.0)
	rig.force_grip(0, 1.0)
	await _frames(3)
	_check("a_hand_closing_on_a_control_is_told_it_worked", rig.pulses(&"grab") == 1,
		"%d grab pulse(s), holding %s" % [rig.pulses(&"grab"), dial.is_held()])

	# AND HOLDING IS NOT AN EVENT. A pulse driven by a STATE rather than by an edge buzzes
	# at the display rate for as long as the hand stays shut, which is not a cue, it is a
	# fault. Ten frames of holding still, and the count must not have moved.
	await _frames(10)
	_check("and_holding_on_does_not_go_on_buzzing", rig.pulses(&"grab") == 1,
		"%d grab pulse(s) after ten more frames" % rig.pulses(&"grab"))

	# AND OPENING THE HAND QUICKLY IS A LATCH, NOT A RELEASE -- which is `_grip_of`'s whole
	# job and which this suite found out the hard way, having expected a release and got a
	# hand still holding the knob. A tap pins the hand to what it has; a second tap lets go.
	# It is the right behaviour and it is why holding a lever at 300 kph is not a hand cramp.
	rig.force_grip(0, 0.0)
	await _frames(3)
	_check("and_a_quick_tap_latches_rather_than_letting_go",
		dial.is_held() and rig.pulses(&"release") == 0,
		"holding %s, %d release pulse(s)" % [dial.is_held(), rig.pulses(&"release")])

	# THE SECOND TAP.
	rig.force_grip(0, 1.0)
	await _frames(2)
	rig.force_grip(0, 0.0)
	await _frames(3)
	_check("and_letting_go_is_a_smaller_one_of_its_own",
		rig.pulses(&"release") == 1 and not dial.is_held(),
		"%d release pulse(s), holding %s" % [rig.pulses(&"release"), dial.is_held()])
	# THE FEELINGS ARE DIFFERENT SIZES, which is the whole reason they are named rather than
	# being one number. Letting go is deliberately quieter than taking hold.
	var grab: Vector2 = PilotRig.FEEL[&"grab"]
	var release: Vector2 = PilotRig.FEEL[&"release"]
	_check("and_letting_go_is_quieter_than_taking_hold", release.x < grab.x,
		"release %.2f against grab %.2f" % [release.x, grab.x])
	_forget(kit)
	_sections += 1


## ONE CLICK PER STOP, and not one per frame and not one per degree of wrist.
##
## `DetentDial` has modelled detents geometrically since the day it was written and had no
## way at all to tell a hand it had crossed one. The count is the assertion that matters:
## a bump raised on the ANGLE rather than on the change of `at_stop` would fire every frame
## the wrist was moving, and a bump left set rather than drained would fire every frame the
## hand stayed on the knob.
func _a_detent_clicks_once_per_stop() -> void:
	var kit: Dictionary = await _a_rig_at_a_console(false)
	var rig: PilotRig = kit["rig"]
	var dial: DetentDial = kit["dial"]
	_put_the_hand_on(rig, dial, 0.0)
	# PINCHED AND NOT GRABBED. A selector is taken between finger and thumb -- see
	# `DetentDial.taken_by` -- so the finger that closes on it is the trigger.
	_close_on(rig, dial, 1.0)
	await _frames(3)
	rig.forget_pulses()
	_check("the_dial_starts_at_its_first_stop", dial.at_stop() == 0,
		"stop %d of %d, %s" % [dial.at_stop(), dial.stops.size(), dial.stop_name()])

	# ROLLING THE WRIST ONE STOP AT A TIME. The sweep is 90 degrees over the whole selector
	# and the default has three stops, so a stop is 45 degrees of wrist -- which is what
	# `SWEEP / (stops - 1)` says and is asked for rather than typed.
	var per_stop: float = DetentDial.SWEEP / float(maxi(dial.stops.size() - 1, 1))
	_put_the_hand_on(rig, dial, -per_stop)
	await _frames(3)
	_check("a_wrist_turned_one_stop_clicks_once",
		rig.pulses(&"detent") == 1 and dial.at_stop() == 1,
		"%d click(s), on %s" % [rig.pulses(&"detent"), dial.stop_name()])

	# AND HOLDING IT THERE IS NOT A SECOND CLICK.
	await _frames(8)
	_check("and_resting_on_a_stop_does_not_click_again", rig.pulses(&"detent") == 1,
		"%d click(s) after eight more frames" % rig.pulses(&"detent"))

	_put_the_hand_on(rig, dial, -per_stop * 2.0)
	await _frames(3)
	_check("and_the_next_stop_is_the_second_click",
		rig.pulses(&"detent") == 2 and dial.at_stop() == 2,
		"%d click(s), on %s" % [rig.pulses(&"detent"), dial.stop_name()])
	# AND A CLICK IS AT LEAST AS STRONG AS IT EVER WAS. The user asked for every buzz to be stronger, and a first go at
	# the table took the detent from 0.51 at the motor to 0.425 (2026-09-13). Read off what went out.
	var click: Vector2 = rig.last_pulse(&"detent")
	_check("and_a_click_goes_to_the_motor_no_weaker_than_it_first_did", click.x >= 0.51,
		"detent %.3f at the motor for %.0f ms, against 0.510 before" % [click.x, click.y * 1000.0])
	_forget(kit)
	_sections += 1


## THE GUN KICKS FOR EVERY ROUND, NOT FOR THE PULL -- AND EACH KICK IS OVER BEFORE THE NEXT ROUND.
##
## A kick per pull was a door gun firing eleven rounds a second that felt like one shot, and a
## pull on a howitzer still loading that kicked a gun which had not fired. So the pull announces
## nothing, and the rig kicks once per round the level hands it (`tests/gunners.gd` counts those
## through a real grip). What is checked here is the shape: a kick must be SHORTER than the gun's
## own time between rounds, or thirty a second is one continuous rumble -- asked for on 2026-09-13.
func _a_round_kicks_and_a_pull_does_not() -> void:
	var kit: Dictionary = await _a_rig_at_a_console(false)
	var rig: PilotRig = kit["rig"]
	var trigger := GunTrigger.new()
	kit["station"].add_child(trigger)
	trigger.setup(TEST_SEAT)
	await _frames(1)

	trigger.hand_input(Bind.TRIGGER, true)
	_check("pulling_a_trigger_announces_nothing_on_its_own", trigger.take_bump() == &"",
		"a round is what is felt")
	trigger.hand_input(Bind.TRIGGER, false)
	rig.forget_pulses()
	# EVERY GUN IN THE GAME, at its own rate from the simulation's table: the kick that went out is
	# read off the call, not out of FEEL.
	var long: Array[String] = []
	var worst: String = ""
	for kind in Sim.Kind.values():
		for mount in range(3):
			var gun: Dictionary = Sim.gun_of(kind, mount)
			if not bool(gun.get("fitted", false)):
				continue
			var reload: float = float(gun.get("reload", 1.0))
			rig.kick_for_a_round(1, reload)
			var sent: Vector2 = rig.last_pulse(&"round")
			var line: String = "%s %d: %.0f%% for %.0f ms every %.0f ms" % [Sim.kind_name(kind), mount,
				sent.x * 100.0, sent.y * 1000.0, reload * 1000.0]
			print("[feel] round kick %s" % line)
			if sent.y >= reload or sent.x <= 0.0:
				long.append(line)
			if reload < 0.05:
				worst = line
	_check("every_guns_kick_is_over_before_its_next_round", long.is_empty(),
		"%s" % [worst if long.is_empty() else long])

	# THE CHOKE POINT COUNTS ON A MACHINE WITH NO MOTOR, which is the seam the whole of
	# this suite stands on. `pulse` returns early when there is no headset and increments
	# first -- counting only when a runtime is attached would leave this untestable
	# everywhere it is run.
	rig.forget_pulses()
	rig.felt(1, &"trigger")
	_check("and_a_rig_with_no_headset_still_counts_what_it_would_have_sent",
		rig.pulses(&"trigger") == 1 and rig.pulses() == 1,
		"trigger=%d any=%d using_xr=%s" % [rig.pulses(&"trigger"), rig.pulses(), rig.using_xr])
	# A NAME NOTHING FEELS IS NOT A PULSE. An unknown reason has no shape to send, so it
	# must not quietly go out as a zero-length buzz that a count would report as real.
	rig.felt(1, &"nonsense")
	_check("and_a_feeling_nobody_named_is_not_sent", rig.pulses() == 1,
		"any=%d after an unknown reason" % rig.pulses())
	_forget(kit)
	_sections += 1


## ---- the edge of reach -------------------------------------------------------------------

## A FREE HAND IS TOLD WHEN A CONTROL COMES WITHIN ITS GRASP, and when it goes out of it -- once each.
##
## Walked in a centimetre at a time from forty centimetres above the knob, the way a hand arrives, rather than dropped on
## the grip: the check that matters is WHERE the buzz came, and it must be the reach the grab uses. A buzz at some other
## radius is a promise the grip does not keep. Every step waits two frames, because awaiting `process_frame` resumes
## before the rig's own `_process` has run on it.
##
## AND EVERY EDGE IS WAITED PAST `PilotRig.REACH_GAP` before the next is looked for, because an edge inside the gap is
## deferred rather than dropped: a check straight after one edge would be a check of the gap and not of the margin.
func _a_free_hand_feels_the_edge_of_reach() -> void:
	var kit: Dictionary = await _a_rig_at_a_console(false)
	var rig: PilotRig = kit["rig"]
	var dial: DetentDial = kit["dial"]
	var grip: Vector3 = dial.grip_global()
	var above: Vector3 = dial.global_transform.basis.y.normalized()
	rig.force_grip(0, 0.0)
	_put_the_hand_at(rig, grip + above * 0.40)
	await _wait_out_the_gap()
	rig.forget_pulses()

	# HALF-CENTIMETRE OFFSETS, so no step lands exactly on the radius and the answer does not hang on a rounding.
	var felt_at: float = -1.0
	for step in range(40, -1, -1):
		var away: float = 0.005 + float(step) * 0.01
		_put_the_hand_at(rig, grip + above * away)
		await _frames(2)
		if felt_at < 0.0 and rig.pulses(&"reach") > 0:
			felt_at = away
	_check("a_free_hand_moved_within_reach_of_a_control_is_told_once",
		rig.pulses(&"reach") == 1 and rig.pulses(&"unreach") == 0,
		"%d reach, %d unreach" % [rig.pulses(&"reach"), rig.pulses(&"unreach")])
	_check("and_it_is_told_at_the_reach_a_grab_uses",
		felt_at > 0.0 and felt_at < VehicleControl.REACH and felt_at > VehicleControl.REACH - 0.01,
		"felt at %.3f m against a reach of %.3f" % [felt_at, VehicleControl.REACH])
	await _frames(10)
	_check("and_resting_there_is_not_told_again", rig.pulses(&"reach") == 1,
		"%d reach after ten more frames" % rig.pulses(&"reach"))

	# TREMBLING ACROSS THE EDGE, three millimetres either side of it, ten times. A tracked hand does this held still.
	await _wait_out_the_gap()
	for i in range(10):
		_put_the_hand_at(rig, grip + above * (VehicleControl.REACH + (0.003 if i % 2 == 0 else -0.003)))
		await _frames(2)
	await _wait_out_the_gap()
	_check("and_a_hand_trembling_on_the_edge_is_not_told_anything",
		rig.pulses(&"reach") == 1 and rig.pulses(&"unreach") == 0,
		"%d reach, %d unreach" % [rig.pulses(&"reach"), rig.pulses(&"unreach")])

	var left_at: float = -1.0
	for step in range(17, 41):
		var away: float = 0.005 + float(step) * 0.01
		_put_the_hand_at(rig, grip + above * away)
		await _frames(2)
		if left_at < 0.0 and rig.pulses(&"unreach") > 0:
			left_at = away
	_check("and_moving_out_of_reach_is_told_once", rig.pulses(&"unreach") == 1 and rig.pulses(&"reach") == 1,
		"%d unreach, %d reach" % [rig.pulses(&"unreach"), rig.pulses(&"reach")])
	var outer: float = VehicleControl.REACH + PilotRig.REACH_MARGIN
	_check("but_only_once_past_the_margin", left_at > outer and left_at < outer + 0.01,
		"left at %.3f m against %.3f + %.3f" % [left_at, VehicleControl.REACH, PilotRig.REACH_MARGIN])

	# AND TREMBLING ON THE OUTER EDGE, which is the other half of the hysteresis.
	await _wait_out_the_gap()
	for i in range(10):
		_put_the_hand_at(rig, grip + above * (outer + (0.003 if i % 2 == 0 else -0.003)))
		await _frames(2)
	await _wait_out_the_gap()
	_check("and_trembling_just_outside_is_not_told_anything",
		rig.pulses(&"reach") == 1 and rig.pulses(&"unreach") == 1,
		"%d reach, %d unreach" % [rig.pulses(&"reach"), rig.pulses(&"unreach")])

	# WHAT WENT TO THE MOTOR, read off the call. Asked for as "a couple of hundred milliseconds" that can be felt, so the
	# floor is 150 ms and the ceiling the gap: longer than that and one buzz runs into the next edge.
	var reach: Vector2 = rig.last_pulse(&"reach")
	var unreach: Vector2 = rig.last_pulse(&"unreach")
	var to_motor := Vector2(PilotRig.HAPTIC_MASTER, 1.0)
	var table_reach: Vector2 = PilotRig.FEEL.get(&"reach", Vector2.ZERO)
	var table_unreach: Vector2 = PilotRig.FEEL.get(&"unreach", Vector2.ZERO)
	_check("and_both_edges_send_what_the_table_says",
		reach != Vector2.ZERO and reach.is_equal_approx(table_reach * to_motor)
			and unreach.is_equal_approx(table_unreach * to_motor),
		"reach %.3f for %.3f s, unreach %.3f for %.3f s" % [reach.x, reach.y, unreach.x, unreach.y])
	_check("and_both_last_a_couple_of_hundred_milliseconds",
		reach.y >= 0.15 and unreach.y >= 0.15 and reach.y <= PilotRig.REACH_GAP and unreach.y <= PilotRig.REACH_GAP,
		"reach %.0f ms, unreach %.0f ms" % [reach.y * 1000.0, unreach.y * 1000.0])
	_forget(kit)
	_sections += 1


## FROM ONE CONTROL STRAIGHT ONTO ITS NEIGHBOUR IS ONE BUZZ, and a hand holding something is told about nothing it passes.
##
## Two selectors half a reach apart, so each is inside the other's reach, which is a console. The hand slides from one
## grip to the other: it must be told once, about the new one, and never "out" -- and a squeeze at the end must take the
## one it was told about. Then, holding it, the hand sweeps back across the first and on past it and must feel nothing.
func _a_hand_moving_between_neighbours_is_told_once() -> void:
	var kit: Dictionary = await _a_rig_at_a_console(true)
	var rig: PilotRig = kit["rig"]
	var dial: DetentDial = kit["dial"]
	var other: DetentDial = kit["neighbour"]
	var from: Vector3 = dial.grip_global()
	var to: Vector3 = other.grip_global()
	rig.force_grip(0, 0.0)
	_put_the_hand_at(rig, from)
	await _wait_out_the_gap()
	rig.forget_pulses()

	_put_the_hand_at(rig, from.lerp(to, 0.5))
	await _frames(2)
	for i in range(10):
		_put_the_hand_at(rig, from.lerp(to, 0.5) + (to - from).normalized() * (0.003 if i % 2 == 0 else -0.003))
		await _frames(2)
	await _wait_out_the_gap()
	_check("a_hand_trembling_halfway_between_two_controls_is_not_told_anything", rig.pulses() == 0,
		"%d pulse(s)" % rig.pulses())

	for step in range(6, 11):
		_put_the_hand_at(rig, from.lerp(to, float(step) / 10.0))
		await _frames(2)
	await _wait_out_the_gap()
	_check("and_sliding_on_to_the_neighbour_is_one_reach_and_no_unreach",
		rig.pulses(&"reach") == 1 and rig.pulses(&"unreach") == 0,
		"%d reach, %d unreach" % [rig.pulses(&"reach"), rig.pulses(&"unreach")])

	_close_on(rig, other, 1.0)
	await _frames(3)
	_check("and_a_squeeze_there_takes_the_one_it_was_told_about", other.is_held() and not dial.is_held(),
		"neighbour held %s, first held %s" % [other.is_held(), dial.is_held()])
	# AND THE EDGE IS THE BIGGER THING TO FEEL, which is the request: a grab is a thump a hand already knows it is making,
	# and the edge is the one a player is feeling FOR. Both read off what went to the motor.
	var reach: Vector2 = rig.last_pulse(&"reach")
	var grab: Vector2 = rig.last_pulse(&"grab")
	_check("and_coming_within_reach_is_felt_harder_and_longer_than_a_grab",
		grab.y > 0.0 and reach.x > grab.x and reach.y > grab.y,
		"reach %.3f for %.0f ms, grab %.3f for %.0f ms" % [reach.x, reach.y * 1000.0, grab.x, grab.y * 1000.0])
	# AND THE GRAB ITSELF IS SOMETHING A MOTOR WILL RENDER. It went out at 0.38 for 35 ms until 2026-09-13 and a player in
	# a headset felt nothing; half strength at the motor is the floor asked for.
	_check("and_a_grab_goes_to_the_motor_at_half_strength_or_more", grab.x >= 0.5,
		"grab %.3f at the motor" % grab.x)
	# AND NOTHING ON A CONTROL OUTWEIGHS THE EDGE OF ONE. The table, because a release and a detent are not sent on this
	# bench -- the rule is between entries, so it is the entries that are compared.
	var edge: Vector2 = PilotRig.FEEL.get(&"reach", Vector2.ZERO)
	var louder: PackedStringArray = []
	for why in [&"grab", &"release", &"detent"]:
		var shape: Vector2 = PilotRig.FEEL[why]
		if shape.x >= edge.x or shape.y >= edge.y:
			louder.append(String(why))
	_check("and_a_grab_a_release_and_a_detent_are_all_lighter_and_shorter_than_reach", louder.is_empty(),
		"not under reach: %s" % (", ".join(louder) if not louder.is_empty() else "none"))
	var detent: Vector2 = PilotRig.FEEL[&"detent"]
	var grab_shape: Vector2 = PilotRig.FEEL[&"grab"]
	_check("and_a_detent_is_still_a_click", detent.y < grab_shape.y,
		"detent %.0f ms against grab %.0f ms" % [detent.y * 1000.0, grab_shape.y * 1000.0])

	rig.forget_pulses()
	for step in range(0, 13):
		_put_the_hand_at(rig, to.lerp(from, float(step) / 4.0))
		await _frames(2)
	await _wait_out_the_gap()
	_check("and_a_hand_holding_something_is_not_told_about_what_it_passes",
		rig.pulses(&"reach") == 0 and rig.pulses(&"unreach") == 0 and other.is_held(),
		"%d reach, %d unreach, still holding %s" % [rig.pulses(&"reach"), rig.pulses(&"unreach"), other.is_held()])
	_forget(kit)
	_sections += 1


## A HAND FLICKED IN AND OUT OF REACH FASTER THAN A BUZZ LASTS IS NOT ONE LONG RUMBLE, and is not left lying about it.
##
## Right across both edges every two frames, so the margin cannot hide it: this is the backstop, `PilotRig.REACH_GAP`,
## and nothing else. No more than one edge per gap, counted against the frame time that actually passed -- the rig's own
## clock is its frames, so that is the time to count in -- and the hand ends outside, so once the gap is over the rig
## must have told it so: as many unreaches as reaches.
func _a_hand_flickering_at_the_edge_is_not_a_rumble() -> void:
	var kit: Dictionary = await _a_rig_at_a_console(false)
	var rig: PilotRig = kit["rig"]
	var dial: DetentDial = kit["dial"]
	var grip: Vector3 = dial.grip_global()
	var above: Vector3 = dial.global_transform.basis.y.normalized()
	rig.force_grip(0, 0.0)
	_put_the_hand_at(rig, grip + above * 0.40)
	await _wait_out_the_gap()
	rig.forget_pulses()

	var took: float = 0.0
	var flips: int = 0
	while took < 0.6:
		_put_the_hand_at(rig, grip + above * (0.05 if flips % 2 == 0 else 0.40))
		flips += 1
		for i in range(2):
			await get_tree().process_frame
			took += get_process_delta_time()
	_put_the_hand_at(rig, grip + above * 0.40)
	var most: int = int(floor(took / PilotRig.REACH_GAP)) + 1
	var during: int = rig.pulses()
	_check("a_hand_flicked_in_and_out_of_reach_buzzes_no_more_than_once_a_gap",
		during >= 2 and during <= most,
		"%d pulse(s) over %d flips in %.3f s, at most %d" % [during, flips, took, most])
	await _wait_out_the_gap()
	_check("and_a_hand_that_ends_outside_is_told_it_is_outside",
		rig.pulses(&"reach") >= 1 and rig.pulses(&"reach") == rig.pulses(&"unreach"),
		"%d reach, %d unreach" % [rig.pulses(&"reach"), rig.pulses(&"unreach")])
	_forget(kit)
	_sections += 1


## ---- sound -------------------------------------------------------------------------------

## THE MAPPING, WALKED ACROSS ITS WHOLE RANGE.
##
## `tone_for` is three numbers in and three out with no state anywhere, which is the entire
## reason it exists as a static: a suite on a machine with no audio device can say whether
## the engine note rises with power, whether the wind rises with speed, and whether either
## can leave the range -- and none of those needs a sound card, a craft or a session.
##
## What it CANNOT say is whether the result sounds like an aeroplane. That wants a pair of
## ears and is written down as such in the report rather than pretended at here.
func _the_note_follows_the_throttle_and_the_speed() -> void:
	var base: float = 100.0
	var shut: Dictionary = VehicleSound.tone_for(base, 0.0, 0.0)
	var open: Dictionary = VehicleSound.tone_for(base, 1.0, 0.0)
	_check("opening_the_throttle_raises_the_note",
		float(open["hz"]) > float(shut["hz"]) * 1.2,
		"%.1f Hz shut, %.1f Hz open" % [shut["hz"], open["hz"]])
	_check("and_makes_it_louder", float(open["engine"]) > float(shut["engine"]),
		"%.2f shut, %.2f open" % [shut["engine"], open["engine"]])
	# AN IDLING ENGINE IS NOT A SILENT ONE. Both floors are deliberate: a craft with the
	# power off still tells you it is running, which is how you know it has not stopped.
	_check("and_an_idling_engine_is_still_running",
		float(shut["engine"]) > 0.0 and float(shut["hz"]) > 0.0,
		"%.2f at %.1f Hz" % [shut["engine"], shut["hz"]])

	# MONOTONIC ALL THE WAY ACROSS, not just at the ends. A mapping that rose and then fell
	# back would pass a two-point check and be a throttle you cannot hold a setting on.
	var climbing: bool = true
	var last: float = -1.0
	for step in range(21):
		var here: float = float(VehicleSound.tone_for(base, float(step) / 20.0, 0.0)["hz"])
		if here < last:
			climbing = false
		last = here
	_check("and_the_note_never_falls_as_the_power_goes_up", climbing,
		"21 steps, ending at %.1f Hz" % last)

	# THE WIND IS THE SQUARE OF SPEED, which is the term the drag is. So half speed is a
	# QUARTER of the roar rather than half of it, and the difference between those two is
	# whether taxiing sounds like flying.
	var still: float = float(VehicleSound.tone_for(base, 0.0, 0.0)["wind"])
	var half: float = float(VehicleSound.tone_for(base, 0.0,
		VehicleSound.WIND_FULL * 0.5)["wind"])
	var full: float = float(VehicleSound.tone_for(base, 0.0, VehicleSound.WIND_FULL)["wind"])
	_check("the_wind_is_silent_at_a_standstill", is_equal_approx(still, 0.0),
		"%.4f at 0 m/s" % still)
	_check("and_rises_with_the_square_of_the_speed",
		absf(half - full * 0.25) < 0.001 and full > half,
		"%.3f at half speed against %.3f at full" % [half, full])

	# AND NOTHING LEAVES THE RANGE, at any input anybody could hand it -- including the
	# ones nobody should: a negative throttle, and twice the fastest thing in the game.
	var bounded: bool = true
	var worst: String = ""
	for throttle in [-1.0, 0.0, 0.5, 1.0, 2.0]:
		for speed in [-50.0, 0.0, 80.0, 400.0]:
			var tone: Dictionary = VehicleSound.tone_for(base, throttle, speed)
			for part in ["engine", "wind"]:
				var value: float = float(tone[part])
				if value < 0.0 or value > 1.0:
					bounded = false
					worst = "%s=%.3f at throttle %.1f, %.0f m/s" % [part, value, throttle, speed]
	_check("and_no_level_ever_leaves_0_to_1", bounded,
		worst if worst != "" else "20 combinations, all inside")
	_sections += 1


## A CRAFT SOUNDS LIKE ITS OWN SIZE, and the size comes off the simulation's shape table.
##
## The one thing that must not happen here is a second table of masses. `base_note` asks
## `Sim.geometry_of`, exactly as the drawn geometry does, so retuning a craft's mass in the
## C++ retunes its note with it.
func _a_craft_sounds_like_its_own_size() -> void:
	# EVERY CRAFT IN THE TABLE, lightest to heaviest, each strictly lower than the one before
	# it that weighs less. It named three -- a plane, an airliner, a tank, in that order of
	# weight -- until lane/liners made the 737 exactly the tank's 62 t (2026-09-19): a roster
	# of which craft is heavier is a second table of masses, and the curve under it had put
	# the 747, the train and every ship on one floor note that three names never looked at.
	var by_mass: Array = []
	for kind in Sim.Kind.values():
		by_mass.append([float(Sim.geometry_of(kind).get("mass", 0.0)), kind])
	by_mass.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out_of_tune: PackedStringArray = []
	for i in range(1, by_mass.size()):
		var lighter: Array = by_mass[i - 1]
		var heavier: Array = by_mass[i]
		if heavier[0] <= lighter[0]:
			continue
		var lighter_hz: float = VehicleSound.base_note(lighter[1])
		var heavier_hz: float = VehicleSound.base_note(heavier[1])
		if not (heavier_hz < lighter_hz):
			out_of_tune.append("%s %.0f kg %.1f Hz, not under %s %.0f kg %.1f Hz" % [Sim.Kind.find_key(heavier[1]),
				heavier[0], heavier_hz, Sim.Kind.find_key(lighter[1]), lighter[0], lighter_hz])
	_check("a_heavier_craft_has_a_lower_note", by_mass.size() > 2 and out_of_tune.is_empty(),
		"%d kinds, %.1f Hz to %.1f Hz; %s" % [by_mass.size(), VehicleSound.base_note(by_mass[0][1]),
			VehicleSound.base_note(by_mass[-1][1]), out_of_tune])
	# AND THE FLOOR HOLDS. Ten thousand tonnes on the old cube root worked out at about four
	# hertz, which is not a note, it is a vibration nothing can reproduce; the curve now lands
	# the heaviest craft on the floor, and this holds it there rather than under it.
	var ship: float = VehicleSound.base_note(Sim.Kind.CARRIER)
	_check("and_a_ten_thousand_tonne_ship_is_still_a_note",
		ship >= VehicleSound.MIN_HZ, "%.1f Hz against a floor of %.1f"
		% [ship, VehicleSound.MIN_HZ])

	_check("a_glider_has_nothing_running", not VehicleSound.has_an_engine(Sim.Kind.GLIDER),
		"engine: %s" % VehicleSound.has_an_engine(Sim.Kind.GLIDER))
	_check("and_neither_has_a_control_tower", not VehicleSound.has_an_engine(Sim.Kind.TOWER),
		"model %s" % Sim.geometry_of(Sim.Kind.TOWER).get("model_name", "?"))
	_check("and_an_aeroplane_has", VehicleSound.has_an_engine(Sim.Kind.PLANE), "engine: true")

	# SILENT WHERE THERE IS NOBODY TO HEAR IT. This suite runs headless, so this is the one
	# check in it that is about the suite's own conditions -- and it is worth having,
	# because the failure it guards is twenty-one suites each filling a ring buffer.
	_check("and_a_machine_with_no_audio_device_builds_no_players",
		not VehicleSound.audible(), "display server is %s" % DisplayServer.get_name())
	# AND OFF UNLESS ASKED FOR, everywhere else. Most development here is headless or an
	# agent looking at a window, so silence is the default and `--audio` is the switch.
	_check("and_sound_is_off_unless_asked_for",
		not VehicleSound.asked_for(PackedStringArray([])
			) and not VehicleSound.asked_for(PackedStringArray(["--level=fly"])),
		"an empty line and a line without %s are both silent" % VehicleSound.AUDIO_FLAG)
	_check("and_the_flag_turns_it_on",
		VehicleSound.asked_for(PackedStringArray(["--level=fly", VehicleSound.AUDIO_FLAG])),
		"%s is the word" % VehicleSound.AUDIO_FLAG)
	var quiet := VehicleSound.new()
	add_child(quiet)
	quiet.setup(Sim.Kind.PLANE)
	_check("and_setting_one_up_there_makes_no_sound_node",
		quiet.get_child_count() == 0, "%d child node(s)" % quiet.get_child_count())
	quiet.queue_free()
	_sections += 1


## A CRAFT GETS A VOICE WHEN SOMEBODY SITS IN IT, and loses it when they get out.
##
## The same rule the stations follow and for the same measured reason: a hundred and forty
## machines nobody is in would be a hundred and forty generators being filled for nobody.
## `man` is the one place either happens, so there is one edge to get right.
func _a_manned_craft_gets_a_voice_and_an_empty_one_does_not() -> void:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene) 		.instantiate() as VehicleView
	add_child(view)
	view.setup(1, TEST_KIND)
	await _frames(1)
	_check("an_empty_craft_has_no_voice", view.sound == null, "sound: %s" % view.sound)
	# A CREW OF ONE IS A CREW. The list is what `Sky` hands over each frame: one row per
	# person aboard.
	view.man([{"seat": 0, "client": 1}], 0)
	await _frames(1)
	_check("and_somebody_sitting_down_gives_it_one", view.sound != null,
		"sound: %s, kind %s" % [view.sound, Sim.kind_name(view.kind)])
	_check("and_it_is_tuned_to_that_craft", view.sound != null
		and is_equal_approx(view.sound._base_hz, VehicleSound.base_note(TEST_KIND)),
		"%.1f Hz" % [view.sound._base_hz if view.sound != null else -1.0])
	view.man([], -1)
	await _frames(2)
	_check("and_everybody_getting_out_takes_it_away_again", view.sound == null,
		"sound: %s" % view.sound)
	view.queue_free()
	_sections += 1


## ---- the bench ---------------------------------------------------------------------------

## A RIG AT A STATION, with a selector on it, and a second one beside it if `neighbour`.
##
## The hall of cockpits does exactly this -- a station on a plinth and `take_station` --
## so it is the game's own arrangement rather than a fixture invented for the suite. The
## dial is added because no authored station carries one yet and `CockpitStation.controls()`
## already picks up anything a player put there, which is how the builder's parts arrive.
func _a_rig_at_a_console(neighbour: bool) -> Dictionary:
	var plinth := Node3D.new()
	add_child(plinth)
	var station := VehicleCatalogue.seat_scene(TEST_KIND).instantiate() as CockpitStation
	plinth.add_child(station)
	station.fit(TEST_SEAT, true, TEST_KIND, false)
	var dial := DetentDial.new()
	dial.name = "Selector"
	# WELL CLEAR OF EVERYTHING ELSE. A hand is offered the NEAREST control it could take,
	# so a dial dropped on top of the console furniture would be a test of which control
	# happens to be closer rather than of the dial.
	dial.position = Vector3(0.62, 0.0, 0.0)
	station.add_child(dial)
	dial.setup(TEST_SEAT)
	# A SECOND SELECTOR INSIDE THE FIRST ONE'S REACH, for the suite that slides a hand from one to the other. Half a
	# reach apart, asked of the reach rather than typed, so a grip sitting on one is inside the other's.
	var next: DetentDial = null
	if neighbour:
		next = DetentDial.new()
		next.name = "Neighbour"
		next.position = dial.position + Vector3(VehicleControl.REACH * 0.5, 0.0, 0.0)
		station.add_child(next)
		next.setup(TEST_SEAT)

	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.take_station(station)
	# THE OTHER HAND OUT OF THE WAY, open and a long way off. Both hands are offered every
	# frame, and a right hand parked at the origin picks up whatever is nearest to it.
	rig.force_grip(1, 0.0)
	rig.force_hand(1, Transform3D(Basis.IDENTITY, Vector3(0.0, -40.0, 0.0)))
	await _frames(2)
	return {"rig": rig, "station": station, "dial": dial, "neighbour": next,
		"plinth": plinth, "stick": station.controls().get("stick") as VehicleControl}


## CLOSE THE FINGER THAT TAKES `control`, whatever that finger is. See
## `VehicleControl.taken_by`: a stick answers a fist and a selector answers the trigger, and a
## suite that closed the wrong one would be a suite watching a hand that never took anything.
func _close_on(rig: PilotRig, control: VehicleControl, shut: float) -> void:
	if control.taken_by() == Bind.Take.PINCH:
		rig.force_input(0, Bind.TRIGGER, shut)
	else:
		rig.force_grip(0, shut)


## Put the left hand on a control's grip, with the wrist rolled about the control's own up.
func _put_the_hand_on(rig: PilotRig, control: VehicleControl, roll: float) -> void:
	rig.force_hand(0, control.global_transform
		* Transform3D(Basis(Vector3.UP, roll), control._grab_point()))


## Put the left hand at a place in the world, facing nowhere in particular.
func _put_the_hand_at(rig: PilotRig, at: Vector3) -> void:
	rig.force_hand(0, Transform3D(Basis.IDENTITY, at))


## PAST `PilotRig.REACH_GAP`, and three frames for the rig to act on it. A timer and not a count of frames, because the
## rig's clock is its frame time and `--fixed-fps` makes a frame a sixtieth whatever the wall clock says -- which a timer
## follows and a frame count typed here would not.
func _wait_out_the_gap() -> void:
	await get_tree().create_timer(PilotRig.REACH_GAP + 0.05).timeout
	await _frames(3)


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
