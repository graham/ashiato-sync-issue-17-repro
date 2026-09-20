extends RefCounted
class_name FireFront
## FIRES THAT LIGHT THEIR NEIGHBOURS, and the cap that stops them taking the island.
##
## `agents.md` had said for a while that fires "grow back and they go out; they do not light
## their neighbours -- that is one constant and a cap away, and it is the thing that would
## turn nine fires into a job you can lose". This is the constant and the cap.
##
## ---------------------------------------------------------------------------------
## IT COSTS NOTHING ON THE WIRE, AND THAT IS WHY IT IS HERE AND NOT IN THE C++
## ---------------------------------------------------------------------------------
##
## A fire is already an entity with a replicated `FireState`, and `light_fire` already makes
## one. Spreading is therefore nothing but lighting more of them, which is a SPAWN -- and a
## spawn is the server's alone, exactly like every vehicle in the world. No new component, no
## new field, no quantiser, no bit. A client finds out a hillside has caught the same way it
## finds out an aeroplane took off.
##
## THE RANDOMNESS MAY BE THE ENGINE'S HERE, and that is worth saying out loud because
## `Terrain` spends nine lines avoiding it. The scenery is NOT replicated -- every peer
## generates it, so a generator that changed under an upgrade would desync everybody -- and a
## fire IS replicated. Only the server rolls this dice and everyone else is told the answer.
##
## ---------------------------------------------------------------------------------
## ONE CLOCK FOR THE WHOLE FRONT, NOT ONE PER FIRE
## ---------------------------------------------------------------------------------
##
## The accumulator is advanced by `delta` times the number of fires burning HARD, so nine
## fires spread three times as fast as three do -- which is the shape that makes this a job
## you can lose rather than a timer you can ignore. A per-fire timer would need a table keyed
## by an entity that comes and goes, and would give a fire nobody can reach the same urgency
## as a row of them over a city.
##
## ---------------------------------------------------------------------------------
## AND WHAT MAKES A FIRE "ATTENDED" IS ITS OWN STRENGTH
## ---------------------------------------------------------------------------------
##
## There is no flag and nothing watches the tanker. A fire below `SPREAD_FROM` is not making
## enough heat to light anything, and knocking one down below that is exactly what a full
## load does. So attending to a fire stops it spreading, and walking away lets it grow back
## through the threshold at two per cent a second and start again -- which is the whole loop:
## knock it down and come back, or it starts up behind you.

## HOW LONG A FIRE BURNING ALONE TAKES TO LIGHT A NEIGHBOUR, in seconds, at full strength.
##
## THE CONSTANT. Half a minute is roughly the round trip to the sea and back for the tanker
## -- twelve seconds to fill, a minute of transit at a fair distance -- so one aeroplane can
## hold about two fires and a crew that splits the job holds more. Slower and the fires are
## scenery; faster and one aeroplane cannot make a dent and the island is gone before
## anybody has found the second fire.
const SPREAD_SECONDS: float = 30.0

## AND THE CAP. Nine to start with, and it stops at twenty-four.
##
## Not a performance number -- twenty-four more entities is nothing against a hundred and
## forty vehicles -- it is the LOSING CONDITION. Something has to be the end of the job, and
## a fire front that grows without limit is one that ends when the player gets bored, which
## is the thing this whole exercise is about not doing. A column is 260 m tall and never
## culled, so twenty-four of them is also a sky you can read at a glance: that is what losing
## looks like from the air.
const MAX_FIRES: int = 24

## BELOW THIS A FIRE LIGHTS NOTHING. A full load knocks a fire to nearly nothing, so anything
## being worked is well under it; a fire left alone climbs back through it in about half a
## minute at the two-per-cent regrowth.
const SPREAD_FROM: float = 0.55

## WHAT A NEW FIRE STARTS AT. Small, so a hillside that has just caught is a thing you can
## still get to in time -- and so that a spread fire is visibly younger than its parent, the
## group the world starts with being exactly that shape.
const SEEDED_AT: float = 0.22

## How far a new fire lands from the one that lit it, in metres. Far enough that the two
## columns are separate marks in the sky and not one fat one; near enough that a single run
## can sometimes take both.
const SPREAD_NEAR: float = 260.0
const SPREAD_FAR: float = 620.0

## HOW MUCH OF THE JUMP IS DOWNWIND, 0 to 1. Fire goes with the wind, the smoke column leans
## with it, and the group the world starts with is described as "one big one and its children
## downwind" -- so a front that spread evenly in a ring would contradict the picture the
## player is already reading.
const DOWNWIND: float = 0.62

## HOW MANY PLACES IT TRIES BEFORE GIVING UP ON A PARENT. A fire on a ridge may have rock on
## three sides, and one that cannot find anywhere should burn on rather than stall the whole
## front: the accumulator is spent either way, so a hemmed-in fire simply spreads slower.
const TRIES: int = 6

## The solid boxes, kept rather than regenerated. `Terrain.boxes()` builds four hundred and
## sixty-three of them and this asks a few times a minute.
var _solid: Array[Dictionary] = []
## Seconds of hard burning banked toward the next neighbour. See the note on one clock.
var _since: float = 0.0
## HOW MANY HAVE BEEN LIT BY THE FIRE ITSELF, and how many have gone out since the world
## started. The debrief is the only reason either is counted.
var _spread: int = 0
var _doused: int = 0
## Which fires were alight last time, so a fire that has gone can be counted once.
var _was: Dictionary = {}
var _rng := RandomNumberGenerator.new()


## `solid` IS REQUIRED, AND AN EMPTY LIST MEANS NOTHING SOLID. It used to default to `[]` and read an empty list as
## "the whole island", so the fires suite's `_open_ground()` -- written as NOTHING SOLID ANYWHERE, for the checks about
## the RATE -- had been handing its fronts every mountain on the island all along, and nothing showed it because nothing
## solid stood within reach of the suite's fire at the origin. Found 2026-09-13, when buildings put downwind of that fire
## made the third fire 38 s late. `tests/fires.gd` holds it: a front built on open ground has 0 boxes (383 before).
func _init(solid: Array[Dictionary], seed_value: int = 20260911) -> void:
	_solid = solid
	# SEEDED, so two runs of the suite fight the same fire. It is the server's own stream and
	# nobody else's, so this is repeatability rather than agreement.
	_rng.seed = seed_value


## ONE STEP OF THE FRONT. `world` is a `CockpitWorld` that is the server.
##
## A `tick(delta)` and not a `_physics_process`, so a suite can run a quarter of an hour of
## fire in one frame and get exact numbers. That seam is why every measurement in this file's
## own suite is a count rather than a wait.
func tick(world, delta: float) -> void:
	if world == null or delta <= 0.0:
		return
	var alight: Array = world.fire_states()
	_count_what_went_out(alight)
	if alight.size() >= MAX_FIRES:
		# AT THE CAP, THE CLOCK STOPS rather than banking. Otherwise putting one fire out at
		# the cap would light three the instant it went.
		_since = 0.0
		return
	var hot: Array[Dictionary] = []
	for row in alight:
		if float((row as Dictionary)["strength"]) >= SPREAD_FROM:
			hot.append(row as Dictionary)
	if hot.is_empty():
		return
	_since += delta * float(hot.size())
	while _since >= SPREAD_SECONDS and world.fire_states().size() < MAX_FIRES:
		_since -= SPREAD_SECONDS
		_light_a_neighbour_of(world, hot[_rng.randi() % hot.size()])


## A NEW FIRE DOWNWIND OF AN OLD ONE, somewhere it can actually burn.
func _light_a_neighbour_of(world, parent: Dictionary) -> void:
	var from: Vector3 = parent["position"]
	var wind: Vector3 = Terrain.WIND
	# IN STILL AIR NO WAY IS DOWNWIND, so a spread may go any way at all. The fallback was
	# FORWARD, which with the wind taken out on 2026-09-14 would have walked every fire front
	# towards -Z on a wind nobody could see.
	var leaning: Vector3 = wind.normalized() if wind.length() > 0.01 else Vector3.ZERO
	for attempt in range(TRIES):
		var about: float = _rng.randf_range(-PI, PI)
		var any := Vector3(sin(about), 0.0, cos(about))
		var way: Vector3 = (leaning * DOWNWIND + any * (1.0 - DOWNWIND)).normalized()
		var at: Vector3 = from + way * _rng.randf_range(SPREAD_NEAR, SPREAD_FAR)
		# ON THE GROUND UNDER IT: the island's slab is 0, and on the generated ground a fire stands at the ground's height.
		at.y = Terrain.ground_height(at)
		if not Terrain.can_burn(_solid, at):
			continue
		if world.light_fire(at, SEEDED_AT) != 0:
			_spread += 1
		return


## A fire that was on the list and is not any more went out. The simulation retires one when
## its strength reaches zero -- see `_a_fire_that_is_out_is_taken_off_the_wire` -- so
## "disappeared" and "was put out" are the same event.
func _count_what_went_out(alight: Array) -> void:
	var now: Dictionary = {}
	for row in alight:
		now[int((row as Dictionary)["entity"])] = true
	for entity in _was:
		if not now.has(entity):
			_doused += 1
	_was = now


## ---- what to say about it ---------------------------------------------------------------

## How many are burning, how many this front has lit itself, and how many have gone out.
## HOW MANY SOLID BOXES THIS FRONT KEEPS ITS FIRES OUT OF, for the suite that has to know an empty list stayed empty.
func solid_count() -> int:
	return _solid.size()


func alight() -> int:
	return _was.size()


func spread() -> int:
	return _spread


func doused() -> int:
	return _doused


## THE DEBRIEF, IN ONE LINE, for the board in the player's hand.
##
## Three numbers and a verdict, because a count on its own is not a score: nine of twenty-four
## alight means nothing until you know that twenty-four is the end of it. It says LOST at the
## cap rather than ending the session, which is the honest amount of game this is: there is
## nothing yet to restart.
func debrief() -> String:
	if alight() >= MAX_FIRES:
		return "THE ISLAND IS LOST. %d fires, the cap. %d put out on the way." % [
			alight(), _doused]
	if alight() == 0:
		return "EVERY FIRE IS OUT. %d put out, %d of them ones that spread." % [
			_doused, _spread]
	return "%d fires alight of %d, %d put out, %d lit by the fire itself." % [
		alight(), MAX_FIRES, _doused, _spread]
