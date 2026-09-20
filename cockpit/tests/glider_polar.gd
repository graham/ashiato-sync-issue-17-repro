extends Node
## THE SAILPLANE'S POLAR, MEASURED: how fast it sinks flying straight at each speed, and how fast it sinks -- and where it
## sits -- circling at each speed and circle. Headless, on the glider level, in the far corner where the level lays no
## thermal, so the only air moving is the wing's own.
##
##   Godot --headless --path cockpit res://tests/glider_polar.tscn
##
## A PROBE, NOT A SUITE: it prints a table and has no right answer. It exists because `SoaringPilot` and the glider level's
## thermals are sized from it (lane/gliderlevel, 2026-09-19), and because what it says is surprising:
##
##   straight, asked / flown m/s:  22 -> 2.69 m/s sink, 8.1:1;  25 -> 2.19, 11.4:1;  28 -> 1.81, 15.4:1;
##                                 31 -> 1.52, 20.3:1;  34 -> 1.34, 25.3:1;  40 -> 1.20, 33.3:1
##   circling, asked m/s and circle: 24 r90 -> 3.15 m/s sink, sitting 106 m out;  27 r110 -> 2.66, 129 m;
##                                 30 r140 -> 2.33, 191 m;  34 r140 -> 2.02, 291 m;  24 r140 -> 3.21, 141 m;
##                                 27 r160 -> 2.68, 163 m
##
## THIS GLIDER SINKS LESS THE FASTER IT FLIES, all the way to its cruise, which no sailplane does: a real one has a minimum
## sink somewhere near 1.3 times its stall and sinks harder either side of it. The cause is the handling table's
## `induced_drag` of 45, which swamps everything at low speed. It is the flight model's to fix, not this lane's:
## todo/gliderlevel--the-gliders-polar-is-backwards.md. Every number the glider level is built on comes from this table, so
## when that is fixed, run this again and the level's thermals and the pilot's circle follow it.
##
## Read the table; RESULT=PASS means it ran.

const STRAIGHT: Array[float] = [22.0, 25.0, 28.0, 31.0, 34.0, 40.0]
## speed, circle radius
const CIRCLES: Array[Vector2] = [Vector2(24.0, 90.0), Vector2(27.0, 110.0), Vector2(30.0, 140.0), Vector2(34.0, 140.0),
	Vector2(24.0, 140.0), Vector2(27.0, 160.0)]
const SETTLE_S: float = 25.0
const MEASURE_S: float = 40.0

var _level: FlightLevel = null


func _ready() -> void:
	Net.choose_level("gliders")
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	while _level.ground_built_msec < 0.0 or not Sim.is_ready:
		await get_tree().process_frame
	for i in range(30):
		await get_tree().process_frame
	print("PROBE cruise %.1f" % Terrain.cruise_for(Sim.Kind.GLIDER))
	var handling: Dictionary = Sim.client.handling(Sim.Kind.GLIDER)
	print("PROBE handling %s" % [handling])
	# FAR FROM EVERY THERMAL: the far corner of the flyable square, where the level lays none.
	var straight: Array = []
	for i in range(STRAIGHT.size()):
		var at := Vector3(-6500.0 + float(i) * 300.0, 2500.0, 6500.0)
		var e: int = Sim.spawn_ai_vehicle(Sim.Kind.GLIDER, at, 0.0, Vector3(0.0, 0.0, -STRAIGHT[i]))
		Sim.server.set_ai_manners(e, {"bank": 0.9})
		straight.append({"entity": e, "speed": STRAIGHT[i], "at": at})
	var circles: Array = []
	for i in range(CIRCLES.size()):
		var at := Vector3(6500.0, 2500.0, -6500.0 + float(i) * 400.0)
		var e: int = Sim.spawn_ai_vehicle(Sim.Kind.GLIDER, at, 0.0, Vector3(0.0, 0.0, -CIRCLES[i].x))
		Sim.server.set_ai_manners(e, {"bank": 0.9})
		circles.append({"entity": e, "speed": CIRCLES[i].x, "radius": CIRCLES[i].y, "middle": at})
	var hz: int = Engine.physics_ticks_per_second
	var ticks: int = 0
	var marks: Dictionary = {}
	while ticks < int((SETTLE_S + MEASURE_S) * hz):
		await get_tree().physics_frame
		ticks += 1
		for row in straight:
			var s: Dictionary = Sim.server.vehicle_state(int(row["entity"]))
			if s.is_empty():
				continue
			var p: Vector3 = s["position"]
			Sim.server.steer_ai(int(row["entity"]), {"toward": Vector3(p.x, p.y, p.z - 4000.0), "speed": float(row["speed"])})
		for row in circles:
			var s: Dictionary = Sim.server.vehicle_state(int(row["entity"]))
			if s.is_empty():
				continue
			var p: Vector3 = s["position"]
			var m: Vector3 = row["middle"]
			var a: float = atan2(p.z - m.z, p.x - m.x)
			var ahead: float = a - 0.9
			Sim.server.steer_ai(int(row["entity"]), {"toward": Vector3(m.x + cos(ahead) * float(row["radius"]), p.y,
				m.z + sin(ahead) * float(row["radius"])), "speed": float(row["speed"])})
		if ticks == int(SETTLE_S * hz):
			for row in straight + circles:
				var s: Dictionary = Sim.server.vehicle_state(int(row["entity"]))
				marks[int(row["entity"])] = s.get("position", Vector3.ZERO)
	for row in straight:
		var s: Dictionary = Sim.server.vehicle_state(int(row["entity"]))
		var p: Vector3 = s.get("position", Vector3.ZERO)
		var v: Vector3 = s.get("velocity", Vector3.ZERO)
		var from: Vector3 = marks.get(int(row["entity"]), p)
		print("PROBE straight asked %.0f: flown %.1f m/s, sink %.2f m/s, glide %.1f:1" % [row["speed"], v.length(),
			(from.y - p.y) / MEASURE_S, Vector2(p.x - from.x, p.z - from.z).length() / maxf(from.y - p.y, 0.01)])
	for row in circles:
		var s: Dictionary = Sim.server.vehicle_state(int(row["entity"]))
		var p: Vector3 = s.get("position", Vector3.ZERO)
		var v: Vector3 = s.get("velocity", Vector3.ZERO)
		var from: Vector3 = marks.get(int(row["entity"]), p)
		var m: Vector3 = row["middle"]
		print("PROBE circle asked %.0f m/s r %.0f: flown %.1f m/s, sink %.2f m/s, %.0f m from the middle" % [row["speed"],
			row["radius"], v.length(), (from.y - p.y) / MEASURE_S, Vector2(p.x - m.x, p.z - m.z).length()])
	print("RESULT=PASS")
	get_tree().quit()
