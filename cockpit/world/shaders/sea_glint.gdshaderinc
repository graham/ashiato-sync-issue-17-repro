// A BRIGHT LIGHT OVER THE SEA, REFLECTED: the oil platform's flare and four of its deck lamps as a glitter path on the
// water at night, for both ocean shaders. Worked out here per pixel against the sea's own normal and roughness, as the
// engine works out the sun's and the moon's, and added as EMISSION.
//
// WHY NOT THE ENGINE'S LIGHT. The flare's OmniLight3D (`OilField.FLARE_RANGE`, 190 m) lights the steel near it. A light's
// specular stops at its range, and the reflection of a flame 80 m up is seen on the water between the flame and the eye,
// hundreds of metres to kilometres from it: from 2 km at sea level (cockpit-oilrig-07) there was no reflection at all,
// and an omni light reaching 2 km would light every mesh in that sphere every frame. The flare is ONE point over the sea,
// so its reflection is the one GGX term below, with no shadow and no cluster.
//
// WHAT IT REPLACED. A 120 m additive disc of value noise laid on the water under the flame (`flare_glow.gdshader`, gone),
// which from a helicopter read as a flat, blotchy, tiled orange floor (the user, 2026-09-18: "the shader doesn't work very
// well with the flame, can you make sure it reflects a little better"). Water shows a light at night as a streak running
// from under it towards the eye, broken up by the waves, tightest near the horizon; the sea's normal and its footprint
// roughness already draw exactly that for the sun by day, so the flare now goes through the same two.
//
// THE SOURCE HAS A SIZE. A flame 10 m across is not a point: its reflection is the GGX lobe widened by the angle the source
// fills (alpha squared plus the square of half that angle), which keeps glassy near water from drawing it as one
// pixel-sized spark and normalises the lobe as the sphere lights of Karis 2013 do.
//
// THE NUMBERS ARE GLOBAL SHADER UNIFORMS (project.godot [shader_globals], `sea_glint_*`), written by `OilField` for the
// platform nearest the eye, because both ocean shaders' materials are built by `SeaSwell` and `WaterSurface`, which know
// nothing of platforms. Zero strength -- every day and dusk, and every world with no platform -- skips all of it on a
// branch every pixel takes the same way.
#ifndef SEA_GLINT_GDSHADERINC
#define SEA_GLINT_GDSHADERINC

// The flare: xyz the middle of the flame in the world, w its radius in metres.
global uniform vec4 sea_glint_flare;
// Its colour times its strength (radiance times area, in the flame shader's own units a square metre); zero when unlit.
global uniform vec4 sea_glint_flare_colour;
// Four deck lamps, one to a column: xyz in the world, w each one's radius.
global uniform mat4 sea_glint_lamps;
// Their shared colour times strength; zero by day.
global uniform vec4 sea_glint_lamps_colour;

// Water's F0, as the ocean's SPECULAR 0.25 gives it.
const float GLINT_F0 = 0.02;
// THE GLINT'S LOBE IS HALF AS WIDE AS THE SEA'S OWN ROUGHNESS says, in alpha squared. At the full roughness the path was an even
// warm band from near to far (cockpit-flaresea-08, first after); a real flare's path is tightest and brightest under the
// flame at the horizon and breaks into separate sparkles close in. At half, 07's band under the flame went from 3.1 to 5.9
// warmth a pixel and 09's near water broke into sparkles. THE RISK is shimmer in a headset: the halving takes in the
// sea's specular antialiasing term too. Not yet looked at in one (learnings/2026-09-18-flaresea.md, What's next).
const float GLINT_SHARPEN = 0.5;

// ONE SOURCE, `at` with radius `radius` and strength `colour`, seen reflected at `here` from `eye` in normal `n` of GGX
// alpha squared `alpha_squared`: F D V (n.l) I / d^2, with V the height-correlated Smith visibility.
vec3 sea_glint_one(vec3 here, vec3 eye, vec3 n, float alpha_squared, vec3 at, float radius, vec3 colour) {
	vec3 to_light = at - here;
	float d2 = max(dot(to_light, to_light), 1.0);
	vec3 l = to_light * inversesqrt(d2);
	vec3 v = normalize(eye - here);
	float nl = dot(n, l);
	float nv = max(dot(n, v), 0.001);
	if (nl <= 0.0) {
		return vec3(0.0);
	}
	vec3 h = normalize(l + v);
	float nh = max(dot(n, h), 0.0);
	float a2 = clamp(alpha_squared * GLINT_SHARPEN + radius * radius * 0.25 / d2, 0.0002, 1.0);
	float den = nh * nh * (a2 - 1.0) + 1.0;
	float dist = a2 / (3.14159265 * den * den);
	float vis = 0.5 / (nl * sqrt(nv * nv * (1.0 - a2) + a2) + nv * sqrt(nl * nl * (1.0 - a2) + a2));
	float vh = max(dot(v, h), 0.0);
	float fresnel = GLINT_F0 + (1.0 - GLINT_F0) * pow(1.0 - vh, 5.0);
	return colour * (fresnel * dist * vis * nl / d2);
}

// EVERY GLINT at `here`, for EMISSION. `n` is the sea's world normal, `alpha_squared` the roughness the sea was handed.
vec3 sea_glints(vec3 here, vec3 eye, vec3 n, float alpha_squared) {
	vec3 out_light = vec3(0.0);
	if (sea_glint_flare_colour.a > 0.0) {
		out_light += sea_glint_one(here, eye, n, alpha_squared, sea_glint_flare.xyz, sea_glint_flare.w,
			sea_glint_flare_colour.rgb);
	}
	if (sea_glint_lamps_colour.a > 0.0) {
		for (int i = 0; i < 4; i++) {
			out_light += sea_glint_one(here, eye, n, alpha_squared, sea_glint_lamps[i].xyz, sea_glint_lamps[i].w,
				sea_glint_lamps_colour.rgb);
		}
	}
	return out_light;
}
#endif
