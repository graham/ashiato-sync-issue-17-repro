@tool
extends Node3D
class_name TouchPanel
## A GODOT UI ON A FLAT PLANE, that a controller can press.
##
## An ordinary `Control` tree rendered to a `SubViewport` and hung on a quad. That is the
## whole trick, and it is worth having exactly once: a cockpit instrument, a main menu and
## whatever comes next are all a Control tree on a panel, and the only thing that differs is
## what is on it.
##
## TOUCH IS A SYNTHETIC MOUSE EVENT. `press` turns a point on the glass into a click at the
## matching pixel, so a finger, a controller and a mouse all reach a `Button` by the same
## path -- which means a page is authored in the editor like any other UI and nobody writing
## one has to know it will be pressed in a headset.
##
## IT REDRAWS WHEN SOMETHING CHANGES, not every frame. A render target per panel at ninety
## frames a second is a real cost for a page of text that changes when a number does.

## How big the glass is in metres, and how many pixels across it is drawn.
@export var size := Vector2(0.40, 0.30):
	set(value):
		size = value
		if is_inside_tree():
			_lay_out()
@export var pixels: int = 512
## The Control shown on it.
@export var page: PackedScene = null
## A frame round the glass. Off for something meant to look like a screen set into a panel.
@export var bezel: bool = true

## HOW CLOSE A FINGERTIP HAS TO BE to count as touching the glass, in metres.
##
## A property of pressing a panel, so it lives with the panel. It used to sit on HandMenu,
## which was deleted -- nothing had ever summoned one -- and this constant was the only
## part of that file anything still used.
##
## Generous, because a tracked fingertip is not where the finger is to the millimetre and a
## screen you have to hit exactly is a screen that feels broken.
const FINGER: float = 0.045

## HOW BIG THE POINTER IS and how long it lingers after the last thing that moved it.
##
## A panel you touch with an untracked fingertip, or point at from across a room with a
## mouse, gives you nothing to aim WITH. A button lighting up under the cursor tells you
## something is there; it does not tell you where you are when you are between two of them,
## or when you are off the page entirely and wondering why nothing responds.
##
## The linger exists because nothing tells a panel that a hand has gone away. Rather than
## every caller having to remember to clear it -- and the one that forgets leaving a dot
## stuck on the glass for the rest of the session -- the dot fades out on its own unless
## something keeps pointing at it.
const DOT: float = 0.006
const DOT_LINGER: float = 0.25

## THE FRAME ROUND THE GLASS: how far it stands out past the glass on every side, and how thick it is, in metres.
## Named because whatever stands a panel somewhere has to know how much room the frame takes: the desk's three screens
## are sized and spaced from these (`DeskRoom.SCREEN_WIDTH`), and a frame typed thicker here moves them apart.
const BEZEL: float = 0.01
const BEZEL_DEPTH: float = 0.012

var _screen: SubViewport = null
var _glass: MeshInstance3D = null
var _frame: MeshInstance3D = null
var _shown: Control = null
var _dot: MeshInstance3D = null
var _dot_for: float = 0.0

## THE PANEL A KEYBOARD IS TYPING INTO, if any: the last one whose page had a text field in focus when a key arrived.
## Static because "is somebody typing?" is asked by things that know no panel -- the rig polls M for the clipboard -- and
## there is one keyboard.
static var _typing: TouchPanel = null


func _ready() -> void:
	_build()


## IS A KEYBOARD TYPING INTO A PANEL? The focus gate anything that polls keys asks first (CLAUDE.md, rule 9): a join code
## with an M in it must not raise the clipboard.
static func is_typing() -> bool:
	return _typing != null and is_instance_valid(_typing) and _typing.takes_keys()


## A TEXT FIELD ON THIS PAGE HAS FOCUS.
func takes_keys() -> bool:
	if _screen == null or not is_inside_tree():
		return false
	var focused: Control = _screen.gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit


## KEYS GO TO THE FIELD THAT HAS FOCUS. A SubViewport hung under a Node3D has no container to hand it the keyboard, so a
## LineEdit on a panel took focus from a click and then heard nothing typed (tests/code_pad.gd measured it). So the panel
## whose page has a focused text field takes each key first, in `_input`, and marks it handled -- which also keeps it
## from the rig's `_unhandled_input` bindings, V and R among them.
func _input(event: InputEvent) -> void:
	# A `@tool` script: in the editor this panel is furniture in a scene being edited, and the keyboard is the editor's.
	if Engine.is_editor_hint():
		return
	if not (event is InputEventKey) or not takes_keys():
		if _typing == self and not takes_keys():
			_typing = null
		return
	_screen.push_input(event, true)
	_typing = self
	get_viewport().set_input_as_handled()
	redraw()


## The Control on the panel, once it exists. Whoever put the page there talks to it through
## this rather than reaching into the viewport.
func shown() -> Control:
	return _shown


func _build() -> void:
	if _screen != null:
		return
	if bezel:
		_frame = MeshInstance3D.new()
		_frame.mesh = BoxMesh.new()
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.06, 0.07, 0.08)
		dark.roughness = 0.9
		_frame.material_override = dark
		add_child(_frame)

	_screen = SubViewport.new()
	_screen.transparent_bg = false
	# NO 3D IN IT, which is not an optimisation, it is the difference between a panel that
	# renders and one that takes the renderer down in a headset.
	#
	# A SubViewport with 3D left on allocates a 3D framebuffer, and in XR the main pass is
	# MULTIVIEW -- two layers, one per eye. The panel's target has one, the cache asks for a
	# framebuffer with two, and every frame turns into
	#
	#   framebuffer_create_multipass: Layers of our texture doesn't match view count
	#
	# A page is a Control tree. There has never been anything 3D on one.
	_screen.disable_3d = true
	# UPDATE_ALWAYS redraws at the display rate whatever is on it. A panel changes when its
	# content does, so it sleeps until something asks for a frame.
	_screen.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_screen.gui_embed_subwindows = false
	add_child(_screen)

	if page != null:
		_shown = page.instantiate() as Control
		if _shown != null:
			# PARENT FIRST, then anchor. A Control set to fill its parent refuses a size
			# while it has no parent to fill, and complains once per panel in the log.
			_screen.add_child(_shown)
			_shown.set_anchors_preset(Control.PRESET_FULL_RECT)

	_glass = MeshInstance3D.new()
	_glass.mesh = QuadMesh.new()
	var lit := StandardMaterial3D.new()
	lit.albedo_texture = _screen.get_texture()
	# UNSHADED, because a screen makes its own light and a panel in a dark cockpit should
	# still be readable.
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_glass.material_override = lit
	add_child(_glass)
	# THE POINTER, in front of the glass so it is never hidden by what it is pointing at.
	_dot = MeshInstance3D.new()
	_dot.name = "Pointer"
	var pip := SphereMesh.new()
	pip.radial_segments = 10
	pip.rings = 5
	pip.radius = DOT
	pip.height = DOT * 2.0
	_dot.mesh = pip
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(1.0, 0.86, 0.35)
	# NO DEPTH TEST. The dot sits a couple of millimetres off the glass and a panel held at
	# arm's length is looked at from every angle; at a glancing one the glass wins the depth
	# test and the pointer disappears exactly when it is hardest to aim.
	ink.no_depth_test = true
	ink.render_priority = 1
	_dot.material_override = ink
	_dot.visible = false
	add_child(_dot)
	set_process(true)
	_lay_out()
	redraw()


## THE POINTER FADES IF NOTHING IS POINTING. See DOT_LINGER.
func _process(delta: float) -> void:
	if _dot == null or not _dot.visible:
		return
	_dot_for -= delta
	if _dot_for <= 0.0:
		_dot.visible = false


func _lay_out() -> void:
	if _screen == null:
		return
	_screen.size = Vector2i(pixels, maxi(int(round(pixels * size.y / size.x)), 16))
	if _shown != null:
		_shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	(_glass.mesh as QuadMesh).size = size
	_glass.position = Vector3(0.0, 0.0, 0.007)
	if _frame != null:
		(_frame.mesh as BoxMesh).size = Vector3(size.x + 2.0 * BEZEL, size.y + 2.0 * BEZEL, BEZEL_DEPTH)


## Draw one frame. Called when whatever is on the panel has changed.
func redraw() -> void:
	if _screen != null:
		_screen.render_target_update_mode = SubViewport.UPDATE_ONCE


## WHERE A POINT ON THE GLASS LANDS ON THE PAGE, in pixels, or null if it misses.
##
## The pane's origin is its middle and a viewport's is its top left, and Y runs the other
## way up. Returning null rather than clamping is what lets a caller offer the same hand to
## several panels in turn: a miss is not this panel's business and says so.
func _pixel_at(at: Vector3) -> Variant:
	if _screen == null or absf(at.x) > size.x * 0.5 or absf(at.y) > size.y * 0.5:
		return null
	return Vector2(
		(at.x / size.x + 0.5) * float(_screen.size.x),
		(0.5 - at.y / size.y) * float(_screen.size.y))


## Send one synthetic event at `where` and redraw. Both of the two below are this with a
## different event on it, which is the whole of what separates a press from a hover.
##
## Typed as the mouse base class, which is where `position` lives.
func _push(event: InputEventMouse, where: Vector2) -> bool:
	event.position = where
	event.global_position = where
	_screen.push_input(event, true)
	redraw()
	return true


## PRESS THE GLASS. `at` is in this panel's own space, in metres. Anything within the pane
## becomes a click at the matching pixel; anything outside it is not this panel's business
## and says so, so a caller can offer the same hand to several panels.
func press(at: Vector3, down: bool) -> bool:
	var where: Variant = _pixel_at(at)
	if where == null:
		return false
	point_at(at)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	return _push(click, where)


## And where the pointer IS, without pressing. What makes a button light up under a finger
## before it is pushed, which is most of what tells somebody a panel is touchable at all.
func hover(at: Vector3) -> bool:
	var where: Variant = _pixel_at(at)
	if where == null:
		return false
	point_at(at)
	return _push(InputEventMouseMotion.new(), where)


## NOTHING IS POINTING HERE ANY MORE: whatever lit up under the pointer goes out.
##
## Needed because a panel is only ever told where a pointer IS. A beam that swings off the pane sends nothing -- the point
## is not on the glass, so `hover` refuses it -- and the button it left stayed lit until something else moved over the
## page. So the pointer says when it goes, and this sends one motion to a pixel with no Control under it.
##
## A MOTION, NOT `notify_mouse_exited`. Read in Godot 4.7's viewport.cpp: `push_input` runs `_update_mouse_over` for every
## mouse event on a SubViewport with no container, finds no Control at (-1, -1), and drops the hovered one. Measured with a
## probe on the desk's level page (2026-09-14): a pushed motion lights the door, a motion at (-1, -1) puts it out, and the
## next motion lights it again. `notify_mouse_exited` put it out too, but it clears a `mouse_in_viewport` that nothing here
## ever set, and Godot warns when it is told twice.
func leave() -> void:
	if _screen == null:
		return
	_push(InputEventMouseMotion.new(), Vector2(-1.0, -1.0))


## HOW FAR ALONG A RAY THE GLASS IS, in metres, or -1 when the ray misses the pane.
##
## A ray from a hand or an eye, met with the plane of the glass, and kept only if the point lands on the pane --
## the sum a pointer needs before it can hover or press anything, written once. It came out of `Clipboard.aim` on
## 2026-09-13, when the desk's screens wanted the same right-hand beam the board has.
func reach(from: Vector3, along: Vector3) -> float:
	var normal: Vector3 = global_basis.z
	var facing: float = normal.dot(along)
	if absf(facing) < 0.0001:
		return -1.0
	var distance: float = normal.dot(global_position - from) / facing
	if distance <= 0.0 or _pixel_at(to_local(from + along * distance)) == null:
		return -1.0
	return distance


## A POINTER ON THE GLASS: hover what the ray is on, show the dot, and press there if `pressing` -- which the CALLER
## decides, because only the thing holding the trigger knows whether this is the moment it went down or a pull that was
## already held when the ray arrived. Returns `reach`, so whoever draws the beam knows how long to draw it.
func aim(from: Vector3, along: Vector3, pressing: bool) -> float:
	var distance: float = reach(from, along)
	if distance < 0.0:
		return -1.0
	var at: Vector3 = to_local(from + along * distance)
	hover(at)
	if pressing:
		press(at, true)
		press(at, false)
	return distance


## SHOW WHERE THE FINGER OR THE POINTER IS, on the glass, whether or not it is pressing.
##
## Separate from `hover` because a caller may know where somebody is aiming before it is
## close enough to count as a hover -- which is the whole of the problem this solves: a hand
## approaching a panel has to be able to see where it is going to land BEFORE it lands.
##
## Clamped to the pane rather than refused. A pointer that vanishes the moment it leaves the
## page is one you cannot use to find the page again.
func point_at(at: Vector3) -> void:
	if _dot == null:
		return
	_dot.position = Vector3(
		clampf(at.x, -size.x * 0.5, size.x * 0.5),
		clampf(at.y, -size.y * 0.5, size.y * 0.5),
		0.010)
	_dot.visible = true
	_dot_for = DOT_LINGER
