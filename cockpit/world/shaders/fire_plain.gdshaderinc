// A PLAIN FIRE'S FLAME, GLOW OR PUFF: one flat tint, unshaded, see-through, and misted -- `fire_plain_add.gdshader` for the
// additive flames and glow (`#define ADDITIVE`), `fire_plain_mix.gdshader` for the blended smoke. Tinted by `FireYard._tint`,
// which writes `tint` only when the colour changes, as it wrote the StandardMaterial3D's albedo before.
//
// WHY A SHADER AND NOT A STANDARD MATERIAL ANY MORE (2026-09-15). The low mist is drawn first among the see-through things
// (world/shaders/mist.gdshader), so every see-through thing drawn after it must mist itself (world/shaders/mist.gdshaderinc,
// held by tests/lint.gd), and a StandardMaterial3D cannot include a shader. PLAIN is the headset's finish, and a fire's
// column stands up out of the ground haze -- team-lead read the pale puffs beside the fires in the survey pictures as unmisted.
// Everything else is the StandardMaterial3D it replaces: unshaded, no culling, no depth written, the engine's fog left on.
//
// ONCE A VERTEX, at the vertex's own place in the world: a puff is metres across and the mist's scales are hundreds.

#include "res://world/shaders/mist.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);

// THE MIST BETWEEN THE EYE AND THIS: rgb its colour, a how much it takes.
varying vec4 mist_here;

void vertex() {
	mist_here = mist_along(EYE_POSITION_WORLD, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz, mist_clock);
}

void fragment() {
#ifdef ADDITIVE
	ALBEDO = tint.rgb * (1.0 - mist_here.a);
#else
	ALBEDO = mix(tint.rgb, mist_here.rgb, mist_here.a);
#endif
	ALPHA = tint.a;
}
