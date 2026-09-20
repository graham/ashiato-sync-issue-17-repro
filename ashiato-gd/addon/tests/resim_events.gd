extends Node
## Does the client actually report when it rewinds, and does latency make it happen more?
##
##   Godot --path addon --headless res://tests/resim_events.tscn
##
## Rollback is the whole reason this architecture exists and it is completely invisible
## from the outside -- the car is simply not quite where it was. These counts are what the
## game draws from, so they have to be real: an indicator that never lights up is
## indistinguishable from a game that never rolls back.

const DT: float = 1.0 / 60.0
var _flight: Array = []
var _tick: int = 0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[resim] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _pump(s, c, delay: int) -> void:
	for p in s.take_outbound(): _flight.append([_tick + delay, false, p["bytes"], p["bits"]])
	for p in c.take_outbound(): _flight.append([_tick + delay, true, p["bytes"], p["bits"]])
	var keep: Array = []
	for e in _flight:
		if e[0] <= _tick:
			if e[1]: s.deliver(1, e[2], e[3])
			else: c.deliver(0, e[2], e[3])
		else: keep.append(e)
	_flight = keep


## Drives a car over a link of the given delay and reports [resims, span, own car resims].
func _run(delay: int) -> Array:
	_flight = []
	var s = ClassDB.instantiate("DrivingWorld")
	var c = ClassDB.instantiate("DrivingWorld")
	s.start(0)
	c.start(1)
	s.spawn_car(0, Vector3(20, 0.5, 0))
	for i in range(90):
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c, delay)
	while c.local_client_id() == 0:
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c, delay)
	s.spawn_car(c.local_client_id(), Vector3(0, 0.5, 0))

	var mine: int = 0
	for i in range(420):
		# Steering about keeps the client and server disagreeing, which is when a rollback
		# is worth doing. A car held straight agrees with itself.
		c.set_input(1.0, sin(float(i) * 0.06) * 0.8, false)
		_tick += 1; s.tick(DT); c.tick(DT); _pump(s, c, delay)
		for e in c.car_entities():
			if c.car_owner(e) == c.local_client_id():
				mine = e
	var stats: Dictionary = c.resim_stats()
	var out: Array = [int(stats["count"]), int(stats["last_span"]), c.car_resims(mine)]
	s.teardown(); c.teardown()
	return out


func _ready() -> void:
	var near: Array = _run(2)
	var far: Array = _run(8)
	print("[resim] 2-tick link: %d rewinds, last span %d frames, our car %d" % near)
	print("[resim] 8-tick link: %d rewinds, last span %d frames, our car %d" % far)

	_check("rollbacks_are_reported", near[0] > 0, "%d on a short link" % near[0])
	_check("our_own_car_is_named", near[2] > 0,
		"the car we drive was replayed %d times" % near[2])
	# A longer link means more to replay when a correction lands: the client has predicted
	# further ahead by the time the truth catches up.
	_check("further_to_rewind_on_a_worse_link", far[1] > near[1],
		"span %d -> %d frames" % [near[1], far[1]])

	print("[resim] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
