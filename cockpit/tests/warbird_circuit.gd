extends Node
## Headless: A WARBIRD DOES ITS JOB, a take-off, a circuit and a landing, flown by its own autopilot through the airport's
## traffic (lane/warbirds2): the brief's "the AI can fly it (a take-off, a circuit and a landing at least)".
##
##   Godot --headless --fixed-fps 120 --xr-mode off --path cockpit res://tests/warbird_circuit.tscn [-- --kind=p51]
##
## Each kind is put on the threshold of a hand-laid runway on flat ground, lined up, and told to depart and come back to
## the same field (`AirportTraffic.depart` with `then_to`), which is the whole of what the island's traffic asks of any
## aeroplane. A TAILDRAGGER does it as its manual says, and the checks read what the aeroplane DID, sampled every tick:
## - it lifts off inside the runway, down the centreline, and its tail came up before it did;
## - it comes back round and lands, and the crash rule reads the touchdown as a landing: whole afterwards, the sink under
##   the land aeroplane's 6.1 m/s, and a three-point touchdown within a few degrees of its rake (`[P4]`: "a tail-low
##   attitude for actual touchdown");
## - it rolls out and stops on its wheels without nosing over.
## Read RESULT=, not the exit code.

## THE RUNWAY: 1,500 m, its middle at the origin, landed on northward (toward -Z) from its southern end. A fighter's field:
## the P-51's book runs 442 m to lift-off and 600 m of landing roll at its combat weight.
const LENGTH: float = 1500.0
## THE KINDS, each with HOW IT ARRIVES and what that means for the attitude it touches down in:
## - "three_point", and how close to its rake it must be, degrees: a VFR circuit is flared to the three-point attitude
##   and held there ("continuous back pressure on the stick", AN 01-60JE-1);
## - "wheels": it is flown ONTO the runway, main wheels first, so the check is that it arrives NOSE UP but nowhere near
##   its rake -- between a wheel landing's own floor and a tail strike. A kind heavier than `TrafficPattern.LARGE_MASS`
##   (5,670 kg, the FAA's 12,500 lb) flies an INSTRUMENT approach and not the visual circuit, and an instrument approach
##   is not flared. The P-47D-30 at 6,001 kg is the first fighter here over that line, and it lands as one: 8.0 degrees
##   nose up at 66 m/s, 296 m past the threshold, 0.77 m/s of sink. Its THREE-POINT landing is held in
##   `tests/taildragger.gd`, which flies it by hand.
const KINDS: Dictionary = {
	"p51": {"touchdown": "three_point", "three_point": 4.0},
	"p47": {"touchdown": "wheels", "wheels_between": Vector2(3.0, 10.0)},
}
## THE LAND AEROPLANE'S LIMIT the crash rule destroys at, m/s (`touchdown_of`: 10 ft/s doubled).
const TOUCH_SINK_MOST: float = 6.1
## THE BASE LAID ROUND THE RUNWAY for the taxi, and how far off its route a taxiing craft may wander, metres
## (`tests/traffic_pattern.gd`'s, which is the Cessna's on the same template).
const TEMPLATE_BASE: String = "res://world/airbases/_template"
const TAXI_STRAY: float = 11.4
## `-- --trace`: where it is and what it is doing every 10 s.
var _trace: bool = OS.get_cmdline_user_args().has("--trace")

var _failed := false
var _traffic: AirportTraffic = null


func _ready() -> void:
	if not Sim.is_available():
		_check("the_extension_is_there", false, "no CockpitWorld")
		_finish()
		return
	await _start()
	Sim.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(7200.0, 400.0, 7200.0))
	_traffic = AirportTraffic.new()
	_traffic.recording = true
	_traffic.highest_ground = func(_at: Vector3, _room: float) -> float: return 0.0
	add_child(_traffic)
	var only: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--kind="):
			only = argument.trim_prefix("--kind=")
	for kind in Sim.Kind.values():
		var name: String = Sim.kind_name(kind)
		if KINDS.has(name) and (only.is_empty() or only == name):
			await _circuit(kind, name, KINDS[name])
	_finish()


func _circuit(kind: int, name: String, rules: Dictionary) -> void:
	var field: Dictionary = {"id": "test_%s" % name, "frame": Terrain.runway_frame(Vector3.ZERO, 0.0, LENGTH, 45.0),
		"ends": {"threshold": {"pattern": "left"}, "far_end": {"pattern": "left"}}, "in_use": "threshold"}
	# FROM AN APRON SPOT, so it has to TAXI to the runway: a taildragger's tail wheel steers a few degrees, and a turn off
	# an apron is sharper than that (the user, 2026-09-19: "the p51 can't stay on the taxi way").
	var base: Dictionary = AirbasePlan.lay(AirbasePlan.read_base(TEMPLATE_BASE), field["frame"])
	field["base"] = base
	var spot: Dictionary = {}
	for id in base.get("spots", {}):
		if String(id).begins_with("apron") and AirbasePlan.fits(base["spots"][id], kind):
			spot = base["spots"][id]
			break
	_check("%s_has_an_apron_spot_it_fits" % name, not spot.is_empty(),
		"spots %s" % str((base.get("spots", {}) as Dictionary).keys()))
	if spot.is_empty():
		return
	var hy: float = float(Sim.geometry_of(kind)["extents"].y)
	var parked_at: Vector3 = AirbasePlan.standing_on_spot(base, spot, kind) + Vector3.UP * (hy + 0.3)
	var entity: int = Sim.spawn_ai_vehicle(kind, parked_at, float(spot["yaw"]), Vector3.ZERO)
	await get_tree().physics_frame
	var rake: float = _pitch(entity)
	# THE DRAWN TYRES, so "on its wheels" is the drawing's tyres on the slab, not a height guessed for the box.
	var frame: WarbirdAirframe = VehicleView.warbird_for(kind)
	frame.dress()
	_traffic.depart(entity, field, kind, String(spot["id"]), "", field)
	var me: Dictionary = _traffic.record_of(entity)
	var p: TrafficPattern = me["pattern"]
	# WHAT IT DID, every tick, in a dictionary (a lambda captures a local by value).
	var seen := {"least_pitch_rolling": 90.0, "touch_pitch": NAN, "least_pitch_after": 90.0, "lost": "", "down": true,
		"airborne": false, "me": me}
	var watch := func() -> bool:
		var state: Dictionary = Sim.server.vehicle_state(entity)
		if state.is_empty():
			return true
		var hull: Dictionary = Sim.server.hull_state(entity)
		if bool(hull.get("destroyed", false)):
			seen["lost"] = String(hull.get("cause_name", "destroyed"))
			return true
		# THE RECORD AFRESH EVERY TICK: going on to a field (`then_to`) is a new record (`_carry_on_to`), and the first
		# cut of this suite watched the departure's for 540 s while the aeroplane came round and landed.
		var now_me: Dictionary = _traffic.record_of(entity)
		if not now_me.is_empty():
			seen["me"] = now_me
		var record: Dictionary = seen["me"]
		var pitch: float = _pitch(entity)
		seen["ticks"] = int(seen.get("ticks", 0)) + 1
		if _trace and int(seen["ticks"]) % 1200 == 0:
			var at: Vector3 = state["position"]
			print("[warbird_circuit]   t %.0f %s at (%.0f, %.0f, %.0f) %.1f m/s pitch %.1f" % [float(seen["ticks"]) / 120.0,
				record["phase"], at.x, at.y, at.z, (state["velocity"] as Vector3).length(), pitch])
		var on: bool = _lowest_tyre(state, frame) < 0.05
		# HOW FAR OFF ITS TAXI ROUTE IT EVER GOT, and how fast it taxied.
		if record["phase"] == &"taxi" and record.has("route"):
			seen["taxi_stray"] = maxf(float(seen.get("taxi_stray", 0.0)),
				_off_route(record["route"] as PackedVector3Array, state["position"]))
			seen["taxi_fastest"] = maxf(float(seen.get("taxi_fastest", 0.0)), (state["velocity"] as Vector3).length())
		if not bool(seen["airborne"]):
			if on:
				seen["least_pitch_rolling"] = minf(float(seen["least_pitch_rolling"]), pitch)
			elif (state["position"] as Vector3).y > hy + 3.0:
				seen["airborne"] = true
		elif on and is_nan(float(seen["touch_pitch"])):
			seen["touch_pitch"] = pitch
		if not is_nan(float(seen["touch_pitch"])):
			seen["least_pitch_after"] = minf(float(seen["least_pitch_after"]), pitch)
		return record["phase"] == &"stopped" or int(record["go_arounds"]) > 1
	var departed: Dictionary = me
	# LONG ENOUGH FOR THE APPROACH THE KIND FLIES. The P-51's VFR circuit is done in 596 s; the P-47's INSTRUMENT
	# approach -- 16 km out on the vectors and a final from as far again -- takes 1,285, and the suite exits the tick it
	# stops. Measured, both, 2026-09-19.
	var flown: float = await _fly(watch, 1800.0)
	me = seen["me"]
	var lift: Vector3 = departed.get("lift_off", Vector3.INF)
	print("[warbird_circuit] %s: %.0f s, legs %s then %s" % [name, flown, str(departed["legs"]), str(me["legs"])])
	_check("%s_taxis_its_route_on_the_pavement" % name,
		float(seen.get("taxi_stray", 99.0)) <= TAXI_STRAY
		and float(seen.get("taxi_fastest", 0.0)) <= AirportTraffic.TAXI_SPEED + 1.0,
		"worst %.1f m off its route (at most %.1f), fastest %.1f m/s" % [seen.get("taxi_stray", -1.0), TAXI_STRAY,
			seen.get("taxi_fastest", 0.0)])
	_check("%s_raises_its_tail_on_the_take_off_run" % name, float(seen["least_pitch_rolling"]) < rake - 8.0,
		"the pitch fell from its %.1f deg rake to %.1f on the run" % [rake, seen["least_pitch_rolling"]])
	_check("%s_lifts_off_within_the_runway_on_the_centreline" % name,
		lift != Vector3.INF and p.ahead_of(lift) >= 0.0 and p.ahead_of(lift) <= p.length and absf(p.out_of(lift)) <= 22.5,
		"lift-off %.0f m past the threshold, %.1f m off the centreline" % [p.ahead_of(lift) if lift != Vector3.INF else -1.0,
			p.out_of(lift) if lift != Vector3.INF else -1.0])
	var landed: Dictionary = me.get("landed", {})
	var sink: float = float(landed.get("touch_sink", INF))
	var touch_at: Vector3 = landed.get("touch_at", Vector3.INF)
	_check("%s_comes_round_and_lands_softly_on_the_runway" % name,
		bool(landed.get("touched", false)) and sink <= TOUCH_SINK_MOST and touch_at != Vector3.INF
		and p.ahead_of(touch_at) >= 0.0 and p.ahead_of(touch_at) <= p.length and String(seen["lost"]).is_empty(),
		"touched %s %.0f m in at %.2f m/s down and %.1f m/s along, %d go-arounds; lost %s" % [landed.get("touched", false),
			p.ahead_of(touch_at) if touch_at != Vector3.INF else -1.0, sink, float(landed.get("touch_speed", 0.0)),
			int(me["go_arounds"]), seen["lost"] if not String(seen["lost"]).is_empty() else "nothing"])
	var pitch_touched: float = float(seen["touch_pitch"])
	if String(rules.get("touchdown", "three_point")) == "wheels":
		var band: Vector2 = rules["wheels_between"]
		_check("%s_touches_down_on_its_wheels_nose_up" % name,
			not is_nan(pitch_touched) and pitch_touched >= band.x and pitch_touched <= band.y,
			"touched at %.1f deg, held between %.1f and %.1f, with its rake at %.1f" % [pitch_touched, band.x, band.y,
				rake])
	else:
		_check("%s_touches_down_three_point" % name,
			not is_nan(pitch_touched) and absf(pitch_touched - rake) <= float(rules["three_point"]),
			"touched at %.1f deg against its %.1f rake (within %.0f)" % [pitch_touched, rake, rules["three_point"]])
	_check("%s_rolls_out_and_stops_without_nosing_over" % name,
		me["phase"] == &"stopped" and String(seen["lost"]).is_empty() and float(seen["least_pitch_after"]) > 0.0,
		"phase %s, the pitch never under %.1f deg after the touch, lost %s" % [me["phase"], seen["least_pitch_after"],
			seen["lost"] if not String(seen["lost"]).is_empty() else "nothing"])
	_traffic.release(entity)
	Sim.server.despawn_vehicle(entity)
	frame.free()


## HOW FAR A POINT IS OFF A ROUTE, metres in plan (`tests/traffic_pattern.gd`'s).
static func _off_route(route: PackedVector3Array, at: Vector3) -> float:
	var best: float = INF
	var flat := Vector2(at.x, at.z)
	for i in range(route.size() - 1):
		var a := Vector2(route[i].x, route[i].z)
		var b := Vector2(route[i + 1].x, route[i + 1].z)
		var t: float = clampf((flat - a).dot(b - a) / maxf((b - a).length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, flat.distance_to(a + (b - a) * t))
	return best


## THE LOWEST DRAWN TYRE'S BOTTOM over the slab, metres.
func _lowest_tyre(state: Dictionary, frame: WarbirdAirframe) -> float:
	var basis := Basis(state.get("basis", Quaternion()) as Quaternion)
	var lowest: float = INF
	for contact in frame.wheel_contacts():
		lowest = minf(lowest, ((state["position"] as Vector3) + basis * (contact as Vector3)).y)
	return lowest


func _pitch(entity: int) -> float:
	var state: Dictionary = Sim.server.vehicle_state(entity)
	var nose: Vector3 = Basis(state.get("basis", Quaternion()) as Quaternion) * Vector3.FORWARD
	return rad_to_deg(asin(clampf(nose.y, -1.0, 1.0)))


func _fly(done: Callable, seconds: float) -> float:
	var ticks: int = int(seconds * 120.0)
	for i in range(ticks):
		await get_tree().physics_frame
		if done.call():
			return float(i) / 120.0
	return seconds


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


func _check(name: String, passed: bool, detail: String) -> void:
	print("[warbird_circuit] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true


func _finish() -> void:
	print("RESULT=%s" % ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)
