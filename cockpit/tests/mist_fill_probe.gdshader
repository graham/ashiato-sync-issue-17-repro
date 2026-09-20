// A PRICING PROBE, NOT THE MIST: the mist pass's quad with its render mode and nothing else -- no depth read, no mist -- so the
// fill and the blend of a full-screen transparent quad can be priced apart from the depth copy the real pass reads
// (MistLayer `--mist-pass=fill`, team-lead's split, 2026-09-15). Never drawn by a level unless asked for on the command line.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
