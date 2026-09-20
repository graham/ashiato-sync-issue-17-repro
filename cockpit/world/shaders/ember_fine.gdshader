// EMBERS, ON THE FINE FINISH: sparks climbing out of a fire, entirely on the GPU.
//
// Each ember is one instance of a small quad in a MultiMesh that sits at the foot of the fire.
// Where it is, how bright, and how far through its short life, are all worked out here from
// TIME and the ember's own seed in INSTANCE_CUSTOM.x -- so a burning hillside's embers cost the
// processor one transform, the fire's, and nothing per spark per frame.
//
// A spark rises, spirals, leans with the smoke, shrinks and goes out, and is born again at the
// bottom. The eye cannot follow one long enough to notice it is the same spark.
//
// Close-range detail only: a spark is a few centimetres of light and nothing holds its size with
// distance, so from the circuit they are gone and the column is what remains.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;

// How hard the fire is burning, 0..1, and how wide it is in metres. Set per fire by FireYard.
instance uniform float heat = 1.0;
instance uniform float span = 20.0;
// How far the rising air leans, in metres per metre of climb. Set from the wind.
uniform vec3 drift = vec3(0.0);

varying vec2 corner;
varying float glow;

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	// RELATIVE TO THE FIRE'S FOOT, which the engine places exactly: see billboard.gdshaderinc.
	vec3 foot = vec3(0.0);
	float t = mod(TIME, 600.0);
	float life = fract(t * (0.16 + 0.12 * fract(seed * 7.3)) + seed);
	float climb = life * span * 4.0;
	float about = seed * 40.0 + t * (1.2 + fract(seed * 5.1));
	float out_from = span * (0.10 + 0.35 * fract(seed * 3.1)) * (1.0 + life);
	vec3 at = foot + vec3(cos(about) * out_from, climb, sin(about) * out_from) + drift * climb;
	float radius = 0.45 * (1.0 - life) * (0.5 + 0.5 * heat);
	glow = (1.0 - life) * heat * (0.6 + 0.4 * sin(t * 23.0 + seed * 51.0));
	corner = VERTEX.xy;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + at, mist_clock);
	VERTEX = BILLBOARD_LOCAL_FROM_VIEW(mat3(VIEW_MATRIX) * at + vec3(corner * radius, 0.0));
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float r = length(corner);
	float spot = 1.0 - smoothstep(0.15, 1.0, r);
	ALBEDO = vec3(1.0, 0.58, 0.18) * 2.2 * glow * spot * (1.0 - mist_here.a);
	ALPHA = spot;
}
