// THE GROUND AS GROUNDVIEW DRAWS IT, lit a pixel at a time from a normal map baked for each cell (world/ground_view.gd).
//
// PER-PIXEL NORMALS, NOT PER-VERTEX. Normals worked out at the vertices and interpolated across a 32 m or 64 m quad drew
// steep faces as vertical fluting, light and shade streaked down every face (team-lead's picture point 2). Each cell
// carries a map of the function's normal, as fine as its level can show -- 65 texels a side at 16 m and 32 m, 33 at 64 m,
// 17 at 128 m -- each texel the function's normal a texel either side.
//
// THE GROUND FUNCTION ITSELF IN THIS SHADER was measured and rejected: a 19-lookup stand-in for it, a lower bound, cost
// 5.73 to 6.04 ms GPU-bound at 3840x2141 against the map's 2.76 to 2.87 and the vertex normals' 2.77 to 2.87 (double
// editor, PLAIN, two passes), and the real function -- integer, warped, with lakes and flattened sites -- cannot be
// written in float32 at all.
//
// THE COLOURS ARE sRGB vertex colours, converted here as the StandardMaterial3D this replaces converted them with
// `vertex_color_is_srgb`. Read as linear -- that material's default -- a 0.26 green drew as 0.55 and the pale rock and
// meadow near white: the first picture of this layer on the double editor was a white range with pale green lowland
// (godotgames-drafts/2026-09-14/cockpit-terrain/ground_view).
//
// THE FLOOR UNDER THE WOODS (increment B4): the forest floor the island's grass paints, from the same eight rectangles
// (forest_floor.gdshaderinc), set on every cell's material by GroundView. Without its uniforms a cell draws no floor.
shader_type spatial;
render_mode cull_back;

#include "res://world/shaders/forest_floor.gdshaderinc"

// Linear, not `hint_normal`: the map is plain RGB8 made at run time, read straight back as a direction.
uniform sampler2D normal_map : filter_linear, repeat_disable;
// A level's tint for the probe's `_levels` pictures; white draws the ground as it is.
uniform vec3 tint = vec3(1.0);

// The map's side and its texel, metres, which the level decides (GroundView.texel_metres): texel k's middle is
// k * texel_metres from the cell's corner.
uniform float texels = 65.0;
uniform float texel_metres = 16.0;

varying vec2 map_uv;
varying vec2 world_xz;

vec3 linear_from_srgb(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	map_uv = (VERTEX.xz / texel_metres + 0.5) / texels;
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 up = normalize(texture(normal_map, map_uv).rgb * 2.0 - 1.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz);
	vec3 albedo = linear_from_srgb(COLOR.rgb) * tint;
	ALBEDO = mix(albedo, floor_colour, forest_floor(world_xz) * floor_strength);
	ROUGHNESS = 0.95;
}
