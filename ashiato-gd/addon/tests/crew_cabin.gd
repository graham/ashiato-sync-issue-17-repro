extends Node
## WHAT HAPPENS IN A COCKPIT REACHES ITS CREW AT ONCE, AND NOBODY ELSE AT ALL.
##
##   Godot --path addon --headless res://tests/crew_cabin.tscn
##
## A server and three clients in one process across a delayed link. A flies an aeroplane, B joins
## it as copilot and C flies something else. C then boards the same aeroplane, leaves it, and does
## both again. What the crew share -- the master arm, the radio, where every seat's levers are --
## must:
##
##   1. reach every machine aboard within WITHIN_TICKS of the server deciding it;
##   2. be on show on the FIRST client tick after the packet that carries it lands, with no
##      interpolation buffer in between, on a clean link and on one that delivers in lumps;
##   3. never be written onto the wire to a client who is not aboard, counted from the SERVER'S
##      trace of what it serialised for each client, which is the wire and not a registry;
##   4. arrive whole for somebody who boards (the baseline on relevance opening) and be taken
##      away from somebody who leaves (removal on relevance closing).
##
## Counted from the server's change and not from the send, because the send side is the command
## queue's business and `cockpit_loopback` holds it (every_command_arrives, the master arm).
##
## Boarding is the real path: a menu request number and a client id on the input frame, as the CREW page
## sends them. Leaving is the USE button, "take the next craft".
##
## Read RESULT=, not the exit code.

const TICK_HZ: float = 60.0
const DT: float = 1.0 / TICK_HZ
## One-way delay in ticks, as cockpit_loopback's.
const LINK_DELAY_TICKS: int = 4
## HOW LATE A MACHINE ABOARD MAY BE, counted from the server's tick. The server serialises a change
## on the tick it makes it, the packet lands LINK_DELAY_TICKS later, and the client applies it on its
## next tick: LINK_DELAY_TICKS + 1. One more for the order a tick is run in here (server, clients,
## then carry), so a record written on the server's tick T can be carried in T's pump.
const WITHIN_TICKS: int = LINK_DELAY_TICKS + 2
## The lumpy link holds every packet to B until a tick that is a multiple of this, which can add
## LUMP_EVERY - 1 ticks to any arrival.
const LUMP_EVERY: int = 3
## A LINK SHORTER THAN THE INTERPOLATION BUFFER, which is the machine on the same network. Over the
## 4-tick link a record lands already behind the buffered clock and is applied on arrival, so an
## interpolated entity looks as if it snapped; over 1 tick the buffer is what makes it late.
const LAN_LINK_TICKS: int = 1
## How long to let the clocks settle after the link changes length.
const SETTLE_TICKS: int = 180
const PEER_A: int = 1
const PEER_B: int = 2
const PEER_C: int = 3

## Kinds and bits, matching cockpit_world.cpp.
const POD: int = 0
const PLANE: int = 1
const USE: int = 2
## Bus channels, matching Channel::Radio and Channel::Master.
const RADIO: int = 9
const MASTER: int = 13

## THE CREW'S OWN THROTTLE, as the marker that a machine has the cockpit's inside: A holds it at
## this, and a machine that has been told where the linkage is reads it back.
const HELD_THROTTLE: float = 0.8
const SECTIONS: int = 9

var _failures: PackedStringArray = []
var _sections_ran: int = 0
var server
var client_a
var client_b
var client_c
var _tick: int = 0
## [deliver_at_tick, target (0 is the server), from_peer, bytes, bits, sent_tick]
var _in_flight: Array = []
var _lump_b: bool = false
## The one-way delay the pump applies now, in ticks.
var _link_ticks: int = LINK_DELAY_TICKS
## peer -> [[sent_tick, delivered_tick], ...]
var _deliveries: Dictionary = {}
## Every component the server serialised, as [tick, client, server_entity, component]. Only the
## components that can carry something a crew shares are kept; cleared per window.
var _sent: Array = []
## peer -> bytes the server handed it, over the whole run.
var _bytes_to: Dictionary = {}
## peer -> the control overrides that client holds every tick.
var _inputs: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[cabin] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _controls(overrides: Dictionary) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0, "trigger": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input


func _world_of(peer: int):
	match peer:
		PEER_A: return client_a
		PEER_B: return client_b
		PEER_C: return client_c
	return null


func _pump() -> void:
	for packet in server.take_outbound():
		var peer: int = int(packet["peer"])
		var due: int = _tick + _link_ticks
		if _lump_b and peer == PEER_B:
			due = ((due + LUMP_EVERY - 1) / LUMP_EVERY) * LUMP_EVERY
		_in_flight.append([due, peer, 0, packet["bytes"], packet["bits"], _tick])
		_bytes_to[peer] = int(_bytes_to.get(peer, 0)) + (packet["bytes"] as PackedByteArray).size()
	for peer in [PEER_A, PEER_B, PEER_C]:
		for packet in _world_of(peer).take_outbound():
			_in_flight.append([_tick + _link_ticks, 0, peer, packet["bytes"], packet["bits"], _tick])
	var still_flying: Array = []
	for entry in _in_flight:
		if int(entry[0]) > _tick:
			still_flying.append(entry)
			continue
		var target: int = int(entry[1])
		if target == 0:
			server.deliver(int(entry[2]), entry[3], entry[4])
			continue
		_world_of(target).deliver(0, entry[3], entry[4])
		(_deliveries.get_or_add(target, []) as Array).append([int(entry[5]), _tick])
	_in_flight = still_flying


## THE GAME'S ORDER: inputs, server tick, client ticks, then every packet due carried across.
## peer -> that peer's menu request number, on every frame; bumped once per JOIN. See `ControlInput::menu_request`.
var _menu_requests: Dictionary = {}


## ONE JOIN ON `peer`'s FRAMES, as the CREW page presses one: the number moves on and the player rides beside it.
func _press_join(peer: int, client: int) -> void:
	_menu_requests[peer] = (int(_menu_requests.get(peer, 0)) + 1) % 8
	_inputs[peer] = {"join_wanted": client}


func _advance(ticks: int) -> void:
	for i in range(ticks):
		for peer in _inputs:
			var frame: Dictionary = (_inputs[peer] as Dictionary).duplicate()
			frame["menu_request"] = int(_menu_requests.get(peer, 0))
			_world_of(peer).set_input(_controls(frame))
		_tick += 1
		server.tick(DT)
		client_a.tick(DT)
		client_b.tick(DT)
		client_c.tick(DT)
		_pump()
		for event in server.take_trace_events():
			if String(event["type"]) != "component_sent":
				continue
			_sent.append([_tick, int(event["client"]), int(event["entity"]), String(event["component"])])


## The tick a packet sent to `peer` at or after `since` first landed, or -1.
func _first_delivery(peer: int, since: int) -> int:
	var first: int = -1
	for row in _deliveries.get(peer, []):
		if int(row[0]) >= since and (first < 0 or int(row[1]) < first):
			first = int(row[1])
	return first


## One pilot's replicated state, by client id.
func _pilot_of(world, client_id: int) -> Dictionary:
	for pilot in world.pilot_states():
		if int(pilot["client"]) == client_id:
			return pilot
	return {}


## The same vehicle on another world. Its CREW is the bridge: entity ids are per-world.
func _same_vehicle_on(world, server_entity: int) -> int:
	if world == server:
		return server_entity
	for state in server.pilot_states():
		if int(state.get("vehicle", 0)) == server_entity:
			var here: int = int(_pilot_of(world, int(state["client"])).get("vehicle", 0))
			if here != 0:
				return here
	return 0


func _systems_seen(world, craft: int) -> Dictionary:
	var here: int = _same_vehicle_on(world, craft)
	return world.craft_systems(here) if here != 0 else {}


func _crew_seen(world, craft: int) -> Dictionary:
	var here: int = _same_vehicle_on(world, craft)
	return world.crew_controls(here) if here != 0 else {}


## Does this machine hold NO cabin for a craft it can name? False while it cannot name the craft at
## all: a world that has lost track of which entity the craft is has not been told anything, and
## reading that as "closed" made a leaving check pass on a lookup that failed.
func _holds_no_cabin(world, craft: int) -> bool:
	var here: int = _same_vehicle_on(world, craft)
	return here != 0 and (world.crew_controls(here) as Dictionary).is_empty()


## Does this machine have the inside of the cockpit: the linkage, with A's throttle on it?
func _has_the_cabin(world, craft: int) -> bool:
	return float(_crew_seen(world, craft).get("linked_throttle", 0.0)) > HELD_THROTTLE * 0.5


## THE SERVER ENTITIES THAT CARRY THIS CRAFT'S CREW-SHARED STATE ON THE WIRE: the craft itself, and
## whatever the server says belongs to its crew. A library without `cabins_of` answers the craft
## alone -- and fails `the_server_names_what_carries_a_crews_cockpit`, so that branch cannot pass
## silently.
func _crew_carriers(craft: int) -> Dictionary:
	var out: Dictionary = {craft: true}
	if server.has_method("cabins_of"):
		for entity in server.cabins_of(craft):
			out[int(entity)] = true
	return out


## Components serialised for `client_id` on this craft's carriers since the window opened. The
## craft's own record only counts its CREW-SHARED components; its pose goes to everybody.
func _crew_records_to(client_id: int, craft: int, carriers: Dictionary) -> int:
	var count: int = 0
	for row in _sent:
		if int(row[1]) != client_id:
			continue
		var entity: int = int(row[2])
		if entity == craft:
			if String(row[3]) in ["CraftSystems", "CrewControls"]:
				count += 1
		elif carriers.has(entity):
			count += 1
	return count


## The first tick at or after `since` on which the server serialised a crew-shared record for this client, or a
## tick no packet has, so `_first_delivery` answers -1 rather than a packet that did not carry it.
func _first_crew_record(client_id: int, craft: int, carriers: Dictionary, since: int) -> int:
	for row in _sent:
		if int(row[0]) < since or int(row[1]) != client_id:
			continue
		var entity: int = int(row[2])
		if (entity == craft and String(row[3]) in ["CraftSystems", "CrewControls"]) \
				or (entity != craft and carriers.has(entity)):
			return int(row[0])
	return 1 << 30


func _craft() -> int:
	return int(_pilot_of(server, client_a.local_client_id()).get("vehicle", 0))


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("[cabin] CockpitWorld not registered; build with -WithCockpit")
		_failures.append("cockpit_world_is_registered")
		_finish()
		return

	server = ClassDB.instantiate("CockpitWorld")
	client_a = ClassDB.instantiate("CockpitWorld")
	client_b = ClassDB.instantiate("CockpitWorld")
	client_c = ClassDB.instantiate("CockpitWorld")
	_check("the_server_can_trace_what_it_writes", server.set_tracing(true),
		"ASHIATO_GD_WITH_TRACING; the outsider checks count the server's own serialisation")
	for world in [server, client_a, client_b, client_c]:
		world.set_tick_rate(TICK_HZ)
	_check("four_worlds_start", server.start(0) and client_a.start(PEER_A) and client_b.start(PEER_B)
		and client_c.start(PEER_C), "a server and three clients")
	for world in [server, client_a, client_b, client_c]:
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(8000.0, 2.0, 8000.0))
	_advance(90)
	var id_a: int = client_a.local_client_id()
	var id_b: int = client_b.local_client_id()
	var id_c: int = client_c.local_client_id()
	_check("three_clients_handshook", server.connected_clients().size() == 3 and id_a > 0 and id_b > 0
		and id_c > 0, "server sees %s" % [server.connected_clients()])
	if server.connected_clients().size() != 3:
		_finish()
		return

	server.spawn_pilot(id_a, PLANE, Vector3(0.0, 600.0, 0.0), 0.0, Vector3(0.0, 0.0, -60.0))
	server.spawn_pilot(id_b, POD, Vector3(60.0, 600.0, 0.0), 0.0, Vector3.ZERO)
	server.spawn_pilot(id_c, POD, Vector3(-900.0, 30.0, 900.0), 0.0, Vector3.ZERO)
	# Somewhere for C to go when it leaves: "take the next craft" needs a craft with a free seat.
	server.spawn_vehicle(POD, Vector3(900.0, 30.0, 900.0), 0.0)
	_inputs = {PEER_A: {"throttle": HELD_THROTTLE}, PEER_B: {}, PEER_C: {}}
	_advance(60)

	var craft: int = _craft()
	_press_join(PEER_B, id_a)
	_advance(2)
	_inputs[PEER_B] = {}
	for i in range(120):
		_advance(1)
		if server.vehicle_seats(craft).has(id_b) and _same_vehicle_on(client_b, craft) != 0:
			break
	_advance(60)
	_check("b_joins_a_as_crew", server.vehicle_seats(craft).has(id_b) and not server.vehicle_seats(craft).has(id_c),
		"seats %s; A %d, B %d, C %d" % [server.vehicle_seats(craft), id_a, id_b, id_c])
	if not server.vehicle_seats(craft).has(id_b):
		_finish()
		return

	var resims_before: int = int(client_a.resim_stats().get("count", 0))
	var ticks_before: int = _tick
	_test_a_switch_reaches_the_crew_at_once(craft, "lan", LAN_LINK_TICKS, false)
	_test_a_switch_reaches_the_crew_at_once(craft, "clean", LINK_DELAY_TICKS, false)
	_test_a_switch_reaches_the_crew_at_once(craft, "lumpy", LINK_DELAY_TICKS, true)
	print("[cabin] measure: the pilot's machine rolled back %d times over %d ticks of crew switching" % [
		int(client_a.resim_stats().get("count", 0)) - resims_before, _tick - ticks_before])
	_test_the_pilots_own_switch_needs_no_rollback(craft)
	_test_the_outsider_is_never_told(craft, id_b, id_c)
	_test_boarding_opens_the_cabin_and_leaving_closes_it(craft, id_a, id_c, 1)
	_test_boarding_and_leaving_again_and_again(craft, id_a, id_c)
	_test_the_server_names_its_carriers(craft)
	_test_nobody_flying_reads_the_same_on_both_sides_of_the_wire(craft)
	print("[cabin] measure: bytes a tick from the server, over %d ticks: A %.1f, B %.1f, C %.1f" % [_tick,
		float(_bytes_to.get(PEER_A, 0)) / _tick, float(_bytes_to.get(PEER_B, 0)) / _tick,
		float(_bytes_to.get(PEER_C, 0)) / _tick])
	_check("every_section_of_the_suite_ran", _sections_ran == SECTIONS, "%d of %d" % [_sections_ran, SECTIONS])
	_finish()


## ---- 1 and 2. A SWITCH THROWN IN THE BACK REACHES EVERY SEAT AT ONCE -------------------------------
##
## B, the copilot, throws the master arm. The pilot's machine predicts the aeroplane and the copilot's
## does not, so the two are late in different ways today: A through a rollback, B through its
## interpolation buffer. Both are measured from the server's tick, and B is measured against the
## packet that carried it -- the tick it landed plus one is the first tick it can be applied on.
func _test_a_switch_reaches_the_crew_at_once(craft: int, link: String, link_ticks: int, lumpy: bool) -> void:
	if link_ticks != _link_ticks:
		_link_ticks = link_ticks
		_advance(SETTLE_TICKS)
	_lump_b = lumpy
	_advance(LUMP_EVERY * 4)
	_deliveries.clear()
	_sent.clear()
	var timing: Dictionary = client_b.timing()
	print("[cabin] measure: %s link %d ticks; the copilot's clock: buffer %s frames, latency %.2f frames, buffered frame %s, server estimate %s" % [
		link, link_ticks, timing.get("buffer_frames", "?"), float(timing.get("latency_frames", 0.0)),
		timing.get("buffered_frame", "?"), timing.get("estimated_server_frame", "?")])
	# The same derivation as WITHIN_TICKS, over this link.
	var bound: int = link_ticks + 2 + (LUMP_EVERY - 1 if lumpy else 0)
	var was: bool = bool(server.craft_systems(craft).get("master", false))
	var taken: bool = client_b.send_command(MASTER, 0 if was else 1)
	var server_at: int = -1
	var a_at: int = -1
	var b_at: int = -1
	for i in range(240):
		_advance(1)
		if server_at < 0 and bool(server.craft_systems(craft).get("master", was)) != was:
			server_at = _tick
		if a_at < 0 and bool(_systems_seen(client_a, craft).get("master", was)) != was:
			a_at = _tick
		if b_at < 0 and bool(_systems_seen(client_b, craft).get("master", was)) != was:
			b_at = _tick
		if server_at >= 0 and a_at >= 0 and b_at >= 0:
			break
	_advance(LUMP_EVERY * 4)
	_lump_b = false
	# THE PACKET THAT CARRIED IT, from the server's own trace: the first tick the server serialised a crew-shared
	# record for that client at or after the change, and that tick's packet. Not "the first packet sent after the
	# change": a crew record is written after the server's tick and can leave on a later packet, which over a lumpy
	# link lands in a later lump -- the first version measured from the wrong lump and read 2 ticks of lag that
	# were the link's (2026-09-14).
	var carriers: Dictionary = _crew_carriers(craft)
	var a_landed: int = _first_delivery(PEER_A, _first_crew_record(client_a.local_client_id(), craft, carriers, server_at))
	var b_landed: int = _first_delivery(PEER_B, _first_crew_record(client_b.local_client_id(), craft, carriers, server_at))
	_check("%s_the_server_takes_the_copilots_master_arm" % link, taken and server_at >= 0,
		"send %s, the server shows it at tick %d" % ["taken" if taken else "refused", server_at])
	_check("%s_every_seat_shows_it_within_%d_ticks_of_the_server" % [link, bound],
		server_at >= 0 and a_at >= 0 and b_at >= 0 and a_at - server_at <= bound and b_at - server_at <= bound,
		"pilot %d, copilot %d ticks after the server" % [a_at - server_at, b_at - server_at])
	_check("%s_the_copilots_machine_shows_it_on_the_first_tick_after_the_packet_lands" % link,
		b_landed >= 0 and b_at >= 0 and b_at <= b_landed + 1,
		"landed at tick %d, shown at %d: %d ticks between" % [b_landed, b_at, b_at - b_landed - 1])
	_check("%s_and_so_does_the_pilots" % link, a_landed >= 0 and a_at >= 0 and a_at <= a_landed + 1,
		"landed at tick %d, shown at %d: %d ticks between" % [a_landed, a_at, a_at - a_landed - 1])
	_sections_ran += 1


## ---- 2b. THE PILOT'S OWN SWITCH SHOWS ON THE PILOT'S OWN MACHINE WITHOUT A ROLLBACK --------------------
##
## The pilot's machine predicts the aeroplane, and a switch on a predicted entity only ever arrives there
## through a rollback: the pilot turns the radio and the whole world is resimulated to show it. A rollback
## is applied in the client tick its record arrives on, so on that path the tick the switch first shows IS
## a rollback tick, every time.
##
## NOT COUNTED FROM THE TRACE. sync's rollback-reason event fires only for a trait that supplies a reason,
## which none here does, and its conflict event names the component by entity and not by name: an
## attribution check written on the trace passed with no event at all (0 of 0, 2026-09-14). So it asks the
## one thing both paths report -- did the pilot's machine roll back on the tick the switch appeared -- over
## THREE switches. The aeroplane is also corrected for reasons of its own, 13 times in 482 ticks here
## (2.7% a tick), so one coincidence is allowed: today's path gives 3 of 3, and a false failure after the
## change needs two coincidences in three, about 0.2%.
const OWN_SWITCHES: int = 3


func _test_the_pilots_own_switch_needs_no_rollback(craft: int) -> void:
	_link_ticks = LAN_LINK_TICKS
	_advance(SETTLE_TICKS)
	var shown: int = 0
	var on_a_rollback: int = 0
	var lags: PackedStringArray = []
	for round in range(OWN_SWITCHES):
		var wanted: int = (int(server.craft_systems(craft).get("radio", 0)) + 3) % 8
		var sent_at: int = _tick
		if not client_a.send_command(RADIO, wanted):
			lags.append("refused")
			continue
		for i in range(240):
			var resims_before: int = int(client_a.resim_stats().get("count", 0))
			_advance(1)
			if int(_systems_seen(client_a, craft).get("radio", -1)) == wanted:
				shown += 1
				var rolled: bool = int(client_a.resim_stats().get("count", 0)) > resims_before
				if rolled:
					on_a_rollback += 1
				lags.append("%d ticks%s" % [_tick - sent_at, " on a rollback" if rolled else ""])
				break
		_advance(30)
	_check("the_pilots_own_radio_shows_on_the_pilots_machine", shown == OWN_SWITCHES,
		"%d of %d shown: %s" % [shown, OWN_SWITCHES, ", ".join(lags)])
	_check("and_it_takes_no_rollback_to_show_it", shown == OWN_SWITCHES and on_a_rollback <= 1,
		"%d of %d appeared on a tick the pilot's machine rolled back, 1 allowed for the aeroplane's own corrections"
			% [on_a_rollback, shown])
	_link_ticks = LINK_DELAY_TICKS
	_advance(SETTLE_TICKS)
	_sections_ran += 1


## ---- 3. NOTHING OF IT IS WRITTEN TO A CLIENT WHO IS NOT ABOARD ---------------------------------------
##
## The pilot and the copilot each work a switch nobody outside can see, and nothing else about the
## craft moves: no gunner, no lights. Counted on the SERVER's trace per client, so it is what went
## onto the wire and not what a client happened to keep. The crew leg is the control: the counting
## sees these records when they are addressed to somebody entitled to them.
func _test_the_outsider_is_never_told(craft: int, id_b: int, id_c: int) -> void:
	_sent.clear()
	var radio: int = int(server.craft_systems(craft).get("radio", 0))
	client_a.send_command(RADIO, (radio + 3) % 8)
	_advance(30)
	client_b.send_command(RADIO, (radio + 5) % 8)
	_advance(30)
	client_b.send_command(MASTER, 0 if bool(server.craft_systems(craft).get("master", false)) else 1)
	_advance(60)
	var carriers: Dictionary = _crew_carriers(craft)
	var to_crew: int = _crew_records_to(id_b, craft, carriers)
	var to_outsider: int = _crew_records_to(id_c, craft, carriers)
	_check("the_crew_are_written_what_their_switches_did", to_crew > 0,
		"%d crew-shared records written to the copilot" % to_crew)
	_check("and_the_outsider_is_written_none_of_it", to_outsider == 0,
		"%d crew-shared records written to a client who is not aboard" % to_outsider)
	_sections_ran += 1


## ---- 4. BOARDING OPENS THE CABIN, WHOLE, AND LEAVING CLOSES IT ---------------------------------------
##
## The master arm is set before C arrives, so the first frame C has of the cabin must already carry
## it: a boarder is sent the state, not the changes since they sat down. Then C leaves, and must stop
## holding the cabin within the same bound -- a copy left behind is a copy of something the craft is
## no longer telling them.
func _test_boarding_opens_the_cabin_and_leaving_closes_it(craft: int, id_a: int, id_c: int, round: int) -> void:
	var armed: bool = bool(server.craft_systems(craft).get("master", false))
	_press_join(PEER_C, id_a)
	_advance(2)
	_inputs[PEER_C] = {}
	var seated_at: int = -1
	var opened_at: int = -1
	var first_frame_whole: bool = false
	for i in range(240):
		_advance(1)
		if seated_at < 0 and server.vehicle_seats(craft).has(id_c):
			seated_at = _tick
		if opened_at < 0 and not _crew_seen(client_c, craft).is_empty():
			opened_at = _tick
			first_frame_whole = _has_the_cabin(client_c, craft) \
				and bool(_systems_seen(client_c, craft).get("master", not armed)) == armed
		if seated_at >= 0 and opened_at >= 0:
			break
	_check("round_%d_the_outsider_boards" % round, seated_at >= 0,
		"C is in the craft's seats at tick %d: %s" % [seated_at, server.vehicle_seats(craft)])
	_check("round_%d_the_cabin_opens_within_%d_ticks_of_sitting_down" % [round, WITHIN_TICKS],
		seated_at >= 0 and opened_at >= 0 and opened_at - seated_at <= WITHIN_TICKS,
		"%d ticks after the seat" % (opened_at - seated_at))
	_check("round_%d_and_its_first_frame_is_the_whole_cabin" % round, first_frame_whole,
		"the linkage and the master arm (%s) on the first frame it had" % armed)
	_advance(30)

	_inputs[PEER_C] = {"buttons": USE}
	_advance(2)
	_inputs[PEER_C] = {}
	var left_at: int = -1
	var closed_at: int = -1
	for i in range(240):
		_advance(1)
		if left_at < 0 and not server.vehicle_seats(craft).has(id_c):
			left_at = _tick
		if left_at >= 0 and closed_at < 0 and _holds_no_cabin(client_c, craft):
			closed_at = _tick
		if left_at >= 0 and closed_at >= 0:
			break
	# LEAVING IS ONLY LEAVING FOR SOMEBODY WHO WAS ABOARD: a C that never sat down is "not in the seats" on the first tick,
	# holds no cabin to lose, and is written nothing -- and each of these three passed that way.
	_check("round_%d_the_boarder_leaves" % round, seated_at >= 0 and left_at >= 0,
		"C sat down at tick %d and left at tick %d" % [seated_at, left_at])
	_check("round_%d_and_the_cabin_is_taken_away_within_%d_ticks" % [round, WITHIN_TICKS],
		seated_at >= 0 and left_at >= 0 and closed_at >= 0 and closed_at - left_at <= WITHIN_TICKS,
		"%s" % ("still held %d ticks later" % 240 if closed_at < 0 else "%d ticks after leaving" % (closed_at - left_at)))

	# AND WHAT HAPPENS AFTER THEY LEAVE IS NOT WRITTEN TO THEM.
	_sent.clear()
	var radio: int = int(server.craft_systems(craft).get("radio", 0))
	client_a.send_command(RADIO, (radio + 1) % 8)
	_advance(60)
	var after: int = _crew_records_to(id_c, craft, _crew_carriers(craft))
	_check("round_%d_and_nothing_the_crew_do_afterwards_is_written_to_them" % round,
		seated_at >= 0 and left_at >= 0 and after == 0,
		"%d crew-shared records written to C after it left" % after)
	_advance(30)
	if round == 1:
		_sections_ran += 1


## ---- 5. AND AGAIN: boarding and leaving churn a client's wire ids -----------------------------------
func _test_boarding_and_leaving_again_and_again(craft: int, id_a: int, id_c: int) -> void:
	var before: int = _failures.size()
	for round in range(2, 6):
		_test_boarding_opens_the_cabin_and_leaving_closes_it(craft, id_a, id_c, round)
	_check("four_more_boardings_and_leavings_all_held", _failures.size() == before,
		"%d checks failed across rounds 2 to 5" % (_failures.size() - before))
	_sections_ran += 1


## ---- 6. THE SERVER NAMES WHAT CARRIES A CREW'S COCKPIT ------------------------------------------------
##
## The outsider counts above look for crew-shared records on the craft and on whatever the server says
## carries that craft's cockpit. Without the question they would look at the craft alone, and a
## cockpit carried somewhere else would pass them by.
func _test_the_server_names_its_carriers(craft: int) -> void:
	_check("the_server_names_what_carries_a_crews_cockpit", server.has_method("cabins_of"),
		"cabins_of(vehicle) %s" % ["answers %s" % [server.cabins_of(craft)] if server.has_method("cabins_of")
			else "is not bound"])
	_sections_ran += 1


## ---- 7. NOBODY FLYING IS THE SAME NOBODY ON EVERY MACHINE ---------------------------------------------
##
## `CrewControls::hands_on` names the seat moving anything, or nobody. The wire carried it in THREE BITS, and the server
## wrote 255 for nobody -- so the server read 255 and every machine reading the cabin back, the host's own client
## included, read 7 (lane/guns, 2026-09-15). Taken last, because it takes A's hand off the throttle every other section
## uses as the marker that a machine has the cabin at all. The answer must be the same on all three and not a seat of
## the craft. Since lane/seats (2026-09-18) a craft may have a seat 7, and `crew_controls` says nobody as -1, which the
## simulation's own sentinel never leaves the library as; `tests/many_seats.gd` holds it in a craft that has a seat 7.
func _test_nobody_flying_reads_the_same_on_both_sides_of_the_wire(craft: int) -> void:
	_inputs[PEER_A] = {}
	_inputs[PEER_B] = {}
	_advance(_link_ticks * 2 + 60)
	var here: int = int((server.crew_controls(craft) as Dictionary).get("hands_on", -1))
	var at_a: int = int(_crew_seen(client_a, craft).get("hands_on", -1))
	var at_b: int = int(_crew_seen(client_b, craft).get("hands_on", -1))
	var seats: int = (server.vehicle_seats(craft) as Array).size()
	_check("nobody_flying_reads_the_same_on_the_server_and_both_crew_machines",
		here == at_a and here == at_b and here == -1,
		"hands_on: server %d, pilot's machine %d, crew's machine %d; the craft has %d seats" % [here, at_a, at_b, seats])
	_sections_ran += 1


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
