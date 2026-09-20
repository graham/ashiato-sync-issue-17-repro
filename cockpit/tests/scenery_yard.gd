extends Node
## Headless: is the island's picture, drawn a kilometre at a time, still the island -- every box, street, road and
## piece of railway drawn once, in its own cell's batch, the size and in the place the list says?
##
##   Godot --headless --path cockpit res://tests/scenery_yard.tscn
##
## `SceneryYard` draws the rock, the concrete and the railway, and `TownView` the buildings and the paint, one
## MultiMesh a cell (world/scenery_yard.gd). A box lost in the split is a mountain the simulation has and nobody sees;
## a box in two batches is a building drawn twice on a border; a batch cut off too near is a cliff that vanishes while
## you are looking at it. None of those shows in a count, so every check here is against something the drawing did
## not compute:
##
## - THE LIST. What each batch was handed, put back into the world, is `Terrain.boxes()` as a multiset to the
##   centimetre, group by group, and the paint and the railway likewise.
## - THE GROUND. Every instance's centre stands inside its batch's cell, asked of `WorldMap.square_of`.
## - THE PEAK. Every rock step carries the peak its box records, as the rock shaders read it.
## - THE EYE. A batch is drawn from anywhere within `FAR` of its furthest corner: its range end is at least `FAR` plus
##   the distance from its middle to that corner, measured here from the instances themselves.
## - THE FLOAT. Every instance is a small offset from its batch's middle, not a world position.
## - THE FINISH. Wearing FINE reaches every batch, and wearing PLAIN takes it off every one.
##
## Read RESULT=, not the exit code.

## How far from the eye the level draws the scenery in this suite: the cameras' far plane, 24 km.
const FAR: float = 24000.0
## The most an instance may sit from its batch's middle, metres: a cell's half-diagonal and the furthest a box reaches
## past its square on the island (326 m, tests/world_map.gd), rounded up. A world position 35 km out is far past it.
const SMALL_OFFSET: float = 1500.0
const SAME: float = 0.01

var _failures: PackedStringArray = []
var _sections: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[scenery_yard] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var solid: Array[Dictionary] = Terrain.boxes()
	var map := WorldMap.new(solid)
	var yard := SceneryYard.new()
	add_child(yard)
	# NO CAMERA HERE, and no watching: everything is built at once with `fill_around`, from the middle of the island, which
	# is within reach of all of it. The rings are tests/scenery_rings.gd's.
	yard.set_process(false)
	var began: int = Time.get_ticks_usec()
	yard.draw_boxes(map, FAR, false)
	var boxes_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	var towns := TownView.new()
	add_child(towns)
	var paint: Array[Dictionary] = TownPlan.streets() + TownPlan.road_marks(Terrain.roads(solid))
	began = Time.get_ticks_usec()
	towns.draw_towns(map, paint, FAR, yard)
	yard.fill_around(Vector3.ZERO)
	var towns_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	_check("there_is_a_picture_to_check", not yard.box_batches().is_empty() and not towns.building_batches().is_empty(),
		"%d rock and concrete batches in %.1f ms, %d building and %d paint batches in %.1f ms, over %d cells"
			% [yard.box_batches().size(), boxes_ms, towns.building_batches().size(), towns.paint_batches().size(),
				towns_ms, map.cells().size()])

	_every_box_is_drawn_once_in_its_own_cell(solid, yard, towns)
	_every_batch_is_drawn_as_far_as_its_furthest_corner(yard, towns)
	_the_paint_and_the_railway_are_drawn_once_in_their_own_cells(paint, towns, yard)
	_the_finish_reaches_every_batch(yard)
	_check("every_section_of_the_suite_ran", _sections == 4, "%d of 4" % _sections)
	_finish()


## ---- the list, and the ground -------------------------------------------------------------------

func _every_box_is_drawn_once_in_its_own_cell(solid: Array[Dictionary], yard: SceneryYard, towns: TownView) -> void:
	# NOT ROCK: the island has none since its mountains became ranges drawn by MountainView (2026-09-18).
	for group in [Terrain.Group.CONCRETE, Terrain.Group.BUILDING]:
		var wanted: Dictionary = {}
		for box in solid:
			if int(box["group"]) == group:
				_count(wanted, _box_key(box["position"], box["half_extents"]))
		var got: Dictionary = {}
		var drawn: int = 0
		var astray: PackedStringArray = []
		var far_out: int = 0
		for batch in (towns.building_batches() if group == Terrain.Group.BUILDING else yard.box_batches()):
			var cell: Vector2i = batch.get_meta(&"cell")
			var square: Rect2 = WorldMap.square_of(cell)
			# A rock or concrete batch is one group, and says which; a building batch holds nothing else.
			if int(batch.get_meta(&"group", Terrain.Group.BUILDING)) != group:
				continue
			var placed: Array = batch.get_meta(&"placed", [])
			for i in range(placed.size()):
				var local: Transform3D = placed[i]
				var at: Vector3 = batch.position + local.origin
				_count(got, _box_key(at, local.basis.get_scale() * 0.5))
				drawn += 1
				if not (at.x >= square.position.x and at.x < square.end.x and at.z >= square.position.y
						and at.z < square.end.y):
					astray.append("%s in %s" % [at.round(), cell])
				if local.origin.length() > SMALL_OFFSET:
					far_out += 1
		var differ: PackedStringArray = _differences(wanted, got)
		var name: String = Terrain.Group.keys()[group].to_lower()
		_check("every_%s_box_is_drawn_once_the_size_and_in_the_place_the_list_says" % name, differ.is_empty() and drawn > 0,
			"%d drawn, %d in the list%s" % [drawn, _total(wanted), "" if differ.is_empty() else ": %s" % [str(Array(differ).slice(0, 4))]])
		_check("and_each_%s_in_its_own_cells_batch_as_a_small_offset_from_its_middle" % name,
			astray.is_empty() and far_out == 0,
			"%d astray%s, %d further than %.0f m from their batch's middle" % [astray.size(),
				"" if astray.is_empty() else ": %s" % [str(Array(astray).slice(0, 4))], far_out, SMALL_OFFSET])
	_sections += 1


## ---- the eye, and the float ----------------------------------------------------------------------

func _every_batch_is_drawn_as_far_as_its_furthest_corner(yard: SceneryYard, towns: TownView) -> void:
	var short: PackedStringArray = []
	var batches: int = 0
	var most_reach: float = 0.0
	var every: Array[MultiMeshInstance3D] = []
	every.append_array(yard.box_batches())
	every.append_array(yard.rail_batches())
	every.append_array(towns.building_batches())
	every.append_array(towns.paint_batches())
	for batch in every:
		batches += 1
		# THE FURTHEST CORNER OF ANY INSTANCE FROM THE BATCH'S MIDDLE, from the instances themselves: each is a unit box
		# put through its own transform, which is what the engine sizes the batch's box from.
		var reach: float = 0.0
		for placed in (batch.get_meta(&"placed", []) as Array):
			var local: Transform3D = placed
			for x in [-0.5, 0.5]:
				for y in [-0.5, 0.5]:
					for z in [-0.5, 0.5]:
						reach = maxf(reach, (local * Vector3(x, y, z)).length())
		most_reach = maxf(most_reach, reach)
		if batch.visibility_range_end < FAR + reach - SAME:
			short.append("%s ends at %.0f, wants %.0f" % [batch.name, batch.visibility_range_end, FAR + reach])
	_check("every_batch_is_drawn_out_to_FAR_from_its_furthest_corner", short.is_empty() and batches > 0,
		"%d batches, the furthest corner %.0f m from its middle%s" % [batches, most_reach,
			"" if short.is_empty() else ", short: %s" % [str(Array(short).slice(0, 4))]])
	_sections += 1


## ---- the paint and the railway -------------------------------------------------------------------

func _the_paint_and_the_railway_are_drawn_once_in_their_own_cells(paint: Array[Dictionary], towns: TownView,
		yard: SceneryYard) -> void:
	var wanted: Dictionary = {}
	# WHERE EACH MARK SHOULD BE, said from its own numbers and not from TownView's call: a slab's across axis is its yaw's x
	# and as long as its width, its along axis its yaw's z tilted up by its pitch and as long as its length, its up axis
	# square to both and as thick as its top. Until increment B5 this built `Basis(UP, yaw).scaled(half * 2)`, TownView's own
	# call, which scales in the world's axes -- so it agreed with a road drawn skewed (2026-09-15).
	for mark in paint:
		var yaw: float = float(mark.get("yaw", 0.0))
		var pitch: float = float(mark.get("pitch", 0.0))
		var size: Vector3 = (mark["half_extents"] as Vector3) * 2.0
		var across := Vector3(cos(yaw), 0.0, -sin(yaw)) * size.x
		var up := Vector3(sin(pitch) * sin(yaw), cos(pitch), sin(pitch) * cos(yaw)) * size.y
		var along := Vector3(cos(pitch) * sin(yaw), -sin(pitch), cos(pitch) * cos(yaw)) * size.z
		_count(wanted, _slab_key(Transform3D(Basis(across, up, along), mark["position"])))
	var got: Dictionary = {}
	var astray: int = 0
	for batch in towns.paint_batches():
		var square: Rect2 = WorldMap.square_of(batch.get_meta(&"cell"))
		for placed in (batch.get_meta(&"placed", []) as Array):
			var local: Transform3D = placed
			var world := Transform3D(local.basis, batch.position + local.origin)
			_count(got, _slab_key(world))
			if not square.has_point(Vector2(world.origin.x, world.origin.z)):
				astray += 1
	var differ: PackedStringArray = _differences(wanted, got)
	_check("every_street_and_road_is_painted_once_in_its_own_cell", differ.is_empty() and astray == 0 and _total(got) > 0,
		"%d painted of %d, %d astray%s" % [_total(got), _total(wanted), astray,
			"" if differ.is_empty() else ": %s" % [str(Array(differ).slice(0, 4))]])

	# THE RAILWAY, from pieces laid on the loop's own points: the level samples the simulation's railway, which this suite
	# has no session for; what is under test here is the filing and the offsets, not the sampling.
	var points: Array[Vector3] = Terrain.rail_points()
	var pieces: Array[Transform3D] = []
	for i in range(points.size()):
		var along: Vector3 = points[(i + 1) % points.size()] - points[i]
		pieces.append(Transform3D(Basis.looking_at(along.normalized(), Vector3.UP).scaled(Vector3(1.44, 0.16, along.length())),
			points[i] + along * 0.5))
	var beam := BoxMesh.new()
	yard.draw_railway(pieces, beam, FAR)
	yard.fill_around(Vector3.ZERO)
	var rails_wanted: Dictionary = {}
	for piece in pieces:
		_count(rails_wanted, _slab_key(piece))
	var rails_got: Dictionary = {}
	var rails_astray: int = 0
	for batch in yard.rail_batches():
		var square: Rect2 = WorldMap.square_of(batch.get_meta(&"cell"))
		for placed in (batch.get_meta(&"placed", []) as Array):
			var local: Transform3D = placed
			var world := Transform3D(local.basis, batch.position + local.origin)
			_count(rails_got, _slab_key(world))
			if not square.has_point(Vector2(world.origin.x, world.origin.z)):
				rails_astray += 1
	var rails_differ: PackedStringArray = _differences(rails_wanted, rails_got)
	_check("and_every_piece_of_railway_is_laid_once_in_its_own_cell",
		rails_differ.is_empty() and rails_astray == 0 and _total(rails_got) == pieces.size(),
		"%d laid of %d in %d batches, %d astray" % [_total(rails_got), pieces.size(), yard.rail_batches().size(),
			rails_astray])
	_sections += 1


## ---- the finish ------------------------------------------------------------------------------------

func _the_finish_reaches_every_batch(yard: SceneryYard) -> void:
	yard.wear(true)
	var plain_left: int = 0
	for batch in yard.box_batches():
		var over := batch.material_override as ShaderMaterial
		if over == null or over.shader != SceneryYard.ROCK_FINE:
			plain_left += 1
	var fine_said: bool = yard.wears_fine()
	yard.wear(false)
	var fine_left: int = 0
	for batch in yard.box_batches():
		if batch.material_override != null:
			fine_left += 1
	_check("wearing_fine_reaches_every_batch_and_wearing_plain_takes_it_off_every_one",
		plain_left == 0 and fine_left == 0 and fine_said and not yard.wears_fine(),
		"%d batches: %d left plain by FINE, %d left fine by PLAIN, wears_fine said %s then %s"
			% [yard.box_batches().size(), plain_left, fine_left, fine_said, yard.wears_fine()])
	_sections += 1


## ---- keys ----------------------------------------------------------------------------------------

static func _box_key(at: Vector3, half: Vector3) -> String:
	return "%.2f,%.2f,%.2f|%.2f,%.2f,%.2f" % [at.x, at.y, at.z, half.x, half.y, half.z]


## A slab as where its middle is and where its unit box's +x, +y and +z faces are, to the centimetre.
static func _slab_key(shape: Transform3D) -> String:
	var x: Vector3 = shape * Vector3(0.5, 0.0, 0.0)
	var y: Vector3 = shape * Vector3(0.0, 0.5, 0.0)
	var z: Vector3 = shape * Vector3(0.0, 0.0, 0.5)
	return "%.2f,%.2f,%.2f|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f" % [shape.origin.x, shape.origin.y,
		shape.origin.z, x.x, x.y, x.z, y.x, y.y, y.z, z.x, z.y, z.z]


static func _count(into: Dictionary, key: String) -> void:
	into[key] = int(into.get(key, 0)) + 1


static func _total(counts: Dictionary) -> int:
	var total: int = 0
	for key in counts:
		total += int(counts[key])
	return total


static func _differences(wanted: Dictionary, got: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for key in wanted:
		var short: int = int(wanted[key]) - int(got.get(key, 0))
		if short != 0:
			out.append("%s %+d" % [key, -short])
	for key in got:
		if not wanted.has(key):
			out.append("%s +%d" % [key, int(got[key])])
	return out


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
