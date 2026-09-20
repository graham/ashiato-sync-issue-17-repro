extends Node3D
class_name SignalReader
## THE BODY FRAME, AND WHAT THE HANDS ARE SAYING IN IT.
##
## One node, added under the rig's XR origin, that does three things a frame:
##
##   1. puts itself where the player's SHOULDERS are -- the tracked head, dropped by a neck,
##      turned by the head's YAW ONLY;
##   2. asks `SignalZones` which zone each hand is in, in that frame;
##   3. advances every signal in the book against the answer, and announces the ones that
##      complete.
##
## ---------------------------------------------------------------------------------
## YAW ONLY, AND WHY THE FRAME IS NOT THE WORLD
## ---------------------------------------------------------------------------------
##
## Zones live around the PLAYER, not around the deck. Turn ninety degrees to watch an
## aeroplane come round the corner and "arm straight out to the side" is still your side.
## Taking the pitch and roll as well would hang the whole zone table off whatever angle
## somebody's neck happened to be at, which is the same mistake `HandMenu` avoids when it
## places a summoned panel -- and it is worse here, because you look DOWN at an aeroplane's
## nosewheel constantly while marshalling it.
##
## Whether you are facing the aircraft is a separate question with its own answer, `facing`,
## because keeping eye contact with the pilot is a real rule and a level may want to insist
## on it.
##
## ---------------------------------------------------------------------------------
## IT ANNOUNCES, IT DOES NOT ACT
## ---------------------------------------------------------------------------------
##
## `signalled` and `holding` carry an id and a strength, and this file has no idea that a
## `come_ahead` makes an aeroplane move. The level decides. That is the same split the desk
## already uses -- `SessionMenu` emits `chose` and the room decides what it meant -- and it
## is what lets the tuning room, the carrier and the gate all read the same hands.

## A signal has been made. Fired ONCE, on the frame it completes.
signal signalled(id: StringName, strength: float)
## A continuous signal is still being made. Every frame, with the rate it is being made at.
signal holding(id: StringName, strength: float)
## A continuous signal has stopped.
signal ended(id: StringName)

## The grip thresholds, taken from `VehicleControl` on purpose: a fist here and a hand round
## a lever there should want the same squeeze, or a player learns two different triggers.
const FIST: float = 0.6
const OPEN: float = 0.35

## How far a hand has to be off the middle of a zone for its angle to mean anything. Below
## this a hand held still would spin its own noise into turns.
const CIRCLE_BITE: float = 0.35

## What a completed CYCLE or CIRCLE goes quiet for before it counts as over.
const LAPSE: float = SignalBook.LAPSE

## WHERE A MEASURED ARM IS REMEMBERED. Settable, because a game that has two of these --
## or a game not called marshalling -- should not be writing to somebody else's file.
var settings_path: String = "user://hand_signals.cfg"

## THE PLAYER, AS SIX PROPERTIES AND NOTHING ELSE.
##
## Typed as `Node3D` and not as any particular rig, because this addon has no business
## knowing what game it is in. Anything with these six members will do:
##
##   origin          Node3D   the XR origin. THIS NODE MUST BE A CHILD OF IT -- see
##                            `_follow_the_head` for why every subtraction below depends
##                            on that and on nothing else.
##   camera          Node3D   the headset camera
##   desktop_camera  Node3D   the flat-screen camera
##   using_xr        bool     which of those two is the one in use
##   left_hand       Node3D   \  the two controllers, as poses in the origin's space
##   right_hand      Node3D   /
##   grip_left       float    \  how hard each is squeezed, 0 to 1
##   grip_right      float    /
##
## Read, never written to. A test drives it with `force_hand` instead and does not need a
## rig at all, which is what lets the whole matcher be exercised with no headset, no input
## and no frame rate.
var rig: Node3D = null

## Shoulders to hand, arm straight out. THE unit: see SignalZones.
var reach: float = SignalZones.NOMINAL_REACH
## And how high those shoulders are off the deck, which is the OTHER thing a zone can be
## measured from. Followed live rather than calibrated: crouching is a move, not a body.
var shoulder: float = SignalZones.NOMINAL_SHOULDER

## The last thing the hands were doing, for the ghosts and the boards.
var left_zone: StringName = SignalZones.NOWHERE
var right_zone: StringName = SignalZones.NOWHERE

var _clock: float = 0.0
var _state: Dictionary = {}
## hand -> {"at", "grip", "up"} when a test is driving this instead of a tracker.
var _forced: Dictionary = {}
var _checked: bool = false


func _ready() -> void:
	recall()
	for id in SignalBook.ids():
		_state[id] = {"armed": false, "step": 0, "began": 0.0, "since": 0.0,
			"cycles": 0, "angle": 0.0, "was": false, "moved": 0.0, "hertz": 0.0,
			"active": false, "bearing": 0.0}


func _process(delta: float) -> void:
	tick(delta)


## ONE FRAME OF IT. Public and separate from `_process` so a headless test can step the
## whole position with no tracker, no input and no frame rate -- which is the only way to
## assert that a signal made slightly wrong is not recognised.
func tick(delta: float) -> void:
	_clock += delta
	_follow_the_head()
	var left: Dictionary = _read_hand(SignalZones.LEFT)
	var right: Dictionary = _read_hand(SignalZones.RIGHT)
	left_zone = left["zone"]
	right_zone = right["zone"]
	for id in SignalBook.ids():
		_advance(id, SignalBook.of(id), left, right, delta)


## WHERE THE SHOULDERS ARE. In the ORIGIN's space, never in the world's: this node is a child
## of the same XR origin the head and hands hang off, so everything below is subtraction
## between children of one node. That is the property the cockpit is built on, and it is
## worth keeping even standing still -- park this post on a carrier making way and the zones
## ride the deck with the player rather than being computed against a moving world.
func _follow_the_head() -> void:
	if rig == null or not is_instance_valid(rig):
		return
	var head: Node3D = rig.camera if rig.using_xr else rig.desktop_camera
	if head == null:
		return
	# A CHILD OF THE SAME ORIGIN THE HANDS ARE, and not a node parked in the world. Every
	# subtraction below is then between children of one node, which is the whole reason a
	# grab in this project is the same arithmetic parked as it is at 300 kph.
	if not _checked:
		_checked = true
		if get_parent() != rig.origin:
			push_error("[marshalling] the reader must be a child of the rig's XR origin.")
	# THE YAW THAT WOULD PRODUCE THIS FACING, which is not `atan2(x, z)`.
	#
	# `Basis(UP, yaw)` sends -Z to `(-sin yaw, 0, -cos yaw)`, so recovering the yaw from a
	# facing means negating both terms. Getting it backwards yaws the whole body frame by
	# 180 degrees, and the hands and the zones then disagree about which way FORWARD is --
	# left becomes right, `forward` ends up behind you, and every signal in the book is
	# mirrored. Invisible to a test that puts the hands in zones (both halves are wrong
	# together, so they agree), invisible in the ONE test that asks which way the player is
	# facing, and instantly fatal in a headset.
	var facing: Vector3 = -head.transform.basis.z
	var yaw: float = atan2(-facing.x, -facing.z)
	transform = Transform3D(Basis(Vector3.UP, yaw),
		head.transform.origin - Vector3(0.0, SignalZones.NECK, 0.0))
	# The XR origin stands on the floor, so this IS the height of the shoulders above the
	# deck -- and it drops when the player crouches, which is what puts `deck` in reach.
	shoulder = maxf(transform.origin.y, 0.3)


## ONE HAND, IN THE BODY FRAME: where it is, which zone that is, how hard it is squeezed and
## which way it is pointing.
##
## "Which way it is pointing" is the controller's own forward. A hand cannot be seen inside a
## headset, so a thumbs-up has to be read off the ONE thing the hardware knows about a wrist
## -- and rolling a controller until it points at the sky is what a thumbs-up does to it.
func _read_hand(hand: int) -> Dictionary:
	var at := Vector3.ZERO
	var grip: float = 0.0
	var up: float = 0.0
	if _forced.has(hand):
		var told: Dictionary = _forced[hand]
		at = told["at"]
		grip = told["grip"]
		up = told["up"]
	elif rig != null and is_instance_valid(rig):
		var node: XRController3D = rig.left_hand if hand == SignalZones.LEFT \
			else rig.right_hand
		var local: Transform3D = transform.affine_inverse() * node.transform
		at = local.origin
		grip = rig.grip_left if hand == SignalZones.LEFT else rig.grip_right
		up = (-local.basis.z).dot(Vector3.UP)
	return {"at": at, "zone": SignalZones.zone_at(at, hand, reach, shoulder), "grip": grip,
		"up": up}


## ---- the matcher ----------------------------------------------------------------

func _advance(id: StringName, row: Dictionary, left: Dictionary, right: Dictionary,
		delta: float) -> void:
	var was: Dictionary = _state[id]
	match int(row["mode"]):
		SignalBook.Mode.HOLD: _hold(id, row, was, left, right, delta)
		SignalBook.Mode.ONCE: _once(id, row, was, left, right, delta)
		SignalBook.Mode.CYCLE: _cycle(id, row, was, left, right, delta)
		SignalBook.Mode.CIRCLE: _circle(id, row, was, left, right, delta)


## ONE POSE, KEPT STILL. The dwell is what makes it a signal rather than somewhere the hands
## went on the way to somewhere else.
func _hold(id: StringName, row: Dictionary, was: Dictionary, left: Dictionary,
		right: Dictionary, delta: float) -> void:
	if not _fits(row["steps"][0], left, right):
		if was["active"]:
			was["active"] = false
			ended.emit(id)
		was["since"] = 0.0
		return
	was["since"] += delta
	if was["since"] < float(row.get("dwell", 0.5)):
		return
	if not was["active"]:
		was["active"] = true
		signalled.emit(id, 1.0)
	holding.emit(id, 1.0)


## POSES IN ORDER, INSIDE A TIME LIMIT. `not_before` is the other half of the limit and it is
## the whole of the difference between a stop and an EMERGENCY stop: the same arms, over the
## same head, done at a different speed.
func _once(id: StringName, row: Dictionary, was: Dictionary, left: Dictionary,
		right: Dictionary, delta: float) -> void:
	var steps: Array = row["steps"]
	var within: float = float(row.get("within", 2.0))
	if not was["armed"]:
		# A RISING EDGE, so a hand parked in the first pose does not re-arm every frame.
		var here: bool = _fits(steps[0], left, right)
		if here and not was["was"]:
			was["armed"] = true
			was["step"] = 0
			was["began"] = 0.0
		was["was"] = here
		return
	was["was"] = true
	was["began"] += delta
	var next: int = int(was["step"]) + 1
	if _fits(steps[next], left, right):
		was["step"] = next
		if next == steps.size() - 1:
			was["armed"] = false
			was["was"] = false
			if was["began"] >= float(row.get("not_before", 0.0)) \
					and was["began"] <= within:
				signalled.emit(id, 1.0)
		return
	if was["began"] > within:
		was["armed"] = false
		was["was"] = false


## POSES ALTERNATING, AND THE RATE IS THE MESSAGE.
##
## Every return to the first pose is one cycle, and the time between them is what the
## aeroplane is told: a slow beckon is a creep and a fast one is a taxi. `cycles` before it
## counts at all, because one arm going up and down once is somebody scratching their head.
func _cycle(id: StringName, row: Dictionary, was: Dictionary, left: Dictionary,
		right: Dictionary, delta: float) -> void:
	var steps: Array = row["steps"]
	if not was["armed"]:
		var here: bool = _fits(steps[0], left, right)
		if here and not was["was"]:
			was["armed"] = true
			was["step"] = 0
			was["cycles"] = 0
			was["moved"] = _clock
			was["hertz"] = 0.0
			was["bearing"] = _clock
		was["was"] = here
		return
	var next: int = (int(was["step"]) + 1) % steps.size()
	if _fits(steps[next], left, right):
		was["step"] = next
		was["moved"] = _clock
		if next == 0:
			was["cycles"] = int(was["cycles"]) + 1
			var took: float = _clock - float(was["bearing"])
			was["bearing"] = _clock
			if took > 0.0:
				# SMOOTHED, because a wave is not metronomic and an aeroplane that changed
				# speed on every stroke would surge under the marshaller's hands.
				var hertz: float = 1.0 / took
				was["hertz"] = hertz if float(was["hertz"]) <= 0.0 \
					else lerpf(float(was["hertz"]), hertz, 0.5)
		if int(was["cycles"]) >= int(row.get("cycles", 2)) and not was["active"]:
			was["active"] = true
			signalled.emit(id, SignalBook.strength(id, float(was["hertz"])))
	if was["active"]:
		holding.emit(id, SignalBook.strength(id, float(was["hertz"])))
	# WHEN A WAVE STOPS MEANING ANYTHING, which is a question with two answers.
	#
	# A wave is a STANDING ORDER -- the aeroplane keeps rolling between strokes -- so the
	# reader has to go on reporting it while the arms are still going round. But it must
	# stop the moment they are not, and the flat 1.4 s it used to allow was a second of
	# phantom signal: a turn that went on cranking the nosewheel over after the marshaller
	# had gone back to waving her straight, and a wave that overwrote the stop that
	# followed it. The aeroplane snaked down the deck and then taxied into the sea.
	#
	# So: one stroke of grace at whatever rate it is BEING made at -- a lazy beckon gets
	# more than a hard one, which is what makes both of them continuous -- and none at all
	# once the hands have left the signal's zones altogether, which is what happens the
	# instant somebody starts making a different signal.
	var stroke: float = clampf(0.9 / maxf(float(was["hertz"]), 0.35), 0.35, LAPSE)
	var zones: Array = row["zones"]
	var still_there: bool = zones.has(left["zone"]) or zones.has(right["zone"])
	if not still_there or _clock - float(was["moved"]) > stroke:
		_quiet(id, was)


## A HAND GOING ROUND. The angle is taken in the HORIZONTAL plane, because a hand circling
## above a head describes a horizontal circle -- the wrist is over the head and the fingers
## go round it. Wound up rather than sampled, so half a turn back the other way undoes half
## a turn, and a hand shaking in place accumulates nothing.
func _circle(id: StringName, row: Dictionary, was: Dictionary, left: Dictionary,
		right: Dictionary, delta: float) -> void:
	var hand: int = int(row.get("hand", SignalZones.RIGHT))
	var told: Dictionary = left if hand == SignalZones.LEFT else right
	var zone: StringName = row.get("zone", &"overhead")
	if told["zone"] != zone:
		_quiet(id, was)
		was["armed"] = false
		return
	var off: Vector3 = (told["at"] as Vector3) - SignalZones.place(zone, hand, reach, shoulder)
	var flat := Vector2(off.x, off.z)
	# THE AUTHORED RADIUS, not the slackened one. See SignalZones.core: how forgiving the
	# zone is about being entered says nothing about how big a circle inside it must be.
	if flat.length() < CIRCLE_BITE * SignalZones.core(zone, reach):
		return
	var bearing: float = flat.angle()
	if was["armed"]:
		was["angle"] = float(was["angle"]) + angle_difference(float(was["bearing"]), bearing)
		was["moved"] = _clock
	was["armed"] = true
	was["bearing"] = bearing
	was["began"] = float(was["began"]) + delta
	var turns: float = absf(float(was["angle"])) / TAU
	if float(was["began"]) > 0.0:
		was["hertz"] = turns / float(was["began"])
	if turns >= float(row.get("turns", 2.0)):
		if not was["active"]:
			was["active"] = true
			signalled.emit(id, SignalBook.strength(id, float(was["hertz"])))
		holding.emit(id, SignalBook.strength(id, float(was["hertz"])))


func _quiet(id: StringName, was: Dictionary) -> void:
	if was["active"]:
		was["active"] = false
		ended.emit(id)
	was["armed"] = false
	was["was"] = false
	was["cycles"] = 0
	was["angle"] = 0.0
	was["began"] = 0.0
	was["hertz"] = 0.0


## Does this pair of hands make that pose?
func _fits(step: Array, left: Dictionary, right: Dictionary) -> bool:
	return _hand_fits(step[0], left) and _hand_fits(step[1], right)


func _hand_fits(spec: Dictionary, told: Dictionary) -> bool:
	var zones: Array = spec["zones"]
	if not zones.is_empty() and not zones.has(told["zone"]):
		return false
	match int(spec["grip"]):
		SignalBook.Grip.OPEN:
			if float(told["grip"]) > OPEN:
				return false
		SignalBook.Grip.FIST:
			if float(told["grip"]) < FIST:
				return false
	match int(spec["palm"]):
		SignalBook.Palm.UP:
			if float(told["up"]) < 0.35:
				return false
		SignalBook.Palm.DOWN:
			if float(told["up"]) > -0.35:
				return false
	return true


## ---- what a level asks ------------------------------------------------------------

## HOW SQUARELY THE PLAYER IS FACING THAT, as a cosine: 1 dead ahead, 0 side on.
##
## Eye contact is not decoration. A marshaller signalling an aeroplane they are not looking
## at is a marshaller who cannot see the wingtip they are about to walk into something, and
## the standard has the signaller in the pilot's field of view throughout.
func facing(point: Vector3) -> float:
	var to: Vector3 = to_local(point)
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return 1.0
	return to.normalized().dot(Vector3.FORWARD)


## ---- calibration ------------------------------------------------------------------

## MEASURE THE PLAYER, from both arms held straight out.
##
## Body units are only worth having if the body is the player's own. The alternative is a
## table in metres that fits one height of person, and everybody else finds that "straight
## out to the side" is a place their arm does not reach or a place it passes through.
func calibrate() -> float:
	var left: Dictionary = _read_hand(SignalZones.LEFT)
	var right: Dictionary = _read_hand(SignalZones.RIGHT)
	var span: float = (Vector3(left["at"].x, 0.0, left["at"].z).length()
		+ Vector3(right["at"].x, 0.0, right["at"].z).length()) * 0.5
	# A SANITY BAND, not a correction. A measurement taken with the arms half down is worse
	# than the nominal, and the way that shows up is a number no adult has.
	if span < 0.45 or span > 1.15:
		push_warning("[marshalling] a reach of %.2f m is not an arm: keeping %.2f" % [span,
			reach])
		return reach
	reach = span
	remember()
	return reach


func remember() -> void:
	var file := ConfigFile.new()
	file.set_value("marshalling", "reach", reach)
	file.save(settings_path)


func recall() -> void:
	var file := ConfigFile.new()
	if file.load(settings_path) == OK:
		reach = float(file.get_value("marshalling", "reach", SignalZones.NOMINAL_REACH))


## ---- what a test does instead of having hands ---------------------------------------

## PUT A HAND SOMEWHERE, in the body frame. A test with no tracker and no controllers walks
## the zones with this, which is the only way to assert that a signal made SLIGHTLY WRONG is
## not recognised -- the case that matters most and the one a person cannot reproduce.
func force_hand(hand: int, at: Vector3, grip: float = 0.0, up: float = 0.0) -> void:
	_forced[hand] = {"at": at, "grip": grip, "up": up}


## Both hands into named zones, which is how nearly every test line reads.
func force_zones(left: StringName, right: StringName, grip: float = 0.0,
		up: float = 0.0) -> void:
	if left == SignalZones.NOWHERE:
		force_hand(SignalZones.LEFT, Vector3(0.0, -3.0, 0.0), grip, up)
	else:
		force_hand(SignalZones.LEFT,
			SignalZones.place(left, SignalZones.LEFT, reach, shoulder), grip, up)
	if right == SignalZones.NOWHERE:
		force_hand(SignalZones.RIGHT, Vector3(0.0, -3.0, 0.0), grip, up)
	else:
		force_hand(SignalZones.RIGHT,
			SignalZones.place(right, SignalZones.RIGHT, reach, shoulder), grip, up)


func release_hands() -> void:
	_forced.clear()
