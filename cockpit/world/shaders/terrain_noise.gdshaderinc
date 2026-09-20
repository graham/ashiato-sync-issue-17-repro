// Shared procedural noise for the world's surfaces.
//
// NO TEXTURES ANYWHERE, and that is a deliberate budget rather than a shortcut: a headset
// is fill-rate bound long before it is ALU bound, and every one of these surfaces covers a
// large part of the screen. A handful of multiply-adds per pixel is cheaper than a texture
// fetch, and it costs no memory and no bandwidth at all.
//
// PRECISION. The world is 14 km across and shader floats are 32-bit, so a coordinate of
// 7000 with a frequency of 5 is an argument of 35000 -- where a float has about a
// centimetre of resolution and fine detail turns into visible stair-stepping. Every
// high-frequency lookup here therefore wraps the world position first, with `tile()`. The
// repeat is invisible under the low-frequency variation on top of it.

vec2 tile(vec2 p, float period) {
	return p - period * floor(p / period);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Value noise. Smoothstep on the interpolant so the derivative is continuous and the
// result does not show the lattice.
float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Three octaves. Not five: the fourth and fifth are below a pixel at any distance you can
// actually see them from, so they cost fill rate and buy shimmer.
float fbm3(vec2 p) {
	float sum = value_noise(p) * 0.5;
	sum += value_noise(p * 2.03) * 0.25;
	sum += value_noise(p * 4.01) * 0.125;
	return sum / 0.875;
}

float fbm2(vec2 p) {
	return (value_noise(p) * 0.5 + value_noise(p * 2.03) * 0.25) / 0.75;
}

// THE LATTICE, WRAPPED, for a lookup whose cells run to a hundred and more. hash21 multiplies a lattice corner by 123.34
// and 456.21, and at large indices float32 keeps too few bits of the fraction: neighbouring corners stop being told apart,
// and the noise draws straight-edged seams along its lattice lines. They show on stock and double alike, measured
// 2026-09-14 (godotgames-drafts/2026-09-14/cockpit-double/p4d, p6, p7):
//   - rock's coarse shape from about 2 km out, where its third octave reaches cell 80;
//   - grass's clumps beside the runway, at cell 107.
// It is not a corner rounded two ways: one corner hashed from either side matched at every index from 5 to 600.
// So each INTEGER corner is wrapped symmetrically into [-period/2, period/2) before it is hashed. The same corner wraps
// the same way from every cell that touches it, so the wrap draws no seam, and within half a period of the origin nothing
// changes at all. Measured with period 128: the seams at 2.2, 8.1 and 32.1 km are gone, 128 m is unchanged, and every
// night picture of the scenery sweep is unchanged past 8/255.
vec2 wrap_cell(vec2 cell, float period) {
	return cell - period * floor((cell + period * 0.5) / period);
}

float value_noise_wrapped(vec2 p, float period) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(wrap_cell(cell, period));
	float b = hash21(wrap_cell(cell + vec2(1.0, 0.0), period));
	float c = hash21(wrap_cell(cell + vec2(0.0, 1.0), period));
	float d = hash21(wrap_cell(cell + vec2(1.0, 1.0), period));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm3_wrapped(vec2 p, float period) {
	float sum = value_noise_wrapped(p, period) * 0.5;
	sum += value_noise_wrapped(p * 2.03, period) * 0.25;
	sum += value_noise_wrapped(p * 4.01, period) * 0.125;
	return sum / 0.875;
}

float fbm2_wrapped(vec2 p, float period) {
	return (value_noise_wrapped(p, period) * 0.5 + value_noise_wrapped(p * 2.03, period) * 0.25) / 0.75;
}

// The lattice period the wrapped lookups use, in cells. See `wrap_cell`.
const float LATTICE_PERIOD = 128.0;

// GRADIENT NOISE, EACH OCTAVE TURNED, for the grass's patches and clumps. Value noise's smoothstep lattice creases along x
// and z, and the creases draw straight lines: from 300 m the 625 m patches made fans converging on the vanishing point, and
// from 40 m FINE's 28.6 m clumps made streaks and tiles. The terrain probe proved each by holding that noise still
// (`--patches=off`, `--clumps=off`: godotgames-drafts/2026-09-14/cockpit-terrain, report 8c). Gradient noise has no
// crease at its lattice lines, and each octave's coordinates are turned by a fixed angle of its own, so no octave's
// lattice lines up with x, z or another's. The corners go through `wrap_cell` as the value noise's do, so the index stays
// bounded far out.
//
// THE SAME SPREAD AS THE VALUE NOISE IT REPLACES, so the grass keeps its share of lush, dry and bare earth: measured over
// 60,000 island points at the shaders' own scales, the gradient fbm's spread is the value fbm's (0.140 against 0.141 for the
// patches, 0.160 against 0.160 for the clumps) about a mean of 0, so it is lifted by 0.5 and not scaled. Lush grass
// (`smoothstep(0.35, 0.75, patches)`) covers 38.1 % against 38.2 %, bare earth 4.3 % against 4.5 %.

// A unit gradient at a wrapped lattice corner, at the corner's hashed angle.
vec2 lattice_gradient(vec2 cell, float period) {
	float angle = hash21(wrap_cell(cell, period)) * 6.2831853;
	return vec2(cos(angle), sin(angle));
}

// Perlin's gradient noise with a quintic fade: about -0.7 to 0.7, centred on 0.
float gradient_noise_wrapped(vec2 p, float period) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(lattice_gradient(cell, period), f);
	float b = dot(lattice_gradient(cell + vec2(1.0, 0.0), period), f - vec2(1.0, 0.0));
	float c = dot(lattice_gradient(cell + vec2(0.0, 1.0), period), f - vec2(0.0, 1.0));
	float d = dot(lattice_gradient(cell + vec2(1.0, 1.0), period), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// The three octaves' turns: 0.62, 1.73 and 2.91 radians, as rotation matrices (a const cannot call cos).
const mat2 OCTAVE_TURN_1 = mat2(vec2(0.8139, 0.5810), vec2(-0.5810, 0.8139));
const mat2 OCTAVE_TURN_2 = mat2(vec2(-0.1585, 0.9874), vec2(-0.9874, -0.1585));
const mat2 OCTAVE_TURN_3 = mat2(vec2(-0.9731, 0.2306), vec2(-0.2306, -0.9731));

// Three octaves at fbm3's frequencies and weights, each turned, on 0 to 1 like fbm3.
float fbm3_turned(vec2 p, float period) {
	float sum = gradient_noise_wrapped(OCTAVE_TURN_1 * p, period) * 0.5;
	sum += gradient_noise_wrapped(OCTAVE_TURN_2 * (p * 2.03), period) * 0.25;
	sum += gradient_noise_wrapped(OCTAVE_TURN_3 * (p * 4.01), period) * 0.125;
	return 0.5 + sum / 0.875;
}

// Two octaves at fbm2's frequencies and weights, each turned, on 0 to 1 like fbm2.
float fbm2_turned(vec2 p, float period) {
	float sum = gradient_noise_wrapped(OCTAVE_TURN_1 * p, period) * 0.5;
	sum += gradient_noise_wrapped(OCTAVE_TURN_2 * (p * 2.03), period) * 0.25;
	return 0.5 + sum / 0.75;
}

// How much detail is worth drawing at this distance. Everything fine fades out with range,
// which is not a quality setting -- it is what stops a surface sparkling in a headset when
// its detail gets smaller than a pixel.
float detail_fade(float dist, float full, float gone) {
	return 1.0 - smoothstep(full, gone, dist);
}
