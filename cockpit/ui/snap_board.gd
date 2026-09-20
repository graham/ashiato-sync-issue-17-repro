extends Node3D
class_name SnapBoard
## THE SNAP BOARD: a small board on the hand that is carrying a control in the builder, saying which snaps are on and
## how fine, worked with the OTHER hand's beam.
##
## Asked for on 2026-09-13, and clarified: "similar to an iPad but attached to the controller that is working with the
## device." So it is a TouchPanel with a page, like the Clipboard, parented to the WORKING hand -- it travels with the
## lever you are carrying -- and the other hand points at it and presses with its trigger. Then: "the menu that is on the
## device might need to be moved in a crowded cockpit." So the other hand can take it by its EDGE and put it somewhere
## else, and where it was left is kept (PlacingGrid.board_at).
##
## IT ANNOUNCES AND DOES NOT ACT. The page's choices pass straight through as signals, and where the board was put down
## is announced with `put_down`; the rig decides what each means and hands the grid back through `show_grid`. The board
## knows nothing about grids, rigs or which hand is which beyond the number it was given.
##
## THE GLASS IS THE POINTER'S AND THE EDGE IS THE HAND'S. A grip anywhere on it would drag the board every time somebody
## reached through it to press a button, so only the band round the glass takes a hand.

const PAGE := preload("res://ui/menus/snap_page.tscn")

## How big the glass is, in metres, and how wide the band round it that a hand takes hold of. Smaller than the clipboard
## (Clipboard.SIZE, 0.24 x 0.30): this one has three rows on it and rides on a hand that is also carrying a lever.
const SIZE := Vector2(0.16, 0.20)
## THE EDGE. Wide enough to be found by a hand that cannot feel it -- a fingertip is never quite where it is believed to
## be (mfd_panel.gd says the same about bezels) -- and no wider than a bezel looks, or it is a frame round a picture.
const EDGE: float = 0.03
## How far off the plane of the board a grip still counts as on its edge, in metres: the panel's own finger distance,
## so taking the board and pressing it are measured the same way.
const HOLD_DEPTH: float = TouchPanel.FINGER
## THE SAME DENSITY AS THE CLIPBOARD, 1024 pixels across 0.24 m, so a word on one is the same size as on the other.
const PIXELS: int = 683

signal chose_rotation_on(on: bool)
signal chose_rotation_step(by: int)
signal chose_position_on(on: bool)
signal chose_position_step(by: int)
signal chose_axis(axis: int, on: bool)
signal chose_stick(quantity: int)
signal chose_reset_position()
## THE OTHER HAND LET GO OF THE EDGE, with the board here, in the working hand's frame. The rig keeps it.
signal put_down(offset: Transform3D)

## Which hand the board is on: 0 left, 1 right. Set by the rig when it hangs the board on a hand.
var working_hand: int = 1
## Which hand has the board by its edge, or -1.
var held_by: int = -1

var _panel: TouchPanel = null
var _page: SnapPage = null
var _hand_when_taken := Transform3D.IDENTITY
var _board_when_taken := Transform3D.IDENTITY


## AWAY FROM THE MOMENT IT EXISTS, and not only once it is in the tree. A Node3D is born visible and `_ready` only runs
## when it is added, so a board the rig had just made read as already UP on the hand asking for it -- the first trigger
## put away a board that had never been shown, and it was never hung on the hand at all.
func _init() -> void:
	visible = false


func _ready() -> void:
	_panel = TouchPanel.new()
	_panel.name = "Glass"
	_panel.page = PAGE
	_panel.size = SIZE
	_panel.pixels = PIXELS
	_panel.bezel = true
	add_child(_panel)
	_page = _panel.shown() as SnapPage
	if _page != null:
		_page.chose_rotation_on.connect(func(on: bool): chose_rotation_on.emit(on))
		_page.chose_rotation_step.connect(func(by: int): chose_rotation_step.emit(by))
		_page.chose_position_on.connect(func(on: bool): chose_position_on.emit(on))
		_page.chose_position_step.connect(func(by: int): chose_position_step.emit(by))
		_page.chose_axis.connect(func(axis: int, on: bool): chose_axis.emit(axis, on))
		_page.chose_stick.connect(func(quantity: int): chose_stick.emit(quantity))
		_page.chose_reset_position.connect(func(): chose_reset_position.emit())
	visible = false


func is_up() -> bool:
	return visible


func show_board(up: bool) -> void:
	visible = up
	if not up:
		held_by = -1


## DRAW THE GRID. See SnapPage.show_grid.
func show_grid(grid: PlacingGrid) -> void:
	if _page != null:
		_page.show_grid(grid)
	if _panel != null:
		_panel.redraw()


func page() -> SnapPage:
	return _page


func panel() -> TouchPanel:
	return _panel


## ---- the beam ------------------------------------------------------------------------------------------------

## THE OTHER HAND'S BEAM IS NOT KEPT HERE. The rig hands this board's glass (`panel`) to `HandBeam` with every other glass
## that is up, and the beam aims the first one along its ray and keeps the one press state. This board had its own copy
## of that state until 2026-09-14, which could not know about a pull held on the clipboard or a monitor.

## WHAT THE FINGERS DO WHILE IT IS UP. On the OTHER hand the trigger is the beam's press, so it is taken away from every
## table under this one -- a free hand that is also carrying a lever would otherwise open a board of its own with the
## same pull. On the working hand the trigger stays the builder's, which is what closes the board.
func bindings(hand: int) -> Dictionary:
	if not visible or hand == working_hand:
		return {}
	return {Bind.TRIGGER: Bind.nothing()}


## ---- the edge -------------------------------------------------------------------------------------------------

## WHETHER A HAND AT `at` -- in THIS BOARD'S OWN FRAME -- IS ON ITS EDGE: inside the outer rectangle, outside the glass,
## and close to the plane. Static, so it can be checked with no board built.
static func edge_holds(at: Vector3) -> bool:
	if absf(at.z) > HOLD_DEPTH:
		return false
	var half_outer := Vector2(SIZE.x * 0.5 + EDGE, SIZE.y * 0.5 + EDGE)
	var inside_outer: bool = absf(at.x) <= half_outer.x and absf(at.y) <= half_outer.y
	var inside_glass: bool = absf(at.x) < SIZE.x * 0.5 and absf(at.y) < SIZE.y * 0.5
	return inside_outer and not inside_glass


## THE OTHER HAND, OFFERED TO THE EDGE, once a frame. `hand_at` is that hand's pose in the WORKING hand's frame -- the
## frame this board is placed in -- so the drag is the same subtraction `VehicleControl.offer_hand_to_place` does, and the
## aeroplane's motion is not a term in it. Returns whether this hand is on the board, so the rig offers it to nothing else.
##
## SQUEEZE AND HOLD, no tap-to-latch: the latch is for levers you fly with, not for furniture you are putting somewhere.
## CAPPED at `PlacingGrid.BOARD_REACH` from the working hand, so a board cannot be dragged off behind the seat.
func offer_edge(hand: int, hand_at: Transform3D, grip: float) -> bool:
	if not visible or hand == working_hand:
		return false
	if held_by == hand:
		if grip < VehicleControl.GRAB_OFF:
			held_by = -1
			put_down.emit(transform)
			return false
		var moved: Transform3D = hand_at * _hand_when_taken.affine_inverse() * _board_when_taken
		if moved.origin.length() > PlacingGrid.BOARD_REACH:
			moved.origin = moved.origin.normalized() * PlacingGrid.BOARD_REACH
		transform = moved
		return true
	if held_by >= 0 or grip < VehicleControl.GRAB_ON:
		return false
	if not edge_holds(transform.affine_inverse() * hand_at.origin):
		return false
	held_by = hand
	_hand_when_taken = hand_at
	_board_when_taken = transform
	return true
