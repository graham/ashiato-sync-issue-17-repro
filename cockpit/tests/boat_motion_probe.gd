extends Node
## A SMALL BOAT'S MOTION ON THE SIMULATED SEA, as numbers: how much a launch and a patrol boat heave, roll and pitch over a
## fixed spell, stopped and under way.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/boat_motion_probe.tscn
##
## A PROBE, NOT A SUITE. It has no right answer: it is run on main's library and on a lane's, and the two are compared. It
## was written for C1 (cockpit-ocean, 2026-09-15), the wind-sea put into `swell_height`, whose whole point is to move small
## boats and whose risk is moving a seated player too much. The simulation is deterministic, so the numbers do not depend on
## the machine's load.
##
## Each boat is spawned with a pilot at (500, 1, 500) on the island-less sea, left to settle for 20 s, then sampled four
## times a second for 60 s: the standard deviation of its height (heave), and the standard deviation and the worst of its
## roll and pitch in degrees. Stopped, a boat on a standing sea only leans where it lies; under way at full throttle along
## the swell's heading, it meets the crests.
##
## Prints one `[boat_motion]` line a boat and case, and RESULT=PASS once it has run to its end.

const TICK: float = 1.0 / 120.0
const SETTLE: float = 20.0
const SPELL: float = 60.0
const SAMPLE_EVERY: int = 30
const AT := Vector3(500.0, 1.0, 500.0)
const BOATS: Dictionary = {"launch": Sim.Kind.BOAT, "gunboat": Sim.Kind.GUNBOAT}


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL CockpitWorld is not registered")
		get_tree().quit()
		return
	var shape: Dictionary = Sim.swell_shape()
	print("[boat_motion] library: swell waves %d, wind waves %d" % [2 if shape.has("first") else 0,
		(shape.get("wind_waves", []) as Array).size()])
	for boat in BOATS:
		for case in ["stopped", "under_way"]:
			_measure(boat, int(BOATS[boat]), 1.0 if case == "under_way" else 0.0, case)
	print("RESULT=PASS")
	get_tree().quit()


func _measure(boat: String, kind: int, throttle: float, case: String) -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var made: Dictionary = world.spawn_pilot(301, kind, AT, 0.0, Vector3.ZERO)
	var vehicle: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	var heights := PackedFloat32Array()
	var rolls := PackedFloat32Array()
	var pitches := PackedFloat32Array()
	var started: Vector3 = Vector3.ZERO
	for i in range(int((SETTLE + SPELL) / TICK)):
		world.set_pilot_input(pilot, {"throttle": throttle})
		world.tick(TICK)
		if i == int(SETTLE / TICK):
			started = world.vehicle_state(vehicle)["position"]
		if i < int(SETTLE / TICK) or i % SAMPLE_EVERY != 0:
			continue
		var state: Dictionary = world.vehicle_state(vehicle)
		var basis := Basis(state["basis"] as Quaternion)
		heights.append((state["position"] as Vector3).y)
		rolls.append(rad_to_deg(asin(clampf(basis.x.y, -1.0, 1.0))))
		pitches.append(rad_to_deg(asin(clampf(-basis.z.y, -1.0, 1.0))))
	var travelled: float = ((world.vehicle_state(vehicle)["position"] as Vector3) - started).length()
	world.teardown()
	print("[boat_motion] %s %s: heave sd %.3f m (%.2f to %.2f), roll sd %.2f deg worst %.2f, pitch sd %.2f deg worst %.2f, %.0f m in %.0f s" % [
		boat, case, _sd(heights), _least(heights), _most(heights), _sd(rolls), _worst(rolls), _sd(pitches), _worst(pitches),
		travelled, SPELL])


func _sd(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var mean: float = 0.0
	for v in values:
		mean += v
	mean /= float(values.size())
	var sum: float = 0.0
	for v in values:
		sum += (v - mean) * (v - mean)
	return sqrt(sum / float(values.size()))


func _worst(values: PackedFloat32Array) -> float:
	var out: float = 0.0
	for v in values:
		out = maxf(out, absf(v))
	return out


func _least(values: PackedFloat32Array) -> float:
	var out: float = INF
	for v in values:
		out = minf(out, v)
	return out


func _most(values: PackedFloat32Array) -> float:
	var out: float = -INF
	for v in values:
		out = maxf(out, v)
	return out
