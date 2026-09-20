// GRASS, at every distance from a metre to eight kilometres.
//
// The difficulty is not making it look like grass close up, it is stopping it turning into
// a seething mess in the distance -- which is what any high-frequency detail does once it
// is smaller than a pixel, and which is far more obvious in a headset than on a monitor.
// So every scale of detail here fades out at the range where it stops being resolvable,
// and what is left far away is the broad colour variation, which is what you actually see
// of a landscape from a mile up.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
#include "res://world/shaders/eye.gdshaderinc"

#include "res://world/shaders/terrain_noise.gdshaderinc"
// The ground under every wood: see `world/woodland.gd`, which sets its uniforms once.
#include "res://world/shaders/forest_floor.gdshaderinc"

uniform vec3 dry_colour : source_color = vec3(0.36, 0.38, 0.22);
uniform vec3 lush_colour : source_color = vec3(0.16, 0.31, 0.14);
uniform vec3 earth_colour : source_color = vec3(0.29, 0.25, 0.18);
uniform float patch_scale = 0.0016;
uniform float clump_scale = 0.035;
uniform float blade_scale = 0.9;
uniform float earth_amount : hint_range(0.0, 1.0) = 0.35;
// HOW NEAR EACH BAND OF DETAIL IS WORTH DRAWING, in metres, as (full, gone). Set from `DetailReach` at build, which
// is the one place these live -- they were typed here as literals until 2026-09-20.
//
// THE DEFAULT DRAWS EVERYTHING EVERYWHERE and that is deliberate. A default of "no detail" would make a wiring
// failure look like the ground simply being plain, which is invisible; this one makes it boil to the horizon, which
// nobody can miss. `mountain_view.gd` uses the same 1e9 sentinel for the same reason.
// Written out rather than as `1.0e9 + 1.0`: a uniform's default must be a CONSTANT EXPRESSION and that sum is not
// one. It compiled nowhere and the runner's error gate caught it in seven suites at once, while the suite run on
// its own still printed RESULT=PASS -- a shader that fails to compile does not fail a check, it just draws with the
// fallback.
uniform vec2 clump_fade = vec2(1.0e9, 1.00001e9);
uniform vec2 blade_fade = vec2(1.0e9, 1.00001e9);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist = length(world_pos - EYE_POSITION_WORLD);
	float mid = detail_fade(dist, clump_fade.x, clump_fade.y);
	float close = detail_fade(dist, blade_fade.x, blade_fade.y);

	// Fields and dry patches, kilometres across. This one never fades: it is the only
	// thing left at range and it is what stops the island being one flat green.
	// Gradient noise, each octave turned: value noise's lattice drew fans from 300 m (terrain_noise.gdshaderinc).
	float patches = fbm3_turned(world_pos.xz * patch_scale, LATTICE_PERIOD);
	vec3 albedo = mix(dry_colour, lush_colour, smoothstep(0.35, 0.75, patches));

	// Clumps, tens of metres across. No tile() in front: the wrapped lattice already bounds the index, and a tile of
	// 4,096 m (143.36 cells, not a multiple of the period) drew a straight seam at every multiple of 4,096 m, world
	// x = 0 and z = 0 beside the airfield included (2026-09-14, godotgames-drafts/.../cockpit-double/p8). Gradient noise,
	// turned, as the patches are.
	if (mid > 0.001) {
		float clumps = fbm2_turned(world_pos.xz * clump_scale, LATTICE_PERIOD);
		albedo = mix(albedo, albedo * (0.74 + 0.52 * clumps), mid);
		// Bare earth where the grass thins out, which is where a landscape stops looking
		// painted.
		albedo = mix(albedo, earth_colour,
			smoothstep(0.62, 0.86, clumps * patches * 1.6) * earth_amount * mid);
	}

	// Blades, and only within a few tens of metres. Past that they are sub-pixel and all
	// they do is boil.
	if (close > 0.001) {
		float blades = value_noise(tile(world_pos.xz, 64.0) * blade_scale);
		albedo *= 1.0 - 0.20 * close * (1.0 - blades);
	}

	// AND UNDER A WOOD, the forest floor: dark, green, and still patchy with the fields under it.
	albedo = mix(albedo, floor_colour * (0.8 + 0.4 * patches),
		forest_floor(world_pos.xz) * floor_strength);

	ALBEDO = albedo;
	ROUGHNESS = 0.95;
}
