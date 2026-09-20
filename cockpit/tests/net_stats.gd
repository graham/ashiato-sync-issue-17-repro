extends Node
## Headless: EVERY MACHINE'S LINK, ONCE A SECOND, AND ONE COLUMN THE OTHER END CAN CONTRADICT.
##
##     Godot --headless --xr-mode off --path cockpit res://tests/net_stats.tscn
##
## A stats table is the exact shape this lane has already been caught by twice: a machine reporting a number nobody
## can check. So the suite's weight is on the ONE column that is not self-reported -- a client says how many bytes a
## second it is receiving, from sync's counter in C++, and the host says how many it sent that client, from `Net.sent`
## counted in GDScript at its own socket. Two pieces of code, two languages, two machines, two sides of one wire. If
## they disagree the table is wrong, and nothing else in it is worth reading.
##
## The rest of the row is self-reported and this suite says so rather than pretending otherwise: what it can check is
## that the numbers are present, whole, fresh, and that the latency each machine guesses for itself is the link the
## level asked for.
##
## WALL CLOCK, AND NO `--fixed-fps` ON THE CHILDREN, for the same reason as `link_ms`: a card sent once a second by a
## process running as fast as it can is not once a second.

## THROUGH THE AUTHORITY, so two checkouts gating at once do not bind the same socket: `crew_peers`' 47990-47999
## range covers this one. See TestPorts.
## A `static var` and not a `const`: a const's initialiser must be a compile-time constant and a call is not one.
## See `link_ms`.
## 47996 of this checkout's block (`TestPorts`), asked silently at load whether anything holds it: a fixed
## number was the same socket in every lane. Held, and the suite says PORT BUSY at once rather than timing out.
static var PORT: int = TestPorts.first_free(47996, 1)
const PATIENCE_MS := 60000
const SETTLE_MS := 6000
const WINDOW_MS := 6000
## How far apart the two ends' byte counts may be. They count different things at the edges -- the host counts what it
## handed the carrier, the client counts what sync decoded -- so they are close rather than equal.
const AGREE_WITHIN := 0.20
## The stress level asks for 80 ms; a packet cannot be used on the tick it arrives, so sync reads about 92 (agents.md,
## "A LEVEL CAN ASK FOR A LINK"). The band is wide because this is a machine's own guess, reported once a second.
const LINK_MS_LOW := 60
const LINK_MS_HIGH := 130
## The host's client is in the host's process and is on no socket at all.
const HOST_MS_MOST := 25

var _children: Array[int] = []
var _failed := false
var _said: Array[String] = []


func _ready() -> void:
	if PORT == 0:
		print("RESULT=FAIL port_busy %s" % TestPorts.busy(47996, 1))
		get_tree().quit(1)
		return
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL extension_missing")
		get_tree().quit(1)
		return
	_a_row_is_checked_before_it_is_believed()
	_a_full_board_fits_in_a_hello()
	await _two_machines_report_themselves()
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


## ---- 1. untrusted input proposes ---------------------------------------------------------------

func _a_row_is_checked_before_it_is_believed() -> void:
	var good: Array = [2, 201, 62, 412, 3, 3, 9, 92, 0, 2466, 0, 0]
	_check("a_whole_row_is_a_row", NetStats.is_a_row(good), "%s" % [good])
	var short: Array = good.slice(0, 5)
	_check("a_short_row_is_refused", not NetStats.is_a_row(short), "%d columns" % short.size())
	var long_row: Array = good.duplicate()
	long_row.append(1)
	_check("a_long_row_is_refused", not NetStats.is_a_row(long_row), "%d columns" % long_row.size())
	var fractional: Array = good.duplicate()
	fractional[3] = 41.2
	_check("a_row_with_a_fraction_in_it_is_refused", not NetStats.is_a_row(fractional), "41.2 in column 3")
	var enormous: Array = good.duplicate()
	enormous[9] = 1e12
	_check("a_row_with_an_absurd_number_in_it_is_refused", not NetStats.is_a_row(enormous), "1e12 in column 9")
	_check("a_row_that_is_not_an_array_is_refused", not NetStats.is_a_row({"client": 2}), "a Dictionary")
	# AND A BOARD, through the same reader a peer's bytes go through.
	var board: Dictionary = {"say": "netboard", "rows": [good, good]}
	_check("a_board_of_rows_is_read", not Net.read_hello(JSON.stringify(board).to_utf8_buffer()).is_empty(),
		"two rows")
	var too_many: Array = []
	for i in range(Net.MAX_PLAYERS + 1):
		too_many.append(good)
	_check("a_board_of_more_rows_than_the_session_holds_is_refused",
		Net.read_hello(JSON.stringify({"say": "netboard", "rows": too_many}).to_utf8_buffer()).is_empty(),
		"%d rows" % too_many.size())
	_check("a_board_carrying_a_row_that_is_not_a_row_is_refused",
		Net.read_hello(JSON.stringify({"say": "netboard", "rows": [good, short]}).to_utf8_buffer()).is_empty(),
		"one short row among good ones")
	_check("a_card_that_is_not_a_row_is_refused",
		Net.read_hello(JSON.stringify({"say": "netstats", "row": short}).to_utf8_buffer()).is_empty(),
		"a short card")


## ---- 2. and it has to fit ----------------------------------------------------------------------

## A FULL SESSION'S BOARD, IN HELLOS. The rows are Arrays rather than Dictionaries because eight players of named fields
## did not fit one hello; sixty-four players of Arrays do not either, so the host sends the board in pages
## (`Net.board_pages`, lane/seats 2026-09-18). This builds the widest plausible row -- every column at a number that
## takes the most room -- a full session's worth, and holds that every page fits, is read back by the same reader a
## peer's bytes go through, and that the pages together carry every row exactly once.
func _a_full_board_fits_in_a_hello() -> void:
	var widest: Array = [8, 999, 999, 12000, 999, 999, 63, 999, 999, 99999, 999, 9999]
	_check("the_widest_row_is_still_a_row", NetStats.is_a_row(widest), "%s" % [widest])
	var rows: Array = []
	for i in range(Net.MAX_PLAYERS):
		var row: Array = widest.duplicate()
		row[0] = 100 + i
		rows.append(row)
	var pages: Array = Net.board_pages(rows)
	var biggest: int = 0
	var read_back: int = 0
	var clients: Dictionary = {}
	for page in pages:
		var bytes: PackedByteArray = JSON.stringify(page).to_utf8_buffer()
		biggest = maxi(biggest, bytes.size())
		var heard: Dictionary = Net.read_hello(bytes)
		read_back += 0 if heard.is_empty() else 1
		for row in heard.get("rows", []):
			clients[int(row[0])] = int(clients.get(int(row[0]), 0)) + 1
	var once: bool = clients.size() == Net.MAX_PLAYERS and clients.values().all(func(n: int) -> bool: return n == 1)
	_check("a_full_board_fits_in_one_hello", pages.size() >= 1 and biggest <= Net.HELLO_MOST_BYTES
		and read_back == pages.size() and once,
		"%d rows in %d pages, the biggest %d bytes of %d; %d read back; %d clients, each once %s" % [rows.size(),
			pages.size(), biggest, Net.HELLO_MOST_BYTES, read_back, clients.size(), once])


## ---- 3. two machines, over a real socket -------------------------------------------------------

func _two_machines_report_themselves() -> void:
	var project := ProjectSettings.globalize_path("res://")
	# AND THE LOGS ARE NAMED FOR THE CHECKOUT: see the note in `link_ms`. Every lane's cockpit shares one `user://`.
	var logs := {
		"host": ProjectSettings.globalize_path(TestPorts.log_for("net_stats", "host")),
		"joiner": ProjectSettings.globalize_path(TestPorts.log_for("net_stats", "joiner")),
	}
	for path in logs.values():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var common := ["--headless", "--xr-mode", "off", "--desktop-only", "--path", project]
	# A STACK OF AEROPLANES, so there is something for the wire to carry: an empty world's numbers are all zero and a
	# table of zeroes agrees with every bug there is.
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.host, "--",
		"--host=%d" % PORT, "--world=stress", "--report=1", "--stack=100"]))
	await _wall_msec(500)
	_children.append(OS.create_process(OS.get_executable_path(), common + ["--log-file", logs.joiner, "--",
		"--join=127.0.0.1:%d" % PORT, "--report=1"]))
	var began := Time.get_ticks_msec()
	var arrived := false
	while Time.get_ticks_msec() - began < PATIENCE_MS:
		var host: Dictionary = _latest_report(logs.host)
		if int(host.get("clients", 0)) == 2 and int(host.get("stack", 0)) >= 100:
			arrived = true
			break
		OS.delay_msec(10)
		await get_tree().process_frame
	_check("the_joiner_arrives_on_a_level_with_traffic_on_it", arrived, "host=%s" % [_latest_report(logs.host)])
	if not arrived:
		_kill_children()
		return
	await _wall_msec(SETTLE_MS)
	var first_host := _stats_rows(logs.host).size()
	var first_joiner := _stats_rows(logs.joiner).size()
	await _wall_msec(WINDOW_MS)
	var host_rows: Array[Dictionary] = _stats_rows(logs.host).slice(first_host)
	var joiner_rows: Array[Dictionary] = _stats_rows(logs.joiner).slice(first_joiner)
	_kill_children()
	_check("the_host_keeps_a_table_of_everybody", _clients_in(host_rows).size() == 2,
		"clients %s over %d rows" % [_clients_in(host_rows), host_rows.size()])
	_check("and_every_machine_is_shown_the_same_table", _clients_in(joiner_rows).size() == 2,
		"clients %s over %d rows" % [_clients_in(joiner_rows), joiner_rows.size()])
	if _failed:
		return
	# WHICH ROW IS WHOSE. The host's own row is the one with no simulated link; the joiner's is the other.
	var host_client := -1
	var joiner_client := -1
	for row in host_rows:
		if int(row["host_kB_s_x10"]) <= 0:
			host_client = int(row["client"])
		else:
			joiner_client = int(row["client"])
	_check("the_two_rows_are_told_apart", host_client >= 0 and joiner_client >= 0 and host_client != joiner_client,
		"host client %d, joiner client %d" % [host_client, joiner_client])
	if host_client < 0 or joiner_client < 0:
		return
	# THE CROSS-CHECK. Everything else in the table is a machine reporting on itself.
	var said: float = _median_of(host_rows, joiner_client, "kB_s_in_x10") / 10.0
	var sent: float = _median_of(host_rows, joiner_client, "host_kB_s_x10") / 10.0
	var apart: float = absf(said - sent) / maxf(sent, 0.001)
	print("NET_STATS_CHECK joiner_says_in=%.1f kB/s host_says_out=%.1f kB/s apart=%.1f%% latency_ms=%d host_latency_ms=%d" % [
		said, sent, apart * 100.0, int(_median_of(host_rows, joiner_client, "latency_ms")),
		int(_median_of(host_rows, host_client, "latency_ms"))])
	_check("what_the_client_says_it_received_is_what_the_host_says_it_sent", apart <= AGREE_WITHIN,
		"client %.1f kB/s, host %.1f kB/s, %.1f%% apart" % [said, sent, apart * 100.0])
	# AND THE LINK EACH MACHINE GUESSES FOR ITSELF IS THE ONE THE LEVEL ASKED FOR.
	var guess: int = int(_median_of(host_rows, joiner_client, "latency_ms"))
	_check("the_joiners_own_latency_guess_is_the_levels_link", guess >= LINK_MS_LOW and guess <= LINK_MS_HIGH,
		"%d ms, wanted %d to %d" % [guess, LINK_MS_LOW, LINK_MS_HIGH])
	var host_guess: int = int(_median_of(host_rows, host_client, "latency_ms"))
	_check("the_hosts_own_row_shows_no_link_at_all", host_guess <= HOST_MS_MOST,
		"%d ms -- the host's client is in the host's process" % host_guess)
	# NOTHING IS STALE while both machines are speaking, and the craft really are arriving.
	var stale := 0
	var silent := 0
	for row in host_rows:
		if int(row["stale"]) != 0:
			stale += 1
		if int(row["client"]) == joiner_client and int(row["updates_s_craft_x10"]) <= 0:
			silent += 1
	_check("no_row_is_stale_while_both_machines_are_speaking", stale == 0,
		"%d stale of %d rows" % [stale, host_rows.size()])
	_check("the_joiner_is_receiving_craft_records", silent == 0,
		"%d of the joiner's rows counted no arrivals" % silent)
	# HOW MANY CRAFT THE CLIENT SAYS IT IS COUNTING, against how many the HOST SAYS IT SERVES. A second cross-check on
	# the other end of the wire, and it is here because the first run of this suite passed while the number was wrong:
	# `received_frames` remembers every entity it has ever had a record for, so a retired craft kept its last frame and
	# the row read 366 craft against a world serving 183, with a worst gap of 1152 frames that was really a measure of
	# how long ago something died.
	var served: int = int(_latest_report(logs.host).get("served", 0))
	var counted: int = int(_median_of(host_rows, joiner_client, "craft"))
	_check("the_client_counts_the_craft_the_host_actually_serves",
		served > 0 and absf(float(counted - served)) <= float(served) * 0.1,
		"client counted %d, host served %d" % [counted, served])
	# AND A GAP IS A GAP AND NOT A HEADSTONE. A craft that is being drawn AND IS MOVING cannot be a second stale
	# without the session being unplayable. The first two runs of this suite read 1,152 and 1,138 frames: the first
	# was retired craft, whose last record is however long ago they died, and the second was PARKED craft, which are
	# never sent because nothing about them changes (lane/sphere, "Motion is not freshness").
	var worst: int = int(_median_of(host_rows, joiner_client, "worst_gap"))
	var moving: int = int(_median_of(host_rows, joiner_client, "moving"))
	_check("the_worst_gap_is_a_moving_craft_and_not_a_parked_one", worst <= int(Sim.tick_hz),
		"worst gap %d frames over %d moving craft, a second is %d" % [worst, moving, int(Sim.tick_hz)])
	_check("some_of_the_craft_are_actually_moving", moving > 0 and moving <= counted,
		"%d moving of %d drawn" % [moving, counted])
	# AND THE ONE COMPARISON A READER SHOULD NOT HAVE TO DO ARITHMETIC FOR is in the same row.
	var gap: int = int(_median_of(host_rows, joiner_client, "worst_gap"))
	var buffer: int = int(_median_of(host_rows, joiner_client, "buffer_frames"))
	print("NET_STATS_HEALTH joiner worst_gap=%d buffer_frames=%d updates_s_craft=%.1f craft=%d moving=%d served=%d" % [
		gap, buffer, _median_of(host_rows, joiner_client, "updates_s_craft_x10") / 10.0,
		int(_median_of(host_rows, joiner_client, "craft")), int(_median_of(host_rows, joiner_client, "moving")),
		served])
	_check("the_gap_and_the_buffer_are_both_reported", gap >= 0 and buffer > 0,
		"gap %d, buffer %d" % [gap, buffer])


func _clients_in(rows: Array[Dictionary]) -> Array:
	var seen: Dictionary = {}
	for row in rows:
		seen[int(row["client"])] = true
	var out: Array = seen.keys()
	out.sort()
	return out


func _median_of(rows: Array[Dictionary], client: int, column: String) -> float:
	var values: Array[float] = []
	for row in rows:
		if int(row["client"]) == client:
			values.append(float(row[column]))
	if values.is_empty():
		return 0.0
	values.sort()
	return values[values.size() / 2]


func _stats_rows(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.begins_with("NETSTATS "):
			continue
		var row: Dictionary = {}
		for pair in line.substr(9).strip_edges().split(" ", false):
			var kv := pair.split("=")
			if kv.size() == 2:
				row[kv[0]] = int(kv[1])
		out.append(row)
	return out


func _latest_report(path: String) -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.begins_with("SESSION_REPORT "):
			continue
		out.clear()
		for pair in line.substr(15).strip_edges().split(" ", false):
			var kv := pair.split("=")
			if kv.size() == 2:
				out[kv[0]] = kv[1]
	return out


func _wall_msec(msec: int) -> void:
	var until := Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < until:
		OS.delay_msec(10)
		await get_tree().process_frame


func _check(name: String, passed: bool, detail: String) -> void:
	print("[net_stats] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true
		_said.append(name)


func _kill_children() -> void:
	for pid in _children:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_children.clear()


func _exit_tree() -> void:
	_kill_children()
