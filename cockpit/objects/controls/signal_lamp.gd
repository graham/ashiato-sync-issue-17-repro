@tool
extends VehicleControl
class_name SignalLamp
## A SIGNAL LAMP: a hand-held lamp with a pistol grip, a lens and a ring sight, for talking to another
## aircraft in flashes of white, red and green.
##
## Asked for on 2026-09-18: *"I have a new device i want you to make, like the camera, while holding it, it
## should move, and after releasing it it just stays whereever you left it (in relation to the player, so
## they can't lose it). The goal is to create a light gun, that the player can press buttons on to make
## lights flash, but other players in other planes need to be able to see this light gun. The idea being two
## players could use light signals to talk to each other. it should have white, red, and green lights
## (trigger white), a = red, b = green (or x/y if the other controller). only one light at a time."*
##
## It is an Aldis lamp, or the light gun a control tower aims at an aircraft with no radio: a beam you point
## at the person you are talking to.
##
## ---------------------------------------------------------------------------------
## CARRIED LIKE THE DIRECTOR'S CAMERA, AND IT CANNOT BE LOST FOR THE SAME REASON
## ---------------------------------------------------------------------------------
##
## `carried_by_hand()` is true, so `PilotRig._work_the_controls` hands the fist to `offer_hand_to_place` in
## flight, exactly as it does for `DirectorCamera`. The hand's pose arrives in the STATION's frame and the
## lamp is placed in it, so a lamp let go of is a lamp left where it was in the cockpit -- bolted to the seat
## the station hangs off, flying with the aircraft. There is no world transform anywhere in this file, which
## is the whole of "in relation to the player, so they can't lose it".
##
## ONE DIFFERENCE FROM THE CAMERA, AND IT IS THE POINT OF THE THING: THE GRIP SNAPS INTO THE PALM. The camera
## keeps whatever offset it had from the hand when the fist closed, because framing a shot is the hand
## carrying a camera about. A pistol grip is held one way, with the barrel along the pointing finger, and a
## lamp held at a random angle to the hand is a beam aimed somewhere the player is not looking. So while
## held, the lamp's frame is the hand's frame (`IN_THE_PALM`): its -Z is the controller's -Z, which is the
## way the rig's pointing beam goes too. And that is what makes the beam cheap to replicate: the hands are
## already on the wire, so where a held lamp points is where that hand points.
##
## ---------------------------------------------------------------------------------
## WHICH FINGER IS WHICH COLOUR, AND ONE AT A TIME
## ---------------------------------------------------------------------------------
##
## The trigger is WHITE, the lower thumb button RED and the upper GREEN -- A and B on the right controller, X
## and Y on the left, because `Bind` names the thumb position rather than the letter, so one table serves
## either hand. The holding hand only: `bindings()` takes those three inputs away from whatever they did with
## an empty hand (the brake, the seat buttons) and `hand_input` is how the lamp sees them.
##
## MOMENTARY. The lamp is lit only while a button is held down, which is what flashing Morse is. A latched
## lamp would be a lamp left on by somebody who has forgotten it, pointing at a wingman.
##
## THE NEWEST PRESS WINS, and letting it go falls back to whichever is still held. So a signaller can go from
## white to red without a dark gap by pressing red before letting white go, and two buttons can never light
## two colours: there is one lens and one colour in it. REJECTED: ignoring a second press while one is held.
## It is simpler and it makes "red now" depend on what the other finger happens to be doing.
##
## LETTING GO OF THE LAMP PUTS IT OUT. A lamp in nobody's hand is a lamp nobody is aiming.
##
## ---------------------------------------------------------------------------------
## WHERE A FRESH ONE IS
## ---------------------------------------------------------------------------------
##
## NOWHERE, UNTIL A PLAYER PUTS ONE THERE (lane/lampopt, 2026-09-19). The user: *"let's have the light gun (like the
## director camera) is optional, not always present and can be loaded via the ipad."* So it is a part in
## `ControlCatalogue.PARTS`, "+ SIGNAL LAMP" on the BUILD tab, placed, saved by `CockpitLayout` and binned like every
## other part. Lane/lightgun had made it kit instead: holstered at every seat by `VehicleView.man`, in all 33 craft.
##
## ONE TO A SEAT, because a seat has one lamp channel and two lamps on it would be two lenses that show one colour.
## `PilotRig.add_control` refuses a second one on the board.
##
## IT ARRIVES IN ITS HOLSTER, NOT IN FRONT OF THE SEAT where other parts land: at the spot `holster_spot` finds,
## clear of every grip in the craft and of every face the pilot reads. The builder may then move it, and wherever
## the builder leaves it becomes its holster (`holster_here`), which is where the desk's recall key puts it back.
##
## OTHER MACHINES LEARN IT IS THERE FROM THE WIRE, and not from the layout. A layout made in flight is written to
## this machine's `user://` and goes nowhere else (only the builder room relays one). So the lamp's own channel
## carries a FITTED bit, and the rig keeps it true for its own seat (`PilotRig._say_whether_i_have_a_lamp`). Every
## machine then holsters a lamp at any other seat whose bit is set, and takes one away when it is clear
## (`VehicleView._match_lamps_to_the_wire`). A far lamp stands at the searched holster spot. That is where lane/lightgun
## already put a joiner's view of a resting lamp, because nothing sends a resting pose. REJECTED: relaying the layout
## the way the builder room does. That is a 64 KiB long message and a host validator to show the far players one lamp,
## where one bit on a channel that is already there does it.
##
## THE HOLSTER IS FOUND, NOT TYPED (`holster_spot`): out to the side of the free hand, at hip height, where
## a seated arm gets to it easily and its grip is clear of every other grip in the craft by `tests/fit.gd`'s
## rule -- two hands' reach -- so a hand reaching for the lamp never takes the throttle instead.
##
## IT IS YOURS ALONE TO PICK UP. `own_seat_only()`: the rig reaches every other control in the craft, which is
## what two pilots on one flight deck do, but a lamp speaks for the seat it belongs to, and a lamp flashed by
## the copilot from the pilot's holster would say the pilot was signalling.

## THE LAMP'S BODY, in metres, in its own frame: -Z is the beam, +Y is up and the origin is the palm, which
## is where the rig's hand pose is. An Aldis lamp is about 20 cm long with a 9 cm lens; this is that, hand
## sized, so it sits in a fist without covering the cockpit.
const BARREL_RADIUS: float = 0.042
const BARREL_UP: float = 0.085
const BARREL_BACK: float = 0.060
const BARREL_FRONT: float = -0.120
## The hood round the lens, a little proud of the barrel, and the lens recessed in it.
const HOOD_RADIUS: float = 0.047
const HOOD_FRONT: float = -0.150
const LENS_RADIUS: float = 0.037
## THE GRIP: what the fist closes round. Straight down under the barrel's back half, so the beam lies along
## the finger. Its middle is `GRIP_AT`, which is where the rig measures a hand against.
const GRIP := Vector3(0.030, 0.100, 0.036)
const GRIP_AT := Vector3(0.0, 0.0, 0.0)
## THE RING SIGHT on top, and the bead at the front: look through the ring at the bead at the aircraft.
const SIGHT_RADIUS: float = 0.014
const SIGHT_AT := Vector3(0.0, BARREL_UP + BARREL_RADIUS + 0.022, -0.010)
const BEAD_AT := Vector3(0.0, BARREL_UP + BARREL_RADIUS + 0.008, -0.105)
## HOW MANY SIDES A ROUND PART HAS. Eight on the barrel and the hood, which is the house's faceted look
## (`modelling_here.md` section 4) and reads as a lamp at arm's length; the lens has the hood's eight so it
## sits flush in it.
const SIDES: int = 8

## THE HAND'S FRAME IS THE LAMP'S FRAME, moved so the grip is in the palm. See the note at the top.
const IN_THE_PALM := Transform3D(Basis.IDENTITY, -GRIP_AT)

## WHAT THE LAMP SHOWS. DARK is off; the rest are the three colours a light gun has.
enum { DARK, WHITE, RED, GREEN }

## WHICH FINGER LIGHTS WHICH COLOUR. The binding names the thumb POSITION, so this is right for both hands.
const FINGERS: Dictionary = {Bind.TRIGGER: WHITE, Bind.THUMB_LOW: RED, Bind.THUMB_HIGH: GREEN}

## WHO HAS IT, as the wire says it: nobody, a left hand, a right hand, or a desk's keys.
enum { NOBODY, LEFT, RIGHT, DESK }

## ITS COLOUR CHANGED. `colour` is one of the enum above. What the rig and a test listen to.
signal signalled(lamp: SignalLamp, colour: int)

## ---------------------------------------------------------------------------------
## ON THE WIRE: ONE GENERIC BUS CHANNEL PER SEAT, AND THE HANDS THAT ARE ALREADY THERE
## ---------------------------------------------------------------------------------
##
## THE COLOUR, WHO HOLDS IT AND WHETHER THERE IS ONE are five bits on the craft's command bus: `lit` in the low two,
## `holder` in the next two, and `FITTED` above them (`RANGE` is 31; it was 15 until the lamp became a part). One
## GENERIC channel per seat (busbits, `Sim.fit_channels`), audience "craft", so the server keeps it on the craft's own page and sends that page to everybody -- the other aircraft included, however
## far off: the priority sphere is a rate, never a filter. It goes the way every switch in the cockpit goes: the lamp
## is a CRAFT-scope control, a change emits `moved`, `PilotRig._send_what_moved` routes it through
## `DeviceSignalRouter` onto the input frame, and the server decides. REJECTED: a bit on the input frame's `buttons`,
## which is full (eight of eight since lock and launch), so that was a C++ change; and a new replicated component,
## which was C++ too and would have been sent every tick rather than on a change.
##
## WHERE IT POINTS COSTS NOTHING ON THE WIRE. Held, the lamp is the hand (`IN_THE_PALM`), and both hands are on
## every pilot's replicated state already, seat-local and interpolated. So a far machine puts the lamp in the far
## pilot's hand -- `follow` -- and reads the colour off the bus. Lit from a desk, it is the head's pose instead
## (`desk_pose`), which is on the same state. Let go of, it stays where the hand last had it, on every machine,
## because the holder going to NOBODY is itself a change on the bus: the far lamp stops following and stays put.
## A machine that joins after the lamp was put down sees it in its holster: nothing sends a resting pose.
const RANGE: int = 31
## THERE IS A LAMP AT THIS SEAT. Set on every value a fitted lamp sends, clear on the 0 its seat sends once it is binned.
const FITTED: int = 16
## HOW MANY SEATS A KIND HAS LAMPS FOR, AT MOST: the block of channels below the top of the wire.
const MOST_SEATS: int = 256

## WHAT IT IS SHOWING NOW. Read from `_asking` rather than kept beside it; see `_redraw`.
var lit: int = DARK
## WHO HAS IT. Here, `held_by` and the desk's keys say; for somebody else's lamp, the bus does.
var holder: int = NOBODY

## THE COLOURS BEING ASKED FOR, oldest first. The last one is lit. See "the newest press wins" above.
var _asking: Array[int] = []
## Where it was holstered, which is where the desk's recall key puts it back.
var _holster := Transform3D.IDENTITY
var _lens: MeshInstance3D = null
## One pip per colour on the back of the barrel, facing the holder: WHITE, RED, GREEN.
var _pips: Array[MeshInstance3D] = []
## THE LENS'S FRONT, as a node: where the beam leaves from, and what the far glare stands on.
var _muzzle: Marker3D = null
var _glare: MeshInstance3D = null

const GLARE: Shader = preload("res://world/shaders/signal_lamp_glare.gdshader")


## ---- the channel ------------------------------------------------------------------------------

## THIS SEAT'S LAMP CHANNEL: a block of `MOST_SEATS` channels at the top of the wire, below the very last one. From
## the top so that generic channels fitted from the bottom -- a device package's panel -- never meet them. -1 with no
## library, which is a lamp nothing is told about.
static func channel_for(seat_index: int) -> int:
	var channels: int = int(Sim.bus_limits().get("channels", 0))
	if channels <= 0 or seat_index < 0 or seat_index >= MOST_SEATS:
		return -1
	return channels - 1 - MOST_SEATS + seat_index


## WHETHER A CHANNEL IS A LAMP'S.
static func is_lamp_channel(which: int) -> bool:
	var first: int = channel_for(0)
	return first >= 0 and which >= first and which < first + MOST_SEATS


## THE LAMP CHANNELS A KIND IS FITTED WITH: one per seat it has.
static func channels_of(kind: int) -> Array:
	var out: Array = []
	var seats: int = (Sim.geometry_of(kind).get("seat_poses", []) as Array).size()
	for seat_index in range(mini(seats, MOST_SEATS)):
		var which: int = channel_for(seat_index)
		if which >= 0:
			out.append({"channel": which, "name": "signal lamp %d" % seat_index, "range": RANGE,
				"audience": "craft"})
	return out


## FIT EVERY KIND WITH ITS LAMPS, keeping whatever other generic channels it has. `Sim.start` calls this before any
## world is made, on every machine, so every peer agrees what the channels are; the library refuses it while a world
## runs, and says so. Returns how many lamp channels were fitted.
static func fit_every_kind() -> int:
	var fitted: int = 0
	for kind in range(Sim.Kind.size()):
		fitted += fit_kind(kind)
	return fitted


static func fit_kind(kind: int) -> int:
	var keep: Array = []
	for row_any in Sim.schema_of(kind).get("channels", []) as Array:
		var row := row_any as Dictionary
		if bool(row.get("generic", false)) and not is_lamp_channel(int(row.get("channel", -1))):
			keep.append({"channel": int(row["channel"]), "name": String(row.get("name", "")),
				"range": int(row.get("range", 1)), "audience": String(row.get("audience", "crew"))})
	var lamps: Array = channels_of(kind)
	if lamps.is_empty():
		return 0
	var answer: Dictionary = Sim.fit_channels(kind, keep + lamps)
	return maxi(int(answer.get("fitted", 0)) - keep.size(), 0)


func label_text() -> String:
	return "SIGNAL\nLAMP"


## THE COLOUR OF ONE OF THE LAMP'S LIGHTS. The aircraft's own navigation lights' colours
## (`VehicleLights`), because a signal lamp's red is the same red a pilot already reads as red at night.
static func colour_of(which: int) -> Color:
	match which:
		WHITE:
			return VehicleLights.WHITE
		RED:
			return VehicleLights.RED
		GREEN:
			return VehicleLights.GREEN
	return Color(0.05, 0.05, 0.06)


static func colour_name(which: int) -> String:
	return ["dark", "white", "red", "green"][which] if which >= DARK and which <= GREEN else "?"


func _build() -> void:
	control_name = "signal lamp"
	# THE CRAFT'S, SO EVERYBODY SEES IT: a proposal on the bus, on this seat's own channel. See "on the wire".
	scope = Scope.CRAFT
	channel = channel_for(seat)
	channel_range = RANGE
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _body_mesh()
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	# VERTEX COLOUR IS LINEAR UNLESS SAID OTHERWISE, and every colour below is written as sRGB.
	# `modelling_here.md`: the carrier's 0.19 deck drew at 0.47.
	paint.vertex_color_is_srgb = true
	paint.roughness = 0.6
	body.material_override = paint
	add_child(body)

	_lens = MeshInstance3D.new()
	_lens.name = "Lens"
	_lens.mesh = _lens_mesh()
	var glass := StandardMaterial3D.new()
	glass.albedo_color = colour_of(DARK)
	glass.roughness = 0.2
	_lens.material_override = glass
	add_child(_lens)

	for which in [WHITE, RED, GREEN]:
		var pip := BoxMesh.new()
		pip.size = Vector3(0.010, 0.010, 0.004)
		var across: float = (float(which) - float(RED)) * 0.018
		_pips.append(_make_mesh(pip, colour_of(which).darkened(0.7),
			Vector3(across, BARREL_UP, BARREL_BACK + 0.002)))

	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0.0, BARREL_UP, HOOD_FRONT)
	add_child(_muzzle)

	# THE GLARE: what somebody in another aircraft sees. A quad the shader turns to face the eye and sizes and
	# brightens by how straight down the beam that eye is. See `signal_lamp_glare.gdshader`.
	_glare = MeshInstance3D.new()
	_glare.name = "Glare"
	# A TWO-CENTIMETRE QUAD, which the shader grows to metres at range. It was 2 m, the shader reading its corners as
	# -1..1 -- and anything that measures a part by its meshes' boxes, hidden ones included, then found a holstered lamp
	# two metres wide: `tests/water.gd` had it standing between the water bomber's pilot and his tank gauge ("hidden by
	# SignalLamp" x5, 2026-09-18). The shader is handed the half-size and reads the corners against it.
	var quad := QuadMesh.new()
	quad.size = Vector2(GLARE_QUAD, GLARE_QUAD)
	_glare.mesh = quad
	_glare.material_override = _glare_paint()
	_glare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# NEVER CULLED BY ITS OWN BOUNDS: the shader draws it metres wide at range, far outside a 2 cm quad.
	_glare.extra_cull_margin = 16384.0
	_glare.visible = false
	_muzzle.add_child(_glare)


## THE BODY IN ONE MESH: grip, trigger, barrel, hood, sight post, ring and bead, coloured in the vertices,
## so the whole of it is one draw call. Every face has its own normal -- see `_face` -- because
## `SurfaceTool.generate_normals` smooths across a welded corner and gives the rounded look the house
## asked not to have.
func _body_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := Color(0.14, 0.15, 0.16)
	var olive := Color(0.30, 0.33, 0.24)
	var steel := Color(0.40, 0.42, 0.44)
	_block(tool, GRIP_AT, GRIP, dark)
	# THE TRIGGER, in front of the grip under the barrel, where the index finger lies.
	_block(tool, Vector3(0.0, 0.045, -0.030), Vector3(0.008, 0.024, 0.010), steel)
	_prism(tool, BARREL_UP, BARREL_BACK, BARREL_FRONT, BARREL_RADIUS, olive)
	_prism(tool, BARREL_UP, BARREL_FRONT, HOOD_FRONT, HOOD_RADIUS, dark)
	# THE SIGHT: a post up off the barrel, a ring on it you look through, and a bead at the front.
	_block(tool, Vector3(0.0, BARREL_UP + BARREL_RADIUS + 0.004, SIGHT_AT.z),
		Vector3(0.004, 0.010, 0.004), steel)
	var ring_sides: int = SIDES
	for side in range(ring_sides):
		var a: float = TAU * float(side) / float(ring_sides)
		var b: float = TAU * float(side + 1) / float(ring_sides)
		var mid: float = (a + b) * 0.5
		var at := SIGHT_AT + Vector3(cos(mid), sin(mid), 0.0) * SIGHT_RADIUS
		var length: float = 2.0 * SIGHT_RADIUS * sin(PI / float(ring_sides)) + 0.002
		_block(tool, at, Vector3(length, 0.003, 0.003), steel, mid + PI * 0.5)
	_block(tool, BEAD_AT, Vector3(0.005, 0.007, 0.005), steel)
	return tool.commit()


## THE LENS: a thin eight-sided disc just inside the hood's mouth.
func _lens_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(tool, BARREL_UP, HOOD_FRONT + 0.006, HOOD_FRONT + 0.002, LENS_RADIUS, Color.WHITE)
	return tool.commit()


## ONE FACE: a flat polygon with its own normal, fanned from its first corner, wound so it faces `out`.
static func _face(tool: SurfaceTool, corners: Array, colour: Color, out: Vector3) -> void:
	var normal: Vector3 = ((corners[1] as Vector3) - (corners[0] as Vector3)).cross(
		(corners[2] as Vector3) - (corners[0] as Vector3)).normalized()
	var order: Array = corners.duplicate()
	# GODOT'S FRONT FACE IS CLOCKWISE AS SEEN, which is a normal of (b - a) x (c - a) pointing AWAY from the
	# viewer. So a face whose cross product points out is turned round.
	if normal.dot(out) > 0.0:
		order.reverse()
	for step in range(1, order.size() - 1):
		for corner in [order[0], order[step], order[step + 1]]:
			tool.set_color(colour)
			tool.set_normal(out.normalized())
			tool.add_vertex(corner as Vector3)


## A BOX of `size` centred on `at`, turned `roll` radians about the lamp's Z.
static func _block(tool: SurfaceTool, at: Vector3, size: Vector3, colour: Color, roll: float = 0.0) -> void:
	var basis := Basis(Vector3.BACK, roll)
	var half: Vector3 = size * 0.5
	for axis in range(3):
		for sign in [-1.0, 1.0]:
			var out := Vector3.ZERO
			out[axis] = sign
			var u := Vector3.ZERO
			var v := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			v[(axis + 2) % 3] = 1.0
			var middle: Vector3 = out * half[axis]
			var du: Vector3 = u * half[(axis + 1) % 3]
			var dv: Vector3 = v * half[(axis + 2) % 3]
			var corners: Array = [middle - du - dv, middle + du - dv, middle + du + dv, middle - du + dv]
			for i in range(4):
				corners[i] = at + basis * (corners[i] as Vector3)
			_face(tool, corners, colour, basis * out)


## A PRISM along Z from `back` to `front`, of `SIDES` sides and `radius` to its corners, its axis at height
## `up`. Capped at both ends.
static func _prism(tool: SurfaceTool, up: float, back: float, front: float, radius: float,
		colour: Color) -> void:
	var ring_back: Array = []
	var ring_front: Array = []
	for side in range(SIDES):
		# A FLAT UNDERNEATH AND ON TOP, not a corner: turned half a side, so it sits on a console.
		var a: float = TAU * (float(side) + 0.5) / float(SIDES)
		var offset := Vector3(cos(a) * radius, up + sin(a) * radius, 0.0)
		ring_back.append(offset + Vector3(0.0, 0.0, back))
		ring_front.append(offset + Vector3(0.0, 0.0, front))
	for side in range(SIDES):
		var next: int = (side + 1) % SIDES
		var mid: float = TAU * (float(side) + 1.0) / float(SIDES)
		_face(tool, [ring_back[side], ring_back[next], ring_front[next], ring_front[side]], colour,
			Vector3(cos(mid), sin(mid), 0.0))
	var towards_front: float = signf(front - back)
	_face(tool, ring_front, colour, Vector3(0.0, 0.0, towards_front))
	_face(tool, ring_back, colour, Vector3(0.0, 0.0, -towards_front))


## ---- held, carried and let go -----------------------------------------------------------------

## THE GRIP, which is the palm. See `GRIP_AT`.
func _grab_point() -> Vector3:
	return GRIP_AT


## GRABBED WITH A FIST: it has a pistol grip.
func taken_by() -> int:
	return Bind.Take.GRIP


## CARRIED WHILE FLYING, like the director's camera. See the note at the top.
func carried_by_hand() -> bool:
	return true


## ONLY BY THE PLAYER IN ITS OWN SEAT. See the note at the top.
func own_seat_only() -> bool:
	return true


## THE THREE FINGERS ARE THE THREE COLOURS, and do nothing else while the lamp is in the hand: an empty left
## hand brakes with its trigger, and a lamp being flashed at a wingman must not also be stopping the
## aeroplane. `hand_input` below is where they are read.
func bindings() -> Dictionary:
	return {Bind.TRIGGER: Bind.nothing(), Bind.THUMB_LOW: Bind.nothing(),
		Bind.THUMB_HIGH: Bind.nothing()}


## PICKED UP, CARRIED AND LET GO. The base class's carry, with the grip snapped into the palm: see the note
## at the top. `hand_at` is in the station's frame, so the lamp is placed in the station's frame and a lamp
## let go of stays in the cockpit.
func offer_hand_to_place(hand: int, hand_at: Transform3D, grip: float) -> void:
	if held_by == hand:
		if grip < GRAB_OFF:
			release()
			return
		transform = hand_at * IN_THE_PALM
		return
	super(hand, hand_at, grip)
	if held_by == hand:
		transform = hand_at * IN_THE_PALM
		# WHICH HAND, ON THE BUS, so every other machine puts it in that hand. See "on the wire".
		worked_here = false
		holder = LEFT if hand == 0 else RIGHT
		_tell_the_craft()


func _on_released() -> void:
	# A LAMP IN NOBODY'S HAND IS PUT OUT. See the note at the top.
	_asking.clear()
	holder = NOBODY
	_show(DARK)
	_tell_the_craft()


## WHAT THE HOLDING HAND'S FINGERS ARE DOING, once per input per frame. A finger going down asks for its
## colour; coming up takes the ask away. See "the newest press wins".
func hand_input(input: int, down: bool) -> void:
	if held_by < 0 or not FINGERS.has(input):
		return
	ask(int(FINGERS[input]), down)


## ASK FOR A COLOUR, OR STOP ASKING FOR IT. The one path to the lens, for a finger and for the desk's keys
## alike, so nothing can light one way for a hand and another for a key.
func ask(colour: int, down: bool) -> void:
	if colour < WHITE or colour > GREEN:
		return
	if down and not _asking.has(colour):
		_asking.append(colour)
	elif not down and _asking.has(colour):
		_asking.erase(colour)
	_show(_asking.back() if not _asking.is_empty() else DARK)
	_tell_the_craft()


## A DESK'S KEY, DOWN OR UP, with the head's pose in the seat's frame. The keyboard has no hand, so the lamp is held
## where a hand would hold it if the player were looking down the beam (`desk_pose`) for as long as a key is down,
## and left there when the last one comes up -- on every machine, because a far one puts it there from the same
## head pose. A lamp in a hand is the hand's: the key only asks for a colour.
func desk(colour: int, down: bool, head: Transform3D) -> void:
	if held_by >= 0:
		ask(colour, down)
		return
	if down:
		worked_here = true
		holder = DESK
		aim_from_the_desk(head)
	ask(colour, down)
	if _asking.is_empty():
		worked_here = false
		holder = NOBODY
		_tell_the_craft()


## FOLLOW THE HEAD while a desk's key is holding the lamp up. Every physics frame, from the rig.
func aim_from_the_desk(head: Transform3D) -> void:
	if holder == DESK and held_by < 0:
		transform = _seat_to_station() * desk_pose(head)


## WHERE A DESK HOLDS THE LAMP: out in front of the eye, a little right and low, its beam along the view. Asked the
## same way here and on a far machine, from the head's pose in the seat's frame, so the two cannot disagree.
static func desk_pose(head: Transform3D) -> Transform3D:
	return head * Transform3D(Basis.IDENTITY, DESK_FROM_THE_EYE)

## Where the desk holds it, in the head's frame.
const DESK_FROM_THE_EYE := Vector3(0.14, -0.20, -0.32)


## PUT IT BACK IN ITS HOLSTER, out of whatever hand has it. The desk's recall key.
func put_back() -> void:
	release()
	_asking.clear()
	worked_here = false
	holder = NOBODY
	_show(DARK)
	_tell_the_craft()
	transform = _holster


func _show(colour: int) -> void:
	if colour == lit:
		return
	lit = colour
	_redraw()
	signalled.emit(self, lit)


func is_lit() -> bool:
	return lit != DARK


## WHAT GOES ON THE BUS: the colour in the low two bits, who holds it in the next two, and `FITTED`.
func packed() -> int:
	return lit | (holder << 2) | FITTED


## WHETHER A LAMP CHANNEL'S VALUE SAYS THERE IS A LAMP AT THAT SEAT. -1, a channel the craft has not got, says no.
static func is_fitted_value(value: int) -> bool:
	return value >= 0 and (value & FITTED) != 0


## WHETHER A LAMP CHANNEL'S VALUE SAYS SOMEBODY HAS THE LAMP UP -- a hand or a desk -- which is when a far machine aims
## it from that pilot's pose. FOR ANYTHING THAT DECIDES WHETHER A PILOT'S POSE IS WORTH SENDING FAR (lane/ashiato-latest's
## distance LOD, 2026-09-18): on the host it is `bus_values(craft)[channel_for(seat)]`, and in the library's own terms the
## channel is `kCommandChannels - 1 - 256 + seat` and "held" is bits 2 and 3 not both zero. `tests/lamp_wire.gd` reads it
## off the server while a lamp is held.
static func is_held_value(value: int) -> bool:
	return value >= 0 and ((value >> 2) & 3) != NOBODY


## ---- a held lamp's hands are always sent -----------------------------------------------------

## WHICH CLIENTS THIS SERVER HAS BEEN TOLD ARE HOLDING A LAMP UP, so it is told only when that changes.
static var _live: Dictionary = {}


## ON THE SERVER, EVERY TICK: KEEP THE HANDS OF EVERY PLAYER WITH A LAMP UP GOING TO EVERYBODY.
##
## A far lamp is drawn from the holder's replicated hand or head (`follow`), and the far-pose LOD (`set_pose_lod`, lane/
## ashiato-latest step 3, off by default) stops sending a far pilot's PilotState. So whoever knows a lamp is up says so
## (`set_pose_live`) -- the LOD does not guess -- and this is that: every pilot's own seat's lamp channel, read off the
## server's own bus, and `set_pose_live` on every change of held (`is_held_value`). Off the SERVER's bus and the
## server's pilot list, because entity ids are per world and the host's client world is a different one.
##
## Told on the change and not every tick: a mask reopened costs a full record, and set_pose_live is idempotent anyway.
## Returns how many clients it told this call, for a suite.
static func keep_held_lamps_live(server: RefCounted) -> int:
	if server == null or not server.has_method("set_pose_live"):
		return 0
	var told: int = 0
	var seen: Dictionary = {}
	for state_any in server.pilot_states():
		var state := state_any as Dictionary
		var client: int = int(state.get("client", 0))
		var vehicle: int = int(state.get("vehicle", 0))
		if client <= 0 or vehicle == 0:
			continue
		var at: int = int(server.bus_values(vehicle).get(channel_for(int(state.get("seat", 0))), 0))
		var held: bool = is_held_value(at)
		seen[client] = true
		if bool(_live.get(client, false)) != held:
			server.set_pose_live(client, held)
			_live[client] = held
			told += 1
	# A PLAYER WHO LEFT WHILE HOLDING ONE is let go of, so the next client with that id does not inherit it.
	for client in _live.keys():
		if not seen.has(client):
			if bool(_live[client]):
				server.set_pose_live(int(client), false)
				told += 1
			_live.erase(client)
	return told


## Forget what this server was told, for a new session or a suite's new world.
static func forget_the_live_lamps() -> void:
	_live.clear()


## SAY WHAT THIS MACHINE IS DOING WITH THE LAMP, as a position on the control's own travel, and emit `moved` if it
## changed -- which is how every control in the cockpit reaches the bus (`PilotRig._send_what_moved`). Only while
## this machine is working it: a lamp drawn from the wire has nothing to say.
func _tell_the_craft() -> void:
	var wanted := from_command(packed())
	if value.distance_squared_to(wanted) < STILL:
		return
	value = wanted
	_told = packed()
	_told_until = Engine.get_physics_frames() + TOLD_FRAMES
	moved.emit(self)


## WHAT THIS MACHINE LAST TOLD THE CRAFT, and until which physics frame the wire is not believed over it. See `apply`.
var _told: int = -1
var _told_until: int = 0
## A SECOND at 120 Hz: far longer than any round trip the game plays over, and short enough that a command the server
## refused does not leave the lamp deaf to the craft for long.
const TOLD_FRAMES: int = 120


## DRAWN FROM THE WIRE: the colour and who holds it, off the bus. `VehicleControl.apply` refuses a lamp a hand or a
## key here is working, for the reason it refuses any control: the wire is a round trip behind them.
##
## AND IT REFUSES THE WIRE UNTIL THE WIRE HAS CAUGHT UP WITH WHAT THIS MACHINE LAST TOLD IT. Let go of a lamp and the
## hand is off it at once -- but the change is sent later in the same frame (`PilotRig._send_what_moved`), and the sky
## draws the cockpit from the bus in between (`FlightLevel._draw_cockpit`). So the lamp read the OLD colour back off the
## bus, put itself back to red, and the router, finding red where red had last been sent, sent nothing: the far machine
## never saw it go dark (`tests/lamp_peers.gd`, "dark never" three times out of three).
func apply(shared: Vector2) -> void:
	if held_by >= 0 or worked_here:
		return
	var at: int = clampi(int(round(shared.y * float(RANGE))), 0, RANGE)
	if _told >= 0:
		if at != _told and Engine.get_physics_frames() <= _told_until:
			return
		_told = -1
	value = shared
	holder = (at >> 2) & 3
	_show(at & 3)


## PUT SOMEBODY ELSE'S LAMP WHERE THEIR HAND OR THEIR EYE IS, from their pilot state as the wire has it (seat-local,
## as `RemotePilot` draws it). Nobody holding it: it stays where it was last put. Never this machine's own lamp, which
## its own hand places.
func follow(state: Dictionary) -> void:
	if held_by >= 0 or worked_here:
		return
	match holder:
		LEFT:
			transform = _seat_to_station() * Transform3D(Basis(state.get("left_basis", Quaternion.IDENTITY) as Quaternion),
				state.get("left", Vector3.ZERO) as Vector3) * IN_THE_PALM
		RIGHT:
			transform = _seat_to_station() * Transform3D(Basis(state.get("right_basis", Quaternion.IDENTITY) as Quaternion),
				state.get("right", Vector3.ZERO) as Vector3) * IN_THE_PALM
		DESK:
			transform = _seat_to_station() * desk_pose(Transform3D(
				Basis(state.get("head_basis", Quaternion.IDENTITY) as Quaternion), state.get("head", Vector3.ZERO) as Vector3))


## FROM THE SEAT'S FRAME TO THE STATION'S, which is the lamp's parent. The station hangs off the seat anchor,
## so this is the station's own transform, inverted.
func _seat_to_station() -> Transform3D:
	var station := get_parent() as Node3D
	return station.transform.affine_inverse() if station != null else Transform3D.IDENTITY


## WHERE THE BEAM LEAVES FROM, and which way it goes: the lens's front, looking along -Z.
func muzzle() -> Node3D:
	return _muzzle


## THE LENS, THE PIPS AND THE GLARE ARE DRAWN FROM `lit`, and from nothing else. A light with a flag of its own is
## a light that can disagree with the thing it is reporting (`DirectorCamera._redraw` says the same).
func _redraw() -> void:
	if _lens == null:
		return
	var glass := _lens.material_override as StandardMaterial3D
	glass.albedo_color = colour_of(lit) if lit != DARK else colour_of(DARK)
	glass.emission_enabled = lit != DARK
	glass.emission = colour_of(lit)
	glass.emission_energy_multiplier = 4.0 if lit != DARK else 0.0
	for step in range(_pips.size()):
		var which: int = WHITE + step
		var on: bool = which == lit
		_tint(_pips[step], colour_of(which) if on else colour_of(which).darkened(0.7))
		var material := _pips[step].material_override as StandardMaterial3D
		material.emission_enabled = on
		material.emission = colour_of(which)
		material.emission_energy_multiplier = 2.0 if on else 0.0
	if _glare != null:
		# A LAMP THAT IS OFF COSTS NOTHING: not drawn at all, rather than drawn dark.
		_glare.visible = lit != DARK
		(_glare.material_override as ShaderMaterial).set_shader_parameter("tint", colour_of(lit))


## ---- the glare ----------------------------------------------------------------------------------

## HOW THE BEAM IS SEEN FROM OUTSIDE, handed to `signal_lamp_glare.gdshader`. An Aldis lamp's beam is a few degrees
## wide and a signal read from a mile off is read inside it, so the glare is brightest and largest within `BEAM_CORE`
## of the axis and gone by `BEAM_EDGE`. It never shrinks below `LEAST_ANGLE`, which is what keeps a lamp a point at
## kilometres, the way `VehicleLights` keeps a wingtip light one. TEN MILLIRADIANS, NOT FOUR: at four, a red lamp aimed
## at the eye from 1.5 km drew 4 red pixels by day and 15 at night on the desktop window (`tests/lamp_beam_shot.gd`,
## 2026-09-18) -- fewer by day than a navigation light, and a lamp pointed at you is meant to be the brightest thing in
## the sky.
const BEAM_CORE: float = 4.0
const BEAM_EDGE: float = 22.0
const LEAST_ANGLE: float = 0.010
const GLARE_ENERGY: float = 3.0
## THE GLARE'S OWN QUAD, metres a side: what anything measuring the lamp's meshes sees. See `_build`.
const GLARE_QUAD: float = 0.02

## ONE MATERIAL PER LAMP, because the colour is per lamp. Few lamps are lit at once, and one that is dark is not drawn.
func _glare_paint() -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = GLARE
	paint.set_shader_parameter("tint", colour_of(lit))
	paint.set_shader_parameter("energy", GLARE_ENERGY)
	paint.set_shader_parameter("least_angle", LEAST_ANGLE)
	paint.set_shader_parameter("real_radius", LENS_RADIUS)
	paint.set_shader_parameter("beam_core", cos(deg_to_rad(BEAM_CORE)))
	paint.set_shader_parameter("beam_edge", cos(deg_to_rad(BEAM_EDGE)))
	paint.set_shader_parameter("quad_half", GLARE_QUAD * 0.5)
	return paint


## THE GLARE NODE, for a test that asks whether it is drawn.
func glare() -> MeshInstance3D:
	return _glare


## HOW BRIGHT THE LENS IS, off its material. What a test reads: a colour the lens is not emitting is a
## colour nobody sees.
func lens_energy() -> float:
	if _lens == null:
		return -1.0
	var glass := _lens.material_override as StandardMaterial3D
	return glass.emission_energy_multiplier if glass.emission_enabled else 0.0


func lens_colour() -> Color:
	if _lens == null:
		return Color.BLACK
	return (_lens.material_override as StandardMaterial3D).emission


## Nothing about a lamp is a throttle.
func throttle() -> float:
	return 0.0


## ---- the holster ---------------------------------------------------------------------------

## THE NAME EVERY HOLSTERED LAMP HAS, so a station has one and anybody can find it.
const NODE_NAME := "SignalLamp"

## WHERE THE HOLSTER SEARCH STARTS AND HOW IT STEPS, in the seat anchor's frame: out to the right of the
## seat at hip height, a little ahead of the shoulder, and then further out, back and up in 3 cm steps
## before it tries the left.
const HOLSTER_FROM := Vector3(0.30, 0.86, -0.12)
const HOLSTER_STEP: float = 0.03
const HOLSTER_TRIES := Vector3i(7, 7, 9)
## And how far BELOW the start it may go, in steps: a car's console gear sits where the first rows of tries are.
const HOLSTER_BELOW: int = 3
## AND HOW FAR INBOARD of the start it may come, in steps, for a craft too narrow for any outboard spot: 0.15 m from the
## centreline at the most. Searched only for a craft that can say where its skin is (`holster_spot`'s `fits`). THE DUO
## DISCUS (2026-09-19): 0.71 m across, and every spot from 0.30 m outward was through its skin -- both holsters hung
## outside the glider's port side.
const HOLSTER_INBOARD: int = 5


## THE LAMP IN `station`, or null.
static func in_station(station: Node) -> SignalLamp:
	return station.get_node_or_null(NODE_NAME) as SignalLamp if station != null else null


## PUT A LAMP IN A HOLSTER AT `station`'s seat, when a player places one or the wire says another seat has one, clear of every grip in `others` (in the station's frame).
## Does nothing if one is already there. Returns the lamp.
static func holster_in(station: Node3D, seat_index: int, others: Array[Vector3], fits: Callable = Callable()) -> SignalLamp:
	var already: SignalLamp = in_station(station)
	if already != null:
		return already
	var lamp := SignalLamp.new()
	lamp.name = NODE_NAME
	lamp.position = holster_spot(others, faces_in(station), fits)
	station.add_child(lamp)
	lamp.setup(seat_index)
	lamp.holster_here()
	return lamp


## WHEREVER IT IS NOW IS ITS HOLSTER: where the desk's recall key puts it back. Said by whatever put it there: the
## holster search, a saved layout, or the builder letting go of it.
func holster_here() -> void:
	_holster = transform

## THE LAMP'S OWN BODY, holstered, in its own frame: barrel, hood, grip and sight, and a centimetre round them. What must
## not stand between the eye and anything read.
const HOLSTERED_BODY := AABB(Vector3(-0.06, -0.07, -0.16), Vector3(0.12, 0.23, 0.23))


## EVERY FACE A SEATED PILOT READS IN `station`, as drawn boxes in its frame: every part that is not a control, not the
## shell, and in front of the eye -- a screen, the crew board, a gauge. Measured off the meshes, as `tests/water.gd`
## measures its tank gauge, so a part added tomorrow is kept clear tomorrow without a list.
static func faces_in(station: Node3D) -> Array[AABB]:
	var out: Array[AABB] = []
	if station == null:
		return out
	for child in station.get_children():
		var part := child as Node3D
		if part == null or part is VehicleControl or part is CockpitShell or not part.visible:
			continue
		var box: AABB = _drawn_box_of(part)
		if box.size != Vector3.ZERO and box.get_center().z < -0.05:
			out.append(box)
	return out


static func _drawn_box_of(part: Node3D) -> AABB:
	var box := AABB()
	var started: bool = false
	var parts: Array[Node] = [part]
	parts.append_array(part.find_children("*", "MeshInstance3D", true, false))
	var into: Transform3D = part.transform
	for node in parts:
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		# IN THE STATION'S FRAME, from the part's own transform down: nothing here is in the tree yet when the view
		# holsters a lamp, so a global transform would be the wrong question.
		var local: Transform3D = into
		if mesh != part:
			local = into * _path_transform(part, mesh)
		var own: AABB = mesh.mesh.get_aabb()
		for corner in range(8):
			var at: Vector3 = local * own.get_endpoint(corner)
			if not started:
				box = AABB(at, Vector3.ZERO)
				started = true
			else:
				box = box.expand(at)
	return box


## `node`'s transform in `root`'s frame, walking up its parents.
static func _path_transform(root: Node3D, node: Node3D) -> Transform3D:
	var out: Transform3D = Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != root:
		var spatial := at as Node3D
		if spatial != null:
			out = spatial.transform * out
		at = at.get_parent()
	return out


## WHETHER A LAMP HOLSTERED AT `at` STANDS BETWEEN THE SEATED EYE AND ANY OF `faces`: its body against the lines to the
## middle and four corners of each, the check `tests/water.gd` makes of the water bomber's tank gauge.
static func _hides_a_face(at: Vector3, faces: Array[AABB]) -> bool:
	var body := AABB(HOLSTERED_BODY.position + at, HOLSTERED_BODY.size)
	var eye := Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	for face in faces:
		# AND NOT IN IT: a face moved onto the console the holster is on -- lane/crewboard puts the crew board low and
		# outboard -- must not have a lamp standing through it.
		if body.intersects(face):
			return true
		var middle: Vector3 = face.get_center()
		var points: Array[Vector3] = [middle]
		for sx in [-0.48, 0.48]:
			for sy in [-0.48, 0.48]:
				points.append(middle + Vector3(face.size.x * sx, face.size.y * sy, face.size.z * 0.5))
		for point in points:
			if body.intersects_segment(eye, point):
				return true
	return false


## WHERE THE HOLSTER GOES: the first spot, nearest the start first, whose grip is at least two hands'
## reach from every grip in `others`, within an easy seated reach of a shoulder, out of the knees, and not
## between the seated eye and anything read (`faces`). The right side first, where the free hand is while the
## left is on the throttle; then the left.
##
## THE SIGHT LINES CAME LAST, and from a failure: on the water bomber the holster stood where the pilot reads
## his tank gauge (`tests/water.gd`, 2026-09-18).
## `fits`, where the craft can answer it (`VehicleView.holster_fits`): whether a box in the station's frame is inside the
## craft's drawn skin. TRIED SECOND, and only when the first spot puts the lamp's body outside it, so a craft whose
## holster already stands inside keeps it where it was. A cabin's declared ROOM was tried as this fence first, and it is
## the wrong question: it is the largest box PROMISED inside the skin, not the cabin's shape, and fencing every craft in
## it moved the Cessna's and the Savoia's holsters off good spots onto a yoke and a gauge, and the F-14's behind its
## chair (2026-09-19). The fenced spot is taken only if it is clear of every grip; otherwise the first stands.
static func holster_spot(others: Array[Vector3], faces: Array[AABB] = [], fits: Callable = Callable()) -> Vector3:
	var first: Vector3 = _holster_search(others, faces, Callable())
	if not fits.is_valid() or bool(fits.call(AABB(HOLSTERED_BODY.position + first, HOLSTERED_BODY.size))):
		return first
	var inside: Vector3 = _holster_search(others, faces, fits)
	if not bool(fits.call(AABB(HOLSTERED_BODY.position + inside, HOLSTERED_BODY.size))):
		return first
	for grip in others:
		if grip.distance_to(inside + GRIP_AT) < VehicleControl.REACH * 2.0:
			return first
	return inside


static func _holster_search(others: Array[Vector3], faces: Array[AABB], fits: Callable) -> Vector3:
	var fenced: bool = fits.is_valid()
	var tries: Array = []
	for mirror in [1.0, -1.0]:
		for out in range(-HOLSTER_INBOARD if fenced else 0, HOLSTER_TRIES.x + 1):
			for back in range(-HOLSTER_TRIES.z, HOLSTER_TRIES.z + 1):
				for up in range(-HOLSTER_BELOW, HOLSTER_TRIES.y + 1):
					var at := Vector3((HOLSTER_FROM.x + float(out) * HOLSTER_STEP) * mirror,
						HOLSTER_FROM.y + float(up) * HOLSTER_STEP,
						HOLSTER_FROM.z + float(back) * HOLSTER_STEP)
					tries.append([absi(out) + absi(back) + absi(up) + (0 if mirror > 0.0 else 100), at])
	tries.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var best: Vector3 = HOLSTER_FROM
	var roomiest: float = -INF
	for one in tries:
		var at: Vector3 = one[1]
		if CockpitStation.from_a_shoulder(at + GRIP_AT) > CockpitStation.EASY_REACH \
				or CockpitStation.KNEES.has_point(at) or _hides_a_face(at, faces):
			continue
		if fenced and not bool(fits.call(AABB(HOLSTERED_BODY.position + at, HOLSTERED_BODY.size))):
			continue
		var room: float = INF
		for grip in others:
			room = minf(room, grip.distance_to(at + GRIP_AT))
		if room >= VehicleControl.REACH * 2.0:
			return at
		if room > roomiest:
			roomiest = room
			best = at
	return best
