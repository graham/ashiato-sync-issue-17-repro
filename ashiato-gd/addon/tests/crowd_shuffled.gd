extends "res://tests/crowd_sight.gd"
## PROBE: the crowded sky over a link that holds every other packet two ticks late -- delivered swapped, delivered held
## in order, or dropped. Numbers, no verdict.
##
##   Godot --path addon --headless res://tests/crowd_shuffled.tscn
##
## WHY. Over Steam, cockpit's sync packets would travel on an UNRELIABLE RPC: GodotSteam 4.21 sends Godot's
## UNRELIABLE_ORDERED as Steam's Reliable (godotsteam_multiplayer_peer.cpp:721-723), which is head-of-line blocking. An
## unreliable channel may reorder, and no loopback here had ever reordered a packet (LEARNINGS.md, "What remains
## unproven"). ashiato-sync addresses updates by frame -- a late record lands in the entity's ring at its own frame
## (update_runtime.cpp:960-972) and is counted as reordered, not missing (timing_stats.cpp:90-95) -- so it ought to be
## tolerated.
##
## THREE LINKS WITH THE SAME DELAYS, because a delay pattern that reorders is also a delay pattern that bunches, and
## crowd_lumpy already shows a bunched link stepping the sky. Every odd packet in each direction is held two ticks more
## than crowd_sight's 4-tick link, and then:
##   swapped         it lands after the packet made a tick later -- a reorder
##   held_in_order   nothing is delivered before an earlier packet in its direction -- the same lumps, no reorder
##   late_dropped    it is thrown away -- what ENet's unreliable_ordered does with a straggler
## Only the difference between the first two is the reorder's.
##
## Every check still prints PASS or FAIL so the numbers read the same as the suite's, but the probe's own RESULT= is
## PROBE and it exits 0.

## Which link, per sky: 1 swapped, 2 held in order, 3 late ones dropped. Carried in the plan's `bunch` column, which
## this probe's own `_due` does not use.
var _made: Array[int] = [0, 0]
var _last_due: Array[int] = [0, 0]


## AND ONE IN TWENTY, the rate a real link might reorder at rather than every other packet: that straggler delivered
## swapped (4), or dropped the way a guard that refuses anything older than the newest would drop it (5). The pair
## decides whether a guard is better than delivering the straggler late.
func _plans() -> Array:
	return [["a_crowded_sky_over_a_swapped_link", CROWD, 4, 1, 0],
		["a_crowded_sky_over_a_held_in_order_link", CROWD, 4, 2, 0],
		["a_crowded_sky_over_a_late_dropped_link", CROWD, 4, 3, 0],
		["a_crowded_sky_with_one_in_twenty_swapped", CROWD, 4, 4, 0],
		["a_crowded_sky_with_one_in_twenty_dropped", CROWD, 4, 5, 0],
		["a_crowded_sky_with_one_in_twenty_twice", CROWD, 4, 6, 0]]


## crowd_sight's `_advance`, with each direction's packets given their own due tick, and a due tick of -1 dropped.
func _advance(ticks: int) -> void:
	for i in range(ticks):
		_tick += 1
		server.tick(1.0 / HZ)
		client.tick(1.0 / HZ)
		for packet in server.take_outbound():
			var due: int = _due_for(1)
			if due >= 0:
				_in_flight.append([due, 1, packet["bytes"], packet["bits"]])
				# DELIVERED TWICE, a tick apart: Steam's own header says an unreliable message "may be received
				# multiple times".
				if _bunch == 6 and _made[1] % 20 == 7:
					_in_flight.append([due + 1, 1, packet["bytes"], packet["bits"]])
		for packet in client.take_outbound():
			var due: int = _due_for(0)
			if due >= 0:
				_in_flight.append([due, 0, packet["bytes"], packet["bits"]])
				if _bunch == 6 and _made[0] % 20 == 7:
					_in_flight.append([due + 1, 0, packet["bytes"], packet["bits"]])
		var later: Array = []
		var now: Array = []
		for entry in _in_flight:
			if int(entry[0]) > _tick:
				later.append(entry)
			else:
				now.append(entry)
		for entry in now:
			if int(entry[1]) == 1:
				client.deliver(0, entry[2], entry[3])
			else:
				server.deliver(PEER, entry[2], entry[3])
		_in_flight = later


func _due_for(direction: int) -> int:
	_made[direction] += 1
	var late: bool = _made[direction] % 2 == 1
	if _bunch == 4 or _bunch == 5:
		late = _made[direction] % 20 == 7
	elif _bunch == 6:
		late = false
	var due: int = _tick + _link + (2 if late else 0)
	match _bunch:
		2:
			due = maxi(due, _last_due[direction])
		3, 5:
			if late:
				return -1
	_last_due[direction] = maxi(_last_due[direction], due)
	return due


func _fly(crowd: int, link: int, bunch: int, guns: int) -> Dictionary:
	_made = [0, 0]
	_last_due = [0, 0]
	return await super(crowd, link, bunch, guns)


func _finish() -> void:
	print("RESULT=PROBE %d of the suite's checks would fail: %s" % [_failures.size(), ", ".join(_failures)])
	get_tree().quit(0)
