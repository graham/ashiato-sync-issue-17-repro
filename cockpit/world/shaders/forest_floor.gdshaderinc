// THE GROUND UNDER A WOOD, painted by the grass itself.
//
// Trees here cast no shadow -- instanced shadows redraw every tree, which X-Plane measured as the
// dominant cost of its autogen -- so what makes a wood sit on the ground rather than float over a
// field is the ground under it going dark and green. No texture: the stands are a few rectangles,
// handed over once as two small uniform arrays by `world/woodland.gd`, and every ground pixel asks
// whether it is inside one.
//
// THE EDGE FOLLOWS THE TREES. A wood thins towards its sides over `edge_band` metres, its trees kept
// with a chance of (distance in / band) ^ `edge_curve`; the floor fades over the same band by the same
// curve, so the dark ground does not end in a hard line where the trees have already thinned. With FINE
// defined the edge is ragged too, wandering out by up to `floor_ragged` metres on a slow noise.
//
// INCLUDED AFTER terrain_noise.gdshaderinc. THE ARRAYS ARE 8 LONG, and the tuning's `most_stands` must
// say the same: a test reads the length out of this file.
//   forest_frame[i] = (centre x, centre z, across x, across z)   -- across is a unit vector
//   forest_half[i]  = (half across, half along, 0, 0)
// Every uniform is set from `world/forest_tuning.gd`; none has an initialiser.

uniform int forest_count;
uniform vec4 forest_frame[8];
uniform vec4 forest_half[8];
uniform vec3 floor_colour : source_color;
uniform float floor_strength;
uniform float edge_band;
uniform float edge_curve;
#ifdef FINE
uniform float floor_ragged;
#endif

// How much of this point is forest floor, 0..1.
float forest_floor(vec2 p) {
	float cover = 0.0;
	for (int i = 0; i < forest_count; i++) {
		vec2 d = p - forest_frame[i].xy;
		vec2 across = forest_frame[i].zw;
		vec2 along = vec2(across.y, -across.x);
		vec2 past = abs(vec2(dot(d, across), dot(d, along))) - forest_half[i].xy;
		// Negative inside: how far in from the nearest side.
		float beyond = max(past.x, past.y);
#ifdef FINE
		beyond -= value_noise(tile(p, 4096.0) / max(floor_ragged, 1.0)) * floor_ragged;
#endif
		cover = max(cover, pow(clamp(-beyond / max(edge_band, 0.001), 0.0, 1.0), edge_curve));
	}
	return cover;
}
