extends Node
## SPOTTING SIZE, PHOTOGRAPHED FROM INSIDE THE GAME: a fighter at 1, 2, 3, 5 and 10 km in one headset eye, off and at
## each strength, and a reel of one flying in from 8 km past the eye.
##
##   Godot --path cockpit res://tests/spotting_shot.tscn -- --level=watch --out=C:/somewhere
##   Godot --path cockpit --resolution 1280x720 --fixed-fps 30 --write-movie C:/somewhere/reel.avi \
##       res://tests/spotting_shot.tscn -- --level=watch --reel=high --out=C:/somewhere
##
## NOT HEADLESS -- it renders. Every picture is the game's own: the eye is a SubViewport in the level, never the desktop.
##
## THE EYE IS A HEADSET'S RENDER TARGET. The headset is a Quest 3 (user, 2026-09-19), 2064 x 2208 panel pixels an eye;
## `PilotRig.RENDER_SCALE` (1.4) on that is 2890 x 3091, drawn 96 degrees tall -- about 24.3 px a degree at the middle,
## which is within a few per cent of the ~25 panel pixels a degree a Quest 3's lens puts at the middle of the view. So a
## pixel counted here near the middle is about a panel pixel there; averaged over the field the panel has ~17.3 a degree,
## 0.71 of these. agents.md, "Spotting size, on the iPad", gives all three. The observer stands at the same place, so the
## mist and the level's per-camera work are for this eye.
##
## WHAT IS REAL AND WHAT IS PLACED. The level, the sky, the light, the finish and the fighter's own `VehicleView` are the
## shipping ones. The fighters are views put in the air by hand (`setup` on entity 0), as `tests/lamp_beam_shot.gd` hangs
## its lamp, and are drawn through the spectacles by `Spectacles.magnify` -- the one function the level's pass calls --
## because a watch level has no rig, and a rig's eye is not a camera a probe can stand where it likes. Which craft the
## level magnifies, and that nothing else changes, is `tests/spotting.gd`'s.
##
## WHAT IT WRITES to `--out`:
##   cockpit-spotting-eye-<strength>.png       the whole eye, all five fighters
##   cockpit-spotting-grid.png                  each fighter cropped from the eye at every strength, 4x nearest-neighbour
##   and a line per fighter per strength: its distance, its scale, and how many pixels of the eye it changed.
## With `--reel=<strength>`: a fighter flying in from 8 km at 200 m/s to pass 150 m abeam, the eye turning to keep it in
## the middle, drawn at 24 pixels a degree like the eye above, with its distance, scale and drawn length written on it.

const WARM: int = 240
const SETTLE: int = 12
## THE EYE: pixels, and degrees tall. See the note at the top.
const EYE_SIZE := Vector2i(2890, 3091)
const EYE_FOV: float = 96.0
## Where the fighters are, metres from the eye, and how far each is turned off the middle, degrees.
const DISTANCES: Array[float] = [1000.0, 2000.0, 3000.0, 5000.0, 10000.0]
const BEARINGS: Array[float] = [-24.0, -12.0, 0.0, 12.0, 24.0]
## How high over the eye each is, as an angle: a little over the horizon, so each is against the sky.
const ELEVATION: float = 3.0
## THE WAY EACH FIGHTER IS TURNED against the line of sight: 45 degrees off it, a three-quarter view.
const ASPECT: float = 45.0
## How big a crop of the eye is round each fighter, pixels, and how much it is enlarged in the grid.
const CROP: int = 96
const ENLARGE: int = 4
## The eye's height over the runway, metres.
const HIGH: float = 400.0
## THE REEL: where the fighter starts, how fast it comes, how far abeam and above it passes, and for how long.
const REEL_FROM: float = 8000.0
const REEL_SPEED: float = 200.0
const REEL_ABEAM: float = 150.0
const REEL_ABOVE: float = 40.0
const REEL_SECONDS: float = 42.0
## THE REEL'S PIXELS A DEGREE, to match the eye's middle: the window's height over this is the camera's field.
const REEL_PIXELS_A_DEGREE: float = 24.2

var _level: FlightLevel = null
var _out: String = ""
var _reel: String = ""
var _eye: Vector3 = Vector3.ZERO
var _ahead: Vector3 = Vector3.FORWARD
var _fighters: Array[VehicleView] = []
var _poses: Array[Transform3D] = []
var _glasses: Spectacles = Spectacles.new()
## `--no-lod-stretch`: every part's distance-LOD range put back after magnifying, so the picture is what the LOD would do
## by TRUE distance -- the magnified craft with its small parts gone. For showing the fix beside the fault; the files are
## named `-true-lod`.
var _stretch: bool = true
## `--kind=<name>`: what is photographed, the fighter unless asked. The tanker is the one to show the LOD on: the fighter's
## own detail parts go at 600 m and are never brought back by a scale, where the tanker's 5 m parts come back to 6.5 km.
var _kind: int = Sim.Kind.FIGHTER
var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[spotting_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	process_priority = 1000
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--kind="):
			_kind = Sim.Kind.keys().find(argument.trim_prefix("--kind=").to_upper())
			if _kind < 0:
				_kind = Sim.Kind.FIGHTER
		elif argument == "--no-lod-stretch":
			_stretch = false
		elif argument.begins_with("--reel="):
			_reel = argument.trim_prefix("--reel=").to_upper()
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("user://spotting_shot")
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	print("[spotting_shot] %s, %s precision, %s on %s" % [Engine.get_version_info()["string"],
		"double" if OS.has_feature("double") else "single", RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name()])
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=watch after the bare --")
		_finish()
		return
	for i in range(WARM):
		await get_tree().process_frame
	_level.call("choose_time", DaylightTuning.When.DAY)
	var runway: Dictionary = Terrain.runways()[0]
	var bearing: float = float(runway["bearing"])
	_ahead = Vector3(-sin(bearing), 0.0, -cos(bearing))
	_eye = (runway["centre"] as Vector3) + Vector3(0.0, HIGH, 0.0)
	if _reel != "":
		await _the_reel()
	else:
		await _the_eye()
	_finish()


## ---- one eye, five fighters -------------------------------------------------------------------------------------

func _a_fighter() -> VehicleView:
	var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
	_level.add_child(view)
	view.setup(0, _kind)
	return view


func _the_eye() -> void:
	for i in range(DISTANCES.size()):
		var toward: Vector3 = _ahead.rotated(Vector3.UP, deg_to_rad(BEARINGS[i]))
		var up: float = tan(deg_to_rad(ELEVATION)) * DISTANCES[i]
		var at: Vector3 = _eye + toward * DISTANCES[i] + Vector3(0.0, up, 0.0)
		var heading: Vector3 = toward.rotated(Vector3.UP, deg_to_rad(90.0 + ASPECT))
		_poses.append(Transform3D(Basis.looking_at(heading, Vector3.UP), at))
		_fighters.append(_a_fighter())
	var screen := SubViewport.new()
	screen.size = EYE_SIZE
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_level.add_child(screen)
	var camera := Camera3D.new()
	camera.fov = EYE_FOV
	camera.far = 60000.0
	screen.add_child(camera)
	camera.current = true
	camera.global_transform = Transform3D(Basis.looking_at(_ahead, Vector3.UP), _eye)
	_level.observer.look_from(_eye, _eye + _ahead)
	var size: float = Spectacles.size_of(_kind)
	# THE SKY WITH NO FIGHTER IN IT, so a fighter's pixels are the ones it changed.
	var empty: Image = await _shoot(screen, -1)
	var shots: Dictionary = {}
	for which in range(Spectacles.STRENGTH_WORDS.size()):
		shots[which] = await _shoot(screen, which)
		var named: String = Spectacles.STRENGTH_WORDS[which].to_lower()
		(shots[which] as Image).save_png(_out.path_join("cockpit-spotting-eye-%s%s%s.png" % [named,
			"" if _stretch else "-true-lod", "" if _kind == Sim.Kind.FIGHTER else "-" + Sim.kind_name(_kind)]))
	var rows: Array = []
	for i in range(DISTANCES.size()):
		var at: Vector2 = camera.unproject_position(_poses[i].origin)
		var row: Array = []
		for which in range(Spectacles.STRENGTH_WORDS.size()):
			var times: float = Spectacles.scale_for(camera.global_position.distance_to(_poses[i].origin), size, which,
				Spectacles.DEFAULT_NEAR)
			var changed: int = _changed(shots[which], empty, at)
			var length_px: float = times * size / DISTANCES[i] * float(EYE_SIZE.y) / (2.0 * tan(deg_to_rad(EYE_FOV / 2.0)))
			print("[spotting_shot] measure: %d m %s x%.2f, %d px changed, %.1f px long" % [int(DISTANCES[i]),
				Spectacles.STRENGTH_WORDS[which], times, changed, length_px])
			row.append({"at": at, "changed": changed, "times": times})
		rows.append(row)
	_write_the_grid(shots, rows)
	_check("a_fighter_at_10_km_is_more_pixels_on_high_than_off",
		int(rows[4][3]["changed"]) > int(rows[4][0]["changed"]) * 3,
		"%d against %d" % [rows[4][3]["changed"], rows[4][0]["changed"]])
	_check("and_at_1_km_on_high_it_is_about_as_it_was", absf(float(rows[0][3]["times"]) - 1.0) < 0.1,
		"x%.2f" % rows[0][3]["times"])
	screen.queue_free()


## DRAW THE EYE with the fighters through `which` strength, or with no fighters at -1.
func _shoot(screen: SubViewport, which: int) -> Image:
	_glasses.strength = maxi(which, 0)
	for i in range(SETTLE):
		_place_the_fighters(which >= 0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return screen.get_texture().get_image()


func _place_the_fighters(shown: bool) -> void:
	for i in range(_fighters.size()):
		_fighters[i].visible = shown
		_fighters[i].transform = _poses[i]
		_glasses.magnify(_fighters[i], _kind, _eye, {"velocity": Vector3.FORWARD * 200.0})
	if not _stretch:
		Spectacles.put_back_every_part()


## HOW MANY PIXELS OF A CROP ROUND `at` differ from the empty sky by more than 3 in 255 on any channel.
func _changed(shot: Image, empty: Image, at: Vector2) -> int:
	var count: int = 0
	for y in range(int(at.y) - CROP, int(at.y) + CROP):
		for x in range(int(at.x) - CROP, int(at.x) + CROP):
			if x < 0 or y < 0 or x >= shot.get_width() or y >= shot.get_height():
				continue
			var a: Color = shot.get_pixel(x, y)
			var b: Color = empty.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 3.0 / 255.0:
				count += 1
	return count


## EACH FIGHTER'S CROP AT EACH STRENGTH, enlarged with no smoothing, in a grid: a row a fighter, a column a strength. The
## labels are the composer's (`tools` side); this writes the pixels and a JSON of what each cell is.
func _write_the_grid(shots: Dictionary, rows: Array) -> void:
	var cell: int = CROP * ENLARGE
	var grid := Image.create(cell * Spectacles.STRENGTH_WORDS.size(), cell * DISTANCES.size(), false, Image.FORMAT_RGB8)
	var cells: Array = []
	for i in range(DISTANCES.size()):
		for which in range(Spectacles.STRENGTH_WORDS.size()):
			var at: Vector2 = rows[i][which]["at"]
			var crop: Image = (shots[which] as Image).get_region(Rect2i(int(at.x) - CROP / 2, int(at.y) - CROP / 2, CROP,
				CROP))
			crop.convert(Image.FORMAT_RGB8)
			crop.resize(cell, cell, Image.INTERPOLATE_NEAREST)
			grid.blit_rect(crop, Rect2i(0, 0, cell, cell), Vector2i(which * cell, i * cell))
			cells.append({"row": i, "column": which, "metres": DISTANCES[i], "strength": Spectacles.STRENGTH_WORDS[which],
				"times": rows[i][which]["times"], "changed_px": rows[i][which]["changed"]})
	grid.save_png(_out.path_join("cockpit-spotting-grid.png"))
	var file := FileAccess.open(_out.path_join("cockpit-spotting-grid.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"crop_px": CROP, "enlarged": ENLARGE, "eye": [EYE_SIZE.x, EYE_SIZE.y],
		"eye_fov_degrees": EYE_FOV, "cells": cells}, "\t"))


## ---- the reel -------------------------------------------------------------------------------------------------------

func _the_reel() -> void:
	var named: int = Spectacles.STRENGTH_WORDS.find(_reel)
	_glasses.strength = maxi(named, 0)
	var fighter: VehicleView = _a_fighter()
	# AN EYE OF ITS OWN, as the stills have: a SubViewport the window's size with a camera turned by this, laid over the
	# whole window, which is what the movie records. The first three reels turned the level's observer, and the window
	# went on drawing the scenery from wherever the level had put it.
	var window: Vector2i = Vector2i(get_viewport().get_visible_rect().size)
	var screen := SubViewport.new()
	screen.size = window
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_level.add_child(screen)
	BuildStamp.attach_to(screen)
	var camera := Camera3D.new()
	camera.far = 60000.0
	screen.add_child(camera)
	camera.current = true
	camera.fov = float(window.y) / REEL_PIXELS_A_DEGREE
	var picture := TextureRect.new()
	picture.texture = screen.get_texture()
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	var words := Label.new()
	words.add_theme_font_size_override("font_size", 22)
	words.add_theme_color_override("font_color", Color(1, 1, 1))
	words.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	words.add_theme_constant_override("outline_size", 6)
	words.position = Vector2(16, 64)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(picture)
	layer.add_child(words)
	add_child(layer)
	var across: Vector3 = _ahead.cross(Vector3.UP).normalized()
	var start: Vector3 = _eye + _ahead * REEL_FROM + across * REEL_ABEAM + Vector3(0.0, REEL_ABOVE, 0.0)
	var heading: Vector3 = -_ahead
	var size: float = Spectacles.size_of(_kind)
	# THIRTY A SECOND, as the movie is written (`--fixed-fps 30`): each frame is a thirtieth of a second of flight.
	var fps: float = 30.0
	var frames: int = int(REEL_SECONDS * fps)
	var lines: PackedStringArray = ["seconds,metres,times,looks_px"]
	# THE FRAME THE REEL STARTS ON, so the movie can be cut to it: everything before is the level warming up.
	print("[spotting_shot] reel starts at drawn frame %d" % Engine.get_frames_drawn())
	for frame in range(frames):
		var t: float = float(frame) / fps
		var at: Vector3 = start + heading * REEL_SPEED * t
		fighter.transform = Transform3D(Basis.looking_at(heading, Vector3.UP), at)
		var times: float = _glasses.magnify(fighter, _kind, _eye, {"velocity": heading * REEL_SPEED})
		camera.global_transform = Transform3D(Basis.looking_at(at - _eye, Vector3.UP), _eye)
		var away: float = _eye.distance_to(at)
		_level.observer.look_from(_eye, at)
		var looks: float = times * size / away * float(window.y) \
			/ (2.0 * tan(deg_to_rad(camera.fov / 2.0)))
		words.text = "SPOTTING SIZE %s   %.2f km   drawn x%.2f   looks %.0f px long" % [
			Spectacles.STRENGTH_WORDS[_glasses.strength], away / 1000.0, times, looks]
		lines.append("%.3f,%.1f,%.4f,%.2f" % [t, away, times, looks])
		await get_tree().process_frame
	var file := FileAccess.open(_out.path_join("cockpit-spotting-reel-%s.csv" % _reel.to_lower()), FileAccess.WRITE)
	file.store_string("\n".join(lines))


func _finish() -> void:
	if _failures.is_empty():
		print("[spotting_shot] RESULT=PASS")
	else:
		print("[spotting_shot] RESULT=FAIL %s" % ", ".join(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)
