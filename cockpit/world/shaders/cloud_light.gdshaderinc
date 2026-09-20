// HOW A CUMULUS IS LIT, for both finishes and the fog clouds: PLAIN calls it once a vertex, FINE once a pixel, the fog once a
// froxel, so none of them can disagree about what colour a cloud's base is at evening.
//
// UNSHADED CLOUDS, LIT HERE. A white albedo under the engine's wrap-lit sun came out nearly as bright on the side
// away from the sun as on the side facing it -- a blob with a slightly grey bottom (2026-09-13 day screenshots). A
// custom light() would do it properly and does not run where vertex shading is forced, which is the default on
// mobile platforms, a standalone headset among them. So the light is worked out from uniforms the level writes ONCE
// PER CHANGE of the time of day (`LiftYard.show_daylight`, from `DaylightTuning`'s own sun, sky and ground):
//
//   A DARK FLAT BASE: the underside is lit by the ground and the haze, not the sky, and darker the thicker the cloud,
//   because the light has further to come.
//   A SUNLIT CROWN: the sun's share rises with height in the cloud and with facing the sun.
//   A SILVER LINING: a thin outer edge seen with the sun behind it glows.
//
// AND A VOLUME, NOT A SHELL (asked for on 2026-09-15: "increase the volumetrics of the clouds"). Each cloud has an
// ENVELOPE, the ellipsoid of the same mass and spread as its lumps (`LiftYard.cloud_envelope`), and a point is lit by
// how much of that envelope lies between it and the sun: Beer's law, with a floor that falls ten times more slowly for the
// light that has scattered many times, so a cloud's far side and core are dim and never black. A lump surface buried deep
// in the envelope -- a crevice between towers, the middle of the skirt -- takes less of the sky's light, and a thin edge
// on the side turned from the sun passes a little sunlight through. The survey pictures before it
// (godotgames-drafts/2026-09-15/cockpit-mist/survey, cumulus_side) showed day clouds as white spheres with the same
// brightness on the sunlit and the shaded side of a heap.
//
// Nothing in here reads the screen or the eye's own position: `to_eye` is from EYE_POSITION_WORLD, the midpoint
// of the eyes, and the envelope is in the world, so a lining and a shadow are the same in both.

uniform vec3 sun_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 towards_sun = vec3(0.42, 0.57, 0.71);
uniform vec3 sky_light : source_color = vec3(0.55, 0.62, 0.74);
uniform vec3 shade_light : source_color = vec3(0.45, 0.48, 0.54);
uniform vec2 base_bright = vec2(0.95, 0.55);
uniform vec2 thick_range = vec2(250.0, 1100.0);
uniform float sunlit = 0.75;
uniform float away = 0.25;
uniform float ambient_share = 0.5;
uniform float lining = 0.9;
uniform float lining_tightness = 6.0;
// THE VOLUME, `CloudTuning`'s SUN_EXTINCTION, SCATTER_FLOOR, SCATTER_REACH, CORE_SHADE and TRANSLUCENT.
uniform float sun_extinction = 0.0033;
uniform float scatter_floor = 0.35;
uniform float scatter_reach = 0.25;
uniform float core_shade = 0.6;
uniform float translucent = 0.3;

// HOW MANY METRES OF A CLOUD'S ENVELOPE LIE BETWEEN `p` AND THE SUN: the chord of the ray from `p` towards the sun through
// the ellipsoid at `centre` with `radii`, from `p` (or where the ray enters, if `p` is outside it) to where it leaves.
float envelope_sun_depth(vec3 p, vec3 centre, vec3 radii) {
	vec3 r = max(radii, vec3(1.0));
	vec3 o = (p - centre) / r;
	vec3 d = towards_sun / r;
	float a = dot(d, d);
	float b = dot(o, d);
	float disc = b * b - a * (dot(o, o) - 1.0);
	if (disc <= 0.0) {
		return 0.0;
	}
	float s = sqrt(disc);
	return max((-b + s) / a - max((-b - s) / a, 0.0), 0.0);
}

// How deep inside the envelope `p` is: 0 on or outside its surface, 1 at its middle.
float envelope_buried(vec3 p, vec3 centre, vec3 radii) {
	return clamp(1.0 - length((p - centre) / max(radii, vec3(1.0))), 0.0, 1.0);
}

// The share of the sun that reaches a point `depth` metres into a cloud: the direct light, or the scattered floor.
float sun_through(float depth) {
	return max(exp(-depth * sun_extinction), scatter_floor * exp(-depth * sun_extinction * scatter_reach));
}

// `n` the world normal, `rise` 0 at the cloud's base to 1 at its top, `thickness` the cloud's height in metres,
// `texture_term` a small signed offset to the rise from noise (0 where there is none), `thin` how far towards the
// silhouette this point is, 0 facing the eye and 1 edge-on, `sun_depth` and `buried` from the envelope, above.
vec3 cloud_light(vec3 n, vec3 to_eye, float rise, float thickness, float texture_term, float thin, float sun_depth,
		float buried) {
	float facing_sun = clamp(dot(n, towards_sun) * 0.5 + 0.5, 0.0, 1.0);
	float base_share = mix(base_bright.x, base_bright.y, smoothstep(thick_range.x, thick_range.y, thickness));
	float depth_light = mix(base_share, 1.0, smoothstep(0.0, 0.7, rise + texture_term));
	float through = sun_through(sun_depth);
	float sun_share = mix(away, sunlit, facing_sun * facing_sun) * depth_light * through;
	float down = clamp(-n.y, 0.0, 1.0);
	float hollow = mix(1.0, core_shade, smoothstep(0.0, 0.7, buried));
	vec3 ambient = mix(sky_light, shade_light, down) * mix(base_share, 1.0, rise) * ambient_share * hollow;
	float against = pow(clamp(dot(-to_eye, towards_sun), 0.0, 1.0), lining_tightness);
	float outer = 1.0 - smoothstep(0.0, 0.5, buried);
	return sun_light * (sun_share + against * lining * thin * outer + translucent * thin * through * (1.0 - facing_sun))
		+ ambient;
}
