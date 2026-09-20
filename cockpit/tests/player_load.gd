extends "res://tests/bulk_load.gd"
## Headless REPORT, not a gate: WHAT 8, 16, 32 AND 64 PLAYERS COST ONE HOST, and where it breaks down.
##
##   Godot --headless --xr-mode off --fixed-fps 120 --path cockpit res://tests/player_load.tscn
##       [-- --craft=200 --settle=600 --measure=600 --players=8,16,32,64]
##
## THE USER, 2026-09-18: "let's make the max 64 for now, i want to see how things break down at higher loads so having
## an unreasonable amount is okay." So this does not fail on what it finds; it says it. One host and N in-process
## peers over `crowd.gd`'s exact tick queue (the carrier `bulk_load` gates on: it prices sync and the server, not N
## competing Godot processes), with `--craft` machines in the sky, at each step of `--players`. Per step it prints:
##
##   host tick         mean and 99th percentile, ms, against the 8.33 ms a 120 Hz tick has
##   down a client     kB/s, and the host's total up, kB/s and Mbit/s: every client is sent its own copy
##   up                kB/s from each client and from all of them
##   worst update gap  ticks between records of one craft on one client, against what the budget predicts
##   faults            what `bulk_load`'s own predicate calls wrong with the cell, by name, and the wall time
##
## and then the table, which is what went into cockpit/agents.md ("Sixty-four players") and the seats learnings.
## Read RESULT=, which is PASS whenever every step ran to its end: the numbers are the product.

var _load_steps: Array[Dictionary] = []


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL extension_missing")
		get_tree().quit(1)
		return
	var craft := 200
	var settle := 600
	var measure := 600
	var players: PackedInt32Array = [8, 16, 32, 64]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--craft="):
			craft = int(arg.get_slice("=", 1))
		elif arg.begins_with("--settle="):
			settle = int(arg.get_slice("=", 1))
		elif arg.begins_with("--measure="):
			measure = int(arg.get_slice("=", 1))
		elif arg.begins_with("--refusals="):
			# The refusal bound (crowd.gd); 0 is unbounded.
			budget_refusals = int(arg.get_slice("=", 1))
		elif arg.begins_with("--budget="):
			# Bytes a second per client, to lift the 245 kB/s cap and see what a cell DEMANDS (crowd.gd, `budget`).
			send_budget_bps = int(arg.get_slice("=", 1))
		elif arg.begins_with("--players="):
			players.clear()
			for part in arg.get_slice("=", 1).split(","):
				players.append(int(part))
	var ran := 0
	for n in players:
		# A PLAYER IS THE HOST OR A PEER: the host flies nobody here, so N players are N peers.
		var began := Time.get_ticks_msec()
		var report := run_bulk_cell(craft, n, 8, settle, measure)
		var wall_s := float(Time.get_ticks_msec() - began) / 1000.0
		var faults: Array[String] = _cell_failures(report) if not report.is_empty() else ["no_report"]
		# AND A HOST THAT CANNOT KEEP ITS TICK, which `bulk_load`'s predicate only prices at 200 craft and eight peers.
		if not report.is_empty() and float(report["server_tick_mean_ms"]) >= 1000.0 / tick_hz:
			faults.append("host_tick_over_budget")
		var step := {"players": n, "report": report, "faults": faults, "wall_s": wall_s}
		_load_steps.append(step)
		_say(step)
		ran += 1
	_table()
	print("RESULT=%s" % ("PASS" if ran == players.size() else "FAIL %d of %d steps ran" % [ran, players.size()]))
	get_tree().quit(0 if ran == players.size() else 1)


func _say(step: Dictionary) -> void:
	var r: Dictionary = step["report"]
	if r.is_empty():
		print("[player_load] %d players: no report" % step["players"])
		return
	var up_total: float = float(r["server_out_kB_s"])
	print("[player_load] %d players, %d craft: host tick %.2f ms mean, %.2f p99 (of %.2f); down %.1f kB/s a client, host up %.0f kB/s = %.1f Mbit/s; up %.1f kB/s a client, %.0f all; worst gap %d ticks (predicted %d); seen %d of %d; faults %s; %.0f s of wall"
		% [step["players"], int(r["craft"]), float(r["server_tick_mean_ms"]), float(r["server_tick_p99_ms"]),
			1000.0 / tick_hz, float(r["down_kB_s_per_client"]), up_total, up_total * 8.0 / 1000.0,
			float(r["up_kB_s_per_client"]), float(r["up_kB_s_per_client"]) * int(step["players"]),
			int(r["worst_update_gap_ticks"]), int(r["predicted_gap_ticks"]), int(r["craft_seen"]),
			int(r["craft"]) + int(step["players"]), ", ".join(PackedStringArray(step["faults"])) if not (step["faults"] as Array).is_empty()
			else "none", step["wall_s"]])
	# AND WHAT THE POSES COST (lane/ashiato-latest step 3): `--tracked` moves every head and hand every tick, `--pose-lod=on`
	# leaves far ones out. The gaps are client 0's own, near and far of its craft.
	print("[player_load] %d players: refusals %s, tracked %s, pose lod %s, %d pairs masked; near gap %d, far gap %d ticks; budget %s"
		% [step["players"], "default (2)" if budget_refusals < 0 else ("unbounded" if budget_refusals == 0 else str(budget_refusals)), r.get("tracked", false), r.get("pose_lod", false), int(r.get("pose_masked_pairs", -1)),
			int(r.get("near_gap_worst_ticks", -1)), int(r.get("far_gap_worst_ticks", -1)),
			"default" if send_budget_bps <= 0 else "%d B/s" % send_budget_bps])


func _table() -> void:
	print("[player_load] | players | host tick mean / p99 ms | down a client kB/s | host up Mbit/s | up all kB/s | worst gap ticks | faults |")
	for step in _load_steps:
		var r: Dictionary = step["report"]
		if r.is_empty():
			continue
		print("[player_load] | %d | %.2f / %.2f | %.1f | %.1f | %.0f | %d | %s |" % [step["players"],
			float(r["server_tick_mean_ms"]), float(r["server_tick_p99_ms"]), float(r["down_kB_s_per_client"]),
			float(r["server_out_kB_s"]) * 8.0 / 1000.0, float(r["up_kB_s_per_client"]) * int(step["players"]),
			int(r["worst_update_gap_ticks"]), ", ".join(PackedStringArray(step["faults"])) if not (step["faults"] as Array).is_empty()
			else "none"])
