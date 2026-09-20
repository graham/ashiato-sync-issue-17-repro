extends Node3D
class_name CloudBank
## THE CLOUDS AS FOG YOU CAN FLY INTO, NEAR THE EYE: one FogVolume over every thermal, drawn by the engine's froxel fog on
## Forward+, faded in as the eye comes close and the mesh cloud in the same place faded out.
##
## Asked for on 2026-09-14: cumulus you can fly into and lose the outside view. A LiftYard cloud is spheres drawn with their
## back faces culled, so from inside one the island is in plain view. Froxel fog extinguishes what is behind it -- but from a
## few kilometres the same fog is a soft blue-grey blob where the lumps are crisp (agents.md, "A cloud you can fly into").
## So THE MESH CLOUD FAR, THE FOG NEAR: `fog_share` of each cloud, from the eye's distance to its box, is how much of it is
## fog, and it is ANNOUNCED (`fog_share_changed`) for the level to hand to LiftYard, which dissolves that cloud's lumps.
##
## A CLOUD IS STILL LAID OUT BY `LiftYard.cloud_lumps`. Each volume is a box round its cloud's lumps, cut at the zone's top,
## and its material carries the same twenty-four lumps, so the fog is where the lumps were, on the base tests/air.gd holds, and
## nothing here puts a cloud where there is no lift. The noise only erodes inside that envelope.
##
## CLOUDS COME AND GO BY ZONE, keyed by `LiftYard.cloud_key`, not by a count: `gather` adds the zones it has not seen and
## removes the ones that have gone, so a world that streams its thermals in and out can hand it whatever is near.
##
## ONE MATERIAL A CLOUD: a fog shader cannot tell which cloud it is in, and each volume is dispatched on its own anyway.
##
## LIT AS THE MESH CLOUD IS, SO THE FADE IS ONE COLOUR. The fog's colour is `cloud_light` -- the lumps' own function, from
## `LiftYard.cloud_light`'s time of day and `LiftYard.cloud_light_shares` -- carried in ALBEDO divided by the light the
## engine will multiply it by (`engine_sun`). Measured across the fade on the clouds view's cloud, cloud pixels of the mesh
## just outside it against the fog just inside: (195, 201, 212) and (198, 204, 214) by day, (216, 178, 147) and (214, 174,
## 140) at evening, (17, 21, 32) and (19, 24, 35) at night. See `world/shaders/cumulus_fog.gdshaderinc` for the two
## engine-lit tries that were a different colour and the emission that was black at night.
##
## FINE ONLY. PLAIN is the mesh clouds, every one whole, and the environment's volumetric fog switched off: a headset starts
## PLAIN, and whether the froxel grid is right in two eyes is below the note in agents.md.
##
## WHAT WENT WRONG BEFORE: the prototype hid every mesh cloud and drew only fog, and the sky at three kilometres was blobs.

## A cloud's share changed: `key` is its `LiftYard.cloud_key`, `share` 0 (all mesh) to 1 (all fog).
signal fog_share_changed(key: Vector2i, share: float)

## `--clouds=fog` after the bare `--` asks for the fog back (see `asked_for`), `--clouds=lumps` is the mesh clouds alone,
## which is what every run gets now, and `--clouds=none` draws no cloud at all (the probe's reference pictures).
const FLAG: String = "clouds"
const FINE_SHADER: Shader = preload("res://world/shaders/cumulus_fog.gdshader")
## The smallest change in a share worth writing. A share at either end is always written when it arrives there.
const SHARE_STEP: float = 0.01
## Laps for the scenery probe; nothing unless it is running. See `world/stopwatch.gd`.
const STOPWATCH := preload("res://world/stopwatch.gd")

## The level's Environment, whose volumetric fog this switches on and sizes. Handed over before the bank is added.
var air: Environment = null

## key -> {"zone", "volume", "paint", "bounds", "lumps", "share"}.
var _clouds: Dictionary = {}
var _fine: bool = false
## Whether the environment was last dressed for FINE. See `wears_fine`.
var _dressed_fine: bool = false
## The look the fog was last lit by, or {} before the level has said.
var _look: Dictionary = {}
## How many times the fog's light has been written, ever, so a test can hold it still.
var light_writes: int = 0


## HOW THE FOG IS LIT AT A TIME OF DAY: `LiftYard.cloud_light`'s sun, sky and shade, the numbers the mesh clouds are lit by,
## written onto every cloud's material once per change -- and onto each new cloud as it is added.
func show_daylight(look: Dictionary) -> void:
	_look = look
	for key in _clouds:
		_light(_clouds[key]["paint"])
	light_writes += 1


func _light(paint: ShaderMaterial) -> void:
	if _look.is_empty():
		return
	var light: Dictionary = LiftYard.cloud_light(_look)
	for field in light:
		paint.set_shader_parameter(field, light[field])
	paint.set_shader_parameter("engine_sun", engine_sun(_look))


## THE SUN AS THE ENGINE LIGHTS FOG WITH IT at a time of day: the colour Daylight gives the DirectionalLight3D made linear,
## times its energy -- the two numbers `light_storage.cpp` multiplies (before its PI, which the shader's `sun_scale` carries).
static func engine_sun(p: Dictionary) -> Vector3:
	var linear: Color = (p["sun_colour"] as Color).srgb_to_linear()
	return Vector3(linear.r, linear.g, linear.b) * float(p["sun_energy"])


## What the fog is lit with now, off one cloud's material, for the tests; null with no cloud.
func fog_lit_with(field: String) -> Variant:
	for key in _clouds:
		return (_clouds[key]["paint"] as ShaderMaterial).get_shader_parameter(field)
	return null


func _ready() -> void:
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", _wear)
	_fine = finish != null and bool(finish.call("is_fine"))
	_dress_the_air(_fine)
	print("[clouds] fog volumes on %s" % RenderingServer.get_current_rendering_method())


## What `--clouds=` asked for, lower case, or "" for nothing asked.
static func asked_on_the_command_line() -> String:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0].to_lower() == FLAG:
			return parts[1].to_lower()
	return ""


## Whether this renderer can draw fog volumes at all.
static func can_draw() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


## WHETHER THE FOG CLOUDS ARE WANTED, which since 2026-09-15 means only when they are ASKED FOR.
##
## "Let's move back to the mobile renderer, disable all volumetrics and turn clouds back into solid objects, if we can
## preserve the fact that the user can't see out of them when inside that would be great. My goal is to remove features
## that the mobile renderer doesn't support and get back some of the lost framerate." The froxel grid costs its whole
## dispatch wherever a cloud is near the eye (agents.md, "What it costs": 0.14 ms a frame on the desktop, never timed in
## a headset, which is where the frames are wanted), and the Mobile renderer cannot draw a FogVolume at all.
##
## NOTHING OF THE FOG IS DELETED. This is the one predicate that stands in front of it, so `--clouds=fog` on a Forward+
## run brings all of it back exactly as it was, and every measurement in agents.md can be taken again. The default is
## off, on every renderer, so what a run draws does not depend on which renderer it started with.
##
## THE VIEW FROM INSIDE IS NOT THE FOG'S TO KEEP. A mesh cloud is spheres with their back faces culled, so from inside
## one the island would be in plain view -- and it is not, because the depth fog whites it out
## (`Daylight.show_in_cloud`, `FlightLevel._on_eye_in_cloud`), which is what PLAIN has always done and what a renderer
## with no volumetric fog has always got. See agents.md, "A cloud you can fly into".
static func asked_for(what: String) -> bool:
	return also_wanted or what == "fog"


## HOW A SUITE ASKS FOR THE FOG, since a test cannot put a word on the command line of the process running it. The seam
## every other one here has: `DeskRoom.starts_steam`, `Net.draw_code`, `MistEffect.lay_on`. A level reads `asked_for`
## and nothing reads this directly, so there is still one answer to "are the fog clouds built".
static var also_wanted: bool = false


## THE ZONES THERE ARE NOW: a cloud added for each one not yet here and removed for each one gone. Every share is said again
## afterwards, because the level calls this after LiftYard has rebuilt its batch with every lump whole.
func gather(zones: Array, wind: Vector3) -> void:
	var wanted: Dictionary = {}
	for zone in zones:
		wanted[LiftYard.cloud_key(zone)] = zone
	for key in _clouds.keys():
		if not wanted.has(key):
			remove_cloud(key)
	for key in wanted:
		if _clouds.has(key):
			_clouds[key]["share"] = -1.0
		else:
			add_cloud(wanted[key], wind)


## ONE CLOUD MORE, from its zone. Starts as all mesh; `_process` works out its share.
func add_cloud(zone: Dictionary, wind: Vector3) -> Vector2i:
	var key: Vector2i = LiftYard.cloud_key(zone)
	if _clouds.has(key):
		return key
	var lumps: Array[Dictionary] = LiftYard.cloud_lumps(zone, wind)
	var bounds: AABB = LiftYard.cloud_bounds(lumps)
	var volume := FogVolume.new()
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	volume.size = bounds.size
	volume.position = bounds.get_center()
	volume.visible = false
	add_child(volume)
	var paint: ShaderMaterial = _paint(lumps)
	volume.material = paint
	_clouds[key] = {"zone": zone, "volume": volume, "paint": paint, "bounds": bounds, "lumps": lumps, "share": -1.0}
	return key


## ONE CLOUD FEWER. Its lumps are told they are whole again first, in case the yard still draws them.
func remove_cloud(key: Vector2i) -> void:
	if not _clouds.has(key):
		return
	(_clouds[key]["volume"] as FogVolume).queue_free()
	_clouds.erase(key)
	fog_share_changed.emit(key, 0.0)


## The clouds there are, by key, for the tests.
func cloud_keys() -> Array:
	return _clouds.keys()


## What share of a cloud is drawn as fog now, read off its volume and material, for the tests: 0 for a hidden volume.
func fog_share_drawn(key: Vector2i) -> float:
	if not _clouds.has(key):
		return 0.0
	var cloud: Dictionary = _clouds[key]
	if not (cloud["volume"] as FogVolume).visible:
		return 0.0
	return float((cloud["paint"] as ShaderMaterial).get_shader_parameter("presence"))


## HOW MUCH OF A CLOUD IS FOG, from the eye's distance to its box in metres: all fog inside `FOG_FADE.x`, all mesh past
## `FOG_FADE.y`. Static and pure, so the bank and a test ask one function.
static func fog_share(distance: float) -> float:
	return 1.0 - smoothstep(CloudTuning.FOG_FADE.x, CloudTuning.FOG_FADE.y, distance)


## How far a point is from a box, 0 inside it.
static func distance_to(box: AABB, point: Vector3) -> float:
	return point.clamp(box.position, box.end).distance_to(point)


## EVERY CLOUD'S SHARE, FROM THE CAMERA THE VIEWPORT IS DRAWN WITH -- the midpoint of the eyes in a headset -- written when it
## moves by `SHARE_STEP` or reaches an end. A cloud with no fog in it has its volume hidden, so the froxels never run it.
func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var watch: int = STOPWATCH.start()
	var eye: Vector3 = camera.global_position
	var any_fog: bool = false
	for key in _clouds:
		var cloud: Dictionary = _clouds[key]
		var share: float = fog_share(distance_to(cloud["bounds"], eye)) if _fine else 0.0
		any_fog = any_fog or share > 0.0
		# THE EYE, FOR THE DETAIL NEAR IT, written only to a cloud that has fog in it -- one or two at a time.
		if share > 0.0:
			(cloud["paint"] as ShaderMaterial).set_shader_parameter("eye_at", eye)
		var was: float = float(cloud["share"])
		var at_an_end: bool = (share <= 0.0 or share >= 1.0) and share != was
		if absf(share - was) < SHARE_STEP and not at_an_end:
			continue
		cloud["share"] = share
		(cloud["volume"] as FogVolume).visible = share > 0.0
		(cloud["paint"] as ShaderMaterial).set_shader_parameter("presence", share)
		fog_share_changed.emit(key, share)
	# THE FROXELS RUN ONLY WHILE A CLOUD HAS FOG IN IT. The environment's volumetric fog costs its grid whether any volume is
	# in it or not: with every cloud all mesh from three kilometres, FINE's GPU timer read 0.609 ms against 0.489 with none
	# (the clouds view, 2026-09-14). Nearer than `FOG_FADE.y` to a cloud it is on; everywhere else, off.
	if air != null and air.volumetric_fog_enabled != any_fog:
		air.volumetric_fog_enabled = any_fog
	STOPWATCH.lap(&"cloud_bank", watch)


func _paint(lumps: Array[Dictionary]) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = FINE_SHADER
	# EACH LUMP'S CENTRE AND ITS THREE RADII -- along the cloud's heading, up, across -- and the heading, read off the first
	# lump's own long axis: every lump of a cloud is stretched along the same one (`LiftYard.cloud_lumps`).
	var at := PackedVector4Array()
	var radii := PackedVector3Array()
	for lump in lumps:
		var t: Transform3D = lump["transform"]
		var half: Vector3 = Vector3(t.basis.x.length(), t.basis.y.length(), t.basis.z.length()) * 0.5 * CloudTuning.FOG_SWELL
		at.append(Vector4(t.origin.x, t.origin.y, t.origin.z, half.x))
		radii.append(half)
	var long_axis: Vector3 = (lumps[0]["transform"] as Transform3D).basis.x
	var custom: Color = lumps[0]["custom"]
	paint.set_shader_parameter("lump_at", at)
	paint.set_shader_parameter("lump_radii", radii)
	paint.set_shader_parameter("heading", Vector2(long_axis.x, long_axis.z).normalized())
	paint.set_shader_parameter("billow_share", CloudTuning.FOG_BILLOW)
	paint.set_shader_parameter("near_detail", CloudTuning.FOG_NEAR_DETAIL)
	paint.set_shader_parameter("near_reach", CloudTuning.FOG_NEAR_REACH)
	# THE ENVELOPE ITS LUMPS ARE LIT THROUGH, so the fog's core is as dim as the mesh cloud's.
	var envelope: Dictionary = LiftYard.cloud_envelope(lumps)
	paint.set_shader_parameter("envelope_centre", envelope["centre"])
	paint.set_shader_parameter("envelope_radii", envelope["radii"])
	paint.set_shader_parameter("base_y", custom.r)
	paint.set_shader_parameter("thickness", custom.g)
	paint.set_shader_parameter("core_density", CloudTuning.FOG_CORE_DENSITY)
	paint.set_shader_parameter("erosion", CloudTuning.FOG_EROSION)
	paint.set_shader_parameter("noise_scale", CloudTuning.FOG_NOISE_SCALE)
	paint.set_shader_parameter("climb", CloudTuning.FOG_CLIMB)
	paint.set_shader_parameter("base_soft", CloudTuning.FOG_BASE_SOFT)
	paint.set_shader_parameter("lump_soft", CloudTuning.FOG_LUMP_SOFT)
	var shares: Dictionary = LiftYard.cloud_light_shares()
	for field in shares:
		paint.set_shader_parameter(field, shares[field])
	_light(paint)
	paint.set_shader_parameter("presence", 0.0)
	return paint


## Whether fog clouds are in play: the environment was last dressed with FINE's froxels. Not whether the fog is on this frame,
## which is only while a cloud is near (`_process`).
func wears_fine() -> bool:
	return air != null and _dressed_fine


## How many clouds there are, for the tests.
func volumes() -> int:
	return _clouds.size()


func _wear(fine: bool) -> void:
	_fine = fine
	_dress_the_air(fine)


## THE ENVIRONMENT'S VOLUMETRIC FOG: on and empty on FINE, so only the volumes put fog in the air; off on PLAIN. `sky_affect`
## is 1, not the brief's 0.35: nearly every cloud is seen against the sky, and at 0 the part of a cloud in front of the sky
## was not drawn at all (cloud_near, 2026-09-14).
func _dress_the_air(fine: bool) -> void:
	if air == null:
		return
	# OFF UNTIL A CLOUD HAS FOG IN IT: `_process` turns it on. PLAIN leaves it off.
	air.volumetric_fog_enabled = false
	_dressed_fine = fine
	if not fine:
		return
	air.volumetric_fog_density = 0.0
	air.volumetric_fog_albedo = Color.WHITE
	air.volumetric_fog_emission = Color.BLACK
	air.volumetric_fog_anisotropy = CloudTuning.FOG_ANISOTROPY
	air.volumetric_fog_length = CloudTuning.FOG_LENGTH
	air.volumetric_fog_detail_spread = CloudTuning.FOG_DETAIL_SPREAD
	air.volumetric_fog_gi_inject = 0.0
	air.volumetric_fog_ambient_inject = 0.0
	air.volumetric_fog_sky_affect = 1.0
	air.volumetric_fog_temporal_reprojection_enabled = true
	air.volumetric_fog_temporal_reprojection_amount = CloudTuning.FOG_REPROJECTION
	RenderingServer.environment_set_volumetric_fog_volume_size(CloudTuning.FOG_FROXELS.x, CloudTuning.FOG_FROXELS.y)
