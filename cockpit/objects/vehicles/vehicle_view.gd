@tool
extends Node3D
class_name VehicleView
## One vehicle, drawn. Owns no state and decides nothing.
##
## Its ENTIRE job is to sit at the right place each render frame, because everything a
## player can see -- their own cockpit, their hands, the other aircraft, the pilots in
## them -- is a child of one of these. If this is smooth, everything is smooth. If it is
## not, nothing else can rescue it.
##
## Placed by interpolating between the last two simulated states by Godot's own physics
## fraction, which is computed against the same clock the simulation was ticked on. There
## is no second clock and no accumulator; see Sim for why that matters.

const ReferenceAirframeMeshes = preload("res://objects/vehicles/reference_airframe_meshes.gd")

var entity: int = 0
var kind: int = 0

## WHAT THIS CRAFT SOUNDS LIKE, or null on the hundred and forty nobody is in. Built and
## freed with the stations, in `man`, and driven from the interpolated state in `draw`.
var sound: VehicleSound = null

## HOW MANY MOUNTS a craft may carry, matching kMaxTurrets in cockpit_components.hpp.
const MAX_TURRETS: int = 3

## HOW MANY ROAD WHEELS A TANK HAS A SIDE. An M1 Abrams of any mark has seven, and the hull
## this is drawn round is Abrams-sized; it was drawn with five until 2026-09-17. Counted by
## name, not by this constant, in `tests/tank_shape.gd`.
const ROAD_WHEELS_A_SIDE: int = 7

## THE REST OF THE RUNNING GEAR, IN METRES OFF THE GROUND THE PHYSICS PUTS THE HULL BOX ON.
##
## The track and the road wheel are the M1's own: a T158 track is 25 in wide and a road wheel 25 in
## across. The sprocket and the idler are NOT a measurement and are not written as one -- what is
## certain is that a drive sprocket stands larger than a road wheel because the track pitches round
## its teeth, and that an idler is a third size again; the steps here are what make the three
## tellable apart, and a drawing would replace them.
const TANK_TRACK_WIDE: float = 0.635
const TANK_ROAD_WHEEL: float = 0.635
const TANK_ROAD_WHEEL_WIDE: float = 0.58
const TANK_TRACK_THICK: float = 0.12
const TANK_SPROCKET: float = 0.72
const TANK_IDLER: float = 0.66
const TANK_END_WHEEL_WIDE: float = 0.55
## How far the sprocket and the idler stand OVER the road-wheel line. An Abrams' track is a
## trapezoid seen from the side, not an oval: the ground run is flat under the road wheels and then
## climbs at each end to an idler and a sprocket carried high. At 0.22 m over the axles and 0.67 m
## outboard of the last road wheel, that climb is 42 degrees, which is what the side of one looks
## like. At zero the track would be a stadium shape and the two ends would be indistinguishable.
const TANK_AXLE_RISE: float = 0.22
## Where the sprocket and the idler sit along the hull, and where the road wheels stop, each as a
## share of the hull's half-length. The gap between them is the length of the climb.
const TANK_END_STATION: float = 0.85
const TANK_WHEEL_STATION: float = 0.68
## HOW MANY SIDES A DRAWN WHEEL HAS. Twelve is the house low-poly look; see `_faceted_wheel` for
## the two things that have to be true of a polygon standing in for a circle.
const TRACK_FACETS: int = 12

## The back seats' station, drawn. Null until setup has run.
var _turret: Node3D = null
## Every mount on this craft, one per turret seat, aimed independently.
var _turrets: Array = []
## THE AIRFRAME: every part painted in the craft's own colour. Kept as a list so it can be
## ghosted as one when somebody is sitting inside it -- see `_show_body`.
var _body: Array = []
var _visual_scene: Node3D = null
## THE PANELS THE HULL IS MADE OF, as plain boxes, or empty for a craft still drawn as one.
## Kept so that "can the pilot see out" is arithmetic rather than a physics query -- see
## HullSkin.is_clear, which the tests use with no world running.
var _panels: Array = []
## THE ROOM AN INLINE-BUILT AIRFRAME PROMISES ROUND ITS CREW, filled in by the builder that
## drew it and empty for one that has not worked it out. See `cabin_room`, which prefers it.
##
## PUBLISHED BY THE BUILDER, NOT LOOKED UP BY KIND. `cabin_room` asks `_visual_scene`,
## `_hawkeye` and `_rotorcraft` by method name so a new airframe SCENE opts in by growing a method;
## a craft this file draws inline has no object to grow, and the alternative was a switch on
## `kind` here -- which is the roster that goes out of date the day somebody adds a craft.
## Filling this in the builder keeps the opt-in next to the geometry it describes.
var _own_cabin_room: Dictionary = {}
## The greenhouse the crew sit in, above the fuselage. Zero-sized on a craft without one.
var _cabin: AABB = AABB()
## The command bus this kind is fitted with, read once. See craft_state.
var _fitted: Array = []
var _paint: StandardMaterial3D = null
var _ghosted: bool = false
## The crew stations currently in this craft, by seat index. Empty on anything nobody is
## sitting in, which is nearly everything.
var _stations: Dictionary = {}
## HOW LONG `man` MAY SPEND BUILDING STATIONS IN ONE FRAME, milliseconds; 0 builds every seat in the call that asks.
##
## A station is about 18 ms to build: sixty-four of them were 1.15 s in one frame when the first person sat down
## (learnings/2026-09-18-seats.md). A frame that long is not only a hitch you see. It is also a machine that sends no
## ACKs for a second, and ashiato-sync 8fa08cf does not recover an entity whose baseline goes that stale: the craft
## froze for good on that machine (S-12, ErikGoldman/ashiato-sync#12). So the flight level sets `GAME_BUILD_MS`, and
## `man` builds this machine's own seat first, then the seats somebody is in, then the rest, at least one a frame and
## no more once the budget is spent; the rest follow over the next frames. Everything else -- the editor's preview, a
## suite that mans a craft and looks at once -- keeps 0, which is the build it always had.
var station_build_budget_ms: float = 0.0
## The flight level's budget: a quarter of a 60 Hz frame.
const GAME_BUILD_MS: float = 4.0
## The single throttle a crew SHARE, where a craft has one. Typed as the base class
## because an airliner's is a quadrant lever and a Cessna's is a plunger, and nothing that
## reads it cares which.
var _pedestal: VehicleControl = null
## role -> control, for everything the VEHICLE owns rather than a seat. Empty on a craft
## nobody is in, and on one whose bus carries none of it.
var _console: Dictionary = {}
## THE V-22'S AIRFRAME, drawn whole by `OspreyAirframe`, its nacelles swung from the bus and its proprotors turned on
## the physics clock every frame, both played from `_osprey_casting` where there is a renderer. Null on everything else.
var _osprey: OspreyAirframe = null
var _osprey_casting: VatCasting = null
## WHERE THE V-22'S RAMP IS DRAWN, 0 shut to 1 down, eased toward the bus's ramp bit (the drop channel) as its gear is
## eased toward the gear bit, in `_gear_drawn`.
var _ramp_drawn: float = 0.0
## A SHIP UNDER SAIL's hull, masts and sails, trimmed in `draw` from the rigging the wire carries. Null on everything else.
var _brig: BrigRig = null
## THE E-2D'S AIRFRAME, drawn by its own builder and NOT in `_body`: see HawkeyeAirframe.
var _hawkeye: HawkeyeAirframe = null
## THE HELICOPTER'S AIRFRAME, drawn whole by its own class and NOT in `_body`, as the Hawkeye's is: `Uh60Airframe`,
## `LightHelicopterAirframe` or `ChinookAirframe`, all built from `RotorcraftKit` and all answering `set_rotors`,
## `cabin_room` and `show_layers`. Null on everything that is not a helicopter.
var _rotorcraft: Node3D = null
## THE F-14D'S AIRFRAME, drawn whole by `TomcatAirframe`, and the VAT its swing wing is played from. The wing is drawn at
## `_sweep_drawn`, eased toward the bus's actual sweep: see `_draw_the_wing_sweep`.
var _phantom: PhantomAirframe = null
var _tomcat: TomcatAirframe = null
## PORCO ROSSO'S SAVOIA, drawn whole by `SavoiaAirframe`: its surfaces and propeller from the linkage, as the Cessna's.
var _savoia: SavoiaAirframe = null
var _tomcat_casting: VatCasting = null
var _sweep_drawn: float = TomcatAirframe.SWEEP_FORWARD
## THE F-16A'S AIRFRAME, drawn whole by `FalconAirframe`: its flaperons, tailplanes and rudder from the stick and its
## gear from the bus, in `_draw_the_falcon`. Null on everything else.
var _falcon: FalconAirframe = null
## THE DUO DISCUS'S AIRFRAME, drawn whole by `SailplaneAirframe`: its ailerons and elevator from the stick, its rudder from
## the pedals, its airbrakes from the bus, in `_draw_the_sailplane`. Null on everything else.
var _sailplane: SailplaneAirframe = null
## THE F-35B'S AIRFRAME, drawn whole by `LightningAirframe`, in `_draw_the_lightning`. Null on everything else.
var _lightning: LightningAirframe = null
var _lightning_casting: VatCasting = null
## THE A-10C'S AIRFRAME, drawn whole by `WarthogAirframe`, in `_draw_the_warthog`. Null on everything else.
var _warthog: WarthogAirframe = null
var _warthog_casting: VatCasting = null
## WHERE THE A-10C'S GEAR AND SPEED BRAKE ARE DRAWN, 0 to 1, each eased toward its bus bit; and its GAU-8: the barrels'
## phase, how fast they are turning as a share of `WarthogAirframe.GUN_PASSES`, the drum's count last frame and the
## seconds the gun is still held to be firing (see `draw_the_warthog_from`).
var _warthog_gear: float = 1.0
var _warthog_brake: float = 0.0
var _warthog_gun_phase: float = 0.0
var _warthog_gun_spin: float = 0.0
var _warthog_rounds: int = -1
var _warthog_firing_for: float = 0.0
## A PISTON WARBIRD'S AIRFRAME, drawn whole by its own class (`warbird_for`), in `_draw_the_warbird`; null on everything
## else. Its gear as drawn, eased toward the bus's bit, and its propeller's phase.
var _warbird: WarbirdAirframe = null
var _warbird_casting: VatCasting = null
var _warbird_gear: float = 1.0
var _warbird_prop: float = 0.0
## WHERE THE F-35B'S GEAR IS DRAWN, 0 up to 1 down, eased toward the bus's bit at `LightningAirframe.GEAR_SECONDS` a cycle.
var _gear_drawn: float = 1.0
## WHERE THE F-35B'S BAY DOORS ARE DRAWN, starboard then port, eased toward the bays' bits over `LightningAirframe.BAY_SECONDS`.
var _bays_drawn: Array[float] = [0.0, 0.0]
## THE MISSILES ON A JET'S RAILS, shown from the craft's `stores` bits (`HungStores`), on a kind whose catalogue entry
## asks for them. Null on everything else.
var _stores: HungStores = null
## THE EA-6B PROWLER, its four rigid moving-surface tables and the renderer-only casting poured from them.
var _prowler: ProwlerAirframe = null
var _prowler_casting: VatCasting = null
## A BOEING JETLINER, drawn whole by its `JetlinerAirframe` (`jetliner_class`), and the VAT its moving parts are played
## from. Null on everything else.
var _jetliner: JetlinerAirframe = null
var _jetliner_casting: VatCasting = null
## THE F/A-18F'S VISUAL SCENE, when the package's scene is that airframe: its gear and hook are drawn from the bus in
## `draw`. Null on everything else.
var _fighter: FighterAirframe = null
## THE NOSE MARKER `_mark_the_ends` stands on a box-drawn craft. Kept out of `_body`, which ghosting repaints, because its
## colour is its own; named here so a visual scene can hide it with the rest of the procedural airframe.
var _nose: MeshInstance3D = null
## How far folded the Hawkeye's wings are drawn, 0 spread and 1 folded, eased toward the bus's bit.
var _fold_drawn: float = 0.0
## THE CESSNA 172S'S VISUAL SCENE, when the package's scene is that airframe: its flaps, trim tab, stick surfaces and
## propeller are drawn from the bus and the linkage in `draw`. Null on everything else.
var _skyhawk: SkyhawkAirframe = null
## THE LIGHTS, once hung: see `_hang_the_lights`.
var _lights: VehicleLights = null

@onready var _hull: MeshInstance3D = $Hull
## Where pilots sit, one marker per seat, so a remote pilot can be parented to theirs.
var seats: Array[Node3D] = []


## THE CRAFT SHOWN IN THE EDITOR when this scene is opened on its own. Set it and the hull,
## the wing, the rotors and every seat's cockpit appear, at the sizes the SIMULATION says --
## `Sim.geometry_of` asks a throwaway CockpitWorld, so there is no second copy of the shape
## table to drift out of step.
##
## A vehicle scene is worth looking at for the things a running game hides: whether a seat is
## inside its own fuselage, whether the ramp seat clears the ramp, whether a gun is over the
## gunner. None of those need physics and all of them need to be seen.
@export var preview_kind: Sim.Kind = Sim.Kind.PLANE:
	set(value):
		preview_kind = value
		if Engine.is_editor_hint() and is_inside_tree():
			_show_in_editor()


func _ready() -> void:
	if Engine.is_editor_hint():
		_show_in_editor()


## Build the whole craft, seats and all, with nobody in it and nothing running.
func _show_in_editor() -> void:
	# Everything the last preview built. The Hull is the scene's own node and is kept.
	for child in get_children():
		if child.name != "Hull":
			remove_child(child)
			child.queue_free()
	seats.clear()
	_stations.clear()
	_body.clear()
	_turrets.clear()
	_pedestal = null
	_console.clear()
	_paint = null
	_panels = []
	_cabin = AABB()
	var hull := get_node_or_null("Hull") as MeshInstance3D
	if hull == null:
		hull = MeshInstance3D.new()
		hull.name = "Hull"
		add_child(hull)
	_hull = hull
	setup(0, preview_kind)
	var every: Array = []
	for i in range(seats.size()):
		every.append(i)
	man(every, -1)


func setup(vehicle_entity: int, vehicle_kind: int) -> void:
	entity = vehicle_entity
	kind = vehicle_kind
	var geometry: Dictionary = Sim.geometry_of(kind)

	# The hull is built from the SIMULATION's own extents. A constant here and a matching
	# constant in the C++ agree until one of them changes, and then the thing you can see
	# is a different size from the thing you collide with -- which is maddening precisely
	# because it looks correct.
	var material := StandardMaterial3D.new()
	material.albedo_color = VehicleCatalogue.paint(kind)
	material.roughness = 0.7
	_hull.material_override = material
	_paint = material
	_body.append(_hull)

	# A SKIN WITH WINDOWS IN IT, or the old solid box for a kind that has not been given a
	# glazing schedule yet. Both go on the SAME node: `Hull` is authored in every craft
	# scene, bound by @onready, and is the one child `_show_in_editor` keeps, so what
	# changes is the mesh on it and never the shape of the tree.
	_fitted = Sim.schema_of(kind).get("channels", []) as Array
	var plan: Dictionary = VehicleCatalogue.glazing(kind)
	_cabin = _greenhouse(geometry)
	# A SHIP IS DRAWN FROM ITS PARTS, and has no box, no nose cone and no tail cone: a bow is
	# a front, and a flight deck is not a box. See ShipHull.
	var ship: bool = not (geometry.get("parts", []) as Array).is_empty()
	if ship:
		_hull.mesh = null
		_panels = []
	elif plan.is_empty() or _cabin.size.z <= 0.0:
		var box := BoxMesh.new()
		box.size = (geometry.get("extents", Vector3.ONE) as Vector3) * 2.0
		_hull.mesh = box
		_panels = []
	else:
		var skin: Dictionary = HullSkin.build(
			geometry.get("extents", Vector3.ONE) as Vector3, _cabin, plan)
		_hull.mesh = skin["mesh"]
		_panels = skin["panels"]

	# A NOSE, because a box has no front and a pilot needs one -- and SIZED FROM THE
	# AIRCRAFT, which the first version was not.
	#
	# It was a fixed 0.44 m cone whatever it was stuck on. On the light aeroplane, which is
	# 1.5 m across, that is a beak you can see from a mile off. On the airliner, which is
	# five metres across and twenty-six long, it is a pimple on the end of a featureless
	# box: the thing genuinely had no visible front, and every report of an aeroplane "not
	# oriented forward" was somebody looking at one and being unable to tell.
	# A SHIP UNDER SAIL IS DRAWN WHOLE BY ITS OWN BUILDER, in place of the box and the end markers, and here in `setup`
	# rather than in `_build_wing`, which returns before any body branch on a craft with no span (cockpit-carrier found
	# the carrier and the battleship were never drawn for that reason).
	if VehicleCatalogue.body(kind) == VehicleCatalogue.Body.BRIG:
		_retire_the_hull()
		_brig = BrigRig.build(geometry.get("rig", {}) as Dictionary, geometry.get("extents", Vector3.ONE) as Vector3)
		add_child(_brig)
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.HAWKEYE:
		# THE HAWKEYE IS DRAWN WHOLE, in place of the box and the end markers, as the brig is. Its wings start where the
		# bus has them, so a Hawkeye parked folded is not seen folding on its first frames.
		_retire_the_hull()
		_hawkeye = HawkeyeAirframe.new()
		_hawkeye.dress(geometry)
		_fold_drawn = 1.0 if entity > 0 and Sim.client != null and bool(Sim.client.craft_controls(entity).get("fold", false)) else 0.0
		_hawkeye.fold(_fold_drawn)
		add_child(_hawkeye)
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.SAVOIA:
		# THE SAVOIA IS DRAWN WHOLE, in place of the box and the end markers, as the Tomcat is.
		_retire_the_hull()
		_savoia = SavoiaAirframe.new()
		_savoia.dress(geometry)
		add_child(_savoia)
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.PHANTOM:
		# THE PHANTOM IS DRAWN WHOLE, in place of the box and the end markers, as the Tomcat is.
		_retire_the_hull()
		_phantom = PhantomAirframe.new()
		_phantom.dress(geometry)
		add_child(_phantom)
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.TOMCAT:
		# THE TOMCAT IS DRAWN WHOLE, in place of the box and the end markers, as the Hawkeye is. Its wings start where
		# the bus has them, so a Tomcat parked swept is not seen sweeping on its first frames.
		_retire_the_hull()
		_tomcat = TomcatAirframe.new()
		_tomcat.dress(geometry)
		_sweep_drawn = _sweep_on_the_bus()
		_tomcat.set_sweep(_sweep_drawn)
		add_child(_tomcat)
		_cast_the_tomcat()
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.FALCON:
		# THE F-16 IS DRAWN WHOLE, in place of the box and the end markers, as the Tomcat is.
		_retire_the_hull()
		_falcon = FalconAirframe.new()
		_falcon.dress(geometry)
		add_child(_falcon)
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.SAILPLANE:
		# THE DUO DISCUS IS DRAWN WHOLE, in place of the box and the end markers, as the F-16 is.
		_retire_the_hull()
		_sailplane = SailplaneAirframe.new()
		_sailplane.dress(geometry)
		add_child(_sailplane)
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.LIGHTNING:
		# THE F-35B IS DRAWN WHOLE, as the F-16 is. Its gear starts where the bus has it, so an F-35B issued in the air
		# is not seen lowering its wheels on its first frames.
		_retire_the_hull()
		_lightning = LightningAirframe.new()
		_lightning.dress(geometry)
		var issued_up: bool = entity > 0 and Sim.client != null \
			and not bool(Sim.client.craft_controls(entity).get("gear", true))
		_gear_drawn = 0.0 if issued_up else 1.0
		_lightning.set_gear(_gear_drawn)
		add_child(_lightning)
		_cast_the_lightning()
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.WARTHOG:
		# THE A-10C IS DRAWN WHOLE, as the F-35B is, its gear starting where the bus has it.
		_retire_the_hull()
		_warthog = WarthogAirframe.new()
		_warthog.dress(geometry)
		var warthog_up: bool = entity > 0 and Sim.client != null \
			and not bool(Sim.client.craft_controls(entity).get("gear", true))
		_warthog_gear = 0.0 if warthog_up else 1.0
		_warthog.set_gear(_warthog_gear)
		add_child(_warthog)
		_cast_the_warthog()
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.WARBIRD:
		# A WARBIRD IS DRAWN WHOLE, as the A-10C is, its gear starting where the bus has it. Drawn LEVEL in the body's
		# frame: the simulation rests a taildragger tail down itself (`roll_a_taildragger`), and `parked()` is only for a
		# picture with no simulation under it.
		_retire_the_hull()
		_warbird = warbird_for(kind)
		_warbird.dress(geometry)
		var warbird_up: bool = entity > 0 and Sim.client != null \
			and not bool(Sim.client.craft_controls(entity).get("gear", true))
		_warbird_gear = 0.0 if warbird_up else 1.0
		_warbird.set_gear(_warbird_gear)
		add_child(_warbird)
		_cast_the_warbird()
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.JETLINER:
		# A JETLINER IS DRAWN WHOLE, in place of the box and the end markers, as the F-16 is. Its box is its table's until
		# the kind's C++ shape matches (`JetlinerAirframe`).
		_retire_the_hull()
		_jetliner = jetliner_for(kind)
		_jetliner.dress(geometry)
		add_child(_jetliner)
		_cast_the_jetliner()
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.PROWLER:
		_retire_the_hull()
		_prowler = ProwlerAirframe.new()
		_prowler.dress(geometry)
		_fold_drawn = 1.0 if entity > 0 and Sim.client != null and bool(Sim.client.craft_controls(entity).get("fold", false)) else 0.0
		_prowler.fold(_fold_drawn)
		add_child(_prowler)
		_cast_the_prowler()
	elif VehicleCatalogue.body(kind) == VehicleCatalogue.Body.TILTROTOR:
		# THE V-22 IS DRAWN WHOLE, in place of the box and the end markers, as the Tomcat is. Its nacelles start where the
		# bus has them, so an Osprey parked in aeroplane mode is not seen swinging down on its first frames.
		_retire_the_hull()
		_osprey = OspreyAirframe.new()
		_osprey.dress(geometry)
		# THE GEAR AND THE RAMP START WHERE THE BUS HAS THEM, so an Osprey issued in the air is not seen raising its
		# gear on its first frames, nor one parked with its ramp down seen lowering it.
		var issued: Dictionary = Sim.client.craft_controls(entity) if entity > 0 and Sim.client != null else {}
		_gear_drawn = 1.0 if bool(issued.get("gear", true)) else 0.0
		_ramp_drawn = 1.0 if bool(issued.get("drop", false)) else 0.0
		_osprey.set_gear(_gear_drawn)
		_osprey.set_ramp(_ramp_drawn)
		add_child(_osprey)
		_draw_the_osprey()
		_cast_the_osprey()
	elif _rotorcraft_class() != null:
		# A HELICOPTER IS DRAWN WHOLE, in place of the box and the end markers. Until 2026-09-17 the light helicopter
		# was the box itself, painted yellow with a stick boom on it: a rotor craft never hid its cuboid.
		_retire_the_hull()
		_rotorcraft = _rotorcraft_class().new()
		_rotorcraft.name = "UH60Airframe" if kind == Sim.Kind.UH60 else String(_rotorcraft_class().get_global_name())
		_rotorcraft.call("dress", geometry)
		add_child(_rotorcraft)
		_draw_the_rotors()
	elif kind in [Sim.Kind.TANKER]:
		# These reference aircraft draw a complete rounded exterior below. The box remains
		# authoritative for collision, but showing it through the loft is what made the
		# gallery models look like crates with wings or rotors attached.
		_retire_the_hull()
	elif kind in [Sim.Kind.PLANE]:
		# These airframes supply their own nose, tail and lifting surfaces below.  Keeping
		# the generic end cones as well made a tanker look as though it had a second nose
		# and hid the sailplane's deliberately thin tail.
		pass
	elif kind in [Sim.Kind.CAR, Sim.Kind.TRAIN, Sim.Kind.TANK]:
		# These are complete, multi-part ground-vehicle models below. Leaving the generic
		# collision box visible would hide the cab, tracks and wheels that make each craft
		# legible, while turning it off changes no native shape or seat anchor.
		_hull.mesh = null
	elif kind == Sim.Kind.TOWER:
		# A CONTROL TOWER IS A STALK WITH A GLASS CAB ON IT, and until 2026-09-17 not one had
		# ever been drawn. The stalk, cab and roof were written at the bottom of `_build_wing`,
		# behind its `if span <= 0.0: return` -- and a tower has no span, because it does not
		# fly. So every tower in the game was the bare collision box this line now hides: a
		# plain 6.4 x 20 m concrete slab with no cab, no glass and no roof, and a controller
		# sitting 18.95 m up inside it. Nothing caught it; it was looked at.
		_retire_the_hull()
		_build_tower(geometry, material)
	elif kind == Sim.Kind.POD:
		# The hover pod is a small enclosed vehicle, not a one-metre freight crate.  Keep
		# the simulation box for collision, but hide it behind a rounded pressure hull and
		# a distinct dark canopy.  The fittings are visual-only and retain the seat's
		# authoritative local pose.
		_retire_the_hull()
		_build_pod_airframe(geometry.get("extents", Vector3.ONE) as Vector3)
	elif not ship:
		_mark_the_ends(geometry.get("extents", Vector3.ONE) as Vector3, material)
	else:
		# NOT IN `_body`, so a crew aboard does not ghost it away: a ship is a thing you stand
		# on and look out of, and its bow and deck are what a helm steers by. A silhouette far
		# away and the ship's own model near, swapped by distance: see ShipHull.dress.
		add_child(ShipHull.dress(kind, geometry))

	# One anchor per seat, at the pose the simulation says the seat has. Everything that
	# rides in this vehicle is parented to one of these, which is what makes a rider's
	# pose relative to the cockpit exactly constant rather than approximately.
	_build_wing(kind, float(geometry.get("span", 0.0)),
		geometry.get("extents", Vector3.ONE) as Vector3, material.albedo_color)
	_build_turret(geometry.get("extents", Vector3.ONE) as Vector3)
	_build_the_selected_guns()
	_finish_setup(geometry)
	_install_visual_scene(geometry)
	_hang_the_stores(kind)
	_hang_the_lights(geometry)


## THE OLD SKIN RETIRED, for every craft drawn whole by something else: hidden AND taken out of `_body`, here and nowhere
## else. `_show_body` sets every mesh in `_body` visible when a crew boards or leaves, so a hull that was only hidden
## stood back up inside the new airframe for everybody aboard -- the V-22's greenhouse across its pilots' view over the
## nose (lane/osprey, 2026-09-19). Thirteen other branches (brig to pod) had each copied `_hull.visible = false` alone.
## The node stays: it is the scene's own `Hull`, and the simulation's box is still what the craft collides with.
## tests/hull_hidden.gd boards and empties every kind and holds it.
func _retire_the_hull() -> void:
	_hull.visible = false
	_body.erase(_hull)


## THE MISSILES ON THE RAILS, on a kind that asks for them: where the simulation's schema says each rail is, full until the
## bus says otherwise.
func _hang_the_stores(kind: int) -> void:
	if not bool(VehicleCatalogue.of(kind).get("hung_stores", false)):
		return
	_stores = HungStores.new()
	_stores.name = "HungStores"
	_stores.fit(Sim.missile_schema(kind), VehicleCatalogue.of(kind).get("store_pylons", {}) as Dictionary)
	add_child(_stores)


## WHICH RAILS STILL CARRY ONE, off the bus, which every machine holds; every rail on a craft nobody is simulating yet.
func _draw_the_stores() -> void:
	var live: bool = entity > 0 and Sim.client != null
	_stores.show_loaded(int(Sim.client.craft_systems(entity).get("stores", 0)) if live else 0xFF)


## The missiles drawn on this craft's rails, or null.
func hung_stores() -> HungStores:
	return _stores


## LIGHTS, where a real aircraft carries them, so another aircraft can be FOUND: on the airframe as it is finally drawn,
## so AFTER the visual scene, whose airframe may say where its own lights are (`SkyhawkAirframe.lights`). Hung on the
## gathered body so they turn round with it, and kept out of `_body` so ghosting the airframe you are inside does not
## repaint them. Until 2026-09-17 they were built before either, from the collision box; see `VehicleLights.for_view`.
func _hang_the_lights(geometry: Dictionary) -> void:
	var body := get_node_or_null("Body") as Node3D
	# THE V-22 SAYS WHERE ITS LIGHTS ARE: measured off its skin, the nav lights would stand on its blade tips.
	var lamps: Array[Dictionary] = VehicleLights.for_view(kind, geometry, self, body,
		_visual_scene if _visual_scene != null else _osprey)
	if lamps.is_empty():
		return
	var lights: VehicleLights = VehicleLights.build(lamps, entity)
	lights.name = "Lights"
	(body if body != null else self).add_child(lights)
	_lights = lights


## THE LIGHTS THIS CRAFT CARRIES, in the body's frame, as `VehicleLights.build` was handed them; empty for a craft with none.
func lamps() -> Array[Dictionary]:
	return _lights.lamps if _lights != null else ([] as Array[Dictionary])


## WHERE THIS CRAFT'S WINGTIPS ARE, left then right, in its own frame: where its red and green lights stand, and where
## `ContrailYard` lays a contrail from. Empty for a craft without them. One place for both, so a rebuilt wing moves its
## lights and its contrails together.
func wingtips() -> Array[Vector3]:
	var tips: Array[Vector3] = []
	# A HELICOPTER'S RED AND GREEN ARE ON ITS STABILISER, NOT A WING, and it leaves no contrail: the probe that measured
	# how far the tips moved on 2026-09-17 found all three helicopters about to lay one from their nav lights.
	if _lights == null or not VehicleLights.has_a_wing(kind):
		return tips
	var frame: Transform3D = VehicleLights.frame_in(_lights, self)
	for colour in [VehicleLights.RED, VehicleLights.GREEN]:
		for lamp in _lights.lamps:
			if lamp["colour"] == colour and int(lamp["pattern"]) == VehicleLights.Pattern.STEADY:
				tips.append(frame * (lamp["position"] as Vector3))
				break
	return tips if tips.size() == 2 else ([] as Array[Vector3])


## OPTIONAL VERSIONED VISUAL SCENE. Physics, seats and networking were already built from
## native geometry above; this may replace only the gathered presentation body. A missing
## or malformed resource therefore leaves the procedural craft intact and flyable.
func _install_visual_scene(geometry: Dictionary) -> void:
	var made: Dictionary = ModelAssetDefinition.instantiate_for(kind, geometry)
	if made.has("error"):
		return
	_visual_scene = made.get("node") as Node3D
	if _visual_scene == null:
		return
	_visual_scene.name = "VisualScene"
	add_child(_visual_scene)
	# THE GEAR AND HOOK START WHERE THE BUS HAS THEM, so a fighter issued in the air is not drawn with its wheels down on
	# its first frame. With no bus -- the builder's preview -- they stand down.
	_fighter = _visual_scene as FighterAirframe
	if _fighter != null:
		_draw_the_fighters_actuators(Sim.client.craft_controls(entity) if entity > 0 and Sim.client != null else {})
	# THE SKYHAWK'S SURFACES START WHERE THE BUS HAS THEM, so a Cessna issued with its flaps out is not drawn with them up on
	# its first frame. With no bus -- the builder's preview -- they stand neutral and the propeller stands still.
	_skyhawk = _visual_scene as SkyhawkAirframe
	if _skyhawk != null:
		_draw_the_skyhawk()
	# THE SCENE REPLACES THE SKIN, NOT THE CRAFT: only the procedural airframe is hidden. This hid the whole `Body` node,
	# which `_finish_setup` had already gathered the lights and the guns into, so the fighter's nav lights stood on its
	# drawn rails and nothing drew them (lane/skyhawk, 2026-09-17).
	for skin in _procedural_airframe():
		skin.visible = false


## THE FIGHTER'S GEAR AND HOOK, STRAIGHT FROM THE COMMAND, 1 or 0, as the nacelles are drawn: no timer and no eased copy
## on this machine. How long a part takes will be the simulation's, evaluated at the frame the hull is drawn at, so every
## machine sees the same phase (`cockpit/actuators_research.md` sections 3.5 and 3.8); a drawn `move_toward` here would be
## a second clock to delete then. The bus has no "hook" bit until the hook channel is fitted, so the hook stays stowed.
func _draw_the_fighters_actuators(bus: Dictionary) -> void:
	_fighter.set_gear(1.0 if bool(bus.get("gear", true)) else 0.0)
	_fighter.set_hook(1.0 if bool(bus.get("hook", false)) else 0.0)


## THE PROCEDURAL AIRFRAME, the part of the drawing a package's visual scene replaces: the body meshes (`_body`, hull
## included), the nose marker, and a builder's airframe where one was built. NOT the lights, the guns or the turrets,
## which are fitted to the craft and stay whatever draws its skin.
func _procedural_airframe() -> Array[Node3D]:
	var skin: Array[Node3D] = []
	for part in _body:
		if part is Node3D and is_instance_valid(part):
			skin.append(part as Node3D)
	for part in [_nose, _hawkeye, _rotorcraft, _brig, _tomcat, _phantom, _savoia, _falcon, _sailplane, _prowler, _lightning, _osprey, _jetliner,
			_warthog, _warbird]:
		if part != null and is_instance_valid(part):
			skin.append(part as Node3D)
	return skin


## THE CESSNA'S MOVING PARTS, from what this machine holds, handed straight to the airframe.
func _draw_the_skyhawk() -> void:
	var live: bool = entity > 0 and Sim.client != null
	var state: Dictionary = Sim.current.get(entity, {}) if live else {}
	draw_the_skyhawk_from(Sim.client.craft_controls(entity) if live else {}, Sim.client.crew_controls(entity) if live else {},
		Sim.client.vehicle_seats(entity) if live else PackedInt64Array(), state.get("velocity", Vector3.ZERO) as Vector3,
		float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second))


## THE CESSNA'S MOVING PARTS, STRAIGHT FROM THE BUS AND THE LINKAGE: no timer and no eased copy on this machine
## (`cockpit/actuators_research.md` sections 3.5 and 3.8).
## - The flaps and the trim tab from the bus, which every machine holds.
## - The ailerons, elevators and rudder from the linkage, `crew_controls`, which only a machine aboard holds: everybody
##   else is handed nothing and draws them neutral. The stick is not on the replicated bus.
## - The propeller turning on the physics clock every machine shares, and STANDING STILL WHEN PARKED: nobody aboard, the
##   throttle closed and not moving. A parked Cessna with its propeller going round would be a lie at a glance.
## Handed its data so a suite can hand it each machine's own, exactly as `draw` does.
func draw_the_skyhawk_from(bus: Dictionary, linkage: Dictionary, occupants: PackedInt64Array, velocity: Vector3,
		seconds: float) -> void:
	if _skyhawk == null:
		return
	var throttle: float = float(bus.get("throttle", 0.0))
	var stick: Vector2 = linkage.get("linked_stick", Vector2.ZERO)
	_skyhawk.set_flaps(float(bus.get("flaps", 0.0)))
	_skyhawk.set_trim(float(bus.get("trim", 0.0)))
	_skyhawk.set_ailerons(stick.x)
	_skyhawk.set_elevator(stick.y)
	_skyhawk.set_rudder(float(linkage.get("linked_rudder", 0.0)))
	var aboard: bool = false
	for occupant in occupants:
		aboard = aboard or occupant >= 0
	_skyhawk.set_propeller(aboard or throttle > 0.01 or velocity.length() > 1.0, throttle, seconds)


## WHICH CLASS DRAWS THIS HELICOPTER, by the catalogue's shape, or null for anything that is not one.
func _rotorcraft_class() -> GDScript:
	match VehicleCatalogue.body(kind):
		VehicleCatalogue.Body.UH60:
			return Uh60Airframe
		VehicleCatalogue.Body.ROTOR:
			return LightHelicopterAirframe
		VehicleCatalogue.Body.TANDEM:
			return ChinookAirframe
		VehicleCatalogue.Body.LITTLEBIRD:
			return LittleBirdAirframe
		VehicleCatalogue.Body.APACHE:
			return ApacheAirframe
	return null


## THE ROTORS AND THE RAMP, from what this machine holds, handed straight to the airframe as the Cessna's propeller is.
## With no bus -- the builder's preview -- the rotors stand parked and the Chinook's ramp stands down.
func _draw_the_rotors() -> void:
	var live: bool = entity > 0 and Sim.client != null
	var state: Dictionary = Sim.current.get(entity, {}) if live else {}
	draw_the_rotors_from(Sim.client.craft_controls(entity) if live else {},
		Sim.client.vehicle_seats(entity) if live else PackedInt64Array(), state.get("velocity", Vector3.ZERO) as Vector3,
		float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second))


## THE SAME, FROM WHAT IT IS HANDED, so a test can hand it each machine's own bus as `draw_the_skyhawk_from` is. The
## rotors turn when anybody is aboard, the collective is up or the craft is moving, and are parked otherwise; the
## Chinook's ramp follows the bus's "ramp" bit (the gear channel), down unless the bus says up.
func draw_the_rotors_from(bus: Dictionary, occupants: PackedInt64Array, velocity: Vector3, seconds: float) -> void:
	if _rotorcraft == null:
		return
	var aboard: bool = false
	for occupant in occupants:
		aboard = aboard or occupant >= 0
	var collective: float = float(bus.get("throttle", 0.0))
	_rotorcraft.call("set_rotors", aboard or collective > 0.01 or velocity.length() > 1.0, collective, seconds)
	if _rotorcraft.has_method("set_ramp"):
		_rotorcraft.call("set_ramp", 1.0 if bool(bus.get("gear", true)) else 0.0)


## A NOSE AND A TAIL on a craft that is otherwise a box, so it has a front.
func _mark_the_ends(half: Vector3, material: StandardMaterial3D) -> void:
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	# A FIFTH of the fuselage across, and an eighth of its length long. The job is to say
	# which end is the front, and a marker does that at a fraction of the size of the thing
	# it is marking -- at half the width, which is where this started, the cone was as big
	# as the aeroplane and read as a shape in its own right rather than as a nose.
	var snout: float = maxf(half.z * 0.12, 0.35)
	cone.top_radius = 0.0
	cone.bottom_radius = maxf(half.x * 0.22, 0.12)
	cone.height = snout
	nose.name = "Nose"
	_nose = nose
	nose.mesh = cone
	var nose_material := StandardMaterial3D.new()
	nose_material.albedo_color = Color(1.0, 0.72, 0.2)
	nose_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nose.material_override = nose_material
	nose.position = Vector3(0.0, 0.0, -(half.z + snout * 0.5))
	nose.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(nose)

	# AND A TAIL, in the hull's own colour, so the two ends of the aircraft are different
	# shapes and not merely different distances from a marker. One bright cone on a
	# symmetrical box tells you where the front is only once you have found the cone;
	# tapering the back as well means the silhouette itself says which way it is going.
	var tail := MeshInstance3D.new()
	var taper := CylinderMesh.new()
	taper.top_radius = 0.0
	# The tail keeps more of its width than the nose, because it is the blunter end and the
	# DIFFERENCE between the two is what makes the silhouette readable at all.
	taper.bottom_radius = maxf(half.x * 0.34, 0.14)
	taper.height = maxf(half.z * 0.16, 0.3)
	tail.name = "Tail"
	tail.mesh = taper
	tail.material_override = material
	_body.append(tail)
	tail.position = Vector3(0.0, 0.0, half.z + taper.height * 0.5)
	tail.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	add_child(tail)


## The body gathered under one node, and a seat anchor per seat. The lights come after the visual scene: see
## `_hang_the_lights`.
func _finish_setup(geometry: Dictionary) -> void:
	# THE DRAWN BODY, GATHERED UNDER ONE NODE so it can be turned round as a piece.
	#
	# Everything built above goes in: hull, wing, tail, cones, rotors, guns. The seats do
	# NOT -- they are placed by the simulation and are where a pilot actually sits, so they
	# have to stay in the vehicle's own frame whatever the model is doing.
	_gather_body()

	for entry in (geometry.get("seat_poses", []) as Array):
		var anchor := Node3D.new()
		anchor.name = "Seat%d" % seats.size()
		anchor.transform = Transform3D(
			Basis(Vector3.UP, float(entry.get("yaw", 0.0))),
			entry.get("position", Vector3.ZERO))
		add_child(anchor)
		seats.append(anchor)
	# THE CHAIR UNDER EACH SEAT, on the anchor and never in `_body`: it is where the occupant sits, so it stays in the
	# seat's frame, and a crew aboard does not ghost it away -- a pilot looking down sees the handle between the knees.
	var chairs: PackedStringArray = VehicleCatalogue.chairs(kind, seats.size())
	for index in range(seats.size()):
		if not chairs[index].is_empty():
			var chair: MeshInstance3D = PilotSeat.of(chairs[index], VehicleCatalogue.chair_overrides(kind))
			chair.name = "Chair"
			seats[index].add_child(chair)


## THE GREENHOUSE THE CREW SIT IN, worked out from where their EYES are.
##
## The measurement that made this necessary: a light aeroplane's hull is 1.4 m tall and its
## seats sit 0.15 m below the middle of it, so the floor is at -0.15 and the roof at +0.70 --
## and the pilot's eye, being EYE_HEIGHT above the floor they are sitting on, is at +1.20.
## HALF A METRE ABOVE THE ROOF. The cockpit frame is taller still. Every crew position in
## this game has been sticking out of the top of its own fuselage, invisibly, because the
## fuselage was hidden from the one person in a position to notice.
##
## Which is also why glazing the hull would have achieved nothing: there is no window you
## can cut in a box that your head is already above. A real light aircraft is the same shape
## for the same reason -- the cabin is taller than the tail boom, and the greenhouse is what
## you see out of.
##
## So it is DERIVED, never typed in: as wide as the fuselage, long enough to hold every seat
## with room to get in and out, and tall enough to clear a standing pilot's head. Move
## EYE_HEIGHT, or move a seat in the C++ shape table, and the cabin follows. That is the
## same rule the drawn hull already obeys about extents.
func _greenhouse(geometry: Dictionary) -> AABB:
	var poses: Array = geometry.get("seat_poses", []) as Array
	if poses.is_empty():
		return AABB()
	var extents: Vector3 = geometry.get("extents", Vector3.ONE) as Vector3
	var fore: float = 1e9
	var aft: float = -1e9
	var floor_at: float = 1e9
	var beam: float = 0.0
	for entry in poses:
		# The 747's operator consoles are on the upper deck behind the flight deck, not in it (they were the E-6B
		# Mercury's mission cabin). Only the two flying positions define its windscreen and tapered nose.
		if kind == Sim.Kind.JUMBO and not bool(entry.get("flies", false)):
			continue
		var at: Vector3 = entry.get("position", Vector3.ZERO)
		fore = minf(fore, at.z)
		aft = maxf(aft, at.z)
		floor_at = minf(floor_at, at.y)
		beam = maxf(beam, absf(at.x))
	# ROOM TO SIT IN behind the last chair, and FORWARD TO THE NOSE in front of the first.
	#
	# A cabin that stops short of the nose is a cabin with the aircraft's own front in the
	# way, and every crew position in this game is in the forward half -- which is what an
	# aeroplane is. Running the glazing all the way to the nose is also simply what a
	# windscreen is: the front of the cabin IS the front of the aircraft, and the cone drawn
	# beyond it is the radome.
	const ROOM: float = 0.55
	fore = -extents.z
	aft = minf(aft + ROOM, extents.z)
	if aft - fore <= 0.0:
		return AABB()
	# HOW FAR DOWN THE GLAZING GOES is set by the EYE, not by the fuselage roof, and this is
	# the number a measurement forced. The Cessna's roof line is only 20 cm below its
	# pilot's eye, so a cabin that started there gave them a sill at chin height and nothing
	# to look through. Forty-five centimetres of drop below the eye is a window you can see
	# the ground out of, which is the entire reason anybody flies a high-wing aeroplane.
	#
	# It cuts INTO the fuselage where it has to; `HullSkin` takes the sides away to meet it.
	var base: float = minf(extents.y - HullSkin.SKIN,
		floor_at + CockpitStation.EYE_HEIGHT - 0.45)
	var top: float = floor_at + CockpitStation.PILOT_HEIGHT + 0.30
	if top <= base:
		return AABB()
	# AS WIDE AS THE CREW, NOT AS WIDE AS THE HULL, and this is what makes an airliner an
	# airliner rather than a shed with a windscreen.
	#
	# Its crew sit within a metre of the centreline and its fuselage is 5.2 m across. A
	# flight deck the width of the hull puts the side sill two metres from the pilot's
	# shoulder: eight degrees of downward view, and no ground at all from any window. The
	# nose of a real airliner TAPERS for exactly this reason, and `HullSkin` steps the
	# fuselage out behind the cabin to meet the rest of the hull.
	#
	# An aeroplane whose crew already fill its width -- the light one, the Cessna -- gets
	# the full beam and no taper, because the minimum is what the hull is.
	const ELBOW: float = 0.42
	var half: float = minf(extents.x, beam + ELBOW)
	return AABB(Vector3(-half, base, fore),
		Vector3(half * 2.0, top - base, aft - fore))


## THE ROOM THIS CRAFT PROMISES ROUND ITS CREW, in the craft's own frame. ONE CALL FOR EVERY CRAFT IN THE GAME.
##
## `{"drawn": bool, "room": AABB, "because": StringName, "why_not": String, "source": String}`. When `drawn` is true,
## **every point inside `room` is inside the skin this craft draws** -- see `SkyhawkAirframe.cabin_room`, which is the
## worked example. A point outside it may or may not be outside the skin: the room is the largest box that can be
## PROMISED, not a description of the cabin's shape.
##
## `because` IS THE ONE WORD A CHECK BRANCHES ON, and `why_not` the sentence a person reads. They are not redundant:
## `lane/shell` asked for the key because a suite that has to assert something about the negative set would otherwise
## be substring-matching against English prose, which breaks the first time somebody improves the wording. Two keys
## exist -- `&"plates"` and `&"box"` -- and a third should be added rather than a sentence bent to fit one of these.
##
## A CRAFT THAT ENCLOSES NOBODY SAYS SO, and that is the half of this interface that is easy to leave out. Measured by
## `lane/shell` on 2026-09-17: on nine of the game's craft the pilot's head is inside nothing the craft draws at all --
## there is no enclosing solid to be outside of. **An absent answer is indistinguishable from an oversight**, so there
## are no absent answers: `drawn` is false and `why_not` says why, in a sentence, and the two reasons are not the same
## fault and must not be lumped together.
##
## ASKED OF THE AIRFRAME BY NAME AND NOT BY TYPE, so a new airframe opts in by growing the method and nothing central
## has to be edited. A roster of which craft have cabins is exactly the list that would go out of date.
##
## IT ANSWERS AFTER `_show_in_editor()` WITH NO WORLD RUNNING, which is how every craft in `lane/shell`'s suite is
## built, and `tests/skyhawk.gd` holds it to that by asking all twenty-five kinds that way and requiring every one of
## them to answer. Nothing in here reads `Sim.client`, an entity or a tick.
## WHERE THIS CRAFT BLOWS, for `ExhaustYard`: an array of {"at", "axis", "radius", "kind", "heat"} in the craft's own
## frame, `at` metres from the origin, `axis` a unit vector the way the gas goes, `kind` an `ExhaustTuning.Kind`, and
## `heat` 1 for a hot pipe and 0 for cold fan air.
##
## ASKED OF THE AIRFRAME BY NAME AND NOT BY TYPE, exactly as `cabin_room` below is and for the same reason: a new
## airframe opts in by growing one method, and there is no central roster of which craft have an exhaust to go stale.
## An empty array is the honest answer for a glider, and unlike a cabin it needs no sentence -- "nothing blows" is not
## ambiguous the way "nothing encloses the pilot" was.
##
## THE AXIS IS THE DRAWN PART'S, not a constant: an airframe whose nozzle swivels reads it off the hinge, so the plume
## and the drawn nozzle are one number and cannot point two ways.
func exhaust_ports() -> Array:
	for airframe in [_visual_scene, _hawkeye, _rotorcraft, _tomcat, _phantom, _savoia, _falcon, _sailplane, _prowler, _lightning,
			_osprey, _jetliner, _warthog, _warbird]:
		if airframe != null and (airframe as Object).has_method("exhaust_ports"):
			return (airframe as Object).call("exhaust_ports") as Array
	# AND A SHIP, WHICH HAS NO AIRFRAME OBJECT TO ASK. `ShipHull.dress` builds a scriptless node on purpose -- forty-four
	# launches share one mesh and nothing there runs per frame -- so a ship's ports travel back with its mesh through the
	# builder dispatch instead, and are read off the same cache (`ShipHull.models`, "ports"). A funnel is an exhaust.
	var geometry: Dictionary = Sim.geometry_of(kind)
	if not (geometry.get("parts", []) as Array).is_empty():
		return ShipHull.models(kind, geometry).get("ports", []) as Array
	return []


func cabin_room() -> Dictionary:
	for airframe in [_visual_scene, _hawkeye, _rotorcraft, _tomcat, _phantom, _savoia, _falcon, _sailplane, _prowler, _lightning, _osprey, _jetliner,
			_warthog, _warbird]:
		if airframe != null and (airframe as Object).has_method("cabin_room"):
			return (airframe as Object).call("cabin_room") as Dictionary
	# AND A CRAFT THIS FILE DRAWS ITSELF ANSWERS FOR ITSELF. See `_own_cabin_room`.
	if not _own_cabin_room.is_empty():
		return _own_cabin_room
	# OPEN PLATES ARE NOT A SKIN. `HullSkin` dresses a glazed craft as panels -- a hull, a greenhouse and their sills --
	# and those panels do not close, so nothing encloses anything for a reason that has nothing to do with seats or
	# stations. This is NOT one craft's special case: measured 2026-09-17, the plane and the airliner give the same
	# answer here because `HullSkin` dressed them both. `_panels` is non-empty exactly for the craft it dressed, so the
	# two sentences below are read off the craft's own state rather than off a list of names.
	if not _panels.is_empty():
		return {"drawn": false, "room": AABB(), "source": "", "because": &"plates",
			"why_not": "drawn by HullSkin as open plates rather than a closed skin, so there is nothing to be inside"}
	return {"drawn": false, "room": AABB(), "source": "", "because": &"box",
		"why_not": "drawn as a simulation box with a greenhouse cut into it, and that greenhouse is derived from the "
			+ "same seat poses a station is, so it can neither disagree with a station nor serve as a datum for one"}


## WHERE THE GLAZING IS, as the band of the cabin that is neither sill nor header. Handed to
## the tests so a check can ask about the window rather than about a magic number.
func glazed_band() -> Vector2:
	var plan: Dictionary = VehicleCatalogue.glazing(kind)
	if plan.is_empty() or _cabin.size.z <= 0.0:
		return Vector2.ZERO
	return Vector2(_cabin.position.y + float(plan.get("sill", 0.16)),
		_cabin.position.y + _cabin.size.y - float(plan.get("header", 0.14)))


## The panels this hull is made of, in the vehicle's own frame. Empty for a craft still
## drawn as a single box.
func hull_panels() -> Array:
	return _panels


## Does this seat fly the craft? Straight off the seat poses the simulation publishes, so a
## seat's job is decided in one place and read everywhere.
func _seat_flies(index: int) -> bool:
	var poses: Array = Sim.geometry_of(kind).get("seat_poses", []) as Array
	if index < 0 or index >= poses.size():
		return true
	return bool((poses[index] as Dictionary).get("flies", true))


## WHICH WAY ROUND THE DRAWN MODEL SITS, in radians about the vertical.
##
## Zero for everything, and PI for the airliner -- which is a decision about how it LOOKS
## and touches nothing else. The simulation is unchanged and was never wrong: measured on a
## live one, its nose lies exactly along its velocity (dot product 1.00), the nose cone is
## drawn ahead of the hull and the tail behind it, and the pilot's seat is in the forward
## third facing -Z with zero yaw.
##
## It is here as one number per kind so it is one line to change and one line to undo.
func _gather_body() -> void:
	var body := Node3D.new()
	body.name = "Body"
	var drawn: Array = []
	for child in get_children():
		if child is Node3D and not (child is CockpitStation):
			drawn.append(child)
	add_child(body)
	for child in drawn:
		remove_child(child)
		body.add_child(child)
	body.rotation.y = VehicleCatalogue.facing(kind)


## Ground craft use the same native extents as their collision shape.  They are deliberately
## made from a few stable PrimitiveMeshes instead of imported art: a model can improve without
## creating a second source of truth for seat placement or physics.
func _ground_part(label: String, mesh: Mesh, at: Vector3, material: Material,
		turned: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.position = at
	part.rotation = turned
	part.material_override = material
	_body.append(part)
	add_child(part)
	return part


func _ground_paint(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.58
	return material


func _build_car_body(extents: Vector3, tint: Color) -> void:
	# Four distinct wheels, a low bonnet, passenger cell and separate glass make this read
	# as a road car from the gallery instead of the old red collision box.
	var paint := _ground_paint(tint)
	var tyre := _ground_paint(Color(0.035, 0.04, 0.045))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.16, 0.34, 0.43, 0.62)
	glass.metallic = 0.15
	glass.roughness = 0.18
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var lower := BoxMesh.new()
	lower.size = Vector3(extents.x * 2.05, extents.y * 0.82, extents.z * 1.92)
	_ground_part("CarChassis", lower, Vector3(0.0, -extents.y * 0.26, 0.0), paint)
	var cabin := BoxMesh.new()
	cabin.size = Vector3(extents.x * 1.55, extents.y * 0.92, extents.z * 0.90)
	_ground_part("CarCabin", cabin, Vector3(0.0, extents.y * 0.48, extents.z * 0.18), paint)
	var windscreen := BoxMesh.new()
	windscreen.size = Vector3(extents.x * 1.36, extents.y * 0.47, 0.055)
	_ground_part("CarWindscreen", windscreen,
		Vector3(0.0, extents.y * 0.67, -extents.z * 0.30), glass, Vector3(0.42, 0.0, 0.0))
	var lamps := _ground_paint(Color(1.0, 0.86, 0.42))
	for side in [-1.0, 1.0]:
		var lamp := BoxMesh.new()
		lamp.size = Vector3(0.20, 0.15, 0.06)
		_ground_part("CarHeadlamp%s" % ["Port" if side < 0.0 else "Starboard"], lamp,
			Vector3(side * extents.x * 0.68, -extents.y * 0.05, -extents.z * 0.99), lamps)
	for axle in [-0.56, 0.56]:
		for side in [-1.0, 1.0]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = extents.y * 0.37
			wheel.bottom_radius = extents.y * 0.37
			wheel.height = extents.x * 0.22
			_ground_part("CarWheel%s%s" % ["Front" if axle < 0.0 else "Rear", "Port" if side < 0.0 else "Starboard"], wheel,
				Vector3(side * extents.x * 1.04, -extents.y * 0.65, axle * extents.z), tyre,
				Vector3(0.0, 0.0, PI * 0.5))


## A MAIN BATTLE TANK'S RUNNING GEAR: A TRACK ROUND A REAR SPROCKET AND A FRONT IDLER.
##
## The hull box this is drawn round is an Abrams: `tank_shape` in the C++ is 3.70 m wide, 2.40 m
## tall and 7.90 m long, against the M1A2's published 3.66 m, 2.44 m to the turret roof and 7.93 m.
## AND THE PHYSICS RESTS THAT BOX'S BOTTOM ON THE GROUND -- a tank dropped on a flat field settles
## at y 1.1999 with hy 1.20 (measured 2026-09-17) -- so `-extents.y` is the ground, and every
## number below is measured up from it.
##
## WHAT WAS WRONG, MEASURED RATHER THAN LOOKED AT.
##
## The tank FLOATED. Its lowest drawn point was a road-wheel rim at -1.020 in a craft whose ground
## is -1.200: eighteen centimetres of daylight under a sixty-two-tonne vehicle, on every one of
## them in the world.
##
## It was drawn WIDER THAN IT COLLIDES. The wheels stood at x +-2.146 on a hull 1.850 half-wide:
## the drawn vehicle was 4.29 m across against a 3.70 m box, and 0.63 m of that was wheel hanging
## in the air outside the thing that stops it.
##
## AND THE WHEELS WERE BOLTED TO THE OUTSIDE OF THE TRACK, which is backwards. The track box
## reached x 2.017 and the wheels 2.146, so 0.13 m of every wheel stood proud of the thing that is
## supposed to wrap round it. There was no drive sprocket and no idler at all, so nothing said
## which end drives, and the "track" was a closed box with no top run and no bottom one.
##
## WHAT IT IS NOW. A ground run flat on the floor under the road wheels, a climb at each end, a
## return run over the wheel tops, a DRIVE SPROCKET AT THE BACK and an IDLER AT THE FRONT -- -Z is
## forward, and an M1 drives from the rear. Seen from the side that is a TRAPEZOID rather than an
## oval, which is what an Abrams' track is: the two ends are carried 0.22 m over the road-wheel
## line and the climb to them is 42 degrees. All of it is inside the hull's own width, and the
## wheels are inboard of the track rather than bolted to the outside of it. The hull tub's floor
## was already 0.48 m over that ground, which is the M1's published clearance to the bit, and it
## has not been touched.
##
## THE BARREL IS NOT TOO LONG, which is what the measurement says and a photograph did not. The
## muzzle stands at z -5.600 and the bow at -3.950, so the gun overhangs by 1.65 m and the whole
## vehicle gun-forward is 9.43 m, against the M1A2's published 9.83 m over a 7.93 m hull -- 1.90 m
## of overhang. The drawn gun is if anything a little SHORT. What makes it read as a telegraph pole
## is that it leaves a ball at the middle of the hull instead of a mantlet in a turret front, and
## that is a different fault from the one it looks like. `tests/tank_shape.gd` states both numbers.
func _build_tank_body(extents: Vector3, tint: Color) -> void:
	# The actual gun still comes from `_build_turret` at the native mount position.
	var paint := _ground_paint(tint)
	var rubber := _ground_paint(Color(0.055, 0.06, 0.052))
	var steel := _ground_paint(Color(0.115, 0.125, 0.125))
	var hull := BoxMesh.new()
	hull.size = Vector3(extents.x * 1.82, extents.y * 0.76, extents.z * 1.80)
	_ground_part("TankHull", hull, Vector3(0.0, -extents.y * 0.22, 0.0), paint)
	var glacis := BoxMesh.new()
	glacis.size = Vector3(extents.x * 1.72, extents.y * 0.42, extents.z * 0.64)
	_ground_part("TankGlacis", glacis, Vector3(0.0, extents.y * 0.23, -extents.z * 0.56), paint,
		Vector3(-0.34, 0.0, 0.0))
	var turret := CylinderMesh.new()
	turret.top_radius = extents.x * 0.62
	turret.bottom_radius = extents.x * 0.74
	turret.height = extents.y * 0.65
	_ground_part("TankTurret", turret, Vector3(0.0, extents.y * 0.51, -extents.z * 0.05), paint)

	# ONE CHAIN, FOUR SURFACES, AND THE CONTACTS CANNOT COME APART.
	#
	# The road wheels ride ON the track, so the ground run's inner face and the wheel's contact
	# line are THE SAME SURFACE, and the return run's underside and the wheel tops are another.
	# Those four numbers were computed rather than typed before 2026-09-17 -- and were only
	# ACCIDENTALLY safe, because they reached the same values down two separate arithmetic paths
	# that happened to meet. TWO DERIVATIONS AGREEING IS NOT ONE AUTHORITY; it is two rosters that
	# currently match, and moving the track's thickness would have opened both joints silently.
	#
	# So each surface below is named and derived from the one under it. The ground is where the
	# physics rests the collision box; the tread is the inside of the ground run; a wheel of the
	# stated diameter stands ON the tread; and the return run rides the tops of those wheels.
	# `tests/tank_shape.gd` checks the two contacts are CLOSED rather than checking four values,
	# because both sides of a joint drifting apart together leaves neither of them out of range.
	var ground: float = -extents.y
	var tread: float = ground + TANK_TRACK_THICK
	var axle: float = tread + TANK_ROAD_WHEEL * 0.5
	var run_top: float = axle + TANK_ROAD_WHEEL * 0.5
	var end_axle: float = axle + TANK_AXLE_RISE
	var station: float = extents.z * TANK_END_STATION
	var flat: float = extents.z * TANK_WHEEL_STATION
	# THE CLIMB AT EACH END, worked out from where the two ends of it are rather than typed beside
	# them: a slope stated as an angle and a length stops meeting the things it joins the moment
	# either moves.
	var climb: float = end_axle - (ground + tread) * 0.5
	var reach: float = station - flat
	var rise_long: float = sqrt(climb * climb + reach * reach)
	var rise_turn: float = atan2(climb, reach)
	# THE TRACK'S OUTER FACE IS THE HULL'S SIDE, and everything else is inboard of it. Nothing a
	# vehicle draws may stand outside the box it collides with: a wheel out there hangs through
	# whatever the tank drives past.
	var across: float = extents.x - TANK_TRACK_WIDE * 0.5
	for side in [-1.0, 1.0]:
		var hand := "Port" if side < 0.0 else "Starboard"
		var beam: float = side * across
		var lower := BoxMesh.new()
		lower.size = Vector3(TANK_TRACK_WIDE, tread - ground, flat * 2.0)
		_ground_part("Tank%sTrackGroundRun" % hand, lower,
			Vector3(beam, (ground + tread) * 0.5, 0.0), rubber)
		# THE RETURN RUN rides over the tops of the road wheels. How many return rollers an M1
		# carries under the run is not something this session could check, so none are drawn and
		# the run is carried on the wheels themselves rather than on invented rollers.
		var upper := BoxMesh.new()
		upper.size = Vector3(TANK_TRACK_WIDE, tread - ground, station * 2.0)
		_ground_part("Tank%sTrackTopRun" % hand, upper,
			Vector3(beam, run_top + (tread - ground) * 0.5, 0.0), rubber)
		# AND THE CLIMB FROM THE GROUND RUN UP TO EACH END WHEEL, which is what makes the track a
		# loop rather than two shelves with a gap at the corners.
		for end in [-1.0, 1.0]:
			var slope := BoxMesh.new()
			slope.size = Vector3(TANK_TRACK_WIDE, tread - ground, rise_long)
			_ground_part("Tank%sTrack%sRise" % [hand, "Front" if end < 0.0 else "Rear"], slope,
				Vector3(beam, ((ground + tread) * 0.5 + end_axle) * 0.5,
					end * (flat + station) * 0.5), rubber,
				Vector3(-end * rise_turn, 0.0, 0.0))
		# -Z IS FORWARD, and an Abrams drives from the BACK: the sprocket is the +Z one.
		_ground_part("Tank%sDriveSprocket" % hand,
			_faceted_wheel(TANK_SPROCKET * 0.5, TANK_END_WHEEL_WIDE),
			Vector3(beam, end_axle, station), steel, Vector3(PI / 12.0, 0.0, PI * 0.5))
		_ground_part("Tank%sIdler" % hand,
			_faceted_wheel(TANK_IDLER * 0.5, TANK_END_WHEEL_WIDE),
			Vector3(beam, end_axle, -station), steel, Vector3(PI / 12.0, 0.0, PI * 0.5))
		for wheel_index in range(ROAD_WHEELS_A_SIDE):
			var along := lerpf(-flat, flat, float(wheel_index) / float(ROAD_WHEELS_A_SIDE - 1))
			_ground_part("Tank%sRoadWheel%d" % [hand, wheel_index + 1],
				_faceted_wheel(TANK_ROAD_WHEEL * 0.5, TANK_ROAD_WHEEL_WIDE),
				Vector3(beam, axle, along), paint, Vector3(PI / 12.0, 0.0, PI * 0.5))


## A WHEEL THAT IS A POLYGON AND IS STILL THE SIZE IT SAYS IT IS.
##
## A FACETED WHEEL MUST CIRCUMSCRIBE THE CIRCLE IT STANDS FOR. A twelve-sided wheel drawn THROUGH
## a circle measures cos(15 degrees) = 0.966 of it across the flats, so a 0.635 m road wheel built
## that way rolls on a 0.613 m one and the vehicle stands 11 mm low. The radius passed here is the
## TRUE one, at the flats, and the circumradius is worked out from it.
##
## AND IT RESTS ON A FLAT, NOT ON A POINT, because a wheel resting on a point is a cog. Twelve
## segments starting at zero put a vertex at the bottom of a wheel laid on its side by `PI * 0.5`
## about Z, so each is turned half a step -- `PI / 12` about its own axle. Godot composes
## `rotation` as Y then X then Z, so `Vector3(PI / 12, 0, PI * 0.5)` lays the axle across the craft
## FIRST and spins the rim about it after, which is the one order that keeps the axle horizontal.
func _faceted_wheel(radius: float, wide: float) -> CylinderMesh:
	var wheel := CylinderMesh.new()
	wheel.radial_segments = TRACK_FACETS
	wheel.rings = 0
	wheel.top_radius = radius / cos(PI / float(TRACK_FACETS))
	wheel.bottom_radius = wheel.top_radius
	wheel.height = wide
	return wheel


## A CONTROL TOWER: A STALK, A GLASS CAB AND A ROOF.
##
## The cab is where the seats are, so it is drawn wider than the stalk and with its own
## colour: from the air the glass is how you find the thing.
##
## THE CAB IS SIZED FROM THE SEATS IN IT, and the stalk stops under its floor -- neither is
## a fraction of the hull typed beside the other. Written as a 2.4 m band at 0.78 extents,
## with the stalk 1.5 extents tall centred a quarter of one down, the stalk's top stood at
## +12.5 m and swallowed the whole cab, and a controller's eye -- the seat pose plus
## `CockpitStation.EYE_HEIGHT`, +8.95 -- came 0.05 m under the ceiling: the roof's underside
## cut a dark band straight across the view out (looked at 2026-09-17,
## `tests/airbase_shot.gd` `tower`). The floor is now a step below the lowest seat and the
## ceiling a head's clearance over the highest eye, so a seat is IN the glass.
##
## SEGMENT COUNTS: three boxes and nothing curved, which is the house look (`modelling_here.md`).
func _build_tower(geometry: Dictionary, material: StandardMaterial3D) -> void:
	var extents: Vector3 = geometry.get("extents", Vector3.ONE)
	# A seat pan sits about this far over the floor it is bolted to, and a head wants this much over it.
	var under_a_seat: float = 0.45
	var over_a_head: float = 0.90
	var lowest: float = INF
	var highest: float = -INF
	for pose in (geometry.get("seat_poses", []) as Array):
		lowest = minf(lowest, (pose["position"] as Vector3).y)
		highest = maxf(highest, (pose["position"] as Vector3).y)
	if lowest == INF:
		lowest = extents.y * 0.76
		highest = lowest
	var floor_at: float = lowest - under_a_seat
	var cab_deep: float = (highest + CockpitStation.EYE_HEIGHT + over_a_head) - floor_at
	var cab_high: float = floor_at + cab_deep * 0.5
	var stalk := MeshInstance3D.new()
	stalk.name = "TowerStalk"
	var column := BoxMesh.new()
	column.size = Vector3(extents.x * 1.1, floor_at + extents.y, extents.z * 1.1)
	stalk.mesh = column
	stalk.position = Vector3(0.0, (floor_at - extents.y) * 0.5, 0.0)
	stalk.material_override = material
	add_child(stalk)
	_body.append(stalk)
	var cab := MeshInstance3D.new()
	cab.name = "TowerCab"
	var glass := BoxMesh.new()
	glass.size = Vector3(extents.x * 2.2, cab_deep, extents.z * 2.2)
	cab.mesh = glass
	cab.position = Vector3(0.0, cab_high, 0.0)
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(0.35, 0.55, 0.62, 0.45)
	lit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cab.material_override = lit
	add_child(cab)
	_body.append(cab)
	# And a roof over it, because a cab with nothing on top reads as a crate.
	var roof := MeshInstance3D.new()
	roof.name = "TowerRoof"
	var lid := BoxMesh.new()
	lid.size = Vector3(extents.x * 2.6, 0.25, extents.z * 2.6)
	roof.mesh = lid
	roof.position = Vector3(0.0, cab_high + cab_deep * 0.5 + 0.13, 0.0)
	roof.material_override = material
	add_child(roof)
	_body.append(roof)


## A WING, OR A ROTOR, AND THE PHYSICS HAS NEVER HEARD OF IT.
##
## The collision hull stops at the fuselage on purpose -- a box the size of a wingspan
## collides with everything the aircraft flies past, and threading a gate becomes impossible
## for reasons the pilot cannot see. But a 1.5 m box is also what an aeroplane looks like at
## two kilometres, which is to say nothing, and a sky full of traffic nobody can pick out is
## a sky with nothing in it.
##
## So the span comes from the simulation's own geometry table like everything else, and this
## draws thirteen metres of aircraft around a hull that is still a metre and a half wide.
func _build_wing(vehicle_kind: int, span: float, extents: Vector3, tint: Color) -> void:
	# Ground vehicles have no aerodynamic span, so they must be handled before the wing
	# guard. These meshes are presentation only: their collision hull, seats and movement
	# models remain the native craft definition.
	if vehicle_kind == Sim.Kind.CAR:
		_build_car_body(extents, tint)
		return
	if vehicle_kind == Sim.Kind.TRAIN:
		# THE LOCOMOTIVE IS DRAWN WHOLE by `RoadDiesel`, as the A-10 and the F-16 are: an EMD SD40-2 measured off
		# the one true broadside of one on Commons. It replaced `_build_train_body`'s F7A, which was seven boxes
		# (lane/trains, 2026-09-19). The model carries its own published dimensions and the simulation's shape
		# carries the same ones, typed separately, so `train_models` can hold the two to each other.
		#
		# IT IS DROPPED BY HALF THE BOX. `RoadDiesel` draws with y = 0 at the RAILHEAD, because that is where a wheel
		# stands and what the track publishes; a craft's own origin is the middle of its collision box, which the
		# simulation lifts by `ride_height` so the box's bottom is on the rail. So the model hangs half a box down.
		var diesel := RoadDiesel.new()
		diesel.dress()
		diesel.position.y = -extents.y
		add_child(diesel)
		return
	if vehicle_kind == Sim.Kind.TANK:
		_build_tank_body(extents, tint)
		return
	if span <= 0.0:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.6

	# WHAT SHAPE IS IT, not what kind is it. A tiltrotor and an aeroplane both have a wing;
	# a Chinook and a light helicopter both have rotors and only one of them has two. The
	# catalogue answers the shape question, so adding a craft that is drawn like an existing
	# one adds no code here at all.
	var shape: VehicleCatalogue.Body = VehicleCatalogue.body(vehicle_kind)
	# A HELICOPTER'S ROTORS, BOOM AND TAIL ARE ITS OWN CLASS'S: see `_rotorcraft`.
	if _rotorcraft != null:
		return
	# THE HAWKEYE HAS ITS OWN WING: a plank drawn through it would be a second wing.
	if shape == VehicleCatalogue.Body.HAWKEYE:
		return
	# AND SO DOES THE V-22 (`OspreyAirframe`), with its nacelles and proprotors on it.
	if shape == VehicleCatalogue.Body.TILTROTOR:
		return
	# AND SO DOES THE TOMCAT, and a swinging one: the first picture of the craft as the game builds it had a 19.5 m plank
	# through the middle and a slab fin, with every check green, because every check built the airframe on its own.
	# AND THE PHANTOM, whose `PhantomAirframe` draws its own wing, stabilators and fin. Without this the generic
	# plank is drawn straight through it, which is what the Tomcat's first picture showed with every check green.
	if shape == VehicleCatalogue.Body.PHANTOM:
		return
	if shape == VehicleCatalogue.Body.TOMCAT or shape == VehicleCatalogue.Body.SAVOIA:
		return
	# AND THE F-16, the Tomcat's lesson taken before it was learnt twice.
	if shape == VehicleCatalogue.Body.FALCON or shape == VehicleCatalogue.Body.LIGHTNING:
		return
	# AND THE A-10C, whose `WarthogAirframe` draws its own straight wing, tailplane and twin fins.
	if shape == VehicleCatalogue.Body.WARTHOG:
		return
	# AND A WARBIRD, drawn whole by its own class.
	if shape == VehicleCatalogue.Body.WARBIRD:
		return
	# AND THE DUO DISCUS: `SailplaneAirframe` draws its own wing, tail and fin.
	if shape == VehicleCatalogue.Body.SAILPLANE:
		return
	# THE PROWLER IS ALSO A COMPLETE AIRFRAME. Its first integration omitted this guard and quietly drew the generic
	# Wing, Tailplane and Fin through the measured Prowler model; an airframe-only preview could never reveal them.
	if shape == VehicleCatalogue.Body.PROWLER:
		return
	# AND A JETLINER, the Prowler's lesson again: a builder's whole airframe has its own wing.
	if shape == VehicleCatalogue.Body.JETLINER:
		return
	if vehicle_kind == Sim.Kind.PLANE:
		_build_utility_twin_airframe(span, extents, material)
		return
	if vehicle_kind == Sim.Kind.TANKER:
		_build_water_bomber_airframe(span, extents, material)
		return
	if shape == VehicleCatalogue.Body.WARSHIP:
		# A superstructure amidships and a turret at each end, which between them are how a
		# warship reads from anywhere.
		var bridge := MeshInstance3D.new()
		bridge.name = "ShipBridge"
		var tower_block := BoxMesh.new()
		tower_block.size = Vector3(extents.x * 1.1, 16.0, extents.z * 0.22)
		bridge.mesh = tower_block
		bridge.position = Vector3(0.0, extents.y + 8.0, -extents.z * 0.16)
		bridge.material_override = material
		add_child(bridge)
		_body.append(bridge)
		for end in [-1.0, 1.0]:
			var turret := MeshInstance3D.new()
			# NAMED FOR ITS END, or the second one is renamed by Godot and nobody sees it happen.
			turret.name = "ShipGunhouse%s" % ["Forward" if end < 0.0 else "Aft"]
			var mount := BoxMesh.new()
			mount.size = Vector3(extents.x * 0.9, 5.0, extents.z * 0.12)
			turret.mesh = mount
			turret.position = Vector3(0.0, extents.y + 2.5, end * extents.z * 0.45)
			turret.material_override = material
			add_child(turret)
			_body.append(turret)
			var barrels := MeshInstance3D.new()
			barrels.name = "ShipGunBarrels%s" % ["Forward" if end < 0.0 else "Aft"]
			var gun := BoxMesh.new()
			gun.size = Vector3(3.0, 1.2, extents.z * 0.20)
			barrels.mesh = gun
			barrels.position = Vector3(0.0, extents.y + 4.0, end * extents.z * 0.60)
			barrels.material_override = material
			add_child(barrels)
			_body.append(barrels)
		return

	# HIGH WING or low: the same plank, and the only difference is where it sits and
	# whether it has struts holding it there. It matters more than it sounds -- the whole
	# reason anybody learns to fly in a high-wing aeroplane is that the ground is visible
	# out of both sides of it, and from outside the strut is how you tell one at a glance.
	var high: bool = shape == VehicleCatalogue.Body.HIGH_WING
	if high:
		for side in [-1.0, 1.0]:
			var strut := MeshInstance3D.new()
			strut.name = "WingStrut%s" % ["Port" if side < 0.0 else "Starboard"]
			var bar := BoxMesh.new()
			bar.size = Vector3(0.10, 1.30, 0.16)
			strut.mesh = bar
			strut.position = Vector3(side * span * 0.45, extents.y * 0.55, extents.z * 0.1)
			strut.rotation = Vector3(0.0, 0.0, side * 0.42)
			strut.material_override = material
			add_child(strut)
			_body.append(strut)

	# Main plane, tailplane and fin. Three boxes, and between them they say which way an
	# aeroplane is pointing from further away than a fuselage ever will.
	var wing := MeshInstance3D.new()
	wing.name = "Wing"
	var plank := BoxMesh.new()
	# CHORD CAPPED AGAINST THE SPAN. Taken from the fuselage alone, a 17 m airliner gets a
	# 4.7 m chord on a 19 m wing, which is a rectangle rather than an aeroplane and reads
	# the same way round whichever way it is pointing.
	plank.size = Vector3(span * 2.0, 0.22, minf(extents.z * 0.55, span * 0.38))
	wing.mesh = plank
	wing.position = Vector3(0.0, extents.y * (1.05 if high else -0.35), extents.z * 0.1)
	wing.material_override = material
	_body.append(wing)
	add_child(wing)

	var tailplane := MeshInstance3D.new()
	tailplane.name = "Tailplane"
	var small := BoxMesh.new()
	small.size = Vector3(span * 0.8, 0.18, extents.z * 0.25)
	tailplane.mesh = small
	tailplane.position = Vector3(0.0, extents.y * 0.3, extents.z * 0.82)
	tailplane.material_override = material
	_body.append(tailplane)
	add_child(tailplane)

	var fin := MeshInstance3D.new()
	fin.name = "Fin"
	var blade := BoxMesh.new()
	blade.size = Vector3(0.18, span * 0.55, extents.z * 0.28)
	fin.mesh = blade
	fin.position = Vector3(0.0, extents.y + span * 0.26, extents.z * 0.85)
	fin.material_override = material
	_body.append(fin)
	add_child(fin)


## The one-seat hover pod's visual pressure hull.  The shell is deliberately smaller than
## its collision box and does not touch the seat anchor; future changes to its movement or
## seat pose therefore flow straight through this view.
func _build_pod_airframe(extents: Vector3) -> void:
	var shell_material := StandardMaterial3D.new()
	shell_material.albedo_color = VehicleCatalogue.paint(kind)
	shell_material.metallic = 0.45
	shell_material.roughness = 0.30
	var shell := SphereMesh.new()
	shell.radius = maxf(extents.x * 0.94, 0.55)
	shell.height = maxf(extents.y * 1.52, 0.82)
	_add_airframe_part("PodPressureHull", shell, Vector3(0.0, -extents.y * 0.06, 0.05), Vector3.ZERO, shell_material)
	var canopy_material := StandardMaterial3D.new()
	canopy_material.albedo_color = Color(0.06, 0.12, 0.16, 0.76)
	canopy_material.metallic = 0.25
	canopy_material.roughness = 0.16
	canopy_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var canopy := SphereMesh.new()
	canopy.radius = maxf(extents.x * 0.70, 0.40)
	canopy.height = maxf(extents.y * 0.82, 0.48)
	_add_airframe_part("PodCanopy", canopy, Vector3(0.0, extents.y * 0.42, -extents.z * 0.24), Vector3.ZERO, canopy_material)
	for side in [-1.0, 1.0]:
		var vane := BoxMesh.new()
		vane.size = Vector3(0.10, 0.48, 0.72)
		_add_airframe_part("PodPortVane" if side < 0.0 else "PodStarboardVane", vane,
			Vector3(side * extents.x * 0.84, -extents.y * 0.15, extents.z * 0.26), Vector3(0.0, side * 0.38, 0.0), shell_material)


## A GENERIC TWIN-ENGINE UTILITY AEROPLANE.  It deliberately does not claim to be one
## particular type: the simulation calls it simply `plane`.  A tapered low wing, nacelles
## and a conventional tail make it useful as an immediately readable baseline when authors
## are comparing a new craft package in the builder.
func _build_utility_twin_airframe(span: float, extents: Vector3, material: StandardMaterial3D) -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.075, 0.085, 0.10)
	dark.metallic = 0.25
	dark.roughness = 0.42
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color(0.12, 0.30, 0.68)
	stripe.roughness = 0.46
	_add_airframe_part("UtilityTwinNose", _cylinder(0.10, extents.x * 0.78, extents.z * 0.42),
		Vector3(0.0, 0.0, -extents.z * 1.18), Vector3(-PI * 0.5, 0.0, 0.0), material)
	for side in [-1.0, 1.0]:
		_add_airframe_part("UtilityTwinWingPort" if side < 0.0 else "UtilityTwinWingStarboard",
			_tapered_wing_mesh(span, extents.z * 0.44, extents.z * 0.24, side),
			Vector3(0.0, -extents.y * 0.25, -extents.z * 0.10), Vector3.ZERO, material)
		var nacelle_at := Vector3(side * span * 0.47, -extents.y * 0.15, -extents.z * 0.28)
		_add_airframe_part("UtilityTwinPortNacelle" if side < 0.0 else "UtilityTwinStarboardNacelle",
			_cylinder(0.34, 0.45, extents.z * 0.54), nacelle_at, Vector3(-PI * 0.5, 0.0, 0.0), material)
		_add_airframe_part("UtilityTwinPortSpinner" if side < 0.0 else "UtilityTwinStarboardSpinner",
			_cylinder(0.12, 0.18, 0.25), nacelle_at + Vector3(0.0, 0.0, -extents.z * 0.33),
			Vector3(-PI * 0.5, 0.0, 0.0), dark)
		for axis in [0.0, PI * 0.5]:
			var prop := BoxMesh.new()
			prop.size = Vector3(0.07, 0.95, 0.04)
			_add_airframe_part("UtilityTwin%sPropellerBlade%s"
				% ["Port" if side < 0.0 else "Starboard", "A" if axis == 0.0 else "B"], prop,
				nacelle_at + Vector3(0.0, 0.0, -extents.z * 0.47), Vector3(0.0, 0.0, axis), dark)
	var tailplane := BoxMesh.new()
	tailplane.size = Vector3(span * 0.44, 0.13, extents.z * 0.19)
	_add_airframe_part("UtilityTwinTailplane", tailplane, Vector3(0.0, extents.y * 0.35, extents.z * 0.93), Vector3.ZERO, material)
	var fin := BoxMesh.new()
	fin.size = Vector3(0.13, extents.y * 1.55, extents.z * 0.27)
	_add_airframe_part("UtilityTwinFin", fin, Vector3(0.0, extents.y * 0.86, extents.z * 0.92), Vector3.ZERO, material)
	for side in [-1.0, 1.0]:
		var flash := BoxMesh.new()
		flash.size = Vector3(0.025, 0.22, extents.z * 1.25)
		_add_airframe_part("UtilityTwinStripe%s" % ["Port" if side < 0.0 else "Starboard"], flash, Vector3(side * (extents.x + 0.03), 0.08, -0.05), Vector3.ZERO, stripe)


## ---- the water bomber ------------------------------------------------------------------
##
## EVERY NUMBER BELOW IS IN THE CRAFT'S OWN FRAME: metres, -Z forward, +Y up, origin at the
## middle of the native hull (half-extents 1.60 x 1.70 x 9.90, half-span 14.30 --
## `tanker_shape`, cockpit_world.cpp). The published figures they are held against are De
## Havilland's own DHC-515 sheet: 19.8 m long, 9.02 m high, 28.6 m span, 3.97 m propeller.
## See `craft/tanker/sources.md`, and note that the CL-215, the CL-415 and the DHC-515 are
## three different aeroplanes -- the sheet on file is the third.

## WHERE THE WING SITS, and it is a height off the DRAWN HULL rather than off the collision
## box. The fuselage loft's crown at the wing station is h 1.25; the wing's lower skin is
## 0.075 below this, so the root beds 0.03 m into the crown.
const WING_ROOT_HEIGHT: float = 1.30
## WHERE THE FIN STANDS AND WHERE IT ENDS. The root is 0.15 m inside a tailcone crown that runs
## h 1.24 to 1.33 along it. The tip is the station the tailplane is bolted to, and it is set so
## that the tailplane's UPPER SKIN -- 0.09 above it -- is h 7.32, which with the hull's lowest
## drawn point at -1.68 is the published 9.02 m. THE HEIGHT IS THEREFORE CARRIED BY A PART
## BOLTED TO THE AEROPLANE, which is the whole of what went wrong here before.
const FIN_ROOT_HEIGHT: float = 1.10
const FIN_TIP_HEIGHT: float = 7.23
## THE PROPELLER DIAMETER De Havilland publishes. It was drawn at 1.42 m, a third of it.
const PROPELLER_DIAMETER: float = 3.97


## A WATER BOMBER AT THE CL-415'S PUBLISHED length and span, without copying a branded
## model.  The hull, high wing, twin turboprops, tip floats and T-tail are the working
## features a player needs to recognise during a low scooping pass.  The physical hull,
## water system and all four seats remain the C++ craft definition.
##
## ---------------------------------------------------------------------------------
## IT WAS IN EIGHTEEN PIECES, AND EVERY SUITE WAS GREEN
## ---------------------------------------------------------------------------------
##
## Until 2026-09-17 this aeroplane was a fuselage with a cloud of parts hanging in the air
## around it, and `screenshots/2026-09-17/cockpit-craft-tanker.png` shows the worst of it: the
## fin and tailplane floating well clear of the tailcone, attached to nothing. Measured by
## `aircraft_fidelity._every_drawn_part_is_joined_to_the_aeroplane`, which was written for it:
## **18 of 21 drawn parts did not touch the aeroplane.** The wing floated 0.33 m over the
## fuselage crown and took the engines, propellers, floats and struts with it as one detached
## group; the fin floated 1.79 m over the tailcone; the tailplane 4.13 m; the floats 9.48 m.
##
## WHY NOTHING CAUGHT IT, and it is worth reading twice because the same hole is elsewhere.
## `aircraft_fidelity` held this craft to a published 9.02 m height and the drawn model was
## 9.00, well inside two per cent -- because THE FIN TOP had been placed at the height that
## satisfies the contract and THE FIN BOTTOM had never been joined to anything. The dimension
## was real, the source was cited, the number was right, and the aeroplane was in pieces. A
## bounding box, a triangle budget and a roster of feature names all describe a SET of parts;
## not one of them asks whether the set is a single object.
##
## That is `lane/glider`'s fault in another costume -- a sailplane meeting its published
## height with an anonymous stub gun mount -- and `lane/skyhawk`'s, whose stations stood
## outside the skin their own craft drew. **A dimension has to be carried by the thing it
## names, and the thing it names has to be attached to the aeroplane.**
##
## ---------------------------------------------------------------------------------
## WHAT IS JOINED TO WHAT, WHICH IS NOW A DESIGN AND NOT AN ACCIDENT
## ---------------------------------------------------------------------------------
##
## Every part beds into its parent rather than resting against it, because a joint drawn to
## touch exactly is a joint that opens the first time anybody adjusts either end:
##
##   hull --- wing (root embedded in the crown) --- engines --- spinners --- blades
##        |                                     \- float struts --- floats
##        \- bow, keel
##        \- dorsal fin --- fin --- tailplane
##
## THE WING CAME DOWN 0.43 m to sit on the fuselage crown, which is where a high wing is. It
## had been at `extents.y * 1.02`, a number with no relationship to the hull the fuselage loft
## actually draws, and the crown under it is at 1.25.
##
## THE TAIL IS A T-TAIL NOW, which this doc block had claimed since it was written while the
## code built a cruciform with the tailplane halfway up a fin that reached nothing. The fin
## root beds into the tailcone at h 1.10 and its tip carries the tailplane, whose upper surface
## is the highest point of the aeroplane and therefore the thing the 9.02 m contract measures.
##
## THE PROPELLERS ARE 3.97 m ACROSS, which is the diameter `craft/tanker/sources.md` cites from
## De Havilland's own DHC-515 sheet and has been sitting there uncontradicted while the model
## drew them at 1.42. Four blades, as two crossed panels.
##
## AND EVERY PART HAS ITS OWN NAME. `_add_airframe_part` was called twice with
## "WaterBomberPropeller" and twice with "WaterBomberFloatStrut", and Godot renames a duplicate
## to `@MeshInstance3D@9` -- so four of this aeroplane's parts were anonymous, could not be
## found by name, could not be held to a feature contract, and do not read in a screenshot
## review as something somebody put there (`lane/glider`, 2026-09-17).
func _build_water_bomber_airframe(span: float, extents: Vector3, material: StandardMaterial3D) -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.07, 0.08)
	dark.metallic = 0.30
	dark.roughness = 0.38
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.94, 0.88)
	white.roughness = 0.5
	# The amphibious hull is broad and deep at the step, then pulls into a raised tail.
	# Its lower oval and separate keel read as a boat hull instead of a rectangular cabin.
	var hull: Array[Vector4] = _water_bomber_hull_stations(extents)
	_add_airframe_part("WaterBomberFuselage", ReferenceAirframeMeshes.fuselage(hull),
		Vector3.ZERO, Vector3.ZERO, material)
	_own_cabin_room = _water_bomber_cabin_room(hull)
	# A raised bow and long, shallow belly say "amphibian" at a distance without changing
	# the collision box that lets it work in the rest of this game.
	_add_airframe_part("WaterBomberBow", _cylinder(0.12, extents.x * 0.90, extents.z * 0.47),
		Vector3(0.0, 0.14, -extents.z + extents.z * 0.235), Vector3(-PI * 0.5, 0.0, 0.0), material)
	var keel := BoxMesh.new()
	keel.size = Vector3(extents.x * 1.34, 0.22, extents.z * 1.50)
	_add_airframe_part("WaterBomberHullKeel", keel, Vector3(0.0, -extents.y * 0.88, 0.35), Vector3.ZERO, white)
	# ON THE CROWN, NOT OVER IT. The fuselage loft's top surface at the wing station is h 1.25:
	# the wing's lower skin at 1.225 beds 0.03 into it, which is a joint. The old 1.734 was
	# `extents.y * 1.02`, a number about the COLLISION box and not about the hull anybody sees.
	var wing_y := WING_ROOT_HEIGHT
	for side in [-1.0, 1.0]:
		_add_airframe_part("WaterBomberWingPort" if side < 0.0 else "WaterBomberWingStarboard",
			_tapered_wing_mesh(span, 3.15, 1.55, side), Vector3(0.0, wing_y, -0.95), Vector3.ZERO, material)
		var hand: String = "Port" if side < 0.0 else "Starboard"
		# THE NACELLE STRADDLES THE WING rather than hanging under it: 0.64 m of radius against
		# a wing skin 0.32 above its axis, so the two solids share space at the leading edge,
		# which is where a tractor turboprop is bolted.
		var engine_at := Vector3(side * span * 0.34, wing_y - 0.32, -1.10)
		_add_airframe_part("WaterBomber%sEngine" % hand,
			_cylinder(0.56, 0.64, 2.05), engine_at, Vector3(-PI * 0.5, 0.0, 0.0), material)
		# A SPINNER, WHICH IS ALSO THE JOINT. Without it the blades sat 0.10 m ahead of the
		# nacelle's front face, which is a propeller flying in loose formation with its engine.
		_add_airframe_part("WaterBomber%sSpinner" % hand, _cylinder(0.14, 0.24, 0.42),
			engine_at + Vector3(0.0, 0.0, -1.15), Vector3(-PI * 0.5, 0.0, 0.0), dark)
		for blade in ["A", "B"]:
			var prop := BoxMesh.new()
			# 3.97 m ACROSS, off the DHC-515 sheet in craft/tanker/sources.md. It was 1.42.
			prop.size = Vector3(0.10, PROPELLER_DIAMETER, 0.05)
			_add_airframe_part("WaterBomber%sPropellerBlade%s" % [hand, blade], prop,
				engine_at + Vector3(0.0, 0.0, -1.32),
				Vector3(0.0, 0.0, 0.0 if blade == "A" else PI * 0.5), dark)
		# THE FLOAT WHERE THE SEA PUSHES ON IT: the simulation's own float (`kind_geometry`'s "floats", keel and
		# height), so the float that holds the wing up and the float drawn under it are one number. It was typed here
		# as 0.79 of the span out and two thirds of the half-height down, and the physics knew nothing of it.
		var wet: Array = Sim.geometry_of(kind).get("floats", []) as Array
		if wet.size() != 2:
			continue
		var float_of: Dictionary = wet[0 if side < 0.0 else 1]
		var float_mesh := _cylinder(0.24, 0.28, 1.85)
		var float_at: Vector3 = (float_of["keel"] as Vector3) + Vector3(0.0, float(float_of["height"]) * 0.5, 0.0)
		_add_airframe_part("WaterBomber%sFloat" % hand, float_mesh, float_at,
			Vector3(-PI * 0.5, 0.0, 0.0), white)
		# AND A STRUT THAT REACHES BOTH ENDS OF WHAT IT CARRIES. The old one was 1.70 m long,
		# leaned over at 0.38 rad, and hung in the air 0.33 m under the wing and 0.15 above the
		# float -- a strut joined to nothing at either end, which is the purest form of this
		# aeroplane's fault. Vertical, on the float's own station, long enough to bed into both.
		var strut := BoxMesh.new()
		strut.size = Vector3(0.12, 2.40, 0.16)
		_add_airframe_part("WaterBomber%sFloatStrut" % hand, strut,
			Vector3(float_at.x, 0.15, -0.30), Vector3.ZERO, material)
	# THE DORSAL FIN, blending the tailcone into the fin root the way the real aeroplane's does,
	# and structurally the thing that makes the fin's long root a joint rather than a butt.
	_add_airframe_part("WaterBomberDorsalFin", _tapered_wing_mesh(1.05, 3.00, 1.60, 1.0),
		Vector3(0.0, FIN_ROOT_HEIGHT + 0.05, 6.40), Vector3(0.0, 0.0, PI * 0.5), material)
	# THE FIN, standing ON the tailcone: its root beds 0.15 m into a crown that runs h 1.24 to
	# 1.33 along it, and its tip is the station the tailplane is bolted to.
	_add_airframe_part("WaterBomberFin",
		_tapered_wing_mesh(FIN_TIP_HEIGHT - FIN_ROOT_HEIGHT, 2.80, 1.40, 1.0),
		Vector3(0.0, FIN_ROOT_HEIGHT, 8.30), Vector3(0.0, 0.0, PI * 0.5), material)
	# THE TAILPLANE ON THE FIN TIP, which is what makes this a T-tail and what makes the
	# aeroplane's published 9.02 m height a dimension of the aeroplane rather than of a part
	# floating near it: the tailplane's upper skin IS the top of the model.
	var tailplane := BoxMesh.new()
	tailplane.size = Vector3(span * 0.42, 0.18, 1.05)
	_add_airframe_part("WaterBomberTailplane", tailplane,
		Vector3(0.0, FIN_TIP_HEIGHT, 8.48), Vector3.ZERO, material)


## THE HULL THIS AEROPLANE IS LOFTED FROM: one station per `Vector4(z, half_width, half_height,
## centre_height)`, nose first. ONE PLACE, because the drawn skin and the room promised inside it
## are now both read off this and cannot drift apart.
func _water_bomber_hull_stations(extents: Vector3) -> Array[Vector4]:
	return [
		Vector4(-extents.z, 0.10, 0.10, 0.12),
		Vector4(-extents.z * 0.83, extents.x * 0.86, extents.y * 0.74, -0.18),
		Vector4(-extents.z * 0.38, extents.x * 0.96, extents.y * 0.87, -0.20),
		Vector4(extents.z * 0.34, extents.x * 0.92, extents.y * 0.78, -0.12),
		Vector4(extents.z * 0.82, extents.x * 0.42, extents.y * 0.42, 0.62),
		Vector4(extents.z, 0.10, 0.13, 1.10),
	]


## HOW FAR FORE AND AFT OF THE CREW THE ROOM RUNS, in metres. The pilots are at z -7.40 and the
## observers at -3.80, and a room has to have some aeroplane in front of the front one and behind
## the back one to be worth promising -- but only as much as the hull can carry, because the
## fuselage is still narrowing steeply at z -7.6.
const BOMBER_ROOM_MARGIN: float = 0.20
## HOW FAR OUTBOARD OF THE OUTERMOST SEAT THE ROOM REACHES. Past the seat and not past the
## SHOULDER: a crew member's shoulders are 0.19 either side of their seat (`CockpitStation`), and
## a box that wide would have to be 0.20 m shorter to stay inside this hull -- which would put the
## pilots' own eyes outside their own room. A room is a box, not a body: the interface says in
## terms that it is the largest box that can be PROMISED and not a description of the cabin's
## shape, and a shoulder outside it is not a shoulder outside the aeroplane.
const BOMBER_ROOM_ELBOW: float = 0.10
## HOW MUCH OF THE SECTION'S HEIGHT IS PROMISED at that width. A 16-sided loft is drawn INSIDE the
## ellipse its stations describe -- its flats cut the corners at cos(PI/16), 0.981 of the radius
## -- so a box laid on the ellipse would have its top corners in the paint. Held against the DRAWN
## TRIANGLES by `tests/water.gd`, which is the only thing that makes it worth anything.
const BOMBER_SECTION_MARGIN: float = 0.96


## THE ROOM THIS AEROPLANE PROMISES ROUND ITS CREW, computed from the loft it is drawn from and
## the seats the simulation puts in it.
##
## AS WIDE AS THE CREW NEED, AND THEN AS TALL AS THE HULL ALLOWS. That order matters and it is the
## second thing tried. The first was the largest box inscribed in the section -- a/sqrt(2) by
## b/sqrt(2), which is the biggest box by area -- and on this aeroplane it came out 0.91 wide and
## reached h 0.66, while the pilots' eyes are at h 0.85. **The largest room was a room the crew's
## own heads were outside of.** A room is worth having because somebody can put something in it,
## so the width is set by what has to fit and the height is then whatever the hull will carry.
##
## COMPUTED AND NOT TYPED, off the same `Vector4` stations the skin is lofted from, so a hull
## section that moves takes the promise with it. That is deliberately NOT what `SkyhawkAirframe`
## does -- there the figures are typed and the test plays them against the drawing, so a mutant
## that moves one is caught by the other. Here skin and promise share a source, so the test cannot
## do that and instead fires rays at the DRAWN TRIANGLES (`tests/water.gd`). Each is a way of
## getting an independent datum. What is not allowed is having neither.
##
## THE TIGHTEST SECTION IN RANGE DECIDES, sampled ALONG the room and not at its two ends: this
## loft is not monotonic -- it swells from the nose to the step and pulls in again -- and a box
## sized off its end stations alone would bulge through the waist between them.
func _water_bomber_cabin_room(hull: Array[Vector4]) -> Dictionary:
	var poses: Array = Sim.geometry_of(Sim.Kind.TANKER).get("seat_poses", []) as Array
	if poses.is_empty():
		return {}
	var fore: float = INF
	var aft: float = -INF
	var half_wide: float = 0.0
	# THE FLOOR IS WHERE THE SEAT POSE IS. A station's own origin is its floor -- the eye is
	# `CockpitStation.EYE_HEIGHT` above it, not above a seat cushion -- so the simulation has
	# already published where the crew stand and this reads it rather than keeping a second copy.
	var floor_y: float = INF
	for pose in poses:
		var at: Vector3 = (pose as Dictionary).get("position", Vector3.ZERO) as Vector3
		fore = minf(fore, at.z)
		aft = maxf(aft, at.z)
		half_wide = maxf(half_wide, absf(at.x))
		floor_y = minf(floor_y, at.y)
	fore -= BOMBER_ROOM_MARGIN
	aft += BOMBER_ROOM_MARGIN
	half_wide += BOMBER_ROOM_ELBOW
	var top: float = INF
	var bottom: float = -INF
	for step in range(17):
		var z: float = lerpf(fore, aft, float(step) / 16.0)
		var section: Vector3 = _hull_section_at(hull, z)
		if section.x <= half_wide or section.y <= 0.0:
			return {}
		# HOW TALL AN ELLIPSE IS AT A GIVEN HALF-WIDTH, which is the whole of the arithmetic:
		# (w/a)^2 + (h/b)^2 = 1. A box that used the section's full half-height would be a box
		# whose top corners are outside the oval at the very place the hull is narrowing.
		var across: float = half_wide / section.x
		var reach: float = section.y * sqrt(maxf(0.0, 1.0 - across * across)) * BOMBER_SECTION_MARGIN
		top = minf(top, section.z + reach)
		bottom = maxf(bottom, section.z - reach)
	if top <= bottom:
		return {}
	return {
		"drawn": true,
		"room": AABB(Vector3(-half_wide, bottom, fore),
			Vector3(half_wide * 2.0, top - bottom, aft - fore)),
		"floor": floor_y,
		"because": &"",
		"why_not": "",
		"source": "computed from the DHC-515 hull loft this aeroplane is drawn from, across the "
			+ "z range and width its own seat poses occupy; craft/tanker/sources.md",
	}


## THE SECTION OF A LOFT AT ONE STATION, as `(half_width, half_height, centre_height)`, linearly
## between the two `Vector4`s it lies between -- which is exactly how `ReferenceAirframeMeshes`
## builds the skin, so the two agree by construction rather than by agreement.
func _hull_section_at(hull: Array[Vector4], z: float) -> Vector3:
	if hull.is_empty():
		return Vector3.ZERO
	if z <= hull[0].x:
		return Vector3(hull[0].y, hull[0].z, hull[0].w)
	for index in range(hull.size() - 1):
		var here: Vector4 = hull[index]
		var next: Vector4 = hull[index + 1]
		if z > next.x:
			continue
		var along: float = 0.0 if is_equal_approx(next.x, here.x) \
			else (z - here.x) / (next.x - here.x)
		return Vector3(lerpf(here.y, next.y, along), lerpf(here.z, next.z, along),
			lerpf(here.w, next.w, along))
	var last: Vector4 = hull[hull.size() - 1]
	return Vector3(last.y, last.z, last.w)


## Create one painted mesh node and keep it in `_body`, so the normal inside-cockpit
## ghosting rule applies equally to the specialised Cessna fittings.
func _add_airframe_part(part_name: String, mesh: Mesh, at: Vector3, rotation: Vector3,
		material: Material) -> MeshInstance3D:
	var drawn := MeshInstance3D.new()
	drawn.name = part_name
	drawn.mesh = mesh
	AircraftVisualLod.configure(drawn)
	drawn.position = at
	drawn.rotation = rotation
	drawn.material_override = material
	_body.append(drawn)
	add_child(drawn)
	return drawn


func _cylinder(top: float, bottom: float, length: float) -> CylinderMesh:
	var tube := CylinderMesh.new()
	tube.top_radius = top
	tube.bottom_radius = bottom
	tube.height = length
	return tube


## One tapered wing panel, with a small thickness.  SurfaceTool gives the Cessna a genuine
## trapezoid instead of a rectangular plank while keeping this model procedural and cheap.
func _tapered_wing_mesh(span: float, root_chord: float, tip_chord: float, side: float) -> ArrayMesh:
	var root_lead: float = -root_chord * 0.5
	var root_trail: float = root_chord * 0.5
	var tip_lead: float = -tip_chord * 0.5 + 0.18
	var tip_trail: float = tip_chord * 0.5 + 0.18
	var outer: float = side * span
	var thick: float = 0.075
	return _panel_mesh([
		Vector3(0.0, thick, root_lead), Vector3(0.0, thick, root_trail),
		Vector3(outer, thick, tip_lead), Vector3(outer, thick, tip_trail),
		Vector3(0.0, -thick, root_lead), Vector3(0.0, -thick, root_trail),
		Vector3(outer, -thick, tip_lead), Vector3(outer, -thick, tip_trail),
	])


## A CLOSED SIX-SIDED PANEL FROM ITS EIGHT CORNERS, welded and faceted: upper surface first
## (root leading, root trailing, tip leading, tip trailing) then the four below it in the
## same order. One place, because two wing builders were about to keep two copies of the
## same winding and a reversed face is invisible until the light moves.
func _panel_mesh(corners: Array) -> ArrayMesh:
	var faces: Array[PackedInt32Array] = [
		PackedInt32Array([0, 2, 1, 1, 2, 3]), PackedInt32Array([4, 5, 6, 5, 7, 6]),
		PackedInt32Array([0, 4, 2, 2, 4, 6]), PackedInt32Array([1, 3, 5, 3, 7, 5]),
		PackedInt32Array([2, 6, 3, 3, 6, 7]), PackedInt32Array([0, 1, 4, 1, 5, 4]),
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		for index in face:
			tool.add_vertex(corners[index] as Vector3)
	tool.generate_normals()
	return tool.commit()


## The back seats' system, made visible. It aims and does not fire, which is the honest
## extent of it: the point is that a seat with no authority over where the craft goes still
## has something of its own to control, and that what it controls is replicated so everyone
## can see where the gunner is looking.
## ONE MOUNT PER TURRET SEAT, where that seat is.
##
## A craft with a gun forward and a gun aft has two gunners looking at two different
## things, so it gets two mounts and each is drawn over the seat that aims it. Everything
## else has one, over the back, exactly as before.
func _build_turret(extents: Vector3) -> void:
	# AN AIRFRAME THAT DRAWS ITS OWN GUN GETS NO SECOND ONE: the AH-64's M230 is `ApacheAirframe`'s chin turret, turned
	# by `set_gun` from `draw_turrets_at` (lane/apache). The generic mount below would have hung a dome and a barrel at
	# 0.35 of the box's length, a second gun beside the one the rounds leave from.
	if _airframe_draws_its_gun():
		_turret = null
		return
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.30, 0.32, 0.36)
	metal.metallic = 0.6
	metal.roughness = 0.4

	# A CRAFT WITH NOTHING TO SHOOT WITH DRAWS NO GUN, WHATEVER ITS SEATS ARE CALLED.
	#
	# This was "no turret seat AND no gun fitted" when `lane/glider` wrote it this morning, and the AND is what let
	# the WATER BOMBER through: its two aft seats are `Station::Turret`, so `where` was never empty, and it carried
	# TWO anonymous gun stubs on its spine -- on the aeroplane whose own simulation comment reads "Nobody in the back
	# of this aeroplane is shooting at anything; they are looking at the ground, which is where the fire is". Measured
	# by `aircraft_fidelity._every_drawn_part_is_joined_to_the_aeroplane` on 2026-09-17: four anonymous meshes, 0.29 m
	# and 0.38 m adrift of the hull, on a firefighting aircraft.
	#
	# A SEAT IS WHERE SOMEBODY SITS, NOT WHAT THEY SHOOT. The turret station is how the simulation says "this seat
	# looks outward and turns"; the observers in a water bomber's waist do exactly that and are armed with binoculars.
	# The only authority for whether a gun exists is the gun table, so that is the only thing asked. ANY mount, not
	# mount 0: a Chinook's ramp gun is mount 1 and there is nothing at all on its mount 0.
	var armed_anywhere: bool = false
	for mount in range(MAX_TURRETS):
		if bool(Sim.gun_of(kind, mount).get("fitted", false)):
			armed_anywhere = true
			break
	if not armed_anywhere:
		_turret = null
		return
	var where: Array[float] = []
	for entry in (Sim.geometry_of(kind).get("seat_poses", []) as Array):
		if String(entry.get("station", "")) == "turret":
			where.append((entry.get("position", Vector3.ZERO) as Vector3).z)
	if where.is_empty():
		# NO TURRET SEAT AND NO GUN FITTED MEANS NO MOUNT, and that is new on 2026-09-17 (`lane/glider`). This
		# fallback used to invent a mount at `extents.z * 0.35` for ANY craft with no turret seat, which put an
		# anonymous 0.36 m dome and a 1.1 m barrel on the cessna, the glider, the brig, the submarine, the segway,
		# the E-6B and the fighter. On the sailplane it was worse than ugly: the dome sat at y 0.98, which was the
		# HIGHEST POINT OF THE AEROPLANE, so `aircraft_fidelity`'s 1.80 m height contract for a DG-1001 was being
		# satisfied by a machine gun while the airframe itself stood 1.69 m. A craft that has nowhere to put a
		# gunner and nothing fitted to shoot with draws no gun.
		#
		# ASKED OF THE SIMULATION, NOT LISTED HERE: `gun_of` is the same question `armed` below asks, so the roster
		# of which craft carry guns stays in one place and cannot go out of date.
		where.append(extents.z * 0.35)

	for i in range(mini(where.size(), MAX_TURRETS)):
		# WHAT IS ACTUALLY ON THIS MOUNT, asked of the simulation. A mount with a gun on it
		# gets THAT gun's barrel -- the length the round is fired from the end of. Drawing a
		# metre of barrel on a tank whose shell leaves five and a half metres in front of the
		# trunnion is how you get a round that appears out of thin air past the end of the gun.
		# A mount with NO gun on it draws nothing at all: see below, where it is kept.
		var fitted: Dictionary = Sim.gun_of(kind, i)
		var armed: bool = bool(fitted.get("fitted", false))
		var length: float = float(fitted.get("barrel", 1.1))
		var bore: float = maxf(length * 0.022, 0.05)

		var gun := Node3D.new()
		gun.name = "Turret%d" % i
		gun.position = Vector3(0.0, extents.y + 0.10, where[i])
		if armed:
			# On the mount the gun is actually on, so the drawn barrel and the fired round
			# start in the same place.
			gun.position = (fitted.get("at", Vector3.ZERO) as Vector3)
		add_child(gun)

		# AN EMPTY MOUNT DRAWS NOTHING -- AND STAYS IN THE ROSTER, WHICH IS THE WHOLE TRICK.
		#
		# This used to draw a 0.36 m dome and a 1.1 m barrel on a mount the simulation says has no
		# gun, on purpose: "a mount with nothing on it keeps the stub it always had". On the TANK that
		# stub was the highest point of the vehicle, 2.68 m over the ground against an M1A2's 2.44 m,
		# which is the sailplane's stub gun again (`lane/glider`): a height contract for the tank would
		# have been met by a gun that is not there. The Chinook carried one on its empty mount 0.
		#
		# DO NOT "SIMPLIFY" THIS TO A BARE `continue`. `draw_turrets_at` hands mount i's aim to
		# `_turrets[i]`, so the array is POSITIONAL, and a `continue` taken before the append shifts
		# every later mount down one. On the tank that looks harmless -- the empty mount is the last,
		# and it merely goes unaimed. On the CHINOOK, whose mount 0 is empty and whose ramp gun is
		# mount 1, the ramp gun would be drawn at the aim meant for the empty seat. So the node is
		# appended, bare, and is aimed like any other and draws nothing. `tests/mount_aim.gd` holds
		# both halves across the fleet, and was turned red by a bare `continue` on purpose to prove it.
		if not armed:
			_turrets.append(gun)
			continue

		# A GUN SWUNG BY HAND IS A DIFFERENT SHAPE FROM A GUN DRIVEN BY A MOTOR, and it is
		# drawn here rather than in the cockpit because everybody can see it: a machine gun
		# hanging out of an open door is most of what a helicopter with a door gunner LOOKS
		# like, and a copy of it built in the gunner's station would be a second gun in the
		# doorway for the two of them to z-fight over.
		#
		# So the whole gun is here -- barrel, body, ammunition and the grips the gunner
		# actually takes hold of -- and `PintleGun` in the cockpit adds nothing but the
		# trigger. The grip offsets are ITS constants, because a grip you reach for has to
		# be the grip you can see.
		if bool(fitted.get("pintle", false)):
			_hand_swung_gun(gun, metal, length)
			_turrets.append(gun)
			# AND THE POST IT SWINGS ON, which does NOT swing. A pintle is a pin in the
			# door frame and the gun turns on top of it, so it is a sibling of the mount
			# rather than a child: bolted to the aircraft, at the aircraft's attitude,
			# whatever the gunner is doing with the gun above it.
			var post := MeshInstance3D.new()
			post.name = "Turret%dPost" % i
			var pillar := CylinderMesh.new()
			pillar.top_radius = 0.030
			pillar.bottom_radius = 0.045
			pillar.height = 0.45
			post.mesh = pillar
			post.material_override = metal
			post.position = gun.position + Vector3(0.0, -0.225, 0.0)
			add_child(post)
			continue

		# A MOUNT THAT THROWS WATER IS A MONITOR, and is drawn as one: a swivel body between its cheeks with a
		# tapering barrel and a nozzle, in the fire-service red.
		#
		# ASKED OF THE MOUNT, NOT OF THE KIND, and that is the difference between this branch and the battleship's
		# below. `gun_of` already knows this mount throws water (`Gun::water`), so a second water-throwing craft --
		# a fire tug, an airport crash tender -- needs no edit in this file at all. The battleship's branch is a
		# kind check because a sixteen-inch gunhouse really is one ship's.
		if bool(fitted.get("water", false)):
			var nozzle := MeshInstance3D.new()
			nozzle.name = "Monitor"
			nozzle.mesh = Fireboat.monitor(length)
			nozzle.material_override = ShipHull.painted()
			gun.add_child(nozzle)
			_turrets.append(gun)
			# AND THE PEDESTAL IT STANDS ON, which does NOT elevate: a sibling, exactly as the pintle gun's post is.
			# Drawn as a child it would lie over on its side every time the crew depressed the monitor.
			var deck_under: float = Superstructure.top_under(
				Sim.geometry_of(kind).get("parts", []) as Array, Vector2(gun.position.x, gun.position.z))
			var stand := MeshInstance3D.new()
			stand.name = "Turret%dPedestal" % i
			stand.mesh = Fireboat.monitor_pedestal(gun.position.y, deck_under if is_finite(deck_under) else 0.0)
			stand.material_override = ShipHull.painted()
			stand.position = Vector3(gun.position.x, 0.0, gun.position.z)
			add_child(stand)
			continue

		# A BATTLESHIP'S MOUNT IS A SIXTEEN-INCH TURRET, drawn as one (plan item 22): the ship's own model leaves the
		# gunhouses it trains out of its welded mesh, and this is where they go -- on the mount, turned with it.
		if kind == Sim.Kind.BATTLESHIP and armed:
			var house := MeshInstance3D.new()
			house.name = "Gunhouse"
			house.mesh = Battleship.gunhouse()
			house.material_override = ShipHull.painted()
			gun.add_child(house)
			_turrets.append(gun)
			continue
		# NAMED, LIKE EVERY OTHER VISIBLE PART. These two were the only anonymous meshes left on the tank
		# (`tests/tank_shape.gd`, 2026-09-17): Godot called them `@MeshInstance3D@2` and up, so no check could
		# ask how long the gun was. They are children of `Turret<i>`, so one name each does for every mount.
		var mount := MeshInstance3D.new()
		mount.name = "Mount"
		var dome := SphereMesh.new()
		dome.radius = maxf(0.18, bore * 3.0)
		dome.height = dome.radius * 2.0
		mount.mesh = dome
		mount.material_override = metal
		gun.add_child(mount)

		var barrel := MeshInstance3D.new()
		barrel.name = "Barrel"
		var tube := CylinderMesh.new()
		tube.top_radius = bore
		tube.bottom_radius = bore * 1.2
		tube.height = length
		barrel.mesh = tube
		# The barrel points along the turret's own -Z, the vehicle's nose at rest.
		barrel.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		barrel.position = Vector3(0.0, 0.0, -length * 0.5)
		barrel.material_override = metal
		gun.add_child(barrel)
		_turrets.append(gun)
	_turret = _turrets[0] if not _turrets.is_empty() else null


## A GUN ON THE WEAPON SELECTOR, drawn where the simulation fires it from: the fighter's minigun (plan item 4), six
## barrels round a spindle under the nose. Not a turret -- it does not train, so it is bolted to the airframe and never
## touched again -- and placed from the station's own `at` and `barrel`, so the rounds leave from the end of what is
## drawn. A craft with no such station draws nothing here.
func _build_the_selected_guns() -> void:
	# NOT ON THE A-10C: `WarthogAirframe` draws its own GAU-8, seven barrels that turn, whose muzzle the rounds leave
	# from. The fighter's six-barrel stand-in was drawn as well, inside the nose, where the pilot saw it through the
	# glass (`tests/warthog.gd`, "and_sees_the_coaming_and_not_into_the_nose").
	if kind == Sim.Kind.WARTHOG:
		return
	# NOR ON A WARBIRD, whose class draws its own guns in its wings, where the rounds leave from (`P51Airframe.muzzles`).
	if VehicleCatalogue.body(kind) == VehicleCatalogue.Body.WARBIRD:
		return
	for entry in (Sim.missile_schema(kind).get("stations", []) as Array):
		var station: Dictionary = entry
		if not bool(station.get("gun", false)):
			continue
		var length: float = float(station.get("barrel", 0.8))
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(0.16, 0.17, 0.19)
		metal.metallic = 0.7
		metal.roughness = 0.35
		var gun := Node3D.new()
		gun.name = "NoseGun"
		gun.position = station.get("at", Vector3.ZERO) as Vector3
		add_child(gun)
		# THE BREECH HOUSING, behind the muzzle end, and the six barrels ahead of it pointing down -Z.
		var housing := MeshInstance3D.new()
		housing.name = "Breech"
		var box := CylinderMesh.new()
		box.top_radius = 0.07
		box.bottom_radius = 0.07
		box.height = 0.30
		housing.mesh = box
		housing.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		housing.position = Vector3(0.0, 0.0, 0.15)
		housing.material_override = metal
		gun.add_child(housing)
		for b in range(6):
			var turn: float = TAU * float(b) / 6.0
			var barrel := MeshInstance3D.new()
			barrel.name = "Barrel%d" % (b + 1)
			var tube := CylinderMesh.new()
			tube.top_radius = 0.011
			tube.bottom_radius = 0.011
			tube.height = length
			barrel.mesh = tube
			barrel.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			barrel.position = Vector3(cos(turn) * 0.035, sin(turn) * 0.035, -length * 0.5)
			barrel.material_override = metal
			gun.add_child(barrel)
		# NOT IN `_body`: ghosting repaints every mesh there in the hull's own colour, and a gun is gunmetal.


## EVERY MOUNT ON THIS CRAFT, PUT WHERE `aimed` SAYS IT IS POINTING.
##
## Separate from `draw` because it is asked for twice: once a frame from the live,
## interpolated angles, and once by the screenshot tool -- which has no simulation behind it
## and wants the guns at rest, where a gunner finds them on climbing aboard.
##
## THE GUN IN THE GUNNER'S HANDS IS AIMED IN THE SAME BREATH, from the same array. A
## hand-swung gun is drawn out here and held in there, so the two have to be one object:
## read twice, a frame apart, they would part company whenever the mount was moving -- which
## is exactly when anybody is looking at it.
func draw_turrets_at(aimed: Array) -> void:
	# THE WIRE FIRST, to every station, because that is what a gun needs to know about the mount
	# whatever it then decides to draw.
	for station in stations():
		(station as CockpitStation).aim_the_gun(aimed)
	# AND THEN WHERE A HAND ON THIS MACHINE HAS ACTUALLY PUT IT. A gun somebody here is holding is
	# ahead of the wire by a round trip -- see PintleGun.lead -- and the barrel hanging out of the
	# doorway is the same object as the sight on top of it, so it has to be drawn from the same
	# answer. Nothing is copied unless somebody is holding something: on every other aircraft in
	# the sky this is the array it was handed.
	var shown: Array = aimed
	for station in stations():
		var led: Dictionary = (station as CockpitStation).gun_it_is_leading()
		if led.is_empty():
			continue
		if shown == aimed:
			shown = aimed.duplicate()
		var mount: int = int(led["mount"])
		if mount < shown.size():
			shown[mount] = led["aim"]
	for i in range(_turrets.size()):
		if i >= shown.size():
			break
		var aim: Vector2 = shown[i]
		(_turrets[i] as Node3D).basis = Basis(Vector3.UP, aim.x) \
			* Basis(Vector3.RIGHT, aim.y)
	# AND THE AIRFRAME'S OWN GUN, from the same answer: the AH-64's chin turret is mount 0 (lane/apache), and the
	# AC-130U's three are mounts 0, 1 and 2 (lane/liners).
	if _airframe_draws_its_gun() and not shown.is_empty():
		if _rotorcraft != null:
			var chin: Vector2 = shown[0]
			_rotorcraft.call("set_gun", chin.x, chin.y)
		elif _jetliner != null:
			_jetliner.call("aim_guns", shown)


## WHETHER THIS CRAFT'S AIRFRAME DRAWS ITS OWN GUN, asked by method name as `cabin_room` is: an airframe opts in by
## growing `set_gun`, and nothing here keeps a list of which craft do.
func _airframe_draws_its_gun() -> bool:
	return (_rotorcraft != null and _rotorcraft.has_method("set_gun")) \
		or (_jetliner != null and _jetliner.has_method("aim_guns"))


## A BELT-FED MACHINE GUN ON A PINTLE, hinged at its own middle.
##
## Everything is measured from the TRUNNION, which is the origin of the mount and the point
## the round is fired along -- so the barrel runs forward out of it and the body, the
## ammunition and the grips hang back over the gunner's side of it. That is why a hand
## pushed right swings the muzzle left, and drawing it as one object is how anybody could
## work that out without being told.
func _hand_swung_gun(gun: Node3D, metal: StandardMaterial3D, length: float) -> void:
	var back: float = PintleGun.GRIP_BACK
	var rise: float = PintleGun.GRIP_RISE
	# THE BARREL, thin, out of the front. `length` is the simulation's, because it is the
	# distance the round leaves from -- see the note above about the tank.
	var tube := CylinderMesh.new()
	tube.top_radius = 0.014
	tube.bottom_radius = 0.020
	tube.height = length
	_gun_part(gun, "Tube", tube, metal, Vector3(0.0, 0.0, -length * 0.5),
		Vector3(-PI * 0.5, 0.0, 0.0))
	# THE TRUNNION it swings on, and the body behind it.
	var pin := CylinderMesh.new()
	pin.top_radius = 0.035
	pin.bottom_radius = 0.035
	pin.height = 0.11
	_gun_part(gun, "Pintle", pin, metal, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5))
	var body := BoxMesh.new()
	body.size = Vector3(0.085, 0.10, back * 0.75)
	_gun_part(gun, "Receiver", body, metal, Vector3(0.0, 0.012, back * 0.35), Vector3.ZERO)
	# THE FEED TRAY AND THE BELT BOX, on the right, which is which side of a machine gun
	# the ammunition has gone in since about 1910. It hangs BESIDE the body rather than
	# under it: under it is where the console is, and a box through the console is the sort
	# of thing only a picture from the seat ever shows.
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.12, 0.19)
	_gun_part(gun, "AmmoBox", box, metal, Vector3(0.115, -0.01, back * 0.30), Vector3.ZERO)
	# AND THE SPADE GRIPS, one either side of the backplate, with the trigger between them.
	# A hand takes hold in the MIDDLE: this is one gun with two handles, not two controls.
	var plate := BoxMesh.new()
	plate.size = Vector3(PintleGun.GRIP_SPREAD + 0.05, 0.12, 0.025)
	_gun_part(gun, "Shield", plate, metal, Vector3(0.0, rise - 0.01, back - 0.055), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var handle := BoxMesh.new()
		handle.size = Vector3(0.030, 0.115, 0.034)
		_gun_part(gun, "Grip%s" % ["Port" if side < 0.0 else "Starboard"], handle, metal,
			Vector3(side * PintleGun.GRIP_SPREAD * 0.5, rise - 0.02, back), Vector3.ZERO)


## ONE PIECE OF A HAND-SWUNG GUN, NAMED. `part_name` is an argument and not a constant
## because this builds six different things -- the tube, the pintle, the receiver, the box,
## the shield and two handles -- and six children called the same thing leave Godot to number
## five of them. See `tests/named_parts.gd`.
func _gun_part(gun: Node3D, part_name: String, mesh: Mesh, metal: StandardMaterial3D,
		at: Vector3, turned: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = metal
	part.position = at
	part.rotation = turned
	gun.add_child(part)


## A SET OF CONTROLS IN FRONT OF EVERY SEAT, not one set per craft.
##
## Two pilots have two sticks, and the whole point is that each can see the other move
## theirs. They are children of the seat anchor like everything else that rides in a
## vehicle, so their pose relative to the cockpit is exactly constant rather than
## approximately -- see the note at the top of PilotRig.
## THE CENTRE CONSOLE: what belongs to the AIRCRAFT rather than to a seat.
##
## Everything on it is within reach of both front seats and owned by neither, which is the
## whole point of a console. A crew calls for flaps and puts the gear down between them,
## and either of them may be the one whose hand does it -- see PilotRig, which offers hands
## by distance and not by seat.
##
## Built once when anybody comes aboard and freed when the last of them leaves, exactly as
## the stations are. `controls_for` splices it into EVERY seat's set, so a console control
## is claimed by all of them and reaches the rig without anything here knowing about rigs.
##
## PLACED IN THE PILOT'S FRAME AND THEN MOVED ONTO THE CENTRE LINE, because a seat anchor
## is not at the vehicle's origin: seat 0 sits 0.30 m below it and 5.60 m forward on the
## airliner, so a console put at hand height in VEHICLE space would float a third of a
## metre above the crew's hands.
##
## THE SPACING IS THE HARD PART and it is measured, not chosen. No two grips in a craft may
## be within one hand of each other -- REACH * 2 -- or a hand reaching for one takes the
## other, which used to be prevented by ownership and is now prevented only by distance.
## The console sits in the gap between two stations' control envelopes, which on
## side-by-side seats 1.10 m apart is 0.42 m wide, so its controls are spread fore and aft
## as well as across. `no_two_controls_in_a_craft_are_within_one_hand_of_each_other` is
## what says whether a placement is legal -- and `tests/fit.gd`, which is what runs it over
## every craft in the game with the console and the guns actually built. That suite found
## twenty-three pairs inside the rule the first time it was pointed at a whole cockpit.
##
## ACROSS, and this used to be 0.30 -- which is exactly one hand short, so the flap gate and
## the gear lever beside it shared a place a hand could be on every aeroplane that has both.
const CONSOLE_SPREAD: float = 0.38
## How far FORWARD of the hands the cluster sits, and how far BELOW them. These were one
## number, `CONSOLE_SPREAD` doing all three jobs, so widening the gap between two levers
## also pushed them out of arm's reach.
## WHERE THE PEDESTAL SITS ALONG THE CENTRE LINE, aft of the hands, one lever per notch.
##
## IT USED TO GO FORWARD, thirty centimetres past where the hands already are, and that put
## the flap gate 0.87 m from a pilot's shoulder and the gear lever 0.88 m from the other
## one's -- past a seated arm, on every aeroplane in the game.
##
## Forward was not a whim. The centre corridor between two side-by-side seats is 0.42 m
## wide, and at the hands plane BOTH ends of it are taken: the right seat's throttle is
## inboard at one edge and the left seat's crew button at the other, each 0.21 m off the
## centre line, where the layout rule wants 0.32. Going forward was the only direction with
## room in it, and it bought that room by putting the levers where nobody can reach.
##
## AFT HAS THE SAME ROOM AND COSTS NOTHING. Behind the hands the corridor is empty, it is
## where a real pedestal runs, and it is beside your hip instead of out on the coaming -- so
## the arm that works it is bent rather than straight. The drop handle found this first and
## the comment beside it says so; the rest of the console has now followed it back.
##
## One notch is 0.34 m, which clears the 0.32 the layout rule asks between two grips with
## enough left over that moving a seat by a centimetre does not fail the suite.
const CONSOLE_NOTCH: float = 0.34

## HOW FAR AFT OF THE HANDS THE FIRST LEVER SITS, when the front slot is not taken by a
## shared throttle. A SEPARATE NUMBER FROM THE NOTCH, and it has to be.
##
## The notch is bounded below by the layout rule: two grips need 0.32 m between them, so the
## row cannot be tighter than that. The START is bounded by something else entirely -- how
## far aft the inboard station controls reach. They sit 0.21 m off the centre line, which
## leaves sqrt(0.32^2 - 0.21^2) = 0.24 m of fore-and-aft clearance to find, and the osprey's
## nacelle lever is the one that reaches furthest back. One number doing both jobs put the
## first lever 0.25 m from it.
## In practice it lands on the same 0.34 as the notch: forward of that and the row hits the
## inboard THROTTLE, whose knob slides aft along its quadrant. The corridor is squeezed from
## both ends and there is exactly one slot in it.
const CONSOLE_START: float = 0.34
## 0.11 AND NOT A CENTIMETRE MORE, because of the airliner. Its two pilots share one
## throttle on the centre line, and the further of them is already 0.78 m from it against a
## 0.80 m reach -- so every centimetre this drops is a centimetre nearer a quadrant one of
## them cannot work. See `and_both_of_them_can_reach_it`, which is the other end of this.
const CONSOLE_BELOW: float = 0.11

## HOW FAR FROM A SEAT A SHARED CONTROL MAY BE and still be that seat's to work, in metres
## from the seat anchor -- which is the FLOOR under the occupant, so a lever by their hip is
## already about 1.1 m from it.
##
## This is a question of ownership rather than of comfort: two pilots share a pedestal, and
## a gunner in the tail shares nothing. Wide enough that a flight deck is one cockpit and
## narrow enough that a fuselage is not -- and narrow enough that a handle out past the far
## seat's shoulder belongs to that seat alone. See `controls_for`.
const CONSOLE_OWNED: float = 1.3

## And how far out the whole ROW goes when there is no gap between two seats to run it down.
const CONSOLE_ASIDE: float = 0.56

## How far aft of the shoulders the middle of the row sits. See `_centre_the_row`.
const CONSOLE_AFT_BIAS: float = 0.05



func _build_console() -> void:
	if not _console.is_empty():
		return
	var fitted: Dictionary = {}
	for entry in _fitted:
		fitted[String((entry as Dictionary).get("name", ""))] = entry
	var seat: Node3D = seat_anchor(0)
	var hands: float = CockpitStation.hands()
	# THE SHARED THROTTLE IS THE FIRST LEVER IN THE ROW, not a separate thing that the row
	# then has to avoid. It was placed on its own at the hands plane and the row was started
	# a fixed notch behind it, which works only if every lever's handle sits at its own
	# origin -- and a plunger's knob is 0.15 m out toward the pilot, so the two handles ended
	# up 0.19 m apart while their origins were 0.34.
	# WHERE THE ROW RUNS, and the first slot in it.
	#
	# A shared throttle takes the front slot, at the hands plane, because it is the one lever
	# on the pedestal a hand stays on. With no shared throttle that slot is where the SEAT's
	# own throttle and crew button already are, so the row starts a notch further aft.
	var line: float = _console_line()
	var along: float = -CockpitStation.HANDS_FORWARD
	if VehicleCatalogue.shares_a_throttle(kind):
		along = _fit_console("throttle", _shared_throttle(), seat,
			Vector3(line, hands - CONSOLE_BELOW, along))
	else:
		along += CONSOLE_START
	# FLAPS AND GEAR, on the craft that has them, and nowhere else. A lever for a channel
	# the aircraft is not fitted with is a dead handle, which is worse than no handle.
	# IN A ROW FRONT TO BACK, not side by side across a corridor 0.42 m wide. Side by side
	# was what forced the whole pedestal forward: two levers need 0.32 m between them and
	# the corridor cannot give it sideways, so it was being taken out of the pilots' reach
	# instead. In a row, the gap is along the axis that has room.
	if _has_channel(Sim.Channel.FLAPS):
		var flaps := FlapsLever.new()
		flaps.name = "ConsoleFlaps"
		along = _fit_console("flaps", flaps, seat,
			Vector3(line, hands - CONSOLE_BELOW, along))
		flaps.set_gate(_range_of(Sim.Channel.FLAPS))
	# THE TRIM WHEEL IS NOT IN THIS ROW, and the reason is a measurement.
	#
	# It was, briefly. A four-lever row is three gaps of 0.34 m, so it spans a metre, and
	# centred on the shoulders that puts both ends 0.51 m fore and aft -- 0.69 m from the
	# shoulder, past a seated arm. Even at the 0.32 m the layout rule allows it is 0.67.
	# THREE IS WHAT THIS ROW HOLDS.
	#
	# So the wheel goes where a real one goes: on the side, at the pilot's hip, one per
	# seat. See CockpitStation._fit_the_trim_wheel. Two wheels on one channel is not a
	# compromise -- it is what the aeroplane has, both of them show the same trim because
	# both are drawn from the wire, and either pilot can wind it.
	if _has_channel(Sim.Channel.GEAR):
		var gear := GearLever.new()
		gear.name = "ConsoleGear"
		along = _fit_console("gear", gear, seat,
			Vector3(line, hands - CONSOLE_BELOW, along))
	# THE TANK DOORS, on the one aeroplane that has any. AFT OF EVERYTHING, level with the
	# pilots' hips, which is where a handbrake is and where this ended up for the same
	# reason: the centre line between two side-by-side seats is only 0.42 m wide, and the
	# forward half of it is taken by the flap gate, the gear lever and two crew buttons. A
	# handle standing up from the pedestal beside the seat is clear of all four, and it is
	# still the one control in this cockpit that can be found without looking -- which is
	# what it is for at fifty feet over a hillside.
	# AND THE DROP HANDLE IS THE LAST LEVER IN THE ROW, not a thing beside it.
	#
	# It was moved outboard, beside the captain, when three levers in a row put the third
	# behind the pilot's hip. That was the right diagnosis and the wrong cure: it stopped
	# being a control BOTH pilots share, which is the whole point of a console, and `water`
	# says so in as many words -- "one handle, not two".
	#
	# Centring the row is what actually fixed it. A three-lever row is 0.68 m long and the
	# problem was never its length, it was that it all hung off the back; astride the
	# shoulders it reaches from mid-thigh to just behind the hip and both ends are in reach.
	# THE HOOK, on a carrier aeroplane, beside the gear: the same "put it out" handle, banded black and yellow.
	#
	# ONLY WHERE THE AIRFRAME CAN DRAW ONE. The hook channel is fitted to both carrier aeroplanes,
	# and only `fighter_airframe.gd` has a `set_hook`: the E-2D reports the bit honestly and draws
	# nothing. Giving it the lever anyway broke `fit` on 2026-09-17 -- a fourth handle pushed the
	# Hawkeye's centred row out past a seated arm, the hook itself landing 0.69 m from the seat and
	# shoving the throttle to 0.62 m against a 0.60 m reach. A control the crew cannot touch, for a
	# hook that is not drawn, is not honest state; it is a broken cockpit, and `fit` is the suite
	# whose job is to say so.
	#
	# The CHANNEL stays fitted on purpose -- the bit is real, the wire carries it, and the arresting
	# -wire lane needs it. It is the HANDLE that waits for something to move. The day `set_hook`
	# arrives on the Hawkeye this predicate lets its lever in with no other change.
	if _has_channel(Sim.Channel.HOOK) and _the_airframe_draws_its_hook():
		var hook := HookLever.new()
		hook.name = "ConsoleHook"
		along = _fit_console("hook", hook, seat,
			Vector3(line, hands - CONSOLE_BELOW, along))
	if _has_channel(Sim.Channel.DROP):
		var doors := DropLever.new()
		doors.name = "ConsoleDrop"
		along = _fit_console("drop", doors, seat,
			Vector3(line, hands - 0.04, along))
	_centre_the_row(seat)


## One control onto the console, in the pilot's frame and then onto the centre line.
## Returns WHERE THE NEXT LEVER IN THE ROW GOES: a notch behind this one's GRIP, rather
## than a notch behind its origin.
##
## That difference is the whole reason the row kept failing the spacing rule. A lever's grip
## is not at its own origin -- a plunger's knob stands 0.15 m out toward the pilot, a flap
## gate's handle stands up and forward -- and the rule is about GRIPS, because a grip is
## where a hand goes. Spacing the origins evenly spaces the handles unevenly, and the two
## whose handles lean toward each other end up half a notch apart.
##
## So each lever is asked where its handle actually ended up and the next one starts from
## there. Nothing has to know which lever has which shape, which is the point: the next
## handle anybody adds is spaced correctly without being measured by hand.
## WHICH LINE THE PEDESTAL RUNS DOWN, in the craft's own frame.
##
## BETWEEN THE FRONT TWO SEATS where there are two abreast, which is what a pedestal is and
## what lets both pilots work it with the inboard hand.
##
## AND BESIDE THE SEAT WHERE THERE IS ONLY ONE. A tank has a single driver on the centre
## line, so "down the middle" runs the row straight through the stick he is holding -- the
## gear lever ended up 0.18 m from it, which is one hand in range of both. To the right,
## past the crew button, there is nothing, and it is the hand that is not on the stick.
## WHETHER THIS SEAT IS THE RIGHT-HAND ONE OF A PAIR ABREAST.
##
## One station scene serves every seat in a craft, so before this the copilot sat in a
## cockpit laid out for the captain: throttle on the left, crew button on the right, both
## measured from the same corner. On the right-hand seat that puts the throttle INBOARD, in
## the corridor the pedestal runs down -- which is how the flap gate came to be 0.25 m from
## a throttle knob, and why the pedestal had been shoved forward out of reach to escape it.
##
## Every two-crew cockpit ever built is symmetric about its centre line. This is the fact
## that makes it so here.
##
## A PAIR, and not merely "x is positive". A lone seat on the right of a fuselage -- a
## gunner at a door -- has nobody to be a mirror of, and flipping it would move its controls
## for no reason at all.
func _is_the_right_hand_seat(index: int) -> bool:
	var mine: Node3D = seat_anchor(index)
	if mine == null or mine.position.x <= 0.01:
		return false
	# A CRAFT WHOSE PILOTS' HANDS DO THE SAME THINGS in both seats is not reflected (`VehicleCatalogue.same_hands`).
	if VehicleCatalogue.same_hands(kind):
		return false
	for other in range(seats.size()):
		if other == index:
			continue
		var his: Node3D = seat_anchor(other)
		if his != null and his.position.x < -0.01 \
				and absf(his.position.z - mine.position.z) < 0.3:
			return true
	return false


## SLIDE THE FINISHED ROW SO IT SITS ASTRIDE THE SHOULDERS.
##
## The row is built forwards from a starting slot, so a craft with three levers on it ends
## up with the last one a good deal further aft than a craft with two -- and the last one is
## the one nobody can reach. An airliner's gear lever came out at 0.61 m for exactly this
## reason while the same lever on a light aeroplane was at 0.49.
##
## The arm is shortest to the middle of its own travel, so the cheapest fix is free: once
## the row exists, measure it and move it bodily until its middle is level with the
## shoulders. Nothing about the spacing changes -- the levers keep the gaps they were given
## -- and the worst reach in the row drops by half the row's overshoot.
##
## ONLY THE LEVERS ON THE LINE. The drop handle is outboard beside one seat and is not part
## of the row; sliding it would walk it into that seat's own throttle.
func _centre_the_row(seat: Node3D) -> void:
	var row: Array[VehicleControl] = []
	for role in ["throttle", "flaps", "gear", "hook", "drop"]:
		var lever := _console.get(role) as VehicleControl
		if lever != null:
			row.append(lever)
	if row.size() < 2:
		return
	var front: float = INF
	var back: float = -INF
	for lever in row:
		var at: float = seat.to_local(lever.grip_global()).z
		front = minf(front, at)
		back = maxf(back, at)
	# ASTRIDE THE SHOULDERS, BUT BIASED AFT, and the bias is not a fudge.
	#
	# A cockpit is judged by two different measurements and they do not want the same thing.
	# Reach is from the SHOULDER, and is happiest with the row centred on it. Whether you can
	# SEE what you are reaching for is from the EYE, which sits a head higher -- so a lever
	# in front of you is further from your eyes than the same lever the same distance behind
	# you, and the forward end of the row is what a pilot has to look down at.
	#
	# Centred exactly, the airliner's shared throttle came out at 0.81 m from the eye against
	# a bar of 0.80 that `smoke` has held since before any of this. A few centimetres aft
	# costs the back of the row almost nothing and buys the front of it that centimetre.
	var shift: float = -(front + back) * 0.5 + CONSOLE_AFT_BIAS
	for lever in row:
		lever.position.z += shift


func _console_line() -> float:
	var first: Node3D = seat_anchor(0)
	var second: Node3D = seat_anchor(1)
	if first == null:
		return 0.0
	if second != null and absf(second.position.x - first.position.x) > 0.5 			and absf(second.position.z - first.position.z) < 0.3:
		# A CRAFT WHOSE PILOTS' HANDS DO THE SAME THINGS (`VehicleCatalogue.same_hands`, the V-22) has no room for the row
		# down the middle: the pilot's thrust lever and the tilt lever beside it are under his LEFT hand, 0.21 m from the
		# middle, and `tests/fit.gd` found them within a hand of the flaps and the gear there. Moved 0.25 m towards the
		# copilot the row was 0.70 m from the pilot's shoulder, past an easy reach, and 0.31 m from the copilot's stick.
		# So it runs down the pilot's right, as it does beside a lone seat.
		if VehicleCatalogue.same_hands(kind):
			return first.position.x + CONSOLE_ASIDE
		return (first.position.x + second.position.x) * 0.5
	return first.position.x + CONSOLE_ASIDE


func _fit_console(role: String, control: VehicleControl, seat: Node3D,
		where: Vector3) -> float:
	control.position = seat.transform * where
	control.position.x = where.x
	add_child(control)
	control.setup(0)
	_console[role] = control
	return seat.to_local(control.grip_global()).z + CONSOLE_NOTCH


## Whether this kind's bus carries a channel at all, and how far it goes. Off craft_schema,
## so an aeroplane with a four-notch gate and one with two get the gate they actually have.
func _has_channel(channel: int) -> bool:
	return _range_of(channel) > 0


## CAN THE CRAFT ACTUALLY MOVE A HOOK? Asked of the installed visual scene by method rather
## than by kind, so an airframe opts in by growing a `set_hook` and nothing here is edited.
## `_fighter` is not the question -- that is one type, and the next carrier aeroplane will be
## another. See the console row, where this decides whether the handle is built.
func _the_airframe_draws_its_hook() -> bool:
	return _visual_scene != null and _visual_scene.has_method("set_hook")


func _range_of(channel: int) -> int:
	for entry in _fitted:
		if int((entry as Dictionary).get("channel", -1)) == channel:
			return int((entry as Dictionary).get("range", 0))
	return 0


## THE TOP OF A CHANNEL'S TRAVEL ON THIS CRAFT, or 0 on one that is not fitted with it.
##
## Public because a hand binding that steps a lever has to know where the lever stops, and
## where it stops is a fact about the aircraft: the same thumb button gives four notches of
## flap on an airliner and one on a gunship, because that is what those two aeroplanes have.
## See Bind.step.
func channel_range(channel: int) -> int:
	return _range_of(channel)


## WHAT THIS CRAFT CALLS EACH FITTED CHANNEL. The enum says "gear" everywhere; the bus
## says "ramp" on a Chinook, "handbrake" in a car and "parking brake" in a tank. Anything
## a player reads uses the craft's word from the schema that decides whether it exists.
func channel_names() -> Dictionary:
	var names: Dictionary = {}
	for entry in _fitted:
		var row := entry as Dictionary
		names[int(row.get("channel", -1))] = String(row.get("name", ""))
	return names


## WHERE A CHANNEL IS NOW, in the same units a command is sent in. -1 if this craft is not
## fitted with it, or if it is a channel with nothing to read.
##
## OFF THE WIRE, like everything else shared. A thumb button that stepped a lever from a
## number this machine had remembered would drift away from the copilot's the first time
## they touched it, and both crew would be certain the flaps were somewhere else.
##
## THE BUS IS TWO COMPONENTS AND THAT IS DELIBERATE -- see cockpit_components.hpp. What the
## aeroplane is FLOWN by rolls back; what is merely switched in the cockpit does not, and
## paying a physics resimulation for a display page would be absurd. Nothing outside this
## function should have to know which half a channel lives in.
func channel_value(channel: int) -> int:
	var top: int = _range_of(channel)
	if top <= 0:
		return -1
	if Sim.client == null:
		return -1
	var bus: Dictionary = Sim.client.craft_controls(entity)
	var systems: Dictionary = Sim.client.craft_systems(entity)
	match channel:
		Sim.Channel.THROTTLE:
			return _scaled(bus.get("throttle", 0.0), top)
		Sim.Channel.FLAPS:
			return _scaled(bus.get("flaps", 0.0), top)
		Sim.Channel.TILT:
			return _scaled(bus.get("tilt", 0.0), top)
		# NOSE TRIM IS THE ONE THAT IS NOT 0 TO 1. It runs -1 to 1, because trim has a
		# neutral in the middle and the other levers have theirs at one end, so the channel
		# has to be folded onto its travel rather than multiplied by it.
		Sim.Channel.TRIM:
			return _scaled((float(bus.get("trim", 0.0)) + 1.0) * 0.5, top)
		Sim.Channel.GEAR:
			return 1 if bool(bus.get("gear", false)) else 0
		Sim.Channel.HOOK:
			return 1 if bool(bus.get("hook", false)) else 0
		Sim.Channel.SPOILERS:
			return 1 if bool(bus.get("spoilers", false)) else 0
		Sim.Channel.WEAPON:
			return clampi(int(systems.get("weapon", 0)), 0, top)
		Sim.Channel.RADIO:
			return clampi(int(systems.get("radio", 0)), 0, top)
		Sim.Channel.DISPLAY:
			return clampi(int(systems.get("display", 0)), 0, top)
		Sim.Channel.MODE:
			return clampi(int(systems.get("mode", 0)), 0, top)
		Sim.Channel.LIGHTS:
			return 1 if bool(systems.get("lights", false)) else 0
		Sim.Channel.MASTER:
			return 1 if bool(systems.get("master", false)) else 0
		# THE WING SWEEP HANDLES SHOW THE COMMAND, not where the wings have got to: a handle is where a hand put it.
		Sim.Channel.SWEEP:
			return clampi(int(systems.get("sweep_command", 0)), 0, top)
	# A GENERIC CHANNEL, past the named ones (busbits, 2026-09-18): whatever the craft's pages hold, 0 where none is
	# set. Asked once a physics frame per craft and kept, because a panel of five hundred switches asks five hundred
	# times a frame.
	if channel >= int(Sim.bus_limits().get("first_generic_channel", 1 << 30)):
		return clampi(int(_generic_values().get(channel, 0)), 0, top)
	# CREW_TOGGLE lands here, and rightly: it is a press and not a position, so there is
	# nothing to step from and a binding that tried would be stepping from a fiction.
	return -1


## This physics frame's `{channel: value}` for the craft's generic channels, from `CockpitWorld.bus_values`.
var _generic_cache: Dictionary = {}
var _generic_frame: int = -1

func _generic_values() -> Dictionary:
	if _generic_frame != Engine.get_physics_frames():
		_generic_frame = Engine.get_physics_frames()
		_generic_cache = Sim.client.bus_values(entity) if Sim.client != null else {}
	return _generic_cache


func _scaled(fraction: Variant, top: int) -> int:
	return clampi(int(round(clampf(float(fraction), 0.0, 1.0) * float(top))), 0, top)


## ---- what this machine has asked of the craft ------------------------------------------
##
## A PRESS PROPOSES; THE CRAFT DECIDES. A hand on a switch, a thumb button stepping a selector, a
## key on the desk -- none of them move anything. They ask, the server applies what it will
## (`apply_command` refuses a channel the craft is not fitted with, and a physical channel from a
## seat that does not fly), and every seat aboard draws what came back.
##
## What this machine asked is SHOWN while the answer is on its way, and no longer. Drawing only
## the answer would put a flicked switch back where it was for a round trip and then throw it
## again; drawing only the ask would leave a refused switch thrown for ever. So the ask is shown
## until the craft agrees with it or the grace runs out, and then the craft wins -- which is how a
## refused press snaps back.

## HOW LONG AN UNANSWERED ASK IS SHOWN, in seconds, on top of however far behind this machine draws
## the craft. A command is answered in the tick after it lands; a round trip on a bad link is a
## few tenths. Half a second more than the buffer is a snap-back that is quick to see and slower
## than any answer that is coming.
const PROPOSAL_GRACE: float = 0.5

## channel -> [the value asked for, the physics frame after which it is given up].
var _proposed: Dictionary = {}


## ASK THE CRAFT FOR A CHANNEL, and show the ask until it answers. See above.
func propose(channel: int, value: int) -> void:
	Sim.send_command(channel, value)
	var ticks: int = int(ceil((PROPOSAL_GRACE + Sim.drawing_late())
		* float(Engine.physics_ticks_per_second)))
	_proposed[channel] = [value, Engine.get_physics_frames() + ticks]


## WHERE A CHANNEL SHOULD BE DRAWN: this machine's unanswered ask, else where the craft says it is.
## -1 for a channel the craft is not fitted with, exactly as `channel_value`.
##
## ON PHYSICS FRAMES AND NOT THE WALL CLOCK, so a suite at `--fixed-fps` gives an ask the same
## number of ticks to be answered as a player does.
func shown_value(channel: int) -> int:
	var craft: int = channel_value(channel)
	if not _proposed.has(channel):
		return craft
	var asked: Array = _proposed[channel]
	if int(asked[0]) == craft or Engine.get_physics_frames() > int(asked[1]):
		_proposed.erase(channel)
		return craft
	return int(asked[0])


## The one throttle quadrant an airliner has, built once and handed to every seat that can
## reach it. It sits on the vehicle rather than in anybody's seat: two pilots share it.
func _shared_throttle() -> VehicleControl:
	if _pedestal != null:
		return _pedestal
	# A QUADRANT LEVER or a PLUNGER through the panel, which is the difference between an
	# airliner's centre console and a light aeroplane's instrument panel.
	_pedestal = PlungerThrottle.new() if VehicleCatalogue.has_a_plunger(kind) \
		else ThrottleLever.new()
	_pedestal.name = "CentreThrottle"
	# Between the seats, at the same height and the same distance forward as everything
	# else -- so it is an arm's length from BOTH of them and not out in the middle of the
	# flight deck. The airliner's front seats sit at +/- 0.42 for exactly this reason: a
	# control two people share has to be inside two people's reach.
	# Placed in the PILOT'S frame and then moved onto the centre line, because a seat
	# anchor is not at the vehicle's origin: this seat sits 0.30 m below it and 5.60 m
	# forward, so a pedestal put at hand height in VEHICLE space would float a third of a
	# metre above the crew's hands.
	return _pedestal


func man(crew: Array, mine: int) -> void:
	# EVERY SEAT IN A MANNED CRAFT, and none at all in an empty one.
	#
	# Not just the occupied seats: a copilot's yoke moving is half the reason the linkage is
	# on the wire, and an empty seat beside you with no controls in it is a seat you cannot
	# see somebody arrive at. The saving is the hundred and thirty machines nobody is in,
	# not the three empty seats in the one somebody is.
	var wanted: Dictionary = {}
	if not crew.is_empty():
		for seat in range(seats.size()):
			wanted[seat] = true
	# Gone: anybody who got out.
	for seat in _stations.keys():
		if not wanted.has(seat):
			(_stations[seat] as Node3D).queue_free()
			_stations.erase(seat)
	if _stations.is_empty() and not _console.is_empty():
		for control in _console.values():
			(control as Node3D).queue_free()
		_console.clear()
		_pedestal = null
	# Arrived: anybody who sat down. THIS MACHINE'S SEAT FIRST, then the seats somebody is in, then the empty ones, and
	# under a budget no more than `station_build_budget_ms` of it a frame: see that for why.
	var order: Array = []
	if wanted.has(mine):
		order.append(mine)
	for seat in crew:
		if wanted.has(seat) and not order.has(seat):
			order.append(seat)
	for seat in wanted:
		if not order.has(seat):
			order.append(seat)
	var began: int = Time.get_ticks_usec()
	var built_this_frame: int = 0
	for seat in order:
		if _stations.has(seat) or seat >= seats.size():
			continue
		if station_build_budget_ms > 0.0 and built_this_frame > 0 and float(Time.get_ticks_usec() - began) / 1000.0 >= station_build_budget_ms:
			break
		built_this_frame += 1
		var built := AuthoredCraftPackages.make_station(kind, seat)
		var station := built.get("station") as CockpitStation
		if station == null:
			push_warning("[cockpit] %s seat %d package refused (%s); using legacy scene" % [
				Sim.kind_name(kind), seat, built.get("error", "could not build")])
			station = VehicleCatalogue.seat_scene(kind).instantiate() as CockpitStation
		seats[seat].add_child(station)
		# WHETHER THIS SEAT FLIES, which only the vehicle knows: the same station scene is
		# used by the pilot and by the gunner, and it is the simulation's seat table that
		# says which is which. A seat that does not fly gets multi-function displays.
		if built.get("station") == null:
			station.fit(seat, _seat_flies(seat), kind, _is_the_right_hand_seat(seat))
		_stations[seat] = station
	# GHOSTED FOR WHOEVER IS INSIDE IT, and painted for everybody looking at it.
	_show_body(mine >= 0)
	# The board in every station, once anybody can read one.
	if not _stations.is_empty():
		var roster: Array = crew()
		for station in stations():
			(station as CockpitStation).show_crew(roster)
	# THE CENTRE CONSOLE, which belongs to the VEHICLE and not to a seat. Built only once
	# somebody is aboard to reach it, like everything else in here.
	if not _stations.is_empty():
		_build_console()
		_match_lamps_to_the_wire(mine)
	# AND IT MAKES A NOISE while there is somebody in it, for the same reason the stations
	# are built here and not at startup: a hundred and forty machines nobody is in would be
	# a hundred and forty ring buffers being filled for nobody. A crewed craft is one
	# somebody is either flying or flying near, and both of those are worth hearing.
	if _stations.is_empty():
		if sound != null:
			sound.queue_free()
			sound = null
	elif sound == null:
		sound = VehicleSound.new()
		sound.name = "Sound"
		add_child(sound)
		sound.setup(kind)


## A SIGNAL LAMP AT EVERY OTHER SEAT WHOSE CHANNEL SAYS IT HAS ONE, and none at a seat whose channel says it has not.
## Every frame the craft is manned, from `man`.
##
## THE LAMP IS A PART NOW, placed off the BUILD tab (lane/lampopt, 2026-09-19); until then this holstered one at every
## seat of every craft. What a player places goes into their own layout on their own machine, and nothing sends a layout
## made in flight anywhere, so the wire's `SignalLamp.FITTED` bit is how this machine hears of it. `mine` is left alone:
## this machine's own seat is the rig's to fit and to announce (`PilotRig._say_whether_i_have_a_lamp`).
##
## AND IT TAKES AWAY A LAMP THE WIRE DOES NOT HAVE, which is how a lamp in this machine's own saved layout stays out of
## another player's cockpit: `AuthoredCraftPackages.make_station` applies the player's saved layout to that seat in every
## craft of the kind, and a lamp is what another player sees them signal with.
func _match_lamps_to_the_wire(mine: int) -> void:
	for seat in _stations:
		if int(seat) == mine:
			continue
		var station := _stations[seat] as CockpitStation
		var channel: int = SignalLamp.channel_for(int(seat))
		if station == null or channel < 0:
			continue
		var lamp: SignalLamp = SignalLamp.in_station(station)
		var fitted: bool = SignalLamp.is_fitted_value(shown_value(channel))
		if fitted and lamp == null:
			holster_a_lamp(int(seat))
		elif not fitted and lamp != null and not lamp.is_queued_for_deletion():
			station.remove_child(lamp)
			lamp.queue_free()


## PUT A SIGNAL LAMP IN A HOLSTER AT `seat`, clear of every grip in the craft: the other seats' controls, the console's
## and the other lamps. That is `tests/fit.gd`'s rule, measured in the station's own frame. Asked for by the rig when its
## player places one off the parts bin, and by `_match_lamps_to_the_wire` when another seat's channel says it has one.
## Null for a seat with no station. Returns the lamp already there, if there is one.
func holster_a_lamp(seat: int) -> SignalLamp:
	var station := _stations.get(seat) as CockpitStation
	if station == null:
		return null
	var already: SignalLamp = SignalLamp.in_station(station)
	if already != null:
		return already
	var others: Array[Vector3] = []
	var mine := station.global_transform.affine_inverse() if station.is_inside_tree() else Transform3D.IDENTITY
	var every: Array = []
	for other_seat in _stations:
		every.append_array((_stations[other_seat] as CockpitStation).controls().values())
		var lamp: SignalLamp = SignalLamp.in_station(_stations[other_seat] as Node)
		if lamp != null and not every.has(lamp):
			every.append(lamp)
	every.append_array(_console.values())
	for control_any in every:
		var control := control_any as VehicleControl
		if control == null or not control.is_inside_tree() or not station.is_inside_tree():
			continue
		others.append(mine * control.grip_global())
	# INSIDE THE SKIN where the airframe can say (lane/sailplane, 2026-09-19): see `holster_fits`.
	return SignalLamp.holster_in(station, seat, others, holster_fits(station, seat))


## WHETHER A BOX IN `station`'s FRAME IS INSIDE THIS CRAFT'S DRAWN SKIN, for the holster search, where the airframe can
## say (`encloses`, asked by method name, as `cabin_room` is): the Duo Discus, the V-22 and the A-10C, each from the same
## sections it is drawn from.
## An invalid Callable where it cannot, and the search is today's. The search asks only when its first spot fails.
##
## NOT ASKED OF A CRAFT'S TRIANGLES. That was built and measured (2026-09-19): rays from the lamp's corners against
## the drawn skin near each station cost 150 ms to 5 s a view -- every craft paid to gather its skin, and a craft whose
## first spot failed sent the search through thousands of fenced spots. A view is built at every spawn. An airframe
## answers from its own sections in microseconds.
##
## AND NOT BEHIND A CHAIR'S BACK, where the chair hides it from the eye: a room fence tried first put the F-14's holster
## 0.21 m aft of the eye, behind its Mk 14 (`tests/pilot_seat.gd`, 2026-09-19). A seat with no chair may holster beside the
## hip a little aft, which in the Duo's cockpit is the one place clear of the stick and the back seat's pedals.
func holster_fits(station: Node3D, seat: int = -1) -> Callable:
	if not station.is_inside_tree():
		return Callable()
	var chaired: bool = seat >= 0 and seat < seats.size() and seats[seat].get_node_or_null("Chair") != null
	for airframe in [_visual_scene, _hawkeye, _rotorcraft, _tomcat, _savoia, _falcon, _sailplane, _prowler, _osprey, _jetliner,
			_warthog, _warbird]:
		if airframe != null and (airframe as Object).has_method("encloses"):
			var into: Transform3D = global_transform.affine_inverse() * station.global_transform
			var asked: Object = airframe
			return func(box: AABB) -> bool:
				if chaired and box.get_center().z > SignalLamp.HOLSTER_FROM.z:
					return false
				var craft := AABB(into * box.get_endpoint(0), Vector3.ZERO)
				for corner in range(1, 8):
					craft = craft.expand(into * box.get_endpoint(corner))
				return bool(asked.call("encloses", craft))
	return Callable()


## The one control a craft's crew SHARE rather than each having their own. Only the
## airliner has one, and it is on the VEHICLE and not in any station -- which is the point
## of it.
func shared_throttle() -> VehicleControl:
	return _pedestal


## NOBODY IS MOVING ANYTHING ABOARD. -1, and NOT the simulation's own 7 -- see `hands_on`.
##
## Here and not on PilotRig, because it is a fact about the craft and the rig is a thing that reaches
## for the craft. Nothing a cockpit reaches for may reach back.
const NOBODY_FLYING: int = -1


## WHICH SEAT IS MOVING ANYTHING ABOARD THIS CRAFT, or `NOBODY_FLYING`.
##
## `CrewControls.hands_on`, straight off the cabin, and the simulation is the only thing that can
## answer it: the hands that matter are on other machines. Asked once a frame by the rig, which
## must not centre a control the linkage is holding over -- see `PilotRig._the_linkage_is_at_rest`.
##
## ANYTHING THAT IS NOT A SEAT OF THIS CRAFT IS NOBODY, and that is not defensive padding. The
## simulation wrote 255 for nobody and the WIRE CARRIES THREE BITS -- `SyncComponentTraits
## <CrewControls>::serialize` does `hands_on & 0x7u` -- so 255 arrived everywhere as **7**. Measured
## 2026-09-15 with an empty cockpit: `crew_controls()` returned `hands_on: 7`. Since 2026-09-16 the
## simulation's nobody IS 7 (`kNobodyHandsOn`), the same on the server and off the wire; a check here
## against a range of seats rather than against that number stays right whatever the field becomes.
func hands_on() -> int:
	if Sim.client == null:
		return NOBODY_FLYING
	var seat: int = int((Sim.client.crew_controls(entity) as Dictionary).get("hands_on", 255))
	return seat if seat >= 0 and seat < seats.size() else NOBODY_FLYING


## THE BODY, SEEN FROM INSIDE IT.
##
## A pilot sits WITHIN the hull -- twenty-six metres of it on the airliner, with three and a
## half still ahead of the windscreen -- and an aircraft is a box you are looking out of
## rather than at. From inside, a solid fuselage is a wall between the eye and the horizon,
## between the eye and the controls, and, worst of all, an interior whose only visible
## feature is the big end behind you. That last one is why an aeroplane pointing exactly
## along its own velocity vector can still feel as though it is flying backwards.
##
## So when the player at this machine is aboard, the airframe is TAKEN AWAY. Everybody
## else's aircraft keeps its paint, because they are being looked AT.
##
## HIDDEN, NOT FADED, and the difference is the whole of this note.
##
## It used to be drawn at 18% alpha, which reads well in a screenshot and flickers in a
## headset. An airframe here is thirty-odd overlapping boxes, and alpha-blended geometry is
## sorted PER OBJECT with no depth written between them, so which box wins in front of which
## is decided afresh every frame from the distance to each one's origin. Sitting inside the
## hull puts most of them at nearly the same distance and several of them behind the eye, so
## the order is not merely arbitrary, it CHANGES -- and in stereo each eye can settle on a
## different one. That is the flicker.
##
## Zero alpha does not fix it. A transparent surface at zero is still submitted, still
## sorted and still blended; it just contributes nothing. `visible` is what actually takes
## the geometry out of the frame, and it costs less than drawing it did.
##
## The alpha is kept as a number rather than deleted because it is the thing to turn back
## up if a ghosted outline is ever wanted again -- at anything above zero the old blended
## path returns, flicker and all.
const GHOST_ALPHA: float = 0.0


func _show_body(ghosted: bool) -> void:
	if ghosted == _ghosted or _paint == null:
		return
	_ghosted = ghosted
	var skin := StandardMaterial3D.new()
	skin.albedo_color = _paint.albedo_color
	skin.roughness = _paint.roughness
	if ghosted:
		skin.albedo_color.a = GHOST_ALPHA
		skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# NO SHADOW off a body you are inside: a fuselage casting one onto its own console
		# puts the cockpit in the dark for the one person who has to read it.
		skin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# A CRAFT YOU CAN SEE OUT OF IS NOT TAKEN AWAY. That is the whole point of cutting
	# windows in it: the nose ahead of the windscreen and the posts against the horizon are
	# what a pilot flies by, and hiding them was only ever the answer to a solid box.
	#
	# A kind still drawn as one box keeps the old behaviour, because a box is a box. They
	# convert one at a time and this is the line that says which.
	var gone: bool = ghosted and GHOST_ALPHA <= 0.0 \
		and VehicleCatalogue.glazing(kind).is_empty()
	# THE HAWKEYE'S AIRFRAME IS HIDDEN, never repainted: its colour is in its vertices.
	if _hawkeye != null:
		_hawkeye.visible = not gone
	if _visual_scene != null:
		_visual_scene.visible = not gone
	for part in _body:
		var mesh := part as MeshInstance3D
		if mesh != null:
			mesh.material_override = skin
			# UNDER A VISUAL SCENE THE PROCEDURAL SKIN STAYS HIDDEN, boarded or not: the scene is the skin.
			mesh.visible = not gone and _visual_scene == null
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if ghosted \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## DRAWN AS A WRECK (lane/combat): the craft was destroyed, and what is left of it is the fireball and the pieces, not
## the airframe. Everything this view draws is hidden EXCEPT a branch holding this machine's own rig -- a rider is a
## child of its seat, and hiding the seat would take the player's camera and hands with it. Their cockpit stays until
## the respawn moves them; the airframe round it goes. Once: a wreck is never repaired.
var wrecked: bool = false


func show_wrecked() -> void:
	if wrecked:
		return
	wrecked = true
	for child in get_children():
		var node := child as Node3D
		if node == null:
			continue
		if not node.find_children("*", "PilotRig", true, false).is_empty():
			continue
		node.visible = false
	if sound != null:
		sound.set_tone(0.0, 0.0)


## Whether anybody is sitting in this craft at all, which is the only reason it has controls.
func is_manned() -> bool:
	return not _stations.is_empty()


## Every control in this craft, by seat -- or nothing, if that seat is empty and therefore
## has no controls in front of it.
##
## ROLE TO CONTROL, AND NOTHING ELSE IN IT. This used to carry the seat index under "seat"
## as well, which made the set a map of controls with one integer hidden in it: anything
## that walked the values and cast them to a VehicleControl -- the obvious thing to do with
## a map of controls -- got a script error on that one key, and the only defence was a
## hand-written list of the roles worth looking at. A stale list of that kind is how the
## gunner's trigger came to be unreachable. The caller passed the seat index in; it does not
## need it handed back.
func controls_for(index: int) -> Dictionary:
	var station := _stations.get(index) as CockpitStation
	if station == null:
		return {}
	var out: Dictionary = station.controls()
	# THE CONSOLE, spliced into every seat. Nothing on it belongs to any of them, which is
	# the point of it: one throttle between two pilots, one flap gate, one gear lever. A
	# console control therefore appears in every seat's set and is the SAME node each time,
	# which is what makes both pilots' hands land on the one handle.
	for role in _console:
		var shared: VehicleControl = _console[role] as VehicleControl
		# AND ONLY TO A SEAT THAT CAN GET TO IT.
		#
		# "Spliced into every seat" was taken literally, and every seat includes the three
		# gun positions down the back of a gunship. Seat 3 was being offered a gear lever
		# NINETEEN METRES away: in its set, in `_reachable`, measured by every layout check
		# as a control of that seat, and of course never once grabbed.
		#
		# It is not a rendering problem or a tidiness problem. `PilotRig._nearest_to` walks
		# everything within reach and a lever nineteen metres off is simply never nearest,
		# so nothing ever went wrong -- which is exactly why it survived. What it broke was
		# the ability to MEASURE a cockpit: a reach check over these sets reported dozens of
		# controls out of reach that were never that seat's business in the first place.
		if shared != null and not _can_reach(index, shared):
			continue
		out[role] = _console[role]
	return out


## WHETHER THE OCCUPANT OF A SEAT COULD PUT A HAND ON A SHARED CONTROL.
##
## Generous on purpose: this is not the reach check, it is the question of whether the
## control belongs to this seat AT ALL. A pilot and a copilot both own the pedestal between
## them even if one of them has to lean; a gunner four metres aft owns none of it.
##
## Measured from the seat anchor to the grip, which is where `_and_every_one_of_them_is_
## within_reach` measures from, so the two agree about what a seat is responsible for.
func _can_reach(index: int, control: VehicleControl) -> bool:
	var anchor: Node3D = seat_anchor(index)
	if anchor == null:
		return false
	return anchor.to_local(control.grip_global()).length() < CONSOLE_OWNED


## EVERY STATION IN THIS CRAFT, found rather than remembered.
##
## Asked of the scene tree instead of read out of the dictionary that put them there, and
## that is the point: anything a station scene contains, anything that adds one, and
## anything that adds a whole extra crew position later all turn up here without a second
## list to keep in step. A hand-written roster is a roster that goes stale.
func stations() -> Array[Node]:
	# "*" and not "": an empty pattern matches NOTHING, so the roster came back empty and
	# every craft looked unmanned.
	return find_children("*", "CockpitStation", true, false)


## THE STATION IN FRONT OF ONE SEAT, or null if nobody is in it.
##
## Asked of the same dictionary `controls_for` reads, because it is the same question one
## step earlier: that returns the controls, and this returns the thing they are bolted to.
## The cockpit builder needs the latter -- a control it is adding has to be parented to the
## seat anchor's station, or it hangs in the world and does not move with the aeroplane.
func station_for(index: int) -> CockpitStation:
	return _stations.get(index) as CockpitStation


## THROW ONE SEAT'S STATION AWAY, so the next `man` builds it again from the scene.
##
## What RESET on the cockpit builder does. A layout is applied while a station is being
## fitted -- see `CockpitStation.fit` -- so undoing one is not a matter of moving the levers
## back: the file has to go, and then the station has to be built again without it.
##
## `man` runs off the world's state every update and rebuilds whatever is missing, so this
## only has to make it missing.
func rebuild_station(index: int) -> void:
	var station := _stations.get(index) as Node3D
	if station == null:
		return
	station.queue_free()
	_stations.erase(index)


## Which seats have a station in them, in seat order.
func manned_seats() -> Array:
	var out: Array = []
	for station in stations():
		out.append((station as CockpitStation).seat)
	out.sort()
	return out


## WHAT EVERY SCREEN IN THIS CRAFT IS SHOWING, and the only place any of them gets it.
##
## Assembled ONCE per craft and handed to every station, so the copilot's airspeed and the
## pilot's are the same number from the same place rather than two instruments each asking
## their own machine and each getting an answer a round trip apart. Every argument about
## which panel is right disappears if neither of them can have an opinion.
##
## All of it comes off state that is already replicated to everybody aboard. A screen that
## wants something not in here is a gap in what the craft SHARES, and the fix is to share
## it -- not to let one panel reach around the back and ask.
func craft_state() -> Dictionary:
	var state: Dictionary = Sim.current.get(entity, {})
	var bus: Dictionary = Sim.client.craft_controls(entity)
	var motion: Vector3 = state.get("velocity", Vector3.ZERO)
	var at: Vector3 = state.get("position", Vector3.ZERO)
	var facing := Basis(state.get("basis", Quaternion()) as Quaternion)
	var nose: Vector3 = -facing.z
	var out: Dictionary = {
		"name": String(Sim.geometry_of(kind).get("name", "?")),
		"airspeed": motion.length(),
		"altitude": at.y,
		# A compass bearing: 0 along -Z and increasing to the right, the same convention
		# every bug and every autopilot in the game uses.
		"heading": fposmod(rad_to_deg(atan2(nose.x, -nose.z)), 360.0),
		"throttle": float(bus.get("throttle", 0.0)) * 100.0,
	}
	if bus.has("tilt"):
		out["tilt"] = float(bus["tilt"]) * 100.0

	# WHICH ROUND EACH GUN IS LOADED WITH, in the words its own gunner's sight shows.
	#
	# ONE PER MOUNT, because a craft's guns are not all one gun: a Chinook's ramp gun is
	# mount 1 and there is nothing at all on mount 0, so the single name this used to
	# publish -- taken off mount 0 and shown to every gunner aboard -- named a gun that is
	# not fitted. Every sight asks for its own.
	#
	# AND ONLY A GUN WITH A READY RACK READS THE SELECTOR. `weapon` is a bus channel that
	# means something different on every craft that carries one -- which gun is HOT on a
	# gunship -- so a gun with a belt in it says what is on the belt. See `Gun::rack`.
	var names: Array = []
	for mount in range(MAX_TURRETS):
		var gun: Dictionary = Sim.gun_of(kind, mount)
		var rounds: Array = gun.get("rounds", [])
		var chosen: int = int(gun.get("ammo", 0))
		if bool(gun.get("rack", false)):
			chosen = clampi(int(bus.get("weapon", chosen)), 0, maxi(rounds.size() - 1, 0))
		names.append(String((rounds[chosen] as Dictionary).get("name", "gun"))
			if bool(gun.get("fitted", false)) and chosen < rounds.size() else "no gun")
	out["ammo_names"] = names

	# WHAT IS IN THE TANK, on the one aeroplane that has one, and whether it is going out or
	# coming in. Absent everywhere else rather than zero: a gauge reading empty on a craft
	# with no tank is a gauge saying something false.
	var carried: float = Sim.tank_load(entity)
	if carried >= 0.0:
		out["tank"] = carried
		out["dropping"] = bool(bus.get("drop", false))
		out["scooping"] = Sim.is_scooping(entity)

	# ---- and everything an MFD needs -------------------------------------------------
	#
	# A page is handed its data and draws it: anything a page wants that is not in here is
	# a gap in what the craft SHARES, and the fix is to share it rather than to let one
	# screen reach around the back and get its own answer. So the whole of it is published
	# once, here, and every seat reads the same numbers.
	out["pitch"] = rad_to_deg(asin(clampf(nose.y, -1.0, 1.0)))
	out["bank"] = rad_to_deg(asin(clampf(-facing.x.y, -1.0, 1.0)))
	out["climb"] = motion.y
	# HOW FAST THE AIR ITSELF IS GOING UP HERE, which is a different number from the
	# climb rate and the one a glider is actually flown by: the variometer says what the
	# aeroplane is doing and this says whether the air is paying for it.
	out["lift"] = Sim.rising(at)
	out["position"] = at
	var systems: Dictionary = Sim.client.craft_systems(entity)
	for key in ["weapon", "radio", "display", "mode", "master", "crew_light", "lights"]:
		if systems.has(key):
			out[key] = systems[key]
	for key in ["flaps", "trim", "gear", "spoilers"]:
		if bus.has(key):
			out[key] = bus[key]
	out["turrets"] = systems.get("turrets", [])
	# THE MISSILES: which pylons still carry one, and every seat's lock on this aircraft. See LockSight, which is handed
	# its own seat's row of these and draws it.
	out["stores"] = int(systems.get("stores", 0))
	# AND WHAT THE GUN ON THE SELECTOR HAS LEFT, -1 for a gun with no count (`CockpitWorld.gun_rounds`).
	out["gun_rounds"] = int(Sim.client.gun_rounds(entity)) if Sim.client.has_method("gun_rounds") else -1
	out["locks"] = Sim.locks_for(entity)
	var linkage: Dictionary = Sim.client.crew_controls(entity)
	out["stick"] = linkage.get("linked_stick", Vector2.ZERO)
	out["rudder"] = float(linkage.get("linked_rudder", 0.0))
	out["hands_on"] = linkage.get("hands_on", 0)
	# WHERE IT IS BEING TAKEN, when something is taking it. An autopilot publishes a route
	# and a hand-flown craft does not, so this is a page that shows dashes rather than a
	# page that shows zero.
	if bool(state.get("has_route", false)):
		var to: Vector3 = state.get("route", Vector3.ZERO)
		var away := Vector2(to.x - at.x, to.z - at.z)
		out["route_range"] = away.length()
		out["route_bearing"] = fposmod(rad_to_deg(atan2(away.x, -away.y)), 360.0)
	out["contacts"] = _contacts_near(at, nose)
	# WHICH CHANNELS THIS CRAFT ACTUALLY HAS, so a page can offer a switch for the things
	# that exist and nothing else. A gunboat has a radio and a hover hold; an aeroplane has
	# flaps, gear, spoilers and a master arm. A screen offering all of them everywhere is a
	# screen with dead switches on it.
	out["fitted"] = _fitted
	return out


## THE NEAREST HANDFUL OF OTHER CRAFT, as bearing, range and what they are.
##
## What an EW page and a situation display are both made of, and neither of them can be made
## of anything else: a gunner who cannot see out of the side they are not facing has no other
## way of knowing there is something there.
##
## Capped, and sorted by range. There are a hundred and sixty machines in the world and a
## screen has room for eight; the eight that matter are the close ones.
const CONTACT_RANGE: float = 20000.0
const CONTACTS_SHOWN: int = 8


func _contacts_near(at: Vector3, nose: Vector3) -> Array:
	var seen: Array = []
	for other in Sim.current:
		if int(other) == entity:
			continue
		var they: Dictionary = Sim.current[other]
		var there: Vector3 = they.get("position", Vector3.ZERO)
		var away := Vector2(there.x - at.x, there.z - at.z)
		var range_to: float = away.length()
		if range_to > CONTACT_RANGE:
			continue
		seen.append({
			"kind": int(they.get("kind", -1)),
			"range": range_to,
			# RELATIVE to the nose, because a bearing on a screen in a cockpit is where to
			# look, and where to look is measured from where you are already facing.
			"bearing": fposmod(rad_to_deg(atan2(away.x, -away.y))
				- rad_to_deg(atan2(nose.x, -nose.z)), 360.0),
			"height": there.y - at.y,
		})
	seen.sort_custom(func(a, b): return float(a["range"]) < float(b["range"]))
	return seen.slice(0, CONTACTS_SHOWN)


## WHO IS IN WHAT SEAT: one row per seat, occupied or not, with the station it is.
##
## The empty seats are the interesting half. A crew of four spread through a fuselage cannot
## see each other, and what a pilot needs to know before pressing the seat button is which
## seats this craft HAS and which of them are free.
func crew() -> Array:
	var out: Array = []
	var poses: Array = Sim.geometry_of(kind).get("seat_poses", [])
	# NOBODY IS IN IT when there is no world -- which is the case in the editor, where a
	# craft scene is opened to look at rather than to fly. The shape is a fact about the
	# kind and comes back either way; who is sitting in it is a fact about a running game.
	var occupant: Array = Sim.client.vehicle_seats(entity) if Sim.client != null else []
	var mine: int = Sim.local_client_id() if Sim.client != null else 0
	for i in range(poses.size()):
		var who: int = int(occupant[i]) if i < occupant.size() else -1
		out.append({
			"seat": i,
			"station": String((poses[i] as Dictionary).get("station", "?")),
			"client": who if who >= 0 else 0,
			"mine": who == mine and mine != 0,
		})
	return out


func seat_anchor(index: int) -> Node3D:
	if index < 0 or index >= seats.size():
		return self
	return seats[index]


## HOW FAR AWAY A CRAFT HAS TO BE before it is worth drawing a box round it. Closer than
## this you can see the aeroplane, and a box round something you can already see is in the
## way rather than helpful.
const SPOT_FROM: float = 500.0
## How much of your view the box fills, as a fraction of the distance to it. A box drawn at
## the craft's real size is a box you cannot see either, because the whole difficulty is
## that the craft is a few pixels across -- so it holds a constant ANGLE instead, about a
## degree, and grows with range the way a gunsight reticle does.
const SPOT_ANGLE: float = 0.018

var _spot: MeshInstance3D = null


## PUT A BOX ROUND IT, or take one away. `from` is where the eye is, in world space.
##
## Drawn as twelve edges rather than a transparent cube: a face, however faint, hides what
## it is pointing at, and what it is pointing at is three pixels of aeroplane.
##
## The box hangs off the view but is NOT rotated with it -- it is a marker in the world, not
## a part of the aircraft, and a marker that rolls with a rolling aeroplane reads as debris.
func spot(from: Vector3, wanted: bool) -> void:
	var away: float = global_position.distance_to(from)
	var on: bool = wanted and away > SPOT_FROM
	if not on:
		if _spot != null:
			_spot.visible = false
		return
	if _spot == null:
		_spot = _build_the_box()
		add_child(_spot)
	_spot.visible = true
	# Undo the craft's own rotation, so the box stays square to the world, and size it to
	# hold its angle. Half the span, because the box is built one metre to a side.
	_spot.global_basis = Basis.IDENTITY.scaled(Vector3.ONE * away * SPOT_ANGLE)


func _build_the_box() -> MeshInstance3D:
	var edges := ImmediateMesh.new()
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.15, 0.12)
	# UNSHADED and never fogged: this is a marker and not a thing in the world, so it does
	# not take the light or the haze that would make it as hard to see as what it marks.
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.disable_fog = true
	edges.surface_begin(Mesh.PRIMITIVE_LINES, red)
	# The eight corners of a unit cube, and the twelve edges between them. Each edge is
	# named by the two corners it joins, which is the whole of the cube: three from each
	# corner, counted once.
	var corner: Array[Vector3] = []
	for i in range(8):
		corner.append(Vector3(
			-0.5 + float(i & 1),
			-0.5 + float((i >> 1) & 1),
			-0.5 + float((i >> 2) & 1)))
	for i in range(8):
		for bit in [1, 2, 4]:
			var j: int = i | bit
			if j == i:
				continue
			edges.surface_add_vertex(corner[i])
			edges.surface_add_vertex(corner[j])
	edges.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = edges
	node.material_override = red
	node.name = "SpottingBox"
	# It is a marker, so it is never culled by the craft's own bounds and never casts a
	# shadow of itself onto the ground.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 16384.0
	return node


## Called every render frame. The first line is the only one that matters in this file;
## the turret rides in the vehicle's own frame, so it is already carried by it.
func draw() -> void:
	transform = Sim.vehicle_transform(entity)
	# WHAT IT SOUNDS LIKE, from the state that is already in hand. `VehicleSound` never asks
	# the simulation anything -- a second reader would be a second answer, and a page handed
	# its data is the rule this whole cockpit runs on.
	if sound != null:
		var state: Dictionary = Sim.current.get(entity, {})
		# AIRSPEED AND NOT GROUND SPEED, which on a windy day are different aeroplanes.
		# The wind is generated on every peer and is not on the wire, so it can simply be
		# subtracted here -- the shear with height is ignored, which at ten metres a second
		# against a hundred and fifty is under a per cent of the roar.
		var through_the_air: float = ((state.get("velocity", Vector3.ZERO) as Vector3)
			- Terrain.WIND).length()
		sound.set_tone(
			float(Sim.client.craft_controls(entity).get("throttle", 0.0)), through_the_air)
	# EACH MOUNT ON ITS OWN AIM. The wire carries one per gunner, so a boat with a gun at
	# each end has two people looking wherever they like without either of them moving the
	# other's barrel.
	if not _turrets.is_empty() or _airframe_draws_its_gun():
		draw_turrets_at(Sim.vehicle_turrets(entity))
	# THE SAILS, as the server's rigging says they are: on a watching machine nothing else knows the wind.
	if _brig != null:
		_brig.trim(Sim.vehicle_rigging(entity))
	if _hawkeye != null:
		# THE ROTODOME ON THIS MACHINE'S PHYSICS CLOCK, and THE FOLD eased toward the bus's bit: the bit is the fact, the
		# swing is drawn.
		_hawkeye.turn_rotodome(float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second))
		var want: float = 1.0 if bool(Sim.client.craft_controls(entity).get("fold", false)) else 0.0
		_fold_drawn = move_toward(_fold_drawn, want, get_process_delta_time() / HawkeyeAirframe.FOLD_SECONDS)
		_hawkeye.fold(_fold_drawn)
	if _fighter != null:
		var bus: Dictionary = Sim.client.craft_controls(entity)
		if not bus.is_empty():
			_draw_the_fighters_actuators(bus)
	if _osprey != null:
		_draw_the_osprey()
	if _skyhawk != null:
		_draw_the_skyhawk()
	if _rotorcraft != null:
		_draw_the_rotors()
	if _phantom != null:
		_draw_the_phantom()
	if _tomcat != null:
		_draw_the_tomcat()
	if _savoia != null:
		_draw_the_savoia()
	if _falcon != null:
		_draw_the_falcon()
	if _sailplane != null:
		_draw_the_sailplane()
	if _lightning != null:
		_draw_the_lightning()
	if _warthog != null:
		_draw_the_warthog()
	if _warbird != null:
		_draw_the_warbird()
	if _stores != null:
		_draw_the_stores()
	if _prowler != null:
		_draw_the_prowler()
	if _jetliner != null:
		_draw_the_jetliner()


## THE SAVOIA'S MOVING PARTS, as the Cessna's (`draw_the_skyhawk_from`): the ailerons, elevators and rudder from the
## linkage, which only a machine aboard holds, and the propeller on the shared physics clock, still when parked.
func _draw_the_savoia() -> void:
	var live: bool = entity > 0 and Sim.client != null
	var bus: Dictionary = Sim.client.craft_controls(entity) if live else {}
	var linkage: Dictionary = Sim.client.crew_controls(entity) if live else {}
	var state: Dictionary = Sim.current.get(entity, {}) if live else {}
	var stick: Vector2 = linkage.get("linked_stick", Vector2.ZERO)
	_savoia.set_ailerons(stick.x)
	_savoia.set_elevator(stick.y)
	_savoia.set_rudder(float(linkage.get("linked_rudder", 0.0)))
	var throttle: float = float(bus.get("throttle", 0.0))
	var aboard: bool = false
	for occupant in (Sim.client.vehicle_seats(entity) if live else PackedInt64Array()):
		aboard = aboard or occupant >= 0
	_savoia.set_propeller(aboard or throttle > 0.01 or (state.get("velocity", Vector3.ZERO) as Vector3).length() > 1.0,
		throttle, float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second))


## ---- the F-16's moving surfaces ----------------------------------------------------------

## THE F-16'S SURFACES, from what this machine holds, handed straight to the airframe as the Cessna's are.
func _draw_the_falcon() -> void:
	var live: bool = entity > 0 and Sim.client != null
	draw_the_falcon_from(Sim.client.craft_controls(entity) if live else {}, Sim.client.crew_controls(entity) if live else {})


## THE F-16'S SURFACES, STRAIGHT FROM THE BUS AND THE LINKAGE, as `draw_the_skyhawk_from` is and for its reasons:
## - the stick and the rudder from the linkage, `crew_controls`, which only a machine aboard holds -- everybody else is
##   handed nothing and draws them neutral, because the stick is not on the replicated bus;
## - the flaperons' droop from the flaps lever and the gear from the bus, which every machine holds.
## A flaperon is an aileron and a flap at once, and the stabilators are the elevator AND help the roll, so the one
## stick drives both pairs (`FalconAirframe.set_flaperons`, `set_stabilators`).
func draw_the_falcon_from(bus: Dictionary, linkage: Dictionary) -> void:
	if _falcon == null:
		return
	var stick: Vector2 = linkage.get("linked_stick", Vector2.ZERO)
	_falcon.set_flaperons(stick.x, float(bus.get("flaps", 0.0)))
	_falcon.set_stabilators(stick.y, stick.x)
	_falcon.set_rudder(float(linkage.get("linked_rudder", 0.0)))
	_falcon.set_gear(1.0 if bool(bus.get("gear", true)) else 0.0)


## ---- the Duo Discus's moving surfaces --------------------------------------------------------

func _draw_the_sailplane() -> void:
	var live: bool = entity > 0 and Sim.client != null
	draw_the_sailplane_from(Sim.client.craft_controls(entity) if live else {}, Sim.client.crew_controls(entity) if live else {})


## THE SAILPLANE'S SURFACES, STRAIGHT FROM THE BUS AND THE LINKAGE, as `draw_the_falcon_from` is and for its reasons: the
## stick and the pedals from the linkage -- whichever seat's stick is moving, since both seats fly and the linkage is the
## sum of them -- and the airbrakes and the gear from the bus, which every machine holds. A glider whose bus has no gear
## channel has its wheel down.
func draw_the_sailplane_from(bus: Dictionary, linkage: Dictionary) -> void:
	if _sailplane == null:
		return
	var stick: Vector2 = linkage.get("linked_stick", Vector2.ZERO)
	_sailplane.set_ailerons(stick.x)
	_sailplane.set_elevator(stick.y)
	_sailplane.set_rudder(float(linkage.get("linked_rudder", 0.0)))
	_sailplane.set_airbrakes(float(bus.get("spoilers", 0.0)))
	_sailplane.set_gear(1.0 if bool(bus.get("gear", true)) else 0.0)


## ---- the F-35B's moving parts --------------------------------------------------------------

## THE F-35B AS THIS MACHINE HOLDS IT, handed to `draw_the_lightning_from`.
func _draw_the_lightning() -> void:
	var live: bool = entity > 0 and Sim.client != null
	draw_the_lightning_from(Sim.client.craft_controls(entity) if live else {}, Sim.client.crew_controls(entity) if live else {},
		get_process_delta_time(), float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second),
		Sim.client.craft_systems(entity) if live else {})


## THE F-35B'S MOVING PARTS, from the bus and the linkage:
## - THE NOZZLE STRAIGHT FROM THE TILT CHANNEL, as the Osprey's nacelles are: the thrust swings with the same number on
##   this machine's physics, so an eased copy here would draw the nozzle somewhere the thrust is not. Its doors go with it.
## - THE GEAR EASED TOWARD THE BUS'S BIT, a whole cycle in `LightningAirframe.GEAR_SECONDS`, as the Hawkeye's fold is (the
##   team lead's ruling, 2026-09-19): the bit is the fact the physics reads; the doors-legs-doors sequence is only drawn.
##   Each machine eases its own copy, so a watcher sees the cycle start one link later than the pilot.
## - The flaperons, tailplanes and rudders from the linkage, which only a machine aboard holds, as the F-16's.
## - THE LIFT FAN TURNING while the nozzle is off zero, on the physics clock every machine shares.
## - THE BAY DOORS EASED TOWARD THE BAYS' BITS on CraftSystems over `BAY_SECONDS`, the second the server waits before it
##   pushes a missile out: so on every machine the doors are drawn open before the missile moves, and shut after.
func draw_the_lightning_from(bus: Dictionary, linkage: Dictionary, delta: float, seconds: float,
		systems: Dictionary = {}) -> void:
	if _lightning == null:
		return
	var nozzle: float = float(bus.get("tilt", 0.0))
	_lightning.set_nozzle(nozzle)
	var want: float = 1.0 if bool(bus.get("gear", true)) else 0.0
	_gear_drawn = move_toward(_gear_drawn, want, delta / LightningAirframe.GEAR_SECONDS)
	_lightning.set_gear(_gear_drawn)
	var stick: Vector2 = linkage.get("linked_stick", Vector2.ZERO)
	_lightning.set_flaperons(stick.x)
	_lightning.set_tailplanes(stick.y)
	_lightning.set_rudders(float(linkage.get("linked_rudder", 0.0)))
	if nozzle > 0.0:
		_lightning.set_fan(seconds * LightningAirframe.FAN_BLADE_PASSES)
	var bays: int = int(systems.get("bays", 0))
	for index in range(2):
		var open: float = 1.0 if (bays >> index) & 1 == 1 else 0.0
		_bays_drawn[index] = move_toward(_bays_drawn[index], open, delta / LightningAirframe.BAY_SECONDS)
		_lightning.set_bay(1.0 if index == 0 else -1.0, _bays_drawn[index])


## ---- the A-10C's moving parts ------------------------------------------------------------------

## ---- a warbird's moving parts ---------------------------------------------------------------------------------

## THE AIRFRAME A WARBIRD KIND IS DRAWN BY. Here and not in the kit, so the kit never names the classes built on it.
static func warbird_for(of_kind: int) -> WarbirdAirframe:
	match of_kind:
		Sim.Kind.P51:
			return P51Airframe.new()
		Sim.Kind.P47:
			return P47Airframe.new()
	return P51Airframe.new()


## A WARBIRD AS THIS MACHINE HOLDS IT, handed to `draw_the_warbird_from`.
func _draw_the_warbird() -> void:
	var live: bool = entity > 0 and Sim.client != null
	draw_the_warbird_from(Sim.client.craft_controls(entity) if live else {}, Sim.client.crew_controls(entity) if live else {},
		get_process_delta_time())


## HOW FAST A WARBIRD'S PROPELLER IS DRAWN TURNING, turns a second at idle and at full throttle. Not its real 1,200 to
## 3,000 rpm, which aliases on a headset at 72 or 90 Hz into a propeller turning slowly backwards; a blur between these
## reads as an engine running. A closed throttle is drawn as an engine that is not running, and the propeller stands.
const WARBIRD_PROP_IDLE: float = 2.5
const WARBIRD_PROP_FULL: float = 7.0
const WARBIRD_PROP_RUNNING: float = 0.02

## WHAT MOVES, from what this machine holds:
## - THE GEAR EASED TOWARD THE BUS'S BIT, a whole cycle in `WarbirdAirframe.GEAR_SECONDS`, as the A-10C's is;
## - the flaps from the lever, and the ailerons, elevators and rudder from the linkage;
## - THE PROPELLER turning while the throttle lever is open: the bus's throttle, which every machine is handed.
func draw_the_warbird_from(bus: Dictionary, linkage: Dictionary, delta: float) -> void:
	if _warbird == null:
		return
	var want: float = 1.0 if bool(bus.get("gear", true)) else 0.0
	_warbird_gear = move_toward(_warbird_gear, want, delta / WarbirdAirframe.GEAR_SECONDS)
	_warbird.set_gear(_warbird_gear)
	_warbird.set_flaps(float(bus.get("flaps", 0.0)))
	var stick: Vector2 = linkage.get("linked_stick", Vector2.ZERO)
	_warbird.set_ailerons(stick.x)
	_warbird.set_elevators(stick.y)
	_warbird.set_rudders(float(linkage.get("linked_rudder", 0.0)))
	var throttle: float = clampf(float(bus.get("throttle", 0.0)), 0.0, 1.0)
	if throttle > WARBIRD_PROP_RUNNING:
		_warbird_prop = fposmod(_warbird_prop + delta * lerpf(WARBIRD_PROP_IDLE, WARBIRD_PROP_FULL, throttle), 1.0)
	_warbird.set_props(_warbird_prop)


## Headless keeps the named moving meshes for the geometry checks; a rendered view pours them into a VAT, as the A-10C's.
func _cast_the_warbird() -> void:
	if DisplayServer.get_name() == "headless" or _warbird == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(_warbird) or not _warbird.is_inside_tree():
		return
	_warbird_casting = await VatCasting.pour(_warbird, _warbird.features())


## THE A-10C AS THIS MACHINE HOLDS IT, handed to `draw_the_warthog_from`.
func _draw_the_warthog() -> void:
	var live: bool = entity > 0 and Sim.client != null
	var rounds: int = int(Sim.client.gun_rounds(entity)) if live and Sim.client.has_method("gun_rounds") else -1
	draw_the_warthog_from(Sim.client.craft_controls(entity) if live else {}, Sim.client.crew_controls(entity) if live else {},
		rounds, get_process_delta_time())


## HOW LONG A FALL IN THE DRUM'S COUNT KEEPS THE BARRELS DRIVEN, seconds. The count reaches every machine as a byte of
## the drum's share, rounded up (`CraftSystems::load`): 1,174 rounds in 255 steps is a step every 4.6 rounds, 71 ms at
## 3,900 a minute, so the count falls in steps and not every frame, and a burst is a run of steps no more than this apart.
const WARTHOG_FIRING_HOLD: float = 0.15


## THE A-10C'S MOVING PARTS, from the bus, the linkage and the drum:
## - THE GEAR EASED TOWARD THE BUS'S BIT, a whole cycle in `WarthogAirframe.GEAR_SECONDS`, as the F-35B's is: the bit is
##   the fact the physics reads; the nose doors-legs-doors sequence is only drawn.
## - THE SPEED BRAKE -- the decelerons splitting -- eased toward the spoilers bit in `WarthogAirframe.SPEEDBRAKE_SECONDS`.
## - The flaps straight from the bus's lever, 0 to 1, which every machine holds.
## - The ailerons, elevators and rudders from the linkage, which only a machine aboard holds, as the F-16's.
## - THE GAU-8'S BARRELS TURN WHILE THE DRUM EMPTIES: the count every machine is handed (`gun_rounds`) falling is the gun
##   firing, on the pilot's machine and on a watcher's alike, with no trigger on the wire to ask. They run up to speed
##   and down again over `WarthogAirframe.GUN_SPIN_UP`, as the real gun's hydraulic drive does.
func draw_the_warthog_from(bus: Dictionary, linkage: Dictionary, rounds: int, delta: float) -> void:
	if _warthog == null:
		return
	var want: float = 1.0 if bool(bus.get("gear", true)) else 0.0
	_warthog_gear = move_toward(_warthog_gear, want, delta / WarthogAirframe.GEAR_SECONDS)
	_warthog.set_gear(_warthog_gear)
	var brake: float = 1.0 if bool(bus.get("spoilers", false)) else 0.0
	_warthog_brake = move_toward(_warthog_brake, brake, delta / WarthogAirframe.SPEEDBRAKE_SECONDS)
	_warthog.set_speedbrake(_warthog_brake)
	_warthog.set_flaps(float(bus.get("flaps", 0.0)))
	var stick: Vector2 = linkage.get("linked_stick", Vector2.ZERO)
	_warthog.set_ailerons(stick.x)
	_warthog.set_elevators(stick.y)
	_warthog.set_rudders(float(linkage.get("linked_rudder", 0.0)))
	if rounds >= 0 and _warthog_rounds >= 0 and rounds < _warthog_rounds:
		_warthog_firing_for = WARTHOG_FIRING_HOLD
	_warthog_rounds = rounds
	_warthog_firing_for = maxf(_warthog_firing_for - delta, 0.0)
	var spin: float = 1.0 if _warthog_firing_for > 0.0 else 0.0
	_warthog_gun_spin = move_toward(_warthog_gun_spin, spin, delta / WarthogAirframe.GUN_SPIN_UP)
	_warthog_gun_phase = fposmod(_warthog_gun_phase + delta * WarthogAirframe.GUN_PASSES * _warthog_gun_spin, 1.0)
	_warthog.set_gun(_warthog_gun_phase)


## HOW FAST THE DRAWN GAU-8 IS TURNING, 0 still to 1 at speed: what `tests/warthog_gun.gd` reads beside the barrels.
func warthog_gun_spin() -> float:
	return _warthog_gun_spin


## Headless keeps the named moving meshes for the geometry checks; a rendered view pours them into a VAT, as the F-35B's.
func _cast_the_warthog() -> void:
	if DisplayServer.get_name() == "headless" or _warthog == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(_warthog) or not _warthog.is_inside_tree():
		return
	_warthog_casting = await VatCasting.pour(_warthog, _warthog.features())


## Headless keeps the named moving meshes for the geometry checks; a rendered view pours them into a VAT, as the Tomcat's.
func _cast_the_lightning() -> void:
	if DisplayServer.get_name() == "headless" or _lightning == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(_lightning) or not _lightning.is_inside_tree():
		return
	_lightning_casting = await VatCasting.pour(_lightning, _lightning.features())


## THE PROWLER AS THIS MACHINE HOLDS IT: fold from replicated craft configuration, flight surfaces from the local crew
## linkage. A machine with nobody aboard has no linkage and therefore draws neutral surfaces, as the Falcon and Tomcat
## do; the fold remains visible to everyone because it is on the bus.
func _draw_the_prowler() -> void:
	var live: bool = entity > 0 and Sim.client != null
	var bus: Dictionary = Sim.client.craft_controls(entity) if live else {}
	var want: float = 1.0 if bool(bus.get("fold", false)) else 0.0
	_fold_drawn = move_toward(_fold_drawn, want, get_process_delta_time() / ProwlerAirframe.FOLD_SECONDS)
	_prowler.fold(_fold_drawn)
	draw_the_prowlers_surfaces_from(Sim.client.crew_controls(entity) if live else {})


func draw_the_prowlers_surfaces_from(linkage: Dictionary) -> void:
	if _prowler == null:
		return
	_prowler.follow_the_stick(linkage.get("linked_stick", Vector2.ZERO),
		float(linkage.get("linked_rudder", 0.0)))


## THE AIRFRAME A JETLINER KIND IS DRAWN BY, not yet dressed: the 737-800 for `airliner`, the 747-400 for `jumbo`, the
## AC-130U for `gunship` and the C-130H for `transport` -- one `HerculesAirframe`, armed or not.
static func jetliner_for(of_kind: int) -> JetlinerAirframe:
	match of_kind:
		Sim.Kind.JUMBO:
			return Boeing747Airframe.new()
		Sim.Kind.GUNSHIP, Sim.Kind.TRANSPORT:
			var hercules := HerculesAirframe.new()
			hercules.armed = of_kind == Sim.Kind.GUNSHIP
			return hercules
	return Boeing737Airframe.new()


## A JETLINER'S MOVING PARTS, from what this machine holds, handed straight to the airframe as the F-16's are.
func _draw_the_jetliner() -> void:
	var live: bool = entity > 0 and Sim.client != null
	draw_the_jetliner_from(Sim.client.craft_controls(entity) if live else {}, Sim.client.crew_controls(entity) if live else {},
		Sim.client.craft_systems(entity) if live else {})


## A JETLINER'S SURFACES, STRAIGHT FROM THE BUS AND THE LINKAGE, as `draw_the_falcon_from` is and for its reasons: the
## stick and the rudder from the linkage, which only a machine aboard holds (everybody else draws them neutral); the
## flaps lever (0 to 3), the spoilers and the gear from the bus, which every machine holds. A Hercules's ramp from the
## bus's drop bit (the V-22's channel), and the AC-130U's guns from `outside`, the craft's outside switches, whose
## `guns_stowed` every machine holds (lane/liners, 2026-09-19).
func draw_the_jetliner_from(bus: Dictionary, linkage: Dictionary, outside: Dictionary = {}) -> void:
	if _jetliner == null:
		return
	var stick: Vector2 = linkage.get("linked_stick", Vector2.ZERO)
	_jetliner.set_ailerons(stick.x)
	_jetliner.set_elevators(stick.y)
	_jetliner.set_rudder(float(linkage.get("linked_rudder", 0.0)))
	_jetliner.set_flaps(float(bus.get("flaps", 0.0)) / 3.0)
	_jetliner.set_spoilers(1.0 if bool(bus.get("spoilers", false)) else 0.0)
	_jetliner.set_gear(1.0 if bool(bus.get("gear", true)) else 0.0)
	if _jetliner.has_method("set_ramp") and (_jetliner.table() as Dictionary).has("ramp"):
		_jetliner.set_ramp(1.0 if bool(bus.get("drop", false)) else 0.0)
	if _jetliner.has_method("set_guns"):
		_jetliner.call("set_guns", 0.0 if bool(outside.get("guns_stowed", false)) else 1.0)
	# A HERCULES'S PROPELLERS TURN while it has a crew or a throttle, on the shared physics clock, at a pace a picture can
	# follow (half a turn a second) rather than the T56's 1,020 rpm, which a frame rate strobes into standing still.
	if _jetliner.has_method("set_props"):
		var live: bool = entity > 0 and Sim.client != null
		var turning: bool = float(bus.get("throttle", 0.0)) > 0.01
		for occupant in (Sim.client.vehicle_seats(entity) if live else PackedInt64Array()):
			turning = turning or occupant >= 0
		if turning:
			_jetliner.call("set_props", float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second) * 2.0)


## A rendered view pours the jetliner's parts once into the rigid-body VAT, as the Prowler's; headless keeps the parts.
func _cast_the_jetliner() -> void:
	if DisplayServer.get_name() == "headless" or _jetliner == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(_jetliner) or not _jetliner.is_inside_tree():
		return
	# THE AC-130U'S GUNS ARE LEFT OUT OF THE CASTING, and their feature with them: each is aimed by its gunner every frame
	# (`aim_guns`), which no baked table can follow, so they stay parts on their own mounts.
	var wanted: Array = _jetliner.features().filter(func(f: Dictionary) -> bool: return f["name"] != "guns")
	_jetliner_casting = await VatCasting.pour(_jetliner, wanted,
		func(part: MeshInstance3D) -> bool: return String(part.name).begins_with("Gun"))


## Headless keeps the named moving meshes for geometry checks. A rendered view pours them once into the same rigid-body
## VAT path as the Tomcat; fold is an outer table on each aileron, so a folded wing still carries its control surface.
func _cast_the_prowler() -> void:
	if DisplayServer.get_name() == "headless" or _prowler == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(_prowler) or not _prowler.is_inside_tree():
		return
	_prowler_casting = await VatCasting.pour(_prowler, _prowler.features())

## ---- the F-14's swing wing -------------------------------------------------------------

## HOW FAST THE DRAWN WING CATCHES UP with the bus's actual sweep, in degrees a second: twice the rate the simulation
## moves it (`kSweepDegreesPerSecond`, 12), so it follows a sweep in progress without lagging it, and closes the 1.7-degree
## steps a pilot's own predicting machine receives the wings in (CraftSystems' `should_roll_back`) without being seen to.
const SWEEP_DRAWN_RATE: float = 24.0


## WHERE THE BUS SAYS THE WINGS ARE, in degrees: `sweep` off CraftSystems, 0 spread to 255 overswept. Spread on a craft
## nobody is simulating yet, which is how a parked Tomcat is built.
func _sweep_on_the_bus() -> float:
	if entity <= 0 or Sim.client == null:
		return TomcatAirframe.SWEEP_FORWARD
	var said: int = int(Sim.client.craft_systems(entity).get("sweep", 0))
	return SweepHandle.sweep_of(float(said) / 255.0)


## THE WINGS, EASED TOWARD THE BUS. The bus is the fact; this is only how it is drawn. The airframe's parts are posed, and
## the VAT casting reads the airframe's own `sweep()` and hands the shader the angle (`VatCasting.play`).
func _draw_the_wing_sweep() -> void:
	_sweep_drawn = move_toward(_sweep_drawn, _sweep_on_the_bus(), SWEEP_DRAWN_RATE * get_process_delta_time())
	_tomcat.set_sweep(_sweep_drawn)


## THE F-14 AS THIS MACHINE HOLDS IT: the wings first, then the surfaces, because the spoilers' share of the roll is
## asked at the sweep the wing is drawn at.
func _draw_the_tomcat() -> void:
	_draw_the_wing_sweep()
	var live: bool = entity > 0 and Sim.client != null
	draw_the_tomcats_surfaces_from(Sim.client.crew_controls(entity) if live else {})


## THE F-4E AS THIS MACHINE HOLDS IT.
func _draw_the_phantom() -> void:
	var live: bool = entity > 0 and Sim.client != null
	draw_the_phantom_from(Sim.client.craft_systems(entity) if live else {},
		Sim.client.crew_controls(entity) if live else {})


## THE F-4E'S SURFACES, FROM THE BUS AND THE LINKAGE, as `draw_the_falcon_from` is and for its reasons: the stick
## and the pedals come from `crew_controls`, which only a machine aboard holds, so everybody else is handed nothing
## and draws them neutral; the flaps come from the bus, which every machine holds.
##
## THE SLATS FOLLOW THE FLAPS, which is what the real aeroplane does -- the E's slats are scheduled with the flap
## lever and are not a separate control. They are a separate SETTER because they are a separate surface and step 3
## may want them apart; `sources.md` records that the E has slats and no boundary layer control, which is why they
## exist at all.
func draw_the_phantom_from(bus: Dictionary, linkage: Dictionary) -> void:
	if _phantom == null:
		return
	var flaps: float = clampf(float(bus.get("flaps", 0.0)), 0.0, 1.0)
	_phantom.set_flaps(flaps)
	_phantom.set_slats(flaps)
	_phantom.follow_the_stick(linkage.get("linked_stick", Vector2.ZERO),
		float(linkage.get("linked_rudder", 0.0)))


## THE F-14'S SURFACES, STRAIGHT FROM THE LINKAGE, as `draw_the_falcon_from` and for its reasons: the stick and the
## pedals are in `crew_controls`, which only a machine aboard holds, so everybody else is handed nothing and draws them
## neutral. The F-14 has no ailerons: the stick's roll goes to the spoilers and the differential tailplanes, its pitch
## to the tailplanes together, and the airframe does the mixing and the spoilers' lockout past 57 degrees of sweep
## (`TomcatAirframe.follow_the_stick`). The VAT casting reads each surface's amount back off the airframe.
func draw_the_tomcats_surfaces_from(linkage: Dictionary) -> void:
	if _tomcat == null:
		return
	_tomcat.follow_the_stick(linkage.get("linked_stick", Vector2.ZERO), float(linkage.get("linked_rudder", 0.0)))


## POUR THE TOMCAT INTO ITS VAT, where there is a renderer to draw one. Headless there is no shader to convert
## (`VatCasting._vat_material` warns and moves nothing), and every headless suite that builds a view of every kind would
## pay for a bake it cannot use -- so a headless run draws the airframe's parts, which the geometry suites measure anyway.
## A COROUTINE, left to run: the airframe draws as parts until the casting is poured, and a view freed first pours nothing.
func _cast_the_tomcat() -> void:
	if DisplayServer.get_name() == "headless" or _tomcat == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(_tomcat) or not _tomcat.is_inside_tree():
		return
	_tomcat_casting = await VatCasting.pour(_tomcat, _tomcat.features())


## THE V-22'S MOVING PARTS, from what this machine holds:
## - THE NACELLES STRAIGHT FROM THE TILT CHANNEL, the same lever the simulation turns the thrust by
##   (`OspreyAirframe.set_tilt`, `fly_tiltrotor`): an eased copy would draw them where the thrust is not;
## - THE GEAR AND THE RAMP EASED TOWARD THE BUS'S BITS, a whole cycle in `OspreyAirframe.GEAR_SECONDS` and
##   `RAMP_SECONDS`, as the F-35B's gear is: the bit is the fact, the doors-legs-doors sequence is only drawn. The ramp is
##   the drop channel's bit, the doors a load leaves by;
## - THE PROPROTORS turning when anybody is aboard, the throttle is up or the craft is moving, on the physics clock every
##   machine shares, as the helicopters' are.
## With no bus -- the builder's preview -- the nacelles stand straight up, as a V-22 parks, the gear is down, the ramp
## shut and the rotors parked.
func _draw_the_osprey() -> void:
	var live: bool = entity > 0 and Sim.client != null
	var state: Dictionary = Sim.current.get(entity, {}) if live else {}
	draw_the_osprey_from(Sim.client.craft_controls(entity) if live else {},
		Sim.client.vehicle_seats(entity) if live else PackedInt64Array(), state.get("velocity", Vector3.ZERO) as Vector3,
		get_process_delta_time(), float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second))


## THE SAME, FROM WHAT IT IS HANDED, so a test can hand it a bus as `draw_the_rotors_from` is.
func draw_the_osprey_from(bus: Dictionary, occupants: PackedInt64Array, velocity: Vector3, delta: float,
		seconds: float) -> void:
	if _osprey == null:
		return
	_osprey.set_tilt(float(bus.get("tilt", OspreyAirframe.vertical())))
	_gear_drawn = move_toward(_gear_drawn, 1.0 if bool(bus.get("gear", true)) else 0.0,
		delta / OspreyAirframe.GEAR_SECONDS)
	_osprey.set_gear(_gear_drawn)
	_ramp_drawn = move_toward(_ramp_drawn, 1.0 if bool(bus.get("drop", false)) else 0.0,
		delta / OspreyAirframe.RAMP_SECONDS)
	_osprey.set_ramp(_ramp_drawn)
	var aboard: bool = false
	for occupant in occupants:
		aboard = aboard or occupant >= 0
	var throttle: float = float(bus.get("throttle", 0.0))
	_osprey.set_rotors(aboard or throttle > 0.01 or velocity.length() > 1.0, throttle, seconds)


## POUR THE V-22 INTO ITS VAT, where there is a renderer to draw one, as the Tomcat is (`_cast_the_tomcat`). Its discs
## stay parts: their fade is not a transform.
func _cast_the_osprey() -> void:
	if DisplayServer.get_name() == "headless" or _osprey == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(_osprey) or not _osprey.is_inside_tree():
		return
	_osprey_casting = await VatCasting.pour(_osprey, _osprey.features(), OspreyAirframe.unpoured)
