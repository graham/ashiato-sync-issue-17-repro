// TREES, ON THE FINE FINISH: forest.gdshaderinc with FINE defined, which adds the whole-tree bend in
// the wind. The tiers, lean and shading are in the mesh and the instances `world/woodland.gd` builds
// for this finish, not branches here -- one shader file per finish, never a uniform bool.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

#define FINE
#include "res://world/shaders/forest.gdshaderinc"
