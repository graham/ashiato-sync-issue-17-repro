extends Node
## Headless: A CONTROL BEING PLACED GOES DOWN ON A GRID, when the pilot wants one -- and a control being placed is
## furniture, whose own fingers do nothing to the aircraft.
##
##   Godot --headless --path cockpit res://tests/snap.tscn
##
## Asked for on 2026-09-13: in the builder, tap to toggle snap to grid and move the joystick up and down to change how
## fine it is -- 5 to 90 degrees in fives -- for rotation and for x, y and z. See PlacingGrid for the grid and
## `PilotRig._building_bindings` for the fingers.
##
## THREE PARTS, because they need three different worlds:
##   1. THE GRID AS ARITHMETIC, asked of PlacingGrid directly, and said so: "is 37 degrees rounded to 35" is a question
##      about a sum. Includes team-lead's reload check: a snapped facing written the way CockpitLayout writes it comes
##      back to the same basis within 1e-4, at every pitch from -90 to 90.
##   2. THE FINGERS AT A BENCH: a station on a plinth, as tests/builder.gd builds one, a rig sat at it with the builder
##      on, and the joystick's click and flick forced on the SAME hand that holds the lever. What is read back is the
##      rig's grid and what `CockpitLayout.of_station` would write -- the file a player saves.
##   3. THE HELD-STICK TRIM LEAK, in a real plane: a stick being carried in the builder wound the aeroplane's trim under a
##      resting thumb and re-centred it on a click, because the builder's table said nothing about the joystick. A bench
##      has no craft to propose to, so a check there would pass over it.
##
## THE GRID FILE IS PUT BACK. The rig writes `PlacingGrid.path` whenever the grid changes; in a suite that is the suite's
## own folder, never the player's (CockpitLayout.folder), and this suite still leaves it as it found it.
##
## Read RESULT=, not the exit code.

const PLANE: int = Sim.Kind.PLANE
const TEST_KIND: int = Sim.Kind.PLANE
const TEST_SEAT: int = 0
const RIGHT: int = 1
## How long the craft is given to answer, in physics frames: a second at 120 Hz.
const PATIENCE: int = 120
## Where the trim is put before the click: far from neutral, so a re-centre cannot pass for it.
const TRIM_SET: int = 200
## An off-grid pose: a turned wrist and a hand a few millimetres off everything. A var and not a const, because a
## `Basis.from_euler` call is not a constant expression and a const initialised with one does not parse.
var _off_grid := Transform3D(Basis.from_euler(Vector3(0.13, 0.41, -0.07), EULER_ORDER_YXZ),
	Vector3(0.1234, 0.9876, -0.4561))
## A hand a few millimetres off everything, as a person's is, in the station's frame.
const OFF_GRID_BY := Vector3(0.0137, 0.0071, -0.0093)
## A wrist turned about the vertical, in radians: 21 degrees -- six off the 15-degree grid, so snapped it lands on 15 and not
## on 0, which a turn that never arrived would also read as.
const WRIST_YAW: float = 0.3665

var _failures: PackedStringArray = []
var _level: FlightLevel = null
## Sections that reached their own end. See the note in tests/feel.gd.
var _sections: int = 0
const SECTIONS: int = 8


func _check(label: String, ok: bool, detail: String) -> void:
	print("[snap] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var kept: String = _borrow_the_grid_file()

	# ---- 1. the grid as arithmetic ----
	_a_fresh_grid_snaps_nothing()
	_rotation_snap_lands_every_angle_on_the_step()
	_a_snapped_facing_reloads_to_the_same_transform()
	_position_snap_lands_on_the_enabled_axes_only()
	_the_stick_walks_the_rotation_step_and_stops_at_the_ends()
	_the_stick_walks_the_position_steps()
	_the_click_toggles_what_the_stick_adjusts()
	_it_is_kept_between_sessions()
	_sections += 1
	# ---- 1b. the snap board, as arithmetic ----
	_the_board_sits_mirrored_on_the_other_hand()
	_a_board_put_somewhere_else_is_kept_and_reset_puts_it_back()
	_a_board_set_on_the_right_hand_reopens_mirrored_on_the_left()
	_a_board_cannot_be_dragged_further_than_a_forearm()
	_the_board_is_held_by_its_edge_and_not_its_glass()
	_sections += 1

	# ---- 2. the fingers, at a bench ----
	var rig := (load("res://player/pilot_rig.tscn") as PackedScene).instantiate() as PilotRig
	add_child(rig)
	await get_tree().process_frame
	var station := _a_station()
	rig.take_station(station)
	await get_tree().process_frame
	rig.build_the_cockpit(true)
	await get_tree().process_frame
	var lever := station.get_node_or_null("Throttle") as VehicleControl
	_check("the_bench_has_a_throttle_to_place", lever != null, "%s" % [lever])
	if lever != null:
		await _the_joystick_click_turns_snap_on_and_the_flick_walks_the_step(rig, station, lever)
		await _a_control_put_down_on_the_grid_is_saved_on_the_grid(rig, station, lever)
		await _the_trigger_puts_the_snap_board_on_the_working_hand_and_the_other_hand_works_it(rig, station, lever)
		await _the_other_hand_moves_the_board_by_its_edge_and_not_the_control_behind_it(rig, station, lever)
	rig.build_the_cockpit(false)
	station.get_parent().queue_free()
	rig.queue_free()
	for i in range(4):
		await get_tree().process_frame

	# ---- 3. the trim leak, in a real plane ----
	_level = load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(240):
		await get_tree().physics_frame
	var pilot: PilotRig = _level.rig
	var view: VehicleView = await _the_player_gets_into_a_plane(pilot)
	if view != null:
		await _a_stick_being_placed_does_not_trim_the_craft(pilot, view)

	_give_back_the_grid_file(kept)
	_check("every_section_of_the_suite_ran", _sections == SECTIONS, "%d of %d" % [_sections, SECTIONS])
	_finish()


## ================================================================================================================
## 1. THE GRID AS ARITHMETIC
## ================================================================================================================

func _a_fresh_grid_snaps_nothing() -> void:
	var grid := PlacingGrid.new()
	var placed: Transform3D = grid.snapped(_off_grid)
	_check("a_fresh_grid_puts_a_control_exactly_where_the_hand_put_it",
		placed.origin.distance_to(_off_grid.origin) < 1e-6 and placed.basis.is_equal_approx(_off_grid.basis),
		"snap is off for both until somebody turns it on: at %s" % placed.origin)
	_check("and_its_steps_are_the_defaults",
		grid.rotation_step == PlacingGrid.DEFAULT_ROTATION_STEP
			and is_equal_approx(grid.position_step, PlacingGrid.DEFAULT_POSITION_STEP),
		"%d degrees, %.3f m" % [grid.rotation_step, grid.position_step])


func _rotation_snap_lands_every_angle_on_the_step() -> void:
	var grid := PlacingGrid.new()
	grid.rotation_on = true
	var placed: Transform3D = grid.snapped(_off_grid)
	var turned: Vector3 = placed.basis.get_euler(EULER_ORDER_YXZ)
	var off: float = 0.0
	for angle in [turned.x, turned.y, turned.z]:
		var degrees: float = rad_to_deg(angle)
		off = maxf(off, absf(degrees - snappedf(degrees, float(grid.rotation_step))))
	_check("rotation_snap_puts_every_angle_on_a_multiple_of_the_step", off < 0.001,
		"%s degrees, worst %.4f off a %d-degree grid" % [
			Vector3(rad_to_deg(turned.x), rad_to_deg(turned.y), rad_to_deg(turned.z)), off, grid.rotation_step])
	_check("and_leaves_the_position_alone", placed.origin.distance_to(_off_grid.origin) < 1e-6,
		"at %s" % placed.origin)


## A SNAPPED FACING SURVIVES BEING WRITTEN DOWN. `CockpitLayout` saves "facing" as the Euler degrees of
## `Node3D.rotation` -- YXZ, the order `snapped` rounds in -- to a thousandth of a degree, and reads it back through
## `deg_to_rad` into `rotation`. Re-deriving a basis from three rounded angles is where gimbal drift would come from, so
## this does exactly that, the way the file does it, and holds the basis to 1e-4 (team-lead, 2026-09-13).
##
## ACROSS THE GRID, not at one pose: every yaw and roll step at every pitch step from -90 to 90 at 15 degrees. Near a
## pitch of 90 yaw and roll share an axis, so two different triples name one basis; what is held is the BASIS, never the
## triple, which is the thing a reloaded lever is drawn from.
func _a_snapped_facing_reloads_to_the_same_transform() -> void:
	var grid := PlacingGrid.new()
	grid.rotation_on = true
	var worst: float = 0.0
	var worst_at: Vector3 = Vector3.ZERO
	for pitch in range(-90, 91, 15):
		for yaw in range(-180, 181, 45):
			for roll in range(-180, 181, 45):
				var wobbly := Basis.from_euler(Vector3(deg_to_rad(pitch + 3.7), deg_to_rad(yaw - 4.1),
					deg_to_rad(roll + 2.3)), EULER_ORDER_YXZ)
				var placed: Basis = grid.snapped(Transform3D(wobbly, Vector3.ZERO)).basis
				var saved: Vector3 = placed.get_euler(EULER_ORDER_YXZ)
				var facing := Vector3(snappedf(rad_to_deg(saved.x), 0.001), snappedf(rad_to_deg(saved.y), 0.001),
					snappedf(rad_to_deg(saved.z), 0.001))
				var reloaded := Basis.from_euler(Vector3(deg_to_rad(facing.x), deg_to_rad(facing.y),
					deg_to_rad(facing.z)), EULER_ORDER_YXZ)
				var off: float = 0.0
				for axis in range(3):
					off = maxf(off, (reloaded[axis] - placed[axis]).length())
				if off > worst:
					worst = off
					worst_at = Vector3(pitch, yaw, roll)
	_check("a_snapped_facing_written_and_read_back_is_the_same_basis_to_1e-4", worst < 1e-4,
		"worst %.6f, near pitch/yaw/roll %s degrees" % [worst, worst_at])


func _position_snap_lands_on_the_enabled_axes_only() -> void:
	var grid := PlacingGrid.new()
	grid.position_on = true
	grid.on_y = false
	var placed: Transform3D = grid.snapped(_off_grid)
	var step: float = grid.position_step
	_check("position_snap_puts_x_and_z_on_the_grid",
		absf(placed.origin.x - snappedf(placed.origin.x, step)) < 1e-6
			and absf(placed.origin.z - snappedf(placed.origin.z, step)) < 1e-6,
		"at %s on a %.3f m grid" % [placed.origin, step])
	_check("and_leaves_an_axis_that_is_switched_off_where_the_hand_put_it",
		is_equal_approx(placed.origin.y, _off_grid.origin.y), "y %.4f, was %.4f" % [placed.origin.y, _off_grid.origin.y])
	_check("and_does_not_turn_it", placed.basis.is_equal_approx(_off_grid.basis), "rotation snap is off")


func _the_stick_walks_the_rotation_step_and_stops_at_the_ends() -> void:
	var grid := PlacingGrid.new()
	var walked: Array = []
	for i in range(20):
		grid.step_by(1)
		walked.append(grid.rotation_step)
	var expected: Array = []
	for degrees in range(20, 95, 5):
		expected.append(degrees)
	while expected.size() < walked.size():
		expected.append(90)
	_check("a_flick_up_coarsens_the_rotation_step_by_five_and_stops_at_ninety", walked == expected,
		"from 15: %s" % [walked])
	for i in range(30):
		grid.step_by(-1)
	_check("and_down_stops_at_five", grid.rotation_step == PlacingGrid.ROTATION_MIN, "%d" % grid.rotation_step)


func _the_stick_walks_the_position_steps() -> void:
	var grid := PlacingGrid.new()
	grid.stick_adjusts = PlacingGrid.Quantity.POSITION
	var walked: Array = []
	for i in range(8):
		grid.step_by(1)
		walked.append(grid.position_step)
	_check("with_the_stick_on_position_a_flick_walks_the_position_steps_and_stops_at_the_top",
		is_equal_approx(float(walked[0]), 0.02) and is_equal_approx(float(walked[walked.size() - 1]), 0.10),
		"from 0.01: %s" % [walked])
	_check("and_leaves_the_rotation_step_alone", grid.rotation_step == PlacingGrid.DEFAULT_ROTATION_STEP,
		"%d" % grid.rotation_step)
	for i in range(10):
		grid.step_by(-1)
	_check("and_down_stops_at_half_a_centimetre", is_equal_approx(grid.position_step, 0.005),
		"%.3f" % grid.position_step)


func _the_click_toggles_what_the_stick_adjusts() -> void:
	var grid := PlacingGrid.new()
	grid.toggle()
	_check("the_click_turns_on_the_snap_the_stick_is_on", grid.rotation_on and not grid.position_on,
		"rotation %s, position %s" % [grid.rotation_on, grid.position_on])
	grid.stick_adjusts = PlacingGrid.Quantity.POSITION
	grid.toggle()
	_check("and_on_position_it_is_the_position_snap_it_turns", grid.rotation_on and grid.position_on,
		"rotation %s, position %s" % [grid.rotation_on, grid.position_on])


## KEPT BETWEEN SESSIONS. A hand-edited file with a step that is not a step is clamped and said, and a file that leaves
## a key out gets that key's own default rather than the bottom of its range. The file is given back by `_ready`.
func _it_is_kept_between_sessions() -> void:
	var grid := PlacingGrid.new()
	grid.rotation_on = true
	grid.rotation_step = 45
	grid.position_on = true
	grid.position_step = 0.05
	grid.on_z = false
	grid.stick_adjusts = PlacingGrid.Quantity.POSITION
	var wrote: bool = grid.write()
	var back: PlacingGrid = PlacingGrid.read()
	_check("a_grid_written_down_reads_back_the_same",
		wrote and back.rotation_on and back.rotation_step == 45 and back.position_on
			and is_equal_approx(back.position_step, 0.05) and back.on_x and back.on_y and not back.on_z
			and back.stick_adjusts == PlacingGrid.Quantity.POSITION,
		"written %s; read %d deg %s, %.3f m %s, axes %s%s%s, stick %d" % [wrote, back.rotation_step,
			back.rotation_on, back.position_step, back.position_on, back.on_x, back.on_y, back.on_z,
			back.stick_adjusts])
	var file := FileAccess.open(PlacingGrid.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"rotation_step": 37, "position_step": 0.037}))
	file.close()
	var edited: PlacingGrid = PlacingGrid.read()
	_check("and_a_hand_edited_step_that_is_not_a_step_is_put_on_one",
		edited.rotation_step == 35 and is_equal_approx(edited.position_step, PlacingGrid.DEFAULT_POSITION_STEP),
		"37 deg read as %d; 0.037 m read as %.3f" % [edited.rotation_step, edited.position_step])
	_check("and_what_it_leaves_out_takes_its_own_default",
		not edited.rotation_on and not edited.position_on and edited.on_x and edited.on_y and edited.on_z
			and edited.stick_adjusts == PlacingGrid.Quantity.ROTATION,
		"on %s/%s, axes %s%s%s" % [edited.rotation_on, edited.position_on, edited.on_x, edited.on_y, edited.on_z])


## ================================================================================================================
## 2. THE FINGERS, AT A BENCH
## ================================================================================================================

func _the_joystick_click_turns_snap_on_and_the_flick_walks_the_step(rig: PilotRig, station: CockpitStation,
		lever: VehicleControl) -> void:
	rig.placing_grid = PlacingGrid.new()
	var grip_local: Vector3 = lever.transform * lever._grab_point()
	rig.force_grip(RIGHT, 1.0)
	await _hand_in_station(rig, station, Transform3D(Basis.IDENTITY, grip_local), 6)
	_check("in_the_builder_the_right_hand_picks_the_lever_up", lever.held_by == RIGHT and rig.placing(),
		"held by %d, placing %s" % [lever.held_by, rig.placing()])
	var table: Dictionary = rig._bindings_for(RIGHT)
	_check("and_its_joystick_click_and_flick_are_the_grid",
		int((table.get(Bind.STICK_CLICK, {}) as Dictionary).get("what", -1)) == Bind.Local.SNAP_TOGGLE
			and int((table.get(Bind.STICK, {}) as Dictionary).get("what", -1)) == Bind.Local.SNAP_STEP,
		"click %s, stick %s" % [Bind.says(table.get(Bind.STICK_CLICK)), Bind.says(table.get(Bind.STICK))])

	await _press(rig, station, Bind.STICK_CLICK, true, false, grip_local)
	_check("clicking_the_joystick_in_turns_rotation_snap_on", rig.placing_grid.rotation_on,
		"rotation %s, position %s" % [rig.placing_grid.rotation_on, rig.placing_grid.position_on])

	await _press(rig, station, Bind.STICK, Vector2(0.0, 1.0), Vector2.ZERO, grip_local)
	_check("a_flick_up_coarsens_the_step_by_one", rig.placing_grid.rotation_step == 20,
		"15 -> %d" % rig.placing_grid.rotation_step)

	# HELD OVER FOR A SECOND: the press, then a repeat at 0.4 s and every 0.25 s after -- at 120 Hz, frames 48, 78 and 108.
	var ticks: int = Engine.physics_ticks_per_second
	var held_for: int = ticks
	rig.force_input(RIGHT, Bind.STICK, Vector2(0.0, 1.0))
	await _hand_in_station(rig, station, Transform3D(Basis.IDENTITY, grip_local), held_for)
	rig.force_input(RIGHT, Bind.STICK, Vector2.ZERO)
	await _hand_in_station(rig, station, Transform3D(Basis.IDENTITY, grip_local), 2)
	rig.force_input(RIGHT, Bind.STICK, null)
	var after: int = int(ceil(PilotRig.GRID_REPEAT_AFTER * ticks))
	var every: int = int(ceil(PilotRig.GRID_REPEAT_EVERY * ticks))
	var steps: int = 1 + (1 + int(floor(float(held_for - after) / float(every))) if held_for >= after else 0)
	_check("holding_it_over_repeats_on_the_rigs_own_schedule",
		absi(rig.placing_grid.rotation_step - (20 + 5 * steps)) <= 5,
		"20 -> %d over %d frames held, %d steps expected" % [rig.placing_grid.rotation_step, held_for, steps])

	rig.force_input(RIGHT, Bind.STICK, Vector2(0.0, 1.0))
	await _hand_in_station(rig, station, Transform3D(Basis.IDENTITY, grip_local), ticks * 6)
	rig.force_input(RIGHT, Bind.STICK, null)
	await _hand_in_station(rig, station, Transform3D(Basis.IDENTITY, grip_local), 2)
	_check("and_it_stops_at_ninety", rig.placing_grid.rotation_step == PlacingGrid.ROTATION_MAX,
		"%d after six seconds held" % rig.placing_grid.rotation_step)
	var file_says: PlacingGrid = PlacingGrid.read()
	_check("and_the_grid_it_walked_is_kept", file_says.rotation_step == PlacingGrid.ROTATION_MAX and file_says.rotation_on,
		"the file says %d, on %s" % [file_says.rotation_step, file_says.rotation_on])
	await _put_it_down(rig, station, Transform3D(Basis.IDENTITY, grip_local))
	_sections += 1


## A LEVER PUT DOWN WITH A TURNED WRIST AND AN UNSTEADY HAND lands on the grid when snap is on, and exactly where the hand
## left it when it is off -- read back from what `CockpitLayout.of_station` would write, which is the file a player saves.
func _a_control_put_down_on_the_grid_is_saved_on_the_grid(rig: PilotRig, station: CockpitStation,
		lever: VehicleControl) -> void:
	rig.placing_grid = PlacingGrid.new()
	rig.placing_grid.rotation_on = true
	rig.placing_grid.position_on = true
	var saved_on: Dictionary = await _place_and_read(rig, station, lever)
	var facing_on: Array = saved_on.get("facing", [0, 0, 0])
	var at_on: Array = saved_on.get("at", [0, 0, 0])
	_check("with_snap_on_the_saved_facing_is_on_the_rotation_step",
		absf(float(facing_on[1]) - 15.0) < 0.002,
		"a 21-degree wrist saved at yaw %.3f, on a 15-degree grid" % float(facing_on[1]))
	_check("and_the_saved_position_is_on_the_centimetre", _on_the_step(at_on, 0.01),
		"at %s on a 0.01 m grid" % [at_on])

	rig.placing_grid.rotation_on = false
	rig.placing_grid.position_on = false
	var saved_off: Dictionary = await _place_and_read(rig, station, lever)
	var facing_off: Array = saved_off.get("facing", [0, 0, 0])
	var at_off: Array = saved_off.get("at", [0, 0, 0])
	_check("with_snap_off_the_saved_facing_is_where_the_wrist_left_it",
		absf(float(facing_off[1]) - snappedf(float(facing_off[1]), 15.0)) > 1.0,
		"yaw %.3f degrees, which is not on the grid" % float(facing_off[1]))
	_check("and_so_is_the_position", not _on_the_step(at_off, 0.01), "at %s" % [at_off])
	_sections += 1


func _place_and_read(rig: PilotRig, station: CockpitStation, lever: VehicleControl) -> Dictionary:
	var grip_local: Vector3 = lever.transform * lever._grab_point()
	rig.force_grip(RIGHT, 1.0)
	await _hand_in_station(rig, station, Transform3D(Basis.IDENTITY, grip_local), 6)
	var moved := Transform3D(Basis(Vector3.UP, WRIST_YAW), grip_local + OFF_GRID_BY)
	await _hand_in_station(rig, station, moved, 12)
	await _put_it_down(rig, station, moved)
	for entry in (CockpitLayout.of_station(TEST_KIND, TEST_SEAT, station).get("controls", []) as Array):
		if String((entry as Dictionary).get("name", "")) == String(lever.name):
			return entry
	return {}


func _on_the_step(at: Array, step: float) -> bool:
	for value in at:
		if absf(float(value) - snappedf(float(value), step)) > 0.0011:
			return false
	return true


func _hand_in_station(rig: PilotRig, station: CockpitStation, local: Transform3D, frames: int) -> void:
	for i in range(frames):
		rig.force_hand(RIGHT, station.global_transform * local)
		await get_tree().physics_frame


func _press(rig: PilotRig, station: CockpitStation, input: int, down: Variant, up: Variant, grip_local: Vector3) -> void:
	rig.force_input(RIGHT, input, down)
	await _hand_in_station(rig, station, Transform3D(Basis.IDENTITY, grip_local), 2)
	rig.force_input(RIGHT, input, up)
	await _hand_in_station(rig, station, Transform3D(Basis.IDENTITY, grip_local), 2)
	rig.force_input(RIGHT, input, null)


## LET GO AS A SQUEEZE ENDS, NOT AS A TAP -- the latch is timed on the wall clock. See tests/shared_controls.gd's `_let_go`.
## THE WHOLE POSE, KEPT until the grip opens: a hand held still at a bare point while the latch time runs turns a lever it
## is still holding back to square, which is how the first run saved a 7-degree wrist as 0.
func _put_it_down(rig: PilotRig, station: CockpitStation, pose: Transform3D) -> void:
	var closed_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - closed_at < int((PilotRig.TAP_SECONDS + 0.15) * 1000.0):
		await _hand_in_station(rig, station, pose, 1)
	rig.force_grip(RIGHT, 0.0)
	await _hand_in_station(rig, station, pose, 4)
	rig.force_hand(RIGHT, null)
	rig.force_grip(RIGHT, -1.0)


## ONE STATION, WITH NO AIRCRAFT BEHIND IT, on a plinth -- as tests/builder.gd and the hall of cockpits build one.
func _a_station() -> CockpitStation:
	var plinth := Node3D.new()
	add_child(plinth)
	var station := VehicleCatalogue.seat_scene(TEST_KIND).instantiate() as CockpitStation
	plinth.add_child(station)
	station.fit(TEST_SEAT, true, TEST_KIND, false)
	return station


## ================================================================================================================
## 3. THE HELD-STICK TRIM LEAK, IN A REAL PLANE
## ================================================================================================================

func _the_player_gets_into_a_plane(rig: PilotRig) -> VehicleView:
	rig.ask_for_kind(PLANE)
	var view: VehicleView = null
	for i in range(900):
		await get_tree().physics_frame
		view = rig.vehicle_view()
		if view != null and view.kind == PLANE and rig.seat_index() == 0:
			break
	var ok: bool = view != null and view.kind == PLANE and rig.seat_index() == 0
	_check("the_player_gets_into_a_plane_at_its_pilot_seat", ok,
		"kind %s, seat %d" % [view.kind if view != null else "-", rig.seat_index()])
	_sections += 1
	return view if ok else null


## THE HELD STICK'S OWN FINGERS STILL WORKED WHILE IT WAS BEING PLACED. `_bindings_for` lays the builder's table over the
## held control's, and the builder's said nothing about the mini joystick or its click -- so a pilot carrying the stick
## across the console with a thumb resting on the joystick wound the aeroplane's trim, and clicking it in re-centred
## the trim, while the stick was furniture. Placing mode's thumbstick and click belong to the grid now, which closes it.
## Runs LAST, because placing the stick moves it.
func _a_stick_being_placed_does_not_trim_the_craft(rig: PilotRig, view: VehicleView) -> void:
	var station: CockpitStation = view.station_for(rig.seat_index())
	var stick := station.controls().get("stick") as FlightStick if station != null else null
	_check("the_pilots_stick_trims_when_it_is_flown", stick != null and stick.trim_range > 0,
		"trim range %d" % [stick.trim_range if stick != null else -1])
	if stick == null:
		_sections += 1
		return
	rig.build_the_cockpit(true)
	for i in range(4):
		await get_tree().physics_frame
	_check("the_builder_is_placing", rig.placing(), "building %s, trying %s" % [rig.building(), rig.trying()])
	var grip: Vector3 = stick._grab_point()
	var taken: bool = await _take_hold(rig, stick, grip)
	_check("a_hand_picks_the_stick_up_to_place_it", taken, "held by %d" % stick.held_by)
	var before: int = view.channel_value(Sim.Channel.TRIM)
	rig.force_input(RIGHT, Bind.STICK, Vector2(0.0, -1.0))
	await _hand_follows(rig, stick, grip, 60)
	rig.force_input(RIGHT, Bind.STICK, null)
	for i in range(PATIENCE / 2):
		await get_tree().physics_frame
	var after_push: int = view.channel_value(Sim.Channel.TRIM)
	_check("pushing_the_mini_joystick_of_a_stick_being_placed_does_not_trim_the_craft", after_push == before,
		"trim %d -> %d over 60 frames of the joystick held back" % [before, after_push])
	# AND THE CLICK, which re-centred it. Only visible from somewhere that is not neutral, so the trim is put there first
	# -- ARRANGED, NOT TESTED.
	Sim.send_command(Sim.Channel.TRIM, TRIM_SET)
	var arranged: int = await _frames_until(func() -> bool: return view.channel_value(Sim.Channel.TRIM) == TRIM_SET)
	await _hand_follows(rig, stick, grip, 2)
	rig.force_input(RIGHT, Bind.STICK_CLICK, true)
	await _hand_follows(rig, stick, grip, 2)
	rig.force_input(RIGHT, Bind.STICK_CLICK, false)
	await _hand_follows(rig, stick, grip, 2)
	rig.force_input(RIGHT, Bind.STICK_CLICK, null)
	for i in range(PATIENCE / 2):
		await get_tree().physics_frame
	_check("and_clicking_it_in_does_not_centre_the_trim",
		arranged >= 0 and view.channel_value(Sim.Channel.TRIM) == TRIM_SET,
		"trim %d after the click, arranged at %d" % [view.channel_value(Sim.Channel.TRIM), TRIM_SET])
	await _let_go(rig, stick, grip)
	rig.build_the_cockpit(false)
	_sections += 1


func _hand_at(control: VehicleControl, local: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, control.to_global(local))


func _hand_follows(rig: PilotRig, control: VehicleControl, local: Vector3, frames: int) -> void:
	for i in range(frames):
		rig.force_hand(RIGHT, _hand_at(control, local))
		await get_tree().physics_frame


func _take_hold(rig: PilotRig, control: VehicleControl, grip: Vector3) -> bool:
	rig.force_grip(RIGHT, 1.0)
	await _hand_follows(rig, control, grip, 6)
	return control.held_by == RIGHT


func _let_go(rig: PilotRig, control: VehicleControl, local: Vector3) -> void:
	var closed_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - closed_at < int((PilotRig.TAP_SECONDS + 0.15) * 1000.0):
		await _hand_follows(rig, control, local, 1)
	rig.force_grip(RIGHT, 0.0)
	await _hand_follows(rig, control, local, 4)
	if control.held_by == RIGHT:
		rig.force_grip(RIGHT, 1.0)
		await _hand_follows(rig, control, local, 2)
		rig.force_grip(RIGHT, 0.0)
		await _hand_follows(rig, control, local, 4)
	rig.force_hand(RIGHT, null)
	rig.force_grip(RIGHT, -1.0)


func _frames_until(cond: Callable, frames: int = PATIENCE) -> int:
	for i in range(frames):
		if bool(cond.call()):
			return i
		await get_tree().physics_frame
	return -1


## ================================================================================================================
## 4. THE SNAP BOARD, ON THE HAND DOING THE WORK
## ================================================================================================================

func _the_board_sits_mirrored_on_the_other_hand() -> void:
	var grid := PlacingGrid.new()
	var right: Transform3D = grid.board_offset_for(1)
	var left: Transform3D = grid.board_offset_for(0)
	var right_euler: Vector3 = right.basis.get_euler(EULER_ORDER_YXZ)
	var left_euler: Vector3 = left.basis.get_euler(EULER_ORDER_YXZ)
	_check("the_board_on_the_left_hand_is_the_right_hands_mirrored",
		is_equal_approx(left.origin.x, -right.origin.x) and is_equal_approx(left.origin.y, right.origin.y)
			and is_equal_approx(left.origin.z, right.origin.z) and is_equal_approx(left_euler.x, right_euler.x)
			and is_equal_approx(left_euler.y, -right_euler.y) and is_equal_approx(left_euler.z, -right_euler.z),
		"right at %s, left at %s" % [right.origin, left.origin])


func _a_board_put_somewhere_else_is_kept_and_reset_puts_it_back() -> void:
	var grid := PlacingGrid.new()
	var moved := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-10.0), deg_to_rad(35.0), 0.0), EULER_ORDER_YXZ),
		Vector3(-0.21, 0.08, -0.05))
	# PUT DOWN ON THE LEFT HAND, and read back on the left hand: the mirror has to be undone the way it was done.
	grid.put_the_board(0, moved)
	var back: Transform3D = grid.board_offset_for(0)
	_check("a_board_moved_on_the_left_hand_is_where_it_was_left_on_the_left_hand",
		back.origin.distance_to(moved.origin) < 1e-5 and back.basis.is_equal_approx(moved.basis),
		"left at %s, read back %s" % [moved.origin, back.origin])
	_check("and_it_is_kept_in_the_right_hands_frame", is_equal_approx(grid.board_at.x, 0.21),
		"kept at %s" % grid.board_at)
	grid.reset_the_board()
	_check("reset_puts_the_board_back_where_it_started",
		grid.board_at.is_equal_approx(PlacingGrid.BOARD_AT) and grid.board_facing.is_equal_approx(PlacingGrid.BOARD_FACING),
		"at %s, facing %s" % [grid.board_at, grid.board_facing])


## SET ON THE RIGHT HAND, KEPT, AND REOPENED ON THE LEFT: the mirror image, to 1e-4 (team-lead, 2026-09-13).
##
## THE MIRROR IS WORKED OUT AS A MATRIX HERE, not as negated Euler angles, because negated angles are what
## `board_offset_for` does -- a check built the same way would agree with a wrong sign. Reflecting across the hand's
## up-and-forward plane is S * T * S with S = diag(-1, 1, 1): a different sum for the same answer. And through the file,
## because "survives a restart" is the claim.
func _a_board_set_on_the_right_hand_reopens_mirrored_on_the_left() -> void:
	var kept: String = FileAccess.get_file_as_string(PlacingGrid.path) if FileAccess.file_exists(PlacingGrid.path) \
		else ""
	var grid := PlacingGrid.new()
	var set_on_right := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-24.0), deg_to_rad(41.0), deg_to_rad(12.0)),
		EULER_ORDER_YXZ), Vector3(0.18, 0.07, -0.13))
	grid.put_the_board(1, set_on_right)
	var wrote: bool = grid.write()
	var reopened: Transform3D = PlacingGrid.read().board_offset_for(0)
	var flip := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0))
	var right_now: Transform3D = PlacingGrid.read().board_offset_for(1)
	var mirrored := Transform3D(flip * right_now.basis * flip, flip * right_now.origin)
	var off: float = reopened.origin.distance_to(mirrored.origin)
	for axis in range(3):
		off = maxf(off, (reopened.basis[axis] - mirrored.basis[axis]).length())
	_check("a_board_set_on_the_right_hand_and_kept_reopens_on_the_left_as_its_mirror_to_1e-4",
		wrote and off < 1e-4 and right_now.origin.distance_to(set_on_right.origin) < 1e-3,
		"worst %.6f; right kept at %s, left opens at %s" % [off, right_now.origin, reopened.origin])
	if kept.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PlacingGrid.path))
	else:
		var restore := FileAccess.open(PlacingGrid.path, FileAccess.WRITE)
		restore.store_string(kept)
		restore.close()


func _a_board_cannot_be_dragged_further_than_a_forearm() -> void:
	var grid := PlacingGrid.new()
	grid.put_the_board(1, Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0)))
	_check("a_board_dragged_a_metre_away_stops_a_forearm_from_the_hand",
		is_equal_approx(grid.board_at.length(), PlacingGrid.BOARD_REACH),
		"%.3f m from the hand, cap %.2f" % [grid.board_at.length(), PlacingGrid.BOARD_REACH])


func _the_board_is_held_by_its_edge_and_not_its_glass() -> void:
	var half := SnapBoard.SIZE * 0.5
	var on_edge := Vector3(half.x + SnapBoard.EDGE * 0.5, 0.0, 0.0)
	var on_glass := Vector3(0.0, 0.0, 0.0)
	var outside := Vector3(half.x + SnapBoard.EDGE * 2.0, 0.0, 0.0)
	var too_far_off := Vector3(half.x + SnapBoard.EDGE * 0.5, 0.0, SnapBoard.HOLD_DEPTH * 2.0)
	_check("a_hand_on_the_boards_edge_holds_it", SnapBoard.edge_holds(on_edge), "at %s" % on_edge)
	_check("but_not_on_its_glass_which_is_the_pointers", not SnapBoard.edge_holds(on_glass), "at %s" % on_glass)
	_check("nor_past_the_edge", not SnapBoard.edge_holds(outside), "at %s" % outside)
	_check("nor_a_hand_held_off_the_plane", not SnapBoard.edge_holds(too_far_off), "at %s" % too_far_off)


const LEFT: int = 0
## How far the carrying hand has moved from the lever's grip when the board is worked: enough that "travels with the
## hand" is a measurement and not a coincidence of both being at the start.
const CARRIED_BY := Vector3(0.0, 0.0, -0.04)


## THE CARRYING HAND'S TRIGGER PUTS THE BOARD ON THAT HAND, it travels with that hand, the other hand's trigger is taken
## for it, and the other hand's beam works it: rotation snap on, a coarser step, the Y axis off, the joystick onto
## position -- each read back off the rig's grid, and off the page, which draws what it was handed.
func _the_trigger_puts_the_snap_board_on_the_working_hand_and_the_other_hand_works_it(rig: PilotRig,
		station: CockpitStation, lever: VehicleControl) -> void:
	rig.placing_grid = PlacingGrid.new()
	var grip_local: Vector3 = lever.transform * lever._grab_point()
	rig.force_grip(RIGHT, 1.0)
	await _hand_in_station(rig, station, Transform3D(Basis.IDENTITY, grip_local), 6)
	await _press(rig, station, Bind.TRIGGER, 1.0, 0.0, grip_local)
	var board: SnapBoard = rig.snap_board
	_check("the_carrying_hands_trigger_puts_the_snap_board_up", board != null and board.is_up(),
		"board %s" % [board])
	if board == null or not board.is_up():
		await _put_it_down(rig, station, Transform3D(Basis.IDENTITY, grip_local))
		_sections += 1
		return
	_check("on_the_carrying_hand_at_the_kept_offset",
		board.working_hand == RIGHT and board.get_parent() == rig.right_hand
			and board.transform.is_equal_approx(rig.placing_grid.board_offset_for(RIGHT)),
		"on hand %d, parent %s, at %s" % [board.working_hand, board.get_parent(), board.transform.origin])
	var was: Vector3 = board.global_position
	var carrying := Transform3D(Basis.IDENTITY, grip_local + CARRIED_BY)
	await _hand_in_station(rig, station, carrying, 6)
	_check("and_it_travels_with_that_hand",
		board.global_position.distance_to(was) > 0.03
			and board.transform.is_equal_approx(rig.placing_grid.board_offset_for(RIGHT)),
		"moved %.3f m with the hand, offset unchanged" % board.global_position.distance_to(was))
	# THE OTHER HAND'S TRIGGER IS THE BOARD'S -- asked with that hand CARRYING A CONTROL OF ITS OWN, because an empty hand's
	# trigger is taken by the builder anyway and a check there could not fail (the first version of this one passed with
	# the board's binding taken out). Carrying, the builder would open a board on it; the board has to win, and a pull
	# on it must leave the board where it is.
	var other := station.get_node_or_null("Stick") as VehicleControl
	if other == null:
		_check("the_bench_has_a_stick_for_the_other_hand", false, "none")
	else:
		rig.force_grip(LEFT, 1.0)
		for i in range(6):
			rig.force_hand(RIGHT, station.global_transform * carrying)
			rig.force_hand(LEFT, Transform3D(Basis.IDENTITY, other.grip_global()))
			await get_tree().physics_frame
		_check("the_other_hand_picks_up_a_control_of_its_own", other.held_by == LEFT, "held by %d" % other.held_by)
		_check("and_its_trigger_is_taken_for_the_board_rather_than_opening_one",
			Bind.says(rig._bindings_for(LEFT).get(Bind.TRIGGER)) == Bind.says(Bind.nothing()),
			"left trigger: %s" % Bind.says(rig._bindings_for(LEFT).get(Bind.TRIGGER)))
		for frame in range(8):
			rig.force_hand(RIGHT, station.global_transform * carrying)
			rig.force_hand(LEFT, Transform3D(Basis.IDENTITY, other.grip_global()))
			if frame == 2:
				rig.force_input(LEFT, Bind.TRIGGER, 1.0)
			elif frame == 4:
				rig.force_input(LEFT, Bind.TRIGGER, 0.0)
			await get_tree().physics_frame
		rig.force_input(LEFT, Bind.TRIGGER, null)
		_check("and_pulling_it_leaves_the_board_up_on_the_carrying_hand",
			board.is_up() and board.working_hand == RIGHT and board.get_parent() == rig.right_hand,
			"up %s, on hand %d" % [board.is_up(), board.working_hand])
		var closed_at: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - closed_at < int((PilotRig.TAP_SECONDS + 0.15) * 1000.0):
			rig.force_hand(RIGHT, station.global_transform * carrying)
			rig.force_hand(LEFT, Transform3D(Basis.IDENTITY, other.grip_global()))
			await get_tree().physics_frame
		rig.force_grip(LEFT, 0.0)
		for i in range(4):
			rig.force_hand(RIGHT, station.global_transform * carrying)
			await get_tree().physics_frame
		if other.held_by == LEFT:
			rig.force_grip(LEFT, 1.0)
			await _hand_in_station(rig, station, carrying, 2)
			rig.force_grip(LEFT, 0.0)
			await _hand_in_station(rig, station, carrying, 4)
		rig.force_hand(LEFT, null)
		rig.force_grip(LEFT, -1.0)
	for i in range(4):
		await _hand_in_station(rig, station, carrying, 1)

	await _beam_press(rig, station, board, "RotationSnap", carrying)
	_check("the_other_hands_beam_turns_rotation_snap_on",
		rig.placing_grid.rotation_on and rig._beam != null and rig._beam.get_parent() == rig.left_hand,
		"rotation %s, beam on %s" % [rig.placing_grid.rotation_on, rig._beam.get_parent() if rig._beam != null else null])
	await _beam_press(rig, station, board, "Coarser", carrying)
	_check("and_its_plus_coarsens_the_rotation_step", rig.placing_grid.rotation_step == 20,
		"15 -> %d" % rig.placing_grid.rotation_step)
	await _beam_press(rig, station, board, "AxisY", carrying)
	_check("and_it_turns_position_snap_off_on_y", not rig.placing_grid.on_y and rig.placing_grid.on_x,
		"x %s, y %s" % [rig.placing_grid.on_x, rig.placing_grid.on_y])
	await _beam_press(rig, station, board, "StickPosition", carrying)
	_check("and_it_puts_the_joystick_on_position",
		rig.placing_grid.stick_adjusts == PlacingGrid.Quantity.POSITION, "stick %d" % rig.placing_grid.stick_adjusts)
	var shows := board.page().control_named("RotationSnap") as BaseButton
	_check("and_the_page_draws_the_grid_it_was_handed", shows != null and shows.button_pressed,
		"ROTATION SNAP pressed %s" % [shows.button_pressed if shows != null else null])
	# AND THE JOYSTICK NOW WORKS POSITION, so the thumb and the board cannot be saying two different things.
	await _press(rig, station, Bind.STICK, Vector2(0.0, 1.0), Vector2.ZERO, carrying.origin)
	_check("and_the_joystick_then_walks_the_position_step_the_board_chose", is_equal_approx(rig.placing_grid.position_step, 0.02),
		"1 cm -> %.3f m" % rig.placing_grid.position_step)
	_sections += 1


## THE OTHER HAND TAKES THE BOARD BY ITS EDGE AND PUTS IT SOMEWHERE ELSE -- and a crew button standing right behind that
## edge, within a hand's reach of the grip, is not picked up. Where it was put down is kept, reopens there, a metre's
## drag stops a forearm from the hand, and RESET POSITION, pressed with the beam, puts it back.
func _the_other_hand_moves_the_board_by_its_edge_and_not_the_control_behind_it(rig: PilotRig,
		station: CockpitStation, lever: VehicleControl) -> void:
	var board: SnapBoard = rig.snap_board
	if board == null or not board.is_up():
		_check("the_board_is_up_to_be_moved", false, "board %s" % [board])
		_sections += 1
		return
	var grip_local: Vector3 = lever.transform * lever._grab_point()
	var carrying := Transform3D(Basis.IDENTITY, grip_local)
	await _hand_in_station(rig, station, carrying, 4)
	var edge_local := Vector3(SnapBoard.SIZE.x * 0.5 + SnapBoard.EDGE * 0.5, 0.0, 0.0)
	var edge_world: Vector3 = board.to_global(edge_local)
	var behind := station.get_node_or_null("Button") as VehicleControl
	if behind == null:
		_check("the_bench_has_a_crew_button_to_stand_behind_the_board", false, "none")
		_sections += 1
		return
	behind.position = station.to_local(edge_world - board.global_basis.z.normalized() * 0.03) - behind._grab_point()
	var behind_was: Vector3 = behind.position
	_check("a_control_stands_within_a_hands_reach_right_behind_the_boards_edge",
		behind.grip_global().distance_to(edge_world) < VehicleControl.REACH,
		"%.3f m from the edge, reach %.2f" % [behind.grip_global().distance_to(edge_world), VehicleControl.REACH])

	var offset_was: Transform3D = board.transform
	var on_edge := Transform3D(Basis.IDENTITY, board.transform * edge_local)
	rig.force_grip(LEFT, 1.0)
	await _both_hands(rig, station, carrying, on_edge, 6)
	_check("the_other_hands_grip_on_the_edge_takes_the_board", board.held_by == LEFT, "held by %d" % board.held_by)
	var dragged := Transform3D(Basis.IDENTITY, on_edge.origin + Vector3(0.06, 0.0, 0.0))
	await _both_hands(rig, station, carrying, dragged, 12)
	_check("and_drags_it_where_the_hand_goes",
		board.transform.origin.distance_to(offset_was.origin + Vector3(0.06, 0.0, 0.0)) < 0.002,
		"moved %s" % (board.transform.origin - offset_was.origin))
	_check("and_the_control_behind_the_edge_stays_where_it_was",
		behind.held_by < 0 and behind.position.distance_to(behind_was) < 1e-4,
		"held by %d, moved %.4f m" % [behind.held_by, behind.position.distance_to(behind_was)])
	await _let_go_of_the_board(rig, station, carrying, dragged)
	var kept: PlacingGrid = PlacingGrid.read()
	_check("and_where_it_was_put_down_is_kept",
		board.held_by < 0 and kept.board_offset_for(RIGHT).origin.distance_to(board.transform.origin) < 0.002,
		"board at %s, file says %s" % [board.transform.origin, kept.board_offset_for(RIGHT).origin])

	await _press(rig, station, Bind.TRIGGER, 1.0, 0.0, grip_local)
	_check("the_carrying_hands_trigger_puts_it_away", not board.is_up(), "up %s" % board.is_up())
	await _press(rig, station, Bind.TRIGGER, 1.0, 0.0, grip_local)
	_check("and_reopened_it_is_where_it_was_left",
		board.is_up() and board.transform.origin.distance_to(kept.board_offset_for(RIGHT).origin) < 0.002,
		"up %s, at %s" % [board.is_up(), board.transform.origin])

	var far_edge := Transform3D(Basis.IDENTITY, board.transform * edge_local)
	rig.force_grip(LEFT, 1.0)
	await _both_hands(rig, station, carrying, far_edge, 6)
	await _both_hands(rig, station, carrying, Transform3D(Basis.IDENTITY, far_edge.origin + Vector3(1.0, 0.0, 0.0)), 12)
	_check("a_board_dragged_a_metre_stops_a_forearm_from_the_hand",
		board.transform.origin.length() <= PlacingGrid.BOARD_REACH + 1e-4,
		"%.3f m from the hand, cap %.2f" % [board.transform.origin.length(), PlacingGrid.BOARD_REACH])
	await _let_go_of_the_board(rig, station, carrying,
		Transform3D(Basis.IDENTITY, far_edge.origin + Vector3(1.0, 0.0, 0.0)))

	await _beam_press(rig, station, board, "ResetPosition", carrying)
	_check("reset_position_puts_the_board_back_where_it_started",
		board.transform.is_equal_approx(PlacingGrid.new().board_offset_for(RIGHT))
			and rig.placing_grid.board_at.is_equal_approx(PlacingGrid.BOARD_AT),
		"at %s" % board.transform.origin)
	await _put_it_down(rig, station, carrying)
	_sections += 1


## ---- hands at a bench, two of them -----------------------------------------------------------------------------

## THE CARRYING HAND AT `carrying` (station frame) AND THE OTHER HAND AT `other`, IN THE CARRYING HAND'S FRAME -- the frame
## the board hangs in -- for `frames` physics frames, both placed again every frame.
func _both_hands(rig: PilotRig, station: CockpitStation, carrying: Transform3D, other: Transform3D, frames: int) -> void:
	for i in range(frames):
		rig.force_hand(RIGHT, station.global_transform * carrying)
		rig.force_hand(LEFT, station.global_transform * carrying * other)
		await get_tree().physics_frame


## LET GO OF THE BOARD AS A SQUEEZE ENDS, the hand kept where it is: see `_put_it_down`. Tapped once more if it latched.
func _let_go_of_the_board(rig: PilotRig, station: CockpitStation, carrying: Transform3D, other: Transform3D) -> void:
	var closed_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - closed_at < int((PilotRig.TAP_SECONDS + 0.15) * 1000.0):
		await _both_hands(rig, station, carrying, other, 1)
	rig.force_grip(LEFT, 0.0)
	await _both_hands(rig, station, carrying, other, 4)
	if rig.snap_board != null and rig.snap_board.held_by == LEFT:
		rig.force_grip(LEFT, 1.0)
		await _both_hands(rig, station, carrying, other, 2)
		rig.force_grip(LEFT, 0.0)
		await _both_hands(rig, station, carrying, other, 4)
	rig.force_hand(LEFT, null)
	rig.force_grip(LEFT, -1.0)


## THE OTHER HAND'S BEAM ON THE CONTROL CALLED `named`, and one pull of its trigger -- the way tests/clipboard.gd presses
## the clipboard: the control's centre on the page, turned into a point on the glass, the hand thirty centimetres off the
## glass looking at it. Both hands placed again every frame, because the board rides the carrying hand.
func _beam_press(rig: PilotRig, station: CockpitStation, board: SnapBoard, named: String, carrying: Transform3D) -> void:
	var panel: TouchPanel = board.panel()
	var target: Control = board.page().control_named(named)
	var screen := panel.get("_screen") as SubViewport
	if target == null or screen == null:
		_check("the_snap_board_has_a_control_called_%s" % named.to_snake_case(), false, "none")
		return
	var centre: Vector2 = target.get_global_rect().get_center()
	var on_glass := Vector3((centre.x / float(screen.size.x) - 0.5) * panel.size.x,
		(0.5 - centre.y / float(screen.size.y)) * panel.size.y, 0.0)
	for frame in range(9):
		rig.force_hand(RIGHT, station.global_transform * carrying)
		var aimed_at: Vector3 = panel.to_global(on_glass)
		var normal: Vector3 = panel.global_basis.z.normalized()
		var up: Vector3 = panel.global_basis.y.normalized()
		var from: Vector3 = aimed_at + normal * 0.30
		rig.force_hand(LEFT, Transform3D(Basis.looking_at(aimed_at - from, up), from))
		if frame == 3:
			rig.force_input(LEFT, Bind.TRIGGER, 1.0)
		elif frame == 5:
			rig.force_input(LEFT, Bind.TRIGGER, 0.0)
		await get_tree().physics_frame
	rig.force_input(LEFT, Bind.TRIGGER, null)
	rig.force_hand(LEFT, null)


## ---- the player's own grid file ---------------------------------------------------------------------------

func _borrow_the_grid_file() -> String:
	return FileAccess.get_file_as_string(PlacingGrid.path) if FileAccess.file_exists(PlacingGrid.path) else ""


func _give_back_the_grid_file(kept: String) -> void:
	if kept.is_empty():
		if FileAccess.file_exists(PlacingGrid.path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PlacingGrid.path))
		return
	var file := FileAccess.open(PlacingGrid.path, FileAccess.WRITE)
	file.store_string(kept)
	file.close()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL " + ", ".join(_failures))
	get_tree().quit()
