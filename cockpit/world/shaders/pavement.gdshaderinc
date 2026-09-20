// WHAT A PAVEMENT LOOKS LIKE WHEN YOU ARE NEAR ENOUGH TO SEE IT: the seams between paving lanes, the transverse
// joints, and the rubber a few thousand landings have laid down in the touchdown zone. The pieces only; each of the
// two pavement shaders composes them, PLAIN with the cheap half and FINE with all of it.
//
// WHAT WAS THERE BEFORE: nothing. The runway's paint and the air bases' pavement are both a MultiMesh of coloured unit
// boxes on a bare StandardMaterial3D (`Sky._draw_runway`, `AirbaseView`), so the asphalt was one flat dark grey from a
// metre up and from three thousand feet alike. The markings were never the problem -- the centreline, the threshold
// bars and the taxiway paint are already laid as geometry by `Terrain.runway_marks_for` and `AirbaseView`, at every
// distance. What was missing was the SURFACE.
//
// THE DISTANCE IS `length(VERTEX)` IN `fragment()`, AND THAT IS WHY IT CANNOT BE WRONG ON THIS BUILD. In a spatial
// fragment shader VERTEX is the fragment in VIEW space, where the camera is the origin by construction, so its length
// is the distance to the eye without anything ever naming the camera. That matters more than it sounds: this whole
// feature is "how far is this pixel from the camera", and `CAMERA_POSITION_WORLD` is MINUS the camera on a
// precision=double Godot (`eye.gdshaderinc`, and `tests/lint.gd` fails any shader that reads it). The neighbouring
// shaders reach for `EYE_POSITION_WORLD` because they need the eye's WORLD position for other reasons; this one needs
// only a distance, and a construction that cannot express the bug is better than one that has to remember to avoid it.
//
// REJECTED: COMPUTING THE FADE IN `vertex()` AND LETTING THE INTERPOLATOR CARRY IT. That is the standard cheap trick
// and it is wrong here. The runway's asphalt is ONE instance of a unit box scaled to 900 m, so it has vertices only at
// its four corners; interpolating a distance between them gives a linear ramp down the length of the runway instead of
// a ring round the camera, and the detail would appear at one end of the strip and not the other. Per-pixel it is one
// `length()` of a value the fragment stage already holds, which is nothing.
//
// REJECTED: A SEPARATE SHADER PER DISTANCE BAND, the way `Finish` gives each tier its own shader. `Finish`'s argument
// is that a tier is uniform for a whole run, so you pick the shader once at build and the other path's registers are
// never allocated -- and that argument does not transfer, because THERE IS NO SEAM TO SPLIT ON. Near and far pixels
// are in the same draw call, the same triangle and the same frame: the slab you are standing on is one box 900 m long,
// and splitting it would mean re-cutting the geometry every frame as the camera moves, which costs far more than the
// branch saves. What DOES transfer is the mechanism underneath `Finish`'s decision -- the cost of a mega-shader on a
// tile-based mobile GPU is register pressure, not branch cost, because the compiler allocates for the worst path and
// occupancy drops for every pixel. So the near path is written SHALLOW rather than merely skipped: one `smoothstep`
// for the fade, and a branch on it that is spatially coherent, since ground distance varies smoothly and whole
// wavefronts take the same side of it.
#ifndef PAVEMENT_GDSHADERINC
#define PAVEMENT_GDSHADERINC

// THE PAVEMENT'S OWN DIMENSIONS, as constants here and not as uniforms on each shader: both tiers draw the same
// runway, so a spacing that lived on each of them would be the same number typed twice, and none of these is a thing
// anybody tunes at runtime -- they are how wide a paving machine is.
//
// A paving lane is 12 to 15 ft; 3.75 m is the middle of that. Transverse construction joints fall where a day's
// paving stopped, tens of metres apart. Both grooves are the width of a sealed joint, about 30 mm.
const float PAVING_LANE = 3.75;
const float PAVING_STOP = 38.0;
const float JOINT_WIDTH = 0.03;
// HALF A LANE OFF THE CENTRELINE, so the centreline stripe sits in the middle of a paving lane and not astride a
// joint. Without it the grid falls at x = 0 and a dark groove ran straight down the middle of the white paint for
// the length of the runway -- which the first pictures showed at once and no test would ever have asked about.
const float PAVING_OFFSET = PAVING_LANE * 0.5;
// How much a groove darkens what it crosses, and how much the rubber does at its blackest.
const float JOINT_DARK = 0.40;
const float RUBBER_DARK = 0.68;
// THE TOUCHDOWN ZONE: its middle this far in from the threshold and about this much of it, which is where a wheel
// first touches on a strip this length. Rubber only over the middle of the strip -- full inside the first number
// metres of the centreline, gone by the second, which is where a light twin's and an airliner's main gear both fall.
const vec2 RUBBER_ZONE = vec2(250.0, 200.0);
const vec2 RUBBER_WHEELS = vec2(8.0, 16.0);
// How coarse the blotching of the rubber is, and of the aggregate in the asphalt: cycles per metre.
const float BLOTCH_SCALE = 0.06;
const float GRAIN_SCALE = 3.1;

// A PORTLAND CEMENT CONCRETE SLAB, which is what a military taxiway and apron are: laid in a grid rather than in
// lanes, so the joints run both ways at one spacing. 6.10 m is the 20 ft bay airfield concrete is usually poured in,
// and it is the same number `AirbaseView.PILASTER_BAY` uses for a hangar's structural bay because both are 20 ft.
const float CONCRETE_BAY = 6.10;
// Concrete is paler and smoother than asphalt, so its joints read harder and its grain reads softer.
const float CONCRETE_JOINT_DARK = 0.30;

// sRGB TO LINEAR, BECAUSE THE PAVEMENT'S TWO CALLERS DISAGREE AND BOTH ARE RIGHT.
//
// `AirbaseView._vertex_colour` sets `vertex_color_is_srgb = true` and `Sky._draw_runway` does NOT. That is not an
// oversight in either: the air base's colours were picked by eye against a picture and read as white when they were
// taken as linear (airbase_view.gd, 2026-09-17), and the runway's were picked against the shader that already took
// them raw. A StandardMaterial3D does this conversion for one caller and not the other; a custom shader is handed
// COLOR raw both times and has to do it itself.
//
// SO THE CONVERSION LIVES IN THE CONCRETE SHADERS AND NOT IN THE RUNWAY'S, and this comment exists because a shared
// pavement shader that quietly applied it to both -- or to neither -- would shift every colour on one of them, and
// a uniform gamma shift across a whole air base is the kind of fault that looks like the lighting.
//
// The piecewise sRGB transfer, matching what the engine does for `vertex_color_is_srgb` rather than an approximation,
// so the concrete comes out the colour it was before this lane to the bit.
vec3 pavement_srgb_to_linear(vec3 colour) {
	return mix(pow((colour + vec3(0.055)) / vec3(1.055), vec3(2.4)), colour / vec3(12.92),
		lessThan(colour, vec3(0.04045)));
}

// WHERE A PIXEL IS ON ITS RUNWAY, in metres: x across the strip from the centreline, y along it from the middle.
//
// The frame comes from the instance's custom data rather than from the instance's own space, and it has to. Each
// painted stripe is its own little box a few metres long, so in ITS space the runway's middle is wherever that stripe
// is -- the rubber would restart under every centreline mark. Handed the runway's centre and bearing instead, a stripe
// and the asphalt under it work out the same coordinate and the detail runs through both unbroken.
//
// The axes are `Terrain.runway_frame`'s: `along` is `nose_from_yaw(bearing)`, which is (-sin b, 0, -cos b) -- a
// COMPASS bearing, so bearing 0 points north, which is -z -- and `across` is (cos b, 0, -sin b). This is the offset
// dotted with those two. `tests/pavement.gd` asserts both against the frame the terrain laid, which is how the sign
// below was found: it was written from `Basis(Vector3.UP, bearing)`'s own +z, which is the opposite way up the strip,
// and the test reported a unit vector exactly 2.0 from the one it should have been.
//
// Worked out in `vertex()` by both shaders and carried as a varying: it is an affine function of position, so
// interpolating it across a flat slab is exact, which the DISTANCE above is not.
vec2 pavement_on_runway(vec2 world_xz, vec2 centre_xz, float bearing) {
	vec2 from_centre = world_xz - centre_xz;
	float c = cos(bearing);
	float s = sin(bearing);
	return vec2(from_centre.x * c - from_centre.y * s, -(from_centre.x * s + from_centre.y * c));
}

// ONE SET OF PARALLEL GROOVES, anti-aliased to the pixel: 1 in a groove, 0 on the slab between them.
//
// `fwidth` is the whole reason this does not crawl. A seam 30 mm wide seen from 200 m covers a hundredth of a pixel,
// and a smoothstep with a fixed soft edge would draw it at full strength on whichever pixels happened to land on it --
// a dotted line that swims as the head moves, which is the most obvious artefact there is in a headset and exactly
// what house rule 3 for this job forbids. Widening the soft edge to one pixel instead makes a sub-pixel seam come out
// proportionally fainter and then vanish, which is what a real one does.
float pavement_seam(float across_them, float spacing, float width) {
	float from_middle = abs(fract(across_them / spacing + 0.5) - 0.5) * spacing;
	float pixel = fwidth(across_them);
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + pixel, from_middle);
}

// THE RUBBER IN THE TOUCHDOWN ZONE: 0 on clean pavement, 1 in the black of it.
//
// Laid where the wheels arrive and nowhere else: a band `zone.x` metres in from each threshold and about `zone.y`
// metres of it, and only over the middle of the strip where the main gear runs -- the edges of a runway stay the
// colour the asphalt is, which is what makes the dark patch read as rubber rather than as a shadow. `blotch` is noise
// the caller chooses the cost of: one octave on PLAIN, two on FINE.
//
// It darkens the PAINT as well as the asphalt, because the stripes are instances of the same pavement and work out the
// same coordinate. That is not a compromise, it is what happens: the touchdown zone markings on a busy runway are
// half scrubbed out by rubber, and the ones outside it are not.
/// WHERE THE RUBBER COULD BE, before any noise is paid for: band times tracks, 0 outside the touchdown zone.
///
/// SPLIT OUT FROM THE BLOTCHING ON PURPOSE. The rubber only exists over a couple of hundred metres in the middle of a
/// strip that is nine hundred long and inside sixteen metres of a centreline on one forty-five wide, so on the great
/// majority of pavement pixels the answer is exactly zero -- and the noise that blotches it was being computed for
/// every one of them before the multiply threw it away. Four hash lookups a pixel to be multiplied by nothing.
/// Measured in `tests/pavement_cost.gd`, mode `fill`, which is the view this costs most in.
float pavement_rubber_mask(vec2 on_runway, float half_length, vec2 zone, vec2 wheels) {
	float from_threshold = half_length - abs(on_runway.y);
	float band = 1.0 - smoothstep(zone.y * 0.5, zone.y, abs(from_threshold - zone.x));
	float tracks = 1.0 - smoothstep(wheels.x, wheels.y, abs(on_runway.x));
	return band * tracks;
}

#endif
