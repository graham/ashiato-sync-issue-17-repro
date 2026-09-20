extends Node
class_name SegmentProbe
## Watches one vehicle's drawn pose and checks it never leaves the segment between the two
## simulated states it is interpolating.
##
## A separate node with a LATE process priority, rather than a check written inline in the
## test, because the ordering is the whole difficulty. Reading the node's transform and the
## simulation's two states from a coroutine awaiting `process_frame` compares a pose drawn
## this frame against a pair captured for the next one, and reports being off by a whole
## tick of motion when nothing is wrong. Running after the level's own `_process` is the
## only way to see both at the same instant.

## Higher runs later. The level draws at the default 0.
const LATE: int = 100

var entity: int = 0
var view: Node3D = null
var worst: float = 0.0
## The same test on the ATTITUDE, which had no coverage at all until an aeroplane at
## 300 kph turned out to be snapping in pitch rather than in position. A rotation that
## leaves the arc between the two simulated attitudes is a rotation being drawn wrong.
var worst_angle: float = 0.0
var frames: int = 0
var watching: bool = false


func _ready() -> void:
	process_priority = LATE


func _process(_delta: float) -> void:
	if not watching or view == null or not is_instance_valid(view):
		return
	if not Sim.current.has(entity):
		return
	var drawn: Vector3 = view.global_position
	var was: Vector3 = (Sim.previous.get(entity, Sim.current[entity]) as Dictionary).get(
		"position", drawn)
	var goes: Vector3 = (Sim.current[entity] as Dictionary).get("position", drawn)
	# On the segment: out and back equals the segment, for any point on it and no point
	# off it.
	worst = maxf(worst, absf(drawn.distance_to(was) + drawn.distance_to(goes)
		- was.distance_to(goes)))

	# On the ARC: the same argument in angles. Out and back equals the arc, for any
	# attitude on it and no attitude off it.
	var spun: Quaternion = view.global_basis.get_rotation_quaternion()
	var spun_was: Quaternion = (Sim.previous.get(entity, Sim.current[entity])
		as Dictionary).get("basis", spun)
	var spun_goes: Quaternion = (Sim.current[entity] as Dictionary).get("basis", spun)
	worst_angle = maxf(worst_angle, absf(_apart(spun, spun_was) + _apart(spun, spun_goes)
		- _apart(spun_was, spun_goes)))
	frames += 1


## How far apart two attitudes are, in metres of wingtip.
##
## NOT Quaternion.angle_to, and the difference matters here more than anywhere: angle_to is
## acos of a dot product that is almost exactly 1, and acos near 1 loses half its
## significant figures. Its noise floor is around 0.0006 rad -- which is LARGER than a whole
## tick of an aeroplane's pitch change. Measured with it, a perfectly smooth rotation reads
## as seven slices of nothing and one of everything, which looks exactly like snapping and
## is not.
##
## The chord swept by two perpendicular unit vectors has no such problem: it is a
## subtraction, it is proportional to the angle for small angles, and using two of them
## catches a rotation about either.
static func _apart(a: Quaternion, b: Quaternion) -> float:
	return maxf((a * Vector3.FORWARD - b * Vector3.FORWARD).length(),
		(a * Vector3.RIGHT - b * Vector3.RIGHT).length())
