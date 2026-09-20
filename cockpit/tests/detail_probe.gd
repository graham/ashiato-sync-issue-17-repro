extends Node3D

## DOES A DETAIL LAYER'S OWN ALPHA MASK IT ON AN OPAQUE MATERIAL, IN THIS ENGINE BUILD?
##
## The weathering design for the Phantom hangs on one unverified claim: that `detail_albedo`'s ALPHA decides where the
## stain lands, on a material whose `transparency` is DISABLED. If that is wrong the whole sheet paints edge to edge
## and a streak cannot be drawn at all. Nothing in this repository uses `detail_*` on any material, so the claim had
## never been run here -- it was read, not measured, and reading is how the fuselage ended up half a metre flat.
##
## SO THIS RENDERS IT AND READS THE PIXELS BACK. Two quads, each a flat blue lit by nothing (`SHADING_MODE_UNSHADED`,
## so a light's falloff cannot be mistaken for a blend), each with a detail layer that is red on its left half and
## nothing on its right:
##
##   A: the alpha is in `detail_albedo` itself -- left (255,0,0,255), right (0,255,0,0), no `detail_mask`.
##   B: `detail_albedo` is opaque red everywhere and a separate `detail_mask` is white left, black right.
##
## Either way the right half must come back BLUE. Red on the right means the layer ignored the alpha; GREEN on the
## right means it took the transparent texel's colour and ignored its alpha, which is the same fault wearing a
## different coat and is worth telling apart. The test is deliberately not "does it look weathered": it is three
## sampled pixels per quad against three named colours.
##
## THE DETAIL IS ON UV2, which is the point of the design -- the airframe's UV1 is already spoken for by the faceted
## panel colouring, so the stains need their own unwrapping. A quad is built by hand with `set_uv2` rather than taken
## from `PlaneMesh`, because `PlaneMesh.add_uv2` pads the second set for lightmapping and this must be exactly 0..1.

const OUT: String = "C:/Users/Graham/AppData/Local/Temp/claude/C--Users-Graham-Desktop-godotgames/9e5b70b7-8882-41cb-a323-4be184a41382/scratchpad/detail_probe"

var _failures: PackedStringArray = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# THE CONTROL RUNS FIRST AND IS NOT OPTIONAL. The first version of this probe came back black on both quads and
	# read as "the detail layer painted nothing"; it was the QUAD that never drew. A probe with no control cannot
	# tell a feature that did nothing from a harness that showed nothing, and it will happily report the wrong one.
	await _probe("0-control-no-detail-layer-at-all", false, true)
	await _probe("A-alpha-in-the-detail-albedo", false)
	await _probe("B-a-separate-detail-mask", true)
	if _failures.is_empty():
		print("RESULT=PASS a_detail_layers_alpha_masks_it_on_an_opaque_material")
	else:
		print("RESULT=FAIL a_detail_layers_alpha_masks_it_on_an_opaque_material %s" % [_failures])
	get_tree().quit(0 if _failures.is_empty() else 1)


## ONE QUAD, RENDERED AND READ BACK. `masked` picks which of the two ways the right half is meant to be kept clear.
func _probe(what: String, masked: bool, control: bool = false) -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(400, 200)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.own_world_3d = true
	stage.transparent_bg = false
	add_child(stage)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# BLACK, so a background bleeding into a sample is obvious rather than plausible.
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 1.0, 1.0)
	env.ambient_light_energy = 1.0
	environment.environment = env
	stage.add_child(environment)

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.0, 0.0, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# CULLING OFF: a one-sided quad wound the wrong way is invisible, and which way SurfaceTool wound it is not
	# what this probe is asking. This is the line that turned the first all-black run into a reading.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.detail_enabled = not control
	material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	if control:
		pass
	elif masked:
		material.detail_albedo = _sheet(Color8(255, 0, 0, 255), Color8(255, 0, 0, 255))
		material.detail_mask = _sheet(Color8(255, 255, 255, 255), Color8(0, 0, 0, 255))
	else:
		material.detail_albedo = _sheet(Color8(255, 0, 0, 255), Color8(0, 255, 0, 0))

	var quad := MeshInstance3D.new()
	quad.mesh = _quad()
	quad.material_override = material
	stage.add_child(quad)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# The quad is 2 by 1, so a size of 1 fills the height exactly and leaves no background in the samples.
	camera.size = 1.0
	camera.current = true
	stage.add_child(camera)
	camera.global_position = Vector3(0.0, 0.0, 2.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	for _f in range(4):
		await RenderingServer.frame_post_draw
	var image := stage.get_texture().get_image()
	image.save_png(OUT.path_join("detail-%s.png" % what))

	var left := image.get_pixel(100, 100)
	var right := image.get_pixel(300, 100)
	print("[detail_probe] %s  left %s  right %s" % [what, _say(left), _say(right)])
	if control:
		_expect(what + " the quad draws at all, left", left, Color(0.0, 0.0, 1.0))
		_expect(what + " the quad draws at all, right", right, Color(0.0, 0.0, 1.0))
		stage.queue_free()
		return
	_expect(what + " the left half takes the detail", left, Color(1.0, 0.0, 0.0))
	_expect(what + " the right half is left alone", right, Color(0.0, 0.0, 1.0))
	stage.queue_free()


## A 64 BY 64 SHEET, one colour on the left half and another on the right.
func _sheet(left: Color, right: Color) -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			image.set_pixel(x, y, left if x < 32 else right)
	return ImageTexture.create_from_image(image)


## A 2 BY 1 QUAD WITH UV AND UV2 BOTH RUNNING 0..1, built by hand for the reason in the block above.
func _quad() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector3(-1.0, -0.5, 0.0), Vector3(1.0, -0.5, 0.0), Vector3(1.0, 0.5, 0.0), Vector3(-1.0, 0.5, 0.0)]
	var uvs := [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)]
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		for i in triangle:
			tool.set_normal(Vector3(0.0, 0.0, 1.0))
			tool.set_uv(uvs[i])
			tool.set_uv2(uvs[i])
			tool.add_vertex(corners[i])
	return tool.commit()


func _expect(label: String, got: Color, want: Color) -> void:
	# A TENTH OF A CHANNEL, because the render target is sRGB and the sample is never the exact literal.
	if absf(got.r - want.r) > 0.1 or absf(got.g - want.g) > 0.1 or absf(got.b - want.b) > 0.1:
		_failures.append("%s: wanted %s, got %s" % [label, _say(want), _say(got)])


func _say(c: Color) -> String:
	return "(%.2f, %.2f, %.2f)" % [c.r, c.g, c.b]
