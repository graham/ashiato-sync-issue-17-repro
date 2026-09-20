#[compute]
#version 450
// mist_core sha256: a12dc0e9841bff12dfc27a5f61f80c731c05726f83cc1027b6ada23229f8d5fc
// THE STAMP ABOVE IS THE SHA-256 OF mist_core.gdshaderinc WITH ITS CARRIAGE RETURNS STRIPPED, and tests/lint.gd fails when it is
// not. This file is compiled when it is IMPORTED, and an edit to the file it includes changes nothing here, so nothing reimported
// it: PLAIN kept the old maths while FINE took the new (2026-09-15, the horizon fix -- equality 11 of 12, the alpine line still
// on PLAIN only). Bumping the stamp is an edit to this file, so every checkout's --import recompiles it, through git, with no
// hand step. Stripped, because git checks the include out CRLF here and LF on Linux. Written after #version, not above
// #[compute]: text before the stage marker is not this file's to risk.

// THE COMPUTE MIST, HALF-RESOLUTION: for each texel of a half-sized image, the nearest surface of the 2 by 2 full-resolution
// pixels it covers, rebuilt in the world through this view's own inverse projection and the camera's rotation, and what the
// mist between the eye and it takes away and puts back -- `mist_along`, the same function the spatial pass calls, from the one
// copy in mist_core.gdshaderinc. Written with the depth it used and an edge mask, for the blended lay-on (mist_lay.glsl). Run by
// MistEffect.
//
// THE NEAREST OF THE FOUR, NOT THE AVERAGE: an average of a building's depth and the sky's behind it is a point in the air that
// is neither, and its mist would draw a halo along every silhouette.
//
// AND THE FARTHEST TOO, WHERE THE FOUR ARE TWO SURFACES: a texel straddling an edge -- a tower's top against the sky, the near
// grass against the far sea at the horizon -- kept only the nearer surface, and a pixel of the farther one with no matching tap
// took the nearer one's mist: a line a pixel or two tall along every such edge, 824 to 1,372 pixels over 16/255 on grass
// (step2c-look2 and look3, rows 446-447, mostly NOT against the sky). So where the nearest and farthest of the four differ by more
// than `edge` of the nearer, the farthest's mist is worked out too (`far_half`, depth in `depth_half.g`), and the upsample takes
// whichever of a tap's two matches the pixel. EACH REBUILT AT ITS OWN PIXEL, not at the 2 by 2's middle: at a grazing horizon half
// a pixel slides the rebuilt point kilometres along the ground.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_full;
layout(set = 0, binding = 1) uniform sampler2D mist_ground;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D mist_half;
layout(rg32f, set = 0, binding = 3) uniform restrict writeonly image2D depth_half;
layout(rgba16f, set = 0, binding = 4) uniform restrict writeonly image2D far_half;
// 1 where one linear tap of the half-resolution mist would bleed one surface's mist over another: the blended composite
// (mist_lay.glsl) does the depth-weighted 2 by 2 only there.
layout(r8, set = 0, binding = 6) uniform restrict writeonly image2D edge_half;
// THE TOWNS (step 3): a texel each, centre x, ground y, z and radius -- `MistLayer.show_towns`' texture.
layout(set = 0, binding = 7) uniform sampler2D mist_towns;

// EVERY NUMBER MistLayer writes as a `mist_*` global, packed by MistEffect (std140: vec4s and a mat4, no holes), plus the eye.
layout(set = 0, binding = 5, std140) uniform Params {
	vec4 haze;
	vec4 stratus;
	vec4 stratus_look;
	vec4 colour;
	vec4 sun_colour;
	vec4 towards_sun_steps;         // xyz towards the sun, w steps
	vec4 sun_clock;                 // xyz glow, tightness, drift; w the mist's clock
	vec4 chart_frame;
	vec4 ground_ceiling_reach;      // x lowest ground, y highest, z ceiling, w reach
	vec4 cover_sky;                 // xy stratus cover, z how far a sky pixel's ray is taken, w the edge share
	vec4 town;                      // the towns' domes: count, density at the ground, height, spread in radii
	vec4 town_glow;                 // xyz the light the domes put back at night
	vec4 pool;                      // the valley pools: x the most extra haze, y metres below the surroundings for it
	vec4 eye;                       // xyz the midpoint of the eyes in the world
	mat4 to_world;                  // the camera's rotation, view to world
} params;

layout(push_constant, std430) uniform Push {
	mat4 inv_projection;            // this view's, depth-corrected as the engine's own (render_scene_data_rd.cpp)
	vec2 full_size;
	vec2 half_size;
} push;

#define mist_haze params.haze
#define mist_stratus params.stratus
#define mist_stratus_cover params.cover_sky.xy
#define mist_stratus_look params.stratus_look
#define mist_colour params.colour
#define mist_sun_colour params.sun_colour
#define mist_towards_sun params.towards_sun_steps.xyz
#define mist_sun params.sun_clock.xyz
#define mist_steps int(params.towards_sun_steps.w)
#define mist_chart_frame params.chart_frame
#define mist_ground_range params.ground_ceiling_reach.xy
#define mist_ceiling params.ground_ceiling_reach.z
#define mist_reach params.ground_ceiling_reach.w
#define mist_town params.town
#define mist_town_glow params.town_glow.xyz
#define mist_pool params.pool

#include "mist_core.gdshaderinc"

// THE MIST AT ONE FULL-RESOLUTION PIXEL, from its own depth: the sky's ray where the depth buffer holds nothing.
vec4 mist_at(ivec2 pixel, float depth) {
	vec2 uv = (vec2(pixel) + 0.5) / push.full_size;
	vec3 eye = params.eye.xyz;
	mat3 to_world = mat3(params.to_world);
	if (depth <= 0.0) {
		vec4 near = push.inv_projection * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
		return mist_along(eye, eye + to_world * normalize(near.xyz / near.w) * params.cover_sky.z, params.sun_clock.w);
	}
	vec4 view = push.inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return mist_along(eye, eye + to_world * (view.xyz / view.w), params.sun_clock.w);
}

void main() {
	ivec2 here = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(here, ivec2(push.half_size)))) {
		return;
	}
	ivec2 corner = here * 2;
	ivec2 last = ivec2(push.full_size) - 1;
	// REVERSE Z: the nearest surface has the largest depth, and the sky is 0.
	float near_depth = -1.0;
	float far_depth = 2.0;
	ivec2 near_pixel = corner;
	ivec2 far_pixel = corner;
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			ivec2 pixel = min(corner + ivec2(i, j), last);
			float d = texelFetch(depth_full, pixel, 0).r;
			if (d > near_depth) {
				near_depth = d;
				near_pixel = pixel;
			}
			if (d < far_depth) {
				far_depth = d;
				far_pixel = pixel;
			}
		}
	}
	vec4 near_mist = mist_at(near_pixel, near_depth);
	bool two_surfaces = near_depth > 0.0 && (near_depth - far_depth) / near_depth > params.cover_sky.w;
	vec4 far_mist = two_surfaces ? mist_at(far_pixel, far_depth) : near_mist;
	imageStore(mist_half, here, near_mist);
	imageStore(depth_half, here, vec4(near_depth, two_surfaces ? far_depth : near_depth, 0.0, 0.0));
	imageStore(far_half, here, far_mist);
	// THE EDGE MASK for the blended composite: this texel holds two surfaces, or a neighbouring texel's 2 by 2 (read at its corner
	// pixel) is sky against this surface or another surface by more than the edge share -- where one linear tap would bleed.
	bool edge = two_surfaces;
	ivec2 half_last = ivec2(push.half_size) - 1;
	ivec2 offsets[4] = ivec2[4](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
	for (int n = 0; n < 4 && !edge; n++) {
		ivec2 other = clamp(here + offsets[n], ivec2(0), half_last);
		float d = texelFetch(depth_full, min(other * 2, last), 0).r;
		if ((d <= 0.0) != (near_depth <= 0.0)) {
			edge = true;
		} else if (near_depth > 0.0 && abs(d - near_depth) / max(d, near_depth) > params.cover_sky.w) {
			edge = true;
		}
	}
	imageStore(edge_half, here, vec4(edge ? 1.0 : 0.0));
}
