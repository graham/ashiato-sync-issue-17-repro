// THE THRUST EXHAUST'S HAZE: the column of disturbed, faintly sooty air streaming out of a nozzle. This is the
// "thrust smoke" the user asked for on 2026-09-19, and it is the first effect of its kind in this game.
//
// BLENDED, NOT ADDITIVE, AND THAT IS THE WHOLE DESIGN DECISION. `flame_fine` and `missile_motor` are additive, which is
// right for fire seen against dark hills and wrong for anything held up against a bright sky: added to a pale blue it
// comes out white. `flare.gdshader` already learned this once -- the oil platform's flame drew as a white sail against
// the sky until it was blended -- and exhaust is the worse case, because hot disturbed air is not bright at all. It is
// if anything DARKER than the sky behind it, and what the eye reads is the sky being disturbed rather than anything
// glowing. So this replaces the background by its own alpha, and that alpha is tiny: `ExhaustTuning.HAZE_THICKNESS` is
// 0.055, and the first build at 0.25 read as a smoke screen towed behind the aeroplane rather than as exhaust.
//
// NO SCREEN-SPACE REFRACTION, deliberately. Real heat shimmer bends what is behind it, and doing that properly needs a
// screen-texture read, paid per pixel and twice on a headset -- and a `depth_draw_never` blended quad cannot sample
// what is drawn after it anyway. This layer stands in for it. If somebody later wants true shimmer it is a different
// shader with a different render order, not a uniform on this one.
//
// One quad per port, standing along the port's axis and turned about that axis to face the MIDPOINT OF THE EYES --
// `missile_motor`'s rule, and for its reason: a quad turned separately per eye is two plumes. `ExhaustYard` puts the
// node's origin at the nozzle, its Y column down the plume (as long as the plume) and its X column across it.
//
// TIME is wrapped at ten minutes, for the fire yard's reason: scrolling noise by an ever-growing TIME loses precision
// over a long session and the haze freezes into stripes.
// ONE MULTIMESH FOR EVERY HAZE IN THE SKY: one draw call however many aircraft are running. A MultiMesh instance
// carries INSTANCE_CUSTOM and its colour and nothing else, so the per-port numbers ride in INSTANCE_CUSTOM; and
// billboard.gdshaderinc's "WHICH" table requires NO skip_vertex_transform plus BILLBOARD_LOCAL_OF for a MultiMesh,
// because a double build otherwise applies the instance transform twice and headless cannot see it happen.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;

#include "res://world/shaders/terrain_noise.gdshaderinc"

uniform vec3 tone : source_color = vec3(0.30, 0.30, 0.31);
uniform float thickness = 0.055;
uniform float spread = 2.8;

varying vec2 uv;
// INSTANCE_CUSTOM.r is how hard this port blows, 0..1, off the replicated bus's throttle; .g is which port it is, so
// four nozzles on one aeroplane are four plumes and not one smeared four times; .b is how COLD it is -- 0 for a hot
// jet pipe, 1 for fan air, which is clean and shows less.
varying float blowing;
varying float seed;
varying float cold;

void vertex() {
	// RELATIVE TO THE PORT'S ORIGIN, which the engine places exactly: see billboard.gdshaderinc. A shader here NEVER
	// reads CAMERA_POSITION_WORLD, which is minus the camera on the double build.
	vec3 origin = vec3(0.0);
	blowing = INSTANCE_CUSTOM.r;
	seed = INSTANCE_CUSTOM.g;
	cold = INSTANCE_CUSTOM.b;
	vec3 along = MODEL_MATRIX[1].xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 to_eye = BILLBOARD_EYE - origin;
	vec3 side = cross(along, to_eye);
	side = length(side) > 0.0001 ? normalize(side) : normalize(MODEL_MATRIX[0].xyz);
	uv = VERTEX.xy;
	// WIDENS AS IT GOES, because a jet entrains the air around it and slows down.
	float widen = 1.0 + spread * clamp(VERTEX.y, 0.0, 1.0);
	vec3 world = origin + side * VERTEX.x * width * widen + along * VERTEX.y;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_LOCAL_OF(world);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float t = mod(TIME, 600.0);
	float y = clamp(uv.y, 0.0, 1.0);
	// TORN ALONG THE AXIS, not up: the flow here has a direction of its own and the noise runs down it.
	float tear = fbm2(vec2(uv.x * 1.8 + seed * 7.0, y * 2.2 - t * 3.1));
	float x = uv.x + (tear - 0.5) * 0.7 * y;
	float curl = fbm2(vec2(x * 3.4 + seed * 13.0, y * 3.0 - t * 4.4));
	// A COLUMN THAT OPENS AND THINS: solid at the nozzle, ragged and gone by the end.
	float half_width = 0.5 * (0.35 + 0.65 * y);
	float body = 1.0 - smoothstep(half_width * 0.25, half_width, abs(x));
	// THE CORE IS DENSEST JUST OFF THE NOZZLE and fades out over the length; the noise breaks it up more the further
	// it goes, which is what stops it reading as a painted cone.
	float density = body * (1.0 - smoothstep(0.05, 1.0, y)) * mix(1.0, curl, smoothstep(0.1, 0.8, y));
	density *= blowing * mix(1.0, 0.45, cold);
	ALBEDO = mix(tone, mist_here.rgb, mist_here.a);
	ALPHA = clamp(density * thickness, 0.0, 1.0);
}
