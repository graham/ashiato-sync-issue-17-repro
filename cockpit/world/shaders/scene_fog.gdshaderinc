// THE SCENE'S FOG, FOR A SHADER THAT DRAWS LIGHT AND TAKES THE FOG ITSELF: how much of a light `away` metres off reaches
// the eye through the environment's fog, whose `density` the level hands over (TownView.show_fog).
//
// WHY A SHADER TAKES IT ITSELF. The engine's fog on an additive quad adds the fog colour over the whole quad -- a square
// round every point at dusk -- so the town's far lights are `fog_disabled` and multiply by this instead. What reaches the
// eye must still be what the engine's fog leaves of the wall the light stands on, so this is the engine's own exponential
// fog: `fog_process` in Godot 4.7's scene_forward_clustered.glsl, `1 - exp(-length(vertex) * fog_density)` taken as the
// light it lets through. The environment has no height fog and no volumetric fog today; `tests/town_lights_shot.gd
// --fog-check` fails if either appears, so this cannot silently stop matching.
//
// ONE FUNCTION FOR EVERY LANE THAT NEEDS IT (asked for on 2026-09-15, beside cockpit-mist's banded mist and valley fog): a
// height-banded density is added HERE, with the heights it needs as further arguments, and every caller follows.
#ifndef SCENE_FOG_GDSHADERINC
#define SCENE_FOG_GDSHADERINC

float scene_fog_transmission(float away, float density) {
	return exp(-density * away);
}

#endif
