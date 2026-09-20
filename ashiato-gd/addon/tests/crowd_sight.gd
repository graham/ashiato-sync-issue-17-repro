extends Node
## A WATCHED SKY IS DRAWN WITHOUT A HOLD OR A LEAP, AND EVERY MISSILE IN IT ENDS WHERE A CLIENT CAN SEE.
##
##   Godot --path addon --headless res://tests/crowd_sight.tscn
##
## A client draws a craft it does not fly from sync's buffered timeline: one integer frame of the registry per tick,
## a few frames behind the server. When the frame a craft needs has not arrived, sync skips it and the craft HOLDS
## where it was, then catches up when the data lands. Under sync's 1024-byte budget and a sky full of traffic the
## server sent each craft only every few ticks, so a joined machine watched remote craft hold and leap (0.80 lone
## jumps per 1000 craft-ticks, worst 49 m, over ENet on the loopback). The same budget let a missile's last state go
## unsent: it was retired three ticks after it ended, and sync drops whatever it had not yet sent about an entity when
## it is destroyed.
##
## In ONE process with no socket and no real clock, so nothing here is Godot's frame pacing: eighty autopilots at
## cruise alongside the watcher, the game's settings (120 Hz, three frames of interpolation). An empty sky first as the
## control, then the crowd with packets carried the tick they are made, over a 4-tick link, and over that link with
## three gunships firing every mount. Measured on the library before the fix: green on the same tick; over the link
## 3,564 held-or-leaping steps; and 1 of 3 missile ends with the guns going. After the rounding and the half-second
## retire, at a true 1,024 bytes a tick, the link still held 3,840; at 245 kB/s it holds none.
##
## AND THE WIRE ROUNDING CHANGES NO BIT: every tick, every craft's components are written straight and through
## quantize and compared (`wire_rounding_check`). It caught a smallest-three quaternion tie on the crowd's one heading
## -- 52,511 of 291,600 components writing different bits -- and a deliberate break (position at twice the wire step,
## after the guard) turns it red with 48,255.
##
## A link that delivers in lumps is `crowd_lumpy`, a probe: it still steps the whole sky a tick at a time and the
## cause is not yet known (cockpit/agents.md, WHAT IS NOT HERE YET).
##
## A STEP is how far a craft moved in one tick beyond what its own velocity carried it. A craft flying straight
## steps millimetres; a held tick steps a whole tick of travel. So the thresholds are fractions of |v| * dt, the
## measured motion, never a number of metres typed beside it.
##
## Read RESULT=, not the exit code.

const HZ: float = 120.0
const PEER: int = 1
const PLANE: int = 1
## Matching kKindGunship, and kMaxTurrets: every mount a craft can have, fitted or not.
const GUNSHIP: int = 15
const MOUNTS: int = 3
const CROWD: int = 80
const CRUISE: float = 120.0
## A step bigger than this fraction of a tick of the craft's own travel is a hold or a leap. A tick of quantised
## position and a turning autopilot are far inside it.
const STEP_OF_A_TICK: float = 0.25
## Metres under which a step is quantisation, for a craft barely moving.
const STEP_FLOOR: float = 0.05
const WATCH_TICKS: int = 1200
const MISSILES: int = 3

var _failures: PackedStringArray = []
var server
var client
var _tick: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[sight] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


## The skies, as [name, crowd, link ticks, bunch, gunships firing]. A probe that wants other skies overrides this.
func _plans() -> Array:
	return [["an_empty_sky", 0, 0, 1, 0], ["a_crowded_sky", CROWD, 0, 1, 0],
		["a_crowded_sky_over_a_link", CROWD, 4, 1, 0], ["a_crowded_sky_under_fire_over_a_link", CROWD, 4, 1, 3]]


## The link: each packet is due `_link` ticks after it is made, and with `_bunch` above 1 it is held until the next
## tick that is a multiple of `_bunch`, so arrivals come in lumps the way a real socket delivers them.
var _link: int = 0
var _bunch: int = 1
var _in_flight: Array = []


func _advance(ticks: int) -> void:
	for i in range(ticks):
		_tick += 1
		server.tick(1.0 / HZ)
		client.tick(1.0 / HZ)
		for packet in server.take_outbound():
			_in_flight.append([_due(), 1, packet["bytes"], packet["bits"]])
		for packet in client.take_outbound():
			_in_flight.append([_due(), 0, packet["bytes"], packet["bits"]])
		var later: Array = []
		for entry in _in_flight:
			if int(entry[0]) > _tick:
				later.append(entry)
			elif int(entry[1]) == 1:
				client.deliver(0, entry[2], entry[3])
			else:
				server.deliver(PEER, entry[2], entry[3])
		_in_flight = later


## Every craft this sky spawned, so a launcher can be given something else in it to fire at.
var _spawned: Array = []


## A craft that is not the launcher, a few along the sky's list.
func _target_for(launcher: int) -> int:
	var at: int = _spawned.find(launcher)
	for step in range(1, _spawned.size()):
		var candidate: int = int(_spawned[(at + step * 5) % _spawned.size()])
		if candidate != launcher:
			return candidate
	return 0


func _due() -> int:
	var due: int = _tick + _link
	return ((due + _bunch - 1) / _bunch) * _bunch


## One sky of `crowd` autopilots. Returns what the client drew and which missile ends it saw.
func _fly(crowd: int, link: int, bunch: int, guns: int) -> Dictionary:
	_tick = 0
	_link = link
	_bunch = bunch
	_in_flight.clear()
	_spawned.clear()
	server = ClassDB.instantiate("CockpitWorld")
	client = ClassDB.instantiate("CockpitWorld")
	for world in [server, client]:
		world.set_tick_rate(HZ)
		for row in world.missile_types():
			# A SHORT LIFE, so every missile ends in the sky on its own and inside the watch.
			world.set_missile_type(int(row["id"]), {"life_s": 2.0, "rearm_s": 0.0})
	client.set_interpolation(3, true)
	server.start(0)
	client.start(PEER)
	# NO HIT POINTS AND NO CRASHES (lane/combat): this measures what the wire draws, and a missile that now destroys its
	# target freezes it, which the step count read as a hold -- one step of three ticks' travel on the kill's tick.
	if server.has_method("set_damage"):
		server.set_damage(false)
		server.set_crashes(false)
	var waited: int = 0
	while waited < int(HZ * 3.0) and not (int(client.local_client_id()) > 0 \
			and server.connected_clients().size() == 1):
		_advance(1)
		waited += 1
	var home := Vector3(-12000.0, 900.0, 12000.0)
	var nose := Vector3(1.0, 0.0, 0.0)
	var yaw: float = atan2(-nose.x, -nose.z)
	var launchers: Array = []
	for i in range(maxi(crowd, MISSILES)):
		var at: Vector3 = home + Vector3(float(i % 10) * 60.0, float(i / 10) * 40.0, float(i % 7) * 60.0)
		var craft: int = int(server.spawn_ai_vehicle(PLANE, at, yaw, nose * CRUISE))
		_spawned.append(craft)
		if launchers.size() < MISSILES:
			launchers.append(craft)
	# GUNSHIPS AT FULL RATE, every fitted mount, because rounds are the heaviest thing a busy sky adds to the wire and
	# a fix that holds only while nobody fires is not one (cockpit-guns: three door guns take a client from about 925
	# to 1018 bytes a tick).
	var gunships: Array = []
	for i in range(guns):
		gunships.append(int(server.spawn_ai_vehicle(GUNSHIP, home + Vector3(float(i) * 120.0, 300.0, -400.0), yaw,
			nose * CRUISE * 0.5)))
	server.spawn_pilot(int(client.local_client_id()), PLANE, home + Vector3(0.0, -200.0, 0.0), yaw, nose * CRUISE)
	_advance(int(HZ * 3.0))

	var rows: Array = []
	## The interpolation lag each tick: when it moves by a frame, the time every interpolated craft is drawn at moves
	## with it, and the whole sky steps a tick together.
	var lags: PackedInt32Array = []
	## The buffered frame the registry was applied at, each tick: it should move by exactly one.
	var clock_frames: PackedInt32Array = []
	var rounded_checked: int = 0
	var rounded_differ: int = 0
	var rounded_examples: int = 0
	var launched: int = 0
	var seen: Dictionary = {}
	var ended: Dictionary = {}
	for j in range(WATCH_TICKS):
		if j % 240 == 60 and launched < launchers.size():
			# AT A CRAFT, so the missile carries an entity reference the way a seeker's does.
			if int(server.launch_missile(int(launchers[launched]), 0, _target_for(launchers[launched]))) != 0:
				launched += 1
		for ship in gunships:
			for mount in range(MOUNTS):
				server.fire_gun(int(ship), mount)
		_advance(1)
		var rounding: Dictionary = server.wire_rounding_check()
		rounded_checked += int(rounding.get("checked", 0))
		rounded_differ += int(rounding.get("differ", 0))
		if int(rounding.get("differ", 0)) > 0 and rounded_examples < 3:
			rounded_examples += 1
			print("[sight] rounding differs: %s; %s" % [rounding.get("by_component", {}), rounding.get("example", "")])
		var timing: Dictionary = client.timing()
		lags.append(int(timing.get("buffer_frames", -1)))
		clock_frames.append(int(timing.get("buffered_frame", -1)))
		var row: Dictionary = {}
		for state in client.vehicle_states():
			if not bool(state["predicted"]):
				row[int(state["entity"])] = [state["position"], state["velocity"]]
		rows.append(row)
		for missile in client.missile_states():
			seen[int(missile["entity"])] = true
			if not bool(missile["flying"]):
				ended[int(missile["entity"])] = true
	var result: Dictionary = _steps(rows, 1.0 / HZ, lags, clock_frames)
	result["launched"] = launched
	result["rounded_checked"] = rounded_checked
	result["rounded_differ"] = rounded_differ
	result["seen"] = seen.size()
	result["ended"] = ended.size()
	result["out_kb_s"] = float(server.net_status().get("bytes_out_per_second", 0)) / 1000.0
	result["buffer"] = int(client.timing().get("buffer_frames", -1))
	client.teardown()
	server.teardown()
	return result


## HOLDS AND LEAPS. A lone step is one craft over the threshold; a common step is a tick on which three or more are.
## When there are common steps it also says whether they came on a tick the interpolation lag moved, or on one the
## buffered clock did not advance by exactly a frame, which are the two things that move the whole sky at once.
func _steps(rows: Array, dt: float, lags: PackedInt32Array, clock_frames: PackedInt32Array) -> Dictionary:
	var craft_ticks: int = 0
	var over: int = 0
	var common: int = 0
	var on_lag_change: int = 0
	var on_uneven_clock: int = 0
	var worst_ticks: float = 0.0
	var worst_any: float = 0.0
	for j in range(1, rows.size()):
		var now_row: Dictionary = rows[j]
		var was_row: Dictionary = rows[j - 1]
		var this_tick: int = 0
		for entity in now_row:
			if not was_row.has(entity):
				continue
			var now: Array = now_row[entity]
			var was: Array = was_row[entity]
			var carried: Vector3 = ((was[1] as Vector3) + (now[1] as Vector3)) * 0.5 * dt
			var step: float = ((now[0] as Vector3) - (was[0] as Vector3) - carried).length()
			craft_ticks += 1
			var travel: float = carried.length()
			worst_any = maxf(worst_any, step / maxf(travel, 0.001))
			if step > maxf(STEP_OF_A_TICK * travel, STEP_FLOOR):
				over += 1
				this_tick += 1
				worst_ticks = maxf(worst_ticks, step / maxf(travel, 0.001))
		if this_tick >= 3:
			common += 1
			if _moved(lags, j, 0):
				on_lag_change += 1
			if _moved(clock_frames, j, 1):
				on_uneven_clock += 1
	if common > 0:
		var lag_changes: int = 0
		var uneven: int = 0
		for j in range(1, lags.size()):
			if lags[j] != lags[j - 1]:
				lag_changes += 1
			if clock_frames[j] - clock_frames[j - 1] != 1:
				uneven += 1
		print("[sight] %d whole-sky steps: %d on a lag change (%d changes, lag %d..%d), %d on an uneven clock tick (%d of %d ticks)" % [
			common, on_lag_change, lag_changes, Array(lags).min(), Array(lags).max(), on_uneven_clock, uneven,
			clock_frames.size() - 1])
	return {"craft_ticks": craft_ticks, "over": over, "common": common, "worst_ticks": worst_ticks,
		"worst_any": worst_any}


## Whether a per-tick series moved by anything but `expected` on tick j or the one before it.
func _moved(series: PackedInt32Array, j: int, expected: int) -> bool:
	if j >= series.size():
		return false
	if series[j] - series[j - 1] != expected:
		return true
	return j >= 2 and series[j - 1] - series[j - 2] != expected


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("cockpit_world_is_registered", false, "build with -WithCockpit")
		_finish()
		return
	for plan in _plans():
		var sky: Dictionary = _fly(int(plan[1]), int(plan[2]), int(plan[3]), int(plan[4]))
		var name: String = plan[0]
		var detail: String = "%d steps over a quarter tick of travel in %d craft-ticks, worst %.2f ticks of travel (%.2f of any step); %.1f kB/s, buffer %d" % [
			int(sky["over"]), int(sky["craft_ticks"]), float(sky["worst_ticks"]), float(sky["worst_any"]),
			float(sky["out_kb_s"]), int(sky["buffer"])]
		_check("%s_draws_every_craft_without_a_hold_or_a_leap" % name, int(sky["over"]) == 0, detail)
		_check("%s_never_steps_the_whole_sky_at_once" % name, int(sky["common"]) == 0,
			"%d ticks on which three or more craft stepped" % int(sky["common"]))
		_check("%s_shows_every_launched_missile" % name,
			int(sky["launched"]) == MISSILES and int(sky["seen"]) == int(sky["launched"]),
			"%d launched, %d seen by the client" % [int(sky["launched"]), int(sky["seen"])])
		# THE ROUNDING CHANGES NO BIT ON THE WIRE: every craft's components written straight and through quantize, every
		# tick of the watch. Compared zero times is a failure, not a pass.
		_check("%s_rounds_no_bit_a_client_receives" % name,
			int(sky["rounded_checked"]) > 0 and int(sky["rounded_differ"]) == 0,
			"%d of %d components wrote different bits once rounded" % [int(sky["rounded_differ"]),
				int(sky["rounded_checked"])])
		_check("%s_hands_the_client_every_missile_end" % name, int(sky["ended"]) == int(sky["launched"]),
			"%d of %d ends seen with flying false" % [int(sky["ended"]), int(sky["launched"])])
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
