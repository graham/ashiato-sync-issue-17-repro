extends Node
## THE SAME CESSNA TAXIING THE SAME DISTANCE AT THE SAME SPEED ON TWO GROUNDS, traced (`CraftTrace`, 60 Hz) so the pitch rate's chatter
## can be counted on each and compared (lane/tracelog, 2026-09-19). A PROBE: it prints where the traces are and has no verdict.
##
##   Godot --headless --fixed-fps 120 --xr-mode off --path cockpit res://tests/taxi_ground_probe.tscn -- --out=<dir> [--levels=island,testfield]
##
## Contact make-and-break against a ground seam is a spatial frequency, so both runs use `AirportTraffic.TAXI_SPEED` and the same
## distance, along the first runway's centreline on each level, steered as the airport traffic steers a taxi (`steer_ai` with
## wheels "taxi"). Then: `python tools/read_trace.py <file> --from 2 --to <end>` and read spin.x hunt/s.
## The line printed says how many multiples of 1,024 m in world x and z the path crosses (the test field's old seam fault).

const PATIENCE: int = 3000
const SECONDS: float = 90.0

var _out: String = ""
var _level: FlightLevel = null


func _ready() -> void:
	var levels: PackedStringArray = ["island", "testfield"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.substr(6)
		elif argument.begins_with("--levels="):
			levels = argument.substr(9).split(",")
	if _out.is_empty():
		_out = OS.get_environment("TEMP").path_join("taxi_ground").replace("\\", "/")
	for id in levels:
		await _one(id)
	Sim.stop()
	print("RESULT=PASS (a probe: no verdict)")
	get_tree().quit(0)


func _one(id: String) -> void:
	Net.choose_level(id)
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	var frames: int = 0
	while frames < PATIENCE and not (_level.ground_built_msec >= 0.0 and Sim.is_ready):
		await get_tree().process_frame
		frames += 1
	for i in 30:
		await get_tree().process_frame
	var strip: Dictionary = Terrain.runways()[0]
	var centre: Vector3 = strip["centre"]
	var along: Vector3 = strip["along"]
	var half: float = 400.0
	var start: Vector3 = centre - along * half
	var finish: Vector3 = centre + along * half
	var ground: float = Terrain.highest_near(start, 20.0)
	start.y = ground + 1.2
	finish.y = ground
	var yaw: float = atan2(-along.x, -along.z)
	var entity: int = Sim.spawn_ai_vehicle(Sim.Kind.CESSNA, start, yaw, Vector3.ZERO)
	var dir: String = _out.path_join(id)
	var recorder: CraftTrace = CraftTrace.install(Sim, "cessna", dir, "60")
	var ticks: int = int(SECONDS * 120.0)
	for i in ticks:
		Sim.server.steer_ai(entity, {"toward": finish, "altitude": ground, "speed": AirportTraffic.TAXI_SPEED, "wheels": "taxi"})
		await get_tree().physics_frame
	recorder.close()
	var seams_x: int = int(floor(maxf(start.x, finish.x) / 1024.0)) - int(floor(minf(start.x, finish.x) / 1024.0))
	var seams_z: int = int(floor(maxf(start.z, finish.z) / 1024.0)) - int(floor(minf(start.z, finish.z) / 1024.0))
	print("TAXI level=%s speed=%.1f m/s from %s to %s seams_crossed x=%d z=%d files=%s" % [id, AirportTraffic.TAXI_SPEED,
		start.snapped(Vector3.ONE), finish.snapped(Vector3.ONE), seams_x, seams_z, recorder.paths.values()])
	recorder.queue_free()
	Sim.stop()
	Net.leave("probe step over")
	get_tree().root.remove_child(_level)
	_level.queue_free()
	for i in 20:
		await get_tree().process_frame
