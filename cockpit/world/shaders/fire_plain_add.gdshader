// A PLAIN FIRE'S FLAMES AND GLOW: additive, so two overlapping flames are brighter than one. See fire_plain.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#define ADDITIVE
#include "res://world/shaders/fire_plain.gdshaderinc"
