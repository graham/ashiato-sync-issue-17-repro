extends Node
## THE BOAT'S TWO HELMS, WITH THE WHEEL AT THIS SEAT SHOWING WHAT THE OTHER PILOT IS DOING.
##
##   Godot --path cockpit res://tests/helm_shot.tscn
##
## NOT HEADLESS -- it renders; headless has no rendering device and the file comes back a black
## rectangle. See `tests/pedal_shot.gd`, which this is built from.
##
## WHAT IT IS FOR. Reported from a session: "both steering wheels should be able to control the boat
## (and that works) but i don't see the other players inputs in my wheel if i'm not holding it."
## `tests/crew_sync.gd` proves the number -- seventeen craft where the wheel at this seat read 0.00
## while the other helm asked 0.70 -- and a number is not a picture of a wheel. This is the picture:
## the same wheel, from the same seat, with the other helm amidships and then hard over. Until
## 2026-09-15 the two frames were identical.
##
## HOW THE OTHER PILOT STEERS. A second crew member is spawned and seated by the server, and their
## control frame is written straight into their pilot entity -- which is where a real second
## machine's frame arrives after the wire. What is under test here is the PICTURE, not the transport;
## `addon/tests/cockpit_loopback.gd` owns the transport.
##
## Written into `user://helm_shots/`: `amidships.png` and `hard_over.png`.

const OUT := "user://helm_shots"
## How hard the other pilot puts their wheel over. Full lock, so the picture is unambiguous.
const OVER: float = 1.0
## How long the linkage is given to arrive, in physics frames: a second at 120 Hz, two orders more
## than a solo world needs.
const PATIENCE: int = 120
## HOW FAR ALONG THE LINE BETWEEN THE TWO WHEELS THE EYE LOOKS, 0 at this seat's and 1 at the other.
## The midpoint was tried and put the near wheel half out of the bottom-right corner: it is a metre
## from the eye and the other helm is four, so an aim that splits the difference in SPACE does not
## split it on the SCREEN. Weighted back toward the near one, which is the wheel the picture is of.
const TOWARD_THEIRS: float = 0.22

var _mate: int = 0
var _input: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level := load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	for i in range(120):
		await get_tree().physics_frame
	var rig: PilotRig = level.rig
	rig.ask_for_kind(Sim.Kind.BOAT)
	for i in range(900):
		await get_tree().physics_frame
		if rig.vehicle_view() != null and rig.vehicle_view().kind == Sim.Kind.BOAT:
			break
	var view: VehicleView = rig.vehicle_view()
	if view == null or view.kind != Sim.Kind.BOAT:
		print("[helm_shot] could not get into a boat")
		get_tree().quit(1)
		return
	var mine: int = rig.seat_index()
	var theirs: int = 1 if mine == 0 else 0
	if not await _seat_a_mate(view, theirs):
		print("[helm_shot] could not seat a second helmsman at seat %d" % theirs)
		get_tree().quit(1)
		return

	var here := view.controls_for(mine).get("stick") as VehicleControl
	var there := view.controls_for(theirs).get("stick") as VehicleControl
	if here == null or there == null:
		print("[helm_shot] a helm is missing: %s and %s" % [here, there])
		get_tree().quit(1)
		return
	# AIMED AT BOTH WHEELS AT ONCE, from wherever the seat happens to put the eye, rather than at a
	# pair of angles typed in. Two helms on one bridge are not in the same place on every hull, and
	# a picture whose whole point is that two objects agree has to have both of them in it.
	var at: Vector3 = here.grip_global().lerp(there.grip_global(), TOWARD_THEIRS)

	DirAccess.make_dir_recursive_absolute(OUT)
	# AMIDSHIPS FIRST, so there is something to compare against. A picture of a wheel hard over is
	# only worth anything beside a picture of the same wheel straight.
	_input = _controls()
	for i in range(PATIENCE):
		_look_at(rig, at)
		await get_tree().physics_frame
	await _shoot(rig, "amidships", here, there)

	# AND NOW THE OTHER PILOT PUTS THEIRS HARD OVER, with nobody at this seat touching anything.
	_input = _controls({"roll": OVER})
	for i in range(PATIENCE):
		_look_at(rig, at)
		await get_tree().physics_frame
	await _shoot(rig, "hard_over", here, there)

	print("[helm_shot] saved to %s/helm_shots" % OS.get_user_data_dir())
	get_tree().quit(0)


func _shoot(rig: PilotRig, called: String, here: VehicleControl, there: VehicleControl) -> void:
	get_tree().paused = true
	for i in range(4):
		await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	get_tree().paused = false
	var file: String = "%s/%s.png" % [OUT, called]
	shot.save_png(file)
	# THE NUMBERS BESIDE THE PICTURE, so a frame that looks wrong can be told from a frame that is --
	# including the angle each wheel is actually DRAWN at. The right-hand seat of a pair is the left
	# one mirrored (`CockpitStation._mirror_the_layout`), and a mirror that flipped the wheel's own
	# mesh would have the two helms turning opposite ways while both reported the same value. It
	# does not: the mirror moves a control's position and its y and z rotation, and the rim turns
	# inside the control. The two numbers below are what says so, and they are the same number.
	print("[helm_shot] %s: the other helm %+.2f drawn %+.2f rad, the wheel at this seat %+.2f drawn"
		% [file, there.roll(), _drawn(there), here.roll()]
		+ " %+.2f rad, held by %d" % [_drawn(here), here.held_by])


## THE ANGLE A WHEEL'S RIM IS ACTUALLY TURNED THROUGH, in radians, off the node that turns.
func _drawn(wheel: VehicleControl) -> float:
	var rim := wheel.get_node_or_null("../%s" % wheel.name) as Node3D
	for child in wheel.get_children():
		var node := child as Node3D
		if node != null and not (node is MeshInstance3D) and node.get_child_count() > 0:
			rim = node
			break
	return rim.rotation.z if rim != null else 0.0


## A SECOND HELMSMAN, made the way the server makes one and seated by the server, which is the only
## thing that decides who sits where.
func _seat_a_mate(view: VehicleView, seat: int) -> bool:
	var craft: int = 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			craft = int((pilot as Dictionary).get("vehicle", 0))
	if craft == 0:
		return false
	var made: Dictionary = Sim.server.spawn_pilot(201, Sim.Kind.POD,
		Vector3(3000.0, 4.0, 3000.0), 0.0, Vector3.ZERO)
	_mate = int(made.get("pilot", 0))
	if _mate == 0 or not Sim.server.seat_client(201, craft, seat):
		return false
	for i in range(PATIENCE):
		await get_tree().physics_frame
		if view.station_for(seat) != null:
			return true
	return false


## WHERE THE DESK CAMERA IS POINTING, worked out from where the thing to look at IS.
##
## `desktop_camera.rotation` is `(pitch, yaw, 0)` in the ORIGIN's frame and Godot composes Euler
## angles as Y then X, so a camera's forward is `(-sin(yaw)cos(pitch), sin(pitch), -cos(yaw)cos(pitch))`
## -- which inverts to the two lines below. Typing a pair of angles instead would be a picture that
## is only aimed correctly on the hull it was aimed on.
func _look_at(rig: PilotRig, target: Vector3) -> void:
	var origin: Node3D = rig.desktop_camera.get_parent() as Node3D
	if origin == null:
		return
	var local: Vector3 = origin.global_transform.affine_inverse() * target
	var away: Vector3 = (local - rig.desktop_camera.position).normalized()
	rig._look_yaw = atan2(-away.x, -away.z)
	rig._look_pitch = asin(clampf(away.y, -1.0, 1.0))


func _physics_process(_delta: float) -> void:
	if _mate != 0 and not _input.is_empty():
		Sim.server.set_pilot_input(_mate, _input)


func _controls(overrides: Dictionary = {}) -> Dictionary:
	var input: Dictionary = {
		"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"head": Vector3.ZERO, "head_basis": Quaternion.IDENTITY,
		"left": Vector3(-0.25, -0.35, -0.30), "left_basis": Quaternion.IDENTITY,
		"right": Vector3(0.25, -0.35, -0.30), "right_basis": Quaternion.IDENTITY,
		"grip_left": 0.0, "grip_right": 0.0, "buttons": 0, "trigger": 0.0,
	}
	for key in overrides:
		input[key] = overrides[key]
	return input
