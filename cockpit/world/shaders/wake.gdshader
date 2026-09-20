// A SHIP'S WAKE, ASTERN: churned white water behind the stern and the Kelvin wedge of wave marks either side of it, lying
// on the sea and aged on the GPU. See WakeYard, which lays a piece of it behind every moving hull every half second and
// never touches it again, and research/wakes.md for what a real wake looks like.
//
// EVERY PIECE OF EVERY WAKE IS ONE INSTANCE OF ONE MULTIMESH, as a contrail's segments are (contrail.gdshader): how wide it
// has spread and how far it has faded is worked out here from how old each end is, so an old wake costs the processor
// nothing. A piece older than its wake's life collapses to a point and draws nothing -- a wake is hundreds of metres wide
// when it dies, and drawing it at alpha 0 would be hundreds of metres of blended pixels for nothing.
//
// What an instance carries:
//   the transform's X column   the piece, from its older end to its newer end, level, in metres;
//   the transform's Y column   straight up, as long as the ship is (its length, metres);
//   the transform's Z column   level and square to X, as long as the ship is wide (its beam, metres);
//   the transform's origin     the piece's midpoint, on the still water there;
//   INSTANCE_CUSTOM            (when the older end was laid, when the newer end was, on the yard's clock `now`; and which way
//                              is ACROSS the track at the older end and at the newer, as an angle from world +x toward +z);
//   COLOR                      (the older end's speed and strength, packed as floor(speed x 64) + strength; the newer end's
//                              the same way; how far the ship had gone when the older end was laid, metres, wrapped at
//                              `track_wrap`; which wake, 0 to 1 -- NEGATIVE for a streak, the line a craft skimming the
//                              water draws with nothing of it in the water, which has a churn and no Kelvin waves).
//
// ACROSS AT EACH END, NOT ACROSS THE PIECE. Two neighbouring pieces meet at one point and are told the same across there --
// the ship's track at the moment it was laid -- so their shared edge is one line however the ship turns. Each piece squared
// to its OWN chord fanned out on a turn: at the carrier's 117 m arms a half-degree between pieces was a metre of gap on one
// side and a metre of double-drawn overlap on the other, every half second, and the wedge read as a venetian blind (first
// pictures, 2026-09-17). Speeds are per end for the same reason: the arms' width steps where the speed does.
//
// WHAT IS DRAWN, at each pixel, from its distance off the track and how long ago the ship was there:
//   THE CHURN: white, as wide as the hull at the stern and spreading, with ragged edges; a solid boil for the first
//   seconds, then lace -- veins and patches of foam drawn out along the track -- thinning to nothing by `churn_share` of
//   the wake's life, and a faint lighter slick that outlasts it.
//   THE KELVIN ARMS: a band at the edge of the wedge, whose half-width is (ship length + distance run since) x tan 19.47 --
//   measured from the STEM, where the V starts, so the arms leave the bow quad (wake_bow.gdshader) where it hands over --
//   drawn as short crests and troughs square to the divergent waves' 35.26 degree travel: lighter and darker marks.
//   THE TRANSVERSE WAVES: faint arcs across the inside of the V, 2 pi v^2 / g apart.
// Every stripe fades out where a pixel is too coarse to hold it, so a far wake is a soft V and never a moire.
//
// HOW LONG A WAKE LASTS is its ship's length times `life_per_metre`, between `life_least` and `life_most`: the sum
// `WakeTuning.wake_life` does, handed its three numbers, so the drawer and the tests read one rule.
//
// PLACED ON THE SEA the sea is drawn with: each vertex asks `sea_height_at` (sea_surface.gdshaderinc) and stands `lift`
// over it, and is pulled `pull` metres toward the eye, so the wake never fights the water for a depth.
//
// No TIME but the sea's own (the swell under it moves with TIME, as the sea's does); the wake's age is on the yard's clock.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
#include "res://world/shaders/terrain_noise.gdshaderinc"
#include "res://world/shaders/sea_surface.gdshaderinc"

varying vec4 mist_here;
// The yard's clock, set once a frame by WakeYard.
uniform float now = 0.0;
// EVERY LOOK NUMBER IS HANDED BY WakeYard FROM WakeTuning, once, so the defaults here are only what a shader preview shows.
uniform float kelvin_tan = 0.3536;
uniform float churn_spread = 0.35;
uniform float churn_share = 0.7;
uniform float whiteness = 0.9;
uniform float arm_strength = 0.3;
uniform float arm_width = 0.08;
uniform float transverse_strength = 0.1;
uniform float lift = 0.06;
uniform float pull = 0.35;
uniform float track_wrap = 4096.0;
uniform float life_per_metre = 0.35;
uniform float life_least = 14.0;
uniform float life_most = 110.0;
// A SKIM STREAK'S LIFE AND LEAST WIDTH: the short foam scar under a craft skimming the water, not a wake.
uniform float streak_life = 1.2;
uniform float streak_width = 3.0;
uniform vec3 foam_colour : source_color = vec3(0.86, 0.90, 0.92);
uniform vec3 shade_colour : source_color = vec3(0.004, 0.02, 0.035);
// PER NODE, written once per change of the time of day: the light the wake is drawn in (ContrailYard.light_at).
instance uniform vec3 light = vec3(1.0);

varying float age_here;
varying float off_track;
varying float half_wedge;
varying float along_track;
varying float strength;
varying float speed;
varying float ship;
varying float beam;
varying float life;
varying float seed;
varying float waves;

void vertex() {
	vec3 along = MODEL_MATRIX[0].xyz;
	float piece = max(length(along), 0.0001);
	vec3 forward = along / piece;
	ship = length(MODEL_MATRIX[1].xyz);
	beam = length(MODEL_MATRIX[2].xyz);
	seed = abs(COLOR.a);
	waves = COLOR.a < 0.0 ? 0.0 : 1.0;
	// A STREAK LASTS A MOMENT and is at least `streak_width` wide: drawn as a hull's wake, a light aeroplane's 1.4 m
	// fuselage left a hard grey line fourteen seconds long behind it, "like a laser" (team-lead, pictures 05).
	life = waves > 0.5 ? clamp(ship * life_per_metre, life_least, life_most) : streak_life;
	beam = waves > 0.5 ? beam : max(beam, streak_width);
	float t = VERTEX.x + 0.5;
	float laid = mix(INSTANCE_CUSTOM.r, INSTANCE_CUSTOM.g, t);
	age_here = max(now - laid, 0.0);
	if (now - INSTANCE_CUSTOM.g > life || INSTANCE_CUSTOM.g < -1000.0) {
		// DEAD, OR NEVER LAID: every vertex on the origin, which draws nothing.
		VERTEX = vec3(0.0);
		strength = 0.0;
		speed = 0.0;
		off_track = 0.0;
		half_wedge = 1.0;
		along_track = 0.0;
		mist_here = vec4(0.0);
	} else {
		strength = mix(fract(COLOR.r), fract(COLOR.g), t);
		speed = mix(floor(COLOR.r), floor(COLOR.g), t) / 64.0;
		half_wedge = max((ship + speed * age_here) * kelvin_tan, beam * 0.5);
		// A LITTLE PAST THE ARM, so the arm's band has room to fade out inside the ribbon; a streak has no arms, and is
		// drawn only as wide as its churn can spread.
		float drawn_half = waves > 0.5 ? half_wedge * (1.0 + arm_width * 0.8) + 1.0 : beam * 1.5 + churn_spread * age_here;
		off_track = VERTEX.y * 2.0 * drawn_half;
		along_track = COLOR.b + t * piece;
		float turned = mix(INSTANCE_CUSTOM.b, INSTANCE_CUSTOM.b + atan(sin(INSTANCE_CUSTOM.a - INSTANCE_CUSTOM.b),
			cos(INSTANCE_CUSTOM.a - INSTANCE_CUSTOM.b)), t);
		vec3 side = vec3(cos(turned), 0.0, sin(turned));
		// TWO AND A HALF MILLIMETRES PAST EACH END, so neighbouring pieces overlap by a hair: placed from two midpoints,
		// their shared edge rounds two ways, and without it drew a dotted crack of sea across the churn at every join. Two
		// centimetres of overlap drew a bright double-blended line there instead (pictures 1 and 2, 2026-09-17).
		vec3 off = forward * (VERTEX.x * (piece + 0.005)) + side * off_track;
		vec3 world = MODEL_MATRIX[3].xyz + off;
		off.y += sea_height_at(world.xz, EYE_POSITION_WORLD, TIME) + lift;
		vec3 to_eye = BILLBOARD_EYE - off;
		off += normalize(to_eye) * min(pull, length(to_eye) * 0.5);
		mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + off, mist_clock);
		VERTEX = BILLBOARD_LOCAL_OF(off);
	}
}

// A STRIPE THAT FADES WHERE THE PIXEL CANNOT HOLD IT: 0.5 + 0.5 sin, drawn toward 0.5 as `metres_a_pixel` nears half its
// wavelength.
float stripe(float phase, float wavelength, float metres_a_pixel) {
	float held = 1.0 - smoothstep(0.25, 0.5, metres_a_pixel / max(wavelength, 0.0001));
	return 0.5 + 0.5 * sin(phase * 6.28318) * held;
}

void fragment() {
	if (strength <= 0.0) {
		discard;
	}
	float x = abs(off_track);
	float pixel = max(length(vec2(dFdx(along_track), dFdy(along_track))), length(vec2(dFdx(off_track), dFdy(off_track))));
	float s = mod(along_track, track_wrap);
	float gone = clamp(age_here / life, 0.0, 1.0);
	// How much of the fine noise a pixel can hold: none where a pixel is wider than the noise's cell.
	float held_fine = 1.0 - smoothstep(0.15, 0.5, pixel);

	// THE CHURN. As wide as the hull at the stern and a little wider as it spreads, with ragged edges; solid white boil
	// for the first seconds, then lace -- veins and patches of foam drawn out along the track -- thinning to nothing.
	float ragged = fbm2_wrapped(vec2(s * 0.04 + seed * 9.0, sign(off_track) * 3.0), LATTICE_PERIOD);
	float churn_half = beam * 0.5 * (0.75 + 0.2 * sqrt(age_here)) + churn_spread * age_here;
	float share = x / churn_half * (0.8 + 0.45 * ragged);
	float profile = exp(-2.2 * share * share);
	float streaks = fbm2_wrapped(vec2(off_track * 0.6 + seed * 17.0, s * 0.12), LATTICE_PERIOD);
	float grain = mix(0.5, value_noise_wrapped(vec2(off_track * 2.0 - seed * 5.0, s * 0.6), LATTICE_PERIOD), held_fine);
	float n = streaks * 0.7 + grain * 0.3;
	float veins = 1.0 - smoothstep(0.0, 0.09, abs(n - 0.5));
	float patches = smoothstep(0.52, 0.62, n);
	float churned = clamp(age_here / (life * churn_share), 0.0, 1.0);
	// A STREAK IS LACE FROM THE START: a solid boil under a skimmer was the hard line.
	float boil = exp(-age_here / 3.0) * waves;
	float lace = mix(max(veins * 0.85, patches), veins * 0.6, churned);
	float white = whiteness * profile * mix(lace, 1.0, boil) * (1.0 - churned) * (1.0 - churned);
	// THE SLICK: the smoothed water the churn leaves, a faintly lighter band that outlasts the foam.
	float slick = 0.10 * exp(-0.9 * share * share) * (1.0 - gone) * (1.0 - boil);

	// THE KELVIN ARMS: a narrow band at the wedge's edge, drawn as short crests and troughs square to the divergent
	// waves' 35.26 degree travel -- the echelon of marks either side of a ship's track, lighter on the crests and
	// darker in the troughs.
	float wavelength = max(6.28318 * speed * speed / 9.81, 1.5);
	// NEVER LONGER THAN HALF THE HULL: a launch at 12 m/s would otherwise draw three crests down its whole wake, and
	// a small fast hull's divergent waves are short (the high-Froude narrowing, research/wakes.md).
	float diverging_length = clamp(wavelength * 0.667, 1.5, ship * 0.5 + 2.0);
	float band = max(half_wedge * arm_width, 1.0);
	float into_arm = (half_wedge - x) / band;
	float arm = smoothstep(-0.25, 0.15, into_arm) * (1.0 - smoothstep(0.35, 1.0, into_arm));
	float diverging = stripe((s * 0.8165 + x * 0.5774) / diverging_length + seed, diverging_length, pixel);
	float arms_left = (1.0 - gone) * (1.0 - gone) * waves;
	// ONE LINE OF SHORT CRESTS: the arm is a continuous lighter line along its whole length, brighter on each crest and
	// shaded between. Drawn as crests alone, the arms read as separate white dashes along the V (team-lead, 01 and 04).
	float along_arm = 0.25 + 0.75 * pow(diverging, 3.0);
	float arm_light = arm * along_arm * arm_strength * 0.75 * arms_left;
	float arm_dark = arm * pow(1.0 - diverging, 3.0) * arm_strength * 0.5 * arms_left;
	// A LITTLE FOAM ON THE ARM'S CRESTS while it is young.
	arm_light += arm * pow(diverging, 8.0) * patches * exp(-age_here / 6.0) * arm_strength * 0.8 * waves;

	// THE TRANSVERSE WAVES, curving back toward the arms, faint, inside the V and outside the churn.
	float wedge_share = clamp(x / half_wedge, 0.0, 1.0);
	float across = stripe((s + wedge_share * wedge_share * wavelength * 0.8) / wavelength, wavelength, pixel) - 0.5;
	float inside = (1.0 - smoothstep(0.55, 0.95, wedge_share)) * (1.0 - profile);
	// FADED IN OVER HALF A WAVELENGTH ASTERN: started at full strength at the stern, the first trough drew a hard-edged dark
	// box behind the tanker's hull (team-lead, picture 04; found by colouring the troughs red).
	float astern = smoothstep(0.0, wavelength * 0.5, speed * age_here);
	float transverse = across * 2.0 * transverse_strength * inside * arms_left * astern;

	float lighter = clamp(white + slick + arm_light + max(transverse, 0.0), 0.0, 1.0);
	float darker = clamp(arm_dark + max(-transverse, 0.0), 0.0, 1.0) * (1.0 - lighter);
	float alpha = clamp((lighter + darker) * strength, 0.0, 1.0);
	vec3 colour = mix(shade_colour, foam_colour, lighter / max(lighter + darker, 0.0001)) * light;
	ALBEDO = mix(colour, mist_here.rgb, mist_here.a);
	ALPHA = alpha;
}
