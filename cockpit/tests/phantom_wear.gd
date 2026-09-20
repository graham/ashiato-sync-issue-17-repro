extends Node

## THE WEATHERING, CHECKED WHERE A HEADLESS RUN CAN SEE IT: that the aeroplane carries a second set of texture
## coordinates at all, that they land a real vertex in the right part of the sheet, AND that the sheet is actually
## dirty there.
##
## **BOTH HALVES OR NEITHER.** A UV check on its own passes perfectly on a blank image -- the coordinates can be
## immaculate and the sheet empty, and the aeroplane draws factory-fresh with every check green. An image check on
## its own passes on a sheet that is dirty in a place no vertex ever reads. The pair is the claim: *this vertex, of
## this part, reads a texel that is this dirty.* That is the same lesson as `nothing_floats` earlier in this lane --
## a check is about the thing it can fail on, not the thing its name suggests.
##
## WHAT THIS CANNOT SEE, and why there is a second test. Nothing here renders. A detail layer that the engine
## ignored entirely, or blended in a way that left the paint untouched, would pass every check in this file.
## `tests/phantom_wear_shot.gd` is the anchor outside this frame: it renders the same aeroplane twice, once with
## `wear` on and once off, and reads the pixels.

const NOSE_TIP: float = 0.35
const SHEET_WIDE: int = 512
const SHEET_HIGH: int = 256

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	var frame := PhantomAirframe.new()
	frame.dress()
	add_child(frame)
	var sheet: StainSheet = frame.stain_sheet()
	var image: Image = sheet.image(SHEET_WIDE, SHEET_HIGH)

	_the_sheet_has_the_eight_named_marks(sheet)
	_every_drawn_vertex_carries_a_second_uv(frame)
	_the_sheet_is_dirty_where_the_exhaust_reads_and_clean_where_the_radome_does(frame, sheet, image)
	_a_lighter_mark_is_actually_lighter(sheet)
	_the_marks_reach_the_aeroplane(image)

	var out: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sheet="):
			out = argument.trim_prefix("--sheet=")
	if out != "":
		image.save_png(out)
		print("[phantom_wear] sheet written to %s" % out)

	if _failures.is_empty():
		print("RESULT=PASS %d checks" % _checks)
	else:
		print("RESULT=FAIL %s" % [_failures])
	get_tree().quit(0 if _failures.is_empty() else 1)


## THE EIGHT, BY NAME. A mark quietly dropped is a mark nobody misses until a picture is compared.
func _the_sheet_has_the_eight_named_marks(sheet: StainSheet) -> void:
	var want := ["exhaust_soot", "nozzle_heat", "gun_gas", "walkway_wear", "boot_marks",
		"panel_line_dirt", "le_erosion", "faded_patches"]
	var got: PackedStringArray = []
	for m in sheet.marks:
		got.append(String(m["name"]))
	var missing: PackedStringArray = []
	for name in want:
		if not got.has(name):
			missing.append(name)
	_check("the_sheet_carries_its_eight_named_marks", missing.is_empty() and got.size() == want.size(),
		"%d marks: %s" % [got.size(), missing if not missing.is_empty() else "all eight"])


## EVERY VERTEX, NOT MOST. A surface built by a function that forgot `set_uv2` reads texel (0,0) for its whole self,
## which is the nose on the side band -- so the fault draws as a clean part rather than as an obviously broken one.
func _every_drawn_vertex_carries_a_second_uv(frame: PhantomAirframe) -> void:
	var surfaces: int = 0
	var vertices: int = 0
	var without: PackedStringArray = []
	var outside: int = 0
	for mesh in _meshes(frame):
		var data: ArrayMesh = mesh.mesh
		if data == null:
			continue
		for s in range(data.get_surface_count()):
			surfaces += 1
			var arrays: Array = data.surface_get_arrays(s)
			var uv2 = arrays[Mesh.ARRAY_TEX_UV2]
			if uv2 == null or uv2.size() == 0:
				without.append("%s surface %d" % [mesh.name, s])
				continue
			vertices += uv2.size()
			for uv in uv2:
				if uv.x < -0.001 or uv.x > 1.001 or uv.y < -0.001 or uv.y > 1.001:
					outside += 1
	_check("every_drawn_surface_carries_a_second_uv", without.is_empty(),
		"%d surfaces, %d vertices%s" % [surfaces, vertices, "" if without.is_empty() else ": %s" % without])
	_check("and_no_second_uv_falls_off_the_sheet", outside == 0, "%d outside 0..1" % outside)


## THE PAIRED CLAIM. A vertex at the back of the aeroplane must read a DIRTY texel, and one on the radome must read
## a CLEAN one -- from the same sheet, through the same mapping, off the drawn mesh rather than off the builder's
## intention.
func _the_sheet_is_dirty_where_the_exhaust_reads_and_clean_where_the_radome_does(
		frame: PhantomAirframe, sheet: StainSheet, image: Image) -> void:
	var aft := _alpha_at_station(frame, sheet, image, PhantomAirframe.LENGTH - 0.6, 1.4)
	var nose := _alpha_at_station(frame, sheet, image, NOSE_TIP, 1.4)
	_check("a_vertex_by_the_nozzles_reads_a_dirty_texel", aft.x >= 0.35,
		"alpha %.3f at station %.2f, from %d vertices" % [aft.x, PhantomAirframe.LENGTH - 0.6, int(aft.y)])
	_check("and_a_vertex_on_the_radome_reads_a_clean_one", nose.x <= 0.15,
		"alpha %.3f at station %.2f, from %d vertices" % [nose.x, NOSE_TIP, int(nose.y)])
	_check("so_the_aeroplane_is_dirtier_aft_than_forward", aft.x > nose.x + 0.25,
		"aft %.3f against nose %.3f" % [aft.x, nose.x])


## A MARK LIGHTER THAN THE PAINT IS THE REASON THIS IS A DETAIL LAYER. Under a multiplied `albedo_texture` it is not
## expressible at all, so if this ever fails the mechanism has been swapped for the one that was rejected.
func _a_lighter_mark_is_actually_lighter(sheet: StainSheet) -> void:
	var lighter: int = 0
	for m in sheet.marks:
		var c: Color = m["colour"]
		if (c.r + c.g + c.b) / 3.0 > 0.45:
			lighter += 1
	_check("some_marks_are_lighter_than_the_paint_they_sit_on", lighter >= 2,
		"%d of %d marks are lighter" % [lighter, sheet.marks.size()])


## AND THE SHEET IS NOT BLANK, AND NOT A SOLID WALL. Either extreme passes every placement check above.
func _the_marks_reach_the_aeroplane(image: Image) -> void:
	var dirty: int = 0
	var strongest: float = 0.0
	var total: float = 0.0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var a: float = image.get_pixel(x, y).a
			total += a
			strongest = maxf(strongest, a)
			if a > 0.08:
				dirty += 1
	var texels: int = (image.get_width() / 2) * (image.get_height() / 2)
	var share: float = float(dirty) / float(texels)
	var mean: float = total / float(texels)
	_check("the_sheet_is_neither_blank_nor_a_solid_wall", share > 0.10 and share < 0.95,
		"%.1f%% of texels carry a mark, mean alpha %.3f, strongest %.3f" % [share * 100.0, mean, strongest])
	_check("and_its_strongest_mark_is_strong_enough_to_see", strongest >= 0.45,
		"strongest alpha %.3f" % strongest)


## THE MEAN ALPHA read by the drawn vertices nearest a station, and how many there were. Off the MESH, so a builder
## that never wrote UV2 for that part cannot pass by arithmetic.
func _alpha_at_station(frame: PhantomAirframe, sheet: StainSheet, image: Image,
		station: float, within: float) -> Vector2:
	var total: float = 0.0
	var seen: int = 0
	for mesh in _meshes(frame):
		var data: ArrayMesh = mesh.mesh
		if data == null:
			continue
		for s in range(data.get_surface_count()):
			var arrays: Array = data.surface_get_arrays(s)
			var points = arrays[Mesh.ARRAY_VERTEX]
			var uv2 = arrays[Mesh.ARRAY_TEX_UV2]
			if points == null or uv2 == null or uv2.size() != points.size():
				continue
			for i in range(points.size()):
				var at: float = points[i].z + mesh.position.z + frame.half_extents().z
				if absf(at - station) > within:
					continue
				var uv: Vector2 = uv2[i]
				var x: int = clampi(int(uv.x * float(image.get_width())), 0, image.get_width() - 1)
				var y: int = clampi(int(uv.y * float(image.get_height())), 0, image.get_height() - 1)
				total += image.get_pixel(x, y).a
				seen += 1
	return Vector2(total / float(maxi(seen, 1)), float(seen))


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found


func _check(label: String, held: bool, said: String) -> void:
	_checks += 1
	print("[phantom_wear] %s %s (%s)" % ["PASS" if held else "FAIL", label, said])
	if not held:
		_failures.append(label)
