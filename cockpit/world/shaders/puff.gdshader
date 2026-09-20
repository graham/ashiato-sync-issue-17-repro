// A CLOUD PUFF, CUT AT THE WORLD: the depth test off and each chord ended at the depth buffer's surface, so a hill or an
// aeroplane inside a cloud is fogged by exactly the cloud in front of it. See puff.gdshaderinc.
shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, depth_draw_never, blend_mix, shadows_disabled;

#define CUT_AT_THE_WORLD
#include "res://world/shaders/puff.gdshaderinc"
