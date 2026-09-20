// THE GROUND AS TERRAIN, PLAIN: a sketch for the terrain probe, not the game's shader.
//
// Grass by the same broad patches the island's grass shader draws, rock where the ground is steep, scree and dry
// grass up high, snow on the flatter faces of the tops, sand at the shore. Everything is read from the surface's own
// world position and world normal, so a cell drawn at any level of detail is coloured the same way.
//
// THE EYE IS WORKED OUT FROM VIEW_MATRIX, never CAMERA_POSITION_WORLD: on a double build that built-in is minus the
// camera (working_with_godot.md, 2026-09-14).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

#include "res://world/shaders/terrain_noise.gdshaderinc"

uniform vec3 dry_colour : source_color = vec3(0.36, 0.38, 0.22);
uniform vec3 lush_colour : source_color = vec3(0.16, 0.31, 0.14);
uniform vec3 rock_colour : source_color = vec3(0.40, 0.38, 0.35);
uniform vec3 scree_colour : source_color = vec3(0.50, 0.47, 0.41);
uniform vec3 snow_colour : source_color = vec3(0.92, 0.93, 0.96);
uniform vec3 sand_colour : source_color = vec3(0.62, 0.57, 0.42);
uniform float patch_scale = 0.0016;
// How much of the slope's rock colour is laid on: 1 by default, 0 for the probe's `--rock=off` mutant.
uniform float rock_amount = 1.0;
// A tint per level of detail, for the picture that shows the rings; zero in every other picture.
uniform vec3 lod_tint = vec3(0.0);
uniform float lod_tint_amount = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 ground_colour(vec3 p, vec3 n, float fine_amount) {
	float patches = fbm3(p.xz * patch_scale);
	vec3 albedo = mix(dry_colour, lush_colour, smoothstep(0.35, 0.75, patches));
	float height = p.y + (patches - 0.5) * 120.0;
	// Drier and paler as it climbs.
	albedo = mix(albedo, mix(dry_colour, scree_colour, 0.5), smoothstep(450.0, 900.0, height) * 0.7);
	float steep = 1.0 - n.y;
	float rock = smoothstep(0.16, 0.34, steep + (patches - 0.5) * 0.10) * rock_amount;
	albedo = mix(albedo, mix(rock_colour, scree_colour, smoothstep(0.55, 0.2, steep) * 0.6), rock);
	float snow = smoothstep(1080.0, 1220.0, height) * (1.0 - smoothstep(0.22, 0.42, steep));
	albedo = mix(albedo, snow_colour, snow);
	float shore = 1.0 - smoothstep(1.5, 5.0, p.y + (patches - 0.5) * 3.0);
	albedo = mix(albedo, sand_colour, shore * (1.0 - rock));
	return albedo;
}

void fragment() {
	ALBEDO = mix(ground_colour(world_pos, world_normal, 0.0), lod_tint, lod_tint_amount);
	ROUGHNESS = 0.95;
}
