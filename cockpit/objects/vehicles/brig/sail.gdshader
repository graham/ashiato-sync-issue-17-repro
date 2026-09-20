shader_type spatial;
// ## A SAIL: canvas that bellies with the wind in it and shivers when it has none.
//
// OPAQUE, and drawn from both faces. A sail in a period rig is heavy canvas you cannot see through, so it goes in the
// opaque pass with no mist include and no sorting, and one sheet is seen from windward and from leeward alike.
//
// THE BELLY IS A VERTEX PUSH ALONG THE SAIL'S OWN NORMAL, by `fill` -- how much the simulation's sail is pulling, 0 to 1,
// carried by the ship's replicated rigging -- shaped so the four corners stay where the yard, the sheets and the mast
// hold them: sin(pi u) along the yard and a belly that is deepest a third of the way down. `leeward` is +1 or -1, which
// face the wind is pushing towards, worked out on the CPU from the apparent wind; the canvas always bellies downwind,
// aback or not (aback, it is pressed back against the mast, which is still downwind).
//
// LUFFING is the same push, small and travelling: under a quarter full the leech shivers, and it stops as the sail fills.
// TIME drives it and nothing else, because a shiver is not physics and no two machines need to agree on its phase.
//
// UV: u runs 0..1 along the head (the yard, or the foot of a fore-and-aft sail), v runs 0 at the head to 1 at the foot.
// `triangle` narrows the head to a point for a jib.

render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 canvas : source_color = vec3(0.86, 0.82, 0.72);
uniform float depth = 1.6;
// THE SHEET'S SIZE in metres, width along u and height down v, for the belly's slope: the push alone moved the canvas
// and left every normal flat, so a full sail was lit as a card and read from astern as a white slab (the first "before"
// pictures). The slope of the push is turned into the normal it bends.
uniform vec2 sheet_size = vec2(10.0, 8.0);
// 1 for a square sail hung forward of a mast at the middle of its yard, 0 for a sail whose luff is its mast or stay.
uniform float mast_notch = 0.0;
// A FLAG rather than a sail: nothing holds its fly, so the ripple grows from the pole to the free edge and never stops.
uniform bool flag = false;
instance uniform float fill = 0.0;
instance uniform float leeward = 1.0;
instance uniform float luff = 0.0;

void vertex() {
	float u = UV.x;
	float v = UV.y;
	// AN IF AND AN ELSE, NOT AN EARLY RETURN: Godot's shader compiler refuses `return` in `vertex()` ("SHADER ERROR: Using
	// 'return' in the 'vertex' processor function is incorrect"), and the gate fails on a SHADER ERROR.
	if (flag) {
		VERTEX.z += luff * 0.45 * u * sin(TIME * 9.0 - u * 7.0 + v * 1.5);
		VERTEX.y -= (1.0 - luff) * 0.6 * u * u;
	} else {
		float across = sin(3.14159 * u);
		// Deepest a third of the way down, and still some at the foot.
		float phase = 3.14159 * clamp(v * 0.85 + 0.08, 0.0, 1.0);
		float down = sin(phase) * (1.0 - 0.25 * v);
		float belly = across * down;
		float full = clamp(fill, 0.0, 1.0);
		// PRESSED AFT, A SQUARE SAIL LIES AGAINST ITS MAST, not through it: an aft belly (leeward > 0, towards the mast behind
		// the sheet) is shallower and notched to nothing where the mast stands, at the middle of the yard.
		float aft = step(0.0, leeward);
		float notch = mix(1.0, smoothstep(0.03, 0.14, abs(u - 0.5)), aft * mast_notch);
		belly *= notch * mix(1.0, 0.45, aft * mast_notch);
		float push = leeward * depth * belly * full;
		// The shiver: a travelling ripple down the leech, fading out as the sail fills.
		float shiver = luff * 0.25 * sin(TIME * 11.0 + u * 9.0 + v * 4.0) * across;
		VERTEX += NORMAL * (push + shiver);
		// THE BENT NORMAL: the push's slope along the sheet (u runs +X over the width, v runs -Y down the height), taken
		// off the flat normal so a bellied sail is lit round, not flat.
		float d_du = leeward * depth * full * 3.14159 * cos(3.14159 * u) * down;
		float d_dv = leeward * depth * full * across
			* (cos(phase) * 3.14159 * 0.85 * (1.0 - 0.25 * v) - 0.25 * sin(phase));
		vec3 slope = vec3(d_du / max(sheet_size.x, 0.1), -d_dv / max(sheet_size.y, 0.1), 0.0);
		NORMAL = normalize(NORMAL - slope);
	}
}

void fragment() {
	// A little darker where the canvas is seamed, so a sail reads as cloths and not as a card.
	float seam = smoothstep(0.46, 0.5, abs(fract(UV.x * 7.0) - 0.5));
	ALBEDO = canvas * (0.93 + 0.07 * (1.0 - seam));
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
	BACKLIGHT = canvas * 0.35;
}
