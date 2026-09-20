extends Node
## THE SECOND WINDOW ON THE DESKTOP: what the director's camera sees, while it is recording.
##
## Asked for on 2026-09-15: *"i want the ability to make the 'desktop' show a different view than what
## is in the vr headset ... it's image should be on the desktop screen (and i should be able to
## fullscreen it as well like the other games in this directory)."*
##
## ---------------------------------------------------------------------------------
## WHY A SECOND WINDOW AND NOT THE GAME'S OWN
## ---------------------------------------------------------------------------------
##
## The obvious reading of the request is that the MAIN window should stop mirroring the headset and
## show the camera instead. Godot 4.7 will not do that, and the reason is worth writing down so nobody
## spends an afternoon finding out again.
##
## While the root viewport has `use_xr` on, everything drawn into it -- including every `CanvasLayer`
## and every 2D node -- is composited into the EYE buffers, and the desktop window is a blit of an eye.
## So a fullscreen `TextureRect` showing the camera's picture over the main window would put that
## picture inside the headset, over the cockpit, which is the opposite of the feature. There is no
## engine call that replaces what the XR blit puts on the screen.
##
## A `Window` node is a viewport of its own. It is drawn by the renderer as an ordinary non-XR
## viewport, blitted to its own operating-system window, and the root's `use_xr` never touches it. So
## it is the one arrangement whose behaviour in a headset can be reasoned about rather than hoped for
## -- which matters, because this machine has no headset to try it on (plan.md item 0).
##
## AND IT COSTS NO MORE. `tests/director_cost.gd` timed both: a `Window` at 1600x900 added 0.702 ms to
## a frame and a `SubViewport` of the same size added 0.671, inside the spread of either. Nothing is
## being paid for the safety.
##
## WHAT THE PLAYER GETS is two windows while recording: the mirror, which is what a spectator watches,
## and this one, which is what a recorder captures. Point OBS at this window, or press F11 in it.
##
## AND IT HAS TO BE A REAL ONE. A `Window` node is EMBEDDED by default -- drawn inside its parent
## viewport, with a title bar Godot paints itself -- and the first run of `tests/director_shot.gd`
## photographed exactly that: the recording sitting in a panel over the bottom half of the cockpit. In a
## headset that is the whole feature inverted, because a subwindow drawn into the root viewport is
## composited into the EYE buffers, which is the thing this file exists to avoid. So the root viewport
## stops embedding subwindows while the recording is up, and goes back to whatever it was doing
## afterwards -- `Viewport.gui_embed_subwindows`, which is the only switch there is; it is a property of
## the PARENT and not of the window, so it cannot be set on ours alone.
##
## ---------------------------------------------------------------------------------
## IT IS HANDED A PLACE TO STAND AND A FIELD OF VIEW, AND NOTHING ELSE
## ---------------------------------------------------------------------------------
##
## This knows nothing about cockpits, cameras, seats or aircraft. `watch` takes a `Node3D` and a number
## of degrees; every frame it stands its own camera where that node is. So the thing being followed
## could be a camera in a cockpit, a marker on a missile or a point in the sky, and none of them has to
## be a kind of thing this file has heard of.
##
## AND IT ANNOUNCES WHERE IT IS LOOKING rather than reaching back. `now_watching` carries what the
## window is showing, or null -- so a camera that was being recorded and is not any more, because
## another camera asked for the window or because the player shut it, hears about it and puts its own
## red light out. The alternative, this file turning a camera off, would mean the monitor knowing what
## a camera is.
##
## ---------------------------------------------------------------------------------
## OFF UNTIL SOMEBODY ASKS, AND GONE AGAIN AFTERWARDS
## ---------------------------------------------------------------------------------
##
## THE WINDOW IS BUILT WHEN IT IS WANTED AND FREED WHEN IT IS NOT. Not hidden: a hidden `Window` whose
## `render_target_update_mode` somebody later tidied would be a second full pass over the world with
## nothing looking at it, and the whole argument for this feature is that the pass happens only while a
## red light is on. `tests/director.gd` checks there is no second viewport with the camera off.
##
## AT THE WINDOW'S OWN SIZE, at 1.0 scale, with MSAA off. Not a guess: `tests/director_cost.gd` found
## that shrinking the recording saves almost nothing, because what the frame waits on is a second cull
## and a second render list over every vehicle in the world -- 0.47 to 0.50 ms at every size -- rather
## than the pixels. 960x540 cost 0.596 ms and 1920x1080 cost 0.617. So there is no render-scale knob
## here, and a future one would be a knob that does nothing.

## Where the window stands and how big it is when it first goes up. Beside the game's own window rather
## than over it, so both are visible without dragging one off the other on first use.
const SIZE := Vector2i(1280, 720)
const AT := Vector2i(80, 80)
const TITLE: String = "cockpit — director's camera"

## The monitor is now showing `at`, or nothing when `at` is null. See the note at the top: listeners
## decide what that means about themselves.
signal now_watching(at: Node3D)

## What the camera in the window is standing on, or null. The one piece of state here.
var _at: Node3D = null
var _window: Window = null
var _eye: Camera3D = null
## Whether the root viewport was embedding subwindows before the recording asked it to stop. See
## `_build_the_window`.
var _embedded_before: bool = false


## ---- what a camera asks for ----------------------------------------------------------------

## SHOW WHAT `at` SEES, at `fov` degrees. Returns whether the window actually went up.
##
## RETURNS A VERDICT RATHER THAN ASSUMING ONE, because a caller that lights a red light on the strength
## of this has to know whether anything is being recorded. A headless run has no screen; it still gets a
## viewport and a camera, which is what makes every one of this feature's checks runnable without a
## display, but a run with no `at` at all gets nothing and is told so.
func watch(at: Node3D, fov: float) -> bool:
	if at == null or not is_instance_valid(at):
		return false
	# ONE WINDOW, SO ONE CAMERA AT A TIME. A second camera switched on takes the monitor off the first,
	# and the first is told -- which is what keeps exactly one red light lit in a cockpit with two
	# cameras in it, without either of them knowing the other exists.
	_at = at
	if _window == null:
		_build_the_window()
	_eye.fov = fov
	_stand_the_camera()
	now_watching.emit(at)
	return true


## CHANGE THE FIELD OF VIEW of whatever it is already showing. Ignored when it is showing nothing --
## framing a shot nobody is recording is not an error, it is a camera being adjusted while off.
func frame_at(fov: float) -> void:
	if _eye != null:
		_eye.fov = fov


## STOP. The window goes, and with it the second pass over the world.
func look_away() -> void:
	if _at == null and _window == null:
		return
	_at = null
	_tear_the_window_down()
	now_watching.emit(null)


## What the window is standing on, or null. What a test asks instead of reaching into the window.
func watching() -> Node3D:
	return _at


## The window itself, or null when nothing is being recorded. For the fullscreen key and for tests that
## want to read the picture back.
func window() -> Window:
	return _window


## The camera in the window, or null. A test asks this and the root viewport's camera the same
## questions -- where are you, how wide are you -- which is how "the desktop is showing a different
## view" is checked without a screenshot.
func eye() -> Camera3D:
	return _eye


## ---- standing the camera --------------------------------------------------------------------

## EVERY FRAME, ON THE RENDER CLOCK, because that is the clock the picture is drawn on. A pose read on
## the physics clock would put the recording a fraction of a frame behind the cockpit it is bolted to,
## which on a camera held in a moving hand is exactly the wobble you would notice. The pinch lane (2026-09-15) learnt the same lesson from the other end.
func _process(_delta: float) -> void:
	if _at == null:
		return
	if not is_instance_valid(_at):
		# THE THING IT WAS WATCHING IS GONE -- binned by the builder, or its craft despawned. The window
		# goes with it rather than hanging on the last pose it saw.
		look_away()
		return
	_stand_the_camera()


func _stand_the_camera() -> void:
	if _eye == null or _at == null:
		return
	_eye.global_transform = _at.global_transform


## ---- the window -----------------------------------------------------------------------------

func _build_the_window() -> void:
	_window = Window.new()
	_window.name = "DirectorWindow"
	_window.title = TITLE
	_window.size = SIZE
	_window.position = AT
	# THE SAME WORLD, which is the whole point: the director's camera must see the same aircraft, the
	# same sea and the same weather as the pilot's. A window with a world of its own would draw an empty
	# sky and cost nothing, which is what "it works" looks like when it does not.
	_window.own_world_3d = false
	_window.msaa_3d = Viewport.MSAA_DISABLED
	_window.scaling_3d_scale = 1.0
	# ITS OWN KEYS. A `Window` is its own viewport, so input landing in it never reaches the autoload's
	# `_unhandled_input` in the main window's tree. `window_input` is where a key pressed in this window
	# arrives.
	_window.window_input.connect(_on_window_input)
	_window.close_requested.connect(look_away)
	# A WINDOW OF THE DESKTOP'S AND NOT ONE DRAWN INSIDE THE GAME'S. See the note at the top. Read
	# before it is changed, and put back in `_tear_the_window_down`, because this is the root
	# viewport's setting and every dialog in the game would otherwise inherit whatever the camera left
	# it on. The flag is read when a window ENTERS THE TREE, so it is set before `add_child` and not
	# after.
	_embedded_before = get_tree().root.gui_embed_subwindows
	get_tree().root.gui_embed_subwindows = false
	add_child(_window)
	_eye = Camera3D.new()
	_eye.name = "DirectorEye"
	# AS FAR AS THE PLAYER'S OWN CAMERA SEES, ASKED AND NOT TYPED. `FlightLevel` builds ground out to
	# whatever the ROOT viewport's camera can see, so a recording with a further plane would show the
	# edge of the built world and one with a nearer plane would cut the island off early. One number,
	# one place: the rig's camera is the authority and this copies it.
	var theirs: Camera3D = get_viewport().get_camera_3d()
	_eye.far = theirs.far if theirs != null else FlightLevel.FAR_WITH_NO_CAMERA
	_eye.near = theirs.near if theirs != null else 0.05
	_eye.current = true
	_window.add_child(_eye)


func _tear_the_window_down() -> void:
	_eye = null
	if _window == null:
		return
	_window.queue_free()
	_window = null
	if is_inside_tree():
		get_tree().root.gui_embed_subwindows = _embedded_before


## F11, OR SHIFT+F, IN THIS WINDOW, and in this window alone. `Fullscreen` owns the key and the mode;
## this only says which window it was pressed in, because `DisplayServer.window_set_mode` needs an id and
## a key pressed in the recording must not throw the mirror into fullscreen instead.
##
## THE THIRD ARGUMENT IS `exact_match` AND IT DEFAULTS TO FALSE. Without it a plain F press satisfies the
## Shift+F event too, and F is `next seat` on the desk -- which does not reach this window, but the habit
## is the one racer's own file argues for and costs nothing to keep.
func _on_window_input(event: InputEvent) -> void:
	if _window == null:
		return
	if event.is_action_pressed(Fullscreen.ACTION, false, true):
		Fullscreen.toggle(_window.get_window_id())
