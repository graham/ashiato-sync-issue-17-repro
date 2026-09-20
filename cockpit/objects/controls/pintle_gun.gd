@tool
extends VehicleControl
class_name PintleGun
## A MACHINE GUN ON A SWIVEL, TAKEN HOLD OF AND POINTED.
##
## Every other gun in this game is laid with a JOYSTICK: a stick in front of the gunner
## whose deflection is a traverse RATE, which is what a powered mount is and what a tank or
## a gunship has. A door gun is not that. It is thirty pounds of steel on a bearing with a
## man's shoulders behind it, and where it points is wherever his arms have put it.
##
## So this control has no travel of its own. The gun follows the HAND: the hand's angle
## away from the grips is an error, the error is the demand, and the demand runs the same
## mount the joystick runs. Let go and it stays where it was left. Push and it swings until
## the grips are back under your hand, which is the whole of what a swivel feels like.
##
## WHICH WAY ROUND IT MOVES IS THE PHYSICAL ONE, and it takes about two seconds to get used
## to: the grips are BEHIND the trunnion, so pushing them right swings the muzzle left. That
## is not a sign to flip. It is what a gun on a pin does, it is why the gun is drawn as one
## object hinged in the middle rather than as a stick, and it is the reason for putting the
## thing in somebody's hands instead of a joystick in front of them.
##
## THE ERROR IS MEASURED IN THE GUN'S OWN FRAME, which is what makes it a servo rather than
## an integration. `PilotRig` hands every control the hand pose in that control's own space;
## this one turns that pose by the gun's live angle first, so "where the hand is" is asked
## relative to where the gun IS rather than where it was when the hand closed. Nothing
## accumulates, so nothing drifts: a hand held still is an error of zero and a gun that has
## stopped.
##
## WHAT IS DRAWN AND WHERE. Nothing here builds a gun. The barrel, the receiver, the ammo
## box and the spade grips are drawn ONCE, by `VehicleView._build_turret`, in the vehicle's
## own frame -- because a gun hanging out of a door is a thing everybody outside can see,
## and two copies of it, one for the cockpit and one for the world, is two guns to keep in
## step and a pair of them z-fighting in the doorway. The only thing this adds is the
## BUTTERFLY TRIGGER between the grips, which is the one part of a gun that has to move for
## the person holding it and for nobody else.

## WHERE THE HANDS GO, in metres from the trunnion, along the gun.
##
## SHARED WITH THE THING THAT DRAWS THE GUN -- see `VehicleView._build_turret` -- because
## the grips a hand reaches for have to be the grips it can see. Two numbers, one here and
## one over there, is a gun you grab at thin air beside.
const GRIP_BACK: float = 0.30
const GRIP_RISE: float = 0.055
## How far apart the two spade grips are. A hand takes hold in the MIDDLE of them, which is
## also where the trigger is: this is one control with two handles, not two controls.
const GRIP_SPREAD: float = 0.13
## How far the butterfly trigger moves when it is pressed, in metres.
const PRESS: float = 0.010

## HOW HARD IT CHASES THE HAND, in demand per radian of error.
##
## Full demand at about ten degrees out, which with a hand-swung mount's slew rate settles
## in something under a tenth of a second and never overshoots: the loop gain per tick is
## slew * FOLLOW * dt, which at 3 rad/s and 120 Hz is 0.15, and anything below 1 cannot
## oscillate. Higher than this and a network round trip starts to ring; lower and the gun
## feels like it is on a spring.
const FOLLOW: float = 6.0
## Below this the hand is on top of the trunnion and the angle to it means nothing.
const TOO_CLOSE: float = 0.06

## The part that swings. Everything drawn or measured in gun space hangs off this, so that
## the control's own transform stays exactly where the gun is BOLTED and only this turns.
var _gun: Node3D = null
var _blade: MeshInstance3D = null
## Whether the hand on the grips is pulling the controller's trigger. Same arrangement as
## the gun grip beside a powered mount: the fist holds the gun, the finger fires it.
var _pulled: bool = false
## Which mount this is, so a helicopter's two door guns each answer their own.
var mount: int = 0

## ---- WHERE THIS MACHINE BELIEVES THE MOUNT IS ----------------------------------------
##
## THE BUG THIS EXISTS FOR, and it is the most valuable sentence in the file: a door gun held by
## somebody who had JOINED a session swung back and forth at nearly full speed with their hand held
## still, while the same gun on the host worked perfectly. Nothing was wrong with the gun, the
## wire, the seats or the mount. `_drag` is a PROPORTIONAL SERVO -- hand-to-grips angle times
## `FOLLOW`, asked for as a traverse RATE -- and `aim_turret` is a pure INTEGRATOR. A proportional
## controller round an integrator is stable only while the loop is fast compared with the lag in
## its feedback, and the feedback ran all the way to the server and back, because `aim_turrets()`
## is server-only and the angle `point_at` is handed is the angle the server last SENT. The loop's
## own time constant is 1 / (FOLLOW * slew) = 56 ms; a host's own client has about none of that and
## everybody who joined has a round trip of it. Measured, `tests/gun_link.gd`: 1.8 degrees of
## travel in the second after the hand stopped over a link with no delay, 141 degrees over a 133 ms
## one, out of a slew rate of 172.
##
## SO THE LOOP IS CLOSED HERE INSTEAD. This machine has the input for its OWN mount -- it is the
## hand on the grips -- so it works out where the mount has got to itself, at the mount's own rate
## and against the mount's own stops, exactly as `aim_turret` does. The error is measured against
## THAT, so there is no delay in the loop at all and a gun on a bad link behaves the way it always
## behaved on the host. The rule underneath is the one the whole project runs on, applied one step
## too coarsely: PREDICT ONLY WHAT YOU HAVE THE INPUT FOR. `CraftSystems` is not predicted because
## a turret aimed by SOMEBODY ELSE is not something you have the input for -- which says nothing
## about the one you are aiming yourself.
##
## REJECTED: turning `FOLLOW` down until the loop is slow enough to be stable over a bad link. That
## is a number that hides the fault rather than removing it -- it would have to come down to about
## 1.0, which is a gun that takes half a second to answer a push, and it would still come apart on
## a worse link. REJECTED ALSO: predicting the mount in the simulation, on the client, in C++.
## `CraftSystems` is a Step component that never rolls back, so a locally advanced value would be
## overwritten by every record that arrived, which is a sawtooth rather than a fix -- and it is a
## change to the meaning of a replicated component for a fault that lives entirely in one control.
##
## HOW THE MOUNT MOVES, from the simulation's own gun table: the traverse rate, where the mount
## rests, how far it trains either side of that and how far it elevates. Set by
## `CockpitStation._fit_the_gunners_stick` from `gun_schema`, never typed here -- the arithmetic
## below has to be `aim_turret`'s arithmetic or the belief drifts from the truth by construction.
var slew: float = 3.0
var rest_yaw: float = 0.0
var yaw_span: float = PI
var pitch_low: float = -1.0
var pitch_high: float = 1.0

## WHERE THIS MACHINE BELIEVES THE MOUNT IS, and what the wire last said. `_led` is what the gun is
## DRAWN from -- in the cockpit and outside it, see `VehicleView.draw_turrets_at` -- because a
## reticle hanging off a gun and a barrel hanging out of a door have to be the same object.
var _led := Vector2.ZERO
var _wire := Vector2.ZERO
## Whether this machine's hand is out ahead of the wire. False on a gun nobody here is holding,
## which is then drawn straight from the wire exactly as it always was.
var _leading: bool = false
## True once the wire has said anything at all, so a gun's first frame is the wire's and not zero.
var _known: bool = false
## How long the wire has been saying the same thing, in seconds. See `lead`.
var _wire_still: float = 0.0
## How far round the seat this station is bolted, kept from the last `point_at` so `lead` can draw.
var _seat_yaw: float = 0.0

## HOW FAST THE BELIEF IS PULLED BACK ONTO WHAT THE SERVER SAYS, in fractions per second, and how
## long the wire has to have held still before it is -- because the server is a round trip behind,
## and a belief dragged toward a value that is still catching up would pull the gun back into the
## swing it had just finished, which is the ringing this whole mechanism exists to remove. Waiting
## for the wire to stop moving is waiting for the server to have obeyed everything already sent.
const ANCHOR: float = 4.0
const WIRE_SETTLED_S: float = 0.10
## Below this a demand is a hand asking for nothing; below this the belief and the wire are the
## same place, at a fifth of a slew step; and below this the wire has not moved. All in radians
## except the first, which is a fraction of full demand.
const ASKING: float = 0.02
const TOGETHER: float = 0.005
const WIRE_MOVED: float = 0.002


func _build() -> void:
	control_name = "gun"
	scope = Scope.SEAT
	_gun = Node3D.new()
	_gun.name = "Swivel"
	add_child(_gun)
	# THE BUTTERFLY TRIGGER, between the grips where both thumbs land. The only piece of
	# the gun that is drawn in here, because it is the only piece whose position is about
	# the person holding it rather than about the gun.
	var paddle := BoxMesh.new()
	paddle.size = Vector3(GRIP_SPREAD * 0.55, 0.016, 0.012)
	_blade = MeshInstance3D.new()
	_blade.mesh = paddle
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.82, 0.20, 0.16)
	red.roughness = 0.5
	_blade.material_override = red
	_gun.add_child(_blade)
	_redraw()


## THE SIGHT, ON THE GUN RATHER THAN ON THE COCKPIT.
##
## Everything else a station fits sits still while the gun moves. A reticle has to do the
## opposite: it is only worth anything if it is looking down the barrel, and this barrel
## swings ninety degrees either side of the door. So it hangs off the swivel with the rest
## of the gun, and CockpitStation drives it exactly as it drives a fixed one.
func fit_sight(sight: Node3D) -> void:
	if _gun == null:
		_built = true
		_build()
	_gun.add_child(sight)


## WHAT THE WIRE SAYS THE MOUNT IS DOING, once a frame.
##
## `aim` is what the wire carries, in the CRAFT's frame; `seat_yaw` is how far round the
## seat this station is bolted to has been turned. Subtracting one from the other is the
## whole of the conversion, because a station is a child of its seat anchor and the anchor
## is the only thing between here and the vehicle.
##
## Driven from `VehicleView.draw` rather than from the station's five-a-second state pass:
## the gun is a thing in your hands and it has to move on the frame, and it has to move on
## the SAME interpolated angles as the barrel everybody outside is looking at.
##
## IT IS NO LONGER WHAT THE GUN IS DRAWN FROM WHEN A HAND HERE IS ON IT. See `lead`, which
## is the other half of this and the whole of the fix for a client's gun running away.
func point_at(aim: Vector2, seat_yaw: float) -> void:
	if _gun == null:
		return
	_seat_yaw = seat_yaw
	if not _known or absf(angle_difference(_wire.x, aim.x)) > WIRE_MOVED \
			or absf(_wire.y - aim.y) > WIRE_MOVED:
		_wire_still = 0.0
	_wire = aim
	_known = true
	# A GUN NOBODY HERE IS HOLDING IS THE WIRE'S, with nothing in between: that is every other gun
	# on every other aircraft, and it is what this has always done.
	if not _leading:
		_led = aim
	_show()


## WHERE THE MOUNT HAS GOT TO, once a frame, worked the way the server works it.
##
## The other half of `point_at`, and the reason a client's gun stops when the hand does. While this
## machine's hand is on the grips the belief is advanced by the demand the hand is making, at the
## mount's own rate and against its own stops -- so `_drag` measures its error against a gun that is
## where the hand has put it rather than where the server last said it was.
##
## AND IT IS PUT BACK ON THE TRUTH WHEN THERE IS NOTHING LEFT TO PREDICT. The belief and the server
## integrate the same demands, but not necessarily the same NUMBER of them: a jittery link makes
## sync use one input frame twice or skip one, and either leaves the two a fraction of a degree
## apart for good. So once the hand has stopped asking for anything AND the wire has stopped moving
## -- which together mean the server has obeyed everything already sent -- the belief eases onto the
## wire. The same easing carries a gun back onto the wire after the hand lets go; a straight
## assignment there would jump the barrel back by however far it had swung in the last round trip.
##
## A SEAM ON THE CLASS AND NOT A WALK IN THE RIG. `_process` calls it in the game; a test calls it
## with the step it is running at, which is how `tests/gun_link.gd` runs three seconds of gunner
## over four different links in a fraction of a second.
func lead(delta: float) -> void:
	if _gun == null:
		return
	_wire_still += delta
	var holding: bool = is_held()
	if holding:
		_leading = true
		# EXACTLY `aim_turret`'S ARITHMETIC. Roll is negated into yaw and pitch is not, the yaw stop
		# is measured as a difference from REST so that a mount resting near half a turn -- the
		# Chinook's ramp gun -- has no seam at the wrap, and the elevation is a plain clamp.
		_led = Vector2(_trained(_led.x - value.x * slew * delta),
			clampf(_led.y + value.y * slew * delta, pitch_low, pitch_high))
		# NOTHING TO BE PUT BACK ONTO, EITHER, UNTIL THE WIRE HAS SAID SOMETHING. A station stood on
		# a bench in the hall of cockpits has no simulation behind it and no mount to be ahead of,
		# and a gun there that eased toward an unset wire would creep home under the hand holding it.
		if not _known or value.length() > ASKING or _wire_still < WIRE_SETTLED_S:
			_show()
			return
	elif not _leading:
		return
	var back: float = clampf(delta * ANCHOR, 0.0, 1.0)
	_led = Vector2(_led.x + angle_difference(_led.x, _wire.x) * back,
		lerpf(_led.y, _wire.y, back))
	if absf(angle_difference(_led.x, _wire.x)) < TOGETHER and absf(_led.y - _wire.y) < TOGETHER:
		_led = _wire
		_leading = holding
	_show()


## WHERE THIS MACHINE IS DRAWING THE MOUNT, for anything outside the cockpit that draws the same
## gun -- which is `VehicleView.draw_turrets_at`, and it has to agree, or the barrel in the doorway
## and the sight on top of it part company by a round trip exactly while somebody is swinging it.
func led_aim() -> Vector2:
	return _led


## WHETHER THIS MACHINE IS OUT AHEAD OF THE WIRE about this mount. False on every gun nobody here
## is holding, which is when `led_aim` is the wire's own value anyway.
func is_leading() -> bool:
	return _leading


## HOW THE MOUNT MOVES, taken from the simulation's gun table rather than written down twice. See
## `CockpitStation._fit_the_gunners_stick`, which is the only caller in the game.
func fit_the_mount(schema: Dictionary) -> void:
	slew = float(schema.get("slew", slew))
	var rest: Vector2 = schema.get("rest", Vector2(rest_yaw, 0.0)) as Vector2
	rest_yaw = rest.x
	yaw_span = float(schema.get("yaw_span", yaw_span))
	var pitch: Vector2 = schema.get("pitch_range", Vector2(pitch_low, pitch_high)) as Vector2
	pitch_low = pitch.x
	pitch_high = pitch.y


## WITHIN WHAT THE MOUNT WILL ACTUALLY DO, as a difference from where it rests. `aim_turret`'s own
## clamp, copied deliberately and named so: a span of half a turn or more is a mount with no stops.
func _trained(yaw: float) -> float:
	var off: float = wrapf(yaw - rest_yaw, -PI, PI)
	return wrapf(rest_yaw + (clampf(off, -yaw_span, yaw_span) if yaw_span < 3.0 else off),
		-PI, PI)


func _show() -> void:
	if _gun == null:
		return
	_gun.basis = Basis(Vector3.UP, _led.x - _seat_yaw) * Basis(Vector3.RIGHT, _led.y)


## ONCE A FRAME, IN THE GAME. Guarded against the editor, where a `@tool` control is geometry and
## nothing else and there is no simulation for it to be ahead of.
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	lead(delta)


## THE GRIPS, in the control's own space -- which is to say, wherever the gun has swung them
## to. Everything that reaches for a control asks this rather than reading `position`, so a
## moving grab point is something the rig already copes with.
func _grab_point() -> Vector3:
	var at := Vector3(0.0, GRIP_RISE, GRIP_BACK)
	return (_gun.basis * at) if _gun != null else at


func _redraw() -> void:
	if _blade == null:
		return
	_blade.position = Vector3(0.0, GRIP_RISE - 0.045, GRIP_BACK - 0.02
		+ (PRESS if _pulled else 0.0))


## WHAT THE HAND ASKS THE MOUNT FOR: the angle it is away from the grips, in the gun's own
## frame, on each of the two axes the mount has.
##
## Two plane rotations rather than one axis-and-angle, because that is what the mount is:
## it trains about the vehicle's vertical and elevates about its own trunnion, and an
## arbitrary rotation between two vectors would ask it for a roll it does not have.
func _drag(at: Vector3) -> void:
	if _gun == null:
		return
	# INTO THE GUN'S FRAME. The hand arrives in the control's space, which is bolted to the
	# aircraft; the error that matters is measured against where the gun is NOW.
	var hand: Vector3 = _gun.basis.inverse() * at
	var rest := Vector3(0.0, GRIP_RISE, GRIP_BACK)
	if Vector2(hand.x, hand.z).length() < TOO_CLOSE:
		return
	# TRAVERSE: the bearing of the hand about the gun's own vertical, against the bearing of
	# the grips. Positive turn is a positive yaw on the mount, and the mount takes a
	# NEGATIVE roll for that -- the sign the stick has always carried, kept here so that the
	# two ways of aiming a gun ask for the same thing.
	var turn: float = wrapf(atan2(rest.z, rest.x) - atan2(hand.z, hand.x), -PI, PI)
	# ELEVATION: the same thing in the vertical plane through the gun. Lifting the grips
	# depresses the barrel, which is what a gun hinged in the middle does.
	var lift: float = wrapf(atan2(rest.y, rest.z) - atan2(hand.y, hand.z), -PI, PI)
	_settle(Vector2(clampf(-turn * FOLLOW, -1.0, 1.0),
		clampf(lift * FOLLOW, -1.0, 1.0)))


## NOTHING ON THE WIRE MOVES THIS, and that is the difference between a gun and a lever.
##
## What another seat's hands did is already here: the mount's two angles are replicated on
## the craft, and `point_at` draws the gun from them -- so the whole crew watches the gun
## swing whoever is on it. `value` is not a position at all, it is what the hand is ASKING
## the mount for, and applying somebody else's demand would move nothing and mean nothing.
func apply(_shared: Vector2) -> void:
	pass


## A GUN NOBODY IS HOLDING IS ASKING FOR NOTHING. Without this the last demand before the
## hand let go stays on the frame, and the mount goes on creeping in that direction.
func _on_released() -> void:
	value = Vector2.ZERO
	_pulled = false
	_redraw()


## PULL THE TRIGGER TO FIRE IT, and nothing else on the hand does anything.
##
## The trigger is the only binding a hand on a machine gun needs, and the other three are
## `nothing` on purpose rather than left out. The global set puts the BRAKE on the trigger
## and the craft and seat browsers on the thumb, so a gunner who left them alone would slow
## the aircraft down every time they fired and change helicopter with their thumb while
## laying the gun. There is no ammunition selector because there is no choice: a belt-fed
## machine gun has a belt in it -- see `Gun::rack` in the simulation.
func bindings() -> Dictionary:
	return {
		Bind.TRIGGER: Bind.fire(),
		Bind.THUMB_LOW: Bind.nothing(),
		Bind.THUMB_HIGH: Bind.nothing(),
		Bind.STICK_CLICK: Bind.nothing(),
	}


## The finger, so the trigger between the grips goes down while the gun is firing. See
## VehicleControl.hand_input.
func hand_input(input: int, down: bool) -> void:
	if input != Bind.TRIGGER or _pulled == down:
		return
	_pulled = down
	_redraw()
