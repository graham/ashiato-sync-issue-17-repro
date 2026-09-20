extends Node
class_name SceneryFinish
## HOW MUCH THE SCENERY IS WORTH DRAWING, AND THE ONE PLACE THAT KNOWS.
##
## Two finishes. PLAIN is the world as it was drawn before there was a choice: the same
## shader files, the same meshes, byte for byte, so it costs exactly what it always cost.
## FINE is the same world with more put into every surface -- waves with a shape, clouds
## with lumps in them, smoke that rises, lights on the aeroplanes. Everything that has two
## ways of drawing itself asks this node which, and listens for `changed`.
##
## THE DECISION: A TIER, NOT A SLIDER PER EFFECT. A headset is fill-rate bound, and what a
## player can actually decide in one is "this is too slow" -- not whether the smoke is worth
## more than the sea. One word they can flip with a thumb, one key on the desk, one flag on a
## command line, and one variable here that all three of them change. Nothing else holds a
## copy: an effect that cached the tier at build time would be an effect the switch does not
## reach, and it would look exactly like the switch being broken.
##
## THE AUTOLOAD IS `Finish` AND THE CLASS IS `SceneryFinish`, and the two names are needed.
## `PilotRig.DESK_KEYS` is a constant, and a constant cannot read a constant off an autoload
## -- the autoload is a node that does not exist until the game runs -- so the action name has
## to be reachable through a class. State is asked of `Finish`; names are read off the class.
##
## FINE IS A SEPARATE SHADER, NOT A UNIFORM. A `bool fine` in one shader is a branch paid on
## every pixel of every surface on both tiers, and on a mobile GPU the plain tier would get
## slower for having a fine one beside it. Two files sharing one noise include keep PLAIN
## exactly as cheap as it was.
##
## WHAT CAME BEFORE: nothing. The game had no graphics setting at all -- the render scale and
## the foveation level are constants in `PilotRig`, sized once for the swapchain -- so the
## only way to make the world cheaper was to edit a shader. This is not a second system
## beside an existing one; there was no first.
##
## NOT REPLICATED, and never will be. What one player's machine can afford to draw is nobody
## else's business, and a host that could turn a client's smoke up would be a bug report
## nobody could reproduce.

## The tier changed. `fine` is the new one. Emitted only on a CHANGE, so a listener that
## rebuilds a material does it once per flick rather than once per press of a switch that
## already agreed.
signal changed(fine: bool)

enum Tier { PLAIN, FINE }

## The input action the desk key and the observer's key are bound to. Bound by whoever owns
## the keyboard in that level -- `PilotRig.DESK_KEYS`, or the Observer -- and read here.
const ACTION: String = "finish"
## `--finish=plain` or `--finish=fine` after the bare `--`.
const FLAG: String = "finish"
## What a machine starts on when nobody has asked. See agents.md, "THE SCENERY HAS TWO
## FINISHES", for the frame times this was chosen against.
const DEFAULT: int = Tier.FINE

## WHAT A HEADSET STARTS ON: PLAIN, and not because FINE was measured to be too dear in one --
## because it was not measured in one at all. This machine has no headset; every frame time in
## agents.md is a desktop GPU drawing a window. PLAIN is the tier known to cost what the game
## cost before, and a headset that drops frames makes people ill, so the unmeasured tier is the
## one a player has to ask for. See `suit_the_display`.
const HEADSET_DEFAULT: int = Tier.PLAIN

## MULTISAMPLING IS PART OF THE FINISH, on the viewport the game and the headset both render
## through -- the root. PLAIN has none, which is what cockpit actually ran with for as long as
## `project.godot` asked for four times under a key Godot never read (see agents.md, "THE
## SCENERY HAS TWO FINISHES"), so every PLAIN frame time is still the game as it was. FINE has
## four times: every aircraft in this game is a hard silhouette against a flat sky, and an
## unsampled edge crawls as the head moves. Its cost in a headset has not been measured.
const PLAIN_MSAA: Viewport.MSAA = Viewport.MSAA_DISABLED
const FINE_MSAA: Viewport.MSAA = Viewport.MSAA_4X

var tier: int = DEFAULT
## Whether somebody has CHOSEN -- a flag, a key, a switch -- rather than the machine starting on
## its default. A choice is never overruled by putting a headset on or taking it off.
var _chosen: bool = false


func _ready() -> void:
	var asked: int = asked_on_the_command_line()
	if asked >= 0:
		tier = asked
		_chosen = true
	_multisample()
	print("[finish] %s scenery%s" % [name_of(is_fine()),
		" (asked for on the command line)" if asked >= 0 else ""])


func is_fine() -> bool:
	return tier == Tier.FINE


## CHOOSE ONE. Called by whatever the player touched -- the rig hands the clipboard's switch
## straight here, and the key arrives through `_unhandled_input` -- and by nothing else.
func choose(fine: bool) -> void:
	_chosen = true
	var wanted: int = Tier.FINE if fine else Tier.PLAIN
	if wanted == tier:
		return
	tier = wanted
	print("[finish] %s scenery" % name_of(fine))
	_multisample()
	changed.emit(fine)


func toggle() -> void:
	choose(not is_fine())


## THE DISPLAY CHANGED: a headset went on, or came off. Called by the rig at the moment it
## changes mode. Moves an UNCHOSEN tier to that display's default -- PLAIN in a headset, DEFAULT
## on a desk -- and leaves a chosen one exactly where the player put it.
func suit_the_display(in_headset: bool) -> void:
	if _chosen:
		return
	var wanted: int = HEADSET_DEFAULT if in_headset else DEFAULT
	if wanted == tier:
		return
	tier = wanted
	print("[finish] %s scenery, the default %s" % [name_of(is_fine()),
		"in a headset" if in_headset else "on a desk"])
	_multisample()
	changed.emit(is_fine())


## How many samples a pixel gets on the finish that is on.
func multisampling() -> Viewport.MSAA:
	return FINE_MSAA if is_fine() else PLAIN_MSAA


## ON THE ROOT, because that is the viewport `PilotRig` turns stereo on -- the headset renders
## through it, not through a SubViewport of its own. Done here rather than by a listener so no
## surface can ever see `changed` before the samples have followed.
func _multisample() -> void:
	if is_inside_tree():
		get_tree().root.msaa_3d = multisampling()


## THE KEY, AS AN EVENT AND NOT A POLL. A press read with `is_action_just_pressed` has to land
## between two frames to be seen, and a robot's press lasts one; an event cannot be missed.
## Unhandled, so a text field with the focus keeps the key for itself.
func _unhandled_input(event: InputEvent) -> void:
	if not InputMap.has_action(ACTION):
		return
	if event.is_action_pressed(ACTION, false):
		toggle()
		get_viewport().set_input_as_handled()


static func name_of(fine: bool) -> String:
	return "fine" if fine else "plain"


## -1 when the command line says nothing, or says something that is not a tier -- which is
## reported rather than guessed at, because `--finish=high` quietly meaning PLAIN would send
## somebody looking for a slowdown in the wrong place.
static func asked_on_the_command_line() -> int:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() != 2 or parts[0].to_lower() != FLAG:
			continue
		match parts[1].to_lower():
			"fine":
				return Tier.FINE
			"plain":
				return Tier.PLAIN
		push_warning("[finish] --finish=%s is not a finish; it is plain or fine" % parts[1])
	return -1
