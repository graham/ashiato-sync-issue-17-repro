// WHERE A TOWN'S LIGHTS GO FROM ITS WALLS TO ITS FAR LIGHTS: the one function both sides of the handover read.
//
// A lit window is drawn by the building's own fragment shader (building.gdshaderinc) out to `windows_to`, and past it by
// a point of light standing off the wall (town_lights.gdshaderinc). Across the band between, the wall gives up exactly the
// share the point takes, from the same `windows_to` handed to both materials from TownTuning, so no distance draws a town
// with neither or with both at full. Until 2026-09-15 the wall's lights faded over this band to nothing better than a
// third of their average -- the dim orange blocks -- and nothing took over.
#ifndef TOWN_HANDOVER_GDSHADERINC
#define TOWN_HANDOVER_GDSHADERINC

// The share of a town's light the far lights carry `away` metres from the eye: 0 inside 0.55 of `windows_to`, 1 past it.
float town_far_share(float away, float windows_to) {
	return smoothstep(windows_to * 0.55, windows_to, away);
}

#endif
