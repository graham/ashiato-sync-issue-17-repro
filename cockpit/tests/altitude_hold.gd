extends Node
## AN AUTOPILOT CAN BE GIVEN ITS OWN TRAFFIC LAYER, and letting the layer go gives the
## ordinary route its altitude back. This drives the native API through the same server
## world `HoldingStack` uses; positions come from vehicle state rather than pilot internals.

const HOLD: float = 800.0
const SETTLE_SECONDS: float = 35.0
const WATCH_SECONDS: float = 60.0
const RELEASE_SECONDS: float = 35.0

var _failed := false
var _said: Array[String] = []


func _ready() -> void:
	if not Sim.is_available():
		print("[altitude_hold] extension missing")
		get_tree().quit(1)
		return
	await _start()
	var cruise := Terrain.cruise_for(Sim.Kind.PLANE)
	var held := int(Sim.server.spawn_ai_vehicle(Sim.Kind.PLANE,
		Vector3(-400.0, HOLD, 0.0), 0.0, Vector3(0.0, 0.0, -cruise)))
	var free := int(Sim.server.spawn_ai_vehicle(Sim.Kind.PLANE,
		Vector3(400.0, HOLD, 0.0), 0.0, Vector3(0.0, 0.0, -cruise)))
	_check("the_native_api_accepts_an_autopilot", Sim.server.set_ai_altitude(held, HOLD),
		"held entity %d" % held)
	_check("the_native_api_refuses_an_unknown_entity", not Sim.server.set_ai_altitude(987654321, HOLD),
		"an entity outside this world")
	await _frames(SETTLE_SECONDS)
	var worst := 0.0
	var free_low := HOLD
	for i in range(int(WATCH_SECONDS / float(Sim.server.fixed_dt()))):
		await get_tree().physics_frame
		var held_state: Dictionary = Sim.server.vehicle_state(held)
		var free_state: Dictionary = Sim.server.vehicle_state(free)
		if held_state.is_empty() or free_state.is_empty():
			_check("both_aircraft_remain_alive", false, "held=%s free=%s" % [held_state, free_state])
			break
		worst = maxf(worst, absf((held_state["position"] as Vector3).y - HOLD))
		free_low = minf(free_low, (free_state["position"] as Vector3).y)
	# First measured on this implementation: 0.0 m worst error over the watched minute.
	# The 45 m gate is still far below the free craft's 280 m route-height change, so an
	# ignored hold is unambiguously red while a later, gentler mixer has room to settle.
	_check("the_held_aircraft_stays_in_its_layer", worst < 45.0,
		"worst |altitude - %.0f| was %.1f m" % [HOLD, worst])
	_check("a_free_aircraft_keeps_using_its_ordinary_altitude", free_low < HOLD - 100.0,
		"the free aircraft descended to %.1f m" % free_low)
	var before_release := (Sim.server.vehicle_state(held)["position"] as Vector3).y
	_check("nan_releases_the_layer", Sim.server.set_ai_altitude(held, NAN),
		"release accepted at %.1f m" % before_release)
	await _frames(RELEASE_SECONDS)
	var after_release := (Sim.server.vehicle_state(held)["position"] as Vector3).y
	_check("the_released_aircraft_returns_to_its_route_height", after_release < before_release - 40.0,
		"%.1f m before release -> %.1f m after" % [before_release, after_release])
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


func _frames(seconds: float) -> void:
	for i in range(int(seconds / float(Sim.server.fixed_dt()))):
		await get_tree().physics_frame


func _check(name: String, passed: bool, detail: String) -> void:
	print("[altitude_hold] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true
		_said.append(name)


func _start() -> void:
	var waiting: Array = [not Sim.is_ready]
	if bool(waiting[0]):
		Sim.sim_ready.connect(func(): waiting[0] = false, CONNECT_ONE_SHOT)
	Net.play_solo()
	Sim.start()
	var patience := 600
	while bool(waiting[0]) and patience > 0:
		patience -= 1
		await get_tree().physics_frame
