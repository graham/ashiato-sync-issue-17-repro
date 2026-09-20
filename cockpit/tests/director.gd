extends Node
## Headless: THE DIRECTOR'S CAMERA -- the switch, the red light, the field of view, the carry, and the
## rule about the beam and the pinch.
##
##   Godot --headless --path cockpit --xr-mode off res://tests/director.tscn
##
## THE GATE FOR plan.md ITEM 20. Asked for on 2026-09-15: *"it's very important that I can record my
## play sessions ... I want a floating camera that i can position in my cockpit, and grab it with my
## hand and move it ... a button to turn it on and off and a red light if it's on, and some fov buttons
## so i can modify those things by clicking small buttons with the pinch gesture we built earlier."*
##
## ---------------------------------------------------------------------------------
## WHAT IT CAN SAY WITHOUT A HEADSET AND WITHOUT A SCREEN, WHICH IS MOST OF IT
## ---------------------------------------------------------------------------------
##
## plan.md item 0: everything must be workable and testable outside VR, and this machine has neither a
## headset nor, under `--headless`, a rendering device. Both turn out to cost less than expected.
##
## A second `Window` node exists and carries its own camera under `--headless` -- measured, not assumed
## (the throwaway probe that established it is quoted in `cockpit/docs/craft.md`). So every
## question about WHICH CAMERA the desktop is standing on, where it is, and how wide it is can be asked
## with no screen at all. What cannot be asked is what the picture LOOKS like; that is
## `tests/director_shot.gd`, which is windowed, and the cost is `tests/director_cost.gd`.
##
## AND "THE FIELD OF VIEW CHANGES WHAT IS DRAWN" IS NOT A SCREENSHOT QUESTION. A camera's frustum is a
## thing it can be asked about -- `is_position_in_frustum`, `unproject_position` -- so a point that is
## outside the shot at 20 degrees and inside it at 100 is a measurement of what would be drawn, taken
## on a machine with nothing to draw on. That is a better check than a picture anyway: it names the
## point.
##
## EVERYTHING GOES THROUGH THE RIG'S OWN SEAMS -- `force_hand`, `force_grip`, `force_input` -- which is
## the path a headset takes. Nothing here calls `VehicleControl.offer_hand`, `DirectorCamera.turn` or
## `Monitor.watch` to make something happen, because those are the layers BELOW every decision this
## suite is about. `tests/pinch.gd` says the same and for the same reason.
##
## THE RIGHT HAND THROUGHOUT, and that is not arbitrary: the right is the hand that POINTS
## (`PilotRig._point_a_hand`), so the beam and the pinch can only collide there. The left is parked
## out of the world.
##
## ---------------------------------------------------------------------------------
## THE RED READINGS, each taken by putting one behaviour back the way it was
## ---------------------------------------------------------------------------------
##
## THIS GATE WAS WRITTEN AFTER THE CODE, not before it, and saying so plainly is worth more than the
## usual sentence about having written it first. So every check here was proved able to fail, by eleven
## mutations applied one at a time, each removing exactly one behaviour and each reverted afterwards.
## The whole table, with the line that matters from each:
##
##   the beam-versus-pinch rule removed
##     FAIL the_glass_is_not_pressed_by_the_finger_pinching_a_key (the page was clicked 1 time)
##   `carried_by_hand()` no longer read by the rig
##     FAIL a_camera_is_carried_by_a_closed_fist_in_flight (moved 0.000 m with the hand 0.200 m)
##   the tally light never emits
##     FAIL and_its_red_light_is_lit (emission 0.00)
##   the field of view never reaches the window
##     FAIL and_the_recording_is_as_wide_as_the_camera_says (camera 70.0, window 60.0)
##     FAIL a_point_out_to_the_side_comes_into_shot_as_it_widens (in at 20.0, in at 100.0)
##   the window's camera never stands on the lens
##     FAIL the_desktop_camera_stands_where_the_lens_is (1.320 m from the lens, 1.350 m from the eye)
##   the keys answer the fist instead of the fingertip
##     FAIL a_closed_fist_on_the_power_key_presses_nothing (is_on true, was false)
##   a part's carried controls are not spliced into the station
##     FAIL and_its_keypad_is_in_reach_of_the_station (10 controls at this station)
##   the window is kept up after it is switched off
##     FAIL and_the_second_window_goes_with_it (window DirectorWindow:<Window#176211102813>)
##   the monitor is told before the camera puts itself out
##     FAIL and_it_says_it_went_off_once_and_not_twice (said [false, false])
##   `Fullscreen._unhandled_input` put back the way racer has it
##     FAIL and_nothing_binds_the_fullscreen_key_in_the_main_window (Fullscreen defines a global input
##     handler)
##   `Monitor._on_window_input` never calling `Fullscreen.toggle`
##     FAIL f11_in_the_recording_window_asks_for_that_window (asked [], the recording window reports 0)
##
## TWO OF THEM PUT THE TRAP BACK BY ACCIDENT, which is the most useful thing the table says. With the
## keypad answering a fist, and again with the keypad not spliced in at all, `the_glass_is_not_pressed_
## by_the_finger_pinching_a_key` went red at "clicked 1 time" -- because the hand then has no PINCHED
## control in reach, the beam comes back, and the same pull presses the glass. The check is watching the
## collision itself and not the line of code that happens to prevent it today.
##
## Read RESULT=, not the exit code.

const TEST_KIND: Sim.Kind = Sim.Kind.PLANE
const TEST_SEAT: int = 0
## The pointing hand. See the note above.
const HAND: int = 1
const OTHER: int = 0

## Where the camera stands on the bench: well clear of the aeroplane's own controls, so nothing in this
## suite is decided by a lever that happens to be nearby.
const BENCH_AT := Vector3(1.40, 0.0, 0.0)
## How far the hand walks while carrying the camera, in metres.
const CARRY: float = 0.20
## Where the test panel stands down the line out of the keypad's face, and how far back up that line
## the hand stands for the control. `BEHIND` is comfortably past `VehicleControl.REACH`, which is what
## makes the control a hand with NOTHING under it rather than a hand slightly further from a key.
const GLASS_AT: float = 0.50
const BEHIND: float = 0.35

var _failures: PackedStringArray = []
## Sections that reached their own end. A GDScript error aborts the function it is in and carries on
## with the next, so counting only failures reports a cheerful pass over a section that fell over.
var _sections: int = 0
## How many times the test page's button was clicked. See `_a_panel_to_point_at`.
var _clicks: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[director] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	# THE COCKPITS AS AUTHORED. `user://cockpits` is the player's, and a layout saved while playing
	# moves the very controls this suite reaches for. `tests/fit.gd` and `tests/pinch.gd` do the same.
	CockpitStation.use_saved_layouts = false
	_the_bin_offers_a_camera_and_not_its_keypad()
	await _it_is_off_when_it_is_put_down_and_costs_nothing()
	await _the_power_key_turns_it_on_and_lights_the_red_light()
	await _the_desktop_is_looking_somewhere_the_headset_is_not()
	await _the_fov_keys_change_what_would_be_drawn()
	await _the_fist_carries_it_and_the_fingertip_works_it()
	await _a_hand_on_a_key_is_not_also_pointing_at_glass()
	await _the_fullscreen_key_asks_the_recording_window()
	_check("every_section_of_the_suite_ran", _sections == 8, "%d of 8" % _sections)
	_finish()


## ---- the parts bin ------------------------------------------------------------------------

## THE CAMERA IS A PART AND ITS KEYPAD IS NOT.
##
## Both halves matter. A camera nobody can place is a feature with no way in; a keypad the builder
## could stand on a console on its own would be three keys wired to nothing, because what a key means
## is the camera's business and there would be no camera behind it.
##
## RED, with `&"CameraKeypad"` added to `PARTS`:
##   FAIL the_bin_does_not_offer_a_keypad_on_its_own (CameraKeypad is in the bin)
func _the_bin_offers_a_camera_and_not_its_keypad() -> void:
	_check("the_bin_offers_a_director_camera", ControlCatalogue.has(&"DirectorCamera"),
		"%d parts" % ControlCatalogue.PARTS.size())
	_check("the_bin_does_not_offer_a_keypad_on_its_own",
		not ControlCatalogue.has(&"CameraKeypad"), "CameraKeypad is not in the bin")
	# WHICH FINGER TAKES WHICH, said here as well as in `tests/pinch.gd`, because this pair is the
	# reason the two-finger rule exists at all and a change to either answer breaks this feature
	# rather than that suite's list.
	var camera := ControlCatalogue.make(&"DirectorCamera") as DirectorCamera
	_check("a_camera_is_taken_by_the_fist", camera != null
		and camera.taken_by() == Bind.Take.GRIP, "taken_by %d" % (camera.taken_by() if camera != null else -1))
	_check("and_it_is_the_one_part_carried_while_flying", camera != null
		and camera.carried_by_hand(), "carried_by_hand")
	if camera != null:
		camera.free()
	var keypad := CameraKeypad.new()
	_check("and_its_keys_are_taken_by_the_fingertip", keypad.taken_by() == Bind.Take.PINCH,
		"taken_by %d" % keypad.taken_by())
	keypad.free()
	_sections += 1


## ---- off by default -----------------------------------------------------------------------

## A CAMERA PUT DOWN IS OFF, AND WHILE IT IS OFF THERE IS NO SECOND VIEWPORT.
##
## This is the cost check, expressed as a thing a headless run can see. `tests/director_cost.gd`
## measured what a second pass costs -- 0.60 to 0.70 ms a frame -- and the entire argument for shipping
## it is that it happens only while a red light is on. A window built once and hidden would keep
## paying, and would look identical from the cockpit.
##
## RED, with `Monitor.watch` called from `DirectorCamera._build`:
##   FAIL there_is_no_second_window_while_it_is_off (a window is up)
func _it_is_off_when_it_is_put_down_and_costs_nothing() -> void:
	var kit: Dictionary = await _a_bench()
	var camera: DirectorCamera = kit["camera"]
	_check("a_camera_is_off_when_it_is_put_down", not camera.is_on(), "is_on %s" % camera.is_on())
	_check("there_is_no_second_window_while_it_is_off", Monitor.window() == null,
		"window %s" % Monitor.window())
	_check("and_the_monitor_is_watching_nothing", Monitor.watching() == null,
		"watching %s" % Monitor.watching())
	_check("and_its_red_light_is_out", not _tally_is_lit(camera),
		"emission %.2f" % _tally_energy(camera))
	# AND ITS KEYPAD IS SOMETHING A HAND CAN REACH, which it only is because the station splices in
	# what a part CARRIES. Without that the keys are in the tree, drawn, and dead.
	var reachable: Array = (kit["station"] as CockpitStation).controls().values()
	_check("and_its_keypad_is_in_reach_of_the_station",
		reachable.has(camera.keypad()), "%d controls at this station" % reachable.size())
	# AND ITS KEYS WERE ACTUALLY DRAWN, which is not the same question as whether they work.
	#
	# The keypad is a GRANDCHILD of the station, so nothing but the camera will ever call its `setup`
	# -- and for an hour nothing did. It went unnoticed because `_key_under` is pure arithmetic: the
	# keys answered a fingertip exactly as they should, from a keypad with no meshes on it at all.
	# Every check in this suite stayed green. `tests/director_shot.gd` found it the moment somebody
	# looked, which is CLAUDE.md's second rule almost word for word.
	_check("and_its_keys_were_drawn", camera.keypad().keys_drawn() == 3,
		"%d keys" % camera.keypad().keys_drawn())
	_forget(kit)
	_sections += 1


## ---- the switch and the light -------------------------------------------------------------

## A FINGERTIP ON THE POWER KEY TURNS IT ON, AND THE RED LIGHT IS LIT ONLY WHILE IT IS ON.
##
## THE LIGHT IS READ OFF THE MESH and not off a flag: `_tally_energy` asks the material what it is
## actually emitting. A bool called `lit` that agreed with `on` would prove nothing about what anybody
## sees, and "a red light if it's on" is a thing you see.
##
## RED, with `DirectorCamera._redraw` not touching the tally's material:
##   FAIL and_its_red_light_is_lit (emission 0.00)
func _the_power_key_turns_it_on_and_lights_the_red_light() -> void:
	var kit: Dictionary = await _a_bench()
	var rig: PilotRig = kit["rig"]
	var camera: DirectorCamera = kit["camera"]

	await _pinch_the_key(rig, camera, CameraKeypad.POWER)
	_check("a_pinch_on_the_power_key_turns_it_on", camera.is_on(), "is_on %s" % camera.is_on())
	_check("and_its_red_light_is_lit", _tally_is_lit(camera),
		"emission %.2f" % _tally_energy(camera))
	_check("and_the_monitor_is_standing_on_its_lens", Monitor.watching() == camera.lens(),
		"watching %s" % Monitor.watching())
	_check("and_there_is_a_second_window_now", Monitor.window() != null, "window is up")

	# AND IT SAYS SO ONCE. `Monitor.look_away` announces that it is watching nothing, and this camera
	# hears its own announcement -- so with the order wrong it switches itself off twice and a page that
	# counted presses would count two.
	var said: Array[bool] = []
	var noted := func(_which: DirectorCamera, state: bool) -> void: said.append(state)
	camera.switched.connect(noted)
	await _pinch_the_key(rig, camera, CameraKeypad.POWER)
	camera.switched.disconnect(noted)
	_check("a_second_pinch_turns_it_off_again", not camera.is_on(), "is_on %s" % camera.is_on())
	_check("and_it_says_it_went_off_once_and_not_twice", said == [false], "said %s" % [said])
	_check("and_the_red_light_goes_out", not _tally_is_lit(camera),
		"emission %.2f" % _tally_energy(camera))
	_check("and_the_second_window_goes_with_it", Monitor.window() == null,
		"window %s" % Monitor.window())
	_forget(kit)
	_sections += 1


## ---- a different view ------------------------------------------------------------------------

## THE DESKTOP IS LOOKING SOMEWHERE THE PLAYER IS NOT, AND FOLLOWS THE CAMERA RATHER THAN THE HEAD.
##
## The whole feature in one section. Two poses and two answers to "what can you see": the monitor's
## camera stands on the lens, the rig's eye stands in the seat, and moving the camera moves one and not
## the other.
##
## MEASURED BY WHAT EACH ONE CAN SEE, not only by where each one is. A point put in front of the lens
## is in the monitor's frustum and not in the rig's, which is the difference between two cameras in
## different places and two cameras pointed different ways -- and the second is what a director's
## camera is for.
##
## RED, with `Monitor._stand_the_camera` leaving its camera at the origin:
##   FAIL the_desktop_camera_stands_where_the_lens_is (0.00 m from the lens, 41.30 m from the eye)
func _the_desktop_is_looking_somewhere_the_headset_is_not() -> void:
	var kit: Dictionary = await _a_bench()
	var rig: PilotRig = kit["rig"]
	var camera: DirectorCamera = kit["camera"]
	await _pinch_the_key(rig, camera, CameraKeypad.POWER)
	var eye: Camera3D = Monitor.eye()
	if eye == null:
		_check("there_is_a_camera_in_the_second_window", false, "no eye")
		_forget(kit)
		_sections += 1
		return
	await _frames(2)

	var from_lens: float = eye.global_position.distance_to(camera.lens().global_position)
	var from_head: float = eye.global_position.distance_to(rig.eye_position())
	_check("the_desktop_camera_stands_where_the_lens_is", from_lens < 0.001,
		"%.3f m from the lens, %.3f m from the eye" % [from_lens, from_head])
	_check("and_that_is_not_where_the_player_is_looking_from", from_head > 0.5,
		"%.3f m apart" % from_head)
	# A POINT A METRE IN FRONT OF THE LENS. In shot for the recording; behind the pilot, or at least
	# not in front of them, for the headset -- because the camera on the bench is pointed at the seat.
	var in_shot: Vector3 = camera.lens().global_position - camera.lens().global_basis.z
	_check("and_a_point_in_front_of_the_lens_is_in_the_recording",
		eye.is_position_in_frustum(in_shot), "%s" % in_shot)

	# AND IT FOLLOWS THE CAMERA. Carried by a closed fist, in flight, and the picture goes with it.
	var stood: Vector3 = eye.global_position
	await _carry_the_camera(rig, camera, Vector3(0.0, CARRY, 0.0))
	await _frames(2)
	var moved: float = eye.global_position.distance_to(stood)
	_check("and_the_recording_follows_the_camera_when_it_is_moved", moved > CARRY * 0.5,
		"the picture moved %.3f m for a hand that moved %.3f m" % [moved, CARRY])
	_forget(kit)
	_sections += 1


## ---- the field of view ------------------------------------------------------------------------

## THE FOV KEYS CHANGE WHAT WOULD BE DRAWN, AND STOP AT THE ENDS.
##
## NOT "the number changed". A field of view that moved a variable and not a frustum is a button that
## does nothing, and on a headless machine the number is the easy thing to check and the wrong one. So
## the measurement is a point out to the side of the lens: outside the shot at the narrow end, inside
## it at the wide end, and the same point both times.
##
## RED, with `DirectorCamera._frame_at` not calling `Monitor.frame_at`:
##   FAIL and_the_recording_is_as_wide_as_the_camera_says (camera 70.0, window 60.0)
##   FAIL a_point_out_to_the_side_comes_into_shot_as_it_widens (out at 20.0, out at 100.0)
func _the_fov_keys_change_what_would_be_drawn() -> void:
	var kit: Dictionary = await _a_bench()
	var rig: PilotRig = kit["rig"]
	var camera: DirectorCamera = kit["camera"]
	await _pinch_the_key(rig, camera, CameraKeypad.POWER)
	var eye: Camera3D = Monitor.eye()
	if eye == null:
		_check("there_is_a_camera_in_the_second_window", false, "no eye")
		_forget(kit)
		_sections += 1
		return

	var started: float = camera.fov
	await _pinch_the_key(rig, camera, CameraKeypad.WIDER)
	_check("a_pinch_on_the_wider_key_opens_the_lens",
		is_equal_approx(camera.fov, started + DirectorCamera.FOV_STEP),
		"%.1f degrees, was %.1f" % [camera.fov, started])
	_check("and_the_recording_is_as_wide_as_the_camera_says",
		is_equal_approx(eye.fov, camera.fov), "camera %.1f, window %.1f" % [camera.fov, eye.fov])

	# THE SAME POINT, SEEN AT BOTH ENDS OF THE TRAVEL. Out to the side of the lens by a third of a
	# metre, a metre ahead -- about 18 degrees off the axis, so a 20-degree lens (10 either side)
	# cannot hold it and a 100-degree one easily can.
	var lens: Node3D = camera.lens()
	var aside: Vector3 = lens.global_position - lens.global_basis.z + lens.global_basis.x * 0.33
	await _press_until(rig, camera, CameraKeypad.NARROWER, DirectorCamera.FOV_LEAST)
	var narrow_holds: bool = Monitor.eye().is_position_in_frustum(aside)
	var narrowest: float = camera.fov
	await _press_until(rig, camera, CameraKeypad.WIDER, DirectorCamera.FOV_MOST)
	var wide_holds: bool = Monitor.eye().is_position_in_frustum(aside)
	_check("a_point_out_to_the_side_comes_into_shot_as_it_widens",
		wide_holds and not narrow_holds,
		"%s at %.1f, %s at %.1f" % ["in" if narrow_holds else "out", narrowest,
			"in" if wide_holds else "out", camera.fov])
	# AND THE ENDS HOLD. A field of view walked past 100 degrees or under 20 is a lens that bends the
	# cockpit or a lens nobody can aim, and a button that can do it is a button that eventually will.
	_check("and_it_stops_at_the_wide_end", is_equal_approx(camera.fov, DirectorCamera.FOV_MOST),
		"%.1f degrees" % camera.fov)
	_check("and_it_stopped_at_the_narrow_end", is_equal_approx(narrowest, DirectorCamera.FOV_LEAST),
		"%.1f degrees" % narrowest)
	_forget(kit)
	_sections += 1


## ---- which finger does what --------------------------------------------------------------

## THE FIST CARRIES THE CAMERA AND THE FINGERTIP WORKS ITS KEYS, AND NEITHER DOES THE OTHER'S JOB.
##
## Item 14's rule on the one object it was always going to be asked about: a handle and three keys a
## hand's breadth apart, which is the arrangement `tests/fit.gd` forbids in an authored cockpit because
## a hand between two grips is ambiguous. It is not ambiguous here, and this is why.
##
## RED, with `PilotRig._work_the_controls` reading `placing()` alone:
##   FAIL a_camera_is_carried_by_a_closed_fist_in_flight (moved 0.000 m with the hand 0.200 m)
func _the_fist_carries_it_and_the_fingertip_works_it() -> void:
	var kit: Dictionary = await _a_bench()
	var rig: PilotRig = kit["rig"]
	var camera: DirectorCamera = kit["camera"]

	# A PULLED TRIGGER ON THE HANDLE DOES NOT PICK IT UP.
	var stood: Vector3 = camera.global_position
	rig.force_hand(HAND, camera.global_transform
		* Transform3D(Basis.IDENTITY, camera._grab_point()))
	rig.force_input(HAND, Bind.TRIGGER, 1.0)
	await _frames(6)
	_check("a_pulled_trigger_does_not_pick_the_camera_up", not camera.is_held(),
		"held_by %d with the trigger at 1.0" % camera.held_by)
	rig.force_input(HAND, Bind.TRIGGER, null)
	await _frames(2)

	# AND A CLOSED FIST DOES, IN FLIGHT, with the builder off.
	_check("the_builder_is_off_for_this", not rig.placing(), "placing %s" % rig.placing())
	await _carry_the_camera(rig, camera, Vector3(CARRY, 0.0, 0.0))
	var went: float = camera.global_position.distance_to(stood)
	_check("a_camera_is_carried_by_a_closed_fist_in_flight", went > CARRY * 0.5,
		"moved %.3f m with the hand %.3f m" % [went, CARRY])
	# AND ITS KEYPAD CAME WITH IT, which is what makes it one object rather than two.
	var keys_at: Vector3 = camera.keypad().global_position
	_check("and_its_keypad_travelled_with_it",
		keys_at.distance_to(camera.global_position) < 0.2
			and keys_at.distance_to(stood) > CARRY * 0.4,
		"the keys are %.3f m from where the camera stood" % keys_at.distance_to(stood))
	await _open_the_fist(rig, camera)

	# AND A FIST ON THE KEYS PRESSES NOTHING. The other half of the rule, and the one that would be
	# silently right if nothing else were ever near the keypad.
	var was_on: bool = camera.is_on()
	rig.force_hand(HAND, camera.keypad().global_transform
		* Transform3D(Basis.IDENTITY, camera.keypad().key_place(CameraKeypad.POWER)))
	rig.force_grip(HAND, 1.0)
	await _frames(6)
	_check("a_closed_fist_on_the_power_key_presses_nothing", camera.is_on() == was_on,
		"is_on %s, was %s" % [camera.is_on(), was_on])
	rig.force_grip(HAND, -1.0)
	await _frames(2)
	_forget(kit)
	_sections += 1


## ---- the beam and the pinch ----------------------------------------------------------------

## A HAND ON A PINCHED KEY IS NOT ALSO POINTING AT GLASS.
##
## THE RULE THIS LANE WAS SENT TO WRITE. `PilotRig._point_a_hand` presses glass with
## `_read_input(hand, Bind.TRIGGER)`; `_nearest_takeable` takes pinched controls from the same raw
## reading; before 2026-09-16 neither knew about the other, and nothing went wrong only because you
## point at a screen from across the cockpit and pinch a switch with your hand on it. A floating camera
## with keys on its back, held in front of a monitor, is where they meet.
##
## BOTH HALVES, because "the beam never works" would pass the first half on its own. So the same pull,
## with the same panel up, is made once with the hand ON a key and once with the hand well clear of
## everything -- and the second one must press the glass.
##
## THE GLASS IS ASKED, NOT THE BEAM. A count of clicks that actually reached a `Button` on the page,
## through `TouchPanel.press`'s synthetic mouse event, which is the path a real press takes. Checking
## that `HandBeam` was put away would be checking the mechanism this rule happens to use.
##
## RED, with `_reaching_for_a_pinch` removed from `_point_a_hand`:
##   FAIL the_glass_is_not_pressed_by_the_finger_pinching_a_key (the page was clicked 1 time)
func _a_hand_on_a_key_is_not_also_pointing_at_glass() -> void:
	var kit: Dictionary = await _a_bench()
	var rig: PilotRig = kit["rig"]
	var camera: DirectorCamera = kit["camera"]
	# THE LINE THE WHOLE SECTION IS ARRANGED ALONG: straight out of the keypad's face, which is the way
	# a hand pressing a key points. The glass stands half a metre down it.
	var keypad: CameraKeypad = camera.keypad()
	var along: Vector3 = keypad.global_basis.z.normalized()
	var panel: TouchPanel = _a_panel_to_point_at(kit["plinth"], keypad.global_position, along)
	rig.pointer_panels = [panel]
	await _frames(4)

	# THE HAND ON THE POWER KEY, POINTING STRAIGHT AT THE GLASS, and one pull.
	_clicks = 0
	var was_on: bool = camera.is_on()
	await _pinch_the_key(rig, camera, CameraKeypad.POWER, along)
	_check("the_key_under_the_finger_is_pressed", camera.is_on() != was_on,
		"is_on %s, was %s" % [camera.is_on(), was_on])
	_check("the_glass_is_not_pressed_by_the_finger_pinching_a_key", _clicks == 0,
		"the page was clicked %d time%s" % [_clicks, "" if _clicks == 1 else "s"])

	# AND THE SAME PULL, DOWN THE SAME LINE, FROM A HAND WITH NOTHING UNDER IT DOES PRESS THE GLASS.
	#
	# Without this the check above would pass on a beam that never worked at all -- which is exactly
	# what the first version of this suite did. The bench had no panel the beam could reach, so nothing
	# was ever pressed, and "the glass is not pressed" was true for a reason that had nothing to do
	# with the rule. The hand now stands well back along the same line, so the ray it fires passes the
	# keypad and goes on to the glass, and the only thing that has changed between the two pulls is
	# whether there is a key under the finger.
	_clicks = 0
	var back: Vector3 = keypad.global_position - along * BEHIND
	_check("and_the_hand_is_now_out_of_reach_of_every_key",
		back.distance_to(keypad.grip_global()) > VehicleControl.REACH,
		"%.3f m from the keys" % back.distance_to(keypad.grip_global()))
	rig.force_hand(HAND, _aimed_along(back, along))
	await _frames(4)
	await _pull(rig)
	_check("but_a_hand_with_nothing_under_it_still_presses_the_glass", _clicks > 0,
		"the page was clicked %d time%s" % [_clicks, "" if _clicks == 1 else "s"])
	rig.pointer_panels = []
	_forget(kit)
	_sections += 1


## ---- the fullscreen key ---------------------------------------------------------------------

## F11 BELONGS TO THE RECORDING WINDOW, AND THE DESK KEEPS ITS OWN KEYS.
##
## "I should be able to fullscreen IT" -- the recording, not the game. There is no global fullscreen
## key in this game and there must not be one: `PilotRig.desk_keys` binds `KEY_F1 + kind` for every
## craft a player may be put in, so **F11 already flies a Cessna**, and F is `next seat`, which a
## Shift+F would satisfy as well unless somebody asked for an exact match. Rebinding either to make
## room for a window key would change what every pilot's keyboard does.
##
## SO THE TWO HALVES ARE: the key works in the recording window, and it is still not the desk's. The
## second is the one that would rot quietly -- a later "let us bind it globally too" costs a craft.
##
## WHAT HEADLESS CANNOT SAY: which window is which. `DisplayServer` makes no real windows, so every
## `Window` node reports id 0, and an event parsed globally arrives at the recording window's own
## `window_input` as well -- the two windows are one. So "the same press on the desk does something
## else" is not a question this machine can answer, and the first attempt at it failed for that reason
## rather than for a real one.
##
## WHAT IT CAN SAY is the invariant that would actually rot: **the autoload defines no global key
## handler at all.** A later "let us bind it globally too" is one method, and that method is what costs
## a player an aeroplane. Read off the script's own method list, so it cannot be satisfied by a comment.
## And that something really does fly on F11, because the day nothing does is the day this rule could
## be relaxed and nobody would know.
##
## THROUGH `window_input`, which is the signal Godot delivers a key to a `Window` with and the exact
## seam `Monitor` listens on.
##
## RED, with `Fullscreen._unhandled_input` put back the way racer has it:
##   FAIL and_nothing_binds_the_fullscreen_key_in_the_main_window (Fullscreen defines a global input
##   handler)
func _the_fullscreen_key_asks_the_recording_window() -> void:
	var kit: Dictionary = await _a_bench()
	var rig: PilotRig = kit["rig"]
	var camera: DirectorCamera = kit["camera"]
	await _pinch_the_key(rig, camera, CameraKeypad.POWER)
	var window: Window = Monitor.window()
	if window == null:
		_check("there_is_a_recording_window_to_fullscreen", false, "the camera did not switch on")
		_forget(kit)
		_sections += 1
		return
	var asked: Array[int] = []
	var noted := func(_message: String, which: int) -> void: asked.append(which)
	Fullscreen.toggle_unavailable.connect(noted)
	window.window_input.emit(_a_key(KEY_F11))
	await _frames(2)
	_check("f11_in_the_recording_window_asks_for_that_window",
		asked == [window.get_window_id()],
		"asked %s, the recording window reports %d" % [asked, window.get_window_id()])

	Fullscreen.toggle_unavailable.disconnect(noted)

	# AND NOTHING LISTENS FOR IT IN THE MAIN WINDOW. See the note above for why this is asked of the
	# script rather than by pressing a key.
	var global_handler: bool = false
	for method in (Fullscreen.get_script() as GDScript).get_script_method_list():
		if String(method["name"]) in ["_unhandled_input", "_input", "_shortcut_input",
				"_unhandled_key_input"]:
			global_handler = true
	_check("and_nothing_binds_the_fullscreen_key_in_the_main_window", not global_handler,
		"Fullscreen defines a global input handler")
	var flies: PackedStringArray = []
	for kind in VehicleCatalogue.pilotable_kinds():
		for event in InputMap.action_get_events("kind_%d" % kind):
			if (event as InputEventKey) != null and (event as InputEventKey).physical_keycode == KEY_F11:
				flies.append(Sim.kind_name(kind))
	# AND THE COLLISION IS REAL, not a worry somebody wrote down. A day when no craft is on F11 is a day
	# this rule could be relaxed, and this line is how anybody would find that out.
	_check("and_something_really_does_fly_on_f11", not flies.is_empty(),
		"F11 is %s" % ", ".join(flies) if not flies.is_empty() else "F11 is free now")
	# AND THE KEY IS ONE A ROBOT CAN PRESS EITHER WAY. CLAUDE.md rule 9: both `keycode` and
	# `physical_keycode`, or half the ways of pressing it match nothing.
	var both: bool = true
	for event in InputMap.action_get_events(Fullscreen.ACTION):
		var key := event as InputEventKey
		both = both and key != null and key.keycode != 0 and key.physical_keycode != 0
	_check("and_both_of_its_events_carry_a_keycode_and_a_physical_one", both,
		"%d event(s)" % InputMap.action_get_events(Fullscreen.ACTION).size())
	_forget(kit)
	_sections += 1


## A key going down, with both codes set. See the check above.
func _a_key(which: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = which
	event.physical_keycode = which
	event.pressed = true
	return event


## ---- the bench ------------------------------------------------------------------------------

## A RIG AT A PLANE'S PILOT STATION with a director's camera standing out on its own.
##
## The station is the game's own -- a seat on a plinth and `take_station`, exactly what the hall of
## cockpits does -- and the camera arrives as a child of it, which is how a part the builder placed
## arrives. `tests/pinch.gd._a_bench` is where the shape comes from.
##
## WELL CLEAR OF THE COCKPIT, because this suite is about the camera and not about which of the
## aeroplane's own levers happens to be nearest.
func _a_bench() -> Dictionary:
	# NOTHING LEFT OVER FROM THE LAST SECTION. Each section builds its own bench, and a camera still
	# recording when its bench was freed would leave the monitor watching a freed node.
	Monitor.look_away()
	var plinth := Node3D.new()
	add_child(plinth)
	var station := VehicleCatalogue.seat_scene(TEST_KIND).instantiate() as CockpitStation
	plinth.add_child(station)
	station.fit(TEST_SEAT, true, TEST_KIND, false)

	var camera := DirectorCamera.new()
	camera.name = "BenchCamera"
	station.add_child(camera)
	camera.setup(TEST_SEAT)
	camera.position = BENCH_AT
	# LOOKING BACK ALONG THE AEROPLANE, which is roughly at the seat -- the shot somebody puts a
	# camera in their own cockpit to get.
	camera.rotation = Vector3(0.0, PI * 0.5, 0.0)

	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	rig.take_station(station)
	# THE OTHER HAND OUT OF THE WAY, open and a long way off. Both hands are offered every frame, and
	# a hand parked at the origin picks up whatever is nearest to it.
	rig.force_grip(OTHER, 0.0)
	rig.force_hand(OTHER, Transform3D(Basis.IDENTITY, Vector3(0.0, -40.0, 0.0)))
	rig.force_grip(HAND, -1.0)
	await _frames(2)
	return {"rig": rig, "station": station, "plinth": plinth, "camera": camera}


## A PANEL THE BEAM CAN REACH, standing `GLASS_AT` down the line `along` from `from` and facing back up
## it -- so a hand anywhere on that line points straight at the glass. The collision arranged rather
## than hoped for.
##
## ITS PAGE IS A SINGLE BUTTON packed at runtime, and the button's own `pressed` signal is what counts
## a click -- so "the glass was pressed" is measured where a real press ends up, through
## `TouchPanel.press`'s synthetic mouse event, rather than at some earlier point in the chain.
func _a_panel_to_point_at(plinth: Node, from: Vector3, along: Vector3) -> TouchPanel:
	var page := Control.new()
	page.name = "Page"
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	var button := Button.new()
	button.name = "Whole"
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(button)
	button.owner = page
	var packed := PackedScene.new()
	packed.pack(page)
	# THE TEMPLATE IS NEVER IN A TREE, so nothing will ever free it. A `Control` and a `Button` left
	# behind are two ObjectDB instances and a font, and the runner counts an "ERROR: ... leaked at
	# exit" line as a failure whatever RESULT says.
	page.free()

	var panel := TouchPanel.new()
	panel.name = "BenchGlass"
	panel.size = Vector2(0.40, 0.30)
	panel.page = packed
	plinth.add_child(panel)
	# CONNECTED TO THE BUTTON ON THE PANEL, NOT TO THE ONE THAT WAS PACKED.
	#
	# A `PackedScene` does not carry signal connections made in code, and the panel instantiates a COPY
	# of the page. The first version connected to the template's button, which is never in any tree and
	# is never pressed -- so the click counter stayed at zero whatever happened on the glass, and the
	# control check below could not pass however the geometry was arranged. An hour went into the
	# geometry before the counter was suspected.
	var live: Button = panel.shown().get_node_or_null("Whole") as Button
	if live != null:
		live.pressed.connect(_on_click)
	# DOWN THE LINE AND FACING BACK UP IT. A panel's front is its own +Z -- `TouchPanel.reach` takes the
	# normal off `global_basis.z` -- and `Basis.looking_at` puts -Z along what it is handed, so looking
	# it ALONG the line leaves its +Z pointing back at the hand, which is what makes the ray meet it.
	panel.global_transform = Transform3D(Basis.looking_at(along, Vector3.UP), from + along * GLASS_AT)
	return panel


func _on_click() -> void:
	_clicks += 1


## ---- driving the hands ------------------------------------------------------------------------

## PUT THE FINGERTIP ON A KEY AND PULL THE TRIGGER, then let go. The path a headset takes.
##
## `pointing` turns the hand so its -Z lies along a direction, for the section that needs the beam aimed
## at a panel while the fingertip is on a key. Everything else leaves the hand square.
func _pinch_the_key(rig: PilotRig, camera: DirectorCamera, which: int,
		pointing: Variant = null) -> void:
	var keypad: CameraKeypad = camera.keypad()
	var at: Transform3D = keypad.global_transform \
		* Transform3D(Basis.IDENTITY, keypad.key_place(which))
	if pointing is Vector3:
		at = _aimed_along(at.origin, pointing)
	rig.force_hand(HAND, at)
	await _pull(rig)


## ONE PULL, DOWN AND UP AGAIN.
##
## OPEN FIRST, because a key remembers which key this squeeze has already pressed -- a trigger left
## pulled from the last press would press nothing, and the check would fail for the wrong reason. AND
## OPEN AFTER, because the beam presses on the EDGE of a pull (`GlassPointer`), so a trigger left down
## would make the next pull no pull at all. `tests/desk_screens.gd._pull` is the same shape.
func _pull(rig: PilotRig) -> void:
	rig.force_input(HAND, Bind.TRIGGER, 0.0)
	await _frames(3)
	rig.force_input(HAND, Bind.TRIGGER, 1.0)
	await _frames(4)
	rig.force_input(HAND, Bind.TRIGGER, 0.0)
	await _frames(2)
	rig.force_input(HAND, Bind.TRIGGER, null)
	await _frames(2)


## PRESS ONE KEY UNTIL THE FIELD OF VIEW STOPS MOVING, up to the whole travel and a little over.
func _press_until(rig: PilotRig, camera: DirectorCamera, which: int, wanted: float) -> void:
	var tries: int = int((DirectorCamera.FOV_MOST - DirectorCamera.FOV_LEAST)
		/ DirectorCamera.FOV_STEP) + 2
	for i in range(tries):
		if is_equal_approx(camera.fov, wanted):
			return
		await _pinch_the_key(rig, camera, which)


## CLOSE THE FIST ON THE HANDLE AND WALK THE HAND, a frame at a time, so the carry is read as travel
## rather than as a teleport. The hand stays shut at the end -- `_open_the_fist` is how it lets go.
func _carry_the_camera(rig: PilotRig, camera: DirectorCamera, by: Vector3) -> void:
	var handle: Vector3 = camera.grip_global()
	rig.force_hand(HAND, Transform3D(Basis.IDENTITY, handle))
	rig.force_grip(HAND, 1.0)
	await _frames(4)
	const STEPS: int = 8
	for i in range(STEPS):
		rig.force_hand(HAND, Transform3D(Basis.IDENTITY,
			handle + by * (float(i + 1) / float(STEPS))))
		await _frames(1)
	await _frames(2)


## OPEN THE FIST, AS A SQUEEZE ENDING AND NOT AS A TAP. A grip opened within `PilotRig.TAP_SECONDS` of
## closing is a LATCH, timed on the wall clock, which a run at `--fixed-fps` gets through far faster
## than frames. `tests/pinch.gd._open_the_hand`, which learnt it.
func _open_the_fist(rig: PilotRig, control: VehicleControl) -> void:
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
	await _frames(2)


## A hand standing at `at` with its -Z along `along`, which is the way a controller points.
##
## `Basis.looking_at(direction)` and not `Transform3D.looking_at(point)`: the first version of the beam
## section aimed at a POINT six metres below the hand, which against an up vector of `Vector3.UP` is
## very nearly degenerate, and a basis built out of two parallel vectors is not a direction anybody can
## point along.
func _aimed_along(at: Vector3, along: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(along, Vector3.UP), at)


## ---- reading the light --------------------------------------------------------------------

## WHAT THE TALLY LIGHT IS ACTUALLY EMITTING, off the material. See the section that uses it.
func _tally_energy(camera: DirectorCamera) -> float:
	for child in camera.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or not (mesh.mesh is SphereMesh):
			continue
		var material := mesh.material_override as StandardMaterial3D
		if material == null:
			continue
		return material.emission_energy_multiplier if material.emission_enabled else 0.0
	return -1.0


func _tally_is_lit(camera: DirectorCamera) -> bool:
	return _tally_energy(camera) > 0.5


func _frames(how_many: int) -> void:
	for i in range(how_many):
		await get_tree().process_frame


func _forget(kit: Dictionary) -> void:
	Monitor.look_away()
	(kit["rig"] as Node).queue_free()
	(kit["plinth"] as Node).queue_free()


## AND NOTHING IS LEFT STANDING AT EXIT.
##
## `queue_free` runs at the END of the frame it is called in, and a suite that printed its verdict and
## quit in the same breath never reached that point: the first full run of this one logged "15 RID
## allocations of type DummyTexture were leaked at exit" and `run_all.ps1` marked it ERRORS over a
## green RESULT. A `TouchPanel` is a `SubViewport` and the monitor's window is another, so this suite
## makes more render targets than most. Three frames after the last `queue_free`, and the window put
## away by name, costs nothing and leaves the runner nothing to report.
func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	Monitor.look_away()
	await _frames(3)
	get_tree().quit(0 if _failures.is_empty() else 1)
