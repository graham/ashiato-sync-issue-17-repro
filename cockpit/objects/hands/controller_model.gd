extends Node3D
class_name ControllerModel
## A CONTROLLER YOU CAN SEE, IN PLACE OF A BALL: its body, grip, trigger, thumbstick and two thumb buttons, and
## beside each one what it does in the hand you have now.
##
## Asked for on 2026-09-13: holding the stick, nobody could see which finger launched and which locked. The labels are
## the LIVE binding table -- whatever `PilotRig._bindings_for` says for this hand, read through `Bind.says` -- handed
## over by the rig. This DRAWS a table and never decides one, and it reaches for nothing: the rig reaches for it (see
## `Doors` for why that direction matters), so a binding changed anywhere shows here without anybody editing this file.
##
## AND IT SHOWS WHAT YOUR FINGERS ARE DOING, asked for the same day: "pressing a button on the controller should have a
## visible change in the state of the controller". The trigger swings back, the grip button goes in, the thumb buttons
## go down, the stick leans the way it is pushed and sinks when clicked, and each turns amber while it is worked. The
## rig hands `show_input` what it read for this hand -- the same reads the bindings act on -- and this draws them. It
## does not read a controller, and it does not decide what "closed" means: the grip's threshold is the rig's to hand in.
##
## ONLY WHAT CHANGED IS WRITTEN. The rig calls `show_input` every frame and a hand at rest is most frames; a transform
## or a material written regardless is a RenderingServer call per part per frame, and the project measured ~0.5 ms of
## those elsewhere. `writes` counts every write so a suite can prove an idle controller costs nothing.
##
## BUILT FROM PRIMITIVES, no imported asset: a model that cannot go missing from a fresh clone, and one plain
## StandardMaterial3D apiece, so there is no shader and nothing to have a FINE twin of. Mirrored for the left hand,
## where the thumbstick sits on the other side of the buttons.
##
## LABELS ONLY WHEN THERE IS SOMETHING TO SAY: the rig shows them while the hand holds a control or the board is up,
## and a finger whose table entry is empty has no label. An empty hand in flight is two plain controllers, which is
## the least clutter a view can have.

## Which hand, 0 left and 1 right. Set before it enters the tree.
var hand: int = 1
## HOW HARD A GRIP MUST CLOSE TO SHOW CLOSED, handed in by the rig before it enters the tree: `VehicleControl.GRAB_ON`,
## the squeeze that takes hold of a control. Not typed here, so the colour and the grab cannot disagree.
var grip_closes_at: float = 1.0

## THE WRITING. Big enough at arm's length -- a 7 mm cap height at 45 cm is about 0.9 degrees, the size the clipboard's
## body text is -- and outlined so it reads against a bright sky and a dark cockpit floor alike.
const FONT_SIZE: int = 30
const PIXEL: float = 0.00024
const OUTLINE: int = 8
## How wide a label may run before it wraps, in the label's own pixels: 96 mm, so the longest binding in the game --
## "lock the target ahead" -- stays on one line; the first screenshots wrapped it into the trigger's label below.
const WRAP: float = 400.0
const INK := Color(0.96, 0.97, 1.0)
const DIM_INK := Color(0.80, 0.84, 0.88)
const BODY := Color(0.20, 0.21, 0.23)
const TRIM := Color(0.34, 0.35, 0.38)

## ---- how a worked part shows it ------------------------------------------------------------

## A PART NOBODY IS PRESSING, in the clipboard's own grey, so a controller and the board in the other hand are one set.
const REST := BoardStyle.DIM
## A PART BEING WORKED, in the clipboard's amber: the colour that already means "this one" on the board.
const WORKED := BoardStyle.AMBER
## HOW BRIGHTLY A WORKED PART GLOWS. Lit by albedo alone, amber in the cockpit's shadow is brown and against a bright
## sky is a silhouette; glowing, it reads in both. Emission is on from the start and black at rest, so pressing a button
## changes a colour and never compiles a shader.
const GLOW: float = 1.2
## How far the trigger swings back at a full pull, in degrees about its hinge: its lower edge, 20 mm below the hinge, moves 7 mm towards the grip.
const TRIGGER_PULL_DEGREES: float = 24.0
## Where the trigger rests, in degrees about X: tipped back under the head, as it was drawn before it moved.
const TRIGGER_REST_DEGREES: float = -20.0
## How far the grip button goes into the handle at a full squeeze, in metres, out of the 10 mm it stands proud of the
## handle: a movement the eye catches beside the head, while its colour is what says it is closed.
const GRIP_TRAVEL: float = 0.003
## How far a thumb button goes down while pressed, in metres: a real one's travel.
const THUMB_TRAVEL: float = 0.0025
## How far the thumbstick leans at full deflection, in degrees. A real one's throw is about this.
const STICK_TILT_DEGREES: float = 22.0
## How far the thumbstick sinks when clicked, in metres.
const STICK_CLICK_TRAVEL: float = 0.003
## THE LEAST CHANGE IN AN ANALOGUE READING THAT IS DRAWN, as a fraction of its travel: half a degree of trigger and a
## sixteenth of a millimetre of grip, below anything an eye can see, and above the jitter of a finger resting on it.
## A reading arriving at either end is drawn whatever the step, so a released trigger always lands exactly at rest.
const EASE: float = 0.02

## input -> Label3D, for every input in `Bind.inputs()`.
var _labels: Dictionary = {}
## input -> what its label says now, so a table that has not changed costs a string compare and nothing else.
var _said: Dictionary = {}
var _shown: bool = false

## THE PARTS THAT MOVE, and where each rests. The trigger and the stick turn about a hinge node of their own.
var _trigger: Node3D = null
var _trigger_hinge: Vector3 = Vector3.ZERO
var _grip_button: MeshInstance3D = null
var _grip_rest: Vector3 = Vector3.ZERO
var _thumb_high: MeshInstance3D = null
var _thumb_high_rest: Vector3 = Vector3.ZERO
var _thumb_low: MeshInstance3D = null
var _thumb_low_rest: Vector3 = Vector3.ZERO
var _stick: Node3D = null
var _stick_rest: Vector3 = Vector3.ZERO
var _stick_cap: MeshInstance3D = null
## WHAT IS DRAWN NOW, so the next reading can be compared with it.
var _trigger_shown: float = 0.0
var _grip_shown: float = 0.0
var _grip_closed: bool = false
var _high_down: bool = false
var _low_down: bool = false
var _stick_shown: Vector2 = Vector2.ZERO
var _click_down: bool = false
var _stick_lit: bool = false
## Every transform and material write since the model was made. See `writes`.
var _writes: int = 0


func _ready() -> void:
	_build_the_body()
	for input in Bind.inputs():
		var label := Label3D.new()
		label.name = "Says%d" % input
		label.font_size = FONT_SIZE
		label.pixel_size = PIXEL
		label.outline_size = OUTLINE
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
		label.modulate = INK if input != Bind.STICK_CLICK else DIM_INK
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.width = WRAP
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _label_side(input) > 0.0 else HORIZONTAL_ALIGNMENT_RIGHT
		# DRAWN OVER THE CONTROLLER, not hidden behind it: a label is only any use if it can always be read.
		label.no_depth_test = true
		label.render_priority = 2
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.double_sided = true
		label.position = _label_at(input)
		# TILTED UP AT THE EYE: a controller is held with its top face towards the face, so the writing lies along
		# that face rather than standing up off it.
		label.rotation = Vector3(deg_to_rad(-60.0), 0.0, 0.0)
		label.visible = false
		add_child(label)
		_labels[input] = label
		_said[input] = ""


## WHAT EVERY FINGER OF THIS HAND DOES, and whether to say so. `table` is what `PilotRig._bindings_for` returns for
## this hand; `labelled` is the rig's answer to "is there anything worth writing" -- a control held, or the board up.
func show_bindings(table: Dictionary, labelled: bool, names: Dictionary) -> void:
	_shown = labelled
	for input in _labels:
		var says: String = Bind.says(table.get(input), names) if labelled else ""
		var label := _labels[input] as Label3D
		if says != _said[input]:
			_said[input] = says
			label.text = _with_finger(input, says)
		label.visible = labelled and says != ""


## WHAT THIS HAND'S FINGERS ARE DOING, drawn. The rig's own readings: the trigger 0..1, the grip 0..1 with the latch in
## it, the two thumb buttons, the stick -1..1 with the rig's dead zone already taken out, and its click. Plain
## arguments rather than a dictionary, because this is called every frame and a dictionary is an allocation.
func show_input(trigger: float, grip: float, thumb_high: bool, thumb_low: bool, stick: Vector2, click: bool) -> void:
	if _trigger == null:
		return
	trigger = clampf(trigger, 0.0, 1.0)
	if _moved(trigger, _trigger_shown):
		_trigger_shown = trigger
		_trigger.transform = Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(TRIGGER_REST_DEGREES - TRIGGER_PULL_DEGREES * trigger)), _trigger_hinge)
		_writes += 1
		_tint(_trigger.get_child(0) as MeshInstance3D, trigger)

	# INWARD is towards the middle of the handle, and the button is on the handle's inside face.
	grip = clampf(grip, 0.0, 1.0)
	if _moved(grip, _grip_shown):
		_grip_shown = grip
		_grip_button.position = _grip_rest + Vector3(_outside() * GRIP_TRAVEL * grip, 0.0, 0.0)
		_writes += 1
	var closed: bool = grip >= grip_closes_at
	if closed != _grip_closed:
		_grip_closed = closed
		_tint(_grip_button, 1.0 if closed else 0.0)

	if thumb_high != _high_down:
		_high_down = thumb_high
		_press(_thumb_high, _thumb_high_rest, thumb_high)
	if thumb_low != _low_down:
		_low_down = thumb_low
		_press(_thumb_low, _thumb_low_rest, thumb_low)

	stick = stick.limit_length(1.0)
	var leant: bool = stick.distance_to(_stick_shown) > EASE \
		or (stick != _stick_shown and (stick == Vector2.ZERO or stick.length_squared() >= 1.0))
	if leant or click != _click_down:
		_stick_shown = stick
		_click_down = click
		_stick.transform = Transform3D(_lean(stick), _stick_rest + Vector3.DOWN * (STICK_CLICK_TRAVEL if click else 0.0))
		_writes += 1
	var lit: bool = click or stick != Vector2.ZERO
	if lit != _stick_lit:
		_stick_lit = lit
		_tint(_stick_cap, 1.0 if lit else 0.0)


## How many transforms and materials `show_input` has written since the model was made. For the suite that proves a
## controller nobody is touching writes nothing.
func writes() -> int:
	return _writes


## What the label beside `input` says, or "" when it shows nothing. For the tests, which compare it with the table.
func says(input: int) -> String:
	var label := _labels.get(input) as Label3D
	return String(_said.get(input, "")) if label != null and label.visible else ""


## Whether any label is up.
func is_labelled() -> bool:
	return _shown


## WHETHER AN ANALOGUE READING HAS MOVED FAR ENOUGH TO DRAW. See EASE.
static func _moved(now: float, was: float) -> bool:
	return absf(now - was) > EASE or (now != was and (now <= 0.0 or now >= 1.0))


## THE STICK LEANT TOWARDS WHERE IT IS PUSHED: +x to the controller's right and +y forward, on either hand. The parts are
## mirrored for the left hand; the stick's axes are not, because a thumbstick pushed right reports +x on both.
static func _lean(stick: Vector2) -> Basis:
	if stick == Vector2.ZERO:
		return Basis.IDENTITY
	# UP crossed with the way it leans, (x, 0, -y), is the axis that tips UP towards it.
	var axis := Vector3(-stick.y, 0.0, -stick.x).normalized()
	return Basis(axis, deg_to_rad(STICK_TILT_DEGREES) * stick.length())


func _press(button: MeshInstance3D, rest: Vector3, down: bool) -> void:
	button.position = rest + Vector3.DOWN * (THUMB_TRAVEL if down else 0.0)
	_writes += 1
	_tint(button, 1.0 if down else 0.0)


## A MOVING PART FROM REST TOWARDS WORKED, by `how_far` 0..1: colour and glow together, as one write.
func _tint(part: MeshInstance3D, how_far: float) -> void:
	var skin := part.material_override as StandardMaterial3D
	skin.albedo_color = REST.lerp(WORKED, how_far)
	skin.emission = Color.BLACK.lerp(WORKED, how_far)
	_writes += 1


func _outside() -> float:
	return 1.0 if hand == 1 else -1.0


## THE FINGER, FIRST AND SHORT, where it is not obvious from where the label sits: the stick's click shares its
## corner with the stick, so it says which one it is. The rest are beside the thing they name.
static func _with_finger(input: int, says: String) -> String:
	if says == "":
		return ""
	return "click: %s" % says if input == Bind.STICK_CLICK else says


## +1 for writing that runs away to this hand's outside, -1 for its inside. The buttons are on the outside of a
## controller and the stick on the inside, so each label goes on its own side and never across the other's.
func _label_side(input: int) -> float:
	var outside: float = _outside()
	match input:
		Bind.STICK, Bind.STICK_CLICK:
			return -outside
	return outside


## WHERE EACH LABEL SITS, in the controller's own frame: -Z is where it points, +Y the top face. Seen from the eye,
## forward reads as UP, so the labels are spread along Z: the trigger furthest forward, then the upper thumb, then the
## lower one; on the inside the stick above its click. The first screenshots (2026-09-13) had the trigger's label
## squeezed between the two thumbs', because it sat below them rather than in front.
func _label_at(input: int) -> Vector3:
	var side: float = _label_side(input)
	match input:
		Bind.TRIGGER:
			return Vector3(side * 0.034, 0.000, -0.080)
		Bind.THUMB_LOW:
			return Vector3(side * 0.034, 0.030, 0.022)
		Bind.THUMB_HIGH:
			return Vector3(side * 0.034, 0.034, -0.022)
		Bind.STICK:
			return Vector3(side * 0.034, 0.034, -0.012)
		Bind.STICK_CLICK:
			return Vector3(side * 0.034, 0.028, 0.024)
	return Vector3.ZERO


## THE CONTROLLER ITSELF. The sizes are a Touch controller's to the nearest few millimetres, which is enough for a
## hand to look like it is holding the thing it is holding.
func _build_the_body() -> void:
	var outside: float = _outside()
	# THE HEAD: the flat top the thumb works, tipped forward a little like the real thing.
	var head := _part("Head", _box(Vector3(0.046, 0.020, 0.062)), BODY, Vector3(0.0, 0.004, -0.006))
	head.rotation = Vector3(deg_to_rad(-8.0), 0.0, 0.0)
	# THE GRIP, down and back from the head, where the hand closes.
	var grip := _part("Grip", _cylinder(0.016, 0.014, 0.092), BODY, Vector3(0.0, -0.040, 0.026))
	grip.rotation = Vector3(deg_to_rad(28.0), 0.0, 0.0)
	# THE RING, the tracking hoop round the knuckles, as a thin bar across the top of the head.
	_part("Ring", _box(Vector3(0.050, 0.008, 0.010)), TRIM, Vector3(0.0, 0.020, -0.040))
	# THE TRIGGER, under the front where the index finger is, hung from a hinge at the top of its blade so a pull swings
	# the blade back towards the grip rather than turning it about its middle. IT STANDS A CENTIMETRE PROUD OF THE HEAD'S
	# FRONT FACE: the first screenshots (2026-09-13) had it wholly under the head, so from the eye, with the controller
	# held top-face-up, a full pull changed nothing anybody could see.
	var blade_half: float = 0.010
	_trigger = Node3D.new()
	_trigger.name = "TriggerHinge"
	_trigger_hinge = Vector3(0.0, -0.012, -0.044) + Basis(Vector3.RIGHT, deg_to_rad(TRIGGER_REST_DEGREES)) \
		* Vector3(0.0, blade_half, 0.0)
	_trigger.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(TRIGGER_REST_DEGREES)), _trigger_hinge)
	add_child(_trigger)
	_part("Trigger", _box(Vector3(0.018, 2.0 * blade_half, 0.012)), REST, Vector3(0.0, -blade_half, 0.0), _trigger)
	# THE GRIP BUTTON, on the inside of the handle, where the middle finger is. Not labelled: it is what takes hold, on
	# every control, and no binding table speaks for it. ITS FACE IS PAST THE EDGE OF THE HEAD, for the trigger's reason:
	# the first one sat inside the head's outline and could not be seen from above.
	_grip_rest = Vector3(-outside * 0.020, -0.030, 0.010)
	_grip_button = _part("GripButton", _box(Vector3(0.010, 0.034, 0.020)), REST, _grip_rest)
	# THE THUMBSTICK on the inside of the head, stem and cap on one pivot at the stem's foot so the pair leans together;
	# and the two thumb buttons on the outside, lower and upper.
	_stick_rest = Vector3(-outside * 0.010, 0.013, -0.004)
	_stick = Node3D.new()
	_stick.name = "Stick"
	_stick.position = _stick_rest
	add_child(_stick)
	_part("StickStem", _cylinder(0.003, 0.003, 0.010), TRIM, Vector3(0.0, 0.005, 0.0), _stick)
	_stick_cap = _part("StickCap", _cylinder(0.008, 0.008, 0.004), REST, Vector3(0.0, 0.011, 0.0), _stick)
	_thumb_low_rest = Vector3(outside * 0.011, 0.017, 0.010)
	_thumb_low = _part("ThumbLow", _cylinder(0.005, 0.005, 0.004), REST, _thumb_low_rest)
	_thumb_high_rest = Vector3(outside * 0.013, 0.019, -0.010)
	_thumb_high = _part("ThumbHigh", _cylinder(0.005, 0.005, 0.004), REST, _thumb_high_rest)


## A PART, under `parent` or the controller itself. A part drawn in REST's colour is one that moves, so its glow is
## switched on here, once, black.
func _part(part_name: String, mesh: Mesh, colour: Color, at: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = colour
	skin.roughness = 0.6
	if colour == REST:
		skin.emission_enabled = true
		skin.emission = Color.BLACK
		skin.emission_energy_multiplier = GLOW
	var piece := MeshInstance3D.new()
	piece.name = part_name
	piece.mesh = mesh
	piece.material_override = skin
	piece.position = at
	(parent if parent != null else self).add_child(piece)
	return piece


static func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var tube := CylinderMesh.new()
	tube.top_radius = top
	tube.bottom_radius = bottom
	tube.height = height
	tube.radial_segments = 12
	tube.rings = 1
	return tube
