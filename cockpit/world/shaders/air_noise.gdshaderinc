// Three-dimensional noise, for the things in the AIR: clouds and smoke.
//
// The ground's noise is two-dimensional because the ground is a surface. A cloud or a column of
// smoke is a volume seen from every side, and noise read off a plane shows as stripes down its
// flanks. So these are the same value noise one dimension up -- eight hashes a lookup instead of
// four -- and they live in their own include so that the rock, the grass and the plain ocean
// compile from exactly the text they always did.
//
// Only ever used on things that cover a small part of the screen most of the time. A cloud you
// fly INTO fills both eyes, so nothing here goes past three octaves, and the fragment-side users
// take two.

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise3(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash31(cell), hash31(cell + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash31(cell + vec3(0.0, 1.0, 0.0)), hash31(cell + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash31(cell + vec3(0.0, 0.0, 1.0)), hash31(cell + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash31(cell + vec3(0.0, 1.0, 1.0)), hash31(cell + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float fbm3_3d(vec3 p) {
	float sum = value_noise3(p) * 0.5;
	sum += value_noise3(p * 2.03) * 0.25;
	sum += value_noise3(p * 4.01) * 0.125;
	return sum / 0.875;
}

float fbm2_3d(vec3 p) {
	return (value_noise3(p) * 0.5 + value_noise3(p * 2.03) * 0.25) / 0.75;
}
