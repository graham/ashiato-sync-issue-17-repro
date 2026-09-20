@tool
extends VehicleControl
class_name GunTrigger
## THE GRIP A GUNNER HOLDS, WITH THE TRIGGER ON THE SIDE THEY CAN SEE.
##
## A pistol grip on a stalk. It has no axes and remembers nothing: all anybody asks it is
## whether a hand is on it, and -- since the finger took the firing over from the fist --
## whether that hand is pulling the trigger.
##
## IT WAS BUILT FACING THE WRONG WAY. The blade sat on the far face of a plain block, three
## centimetres beyond it, so from the only seat that will ever reach for this the red was
## behind the grey and there was nothing to see but a small dark box on the console. The
## grab point was out there with it, which meant reaching THROUGH the housing for a part of
## the control that was never visible in the first place. A cockpit is judged from one
## viewpoint and this had never been looked at from it -- see tests/station_shot.gd, which
## is how it finally was.
##
## So the blade hangs in a guard on the gunner's side of the grip now, where a finger and
## an eye both already are, and it is pulled TOWARD them -- which is the way a trigger moves
## and, more to the point, somewhere they can watch it move.
##
## IT IS A LEVEL, NOT A COMMAND, and that is the difference between it and the crew button
## beside it. A crew button toggles a lamp, so it fires once per press and has to re-arm.
## A trigger is HELD -- that is what a rotary cannon at thirty rounds a second is -- so it
## reports its state every frame and the SERVER decides what a held trigger means. Which is
## the same rule the rest of the buttons follow: an input frame is replayed during a
## rollback, so "just pressed" is the server's to work out.
##
## What turns that into rounds is the binding below, which puts the fire bit on the input
## frame while the controller's trigger is down, and `CockpitWorld`, which fires the gun
## again every time it has reloaded for as long as the bit is there.

## How far the blade travels when it is pulled, in metres. Toward the gunner: +Z.
const PULL: float = 0.014
## How far the stalk stands above its mount, in metres.
const RISE: float = 0.11
## Where the palm goes, and where the blade hangs, above the mount. The blade is BELOW the
## grip and on the gunner's side of it, so that the grip does not stand in front of it.
const GRIP_AT: float = 0.135
const BLADE_AT: float = 0.095
## How far back the blade sits, past the grip's rear face at z = 0.040.
const BLADE_Z: float = 0.050
## HOW FAR BACK THE GRIP LEANS, in radians. A grip square to the floor is one a wrist has to
## break to hold; every gun grip ever made leans away from the muzzle.
const RAKE: float = 0.30

var _lever: MeshInstance3D = null
## Whether the hand on this is pulling the controller's trigger. Set by the rig through
## `hand_input`, because the FINGER fires now and the fist only holds -- see `bindings`.
var _pulled: bool = false


## The grip holds it and the FINGER fires it, which is the one thing about this control
## that is not obvious from looking at it.
func label_text() -> String:
	return "GUN\nPULL TRIGGER"


func _build() -> void:
	control_name = "trigger"
	scope = Scope.SEAT
	# THE STALK, up off the console so a hand can close round the grip without the console
	# being in the way of the knuckles.
	var post := BoxMesh.new()
	post.size = Vector3(0.030, RISE, 0.034)
	var stalk := _make_mesh(post, Color(0.12, 0.12, 0.14), Vector3(0.0, RISE * 0.5, 0.0))
	stalk.rotation = Vector3(RAKE, 0.0, 0.0)
	# THE GRIP, raked back toward the gunner. A handle square to the floor is one a wrist
	# has to break to hold, and every gun grip ever made leans away from the muzzle.
	var hand := BoxMesh.new()
	hand.size = Vector3(0.046, 0.070, 0.048)
	var held := _make_mesh(hand, Color(0.17, 0.17, 0.20), Vector3(0.0, GRIP_AT, 0.016))
	held.rotation = Vector3(RAKE, 0.0, 0.0)
	# THE GUARD, a hoop below the grip ON THE GUNNER'S SIDE of it. It is what says "trigger"
	# at a glance, more than the blade does, and it was missing entirely.
	#
	# The ring's axis lies along X, so it stands edge-on to the gunner with its opening
	# facing them, and the blade inside it is against the background rather than the grip.
	var guard := TorusMesh.new()
	guard.inner_radius = 0.024
	guard.outer_radius = 0.030
	var hoop := _make_mesh(guard, Color(0.12, 0.12, 0.14), Vector3(0.0, BLADE_AT, BLADE_Z + 0.004))
	hoop.rotation = Vector3(0.0, 0.0, PI * 0.5)
	# AND THE BLADE, hanging in the middle of the hoop, BELOW AND BEHIND the grip.
	#
	# Behind, and that is the whole point. A real trigger is on the far face of the grip and
	# the shooter's own hand hides it; here the only viewpoint that exists is the seat, and a
	# control nobody can see is a control nobody will reach for. It was tried on the far side
	# and the grip swallowed it whole -- which is exactly what happened to the version before
	# this one, in a plain block, and what was reported from the cockpit.
	var blade := BoxMesh.new()
	blade.size = Vector3(0.013, 0.044, 0.010)
	_lever = _make_mesh(blade, Color(0.82, 0.20, 0.16), Vector3(0.0, BLADE_AT, BLADE_Z))


func _redraw() -> void:
	if _lever == null:
		return
	# ON THE PULL AND NOT ON THE GRAB. Holding this used to move the blade, back when
	# holding it was the firing; it is not any more, and a blade that dropped the moment a
	# hand closed on the grip would say "firing" whenever it meant "held".
	_lever.position = Vector3(0.0, BLADE_AT, BLADE_Z + (PULL if _pulled else 0.0))


## WHAT THE HAND ON THIS IS DOING WITH THE REST OF ITSELF. See VehicleControl.hand_input.
##
## The blade is the one thing in the cockpit that says a gun is firing, so it has to be
## driven by the input that fires it rather than by the one that holds the grip.
func hand_input(input: int, down: bool) -> void:
	if input != Bind.TRIGGER or _pulled == down:
		return
	_pulled = down
	# AND THE PULL ITSELF IS NOT FELT. The hand feels ROUNDS, one kick each, as they leave
	# the gun -- see `PilotRig.feel_a_round_leave`. It used to kick here, once per pull,
	# because a round's birth record did not say who fired it; that made a 25 mm firing
	# thirty a second feel like one shot, and a pull on a howitzer still loading kick a gun
	# that had not fired.
	_redraw()


## PULL THE TRIGGER TO FIRE IT, which is the sentence this control was named for.
##
## Holding the grip used to BE the firing, because the grip was the only input a control
## had. It made a gunner who wanted to hold on to their gun while it was not firing --
## which is a gunner traversing onto a target -- impossible: letting go to stop shooting
## also let go of the gun.
##
## So the grip holds and the index finger fires, which is how the real thing works and
## what everyone reaches for anyway.
##
## AND THE AMMUNITION IS UNDER THE SAME THUMB. `Weapon` is four rounds in a tank's ready
## rack and four stores on an aircraft, and choosing between them is the one other decision
## a hand on a gun makes. Wrapped, because a selector with four positions and no way back
## to the first is a selector you can drive off the end of.
##
## `Bind.nothing()` ON THE OTHER TWO IS NOT PADDING. The global set puts the brake on the
## trigger and the craft browser on the thumb, and a gunner who changed aeroplanes by
## reaching for the ammunition selector would have a very confusing afternoon.
func bindings() -> Dictionary:
	return {
		Bind.TRIGGER: Bind.fire(),
		Bind.THUMB_LOW: Bind.step(Sim.Channel.WEAPON, 1, true),
		Bind.THUMB_HIGH: Bind.nothing(),
		Bind.STICK_CLICK: Bind.nothing(),
	}


## THE GRIP, which is the part a hand closes around -- and it is on the gunner's side of
## the stalk, not beyond it. Reaching for a control means reaching for the part of it you
## can see.
func _grab_point() -> Vector3:
	return Vector3(0.0, GRIP_AT, 0.016)


## HELD IS THE WHOLE STATE. No latch, no re-arm, no value: `is_held` already means "a hand
## is on it and the grip is closed", which is exactly what holding a gun is. What the gun
## DOES is `_pulled`, above.
func offer_hand(hand: int, at: Vector3, grip: float,
		_facing: Basis = Basis.IDENTITY) -> void:
	var on_it: bool = at.distance_to(_grab_point()) < REACH
	if on_it and grip >= GRAB_ON:
		held_by = hand
	elif not on_it or grip <= GRAB_OFF:
		held_by = -1
		# A HAND THAT HAS LET GO IS NOT STILL FIRING. Without this the blade stays down
		# and the gun keeps shooting in the only place anybody can see it: the cockpit.
		if _pulled:
			_pulled = false
	_redraw()
