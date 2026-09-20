// A FIREBOAT MONITOR'S STREAM: water thrown on a ballistic arc, coherent at the nozzle, breaking into droplets, and
// opening into spray at the end of its reach.
//
// THROWN ONCE AND FLOWN BY THE GPU, which is `SprayYard`'s decision and the reason this costs almost nothing: the
// processor writes ONE instance per monitor every twentieth of a second -- the two ends' launch points, their launch
// times and the launch velocity -- and never touches it again. Where the water has got to is worked out HERE from each
// pixel's own age. A stream a hundred metres long is about seventy instances and seventy writes a second.
//
// AND THAT IS WHY THE STREAM WHIPS WHEN THE MONITOR IS TRAINED. Water already thrown keeps the velocity it left with,
// so swinging the nozzle sweeps a curve through the air rather than snapping the whole arc across like a laser. It is
// the single most recognisable thing about a monitor being worked, and it falls out of the architecture rather than
// being animated: an arc recomputed every frame from the current aim could not do it at all.
//
// THE DRAG LAW IS LINEAR, AND THAT IS A DELIBERATE CHOICE RATHER THAN A SIMPLIFICATION. Linear drag is the only one
// with a closed form, which is what lets the GPU fly a parcel from its age instead of the processor integrating it
// every frame. It was checked before it was chosen: fitted to the PUBLISHED 320 ft horizontal throw it gives a
// vertical reach of 66.0 m, where a quadratic law fitted to the same figure gives 65.9 m. Two different laws, each
// told only about the horizontal, agreeing about the vertical to a tenth of a metre -- so the reach is a property of
// the water and not of the model. Both also put the best elevation well below 45 degrees, which is what drag does.
//
//   p(t) = p0 + (v0 - a/k) (1 - e^-kt)/k + (a/k) t     a = gravity, k = `drag`
//
// What an instance carries:
//   the transform's origin     the midpoint of the two ends' LAUNCH points
//   the transform's X column   from the older launch point to the newer one
//   INSTANCE_CUSTOM.r / .g     when the older and newer ends left the nozzle, on the yard's clock (`now`)
//   INSTANCE_CUSTOM.b          which monitor, so three streams break up differently
//   INSTANCE_CUSTOM.a          how hard the pump is running, 0 to 1
//   COLOR.rgb                  the LAUNCH VELOCITY, shared by both ends
//   COLOR.a                    unused
//
// THE LAUNCH VELOCITY IS SHARED BY THE SEGMENT'S TWO ENDS, and that is the one approximation. Exact while the monitor
// is still; while it is training at its 30 deg/s the two ends differ by 1.5 degrees, which is a tenth of the stream's
// own width at that range. It buys an ORTHONORMAL basis, which `billboard.gdshaderinc` requires -- packing a second
// velocity into the basis columns would have made them non-invertible and `BILLBOARD_LOCAL_OF` returns rubbish.
//
// NO `skip_vertex_transform` AND `BILLBOARD_LOCAL_OF`, because this is a MULTIMESH: a double build bakes the instance
// into the model matrix and then applies MODELVIEW a second time, so the other macro is wrong here. See
// billboard.gdshaderinc, which is the only reason this stays put at the oil field ten kilometres out.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
#include "res://world/shaders/terrain_noise.gdshaderinc"

// THE MIST BETWEEN THE EYE AND THIS, once a vertex, as every see-through shader here does (tests/lint.gd).
varying vec4 mist_here;

// The yard's clock, set once a frame. Not TIME: the ends were stamped on the processor.
uniform float now = 0.0;
// LINEAR DRAG, per second. Solved against the published horizontal throw; see the note above.
uniform float drag = 0.3389;
uniform float gravity = 9.81;
// How long a parcel is drawn for at most, seconds. A stream to its full reach flies about 3.5 s.
uniform float life = 6.0;
// THE NOZZLE'S BORE and how fast the stream opens out, metres. A 3.5-inch tip is 0.089 m; the drawn jet starts a
// little wider than the bore because it is already ragged as it leaves.
uniform float bore = 0.32;
uniform float spread = 1.05;
// WHERE THE SEA IS, so a stream stops at the water instead of carrying on under it.
uniform float sea_level = 0.0;
// The thinnest it is drawn as a fraction of distance, so a stream a kilometre off is still a stream. It was 0.0015
// and at 165 m -- which is where anybody watching a boat fight a rig fire stands -- the jet came out two pixels wide
// and read as white WIRE rather than as water. A monitor throws about four tonnes a minute; it should look like it.
uniform float least_angle = 0.0032;
uniform vec3 tint = vec3(0.90, 0.94, 0.98);
uniform float opacity = 0.85;
// PER NODE, written once per change of the time of day: the light the water is drawn in, as a cloud is lit
// (`ContrailYard.light_at`). Unshaded, a stream was as white against the night as against noon.
instance uniform vec3 light = vec3(1.0);

varying float age_here;
varying float across;
varying float strength;
varying float seed;
varying float below_sea;


// WHERE A PARCEL HAS FLOWN TO, and how fast it is going, after `t` seconds. The closed form above.
void fly(vec3 v0, float t, out vec3 moved, out vec3 speed) {
	vec3 a = vec3(0.0, -gravity, 0.0);
	float e = (1.0 - exp(-drag * t)) / drag;
	moved = (v0 - a / drag) * e + (a / drag) * t;
	speed = (v0 - a / drag) * exp(-drag * t) + a / drag;
}

void vertex() {
	vec3 along_launch = MODEL_MATRIX[0].xyz;
	vec3 launch_v = COLOR.rgb;
	// RELATIVE TO THE INSTANCE'S ORIGIN, which the engine places exactly: see billboard.gdshaderinc.
	vec3 from = along_launch * VERTEX.x;
	float laid = mix(INSTANCE_CUSTOM.r, INSTANCE_CUSTOM.g, VERTEX.x + 0.5);
	float age = max(now - laid, 0.0);
	vec3 moved;
	vec3 speed;
	fly(launch_v, age, moved, speed);
	vec3 at = from + moved;

	// THE TANGENT IS THE PARCEL'S OWN VELOCITY, not the chord between the segment's ends. It is exact, it costs
	// nothing extra -- `fly` returns it -- and a chord between two ends that have flown different distances is
	// visibly wrong where the arc bends hardest, which is exactly where the eye is looking.
	vec3 along = length(speed) > 0.001 ? normalize(speed) : vec3(0.0, 0.0, -1.0);
	vec3 eye = BILLBOARD_EYE;
	float away = length(eye - at);
	// THREE REGIMES IN ONE CURVE. Near the nozzle the jet is a tight rope; by a second it is breaking into droplets;
	// by three it is spray. `pow(age, 1.35)` is that: slow at first, then opening out fast.
	float width = max(bore + spread * pow(age, 1.35), away * least_angle);
	vec3 side = cross(along, eye - at);
	side = length(side) > 0.000001 ? normalize(side) : vec3(0.0, 1.0, 0.0);

	age_here = age;
	across = VERTEX.y * 2.0;
	strength = INSTANCE_CUSTOM.a;
	seed = INSTANCE_CUSTOM.b;
	vec3 world = at + side * VERTEX.y * width;
	// A STREAM STOPS AT THE WATER. The parcel's own height decides, not the vertex's, so a wide spray does not
	// flicker away half a quad at a time as it comes down.
	below_sea = (MODEL_MATRIX[3].y + at.y) < sea_level ? 1.0 : 0.0;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_LOCAL_OF(world);
}

void fragment() {
	// THE EDGE. A coherent jet has a hard edge and a broken one has none, so the softness grows with age -- and past
	// the first second the edge is broken up by noise fixed to the water rather than to the screen, so a stream seen
	// from a moving boat is a shape in the air and not a pattern sliding over it (`contrail_fine`'s rule).
	float broken = smoothstep(0.35, 2.2, age_here);
	float ragged = fbm2(vec2(age_here * 4.3 + seed * 23.0, across * 1.7));
	float soft = mix(0.90, 0.20 + ragged * 0.45, broken);
	float edge = 1.0 - smoothstep(soft, 1.0, abs(across));

	// HOW SOLID IT IS. Water leaving a nozzle at 49 m/s is very nearly opaque; by the time it is spray it is a haze
	// you can see the fire through. That fall is most of what makes it read as water rather than as a white ribbon.
	float solid = mix(1.0, 0.16, smoothstep(0.15, 2.6, age_here));
	float alive = 1.0 - smoothstep(life * 0.55, life, age_here);

	// AND IT IS WHITER WHERE IT IS BROKEN, because that is what atomised water does to light: a coherent jet is
	// nearly glassy and takes the colour of what is behind it, and spray scatters everything back at you.
	vec3 colour = mix(tint * 0.92, vec3(1.0), broken * 0.6);
	ALBEDO = mix(colour * light, mist_here.rgb, mist_here.a);
	ALPHA = clamp(opacity * solid * alive * edge * strength * (1.0 - below_sea), 0.0, 1.0);
}
