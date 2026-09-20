// THE SLOPE A STEP IS PART OF, for both rock finishes. Needs a `varying vec4 peak` (INSTANCE_CUSTOM: the peak's
// centre x and z, its crown and its summit) and a `varying float riser` (the box's own height).
//
// THE MOUNTAINS ARE BOXES AND STAY BOXES: every one is also collision, and a smooth surface drawn over them would sit
// 18 to 38 m clear of the rock a shell stops against (agents.md, THE SCENERY HAS TWO FINISHES). So nothing here moves
// a vertex. What reads as a stepped pyramid from a distance is that each box is lit on its own -- every tread as
// bright as every other, every wall as dark -- so a step is lit here, in part, as the slope through the outer lip of
// every layer, which `Terrain._peak` knows and hands over once, at build.
//
// And HOW FAR UNDER THAT SLOPE a point lies, in risers, is the one number a box cannot know about itself and a
// mountain is shaped by: nothing at an exposed lip, about one riser in the inner corner a tread makes with the wall
// above it. The corner darkens by it, scree lies in it, snow gathers in it, and a wall's stains run from its top.
//
// A PLAN, NOT A CONE: the distance from the centre is a superellipse, so a flank of rectangular layers is lit as a
// flank rather than rounded off. A box with no peak (concrete) carries a summit of zero and gets w = -1: untouched.

uniform float envelope_slope = 2.0;
uniform float plan_power = 4.0;

// xyz: the slope's world normal. w: how far under the slope, in risers, or -1 for a box with no peak.
vec4 peak_slope(vec3 at, vec4 peak_data, float riser_height) {
	if (peak_data.w <= 0.0) {
		return vec4(0.0, 1.0, 0.0, -1.0);
	}
	vec2 off = at.xz - peak_data.xy;
	vec2 a = abs(off) + vec2(0.01);
	float r = pow(pow(a.x, plan_power) + pow(a.y, plan_power), 1.0 / plan_power);
	float rising = peak_data.z - envelope_slope * r;
	float surface = min(rising, peak_data.w);
	float under = max(surface - at.y, 0.0) / max(riser_height, 1.0);
	if (rising >= peak_data.w) {
		return vec4(0.0, 1.0, 0.0, under);
	}
	vec2 along = sign(off) * pow(a / r, vec2(plan_power - 1.0));
	return vec4(normalize(vec3(along.x * envelope_slope, 1.0, along.y * envelope_slope)), under);
}
