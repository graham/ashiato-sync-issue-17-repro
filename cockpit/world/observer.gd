extends Camera3D
class_name Observer
## THE WORLD WITH NOBODY IN IT, WATCHED FROM OUTSIDE.
##
##   Godot --path cockpit -- --level=watch
##   Godot --path cockpit -- --level=watch --kind=tank
##
## Every level in this project until now has put a player in a seat, which is right -- it is
## a game about flying things -- and wrong for the one job a game also has to do, which is
## LOOKING AT ITSELF. A hundred and forty machines fly themselves, and until now the only
## way to watch one was to fly a second machine after it, in a headset, with hands.
##
## So: no rig, no seat, no XR, no hands. A camera that flies, chases whatever you point it
## at, and steps through the world's vehicles in order. It runs on a monitor, it runs
## headless with `--quit-after`, and nothing in it needs a person.
##
## `--level=fly` is the neighbouring door and answers a different question: ONE craft, in an
## EMPTY sky, with its trim written down. This one is the whole world, at once.

## How far behind and above a chased craft the camera sits, in multiples of its own length.
## Read off the aircraft rather than fixed, so a 333 m carrier and a 6 m fighter are both
## in frame.
const BEHIND: float = 3.2
const ABOVE: float = 0.9
## And never closer than this, for the small things.
const NEAR_ENOUGH: float = 14.0

const FLY_SPEED: float = 120.0
const FAST: float = 8.0
const LOOK: float = 0.0022
## Laps for the scenery probe; nothing unless it is running. See `world/stopwatch.gd`.
const STOPWATCH := preload("res://world/stopwatch.gd")

## The level, asked for the node a vehicle is drawn by. Set by whoever builds this.
var world: Node = null

var _chasing: int = 0
var _only_kind: int = -1
## A kind asked for on the command line before the world had anything in it. Kept until it
## can be honoured: the level seeds its machines a tick after the simulation is ready, and
## `Sim.current` is still empty on the frame that asks.
var _waiting_for: int = -1
var _yaw: float = 0.0
var _pitch: float = -0.15
var _board: Label = null
## Seconds between rounds when the camera has been told to keep firing, or 0 for never.
## `--fire=3` on the command line: a gun that goes off on its own is the only way to look
## at what one does without a pair of hands on it.
var _repeat: float = 0.0
var _next_round: float = 0.0


func _ready() -> void:
	current = true
	near = 0.25
	far = 24000.0
	position = Vector3(0.0, 260.0, 400.0)
	_build_the_board()
	# THE SPOTTING BOXES ARE THE LEVEL'S, AND IT ASKS FOR THEM BY NAME. Every action in
	# this game is bound by `PilotRig`, and there is no rig here -- so the one action the
	# world reads outside a cockpit is bound from here instead, on B rather than the rig's
	# D, which this camera is already using to fly sideways.
	if not InputMap.has_action("spot"):
		InputMap.add_action("spot")
		var press := InputEventKey.new()
		press.physical_keycode = KEY_B
		InputMap.action_add_event("spot", press)
	# AND THE FINISH, on the same key the desk uses, for the same reason: there is no rig
	# here to bind it, and a camera for looking at the world is the first place anybody
	# wants to compare the two. `Finish` reads the action; this only gives it a key.
	if not InputMap.has_action(SceneryFinish.ACTION):
		InputMap.add_action(SceneryFinish.ACTION)
		var finish := InputEventKey.new()
		finish.physical_keycode = KEY_BACKSLASH
		finish.keycode = KEY_BACKSLASH
		InputMap.action_add_event(SceneryFinish.ACTION, finish)
	_repeat = maxf(_asked_seconds("fire"), 0.0)
	if _repeat > 0.0:
		print("[watch] firing every %.1f s" % _repeat)
	print("[watch] N/P next and previous craft · K by kind · F free camera · G fire · "
		+ "B boxes · backslash plain or fine scenery · right mouse look · WASD/QE fly · shift faster")


func _process(delta: float) -> void:
	var watch: int = STOPWATCH.start()
	if _waiting_for >= 0 and _chasing == 0:
		only(_waiting_for)
	if _repeat > 0.0:
		_next_round -= delta
		if _next_round <= 0.0:
			_next_round = _repeat
			_pull_the_trigger()
	_fly(delta)
	_chase()
	_write_the_board()
	STOPWATCH.lap(&"observer", watch)


## ---- what it is looking at ------------------------------------------------------------

## THE CRAFT IT IS FOLLOWING, or null while the camera is free. Asked of the level every
## frame rather than held: vehicles are made and retired while nobody is watching, and a
## node kept here would eventually be one that has been freed.
func _watched() -> VehicleView:
	if _chasing == 0 or world == null:
		return null
	var view: Node = world.view_of(_chasing)
	return view as VehicleView if is_instance_valid(view) else null


func _chase() -> void:
	var view: VehicleView = _watched()
	if view == null:
		return
	# BEHIND AND ABOVE, IN THE CRAFT'S OWN FRAME, so a machine in a turn is watched from
	# over its own tail rather than swung around by the world.
	var size: float = maxf((Sim.geometry_of(view.kind).get("extents", Vector3.ONE)
		as Vector3).z * 2.0, 4.0)
	var back: float = maxf(size * BEHIND, NEAR_ENOUGH)
	# ORTHONORMAL, because a view drawn through a pair of `Spectacles` carries a scale in its basis.
	var pose: Transform3D = view.global_transform.orthonormalized()
	global_position = pose.origin + pose.basis.z * back + Vector3.UP * (size * ABOVE)
	look_at(pose.origin, Vector3.UP)


## POINT THE CAMERA AT ONE CRAFT BY NAME. `step` walks the world in order, which is right for a person with a
## keyboard and useless to a probe that knows which machine it wants to photograph (`tests/tower_shot.gd`).
func watch_this(entity: int) -> void:
	_chasing = entity
	_waiting_for = -1


## WHICH CRAFT IS UNDER THE CAMERA, or 0 for none. The tower's buttons command this one, so the camera IS the
## selection and there is no second list to keep in step (`tower_panel.gd`).
func watching() -> int:
	return _chasing


## Step through the world's vehicles in entity order, which is the order they were made in.
## With a kind chosen, only that kind -- which is the difference between finding the one
## tank and pressing a key a hundred and forty times.
func step(by: int) -> void:
	var entities: Array = []
	for entity in Sim.current:
		if _only_kind < 0 or int((Sim.current[entity] as Dictionary).get("kind", -1)) \
				== _only_kind:
			entities.append(int(entity))
	if entities.is_empty():
		_chasing = 0
		return
	entities.sort()
	var at: int = entities.find(_chasing)
	_chasing = entities[posmod(at + by, entities.size())] if at >= 0 \
		else entities[0 if by >= 0 else entities.size() - 1]


## Only craft of this kind, or every kind at -1. Moves to one straight away, because a
## filter that leaves the camera pointing at the wrong thing looks like it did nothing.
func only(kind: int) -> void:
	var told: bool = _only_kind != kind or _waiting_for >= 0
	_only_kind = kind
	_chasing = 0
	step(1)
	# Asked for before there was anything to point at: keep trying, quietly, until the
	# world has one. Announced only when something changes, or a command line that names a
	# kind prints a line a second for ever.
	_waiting_for = kind if (_chasing == 0 and kind >= 0) else -1
	if told and _chasing != 0:
		print("[watch] %s #%d" % [Sim.kind_name(kind) if kind >= 0 else "every kind",
			_short(_chasing)])


func free_camera() -> void:
	_chasing = 0


## STAND HERE AND LOOK AT THAT, and stay put. For anything that has to see the same view
## twice -- `tests/scenery_shot.gd` compares two finishes from one place -- because a view
## flown to by hand is a different view every time. Stops chasing: a chased craft owns the
## camera, and the two would fight.
func look_from(at: Vector3, toward: Vector3) -> void:
	_chasing = 0
	_waiting_for = -1
	global_position = at
	var ahead: Vector3 = (toward - at).normalized()
	# A camera looks down -Z, so the yaw that points it along `ahead` is measured from -Z.
	_yaw = atan2(-ahead.x, -ahead.z)
	_pitch = asin(clampf(ahead.y, -1.0, 1.0))
	rotation = Vector3(_pitch, _yaw, 0.0)


## A number off the command line, or 0. Its own little parser for the same reason the
## bench has one: a level that can be opened directly has to be able to ask what it was
## opened for.
static func _asked_seconds(name: String) -> float:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0].to_lower() == name:
			return parts[1].to_float()
	return 0.0


## FIRE THE GUN OF WHATEVER IS BEING WATCHED, if it has one.
func _pull_the_trigger() -> void:
	if _chasing == 0:
		return
	if int(Sim.fire_gun(_chasing, 0)) == 0:
		print("[watch] nothing fired: no gun on that mount, or still loading")


## ---- the camera itself -----------------------------------------------------------------

func _fly(delta: float) -> void:
	if _chasing != 0:
		return
	var wish := Vector3.ZERO
	wish.x = (1.0 if Input.is_key_pressed(KEY_D) else 0.0) \
		- (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
	wish.z = (1.0 if Input.is_key_pressed(KEY_S) else 0.0) \
		- (1.0 if Input.is_key_pressed(KEY_W) else 0.0)
	wish.y = (1.0 if Input.is_key_pressed(KEY_E) else 0.0) \
		- (1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	if wish.length_squared() > 0.0:
		var pace: float = FLY_SPEED * (FAST if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		global_position += (global_transform.basis * wish.normalized()) * pace * delta
	rotation = Vector3(_pitch, _yaw, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= motion.relative.x * LOOK
		_pitch = clampf(_pitch - motion.relative.y * LOOK, deg_to_rad(-89.0),
			deg_to_rad(89.0))
		# Free camera only: chasing owns the transform, and fighting it every frame reads
		# as a camera that will not turn.
		if _chasing == 0:
			rotation = Vector3(_pitch, _yaw, 0.0)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_N: step(1)
		KEY_P: step(-1)
		KEY_F: free_camera()
		# AND FIRE WHAT IT IS WATCHING. A camera with a trigger is not a player -- it is
		# the only way to see a gun work without a crew, which is what this room is for.
		KEY_G: _pull_the_trigger()
		KEY_K: only(-1 if _only_kind >= Sim.Kind.size() - 1 else _only_kind + 1)


## AN ENTITY, WITHOUT ITS GENERATION. The id carries a generation in its high word, so the
## forty-fifth machine in the world reads as 4294967341 -- a number nobody can hold in their
## head or compare against the next one. The low word is the one a person wants.
static func _short(entity: int) -> int:
	return entity & 0xFFFFFFFF


## ---- what it says ----------------------------------------------------------------------

func _build_the_board() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_board = Label.new()
	# BOTTOM LEFT, because the top left is the world's own status line and two blocks of
	# text in one corner is neither of them readable.
	_board.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_board.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_board.position += Vector2(16.0, -20.0)
	_board.add_theme_font_size_override("font_size", 15)
	_board.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
	layer.add_child(_board)


func _write_the_board() -> void:
	if _board == null:
		return
	var view: VehicleView = _watched()
	var lines: String = "WATCHING  %d vehicles" % Sim.current.size()
	if _only_kind >= 0:
		lines += "  ·  showing %s only" % Sim.kind_name(_only_kind)
	if view == null:
		_board.text = lines + "\nfree camera  ·  N next craft, K by kind"
		return
	var state: Dictionary = Sim.current.get(view.entity, {})
	var speed: float = (state.get("velocity", Vector3.ZERO) as Vector3).length()
	_board.text = "%s\n%s #%d  ·  %.0f m/s  ·  %.0f m" % [lines,
		Sim.kind_name(view.kind).to_upper(), _short(view.entity), speed,
		view.global_position.y]
