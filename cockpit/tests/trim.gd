extends Node
## ONE AEROPLANE, LEFT ALONE, AND WHETHER IT FINDS LEVEL FLIGHT.
##
## Every other suite watches a hundred and forty machines do something. This watches ONE do
## nothing, which turns out to be the harder test: an autopilot that holds a heading and an
## altitude with no waypoint to chase has nowhere to hide, and a loop that is a shade too
## eager shows up as a slow porpoise rather than as a failure.
##
## AN AVERAGE CANNOT SEE AN OSCILLATION. A machine climbing and diving through its bug by
## a hundred metres has exactly the right mean altitude, so what is measured here is the
## PEAK-TO-PEAK swing and the number of times the climb rate changes sign. Both are small
## for an aeroplane in trim and neither is small for one that is hunting.
##
## No world, no terrain, no traffic: an empty sky, one aeroplane in it, and the autopilot's
## own recovery height as the thing it is asked to hold.

## How long to let it settle before anything is written down, and how long to watch after.
const SETTLE: float = 25.0
const WATCH: float = 60.0
## The height an aeroplane with nowhere to go holds, from `recovery_height` in the mixer.
const HOLD: float = 520.0

var _failed: bool = false
var _said: Array[String] = []
## `-- --set=... --kind=...`: see `TuningCard`. Empty, and nothing is retuned or skipped.
var _card: TuningCard = TuningCard.from_command_line()


func _ready() -> void:
	if not Sim.is_available():
		print("[trim] extension missing")
		get_tree().quit(1)
		return
	await _start()
	if not _card.is_empty():
		print("[trim] %s" % _card.clip_on())
	# EVERY WING IN THE GAME, and the water bomber belongs in the list for the reason the
	# airliner earned its place: it is a big, heavy, slow aeroplane, and the accident that
	# put the airliner in the sea was a cruise three per cent over its own stall. A tanker
	# spends its working life at a hundred and fifty feet with the flaps out.
	# EVERY KIND THAT LEAVES THE GROUND, and the list is the whole point.
	#
	# It used to be five, and the three that were missing were the three nobody had ever
	# watched fly on its own: the gunship, the chinook and the helicopter. Two of those had
	# no waypoint pool at all until the commit before this one, so they were being flown by
	# an autopilot with no destination -- which is a machine that holds no altitude and
	# descends until it hits something, and is exactly what "some of the planes don't fly
	# that well" looks like from the ground.
	#
	# A list of kinds is a list somebody has to remember to add to. This one is derived: if
	# the simulation says a kind stalls, it has a wing, and if it has a wing it has to be
	# able to hold level flight on its own.
	for kind in _everything_with_a_wing():
		if _card.flies(kind):
			await _fly_one(kind)
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


## EVERY KIND THE SIMULATION WILL FLY, asked of the simulation rather than typed out.
##
## A rotor counts. A helicopter holding a hover with nowhere to go is the same question as
## an aeroplane holding a cruise, and it is the one a player sees first: the machine they
## are not in, in the air beside them, either sitting there or sinking.
##
## THE GROUND-BOUND ONES ARE SKIPPED, and cheaply: a car's model has no stall speed because
## a car does not stall, so anything the handling table gives a stall to is something with
## a wing or a rotor under it.
func _everything_with_a_wing() -> Array:
	var out: Array = []
	for kind in range(Sim.Kind.size()):
		# THE MODEL IS ON THE GEOMETRY, not on the handling. `handling` is the numbers a
		# model is flown WITH -- thrust, stall, lift -- and which model it is belongs to the
		# shape. Asking the wrong one returns no key, the default lands on -1, and the
		# suite cheerfully flies nothing and reports PASS.
		var model: int = int(Sim.geometry_of(kind).get("model", -1))
		if model == Sim.Model.AIRPLANE or model == Sim.Model.HELICOPTER 				or model == Sim.Model.TILTROTOR:
			out.append(kind)
	return out


func _fly_one(kind: int) -> void:
	var name: String = Sim.kind_name(kind)
	var cruise: float = Terrain.cruise_for(kind)
	var craft: int = int(Sim.server.spawn_ai_vehicle(kind,
		Vector3(0.0, HOLD, 0.0), 0.0, Vector3(0.0, 0.0, -cruise)))
	if craft == 0:
		_check("%s_exists" % name, false, "nothing spawned")
		return

	var step: float = float(Sim.server.fixed_dt())
	for i in range(int(SETTLE / step)):
		await get_tree().physics_frame

	var highest: float = -1e9
	var lowest: float = 1e9
	var slowest: float = 1e9
	var flips: int = 0
	var was_climbing: int = 0
	var still_there: bool = true
	for i in range(int(WATCH / step)):
		await get_tree().physics_frame
		var state: Dictionary = Sim.server.vehicle_state(craft)
		if state.is_empty():
			still_there = false
			break
		var at: Vector3 = state["position"]
		var going: Vector3 = state["velocity"]
		highest = maxf(highest, at.y)
		lowest = minf(lowest, at.y)
		slowest = minf(slowest, going.length())
		# SIGN CHANGES IN THE CLIMB RATE, ignoring the dither about zero that any aeroplane
		# has. A machine in trim crosses a few times in a minute; one that is porpoising
		# crosses on every half cycle and there are a lot of half cycles.
		var climbing: int = 0
		if going.y > 0.6:
			climbing = 1
		elif going.y < -0.6:
			climbing = -1
		if climbing != 0 and was_climbing != 0 and climbing != was_climbing:
			flips += 1
		if climbing != 0:
			was_climbing = climbing

	# A GLIDER IS MEASURED AGAINST WHAT A GLIDER DOES, which is not level flight.
	#
	# It has no engine, so height is the only fuel it has and it must spend some. What it
	# must NOT do is stall: a steady sink at its published rate is a glide, and 479 m in a
	# minute with the speed reaching zero is an aeroplane falling.
	var sinks: bool = float(Sim.server.handling(kind).get("thrust", 1.0)) <= 0.0
	var room: float = 400.0 if sinks else 70.0
	_check("%s_is_still_in_the_air" % name, still_there and lowest > 40.0 if sinks
			else still_there and lowest > 200.0,
		"the lowest it got was %.0f m" % lowest)
	_check("%s_holds_its_height" % name, highest - lowest < room,
		"it %s %.0f m between %.0f and %.0f" % ["sank" if sinks else "wandered",
			highest - lowest, lowest, highest])
	_check("%s_is_not_porpoising" % name, flips <= 4,
		"the climb changed sign %d times in a minute" % flips)
	# THE STALL IS A WING'S PROBLEM AND NOBODY ELSE'S.
	#
	# `stall_speed` is sqrt(weight / (camber * lift)), which is a real number for a wing and
	# arithmetic for anything else: a helicopter came out at 940 m/s and a chinook at 3836,
	# because a rotor carries its weight with terms this formula has never heard of. Asked of
	# a hovering helicopter it reported a stall at three times the speed of sound.
	#
	# A rotorcraft hovering at nothing is a rotorcraft doing its job, so the question does
	# not apply and is not asked.
	var model: int = int(Sim.geometry_of(kind).get("model", -1))
	if model == Sim.Model.AIRPLANE or model == Sim.Model.TILTROTOR:
		var stall: float = float(Sim.server.handling(kind).get("stall_speed", 0.0))
		_check("%s_keeps_its_speed_up" % name, slowest > stall * 1.05,
			"slowest was %.0f m/s against a stall of %.0f" % [slowest, stall])
	Sim.server.despawn_vehicle(craft)
	for i in range(4):
		await get_tree().physics_frame


func _check(name: String, passed: bool, detail: String) -> void:
	print("[trim] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
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
