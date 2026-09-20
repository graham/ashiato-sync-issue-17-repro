extends SubViewportContainer
class_name DioramaView
## THE WINDOW ONTO THE BOARD: a `SubViewport` WITH A WORLD OF ITS OWN, holding a `DioramaBoard`, a light and a camera
## you can walk round it with. Dropped into a flat screen wherever a miniature is wanted; `world/control_station.gd` is
## the first and so far only place.
##
## ---------------------------------------------------------------------------------------------------
## `own_world_3d` IS THE WHOLE ARCHITECTURE, IN ONE PROPERTY
## ---------------------------------------------------------------------------------------------------
##
## `world/level_map.gd` does the opposite and says why: *"Share the level's World3D, then freeze its picture. A
## SubViewport otherwise owns an empty scenario and its camera sees only the background."* For a photograph of the real
## island that is exactly right, and it is why that file has to freeze what it renders.
##
## **Here the empty scenario is the feature.** This viewport's world contains the board, one directional light and
## nothing else -- no terrain, no mountains, no woodland, no ninety aircraft, no sea shader, nothing further from the
## origin than 0.6 m. That is what makes it cheap enough to render EVERY FRAME where the flat map must be frozen after
## one, and it is the answer to the user's *"it doesn't incur the same 3d drawing issues and distance calculations"*.
##
## It also means the board cannot accidentally show something radar did not: there is physically nothing else in the
## world to draw. A regression that handed the board `Sim.current` would still have to put pieces on it one at a time.
##
## ---------------------------------------------------------------------------------------------------
## THE CAMERA IS LOW ON PURPOSE
## ---------------------------------------------------------------------------------------------------
##
## It opens at `PITCH_AT` -- about twenty-five degrees above the board rather than looking down at it -- because
## straight down is the picture the flat plot already gives, and a board seen from straight down has thrown away the
## only thing it has that the plot has not. From low down, a stalk's length IS the contact's altitude and you read it
## without looking at the panel.
##
## Dragging turns it and the wheel dollies, and the same three moves are on the arrow keys and `,`/`.` -- not for
## comfort, but because `docs/testing.md` asks a device for "an answer a robot can give through real input", and a
## robot has no mouse wheel. Both `keycode` and `physical_keycode` are read (rule 9).

## Where the camera starts: how far from the middle of the board, and how high above its plane.
##
## **BOTH DIRECTIONS WERE WRONG ONCE.** At 1.45 the board ran off the edges as soon as the camera was dropped or
## turned; at 1.9 it sat in the middle of a lot of black, which the side-by-side picture showed plainly beside a flat
## plot that fills its half. 1.55 holds the whole board with room over it for the stalks, which are part of the
## picture, and still fills the frame.
const DOLLY_AT: float = 1.55
const PITCH_AT: float = 0.44
const YAW_AT: float = 0.6
## How close and how far it may be pulled, board metres. Closer than `DOLLY_NEAR` and the near plane eats the board.
const DOLLY_NEAR: float = 0.55
const DOLLY_FAR: float = 4.2
## How far up and down it may be swung. Never past the horizontal, because a board seen from below is nonsense, and
## never quite to straight down, because that is the flat plot and the flat plot is one key away.
##
## `PITCH_LOW` WAS 0.06 AND THAT IS TOO FLAT TO USE: the board goes edge-on, half the picture is the black under it,
## and the contacts stack into a hedge. 0.14 is low enough that a stalk's length is its altitude and high enough that
## you can still see which bit of coast it is over.
const PITCH_LOW: float = 0.14
const PITCH_HIGH: float = 1.40
## The camera's vertical field, degrees. Narrow-ish, as a person leaning over a table sees it, and because a wide angle
## on a small board bends the coastline.
const FOV: float = 42.0

const TURN_PER_PIXEL: float = 0.007
const TURN_PER_PRESS: float = 0.10
const DOLLY_PER_NOTCH: float = 0.12

var board: DioramaBoard = null

var _glass: SubViewport = null
var _camera: Camera3D = null
var _yaw: float = YAW_AT
var _pitch: float = PITCH_AT
var _dolly: float = DOLLY_AT


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_glass = SubViewport.new()
	_glass.name = "DioramaGlass"
	# A WORLD OF ITS OWN. See the doc block -- this is the line the feature is about.
	_glass.own_world_3d = true
	_glass.transparent_bg = false
	_glass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_glass.msaa_3d = Viewport.MSAA_4X
	add_child(_glass)

	board = DioramaBoard.new()
	board.name = "DioramaBoard"
	_glass.add_child(board)

	# THE LIGHT AND THE BACKGROUND ARE THE BOARD'S OWN, not the level's. A diorama is lit by the room it stands in, and
	# the level's own sun is wherever the level's clock put it -- a board that went dark at dusk would be a display
	# failing for a reason nothing on screen explains.
	var sun := DirectionalLight3D.new()
	sun.name = "RoomLight"
	sun.rotation = Vector3(-0.95, -0.7, 0.0)
	sun.light_energy = 1.15
	_glass.add_child(sun)

	var room := WorldEnvironment.new()
	room.name = "Room"
	var air := Environment.new()
	air.background_mode = Environment.BG_COLOR
	air.background_color = Color(0.04, 0.05, 0.06)
	air.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	air.ambient_light_color = Color(0.62, 0.68, 0.76)
	air.ambient_light_energy = 0.55
	air.fog_enabled = false
	room.environment = air
	_glass.add_child(room)

	_camera = Camera3D.new()
	_camera.name = "BoardCamera"
	_camera.fov = FOV
	# NEAR AND FAR FOR A TABLE, not for a world. The engine's defaults are 0.05 and 4,000, which over a 1.2 m board
	# spends the entire depth buffer on empty space behind it.
	_camera.near = 0.02
	_camera.far = 12.0
	_glass.add_child(_camera)
	_aim()


## BUILD THE BOARD for a level, and say what it cost. Passed straight through to `DioramaBoard.build`; the extent and
## the middle come from `LevelMap` so the board and the flat plot cover the same ground (rule 4).
func lay_the_board(covering: float, middle: Vector2) -> Dictionary:
	return board.build(covering, middle)


## THE PICTURE, HANDED ON UNCHANGED. `rows` is `RadarSet.read`'s shape and this view decides nothing about it. `age` is
## how old the picture is and is used only if the board is dead reckoning (`DioramaBoard.reckoning`).
func show_contacts(rows: Array, age: float = 0.0) -> void:
	board.show_contacts(rows, age)


## DRIFT ROUND THE BOARD BY A SMALL AMOUNT, radians. For a reel that wants a slow continuous orbit rather than the
## stepped presses `drive` makes: a still camera over a board makes it very hard to tell a frozen picture from a
## frozen render, which is exactly the thing `tests/diorama_reel.gd` is filmed to judge.
func orbit(by: float) -> void:
	_turn(by, 0.0)


## BACK TO THE OPENING VIEW. A probe taking several pictures needs this: without it each shot is driven from wherever
## the last one left the camera, and the first run of `tests/diorama_shot.gd` photographed its comparison from a
## near-vertical 0.97 rad because nine presses of UP had been added to a view already driven flat.
func look_from_the_default() -> void:
	_yaw = YAW_AT
	_pitch = PITCH_AT
	_dolly = DOLLY_AT
	_aim()


## WHERE THE CAMERA IS, for a suite that wants to say the view moved without photographing it.
func eye() -> Dictionary:
	return {"yaw": _yaw, "pitch": _pitch, "dolly": _dolly, "at": _camera.position if _camera != null else Vector3.ZERO}


func _aim() -> void:
	if _camera == null:
		return
	_camera.position = Vector3(
		sin(_yaw) * cos(_pitch) * _dolly,
		sin(_pitch) * _dolly,
		cos(_yaw) * cos(_pitch) * _dolly)
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _turn(by_yaw: float, by_pitch: float) -> void:
	_yaw = wrapf(_yaw + by_yaw, -PI, PI)
	_pitch = clampf(_pitch + by_pitch, PITCH_LOW, PITCH_HIGH)
	_aim()


func _pull(by: float) -> void:
	_dolly = clampf(_dolly + by, DOLLY_NEAR, DOLLY_FAR)
	_aim()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		var moved := event as InputEventMouseMotion
		_turn(-moved.relative.x * TURN_PER_PIXEL, moved.relative.y * TURN_PER_PIXEL)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_WHEEL_UP:
			_pull(-DOLLY_PER_NOTCH)
			accept_event()
		elif click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_pull(DOLLY_PER_NOTCH)
			accept_event()


## THE KEYS, so a robot can drive the view (`docs/testing.md`, "an answer a robot can give through real input"). Both
## `keycode` and `physical_keycode` are read, because a suite sends one and a person's keyboard sends the other.
func drive(event: InputEventKey) -> bool:
	if event == null or not event.pressed:
		return false
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	match key:
		KEY_LEFT:
			_turn(-TURN_PER_PRESS, 0.0)
		KEY_RIGHT:
			_turn(TURN_PER_PRESS, 0.0)
		KEY_UP:
			_turn(0.0, TURN_PER_PRESS)
		KEY_DOWN:
			_turn(0.0, -TURN_PER_PRESS)
		KEY_COMMA:
			_pull(-DOLLY_PER_NOTCH)
		KEY_PERIOD:
			_pull(DOLLY_PER_NOTCH)
		_:
			return false
	return true
