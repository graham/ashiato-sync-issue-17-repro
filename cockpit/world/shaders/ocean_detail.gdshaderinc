// THE WIND-SEA, PAINTED: the short waves that make a sea look rough, dark and never the same twice, for both ocean shaders.
//
// A NORMAL AND A COLOUR, NEVER A HEIGHT. Nothing here is read by `vertex()`. The simulation floats every hull on its own
// standing swell, and a wave drawn over a deck that the simulation keeps dry reads as a swamped boat (FINE's chop at 0.4,
// 0.93 m over a launch with 0.4 m of freeboard, 2026-09-15). So the roughness asked for ("more tumultuous, darker, more
// ripples", 2026-09-15) is all slope, roughness and foam.
//
// WHY A SPECTRUM. The sea used to paint two chop wavelets of fixed direction over the simulation's two swell waves: a
// glassy lake near the eye, corduroy to the horizon, and the sun as one smooth blob. A real sea's surface slope, measured
// from sun glitter by Cox and Munk, has a variance of 0.003 + 0.00512 U -- 0.044 at 8 m/s -- and the swell carries 0.0002
// of it. `WindSea` builds up to ten waves, 38 m down to half a metre, spread about the swell's heading, each carrying an
// equal share of that variance, moving at the speed deep water gives its length. This file only sums what it is handed:
// no amplitude, direction or speed is typed here.
//
// WHOLE WAVES IN THE TILE. Every wave vector is a whole number of waves across `wind_sea_tile`, so the position is wrapped
// there with no seam and the phase stays under ten thousand radians anywhere in the world. A wave that is not whole steps
// wherever the wrap flips: the swell did exactly that twice (agents.md, "A wrap is seamless only if the swell is periodic in
// it").
//
// BAND-LIMITED BY THE PIXEL, NOT BY DISTANCE. Each wave fades out as it narrows from four pixels to two, measured by the
// pixel's own footprint on the water, and the slope variance it no longer draws is handed on as roughness (Bruneton, Neyret
// and Holzschuch 2010; Toksvig; LEAN). Detail smaller than a pixel sparkles in a headset; faded by distance alone it left
// the old sea's corduroy at the horizon and white smears from a kilometre up. Faded by footprint, the far sea keeps the
// wind's roughness and the sun draws a glitter path on it.
//
// THE RIPPLES ARE NOT MORE SINES. What is shorter than the shortest sine a finish paints was first drawn as octaves of
// turned gradient noise worked out per pixel, and is now two normal maps made of that noise (see the ripple maps below, and
// agents.md, "WHAT THE PAINTED SEA MAY COST": the octaves cost three and a half times the budget at the helm view).
// Painted as sines, the half-metre waves drew a honeycomb in FINE's glitter and PLAIN's shortest sine, 1.25 m, left the water
// at a helm soft and glassy (godotgames-drafts/2026-09-15/cockpit-ocean/after4, close_8). A few sines always interfere into a
// lattice, and it shows wherever they are the shortest thing a pixel still draws: with three noise octaves under six sines
// the glitter from 200 m kept its crosshatch (after5, sea_200), the 3-9 m sines sitting at their fade, and with the sines
// stopped at 8.8 m it was still there (after6). With no sines at all it was gone, and the far sea went glassy: the glitter
// from 60 m a soft blob (diag-nosines). So the sines keep only half their slope (`SINE_KEEP`) and hand the other half to
// noise octaves of their own lengths, 12 m and 5 m, and they fade at sixteen pixels a wavelength where the noise fades at
// eight: wherever a sine is the finest thing a pixel draws, noise as long as it is drawn over it. The octaves carry exactly the slope the sines leave -- the spectrum's unpainted waves and a share of
// what `WindSea` hands as unpainted -- so the sea's slope is still Cox and Munk's, drawn or turned into roughness.
//
// WAVES_PAINTED must be defined before this is included: 4 on both, 38 m to 8.8 m. A constant loop bound, not a uniform,
// so each finish compiles its own loop. Every wave long enough to break (`whitecap_longer_than`) is painted on both, so
// the whitecap threshold `WindSea` solves for those waves is the one each finish draws.

#ifndef OCEAN_DETAIL_GDSHADERINC
#define OCEAN_DETAIL_GDSHADERINC

// Each wave's vector (direction times wavenumber, radians a metre), height, and angular speed. Handed by `WindSea.hand`;
// until then every height is zero, which paints no wind-sea at all.
uniform vec2 wind_sea_k[10];
uniform float wind_sea_height[10];
uniform float wind_sea_speed[10];
uniform float wind_sea_tile = 512.0;
// The roughness, as GGX alpha squared, of everything shorter than the shortest wave painted: the ripples no finish draws.
uniform float wind_sea_unpainted = 0.0;
// How far the churn bends each crest, in radians of phase across the churn's range. 1.6 was too little: the first pictures
// after (2026-09-15, after1, glitter_60 and dusk_20) showed the ten waves' interference as a woven crosshatch.
uniform float wind_sea_bend = 5.0;
// EACH WAVE BENDS BY ITS OWN SHARE, alternating in sign and size, so neighbouring waves do not bend together and their
// interference cannot settle into a lattice.
const float BEND_SHARE[10] = {1.0, -1.3, 0.8, -0.6, 1.2, -1.0, 0.7, -1.4, 0.9, -0.8};
// A wave is drawn whole down to FADE_FROM pixels a wavelength and gone at FADE_GONE. Four to two pixels drew the waves
// crisply right to the edge of what a pixel holds, which is where their few-wave lattice showed most; eight to four hands
// them to the roughness sooner, and in a headset shimmers less.
// WAVES COME IN GROUPS. Each wave's height is scaled by its own signed share of the bend as well, by up to GROUPS either
// way, so where one wave runs high its neighbour runs low: with every wave the same height everywhere, the 10-40 m waves'
// interference still drew a regular herringbone across the glitter from 200 m (after3, sea_200).
const float GROUPS = 1.2;
const float FADE_FROM = 0.125;
const float FADE_GONE = 0.25;
// THE SINES FADE TWICE AS SOON, sixteen to eight pixels a wavelength, and keep this share of their slope variance; the rest
// is drawn by the noise octaves. See the ripples above.
const float SINE_FADE_FROM = 0.0625;
const float SINE_FADE_GONE = 0.125;
const float SINE_KEEP = 0.5;
// Waves shorter than this, in metres, are the ones gusts roughen (the cat's paws).
uniform float wind_sea_gusty_below = 4.0;
// WHITECAPS: waves longer than this break; a crest whose painted curvature (minus the Laplacian of the height) is past
// `whitecap_curvature` is foam, and `whitecap_cover` is the share of sea foam covers where no crest can be resolved.
uniform float whitecap_longer_than = 3.0;
uniform float whitecap_curvature = 1.0e9;
uniform float whitecap_cover = 0.0;

// THE RIPPLE MAPS: TWO NORMAL MAPS MADE OF NOISE, THE EXCEPTION TO "NO TEXTURES ANYWHERE" (team-lead, 2026-09-15). Seven
// octaves of turned gradient noise worked out per pixel cost a headset's two eyes +0.56 to +0.60 ms on the open sea and
// +1.09 ms at the helm view from a height, against +0.3 (agents.md, "WHAT THE PAINTED SEA MAY COST"). A mipmapped texture
// fetch is a handful of arithmetic, and its mipmaps band-limit it for nothing. Both maps are made by `WindSea.ripple_maps`
// when a sea is first built: seamless fractal noise, turned into a normal map, mipmapped. Nothing is imported. The long map
// tiles every `ripple_map_tile.x`, its octaves from an eighth of that down; the short one every `.y`, down to 3 cm for a
// helm's near water (a launch's water 2 to 6 m off was smooth strokes until the ripples reached that far: drafts
// cockpit-ocean/crops, helm_down-right-x4 against -G), and it is read again at `.z`, turned and drifting on its own, so no
// single sheet slides and no tile repeats alone.
uniform sampler2D ripple_map_long : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ripple_map_short : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// The tiles in metres (long, short, short read again), each map's decoded slope variance (`WindSea.decoded_slope_variance`),
// each map's octaves, and each read's drift down the wind in metres a second: all handed by `WindSea.hand` from the maps it
// built. Until then every variance is zero, which draws no ripples and hands their slope to the roughness.
uniform vec3 ripple_map_tile = vec3(51.7, 7.3, 10.0);
uniform vec2 ripple_map_variance = vec2(0.0);
uniform vec2 ripple_map_octaves = vec2(4.0, 6.0);
uniform vec3 ripple_map_drift = vec3(0.0);
// A map's longest octave is an eighth of its tile and each next one half the one before (`WindSea`: eight cells a tile,
// lacunarity 2, gain 0.5, so every octave carries the same slope).
const float RIPPLE_MAP_FIRST_CELL = 0.125;
// THE MAPS ARE READ FOUR TIMES COARSER THAN THE PIXEL ASKS (a mip bias of 2), so each octave is gone as its cell narrows from
// eight pixels to four, as the noise's was, and its slope handed to the roughness over the same band. Read at the pixel's
// own mip, an octave was drawn down to a pixel or two a cell: the dusk glitter at a headset's pixel popped on 0.280 % of
// PLAIN's pixels a frame and 0.908 % of FINE's, where the noise had popped on 0.009 % and 0.022 % (drafts cockpit-ocean,
// flicker-A8-90 against flicker-H2-90). A mipmap averages a crisp normal over a few texels; it does not stop it sparkling.
const float RIPPLE_MAP_LOD_BIAS = 2.0;
const float RIPPLE_MAP_FADE_FROM = 0.125;
const float RIPPLE_MAP_FADE_GONE = 0.25;
// Each read's crests are squeezed this much across the wind, as wind ripples lie. 1.6 added to the foreshortening at a helm's
// grazing angle and drew the near ripples as strokes.
const float RIPPLE_ACROSS = 1.25;
// The share of `wind_sea_unpainted` the ripples draw where a pixel holds them; the rest is always roughness.
const float RIPPLE_SHARE = 0.7;
// Each read's turn, 0.62, 1.73 and 2.91 radians, so no read's tile lines up with another's or with x and z.
const mat2 RIPPLE_TURN[3] = {mat2(vec2(0.8139, 0.5810), vec2(-0.5810, 0.8139)),
	mat2(vec2(-0.1585, 0.9874), vec2(-0.9874, -0.1585)), mat2(vec2(-0.9731, 0.2306), vec2(-0.2306, -0.9731))};

// THE SLOPE A RIPPLE MAP GIVES AT A POINT OF THE WORLD, in the map's decoded units. `Image.bump_map_to_normal_map` writes red
// as minus the height's rise along the image's x and green as its rise down its rows (a rising ramp in each, read back on
// this editor: drafts cockpit-ocean, bump_probe.gd), so the slope is (-red, green) over blue. Placed through the wind's
// frame, the squeeze and the turn, and handed back through all three.
vec2 ripple_map_slope(sampler2D map, vec2 world_xz, vec2 downwind, vec2 across, float tile, mat2 turn, float drift,
		float t) {
	vec2 drifted = world_xz - downwind * (drift * t);
	vec2 frame = vec2(dot(drifted, downwind), dot(drifted, across) / RIPPLE_ACROSS);
	vec3 n = texture(map, (turn * frame) / tile, RIPPLE_MAP_LOD_BIAS).rgb * 2.0 - 1.0;
	vec2 in_frame = transpose(turn) * (vec2(-n.x, n.y) / max(n.z, 0.2));
	return downwind * in_frame.x + across * (in_frame.y / RIPPLE_ACROSS);
}

// THE SHARE OF A MAP'S SLOPE A PIXEL CANNOT HOLD: how many of its octaves have narrowed past the pixel, each an equal share.
float ripple_map_lost(float footprint, float tile, float octaves) {
	float lost = 0.0;
	float cell = tile * RIPPLE_MAP_FIRST_CELL;
	for (int i = 0; i < 8; i++) {
		if (float(i) >= octaves) {
			break;
		}
		float fade = 1.0 - smoothstep(RIPPLE_MAP_FADE_FROM, RIPPLE_MAP_FADE_GONE, footprint / cell);
		lost += 1.0 - fade * fade;
		cell *= 0.5;
	}
	return lost / max(octaves, 1.0);
}

// THE WIND-SEA AT A POINT: its slope, the slope variance too fine for this pixel as GGX alpha squared (for the roughness,
// the unpainted floor included), and the curvature of the waves long enough to break (for the foam). `footprint` is metres
// a pixel, `fwidth` of the world position taken in fragment(); `churn` (0 to 1) bends the sines' crests -- a 14 m noise
// mixed into it broke their lattice where an 83 m one alone did not (after2, glitter_60); `gusts` scales the ripples'
// height and any sine under `wind_sea_gusty_below`; `downwind` is the unit direction the ripples drift and lie across.
void paint_wind_sea(vec2 world_xz, float footprint, float churn, float gusts, float t, vec2 downwind,
		out vec2 slope, out float unresolved, out float curvature) {
	vec2 p = world_xz - wind_sea_tile * floor(world_xz / wind_sea_tile);
	float bend = wind_sea_bend * (churn - 0.5);
	slope = vec2(0.0);
	unresolved = 0.0;
	curvature = 0.0;
	// The slope variance the sines hand to the noise octaves.
	float sines_given = 0.0;
	for (int i = 0; i < WAVES_PAINTED; i++) {
		float k = length(wind_sea_k[i]);
		if (k <= 0.0) {
			continue;
		}
		float wavelength = 6.2831853 / k;
		bool short_wave = wavelength < wind_sea_gusty_below;
		float height = wind_sea_height[i] * (short_wave ? gusts : 1.0)
			* max(1.0 + GROUPS * BEND_SHARE[i] * (churn - 0.5), 0.0);
		float fade = 1.0 - smoothstep(SINE_FADE_FROM, SINE_FADE_GONE, footprint / wavelength);
		// Half of (k a) squared is a sine's slope variance, both directions together.
		float variance = 0.5 * k * k * height * height;
		unresolved += (1.0 - fade * fade) * SINE_KEEP * variance;
		sines_given += (1.0 - SINE_KEEP) * variance;
		if (fade <= 0.0) {
			continue;
		}
		float phase = dot(p, wind_sea_k[i]) - wind_sea_speed[i] * t + bend * BEND_SHARE[i];
		slope += wind_sea_k[i] * (cos(phase) * height * sqrt(SINE_KEEP) * fade);
		// THE CURVATURE AT THE WAVE'S WHOLE HEIGHT: `WindSea` solved the whitecap threshold for the waves it handed.
		if (wavelength > whitecap_longer_than) {
			curvature += k * k * height * sin(phase) * fade;
		}
	}
	// THE RIPPLES' SLOPE VARIANCE: the spectrum's waves this finish does not paint as sines, and the ripple share of the
	// unpainted; what is left of the unpainted is roughness everywhere.
	float ripple_variance = RIPPLE_SHARE * wind_sea_unpainted * gusts * gusts + sines_given;
	for (int i = WAVES_PAINTED; i < 10; i++) {
		float k = length(wind_sea_k[i]);
		float height = wind_sea_height[i] * gusts;
		ripple_variance += 0.5 * k * k * height * height;
	}
	unresolved += (1.0 - RIPPLE_SHARE) * wind_sea_unpainted;
	float octaves = ripple_map_octaves.x + ripple_map_octaves.y;
	if (ripple_variance <= 0.0) {
		return;
	}
	if (octaves <= 0.0 || ripple_map_variance.x <= 0.0 || ripple_map_variance.y <= 0.0) {
		unresolved += ripple_variance;
		return;
	}
	// Each map carries the ripples' slope in proportion to its octaves, the short map's split between its two reads. A map's
	// decoded slope variance reaches the world halved per axis through the squeeze.
	float squeeze = 0.5 * (1.0 + 1.0 / (RIPPLE_ACROSS * RIPPLE_ACROSS));
	float long_share = ripple_variance * ripple_map_octaves.x / octaves;
	float short_share = 0.5 * ripple_variance * ripple_map_octaves.y / octaves;
	vec2 across = vec2(-downwind.y, downwind.x);
	float long_lost = ripple_map_lost(footprint, ripple_map_tile.x, ripple_map_octaves.x);
	float short_lost = ripple_map_lost(footprint, ripple_map_tile.y, ripple_map_octaves.y);
	float again_lost = ripple_map_lost(footprint, ripple_map_tile.z, ripple_map_octaves.y);
	unresolved += long_share * long_lost + short_share * (short_lost + again_lost);
	// A read whose every octave has narrowed past the pixel is not fetched at all.
	if (long_lost < 1.0) {
		slope += ripple_map_slope(ripple_map_long, world_xz, downwind, across, ripple_map_tile.x, RIPPLE_TURN[0],
			ripple_map_drift.x, t) * sqrt(long_share / (squeeze * ripple_map_variance.x));
	}
	float short_scale = sqrt(short_share / (squeeze * ripple_map_variance.y));
	if (short_lost < 1.0) {
		slope += ripple_map_slope(ripple_map_short, world_xz, downwind, across, ripple_map_tile.y, RIPPLE_TURN[1],
			ripple_map_drift.y, t) * short_scale;
	}
	if (again_lost < 1.0) {
		slope += ripple_map_slope(ripple_map_short, world_xz, downwind, across, ripple_map_tile.z, RIPPLE_TURN[2],
			ripple_map_drift.z, t) * short_scale;
	}
}

// GGX ALPHA SQUARED TO GODOT'S ROUGHNESS, which is perceptual: alpha is roughness squared.
float roughness_of(float alpha_squared) {
	return sqrt(sqrt(clamp(alpha_squared, 0.0, 1.0)));
}

// WHITECAPS FROM THE CURVATURE, broken up by `breakup` (0 to 1), and faded as the breaking waves narrow below a few pixels,
// past which the foam is spread across the pixel as `whitecap_cover` instead of drawn as smears.
float whitecaps(float curvature, float breakup, float footprint) {
	float resolved = 1.0 - smoothstep(FADE_FROM, FADE_GONE, footprint / whitecap_longer_than);
	float crest = smoothstep(whitecap_curvature, whitecap_curvature * 1.8, curvature) * smoothstep(0.35, 0.75, breakup);
	return crest * resolved + whitecap_cover * (1.0 - resolved);
}

#endif
