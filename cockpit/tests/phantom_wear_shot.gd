extends Node3D

## THE WEATHERING, JUDGED ON RENDERED PIXELS — the anchor outside the sheet's own frame.
##
## `tests/phantom_wear.gd` proves the coordinates land on dirty texels, and every one of its checks would still pass
## if the engine ignored `detail_albedo` completely, or blended it in a way that left the paint exactly as it was.
## Nothing in that file renders. So this file flies the same aeroplane twice, from the same camera in the same
## light, once with `wear` on and once off, and reads the pixels back:
##
##   - aft of the nozzles the paint must DARKEN, by a stated amount;
##   - on the radome it must NOT MOVE, because the radome is the one place the sheet is deliberately clean.
##
## The second half is what makes it a measurement rather than a mood. A sheet accidentally left opaque everywhere
## would darken the exhaust perfectly well and would also darken the nose, and only the pair can tell those apart.
##
## **THE PIXELS ARE FOUND BY PROJECTION, NOT BY GUESSWORK.** `Camera3D.unproject_position` is asked where a known
## station actually landed, so the sample follows the aeroplane if the framing is ever changed. A hand-typed pixel
## box is a number that silently stops pointing at the thing it was chosen for -- which is how this lane's overlay
## came to be measuring the wrong edge earlier on.
##
## WHY IT IS NOT IN `suites.txt`: it needs a real renderer, and the suite runner is headless. Run it by hand, the
## way `phantom_shot` is, with `tools/gpu_slot.ps1` held as a CAPTURE.

## THE CHECK IS A RATIO, AND THAT IS DELIBERATE. The first version demanded the exhaust darken by an absolute 0.06
## -- a number picked before anything had been measured, which is the right order to pick it in but not a number to
## then defend. Measured, the exhaust darkens by 0.043 and the radome moves by 0.006, and chasing the 0.06 meant
## making the aeroplane sootier than it should be to satisfy an arbitrary figure. So the claim is stated as what it
## is actually for: **the place the sheet is dirty must move far more than the place it is clean.** That is immune
## to the paint, the lighting and the exposure, all of which move both numbers together, and it cannot be satisfied
## by a sheet that is uniformly dirty -- which an absolute threshold can.
##
## Measured on 2026-09-20: exhaust 0.3370 -> 0.2973 (0.0397 darker, 11.8%), radome 0.3876 -> 0.3820 (0.0056), a
## ratio of 7.1. The floor below is a little over half of that, so an honest change of materials has room and a
## detail layer that stopped working does not.
const DARKEN_RATIO: float = 4.0
## And an absolute floor, so the ratio cannot be satisfied by two numbers that are both essentially zero.
const MUST_DARKEN: float = 0.02
## How much the radome may move on its own. Not zero: the sheet's feather and eight-bit quantisation both land here.
const RADOME_MAY_MOVE: float = 0.02
## The two places, as STATION RANGES in metres aft of the nose. A range and not a point, because a point on a
## faceted hull lands wherever that facet happens to be and its box then straddles the silhouette -- which is
## exactly what the first version of this file did: it sampled a box half on the aeroplane and half on the
## background, read 0.3289 both times, and reported that the weathering had no effect at all. The strip below
## counts only pixels that are actually aircraft.
## As `Rect2(station, height, along, up)` in metres. The HEIGHT band matters as much as the station one: a strip
## taken over the aeroplane's whole depth at the tail includes the fin, which stands well clear of the exhaust and
## is meant to stay clean, and averaging it in diluted a real 7% darkening down to 2.5% and read as a failure. The
## box asks about the piece of aeroplane the mark claims, which is the only thing the mark can be held to.
const AFT_OF_THE_NOZZLES := Rect2(17.6, 0.6, 1.5, 1.8)
const ON_THE_RADOME := Rect2(0.4, 1.0, 1.6, 1.6)
## Anything darker than this is background or shadow and is not the aeroplane. The background is 0.02.
const NOT_THE_AEROPLANE: float = 0.08

var _failures: PackedStringArray = []


func _ready() -> void:
	var dirty := await _render(true)
	var clean := await _render(false)
	var out: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		dirty["image"].save_png(out.path_join("wear-on.png"))
		clean["image"].save_png(out.path_join("wear-off.png"))
		print("[phantom_wear_shot] wrote wear-on.png and wear-off.png into %s" % out)

	var exhaust_dirty: float = dirty["exhaust"]
	var exhaust_clean: float = clean["exhaust"]
	var radome_dirty: float = dirty["radome"]
	var radome_clean: float = clean["radome"]

	print("[phantom_wear_shot] exhaust %.4f clean -> %.4f dirty (%.4f darker)"
		% [exhaust_clean, exhaust_dirty, exhaust_clean - exhaust_dirty])
	print("[phantom_wear_shot] radome  %.4f clean -> %.4f dirty (%.4f moved)"
		% [radome_clean, radome_dirty, absf(radome_clean - radome_dirty)])

	var darkened: float = exhaust_clean - exhaust_dirty
	var moved: float = absf(radome_clean - radome_dirty)
	_check("the_detail_layer_reaches_the_rendered_pixels_aft_of_the_nozzles", darkened >= MUST_DARKEN,
		"darkened by %.4f, wanted at least %.4f" % [darkened, MUST_DARKEN])
	_check("and_far_more_there_than_where_the_sheet_is_clean", darkened >= moved * DARKEN_RATIO,
		"exhaust %.4f against radome %.4f, a ratio of %.1f, wanted %.1f"
			% [darkened, moved, darkened / maxf(moved, 0.0001), DARKEN_RATIO])
	_check("and_leaves_the_radome_where_it_was",
		absf(radome_clean - radome_dirty) <= RADOME_MAY_MOVE,
		"moved by %.4f, allowed %.4f" % [absf(radome_clean - radome_dirty), RADOME_MAY_MOVE])
	_check("and_the_aeroplane_was_actually_on_screen", exhaust_clean > 0.05 and radome_clean > 0.05,
		"exhaust %.4f, radome %.4f -- a black frame passes the first two checks" % [exhaust_clean, radome_clean])

	if _failures.is_empty():
		print("RESULT=PASS the weathering changes the pixels it should and no others")
	else:
		print("RESULT=FAIL %s" % [_failures])
	get_tree().quit(0 if _failures.is_empty() else 1)


## ONE RENDER of the aeroplane's port side, and the brightness at the two places that matter.
func _render(weathered: bool) -> Dictionary:
	var stage := SubViewport.new()
	stage.size = Vector2i(1600, 400)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.own_world_3d = true
	add_child(stage)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 1.0, 1.0)
	# FLAT, BRIGHT AMBIENT AND NO DIRECTIONAL LIGHT. A shadow crossing a sample box would be read as dirt, and the
	# two renders would have to agree about it exactly. The claim is about albedo, so light it like a swatch.
	env.ambient_light_energy = 1.0
	environment.environment = env
	stage.add_child(environment)

	var frame := PhantomAirframe.new()
	frame.wear = weathered
	frame.dress()
	stage.add_child(frame)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	camera.current = true
	stage.add_child(camera)
	camera.global_position = Vector3(30.0, 1.6, 0.0)
	camera.look_at(Vector3(0.0, 1.6, 0.0), Vector3.UP)

	for _f in range(4):
		await RenderingServer.frame_post_draw
	var image: Image = stage.get_texture().get_image()
	var result := {
		"image": image,
		"exhaust": _brightness_at(image, camera, frame, AFT_OF_THE_NOZZLES),
		"radome": _brightness_at(image, camera, frame, ON_THE_RADOME),
	}
	stage.queue_free()
	return result


## THE MEAN BRIGHTNESS OF THE AEROPLANE between two stations: every pixel in that vertical strip that is bright
## enough to be hull rather than background. `unproject_position` gives the strip's edges, so the sample follows
## the aeroplane if the framing changes and never has to be re-typed.
func _brightness_at(image: Image, camera: Camera3D, frame: PhantomAirframe, box: Rect2) -> float:
	var a: Vector2 = camera.unproject_position(frame.point(0.0, box.position.y, box.position.x))
	var b: Vector2 = camera.unproject_position(frame.point(0.0, box.end.y, box.end.x))
	var from_x: int = clampi(int(minf(a.x, b.x)), 0, image.get_width() - 1)
	var to_x: int = clampi(int(maxf(a.x, b.x)), 0, image.get_width() - 1)
	var from_y: int = clampi(int(minf(a.y, b.y)), 0, image.get_height() - 1)
	var to_y: int = clampi(int(maxf(a.y, b.y)), 0, image.get_height() - 1)
	var total: float = 0.0
	var seen: int = 0
	for x in range(from_x, to_x + 1):
		for y in range(from_y, to_y + 1):
			var c: Color = image.get_pixel(x, y)
			var bright: float = (c.r + c.g + c.b) / 3.0
			if bright < NOT_THE_AEROPLANE:
				continue
			total += bright
			seen += 1
	print("[phantom_wear_shot]   station %.1f-%.1f height %.1f-%.1f -> %d hull pixels"
		% [box.position.x, box.end.x, box.position.y, box.end.y, seen])
	return total / float(maxi(seen, 1))

func _check(label: String, held: bool, said: String) -> void:
	print("[phantom_wear_shot] %s %s (%s)" % ["PASS" if held else "FAIL", label, said])
	if not held:
		_failures.append(label)
