extends Node3D
class_name MarshallingLevel
## THE HALF OF A MARSHALLING LEVEL THAT IS THE SAME ON A DECK AND ON A STAND.
##
## A player standing at a post, a reader watching their hands, an aeroplane that answers,
## and a checklist keeping score. What differs between the two levels is the PLACE, the
## AIRCRAFT and the LIST -- three methods, overridden -- and nothing else.
##
## The one piece of wiring worth reading is `_hear`: a signal goes to the aircraft AND to
## the checklist, in that order and unconditionally. The aeroplane obeys signals the
## checklist was not expecting, which is the difference between a job and a quick-time
## event: you can wave it forward when you should have stopped it, and the consequence is
## that it rolls forward, not that a prompt turns red.

## THE THREE DOORS, AND THE ONE PLACE THEIR PATHS ARE WRITTEN DOWN.
##
## The router opens them and the desk has buttons for them, and neither of those files
## should have to keep its own copy of a path into this directory -- a name that must agree
## with another name is asked for, not typed twice. Aliases because a person typing a
## command line should not have to remember whether it was `deck` or `carrier`.
const DOORS: Dictionary = {
	"deck": "res://marshalling/deck_launch.tscn",
	"carrier": "res://marshalling/deck_launch.tscn",
	"launch": "res://marshalling/deck_launch.tscn",
	"stand": "res://marshalling/gate_arrival.tscn",
	"gate": "res://marshalling/gate_arrival.tscn",
	"apron": "res://marshalling/gate_arrival.tscn",
	"signals": "res://marshalling/signal_room.tscn",
	"marshalling": "res://marshalling/signal_room.tscn",
	"hands": "res://marshalling/signal_room.tscn",
}


## The scene behind a `--level=` name, or "" if that name is not one of ours.
static func scene_for(level: String) -> String:
	return String(DOORS.get(level.to_lower(), ""))


const RIG := preload("res://marshalling/hand/marshal_rig.tscn")

## WHERE THE BOARDS STAND: an arm and a half away, off to the left, at chest height, turned
## in towards the player and leaning back like a clipboard on a stand.
##
## Not in front of the eyes -- a panel welded to the head is the one thing a headset does
## worse than a monitor, and you spend this whole level looking at an aeroplane. And not
## half a metre away either, which is where they started: at that range a board of ordinary
## text is two metres wide and fills the deck.
const BOARD_AT := Vector3(-0.92, 1.28, -0.95)
## Which way it is turned to face the player, worked out from where it stands rather than
## typed in beside it -- move the board and it still looks at you.
const BOARD_LEAN: float = -26.0

var rig: MarshalRig = null
var reader: SignalReader = null
var ghosts: SignalGhosts = null
var craft: MarshalledCraft = null
var procedure: MarshalProcedure = null

var _tells: Label3D = null
var _says: Label3D = null
var _said_at: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	if not Sim.is_available():
		push_warning("[marshalling] no CockpitWorld: the aircraft will be the wrong size. "
			+ "Run ashiato-gd/tools/bootstrap-linux.sh.")
	_build_the_place()
	craft = _build_the_craft()
	_stand_the_player_at(post_pose())

	procedure = MarshalProcedure.new()
	procedure.name = "Procedure"
	add_child(procedure)
	procedure.advanced.connect(_on_advanced)
	procedure.fault.connect(func(why: String) -> void: _say("MISTAKE: " + why))
	procedure.finished.connect(_on_finished)
	if craft != null:
		craft.refused.connect(func(_what: StringName, why: String) -> void:
			_say("The pilot: \"%s\"" % why))
	procedure.begin(_steps())


## ---- what a level supplies ---------------------------------------------------------

## The deck, the sea, the paint, the light. Called first.
func _build_the_place() -> void:
	pass


## The aeroplane, already placed where it starts.
func _build_the_craft() -> MarshalledCraft:
	return null


## The job, as a list of steps. See MarshalProcedure.
func _steps() -> Array:
	return []


## Where the marshaller stands, and which way they are looking when they get there.
func post_pose() -> Transform3D:
	return Transform3D.IDENTITY


## WHERE SHE IS BEING PUT: the line she should be on, and the mark she should stop on. Two
## numbers, because both levels are the same shape -- a line and a bar -- and the test's
## robot marshaller reads them rather than knowing one apron from the other.
func the_line() -> Vector2:
	return Vector2.ZERO


## ---- the player --------------------------------------------------------------------

## A POST IS A SEAT. The rig is bolted to an anchor and never given a world transform of its
## own, exactly as a pilot is bolted to a seat -- which is not ceremony: put this post on a
## carrier that is making way and the player's hands are steady on a moving deck for the
## same reason a pilot's are steady at 300 kph.
func _stand_the_player_at(pose: Transform3D) -> void:
	var post := Node3D.new()
	post.name = "Post"
	post.transform = pose
	add_child(post)
	rig = RIG.instantiate() as MarshalRig
	add_child(rig)
	rig.sit_in(post)

	reader = SignalReader.new()
	reader.name = "SignalReader"
	reader.rig = rig
	rig.origin.add_child(reader)
	reader.signalled.connect(_hear)
	reader.holding.connect(_hold)
	reader.ended.connect(_let_go)

	ghosts = SignalGhosts.new()
	ghosts.name = "Ghosts"
	ghosts.reader = reader
	reader.add_child(ghosts)

	_tells = _board(BOARD_AT, 38, Color(0.95, 0.80, 0.32))
	_says = _board(BOARD_AT + Vector3(0.0, -0.30, 0.0), 30, Color(0.80, 0.88, 0.95))
	post.add_child(_tells)
	post.add_child(_says)
	var facing: float = atan2(-BOARD_AT.x, -BOARD_AT.z)
	for plate in [_tells, _says]:
		plate.rotation = Vector3(deg_to_rad(BOARD_LEAN), facing, 0.0)


## ---- hands to aeroplane --------------------------------------------------------------

## A SIGNAL, ONCE. To the aircraft first and the checklist second, and neither is allowed to
## veto the other.
## HOW FAR ROUND THE PLAYER MAY BE LOOKING and still be signalling. About seventy degrees
## either side, which is generous: it lets you glance at the board and watch a wingtip.
const EYES_ON: float = 0.32

func _hear(id: StringName, strength: float) -> void:
	# A SIGNAL MADE WITH YOUR BACK TURNED IS NOT A SIGNAL.
	#
	# The pilot has to be able to see you, and you have to be able to see the aeroplane --
	# which is a real rule, not a flourish: a marshaller signalling something they are not
	# looking at is a marshaller who cannot see the wingtip they are walking into a bridge.
	# The zones are around your body wherever you face, deliberately, so this is the ONLY
	# thing that says which way you are pointing.
	if craft != null and reader.facing(craft.global_position) < EYES_ON:
		_say("Face her. The pilot cannot see what you are doing.")
		return
	if craft != null:
		craft.command(id, strength, true)
	if procedure != null:
		procedure.heard(id)
	print("[marshalling] %s" % SignalBook.title(id))


## A SIGNAL BEING HELD. Every frame, which is what a standing order is: the aeroplane is
## told again, at whatever rate the arms are moving now.
func _hold(id: StringName, strength: float) -> void:
	if craft != null:
		# NOT FRESH. See MarshalledCraft.command: a held order is one the aircraft may
		# refuse to hear, because it goes on arriving after the arms have stopped.
		craft.command(id, strength, false)


func _let_go(id: StringName) -> void:
	if craft != null:
		craft.release(id)


func _on_advanced(_index: int, tells: String) -> void:
	if _tells != null:
		_tells.text = tells
	var wanted: StringName = procedure.expects()
	# THE GHOSTS SHOW WHAT IS WANTED NEXT. Which is the whole answer to "how does anybody
	# learn twenty signals": they are drawn, at arm's length, in the order the job needs
	# them, and you copy the one in front of you.
	if ghosts != null:
		ghosts.demonstrate(wanted)
	if wanted != &"":
		print("[marshalling] wants %s -- %s" % [wanted, SignalBook.says(wanted)])


func _on_finished(score: Dictionary) -> void:
	if ghosts != null:
		ghosts.demonstrate(&"")
	var lines: String = "DONE\n%.0f seconds, %d mistakes" % [score["seconds"],
		score["faults"]]
	for mark in (score["marks"] as Dictionary):
		lines += "\n%s: %s" % [mark, score["marks"][mark]]
	if _tells != null:
		_tells.text = lines
	print("[marshalling] %s" % lines.replace("\n", " · "))


func _say(what: String) -> void:
	_said_at = _clock
	if _says != null:
		_says.text = what
	print("[marshalling] %s" % what)


func _physics_process(delta: float) -> void:
	_clock += delta
	# A REMARK IS NOT A CAPTION. It says its piece and goes away, so the board is empty
	# whenever nothing has just gone wrong.
	if _says != null and _says.text != "" and _clock - _said_at > 5.0:
		_says.text = ""


## ---- odds and ends -------------------------------------------------------------------

func _board(at: Vector3, size: int, tint: Color) -> Label3D:
	var plate := Label3D.new()
	plate.font_size = size
	plate.pixel_size = 0.0007
	plate.position = at
	plate.modulate = tint
	plate.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	plate.width = 860.0
	plate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return plate

