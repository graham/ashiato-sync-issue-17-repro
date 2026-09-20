extends RefCounted
class_name RotorcraftKit
## THE PARTS EVERY HELICOPTER HERE IS BUILT FROM: a faceted loft for a fuselage or a boom, a rotor of real blades on a
## hub that turns, rods, boxes and wheels. `LightHelicopterAirframe`, `Uh60Airframe` and `ChinookAirframe` each draw
## their own shape out of these, so a blade or a hub is written once and all three helicopters get the same one.
##
## WHY IT EXISTS: until 2026-09-17 the three helicopters shared nothing but a `_build_horizontal_rotor` that drew each
## blade as a 2 x 0.075 x 0.20 m plank, and a helicopter's rotor is most of what it looks like from outside. A blade
## here is a lofted airfoil -- a rounded leading edge, a sharp trailing edge, a taper and a tip -- in six facets, which
## is what the user's "somewhat lower poly look ... old school feel" (2026-09-17) means for a blade.
##
## FACETED, NEVER SMOOTHED. Every triangle carries its own face normal, so a panel is a panel and an edge is a crease,
## as on the Cessna (`SkyhawkAirframe`). Colour is in the vertices, so a whole fuselage in two colours is one draw.
##
## WINDING: Godot treats CLOCKWISE as the front face. Every triangle here is ordered from the point it is told is
## inside, so the caller never thinks about winding, and every skin is double-sided anyway because a crew sits inside
## it and looks at its lining.

## BEYOND THIS A SMALL FITTING IS NOT DRAWN. Mobile has no dependency fade, so it is a clean cut (see Uh60Airframe).
const DETAIL_RANGE := 500.0
## HOW FAST A DRAWN ROTOR TURNS, in turns a second, on the physics clock every machine shares. NOT the real rate: a
## UH-60's rotor turns at 4.3 Hz, which at 72 frames a second strobes into a stationary or backwards-turning wheel. At a
## little over one turn a second a blade is still a blade to the eye and the rotor still reads as running.
const MAIN_TURNS := 1.15
## A tail rotor turns about five times as fast as the main rotor on every helicopter drawn here.
const TAIL_TURNS := 4.6
## HOW MUCH OF THE DISC SHOWS, at most, over the moving blades: a hint of the swept disc, never a solid plate.
const DISC_ALPHA := 0.16


## ---- materials --------------------------------------------------------------------------------------------------

## THE SKIN: colour from the vertices, double-sided because the crew are inside it.
static func paint() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# THE COLOURS ARE WRITTEN AS SRGB, as every `albedo_color` in this project is; without this they read as linear
	# and the yellow came out cream (first picture, 2026-09-17).
	material.vertex_color_is_srgb = true
	material.roughness = 0.68
	material.metallic = 0.08
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## THE GLASS, tinted and see-through both ways: a pilot flies by what is outside it.
static func glass() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.12
	material.metallic = 0.25
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## THE SWEPT DISC, unshaded and faint, drawn only while the rotor runs.
static func disc_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.08, 0.09, 0.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## ---- triangles ------------------------------------------------------------------------------------------------------

static func tool() -> SurfaceTool:
	var made := SurfaceTool.new()
	made.begin(Mesh.PRIMITIVE_TRIANGLES)
	return made


## ONE FLAT TRIANGLE, facing away from `inside`.
static func tri(into: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, colour: Color) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	if normal.length_squared() < 1e-12:
		return
	normal = normal.normalized()
	var centre: Vector3 = (a + b + c) / 3.0
	if normal.dot(centre - inside) < 0.0:
		normal = -normal
	else:
		# Right-handed (b - a) x (c - a) faces the viewer counter-clockwise; Godot's front face is clockwise.
		var swap := b
		b = c
		c = swap
	into.set_color(colour)
	into.set_normal(normal)
	into.add_vertex(a)
	into.set_color(colour)
	into.set_normal(normal)
	into.add_vertex(b)
	into.set_color(colour)
	into.set_normal(normal)
	into.add_vertex(c)


static func quad(into: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3,
		colour: Color) -> void:
	tri(into, a, b, c, inside, colour)
	tri(into, a, c, d, inside, colour)


## ---- sections and lofts -------------------------------------------------------------------------------------------

## A TWELVE-POINT FUSELAGE SECTION at station `z`: a shallow vee keel, a chine, sides that bulge to `half` at mid
## height, a shoulder and a shallow ridged roof. `keel` and `crown` are how far out, as fractions of `half`, the keel
## and the roof run before the chine and the shoulder turn; `lower` and `upper` how much of the height those take.
##
## NO FACET IS SQUARE TO THE CRAFT'S AXES, ON PURPOSE. An eight-point section with flat sides, a flat roof and a flat
## keel was tried first and `craft_model_audit` read the light helicopter as 0.78 slab -- between the gunboat and the
## carrier, a box with its corners cut off. A crease down the roof and the keel and a bulge in the side is what a
## real cabin has, and it is still twelve facets: faceted, not round.
##
## THE FACETS ARE NUMBERED from the keel's middle round the starboard side and back along the port side, and
## `facet_is` names them, so a loft's `style` asks "is this a side?" rather than counting.
static func section(z: float, half: float, low: float, high: float, keel: float = 0.75, crown: float = 0.7,
		lower: float = 0.22, upper: float = 0.26, centre_x: float = 0.0) -> PackedVector3Array:
	var tall: float = high - low
	var side_low: float = low + tall * lower
	var side_high: float = high - tall * upper
	var vee: float = tall * 0.035
	var ridge: float = tall * 0.035
	var points := PackedVector3Array()
	var starboard: Array[Vector2] = [Vector2(0.0, low), Vector2(half * keel, low + vee),
		Vector2(half * 0.96, side_low), Vector2(half, (side_low + side_high) * 0.5), Vector2(half * 0.96, side_high),
		Vector2(half * crown, high - ridge)]
	for point in starboard:
		points.append(Vector3(centre_x + point.x, point.y, z))
	points.append(Vector3(centre_x, high, z))
	for index in range(starboard.size() - 1, 0, -1):
		points.append(Vector3(centre_x - starboard[index].x, starboard[index].y, z))
	return points


## WHAT FACET `facet` OF A `section` IS: &"keel", &"chine", &"lower" (side), &"upper" (side), &"shoulder" or
## &"roof". Facets 0 to 5 are starboard and 6 to 11 port.
static func facet_is(facet: int) -> StringName:
	var from_keel: int = facet if facet < 6 else 11 - facet
	return [&"keel", &"chine", &"lower", &"upper", &"shoulder", &"roof"][from_keel]


## A LOFT through rings of equal size. `style.call(span, facet)` answers what each panel is: a Color for skin in that
## colour, a Color with alpha under 1 for glass, or null for an opening. `span` is the gap between ring `span` and
## ring `span + 1`; the front cap is asked as span -1 and the back cap as span `rings.size() - 1`, facet 0.
static func loft(skin: SurfaceTool, glazing: SurfaceTool, rings: Array, style: Callable) -> void:
	for span in range(rings.size() - 1):
		var near: PackedVector3Array = rings[span]
		var far: PackedVector3Array = rings[span + 1]
		var inside: Vector3 = (_middle(near) + _middle(far)) * 0.5
		for facet in range(near.size()):
			var next: int = (facet + 1) % near.size()
			var answer: Variant = style.call(span, facet)
			if answer == null:
				continue
			var colour: Color = answer
			quad(glazing if colour.a < 1.0 else skin, near[facet], near[next], far[next], far[facet], inside, colour)
	for end in [0, rings.size() - 1]:
		var ring: PackedVector3Array = rings[end]
		var answer: Variant = style.call(-1 if end == 0 else end, 0)
		if answer == null:
			continue
		var colour: Color = answer
		var middle: Vector3 = _middle(ring)
		# THE INSIDE OF A CAP IS TOWARDS THE REST OF THE LOFT.
		var inward: Vector3 = _middle(rings[1] if end == 0 else rings[end - 1])
		for facet in range(ring.size()):
			tri(glazing if colour.a < 1.0 else skin, middle, ring[facet], ring[(facet + 1) % ring.size()],
				inward, colour)


## HALFWAY BETWEEN THE EXTREMES, not the mean of the points: a mean over a ring is a mean over how it was sampled.
static func _middle(ring: PackedVector3Array) -> Vector3:
	var box := AABB(ring[0], Vector3.ZERO)
	for point in ring:
		box = box.expand(point)
	return box.get_center()


## A RING OF `sides` POINTS round an axis, for a boom, a strut or a tube: centred on `at`, in the plane square to
## `along`, `radius_x` across and `radius_y` up. `turn` starts the first point off the vertical.
static func ring(at: Vector3, along: Vector3, radius_x: float, radius_y: float, sides: int = 8,
		turn: float = 0.0) -> PackedVector3Array:
	var forward: Vector3 = along.normalized()
	var up: Vector3 = Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.95 else Vector3.BACK
	var across: Vector3 = up.cross(forward).normalized()
	up = forward.cross(across).normalized()
	var points := PackedVector3Array()
	for side in range(sides):
		var angle: float = turn + TAU * float(side) / float(sides)
		points.append(at + across * cos(angle) * radius_x + up * sin(angle) * radius_y)
	return points


## A PRISM from `a` to `b`: a rod, a strut, a tube.
static func rod(into: SurfaceTool, a: Vector3, b: Vector3, radius: float, colour: Color, sides: int = 6,
		end_radius: float = -1.0) -> void:
	var far_radius: float = radius if end_radius < 0.0 else end_radius
	loft(into, into, [ring(a, b - a, radius, radius, sides, PI / float(sides)),
		ring(b, b - a, far_radius, far_radius, sides, PI / float(sides))], func(_s, _f): return colour)


## A PRISM THROUGH SEVERAL POINTS, for a bent tube such as a skid or a cross tube.
static func bent_rod(into: SurfaceTool, points: Array[Vector3], radius: float, colour: Color, sides: int = 6) -> void:
	var rings: Array = []
	for index in range(points.size()):
		var before: Vector3 = points[maxi(index - 1, 0)]
		var after: Vector3 = points[mini(index + 1, points.size() - 1)]
		rings.append(ring(points[index], after - before, radius, radius, sides, PI / float(sides)))
	loft(into, into, rings, func(_s, _f): return colour)


## A BOX, centred on `at`, turned by `turn`.
static func box(into: SurfaceTool, at: Vector3, size: Vector3, colour: Color, turn: Basis = Basis.IDENTITY) -> void:
	var half: Vector3 = size * 0.5
	var front: PackedVector3Array = PackedVector3Array()
	var back: PackedVector3Array = PackedVector3Array()
	for corner in [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
		front.append(at + turn * Vector3(corner.x * half.x, corner.y * half.y, -half.z))
		back.append(at + turn * Vector3(corner.x * half.x, corner.y * half.y, half.z))
	loft(into, into, [front, back], func(_s, _f): return colour)


## A WHEEL: an eight-sided tyre on an axle along x.
static func wheel(into: SurfaceTool, at: Vector3, radius: float, wide: float, colour: Color) -> void:
	rod(into, at - Vector3(wide * 0.5, 0.0, 0.0), at + Vector3(wide * 0.5, 0.0, 0.0), radius, colour, 8)


## A FLAT PLATE of some thickness through an outline, for a fin or a stabiliser: `outline` in the plate's plane, the
## plate `thick` across `normal`.
static func plate(into: SurfaceTool, outline: Array[Vector3], normal: Vector3, thick: float, colour: Color) -> void:
	var offset: Vector3 = normal.normalized() * thick * 0.5
	var one := PackedVector3Array()
	var two := PackedVector3Array()
	for point in outline:
		one.append(point - offset)
		two.append(point + offset)
	loft(into, into, [one, two], func(_s, _f): return colour)


## ---- rotors ---------------------------------------------------------------------------------------------------------

## ONE BLADE as a six-point airfoil lofted from `root` to `tip`, about the shaft `shaft`: a rounded leading edge ahead,
## a sharp trailing edge behind, `thick` of the chord deep at the root and thinner at the tip, and a closed tip.
## `lead` is the direction the blade moves, which is where its leading edge goes.
static func blade(into: SurfaceTool, root: Vector3, tip: Vector3, shaft: Vector3, lead: float,
		chord_root: float, chord_tip: float, thick: float, colour: Color, tip_colour: Color) -> void:
	var span: Vector3 = (tip - root).normalized()
	var ahead: Vector3 = shaft.normalized().cross(span).normalized() * signf(lead)
	var up: Vector3 = shaft.normalized()
	var rows: Array = []
	var stations: Array[float] = [0.0, 0.88, 1.0]
	for at in stations:
		var chord: float = lerpf(chord_root, chord_tip, at)
		var deep: float = chord * lerpf(thick, thick * 0.6, at)
		var centre: Vector3 = root.lerp(tip, at)
		rows.append(PackedVector3Array([
			centre + ahead * chord * 0.30,
			centre + ahead * chord * 0.22 + up * deep * 0.5,
			centre - ahead * chord * 0.20 + up * deep * 0.32,
			centre - ahead * chord * 0.70,
			centre - ahead * chord * 0.20 - up * deep * 0.18,
			centre + ahead * chord * 0.22 - up * deep * 0.34,
		]))
	loft(into, into, rows, func(span_index, _facet): return tip_colour if span_index == 1 else colour)


## A ROTOR: a node named `label` at `hub`, turned so its local +Y is the shaft `shaft_basis.y`, holding
## `<label>Hub`, `<label>Blades` and `<label>Disc`. Every blade is in the one `Blades` mesh, so a rotor of four
## blades is one draw. `blades` blades of `radius` metres from the shaft to the tip, the first at `phase` radians.
## `hub_radius` is the hub's own; the blade roots start just inside it so each blade is bedded in the hub.
## Returns the pivot, which `turn` spins.
static func rotor(parent: Node3D, label: String, hub: Vector3, shaft_basis: Basis, radius: float, blades: int,
		chord: float, hub_radius: float, hub_height: float, blade_colour: Color, tip_colour: Color,
		hub_colour: Color, material: Material, spin: float = 1.0, phase: float = 0.0) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = hub
	pivot.basis = shaft_basis
	pivot.set_meta(&"rest", shaft_basis)
	pivot.set_meta(&"spin", spin)
	# HOW MANY BLADES, asked of the rotor rather than counted off mesh names: they are one mesh.
	pivot.set_meta(&"blades", blades)
	parent.add_child(pivot)
	# THE HUB: a hexagonal drum with a grip for each blade.
	var head := tool()
	rod(head, Vector3(0.0, -hub_height * 0.5, 0.0), Vector3(0.0, hub_height * 0.5, 0.0), hub_radius, hub_colour, 6)
	rod(head, Vector3(0.0, hub_height * 0.5, 0.0), Vector3(0.0, hub_height * 0.95, 0.0), hub_radius * 0.55,
		hub_colour, 6, hub_radius * 0.25)
	for index in range(blades):
		var angle: float = phase + TAU * float(index) / float(blades)
		var out := Vector3(cos(angle), 0.0, -sin(angle))
		rod(head, out * hub_radius * 0.5, out * (hub_radius + chord * 0.9), hub_height * 0.26, hub_colour, 6)
	part(pivot, label + "Hub", head, material)
	var sweep := tool()
	for index in range(blades):
		var angle: float = phase + TAU * float(index) / float(blades)
		var out := Vector3(cos(angle), 0.0, -sin(angle))
		blade(sweep, out * (hub_radius + chord * 0.6), out * radius, Vector3.UP, spin, chord, chord * 0.82, 0.13,
			blade_colour, tip_colour)
	part(pivot, label + "Blades", sweep, material)
	# THE DISC CIRCUMSCRIBES THE SWEPT CIRCLE: a faceted disc inscribed in it would be smaller than the rotor.
	var face := tool()
	var sides: int = 24
	var reach: float = radius / cos(PI / float(sides))
	for side in range(sides):
		var one: float = TAU * float(side) / float(sides)
		var two: float = TAU * float(side + 1) / float(sides)
		tri(face, Vector3.ZERO, Vector3(cos(one) * reach, 0.0, sin(one) * reach),
			Vector3(cos(two) * reach, 0.0, sin(two) * reach), Vector3(0.0, -1.0, 0.0), Color.WHITE)
	var disc := part(pivot, label + "Disc", face, disc_material())
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.visible = false
	return pivot


## SPIN A ROTOR BUILT BY `rotor` to `turns` turns, in its own sense; `shown` how solid its disc is, 0 to 1.
static func turn(pivot: Node3D, turns: float, shown: float) -> void:
	if pivot == null:
		return
	var rest: Basis = pivot.get_meta(&"rest", Basis.IDENTITY)
	var spin: float = float(pivot.get_meta(&"spin", 1.0))
	pivot.basis = rest * Basis(Vector3.UP, fposmod(turns, 1.0) * TAU * spin)
	var disc := pivot.get_node_or_null(NodePath(String(pivot.name) + "Disc")) as MeshInstance3D
	if disc != null:
		disc.visible = shown > 0.0
		(disc.material_override as StandardMaterial3D).albedo_color.a = DISC_ALPHA * clampf(shown, 0.0, 1.0)


## ---- fittings every helicopter here has -----------------------------------------------------------------------------

## AN ARM FROM THE DOOR SILL UP TO EACH DOOR GUN'S PINTLE POST, one per fitted pintle gun on `kind`. The gun and its post
## are VehicleView's, drawn where the simulation mounts the gun (`Sim.gun_of`); this is only what bolts that post to the
## helicopter, so it is ASKED where the post stands rather than told. `sill_in` is how far inboard of the post, and
## `sill_y` how high, the arm's foot is bedded in the cabin floor.
static func door_gun_arms(parent: Node3D, kind: int, sill_in: float, sill_y: float, material: Material,
		colour: Color) -> void:
	for mount in range(4):
		var gun: Dictionary = Sim.gun_of(kind, mount)
		if not bool(gun.get("fitted", false)) or not bool(gun.get("pintle", false)):
			continue
		var at: Vector3 = gun.get("at", Vector3.ZERO)
		# THE POST'S FOOT: VehicleView stands a 0.45 m post centred 0.225 m under the gun.
		var foot := at - Vector3(0.0, 0.45, 0.0)
		var side: float = signf(at.x) if absf(at.x) > 0.01 else 0.0
		var arm := tool()
		var sill := Vector3(at.x - side * sill_in, sill_y, at.z + (sill_in if side == 0.0 else 0.0))
		bent_rod(arm, [sill, Vector3(foot.x, lerpf(sill_y, foot.y, 0.35), foot.z), foot + Vector3(0.0, 0.02, 0.0)],
			0.035, colour, 6)
		part(parent, "DoorGunArm%d" % mount, arm, material, true)


## A SEAT AT EVERY STATION `kind` HAS, from the seat poses the simulation publishes: a canvas pan and back on a frame,
## turned the way the station faces, behind the anchor where a person's hips are. Named by seat index.
static func crew_seats(parent: Node3D, kind: int, material: Material, canvas: Color, frame: Color) -> void:
	var poses: Array = Sim.geometry_of(kind).get("seat_poses", []) as Array
	# NOT UNDER A PILOT WHO HAS A CHAIR: `VehicleView` puts a `PilotSeat` on those seats' anchors, and two seats in one
	# place is one too many (2026-09-18).
	var chaired: PackedStringArray = VehicleCatalogue.chairs(kind, poses.size())
	for index in range(poses.size()):
		if not chaired[index].is_empty():
			continue
		var pose: Dictionary = poses[index]
		var at: Vector3 = pose.get("position", Vector3.ZERO)
		var facing := Basis(Vector3.UP, float(pose.get("yaw", 0.0)))
		var seat := tool()
		box(seat, at + facing * Vector3(0.0, 0.40, 0.12), Vector3(0.50, 0.08, 0.48), canvas, facing)
		box(seat, at + facing * Vector3(0.0, 0.78, 0.40), Vector3(0.50, 0.70, 0.07), canvas, facing)
		box(seat, at + facing * Vector3(0.0, 0.18, 0.12), Vector3(0.40, 0.36, 0.40), frame, facing)
		part(parent, "CrewSeat%d" % index, seat, material)


## ---- parts ----------------------------------------------------------------------------------------------------------

## A NAMED PART from what `into` holds. Every part is named by its caller, with every loop variable in the name.
static func part(parent: Node3D, label: String, into: SurfaceTool, material: Material,
		detail: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = into.commit()
	node.material_override = material
	if detail:
		node.visibility_range_end = DETAIL_RANGE
	parent.add_child(node)
	return node
