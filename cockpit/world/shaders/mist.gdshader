// THE LOW MIST PASS: one quad over the whole view, drawn after everything opaque and before anything else transparent, taking
// away and putting back what `mist_along` (mist.gdshaderinc) says the mist between the eye and each pixel's surface does.
//
// WHERE THE SURFACE IS: the depth buffer, turned back into a point in the world through the inverse projection and
// VIEW_MATRIX -- not INV_VIEW_MATRIX, whose translation the double build overwrites (world/shaders/eye.gdshaderinc). A pixel
// of sky has nothing in the depth buffer (reverse Z clears it to 0), and its ray is taken `sky_reach` metres out, where the
// slab has long been left.
//
// IN A HEADSET, reasoned from Godot 4.7's multiview path and not yet seen in one (agents.md has the check for the user):
//   - EACH EYE ITS OWN RAY. The quad is drawn once a view by the multiview pass; POSITION puts it straight into that view's
//     clip space, so it covers each eye whole and no near plane can clip it as the head moves. SCREEN_UV, the depth sample,
//     INV_PROJECTION_MATRIX and VIEW_MATRIX are all that view's own, and nothing here assumes one eye.
//   - THE EYE IS THE MIDPOINT, THE DIRECTION IS EACH EYE'S. EYE_POSITION_WORLD is the midpoint of the eyes (the engine puts each
//     eye's offset in its projection), and a surface point rebuilt through this view's projection and VIEW_MATRIX is that
//     eye's point in the world. So each eye integrates from the midpoint to the point it actually sees: a centimetre-scale
//     difference in where the ray starts, the same field in the world for both, and no pattern that belongs to one eye.
//   - DEPTH UNDER MSAA: `hint_depth_texture` is the resolved depth the engine copies for transparent passes, one sample a
//     pixel, so an edge pixel is misted as its resolved surface. FINE has two samples; what that does at a silhouette in a
//     headset is on the list to look at.
//
// ON BOTH FINISHES: a headset starts PLAIN, and PLAIN takes one step (`steps`).
shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

#include "res://world/shaders/mist.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float sky_reach = 40000.0;

void vertex() {
	// THE WHOLE VIEW, EACH EYE'S OWN: a 2 by 2 quad put straight into clip space at the near plane (reverse Z).
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec3 eye = EYE_POSITION_WORLD;
	mat3 to_world = transpose(mat3(VIEW_MATRIX));
	vec3 surface;
	if (depth <= 0.0) {
		vec4 near = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
		surface = eye + to_world * normalize(near.xyz / near.w) * sky_reach;
	} else {
		vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		surface = to_world * (view.xyz / view.w - VIEW_MATRIX[3].xyz);
	}
	vec4 mist = mist_along(eye, surface, mist_clock);
	ALBEDO = mist.rgb;
	ALPHA = mist.a;
}
