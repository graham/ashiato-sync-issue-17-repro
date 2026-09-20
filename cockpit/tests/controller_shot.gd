extends Node
## BOTH CONTROLLERS FROM THE PILOT'S EYE, AT REST AND WITH EACH FINGER WORKED, saved as PNGs and one contact sheet.
##
##   Godot --path cockpit res://tests/controller_shot.tscn
##
## NOT HEADLESS -- it renders; headless has no rendering device and the file comes back a black rectangle. Use the stock
## editor on Linux, where the double build cannot open a window (see the workshop's CLAUDE.md).
##
## Exists because `tests/hands.gd` proves every part moves by its stated travel and turns amber, and cannot say whether
## three millimetres and a colour can be SEEN at arm's length. The player gets into a plane, both hands are held in front
## of the desk camera -- where a headset's hands would be -- and put back every frame, the world is paused for each
## picture, and every pose is taken twice: HELD, the top face tipped towards the eye as a controller is held, and SIDE,
## each controller turned to show its inside face, which is where the trigger's swing and the grip button are.
##
## Written into `user://controller_shots/`: one PNG per pose and view, and `sheet.png`, the middle of each frame in a
## grid, a row per pose in the order `poses` lists them, HELD on the left and SIDE on the right.

const OUT := "user://controller_shots"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# THE POSES, every finger on both hands at once. A float or bool for an input, and "grip" for the grip.
	var poses: Array = [
		["rest", {}],
		["trigger", {Bind.TRIGGER: 1.0}],
		["grip", {"grip": 1.0}],
		["upper_thumb", {Bind.THUMB_HIGH: true}],
		["lower_thumb", {Bind.THUMB_LOW: true}],
		["stick_right", {Bind.STICK: Vector2(1.0, 0.0)}],
		["stick_forward", {Bind.STICK: Vector2(0.0, 1.0)}],
		["stick_click", {Bind.STICK_CLICK: true}],
	]
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
	# AND A SECOND TO SETTLE: the first run's first two pictures were washed red by the HUD's jumped-frame flash from
	# sitting down.
	for i in range(240):
		await get_tree().physics_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var tiles: Array[Image] = []
	for view in ["held", "side"]:
		for pose in poses:
			var name_of: String = pose[0]
			var fingers: Dictionary = pose[1]
			for hand in range(2):
				rig.force_grip(hand, float(fingers.get("grip", 0.0)))
				for input in Bind.inputs():
					rig.force_input(hand, input, fingers.get(input, null))
			for i in range(8):
				_hold_the_hands(rig, view)
				await get_tree().process_frame
			get_tree().paused = true
			for i in range(4):
				_hold_the_hands(rig, view)
				await RenderingServer.frame_post_draw
			var shot: Image = get_viewport().get_texture().get_image()
			get_tree().paused = false
			var file: String = "%s/%s_%s.png" % [OUT, view, name_of]
			shot.save_png(file)
			print("[controller_shot] %s held %s %s writes L %d R %d" % [file, rig._held_by(0), rig._held_by(1),
				rig.controller_model(0).writes(), rig.controller_model(1).writes()])
			tiles.append(_middle_of(shot))
	for hand in range(2):
		rig.force_grip(hand, -1.0)
		for input in Bind.inputs():
			rig.force_input(hand, input, null)
	_sheet(tiles, poses.size()).save_png(OUT + "/sheet.png")
	print("[controller_shot] saved to %s/controller_shots" % OS.get_user_data_dir())
	get_tree().quit(0)


## BOTH HANDS WHERE A SEATED PILOT HOLDS THEM, 28 cm in front of the eye, 12 cm down and 9 cm either side, from where the
## eye is NOW -- the aeroplane moves on between frames.
func _hold_the_hands(rig: PilotRig, view: String) -> void:
	var eye: Transform3D = rig.desktop_camera.global_transform
	for hand in range(2):
		var side: float = -1.0 if hand == 0 else 1.0
		var turn := Basis(Vector3.RIGHT, deg_to_rad(50.0))
		if view == "side":
			# THE INSIDE FACE TO THE EYE: +90 degrees about up on the right hand, whose inside is -X; -90 on the left.
			turn = Basis(Vector3.UP, deg_to_rad(90.0 * side))
		var at := Vector3(side * (0.09 if view == "held" else 0.11), -0.12, -0.28)
		rig.force_hand(hand, eye * Transform3D(turn, at))


## The lower middle of a frame, where the two controllers are, at half size. The first sheet cut the middle of the frame
## and showed sky with the controllers cropped off its bottom edge.
static func _middle_of(shot: Image) -> Image:
	var size: Vector2i = shot.get_size()
	var cut := Rect2i(size.x / 4, size.y / 2, size.x / 2, size.y / 2)
	var tile: Image = shot.get_region(cut)
	tile.resize(cut.size.x / 2, cut.size.y / 2)
	return tile


## A POSE PER ROW, HELD on the left and SIDE on the right. `tiles` is every HELD pose and then every SIDE one.
static func _sheet(tiles: Array[Image], rows: int) -> Image:
	var tile: Vector2i = tiles[0].get_size()
	var sheet := Image.create_empty(tile.x * 2, tile.y * rows, false, tiles[0].get_format())
	for i in range(tiles.size()):
		sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tile), Vector2i(tile.x * (i / rows), tile.y * (i % rows)))
	return sheet
