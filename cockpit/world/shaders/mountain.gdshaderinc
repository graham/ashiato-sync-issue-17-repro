// THE MOUNTAINS' ROCK, both finishes: what a facet is made of, and the grit the geometry does not carry.
//
// THE GEOMETRY IS THE COLLISION (range_core.hpp), 48 m facets, and this never moves a vertex: it colours and lights
// what is there. Everything below reads three things -- where the pixel is, which way its facet faces, and the two grit
// channels in COLOR that the function baked into each vertex: red, how deep in a gully; green, how far down the flank.
//
// FACETED NEAR, SMOOTH FAR. A facet is lit flat, from the screen-space derivative of its own view position -- the house's
// low-poly look, the Hawkeye's (modelling_here.md) -- and between `smooth_from.x` and `.y` metres that blends to the
// smooth vertex normal MountainView built, because a facet smaller than a pixel lit flat flickers between its neighbours'
// lights as the view moves.
//
// WHAT IS PAINTED, in order: rock from dark at the foot to pale at the top, warped by a broad noise; STRATA, bands of
// bedding along the height; SCRUB on gentle low facets; SCREE where a flank meets the valley floor, on facets gentle
// enough to hold it; the GULLY RIMS, the edges of each gully drawn as a darker line -- the "valley edges"; a CREEK down
// the bottom of every gully below its head, dark and a little blue; and SNOW on facets over the snow line and gentle
// enough to hold it, lower in a gully's shade. Every number is RockTuning's.
//
// THE FOOT IS THE ISLAND'S GRASS: below `foot_blend.y` metres a facet takes the ground's own broad field colour
// (grass.gdshader's patches, from the numbers MountainView copies off the ground's material), so the lowest facets, a few
// metres over the grass, are grassy slope and not grey puddles on it (the first after pictures, 2026-09-18).
//
// ITS OWN HAZE, THINNER WITH HEIGHT. The world's air is exponential fog of one density at every height (DaylightTuning's
// `clear_air`, 0.00016 a metre by day), which leaves 5.6% of anything 18 km off: from out at sea the island had no
// mountains at all. Real haze thins with height, and a ridge stands above most of it. So this writes FOG itself: the
// Environment's own density, colour and aerial perspective, handed over every frame by MountainView, with the density
// thinned by the facet's height -- not at all at the foot, so the foot fades exactly as the grass beside it does, and to
// `haze_thin.y` of it by `haze_thin.x` metres. Thinning the DENSITY and not the amount keeps a cloud's whiteout, whose
// density is hundreds of times the clear air's, as white as it was.
//
// NEVER CAMERA_POSITION_WORLD: see eye.gdshaderinc.
#include "res://world/shaders/eye.gdshaderinc"
#include "res://world/shaders/terrain_noise.gdshaderinc"

uniform vec3 low_colour : source_color = vec3(0.30, 0.28, 0.26);
uniform vec3 high_colour : source_color = vec3(0.55, 0.53, 0.50);
uniform vec3 band_colour : source_color = vec3(0.40, 0.36, 0.32);
uniform vec3 scree_colour : source_color = vec3(0.47, 0.44, 0.39);
uniform vec3 scrub_colour : source_color = vec3(0.24, 0.28, 0.17);
uniform vec3 creek_colour : source_color = vec3(0.10, 0.12, 0.14);
uniform vec3 snow_colour : source_color = vec3(0.90, 0.92, 0.95);
// Metres a top-to-bottom shade runs over, and the broad noise's say in it.
uniform vec2 shade = vec2(620.0, 0.35);
// STRATA: metres between beds, how strong, and how far a bed wanders up and down.
uniform vec3 strata = vec3(26.0, 0.30, 30.0);
// SCRUB: the height it thins from and is gone by, and the flattest facet it needs (normal y).
uniform vec3 scrub = vec3(140.0, 320.0, 0.80);
// SCREE: how far down the flank it starts (green channel), and the facet it needs.
uniform vec2 scree = vec2(0.72, 0.55);
// GULLY RIMS: where on the red channel the rim lies, how wide, and how dark.
uniform vec3 rim = vec3(0.45, 0.10, 0.25);
// CREEK: the red channel it starts at, how far down the flank a gully must be before it carries one, and how dark.
uniform vec3 creek = vec3(0.86, 0.22, 0.65);
// FACETS: how much each facet's own tone wanders, as a share of its colour -- the low-poly look, one tone a triangle.
uniform float facet_tone = 0.07;
// GULLY SHADE: how much darker the bottom of a gully is than the spur beside it, so the pattern of spurs and gullies
// reads from kilometres off, where a creek is under a pixel.
uniform float gully_shade = 0.28;
// SNOW: the line, the blend round it, the flattest facet it lies on (normal y), and how much lower it lies in a gully.
uniform vec4 snow = vec4(400.0, 40.0, 0.62, 90.0);
// Metres between which a facet's flat light blends to the smooth normal, and the fine grain fades.
uniform vec2 smooth_from = vec2(2500.0, 7000.0);
uniform vec2 grain_fade = vec2(300.0, 2000.0);
// The foot: the ground's field colours and scale (the island ground's own), and the heights the blend runs over.
uniform vec3 dry_colour : source_color = vec3(0.36, 0.38, 0.22);
uniform vec3 lush_colour : source_color = vec3(0.16, 0.31, 0.14);
uniform float patch_scale = 0.0016;
uniform vec2 foot_blend = vec2(2.0, 30.0);
// The haze: the Environment's density and colour (already mixed toward the horizon by its aerial perspective), and the
// height by which the density is thinned to what share.
uniform float haze_density = 0.00016;
uniform vec3 haze_colour : source_color = vec3(0.518, 0.553, 0.608);
uniform vec2 haze_thin = vec2(700.0, 0.4);
// THE FAR BLUE: from `far_blue.x` to `.y` metres the rock's own colour turns toward `far_colour`, by `far_share` at most --
// a distant range reads as a blue-grey silhouette against a paler sky, not as pale snow fading into it.
uniform vec3 far_colour : source_color = vec3(0.30, 0.36, 0.46);
uniform vec2 far_blue = vec2(6000.0, 16000.0);
uniform float far_share = 0.7;

varying vec3 world_pos;
varying vec3 world_smooth;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_smooth = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float dist = length(world_pos - EYE_POSITION_WORLD);
	// THE FACET'S OWN NORMAL, from its view position's derivatives, turned to face the eye (only front faces are drawn).
	vec3 flat_view = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	flat_view *= sign(dot(flat_view, -VERTEX));
	vec3 flat_world = normalize(mat3(INV_VIEW_MATRIX) * flat_view);
	vec3 n = normalize(mix(flat_world, normalize(world_smooth), smoothstep(smooth_from.x, smooth_from.y, dist)));
	float up = n.y;
	// ONE TONE A FACET: a hash of the facet's own normal, which is the same everywhere on it and different on its
	// neighbour. Faded with the flat light, so a far facet under a pixel does not sparkle.
	float facet = fract(sin(dot(flat_world, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float faceted = 1.0 - smoothstep(smooth_from.x, smooth_from.y, dist);
	float gully = COLOR.r;
	float down = COLOR.g;

	float broad = fbm3_wrapped(world_pos.xz * 0.004, LATTICE_PERIOD);
	vec3 albedo = mix(low_colour, high_colour, clamp(world_pos.y / shade.x + (broad - 0.5) * shade.y, 0.0, 1.0));
	// STRATA: beds along the height, wandered by the broad noise so they are not contour lines.
	float bed = world_pos.y + (broad - 0.5) * 2.0 * strata.z;
	float bands = smoothstep(0.55, 0.95, sin(bed * 6.28318 / strata.x) * 0.5 + 0.5);
	albedo = mix(albedo, band_colour, bands * strata.y * (1.0 - up * 0.6));

#ifdef MOUNTAIN_FINE
	float near = detail_fade(dist, grain_fade.x, grain_fade.y);
	float grain = near > 0.001 ? fbm2(tile(world_pos.xz + world_pos.y, 256.0) * 0.21) * near : 0.0;
	albedo *= 0.88 + 0.24 * grain;
	// A creek meanders inside its gully rather than following the facets' straight edges.
	float meander = fbm2_wrapped(world_pos.xz * 0.02, LATTICE_PERIOD) - 0.5;
#else
	float grain = 0.0;
	float meander = 0.0;
#endif

	// SCRUB on gentle low facets, patchy by the broad noise.
	float scrubby = (1.0 - smoothstep(scrub.x, scrub.y, world_pos.y)) * smoothstep(scrub.z - 0.1, scrub.z + 0.05, up)
		* smoothstep(0.35, 0.6, broad + 0.2 * (1.0 - down));
	albedo = mix(albedo, scrub_colour, scrubby * 0.85);
	// SCREE where a flank reaches the valley floor.
	float fallen = smoothstep(scree.x, 1.0, down) * smoothstep(scree.y - 0.1, scree.y + 0.1, up);
	albedo = mix(albedo, scree_colour, fallen * (0.75 + 0.25 * broad));
	// THE GULLY'S SHADE, the whole of it, deepening down the flank as the gully does.
	albedo *= 1.0 - gully_shade * smoothstep(0.2, 0.9, gully) * smoothstep(0.05, 0.35, down);
	// THE GULLY RIMS: a darker line along each gully's edge, the break between a spur's shoulder and the cut below it.
	float edge = 1.0 - smoothstep(0.0, rim.y, abs(gully - rim.x));
	albedo *= 1.0 - edge * rim.z * smoothstep(0.1, 0.3, down);
	// THE CREEK, down the bottom of a gully below its head.
	float wet = smoothstep(creek.x - 0.04 + meander * 0.1, creek.x + 0.04 + meander * 0.1, gully)
		* smoothstep(creek.y, creek.y + 0.15, down);
	albedo = mix(albedo, creek_colour, wet * creek.z);
	// SNOW over the line, on facets flat enough to hold it, lower where a gully shades it.
	float line = snow.x - gully * snow.w + (broad - 0.5) * 80.0;
	float snowy = smoothstep(line - snow.y, line + snow.y, world_pos.y) * smoothstep(snow.z - 0.08, snow.z + 0.08, up);
	albedo = mix(albedo, snow_colour, snowy * (1.0 - wet * 0.6));

	// THE FOOT, grass as the ground beside it is: see the top.
	float fields = fbm3_turned(world_pos.xz * patch_scale, LATTICE_PERIOD);
	vec3 grass = mix(dry_colour, lush_colour, smoothstep(0.35, 0.75, fields));
	albedo = mix(albedo, grass, 1.0 - smoothstep(foot_blend.x, foot_blend.y, world_pos.y));

	albedo *= 1.0 + (facet - 0.5) * 2.0 * facet_tone * faceted;
	// THE FAR BLUE: see the uniforms.
	albedo = mix(albedo, far_colour, far_share * smoothstep(far_blue.x, far_blue.y, dist));

	ALBEDO = albedo;
	float thin = mix(1.0, haze_thin.y, smoothstep(0.0, haze_thin.x, world_pos.y));
	FOG = vec4(haze_colour, 1.0 - exp(-haze_density * dist * thin));
	ROUGHNESS = 0.92 - 0.3 * wet - 0.1 * grain;
	NORMAL = normalize(mat3(VIEW_MATRIX) * n);
}
