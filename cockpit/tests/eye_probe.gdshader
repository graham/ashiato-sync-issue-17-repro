// WHERE THIS SHADER THINKS THE EYE IS, painted into a pixel for tests/eye_shot.gd to read back.
//
// Red is 1 when Godot's own CAMERA_POSITION_WORLD is within a metre of `truth`, the camera's position handed over from
// GDScript; green is 1 when the house's EYE_POSITION_WORLD (eye.gdshaderinc, from VIEW_MATRIX) is. On the stock editor
// both are; on the
// precision=double editor red is not, because that build hands shaders MINUS the camera in the inverse view matrix's
// translation, and CAMERA_POSITION_WORLD is read straight from it. See eye_shot.gd for the lines in Godot's source.
//
// The one file besides eye.gdshaderinc allowed to read CAMERA_POSITION_WORLD: reporting what the engine gives is its job.
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled;

#include "res://world/shaders/eye.gdshaderinc"

uniform vec3 truth = vec3(0.0);

void fragment() {
	float built_in = step(length(CAMERA_POSITION_WORLD - truth), 1.0);
	float from_view = step(length(EYE_POSITION_WORLD - truth), 1.0);
	ALBEDO = vec3(built_in, from_view, 0.0);
}
