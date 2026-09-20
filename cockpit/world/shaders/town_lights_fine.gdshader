// A TOWN'S FAR LIGHTS, FINE: warm lamps and cool screens. See town_lights.gdshaderinc, which is the whole of it with FINE defined.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#define FINE
#include "res://world/shaders/town_lights.gdshaderinc"
