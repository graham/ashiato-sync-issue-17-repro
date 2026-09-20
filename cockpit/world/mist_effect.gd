extends CompositorEffect
class_name MistEffect
## THE LOW MIST AS A HALF-RESOLUTION COMPUTE PASS LAID ON BY BLENDING, on PLAIN: the same mist as `world/shaders/mist.gdshader`,
## worked out for a quarter of the pixels and laid on the colour by one blended triangle, instead of a full-screen transparent quad
## that reads a copy of the depth buffer. `MistLayer` hangs it on the level's Compositor on PLAIN and keeps the spatial pass on
## FINE (`MistLayer.computes`).
##
## WHY (team-lead's DECISION, 2026-09-15, off the GPU-bound table): at 3840x2141 x2.00 the spatial pass with NOTHING in it cost
## +0.61 to +0.83 ms -- the full-screen fill, the blend, and the depth copy the engine makes for any transparent shader that reads
## `hint_depth_texture` -- about 0.33 to 0.45 ms of a headset's two eyes before any maths, against PLAIN's +0.5 ms for the whole.
##
## WHEN IN THE FRAME: PRE_TRANSPARENT. render_forward_clustered.cpp's _render_scene runs opaque, then POST_OPAQUE, then the sky,
## then the MSAA resolves, then POST_SKY, then the separate-specular merge, the screen-texture copy and the depth-texture copy (each
## only if something needs it), then PRE_TRANSPARENT, then the transparent pass. AT POST_OPAQUE THE SKY DRAWS OVER THE MIST; at
## POST_SKY the specular merge would land on top of it. PRE_TRANSPARENT is where the spatial pass sat: after everything opaque
## and the sky, before the see-through things that mist themselves (world/shaders/mist.gdshaderinc).
##
## NOT ON FINE, BECAUSE OF MSAA: with multisampling the transparent pass draws into the multisample colour buffer, which is
## resolved into the internal texture afterwards, over anything laid on the resolved one here. PLAIN has no MSAA
## (Finish.PLAIN_MSAA) and a headset starts PLAIN (Finish.HEADSET_DEFAULT); a player who chooses FINE gets the spatial pass. This
## effect does nothing if it ever meets MSAA.
##
## ONE COPY OF THE MATHS: world/shaders/mist_half.glsl includes mist_core.gdshaderinc, the same file mist.gdshaderinc includes,
## and #defines the `mist_*` globals onto a uniform buffer `pack` fills from MistLayer's written numbers.
##
## LAID ON BY BLENDING, NOT BY A COMPUTE STORE (team-lead's DECISION after prototype (a), 2026-09-15): a compute upsample that
## loaded and stored every pixel (mist_up.glsl, removed) cost +1.03 to +1.07 ms at 4K whatever the mist held; one procedural
## triangle drawn with the engine's own blending (world/shaders/mist_lay.glsl) -- one linear tap a pixel, the depth-weighted 2 by 2
## only where the half pass flagged an edge (`half_edge`) -- cost +0.23 to +0.32. See agents.md, "the half-resolution compute mist".
##
## PER VIEW: a headset draws two views in one pass; each gets its own inverse projection (RenderSceneData.get_view_projection,
## eye offset included, depth-corrected as the engine's own) and the centred camera's rotation and position -- the ray from the
## midpoint of the eyes to what this eye sees, as the spatial pass takes it (`view_constants`) -- and its own framebuffer on that
## view's slice of the colour texture (`_lay_on`).
##
## ON THE RENDER THREAD: `_render_callback` runs there. Everything it reads from the main thread is handed over under a mutex
## (`hand`, `hand_clock`), by value; it reads no node.

const HALF_SHADER: RDShaderFile = preload("res://world/shaders/mist_half.glsl")
const LAY_SHADER: RDShaderFile = preload("res://world/shaders/mist_lay.glsl")
const CONTEXT: StringName = &"mist"
## How many floats `pack` writes before the eye: twelve vec4s (see mist_half.glsl's Params).
const NUMBERS: int = 52
## Where the clock sits in them: sun_clock.w.
const CLOCK_AT: int = 27

## How many frames the callback laid the mist on, for a probe to read that it ran.
var laid: int = 0
## The most views any frame laid it on: 2 in a headset (tests/mist_multiview.gd reads it). THE MOST, NOT THE LAST: the effect runs
## for every viewport that draws the world, and a window drawn after a headset's viewport left the last frame's count at 1.
var views_drawn: int = 0
## Whether the mist is laid on. False only for the pricing probe `--mist-pass=compute-half`, which times the half-resolution pass
## alone so the composite's own cost is the difference (team-lead, 2026-09-15). Never a level's.
var lay_on: bool = true
## Draw the half pass's edge mask instead of the mist, white where it is set: the pictures probe `--mist-pass=compute-mask`, for the
## mask's share of texels (team-lead, 2026-09-15). Never a level's.
var show_mask: bool = false

var _rd: RenderingDevice = null
var _half_shader := RID()
var _half_pipeline := RID()
var _lay_shader := RID()
var _lay_pipeline := RID()
var _lay_format: int = -1
## Each colour texture's framebuffer, by the texture's RID. See `framebuffers_to_let_go`.
var _framebuffers: Dictionary = {}
var _nearest := RID()
var _linear := RID()
var _params := RID()
var _mutex := Mutex.new()
var _numbers := PackedFloat32Array()
var _chart := RID()
var _towns := RID()
var _clock: float = 0.0


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT
	_rd = RenderingServer.get_rendering_device()


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or _rd == null:
		return
	for framebuffer: RID in _framebuffers.values():
		if framebuffer.is_valid() and _rd.framebuffer_is_valid(framebuffer):
			_rd.free_rid(framebuffer)
	for rid in [_half_shader, _lay_shader, _nearest, _linear, _params]:
		if (rid as RID).is_valid():
			_rd.free_rid(rid)


## THE NUMBERS, THE CHART AND THE TOWNS, from the main thread, once per change: `pack` of MistLayer's written globals, and the
## chart's and the towns' RenderingDevice textures.
func hand(numbers: PackedFloat32Array, chart_rd: RID, towns_rd: RID) -> void:
	_mutex.lock()
	_numbers = numbers
	_chart = chart_rd
	_towns = towns_rd
	_mutex.unlock()


## THE MIST'S CLOCK, from the main thread, once a frame.
func hand_clock(clock: float) -> void:
	_mutex.lock()
	_clock = clock
	_mutex.unlock()


## THE UNIFORM BUFFER'S NUMBERS from MistLayer's `written` globals, in mist_half.glsl's order. Static and pure, for the tests.
static func pack(written: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for key in ["mist_haze", "mist_stratus", "mist_stratus_look"]:
		var v: Vector4 = written.get(key, Vector4.ZERO)
		out.append_array([v.x, v.y, v.z, v.w])
	for key in ["mist_colour", "mist_sun_colour"]:
		var c: Color = written.get(key, Color(0, 0, 0, 0))
		out.append_array([c.r, c.g, c.b, c.a])
	var towards: Vector3 = written.get("mist_towards_sun", Vector3.UP)
	out.append_array([towards.x, towards.y, towards.z, float(written.get("mist_steps", 1))])
	var sun: Vector3 = written.get("mist_sun", Vector3.ZERO)
	out.append_array([sun.x, sun.y, sun.z, 0.0])
	var frame: Vector4 = written.get("mist_chart_frame", Vector4.ZERO)
	out.append_array([frame.x, frame.y, frame.z, frame.w])
	var ground: Vector2 = written.get("mist_ground_range", Vector2.ZERO)
	out.append_array([ground.x, ground.y, float(written.get("mist_ceiling", MistTuning.CEILING)),
		float(written.get("mist_reach", MistTuning.REACH))])
	var cover: Vector2 = written.get("mist_stratus_cover", Vector2.ONE)
	out.append_array([cover.x, cover.y, MistTuning.SKY_REACH, MistTuning.COMPUTE_EDGE])
	var town: Vector4 = written.get("mist_town", Vector4(0.0, 0.0, MistTuning.DOME_HEIGHT, MistTuning.DOME_SPREAD))
	out.append_array([town.x, town.y, town.z, town.w])
	var glow: Vector3 = written.get("mist_town_glow", Vector3.ZERO)
	out.append_array([glow.x, glow.y, glow.z, 0.0])
	var pool: Vector4 = written.get("mist_pool", Vector4(0.0, MistTuning.POOL_DEPTH, 0.0, 0.0))
	out.append_array([pool.x, pool.y, pool.z, pool.w])
	return out


## THIS VIEW'S PUSH CONSTANT for mist_half.glsl: its own inverse projection, then the full and half sizes. `scene_data` is the
## frame's RenderSceneData, or anything with its `get_view_projection` (the tests hand two eyes). Static and pure.
static func view_constants(scene_data: Object, view: int, full: Vector2i, half: Vector2i) -> PackedFloat32Array:
	var inverse: Projection = (scene_data.call("get_view_projection", view) as Projection).inverse()
	var out := PackedFloat32Array()
	for column in range(4):
		var c: Vector4 = inverse[column]
		out.append_array([c.x, c.y, c.z, c.w])
	out.append_array([full.x, full.y, half.x, half.y])
	return out


## THE CENTRED CAMERA, after the numbers: its position, then its rotation as a mat4, column by column. Static and pure.
static func camera_constants(camera: Transform3D) -> PackedFloat32Array:
	var b: Basis = camera.basis
	return PackedFloat32Array([camera.origin.x, camera.origin.y, camera.origin.z, 1.0,
		b.x.x, b.x.y, b.x.z, 0.0, b.y.x, b.y.y, b.y.z, 0.0, b.z.x, b.z.y, b.z.z, 0.0, 0.0, 0.0, 0.0, 1.0])


## THE FRAMEBUFFERS NO VIEW DREW INTO THIS FRAME: the keys of `cache` (colour textures) not in `in_use`. A resize, a new finish or a
## headset gives the views new colour textures, and a framebuffer kept for an old one is a leak that grows with every resize; the
## callback lets these go at the end of each frame. Static and pure, for the tests (team-lead, 2026-09-15).
static func framebuffers_to_let_go(cache: Dictionary, in_use: Array) -> Array:
	var gone: Array = []
	for colour in cache.keys():
		if not in_use.has(colour):
			gone.append(colour)
	return gone


## THE LAY-ON'S PUSH CONSTANT for mist_lay.glsl: full and half sizes, the edge share, and whether to draw the edge mask instead.
## Static and pure.
static func lay_constants(full: Vector2i, half: Vector2i, mask: bool) -> PackedFloat32Array:
	return PackedFloat32Array([full.x, full.y, half.x, half.y, MistTuning.COMPUTE_EDGE, 1.0 if mask else 0.0, 0.0, 0.0])


func _ready_on_render_thread() -> bool:
	if _rd == null:
		return false
	if _half_pipeline.is_valid() and _lay_shader.is_valid():
		return true
	_half_shader = _rd.shader_create_from_spirv(HALF_SHADER.get_spirv())
	_lay_shader = _rd.shader_create_from_spirv(LAY_SHADER.get_spirv())
	if not _half_shader.is_valid() or not _lay_shader.is_valid():
		return false
	_half_pipeline = _rd.compute_pipeline_create(_half_shader)
	var nearest := RDSamplerState.new()
	nearest.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	_nearest = _rd.sampler_create(nearest)
	var linear := RDSamplerState.new()
	linear.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	linear.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_linear = _rd.sampler_create(linear)
	_params = _rd.uniform_buffer_create((NUMBERS + 20) * 4)
	return _half_pipeline.is_valid()


func _render_callback(_type: int, render_data: RenderData) -> void:
	if not _ready_on_render_thread():
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene := render_data.get_render_scene_data() as RenderSceneDataRD
	if buffers == null or scene == null or buffers.get_msaa_3d() != RenderingServer.VIEWPORT_MSAA_DISABLED:
		return
	var full: Vector2i = buffers.get_internal_size()
	if full.x <= 0 or full.y <= 0:
		return
	var half := Vector2i((full.x + 1) / 2, (full.y + 1) / 2)
	_mutex.lock()
	var numbers: PackedFloat32Array = _numbers
	var chart: RID = _chart
	var towns: RID = _towns
	var clock: float = _clock
	_mutex.unlock()
	if numbers.size() != NUMBERS or not chart.is_valid() or not towns.is_valid():
		return
	var views: int = buffers.get_view_count()
	var usage: int = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	if not buffers.has_texture(CONTEXT, &"half_edge"):
		buffers.create_texture(CONTEXT, &"half", RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage,
			RenderingDevice.TEXTURE_SAMPLES_1, half, views, 1, true, false)
		buffers.create_texture(CONTEXT, &"half_depth", RenderingDevice.DATA_FORMAT_R32G32_SFLOAT, usage,
			RenderingDevice.TEXTURE_SAMPLES_1, half, views, 1, true, false)
		# THE FARTHER SURFACE'S MIST on texels that hold two: see mist_half.glsl, the line along every edge.
		buffers.create_texture(CONTEXT, &"half_far", RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage,
			RenderingDevice.TEXTURE_SAMPLES_1, half, views, 1, true, false)
		# WHERE ONE LINEAR TAP WOULD BLEED ACROSS AN EDGE: see mist_half.glsl.
		buffers.create_texture(CONTEXT, &"half_edge", RenderingDevice.DATA_FORMAT_R8_UNORM, usage,
			RenderingDevice.TEXTURE_SAMPLES_1, half, views, 1, true, false)
	var block: PackedFloat32Array = numbers.duplicate()
	block[CLOCK_AT] = clock
	block.append_array(camera_constants(scene.get_cam_transform()))
	var bytes: PackedByteArray = block.to_byte_array()
	_rd.buffer_update(_params, 0, bytes.size(), bytes)
	var drawn_into: Array = []
	for view in range(views):
		var depth: RID = buffers.get_depth_layer(view)
		var colour: RID = buffers.get_color_layer(view)
		var half_mist: RID = buffers.get_texture_slice(CONTEXT, &"half", view, 0, 1, 1)
		var half_depth: RID = buffers.get_texture_slice(CONTEXT, &"half_depth", view, 0, 1, 1)
		var half_far: RID = buffers.get_texture_slice(CONTEXT, &"half_far", view, 0, 1, 1)
		var half_edge: RID = buffers.get_texture_slice(CONTEXT, &"half_edge", view, 0, 1, 1)
		var first: RID = UniformSetCacheRD.get_cache(_half_shader, 0, [
			_sampled(0, _nearest, depth), _sampled(1, _linear, chart), _image(2, half_mist), _image(3, half_depth),
			_image(4, half_far), _buffer(5, _params), _image(6, half_edge), _sampled(7, _nearest, towns)])
		_dispatch(_half_pipeline, first, view_constants(scene, view, full, half).to_byte_array(), half)
		if lay_on:
			_lay_on(colour, depth, half_mist, half_depth, half_far, half_edge, lay_constants(full, half, show_mask).to_byte_array())
			drawn_into.append(colour)
	for colour in framebuffers_to_let_go(_framebuffers, drawn_into):
		var framebuffer: RID = _framebuffers[colour]
		if framebuffer.is_valid() and _rd.framebuffer_is_valid(framebuffer):
			_rd.free_rid(framebuffer)
		_framebuffers.erase(colour)
	views_drawn = maxi(views_drawn, drawn_into.size())
	laid += 1


## ONE TRIANGLE OVER THIS VIEW'S COLOUR, blended src ONE, dst SRC_ALPHA, alpha untouched (mist_lay.glsl): colour * T + mist * a.
func _lay_on(colour: RID, depth: RID, half_mist: RID, half_depth: RID, half_far: RID, half_edge: RID, push: PackedByteArray) -> void:
	var framebuffer: RID = _framebuffers.get(colour, RID())
	if not framebuffer.is_valid() or not _rd.framebuffer_is_valid(framebuffer):
		var textures: Array[RID] = [colour]
		framebuffer = _rd.framebuffer_create(textures)
		_framebuffers[colour] = framebuffer
	if not framebuffer.is_valid():
		return
	var format: int = _rd.framebuffer_get_format(framebuffer)
	if not _lay_pipeline.is_valid() or format != _lay_format:
		if _lay_pipeline.is_valid():
			_rd.free_rid(_lay_pipeline)
		var attachment := RDPipelineColorBlendStateAttachment.new()
		attachment.enable_blend = true
		attachment.color_blend_op = RenderingDevice.BLEND_OP_ADD
		attachment.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
		attachment.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_SRC_ALPHA
		attachment.alpha_blend_op = RenderingDevice.BLEND_OP_ADD
		attachment.src_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ZERO
		attachment.dst_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
		attachment.write_a = false
		var attachments: Array[RDPipelineColorBlendStateAttachment] = [attachment]
		var blend_state := RDPipelineColorBlendState.new()
		blend_state.attachments = attachments
		# -1: no vertex format; the triangle is procedural (gl_VertexIndex).
		_lay_pipeline = _rd.render_pipeline_create(_lay_shader, format, -1, RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
			RDPipelineRasterizationState.new(), RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(), blend_state)
		_lay_format = format
	if not _lay_pipeline.is_valid():
		return
	var uniforms: RID = UniformSetCacheRD.get_cache(_lay_shader, 0, [
		_sampled(0, _linear, half_mist), _sampled(1, _nearest, half_edge), _sampled(2, _nearest, depth),
		_sampled(3, _nearest, half_mist), _sampled(4, _nearest, half_depth), _sampled(5, _nearest, half_far)])
	# DRAW_DEFAULT_ALL (0): the colour attachment is LOADED and STORED (INITIAL_ACTION_LOAD, FINAL_ACTION_STORE in 4.7.2).
	var list: int = _rd.draw_list_begin(framebuffer, RenderingDevice.DRAW_DEFAULT_ALL)
	_rd.draw_list_bind_render_pipeline(list, _lay_pipeline)
	_rd.draw_list_bind_uniform_set(list, uniforms, 0)
	_rd.draw_list_set_push_constant(list, push, push.size())
	_rd.draw_list_draw(list, false, 1, 3)
	_rd.draw_list_end()


func _dispatch(pipeline: RID, uniform_set: RID, push: PackedByteArray, size: Vector2i) -> void:
	var list: int = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, pipeline)
	_rd.compute_list_bind_uniform_set(list, uniform_set, 0)
	_rd.compute_list_set_push_constant(list, push, push.size())
	_rd.compute_list_dispatch(list, (size.x + 7) / 8, (size.y + 7) / 8, 1)
	_rd.compute_list_end()


static func _sampled(binding: int, sampler: RID, texture: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(sampler)
	u.add_id(texture)
	return u


static func _image(binding: int, texture: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(texture)
	return u


static func _buffer(binding: int, buffer: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u.binding = binding
	u.add_id(buffer)
	return u
