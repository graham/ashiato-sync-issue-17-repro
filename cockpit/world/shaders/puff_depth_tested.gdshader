// A CLOUD PUFF, DEPTH TESTED: no depth texture read, the engine's depth test against its back faces instead. The cheaper
// and worse of the two; see puff.gdshaderinc.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, shadows_disabled;

#include "res://world/shaders/puff.gdshaderinc"
