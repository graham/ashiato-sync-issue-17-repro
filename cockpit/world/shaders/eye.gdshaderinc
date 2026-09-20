// WHERE THE EYE IS, IN THE WORLD, ON EITHER ENGINE: `EYE_POSITION_WORLD`, in place of CAMERA_POSITION_WORLD.
//
// THE GAME IS PLAYED ON A precision=double GODOT, and on that build Godot 4.7.2's Forward+ hands every shader stage
// MINUS the camera as CAMERA_POSITION_WORLD. The double build overwrites the translation of the scene's inverse view
// matrix with -camera, split into a float and a remainder (servers/rendering/renderer_rd/storage_rd/
// render_scene_data_rd.cpp, `split_double(-cam_transform.origin.x, ...)`), because its emulated-double
// `model origin + inv_view[3]` sum wants a camera-relative origin -- and CAMERA_POSITION_WORLD is renamed straight to
// `inv_view_matrix[3].xyz` (scene_shader_forward_clustered.cpp). The stock build hands the camera. Measured
// 2026-09-14 by tests/eye_shot.gd: CAMERA_POSITION_WORLD within a metre of the camera on stock, not on double, at the
// origin and 7 km out.
//
// WHAT IT BROKE: every size, fade and facing worked out from the eye. A runway light's radius is `away * least_angle`,
// and on double `away` was the distance to the eye's mirror image through the origin: seven kilometres out, a light
// 60 m off drew 141,818 px where the stock build drew 1,300 -- the cream domes in front of the threshold.
//
// THE ANSWER: VIEW_MATRIX, which both builds hand over whole (`store_transform_transposed_3x4(cam.affine_inverse(), ...)`,
// with nothing overwritten after), inverted here: a view matrix is [R | t] with t = -R * eye, so eye = -R^T * t. Float precision on
// the GPU, the same as the stock built-in: a millimetre at ten kilometres, for a size or a fade. In stereo it is the
// midpoint of the eyes, as CAMERA_POSITION_WORLD is, because the engine puts each eye's offset in its projection.
//
// REJECTED: MODELVIEW_MATRIX for the billboards, which on double is summed in emulated double precision and would have
// been steadier far out. With skip_vertex_transform on a multimesh the double build applies the instance transform to it
// TWICE (scene_forward_clustered.glsl bakes it into the model matrix, then multiplies it in again), and every billboard
// here is a multimesh with skip_vertex_transform.
//
// A MACRO, because a function outside a stage cannot read VIEW_MATRIX. Only usable inside vertex() and fragment().
// tests/lint.gd fails any other shader that reads CAMERA_POSITION_WORLD or INV_VIEW_MATRIX[3].
#ifndef EYE_GDSHADERINC
#define EYE_GDSHADERINC
#define EYE_POSITION_WORLD (-(transpose(mat3(VIEW_MATRIX)) * VIEW_MATRIX[3].xyz))
#endif
