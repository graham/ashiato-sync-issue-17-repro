extends Node
## WHAT THE FLIGHT RECORDER COSTS A TICK: ten AI Cessnas flying, the wall time of a physics frame averaged over 600 of them with
## tracing OFF (no recorder exists), with ONE craft traced and with all TEN. Prints the three and the recorder's own microseconds a
## sample; asserts only that the recorder's share of the 120 Hz budget (8,333 us) stays under 10 %, which is a guard against a
## slip and not a measurement. Not a gate on speed: a loaded machine moves the frame times, so read the printed numbers.
##
##   Godot --headless --fixed-fps 120 --xr-mode off --path cockpit res://tests/trace_cost.tscn
##
## Read RESULT=, not the exit code.

const FRAMES: int = 600
const BUDGET_US: float = 8333.0

var _failed := false


func _ready() -> void:
	if not Sim.is_available():
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	var folder: String = OS.get_environment("TEMP").path_join("trace_cost_%d" % OS.get_process_id()).replace("\\", "/")
	var waiting: Array = [not Sim.is_ready]
	if bool(waiting[0]):
		Sim.sim_ready.connect(func(): waiting[0] = false, CONNECT_ONE_SHOT)
	Net.play_solo()
	Sim.start()
	while bool(waiting[0]):
		await get_tree().physics_frame
	Sim.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(7200.0, 400.0, 7200.0))
	var first := 0
	for i in 10:
		var entity: int = Sim.spawn_ai_vehicle(Sim.Kind.CESSNA, Vector3(-2000.0 + 150.0 * float(i), 900.0, 0.0), 0.0,
			Vector3(0.0, 0.0, -Terrain.cruise_for(Sim.Kind.CESSNA)))
		first = entity if i == 0 else first
	for i in 240:
		await get_tree().physics_frame
	var off: float = await _frames()
	var one: CraftTrace = CraftTrace.install(Sim, str(first), folder + "_one", "60")
	var with_one: float = await _frames()
	var one_us: float = float(one.spent_usec) / float(FRAMES / 2)
	one.close()
	one.queue_free()
	var ten: CraftTrace = CraftTrace.install(Sim, "ai", folder + "_ten", "60")
	var with_ten: float = await _frames()
	var ten_us: float = float(ten.spent_usec) / float(FRAMES / 2)
	ten.close()
	ten.queue_free()
	print("[trace_cost] frame, off: %.0f us; one craft traced: %.0f us; ten craft traced: %.0f us" % [off, with_one, with_ten])
	print("[trace_cost] the recorder's own time per sample (60 Hz, every second tick): one craft %.0f us, ten craft %.0f us" % [one_us, ten_us])
	var share: float = ten_us / 2.0 / BUDGET_US
	var ok: bool = share < 0.10
	print("[trace_cost] %s the recorder with ten craft is %.1f %% of a tick's 8,333 us budget" % ["PASS" if ok else "FAIL", share * 100.0])
	Sim.stop()
	print("RESULT=%s" % ("PASS" if ok else "FAIL the_recorder_is_over_a_tenth_of_the_budget"))
	get_tree().quit(0 if ok else 1)


func _frames() -> float:
	var began: int = Time.get_ticks_usec()
	for i in FRAMES:
		await get_tree().physics_frame
	return float(Time.get_ticks_usec() - began) / float(FRAMES)
