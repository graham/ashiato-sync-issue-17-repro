// ROCK, and CONCRETE from the same shader with different numbers.
//
// The scenery is axis-aligned BOXES, which turns the expensive part of this into nothing:
// a triplanar material normally blends three projections per pixel, but every face here
// has a normal along exactly one axis, so the right projection can be CHOSEN instead of
// blended. Three lookups become one.
//
// A MOUNTAIN IS LIT AS A MOUNTAIN (2026-09-13): each step is lit partly as the slope of the peak it belongs to, its
// inner corners darken, scree lies against the wall above a tread, scrub on the low lips and snow on the high treads.
// All of it from `peak_slope` (rock_slope.gdshaderinc) and `RockTuning`'s numbers -- no texture, no vertex moved,
// one smoothstep or two a pixel. Before, every box was lit on its own and the island's mountains read as stepped
// grey pyramids. Concrete carries no peak and is drawn exactly as it was.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
#include "res://world/shaders/eye.gdshaderinc"

#include "res://world/shaders/terrain_noise.gdshaderinc"
#include "res://world/shaders/rock_slope.gdshaderinc"

uniform vec3 low_colour : source_color = vec3(0.22, 0.21, 0.20);
uniform vec3 high_colour : source_color = vec3(0.46, 0.44, 0.41);
uniform vec3 face_colour : source_color = vec3(0.34, 0.32, 0.30);
uniform float strata : hint_range(0.0, 0.4) = 0.10;
uniform float grain : hint_range(0.0, 1.0) = 0.55;
uniform float coarse_scale = 0.010;
uniform float fine_scale = 0.22;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
// ---- RockTuning's, set by SceneryYard.draw_boxes ----
uniform vec4 slope_share = vec4(0.30, 0.80, 300.0, 3000.0);
uniform vec3 corner = vec3(0.25, 1.0, 0.55);
uniform vec3 scree_colour : source_color = vec3(0.47, 0.44, 0.39);
uniform vec2 scree = vec2(0.45, 0.65);
uniform vec3 scrub_colour : source_color = vec3(0.24, 0.28, 0.17);
uniform vec2 scrub_height = vec2(160.0, 320.0);
uniform vec3 snow_colour : source_color = vec3(0.90, 0.92, 0.95);
uniform vec2 snow_height = vec2(400.0, 40.0);

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 peak;
varying float riser;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	peak = INSTANCE_CUSTOM;
	riser = length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	bool top = n.y > max(n.x, n.z) && world_normal.y > 0.0;
	// The dominant axis, picked rather than blended. See the note at the top.
	vec2 flat_uv = n.y > max(n.x, n.z)
		? world_pos.xz
		: (n.x > n.z ? world_pos.zy : world_pos.xy);

	float dist = length(world_pos - EYE_POSITION_WORLD);
	float near = detail_fade(dist, 400.0, 2600.0);

	// Broad shape first: which part of the mountain this is, not what it is made of.
	float shape = fbm3_wrapped(flat_uv * coarse_scale, LATTICE_PERIOD);
	// Bedding planes, which is most of what makes rock read as rock rather than as noise.
	float bands = sin(world_pos.y * strata * 6.28318 + shape * 5.0) * 0.5 + 0.5;
	// And the grain, wrapped for precision and faded out before it can sparkle.
	float fine = near > 0.001
		? fbm2(tile(flat_uv, 256.0) * fine_scale) * near
		: 0.0;

	float height = clamp(world_pos.y * 0.0022 + shape * 0.5, 0.0, 1.0);
	vec3 albedo = mix(low_colour, high_colour, height);
	albedo = mix(albedo, face_colour, bands * 0.35);
	// A flat top is a ledge and catches light; a wall is a face and does not.
	albedo *= 0.82 + 0.18 * n.y;
	albedo *= 0.86 + grain * 0.28 * fine;

	vec3 lit = world_normal;
	vec4 slope = peak_slope(world_pos, peak, riser);
	if (slope.w >= 0.0) {
		float under = slope.w;
		lit = normalize(mix(world_normal, slope.xyz,
			mix(slope_share.x, slope_share.y, smoothstep(slope_share.z, slope_share.w, dist))));
		if (top) {
			float fallen = smoothstep(scree.x, 1.0, under) * scree.y;
			albedo = mix(albedo, scree_colour, fallen * (0.7 + 0.3 * shape));
			float scrubby = (1.0 - smoothstep(scrub_height.x, scrub_height.y, world_pos.y))
				* (1.0 - smoothstep(0.15, 0.6, under)) * smoothstep(0.4, 0.6, shape);
			albedo = mix(albedo, scrub_colour, scrubby * 0.8);
			float snowy = smoothstep(snow_height.x - snow_height.y, snow_height.x + snow_height.y,
				world_pos.y + (shape - 0.5) * 80.0) * mix(0.55, 1.0, smoothstep(0.0, 0.8, under));
			albedo = mix(albedo, snow_colour, snowy);
		}
		albedo *= mix(1.0, corner.z, smoothstep(corner.x, corner.y, under));
	}

	ALBEDO = albedo;
	ROUGHNESS = roughness_value - 0.10 * fine;
	NORMAL = normalize((VIEW_MATRIX * vec4(lit, 0.0)).xyz);
	// A little normal detail, and only where it is worth having. Derived from the same
	// noise rather than a second lookup.
	NORMAL_MAP = vec3(0.5 + (fine - 0.5) * 0.35 * near,
		0.5 + (bands - 0.5) * 0.25 * near, 1.0);
}
