// GODOT'S PROCEDURAL SKY, COPIED, FOR BOTH FINISHES: the uniforms, the gradient, the ground and the light disc of
// `ProceduralSkyMaterial::_update_shader` (scene/resources/3d/sky_material.cpp, 4.7), with the same uniform names, so Daylight
// writes the same four colours it always did. Its setters write `inv_sky_curve` 0.6 / 0.15, `inv_ground_curve` 0.6 / 0.02,
// `sun_angle_max` cos(30 degrees), `inv_sun_curve` 1.6 / pow(0.15, 1.4) and `exposure` 1, which are the defaults below.
//
// SHARED SINCE THE MOON (2026-09-15). FINE's sky copied this in 2026-09-14 for its cirrus, and PLAIN kept the
// ProceduralSkyMaterial itself. A headset starts on PLAIN (`Finish.HEADSET_DEFAULT`), so a moon drawn only in FINE's shader
// would never have reached one: PLAIN wears `sky_plain.gdshader` now, this and the moon with no cirrus, and the code the
// two share lives here once.
#ifndef SKY_PROCEDURAL_GDSHADERINC
#define SKY_PROCEDURAL_GDSHADERINC

uniform vec4 sky_top_color : source_color = vec4(0.385, 0.454, 0.55, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.646, 0.656, 0.67, 1.0);
uniform float inv_sky_curve : hint_range(1, 100) = 4.0;
uniform vec4 ground_bottom_color : source_color = vec4(0.2, 0.169, 0.133, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.646, 0.656, 0.67, 1.0);
uniform float inv_ground_curve : hint_range(1, 100) = 30.0;
uniform float sun_angle_max = 0.8660254;
uniform float inv_sun_curve : hint_range(1, 100) = 22.7597;
uniform float exposure : hint_range(0, 128) = 1.0;

float sun_disk(vec3 dir, vec3 light_dir, float light_size, inout vec3 sky, vec3 light) {
	float sun_angle = dot(light_dir, dir);
	float sun_size = cos(light_size);
	if (sun_angle > sun_size) {
		sky = light;
	} else if (sun_angle > sun_angle_max) {
		float c2 = (sun_size - sun_angle) / (sun_size - sun_angle_max);
		sky = mix(sky, light, clamp(pow(1.0 - c2, inv_sun_curve), 0.0, 1.0));
	}
	return 0.0;
}

// The sky above the horizon along `dir`, before any light is drawn on it.
vec3 sky_gradient(vec3 dir) {
	float v_angle = clamp(dir.y, -1.0, 1.0);
	return mix(sky_top_color.rgb, sky_horizon_color.rgb, clamp(pow(1.0 - v_angle, inv_sky_curve), 0.0, 1.0));
}

// The sky's ground along `dir`, and the two put together at the horizon.
vec3 sky_with_ground(vec3 dir, vec3 sky) {
	float v_angle = clamp(dir.y, -1.0, 1.0);
	vec3 ground = mix(ground_bottom_color.rgb, ground_horizon_color.rgb, clamp(pow(1.0 + v_angle, inv_ground_curve), 0.0, 1.0));
	return mix(ground, sky, step(0.0, dir.y)) * exposure;
}

#endif
