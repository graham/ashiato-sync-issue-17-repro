extends RefCounted
class_name WaterSurface
## HOW ANY WATER IN THE GAME IS DRESSED: the ocean shader family, the plain finish's `ocean.gdshader` or the fine
## finish's `ocean_fine.gdshader`, handed the simulation's swell and the wind-sea exactly as the sea itself is.
##
## Asked for on 2026-09-17, after the first pictures of the wakes: "let's make sure we always use the good water
## shader". Until then the reel's river and the Savoia probe's pond were flat StandardMaterial3D blue, and the lakes of
## the generated ground were not drawn as water at all -- the ground shader coloured them by height and slope like any
## other ground. A wake laid on either lay on something that was not the sea it was tuned on.
##
## ONE PLACE, so a new pond cannot be a new blue: `dressed(fine)` for a material, `wear` to put one on a mesh, and
## `is_water(material)` for the check that holds every water surface to it (tests/water_surfaces.gd). A level may name
## the sea's colours in `level.json` (`LevelChart.water`); `dressed` reads them off the session's chart
## (`ChartDrawer.chart(Net.level)`), the same way the sky reads haze, rather than threading a chart through every pond
## and river. A channel the level does not name is never written, so both shaders keep the defaults they already had --
## those numbers live in the shader files, once.
##
## INLAND WATER IS STILL, AND IT SAYS SO. Both shaders move their vertices by the sea's swell, the wind-sea and -- on
## FINE -- four Gerstner waves of chop, all scaled by `sea_motion` (shaders/still_water.gdshaderinc). Until 2026-09-20
## the only thing keeping that off a lake was the geometric accident of the lake lying inside `land_half`, which is
## handed `Terrain.WORLD_HALF`, 7,200 m -- the ISLAND level's half-width -- on every level. The generated levels put
## their lakes out to 19 km, and `tests/rivers_survey.gd` measured THIRTY OF THE FIFTY-FOUR outside that band at full
## motion: a lake 15.3 km out and 27 m above the sea heaved with the open swell while the hull floating on it used the
## flat `Terrain.water_height`. So `dressed` and `wear` take `inland`, the caller says what the water is, and a lake is
## still wherever it lies. Withholding the swell would not have done it: `ocean_fine.gdshader`'s `swell_steepness`
## defaults to 0.15 in the shader itself.

const PLAIN: Shader = preload("res://world/shaders/ocean.gdshader")
const FINE: Shader = preload("res://world/shaders/ocean_fine.gdshader")


## A MATERIAL FOR WATER on a finish: the shader the finish's sea wears, with everything the sea is handed.
## Colours from `chart` if given, otherwise the session's level; a channel neither names is left to the shader.
## `inland` for a lake, a river or a pond: water that is not the sea and gets none of the sea's motion at any distance.
static func dressed(fine: bool, chart: LevelChart = null, inland: bool = false) -> ShaderMaterial:
	var wet := ShaderMaterial.new()
	wet.shader = FINE if fine else PLAIN
	wet.set_shader_parameter("land_half", Terrain.WORLD_HALF)
	wet.set_shader_parameter("inland", 1.0 if inland else 0.0)
	if fine:
		# A heading and not the wind, which is zero: see `Terrain.SWELL_HEADING`, and `SeaSwell._ready`.
		wet.set_shader_parameter("wind", Terrain.SWELL_HEADING)
	SeaSwell.hand_the_swell(wet)
	WindSea.hand(wet, WindSea.ships_wind())
	_colour(wet, chart if chart != null else ChartDrawer.chart(Net.level))
	return wet


## PUT WATER ON A MESH for a finish. Opaque and casting no shadow, as the sea is. `inland` as `dressed` takes it.
static func wear(water: GeometryInstance3D, fine: bool, chart: LevelChart = null, inland: bool = false) -> void:
	water.material_override = dressed(fine, chart, inland)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## THE LEVEL'S COLOURS ONTO A MATERIAL, only the channels it named. Unnamed ones stay the shader's default because
## they are never written -- a copy of those numbers here would be a second set that had to be kept in step.
static func _colour(wet: ShaderMaterial, chart: LevelChart) -> void:
	if wet == null or chart == null:
		return
	for field in chart.water:
		wet.set_shader_parameter("%s_colour" % String(field), chart.water[field])


## WHETHER A MATERIAL IS WATER DRAWN AS THE SEA IS: a ShaderMaterial wearing one of the two ocean shaders.
static func is_water(material: Material) -> bool:
	var wet := material as ShaderMaterial
	return wet != null and (wet.shader == PLAIN or wet.shader == FINE)


## WHETHER A MATERIAL WAS DRESSED AS INLAND WATER, for the check that every lake is. False for the sea and for anything
## that is not water at all.
static func is_inland(material: Material) -> bool:
	if not is_water(material):
		return false
	return float((material as ShaderMaterial).get_shader_parameter("inland")) > 0.5
