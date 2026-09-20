// HOW INLAND WATER READS AT ITS SHORE (lane/rivers, 2026-09-20): the shallows pale, the deep water its own colour, and a
// wet line along the waterline itself. The user's ask was "near these the ground and water should look different on the
// shore", and before this nothing in the game drew a shore at all: a lake was the open ocean's `deep_colour` --
// (0.016, 0.055, 0.094), very nearly black -- meeting green grass along a hard edge, which from the air read as a tar
// pit in a field (godotgames-drafts/2026-09-20/rivers, lake_above).
//
// THE DEPTH RIDES IN CUSTOM0, one float32 a vertex, in metres, put there by `LakeSheets` from the ground function
// itself, and it is EXACTLY 0 along the shore because the sheet's edge is solved for the crossing. So the shore band
// keys off a number that is true by construction rather than off a distance to a line nobody has. It is not in the
// vertex colour because that is eight bits a channel and every depth over 1 m clamped.
//
// WHY NOT THE DEPTH BUFFER, which is how a water shader usually does this: `ocean.gdshader` is opaque on purpose and
// says so in its first paragraph -- "no transparency, no refraction, no screen or depth texture, the expensive things in
// a water shader" -- and this game draws water in a headset. A sheet that carries its own depth costs one more vertex
// attribute on a mesh that is built once at level load, and nothing per pixel but a smoothstep.
//
// ONLY ON WATER THAT SAYS IT IS INLAND. The sea's sheet carries no CUSTOM0 at all, so what a read of it gives is not
// this game's to rely on. The callers ask `inland` (still_water.gdshaderinc) first, which is a uniform, so the branch
// is uniform and costs nothing.
#ifndef SHORE_WATER_GDSHADERINC
#define SHORE_WATER_GDSHADERINC

// THE SHALLOWS' COLOUR, and how deep the water has to be before none of it shows. A lake's bed is 12 to 28 m at the
// middle (`ground_core.hpp`, `find_lakes`), so at 9 m the middle of every lake is still its own deep colour and the
// grading is spent where the eye reads a shore.
uniform vec3 shallow_colour : source_color = vec3(0.10, 0.24, 0.24);
uniform float shallow_depth = 9.0;
// HOW MUCH OF THE SHALLOW COLOUR THE SHALLOWEST WATER TAKES. Not 1.0: water over a bed is still water, and at 1.0 the
// rim of a lake read as painted turquoise rather than as shallow.
uniform float shallow_strength : hint_range(0.0, 1.0) = 0.75;
// THE WET LINE AT THE WATERLINE: how deep the water is where it stops, metres, and how strongly it takes the foam
// colour. This is the sea's own `foam_colour`, handed in, so a lake's edge and a whitecap are one colour.
uniform float shore_band = 0.45;
uniform float shore_strength : hint_range(0.0, 1.0) = 0.55;

// `albedo` shaded for water `depth` metres deep, with `foam` for the line along the shore. Callers guard on `inland`.
vec3 shore_water(vec3 albedo, vec3 foam, float depth) {
	float shallow = 1.0 - smoothstep(0.0, shallow_depth, depth);
	vec3 shaded = mix(albedo, shallow_colour, shallow * shallow_strength);
	float edge = 1.0 - smoothstep(0.0, shore_band, depth);
	return mix(shaded, foam, edge * shore_strength);
}

// AND THE SHALLOWS ARE ROUGHER, because a bed a hand's depth under the surface breaks what little the wind does to it
// and because a mirror running right up to the grass is what made the first shore read as glass.
float shore_roughness(float roughness, float depth) {
	return mix(roughness, 0.72, (1.0 - smoothstep(0.0, shallow_depth, depth)) * shallow_strength);
}
#endif
