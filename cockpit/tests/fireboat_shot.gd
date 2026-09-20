extends Node
## THE FIREBOAT FIGHTING A FIRE ON THE OIL PLATFORM, photographed by day and by night.
##
##   Godot --path cockpit --xr-mode off --resolution 1600x900 res://tests/fireboat_shot.tscn -- --level=watch
##   ... -- --level=watch --out=C:/somewhere [--only=03]
##
## NOT HEADLESS -- it renders. This is the picture the whole lane is for: the user asked for "a firefighting boat, with
## a controllable hose that shoots a stream of water", for the oil rig to be the thing alight, and for "at least one
## during the day and another at night".
##
## IT IS NOT FOR THE PICTURE ALONE, and that is `oil_platform_shot.gd`'s rule copied on purpose. A stream proved by its
## own shader would go on being proved for ever if nothing ever opened a monitor; a fire proved by its own strength
## would go on burning whatever the water did. So each picture also MEASURES what it shows:
##
##   * the water is proved by a BEFORE AND AFTER OF THE SAME FRAME -- the identical camera with the monitors shut,
##     then with them running -- and the check counts how many pixels got PALER. The first version of this counted
##     "bright and neutral" pixels in the finished picture and passed with 25,283 of them on a photograph containing
##     no water at all: a hazy sky, a white deckhouse and pale smoke are all bright and neutral. That is
##     `modelling_here.md` section 7's rule exactly -- take the before shot BEFORE you make the change, because a
##     number that agrees with your prediction is not a picture;
##   * the fire is asked for its strength BEFORE and AFTER the monitors run, and must have been knocked down, which is
##     the user's "attempt to put it out" -- and a control fire out of the water's reach must NOT have been, without
##     which a timer would pass this just as well as the water does.
##
## KNOWN RED, ON PURPOSE: `and_she_is_drawn_at_the_scale_the_filename_claims` FAILS TODAY.
##
## Picture 05 is an orthographic port elevation meant to be laid over the reference photograph, and it is the ONLY
## instrument that can check a fore-and-aft STATION -- see `craft/fireboat/overlay.py` and
## `learnings/2026-09-20-harriershape.md`. The camera is genuinely orthographic and genuinely the one that drew
## (both checked), but the boat comes out about a tenth of the size the camera's `size` implies, and this lane did
## not work out why.
##
## THE CHECK IS LEFT RED RATHER THAN REMOVED OR LOOSENED, and that is the point. Its FIRST version passed over the
## same wrong picture because it read `LENGTH_M * px_per_m` -- arithmetic on two numbers this file already knew --
## instead of measuring the drawn hull. An overlay is worth nothing if its stated scale is not its drawn scale, so
## a green check over that picture was worse than no check at all. This one measures the red hull in the image and
## says what it found. It is a PROBE and not in `suites.txt`, so it gates nothing; see
## `todo/fireboat--the-orthographic-overlay-does-not-scale.md`.
##
## WHY THE WORLD WORKS HER RATHER THAN A CREW. Three monitors need three gunners, and nobody is aboard in a shot.
## `CockpitWorld.aim_gun` and `set_monitor` are the server's way to work a mount, exactly as `fire_gun` already is --
## and they go through the SAME stops as a gunner's stick (`hold_the_stops`), so this cannot photograph a monitor
## pointing somewhere a crew could not have pointed it.

const DEFAULT_OUT: String = "user://"
const SETTLE: int = 90
## How long the monitors run before the second picture, in frames, and how hard the fire must be knocked down by then.
const PLAY_WATER: int = 420
const KNOCKED_DOWN_BY: float = 0.08
## WHERE SHE STANDS OFF, in the platform's frame: 70 m out on the beam, which is inside the monitors' measured 97.5 m
## reach with room for the arc (`craft/fireboat/sources.md`).
const STAND_OFF := Vector3(0.0, 0.0, 74.0)
## WHICH MODULE IS ALIGHT, in the platform's frame: on the weather deck, the end nearest the boat.
const BLAZE_AT := Vector3(-6.0, 26.0, 12.0)
## AND A CONTROL FIRE, far enough off that no water can reach it. If this one goes out too, something other than the
## water is putting fires out and the check above is measuring a timer.
const CONTROL_AT := Vector3(-6.0, 26.0, -300.0)
## How far the monitors are trained off dead ahead to lay their water on the module, and how high. Elevation is the
## ballistics' answer for this range, not a number chosen by eye. Solved under the same linear drag the stream and the
## dousing both use: from a nozzle 3.9 m up, 36 degrees puts the water 26.2 m up at 74 m, which is the module, after
## 2.95 s of flight. 34 degrees would reach 24.5 m and 38 would reach 27.6.
## HER HEADING, and the train that follows from it. A monitor's yaw is in the CRAFT's frame with 0 dead ahead, and
## the bearing of a target that lies dead astern of the world's -Z works out as exactly `-HEADING`. Derived rather
## than typed, so moving her round the rig cannot leave the monitors pointing at nothing.
const HEADING: float = PI * 0.5
const TRAIN: float = -PI * 0.5
## HOW MANY METRES THE ORTHOGRAPHIC ELEVATION'S FRAME IS TALL. A round number on purpose: the px/m it implies is
## printed into the picture's own filename, and a round size makes the overlay's arithmetic checkable by eye.
const ORTHO_METRES: float = 25.0
## Her published length, so the elevation can assert she is drawn at the scale its filename claims.
const LENGTH_M: float = 42.672
const ELEVATE: float = 0.628

var _out: String = DEFAULT_OUT
var _only: String = ""
var _level: FlightLevel = null
var _stamp: Label = null
var _commit: String = ""
var failures: PackedStringArray = []
var _boat: int = 0
var _fire_at := Vector3.ZERO
var _control_at := Vector3.ZERO
## THE FRAME WITH THE MONITORS SHUT, kept so the one with them running can be held against it.
var _reference: Image = null


func check(label: String, ok: bool, detail: String = "") -> void:
	print("[fireboat_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures.append(label)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--out="):
			_out = String(arg).substr(6)
		if String(arg).begins_with("--only="):
			_only = String(arg).substr(7)
	if DisplayServer.get_name() == "headless":
		check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	_commit = _commit_stamp()
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		check("there_is_somebody_watching", false, "pass --level=watch after the bare --")
		_finish()
		return
	_quieten()

	var sites: Array[Dictionary] = OilField.sites()
	check("the_world_has_an_oil_platform", not sites.is_empty(), "%d sites" % sites.size())
	if sites.is_empty() or Sim.server == null:
		check("there_is_a_simulation_to_put_her_in", Sim.server != null, "no server")
		_finish()
		return
	var site: Vector3 = sites[0]["position"]
	_fire_at = site + BLAZE_AT
	_control_at = site + CONTROL_AT

	# HER, ALONGSIDE, HEAD ON TO THE RIG so the forward monitors bear on it.
	var where: Vector3 = site + STAND_OFF
	# SHE LIES BEAM ON TO THE FIRE, AND THAT IS THE ONLY HEADING ON WHICH ALL THREE MONITORS BEAR.
	#
	# Each mount trains 135 degrees either side of where it rests. The two forward ones rest dead ahead and the after
	# one rests dead astern, so a fire ON THE BOW can be reached by two of the three and never by the third -- which
	# is a true fact about the arrangement the user asked for, not a bug, and the first picture showed it honestly
	# with the after monitor throwing its water out to sea behind her. Broadside on, the fire is 90 degrees off the
	# bow AND 90 degrees off the stern, inside both arcs. It is also how a fireboat actually lies alongside a fire.
	#
	# The first run had her at PI, stern to the rig, and all three threw out to sea.
	_boat = int(Sim.server.spawn_vehicle(Sim.Kind.FIREBOAT, Vector3(where.x, Terrain.SEA_LEVEL, where.z),
		HEADING, Vector3.ZERO))
	check("she_is_in_the_water_beside_the_rig", _boat != 0, "entity %d, %.0f m off" % [_boat, STAND_OFF.length()])
	if _boat == 0:
		_finish()
		return

	await _picture("01-alongside-the-rig-day", DaylightTuning.When.DAY, site,
		Vector3(96.0, 26.0, 150.0), Vector3(-4.0, 22.0, 36.0), 42.0, false)
	# THE ONE INSTRUMENT THAT CAN CHECK A STATION. See `_the_profile_against_the_photograph`.
	await _orthographic_profile(site)
	await _fight_the_fire(site)
	_finish()


## LIGHT THE RIG, OPEN THE MONITORS, AND WATCH WHAT THE WATER DOES -- by day and again at night.
func _fight_the_fire(site: Vector3) -> void:
	var blaze: int = int(Sim.server.light_fire(_fire_at, 1.0))
	var control: int = int(Sim.server.light_fire(_control_at, 1.0))
	check("the_rig_is_alight", blaze != 0 and control != 0,
		"the module burning as entity %d, a control fire %.0f m away as %d"
		% [blaze, (_control_at - _fire_at).length(), control])
	if blaze == 0:
		return
	# BEFORE. Settle first, so the flame is drawn and its strength is the one the picture shows.
	for i in range(40):
		await get_tree().process_frame
	var was: float = _fire_strength(blaze)
	var was_control: float = _fire_strength(control)
	await _picture("02-the-rig-alight-day", DaylightTuning.When.DAY, site,
		Vector3(96.0, 30.0, 150.0), Vector3(-6.0, 30.0, 20.0), 42.0, false)

	# THE BEFORE FRAME, at the very camera picture 03 will use, with the monitors still shut. Nothing else in the
	# scene is touched between this and the after, so every pixel that changes is water.
	_reference = await _grab_at(site, Vector3(96.0, 30.0, 150.0), Vector3(-6.0, 28.0, 20.0), 42.0)

	# THE MONITORS, TRAINED ON THE MODULE AND OPENED. Through the server's own calls, which hold the same stops a
	# gunner's stick does.
	for mount in range(3):
		Sim.server.aim_gun(_boat, mount, TRAIN, ELEVATE)
		Sim.server.set_monitor(_boat, mount, true)
	for i in range(PLAY_WATER):
		await get_tree().process_frame
		# HELD OPEN. The pump is a valve a person holds; nothing here lets go of it.
		for mount in range(3):
			Sim.server.set_monitor(_boat, mount, true)

	# WHAT THE DRAWER ACTUALLY HAS. Asked out loud, because "no water in the picture" has at least four causes and
	# the picture cannot tell them apart: nobody opened the pump, the pump bit did not reach the client, the yard is
	# not in the level, or the yard is there and laid nothing.
	var has_client: bool = Sim.client != null
	var reported: Array = [] if not has_client else (Sim.client.craft_systems(_boat).get("monitors_flowing", []) as Array)
	var yard_there: bool = _level.get("monitors") != null
	var laid: int = 0
	if yard_there:
		var mm: Node = (_level.get("monitors") as Node).get_node_or_null("Monitors")
		if mm != null:
			laid = int((mm as MultiMeshInstance3D).multimesh.visible_instance_count)
	check("the_drawer_has_something_to_draw", has_client and reported.size() >= 3 and yard_there and laid > 0,
		"Sim.client %s, flowing %s, yard %s, %d segments laid"
		% [has_client, reported, yard_there, laid])

	await _picture("03-monitors-on-the-rig-day", DaylightTuning.When.DAY, site,
		Vector3(96.0, 30.0, 150.0), Vector3(-6.0, 28.0, 20.0), 42.0, true)
	await _picture("04-monitors-on-the-rig-night", DaylightTuning.When.NIGHT, site,
		Vector3(96.0, 30.0, 150.0), Vector3(-6.0, 28.0, 20.0), 42.0, true)

	var now: float = _fire_strength(blaze)
	var now_control: float = _fire_strength(control)
	# THE WATER KNOCKED IT DOWN -- and the control fire, out of reach, did NOT go out. Without the second half a
	# timer, a `burn` bug or a fire that simply expires would pass this exactly as well as the water does.
	check("the_water_knocked_the_fire_down", now < was - KNOCKED_DOWN_BY,
		"the module went %.2f -> %.2f while the monitors ran" % [was, now])
	check("and_a_fire_out_of_reach_did_not_go_out", now_control >= was_control - KNOCKED_DOWN_BY * 0.5,
		"the control fire %.0f m away went %.2f -> %.2f"
		% [(_control_at - _fire_at).length(), was_control, now_control])


## HOW HARD A FIRE IS BURNING, off the simulation's own record.
func _fire_strength(entity: int) -> float:
	for fire in (Sim.server.fire_states() as Array):
		if int(fire.get("entity", 0)) == entity:
			return float(fire.get("strength", 0.0))
	return 0.0


## ONE PICTURE. `water` asks that the stream is actually in the air between the eye and the rig.
func _picture(id: String, when: int, site: Vector3, eye_at: Vector3, look_at: Vector3, fov: float,
		water: bool) -> void:
	if _only != "" and not id.contains(_only):
		return
	_level.choose_time(when)
	var eye_world: Vector3 = site + eye_at
	var aim: Vector3 = site + look_at
	for i in range(SETTLE):
		await get_tree().process_frame
		_level.observer.look_from(eye_world, aim)
		(_level.observer as Camera3D).fov = fov
	var eye: Camera3D = get_viewport().get_camera_3d()
	check("%s_was_drawn_with_the_watching_camera" % id, eye == _level.observer,
		"drew with %s" % [eye.name if eye != null else "nothing"])
	if eye == null:
		return
	_stamp.text = "%s  |  %s  |  %s  |  eye %.0f m up, %.0f m off, %s" % [_commit,
		Time.get_datetime_string_from_system(false, true), id, eye.global_position.y - Terrain.SEA_LEVEL,
		eye.global_position.distance_to(aim), String(DaylightTuning.When.keys()[when]).to_lower()]
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if water:
		_water_arrived(id, image)
	var shot: String = "%s/cockpit-fireboat-%s.png" % [_out, id]
	var saved: int = image.save_png(shot)
	check("%s_was_written" % id, saved == OK, "%s -> %s" % [error_string(saved), ProjectSettings.globalize_path(shot)])


## THE STREAM IS ACTUALLY IN THE PICTURE, proved against the SAME FRAME WITHOUT IT.
##
## The first version of this counted pixels that were bright and near-neutral in the finished picture, and passed
## with 25,283 of them on a photograph that contained no water whatever -- the sky, the white deckhouse and the
## smoke are all bright and near-neutral. A check that cannot fail on an empty frame is not a check.
##
## So: the identical camera, once with the monitors shut and once with them running, and count the pixels that got
## PALER. Nothing else in the scene moves between the two, so the difference is the water and only the water. This is
## `modelling_here.md` section 7 -- the before shot is the only evidence that separates "the data changed" from "the
## drawing changed", and it costs one extra frame.
func _water_arrived(id: String, image: Image) -> void:
	if _reference == null:
		check("%s_has_a_before_frame_to_compare" % id, false, "none captured")
		return
	if _reference.get_width() != image.get_width() or _reference.get_height() != image.get_height():
		check("%s_has_a_before_frame_to_compare" % id, false, "the two frames are different sizes")
		return
	var stamp: Rect2i = BuildStamp.pixels()
	var paler: int = 0
	var looked: int = 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			if stamp.has_point(Vector2i(x, y)):
				continue
			looked += 1
			var was: Color = _reference.get_pixel(x, y)
			var now: Color = image.get_pixel(x, y)
			# PALER, and by enough that the sea's own moving glitter does not count. Water laid over anything in
			# this scene -- grey rig, dark sea, orange flame, black smoke -- lifts every channel.
			if now.r - was.r > 0.10 and now.g - was.g > 0.10 and now.b - was.b > 0.10:
				paler += 1
	check("%s_water_arrived" % id, paler > 600,
		"%d of %d sampled pixels got paler when the monitors opened" % [paler, looked])

## AN ORTHOGRAPHIC SIDE ELEVATION AT A STATED SCALE, for laying over the reference photograph.
##
## THIS IS THE ONLY CHECK THAT CAN CATCH A WRONG STATION, and `learnings/2026-09-20-harriershape.md` is why it is
## here. That lane put the Harrier's intake bells ROUND THE NOSE, ahead of the windscreen, and every published figure
## still held -- because **not one published figure on its sheet was a station**. They were lengths, spans, heights,
## tracks and angles, and a component can slide anywhere along a body without disturbing any of them.
##
## This boat has exactly the same exposure and a bigger number on it. Her length, beam, draught, tonnage and speed
## are published and all five are satisfied wherever her deckhouse sits. Her widths and heights are good to about a
## pixel; her POSITIONS ALONG THE HULL are the soft measurement, at about 5 per cent, and nothing in `tests/fireboat.gd`
## can see them. So the profile is rendered at a KNOWN px/m and `craft/fireboat/overlay.py` lays it on the photograph
## at the same scale. A reader can dispute that picture; nobody can dispute "it looks right".
##
## ORTHOGRAPHIC, NOT A LONG LENS. A perspective view has a different scale at every station, which is the whole fault
## being looked for, so a check for it must not contain one.
func _orthographic_profile(site: Vector3) -> void:
	var boat: Vector3 = (Sim.current.get(_boat, {}) as Dictionary).get("position", site + STAND_OFF)
	# A CAMERA OF ITS OWN, AND THE OBSERVER SWITCHED OFF, because the observer will not stay orthographic.
	#
	# The first version set `projection` and `size` on `_level.observer` every frame of the settle and the picture
	# came back PERSPECTIVE, with a horizon in it and the boat a fifth of the size the scale said. The observer
	# writes its own projection in its own `_process`, after this one, every frame. `modelling_here.md` section 7
	# already records the family this belongs to -- a level takes the view off your shot camera -- and the cure it
	# gives is the cure here: own the camera, switch the others off, and ASK THE VIEWPORT which one it drew with
	# rather than trusting `is_current`, which is the tautology.
	var eye := Camera3D.new()
	eye.name = "Elevation"
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	eye.size = ORTHO_METRES
	eye.far = 4000.0
	add_child(eye)
	(_level.observer as Camera3D).current = false
	eye.current = true
	# FROM HER PORT BEAM, which is the side the reference photograph shows. Worked out from her heading rather than
	# typed, so moving her cannot silently turn this into a three-quarter view -- the very thing it rules out.
	var abeam: Vector3 = Vector3(cos(HEADING), 0.0, -sin(HEADING))
	var middle: Vector3 = boat + Vector3(0.0, 6.0, 0.0)
	for i in range(SETTLE):
		await get_tree().process_frame
		eye.look_at_from_position(middle + abeam * 600.0, middle, Vector3.UP)
		eye.projection = Camera3D.PROJECTION_ORTHOGONAL
		eye.size = ORTHO_METRES
		eye.current = true
	var drew: Camera3D = get_viewport().get_camera_3d()
	check("05-orthographic-port-elevation_was_drawn_with_its_own_camera", drew == eye,
		"drew with %s, orthogonal %s" % [drew.name if drew != null else "nothing",
			drew != null and drew.projection == Camera3D.PROJECTION_ORTHOGONAL])
	var frame: Vector2 = get_viewport().get_visible_rect().size
	# THE SCALE IS STATED, and stated in the FILENAME as `modelling_here.md` section 7 requires: an overlay whose
	# scale lives only in somebody's head cannot be laid on anything.
	var px_per_m: float = frame.y / ORTHO_METRES
	_stamp.text = "%s  |  %s  |  orthographic port elevation  |  %.3f px/m  |  %.1f m across the frame" % [
		_commit, Time.get_datetime_string_from_system(false, true), px_per_m, ORTHO_METRES * frame.x / frame.y]
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var shot: String = "%s/cockpit-fireboat-05-orthographic-port-elevation-%.2fpxm.png" % [_out, px_per_m]
	var saved: int = image.save_png(shot)
	check("05-orthographic-port-elevation_was_written", saved == OK,
		"%.3f px/m -> %s" % [px_per_m, ProjectSettings.globalize_path(shot)])
	# AND SHE IS DRAWN AT THE SCALE THE FILENAME CLAIMS -- MEASURED IN THE PICTURE, NOT COMPUTED.
	#
	# THE FIRST VERSION OF THIS CHECK WAS A TAUTOLOGY AND IT PASSED OVER A WRONG PICTURE. It read
	# `LENGTH_M * px_per_m` and compared that to the frame width -- 42.672 x 36 = 1,536 px against 1,600 -- which is
	# arithmetic on two numbers this file already knew and says nothing whatever about what was rendered. The boat
	# in that frame was about 150 px long. An overlay is worthless if its stated scale is not the drawn scale, so
	# the one thing this check must do is read the DRAWN boat, and the only version that was wrong was the one that
	# did not. It is `testing_godot_headless.md`'s tautology trap in the middle of a lane that has been writing
	# about it all night.
	# Her red hull against sea and sky, by the same ratio test that measures the reference photograph.
	var least: int = frame.x as int
	var most: int = 0
	for x in range(0, image.get_width(), 2):
		for y in range(0, image.get_height(), 2):
			var c: Color = image.get_pixel(x, y)
			if c.r > 0.07 and c.r > c.g * 1.5 and c.r > c.b * 1.4:
				least = mini(least, x)
				most = maxi(most, x)
	var drawn_px: int = most - least
	var drawn_scale: float = float(drawn_px) / LENGTH_M
	check("and_she_is_drawn_at_the_scale_the_filename_claims",
		drawn_px > 0 and absf(drawn_scale - px_per_m) < px_per_m * 0.06,
		"%d px of red hull for a published %.2f m = %.1f px/m drawn, against %.1f px/m claimed"
		% [drawn_px, LENGTH_M, drawn_scale, px_per_m])
	eye.current = false
	(_level.observer as Camera3D).current = true
	eye.queue_free()


## SETTLE THE CAMERA SOMEWHERE AND HAND BACK WHAT IT SEES, without writing a file. The before frame.
func _grab_at(site: Vector3, eye_at: Vector3, look_at: Vector3, fov: float) -> Image:
	var eye_world: Vector3 = site + eye_at
	var aim: Vector3 = site + look_at
	for i in range(SETTLE):
		await get_tree().process_frame
		_level.observer.look_from(eye_world, aim)
		(_level.observer as Camera3D).fov = fov
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _quieten() -> void:
	var ui: Node = _level.get_node_or_null("Ui")
	if ui != null:
		ui.set("visible", false)
	for label in _level.observer.find_children("*", "Label", true, false):
		(label as Label).visible = false
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_stamp = Label.new()
	_stamp.position = Vector2(12.0, 8.0)
	_stamp.add_theme_font_size_override("font_size", 18)
	_stamp.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_stamp.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_stamp.add_theme_constant_override("outline_size", 5)
	layer.add_child(_stamp)


## `<short commit>[+dirty]`, read from git beside the project, so a stale picture says so.
func _commit_stamp() -> String:
	var project: String = ProjectSettings.globalize_path("res://")
	var out: Array = []
	OS.execute("git", ["-C", project, "rev-parse", "--short", "HEAD"], out)
	var hash: String = String(out[0]).strip_edges() if not out.is_empty() else "?"
	var status: Array = []
	OS.execute("git", ["-C", project, "status", "--porcelain"], status)
	var dirty: bool = not status.is_empty() and String(status[0]).strip_edges() != ""
	return hash + ("+dirty" if dirty else "")


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
