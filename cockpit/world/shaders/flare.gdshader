// AN OIL PLATFORM'S FLARE: a gas flame at the end of the flare boom, torn by the wind, orange against a daylit sky.
//
// WHY NOT THE FIRE YARD'S FLAME. `flame_fine.gdshader` is additive, which is right for a fire on the ground seen against
// dark hills and wrong for a flame held up against a bright sky: added to a pale blue it comes out white, and the first
// picture of the platform (lane/oilrig, 2026-09-18, cockpit-oilrig-01) showed a white sail on the flare stack where the
// Montrose photograph has an orange flame. So this one is BLENDED: its colour replaces the sky behind it by its own alpha,
// and a flame is orange whatever it is in front of. At night the same unshaded colour is the brightest thing on the sea.
//
// Everything else is the fire yard's: a quad stood on the stack's tip and turned about its own up axis towards the
// midpoint of the eyes (billboard.gdshaderinc), noise scrolling up through a teardrop and torn sideways higher up
// (terrain_noise.gdshaderinc's fbm2), misted once a vertex (mist.gdshaderinc, which every see-through shader includes).
// TIME is wrapped at ten minutes, for the fire yard's reason.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
varying vec4 mist_here;

#include "res://world/shaders/terrain_noise.gdshaderinc"

// Which tongue this is, so the tongues on the stack are different flames.
instance uniform float seed = 0.0;
// HOW HOT THE FLAME LOOKS, by time of day (`OilField.FLAME_HEAT`): 1 by day, well over 1 at night, where the colour goes
// past white into the renderer's HDR range and the flame is the brightest thing on the sea.
uniform float heat = 1.0;

varying vec2 uv;

void vertex() {
	vec3 origin = vec3(0.0);
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 up = MODEL_MATRIX[1].xyz;
	vec3 to_eye = BILLBOARD_EYE - origin;
	to_eye.y = 0.0;
	vec3 right = length(to_eye) > 0.01 ? normalize(vec3(to_eye.z, 0.0, -to_eye.x)) : vec3(1.0, 0.0, 0.0);
	uv = VERTEX.xy;
	// THE SWAY: the top of each tongue wanders across and pulses in height on its own clock, so the three tongues
	// never stand still together and the flame billows rather than holding a shape.
	float t = mod(TIME, 600.0);
	float h = VERTEX.y * VERTEX.y;
	float sway = (sin(t * 2.3 + seed * 11.0) * 0.6 + sin(t * 3.7 + seed * 5.0) * 0.4) * 0.22 * h;
	float pulse = 1.0 + 0.16 * sin(t * 4.1 + seed * 9.0) * VERTEX.y;
	vec3 world = origin + right * (VERTEX.x + sway) * width + up * VERTEX.y * pulse;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_VIEW_OF(world);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float t = mod(TIME, 600.0);
	// Two octaves torn upward: the big billows and the licks at the edge.
	float tear = fbm2(vec2(uv.x * 1.6 + seed * 7.0, uv.y * 1.2 - t * 1.4));
	float x = uv.x + (tear - 0.5) * 0.55 * uv.y;
	float lick = fbm2(vec2(x * 3.0 + seed * 13.0, uv.y * 2.4 - t * 2.9));
	// A ROUNDED BODY, widest a third of the way up and closing to a ragged top -- not a cone to a point, which is what
	// read as a crystal shard in the first pictures.
	float y = clamp(uv.y, 0.0, 1.0);
	float width = 0.5 * sqrt(max(0.0, sin(3.14159 * pow(y, 0.7)))) * (0.75 + 0.35 * lick) + 0.03;
	float body = 1.0 - smoothstep(width * 0.3, width, abs(x));
	float burn = clamp(body * (1.25 - y * 1.05 + (lick - 0.5) * 1.1), 0.0, 1.0);
	vec3 colour = mix(vec3(0.72, 0.12, 0.02), vec3(1.0, 0.42, 0.05), smoothstep(0.05, 0.4, burn));
	colour = mix(colour, vec3(1.0, 0.74, 0.22), smoothstep(0.45, 0.8, burn));
	colour = mix(colour, vec3(1.0, 0.93, 0.70), smoothstep(0.85, 1.0, burn));
	ALBEDO = mix(colour * heat, mist_here.rgb, mist_here.a);
	ALPHA = clamp(burn * 2.4, 0.0, 1.0) * smoothstep(0.0, 0.04, y);
}
