// WHERE THE DRAWN SEA STANDS OVER A POINT, relative to still water: the same sums `ocean.gdshader` and `ocean_fine.gdshader`
// move their vertices by, for a thing that must lie ON the sea rather than through it -- a ship's wake (wake.gdshader,
// wake_bow.gdshader).
//
// THREE LAYERS, as the seas draw them:
//   the simulation's STANDING SWELL (`standing_*`), which every hull floats on, faded between `standing_near` and
//   `standing_gone` from the eye;
//   the WIND-SEA THE BOATS FEEL (`standing_wind`), faded between `standing_wind_near` and `standing_wind_gone`;
//   on the fine finish only, the four Gerstner waves of CHOP (`chop_steepness`, 0 on plain), faded between `shape_near`
//   and `shape_gone`. Only their height: a Gerstner wave also moves a point sideways by a few centimetres at this
//   steepness, which a wake lifted `lift` metres does not notice.
// All of it scaled by `sea_motion` (still_water.gdshaderinc), which is nothing on water that says it is inland and
// nothing on or near the land. It used to say here that a lake is "inside it" and so still, which was true on the
// island level and false on every generated one: see still_water.gdshaderinc for the thirty lakes that measured it.
//
// THE SAME UNIFORM NAMES AS THE SEAS', so `SeaSwell.hand_the_swell` hands a wake's material its swell exactly as it hands
// the seas theirs, and nothing types the swell a second time. The fade distances are the seas' defaults; tests/wakes.gd
// holds this file's defaults equal to both ocean shaders'.
//
// Evaluated per VERTEX of the wake, whose cells are finer than the sea's 3 m near the eye only where the wake is narrow;
// what the two grids disagree by between vertices is what `lift` and `pull` are for.
#ifndef SEA_SURFACE_GDSHADERINC
#define SEA_SURFACE_GDSHADERINC

#include "res://world/shaders/still_water.gdshaderinc"

uniform float standing_height = 0.0;
uniform float standing_second_height = 0.0;
uniform vec2 standing_first = vec2(0.0);
uniform vec2 standing_second = vec2(0.0);
uniform float standing_tile = 2048.0;
uniform float standing_near = 350.0;
uniform float standing_gone = 600.0;
uniform vec3 standing_wind[3];
uniform float standing_wind_near = 110.0;
uniform float standing_wind_gone = 170.0;
// THE FINE SEA'S CHOP: its `swell_steepness` on FINE, handed by WakeYard, and 0 on PLAIN, whose sea has none.
uniform float chop_steepness = 0.0;
uniform vec2 wind = vec2(0.9010, -0.4338);
uniform float shape_near = 110.0;
uniform float shape_gone = 320.0;

float sea_gerstner_height(vec2 x, vec2 dir, float wavelength, float steep, float t) {
	float k = 6.28318 / wavelength;
	return steep / k * sin(k * (dot(dir, x) - sqrt(9.81 / k) * t));
}

// The drawn sea's height at `xz` over still water, for an eye at `eye` (EYE_POSITION_WORLD) at time `t` (TIME).
float sea_height_at(vec2 xz, vec3 eye, float t) {
	float range = length(xz - eye.xz);
	float coast = sea_motion(xz);
	if (coast <= 0.0001) {
		return 0.0;
	}
	float y = 0.0;
	vec2 p = xz - standing_tile * floor(xz / standing_tile);
	float held = (1.0 - smoothstep(standing_near, standing_gone, range)) * coast;
	if (held > 0.0001) {
		y += (sin(dot(p, standing_first)) * standing_height + sin(dot(p, standing_second)) * standing_second_height) * held;
	}
	float windy = (1.0 - smoothstep(standing_wind_near, standing_wind_gone, range)) * coast;
	if (windy > 0.0001) {
		for (int i = 0; i < 3; i++) {
			y += sin(dot(p, standing_wind[i].xy)) * standing_wind[i].z * windy;
		}
	}
	float q = chop_steepness * (1.0 - smoothstep(shape_near, shape_gone, range)) * coast;
	if (q > 0.0001) {
		vec2 w = normalize(wind);
		vec2 across = vec2(-w.y, w.x);
		y += sea_gerstner_height(xz, w, 70.0, 0.10 * q, t);
		y += sea_gerstner_height(xz, normalize(w + across * 0.55), 43.0, 0.10 * q, t);
		y += sea_gerstner_height(xz, normalize(w - across * 0.7), 27.0, 0.08 * q, t);
		y += sea_gerstner_height(xz, normalize(w + across * 1.4), 16.0, 0.07 * q, t);
	}
	return y;
}
#endif
