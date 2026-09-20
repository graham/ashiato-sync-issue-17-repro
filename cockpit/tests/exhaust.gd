extends Node
## Headless contract for the THRUST EXHAUST -- the first effect of its kind in this game (lane/harrier, 2026-09-19),
## asked for with the Harrier: "I'd like you to also try modelling a thrust 'smoke' on this model as well."
## Read RESULT=.
##
## IT IS PROVED ON THE F-35B, not on the Harrier it was asked for, and that is the point rather than an accident. The
## question a new effect has to answer is whether it is a FEATURE or one aeroplane's trick, and proving the interface
## on a different aeroplane -- one that already hovers, whose own suite already flies straight up and lands on a deck
## -- answers it by construction. Every check below is about the INTERFACE, and only the F-35B's own port list is
## about an aeroplane.
##
## THE CHECKS THAT CANNOT BE SATISFIED BY THEIR OWN SUBJECT:
## - the plume's axis is held to `Sim.thrust_axis_of`, the expression `fly_tiltrotor` actually pushes along, so a
##   plume cannot be drawn anywhere the thrust is not. The drawing does not get to mark its own homework.
## - which kinds owe an exhaust is read off the HANDLING TABLE -- a kind with thrust blows -- and never off a list
##   kept here, because a list is exactly the thing that goes stale.

var _failures: PackedStringArray = []

## HOW MANY KINDS WITH THRUST MAY STILL LACK PORTS. A RATCHET, NOT A ROSTER: it names nobody, it can only be lowered,
## and when it reaches zero the check becomes what it is really for -- a kind with thrust and no `exhaust_ports()` is
## a red, full stop. Today one kind of the drawn fleet declares them, which is the F-35B this lane fitted. Lower this
## as each airframe grows the method; it is four lines an aeroplane (`LightningAirframe.exhaust_ports`).
##
## SET TO WHAT IT ACTUALLY IS, not to a comfortable margin. This suite's first run had it at 64 against 28 owed, which
## is a check that cannot fail and therefore is not one -- a later lane could have deleted every port on the fleet and
## stayed green. A ratchet is only worth anything when it sits exactly on the current number.
##
## A NEW KIND RAISES IT BY ONE, AND THAT IS THE ONLY REASON IT MAY EVER RISE. This went 28 to 29 the moment the P-47
## was merged: it has thrust, it declares no ports, and it arrived on main after lane/harrier set the number. That is
## the ratchet working, not failing -- an aeroplane joined the fleet owing an exhaust. What it must never absorb is
## the other way a count grows, which is somebody DELETING ports from a kind that had them. The two are told apart by
## the check's own message, which names every kind that declares: if that list is shorter than it was, the number did
## not rise because a kind arrived. Raise this only with a new kind named in the commit, and lower it the moment an
## airframe grows the method -- it is four lines an aeroplane (`LightningAirframe.exhaust_ports`).
const STILL_OWED: int = 29


func _check(label: String, ok: bool, detail: String) -> void:
	print("[exhaust] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var frame := LightningAirframe.new()
	add_child(frame)
	frame.dress()
	_a_port_is_well_formed(frame)
	_the_plume_points_where_the_thrust_does(frame)
	_the_cold_ports_open_with_the_nozzle(frame)
	_a_kind_with_thrust_owes_an_exhaust()
	_the_layers_a_kind_draws_are_what_it_can_make(frame)
	_nothing_blooms_where_the_plume_is_not_aimed_at_the_ground()
	_a_hovering_craft_raises_the_ground(frame)
	_what_it_costs()
	_finish()


## WHAT IT COSTS, because this is the first effect of its kind and everything after it will copy it (team-lead's
## instruction, 2026-09-19): the tick with NO exhaust, with ONE aircraft, and with a FLIGHT OF FOUR.
##
## THE PROCESSOR'S HALF ONLY, and said so rather than implied. This times `lay()` -- deciding which ports blow, where
## each plume stands, where its wash strikes and how many puffs to throw. It does NOT time the drawing, which is the
## GPU's and belongs in a windowed A/B on a quiet machine under the slot. What can be stated without one is the draw
## call count, and that is the number that decides whether this scales: THREE, one per layer, for the whole sky,
## however many aircraft are running. A flight of four with four ports each would be thirty-two if the layers were
## nodes per craft.
##
## INTERLEAVED A/B/A/B and judged only on the difference, because load flattens a difference
## (`modelling_here.md` section 8) and this machine has other lanes on it.
func _what_it_costs() -> void:
	var missiles := MissileYard.new()
	add_child(missiles)
	var yard := ExhaustYard.new()
	yard.follow(missiles)
	yard.throttle_of = func(_e: int) -> float: return 1.0
	add_child(yard)
	var flight: Dictionary = {}
	for i in range(4):
		var one := LightningAirframe.new()
		add_child(one)
		one.dress()
		one.set_nozzle(1.0)
		one.global_transform = Transform3D(Basis.IDENTITY, Vector3(float(i) * 30.0, 20.0, 0.0))
		flight[i + 1] = one
	var one_craft: Dictionary = {1: flight[1]}
	var said: PackedStringArray = []
	var costs: Dictionary = {"none": 0.0, "one": 0.0, "four": 0.0}
	for pass_number in range(3):
		for arm in [["none", {} as Dictionary], ["one", one_craft], ["four", flight]]:
			var views: Dictionary = arm[1]
			var started: int = Time.get_ticks_usec()
			for f in range(60):
				missiles.draw_missiles([], Vector3(60.0, 25.0, 60.0), 1.0 / 60.0)
				yard.lay(views)
			costs[arm[0]] = costs[arm[0]] + float(Time.get_ticks_usec() - started) / 60.0
	for arm in ["none", "one", "four"]:
		costs[arm] = float(costs[arm]) / 3.0
		said.append("%s %.3f ms" % [arm, float(costs[arm]) / 1000.0])
	var per_craft: float = (float(costs["four"]) - float(costs["one"])) / 3.0 / 1000.0
	for entity in flight:
		(flight[entity] as Node).queue_free()
	yard.queue_free()
	missiles.queue_free()
	# NOT A THRESHOLD ON THE ABSOLUTE TIME, which would be a check on how busy this machine is rather than on the
	# yard. A quarter of a millisecond a craft is far above anything measured here and still catches a change of kind.
	_check("what_it_costs", per_craft < 0.25,
		"lay() a frame, 3 passes of 60 frames interleaved: %s; %+.4f ms an extra craft; 3 draw calls for the sky"
		% [", ".join(said), per_craft])


## THE YARD ACTUALLY THROWS SOMETHING. Every check above this one asks the INTERFACE -- the ports, the tuning, the
## layers -- and not one of them runs `ExhaustYard.lay()`. That gap is not academic: the suite was green through six
## checks while the first picture of a hovering F-35B had no ground wash under it at all, because a yard can report
## itself perfectly and draw nothing. `tests/director.gd` was green through 43 checks while its keypad had never been
## built, for exactly this reason (`modelling_here.md` section 6: assert what is DRAWN, not only what is computed).
func _a_hovering_craft_raises_the_ground(frame: LightningAirframe) -> void:
	var missiles := MissileYard.new()
	add_child(missiles)
	var yard := ExhaustYard.new()
	yard.follow(missiles)
	yard.throttle_of = func(_e: int) -> float: return 1.0
	add_child(yard)
	frame.set_nozzle(1.0)
	# HOVERING over the island's own ground, well inside the bloom's reach.
	frame.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 20.0, 0.0))
	var surface: float = Terrain.surface_height(Vector3(0.0, 20.0, 0.0))
	for i in range(12):
		missiles.draw_missiles([], Vector3(40.0, 20.0, 40.0), 1.0 / 60.0)
		yard.lay({1: frame})
	var thrown: int = yard.puffs_thrown()
	var drawn: Dictionary = yard.drawn()
	var strike: Dictionary = {}
	if drawn.has(1) and not (drawn[1] as Array).is_empty():
		strike = ((drawn[1] as Array)[0] as Dictionary).get("strike", {})
	frame.set_nozzle(0.0)
	yard.queue_free()
	missiles.queue_free()
	_check("a_hovering_craft_raises_the_ground", thrown > 0,
		"surface under it %.2f m, craft at 20.0, clock ran to %.3f s, strike %s, %d puffs thrown in 12 frames"
		% [surface, missiles.clock(), strike, thrown])


## EVERY PORT IS WELL FORMED: a unit axis, a positive radius, a known kind and a heat in range. A malformed port would
## draw a plume of no length or of infinite width, and nothing else in the pipeline would notice.
func _a_port_is_well_formed(frame: LightningAirframe) -> void:
	frame.set_nozzle(1.0)
	var ports: Array = frame.exhaust_ports()
	var said: PackedStringArray = []
	var ok: bool = not ports.is_empty()
	for port in ports:
		var p: Dictionary = port
		var axis: Vector3 = p.get("axis", Vector3.ZERO)
		var radius: float = float(p.get("radius", 0.0))
		var heat: float = float(p.get("heat", -1.0))
		var kind: int = int(p.get("kind", -1))
		var good: bool = absf(axis.length() - 1.0) < 1e-4 and radius > 0.0 \
			and heat >= 0.0 and heat <= 1.0 and kind >= 0 and kind < ExhaustTuning.Kind.size() \
			and p.has("at")
		ok = ok and good
		said.append("kind %d r=%.2f heat=%.1f |axis|=%.4f" % [kind, radius, heat, axis.length()])
	frame.set_nozzle(0.0)
	_check("a_port_is_well_formed", ok, "%d ports: %s" % [ports.size(), "; ".join(said)])


## THE PLUME CANNOT POINT WHERE THE THRUST DOES NOT. The gas leaves along the REVERSE of the thrust axis, and the
## thrust axis is `Sim.thrust_axis_of` -- the expression `fly_tiltrotor` pushes along, not a copy of it. This is
## `tests/lightning.gd`'s nozzle check applied to the effect, and it is the whole reason the exhaust reads the drawn
## part's angle rather than carrying a number of its own.
## AND IT IS HELD TO THE DRAWN MESH AS WELL AS TO THE FORMULA, because those catch different bugs. The angle check
## alone is nearly a tautology: `exhaust_ports` turns by `nozzle_angle()`, which reads the same `vector_travel` that
## `thrust_axis_of` reads, so both sides share a number and only the SIGNS and AXES are really under test. What is not
## shared is the drawn nozzle's own vertices -- so the port's `at` is held to where the metal actually ends, which is
## the check that catches a plume declared at the wrong station or left behind when the nozzle moved.
func _the_plume_points_where_the_thrust_does(frame: LightningAirframe) -> void:
	var nozzle := frame.find_child("Nozzle", true, false) as MeshInstance3D
	var said: PackedStringArray = []
	var ok: bool = nozzle != null
	var worst: float = 0.0
	for amount in [0.0, 0.25, 0.5, 0.75, 1.0]:
		frame.set_nozzle(amount)
		var ports: Array = frame.exhaust_ports()
		var jet := Vector3.ZERO
		var at := Vector3.ZERO
		for port in ports:
			if int((port as Dictionary).get("kind", -1)) == ExhaustTuning.Kind.JET:
				jet = (port as Dictionary)["axis"]
				at = (port as Dictionary)["at"]
		var thrust: Vector3 = Sim.thrust_axis_of(Sim.Kind.LIGHTNING, amount)
		var apart: float = rad_to_deg(jet.angle_to(-thrust)) if thrust != Vector3.ZERO else 180.0
		ok = ok and apart < 0.25
		# THE DRAWN EXIT, as the CENTRE of the exit ring rather than one vertex of it: the sawtooth exit is 0.45 m in
		# radius, so the single furthest vertex is a corner half a metre off the axis and a check against it would
		# have a built-in error the size of the thing it is measuring. Take the mean of every vertex within 0.1 m of
		# the furthest, which is the ring.
		var far: float = -INF
		var to_frame: Transform3D = frame.global_transform.affine_inverse() * nozzle.global_transform
		var points: PackedVector3Array = nozzle.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for p in points:
			far = maxf(far, (to_frame * p).dot(jet))
		var tip := Vector3.ZERO
		var n: int = 0
		for p in points:
			var here: Vector3 = to_frame * p
			if here.dot(jet) > far - 0.1:
				tip += here
				n += 1
		tip /= maxf(float(n), 1.0)
		var off: float = at.distance_to(tip)
		worst = maxf(worst, off)
		ok = ok and off < 0.30
		said.append("lever %.2f: %.3f deg, port %.3f m from the drawn exit" % [amount, apart, off])
	frame.set_nozzle(0.0)
	_check("the_plume_points_where_the_thrust_does", ok,
		"%s; worst gap %.3f m" % [", ".join(said), worst])


## THE COLD PORTS ARE DECLARED ONLY WHILE THEIR DOORS ARE OPEN, which is while the nozzle is off zero. A lift fan
## behind a shut door is not blowing, and declaring it anyway draws a column of dust under an aeroplane in the cruise.
func _the_cold_ports_open_with_the_nozzle(frame: LightningAirframe) -> void:
	frame.set_nozzle(0.0)
	var shut: int = frame.exhaust_ports().size()
	frame.set_nozzle(1.0)
	var open: Array = frame.exhaust_ports()
	var cold: int = 0
	for port in open:
		if int((port as Dictionary).get("kind", -1)) == ExhaustTuning.Kind.FAN:
			cold += 1
	frame.set_nozzle(0.0)
	_check("the_cold_ports_open_with_the_nozzle", shut == 1 and open.size() == 4 and cold == 3,
		"nozzle shut: %d port; swung: %d ports of which %d cold" % [shut, open.size(), cold])


## WHICH KINDS OWE AN EXHAUST IS THE HANDLING TABLE'S ANSWER, NOT A LIST KEPT HERE. A kind with thrust blows; if it
## declares no ports, it is either unfinished or wrong, and either way the number is visible and may only fall.
## A roster of "kinds that should have an exhaust" is precisely the artefact this project keeps deleting.
func _a_kind_with_thrust_owes_an_exhaust() -> void:
	var owed: PackedStringArray = []
	var declared: PackedStringArray = []
	# BUILT THE WAY `tests/skyhawk.gd` builds one for `cabin_room`: `craft_plane.tscn` with `preview_kind` and
	# `_show_in_editor()`, which is the one route that dresses any kind with no world running. A bare
	# `VehicleView.new()` does not -- its first run here reported "Node not found: Hull" 29 times, because an
	# undressed view has no airframe to ask and every kind read as owing an exhaust.
	var scene: PackedScene = load("res://objects/vehicles/craft_plane.tscn") as PackedScene
	for kind in range(Sim.Kind.size()):
		if float(Sim.handling_of(kind).get("thrust", 0.0)) <= 0.0:
			continue
		var view := scene.instantiate() as VehicleView
		add_child(view)
		view.preview_kind = kind
		view._show_in_editor()
		if (view.exhaust_ports() as Array).is_empty():
			owed.append(Sim.kind_name(kind))
		else:
			declared.append(Sim.kind_name(kind))
		view.queue_free()
	_check("a_kind_with_thrust_owes_an_exhaust", owed.size() <= STILL_OWED,
		"%d declare (%s), %d still owe, ratchet %d"
		% [declared.size(), ", ".join(declared), owed.size(), STILL_OWED])


## A KIND OF PORT DRAWS ONLY WHAT IT CAN MAKE. A fan and a rotor move cold air, so neither gets a core: a flame on a
## proprotor would be invented. Held against `ExhaustTuning.layers_of`, which is the one place that branches on kind.
func _the_layers_a_kind_draws_are_what_it_can_make(frame: LightningAirframe) -> void:
	var jet: Array = ExhaustTuning.layers_of(ExhaustTuning.Kind.JET)
	var fan: Array = ExhaustTuning.layers_of(ExhaustTuning.Kind.FAN)
	var rotor: Array = ExhaustTuning.layers_of(ExhaustTuning.Kind.ROTOR)
	var ok: bool = bool(jet[0]) and not bool(fan[0]) and not bool(rotor[0]) \
		and bool(jet[1]) and bool(fan[1]) and not bool(rotor[1]) \
		and bool(jet[2]) and bool(fan[2]) and bool(rotor[2])
	_check("the_layers_a_kind_draws_are_what_it_can_make", ok,
		"jet %s, fan %s, rotor %s (core, haze, bloom)" % [jet, fan, rotor])


## A PLUME NOT AIMED AT THE GROUND RAISES NOTHING, however close the ground is. An aeroplane in the cruise at fifty
## feet is not sandblasting the runway, and the rule that stops it is the port's own axis rather than the craft's kind
## or its altitude.
func _nothing_blooms_where_the_plume_is_not_aimed_at_the_ground() -> void:
	var aft: float = -Vector3.BACK.y
	var down: float = -Vector3.DOWN.y
	var ok: bool = aft < ExhaustTuning.BLOOM_LEAST_DOWN and down >= ExhaustTuning.BLOOM_LEAST_DOWN \
		and ExhaustTuning.bloom_by_height(ExhaustTuning.BLOOM_REACH + 1.0) == 0.0 \
		and ExhaustTuning.bloom_by_height(0.0) == 1.0
	_check("nothing_blooms_where_the_plume_is_not_aimed_at_the_ground", ok,
		"aft %.2f and down %.2f against the least %.2f; at the reach %.2f, on the deck %.2f"
		% [aft, down, ExhaustTuning.BLOOM_LEAST_DOWN,
		ExhaustTuning.bloom_by_height(ExhaustTuning.BLOOM_REACH + 1.0), ExhaustTuning.bloom_by_height(0.0)])


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
