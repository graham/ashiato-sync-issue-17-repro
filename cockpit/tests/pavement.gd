extends Node
## Headless: does the runway's pavement know where it is, and is there one place that says how near its detail comes in?
##
##   Godot --headless --path cockpit res://tests/pavement.tscn
##
## WHAT A SUITE CAN AND CANNOT SEE HERE. Almost the whole of this feature is a picture -- whether the seams shimmer,
## whether the touchdown zone reads as rubber, whether anything pops as you descend -- and none of that is visible to
## a headless run (`testing_godot_headless.md`). The pictures are the evidence for those and they are in
## `learnings/2026-09-20-detailshaders.md`.
##
## What IS checkable is everything the picture depends on, and it is the half that fails silently:
##
## - THE FRAME CONVENTION. The pavement shader turns a world position into "metres along the strip from the middle,
##   metres across from the centreline" with a cos and a sin it works out from the runway's bearing. Get a sign wrong
##   and the touchdown zone lands sideways, or on the grass, and the only symptom is a picture that looks a bit odd.
##   So the convention is asserted against `Terrain.runway_frame`'s OWN `along` and `across` vectors -- against the
##   authority, not against a second copy of the arithmetic, which would be the tautology trap.
## - THE FRAME ACTUALLY REACHING THE INSTANCES, through a MultiMesh's custom data, with numbers like -900 and 450 in
##   it. That is a float round trip through the rendering server and it is worth proving rather than assuming.
## - EVERY MARK OF ONE RUNWAY CARRYING THAT RUNWAY'S FRAME, which is the single thing that stops the rubber and the
##   paving seams restarting inside every painted stripe.
## - ONE PLACE FOR THE RANGES. `DetailReach` holds them; the materials carry what it holds; and the FINE tier carries
##   the same `wear_fade` as PLAIN, because FINE adds a layer and does not move the detail nearer.
##
## Read RESULT=, not the exit code.

## How close two floats have to be to count as the same. The frame data is float32 through the rendering server.
const CLOSE: float = 1.0e-3

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[pavement] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_shaders_frame_is_the_runways_frame()
	_the_ranges_have_one_place_and_one_dial()
	_the_shaders_take_their_distance_from_view_space()
	await _every_mark_carries_the_frame_of_the_runway_it_is_painted_on()
	await _the_two_tiers_differ_by_a_layer_and_not_by_a_range()
	_only_the_concrete_converts_its_colour_from_srgb()
	await _the_finish_reaches_every_air_base_and_only_its_pavement()
	await _the_ground_reads_its_bands_off_the_same_authority()
	_finish()


## ---- the frame -------------------------------------------------------------------------

## THE SHADER'S COS AND SIN ARE THE RUNWAY'S OWN AXES, asked of the runway.
##
## `pavement_on_runway` turns an offset from the runway's centre into (across, along) with
##
##     across = d.x * cos(b) - d.z * sin(b)
##     along  = d.x * sin(b) + d.z * cos(b)
##
## which is that offset dotted with `Basis(Vector3.UP, b)`'s local +x and local +z. If that is right then those two
## basis vectors ARE `frame["across"]` and `frame["along"]`, which `Terrain` worked out for itself when it laid the
## strip. So the check is against the authority: flip either sign in the shader and this fails, and it fails for every
## runway on every world rather than only for the ones that happen to point along an axis.
##
## AND IT IS CHECKED ON A BEARING THAT IS NOT A MULTIPLE OF A QUARTER TURN, or it could not fail: on the island the
## runway points due north, where sin is 0 and cos is 1 and three of the four signs do not matter.
func _the_shaders_frame_is_the_runways_frame() -> void:
	var frames: Array[Dictionary] = Terrain.runways()
	_check("there_are_runways_to_check", not frames.is_empty(), "%d" % frames.size())
	var worst: float = 0.0
	var turned: int = 0
	for frame in frames:
		var bearing: float = float(frame["bearing"])
		var along: Vector3 = frame["along"]
		var across: Vector3 = frame["across"]
		var shader_along := Vector3(-sin(bearing), 0.0, -cos(bearing))
		var shader_across := Vector3(cos(bearing), 0.0, -sin(bearing))
		worst = maxf(worst, (shader_along - along).length())
		worst = maxf(worst, (shader_across - across).length())
		if absf(sin(bearing)) > CLOSE and absf(cos(bearing)) > CLOSE:
			turned += 1
	_check("the_shaders_axes_are_the_runways_axes", worst < CLOSE, "worst %.6f over %d runways" % [worst, frames.size()])
	# A BEARING OFF THE AXES SOMEWHERE IN THE GAME, so the check above has something to bite on. Reported rather than
	# failed on the island alone, whose single strip is due north -- but a world with only square runways would make
	# the assertion above unfalsifiable, and that is worth saying out loud.
	print("[pavement] %d of %d runways are on a bearing off the axes" % [turned, frames.size()])
	# THE ARITHMETIC ITSELF, ON A TURNED FRAME, whatever the world happens to hold: a point 100 m up the strip and 20 m
	# right of the centreline of a runway on 040 must come back as (20, 100).
	var bearing: float = deg_to_rad(40.0)
	var along: Vector3 = Terrain.nose_from_yaw(bearing)
	var across := Vector3(-along.z, 0.0, along.x)
	var point: Vector3 = along * 100.0 + across * 20.0
	var got_across: float = point.x * cos(bearing) - point.z * sin(bearing)
	var got_along: float = -(point.x * sin(bearing) + point.z * cos(bearing))
	_check("a_point_up_and_right_of_the_centreline_comes_back_as_such",
		absf(got_across - 20.0) < CLOSE and absf(got_along - 100.0) < CLOSE,
		"across %.4f along %.4f, wanted 20 and 100" % [got_across, got_along])


## ---- the one place ---------------------------------------------------------------------

## THE RANGES COME FROM `DetailReach` AND THE DIAL MOVES ALL OF THEM.
##
## The dial is what makes "what does pushing the threshold out cost" a measurement rather than a guess: the probe asks
## for 2.0 and the game ships 1.0, and both go through this one function. If a range ever stopped being scaled by it,
## the measurement and the game would quietly be measuring different runways.
func _the_ranges_have_one_place_and_one_dial() -> void:
	var shipped: Dictionary = DetailReach.pavement_numbers()
	var doubled: Dictionary = DetailReach.pavement_numbers(2.0)
	_check("the_authority_names_both_bands", shipped.has("wear_fade") and shipped.has("grain_fade"),
		", ".join(PackedStringArray(shipped.keys())))
	var wrong: PackedStringArray = []
	for named in shipped:
		var one: Vector2 = shipped[named]
		var two: Vector2 = doubled[named]
		if (two - one * 2.0).length() > CLOSE:
			wrong.append("%s %s against %s" % [named, two, one * 2.0])
		# A band has to have width, or `detail_fade`'s smoothstep has nothing to fade across.
		if one.y <= one.x:
			wrong.append("%s is not a band: %s" % [named, one])
	_check("the_dial_moves_every_band_and_every_band_is_a_band", wrong.is_empty(), "; ".join(wrong))
	# THE GRAIN IS THE NEARER OF THE TWO, which is the whole reason there are two: centimetres of aggregate stop being
	# a pixel long before metres of rubber do.
	var grain: Vector2 = shipped["grain_fade"]
	var wear: Vector2 = shipped["wear_fade"]
	_check("the_aggregate_gives_up_before_the_wear_does", grain.y < wear.y,
		"grain gone at %.0f m, wear at %.0f m" % [grain.y, wear.y])


## THE DISTANCE IS TAKEN FROM VIEW SPACE, WHERE THE CAMERA CANNOT BE WRONG.
##
## `tests/lint.gd` already fails any shader that reads `CAMERA_POSITION_WORLD` or `INV_VIEW_MATRIX[3]`, which on this
## precision=double build is minus the camera (`eye.gdshaderinc`). That rule catches the bug. This one asks the
## narrower question about these two files specifically: that they get their distance from `length(VERTEX)` in the
## fragment stage, which is the construction that cannot express the bug at all rather than the one that remembered
## to avoid it. A rewrite that reached for `EYE_POSITION_WORLD` would still pass lint and would still be a step back.
func _the_shaders_take_their_distance_from_view_space() -> void:
	for path in ["res://world/shaders/pavement.gdshader", "res://world/shaders/pavement_fine.gdshader"]:
		var code: String = FileAccess.get_file_as_string(path)
		_check("%s_measures_distance_in_view_space" % path.get_file().get_basename(),
			code.contains("length(VERTEX)") and not code.contains("EYE_POSITION_WORLD"),
			"length(VERTEX) %s, EYE_POSITION_WORLD %s" % [code.contains("length(VERTEX)"),
				code.contains("EYE_POSITION_WORLD")])


## ---- the frame reaching the instances ---------------------------------------------------

## EVERY MARK OF ONE RUNWAY CARRIES THAT RUNWAY'S FRAME, read back off the built level.
##
## Off the LEVEL and not off `_runway_frame_data`: the question is whether the four numbers survived being packed into
## a Color, handed to a MultiMesh and stored by the rendering server as float32, and a test that called the packing
## function and compared the answer with itself would pass with the MultiMesh unplugged.
##
## THIS IS THE CHECK THAT GUARDS THE ONE DESIGN DECISION THAT MATTERS. Each painted stripe is its own little box a few
## metres long. If the shader took its coordinate from the instance's own space, the touchdown zone would restart
## inside every centreline mark -- the rubber would appear as a dark blob on each stripe and nowhere else. The frame
## being the RUNWAY'S and identical across every mark of it is what makes the detail run through the paint unbroken.
func _every_mark_carries_the_frame_of_the_runway_it_is_painted_on() -> void:
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var runway := level.get_node_or_null("Runway") as MultiMeshInstance3D
	if runway == null or runway.multimesh == null:
		_check("the_level_drew_a_runway", false, "no Runway node")
		level.queue_free()
		await get_tree().process_frame
		return
	var slabs: MultiMesh = runway.multimesh
	_check("the_level_drew_a_runway", slabs.instance_count > 0, "%d marks" % slabs.instance_count)
	# ONE FRAME PER MARK AND IN THE BATCH'S ORDER. Asked of `runway_frames`, which is the array the level handed to
	# `set_instance_custom_data`, because the MultiMesh itself cannot answer headless -- the dummy rendering server
	# keeps no buffers and reads every instance back as a default. That is not a softer check as long as the two agree
	# in length, which is what this first line is: a roster shorter than the batch means marks drawing with no frame.
	_check("every_mark_was_handed_a_frame", level.runway_frames.size() == slabs.instance_count,
		"%d frames for %d marks" % [level.runway_frames.size(), slabs.instance_count])
	# WHAT THE FRAMES SHOULD BE, from `Terrain` -- the same authority the level asked.
	var wanted: Dictionary = {}
	for frame in Terrain.runways():
		var data: Color = FlightLevel._runway_frame_data(frame)
		wanted["%.1f,%.1f" % [data.r, data.g]] = data
	var unmatched: int = 0
	var worst: float = 0.0
	var seen: Dictionary = {}
	for got in level.runway_frames:
		var key: String = "%.1f,%.1f" % [got.r, got.g]
		if not wanted.has(key):
			unmatched += 1
			continue
		seen[key] = int(seen.get(key, 0)) + 1
		var want: Color = wanted[key]
		worst = maxf(worst, absf(got.b - want.b))
		worst = maxf(worst, absf(got.a - want.a))
	_check("every_mark_names_a_runway_the_terrain_laid", unmatched == 0,
		"%d of %d marks matched no runway" % [unmatched, level.runway_frames.size()])
	_check("each_marks_bearing_and_half_length_are_its_runways", worst < CLOSE, "worst %.6f" % worst)
	# AND EVERY RUNWAY THE TERRAIN LAID GOT MARKS, not just the one the island starts on.
	_check("every_runway_was_painted", seen.size() == wanted.size(),
		"%d of %d runways have marks" % [seen.size(), wanted.size()])
	# MORE THAN ONE MARK A RUNWAY, or the check above would be satisfied by a single asphalt slab and would say nothing
	# about the paint, which is the case it exists for.
	var thinnest: int = 1 << 30
	for key in seen:
		thinnest = mini(thinnest, int(seen[key]))
	_check("each_runway_has_its_paint_on_the_same_frame_as_its_asphalt",
		not seen.is_empty() and thinnest > 1,
		"the least-marked runway has %d marks" % (thinnest if not seen.is_empty() else 0))
	level.queue_free()
	await get_tree().process_frame


## ---- the two axes -----------------------------------------------------------------------

## FINE ADDS A LAYER; IT DOES NOT MOVE THE DETAIL NEARER.
##
## This is the composition of the two axes, asserted. The tier decides WHICH shader; `DetailReach` decides HOW NEAR,
## and it decides it the same way for both. A FINE build that quietly carried a longer `wear_fade` would be a quality
## tier that had eaten the distance axis, which is the thing the design of this was most at risk of becoming.
##
## AND PLAIN DOES NOT DECLARE THE AGGREGATE AT ALL. Not "sets it to zero" -- does not have the uniform, because it
## does not have the code. That is `Finish`'s promise kept in the one way that survives a mobile GPU: PLAIN's shader
## has no dead near-detail path to allocate registers for.
func _the_two_tiers_differ_by_a_layer_and_not_by_a_range() -> void:
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var runway := level.get_node_or_null("Runway") as MultiMeshInstance3D
	if runway == null:
		_check("there_is_a_runway_to_wear_a_finish", false, "no Runway node")
		level.queue_free()
		await get_tree().process_frame
		return
	var finish: Node = get_node_or_null("/root/Finish")
	var was_fine: bool = finish != null and bool(finish.call("is_fine"))
	var carried: Dictionary = {}
	var shaders: Dictionary = {}
	for fine in [false, true]:
		if finish != null:
			finish.call("choose", fine)
		await get_tree().process_frame
		var worn := runway.material_override as ShaderMaterial
		if worn == null:
			_check("the_runway_wears_a_pavement_shader", false, "%s" % runway.material_override)
			continue
		carried[fine] = worn.get_shader_parameter("wear_fade")
		shaders[fine] = worn.shader
	if finish != null:
		finish.call("choose", was_fine)
	_check("the_finish_reaches_the_runway_and_the_two_tiers_are_two_shaders",
		shaders.size() == 2 and shaders[false] != shaders[true],
		"plain %s, fine %s" % [shaders.get(false), shaders.get(true)])
	# THE RANGE THE AUTHORITY HOLDS, ON THE MATERIAL, ON BOTH TIERS.
	var wanted: Vector2 = DetailReach.pavement_numbers()["wear_fade"]
	var both_right: bool = carried.size() == 2 \
		and (carried[false] as Vector2 - wanted).length() < CLOSE \
		and (carried[true] as Vector2 - wanted).length() < CLOSE
	_check("both_tiers_carry_the_authoritys_range", both_right,
		"plain %s, fine %s, authority %s" % [carried.get(false), carried.get(true), wanted])
	# AND THE AGGREGATE IS FINE'S ALONE, asked of the shaders' own uniform lists.
	var plain_has: bool = _declares(shaders.get(false) as Shader, "grain_fade")
	var fine_has: bool = _declares(shaders.get(true) as Shader, "grain_fade")
	_check("only_the_fine_pavement_has_an_aggregate_path", not plain_has and fine_has,
		"plain declares grain_fade %s, fine %s" % [plain_has, fine_has])
	level.queue_free()
	await get_tree().process_frame


## ---- the concrete -----------------------------------------------------------------------

## ONE OF THE TWO PAVEMENTS CONVERTS ITS COLOUR AND THE OTHER MUST NOT.
##
## `AirbaseView._vertex_colour` sets `vertex_color_is_srgb = true` and `Sky._draw_runway` does not, and both are
## right for the colours they were tuned against -- the air base's were picked by eye and read as white when they
## were taken as linear (airbase_view.gd, 2026-09-17). A StandardMaterial3D did that conversion for one caller and
## not the other and so hid the difference; a custom shader is handed COLOR raw in both cases and has to choose.
##
## GETTING IT BACKWARDS SHIFTS THE GAMMA OF A WHOLE AIR BASE, OR OF THE RUNWAY, and a uniform gamma shift reads as
## the lighting being off rather than as a bug in a surface -- which is exactly the kind of fault that survives a
## look. Nothing else in the suite would catch it, so it is asserted on the source.
func _only_the_concrete_converts_its_colour_from_srgb() -> void:
	var converts: Array[String] = ["concrete", "concrete_fine"]
	var must_not: Array[String] = ["pavement", "pavement_fine"]
	var wrong: PackedStringArray = []
	for stem in converts + must_not:
		var code: String = FileAccess.get_file_as_string("res://world/shaders/%s.gdshader" % stem)
		var does: bool = code.contains("pavement_srgb_to_linear(COLOR")
		if converts.has(stem) and not does:
			wrong.append("%s should convert and does not" % stem)
		if must_not.has(stem) and does:
			wrong.append("%s converts and must not" % stem)
	_check("only_the_concrete_converts_its_colour_from_srgb", wrong.is_empty(), "; ".join(wrong))


## THE FINISH REACHES EVERY AIR BASE, AND REACHES ONLY ITS PAVEMENT.
##
## Two claims in one build because a level is expensive. That the tier gets to each base -- asked of the bases, not
## of `Finish` -- and that it does not get to the structures: `AirbaseView._boxes` is shared between the ground and
## the walls, so the obvious way to write this puts a slab grid up the side of a hangar, a joint every 6.10 m of
## nothing. The structures must still wear the plain vertex-coloured material.
##
## AND EVERY BASE HAS TO AGREE. `finish_worn` reports the pavement as ONE surface, true only when each base wears
## it, so a base the switch missed cannot hide behind the ones it reached.
func _the_finish_reaches_every_air_base_and_only_its_pavement() -> void:
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var bases: Node = level.get_node_or_null("Airbases")
	if bases == null or bases.get_child_count() == 0:
		_check("the_level_drew_air_bases", false, "no Airbases")
		level.queue_free()
		await get_tree().process_frame
		return
	_check("the_level_drew_air_bases", true, "%d bases" % bases.get_child_count())
	var finish: Node = get_node_or_null("/root/Finish")
	var was_fine: bool = finish != null and bool(finish.call("is_fine"))
	var followed: Dictionary = {}
	for fine in [false, true]:
		if finish != null:
			finish.call("choose", fine)
		await get_tree().process_frame
		var every: bool = true
		for base in bases.get_children():
			every = every and (base as AirbaseView).wears_fine() == fine
		followed[fine] = every
	if finish != null:
		finish.call("choose", was_fine)
	_check("every_base_wears_the_tier_the_switch_is_on",
		bool(followed.get(false, false)) and bool(followed.get(true, false)),
		"plain %s, fine %s over %d bases" % [followed.get(false), followed.get(true), bases.get_child_count()])
	_check("the_level_reports_the_pavement_as_one_surface",
		level.finish_worn().has("airbase_pavement"),
		", ".join(PackedStringArray(level.finish_worn().keys())))
	# AND THE STRUCTURES ARE NOT PAVEMENT. Asked of the nodes: the ground wears a ShaderMaterial, the walls and the
	# roofs do not.
	var wrong: PackedStringArray = []
	for base in bases.get_children():
		# GeometryInstance3D AND NOT MeshInstance3D: `Ground` is a MultiMeshInstance3D, which does not descend from
		# MeshInstance3D, so that cast comes back null and reading `material_override` off it is a script error that
		# aborts the check silently -- which is how this was found, by the assertion never printing at all.
		var ground := base.get_node_or_null("Ground") as GeometryInstance3D
		if ground == null or not (ground.material_override is ShaderMaterial):
			wrong.append("a base's Ground wears no pavement shader")
		for called in ["Structures", "Roofs"]:
			var node: Node = base.get_node_or_null(called)
			if node != null and (node as GeometryInstance3D).material_override is ShaderMaterial:
				wrong.append("a base's %s wears a pavement shader and should not" % called)
	_check("the_pavement_shader_reaches_the_ground_and_not_the_hangars", wrong.is_empty(),
		"; ".join(wrong) if not wrong.is_empty() else "%d bases" % bases.get_child_count())
	level.queue_free()
	await get_tree().process_frame


## THE GROUND'S BANDS COME FROM THE SAME AUTHORITY AS THE PAVEMENT'S.
##
## The ground already had near detail before this lane -- two bands in `grass.gdshader`, with a comment saying
## blades past the far edge are sub-pixel and all they do is boil. What it did not have was a dial: the four numbers
## were typed into the two grass shaders. Moving them to `DetailReach` is what makes one `REACH` move the ground,
## the runway and the air bases together, which is the difference between a dial and three numbers that happen to
## be multiplied by the same thing.
##
## ASKED OF THE MATERIALS AND OF THE SOURCE, because they fail differently. A material that was never dressed still
## draws -- the shader's default is a 1e9 sentinel that draws everything everywhere, chosen so the failure boils to
## the horizon instead of quietly looking plain -- and a literal left behind in the source would keep working while
## making the dial a lie.
func _the_ground_reads_its_bands_off_the_same_authority() -> void:
	# NO RANGE LITERALS LEFT IN THE TWO GRASS SHADERS: a `detail_fade` still called with a number in it.
	var left: PackedStringArray = []
	for stem in ["grass", "grass_fine"]:
		var code: String = FileAccess.get_file_as_string("res://world/shaders/%s.gdshader" % stem)
		for line in code.replace("\r\n", "\n").split("\n"):
			if line.contains("detail_fade(") and line.contains("."):
				var after: String = line.get_slice("detail_fade(", 1)
				# A digit before the closing bracket means a typed range rather than a uniform.
				for digit in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
					if after.get_slice(")", 0).contains(digit):
						left.append("%s: %s" % [stem, line.strip_edges()])
						break
	_check("no_grass_shader_types_a_range", left.is_empty(), "; ".join(left))
	var level := (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var ground := level.get_node_or_null("Ground") as MeshInstance3D
	if ground == null or not (ground.material_override is ShaderMaterial):
		_check("the_ground_wears_a_grass_shader", false, "no Ground")
		level.queue_free()
		await get_tree().process_frame
		return
	# BOTH TIERS, by flicking the switch, because the fine material is a DUPLICATE of the plain one and a duplicate
	# taken before the bands were set would carry the sentinel for ever.
	var finish: Node = get_node_or_null("/root/Finish")
	var was_fine: bool = finish != null and bool(finish.call("is_fine"))
	var wanted: Dictionary = DetailReach.ground_numbers()
	var wrong: PackedStringArray = []
	for fine in [false, true]:
		if finish != null:
			finish.call("choose", fine)
		await get_tree().process_frame
		var worn := (level.get_node_or_null("Ground") as MeshInstance3D).material_override as ShaderMaterial
		for named in wanted:
			var got = worn.get_shader_parameter(named)
			if got == null or ((got as Vector2) - (wanted[named] as Vector2)).length() > CLOSE:
				wrong.append("%s tier %s carries %s, authority says %s"
					% [named, SceneryFinish.name_of(fine), got, wanted[named]])
	if finish != null:
		finish.call("choose", was_fine)
	_check("both_ground_tiers_carry_the_authoritys_bands", wrong.is_empty(), "; ".join(wrong))
	# AND THE ONE DIAL MOVES THE GROUND AND THE PAVEMENT TOGETHER, which is the whole point of one authority.
	var ground_two: Dictionary = DetailReach.ground_numbers(2.0)
	var pave_two: Dictionary = DetailReach.pavement_numbers(2.0)
	_check("one_reach_moves_the_ground_and_the_pavement_alike",
		((ground_two["blade_fade"] as Vector2) - (DetailReach.GROUND_BLADES * 2.0)).length() < CLOSE
			and ((pave_two["wear_fade"] as Vector2) - (DetailReach.PAVEMENT_WEAR * 2.0)).length() < CLOSE,
		"ground %s, pavement %s" % [ground_two["blade_fade"], pave_two["wear_fade"]])
	level.queue_free()
	await get_tree().process_frame


static func _declares(which: Shader, named: String) -> bool:
	if which == null:
		return false
	for uniform in which.get_shader_uniform_list():
		if String(uniform["name"]) == named:
			return true
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
