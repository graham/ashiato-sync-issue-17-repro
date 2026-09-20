// WHITEWATER THROWN UP BY AN AIRCRAFT SKIMMING THE SEA: puffs of spray and mist that leave the water, rise, spread and fall
// back, thrown behind and beside anything within 3 m of the water at more than 80 km/h (SprayYard, WakeTuning). The
// rooster tail a seaplane throws off its step, and the sheet a low pass tears off the sea.
//
// EVERY PUFF IS ONE INSTANCE OF ONE MULTIMESH, thrown once by SprayYard and never touched again: where it is now -- risen,
// slowed by the air and fallen back -- is worked out HERE from when it was thrown and how, so a sky full of spray costs the
// processor only the throwing.
//
// What an instance carries:
//   the transform's origin     where it left the water;
//   INSTANCE_CUSTOM            (when it was thrown, on the yard's clock `now`; and its velocity then, x y z, m/s);
//   COLOR                      (how strongly it was thrown 0 to 1, which puff, how long it lasts in seconds, how big it grows
//                              as a share of `size_to`).
// A puff that has not been thrown, or whose life is over, collapses to a point and draws nothing.
//
// FACING THE EYE, placed through MODELVIEW_MATRIX (billboard.gdshaderinc), so it stands still on the double build.
// SOFT AT THE WATER, PER PIXEL: every pixel knows how high it is over the water the puff left, and fades to nothing at it,
// since nothing here can read the depth buffer. Faded by the puff's middle only, a puff half in the sea was cut off flat
// along the waterline (first pictures, 2026-09-17).
//
// DROPS, THEN MIST: a young puff is speckled with drops and has a bright core; as it ages the speckle smooths out and it
// thins to mist. Drawn smooth, the first puffs read as cotton wool -- smoke, not water.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
#include "res://world/shaders/terrain_noise.gdshaderinc"

varying vec4 mist_here;
uniform float now = 0.0;
// HANDED BY SprayYard FROM WakeTuning, once.
uniform float size_from = 1.6;
uniform float size_to = 7.0;
uniform float whiteness = 0.85;
// How quickly the air takes a puff's speed away, per second. Spray is small drops and mist: it stops quickly.
uniform float drag = 0.9;
// HOW MUCH A YOUNG PUFF IS DRAWN OUT ALONG ITS FLIGHT: seconds of its speed on the screen. Round, the first rooster tails
// read as cotton wool; drawn out along the way they fly, they read as water thrown.
uniform float streak = 0.12;
uniform vec3 spray_colour : source_color = vec3(0.92, 0.95, 0.97);
instance uniform vec3 light = vec3(1.0);

varying float left;
varying float strength;
varying float seed;
varying float above;
varying float size;
varying float young;

void vertex() {
	float age = now - INSTANCE_CUSTOM.r;
	float life = COLOR.b;
	strength = COLOR.r;
	seed = COLOR.g;
	if (age < 0.0 || age > life || life <= 0.0 || strength <= 0.0) {
		VERTEX = vec3(0.0);
		left = 0.0;
		above = 0.0;
		size = 1.0;
		young = 0.0;
		mist_here = vec4(0.0);
	} else {
		vec3 thrown = INSTANCE_CUSTOM.gba;
		// SLOWED BY THE AIR: x(t) = v (1 - e^-kt) / k, and gravity on top.
		float slowed = (1.0 - exp(-drag * age)) / drag;
		vec3 at = thrown * slowed;
		at.y -= 0.5 * 9.81 * age * age;
		float grown = sqrt(clamp(age / life, 0.0, 1.0));
		size = mix(size_from, size_to * COLOR.a, grown);
		left = 1.0 - age / life;
		young = exp(-age / 1.2);
		// ITS VELOCITY NOW, on the screen: the way it is drawn out.
		vec3 moving = thrown * exp(-drag * age) + vec3(0.0, -9.81 * age, 0.0);
		vec2 on_screen = (mat3(VIEW_MATRIX) * moving).xy;
		float fast = length(on_screen);
		vec2 way = fast > 0.1 ? on_screen / fast : vec2(0.0, 1.0);
		vec2 square = vec2(-way.y, way.x);
		// DRAWN OUT FOR ITS WHOLE FLIGHT, rising and falling: drawn out only while young, the tail of a rooster tail was
		// round puffs (round 3, 2026-09-17).
		float drawn_out = 1.0 + min(fast * streak, 4.0) * (0.5 + 0.5 * young);
		vec3 corner = vec3((way * VERTEX.y * drawn_out + square * VERTEX.x) * size, 0.0);
		vec3 view_at = mat3(VIEW_MATRIX) * at + corner;
		// HOW HIGH THIS CORNER IS over the water the puff left, in world metres: interpolated, it is each pixel's.
		above = at.y + (transpose(mat3(VIEW_MATRIX)) * corner).y;
		mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + at, mist_clock);
		VERTEX = BILLBOARD_LOCAL_FROM_VIEW(view_at);
	}
}

void fragment() {
	if (left <= 0.0) {
		discard;
	}
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float lumps = fbm2_wrapped(p * 2.2 + vec2(seed * 7.1, seed * 3.3), LATTICE_PERIOD);
	float shape = 1.0 - smoothstep(0.15 + 0.4 * lumps, 1.0, r);
	float drops = value_noise_wrapped(p * 9.0 + vec2(seed * 31.0, seed * 17.0), LATTICE_PERIOD);
	float speckle = mix(1.0, smoothstep(0.25, 0.75, drops) * 1.4, young * 0.8);
	float core = 1.0 - smoothstep(0.0, 0.55, r);
	// IN QUICKLY, OUT SLOWLY; and gone at the water it came from.
	float fade = smoothstep(0.0, 0.08, 1.0 - left) * left;
	float soft = smoothstep(0.0, max(size * 0.25, 0.3), above);
	float alpha = whiteness * strength * shape * speckle * fade * soft * mix(0.55, 1.0, core * young);
	if (alpha < 0.004) {
		discard;
	}
	vec3 colour = spray_colour * light * (0.82 + 0.18 * lumps);
	ALBEDO = mix(colour, mist_here.rgb, mist_here.a);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
