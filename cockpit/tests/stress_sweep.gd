extends "res://tests/crowd.gd"
## HOW MANY CRAFT AT 80 MS. The sweep that answers the user's question, and a probe rather than a suite: there is no
## pass and no fail, because the answer is a number and which number you accept depends on what you will put up with.
##
##     Godot --headless --xr-mode off --path cockpit res://tests/stress_sweep.tscn -- --sphere=on
##     ... -- --sphere=on --peers=8           one column of the grid, for bracketing a measurement hold per block
##     ... -- --sphere=on --craft=200,400     fewer rungs
##
## EIGHTY MILLISECONDS IS ONE WAY. `crowd` takes a round trip, so the cells run at a 167 ms ping: link 10 ticks each
## way at 120 Hz, which is 83.3 ms rather than 80 because a link is a whole number of ticks. Say 83 when quoting it.
## The game's own `--latency=80` is the same link over a real socket (agents.md, "A LEVEL CAN ASK FOR A LINK"), where
## sync measures about 92 ms because a packet cannot be used on the tick it arrives.
##
## WHAT THIS IS AND IS NOT. It is every world in ONE PROCESS behind an exact tick queue: repeatable to the decimal, and
## blind to sockets -- no ENet sequencing, no MTU fragmentation, no OS scheduling, and a link with no jitter. That is
## what makes a grid of fifteen cells comparable with each other. `net_stats` and `bulk_peers` are the real-socket
## checks; this is the shape of the ceiling, not a promise about a particular afternoon.
##
## TWO QUESTIONS, AND THE GRID ANSWERS BOTH. The server's tick is quadratic in clients and linear in craft, and at 600
## craft a first cell read 13.6 ms at only TWO peers -- which says the simulation half may dominate rather than the
## replication half. So the grid is craft against a fixed peer count AND peers against a fixed craft count: whichever
## curve bends is the one that sets the ceiling.
##
## AND THE SPHERE IS PROBABLY INERT HERE, WHICH THE TABLE MUST SAY. The stack flies a 2.8 km ring round the island
## centre and `crowd` seats its players 400 m from that centre, so at the game's own 10 km radius every craft is inside
## every player's sphere and the prioritiser is doing nothing at all. `near` and `far` are printed per cell for exactly
## that reason: a table that showed the feature working while it was inert would be worse than no table.

## WHERE THE TICK GOES, with `--breakdown`: ONE cell, timed job by job, and NOT part of the grid.
##
## `set_tick_breakdown` reads the clock twice per vehicle per tick and costs 7 to 8 per cent of the tick it is
## measuring (agents.md, "What it costs as the sky fills"), so a grid measured with it on would report a ceiling this
## game does not have. The grid runs untimed and this one cell says where the microseconds are, with its own caveat
## attached to every number it prints.
var _breakdown: Dictionary = {}
var _breakdown_on: bool = false


## Turned on for the one diagnostic cell only; `run_bulk_cell` builds the server, so this is where to reach it.
func _stand_everything_up() -> void:
	super()
	if _breakdown_on and _server != null and _server.has_method("set_tick_breakdown"):
		_server.set_tick_breakdown(true)


## `_report` is the last thing that runs while the world is still standing, so the breakdown is taken here.
func _report() -> void:
	if _breakdown_on and _server != null and _server.has_method("tick_breakdown"):
		_breakdown = _server.tick_breakdown()
	super()


## The rungs, unless the command line says otherwise. 600 is `HoldingStack.MOST`.
const CRAFT: PackedInt32Array = [100, 200, 300, 400, 600]
const PEERS: PackedInt32Array = [2, 4, 8]
## Ten ticks each way at 120 Hz: 83.3 ms one way, 166.7 ms round trip. See the header.
const LINK_TICKS: int = 10
const SETTLE_TICKS: int = 600
const MEASURE_TICKS: int = 1200


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("[stress_sweep] extension missing")
		get_tree().quit(1)
		return
	var craft: PackedInt32Array = CRAFT
	var peers: PackedInt32Array = PEERS
	_breakdown_on = OS.get_cmdline_user_args().has("--breakdown")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--craft="):
			craft = PackedInt32Array([])
			for word in arg.trim_prefix("--craft=").split(","):
				craft.append(mini(int(word), HoldingStack.MOST))
		elif arg.begins_with("--peers="):
			peers = PackedInt32Array([])
			for word in arg.trim_prefix("--peers=").split(","):
				peers.append(int(word))
	print("[stress_sweep] link %d ticks each way (%.1f ms one way, %.1f ms round trip) at %.0f Hz; sphere %s" % [
		LINK_TICKS, float(LINK_TICKS) / tick_hz * 1000.0, float(LINK_TICKS) * 2.0 / tick_hz * 1000.0, tick_hz,
		"on" if sphere_on else "off"])
	for peer_count in peers:
		for count in craft:
			var cell: Dictionary = run_bulk_cell(count, peer_count, LINK_TICKS, SETTLE_TICKS, MEASURE_TICKS)
			# THE ONE LINE A PERSON READS. The BULK line above it has everything; this says whether the cell was
			# healthy, in the two terms that decide it: the host kept its tick, and a craft's worst gap still fitted
			# inside the buffer the clock settled on.
			var tick_p99: float = float(cell.get("server_tick_p99_ms", 0.0))
			var budget_ms: float = 1000.0 / tick_hz
			var gap: int = int(cell.get("worst_update_gap_ticks", 0))
			var buffer: int = int(cell.get("buffer_last", 0))
			var near: int = int(cell.get("near_craft", 0))
			var far: int = int(cell.get("far_craft", 0))
			# AND WHETHER THIS ROW PRICES A PRODUCTION TICK. `crowd` traces the server whenever there are two clients
			# or fewer, and a traced tick is about twice a production one -- the two-peer column of this grid was read
			# as a ceiling before this field existed, and it is not one. `timing_valid` is crowd's own answer.
			var traced: bool = not bool(cell.get("timing_valid", true))
			print("SWEEP craft=%d peers=%d traced=%s tick_mean_ms=%.3f tick_p99_ms=%.3f budget_ms=%.3f gap_ticks=%d buffer_frames=%d receipts_s_craft=%.2f near=%d far=%d rollbacks_s=%.2f starved=%d kept_the_tick=%s gap_fits_the_buffer=%s" % [
				count, peer_count, "yes" if traced else "no",
				float(cell.get("server_tick_mean_ms", 0.0)), tick_p99, budget_ms, gap, buffer,
				float(cell.get("receipts_per_s_per_craft", 0.0)), near, far,
				float(cell.get("rollbacks_per_s", 0.0)), int(cell.get("starved", 0)),
				"yes" if tick_p99 <= budget_ms else "NO", "yes" if buffer > 0 and gap <= buffer else "NO"])
	if _breakdown_on and not _breakdown.is_empty():
		# EVERY NUMBER HERE IS 7 TO 8 PER CENT HIGH, because the timers are part of what they time. The SHARES are
		# what this cell is for: which job the tick is made of, not how long the tick is.
		var whole: float = maxf(float(_breakdown.get("server_tick", 0.0)), 1.0)
		var parts: PackedStringArray = []
		for job in ["forces", "step", "ground", "air", "control", "guidance", "mixers", "readback", "rails", "sync",
				"chores", "display", "after", "other"]:
			if _breakdown.has(job):
				parts.append("%s=%.1fus(%.0f%%)" % [job, float(_breakdown[job]),
					float(_breakdown[job]) / whole * 100.0])
		print("SWEEP_BREAKDOWN server_tick=%.1fus ticks=%d %s" % [whole, int(_breakdown.get("ticks", 0)),
			" ".join(parts)])
	print("[stress_sweep] complete; the SWEEP lines above are the table")
	get_tree().quit()
