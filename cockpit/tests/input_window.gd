extends Node
## Headless: A CLIENT FLYING OVER AN ORDINARY INTERNET LINK GETS ITS OWN INPUT TO THE SERVER IN TIME.
##
##   Godot --headless --xr-mode off --fixed-fps 120 --path cockpit res://tests/input_window.tscn
##
## THE BUG. Every tick ashiato-sync's client sends one input packet holding every input frame the server has not
## acknowledged, and that window is the whole round trip: a frame stays in it until an acknowledgement a round trip old
## says it arrived. The packet was written OLDEST first and cut at the MTU (1200 bytes) or the input count (31), and a
## ControlInput was 327 bits on every full frame, so it held 29. Past a round trip of 29 frames the newest input never left
## the client: the server stepped every frame on input it had already used, and the client's prediction was corrected
## on every one. Frames behind = round-trip lead - 29, from a one-way link of 15 ticks (125 ms at 120 Hz).
## `ashiato-gd/tools/patches/ashiato-sync-send-newest-inputs-first.patch` sent the newest eight instead. Protocol 9
## delta-encodes them against an acknowledged baseline; see the codec checks below. SINCE ASHIATO-SYNC 8fa08cf
## (2026-09-18) upstream sends the newest frames itself, up to the protocol's 31, trimming the OLDEST when the MTU cuts,
## and our 8-frame cap is gone: the user accepted the upload that costs (below) because it changed neither starvation
## nor rollbacks in any condition measured here.
##
## WHAT IS REAL HERE. A server and a client CockpitWorld, a pilot in a plane with a stick that moves, and the library's
## own sync trace (`input_starved`, detail `input_frame=N`) read on the server. The only thing modelled is the WIRE, and
## the pump is EXACT: a packet sent after tick T is delivered before the receiver's tick T + link. The older suites'
## pump (`gun_link`, `big_guns`, `shell_prediction`) delivers after both worlds tick, so their "link" is one tick
## longer each way than it says.
##
## WHAT IT HOLDS, each checked, not printed:
##   * links of 16, 24, 30, 36 and 42 ticks each way (up to 350 ms one way): no server frame starved,
##     and rollbacks within twice link 0's;
##   * what a steady-flight packet costs stops growing once the window is full: none at 16 to 42 is bigger than
##     eight FULL frames were (the old codec's packet), and none is cut by the MTU;
##   * with head and both hands moving every frame, a full 31-frame window of deltas still fits one packet uncut;
##   * over a bad ENet link at 16 ticks -- 1% loss each way, a 5-tick outage every 2 s, 0 to 4 ticks of jitter per
##     packet, one tick's packets in ten reversed, and a packet that arrives after a later one DISCARDED, which is what
##     ENet's unreliable sequenced channel does to Net's `unreliable_ordered` RPC -- starved frames stay under a tenth
##     and rollbacks within twice link 0's.
##
## RED on main at cfe1b183 (ashiato_gd.double.dll d5535381), GREEN with the patch; per 600 measured ticks after 600
## settling ones, largest input packet in bytes:
##
##   link                        RED: starved  rollbacks  largest        GREEN: starved  rollbacks  largest
##   0                                  0         11        89                   0          11        89
##   4                                  0         10       333                   0          10       333
##   16                               600         60      1193                   0          11       337
##   24                               600        380      1193                   0          10       337
##   16, bad ENet link                600         73      1196                  24          14       340
##
## 8fa08cf against the 8-frame cap, same harness, up bytes a tick (largest): link 0 and 4 unchanged, 16 to 42 72.2 (73)
## -> 134.0 (134), tracked poses at 16 265.4 (267) -> 962.6 (966), bad link 72.0 (75) -> 133.3 (137). Starved and
## rollbacks identical in every row: 0 and 7, the bad link 24 and 10.
##
## A DrivingWorld and a VrWorld client at 60 Hz hit the other cap, the input count of 31, past a lead of 31 frames: 93
## and 1,057 bytes a tick at links of 16 and 24 before, 32 and 281 after, a full first frame being 4 bytes of it.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 120.0
const TICK_HZ: float = 120.0
const PEER: int = 2
const SETTLE: int = 600
const MEASURE: int = 600
## The plane, and how the pilot flies it: some throttle and a stick rocked side to side every quarter second, so the
## input actually changes and a stale frame actually mispredicts.
const PLANE: int = 1
const THROTTLE: float = 0.6
const ROLL: float = 0.4
const ROCK_TICKS: int = 30
## Room over a packet of exactly the cap: a first frame sent full carries its 32-bit number, and an input packet also
## carries whatever acknowledgements are due. 340 bytes was seen over the bad link against 337 clean.
const PACKET_SLACK_BYTES: int = 16
## The bad link, as described at the top.
const LOSS: float = 0.01
const OUTAGE_EVERY: int = 240
const OUTAGE_TICKS: int = 5
const JITTER_TICKS: int = 4
const SWAP_CHANCE: float = 0.1
const SEED: int = 1
## The old full-frame codec, measured by this harness at links 16/24 before input deltas.
const FULL_INPUT_PACKET_BYTES: int = 338
## sync's default MTU, which the cockpit does not change.
const MTU_BYTES: int = 1200

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _client: RefCounted = null
var _tick: int = 0
var _bad_link: bool = false
var _rng := RandomNumberGenerator.new()
## [[due_tick, to_the_server, bytes, bits, sequence], ...] in the order they arrive.
var _in_flight: Array = []
var _lost: int = 0
var _discarded: int = 0
## Per direction, index 0 up (client to server) and 1 down: next sequence number, last one delivered.
var _sent: Array = [0, 0]
var _delivered: Array = [-1, -1]
var _up_bytes: int = 0
var _largest_up: int = 0
var _tracked_poses: bool = false
var _drop_next_up: bool = false
var _input_buttons: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[input_window] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("cockpit_world_is_registered", false, "the ashiato extension did not load")
		_finish()
		return
	var codec_world: RefCounted = ClassDB.instantiate("CockpitWorld")
	var codec: Dictionary = codec_world.input_wire_probe(20000)
	# THE COMMAND'S SHARE IS READ FROM THE BUS'S OWN WIDTHS, not typed here (busbits, 2026-09-18): a form bit, a short or
	# a wide channel, a value and a sequence. AND THE JOIN SEAT'S FROM THE SEAT'S (lane/seats, 2026-09-18): "any seat" is
	# one bit where it was three, and a seat past the fourth is a presence bit, a form bit and sixteen. Everything else
	# in a frame is 309 bits full and 380 at worst. History of the full frame: 327 with a two-bit sequence, 333 with eight
	# (2026-09-17), 342 with sixteen and the form bit, 340 with the one-bit "any seat".
	var bus: Dictionary = ClassDB.class_call_static(&"CockpitWorld", &"bus_limits")
	var seat: Dictionary = ClassDB.class_call_static(&"CockpitWorld", &"seat_limits")
	var short_command: int = 1 + int(bus["short_channel_bits"]) + int(bus["value_bits"]) + int(bus["seq_bits"])
	var wide_command: int = 1 + int(bus["channel_bits"]) + int(bus["value_bits"]) + int(bus["seq_bits"])
	var any_seat: int = 1
	var wide_seat: int = 1 + 1 + int(seat["seat_bits"])
	_check("the_full_control_input_size_is_measured", int(codec.get("full_bits", 0)) == 309 + any_seat + short_command,
		"%d bits, %d of them the command and %d the seat" % [int(codec.get("full_bits", 0)), short_command, any_seat])
	_check("an_unchanged_input_is_only_the_delta_mask", int(codec.get("unchanged_delta_bits", 0)) == 21,
		"%d bits" % int(codec.get("unchanged_delta_bits", 0)))
	# The worst case carries a WIDE channel (300). 404 with the eight-bit sequence; two bits of slack over it, as before.
	# AND A WIDE KIND (300), since lane/kinds: the 383 counts the kind's five-bit short form, and a kind from `short_kinds`
	# up adds `id_bits` to it, read from the library as the command's share is. 424 before, 440 with it.
	# AND A WIDE SEAT (300), since lane/seats: the 380 leaves the seat out, and a seat past the fourth is a presence bit,
	# a form bit and sixteen. 456 with it.
	var kinds: Dictionary = ClassDB.class_call_static(&"CockpitWorld", &"kind_limits")
	var wide_kind: int = int(kinds["id_bits"])
	_check("the_worst_case_delta_size_is_bounded",
		int(codec.get("all_changed_delta_bits", 0)) <= 380 + wide_seat + wide_kind + wide_command + 2,
		"%d bits, %d of them the command, %d the kind's wide form and %d the seat" % [
			int(codec.get("all_changed_delta_bits", 0)), wide_command, wide_kind, wide_seat])
	_check("eight_worst_case_frames_encode_inside_one_percent_of_a_tick",
		float(codec.get("eight_frame_encode_us", 1e9)) < (1e6 / TICK_HZ) * 0.01,
		"%.2f us per eight-frame packet" % float(codec.get("eight_frame_encode_us", -1.0)))
	var still: Dictionary = _fly(0, false)
	var sized: Dictionary = _fly(4, false)
	var frames_per_packet: int = int(still.get("frames_per_packet", -1))
	_check("the_library_says_how_many_frames_an_input_packet_holds", frames_per_packet > 0,
		"input_frames_max %d" % frames_per_packet)
	if frames_per_packet <= 0:
		frames_per_packet = 8
	# The full-frame measurement is retained above as a mutation threshold. Deltas make a
	# per-frame extrapolation invalid: the first frame is relative to the acknowledged
	# baseline and every later one is relative to its predecessor. A 31-frame steady window
	# is 134 bytes, well inside eight full frames (354), which is what these hold it to.
	var full_packet: int = FULL_INPUT_PACKET_BYTES + PACKET_SLACK_BYTES
	for run in [still, sized]:
		_check("link_%d_counts_no_cut_input_packet" % run["link"], int(run["truncated"]) == 0,
			"%d packets cut" % run["truncated"])

	for link in [16, 24, 30, 36, 42]:
		var run: Dictionary = _fly(link, false)
		_check("link_%d_starves_no_server_frame" % link, int(run["starved"]) == 0,
			"%d of %d starved, %d frames behind in all, lead %d" % [run["starved"], MEASURE, run["behind"], run["lead"]])
		_check("link_%d_rolls_back_about_as_often_as_link_0" % link,
			int(run["rollbacks"]) <= 2 * int(still["rollbacks"]),
			"%d rollbacks against %d at link 0" % [run["rollbacks"], still["rollbacks"]])
		_check("link_%d_steady_packets_stay_under_eight_full_frames" % link, int(run["largest"]) <= full_packet,
			"largest %d bytes, %.1f a tick, against %d for eight full frames; the window is up to %d" % [run["largest"],
				run["per_tick"], full_packet, frames_per_packet])
		_check("link_%d_counts_no_cut_input_packet" % link, int(run["truncated"]) == 0,
			"%d packets cut" % run["truncated"])
		if link == 24:
			_check("input_deltas_cut_the_steady_flight_packet_in_half",
				int(run["largest"]) < FULL_INPUT_PACKET_BYTES / 2,
				"%d bytes against %d before deltas" % [run["largest"], FULL_INPUT_PACKET_BYTES])

	var tracked: Dictionary = _fly(16, false, true)
	# 31 full frames would be 1,318 bytes and cut by the 1,200-byte MTU, so a broken delta codec fails here. 966 measured.
	_check("a_full_window_of_moving_tracked_poses_fits_one_packet_uncut",
		int(tracked["largest"]) <= MTU_BYTES and int(tracked["truncated"]) == 0 and int(tracked["starved"]) == 0,
		"largest %d bytes, %.1f a tick, %d cut, %d starved, against a %d-byte MTU" % [tracked["largest"],
			tracked["per_tick"], tracked["truncated"], tracked["starved"], MTU_BYTES])
	var one_lost: Dictionary = _fly(16, false, false, true)
	_check("a_packet_lost_before_it_can_become_a_baseline_recovers_on_the_next_packet",
		int(one_lost["lost"]) == 1 and int(one_lost["starved"]) <= 1
			and int(one_lost["behind"]) <= 1 and int(one_lost["starved_after_first"]) == 0
			and int(one_lost["buttons_seen"]) == 0xA5,
		"%d deliberately lost, %d server frames starved, %d later starved, buttons 0x%02X, %d rollbacks" % [
			one_lost["lost"], one_lost["starved"], one_lost["starved_after_first"],
			one_lost["buttons_seen"], one_lost["rollbacks"]])

	var bad: Dictionary = _fly(16, true)
	_check("a_bad_enet_link_at_16_starves_under_a_tenth_of_frames", int(bad["starved"]) <= MEASURE / 10,
		"%d of %d starved, %d behind in all, %d lost, %d discarded as late" % [bad["starved"], MEASURE, bad["behind"],
			bad["lost"], bad["discarded"]])
	_check("and_rolls_back_about_as_often_as_link_0", int(bad["rollbacks"]) <= 2 * int(still["rollbacks"]),
		"%d rollbacks against %d at link 0" % [bad["rollbacks"], still["rollbacks"]])
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## One flight over one link. Returns what was measured over the last MEASURE ticks.
func _fly(link: int, bad_link: bool, tracked_poses: bool = false, drop_one_up: bool = false) -> Dictionary:
	_server = ClassDB.instantiate("CockpitWorld")
	_client = ClassDB.instantiate("CockpitWorld")
	_tick = 0
	_in_flight.clear()
	_sent = [0, 0]
	_delivered = [-1, -1]
	_rng.seed = SEED
	_bad_link = false
	_tracked_poses = tracked_poses
	_drop_next_up = false
	_input_buttons = 0
	_server.set_tracing(true)
	for world in [_server, _client]:
		world.set_tick_rate(TICK_HZ)
	_server.start(0)
	_client.start(PEER)
	for world in [_server, _client]:
		world.add_static_box(Vector3(0, -160, 0), Vector3(12000, 10, 12000))
	_run(link, 90, false)
	var spawned: Dictionary = _server.spawn_pilot(int(_client.local_client_id()), PLANE,
		Vector3(0, 800, 0), 0.0, Vector3(0, 0, -60))
	var pilot: int = int(spawned.get("pilot", 0))
	# The bad link starts once the client has joined, so it is flying that is measured and never the handshake.
	_bad_link = bad_link
	_run(link, SETTLE, true)
	_server.take_trace_events()
	_up_bytes = 0
	_largest_up = 0
	var lost_before: int = _lost
	var discarded_before: int = _discarded
	if drop_one_up:
		_drop_next_up = true
	var rollbacks_before: int = int(_client.resim_stats().get("count", 0))
	var starved: int = 0
	var behind: int = 0
	var starved_after_first: int = 0
	var saw_starvation := false
	for i in range(MEASURE):
		# Change an exact byte after the deliberately lost packet. The server must
		# reconstruct it from the next packet's acknowledged baseline, not merely
		# continue replaying the old control value.
		if drop_one_up and i == 2:
			_input_buttons = 0xA5
		_run(link, 1, true)
		for event in _server.take_trace_events():
			if String(event["type"]) != "input_starved":
				continue
			starved += 1
			if saw_starvation:
				starved_after_first += 1
			saw_starvation = true
			behind += int(event["frame"]) - String(event["detail"]).get_slice("input_frame=", 1).to_int()
	var timing: Dictionary = _client.timing()
	var run: Dictionary = {
		"link": link,
		"starved": starved,
		"behind": behind,
		"starved_after_first": starved_after_first,
		"buttons_seen": _server.buttons_seen(pilot),
		"rollbacks": int(_client.resim_stats().get("count", 0)) - rollbacks_before,
		"largest": _largest_up,
		"per_tick": float(_up_bytes) / MEASURE,
		"lead": int(timing.get("prediction_lead", -1)),
		"truncated": int(timing.get("input_packets_truncated", -1)),
		"frames_per_packet": int(timing.get("input_frames_max", -1)),
		"lost": _lost - lost_before,
		"discarded": _discarded - discarded_before,
	}
	print("[input_window] link %d%s%s: %d starved, %d behind, %d rollbacks, largest packet %d B, %.1f B a tick up, lead %d, %d cut" % [
		link, " (bad ENet link)" if bad_link else "", " (tracked poses)" if tracked_poses else "",
		starved, behind, run["rollbacks"], _largest_up, run["per_tick"],
		run["lead"], run["truncated"]])
	_client.teardown()
	_server.teardown()
	return run



func _run(link: int, ticks: int, flying: bool) -> void:
	for i in range(ticks):
		var roll: float = 0.0
		if flying:
			roll = ROLL if (_tick / ROCK_TICKS) % 2 == 0 else -ROLL
		var input: Dictionary = {"throttle": THROTTLE if flying else 0.0, "pitch": 0.0, "roll": roll, "rudder": 0.0,
			"brake": 0.0, "buttons": _input_buttons, "trigger": 0.0}
		if _tracked_poses and flying:
			var phase := float(_tick) * 0.07
			input["head"] = Vector3(sin(phase) * 0.10, cos(phase * 0.7) * 0.06, sin(phase * 0.4) * 0.05)
			input["left"] = Vector3(-0.3 + sin(phase * 1.1) * 0.12, -0.25 + cos(phase) * 0.10, -0.3)
			input["right"] = Vector3(0.3 + cos(phase * 0.9) * 0.12, -0.25 + sin(phase) * 0.10, -0.3)
			input["head_basis"] = Quaternion(Vector3.UP, phase * 0.2)
			input["left_basis"] = Quaternion(Vector3.RIGHT, phase * 0.3)
			input["right_basis"] = Quaternion(Vector3.FORWARD, phase * 0.25)
		_client.set_input(input)
		_tick += 1
		_deliver_due()
		_server.tick(DT)
		_client.tick(DT)
		_send(false, _server.take_outbound(), link)
		_send(true, _client.take_outbound(), link)


func _send(up: bool, packets: Array, link: int) -> void:
	var direction: int = 0 if up else 1
	var batch: Array = []
	for packet in packets:
		var size: int = PackedByteArray(packet["bytes"]).size()
		if up:
			_up_bytes += size
			_largest_up = maxi(_largest_up, size)
		var late: int = _rng.randi_range(0, JITTER_TICKS) if _bad_link else 0
		if up and _drop_next_up:
			_drop_next_up = false
			_lost += 1
			_sent[direction] += 1
			continue
		batch.append([_tick + maxi(link, 1) + late, up, packet["bytes"], packet["bits"], _sent[direction]])
		_sent[direction] += 1
	if not _bad_link:
		_in_flight.append_array(batch)
		return
	if batch.size() >= 2 and _rng.randf() < SWAP_CHANCE:
		batch.reverse()
	var out_of_service: bool = (_tick % OUTAGE_EVERY) < OUTAGE_TICKS
	for flight in batch:
		if out_of_service or _rng.randf() < LOSS:
			_lost += 1
		else:
			_in_flight.append(flight)


func _deliver_due() -> void:
	var waiting: Array = []
	for flight in _in_flight:
		if int(flight[0]) > _tick:
			waiting.append(flight)
			continue
		var direction: int = 0 if flight[1] else 1
		if _bad_link and int(flight[4]) <= int(_delivered[direction]):
			_discarded += 1
			continue
		_delivered[direction] = maxi(int(_delivered[direction]), int(flight[4]))
		if flight[1]:
			_server.deliver(PEER, flight[2], flight[3])
		else:
			_client.deliver(0, flight[2], flight[3])
	_in_flight = waiting
