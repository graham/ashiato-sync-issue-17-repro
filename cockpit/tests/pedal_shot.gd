extends Node
## THE PLANE'S PILOT LOOKING DOWN INTO THE FOOTWELL, with the rudder at rest and at full left, saved as two PNGs.
##
##   Godot --path cockpit res://tests/pedal_shot.tscn
##
## NOT HEADLESS -- it renders; headless has no rendering device and the file comes back a black rectangle. Either editor
## on the Windows workstation: the double build could not draw a window on the Mobile renderer (see "The controller in
## your hand shows what your fingers are doing" in agents.md) and draws on Forward+ since 2026-09-14.
##
## Exists because `tests/pedals.gd` proves the pedals move by their stated travel and cannot say whether eight
## centimetres of pedal on a dark floor can be SEEN from the seat, or whether the column and the console are in the way
## of seeing them at all. The player gets into a plane, the desk camera is tipped down at the footwell and held there,
## and each picture is taken with the world paused -- the rest first, then with the desk's Q held long enough for the
## pedals to reach their stops.
##
## Written into `user://pedal_shots/`: `rest.png` and `full_left.png`.

const OUT := "user://pedal_shots"
## How far down the eye looks, in radians: from 1.35 m over the anchor to pedals 0.46 m ahead on the floor is about 70
## degrees. The first pictures looked down 60 and put the floor under the HUD's card at the bottom of the frame.
const LOOK_DOWN: float = -1.22


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level := load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	for i in range(120):
		await get_tree().physics_frame
	var rig: PilotRig = level.rig
	rig.ask_for_kind(Sim.Kind.PLANE)
	for i in range(900):
		await get_tree().physics_frame
		if rig.vehicle_view() != null and rig.seat_index() == 0:
			break
	# A SECOND TO SETTLE, as controller_shot does: sitting down flashes the HUD for a jumped frame.
	for i in range(240):
		_look_down(rig)
		await get_tree().physics_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	await _shoot(rig, "rest")
	var q := InputEventKey.new()
	q.keycode = KEY_Q
	q.physical_keycode = KEY_Q
	q.pressed = true
	Input.parse_input_event(q)
	for i in range(30):
		_look_down(rig)
		await get_tree().physics_frame
	await _shoot(rig, "full_left")
	q = q.duplicate()
	q.pressed = false
	Input.parse_input_event(q)
	print("[pedal_shot] saved to %s/pedal_shots" % OS.get_user_data_dir())
	get_tree().quit(0)


func _shoot(rig: PilotRig, called: String) -> void:
	get_tree().paused = true
	for i in range(4):
		_look_down(rig)
		await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	get_tree().paused = false
	var file: String = "%s/%s.png" % [OUT, called]
	shot.save_png(file)
	var pedals: Array = rig.vehicle_view().station_for(rig.seat_index()).find_children("*", "RudderPedals", false, false)
	print("[pedal_shot] %s rudder %+.2f pedals %s" % [file, rig.rudder_sent(),
		(pedals[0] as RudderPedals).shown if not pedals.is_empty() else "none"])


func _look_down(rig: PilotRig) -> void:
	rig._look_yaw = 0.0
	rig._look_pitch = LOOK_DOWN
