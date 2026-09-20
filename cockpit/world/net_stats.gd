extends Node
class_name NetStats
## WHAT EACH MACHINE'S LINK IS REALLY DOING, ONCE A SECOND, GATHERED WHERE THE RECORDS LAND.
##
## Asked for on 2026-09-17: *"let's keep track of updates, resyncs, resims, etc and show each player their stats ...
## Once per second, have every client send their stats to the server and the level should have a large monitor that
## shows a table of everyone's network stats ... a latency ms guess for each client, transmitted to the server in the
## 'once per second' network update."*
##
## A machine asks its OWN world four questions, turns the answers into one row, and sends the row to the host. The host
## keeps every row, adds its own, and publishes the table. Nothing here decides anything: the board that draws it is
## handed the table (agents.md, "Announce, don't act").
##
## COUNTED WHERE THE RECORDS LAND. `updates` is `received_frames().count`, which is filled from sync's trace callback as
## records ARRIVE. It is NOT `component_sent`, which sync writes while it serialises a record, BEFORE the budget check
## that may drop it -- that counts what a client was OWED, and at 200 craft it says every craft every tick where
## receipts say 35 to 41 times a second. A table built on it reports a lie confidently, and one already did
## (agents.md, "MEASURE A SEND ON THE CLIENT, NEVER WITH `component_sent`"). That was sync up to 90f50bf; since 8fa08cf
## `component_sent` fires once a record is in a packet, but a packet can be lost, so arrivals are still what counts.
##
## "RESYNCS" DO NOT EXIST AS A COUNTER and this does not invent one. The honest pair is `resim_stats`: how many times
## this machine rewound, and how many ticks it replayed doing it. Both are totals since the session started, so what
## goes in the row is the DIFFERENCE over the second.
##
## THE GAP AND THE BUFFER SIT IN THE SAME ROW, because neither means anything alone: a gap is harmless while it fits
## inside `buffer_frames` and ugly the moment it does not. That is the one comparison a person reading the table should
## be able to make without arithmetic.
##
## THE HOST'S OWN ROW READS NO LATENCY, and that is correct rather than broken: its client is in its own process and
## never goes near a socket (`Net.suit_the_link`). Whatever draws this table says so in words.

## How often a machine speaks, milliseconds. The user asked for once a second.
const EVERY_MSEC: int = 1000
## A row older than this is stale: the machine has missed at least one turn, and a board should say so rather than draw
## last second's numbers as though they were this second's. Two turns plus the round trip of the longest link allowed.
const STALE_MSEC: int = 2600
## THE COLUMNS, IN ORDER, and the wire carries an Array in exactly this order rather than a Dictionary per row: eight
## players of named fields do not fit in a hello. See `read_row`.
const COLUMNS: PackedStringArray = ["client", "craft", "moving", "updates_s_craft_x10", "worst_gap", "median_gap",
	"buffer_frames", "latency_ms", "jitter_x10", "kB_s_in_x10", "rollbacks", "resim_ticks"]
## HOW FAST A CRAFT HAS TO BE GOING before its freshness means anything, metres a second.
##
## A PARKED CRAFT IS NEVER SENT, because nothing about it has changed, so its last record is from whenever it last
## moved and its "gap" is the age of the session rather than a fact about the link (lane/sphere: "Motion is not
## freshness"). Counting those, this read a worst gap of 1,138 frames on a link that was delivering everything it was
## asked to. The rate and the gaps are therefore over the craft that are MOVING, and `craft` beside them is everything
## this machine draws, which is the number the host's `served=` can contradict.
const MOVING_M_S: float = 5.0
## HOW MANY ROWS A BOARD MAY CARRY is `Net.MAX_PLAYERS`, the session's own limit, asked of Net where it is used rather
## than typed here: it was a literal 8 beside Net's 8, and the cap went to 64 (lane/seats, 2026-09-18).

## client id -> {row: Array, at: msec when this machine heard it}. The host's view, and after a board arrives, every
## machine's view.
var rows: Dictionary = {}

## THE HOST'S OWN FIGURE FOR WHAT IT SENT EACH CLIENT, kB a second, measured at its own socket edge: client id -> kB/s.
##
## THIS IS THE ONLY NUMBER IN THE TABLE THAT ANYBODY CAN CONTRADICT, and that is what it is for. Every other column is
## a machine reporting on itself, and a client reporting a number nobody can check is the shape that has gone wrong
## twice in this lane already. A client's `kB_s_in` comes from sync's own counter, in C++, on the client; this comes
## from `Net.sent`, counted in GDScript at the host's socket, on the other machine. They are different code counting
## different sides of the same wire, so they must agree, and a suite can say so.
var host_kB_s: Dictionary = {}

var _sent_before: Dictionary = {}
var _next_msec: int = 0
var _updates_before: int = 0
var _rollbacks_before: int = 0
var _resim_ticks_before: int = 0
var _spoke_at: int = 0


func _ready() -> void:
	_next_msec = Time.get_ticks_msec() + EVERY_MSEC


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_msec:
		return
	var seconds := float(now - _spoke_at) / 1000.0 if _spoke_at > 0 else float(EVERY_MSEC) / 1000.0
	_spoke_at = now
	_next_msec = now + EVERY_MSEC
	if Net.is_host:
		_measure_what_the_host_sent(seconds)
	var mine: Array = take_a_reading(seconds)
	if mine.is_empty():
		return
	# THIS MACHINE'S OWN ROW GOES IN ITS OWN TABLE FIRST, so a solo session and a host with nobody aboard both have a
	# table to draw. A joiner's copy is replaced by the host's board when it arrives.
	rows[int(mine[0])] = {"row": mine, "at": now}
	if Net.is_networked() and not Net.is_host:
		Net.say_my_stats(mine)
	elif Net.is_host:
		Net.publish_the_stats_board(board())


## WHAT THIS HOST PUT ON THE WIRE FOR EACH CLIENT over the last second, from the carrier's own byte counter. Kept by
## client id rather than peer id so it sits beside the rows without anybody having to map one to the other twice.
func _measure_what_the_host_sent(seconds: float) -> void:
	host_kB_s.clear()
	for peer in Net.sent:
		var client: int = Sim.client_of_peer(int(peer))
		if client == 0:
			continue
		var bytes: int = int((Net.sent[peer] as Array)[1])
		var before: int = int(_sent_before.get(peer, bytes))
		host_kB_s[client] = float(bytes - before) / maxf(seconds, 0.001) / 1000.0
		_sent_before[peer] = bytes


## THIS MACHINE'S ROW, over `seconds` of its own clock. Empty when there is no client world to ask, which is every
## machine that is not in a session yet.
func take_a_reading(seconds: float) -> Array:
	if Sim.client == null or not Sim.is_ready:
		return []
	var receipts: Dictionary = Sim.client.received_frames()
	var frames: Dictionary = receipts.get("frames", {})
	var newest: int = int(receipts.get("newest", 0))
	var updates: int = int(receipts.get("count", 0))
	# ONLY THE CRAFT THIS MACHINE IS STILL DRAWING, and that is not a detail. `received_frames` keeps the newest frame
	# of everything it has EVER had a record for, and a craft that was retired an hour ago keeps its last frame for
	# ever -- so its gap grows by 120 every second and the worst gap becomes a measure of how long ago something died.
	# The first run of this said `worst_gap=1152` and `craft=366` against a world serving 183: both numbers were the
	# dead ones. Counting against what the client currently draws is what `crowd.gd` does, for the same reason.
	var drawn: Dictionary = {}
	var moving: Dictionary = {}
	for state in Sim.client.vehicle_states():
		var entity: int = int((state as Dictionary)["entity"])
		drawn[entity] = true
		if ((state as Dictionary)["velocity"] as Vector3).length() >= MOVING_M_S:
			moving[entity] = true
	var craft: int = drawn.size()
	# HOW STALE EACH CRAFT IS, in server frames, against the newest frame this machine has of anything. The worst and
	# the middle, because one late craft in two hundred is a different thing from all of them being late.
	var gaps: Array[int] = []
	for entity in frames:
		if not moving.has(int(entity)):
			continue
		gaps.append(maxi(newest - int(frames[entity]), 0))
	gaps.sort()
	var worst: int = gaps[gaps.size() - 1] if not gaps.is_empty() else 0
	var middle: int = gaps[gaps.size() / 2] if not gaps.is_empty() else 0
	var resim: Dictionary = Sim.client.resim_stats()
	var timing: Dictionary = Sim.client.timing()
	var status: Dictionary = Sim.client.net_status()
	var rollbacks: int = int(resim.get("count", 0))
	var resim_ticks: int = int(resim.get("ticks", 0))
	var per_craft: float = (float(updates - _updates_before) / maxf(seconds, 0.001)) / float(maxi(moving.size(), 1))
	# THE MACHINE'S OWN GUESS AT ITS LINK, in milliseconds, which is sync's estimate from server frame numbers and not
	# a ping this game sends. At 120 Hz a frame is 8.33 ms, and a packet cannot be used on the tick it arrives, so a
	# machine holding 80 ms of delay reads about 92 (agents.md, "A LEVEL CAN ASK FOR A LINK").
	var latency_ms: int = int(round(float(timing.get("latency_frames", 0)) / maxf(Sim.tick_hz, 1.0) * 1000.0))
	var row: Array = [
		Sim.local_client_id(),
		craft,
		moving.size(),
		int(round(per_craft * 10.0)),
		worst,
		middle,
		int(timing.get("buffer_frames", 0)),
		latency_ms,
		int(round(float(timing.get("jitter_frames", 0.0)) * 10.0)),
		int(round(float(status.get("bytes_in_per_second", 0.0)) / 1000.0 * 10.0)),
		maxi(rollbacks - _rollbacks_before, 0),
		maxi(resim_ticks - _resim_ticks_before, 0),
	]
	_updates_before = updates
	_rollbacks_before = rollbacks
	_resim_ticks_before = resim_ticks
	return row


## SOMEBODY'S ROW ARRIVED. The host's; a client's board arriving calls `take_the_board`.
func hear_a_row(row: Array) -> void:
	if not is_a_row(row):
		return
	rows[int(row[0])] = {"row": row, "at": Time.get_ticks_msec()}


## THE HOST'S TABLE, oldest column order, at most `Net.MAX_PLAYERS` rows and this machine's own first.
func board() -> Array:
	var out: Array = []
	var mine: int = Sim.local_client_id()
	if rows.has(mine):
		out.append((rows[mine] as Dictionary)["row"])
	var others: Array = rows.keys()
	others.sort()
	for client in others:
		if int(client) == mine:
			continue
		out.append((rows[client] as Dictionary)["row"])
		if out.size() >= Net.MAX_PLAYERS:
			break
	return out


## A BOARD FROM THE HOST. It replaces what this machine knew about everybody else, and its own row with it: the host's
## copy is the one every machine in the session is looking at, so two players never read different tables.
##
## IN PAGES since the session went to sixty-four (lane/seats): page 0 replaces the board, and every page after it adds
## its rows. A page 0 that was lost leaves the last second's rows standing until the next one, each saying its age.
func take_the_board(table: Array, page: int = 0) -> void:
	var now := Time.get_ticks_msec()
	var fresh: Dictionary = {} if page == 0 else rows
	for row in table:
		if not is_a_row(row):
			continue
		fresh[int((row as Array)[0])] = {"row": row, "at": now}
	rows = fresh


## EVERY ROW A BOARD SHOULD DRAW, each with how old it is in milliseconds and whether that is too old to believe.
## A DISPLAY IS HANDED THIS. It decides nothing.
func table() -> Array:
	var now := Time.get_ticks_msec()
	var out: Array = []
	for client in rows:
		var kept: Dictionary = rows[client]
		var age: int = now - int(kept["at"])
		var named: Dictionary = {"age_msec": age, "stale": age > STALE_MSEC}
		var row: Array = kept["row"]
		for i in range(COLUMNS.size()):
			named[COLUMNS[i]] = int(row[i])
		out.append(named)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["client"]) < int(b["client"]))
	return out


## IS THIS A ROW? Every number, whole, and the right number of them. Untrusted input proposes and the host disposes
## (CLAUDE.md, rule 8): a client's card arrives over the same carrier as everything else and is checked like everything
## else, because a row that is not a row would otherwise reach a board as `null` columns.
static func is_a_row(row: Variant) -> bool:
	if not row is Array or (row as Array).size() != COLUMNS.size():
		return false
	for value in row as Array:
		if not (value is float or value is int) or float(value) != floorf(float(value)):
			return false
		if absf(float(value)) > 1e9:
			return false
	return true
