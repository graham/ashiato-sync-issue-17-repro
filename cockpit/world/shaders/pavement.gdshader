// PAVEMENT, PLAIN: the runway's asphalt and its paint, with the seams and the rubber that appear when you are near
// enough to see them, and nothing that costs more than that.
//
// Far away this is the flat vertex-coloured surface the runway has always been, to the pixel: the wear fade reaches
// zero at `wear_fade.y` and every line below it is multiplied by that fade, so past it the fragment stage does one
// `length`, one `smoothstep` and an assignment. Near, it gains the paving-lane seams, the transverse joints and the
// black of the touchdown zone.
//
// WHAT PLAIN GETS AND WHY. The split between the tiers is not "half as much of the same thing" -- it is along what the
// detail IS. The seams and the rubber are geometry-scale features, a handful of smoothsteps and one octave of noise,
// and they are the ones a pilot actually uses: the dark touchdown zone is a cue from the whole way down the approach.
// The aggregate grain is high-frequency noise that only exists within about 150 m and is the expensive half, so it is
// FINE's (`pavement_fine.gdshader`). A PLAIN player on short final sees the strip break into paving lanes with a
// scrubbed black touchdown zone; they do not see the stones in the asphalt.
//
// See `pavement.gdshaderinc` for why the distance is `length(VERTEX)`, why the fade is not interpolated from the
// vertex stage, and why this is not split into a near shader and a far one.
shader_type spatial;
render_mode cull_back;

#include "res://world/shaders/terrain_noise.gdshaderinc"
#include "res://world/shaders/pavement.gdshaderinc"

// HOW NEAR THE DETAIL IS WORTH DRAWING, in metres, as (full, gone). Set on the material at build from `DetailReach`,
// which is the one place these live. The default here draws NOTHING -- gone by a metre -- rather than repeating
// `DetailReach`'s numbers as a second copy of them; an undressed material is therefore the plain runway as it was,
// and `tests/pavement.gd` asserts the material carries `DetailReach.pavement_numbers()` so that silence is caught.
uniform vec2 wear_fade = vec2(0.0, 1.0);
// The pavement's roughness, matching the StandardMaterial3D this replaced.
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.92;

// Where this pixel is on its runway, in metres: x across from the centreline, y along from the middle. Affine in
// position, so interpolating it is exact.
varying vec2 on_runway;
// The runway's half length, carried so the touchdown zone can be measured from whichever threshold is nearer.
varying float half_length;

void vertex() {
	vec3 world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The runway's centre, bearing and half length, put on every instance by `Sky._draw_runway` from the frame
	// `Terrain` laid it to. A painted stripe and the asphalt under it carry the same four numbers.
	on_runway = pavement_on_runway(world_at.xz, INSTANCE_CUSTOM.xy, INSTANCE_CUSTOM.z);
	half_length = INSTANCE_CUSTOM.w;
}

void fragment() {
	vec3 albedo = COLOR.rgb;
	float wear = detail_fade(length(VERTEX), wear_fade.x, wear_fade.y);
	// COHERENT, NOT CLEVER: ground distance varies smoothly across the screen, so whole wavefronts take one side of
	// this and the far ones do no work at all. See the register-pressure note in the include for why the branch is
	// worth having and why what is inside it is kept shallow.
	if (wear > 0.0) {
		// THE MASK FIRST AND THE NOISE ONLY INSIDE IT: outside the touchdown zone the mask is exactly zero, and
		// blotching a zero costs four hash lookups to throw away. See `pavement_rubber_mask`.
		float rubber = pavement_rubber_mask(on_runway, half_length, RUBBER_ZONE, RUBBER_WHEELS);
		if (rubber > 0.0) {
			rubber *= value_noise(on_runway * BLOTCH_SCALE);
		}
		// The lanes run along the strip, so they are spaced ACROSS it; the day joints the other way about.
		float lanes = pavement_seam(on_runway.x + PAVING_OFFSET, PAVING_LANE, JOINT_WIDTH);
		float stops = pavement_seam(on_runway.y, PAVING_STOP, JOINT_WIDTH);
		float joints = max(lanes, stops);
		albedo *= 1.0 - wear * (rubber * RUBBER_DARK + joints * JOINT_DARK);
	}
	ALBEDO = albedo;
	ROUGHNESS = surface_roughness;
}
