extends Node
## TWO AEROPLANES WITH SOMETHING SOLID IN THE WAY, left to their autopilots.
##
##   Godot --headless --fixed-fps 120 --path cockpit res://tests/avoid.tscn
##
## The one aircraft still down after the climb fix of 2026-09-14, in the real sky on the merged library: a tanker added on
## open ground turned onto a leg, the turn took it off the line that had been checked against the terrain, and the ground
## rose some 370 m under it in six seconds. Its look-ahead saw the slope and climbed, but twelve seconds of a tanker's ten
## metres a second is not a mountain, and it hit the face at 389 m (tests/sinking_probe.gd). Two cases, each the smallest
## world that holds one half of that:
##
##   * A FACE AHEAD. A tanker level at its recovery height with a wall rising in front of it: taller than twelve seconds
##     of its climb clears, and lower than the climb it has if it looks as far ahead as that climb needs.
##   * A LEG THAT STOPS BEING CLEAR. A light aeroplane on a leg, and a wall put across the leg once it is flying it -- far
##     too tall to climb over, so the only way past is to notice the leg is blocked and choose another.
##
## THEIR OWN BOXES, NOT THE ISLAND'S. A check pinned to today's mountains is a check the next reshape of them breaks.
##
## Read RESULT=, not the exit code.

## The height a machine with nowhere to go holds (`recovery_height` in the simulation): level flight at it is what each
## aircraft is doing when the thing in the way arrives.
const HOLD: float = 520.0
## A FACE 1500 m ahead of the tanker and 160 m above it. Twelve seconds of look at 58 m/s is 700 m, and what a tanker
## climbs from there before it arrives is not 160 m; looking as far as 300 m of its own climb takes, it is.
const FACE_AHEAD: float = 1500.0
const FACE_RISE: float = 160.0
const FACE_LANE_X: float = -3000.0
## A WALL put 2 km ahead of the light aeroplane five seconds into its leg, three kilometres tall and three wide: nothing
## climbs over that, and a leg that is re-checked from where the aircraft is finds it within seconds.
const LEG_LANE_X: float = 3000.0
const BLOCK_AFTER: float = 5.0
const WALL_AHEAD: float = 2000.0
const WALL_TALL: float = 3000.0
const WALL_HALF_WIDE: float = 1500.0
## Where the light aeroplane may go: straight on, beyond where the wall will be, and off to one side, which the wall does
## not cover. The simulation insists on legs of at least 3 km for an aeroplane.
const STRAIGHT_ON := Vector3(0.0, 0.0, -6000.0)
const TO_ONE_SIDE := Vector3(5000.0, 0.0, -1000.0)
## A strike is this much speed gone in half a second: past any wing or brake.
const STRIKE: float = 20.0
const WATCH: float = 60.0
const EVERY: float = 0.5

var _failed: bool = false
var _said: Array[String] = []


func _ready() -> void:
	if not Sim.is_available():
		print("[avoid] extension missing")
		get_tree().quit(1)
		return
	await _start()
	Sim.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(7200.0, 400.0, 7200.0))

	# THE FACE, and a waypoint for tankers beyond it, so the tanker's only leg is one the face blocks and it flies at the
	# face level with nowhere to go -- which is what recovery is. Without a pool of its own a tanker borrows the light
	# aeroplane's, and would fly off to the other case.
	var face_top: float = HOLD + FACE_RISE
	Sim.add_static_box(Vector3(FACE_LANE_X, face_top * 0.5, -FACE_AHEAD), Vector3(1500.0, face_top * 0.5, 10.0))
	Sim.server.add_ai_waypoint(Sim.Kind.TANKER, Vector3(FACE_LANE_X, HOLD, -8000.0))
	var tanker_cruise: float = float(Sim.server.handling(Sim.Kind.TANKER).get("cruise", 58.0))
	var tanker: int = int(Sim.server.spawn_ai_vehicle(Sim.Kind.TANKER, Vector3(FACE_LANE_X, HOLD, 0.0), 0.0,
		Vector3(0.0, 0.0, -tanker_cruise)))

	Sim.server.add_ai_waypoint(Sim.Kind.PLANE, Vector3(LEG_LANE_X, HOLD, 0.0) + STRAIGHT_ON)
	Sim.server.add_ai_waypoint(Sim.Kind.PLANE, Vector3(LEG_LANE_X, HOLD, 0.0) + TO_ONE_SIDE)
	var plane_cruise: float = float(Sim.server.handling(Sim.Kind.PLANE).get("cruise", 70.0))
	var plane: int = int(Sim.server.spawn_ai_vehicle(Sim.Kind.PLANE, Vector3(LEG_LANE_X, HOLD, 0.0), 0.0,
		Vector3(0.0, 0.0, -plane_cruise)))
	_check("both_aircraft_exist", tanker != 0 and plane != 0, "tanker %d, plane %d" % [tanker, plane])

	var face := {"entity": tanker, "was": -1.0, "lost_most": 0.0, "over_it": -INF, "time": 0.0}
	var leg := {"entity": plane, "was": -1.0, "lost_most": 0.0, "inside": false, "time": 0.0, "wall_z": 0.0,
		"first_goal": Vector3.ZERO, "last_goal": Vector3.ZERO, "end_y": 0.0}
	var frames: int = int(round(EVERY / float(Sim.server.fixed_dt())))
	var blocked: bool = false
	for sample in range(int(WATCH / EVERY)):
		for i in range(frames):
			await get_tree().physics_frame
		var now: float = float(sample + 1) * EVERY
		_watch_the_face(face, face_top)
		if not blocked and now >= BLOCK_AFTER:
			blocked = true
			var at: Vector3 = Sim.server.vehicle_state(plane).get("position", Vector3.ZERO)
			leg["wall_z"] = at.z - WALL_AHEAD
			leg["first_goal"] = Sim.server.ai_destination(plane).get("waypoint", Vector3.ZERO)
			Sim.add_static_box(Vector3(LEG_LANE_X, WALL_TALL * 0.5, float(leg["wall_z"])),
				Vector3(WALL_HALF_WIDE, WALL_TALL * 0.5, 10.0))
		_watch_the_leg(leg, blocked)

	_check("a_tanker_level_at_a_rising_face_climbs_over_it",
		float(face["over_it"]) > face_top and float(face["lost_most"]) < STRIKE,
		"%.0f m up as it crossed a face whose top is %.0f m, and the most speed lost in half a second was %.1f m/s" % [
			float(face["over_it"]), face_top, float(face["lost_most"])])
	var side: Vector3 = Vector3(LEG_LANE_X, HOLD, 0.0) + TO_ONE_SIDE
	_check("a_light_aeroplane_whose_leg_is_blocked_goes_another_way",
		not bool(leg["inside"]) and float(leg["lost_most"]) < STRIKE
			and (leg["last_goal"] as Vector3).distance_to(side) < 1.0 and float(leg["end_y"]) > 300.0,
		"heading for %v when the wall went up and %v at the end, %s the wall, the most speed lost in half a second %.1f m/s, %.0f m up at the end" % [
			leg["first_goal"], leg["last_goal"], "inside" if bool(leg["inside"]) else "never inside",
			float(leg["lost_most"]), float(leg["end_y"])])
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


func _watch_the_face(face: Dictionary, face_top: float) -> void:
	face["time"] = float(face["time"]) + EVERY
	var state: Dictionary = Sim.server.vehicle_state(int(face["entity"]))
	if state.is_empty():
		return
	var at: Vector3 = state["position"]
	var speed: float = (state["velocity"] as Vector3).length()
	if float(face["was"]) >= 0.0 and float(face["time"]) > 1.0:
		face["lost_most"] = maxf(float(face["lost_most"]), float(face["was"]) - speed)
	face["was"] = speed
	# THE FIRST TIME IT IS AT THE FACE, and only then: see the wall in tests/climb.gd for what the highest sample did.
	if absf(at.z + FACE_AHEAD) < 60.0 and float(face["over_it"]) == -INF:
		face["over_it"] = at.y


func _watch_the_leg(leg: Dictionary, blocked: bool) -> void:
	leg["time"] = float(leg["time"]) + EVERY
	var entity: int = int(leg["entity"])
	var state: Dictionary = Sim.server.vehicle_state(entity)
	if state.is_empty():
		return
	var at: Vector3 = state["position"]
	var speed: float = (state["velocity"] as Vector3).length()
	if float(leg["was"]) >= 0.0 and float(leg["time"]) > 1.0:
		leg["lost_most"] = maxf(float(leg["lost_most"]), float(leg["was"]) - speed)
	leg["was"] = speed
	leg["end_y"] = at.y
	var goal: Dictionary = Sim.server.ai_destination(entity)
	if bool(goal.get("has_route", false)):
		leg["last_goal"] = goal["waypoint"]
	if blocked and absf(at.z - float(leg["wall_z"])) < 20.0 and absf(at.x - LEG_LANE_X) < WALL_HALF_WIDE + 10.0 \
			and at.y < WALL_TALL + 10.0:
		leg["inside"] = true


func _check(name: String, passed: bool, detail: String) -> void:
	print("[avoid] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
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
