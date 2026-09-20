extends Node3D
## Windowed visual evidence for the road vehicles, and the pictures a reader can DISPUTE.
##
##   tools\gate_run.ps1 -Probe road_vehicles_shot
##   Godot --path cockpit --xr-mode off --resolution 1600x900 res://tests/road_vehicles_shot.tscn -- --out=C:/somewhere
##
## NOT HEADLESS -- headless has no rendering device, so the files come back black or the run hangs waiting for a frame
## that never draws. `tests/road_vehicles.gd` holds everything about these models that can be asserted; this renders the
## thing no suite can see, which is whether a 232-triangle box with eight-sided wheels actually READS as a car.
##
## WHAT IT SHOWS, and why each is the picture somebody would ask for:
##
##   01  THE LINE-UP AT ONE SCALE, three-quarter, the whole fleet side by side on tarmac with a 1.80 m figure at the
##       end of the row. **The figure is the whole point of this picture**: "is this the right size" is a question no
##       number answers as well as something known standing next to it, and these are the first things in this game that
##       a person is a useful ruler for.
##   02  THE SAME ROW FROM ABOVE, which is how nearly every one of these will actually be seen -- from an aeroplane. A
##       car from above is a roof, a windscreen, a backlight and four dark patches, and if it does not read from here it
##       does not matter what it looks like from anywhere else.
##   03  EYE HEIGHT AND CLOSE, a metre and a half up alongside the row: the view from a cockpit waiting at a hold, and
##       the only one in which the arches, the tyre and the glass are large enough to judge.
##   04  EVERY SILHOUETTE, orthographic from the SIDE, flat and unshaded, all at one scale on one
##       page, parked nose to tail. This is the picture that settles whether the four body styles are four body styles
##       -- and a side elevation is the only view that settles it, which is why `_row` is told which way to spread.
##
## A SubViewport with its OWN World3D for each, because without it every stage shares the parent's world and each
## WorldEnvironment fights the others (`lane/prowler`). AMBIENT_SOURCE_COLOR reads `ambient_light_color`, which defaults
## to BLACK, so both are set. `falcon_shot.gd` is the file this is built from.

const SILHOUETTE := Color(0.10, 0.11, 0.13)
## A person, for scale. 1.80 m is a tall-ish adult and is a round number a reader can hold in their head; it is drawn as
## two boxes because it is a RULER and not a model, and a badly drawn figure would be the thing people looked at.
const PERSON_TALL: float = 1.80
## HOW MUCH DAYLIGHT BETWEEN ONE VEHICLE AND THE NEXT. The SPACING itself is not a constant and must not be: it is this
## plus the longest vehicle in the catalogue, ASKED of the catalogue. A fixed 7.4 m was ample for four cars and put the
## articulated vehicle straight through the van -- an artic is 16.48 m long, and how long the fleet's longest member is
## is not something a picture should have to be told separately.
const GAP: float = 2.6
## HOW WIDE THE SILHOUETTE PAGE MAY BE, in pixels. The SCALE follows from it and from how long the row turns out, rather
## than the other way about, and the scale that came out goes in the FILENAME so a reader can still lay a ruler on the
## picture and get metres off it. Four cars fitted a page at 100 px a metre; seven vehicles including an artic do not,
## and there is no reason they should have to.
const PAGE_WIDE: int = 3800


## WHERE EACH VEHICLE STANDS ALONG THE ROW, as an offset from the row's middle: laid END TO END, each
## taking exactly its own length plus a gap.
##
## **NOT ONE SPACING FOR ALL OF THEM.** Spacing everything by the LONGEST -- the 16.48 m artic -- put
## the hatchback 19 m from the saloon, made the row 114 m long, and left the cars as specks at the
## edge of a frame mostly full of tarmac. A fixed 7.4 m before that had drawn the artic through the
## van. A row of parked vehicles is not evenly spaced; it is packed, and each takes the room it needs.
static func places() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var at: float = 0.0
	for row in RoadFleet.TYPES:
		var length: float = float(row["length"])
		out.append(at + length * 0.5)
		at += length + GAP
	var middle: float = (at - GAP) * 0.5
	for i in range(out.size()):
		out[i] -= middle
	return out


## The longest vehicle in the catalogue: what a frame has to fit across its SHORT side.
static func longest() -> float:
	var most: float = 0.0
	for row in RoadFleet.TYPES:
		most = maxf(most, float(row["length"]))
	return most


## How long the whole row is, nose of the first to tail of the last.
static func span() -> float:
	var total: float = 0.0
	for row in RoadFleet.TYPES:
		total += float(row["length"]) + GAP
	return total - GAP


## HOW FAR BACK A CAMERA HAS TO STAND to get `across` metres into a frame `fov` degrees tall at this
## aspect, plus a margin. Worked out rather than guessed: a row whose length depends on the catalogue
## cannot be framed from a distance that does not.
static func standing_back(across: float, fov: float, size: Vector2i, margin: float) -> float:
	var vertical: float = deg_to_rad(fov) * 0.5
	var horizontal: float = atan(tan(vertical) * float(size.x) / float(size.y))
	return (across * 0.5 * margin) / tan(horizontal)

var out := ""
var failures: PackedStringArray = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../screenshots/%s" % Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(out)

	# A FRONT three-quarter: the eye goes to -Z, which is the way every vehicle in this project faces. Behind the row it
	# is looking at seven sets of tail lamps, which is a photograph of the least characteristic end of a vehicle. Every
	# distance is a share of the row's own length, so a longer fleet steps the camera back instead of cropping itself.
	var wide := Vector2i(2200, 900)
	var back: float = standing_back(span(), 40.0, wide, 1.18)
	await _lit("cockpit-roadfleet-01-line-up-with-a-person-for-scale.png", wide,
		Vector3(-span() * 0.10, back * 0.30, -back), Vector3(0.0, 1.2, 0.0), 40.0)
	# FROM ABOVE, AND ONLY JUST OFF VERTICAL. The camera cannot look straight down -- `look_at` with the
	# view along its own up vector is degenerate -- so it stands a little aft. How little matters: at a
	# tenth of the row it tilted 9.5 degrees, and the near end of a 16.5 m artic then fell outside the
	# frame's short side while every car sat comfortably inside it. The offset is a share of the
	# LONGEST VEHICLE rather than of the row, because the longest vehicle is what has to fit.
	await _lit("cockpit-roadfleet-02-the-row-from-above.png", wide,
		Vector3(0.0, standing_back(span(), 40.0, wide, 1.14), longest() * 0.12),
		Vector3(0.0, 0.0, 0.0), 40.0)
	# EYE HEIGHT AND CLOSE: not the whole row, on purpose. This is the only view in which a tyre, an
	# arch and a pane of glass are big enough to judge, and framing all seven would throw that away.
	await _lit("cockpit-roadfleet-03-at-eye-height-alongside.png", Vector2i(1600, 900),
		Vector3(-span() * 0.30, 1.60, 11.0), Vector3(span() * 0.06, 1.30, -1.0), 52.0)
	await _silhouettes("cockpit-roadfleet-04-every-silhouette-at-%dpx-per-m.png")

	print("[road_vehicles_shot] RESULT=%s into %s" % ["PASS" if failures.is_empty() else "FAIL", out])
	get_tree().quit(0 if failures.is_empty() else 1)


func _stage(size: Vector2i, background: Color, ambient: Color, energy: float) -> SubViewport:
	var stage := SubViewport.new()
	stage.size = size
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.own_world_3d = true
	add_child(stage)
	# THE BUILD STAMP IN THE LOWER RIGHT, as in every picture the game takes (`BuildStamp`, 2026-09-18): this stage is a
	# viewport of its own, which the root's stamp is not drawn into.
	BuildStamp.attach_to(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = energy
	environment.environment = env
	stage.add_child(environment)
	return stage


## `into` IS A `Node`, NOT A `Node3D`, in all three of these helpers: a `SubViewport` is a `Viewport`, which is a
## `Node` and NOT a `Node3D`, so a stage cannot be passed to anything typed as one. The parse error it gives --
## "argument 1 should be Node3D but is SubViewport" -- HANGS the run rather than failing it, because the scene never
## loads and the window never closes, and the `.console.exe` wrapper's child goes on spinning after the launcher is
## killed (`running_a_team_here.md`). Match the child by its worktree path on the command line, never by process name.
##
## THE ROW, in catalogue order, each standing on the tarmac at y = 0 -- which is the model's own origin and needs no
## lift, and is exactly the claim `tests/road_vehicles.gd` makes about every one of them. A car sunk into the road or
## floating over it would show here before it showed anywhere else.
## **`along` IS WHICH WAY THE ROW IS SPREAD, AND IT IS NOT A STYLE CHOICE.** A camera sees four things side by side only
## when they are separated ACROSS its own view. The lit views look down the Z axis, so their row runs along X; the
## silhouette view looks along X to see a vehicle's SIDE, so its row must run along Z -- four cars parked nose to tail.
## Laid out along X and photographed from -Z, "the four silhouettes at one scale" came back as four FRONT views: a
## perfectly good picture of something nobody asked for, which shows nothing about a roofline at all.
func _row(into: Node, flat: bool, along: Vector3) -> void:
	var names: Array[StringName] = RoadFleet.names()
	var along_row: PackedFloat32Array = places()
	var material: StandardMaterial3D = Pressing.painted()
	if flat:
		material = StandardMaterial3D.new()
		material.albedo_color = SILHOUETTE
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(names.size()):
		var drawn := MeshInstance3D.new()
		drawn.mesh = RoadFleet.mesh(names[i])
		drawn.material_override = material
		drawn.position = along * along_row[i]
		into.add_child(drawn)


## A FIGURE 1.80 m TALL, as a ruler. Two boxes and nothing else: see the doc block.
func _person(into: Node, at: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var coat := Color(0.30, 0.34, 0.42)
	var head := Color(0.62, 0.50, 0.42)
	Plating.box(tool, Vector3(0.0, PERSON_TALL * 0.36, 0.0), Vector3(0.44, PERSON_TALL * 0.72, 0.26), coat)
	Plating.box(tool, Vector3(0.0, PERSON_TALL * 0.86, 0.0), Vector3(0.20, PERSON_TALL * 0.16, 0.20), head)
	var drawn := MeshInstance3D.new()
	drawn.mesh = Plating.weld(tool)
	drawn.material_override = Pressing.painted()
	drawn.position = at
	into.add_child(drawn)


## TARMAC, so the vehicles are seen to stand on something. Plain and a little darker than the palest paint, or the pale
## cars vanish into it.
func _tarmac(into: Node) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(span() * 2.2, span() * 2.2)
	ground.mesh = plane
	var tarmac := StandardMaterial3D.new()
	tarmac.albedo_color = Color(0.30, 0.30, 0.31)
	tarmac.roughness = 0.95
	ground.material_override = tarmac
	into.add_child(ground)


func _lit(filename: String, size: Vector2i, from: Vector3, target: Vector3, fov: float) -> void:
	var stage := _stage(size, Color(0.56, 0.65, 0.74), Color(0.60, 0.65, 0.72), 0.75)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.78, -0.62, 0.0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	stage.add_child(light)
	_tarmac(stage)
	_row(stage, false, Vector3.RIGHT)
	# THE FIGURE STANDS IN FRONT OF THE LONGEST VEHICLE, not off the end of the row -- beyond the end it
	# extends the very thing the camera distance was worked out from, and it was the first thing out of
	# frame. **And CLEAR of it in z, by its own half-length plus 1.8 m.** Put at the vehicle's own
	# centre it is inside the trailer, which draws over it completely: a ruler nobody can see is not a
	# ruler, and this one was invisible for a whole render because the fix for one framing fault put it
	# somewhere the fault could not be seen.
	_person(stage, Vector3(span() * 0.5 - longest() * 0.5, 0.0, -longest() * 0.5 - 1.8))
	var camera := Camera3D.new()
	camera.fov = fov
	camera.current = true
	stage.add_child(camera)
	camera.global_position = from
	camera.look_at(target, Vector3.UP)
	await _save(stage, filename)


## EVERY SILHOUETTE from the side, orthographic, flat and unshaded on white. One scale, one page,
## and no fitting: a reader can lay a ruler across the printed picture and get metres out of it.
func _silhouettes(pattern: String) -> void:
	# THE ROW DECIDES THE SCALE, not the other way about, and the scale it came out at names the file.
	var across: float = span() * 1.04
	var px: float = float(PAGE_WIDE) / across
	var size := Vector2i(PAGE_WIDE, int(float(PAGE_WIDE) * 0.105))
	var filename: String = pattern % int(round(px))
	var stage := _stage(size, Color.WHITE, Color.WHITE, 1.0)
	_row(stage, true, Vector3.BACK)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = across
	camera.near = 0.05
	camera.far = span() * 4.0
	camera.current = true
	stage.add_child(camera)
	# FROM THE VEHICLES' PORT SIDE, along the X axis, with the camera raised to the middle of the tallest so no vehicle
	# is cut off and none is looked down on. The row runs along Z for this one view (see `_row`), which is what makes it
	# a side elevation rather than four head-on views.
	camera.global_position = Vector3(-span(), 1.90, 0.0)
	camera.look_at(Vector3(0.0, 1.90, 0.0), Vector3.UP)
	await _save(stage, filename)


func _save(stage: SubViewport, filename: String) -> void:
	for frame in range(4):
		await RenderingServer.frame_post_draw
	var path := out.path_join(filename)
	var error := stage.get_texture().get_image().save_png(path)
	if error != OK:
		failures.append(filename)
	print("[road_vehicles_shot] %s %s" % ["saved" if error == OK else "FAILED", path])
	stage.queue_free()
