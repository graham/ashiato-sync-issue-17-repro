extends Node
## How violently does a car move when the server corrects it?
##
##   Godot --path addon --headless res://tests/correction_smoothness.tscn
##
## A correction is unavoidable -- prediction is a guess and the server has the truth. What
## is avoidable is the car ARRIVING at the right place rather than sliding into it. This
## measures the difference the only way that counts: the largest single-frame jump in the
## position actually drawn, over a link bad enough to force rollbacks.
##
## Measured on the SAMPLED position, not the simulation's, because the sampled one is what
## a player sees -- error blending deliberately lets the two disagree for a moment.
##
## THE CORRECTIONS ARE MADE BY LOSING THE CLIENT'S INPUT, and they used to be made by a bug.
## Until 2026-09-16 a 20-tick link forced rollbacks on its own: sync's client sent its input
## window oldest first and cut it at the input count of 31, so past a lead of 31 frames the
## server steered the car on stale input every frame -- 38 rewinds here, the simulation
## jumping 2.65 m. `ashiato-sync-send-newest-inputs-first.patch` fixed that, and the same link
## then predicted cleanly: 1 rewind, and every check below had nothing to measure. So now the
## client's packets are lost for LOST_TICKS of every LOST_EVERY, which is what a real link
## does: the server steps those frames on the last steering it had while the client has
## already reversed it. 16 rewinds, simulation 2.43 m, drawn 0.22 m (lane/starve).

const DT: float = 1.0 / 60.0
const LOST_EVERY: int = 60
const LOST_TICKS: int = 10
var _flight: Array = []
var _tick: int = 0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[smooth] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _pump(s, c, delay: int) -> void:
	for p in s.take_outbound(): _flight.append([_tick + delay, false, p["bytes"], p["bits"]])
	for p in c.take_outbound():
		if _tick % LOST_EVERY < LOST_TICKS:
			continue
		_flight.append([_tick + delay, true, p["bytes"], p["bits"]])
	var keep: Array = []
	for e in _flight:
		if e[0] <= _tick:
			if e[1]: s.deliver(1, e[2], e[3])
			else: c.deliver(0, e[2], e[3])
		else: keep.append(e)
	_flight = keep


func _ready() -> void:
	_flight = []
	var s = ClassDB.instantiate("DrivingWorld")
	var c = ClassDB.instantiate("DrivingWorld")
	s.start(0)
	c.start(1)
	s.spawn_car(0, Vector3(20, 0.5, 0))
	for i in range(90):
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c, 20)
	while c.local_client_id() == 0:
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c, 20)
	s.spawn_car(c.local_client_id(), Vector3(0, 0.5, 0))

	var mine: int = 0
	for i in range(120):
		c.set_input(1.0, 0.0, false)
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c, 20)
		for e in c.car_entities():
			if c.car_owner(e) == c.local_client_id():
				mine = e

	# Steer about over a long link so the client and server keep disagreeing.
	var worst_drawn: float = 0.0
	var worst_sim: float = 0.0
	var previous_drawn := Vector3.ZERO
	var previous_sim := Vector3.ZERO
	var samples: int = 0
	var divergence: float = 0.0
	for i in range(600):
		c.set_input(1.0, 1.0 if (i / 15) % 2 == 0 else -1.0, false)
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c, 20)
		var sim: Vector3 = c.car_state(mine).get("position", Vector3())
		var drawn := sim
		for sample in c.sampled_cars():
			if int(sample["entity"]) == mine and sample["sampled"]:
				drawn = sample["position"]
		# How far the drawn car is from the simulated one. Error blending IS this gap: the
		# simulation jumps to the server's answer and the drawing is allowed to lag behind
		# and catch up. If this is always zero, nothing is being blended.
		divergence = maxf(divergence, (drawn - sim).length())
		if samples > 0:
			worst_drawn = maxf(worst_drawn, (drawn - previous_drawn).length())
			worst_sim = maxf(worst_sim, (sim - previous_sim).length())
		previous_drawn = drawn
		previous_sim = sim
		samples += 1

	var stats: Dictionary = c.resim_stats()
	print("[smooth] %d rewinds over a 20-tick link" % int(stats["count"]))
	print("[smooth] worst single-frame move: simulation %.4f m, DRAWN %.4f m" % [
		worst_sim, worst_drawn])
	print("[smooth] furthest the drawn car lagged the simulation: %.4f m" % divergence)

	_check("corrections_happened", int(stats["count"]) > 5,
		"%d rewinds -- nothing to smooth otherwise" % int(stats["count"]))
	# THE measurement. The simulation is allowed to jump: it has to, the server is right and
	# the prediction was not. What must not jump is the car on screen.
	_check("drawn_is_far_smoother_than_the_simulation", worst_drawn < worst_sim * 0.5,
		"drawn %.2f m vs simulated %.2f m in one frame" % [worst_drawn, worst_sim])
	# A car at 20 m/s covers 0.33 m a frame, so anything much past that is a jump rather
	# than movement.
	_check("nothing_teleports_on_screen", worst_drawn < 0.55,
		"largest drawn step %.4f m" % worst_drawn)
	# And the blend has to actually be engaged: if the drawn car never lags the simulated
	# one, no error is being paid off over time and the smoothness above is a coincidence.
	_check("the_blend_is_doing_the_work", divergence > 0.2,
		"drawn car trailed the truth by up to %.2f m, then caught up" % divergence)

	s.teardown(); c.teardown()
	print("[smooth] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
