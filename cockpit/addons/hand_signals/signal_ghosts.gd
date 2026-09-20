extends Node3D
class_name SignalGhosts
## WHERE TO PUT YOUR HANDS, DRAWN IN THE AIR IN FRONT OF YOU.
##
## Nobody knows twenty marshalling signals. A player who is not shown them is a player
## waving at an aeroplane hoping something happens, and the first minute decides whether
## there is a second one -- so the zones the current step wants are simply DRAWN, as two
## soft spheres at arm's length, and they light up when a hand arrives.
##
## This is the same answer the rest of the project gives to "how does anybody find this":
## the spotting boxes round distant aircraft, the nameplates in the hall of cockpits, the
## crew board listing seats. Show the thing in the world rather than describing it in a
## manual nobody opens.
##
## A child of the `SignalReader`, so it inherits the body frame for free: the ghosts sit
## around the player wherever the player is looking, because the zones do.

## The ghost of a hand you have not put there yet.
const WAITING := Color(0.95, 0.76, 0.28, 0.22)
## And the same ghost with your hand in it.
const FOUND := Color(0.45, 0.95, 0.55, 0.42)
## The same two answers in ink, for the line that says which hand is still wrong.
const WAITING_TEXT := Color(0.95, 0.78, 0.30)
const FOUND_TEXT := Color(0.50, 0.95, 0.58)
## HOW LONG THE GUIDE WAITS ONCE YOUR HANDS ARE IN THE POSE IT IS SHOWING, before moving on
## to the next one. A beat, so that arriving is acknowledged rather than instantly undone.
const BEAT: float = 0.55
## AND HOW LONG IT WAITS WHEN THEY ARE NOT.
##
## This is the difference between a guide and a metronome, and it was the metronome. The
## poses advanced every 0.8 s whatever the player was doing, so the targets you were reaching
## for moved before you got to them, went somewhere else, and came back -- while the matcher,
## which does NOT loop, sat waiting for the second pose you were being led away from. A
## player doing exactly the right thing watched the guide disagree with them.
##
## So it waits. Long enough to walk a couple of steps and get an arm up, and not for ever:
## a player who is doing nothing still has to be shown that a beckon REPEATS, because the
## repetition is the signal.
const IDLE: float = 3.5

var reader: SignalReader = null

var _balls: Array[MeshInstance3D] = []
var _shown: Array = []
var _caption: Label3D = null
## The line under the title that names whichever hand is not where it should be.
var _hint: Label3D = null
var _demo: StringName = &""
var _beat: float = 0.0
var _step: int = 0


func _ready() -> void:
	_caption = Label3D.new()
	_caption.font_size = 44
	_caption.pixel_size = 0.0008
	_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_caption.modulate = Color(0.95, 0.78, 0.30)
	# Above the target balls and out at arm's length plus a bit, so it labels the pose
	# rather than sitting in front of it.
	_caption.position = Vector3(0.0, 0.62, -1.6)
	_caption.visible = false
	add_child(_caption)
	_hint = Label3D.new()
	_hint.font_size = 30
	_hint.pixel_size = 0.0008
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.modulate = WAITING_TEXT
	# Under the title, and above the balls rather than among them: a caption in the middle
	# of the targets is one your own hand covers at the moment you need to read it.
	_hint.position = _caption.position + Vector3(0.0, -0.10, 0.0)
	_hint.visible = false
	add_child(_hint)


## THE POSE THIS STEP WANTS. `[left_zone, right_zone]`, either of which may be NOWHERE for a
## hand the signal does not care about -- and a hand the signal does not care about gets no
## ghost, because a target you do not have to hit is a target that teaches the wrong thing.
func show_pose(left: StringName, right: StringName, caption: String = "") -> void:
	_lay_out([[SignalZones.LEFT, left], [SignalZones.RIGHT, right]], caption)


## EVERY ZONE AT ONCE, both hands. The tuning room, and nothing else: it is unreadable as
## teaching and it is exactly what you want when the question is "is `brow` too close to
## `head`".
func show_every_zone() -> void:
	var wanted: Array = []
	for zone in SignalZones.names():
		wanted.append([SignalZones.LEFT, zone])
		wanted.append([SignalZones.RIGHT, zone])
	_lay_out(wanted, "every zone")


## PLAY A SIGNAL BACK, one pose a beat, round and round. Copying a movement is how anybody
## learns one, and a still picture of a cycling signal cannot show the thing that MAKES it
## that signal -- which is that it repeats.
func demonstrate(id: StringName) -> void:
	_demo = id
	_step = 0
	_beat = 0.0
	if id == &"":
		clear()
	else:
		_pose_of(id, 0)


func clear() -> void:
	_demo = &""
	_lay_out([], "")


func _process(delta: float) -> void:
	var arrived: bool = _light_up()
	if _demo == &"":
		return
	_beat += delta
	# THE GUIDE LEADS, IT DOES NOT RACE. Your hands being in the pose is what moves it on;
	# not being in it buys you IDLE seconds rather than none.
	if _beat < (BEAT if arrived else IDLE):
		return
	_beat = 0.0
	var steps: Array = (SignalBook.of(_demo) as Dictionary).get("steps", [])
	_step = (_step + 1) % maxi(steps.size(), 1)
	_pose_of(_demo, _step)


## The step of a signal, as two zones. A step whose hand accepts several zones shows the
## FIRST, which is the one the description in the book is written about.
func _pose_of(id: StringName, step: int) -> void:
	var row: Dictionary = SignalBook.of(id)
	var steps: Array = row.get("steps", [])
	if step >= steps.size():
		return
	var pose: Array = steps[step]
	var left: StringName = _first(pose[0])
	var right: StringName = _first(pose[1])
	var caption: String = SignalBook.title(id)
	if steps.size() > 1:
		caption += "  ·  %d of %d" % [step + 1, steps.size()]
	show_pose(left, right, caption)


static func _first(spec: Dictionary) -> StringName:
	var zones: Array = spec["zones"]
	return zones[0] if not zones.is_empty() else SignalZones.NOWHERE


## Balls where the hands should be. Pooled: a level that changes step every second would
## otherwise build and free a mesh and a material every second for the whole session.
func _lay_out(wanted: Array, caption: String) -> void:
	# A HAND THE SIGNAL DOES NOT CARE ABOUT GETS NO BALL. `["*", "brow"]` is one target and
	# drawing a second one at the origin would put a ghost inside the player's chest.
	var real: Array = []
	for one in wanted:
		if one[1] != SignalZones.NOWHERE:
			real.append(one)
	wanted = real
	_shown = wanted
	while _balls.size() < wanted.size():
		var ball := MeshInstance3D.new()
		var round_thing := SphereMesh.new()
		round_thing.radial_segments = 12
		round_thing.rings = 6
		ball.mesh = round_thing
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.albedo_color = WAITING
		ball.material_override = glow
		add_child(ball)
		_balls.append(ball)
	for i in range(_balls.size()):
		var ball: MeshInstance3D = _balls[i]
		ball.visible = i < wanted.size()
		if not ball.visible:
			continue
		var hand: int = wanted[i][0]
		var zone: StringName = wanted[i][1]
		var reach: float = reader.reach if reader != null else SignalZones.NOMINAL_REACH
		var stood: float = reader.shoulder if reader != null else SignalZones.NOMINAL_SHOULDER
		var span: float = SignalZones.radius(zone, reach)
		ball.position = SignalZones.place(zone, hand, reach, stood)
		var mesh := ball.mesh as SphereMesh
		mesh.radius = span
		mesh.height = span * 2.0
	if _caption != null:
		_caption.text = caption
		_caption.visible = caption != ""
	if _hint != null:
		_hint.visible = caption != ""


## GREEN WHEN THE HAND IS IN IT, and the answer to whether they ALL are.
##
## The one piece of feedback that makes the mechanic legible: a player who cannot tell
## whether they are in the zone cannot tell whether the signal is their arm or their timing.
## The return value is what lets the guide wait for them -- see `_process`.
func _light_up() -> bool:
	if reader == null or _shown.is_empty():
		return false
	var all_of_them: bool = true
	var missing: Array[String] = []
	for i in range(_shown.size()):
		var hand: int = _shown[i][0]
		var zone: StringName = _shown[i][1]
		var here: StringName = reader.left_zone if hand == SignalZones.LEFT \
			else reader.right_zone
		var paint := _balls[i].material_override as StandardMaterial3D
		var found: bool = here == zone
		paint.albedo_color = FOUND if found else WAITING
		if not found:
			all_of_them = false
			# IN WORDS, AND NAMING THE HAND. A ball you have not reached tells you where to
			# put something; it does not tell you WHICH something, and "my arm is in the
			# circle, why is nothing happening" is almost always the other arm.
			missing.append("%s hand: %s"
				% ["Left" if hand == SignalZones.LEFT else "Right",
					SignalZones.says(zone)])
	_tell_them(missing)
	return all_of_them


## WHAT IS STILL WRONG, under the title, where the player is already looking.
##
## Two lines at most: past that it is a paragraph in the air, which nobody reads while an
## aeroplane is rolling at them.
func _tell_them(missing: Array[String]) -> void:
	if _hint == null:
		return
	# JOINED WITH A NEWLINE, so two wrong hands are two lines rather than a sentence.
	_hint.text = "\n".join(missing) if not missing.is_empty() else "that's it -- hold it"
	_hint.modulate = WAITING_TEXT if not missing.is_empty() else FOUND_TEXT
	_hint.visible = _caption != null and _caption.visible
