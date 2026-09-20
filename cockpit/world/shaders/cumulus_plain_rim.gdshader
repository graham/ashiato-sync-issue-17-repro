// CUMULUS, ON THE PLAIN FINISH, ITS RIM: the soft edge round the core, blended, drawn as the core's next pass. See
// cumulus_plain_lump.gdshaderinc.
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never;

#define RIM_PASS
#include "res://world/shaders/cumulus_plain_lump.gdshaderinc"
