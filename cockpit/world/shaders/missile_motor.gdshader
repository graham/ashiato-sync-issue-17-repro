// A MISSILE'S MOTOR, PLAIN: a hot tongue of light out of the nozzle, the cheapest thing that reads as burning.
//
// One quad per missile, standing along the missile's axis behind the nozzle and turned about that axis to face the
// midpoint of the eyes -- the rule `flame_fine` follows, and for the same reason: a quad turned separately per eye
// is two flames. MissileYard puts the node's origin at the nozzle, its Y column along the plume (backwards, as long
// as the plume) and its X column across it (as wide as the plume), and shows it only while the simulation's `motor`
// is true, so a motor that has burnt out is not drawn at all rather than drawn dark.
//
// IT HOLDS AN ANGLE, like the lights: a plume two metres long is under a pixel at four kilometres, and a missile in
// flight is found by its motor. So the width never falls below `least_angle` of the distance, and the length grows
// with it. Additive and depth-write off, so two motors on one rail are brighter rather than one hiding the other.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled,
	skip_vertex_transform;

// How much burn is left, 1 at ignition to 0 at burnout. A motor fades a little as it goes, and no more: a motor is on
// or it is off, and `motor` on the wire is what decides that.
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;
instance uniform float burn = 1.0;
// Which missile this is, so two on one rail flicker apart.
instance uniform float seed = 0.0;
// The narrowest a plume is ever drawn, as a fraction of its distance from the eye. About two pixels.
uniform float least_angle = 0.0018;

varying vec2 uv;

void vertex() {
	// RELATIVE TO THE MOTOR'S ORIGIN, which the engine places exactly: see billboard.gdshaderinc.
	vec3 origin = vec3(0.0);
	vec3 along = MODEL_MATRIX[1].xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	float away = length(BILLBOARD_EYE - origin);
	// THE FLOOR, and the plume stretched by the same factor so a far motor keeps its shape.
	float grow = max(1.0, away * least_angle / max(width, 0.0001));
	vec3 to_eye = BILLBOARD_EYE - origin;
	vec3 side = cross(along, to_eye);
	side = length(side) > 0.0001 ? normalize(side) : normalize(MODEL_MATRIX[0].xyz);
	uv = VERTEX.xy;
	vec3 world = origin + side * VERTEX.x * width * grow + along * VERTEX.y * grow;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_VIEW_OF(world);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float t = mod(TIME, 600.0);
	float y = clamp(uv.y, 0.0, 1.0);
	// WIDEST AT THE NOZZLE, a point at the tip.
	float half_width = 0.5 * (1.0 - y * 0.8);
	float body = 1.0 - smoothstep(half_width * 0.25, half_width, abs(uv.x));
	float tongue = body * pow(1.0 - y, 1.6);
	float flicker = 0.82 + 0.18 * sin(t * 57.0 + seed * 41.0) * sin(t * 23.0 + seed * 7.0);
	vec3 colour = mix(vec3(1.0, 0.45, 0.10), vec3(1.0, 0.95, 0.80), smoothstep(0.35, 0.9, tongue));
	float strength = tongue * flicker * (0.7 + 0.3 * burn);
	ALBEDO = colour * strength * 1.8 * (1.0 - mist_here.a);
	ALPHA = clamp(strength, 0.0, 1.0);
}
