extends Node3D
## Windowed visual evidence for the F-14D's STICK-DRIVEN SURFACES -- spoilers, stabilators, rudders -- and for the VAT
## that plays them, BY PIXELS.
##
##   Godot --path cockpit res://tests/tomcat_surfaces_shot.tscn -- --out=<folder>
##
## NOT HEADLESS. `tests/tomcat.gd` holds what can be asserted of the surfaces: one axis at a time, from a real wire,
## riding the wing, clear of every other part, and the VAT against the parts by worst vertex. This renders what it cannot
## see: whether the surfaces READ at a glance, and whether the shader draws them where the parts are, pixel for pixel.
##
## THE SURFACES ARE MOVED THROUGH `follow_the_stick`, the view's own call, so the pictures show the F-14's mixing and its
## lockouts, not a pose typed per surface. The VAT comparisons set each feature's amount directly, one feature alone and
## then all at once with the wing swept, because a swapped table reads right when every axis moves together.

## THE SWEEPS the lit pictures are taken at [PUB]: forward, the one between, full, overswept.
const SWEEPS: Array[float] = [20.0, 44.0, 68.0, 75.0]
## A PIXEL DIFFERS if any channel is more than 2 of 255 out; a comparison FAILS past one in a thousand of the
## aeroplane's own pixels (`tomcat_shot.gd`'s threshold, from `vat`'s 1 of 112,510 on the Cessna).
const CHANNEL_SLACK: float = 2.0 / 255.0
const MOST_DIFFERING: float = 0.001

var out := ""
var failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	var stamp := _stamp()
	# THE SWEEP, lit, from high on the starboard quarter: the planform and the glove.
	for sweep in SWEEPS:
		await _lit("tomcat2-sweep-%02d.png" % int(sweep), "wing at %.0f degrees" % sweep, sweep, Vector2.ZERO, 0.0,
			[Vector3(14.0, 13.0, -12.0), Vector3(0.0, 2.3, 2.0)], stamp)
	# THE SURFACES, lit and close, each from where it reads: the spoilers from high behind the port quarter, over both
	# wings' tops; the tailplanes from low on the beam, where a tailplane's angle is a profile; the rudders from high
	# behind, down the fins. One camera for all of them was tried first: the tail and the rudders did not read.
	var behind := [Vector3(-12.0, 8.5, 18.0), Vector3(0.0, 2.3, 2.0)]
	var beam := [Vector3(-17.0, 2.2, 10.0), Vector3(0.0, 1.9, 6.5)]
	var astern := [Vector3(-2.5, 9.0, 24.0), Vector3(0.0, 3.4, 7.5)]
	for pose in [["roll-right", "stick hard right: starboard spoilers up, tailplanes apart", Vector2(1, 0), 0.0, behind],
			["roll-left", "stick hard left: port spoilers up, tailplanes apart", Vector2(-1, 0), 0.0, behind],
			["pitch-up", "stick back: both tailplanes trailing edge up", Vector2(0, 1), 0.0, beam],
			["pitch-down", "stick forward: both tailplanes trailing edge down", Vector2(0, -1), 0.0, beam],
			["pitch-neutral", "stick centred", Vector2.ZERO, 0.0, beam],
			["rudder-right", "right pedal: both rudders to starboard", Vector2.ZERO, 1.0, astern],
			["rudder-left", "left pedal: both rudders to port", Vector2.ZERO, -1.0, astern],
			["neutral", "stick and pedals centred", Vector2.ZERO, 0.0, behind]]:
		await _lit("tomcat2-surfaces-%s.png" % pose[0], pose[1], 20.0, pose[2], pose[3], pose[4], stamp)
	# THE SPOILERS ON A SWEPT WING, and past the lockout.
	await _lit("tomcat2-surfaces-roll-right-at-44.png", "stick hard right at 44 degrees: the spoilers ride the wing", 44.0,
		Vector2(1, 0), 0.0, behind, stamp)
	await _lit("tomcat2-surfaces-roll-right-at-68.png", "stick hard right at 68 degrees: spoilers locked down, tail rolls it",
		68.0, Vector2(1, 0), 0.0, behind, stamp)
	# THE VAT AGAINST THE PARTS: [sweep, spoilers, pitch, roll, rudder], each feature alone and off the grid, then all.
	for pose in [[20.0, 0.83, 0.0, 0.0, 0.0], [20.0, 0.0, -0.61, 0.0, 0.0], [20.0, 0.0, 0.0, 0.77, 0.0],
			[20.0, 0.0, 0.0, 0.0, -0.9], [44.29, -0.93, 0.52, -0.87, 0.41], [54.83, 1.0, 1.0, 1.0, 1.0],
			[67.53, 0.0, -1.0, 1.0, 0.0]]:
		await _vat_against_parts(pose)
	print("[tomcat_surfaces_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
	get_tree().quit(0 if failures.is_empty() else 1)


## THE COMMIT AND WHETHER THE TREE WAS DIRTY, burned into every lit picture (`modelling_here.md` section 7).
func _stamp() -> String:
	var head: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], head)
	var status: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain"], status)
	var dirty: bool = not String(status[0] if not status.is_empty() else "").strip_edges().is_empty()
	return "%s%s, %s" % [String(head[0] if not head.is_empty() else "?").strip_edges(), "+dirty" if dirty else "",
		Time.get_datetime_string_from_system(false, true)]


func _stage(size: Vector2i) -> SubViewport:
	var stage := SubViewport.new()
	stage.size = size
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# ITS OWN WORLD, or every stage here shares one scene and each WorldEnvironment fights the others (`lane/prowler`).
	stage.own_world_3d = true
	add_child(stage)
	# THE BUILD STAMP IN THE LOWER RIGHT, as in every picture the game takes (`BuildStamp`, 2026-09-18): this stage is a
	# viewport of its own, which the root's stamp is not drawn into.
	BuildStamp.attach_to(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.24, 0.28, 0.33)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which defaults to BLACK.
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 0.85
	environment.environment = env
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.85, -0.55, 0.0)
	light.light_energy = 1.5
	stage.add_child(light)
	return stage


## LIT, on a ground plane at the tyres, from a stated eye, captioned with what is being shown and the stamp.
## iew is [eye, the point looked at], in the airframe's frame with heights over the ground.
func _lit(filename: String, said: String, sweep: float, stick: Vector2, rudder: float, view: Array, stamp: String) -> void:
	var stage := _stage(Vector2i(1600, 900))
	(stage.find_children("*", "DirectionalLight3D", false, false)[0] as DirectionalLight3D).shadow_enabled = true
	var frame := TomcatAirframe.new()
	frame.dress()
	frame.set_sweep(sweep)
	frame.follow_the_stick(stick, rudder)
	stage.add_child(frame)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	ground.mesh = plane
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.36, 0.37, 0.36)
	ground.material_override = paint
	ground.position = Vector3(0.0, frame.height(0.0), 0.0)
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 38
	camera.current = true
	stage.add_child(camera)
	var eye: Vector3 = view[0]
	var at: Vector3 = view[1]
	camera.global_position = eye
	camera.look_at(Vector3(at.x, frame.height(at.y), at.z), Vector3.UP)
	var caption := Label.new()
	caption.text = "F-14D, %s   |   %s" % [said, stamp]
	caption.position = Vector2(16, 12)
	caption.add_theme_font_size_override("font_size", 26)
	stage.add_child(caption)
	await _save(stage, filename)


func _save(stage: SubViewport, filename: String) -> void:
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[tomcat_surfaces_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()


## THE SURFACES THROUGH THE VAT, AGAINST THE PARTS, BY PIXELS. Two stages lit and framed alike from high behind: one
## airframe drawn as its parts, one poured into a `VatCasting` and played by the shader, each handed the same amounts.
## Saved as one picture, PARTS | VAT | THE DIFFERENCE in magenta, so a reader sees both and what separates them.
func _vat_against_parts(pose: Array) -> void:
	var pictures: Array[Image] = []
	var stamp := Rect2i()
	for casting in [false, true]:
		var stage := _stage(Vector2i(1000, 700))
		var frame := TomcatAirframe.new()
		frame.dress()
		stage.add_child(frame)
		var vat: VatCasting = null
		if casting:
			vat = await VatCasting.pour(frame, frame.features())
			vat.set_process(false)
		frame.set_sweep(pose[0])
		frame.set_spoilers(pose[1])
		frame.set_stabilators(pose[2], pose[3])
		frame.set_rudders(pose[4])
		if vat != null:
			vat.play()
		var camera := Camera3D.new()
		camera.fov = 40
		camera.current = true
		stage.add_child(camera)
		camera.global_position = Vector3(-8.0, 13.0, 17.0)
		camera.look_at(Vector3(0.0, frame.height(2.2), 2.5), Vector3.UP)
		for i in range(4):
			await RenderingServer.frame_post_draw
		pictures.append(stage.get_texture().get_image())
		stamp = BuildStamp.pixels_in(stage)
		stage.queue_free()
	var background := pictures[0].get_pixel(0, 0)
	var aeroplane: int = 0
	var differ: int = 0
	var marked := pictures[1].duplicate() as Image
	for y in range(pictures[0].get_height()):
		for x in range(pictures[0].get_width()):
			# NOT THE BUILD STAMP: its letters are not the background, so they would count as aeroplane.
			if stamp.has_point(Vector2i(x, y)):
				continue
			var a: Color = pictures[0].get_pixel(x, y)
			var b: Color = pictures[1].get_pixel(x, y)
			if not (a.is_equal_approx(background) and b.is_equal_approx(background)):
				aeroplane += 1
			if absf(a.r - b.r) > CHANNEL_SLACK or absf(a.g - b.g) > CHANNEL_SLACK or absf(a.b - b.b) > CHANNEL_SLACK:
				differ += 1
				marked.set_pixel(x, y, Color(1.0, 0.0, 1.0))
	var w: int = pictures[0].get_width()
	var h: int = pictures[0].get_height()
	var sheet := Image.create_empty(w * 3, h, false, pictures[0].get_format())
	sheet.blit_rect(pictures[0], Rect2i(0, 0, w, h), Vector2i(0, 0))
	sheet.blit_rect(pictures[1], Rect2i(0, 0, w, h), Vector2i(w, 0))
	marked.convert(pictures[0].get_format())
	sheet.blit_rect(marked, Rect2i(0, 0, w, h), Vector2i(w * 2, 0))
	var name := "tomcat2-vat-against-parts-sweep-%05.2f-spoilers%+.2f-pitch%+.2f-roll%+.2f-rudder%+.2f.png" % pose
	sheet.save_png(out.path_join(name))
	var ok: bool = aeroplane > 10000 and float(differ) <= float(aeroplane) * MOST_DIFFERING
	if not ok:
		failures.append(name)
	print("[tomcat_surfaces_shot] vat against parts at %s: %d of %d aeroplane pixels differ (%s); parts | vat | magenta difference in %s"
		% [pose, differ, aeroplane, "PASS" if ok else "FAIL", name])
