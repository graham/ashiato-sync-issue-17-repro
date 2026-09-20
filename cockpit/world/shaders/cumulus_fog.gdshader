// CUMULUS AS FOG, ON THE FINE FINISH, NEAR THE EYE: the lumps' envelope eroded by three octaves of world-space noise that
// climb and turn over, so a cloud boils in still air without leaving its thermal, and lit as the mesh cloud is. See
// cumulus_fog.gdshaderinc.
//
// Drawn on FINE, on Forward+, faded in by `presence` (CloudBank). At 128 froxels across a 1600-pixel
// picture the octaves above the first are barely seen (erosion 0.7 at twice the frequency drew the same blur, cloud_near
// 2026-09-14); they are kept for the near field, where a froxel is a few metres.
shader_type fog;

#include "res://world/shaders/cumulus_fog.gdshaderinc"

void fog() {
	vec3 p = WORLD_POSITION;
	vec3 normal;
	float shape = cloud_shape(p, normal);
	float density = 0.0;
	float n = 0.5;
	if (shape > 0.0) {
		vec3 q = p * noise_scale;
		float t = TIME * climb * noise_scale;
		// EACH OCTAVE DRIFTS ITS OWN WAY, so the shape changes rather than one pattern sliding up through the cloud.
		float smooth_n = (value_noise3(q - vec3(0.0, t, 0.0)) * 0.5
			+ value_noise3(q * 2.03 + vec3(t * 0.7, -t * 1.6, 0.0)) * 0.25
			+ value_noise3(q * 4.01 + vec3(0.0, -t * 2.3, t)) * 0.125) / 0.875;
		// SHREDDED, NOT SMOOTH: billows eat into the edge, and near the eye a finer octave, where froxels are small enough.
		n = mix(smooth_n, billows(q * 1.7 + vec3(0.0, -t * 1.3, 0.0)), billow_share);
		float near = 1.0 - smoothstep(near_reach.x, near_reach.y, distance(p, eye_at));
		n = clamp(n + (value_noise3(q * 9.1 + vec3(t, -t * 2.0, 0.0)) - 0.5) * near_detail * near, 0.0, 1.0);
		density = cloud_density(shape, n);
	}
	DENSITY = density * core_density * presence;
	// THE COLOUR RIDES IN ALBEDO, DIVIDED BY THE LIGHT THE ENGINE WILL MULTIPLY IT BY. See cumulus_fog.gdshaderinc.
	ALBEDO = cloud_colour(p, normal, n) / max(engine_sun * sun_scale, vec3(1e-4));
}
