extends Node
## Headless: A CRAFT WITH FIVE HUNDRED DEVICES, AND ONE AT THE TOP OF THE WIRE, WORKED BY A JOINER.
##
##   Godot --headless --xr-mode off --fixed-fps 120 --path cockpit res://tests/many_devices.tscn
##
## ASKED FOR ON 2026-09-18: "There could easily be 255 or 512 devices in a single vehicle ... internal to the plane there
## will be many (including sometimes 4x for a single device, one for each pilot). Let's make sure we can support a large
## amount > 256 and we can configure more if we get there."
##
## WHAT WAS IN THE WAY. Devices were never the limit: any number of switches, keys and per-seat copies work one channel
## through `DeviceSignalRouter`. What was capped was the number of independent values a crew shares -- the bus's
## CHANNELS -- at 32, five bits on the wire, seventeen used and each one a hand-written case in `apply_command`. A
## channel past them had no wire to travel on and nowhere to be kept. Now a kind is fitted with GENERIC channels from 32
## up to `kCommandChannels` (`Sim.fit_channels`), a command names one in the wide form, and the server keeps its value
## on a `BusPage` -- the crew's to the crew alone, the craft's to everybody -- 32 to a page and only once one is set.
##
## WHAT IS REAL HERE. A server and two client CockpitWorlds over the in-process link `command_burst` uses: a joiner in
## the F-14's back seat, and a spectator in a pod elsewhere. The joiner's devices go through the real path a hand does
## -- a `VehicleControl` with a device id and a binding, `DeviceSignalRouter.route`, `Sim.send_command`, its world's
## queue, the input frame, the server's `apply_command` -- with `Sim.client` pointed at the joiner's world for the
## length of it, as `shots` does. What each machine SEES is read back through `bus_values`, which is what
## `VehicleView.channel_value` draws a generic channel from.
##
## WHAT IT HOLDS, each checked, not printed:
##   * the widths are one place: every `Sim.Channel` is below the first generic channel and there are as many as the
##     library names, and the channel is at least sixteen bits, as asked;
##   * a malformed channel is refused with a warning and the rest are fitted; nothing is fitted while a world runs;
##   * 512 generic channels and the one at the very top (65,535) all round-trip from the joiner: every value on the
##     server, every one on the joiner, and on the spectator every CRAFT channel and not one CREW channel;
##   * device 300 (crew) and device 511 (craft) specifically, and four per-seat copies of one device on one channel;
##   * a whole panel queues at once (512; it was 16), a channel not fitted is refused, and a value clamps to its range;
##   * a crew member who leaves the craft loses its crew pages and keeps seeing its craft pages;
##   * and what it costs: pages, bytes on the wire down to each client, and the server's tick, printed.
##
## MUTANTS, each built and run (busbits, 2026-09-18): `kCommandChannelBits` 8 -- device 300, 511 and the top channel are
## refused by `fit_channels` and never land; `kCommandChannelBits` 5 -- does not compile (the short form must be
## narrower than the wide one); `kCommandSeqBits` 8 -- `command_burst`'s burst of 256 ends on the value before it.
##
## Read RESULT=, not the exit code.

const DT: float = 1.0 / 120.0
const TICK_HZ: float = 120.0
const JOINER_PEER: int = 2
const SPECTATOR_PEER: int = 3
const POD: int = 0
const TOMCAT: int = 25
const RIO_SEAT: int = 1
## HOW MANY GENERIC CHANNELS THE CRAFT IS FITTED WITH, from the first generic channel up, and then one more at the very
## top of the wire. Even channels are the crew's, odd ones the craft's.
const PANEL: int = 512
## The two devices the lead asked for by number, and the one channel fitted with a range of 1 to see a value clamp.
const CREW_DEVICE: int = 300
const CRAFT_DEVICE: int = 511
const SWITCH_CHANNEL: int = 33
## A channel inside the wire and past the panel, fitted with nothing.
const UNFITTED: int = 600

var _failures: PackedStringArray = []
var _server: RefCounted = null
var _joiner: RefCounted = null
var _spectator: RefCounted = null
var _tick: int = 0
## [[due_tick, to (0 server, else a peer), from_peer, bytes, bits], ...]
var _in_flight: Array = []
var _bytes_down: Dictionary = {}
var _server_usec: int = 0
var _limits: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[many_devices] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "CockpitWorld is not registered")
		_finish()
		return
	_limits = Sim.bus_limits()
	_the_widths_are_one_place()
	_a_malformed_channel_is_refused_and_the_rest_are_fitted()
	var fitted: Dictionary = Sim.fit_channels(TOMCAT, _panel())
	_check("the_panel_is_fitted", int(fitted.get("fitted", 0)) == PANEL + 1 and int(fitted.get("refused", -1)) == 0,
		"%s for %d channels" % [str(fitted), PANEL + 1])
	_a_joiner_works_every_device_and_everybody_sees_what_they_should()
	Sim.fit_channels(TOMCAT, [])
	_finish()


func _top() -> int:
	return int(_limits.get("channels", 0)) - 1


func _first() -> int:
	return int(_limits.get("first_generic_channel", 1 << 30))


## THE PANEL: PANEL channels from the first generic one, and the top of the wire.
func _panel() -> Array:
	var out: Array = []
	for i in range(PANEL):
		var channel: int = _first() + i
		out.append({"channel": channel, "name": "device %d" % channel, "range": 1 if channel == SWITCH_CHANNEL else 255,
			"audience": "crew" if channel % 2 == 0 else "craft"})
	out.append({"channel": _top(), "name": "the last channel", "range": 255, "audience": "craft"})
	return out


func _is_crew(channel: int) -> bool:
	return channel != _top() and channel % 2 == 0


## WHAT THE JOINER ASKS EACH CHANNEL FOR: never zero, never the same twice in a row, and 5 on the one-position switch.
func _asked(channel: int) -> int:
	return 5 if channel == SWITCH_CHANNEL else 1 + (channel * 7) % 254


func _expected(channel: int) -> int:
	return 1 if channel == SWITCH_CHANNEL else _asked(channel)


func _the_widths_are_one_place() -> void:
	var first: int = _first()
	var named: int = int(_limits.get("named_channels", -1))
	var highest: int = -1
	for name in Sim.Channel:
		highest = maxi(highest, int(Sim.Channel[name]))
	_check("every_named_channel_is_below_the_generic_ones", highest < first,
		"Sim.Channel runs to %d; generic channels start at %d" % [highest, first])
	_check("sim_names_as_many_channels_as_the_library", Sim.Channel.size() == named and highest == named - 1,
		"Sim.Channel has %d, the library %d" % [Sim.Channel.size(), named])
	var bits: int = int(_limits.get("channel_bits", 0))
	_check("the_channel_is_at_least_sixteen_bits", bits >= 16 and int(_limits.get("channels", 0)) == 1 << bits,
		"%d bits, %d channels" % [bits, int(_limits.get("channels", 0))])


func _a_malformed_channel_is_refused_and_the_rest_are_fitted() -> void:
	var answer: Dictionary = Sim.fit_channels(POD, [
		{"channel": 16, "name": "a named channel", "range": 1, "audience": "crew"},
		{"channel": _top() + 1, "name": "past the wire", "range": 1, "audience": "crew"},
		{"channel": 40, "name": "no range", "range": 0, "audience": "crew"},
		{"channel": 41, "name": "", "range": 1, "audience": "crew"},
		{"channel": 42, "name": "nobody's", "range": 1, "audience": "everybody"},
		{"channel": 43, "name": "twice", "range": 1, "audience": "crew"},
		{"channel": 43, "name": "twice again", "range": 1, "audience": "craft"},
		{"channel": 44, "name": "a good one", "range": 3, "audience": "craft"},
	])
	var schema: Array = Sim.schema_of(POD).get("channels", []) as Array
	var generic: Array = schema.filter(func(row: Dictionary) -> bool: return bool(row.get("generic", false)))
	_check("a_malformed_channel_is_refused_and_the_rest_are_fitted",
		int(answer.get("refused", 0)) == 6 and int(answer.get("fitted", 0)) == 2 and generic.size() == 2,
		"%s; the schema lists %d generic" % [str(answer), generic.size()])
	Sim.fit_channels(POD, [])


func _a_joiner_works_every_device_and_everybody_sees_what_they_should() -> void:
	var hull: int = _stand_up()
	if hull == 0:
		return
	var late: Dictionary = Sim.fit_channels(TOMCAT, [])
	_check("nothing_is_fitted_while_a_world_runs", int(late.get("refused", -1)) == 0 and int(late.get("fitted", -1)) == 0
		and (Sim.schema_of(TOMCAT).get("channels", []) as Array).size() > PANEL,
		"%s, and the schema still lists the panel" % str(late))
	var was: RefCounted = Sim.client
	Sim.client = _joiner
	DeviceSignalRouter.reset_for_test()

	# A QUIET SECOND, to measure against.
	_measure_from()
	_advance(120)
	var quiet: Dictionary = _measured(120)

	# DEVICE 300 AND DEVICE 511, as a hand works them: a control with a stable id and a binding, through the router.
	var crew_device := _device("seat1/breaker %d" % CREW_DEVICE, CREW_DEVICE)
	var craft_device := _device("seat1/switch %d" % CRAFT_DEVICE, CRAFT_DEVICE)
	crew_device.value.y = 77.0 / 255.0
	craft_device.value.y = 200.0 / 255.0
	var routed: Array = [DeviceSignalRouter.route(TOMCAT, RIO_SEAT, crew_device),
		DeviceSignalRouter.route(TOMCAT, RIO_SEAT, craft_device)]
	_advance(30)
	_check("device_300_from_a_joiner_lands", _server_values(hull).get(CREW_DEVICE, -1) == 77
		and _joiner_values().get(CREW_DEVICE, -1) == 77,
		"routed %s; server %d, joiner %d" % [str(routed[0]), _server_values(hull).get(CREW_DEVICE, -1),
			_joiner_values().get(CREW_DEVICE, -1)])
	_check("device_511_from_a_joiner_lands_everywhere", _server_values(hull).get(CRAFT_DEVICE, -1) == 200
		and _joiner_values().get(CRAFT_DEVICE, -1) == 200 and _spectator_values().get(CRAFT_DEVICE, -1) == 200,
		"routed %s; server %d, joiner %d, spectator %d" % [str(routed[1]), _server_values(hull).get(CRAFT_DEVICE, -1),
			_joiner_values().get(CRAFT_DEVICE, -1), _spectator_values().get(CRAFT_DEVICE, -1)])
	_check("and_the_spectator_does_not_see_the_crews_device", not _spectator_values().has(CREW_DEVICE),
		"spectator has %s" % str(_spectator_values().get(CREW_DEVICE, "nothing")))

	# FOUR COPIES OF ONE DEVICE, one in front of each seat, all on one channel: the last one worked is what everybody sees.
	var copies: Array = []
	for seat in range(4):
		copies.append(_device("seat%d/fuel pump" % seat, 302))
	for seat in range(4):
		var copy: VehicleControl = copies[seat]
		copy.value.y = float(10 * (seat + 1)) / 255.0
		DeviceSignalRouter.route(TOMCAT, RIO_SEAT, copy)
		_advance(8)
	_advance(20)
	_check("four_copies_of_one_device_share_its_channel", _server_values(hull).get(302, -1) == 40
		and _joiner_values().get(302, -1) == 40, "server %d, joiner %d after 10, 20, 30, 40 from four seats' copies"
		% [_server_values(hull).get(302, -1), _joiner_values().get(302, -1)])
	for control in copies + [crew_device, craft_device]:
		(control as VehicleControl).free()

	# THE WHOLE PANEL AT ONCE: 512 sends in one frame, then the drain, then the top of the wire.
	var queued: int = 0
	for i in range(PANEL):
		var channel: int = _first() + i
		if bool(_joiner.send_command(channel, _asked(channel))):
			queued += 1
	_check("a_whole_panel_queues_at_once", queued == PANEL, "%d of %d accepted in one frame" % [queued, PANEL])
	var ride: int = maxi(1, int(ceil(float(_limits.get("ride_seconds", 1.0 / 30.0)) * TICK_HZ - 1e-6)))
	_measure_from()
	var drain: int = PANEL * ride + 60
	_advance(drain)
	var busy: Dictionary = _measured(drain)
	_joiner.send_command(_top(), _asked(_top()))
	_joiner.send_command(UNFITTED, 9)
	_advance(3 * ride + 30)

	var server := _server_values(hull)
	var joiner := _joiner_values()
	var spectator := _spectator_values()
	var wrong_server: Array = []
	var wrong_joiner: Array = []
	var wrong_spectator: Array = []
	var crew_leaked: int = 0
	var channels: Array = []
	for i in range(PANEL):
		channels.append(_first() + i)
	channels.append(_top())
	for channel in channels:
		var want: int = _expected(channel)
		if int(server.get(channel, 0)) != want:
			wrong_server.append(channel)
		if int(joiner.get(channel, 0)) != want:
			wrong_joiner.append(channel)
		if _is_crew(channel):
			crew_leaked += 1 if spectator.has(channel) else 0
		elif int(spectator.get(channel, 0)) != want:
			wrong_spectator.append(channel)
	_check("every_one_of_%d_channels_lands_on_the_server" % channels.size(), wrong_server.is_empty(),
		"%d wrong: %s" % [wrong_server.size(), str(wrong_server.slice(0, 8))])
	_check("and_the_joiner_sees_every_one", wrong_joiner.is_empty(),
		"%d wrong: %s" % [wrong_joiner.size(), str(wrong_joiner.slice(0, 8))])
	_check("and_the_spectator_every_craft_channel", wrong_spectator.is_empty(),
		"%d wrong: %s" % [wrong_spectator.size(), str(wrong_spectator.slice(0, 8))])
	_check("and_not_one_crew_channel", crew_leaked == 0, "%d crew channels reached the spectator" % crew_leaked)
	# AND NOT ONE CREW PAGE, whatever it holds: the audience is what sync SENT, counted on the spectator's own registry,
	# not what `bus_values` chose to show. Beside it, the crew member's world holds exactly its own copies.
	var seen_by_spectator: Dictionary = _spectator.bus_page_stats()
	var seen_by_joiner: Dictionary = _joiner.bus_page_stats()
	_check("no_crew_page_ever_reaches_a_peer_outside_the_crew", int(seen_by_spectator.get("crew_pages", -1)) == 0
		and int(seen_by_spectator.get("craft_pages", 0)) > 0 and int(seen_by_joiner.get("crew_pages", 0)) > 0,
		"spectator holds %d crew and %d craft pages; the joiner %d crew" % [int(seen_by_spectator.get("crew_pages", -1)),
			int(seen_by_spectator.get("craft_pages", 0)), int(seen_by_joiner.get("crew_pages", 0))])
	_check("the_channel_at_the_top_of_the_wire_lands", int(server.get(_top(), 0)) == _expected(_top())
		and int(spectator.get(_top(), 0)) == _expected(_top()),
		"channel %d: server %d, spectator %d, asked %d" % [_top(), int(server.get(_top(), 0)),
			int(spectator.get(_top(), 0)), _expected(_top())])
	_check("a_value_clamps_to_its_channels_range", int(server.get(SWITCH_CHANNEL, 0)) == 1,
		"asked %d of a one-position switch; the server has %d" % [_asked(SWITCH_CHANNEL), int(server.get(SWITCH_CHANNEL, 0))])
	_check("a_channel_not_fitted_is_refused", not server.has(UNFITTED), "server has %s" % str(server.get(UNFITTED, "nothing")))

	var stats: Dictionary = _server.bus_page_stats()
	var memory: int = int(stats["craft_pages"]) * int(stats["page_bytes"]) + int(stats["crew_pages"]) * int(stats["page_bytes"]) \
		+ int(stats["crew_truth_pages"]) * int(stats["truth_page_bytes"])
	print("[many_devices] server: %d craft pages, %d crew pages, %d crew truth pages; %d B of page data for the craft, "
		% [int(stats["craft_pages"]), int(stats["crew_pages"]), int(stats["crew_truth_pages"]), memory]
		+ "%d B for the %d fitted entries of the table; %d generic commands applied"
		% [int(stats["fitted_entry_bytes"]) * int(stats["fitted_channels"]), int(stats["fitted_channels"]),
			int(stats["generic_applied"])])
	print("[many_devices] down a tick: joiner %.1f B quiet, %.1f B draining the panel; spectator %.1f B quiet, %.1f B draining"
		% [quiet["joiner"], busy["joiner"], quiet["spectator"], busy["spectator"]])
	print("[many_devices] up a tick from the joiner: %.1f B quiet, %.1f B draining; server tick %.3f ms quiet, %.3f ms draining"
		% [quiet["up"], busy["up"], quiet["server_ms"], busy["server_ms"]])

	# A CREW MEMBER WHO LEAVES takes nothing of the crew's with it, and still sees the craft like anybody.
	# INTO A POD OF ITS OWN: the one it arrived in was put away as litter once it sat down in the F-14.
	var me: int = int(_joiner.local_client_id())
	var moved: bool = int(_server.spawn_pilot(me, POD, Vector3(80.0, 4.0, 80.0), 0.0, Vector3.ZERO).get("vehicle", 0)) != 0
	_advance(60)
	var after := _joiner_values()
	var crew_left: int = 0
	for channel in after:
		crew_left += 1 if _is_crew(int(channel)) else 0
	_check("a_crew_member_who_leaves_loses_the_crew_pages", moved and crew_left == 0
		and int(after.get(CRAFT_DEVICE, 0)) == _expected(CRAFT_DEVICE),
		"moved %s; %d crew channels still on the leaver, craft device %d" % [moved, crew_left,
			int(after.get(CRAFT_DEVICE, 0))])
	Sim.client = was
	_teardown()


## A CONTROL IN FRONT OF A SEAT, as the builder places one: a stable device id and the binding a package saves.
func _device(id: String, channel: int) -> VehicleControl:
	var control := VehicleControl.new()
	control.device_id = id
	control.channel = channel
	control.channel_range = 255
	control.signal_binding = DeviceSignalRouter.binding_of(channel, 255)
	return control


func _server_values(hull: int) -> Dictionary:
	return _server.bus_values(hull) if _server != null else {}


func _joiner_values() -> Dictionary:
	return _joiner.bus_values(_local_hull(_joiner)) if _joiner != null else {}


func _spectator_values() -> Dictionary:
	return _spectator.bus_values(_local_hull(_spectator)) if _spectator != null else {}


## THE TOMCAT AS THIS CLIENT KNOWS IT: its own entity id, found by kind, since there is only one.
func _local_hull(world: RefCounted) -> int:
	for row in world.vehicle_states():
		if int(row.get("kind", -1)) == TOMCAT:
			return int(row.get("entity", 0))
	return 0


## A SERVER, A JOINER IN THE F-14'S BACK SEAT, AND A SPECTATOR IN A POD. The hull, or 0 having said why.
func _stand_up() -> int:
	_server = ClassDB.instantiate("CockpitWorld")
	_joiner = ClassDB.instantiate("CockpitWorld")
	_spectator = ClassDB.instantiate("CockpitWorld")
	_tick = 0
	_in_flight.clear()
	for world in [_server, _joiner, _spectator]:
		world.set_tick_rate(TICK_HZ)
	_server.start(0)
	_joiner.start(JOINER_PEER)
	_spectator.start(SPECTATOR_PEER)
	for world in [_server, _joiner, _spectator]:
		world.add_static_box(Vector3(0.0, -2.0, 0.0), Vector3(400.0, 2.0, 400.0))
	_advance(90)
	var me: int = int(_joiner.local_client_id())
	var them: int = int(_spectator.local_client_id())
	if me <= 0 or them <= 0:
		_check("both_clients_handshook", false, "client ids %d and %d" % [me, them])
		_teardown()
		return 0
	var craft: Dictionary = _server.spawn_pilot(201, TOMCAT, Vector3(0.0, 300.0, 0.0), 0.0, Vector3.ZERO)
	_server.spawn_pilot(me, POD, Vector3(60.0, 4.0, 60.0), 0.0, Vector3.ZERO)
	_server.spawn_pilot(them, POD, Vector3(-60.0, 4.0, 60.0), 0.0, Vector3.ZERO)
	var hull: int = int(craft.get("vehicle", 0))
	_advance(20)
	if hull == 0 or not bool(_server.seat_client(me, hull, RIO_SEAT)):
		_check("the_joiner_takes_the_rios_seat", false, "client %d into seat %d of %d" % [me, RIO_SEAT, hull])
		_teardown()
		return 0
	_advance(40)
	if _local_hull(_joiner) == 0 or _local_hull(_spectator) == 0:
		_check("both_clients_see_the_tomcat", false, "joiner %d, spectator %d" % [_local_hull(_joiner),
			_local_hull(_spectator)])
		_teardown()
		return 0
	return hull


func _controls() -> Dictionary:
	return {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}


func _advance(ticks: int) -> void:
	for i in range(ticks):
		_joiner.set_input(_controls())
		_spectator.set_input(_controls())
		_tick += 1
		var began: int = Time.get_ticks_usec()
		_server.tick(DT)
		_server_usec += Time.get_ticks_usec() - began
		_joiner.tick(DT)
		_spectator.tick(DT)
		_pump()


func _measure_from() -> void:
	_bytes_down = {JOINER_PEER: 0, SPECTATOR_PEER: 0, 0: 0}
	_server_usec = 0


func _measured(ticks: int) -> Dictionary:
	return {"joiner": float(_bytes_down[JOINER_PEER]) / ticks, "spectator": float(_bytes_down[SPECTATOR_PEER]) / ticks,
		"up": float(_bytes_down[0]) / ticks, "server_ms": float(_server_usec) / 1000.0 / ticks}


## A ONE-TICK LINK, as `command_burst`'s: everything sent this tick is delivered before the next.
func _pump() -> void:
	for packet in _server.take_outbound():
		var peer: int = int(packet["peer"])
		_bytes_down[peer] = int(_bytes_down.get(peer, 0)) + (packet["bytes"] as PackedByteArray).size()
		_in_flight.append([_tick, peer, 0, packet["bytes"], packet["bits"]])
	for packet in _joiner.take_outbound():
		_bytes_down[0] = int(_bytes_down.get(0, 0)) + (packet["bytes"] as PackedByteArray).size()
		_in_flight.append([_tick, 0, JOINER_PEER, packet["bytes"], packet["bits"]])
	for packet in _spectator.take_outbound():
		_in_flight.append([_tick, 0, SPECTATOR_PEER, packet["bytes"], packet["bits"]])
	var still_flying: Array = []
	for entry in _in_flight:
		if int(entry[0]) > _tick:
			still_flying.append(entry)
			continue
		match int(entry[1]):
			0:
				_server.deliver(int(entry[2]), entry[3], entry[4])
			JOINER_PEER:
				_joiner.deliver(0, entry[3], entry[4])
			SPECTATOR_PEER:
				_spectator.deliver(0, entry[3], entry[4])
	_in_flight = still_flying


func _teardown() -> void:
	for world in [_joiner, _spectator, _server]:
		if world != null:
			world.teardown()
	_joiner = null
	_spectator = null
	_server = null
	_in_flight.clear()


func _finish() -> void:
	_teardown()
	Sim.fit_channels(TOMCAT, [])
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
