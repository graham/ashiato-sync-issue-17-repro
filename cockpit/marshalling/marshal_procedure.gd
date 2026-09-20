extends Node
class_name MarshalProcedure
## A JOB, AS A LIST OF STEPS, and the board that tells you which one you are on.
##
## Both levels are the same shape -- a sequence of things that have to happen in order, some
## of which are signals and some of which are states of the world ("her nosewheel is on the
## track") -- so the sequence is data and the levels are two tables.
##
## It WATCHES. It does not command, and it does not gate: every signal the player makes
## reaches the aircraft whether the procedure wanted it or not, because an aeroplane that
## ignored a stop signal on the grounds that stopping was not the next item on the checklist
## would be a worse thing than any mistake a player could make. What the procedure does is
## keep score and say what is wanted next.
##
## A step is:
##
##   expects  the signal that completes it, or &"" for a step the WORLD completes
##   tells    what to show the player
##   does     a Callable run when the expected SIGNAL arrives, whether or not that finishes
##            the step -- which is what starts anything the world then has to finish
##   until    a Callable answering "is it done" -- checked every frame while this step is on
##   then     a Callable run when the step completes
##   faults   signals that are a MISTAKE at this point, with what to say about each
##
## `does` and `then` are two different moments and the difference is a bug that was easy to
## write: the jet bridge is set swinging by the all-clear and the step is over when it
## ARRIVES, so hanging the swing off `then` meant it waited for itself for ever.

signal advanced(index: int, tells: String)
signal fault(why: String)
signal finished(score: Dictionary)

var steps: Array = []
var at: int = 0
var faults: int = 0
var _did: bool = false
var clock: float = 0.0
var done: bool = false

## Whatever the level wants remembered in the debrief -- how square the aeroplane ended up,
## how far off the bar it stopped. The procedure does not know what any of it means.
var marks: Dictionary = {}


func begin(list: Array) -> void:
	steps = list
	at = 0
	faults = 0
	_did = false
	clock = 0.0
	done = false
	marks.clear()
	_announce()


func _physics_process(delta: float) -> void:
	if done or steps.is_empty():
		return
	clock += delta
	var step: Dictionary = steps[at]
	var until: Callable = step.get("until", Callable())
	if until.is_valid() and until.call():
		_advance()


## A SIGNAL WAS MADE. If it is the one this step wanted, the step is done; if it is one this
## step calls a mistake, it is counted and said out loud.
func heard(id: StringName) -> void:
	if done or steps.is_empty():
		return
	var step: Dictionary = steps[at]
	if StringName(step.get("expects", &"")) == id:
		var does: Callable = step.get("does", Callable())
		if does.is_valid() and not _did:
			_did = true
			does.call()
		var until: Callable = step.get("until", Callable())
		# A step may want BOTH: the right signal AND the aeroplane in the right place. The
		# signal alone does not finish one of those -- it is the world that finishes it.
		if not until.is_valid():
			_advance()
		return
	var bad: Dictionary = step.get("faults", {})
	if bad.has(id):
		faults += 1
		fault.emit(String(bad[id]))


func _advance() -> void:
	var step: Dictionary = steps[at]
	var then: Callable = step.get("then", Callable())
	if then.is_valid():
		then.call()
	at += 1
	_did = false
	if at >= steps.size():
		done = true
		finished.emit({"seconds": clock, "faults": faults, "marks": marks})
		return
	_announce()


func _announce() -> void:
	if at < steps.size():
		advanced.emit(at, String(steps[at].get("tells", "")))


## And which signal would do it, so the ghosts can show the hands.
func expects() -> StringName:
	return StringName(steps[at].get("expects", &"")) if at < steps.size() else &""
