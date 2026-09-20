#[vertex]
#version 450

// THE COMPUTE MIST LAID ON BY A BLEND, NOT A STORE (team-lead's DECISION after prototype (a), 2026-09-15): one triangle over the
// whole view, drawn with the engine's own blending into the colour buffer. A full-resolution compute upsample (removed) cost +1.03
// to +1.07 ms at 4K whatever the mist held -- about thirteen texel fetches and an imageLoad and imageStore on every pixel; this
// reads the half-resolution mist with ONE linear tap, and does the depth-weighted 2 by 2 only where the half pass flagged the
// texel as an edge (edge_half): +0.23 to +0.32 ms. Procedural: no vertex buffer, three vertices from gl_VertexIndex.

void main() {
	vec2 corner = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
	gl_Position = vec4(corner * 2.0 - 1.0, 0.0, 1.0);
}

#[fragment]
#version 450

// BLENDED src ONE, dst SRC_ALPHA, alpha not written: colour * T + mist * a, with T = 1 - a in alpha.
layout(location = 0) out vec4 laid;

layout(set = 0, binding = 0) uniform sampler2D mist_linear;     // the half-resolution mist, a LINEAR sampler
layout(set = 0, binding = 1) uniform sampler2D edge_half;       // 1 where the half pass saw an edge; nearest
layout(set = 0, binding = 2) uniform sampler2D depth_full;
layout(set = 0, binding = 3) uniform sampler2D mist_half;       // the same texture, NEAREST, for the edge path
layout(set = 0, binding = 4) uniform sampler2D depth_half;
layout(set = 0, binding = 5) uniform sampler2D far_half;

layout(push_constant, std430) uniform Push {
	vec2 full_size;
	vec2 half_size;
	float edge;
	float show_mask;                // 1: draw the edge mask instead of the mist (--mist-pass=compute-mask)
	float pad1;
	float pad2;
} push;

float likeness(float depth, float candidate) {
	if (depth <= 0.0 && candidate <= 0.0) {
		return 1.0;
	}
	return 1.0 - smoothstep(0.0, push.edge, abs(candidate - depth) / max(max(depth, candidate), 1e-7));
}

// THE EDGE PATH: the depth-weighted 2 by 2, for the few pixels whose texel the half pass flagged. Each tap offers its nearest
// and farthest surface (mist_half.glsl); a pixel weighs each by how near its depth is to the pixel's own, bilinearly, and takes
// the candidate nearest in depth where none is its own surface -- no halo along a silhouette, no line along a grazing horizon.
vec4 by_depth(ivec2 here) {
	float depth = texelFetch(depth_full, here, 0).r;
	vec2 at = (vec2(here) + 0.5) * 0.5 - 0.5;
	ivec2 base = ivec2(floor(at));
	vec2 f = at - vec2(base);
	ivec2 last = ivec2(push.half_size) - 1;
	vec4 sum = vec4(0.0);
	float weights = 0.0;
	vec4 nearest = vec4(0.0);
	float nearest_gap = 1e30;
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			ivec2 tap = clamp(base + ivec2(i, j), ivec2(0), last);
			vec2 depths = texelFetch(depth_half, tap, 0).rg;
			vec4 near_mist = texelFetch(mist_half, tap, 0);
			vec4 far_mist = texelFetch(far_half, tap, 0);
			float bilinear = (i == 0 ? 1.0 - f.x : f.x) * (j == 0 ? 1.0 - f.y : f.y);
			float near_like = likeness(depth, depths.r);
			float far_like = depths.g != depths.r ? likeness(depth, depths.g) : 0.0;
			float like = max(near_like, far_like);
			vec4 mist = far_like > near_like ? far_mist : near_mist;
			sum += mist * bilinear * like;
			weights += bilinear * like;
			float gap = min(abs(depths.r - depth), abs(depths.g - depth));
			if (gap < nearest_gap) {
				nearest_gap = gap;
				nearest = abs(depths.g - depth) < abs(depths.r - depth) ? far_mist : near_mist;
			}
		}
	}
	return weights > 1e-3 ? sum / weights : nearest;
}

void main() {
	ivec2 here = ivec2(gl_FragCoord.xy);
	ivec2 texel = clamp(here / 2, ivec2(0), ivec2(push.half_size) - 1);
	float flagged = texelFetch(edge_half, texel, 0).r;
	// THE MASK PROBE: white where flagged; alpha 0 so the blend replaces the colour.
	if (push.show_mask > 0.5) {
		laid = vec4(vec3(flagged), 0.0);
		return;
	}
	vec4 mist;
	if (flagged < 0.5) {
		mist = textureLod(mist_linear, (gl_FragCoord.xy * 0.5) / push.half_size, 0.0);
	} else {
		mist = by_depth(here);
	}
	laid = vec4(mist.rgb * mist.a, 1.0 - mist.a);
}
