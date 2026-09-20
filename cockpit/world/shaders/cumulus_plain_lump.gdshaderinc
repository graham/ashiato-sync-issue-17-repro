// CUMULUS, ON THE PLAIN FINISH: one lump, lit per vertex, for its two passes -- `cumulus_plain.gdshader` the opaque CORE and
// `cumulus_plain_rim.gdshader` (`#define RIM_PASS`) the blended RIM, meeting where the facing's coverage is `CORE_COVERAGE`.
//
// ALL OF IT IN THE VERTEX. Each lump is a 24 by 12 sphere (12 by 8 until the rim was blended, when its facets showed); below its cloud's base (INSTANCE_CUSTOM.r, the top of the lift zone)
// it is cut off level, and the light (cloud_light.gdshaderinc, shared with FINE) is worked out at each vertex through its
// cloud's envelope and interpolated. Unshaded, so the engine's per-pixel light and shadow lookups are not paid for.
//
// THE EDGE WAS A HASH STIPPLE (2026-09-14, "softer edges"): the facing against a hash of the fragment's cell, every rim pixel
// drawn or not, which team-lead read off the survey pictures as salt and pepper that would crawl in a headset. It is a blended
// falloff now, from the facing alone, which is the same in both eyes. See cumulus_lump.gdshaderinc for why unsorted rims blend.
// REJECTED: greying the low lumps by instance colour alone (no flat base, which is what makes a heap read as a cumulus).

#include "res://world/shaders/eye.gdshaderinc"
#include "res://world/shaders/cloud_light.gdshaderinc"
#include "res://world/shaders/cloud_envelopes.gdshaderinc"
#include "res://world/shaders/cloud_rim.gdshaderinc"
#ifdef RIM_PASS
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;
#endif

// See cumulus_lump.gdshaderinc for 0.35 and 0.8.
const float CORE_COVERAGE = 0.35;
const float RIM_RAMP = 0.8;

varying vec3 colour;
// THE FACING ONCE A PIXEL (step1-rim/after, clouds-plain-day, 2026-09-15): worked out once a vertex, the rim's falloff ran
// straight across each triangle of the 12 by 8 sphere and a lump's outline read as its facets, which the stipple had hidden.
// A dot product a pixel costs nothing beside the blend; the light stays once a vertex.
varying vec3 world_at;
varying vec3 world_normal;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float scale_y = max(length(MODEL_MATRIX[1].xyz), 0.001);
	float base_y = INSTANCE_CUSTOM.r;
	float thickness = max(INSTANCE_CUSTOM.g, 1.0);
	vec3 moved = VERTEX;
	vec3 facing = NORMAL;
	float floor_y = (base_y - centre.y) / scale_y;
	if (moved.y < floor_y) {
		moved.y = floor_y;
		facing = normalize(mix(NORMAL, vec3(0.0, -1.0, 0.0), 0.9));
	}
	vec3 at = (MODEL_MATRIX * vec4(moved, 1.0)).xyz;
	vec3 n = normalize((MODEL_MATRIX * vec4(facing, 0.0)).xyz);
	vec3 to_eye = normalize(EYE_POSITION_WORLD - at);
	float facing_eye = abs(dot(n, to_eye));
	float thin = 1.0 - smoothstep(0.0, 0.30, facing_eye);
	world_at = at;
	world_normal = n;
#ifdef RIM_PASS
	mist_here = mist_along(EYE_POSITION_WORLD, at, mist_clock);
#endif
	int cloud = CLOUD_OF_INSTANCE;
	vec3 env_centre = envelope_at[cloud].xyz;
	vec3 env_radii = envelope_radii[cloud].xyz;
	colour = cloud_light(n, to_eye, clamp((at.y - base_y) / thickness, 0.0, 1.0), thickness, 0.0, thin,
		envelope_sun_depth(at, env_centre, env_radii), envelope_buried(at, env_centre, env_radii));
	VERTEX = moved;
	NORMAL = facing;
}

void fragment() {
	ALBEDO = colour;
	float facing_eye = abs(dot(normalize(world_normal), normalize(EYE_POSITION_WORLD - world_at)));
	float edge_alpha = smoothstep(0.0, RIM_RAMP, facing_eye);
	// FILTERED OVER THE PIXEL (cloud_rim.gdshaderinc): the rim's ramp averaged over the pixel, and the core cut only where
	// the whole pixel is past CORE_COVERAGE, so the cut is a one-pixel blend with no MSAA and needs no alpha to coverage.
	float footprint = cloud_rim_footprint(edge_alpha);
	float cut = cloud_core_cut(CORE_COVERAGE, footprint);
#ifdef RIM_PASS
	if (edge_alpha >= cut) {
		discard;
	}
	ALPHA = cloud_rim_alpha(edge_alpha, CORE_COVERAGE, footprint);
		ALBEDO = mix(ALBEDO, mist_here.rgb, mist_here.a);
#else
	ALPHA = edge_alpha;
	ALPHA_SCISSOR_THRESHOLD = cut;
#endif
}
