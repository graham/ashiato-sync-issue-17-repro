// VISIBILITY LIGHTS, FINE, THE HALO: a soft blended ring round the core beacon_fine draws,
// brightened by the flash. Hung on the fine light material as its next pass, so PLAIN never draws
// it. Blended rather than added so it keeps the light's colour over a pale sky; writing no depth
// so it never hides what is behind it; and kept off the core, so the core stays the light's own
// colour. See beacon.gdshaderinc and beacon_fine.gdshader.
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled,
	blend_mix, depth_draw_never;

#define FINE
#define HALO
#include "res://world/shaders/beacon.gdshaderinc"
