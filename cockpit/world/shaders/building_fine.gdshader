// A BUILDING, FINE. See building.gdshaderinc, which is the whole of it with FINE defined.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

#define FINE
#include "res://world/shaders/building.gdshaderinc"
