extends Node
## EVERY AEROPLANE LEFT TO ITS AUTOPILOT FOR THREE MINUTES, FROM THE GROUND AND FROM THE AIR.
##
##   Godot --headless --fixed-fps 120 --path cockpit res://tests/climb.tscn
##
## Asked for on 2026-09-14 -- "planes still seem to end up on the ground after a minute, all
## types ... they should ascend more slowly and be careful not to stall" -- and every limit here
## is something `tests/sinking_probe.gd` measured going wrong in the real sky that day:
##
##   * the tanker and the gunship were asked for thirty metres a second of climb, pitched to
##     sixty degrees, lost their speed in eight seconds and fell out of the sky;
##   * the light aeroplane climbed at twenty-three degrees, which is the steep climb the user saw;
##   * a tiltrotor put down on the ground rolled at cruise speed for a minute and never left it.
##
## AN EMPTY FLAT WORLD WITH NO WAYPOINTS, so every autopilot has one job: get off the ground if it
## is on it, and climb to the height a machine with nowhere to go holds. Nothing is read out of
## the autopilot. Height, climb, pitch and airspeed are the vehicle's own state, and the limits
## are the user's words turned into numbers here -- not the mixer's numbers read back, which
## would be a test that agrees with whatever the mixer does.
##
## Read RESULT=, not the exit code.

## How long every machine is left alone.
const WATCH: float = 180.0
## FLYING is this far up, once and for good: clear of its own take-off. At ten metres over the
## wheels -- the first try -- the light aeroplane, the airliner and the Cessna each counted as
## flying a second before they were, and reported "lowest 15 m once flying" off a clean climb-out.
const FLYING_FROM: float = 60.0
## Once it is flying, it never comes lower than this, and it ends the run higher than the next.
const LOWEST_ONCE_FLYING: float = 30.0
const HIGH_AT_THE_END: float = 200.0
## A GENTLE CLIMB, as the flight path's angle and not a rate: a rate that is gentle for an
## aeroplane doing seventy metres a second is a zoom for one doing forty. Nine degrees is about
## what an airliner climbs at, and the light aeroplane was doing twenty-three.
const STEEPEST_CLIMB_DEG: float = 9.0
## Never slower than this share over the stall while it is climbing. The stall is the handling
## table's own, the speed the wing carries the weight at with the nose on the horizon. A
## quarter over it: the user said "be careful not to stall", and the autopilot stops climbing
## at thirty per cent over, so this is the floor with room for a sample taken mid-correction.
const CLIMBING_OVER_THE_STALL: float = 1.25
## AND NO FASTER THAN THIS, in metres a second, however fast the aeroplane: the light
## aeroplane was climbing at thirty.
const CLIMB_RATE_MOST: float = 10.0
## A machine put down on the ground is flying -- FLYING_FROM up -- within this many seconds.
## The tiltrotor rolled for a minute and never left.
## SIXTY SECONDS IS ENOUGH FOR EVERY MACHINE HERE, and the two that looked as if they needed more were not being given
## ground to take off from -- see the slab in `_ready`. On it, the P-51D reaches 60 m in 35.5 s and the P-47D-30 in
## 39.5, against a Cessna's 44 and a jet's 14. A per-kind allowance was written here first and then deleted: the
## measurement was the bug (lane/warbirds2, 2026-09-19).
const OFF_THE_GROUND_WITHIN: float = 60.0
## Only counted once clear of the take-off, and only while really climbing.
const CLIMBING_FROM: float = 15.0
const CLIMBING_AT: float = 1.0
## Sampled this often, in seconds.
const EVERY: float = 0.5
## AND IT HAS TO HAVE BEEN SEEN CLIMBING, for this many samples, or neither climb check has
## anything to say. The first run passed the tiltrotor from the air on both of them with a
## steepest climb of nought and a slowest speed of infinity: it had held 300 m for three minutes
## and never climbed at all, because a tiltrotor with nowhere to go held whatever height it had.
const CLIMBING_SAMPLES_AT_LEAST: int = 10

## A WALL AHEAD OF A LOW AEROPLANE. The first run of the gentle climb in the real sky flew two
## light aeroplanes launched at 60 m into the lintel of the gate they were pointed at, seven
## seconds later: a climb gentle enough for a user to watch is too gentle to clear what is in
## front of it, so the autopilot has to look. 500 m ahead and 130 m tall is what that climb
## cannot clear from 60 m and a look-ahead climb can.
const WALL_AHEAD: float = 500.0
const WALL_TALL: float = 130.0
const WALL_LAUNCH_Y: float = 60.0
const WALL_LANE_X: float = 3000.0
const WALL_Z: float = 2500.0

var _failed: bool = false
var _said: Array[String] = []
## `-- --set=... --kind=...`: see `TuningCard`. Empty, and nothing is retuned or skipped.
var _card: TuningCard = TuningCard.from_command_line()


func _ready() -> void:
	if not Sim.is_available():
		print("[climb] extension missing")
		get_tree().quit(1)
		return
	await _start()
	if not _card.is_empty():
		print("[climb] %s" % _card.clip_on())
	# THE GROUND, WIDE ENOUGH FOR THE LANES THERE ACTUALLY ARE. A lane is 700 m further out than the last and the first
	# is at -4,000, so the slab's typed 7,200 ran out at the SEVENTEENTH powered wing: the P-51D was spawned on its
	# edge and the P-47D-30 beyond it, and both fell through to the world's floor at -200 m and were clamped there --
	# thousands of `the wire clamped ... VehicleState.y` errors a run, which the suite's own FAIL had been hiding
	# (lane/warbirds2, 2026-09-19). Worked out from the lanes now, so the next kind cannot do it again. The lanes
	# themselves are not moved: a kind's lane is its place in `Sim.Kind` and moving them would move every measurement.
	var flying: Array[int] = []
	for kind in _every_powered_wing():
		if _card.flies(kind):
			flying.append(kind)
	Sim.add_static_box(Vector3(0.0, -400.0, 0.0),
		Vector3(maxf(7200.0, 4000.0 + float(maxi(flying.size() - 1, 0)) * 700.0 + 700.0), 400.0, 7200.0))
	var flown: Array[Dictionary] = []
	var lane: int = 0
	for kind in flying:
		var hy: float = (Sim.geometry_of(kind)["extents"] as Vector3).y
		var cruise: float = float(Sim.server.handling(kind).get("cruise", 60.0))
		# SEPARATE LANES, all flying down -Z, so nothing meets anything: a machine from the
		# ground climbs through the height the one from the air started at.
		var parked: int = int(Sim.server.spawn_ai_vehicle(kind,
			Vector3(-4000.0 + float(lane) * 700.0, hy + 0.3, 0.0), 0.0, Vector3.ZERO))
		var aloft: int = int(Sim.server.spawn_ai_vehicle(kind,
			Vector3(-3650.0 + float(lane) * 700.0, 300.0, 3000.0), 0.0,
			Vector3(0.0, 0.0, -cruise)))
		flown.append(_watching(kind, parked, "ground", hy))
		flown.append(_watching(kind, aloft, "air", hy))
		lane += 1
	_check("there_is_something_to_fly", lane >= (5 if _card.kinds.is_empty() else _card.kinds.size()),
		"%d kinds with an engine and a wing" % lane)
	# AND ONE WITH A WALL IN FRONT OF IT, in a lane of its own and left out of the gentle checks,
	# because climbing hard over something is the one time it should. See WALL_AHEAD.
	var wall_hy: float = WALL_TALL * 0.5
	Sim.add_static_box(Vector3(WALL_LANE_X, wall_hy, WALL_Z), Vector3(300.0, wall_hy, 10.0))
	var walled: int = int(Sim.server.spawn_ai_vehicle(Sim.Kind.PLANE,
		Vector3(WALL_LANE_X, WALL_LAUNCH_Y, WALL_Z + WALL_AHEAD), 0.0,
		Vector3(0.0, 0.0, -float(Sim.server.handling(Sim.Kind.PLANE).get("cruise", 60.0)))))
	var wall := {"entity": walled, "slowest_after_a_second": INF, "lost_most": 0.0,
		"height_over_the_wall": -INF, "was": -1.0, "time": 0.0}

	var step: float = float(Sim.server.fixed_dt())
	var frames: int = int(round(EVERY / step))
	for sample in range(int(WATCH / EVERY)):
		for i in range(frames):
			await get_tree().physics_frame
		for craft in flown:
			_sample(craft)
		_sample_the_wall(wall)

	for craft in flown:
		_judge(craft)
	_check("a_light_aeroplane_launched_at_a_wall_climbs_over_it",
		float(wall["height_over_the_wall"]) > WALL_TALL and float(wall["lost_most"]) < 20.0,
		"%.0f m up as it crossed a %.0f m wall, and the most speed lost in half a second was %.1f m/s" % [
			float(wall["height_over_the_wall"]), WALL_TALL, float(wall["lost_most"])])
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


## EVERY KIND WITH A WING AND AN ENGINE, asked of the simulation rather than typed out. A glider
## is left out on purpose: it has no way off the ground and no way to climb in still air.
func _every_powered_wing() -> Array[int]:
	var out: Array[int] = []
	for kind in range(Sim.Kind.size()):
		var model: int = int(Sim.geometry_of(kind).get("model", -1))
		if model != Sim.Model.AIRPLANE and model != Sim.Model.TILTROTOR:
			continue
		if float(Sim.server.handling(kind).get("thrust", 0.0)) <= 0.0:
			continue
		out.append(kind)
	return out


func _watching(kind: int, entity: int, from: String, hy: float) -> Dictionary:
	return {"kind": kind, "entity": entity, "name": "%s_from_the_%s" % [Sim.kind_name(kind), from],
		"stall": float(Sim.server.handling(kind).get("stall_speed", 0.0)), "hy": hy,
		"on_the_ground": from == "ground", "flying": from == "air", "gone": entity == 0,
		"lowest": INF, "steepest": 0.0, "steepest_at": 0.0, "slowest": INF, "slowest_at": 0.0,
		"climbing": 0, "fastest_climb": 0.0, "flying_at": -1.0,
		"end": 0.0, "time": 0.0}


func _sample(craft: Dictionary) -> void:
	craft["time"] = float(craft["time"]) + EVERY
	if bool(craft["gone"]):
		return
	var state: Dictionary = Sim.server.vehicle_state(int(craft["entity"]))
	if state.is_empty():
		craft["gone"] = true
		return
	var at: Vector3 = state["position"]
	var going: Vector3 = state["velocity"]
	var nose: Vector3 = Basis(state["basis"] as Quaternion) * Vector3.FORWARD
	craft["end"] = at.y
	if not bool(craft["flying"]) and at.y > FLYING_FROM:
		craft["flying"] = true
		craft["flying_at"] = craft["time"]
	if bool(craft["flying"]):
		craft["lowest"] = minf(float(craft["lowest"]), at.y)
	if at.y < CLIMBING_FROM or going.y < CLIMBING_AT:
		return
	craft["climbing"] = int(craft["climbing"]) + 1
	craft["fastest_climb"] = maxf(float(craft["fastest_climb"]), going.y)
	var speed: float = going.length()
	var path: float = rad_to_deg(asin(clampf(going.y / maxf(speed, 0.1), -1.0, 1.0)))
	if path > float(craft["steepest"]):
		craft["steepest"] = path
		craft["steepest_at"] = craft["time"]
	var along: float = going.dot(nose)
	if along < float(craft["slowest"]):
		craft["slowest"] = along
		craft["slowest_at"] = craft["time"]


## WHERE IT WAS AS IT CROSSED THE WALL, and whether it hit anything on the way: a strike is speed
## gone faster than any wing or brake takes it, and twenty metres a second in half a second is
## well past both.
func _sample_the_wall(wall: Dictionary) -> void:
	wall["time"] = float(wall["time"]) + EVERY
	var state: Dictionary = Sim.server.vehicle_state(int(wall["entity"]))
	if state.is_empty():
		return
	var at: Vector3 = state["position"]
	var speed: float = (state["velocity"] as Vector3).length()
	if float(wall["was"]) >= 0.0 and float(wall["time"]) > 1.0:
		wall["lost_most"] = maxf(float(wall["lost_most"]), float(wall["was"]) - speed)
	wall["was"] = speed
	# THE FIRST TIME IT IS OVER THE WALL, and only then. Kept as the highest sample near the wall,
	# the old library's aeroplane read "520 m up as it crossed" after flying into the wall and
	# climbing away from beside it; only the speed it lost said what had happened.
	if absf(at.z - WALL_Z) < 60.0 and float(wall["height_over_the_wall"]) == -INF:
		wall["height_over_the_wall"] = at.y


func _judge(craft: Dictionary) -> void:
	var name: String = craft["name"]
	var stall: float = float(craft["stall"])
	_check("%s_is_flying_after_three_minutes" % name,
		not bool(craft["gone"]) and bool(craft["flying"])
			and float(craft["lowest"]) > LOWEST_ONCE_FLYING
			and float(craft["end"]) > HIGH_AT_THE_END,
		"%s, lowest %.0f m once flying, %.0f m at the end" % [
			"gone" if bool(craft["gone"]) else ("flew" if bool(craft["flying"]) else "never left the ground"),
			float(craft["lowest"]), float(craft["end"])])
	var seen: bool = int(craft["climbing"]) >= CLIMBING_SAMPLES_AT_LEAST
	if bool(craft["on_the_ground"]):
		_check("%s_leaves_the_ground" % name,
			float(craft["flying_at"]) >= 0.0 and float(craft["flying_at"]) <= OFF_THE_GROUND_WITHIN,
			"%.0f m up at %.1f s, against %.0f s" % [FLYING_FROM, float(craft["flying_at"]),
				OFF_THE_GROUND_WITHIN])
	_check("%s_climbs_no_faster_than_the_cap" % name,
		seen and float(craft["fastest_climb"]) <= CLIMB_RATE_MOST,
		"fastest climb %.1f m/s against %.0f" % [float(craft["fastest_climb"]), CLIMB_RATE_MOST])
	_check("%s_climbs_gently" % name, seen and float(craft["steepest"]) <= STEEPEST_CLIMB_DEG,
		"steepest climb %.1f degrees at %.1f s, against %.0f, over %d climbing samples" % [
			float(craft["steepest"]), float(craft["steepest_at"]), STEEPEST_CLIMB_DEG,
			int(craft["climbing"])])
	_check("%s_keeps_its_speed_while_climbing" % name,
		seen and float(craft["slowest"]) >= stall * CLIMBING_OVER_THE_STALL,
		"slowest %.1f m/s climbing, at %.1f s, against %.1f (a stall of %.1f), over %d samples" % [
			float(craft["slowest"]), float(craft["slowest_at"]), stall * CLIMBING_OVER_THE_STALL,
			stall, int(craft["climbing"])])


func _check(name: String, passed: bool, detail: String) -> void:
	print("[climb] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true
		_said.append(name)


func _start() -> void:
	var waiting: Array = [not Sim.is_ready]
	if bool(waiting[0]):
		Sim.sim_ready.connect(func(): waiting[0] = false, CONNECT_ONE_SHOT)
	Net.play_solo()
	Sim.start()
	var patience: int = 600
	while bool(waiting[0]) and patience > 0:
		patience -= 1
		await get_tree().physics_frame
