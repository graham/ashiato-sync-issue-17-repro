extends Node
## PROBE: what a joined machine's craft steps are made of.
##
##   Godot --headless --path cockpit res://tests/net_jump.tscn -- --role=host [--trace] [--no-missile]
##   Godot --headless --path cockpit res://tests/net_jump.tscn -- --role=join [--trace] [--no-missile]
##
## Built on cockpit-hitjump's hit_jump_net. Two processes over ENet on the loopback, through `Net.host` and
## `Net.join` and the real level. The host puts three launcher-and-target pairs up and fires a seeker in each; the
## joiner records every craft in `Sim.current` each tick.
##
## What this adds: the SAME step count taken on the host's own server truth, so a step that is in the simulation is
## told from one the wire made; per joiner tick, how many physics ticks Godot ran in that process frame, so Godot's
## own frame pacing is told from sync's; and with --trace, sync's own events -- which craft the joiner's buffered
## clock found no frame for (`buffered_starved`), which frames it applied, and how often the server sent each craft
## -- so every step is put against whether the craft had a frame to be drawn from.
##
## Read RESULT=, not the exit code.

## 47931 of this checkout's block (`TestPorts`). Both roles work it out alike -- `of`, not `first_free`, because the
## joiner starts while the host holds it -- and the host asks first whether anything else does.
static var PORT: int = TestPorts.of(47931)
const PLANE: int = Sim.Kind.PLANE
const ROUNDS: int = 3
const JOIN_SECONDS: float = 60.0
## The joiner's "I am watching" marker, in the user directory both processes share on one machine -- and every other
## checkout's processes too, so it is this checkout's own.
static var WATCHING: String = TestPorts.log_for("net_jump", "joiner_watching")

var _role: String = "host"
var _trace: bool = false
var _recording: bool = false
## Every tick: entity -> [position, velocity]. The joiner's is `Sim.current`; the host's is its server's truth.
var _rows: Array = []
## Joiner: physics ticks Godot ran in the process frame this tick belonged to.
var _ticks_in_frame: PackedInt32Array = []
var _physics_since_process: int = 0
var _frame_ticks: int = 0
## Joiner, --trace: per tick, the entities starved on it and the buffered frames applied on it.
var _starved: Array = []
var _applied_frames: Array = []
var _event_types: Dictionary = {}
var _event_examples: Dictionary = {}
## Host, --trace: server entity -> frames it was sent to the joiner on.
var _sent_frames: Dictionary = {}
## Host, --trace: component name -> bits sent, and how many times. What fills the budget.
var _sent_bits: Dictionary = {}
var _sent_count: Dictionary = {}
## Missiles, as the joiner saw them.
var _missiles_seen: Dictionary = {}
var _ends_seen: Dictionary = {}
var _lags: PackedInt32Array = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.substr(7)
	_trace = "--trace" in OS.get_cmdline_user_args()
	# BEFORE the level starts the simulation: a tracer is attached as the client is built.
	Sim.tracing = _trace
	if _role == "host":
		# A MARKER LEFT BY AN EARLIER RUN would tell this host the joiner is already watching.
		if FileAccess.file_exists(WATCHING):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(WATCHING))
		if TestPorts.is_held(PORT):
			_finish("FAIL %s" % TestPorts.busy(47931))
			return
		Net.host(PORT)
		if not Net.is_in_session:
			_finish("FAIL host could not listen on %d" % PORT)
			return
	else:
		var since: int = Time.get_ticks_msec()
		while not Net.is_in_session:
			if Time.get_ticks_msec() - since > 30000:
				_finish("FAIL no answer from the host")
				return
			Net.join("127.0.0.1", PORT)
			var knocked: int = Time.get_ticks_msec()
			while not Net.is_in_session and Time.get_ticks_msec() - knocked < 1500:
				await get_tree().process_frame
			if not Net.is_in_session:
				Net.leave("knocking again")
	var level: Node = load("res://world/sky.tscn").instantiate()
	get_tree().root.add_child.call_deferred(level)
	await _frames(240)
	print("[net] %s in session, peer %d, tracing %s, windowed %s" % [_role, Net.my_peer_id(), _trace,
		DisplayServer.get_name() != "headless"])
	if _role == "host":
		await _host()
	else:
		await _join()


func _process(_delta: float) -> void:
	_frame_ticks = _physics_since_process
	_physics_since_process = 0


func _host() -> void:
	var joiner: Dictionary = {}
	for i in range(3600):
		for pilot in Sim.server.pilot_states():
			if int((pilot as Dictionary).get("client", -1)) != Sim.local_client_id() \
					and int((pilot as Dictionary).get("vehicle", 0)) != 0:
				joiner = pilot
		if not joiner.is_empty():
			break
		await get_tree().physics_frame
	if joiner.is_empty():
		_finish("FAIL nobody joined")
		return
	_recording = true
	# NOT BEFORE THE JOINER IS WATCHING. The host sees the joiner's pilot within the joiner's first frames, but the
	# joiner records only once its level has grown and its clock is ready -- 240 frames, a ready check and 120 more,
	# stalling under load -- and a fixed wait here was a guess that a loaded machine could lose. So the joiner leaves a
	# marker in the user directory the two processes share on its first recorded tick, and the rounds wait for it.
	var asked: int = Time.get_ticks_msec()
	while not FileAccess.file_exists(WATCHING):
		if Time.get_ticks_msec() - asked > 120000:
			_finish("FAIL the joiner never started watching")
			return
		await get_tree().physics_frame
	print("[net] host: the joiner is watching at %.3f s" % Time.get_unix_time_from_system())
	await _seconds(3.0)
	for round in range(ROUNDS):
		var under: Vector3 = Sim.server.vehicle_state(int(joiner["vehicle"])).get("position", Vector3.ZERO)
		var nose := Vector3(1.0, 0.0, 0.0)
		var yaw: float = atan2(-nose.x, -nose.z)
		var start: Vector3 = under + Vector3(-900.0, 250.0, -300.0)
		var launcher: int = int(Sim.server.spawn_ai_vehicle(PLANE, start, yaw, nose * 120.0))
		var target: int = int(Sim.server.spawn_ai_vehicle(PLANE, start + nose * 700.0, yaw, nose * 120.0))
		await _seconds(2.0)
		var missile: int = 0
		if not ("--no-missile" in OS.get_cmdline_user_args()):
			missile = int(Sim.server.launch_missile(launcher, 0, target))
		var launched_at: float = Time.get_unix_time_from_system()
		var ended_at: float = 0.0
		var ended: String = "still flying after 8 s"
		var t: float = 0.0
		while t < 8.0:
			await get_tree().physics_frame
			t += Sim.tick_dt()
			if ended != "still flying after 8 s":
				continue
			for row in Sim.server.missile_states():
				if int((row as Dictionary)["entity"]) == missile and not bool((row as Dictionary)["flying"]):
					ended = "ended at %.2f s, surface %d" % [t, int((row as Dictionary)["surface"])]
					ended_at = Time.get_unix_time_from_system()
		# WALL-CLOCK SECONDS, which both processes on one machine share, so a round can be put against the joiner's
		# recording window.
		print("[net] host round %d: missile %d %s; launched at %.3f s, ended at %.3f s" % [round, missile, ended,
			launched_at, ended_at])
		Sim.server.despawn_vehicle(launcher)
		Sim.server.despawn_vehicle(target)
		await _seconds(1.0)
	await _seconds(4.0)
	_recording = false
	# OUTLIVE THE JOINER, which records for JOIN_SECONDS from when its level loaded: a host that quits first ends the
	# joiner's session under it.
	await _seconds(JOIN_SECONDS - 30.0)
	print("[net] host: server out %.1f kB/s, %d craft" % [float(Sim.server.net_status().get("bytes_out_per_second", 0)) / 1000.0,
		Sim.server.vehicle_states().size()])
	print("[net] host: socket sent [packets, bytes, largest] per peer %s, received %s" % [Net.sent, Net.received])
	_summarise_enet()
	_summarise("host truth", Sim.tick_dt())
	if _trace:
		_summarise_sends()
		_print_missile_trace("host")
	_finish("PASS host launched %d rounds" % ROUNDS)


func _join() -> void:
	# A JOINED MACHINE'S SIMULATION ARRIVES LATE: `Net.is_in_session` comes first and the client some seconds after,
	# once the level has been told the session is ready and sync has handshaken. Recording before it is nothing.
	var waited: int = 0
	while not (Sim.client != null and Sim.is_ready):
		waited += 1
		if waited > 120 * 60:
			_finish("FAIL the joiner's simulation never became ready")
			return
		await get_tree().physics_frame
	await _frames(120)
	_recording = true
	var watching: FileAccess = FileAccess.open(WATCHING, FileAccess.WRITE)
	if watching != null:
		watching.store_string("%.3f" % Time.get_unix_time_from_system())
		watching.close()
	var watch_began: float = Time.get_unix_time_from_system()
	# WHAT ARRIVED WHILE RECORDING, from the host, against how many ticks that was: the server sends each client one
	# packet a tick while its budget is under a packet, so the two should be close on a link that loses nothing.
	var received_at_start: int = int((Net.received.get(1, [0, 0, 0]) as Array)[0])
	var bytes_at_start: int = int((Net.received.get(1, [0, 0, 0]) as Array)[1])
	var ticks_at_start: int = Engine.get_physics_frames()
	var t: float = 0.0
	# UNTIL THE HOST LEAVES, at the latest: a joiner whose session has ended has no client to read, and rows recorded
	# after that are an empty sky, not a measurement.
	while t < JOIN_SECONDS and Sim.client != null and Net.is_in_session:
		await get_tree().physics_frame
		t += Sim.tick_dt()
	_recording = false
	print("[net] joiner: recorded from %.3f s to %.3f s" % [watch_began, Time.get_unix_time_from_system()])
	if Sim.client == null:
		_finish("FAIL the session ended before the joiner had recorded %.0f s" % JOIN_SECONDS)
		return
	var timing: Dictionary = Sim.client.timing()
	print("[net] joiner: timing %s" % timing)
	print("[net] joiner: socket received [packets, bytes, largest] per peer %s, sent %s" % [Net.received, Net.sent])
	var from_host: Array = Net.received.get(1, [0, 0, 0])
	var ticks: int = Engine.get_physics_frames() - ticks_at_start
	print("[net] joiner: while recording, %d packets (%.1f kB/s) arrived from the host in %d ticks" % [
		int(from_host[0]) - received_at_start, (int(from_host[1]) - bytes_at_start) / 1000.0 / maxf(ticks * Sim.tick_dt(), 0.001),
		ticks])
	print("[net] joiner: %d missile(s) seen, %d end(s) seen %s" % [_missiles_seen.size(), _ends_seen.size(), _ends_seen.keys()])
	print("[net] joiner: most missiles at once: %d in the client, %d in Sim.missiles; client held one from recorded tick %d to %d of %d" % [
		_most_missiles_direct, _most_missiles_captured, _first_missile_tick, _last_missile_tick, _rows.size()])
	_summarise("joiner", Sim.tick_dt())
	var doubled: int = 0
	for n in _ticks_in_frame:
		if n >= 2:
			doubled += 1
	print("[net] joiner: %d of %d ticks ran in a process frame with 2+ physics ticks" % [doubled, _ticks_in_frame.size()])
	if _trace:
		print("[net] joiner: trace event types %s, dropped %d" % [_event_types, int(Sim.client.trace_events_dropped())])
		for kind in _event_examples:
			print("[net]   e.g. %s: %s" % [kind, _event_examples[kind]])
		_print_missile_trace("joiner")
		print("[net] joiner: refused server updates by reason %s" % _refused)
		for example in _refused_examples:
			print("[net]   refused: %s" % example)
	_finish("PASS joiner recorded %d ticks" % _rows.size())


## Host: ENet's view of each joiner, sampled once a second while recording -- [throttle, packet loss, round trip]
## per sample. The throttle is the probability ENet SENDS an unreliable packet at all (ENetPacketPeer docs), so a
## throttle below PACKET_THROTTLE_SCALE is ENet dropping sync's packets on purpose.
var _enet_samples: Array = []
## --trace: "type role entity" -> [events, first frame, last frame], for MissileState and destroys.
var _missile_trace: Dictionary = {}
## entity -> kind, the last seen, so a blink can say what sort of craft it was.
var _kinds: Dictionary = {}
## Joiner: the most missiles the client's own missile_states() held on one tick, the most `Sim.missiles` held, and the
## first and last recorded tick the client held any.
var _most_missiles_direct: int = 0
var _most_missiles_captured: int = 0
var _first_missile_tick: int = -1
var _last_missile_tick: int = -1
## Joiner, --trace on a library that logs packets: refused server updates, reason -> count, and the first few whole.
var _refused: Dictionary = {}
var _refused_examples: PackedStringArray = []


func _print_missile_trace(who: String) -> void:
	var keys: Array = _missile_trace.keys()
	keys.sort()
	print("[net] %s: %d missile trace rows" % [who, keys.size()])
	for key in keys:
		var row: Array = _missile_trace[key]
		if String(key).begins_with("entity_destroyed") and int(row[0]) == 0:
			continue
		print("[net]   %s: %d events, frames %d..%d" % [key, int(row[0]), int(row[1]), int(row[2])])


func _sample_enet() -> void:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if not (peer is ENetMultiplayerPeer):
		return
	for id in multiplayer.get_peers():
		var packet_peer: ENetPacketPeer = (peer as ENetMultiplayerPeer).get_peer(id)
		if packet_peer == null:
			continue
		_enet_samples.append([packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE),
			packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS),
			packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)])


func _summarise_enet() -> void:
	if _enet_samples.is_empty():
		print("[net] host: no ENet samples")
		return
	var lowest: float = INF
	var total: float = 0.0
	var below: int = 0
	var worst_loss: float = 0.0
	var worst_rtt: float = 0.0
	for sample in _enet_samples:
		lowest = minf(lowest, float(sample[0]))
		total += float(sample[0])
		if float(sample[0]) < ENetPacketPeer.PACKET_THROTTLE_SCALE:
			below += 1
		worst_loss = maxf(worst_loss, float(sample[1]))
		worst_rtt = maxf(worst_rtt, float(sample[2]))
	print("[net] host: ENet throttle toward the joiner lowest %.0f, mean %.1f of %d; below full on %d of %d samples; worst reliable loss %.0f (of %d), worst round trip %.0f ms" % [
		lowest, total / _enet_samples.size(), ENetPacketPeer.PACKET_THROTTLE_SCALE, below, _enet_samples.size(),
		worst_loss, ENetPacketPeer.PACKET_LOSS_SCALE, worst_rtt])


func _physics_process(_delta: float) -> void:
	_physics_since_process += 1
	if _recording and _role == "host" and Engine.get_physics_frames() % 120 == 0:
		_sample_enet()
	if not _recording or Sim.client == null:
		return
	var row: Dictionary = {}
	var states: Array = Sim.server.vehicle_states() if _role == "host" else Sim.current.values()
	for state in states:
		row[int((state as Dictionary)["entity"])] = [(state as Dictionary)["position"], (state as Dictionary)["velocity"]]
		_kinds[int((state as Dictionary)["entity"])] = int((state as Dictionary).get("kind", -1))
	_rows.append(row)
	_ticks_in_frame.append(maxi(_frame_ticks, _physics_since_process))
	_lags.append(int(Sim.client.timing().get("buffer_frames", -1)) if Sim.client != null else -1)
	if _role == "join":
		for missile in Sim.missiles:
			var entity: int = int((missile as Dictionary)["entity"])
			_missiles_seen[entity] = true
			if not bool((missile as Dictionary).get("flying", true)):
				_ends_seen[entity] = true
		# THE CLIENT ITSELF, not the level's copy: a missile in the client's registry that `Sim.missiles` never held is
		# a capture problem, and one the client never had is a delivery one.
		var direct: int = (Sim.client.missile_states() as Array).size() if Sim.client.has_method("missile_states") else -1
		_most_missiles_direct = maxi(_most_missiles_direct, direct)
		_most_missiles_captured = maxi(_most_missiles_captured, Sim.missiles.size())
		if direct > 0:
			if _first_missile_tick < 0:
				_first_missile_tick = _rows.size()
			_last_missile_tick = _rows.size()
	if _trace:
		_drain_trace()


func _drain_trace() -> void:
	var starved: Dictionary = {}
	var applied: Dictionary = {}
	var worlds: Array = [Sim.client] if _role == "join" else [Sim.server]
	for world in worlds:
		for event in world.take_trace_events():
			var kind: String = (event as Dictionary)["type"]
			_event_types[kind] = int(_event_types.get(kind, 0)) + 1
			if not _event_examples.has(kind):
				_event_examples[kind] = event
			# EVERY MISSILE EVENT, on either machine: which missile records the server sent to whom, which the joiner
			# received and applied, and which entities it destroyed -- so a missile a joined machine never drew is
			# found either never sent, sent and not received, or received and not applied.
			if String(event.get("component", "")) == "MissileState" or kind == "entity_destroyed":
				var key: String = "%s %s %d" % [kind, event.get("role", ""), int(event["entity"])]
				var row: Array = _missile_trace.get(key, [0, int(event["frame"]), int(event["frame"])])
				_missile_trace[key] = [int(row[0]) + 1, mini(int(row[1]), int(event["frame"])),
					maxi(int(row[2]), int(event["frame"]))]
			# A SERVER UPDATE THE CLIENT REFUSED, with sync's reason, when the library logs packets.
			var detail: String = String(event.get("detail", ""))
			if detail.contains("message=server_update") and detail.contains("applied=false"):
				var reason: String = "unknown"
				var at: int = detail.find("apply_failure=")
				if at >= 0:
					reason = detail.substr(at + 14).get_slice(",", 0)
				_refused[reason] = int(_refused.get(reason, 0)) + 1
				if _refused_examples.size() < 5:
					_refused_examples.append(detail.left(240))
			match kind:
				"buffered_starved":
					starved[int(event["entity"])] = int(event["frame"])
				"component_applied":
					applied[int(event["frame"])] = true
				"component_sent":
					var component: String = event["component"]
					_sent_bits[component] = int(_sent_bits.get(component, 0)) + int(event["bits"])
					_sent_count[component] = int(_sent_count.get(component, 0)) + 1
					var sent: Dictionary = _sent_frames.get(int(event["entity"]), {})
					sent[int(event["frame"])] = true
					_sent_frames[int(event["entity"])] = sent
	_starved.append(starved)
	_applied_frames.append(applied.keys())


## LONE JUMP: one craft steps more than 2 m while at most one other steps more than 1 m. WORLD STEP: three or more
## craft over 0.5 m on one tick. With --trace on the joiner, each is put against starvation: was the craft starved on
## this tick or the one before, and how many frames did the clock apply on it.
func _summarise(who: String, dt: float) -> void:
	var craft_ticks: int = 0
	var lone: int = 0
	## Lone jumps on a craft barely moving -- parked, a tower, a deck -- against those on one flying, because the two
	## are different faults: a flying craft that holds then leaps is starvation, a parked one that steps tens of metres
	## and back in a tick is not.
	var lone_parked: int = 0
	var blinks: int = 0
	var worst: float = 0.0
	var world_steps: int = 0
	var steps_over_half: int = 0
	var starved_steps: int = 0
	var doubled_steps: int = 0
	var lone_starved: int = 0
	var lone_ratios: PackedFloat32Array = []
	for j in range(1, _rows.size()):
		var now_row: Dictionary = _rows[j]
		var was_row: Dictionary = _rows[j - 1]
		var steps: Dictionary = {}
		for entity in now_row:
			var off: float = _step_of(now_row, was_row, int(entity), dt)
			if off <= 50.0:
				steps[int(entity)] = off
		craft_ticks += steps.size()
		var over_half: int = 0
		var over_one: int = 0
		for entity in steps:
			if steps[entity] > 0.5:
				over_half += 1
				steps_over_half += 1
				if _ticks_in_frame.size() > j and _ticks_in_frame[j] >= 2:
					doubled_steps += 1
				if _starved.size() > j and ((_starved[j] as Dictionary).has(entity) \
						or (_starved[j - 1] as Dictionary).has(entity)):
					starved_steps += 1
			if steps[entity] > 1.0:
				over_one += 1
		if over_half >= 3:
			world_steps += 1
		for entity in steps:
			if steps[entity] > 2.0 and over_one - 1 <= 1:
				lone += 1
				worst = maxf(worst, steps[entity])
				var v: Vector3 = (now_row[entity] as Array)[1]
				if v.length() < 1.0:
					lone_parked += 1
					# A BLINK: the next tick puts it back within a metre of where it was before the jump. A craft
					# that really moved stays moved; one drawn somewhere wrong for a single tick does not.
					if j >= 1 and j + 1 < _rows.size() and (_rows[j + 1] as Dictionary).has(entity) \
							and (was_row as Dictionary).has(entity):
						var before: Vector3 = (was_row[entity] as Array)[0]
						var during: Vector3 = (now_row[entity] as Array)[0]
						var after: Vector3 = ((_rows[j + 1] as Dictionary)[entity] as Array)[0]
						if after.distance_to(before) < 1.0:
							blinks += 1
							if blinks <= 6:
								print("[net] %s: BLINK craft %d kind %d at tick %d: drawn %.2f m away at %s (offset %s), back next tick" % [
									who, entity, int(_kinds.get(entity, -1)), j, during.distance_to(before), before,
									during - before])
				lone_ratios.append(steps[entity] / maxf(v.length() * dt, 0.001))
				var held: int = 0
				for back in range(j, maxi(j - 80, 0), -1):
					if _starved.size() > back and (_starved[back] as Dictionary).has(entity):
						held += 1
					elif held > 0:
						break
				if held > 0:
					lone_starved += 1
				if lone <= 12:
					print("[net] %s: lone jump %.2f m on craft %d at tick %d = %.1f ticks of travel, starved %d tick(s) before, %d physics tick(s) in its frame" % [
						who, steps[entity], entity, j, lone_ratios[-1], held, _ticks_in_frame[j] if _ticks_in_frame.size() > j else -1])
	print("[net] %s: lone jumps > 2 m: %d in %d craft-ticks (%.2f per 1000), worst %.2f m, %d after starvation, %d on a craft slower than 1 m/s, %d of those blinks" % [
		who, lone, craft_ticks, 1000.0 * lone / maxf(craft_ticks, 1.0), worst, lone_starved, lone_parked, blinks])
	print("[net] %s: world steps %d of %d ticks; %d craft steps > 0.5 m, %d on a starved tick, %d in a doubled frame" % [
		who, world_steps, _rows.size() - 1, steps_over_half, starved_steps, doubled_steps])
	# THE PERIOD, if there is one: the gaps between successive world-step ticks.
	var gaps: Dictionary = {}
	var last: int = -1
	for j in range(1, _rows.size()):
		var count: int = 0
		for entity in _rows[j]:
			if _step_of(_rows[j], _rows[j - 1], int(entity), dt) > 0.5:
				count += 1
		if count >= 3:
			if last >= 0:
				gaps[j - last] = int(gaps.get(j - last, 0)) + 1
			last = j
	print("[net] %s: gaps between world steps (ticks: count) %s" % [who, gaps])
	# THE LAG, which moves the time every interpolated craft is drawn at: a world step on a tick the lag changed is the
	# clock, not a craft waiting for its record.
	var lag_changes: int = 0
	var steps_on_change: int = 0
	var world_ticks: int = 0
	for j in range(1, mini(_rows.size(), _lags.size())):
		var changed: bool = _lags[j] != _lags[j - 1] or (j >= 2 and _lags[j - 1] != _lags[j - 2])
		if _lags[j] != _lags[j - 1]:
			lag_changes += 1
		var count: int = 0
		for entity in _rows[j]:
			if _step_of(_rows[j], _rows[j - 1], int(entity), dt) > 0.5:
				count += 1
		if count >= 3:
			world_ticks += 1
			if changed:
				steps_on_change += 1
	if _lags.size() > 1:
		print("[net] %s: lag changed %d times (lowest %d, highest %d); %d of %d world steps on a lag change" % [who,
			lag_changes, Array(_lags).min(), Array(_lags).max(), steps_on_change, world_ticks])
	if _applied_frames.size() > 1:
		var per_tick: Dictionary = {}
		for frames in _applied_frames:
			per_tick[(frames as Array).size()] = int(per_tick.get((frames as Array).size(), 0)) + 1
		print("[net] %s: buffered frames applied per tick (frames: ticks) %s" % [who, per_tick])


func _summarise_sends() -> void:
	var gap_hist: Dictionary = {}
	for entity in _sent_frames:
		var frames: Array = (_sent_frames[entity] as Dictionary).keys()
		frames.sort()
		for i in range(1, frames.size()):
			var gap: int = mini(int(frames[i]) - int(frames[i - 1]), 20)
			gap_hist[gap] = int(gap_hist.get(gap, 0)) + 1
	print("[net] host: frames between sends of one entity (gap: count, 20 = 20+) %s" % gap_hist)
	var total: int = 0
	for component in _sent_bits:
		total += int(_sent_bits[component])
	var names: Array = _sent_bits.keys()
	names.sort_custom(func(a, b) -> bool: return int(_sent_bits[a]) > int(_sent_bits[b]))
	for component in names:
		print("[net] host: sent %-16s %9d bits (%4.1f%%) in %7d sends, %.1f bits each" % [component,
			int(_sent_bits[component]), 100.0 * int(_sent_bits[component]) / maxf(total, 1.0),
			int(_sent_count[component]), float(_sent_bits[component]) / maxf(int(_sent_count[component]), 1)])


func _step_of(now_row: Dictionary, was_row: Dictionary, entity: int, dt: float) -> float:
	var now: Array = now_row.get(entity, [])
	var was: Array = was_row.get(entity, [])
	if now.is_empty() or was.is_empty():
		return 0.0
	var expected: Vector3 = ((was[1] as Vector3) + (now[1] as Vector3)) * 0.5 * dt
	return ((now[0] as Vector3) - (was[0] as Vector3) - expected).length()


func _finish(verdict: String) -> void:
	print("RESULT=%s" % verdict)
	get_tree().quit(0 if verdict.begins_with("PASS") else 1)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += Sim.tick_dt()
