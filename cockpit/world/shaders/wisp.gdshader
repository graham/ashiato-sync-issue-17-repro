// A WISP OF RISING AIR, climbing a thermal's column: haze, not a shape.
//
// The first round wisps (2026-09-14) were a StandardMaterial at one alpha all over, and close to they read as large pale
// ellipses with a hard edge -- one lay across a peak like a glass lens (the lead, looking at the clouds view). So the alpha
// thins towards the silhouette, by how squarely the surface faces the eye, and the bottom of each puff fades out, which is
// the edge that meets the ground or a hillside behind it.
//
// NOT A DEPTH-TEXTURE FADE. The one thing that knows where the rock behind a wisp is, is the depth texture, and nothing in
// this project reads it (agents.md, "No screen texture, no depth texture, no FRAGCOORD"). The bottom fade is in the puff's
// own space instead: it softens the edge a wisp shows against whatever is behind it, and does not know what that is.
//
// Still depth-tested against the rock like anything else: a wisp in front of a peak is in front of it. The instance colour's
// alpha (LiftYard.wisp_alpha) and the tint's (the time of day's markers) multiply in, as they did on the StandardMaterial.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, specular_disabled, shadows_disabled;
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;

uniform vec4 tint : source_color = vec4(0.86, 0.90, 0.96, 0.12);
// How sharply the alpha falls towards the silhouette: 1 is gentle, higher thins the rim faster.
uniform float rim_power = 1.5;
// How much of the puff's height, from its bottom, fades in.
uniform float soft_bottom = 0.45;

varying float low;

void vertex() {
	// The unit sphere runs -0.5 to 0.5.
	low = VERTEX.y;
	mist_here = mist_along(EYE_POSITION_WORLD, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz, mist_clock);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(facing, rim_power);
	float bottom = smoothstep(-0.5, -0.5 + soft_bottom, low);
	ALBEDO = mix(tint.rgb * COLOR.rgb, mist_here.rgb, mist_here.a);
	ALPHA = tint.a * COLOR.a * rim * bottom;
}
