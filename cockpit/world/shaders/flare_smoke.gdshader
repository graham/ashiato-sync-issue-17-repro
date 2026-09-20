// THE FLARE'S SMOKE: a thin dark trail rising off the top of the flame and carried downwind. One quad, stood on the flame's
// top and leaning with it, turned about its own long axis towards the midpoint of the eyes (billboard.gdshaderinc), with
// noise scrolling up it so the trail is always leaving the flame. Blended, dark and thinning to nothing, so it is a streak
// against the sky and never a wall. Misted once a vertex (mist.gdshaderinc), as every see-through shader is.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
varying vec4 mist_here;

#include "res://world/shaders/terrain_noise.gdshaderinc"

// How dark the smoke is, 0..1, handed over by `OilField` for the time of day: it is lit by the flame at night.
uniform vec3 smoke_colour : source_color = vec3(0.16, 0.15, 0.14);
uniform float thickness = 0.55;
// THE UNDERSIDE LIT BY THE FLAME at night: the colour the smoke takes nearest the fire, and how much of it.
uniform vec3 underlit : source_color = vec3(1.0, 0.45, 0.12);
uniform float underlit_share = 0.0;

varying vec2 uv;

void vertex() {
	vec3 origin = vec3(0.0);
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 up = MODEL_MATRIX[1].xyz;
	vec3 to_eye = BILLBOARD_EYE - origin;
	vec3 along = normalize(up);
	vec3 across = cross(along, to_eye);
	vec3 right = length(across) > 0.01 ? normalize(across) : vec3(1.0, 0.0, 0.0);
	uv = VERTEX.xy;
	// The trail widens as it rises and spreads.
	vec3 world = origin + right * VERTEX.x * width * (0.35 + 1.1 * VERTEX.y) + up * VERTEX.y;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_VIEW_OF(world);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float t = mod(TIME, 600.0);
	float y = clamp(uv.y, 0.0, 1.0);
	float wander = fbm2(vec2(y * 2.0 - t * 0.35, 3.0)) - 0.5;
	float x = uv.x + wander * 0.5;
	float puff = fbm2(vec2(x * 3.0, y * 4.0 - t * 0.9));
	float core = 1.0 - smoothstep(0.1, 0.5, abs(x));
	float density = core * smoothstep(0.25, 0.75, puff) * smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.35, 1.0, y));
	vec3 lit = mix(smoke_colour, underlit, underlit_share * (1.0 - smoothstep(0.0, 0.4, y)));
	ALBEDO = mix(lit, mist_here.rgb, mist_here.a);
	ALPHA = clamp(density * thickness, 0.0, 1.0);
}
