// GRASS, ON THE FINE FINISH: the plain grass, with the wind in it and ground under it.
//
// Everything in grass.gdshader still holds, and its three scales of colour are here unchanged.
// What the plain field lacks is the two things a real one does from the air:
//
//   IT MOVES. Wind over long grass bends it, and bent grass shows its paler side, so gusts are
//   bright bands rolling across a field downwind at the wind's speed. From two thousand feet
//   that is the only movement on the ground, and it is how a glider pilot sees the air near it.
//   The same gust is read by the blades standing in it -- `gust_at`, one function.
//
//   IT IS NOT FLAT. Hummocks tens of metres across, lit: the slope of the clump noise comes out
//   of the same four hashes (`value_noise_d`) and tilts the normal, so the sun picks out ground
//   the plain finish paints as colour. Hollows darken a little besides, which is where a
//   landscape stops looking printed.
//
// Cost against the plain field: one more value-noise lookup for the relief and two for the gust,
// on top of the plain six. Measured in agents.md.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
#include "res://world/shaders/eye.gdshaderinc"

#include "res://world/shaders/terrain_noise.gdshaderinc"
#include "res://world/shaders/terrain_relief.gdshaderinc"
// The ground under every wood, with the ragged edge the fine finish gives it.
#define FINE
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
// Which way the air is moving, in metres a second. Set from Terrain.WIND.
uniform vec2 wind = vec2(5.4, -2.6);
// How much brighter the grass is where a gust has bent it over.
uniform float gust_sheen : hint_range(0.0, 1.0) = 0.32;
// How many metres tall the hummocks are lit as being.
uniform float hummock_height = 4.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist = length(world_pos - EYE_POSITION_WORLD);
	float mid = detail_fade(dist, clump_fade.x, clump_fade.y);
	float close = detail_fade(dist, blade_fade.x, blade_fade.y);

	// Gradient noise, each octave turned, as in grass.gdshader: value noise's lattice drew fans from 300 m.
	float patches = fbm3_turned(world_pos.xz * patch_scale, LATTICE_PERIOD);
	vec3 albedo = mix(dry_colour, lush_colour, smoothstep(0.35, 0.75, patches));
	vec3 normal = vec3(0.0, 1.0, 0.0);

	// THE GUSTS, which never fade: they are kilometres across and are the whole point from height.
	float gust = gust_at(world_pos.xz, wind, TIME);
	albedo *= 1.0 + (gust - 0.5) * gust_sheen;
	normal.xz += normalize(wind) * (gust - 0.5) * 0.22;

	if (mid > 0.001) {
		// Untiled, as in grass.gdshader: the wrapped lattice bounds the index, and a 4,096 m tile drew a seam. Gradient noise,
		// turned: value noise's 28.6 m lattice drew streaks and tiles from 40 m (terrain_noise.gdshaderinc).
		vec2 at = world_pos.xz * clump_scale;
		float clumps = fbm2_turned(at, LATTICE_PERIOD);
		albedo = mix(albedo, albedo * (0.74 + 0.52 * clumps), mid);
		albedo = mix(albedo, earth_colour,
			smoothstep(0.62, 0.86, clumps * patches * 1.6) * earth_amount * mid);
		// THE HUMMOCKS, lit rather than painted, from gradient noise with the value noise's spread and slope
		// (terrain_relief.gdshaderinc).
		vec3 lump = gradient_noise_d_wrapped(at * 0.5, LATTICE_PERIOD);
		normal.xz -= lump.yz * clump_scale * 0.5 * hummock_height * mid;
		albedo *= mix(1.0, 0.84 + 0.22 * lump.x, mid);
	}

	if (close > 0.001) {
		float blades = value_noise(tile(world_pos.xz, 64.0) * blade_scale);
		albedo *= 1.0 - 0.20 * close * (1.0 - blades);
	}

	// AND UNDER A WOOD, the forest floor, after the gusts: long grass bends in the wind, a forest
	// floor does not.
	albedo = mix(albedo, floor_colour * (0.8 + 0.4 * patches),
		forest_floor(world_pos.xz) * floor_strength);

	ALBEDO = albedo;
	ROUGHNESS = 0.95;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(normal), 0.0)).xyz);
}
