// THE LOW MIST, AS A FIELD IN THE WORLD: how much of the light along a ray from the eye to a point the mist takes away, and
// what colour it puts back. One function, `mist_along`, for the mist pass (world/shaders/mist.gdshader) and for EVERY
// see-through shader drawn after it (tests/lint.gd holds that each includes this or says why not):
//
//   vec4 m = mist_along(EYE_POSITION_WORLD, world_position, mist_clock);   // m.rgb the mist's colour, m.a how much it takes
//   blend_mix:  ALBEDO = mix(ALBEDO, m.rgb, m.a);      blend_add:  colour *= 1.0 - m.a;
//
// Taken once a vertex, at the thing's own place in the world: a see-through thing is small against the mist's scales.
//
// ITS NUMBERS ARE GLOBAL SHADER UNIFORMS (project.godot [shader_globals], written by `MistLayer`), so a material that
// includes this sets nothing, and with no MistLayer every density is 0 and nothing is taken away. SELF-CONTAINED: its noise
// is its own `mist_` functions, because terrain_noise.gdshaderinc has no include guard and half the shaders that must include
// this include that already. Callable from vertex() and fragment(); it reads no screen built-in.
//
// WHAT IT IS. Extinction per metre is a sum of bands, each a shape in height over the ground and a share in plan:
//   GROUND HAZE: densest on the ground, falling by e every haze height, broken up in plan by world noise;
//   LOW STRATUS: a Gaussian band a height over the ground, in patches where the noise is over the cover, its top lit a little
//   brighter than its underside, faded out far along the ray.
// The ground under a point is `mist_ground`, a chart of `Terrain.surface_height` baked on a worker round the eye (`MistChart`).
//
// ANALYTIC IN HEIGHT, A FEW STEPS IN PLAN. Along a straight ray height is linear, so each band's integral over a step has a
// closed form: the exponential's is exact, the Gaussian's is an erf. Only the ground and the noise are taken a few times a step,
// where the band matters on it: the haze over each half of the step, on the lower ground of the half's two ends (see mist_along
// in mist_core.gdshaderinc), the stratus where the ray is nearest the band's middle -- places in the world, so a patch crossed
// from above stands still as the eye moves. Nothing is dithered or jittered; the eyes differ only by their own rays.
//
// WHAT A STEP COSTS, AND SO HOW MANY. Priced 2026-09-15 on the double editor, 1600x900 at 3D scale 1.40, two rounds agreeing to
// 0.014 ms: the pass with no steps +0.06 ms PLAIN and +0.10 to +0.13 FINE, every step about +0.045 more. So both finishes take ONE
// step -- the closed form over the whole ray, exact over flat ground (team-lead's option 0; FINE looked the same at one as at four).
#ifndef MIST_GDSHADERINC
#define MIST_GDSHADERINC

#include "res://world/shaders/eye.gdshaderinc"

global uniform sampler2D mist_ground;
// (least x, least z, span in metres, 0)
global uniform vec4 mist_chart_frame;
// (lowest, highest) ground on the chart; the slab a ray is clipped to reaches `mist_ceiling` over the highest.
global uniform vec2 mist_ground_range;
global uniform float mist_ceiling;
// HOW FAR ALONG ANY RAY THE MIST IS FOLLOWED, sky or surface alike: `MistTuning.REACH`. A sky pixel has no surface to end at,
// and when its ray ran 40 km through the haze while the ground just under the horizon ended at the island's edge, the step
// between them drew a bright white band along the whole horizon (step2-try3).
global uniform float mist_reach;
// (density at the ground per metre, the height it falls by e over, the share the noise breaks up, noise cycles a metre)
global uniform vec4 mist_haze;
// (density per metre, height over the ground, width, noise cycles a metre)
global uniform vec4 mist_stratus;
global uniform vec2 mist_stratus_cover;
// (second octave 0 or 1, how much lighter the top than the underside, metres along a ray a patch is still whole, the most
// optical depth one ray may take from the stratus)
global uniform vec4 mist_stratus_look;
global uniform vec4 mist_colour;
global uniform vec4 mist_sun_colour;
global uniform vec3 mist_towards_sun;
// (glow towards the sun, how tight, metres a second the noise wanders)
global uniform vec3 mist_sun;
global uniform int mist_steps;
// THE MIST'S OWN CLOCK, seconds, written once a frame by `MistLayer` -- what every call hands as its time, NEVER TIME: a
// shader that must not read TIME (the town's lamps flash from the tick alone, tests/night_lights.gd) still takes the mist,
// and TIME is each machine's own time since start. Main went red on it (2026-09-15).
global uniform float mist_clock;

// THE TOWNS' HAZE DOMES (step 3): each town's centre (x, ground y, z) and radius in a texel of `mist_towns`, written by
// `MistLayer.show_towns`; (count, density at the ground per metre, height it falls by e over, spread in radii) in `mist_town`;
// and the light the domes put back at night in `mist_town_glow`. See MistTuning.
global uniform sampler2D mist_towns;
global uniform vec4 mist_town;
global uniform vec3 mist_town_glow;

// THE VALLEY POOLS (step 4): (the most extra haze where the ground lies below the ground round it, the metres below it that
// takes, 0, 0). The relief itself is the chart's green (`MistChart.relief_of`). See MistTuning.
global uniform vec4 mist_pool;

// THE MATHS LIVE IN mist_core.gdshaderinc, shared with the compute mist: the same functions, one copy.
#include "res://world/shaders/mist_core.gdshaderinc"

#endif
