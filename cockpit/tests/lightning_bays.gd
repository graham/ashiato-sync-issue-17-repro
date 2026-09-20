extends Node
## Headless: THE F-35B'S WEAPONS BAYS AND ITS GUN POD, launched and fired through a seated pilot's own control frame -- the
## weapon selector and the master arm as bus commands, LOCK and LAUNCH as the buttons a rig sends, the trigger as its
## trigger -- in a world of its own with a light twin to shoot at. Read RESULT=.
##
##   Godot --headless --fixed-fps 120 --path cockpit res://tests/lightning_bays.tscn
##
## WHAT A BAY LAUNCH MUST DO, in the user's words ("the doors for gear, and missle launches are a bit difficult"), each
## held to the SERVER's own record tick by tick, never to a flag the code sets to say so:
## - THE DOORS OPEN BEFORE THE MISSILE MOVES: the bay's bit is set at least `LightningAirframe.BAY_SECONDS` before the
##   missile exists, the time the drawing takes to swing the doors open, so on every machine the doors are drawn open
##   first. No missile anywhere while the bay is shut.
## - THE MISSILE FALLS CLEAR OF THE HULL BEFORE ITS MOTOR LIGHTS: unlit on every tick until it is at least a metre under
##   the belly in the aeroplane's own frame, and lit after.
## - THE DOORS SHUT AFTER: the bit clears once the missile is away, and not before.
## - TWO IN A ROW: a second launch straight after takes the other bay's missile, and does all of the above too.
## And THE GUN: the GAU-22/A's rounds leave from the pod's muzzle the airframe draws (`LightningAirframe.gun_port()`),
## within 0.05 m across the bore, and the drum is the pod's 220.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 60
const BUTTON_LOCK: int = 1 << 6
const BUTTON_LAUNCH: int = 1 << 7
## HOW FAR UNDER THE BELLY A MISSILE MUST BE when its motor lights: a metre clear of the skin.
const CLEAR_OF_THE_BELLY: float = 1.0
const POD_ROUNDS: int = 220

var _world: Object = null
var _pilot: int = 0
var _craft: int = 0
var _target: int = 0
var _t: float = 0.0
var _seq: int = 0
var _input: Dictionary = {}
var _failures: PackedStringArray = []
var _frame: LightningAirframe = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lightning_bays] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	_frame = LightningAirframe.new()
	add_child(_frame)
	_frame.dress()
	_begin()
	# THE RADAR STATION, ARMED, LOCKED: the selector at 1, the master arm on, and LOCK pressed on the light twin ahead.
	_command(Sim.Channel.WEAPON, 1)
	_fly(0.3)
	_command(Sim.Channel.MASTER, 1)
	_fly(0.3)
	_press(BUTTON_LOCK)
	_fly(2.5)
	var record: Array = []
	_press(BUTTON_LAUNCH)
	_fly(0.75, record)
	# THE SECOND, straight after the first has left and the station's reload has run.
	_press(BUTTON_LAUNCH)
	_fly(6.0, record)
	_judge_the_launches(record)
	_the_gun_fires_from_the_drawn_pod()
	_end()
	_frame.queue_free()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)


## ---- the judgement ----------------------------------------------------------------------------------------------------

func _judge_the_launches(record: Array) -> void:
	# Per missile entity: the tick it first exists, the tick its motor lights, and its depth under the belly then.
	var bay_open_at: Array[float] = [-1.0, -1.0]
	var bay_shut_at: Array[float] = [-1.0, -1.0]
	var missiles: Dictionary = {}
	var early: PackedStringArray = []
	for tick in record:
		var bays: int = int(tick["bays"])
		for side in range(2):
			var open: bool = (bays >> side) & 1 == 1
			if open and bay_open_at[side] < 0.0:
				bay_open_at[side] = float(tick["t"])
			if not open and bay_open_at[side] >= 0.0 and bay_shut_at[side] < 0.0:
				bay_shut_at[side] = float(tick["t"])
		for m in tick["missiles"]:
			var id: int = int(m["entity"])
			var local: Vector3 = (tick["craft"] as Transform3D).affine_inverse() * (m["position"] as Vector3)
			if not missiles.has(id):
				missiles[id] = {"born": float(tick["t"]), "side": 0 if local.x > 0.0 else 1, "lit": -1.0, "depth": 0.0,
					"born_local": local}
			var one: Dictionary = missiles[id]
			if bool(m["motor"]) and float(one["lit"]) < 0.0:
				one["lit"] = float(tick["t"])
				one["depth"] = _belly_y() - local.y
			# A missile that exists while its bay's bit is clear came out of a shut bay.
			if (bays >> int(one["side"])) & 1 == 0 and float(one["lit"]) < 0.0:
				early.append("%d at %.2f" % [id, float(tick["t"])])
	var said: PackedStringArray = []
	var doors_first := true
	var clear := true
	var shut_after := true
	for id in missiles:
		var one: Dictionary = missiles[id]
		var side: int = int(one["side"])
		var waited: float = float(one["born"]) - bay_open_at[side] if bay_open_at[side] >= 0.0 else -1.0
		doors_first = doors_first and waited >= LightningAirframe.BAY_SECONDS - TICK * 1.5
		clear = clear and float(one["lit"]) > 0.0 and float(one["depth"]) >= CLEAR_OF_THE_BELLY
		shut_after = shut_after and bay_shut_at[side] > float(one["lit"])
		said.append("%s bay: open %.2f s before the missile moved, which fell %.2f m under the belly before its motor lit %.2f s after it left, the bay shut %.2f s after it left"
			% ["starboard" if side == 0 else "port", waited, float(one["depth"]), float(one["lit"]) - float(one["born"]),
				bay_shut_at[side] - float(one["born"]) if bay_shut_at[side] > 0.0 else -1.0])
	_check("the_doors_open_before_the_missile_moves", missiles.size() == 2 and doors_first and early.is_empty(),
		"%d missiles; %s; missiles seen while their bay was shut: %s" % [missiles.size(), "; ".join(said),
			"none" if early.is_empty() else ", ".join(early)])
	_check("the_missile_clears_the_hull_before_its_motor_lights", missiles.size() == 2 and clear,
		"at least %.1f m under the belly when it lights" % CLEAR_OF_THE_BELLY)
	_check("the_doors_shut_after", missiles.size() == 2 and shut_after, "each bay shut after its missile had lit")
	_check("two_in_a_row_from_both_bays", missiles.size() == 2 and bay_open_at[0] >= 0.0 and bay_open_at[1] >= 0.0,
		"starboard bay opened at %.2f s, port at %.2f s" % [bay_open_at[0], bay_open_at[1]])


## THE GUN: station 2, the trigger held a quarter of a second; every round's birth in the aeroplane's frame against the
## drawn pod's muzzle, and the drum.
func _the_gun_fires_from_the_drawn_pod() -> void:
	_command(Sim.Channel.WEAPON, 2)
	_fly(0.3)
	var muzzle: Vector3 = _frame.gun_port()
	var before: Dictionary = {}
	for s in _world.shot_states():
		before[int(s["entity"])] = true
	var worst: float = 0.0
	var born: int = 0
	var drum_full: int = int(_world.gun_rounds(_craft))
	_input["trigger"] = 1.0
	for i in range(30):
		# THE POSE THE ROUND WAS FIRED FROM is the one before the tick: after it, a jet sinking a few metres a second has
		# moved a tenth of a metre, which read as the muzzle being out by that much.
		var st: Dictionary = _world.vehicle_state(_craft)
		var craft := Transform3D(Basis(st["basis"] as Quaternion), st["position"] as Vector3)
		_fly(TICK)
		for s in _world.shot_states():
			var id: int = int(s["entity"])
			if before.has(id):
				continue
			before[id] = true
			born += 1
			var local: Vector3 = craft.affine_inverse() * (s["from"] as Vector3)
			var across: float = Vector2(local.x - muzzle.x, local.y - muzzle.y).length()
			worst = maxf(worst, across)
	_input["trigger"] = 0.0
	_fly(0.2)
	_check("the_gun_fires_from_the_drawn_pod", born > 0 and worst <= 0.05 and drum_full == POD_ROUNDS,
		"%d rounds in a quarter second, worst %.3f m across the bore from the pod's muzzle at %s; the drum held %d (the pod's %d)"
			% [born, worst, muzzle, drum_full, POD_ROUNDS])


## ---- the world and the hands -------------------------------------------------------------------------------------------

func _begin() -> void:
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(40000.0, 400.0, 40000.0))
	var made: Dictionary = _world.spawn_pilot(CLIENT, Sim.Kind.LIGHTNING, Vector3(0.0, 1500.0, 0.0), 0.0, Vector3(0.0, 0.0, -150.0))
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_target = int(_world.spawn_ai_vehicle(Sim.Kind.PLANE, Vector3(0.0, 1500.0, -1200.0), 0.0, Vector3(0.0, 0.0, -60.0)))
	_input = {"throttle": 0.6, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0, "buttons": 0, "trigger": 0.0}
	_command(Sim.Channel.GEAR, 0)


func _end() -> void:
	if _world != null:
		_world.teardown()
		_world = null


func _command(channel: int, value: int) -> void:
	_seq = _seq % 3 + 1
	_input["command_channel"] = channel
	_input["command_value"] = value
	_input["command_seq"] = _seq


## A BUTTON PRESSED FOR ONE TICK: an edge, as a rig's press is.
func _press(button: int) -> void:
	_input["buttons"] = button
	_fly(TICK)
	_input["buttons"] = 0


## FLY LEVEL for `seconds`, the nose held on the horizon and the wings level, recording each tick into `record` if given.
func _fly(seconds: float, record: Variant = null) -> void:
	var n: int = maxi(1, int(round(seconds / TICK)))
	for i in range(n):
		var st: Dictionary = _world.vehicle_state(_craft)
		var basis := Basis(st["basis"] as Quaternion)
		var nose: Vector3 = basis * Vector3.FORWARD
		var right: Vector3 = basis * Vector3.RIGHT
		var v: Vector3 = st["velocity"]
		_input["pitch"] = clampf((-rad_to_deg(asin(clampf(nose.y, -1.0, 1.0))) - v.y * 0.5) * 0.05, -1.0, 1.0)
		_input["roll"] = clampf(rad_to_deg(asin(clampf(right.y, -1.0, 1.0))) * 0.05, -1.0, 1.0)
		_world.set_pilot_input(_pilot, _input)
		_world.tick(TICK)
		_t += TICK
		if record != null:
			var after: Dictionary = _world.vehicle_state(_craft)
			var mine: Array = []
			for m in _world.missile_states():
				if int(m.get("client", -1)) == CLIENT:
					mine.append(m)
			(record as Array).append({"t": _t, "bays": int((_world.craft_systems(_craft) as Dictionary).get("bays", 0)),
				"craft": Transform3D(Basis(after["basis"] as Quaternion), after["position"] as Vector3), "missiles": mine})


## THE BELLY'S HEIGHT in the aeroplane's frame: the drawn datum, the side view's lowest point.
func _belly_y() -> float:
	return _frame.point(0.0, 0.0, 0.0).y
