@tool
extends Node3D
class_name VehicleControl
## A PHYSICAL CONTROL IN A COCKPIT, in front of one particular seat.
##
## The base class for a throttle lever, a flight stick, a button -- anything a hand can
## reach out and move. Three responsibilities, and they are worth separating because they
## have three different owners:
##
##   1. **SHOW** where the control is. Every crew member sees every control, including the
##      other pilot's, because a shared cockpit that does not move when your copilot moves
##      it is not a shared cockpit. The position comes off the WIRE, from `CrewControls`,
##      not from local input -- see `apply()`.
##   2. **BE GRABBED** by the player at this machine, wherever in the craft it is. A hand
##      reaches across the flight deck to the other seat's levers and to the centre
##      console exactly as it reaches its own, because that is what two people in one
##      cockpit do. Nobody ELSE's hands exist here as anything but poses, and the rig only
##      ever offers hands to controls in the craft it is sitting in, so a hand cannot reach
##      through a fuselage into somebody else's aeroplane.
##   3. **REPORT** what the hand did, as a value the rig folds into its control frame or
##      sends as a command. This class never talks to the simulation itself.
##
## Why it is a Node3D per seat rather than one control per craft: two pilots have two
## sticks, and the whole point of the exercise is that each of them can see the other's.
##
## THE ONE RULE THIS SHARES WITH EVERYTHING ELSE IN THE COCKPIT: it is a child of a seat
## anchor and never sets a world transform. Its local transform is where it is bolted to
## the aeroplane, and the aeroplane's motion is not a term in that expression.

signal moved(control: VehicleControl)

## How close a hand has to be, in metres, before it counts as being on the control.
const REACH: float = 0.16
## HOW FAR THE CONTROL IS TWISTED about its own axis, -1 hard left to +1 hard right. Zero
## on everything that does not twist, which is everything except a control column.
##
## Separate from `value` because it is a THIRD axis, and separate from the rudder on the
## wire because this is where the control physically is -- the same distinction `value`
## draws between a stick's position and what the aeroplane does about it.
var twist: float = 0.0
## How fast this control returns to centre with nobody holding it, in fractions per second.
## Zero -- the default -- means it latches where it is put. Set in `_build`.
var centring: float = 0.0
## How hard the grip has to be squeezed to take hold, and how far it must relax to let go.
## Two thresholds rather than one: a single one chatters when a hand sits on the boundary.
const GRAB_ON: float = 0.6
const GRAB_OFF: float = 0.35

## WHICH SEAT THIS CONTROL WAS BUILT IN, and therefore whose station drew it. NOT who may
## touch it: anybody aboard may work anything they can reach, which is what a shared
## cockpit means. See PilotRig, which offers hands by reach rather than by seat.
@export var seat: int = 0
## What this control is called, for the panel and for tests.
@export var control_name: String = "control"
## Stable authoring identity. It is separate from a scene node name: a builder may rename
## the visible node or move it between consoles without changing the semantic endpoint it
## represents. Empty legacy controls receive `seat<N>/<node-name>` when serialized.
@export var device_id: String = ""
## Immutable semantic target saved by the cockpit package. Runtime routing reads this rather
## than rebuilding a target from mutable inspector fields.
@export var signal_binding: Dictionary = {}

## WHICH BUS CHANNEL THIS CONTROL WORKS, or -1 for one that rides the input frame instead.
##
## The difference is what the control PROMISES. A latched control is a CONFIGURATION: it
## stays where it is put, the physics reads it off the vehicle, and both pilots have to see
## it, so what it sends is a command WHEN IT MOVES rather than a level every tick. A
## spring-loaded one is a momentary demand and belongs on the input frame, where a rollback
## can replay it.
##
## Set in `_build`, beside `control_name`. The rig walks every control it can reach and
## sends for any that has one, which is why a new lever on the bus is a class and not
## another special case in PilotRig -- it was one, for the nacelles, and gear and flaps
## would have been two more.
@export var channel: int = -1
## The top of this channel's range, from `craft_schema`: 1 is a two-position switch, 3 is a
## four-notch flap gate, 255 is a continuous lever. What the value below is scaled into.
@export var channel_range: int = 255

## WHOSE THIS CONTROL'S POSITION IS, and therefore who is told about it and who it is drawn from.
##
##   CRAFT  the aircraft's. A setting on the bus -- a switch, a lever, the trim, the master arm, a
##          selector. A hand here only PROPOSES a position; the craft decides, and every seat aboard
##          draws what the craft decided (`FlightLevel._draw_cockpit`, `VehicleView.shown_value`).
##   SEAT   yours while you hold it: your input, sent to the craft on the input frame as a demand
##          and drawn for the rest of the crew through the linkage. Not a shared setting -- a stick
##          has no position worth remembering.
##   PILOT  yours alone. Never sent, never drawn from anybody else's.
##
## THE SHARING CODE READS THIS AND NOTHING ELSE. It used to walk a list of four roles -- extra,
## flaps, gear, drop -- so the trim wheel, the master arm switch and every knob and switch the
## builder could place were drawn from the hand that last touched them: the U key armed the craft
## and the switch in front of the pilot stayed at SAFE, and a hand could not disarm it by pulling it
## back, because it was already back. `tests/shared_controls.gd`.
##
## UNSAID UNTIL A PART SAYS. Every part sets its own in `_build`, beside `control_name`, and a
## part that forgets is a part nothing shares -- which is a louder failure than a default that
## happens to share it.
enum Scope { UNSAID = -1, CRAFT, SEAT, PILOT }
@export var scope: Scope = Scope.UNSAID


## WHAT THIS CONTROL IS ASKING THE BUS FOR, 0 to channel_range.
##
## Off the y axis, which is the one every latched control uses. A control whose travel does
## not mean this overrides it -- but none does yet, and a lever that commanded something
## other than where it is pointing would be lying about itself.
func command_value() -> int:
	return int(round(clampf(value.y, 0.0, 1.0) * float(maxi(channel_range, 1))))


## WHERE THE BUS SAYS THIS CONTROL IS, as a position on its own travel.
##
## The inverse of `command_value`, and the reason a switch pressed on a screen moves the
## lever in the cockpit: the page commands, the bus comes back, and this puts the handle
## where the craft says it is.
func from_command(asked: int) -> Vector2:
	return Vector2(0.0, clampf(float(asked) / float(maxi(channel_range, 1)), 0.0, 1.0))

## HOW A HAND WORKS THIS: by MOVING or by TURNING.
##
## Moving is the honest one and the default. You take hold of a stick and push it, and the
## control goes where your hand went -- which is what the thing in front of you looks like
## it should do, and is the whole appeal of a cockpit you can reach into.
##
## Turning exists because a tracked controller is not a stick. There is nothing under your
## hand to push against, so a long hold at full deflection is an arm held out in mid-air
## with nothing supporting it, and the shoulder gives out long before the aeroplane does.
## Rolling a wrist is something you can do all afternoon with your elbow on your knee.
##
## PER CONTROL, and chosen by the player on the board in their left hand. It is not a
## setting the game should be confident about: which one is better depends on the aircraft,
## the control, how long the flight is and whose arm it is.
enum Drive { TRANSLATION, ROTATION }

var driven_by: int = Drive.TRANSLATION

## HOW FAR A WRIST TURN COUNTS AS A PUSH, in metres per radian.
##
## A comfortable wrist is about 0.6 rad either way, and a stick throws 0.12 m, so 0.2 gives
## full deflection at the edge of a comfortable roll. Generous rather than exact: the point
## of this mode is that it costs no effort, and a mapping that needed the last degree of
## wrist travel would cost more than pushing did.
const ROTATION_ARM: float = 0.20


## THE WRIST TURN SINCE THE GRAB, AS THE PUSH IT STANDS IN FOR.
##
## Pitch of the wrist becomes fore-and-aft, roll becomes side-to-side. Those are the two a
## hand can make independently while holding something; yaw is left alone because turning
## the grip is already the rudder on a control column and a mode that stole it would take
## an axis away to add one.
##
## MEASURED FROM WHERE THE HAND WAS WHEN IT GRABBED, exactly as `_hand_travel` measures
## position from where it was, so taking a fresh grip re-zeroes the wrist and a control can
## be walked to the stop in stages.
func _as_if_pushed(facing: Basis) -> Vector3:
	var since: Basis = _grabbed_facing.inverse() * facing
	var euler: Vector3 = since.get_euler()
	# +X of the euler is the wrist tipping NOSE UP -- the top of the controller rolled back towards
	# you, its -Z turned towards +Y -- and that PULLS the control back: +Z. Tilt back is pull back,
	# which is what a stick does under a real hand. It was -Z until 2026-09-13, which flew every
	# control in rotation drive backwards in pitch ("rotate back should be back on the stick"), and
	# the smoke check agreed with it because its wrist was labelled nose-down and was nose-up.
	# Roll was right and is unchanged: +Z of the euler lifts the right side, which is left: -X.
	return _grabbed_at + Vector3(euler.z * -ROTATION_ARM, 0.0, euler.x * ROTATION_ARM)


## -1..1 on each axis it has. A lever uses y, a stick uses both, a button uses neither.
var value := Vector2.ZERO
## Who is holding it here: -1 nobody, otherwise 0 left hand or 1 right.
var held_by: int = -1
## WHETHER A KEY ON THIS MACHINE IS WORKING THIS CONTROL, which is what a desk has instead of a hand.
##
## `held_by` says a hand is on it and `apply` refuses to draw the wire over a control a hand is on. A player at a
## keyboard has no hand on anything, so the throttle lever they were winding with Shift was overwritten from the wire
## every render frame and the lever never left 0.000 -- see `PilotRig._wind_the_lever` for the measurement. This is the
## same rule said for the other kind of hand: while a key is working it, the control is this player's.
var worked_here: bool = false

## Whether the meshes have been built. They are built once, by whichever of `setup` and the
## editor's `_ready` gets there first.
var _built: bool = false
## The floating caption, built the first time anybody asks for one. See `show_label`.
var _label: Label3D = null
var _grabbed_at := Vector3.ZERO
var _grabbed_facing := Basis.IDENTITY
var _value_at_grab := Vector2.ZERO
var _twist_at_grab: float = 0.0


## Called once, when the cockpit is built.
func setup(seat_index: int) -> void:
	seat = seat_index
	if not _built:
		_built = true
		_build()
	_redraw()


## SO YOU CAN SEE IT IN THE EDITOR.
##
## Every control builds its own meshes in `_build`, which at runtime is called by `setup` --
## and `setup` also has to say which seat this is and whose hands may move it, which is not
## a question the editor can answer. So the editor gets the geometry and nothing else: open
## a station scene and the levers, the stick and the instruments are all there, in the right
## places, and dragging one moves it.
##
## This is the whole reason the controls are `@tool`. A cockpit you cannot see is a cockpit
## you have to run the game to lay out.
func _ready() -> void:
	if Engine.is_editor_hint() and not _built:
		_built = true
		_build()
		_redraw()


## SHOW where the control is, from the replicated position rather than from local input.
##
## Even your OWN control is drawn from the wire when somebody else could be moving it --
## and for the seat you are sitting in, the local value is applied first and the wire
## agrees a round trip later, so there is nothing to see either way.
func apply(shared: Vector2) -> void:
	# A HAND ON IT, OR A KEY ON IT. Both mean this machine's player is working the control and the wire is a round trip
	# behind them. See `worked_here`.
	if held_by >= 0 or worked_here:
		return
	if value.distance_squared_to(shared) < STILL:
		return
	value = shared
	_redraw()


## WHAT TO CALL THIS, ON THE LABEL THAT FLOATS BESIDE IT.
##
## Defaults to the name the control already answers to, which for most of them is the whole
## answer -- FLAPS is a flap lever and nothing else. It is overridden where the name does
## not say the JOB: a stick is not obviously the thing that pitches and rolls you until
## somebody says so, and "crew button" tells you its category rather than its effect.
##
## Two lines where a second one earns its place: what it is, then what it does.
func label_text() -> String:
	return control_name.to_upper()


## HOW BIG THE LABEL IS and how far above the grip it floats.
##
## Above the GRIP and not the origin, because the grip is the part you are looking at when
## you are deciding whether to reach for it -- and on a stick those are 22 cm apart.
## A LINE ABOUT A CENTIMETRE TALL, which is a caption on a lever rather than a sign over
## it. At twice this the word STICK was wider than the screen behind it -- rendered, looked
## at, and halved.
const LABEL_SIZE: int = 48
const LABEL_PIXELS: float = 0.00020
const LABEL_ABOVE: float = 0.055


## SHOW OR HIDE THE LABEL. Off by default, and a local view of the cockpit rather than a
## fact about it: nothing here goes on any wire, because what one player has chosen to have
## written on their own panel is nobody else's business.
##
## Built on first use rather than in `_build`, so a cockpit nobody has asked to label costs
## nothing -- which on a craft with four stations and a console is thirty-odd Label3Ds and
## thirty-odd draw calls that would otherwise exist to be invisible.
func show_label(on: bool) -> void:
	if not on:
		if _label != null:
			_label.visible = false
		return
	if _label == null:
		_label = Label3D.new()
		_label.name = "Label"
		_label.font_size = LABEL_SIZE
		_label.pixel_size = LABEL_PIXELS
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# NO DEPTH TEST. A label is a caption on a thing, not an object in the cockpit, and
		# at a glancing angle the console it names would otherwise be in front of it -- which
		# hides exactly the labels for the controls furthest away, the ones you needed named.
		_label.no_depth_test = true
		_label.modulate = Color(0.95, 0.82, 0.35)
		_label.outline_size = 12
		_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
		add_child(_label)
	_label.text = label_text()
	_label.position = _label_point()
	_label.visible = true


## WHERE THE LABEL HANGS, in this control's own frame: `LABEL_ABOVE` over the grip, which is what a hand reaches for. A
## control with writing of its own under that spot hangs it somewhere else -- see `DetentDial._label_point`, whose stop
## names were seen through it.
func _label_point() -> Vector3:
	return _grab_point() + Vector3(0.0, LABEL_ABOVE, 0.0)


## WHAT THE REST OF THE HAND DOES WHILE IT IS HOLDING THIS.
##
## A hand controller carries a trigger, two thumb buttons and a mini joystick besides the
## grip, and what those mean depends entirely on what is in the hand: the trigger fires the
## gun you have hold of, and a thumb button on a throttle is not the same thumb button on a
## control column. So the table lives on the control, which is the only thing that knows
## what it is.
##
## `Bind` input -> action, and anything left out falls through to the rig's global set --
## so a lever that has nothing to say about the trigger leaves the trigger doing whatever it
## does with an empty hand. `Bind.nothing()` is how a control takes an input AWAY instead,
## which a gun grip has to do to the brake.
##
## Empty here, and empty is the honest answer for most controls: a flaps lever is a flaps
## lever and your thumb has nothing to add to it.
func bindings() -> Dictionary:
	return {}


## WHAT THE HAND HOLDING THIS IS DOING WITH THE REST OF ITSELF, once per input per frame.
##
## The other half of `bindings`. A table says what an input MEANS; this is how the control
## gets to see it happening, so it can show it. A gun grip drops its trigger blade when the
## index finger pulls, and nothing else in the cockpit can say a gun is firing.
##
## Empty here, and empty is right for most controls: a flaps lever has nothing to show
## about a thumb button.
##
## GENERIC ON PURPOSE, rather than the rig reaching into GunTrigger for the one case that
## needs it today. That is the branch-in-the-rig this whole arrangement exists to avoid,
## and the next control that wants to light up under a thumb should not have to add one.
func hand_input(_input: int, _down: bool) -> void:
	pass


## ---- something a hand should FEEL --------------------------------------------------

## SOMETHING HAPPENED THAT A HAND SHOULD FEEL: a detent crossed, a trigger pulled.
##
## The control ANNOUNCES it and does not act on it, which is the same split the rest of
## this cockpit runs on -- a page is handed its data, a switch emits a command, and here a
## knob says it clicked. Only the rig has a motor to buzz, and only the rig knows which
## HAND is on this, so only the rig can do anything with it. A control that reached for
## `PilotRig` to pulse would be a control that cannot be built in the hall, on a bench, in
## the editor or in a test.
##
## The name is one of `PilotRig.FEEL`'s, so what a detent feels like is decided in one
## place rather than typed into every control that has one.
var _bump: StringName = &""


## Say that this control just did something worth feeling.
func bump(what: StringName) -> void:
	_bump = what


## WHAT IT DID, AND IT IS DRAINED BY THE READING. Same rule as `Sim.cues`: a moment is
## delivered once. Left set, a detent would be felt again on every frame the hand stayed on
## the knob, which at the display rate is a knob that vibrates rather than clicks.
func take_bump() -> StringName:
	var was: StringName = _bump
	_bump = &""
	return was


## BE TAKEN HOLD OF. `hand` is 0 left, 1 right; `at` and `facing` are the hand's position and
## orientation in this control's OWN space, which is what makes the maths below independent
## of where the aeroplane is or what it is doing.
##
## `closed` IS HOW FAR THE FINGER THAT TAKES THIS ONE IS SHUT, and which finger that is comes
## from `taken_by`: the hand's grip on a stick, the index trigger on a switch. One number
## either way, so nothing below this line knows there are two gestures -- which is the whole
## reason the pinch cost no control class anything.
func offer_hand(hand: int, at: Vector3, closed: float,
		facing: Basis = Basis.IDENTITY) -> void:
	if held_by == hand:
		if closed < GRAB_OFF:
			release()
			return
		# MOVED OR TURNED, and the control below cannot tell which. `_drag` takes a place a
		# hand is; in rotation mode it is handed the place the hand WOULD be if the wrist's
		# turn had been a push instead. Every `_drag` in the game therefore works in both
		# modes without knowing either exists, which is the only reason this is a switch
		# rather than a second implementation of every control.
		_drag(at if driven_by == Drive.TRANSLATION else _as_if_pushed(facing))
		_turn(facing)
		return
	# Measured to the part you actually take hold of, which is not the origin. A stick's
	# grip is twenty centimetres up its shaft, so a hand ON it is well outside a reach
	# measured from the base -- and the control simply could not be picked up, while
	# looking exactly as though it should be.
	if held_by >= 0 or closed < GRAB_ON or at.distance_to(_grab_point()) > REACH:
		return
	held_by = hand
	_grabbed_at = at
	_grabbed_facing = facing
	_value_at_grab = value
	_twist_at_grab = twist
	_on_grabbed()


## BE PICKED UP AND PUT SOMEWHERE ELSE, rather than worked.
##
## The cockpit builder's grab. `offer_hand` above asks what the hand DID to this control;
## this one asks where the hand WENT, and moves the control with it. A lever being dragged
## across the console does not open the throttle on the way past.
##
## `hand_at` IS IN THE PARENT'S FRAME -- the station's -- and not in this control's own,
## which is the one real difference between the two and the reason this is a second entry
## point rather than a flag on the first. Every other grab in the game measures the hand
## against the control it is holding; here the control is the thing that moves, so measuring
## against it would be measuring a ruler with itself. The station holds still and both the
## hand and the lever are placed in it.
##
## THE WHOLE HAND, so a wrist turns a lever as well as sliding it. A cockpit laid out by
## dragging alone would be a cockpit of levers that all face forward, and half the reason a
## throttle quadrant is reachable is that it is raked over towards the hand.
func offer_hand_to_place(hand: int, hand_at: Transform3D, grip: float) -> void:
	if held_by == hand:
		if grip < GRAB_OFF:
			release()
			return
		# WHERE IT WOULD BE IF IT HAD BEEN WELDED TO THE HAND when the hand closed. Not an
		# offset added to a position: a lever picked up by its top and rolled is a lever
		# that pivots about the hand, which is what holding something actually does.
		transform = hand_at * _hand_when_lifted.affine_inverse() * _lifted_from
		if _label != null and _label.visible:
			_label.position = _label_point()
		return
	if held_by >= 0 or grip < GRAB_ON:
		return
	if hand_at.origin.distance_to(transform * _grab_point()) > REACH:
		return
	held_by = hand
	_lifted_from = transform
	_hand_when_lifted = hand_at


## WHERE THIS AND THE HAND HOLDING IT BOTH WERE when it was picked up. See
## `offer_hand_to_place`; untouched by every other kind of grab.
var _lifted_from := Transform3D.IDENTITY
var _hand_when_lifted := Transform3D.IDENTITY


## WHETHER A HAND MAY PICK THIS UP AND CARRY IT WHILE FLYING, rather than only while the cockpit
## builder is on.
##
## FALSE FOR EVERYTHING EXCEPT THE DIRECTOR'S CAMERA, and that asymmetry is the honest one. A throttle
## that came off its quadrant in flight is a throttle somebody has dropped over the Atlantic; the
## builder is a mode precisely so that moving the furniture and flying the aeroplane are different
## activities. A camera is the exception because framing a shot IS the activity -- "grab it with my
## hand and move it", asked for on 2026-09-15 -- and you cannot be in the builder while doing anything
## worth recording.
##
## Read by `PilotRig._work_the_controls` beside `placing()`. What it selects is `offer_hand_to_place`,
## which already knows how to pivot a thing about the hand that lifted it.
func carried_by_hand() -> bool:
	return false


## OTHER CONTROLS THIS ONE BRINGS WITH IT, and which must be reachable although they are not children
## of the station.
##
## Empty for everything but the director's camera, whose keypad is bolted to its back and has to travel
## with it. `CockpitStation.controls()` walks its own children, so a control on a control would
## otherwise be a control no hand can reach -- and `CockpitLayout` walks the same children, so what is
## carried is saved with its carrier rather than as a part of its own, which is right: you do not place
## a keypad, you place a camera.
##
## ANNOUNCED BY THE PART rather than looked for by the station. The station has no business knowing
## that a camera has a keypad on it, and a station that went hunting for VehicleControls at any depth
## would also find the ones a future part keeps deliberately out of reach.
func carries() -> Array[VehicleControl]:
	return []


## WHETHER ONLY THE PLAYER IN THIS CONTROL'S OWN SEAT MAY TAKE HOLD OF IT.
##
## False for everything but the signal lamp, and false is the rule the rest of the cockpit is built on: a
## hand reaches across the flight deck to the other seat's levers, because that is what two people in one
## cockpit do. A lamp is the exception because it speaks for its seat -- what it flashes is shown to the
## world as that seat's signal (`SignalLamp`) -- so the copilot flashing the pilot's lamp would be a signal
## from the wrong person. `PilotRig._gather_reachable` reads it.
func own_seat_only() -> bool:
	return false


## WHERE THE HAND HAS TO BE to take hold of this, in world space.
##
## The part you HOLD and not the origin, which on a stick is 22 cm up its own shaft and on
## a yoke is 17 cm out from the mount. Anything placing these -- or checking they are
## placed within reach -- has to ask this and not read `position`.
func grip_global() -> Vector3:
	return global_transform * _grab_point()


func release() -> void:
	if held_by < 0:
		return
	held_by = -1
	_on_released()
	_redraw()


## SPRING BACK, at `centring` fractions per second. Only while this machine's player is
## holding nothing: a control moved by the other seat is being driven from the wire and
## must not also be centring locally.
##
## Zero means it stays where it is put, which is the whole difference between a throttle
## and a stick and the reason one is on the command bus and the other on the input frame.
func relax(delta: float) -> void:
	if centring <= 0.0 or is_held():
		return
	if value.length_squared() < 0.000001 and absf(twist) < 0.001:
		return
	var back: float = clampf(delta * centring, 0.0, 1.0)
	value = value.lerp(Vector2.ZERO, back)
	twist = lerpf(twist, 0.0, back)
	_redraw()
	moved.emit(self)


## ROLL AND PITCH, in the sign convention ControlInput uses: +1 right wing down, +1 nose up.
##
## Here rather than on the stick because a YOKE answers them too, and the seat in front of
## you may have either. Asking the base class is what lets a rig hold "the thing that flies
## it" without caring which -- typing that as a FlightStick crashed the moment somebody sat
## down in the airliner.
func roll() -> float:
	return clampf(value.x, -1.0, 1.0)


## HOW FAR OPEN A ONE-AXIS LEVER IS, 0 shut and 1 wide.
##
## Here beside roll and pitch, and for the same reason: the lever beside you may be a
## throttle quadrant or a helicopter's collective, and the rig asks the same question of
## either without caring which it got.
func throttle() -> float:
	return clampf(value.y, 0.0, 1.0)


## HOW MUCH RUDDER, in ControlInput's convention: +1 is nose right.
func rudder() -> float:
	return clampf(twist, -1.0, 1.0)


## HOW MUCH BRAKE, 0 off and 1 hard on. Zero on everything that is not a brake.
##
## Every control answers all five axes and the base class answers them all neutrally, which
## is what lets a cockpit be a LIST of controls rather than a fixed set of named ones. A
## locomotive has two levers and no stick, a car has a wheel with no pitch axis, and the rig
## does not have to know either: it asks each control what it is asking for and adds it up.
func brake() -> float:
	return 0.0


func pitch() -> float:
	return clampf(value.y, -1.0, 1.0)


func is_held() -> bool:
	return held_by >= 0


## WORKED BY FEET AND NOT BY HANDS. False on everything a hand works; true on `RudderPedals`, which stand on the floor of
## the footwell more than a metre from a seated shoulder, where a reach measured from a shoulder has nothing to say about
## them. See tests/fit.gd.
func under_foot() -> bool:
	return false


## WHICH FINGER TAKES HOLD OF THIS, and therefore which one has to close before `offer_hand`
## will do anything. `Bind.Take.GRIP` unless the part says otherwise.
##
## Asked for on 2026-09-15: "it's more natural to grab joysticks or wheels and 'pinch'
## buttons and switches." Before that day one grab took everything -- see `Bind`, whose doc
## block said so -- and the whole of this is that a bat switch the size of a fingernail was
## worked by closing a whole fist over it.
##
## AND IT DECIDES THE RELEASE AS WELL AS THE TAKING. A grabbed control latches on a tapped
## fist and is let go of by a second tap; a pinched one is released the instant the trigger
## lifts, however brief the pull was. See `Bind.Take`, which carries the reason in the user's
## own words: you hold a switch only until it is at the setting you want.
##
## A PROPERTY OF THE KIND AND NOT OF THE RIG, which is why this needed no new input path.
## `PilotRig` asks each control what takes it and hands `offer_hand` the reading of THAT
## finger; the control below goes on believing one number, exactly as it did.
##
## EACH PART ANSWERS FOR ITSELF, AND THE ANSWER IS NOT DERIVED FROM `faces_the_eye`. Every
## part that faces the eye today is also a part that is pinched, so the derivation would
## work and would be one line instead of five. It was rejected because the two are different
## questions that happen to agree: one is about which way a part is TURNED when the builder
## puts it down, the other about which finger takes it. A gun grip that had to be aimed at
## the eye, or a screen worked with a whole hand, would then be a part that could not say so
## -- and the failure would look like the builder's fault rather than like a missing answer.
func taken_by() -> int:
	return Bind.Take.GRIP


## WHETHER THIS PART IS READ RATHER THAN PUSHED ALONG AN AXIS: a dial, a knob, a switch, a button, a screen. One the builder
## adds is turned about the vertical to face the seat. A lever, a throttle, a wheel, a stick or the pedals keep the seat's
## forward, because they are worked along their own axes, and a throttle turned to face the eye pushes diagonally
## (2026-09-14). See `PilotRig.place_a_new_control`.
func faces_the_eye() -> bool:
	return false


## ---- for subclasses -----------------------------------------------------------------

## WHERE THE HAND GOES, in this control's own space. The origin unless a subclass says
## otherwise -- see the note in offer_hand.
func _grab_point() -> Vector3:
	return Vector3.ZERO


## Build the meshes. Called once.
func _build() -> void:
	pass


## Put the meshes where `value` says they are. Called whenever it changes.
func _redraw() -> void:
	pass


## A held hand has moved to `at`, in this control's space.
func _drag(at: Vector3) -> void:
	pass


## A held hand has TURNED to `facing`, in this control's space. Only a control that twists
## does anything with it.
func _turn(facing: Basis) -> void:
	pass


## THE ANGLE A HAND IS TURNED THROUGH about `axis`, in radians, from where it was when it
## took hold. Both bases are in this control's space.
##
## Measured off the hand's ACROSS vector projected flat against the axis, which is the one
## direction a wrist rolling about a stick actually moves. Taking the whole rotation and
## reading a Euler angle out of it would pick up the arm swinging as well.
func _turned_about(axis: Vector3, facing: Basis) -> float:
	var was: Vector3 = _flat(_grabbed_facing.x, axis)
	var now: Vector3 = _flat(facing.x, axis)
	if was.length_squared() < 1e-6 or now.length_squared() < 1e-6:
		return 0.0
	return atan2(was.cross(now).dot(axis), was.dot(now))


static func _flat(v: Vector3, axis: Vector3) -> Vector3:
	return v - axis * v.dot(axis)


func _on_grabbed() -> void:
	pass


func _on_released() -> void:
	pass


## ---- small shared helpers ------------------------------------------------------------

func _hand_travel(at: Vector3) -> Vector3:
	return at - _grabbed_at


func _grab_value() -> Vector2:
	return _value_at_grab


## HOW LITTLE COUNTS AS NOT MOVING. Compared as a squared distance, so this is the square
## of the smallest movement worth telling anybody about -- a thousandth of the travel,
## which is finer than the wire's own quantisation of 1/128 of an axis.
const STILL: float = 0.000001


## PUT THE CONTROL WHERE THE HAND ASKS, and say so if it actually moved.
##
## Every `_drag` works out `wanted` its own way -- that is what makes a collective
## different from a yoke -- and then all of them do exactly this with the answer. It used
## to be written out at the end of all six, and the copies had already drifted: the
## throttle compared a scalar against 0.0005 where its five siblings compared a squared
## distance against 0.000001, so it needed twice the movement before it would report one,
## for no reason anybody had written down.
##
## Returning early on a movement too small to see is not a micro-optimisation. `moved`
## reaches the rig, which folds it into the control frame that goes on the wire every
## tick, so a control that emitted on floating-point noise would be sending a fresh
## position for a hand that is holding still.
func _settle(wanted: Vector2) -> void:
	if wanted.distance_squared_to(value) < STILL:
		return
	value = wanted
	_redraw()
	moved.emit(self)


func _make_mesh(mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.55
	node.material_override = material
	add_child(node)
	return node


static func _tint(node: MeshInstance3D, colour: Color) -> void:
	(node.material_override as StandardMaterial3D).albedo_color = colour
