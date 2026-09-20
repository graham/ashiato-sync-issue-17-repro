// A HIT CRAFT'S SMOKE: lit puffs left behind it, each where the craft was when it was laid, swelling, rising a little,
// drifting downwind and thinning away (lane/combat, 2026-09-18). `DamageYard` lays them; two materials of this, a thin
// grey one and a thick black one, are the two stages of damage.
//
// PUFFS, NOT A RIBBON. The first build wore the missile yard's trail -- a camera-facing strip that widens as it ages --
// turned dark, and photographed it read as a flat beige sheet laid across the ground behind the aeroplane, not smoke
// (combat-smoke, the first picture). A trail of separate lit balls that overlap is what a smoking engine leaves.
//
// THE MULTIMESH PATTERN OF `heavy_burst_smoke.gdshader`: laid once, aged here. An instance's ORIGIN is where the puff was
// laid (its basis the identity, as billboard.gdshaderinc asks of a MultiMesh), `INSTANCE_CUSTOM.r` the yard's clock when it
// was laid and `.g` a number of its own for its size and drift. LIT, not glowing, so it is grey by day and dark at night
// without being told the time; the thick smoke's first fraction of a second is lit from inside, which is the fire.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
varying vec4 mist_here;

// The yard's clock, written every frame.
uniform float now = 0.0;
// Seconds a puff lasts.
uniform float life = 6.0;
// Its radius when it is laid, and how much it grows over its life, metres.
uniform float start_size = 1.2;
uniform float grow = 5.0;
// How fast it rises, metres a second, and the wind that carries it.
uniform float rise = 1.0;
uniform vec3 wind = vec3(0.0);
uniform vec3 tone : source_color = vec3(0.5, 0.5, 0.5);
uniform float opacity = 0.5;
// How long the fire at the craft lights the newest puffs from inside, seconds; 0 for no fire.
uniform float fire_s = 0.0;

varying vec2 uv;
varying float fade;
varying float heat;
varying vec3 right_w;
varying vec3 up_w;
varying vec3 eye_w;

void vertex() {
	vec3 centre = vec3(0.0);
	float t = now - INSTANCE_CUSTOM.r;
	float k = t / life;
	float own = INSTANCE_CUSTOM.g;
	uv = VERTEX.xy * 2.0;
	fade = 0.0;
	heat = 0.0;
	float radius = 0.0;
	vec3 at = centre;
	if (t >= 0.0 && k < 1.0) {
		// SWELLS FAST AND THEN SLOWLY, as a puff of smoke does: the square root of its age.
		radius = (start_size + grow * sqrt(k)) * (0.75 + 0.5 * own);
		at = centre + vec3(0.0, rise * t, 0.0) + wind * t;
		fade = opacity * smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.35, 1.0, k));
		heat = fire_s > 0.0 ? 1.0 - smoothstep(0.0, fire_s, t) : 0.0;
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
	float body = 1.0 - smoothstep(0.35, 1.0, r);
	vec3 ball = normalize(right_w * uv.x + up_w * uv.y + eye_w * (sqrt(max(1.0 - r * r, 0.0)) + 0.2));
	NORMAL = normalize((VIEW_MATRIX * vec4(ball, 0.0)).xyz);
	ALBEDO = tone * (0.8 + 0.3 * clamp(ball.y * 0.5 + 0.5, 0.0, 1.0));
	EMISSION = vec3(1.0, 0.45, 0.1) * heat * heat * body * 1.2;
	ROUGHNESS = 1.0;
	ALPHA = clamp(body * fade, 0.0, 1.0);
	ALBEDO *= 1.0 - mist_here.a;
	EMISSION = EMISSION * (1.0 - mist_here.a) + mist_here.rgb * mist_here.a;
}
