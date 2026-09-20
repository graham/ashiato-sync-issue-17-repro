// A MISSILE'S TRAIL, FINE: smoke that billows, spreads wider and lingers, and is hot just behind the motor. And, worn
// shorter, an aircraft's contrail (ContrailYard).
//
// The same instances, the same clock and the same turning as `contrail.gdshader` -- read that for what an instance
// carries, for `lasting`, `forming`, `forming_from` and `light`, and for how a contrail comes and goes along its length
// rather than segment by segment. What FINE adds: the ribbon's edge is broken by noise that is fixed to the trail
// rather than to the screen, so a trail seen from a moving aeroplane is a shape in the sky and not a pattern sliding
// over it; it spreads further and lasts longer; and the few metres just laid glow faintly warm, which joins the smoke
// to the motor. A contrail has no motor, so its warmth is gone wherever `forming` is set.
//
// Still one draw call and still no texture. The noise is `fbm2`, two octaves, once a fragment.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;

#include "res://world/shaders/terrain_noise.gdshaderinc"

uniform float now = 0.0;
// No default: see `contrail.gdshader`.
uniform float life;
uniform float start_width = 1.0;
uniform float spread = 1.6;
uniform float least_angle = 0.0012;
uniform vec3 tint = vec3(0.90, 0.91, 0.93);
uniform float opacity = 0.62;
instance uniform float lasting = 1.0;
instance uniform float forming = 0.0;
instance uniform float forming_from = 0.0;
instance uniform vec3 light = vec3(1.0);

varying float fade;
varying float across;
varying float age_now;
// Where along the trail this is, in seconds of flight: fixed to the smoke, so the billows stay where they were laid.
varying float laid_at;
varying float seed;
varying float strength;

void vertex() {
	vec3 along = MODEL_MATRIX[0].xyz;
	// RELATIVE TO THE SEGMENT'S MIDDLE, which the engine places exactly: see billboard.gdshaderinc.
	vec3 at = along * VERTEX.x;
	float laid = mix(INSTANCE_CUSTOM.r, INSTANCE_CUSTOM.g, VERTEX.x + 0.5);
	float age = max(now - laid, 0.0);
	float away = length(BILLBOARD_EYE - at);
	float width = max(start_width + spread * sqrt(age) * 2.2, away * least_angle);
	vec3 side = cross(along, BILLBOARD_EYE - at);
	side = length(side) > 0.000001 ? normalize(side) : vec3(0.0);
	fade = clamp(1.0 - age / max(life * lasting, 0.001), 0.0, 1.0);
	strength = INSTANCE_CUSTOM.a * mix(COLOR.r, COLOR.g, VERTEX.x + 0.5);
	across = VERTEX.y * 2.0;
	age_now = age;
	laid_at = laid;
	seed = INSTANCE_CUSTOM.b;
	vec3 world = at + side * VERTEX.y * width;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_LOCAL_OF(world);
}

void fragment() {
	float billow = fbm2(vec2(laid_at * 3.1 + seed * 17.0, across * 1.3 + age_now * 0.08));
	float edge = 1.0 - smoothstep(0.35 + billow * 0.45, 1.0, abs(across));
	float body = 0.55 + 0.6 * billow;
	float warm = forming > 0.0 ? 0.0 : (1.0 - smoothstep(0.0, 0.35, age_now)) * 0.6;
	vec3 colour = mix(tint * (0.85 + 0.2 * billow), vec3(1.0, 0.72, 0.45), warm);
	ALBEDO = mix(colour * light, mist_here.rgb, mist_here.a);
	// BEHIND AN AIRCRAFT, from this pixel's own age: see `contrail.gdshader`. Behind a missile, as it always was.
	float there = forming > 0.0
		? smoothstep(forming_from, forming_from + forming, age_now)
			* (1.0 - smoothstep(0.0, max(life * lasting, 0.001), age_now))
		: fade * fade * smoothstep(0.0, 0.05, age_now);
	ALPHA = clamp(opacity * there * edge * body * strength, 0.0, 1.0);
}
