// A BIG EXPLOSION, THE SMOKE, FINE: twice the puffs, stacked into a column with a billowing broken edge, light through
// the thin parts, darkest at the base, and debris -- dark chunks, glowing at first, thrown out and falling.
//
// The same instances, clock, sizes and times as `heavy_burst_smoke.gdshader` -- read that for what an instance carries,
// how the puffs stack into a column, and why it is lit and unsorted. What FINE adds: every quad is drawn (sixteen puffs
// and ten pieces of debris); each puff's edge and density are broken by two octaves of noise fixed to the puff, so it
// billows rather than being a soft disc; and BACKLIGHT lets the sun through the thin edges.
//
// No depth texture and no soft particles, for the reason `smoke_fine.gdshader` rejected them.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;

#include "res://world/shaders/terrain_noise.gdshaderinc"

uniform float now = 0.0;
// PER BURST, because a small burst's smoke goes sooner: see BurstTuning.lasts.
instance uniform float life = 14.0;
uniform float grow;
uniform float rise;
uniform float delay_s;
uniform vec3 tone : source_color;
uniform float opacity;
uniform float debris_speed;
uniform float debris_s;
uniform float gravity;
uniform float least_angle = 0.0015;

instance uniform float born = -100000.0;
instance uniform float size = 10.0;
instance uniform vec3 wind = vec3(0.0);
instance uniform float grounded = 0.0;
instance uniform float turn = 0.0;
instance uniform float density = 1.0;

varying vec2 uv;
varying float fade;
varying float heat;
varying float kind;
varying float seed;
varying float age;
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
	float code = mod(floor(INSTANCE_CUSTOM.r + 0.5), 10.0);
	float t = now - born;
	uv = VERTEX.xy * 2.0;
	kind = code;
	seed = INSTANCE_CUSTOM.g;
	age = max(t, 0.0);
	lift = INSTANCE_CUSTOM.g;
	fade = 0.0;
	heat = 0.0;
	vec3 at = centre;
	float radius = 0.0;
	if (code < 0.5) {
		float late = t - delay_s * (0.6 + 0.8 * INSTANCE_CUSTOM.a);
		float k = late / life;
		if (late > 0.0 && k < 1.0) {
			float spread = sqrt(k);
			// A COLUMN: see `heavy_burst_smoke.gdshader`.
			float climbed = rise * size * 8.0 * (1.0 - exp(-late / 8.0)) * (0.2 + 1.6 * lift);
			vec3 across = vec3(dir.x, 0.0, dir.z) * size * (0.2 + 0.5 * spread) * (0.5 + 0.8 * lift);
			at = centre + across + vec3(0.0, climbed + size * 0.3, 0.0) + wind * late;
			radius = size * (0.45 + grow * spread) * (0.7 + 0.6 * INSTANCE_CUSTOM.b) * (0.7 + 0.5 * lift);
			fade = density * opacity * smoothstep(0.0, 0.4, late) * (1.0 - smoothstep(0.3, 1.0, k));
			heat = 1.0 - smoothstep(0.0, 1.0, late);
		}
	} else if (t >= 0.0) {
		float lasts = debris_s * (0.5 + 0.5 * INSTANCE_CUSTOM.a);
		if (t < lasts) {
			float drag = 0.5;
			vec3 thrown = dir * debris_speed * size * (0.4 + 0.6 * INSTANCE_CUSTOM.b);
			at = centre + thrown * (1.0 - exp(-drag * t)) / drag + vec3(0.0, -0.5 * gravity * t * t, 0.0);
			radius = max(size * 0.025 * (0.6 + 0.8 * INSTANCE_CUSTOM.b), length(BILLBOARD_EYE - at) * least_angle);
			fade = 1.0 - smoothstep(lasts * 0.7, lasts, t);
			heat = 1.0 - smoothstep(0.0, 0.8, t);
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
	vec3 ball = normalize(right_w * uv.x + up_w * uv.y + eye_w * (sqrt(max(1.0 - r * r, 0.0)) + 0.2));
	NORMAL = normalize((VIEW_MATRIX * vec4(ball, 0.0)).xyz);
	ROUGHNESS = 1.0;
	if (kind < 0.5) {
		float churn = fbm2(uv * 1.2 + vec2(seed * 23.0, seed * 11.0 + age * 0.04));
		float wisp = fbm2(uv * 3.1 + vec2(seed * 5.0 - age * 0.07, seed * 13.0));
		float body = (1.0 - smoothstep(0.15 + 0.5 * churn, 1.0, r)) * (0.55 + 0.65 * wisp);
		ALBEDO = tone * (0.7 + 0.45 * clamp(ball.y * 0.5 + 0.5, 0.0, 1.0)) * (0.85 + 0.3 * wisp) * mix(0.45, 1.05, lift);
		BACKLIGHT = tone * 0.3;
		EMISSION = vec3(1.0, 0.42, 0.1) * heat * heat * body * 1.4;
		ALPHA = clamp(body * fade, 0.0, 1.0);
	} else {
		float chunk = 1.0 - smoothstep(0.55, 0.8, r);
		ALBEDO = vec3(0.06);
		EMISSION = vec3(1.0, 0.5, 0.15) * heat * 2.0;
		ALPHA = clamp(chunk * fade, 0.0, 1.0);
	}
	ALBEDO *= 1.0 - mist_here.a;
	EMISSION = EMISSION * (1.0 - mist_here.a) + mist_here.rgb * mist_here.a;
}
