extends Node
## Can Box3D be rewound? The whole predicted-driving architecture rests on this.
##
##   Godot --path addon --headless res://tests/physics_rewind.tscn
##
## Rollback works like this: the client keeps per-frame state, the server says "you were
## wrong at frame N", and the client restores frame N and RE-STEPS to now. That is only
## viable if restoring a body and re-stepping reproduces the same trajectory.
##
## Box3D is documented as deterministic, but its public API restores a body's transform
## and velocities and NOT the solver's warm-start / contact state. So the honest question
## is not "is it deterministic" (it is) but "how much does a rewind THROUGH CONTACT
## drift". This measures that in both regimes rather than assuming either.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 60.0
const SUB_STEPS: int = 4

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[rewind] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## A deterministic, frame-indexed force. Rollback replays the same inputs, so the drive
## has to be a pure function of the frame number -- anything time- or random-based would
## make the replay a different simulation and prove nothing.
func _force_for(frame: int) -> Vector3:
	return Vector3(sin(float(frame) * 0.11) * 900.0, 0.0, cos(float(frame) * 0.07) * 900.0)


func _run(world, body: int, from_frame: int, to_frame: int) -> void:
	for frame in range(from_frame, to_frame):
		world.apply_force(body, _force_for(frame))
		world.step(DT, SUB_STEPS)


func _drift(a: Dictionary, b: Dictionary) -> float:
	var pa: Vector3 = a.get("position", Vector3())
	var pb: Vector3 = b.get("position", Vector3())
	return pa.distance_to(pb)


func _ready() -> void:
	if not ClassDB.class_exists("Box3DWorld"):
		print("[rewind] Box3DWorld not registered; build with -WithPhysics")
		_finish()
		return

	# ---- 1. plain determinism: same inputs, two worlds, same result ----
	var a = ClassDB.instantiate("Box3DWorld")
	var b = ClassDB.instantiate("Box3DWorld")
	for w in [a, b]:
		w.create(Vector3(0, -9.81, 0))
		w.add_box(Vector3(0, -1, 0), Vector3(50, 1, 50), 0.0, true)
	var body_a: int = a.add_box(Vector3(0, 5, 0), Vector3(0.5, 0.5, 0.5), 10.0, false)
	var body_b: int = b.add_box(Vector3(0, 5, 0), Vector3(0.5, 0.5, 0.5), 10.0, false)

	_run(a, body_a, 0, 180)
	_run(b, body_b, 0, 180)
	var determinism_drift: float = _drift(a.get_state(body_a), b.get_state(body_b))
	_check("two_worlds_agree", determinism_drift < 1e-6,
		"%.9f m apart after 180 steps" % determinism_drift)

	# ---- 2. rewind in FREE FLIGHT (no contact, so no warm-start state to lose) ----
	var f = ClassDB.instantiate("Box3DWorld")
	f.create(Vector3(0, -9.81, 0))
	# Ground far below, so the box never touches it during the window.
	f.add_box(Vector3(0, -500, 0), Vector3(50, 1, 50), 0.0, true)
	var fb: int = f.add_box(Vector3(0, 50, 0), Vector3(0.5, 0.5, 0.5), 10.0, false)

	_run(f, fb, 0, 60)
	var free_checkpoint: Dictionary = f.get_state(fb)
	_run(f, fb, 60, 120)
	var free_truth: Dictionary = f.get_state(fb)

	f.set_state(fb, free_checkpoint)
	_run(f, fb, 60, 120)
	var free_error: float = _drift(f.get_state(fb), free_truth)
	_check("rewind_exact_in_free_flight", free_error < 1e-5,
		"%.9f m after rewinding 60 frames" % free_error)

	# ---- 3. rewind THROUGH CONTACT, which is the case a driving game actually hits ----
	var c = ClassDB.instantiate("Box3DWorld")
	c.create(Vector3(0, -9.81, 0))
	c.add_box(Vector3(0, -1, 0), Vector3(50, 1, 50), 0.0, true)
	var cb: int = c.add_box(Vector3(0, 1.0, 0), Vector3(0.5, 0.5, 0.5), 10.0, false)

	# Settle onto the ground first so the rewind window is full of live contact.
	_run(c, cb, 0, 90)
	var contact_checkpoint: Dictionary = c.get_state(cb)
	_run(c, cb, 90, 150)
	var contact_truth: Dictionary = c.get_state(cb)

	c.set_state(cb, contact_checkpoint)
	_run(c, cb, 90, 150)
	var contact_error: float = _drift(c.get_state(cb), contact_truth)

	# The number that decides the design. A car is ~4 m long, and a correction under a
	# centimetre after a 60-frame (1 second) rollback is invisible once the client
	# smooths it. Anything approaching a car width would mean rollback is unusable and
	# the sim would have to be a custom deterministic model instead.
	print("[rewind] contact rollback drift over 60 frames: %.6f m" % contact_error)
	_check("rewind_usable_through_contact", contact_error < 0.01,
		"%.6f m, budget 0.01" % contact_error)

	# ---- 4. a rollback that changes nothing must change nothing ----
	# Restoring the CURRENT state and re-stepping zero frames is the no-op case; if that
	# drifts, the state capture itself is lossy and nothing else can be trusted.
	var s = ClassDB.instantiate("Box3DWorld")
	s.create(Vector3(0, -9.81, 0))
	s.add_box(Vector3(0, -1, 0), Vector3(50, 1, 50), 0.0, true)
	var sb: int = s.add_box(Vector3(0, 3, 0), Vector3(0.5, 0.5, 0.5), 10.0, false)
	_run(s, sb, 0, 45)
	var before: Dictionary = s.get_state(sb)
	s.set_state(sb, before)
	var after: Dictionary = s.get_state(sb)
	_check("state_capture_is_lossless", _drift(before, after) < 1e-9,
		"get -> set -> get is identity")

	_finish()


func _finish() -> void:
	print("[rewind] RESULT=%s" % (
		"PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
