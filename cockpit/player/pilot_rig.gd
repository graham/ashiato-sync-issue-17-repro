extends Node3D
class_name PilotRig

## Emitted once after a builder operation settles. The builder session serializes the
## complete station then; drag poses are never streamed.
signal builder_layout_released
## The local player: an OpenXR rig that is a PERMANENT CHILD of a seat.
##
## ---------------------------------------------------------------------------------
## THIS FILE NEVER SETS A WORLD TRANSFORM. NOT ONCE.
## ---------------------------------------------------------------------------------
##
## It is parented to a seat anchor on the vehicle's node with an identity local transform,
## and from then on the scene graph does the work. The head and hands are the tracker
## poses, applied by OpenXR relative to that origin every frame, at the display rate.
##
## That is the whole reason the cockpit is steady. A hand held still has a constant local
## transform whether the aircraft is parked or doing 200 knots -- the vehicle's speed is
## not a term in the expression at all, so no amount of it can add jitter. The previous
## project computed a world pose for the player each frame and then tried to keep it in
## step with the vehicle's; two calculations of the same thing agree only while nothing
## goes wrong with either.
##
## The tracked poses go OUT as control input, so other people and the server know where
## this player's hands are. Nothing comes back in. Routing your own head through the
## network would add the round trip to head tracking, and head-tracking latency in VR is
## not a feel problem -- it is a physical one.

## A 1.6 m PILOT'S EYES, standing. Defined by the COCKPIT and read here, not the other way
## round: a station scene needs it to place a lever, and this file cannot be what a station
## scene depends on without closing a load cycle. See CockpitStation.EYE_HEIGHT.
const EYE_HEIGHT: float = CockpitStation.EYE_HEIGHT
## How fast a thumbstick drives the throttle lever or the collective, in full travel per
## second. Slow enough to set a cruise power by feel, quick enough to go from idle to full
## in under two seconds.
const LEVER_RATE: float = 0.7
## AND HOW FAST THE TRIM WHEEL WINDS, in fractions of its travel a second.
##
## A quarter of the throttle's, because the whole travel is two and a half turns of
## a wheel and the useful part of it is the middle. Trim is a control you creep up
## on -- you are cancelling a load you can feel, not setting a number -- and one that
## crossed its range in a second and a half would be one you always overshot.
const TRIM_RATE: float = 0.18
const DEADZONE: float = 0.18
const MOUSE_SENS: float = 0.0025

## ---------------------------------------------------------------------------------
## TELLING A HAND SOMETHING HAPPENED
## ---------------------------------------------------------------------------------
##
## The whole interaction model of this game is closing a hand around a lever, and until now
## nothing anywhere told the hand it had worked. A grab with no pulse is a grab you are not
## sure of: the lever is visibly held, but the one sense that says "you have got it" in
## every real cockpit is silent, and the player checks by looking -- which is the thing
## `fit` and `station_shot` exist to stop them having to do in the visual domain.
##
## ONE PLACE CALLS THE RUNTIME, which is `pulse` below, and everything else asks for a
## FEELING by name. Named reasons, one table, so they can be compared with each other
## rather than tuned one at a time in as many files.
##
## AND IT IS ON THE INTERFACE, NOT ON THE CONTROLLER. `XRController3D` has no
## `trigger_haptic_pulse` -- measured against 4.7.2's own ClassDB, the only one in the
## engine is
##
##   XRInterface.trigger_haptic_pulse(action_name, tracker_name, frequency,
##                                    amplitude, duration_sec, delay_sec)
##
## so the node is where the TRACKER NAME comes from and the interface is what is called.
## The `haptic` action has been in `openxr_action_map.tres` since the project started, bound
## to `/user/hand/{left,right}/output/haptic` on all three profiles, and nothing had ever
## asked it for anything.
const HAPTIC_ACTION: String = "haptic"
## ZERO FREQUENCY IS NOT "no buzz", it is XR_FREQUENCY_UNSPECIFIED -- the runtime picks
## whatever its own hardware does best. A number here would be this file guessing at a
## motor it has never met, and the guess is wrong on half of them.
const PULSE_HZ: float = 0.0
## Everything is scaled by this on the way out. One knob for "the whole game buzzes too
## much", which is the note that always comes back from a first session in a headset.
const HAPTIC_MASTER: float = 0.85
## WHAT EACH THING FEELS LIKE: amplitude 0..1, then seconds.
##
## A grab is a firm thump and letting go is a smaller one, because taking hold is the event
## and letting go is only its end. A detent is the shortest thing here -- what a real
## selector does under a finger is a click, not a push, and a dial turned through three
## stops must be three clicks and not a hum. A round leaving the barrel is the hardest short
## thing a hand feels, and still under a tenth of a second: a gun is not a rumble.
##
## TWICE THE STRENGTH AND LONGER THAN THEY FIRST WERE, and the reason is a headset. The first
## table had a grab at 0.45 for 35 ms -- 0.38 at the motor -- a release at 0.17 for 20 and a
## detent at 0.51 for 28, and a player who played with them on 2026-09-13 felt nothing at
## all. They were likely under what a Quest Touch motor renders. What is here is the user's
## own "yes, stronger" -- and stronger means every one, the detent included: a first go took
## it DOWN to 0.425 and was caught before it landed. Whether it is enough is a headset's
## answer, not a suite's.
##
## AND TWO ARE NOT EVENTS ON A CONTROL AT ALL, but the edge of one: `reach` is something
## coming within a free hand's grasp and `unreach` is it going out again, so a player can
## feel where a grab would work without looking for it. THE LONGEST THINGS IN THE TABLE, and
## `reach` is harder and longer than a grab, a release or a detent, on purpose: the first
## design had them a hint under a grab (0.25 for 20 ms), and what came back was "a couple of
## hundred milliseconds, and I should be able to feel when I'm in a place where I could
## grab". Leaving is the lighter of the two, for the reason letting go is. See `_notice_reach`.
const FEEL: Dictionary = {
	&"grab": Vector2(0.65, 0.060),
	&"release": Vector2(0.50, 0.045),
	&"detent": Vector2(0.65, 0.035),
	&"trigger": Vector2(0.85, 0.055),
	# A ROUND LEAVING THE GUN IN THIS HAND. The strongest short thing here, and never longer than half the gun's own
	# time between rounds -- see `feel_a_round_leave` -- so a held gun is felt as a string of kicks and not as one
	# rumble. Stronger than a detent so a gun and a knob are never the same thing in the hand.
	&"round": Vector2(0.80, 0.030),
	&"reach": Vector2(0.70, 0.200),
	&"unreach": Vector2(0.55, 0.180),
}
## HOW FAR PAST `VehicleControl.REACH` A FREE HAND MAY DRIFT BEFORE IT IS TOLD IT HAS LEFT, in metres, and how much
## nearer a neighbouring control has to be before the hand is told about that one instead.
##
## A tracked hand held still wanders by a few millimetres, and one hardware grip resting on the edge of reach with a single
## radius both ways is a hand that buzzes at the display rate for as long as it rests there. One centimetre is twice the
## wander and a sixteenth of the reach.
const REACH_MARGIN: float = 0.01
## AND NO MORE THAN ONE EDGE A HAND IN THIS LONG, in seconds, as a backstop behind the margin. A reach buzz is 200 ms,
## and a hand flicking in and out faster than that would be one long rumble rather than edges. OpenXR replaces a pulse
## still playing rather than queueing it (`xrApplyHapticFeedback`: the runtime "must interrupt that other event and
## replace it"), so nothing piles up; this is so there is something to feel between two. An edge inside the gap is
## DEFERRED, not dropped: the hand keeps its old answer until the gap is over, so a hand that really did leave is still
## told it has.
const REACH_GAP: float = 0.25

@onready var origin: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var desktop_camera: Camera3D = $XROrigin3D/DesktopCamera
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
## Head-locked, so it moves to whichever camera is current. See _apply_display_mode.
@onready var hud: VehicleHud = $XROrigin3D/VehicleHud

var using_xr: bool = false
var using_desktop: bool = false
## The seat anchor this rig is bolted to, or null before it has been seated.
var seat: Node3D = null

## THE CLIPBOARD IN THE LEFT HAND: the only menu that exists once you are flying. Held
## rather than stood on furniture, brought up with the left controller's menu button, and
## pressed with the right hand -- see `Clipboard`.
var clipboard: Clipboard = null
## A TIME-OF-DAY DIAL WAS TURNED. Announced, not acted on: the level decides, with the call the board's TIME tab lands
## on. See TimeOfDayDial.
signal chose_time(time: int)
## THE CLOCK THE LEVEL LAST HANDED IN, minutes, or -1 on a level with no sky, so a dial put in afterwards shows it too.
## See `show_time`.
var _time_shown: float = -1.0
var _menu_was_down: bool = false
## Whether the mouse has been let go of for the board. Desktop only.
var _pointing: bool = false
## What the clipboard has asked for, held for exactly one input frame. A request left
## standing would be sent on every tick, and the server would answer it every time.
var _kind_asked: int = -1
var _join_asked: int = -1
## Which of their seats, with `_join_asked`: any seat that craft has, or -1 for any free one.
var _join_seat_asked: int = -1
## `Sim.join_answer`'s count when the JOIN now pending was pressed: a different count is the host's answer to it.
var _join_count_at_press: int = 0
## The cabin's shared menu-answer count when the CRAFT request was pressed. A refusal has
## to release the held request immediately and say why; waiting for a vehicle change can
## only represent success.
var _kind_count_at_press: int = 0
## The craft this player was in when the craft now pending was pressed: a different one is the server's answer to it.
var _kind_vehicle_at_press: int = 0
## Frames the menu press now pending has been waiting. See `join_patience_frames`.
var _menu_waited_frames: int = 0

var _xr_interface: XRInterface
var _xr_busy: bool = false
var _vsync_before: int = DisplayServer.VSYNC_ENABLED
var _desktop_size: Vector2i = Vector2i(1600, 900)
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
## Rollbacks this second, and last second's total, for the panel.
## The controls in front of THIS seat, claimed on arrival. See _claim_controls.
## A THROTTLE LEVER OR A COLLECTIVE, depending on what this craft is worked with. Typed
## as the base class for the same reason the stick is: which lever is beside you is the
## cockpit's business, and the rig only ever asks it how far open it is.
var _my_throttle: VehicleControl = null
## A STICK OR A YOKE. Typed as the base class deliberately: which one is in front of you
## is the cockpit's business, and the rig only ever asks it for roll and pitch.
var _my_stick: VehicleControl = null
var _my_button: CrewButton = null
## THE TRIGGER, on the seats that have a gun in front of them. Null everywhere else, which
## is nearly everywhere: see CockpitStation._fit_the_gun.
var _my_trigger: VehicleControl = null
## The nacelle lever on a tiltrotor, and nothing at all on anything else.
var _my_extra: VehicleControl = null

## EVERY CONTROL IN THIS CRAFT A HAND MAY TAKE HOLD OF, and what job each of them does.
##
## Not just this seat's four. Two people in one cockpit reach across it -- to the other
## seat's levers, and to whatever sits on the centre line between them -- and an aeroplane
## where the copilot cannot touch the pilot's throttle is not a cockpit two people share.
##
## THE CRAFT, and only the craft. The set is built from the VehicleView this rig is sitting
## in, so a hand cannot reach through a fuselage into somebody else's aeroplane. That used
## to be what `is_mine` was for; it is structural now, which is better, because a flag can
## be left set and a list of the wrong aeroplane's controls cannot be built by accident.
var _reachable: Array[VehicleControl] = []
## control -> "throttle" | "stick" | "button" | "extra". Which job a control does is decided
## by the station that built it -- see CockpitStation.controls -- so it is read off that
## rather than guessed from the class, and a lever shared by the whole crew keeps the job
## the craft gave it.
var _role_of: Dictionary = {}
## Which craft and seat the controls above were taken from. See _claim_controls.
var _claimed_craft: int = 0
var _claimed_seat: int = -1
## A station with no aircraft behind it, for the hall of cockpits. Null everywhere else.
var _loose_station: CockpitStation = null
## control -> the last value sent for it, so a lever nobody is touching sends nothing.
##
## Per CONTROL and not per channel: two seats have two handles on one channel, and a value
## one of them has already sent must not be sent again by the other.
##
## ONLY FOR A STATION WITH NO CRAFT BEHIND IT now. In a craft, what has been asked is the craft's
## to remember -- see `VehicleView.propose`.
var _sent: Dictionary = {}
## control -> true, for every control a hand on this machine moved since the last send. See
## `_send_what_moved`.
var _moved_here: Dictionary = {}
## Whether the controls are writing their own names. Local to this player -- see
## `name_the_controls` -- and remembered across a change of seat or aircraft.
var _labels_on: bool = false
## WHETHER THE COCKPIT IS BEING BUILT RATHER THAN FLOWN. See `build_the_cockpit`.
var _building: bool = false
## The monitor builder's selected device. Chosen by click or TAB and moved by the
## builder-only key layer before flight bindings see those same keys.
var _desk_build_control: VehicleControl = null
## AND WHETHER, INSIDE THE BUILDER, THE HANDS ARE WORKING THE CONTROLS RATHER THAN MOVING
## THEM. See `try_the_controls`.
var _trying: bool = false
## The station in front of this player, which is what a new control gets bolted to. Null on
## a rig that is not sitting anywhere.
var _my_station: Node3D = null
## Which controls this player works by turning rather than by pushing, by the name they
## write on their own label. See `work_control_by_turning`.
var _turned: Dictionary = {}
## The last grip strengths read, so the controls can be offered hands outside read_controls.
##
## THE EFFECTIVE GRIP AND NOT THE RAW ONE. A latched hand reads 1.0 here whatever the
## finger is doing, which is what makes `_work_the_controls` and every control below it
## need to know nothing at all about latching. See `_grip_of`.
var grip_left: float = 0.0
var grip_right: float = 0.0
## AND THE LAST INDEX FINGERS READ, which is the other way to take hold of something. See
## `_nearest_takeable`, and `VehicleControl.taken_by` for what each finger takes.
##
## KEPT HERE, ON THE PHYSICS CLOCK, RATHER THAN READ WHERE IT IS WANTED. `_work_the_controls`
## runs on the render clock and the grips above are written in `read_controls`, which runs on
## the physics one -- so a pinch read live was a pinch that arrived UP TO A PHYSICS FRAME
## BEFORE the fist beside it. The suite caught it at `--fixed-fps 120` against 60 Hz physics:
## both fingers closed in one breath, and the switch was taken before the grip reading had
## caught up, which is the exact case "the grip wins" exists to settle
## (`tests/pinch.gd`, `and_with_both_fingers_closed_the_grip_wins`). Two readings that decide
## one question have to be taken at the same moment.
var pinch_left: float = 0.0
var pinch_right: float = 0.0
## WHETHER A HAND IS LATCHED ONTO WHAT IT IS HOLDING, per hand.
##
## A quick tap of the grip latches; a second tap lets go. Squeezing and holding still works
## and still releases when the hand relaxes, so nothing anybody already knows stops working
## -- the tap is an addition, and it is there because holding a lever at 300 kph for four
## minutes is a hand cramp, not a skill.
var _latched: Array[bool] = [false, false]
## HOW MANY PULSES HAVE GONE OUT, by reason, with `&"any"` as the total. See `pulse`.
var _pulses: Dictionary = {}
## WHAT THE LAST PULSE OF EACH REASON SENT: amplitude at the motor, after `HAPTIC_MASTER`, then seconds. See `last_pulse`.
var _last_sent: Dictionary = {}
## WHAT EACH HAND COULD TAKE HOLD OF, as it was last told, or null; and when it was last told, on `_reach_clock`. See
## `_notice_reach`.
var _in_reach: Array = [null, null]
var _reach_told_at: Array[float] = [-INF, -INF]
## SECONDS OF THE RIG'S OWN FRAMES, for `REACH_GAP`. Frame time and not the wall clock, so a suite run at `--fixed-fps`
## and a headset agree about how long a gap is: under a fixed rate a sixtieth of a second passes per frame however fast
## the frames really go, and a wall-clock gap would still be open after a suite had waited it out.
var _reach_clock: float = 0.0
## WHAT THE LEGEND WAS LAST BUILT FROM. See `_show_the_legend`.
var _legend_was: String = ""
## A GRIP WITH NO HAND IN IT, per hand, or -1 for "read the hardware". See `force_grip`.
var _forced_grip: Array[float] = [-1.0, -1.0]
## input -> reading, per hand, for inputs held down by something that is not a finger. See
## `force_input`.
var _forced_input: Array[Dictionary] = [{}, {}]
## A HAND POSE WITH NO HAND, per hand, in world space, or null for "wherever it really is".
var _forced_hand: Array = [null, null]
## The pointing hand's beam. Built the first time it is wanted, and moved to whichever hand points. See `_point_a_hand`
## and `HandBeam`, which keeps the pull's press-once state for every glass at once.
var _beam: HandBeam = null
## PANELS THE BEAM MAY POINT AT -- the desk's screens -- alongside whichever boards are up. HANDED TO the rig by the level
## that put them up; the rig never goes looking for panels, for the reason in `Doors`. See `_point_a_hand`.
var pointer_panels: Array[TouchPanel] = []
## Solid world controls that opt into the same desktop/VR pointing seam as panels.  The
## level hands these over explicitly; the rig never searches the scene tree, so another
## craft or room cannot become interactable merely by existing nearby.
var world_pointer_targets: Array[Node] = []
## Left hand, right hand, then desktop mouse.  A held trigger/click is one request, even
## while its authoritative response takes several network ticks to return.
var _world_pointer_was_down: Array[bool] = [false, false, false]
## How long the beam is drawn when it is not on the glass, in metres. Asked of the beam, which owns it.
const BEAM_REACH: float = HandBeam.REACH
## When each hand's grip last closed, on the engine clock, for telling a tap from a squeeze.
var _grip_closed_at: Array[float] = [0.0, 0.0]
## Whether each hand's grip was closed last frame, so the two edges can be found.
var _grip_was_closed: Array[bool] = [false, false]
## A GRIP HELD LONGER THAN THIS IS A SQUEEZE, not a tap. Seconds.
##
## Generous, because a tap through a controller you cannot see is not a mouse click and
## nobody is being timed. Short enough that deliberately holding a lever for a moment is
## never mistaken for a latch.
const TAP_SECONDS: float = 0.35

## Whether each hand's bindable inputs were down last frame, for finding the press.
## hand -> Bind input -> bool, filled in as inputs are first seen. An input not in here has
## never been down, which is what a missing key already means to `get(input, false)`.
var _input_was_down: Array[Dictionary] = [{}, {}]
## Which way the hardware is asking the lever to move, -1 shut to +1 open. A RATE.
var _lever_rate: float = 0.0
## And which way the thumbstick is asking the craft's TRIM to wind. Also a rate. See `_wind_the_trim`.
var _trim_rate: float = 0.0
## Where a thumb has wound the trim to, in notches, while it is held. See `_wind_the_trim`.
var _trim_wound: float = 0.0
## Whether a thumb is winding it now, so the next push starts from the craft and not from here.
var _trim_winding: bool = false
## THE GRID A CONTROL IS PUT DOWN ON while the cockpit is being built. The pilot's own, read from `user://` when the rig
## is made and written back whenever it changes. See PlacingGrid.
var placing_grid: PlacingGrid = PlacingGrid.read()
## SPOTTING SIZE: far aircraft drawn bigger for this player's eye alone. Theirs, read from `user://` when the rig is made
## and written back when the board changes it; never sent. The level draws through it. See Spectacles.
var spectacles: Spectacles = Spectacles.worn()
## The physics frame at which a joystick held over steps the grid again, or -1 while it is not held. See `_step_the_grid`.
var _grid_repeat_at: int = -1
## HOW LONG A HELD JOYSTICK WAITS BEFORE IT REPEATS, and then how often, in seconds. Long enough that a flick is one step;
## short enough that walking from 5 to 90 degrees is four seconds rather than eighteen flicks.
const GRID_REPEAT_AFTER: float = 0.4
const GRID_REPEAT_EVERY: float = 0.25


## A FLICK OF THE JOYSTICK STEPS THE GRID, AND HOLDING IT OVER STEPS IT AGAIN. Up is coarser. Counted on physics frames,
## so a suite at `--fixed-fps` holds the stick for the same number of repeats a player does.
func _step_the_grid(raw: Variant, down: bool, pressed: bool) -> void:
	if not down or not (raw is Vector2):
		_grid_repeat_at = -1
		return
	var now: int = Engine.get_physics_frames()
	var ticks: float = float(Engine.physics_ticks_per_second)
	if pressed:
		_grid_repeat_at = now + int(ceil(GRID_REPEAT_AFTER * ticks))
	elif _grid_repeat_at >= 0 and now >= _grid_repeat_at:
		_grid_repeat_at = now + int(ceil(GRID_REPEAT_EVERY * ticks))
	else:
		return
	# A THUMBSTICK REPORTS +y PUSHED FORWARD, which is up.
	placing_grid.step_by(1 if (raw as Vector2).y > 0.0 else -1)
	_grid_changed()


## THE GRID CHANGED, so it is kept, and the snap board draws it if it is up. Written on every change rather than on
## leaving the builder, because a headset taken off is not a builder left.
func _grid_changed() -> void:
	placing_grid.write()
	if snap_board != null and snap_board.is_up():
		snap_board.show_grid(placing_grid)


## ---- the snap board ----------------------------------------------------------------------------------------------

## THE SNAP BOARD, once one has been asked for: on the hand carrying a control in the builder, worked with the other
## hand's beam, and moved by the other hand taking its edge. See SnapBoard.
var snap_board: SnapBoard = null


## THE TRIGGER OF THE HAND CARRYING A CONTROL: the snap board up on that hand, or away. Up on the other hand already, it
## moves to this one -- ONE board, on whichever hand is working, at the one offset the pilot left it at (mirrored).
func _toggle_the_snap_board(hand: int) -> void:
	if snap_board == null:
		snap_board = SnapBoard.new()
		snap_board.name = "SnapBoard"
		snap_board.chose_rotation_on.connect(_board_turned_rotation)
		snap_board.chose_rotation_step.connect(_board_stepped_rotation)
		snap_board.chose_position_on.connect(_board_turned_position)
		snap_board.chose_position_step.connect(_board_stepped_position)
		snap_board.chose_axis.connect(_board_turned_axis)
		snap_board.chose_stick.connect(_board_chose_stick)
		snap_board.chose_reset_position.connect(_board_reset)
		snap_board.put_down.connect(_board_put_down)
	var pad: Node3D = left_hand if hand == 0 else right_hand
	if snap_board.is_up() and snap_board.working_hand == hand:
		snap_board.show_board(false)
		return
	if snap_board.get_parent() != pad:
		if snap_board.get_parent() != null:
			snap_board.get_parent().remove_child(snap_board)
		pad.add_child(snap_board)
	snap_board.working_hand = hand
	snap_board.transform = placing_grid.board_offset_for(hand)
	snap_board.show_board(true)
	snap_board.show_grid(placing_grid)


## WHAT THE BOARD ASKED FOR, each done to the grid and handed back. The board decides nothing; see SnapBoard.
func _board_turned_rotation(on: bool) -> void:
	placing_grid.rotation_on = on
	_grid_changed()


func _board_stepped_rotation(by: int) -> void:
	placing_grid.step_by_for(PlacingGrid.Quantity.ROTATION, by)
	_grid_changed()


func _board_turned_position(on: bool) -> void:
	placing_grid.position_on = on
	_grid_changed()


func _board_stepped_position(by: int) -> void:
	placing_grid.step_by_for(PlacingGrid.Quantity.POSITION, by)
	_grid_changed()


func _board_turned_axis(axis: int, on: bool) -> void:
	match axis:
		0: placing_grid.on_x = on
		1: placing_grid.on_y = on
		2: placing_grid.on_z = on
	_grid_changed()


func _board_chose_stick(quantity: int) -> void:
	placing_grid.stick_adjusts = quantity as PlacingGrid.Quantity
	_grid_changed()


## RESET POSITION: the default spot, kept, and the board put there now.
func _board_reset() -> void:
	placing_grid.reset_the_board()
	if snap_board != null:
		snap_board.transform = placing_grid.board_offset_for(snap_board.working_hand)
	_grid_changed()


## THE OTHER HAND PUT THE BOARD DOWN HERE: kept (in the right hand's frame, capped), and the board put where the grid now
## says -- so what is drawn is exactly what will reopen.
func _board_put_down(offset: Transform3D) -> void:
	if snap_board == null:
		return
	placing_grid.put_the_board(snap_board.working_hand, offset)
	snap_board.transform = placing_grid.board_offset_for(snap_board.working_hand)
	_grid_changed()

## What this seat is asking for, for the panel.
var _throttle: float = 0.0
var _brake: float = 0.0
## And the rudder it put on the frame, for its own pedals. See `rudder_sent`.
var _rudder: float = 0.0
var _rollbacks: int = 0
var _rollback_rate: int = 0
var _rollback_window: float = 1.0
## Where the vehicle was drawn on the previous rendered frame. See _process.
var _last_drawn: Vector3 = Vector3.ZERO
var _had_last_drawn: bool = false


## STRAIGHT INTO WHICHEVER ONE IT IS, never through the other one on the way.
##
## This used to enter desktop and then immediately enter VR, which on the first rig of a
## run is harmless -- the viewport is mono already, so only the second call changes
## anything. On the SECOND rig it is not: changing scene means the old rig leaves a stereo
## viewport behind, and a new one that turns stereo off and straight back on again is
## asking the renderer to tear down and rebuild the whole XR render target inside one
## frame. It does not survive that. The eye buffers come back with one layer where the
## pass wants two, no framebuffer can be built from them, and every draw call for the rest
## of the run fails on a null one.
##
## Which is why this only ever showed up on the way out of the main menu. Booting straight
## into the world has one rig and one transition.
func _ready() -> void:
	add_to_group("pilot_rig")
	_bind_actions()
	# ON THE LEFT HAND, so it goes where the hand goes and nothing here writes a transform
	# for it. Hidden until somebody asks for it.
	clipboard = Clipboard.new()
	clipboard.name = "Clipboard"
	left_hand.add_child(clipboard)
	clipboard.chose_kind.connect(ask_for_kind)
	clipboard.chose_join.connect(ask_to_join)
	# AND THE WAY BACK OUT. `Doors` and not `Boot`, and not a path written out here either:
	# the first is a CYCLE -- the router reaches the marshalling levels, which preload a
	# scene built from this one -- and the second is a second copy of the door. See Doors.
	clipboard.chose_menu.connect(Doors.to_the_desk)
	clipboard.chose_labels.connect(name_the_controls)
	# THE FINISH IS NOT THE RIG'S. The board announces a flick and the rig hands it to the
	# one place that holds the tier; the board is told what the tier IS whenever it changes,
	# by the key as much as by the switch, so the two can never disagree.
	clipboard.chose_finish.connect(Finish.choose)
	Finish.changed.connect(clipboard.show_finish)
	clipboard.show_finish(Finish.is_fine())
	clipboard.chose_drive.connect(work_control_by_turning)
	clipboard.chose_build.connect(build_the_cockpit)
	clipboard.chose_try.connect(try_the_controls)
	clipboard.chose_part.connect(add_control)
	clipboard.chose_save.connect(save_the_cockpit)
	clipboard.chose_save_package.connect(save_the_package)
	clipboard.chose_load_package.connect(load_the_package)
	clipboard.chose_reset.connect(forget_the_cockpit)
	clipboard.chose_button_labels.connect(label_the_buttons)
	clipboard.show_button_labels(_button_labels_on)
	# AND THE HUD, which starts down every time: the board announces HUD, the rig puts it up or away and shows the
	# board what it did. See `show_the_hud`.
	clipboard.chose_hud.connect(show_the_hud)
	show_the_hud(_hud_on)
	# AND LEVEL HORIZON IN SMALL BOATS, the same shape: the board announces, the rig decides and shows the board.
	clipboard.chose_level_horizon.connect(level_the_horizon)
	level_the_horizon(_level_horizon)
	# AND SPOTTING SIZE, the same shape: the board announces, the rig keeps it and shows the board.
	clipboard.chose_spotting.connect(choose_spotting)
	clipboard.chose_spotting_near.connect(choose_spotting_near)
	clipboard.show_spotting(spectacles)
	# AND RESET HEAD, which is the R key's own call: the board announces, the rig recentres.
	clipboard.chose_recentre.connect(recentre)
	# NOR ARE THE EARS. The same shape as the finish: the board announces GAME SOUND and VOICE, the headphones decide,
	# and the board is told what they decided -- including a voice that could not come on, and why.
	clipboard.chose_game_sound.connect(Headphones.choose_game_sound)
	clipboard.chose_voice.connect(Headphones.choose_voice)
	Headphones.changed.connect(clipboard.show_audio)
	clipboard.show_audio(Headphones.game_sound, Headphones.voice_on(), Headphones.said)
	clipboard.chose_radio.connect(func(text: String): Radio.speak(text))
	Radio.changed.connect(func(words: String): clipboard.show_radio(words, Net.is_host))
	clipboard.show_radio(Radio.status, Net.is_host)
	# AND WHAT HAPPENED AT THE DOOR: a join that ended without getting in is said on the board too, amber, since in a
	# headset the board may be what the player is looking at when the desk says it. See `_heard_at_the_door`.
	Net.logbook.changed.connect(_heard_at_the_door)
	# A SESSION THAT ENDED AGAINST THE PLAYER'S WILL and brought them to the desk is said here as well as on its screen;
	# and the LOG tab starts with what the book already holds.
	if Net.parting_words != "":
		_heard_at_the_door()
	else:
		clipboard.show_log(Net.logbook.rows())
	_fit_the_controller_models()
	if xr_available() and enter_vr():
		return
	_desktop_size = get_viewport().size
	_enter_desktop()


## Bolt this rig into a seat. Called once when the seat is known, and again only if the
## player changes vehicles.
##
## `reparent(false)`: the seat decides where the rig is, not where it happened to be. The
## local transform is IDENTITY and stays that way -- the seat anchor already carries the
## seat's pose, so anything here would be a second offset nobody asked for.
func sit_in(anchor: Node3D) -> void:
	if anchor == null or not is_instance_valid(anchor) or anchor == seat:
		return
	seat = anchor
	if get_parent() != anchor:
		reparent(anchor, false)
	transform = Transform3D.IDENTITY
	origin.transform = Transform3D.IDENTITY
	# SIT DOWN IN IT. See _seat_the_head: deferred because in a headset the tracker has not
	# said where the head is yet on the frame the seat changes.
	_seat_the_head.call_deferred()


func is_seated() -> bool:
	return seat != null and is_instance_valid(seat) and get_parent() == seat


## The vehicle this rig is riding in, found through the scene graph rather than tracked.
## The seat anchor is a child of the view, and the rig is a child of the anchor, so the
## tree already knows -- and a second copy of that fact could disagree with it.
## SIT AT A STATION THAT IS NOT IN ANYTHING, which is what the hall of cockpits is made of.
## Pass null to go back to finding the aircraft through the scene graph.
func take_station(station: CockpitStation) -> void:
	_loose_station = station
	_claimed_seat = -1
	if station != null:
		sit_in(station.get_parent() as Node3D)


## WHETHER THE KEYBOARD IS DRIVING A SEGWAY, and so whether the segway's layer of desk keys applies.
##
## ONE PREDICATE, ASKED BY BOTH ENDS. The rig asks it before letting D strafe, and `FlightLevel` asks
## it before letting D toggle the spotting boxes, so the two cannot disagree about who owns the key
## -- which is the way a key ends up doing both things at once.
##
## Off the SEAT the rig is bolted to, not off a flag set when somebody sat down: a second copy of
## "what am I in" is a second thing to get wrong, which is the reason `vehicle_view` is written the
## way it is.
func reading_a_segway() -> bool:
	var view: VehicleView = vehicle_view()
	return view != null and view.kind == Sim.Kind.SEGWAY


func vehicle_view() -> VehicleView:
	if not is_seated():
		return null
	return seat.get_parent() as VehicleView


## Which seat, as an index. Read off the anchor the rig is bolted to rather than tracked
## alongside it, for the same reason as vehicle_view: a second copy could disagree.
func seat_index() -> int:
	var view: VehicleView = vehicle_view()
	return view.seats.find(seat) if view != null else -1


## ---- what this player is doing ----------------------------------------------

func _physics_process(_delta: float) -> void:
	# THE THROTTLE LEVER FIRST, because `read_controls` at the bottom of this function is what reads it. See
	# `_wind_the_lever`, which is where the whole reason it is on this clock is written down.
	_wind_the_lever(_delta)
	if using_desktop:
		_place_desktop_rig()
	# AFTER the desktop placement and not before it: a forced hand is the last word on
	# where a hand is, and `_place_desktop_rig` welds both of them in front of the panel
	# every physics frame. See `force_hand`.
	_place_forced_hands()
	Sim.set_input(read_controls())
	_update_hud()


## What the player is flying, how fast, and whether the simulation just changed its mind.
##
## On the physics clock rather than the render one: it is text, and sixty rewrites a second
## is already more than anybody can read. The flash is on this clock too, because a
## rollback is a per-tick event.
func _update_hud() -> void:
	# NOTHING AT ALL WHILE THE HUD IS DOWN: no state read, no text rebuilt, no rollback counted. See `show_the_hud`.
	if hud == null or not _hud_on:
		return
	hud_writes += 1
	var view: VehicleView = vehicle_view()
	if view == null or Sim.client == null or not Sim.is_ready:
		hud.show_nothing()
		return
	var drawn: Dictionary = Sim.current.get(view.entity, {})
	var speed: float = (Sim.client.vehicle_state(view.entity).get("velocity", Vector3.ZERO)
		as Vector3).length()

	# YELLOW when the vehicle you are in was rewound and replayed. If the world lurches and
	# the screen goes yellow at the same moment, the lurch is a rollback -- and if it does
	# not, it is not, which is the half of the answer that is hard to get any other way.
	if bool(drawn.get("corrected", false)):
		hud.flash(VehicleHud.ROLLBACK)
		_rollbacks += 1
	_rollback_window -= Sim.tick_dt()
	if _rollback_window <= 0.0:
		_rollback_window = 1.0
		_rollback_rate = _rollbacks
		_rollbacks = 0

	# How far to whatever is taking this vehicle somewhere, which is only ever something
	# when an autopilot has it. The beacon standing on that point is drawn by the level.
	var note: String = "%.0f Hz · %d rollback/s" % [Sim.tick_hz, _rollback_rate]
	# THE WORLD'S EDGE, FIRST: how far there is left, or that the craft is being turned back. See WorldEdge.
	var edge: String = WorldEdge.warning(drawn.get("position", Vector3.ZERO), Sim.edge)
	if edge != "":
		note = edge + "\n" + note
	if bool(drawn.get("has_route", false)):
		note = "WP %.1f km · " % ((drawn.get("route", Vector3.ZERO) as Vector3)
			.distance_to(drawn.get("position", Vector3.ZERO)) / 1000.0) + note
	hud.show_vehicle(view.kind, speed, maxi(seat_index(), 0), view.seats.size(),
		_throttle, _brake, note)


## RED when the picture jumped further in one frame than the vehicle's own speed can
## account for. That is not the network, it is the frame missing its timing, and it wants a
## completely different fix -- which is exactly why it gets a different colour.
##
## On the RENDER clock, because that is the thing being checked.
func _process(delta: float) -> void:
	# THE HORIZON FIRST, so everything this frame reads a head the boat's roll is already off.
	_hold_the_horizon()
	_work_the_clipboard()
	# LET GO OF A FREED STATION BEFORE ANYTHING WALKS IT, as `read_controls` does. `_label_the_controllers` asks every
	# reachable control who holds it, and it runs before `_work_the_controls` gets to notice: a station rebuilt under the
	# rig -- the builder's RESET, `VehicleView.rebuild_station` -- printed "Invalid access to property or key 'held_by' on
	# a base object of type 'previously freed'" once per rebuild. tests/pedals.gd found it, rebuilding the pilot's seat.
	if not _holding_live_nodes():
		_let_go()
	_label_the_controllers(delta)
	_show_the_fingers()
	_work_the_controls(delta)
	_say_whether_i_have_a_lamp()
	var view: VehicleView = vehicle_view()
	# AND THE SIMULATION MAY BE GONE while this level is still standing. `Sim.client` is
	# null between `Sim.stop()` and the next `Sim.start()`, which is every session change
	# and every `Net.leave()` -- and rule 7 at the top of agents.md says it plainly:
	# nothing may read state before `Sim.is_ready`. The line below did, every render frame,
	# and printed "Nonexistent function 'vehicle_state' in base 'Nil'" until the level went
	# away. Nothing had ever left a session with a world up, so nothing had ever seen it.
	if hud == null or not _hud_on or view == null or delta <= 0.0 or Sim.client == null:
		return
	var here: Vector3 = view.global_position
	if _had_last_drawn:
		var speed: float = (Sim.client.vehicle_state(view.entity).get("velocity",
			Vector3.ZERO) as Vector3).length()
		# Two frames of travel in one frame is not a rounding error. The floor keeps a
		# parked vehicle from tripping it on millimetres.
		if _last_drawn.distance_to(here) > maxf(speed * delta * 2.5, 0.25):
			hud.flash(VehicleHud.FRAME_STEP)
	_last_drawn = here
	_had_last_drawn = true


## THIS SEAT'S CONTROLS, AND EVERY OTHER ONE IN THE CRAFT, found the first time I sit in it.
##
## Two lists, because they answer two different questions. `_my_*` is what is in front of
## THIS seat, which is what the frame falls back to and what the keyboard drives.
## `_reachable` is everything a hand may take hold of, which is the whole cockpit.
##
## Nothing here decides who may touch what any more. A hand takes whatever it is nearest
## to and strong enough to hold, and the only thing keeping it out of another aeroplane is
## that this list is built from the craft this rig is sitting in.
func _claim_controls() -> void:
	# A STATION HANDED OVER DIRECTLY, with no aircraft behind it. The hall of cockpits is
	# seats and nothing else -- see world/hall.gd -- so there is no VehicleView to find the
	# controls through, and the whole point of the place is to reach them.
	if _loose_station != null and is_instance_valid(_loose_station):
		var loose: Dictionary = _loose_station.controls()
		if loose.get("stick") == _my_stick and loose.get("throttle") == _my_throttle \
				and loose.get("button") == _my_button and _claimed_seat == -2:
			return
		_claimed_craft = 0
		_claimed_seat = -2
		_take(loose)
		return
	var view: VehicleView = vehicle_view()
	if view == null:
		# NO SEAT, SO NO CONTROLS -- AND SAYING SO IS THE WHOLE POINT.
		#
		# `Sky._reap` stands the rig up and frees the aeroplane in the same breath, and
		# every station goes with it, so from that moment `_my_stick` names a freed node.
		# This used to return with all four still in hand, which was fine until the next
		# `read_controls` passed one to `_reading` -- a freed object does not satisfy a
		# typed VehicleControl argument, and GDScript reports that where the call is
		# rather than where the node was freed.
		_let_go()
		return
	var mine: Dictionary = view.controls_for(seat_index())
	if mine.is_empty():
		# A CRAFT THAT HAS TORN ITS STATIONS DOWN, which `VehicleView.man` does the moment
		# the last person gets out of it. Same freed nodes, same answer.
		_let_go()
		return
	# ALREADY CLAIMED? Asked of the SEAT rather than of the stick.
	#
	# It used to compare the station's stick with the one being held, which is a fine test
	# for a station that has a stick. A control tower has neither stick nor throttle, so
	# both sides were null, the test said "already claimed", and the tower's button and
	# radio were never marked as this player's -- a cockpit you sit in and cannot touch.
	#
	# The controls are still compared as well, because a view that rebuilds its stations
	# hands back different nodes for the same seat and those have to be picked up.
	#
	# WHAT IS HELD MUST STILL BE THERE, asked before the comparison rather than as part of
	# it, because a comparison cannot tell. On the tower above, all three are null on both
	# sides whatever has been freed, so the guard says "already claimed" and keeps a dead
	# `_my_extra` and a `_reachable` full of dead nodes for another frame. Letting go
	# clears the seat, the comparison then fails, and the set is taken again from scratch
	# in this same call.
	if not _holding_live_nodes():
		_let_go()
	if view.entity == _claimed_craft and seat_index() == _claimed_seat \
			and mine.get("stick") == _my_stick \
			and mine.get("throttle") == _my_throttle \
			and mine.get("button") == _my_button:
		return
	_claimed_craft = view.entity
	_claimed_seat = seat_index()
	_take(mine, view)


## PUT EVERYTHING DOWN, because there is nothing left to hold.
##
## The exact opposite of `_take`, and it exists because standing up is not the only way a
## rig stops having controls: the aeroplane can be freed out from under it. `Sky._reap`
## reparents the rig to safety and frees the view, `VehicleView.man` frees the stations of
## a craft everybody has left, and `Sky._forget` frees the lot on a disconnect. None of
## those can reach in here to tidy up, so the rig notices for itself -- the next time it
## looks for its seat and does not find one.
##
## Nulling is not tidiness. A freed node is NOT null: it is a reference to something that
## has gone, so `_my_stick != null` stays true across the free and every guard written that
## way lets a dead node through. Only assigning null actually clears one.
func _let_go() -> void:
	# AND THE KEYBOARD IS OFF THE LEVER. A control dropped while Shift was down would carry `worked_here` forever, and
	# `apply` would never draw the wire on it again -- a lever frozen for everybody watching this seat.
	if _my_throttle != null and is_instance_valid(_my_throttle):
		_my_throttle.worked_here = false
	_my_throttle = null
	_my_stick = null
	_my_button = null
	_my_extra = null
	_my_trigger = null
	_reachable.clear()
	_role_of.clear()
	_sent.clear()
	_in_reach = [null, null]
	_my_station = null
	# So the next station is TAKEN rather than mistaken for the one just let go of. The
	# entity ids come from the simulation and are reused, and seat 0 of the aeroplane that
	# arrives next would otherwise match the seat 0 that has just been freed.
	_claimed_craft = 0
	_claimed_seat = -1


## Whether what this rig thinks it is holding is still actually there.
##
## `is_instance_valid` and not a null check, for the reason in `_let_go`: after the free
## these still point somewhere, and this is the only question that asks whether anything is
## at the other end.
func _holding_live_nodes() -> bool:
	for control in [_my_throttle, _my_stick, _my_button, _my_extra, _my_trigger]:
		if control != null and not is_instance_valid(control):
			return false
	# AND EVERYTHING WITHIN REACH, which can go stale while this seat's own four do not.
	# `VehicleView.man` frees the station of a seat somebody got out of and leaves the
	# rest standing, so the copilot's yoke this rig could reach across to is gone while
	# the pilot's own stick is untouched. Every walk of `_reachable` reads `held_by` off
	# whatever is in it, and a freed node answers that with the same error.
	for control in _reachable:
		if not is_instance_valid(control):
			return false
	return true


## Take a set of controls as this player's own. The half of `_claim_controls` that does not
## care where they came from, so a station on a bench and a station in an aeroplane are the
## same thing from here on.
func _take(mine: Dictionary, view: VehicleView = null) -> void:
	_my_throttle = mine["throttle"]
	_my_stick = mine["stick"]
	_my_button = mine["button"]
	# A FOURTH CONTROL, on the one craft that has one. Null everywhere else, and every
	# place that walks the set has to cope with that rather than assume three.
	_my_extra = mine.get("extra")
	# AND A TRIGGER, on a seat with a gun in front of it. See CockpitStation._fit_the_gun.
	_my_trigger = mine.get("trigger")
	_sent.clear()
	# AND WHAT THEY ARE ALL BOLTED TO, for the builder. `_loose_station` is the hall of
	# cockpits, where a station stands on a bench with no aircraft behind it.
	_my_station = _loose_station if view == null else view.station_for(seat_index())
	_gather_reachable(mine, view)
	# AND THE NEW SET GETS THE LABELS, if they were on. A player who turned them on and then
	# changed seat should not have to turn them on again.
	_label_everything()
	_apply_how_things_are_worked()
	# AND THE BOARD IS TOLD WHAT IS IN FRONT OF THE PLAYER NOW, so its switches are the
	# controls of the cockpit they are actually sitting in.
	if clipboard != null:
		var build_kind: int = view.kind if view != null else (_loose_station.craft_kind if _loose_station != null else -1)
		clipboard.show_allowed_parts(VehicleCatalogue.allowed(build_kind) if build_kind >= 0 else ControlCatalogue.PARTS)
		var named: Array = []
		for control in _reachable:
			named.append(control.label_text())
		named.sort()
		clipboard.show_controls(named)
	# EVERY BUTTON IN THE CRAFT, not just this seat's. A press only ever happens because
	# THIS rig put a hand on it -- other seats' controls are moved by the wire, through
	# `apply`, which emits nothing -- so listening to all of them cannot hear somebody
	# else's press.
	for control in _reachable:
		var button := control as CrewButton
		if button != null and not button.pressed.is_connected(_on_crew_button):
			button.pressed.connect(_on_crew_button)
		# AND EVERY CONTROL IN THE CRAFT, for the same reason: `moved` is a hand HERE working it.
		# See `_send_what_moved`, which is the only reader.
		if not control.moved.is_connected(_on_moved_here):
			control.moved.connect(_on_moved_here)
		# AND EVERY TIME-OF-DAY DIAL, which asks the level through `chose_time` and is shown what the level has on.
		var clock := control as TimeOfDayDial
		if clock != null:
			if not clock.chose_time.is_connected(_on_time_dial):
				clock.chose_time.connect(_on_time_dial)
			clock.show_time(_time_shown)


## Every control in the craft this rig is in, with the job each one does.
##
## Built from every MANNED seat, because that is where the stations are: an empty seat has
## no controls in front of it to reach for. `controls_for` already splices in anything the
## VEHICLE owns rather than a seat -- the airliner's pedestal today, a centre console next
## -- so a shared control arrives here once, on whichever seat is walked first, and the
## `has` check keeps it once.
func _gather_reachable(mine: Dictionary, view: VehicleView) -> void:
	_reachable.clear()
	_role_of.clear()
	var sets: Array[Dictionary] = []
	if view != null:
		for seat in view.manned_seats():
			var here: Dictionary = view.controls_for(int(seat))
			if not here.is_empty():
				sets.append(here)
	# A STATION ON A BENCH, with no aircraft behind it. The hall of cockpits is seats and
	# nothing else, so the set handed in is the whole of what there is to reach.
	if sets.is_empty():
		sets.append(mine)
	_role_of = grabbable_in(sets)
	for node in _role_of.keys():
		# NOT ANOTHER SEAT'S OWN KIT. See `VehicleControl.own_seat_only`: a signal lamp speaks for its seat.
		if view != null and (node as VehicleControl).own_seat_only() \
				and (node as VehicleControl).seat != seat_index():
			_role_of.erase(node)
			continue
		_reachable.append(node)


## EVERY CONTROL IN THOSE SETS THAT A HAND MAY TAKE HOLD OF, as node -> the role it does.
##
## WHATEVER IS IN THE SET, AND NOT A LIST OF WHAT MIGHT BE.
##
## This was a hand-written roll of roles -- throttle, stick, button, extra, flaps, gear,
## drop -- and it went stale the first time a control was added without it being edited.
## That control was the gunner's TRIGGER: a powered mount fits a GunTrigger beside the
## joystick, `controls_for` hands it over under "trigger", and nothing here ever looked at
## that key, so no hand could take hold of it and a gunner in a headset could traverse onto
## a target and not shoot. The desktop never showed it, because a keyboard has no hands and
## asks the gun directly.
##
## A station's set is already a map of role to control, so asking it what it has is both
## shorter and the only version of this that cannot fall behind. Anything that is not a
## control is skipped by the `is`: that covers the RudderIndicator, which is a display
## rather than a handle, and anything in there that is not an object at all.
##
## STATIC, so the rule can be checked without standing a rig up -- a PilotRig wants an XR
## origin and two controllers under it before it will run. See tests/fit.gd, which asks
## this of every craft in the game.
static func grabbable_in(sets: Array[Dictionary]) -> Dictionary:
	var found: Dictionary = {}
	for one in sets:
		for role in one:
			if not (one[role] is VehicleControl):
				continue
			var node: VehicleControl = one[role]
			if found.has(node):
				continue
			found[node] = String(role)
	return found


## EVERY LATCHED CONTROL THAT HAS MOVED, ONTO THE BUS.
##
## A configuration -- flaps, gear, the nacelles -- is not a level to send every tick. It is
## where a lever IS, so it goes as a COMMAND when the lever moves and costs nothing in
## between, which is also what makes it survive a rollback: the sequence on the input frame
## means a replayed frame does not apply it twice.
##
## Walks whatever this rig can reach, so reaching across to the other seat's gear lever
## works exactly as reaching for your own does. This was a hardcoded TiltLever branch; gear
## and flaps would have been two more, and every lever after them another.
##
## Remembered per control rather than per channel, because two seats have two handles on
## one channel and a value that has not moved must not be resent by the other one.
##
## ONLY WHAT A HAND HERE MOVED, AND ONLY WHAT IS THE CRAFT'S. This walked every control in reach and
## sent any whose position differed from what it had last sent -- and `_take` forgets that, so
## taking a seat sent the local position of every wheel and switch in the craft. Changing seat in
## an armed aeroplane disarmed it and wound its trim back to the middle (`tests/shared_controls.gd`,
## once `Sim.send_command` stopped losing all but the last command of a frame, which had hidden it).
## A control that moved says so (`moved`), and a position the craft already shows is not asked for
## again.
func _send_what_moved() -> void:
	var view: VehicleView = vehicle_view()
	for key in _moved_here:
		if not is_instance_valid(key):
			continue
		var control := key as VehicleControl
		if control == null or control.scope != VehicleControl.Scope.CRAFT or control.channel < 0:
			continue
		if view != null:
			DeviceSignalRouter.route(_kind_i_am_in(), control.seat, control, view)
			continue
		# A STATION ON A BENCH, with no craft to ask and nothing to show back. The hall of
		# cockpits sends into nothing, and remembers what it sent so it does not send it twice.
		DeviceSignalRouter.route(_kind_i_am_in(), control.seat, control)
	_moved_here.clear()


## A CONTROL IN REACH MOVED. `moved` is emitted only by a hand working it here -- `apply`, which
## draws the wire, emits nothing -- so this is the list of what this machine has something to say
## about. See `_send_what_moved`.
func _on_moved_here(control: VehicleControl) -> void:
	_moved_here[control] = true


## What this hand already has hold of, or null.
##
## A hand holding a control is offered to nothing else until it lets go. The controls sit on
## one console within arm's reach of each other, so without this a fist closed round the
## stick still pressed whatever it swept across on the way back -- which stops being a
## question of proximity the moment the hand is on something.
func _held_by(hand: int) -> VehicleControl:
	for control in _reachable:
		if control.held_by == hand:
			return control
	return null


## WHAT THIS HAND HAS HOLD OF WITH ITS FIST, or null -- which for a hand pinching a switch is
## null even though the hand is holding something. What the latch is allowed to pin. See
## `_grip_of`, which is the only caller and carries the bug that earned it.
func _in_the_fist(hand: int) -> VehicleControl:
	var held: VehicleControl = _held_by(hand)
	if held == null or held.taken_by() != Bind.Take.GRIP:
		return null
	return held


## The control this rig has hold of that does `role`, or null if neither hand is on one.
##
## What makes reaching across worth anything. A hand on the other seat's throttle has to
## BE the throttle this player is sending, or the lever moves under the hand and the wire
## puts it straight back -- which is what happened before the frame was read from whatever
## is actually held rather than from this seat's four.
func _holding(role: String) -> VehicleControl:
	for control in _reachable:
		if control.held_by >= 0 and String(_role_of.get(control, "")) == role:
			return control
	return null


## The control doing `role` that this rig should READ: whatever it is holding, else the one
## in front of its own seat.
func _reading(role: String, own: VehicleControl) -> VehicleControl:
	var held: VehicleControl = _holding(role)
	return held if held != null else own


## The control whose GRIP is closest to this hand, or null if none is near enough to take.
##
## The grip and not the origin: a stick's is 22 cm up its shaft and a yoke's 17 cm out from
## the mount, and a hand is on the part it closes round.
##
## `taken` narrows it to the parts one finger can take -- see `_nearest_takeable`, which is
## the only caller that passes it. -1 is "anything", which is what the reach cue wants.
func _nearest_to(at: Vector3, taken: int = -1) -> VehicleControl:
	var best: VehicleControl = null
	var closest: float = VehicleControl.REACH
	for control in _reachable:
		if control.held_by >= 0:
			continue
		if taken >= 0 and control.taken_by() != taken:
			continue
		var reach: float = at.distance_to(control.grip_global())
		if reach < closest:
			closest = reach
			best = control
	return best


## ---------------------------------------------------------------------------------
## WHICH FINGER TAKES WHICH CONTROL, AND WHAT HAPPENS WHEN BOTH COULD
## ---------------------------------------------------------------------------------
##
## Asked for on 2026-09-15: "some devices should be grabbable by the grab button, and others
## should use the trigger button, it's more natural to grab joysticks or wheels and 'pinch'
## buttons and switches." Before that day there was one grab for everything -- see `Bind`,
## whose doc block said so -- and a bat switch the size of a fingernail was worked by closing
## a whole fist over it.
##
## THE FINGER THAT IS CLOSING DECIDES WHICH CONTROLS ARE EVEN CANDIDATES, and only then does
## nearest choose between them. A closing trigger can see nothing but pinched parts; a
## closing fist can see nothing but grabbed ones.
##
## THAT IS THE WHOLE OF THE HARD CASE. A hand resting between a stick and a switch is within
## reach of both, and the question "which one" is the reason this is a function rather than a
## filter written inline: the hand has ALREADY SAID which it meant, with the finger it closed,
## and the geometry must not overrule it. The gate measured the old answer -- a fist four
## centimetres from a stick took the switch six centimetres away, because nearest was the only
## question anybody asked (`tests/pinch.gd`, the RED reading).
##
## REJECTED: NEAREST DECIDES AND THE FINGER ONLY SAYS WHETHER TO TAKE IT. That is what the
## code did, and it makes millimetres settle a question a finger has answered. On a console
## where a switch sits two centimetres from a stick's grip it is also unfixable by laying the
## cockpit out differently, which is exactly the arrangement a fighter's left console is.
##
## AND WITH BOTH FINGERS CLOSED, THE GRIP WINS. An index finger RESTS on a trigger and that
## trigger is the brake, the gun and the beam's press besides, so a pull can be incidental; a
## fist is closed on purpose and on nothing else. The deliberate gesture beats the one that
## can happen by accident.
##
## REJECTED FOR THAT CASE: NEAREST OF THE TWO ANSWERS. It reads fairer and it is worse, for
## the reason above -- it would let a resting trigger take a switch away from a hand that was
## deliberately reaching for the stick beside it, and the player would have no way to tell
## why. A rule you can state in one sentence is one you can predict.
##
## NEITHER CLOSED IS "ANYTHING", so a hand hovering still finds the nearest thing it could
## take. Nothing is taken -- `offer_hand` wants `GRAB_ON` before it does anything -- but that
## is the answer a hand about to close is offered.
func _nearest_takeable(at: Vector3, grip: float, pinch: float) -> VehicleControl:
	if grip >= VehicleControl.GRAB_ON:
		return _nearest_to(at, Bind.Take.GRIP)
	if pinch >= VehicleControl.GRAB_ON:
		return _nearest_to(at, Bind.Take.PINCH)
	return _nearest_to(at)


## HOW FAR THIS HAND'S INDEX FINGER IS PULLED, 0 to 1: the pinch, as `grip_left` and
## `grip_right` are the grab.
##
## Read through `_read_input`, which is the one read in the game a forced finger can reach --
## so a suite with no headset pinches a switch the same way a headset does.
func _pinch_of(hand: int) -> float:
	return _reading_of(_read_input(hand, Bind.TRIGGER), -1)


## HOW FAR SHUT THE FINGER THAT TAKES `control` IS, which is the one number `offer_hand`
## wants. See `VehicleControl.taken_by`.
##
## THE LATCH IS THE GRIP'S ALONE and does not follow the pinch here. `_grip_of` exists because
## holding a lever at 300 kph for four minutes is a hand cramp; a pinch is a flick, a press or
## a nudge of a knob, and there is nothing to hold. An index finger latched onto a selector
## would also be an index finger that has stopped being the brake, the gun and the beam --
## with no fist closed to explain why. Rejected on that: uniformity would have cost three
## other jobs the same finger already has.
func _taking_finger(control: VehicleControl, grip: float, pinch: float) -> float:
	return pinch if control.taken_by() == Bind.Take.PINCH else grip


## WORK ONE CONTROL BY TURNING THE WRIST RATHER THAN BY MOVING THE HAND.
##
## Named rather than handed over as a node, because the board has no idea what a cockpit is
## and the set it was shown may have been rebuilt underneath it since -- changing seat, or a
## craft rebuilding its stations. Looking the name up again is what makes a stale board
## harmless instead of a reference to a freed control.
##
## REMEMBERED BY NAME for the same reason `_labels_on` is: a player who set the stick to
## turn and then changed aircraft should find the stick still set that way.
func work_control_by_turning(what: String, rotate: bool) -> void:
	_turned[what] = rotate
	_apply_how_things_are_worked()


func _apply_how_things_are_worked() -> void:
	for control in _reachable:
		if is_instance_valid(control):
			control.driven_by = VehicleControl.Drive.ROTATION 				if bool(_turned.get(control.label_text(), false)) 				else VehicleControl.Drive.TRANSLATION


## ---- building the cockpit rather than flying it --------------------------------------
##
## A cockpit is a set of controls and the places they are bolted to, and until now the
## second half was only ever decided in the Godot editor, in a scene, by somebody looking at
## a viewport from outside. That is the wrong place to decide it from. Whether a lever is
## comfortable is a question about an arm, and the only way to answer it is to sit in the
## seat and reach for the thing.
##
## So: turn BUILD on from the board, and the grab stops working the controls and starts
## moving them. Drag them where you want them, add what is missing, throw out what is not,
## press SAVE, and what comes out is a JSON file of parts and positions -- see CockpitLayout
## -- that can be read, checked, pasted into a conversation, and turned into the scene
## everybody else flies.


## BUILD, OR FLY.
##
## THE HANDS LET GO ON THE WAY IN AND ON THE WAY OUT, which is not tidiness. A hand holding
## the throttle when the builder comes on is a hand that would carry straight on holding it
## in the other sense -- and the first thing it would do is drag the lever to wherever the
## hand happened to be, because that is what picking something up means.
##
## THE LABELS COME ON WITH IT. A cockpit being rearranged is a cockpit where nothing is
## where you last saw it, and the one thing that makes that navigable is every lever saying
## what it is. They go back to whatever the player had chosen when the builder goes off.
func build_the_cockpit(on: bool) -> void:
	if _building == on:
		return
	_building = on
	# AND THE SNAP BOARD GOES WITH THE BUILDER: it is a tool for placing, and a board left on a hand in flight is a board
	# in the way of the flying.
	if not on and snap_board != null:
		snap_board.show_board(false)
	# AND IT ALWAYS OPENS IN MOVE. Leaving the builder in USE from last time would make the
	# switch the first thing anybody has to find, which is the opposite of what it is for.
	_trying = false
	_let_go_of_everything()
	_label_everything()
	if clipboard != null:
		clipboard.say(_what_the_hands_are_doing() if on else "Flying.")
		clipboard.show_building(false)


## MOVE THE CONTROLS, OR WORK THEM -- WITHOUT LEAVING THE BUILDER.
##
## The other half of laying a cockpit out, and the half that cannot be done from outside the
## seat at all. Putting a lever somewhere is a guess; the question is whether your hand
## lands on it without looking, whether your elbow is anywhere, and whether the throw is
## clear of the other lever beside it. None of that is answerable by looking at where the
## thing is. You have to reach out and use it.
##
## SO IT IS A SWITCH AND NOT AN EXIT. The builder stays on -- the labels stay up, SAVE still
## saves this cockpit, and the upper thumb button switches straight back -- because moving a
## lever, trying it, and moving it again is one loop and not three errands.
##
## THE HANDS LET GO ACROSS THE SWITCH, in both directions, for the same reason they do going
## into the builder: a hand holding a lever in one sense would carry on holding it in the
## other, and the first thing it would do is either fly the aeroplane or drag the lever to
## wherever the hand happens to be.
func try_the_controls(on: bool) -> void:
	if not _building or _trying == on:
		return
	_trying = on
	_let_go_of_everything()
	if clipboard != null:
		clipboard.say(_what_the_hands_are_doing())
		# AND THE SWITCH ON THE PAGE FOLLOWS, because the thumb button flips the same mode
		# and a board that disagrees with your hands is worse than a board with no switch.
		clipboard.show_building(_trying)


func _let_go_of_everything() -> void:
	for control in _reachable:
		if is_instance_valid(control):
			control.release()


func _what_the_hands_are_doing() -> String:
	if _trying:
		return "USE: working the controls. Upper thumb goes back to moving them."
	return "MOVE: upper thumb to use them, lower thumb to bin what you hold."


## Whether the cockpit is being built. Read by `_label_everything`, and by the tests.
func building() -> bool:
	return _building


## Whether the hands are WORKING the controls rather than moving them. False outside the
## builder, where the question does not arise -- flying is working them.
func trying() -> bool:
	return _trying


## Whether a grab picks a control up rather than working it, which is the one question the
## hand loop actually asks.
func placing() -> bool:
	return _building and not _trying


## ONE MORE CONTROL, off the board's parts list.
##
## IT ARRIVES IN FRONT OF THE SEAT AND NOT WHERE IT BELONGS, because nothing knows where it
## belongs -- that is the whole question the builder exists to answer. It lands on the
## centreline a hand's breadth above the deck, which is somewhere you can reach without
## leaning and somewhere nothing else already is.
##
## STEPPED SIDEWAYS FOR EACH ONE ALREADY WAITING THERE. Adding three levers in a row and
## finding one lever is the kind of bug that looks like the button not working.
func add_control(part: StringName) -> void:
	if _my_station == null or not is_instance_valid(_my_station):
		if clipboard != null:
			clipboard.say("Sit down first -- a control has to bolt to something.")
		return
	var kind := _kind_i_am_in()
	if kind >= 0 and not VehicleCatalogue.allowed(kind).has(part):
		if clipboard != null:
			clipboard.say("%s is not fitted to this %s." % [ControlCatalogue.label_of(part), Sim.kind_name(kind)])
		return
	# A SIGNAL LAMP GOES IN ITS HOLSTER, AND THERE IS ONE TO A SEAT. See `SignalLamp`, "nowhere, until a player puts
	# one there".
	if part == &"SignalLamp":
		_add_a_lamp()
		return
	var made: VehicleControl = ControlCatalogue.make(part)
	if made == null:
		return
	made.name = _a_free_name(part)
	# PLACED BEFORE IT IS IN THE STATION, or it would stand in its own way.
	var crowded: bool = place_a_new_control(_my_station, made)
	_my_station.add_child(made)
	made.setup(seat_index())
	# AND THE SET IS TAKEN AGAIN, so the thing that was just added is something a hand can
	# reach. `_claim_controls` compares this seat's stick, throttle and button to decide
	# whether anything has changed, and adding a fourth lever changes none of the three --
	# so it is told outright rather than left to notice.
	_claimed_seat = -1
	if clipboard != null:
		if crowded:
			# SAID ON THE BOARD AND NOT WARNED: a full console is a thing a player did, not a fault. ONE LINE, like everything
			# BUILD's answer line says.
			clipboard.say("%s is in, but crowded: no clear place was left. Move it." % ControlCatalogue.label_of(part))
		else:
			clipboard.say("Added %s. Grab it and put it where you want it."
				% ControlCatalogue.label_of(part))
	builder_layout_released.emit()


## THIS SEAT'S SIGNAL LAMP, off the parts bin: in the holster the search finds, clear of every grip in the craft and
## every face the pilot reads, and not in front of the seat where other parts land. A lamp dropped in front of the seat
## would stand over the gauges until somebody moved it, which is the one place `SignalLamp.holster_spot` exists to keep
## it out of. On a bench, with no craft to search, the search runs over this station alone.
func _add_a_lamp() -> void:
	if SignalLamp.in_station(_my_station) != null:
		if clipboard != null:
			clipboard.say("This seat has its signal lamp already. One to a seat.")
		return
	var view: VehicleView = vehicle_view()
	var lamp: SignalLamp = view.holster_a_lamp(seat_index()) if view != null 		and view.station_for(seat_index()) == _my_station else null
	if lamp == null:
		var others: Array[Vector3] = []
		for control_any in _my_station.controls().values():
			var control := control_any as VehicleControl
			if control != null and control.is_inside_tree():
				others.append(_my_station.global_transform.affine_inverse() * control.grip_global())
		lamp = SignalLamp.holster_in(_my_station, seat_index(), others)
	_claimed_seat = -1
	if clipboard != null:
		clipboard.say("Added SIGNAL LAMP, in its holster. Grab it to signal.")
	builder_layout_released.emit()


## TELL THE CRAFT WHETHER THIS SEAT HAS A SIGNAL LAMP, every physics frame, when the wire disagrees. Its channel's
## `FITTED` bit is how every other machine knows to draw one here (`VehicleView._match_lamps_to_the_wire`), and the
## wire can disagree for reasons no single event covers: a lamp just placed, a lamp binned (freed before the frame's
## `_send_what_moved` could say it went dark), a layout applied without one, or the last player in this seat having had
## one. So the rig compares, which covers all of them. `shown_value` counts this machine's unanswered proposal, so a
## proposal is not made twice while it is on its way.
##
## AND WHILE THE BUILDER IS ON, WHEREVER THE LAMP IS PUT IS ITS HOLSTER (`SignalLamp.holster_here`), so the desk's
## recall key puts it back where the player put it and not where the search first found.
func _say_whether_i_have_a_lamp() -> void:
	var view: VehicleView = vehicle_view()
	if view == null or _my_station == null or not is_instance_valid(_my_station) or Sim.client == null:
		return
	var channel: int = SignalLamp.channel_for(seat_index())
	if channel < 0:
		return
	var lamp: SignalLamp = SignalLamp.in_station(_my_station)
	if lamp != null and lamp.is_queued_for_deletion():
		lamp = null
	if lamp != null and placing() and lamp.held_by < 0:
		lamp.holster_here()
	var shown: int = view.shown_value(channel)
	if shown < 0 or SignalLamp.is_fitted_value(shown) == (lamp != null):
		return
	view.propose(channel, lamp.packed() if lamp != null else 0)
	DeviceSignalRouter.forget_channel(channel)


## A NAME NOTHING ELSE IN THIS STATION ANSWERS TO.
##
## The part's own name first -- a station with no throttle gets a node called
## `ThrottleLever`, which is what somebody reading the saved file would hope to see -- and a
## number after it only once there are two. Node names have to be unique among siblings, and
## Godot silently renames a clash, so a layout saved with two `Throttle`s would come back
## with one.
func _a_free_name(part: StringName) -> String:
	var stem: String = String(part)
	if _my_station.get_node_or_null(stem) == null:
		return stem
	var next: int = 2
	while _my_station.get_node_or_null("%s%d" % [stem, next]) != null:
		next += 1
	return "%s%d" % [stem, next]


## WHERE A FRESH CONTROL LANDS, in `station`'s own frame. Static, so tests/station_shot.gd puts a part where the builder
## would.
##
## CLEAR OF THE SCREENS AS WELL AS THE CONTROLS. It stepped clear of other controls only, and every station's flight
## display stands at (-0.02, 1.14, -0.36) with its glass at z -0.354: a part landed at (0, 1.06, -0.34) had its far half
## behind the screen, and a detent dial's stop names with it (2026-09-14). A spot inside a screen's frame, or less than
## `DetentDial.LEGEND_REACH` in front of it, steps towards the seat -- nearer the hand, never further -- before anything
## steps sideways.
##
## AND WITH ITS GRIP OUT OF EVERY OTHER CONTROL'S GRAB, IN NOBODY'S LINE OF SIGHT (2026-09-14). At z -0.25 on the plane
## a new dial's knob sat on the stick's head, its grip inside the stick's grab: a hand for one was a hand on both. So the
## spot is the first, nearest first, where the new part's grip -- turned as it will stand -- is at least
## `VehicleControl.REACH` from every other control's grip, and from a stick's grip at each of the nine places full
## deflection puts it; within `CockpitStation.EASY_REACH` of a shoulder; out of `CockpitStation.KNEES`; clear of every
## screen and crew board by `DetentDial.LEGEND_REACH`; and off every line from the seated eye to a screen's or the crew
## board's face. Two reaches between grabs, with a ball round each control's origin, was tried first and was rejected: the
## plane was crowded from the second part. A step to the side counts twice a step back or up, so a part stays in front of
## the pilot when it can.
const BENCH_ABOVE: float = 0.12
const BENCH_STEP: float = 0.09
## HOW FAR THE SEARCH STEPS UP each time, and how many steps it takes each way: up to 16 cm up, 13.5 cm towards the
## seat and 45 cm to a side -- still under the eye line, and still in front of the seat.
const BENCH_RISE: float = 0.04
const BENCH_TRIES := Vector3i(5, 4, 3)


static func where_a_new_control_lands(station: Node3D, made: VehicleControl = null) -> Vector3:
	var start := Vector3(0.0, CockpitStation.hands() + BENCH_ABOVE, -CockpitStation.HANDS_FORWARD)
	var tries: Array = []
	for back in range(BENCH_TRIES.z + 1):
		for up in range(BENCH_TRIES.y + 1):
			for side in range(-BENCH_TRIES.x, BENCH_TRIES.x + 1):
				tries.append([absi(side) * 2 + back + up, -side, Vector3(float(side) * BENCH_STEP,
					float(up) * BENCH_RISE, float(back) * BENCH_STEP * 0.5)])
	# NEAREST FIRST; where two are as near, the right-hand one, which is where the free hand is while the left holds the board.
	tries.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	# AND IF NOTHING CLEARS EVERY RULE -- a console already full of parts -- the reachable spot, out of the knees, whose
	# grip is furthest outside every other control's grab: somewhere a hand gets to and can move it from. Every try is
	# tried once, so the search ends; `place_a_new_control` says the part is crowded.
	var best: Vector3 = start
	var roomiest: float = -INF
	for one in tries:
		var at: Vector3 = start + (one[2] as Vector3)
		if _a_spot_for_a_new_control(station, at, made):
			return at
		if CockpitStation.from_a_shoulder(at) <= CockpitStation.EASY_REACH and not CockpitStation.KNEES.has_point(at):
			var room: float = _grip_room(station, _its_grip(at, made))
			if room > roomiest:
				roomiest = room
				best = at
	return best


## PUT A FRESH CONTROL WHERE IT LANDS, TURNED AS IT SHOULD STAND, and say whether it had to crowd. Everything that places a
## new part -- the rig's `add_control`, tests/station_shot.gd, the builder suite -- places it through this, so they all put
## it in one place facing one way. Call it before the part is in the station, or it stands in its own way.
##
## A PART THAT IS READ IS TURNED TO FACE THE SEATED EYE, about the vertical and no other way: a dial landed out to one side
## faced straight back along the seat, and its names were 49 degrees off the eye (2026-09-14). A part pushed along an axis
## keeps the seat's forward -- see `VehicleControl.faces_the_eye`.
static func place_a_new_control(station: Node3D, made: VehicleControl) -> bool:
	var at: Vector3 = where_a_new_control_lands(station, made)
	made.position = at
	made.rotation = Vector3(0.0, _turn_towards_the_seat(at, made), 0.0)
	return not _a_spot_for_a_new_control(station, at, made)


## HOW FAR A FRESH CONTROL AT `at` IS TURNED about the vertical: to face the seated eye if it is read, not at all otherwise.
static func _turn_towards_the_seat(at: Vector3, made: VehicleControl) -> float:
	return atan2(-at.x, -at.z) if made != null and made.faces_the_eye() else 0.0


## WHERE A FRESH CONTROL'S GRIP WOULD BE with its origin at `at`, turned as it would stand.
static func _its_grip(at: Vector3, made: VehicleControl) -> Vector3:
	if made == null:
		return at
	return at + Basis(Vector3.UP, _turn_towards_the_seat(at, made)) * made._grab_point()


## EVERY PLACE ANOTHER CONTROL'S GRIP CAN BE, in its parent's frame: where it is, and for a stick each of the nine places its
## full deflection puts it.
static func _grips_of(other: VehicleControl) -> Array[Vector3]:
	var places: Array[Vector3] = [other.transform * other._grab_point()]
	if other is FlightStick:
		for along in [-1.0, 0.0, 1.0]:
			for across in [-1.0, 0.0, 1.0]:
				places.append(other.transform * (Basis(Vector3.RIGHT, along * FlightStick.LEAN)
					* Basis(Vector3.BACK, -across * FlightStick.LEAN) * Vector3(0.0, FlightStick.SHAFT, 0.0)))
	return places


## HOW FAR A GRIP AT `grip` IS OUTSIDE EVERY OTHER CONTROL'S GRAB, in metres: negative where it is inside one.
static func _grip_room(station: Node3D, grip: Vector3) -> float:
	var room: float = INF
	for child in station.get_children():
		var other := child as VehicleControl
		if other == null:
			continue
		for place in _grips_of(other):
			room = minf(room, place.distance_to(grip) - VehicleControl.REACH)
	return room


## WHETHER A FRESH CONTROL MAY STAND AT `at`, in `station`'s frame. See `where_a_new_control_lands`.
static func _a_spot_for_a_new_control(station: Node3D, at: Vector3, made: VehicleControl = null) -> bool:
	if CockpitStation.from_a_shoulder(at) > CockpitStation.EASY_REACH or CockpitStation.KNEES.has_point(at):
		return false
	if _grip_room(station, _its_grip(at, made)) < 0.0:
		return false
	var eye := Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	for child in station.get_children():
		var half: Vector2 = _face_of(child)
		if half == Vector2.ZERO:
			continue
		if _within_room_of(child as Node3D, at, Vector3(half.x, half.y, 0.008)) \
				or _stands_in_the_way(eye, child as Node3D, half, at):
			return false
	return true


## HALF THE SIZE OF A SCREEN'S FACE, frame and all, or of the crew board's; zero for anything else.
static func _face_of(node: Node) -> Vector2:
	if node is TouchPanel:
		return (node as TouchPanel).size * 0.5 + Vector2(0.01, 0.01)
	if node is CrewBoard:
		return CrewBoard.half()
	return Vector2.ZERO


## WHETHER A PART AT `at` STANDS BETWEEN `eye` AND ANY OF A FACE: a ball of `DetentDial.LEGEND_REACH` round the middle of a
## part's height, against the lines to 5 x 5 points across the face. On the plane a dial stood 11 cm in front of the crew
## board, over two of its four rows (2026-09-14).
static func _stands_in_the_way(eye: Vector3, face: Node3D, half: Vector2, at: Vector3) -> bool:
	var middle: Vector3 = at + Vector3(0.0, DetentDial.LEGEND_UP, 0.0)
	for i in range(5):
		for j in range(5):
			var on_face: Vector3 = face.transform * Vector3(lerpf(-half.x, half.x, float(i) / 4.0),
				lerpf(-half.y, half.y, float(j) / 4.0), 0.0)
			var along: Vector3 = on_face - eye
			var t: float = (middle - eye).dot(along) / along.length_squared()
			if t > 0.0 and t < 1.0 and middle.distance_to(eye + along * t) < DetentDial.LEGEND_REACH:
				return true
	return false


## Whether `at`, in the parent's frame, is within `DetentDial.LEGEND_REACH` of a box of half-extents `half` round `node`.
static func _within_room_of(node: Node3D, at: Vector3, half: Vector3) -> bool:
	var local: Vector3 = node.transform.affine_inverse() * at
	var room: float = DetentDial.LEGEND_REACH
	return absf(local.x) < half.x + room and absf(local.y) < half.y + room and absf(local.z) < half.z + room


## TAKE WHATEVER IS IN A HAND OUT OF THE COCKPIT.
##
## Bound to the lower thumb button while the builder is on -- see `_building_bindings`.
##
## ONLY PARTS THE BIN CAN MAKE. A gun, a sight and a multi-function display are fitted from
## facts about the CRAFT rather than chosen, so binning one would be undone by the next
## `fit` -- silently, which is worse than refusing.
func bin_what_is_held() -> void:
	if not _building:
		return
	for hand in range(2):
		var held: VehicleControl = _held_by(hand)
		if held == null or not is_instance_valid(held):
			continue
		if not ControlCatalogue.has(ControlCatalogue.part_of(held)):
			# A GUN, A SIGHT, A DISPLAY. Fitted from facts about the CRAFT rather than
			# chosen, so binning one would be undone by the next `fit` -- silently, which
			# is worse than refusing out loud.
			if clipboard != null:
				clipboard.say("%s is the aircraft's, not yours to move." % held.label_text())
			continue
		bin_the_part(held)


## TAKE ONE PART OUT OF THE COCKPIT: what the builder's lower thumb does to the part in the hand, once
## `bin_what_is_held` has decided it may. Also what `SignalLampHarness` calls to bin a lamp, since a desk has no hand
## to hold one and the game has no desk key for the bin.
func bin_the_part(held: VehicleControl) -> void:
	held.release()
	_reachable.erase(held)
	_role_of.erase(held)
	held.get_parent().remove_child(held)
	held.queue_free()
	_claimed_seat = -1
	if clipboard != null:
		clipboard.say("Binned.")
	builder_layout_released.emit()


## WRITE THIS COCKPIT DOWN. See CockpitLayout for what comes out and why it is JSON.
##
## THE FILE IS SAID OUT LOUD, on the board by its name and in the console as a whole absolute path. `user://` is six
## folders deep inside AppData on Windows and under ~/.local/share on Linux, and a save button whose output you cannot
## find is a save button nobody presses twice. See `saved_line` for why the board says only the name.
func save_the_cockpit() -> void:
	if _my_station == null or not is_instance_valid(_my_station):
		return
	var path: String = CockpitLayout.write(_kind_i_am_in(), seat_index(), _my_station)
	if path.is_empty():
		if clipboard != null:
			clipboard.say("Could not write the layout.")
		return
	var full: String = ProjectSettings.globalize_path(path)
	print("[cockpit] saved the layout to %s" % full)
	if clipboard != null:
		clipboard.say(saved_line(full))

func save_the_package() -> void:
	if _my_station == null or not is_instance_valid(_my_station): return
	var result := CraftPackage.write_station(_kind_i_am_in(), seat_index(), _my_station)
	if clipboard != null: clipboard.say(String(result.get("error", "Saved package %s." % String(result.get("hash", "")).left(12))))

func load_the_package() -> void:
	if _my_station == null or not is_instance_valid(_my_station): return
	var kind := _kind_i_am_in(); var result := CraftPackage.read_station(kind, seat_index())
	if result.has("error"):
		if clipboard != null: clipboard.say(String(result["error"]))
		return
	var file := FileAccess.open(CockpitLayout.path_for(kind, seat_index()), FileAccess.WRITE)
	if file == null:
		if clipboard != null: clipboard.say("Could not install the package.")
		return
	file.store_string(JSON.stringify(result["layout"], "  ")); file.close()
	var view: VehicleView = vehicle_view()
	if view != null: view.rebuild_station(seat_index())
	if clipboard != null: clipboard.say("Loaded package %s." % String(result.get("hash", "")).left(12))


## WHAT THE BOARD SAYS WAS SAVED: the file's name, and not where it is. "Saved to" and the absolute path was 1225 px on
## the board on Windows and longer on Linux -- two lines on BUILD, the fullest page, which a second line leaves 4 px
## from scrolling (2026-09-13) -- and every other thing BUILD says is one line. A `%APPDATA%` shortening fitted on
## Windows and nowhere else, so it was dropped for this, which has no OS in it. The console prints the whole path.
static func saved_line(full: String) -> String:
	return "Saved %s." % full.get_file()


## THROW THE SAVED ONE AWAY and put the cockpit back the way the scene has it.
##
## Not a matter of moving the levers back: a layout is applied while the station is being
## FITTED, so the file has to go and the station has to be built again without it. See
## `VehicleView.rebuild_station`.
func forget_the_cockpit() -> void:
	var kind: int = _kind_i_am_in()
	CockpitLayout.forget(kind, seat_index())
	var view: VehicleView = vehicle_view()
	if view != null:
		view.rebuild_station(seat_index())
	_let_go()
	if clipboard != null:
		clipboard.say("Back to the cockpit the aircraft came with.")


## WHICH CRAFT THIS RIG IS SITTING IN, or -1 on a station standing on a bench. A layout is
## saved per craft and per seat, so this is the half of the key the seat index does not say.
func _kind_i_am_in() -> int:
	var view: VehicleView = vehicle_view()
	return view.kind if view != null else (_loose_station.craft_kind if _loose_station != null else -1)


## WRITE WHAT EVERYTHING IS, or stop.
##
## Every control this rig can reach, which is every control in the craft it is sitting in --
## so a label appears on the copilot's levers and on the console as well as on your own.
## That is the point: the ones you cannot name are the ones on the other side of the
## cockpit.
##
## REMEMBERED, because `_reachable` is rebuilt whenever a station is taken -- changing seat,
## changing aircraft, a craft rebuilding its stations -- and a setting that silently turned
## itself off every time you moved would be one nobody trusted.
func name_the_controls(on: bool) -> void:
	_labels_on = on
	_label_everything()


func _label_everything() -> void:
	# ALWAYS ON WHILE THE COCKPIT IS BEING BUILT. Nothing is where it was a minute ago, and
	# a lever that says what it is, is the difference between rearranging a cockpit and
	# shuffling grey shapes.
	var on: bool = _labels_on or _building
	for control in _reachable:
		if is_instance_valid(control):
			control.show_label(on)


## WHAT THIS RIG HAS HOLD OF, for the tests. Named for what it is rather than dressed up as
## something the game uses: nothing in the game asks, because the rig is the only thing that
## needs to know.
func my_controls_for_the_test() -> Dictionary:
	return {"throttle": _my_throttle, "stick": _my_stick, "button": _my_button,
		"extra": _my_extra} if not _my_controls().is_empty() else {}


## Every control in front of this seat, however many there are.
func _my_controls() -> Array:
	var out: Array = []
	for control in [_my_throttle, _my_stick, _my_button, _my_extra]:
		if control != null:
			out.append(control)
	return out


## A press is a COMMAND, sent once. The bus toggles the light and everybody aboard sees it.
func _on_crew_button(_button: CrewButton) -> void:
	Sim.send_command(Sim.Channel.CREW_TOGGLE, seat_index())


## THE THROTTLE LEVER, WOUND AT A RATE, WHICH IS WHAT MAKES IT LATCH.
##
## An absolute axis cannot latch: release the trigger and it reads zero, so the throttle a hand had just set would shut
## the moment the hand let go of it. Push the thumbstick up to open and down to close, or hold Shift at a desk, and
## leave it alone and the lever stays where it was put -- which is the entire difference between a lever and a spring.
##
## TWO THINGS HERE WERE WRONG AND THEY HID EACH OTHER (measured 2026-09-17, tests/airbase_taxi.gd).
##
## The wind was three lines in `_work_the_controls`, which `_process` calls -- the RENDER clock. `Sky._draw_cockpit`
## is on that clock too, runs later, and hands every seat's lever the cabin's `linked_throttle` through `apply`. So
## every turn the keyboard put into the lever was drawn over before the physics step could read it.
##
## And `apply` refuses a control A HAND IS ON, which at a desk is nothing -- so the wire won every frame. It was not a
## race that the lever sometimes lost: it lost always. With Shift held down for 8,000 frames the lever read exactly
## 0.0000 at every single physics frame and the aeroplane never moved. **A PLAYER AT A KEYBOARD COULD NOT OPEN THE
## THROTTLE ON ANY CRAFT IN THE GAME.** In a headset the hand on the lever made `apply` refuse and none of it could
## happen, and no suite in the project had ever pressed Shift, so nothing had ever looked.
##
## So: wound HERE, on the clock that reads it, and `worked_here` says the key is on it for exactly as long as it is
## down -- the same sentence `held_by` says about a hand. Released, the flag drops and the wire draws the lever again,
## by then agreeing with where the key left it.
func _wind_the_lever(delta: float) -> void:
	if _my_throttle == null or not is_instance_valid(_my_throttle):
		return
	# A HAND BEATS A KEY. In a headset the hand is already driving this lever through `_drag`, and two things winding
	# one lever would double its rate.
	_my_throttle.worked_here = _lever_rate != 0.0 and not _my_throttle.is_held()
	if not _my_throttle.worked_here:
		return
	_my_throttle.value = Vector2(0.0,
		clampf(_my_throttle.value.y + _lever_rate * LEVER_RATE * delta, 0.0, 1.0))
	_my_throttle._redraw()


## OFFER BOTH HANDS TO EVERY CONTROL I OWN, in the control's OWN space.
##
## Seat-local throughout, and that is what makes it work at any speed: the hand pose and
## the control are both children of the same seat anchor, so the aeroplane's motion is not
## a term in the subtraction. A grab at 300 kph is the same arithmetic as a grab on the
## ground.
func _work_the_controls(delta: float) -> void:
	_reach_clock += delta
	_claim_controls()
	# A STATION MAY HAVE NEITHER. A control tower has no stick and no throttle, because a
	# tower does not fly -- it has a radio, a screen and a button, and every one of those is
	# worth sitting at. `_my_controls` returns what is actually there and the loop below
	# copes with a short list; only the spring needs a stick to exist.
	if _reachable.is_empty():
		return
	# THE LEVER IS WOUND ON THE PHYSICS CLOCK NOW, and not here. See `_wind_the_lever`.
	# AND THE TRIM WINDS THE SAME WAY, off the mini joystick of a hand on a column that trims. A rate
	# and not a position, for the reason above: trim is where the elevator STAYS, so letting go of
	# the thumbstick must leave it where it was put. On the bus, as a proposal -- see `_wind_the_trim`.
	_wind_the_trim(delta)
	# ONE HAND, ONE CONTROL. A hand that already has hold of something is BUSY, and is
	# offered to nothing else until it lets go.
	#
	# Without this a fist closed round the stick still pressed whatever it happened to be
	# passing: the controls sit within a few centimetres of each other on one console, so
	# pulling the stick back swept the hand across the crew button and set the cabin light
	# flashing at the tick rate. Which control a hand is on is not a question of proximity
	# once the hand is on one.
	# THE NACELLES GO ON THE BUS, not on the input frame. They are a configuration, so
	# what is sent is a command when the lever moves and not a level every tick -- exactly
	# the flaps and the gear, and for exactly the same reason.
	_send_what_moved()
	# ONE HAND, ONE CONTROL, AND THE NEAREST ONE.
	#
	# A hand is offered to exactly one control a frame: whatever it already holds, or if it
	# holds nothing, the closest thing it could take hold of. Iteration order used to
	# decide -- the first control in the list within reach got the hand, which on a console
	# where two controls are close means the answer depends on which was built first.
	# Nearest is the only answer that is about where the hand actually is.
	for hand in range(2):
		var pose: Node3D = left_hand if hand == 0 else right_hand
		var grip: float = grip_left if hand == 0 else grip_right
		# AND WHAT THE INDEX FINGER IS DOING, which since 2026-09-15 is the other way to take
		# hold of something. Both read on the same clock: see `pinch_left`.
		var pinch: float = pinch_left if hand == 0 else pinch_right
		# THE SNAP BOARD'S EDGE FIRST, for a hand that is holding nothing. A board in a crowded cockpit is in front of
		# levers, and a grip closed on its edge must move the board and not the lever behind it -- so a hand the board
		# takes is offered to no control this frame: one hand, one thing. Measured in the WORKING hand's frame, which
		# is the frame the board is hung in. See SnapBoard.offer_edge.
		if snap_board != null and snap_board.is_up() and _held_by(hand) == null:
			var working: Node3D = left_hand if snap_board.working_hand == 0 else right_hand
			if snap_board.offer_edge(hand, working.global_transform.affine_inverse() * pose.global_transform, grip):
				continue
		var chosen: VehicleControl = _held_by(hand)
		var holding: bool = chosen != null
		if not holding:
			chosen = _nearest_takeable(pose.global_position, grip, pinch)
		# AND WHETHER THAT ANSWER CHANGED, which is a thing to feel. See `_notice_reach`.
		#
		# TOLD ABOUT WHATEVER IS THERE, and not about whatever this frame's finger could take.
		# The cue means "something is within your grasp", which is true of a switch whether or
		# not the hand happens to be squeezing at that instant -- and fed the filtered answer, a
		# fist closing beside a switch would be told the hand had just LEFT something.
		_notice_reach(hand, pose.global_position, holding,
			chosen if holding else _nearest_to(pose.global_position))
		if chosen == null:
			continue
		# BUILDING RATHER THAN FLYING: the hand PICKS THE CONTROL UP instead of working it.
		#
		# Measured in whatever the control is BOLTED TO rather than in the control itself,
		# because the control is the thing that is about to move -- a hand measured against
		# a lever it is dragging never appears to move at all. See
		# `VehicleControl.offer_hand_to_place`.
		#
		# OR THE PART ITSELF SAYS IT IS CARRIED, which since 2026-09-15 one of them does. The
		# director's camera is picked up and moved while FLYING -- that is what framing a shot is,
		# and the builder is a mode you cannot be in while doing anything worth recording. Asked of
		# the part rather than listed here (`VehicleControl.carried_by_hand`), because a roster of
		# which parts are carried is the kind of list that goes stale the first time somebody adds
		# one: `grabbable_in`'s own doc block is about exactly that failure.
		if placing() or chosen.carried_by_hand():
			var bolted: Node3D = chosen.get_parent() as Node3D
			if bolted != null:
				var held_before_placing: bool = chosen.held_by == hand
				# THE BUILDER'S CARRY IS ALWAYS THE GRIP, whatever takes the part in flight. You
				# are not pinching a switch here, you are picking a piece of furniture up and
				# moving it, and that is a whole-hand job on a knob exactly as on a lever. The
				# builder also has the trigger already -- `Bind.nothing()`, or the snap board on
				# a carrying hand -- so a pinched carry would be two jobs on one finger.
				chosen.offer_hand_to_place(hand,
					bolted.global_transform.affine_inverse() * pose.global_transform, grip)
				# AND ONTO THE GRID, if it is on. In the frame the control is bolted in, which is the frame
				# `offer_hand_to_place` just worked in and the frame `CockpitLayout` writes -- so what is drawn is
				# what is saved. Every frame the hand holds it, from the hand's own pose, so rounding never
				# accumulates: the grid is applied to where the hand is, not to where the grid last put it.
				# ONLY WHILE BUILDING. A part carried in flight -- the camera, the signal lamp -- is being aimed, and a
				# lamp whose beam turned in fifteen-degree steps because the grid was left on in the builder would be a
				# lamp that cannot be pointed at a wingman.
				if chosen.held_by == hand and placing():
					chosen.transform = placing_grid.snapped(chosen.transform)
				# This branch continues before the ordinary hand edge below. Observe its own
				# release so the network sees one settled document rather than drag poses.
				if held_before_placing and chosen.held_by != hand and placing():
					felt(hand, &"release")
					builder_layout_released.emit()
			continue
		# THE HAND'S ORIENTATION TOO, because twisting a control column is rudder and a
		# position on its own cannot say how far a wrist has turned.
		var local: Transform3D = chosen.global_transform.affine_inverse() \
			* pose.global_transform
		# TAKING HOLD AND LETTING GO ARE THE TWO EVENTS A HAND SHOULD FEEL, and this is
		# the one place in the game where either happens -- every control is offered a
		# hand from this loop and nowhere else, so there is exactly one edge to find.
		var had: bool = chosen.held_by == hand
		chosen.offer_hand(hand, local.origin, _taking_finger(chosen, grip, pinch), local.basis)
		if (chosen.held_by == hand) != had:
			felt(hand, &"grab" if chosen.held_by == hand else &"release")
			if chosen.held_by == hand:
				_put_the_board_away_for(hand, chosen)
		# AND WHATEVER ELSE THE CONTROL HAS TO SAY. A detent crossed, a trigger pulled:
		# the control ANNOUNCES it and the rig is what owns a motor. Draining it by the
		# reading is the same rule `Sim.cues` follows, and for the same reason -- a bump
		# that stayed set would be felt again every frame the hand stayed on the knob.
		var bump: StringName = chosen.take_bump()
		if bump != &"":
			felt(hand, bump)
	# AND THE SPRING, ONLY WHILE THE WHOLE LINKAGE IS AT REST.
	#
	# A stick, a yoke and a wheel all centre when nobody is holding them, and until the linkage
	# was drawn at this seat that was the only thing that could move them. It is not any more:
	# `FlightLevel._draw_cockpit` puts my own control where the aircraft's controls actually ARE,
	# and a spring running at the same time would drag it back out of the linkage every frame --
	# a wheel reading two thirds of what the other helm is doing, for no reason anybody could see.
	#
	# `VehicleView.hands_on` is the simulation's own answer to "which seat is moving anything".
	# Asked of the linkage rather than of `is_held()`, because the hand that matters may be on
	# another machine -- and because on a desk there are no hands at all and the keys go on the
	# frame, which the linkage carries and `is_held()` never sees.
	if _my_stick != null and _the_linkage_is_at_rest():
		_my_stick.relax(delta)


## WHETHER NOBODY ANYWHERE ABOARD IS ASKING THIS CRAFT FOR ANYTHING. True with no craft at all,
## which is a station on a bench in the hall of cockpits: there is no linkage to be at rest, and a
## stick there must still centre when it is let go.
func _the_linkage_is_at_rest() -> bool:
	var view: VehicleView = vehicle_view()
	return view == null or view.hands_on() == VehicleView.NOBODY_FLYING


## WIND THE CRAFT'S TRIM, at `TRIM_RATE` of its travel a second, while a thumb holds the mini joystick over.
##
## THE CRAFT'S TRIM AND NOT A WHEEL. This wound `_reading("trim", null)` -- the trim wheel a hand here was HOLDING -- and
## then skipped it for being held, so a thumb on the stick trimmed nothing: sixty frames of the joystick held back left
## the craft at 128 (`tests/shared_controls.gd`). Nor could it be seen headless, because the desk threw away what a
## forced finger asked for.
##
## So the thumb winds the channel. It starts from where the craft is SHOWN -- this machine's unanswered ask included --
## and keeps the fraction here while the thumb is held, because a channel counts whole notches and one frame of winding
## is a small part of one. Every whole notch is proposed; the craft decides; every wheel aboard draws what it decided.
## Let go of the thumbstick and the next push starts from the craft again.
func _wind_the_trim(delta: float) -> void:
	var view: VehicleView = vehicle_view()
	var top: int = view.channel_range(Sim.Channel.TRIM) if view != null else 0
	if _trim_rate == 0.0 or top <= 0:
		_trim_winding = false
		return
	var shown: int = view.shown_value(Sim.Channel.TRIM)
	if not _trim_winding:
		_trim_wound = float(shown)
		_trim_winding = true
	# PUSHED FORWARD IS NOSE DOWN: a thumbstick reports +y forward, so the rate is taken off.
	_trim_wound = clampf(_trim_wound - _trim_rate * TRIM_RATE * float(top) * delta, 0.0, float(top))
	var asked: int = int(round(_trim_wound))
	if asked != shown:
		view.propose(Sim.Channel.TRIM, asked)


## GO AND FIND ME ONE OF THOSE. The same request the function keys make, from a menu press.
##
## A MENU PRESS: `Sim.menu_request` moves on by one and stays on every frame, and the kind rides beside it until this
## player's craft changes -- the server's answer to a kind -- or the patience runs out, when the board says so. Refused,
## with a word on the board, while another menu press is still waiting: see `ask_to_join`. Returns whether it was taken.
func ask_for_kind(kind: int) -> bool:
	if _menu_pending():
		if clipboard != null:
			clipboard.show_still_waiting()
		return false
	_kind_asked = kind
	_kind_vehicle_at_press = my_vehicle()
	_kind_count_at_press = int(Sim.join_answer.get("count", 0))
	_menu_waited_frames = 0
	Sim.next_menu_request()
	return true


## THE CRAFT THIS PLAYER IS IN, as this machine was last told: the entity `Sim.pilots` gives this client, or 0.
func my_vehicle() -> int:
	var me: int = Sim.local_client_id()
	for state in Sim.pilots:
		if int((state as Dictionary).get("client", -1)) == me:
			return int((state as Dictionary).get("vehicle", 0))
	return 0


## Whether a JOIN or a craft pressed on the clipboard is still waiting for the server to show its answer.
func _menu_pending() -> bool:
	return _join_asked >= 0 or _kind_asked >= 0


## WHETHER THE SERVER HAS SHOWN ITS ANSWER TO THE CRAFT NOW PENDING: this player in a different craft from the one they
## were in when they pressed -- or, pressed before this machine knew their craft at all, in a craft of the kind asked.
## Not "any craft": the pilot's first pod replicating in after a press made at level load is not an answer, and letting
## the kind go then could leave the server, which reads the kind off the frame that carries the new number, with none.
func _kind_press_answered() -> bool:
	var now: int = my_vehicle()
	if now == 0 or now == _kind_vehicle_at_press:
		return false
	if _kind_vehicle_at_press != 0:
		return true
	return int((Sim.current.get(now, {}) as Dictionary).get("kind", -1)) == _kind_asked


## SIT WITH THAT PLAYER, by client id, in that seat of theirs (any it has) or the first free one (-1).
##
## A MENU PRESS, AND ITS NUMBER IS WHAT REACHES THE SERVER. `Sim.menu_request` moves on by one and stays on every input frame;
## the server acts when it changes (`ControlInput::menu_request`), and the player and seat ride beside it until
## `Sim.join_answer`'s count moves or the patience runs out, when the board says the host did not answer. It was a button
## edge, held for one frame and then until answered, and the server skips frames that arrive late together: an edge
## on a skipped frame, or the let-up before a second press, was lost -- tests/crew_peers.gd went unanswered 2 runs in 7
## with one frame and 1 in 34 held. A number is on whichever frame the server applies next.
##
## ONE MENU PRESS AT A TIME, AND THAT IS THE WRAPAROUND'S LIMIT. Three bits wrap after eight presses, so eight between two
## frames the server applies would look like none. While a JOIN or a craft is waiting, another menu press is refused and
## the board says so; a press waits at most the patience, so the number moves at most once a patience window.
func ask_to_join(client: int, seat: int = -1) -> bool:
	if _menu_pending():
		if clipboard != null:
			clipboard.show_still_waiting()
		return false
	_join_asked = client
	_join_seat_asked = seat
	_menu_waited_frames = 0
	_join_count_at_press = int(Sim.join_answer.get("count", 0))
	Sim.next_menu_request()
	return true


## FRAMES A JOIN IS HELD WITH NO ANSWER: the time `Net` gives a connection to the host to open (`Net.patience`'s
## "connect"), on the physics clock the frames are read on. Not a number of its own: a host that cannot answer a press in
## the time a connection to it is allowed is a host that is not answering, and a test that shortens the one shortens both.
## A player whose craft has gone holds no cabin, reads no answer, and must not be left with the button down for ever.
func join_patience_frames() -> int:
	var seconds: float = float(Net.patience.get("connect", Net.PATIENCE["connect"]))
	return maxi(1, roundi(seconds * float(Engine.physics_ticks_per_second)))


## THE CLIPBOARD, UP OR AWAY. One button, both ways, and it is local: a menu is not
## something the wire has an opinion about.
func toggle_clipboard() -> void:
	if clipboard != null:
		clipboard.toggle()


## A HAND THAT TAKES HOLD OF SOMETHING PUTS THE BOARD AWAY.
##
## Reaching for a lever with the board up means the reading is over. Left up, the board would
## go on owning the fingers -- `_bindings_for` lays it over everything while it is up -- so the
## hand would be on the throttle with its thumb scrolling a menu and its trigger pressing
## whatever was highlighted, which is a lever that has stopped working for no reason anybody
## could see.
##
## PUTTING IT AWAY IS THE WHOLE OF THE HANDOVER. The fingers are looked up afresh every frame
## from what the hand holds and whether the board is up, so once it is down the control's own
## table is what they read -- nothing to unbind and nothing to remember to rebind.
##
## AND A BUTTON ALREADY DOWN DOES NOT FIRE ON THE CONTROL. A press is the input going down
## (`_input_was_down`), and a thumb that was held while scrolling is still down when the table
## changes under it, so the control's action for that thumb waits for the next real press.
##
## Either hand, the one holding the board included: a left hand that lets go of the board to
## take the collective has put the board down.
func _put_the_board_away_for(hand: int, control: VehicleControl) -> void:
	if clipboard == null or not clipboard.is_up():
		return
	clipboard.show_board(false)
	print("[clipboard] away: the %s hand took hold of %s" % [
		"left" if hand == 0 else "right", control.control_name])


## THE MENU BUTTON, AND THE FINGER.
##
## Both read here rather than off the input frame, because a menu is LOCAL: nothing about
## which page somebody is looking at belongs on a wire, and the hall of cockpits already
## reads this button the same way for the same reason.
##
## Edge-detected, because holding the button down is one press and not ninety.
func _work_the_clipboard() -> void:
	if clipboard == null:
		return
	# EITHER HAND, AND ALWAYS THIS. The menu button is one of the two inputs no control may
	# bind -- see `Bind` -- because a menu button that opened the menu only sometimes is a
	# menu button people press twice. It used to be read off the left hand alone, so a
	# player whose left hand was busy on a collective had to let go of the helicopter to
	# read anything.
	#
	# WHICH HANDS ACTUALLY HAVE ONE IS THE CONTROLLER'S BUSINESS and not this rig's. On
	# Touch the action map can only reach the left one: a Quest's right controller has no
	# menu button, only the system button, and the runtime keeps that for itself. So this
	# asks both and takes whichever answers, which is right on the controllers that have
	# two and costs nothing on the ones that do not.
	var down: bool = false
	if using_xr:
		for pad in [left_hand, right_hand]:
			if pad != null and pad.is_button_pressed(&"menu_button"):
				down = true
	elif using_desktop:
		# NOT WHILE SOMEBODY IS TYPING INTO A PANEL (CLAUDE.md, rule 9). Measured 2026-09-14 in tests/code_pad.gd: with
		# nothing asking, the M in a join code typed on a desk raised the clipboard over the keypad.
		down = Input.is_key_pressed(KEY_M) and not TouchPanel.is_typing()
	if down and not _menu_was_down:
		clipboard.toggle()
	_menu_was_down = down
	# THE RIGHT HAND, AND ONLY THE RIGHT HAND. The left one is holding the thing, and a
	# panel in a hand that also has to press it is a panel nobody can press.
	if clipboard.is_up() and using_xr and right_hand != null:
		clipboard.offer_finger(right_hand.global_position)
	# AND A POINTER while a board is up, out of whichever hand works it, to see what a press will land on.
	_point_a_hand()
	# ON A MONITOR THERE IS NO HAND TO REACH WITH: both of them are welded in front of the
	# face, and neither can arrive at a board held in the other. So the mouse points at it,
	# and the mouse has to be let go of to do that -- looking around and pressing buttons
	# cannot both have the cursor.
	if using_desktop:
		_point_the_mouse()
	_show_the_legend()


## THE CONTROLLERS IN YOUR HANDS, drawn as controllers in place of the balls that were there, with what each finger
## does written beside it. Asked for on 2026-09-13. See `ControllerModel`, which draws a table and never decides one.
var _controllers: Array[ControllerModel] = [null, null]
## What the labels were last written from, and how long until they are written again regardless. See
## `_label_the_controllers`.
var _labelled_from: String = ""
var _labels_due: float = 0.0
## WHETHER THE CONTROLLERS SAY WHAT EACH FINGER DOES, the clipboard's BUTTON LABELS switch. On until turned off, and
## remembered here like `_labels_on`, so moving seat or craft does not quietly turn it back on or off.
var _button_labels_on: bool = true
## How often the labels are rewritten when nothing they watch has changed, in seconds: a control may rewrite its own
## table without anybody changing hands -- a seat fitted for missiles after the hand closed on its stick.
const LABELS_EVERY: float = 0.5


## THE BUTTON LABELS SWITCH, flicked. Pilot-local: nothing is sent, and nobody else's controllers change.
func label_the_buttons(on: bool) -> void:
	_button_labels_on = on
	_labels_due = 0.0


## WHETHER THE HEAD-LOCKED HUD IS UP: the clipboard's HUD switch. DOWN every start, on a headset and a desk alike. Asked
## for on 2026-09-14: "turn off the hud that shows up connected to the head (we need a toggle in the ipad to turn it back
## on)". Yours alone, like BUTTON LABELS: nothing is sent. Down is hidden AND unwritten -- `_update_hud` and the
## frame-step check in `_process` return first -- because a HUD only made invisible would still ask the simulation for
## the vehicle and rebuild its text every tick.
## LEVEL HORIZON IN SMALL BOATS (C1, 2026-09-15). The wind-sea rolls and pitches a launch and a patrol boat, and a seated
## player sees that motion without feeling it, which is what makes a seated player sick. On, the rig takes the boat's
## roll and pitch off itself about the seat and keeps its heading, so the horizon stays level and the boat moves about
## you. Off unless chosen: a player who is fine wants to see the sea move the boat. Per player and never sent, like HUD.
## THE HANDS GO WITH IT: they are tracked in the rig's space, so a console rolling a few degrees moves a few centimetres
## under a held hand. Only in small boats: a carrier or a battleship leans under two degrees, and an aircraft's attitude
## is what its pilot flies by.
var _level_horizon: bool = false


## LEVEL HORIZON FLICKED: remember it and show the board what was decided.
func level_the_horizon(on: bool) -> void:
	_level_horizon = on
	if clipboard != null:
		clipboard.show_level_horizon(on)


## Whether this player keeps the horizon level in small boats.
func levels_the_horizon() -> bool:
	return _level_horizon


## The kinds LEVEL HORIZON holds level: the boats a player sits in that the wind-sea visibly rolls.
static func is_small_boat(kind: int) -> bool:
	return kind == Sim.Kind.BOAT or kind == Sim.Kind.GUNBOAT or kind == Sim.Kind.CB90


## THE RIG'S BASIS UNDER A SEAT ANCHOR whose global basis is `anchor`: the identity unless `on` in a small boat, and
## otherwise the turn that undoes the anchor's roll and pitch and keeps its heading -- the rig then looks along the
## anchor's forward laid flat, with the world's up.
static func level_basis(anchor: Basis, kind: int, on: bool) -> Basis:
	if not on or not is_small_boat(kind):
		return Basis.IDENTITY
	var ahead: Vector3 = -anchor.z
	ahead.y = 0.0
	if ahead.length_squared() < 0.000001:
		return Basis.IDENTITY
	var level := Basis.looking_at(ahead.normalized(), Vector3.UP)
	return (anchor.orthonormalized().inverse() * level).orthonormalized()


## EVERY RENDER FRAME, after the level has placed the craft (`VehicleView.draw`, in the sky's `_process`, which runs
## before this rig's, a descendant of the craft): the rig's basis under its seat, level or not.
func _hold_the_horizon() -> void:
	if not is_seated():
		return
	var view := seat.get_parent() as VehicleView
	var wanted: Basis = level_basis(seat.global_basis, view.kind if view != null else -1, _level_horizon)
	if not transform.basis.is_equal_approx(wanted):
		transform.basis = wanted


var _hud_on: bool = false
## HOW MANY TIMES THE HUD HAS BEEN WRITTEN. For the tests: while it is down, this does not move.
var hud_writes: int = 0


## THE HUD SWITCH, flicked: up or away. The rig decides, and the board is shown what it decided.
func show_the_hud(on: bool) -> void:
	_hud_on = on
	# AND NO RED FLASH FOR THE DISTANCE FLOWN WHILE IT WAS DOWN: the frame-step check measures from the last frame it saw.
	_had_last_drawn = false
	if hud != null:
		hud.visible = on
		if not on:
			hud.clear_flash()
	if clipboard != null:
		clipboard.show_hud(on)


## SPOTTING SIZE, chosen on the board: a strength (`Spectacles.Strength`), kept, and shown back.
func choose_spotting(strength: int) -> void:
	spectacles.strength = clampi(strength, Spectacles.Strength.OFF, Spectacles.Strength.HIGH)
	spectacles.write()
	if clipboard != null:
		clipboard.show_spotting(spectacles)


## AND THE DISTANCE INSIDE WHICH EVERY AIRCRAFT IS ITS TRUE SIZE, metres: one of `Spectacles.NEAR_STEPS`.
func choose_spotting_near(metres: float) -> void:
	spectacles.near_m = metres if Spectacles.NEAR_STEPS.has(metres) else Spectacles.DEFAULT_NEAR
	spectacles.write()
	if clipboard != null:
		clipboard.show_spotting(spectacles)


## Whether the HUD is up. See `show_the_hud`.
func hud_is_on() -> bool:
	return _hud_on


func _on_time_dial(time: int) -> void:
	chose_time.emit(time)


## THE TIME OF DAY THE LEVEL HAS ON, handed in on every change: to the board's TIME tab, and to every time-of-day dial
## on this station, in reach of a hand or not. One call, so the tab and the knob are never told different things.
func show_time(time: float) -> void:
	_time_shown = time
	if clipboard != null:
		clipboard.show_time(time)
	if _my_station == null or not is_instance_valid(_my_station):
		return
	for child in _my_station.get_children():
		var clock := child as TimeOfDayDial
		if clock != null:
			clock.show_time(time)


## THE CONNECTION LOG CHANGED: this machine's own knock ended without getting in -- refused, given up on, or the host
## gone -- and the board says why, amber, in the words the desk says. Announce, don't act: `Net` wrote the row and the
## board only draws it. A host's rows about OTHER people's knocks are not news for its board's answer line.
const DOOR_ENDINGS: Array[String] = ["REFUSED", "TIMED_OUT", "DROPPED", "PARTED"]


func _heard_at_the_door() -> void:
	if clipboard == null:
		return
	var rows: Array[Dictionary] = Net.logbook.rows()
	# THE LOG TAB, whatever the row: the page is handed the whole book and draws it.
	clipboard.show_log(rows)
	if rows.is_empty():
		return
	var newest: Dictionary = rows[0]
	if String(newest.get("side", "")) == "client" and String(newest.get("event", "")) in DOOR_ENDINGS:
		clipboard.say_no(String(newest.get("words", "")))


func _fit_the_controller_models() -> void:
	for side in range(2):
		var pad: XRController3D = left_hand if side == 0 else right_hand
		if pad == null:
			continue
		var ball := pad.get_node_or_null("Mesh") as MeshInstance3D
		if ball != null:
			ball.visible = false
		var model := ControllerModel.new()
		model.name = "Controller"
		model.hand = side
		# THE SQUEEZE THAT TAKES HOLD is the squeeze the grip button shows closed at. See `ControllerModel.show_input`.
		model.grip_closes_at = VehicleControl.GRAB_ON
		pad.add_child(model)
		_controllers[side] = model


## WHAT EVERY FINGER DOES, ONTO THE CONTROLLERS. Rewritten when something that changes a binding has changed -- which
## control each hand holds, the builder and its try-it mode, the board -- the same things `_show_the_legend` watches,
## and every `LABELS_EVERY` regardless. Written while a hand holds something or the board is up, and not otherwise: an
## empty hand in flight is a plain controller.
func _label_the_controllers(delta: float) -> void:
	var board_up: bool = clipboard != null and clipboard.is_up()
	var now: String = "%s|%s|%s|%s|%s|%s" % [_held_by(0), _held_by(1), _building, _trying, board_up, _button_labels_on]
	_labels_due -= delta
	if now == _labelled_from and _labels_due > 0.0:
		return
	_labelled_from = now
	_labels_due = LABELS_EVERY
	for side in range(2):
		var model: ControllerModel = _controllers[side]
		if model != null and is_instance_valid(model):
			var view: VehicleView = vehicle_view()
			model.show_bindings(_bindings_for(side),
				_button_labels_on and (_held_by(side) != null or board_up),
				view.channel_names() if view != null else {})


## WHAT EVERY FINGER IS DOING, ONTO THE CONTROLLERS, every render frame. Read through `_read_input` -- the one read the
## bindings act on, a forced finger included -- for all five inputs whether bound or not, because a button that does
## nothing in this hand is still a button somebody pressed. The grip is `grip_left` / `grip_right` as `read_controls` left
## them, latch and all: a latched hand is holding on, and shows it. The model writes only what changed.
func _show_the_fingers() -> void:
	for side in range(2):
		var model: ControllerModel = _controllers[side]
		if model == null or not is_instance_valid(model):
			continue
		var stick: Variant = _read_input(side, Bind.STICK)
		model.show_input(_reading_of(_read_input(side, Bind.TRIGGER), -1), grip_left if side == 0 else grip_right,
			_is_down(_read_input(side, Bind.THUMB_HIGH)), _is_down(_read_input(side, Bind.THUMB_LOW)),
			stick as Vector2 if stick is Vector2 else Vector2.ZERO, _is_down(_read_input(side, Bind.STICK_CLICK)))


## What the controller in `hand` is, for the tests and the screenshots.
func controller_model(hand: int) -> ControllerModel:
	return _controllers[hand]


## WHAT EVERY FINGER DOES, ONTO THE BOARD, while the board is up.
##
## ONLY WHEN SOMETHING HAS CHANGED, and the something is small: which control each hand is
## holding, and whether the builder or its try-it mode is on. Those are the only four things
## `_bindings_for` reads, so anything else moving cannot change a single row -- and building
## fifty-odd rows of strings on every render frame for a page that is usually not even the
## one on show is the kind of per-frame garbage this project has already had to go and find
## once, in the renderer.
func _show_the_legend() -> void:
	if not clipboard.is_up():
		return
	var now: String = "%s|%s|%s|%s" % [_held_by(0), _held_by(1), _building, _trying]
	if now == _legend_was:
		return
	_legend_was = now
	clipboard.show_help(legend())


## The desk mouse's pointer: which glass it is on, and one click per press. See `GlassPointer`.
var _mouse_pointer: GlassPointer = GlassPointer.new()


## THE MOUSE, WHILE THERE IS GLASS TO POINT AT: the clipboard or the snap board while one is up, and the panels the
## level handed over (the desk's two screens). Released so it can be aimed, and taken back when there is nothing left to
## point at, which is the same trade every game with a menu in it makes.
##
## IT WAS THE CLIPBOARD ALONE until 2026-09-14, through `Clipboard.offer_pointer`, so on a monitor nothing on the desk
## could be clicked -- found while building the join code's keypad, which a desk types into. tests/desk_screens.gd drives
## it with real mouse events in window coordinates, and before this both of its clicks pressed nothing. Every glass now
## goes to one `GlassPointer`, which takes the nearest along the ray from the eye through the cursor, as a hand's beam does.
func _point_the_mouse() -> void:
	if desktop_camera == null:
		return
	var at: Vector2 = desktop_camera.get_viewport().get_mouse_position()
	var world_active := _point_world_targets(2, desktop_camera.project_ray_origin(at),
		desktop_camera.project_ray_normal(at), Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if world_active:
		_mouse_pointer.let_go()
		if not _pointing:
			_pointing = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	var glasses: Array[TouchPanel] = []
	if clipboard != null and clipboard.is_up():
		glasses.append(clipboard.panel())
	if snap_board != null and snap_board.is_up():
		glasses.append(snap_board.panel())
	glasses.append_array(pointer_panels)
	if glasses.is_empty():
		_mouse_pointer.let_go()
		if _pointing:
			_pointing = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if not _pointing:
		_pointing = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_pointer.point(desktop_camera.project_ray_origin(at), desktop_camera.project_ray_normal(at),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), glasses)


## A HAND'S POINTER, while a board is up or a level has handed over panels. Asked for on 2026-09-12: the board was hard to
## use without seeing what a press would land on. A thin beam out of the front of the pointing controller, drawn as far
## as the glass when it meets it and `BEAM_REACH` when it does not; the glass hovers and marks what it is on, and that
## hand's trigger presses there.
##
## EVERY GLASS AT ONCE, and the beam aims the first one along the ray (`HandBeam.point`). Until 2026-09-14 this aimed a
## board ALONE while one was up, so with the clipboard out the desk's monitors could not be pointed at -- "make sure the
## monitor screens on the opening main menu level allow for pointing and clicking like the ipad" -- and each board kept
## its own press-once state. While the beam is on any glass the clipboard's "press what is highlighted" is held off, or
## a pull on a monitor with the board up would press two things.
##
## WHICH HAND POINTS was always the right, and became a question on 2026-09-13 with the snap board, which rides on
## whichever hand is carrying a control -- a board on the right hand cannot be pointed at from the right. So: the
## clipboard is held in the left and worked from the right, and wins while it is up; otherwise a snap board is worked
## from the hand it is NOT on; otherwise the right, as before, for the panels a level hands over. The beam moves to the
## pointing hand. It was named for the right hand until then.
##
## In a headset, and on a desk only when a test has put the pointing hand somewhere with `force_hand` -- a desk's hands
## are welded in front of the face and point at nothing, and the mouse is its pointer.
func _point_a_hand() -> void:
	var board_up: bool = clipboard != null and clipboard.is_up()
	var snap_up: bool = snap_board != null and snap_board.is_up()
	var hand: int = 1
	if not board_up and snap_up:
		hand = 1 - snap_board.working_hand
	var pad: XRController3D = left_hand if hand == 0 else right_hand
	var aiming: bool = ((board_up or snap_up or not pointer_panels.is_empty() or not world_pointer_targets.is_empty()) and pad != null
		and (using_xr or _forced_hand[hand] is Transform3D))
	# AND A HAND WITH A PINCHED CONTROL UNDER IT IS REACHING, NOT POINTING. See
	# `_reaching_for_a_pinch`, which is the whole of the rule and carries why.
	if aiming and _reaching_for_a_pinch(hand, pad.global_position):
		aiming = false
	if not aiming:
		_clear_world_pointer_hover()
		if _beam != null:
			_beam.put_away()
		if clipboard != null:
			clipboard.beam_on_glass(false)
		return
	if _beam == null:
		_beam = HandBeam.new()
	if _beam.get_parent() != pad:
		if _beam.get_parent() != null:
			_beam.get_parent().remove_child(_beam)
		pad.add_child(_beam)
	var from: Vector3 = pad.global_position
	var along: Vector3 = -pad.global_basis.z.normalized()
	var pulled: bool = float(_read_input(hand, Bind.TRIGGER)) > 0.5
	if _point_world_targets(hand, from, along, pulled):
		if _beam != null:
			_beam.put_away()
		if clipboard != null:
			clipboard.beam_on_glass(false)
		return
	# EVERY GLASS THAT IS UP -- the board in your hand, the snap board, the panels the level handed over -- and the beam
	# decides which its ray crosses first. The board is usually in front of the room, but "usually" is the beam's sum.
	var glasses: Array[TouchPanel] = []
	if board_up:
		glasses.append(clipboard.panel())
	if snap_up:
		glasses.append(snap_board.panel())
	glasses.append_array(pointer_panels)
	var on: TouchPanel = _beam.point(from, along, pulled, glasses)
	if clipboard != null:
		clipboard.beam_on_glass(on != null)


## Ask authored world targets for their nearest stable address and submit exactly once
## on a press edge.  This is deliberately separate from `GlassPointer`: glass owns UI
## hit-testing, while a MultiMesh endpoint has no individual physics body to collide with.
func _point_world_targets(pointer_index: int, from: Vector3, along: Vector3, down: bool) -> bool:
	if pointer_index < 0 or pointer_index >= _world_pointer_was_down.size():
		return false
	var winner: Node = null
	var hit: Dictionary = {}
	var nearest := INF
	for target in world_pointer_targets:
		if target == null or not is_instance_valid(target) or not target.has_method("world_pointer_hit"):
			continue
		var answer: Variant = target.call("world_pointer_hit", from, along)
		if not answer is Dictionary:
			continue
		var candidate := answer as Dictionary
		var distance := float(candidate.get("distance", INF))
		if candidate.is_empty() or not is_finite(distance) or distance < 0.0 or distance >= nearest:
			continue
		winner = target
		hit = candidate
		nearest = distance
	for target in world_pointer_targets:
		if target != null and is_instance_valid(target) and target.has_method("world_pointer_hover"):
			target.call("world_pointer_hover", hit if target == winner else {})
	var was_down := _world_pointer_was_down[pointer_index]
	_world_pointer_was_down[pointer_index] = down
	if winner != null and down and not was_down and winner.has_method("world_pointer_press"):
		winner.call("world_pointer_press", hit)
	return winner != null


func _clear_world_pointer_hover() -> void:
	for index in range(_world_pointer_was_down.size()):
		_world_pointer_was_down[index] = false
	for target in world_pointer_targets:
		if target != null and is_instance_valid(target) and target.has_method("world_pointer_hover"):
			target.call("world_pointer_hover", {})


## WHETHER THIS HAND IS REACHING FOR SOMETHING TO PINCH, and therefore is not pointing at glass.
##
## ---------------------------------------------------------------------------------
## THE BEAM AND THE PINCH ARE THE SAME FINGER, AND THIS IS THE RULE THAT SETTLES IT
## ---------------------------------------------------------------------------------
##
## `_point_a_hand` presses glass with `_read_input(hand, Bind.TRIGGER)`, and `_nearest_takeable` takes
## PINCHED controls from that same raw reading. Until 2026-09-15 neither knew about the other, and
## nothing went wrong -- because you point at a screen from across the cockpit and pinch a switch with
## your hand on it, so the two never happened at once. The pinch lane (2026-09-15) left it as a
## place to look.
##
## The director's camera is the thing that walks into it: a floating object with three pinched keys on
## its back that a player holds wherever they like, including an arm's length from the desk's monitors
## or in front of a clipboard. One trigger pull would then both press the glass and press a key.
##
## **TOUCHING BEATS POINTING.** A beam is how you reach something you cannot touch; a hand with a
## pinchable control within `VehicleControl.REACH` has already arrived. So that hand's beam is put
## away, visibly, and its pull works the control.
##
## REJECTED: NEAREST WINS -- compare how far along the ray the glass is with how far the control is. It
## reads fairer and it is the same mistake item 14 already rejected between the two fingers: the beam's
## hit distance is a function of where you happen to be aiming and can be a few centimetres when the
## glass is close, so millimetres would settle a question the hand has answered by being ON a key. A
## rule you can state in one sentence is one you can predict.
##
## REJECTED: THE BEAM WINS WHILE IT IS ON GLASS. That makes the camera's keys silently dead whenever a
## board is up -- which is exactly when somebody is setting a shot -- and silently is the word: nothing
## on screen would say why the button did not work.
##
## A HAND ALREADY PINCHING SOMETHING COUNTS, and that is not the same question as "is there one near".
## `_nearest_to` skips what is already held, so asking it alone would let the beam come back on the
## very frame a key went down -- and the pull that pressed the key would press the glass as well. The
## held control is asked first for that reason.
##
## A HAND CARRYING SOMETHING WITH ITS FIST STILL POINTS. Its trigger is free by definition -- that is
## what makes the grab and the pinch two gestures -- and taking the beam away from it would cost a
## player holding the camera the ability to point at anything, for no case anybody has met.
func _reaching_for_a_pinch(hand: int, at: Vector3) -> bool:
	var held: VehicleControl = _held_by(hand)
	if held != null:
		return held.taken_by() == Bind.Take.PINCH
	return _nearest_to(at, Bind.Take.PINCH) != null


## WHERE THE EYE IS, in world space, whichever way the player is looking through.
##
## The headset camera and the desktop one are two nodes and only one of them is ever
## current, so anything that needs "how far is that from the viewer" has to ask rather than
## pick one. It is the distance the spotting boxes are sized by.
func eye_position() -> Vector3:
	var head: Node3D = camera if using_xr else desktop_camera
	return head.global_position if head != null else global_position


## ---- what the rest of the hand is doing ----------------------------------------------
##
## See `Bind`. The rule is one sentence: a hand offers its fingers to whatever it is
## HOLDING, and to the global set when it is holding nothing. Everything below is that
## sentence, plus the bookkeeping to say it once a frame per hand.


## WHAT A HAND'S FINGERS DO WHEN IT IS HOLDING NOTHING.
##
## Declared here rather than hardcoded down in `read_controls`, so the empty hand is one
## more binding table and not a different mechanism. It says exactly what the rig has always
## done -- fly with the thumbsticks, brake with the left trigger, browse craft and seats
## with the thumb buttons -- and now it says it in a form a control can override.
##
## PER HAND, because these are not symmetric and never were: the left stick is the control
## column and the right is rudder and power. That is the arrangement every stick-and-
## throttle setup in the world uses, and the reason your hands already know which is which.
func _global_bindings(hand: int) -> Dictionary:
	if hand == 0:
		return {
			# The brake, as a level. An analog trigger read straight through is a control
			# that cannot latch, which is exactly right for a brake and exactly wrong for
			# the throttle this used to be.
			Bind.TRIGGER: Bind.axis("brake"),
			# NEGATED ON PITCH, because a control column is not a camera stick. A thumbstick
			# reports +y pushed forward, and pushing a stick forward is nose DOWN.
			Bind.STICK: [Bind.axis("pitch", -1.0, 1), Bind.axis("roll", 1.0, 0)],
			# TWO LEVELS OF ONE LIST. The upper button walks the machines; the lower jumps
			# to a different KIND of machine, because getting from an aeroplane to a boat
			# through forty aeroplanes is not a list anybody can choose from.
			Bind.THUMB_HIGH: Bind.frame(Sim.BUTTON_USE),
			Bind.THUMB_LOW: Bind.frame(Sim.BUTTON_KIND),
		}
	return {
		Bind.STICK: [Bind.axis("rudder", 1.0, 0), Bind.axis("lever_rate", 1.0, 1)],
		# ONE SEAT ALONG, INSIDE THIS CRAFT, on either button. One question per hand, and
		# neither hand does the other's job.
		Bind.THUMB_HIGH: Bind.frame(Sim.BUTTON_SEAT),
		Bind.THUMB_LOW: Bind.frame(Sim.BUTTON_SEAT),
	}


## THE TABLE THIS HAND IS ACTUALLY WORKING FROM.
##
## The held control's entries laid over the global set, so a control speaks only for the
## fingers it has something to say about and the rest go on doing what they always do. A gun
## grip that wants the brake OFF its trigger says `Bind.nothing()`, which is an entry and
## therefore wins; leaving the trigger out would leave it braking.
func _bindings_for(hand: int) -> Dictionary:
	var table: Dictionary = _global_bindings(hand).duplicate()
	var held: VehicleControl = _held_by(hand)
	if held != null and is_instance_valid(held):
		table.merge(held.bindings(), true)
		# AND THE FINGER THAT IS HOLDING IT IS NOT ALSO FREE TO DO SOMETHING ELSE.
		#
		# The rule `Bind` already states about the grip, extended to the pinch the moment there
		# was one. An empty left hand brakes with its trigger; give that trigger a second job
		# and, with nothing said, it does both at once -- throw the master arm on final and the
		# aeroplane brakes. `tests/pinch.gd` measured exactly that: brake 1.00 with the switch
		# in the hand.
		#
		# AFTER the control's own table and not before, so a pinched part cannot contradict
		# itself about the finger that is holding it; before the board and the builder, which go
		# on beating everything. And only while the part is actually HELD: a hand merely passing
		# a switch brakes as it always did, which is the honest reading of a finger that has not
		# taken anything yet.
		if held.taken_by() == Bind.Take.PINCH:
			table[Bind.TRIGGER] = Bind.nothing()
	# AND THE BOARD BEATS BOTH OF THEM WHILE IT IS UP.
	#
	# Last, and therefore winning. A board you are reading is the thing you are working,
	# and the thumb buttons are what works it -- whatever they would otherwise have done,
	# and on either hand, because which hand is free depends on what you are flying.
	#
	# WHILE IT IS UP AND NOT OTHERWISE, so this costs the empty hand nothing: put the board
	# away and the thumbs go back to walking the machines.
	# THE BUILDER BEATS THE CONTROLS. A cockpit being built is not a cockpit being flown:
	# the things in it are furniture, and what their own tables say about thumb buttons is
	# beside the point until the player turns the builder off.
	if _building:
		table.merge(_building_bindings(hand), true)
	# AND THE BOARD BEATS THE BUILDER, while it is up.
	#
	# LAST, and that order is the whole of it: a board you are reading is the thing you are
	# working, whatever else is going on. Put it the other way round and the thumbs would
	# stop scrolling the parts list the moment the builder was switched on -- which is
	# exactly when somebody is scrolling a parts list.
	# AND THE SNAP BOARD BEATS THE BUILDER TOO, while it is up: on the hand pointing at it the trigger is its press, and
	# nothing under it may also act on that pull. See SnapBoard.bindings.
	if snap_board != null and snap_board.is_up():
		table.merge(snap_board.bindings(hand), true)
	if clipboard != null and clipboard.is_up():
		table.merge(clipboard.bindings(hand), true)
	# A CONTROL MAY OFFER A SHARED BINDING TABLE, but this particular craft may not carry
	# every channel in it. A boat's throttle is the same class as an aeroplane's and its
	# upper thumb must therefore lose FLAPS here, before this one table feeds input, the
	# controller labels and HELP. A loose station has no craft and keeps the whole table.
	var view: VehicleView = vehicle_view()
	if view != null:
		for input in table.keys():
			var fitted: Variant = _only_fitted_commands(table[input], view)
			if fitted == null:
				table.erase(input)
			else:
				table[input] = fitted
	return table


## ONE ACTION WITH COMMANDS FOR CHANNELS THIS CRAFT DOES NOT HAVE REMOVED. Arrays matter:
## a trigger can carry two actions, and removing one must not take the other with it.
static func _only_fitted_commands(action: Variant, view: VehicleView) -> Variant:
	if action is Array:
		var kept: Array = []
		for one in action:
			var fitted: Variant = _only_fitted_commands(one, view)
			if fitted != null:
				kept.append(fitted)
		return kept if not kept.is_empty() else null
	if action is Dictionary and int((action as Dictionary).get("kind", -1)) == Bind.Kind.COMMAND:
		return action if view.channel_range(int((action as Dictionary).get("channel", -1))) > 0 else null
	return action


## WHAT THE FINGERS DO WHILE THE COCKPIT IS BEING BUILT.
##
## ONE BUTTON, AND IT IS THE BIN. Adding controls happens on the board, which has room to
## name all fourteen; taking one OUT has to happen with the thing in your hand, because
## picking a name off a list is not how anybody says "not that one, THAT one".
##
## THE LOWER THUMB BUTTON, which every other table treats as the less consequential of the
## two, and bound only while the builder is on. A button that could delete the throttle in
## flight is not a bug anybody should have to find.
##
## AND THE TRIGGER IS TAKEN AWAY rather than left out. An empty left hand brakes with it and
## a gun grip fires with it, and neither is something to be doing while dragging a lever
## across the console. An absent entry would leave both.
##
## AND THE HAND CARRYING A CONTROL WORKS THE GRID IT IS PUT DOWN ON. Asked for on 2026-09-13: tap to turn snap on or off,
## and the joystick up and down for how fine. So on the hand that holds something while placing, the joystick's click is
## snap on or off and the joystick's flick is the step (`PlacingGrid`). Only on that hand: an empty hand has nothing to
## snap.
##
## WHICH ALSO TAKES THE CARRIED CONTROL'S OWN FINGERS AWAY. The held control's table is laid under this one, and this
## one said nothing about the mini joystick or its click -- so a stick being carried across the console wound the
## aeroplane's trim under a resting thumb and re-centred it on a click, while it was furniture.
## `tests/snap.gd`, `_a_stick_being_placed_does_not_trim_the_craft`.
func _building_bindings(hand: int) -> Dictionary:
	# THE UPPER THUMB IS THE MODE SWITCH, and it is there in both modes -- that is what
	# makes it a switch rather than a way in. A cockpit is laid out by putting a lever
	# somewhere, working it, and moving it again, and a mode change that meant finding the
	# board and a tab every time would be a loop nobody goes round twice.
	var table: Dictionary = {Bind.THUMB_HIGH: Bind.local(Bind.Local.TRY_IT)}
	if _trying:
		# WORKING THEM, so everything else is left exactly as it is: the throttle's own
		# thumb button still works the flaps and the gun grip still fires. A test flight in
		# which half the controls behave differently is not a test of anything.
		return table
	table[Bind.TRIGGER] = Bind.nothing()
	table[Bind.THUMB_LOW] = Bind.local(Bind.Local.BIN)
	if _held_by(hand) != null:
		table[Bind.STICK_CLICK] = Bind.local(Bind.Local.SNAP_TOGGLE)
		table[Bind.STICK] = Bind.local(Bind.Local.SNAP_STEP)
		# AND THE TRIGGER OPENS THE SNAP BOARD on this hand, or puts it away. See `_toggle_the_snap_board`.
		table[Bind.TRIGGER] = Bind.local(Bind.Local.SNAP_BOARD)
	return table


## ONE PHYSICAL INPUT, READ. A float for the trigger, a Vector2 for the mini joystick, a
## bool for the two thumb buttons and the click.
func _read_input(hand: int, input: int) -> Variant:
	# A FINGER PRESSED BY A TEST. See `force_input`.
	if _forced_input[hand].has(input):
		return _forced_input[hand][input]
	var pad: XRController3D = left_hand if hand == 0 else right_hand
	if pad == null:
		return 0.0
	match input:
		Bind.TRIGGER:
			return pad.get_float(&"trigger")
		Bind.STICK:
			return _stick(pad)
		Bind.STICK_CLICK:
			return pad.is_button_pressed(&"primary_click")
		# THE LETTER ON THE BUTTON IS NOT THE POSITION OF THE BUTTON. `ax_button` is the
		# LOWER of the two on both hands -- A on the right, X on the left -- and `by_button`
		# the upper. A binding names the thumb position, so one table serves either hand.
		Bind.THUMB_LOW:
			return pad.is_button_pressed(&"ax_button")
		Bind.THUMB_HIGH:
			return pad.is_button_pressed(&"by_button")
	return 0.0


## AN INPUT AS A NUMBER, whatever it physically is. `component` picks an axis out of a
## Vector2 and is ignored by everything else.
func _reading_of(raw: Variant, component: int) -> float:
	if raw is Vector2:
		var pair: Vector2 = raw
		return pair.y if component == 1 else pair.x
	if raw is bool:
		return 1.0 if raw else 0.0
	return float(raw)


## AN INPUT AS A YES OR NO. Half travel on the analog ones, which is where a finger that
## means it has got to.
func _is_down(raw: Variant) -> bool:
	if raw is Vector2:
		return (raw as Vector2).length() > 0.5
	if raw is bool:
		return raw
	return float(raw) > 0.5


## EVERY BINDING ON BOTH HANDS, INTO ONE FRAME.
##
## `frame` is the control frame under construction: the axes by name, and `buttons` for the
## bits. Commands do not go in it -- they go on the bus as they happen -- which is the same
## split the rest of the cockpit already draws between a level and a configuration.
func _work_the_hands(frame: Dictionary) -> void:
	for hand in range(2):
		var table: Dictionary = _bindings_for(hand)
		for input in table:
			var raw: Variant = _read_input(hand, input)
			var down: bool = _is_down(raw)
			# THE PRESS AND NOT THE HOLD, for anything that acts once. Held down, a selector
			# would cycle at the tick rate and a gear switch would buzz.
			var pressed: bool = down and not bool(_input_was_down[hand].get(input, false))
			_input_was_down[hand][input] = down
			# AND THE CONTROL GETS TO SEE ITS OWN HAND. A binding says what an input means;
			# this is how the thing being held finds out it happened, so it can show it.
			# The gun's blade is the only thing in the cockpit that says a gun is firing.
			var held: VehicleControl = _held_by(hand)
			if held != null and is_instance_valid(held):
				held.hand_input(input, down)
			var actions: Array = table[input] if table[input] is Array else [table[input]]
			for action in actions:
				_do_action(action as Dictionary, raw, down, pressed, frame, hand)


## ONE ACTION. See Bind for what the four kinds mean and, more to the point, WHEN they act.
func _do_action(action: Dictionary, raw: Variant, down: bool, pressed: bool,
		frame: Dictionary, hand: int) -> void:
	match int(action.get("kind", -1)):
		Bind.Kind.FRAME_BIT:
			if down:
				frame["buttons"] = int(frame.get("buttons", 0)) | int(action.get("bit", 0))
		Bind.Kind.FRAME_AXIS:
			var value: float = _reading_of(raw, int(action.get("component", -1)))
			frame[String(action.get("axis", ""))] = value * float(action.get("scale", 1.0))
		Bind.Kind.COMMAND:
			if pressed:
				_do_command(action)
		Bind.Kind.LOCAL:
			# THE GRID FIRST, because it wants the stick HELD as well as flicked, and it needs no board: a grid is the
			# rig's and works with the clipboard away.
			var what: int = int(action.get("what", -1))
			if what == Bind.Local.SNAP_STEP:
				_step_the_grid(raw, down, pressed)
				return
			if what == Bind.Local.SNAP_TOGGLE:
				if pressed:
					placing_grid.toggle()
					_grid_changed()
				return
			# THE SNAP BOARD, on the hand whose trigger this is -- which is why `_do_action` is told the hand.
			if what == Bind.Local.SNAP_BOARD:
				if pressed:
					_toggle_the_snap_board(hand)
				return
			if not pressed or clipboard == null:
				return
			match what:
				Bind.Local.CLIPBOARD:
					clipboard.toggle()
				Bind.Local.SCROLL_UP:
					clipboard.scroll(-1)
				Bind.Local.SCROLL_DOWN:
					clipboard.scroll(1)
				Bind.Local.BIN:
					bin_what_is_held()
				Bind.Local.TRY_IT:
					try_the_controls(not _trying)
				Bind.Local.NAVIGATE:
					if raw is Vector2:
						clipboard.navigate(raw as Vector2)
				Bind.Local.PRESS_HIGHLIGHTED:
					clipboard.press_highlighted()
				Bind.Local.TAB_NEXT:
					clipboard.next_tab(1)


## A BUS COMMAND FROM A BINDING.
##
## A step reads where the channel IS from the craft rather than from anything remembered
## here, for the reason `VehicleView.channel_value` gives: two crew on one aeroplane, and a
## number this machine had been keeping would part company with theirs the moment they
## touched it.
##
## A CHANNEL THE CRAFT IS NOT FITTED WITH IS SILENTLY NOTHING, and that is what binding by
## range rather than by value buys. A collective carries the throttle's table, a helicopter
## has no flaps, and the button does nothing rather than something wrong.
func _do_command(action: Dictionary) -> void:
	var channel: int = int(action.get("channel", -1))
	if channel < 0:
		return
	var step: int = int(action.get("step", 0))
	var view: VehicleView = vehicle_view()
	if step == 0:
		if view != null:
			view.propose(channel, int(action.get("value", 0)))
		else:
			Sim.send_command(channel, int(action.get("value", 0)))
		return
	if view == null:
		return
	var top: int = view.channel_range(channel)
	# FROM WHERE THE CHANNEL IS SHOWN, which includes an ask still on its way. Stepped from the
	# craft's own answer alone, two presses inside a round trip both stepped from the same old
	# notch and the second was lost.
	var now: int = view.shown_value(channel)
	if top <= 0 or now < 0:
		return
	var wanted: int = now + step
	var stops: Array = action.get("stops", []) as Array
	if not stops.is_empty():
		# THE NEXT OF WHAT THE CRAFT CAN ACTUALLY SELECT, round to the first. See `Bind.step_among`.
		var at: int = stops.find(now)
		wanted = int(stops[(at + 1) % stops.size()]) if at >= 0 else int(stops[0])
	elif bool(action.get("wrap", false)):
		wanted = wrapi(wanted, 0, top + 1)
	else:
		wanted = clampi(wanted, 0, top)
	if wanted != now:
		view.propose(channel, wanted)


## HOW HARD THIS HAND IS ACTUALLY HOLDING ON, latch included.
##
## TAP TO LATCH, TAP AGAIN TO LET GO. A quick squeeze and release while holding something
## pins the hand to it, and this reports a closed fist from then on. The next quick squeeze
## unpins it, and the real finger takes over again -- which on a hand that has just opened
## means the control is dropped that same frame.
##
## Squeezing and holding still works and still releases when the hand relaxes. The tap is an
## addition and takes nothing away, because holding a lever at 300 kph for four minutes is a
## hand cramp rather than a skill.
##
## AND IT IS THE FIST'S ALONE. A PINCH NEVER LATCHES: any release of the trigger is a full
## release, however brief the pull was. Asked for in those words on 2026-09-15 -- "this is
## different with pinch, any release is a full release, this makes working with switches
## (which you only want to grab until you have the setting you want) easier" -- and the reason
## is in the sentence. You hold a switch only until it is where you want it. A latch is right
## for a lever you fly with for an hour and wrong for a switch you flick, where it would leave
## your hand stuck to the switch after every flick, to be got off with a second tap nobody
## asked to make. See `_taking_finger`, which is where the pinch declines the latch by reading
## the finger raw.
##
## THE LATCH IS THE RIG'S AND NOT THE CONTROL'S, deliberately. Every control already knows
## how to be held by a grip strength, the tests drive them by handing one in, and a latch
## pushed down into `offer_hand` would be a SECOND way to be held that every subclass and
## every test would then have to know about. Here it is one number, worked out once, and
## everything downstream goes on believing a finger.
##
## LATCHING ONTO NOTHING IS NOT A THING. A tap with an empty hand would leave a fist closed
## on the way past every lever in the cockpit, so the tap only takes if the hand had hold of
## something at the moment it opened.
##
## AND ONLY ONTO SOMETHING A FIST IS HOLDING. The latch belongs to the gesture and not to the
## hand: a hand PINCHING a switch is holding something no fist has hold of, so a fist tapped
## at the same time has nothing to take. Measured on 2026-09-15 with `_held_by` here instead
## (`tests/pinch.gd`, `and_a_grip_tapped_while_pinching_latches_nothing`): the tap latched
## anyway, and the fist it left closed was still closed on the frame the trigger let the
## switch go -- so the hand let go of the switch and took the STICK beside it, having been
## told to do neither.
func _grip_of(hand: int, raw: float) -> float:
	var now: float = float(Time.get_ticks_msec()) * 0.001
	if raw >= VehicleControl.GRAB_ON and not _grip_was_closed[hand]:
		_grip_closed_at[hand] = now
		_grip_was_closed[hand] = true
	elif raw < VehicleControl.GRAB_OFF and _grip_was_closed[hand]:
		_grip_was_closed[hand] = false
		if now - _grip_closed_at[hand] <= TAP_SECONDS:
			# A tap. Either it pins the hand to what it is holding or, if the hand is
			# already pinned, it lets go -- and the raw reading below does the letting.
			if _latched[hand]:
				_latched[hand] = false
			elif _in_the_fist(hand) != null:
				_latched[hand] = true
	# NOTHING LEFT TO HOLD ON TO. A control freed under a latched hand -- see `_let_go` --
	# would otherwise leave the fist closed for the rest of the session. A control the hand
	# has stopped holding WITH ITS FIST counts as freed, which is what drops the latch when a
	# latched hand lets go and pinches something instead.
	if _latched[hand] and _in_the_fist(hand) == null:
		_latched[hand] = false
	return 1.0 if _latched[hand] else raw


## ---- what a hand is told -----------------------------------------------------------

## THE ONE CALL INTO THE RUNTIME. Everything that wants a hand to feel something comes
## through here, and nothing else in the project mentions haptics at all.
##
## IT COUNTS EVEN WHEN THERE IS NOBODY TO FEEL IT, which is the seam. On a desktop and
## headless there is no interface and no motor, so the pulse goes nowhere -- but the COUNT
## still moves, and that is a thing a suite can assert. Counting only when a headset is
## attached would mean the only machine that could check this is the one nobody tests on.
func pulse(hand: int, strength: float, seconds: float, why: StringName = &"") -> void:
	_pulses[why] = int(_pulses.get(why, 0)) + 1
	_pulses[&"any"] = int(_pulses.get(&"any", 0)) + 1
	var sent := Vector2(clampf(strength, 0.0, 1.0) * HAPTIC_MASTER, maxf(seconds, 0.0))
	_last_sent[why] = sent
	if not using_xr:
		return
	var pad: XRController3D = left_hand if hand == 0 else right_hand
	var runtime: XRInterface = XRServer.primary_interface
	if pad == null or runtime == null:
		return
	# THE TRACKER NAME COMES OFF THE NODE, not out of a table here. One number, one place:
	# the rig's two controllers already carry `left_hand` and `right_hand`, and a second
	# copy of those strings would be a second thing to rename.
	runtime.trigger_haptic_pulse(HAPTIC_ACTION, pad.tracker, PULSE_HZ, sent.x, sent.y, 0.0)


## A ROUND LEFT THIS PLAYER'S GUN: felt in the hand holding it, once per round.
##
## ASKED FOR ON 2026-09-13 with the guns made automatic. The kick used to come once per PULL, from the grip, because
## a round's birth record did not say who fired it; a door gun firing eleven rounds a second was felt as one shot,
## which is exactly what "one shot, not automatic" described. The record names its shooter and mount now, and the
## level hands this player's own rounds here.
##
## SHORTER THAN THE GUN'S OWN TIME BETWEEN ROUNDS, by half, so a 25 mm at thirty a second is thirty kicks of 16 ms and
## not one long rumble. The mount's reload is the simulation's, asked of the gun table.
##
## NOTHING WHEN NO HAND HOLDS A GUN -- a desk -- or when the gun in the hand is not the one that fired.
func feel_a_round_leave(mount: int) -> void:
	var view: VehicleView = vehicle_view()
	if view == null:
		return
	for hand in range(2):
		var held: VehicleControl = _held_by(hand)
		if held is PintleGun or held is GunTrigger:
			if Sim.mount_of_seat(view.kind, seat_index()) != mount:
				return
			kick_for_a_round(hand, float(Sim.gun_of(view.kind, mount).get("reload", 1.0)))
			return
		# THE GUN ON THE WEAPON SELECTOR, felt in the hand on the stick whose trigger fired it (plan item 4). A seat with
		# no mount of its own fires no round but that one, so the round's mount byte has nothing to say here.
		if held is FlightStick and Sim.mount_of_seat(view.kind, seat_index()) < 0 and _fires_a_gun_here():
			for entry in (Sim.missile_schema(view.kind).get("stations", []) as Array):
				if bool((entry as Dictionary).get("gun", false)):
					kick_for_a_round(hand, float((entry as Dictionary).get("reload", 1.0)))
					return


## ONE ROUND'S KICK in `hand`, for a gun that fires one every `reload` seconds. See `feel_a_round_leave`.
func kick_for_a_round(hand: int, reload: float) -> void:
	var shape: Vector2 = FEEL[&"round"]
	pulse(hand, shape.x, minf(shape.y, reload * 0.5), &"round")


## ONE OF THE NAMED FEELINGS. See FEEL: this is what every call site uses, so that
## "what a detent feels like" is a decision made once rather than a pair of numbers typed
## into a control class.
func felt(hand: int, why: StringName) -> void:
	var shape: Vector2 = FEEL.get(why, Vector2.ZERO)
	if shape == Vector2.ZERO:
		return
	pulse(hand, shape.x, shape.y, why)


## TELL A FREE HAND WHEN SOMETHING COMES WITHIN ITS GRASP, and again when it goes out of it.
##
## Asked for in a headset: a closed hand either takes hold of a lever or closes on air, and until this the only way to
## know which it would be was to look. `reach` is felt once as the hand arrives and `unreach` once as it leaves.
##
## WHAT A GRIP WOULD TAKE, FROM THE FUNCTION THAT TAKES IT. `chosen` is `_nearest_to`'s answer this frame, so the way in
## is exactly `VehicleControl.REACH` to the grip -- in flight and in the builder alike, because both are offered hands by
## the same loop. A second radius typed here would be a buzz that promised a grab the next squeeze did not make.
##
## EDGES, NOT STATE. A pulse for every frame a control is in reach is a hand that hums against the console; this is told
## only when the answer CHANGES, and a hand that goes from one lever straight onto an overlapping one is told once about
## the new one rather than out-and-in back to back.
##
## A HAND THAT IS HOLDING SOMETHING IS TOLD NOTHING. `grab` and `release` already said it, and what it holds is what is
## remembered, so letting go with the hand still on the lever is not a second buzz on top of `release`, and sweeping a
## stick past the gear handle is not a buzz for the gear handle.
##
## THE WAY OUT IS WIDER THAN THE WAY IN, by `REACH_MARGIN`, and a neighbour has to be that much nearer to take over; and
## no two edges come inside `REACH_GAP`, where the old answer is KEPT so the edge is told when the gap ends. See both. A
## control freed under the hand is forgotten without a pulse: nothing happened at the hand.
func _notice_reach(hand: int, at: Vector3, holding: bool, chosen: VehicleControl) -> void:
	# A CONTROL TAKEN OUT OF THE COCKPIT IS NOTHING IN REACH, freed or not: a part the bin has taken off the station is
	# still an object for a frame, and asking its grip printed "!is_inside_tree()" (2026-09-14, tests/builder.gd, a trim
	# wheel added where the test's hand was and binned).
	var was: VehicleControl = _in_reach[hand] if is_instance_valid(_in_reach[hand]) and _in_reach[hand].is_inside_tree() else null
	if holding:
		_in_reach[hand] = chosen
		return
	var now: VehicleControl = chosen
	if was != null and was.held_by < 0:
		var from_was: float = at.distance_to(was.grip_global())
		var from_chosen: float = at.distance_to(chosen.grip_global()) if chosen != null else INF
		if from_was <= VehicleControl.REACH + REACH_MARGIN and from_was - from_chosen <= REACH_MARGIN:
			now = was
	_in_reach[hand] = was
	if now == was or _reach_clock - _reach_told_at[hand] < REACH_GAP:
		return
	_in_reach[hand] = now
	_reach_told_at[hand] = _reach_clock
	felt(hand, &"reach" if now != null else &"unreach")


## How many pulses have gone out, by reason. `&"any"` is the total. This is what a suite
## asks: a detent felt once is one count, and a detent felt at the tick rate -- which is
## what happens if a bump is set rather than emitted -- is two hundred.
func pulses(why: StringName = &"any") -> int:
	return int(_pulses.get(why, 0))


## WHAT THE LAST PULSE FOR `why` SENT TO THE MOTOR: amplitude after `HAPTIC_MASTER`, then seconds; zero if none has gone.
##
## Read off the call rather than out of FEEL, so a suite asking "is this strong enough to feel" asks what went out -- a
## check that read the table back would pass over a `pulse` that scaled it to nothing.
func last_pulse(why: StringName) -> Vector2:
	return _last_sent.get(why, Vector2.ZERO)


## Forget the tally. For a suite that wants to count one gesture rather than a session.
func forget_pulses() -> void:
	_pulses.clear()
	_last_sent.clear()


## PUT A HAND SOMEWHERE, with no hand and no tracker. World space; null to stop.
##
## The other half of `force_grip`, and the reason it is needed is the same shape: there is
## always something else writing these. On a desktop `_place_desktop_rig` welds both hands
## in front of the instrument panel every physics frame, so a test that set
## `left_hand.global_transform` had it taken away before `_process` could read it -- which
## looks exactly like a grab that did not work and cost twenty minutes to see.
##
## The name is `testing_godot_headless.md`'s: a test double for a hand belongs ON the class
## that reads it, so every test drives the same seam.
func force_hand(hand: int, pose: Variant) -> void:
	_forced_hand[hand] = pose
	_place_forced_hands()


func _place_forced_hands() -> void:
	for hand in range(2):
		if _forced_hand[hand] is Transform3D:
			var pad: XRController3D = left_hand if hand == 0 else right_hand
			if pad != null:
				pad.global_transform = _forced_hand[hand]


## CLOSE A HAND WITH NO HAND, and the pose goes on the controller node as usual.
##
## The seam every grab test in this project has been missing. Without it the only way to
## exercise a grab headless is to call `VehicleControl.offer_hand` -- which is the layer
## BELOW the rig, so the latch, the nearest-control choice, the one-hand-one-control rule
## and now the pulse are all untested by everything that claims to test grabbing.
##
## It is needed because a desktop rig has no grip at all: `read_controls` zeroes both every
## physics frame and only fills them from the controllers when `using_xr`, so a test that
## simply wrote `grip_left` had it taken away again before `_process` could use it. A
## strength below zero means "read the hardware", which is what a player always gets.
func force_grip(hand: int, strength: float) -> void:
	_forced_grip[hand] = strength


## PRESS A FINGER WITH NO FINGER: a thumb button, the trigger, the stick. `value` is what the
## hardware would report -- a bool, a float, a Vector2 -- and null lets go of the seam.
##
## The same seam `force_grip` is, for the rest of the hand, and needed for the same reason: a
## desktop rig reads no controller at all, so without it every binding in the game -- a gun's
## trigger, the board's stick -- is a table a suite can read and never a thing it can press.
## While any input is forced the hands are worked on a desk too, so a test goes through
## `_work_the_hands` and `_do_action` exactly as a headset does.
func force_input(hand: int, input: int, value: Variant) -> void:
	if value == null:
		_forced_input[hand].erase(input)
	else:
		_forced_input[hand][input] = value


## THE SIGNAL LAMP'S KEYS, ON A DESK. Told only when a key CHANGES, because the lamp keeps one list of what is
## being asked for (`SignalLamp.ask`) and a key read as "up" every frame would take away a colour a forced hand
## is holding in a suite.
const DESK_LAMP: Dictionary = {"lamp_white": SignalLamp.WHITE, "lamp_red": SignalLamp.RED,
	"lamp_green": SignalLamp.GREEN}
var _desk_lamp_down: Dictionary = {}


func _work_the_desk_lamp() -> void:
	var lamp: SignalLamp = SignalLamp.in_station(_my_station)
	if lamp == null or not is_instance_valid(lamp):
		_desk_lamp_down.clear()
		return
	# THE HEAD AS THE INPUT FRAME SENDS IT -- in the origin's frame, which `read_controls` calls seat-local -- so the
	# lamp a desk holds up here is exactly where a far machine puts it from the same pose (`SignalLamp.desk_pose`).
	var head: Transform3D = origin.global_transform.affine_inverse() * desktop_camera.global_transform
	for action in DESK_LAMP:
		var down: bool = InputMap.has_action(action) and Input.is_action_pressed(action)
		if down != bool(_desk_lamp_down.get(action, false)):
			_desk_lamp_down[action] = down
			lamp.desk(int(DESK_LAMP[action]), down, head)
	lamp.aim_from_the_desk(head)
	if InputMap.has_action("lamp_home") and Input.is_action_just_pressed("lamp_home"):
		lamp.put_back()


func _an_input_is_forced() -> bool:
	return not _forced_input[0].is_empty() or not _forced_input[1].is_empty()


## WHERE THE RUDDER COMES FROM, best first. Every source of rudder is behind this one function.
##
##   1. A PEDAL DEVICE pushed off centre. Feet on real pedals are the rudder, and nothing a hand does beats them.
##   2. A STICK A HAND HAS HOLD OF, twisted. What the hands did beats what the thumbsticks said.
##   3. THE THUMBSTICK OR THE DESK'S Q AND E: whatever the hand bindings or the keyboard put in `hands_or_keys`.
##
## A DEVICE RESTING AT CENTRE YIELDS, for the reason a resting thumbstick does: pedals nobody's feet are on read 0 once
## their dead zone is out, and a 0 that won would take the rudder away from a wrist twisting the stick. `device` is null
## when there is none and `held_twist` null when no hand is on a stick; every argument is required, so a caller says
## which it has. -1..1 and +1 nose right, ControlInput.rudder's own convention, which the ground handling reads as the
## nosewheel -- nothing here may change its sign or its scale.
static func rudder_demand(device: Variant, held_twist: Variant, hands_or_keys: float) -> float:
	if device != null and absf(float(device)) > 0.0:
		return clampf(float(device), -1.0, 1.0)
	if held_twist != null:
		return clampf(float(held_twist), -1.0, 1.0)
	return hands_or_keys


## WHAT A USB RUDDER PEDAL DEVICE SAYS, -1..1 with its dead zone already taken out, or null when there is none.
##
## NULL, ALWAYS, TODAY: no pedal device is read yet. See agents.md, WHAT IS NOT HERE YET.
##
## TODO(pedal device): a `PedalDevice` reader answers here -- the joypad and axis named in a tuning file (device, axis,
## invert, dead zone, and the calibrated left stop, centre and right stop), read with `Input.get_joy_axis`, and null
## while nothing is mapped or the joypad is not connected. Nothing else has to change: `rudder_demand` already puts it
## first, the frame carries it like every other rudder, and `RudderPedals` shows what the frame carried.
func _pedal_device_reading() -> Variant:
	return null


## THE RUDDER THIS SEAT PUT ON ITS LAST INPUT FRAME, from whichever source it came -- which is what this seat's own
## pedals show. See `FlightLevel._draw_cockpit`.
func rudder_sent() -> float:
	return _rudder


## The control frame. Poses are relative to the ORIGIN, which is the seat, so they are
## already in the frame the wire wants. No conversion, no world space, nowhere for a speed
## term to creep in.
func read_controls() -> Dictionary:
	# ASKED HERE TOO, AND NOT ONLY IN `_work_the_controls`, because the two run on
	# different clocks. Claiming happens on the render frame; this is the physics frame,
	# and at sixty ticks against a stuttering thirty there are frames where a station is
	# freed and this runs twice before `_process` next gets a chance to notice. One of
	# those two reads is where the freed stick reached `_reading`.
	if not _holding_live_nodes():
		_let_go()
	var to_local: Transform3D = origin.global_transform.affine_inverse()
	var head: Node3D = camera if using_xr else desktop_camera
	var head_local: Transform3D = to_local * head.global_transform
	var left_local: Transform3D = to_local * left_hand.global_transform
	var right_local: Transform3D = to_local * right_hand.global_transform

	var throttle: float = 0.0
	var pitch: float = 0.0
	var roll: float = 0.0
	var rudder: float = 0.0
	var brake: float = 0.0
	# How hard the index finger is pulling, whatever it is pulling on. See `Bind.fire`.
	var trigger: float = 0.0
	var buttons: int = 0
	# "No kind in particular", which is what the thumb button asks for. Named rather than
	# written out: it was the literal 15, which stopped meaning "none" and started meaning
	# "the gunship" the moment there were seventeen kinds.
	var wanted_kind: int = Sim.NO_KIND
	# WHAT THE CLIPBOARD ASKED FOR, if anything: the fields of the menu press now pending, beside `Sim.menu_request`, which
	# is on every frame. Let go once the server shows its answer, or the patience runs out -- and then said on the board.
	# See `ask_to_join`. No button: a menu press is its number.
	var joining: int = -1
	var joining_seat: int = -1
	var kind_menu: int = -1
	if _menu_pending():
		var answered: bool = false
		if _join_asked >= 0:
			answered = int(Sim.join_answer.get("count", 0)) != _join_count_at_press
		else:
			answered = _kind_press_answered() or int(Sim.join_answer.get("count", 0)) != _kind_count_at_press
		if answered or _menu_waited_frames >= join_patience_frames():
			if answered and _kind_asked >= 0 and not _kind_press_answered() and clipboard != null:
				clipboard.show_kind_answer(_kind_asked, String(Sim.join_answer.get("why", "")))
			if not answered and clipboard != null:
				if _join_asked >= 0:
					clipboard.show_unanswered_join()
				else:
					clipboard.show_unanswered_kind(_kind_asked)
			_join_asked = -1
			_join_seat_asked = -1
			_kind_asked = -1
			_menu_waited_frames = 0
		else:
			joining = _join_asked
			joining_seat = _join_seat_asked
			kind_menu = _kind_asked
			_menu_waited_frames += 1
	grip_left = 0.0
	grip_right = 0.0
	# A HAND CLOSED BY SOMETHING THAT IS NOT A HAND. See `force_grip`: it is read here
	# rather than inside the `using_xr` branch, because the whole point of it is to work on
	# a machine with no headset, which is every machine the suite runs on.
	if _forced_grip[0] >= 0.0:
		grip_left = _grip_of(0, _forced_grip[0])
	if _forced_grip[1] >= 0.0:
		grip_right = _grip_of(1, _forced_grip[1])
	# AND BOTH INDEX FINGERS, ON THIS SAME TICK. `_read_input` already answers for a forced
	# finger and for a real one, and for a hand with no controller behind it at all, so there
	# is no `using_xr` branch to write here -- and no reason to have one: a machine with no
	# headset is the machine every suite runs on. See `pinch_left`.
	pinch_left = _pinch_of(0)
	pinch_right = _pinch_of(1)

	if using_xr:
		# THE GRIP FIRST, because everything below it depends on what is in the hand.
		#
		# `_grip_of` is where a tap becomes a latch, and it has to run before the bindings
		# are looked up: which table a hand is working from is decided by what it is
		# holding, and what it is holding is decided by this number.
		if _forced_grip[0] < 0.0:
			grip_left = _grip_of(0, left_hand.get_float(&"grip"))
		if _forced_grip[1] < 0.0:
			grip_right = _grip_of(1, right_hand.get_float(&"grip"))
		# AND THEN WHATEVER EACH HAND'S FINGERS ARE BOUND TO. Every axis and every button
		# below used to be written out here, one branch per finger; it is a table per
		# control now, because the answer depends on what the hand has hold of. See `Bind`.
		var worked: Dictionary = {"buttons": buttons}
		_work_the_hands(worked)
		pitch = float(worked.get("pitch", 0.0))
		roll = float(worked.get("roll", 0.0))
		rudder = float(worked.get("rudder", 0.0))
		brake = float(worked.get("brake", 0.0))
		# HOW HARD THE INDEX FINGER IS PULLING, for whatever that finger is on. Zero unless
		# something bound it there: a hand on a throttle brakes with its trigger, and a
		# brake is not a gun.
		trigger = float(worked.get("trigger", 0.0))
		# A RATE AND NOT A POSITION, which is what makes the throttle latch. It is not on
		# the frame -- the rig winds its own lever with it, in `_work_the_controls` -- so it
		# comes back out of the table rather than going onto the wire.
		_lever_rate = float(worked.get("lever_rate", 0.0))
		_trim_rate = float(worked.get("trim_rate", 0.0))
		buttons = int(worked.get("buttons", 0))
	else:
		# A FINGER PRESSED BY A TEST, worked through the same tables a headset uses. What it
		# would put on the frame is thrown away: on a desk the keyboard flies, and a forced
		# finger is there to reach the board and the controls, not to fight the keys.
		#
		# EXCEPT THE TRIM RATE, which is not on the frame at all: the rig winds the craft's trim with it,
		# exactly as a headset's thumb does. Thrown away with the rest, no suite could ever push the
		# stick's mini joystick -- which is how a thumb that trimmed nothing went unseen.
		#
		# AND EXCEPT THE TRIGGER. A finger forced onto a gun is there to fire it, and nothing else on a machine with
		# no headset can pull a trigger through a HAND: thrown away, a suite could only fire a gun by calling
		# `fire_gun`, which is how "one shot, not automatic" (2026-09-13) had no test holding a real grip.
		if _an_input_is_forced():
			var forced: Dictionary = {"buttons": buttons}
			_work_the_hands(forced)
			_trim_rate = float(forced.get("trim_rate", 0.0))
			buttons |= int(forced.get("buttons", 0)) & Sim.BUTTON_FIRE
			trigger = maxf(trigger, float(forced.get("trigger", 0.0)))
		else:
			_trim_rate = 0.0
		pitch = Input.get_axis("pitch_down", "pitch_up")
		roll = Input.get_axis("roll_left", "roll_right")
		# AND D STRAFES RIGHT WHEN THIS IS A SEGWAY. See the note on `strafe_right` in DESK_KEYS.
		if reading_a_segway() and Input.is_action_pressed("strafe_right"):
			roll = clampf(roll + 1.0, -1.0, 1.0)
		rudder = Input.get_axis("yaw_left", "yaw_right")
		_work_the_desk_lamp()
		_lever_rate = 1.0 if Input.is_action_pressed("throttle") else 0.0
		brake = 1.0 if Input.is_action_pressed("brake") else 0.0
		if Input.is_action_pressed("seat"):
			buttons |= Sim.BUTTON_SEAT
		if Input.is_action_pressed("switch"):
			buttons |= Sim.BUTTON_USE
		if Input.is_action_pressed("switch_kind"):
			buttons |= Sim.BUTTON_KIND
		# A KEY PER CRAFT TYPE. F1 is the pods, F2 the aeroplanes, and so on down the list:
		# a key bound to a kind is a shortcut, where a button that walks the kinds is a
		# place in a queue. Pressing the one you are already in asks for another of the
		# same, which walks the machines of that kind.
		for kind in keyed_kinds():
			if Input.is_action_pressed("kind_%d" % kind):
				buttons |= Sim.BUTTON_KIND
				wanted_kind = kind
				break

	# THE TRIGGER, ON THE INPUT FRAME. A level rather than a press: a rotary cannon at
	# thirty rounds a second is a HELD trigger, and what turns holding it into one round
	# every fourth tick is the reload on the server. Nothing anywhere turns it into a press,
	# and nothing may: an input frame is replayed during a rollback, and the reload is keyed
	# on simulation time, so a replayed frame finds the gun still loading.
	#
	# THE BIT IS SET BY A BINDING NOW -- see GunTrigger.bindings -- and not by having hold
	# of the gun. Holding WAS the firing, which made a gunner who wanted to keep hold of
	# their gun without shooting, which is a gunner traversing onto a target, impossible.
	# The grip holds it and the index finger fires it.
	#
	# ON THE DESKTOP THERE IS NO HAND TO HOLD IT WITH, so the keyboard still asks the gun
	# directly. A monitor has no grip and no finger, and a gunner at one has to be able to
	# shoot.
	#
	# AND A PILOT WITH A GUN ON THE WEAPON SELECTOR HAS NO TRIGGER CONTROL AT ALL: the fighter's minigun is fired by the
	# stick's own trigger (plan item 4), so the key is asked of the station instead. The server fires it only while the
	# selector is on the gun, as it does for a headset.
	if not using_xr and ((_my_trigger != null and is_instance_valid(_my_trigger)) or _fires_a_gun_here()) \
			and Input.is_action_pressed("fire"):
		buttons |= Sim.BUTTON_FIRE
		# AND A KEY IS A FULL PULL. The simulation works the rate of fire off the axis now,
		# and a key that left it at zero would be a gunner at a desk who could not shoot.
		trigger = 1.0
	# AND THE MISSILES, at a seat that can launch. Levels, like the trigger: the server edge-detects both.
	if not using_xr and _launches_here():
		if Input.is_action_pressed("lock"):
			buttons |= Sim.BUTTON_LOCK
		if Input.is_action_pressed("launch"):
			buttons |= Sim.BUTTON_LAUNCH

	if kind_menu >= 0:
		wanted_kind = kind_menu

	# Kept for the panel. What the HUD shows is what THIS seat is asking for, which for a
	# pilot is the aircraft's throttle and for a turret station is nothing -- and the
	# station line above it already says which of those you are.
	_throttle = throttle
	_brake = brake
	# WHAT THE HANDS DID BEATS WHAT THE STICKS SAID. A control being held is a control
	# somebody has hold of, and a thumbstick resting at centre must not average it away.
	# WHICHEVER STICK THIS PLAYER IS ON, which need not be the one in front of them: a
	# copilot reaching over to the pilot's column is flying the aeroplane from it.
	var stick: VehicleControl = _reading("stick", _my_stick)
	if stick != null and stick.is_held():
		roll = stick.roll()
		pitch = stick.pitch()
	# THE RUDDER, FROM WHICHEVER OF ITS SOURCES IS SAYING SOMETHING, in the order `rudder_demand` gives. The twist counts
	# ONLY WHILE HELD, like the other two axes: a stick that is not being held is centring, and the thumbstick is what is
	# flying.
	rudder = rudder_demand(_pedal_device_reading(),
		stick.rudder() if stick != null and stick.is_held() else null, rudder)
	_rudder = rudder
	# THE BRAKE, from whichever control is one. On a locomotive that is the second lever,
	# which is latched and therefore reads whether or not a hand is on it; on everything
	# else every control answers zero and the trigger has it to itself.
	if stick != null:
		brake = maxf(brake, stick.brake())
	# THE LEVER IS THE THROTTLE, held or not. This used to read it only while a hand was on
	# it and fall back to the hardware otherwise, so letting go of a lever set to cruise
	# dropped the engines to whatever the trigger happened to be -- which was nothing.
	# A lever stays where it is put; that is what makes it a lever.
	var lever: VehicleControl = _reading("throttle", _my_throttle)
	if lever != null:
		throttle = lever.throttle()
	# Furniture editing owns the desktop arrows and hands. A selected control must not also
	# fly, fire or change configuration on the parked craft. Keep only SEAT so a builder can
	# still leave; menu join/kind requests have their own fields below.
	if placing():
		throttle = 0.0; pitch = 0.0; roll = 0.0; rudder = 0.0; brake = 0.0; trigger = 0.0
		_lever_rate = 0.0; _trim_rate = 0.0; buttons &= Sim.BUTTON_SEAT
	return {
		"throttle": throttle,
		"pitch": pitch,
		"roll": roll,
		"rudder": rudder,
		"brake": brake,
		"trigger": trigger,
		"head": head_local.origin,
		"head_basis": head_local.basis.get_rotation_quaternion(),
		"left": left_local.origin,
		"left_basis": left_local.basis.get_rotation_quaternion(),
		"right": right_local.origin,
		"right_basis": right_local.basis.get_rotation_quaternion(),
		"grip_left": grip_left,
		"grip_right": grip_right,
		"buttons": buttons,
		"kind_wanted": wanted_kind,
		"join_wanted": joining if joining >= 0 else 255,
		"join_seat": joining_seat if joining >= 0 and joining_seat >= 0 else Sim.ANY_SEAT,
		"menu_request": Sim.menu_request,
	}


func _stick(controller: XRController3D) -> Vector2:
	var stick: Vector2 = controller.get_vector2(&"primary")
	if stick.length_squared() < 0.0001:
		stick = controller.get_vector2(&"thumbstick")
	var length: float = stick.length()
	if length < DEADZONE:
		return Vector2.ZERO
	return stick.normalized() * ((length - DEADZONE) / (1.0 - DEADZONE))


## ---- headset on, headset off -------------------------------------------------
##
## OpenXR is initialised once and never torn down -- Vulkan and D3D12 cannot bring it back
## inside a frame -- so what toggles is Viewport.use_xr and which camera is current. The
## ordering below is the part that was paid for elsewhere: the first V is always fine, and
## leaving and re-entering is what puts each eye on its own view.

func xr_available() -> bool:
	# Windowed automation needs a real renderer for screenshots but must not initialize
	# the machine's headset runtime.  Godot consumes `--xr-mode off` before scripts can
	# inspect arguments, so screenshot tools also pass this explicit application flag.
	if OS.get_cmdline_user_args().has("--desktop-only") or OS.get_cmdline_args().has("--desktop-only"):
		return false
	# A headless run has no swapchain, so OpenXR creates an instance and then fails to
	# create a session -- leaving is_initialized() true and the rig convinced it is in a
	# headset that cannot draw.
	if DisplayServer.get_name() == "headless":
		return false
	if _xr_interface == null:
		_xr_interface = XRServer.find_interface("OpenXR")
	return _xr_interface != null


func toggle_vr() -> bool:
	if _xr_busy:
		return false
	return _leave_vr() if using_xr else enter_vr()


func enter_vr() -> bool:
	if using_xr:
		return true
	if not xr_available():
		print("[XR] No OpenXR runtime.")
		return false
	_ask_for_more_pixels()
	if not _xr_interface.is_initialized() and not _xr_interface.initialize():
		print("[XR] OpenXR failed to start. Headset on, then press V.")
		return false
	_vsync_before = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# The window size to come back to, and only if this is the rig that LEFT it. A rig
	# arriving into a viewport that is already stereo would otherwise record the headset's
	# render size as the desktop size, and hand the player a window that shape on the way
	# back out.
	if not get_viewport().use_xr:
		_desktop_size = get_viewport().size
	using_xr = true
	using_desktop = false
	# A HEADSET STARTS ON THE PLAIN FINISH unless somebody chose otherwise -- the fine one has
	# never been timed in a headset. See `SceneryFinish.HEADSET_DEFAULT`.
	Finish.suit_the_display(true)
	# CAMERAS FIRST, THEN use_xr, which _apply_display_mode does in that order. Enabling XR
	# while a plain Camera3D is still current makes stereo duplicate THAT camera instead of
	# using the XRCamera3D with its IPD, so both eyes get the same image and the depth is
	# gone.
	_apply_display_mode()
	desktop_camera.visible = false
	origin.world_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[XR] VR on. V to leave.")
	return true


## MORE PIXELS WHERE THE EYE IS, AND FEWER WHERE IT IS NOT.
##
## A headset does not render at the panel resolution. The runtime hands the engine an eye
## buffer sized for the lens distortion it is about to apply, and that buffer is normally
## SMALLER than what the panels can show -- so the image is upscaled on the way out and
## everything with a hard edge, which in this game is every instrument marking and every
## aircraft against the sky, gets soft.
##
## `render_target_size_multiplier` is the knob. 1.4 means each eye is rendered at 1.4x the
## runtime's suggestion in each direction, which is TWICE the pixels: supersampling, and
## the only cure for aliasing that does not also blur what it is fixing.
##
## MUST BE SET BEFORE THE INTERFACE IS INITIALISED. It sizes the swapchain, and the
## swapchain is made once -- which is why this is called from `enter_vr` before
## `initialize()` and cannot be a setting that takes effect while you are wearing it.
##
## FOVEATION PAYS FOR IT. Twice the pixels is twice the work, so the outer field is
## rendered coarsely and the middle -- where you are looking, and where the whole of a
## cockpit is -- at full rate. On Forward+ (the renderer since 2026-09-14) and on Mobile, what
## does that is `Viewport.vrs_mode = VRS_XR` in `_apply_display_mode`.
## `foveation_level` and `foveation_dynamic`, set below, act ONLY ON THE COMPATIBILITY RENDERER:
## Godot's OpenXR settings page (read 2026-09-14) says of both "Compatibility renderer only, for
## Mobile and Forward+ renderer, set the vrs_mode property on Viewport to VRS_XR". They are kept so
## the level is right if the game is ever run on Compatibility, where `foveation_dynamic` eases the
## level rather than snapping it, because a foveation boundary that jumps is more noticeable than
## one that is simply there. On this renderer they do nothing, and the note that stood here --
## that with the level left at zero VRS_XR had nothing to apply -- was wrong.
const RENDER_SCALE: float = 1.4
const FOVEATION: int = 3
## `--render-scale=1.0` after the bare `--`, for finding the point where a headset holds its refresh.
##
## THE ONE KNOB WORTH REACHING FOR FIRST, and until 2026-09-15 it could only be reached by editing this file and
## restarting. 1.4 is twice the pixels of 1.0, so it is the largest single GPU cost in the game -- larger than the
## renderer, the volumetrics and the finish put together -- and NOTHING HERE HAS EVER BEEN TIMED IN A HEADSET, which is
## the only place the number means anything. A player who drops frames is told by every VR guide to lower this before
## they lower anything they would notice; they could not.
##
## NOT A SWITCH ON THE CLIPBOARD, because it cannot be one: it sizes the swapchain, which is made once when the
## interface initialises (see `_ask_for_more_pixels`). A control that appeared to change it while you were wearing the
## headset and did nothing until the next run would be worse than no control.
##
## THE DEFAULT DOES NOT MOVE. 1.4 is what every picture and every frame time in agents.md was taken at, and a default
## that quietly changed would make all of them lies.
const RENDER_SCALE_FLAG: String = "render-scale"
## The least and most a render scale may be asked for. Below 0.5 the runtime's own upscale is doing all the work;
## above 2.0 is four times the pixels of 1.0 and no headset on this machine would hold it.
const RENDER_SCALE_LEAST: float = 0.5
const RENDER_SCALE_MOST: float = 2.0


## WHAT RENDER SCALE WAS ASKED FOR, or `RENDER_SCALE` when nothing was. Static and pure, so a test can ask it what a
## command line means without a rig. A number outside the range is REFUSED with a warning and the default used, rather
## than clamped: a scale that silently became 0.5 would send somebody looking for the slowdown somewhere else.
static func render_scale_asked_for(arguments: PackedStringArray) -> float:
	for argument in arguments:
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2 or parts[0].to_lower() != RENDER_SCALE_FLAG:
			continue
		if not parts[1].is_valid_float():
			push_warning("[XR] --render-scale=%s is not a number; rendering at %.2fx" % [parts[1], RENDER_SCALE])
			return RENDER_SCALE
		var wanted: float = float(parts[1])
		if wanted < RENDER_SCALE_LEAST or wanted > RENDER_SCALE_MOST:
			push_warning("[XR] --render-scale=%s is outside %.2f to %.2f; rendering at %.2fx" % [parts[1],
				RENDER_SCALE_LEAST, RENDER_SCALE_MOST, RENDER_SCALE])
			return RENDER_SCALE
		return wanted
	return RENDER_SCALE


func _ask_for_more_pixels() -> void:
	if _xr_interface == null or _xr_interface.is_initialized():
		return
	# Asked for by name rather than by casting to OpenXRInterface: a build without the
	# OpenXR module would not PARSE a reference to that class, and a rig that cannot be
	# compiled on a machine with no headset is worse than one that renders at 1x on it.
	if not ("render_target_size_multiplier" in _xr_interface):
		return
	var scale: float = render_scale_asked_for(OS.get_cmdline_user_args())
	_xr_interface.set("render_target_size_multiplier", scale)
	# Compatibility renderer only; on Forward+ VRS_XR foveates (see FOVEATION PAYS FOR IT, above).
	_xr_interface.set("foveation_level", FOVEATION)
	_xr_interface.set("foveation_dynamic", true)
	# THE SCALE IT ACTUALLY USED, not the constant: a line that said 1.40 while the swapchain was 1.00 would be the
	# one piece of evidence a player has about the knob they just turned, and it would be wrong.
	print("[XR] Rendering each eye at %.2fx%s, foveation %d." % [scale,
		"" if is_equal_approx(scale, RENDER_SCALE) else " (asked for on the command line)", FOVEATION])


func _leave_vr() -> bool:
	_xr_busy = true
	var view := get_viewport()
	# The density map goes before the stereo does, for the reason in `_apply_display_mode`:
	# a two-layer foveation map on a one-view pass is the same mismatch the other way up.
	view.vrs_mode = Viewport.VRS_DISABLED
	view.use_xr = false
	if _desktop_size.x > 1 and _desktop_size.y > 1:
		view.size = _desktop_size
	if camera.current:
		camera.clear_current(false)
	DisplayServer.window_set_vsync_mode(_vsync_before)
	_enter_desktop()
	# A one-shot connection rather than an await: making this a coroutine would make
	# toggle_vr() one too, and every caller of it, for the sake of skipping a frame.
	get_tree().process_frame.connect(_release_busy, CONNECT_ONE_SHOT)
	return true


## A frame after leaving, so a double tap of V cannot start a session while the old one is
## still stopping. Godot cannot tear OpenXR down and bring it back inside a frame.
func _release_busy() -> void:
	_xr_busy = false


func _enter_desktop() -> void:
	using_desktop = true
	using_xr = false
	Finish.suit_the_display(false)
	_apply_display_mode()
	desktop_camera.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# THE SAME TABLE THE PAGE IS DRAWN FROM. This line used to be hand-written and said
	# "F1-F10 a type" when eighteen keys were bound. It is a convenience for whoever is
	# reading a console; the LEGEND a player reads is the HELP tab on the clipboard.
	print("[XR] Desktop: %s" % " · ".join(_desk_line()))


## The keyboard as one line, for a console. The craft keys are collapsed into a range,
## because eighteen of them on one line is a line nobody reads -- and the range is worked
## out from the table rather than typed, which is what went wrong last time.
func _desk_line() -> PackedStringArray:
	var said: PackedStringArray = []
	for row in DESK_KEYS:
		var keys: PackedStringArray = []
		for key in row["keys"]:
			keys.append(OS.get_keycode_string(key as Key))
		said.append("%s %s" % ["/".join(keys), row["does"]])
	# THE HIGHEST KEY BOUND, not the number of kinds: the pirate ship has no key and sits in the middle of the row, so
	# the count said F28 while F29 flew the Little Bird (lane/kinds, 2026-09-18).
	var keyed: Array[int] = keyed_kinds()
	if not keyed.is_empty():
		said.append("F1-%s a craft type" % OS.get_keycode_string(kind_key(keyed.back())))
	return said


## ---------------------------------------------------------------------------------
## THE LEGEND: WHAT EVERY INPUT DOES, RIGHT NOW
## ---------------------------------------------------------------------------------
##
## Built from the LIVE tables and not from a list of sentences. `_bindings_for` is the
## function the fingers are actually read through -- the global set, with whatever the hand
## is holding laid over it, and the builder and the board on top of that -- so the page says
## what the thumb does in THIS hand on THIS control, which is what `agents.md` describes and
## what nothing had ever shown anybody.
##
## It ANNOUNCES. The rig hands the rows over and the page draws them; the page has no idea
## what a binding is, exactly as it has no idea what a cockpit is.
##
## GRIP AND MENU ARE ADDED BY HAND HERE and that is not a drift risk, it is the opposite:
## they are the two inputs `Bind` says may never be bound, so they are in no table to be
## read from. A legend that only listed the bindable ones would leave out the one input
## every single interaction in this game starts with.
func legend() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var view: VehicleView = vehicle_view()
	var names: Dictionary = view.channel_names() if view != null else {}
	for hand in range(2):
		var where: String = "LEFT HAND" if hand == 0 else "RIGHT HAND"
		rows.append({"where": where, "what": "grip",
			"does": "take hold of the nearest control; a quick tap latches it"})
		rows.append({"where": where, "what": "menu button", "does": "the clipboard"})
		var table: Dictionary = _bindings_for(hand)
		for input in Bind.inputs():
			if not table.has(input):
				continue
			rows.append({"where": where, "what": Bind.input_name(input),
				"does": Bind.says(table[input], names)})
	# A DESK KEY THAT WORKS A CHANNEL IS LISTED ONLY WHERE THE CRAFT HAS THAT CHANNEL. The hand
	# bindings above are already filtered by `_bindings_for`, and `sense` holds the whole rig to
	# "every control command is fitted to its craft" -- but `desk_keys()` is static and knows
	# nothing about what you are sitting in, so a boat's legend advertised a gear key as soon as
	# one existed (J on 2026-09-17, and T for the hook with it). Telling a player about a key
	# that does nothing in their craft is the same fault as binding one.
	for row in desk_keys_here():
		var keys: PackedStringArray = []
		for key in row["keys"]:
			keys.append(OS.get_keycode_string(key as Key))
		rows.append({"where": "DESK", "what": " or ".join(keys), "does": row["does"]})
	return rows


## PUT THE HEAD BACK WHERE IT BELONGS: facing along the seat, at the seat's own origin.
##
## In a headset this is the play space being re-centred on wherever the person actually is.
## A tracked origin drifts -- somebody sits down after standing, turns their chair, or
## starts a session facing the wrong way -- and the cockpit is built around a specific place
## and direction, so a head that is not there is a head that cannot reach the controls or
## see out. RESET_BUT_KEEP_TILT because the horizon is not something to guess at: the pitch
## and roll of a headset are measured against gravity and are already right.
##
## On the desktop there is no tracker to re-centre, so it is the mouse look that goes back
## to zero, which is the same promise: you are facing the way the seat faces.
func recentre() -> void:
	_look_yaw = 0.0
	_look_pitch = 0.0
	if using_xr and _xr_interface != null:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	_seat_the_head.call_deferred()
	print("[XR] Recentred on the seat.")


## PUT THE EYES WHERE THE COCKPIT WAS BUILT FOR THEM, by moving the play space DOWN.
##
## A cockpit is authored against `CockpitStation.EYE_HEIGHT` -- the deck sits a quarter of a
## metre under it, the console below that, the view band above. But in a headset the eyes
## are wherever the TRACKER says, which is a fact about the room the player is standing or
## sitting in and has nothing to do with the aeroplane. A player whose real head is at 1.7 m
## in a cockpit authored for 0.85 is half a metre above their own instruments.
##
## Lowering the assumed eye height does not fix that -- it lowers the DECK and moves the
## controls further away, which is the wrong direction and is exactly what happened the
## first time this was tried. What fixes it is sitting the player DOWN: the origin drops by
## however far the head is above where the cockpit wants it, and the hands come down with it
## because they are tracked in the same space.
##
## Done on sitting down and on `recentre`, and never per frame: correcting continuously
## would mean standing up in the room moved the aeroplane instead of the pilot, and nobody
## could ever lean.
func _seat_the_head() -> void:
	if not is_seated():
		return
	# The desktop camera is placed at the eye height by hand, so there is nothing to correct.
	var tracked: float = camera.position.y if using_xr else CockpitStation.EYE_HEIGHT
	if tracked < 0.05:
		return
	origin.position.y = CockpitStation.EYE_HEIGHT - tracked


## Desktop stand-in for a headset: the camera looks around with the mouse, and two hands
## sit where a seated person's hands are. The simulation makes no distinction.
func _place_desktop_rig() -> void:
	desktop_camera.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	desktop_camera.rotation = Vector3(_look_pitch, _look_yaw, 0.0)
	var eye: Transform3D = desktop_camera.transform
	# ON THE CONTROLS, from the cockpit's own constants rather than from a pair of numbers
	# that happened to match once. The left hand falls on the throttle and the right on the
	# button, with the stick between them and inside either one's reach.
	var hand := Vector3(0.24, -CockpitStation.HANDS_BELOW_EYES,
		-CockpitStation.HANDS_FORWARD)
	# AND THE LEFT HAND RAISES THE BOARD when it is up. In a headset you lift your arm and
	# look at it; on a monitor the hands are welded in front of the instrument panel, so a
	# clipboard held there is a clipboard inside the panel. Raising it is what the person
	# would be doing anyway.
	var raised: bool = clipboard != null and clipboard.is_up()
	left_hand.transform = eye * Transform3D(Basis.IDENTITY,
		Vector3(-0.26, -0.12, -0.34) if raised else Vector3(-hand.x, hand.y, hand.z))
	right_hand.transform = eye * Transform3D(Basis.IDENTITY, hand)
	# AND AT A BIG GUN THE EYES GO WHERE THE TURRET IS TRAINED, the hands staying on the controls. Plan item 22c, rule 0: a
	# desk gunner trains with the keys, and a view fixed over the bow lost the sight -- and the target in it -- once the
	# turret was trained more than the window's half-width off it. The mouse still looks round from there. DESK ONLY:
	# this function is not called in a headset, where turning a player's view without their head is a comfort failure
	# (tests/ranging_sight.gd holds both).
	desktop_camera.rotation.y = _look_yaw + _desk_train()


## THE TURRET'S TRAIN AS A YAW OF THIS RIG'S ORIGIN, at a seat whose station lays a big gun by a ranging sight; 0 at
## any other seat. Asked of the station, which asks the gunner's own predicted aim: see CockpitStation.sight_bearing.
func _desk_train() -> float:
	var view: VehicleView = vehicle_view()
	var station: CockpitStation = view.station_for(seat_index()) if view != null else null
	var bearing: Vector3 = station.sight_bearing() if station != null else Vector3.ZERO
	if bearing == Vector3.ZERO:
		return 0.0
	var local: Vector3 = origin.global_basis.inverse() * bearing
	return atan2(-local.x, -local.z)


## WHETHER THE SEAT THIS RIG IS IN CAN LAUNCH MISSILES, which is whether its station was fitted for them. Asked of the
## station, which asked the simulation: see CockpitStation._fit_the_missiles.
func _launches_here() -> bool:
	var view: VehicleView = vehicle_view()
	if view == null:
		return false
	var station: CockpitStation = view.station_for(seat_index())
	return station != null and station.launches()


## AND WHETHER ONE OF THAT SEAT'S STATIONS IS A GUN, which is what lets the desk's fire key work a pilot's minigun.
func _fires_a_gun_here() -> bool:
	# A HELMET-SLAVED GUN AT THIS SEAT, whose trigger is the flying stick's own: the AH-64's front seat has no separate
	# trigger control, and a gunner at a desk has to be able to shoot (lane/apache).
	var view: VehicleView = vehicle_view()
	var station: CockpitStation = view.station_for(seat_index()) if view != null else null
	if station != null and station.slaves_a_gun():
		return true
	if not _launches_here():
		return false
	return vehicle_view().station_for(seat_index()).fires_a_gun()


func _unhandled_input(event: InputEvent) -> void:
	if _desk_builder_input(event):
		get_viewport().set_input_as_handled()
		return
	# MASTER ARM AND THE WEAPON STATION, on a desk: a step on the bus on the press, exactly what the stick's thumb
	# sends in a headset. Only at a seat that can launch -- anywhere else they are keys that do nothing, and taken.
	if event.is_action_pressed("master_arm") or event.is_action_pressed("weapon_station"):
		if _launches_here():
			# THE STATIONS THE CRAFT CARRIES, the same list the stick's lower thumb walks. See `Bind.step_among`.
			_do_command(Bind.step(Sim.Channel.MASTER, 1, true) if event.is_action_pressed("master_arm")
				else Bind.step_among(Sim.Channel.WEAPON, vehicle_view().station_for(seat_index()).missile_stations()))
		get_viewport().set_input_as_handled()
		return
	# THE GEAR, on a desk: a step on the bus on the press, at a seat in a craft that has gear. The server refuses it from a
	# seat that does not fly and on the ground with weight on the wheels, and the lever snaps back as it would for a hand.
	if event.is_action_pressed("gear") or event.is_action_pressed("hook"):
		var wanted: int = Sim.Channel.GEAR if event.is_action_pressed("gear") else Sim.Channel.HOOK
		var view: VehicleView = vehicle_view()
		if view != null and view.channel_range(wanted) > 0:
			_do_command(Bind.step(wanted, 1, true))
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_vr"):
		toggle_vr()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("recentre"):
		recentre()
		get_viewport().set_input_as_handled()
		return
	# The simulation rate, live. Refused while networked -- every peer has to agree on it,
	# because a rollback replays ticks and a peer at a different rate disagrees about what
	# a frame number means.
	if event.is_action_pressed("tick_up") or event.is_action_pressed("tick_down"):
		Sim.step_tick_rate(1 if event.is_action_pressed("tick_up") else -1)
		get_viewport().set_input_as_handled()
		return
	# HOW FAR BEHIND EVERYBODY ELSE IS DRAWN, live, and allowed while networked -- which is
	# the whole difference between this and the tick rate beside it. The buffer is
	# per-machine: it only decides how far into the past THIS client draws the entities it
	# is interpolating, so no other peer can tell and none of them has to agree.
	#
	# Worth having a key for because it is the one dial in the game that is free on the
	# wire. Deeper is smoother on traffic the server is not sending every tick and costs
	# `frames / tick_hz` seconds of lag on every aircraft that is not yours. The status
	# line reports what the clock actually settled on, which in automatic mode is not
	# necessarily what was asked for.
	if event.is_action_pressed("buffer_up") or event.is_action_pressed("buffer_down"):
		Sim.set_buffer_frames(Sim.buffer_frames
			+ (1 if event.is_action_pressed("buffer_up") else -1))
		get_viewport().set_input_as_handled()
		return
	if not using_desktop:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_look_yaw -= motion.relative.x * MOUSE_SENS
		_look_pitch = clampf(_look_pitch - motion.relative.y * MOUSE_SENS,
			deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _desk_builder_input(event: InputEvent) -> bool:
	if not using_desktop or not placing() or _my_station == null or clipboard == null or clipboard.is_up():
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and (event as InputEventMouseButton).pressed:
		_desk_build_control = _control_near_screen_point((event as InputEventMouseButton).position)
		if _desk_build_control != null: clipboard.say("Selected %s." % _desk_build_control.label_text())
		return _desk_build_control != null
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return false
	var key := (event as InputEventKey).keycode
	if key == KEY_TAB:
		_cycle_desk_build_control(); return true
	if _desk_build_control == null or not is_instance_valid(_desk_build_control):
		return false
	var move := Vector3.ZERO
	var step := placing_grid.position_step
	match key:
		KEY_LEFT: move.x = -step
		KEY_RIGHT: move.x = step
		KEY_UP: move.z = -step
		KEY_DOWN: move.z = step
		KEY_PAGEUP: move.y = step
		KEY_PAGEDOWN: move.y = -step
		KEY_COMMA: _desk_build_control.rotate_y(-deg_to_rad(float(placing_grid.rotation_step)))
		KEY_PERIOD: _desk_build_control.rotate_y(deg_to_rad(float(placing_grid.rotation_step)))
		_: return false
	_desk_build_control.position += move
	builder_layout_released.emit()
	clipboard.say("%s at %.3f, %.3f, %.3f." % [_desk_build_control.label_text(),
		_desk_build_control.position.x, _desk_build_control.position.y, _desk_build_control.position.z])
	return true


func _cycle_desk_build_control() -> void:
	var controls: Array[VehicleControl] = []
	for child in _my_station.get_children():
		if child is VehicleControl and ControlCatalogue.has(ControlCatalogue.part_of(child)):
			controls.append(child as VehicleControl)
	if controls.is_empty(): _desk_build_control = null; return
	var at := controls.find(_desk_build_control)
	_desk_build_control = controls[(at + 1) % controls.size()]
	clipboard.say("Selected %s. Arrows move, Page Up/Down raises, comma/period turns." % _desk_build_control.label_text())


func _control_near_screen_point(point: Vector2) -> VehicleControl:
	var best: VehicleControl = null; var nearest := 42.0
	for child in _my_station.get_children():
		var control := child as VehicleControl
		if control == null or not ControlCatalogue.has(ControlCatalogue.part_of(control)) \
				or desktop_camera.is_position_behind(control.global_position): continue
		var away := desktop_camera.unproject_position(control.global_position).distance_to(point)
		if away < nearest: nearest = away; best = control
	return best


## Harness seam for the exact desktop key layer. It selects by stable node name and feeds
## ordinary key events through `_desk_builder_input`; no production caller uses it.
func builder_desk_steps_for_test(control_name: String, key: Key, steps: int) -> bool:
	if _my_station == null: return false
	_desk_build_control = _my_station.get_node_or_null(control_name) as VehicleControl
	if _desk_build_control == null: return false
	build_the_cockpit(true)
	for _i in range(steps):
		var event := InputEventKey.new(); event.keycode = key; event.pressed = true
		if not _desk_builder_input(event): return false
	return true


## THE FINISH'S SCRIPT, PRELOADED, so the key table can name its action in a constant. A global
## class name resolves only once the editor or an import has registered it, and a constant that
## leans on one fails to parse on a checkout whose class cache is older than the class -- which
## is exactly what the first run of this on Windows found. A preload is a path, and a path is
## always there.
const FINISH := preload("res://autoload/finish.gd")

## WHICH DESK KEYS WORK A CRAFT CHANNEL, so `legend()` can leave out the ones this craft has
## no use for. Only the actions that step a fitted channel belong here: flying, looking and
## changing craft are the rig's own and every craft has them. Read by `legend()`; the actual
## binding is unconditional, because pressing a key for a channel you do not have is already
## refused where the command is applied.
const DESK_CHANNELS: Dictionary = {
	"gear": Sim.Channel.GEAR,
	"hook": Sim.Channel.HOOK,
	"master_arm": Sim.Channel.MASTER,
	"weapon_station": Sim.Channel.WEAPON,
}

## EVERY KEY ON A DESK, IN ONE TABLE.
##
## This was three lists that had already gone out of step: `_bind_actions` bound the keys, a
## `print` in `_enter_desktop` wrote a line about them that nobody running the game ever
## sees, and nothing anywhere showed them to a player. The printed one said "F1-F10 a type"
## while EIGHTEEN keys were bound to eighteen craft, which is what a list kept in three
## places always comes to.
##
## So there is one. The binder walks it, the stdout line is generated from it, and the HELP
## page on the clipboard is drawn from it -- and a key added without a sentence beside it is
## a key that turns up on the page saying nothing, which somebody will notice.
##
## ROLL IS ON THE ARROWS AND ON A. D is roll as well historically and is now the spotting
## toggle: a key that does two things is a key that does neither well, so the arrows are the
## ones to fly with.
const DESK_KEYS: Array[Dictionary] = [
	{"action": "pitch_down", "keys": [KEY_W], "does": "nose down"},
	{"action": "pitch_up", "keys": [KEY_S], "does": "nose up"},
	{"action": "roll_left", "keys": [KEY_LEFT, KEY_A], "does": "roll left"},
	{"action": "roll_right", "keys": [KEY_RIGHT], "does": "roll right"},
	{"action": "yaw_left", "keys": [KEY_Q], "does": "rudder left"},
	{"action": "yaw_right", "keys": [KEY_E], "does": "rudder right"},
	{"action": "throttle", "keys": [KEY_SHIFT], "does": "open the throttle"},
	{"action": "brake", "keys": [KEY_CTRL], "does": "brake"},
	# THE GUN, ON A DESK. In a headset the trigger under the index finger fires whatever gun
	# the hand is holding -- see GunTrigger.bindings -- and a monitor has neither the hand
	# nor the finger, so a gunner at one needs a key or they cannot shoot at all.
	{"action": "fire", "keys": [KEY_SPACE], "does": "fire the gun"},
	# THE MISSILES, ON A DESK, for the same reason as the gun: in a headset they are the stick's trigger and thumbs --
	# see FlightStick.missile_bindings -- and a monitor has neither. Master arm and the station are switches on the
	# bus, so they go as a command on the press; the lock and the launch are levels on the frame.
	{"action": "lock", "keys": [KEY_L], "does": "lock the target ahead"},
	{"action": "launch", "keys": [KEY_ENTER], "does": "launch a missile"},
	{"action": "master_arm", "keys": [KEY_U], "does": "master arm on or off"},
	{"action": "weapon_station", "keys": [KEY_Y], "does": "next weapon station"},
	# THE GEAR, ON A DESK. In a headset it is a lever or a handle a hand reaches for -- see GearLever and GearHandle -- and
	# the stick's click; a monitor has neither, so a desk pilot could not put the wheels down at all. A step on the bus
	# on the press, as master arm is. J, because G and H already change craft.
	{"action": "gear", "keys": [KEY_J], "does": "gear up or down"},
	# AND THE HOOK, on the two carrier aeroplanes, for the same reason: T for tailhook.
	{"action": "hook", "keys": [KEY_T], "does": "arresting hook down or up"},
	# THE SIGNAL LAMP, ON A DESK. In a headset the hand holding it flashes it -- trigger white, the lower thumb red, the
	# upper green (`SignalLamp`) -- and a monitor has neither the hand nor the fingers. Held, like the buttons are: the
	# lamp is lit for as long as the key is down, which is how Morse is sent. 0 puts it back in its holster.
	{"action": "lamp_white", "keys": [KEY_1], "does": "signal lamp: white while held"},
	{"action": "lamp_red", "keys": [KEY_2], "does": "signal lamp: red while held"},
	{"action": "lamp_green", "keys": [KEY_3], "does": "signal lamp: green while held"},
	{"action": "lamp_home", "keys": [KEY_0], "does": "signal lamp back in its holster"},
	{"action": "seat", "keys": [KEY_F], "does": "next seat in this craft"},
	{"action": "switch", "keys": [KEY_G], "does": "next craft"},
	{"action": "switch_kind", "keys": [KEY_H], "does": "next KIND of craft"},
	{"action": "spot", "keys": [KEY_D], "does": "red boxes round distant aircraft"},
	# STRAFE RIGHT, D, AND ONLY IN A SEGWAY. Asked for on 2026-09-15: "they should be able to move
	# forward/back/strafe-left/strafe-right with 'wasd'". W, S and A already do it -- they are
	# `pitch_down`, `pitch_up` and `roll_left`, and a segway reads pitch as ahead and roll as
	# sideways -- but D has been `spot` since long before there was anything to walk, and
	# `roll_right` lives on the arrow key alone.
	#
	# SO IT IS A LAYER, not a rebinding. Taking D off the spotting boxes would change what every
	# pilot's keyboard does to fix what a person standing in a room needs; instead a segway lays a
	# layer over the desk keys, the way a hand holding a control lays one over the global bindings
	# (`_bindings_for`). In a segway D strafes and the boxes keep their key back in a craft. The two
	# never both happen: `_reading_a_segway` gates both ends, here and in `FlightLevel`.
	{"action": "strafe_right", "keys": [KEY_D], "does": "strafe right (in a segway)"},
	# THE FINISH, plain or fine. On the desk beside the spotting boxes because both are about
	# what the world looks like rather than what the aircraft does, and on the clipboard as
	# well, because a headset has no keyboard. See `Finish`.
	{"action": FINISH.ACTION, "keys": [KEY_BACKSLASH], "does": "plain or fine scenery"},
	{"action": "recentre", "keys": [KEY_R], "does": "put your head back in the seat"},
	{"action": "toggle_vr", "keys": [KEY_V], "does": "headset on, or off"},
	# THE TWO DEVELOPER PAIRS. They are on the same keyboard a player uses and they are said
	# out loud rather than hidden, because a key that does something surprising is worse
	# undocumented than documented.
	{"action": "tick_down", "keys": [KEY_BRACKETLEFT], "does": "slower simulation rate"},
	{"action": "tick_up", "keys": [KEY_BRACKETRIGHT], "does": "faster simulation rate"},
	{"action": "buffer_down", "keys": [KEY_SEMICOLON], "does": "shallower interpolation buffer"},
	{"action": "buffer_up", "keys": [KEY_APOSTROPHE], "does": "deeper interpolation buffer"},
]


## THE WHOLE KEYBOARD, including the one key per craft type that is generated rather than
## written down. F1 upwards, in the order `Sim.Kind` lists them -- off the enum, so a kind
## added in the C++ arrives on the page without anything here being edited. That is the rule
## `Sim.channel_name` already follows and the reason the hand-written line said ten.
##
## THE F-ROW ENDS AT F35, and the kinds do not (lane/kinds, 2026-09-18: "i'd like to have lots of vehicle kinds"). `KEY_F1
## + 35` is no key at all, so a kind past F35 gets NO key rather than an invalid one, and is reached from the CRAFT page
## like every other. F13 and up are not on most keyboards anyway; the page is the way in, the key a shortcut.
static func desk_keys() -> Array[Dictionary]:
	var rows: Array[Dictionary] = DESK_KEYS.duplicate()
	# A KEY FOR EVERY KIND A PLAYER MAY BE PUT IN THAT THE F-ROW REACHES, and none for one the host would refuse.
	for kind in keyed_kinds():
		rows.append({"action": "kind_%d" % kind, "keys": [kind_key(kind)],
			"does": "a %s" % Sim.kind_name(kind)})
	return rows


## THE LAST KEY A KIND MAY HAVE. Godot's F-row is contiguous from `KEY_F1` to here.
const LAST_KIND_KEY: Key = KEY_F35


## THE KEY THAT PUTS A PLAYER IN A CRAFT OF THIS KIND: F1 plus the kind, or `KEY_NONE` past F35.
static func kind_key(kind: int) -> Key:
	return (KEY_F1 + kind) as Key if kind >= 0 and KEY_F1 + kind <= LAST_KIND_KEY else KEY_NONE


## EVERY KIND A PLAYER MAY BE PUT IN THAT HAS A KEY: what `desk_keys` binds, and all the rig polls. Polling an action that
## was never bound is an error every frame, so the poll walks this and not `pilotable_kinds`.
static func keyed_kinds() -> Array[int]:
	var out: Array[int] = []
	for kind in VehicleCatalogue.pilotable_kinds():
		if kind_key(kind) != KEY_NONE:
			out.append(kind)
	return out


## THE DESK KEYS THAT DO SOMETHING IN THE CRAFT THIS RIG IS SITTING IN, which is a narrower
## question than `desk_keys()` and the one a PLAYER is asking.
##
## Everything in `DESK_CHANNELS` works a craft channel, so it is listed only where the craft has
## that channel: a boat is not told about a gear key. Flying, looking and changing craft are the
## rig's own and every craft has them, so they always appear.
##
## BOTH THE LEGEND AND THE SUITE THAT AUDITS THE LEGEND READ THIS, and that is the point. On
## 2026-09-17 `legend()` filtered and `clipboard.gd` walked the unfiltered `desk_keys()`, so the
## two asked different questions about the same board and `and_every_key_the_game_binds_is_named
## _on_it` went red naming four keys that were deliberately absent. `sense` wants a boat's legend
## silent about gear; `clipboard` wants every key a player can press to be named. Both are right,
## and they only agree if there is one list of what this craft binds.
##
## The BINDING stays unconditional. Pressing a key for a channel a craft does not have is already
## refused where the command is applied, and a key that binds nothing is cheaper than a rig that
## rebinds its whole table every time somebody changes seat.
func desk_keys_here() -> Array[Dictionary]:
	var view: VehicleView = vehicle_view()
	var rows: Array[Dictionary] = []
	for row in desk_keys():
		var channel: int = DESK_CHANNELS.get(String(row["action"]), -1)
		if channel >= 0 and (view == null or view.channel_range(channel) <= 0):
			continue
		rows.append(row)
	return rows


func _bind_actions() -> void:
	for row in desk_keys():
		for key in row["keys"]:
			_bind(String(row["action"]), key as Key)


func _bind(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing as InputEventKey).physical_keycode == keycode:
			return
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.keycode = keycode
	InputMap.action_add_event(action, key)


## Re-assert the display mode after being moved in the tree.
##
## `use_xr` and "which camera is current" are properties of the VIEWPORT, not of this node,
## but a reparent fires _exit_tree and _enter_tree and the old _exit_tree turned XR off.
## Since sitting in a seat IS a reparent, the headset went dark the moment the pilot was
## seated -- OpenXR kept running and reported "No viewport was marked with use_xr, there is
## no rendered output" on every frame, while this file went on believing it was in VR.
##
## Reparenting is a normal thing for this node to do, so the display mode is restored
## rather than the reparenting avoided.
func _enter_tree() -> void:
	# is_node_ready(), not is_inside_tree(): _enter_tree fires BEFORE @onready runs, so on
	# the very first entry the camera references are still null and there is nothing to
	# apply. Every later entry is a reparent, which is the case this exists for.
	if is_node_ready():
		_apply_display_mode()


func _apply_display_mode() -> void:
	var view := get_viewport()
	if view == null:
		return
	# The HUD rides on whichever camera is current, so toggling the headset moves it. It is
	# the ONE thing in this project that is head-locked rather than seat-parented, and the
	# reason is in vehicle_hud.gd: a panel bolted to the cockpit is in front of your face
	# only if the play space origin happens to be under the chair.
	var head: Node3D = camera if using_xr else desktop_camera
	if hud != null and head != null and hud.get_parent() != head:
		hud.reparent(head, false)
	if using_xr:
		if desktop_camera != null and desktop_camera.current:
			desktop_camera.clear_current(false)
		if camera != null:
			camera.make_current()
		# STEREO FIRST, THEN THE DENSITY MAP, and this order is not a preference.
		#
		# VRS_XR asks the runtime for a foveation map with ONE LAYER PER EYE. Set on a
		# viewport that is still mono, the map has one layer and the pass wants two, and
		# the framebuffer cannot be built at all:
		#
		#   framebuffer_create_multipass: Layers of our texture doesn't match view count
		#
		# From there every draw call in the frame fails on a null framebuffer -- a
		# thousand errors a second and no picture. It never showed while the world was the
		# first thing loaded, because the flag was already true from the boot before it.
		# Coming into the world FROM THE DESK is what exposed it: the desk's rig clears
		# `use_xr` on its way out and the world's rig turns it back on, so for the first
		# time the two were being set in the same frame.
		view.use_xr = true
		if RenderingServer.get_rendering_device() != null:
			view.vrs_mode = Viewport.VRS_XR
	elif using_desktop:
		view.vrs_mode = Viewport.VRS_DISABLED
		view.use_xr = false
		if desktop_camera != null:
			desktop_camera.make_current()


func _exit_tree() -> void:
	# ONLY when actually going away. A reparent is not a departure, and clearing the
	# viewport's XR flag here is what made the headset stop rendering as soon as the rig
	# sat down.
	if not is_queued_for_deletion():
		return
	# THE VIEWPORT IS LEFT AS IT IS, stereo and all. It belongs to the window rather than
	# to this rig, and the next thing to want it is almost always another rig that wants it
	# in exactly this state -- changing scene is how you get from the desk to the aeroplane.
	# Turning stereo off here and on again a moment later is a render target rebuilt twice
	# for nothing, and it is what the framebuffer errors were.
	#
	# The only rig that leaves without a successor is the last one, on the way out of the
	# process, where nothing is going to draw again anyway.
	if using_desktop:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
