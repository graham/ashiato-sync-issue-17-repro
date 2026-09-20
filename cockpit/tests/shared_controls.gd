extends Node
## Headless: A SWITCH ON THE CRAFT SHOWS THE CRAFT -- at every seat, whoever moved it, and whatever this machine did last.
##
##   Godot --headless --path cockpit res://tests/shared_controls.tscn
##
## THE BUG THIS EXISTS FOR. The master arm switch fitted for the missiles (9cec76d) showed only what a hand on THIS
## machine had done to it: the U key armed the craft and the switch stayed at SAFE, and the copilot's switch never moved
## at all. Only four roles were ever drawn back from the bus (`FlightLevel._draw_cockpit`: extra, flaps, gear, drop), so
## the trim wheel, the arm switch and every knob and switch the builder can place were controls whose picture was local.
## A switch showing SAFE on an armed craft is also a switch a hand cannot disarm: pulled back, it is already back.
##
## AND ITS OTHER HALVES. Taking a seat forgot what the rig had sent, so the next frame sent every latched control's LOCAL
## position as a command. And the input frame carries ONE command: a second sent in the same frame overwrote the first,
## and four brought the two-bit sequence back to where it started, so none of them arrived at all.
##
## THE REAL PATH. The desk's own keys (U, Y, F) as key events with both codes set, and a hand closed on a switch and on a
## wheel through the rig's own hand pass (`force_hand`, `force_grip`). What is read back is the craft's bus on this
## client and the controls' own positions. Nothing here calls `send_command` except once, to put the trim somewhere
## recognisable before the seat change -- which is an arrangement and not the thing under test.
##
## A FORCED HAND IS A WORLD POSE AND THE AEROPLANE IS DOING 58 m/s, so a hand placed once is left behind in the sky
## within a frame or two, still holding what it closed on. The first run wound a trim wheel to its stop that way. Every
## hand here is placed again on every physics frame, from the control's own transform.
##
## ONE PROCESS, EVERY SEAT. `VehicleView.man` builds a station at every seat of a manned craft, so the copilot's switch
## exists here and is drawn by the same loop that draws it on the copilot's own machine. Whether the bus reaches that
## other machine is ashiato's to test (addon/tests/cockpit_loopback.gd).
##
## Read RESULT=, not the exit code.

const PLANE: int = Sim.Kind.PLANE
const RIGHT: int = 1
## HOW LONG THE CRAFT IS GIVEN TO ANSWER, in physics frames: a second at 120 Hz. A solo world answers a command in a
## couple of ticks, so this is an order of margin and not a guess at the rate.
const PATIENCE: int = 120
## Where the trim is put before the seat change: far from the middle, so a re-centre cannot pass for it.
const TRIM_SET: int = 200
## How far a hand winds a wheel, in metres along the rim. About forty counts of the channel's 255.
const WIND: float = 0.15
## How long a thumb holds the mini joystick back to trim, in physics frames: half a second at 120 Hz, long enough for
## the trim to move a couple of dozen counts at the rig's rate and short enough to stay off the stop.
const TRIM_FRAMES: int = 60
## FIVE DIFFERENT CHANNELS the plane carries, asked for in one frame. Five because four is the number that wrapped the
## library's two-bit sequence back to where it was, so a burst of five crosses that wrap whatever it started at.
const BURST: Array[int] = [Sim.Channel.RADIO, Sim.Channel.DISPLAY, Sim.Channel.LIGHTS, Sim.Channel.FLAPS,
	Sim.Channel.SPOILERS]

var _failures: PackedStringArray = []
var _level: FlightLevel = null
## Sections that reached their own end. See the note in tests/feel.gd.
var _sections: int = 0
const SECTIONS: int = 10


func _check(label: String, ok: bool, detail: String) -> void:
	print("[shared] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
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
	var rig: PilotRig = _level.rig
	if not await _the_player_gets_into_a_plane(rig):
		_finish()
		return
	var view: VehicleView = rig.vehicle_view()
	await _the_arm_key_arms_every_switch_aboard(view)
	await _a_hand_throws_it_back_and_every_seat_sees_that_too(rig, view)
	await _two_switches_thrown_on_one_frame_both_reach_the_craft(view)
	await _a_burst_of_five_channels_in_one_frame_all_lands_in_order(view)
	await _the_stick_trims_through_the_craft_and_every_wheel_follows(rig, view)
	await _the_lower_thumb_steps_the_missile_stations_the_craft_carries(rig, view)
	await _changing_seat_neither_disarms_nor_retrims(rig, view)
	await _a_wheel_the_craft_refuses_goes_back(rig, view)
	await _a_stick_with_no_trim_leaves_the_thumbstick_alone(rig)
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
	_sections += 1
	return ok


## ---- the master arm ---------------------------------------------------------------------

## THE KEY IS NOT THE SWITCH, which is the point: the craft is armed by something other than the switch, and every
## switch aboard has to say so -- the one in front of the player and the one in front of the empty copilot's seat.
func _the_arm_key_arms_every_switch_aboard(view: VehicleView) -> void:
	# THE STATIONS ARRIVE OVER FRAMES in a flight since lane/ashiato-latest's station budget (74f674c1): this machine's
	# seat first, the others after. So the copilot's switch is waited for, a second at most, not counted on the first
	# frame the player is seated -- which the sweeper found reading 1 switch (pass 5, 2026-09-19).
	var arms: Array = _arm_switches(view)
	for _i in range(120):
		if arms.size() >= 2:
			break
		await get_tree().process_frame
		arms = _arm_switches(view)
	_check("the_pilot_and_the_copilot_each_have_a_master_arm_switch", arms.size() >= 2,
		"%d, %s" % [arms.size(), _positions(arms)])
	_check("and_the_craft_starts_safe", not _master(view), "master %s" % _master(view))
	await _hold("master_arm", 2)
	var armed: int = await _frames_until(func() -> bool: return _master(view))
	_check("the_arm_key_arms_the_craft", armed >= 0, "master on this client after %d frames" % armed)
	var shown: int = await _frames_until(func() -> bool: return _all_on(arms, true))
	_check("and_every_master_arm_switch_aboard_shows_armed", shown >= 0,
		"%s, %d frames after the craft" % [_positions(arms), shown])
	_sections += 1


## A HAND THROWS THE PILOT'S SWITCH BACK TO SAFE, and the craft and the copilot's switch follow -- and the pilot's own
## switch stays at safe once the hand is off it, which is the half a switch drawn from a stale wire gets wrong.
func _a_hand_throws_it_back_and_every_seat_sees_that_too(rig: PilotRig, view: VehicleView) -> void:
	var station: CockpitStation = view.station_for(rig.seat_index())
	var arm := station.get_node_or_null("MasterArm") as ToggleSwitch if station != null else null
	if arm == null:
		_check("the_pilot_has_a_master_arm_switch", false, "none at seat %d" % rig.seat_index())
		_sections += 1
		return
	var grip: Vector3 = arm._grab_point()
	var taken: bool = await _take_hold(rig, arm, grip)
	_check("the_right_hand_takes_hold_of_the_pilots_arm_switch", taken, "held by %d" % arm.held_by)
	# NOT A PULL ON A SWITCH THAT WAS ALREADY BACK: that would pass over the very bug above.
	_check("and_the_switch_under_the_hand_is_at_armed", arm.is_on(),
		"position %d, craft armed %s" % [arm.at_position(), _master(view)])
	# PULLED BACK IS SAFE: forward is on. See ToggleSwitch.
	await _hand_follows(rig, arm, grip + Vector3(0.0, 0.0, ToggleSwitch.THROW), 6)
	_check("and_pulling_it_back_throws_it_to_safe", not arm.is_on(), "position %d" % arm.at_position())
	var safe: int = await _frames_until(func() -> bool: return not _master(view))
	_check("which_disarms_the_craft", safe >= 0, "master %s after %d frames" % [_master(view), safe])
	await _let_go(rig, arm, grip + Vector3(0.0, 0.0, ToggleSwitch.THROW))
	for i in range(PATIENCE):
		await get_tree().physics_frame
	var arms: Array = _arm_switches(view)
	_check("and_once_the_hand_is_off_it_every_switch_aboard_shows_safe", not _master(view) and _all_on(arms, false),
		"%s, master %s, a second after letting go" % [_positions(arms), _master(view)])
	_sections += 1


## ---- one frame, two commands ---------------------------------------------------------------

## TWO SWITCHES ON ONE FRAME. The arm key and the station key, pressed together: two commands on one input frame, and
## both have to land. A frame that carries one command keeps the last and loses the first.
func _two_switches_thrown_on_one_frame_both_reach_the_craft(view: VehicleView) -> void:
	var was_armed: bool = _master(view)
	var was_station: int = view.channel_value(Sim.Channel.WEAPON)
	var arm_key: Key = _key_of("master_arm")
	var station_key: Key = _key_of("weapon_station")
	_key(arm_key, true)
	_key(station_key, true)
	for i in range(2):
		await get_tree().physics_frame
	_key(arm_key, false)
	_key(station_key, false)
	var both: int = await _frames_until(func() -> bool:
		return _master(view) != was_armed and view.channel_value(Sim.Channel.WEAPON) != was_station)
	_check("two_switches_thrown_on_one_frame_both_reach_the_craft", both >= 0,
		"master %s -> %s, station %d -> %d" % [was_armed, _master(view), was_station,
			view.channel_value(Sim.Channel.WEAPON)])
	_sections += 1


## A BURST: FIVE CHANNELS IN ONE FRAME, EVERY ONE LANDS, IN THE ORDER ASKED. The input frame carries one command, and
## the library kept one pending and bumped a two-bit sequence per send -- so a burst lost all but its last, and four
## wrapped the sequence to nothing. Each channel is asked for one notch along from where it is, and the frame each one
## lands on is recorded: every one has to arrive, and no later ask may land before an earlier one.
##
## Then put back, the same way, so the flaps and spoilers do not fly the rest of the suite.
func _a_burst_of_five_channels_in_one_frame_all_lands_in_order(view: VehicleView) -> void:
	var was: Dictionary = {}
	var asked: Dictionary = {}
	for channel in BURST:
		var top: int = view.channel_range(channel)
		if top <= 0:
			continue
		was[channel] = view.channel_value(channel)
		asked[channel] = (int(was[channel]) + 1) % (top + 1)
	_check("the_plane_carries_every_channel_in_the_burst", asked.size() == BURST.size(),
		"%d of %d fitted" % [asked.size(), BURST.size()])
	var frames: Array = await _send_and_watch(view, asked)
	var every: bool = not frames.has(-1)
	var ordered: bool = every
	for i in range(1, frames.size()):
		ordered = ordered and int(frames[i]) >= int(frames[i - 1])
	_check("five_channels_asked_for_in_one_frame_all_land", every,
		"%s asked, landed on frames %s" % [_named(asked), frames])
	_check("and_they_land_in_the_order_they_were_asked", ordered, "frames %s" % [frames])
	var back: Array = await _send_and_watch(view, was)
	_check("and_put_back_the_same_way_they_all_land_again", not back.has(-1), "frames %s" % [back])
	_sections += 1


## SEND EVERY CHANNEL IN `wanted` IN ONE FRAME, through `Sim.send_command`, and return the physics frame each one was first
## seen at its value on this client, in the order sent; -1 for one that never arrived within `PATIENCE`.
func _send_and_watch(view: VehicleView, wanted: Dictionary) -> Array:
	var order: Array = wanted.keys()
	for channel in order:
		Sim.send_command(int(channel), int(wanted[channel]))
	var seen: Array = []
	seen.resize(order.size())
	seen.fill(-1)
	for frame in range(PATIENCE):
		for i in range(order.size()):
			if int(seen[i]) < 0 and view.channel_value(int(order[i])) == int(wanted[order[i]]):
				seen[i] = frame
		if not seen.has(-1):
			break
		await get_tree().physics_frame
	return seen


func _named(wanted: Dictionary) -> String:
	var said: PackedStringArray = []
	for channel in wanted:
		said.append("%s=%d" % [Sim.channel_name(int(channel)), int(wanted[channel])])
	return ", ".join(said)


## ---- the lower thumb, on a stick that launches -----------------------------------------------

## THE LOWER THUMB WALKS THE MISSILE STATIONS THE CRAFT CARRIES, and only those. The weapon channel is fitted with more
## positions than the plane has racks (cockpit_world.cpp fits Weapon at range 3 and loads two), so stepping the channel
## by one landed on selectors with nothing on them. Every press has to move the station, every station it lands on has
## to be one the schema lists, it has to go round all of them, and the sight has to name the one it is on.
func _the_lower_thumb_steps_the_missile_stations_the_craft_carries(rig: PilotRig, view: VehicleView) -> void:
	var numbers: Array = []
	for entry in (Sim.missile_schema(view.kind).get("stations", []) as Array):
		numbers.append(int((entry as Dictionary).get("station", -1)))
	var station: CockpitStation = view.station_for(rig.seat_index())
	var stick := station.controls().get("stick") as FlightStick if station != null else null
	_check("the_pilots_stick_launches_on_the_trigger", stick != null and stick.launches and stick.launch_on_trigger,
		"stick %s" % [stick])
	if stick == null:
		_sections += 1
		return
	var grip: Vector3 = stick._grab_point()
	var taken: bool = await _take_hold(rig, stick, grip)
	_check("the_right_hand_takes_hold_of_the_stick_to_choose_a_station", taken, "held by %d" % stick.held_by)
	var landed: Array = []
	var stuck: int = 0
	for press in range(numbers.size() * 2):
		var was: int = view.channel_value(Sim.Channel.WEAPON)
		rig.force_input(RIGHT, Bind.THUMB_LOW, true)
		await _hand_follows(rig, stick, grip, 2)
		rig.force_input(RIGHT, Bind.THUMB_LOW, false)
		await _hand_follows(rig, stick, grip, 2)
		rig.force_input(RIGHT, Bind.THUMB_LOW, null)
		var moved: int = -1
		for i in range(PATIENCE):
			if view.channel_value(Sim.Channel.WEAPON) != was:
				moved = i
				break
			await _hand_follows(rig, stick, grip, 1)
		if moved < 0:
			stuck += 1
		landed.append(view.channel_value(Sim.Channel.WEAPON))
	_check("every_press_of_the_lower_thumb_moves_the_station", stuck == 0 or numbers.size() < 2,
		"%d of %d presses moved nothing" % [stuck, numbers.size() * 2])
	var strangers: Array = landed.filter(func(n: int) -> bool: return not numbers.has(n))
	_check("and_every_station_it_lands_on_is_one_the_craft_carries", strangers.is_empty(),
		"carries %s, landed on %s" % [numbers, landed])
	var visited: Array = []
	for n in landed:
		if not visited.has(n):
			visited.append(n)
	_check("and_it_goes_round_every_one_of_them", visited.size() == numbers.size(),
		"carries %s, visited %s" % [numbers, visited])
	# AND THE SIGHT NAMES THE STATION IT IS ON, found by the station's own number and not by where it sits in the list.
	# The two coincide on the plane (0 and 1); they would not on a craft whose first rack is empty.
	var sight := station.find_child("LockSight", true, false) as LockSight
	var chosen: String = "?"
	for entry in (Sim.missile_schema(view.kind).get("stations", []) as Array):
		if int((entry as Dictionary).get("station", -1)) == view.channel_value(Sim.Channel.WEAPON):
			chosen = String((entry as Dictionary).get("name", "?"))
	var named: int = await _frames_until(func() -> bool:
		return sight != null and sight.says().to_upper().contains(chosen.to_upper()))
	_check("and_the_sight_names_the_station_it_landed_on", named >= 0,
		"%s, sight says %s" % [chosen, sight.says().replace("\n", " | ") if sight != null else "-"])
	await _let_go(rig, stick, grip)
	_sections += 1


## ---- a seat is taken -----------------------------------------------------------------------

## TAKING A SEAT PROPOSES NOTHING. The craft is armed and trimmed off the middle, the player moves one seat along with
## the desk's own key, and the craft is still armed and still trimmed where it was -- and every wheel aboard says where.
func _changing_seat_neither_disarms_nor_retrims(rig: PilotRig, view: VehicleView) -> void:
	# ARMED BY THE KEY, AND ONLY IF IT IS NOT ALREADY: the key is a step, and pressing it on an armed craft disarms it
	# before the seat change can -- which is how the first run of this check passed over the bug it is for.
	if not _master(view):
		await _hold("master_arm", 2)
	# ARRANGED, NOT TESTED: somewhere recognisable for the trim. See the header.
	Sim.send_command(Sim.Channel.TRIM, TRIM_SET)
	var ready: int = await _frames_until(func() -> bool:
		return _master(view) and view.channel_value(Sim.Channel.TRIM) == TRIM_SET)
	_check("before_the_seat_change_the_craft_is_armed_and_trimmed", ready >= 0,
		"master %s, trim %d" % [_master(view), view.channel_value(Sim.Channel.TRIM)])
	var was: int = rig.seat_index()
	await _hold("seat", 2)
	var moved: int = await _frames_until(func() -> bool: return rig.seat_index() != was)
	_check("the_seat_key_moves_the_player_along", moved >= 0, "seat %d -> %d" % [was, rig.seat_index()])
	for i in range(30):
		await get_tree().physics_frame
	_check("changing_seat_leaves_the_craft_armed", _master(view), "master %s" % _master(view))
	_check("and_leaves_its_trim_where_it_was", view.channel_value(Sim.Channel.TRIM) == TRIM_SET,
		"trim %d, was set to %d" % [view.channel_value(Sim.Channel.TRIM), TRIM_SET])
	var wheels: Array = _trim_wheels(view)
	var shown: int = await _frames_until(func() -> bool: return _all_at(wheels, TRIM_SET))
	_check("and_every_trim_wheel_aboard_shows_it", shown >= 0, _positions(wheels))
	_sections += 1


## ---- a refusal -----------------------------------------------------------------------------

## A PROPOSAL THE CRAFT REFUSES GOES BACK. Trim is a physical channel, and the server takes a physical channel only from a
## seat that flies (`apply_command`); the plane's back two seats are turrets. So a hand winds the wheel at a turret seat,
## the craft keeps its trim, and once the hand lets go the wheel returns to where the craft says the trim is.
func _a_wheel_the_craft_refuses_goes_back(rig: PilotRig, view: VehicleView) -> void:
	for tries in range(4):
		if not view._seat_flies(rig.seat_index()):
			break
		var was: int = rig.seat_index()
		await _hold("seat", 2)
		await _frames_until(func() -> bool: return rig.seat_index() != was)
	var seat: int = rig.seat_index()
	_check("the_player_reaches_a_seat_that_does_not_fly", not view._seat_flies(seat), "seat %d" % seat)
	var station: CockpitStation = view.station_for(seat)
	var wheel := station.get_node_or_null("Trim") as TrimWheel if station != null else null
	_check("and_that_seat_has_a_trim_wheel", wheel != null, "seat %d" % seat)
	if wheel == null:
		_sections += 1
		return
	for i in range(30):
		await get_tree().physics_frame
	var craft: int = view.channel_value(Sim.Channel.TRIM)
	var grip: Vector3 = wheel._grab_point()
	var taken: bool = await _take_hold(rig, wheel, grip)
	_check("the_right_hand_takes_hold_of_the_turret_seats_wheel", taken, "held by %d" % wheel.held_by)
	var wound_to := grip + Vector3(0.0, 0.0, -WIND)
	await _hand_follows(rig, wheel, wound_to, PATIENCE / 2)
	var wound: int = wheel.command_value()
	# WOUND, AND NOT TO A STOP. A wheel at 0 or at its top is a hand left behind by the aeroplane, not a hand winding.
	_check("the_hand_winds_the_wheel_part_of_a_turn", wound != craft and wound > 0 and wound < wheel.channel_range,
		"wheel at %d, craft at %d" % [wound, craft])
	_check("but_the_craft_refuses_trim_from_a_seat_that_does_not_fly",
		view.channel_value(Sim.Channel.TRIM) == craft,
		"trim %d, was %d" % [view.channel_value(Sim.Channel.TRIM), craft])
	await _let_go(rig, wheel, wound_to)
	var back: int = await _frames_until(func() -> bool:
		return wheel.command_value() == view.channel_value(Sim.Channel.TRIM), PATIENCE * 2)
	_check("and_once_the_hand_is_off_it_the_wheel_goes_back_to_where_the_craft_is", back >= 0,
		"wheel %d, craft %d, %d frames after letting go" % [wheel.command_value(),
			view.channel_value(Sim.Channel.TRIM), back])
	_sections += 1


## ---- trim, from the stick ---------------------------------------------------------------------

## THE STICK TRIMS THE CRAFT, AND EVERY WHEEL SHOWS IT. A hand closed on the pilot's stick pulls the mini joystick back,
## the craft's trim climbs at the rig's own rate, and every trim wheel aboard follows; pressing the joystick in puts it
## back to neutral. Through the bus both ways -- the thumb proposes, the craft decides, the wheels draw the craft -- so
## a wheel and a stick can never show two trims.
func _the_stick_trims_through_the_craft_and_every_wheel_follows(rig: PilotRig, view: VehicleView) -> void:
	var station: CockpitStation = view.station_for(rig.seat_index())
	var stick := station.controls().get("stick") as FlightStick if station != null else null
	if stick == null:
		_check("the_pilot_has_a_stick", false, "seat %d" % rig.seat_index())
		_sections += 1
		return
	var top: int = view.channel_range(Sim.Channel.TRIM)
	var grip: Vector3 = stick._grab_point()
	var taken: bool = await _take_hold(rig, stick, grip)
	_check("the_right_hand_takes_hold_of_the_stick_to_trim", taken, "held by %d" % stick.held_by)
	var before: int = view.channel_value(Sim.Channel.TRIM)
	# PULLED BACK, which is nose up: a thumbstick reports +y pushed forward, and forward is nose down.
	rig.force_input(RIGHT, Bind.STICK, Vector2(0.0, -1.0))
	await _hand_follows(rig, stick, grip, TRIM_FRAMES)
	rig.force_input(RIGHT, Bind.STICK, null)
	var settled: int = await _frames_until(func() -> bool:
		return view.shown_value(Sim.Channel.TRIM) == view.channel_value(Sim.Channel.TRIM))
	var after: int = view.channel_value(Sim.Channel.TRIM)
	# THE RATE IS THE RIG'S: `PilotRig.TRIM_RATE` of the travel a second. Asserted as an envelope, not a number: the
	# first and last frames of a push are a count either way.
	var expected: float = PilotRig.TRIM_RATE * float(top) * float(TRIM_FRAMES) / float(Engine.physics_ticks_per_second)
	_check("pulling_the_mini_joystick_back_trims_the_nose_up_at_the_rigs_rate",
		after > before and absf(float(after - before) - expected) <= expected * 0.35 + 2.0,
		"trim %d -> %d over %d frames, %.1f expected, settled %d frames later" % [before, after, TRIM_FRAMES,
			expected, settled])
	var wheels: Array = _trim_wheels(view)
	var shown: int = await _frames_until(func() -> bool:
		return _all_at(wheels, view.channel_value(Sim.Channel.TRIM)))
	_check("and_every_trim_wheel_aboard_shows_the_trim_the_stick_set", shown >= 0,
		"%s, craft %d" % [_positions(wheels), view.channel_value(Sim.Channel.TRIM)])
	rig.force_input(RIGHT, Bind.STICK_CLICK, true)
	await _hand_follows(rig, stick, grip, 2)
	rig.force_input(RIGHT, Bind.STICK_CLICK, false)
	await _hand_follows(rig, stick, grip, 2)
	rig.force_input(RIGHT, Bind.STICK_CLICK, null)
	var neutral: int = TrimWheel.neutral(top)
	var centred: int = await _frames_until(func() -> bool: return view.channel_value(Sim.Channel.TRIM) == neutral)
	_check("pressing_the_mini_joystick_in_puts_the_trim_back_to_neutral", centred >= 0,
		"trim %d, neutral %d" % [view.channel_value(Sim.Channel.TRIM), neutral])
	var wheels_centred: int = await _frames_until(func() -> bool: return _all_at(wheels, neutral))
	_check("and_every_wheel_shows_neutral", wheels_centred >= 0, _positions(wheels))
	await _let_go(rig, stick, grip)
	_sections += 1


## ---- a craft with no trim ------------------------------------------------------------------------

## NO TRIM, AND THE THUMBSTICK IS WHAT IT WAS. The pod has a stick and no trim channel, so a hand closed on its stick
## must leave the mini joystick to the empty hand's own binding.
func _a_stick_with_no_trim_leaves_the_thumbstick_alone(rig: PilotRig) -> void:
	rig.ask_for_kind(Sim.Kind.POD)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == Sim.Kind.POD:
			break
	_check("the_player_gets_into_a_pod", view != null and view.kind == Sim.Kind.POD,
		"kind %s" % [view.kind if view != null else "-"])
	if view == null or view.kind != Sim.Kind.POD:
		_sections += 1
		return
	_check("which_has_no_trim", view.channel_range(Sim.Channel.TRIM) <= 0,
		"range %d" % view.channel_range(Sim.Channel.TRIM))
	var station: CockpitStation = view.station_for(rig.seat_index())
	var stick := station.controls().get("stick") as FlightStick if station != null else null
	if stick == null:
		_check("the_pod_has_a_stick", false, "seat %d" % rig.seat_index())
		_sections += 1
		return
	var grip: Vector3 = stick._grab_point()
	var taken: bool = await _take_hold(rig, stick, grip)
	_check("the_right_hand_takes_hold_of_the_pods_stick", taken, "held by %d" % stick.held_by)
	var held: Dictionary = rig._bindings_for(RIGHT)
	var empty: Dictionary = rig._global_bindings(RIGHT)
	_check("and_its_mini_joystick_keeps_the_empty_hands_binding",
		Bind.says(held.get(Bind.STICK)) == Bind.says(empty.get(Bind.STICK))
			and Bind.says(held.get(Bind.STICK_CLICK)) == Bind.says(empty.get(Bind.STICK_CLICK)),
		"held: %s / %s; empty: %s / %s" % [Bind.says(held.get(Bind.STICK)), Bind.says(held.get(Bind.STICK_CLICK)),
			Bind.says(empty.get(Bind.STICK)), Bind.says(empty.get(Bind.STICK_CLICK))])
	await _let_go(rig, stick, grip)
	_sections += 1


## ---- hands ---------------------------------------------------------------------------------

## A HAND ON A CONTROL, offset in the control's own frame, as the world pose `force_hand` takes.
func _hand_at(control: VehicleControl, local: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, control.to_global(local))


## KEEP THE HAND THERE for `frames` physics frames, placed again every frame -- see the header on why once is not enough.
func _hand_follows(rig: PilotRig, control: VehicleControl, local: Vector3, frames: int) -> void:
	for i in range(frames):
		rig.force_hand(RIGHT, _hand_at(control, local))
		await get_tree().physics_frame


## CLOSE THE FINGER THAT TAKES THIS ONE. The master arm switch is PINCHED and the stick and the
## trim wheel are GRABBED -- see `VehicleControl.taken_by` -- so which finger to close is asked of
## the control rather than assumed. A fist on a bat switch has done nothing since 2026-09-15.
func _take_hold(rig: PilotRig, control: VehicleControl, grip: Vector3) -> bool:
	_close(rig, control, 1.0)
	await _hand_follows(rig, control, grip, 6)
	return control.held_by == RIGHT


func _close(rig: PilotRig, control: VehicleControl, shut: float) -> void:
	if control.taken_by() == Bind.Take.PINCH:
		rig.force_input(RIGHT, Bind.TRIGGER, shut)
	else:
		rig.force_grip(RIGHT, shut)


## LET GO, AS A SQUEEZE ENDS AND NOT AS A TAP. A grip opened within `PilotRig.TAP_SECONDS` of closing is a LATCH, and the
## latch is timed on the WALL clock (`_grip_of`), which a run at `--fixed-fps` gets through far faster than frames. So the
## hand stays closed, where it is, until that much real time has passed, and taps once more if it latched anyway.
func _let_go(rig: PilotRig, control: VehicleControl, local: Vector3) -> void:
	# A PINCH HAS NO LATCH -- see `PilotRig._taking_finger` -- so letting go of one is just
	# letting go, and none of the waiting below applies to it.
	if control.taken_by() == Bind.Take.PINCH:
		rig.force_input(RIGHT, Bind.TRIGGER, null)
		await _hand_follows(rig, control, local, 4)
		rig.force_hand(RIGHT, null)
		return
	var closed_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - closed_at < int((PilotRig.TAP_SECONDS + 0.15) * 1000.0):
		await _hand_follows(rig, control, local, 1)
	rig.force_grip(RIGHT, 0.0)
	await _hand_follows(rig, control, local, 4)
	if control.held_by == RIGHT:
		rig.force_grip(RIGHT, 1.0)
		await _hand_follows(rig, control, local, 2)
		rig.force_grip(RIGHT, 0.0)
		await _hand_follows(rig, control, local, 4)
	rig.force_hand(RIGHT, null)
	rig.force_grip(RIGHT, -1.0)


## ---- what is aboard --------------------------------------------------------------------------

func _master(view: VehicleView) -> bool:
	return bool(Sim.client.craft_systems(view.entity).get("master", false))


func _arm_switches(view: VehicleView) -> Array:
	return _at_every_seat(view, "MasterArm")


func _trim_wheels(view: VehicleView) -> Array:
	return _at_every_seat(view, "Trim")


func _at_every_seat(view: VehicleView, named: String) -> Array:
	var out: Array = []
	for seat in view.manned_seats():
		var station: CockpitStation = view.station_for(int(seat))
		var found := station.get_node_or_null(named) as VehicleControl if station != null else null
		if found != null:
			out.append(found)
	return out


func _all_on(controls: Array, on: bool) -> bool:
	if controls.is_empty():
		return false
	for control in controls:
		if (control as ToggleSwitch).is_on() != on:
			return false
	return true


func _all_at(controls: Array, at: int) -> bool:
	if controls.is_empty():
		return false
	for control in controls:
		if (control as VehicleControl).command_value() != at:
			return false
	return true


func _positions(controls: Array) -> String:
	var said: PackedStringArray = []
	for control in controls:
		said.append("seat %d at %d" % [(control as VehicleControl).seat, (control as VehicleControl).command_value()])
	return ", ".join(said)


## HOW MANY PHYSICS FRAMES UNTIL `cond` HOLDS, or -1 if it never does within `frames`. Settles on the value, not on a
## frame count -- see testing_godot_headless.md.
func _frames_until(cond: Callable, frames: int = PATIENCE) -> int:
	for i in range(frames):
		if bool(cond.call()):
			return i
		await get_tree().physics_frame
	return -1


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
