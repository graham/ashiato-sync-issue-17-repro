extends Node
## PRESS V WITH NO HEADSET: THE GAME STAYS ON THE DESKTOP, CLEANLY, ON EITHER EDITOR.
##
##   Godot --path cockpit res://tests/vr_fallback_shot.tscn
##
## NOT HEADLESS. `PilotRig.xr_available` answers no to a headless run before OpenXR is ever asked (a headless session
## has no swapchain), so headless would test that line and nothing else. Windowed, the press reaches `enter_vr`,
## which asks OpenXR to initialise; on a machine with no runtime running that fails, and what matters is what is left.
##
## WHY IT EXISTS. The headset plays the precision=double build from 2026-09-14, and there is no headset on the build
## machine. What can be proved here is that the double editor takes the same road as the stock one on a V with no
## runtime: the key reaches the rig through real input (keycode AND physical_keycode, as the rig's binding is read),
## the rig says so, the viewport is not stereo, the desktop camera is still the one drawing, and a second V does the
## same -- the ordering in `enter_vr` (cameras, then `use_xr`) is not reached, so nothing is left half-switched.
##
## A world with a player in it: `sky.tscn` with no `--level=watch`, which builds a `PilotRig`.

const PRESSES: int = 2

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[vr] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_check("there_is_a_window", false, "headless never asks OpenXR; run it windowed")
		_finish()
		return
	print("[vr] %s, %s precision" % [Engine.get_version_info()["string"], "double" if OS.has_feature("double") else "single"])
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	for i in range(120):
		await get_tree().process_frame
	var rig: PilotRig = level.rig
	_check("there_is_a_player", rig != null, "sky.tscn built a PilotRig")
	if rig == null:
		_finish()
		return
	var openxr: XRInterface = XRServer.find_interface("OpenXR")
	print("[vr] OpenXR interface %s, initialised before the press: %s" % [
		"found" if openxr != null else "absent", openxr.is_initialized() if openxr != null else false])
	for press in range(PRESSES):
		_press(KEY_V)
		for i in range(10):
			await get_tree().process_frame
		var at: String = "press %d" % (press + 1)
		_check("still_on_the_desktop_after_" + str(press + 1), not rig.using_xr, at)
		_check("and_the_viewport_is_not_stereo_after_" + str(press + 1), not get_viewport().use_xr, at)
		_check("and_the_desktop_camera_is_drawing_after_" + str(press + 1),
			rig.desktop_camera != null and rig.desktop_camera.visible
				and get_viewport().get_camera_3d() == rig.desktop_camera,
			"%s: camera %s" % [at, get_viewport().get_camera_3d()])
		_check("and_openxr_is_not_left_initialised_after_" + str(press + 1),
			openxr == null or not openxr.is_initialized(), at)
	_finish()


## A key down and up through the input the game reads, both codes set.
func _press(key: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = down
		Input.parse_input_event(event)


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
