// RIVETED ARMOUR PANEL: seams, rivets and panel-to-panel tone, computed in metres from the object's own vertices.
//
// THE WHOLE HANGAR IS ONE WELDED MESH WITH ONE MATERIAL (see SkyfrontHangar and Plating), so the paint is in the
// vertices: COLOR.rgb is the tint AS sRGB, exactly as every ship colour in this project is written, and COLOR.a is HOW
// MUCH PANEL DETAIL that surface takes -- 1.0 a riveted armour panel, about 0.35 a structural member, 0.0 painted
// markings and railings, which have no seams in them.
//
// NO TEXTURE AND NO UVs. `Plating` welds quads with a colour and a normal and nothing else, and the concept sheet's
// panels are a fixed size in metres: a 10 m wall must carry 10 m worth of rivets, not the same four that a 2 m cabinet
// carries. So the grid comes from OBJECT SPACE -- the vertex position, projected onto the plane the face points out of --
// which is the same trick `building.gdshaderinc` uses for the town's windows, and for the same reason.
//
// EVERY EDGE IS RAMPED OVER A PIXEL, and detail too small to draw is not drawn: past the range where a seam is about a
// pixel across, the seams and rivets fade into what the panel AVERAGES to rather than switching off. A hard edge a pixel
// or two wide flickers as the head moves, which is most of what the town's windows had to be cured of (agents.md, "Why
// the windows flickered"); in a headset that flicker is at eye level and unmissable.
//
// THERE IS NO PLAIN/FINE PAIR, unlike `building.gdshader` and `building_fine.gdshader`. The reason those are two files is
// that a town is a FIELD of buildings with a far-range light handover in it; this is ONE building, and the only range
// behaviour it needs -- the fade above -- is already in this file and costs nothing when it has faded. Do not add a
// second file by analogy with the town.

shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// A panel of armour, metres across and up. Measured off the concept sheet's wall bays.
uniform float panel_wide = 2.5;
uniform float panel_tall = 2.4;
// Half the width of the seam between two panels, metres.
uniform float seam_half = 0.035;
// How dark a seam is, and how much of the tone a panel varies by, panel to panel.
uniform float seam_shade = 0.62;
uniform float panel_variation = 0.05;
// Rivets: how far apart along a seam, and how wide, metres.
uniform float rivet_pitch = 0.5;
uniform float rivet_radius = 0.045;
// The warm orange of a weathered rivet, sampled from the concept sheet.
uniform vec3 rivet_tint = vec3(0.70, 0.45, 0.16);
// The least a seam may span on screen, in pixels, before the detail hands itself over to the panel's average tone.
uniform float detail_pixels_least = 1.6;
uniform float roughness_panel = 0.82;
uniform float metallic_panel = 0.10;

varying vec3 panel_point;
varying vec3 panel_normal;

// sRGB to linear, because the tint in the vertices was chosen as sRGB: `StandardMaterial3D.vertex_color_is_srgb` does
// this for every other mesh here, and without it a haze grey comes out near white (ship_hull.gd, `painted`).
vec3 from_srgb(vec3 c) {
	return mix(c / 12.92, pow((c + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float hash21(vec2 at) {
	return fract(sin(dot(at, vec2(41.7, 289.1))) * 43758.5453);
}

void vertex() {
	panel_point = VERTEX;
	panel_normal = NORMAL;
}

void fragment() {
	vec3 tint = from_srgb(COLOR.rgb);
	float detail = COLOR.a;
	// WHICH TWO METRES ACROSS THE FACE: the axes the face does not point along, so a wall is measured along and up it
	// and a roof slope across and down it. A sloped roof face is dominated by y, which is why the ends are compared.
	vec3 n = abs(panel_normal);
	vec2 across = n.y >= max(n.x, n.z) ? panel_point.xz : (n.x >= n.z ? panel_point.zy : panel_point.xy);
	vec2 cell = across / vec2(panel_wide, panel_tall);
	// Distance in metres to the nearest seam line, along each axis.
	vec2 to_seam = abs(fract(cell) - 0.5) * vec2(panel_wide, panel_tall);
	vec2 from_edge = vec2(panel_wide, panel_tall) * 0.5 - to_seam;
	// A PIXEL IS A SIZE ON SCREEN, not a distance: it arrives larger at range and at a grazing angle.
	float pixel = max(max(fwidth(across.x), fwidth(across.y)), 1e-6);
	float visible = detail * smoothstep(0.0, 1.0, (seam_half * 2.0 / pixel) / detail_pixels_least - 1.0);
	// The seam itself, ramped over one pixel.
	float seam = max(1.0 - smoothstep(seam_half - pixel, seam_half + pixel, from_edge.x),
		1.0 - smoothstep(seam_half - pixel, seam_half + pixel, from_edge.y));
	// RIVETS SIT ON THE SEAMS, at a fixed pitch along them, as they do on the sheet.
	vec2 along = across / rivet_pitch;
	vec2 to_rivet = abs(fract(along) - 0.5) * rivet_pitch;
	float rivet = max(
		(1.0 - smoothstep(rivet_radius - pixel, rivet_radius + pixel, max(from_edge.x, to_rivet.y))),
		(1.0 - smoothstep(rivet_radius - pixel, rivet_radius + pixel, max(from_edge.y, to_rivet.x))));
	// PANEL TO PANEL TONE, flat within one panel so nothing moves inside it: weathering, and the thing that keeps a
	// 40 m wall from reading as one slab.
	float shade = 1.0 + (hash21(floor(cell) + vec2(7.0, 3.0)) - 0.5) * 2.0 * panel_variation * detail;
	vec3 albedo = tint * shade;
	albedo = mix(albedo, albedo * seam_shade, seam * visible);
	albedo = mix(albedo, from_srgb(rivet_tint), rivet * visible * 0.85);
	// AND WHAT IT AVERAGES TO once the detail is too small to draw: a seam and its rivets are darker than the panel, so
	// a wall of them settles to a slightly deeper tone instead of to the bare panel colour.
	float faded = detail * (1.0 - visible);
	albedo *= 1.0 - 0.06 * faded;
	ALBEDO = albedo;
	ROUGHNESS = mix(0.55, roughness_panel, detail);
	METALLIC = mix(0.25, metallic_panel, detail);
}
