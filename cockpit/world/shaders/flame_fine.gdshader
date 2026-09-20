// FLAMES, ON THE FINE FINISH: a tongue of fire that moves, instead of a cone that stretches.
//
// The plain flame is a cone whose height is shaken by a sine wave, which from the approach reads
// as a cluster of orange traffic cones. A flame is not a shape at all: it is hot gas rising and
// breaking up, hottest and whitest at the root, thinning to red at the tips, torn sideways.
//
// So each flame is a quad standing upright on the fire and turned about the vertical to face the
// eye, painted with noise scrolling UP through a teardrop: a second noise displaces it sideways
// more the higher it goes, which is the tearing, and the brightness runs through a temperature
// ramp rather than a colour. The processor still sets how tall each flame is -- that is the
// fire's STRENGTH, off the wire -- and everything about how it moves is here.
//
// TURNED TOWARDS THE MIDPOINT OF THE EYES, not towards each eye, so both eyes see one flat quad
// in one place -- a quad turned separately per eye is two different flames and reads as a smear.
// From directly overhead a vertical quad is edge-on; the glow disc under the fire is what a pilot
// above it sees, on both finishes.
//
// TIME is wrapped at ten minutes. Scrolling noise by an ever-growing TIME loses precision over a
// long session and the flame freezes into stripes; a single frame's jump every ten minutes is the
// cheaper fault.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled,
	skip_vertex_transform;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;

#include "res://world/shaders/terrain_noise.gdshaderinc"

// How hard the fire is burning, 0..1. Set per flame by FireYard.
instance uniform float heat = 1.0;
// Which flame this is, so seven flames on one fire are seven different flames.
instance uniform float seed = 0.0;

varying vec2 uv;

void vertex() {
	// RELATIVE TO THE FLAME'S ORIGIN, which the engine places exactly: see billboard.gdshaderinc.
	vec3 origin = vec3(0.0);
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 up = MODEL_MATRIX[1].xyz;
	vec3 to_eye = BILLBOARD_EYE - origin;
	to_eye.y = 0.0;
	vec3 right = length(to_eye) > 0.01 ? normalize(vec3(to_eye.z, 0.0, -to_eye.x))
		: vec3(1.0, 0.0, 0.0);
	uv = VERTEX.xy;
	vec3 world = origin + right * VERTEX.x * width + up * VERTEX.y;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_VIEW_OF(world);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float t = mod(TIME, 600.0);
	float tear = fbm2(vec2(uv.x * 2.0 + seed * 7.0, uv.y * 1.5 - t * 1.3));
	float x = uv.x + (tear - 0.5) * 0.45 * uv.y;
	float lick = fbm2(vec2(x * 4.0 + seed * 13.0, uv.y * 2.6 - t * 2.8));
	float width = 0.5 * (1.0 - pow(clamp(uv.y, 0.0, 1.0), 1.4)) + 0.02;
	float body = 1.0 - smoothstep(width * 0.35, width, abs(x));
	float burn = clamp(body * (1.25 - uv.y * 1.3 + lick * 0.9 - 0.35), 0.0, 1.0);
	vec3 colour = mix(vec3(0.55, 0.06, 0.01), vec3(1.0, 0.42, 0.08), smoothstep(0.0, 0.35, burn));
	colour = mix(colour, vec3(1.0, 0.86, 0.40), smoothstep(0.35, 0.75, burn));
	colour = mix(colour, vec3(1.0, 0.98, 0.85), smoothstep(0.80, 1.0, burn));
	ALBEDO = colour * burn * (0.6 + 0.8 * heat) * (1.0 - mist_here.a);
	ALPHA = clamp(burn * 1.4, 0.0, 1.0);
}
