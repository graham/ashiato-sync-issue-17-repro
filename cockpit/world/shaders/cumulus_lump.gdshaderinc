// CUMULUS, ON THE FINE FINISH: one lump's shape, light and coverage, for its two passes. `cumulus.gdshader` draws the CORE
// opaque, cut where the coverage falls under `CORE_COVERAGE`; `cumulus_rim.gdshader` (`#define RIM_PASS`) draws the RIM
// blended, from nothing at the silhouette up to whole where the core begins, so the edge is a smooth falloff and not a stipple.
//
// WHY TWO PASSES (asked for on 2026-09-15 by team-lead, off the survey's cumulus_side: "coarse salt-and-pepper stipple several
// pixels deep. In VR that will crawl and differ between eyes"). The rim was ALPHA_SCISSOR_THRESHOLD against a hash of the
// lump's cells: every pixel of the outer 0.55 of the facing either drawn or not. One blended lump batch cannot be sorted, which
// is why it was dithered; but a rim is low alpha over a core of the same colour, so the order the rims blend in does not show,
// and each rim is depth-tested against every core in front of it. The core and the rim meet where the coverage is
// `CORE_COVERAGE`, and the rim's alpha is 1 there, so no seam. Both read only world-space noise and the midpoint of the eyes.
//
// THE LIGHT is cloud_light.gdshaderinc's, shared with PLAIN. CAULIFLOWER: each lump's surface is pushed out along its normal by
// 3D noise at two scales, seeded by its cloud, drifting slowly with TIME so the cloud boils. ONE BASE A CLOUD: below its base
// (INSTANCE_CUSTOM.r) a lump is cut off level.
//
// REJECTED: raymarching a density field (a cloud you fly through fills both eyes); FRAGCOORD dither and the engine's alpha hash
// (both pick cells per pixel, so per eye); alpha to coverage (two samples on FINE: three levels, a coarser stipple; and PLAIN, a headset's default, has no MSAA).

#include "res://world/shaders/eye.gdshaderinc"
#include "res://world/shaders/air_noise.gdshaderinc"
#include "res://world/shaders/cloud_light.gdshaderinc"
#include "res://world/shaders/cloud_envelopes.gdshaderinc"
#include "res://world/shaders/cloud_rim.gdshaderinc"
#ifdef RIM_PASS
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;
#endif

// How far a lump's surface is pushed in and out, as a fraction of its own radius.
uniform float billow : hint_range(0.0, 0.5) = 0.24;
// How fast the lumps change shape. Slow: a cloud that visibly churns reads as smoke.
uniform float boil = 0.05;
// Where the core ends and the rim begins, as coverage, and how far into the facing the rim's falloff runs. 0.35 and 0.8, not
// 0.5 and 0.55 (team-lead off glassrim-zoom4, 2026-09-15): the core's hard cut stair-stepped along a lump's top edge seen
// from above, and the rim was a narrow darker band with a light lip; a lower cut and a wider ramp spread the rim over more
// pixels.
const float CORE_COVERAGE = 0.35;
const float RIM_RAMP = 0.8;

varying vec3 world_pos;
varying vec3 world_normal;
varying float rise;
varying float lump;
varying float size;
varying float thickness;
varying vec3 local_pos;
varying flat float fade;
varying flat vec3 env_centre;
varying flat vec3 env_radii;

void vertex() {
	int cloud = CLOUD_OF_INSTANCE;
	env_centre = envelope_at[cloud].xyz;
	env_radii = envelope_radii[cloud].xyz;
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	size = max(scale.x, 1.0);
	float base_y = INSTANCE_CUSTOM.r;
	thickness = max(INSTANCE_CUSTOM.g, 1.0);
	float seed = INSTANCE_CUSTOM.b;
	fade = INSTANCE_CUSTOM.a;
	vec3 dir = normalize(VERTEX);
	vec3 drift = vec3(0.0, TIME * boil, TIME * boil * 0.6);
	float shape = fbm3_3d(dir * 2.4 + seed * 91.7 + centre * 0.013 + drift);
	float florets = value_noise3(dir * 7.0 + seed * 37.1 + drift * 2.0);
	lump = shape;
	vec3 moved = VERTEX + NORMAL * ((shape - 0.45) * billow + (florets - 0.5) * billow * 0.5);
	vec3 facing = NORMAL;
	float floor_y = (base_y - centre.y) / max(scale.y, 0.001);
	if (moved.y < floor_y) {
		moved.y = floor_y;
		facing = normalize(mix(NORMAL, vec3(0.0, -1.0, 0.0), 0.9));
	}
	world_pos = (MODEL_MATRIX * vec4(moved, 1.0)).xyz;
	rise = clamp((world_pos.y - base_y) / thickness, 0.0, 1.0);
	local_pos = moved + centre * 0.001;
	VERTEX = moved;
	NORMAL = facing;
	world_normal = normalize((MODEL_MATRIX * vec4(facing, 0.0)).xyz);
#ifdef RIM_PASS
	mist_here = mist_along(EYE_POSITION_WORLD, world_pos, mist_clock);
#endif
}

void fragment() {
	vec3 to_eye = normalize(EYE_POSITION_WORLD - world_pos);
	vec3 n = normalize(world_normal);
	float grain = fbm2_3d(world_pos * (7.0 / size));
	float edge = abs(dot(n, to_eye));
	float rim = smoothstep(0.0, 0.55, edge);
	ALBEDO = cloud_light(n, to_eye, rise, thickness, (lump - 0.5) * 0.25 + (grain - 0.5) * 0.15, 1.0 - rim,
		envelope_sun_depth(world_pos, env_centre, env_radii), envelope_buried(world_pos, env_centre, env_radii));
	// THE COVERAGE: the facing eaten into by the grain, and given way to the fog in soft clumps keyed to the lump. All of it
	// value noise in the lump's own frame -- smooth, the same in both eyes, nothing hashed per cell.
	// The light keeps its own 0.55 ramp (its lining); only the coverage falls off over RIM_RAMP.
	float fall = smoothstep(0.0, RIM_RAMP, edge);
	float coverage = clamp(fall + (grain - 0.5) * 0.6 * (1.0 - fall), 0.0, 1.0);
	// AT FIXED FREQUENCIES IN THE LUMP'S FRAME: the old clumps' frequency stepped by powers of two with range, which a hashed
	// stipple hid and a smooth falloff would show as a pop.
	float blotch = mix(value_noise3(local_pos * 16.0), value_noise3(local_pos * 6.0), 0.35);
	coverage *= smoothstep(fade * 1.2 - 0.1, fade * 1.2 - 0.02, blotch);
	// FILTERED OVER THE PIXEL (cloud_rim.gdshaderinc): the rim's ramp averaged over the pixel, and the core cut only where
	// the whole pixel is past CORE_COVERAGE, so the cut is a one-pixel blend with no MSAA and needs no alpha to coverage.
	float footprint = cloud_rim_footprint(coverage);
	float cut = cloud_core_cut(CORE_COVERAGE, footprint);
#ifdef RIM_PASS
	if (coverage >= cut) {
		discard;
	}
	ALPHA = cloud_rim_alpha(coverage, CORE_COVERAGE, footprint);
		ALBEDO = mix(ALBEDO, mist_here.rgb, mist_here.a);
#else
	ALPHA = coverage;
	ALPHA_SCISSOR_THRESHOLD = cut;
#endif
}
