// A CLOUD PUFF, ITS BODY, for both of its shaders: one transparent ellipsoid of cloud, drawn as the air it holds rather than
// as a surface. A PROTOTYPE (lane/clouds2, 2026-09-17) beside LiftYard's lumps, for the user to choose from; see
// research/clouds_2.md.
//
// WHAT IT IS. Every pixel the puff covers is a ray from the eye, and the ray's OPTICAL DEPTH through the ellipsoid is worked
// out exactly, in closed form -- no raymarch. The density is highest at the middle and falls to nothing at the skin,
// rho = 1 - r^2 in the puff's own unit sphere, so the integral along the chord is a cubic in the ray parameter and the edge
// is soft by construction: a ray that grazes the puff crosses almost no cloud. The alpha is Beer's law of it,
// 1 - exp(-depth). THREE THINGS FALL OUT OF THAT FOR FREE:
//
//   OVERLAPPING PUFFS NEED NO SORTING. Two layers of alpha a1 and a2 cover 1 - (1 - a1)(1 - a2) = 1 - exp(-(d1 + d2)) in
//   either order, so a heap of puffs is one volume of summed depth wherever they overlap, and no puff's skin shows through
//   another's. Only the colour depends on the order, and the colours of one cloud are close.
//
//   FLYING IN IS FLYING IN. The mesh is drawn by its BACK faces (cull_front), so every pixel inside the puff's outline has
//   exactly one fragment whether the eye is outside or inside it, and the chord starts at the eye once the eye is inside.
//   Nothing is ever near the near plane, so nothing is clipped or pops; the view goes white as the depth in front of the
//   eye grows, and clears as it shrinks.
//
//   A SOFT MEETING WITH THE WORLD. Depth test is off; instead the chord is cut where the depth buffer's surface is, so a
//   mountain inside a cloud, or an aeroplane inside it, is fogged by exactly the cloud in front of it, and a cloud's foot
//   in a hillside fades into it. The depth copy is the one the mist pass already reads on both finishes.
//
// ONE FLAT BASE A CLOUD: the chord is also cut at the cloud's base height (INSTANCE_CUSTOM.r), so a heap of round puffs
// has a level floor, as a cumulus has at its condensation level.
//
// BOTH EYES. The ray is each eye's own: VERTEX is in view space and the eye is EYE_OFFSET there (zero on a desktop), so the
// two eyes see one ellipsoid in the world from where each of them is -- a solid, not a picture. The noise is sampled in the
// world. Nothing reads SCREEN_UV except the depth buffer, which is the same eye's own. MODELVIEW_MATRIX is used without
// skip_vertex_transform, which on the double build is the precise, emulated-double transform (billboard.gdshaderinc).
//
// INSTANCE_CUSTOM: r the cloud's base height in the world, g the cloud's thickness, b a seed, a the core density per metre.
// TWO SHADERS, ONE BODY. puff.gdshader cuts each chord at the depth buffer's surface (CUT_AT_THE_WORLD), with the depth test
// off; puff_depth_tested.gdshader reads no depth texture and lets the engine's depth test hide the back faces behind the world
// instead, which loses a cloud's far half behind a hill and fogs nothing in front of an aeroplane inside it -- kept to price
// the depth copy against, since on PLAIN nothing else reads the depth texture (tests/lint.gd).

#include "res://world/shaders/eye.gdshaderinc"
#include "res://world/shaders/air_noise.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"

#ifdef CUT_AT_THE_WORLD
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
#endif

// THE LIGHT, written by the sky from its sun. Every colour below is a share of these three, so dawn, evening and night
// light the cloud as they light the rest of the world.
uniform vec3 towards_sun = vec3(0.42, 0.57, 0.71);
uniform vec3 sun_light : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 sky_light : source_color = vec3(0.56, 0.64, 0.78);
uniform vec3 base_light : source_color = vec3(0.42, 0.45, 0.52);
// How much of the sun a point takes, and how far into a puff the sun is lost (per metre of core density).
uniform float sun_share = 1.05;
uniform float sun_extinction = 0.12;
// How much of the cloud's round reach its own shadow is taken through: the cloud is lit as the sphere of its reach, and a
// towering cumulus is much less than that sphere, so at 1 its sunlit flank was lost in its own shadow (clouds3's first
// pictures, the flanks at a third of the crown's light). 0.8 since the user asked for "darker bluer" shade (step 2).
uniform float shadow_depth = 0.8;
// The share of the sun that still arrives deep in the cloud's shadow, scattered many times. At clouds2's 0.55 every lobe
// of a backlit heap kept a bright crescent on its top, a froth of outlined bubbles (clouds3's first backlit wall); at
// 0.3 the shadowed flanks were the sun's light dimmed, a neutral grey, where the user asked for "darker bluer" (step 2).
const float SCATTER_FLOOR = 0.15;
// THE LONGEST SHADOW A CLOUD CASTS ON ITSELF, in metres of its reach: the cloud is lit as the sphere of its reach, and a
// towering cumulus's reach is its height, so a tower 2 km tall lost every face to its own shadow, crown and all (clouds3's
// walls, found by drawing the sun's share as green: 0 over every tower, 0.9 over the heaps beside them).
const float SHADOW_MOST = 600.0;
// THE SILVER LINING: the thin edges seen against the sun glow, by the Henyey-Greenstein phase of the sun's light scattered
// forward through them; `lining_g` is how forward (0 all ways alike, 0.9 a tight glow about the sun).
uniform float lining = 0.9;
uniform float lining_g = 0.6;
// THE TEXTURE (clouds3, 2026-09-18). ONE WORLD NOISE AT THE SKIN THE EYE SEES, with its gradient worked out alongside it
// (value noise's analytic derivative, one lookup's hashes), does three jobs: it scallops the puff's outline into lobes, it
// bends the skin's normal so every lobe has its own lit side and shaded side, and it thins the depth inside for the
// fly-through. `noise_cell` is the metres a lobe is; FINE adds an octave of lobes on the lobes.
uniform float noise_cell = 90.0;
uniform float noise_thin = 0.5;
// How much of the whole the density profile keeps at the skin, for a crisper puff (0 is the softest).
uniform float firm = 0.0;
// CRISPNESS: the half-width, in the puff's radius, of the band its outline fades across -- 0.02 is a cut edge, 0.3 smoke.
uniform float crisp = 0.08;
// How deep the lobes bite into the outline, in the puff's radius (0 a plain ellipse).
uniform float bump = 0.22;
// How steep the lobes stand out of the skin to the light: the lobes' height over their width.
uniform float lobe_relief = 0.9;
// How much more opaque the body is than its depth alone makes it, seen from outside: cumulus reads as a solid with a crisp
// edge from a distance. It goes back to the depth alone as the eye comes within `near_soft` metres, so a cloud you fly
// into is still the air it was.
uniform float body = 3.0;
uniform vec2 near_soft = vec2(40.0, 200.0);
// Where the skin the eye sees lies, as a share of the puff's radius: the density has built up by then.
uniform float skin = 0.8;
// How much the noise thins the depth close to and inside, where it is the whole texture of the fly-through (clouds2's).
const float NEAR_THIN = 0.85;
// How high over the base the foot's shade reaches, at most.
const float FOOT_METRES = 300.0;
// How dark the cloud's base is against its crown, 0 to 1: a thick cloud's base is lit only by the ground and the haze.
uniform float base_shade = 0.4;
// THE SHADE. The side away from the sun is lit by the sky alone, and the sky is blue: `shade_colour` tints the sky's light
// on it (a blue-grey, never a neutral grey), `shade_light` is how bright it is against the sunlit side.
uniform vec3 shade_colour : source_color = vec3(0.8, 0.95, 1.0);
uniform float shade_light = 0.8;
// THE TERMINATOR: the half-width, in the cosine of the sun's angle, of the band from lit to shade (0.05 inked, 0.6 soft).
uniform float terminator = 0.22;
// THE CROWN: how much brighter the sunlit top is than the sunlit foot.
uniform float top_bright = 1.25;
// A sheet (stratocumulus, altocumulus, cirrus) is lit by height alone; a heap by where in the heap a point is.
uniform bool flat_layer = false;
// How much of a point's light is its own puff's modelling rather than its cloud's: the florets of a heap.
uniform float puff_modelling = 0.6;
// COLOR.a's metres: the instance colour is eight bits, so the reach is carried as a share of this.
uniform float reach_unit = 5000.0;
// THE FINISH: FINE takes three octaves of world noise and a finer one over them, PLAIN one octave (`PuffSky.wear`).
uniform bool fine = true;
// HOW FAR THE PUFFS HOLDING THE EYE HAVE GIVEN WAY to the level's whiteout, 0 to 1 (`PuffSky.show_eye_in_cloud`): deep in a
// cloud every puff holding the eye covers both eyes, and the depth fog does the same work for nothing.
uniform float eye_gone = 0.0;

varying vec3 local_at;
varying flat vec3 local_eye;
varying vec3 world_at;
varying flat float base_local;
varying flat float base_world;
varying flat float thickness;
varying flat float seed;
varying flat float density;
varying flat vec3 origin;
varying flat vec3 cloud_at;
varying flat float cloud_reach;
// THE MIST BETWEEN THE EYE AND THE PUFF, once a vertex (mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;
// THE PUFF'S OWN TURN AND SCALE, for the fragment: in fragment() MODEL_MATRIX is the batch's, without the instance's
// transform, so the skin's normal and the point's place in its cloud came out turned by each puff's random yaw -- lit sides
// facing every way (clouds3, found by drawing the lit share as a colour on the wall picture).
varying flat vec3 puff_x;
varying flat vec3 puff_y;
varying flat vec3 puff_z;
// Whether the eye is inside this puff, 1 or 0: the same for every vertex of it.
varying flat float holds_eye;

void vertex() {
	mat4 to_local = inverse(MODELVIEW_MATRIX);
	local_eye = (to_local * vec4(EYE_OFFSET, 1.0)).xyz;
	local_at = VERTEX;
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	puff_x = MODEL_MATRIX[0].xyz;
	puff_y = MODEL_MATRIX[1].xyz;
	puff_z = MODEL_MATRIX[2].xyz;
	base_world = INSTANCE_CUSTOM.r;
	thickness = max(INSTANCE_CUSTOM.g, 1.0);
	seed = INSTANCE_CUSTOM.b;
	density = INSTANCE_CUSTOM.a;
	// Where this puff sits in its cloud, in the cloud's reach, and the reach in metres (COLOR.a in REACH_UNIT).
	cloud_at = COLOR.rgb;
	cloud_reach = max(COLOR.a * reach_unit, 1.0);
	// The base plane in the puff's own space: puffs are only turned about the vertical, so height maps through the y scale.
	base_local = (base_world - origin.y) / max(length(MODEL_MATRIX[1].xyz), 0.001);
	holds_eye = dot(local_eye, local_eye) < 1.0 && local_eye.y >= base_local ? 1.0 : 0.0;
	mist_here = mist_along(EYE_POSITION_WORLD, world_at, mist_clock);
}

// The integral of (1 - |o + t d|^2) dt from 0 to t, with a = d.d, b = o.d, c = o.o - 1: -c t - b t^2 - a t^3 / 3.
float profile_integral(float t, float a, float b, float c) {
	return -c * t - b * t * t - a * t * t * t / 3.0;
}

// VALUE NOISE AND ITS GRADIENT, from the same hash and fade as air_noise's value_noise3 (Inigo Quilez, "value noise
// derivatives", 2008): x the value 0 to 1, yzw its gradient per unit of p. Eight hashes, the same as the value alone.
vec4 value_noise3_d(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	vec3 du = 6.0 * f * (1.0 - f);
	float va = hash31(cell);
	float vb = hash31(cell + vec3(1.0, 0.0, 0.0));
	float vc = hash31(cell + vec3(0.0, 1.0, 0.0));
	float vd = hash31(cell + vec3(1.0, 1.0, 0.0));
	float ve = hash31(cell + vec3(0.0, 0.0, 1.0));
	float vf = hash31(cell + vec3(1.0, 0.0, 1.0));
	float vg = hash31(cell + vec3(0.0, 1.0, 1.0));
	float vh = hash31(cell + vec3(1.0, 1.0, 1.0));
	float k1 = vb - va;
	float k2 = vc - va;
	float k3 = ve - va;
	float k4 = va - vb - vc + vd;
	float k5 = va - vc - ve + vg;
	float k6 = va - vb - ve + vf;
	float k7 = -va + vb + vc - vd + ve - vf - vg + vh;
	float value = va + k1 * u.x + k2 * u.y + k3 * u.z + k4 * u.x * u.y + k5 * u.y * u.z + k6 * u.z * u.x
		+ k7 * u.x * u.y * u.z;
	vec3 slope = du * vec3(k1 + k4 * u.y + k6 * u.z + k7 * u.y * u.z, k2 + k5 * u.z + k4 * u.x + k7 * u.z * u.x,
		k3 + k6 * u.x + k5 * u.y + k7 * u.x * u.y);
	return vec4(value, slope);
}

// The span [t0, t1] of the ray o + t d inside the unit sphere and above the local base plane, or t1 < t0 if none.
vec2 inside_span(vec3 o, vec3 d, float floor_y) {
	float a = dot(d, d);
	float b = dot(o, d);
	float c = dot(o, o) - 1.0;
	float disc = b * b - a * c;
	if (disc <= 0.0) {
		return vec2(1.0, 0.0);
	}
	float s = sqrt(disc);
	vec2 span = vec2((-b - s) / a, (-b + s) / a);
	if (abs(d.y) > 1e-6) {
		float cross_t = (floor_y - o.y) / d.y;
		if (d.y > 0.0) {
			span.x = max(span.x, cross_t);
		} else {
			span.y = min(span.y, cross_t);
		}
	} else if (o.y < floor_y) {
		return vec2(1.0, 0.0);
	}
	return span;
}

void fragment() {
	// GIVEN WAY: a puff holding the eye, deep in its cloud, is the level's whiteout now. Before any of the sums.
	if (holds_eye * eye_gone > 0.999) {
		discard;
	}
	// THE RAY, this eye's, in view space: from the eye to this back-face point is t = 0 to 1.
	vec3 eye_view = EYE_OFFSET;
	vec3 ray_view = VERTEX - eye_view;
	float metres = length(ray_view);
	vec3 o = local_eye;
	vec3 d = local_at - local_eye;
	vec2 span = inside_span(o, d, base_local);
	span.x = max(span.x, 0.0);
	// THE WORLD IN FRONT: the depth buffer's surface on this pixel, as a t on the same ray. Reverse Z: 0 is the sky.
#ifdef CUT_AT_THE_WORLD
	float depth = texture(depth_texture, SCREEN_UV).r;
	if (depth > 0.0) {
		vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		vec3 surface = scene.xyz / scene.w;
		float along = (surface.z - eye_view.z) / min(ray_view.z, -1e-4);
		span.y = min(span.y, along);
	}
#endif
	if (span.y <= span.x) {
		discard;
	}
	float a = dot(d, d);
	float b = dot(o, d);
	float c = dot(o, o) - 1.0;
	float soft = profile_integral(span.y, a, b, c) - profile_integral(span.x, a, b, c);
	float hard = span.y - span.x;
	// Per unit t that is `metres` in the world, and the profile's core is 1.
	float optical = mix(soft, hard, firm) * metres * density;

	vec3 eye_world = EYE_POSITION_WORLD;

	// THE SKIN THE EYE SEES: where the ray first comes within `skin` of the puff's middle, or its closest approach if it
	// never does; or the flat base, where the ray comes up through it. Lit there, and not at the middle of the chord, a
	// puff has a lit side and a shaded side with a line between them, as a cauliflower lobe has.
	float t_close = -b / a;
	float r2_close = max(dot(o, o) - b * b / a, 0.0);
	float t_skin = t_close - sqrt(max(skin * skin - r2_close, 0.0) / a);
	float t_seen = clamp(t_skin, span.x, span.y);
	// FAR, 0 close to or inside, 1 from outside: the body, the crisp lobed outline, the skin's light and the terminator are
	// all things a cloud has from outside, and from inside it is the even grey-white it always was. Close to, the skins of
	// the puffs round the eye showed as shells, and from inside a puff the skin behind the eye drew a line across the view
	// where the ray's nearest point to the middle passes behind it (clouds3's first fly-through pictures). So close to, the
	// light is the chord's middle's, as it was.
	float t_middle = (span.x + span.y) * 0.5;
	float far = smoothstep(near_soft.x, near_soft.y, distance(eye_world, mix(eye_world, world_at, t_middle)))
		* (1.0 - holds_eye) * step(1.0, dot(o, o));
	t_seen = mix(t_middle, t_seen, far);
	vec3 seen_local = o + d * t_seen;
	vec3 seen_world = mix(eye_world, world_at, t_seen);
	bool on_base = seen_local.y < base_local + 0.02 && d.y > 0.0;

	// THE LOBES: one noise at the seen skin, and its gradient, per metre of the world, so both eyes see one shape.
	vec3 q = seen_world / noise_cell + vec3(seed * 17.0, 0.0, seed * 5.0);
	vec4 lobes = value_noise3_d(q);
	if (fine) {
		vec4 small = value_noise3_d(q * 2.31 + vec3(3.7, 1.3, 5.9));
		lobes = vec4(lobes.x * 0.65 + small.x * 0.35, lobes.yzw * 0.65 + small.yzw * (0.35 * 2.31));
	}
	float grain = lobes.x;

	// THE OUTLINE, scalloped: the puff's edge is a level set of how near the ray comes to its middle, bitten in where the
	// noise is low, and faded across `crisp`. A puff holding the eye has no outline to be inside.
	// FAR, 0 close to or inside, 1 from outside: the body, the crisp lobed outline and the terminator are all things a cloud
	// has from outside, and from inside it is the even grey-white it always was. Close to, the crisp outlines of the puffs
	// round the eye showed as shells (clouds3's first fly-through pictures).
	float edge = 1.0 - bump * (1.0 - grain);
	float cover = mix(1.0, 1.0 - smoothstep(edge - crisp, edge + crisp, sqrt(r2_close)), far);
	// THE BODY: opaque from outside, the depth alone from close to, so flying in is the fade it always was.
	float gain = mix(1.0, body, far);
	optical *= mix(1.0, grain * 2.0, mix(NEAR_THIN, noise_thin, far));
	float alpha = (1.0 - exp(-optical * gain)) * cover * (1.0 - holds_eye * eye_gone);
	if (alpha < 0.002) {
		discard;
	}

	// THE LIGHT, OF THE CLOUD AND OF THE LOBE. The point is placed in its CLOUD -- the puff's offset from the cloud's middle
	// in the cloud's reach (COLOR, from `PuffSky.show_clouds`) plus this point's offset in the puff, never normalised, so the
	// middle of the cloud has no direction -- for how much of the cloud lies between it and the sun, and for the cloud's
	// broad roundness. The puff's own skin normal, bent by the lobes, gives the florets their terminator. Lighting each puff
	// as its own sphere ALONE read as a heap of balls (clouds2's first pictures); the cloud's shadow is what stops that.
	mat3 puff_turn = mat3(puff_x, puff_y, puff_z);
	vec3 in_cloud = (cloud_at * 2.0 - 1.0) + (puff_turn * seen_local) / cloud_reach;
	if (flat_layer) {
		in_cloud.xz = vec2(0.0);
	}
	float out_of_middle = length(in_cloud);
	if (out_of_middle > 1.0) {
		in_cloud /= out_of_middle;
	}
	float rise = clamp((seen_world.y - base_world) / thickness, 0.0, 1.0);
	float sb = dot(in_cloud, towards_sun);
	float sc = dot(in_cloud, in_cloud) - 1.0;
	float sun_metres = (-sb + sqrt(max(sb * sb - sc, 0.0))) * (flat_layer ? thickness * 0.5 : min(cloud_reach * shadow_depth, SHADOW_MOST));
	float sun_reach = max(exp(-sun_metres * density * sun_extinction), SCATTER_FLOOR * exp(-sun_metres * density * sun_extinction * 0.2));

	// The ellipsoid's normal: the unit sphere's through the inverse transpose, which for a scaled and turned sphere is the
	// turn times position over scale squared. Shortened towards the puff's middle, which has no direction.
	vec3 scale = vec3(length(puff_x), length(puff_y), length(puff_z));
	vec3 puff_normal = puff_turn * (seen_local / (scale * scale));
	puff_normal = puff_normal / max(length(puff_normal), 1e-6) * min(length(seen_local) / skin, 1.0);
	if (flat_layer) {
		puff_normal.xz *= 0.4;
	}
	// A SHEET takes a quarter of a heap's modelling: lit as its own flat ellipsoid, every puff of an altocumulus deck had a
	// lit rim round a shaded middle, and the deck read as bubble wrap (clouds3, step 4).
	float modelling = puff_modelling * far * (flat_layer ? 0.25 : 1.0);
	vec3 normal = puff_normal * modelling + in_cloud * (1.0 - modelling);
	// THE FLAT BASE faces down, a heap's; a sheet's puffs each cut at the deck's base drew a dark disc apiece, with the lit
	// side of the puff as a rim round it, and a deck from below was bubble wrap (clouds3, step 4). A sheet's underside is
	// darkened by `foot` alone.
	if (on_base && !flat_layer) {
		normal = vec3(0.0, -1.0, 0.0);
	}
	// The lobes lean the normal down their slope: the gradient's part along the skin, per lobe width, times the relief.
	vec3 slope = lobes.yzw * (lobe_relief * far * 0.5);
	float roundness = length(normal);
	vec3 facing = normal / max(roundness, 1e-4);
	normal = facing - (slope - facing * dot(slope, facing));
	normal = normal / max(length(normal), 1e-4) * max(roundness, 0.2);

	float cosine = dot(normal, towards_sun);
	float soft_line = mix(1.0, terminator, far);
	float lit = smoothstep(-soft_line, soft_line, cosine);
	// The crown: brighter the higher it is. The foot: darker towards the base, and the base darkest.
	float crown = mix(1.0, top_bright, smoothstep(0.35, 1.0, rise));
	// Only the foot: over a tower's whole lower half it greyed the sunlit flank (clouds3's first wall pictures).
	float above_base = seen_world.y - base_world + (grain - 0.5) * 40.0;
	float foot = mix(1.0 - base_shade, 1.0, smoothstep(0.0, min(thickness * 0.25, FOOT_METRES), above_base));
	if (on_base) {
		foot = 1.0 - base_shade;
	}
	vec3 sun_part = sun_light * sun_share * lit * sun_reach * crown;
	// The shade: the sky's blue light from above, the haze's from below, tinted, at `shade_light` of the lit side.
	vec3 sky_part = mix(base_light, sky_light, clamp(normal.y * 0.5 + 0.5, 0.0, 1.0)) * shade_colour * shade_light;
	// The silver lining: forward scattering through the thin edge, the Henyey-Greenstein phase over its average.
	vec3 view_way = normalize(seen_world - eye_world);
	float g2 = lining_g * lining_g;
	float phase = (1.0 - g2) / pow(max(1.0 + g2 - 2.0 * lining_g * dot(view_way, towards_sun), 1e-4), 1.5);
	// Only at the CLOUD's edge, where there is no cloud behind the thin puff: lit at every puff's own edge, a backlit heap was
	// a froth of outlined bubbles (clouds3's first backlit wall).
	float thin = exp(-optical * gain * 0.6) * smoothstep(0.55, 0.95, out_of_middle);
	vec3 colour = (sun_part + sky_part) * foot + sun_light * lining * max(phase - 1.0, 0.0) * 0.12 * thin;
	ALBEDO = mix(colour, mist_here.rgb, mist_here.a);
	ALPHA = alpha;
}
