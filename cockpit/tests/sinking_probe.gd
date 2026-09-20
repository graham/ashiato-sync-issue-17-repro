extends Node
## WHY DO THE AEROPLANES END UP ON THE GROUND? A probe, not a suite.
##
##   Godot --headless --fixed-fps 120 --path cockpit res://tests/sinking_probe.tscn [-- --still] [-- --seconds=180]
##
## The real sky level with its whole fleet, left alone for three simulated minutes, and every
## autopilot aeroplane logged once a second: kind, height over whatever is under it, airspeed,
## vertical speed, angle of attack, pitch, bank, throttle, gear, and what the autopilot is
## after. Reported by the user on 2026-09-14 as "planes still seem to end up on the ground after
## a minute, all types", and this is the measurement taken before anything was retuned.
##
## THE COMMANDED CLIMB IS INFERRED, not read: the mixer does not publish it. It is the altitude
## loop's own arithmetic -- 0.45 per metre of error, clamped to the kind's climb limit scaled by
## airspeed over stall -- against the waypoint's height, or the slot's for a follower, or the
## recovery height for a machine with no route.
##
## `--still` zeroes the wind after the level has built, so a run with and without it says
## whether the wind is any part of it.

const WINGED: Array[int] = [Sim.Kind.PLANE, Sim.Kind.AIRLINER, Sim.Kind.OSPREY, Sim.Kind.CESSNA,
	Sim.Kind.GUNSHIP, Sim.Kind.TANKER, Sim.Kind.GLIDER]
## The mixer's per-kind climb limits, copied for the INFERENCE only (fly_it_like_a).
const CLIMB_LIMIT: Dictionary = {Sim.Kind.AIRLINER: 12.0, Sim.Kind.PLANE: 30.0, Sim.Kind.OSPREY: 22.0}
const CELL: float = 400.0

var _level: Node = null
var _cells: Dictionary = {}
var _craft: Dictionary = {}   # entity -> {kind, stall, rows: Array}
var _seconds: int = 180


func _ready() -> void:
	# `--seed=N` moves the added machines -- which waypoint each is launched from, which piece of open ground each is
	# put down on, which way each points -- and leaves the level's own traffic where it is. The 1.45 cruise floor found
	# the last tanker by moving routes, so one seed is one set of routes and a verdict wants several.
	var seed: int = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = int(arg.get_slice("=", 1))
		if arg.begins_with("--seed="):
			seed = int(arg.get_slice("=", 1))
	_level = load("res://world/sky.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	while not Sim.is_ready:
		await get_tree().physics_frame
	for i in range(10):
		await get_tree().physics_frame
	if OS.get_cmdline_user_args().has("--still"):
		Sim.set_wind(Vector3.ZERO, 0.0)
	print("[sink] wind at 0 m %s, at 500 m %s" % [Sim.server.wind(0.0), Sim.server.wind(500.0)])
	_file_the_ground()
	# ONE OF EVERY WING, twice: put into the air at its own cruise over the aeroplanes' pool, and
	# set down on open ground, so the take-off is measured as well as the cruise. The level's own
	# traffic is only light aeroplanes, airliners and helicopters.
	var origin: Dictionary = {}
	var ground: Array[Vector3] = Terrain.waypoints(Sim.Kind.CAR, BoxGrid.new(Terrain.boxes()))
	var n: int = 0
	for kind in WINGED:
		var up: Dictionary = Terrain.one_more(Sim.Kind.PLANE, 40 + n * 5 + seed * 13, BoxGrid.new(Terrain.boxes()))
		var cruise: float = float(Sim.server.handling(kind).get("cruise", 60.0))
		var aloft: int = Sim.spawn_ai_vehicle(kind, up["position"], float(up["yaw"]),
			Terrain.nose_from_yaw(float(up["yaw"])) * cruise)
		origin[aloft] = "air+"
		var spot: Vector3 = ground[(n * 11 + 3 + seed * 7) % ground.size()]
		spot.y = (Sim.server.kind_geometry(kind)["extents"] as Vector3).y + 0.3
		var parked: int = Sim.spawn_ai_vehicle(kind, spot, TAU * (float(n) + float(seed) * 0.37) / 7.0, Vector3.ZERO)
		origin[parked] = "gnd+"
		n += 1
	for i in range(3):
		await get_tree().physics_frame
	for state in Sim.server.vehicle_states():
		var kind: int = int(state["kind"])
		var entity: int = int(state["entity"])
		if not (WINGED.has(kind) or kind == Sim.Kind.HELI):
			continue
		if (Sim.server.ai_destination(entity) as Dictionary).is_empty():
			continue
		var handling: Dictionary = Sim.server.handling(kind)
		var geometry: Dictionary = Sim.server.kind_geometry(kind)
		var carry: float = maxf(float(handling["camber"]) * float(handling["lift"]), 0.01)
		var peak: float = maxf(float(handling["stall_angle"]) * float(handling["lift"]), 0.01)
		_craft[entity] = {"kind": kind, "name": "%s%s" % [geometry["name"], origin.get(entity, "")],
			"stall": sqrt(float(geometry["mass"]) * 9.81 / carry) if WINGED.has(kind) else 0.0,
			"true_stall": sqrt(float(geometry["mass"]) * 9.81 / peak) if WINGED.has(kind) else 0.0,
			"cruise": float(handling.get("cruise", 0.0)), "hy": (geometry["extents"] as Vector3).y,
			"thrust_weight": float(handling["thrust"]) / (float(geometry["mass"]) * 9.81),
			"ground_speed": float(handling["ground_speed"]), "rows": []}
	print("[sink] %d autopilot aircraft" % _craft.size())
	for second in range(_seconds + 1):
		_sample(second)
		for i in range(int(round(Sim.tick_hz))):
			await get_tree().physics_frame
	_report()
	print("RESULT=PASS")
	get_tree().quit(0)


func _file_the_ground() -> void:
	for box in Terrain.boxes():
		var at: Vector3 = box["position"]
		var half: Vector3 = box["half_extents"]
		for cx in range(floori((at.x - half.x) / CELL), floori((at.x + half.x) / CELL) + 1):
			for cz in range(floori((at.z - half.z) / CELL), floori((at.z + half.z) / CELL) + 1):
				var key := Vector2i(cx, cz)
				if not _cells.has(key):
					_cells[key] = []
				(_cells[key] as Array).append(box)


func _ground_under(at: Vector3) -> float:
	var top: float = 0.0
	for box in _cells.get(Vector2i(floori(at.x / CELL), floori(at.z / CELL)), []):
		var p: Vector3 = box["position"]
		var h: Vector3 = box["half_extents"]
		if absf(at.x - p.x) <= h.x and absf(at.z - p.z) <= h.z and p.y + h.y <= at.y + 2.0:
			top = maxf(top, p.y + h.y)
	return top


func _sample(second: int) -> void:
	for entity in _craft.keys():
		var c: Dictionary = _craft[entity]
		var s: Dictionary = Sim.server.vehicle_state(entity)
		if s.is_empty():
			continue
		var at: Vector3 = s["position"]
		var basis := Basis(s["basis"] as Quaternion)
		var forward: Vector3 = basis * Vector3.FORWARD
		var up: Vector3 = basis * Vector3.UP
		var flow: Vector3 = (s["velocity"] as Vector3) - (Sim.server.wind(at.y) as Vector3)
		var along: float = flow.dot(forward)
		var aoa: float = atan2(-flow.dot(up), maxf(along, 0.1))
		var pitch: float = asin(clampf(forward.y, -1.0, 1.0))
		var right: Vector3 = basis * Vector3.RIGHT
		var bank: float = atan2(-right.y, maxf(up.y, 0.05))
		var agl: float = at.y - _ground_under(at)
		var dest: Dictionary = Sim.server.ai_destination(entity)
		var levers: Dictionary = Sim.server.craft_controls(entity)
		var following: bool = bool(dest.get("following", false))
		var want: float = 520.0
		var state: String = "recover"
		if following:
			var lead: Dictionary = Sim.server.vehicle_state(int(dest["leader"]))
			want = ((lead.get("position", at) as Vector3).y + (dest["slot"] as Vector3).y)
			state = "follow"
		elif bool(dest.get("has_route", false)):
			want = (dest["waypoint"] as Vector3).y
			state = "leg"
		var speed: float = flow.length()
		if agl < float(c["hy"]) + 4.0 and speed < float(c["ground_speed"]):
			state = "ground"
		var limit: float = float(CLIMB_LIMIT.get(int(c["kind"]), 30.0)) * (1.6 if following else 1.0)
		var able: float = clampf(speed / maxf(float(c["stall"]), 1.0), 0.2, 1.0)
		var cmd: float = clampf(0.45 * (want - at.y), -limit * able, limit * able)
		var row := {"t": second, "agl": agl, "y": at.y, "spd": along, "vs": (s["velocity"] as Vector3).y,
			"aoa": rad_to_deg(aoa), "pitch": rad_to_deg(pitch), "bank": rad_to_deg(bank),
			"thr": float(levers.get("throttle", 0.0)), "gear": bool(levers.get("gear", false)),
			"state": state, "want": want, "cmd": cmd}
		(c["rows"] as Array).append(row)
		print("[sink] t=%3d %5d %-9s agl=%6.0f y=%6.0f spd=%5.1f st=%4.1f vs=%6.1f aoa=%5.1f pitch=%5.1f bank=%5.1f thr=%.2f gear=%d %-7s want=%5.0f cmd=%5.1f"
			% [second, entity, c["name"], agl, at.y, along, c["stall"], row["vs"], row["aoa"], row["pitch"],
				row["bank"], row["thr"], 1 if row["gear"] else 0, state, want, cmd])


func _report() -> void:
	var by_kind: Dictionary = {}
	for entity in _craft.keys():
		var c: Dictionary = _craft[entity]
		var rows: Array = c["rows"]
		if rows.is_empty():
			continue
		var low_at: int = -1
		var min_agl: float = INF
		var slow: int = 0
		var full: int = 0
		var steep: int = 0
		var stalled_aoa: int = 0
		var top_climb: float = 0.0
		var top_pitch: float = 0.0
		var slowest_climbing: float = INF
		var strike: int = -1
		var previous: Dictionary = {}
		for row in rows:
			top_climb = maxf(top_climb, row["vs"])
			top_pitch = maxf(top_pitch, row["pitch"])
			if row["vs"] > 2.0 and row["state"] != "ground":
				slowest_climbing = minf(slowest_climbing, row["spd"])
			# A STRIKE: forty metres a second gone in one second, which no wing and no brake does.
			if strike < 0 and not previous.is_empty() and previous["spd"] - row["spd"] > 40.0:
				strike = row["t"]
			previous = row
			min_agl = minf(min_agl, row["agl"])
			if low_at < 0 and row["agl"] < 30.0 and row["state"] != "ground":
				low_at = row["t"]
			if WINGED.has(int(c["kind"])) and row["spd"] < float(c["stall"]) * 1.1:
				slow += 1
			if row["thr"] > 0.98:
				full += 1
			if row["pitch"] > 15.0:
				steep += 1
			if absf(row["aoa"]) > 14.0:
				stalled_aoa += 1
		var last: Dictionary = rows[rows.size() - 1]
		var line: String = "[sink] END %5d %-13s start_y=%5.0f end_agl=%6.0f min_agl=%6.0f low_at=%4d strike=%4d slow=%3ds full_thr=%3ds pitch>15=%3ds aoa>14=%3ds top_climb=%5.1f top_pitch=%5.1f slowest_climbing=%5.1f end_state=%s end_spd=%.1f level_stall=%.1f true_stall=%.1f cruise=%.1f t/w=%.2f" % [
			entity, c["name"], rows[0]["y"], last["agl"], min_agl, low_at, strike, slow, full, steep, stalled_aoa,
			top_climb, top_pitch, slowest_climbing, last["state"], last["spd"], c["stall"], c["true_stall"],
			c["cruise"], c["thrust_weight"]]
		print(line)
		if low_at >= 0:
			for row in rows:
				if row["t"] >= low_at - 20 and row["t"] <= low_at and (int(row["t"]) - low_at) % 4 == 0:
					print("[sink]   before %5d t=%3d agl=%5.0f spd=%5.1f vs=%6.1f aoa=%5.1f pitch=%5.1f bank=%5.1f thr=%.2f gear=%d %s want=%.0f cmd=%.1f" % [
						entity, row["t"], row["agl"], row["spd"], row["vs"], row["aoa"], row["pitch"], row["bank"],
						row["thr"], 1 if row["gear"] else 0, row["state"], row["want"], row["cmd"]])
		var name: String = c["name"]
		if not by_kind.has(name):
			by_kind[name] = {"n": 0, "low": 0, "end_ground": 0}
		by_kind[name]["n"] += 1
		if low_at >= 0:
			by_kind[name]["low"] += 1
		if last["agl"] < 30.0:
			by_kind[name]["end_ground"] += 1
	for name in by_kind.keys():
		print("[sink] KIND %-9s %d aircraft, %d went below 30 m AGL, %d ended below 30 m" % [
			name, by_kind[name]["n"], by_kind[name]["low"], by_kind[name]["end_ground"]])
