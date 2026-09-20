extends Node3D
class_name MarshalledCraft
## THE AEROPLANE ON THE OTHER END OF THE SIGNAL, and the pilot flying it.
##
## ---------------------------------------------------------------------------------
## WHY THIS IS A NODE AND NOT AN ENTITY
## ---------------------------------------------------------------------------------
##
## The rest of this game is emphatic that a node never writes a position into the
## simulation: the ECS owns everything that moves, and a node that disagreed with it would
## be a second answer to a question that must only have one. That rule is not bent here.
## There is NO SIMULATION IN THESE LEVELS AT ALL -- the same as the hall of cockpits, which
## is seats and nothing else -- so there is nothing to write into and nothing to disagree
## with. What moves is a node, owned by the level that made it.
##
## The price is honest and it is worth writing down: a second player cannot sit in this
## aeroplane. Everything goes through `command`, which is a dozen verbs wide, so the day a
## marshaller wants to be directing a real player's aircraft over the wire, that is what
## gets reimplemented -- and the levels above it do not find out.
##
## What is NOT given up is what the aeroplane looks like: the body is the game's own
## `VehicleView`, built by the game's own code from the simulation's own dimensions, so the
## jet on the catapult is the jet, at the size it collides at.
##
## ---------------------------------------------------------------------------------
## THE PILOT IS NOT INSTANT, AND THAT IS THE GAME
## ---------------------------------------------------------------------------------
##
## Every command waits `REACT` before anything happens, and then speed arrives through an
## acceleration rather than in a step. So a marshaller who calls the stop when the aeroplane
## is on the mark has already overshot it, and the skill of the job -- the entire skill of
## the job -- is knowing how far ahead of the mark to call it. An aeroplane that stopped the
## instant you crossed your arms would need no judgement at all.
##
## And a pilot who REFUSES is how the order of a procedure is taught. Nobody taxis with the
## chocks in. Being told no, with a reason, beats a checklist that says the same thing.

## The pilot did not do it, and why not. The levels put this on a board: it is the whole
## tutorial, delivered at the moment it is needed instead of on a page beforehand.
signal refused(what: StringName, why: String)
signal launched()
signal stopped()

enum State { PARKED, TAXI, LAUNCH, FLYAWAY }

## ORDERS THAT ARE ONLY GOOD WHILE YOU GO ON GIVING THEM.
##
## The difference between the two halves of the book, and it is not a detail. "Set the
## brakes" is a LATCH: say it once and it is true afterwards, and an order that arrives half
## a second late still means what it meant when it was given. "Turn left" is a HAND ON THE
## AEROPLANE: it is true while the arm is going round and false the moment it stops.
##
## A stale latch is harmless. A stale hand is not: a turn that arrived after its marshaller
## had lowered their arms put the nosewheel back over with nothing left to take it off
## again, and the aeroplane left the track at thirty degrees while its marshaller was
## already waving it to a stop.
const WHILE_YOU_MEAN_IT: Array[StringName] = [&"come_ahead", &"turn_left", &"turn_right",
	&"slow_down", &"move_back", &"run_up"]

## How long the pilot takes to answer. Half a second is what it takes to see an arm move,
## believe it, and put a boot on a pedal.
const REACT: float = 0.45
## The slowest and fastest a wave can ask for, in metres a second.
##
## A BRISK TAXI AT THE TOP, NOT A STROLL. It was walking pace -- 2.6, reached at 0.7 m/s^2 --
## and a robot marshal took 94 s to put the jet on the catapult and 111 s to put the airliner
## on its stand, which from the post felt like an aeroplane glued to the deck. The brakes came
## up with the pace, so the lead a marshaller has to give a stop stays about what it was.
const CREEP: float = 1.2
const TAXI: float = 4.5
const ACCELERATE: float = 1.4
const BRAKE: float = 3.0
const PANIC: float = 6.0
## HOW FAST THE NOSE MAY COME ROUND, in radians a second at full lock and taxi speed.
##
## The nosewheel angle is worked out FROM this rather than the other way round, and that is
## the whole reason it is here. There is the better part of two seconds between a marshaller
## deciding something and the gear doing it -- a wave has to be read, a pilot has to answer,
## the gear has to swing across -- so a nose that comes round at fifteen degrees a second
## cannot be steered by anybody: it is thirty degrees of error before the correction starts.
##
## Seven and a half degrees a second is slow enough to aim and still turns her through
## ninety in a deck's width. And because it is a RATE, the same number gives a fighter about
## six degrees of nosewheel at full taxi and an airliner about twenty-two -- the long
## aeroplane needs more lock for the same rate, and neither of them was typed in.
const TURN_RATE: float = 0.13
const LOCK_RATE: float = deg_to_rad(22.0)
## The catapult: what it does to eighteen tonnes in two seconds.
const CAT_PUSH: float = 30.0
const CAT_OFF: float = 68.0

var kind: int = Sim.Kind.PLANE
var state: int = State.PARKED

## What the aircraft is doing.
var speed: float = 0.0
var steer: float = 0.0
## What it has been TOLD to do, which is a standing order: an aeroplane waved forward keeps
## rolling until somebody stops it, exactly as on a real apron. That is what makes the stop
## signal worth getting right.
var wanted_speed: float = 0.0
var wanted_steer: float = 0.0
var braking: float = BRAKE

## The switches a procedure is made of.
var engines: bool = true
var brakes_set: bool = true
var chocks_in: bool = false
var wings_spread: bool = false
var tension: bool = false
var saluted: bool = false
var power: float = 0.0

## Its own size, from the simulation's shape table. Never typed in here: a hull that is drawn
## one size and measured another is the bug that is hardest to see, because it looks right.
var extents: Vector3 = Vector3.ONE
var wheelbase: float = 4.0
## Full nosewheel deflection, worked out from the wheelbase. See TURN_RATE.
var lock: float = deg_to_rad(10.0)

var _view: VehicleView = null
var _clock: float = 0.0
var _pending: Dictionary = {}
## THE LAST THING THE MARSHALLER ACTUALLY MADE, and the only order that may be HELD.
##
## The reader goes on reporting a cycling signal as held for over a second after the hands
## stop moving, and that is right: a slow beckon has more than a second between strokes and
## an aeroplane that stopped between them would judder up the deck. But it means that for
## that second, the signal you have just STOPPED making is still arriving, every frame,
## while the new one arrives once.
##
## Both of the bugs that came out of this were the same bug. A stop was overwritten by the
## wave that preceded it and the jet taxied off the bow. And a turn kept the nosewheel over
## for a second after the arms came down, which curved the aeroplane forty degrees off the
## track while its marshaller was signalling something else entirely.
##
## So: a held order counts only while it is the last thing that was actually made. Nothing
## else needs a special case, and neither of those two can happen again.
var _standing: StringName = &""
var _stroke: float = 0.0
var _spooling: bool = false


## BUILT FROM THE CRAFT SCENE THE GAME ALREADY HAS. `setup` with entity 0 is the same call
## the editor preview and the smoke test make: it needs no session, because `kind_geometry`
## is answered by a CockpitWorld built for the purpose in its own constructor.
##
## `draw()` is never called on it, which is the whole arrangement -- that is the method that
## would read a pose out of the simulation, and this craft's pose is ours.
func fit(craft: int, scene: PackedScene) -> void:
	kind = craft
	_view = scene.instantiate() as VehicleView
	add_child(_view)
	_view.setup(0, craft)
	var geometry: Dictionary = Sim.geometry_of(craft)
	extents = geometry.get("extents", Vector3.ONE)
	# Nose gear to main gear. Not a number of its own: a long aeroplane turns in a long arc
	# and that has to follow from the aeroplane rather than from a taste for how it feels.
	wheelbase = maxf(extents.z * 1.1, 2.0)
	lock = atan(TURN_RATE * wheelbase / TAXI)


## ---- what a marshaller can ask for -------------------------------------------------

## ONE VERB, WITH A STRENGTH. The strength is how hard the signal was being made -- see
## `SignalBook`, where the rate of a wave is part of its meaning -- and for everything that
## is not a wave it is 1.
##
## Queued rather than done: `REACT` later, `_obey` runs. Repeating a continuous command
## refreshes the one already waiting instead of stacking up, because `holding` arrives at
## the frame rate and a queue of four hundred identical orders is a queue with a four-second
## delay in it.
func command(what: StringName, strength: float = 1.0, fresh: bool = true) -> void:
	if fresh:
		_standing = what
	elif what != _standing:
		return
	if _pending.has(what):
		_pending[what]["strength"] = strength
		return
	_pending[what] = {"at": _clock + REACT, "strength": strength}


## A CONTINUOUS SIGNAL HAS STOPPED. The nosewheel comes back to centre, because a turn is
## made by an arm that is still moving; the SPEED does not, because a wave is an instruction
## to go and not a hand on the throttle.
## WHAT IS ALREADY IN THE PILOT'S HANDS STAYS THERE. Lowering your arms cancels the STANDING
## order, not the one you gave half a second ago -- a marshaller who takes tension and then
## drops their arms has still taken tension, and erasing the order because the signal stopped
## meant the aeroplane was never told at all. Which is the sort of thing that happens to
## every HELD signal in the book and to none of the others, so it hid until a test made all
## nineteen of them in a row.
func release(what: StringName) -> void:
	if what == _standing:
		_standing = &""
	if what == &"turn_left" or what == &"turn_right":
		wanted_steer = 0.0
	if what == &"run_up":
		_spooling = false


func _physics_process(delta: float) -> void:
	_clock += delta
	for what in _pending.keys():
		if float(_pending[what]["at"]) <= _clock:
			var strength: float = float(_pending[what]["strength"])
			_pending.erase(what)
			# STALE, and only the ones that can be. See WHILE_YOU_MEAN_IT.
			if what in WHILE_YOU_MEAN_IT and _standing != what:
				continue
			_obey(what, strength)
	# UP TO FULL, AND THEN IT STAYS THERE. A pilot at tension holds military power waiting
	# for the shot; a pilot whose marshaller stopped asking for it comes back to idle.
	if power < 1.0:
		power = move_toward(power, 1.0 if _spooling else 0.0, delta * 0.55)
	match state:
		State.LAUNCH: _shot(delta)
		State.FLYAWAY: _away(delta)
		_: _roll(delta)


## ---- the pilot ---------------------------------------------------------------------

func _obey(what: StringName, strength: float) -> void:
	if OS.has_environment("MARSHAL_TRACE"):
		print("[craft] %.2f obey %s tension=%s power=%.2f speed=%.2f wings=%s" % [_clock,
			what, tension, power, speed, wings_spread])
	match what:
		&"come_ahead", &"turn_left", &"turn_right":
			if not _may_move():
				return
			wanted_speed = lerpf(CREEP, TAXI, strength)
			braking = BRAKE
			# "STRAIGHT AHEAD" IS THE SIGNAL'S OWN NAME. A come-ahead with no turn in it
			# centres the nosewheel, which is also what stops a turn from carrying on
			# after the marshaller has gone back to waving her forward.
			wanted_steer = 0.0
			# HOW FAST YOU WAVE IS HOW HARD SHE TURNS. The standard says so in as many
			# words -- "the speed of the signal indicates the rate of turn" -- and it is
			# what makes a small correction possible at all: full lock for any turn at all
			# would mean the only way to move an aeroplane a metre sideways is to swing
			# her thirty degrees and swing her back.
			if what == &"turn_left":
				wanted_steer = lock * maxf(strength, 0.15)
			elif what == &"turn_right":
				wanted_steer = -lock * maxf(strength, 0.15)
			state = State.TAXI
		&"move_back":
			if not _may_move():
				return
			# A PUSHBACK IS SLOW, whoever is doing the pushing, and the nosewheel steers
			# the other way round -- which the bicycle model already does for nothing,
			# because its turn rate is proportional to a speed that is now negative.
			wanted_speed = -lerpf(0.3, 0.9, strength)
			braking = BRAKE
			state = State.TAXI
		&"slow_down":
			# A HARDER PAT IS A HARDER STOP. The rate of the signal is the rate of the
			# deceleration, which is what it means on a real apron.
			wanted_speed = CREEP
			braking = lerpf(BRAKE * 0.4, BRAKE, strength)
		&"hold_position", &"normal_stop":
			_all_stop(BRAKE)
		&"emergency_stop":
			_all_stop(PANIC)
		&"set_brakes":
			if absf(speed) > 0.05:
				refused.emit(what, "she is still rolling")
				return
			brakes_set = true
			wanted_speed = 0.0
		&"release_brakes":
			if chocks_in:
				refused.emit(what, "the chocks are still in")
				return
			brakes_set = false
		&"chocks_in":
			if absf(speed) > 0.05:
				refused.emit(what, "nobody walks under a moving aeroplane")
				return
			if not brakes_set:
				refused.emit(what, "not until the brakes are set")
				return
			chocks_in = true
		&"cut_engines":
			if absf(speed) > 0.05:
				refused.emit(what, "she is still rolling")
				return
			engines = false
			power = 0.0
		&"spread_wings":
			if absf(speed) > 0.05:
				refused.emit(what, "not while she is moving")
				return
			wings_spread = true
		&"take_tension":
			if not wings_spread:
				refused.emit(what, "the wings are still folded")
				return
			if absf(speed) > 0.05:
				refused.emit(what, "she is not on the shuttle yet")
				return
			brakes_set = false
			tension = true
		&"run_up":
			if not tension:
				refused.emit(what, "no tension on the shuttle")
				return
			# SPOOLING, not a step. Engines take a couple of seconds to come up and the
			# marshaller keeps circling until they have -- which is what a run-up IS. The
			# first version added a lump of power per order and the checklist ticked the
			# step off the instant it recognised the signal, so the arms came down after
			# one order and the aeroplane went to the catapult at half power.
			_spooling = true
		&"salute":
			saluted = true
		&"touch_deck":
			if not tension or power < 0.8:
				refused.emit(what, "she is not at full power")
				return
			state = State.LAUNCH
			_stroke = 0.0
			launched.emit()
		_:
			pass


## EVERYTHING SHE WAS TOLD BEFORE THIS, FORGOTTEN. The orders already in the pilot's hands
## go with it: a wave from half a second ago must not arrive after the stop and undo it.
func _all_stop(how_hard: float) -> void:
	wanted_speed = 0.0
	wanted_steer = 0.0
	braking = how_hard
	_standing = &""
	for what in _pending.keys():
		if what in [&"come_ahead", &"turn_left", &"turn_right", &"move_back", &"slow_down"]:
			_pending.erase(what)


## Told to move, and a reason it cannot. Every one of these is a real one, and being told is
## how the order of the procedure gets learned.
func _may_move() -> bool:
	if not engines:
		refused.emit(&"come_ahead", "the engines are shut down")
		return false
	if chocks_in:
		refused.emit(&"come_ahead", "the chocks are in")
		return false
	if brakes_set:
		refused.emit(&"come_ahead", "the brakes are set")
		return false
	if tension:
		refused.emit(&"come_ahead", "she is chained to the catapult")
		return false
	return true


## ---- and the aeroplane -------------------------------------------------------------

## A TRICYCLE, which is all a taxiing aeroplane is. The nose gear points, the mains follow,
## and the arc it turns in is its own wheelbase -- so the airliner swings wide and the jet
## does not, without either of them being given a number for it.
func _roll(delta: float) -> void:
	var was: float = speed
	if speed < wanted_speed:
		speed = minf(speed + ACCELERATE * delta, wanted_speed)
	else:
		speed = maxf(speed - braking * delta, wanted_speed)
	if brakes_set or chocks_in or not engines:
		speed = maxf(speed - PANIC * delta, 0.0)
	steer = move_toward(steer, wanted_steer, LOCK_RATE * delta)
	if absf(speed) < 0.001:
		if absf(was) >= 0.001:
			stopped.emit()
		return
	rotate_y(speed / wheelbase * tan(steer) * delta)
	global_position += -global_transform.basis.z * speed * delta


## THE STROKE. Two seconds, a hundred metres, and nothing the marshaller can do about it any
## more -- which is exactly what a catapult is.
func _shot(delta: float) -> void:
	speed += CAT_PUSH * delta
	var step: float = speed * delta
	_stroke += step
	global_position += -global_transform.basis.z * step
	if speed >= CAT_OFF:
		state = State.FLYAWAY


func _away(delta: float) -> void:
	speed += 4.0 * delta
	rotation.x = minf(rotation.x + delta * 0.22, deg_to_rad(11.0))
	# The nose is up, so its own forward has a climb in it. One vector, not two.
	global_position += -global_transform.basis.z * speed * delta


## ---- what a level measures ------------------------------------------------------------

## THE NOSEWHEEL, which is the part of an aeroplane a stop bar is drawn for. Everything a
## marshaller is scored on is measured here and not at the middle of the hull.
func nose() -> Vector3:
	return global_position - global_transform.basis.z * extents.z


func wingtips() -> Array[Vector3]:
	var span: float = maxf(float(Sim.geometry_of(kind).get("span", extents.x * 2.0)), 1.0)
	return [global_position + global_transform.basis.x * span * 0.5,
		global_position - global_transform.basis.x * span * 0.5]


## Which way the nose is pointing, as a bearing. For "is she straight on the track yet".
func heading() -> float:
	var nose_at: Vector3 = -global_transform.basis.z
	return atan2(nose_at.x, -nose_at.z)


func is_rolling() -> bool:
	return absf(speed) > 0.05
