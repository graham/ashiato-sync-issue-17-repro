// THE SKY ON THE PLAIN FINISH: Godot's procedural sky, as the ProceduralSkyMaterial PLAIN wore until 2026-09-15, with the moon
// and the stars at night and nothing else. No half-resolution pass and no cirrus: those are FINE's.
//
// WHY PLAIN LEFT THE MATERIAL. A headset starts on PLAIN (`Finish.HEADSET_DEFAULT`), and a ProceduralSkyMaterial has no
// moon to wear, so the moon asked for would not have been in the headset it was asked for. The procedural code is copied
// (`sky_procedural.gdshaderinc`), so this sky by day is the material's; `Daylight.plain_sky` wears it.
shader_type sky;
render_mode use_debanding;

#include "res://world/shaders/sky_procedural.gdshaderinc"
#include "res://world/shaders/sky_night.gdshaderinc"
#include "res://world/shaders/sky_stars.gdshaderinc"

void sky() {
	// FIRST, BEFORE ANY BRANCH: a derivative inside one is undefined.
	float pixel = pixel_angle(dFdx(EYEDIR), dFdy(EYEDIR));
	vec3 sky = sky_gradient(EYEDIR) + dusk_glow_seen(EYEDIR);
	// OUTSIDE THE CUBEMAP, the moon and its small halo wherever the moon stands (`moon_direction`); the light's disc and glow
	// as the ProceduralSkyMaterial drew them while the light is the sun, and in the cubemap always.
	bool moonlit = moon_bright > 0.0 && !AT_CUBEMAP_PASS;
	vec4 moon = moonlit ? moon_light_seen(EYEDIR, moon_direction, pixel, moon_light) : vec4(0.0);
	// THE STARS, outside the cubemap and behind the moon's disc.
	if (!AT_CUBEMAP_PASS) {
		float moon_lit = moonlit ? 0.5 - 0.5 * dot(true_sun, moon_direction) : 0.0;
		sky += stars_seen(EYEDIR, pixel, moon_direction, moon_lit) * (1.0 - moon.a);
	}
	sky += moon.rgb;
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
