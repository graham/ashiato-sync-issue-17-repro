// A SHIP'S BOW WAVE AND THE WHITE WATER ALONG ITS SIDES: one level quad under every moving hull, from a little ahead of the
// stem to the stern, placed every frame by WakeYard. The wake astern (wake.gdshader) takes over at the stern.
//
// What an instance carries:
//   the transform's X column   the ship's heading, level, as long as the ship (metres);
//   the transform's Y column   straight up, as long as the ship is wide (its beam, metres);
//   the transform's Z column   level and square to X, one metre long when the hull has a drawn waterline outline to
//                              keep foam out from under, a centimetre when it is one box (the tanker, an aeroplane);
//   the transform's origin     midships, on the still water there;
//   INSTANCE_CUSTOM            (the ship's speed in m/s, how strongly it wakes 0 to 1, which ship, how far the ship has gone,
//                              metres, wrapped at `track_wrap` -- so the Kelvin arms' crests run on into the wake's).
//
// WHAT IS DRAWN: a hull-shaped hole, which the hull itself covers and which keeps foam off a low deck; white water piled at
// the stem and thrown out to the sides, thinning along the hull and building again at the stern quarter; a moustache of
// foam just ahead of the stem; and the Kelvin arms starting at the stem at 19.47 degrees, as the wake draws them.
//
// Placed on the sea as the wake is (sea_surface.gdshaderinc), `lift` over it and `pull` toward the eye.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
#include "res://world/shaders/terrain_noise.gdshaderinc"
#include "res://world/shaders/sea_surface.gdshaderinc"

varying vec4 mist_here;
// The yard's clock, set once a frame by WakeYard: the foam at the bow boils on it.
uniform float now = 0.0;
// HANDED BY WakeYard FROM WakeTuning, once.
uniform float kelvin_tan = 0.3536;
uniform float whiteness = 0.9;
uniform float bow_strength = 0.85;
uniform float arm_strength = 0.55;
uniform float arm_width = 0.22;
uniform float lift = 0.06;
uniform float pull = 0.35;
uniform float track_wrap = 4096.0;
uniform vec3 foam_colour : source_color = vec3(0.86, 0.90, 0.92);
uniform vec3 shade_colour : source_color = vec3(0.004, 0.02, 0.035);
instance uniform vec3 light = vec3(1.0);

// How far ahead of the stem the quad reaches, as a share of the ship's length.
const float AHEAD = 0.12;

varying float aft;
varying float off_track;
varying float ship;
varying float beam;
varying float speed;
varying float strength;
varying float seed;
varying float track;
// 1 where a hole is kept under the hull, 0 for a hull drawn as one box.
varying float holed;
// Where on the quad, 0 to 1 from the stern and -1 to 1 across: for fading out before its edges.
varying float along_share;
varying float across_share;

void vertex() {
	vec3 heading = MODEL_MATRIX[0].xyz;
	ship = max(length(heading), 0.001);
	vec3 forward = heading / ship;
	beam = length(MODEL_MATRIX[1].xyz);
	speed = INSTANCE_CUSTOM.r;
	strength = INSTANCE_CUSTOM.g;
	seed = INSTANCE_CUSTOM.b;
	track = INSTANCE_CUSTOM.a;
	holed = length(MODEL_MATRIX[2].xyz) > 0.5 ? 1.0 : 0.0;
	if (strength <= 0.0) {
		VERTEX = vec3(0.0);
		aft = 0.0;
		off_track = 0.0;
		along_share = 0.0;
		across_share = 0.0;
		mist_here = vec4(0.0);
	} else {
		float ahead = mix(-ship * 0.5, ship * (0.5 + AHEAD), VERTEX.x + 0.5);
		aft = ship * 0.5 - ahead;
		along_share = VERTEX.x + 0.5;
		across_share = VERTEX.y * 2.0;
		float half_across = max(ship * kelvin_tan * (1.0 + arm_width * 0.6), beam * 1.3);
		off_track = VERTEX.y * 2.0 * half_across;
		vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
		vec3 off = forward * ahead + side * off_track;
		vec3 world = MODEL_MATRIX[3].xyz + off;
		off.y += sea_height_at(world.xz, EYE_POSITION_WORLD, TIME) + lift;
		vec3 to_eye = BILLBOARD_EYE - off;
		off += normalize(to_eye) * min(pull, length(to_eye) * 0.5);
		mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + off, mist_clock);
		VERTEX = BILLBOARD_LOCAL_OF(off);
	}
}

float stripe(float phase, float wavelength, float metres_a_pixel) {
	float held = 1.0 - smoothstep(0.25, 0.5, metres_a_pixel / max(wavelength, 0.0001));
	return 0.5 + 0.5 * sin(phase * 6.28318) * held;
}

void fragment() {
	if (strength <= 0.0) {
		discard;
	}
	float x = abs(off_track);
	float d = aft;
	// THE HULL'S HALF-BEAM at this station: fine at the stem, full by a fifth of the way aft.
	float hull = beam * 0.5 * sqrt(clamp(d / (0.2 * ship), 0.0, 1.0));
	// UNDER THE HULL, NOTHING -- faded in, never cut. A hard cut-out of the whole hull box showed on the tanker as a dark
	// box behind its hull, where the box runs on past the part of the hull in the water (team-lead, picture 04; the same
	// frame with no wake drawn had no box). The last seventh of the hull is left open, where the churn starts.
	// ONLY UNDER A HULL WITH A WATERLINE OUTLINE: the tanker's hull is one box, longer than the part of it in the water.
	float under_hull = holed > 0.5 && d > 0.0 && d < ship * 0.85 ? 1.0 - smoothstep(hull * 0.55, hull * 0.95, x) : 0.0;
	if (under_hull >= 0.999) {
		discard;
	}
	float out_from = max(x - hull, 0.0);
	float pixel = max(length(vec2(dFdx(aft), dFdy(aft))), length(vec2(dFdx(off_track), dFdy(off_track))));
	float s = mod(track + (ship - d), track_wrap);
	float fast = smoothstep(1.0, 12.0, speed);
	// THE WATER BOILS: the noise drifts aft past the hull, which is the water moving past it.
	float froth = fbm2_wrapped(vec2(off_track * 0.6 + seed * 13.0, s * 0.12 + now * 0.5), LATTICE_PERIOD);
	float lace = smoothstep(0.4, 0.6, froth);
	// THE BOW WAVE: a ridge of white thrown off the stem, standing out from the hull by `reach` and running aft along
	// it for a quarter of the ship, the faster the further.
	float reach = (0.4 + beam * 0.1) * (0.5 + fast);
	float pile = exp(-max(d, 0.0) / max(0.12 * ship * (0.5 + fast), 0.5));
	float ridge = exp(-pow((out_from - reach * 0.4) / reach, 2.0) * 2.0);
	float bow = pile * ridge * (0.6 + 0.4 * lace);
	// White water along the sides and building again at the stern quarter, thin.
	float side_wash = d > 0.0 && d < ship ? 0.3 * exp(-out_from / (reach * 0.4)) * (0.4 + 0.6 * lace) * fast : 0.0;
	float quarter = 0.6 * exp(-pow((ship - d) / max(0.1 * ship, 0.5), 2.0)) * exp(-out_from / reach) * lace;
	// A MOUSTACHE just ahead of the stem.
	float moustache = d < 0.0 ? exp(d / max(0.015 * ship, 0.3)) * exp(-x / max(beam * 0.25, 0.3)) : 0.0;
	float white = whiteness * bow_strength * clamp(bow + side_wash + quarter + moustache, 0.0, 1.0);

	// THE KELVIN ARMS FROM THE STEM, as the wake draws them astern.
	float wavelength = max(6.28318 * speed * speed / 9.81, 1.5);
	float diverging_length = clamp(wavelength * 0.667, 1.5, ship * 0.5 + 2.0);
	float half_wedge = max(d, 0.0) * kelvin_tan;
	float band = max(half_wedge * arm_width, 1.0);
	float into_arm = (half_wedge - x) / band;
	float arm = d > 0.0 ? smoothstep(-0.25, 0.15, into_arm) * (1.0 - smoothstep(0.35, 1.0, into_arm)) : 0.0;
	// NOT AGAINST THE HULL: there the bow wave is the white water, and the arm's troughs drew a dark box round a small hull.
	arm *= smoothstep(0.1 * ship, 0.35 * ship, d) * smoothstep(hull + 1.0, hull + 3.0, x);
	float diverging = stripe((s * 0.8165 + x * 0.5774) / diverging_length + seed, diverging_length, pixel);
	// ONE LINE OF SHORT CRESTS, as wake.gdshader draws the arm astern.
	float arm_light = arm * (0.25 + 0.75 * pow(diverging, 3.0)) * arm_strength * 0.75;
	float arm_dark = arm * pow(1.0 - diverging, 3.0) * arm_strength * 0.5;

	// NOTHING REACHES THE QUAD'S EDGES, so the quad is never seen as one.
	float inside = (1.0 - smoothstep(0.85, 1.0, abs(across_share))) * smoothstep(0.0, 0.05, 1.0 - along_share)
		* (1.0 - under_hull);
	float lighter = clamp(white + arm_light, 0.0, 1.0) * inside;
	float darker = clamp(arm_dark, 0.0, 1.0) * (1.0 - lighter) * inside;
	vec3 colour = mix(shade_colour, foam_colour, lighter / max(lighter + darker, 0.0001)) * light;
	ALBEDO = mix(colour, mist_here.rgb, mist_here.a);
	ALPHA = clamp((lighter + darker) * strength, 0.0, 1.0);
}
