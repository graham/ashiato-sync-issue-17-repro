// THE SKY ON THE FINE FINISH: Godot's procedural sky, line for line, with a veil of cirrus nine kilometres up drawn in the
// half-resolution pass (2026-09-14), and the moon and the stars at night (2026-09-15). PLAIN wears the same sky without the cirrus
// (`sky_plain.gdshader`).
//
// THE PROCEDURAL SKY IS COPIED, NOT REDRAWN, and lives in `sky_procedural.gdshaderinc`, which both finishes include; the moon
// is `sky_night.gdshaderinc`.
//
// THE CIRRUS: a flat sheet at `cirrus_height`, where the eye's ray meets it; streaks drawn long along `cirrus_heading` by
// stretching warped value noise; faded out with the distance along the ray so the horizon does not fill with a sheet; lit by
// LIGHT0 -- the sun, and the moon at night, so the time of day reaches it with no uniform of its own -- and the horizon. No
// TIME: there is no wind, and TIME in a sky shader redraws its cubemap every frame. Not in the cubemap pass either, so the
// light the sky throws on the world is the sky's without it.
//
// THE MOON IS DRAWN UNDER THE CIRRUS: before the half-resolution colour is laid over, so a streak crossing the moon covers
// it and its halo. The sun is still drawn over the cirrus, as it was, so the day's sky is unchanged.
shader_type sky;
render_mode use_half_res_pass, use_debanding;

#include "res://world/shaders/air_noise.gdshaderinc"
#include "res://world/shaders/sky_procedural.gdshaderinc"
#include "res://world/shaders/sky_night.gdshaderinc"
#include "res://world/shaders/sky_stars.gdshaderinc"

uniform float cirrus_height = 9000.0;
uniform float cirrus_cover = 0.45;
uniform float cirrus_scale = 0.00012;
uniform float cirrus_stretch = 6.0;
uniform vec2 cirrus_heading = vec2(0.8, 0.6);
uniform float cirrus_reach = 60000.0;
uniform float cirrus_opacity = 0.55;
uniform float cirrus_sun_share = 0.5;
uniform float cirrus_sky_share = 0.6;

// How much cirrus the ray from `eye` along `dir` meets, 0 to 1.
float cirrus_cover_at(vec3 dir, vec3 eye) {
	if (dir.y <= 0.01) {
		return 0.0;
	}
	float t = (cirrus_height - eye.y) / dir.y;
	if (t <= 0.0) {
		return 0.0;
	}
	vec2 p = eye.xz + dir.xz * t;
	vec2 along = normalize(cirrus_heading);
	vec2 across = vec2(-along.y, along.x);
	vec2 q = vec2(dot(p, along) / cirrus_stretch, dot(p, across)) * cirrus_scale;
	// A STREAK WANDERS AND BREAKS. Straight bands the length of the sky read as searchlight beams (the cirrus view,
	// 2026-09-14): each is bent sideways by noise slow along its length, and its cover comes and goes along it.
	float bend = value_noise3(vec3(q.x * 0.25, q.y * 0.08, 11.0));
	q.y += (bend - 0.5) * 2.5;
	float warp = value_noise3(vec3(q * 0.35, 7.0));
	float n = value_noise3(vec3(q + vec2(warp * 1.5, 0.0), 0.0)) * 0.6
		+ value_noise3(vec3(q * 2.3 + vec2(0.0, warp), 3.0)) * 0.3
		+ value_noise3(vec3(q * 5.1, 5.0)) * 0.1;
	float breaks = smoothstep(0.3, 0.7, value_noise3(vec3(q.x * 0.9, q.y * 0.4, 13.0)));
	float cover = smoothstep(1.0 - cirrus_cover, 1.0 - cirrus_cover + 0.25, n) * breaks;
	return cover * (1.0 - smoothstep(cirrus_reach * 0.4, cirrus_reach, t));
}

void sky() {
	// FIRST, BEFORE ANY BRANCH: a derivative inside one is undefined.
	float pixel = pixel_angle(dFdx(EYEDIR), dFdy(EYEDIR));
	if (AT_HALF_RES_PASS) {
		vec3 light = LIGHT0_ENABLED ? LIGHT0_COLOR * LIGHT0_ENERGY : vec3(0.0);
		COLOR = sky_horizon_color.rgb * cirrus_sky_share + light * cirrus_sun_share;
		ALPHA = cirrus_cover_at(EYEDIR, POSITION) * cirrus_opacity;
	} else {
		vec3 sky = sky_gradient(EYEDIR) + dusk_glow_seen(EYEDIR);
		// OUTSIDE THE CUBEMAP, the moon and its small halo wherever the moon stands (`moon_direction`), UNDER the cirrus; by day,
		// and in the cubemap, the light's disc and glow over it, as they always were.
		bool moonlit = moon_bright > 0.0 && !AT_CUBEMAP_PASS;
		vec4 moon = moonlit ? moon_light_seen(EYEDIR, moon_direction, pixel, moon_light) : vec4(0.0);
		// THE STARS, outside the cubemap, behind the moon's disc and under the cirrus.
		if (!AT_CUBEMAP_PASS) {
			float moon_lit = moonlit ? 0.5 - 0.5 * dot(true_sun, moon_direction) : 0.0;
			sky += stars_seen(EYEDIR, pixel, moon_direction, moon_lit) * (1.0 - moon.a);
		}
		sky += moon.rgb;
		if (!AT_CUBEMAP_PASS) {
			sky = mix(sky, HALF_RES_COLOR.rgb, HALF_RES_COLOR.a);
		}
		// THE LIGHT'S DISC WHEN THE LIGHT IS THE SUN; when it is the moon, only in the cubemap, as it always was.
		if (LIGHT0_ENABLED && (AT_CUBEMAP_PASS || light_is_moon < 0.5)) {
			sun_disk(EYEDIR, LIGHT0_DIRECTION, LIGHT0_SIZE, sky, light_is_moon > 0.5 ? LIGHT0_COLOR * LIGHT0_ENERGY : sun_seen);
		}
		if (LIGHT1_ENABLED) {
			sun_disk(EYEDIR, LIGHT1_DIRECTION, LIGHT1_SIZE, sky, LIGHT1_COLOR * LIGHT1_ENERGY);
		}
		if (LIGHT2_ENABLED) {
			sun_disk(EYEDIR, LIGHT2_DIRECTION, LIGHT2_SIZE, sky, LIGHT2_COLOR * LIGHT2_ENERGY);
		}
		if (LIGHT3_ENABLED) {
			sun_disk(EYEDIR, LIGHT3_DIRECTION, LIGHT3_SIZE, sky, LIGHT3_COLOR * LIGHT3_ENERGY);
		}
		COLOR = sky_with_ground(EYEDIR, sky);
	}
}
