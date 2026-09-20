// A CLOUD LUMP'S EDGE, FILTERED OVER THE PIXEL: how opaque the blended rim is, and where the opaque core may begin, from the
// lump's coverage (0 at the silhouette, rising inwards) and how much it changes across one pixel. Shared by FINE's and PLAIN's
// lumps (cumulus_lump.gdshaderinc, cumulus_plain_lump.gdshaderinc), both passes.
//
// WHY (team-lead off glassrim-zoom4, 2026-09-15): along a lump's top edge seen from above the coverage rises from 0 to past the
// core's cut inside a pixel or two, so the rim's ramp was narrower than a pixel and the core's hard cut stair-stepped, and would
// crawl between the eyes. PLAIN, the headset's default, has no MSAA, so alpha to coverage cannot help it. Instead the rim's
// alpha is its ramp clamp(coverage / core) AVERAGED OVER THE PIXEL'S FOOTPRINT, coverage +- half its fwidth -- exact for a
// linear ramp -- and the core only starts where the whole footprint is past the cut, where that average is 1. Where the ramp
// is many pixels wide this is the ramp itself; where it is less than one, the pixel gets its share, a one-pixel blend.
// Everything here is per pixel and per eye only through fwidth, which is the pixel's own size: nothing is hashed or dithered.

#ifndef CLOUD_RIM_GDSHADERINC
#define CLOUD_RIM_GDSHADERINC

// The integral of clamp(x / core, 0, 1) from 0 to x.
float cloud_rim_ramp_integral(float x, float core) {
	if (x <= 0.0) {
		return 0.0;
	}
	if (x < core) {
		return x * x / (2.0 * core);
	}
	return x - core * 0.5;
}

// How much the coverage changes across a pixel, never nothing.
float cloud_rim_footprint(float coverage) {
	return max(fwidth(coverage), 1e-4);
}

// The rim's alpha: the ramp averaged over the pixel.
float cloud_rim_alpha(float coverage, float core, float footprint) {
	float half_width = footprint * 0.5;
	return clamp((cloud_rim_ramp_integral(coverage + half_width, core)
		- cloud_rim_ramp_integral(coverage - half_width, core)) / footprint, 0.0, 1.0);
}

// Where the core is cut: where the pixel's whole footprint is past `core`, so the rim under it is whole.
float cloud_core_cut(float core, float footprint) {
	return core + footprint * 0.5;
}

#endif
