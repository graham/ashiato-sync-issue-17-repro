// A MISSILE'S MOTOR, FINE: a white-hot nozzle, a plume that tears, and the shock diamonds of a rocket.
//
// The same quad as the plain motor, placed by MissileYard the same way and held to the same least angle -- see
// `missile_motor.gdshader`, which this is a costlier drawing of and never a different size from. What FINE adds is in
// the fragment: the plume is broken up by noise scrolling back down it, which is the exhaust leaving at a thousand
// metres a second, and its brightness is beaded with standing diamonds, which is what an under-expanded rocket
// exhaust does and what makes a missile motor read as a rocket rather than as a torch. The diamonds stand still
// against the nozzle: they are a pressure pattern, not something travelling in the gas.
//
// TIME is wrapped at ten minutes, for the reason written in `flame_fine`.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled,
	skip_vertex_transform;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;

#include "res://world/shaders/terrain_noise.gdshaderinc"

instance uniform float burn = 1.0;
instance uniform float seed = 0.0;
uniform float least_angle = 0.0018;
// How many diamonds stand in the plume.
uniform float diamonds = 4.0;

varying vec2 uv;

void vertex() {
	// RELATIVE TO THE MOTOR'S ORIGIN, which the engine places exactly: see billboard.gdshaderinc.
	vec3 origin = vec3(0.0);
	vec3 along = MODEL_MATRIX[1].xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	float away = length(BILLBOARD_EYE - origin);
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
	// TORN SIDEWAYS more the further from the nozzle it gets, by noise running back down the plume.
	float tear = fbm2(vec2(uv.x * 3.0 + seed * 11.0, y * 3.0 - t * 9.0));
	float x = uv.x + (tear - 0.5) * 0.30 * y;
	float half_width = 0.5 * (1.0 - y * 0.75);
	float body = 1.0 - smoothstep(half_width * 0.2, half_width, abs(x));
	float grain = fbm2(vec2(x * 6.0 + seed * 5.0, y * 7.0 - t * 14.0));
	float plume = body * pow(1.0 - y, 1.3) * (0.65 + 0.7 * grain);
	// THE DIAMONDS: bright beads in the first half of the plume, standing against the nozzle.
	float bead = pow(0.5 + 0.5 * cos(y * 6.2832 * diamonds), 6.0) * (1.0 - smoothstep(0.1, 0.6, y));
	float core = (1.0 - smoothstep(0.0, 0.18, abs(x))) * bead;
	// AND THE NOZZLE ITSELF, white.
	float throat = (1.0 - smoothstep(0.0, 0.08, y)) * (1.0 - smoothstep(0.0, 0.35, abs(x)));
	float heat = clamp(plume + core * 0.9 + throat, 0.0, 1.6);
	vec3 colour = mix(vec3(0.95, 0.30, 0.06), vec3(1.0, 0.78, 0.35), smoothstep(0.2, 0.6, heat));
	colour = mix(colour, vec3(1.0, 0.98, 0.92), smoothstep(0.7, 1.2, heat));
	float flicker = 0.9 + 0.1 * sin(t * 71.0 + seed * 29.0);
	float strength = heat * flicker * (0.75 + 0.25 * burn);
	ALBEDO = colour * strength * 1.6 * (1.0 - mist_here.a);
	ALPHA = clamp(strength, 0.0, 1.0);
}
