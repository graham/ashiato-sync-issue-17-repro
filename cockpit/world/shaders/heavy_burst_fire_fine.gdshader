// A BIG EXPLOSION, THE FIRE, FINE: the flash with a broken edge, a fireball of boiling flame, sparks with hot heads, a
// pale ring thrown out through the air, and -- on the ground -- fire that stays.
//
// The same instances, clock, sizes and times as `heavy_burst_fire.gdshader` -- read that for what an instance carries,
// for the two clocks a puff burns by and for the puffs that stay on the ground. What FINE adds: it draws every quad
// (the ones marked +10 as well), so nine puffs, forty-eight sparks and the ring; the fireball's edge, its lumps and its
// temperature are broken by two octaves of noise that move with the puff rather than the screen, so a fireball is a
// churning mass of flame and not a stack of soft discs; and the flash has a ragged rim.
//
// Still one draw call per burst and no texture: `fbm2` twice a fragment, and only on the fireball.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;

#include "res://world/shaders/terrain_noise.gdshaderinc"

uniform float now = 0.0;
uniform float flash_across;
uniform float flash_s;
uniform float grow_s;
uniform float cool_s;
uniform float burn_s;
uniform float ember_s;
uniform float rise;
uniform float spark_speed;
uniform float spark_s;
uniform float gravity;
uniform float ring_out;
uniform float ring_s;
uniform float least_angle = 0.0015;
const float LINGER_FROM = 0.55;

instance uniform float born = -100000.0;
instance uniform float size = 10.0;
instance uniform vec3 wind = vec3(0.0);
instance uniform float grounded = 0.0;
instance uniform float turn = 0.0;

varying vec2 uv;
varying float glow;
varying float heat;
varying float kind;
varying float seed;
varying float age;

vec3 turned(vec3 d) {
	float c = cos(turn);
	float s = sin(turn);
	vec3 r = vec3(c * d.x - s * d.z, d.y, s * d.x + c * d.z);
	r.y = grounded > 0.5 ? abs(r.y) : r.y;
	return r;
}

vec3 ramp(float h) {
	vec3 c = mix(vec3(0.18, 0.02, 0.0), vec3(0.85, 0.18, 0.02), smoothstep(0.0, 0.35, h));
	c = mix(c, vec3(1.0, 0.45, 0.05), smoothstep(0.35, 0.65, h));
	c = mix(c, vec3(1.0, 0.75, 0.25), smoothstep(0.65, 0.9, h));
	return mix(c, vec3(1.0, 0.95, 0.8), smoothstep(0.93, 1.0, h));
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
	glow = 0.0;
	heat = 0.0;
	vec3 at = centre;
	float radius = 0.0;
	vec3 axis = vec3(0.0);
	float stretch = 0.0;
	if (t >= 0.0) {
		if (code < 0.5) {
			radius = size * flash_across * 0.5 * (0.55 + 0.45 * smoothstep(0.0, flash_s * 0.5, t));
			glow = 1.0 - smoothstep(0.0, flash_s, t);
			heat = 1.0;
		} else if (code < 1.5) {
			// IN THE AIR ONLY: see BurstTuning's RING.
			float k = clamp(t / ring_s, 0.0, 1.0);
			radius = size * (1.0 + ring_out * pow(k, 0.6));
			glow = (t < ring_s && grounded < 0.5) ? (1.0 - k) * (1.0 - k) : 0.0;
		} else if (code < 2.5) {
			float late = t - INSTANCE_CUSTOM.a * 0.08;
			float grown = 1.0 - pow(1.0 - clamp(late / grow_s, 0.0, 1.0), 3.0);
			float since = max(late, 0.0);
			// OUT TO 0.62 AND 0.48 TO 0.78 ACROSS, and a burst on the ground lifted by a third of its size: see
			// `heavy_burst_fire.gdshader`, where the pictures that set these are written down.
			at = centre + dir * size * 0.62 * grown + vec3(0.0, grounded * size * 0.35 + rise * since, 0.0) + wind * since * 0.5;
			radius = size * (0.48 + 0.30 * INSTANCE_CUSTOM.b) * (0.35 + 0.65 * grown);
			float pace = 0.7 + 0.6 * INSTANCE_CUSTOM.g;
			heat = max(1.0 - smoothstep(0.0, cool_s * pace, late), 0.62 * (1.0 - smoothstep(0.0, burn_s * pace, late)));
			glow = late > 0.0 ? 1.0 - smoothstep(burn_s * 0.45 * pace, burn_s * pace, late) : 0.0;
			float settle = grounded * step(LINGER_FROM, INSTANCE_CUSTOM.a) * smoothstep(burn_s * 0.3, burn_s * 0.8, late);
			vec3 flat_way = vec3(dir.x, 0.0, dir.z);
			vec3 ground_at = centre + flat_way * size * (0.25 + 0.5 * INSTANCE_CUSTOM.b) + vec3(0.0, size * 0.06, 0.0);
			at = mix(at, ground_at, settle);
			radius = mix(radius, size * (0.12 + 0.12 * INSTANCE_CUSTOM.b), settle);
			heat = mix(heat, 0.34 + 0.12 * sin(now * 11.0 + INSTANCE_CUSTOM.g * 37.0), settle);
			glow = mix(glow, 0.9 * (1.0 - smoothstep(ember_s * 0.6, ember_s, late)), settle);
		} else {
			float life = spark_s * (0.4 + 0.6 * INSTANCE_CUSTOM.a);
			float drag = 1.2;
			vec3 thrown = dir * spark_speed * size * (0.3 + 0.7 * INSTANCE_CUSTOM.b);
			at = centre + thrown * (1.0 - exp(-drag * t)) / drag + vec3(0.0, -0.5 * gravity * t * t, 0.0);
			vec3 going = thrown * exp(-drag * t) + vec3(0.0, -gravity * t, 0.0);
			glow = t < life ? 1.0 - t / life : 0.0;
			heat = glow;
			axis = length(going) > 0.001 ? normalize(going) : vec3(0.0, 1.0, 0.0);
			stretch = clamp(length(going) * 0.06, 0.5, size * 0.6);
			radius = size * 0.012;
		}
	}
	vec3 world = at;
	if (glow > 0.0) {
		radius = max(radius, length(BILLBOARD_EYE - at) * least_angle);
		if (stretch > 0.0) {
			vec3 side = cross(axis, BILLBOARD_EYE - at);
			side = length(side) > 0.000001 ? normalize(side) : INV_VIEW_MATRIX[0].xyz;
			world = at + axis * VERTEX.x * stretch + side * VERTEX.y * radius * 2.0;
		} else {
			world = at + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * radius * 2.0;
		}
	}
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_LOCAL_OF(world);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float r = length(uv);
	vec3 colour;
	if (kind < 0.5) {
		float rim = fbm2(vec2(atan(uv.y, uv.x) * 2.5 + seed * 9.0, r * 1.5));
		float core = pow(clamp(1.0 - r / (0.7 + 0.35 * rim), 0.0, 1.0), 1.8);
		colour = vec3(1.0, 0.95, 0.85) * core * glow * 2.0;
	} else if (kind < 1.5) {
		float band = exp(-pow((r - 0.9) / 0.06, 2.0));
		colour = vec3(0.85, 0.9, 1.0) * band * glow * 0.22;
	} else if (kind < 2.5) {
		// BOILING FLAME: the churn eats the edge and makes lumps, the boil breaks the temperature, and the rim burns cooler.
		float churn = fbm2(uv * 1.7 + vec2(seed * 31.0, seed * 17.0 - age * 0.9));
		float boil = fbm2(uv * 3.9 + vec2(seed * 7.0 + age * 0.4, age * 1.3));
		float body = (1.0 - smoothstep(0.3 + 0.5 * churn, 1.0, r)) * (0.55 + 0.6 * churn);
		float h = clamp(heat * (0.55 + 0.8 * boil) * (1.05 - 0.5 * r), 0.0, 1.0);
		colour = ramp(h) * body * glow * (0.3 + 0.7 * h) * 0.9;
	} else {
		float streak = (1.0 - smoothstep(0.3, 1.0, abs(uv.x))) * (1.0 - smoothstep(0.0, 1.0, abs(uv.y)));
		colour = mix(vec3(1.0, 0.35, 0.05), vec3(1.0, 0.85, 0.5), clamp(uv.x * 0.5 + 0.5, 0.0, 1.0)) * streak * glow * 3.0;
	}
	ALBEDO = colour * (1.0 - mist_here.a);
	ALPHA = 1.0;
}
