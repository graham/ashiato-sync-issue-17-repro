// A SIGNAL LAMP'S BEAM, SEEN FROM OUTSIDE IT: a bright point in the lamp's colour that stays a point at kilometres,
// and that is there only for an eye the beam is pointed at. See SignalLamp.
//
// THE SAME TRICK AS THE AIRCRAFT'S LIGHTS (beacon.gdshaderinc), for the same reason: a real lamp does not get smaller
// with distance the way the aeroplane it is on does, so the quad's radius is the LARGER of the lens's real size and a
// fixed ANGLE. Unshaded, never fogged, never shadowed, and it lights nothing: a signal lamp's job is to be SEEN.
//
// AND ONE THING THE NAVIGATION LIGHTS DO NOT HAVE: A BEAM. An Aldis lamp is aimed. Its light goes out in a cone a few
// degrees wide, and a signal is read by the person inside the cone and by nobody much outside it -- which is the point
// of aiming it. So the glare's size and brightness are scaled by where the eye is against the lamp's axis: full inside
// `beam_core`, fading to nothing at `beam_edge`, and not drawn at all behind the lamp. The holder, looking along the
// back of their own lamp, never sees it.
//
// PLACED BY THE ENGINE'S OWN TRANSFORM, NOT BY `VIEW_MATRIX * centre`, which is what makes it steady far from the
// origin on the double build (beacon.gdshaderinc has the measurement). The centre, the distance and the lamp's axis are
// read from MODELVIEW_MATRIX; the quad is written back in the node's own space for the engine to place. It never reads
// CAMERA_POSITION_WORLD, which is minus the camera on a double build (working_with_godot.md).
//
// THE AXIS IS THE NODE'S -Z: the glare stands on the lamp's muzzle, whose -Z is the beam.
//
// THROUGH THE MIST like every see-through thing (mist.gdshaderinc, and tests/lint.gd holds it): a lamp flashed across
// a valley full of haze is dimmer for it, as a real one is, and the fog the engine would have applied is off.
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled, blend_mix, depth_draw_never;

#include "res://world/shaders/mist.gdshaderinc"

// The lamp's colour, and how far past white the core is pushed (it is tonemapped like everything else).
uniform vec3 tint = vec3(1.0);
uniform float energy = 3.0;
// Radius, in radians, below which the glare never shrinks at the centre of the beam. See SignalLamp.LEAST_ANGLE.
uniform float least_angle = 0.010;
// The lens's own radius, in metres: what the glare is up close.
uniform float real_radius = 0.037;
// The beam, as cosines of the angle off the axis: full inside `beam_core`, gone at `beam_edge`.
uniform float beam_core = 0.9976;
uniform float beam_edge = 0.927;
// HALF THE QUAD'S OWN SIDE, in metres, so the corners read -1..1 whatever size the mesh is. The mesh is tiny on purpose:
// see SignalLamp.GLARE_QUAD.
uniform float quad_half = 0.01;

varying vec2 corner;
varying float in_beam;
// THE MIST BETWEEN THE EYE AND THE LAMP, once a vertex: rgb its colour, a how much it takes.
varying vec4 mist_here;

void vertex() {
	vec3 centre_view = MODELVIEW_MATRIX[3].xyz;
	float away = max(length(centre_view), 0.0001);
	// The lamp's axis and the way to the eye, both in view space. The eye is the view's origin.
	vec3 axis = normalize(mat3(MODELVIEW_MATRIX) * vec3(0.0, 0.0, -1.0));
	vec3 to_eye = -centre_view / away;
	in_beam = smoothstep(beam_edge, beam_core, dot(axis, to_eye));
	// Full size in the beam, a quarter at its edge, and nothing outside it: a glare that is off costs no pixels.
	float radius = max(real_radius * 1.5, away * least_angle) * mix(0.25, 1.0, in_beam) * step(0.001, in_beam);
	corner = VERTEX.xy / quad_half;
	// PULLED TOWARDS THE EYE by its own radius, so a glare grown metres wide at range does not sink into the aeroplane
	// holding it -- never past half the way to the eye (beacon.gdshaderinc).
	vec3 offset_view = to_eye * min(radius, away * 0.5) + vec3(corner * radius, 0.0);
	mist_here = mist_along(EYE_POSITION_WORLD, MODEL_MATRIX[3].xyz, mist_clock);
	VERTEX = inverse(mat3(MODELVIEW_MATRIX)) * offset_view;
}

void fragment() {
	float r = length(corner);
	if (r > 1.0) {
		discard;
	}
	// A HARD CORE a third of the way out, in the lamp's colour pushed bright, and a soft halo round it. NOT WHITENED at
	// the middle, though that is how a real lamp photographs: tonemapped, a whitened red read as pink, and red against
	// white is the whole of what this light has to say.
	float core = 1.0 - smoothstep(0.42, 0.52, r);
	float halo = pow(1.0 - r, 1.5) * 0.9;
	// HALF WHAT THE MIST TAKES FROM A SURFACE: a lamp is far brighter than anything it is seen against, and a real one
	// burns through haze that greys a hillside. At the full share a red lamp 1.5 km off by day drew as a pale pink point.
	ALBEDO = mix(tint * energy * (0.6 + 0.4 * in_beam), mist_here.rgb, mist_here.a * 0.5);
	ALPHA = clamp(max(core, halo) * in_beam, 0.0, 1.0);
}
