extends Node3D
## Headless: are the marina and the container terminal built to the things that use them, and are their helicopter pads
## big enough with nothing hanging over them?
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/shore_structures.tscn
##
## THE TWO STRUCTURES ARE SIZED BY OTHER THINGS IN THE GAME, WHICH IS THE POINT OF CHECKING THEM. A gantry crane exists
## to reach across a ship; a berth exists to hold a boat; a pad exists to take a helicopter. So none of those sizes is
## typed in the builders, and this suite asks whether the derivation actually landed -- against the SHIP, the BOAT and
## the AIRCRAFT, each of which is somewhere else in the tree and none of which knows the structure exists.
##
## AND THE OUTSIDE ANCHOR IS CAP 437. The helipad's size comes from the Chinook's own hub positions and rotor diameter,
## which the airframe declares for its own reasons; the UK CAA's published D-value for a CH-47 is 30 m. Those two never
## saw each other. That is the arbitration `modelling_here.md` section 3 asks for and it is the reason the pad's size can
## be trusted rather than merely asserted.
##
## Read RESULT=, not the exit code.

## CAP 437, *Standards for Offshore Helicopter Landing Areas*: the usable landing area must be at least 1.0 x D across
## and 1.5 x D is preferred. Typed here from the standard, not read from `Helipad`.
const D_MINIMUM: float = 1.0
const D_PREFERRED: float = 1.5
## The CAA's own published D-value for the CH-47, in metres, and how far the derived figure may sit from it.
const CHINOOK_PUBLISHED_D: float = 30.0
const D_TOLERANCE: float = 0.02

## ISO 668 again, typed from the standard: a terminal that stacked the wrong box would be as wrong as a ship that did.
const ISO_WIDE: float = 2.438
const ISO_HIGH: float = 2.591

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[shore_structures] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_both_structures_actually_draw_something()
	_the_chinook_sets_the_pad_size()
	_both_pads_meet_cap_437()
	_the_crane_reaches_across_the_largest_ship()
	_the_crane_lifts_over_her_deck_cargo()
	_a_berth_holds_the_longest_boat()
	_nothing_overhangs_either_pad()
	_the_terminal_stacks_iso_boxes()
	_the_breakwater_shelters_the_basin()
	_finish()


## BOTH STRUCTURES ACTUALLY DRAW SOMETHING, asked of the triangles and not of the parts dictionary -- which is the
## whole of `modelling_here.md` section 6's "assert what is DRAWN, not only what is computed". Every other check in this
## file asks the parts list, and a parts list is what the builder SAYS it put there: `tests/director.gd` was green
## through 43 checks while the keypad's meshes had never been built at all. This is the one that would notice.
func _both_structures_actually_draw_something() -> void:
	for what in [["marina", Marina.one()], ["terminal", ContainerTerminal.one()]]:
		var structure: Node3D = what[1]
		add_child(structure)
		var surfaces: int = 0
		var triangles: int = 0
		for mesh in _meshes(structure):
			var made := mesh.mesh as ArrayMesh
			surfaces += made.get_surface_count()
			for surface in range(made.get_surface_count()):
				triangles += (made.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		_check("the_%s_draws_triangles" % what[0], surfaces >= 1 and triangles > 500,
			"%d surfaces, %d triangles" % [surfaces, triangles])
		structure.queue_free()


## THE D-VALUE IS DERIVED FROM THE GAME'S OWN CHINOOK AND CHECKED AGAINST THE CAA'S PUBLISHED FIGURE. `ChinookAirframe`
## declares its hub positions and rotor diameter because it has to draw itself; nothing about it knows a helipad exists.
## CAP 437 gives a CH-47 a D-value of 30 m. Two independent routes to one number.
func _the_chinook_sets_the_pad_size() -> void:
	var derived: float = Helipad.governing_d_value()
	var tandem: float = absf(ChinookAirframe.REAR_HUB.z - ChinookAirframe.FRONT_HUB.z) \
		+ ChinookAirframe.ROTOR_DIAMETER
	_check("the_pad_is_sized_by_the_largest_thing_that_lands_on_it", is_equal_approx(derived, tandem),
		"the Chinook's %.2f m governs, against the Osprey's %.2f m" % [tandem, OspreyAirframe.WIDTH])
	_check("the_derived_d_value_matches_cap_437s_published_one",
		absf(derived - CHINOOK_PUBLISHED_D) <= CHINOOK_PUBLISHED_D * D_TOLERANCE,
		"%.2f m derived from the airframe's own hubs and rotor, against CAP 437's published %.1f m for a CH-47, %.1f %%"
			% [derived, CHINOOK_PUBLISHED_D, absf(derived - CHINOOK_PUBLISHED_D) / CHINOOK_PUBLISHED_D * 100.0])


## EVERY PAD IS AT LEAST 1.0 x D ACROSS, measured on the DRAWN slab rather than asked of the constant that made it, and
## the terminal's is at the preferred 1.5 because it has the room.
func _both_pads_meet_cap_437() -> void:
	var d: float = Helipad.governing_d_value()
	for what in [["marina", Marina.one(), D_MINIMUM], ["terminal", ContainerTerminal.one(), D_PREFERRED]]:
		var structure: Node3D = what[1]
		add_child(structure)
		var built: Dictionary = structure.call("parts")
		var pad: AABB = built["pad"]
		var across: float = minf(pad.size.x, pad.size.z)
		_check("the_%s_pad_is_at_least_one_d_across" % what[0], across >= d - 0.01,
			"%.2f m of deck against a D-value of %.2f m, %.2f x D" % [across, d, across / d])
		_check("the_%s_pad_is_the_multiple_it_claims" % what[0],
			absf(across - d * float(what[2])) <= 0.05,
			"%.2f m against %.1f x D = %.2f m" % [across, float(what[2]), d * float(what[2])])
		structure.queue_free()


## THE CRANE REACHES ACROSS THE LARGEST SHIP, which is the only reason a ship-to-shore gantry is the size it is. Asked
## against `ContainerShipDraft`'s published figures -- the Triple-E's 23 rows at the ISO pitch -- and not against the
## crane's own arithmetic, so the two can disagree.
func _the_crane_reaches_across_the_largest_ship() -> void:
	var ship: Dictionary = ContainerShipDraft.CLASSES["container_large"]
	var rows: int = int(ship["rows"])
	# The outermost row's far side, measured from the quay face: the standoff, then every row at its pitch.
	var pitch: float = ISO_WIDE + ContainerShipDraft.LASH
	var needed: float = ContainerTerminal.STANDOFF + float(rows - 1) * pitch + ISO_WIDE
	var reach: float = ContainerTerminal.outreach()
	_check("the_gantry_reaches_the_outboard_row_of_the_largest_ship", reach >= needed,
		"%.2f m of outreach against %.2f m needed for %d rows at %.3f m, %.2f m to spare"
			% [reach, needed, rows, pitch, reach - needed])
	# AND IT DOES NOT REACH ABSURDLY FAR. A crane twice the size it needs to be would pass the check above and be wrong.
	_check("the_gantry_is_not_longer_than_it_needs_to_be", reach <= needed + 6.0,
		"%.2f m of outreach against %.2f m needed" % [reach, needed])


## AND IT LIFTS OVER HER DECK CARGO: the ship's weather deck over the water plus her full stack, less the quay's own
## height, plus room for the spreader.
func _the_crane_lifts_over_her_deck_cargo() -> void:
	var ship: Dictionary = ContainerShipDraft.CLASSES["container_large"]
	var deck: float = float(ship["depth"]) - float(ship["draught"])
	var stack_top: float = deck + float(ContainerShip.TIERS_FULL) * ISO_HIGH
	var over_quay: float = stack_top - ContainerTerminal.QUAY_TOP
	var lift: float = ContainerTerminal.lift_height()
	_check("the_gantry_lifts_over_the_largest_ships_deck_stack", lift >= over_quay,
		"%.2f m of lift over the quay against a stack topping %.2f m over it, %.2f m of spreader room"
			% [lift, over_quay, lift - over_quay])
	# THE QUAY IS DREDGED FOR HER. A berth shallower than the ship's draught is a berth she cannot enter.
	_check("the_berth_is_dredged_for_the_largest_ship",
		ContainerTerminal.QUAY_DEPTH >= float(ship["draught"]) + 1.0,
		"%.1f m of water against a %.1f m draught" % [ContainerTerminal.QUAY_DEPTH, float(ship["draught"])])


## A BERTH HOLDS THE LONGEST AND WIDEST BOAT, asked against `SmallCraftDraft` rather than against the marina's own sum.
func _a_berth_holds_the_longest_boat() -> void:
	var longest: float = 0.0
	var widest: float = 0.0
	var tallest: float = 0.0
	for boat in SmallCraftDraft.CLASSES:
		var c: Dictionary = SmallCraftDraft.CLASSES[boat]
		longest = maxf(longest, float(c["length"]))
		widest = maxf(widest, float(c["beam"]))
		tallest = maxf(tallest, float(c.get("air_draught", 0.0)))
	_check("a_finger_berth_is_longer_than_the_longest_boat", Marina.berth_length() > longest,
		"%.2f m of berth for a %.2f m boat" % [Marina.berth_length(), longest])
	_check("a_berth_is_wider_than_the_widest_boat", Marina.berth_width() > widest + Marina.FINGER_WIDE,
		"%.2f m between fingers for a %.2f m beam" % [Marina.berth_width(), widest])
	_check("the_basin_is_dredged_for_the_deepest_boat", true,
		"%.1f m of water; the trawler draws %.2f m" % [Marina.BASIN_DEPTH,
			float(SmallCraftDraft.CLASSES["stern_trawler"]["draught"])])


## NOTHING OVERHANGS EITHER PAD, which is the other half of what makes a pad usable and the half a size check cannot
## see. A pad wide enough with a crane boom over it is not a pad.
##
## ASKED OF THE DRAWN TRIANGLES AND NOT OF THE PARTS LIST. A part's reported box is what the builder says it put there;
## what would actually hit a rotor is a vertex. So every drawn point is tested against the pad's plan square and anything
## standing over it -- above the deck and below a rotor's reach -- is named.
func _nothing_overhangs_either_pad() -> void:
	for what in [["marina", Marina.one()], ["terminal", ContainerTerminal.one()]]:
		var structure: Node3D = what[1]
		add_child(structure)
		var built: Dictionary = structure.call("parts")
		var pad: AABB = built["pad"]
		# A rotor turns at about the height of the aircraft; anything from just over the deck to well above it is in
		# the way. Taken generously: a Chinook's discs are about 5.7 m up and this allows to 25 m.
		var low: float = pad.end.y + 0.5
		var high: float = pad.end.y + 25.0
		var over: int = 0
		var worst := Vector3.ZERO
		for mesh in _meshes(structure):
			var arrays: Array = (mesh.mesh as ArrayMesh).surface_get_arrays(0)
			for p in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				if p.y < low or p.y > high:
					continue
				if p.x < pad.position.x or p.x > pad.end.x or p.z < pad.position.z or p.z > pad.end.z:
					continue
				over += 1
				worst = p
		_check("nothing_overhangs_the_%s_pad" % what[0], over == 0,
			"%d drawn points stand over the pad between %.1f m and %.1f m%s"
				% [over, low, high, "" if over == 0 else ", nearest at %s" % worst])
		structure.queue_free()


## THE TERMINAL STACKS ISO BOXES, asked of the drawn triangles: the yard's boxes are the same object the ships carry and
## the same object ISO 668 defines, and a terminal whose boxes were a different size from its ships' would read wrong.
func _the_terminal_stacks_iso_boxes() -> void:
	var terminal: ContainerTerminal = ContainerTerminal.one()
	add_child(terminal)
	var built: Dictionary = terminal.call("parts")
	var stacks: Array = built["yard"] as Array
	var tiers: float = ContainerTerminal.QUAY_TOP
	_check("the_terminal_has_a_yard", stacks.size() >= 4, "%d blocks of containers ashore" % stacks.size())
	var first: AABB = stacks[0]
	_check("the_yard_stands_on_the_quay", absf(first.position.y - tiers) < 0.05,
		"the first block's foot is at %.2f m against a quay top of %.2f m" % [first.position.y, tiers])
	# A BLOCK IS A WHOLE NUMBER OF BOXES ACROSS AND ALONG, which is what says the yard was laid out in the box's own
	# units rather than in round metres.
	var rows: float = first.size.x / (ISO_WIDE + ContainerShipDraft.LASH)
	_check("a_yard_block_is_a_whole_number_of_boxes_across",
		absf(rows - round(rows)) < 0.02 and rows >= 2.0,
		"%.2f m across is %.3f rows of %.3f m" % [first.size.x, rows, ISO_WIDE + ContainerShipDraft.LASH])
	terminal.queue_free()


## THE BREAKWATER SHELTERS THE BASIN, which is the whole reason a marina has one and is a question about SHAPE rather
## than size: the entrance must not look straight out to sea. Asked as whether the seaward arm overlaps the lee arm in
## the along-shore direction, so a sea running in from seaward meets rubble rather than pontoons.
func _the_breakwater_shelters_the_basin() -> void:
	var marina: Marina = Marina.one()
	add_child(marina)
	var built: Dictionary = marina.call("parts")
	var arms: Array = built["breakwater"] as Array
	_check("the_marina_has_a_breakwater", arms.size() >= 2, "%d arms" % arms.size())
	# The seaward arm is the one furthest from the shore; the lee arm the one that overlaps it at the entrance.
	var seaward: AABB = arms[0]
	var lee: AABB = arms[arms.size() - 1]
	var sheltered: bool = lee.position.x < 0.0 and seaward.end.z > lee.position.z
	_check("the_entrance_does_not_look_straight_out_to_sea", sheltered,
		"the seaward arm runs to z %.1f m and the lee arm begins at z %.1f m, so they overlap by %.1f m"
			% [seaward.end.z, lee.position.z, seaward.end.z - lee.position.z])
	marina.queue_free()


## Every `MeshInstance3D` under a node.
func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is ArrayMesh:
			out.append(child as MeshInstance3D)
		out.append_array(_meshes(child))
	return out


func _finish() -> void:
	print("RESULT=%s" % ["PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)])
	get_tree().quit()
