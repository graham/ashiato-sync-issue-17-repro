// THE HOT CORE JUST OUTSIDE A JET PIPE: the short pale tongue that says an engine is running hard.
//
// `missile_motor.gdshader`'s shape, and read that one first -- one quad standing along the port's axis, turned about
// that axis towards the MIDPOINT OF THE EYES (a quad turned per eye is two flames), additive with depth-write off so
// two nozzles side by side are brighter rather than one hiding the other, and holding an ANGLE so a plume does not
// vanish into a sub-pixel at four kilometres.
//
// WHAT IS DIFFERENT FROM A MISSILE'S MOTOR, and it is not a tuning difference. A rocket is a long bright tongue
// because it is burning fuel in the open; a turbofan at full dry thrust shows a SHORT, PALE, nearly clear one, and
// copying the missile's length was the first thing that looked wrong. `ExhaustTuning.CORE_LENGTH_RADII` is 2.6 nozzle
// radii, and below `CORE_FROM_THROTTLE` nothing is drawn at all, because an engine at idle does not glow.
//
// ONLY A HOT PORT HAS ONE. `ExhaustTuning.layers_of` gives a core to a JET and to nothing else: a lift fan and a rotor
// move cold air, and drawing a flame on them would be inventing one. On a Harrier that is visible in the aeroplane
// itself -- the two FRONT nozzles are LP-compressor air and the two REAR are 650 degrees ([PEG], about 60/40 by flow),
// so it wears two cold plumes forward and two hot ones aft, which nothing else in this game does.
// ONE MULTIMESH FOR EVERY CORE IN THE SKY, which is one draw call however many aircraft are running. That costs the
// per-instance uniforms -- a MultiMesh instance carries INSTANCE_CUSTOM and its colour and nothing else -- so `blowing`
// and `seed` ride in INSTANCE_CUSTOM instead. And it decides the billboard path: billboard.gdshaderinc's "WHICH" table
// says NO skip_vertex_transform plus BILLBOARD_LOCAL_OF for every MultiMesh, because on the double build
// skip_vertex_transform makes the engine bake the instance into the model matrix and then apply it a second time, and
// headless Godot cannot catch it -- its dummy renderer reads every instance back as the identity.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://world/shaders/billboard.gdshaderinc"
#include "res://world/shaders/mist.gdshaderinc"
// THE MIST BETWEEN THE EYE AND THIS, once a vertex (world/shaders/mist.gdshaderinc): rgb its colour, a how much it takes.
varying vec4 mist_here;

// The narrowest a core is ever drawn, as a fraction of its distance from the eye. About two pixels.
uniform float least_angle = 0.0016;
uniform float brightness = 1.4;

varying vec2 uv;
// INSTANCE_CUSTOM.r is how hard this port blows, 0..1, off the replicated bus's throttle; .g is which port it is, so
// four nozzles flicker apart.
varying float blowing;
varying float seed;

void vertex() {
	// RELATIVE TO THE PORT'S ORIGIN, which the engine places exactly: see billboard.gdshaderinc.
	vec3 origin = vec3(0.0);
	blowing = INSTANCE_CUSTOM.r;
	seed = INSTANCE_CUSTOM.g;
	vec3 along = MODEL_MATRIX[1].xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	float away = length(BILLBOARD_EYE - origin);
	// THE FLOOR, and the tongue stretched by the same factor so a far core keeps its shape.
	float grow = max(1.0, away * least_angle / max(width, 0.0001));
	vec3 to_eye = BILLBOARD_EYE - origin;
	vec3 side = cross(along, to_eye);
	side = length(side) > 0.0001 ? normalize(side) : normalize(MODEL_MATRIX[0].xyz);
	uv = VERTEX.xy;
	vec3 world = origin + side * VERTEX.x * width * grow + along * VERTEX.y * grow;
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz + world, mist_clock);
	VERTEX = BILLBOARD_LOCAL_OF(world);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float t = mod(TIME, 600.0);
	float y = clamp(uv.y, 0.0, 1.0);
	// WIDEST AT THE NOZZLE, closing to nothing: a jet pipe's plume necks in rather than coming to a rocket's point.
	float half_width = 0.5 * (1.0 - y * 0.55);
	float body = 1.0 - smoothstep(half_width * 0.2, half_width, abs(uv.x));
	float tongue = body * pow(1.0 - y, 1.9);
	// A FAST FLICKER, much shallower than a motor's: a turbine is steady and a rocket is not.
	float flicker = 0.92 + 0.08 * sin(t * 61.0 + seed * 41.0) * sin(t * 27.0 + seed * 7.0);
	// PALE, and barely coloured. A dry turbofan's core is nearly clear with a blue-white root; the orange belongs to
	// afterburners and to fires, and putting it here made every aeroplane look like it was on fire.
	vec3 colour = mix(vec3(0.55, 0.62, 0.85), vec3(0.95, 0.93, 0.88), smoothstep(0.2, 0.9, tongue));
	float strength = tongue * flicker * blowing;
	ALBEDO = colour * strength * brightness * (1.0 - mist_here.a);
	ALPHA = clamp(strength, 0.0, 1.0);
}
