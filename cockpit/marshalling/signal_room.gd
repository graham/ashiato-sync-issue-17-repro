extends Node3D
class_name SignalRoom
## EVERY SIGNAL IN THE BOOK, WITH NOTHING ROUND IT.
##
##   Godot --path cockpit -- --level=signals
##
## The hall of cockpits, for hands. A cockpit can only be judged by sitting in it and
## reaching for things; a signal can only be judged by making it, and finding out whether
## the thing that answers is the thing you meant. So: one room, one player, every zone
## drawable, and a board that says what the reader thinks your arms are doing.
##
## SPACE walks the book and the ghosts DEMONSTRATE the signal -- pose by pose, round and
## round -- so the way to learn one is to stand in front of it and copy it. Z draws every
## zone at once instead, which is the view you want when the question is whether two of them
## are too close together. C measures your arms.
##
## Nothing here is a level in the game sense: there is no aircraft, nothing to get right and
## no way to lose. It is the workshop.

const RIG := preload("res://marshalling/hand/marshal_rig.tscn")

var _rig: MarshalRig = null
var _reader: SignalReader = null
var _ghosts: SignalGhosts = null
var _board: Label3D = null
var _heard: Label3D = null
var _at: int = 0
var _showing_zones: bool = false
var _last: String = "nothing yet"
var _menu_was_down: bool = false


func _ready() -> void:
	_build_the_room()

	# A POST, and the rig BOLTED TO IT, exactly as a pilot is bolted to a seat anchor. The
	# rig never gets a world transform of its own here either -- see PilotRig, and the note
	# in `marshal_rig.gd` about why a marshaller is a seated pilot who happens to be
	# standing up. On a carrier the post is on the deck and rides with it.
	var post := Node3D.new()
	post.name = "Post"
	add_child(post)
	_rig = RIG.instantiate() as MarshalRig
	add_child(_rig)
	_rig.sit_in(post)

	_reader = SignalReader.new()
	_reader.name = "SignalReader"
	_reader.rig = _rig
	# UNDER THE XR ORIGIN, so the body frame and the hands are children of one node.
	_rig.origin.add_child(_reader)
	_reader.signalled.connect(_on_signalled)
	_reader.ended.connect(func(id: StringName) -> void:
		_last = "%s ended" % SignalBook.title(id))

	_ghosts = SignalGhosts.new()
	_ghosts.name = "Ghosts"
	_ghosts.reader = _reader
	_reader.add_child(_ghosts)

	_show(0)
	print("[signals] %d signals. SPACE next, SHIFT+SPACE back, Z every zone, C calibrate."
		% SignalBook.ids().size())


func _on_signalled(id: StringName, strength: float) -> void:
	_last = "%s   %d%%" % [SignalBook.title(id), int(round(strength * 100.0))]
	print("[signals] heard %s at %d%%" % [id, int(round(strength * 100.0))])


func _process(_delta: float) -> void:
	if _heard == null:
		return
	# LIVE, because the useful half of this room is watching the zone name change as your hand
	# crosses from one to the next. A signal that will not fire is nearly always a hand in
	# the zone next door to the one it wanted.
	_heard.text = "left   %s\nright  %s\n\n%s\narm %.2f m" % [
		_name_of(_reader.left_zone), _name_of(_reader.right_zone), _last, _reader.reach]


## The zone, in the words the table describes it with. "arm at your side" is what somebody
## learning this needs to read; `side` is what somebody debugging it needs, and the name is
## in there too.
static func _name_of(zone: StringName) -> String:
	return "-" if zone == SignalZones.NOWHERE \
		else "%s\n         %s" % [zone, SignalZones.says(zone)]


func _show(index: int) -> void:
	var ids: Array = SignalBook.ids()
	_at = posmod(index, ids.size())
	_showing_zones = false
	var id: StringName = ids[_at]
	_ghosts.demonstrate(id)
	_board.text = "%d of %d\n%s\n\n%s" % [_at + 1, ids.size(), SignalBook.title(id).to_upper(),
		SignalBook.says(id)]
	print("[signals] showing %s -- %s" % [id, SignalBook.says(id)])


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_SPACE:
			_show(_at + (-1 if key.shift_pressed else 1))
		KEY_Z:
			_showing_zones = not _showing_zones
			if _showing_zones:
				_ghosts.demonstrate(&"")
				_ghosts.show_every_zone()
				_board.text = "EVERY ZONE\n\nboth hands, all %d of them" \
					% SignalZones.names().size()
			else:
				_show(_at)
		KEY_C:
			# ARMS STRAIGHT OUT, then press it. See SignalReader.calibrate: the zones are
			# in body units and this is what makes the body yours.
			print("[signals] arm measured at %.2f m" % _reader.calibrate())


func _physics_process(_delta: float) -> void:
	# The menu button on the left controller walks the book, the same way it walks the
	# stations in the hall of cockpits -- and read here rather than through the rig for the
	# same reason: the rig's buttons belong to a craft, and this one belongs to the room.
	if _rig == null or not _rig.using_xr or _rig.left_hand == null:
		return
	var down: bool = _rig.left_hand.is_button_pressed(&"menu_button")
	if down and not _menu_was_down:
		_show(_at + 1)
	_menu_was_down = down


## ---- the room ---------------------------------------------------------------------

func _build_the_room() -> void:
	var deck := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(24.0, 0.4, 24.0)
	deck.mesh = slab
	deck.position = Vector3(0.0, -0.2, 0.0)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.13, 0.14, 0.16)
	paint.roughness = 0.95
	deck.material_override = paint
	add_child(deck)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.7, 0.0)
	add_child(sun)
	var air := WorldEnvironment.new()
	var room := Environment.new()
	room.background_mode = Environment.BG_COLOR
	room.background_color = Color(0.06, 0.07, 0.09)
	room.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room.ambient_light_color = Color(0.48, 0.51, 0.58)
	room.ambient_light_energy = 1.1
	air.environment = room
	add_child(air)

	_board = _sign(Vector3(0.0, 1.62, -2.5), 52, Color(0.95, 0.78, 0.30))
	_heard = _sign(Vector3(1.30, 1.30, -2.3), 32, Color(0.72, 0.86, 0.95))
	_heard.rotation = Vector3(0.0, -0.42, 0.0)
	# THE GHOSTS ARE ALL ROUND YOU, which is right in a headset and awkward on a monitor:
	# the overhead ones are above the top of the screen. So the room says how to look at
	# them, on the wall, where somebody who has just arrived will read it.
	var how := _sign(Vector3(-1.6, 1.15, -2.3), 30, Color(0.62, 0.68, 0.76))
	how.rotation = Vector3(0.0, 0.42, 0.0)
	how.text = "mouse: your arms\nright button: look around\nleft button: fists\n"\
		+ "wheel: reach\nQ / E: one arm only\nctrl: crouch\nshift: thumbs up\n\n"\
		+ "SPACE: next signal\nZ: every zone\nC: measure your arms"


func _sign(at: Vector3, size: int, tint: Color) -> Label3D:
	var plate := Label3D.new()
	plate.font_size = size
	plate.pixel_size = 0.0016
	plate.position = at
	plate.modulate = tint
	plate.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(plate)
	return plate
