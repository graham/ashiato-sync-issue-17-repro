// THE WALL OF SPRAY BEHIND A SEAPLANE SKIMMING FAST: one solid curtain of white water standing up behind the hull, several
// times its height, flat and bright on its face, crisp and billowing along its top in cartoon-cloud lobes, pale blue at
// its base and under each lobe (asked for on 2026-09-18 with a Porco Rosso still; SprayYard, WakeTuning's SHEET_*).
//
// A SHAPED SHEET, NOT PARTICLES. Every piece of wall is one instance of one MultiMesh, laid by SprayYard along the track
// where the craft met the water and never moved: this shader raises it from its age on the yard's clock `now`, so the
// wall fans up from the hull and stands behind it, and a frozen level freezes it.
//
// What an instance carries:
//   the transform       origin at the water where the NEWER end was laid; basis x across the track (a unit vector), y up,
//                       z the chord from the newer end to the OLDER end, so neighbouring pieces share an end exactly;
//   INSTANCE_CUSTOM     (when the newer end was laid, when the older end was, metres along the track at the newer end,
//                       how strongly the craft sprayed at the newer end);
//   COLOR               (how strongly at the older end, the craft's seed, the hull's half-width in metres, 0).
// The mesh is a strip across the track, x from -1 to 1 and z from -0.5 to 0.5 (the newer end to the older).
//
// ITS SHAPE IS A V ACROSS THE TRACK: from the keel line at the water, out and up to its top on each side. From the side
// one face is a wall, from behind both are seen, and each eye of a headset sees the same world-space sheet -- nothing
// here faces the eye. The top edge is a row of circles, the lobes, cut CRISP by the alpha scissor: the sheet is drawn
// opaque, so it sorts with the aircraft and the sea and costs no blending. It goes by being eaten into holes, not faded.
//
// LIT AS A CEL IS, by the rule the clouds use: a flat bright face toward the sun, a blue-grey shade at the base, in the
// lower crescent of each lobe, and on a face turned from it. The sun is the mist's own `mist_towards_sun`.
//
// PLACED THROUGH THE INSTANCE'S OWN TRANSFORM (billboard.gdshaderinc, BILLBOARD_LOCAL_OF), so it is steady far out on the
// double build. The eye is EYE_POSITION_WORLD, never the engine's.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
#include "res://world/shaders/terrain_noise.gdshaderinc"

uniform float now = 0.0;
// HANDED BY SprayYard FROM WakeTuning, once.
uniform float sheet_height = 13.0;
uniform float rise = 0.35;
uniform float life = 1.6;
uniform float dissolve = 0.45;
uniform float width = 3.0;
uniform float spread = 2.5;
uniform float lobe = 3.2;
uniform float billow = 0.5;
uniform float crisp = 0.04;
uniform float holes = 0.18;
uniform vec3 face_colour : source_color = vec3(0.97, 0.98, 1.0);
uniform vec3 shadow_colour : source_color = vec3(0.66, 0.80, 0.88);
uniform float base_share = 0.28;
uniform float lobe_shade = 0.55;
uniform float contact = 1.0;
uniform float contact_height = 0.45;
instance uniform vec3 light = vec3(1.0);

// HOW FAR BELOW THE STILL WATER THE KEEL LINE IS DRAWN, metres: the sea's chop never shows a gap under the wall.
const float SINK = 0.5;
// HOW STEEPLY THE V RISES FROM THE KEEL: 1 is a straight V, less is a wall that stands up and then leans out.
const float STEEP = 0.6;

varying float along;
varying float above;
varying float tall;
varying float aged;
varying float strength;
// FLAT: interpolated, a constant came back a few units in the last place different on every pixel, and the hash each
// lobe is drawn from turned that into a different lobe on every pixel -- the lobes were stippled like a screen print.
varying flat float seed;
varying vec3 facing;
varying vec4 mist_here;

void vertex() {
	float u = VERTEX.x;
	float v = VERTEX.z + 0.5;
	float laid = mix(INSTANCE_CUSTOM.r, INSTANCE_CUSTOM.g, v);
	aged = now - laid;
	strength = mix(INSTANCE_CUSTOM.a, COLOR.r, v);
	seed = COLOR.g;
	vec3 chord = MODEL_MATRIX[2].xyz;
	along = INSTANCE_CUSTOM.b - v * length(chord);
	if (aged < 0.0 || aged > life || strength <= 0.0) {
		VERTEX = vec3(0.0);
		above = 0.0;
		tall = 0.0;
		facing = vec3(0.0, 1.0, 0.0);
		mist_here = vec4(0.0);
	} else {
		vec3 across = normalize(MODEL_MATRIX[0].xyz);
		// RISEN TO ITS HEIGHT over `rise` seconds: the wall fans up from the hull.
		tall = sheet_height * strength * (1.0 - exp(-aged / rise));
		// ROOM ABOVE IT FOR THE LOBES, which the fragment cuts out of the strip.
		float top = tall + lobe * (1.0 + billow * aged) * 1.2;
		float opened = COLOR.b + width * strength + spread * aged;
		float a = max(abs(u), 0.001);
		float y = pow(a, STEEP) * top;
		vec3 off = across * u * opened + vec3(0.0, y - SINK, 0.0) + chord * v;
		above = y - SINK;
		// THE SHEET'S NORMAL, turned to the eye in the fragment's sums: a face seen is the face lit.
		vec3 up_the_face = across * sign(u) * opened + vec3(0.0, STEEP * pow(a, STEEP - 1.0) * top * sign(u), 0.0);
		vec3 normal = normalize(cross(up_the_face, chord));
		vec3 at = MODEL_MATRIX[3].xyz + off;
		facing = dot(normal, EYE_POSITION_WORLD - at) >= 0.0 ? normal : -normal;
		mist_here = mist_along(EYE_POSITION_WORLD, at, mist_clock);
		VERTEX = BILLBOARD_LOCAL_OF(off);
	}
}

// ONE LOBE OF THE WALL: a circle standing on the face, in metres along the track and up it. Row 0 is the top edge, whose
// circles ARE the edge; row 1 is a lower rank of billows drawn in front of it, as the still has them.
void lobe_of(float c, float row, float size, float seed_here, float tall_here, float grow, out float centre,
		out float base, out float r) {
	float r1 = hash21(vec2(c + row * 131.0, seed_here * 97.0));
	float r2 = hash21(vec2(c * 1.37 + 11.0 + row * 71.0, seed_here * 53.0));
	float r3 = hash21(vec2(c * 0.71 - 5.0 - row * 17.0, seed_here * 29.0));
	float r4 = hash21(vec2(c * 2.13 + 3.0 + row * 37.0, seed_here * 11.0));
	centre = (c + 0.5 + row * 0.5 + (r1 - 0.5) * 0.9) * size;
	// SIZES SPREAD WIDE, SMALL ONES COMMON, and now and then a big billow that stands out of the crest: all the same
	// size, the lobes read as a row of circles, not as the still's scalloped crest (team-lead, first pictures).
	r = size * (0.35 + 0.6 * r2 * r2 + (r4 > 0.8 ? 0.45 : 0.0)) * grow;
	base = row < 0.5 ? tall_here - r * (0.1 + 0.7 * r3) : tall_here * (0.4 + 0.25 * r3);
}

// WHERE ALONG THE TRACK THE LOBES ARE LAID OUT: the track bent by a slow noise, so they bunch and spread rather than
// standing at even intervals. Its slope stays above -1, so it never runs backwards.
float laid_along(float along_here, float size, float seed_here) {
	float wander = value_noise_wrapped(vec2(along_here / (size * 2.5), seed_here * 9.0), LATTICE_PERIOD) - 0.5;
	return along_here + wander * size * 1.2;
}

void fragment() {
	if (aged < 0.0 || aged > life || strength <= 0.0) {
		discard;
	}
	// THE LOBES: the top edge is the highest row-0 circle over this point. A point inside a lobe is LIT in the circle
	// raised by `lobe_shade` of its radius and SHADED in the crescent below that; row 1 is nearer, so it is asked first.
	float gone = smoothstep(life * (1.0 - dissolve), life, aged);
	float grow = (1.0 + billow * aged) * clamp(tall / max(sheet_height, 0.001) * 1.5, 0.35, 1.0);
	float sunk = gone * tall * 0.5;
	float rim = tall * 0.55 - sunk;
	float in_shade = 0.0;
	float decided = 0.0;
	for (int row = 1; row >= 0; row--) {
		float size = lobe * (row == 0 ? 1.0 : 0.75);
		float spaced = laid_along(along, size, seed + float(row));
		float cell = floor(spaced / size - float(row) * 0.5);
		for (int k = -3; k <= 3; k++) {
			float centre;
			float base;
			float r;
			lobe_of(cell + float(k), float(row), size, seed, tall, grow, centre, base, r);
			base -= sunk;
			vec2 p = vec2(spaced - centre, above - base);
			if (row == 0 && abs(p.x) < r) {
				rim = max(rim, base + sqrt(r * r - p.x * p.x));
			}
			if (decided < 0.5 && length(p) < r) {
				decided = 1.0;
				in_shade = step(r * 0.93, length(p - vec2(r * 0.12, r * lobe_shade)));
			}
		}
	}
	// CUT CRISP along the top edge; and eaten into holes high up, and everywhere as it goes.
	// NO fwidth IN IT: seen edge-on a pixel spans metres of `above`, a smoothstep that wide left half the far face at
	// alpha 0.5 against a 0.5 scissor, and it came out stippled like a screen print (round 2, picture from behind).
	float edge = 1.0 - smoothstep(rim - crisp, rim + crisp, above);
	float bite = value_noise_wrapped(vec2(along * 0.45, above * 0.45) + vec2(seed * 13.0, seed * 7.0), LATTICE_PERIOD);
	float ragged = holes * smoothstep(tall * 0.5, tall, above) + gone * 1.05;
	float kept = step(ragged, bite);
	ALPHA = edge * kept;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// THE SHADE AT THE BASE, in a wavering band; and a face turned from the sun, a little.
	float wave = value_noise_wrapped(vec2(along * 0.18, seed * 5.0), LATTICE_PERIOD);
	float base_line = tall * base_share * (0.6 + 0.8 * wave);
	in_shade = max(in_shade, 1.0 - step(base_line, above));
	float turned = 1.0 - smoothstep(-0.35, -0.1, dot(normalize(facing), mist_towards_sun));
	vec3 colour = mix(face_colour, shadow_colour, max(in_shade, turned * 0.6));
	// THE THIN WHITE LINE AT THE HULL, where the youngest wall meets the water.
	float line = contact * (1.0 - step(contact_height, above)) * (1.0 - smoothstep(0.1, 0.3, aged));
	colour = mix(colour, face_colour * 1.05, line);
	colour *= light;
	ALBEDO = mix(colour, mist_here.rgb, mist_here.a);
}
