// A TREE, FOR A WOOD OF THEM: EVERY ONE THE SAME MESH, AND EVERYTHING THAT MAKES IT THAT TREE IN
// FOUR NUMBERS ON THE INSTANCE.
//
// The user asked for trees that are "very cheap; they need no collision, just visible (like grass
// but a forest)". So a tree is one opaque low-poly mesh in a MultiMesh -- a trunk and a crown, no
// texture, no alpha -- and every tree in a chunk of wood is one draw. See `world/woodland.gd` for
// where they are planted and `world/forest_tuning.gd` for every number used here: the uniforms
// below have NO initialisers on purpose, so a value that the tuning did not set is not set at all.
//
// THE INSTANCE, in INSTANCE_CUSTOM:
//   r  rank, 0..1 within this finish's trees: the order a tree leaves in as the wood thins with
//      distance. Low ranks stay longest.
//   g  1 for a conifer, 0 for a broadleaf.
//   b  where between its kind's dark and light colour this tree's crown is.
//   a  its wind phase, 0..1 (FINE only).
// Height and lean are the instance basis (a uniform scale and a tilt), and the position is its origin.
//
// ONE MESH, TWO KINDS OF TREE. The vertex is the conifer's shape and CUSTOM0.xyz the broadleaf's,
// with their normals in NORMAL and CUSTOM1.xyz; they share every triangle, so a mixed wood is still
// one mesh and one draw. CUSTOM0.w is 1 on the trunk. UV.x and UV.y are how lit each vertex is on
// the conifer and the broadleaf, baked where the mesh is built. The mesh is UNIT-SIZED -- a trunk
// from y = -1 to 0 and a crown from 0 to 1, a ring of radius 1 -- and this shader gives it its
// proportions from the tuning, so no proportion is typed into the mesh either.
//
// THE WOOD THINS AND FADES IN HERE, NOT IN MORE CHUNKS. Past `near_range` only `far_share` of the
// trees stay, and between `fade_from` and `fade_to` the rest go -- each tree shrinking to nothing
// over its own slice of the band, in rank order. That is a dither keyed to the TREE, not the
// screen: the same tree goes at the same distance in both eyes, nothing is discarded, and the early
// depth test keeps working. A tree that has gone is a degenerate triangle at its own foot.
//
// DISTANCE IS FROM EYE_POSITION_WORLD, the midpoint of the eyes, so both eyes agree about which
// trees are there.
#include "res://world/shaders/eye.gdshaderinc"

uniform float fade_from;
uniform float fade_to;
uniform float near_range;
uniform float far_share;
uniform float conifer_width;
uniform float broadleaf_width;
uniform float trunk_share;
uniform float trunk_width;
uniform vec3 conifer_dark : source_color;
uniform vec3 conifer_light : source_color;
uniform vec3 broadleaf_dark : source_color;
uniform vec3 broadleaf_light : source_color;
uniform vec3 trunk_colour : source_color;
#ifdef FINE
uniform float sway;
uniform float sway_rate;
// Which way the air is moving, from Terrain.WIND: a fact about the day, not a tuning number.
uniform vec2 wind;
#endif

varying vec3 tint;

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	float height = length(MODEL_MATRIX[1].xyz);
	float away = length(foot - EYE_POSITION_WORLD);
	// How many of this finish's trees are still standing at this distance, as a share.
	float share = mix(1.0, far_share, smoothstep(near_range, near_range * 2.0 + 1.0, away));
	share *= 1.0 - smoothstep(fade_from, fade_to, away);
	// This tree's own slice of that: whole while the share is above its rank, gone below it.
	float grow = clamp((share * 1.08 - INSTANCE_CUSTOM.r) / 0.08, 0.0, 1.0);

	float conifer = INSTANCE_CUSTOM.g;
	float trunk = CUSTOM0.w;
	vec3 shape = mix(CUSTOM0.xyz, VERTEX, conifer);
	vec3 facing = mix(CUSTOM1.xyz, NORMAL, conifer);
	float lit = mix(UV.y, UV.x, conifer);

	// PROPORTIONS, from the tuning: widths are diameters as a share of the height.
	float radius = 0.5 * mix(mix(broadleaf_width, conifer_width, conifer), trunk_width, trunk);
	// The crown runs from the top of the trunk to the top of the tree; the trunk from the ground up.
	float tall = mix(1.0 - trunk_share, trunk_share, trunk);
	vec3 at = vec3(shape.x * radius,
		mix(trunk_share + shape.y * tall, (1.0 + shape.y) * trunk_share, trunk), shape.z * radius);
	// A flat face scaled by a diagonal keeps its facing through the inverse scale.
	NORMAL = normalize(facing / vec3(max(radius, 0.001), max(tall, 0.001), max(radius, 0.001)));

#ifdef FINE
	// THE WHOLE TREE BENDS, more at the top: the square of the height up it, swinging round a lean
	// downwind at its own phase. In the tree's own frame, so a leaning tree bends the same way.
	float swing = 0.6 + 0.4 * sin(TIME * sway_rate + INSTANCE_CUSTOM.a * 6.2831853);
	vec3 downwind = vec3(wind.x, 0.0, wind.y) / max(length(wind), 0.001);
	vec3 in_tree = transpose(mat3(MODEL_MATRIX)) * downwind / max(height * height, 0.001);
	at += in_tree * sway * at.y * at.y * swing;
#endif

	VERTEX = at * grow;

	vec3 crown = mix(mix(broadleaf_dark, broadleaf_light, INSTANCE_CUSTOM.b),
		mix(conifer_dark, conifer_light, INSTANCE_CUSTOM.b), conifer);
	tint = mix(crown * lit, trunk_colour, trunk);
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.9;
}
