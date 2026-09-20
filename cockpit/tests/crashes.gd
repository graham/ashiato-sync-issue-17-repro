extends Node
## Headless: WHAT DESTROYS AN AIRCRAFT AND WHAT DOES NOT -- the crash rule (`CockpitWorld::judge_impacts`) against
## landings that must survive it and impacts that must not (lane/combat, 2026-09-18).
##
##   Godot --headless --path cockpit res://tests/crashes.tscn [-- --impact=1.5]
##
## Asked for on 2026-09-18: "planes that hit the ground or water (that are not planeboats) should explode too". And by
## team-lead: a normal landing never explodes -- on wheels, on a skid, a flying boat on the sea, a helicopter, a
## touch-and-go and a landing on a moving carrier's deck.
##
## A BARE SERVER WORLD per case, a slab at sea level with the sea past its edge (as `ground_stick.gd`), and every craft
## FLOWN THROUGH `set_pilot_input` -- the frame a seated player's rig sends, gear lowered by the bus command a hand on
## the lever sends. Nothing is placed after it is spawned. Every row prints the hardest contact it made
## (`impact_report`), which is the measurement the limit was set against: see agents.md, "A HULL, AND WHAT BREAKS IT".
##
## MUTANT: `-- --impact=1.5` puts the crash limit under a gentle landing's contact through the test's own copy of the
## rule's number (`set_crash_impact`), and the landing rows must go red.
##
## A LANDING, DEFINED (step 5, 2026-09-19; the user: "make sure we understand the difference between a landing and a
## crash, since we need to support landings on ground and on the aircraft carrier (which are 'hard' landings)"). Each
## kind's gear is `touchdown_rule(kind)`, and the rows below are flown at a CONTACT SINK asked of that rule -- put down
## `CLOSE` over the surface with the sink that reaches the asked speed at it -- and each prints what it measured:
## a carrier trap under the carrier aeroplane's limit and just over it; a firm ground landing at 3 m/s and at 2.5 times
## that; a wing dropped at the touch; the nose into a wall; a belly landing gently and hard; and the Osprey and the
## F-35B landing vertically, on the slab and on the carrier. More mutants, one clause of the rule off each
## (`set_landing_mutant`): `-- --landing-mutant=tip`, `strike`, `belly`; each turns its own rows red.
##
## Read RESULT=.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 70
const COAST: float = 7200.0
## How long each case is flown after it is put in the air, seconds.
const FLOWN_S: float = 6.0
## How far over the surface a set-sink case is put, metres: just past the legs' reach (0.6 m under the box, the
## simulation's `kWheelReach`), so its wheels ARRIVE -- a craft put down inside their reach is already on them -- and
## near enough that the sink asked is the sink it meets. And the fall it has before they do.
const CLOSE: float = 0.85
const FALL: float = 0.25
## The carrier's deck over the ship's origin, by kind, found once each: see `_deck_over_the_carrier`.
var _decks: Dictionary = {}

var _failures: PackedStringArray = []
var _world: Object = null
var _craft: int = 0
var _pilot: int = 0
var _input: Dictionary = {}
var _seq: int = 0
var _lost: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[crashes] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld")
	if not ClassDB.class_exists("CockpitWorld") or not ClassDB.class_has_method("CockpitWorld", "take_kills"):
		_check("the_library_has_a_crash_rule", false, "no take_kills")
		_finish()
		return
	var rule: Dictionary = ClassDB.class_call_static(&"CockpitWorld", &"crash_rule")
	print("[crashes] the rule: %s" % rule)
	# ---- what must survive ----
	_survives("a_light_aeroplane_lands_on_its_wheels", Sim.Kind.PLANE, "slab", 40.0, 1.5, true, 0.1)
	_survives("a_light_aeroplane_lands_firmly_at_ten_feet_a_second", Sim.Kind.PLANE, "slab", 40.0, 3.0, true, 0.1)
	_survives("a_fighter_lands_on_its_wheels", Sim.Kind.FIGHTER, "slab", 62.0, 3.0, true, -0.3)
	_survives("a_glider_lands_on_its_skid", Sim.Kind.GLIDER, "slab", 24.0, 1.2, true, 0.0)
	_survives("a_helicopter_sets_down", Sim.Kind.HELI, "slab", 0.0, 1.5, true, 0.3)
	_survives("an_apache_sets_down", Sim.Kind.APACHE, "slab", 0.0, 1.5, true, 0.3)
	_survives("a_savoia_alights_on_the_sea", Sim.Kind.SAVOIA, "sea", 32.0, 1.2, false, 0.0)
	_survives("a_water_bomber_alights_on_the_sea", Sim.Kind.TANKER, "sea", 36.0, 1.2, false, -0.2)
	_touch_and_go()
	_on_a_moving_deck()
	# ---- a landing, defined (step 5) ----
	var carrier: Dictionary = _world_rule(Sim.Kind.FIGHTER)
	var land: Dictionary = _world_rule(Sim.Kind.PLANE)
	var carrier_limit: float = float(carrier.get("limit", 0.0))
	var land_design: float = float(land.get("design", 0.0))
	print("[crashes] a carrier aeroplane's gear %s; a land aeroplane's %s" % [carrier, land])
	_check("a_carrier_aeroplane_is_rated_at_the_carrier_sink", is_equal_approx(carrier_limit, 7.62),
		"limit %.2f m/s" % carrier_limit)
	_check("a_land_aeroplane_is_rated_at_twice_ten_feet_a_second", is_equal_approx(float(land.get("limit", 0.0)), 6.1),
		"limit %.2f m/s" % float(land.get("limit", 0.0)))
	# ASKED ABOVE WHAT IT ARRIVES WITH: the wing takes about 1.3 m/s off a sink put on a level aeroplane before its wheels
	# reach the deck (asked 7.12, arrived 5.73; asked 8.22, arrived 6.96). So each row holds what ARRIVED against the
	# line: just under it and whole, or over it and destroyed.
	_trap("a_carrier_trap_just_under_the_carrier_sink_is_a_landing", Sim.Kind.FIGHTER, 8.6, 35.0, true, carrier_limit)
	_trap("a_carrier_trap_just_over_the_carrier_sink_is_a_crash", Sim.Kind.FIGHTER, 9.4, 35.0, false, carrier_limit)
	_set_sink("a_firm_ground_landing_at_three_metres_a_second_is_a_landing", Sim.Kind.PLANE, 40.0, 3.0, 0.0, true,
		"")
	_set_sink("a_ground_landing_at_two_and_a_half_times_that_is_a_crash", Sim.Kind.PLANE, 40.0, land_design * 2.5, 0.0,
		false, "touched down")
	# THE WING DROPPED BY THE PILOT'S OWN HAND on the way down from 3 m, so the bank is there at the touch.
	_set_sink("a_wing_dropped_at_the_touch_is_a_crash", Sim.Kind.PLANE, 40.0, 3.0, 0.25, false, "wingtip", 3.0)
	_into_a_wall()
	_belly("a_belly_landing_gear_up_is_survived_and_costs_half_the_hull", 1.5, true)
	_belly("a_belly_landing_harder_than_the_gear_design_is_a_crash", 9.0, false)
	_set_sink("an_osprey_lands_vertically", Sim.Kind.OSPREY, 0.0, 0.6, 0.0, true, "")
	_set_sink("an_f35b_lands_vertically", Sim.Kind.LIGHTNING, 0.0, 0.6, 0.0, true, "")
	_trap("an_f35b_lands_vertically_on_the_carrier", Sim.Kind.LIGHTNING, 0.6, 0.0, true)
	# ---- what must not ----
	_destroyed("a_light_aeroplane_flown_into_the_ground", Sim.Kind.PLANE, "slab", 60.0, 30.0, "ground", 0.0)
	_destroyed("a_light_aeroplane_dropped_on_the_runway_at_eleven_metres_a_second", Sim.Kind.PLANE, "slab", 15.0, 11.0,
		"ground", 0.0)
	_destroyed("a_light_aeroplane_rolled_onto_its_side_into_the_runway", Sim.Kind.PLANE, "slab", 40.0, 0.5, "ground",
		1.0)
	_destroyed("a_light_aeroplane_ditched_in_the_sea", Sim.Kind.PLANE, "sea", 40.0, 1.5, "water", 0.0)
	_destroyed("a_helicopter_set_down_on_the_sea", Sim.Kind.HELI, "sea", 0.0, 1.0, "water", 0.0)
	_destroyed("a_savoia_dropped_on_the_sea", Sim.Kind.SAVOIA, "sea", 15.0, 8.0, "water", 0.0)
	_end()
	_finish()


## A CASE THAT MUST SURVIVE: flown `FLOWN_S` from just over the surface at `speed` along the nose and `sink` down,
## gear down if it has any, the stick eased back by `flare`, idle; then held with the brakes. Must touch, and must not be
## destroyed.
func _survives(label: String, kind: int, place: String, speed: float, sink: float, gear: bool, flare: float) -> void:
	if not _begin(kind, place, speed, sink):
		_check(label, false, "could not be boarded")
		return
	if gear:
		_command(Sim.Channel.GEAR, 1)
	_input = {"throttle": 0.0, "pitch": flare, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"collective": 0.2}
	var touched: float = _fly(FLOWN_S)
	var destroyed: bool = _is_destroyed()
	_check(label, touched > 0.0 and not destroyed, "hardest contact %.2f m/s, %s" % [touched,
		"destroyed: " + String((_lost[0] as Dictionary).get("rule", "")) if destroyed else "whole"])


## A CASE THAT MUST NOT: from `speed` along the nose and `sink` down, with the stick held over at `roll` (a wing
## dropped into the runway by the pilot's own hand). Must be destroyed, by `cause`.
func _destroyed(label: String, kind: int, place: String, speed: float, sink: float, cause: String,
		roll: float) -> void:
	if not _begin(kind, place, speed, sink):
		_check(label, false, "could not be boarded")
		return
	_input = {"throttle": 0.3, "pitch": 0.0, "roll": roll, "rudder": 0.0, "brake": 0.0}
	var touched: float = _fly(FLOWN_S)
	var kill: Dictionary = _lost[0] if not _lost.is_empty() else {}
	_check(label, _is_destroyed() and String(kill.get("cause_name", "")) == cause,
		"hardest contact %.2f m/s; %s" % [touched, kill.get("rule", "whole")])


## A TOUCH-AND-GO: down on the wheels, then full power and the stick back, and away again in one piece.
func _touch_and_go() -> void:
	if not _begin(Sim.Kind.PLANE, "slab", 42.0, 1.5):
		_check("a_touch_and_go", false, "could not be boarded")
		return
	_command(Sim.Channel.GEAR, 1)
	_input = {"throttle": 0.0, "pitch": 0.1, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	var touched: float = _fly(3.0)
	_input = {"throttle": 1.0, "pitch": 0.35, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	_fly(8.0)
	var y: float = float((_world.vehicle_state(_craft).get("position", Vector3.ZERO) as Vector3).y)
	_check("a_touch_and_go", touched > 0.0 and not _is_destroyed() and y > 5.0,
		"hardest contact %.2f m/s, %.0f m up after, %s" % [touched, y, "destroyed" if _is_destroyed() else "whole"])


## A FIGHTER PUT DOWN ON A CARRIER'S DECK WHILE THE CARRIER MAKES WAY, hook down, at a carrier landing's sink rate.
##
## WHERE THE DECK IS is found the way a fighter finds it: one dropped on it with the crash rule off comes to rest there,
## and that height over the ship's origin is where the landing is flown to, a fresh world later.
func _on_a_moving_deck() -> void:
	var deck: float = _deck_over_the_carrier()
	_check("the_carriers_deck_can_be_found", deck > 5.0, "deck %.2f m over the ship's origin" % deck)
	if deck <= 5.0:
		return
	var ship: Dictionary = _a_carrier_under_way()
	var carrier_at: Vector3 = ship["position"]
	var at: Vector3 = carrier_at + Vector3(0.0, deck + 1.2, 40.0)
	var made: Dictionary = _world.spawn_pilot(CLIENT, Sim.Kind.FIGHTER, at, 0.0,
		(ship["velocity"] as Vector3) + Vector3(0.0, -3.5, -60.0))
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_command(Sim.Channel.GEAR, 1)
	_command(Sim.Channel.HOOK, 1)
	# PUSHED ON, as a carrier landing is flown: no flare, onto the deck at the sink rate it arrived with.
	_input = {"throttle": 0.0, "pitch": -0.3, "roll": 0.0, "rudder": 0.0, "brake": 1.0}
	var touched: float = _fly(4.0)
	_check("a_fighter_lands_on_a_moving_carriers_deck", touched > 0.0 and not _is_destroyed(),
		"hardest contact %.2f m/s, %s" % [touched, (_lost[0] as Dictionary).get("rule", "")
			if _is_destroyed() else "whole"])


## A KIND'S GEAR, as the simulation rules it: asked of a world, as the game would.
func _world_rule(kind: int) -> Dictionary:
	_end()
	_world = ClassDB.instantiate("CockpitWorld")
	_world.start(0)
	return _world.touchdown_rule(kind)


## THE SINK THAT MEETS THE SURFACE AT `contact` from `over` it: gravity adds the rest on the way down.
static func _sink_for(contact: float, over: float = FALL) -> float:
	return sqrt(maxf(contact * contact - 2.0 * 9.81 * over, 0.0))


## A SET-SINK CASE on the slab: `speed` along the nose, meeting it at `contact`, the stick over at `roll`, gear down.
## Whole, or destroyed with `word` in the rule.
func _set_sink(label: String, kind: int, speed: float, contact: float, roll: float, whole: bool, word: String,
		over: float = CLOSE) -> void:
	if not _begin(kind, "slab", speed, _sink_for(contact, over - (CLOSE - FALL)), over):
		_check(label, false, "could not be boarded")
		return
	_command(Sim.Channel.GEAR, 1)
	_input = {"throttle": 0.0, "pitch": 0.0, "roll": roll, "rudder": 0.0, "brake": 0.0, "collective": 0.2}
	var touched: float = _fly(FLOWN_S)
	_judged(label, touched, whole, word)


## WHOLE, or destroyed by a rule that says `word`; with the contact it measured.
func _judged(label: String, touched: float, whole: bool, word: String) -> void:
	var rule: String = String((_lost[0] as Dictionary).get("rule", "")) if not _lost.is_empty() else "whole"
	var ok: bool = touched > 0.0 and (not _is_destroyed() if whole else (_is_destroyed() and word in rule))
	_check(label, ok, "hardest contact %.2f m/s (the box %.2f, the wheels arriving %s), %s" % [touched,
		float(_world.impact_report(false).get(_craft, 0.0)),
		"%.2f" % float(_world.touchdown_report(false)[_craft]) if _world.touchdown_report(false).has(_craft)
			else "never", rule])


## A CARRIER TRAP -- or a vertical landing on the deck, at `speed` 0 -- met at `contact` into a deck making way.
func _trap(label: String, kind: int, contact: float, speed: float, whole: bool, line: float = -1.0) -> void:
	var deck: float = _decks.get(kind, -1.0)
	if deck < 0.0:
		deck = _deck_over_the_carrier(kind)
		_decks[kind] = deck
		print("[crashes] kind %d rests its middle %.2f m over the carrier's origin" % [kind, deck])
	if deck <= 5.0:
		_check(label, false, "no deck found for kind %d" % kind)
		return
	var ship: Dictionary = _a_carrier_under_way()
	var at: Vector3 = (ship["position"] as Vector3) + Vector3(0.0, deck + CLOSE, 40.0 if speed > 0.0 else 0.0)
	var made: Dictionary = _world.spawn_pilot(CLIENT, kind, at, 0.0,
		(ship["velocity"] as Vector3) + Vector3(0.0, -_sink_for(contact), -speed))
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	_command(Sim.Channel.GEAR, 1)
	_command(Sim.Channel.HOOK, 1)
	# PUSHED ON, as a trap is flown: no flare, onto the deck at the sink it arrived with, and the brakes on.
	_input = {"throttle": 0.0, "pitch": -0.3 if speed > 0.0 else 0.0, "roll": 0.0, "rudder": 0.0, "brake": 1.0,
		"collective": 0.2}
	var touched: float = _fly(4.0)
	# AGAINST THE LINE, when there is one: arrived within a metre a second under it, or over it.
	if line > 0.0 and (touched > line or touched < line - 1.0 if whole else touched <= line):
		_check(label, false, "arrived at %.2f m/s, which does not test the line at %.2f" % [touched, line])
		return
	_judged(label, touched, whole, "touched down")


## THE NOSE INTO A WALL at 30 m/s, level and on its wheels: not its underside first, so a strike.
func _into_a_wall() -> void:
	if not _begin(Sim.Kind.PLANE, "slab", 30.0, 0.0, 1.5):
		_check("the_nose_into_a_wall_is_a_crash", false, "could not be boarded")
		return
	_world.add_static_box(Vector3(0.0, 20.0, -60.0), Vector3(40.0, 20.0, 2.0))
	_command(Sim.Channel.GEAR, 1)
	_input = {"throttle": 0.6, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0}
	var touched: float = _fly(FLOWN_S)
	_judged("the_nose_into_a_wall_is_a_crash", touched, false, "its nose")


## A BELLY LANDING: a fighter, its gear never lowered, met at `contact`. Whole at half its hull, or destroyed on its belly.
func _belly(label: String, contact: float, whole: bool) -> void:
	# FROM 3 m, because the gear will not come up with weight on it, and slower than it flies, so it comes down.
	if not _begin(Sim.Kind.FIGHTER, "slab", 5.0 if contact > 5.0 else 40.0, _sink_for(contact, 3.0 - (CLOSE - FALL)), 3.0):
		_check(label, false, "could not be boarded")
		return
	_command(Sim.Channel.GEAR, 0)
	_input = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 1.0}
	var touched: float = _fly(FLOWN_S)
	var left: float = float(_world.hull_state(_craft).get("left", 1.0))
	if whole:
		var rule: String = String((_lost[0] as Dictionary).get("rule", "")) if not _lost.is_empty() else "whole"
		_check(label, touched > 0.0 and not _is_destroyed() and left < 0.55 and left > 0.3,
			"hardest contact %.2f m/s, %s, hull left %.2f" % [touched, rule, left])
	else:
		_judged(label, touched, false, "belly")


## A world with a carrier making 12 m/s at sea, steadied for two seconds: its state.
func _a_carrier_under_way() -> Dictionary:
	_end()
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	_lost.clear()
	_seq = 0
	_world.set_sea(true)
	_world.set_landing_mutant(_asked_word("landing-mutant"))
	var impact: float = _asked("impact")
	if impact > 0.0:
		_world.set_crash_impact(impact)
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
	var carrier: int = int(_world.spawn_vehicle(Sim.Kind.CARRIER, Vector3(0.0, 0.0, COAST + 3000.0), 0.0,
		Vector3(0.0, 0.0, -12.0)))
	for i in range(240):
		_world.tick(TICK)
	var ship: Dictionary = _world.vehicle_state(carrier)
	ship["entity"] = carrier
	return ship


## How far over the carrier's origin a fighter's middle rests on its deck, metres; 0 if it never came to rest there.
func _deck_over_the_carrier(kind: int = Sim.Kind.FIGHTER) -> float:
	var ship: Dictionary = _a_carrier_under_way()
	_world.set_crashes(false)
	var made: Dictionary = _world.spawn_pilot(CLIENT, kind, (ship["position"] as Vector3)
		+ Vector3(0.0, 40.0, 40.0), 0.0, ship["velocity"])
	var pilot: int = int(made.get("pilot", 0))
	var craft: int = int(made.get("vehicle", 0))
	for i in range(int(6.0 / TICK)):
		_world.set_pilot_input(pilot, {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 1.0})
		_world.tick(TICK)
	var rest: Vector3 = _world.vehicle_state(craft).get("position", Vector3.ZERO)
	var under: Vector3 = _world.vehicle_state(int(ship["entity"])).get("position", Vector3.ZERO)
	return rest.y - under.y if absf(rest.y - under.y) < 60.0 else 0.0


## ---- the world ---------------------------------------------------------------------------------------------------

func _begin(kind: int, place: String, speed: float, sink: float, clearance: float = 1.5) -> bool:
	_end()
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	_lost.clear()
	_seq = 0
	var impact: float = _asked("impact")
	if impact > 0.0:
		_world.set_crash_impact(impact)
	_world.set_landing_mutant(_asked_word("landing-mutant"))
	# THE SEA PAST THE SLAB, as the island's level says there is one.
	_world.set_sea(true)
	_world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(COAST, 400.0, COAST))
	var extents: Vector3 = Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3
	# JUST OVER THE SURFACE: a half-height and `clearance` (a metre and a half unless asked), so the craft is flown onto
	# it rather than dropped.
	var at := Vector3(0.0, extents.y + clearance, 0.0) if place == "slab" \
		else Vector3(0.0, extents.y + clearance, COAST + 1500.0)
	var made: Dictionary = _world.spawn_pilot(CLIENT, kind, at, 0.0, Vector3(0.0, -sink, -speed))
	_craft = int(made.get("vehicle", 0))
	_pilot = int(made.get("pilot", 0))
	return _craft != 0 and _pilot != 0


func _end() -> void:
	if _world != null:
		_world.teardown()
		_world = null


## Fly `seconds` on the frame as it stands; the hardest contact the craft made, 0 for none. Every kill is kept.
func _fly(seconds: float) -> float:
	var trace: bool = _asked("trace") > 0.0
	for i in range(int(round(seconds / TICK))):
		_world.set_pilot_input(_pilot, _input)
		_world.tick(TICK)
		if trace and i % 12 == 0:
			var st: Dictionary = _world.vehicle_state(_craft)
			print("[crashes] trace t=%.2f at=%s v=%s hit=%.2f" % [i * TICK, st.get("position"), st.get("velocity"),
				float(_world.impact_report(false).get(_craft, 0.0))])
		for kill in _world.take_kills():
			_lost.append(kill)
	# THE HARDER OF THE TWO: the box meeting something, and a winged craft's sink the tick its wheels reached it.
	return maxf(float(_world.impact_report(false).get(_craft, 0.0)),
		float(_world.touchdown_report(false).get(_craft, 0.0)))


func _command(channel: int, value: int) -> void:
	_seq += 1
	var frame: Dictionary = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 0.0,
		"command_channel": channel, "command_value": value, "command_seq": _seq}
	for i in range(3):
		_world.set_pilot_input(_pilot, frame)
		_world.tick(TICK)


func _is_destroyed() -> bool:
	return bool(_world.hull_state(_craft).get("destroyed", false))


static func _asked_word(name: String) -> String:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0] == name:
			return parts[1]
	return ""


static func _asked(name: String) -> float:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0] == name:
			return parts[1].to_float()
	return 0.0


func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0 if _failures.is_empty() else 1)
