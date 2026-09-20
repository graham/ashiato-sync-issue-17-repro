extends Node
## Headless: WHAT ONE CREW MEMBER DOES, EVERY OTHER SEAT SEES -- on every craft with more than one
## seat, and WHILE IT IS BEING MOVED rather than only once it has been let go.
##
##   Godot --headless --path cockpit res://tests/crew_sync.tscn
##
## ASKED FOR ON 2026-09-15: "do a general audit of craft and their synced values, you should make
## sure that they work as if they are linked. Rudders should move together, buttons, switches. The
## arm switch in the fighter only syncs when released, not while being moved." And, about boats:
## "both steering wheels should be able to control the boat (and that works) but i don't see the
## other players inputs in my wheel if i'm not holding it."
##
## A SUITE AND NOT A READ-THROUGH, because a read-through rots the day it is written. This walks
## every craft the catalogue will give a player, sits a second crew member down in it, has that
## crew member fly, and asks what the controls at BOTH seats are showing.
##
## ONE PROCESS, EVERY SEAT. `VehicleView.man` builds a station at every seat of a manned craft, so
## the other crew member's yoke exists in this tree and is drawn by the same loop that draws it on
## their own machine (`FlightLevel._draw_cockpit`). Whether the linkage reaches that machine at all
## is ashiato's to test -- `addon/tests/cockpit_loopback.gd` does it -- and what this suite is for
## is the half above the wire: which controls the cockpit chooses to draw from it.
##
## THE THREE QUESTIONS, and the second is the one that was wrong:
##
##   1. THEIR control shows what they are doing. A copilot's yoke moving is half the reason the
##      linkage is on the wire at all.
##   2. MY OWN control shows it too, when my hands are not on it. Two wheels on one boat are ONE
##      helm; a wheel that sits still while the other one is hard over is a wheel that is lying
##      about which way the boat is turning. This is the one the report named.
##   3. A control the CRAFT owns -- a switch, a lever, a dial -- follows at the other seat WHILE a
##      hand is still on it, with no release anywhere in the check. That is the case a naive audit
##      misses, because letting go is when everything looks fine.
##
## THE RUDDER GETS ITS OWN QUESTION, because it has nowhere else to show itself: it is a twist on a
## column and a pair of pedals in a footwell, and the indicator beside each seat is the only thing
## in the cockpit that reads it.
##
## HOW THE SECOND CREW MEMBER FLIES. Their control frame is written straight into their pilot
## entity on the server (`set_pilot_input`), which is where a real second machine's frame arrives
## after the wire. Their hands are not simulated and do not need to be: what is under test is what
## the linkage does with a frame, not how a frame is made -- `tests/shared_controls.gd` drives real
## hands through the rig, and this one drives the crew.
##
## Read RESULT=, not the exit code.

const RIGHT: int = 1
## How long the craft is given to answer, in physics frames: half a second at 120 Hz. A solo world
## publishes the cabin a tick after the seats and sends it on the next, so this is two orders of
## margin and not a guess at the rate.
const PATIENCE: int = 60
## How hard the other crew member flies, per axis. Well past `kHandsOn` (0.02 in the simulation), so
## the linkage counts them as a hand actually on that axis, and off the stops.
const PUSHED: float = 0.70
## How much of that has to show at a control before it counts as having moved together. Half, which
## is far more than the wire's own quantisation of 1/128 of an axis and far less than the thing
## being asked about -- a wheel that does not move at all reads 0.
const TOGETHER: float = 0.35
## How far a hand moves a craft's own control, in metres, and in how many steps. Enough travel to
## cross a switch's snap and most of a lever's gate.
const WIND: float = 0.10
const STEPS: int = 6

var _failures: PackedStringArray = []
var _level: FlightLevel = null
## Every kind that was actually visited, so a run that could not get into anything says so rather
## than passing over nothing.
var _visited: int = 0
## Client ids the server has not handed out, for the crew this suite seats itself.
var _next_spare: int = 0
## pilot entity -> the control frame written into it each physics frame.
var _crew_inputs: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[crew_sync] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	for i in range(240):
		await get_tree().physics_frame
	var rig: PilotRig = _level.rig

	for kind in VehicleCatalogue.pilotable_kinds():
		var flying: Array[int] = _flying_seats(kind)
		if flying.size() < 2:
			continue
		await _one_crafts_crew(rig, int(kind), flying)
	_check("some_craft_carry_more_than_one_pilot", _visited >= 2,
		"%d craft with two flying seats were walked" % _visited)
	await _a_craft_control_syncs_while_it_is_being_moved(rig)
	await _a_button_pressed_at_one_seat_lights_the_one_at_the_other(rig)
	_finish()


## THE PEDALS IN A SEAT'S SET, whatever they were called. They are fitted rather than authored and
## the builder may have moved them, so they are found by TYPE and not under a role.
func _pedals_of(set: Dictionary) -> RudderPedals:
	for control in set.values():
		var feet := control as RudderPedals
		if feet != null:
			return feet
	return null


## WHICH SEATS OF THIS KIND FLY IT, from the simulation's own seat table. A turret station is not
## one: a gunner has no authority over the craft and nothing of theirs is on the linkage.
func _flying_seats(kind: int) -> Array[int]:
	var out: Array[int] = []
	# THE MANIFEST, NOT FOUR: the simulation can carry seats 0..7 and authored packages already
	# have operator stations after the first pair. A future third flight station must enter this
	# gate without somebody remembering that this test once stopped at four.
	var poses: Array = Sim.geometry_of(kind).get("seat_poses", []) as Array
	for seat in range(poses.size()):
		var pose: Dictionary = Sim.server.seat_pose(kind, seat)
		if bool(pose.get("valid", false)) and bool(pose.get("flies", false)):
			out.append(seat)
	return out


## ---- 1, 2 and the rudder: one craft, two pilots ---------------------------------------------

func _one_crafts_crew(rig: PilotRig, kind: int, flying: Array[int]) -> void:
	var called: String = Sim.kind_name(kind).to_lower().replace(" ", "_")
	var view: VehicleView = await _take(rig, kind)
	if view == null:
		_check("this_machine_gets_into_a_%s" % called, false, "no view of kind %d" % kind)
		return
	var mine: int = rig.seat_index()
	var sources: int = 0
	for theirs in flying:
		if theirs == mine:
			continue
		if await _one_flying_seat_drives_all(view, called, int(theirs), flying):
			sources += 1
	if sources > 0:
		_visited += 1


## EACH OTHER FLIGHT STATION IS THE SOURCE ONCE, and every flight station is observed. This is deliberately an N-by-N
## gate rather than "pilot and copilot": seat roles change in authored packages, and linkage is a craft property.
func _one_flying_seat_drives_all(view: VehicleView, called: String, theirs: int, flying: Array[int]) -> bool:
	var mate: int = await _seat_a_mate(view, theirs)
	if mate == 0:
		_check("flight_seat_%d_boards_the_%s" % [theirs, called], false, "craft %s" % view.entity)
		return false

	# THEM FLYING, and nothing at all from this machine: hands in the lap, which is the case the
	# linkage is for. Only the hands actually ON an axis count toward it -- see `Linkage::add` --
	# so an idle seat does not halve what the other one is asking for.
	_crew_inputs[mate] = _controls({"roll": PUSHED, "pitch": -PUSHED, "throttle": PUSHED,
		"rudder": PUSHED})
	for i in range(PATIENCE):
		await get_tree().physics_frame

	for observer in flying:
		var controls: Dictionary = view.controls_for(int(observer))
		var stick := controls.get("stick") as VehicleControl
		var lever := controls.get("throttle") as VehicleControl
		var needle := controls.get("rudder") as RudderIndicator
		if stick != null:
			_check("%s_source_%d_moves_flight_seat_%d_stick" % [called, theirs, observer],
				absf(stick.roll()) >= TOGETHER, "asked %.2f, shown %.2f" % [PUSHED, stick.roll()])
		if lever != null and lever.channel < 0:
			_check("%s_source_%d_moves_flight_seat_%d_throttle" % [called, theirs, observer],
				lever.throttle() >= TOGETHER, "asked %.2f, shown %.2f" % [PUSHED, lever.throttle()])
		if needle != null:
			_check("%s_source_%d_moves_flight_seat_%d_rudder" % [called, theirs, observer],
				absf(needle.shown()) >= TOGETHER, "asked %.2f, shown %.2f" % [PUSHED, needle.shown()])
		var pedals := _pedals_of(controls)
		if pedals != null:
			_check("%s_source_%d_moves_flight_seat_%d_pedals" % [called, theirs, observer],
				absf(pedals.shown) >= TOGETHER, "asked %.2f, shown %.2f" % [PUSHED, pedals.shown])

	# AND IT STOPS WHEN THEY DO. A control that follows a moving one and then stays where it was
	# put is a control drawn from a value that is never cleared, which passes the check above and
	# is still wrong.
	_crew_inputs[mate] = _controls()
	for i in range(PATIENCE):
		await get_tree().physics_frame
	for observer in flying:
		var stick := view.controls_for(int(observer)).get("stick") as VehicleControl
		if stick != null:
			_check("%s_source_%d_releases_flight_seat_%d_stick" % [called, theirs, observer],
				absf(stick.roll()) < TOGETHER, "shown %.2f" % stick.roll())
	# AND THE MATE GETS OUT. Seventeen craft are walked and a crew member left aboard each is
	# seventeen extra pilots flying about for the rest of the run -- and, worse, a craft this suite
	# comes back to later with somebody already in the seat it wanted.
	_crew_inputs.erase(mate)
	Sim.server.despawn_pilot(mate)
	for i in range(4):
		await get_tree().physics_frame
	return true


## ---- 3. a craft's own control, read at the other seat MID-MOVEMENT --------------------------

## THE CASE THE REPORT NAMED: "the arm switch in the fighter only syncs when released, not while
## being moved." So nothing here is ever released. A hand takes hold of a control the CRAFT owns at
## this seat, moves it a step at a time, and after each step the SAME control at the other seat is
## read -- with the hand still closed on the first one.
##
## THE OTHER SEAT'S COPY AND NOT THE BUS. Reading the bus back would prove the command went out,
## which is the half that was never in doubt; what the report is about is the picture in front of
## the other pilot, and that is a different object drawn by a different branch.
func _a_craft_control_syncs_while_it_is_being_moved(rig: PilotRig) -> void:
	var view: VehicleView = await _take(rig, Sim.Kind.PLANE)
	if view == null:
		_check("this_machine_gets_into_a_fighter", false, "no view")
		return
	var mine: int = rig.seat_index()
	var theirs: int = -1
	for seat in _flying_seats(Sim.Kind.PLANE):
		if seat != mine:
			theirs = seat
			break
	if theirs < 0:
		_check("a_fighter_has_a_second_seat", false, "flying seats %s"
			% [_flying_seats(Sim.Kind.PLANE)])
		return
	var mate: int = await _seat_a_mate(view, theirs)
	if mate == 0:
		_check("a_second_pilot_boards_the_fighter", false, "seat %d" % theirs)
		return

	var mine_set: Dictionary = view.controls_for(mine)
	var theirs_set: Dictionary = view.controls_for(theirs)
	for role in mine_set:
		var here := mine_set[role] as VehicleControl
		var there := theirs_set.get(role) as VehicleControl
		# THE CRAFT'S OWN, ON A CHANNEL, AND TWO OF THEM. A console control is the SAME node at both
		# seats, so it cannot disagree with itself and has nothing to say here.
		if here == null or there == null or here == there:
			continue
		if here.scope != VehicleControl.Scope.CRAFT or here.channel < 0:
			continue
		# AND ON ONE CHANNEL. A signal lamp is at every seat under one name, but each is on its OWN seat's channel
		# (`SignalLamp.channel_for`) -- the seat's signal, not a setting the two share -- so there is nothing for the
		# other seat's copy to follow, and a lamp is lit by a finger, not dragged.
		if there.channel != here.channel:
			continue
		await _move_it_and_watch_the_other_one(rig, view, here, there, String(role))
	_let_the_hand_go(rig)
	# AND THIS ONE GETS OUT TOO, or the next section cannot seat anybody in the chair they are
	# still sitting in -- which reads as "a second pilot boards the fighter: FAIL", a mile from
	# what is actually wrong.
	Sim.server.despawn_pilot(mate)
	for i in range(PATIENCE):
		await get_tree().physics_frame


func _move_it_and_watch_the_other_one(rig: PilotRig, view: VehicleView, here: VehicleControl,
		there: VehicleControl, role: String) -> void:
	var channel: int = here.channel
	var called: String = "%s_%s" % [role, Sim.channel_name(channel).to_lower().replace(" ", "_")]
	var from: int = here.command_value()
	_close(rig, here, 1.0)
	var closed_at: int = Time.get_ticks_msec()
	for i in range(8):
		await _hand_at(rig, here, here._grab_point())
	if here.held_by != RIGHT:
		_check("a_hand_takes_hold_of_the_%s_in_a_fighter" % called, false,
			"held by %d, taken by %s" % [here.held_by, _finger(here)])
		_let_the_hand_go(rig)
		return

	# WOUND IN STEPS, AND THE HAND NEVER OPENS. Each step is a place in the CONTROL'S OWN frame,
	# offset along its -Z from where the hand took hold: forward is on for a switch and open for a
	# lever, which is what everything in this cockpit is laid out to mean.
	var took_hold_at: Vector3 = here._grab_point()
	var seen_moving: bool = false
	var reached: int = from
	for step in range(1, STEPS + 1):
		var to: Vector3 = took_hold_at + Vector3(0.0, 0.0, -WIND * float(step) / float(STEPS))
		for i in range(20):
			await _hand_at(rig, here, to)
			reached = here.command_value()
			# THE CRAFT AND THEN THE OTHER SEAT, and the craft is not optional. `shown_value` returns
			# THIS machine own unanswered proposal for a grace period, so a check that only asked the
			# other seat what it was showing could be told the answer by the hand that asked the
			# question -- which is the most comfortable kind of green there is.
			if reached != from and view.channel_value(channel) == reached 					and there.command_value() == reached:
				seen_moving = true
				break
		if seen_moving:
			break
	_check("the_%s_in_a_fighter_follows_at_the_other_seat_while_it_is_still_held" % called,
		seen_moving, "moved from %d to %d with the hand still on it; the other seat shows %d"
			% [from, reached, there.command_value()])
	_check("and_it_was_still_held_when_that_was_asked_%s" % called, here.held_by == RIGHT,
		"held by %d" % here.held_by)
	# AND THE HAND ONLY OPENS NOW, after the question has been asked -- AS A SQUEEZE ENDING AND NOT
	# AS A TAP, on anything a whole FIST takes. A grip closed and opened inside `PilotRig.TAP_SECONDS`
	# of WALL CLOCK pins the hand to what it is holding, and a suite at `--fixed-fps 120` runs a
	# hundred frames in a fraction of a second: an early version of this tapped its way onto the trim
	# wheel and then could not reach the arm switch at all, because the fist was still shut round the
	# wheel. A PINCHED control has no latch -- it lets go the instant the trigger lifts, however brief
	# the pull -- so the wait is asked of the control rather than paid on everything.
	if here.taken_by() == Bind.Take.GRIP:
		while Time.get_ticks_msec() - closed_at < int((PilotRig.TAP_SECONDS + 0.15) * 1000.0):
			await _hand_at(rig, here, here._grab_point())
	_close(rig, here, 0.0)
	for i in range(6):
		await _hand_at(rig, here, here._grab_point())
	_let_the_hand_go(rig)
	await get_tree().physics_frame


## A HAND AT A PLACE IN THE CONTROL'S OWN FRAME, for one physics frame.
##
## IN THE CONTROL'S FRAME AND NOT THE WORLD'S, and that is not a convenience. `force_hand` takes a
## world pose, the fighter is doing 200 knots, and a world pose handed over once is a hand left
## behind in the sky within two frames -- still holding the switch, and dragging it to its stop.
## The first run of this wound a trim wheel from the middle to zero that way and called it a pass.
func _hand_at(rig: PilotRig, control: VehicleControl, at: Vector3) -> void:
	rig.force_hand(RIGHT, Transform3D(Basis.IDENTITY, control.global_transform * at))
	await get_tree().physics_frame


## ---- and the buttons, which the report also named ---------------------------------------------

## A CREW BUTTON IS NOT A POSITION, SO IT IS NOT DRAWN LIKE ONE. It has no channel of its own and no
## value: `CrewButton.pressed` reaches `PilotRig._on_crew_button`, which sends `Channel.CREW_TOGGLE`,
## and what every button aboard then SHOWS is the craft's own `crew_light` flag. So the question to
## ask about a button is not where it is, it is whether it is LIT -- at the seat that did not press
## it, and then not lit again once it is pressed back.
##
## THE FINGER AND THE SQUEEZE, through the rig. `CrewButton.offer_hand` wants a hand on the cap AND a
## closed grip, and it re-arms only when the hand comes off or the grip opens -- a hand simply
## resting near the console used to toggle the cabin every time it drifted within a few centimetres.
func _a_button_pressed_at_one_seat_lights_the_one_at_the_other(rig: PilotRig) -> void:
	var view: VehicleView = await _take(rig, Sim.Kind.PLANE)
	if view == null:
		_check("this_machine_gets_into_a_fighter_to_press_a_button", false, "no view")
		return
	var mine: int = rig.seat_index()
	var here := view.controls_for(mine).get("button") as CrewButton
	var buttons: Array[CrewButton] = []
	var poses: Array = Sim.geometry_of(Sim.Kind.PLANE).get("seat_poses", []) as Array
	for seat in range(poses.size()):
		var button := view.controls_for(seat).get("button") as CrewButton
		if button != null and button != here:
			buttons.append(button)
	_check("every_other_fighter_station_has_its_own_crew_button",
		here != null and buttons.size() == poses.size() - 1,
		"%d other buttons across %d stations" % [buttons.size(), poses.size()])
	if here == null or buttons.is_empty():
		return
	var was: bool = buttons[0].lit
	var lit: int = await _press_it(rig, here, buttons, not was)
	_check("a_crew_button_pressed_at_one_seat_lights_every_other_station", lit >= 0,
		"%d other stations went %s after %d frames" % [buttons.size(), not was, lit])
	# AND BACK. `_press_it` refuses to answer about a lamp that is ALREADY where it is being asked
	# to go -- it returns -1 rather than 0 -- because "it is off and I wanted it off" is a pass this
	# check can get without the press doing anything at all, which is the shape that let a removal
	# check pass over nobody being removed (`testing_godot_headless.md`).
	var out: int = await _press_it(rig, here, buttons, was)
	_check("and_pressing_it_again_puts_every_other_stations_button_back", out >= 0,
		"%d stations back to %s after %d frames" % [buttons.size(), was, out])
	_let_the_hand_go(rig)


## PRESS `here` AND WAIT FOR every other station TO SAY `wanted`: the frame they did, or -1. The finger comes off
## the cap afterwards, because the button only re-arms when the hand leaves or the grip opens.
func _press_it(rig: PilotRig, here: CrewButton, others: Array[CrewButton], wanted: bool) -> int:
	if others.all(func(button: CrewButton) -> bool: return button.lit == wanted):
		return -1
	_close(rig, here, 1.0)
	var landed: int = -1
	for i in range(PATIENCE):
		await _hand_at(rig, here, here._grab_point())
		if others.all(func(button: CrewButton) -> bool: return button.lit == wanted):
			landed = i
			break
	_close(rig, here, 0.0)
	for i in range(6):
		await _hand_at(rig, here, here._grab_point())
	_let_the_hand_go(rig)
	for i in range(4):
		await get_tree().physics_frame
	return landed


## CLOSE THE FINGER THAT TAKES THIS ONE, and let the CONTROL say which.
##
## A bat switch, a button, a knob, a dial and a screen are PINCHED with the index finger; a stick, a
## wheel, a lever and a gun are GRABBED with the whole fist (`VehicleControl.taken_by`, 2026-09-15).
## A fist on a bat switch has done nothing since that landed, and a suite that closes the wrong one
## reports "held by -1", which reads as a reach or a layout fault and is neither. Ask, do not assume;
## `tests/shared_controls.gd` has the same helper for the same reason.
func _close(rig: PilotRig, control: VehicleControl, shut: float) -> void:
	if control.taken_by() == Bind.Take.PINCH:
		rig.force_input(RIGHT, Bind.TRIGGER, shut)
	else:
		rig.force_grip(RIGHT, shut)


## What takes this one, for a failure's detail line.
func _finger(control: VehicleControl) -> String:
	return "a pinch" if control.taken_by() == Bind.Take.PINCH else "a grip"


## THE HAND OFF EVERYTHING: both fingers released and the forced pose dropped, so the next section
## starts with an empty hand whichever kind of control the last one was.
func _let_the_hand_go(rig: PilotRig) -> void:
	rig.force_input(RIGHT, Bind.TRIGGER, null)
	rig.force_grip(RIGHT, -1.0)
	rig.force_hand(RIGHT, null)


## ---- getting into a craft, and seating a mate in it ------------------------------------------

func _take(rig: PilotRig, kind: int) -> VehicleView:
	var view: VehicleView = rig.vehicle_view()
	if view != null and view.kind == kind:
		return view
	rig.ask_for_kind(kind)
	for i in range(600):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == kind and view.station_for(rig.seat_index()) != null:
			return view
	return null


## A SECOND CREW MEMBER IN `seat`, made the way the server makes one and seated by the server,
## which is the only thing that decides who sits where. Their pilot entity, or 0.
func _seat_a_mate(view: VehicleView, seat: int) -> int:
	var craft: int = 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			craft = int((pilot as Dictionary).get("vehicle", 0))
	if craft == 0:
		return 0
	_next_spare += 1
	var who: int = 200 + _next_spare
	var made: Dictionary = Sim.server.spawn_pilot(who, Sim.Kind.POD,
		Vector3(3000.0 + float(_next_spare) * 20.0, 40.0, 3000.0), 0.0, Vector3.ZERO)
	if not Sim.server.seat_client(who, craft, seat):
		return 0
	for i in range(PATIENCE):
		await get_tree().physics_frame
		if view.station_for(seat) != null:
			break
	return int(made.get("pilot", 0))


func _physics_process(_delta: float) -> void:
	# EVERY FRAME, because a control frame is a LEVEL: the simulation reads the newest one it has
	# and a frame written once is a hand that let go on the next tick.
	for pilot in _crew_inputs:
		Sim.server.set_pilot_input(pilot, _crew_inputs[pilot])


## A complete control frame, sticks centred.
func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
