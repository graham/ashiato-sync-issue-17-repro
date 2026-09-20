// THE FLARE'S HALO: the glow a gas flame throws into the air round itself at night, which is what makes a flare a
// landmark from kilometres off. One quad at the flame's middle, turned full-face to the eye, added, falling off from
// its middle and flickering with the flame. Evening and night only (`OilField.light_for`). Misted once a vertex
// (mist.gdshaderinc), as every see-through shader is.
// FOG DISABLED, as every added sprite here is: the engine's fog mixed the quad's black corners towards the fog colour
// and ADDED that, which drew the whole 70 m square against the bright evening sky (lane/flaresea, cockpit-flaresea-10,
// 2026-09-18). The mist above is what fades it.
shader_type spatial;
render_mode unshaded, fog_disabled, blend_add, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
#include "res://world/shaders/mist.gdshaderinc"
varying vec4 mist_here;

uniform float strength = 0.0;

varying vec2 uv;

void vertex() {
	uv = VERTEX.xy * 2.0;
	float size = length(MODEL_MATRIX[0].xyz);
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz, mist_clock);
	VERTEX = MODELVIEW_MATRIX[3].xyz + vec3(VERTEX.xy * size, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float t = mod(TIME, 600.0);
	float r = length(uv);
	float flicker = 0.82 + 0.1 * sin(t * 9.0) + 0.08 * sin(t * 13.7 + 2.0);
	float core = exp(-r * r * 9.0);
	float wide = pow(clamp(1.0 - r, 0.0, 1.0), 2.0) * 0.35;
	ALBEDO = vec3(1.0, 0.52, 0.16) * (core + wide) * flicker * strength * (1.0 - mist_here.a);
}
