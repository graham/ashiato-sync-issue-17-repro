extends RefCounted
class_name AircraftVisualLod
## Manual range LOD for procedural fittings. Imported GLB scenes use Godot's generated
## mesh LOD; primitive fallback parts have no lower-detail surface to select.
##
## GeometryInstance3D documents disabled fade as the hysteresis path and notes that the
## self/dependency fade modes are unsupported by Mobile, this project's renderer:
## https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html

const SMALL_PART_END := 900.0
const MEDIUM_PART_END := 2400.0
const SMALL_PART_MAX := 2.5
const MEDIUM_PART_MAX := 5.0
const MARGIN_SHARE := 0.10


static func configure(part: MeshInstance3D) -> void:
	if part == null or part.mesh == null:
		return
	var size: Vector3 = part.mesh.get_aabb().size * part.scale.abs()
	var longest := maxf(size.x, maxf(size.y, size.z))
	var end := 0.0
	if longest <= SMALL_PART_MAX:
		end = SMALL_PART_END
	elif longest <= MEDIUM_PART_MAX:
		end = MEDIUM_PART_END
	if end <= 0.0:
		return
	part.visibility_range_end = end
	part.visibility_range_end_margin = end * MARGIN_SHARE
	part.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	# These small fittings do not cast a useful shadow at the distances where exterior
	# aircraft dominate the frame; disabling that pass also reduces their near draw cost.
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func drawn_at(part: MeshInstance3D, distance: float) -> bool:
	return part.visibility_range_end <= 0.0 or distance <= part.visibility_range_end
