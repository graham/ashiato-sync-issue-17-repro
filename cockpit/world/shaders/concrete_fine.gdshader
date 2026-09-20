// AN AIR BASE'S PAVEMENT, FINE: the same slab joints, and the staining and grain of concrete on top of them.
//
// WHAT FINE ADDS HERE, and why it is not what it adds to the runway. Asphalt's expensive half is the aggregate --
// stones a few centimetres across, only visible from about a hundred metres in. Concrete's is different: a poured
// bay is smooth, and what actually reads on one from a taxiing aeroplane is the DISCOLOURATION -- each bay cured on
// a different day to a slightly different shade, with tyre and fuel staining down the middle of a taxiway where
// every aircraft's wheels have run. So FINE's layer on concrete is per-BAY tone plus a stain, at a scale a bay
// across rather than a stone across, and it survives much further out than the runway's aggregate does.
//
// PER-BAY AND NOT PER-PIXEL: the tone is hashed off the bay's own cell, so a whole slab shifts together and the
// joints between slabs read as edges between two shades rather than as lines drawn on one. That is the thing that
// makes concrete look poured instead of painted, and it is one hash per pixel of a value that is constant across
// the bay.
//
// See `pavement.gdshaderinc` for the distance, the anti-aliasing and the two rejected designs, and
// `concrete.gdshader` for why the colour is converted from sRGB here and is not on the runway.
shader_type spatial;
render_mode cull_back;

#include "res://world/shaders/terrain_noise.gdshaderinc"
#include "res://world/shaders/pavement.gdshaderinc"

uniform vec2 wear_fade = vec2(0.0, 1.0);
uniform vec2 grain_fade = vec2(0.0, 1.0);
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.92;
// How far apart two bays' shades can be, and how dark the staining gets at its worst.
uniform float bay_tone : hint_range(0.0, 1.0) = 0.07;
uniform float stain_dark : hint_range(0.0, 1.0) = 0.18;

varying vec2 on_ground;

void vertex() {
	on_ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 albedo = pavement_srgb_to_linear(COLOR.rgb);
	float away = length(VERTEX);
	float wear = detail_fade(away, wear_fade.x, wear_fade.y);
	if (wear > 0.0) {
		float joints = max(pavement_seam(on_ground.x, CONCRETE_BAY, JOINT_WIDTH),
			pavement_seam(on_ground.y, CONCRETE_BAY, JOINT_WIDTH));
		// EACH BAY ITS OWN SHADE, hashed off the cell the pixel falls in so the whole slab moves together.
		float bay = hash21(floor(on_ground / CONCRETE_BAY)) - 0.5;
		// AND THE STAINING, broad and soft, at a few bays' scale: oil, fuel and rubber off taxiing tyres, which
		// pools where the traffic is rather than evenly.
		float stain = smoothstep(0.45, 0.95, fbm2(on_ground * 0.05));
		albedo *= 1.0 - wear * (joints * CONCRETE_JOINT_DARK + stain * stain_dark - bay * bay_tone);
	}
	// THE GRAIN, inside its own much nearer band and independent of the one above -- nesting it would tie the near
	// layer's life to the far one's. Finer and weaker than the asphalt's, because a floated concrete surface is.
	float grain = detail_fade(away, grain_fade.x, grain_fade.y);
	if (grain > 0.0) {
		albedo *= 1.0 + grain * 0.09 * (value_noise(on_ground * GRAIN_SCALE * 1.7) - 0.5);
	}
	ALBEDO = albedo;
	ROUGHNESS = surface_roughness;
}
