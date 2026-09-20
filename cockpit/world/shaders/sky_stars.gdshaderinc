// THE STARS, IN BOTH SKIES (2026-09-15): a field of points at infinity, a function of the view direction alone. Asked for with
// the moon: "have a shader that allows their to be stars".
//
// WHERE: one candidate star in every cell of a cube wrapped round the sky, `star_cells` cells along a face's edge, each face's
// square coordinates bent by atan so a cell spans nearly the same angle at a face's corner as at its middle -- no pole to
// pinch, as a latitude-longitude grid would. A cell has a star when its hash is under `star_share`; where in the cell, how
// bright and what colour are three more hashes. Direction only: the stars are at infinity, the same in both eyes, and
// nothing to either editor's idea of where the eye is.
//
// HOW BRIGHT: pow(hash, star_power), so many are faint and few are bright, as the sky has them. The colour runs from
// blue-white to orange by a fifth hash squared, so most are near white.
//
// NEVER SMALLER THAN A PIXEL, AND NO BRIGHTER FOR BEING DRAWN SMALL. A real star is far smaller than a pixel, and a
// point drawn smaller than one flickers on and off and swims between the eyes as the head moves. So a star is a gaussian
// `star_pixels` of this eye's pixels in sigma -- wider in radians on a coarse screen, narrower on a fine one -- and its peak
// is scaled by (reference pixel / pixel)^2, so the light it gives, peak times area, is the same at every resolution:
// `star_bright` is the brightest star's peak at a pixel of a twentieth of a degree. A gaussian about a pixel wide, sampled at
// pixel centres, keeps its sum as it moves across the grid. No TIME, so no twinkle of its own either, and no redrawn cubemap.
//
// A STAR STAYS IN ITS CELL: its centre is kept `star_margin` of a cell from the edges, and a star whose three sigmas would
// cross an edge -- a coarse screen -- fades rather than being cut into a half-disc, because only the cell the pixel is in
// is asked.
//
// DIMMED BY: `stars`, the time of day's (0 with the sun up, 1 in full dark: `NightSkyTuning.stars_seen`); the haze low down
// (`star_horizon` of the view's height); the moon -- near it by `star_moon_near` radians, and across the sky the faintest
// washed out by `star_moon_wash`, both by how much of the moon is lit -- and, from the caller, the moon's disc in front of
// them. The cirrus, the clouds, the fog and the mist cover them after, as they cover the sky. Not in the cubemap pass.
#ifndef SKY_STARS_GDSHADERINC
#define SKY_STARS_GDSHADERINC

uniform float stars = 0.0;
uniform float star_cells = 96.0;
uniform float star_share = 0.14;
uniform float star_power = 6.0;
uniform float star_bright = 1.5;
uniform float star_pixels = 0.9;
uniform float star_margin = 0.25;
uniform float star_horizon = 0.3;
uniform float star_moon_near = 0.14;
uniform float star_moon_wash = 0.25;
uniform vec3 star_blue : source_color = vec3(0.78, 0.86, 1.0);
uniform vec3 star_orange : source_color = vec3(1.0, 0.78, 0.55);

float star_hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

// The light of the stars along `dir`, a pixel `pixel` radians across, with the moon along `moon` and `moon_lit` of it lit
// (0 when there is no moon).
vec3 stars_seen(vec3 dir, float pixel, vec3 moon, float moon_lit) {
	if (stars <= 0.0 || dir.y <= 0.0) {
		return vec3(0.0);
	}
	// THE CUBE FACE, and the two axes across it.
	vec3 a = abs(dir);
	vec3 axis;
	vec3 u_axis;
	vec3 v_axis;
	float face;
	if (a.x >= a.y && a.x >= a.z) {
		axis = vec3(sign(dir.x), 0.0, 0.0);
		u_axis = vec3(0.0, 0.0, 1.0);
		v_axis = vec3(0.0, 1.0, 0.0);
		face = dir.x > 0.0 ? 0.0 : 1.0;
	} else if (a.y >= a.z) {
		axis = vec3(0.0, sign(dir.y), 0.0);
		u_axis = vec3(1.0, 0.0, 0.0);
		v_axis = vec3(0.0, 0.0, 1.0);
		face = dir.y > 0.0 ? 2.0 : 3.0;
	} else {
		axis = vec3(0.0, 0.0, sign(dir.z));
		u_axis = vec3(1.0, 0.0, 0.0);
		v_axis = vec3(0.0, 1.0, 0.0);
		face = dir.z > 0.0 ? 4.0 : 5.0;
	}
	float major = dot(dir, axis);
	vec2 square = vec2(dot(dir, u_axis), dot(dir, v_axis)) / major;
	vec2 even = atan(square) * (4.0 / PI);
	vec2 cell = floor((even * 0.5 + 0.5) * star_cells);
	vec3 seed = vec3(cell, face * 7.0 + 1.0);
	if (star_hash(seed) >= star_share) {
		return vec3(0.0);
	}
	// WHERE IN THE CELL, turned back into a direction the same way.
	vec2 inside = mix(vec2(star_margin), vec2(1.0 - star_margin),
		vec2(star_hash(seed + vec3(0.0, 0.0, 11.0)), star_hash(seed + vec3(0.0, 0.0, 23.0))));
	vec2 star_square = tan(((cell + inside) / star_cells * 2.0 - 1.0) * (PI / 4.0));
	vec3 star = normalize(axis + u_axis * star_square.x + v_axis * star_square.y);
	float sigma = pixel * star_pixels;
	float apart = length(dir - star);
	if (apart > 3.0 * sigma) {
		return vec3(0.0);
	}
	float cell_angle = (PI / 2.0) / star_cells;
	float fits = 1.0 - smoothstep(0.8, 1.0, 3.0 * sigma / (star_margin * cell_angle));
	float flux = pow(star_hash(seed + vec3(0.0, 0.0, 37.0)), star_power);
	float wash = star_moon_wash * moon_lit;
	flux = max(flux - wash, 0.0) / (1.0 - wash);
	float near_moon = 1.0 - moon_lit * exp(-acos(clamp(dot(dir, moon), -1.0, 1.0)) / star_moon_near);
	float haze = smoothstep(0.0, star_horizon, dir.y);
	float reference = radians(1.0 / 20.0);
	float peak = star_bright * flux * (reference / pixel) * (reference / pixel) * exp(-0.5 * apart * apart / (sigma * sigma));
	float warm = star_hash(seed + vec3(0.0, 0.0, 53.0));
	return mix(star_blue, star_orange, warm * warm) * peak * stars * fits * haze * near_moon;
}

#endif
