// A PLAIN FIRE'S SMOKE: blended, not additive, because smoke HIDES what is behind it and additive smoke over a dark hillside
// is invisible. See fire_plain.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://world/shaders/fire_plain.gdshaderinc"
