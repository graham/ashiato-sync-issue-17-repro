// THE GROUND AS TERRAIN, FINE: the plain sketch's colours, and the detail that only pays near the eye -- clumps and
// bare earth in the grass, strata and a stain on steep rock, and a little lit relief -- each faded out with range so
// nothing sparkles. A sketch for the terrain probe, not the game's shader.
//
// THE EYE IS WORKED OUT FROM VIEW_MATRIX, never CAMERA_POSITION_WORLD: on a double build that built-in is minus the
// camera (working_with_godot.md, 2026-09-14). The dither rule (THE SCENERY HAS TWO FINISHES) is not touched: nothing
// here is screen-space, and every lookup is keyed to the world.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

#include "res://world/shaders/terrain_noise.gdshaderinc"

uniform vec3 dry_colour : source_color = vec3(0.36, 0.38, 0.22);
uniform vec3 lush_colour : source_color = vec3(0.16, 0.31, 0.14);
uniform vec3 earth_colour : source_color = vec3(0.29, 0.25, 0.18);
uniform vec3 rock_colour : source_color = vec3(0.40, 0.38, 0.35);
uniform vec3 scree_colour : source_color = vec3(0.50, 0.47, 0.41);
uniform vec3 snow_colour : source_color = vec3(0.92, 0.93, 0.96);
uniform vec3 sand_colour : source_color = vec3(0.62, 0.57, 0.42);
uniform float patch_scale = 0.0016;
uniform float clump_scale = 0.035;
uniform float earth_amount = 0.35;
// How much of the slope's rock colour is laid on: 1 by default, 0 for the probe's `--rock=off` mutant.
uniform float rock_amount = 1.0;
uniform vec3 lod_tint = vec3(0.0);
uniform float lod_tint_amount = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 eye = -(transpose(mat3(VIEW_MATRIX)) * VIEW_MATRIX[3].xyz);
	float dist = length(world_pos - eye);
	float mid = detail_fade(dist, 600.0, 3000.0);
	float close = detail_fade(dist, 40.0, 260.0);
	vec3 n = world_normal;

	float patches = fbm3(world_pos.xz * patch_scale);
	vec3 albedo = mix(dry_colour, lush_colour, smoothstep(0.35, 0.75, patches));
	float clumps = 0.5;
	if (mid > 0.001) {
		clumps = fbm2(tile(world_pos.xz, 4096.0) * clump_scale);
		albedo = mix(albedo, albedo * (0.74 + 0.52 * clumps), mid);
		albedo = mix(albedo, earth_colour, smoothstep(0.62, 0.86, clumps * patches * 1.6) * earth_amount * mid);
	}
	float height = world_pos.y + (patches - 0.5) * 120.0;
	albedo = mix(albedo, mix(dry_colour, scree_colour, 0.5), smoothstep(450.0, 900.0, height) * 0.7);
	float steep = 1.0 - n.y;
	float rock = smoothstep(0.16, 0.34, steep + (patches - 0.5) * 0.10 + (clumps - 0.5) * 0.08 * mid) * rock_amount;
	vec3 stone = mix(rock_colour, scree_colour, smoothstep(0.55, 0.2, steep) * 0.6);
	if (mid > 0.001) {
		// STRATA across a steep face: bands in world height, wavering with a slow noise, and a darker stain below each.
		float band = fract((tile(world_pos.xz, 2048.0).x * 0.004 + world_pos.y * 0.09) + value_noise(tile(world_pos.xz, 1024.0) * 0.02));
		stone *= mix(1.0, 0.82 + 0.26 * smoothstep(0.0, 0.25, band), mid * rock);
	}
	albedo = mix(albedo, stone, rock);
	float snow = smoothstep(1080.0, 1220.0, height) * (1.0 - smoothstep(0.22, 0.42, steep));
	albedo = mix(albedo, snow_colour, snow);
	float shore = 1.0 - smoothstep(1.5, 5.0, world_pos.y + (patches - 0.5) * 3.0);
	albedo = mix(albedo, sand_colour, shore * (1.0 - rock));
	if (close > 0.001) {
		float blades = value_noise(tile(world_pos.xz, 64.0) * 0.9);
		albedo *= 1.0 - 0.20 * close * (1.0 - blades) * (1.0 - rock) * (1.0 - snow);
	}
	// A LITTLE LIT RELIEF near the eye: the normal tipped by a slope of the clump noise, in view space.
	if (mid > 0.001) {
		vec2 q = tile(world_pos.xz, 4096.0) * clump_scale;
		float e = 0.35;
		vec2 slope = vec2(fbm2(q + vec2(e, 0.0)) - fbm2(q - vec2(e, 0.0)), fbm2(q + vec2(0.0, e)) - fbm2(q - vec2(0.0, e)));
		vec3 tipped = normalize(n + vec3(-slope.x, 0.0, -slope.y) * 0.35 * mid);
		NORMAL = normalize((VIEW_MATRIX * vec4(tipped, 0.0)).xyz);
	}
	ALBEDO = mix(albedo, lod_tint, lod_tint_amount);
	ROUGHNESS = 0.95;
}
