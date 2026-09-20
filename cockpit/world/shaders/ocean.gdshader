// THE OCEAN ON THE PLAIN FINISH: the simulation's swell for its shape, and a wind-sea painted on it.
//
// SHAPE. The sea wears SeaSwell's eye-following sheet (`SeaSwell.carry`) since 2026-09-15, and near the eye its vertices
// move by the simulation's standing swell, so a hull heaving on that swell is not heaving through a flat plane. That is the
// only height this shader draws, and `tests/ocean_height_shot.gd` holds it to `swell_height_at` by rendering this file's
// own `vertex()`. See `vertex()`.
//
// SURFACE. Everything else is a normal, a roughness and a colour (`ocean_detail.gdshaderinc`, handed its waves by
// `WindSea`): four waves from 38 m to 8.8 m on the swell's own painted slope, bent by the churn, and five octaves of noise
// ripples under them down to a tenth of a metre, roughened in gusts, band-limited by the pixel so they never sparkle, with the slope they cannot draw handed on as
// roughness -- so the far sea is dark and the sun draws a glitter path on it. Until 2026-09-15 it was two typed chop wavelets and a whitecap on any steep face; the
// pictures before (godotgames-drafts/2026-09-15/cockpit-ocean/before) showed a glassy lake near the eye, corduroy to the
// horizon, the sun as one blob and white smears from a kilometre up. Asked for: "ocean's are often much more tumultous
// and have more varied waves, it's usually darker and has more ripples".
//
// DARK BY FRESNEL, NOT BY A DARKER COLOUR. The deep colour was already about 0.001-0.009 linear; the sea read light because
// it was mixed toward a shallow colour by view angle and reflected like F0 0.045. Water's F0 is 0.02 (`SPECULAR` 0.25).
//
// Opaque: no transparency, no refraction, no screen or depth texture, the expensive things in a water shader. No FRAGCOORD,
// so both eyes see one sea; TIME only moves the waves.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;
#include "res://world/shaders/eye.gdshaderinc"

#include "res://world/shaders/terrain_noise.gdshaderinc"
#define WAVES_PAINTED 4
#include "res://world/shaders/ocean_detail.gdshaderinc"
#include "res://world/shaders/sea_glint.gdshaderinc"
#include "res://world/shaders/still_water.gdshaderinc"
#include "res://world/shaders/shore_water.gdshaderinc"

uniform vec3 deep_colour : source_color = vec3(0.016, 0.055, 0.094);
// The green-blue of light through a thin crest, lit from behind by the sun or the moon (BACKLIGHT).
// Half what it was first (after5, dusk_20): at 0.04, 0.16, 0.15 the crests facing a low sun read as green blotches.
uniform vec3 crest_colour : source_color = vec3(0.028, 0.113, 0.106);
uniform vec3 foam_colour : source_color = vec3(0.82, 0.88, 0.90);
// How fast the painted swell's highlight drifts. The wind-sea's waves move at their own speeds (`WindSea`).
uniform float wave_speed = 0.55;
// THE STANDING SWELL THE SIMULATION FLOATS EVERY HULL ON (`swell_height` in cockpit_world.cpp), handed in by
// `SeaSwell.hand_the_swell` from `Sim.swell_shape`: zero heights until then, which is a flat sheet. The same shape, wrap
// and fade as ocean_fine.gdshader, and the painted swell below takes the same waves. Faded out between `standing_near`
// and `standing_gone` from the eye, where the sheet's cells grow too coarse to carry a 150 m wave.
uniform float standing_height = 0.0;
uniform float standing_second_height = 0.0;
uniform vec2 standing_first = vec2(0.0);
uniform vec2 standing_second = vec2(0.0);
uniform float standing_tile = 2048.0;
uniform float standing_near = 350.0;
uniform float standing_gone = 600.0;
// AND THE WIND-SEA THE BOATS FEEL (`swell_height`'s `kWindWaves`, C1): each wave's vector in xy and its height in z, handed
// by `SeaSwell.hand_the_swell`; zero heights until then. 26 to 64 m long, so drawn only where SeaSwell's cells hold them:
// the cells are 3 m to 150 m from the eye and wider past it, and at 170 m a 26 m wave has about four vertices.
uniform vec3 standing_wind[3];
uniform float standing_wind_near = 110.0;
uniform float standing_wind_gone = 170.0;

varying vec3 world_pos;
// HOW DEEP THE WATER IS HERE, metres, off the mesh's own CUSTOM0 (`LakeSheets`). Only inland water carries it; the sea
// has no such attribute, which is why every read of it is behind `inland` (shore_water.gdshaderinc).
varying float water_depth;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float range = length(wp.xz - EYE_POSITION_WORLD.xz);
	float coast = sea_motion(wp.xz);
	float held = (1.0 - smoothstep(standing_near, standing_gone, range)) * coast;
	if (held > 0.0001 && (standing_height > 0.0 || standing_second_height > 0.0)) {
		vec2 p = wp.xz - standing_tile * floor(wp.xz / standing_tile);
		VERTEX.y += (sin(dot(p, standing_first)) * standing_height
			+ sin(dot(p, standing_second)) * standing_second_height) * held;
	}
	float windy = (1.0 - smoothstep(standing_wind_near, standing_wind_gone, range)) * coast;
	if (windy > 0.0001) {
		vec2 q = wp.xz - standing_tile * floor(wp.xz / standing_tile);
		for (int i = 0; i < 3; i++) {
			VERTEX.y += sin(dot(q, standing_wind[i].xy)) * standing_wind[i].z * windy;
		}
	}
	water_depth = CUSTOM0.x;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The same wavelet with its direction and wavenumber as one vector, which is how the simulation hands its swell over.
vec2 wavelet_k(vec2 p, vec2 k, float amp, float t) {
	return k * cos(dot(p, k) + t) * amp;
}

void fragment() {
	float dist = length(world_pos - EYE_POSITION_WORLD);
	float swell = detail_fade(dist, 900.0, 7000.0);

	vec2 p = tile(world_pos.xz, 2048.0);
	// Everything but the painted swell reads the unwrapped position: the wind-sea wraps itself at its own tile, where every
	// wave is whole, and the noise goes through the bounded lattice (terrain_noise.gdshaderinc).
	vec2 unwrapped = world_pos.xz;
	float t = TIME * wave_speed;

	// Swell: the simulation's two waves, whole across its tile, travelling as a highlight over a shape that stands.
	vec2 slope = wavelet_k(p, standing_first, standing_height, t * 0.9);
	slope += wavelet_k(p, standing_second, standing_second_height, t * 1.15);
	slope *= swell;

	// METRES A PIXEL on the water, for band-limiting each wave to what the pixel can hold: the geometric mean of the pixel's
	// two sides. At a helm's grazing angle a pixel is several times longer along the view than across it, and its long side
	// (`length(fwidth())`, until 2026-09-15) faded ripples the eye still sees across the view, leaving brush strokes on the
	// water beside a launch (drafts cockpit-ocean/ships-lane, boat-plain-helm). What the long side cannot hold goes to the
	// roughness through the normal's own change across the pixel, below.
	float footprint = max(sqrt(length(dFdx(world_pos.xz)) * length(dFdy(world_pos.xz))), 0.0001);
	// THE CHURN, which bends the wind-sea's crests. Turned gradient noise on a bounded lattice: value noise far out drew
	// straight seams (cockpit-pirate, 2026-09-15).
	float churn = fbm2_turned(unwrapped * 0.012 + vec2(t * 0.05, -t * 0.03), LATTICE_PERIOD);
	// CAT'S PAWS: gusts roughen patches of the sea, read off the churn already worked out, so they cost no lookup of their
	// own. A 300 m gust noise of its own was 0.04 ms of a headset's two eyes at the helm view (cockpit-ocean, 2026-09-15),
	// where the budget for the whole painted sea was 0.3.
	vec2 downwind = wind_sea_k[0] / max(length(wind_sea_k[0]), 0.000001);
	float gusts = mix(0.45, 1.45, smoothstep(0.3, 0.7, churn));

	// NO 14 M BEND. It broke the ten sines' lattice from 60 m (after2, glitter_60); with four sines at half their slope and
	// noise octaves of their own lengths under them, the churn alone bends them.
	vec2 wind_slope;
	float unresolved;
	float curvature;
	paint_wind_sea(unwrapped, footprint, churn, gusts, TIME, downwind, wind_slope, unresolved, curvature);
	slope += wind_slope;

	vec3 normal = normalize(vec3(-slope.x, 1.0, -slope.y));

	// GEOMETRIC SPECULAR ANTIALIASING (Tokuyoshi and Kaplanyan 2019): what the normal still changes across a pixel widens
	// the highlight, so what the footprint fade leaves cannot sparkle either.
	vec3 normal_dx = dFdx(normal);
	vec3 normal_dy = dFdy(normal);
	float pixel_variance = 0.25 * (dot(normal_dx, normal_dx) + dot(normal_dy, normal_dy));
	float alpha_squared = unresolved + min(2.0 * pixel_variance, 0.18);

	// WHITECAPS on crests sharp enough to break, as much as the wind says, broken up; spread as a share of foam where no
	// crest can be resolved.
	// THE BREAKUP NOISE ONLY ON A CREST PAST THE THRESHOLD: below it `whitecaps` multiplies the noise by nothing, and under
	// 2 % of the sea passes it in the ships' weather (Monahan), so nearly every pixel skips the lookup.
	float breakup = 0.0;
	if (curvature > whitecap_curvature) {
		breakup = fbm2_turned((unwrapped - downwind * TIME * 0.3) * 0.29, LATTICE_PERIOD);
	}
	float caps = whitecaps(curvature, breakup, footprint);

	vec3 albedo = mix(deep_colour, foam_colour, caps);
	// LIGHT THROUGH THE CRESTS. Godot multiplies BACKLIGHT by the albedo after the lights, and this albedo is nearly black,
	// so it is handed the colour wanted divided by the albedo.
	float thin = smoothstep(0.0, max(whitecap_curvature, 0.0001), curvature) * (1.0 - caps);
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
	EMISSION = sea_glints(world_pos, EYE_POSITION_WORLD, normal, alpha_squared) * (1.0 - caps);
}
