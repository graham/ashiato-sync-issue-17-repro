// AN AIR BASE'S PAVEMENT, PLAIN: the taxiways, taxilanes and aprons, with the joints between their slabs when you are
// near enough to see them, and nothing that costs more than that.
//
// THE SAME MECHANISM AS THE RUNWAY AND A DIFFERENT SURFACE. `pavement.gdshader` draws asphalt, which is laid in lanes
// by a paving machine and collects rubber where aeroplanes land on it. This draws portland cement concrete, which is
// poured in a grid of bays and never gets landed on: joints both ways at one spacing, no rubber, and a smoother grain
// left to FINE. See `pavement.gdshaderinc` for why the distance is `length(VERTEX)`, why the fade is not carried from
// the vertex stage, and why this is not split into a near shader and a far one.
//
// NO INSTANCE CUSTOM DATA, UNLIKE THE RUNWAY'S. The runway needs its strip's centre and bearing handed to every mark
// so the touchdown zone does not restart inside each painted stripe. Concrete has no such feature: a slab grid is
// laid to the site and not to any one piece of pavement, so world position is the whole of the frame and the joints
// run unbroken from a taxiway across an apron to a hardstand, which is what they do on a real base.
//
// THE COLOUR IS CONVERTED FROM sRGB AND THE RUNWAY'S IS NOT. `AirbaseView._vertex_colour` sets
// `vertex_color_is_srgb = true`; `Sky._draw_runway` does not. Both are right for their own colours and a
// StandardMaterial3D hid the difference by doing the conversion for one of them. A custom shader is handed COLOR raw
// in both cases, so this one converts and `pavement.gdshader` must not. Getting that backwards shifts the gamma of a
// whole air base and looks like the lighting rather than like a bug.
shader_type spatial;
render_mode cull_back;

#include "res://world/shaders/terrain_noise.gdshaderinc"
#include "res://world/shaders/pavement.gdshaderinc"

// HOW NEAR THE DETAIL IS WORTH DRAWING, in metres, as (full, gone), set from `DetailReach` at build. The default here
// draws nothing rather than repeating the authority's numbers as a second copy of them.
uniform vec2 wear_fade = vec2(0.0, 1.0);
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.92;

// Where this pixel is in the world, in metres, flat. The slab grid is laid to this, so it is continuous across every
// piece of pavement on the base. Affine in position, so interpolating it is exact.
varying vec2 on_ground;

void vertex() {
	on_ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 albedo = pavement_srgb_to_linear(COLOR.rgb);
	float wear = detail_fade(length(VERTEX), wear_fade.x, wear_fade.y);
	if (wear > 0.0) {
		// THE BAYS, both ways at one spacing, each groove anti-aliased to the pixel so a sub-pixel joint fades out
		// rather than crawling. See `pavement_seam`.
		float joints = max(pavement_seam(on_ground.x, CONCRETE_BAY, JOINT_WIDTH),
			pavement_seam(on_ground.y, CONCRETE_BAY, JOINT_WIDTH));
		albedo *= 1.0 - wear * joints * CONCRETE_JOINT_DARK;
	}
	ALBEDO = albedo;
	ROUGHNESS = surface_roughness;
}
