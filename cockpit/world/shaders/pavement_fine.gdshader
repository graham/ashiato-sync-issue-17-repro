// PAVEMENT, FINE: everything PLAIN draws, and the aggregate in the asphalt on top of the same seams.
//
// THE TWO AXES COMPOSE HERE AND THEY ARE NOT THE SAME AXIS. `Finish` is the tier -- one word for the whole world,
// PLAIN or FINE -- and this file is the FINE one, chosen once at build the way `rock_fine` and `building_fine` are.
// The distance fades inside it are the other axis, per pixel and continuous, and they run on BOTH tiers: FINE does
// not move the runway's detail nearer or further, it adds a layer to what is already there at that range. A player
// on PLAIN still gets the seams and the black touchdown zone on short final; this adds the stones.
//
// TWO GRADES OF NOISE, which is the actual difference. The rubber's blotching is one octave on PLAIN
// (`value_noise`) and two here (`fbm2`), so its edge stops being a smooth lobe and starts having bays in it. The
// grain is entirely FINE's: it lives inside about 150 m, it is the high-frequency half, and high-frequency detail is
// the half that costs and the half that sparkles.
//
// See `pavement.gdshaderinc` for the distance, the anti-aliasing of the seams, and the two rejected designs.
shader_type spatial;
render_mode cull_back;

#include "res://world/shaders/terrain_noise.gdshaderinc"
#include "res://world/shaders/pavement.gdshaderinc"

// As `pavement.gdshader`: set from `DetailReach`, and defaulting to nothing rather than to a second copy of its
// numbers. `grain_fade` is the nearer of the two bands -- the aggregate is centimetres across and is a pixel at a
// hundred and sixty metres, so drawing it past that buys nothing and is the exact thing that crawls in a headset.
uniform vec2 wear_fade = vec2(0.0, 1.0);
uniform vec2 grain_fade = vec2(0.0, 1.0);
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.92;
// How much the aggregate lightens and darkens the asphalt, and how much rougher a stone is than the binder round it.
uniform float grain_depth : hint_range(0.0, 1.0) = 0.16;
uniform float grain_roughen : hint_range(0.0, 1.0) = 0.05;

varying vec2 on_runway;
varying float half_length;

void vertex() {
	vec3 world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	on_runway = pavement_on_runway(world_at.xz, INSTANCE_CUSTOM.xy, INSTANCE_CUSTOM.z);
	half_length = INSTANCE_CUSTOM.w;
}

void fragment() {
	vec3 albedo = COLOR.rgb;
	float rough = surface_roughness;
	float away = length(VERTEX);
	float wear = detail_fade(away, wear_fade.x, wear_fade.y);
	if (wear > 0.0) {
		// THE MASK FIRST AND THE NOISE ONLY INSIDE IT: outside the touchdown zone the mask is exactly zero, and
		// blotching a zero costs four hash lookups to throw away. See `pavement_rubber_mask`.
		float rubber = pavement_rubber_mask(on_runway, half_length, RUBBER_ZONE, RUBBER_WHEELS);
		if (rubber > 0.0) {
			rubber *= fbm2(on_runway * BLOTCH_SCALE);
		}
		float lanes = pavement_seam(on_runway.x + PAVING_OFFSET, PAVING_LANE, JOINT_WIDTH);
		float stops = pavement_seam(on_runway.y, PAVING_STOP, JOINT_WIDTH);
		float joints = max(lanes, stops);
		albedo *= 1.0 - wear * (rubber * RUBBER_DARK + joints * JOINT_DARK);
	}
	// THE AGGREGATE, inside its own much nearer band. Nested inside the wear branch would be wrong: the two bands are
	// independent, and a tree that read `if (wear > 0.0)` round both would tie the near layer's life to the far one's.
	float grain = detail_fade(away, grain_fade.x, grain_fade.y);
	if (grain > 0.0) {
		float stones = value_noise(on_runway * GRAIN_SCALE) - 0.5;
		albedo *= 1.0 + grain * grain_depth * stones;
		rough += grain * grain_roughen * stones;
	}
	ALBEDO = albedo;
	ROUGHNESS = clamp(rough, 0.0, 1.0);
}
