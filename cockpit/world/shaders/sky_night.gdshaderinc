// THE MOON, IN BOTH SKIES (2026-09-15): a disc wearing the moon's near side, lit on the side that faces the sun, drawn along
// the light that is the moon at night. Asked for: "make sure the moon at night has a moon decal, that way it looks like the
// real moon". Before, the sky drew the night's light as it draws the sun -- a light-coloured disc and glow -- which at the
// night's energy was a faint blue smudge with no face and no phase.
//
// WHERE: along `moon_direction`, `Orrery.moon` at the session's clock (2026-09-18). Until then the disc was drawn along
// LIGHT0_DIRECTION, the light being the moon at night; with a clock the moon stands in the sky over the blue hour while the
// sun is still the light, so it has a direction of its own, and when it IS the light (`light_is_moon`) the two are one
// vector from one sum. At infinity -- a direction and no position -- so both eyes see it in the same place and it never moves
// as the head does.
//
// THE FACE: `moon_face`, NASA's LRO colour map baked into an orthographic near-side disc (see NightSkyTuning for the source
// and its public-domain terms), sampled across the disc with the mip level worked out from how many texels fall in a pixel.
// textureLod and not texture: the implicit derivatives of a sample are undefined inside a branch, and this is called in one.
//
// THE PHASE: `true_sun`, towards the sun as `DaylightTuning.towards_the_true_sun` has it -- under the horizon at night. Each
// point of the face is a point on a sphere turned to the eye, lit Lommel-Seeliger fashion, 2 cos(i) / (cos(i) + cos(e)),
// which is the moon's own law: a full moon is flat to its limb and not a shaded ball. The terminator is softened over
// `moon_terminator` of cos(i). The dark side keeps `moon_earthshine` of the lit face's brightness with a full Earth, as it has
// under a thin crescent, and less as the Earth seen from the moon wanes.
//
// THE EDGE is antialiased over one pixel, from `pixel`, the view direction's change across a pixel, which sky() takes before
// any branch. In a headset each eye's view is drawn on its own, so dFdx and dFdy of EYEDIR are that eye's own neighbours
// and the footprint is that eye's pixel -- reasoned, since every run here is one view; the headset is where to look.
//
// ADDED TO THE SKY, NOT LAID OVER IT: the air's glow lies between the eye and the moon, so the moon's light is added to the
// sky's colour and its cover only hides what is BEHIND it. The first pictures (2026-09-15) laid it over, and the dark limb of
// a gibbous moon and all of a crescent's were black, darker than the sky round them.
//
// A SMALL HALO, NOT THE LIGHT'S GLOW. The procedural light disc's glow reaches 30 degrees and filled a close view of the moon
// with the light's blue; at night `moon_light_seen` draws, in its place, `moon_halo` of the light's colour and energy falling
// away by e every `moon_halo_width` radians outside the disc, as bright as the moon is lit.
//
// NOT IN THE CUBEMAP PASS: the caller keeps the procedural glow there, as it always drew, so what the sky throws on the world
// and what the sea reflects are unchanged.
#ifndef SKY_NIGHT_GDSHADERINC
#define SKY_NIGHT_GDSHADERINC

uniform sampler2D moon_face : source_color, filter_linear_mipmap, repeat_disable;
// How bright the face is before the tonemapper; 0 draws no moon. The time of day's `moon_bright`.
uniform float moon_bright = 0.0;
// The disc's angular radius, radians: NightSkyTuning.moon_radius().
uniform float moon_radius = 0.0068;
uniform vec3 moon_tint : source_color = vec3(1.0, 0.96, 0.9);
uniform float moon_terminator = 0.05;
uniform float moon_earthshine = 0.02;
// The halo's brightness as a share of the light's colour and energy, and how far it reaches, radians: NightSkyTuning's.
uniform float moon_halo = 0.5;
uniform float moon_halo_width = 0.035;
// Towards the sun, lit or not: `Orrery.sun`.
uniform vec3 true_sun = vec3(0.0, -1.0, 0.0);
// Towards the moon (`Orrery.moon`), and its light as its halo is drawn with -- a linear colour times its energy, what
// LIGHT0_COLOR * LIGHT0_ENERGY is when the light is the moon -- and whether the light IS the moon, when the light's own disc
// is not drawn outside the cubemap. `DaylightTuning.look_at`'s "moon", "moon_light" and "light_is_moon".
uniform vec3 moon_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_light = vec3(0.0);
uniform float light_is_moon = 0.0;
// THE GLOW ON THE HORIZON WHERE THE SUN IS, round sunset and dawn: `DaylightTuning.dusk_glow`, a linear colour times its
// strength, 0 at DAY, EVENING and NIGHT.
uniform vec3 dusk_glow = vec3(0.0);
// THE SUN'S DISC AS THE SKY DRAWS IT, while the sun is the light: `DaylightTuning.look_at`'s "sun_seen", the light's colour
// and energy before its fade toward the horizon -- equal to LIGHT0_COLOR * LIGHT0_ENERGY at every preset, and bright where the
// light has faded, so a rising sun is not drawn as a dark disc.
uniform vec3 sun_seen = vec3(1.0);

// THE DUSK GLOW SEEN ALONG `dir`, to ADD to the sky's gradient: brightest on the horizon under the sun, falling away by e
// every 40 degrees round from it and every seven degrees up. None below the horizon, where the ground is drawn.
vec3 dusk_glow_seen(vec3 dir) {
	if (dusk_glow.r + dusk_glow.g + dusk_glow.b <= 0.0 || dir.y < 0.0) {
		return vec3(0.0);
	}
	vec2 sun_flat = normalize(true_sun.xz + vec2(1e-6, 0.0));
	vec2 eye_flat = normalize(dir.xz + vec2(1e-6, 0.0));
	float round_from_sun = acos(clamp(dot(sun_flat, eye_flat), -1.0, 1.0));
	return dusk_glow * exp(-round_from_sun / 0.7) * exp(-dir.y / 0.12);
}

// How many radians of sky one pixel spans, from the view direction's change across it in x and in y.
float pixel_angle(vec3 across_x, vec3 across_y) {
	return max(max(length(across_x), length(across_y)), 1e-6);
}

// THE MOON SEEN ALONG `dir`, with the moon along `moon` and a pixel `pixel` radians across: rgb is its light, a is how much of
// the pixel it covers. Nothing where there is no moon.
vec4 moon_seen(vec3 dir, vec3 moon, float pixel) {
	if (moon_bright <= 0.0 || dot(dir, moon) <= 0.0) {
		return vec4(0.0);
	}
	// THE FACE'S OWN AXES, lunar north towards the sky's up. Looking along `moon`, `right` is the right of the view.
	vec3 right = cross(moon, vec3(0.0, 1.0, 0.0));
	right = dot(right, right) < 1e-8 ? vec3(1.0, 0.0, 0.0) : normalize(right);
	vec3 up = cross(right, moon);
	float size = sin(moon_radius);
	vec2 at = vec2(dot(dir, right), dot(dir, up)) / size;
	float r = length(at);
	float cover = clamp((1.0 - r) * size / pixel + 0.5, 0.0, 1.0);
	if (cover <= 0.0) {
		return vec4(0.0);
	}
	// A pixel over the limb is read at the limb.
	vec2 face = at / max(r, 1.0);
	float toward_eye = sqrt(max(1.0 - dot(face, face), 0.0));
	vec3 normal = right * face.x + up * face.y - moon * toward_eye;
	float lod = log2(max(float(textureSize(moon_face, 0).x) * pixel / (2.0 * size), 1.0));
	vec3 albedo = textureLod(moon_face, vec2(0.5 + 0.5 * face.x, 0.5 - 0.5 * face.y), lod).rgb;
	float cos_sun = dot(normal, true_sun);
	float lit = min(2.0 * max(cos_sun, 0.0) / (max(cos_sun, 0.0) + toward_eye + 0.001), 1.25)
		* smoothstep(-moon_terminator, moon_terminator, cos_sun);
	float earthshine = moon_earthshine * (0.5 + 0.5 * dot(true_sun, moon));
	return vec4(albedo * moon_tint * moon_bright * (lit + earthshine), cover);
}

// THE MOON AND ITS HALO seen along `dir`, to ADD to the sky: rgb is the light added, a is how much of the pixel the disc
// covers, which is what hides a star behind it. `light` is the moonlight's colour times its energy.
vec4 moon_light_seen(vec3 dir, vec3 moon, float pixel, vec3 light) {
	float toward = dot(dir, moon);
	if (moon_bright <= 0.0 || toward < cos(moon_radius + moon_halo_width * 12.0)) {
		return vec4(0.0);
	}
	vec4 face = moon_seen(dir, moon, pixel);
	float outside = max(acos(clamp(toward, -1.0, 1.0)) - moon_radius, 0.0);
	float lit_share = 0.5 - 0.5 * dot(true_sun, moon);
	vec3 halo = light * moon_halo * lit_share * exp(-outside / moon_halo_width);
	return vec4(face.rgb * face.a + halo, face.a);
}

#endif
