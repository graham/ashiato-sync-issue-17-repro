// Value noise WITH ITS DERIVATIVE, for the fine finish's surfaces that want to be lit as though
// they had relief. Needs terrain_noise.gdshaderinc included first, for `hash21`.
//
// The same four hashes as `value_noise`, and the slope falls out of the interpolation for
// nothing: a lit hummock without a second or third lookup to take a finite difference. That
// is the only reason relief is affordable on a surface that covers half of both eyes.
//
// Returns (value, d/dx, d/dy) in the noise's own units. Multiply the slope by the frequency the
// noise was sampled at, and by how many metres tall the bumps are meant to be.

vec3 value_noise_d(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	float k = a - b - c + d;
	return vec3(a + (b - a) * u.x + (c - a) * u.y + k * u.x * u.y,
		du * (vec2(b - a, c - a) + k * u.yx));
}

// The same, on the wrapped lattice (terrain_noise.gdshaderinc, `wrap_cell`), for a lookup whose cells run into the hundreds.
vec3 value_noise_d_wrapped(vec2 p, float period) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = hash21(wrap_cell(cell, period));
	float b = hash21(wrap_cell(cell + vec2(1.0, 0.0), period));
	float c = hash21(wrap_cell(cell + vec2(0.0, 1.0), period));
	float d = hash21(wrap_cell(cell + vec2(1.0, 1.0), period));
	float k = a - b - c + d;
	return vec3(a + (b - a) * u.x + (c - a) * u.y + k * u.x * u.y,
		du * (vec2(b - a, c - a) + k * u.yx));
}

// GRADIENT NOISE WITH ITS DERIVATIVE, for FINE's hummocks: the gradient noise of terrain_noise.gdshaderinc, whose lattice
// does not crease into the streaks value noise drew near the eye. Not turned, as the patches' and clumps' octaves are: the
// slope tilts the normal in world x and z, and one octave of gradient noise has no crease to hide.
//
// THE SAME VALUE AND SLOPE AS `value_noise_d_wrapped`, so the hummocks keep the height they were tuned at: over 60,000
// points at grass_fine's own scale, the value's spread is value noise's (0.214 against 0.217) about 0, so it is lifted by
// 0.5; its slope averages 0.81 against value noise's 0.47, so the slope is scaled by `GRADIENT_SLOPE_MATCH`. The analytic
// slope matched a finite difference to 1.4e-5.
const float GRADIENT_SLOPE_MATCH = 0.58;

vec3 gradient_noise_d_wrapped(vec2 p, float period) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
	vec2 ga = lattice_gradient(cell, period);
	vec2 gb = lattice_gradient(cell + vec2(1.0, 0.0), period);
	vec2 gc = lattice_gradient(cell + vec2(0.0, 1.0), period);
	vec2 gd = lattice_gradient(cell + vec2(1.0, 1.0), period);
	float va = dot(ga, f);
	float vb = dot(gb, f - vec2(1.0, 0.0));
	float vc = dot(gc, f - vec2(0.0, 1.0));
	float vd = dot(gd, f - vec2(1.0, 1.0));
	float k = va - vb - vc + vd;
	float value = va + (vb - va) * u.x + (vc - va) * u.y + k * u.x * u.y;
	vec2 blended = ga + (gb - ga) * u.x + (gc - ga) * u.y + (ga - gb - gc + gd) * u.x * u.y;
	vec2 slope = blended + du * (vec2(vb - va, vc - va) + k * u.yx);
	return vec3(0.5 + value, slope * GRADIENT_SLOPE_MATCH);
}

// THE GUSTS, in one place for the grass and the blades standing in it, so a bright band rolling
// across a field and the blades bending under it are the same gust. Bands long across the wind
// and short along it, moving downwind at the wind's own speed.
float gust_at(vec2 xz, vec2 wind, float t) {
	vec2 w = normalize(wind);
	vec2 frame = vec2(dot(xz, w), dot(xz, vec2(-w.y, w.x)));
	return fbm2(frame * vec2(0.004, 0.0016) - vec2(t * length(wind) * 0.004, 0.0));
}
