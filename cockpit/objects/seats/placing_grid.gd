extends RefCounted
class_name PlacingGrid
## THE GRID A CONTROL IS PUT DOWN ON, while the cockpit is being built: a step for where it goes and a step for which
## way it faces, each of which can be switched off.
##
## Asked for by the user on 2026-09-13: "toggle 'snap to grid' sometimes, and control the granularity with the
## joystick", for rotation angles and for x/y/z. A lever dragged by hand is good to a few millimetres and a degree or
## two, and a row of switches that are nearly in line is a row that looks broken. So a control being PLACED -- never
## one being worked -- is rounded onto this grid before it is drawn, which is also what `CockpitLayout` then writes.
##
## THE STATION'S FRAME, and nothing else. `VehicleControl.offer_hand_to_place` moves a control in the frame of what it
## is bolted to, and `CockpitLayout` writes "at" and "facing" in that frame; snapping anywhere else would put a control
## on a grid the saved file cannot see. Position is rounded relative to the station's origin, which is the seat
## anchor on the play-space floor; rotation per Euler axis in the order `Node3D.rotation` uses (YXZ), which is the
## order the saved "facing" is read back in.
##
## THE PILOT'S. What grid somebody lays a cockpit out on is a tool preference, never sent and never shared: one
## player's 15-degree habit is nobody else's business. It is kept in `user://`, beside the layouts, so the grid you
## chose is the grid you get next session -- and it is ONE grid, not one per control, because the step should not
## change when you pick up the next lever.
##
## A pure arithmetic object with no scene in it, so `snapped` can be checked without a rig -- and so the rig, the
## board and the thumbstick all ask one thing rather than three copies of it.

## WHAT THE THUMBSTICK AND THE CLICK WORK ON. One of the two at a time, chosen on the board, so the stick and the
## board can never disagree about which step a flick just changed.
enum Quantity { ROTATION, POSITION }

## Rotation steps, in degrees: 5 to 90 in fives, as asked.
const ROTATION_MIN: int = 5
const ROTATION_MAX: int = 90
const ROTATION_BY: int = 5
## Position steps, in metres. Every one divides a millimetre exactly, so `CockpitLayout._triple`'s rounding keeps a
## saved control on the grid it was put on.
const POSITION_STEPS: Array[float] = [0.005, 0.01, 0.02, 0.05, 0.10]

## THE DEFAULTS, each written once and used at every place a value can be missing -- a fresh grid, a file that does
## not say, a file that is not a file. A rotation that starts at a quarter of a right angle and a centimetre are the
## two a person reaches for first.
const DEFAULT_ROTATION_STEP: int = 15
const DEFAULT_POSITION_STEP: float = 0.01

## Where it is kept, beside the cockpits it lays out: the player's folder in the game, a suite's own in a suite. See
## CockpitLayout.folder.
##
## ASKED FROM THE COMMAND LINE, NOT READ OFF CockpitLayout.folder: static vars of two scripts initialise in whatever
## order the scripts load, and on 2026-09-19 a merge that touched autoload/sim.gd made this one load first, when
## CockpitLayout.folder was still "" -- so the grid went to "snap.json" beside nothing, and builder's out-of-the-
## player's-folder check caught it. folder_for is a pure function of the arguments, so both agree whatever loads first.
static var path: String = CockpitLayout.folder_for(OS.get_cmdline_args()).path_join("snap.json")
const UNITS: String = "rotation_step in degrees; position_step in metres; both in the station's own frame"

var rotation_on: bool = false
var rotation_step: int = DEFAULT_ROTATION_STEP
var position_on: bool = false
var position_step: float = DEFAULT_POSITION_STEP
## Which of x, y and z the position step applies to. All three by default: a grid you have to switch on per axis
## before it does anything is a grid that seems not to work.
var on_x: bool = true
var on_y: bool = true
var on_z: bool = true
var stick_adjusts: Quantity = Quantity.ROTATION


## ---- the thumbstick and the click ------------------------------------------------------------------------

## THE CLICK: snap on or off, for whichever quantity the stick adjusts.
func toggle() -> void:
	if stick_adjusts == Quantity.ROTATION:
		rotation_on = not rotation_on
	else:
		position_on = not position_on


## A FLICK: `notches` along the steps of whichever quantity the stick adjusts, stopping at the ends rather than going
## round. Up is a coarser grid; a flick past 90 degrees stays at 90.
func step_by(notches: int) -> void:
	step_by_for(stick_adjusts, notches)


## THE SAME STEP, FOR A NAMED QUANTITY rather than whichever the stick is on: what the snap board's − and + buttons ask
## for, each beside its own row. One piece of arithmetic for the thumb and the board.
func step_by_for(quantity: int, notches: int) -> void:
	if quantity == Quantity.ROTATION:
		rotation_step = clampi(rotation_step + notches * ROTATION_BY, ROTATION_MIN, ROTATION_MAX)
		return
	var at: int = _position_index()
	position_step = POSITION_STEPS[clampi(at + notches, 0, POSITION_STEPS.size() - 1)]


## Where the current position step is in the list, or the default's place when it is somehow not in it.
func _position_index() -> int:
	for i in range(POSITION_STEPS.size()):
		if is_equal_approx(POSITION_STEPS[i], position_step):
			return i
	return POSITION_STEPS.find(DEFAULT_POSITION_STEP)


## ---- the arithmetic -------------------------------------------------------------------------------------

## A PLACED TRANSFORM, PUT ON THE GRID: position rounded on the enabled axes, rotation rounded per Euler axis, each only
## if its snap is on. In the station's frame, as the transform arrives from `offer_hand_to_place`.
##
## THE GRIP MOVES OFF THE HAND by up to half a step. That is what a grid is; a control that stayed under the hand could
## not also be on it.
func snapped(placed: Transform3D) -> Transform3D:
	var out: Transform3D = placed
	if rotation_on:
		var turned: Vector3 = placed.basis.get_euler(EULER_ORDER_YXZ)
		var step: float = float(rotation_step)
		turned = Vector3(deg_to_rad(snappedf(rad_to_deg(turned.x), step)),
			deg_to_rad(snappedf(rad_to_deg(turned.y), step)),
			deg_to_rad(snappedf(rad_to_deg(turned.z), step)))
		out.basis = Basis.from_euler(turned, EULER_ORDER_YXZ)
	if position_on:
		var at: Vector3 = placed.origin
		out.origin = Vector3(snappedf(at.x, position_step) if on_x else at.x,
			snappedf(at.y, position_step) if on_y else at.y,
			snappedf(at.z, position_step) if on_z else at.z)
	return out


## ---- where the snap board sits on the hand ------------------------------------------------------------------
##
## THE BOARD MOVES, because a cockpit is crowded (the user, 2026-09-13). The other hand takes it by the edge and drags
## it, and where it was left is kept -- here, with the rest of the pilot's grid, and between sessions.
##
## ONE OFFSET, TWO HANDS. It is kept in the RIGHT hand's frame and mirrored for the left -- x, yaw and roll negated --
## because a board a player has put just outboard of their right wrist is one they want just outboard of their left
## when they pick a lever up with the other hand. Two offsets would be two things to set.
##
## CAPPED A FOREARM FROM THE HAND. A board dragged across the cockpit and let go behind the seat is a board nobody can
## find again, and a working hand cannot reach round to fetch it. So its origin is kept within `BOARD_REACH` of the
## hand, and a drag past that stops there (team-lead approved the cap, 2026-09-13).

## Outboard of the grip, a little up and forward, tilted back towards the face: the clipboard's own lie (Clipboard.AT,
## Clipboard.TILT), moved out to the side so the hand that carries a lever is not looking through the board at it.
const BOARD_AT := Vector3(0.12, 0.05, -0.10)
const BOARD_FACING := Vector3(-32.0, -20.0, 0.0)
## How far from the working hand the board may be put, in metres: about a forearm.
const BOARD_REACH: float = 0.45

var board_at: Vector3 = BOARD_AT
## Degrees, YXZ, as a layout's "facing" is.
var board_facing: Vector3 = BOARD_FACING


## WHERE THE BOARD SITS ON `hand` (0 left, 1 right), in that hand's frame.
func board_offset_for(hand: int) -> Transform3D:
	var at: Vector3 = board_at
	var facing: Vector3 = board_facing
	if hand == 0:
		at.x = -at.x
		facing.y = -facing.y
		facing.z = -facing.z
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(facing.x), deg_to_rad(facing.y), deg_to_rad(facing.z)),
		EULER_ORDER_YXZ), at)


## THE BOARD WAS LEFT HERE on `hand`, in that hand's frame: kept in the right hand's frame, and capped.
func put_the_board(hand: int, offset: Transform3D) -> void:
	var at: Vector3 = offset.origin
	if at.length() > BOARD_REACH:
		at = at.normalized() * BOARD_REACH
	var facing: Vector3 = offset.basis.get_euler(EULER_ORDER_YXZ)
	facing = Vector3(rad_to_deg(facing.x), rad_to_deg(facing.y), rad_to_deg(facing.z))
	if hand == 0:
		at.x = -at.x
		facing.y = -facing.y
		facing.z = -facing.z
	board_at = at
	board_facing = facing


## RESET POSITION.
func reset_the_board() -> void:
	board_at = BOARD_AT
	board_facing = BOARD_FACING


## ---- kept between sessions --------------------------------------------------------------------------------

## WRITE IT DOWN. Returns whether it was written, so the board can say so rather than a grid quietly not surviving.
func write() -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[cockpit] could not write %s" % path)
		return false
	file.store_string(JSON.stringify({
		"units": UNITS,
		"rotation_on": rotation_on,
		"rotation_step": rotation_step,
		"position_on": position_on,
		"position_step": position_step,
		"axes": {"x": on_x, "y": on_y, "z": on_z},
		"stick_adjusts": "position" if stick_adjusts == Quantity.POSITION else "rotation",
		# WHERE THE SNAP BOARD SITS, in the right hand's frame: metres, and degrees YXZ to a thousandth, as a layout's
		# facing is -- 0.1 would be 1.7e-3 rad, more than the 1e-4 the reload checks hold everything else to.
		"board": {"at": [snappedf(board_at.x, 0.001), snappedf(board_at.y, 0.001), snappedf(board_at.z, 0.001)],
			"facing": [snappedf(board_facing.x, 0.001), snappedf(board_facing.y, 0.001),
				snappedf(board_facing.z, 0.001)]},
	}, "  "))
	file.close()
	return true


## THE GRID THIS PLAYER LAST USED, or a fresh one.
##
## EVERY FAILURE IS "THERE ISN'T ONE", like a layout: no file, not JSON, not an object. And EVERY VALUE TAKES ITS
## DEFAULT AT ITS OWN LINE -- a hand-edited file that leaves out the rotation step gets fifteen degrees, not the bottom
## of the range. A step out of range is clamped onto it and said, and a position step that is not one of the list
## goes back to the default and is said, because a grid of 3.7 cm is a grid nobody chose.
static func read() -> PlacingGrid:
	var grid := PlacingGrid.new()
	if not FileAccess.file_exists(path):
		return grid
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return grid
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("[cockpit] %s is not a snap grid" % path)
		return grid
	var saved: Dictionary = parsed
	grid.rotation_on = bool(saved.get("rotation_on", false))
	var asked_rotation: int = int(saved.get("rotation_step", DEFAULT_ROTATION_STEP))
	# ROUNDED THROUGH `snappedf`, which `CockpitLayout._triple` already uses on this engine, rather than an integer
	# twin nothing in the workshop has ever called.
	grid.rotation_step = clampi(int(snappedf(float(asked_rotation), float(ROTATION_BY))), ROTATION_MIN, ROTATION_MAX)
	if grid.rotation_step != asked_rotation:
		push_warning("[cockpit] snap rotation step %d is not one of 5..90 in fives; using %d" % [
			asked_rotation, grid.rotation_step])
	grid.position_on = bool(saved.get("position_on", false))
	grid.position_step = float(saved.get("position_step", DEFAULT_POSITION_STEP))
	var listed: bool = false
	for step in POSITION_STEPS:
		listed = listed or is_equal_approx(step, grid.position_step)
	if not listed:
		push_warning("[cockpit] snap position step %s is not one of %s; using %s" % [
			grid.position_step, POSITION_STEPS, DEFAULT_POSITION_STEP])
		grid.position_step = DEFAULT_POSITION_STEP
	var axes: Dictionary = saved.get("axes", {}) as Dictionary if saved.get("axes", {}) is Dictionary else {}
	grid.on_x = bool(axes.get("x", true))
	grid.on_y = bool(axes.get("y", true))
	grid.on_z = bool(axes.get("z", true))
	# `PlacingGrid.Quantity` AND NOT A BARE `Quantity`. Inside this file the two are one enum; tests/lint.gd compiles the
	# source as an unnamed copy, where a bare `Quantity` is the copy's own enum and `grid` -- a real PlacingGrid -- wants
	# the named one: "cannot be assigned to a variable of type PlacingGrid.Quantity".
	grid.stick_adjusts = PlacingGrid.Quantity.POSITION if String(saved.get("stick_adjusts", "rotation")) == "position" \
		else PlacingGrid.Quantity.ROTATION
	# WHERE THE BOARD SITS, each its own default, and a board saved further out than a forearm put back within one.
	var board: Dictionary = saved.get("board", {}) as Dictionary if saved.get("board", {}) is Dictionary else {}
	grid.board_at = _triple_or(board.get("at"), BOARD_AT)
	grid.board_facing = _triple_or(board.get("facing"), BOARD_FACING)
	if grid.board_at.length() > BOARD_REACH:
		push_warning("[cockpit] the snap board was saved %.2f m from the hand; put back within %.2f m" % [
			grid.board_at.length(), BOARD_REACH])
		grid.board_at = grid.board_at.normalized() * BOARD_REACH
	return grid


## Three numbers out of a file, or `fallback` when they are not three numbers.
static func _triple_or(from: Variant, fallback: Vector3) -> Vector3:
	var list: Array = from as Array if from is Array else []
	if list.size() < 3:
		return fallback
	return Vector3(float(list[0]), float(list[1]), float(list[2]))
