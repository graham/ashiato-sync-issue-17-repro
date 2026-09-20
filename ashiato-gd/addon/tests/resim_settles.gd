extends Node
## Does resimulation converge, or does it keep going forever?
##
##   Godot --path addon --headless res://tests/resim_settles.tscn
##
## A rollback is meant to be an event: the server disagrees, the client rewinds, replays,
## and is then RIGHT -- so the next frame needs no rollback. If they keep coming every
## frame, the replay is not fixing anything and the client is disagreeing about something
## it cannot fix by resimulating.

const DT: float = 1.0 / 60.0
var _flight: Array = []
var _tick: int = 0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[settle] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _pump(s, c) -> void:
	for p in s.take_outbound(): _flight.append([_tick + 4, false, p["bytes"], p["bits"]])
	for p in c.take_outbound(): _flight.append([_tick + 4, true, p["bytes"], p["bits"]])
	var keep: Array = []
	for e in _flight:
		if e[0] <= _tick:
			if e[1]: s.deliver(1, e[2], e[3])
			else: c.deliver(0, e[2], e[3])
		else: keep.append(e)
	_flight = keep


## Drives steadily and reports rollbacks in the FIRST half versus the SECOND. A system that
## settles does most of its correcting early; one that never settles keeps the same rate.
func _run(predict_all: bool) -> Array:
	_flight = []
	var s = ClassDB.instantiate("DrivingWorld")
	var c = ClassDB.instantiate("DrivingWorld")
	s.start(0)
	c.set_predict_all(predict_all)
	c.start(1)
	# Two other cars, driven by the server -- the ones a client has no input for.
	var bots: Array = [s.spawn_car(0, Vector3(20, 0.5, 0)), s.spawn_car(0, Vector3(40, 0.5, 0))]
	for i in range(90):
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c)
	while c.local_client_id() == 0:
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c)
	s.spawn_car(c.local_client_id(), Vector3(0, 0.5, 0))

	for i in range(120):
		c.set_input(1.0, 0.0, false)
		for b in bots:
			s.set_car_input(b, 0.8, 0.2, false)
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c)

	var first: int = int(c.resim_stats()["count"])
	for i in range(300):
		c.set_input(1.0, 0.1, false)
		for b in bots:
			s.set_car_input(b, 0.8, 0.2, false)
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c)
	var mid: int = int(c.resim_stats()["count"])
	for i in range(300):
		c.set_input(1.0, 0.1, false)
		for b in bots:
			s.set_car_input(b, 0.8, 0.2, false)
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c)
	var last: int = int(c.resim_stats()["count"])
	s.teardown(); c.teardown()
	return [mid - first, last - mid]


func _ready() -> void:
	var interpolated: Array = _run(false)
	var predicted: Array = _run(true)
	print("[settle] interpolating others: %d rewinds in 300 frames, then %d" % interpolated)
	print("[settle] predicting every car: %d rewinds in 300 frames, then %d" % predicted)

	# Steady driving over a good link should need almost no correcting at all.
	_check("interpolating_settles", interpolated[1] <= 10,
		"%d rewinds in the last 300 frames" % interpolated[1])
	_check("predicting_everything_does_not_settle", predicted[1] > 50,
		"%d rewinds in the last 300 frames -- one almost every frame" % predicted[1])

	print("[settle] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
