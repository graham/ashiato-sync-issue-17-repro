extends "res://tests/crowd.gd"
## Deterministic load gate. The carrier is an exact tick queue so this measures sync and
## the server rather than nine competing Godot processes. Real sockets are bulk_peers.

var _bulk_failed := false
var _bulk_said: Array[String] = []


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL extension_missing")
		get_tree().quit(1)
		return
	var settle := 600
	var measured := 1200
	var only: PackedInt32Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settle="):
			settle = int(arg.get_slice("=", 1))
		elif arg.begins_with("--measure="):
			measured = int(arg.get_slice("=", 1))
		elif arg.begins_with("--cell="):
			for part in arg.get_slice("=", 1).split(","):
				only.append(int(part))
	var cells: Array[PackedInt32Array] = [
		PackedInt32Array([0, 2, 8]), PackedInt32Array([200, 2, 8]),
		PackedInt32Array([0, 8, 8]), PackedInt32Array([200, 8, 8]),
		# A matching baseline makes the link-16 rollback comparison honest.
		PackedInt32Array([0, 8, 16]), PackedInt32Array([200, 8, 16]),
	]
	if only.size() == 3:
		cells = [only]
	# THE GAP IS COUNTED WHERE A RECORD LANDS, first and on a starved cell, because every gap below depends on it.
	if only.is_empty() or OS.get_cmdline_user_args().has("--metric-only"):
		_the_gap_is_counted_where_records_land()
		if OS.get_cmdline_user_args().has("--metric-only"):
			print("RESULT=%s%s" % ["FAIL " if _bulk_failed else "PASS", ", ".join(_bulk_said)])
			get_tree().quit(1 if _bulk_failed else 0)
			return
	var baselines: Dictionary = {}
	var reports: Array[Dictionary] = []
	var began := Time.get_ticks_msec()
	for cell in cells:
		var report := run_bulk_cell(cell[0], cell[1], cell[2], settle, measured)
		reports.append(report)
		var key := "%d:%d" % [cell[1], cell[2]]
		if cell[0] == 0:
			baselines[key] = report
		for fault in _cell_failures(report):
			_fail("%dx%dx%d_%s" % [cell[0], cell[1], cell[2], fault])
		if cell[0] == 200 and baselines.has(key):
			var base: Dictionary = baselines[key]
			_check("rollbacks_%dx%d" % [cell[1], cell[2]],
				float(report["rollbacks_per_s"]) <= float(base["rollbacks_per_s"]) * 2.0 + 0.001,
				"%.3f/s loaded, %.3f/s baseline" % [report["rollbacks_per_s"], base["rollbacks_per_s"]])
	# Wide tracing is deliberately separate from timing: recording every component for
	# eight clients materially changes the tick it is meant to price. These two audits
	# still hold starvation and freshness at both gate links.
	if only.is_empty():
		force_trace = true
		for link in [8, 16]:
			# Five observed seconds catches the every-frame starvation regression while
			# keeping the bounded gate comfortably below its 180 s process deadline.
			var audit := run_bulk_cell(200, 8, link, settle, mini(measured, 600))
			reports.append(audit)
			_check("trace_audit_%d_has_no_starvation" % link,
				int(audit["starved"]) == 0 and int(audit["truncated"]) == 0,
				"starved %d, truncated %d, serialised events %d, dropped %d" % [audit["starved"], audit["truncated"],
					audit["serialised_events"], audit["trace_dropped"]])
			# RECEIVED, not serialised: see `_the_gap_is_counted_where_records_land`.
			_check("trace_audit_%d_rotates_fairly" % link, int(audit["receipts_per_tick"]) > 0 \
				and int(audit["worst_update_gap_ticks"]) <= maxi(2, int(audit["predicted_gap_ticks"]) * 2),
				"received gap %d (median %d), predicted %d, %.2f receipts a second a craft" % [
					audit["worst_update_gap_ticks"], audit["receipt_gap_median_ticks"], audit["predicted_gap_ticks"],
					audit["receipts_per_s_per_craft"]])
		force_trace = false
	# Mutants exercise the verdict, independently of whatever this machine measured.
	if not reports.is_empty():
		var good := reports[0]
		var mutant := good.duplicate(true)
		mutant["down_payload_B_tick"] = float(mutant["budget_B_tick"]) * 4.0
		_check("budget_mutant_is_refused", _cell_failures(mutant).has("budget_mean"), "four times budget")
		mutant = good.duplicate(true)
		mutant["starved"] = 1
		_check("starvation_mutant_is_refused", _cell_failures(mutant).has("input_starved"), "one starved frame")
		mutant = good.duplicate(true)
		mutant["lost"] = 1
		_check("flight_mutant_is_refused", _cell_failures(mutant).has("flight_lost"), "one stalled craft")
	print("[bulk_load] %d cell(s) in %.1f s" % [reports.size(), float(Time.get_ticks_msec() - began) / 1000.0])
	print("RESULT=%s%s" % ["FAIL " if _bulk_failed else "PASS", ", ".join(_bulk_said)])
	get_tree().quit(1 if _bulk_failed else 0)


## A CELL STARVED ON PURPOSE: 60 stack craft and two peers at 20,000 B/s, 167 bytes a tick, which carries a few craft
## updates a tick. (At 8,000 B/s, 67 bytes a tick, a whole first record does not fit and the client drew 1 craft of 62:
## that tests creation, not rotation.) Up to ashiato-sync 90f50bf `component_sent` was written while an entity was
## serialised, before the budget check, so a gap counted from it was one tick whatever the budget; this checks that the
## cell's gap is counted from what the watched client RECEIVED, and that it shows the starvation. Since 8fa08cf sync
## defers `component_sent` until the record is in a packet, so the server's count now AGREES with the receipts (16 and
## 16 ticks where it was 1 and 8+), and the second check pins that: if it ever goes back to counting what was owed,
## every "serialised" column in crowd.gd means something else again.
func _the_gap_is_counted_where_records_land() -> void:
	send_budget_bps = 20000
	var starved := run_bulk_cell(60, 2, 8, 300, 600)
	send_budget_bps = 0
	var received := int(starved.get("receipt_gap_worst_ticks", -1))
	var serialised := int(starved.get("serialised_gap_worst_ticks", starved.get("worst_update_gap_ticks", -1)))
	_check("a_starved_cell_counts_its_gap_from_receipts",
		received >= 8 and int(starved.get("worst_update_gap_ticks", -1)) == received,
		"received gap %d ticks, reported %d, %.2f receipts a second a craft at %d B a tick" % [received,
			int(starved.get("worst_update_gap_ticks", -1)), float(starved.get("receipts_per_s_per_craft", -1.0)),
			int(starved.get("budget_B_tick", -1))])
	_check("and_the_servers_sent_trace_agrees_with_the_receipts", absi(received - serialised) <= 2,
		"sent gap %d ticks against received %d" % [serialised, received])


func _cell_failures(report: Dictionary) -> Array[String]:
	var faults: Array[String] = []
	var expected := int(report["craft"]) + int(report["peers"])
	if int(report["craft_seen"]) < expected:
		faults.append("craft_seen")
	if int(report["out_of_band"]) != 0:
		faults.append("separation")
	if int(report["lost"]) != 0:
		faults.append("flight_lost")
	if float(report["down_payload_B_tick"]) > float(report["budget_B_tick"]) * 1.02:
		faults.append("budget_mean")
	if int(report["largest_down_tick_B"]) > int(report["budget_B_tick"]) + 1200:
		faults.append("budget_peak")
	if int(report["largest_down_B"]) > 1200:
		faults.append("packet_mtu")
	if int(report["craft"]) > 0 and float(report["receipts_per_tick"]) > 0.0 and int(report["worst_update_gap_ticks"]) > \
			maxi(2, int(report["predicted_gap_ticks"]) * 2):
		faults.append("unfair_rotation")
	if int(report["starved"]) > 0:
		faults.append("input_starved")
	if int(report["truncated"]) != 0:
		faults.append("input_truncated")
	if int(report["buffer_last"]) - int(report["buffer_first"]) > 1:
		faults.append("buffer_climbed")
	if bool(report.get("timing_valid", true)) and int(report["craft"]) == 200 and int(report["peers"]) == 8 and \
			float(report["server_tick_ms"]) >= 1000.0 / tick_hz:
		faults.append("server_missed_120_hz")
	return faults


func _check(name: String, passed: bool, detail: String) -> void:
	print("[bulk_load] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_fail(name)


func _fail(name: String) -> void:
	print("[bulk_load] FAIL %s" % name)
	_bulk_failed = true
	_bulk_said.append(name)
