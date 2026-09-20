// A LIGHT YOU CAN SEE FROM EIGHT KILOMETRES, which is not a light at all.
//
// An aeroplane four kilometres off is three grey pixels on a grey sky, and a runway from the
// circuit is a grey stripe on green. What makes both findable in life is the lights on them,
// and what makes a real light findable is that it does not get smaller with distance the way
// the thing it is on does: a point source stays a point. So each light here is a quad drawn
// round a point, and its radius is the LARGER of its real size and a fixed ANGLE -- the same
// trick the spotting boxes use, for the same reason, and this time without anybody having to
// press D.
//
// NOT A LIGHT IN THE ENGINE'S SENSE. Nothing is lit by it: an OmniLight per wingtip on a
// hundred aircraft was a slideshow on the Mobile renderer this was written for (untimed on
// Forward+, the renderer since 2026-09-14), and a nav light's whole job is to
// be SEEN, not to illuminate a wing. Unshaded, never fogged -- haze that swallowed a landing
// light would defeat the point -- and never shadowed.
//
// CORRECT IN BOTH EYES. The size and the PAPI colour are worked out from the light's place
// relative to the main view, whose eye is the midpoint of the eyes in stereo, so both eyes
// agree on how big a light is and what colour it shows. The quad faces each eye's own view,
// which is what the engine's own billboards do: a round glow looks the same from either.
//
// PLACED BY THE ENGINE'S OWN TRANSFORM, NOT BY `VIEW_MATRIX * centre`. A precision=double Godot
// works a model's origin out relative to the camera in emulated double precision and hands it
// over as MODELVIEW_MATRIX; VIEW_MATRIX and MODEL_MATRIX are float32 on either build. Until
// 2026-09-14 this shader took `skip_vertex_transform` and placed the dot at
// `VIEW_MATRIX * centre`, so on double, 9.46 km out, a runway light riding a still craft stepped
// on float32's grid on 58 of 90 frames (tests/shake_shot.gd) while a mesh beside it never moved.
// So the centre, the distance and the PAPI's height are read from MODELVIEW_MATRIX, and the
// quad is written back in the instance's own space -- the inverse of MODELVIEW's basis --
// for the engine's precise transform to place. `skip_vertex_transform` must not come back:
// with it, a double build bakes the multimesh instance into the model matrix and then applies
// it to MODELVIEW_MATRIX a second time (scene_forward_clustered.glsl), which is the other thing
// that was wrong. MODEL_MATRIX alone would be safe -- it bakes only the matrix handed to the
// shader -- but nothing here needs it.
//
// ONE MESH PER CRAFT, the pattern in the instance: INSTANCE_CUSTOM is
//   x  pattern -- 0 steady, 1 anticollision beacon, 2 strobe, 3 approach "rabbit", 4 PAPI
//   y  phase, 0..1, so two aircraft do not flash in step
//   z  how many times the least angle this light holds (a strobe is bigger than a nav light)
//   w  for a PAPI, the glideslope angle in degrees at which it turns from red to white
// and the colour in the instance colour. The flashing is TIME, here, so a hundred flashing
// aircraft cost the processor nothing at all.
//
// PLAIN and FINE are this file with and without `#define FINE`. Plain is a hard, opaque,
// steady dot with the strobes and the rabbit dark. FINE is two passes: the same opaque dot, in
// the same colour, a third larger, with the strobes and the rabbit flashing (beacon_fine); and a
// blended halo round it that the flashing brightens and that never covers the dot
// (beacon_halo, drawn as the fine material's next pass). See `flash` for why a beacon is never
// dark, and beacon_fine.gdshader for the measurement that made the core opaque.

// Radius, in radians, below which no light shrinks. 0.0016 rad is a little under a tenth of
// a degree: about two pixels of radius at the twenty pixels a degree a headset or this
// project's desktop window shows -- before `size_scale`, which halves it.
uniform float least_angle = 0.0016;
// HALF THE SIZE THEY WERE, asked for on 2026-09-12: every light, on both finishes, aircraft and
// runway alike. Applied once to the radius -- its real size and the least angle both -- so the
// FINE core's third and the halo's reach stay in proportion to it.
uniform float size_scale = 0.5;
// AND DIMMER WITH DISTANCE, asked for the same day. A light holds its least angle however far off
// it is, which is what makes it findable, and it also kept its full brightness, which made a far
// airfield or a sky full of traffic a spray of bright dots as loud as the nearest one. Full
// brightness out to `dim_from` metres, easing to `far_bright` of it by `dim_to`.
uniform float dim_from = 300.0;
uniform float dim_to = 5000.0;
uniform float far_bright = 0.35;
// HOW MUCH OF ITS LEAST ANGLE A LIGHT STILL HOLDS BY `dim_to`, 0..1, eased over the same distance as the brightness.
// 1 keeps a far light a dot of fixed size, which is how an aeroplane is found at night -- and what made a far one by
// day a bright dot: "the lights on planes are still too bright in the daytime, dim them at distance more"
// (2026-09-13). A light near enough to be seen as part of an aeroplane is inside `dim_from` and keeps its size. Set
// per time of day by VehicleLights.show_daylight; 1 on the runway.
uniform float far_least = 1.0;
// THE LEAST ANGLE'S OWN SCALE, apart from `size_scale`, so a set of lights can be made smaller without vanishing at
// range as fast. Equal to `size_scale` on the runway, which is the sum as it was; a little over it on an aircraft.
uniform float least_scale = 0.5;
// HOW BRIGHT BY THE TIME OF DAY, 0..1, set once per change (VehicleLights.show_daylight): an aircraft's lights by day
// are small coloured points and at night as bright as ever. Core and halo alike. 1 on the runway.
uniform float daylight = 1.0;
// THE DITHERED RIM, as a share of the dot's radius: pixels in that outer band are discarded by a hash of their cell in
// the dot's own frame and the light's phase -- so the edge is soft, the same in both eyes, and still in a still frame,
// because nothing in it is TIME or FRAGCOORD. Set per finish by VehicleLights; 0 on the runway.
uniform float rim_dither = 0.0;
// HOW MUCH LARGER THE FINE CORE IS THAN THE PLAIN DOT, and the halo with it so it stays off the core: 1.35 on the
// runway (see the FINE branch below), larger on an aircraft, whose dot is smaller and dimmer by day. Set by VehicleLights.
uniform float fine_core = 1.35;

varying vec3 tint;
varying vec2 corner;
varying float lit;
// How bright this light is for its distance, 1 near and `far_bright` far. See `dim_from`.
varying float bright;
// The light's phase, which keys its rim dither so two lights side by side do not share one pattern. FLAT: the rim's
// hash multiplies a sine by 43758, and an ordinary varying hands a constant back only to about one part in ten million,
// pixel to pixel and moving with the view -- which is what turned the windows' hash into flicker (8054cd0).
varying flat float seed;
#ifdef HALO
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;
#endif
#ifdef FINE
// How far through its flash a flashing light is, 0..1. See `beat`.
varying float pulse;
#endif

float flash(float pattern, float phase, float t) {
#ifdef FINE
	if (pattern < 0.5 || pattern > 3.5) {
		return 1.0;
	}
	if (pattern < 1.5) {
		// ANTICOLLISION: ALWAYS DRAWN, and the flash is on top of it -- see `beat`. It used to
		// be dark between flashes, which is four frames in five, and the first render check
		// (2026-09-12, traffic and runway views) found the plain finish's steady red dots far
		// easier to find than this one's: the flash was costing the light its one job.
		return 1.0;
	}
	if (pattern < 2.5) {
		// STROBE: the double flash every airliner has, twice in quick succession every 1.2 s.
		float c = fract(t / 1.2 + phase) * 1.2;
		return step(c, 0.05) + step(0.15, c) * step(c, 0.20);
	}
	// THE RABBIT: approach strobes firing in sequence towards the threshold, twice a second.
	// Phase is the light's place in the line, outermost first.
	float c = fract(t * 2.0 - phase * 0.5);
	return step(c, 0.06);
#else
	// Plain: everything steady, and the lights whose whole character is flashing stay dark
	// rather than pretending to be nav lights.
	return (pattern > 1.5 && pattern < 3.5) ? 0.0 : 1.0;
#endif
}

#ifdef FINE
// THE FLASH OF A FLASHING LIGHT, as a brightening on top of a light that is there anyway: the
// anticollision beacon beats once a second with a short fade, strobes and the rabbit are their
// own flash, and a steady light never beats.
float beat(float pattern, float phase, float t) {
	if (pattern > 0.5 && pattern < 1.5) {
		return 1.0 - smoothstep(0.08, 0.24, fract(t + phase));
	}
	return (pattern > 1.5 && pattern < 3.5) ? 1.0 : 0.0;
}
#endif

void vertex() {
	// The light's centre in view space, from the engine's camera-relative transform: exact on double. See the header.
	vec3 centre_view = MODELVIEW_MATRIX[3].xyz;
	// Its real size: the view's rotation keeps a column's length, so this is the instance's scale.
	float physical = length(MODELVIEW_MATRIX[0].xyz);
	float away = length(centre_view);
	float fade = smoothstep(dim_from, dim_to, away);
	float radius = max(physical * size_scale,
		away * least_angle * max(INSTANCE_CUSTOM.z, 0.1) * least_scale * mix(1.0, far_least, fade));
	bright = mix(1.0, far_bright, fade) * daylight;
	seed = INSTANCE_CUSTOM.y;
	lit = flash(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.y, TIME);
#ifdef FINE
	pulse = beat(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.y, TIME);
#endif
	tint = COLOR.rgb;
	if (INSTANCE_CUSTOM.x > 3.5) {
		// PAPI: red below its angle, white above, judged from where the pilot's head is.
		// The eye's height over the light is minus the light's world-space offset from the eye, turned out of view space.
		float above = degrees(asin(clamp(-(transpose(mat3(VIEW_MATRIX)) * centre_view).y / max(away, 1.0),
			-1.0, 1.0)));
		tint = mix(vec3(1.0, 0.10, 0.06), vec3(1.0, 0.97, 0.90),
			smoothstep(INSTANCE_CUSTOM.w - 0.06, INSTANCE_CUSTOM.w + 0.06, above));
	}
#ifdef HALO
	// THE HALO PASS is drawn well outside the core, and kept off it -- see the fragment.
	// Scaled with the core, so the core still reaches about 0.52 of this quad and the halo's 0.50..0.58 edge stays off it.
	radius *= 2.6 * fine_core / 1.35;
#else
#ifdef FINE
	// THE FINE CORE IS THE PLAIN DOT, A THIRD LARGER, and in exactly the plain colour. Larger
	// because the fine finish multisamples, which softens a dot's edge pixels into the sky. A fifth
	// was measured short (render_check_4, 2026-09-12): the core colour matched PLAIN on every view,
	// but on the base-leg view, lights at about 1.5 km, FINE gave 7.16 red pixels a light against
	// PLAIN's 8.05 and 8.49 -- a shortfall beyond that view's own run-to-run spread.
	radius *= fine_core;
#endif
#endif
	// A light that is off costs no pixels at all.
	radius *= step(0.001, lit);
	corner = VERTEX.xy;
	// PULLED TOWARDS THE EYE by its own radius, so a light grown to ten metres across at range
	// does not sink halfway into the wing it is mounted on -- but never past half the way to
	// the eye, or a light close up would jump in front of the canopy frame.
	float depth = length(centre_view);
	vec3 offset_view = -normalize(centre_view) * min(radius, depth * 0.5) + vec3(corner * radius, 0.0);
	// Back into the instance's own space, for the engine's transform to add to the precise centre. A light whose radius is 0
	// (switched off) collapses to its centre, as it did.
#ifdef HALO
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz, mist_clock);
#endif
	VERTEX = inverse(mat3(MODELVIEW_MATRIX)) * offset_view;
}

void fragment() {
	float r = length(corner);
#ifdef HALO
	// THE HALO ONLY, round a core the opaque pass has already drawn. The core reaches 1.35 / 2.6 of
	// this quad, about 0.52, and the halo is kept outside it: a blended halo over the core is a
	// core that is not the light's colour any more. The flash brightens and whitens the halo only.
	float halo = pow(max(1.0 - r, 0.0), 2.0) * (0.22 + 0.58 * pulse);
	ALBEDO = mix(tint, vec3(1.0), 0.40 * pulse);
	ALPHA = clamp(halo * lit * smoothstep(0.50, 0.58, r) * bright, 0.0, 1.0) * (1.0 - mist_here.a);
#else
	// The rim thinned by a hash of the cell -- six to a radius, in the dot's own frame -- so the edge dithers away.
	float rim_hash = fract(sin(dot(floor(corner * 6.0) + vec2(seed * 17.0, seed * 5.0), vec2(12.9898, 78.233)))
		* 43758.5453);
	if (r > 1.0 - rim_dither * rim_hash) {
		discard;
	}
	// Dimmer the further off it is, in its own colour: unshaded, so this is the light's brightness.
	ALBEDO = tint * bright;
#endif
}
