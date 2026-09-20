extends Node
## Does the tracer actually produce anything, and can it be turned off?
##
##   Godot --path addon --headless res://tests/tracing.tscn

const DT: float = 1.0 / 60.0
const DELAY: int = 4
var _flight: Array = []
var _tick: int = 0
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[trace] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _pump(s, c) -> void:
	for p in s.take_outbound(): _flight.append([_tick + DELAY, false, p["bytes"], p["bits"]])
	for p in c.take_outbound(): _flight.append([_tick + DELAY, true, p["bytes"], p["bits"]])
	var keep: Array = []
	for e in _flight:
		if e[0] <= _tick:
			if e[1]: s.deliver(1, e[2], e[3])
			else: c.deliver(0, e[2], e[3])
		else: keep.append(e)
	_flight = keep


func _run(tracing: bool) -> Array:
	_flight = []
	var s = ClassDB.instantiate("DrivingWorld")
	var c = ClassDB.instantiate("DrivingWorld")
	s.set_tracing(tracing)
	c.set_tracing(tracing)
	s.start(0)
	c.start(1)
	s.spawn_car(0, Vector3(0, 0.5, 0))
	var events: Array = []
	for i in range(240):
		_tick += 1
		c.set_input(1.0, 0.3, false)
		s.tick(DT); c.tick(DT); _pump(s, c)
		events.append_array(s.take_trace_events())
		events.append_array(c.take_trace_events())
	s.teardown(); c.teardown()
	return events


func _ready() -> void:
	var probe = ClassDB.instantiate("DrivingWorld")
	_check("tracing_is_built_in", probe.tracing_available(),
		"ASHIATO_GD_WITH_TRACING -- without it set_tracing can never do anything")
	_check("set_tracing_reports_success", probe.set_tracing(true), "accepted")
	probe.teardown()

	var on: Array = _run(true)
	_check("tracer_produces_events", on.size() > 0, "%d events" % on.size())

	var kinds: Dictionary = {}
	for e in on:
		kinds[e["type"]] = int(kinds.get(e["type"], 0)) + 1
	var names: Array = kinds.keys()
	names.sort()
	for n in names:
		print("[trace]   %-24s %d" % [n, kinds[n]])

	# The events that actually explain a desync are the ones worth having.
	_check("sees_the_handshake", kinds.has("client_connected"), "client_connected recorded")
	_check("sees_components_move",
		kinds.has("component_sent") or kinds.has("component_applied"),
		"component traffic recorded")

	var off: Array = _run(false)
	_check("off_means_off", off.is_empty(),
		"%d events with tracing disabled" % off.size())

	print("[trace] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)
