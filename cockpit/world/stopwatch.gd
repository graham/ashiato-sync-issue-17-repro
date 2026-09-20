extends RefCounted
## A STOPWATCH FOR THE PARTS OF A FRAME: STARTED BY THE SCENERY PROBE AND BY NOTHING ELSE.
##
## `tests/scenery_shot.gd` could time a whole frame, and the renderer's share of it, and on the
## desktop 3 to 5 ms of every frame belonged to neither the GPU timer nor the renderer's CPU
## timer (agents.md, "What it costs"). The candidates were the simulation's two ticks a drawn
## frame, the fire yard and the lift wisps, and a candidate is not a thing to start cutting. So
## each block those guesses name holds a lap, and the probe adds the laps up per drawn frame.
##
## OFF UNLESS A PROBE TURNS IT ON. Off, `start` returns 0 and `lap` given a 0 returns at once:
## about twenty static calls a frame and no clock read. The probe's `--stopwatch=off` run exists to
## put a number on what the clock reads cost when it is on.
##
## STATIC AND PRELOADED BY PATH, not an autoload and not a `class_name`: nothing about it needs a
## node, and a name in the global class cache is one more thing a fresh checkout has to import
## before any script that mentions it will parse.
##
## NOT INSIDE THE SIMULATION'S TICK ANY MORE. `autoload/sim.gd` held laps round its tick and its state capture
## through Stage 1, which is how the extension was measured at 4 to 5 per cent of a frame. The rule set before
## Stage 1 said those laps come out if turning the stopwatch off moved the frame past the noise. It did twice
## (agents.md, Stages 1 and 2). The first result was re-run rather than obeyed, because the spreading fire
## front had changed between the launches too; the second, with the fires held, moved by less than two
## launches differed from each other, and was obeyed. The level's laps (its fire front included), the lift
## wisps' and the observer's stay, and no autoload reaches into `world/` for this now.

## Whether anything is being timed. Only a probe sets it.
static var running: bool = false

## Microseconds per block since the last `take`. A block timed twice in one drawn frame -- the
## level's physics step runs twice in a frame at 60 -- adds up.
static var _spent: Dictionary = {}


## Start or stop timing. A function and not a write to `running` from outside, because a probe
## that loads this by path holds a Script, and a static function is the one thing a Script is
## certain to answer.
static func run(on: bool) -> void:
	running = on
	_spent = {}


## Now, in microseconds, if the stopwatch is running; 0 if it is not.
static func start() -> int:
	return Time.get_ticks_usec() if running else 0


## Add the time since `since` to `block`. A `since` of 0 means the stopwatch was not running.
static func lap(block: StringName, since: int) -> void:
	if since == 0:
		return
	_spent[block] = int(_spent.get(block, 0)) + (Time.get_ticks_usec() - since)


## Every block's microseconds since this was last asked, and a clean sheet for the next frame.
static func take() -> Dictionary:
	var spent: Dictionary = _spent
	_spent = {}
	return spent
