extends Node
## Headless: THE BATTLESHIP GUNNER'S RANGING SIGHT, worked from a desk -- laid with the keys, read off the glass, fired, and
## the fall of shot spotted.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/ranging_sight.tscn
##
## Plan item 22c, the user's words: "build a sight for them, they can fire and gauge distance". The sight is `RangeSight`:
## a level line along the turret's bearing, a mil scale to judge a target's distance by its size, a drum that says where
## the laid gun's shell lands, and the fall of shot. It measures no target; the gunner gauges and brackets.
##
## RULE 0, THE DESK. Everything here is the real level and the real rig at a monitor: the gunner sits at the forward turret
## seat, lays the gun with the desk's pitch and roll keys and fires with its fire key, pressed as key events with both
## codes set, and what is read is the sight the station fitted, where the desk camera sees it.
##
## WHAT HEADLESS CANNOT HOLD, and tests/ranging_sight_shot.gd does: that a mark on the rendered picture subtends the mils
## it says against a real object at a real range, and that the splash can be seen from the seat at six kilometres.
##
## Read RESULT=, not the exit code.

const BATTLESHIP: int = 13
const SEAT: int = 2
## How far a mark may be from its stated angle from the eye, as a share of that angle.
const MILS_AGREE: float = 0.01
## THE HEADSET'S PIXELS, as the builder suite counts them: twenty a degree, a Quest 2. See tests/builder.gd.
const HEADSET_PIXELS_PER_DEGREE: float = 20.0
const LEAST_WORD_PIXELS: float = 20.0
## HOW FAR THE KEYS TRAIN THE TURRET for the desk camera's check, seconds of a held key: at four degrees a second, twenty
## degrees -- well past where a view fixed over the bow still had the crosshair in its middle.
const TRAIN_S: float = 5.0
## How far the desk camera may look from the turret's bearing, degrees.
const FACES_DEG: float = 0.3
const LEFT: int = 0
## THE BEAMS the drum is held on (plan item 22e), as the mount's train, radians: starboard, then port. On the beam a hull's
## roll is all elevation.
const BEAMS: Array[float] = [-PI * 0.5, PI * 0.5]
## How far a drum may be from where the shell lands, as a share of the range.
const DRUM_LANDS_SHARE: float = 0.01
## How far a drum reading may be from the simulation's own reach at the barrel's world elevation, read on the same drawn
## frame, metres: the board rounds to one. A 1% allowance here once hid a drum 200 ms stale (see RangeSight.show_drum).
const DRUM_AGREES_M: float = 1.0
## How much the hull must be tilting the barrel against the world when it fires, degrees: the roll is what is being held,
## so the shot waits for one. The battleship rolls about +/-0.8 degrees at rest (2026-09-16).
const TILTED_AT_LEAST_DEG: float = 0.15
## How far a hand pushes the stick sideways, metres, and for how long: tests/gunners.gd's full deflection.
const SHOVE: float = 0.12
const SHOVE_S: float = 2.0

var _failures: PackedStringArray = []
var _level: FlightLevel = null


func _check(label: String, ok: bool, detail: String) -> void:
	print("[ranging_sight] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	for i in range(240):
		await get_tree().physics_frame
	var rig: PilotRig = _level.rig
	var sight: RangeSight = await _sit_at_the_forward_turret(rig)
	if sight == null:
		_finish()
		return
	_the_horizon_stays_level_on_a_rolled_ship()
	await _the_sight_is_in_front_of_the_desk_camera(rig, sight)
	await _the_desk_keys_lay_the_gun_and_the_drum_follows(rig, sight)
	await _the_crosshair_follows_the_train(rig, sight)
	await _in_a_headset_the_view_is_not_turned_with_the_turret(rig, sight)
	_the_other_turret_s_sight_is_not_drawn_for_this_gunner(rig, sight)
	await _the_train_arrow_points_the_shorter_way_to_the_gun(rig, sight)
	await _every_mark_is_at_its_angle_from_the_eye(rig, sight)
	_the_marks_and_words_can_be_read_in_a_headset(rig, sight)
	await _the_fire_key_fires_and_the_fall_of_shot_is_spotted(rig, sight)
	for beam in BEAMS:
		await _on_the_beam_the_drum_reads_where_the_shell_lands(rig, sight, beam)
	_finish()


## ---- the seat ----------------------------------------------------------------------------------------------------

func _sit_at_the_forward_turret(rig: PilotRig) -> RangeSight:
	rig.ask_for_kind(BATTLESHIP)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == BATTLESHIP:
			break
	if view == null or view.kind != BATTLESHIP:
		_check("the_player_gets_into_a_battleship", false, "kind %s" % [view.kind if view != null else "-"])
		return null
	# THE SERVER'S NUMBER FOR THE CRAFT, off its own pilot list (see tests/gunners.gd, which paid for it).
	var craft: int = 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary).get("client", -1)) == Sim.local_client_id():
			craft = int((pilot as Dictionary).get("vehicle", 0))
	Sim.server.seat_client(Sim.local_client_id(), craft, SEAT)
	var sight: RangeSight = null
	for i in range(300):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and rig.seat_index() == SEAT and view.station_for(SEAT) != null:
			sight = view.station_for(SEAT).get_node_or_null("RangeSight") as RangeSight
			if sight != null:
				break
	var trigger := view.station_for(SEAT).controls().get("trigger") as GunTrigger if sight != null else null
	_check("the_forward_turret_seat_has_a_ranging_sight_and_a_trigger", sight != null and trigger != null,
		"seat %d, sight %s, trigger %s, desk %s" % [rig.seat_index(), sight, trigger, rig.using_desktop])
	return sight


## ---- the glass --------------------------------------------------------------------------------------------------

## A ROLLED SHIP DOES NOT ROLL THE HORIZON: the sight is level with the world, whatever the hull is doing. On its own, with
## a hull rolled twelve degrees and trained forty degrees to port.
func _the_horizon_stays_level_on_a_rolled_ship() -> void:
	var sight := RangeSight.new()
	add_child(sight)
	var rolled := Transform3D(Basis(Vector3.BACK, deg_to_rad(12.0)), Vector3(10.0, 5.0, -20.0))
	sight.follow(Vector3(10.0, 7.0, -20.0), rolled, Vector2(deg_to_rad(40.0), 0.1))
	var up: float = sight.global_basis.y.normalized().dot(Vector3.UP)
	var ahead: Vector3 = -sight.global_basis.z.normalized()
	var wanted: Vector3 = rolled.basis * Vector3(-sin(deg_to_rad(40.0)), 0.0, -cos(deg_to_rad(40.0)))
	wanted.y = 0.0
	var off: float = ahead.angle_to(wanted.normalized())
	sight.queue_free()
	_check("the_horizon_stays_level_on_a_rolled_ship_and_the_crosshair_on_the_bearing", up > 0.99999 and off < 0.001,
		"up . world up %.6f, %.4f rad off the bearing" % [up, off])


func _the_sight_is_in_front_of_the_desk_camera(rig: PilotRig, sight: RangeSight) -> void:
	for i in range(10):
		await get_tree().process_frame
	var camera: Camera3D = rig.desktop_camera
	var from_eye: float = sight.centre().distance_to(camera.global_position)
	var board: Label3D = sight.get_node_or_null("Board") as Label3D
	_check("at_a_desk_the_reticle_and_the_board_are_in_view", camera.current and absf(from_eye - RangeSight.AT) < 0.01
		and camera.is_position_in_frustum(sight.centre()) and board != null
		and camera.is_position_in_frustum(board.global_position),
		"camera current %s, reticle %.3f m from the eye, reticle in view %s, board in view %s" % [camera.current,
			from_eye, camera.is_position_in_frustum(sight.centre()),
			camera.is_position_in_frustum(board.global_position) if board != null else false])


## ---- laying ---------------------------------------------------------------------------------------------------

func _the_desk_keys_lay_the_gun_and_the_drum_follows(rig: PilotRig, sight: RangeSight) -> void:
	var before: Vector2 = _laid()
	await _hold("pitch_up", 120)
	await _hold("pitch_down", 12)
	for i in range(60):
		await get_tree().physics_frame
	# ON A DRAWN FRAME, AS THE DRUM IS: right after the frame the sight wrote it on, so the check reads the same hull pose.
	await get_tree().process_frame
	var after: Vector2 = _laid()
	var said: String = sight.says()
	var drum: float = _read(said, "RANGE ")
	var world: float = _world_elevation(rig, after)
	var started_us: int = Time.get_ticks_usec()
	var reach: float = float(Sim.shell_reach(BATTLESHIP, sight.mount, world).get("range", -1.0))
	print("[ranging_sight] measure: one shell_reach, which the drum now asks every drawn frame, took %d us" % (
		Time.get_ticks_usec() - started_us))
	_check("the_desk_keys_raise_the_gun", after.y > before.y + 0.02,
		"elevation %.3f deg then %.3f deg" % [rad_to_deg(before.y), rad_to_deg(after.y)])
	# AGAINST THE WORLD, NOT THE SHIP (plan item 22e): the shell is flown from the barrel as it points in the world, and the
	# hull under it rolls. Until 22e this compared the drum with the reach at the SHIP-relative elevation, which a drum
	# sharing the ship's frame passed while beam shots landed 150 m off.
	_check("and_the_drum_reads_the_reach_of_the_barrel_as_it_points_in_the_world",
		drum > 0.0 and absf(drum - reach) <= DRUM_AGREES_M,
		"drum %.0f m; the simulation's reach %.1f m at %.3f deg in the world (%.3f against the ship) (%s)" % [drum, reach,
			rad_to_deg(world), rad_to_deg(after.y), said.replace("\n", " | ")])


func _the_crosshair_follows_the_train(rig: PilotRig, sight: RangeSight) -> void:
	var before: Vector2 = _laid()
	await _hold("roll_right", int(TRAIN_S * 120.0))
	for i in range(30):
		await get_tree().process_frame
	var after: Vector2 = _laid()
	var view: VehicleView = rig.vehicle_view()
	var wanted: Vector3 = view.global_basis * Vector3(-sin(after.x), 0.0, -cos(after.x))
	wanted.y = 0.0
	var ahead: Vector3 = -sight.global_basis.z
	ahead.y = 0.0
	var off: float = ahead.normalized().angle_to(wanted.normalized())
	var trained: float = rad_to_deg(angle_difference(before.x, after.x))
	_check("the_desk_keys_train_the_turret_and_the_crosshair_goes_with_it", absf(trained) > 15.0 and off < 0.002,
		"trained %.2f deg; the crosshair %.3f deg off the bearing" % [trained, rad_to_deg(off)])
	# AND THE DESK CAMERA TURNS WITH IT, so the sight stays in the middle of the monitor. Plan item 22c, rule 0: the view
	# was fixed over the bow, and a turret trained past the window's half-width took the sight and its target off screen.
	var camera: Camera3D = rig.desktop_camera
	var looking: Vector3 = -camera.global_basis.z
	looking.y = 0.0
	var faces: float = rad_to_deg(looking.normalized().angle_to(wanted.normalized()))
	var on_screen: Vector2 = camera.unproject_position(sight.centre()) / camera.get_viewport().get_visible_rect().size
	_check("and_at_a_desk_the_camera_turns_with_the_turret_keeping_the_sight_mid_screen", faces < FACES_DEG
		and absf(on_screen.x - 0.5) < 0.02, "the camera looks %.3f deg off the bearing; the crosshair at %.3f across the screen"
		% [faces, on_screen.x])


## IN A HEADSET THE VIEW IS NEVER TURNED FOR THE PLAYER. A seat that yawed a player's eyes with the turret, with no head
## motion, is the classic comfort failure, slow or not. So with the rig in its headset mode the turret is trained by a
## hand on the station's stick -- the headset's own path, tests/gunners.gd's full deflection -- and neither camera may
## have turned. The mode is set on the rig's two flags rather than through OpenXR, which no suite machine has.
func _in_a_headset_the_view_is_not_turned_with_the_turret(rig: PilotRig, sight: RangeSight) -> void:
	var station: CockpitStation = rig.vehicle_view().station_for(SEAT)
	var stick := station.controls().get("stick") as FlightStick
	_check("the_turret_seat_has_a_stick_to_train_with_in_a_headset", stick != null, "%s" % [stick])
	if stick == null:
		return
	rig.using_desktop = false
	rig.using_xr = true
	var desk_before: Basis = rig.desktop_camera.basis
	var head_before: Basis = rig.camera.basis
	var before: Vector2 = _laid()
	rig.force_grip(LEFT, 1.0)
	for i in range(8):
		rig.force_hand(LEFT, Transform3D(Basis.IDENTITY, stick.grip_global()))
		await get_tree().physics_frame
	var held: bool = stick.held_by == LEFT
	var pushed: Vector3 = stick._grab_point() + Vector3(SHOVE, 0.0, 0.0)
	for i in range(int(SHOVE_S * 120.0)):
		rig.force_hand(LEFT, Transform3D(Basis.IDENTITY, stick.global_transform * pushed))
		await get_tree().physics_frame
	var after: Vector2 = _laid()
	var desk_turned: float = rad_to_deg((-desk_before.z).angle_to(-rig.desktop_camera.basis.z))
	var head_turned: float = rad_to_deg((-head_before.z).angle_to(-rig.camera.basis.z))
	rig.force_hand(LEFT, null)
	rig.force_grip(LEFT, -1.0)
	rig.using_xr = false
	rig.using_desktop = true
	for i in range(10):
		await get_tree().physics_frame
	var trained: float = rad_to_deg(angle_difference(before.x, after.x))
	_check("in_a_headset_a_hand_on_the_stick_trains_the_turret_and_neither_camera_turns_with_it",
		held and absf(trained) > 3.0 and desk_turned < 0.01 and head_turned < 0.01,
		"held %s; trained %.2f deg; the desk camera turned %.3f deg (against the craft, which it rides), the headset's %.3f"
		% [held, trained, desk_turned, head_turned])


## THE OTHER TURRET'S SIGHT IS NOT DRAWN FOR THIS GUNNER. Every turret station has a sight that follows the drawing
## camera, and until 22e the one nobody here sat at drew too: turret 3's, trained aft, wrote TRAIN > over turret 2's drum
## in the picture from seat 2. Checked with turret 2 trained twenty degrees off the bow, where turret 3's bearing is far
## outside the view and its arrow would show.
func _the_other_turret_s_sight_is_not_drawn_for_this_gunner(rig: PilotRig, sight: RangeSight) -> void:
	var other_station: CockpitStation = rig.vehicle_view().station_for(3)
	var other := other_station.get_node_or_null("RangeSight") as RangeSight if other_station != null else null
	var arrow := other.get_node_or_null("Train") as Label3D if other != null else null
	_check("the_aft_turret_s_sight_and_its_train_arrow_are_not_drawn_for_the_forward_gunner",
		other != null and not other.is_visible_in_tree() and arrow != null and not arrow.is_visible_in_tree()
			and sight.is_visible_in_tree(),
		"aft sight drawn %s, its arrow drawn %s; this gunner's sight drawn %s" % [
			other.is_visible_in_tree() if other != null else "-", arrow.is_visible_in_tree() if arrow != null else "-",
			sight.is_visible_in_tree()])


## THE TRAIN ARROW POINTS THE SHORTER WAY TO THE GUN (plan item 22d). The seat is fixed to the hull and the gunner turns
## their head to the gun, so a gunner looking away is told which way it is -- "TRAIN <" when the bearing is to the left
## of the view, "TRAIN >" to the right -- once it is more than `RangeSight.TRAIN_SHOWN_DEG` off, in front of the eye and at
## least twenty headset pixels tall. Through the real paths: at a desk the camera follows the turret, so no arrow; the
## MOUSE turns the desk view away (captured, as a desk has it); in a headset the HEAD turns, as a tracked pose does.
func _the_train_arrow_points_the_shorter_way_to_the_gun(rig: PilotRig, sight: RangeSight) -> void:
	for i in range(10):
		await get_tree().process_frame
	var following: String = sight.train_says()
	var bearing: Vector3 = -sight.global_basis.z
	bearing.y = 0.0
	bearing = bearing.normalized()
	# THE MOUSE, NINETY DEGREES TO THE LEFT: the bearing is then to the right. SET AS THE MOUSE SETS IT, on the rig's look
	# yaw: the rig turns the desk view only while the mouse is captured, and a headless display does not capture it
	# (measured: Input.mouse_mode read back VISIBLE after being set to CAPTURED, 2026-09-16), so a motion event is ignored.
	var look_before: float = float(rig.get("_look_yaw"))
	rig.set("_look_yaw", look_before + deg_to_rad(90.0))
	for i in range(10):
		await get_tree().process_frame
	var desk_away: String = sight.train_says()
	var desk_seen: bool = rig.desktop_camera.is_position_in_frustum(sight.train_at())
	var desk_px: float = _headset_pixels_of(sight, rig.desktop_camera.global_position)
	rig.set("_look_yaw", look_before)
	for i in range(10):
		await get_tree().process_frame
	var desk_back: String = sight.train_says()
	_check("at_a_desk_no_train_arrow_while_the_camera_follows_and_looking_left_of_the_gun_says_train_right",
		following == "" and desk_away == "TRAIN >" and desk_seen and desk_px >= LEAST_WORD_PIXELS and desk_back == "",
		"following %s; looking 90 deg left %s (in view %s, %.1f headset px, at least %.0f); back %s" % [_said(following),
			_said(desk_away), desk_seen, desk_px, LEAST_WORD_PIXELS, _said(desk_back)])
	# THE HEAD, IN HEADSET MODE: turned ninety degrees to the right of the bearing, then back onto it.
	rig.using_desktop = false
	rig.using_xr = true
	var head: XRCamera3D = rig.camera
	var head_before: Transform3D = head.transform
	head.make_current()
	head.global_transform = Transform3D(Basis.looking_at(bearing.rotated(Vector3.UP, -PI * 0.5), Vector3.UP),
		head.global_position)
	for i in range(10):
		await get_tree().process_frame
	var head_away: String = sight.train_says()
	var head_seen: bool = head.is_position_in_frustum(sight.train_at())
	var head_px: float = _headset_pixels_of(sight, head.global_position)
	head.global_transform = Transform3D(Basis.looking_at(bearing.rotated(Vector3.UP, deg_to_rad(20.0)), Vector3.UP),
		head.global_position)
	for i in range(10):
		await get_tree().process_frame
	var head_near: String = sight.train_says()
	head.transform = head_before
	rig.desktop_camera.make_current()
	rig.using_xr = false
	rig.using_desktop = true
	for i in range(10):
		await get_tree().process_frame
	_check("in_a_headset_the_head_turned_right_of_the_gun_says_train_left_and_within_thirty_degrees_nothing",
		head_away == "TRAIN <" and head_seen and head_px >= LEAST_WORD_PIXELS and head_near == "",
		"head 90 deg right of the bearing %s (in view %s, %.1f headset px); 20 deg left of it %s" % [_said(head_away),
			head_seen, head_px, _said(head_near)])


static func _said(text: String) -> String:
	return "\"%s\"" % text if text != "" else "nothing"


## How tall the TRAIN arrow's writing is from `eye`, in headset pixels.
func _headset_pixels_of(sight: RangeSight, eye: Vector3) -> float:
	var word := sight.get_node_or_null("Train") as Label3D
	if word == null:
		return 0.0
	var tall: float = float(word.font_size) * word.pixel_size
	return rad_to_deg(atan(tall / eye.distance_to(word.global_position))) * HEADSET_PIXELS_PER_DEGREE


## EVERY TICK IS AT ITS OWN ANGLE FROM THE EYE -- measured from the desk camera, not from the sight's own arithmetic.
func _every_mark_is_at_its_angle_from_the_eye(rig: PilotRig, sight: RangeSight) -> void:
	await get_tree().process_frame
	var eye: Vector3 = rig.desktop_camera.global_position
	var centre: Vector3 = sight.scale_centre() - eye
	var worst: float = 0.0
	var said: PackedStringArray = []
	for k in range(1, RangeSight.TICKS + 1):
		for side in [-1, 1]:
			var mils: int = side * k * RangeSight.TICK_MILS
			var at: Vector3 = sight.tick_at(mils) - eye
			var measured: float = centre.angle_to(at) * 1000.0
			var wanted: float = float(absi(mils))
			worst = maxf(worst, absf(measured - wanted) / wanted)
			if k == RangeSight.TICKS and side > 0:
				said.append("%d mils read %.2f" % [mils, measured])
	_check("every_mil_tick_is_at_its_angle_from_the_desk_eye", worst <= MILS_AGREE,
		"worst %.2f%% off; %s" % [worst * 100.0, ", ".join(said)])


## LEGIBLE IN A HEADSET: the thinnest line and the smallest numeral, in headset pixels from the eye.
func _the_marks_and_words_can_be_read_in_a_headset(rig: PilotRig, sight: RangeSight) -> void:
	var eye: Vector3 = rig.desktop_camera.global_position
	var smallest: float = INF
	for node in sight.find_children("*", "Label3D", true, false):
		var word := node as Label3D
		# THE TRAIN ARROW WHILE HIDDEN is wherever it was last shown; its size is held while it shows, above.
		if not word.visible:
			continue
		var tall: float = float(word.font_size) * word.pixel_size
		smallest = minf(smallest, rad_to_deg(atan(tall / eye.distance_to(word.global_position))) * HEADSET_PIXELS_PER_DEGREE)
	var line: float = rad_to_deg(RangeSight.LINE_MILS * 0.001) * HEADSET_PIXELS_PER_DEGREE
	_check("the_smallest_writing_on_the_sight_is_twenty_headset_pixels", smallest >= LEAST_WORD_PIXELS,
		"smallest line of writing %.1f headset px (at least %.0f); thinnest mark %.2f headset px" % [smallest,
			LEAST_WORD_PIXELS, line])
	# NO TWO PIECES OF WRITING OVERLAP, AND NONE IS OVER THE TARGET. The first picture numbered the scale every ten mils and
	# drew "10 20 30 40" as one smear; and anything written above the scale's bar is written where the target is.
	# IN THE SIGHT'S PLANE, as rectangles: a Label3D's box is flat, and AABB.intersects is false for two flat boxes that
	# cover each other.
	var boxes: Array[Rect2] = []
	var names: PackedStringArray = []
	var above: PackedStringArray = []
	var bar_y: float = (sight.global_transform.affine_inverse() * sight.scale_centre()).y
	for node in sight.find_children("*", "Label3D", true, false):
		var word := node as Label3D
		# THE TRAIN ARROW IS NOT ON THIS GLASS: it is written in front of wherever the eye looks. Held below.
		if word.text.strip_edges() == "" or word.name == "Train":
			continue
		var flat: AABB = word.transform * word.get_aabb()
		var box := Rect2(flat.position.x, flat.position.y, flat.size.x, flat.size.y)
		boxes.append(box)
		names.append("%s %s" % [word.name, box])
		if box.end.y > bar_y:
			above.append(word.name)
	var touching: PackedStringArray = []
	for i in range(boxes.size()):
		for j in range(i + 1, boxes.size()):
			if boxes[i].intersects(boxes[j]):
				touching.append("%s / %s" % [names[i], names[j]])
	_check("no_two_pieces_of_writing_on_the_sight_overlap_and_none_is_above_the_scale",
		boxes.size() >= 4 and touching.is_empty() and above.is_empty(),
		"%d pieces; overlapping %s; above the bar at %.4f: %s; %s" % [boxes.size(), touching, bar_y, above, names])


## ---- the fall of shot ---------------------------------------------------------------------------------------------

## THE FIRE KEY FIRES, THE BOARD COUNTS THE FLIGHT DOWN, AND WHEN IT LANDS SAYS WHERE: its impact's distance from the
## trunnion, within a metre of the world's own.
func _the_fire_key_fires_and_the_fall_of_shot_is_spotted(rig: PilotRig, sight: RangeSight) -> void:
	var me: int = Sim.local_client_id()
	var seen: Dictionary = {}
	for row in Sim.shots:
		seen[int((row as Dictionary)["entity"])] = true
	await _hold("fire", 6)
	var shell: int = 0
	var counting: String = ""
	var landed: Dictionary = {}
	var trunnion: Vector3 = Vector3.INF
	for i in range(int(30.0 * 120.0)):
		await get_tree().physics_frame
		for row in Sim.shots:
			var shot: Dictionary = row
			if shell == 0 and not seen.has(int(shot["entity"])) and int(shot.get("shooter", -1)) == me:
				shell = int(shot["entity"])
			if shell != 0 and int(shot["entity"]) == shell and not bool(shot.get("flying", true)) and landed.is_empty():
				landed = shot
				var view: VehicleView = rig.vehicle_view()
				trunnion = view.global_transform * (sight.gun.get("at", Vector3.ZERO) as Vector3)
		if counting == "" and sight.says().contains("LANDS IN"):
			counting = sight.says().replace("\n", " | ")
		if not landed.is_empty():
			break
	for i in range(60):
		await get_tree().physics_frame
	var said: String = sight.says()
	var spotted: float = _read(said, "SPLASH ")
	var impact: Vector3 = landed.get("impact", Vector3.INF) as Vector3
	var actual: float = Vector2(impact.x - trunnion.x, impact.z - trunnion.z).length() if not landed.is_empty() else -1.0
	_check("the_fire_key_fires_and_the_board_counts_the_flight_down", shell != 0 and counting != "",
		"shell %d; %s" % [shell, counting if counting != "" else "no countdown"])
	# WITHIN A FEW METRES, NOT ONE: the board reads the trunnion where the craft is DRAWN this frame, the check where it is
	# drawn a few frames later, and the ship is under way.
	_check("and_when_it_lands_the_board_says_how_far_off", spotted > 0.0 and absf(spotted - actual) <= 5.0,
		"board %.0f m, impact %.1f m from the trunnion (%s)" % [spotted, actual, said.replace("\n", " | ")])


## THE DRUM'S RANGE IS WHERE THE SHELL LANDS, on each beam, with the hull rolling (plan item 22e). That is the whole of
## what a gunner relies on the drum for, and the check before it compared the drum with the reach at the elevation against
## the SHIP, sharing the ship's frame: a rolling hull passed it while beam shots landed 150 m off. The gun is trained to the
## beam with the desk keys, the shot waits for the hull to be tilting the barrel at least TILTED_AT_LEAST_DEG against the
## world, and the drum read on the tick the fire key goes down is held to the impact's flat distance from the trunnion at
## that tick.
func _on_the_beam_the_drum_reads_where_the_shell_lands(rig: PilotRig, sight: RangeSight, beam: float) -> void:
	var side: String = "starboard" if beam < 0.0 else "port"
	for i in range(int(90.0 * 120.0)):
		var off: float = angle_difference(_laid().x, beam)
		if absf(off) < deg_to_rad(0.5):
			break
		await _hold("roll_left" if off > 0.0 else "roll_right", 12 if absf(off) > deg_to_rad(3.0) else 1)
	for i in range(int(8.0 * 120.0)):
		await get_tree().physics_frame
	var tilt: float = 0.0
	for i in range(int(90.0 * 120.0)):
		await get_tree().physics_frame
		tilt = _world_elevation(rig, _laid()) - _laid().y
		if absf(tilt) >= deg_to_rad(TILTED_AT_LEAST_DEG):
			break
	var me: int = Sim.local_client_id()
	var seen: Dictionary = {}
	for row in Sim.shots:
		seen[int((row as Dictionary)["entity"])] = true
	var drum: float = _read(sight.says(), "RANGE ")
	var view: VehicleView = rig.vehicle_view()
	var trunnion: Vector3 = view.global_transform * (sight.gun.get("at", Vector3.ZERO) as Vector3)
	var laid: Vector2 = _laid()
	await _hold("fire", 6)
	var shell: int = 0
	var impact: Vector3 = Vector3.INF
	for i in range(int(30.0 * 120.0)):
		await get_tree().physics_frame
		for row in Sim.shots:
			var shot: Dictionary = row
			if shell == 0 and not seen.has(int(shot["entity"])) and int(shot.get("shooter", -1)) == me:
				shell = int(shot["entity"])
			if shell != 0 and int(shot["entity"]) == shell and not bool(shot.get("flying", true)):
				impact = shot["impact"] as Vector3
		if impact != Vector3.INF:
			break
	var lands: float = Vector2(impact.x - trunnion.x, impact.z - trunnion.z).length() if impact != Vector3.INF else -1.0
	_check("on_the_%s_beam_the_drum_reads_where_the_shell_lands_within_one_percent" % side,
		lands > 0.0 and absf(drum - lands) <= lands * DRUM_LANDS_SHARE,
		"trained %.1f deg, laid %.2f deg against the ship; the hull tilting the barrel %+.3f deg at fire; drum %.0f m, landed %.0f m from the trunnion (%+.0f m, %+.1f%%)"
		% [rad_to_deg(laid.x), rad_to_deg(laid.y), rad_to_deg(tilt), drum, lands, lands - drum,
			100.0 * (lands - drum) / maxf(lands, 1.0)])
	for i in range(int(7.0 * 120.0)):
		await get_tree().physics_frame


## Where a mount laid at `aim` on this rig's craft points in the world: its elevation above the horizontal, radians.
func _world_elevation(rig: PilotRig, aim: Vector2) -> float:
	var view: VehicleView = rig.vehicle_view()
	if view == null:
		return aim.y
	var barrel: Vector3 = view.global_basis * Vector3(-sin(aim.x) * cos(aim.y), sin(aim.y), -cos(aim.x) * cos(aim.y))
	return asin(clampf(barrel.normalized().y, -1.0, 1.0))


## ---- reading --------------------------------------------------------------------------------------------------------

func _laid() -> Vector2:
	var mine: Dictionary = Sim.client.gunner_state(Sim.local_client_id())
	return mine.get("aim", Vector2.ZERO) as Vector2


## The number after `label` on the board, commas and all, or -1.
static func _read(said: String, label: String) -> float:
	var at: int = said.find(label)
	if at < 0:
		return -1.0
	var digits: String = ""
	for c in said.substr(at + label.length()):
		if c == ",":
			continue
		if c < "0" or c > "9":
			break
		digits += c
	return float(digits) if digits != "" else -1.0


func _key_of(action: String) -> Key:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	_check("the_%s_action_is_bound_to_a_key" % action, false, "nothing bound")
	return KEY_NONE


func _hold(action: String, frames: int) -> void:
	var code: Key = _key_of(action)
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	for i in range(frames):
		await get_tree().physics_frame
	var lift := InputEventKey.new()
	lift.keycode = code
	lift.physical_keycode = code
	lift.pressed = false
	Input.parse_input_event(lift)
	await get_tree().physics_frame


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
