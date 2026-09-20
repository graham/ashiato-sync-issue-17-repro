extends Node
## PROBE: what fills a client's 1024-byte tick in the real sky.
##
##   Godot --headless --path cockpit res://tests/wire_budget.tscn
##
## SOLO, so sync's whole path runs with no link and nothing here is timing: the level's own traffic, the server
## traced. For every record the server serialised for the local client over WATCH_TICKS: bits per component, how many
## of those were full records (a VehicleKind never changes, so it goes only in a full record), and which craft --
## parked or moving -- the bits were spent on. Up to ashiato-sync 90f50bf serialised was DEMAND: sync traced a record
## before it checked the budget, so the total over 1024 bytes a tick was what did not fit. Since 8fa08cf the trace waits
## until the record is in a packet, so under a binding budget this counts what was SENT; solo the budget does not bind
## (1,626 of 2,042 bytes a tick), and the numbers were identical before and after (2026-09-18).
##
## Read RESULT=, not the exit code.

const SETTLE_TICKS: int = 1200
const WATCH_TICKS: int = 600
## A craft slower than this is parked, for the split.
const PARKED_SPEED: float = 1.0

var _bits: Dictionary = {}
var _count: Dictionary = {}
var _entity_bits: Dictionary = {}
var _entity_full: Dictionary = {}
var _entity_records: Dictionary = {}


func _ready() -> void:
	Sim.tracing = true
	Net.play_solo()
	get_tree().root.add_child.call_deferred(load("res://world/sky.tscn").instantiate())
	for i in range(SETTLE_TICKS):
		await get_tree().physics_frame
		if Sim.server != null:
			Sim.server.take_trace_events()
	if Sim.server == null:
		_finish("FAIL no server")
		return
	var client_id: int = Sim.local_client_id()
	# THE PEAK AS WELL AS THE MEAN, because a budget sized on the mean starves every tick above it.
	var per_tick: PackedInt64Array = []
	for i in range(WATCH_TICKS):
		await get_tree().physics_frame
		var this_tick: int = 0
		for event in Sim.server.take_trace_events():
			if String(event["type"]) != "component_sent" or int(event["client"]) != client_id:
				continue
			var component: String = event["component"]
			var entity: int = int(event["entity"])
			var bits: int = int(event["bits"])
			this_tick += bits
			_bits[component] = int(_bits.get(component, 0)) + bits
			_count[component] = int(_count.get(component, 0)) + 1
			_entity_bits[entity] = int(_entity_bits.get(entity, 0)) + bits
			if component == "VehicleKind":
				_entity_full[entity] = int(_entity_full.get(entity, 0)) + 1
			if component == "VehicleState":
				_entity_records[entity] = int(_entity_records.get(entity, 0)) + 1
		per_tick.append(this_tick)
	var dropped: int = int(Sim.server.trace_events_dropped())
	var sorted_ticks: PackedInt64Array = per_tick.duplicate()
	sorted_ticks.sort()
	print("[wire] component bytes a tick: peak %.0f, 99th percentile %.0f, median %.0f (budget %s)" % [
		sorted_ticks[sorted_ticks.size() - 1] / 8.0, sorted_ticks[int(sorted_ticks.size() * 0.99)] / 8.0,
		sorted_ticks[sorted_ticks.size() / 2] / 8.0, Sim.server.net_status().get("send_budget_per_tick", "?")])
	var speeds: Dictionary = {}
	var kinds: Dictionary = {}
	for state in Sim.server.vehicle_states():
		speeds[int(state["entity"])] = (state["velocity"] as Vector3).length()
		kinds[int(state["entity"])] = int(state["kind"])
	var total: int = 0
	for component in _bits:
		total += int(_bits[component])
	print("[wire] %d craft; demand %.0f bytes a tick for one client against 1024; trace dropped %d" % [speeds.size(),
		total / 8.0 / WATCH_TICKS, dropped])
	var names: Array = _bits.keys()
	names.sort_custom(func(a, b) -> bool: return int(_bits[a]) > int(_bits[b]))
	for component in names:
		print("[wire] %-14s %5.0f bytes a tick (%4.1f%%), %6.1f sends a tick, %.0f bits each" % [component,
			int(_bits[component]) / 8.0 / WATCH_TICKS, 100.0 * int(_bits[component]) / maxf(total, 1.0),
			float(_count[component]) / WATCH_TICKS, float(_bits[component]) / maxf(int(_count[component]), 1)])
	var parked_bits: int = 0
	var moving_bits: int = 0
	var parked: int = 0
	var records: int = 0
	var full: int = 0
	for entity in speeds:
		records += int(_entity_records.get(entity, 0))
		full += int(_entity_full.get(entity, 0))
		if float(speeds[entity]) < PARKED_SPEED:
			parked += 1
			parked_bits += int(_entity_bits.get(entity, 0))
		else:
			moving_bits += int(_entity_bits.get(entity, 0))
	print("[wire] %d parked craft cost %.0f bytes a tick, %d moving craft %.0f; %d of %d VehicleState records were full" % [
		parked, parked_bits / 8.0 / WATCH_TICKS, speeds.size() - parked, moving_bits / 8.0 / WATCH_TICKS, full, records])
	var costly: Array = _entity_bits.keys()
	costly.sort_custom(func(a, b) -> bool: return int(_entity_bits[a]) > int(_entity_bits[b]))
	for entity in costly.slice(0, 12):
		print("[wire]   entity %d kind %d speed %.1f m/s: %.0f bytes a tick, %d VehicleState sends, %d full" % [entity,
			int(kinds.get(entity, -1)), float(speeds.get(entity, -1.0)), int(_entity_bits[entity]) / 8.0 / WATCH_TICKS,
			int(_entity_records.get(entity, 0)), int(_entity_full.get(entity, 0))])
	_finish("PASS measured %d ticks" % WATCH_TICKS)


func _finish(verdict: String) -> void:
	print("RESULT=%s" % verdict)
	get_tree().quit(0 if verdict.begins_with("PASS") else 1)
