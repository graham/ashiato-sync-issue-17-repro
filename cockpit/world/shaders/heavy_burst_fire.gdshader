// A BIG EXPLOSION, THE FIRE, PLAIN: the flash, a fireball of flame, sparks, and -- on the ground -- fire that stays.
//
// EVERY QUAD OF EVERY BURST IS AN INSTANCE OF ONE MULTIMESH THE YARD LAID OUT ONCE (see BurstYard and HeavyBurst),
// and nothing about any of them is written again: where each has flown, how big it has swelled and how far it has
// cooled is worked out here from how long ago its burst was set off, on the yard's clock.
//
// What an instance carries:
//   the transform's X column   a direction in the burst's frame, turned by `turn` and folded upwards on the ground:
//                              which way a spark is thrown, or where in the ball a puff sits (its length is how far);
//   the transform's origin     nothing: the node's own place is the burst's centre;
//   INSTANCE_CUSTOM.r          what it is: 0 the flash, 1 the ring, 2 a fireball puff, 3 a spark -- plus 10 for a quad
//                              only FINE draws, which this collapses to nothing;
//   INSTANCE_CUSTOM.g / .b / .a   three numbers 0..1 of its own: a seed, a size or speed, a lifetime or delay.
//
// FIRE, NOT A GLOWING BALL (asked for on 2026-09-14, after the first pictures: "reads as a smooth pale yellow-white
// ball, not fire"). Two clocks per puff: `cool_s`, how long it is white-hot -- a moment -- and `burn_s`, how long it
// goes on burning orange down to a dull red before it goes out. Its rim burns cooler than its middle, and a pattern of
// lumps fixed to the puff breaks both its edge and its temperature. ON THE GROUND, the puffs whose own number is past
// `LINGER_FROM` settle to the ground as the ball burns out and flicker there as small fires until `ember_s`: no quad is
// added for them, they are puffs that stay.
//
// PLAIN IS THE SAME BURST WITH LESS IN IT: five puffs rather than nine, twenty sparks rather than forty-eight, no ring,
// and a few sines where FINE has noise. The sizes and the times are the same numbers, so a finish changed mid-burst
// changes how it is drawn and not what it is.
//
// FACING THE CAMERA'S OWN AXES, not a direction to each eye: both eyes share the head's turn, so a disc is one disc in
// both. A spark is turned about its own flight to face the midpoint of the eyes, as a trail is.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The yard's clock, written by BurstYard while any burst is going.
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;
uniform float now = 0.0;
// Written once by BurstYard from BurstTuning, which is the one place each number is. No defaults, on purpose.
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
// The smallest a lit thing is drawn, as a fraction of its distance from the eye.
uniform float least_angle = 0.0015;
// Which puffs stay on the ground as fires: those whose own number is past this.
const float LINGER_FROM = 0.55;

// Per burst, written when it is set off.
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

// A FLAME'S TEMPERATURE, not a colour: dull red, orange, yellow, and white only at the very top -- which a puff reaches
// only while it is white-hot.
vec3 ramp(float h) {
	vec3 c = mix(vec3(0.18, 0.02, 0.0), vec3(0.85, 0.18, 0.02), smoothstep(0.0, 0.35, h));
	c = mix(c, vec3(1.0, 0.45, 0.05), smoothstep(0.35, 0.65, h));
	c = mix(c, vec3(1.0, 0.75, 0.25), smoothstep(0.65, 0.9, h));
	return mix(c, vec3(1.0, 0.95, 0.8), smoothstep(0.93, 1.0, h));
}

// LUMPS OF FLAME, 0..1, fixed to the puff and turning over slowly: a few sines rather than FINE's noise -- ROUND THE PUFF
// AND OUT FROM ITS MIDDLE, never along a straight line. The first version added a sine of x + y, and every PLAIN fireball
// in the pictures wore the same diagonal stripes (2026-09-14).
float lumps(vec2 p, float s, float a) {
	float round_it = atan(p.y, p.x);
	float out_of_it = length(p);
	return clamp(0.5 + 0.3 * sin(round_it * 3.0 + s * 20.0 + a * 0.9) * cos(out_of_it * 4.0 - s * 9.0 - a * 1.3)
		+ 0.2 * sin(round_it * 5.0 - s * 13.0 - a * 0.7) * sin(out_of_it * 2.5 + s * 5.0), 0.0, 1.0);
}

void vertex() {
	// RELATIVE TO THE BURST'S ORIGIN, which the engine places exactly: see billboard.gdshaderinc.
	vec3 centre = vec3(0.0);
	vec3 dir = turned(MODEL_MATRIX[0].xyz);
	float code = floor(INSTANCE_CUSTOM.r + 0.5);
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
	if (code < 9.5 && t >= 0.0) {
		if (code < 0.5) {
			radius = size * flash_across * 0.5 * (0.55 + 0.45 * smoothstep(0.0, flash_s * 0.5, t));
			glow = 1.0 - smoothstep(0.0, flash_s, t);
			heat = 1.0;
		} else if (code > 1.5 && code < 2.5) {
			float late = t - INSTANCE_CUSTOM.a * 0.08;
			float grown = 1.0 - pow(1.0 - clamp(late / grow_s, 0.0, 1.0), 3.0);
			float since = max(late, 0.0);
			// OUT TO 0.62 AND 0.48 TO 0.78 ACROSS, and a burst on the ground lifted by a third of its size: measured
			// against the pictures, so the lit ball is as wide as `size` says. 0.43 and 0.32..0.57 drew a 42 m 105 as a
			// 20 m dome with its lower half under the runway.
			at = centre + dir * size * 0.62 * grown + vec3(0.0, grounded * size * 0.35 + rise * since, 0.0) + wind * since * 0.5;
			radius = size * (0.48 + 0.30 * INSTANCE_CUSTOM.b) * (0.35 + 0.65 * grown);
			// WHITE-HOT FOR A MOMENT, then burning orange down to red for `burn_s`, each puff at its own pace.
			float pace = 0.7 + 0.6 * INSTANCE_CUSTOM.g;
			heat = max(1.0 - smoothstep(0.0, cool_s * pace, late), 0.62 * (1.0 - smoothstep(0.0, burn_s * pace, late)));
			glow = late > 0.0 ? 1.0 - smoothstep(burn_s * 0.45 * pace, burn_s * pace, late) : 0.0;
			// AND ON THE GROUND, SOME OF IT STAYS: settled beside where it hit, small, flickering, until `ember_s`.
			float settle = grounded * step(LINGER_FROM, INSTANCE_CUSTOM.a) * smoothstep(burn_s * 0.3, burn_s * 0.8, late);
			vec3 flat_way = vec3(dir.x, 0.0, dir.z);
			vec3 ground_at = centre + flat_way * size * (0.25 + 0.5 * INSTANCE_CUSTOM.b) + vec3(0.0, size * 0.06, 0.0);
			at = mix(at, ground_at, settle);
			radius = mix(radius, size * (0.12 + 0.12 * INSTANCE_CUSTOM.b), settle);
			heat = mix(heat, 0.34 + 0.12 * sin(now * 11.0 + INSTANCE_CUSTOM.g * 37.0), settle);
			glow = mix(glow, 0.9 * (1.0 - smoothstep(ember_s * 0.6, ember_s, late)), settle);
		} else if (code > 2.5) {
			float life = spark_s * (0.4 + 0.6 * INSTANCE_CUSTOM.a);
			float drag = 1.2;
			vec3 thrown = dir * spark_speed * size * (0.3 + 0.7 * INSTANCE_CUSTOM.b);
			at = centre + thrown * (1.0 - exp(-drag * t)) / drag + vec3(0.0, -0.5 * gravity * t * t, 0.0);
			vec3 going = thrown * exp(-drag * t) + vec3(0.0, -gravity * t, 0.0);
			glow = t < life ? 1.0 - t / life : 0.0;
			heat = glow;
			axis = length(going) > 0.001 ? normalize(going) : vec3(0.0, 1.0, 0.0);
			stretch = clamp(length(going) * 0.05, 0.4, size * 0.5);
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
		colour = vec3(1.0, 0.95, 0.82) * pow(clamp(1.0 - r, 0.0, 1.0), 2.0) * glow * 2.0;
	} else if (kind < 2.5) {
		// A BROKEN EDGE AND A COOLER RIM: the lumps eat into the edge and into the temperature, and the middle of a
		// puff burns hotter than its outside.
		float lump = lumps(uv, seed, age);
		float body = 1.0 - smoothstep(0.35 + 0.35 * lump, 1.0, r);
		float h = clamp(heat * (1.05 - 0.55 * r) * (0.75 + 0.5 * lump), 0.0, 1.0);
		colour = ramp(h) * body * glow * (0.35 + 0.65 * h) * 0.85;
	} else {
		float streak = (1.0 - smoothstep(0.3, 1.0, abs(uv.x))) * (1.0 - smoothstep(0.0, 1.0, abs(uv.y)));
		colour = vec3(1.0, 0.62, 0.22) * streak * glow * 2.5;
	}
	ALBEDO = colour * (1.0 - mist_here.a);
	ALPHA = 1.0;
}
