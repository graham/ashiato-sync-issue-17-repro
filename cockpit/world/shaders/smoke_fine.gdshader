// SMOKE, ON THE FINE FINISH: puffs that billow, catch the sun, and are stippled rather than
// smeared.
//
// The plain column is fourteen translucent spheres, each one flat grey, blended. Close up that
// is fourteen balls; from the approach it is a grey smear. Three things make smoke read as a
// volume, and this does each:
//
//   IT BILLOWS. Each puff's surface is pushed out along its normal by 3D noise that scrolls
//   upward, seeded per puff, so the outline boils. The processor makes the puffs RISE through the
//   column and come back at the bottom (see FireYard); the shader makes each one churn while it
//   does.
//
//   IT IS LIT. Wrap-lit by the real sun, with a paler top and a darker underside, so a column has
//   a bright side and a shadow side the way a solid object would -- which is most of what makes a
//   grey shape read as a mass rather than a stain.
//
//   IT IS GRAINED, AND THE GRAIN IS ON THE SMOKE. Density is blended, like the plain puffs, and
//   shaded by a hash of the fragment's cell IN THE PUFF, so the column has a texture that stays
//   put as the head moves and is the same in both eyes.
//
//   IT WAS A STIPPLE FIRST, and the stipple failed a look. Coverage by discarding every pixel
//   whose cell hashed above the density gave an opaque, unsorted column -- and in the first
//   render checks (2026-09-12, fire view at 560 m, cells of 64 and then 128 per unit) it read as
//   a swarm of dark specks, not smoke, where the plain finish's soft blended puffs read as smoke.
//   Thin smoke is mostly holes when it is drawn as all-or-nothing.
//
// REJECTED: blended sprites with soft particles. Softening needs the depth texture, which on the
// Mobile renderer this was written for is a second pass (untimed on Forward+, the renderer since
// 2026-09-14), and blended overdraw is the one thing a headset in a smoke
// column cannot afford.
shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_disabled, shadows_disabled,
	depth_draw_never;
#include "res://world/shaders/eye.gdshaderinc"

#include "res://world/shaders/air_noise.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;

// The puff's colour, and in `a` how dense it is, 0..1. Set per puff by FireYard.
instance uniform vec4 tone : source_color = vec4(0.30, 0.29, 0.28, 0.5);
// Which puff this is, so no two churn alike.
instance uniform float seed = 0.0;
// How far a puff's surface is pushed in and out, as a fraction of its radius.
uniform float billow : hint_range(0.0, 0.5) = 0.24;
// How many grain cells across a unit of the puff, and how much the grain moves the density.
uniform float stipple = 128.0;
uniform float grain_amount : hint_range(0.0, 1.0) = 0.35;

varying vec3 shape_pos;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	float t = mod(TIME, 600.0);
	vec3 dir = normalize(VERTEX);
	float lump = fbm3_3d(dir * 2.0 + vec3(seed * 7.1, seed * 3.3 - t * 0.22, seed * 5.7));
	VERTEX += NORMAL * (lump - 0.45) * billow;
	shape_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	mist_here = mist_along(EYE_POSITION_WORLD, world_pos, mist_clock);
}

void fragment() {
	float t = mod(TIME, 600.0);
	float wisp = fbm2_3d(shape_pos * 3.0 + vec3(seed * 11.0, -t * 0.3, seed * 2.0));
	vec3 n = normalize(world_normal);
	float edge = abs(dot(n, normalize(EYE_POSITION_WORLD - world_pos)));
	// DENSE AT THE CORE AND SOFT AT THE EDGE: the silhouette fades over the outer half of the
	// puff, and the middle is nearly solid, which is what reads as a volume rather than a veil.
	float grain = hash31(floor(shape_pos * stipple) + vec3(seed * 17.0));
	float density = tone.a * 1.35 * smoothstep(0.0, 0.55, edge) * (0.6 + 0.8 * wisp);
	ALPHA = clamp(density * (1.0 - grain_amount * 0.5 + grain_amount * grain), 0.0, 1.0);
	ALBEDO = tone.rgb * (0.7 + 0.45 * clamp(n.y * 0.5 + 0.5, 0.0, 1.0));
	BACKLIGHT = tone.rgb * 0.35 * (1.0 - mist_here.a);
	ALBEDO *= 1.0 - mist_here.a;
	EMISSION = mist_here.rgb * mist_here.a;
	ROUGHNESS = 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
