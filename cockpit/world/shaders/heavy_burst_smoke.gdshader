// A BIG EXPLOSION, THE SMOKE, PLAIN: lit puffs that stack into a column, climb, widen as they rise, drift downwind and
// thin away -- darkest at the base.
//
// The same MultiMesh idea as `heavy_burst_fire.gdshader` -- laid out once, aged here -- and read that for what an
// instance carries. Here INSTANCE_CUSTOM.r is 0 for a smoke puff and 1 for a piece of debris, plus 10 for the ones
// only FINE draws (this collapses those), and the debris is all FINE's.
//
// A COLUMN, NOT A BALL (2026-09-14: "at 4 s the smoke is a single grey blob sitting on the ground"). Each puff's own
// number `.g` is its share of the height: low puffs stay near the ground, narrow and dark, high ones climb furthest and
// open out widest. The climb is in fireball radii, easing off over about eight seconds; the footprint is kept close
// in so the puffs stack rather than spread, and it widens with height.
//
// LIT, NOT GLOWING. The puffs are camera-facing discs given the normal of a ball, and lit by the level's own sun and
// ambient, so smoke is grey by day and dark at night without anybody telling it the time -- the trails, which are
// unshaded, glow white at night, and this was not going to join them. The first second is lit from inside as well,
// by an EMISSION that is the fireball's colour and goes out as it cools.
//
// BLENDED AND UNSORTED WITHIN A BURST: one MultiMesh is one draw, so its puffs are drawn in the order they were laid,
// not back to front. At the smoke's opacity the wrong order reads as a denser patch rather than a hole; bursts are
// sorted against each other by the engine as nodes.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;

uniform float now = 0.0;
// PER BURST, because a small burst's smoke goes sooner: see BurstTuning.lasts.
instance uniform float life = 14.0;
// Written once by BurstYard from BurstTuning. No defaults, on purpose.
uniform float grow;
uniform float rise;
uniform float delay_s;
uniform vec3 tone : source_color;
uniform float opacity;

instance uniform float born = -100000.0;
instance uniform float size = 10.0;
instance uniform vec3 wind = vec3(0.0);
instance uniform float grounded = 0.0;
instance uniform float turn = 0.0;
// How thick this burst's smoke is, by what it hit: 1 in the air. See Ammunition.SURFACE.
instance uniform float density = 1.0;

varying vec2 uv;
varying float fade;
varying float heat;
varying float lift;
varying vec3 right_w;
varying vec3 up_w;
varying vec3 eye_w;

vec3 turned(vec3 d) {
	float c = cos(turn);
	float s = sin(turn);
	vec3 r = vec3(c * d.x - s * d.z, d.y, s * d.x + c * d.z);
	r.y = grounded > 0.5 ? abs(r.y) : r.y;
	return r;
}

void vertex() {
	// RELATIVE TO THE BURST'S ORIGIN, which the engine places exactly: see billboard.gdshaderinc.
	vec3 centre = vec3(0.0);
	vec3 dir = turned(MODEL_MATRIX[0].xyz);
	float code = floor(INSTANCE_CUSTOM.r + 0.5);
	float t = now - born;
	uv = VERTEX.xy * 2.0;
	fade = 0.0;
	heat = 0.0;
	lift = INSTANCE_CUSTOM.g;
	vec3 at = centre;
	float radius = 0.0;
	if (code < 0.5) {
		float late = t - delay_s * (0.6 + 0.8 * INSTANCE_CUSTOM.a);
		float k = late / life;
		if (late > 0.0 && k < 1.0) {
			float spread = sqrt(k);
			// THE PUFF'S SHARE OF THE COLUMN: 0.2 to 1.8 of the climb, in fireball radii, easing off over eight seconds.
			float climbed = rise * size * 8.0 * (1.0 - exp(-late / 8.0)) * (0.2 + 1.6 * lift);
			// CLOSE IN AT THE BASE AND WIDER AS IT RISES, so the puffs stack.
			vec3 across = vec3(dir.x, 0.0, dir.z) * size * (0.2 + 0.5 * spread) * (0.5 + 0.8 * lift);
			at = centre + across + vec3(0.0, climbed + size * 0.3, 0.0) + wind * late;
			radius = size * (0.45 + grow * spread) * (0.7 + 0.6 * INSTANCE_CUSTOM.b) * (0.7 + 0.5 * lift);
			fade = density * opacity * smoothstep(0.0, 0.4, late) * (1.0 - smoothstep(0.3, 1.0, k));
			heat = 1.0 - smoothstep(0.0, 1.0, late);
		}
	}
	right_w = INV_VIEW_MATRIX[0].xyz;
	up_w = INV_VIEW_MATRIX[1].xyz;
	eye_w = normalize(BILLBOARD_EYE - at);
	vec3 world = fade > 0.0 ? at + (right_w * VERTEX.x + up_w * VERTEX.y) * radius * 2.0 : at;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_LOCAL_OF(world);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float r = length(uv);
	float body = 1.0 - smoothstep(0.3, 1.0, r);
	vec3 ball = normalize(right_w * uv.x + up_w * uv.y + eye_w * (sqrt(max(1.0 - r * r, 0.0)) + 0.2));
	NORMAL = normalize((VIEW_MATRIX * vec4(ball, 0.0)).xyz);
	// DARKEST AT THE BASE, where the smoke is thickest and freshest off the fire.
	ALBEDO = tone * (0.8 + 0.3 * clamp(ball.y * 0.5 + 0.5, 0.0, 1.0)) * mix(0.45, 1.05, lift);
	EMISSION = vec3(1.0, 0.42, 0.1) * heat * heat * body * 1.2;
	ROUGHNESS = 1.0;
	ALPHA = clamp(body * fade, 0.0, 1.0);
	ALBEDO *= 1.0 - mist_here.a;
	EMISSION = EMISSION * (1.0 - mist_here.a) + mist_here.rgb * mist_here.a;
}
