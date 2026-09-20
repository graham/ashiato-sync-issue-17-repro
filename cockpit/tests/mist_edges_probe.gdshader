// A PICTURES PROBE, NOT THE MIST: the mist pass's quad drawing, opaque, three facts about the depth buffer the compute mist's
// upsample is checked against (MistLayer `--mist-pass=edges`, team-lead's conditions on the edge fix, 2026-09-15). Never drawn
// by a level unless asked for on the command line.
//   RED:   this pixel's depth jumps from a neighbour's by more than `edge` of the nearer, or one is sky and the other not;
//   GREEN: the 2 by 2 block this pixel falls in (aligned as the compute mist's half texels are) holds two surfaces by that same
//          test, so its texel took the extra far mist (mist_half.glsl) -- the share of green is the share of such texels;
//   BLUE:  sky, where the depth buffer holds nothing.
// Read on the viewport's own 3D pixels (FRAGCOORD), which are the compute mist's full resolution.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
// MistTuning.COMPUTE_EDGE, handed by MistLayer.
uniform float edge = 0.02;

bool apart(float a, float b) {
	if ((a <= 0.0) != (b <= 0.0)) {
		return true;
	}
	return a > 0.0 && abs(a - b) / max(max(a, b), 1e-7) > edge;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	ivec2 size = textureSize(depth_texture, 0);
	ivec2 p = clamp(ivec2(FRAGCOORD.xy), ivec2(0), size - 1);
	float d = texelFetch(depth_texture, p, 0).r;
	float jump = 0.0;
	for (int k = 0; k < 4; k++) {
		ivec2 o = k == 0 ? ivec2(1, 0) : (k == 1 ? ivec2(-1, 0) : (k == 2 ? ivec2(0, 1) : ivec2(0, -1)));
		if (apart(d, texelFetch(depth_texture, clamp(p + o, ivec2(0), size - 1), 0).r)) {
			jump = 1.0;
		}
	}
	ivec2 corner = (p / 2) * 2;
	float near_depth = -1.0;
	float far_depth = 2.0;
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			float s = texelFetch(depth_texture, min(corner + ivec2(i, j), size - 1), 0).r;
			near_depth = max(near_depth, s);
			far_depth = min(far_depth, s);
		}
	}
	float two = (near_depth > 0.0 && (near_depth - far_depth) / near_depth > edge) ? 1.0 : 0.0;
	ALBEDO = vec3(jump, two, d <= 0.0 ? 1.0 : 0.0);
	ALPHA = 1.0;
}
