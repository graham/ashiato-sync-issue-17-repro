// WHERE A BILLBOARD STANDS, EXACTLY, ON EITHER ENGINE: its positions worked out relative to its own origin, and placed
// through the camera-relative transform a precision=double Godot works out in emulated double precision.
//
// WHY. `VIEW_MATRIX * vec4(centre, 1.0)` with `centre` from MODEL_MATRIX is float32 on the GPU on either build, so on
// the double editor a quad riding a still craft 9.46 km out stepped on float32's grid -- a runway light on 58 frames of
// 90 (tests/shake_shot.gd) -- while a plain mesh beside it never moved. MODELVIEW_MATRIX's translation is the precise one.
//
// HOW. Do every sum relative to the instance's origin -- the centre is vec3(0.0) -- and hand the result to one of these:
//   BILLBOARD_EYE            the eye, relative to the instance's origin, in world axes (where EYE_POSITION_WORLD - centre
//                            was); both kinds below
//   BILLBOARD_VIEW_OF(off)   a point `off` from the origin, in view space, for VERTEX in a skip_vertex_transform shader
//   BILLBOARD_LOCAL_OF(off)  the same point in the instance's own space, for VERTEX in a shader WITHOUT skip_vertex_transform
//
//   BILLBOARD_LOCAL_FROM_VIEW(v)  a view-space offset from the origin, in the instance's own space (a quad that faces the view)
//
// WHICH. With skip_vertex_transform on a MULTIMESH, a double build bakes the instance into the model matrix and then
// applies it to MODELVIEW_MATRIX a second time (scene_forward_clustered.glsl), so MODELVIEW's translation is wrong for any
// instance with an origin -- and headless Godot cannot hold "these instances have none" for us: its dummy renderer reads
// every MultiMesh instance back as the identity. So:
//   no skip_vertex_transform + BILLBOARD_LOCAL_OF   every MULTIMESH, whatever its instances hold: contrail*, heavy_burst_*,
//                                                   ember_fine, and beacon (which works in view space throughout). The
//                                                   instance basis has to be invertible: see MissileYard.segment_basis.
//   skip_vertex_transform + BILLBOARD_VIEW_OF       a plain MeshInstance3D: missile_motor*, flame_fine.
// Reading MODEL_MATRIX's basis is safe in either.
//
// Macros, because a function outside a stage cannot read MODELVIEW_MATRIX. Inside vertex() only.
#ifndef BILLBOARD_GDSHADERINC
#define BILLBOARD_GDSHADERINC
#define BILLBOARD_EYE (-(transpose(mat3(VIEW_MATRIX)) * MODELVIEW_MATRIX[3].xyz))
#define BILLBOARD_VIEW_OF(off) (MODELVIEW_MATRIX[3].xyz + mat3(VIEW_MATRIX) * (off))
#define BILLBOARD_LOCAL_FROM_VIEW(v) (inverse(mat3(MODELVIEW_MATRIX)) * (v))
#define BILLBOARD_LOCAL_OF(off) BILLBOARD_LOCAL_FROM_VIEW(mat3(VIEW_MATRIX) * (off))
#endif
