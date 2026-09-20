// WHAT A HOVERING AIRCRAFT DOES TO THE GROUND: the ring of dust or spray thrown out from where its jets strike, run
// outward, lifted, and thinned away. This is the picture everybody knows of a Harrier, and before 2026-09-19 there was
// no downwash, dust or ground wash anywhere in this game.
//
// THROWN ONCE AND FLOWN BY THE GPU, which is `SprayYard`'s pattern exactly. One instance of one MultiMesh is written
// when the puff is thrown -- where on the ring it started (the instance's ORIGIN, its basis the identity, as
// billboard.gdshaderinc asks of a MultiMesh), when, which way out, and how much of it is fountain -- and never touched
// again. The shader works out where it has run and risen to from its age on `MissileYard`'s clock, so the processor's
// whole cost is the throwing and a frozen level freezes the ground wash exactly as it freezes the contrails.
//
// A RING, NOT A CLOUD. Each puff starts at the EDGE of the jet's footprint rather than at the point of impact
// (`ExhaustTuning.BLOOM_RING_RADII`) and runs outward. That dark centre with a wall of dust around it is what every
// photograph of a hovering jet shows, and a cloud centred on the impact point does not read as one.
//
// AND THE FOUNTAIN, which is the part that is specifically a Harrier. Where two jets strike close together their
// outward flows collide between them and go straight back UP; on the real aeroplane the LIDS strakes and the
// retractable fence under the fuselage exist to trap exactly that (`craft/harrier/sources.md`). A puff thrown near
// another port's impact carries `INSTANCE_CUSTOM.a` and rises instead of running out.
//
// LIT, NOT GLOWING -- `damage_smoke.gdshader`'s decision and for its reason: camera-facing discs given the normal of a
// ball and lit by the level's own sun and ambient, so dust is pale by day and dark at night without anybody telling it
// the time. The unshaded trails glow white at night and this was not going to join them.
//
// ITS COLOUR IS PER PUFF, in the instance colour, and comes from WHAT WAS HIT rather than from what the craft is:
// `Terrain.water_height` finite under the strike means white spray, otherwise dust in the ground's own colour. One
// MultiMesh and one draw call covers both, so an aircraft hovering over a shoreline throws white on one side and brown
// on the other without anything branching.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
varying vec4 mist_here;

// The yard's clock, written every frame -- MissileYard's, shared with the contrails and the spray.
uniform float now = 0.0;
uniform float life = 1.9;
// A puff's radius when it is thrown, and how much it grows over its life, metres.
uniform float start_size = 0.7;
uniform float grow = 3.4;
// How fast it runs outward from the footprint's edge, and how fast it lifts, metres a second.
uniform float outward = 11.0;
uniform float lift = 2.2;
// ...and how fast a puff caught in a fountain between two jets rises instead.
uniform float fountain_lift = 6.5;
uniform float opacity = 0.40;

varying vec2 uv;
varying float fade;
varying vec3 right_w;
varying vec3 up_w;
varying vec3 eye_w;
varying vec3 tone;

void vertex() {
	// RELATIVE TO THE PUFF'S OWN ORIGIN, which the engine places exactly: see billboard.gdshaderinc.
	vec3 start = vec3(0.0);
	float t = now - INSTANCE_CUSTOM.r;
	float k = t / life;
	float own = INSTANCE_CUSTOM.g;
	float bearing = INSTANCE_CUSTOM.b * 6.2831853;
	float fountain = INSTANCE_CUSTOM.a;
	tone = COLOR.rgb;
	uv = VERTEX.xy * 2.0;
	fade = 0.0;
	float radius = 0.0;
	vec3 at = start;
	if (t >= 0.0 && k < 1.0) {
		// SWELLS FAST AND THEN SLOWLY, as a puff of anything does: the square root of its age.
		radius = (start_size + grow * sqrt(k)) * (0.7 + 0.6 * own);
		// RUNS OUT AND SLOWS, because the air it is riding spreads and loses speed; a fountain puff trades that
		// outward run for a climb.
		float ran = outward * (1.0 - exp(-t * 1.8)) / 1.8 * (0.75 + 0.5 * own) * (1.0 - fountain);
		float rose = mix(lift, fountain_lift, fountain) * t * (0.8 + 0.4 * own);
		at = start + vec3(cos(bearing) * ran, rose, sin(bearing) * ran);
		fade = opacity * smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.30, 1.0, k));
	}
	right_w = INV_VIEW_MATRIX[0].xyz;
	up_w = INV_VIEW_MATRIX[1].xyz;
	eye_w = normalize(BILLBOARD_EYE - at);
	vec3 world = fade > 0.0 ? at + (right_w * VERTEX.x + up_w * VERTEX.y) * radius * 2.0 : at;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_LOCAL_OF(world);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float r = length(uv);
	float body = 1.0 - smoothstep(0.30, 1.0, r);
	vec3 ball = normalize(right_w * uv.x + up_w * uv.y + eye_w * (sqrt(max(1.0 - r * r, 0.0)) + 0.2));
	NORMAL = normalize((VIEW_MATRIX * vec4(ball, 0.0)).xyz);
	ALBEDO = tone * (0.8 + 0.3 * clamp(ball.y * 0.5 + 0.5, 0.0, 1.0));
	ROUGHNESS = 1.0;
	ALPHA = clamp(body * fade, 0.0, 1.0);
	ALBEDO = ALBEDO * (1.0 - mist_here.a) + mist_here.rgb * mist_here.a;
}
