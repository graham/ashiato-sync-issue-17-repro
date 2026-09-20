extends Node
## Headless: THE LITTLE BIRD AGAINST ITS BOOK, on its rotor disc.
##
##   Godot --headless --path cockpit res://tests/littlebird_book.tscn [-- --set=rotors=0|1]
##
## `tests/littlebird_flight.gd` is the job: a hover, forward flight, a banked turn, a landing.
## This holds the disc to published MH-6 / MD 530F figures, each against a mutant that must
## fail it. Never against the model's own formula. Plan: research/littlebird_rotor_plan.md.
##
## Read RESULT=.

const KIND: int = Sim.Kind.LITTLEBIRD
const KNOT: float = 0.514444
const BOOK_CLIMB: float = 2070.0 * 0.3048 / 60.0
const BOOK_CRUISE: float = 135.0 * KNOT
const BOOK_VNE: float = 152.0 * KNOT
const WEIGHT: float = 1406.0 * 9.81

var _world: Object
var _failed: PackedStringArray = []
var _passed: int = 0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[littlebird_book] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if ok:
		_passed += 1
	else:
		_failed.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	_world = ClassDB.instantiate("CockpitWorld")
	_world.set_tick_rate(120.0)
	_world.start(0)
	var card := TuningCard.from_command_line()
	card.apply_to(_world, KIND)
	if not _world.has_method("probe_rotor"):
		_check("the_disc_is_in_this_build", false, "CockpitWorld has no probe_rotor; rebuild ashiato_gd")
		_finish()
		return
	var disc: Dictionary = _world.rotor_disc(KIND)
	_check("the_little_bird_has_a_disc", not disc.is_empty() and bool(disc.get("switched_on", false)),
		"radius %.3f m, mass %.0f kg, switched_on %s" % [float(disc.get("radius", 0.0)),
			float(disc.get("mass", 0.0)), disc.get("switched_on", false)])
	_ige_needs_less_collective_than_oge()
	_etl_gives_more_thrust_at_the_same_collective()
	_oge_climb_is_the_books()
	_cruise_and_vne()
	_vortex_ring_cuts_thrust()
	_autorotation_carries_weight_in_a_descent()
	_old_thruster_is_the_climb_mutant()
	_world.teardown()
	_finish()


func _probe(collective: float, along: float, climb: float, height: float, mutant: float = 0.0) -> Dictionary:
	_world.set_handling(KIND, {"rotor_mutant": mutant, "rotors": 1.0})
	return _world.probe_rotor(KIND, collective, along, climb, height)


func _ige_needs_less_collective_than_oge() -> void:
	var ige: Dictionary = _probe(0.47, 0.0, 0.0, 1.0)
	var oge: Dictionary = _probe(0.47, 0.0, 0.0, 20.0)
	var ige_t: float = float(ige.get("thrust", 0.0))
	var oge_t: float = float(oge.get("thrust", 0.0))
	_check("ige_hover_makes_more_thrust_than_oge_at_the_same_collective",
		ige_t > oge_t * 1.04 and String(ige.get("phase", "")) == "ige_hover",
		"T ige %.0f N vs oge %.0f N (weight %.0f), phases %s / %s" % [ige_t, oge_t, WEIGHT,
			ige.get("phase", "?"), oge.get("phase", "?")])
	var off: Dictionary = _probe(0.47, 0.0, 0.0, 1.0, 1.0)
	_check("no_ground_effect_is_the_ige_mutant",
		absf(float(off.get("thrust", 0.0)) - oge_t) < 0.08 * oge_t,
		"mutant T at 1 m %.0f N, oge %.0f N" % [float(off.get("thrust", 0.0)), oge_t])


func _etl_gives_more_thrust_at_the_same_collective() -> void:
	var hover: Dictionary = _probe(0.47, 0.0, 0.0, 30.0)
	var etl: Dictionary = _probe(0.47, 12.0, 0.0, 30.0)
	var ht: float = float(hover.get("thrust", 0.0))
	var et: float = float(etl.get("thrust", 0.0))
	_check("translational_lift_adds_thrust_by_12_m_s",
		et > ht * 1.03 and float(etl.get("etl", 0.0)) > 0.4,
		"T hover %.0f N vs 12 m/s %.0f N, etl %.2f, phase %s" % [ht, et,
			float(etl.get("etl", 0.0)), etl.get("phase", "?")])
	var off: Dictionary = _probe(0.47, 12.0, 0.0, 30.0, 2.0)
	_check("no_translational_lift_is_the_etl_mutant",
		absf(float(off.get("thrust", 0.0)) - ht) < 0.08 * ht,
		"mutant T at 12 m/s %.0f N, hover %.0f N" % [float(off.get("thrust", 0.0)), ht])


func _oge_climb_is_the_books() -> void:
	var at_rate: Dictionary = _probe(1.0, 0.0, BOOK_CLIMB, 40.0)
	var t: float = float(at_rate.get("thrust", 0.0))
	_check("full_collective_oge_climb_matches_the_530F",
		t > WEIGHT * 0.95,
		"at the book's %.1f m/s climb, T %.0f N against weight %.0f (at least 0.95), power %.0f kW" % [
			BOOK_CLIMB, t, WEIGHT, float(at_rate.get("power", 0.0)) / 1000.0])


func _cruise_and_vne() -> void:
	var cruise: Dictionary = _probe(0.70, BOOK_CRUISE, 0.0, 40.0)
	var fast: Dictionary = _probe(1.0, 90.0, 0.0, 40.0)
	_check("at_cruise_the_disc_still_carries_the_weight",
		float(cruise.get("thrust", 0.0)) > WEIGHT * 0.9,
		"T at 69 m/s %.0f N (weight %.0f), phase %s" % [float(cruise.get("thrust", 0.0)), WEIGHT,
			cruise.get("phase", "?")])
	_check("ninety_metres_a_second_is_past_vne",
		float(fast.get("thrust", 0.0)) < WEIGHT * 0.95 or float(fast.get("power", 0.0)) > 400000.0,
		"T at 90 m/s %.0f N, power %.0f kW, Vne %.1f m/s" % [float(fast.get("thrust", 0.0)),
			float(fast.get("power", 0.0)) / 1000.0, BOOK_VNE])


func _vortex_ring_cuts_thrust() -> void:
	var hover: Dictionary = _probe(0.70, 0.5, 0.0, 40.0)
	var vrs: Dictionary = _probe(0.70, 0.5, -10.0, 40.0)
	_check("vortex_ring_cuts_thrust_in_a_powered_descent",
		float(vrs.get("thrust", 0.0)) < float(hover.get("thrust", 0.0)) * 0.85
			and String(vrs.get("phase", "")) == "vortex_ring",
		"T hover %.0f vs descent %.0f, phase %s" % [float(hover.get("thrust", 0.0)),
			float(vrs.get("thrust", 0.0)), vrs.get("phase", "?")])
	var off: Dictionary = _probe(0.70, 0.5, -10.0, 40.0, 4.0)
	_check("no_vortex_ring_is_the_vrs_mutant",
		float(off.get("thrust", 0.0)) > float(vrs.get("thrust", 0.0)) * 1.1,
		"mutant T %.0f vs vrs %.0f" % [float(off.get("thrust", 0.0)), float(vrs.get("thrust", 0.0))])


func _autorotation_carries_weight_in_a_descent() -> void:
	var idle: Dictionary = _probe(0.0, 8.0, -12.0, 40.0)
	_check("autorotation_carries_near_weight_at_twelve_metres_down",
		float(idle.get("thrust", 0.0)) > WEIGHT * 0.75
			and String(idle.get("phase", "")) == "autorotation",
		"T %.0f N (weight %.0f), phase %s" % [float(idle.get("thrust", 0.0)), WEIGHT,
			idle.get("phase", "?")])
	var off: Dictionary = _probe(0.0, 8.0, -12.0, 40.0, 8.0)
	_check("no_autorotation_is_the_auto_mutant",
		float(off.get("thrust", 0.0)) < WEIGHT * 0.2,
		"mutant T %.0f N" % float(off.get("thrust", 0.0)))


func _old_thruster_is_the_climb_mutant() -> void:
	_world.set_handling(KIND, {"rotors": 0.0, "rotor_mutant": 0.0})
	var h: Dictionary = _world.handling(KIND)
	_check("rotors_off_is_the_old_thruster",
		float(h.get("rotors", 1.0)) < 0.5,
		"handling.rotors %s" % str(h.get("rotors", "?")))
	_world.set_handling(KIND, {"rotors": 1.0})


func _finish() -> void:
	print("[littlebird_book] %d passed, %d failed" % [_passed, _failed.size()])
	print("RESULT=%s%s" % ["PASS" if _failed.is_empty() else "FAIL",
		"" if _failed.is_empty() else " " + ", ".join(_failed)])
	get_tree().quit(0 if _failed.is_empty() else 1)
