// BLADES OF GRASS, near the eye, on the fine finish. See GrassBlades for why they exist and why
// they are opaque.
//
// Every instance is a clump of five thin triangles standing on a lattice point that follows the
// eye in whole steps. Everything that makes one clump differ from the next -- where in its cell
// it stands, how tall it is, which way it faces -- is hashed from the WORLD position of that
// lattice point, so as the lattice moves with the aircraft a clump that stays in view keeps its
// shape rather than reshuffling.
//
// A clump that should not be there is collapsed to a point rather than hidden: past the reach,
// on the runway, or beyond the coast. A collapsed triangle covers no pixels and costs its three
// vertices and nothing else.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
#include "res://world/shaders/eye.gdshaderinc"

#include "res://world/shaders/terrain_noise.gdshaderinc"
#include "res://world/shaders/terrain_relief.gdshaderinc"

// The ground's own colours, copied from its material so a blade is the colour of the field it
// stands in. See GrassBlades.match_the_ground.
uniform vec3 dry_colour : source_color = vec3(0.36, 0.38, 0.22);
uniform vec3 lush_colour : source_color = vec3(0.16, 0.31, 0.14);
uniform float patch_scale = 0.0016;
uniform vec2 wind = vec2(5.4, -2.6);
uniform float reach = 36.0;
uniform float spacing = 0.6;
uniform float land_half = 7200.0;
// The runway, as min x, min z, max x, max z, with a margin. No grass grows through tarmac.
uniform vec4 runway = vec4(0.0);
// AND THE AIR BASE'S PAVEMENT NEAR THE EYE, the same way: up to eight rectangles, `pavements` of them in use, handed in
// by GrassBlades as the eye moves. Eight covers the fighter base: tests/airbase.gd counts 7 at its busiest place.
uniform vec4 pavement[8];
uniform int pavements = 0;

varying vec3 tint;
varying float up;
// How far towards the edge of the patch a clump is, 0 near and 1 at the reach.
varying float faded;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 cell = tile(root.xz, 4096.0);
	float h1 = hash21(cell * 0.371 + 0.13);
	float h2 = hash21(cell * 0.529 + 0.77);
	vec2 at = root.xz + (vec2(h1, h2) - 0.5) * spacing;

	float range = length(at - EYE_POSITION_WORLD.xz);
	// SHRINKING FROM A THIRD OF THE WAY OUT, not from half: the first render check (2026-09-12)
	// showed the patch ending in a hard line where the blades stopped.
	faded = smoothstep(reach * 0.35, reach * 0.9, range);
	float keep = 1.0 - smoothstep(reach * 0.35, reach, range);
	keep *= step(max(abs(at.x), abs(at.y)), land_half - 2.0);
	keep *= 1.0 - step(runway.x, at.x) * step(at.x, runway.z) * step(runway.y, at.y)
		* step(at.y, runway.w);
	for (int i = 0; i < pavements; i++) {
		keep *= 1.0 - step(pavement[i].x, at.x) * step(at.x, pavement[i].z) * step(pavement[i].y, at.y)
			* step(at.y, pavement[i].w);
	}

	up = VERTEX.y;
	float tall = (0.30 + 0.45 * h1) * keep;
	float turn = h2 * 6.28318;
	vec2 across = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn)))
		* VERTEX.xz * (0.7 + 0.6 * h1) * keep;

	// SWAY: a small flutter of its own, and the gust that is rolling across the field under it.
	// Bent by the square of the height up the blade, so the root stays in the ground.
	vec2 w = normalize(wind);
	float gust = gust_at(at, wind, TIME);
	float sway = (sin(TIME * 2.1 + h1 * 6.28318 + dot(at, w) * 0.2) * 0.25 + gust * 0.9)
		* up * up * tall * 0.6;

	VERTEX = vec3(across.x + (at.x - root.x) + w.x * sway, VERTEX.y * tall,
		across.y + (at.y - root.z) + w.y * sway);
	NORMAL = vec3(0.0, 1.0, 0.0);

	// The same patches as the ground under the blade (grass.gdshader), so a clump and its field are one colour.
	float patches = fbm3_turned(at * patch_scale, LATTICE_PERIOD);
	tint = mix(dry_colour, lush_colour, smoothstep(0.35, 0.75, patches));
	// THE FIELD'S OWN GUST SHEEN, so a blade and the ground under it brighten together.
	tint *= 1.0 + (gust - 0.5) * 0.32;
	// AND EVERY CLUMP A LITTLE DIFFERENT, some yellower, some bluer.
	tint *= vec3(0.92 + 0.16 * h2, 0.96 + 0.08 * h1, 0.90 + 0.10 * (1.0 - h2));
}

void fragment() {
	// SHADED AT THE ROOT, NOT BLACK, and bleached towards straw at the tip. The first version
	// went from 0.55 at the root to 1.15 at the tip and drew near-black spikes: the blades are
	// two-sided, and a back face turns its normal away from the sun.
	// AND THEN TOO FAR THE OTHER WAY: at 0.68 to 1.02 the blades matched the ground so closely that
	// render_check_3 showed a field with almost no blades in it. Half at the root and a stronger
	// straw tip is what makes a blade a blade without going back to black.
	vec3 rooted = tint * mix(0.50, 1.0, up);
	vec3 tipped = mix(rooted, tint * vec3(1.26, 1.18, 0.76), smoothstep(0.50, 1.0, up) * 0.70);
	// Towards the plain field colour as the clump shrinks away, so the patch has no edge.
	ALBEDO = mix(tipped, tint, faded);
	// LIT LIKE THE GROUND on both faces: the normal is the ground's, whichever face is showing.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 0.9;
	BACKLIGHT = tint * 0.25;
}
