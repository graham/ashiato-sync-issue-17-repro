// THE OCEAN, ON THE FINE FINISH: the plain ocean's surface, on a sea with a shape.
//
// Everything `ocean.gdshader` says still holds -- opaque, no screen or depth texture, the wind-sea painted from
// `ocean_detail.gdshaderinc` and band-limited by the pixel, the same four sines and five octaves of noise ripples as PLAIN.
// What is added, and why each is worth its cost:
//
//   SHAPE. Four Gerstner waves displace the vertices of `SeaSwell`'s grid near the eye, on the simulation's standing swell.
//   A Gerstner wave moves a point in a circle as it passes rather than only up and down, which is what gives a sea its
//   sharp crests and flat troughs. Faded to flat by `shape_gone` metres, which is the range the grid's cells get too wide
//   to carry a wave, and to flat on and near the land so no wave comes up through it, and on any water that says it is
//   inland (`sea_motion`, still_water.gdshaderinc). SMALL ON PURPOSE: no hull
//   floats on it (see `swell_steepness`).
//
//   ITS NORMAL PER PIXEL. The shape's slope is analytic, and it was made per vertex and interpolated, which drew straight
//   bright facet lines along the sheet's 3 m triangles (before pictures, close_8 and the launch's helm, 2026-09-15). The
//   four waves and the swell's slope are evaluated again in `fragment()` at the rest position the vertex had.
//
//   LIGHT THROUGH THE CRESTS. The top of a wave is thin water and glows green-blue with the sun behind it: BACKLIGHT, on
//   the chop's own crests and the wind-sea's.
//
//   WIND STREAKS. Foam drawn out ALONG the wind and drifting down it, which is how a pilot reads the wind off the sea --
//   faint, because drawn strongly they read as stripes (see below).
//
// Both eyes agree on every vertex: the fade is measured from EYE_POSITION_WORLD, which in stereo is the midpoint of the eyes.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;
#include "res://world/shaders/eye.gdshaderinc"
#include "res://world/shaders/still_water.gdshaderinc"
#include "res://world/shaders/shore_water.gdshaderinc"

#include "res://world/shaders/terrain_noise.gdshaderinc"
#define WAVES_PAINTED 4
#include "res://world/shaders/ocean_detail.gdshaderinc"
#include "res://world/shaders/sea_glint.gdshaderinc"

uniform vec3 deep_colour : source_color = vec3(0.016, 0.055, 0.094);
// Half what it was first, as on the plain sea (after5, dusk_20).
uniform vec3 crest_colour : source_color = vec3(0.028, 0.113, 0.106);
uniform vec3 foam_colour : source_color = vec3(0.82, 0.88, 0.90);
uniform float wave_speed = 0.55;
// Which way the air is moving over the sea, in metres a second. Set from Terrain.WIND.
uniform vec2 wind = vec2(5.4, -2.6);
// SCALES ALL FOUR WAVES TOGETHER, and it is small on purpose (team-lead, 2026-09-15). This chop travels with TIME and
// the simulation floats no hull on it -- it cannot, or a replayed tick would meet a different sea -- so every metre it
// adds is a metre of sea drawn over a deck the simulation keeps dry. At 0.4 its crests reached 0.93 m above the simulated
// swell, and cockpit-carrier's launch, 0.4 m of freeboard, looked swamped from its own helm on FINE and dry on PLAIN.
// At 0.15 they reach 0.35 m where all four line up -- under the launch's 0.4 m of deck over the simulated water even with
// its worst 2.2 degrees of heel (0.05 m at its side) -- and from carrier's helm (tests/ship_shot.gd --kinds=boat
// --shots=helm,helm_down) the plated deck reads dry, where at 0.4 a line-up of all four can reach twice that deck.
uniform float swell_steepness : hint_range(0.0, 1.0) = 0.15;
uniform float shape_near = 110.0;
uniform float shape_gone = 320.0;

// THE STANDING SWELL THE SIMULATION FLOATS EVERY HULL ON (`swell_height` in cockpit_world.cpp), as the base the chop
// rides on, so the water drawn at a hull is the water the hull is in. Handed in by SeaSwell from `Sim.swell_shape`:
// zero heights until then, which is this shader as it was. Wrapped with floor at `standing_tile`, exactly as the physics
// wraps it. Faded out between `standing_near` and `standing_gone` from the eye, because past there SeaSwell's cells are
// too coarse to carry a 153 m wave without aliasing, and a hull that far off is a few pixels.
uniform float standing_height = 0.0;
uniform float standing_second_height = 0.0;
uniform vec2 standing_first = vec2(0.0);
uniform vec2 standing_second = vec2(0.0);
uniform float standing_tile = 2048.0;
uniform float standing_near = 350.0;
uniform float standing_gone = 600.0;
// AND THE WIND-SEA THE BOATS FEEL, as on the plain sea: each wave's vector in xy and its height in z, drawn only where the
// sheet's cells hold a 26 m wave.
uniform vec3 standing_wind[3];
uniform float standing_wind_near = 110.0;
uniform float standing_wind_gone = 170.0;

varying vec3 world_pos;
// HOW DEEP THE WATER IS HERE, metres, off the mesh's own CUSTOM0 (`LakeSheets`). Only inland water carries it; the sea
// has no such attribute, which is why every read of it is behind `inland` (shore_water.gdshaderinc).
varying float water_depth;
varying float crest;
// Where the vertex stood before it was moved, for the shape's normal worked out again per pixel.
varying vec2 rest_xz;

vec3 gerstner(vec2 x, vec2 dir, float wavelength, float steep, float t,
		inout vec3 tangent, inout vec3 binormal) {
	float k = 6.28318 / wavelength;
	// Deep-water waves travel at the speed their length sets. Typing a speed in would put a
	// seventy-metre swell and a sixteen-metre chop at the same pace, which reads as a sheet.
	float f = k * (dot(dir, x) - sqrt(9.81 / k) * t);
	float a = steep / k;
	float s = sin(f);
	float c = cos(f);
	tangent += vec3(-dir.x * dir.x * steep * s, dir.x * steep * c, -dir.x * dir.y * steep * s);
	binormal += vec3(-dir.x * dir.y * steep * s, dir.y * steep * c, -dir.y * dir.y * steep * s);
	return vec3(dir.x * a * c, a * s, dir.y * a * c);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float range = length(wp.xz - EYE_POSITION_WORLD.xz);
	float coast = sea_motion(wp.xz);
	float reach = (1.0 - smoothstep(shape_near, shape_gone, range)) * coast;
	vec2 w = normalize(wind);
	vec2 across = vec2(-w.y, w.x);
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	vec3 offset = vec3(0.0);
	float q = swell_steepness * reach;
	if (q > 0.0001) {
		offset += gerstner(wp.xz, w, 70.0, 0.10 * q, TIME, tangent, binormal);
		offset += gerstner(wp.xz, normalize(w + across * 0.55), 43.0, 0.10 * q, TIME,
			tangent, binormal);
		offset += gerstner(wp.xz, normalize(w - across * 0.7), 27.0, 0.08 * q, TIME,
			tangent, binormal);
		offset += gerstner(wp.xz, normalize(w + across * 1.4), 16.0, 0.07 * q, TIME,
			tangent, binormal);
	}
	// The standing swell, under the chop.
	float held = (1.0 - smoothstep(standing_near, standing_gone, range)) * coast;
	vec3 base = vec3(0.0);
	if (held > 0.0001 && (standing_height > 0.0 || standing_second_height > 0.0)) {
		vec2 p = wp.xz - standing_tile * floor(wp.xz / standing_tile);
		float f1 = dot(p, standing_first);
		float f2 = dot(p, standing_second);
		base.y = (sin(f1) * standing_height + sin(f2) * standing_second_height) * held;
	}
	float windy = (1.0 - smoothstep(standing_wind_near, standing_wind_gone, range)) * coast;
	if (windy > 0.0001) {
		vec2 q = wp.xz - standing_tile * floor(wp.xz / standing_tile);
		for (int i = 0; i < 3; i++) {
			base.y += sin(dot(q, standing_wind[i].xy)) * standing_wind[i].z * windy;
		}
	}
	VERTEX += offset + base;
	water_depth = CUSTOM0.x;
	world_pos = wp + offset + base;
	// Foam keys off the chop's own crests, not the swell under it.
	crest = offset.y;
	rest_xz = wp.xz;
}

// THE SHAPE'S NORMAL AT A REST POSITION: the four Gerstner waves' and the standing swell's analytic slopes, with the same
// fades `vertex()` gives them.
vec3 shape_normal(vec2 x, vec3 eye) {
	float range = length(x - eye.xz);
	float coast = sea_motion(x);
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	float q = swell_steepness * (1.0 - smoothstep(shape_near, shape_gone, range)) * coast;
	if (q > 0.0001) {
		vec2 w = normalize(wind);
		vec2 across = vec2(-w.y, w.x);
		gerstner(x, w, 70.0, 0.10 * q, TIME, tangent, binormal);
		gerstner(x, normalize(w + across * 0.55), 43.0, 0.10 * q, TIME, tangent, binormal);
		gerstner(x, normalize(w - across * 0.7), 27.0, 0.08 * q, TIME, tangent, binormal);
		gerstner(x, normalize(w + across * 1.4), 16.0, 0.07 * q, TIME, tangent, binormal);
	}
	float held = (1.0 - smoothstep(standing_near, standing_gone, range)) * coast;
	if (held > 0.0001 && (standing_height > 0.0 || standing_second_height > 0.0)) {
		vec2 p = x - standing_tile * floor(x / standing_tile);
		vec2 slope = (cos(dot(p, standing_first)) * standing_height * standing_first
			+ cos(dot(p, standing_second)) * standing_second_height * standing_second) * held;
		tangent.y += slope.x;
		binormal.y += slope.y;
	}
	float windy = (1.0 - smoothstep(standing_wind_near, standing_wind_gone, range)) * coast;
	if (windy > 0.0001) {
		vec2 q = x - standing_tile * floor(x / standing_tile);
		for (int i = 0; i < 3; i++) {
			vec2 slope = standing_wind[i].xy * (cos(dot(q, standing_wind[i].xy)) * standing_wind[i].z * windy);
			tangent.y += slope.x;
			binormal.y += slope.y;
		}
	}
	return normalize(cross(binormal, tangent));
}

// The same wavelet with its direction and wavenumber as one vector, which is how the simulation hands its swell over.
vec2 wavelet_k(vec2 p, vec2 k, float amp, float t) {
	return k * cos(dot(p, k) + t) * amp;
}

void fragment() {
	vec3 eye = EYE_POSITION_WORLD;
	float dist = length(world_pos - eye);
	float detail = detail_fade(dist, 120.0, 1400.0);
	float swell = detail_fade(dist, 900.0, 7000.0);

	// NOT WRAPPED. `tile` puts a seam where a wavelet's phase jumps, and the plain finish showed it
	// as a straight line across the sea (first render check, 2026-09-12, coast view; and down the
	// middle of mist's sea_low view on z = 0, 2026-09-15, after which the plain shader's chop and
	// churn stopped wrapping too). The precision the wrap was protecting is not needed here: the largest
	// argument is about 9 km times 0.27, some 2400 radians, which a float holds to a few ten-
	// thousandths -- far below a pixel of wave. The wind-sea wraps itself, at a tile its waves are whole in.
	vec2 p = world_pos.xz;
	float t = TIME * wave_speed;

	// The painted swell is the simulation's two waves, as on the plain sea.
	vec2 slope = wavelet_k(p, standing_first, standing_height, t * 0.9);
	slope += wavelet_k(p, standing_second, standing_second_height, t * 1.15);
	slope *= swell;

	// Metres a pixel as the geometric mean of its two sides, as on the plain sea.
	float footprint = max(sqrt(length(dFdx(world_pos.xz)) * length(dFdy(world_pos.xz))), 0.0001);
	// THE CHURN ON TURNED GRADIENT NOISE, with its lattice wrapped (terrain_noise.gdshaderinc): value noise read at the
	// world position far out hashes lattice corners too large for a float's fraction and draws straight-edged seams, and
	// its smoothstep lattice creases along x and z -- a hard diagonal edge across the near water from a brig 11 km out
	// (cell 132, 268 in the second octave), the same with the sun's shadows on and off, 2026-09-15. It bends the wind-sea's
	// crests.
	float churn = fbm2_turned(p * 0.012 + vec2(t * 0.05, -t * 0.03), LATTICE_PERIOD);
	vec2 w = normalize(wind);
	// CAT'S PAWS, two octaves on FINE: gusts roughen patches, drifting down the wind.
	// One octave at each scale, each scaled to the spread fbm2's two had, as on the plain sea.
	float gusts = mix(0.45, 1.45, smoothstep(0.3, 0.7, 0.5 + 0.745
		* (gradient_noise_wrapped(OCTAVE_TURN_1 * ((p - w * TIME * 0.8) * 0.0033), LATTICE_PERIOD) * 0.7
		+ gradient_noise_wrapped(OCTAVE_TURN_2 * ((p - w * TIME * 0.8) * 0.0143), LATTICE_PERIOD) * 0.3)));

	// No 14 m bend, as on the plain sea: the churn alone bends the sines.
	vec2 wind_slope;
	float unresolved;
	float curvature;
	paint_wind_sea(p, footprint, churn, gusts, TIME, w, wind_slope, unresolved, curvature);
	slope += wind_slope;

	// The painted waves, tilted onto the shape's own surface, worked out per pixel.
	vec3 normal = normalize(shape_normal(rest_xz, eye) + vec3(-slope.x, 0.0, -slope.y));

	vec3 normal_dx = dFdx(normal);
	vec3 normal_dy = dFdy(normal);
	float pixel_variance = 0.25 * (dot(normal_dx, normal_dx) + dot(normal_dy, normal_dy));
	float alpha_squared = unresolved + min(2.0 * pixel_variance, 0.18);

	float lifted = clamp(crest / 0.35, 0.0, 1.0);

	// STREAKS ALONG THE WIND, faint and short. They were 170 m long, eleven wide and drawn at
	// almost half foam, and the first render check (2026-09-12, coast view) showed them as long
	// straight bright stripes fanning towards the camera -- an artifact, not a sea. Now a few tens
	// of metres long, softened, and a sixth of foam at most. Halved again on the darker sea (2026-09-15, after2, glitter_60),
	// where a sixth read as white smears across the water, and narrower and fainter again (after5, sea_200), where at 17 m
	// wide and 0.08 they still lay on the sea as pale smudges from 200 m: 7 m wide and 0.05.
	vec2 wind_frame = vec2(dot(p, w), dot(p, vec2(-w.y, w.x)));
	// WRAPPED LATTICE, NOT TURNED: the streaks lie along the wind on purpose, so only the hash index is bounded -- at 11 km
	// out the long axis reads lattice cell 660, well past where value noise draws straight seams (terrain_noise.gdshaderinc).
	float streak = fbm2_wrapped(wind_frame * vec2(0.02, 0.14) - vec2(t * 0.8, 0.0), LATTICE_PERIOD);
	// AS MUCH AS THE WEATHER SAYS. Foam blown into streaks along the wind is Beaufort 7's sea ("foam begins to be blown in
	// streaks", Met Office), past about 13 m/s; the ships' weather is 5 to 12. So they grow in with the whitecap cover
	// `WindSea` hands, from 1.5 % (11.6 m/s) to 3 % (13.9), and at the ships' middle wind, 0.57 %, are not drawn: drawn
	// there at 0.05 they were scratches on the sea from 200 m and a pale band past the helm (after7, sea_200 and close_8).
	float streaks = smoothstep(0.62, 0.90, streak) * 0.05 * smoothstep(0.015, 0.03, whitecap_cover);

	// The breakup noise only on a crest past the threshold, as on the plain sea.
	float breakup = 0.0;
	if (curvature > whitecap_curvature) {
		breakup = fbm2_turned((p - w * TIME * 0.3) * 0.29, LATTICE_PERIOD);
	}
	float caps = whitecaps(curvature, breakup, footprint);
	caps += streaks * churn * (1.0 - caps) * detail;

	vec3 albedo = mix(deep_colour, foam_colour, caps);
	float thin = max(smoothstep(0.0, max(whitecap_curvature, 0.0001), curvature), lifted) * (1.0 - caps);
	// THE SHORE, ON INLAND WATER ONLY: the shallows pale and a wet line along the waterline, from the depth
	// `LakeSheets` baked into CUSTOM0. The sea carries no such attribute, which is
	// why this asks `inland` first (shore_water.gdshaderinc).
	if (inland > 0.5) {
		albedo = shore_water(albedo, foam_colour, water_depth);
	}
	ALBEDO = albedo;
	BACKLIGHT = crest_colour * thin / max(albedo, vec3(0.002));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
	float rough = mix(roughness_of(alpha_squared), 0.6, caps);
	ROUGHNESS = (inland > 0.5) ? shore_roughness(rough, water_depth) : rough;
	METALLIC = 0.0;
	SPECULAR = mix(0.25, 0.1, caps);
	// A FLARE OR A LAMP OVER THE SEA, reflected through this normal and roughness (sea_glint.gdshaderinc); foam does not
	// mirror it.
	EMISSION = sea_glints(world_pos, eye, normal, alpha_squared) * (1.0 - caps);
}
