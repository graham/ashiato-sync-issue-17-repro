// VISIBILITY LIGHTS, FINE, THE CORE: the plain opaque dot in the plain colour, a third larger,
// with the strobes and the approach rabbit flashing. See beacon.gdshaderinc.
//
// OPAQUE, LIKE PLAIN, AND THE SAME COLOUR, which took three tries and a measurement to arrive at.
// An additive halo washed red to pink over the pale sky. A blended core with a little white mixed
// into it -- 8 % -- was still pink, and render_check_3 (2026-09-12) measured it: every PLAIN red
// light's core pixel was (255, 124, 102) and 163 to 251 pixels a view passed a red test, while
// every FINE one was about (255, 150, 136) and none passed. A uniform shift on dozens of lights is
// a colour, not multisampling. So the core is now drawn exactly as PLAIN draws it, and the halo
// is a second pass that goes round it: beacon_halo.gdshader.
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled;

#define FINE
#include "res://world/shaders/beacon.gdshaderinc"
