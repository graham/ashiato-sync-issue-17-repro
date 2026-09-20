extends Node
## F11 OR SHIFT+F PUTS A WINDOW FULLSCREEN, and takes it back out again.
##
## Asked for on 2026-09-15 as part of the director's camera: *"i should be able to fullscreen it as
## well like the other games in this directory."* So this is `racer/autoload/fullscreen.gd`, brought
## across rather than reinvented -- the key, the borderless mode, the "read the mode back rather than
## trusting the request" rule and the on-screen refusal are all its, and are all things somebody there
## paid for. cockpit had no fullscreen key at all before this.
##
## TWO DIFFERENCES, and both are about this game having more than one window and more keys than racer.
##
## **Every call takes a window id.** racer has one window. This game has two while a recording is
## running -- the mirror and `Monitor`'s -- and a key pressed in the recording window that threw the
## MIRROR into fullscreen would be the least useful thing it could do. `DisplayServer.MAIN_WINDOW_ID`
## is the default, so a caller with one window reads exactly as racer's does.
##
## **AND NOTHING HERE LISTENS FOR THE KEY IN THE MAIN WINDOW, because both of racer's keys are already
## taken in this one.** `PilotRig.desk_keys` binds `KEY_F1 + kind` for every craft a player may be put
## in, and there are enough kinds that F11 is one of them -- it flies a Cessna. F is `next seat in this
## craft`, and `is_action_pressed` matches a plain event inside a modified press unless it is asked for
## an exact match, so Shift+F would change seat as well. Rebinding either to make room for a window key
## would change what every pilot's keyboard does, which is a bad trade for a convenience.
##
## So the key belongs to the RECORDING WINDOW, which is the window the request was about -- "i should
## be able to fullscreen IT" -- and which has no craft keys in it at all, because a `Window` is its own
## viewport and the rig's `_unhandled_input` never sees what lands there. `Monitor` listens on its
## window's own `window_input` and calls `toggle` with that window's id. The main window can still be
## put fullscreen by asking (`set_fullscreen`), by the window manager, and by alt+enter; it simply has
## no key of its own, which is what it had before this file existed.
##
## AN AUTOLOAD rather than a node in a level: the key has to work on the main menu, in the hall of
## cockpits and in the air, and this project keeps features working from files alone (`agents.md`).
##
## THE WINDOW'S OWN MODE IS THE TRUTH, never a flag kept here. A player can also be put into fullscreen
## by the window manager -- alt+enter, a tiling shortcut -- and a remembered flag would then have the
## key backwards.
##
## NOT EVERY WINDOW CAN CHANGE MODE. The editor's embedded game window refuses with "Embedded window
## only supports Windowed mode", and a headless run ignores the request entirely. Neither reports
## failure, so the mode is read back afterwards and a notice is shown rather than leaving the key
## looking broken. There is no DisplayServer call in 4.7 that says "this window is embedded", which is
## why this is established by trying it.

const ACTION: StringName = &"toggle_fullscreen"

const EMBEDDED_HINT: String = \
	"Fullscreen is unavailable in the editor's embedded game window.\n" \
	+ "Editor Settings > Run > Window Placement > Game Embed Mode: Disabled, then play again."
const UNAVAILABLE_HINT: String = "This window cannot go fullscreen."

signal fullscreen_changed(on: bool, window: int)
## The window refused the change. `message` explains why, as far as we can tell, and `window` says WHICH
## window refused -- which is the half a test can check on a machine where every window refuses, and the
## half that says the right window was asked.
signal toggle_unavailable(message: String, window: int)

var _notice: Label = null


func _ready() -> void:
	# Keep working while the tree is paused; a pause menu is the likeliest place somebody reaches for
	# the fullscreen key.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_actions()
	_build_notice()


## BOUND IN CODE rather than in project.godot's `[input]` map, which is how every other action in this
## game is bound -- the feature then survives a project.godot the editor rewrote, and there is no
## hand-edited InputEventKey blob to go stale.
##
## BOTH `keycode` AND `physical_keycode`, because a robot pressing this through
## `Input.parse_input_event` has to be able to match it either way. That is rule 9 in CLAUDE.md and it
## is what makes `tests/director.gd` able to press F11 at all.
func _bind_actions() -> void:
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
	_add_event(KEY_F11, false)
	_add_event(KEY_F, true)


func _add_event(keycode: Key, shift: bool) -> void:
	for event in InputMap.action_get_events(ACTION):
		if event is InputEventKey \
				and event.physical_keycode == keycode \
				and event.shift_pressed == shift:
			return
	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	key_event.shift_pressed = shift
	InputMap.action_add_event(ACTION, key_event)


## Whether a window mode counts as fullscreen. Exclusive fullscreen is somebody else's doing -- the
## game never asks for it -- but the key must still return from it.
static func mode_is_fullscreen(mode: int) -> bool:
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## The mode to switch to from a given one. Borderless fullscreen rather than exclusive: it alt-tabs
## cleanly and keeps a second monitor usable, which matters more here than the last few frames of
## latency -- and matters more again in a game whose point is that a second window is being recorded.
static func mode_after_toggle(mode: int) -> int:
	return DisplayServer.WINDOW_MODE_WINDOWED if mode_is_fullscreen(mode) \
		else DisplayServer.WINDOW_MODE_FULLSCREEN


## Why a window might have refused. Only a guess at the reason -- the failure itself is measured.
static func refusal_message() -> String:
	return EMBEDDED_HINT if OS.has_feature("editor") else UNAVAILABLE_HINT


func is_fullscreen(window: int = DisplayServer.MAIN_WINDOW_ID) -> bool:
	return mode_is_fullscreen(DisplayServer.window_get_mode(window))


## True if the window actually changed.
func toggle(window: int = DisplayServer.MAIN_WINDOW_ID) -> bool:
	return _request(mode_after_toggle(DisplayServer.window_get_mode(window)), window)


func set_fullscreen(on: bool, window: int = DisplayServer.MAIN_WINDOW_ID) -> bool:
	return _request(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED, window)


func _request(wanted: int, window: int) -> bool:
	DisplayServer.window_set_mode(wanted, window)
	if DisplayServer.window_get_mode(window) != wanted:
		var message: String = refusal_message()
		_show_notice(message)
		toggle_unavailable.emit(message, window)
		print("[fullscreen] refused on window %d: %s" % [window, message])
		return false
	fullscreen_changed.emit(mode_is_fullscreen(wanted), window)
	return true


## The autoload carries its own CanvasLayer so a refusal can be explained on screen in any scene
## without every scene having to provide a label for it.
func _build_notice() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FullscreenNotice"
	layer.layer = 128
	add_child(layer)
	_notice = Label.new()
	_notice.name = "Notice"
	_notice.visible = false
	_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice.offset_left = -420.0
	_notice.offset_top = 24.0
	_notice.offset_right = 420.0
	_notice.offset_bottom = 96.0
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_notice.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_notice.add_theme_constant_override("outline_size", 6)
	layer.add_child(_notice)


func _show_notice(message: String, seconds: float = 5.0) -> void:
	if _notice == null:
		return
	_notice.text = message
	_notice.visible = true
	# Fresh timer per notice so a second refusal restarts the countdown rather than inheriting the
	# remains of the first.
	var timer := get_tree().create_timer(seconds, true, false, true)
	await timer.timeout
	if _notice != null and _notice.text == message:
		_notice.visible = false
