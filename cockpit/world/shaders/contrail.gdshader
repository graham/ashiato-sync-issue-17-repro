// A MISSILE'S TRAIL, PLAIN: a flat white ribbon that widens and fades where the missile has been. And, worn shorter, an
// aircraft's contrail (ContrailYard).
//
// EVERY SEGMENT OF EVERY TRAIL IS ONE INSTANCE OF ONE MULTIMESH, so all the smoke in the sky is one draw call. See
// MissileYard, which writes a segment when the missile has flown far enough and then never touches it again: how
// wide it has spread and how far it has faded is worked out HERE from how old each end is, so an old trail costs the
// processor nothing at all.
//
// What an instance carries:
//   the transform's X column   the segment, from its older end to its newer end, in metres;
//   the transform's origin     the segment's midpoint;
//   INSTANCE_CUSTOM.r / .g     when the older and newer ends were laid, on the yard's clock (`now`);
//   INSTANCE_CUSTOM.b          which trail, so two trails billow apart on the fine finish;
//   INSTANCE_CUSTOM.a          how strongly it was laid, 0 to 1: 1 behind a missile and behind an aircraft alike;
//   COLOR.r / .g               how strongly its older and newer ends were laid, 0 to 1: the instance colour, which only
//                              ContrailYard's drawer carries -- the height band, the speed and the nacelles, per END, so
//                              where one segment meets the next they are one strength. A drawer with no colours reads
//                              white here, so a missile's is 1 at both ends.
// An unused instance has a zero X column, which collapses it to a point and draws nothing.
//
// A CONTRAIL COMES AND GOES ALONG ITS LENGTH, NOT SEGMENT BY SEGMENT (2026-09-14, "it's a little obvious they are
// chunky"). Behind an aircraft how much trail there is, is worked out at every PIXEL from that pixel's own age: nothing
// for the first `forming_from` seconds, in smoothly over `forming` more, and out smoothly over the rest of its life.
// BEFORE, a new segment thickened in as a whole, by the age of its newer end -- neighbours 0.2 s apart stood 0.4 of the
// way apart -- and a segment's strength was the mean of its ends, so a trail crossing the height band stepped at every
// join. Behind a missile nothing here has changed: the square of what is left of its life, at the ends.
//
// TURNED ABOUT ITS OWN LENGTH to face the midpoint of the eyes, never per eye: see `flame_fine`.
//
// COST, which is the reason it is this plain. Smoke near the eye is the most expensive thing to draw in a headset --
// every pixel of a ribbon ten metres wide at arm's length is a blended pixel -- so the plain trail is one texture-free
// fragment with no noise, and it is thin and short-lived compared to the fine one.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// The yard's clock, set once a frame. Not TIME: the ends were stamped on the processor, so their ages have to be
// measured on the same clock.
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;
uniform float now = 0.0;
// How long a missile's trail lasts, in seconds. NO DEFAULT: written once by MissileYard from TrailTuning, which is the
// one place the number is, so a contrail can be a share of it.
uniform float life;
// How wide it leaves the nozzle, and how fast it spreads, in metres and metres a second.
uniform float start_width = 0.8;
uniform float spread = 0.9;
// The thinnest it is drawn, as a fraction of distance from the eye. A trail you cannot see is not a trail.
uniform float least_angle = 0.0012;
uniform vec3 tint = vec3(0.92, 0.93, 0.95);
uniform float opacity = 0.55;
// PER NODE, set once: how much of `life` this node's trails last (1 behind a missile, a share behind an aircraft); how
// many seconds a new trail takes to come in (0, none, behind a missile, whose segment grows from the nozzle); and how
// many seconds of it are not there yet at all, which behind an aircraft is one sample, so the segment just laid is
// nothing at its newer end and a trail's head never arrives in a piece.
instance uniform float lasting = 1.0;
instance uniform float forming = 0.0;
instance uniform float forming_from = 0.0;
// PER NODE, written once per change of the time of day: the light the trail is drawn in (`ContrailYard.light_at`, from
// the sun and sky a cloud is lit by). White behind a missile, which is drawn as it always was.
instance uniform vec3 light = vec3(1.0);

varying float fade;
varying float across;
varying float age_here;
varying float strength;

void vertex() {
	vec3 along = MODEL_MATRIX[0].xyz;
	// RELATIVE TO THE SEGMENT'S MIDDLE, which the engine places exactly: see billboard.gdshaderinc.
	vec3 at = along * VERTEX.x;
	float laid = mix(INSTANCE_CUSTOM.r, INSTANCE_CUSTOM.g, VERTEX.x + 0.5);
	float age = max(now - laid, 0.0);
	float away = length(BILLBOARD_EYE - at);
	float width = max(start_width + spread * age, away * least_angle);
	vec3 side = cross(along, BILLBOARD_EYE - at);
	side = length(side) > 0.000001 ? normalize(side) : vec3(0.0);
	fade = clamp(1.0 - age / max(life * lasting, 0.001), 0.0, 1.0);
	age_here = age;
	strength = INSTANCE_CUSTOM.a * mix(COLOR.r, COLOR.g, VERTEX.x + 0.5);
	across = VERTEX.y * 2.0;
	vec3 world = at + side * VERTEX.y * width;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_LOCAL_OF(world);
}

void fragment() {
	float edge = 1.0 - across * across;
	ALBEDO = mix(tint * light, mist_here.rgb, mist_here.a);
	float there = forming > 0.0
		? smoothstep(forming_from, forming_from + forming, age_here)
			* (1.0 - smoothstep(0.0, max(life * lasting, 0.001), age_here))
		: fade * fade;
	ALPHA = clamp(opacity * there * edge * strength, 0.0, 1.0);
}
