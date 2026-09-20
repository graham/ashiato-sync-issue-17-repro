extends Node
## THE DIRECTOR'S CAMERA IN A COCKPIT, AND THE PICTURE IT PUTS ON THE DESKTOP, side by side.
##
##   Godot --path cockpit --xr-mode off res://tests/director_shot.tscn
##   Godot --path cockpit --xr-mode off res://tests/director_shot.tscn -- --out=C:/somewhere
##
## NOT HEADLESS -- it renders. Headless has no rendering device and every file would come back a black
## rectangle, which is what a result looks like when there is none. `tests/controller_shot.gd` is the
## shape this borrows.
##
## WHY IT EXISTS. `tests/director.gd` can say that the second window's camera stands on the lens, that
## it is pointed somewhere the player is not, and that a named point falls inside its frustum at a
## hundred degrees and outside it at twenty. What it cannot say is what any of that LOOKS like, and
## CLAUDE.md's second rule is that layout, legibility and "is it on screen at all" are invisible to a
## headless suite. So this takes the two pictures the item is about:
##
##   cockpit.png   the player's own view, with the camera floating in front of the seat and its red
##                 light lit -- which is the only way to find out whether a tally light the size of a
##                 thumbnail reads as lit from where a pilot sits.
##   desktop.png   what the second window is showing at that same instant: the same world, the same
##                 aeroplanes, from somewhere else entirely.
##   wide.png      the same shot at a hundred degrees, so the two can be held against each other.
##   narrow.png    and at twenty.
##
## THE TWO PICTURES ARE TAKEN A FRAME APART AND NOT AT ONCE, which is worth saying because it looks
## like a flaw and is not: `get_texture().get_image()` reads a render target back, and two viewports
## finish drawing at different points in a frame. The world is PAUSED for every picture here, so a
## frame between them changes nothing -- the aeroplanes are where they were.
##
## A probe, not a suite. Its one verdict is that the files were written and that the two pictures are
## not the same picture, which is the whole feature and is exactly the thing a mirror would fail.

const OUT_DEFAULT := "user://director_shots"

var _failures: PackedStringArray = []
var _out: String = OUT_DEFAULT


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("[director_shot] %s %s%s" % ["PASS" if ok else "FAIL", what,
		"" if detail == "" else " (%s)" % detail])
	if not ok:
		_failures.append(what)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0] == "out":
			_out = parts[1]
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return

	var level := load("res://world/sky.tscn").instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	for i in range(120):
		await get_tree().physics_frame
	var rig: PilotRig = level.rig
	rig.ask_for_kind(Sim.Kind.PLANE)
	for i in range(900):
		await get_tree().physics_frame
		if rig.vehicle_view() != null and rig.seat_index() == 0:
			break
	# AND A SECOND TO SETTLE, for the reason `controller_shot` gives: the HUD flashes red on sitting
	# down, and the first picture came out washed.
	for i in range(240):
		await get_tree().physics_frame

	var station: CockpitStation = rig.vehicle_view().station_for(rig.seat_index())
	if station == null:
		_check("there_is_a_station_to_put_a_camera_in", false, "no station at seat %d" % rig.seat_index())
		_finish()
		return
	var camera := DirectorCamera.new()
	camera.name = "ShotCamera"
	station.add_child(camera)
	camera.setup(rig.seat_index())
	# IN FRONT OF THE PILOT'S EYE AND OFF TO THE RIGHT, where a hand would have put it: close enough
	# that the tally light is a thumbnail rather than a dot, and turned back towards the pilot, which is
	# the shot somebody stands a camera in their own cockpit to get.
	#
	# PLACED FROM THE EYE AND NOT FROM THE STATION, which is the second attempt. A station's origin is
	# down at the cockpit floor, so the first numbers here -- picked as if they were offsets from the
	# head -- put the camera under the instrument panel, and the picture came back with no camera in it
	# at all. It is still a child of the station, so it still flies with the aeroplane; only the sum
	# that placed it has changed.
	camera.global_transform = rig.desktop_camera.global_transform \
		* Transform3D(Basis(Vector3.UP, PI), Vector3(0.26, -0.13, -0.55))
	await get_tree().process_frame

	DirAccess.make_dir_recursive_absolute(_out)
	# THROUGH THE KEYPAD, not through `turn()`. The picture has to be of the thing the player works,
	# and a probe that switched the camera on by calling the function underneath the button would be a
	# picture of a state nobody can reach.
	camera.keypad().press(CameraKeypad.POWER)
	await get_tree().process_frame
	_check("the_camera_is_recording", camera.is_on(), "is_on %s" % camera.is_on())
	_check("and_there_is_a_second_window", Monitor.window() != null, "%s" % Monitor.window())
	if Monitor.window() == null:
		_finish()
		return
	# THE SECOND WINDOW OUT OF THE WAY OF THE FIRST, so a person watching this run can see both.
	Monitor.window().position = Vector2i(40, 560)

	var cockpit: Image = await _picture_of_the_cockpit()
	var desktop: Image = await _picture_of_the_desktop()
	cockpit.save_png("%s/cockpit.png" % _out)
	desktop.save_png("%s/desktop.png" % _out)
	_check("the_two_pictures_are_not_the_same_picture", _apart(cockpit, desktop) > 0.05,
		"%.4f mean difference a pixel" % _apart(cockpit, desktop))

	camera.keypad().press(CameraKeypad.WIDER)
	for i in range(4):
		camera.keypad().press(CameraKeypad.WIDER)
	await get_tree().process_frame
	var wide: Image = await _picture_of_the_desktop()
	wide.save_png("%s/wide.png" % _out)
	_check("the_lens_opened_to_the_wide_end", is_equal_approx(camera.fov, DirectorCamera.FOV_MOST),
		"%.0f degrees" % camera.fov)

	for i in range(10):
		camera.keypad().press(CameraKeypad.NARROWER)
	await get_tree().process_frame
	var narrow: Image = await _picture_of_the_desktop()
	narrow.save_png("%s/narrow.png" % _out)
	_check("and_closed_to_the_narrow_end", is_equal_approx(camera.fov, DirectorCamera.FOV_LEAST),
		"%.0f degrees" % camera.fov)
	# A WIDE SHOT AND A NARROW ONE OF THE SAME WORLD ARE DIFFERENT PICTURES. Said out loud because
	# "the number changed" is the easy check and the one that would pass over a lens wired to nothing.
	_check("and_a_wide_shot_is_not_a_narrow_one", _apart(wide, narrow) > 0.05,
		"%.4f mean difference a pixel" % _apart(wide, narrow))
	print("[director_shot] four pictures in %s" % _out)
	_finish()


## THE PLAYER'S OWN VIEW, with the world held still so the recording beside it is of the same instant.
func _picture_of_the_cockpit() -> Image:
	get_tree().paused = true
	for i in range(4):
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## WHAT THE SECOND WINDOW IS SHOWING. The world is already paused by the call above and stays so.
func _picture_of_the_desktop() -> Image:
	get_tree().paused = true
	for i in range(4):
		await RenderingServer.frame_post_draw
	return Monitor.window().get_texture().get_image()


## HOW FAR APART TWO PICTURES ARE, per pixel, sampled by fraction of the width so two of different
## sizes can still be held against each other. `tests/director_cost.gd` carries the reason this is not
## a comparison of mean colours.
func _apart(one: Image, other: Image) -> float:
	const GRID: int = 48
	var total: float = 0.0
	# NOT WHERE THE BUILD STAMP IS (`BuildStamp`, 2026-09-18): both windows carry it in the lower right, at the same share
	# of the picture, so its letters would be the same in any two pictures and pull every pair together. Taken as a share
	# of the root's picture, a grid cell wider each way for the recording's own margins.
	var root_size := Vector2(get_viewport().get_texture().get_size())
	var stamp: Rect2 = BuildStamp.rect()
	stamp = Rect2(stamp.position / root_size, stamp.size / root_size).grow(1.0 / float(GRID)) if stamp.has_area() else Rect2()
	var counted: int = 0
	for j in range(GRID):
		for i in range(GRID):
			var across: float = (float(i) + 0.5) / float(GRID)
			var down: float = (float(j) + 0.5) / float(GRID)
			if stamp.has_point(Vector2(across, down)):
				continue
			counted += 1
			var a: Color = one.get_pixel(int(across * one.get_width()), int(down * one.get_height()))
			var b: Color = other.get_pixel(int(across * other.get_width()), int(down * other.get_height()))
			total += (Vector3(a.r, a.g, a.b) - Vector3(b.r, b.g, b.b)).length()
	return total / float(maxi(counted, 1))


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().paused = false
	get_tree().quit(0 if _failures.is_empty() else 1)
