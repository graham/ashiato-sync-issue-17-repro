extends Node
## Headless: EVERY CRAFT KIND'S MOTION, PRINTED BIT FOR BIT, so "every other kind is unchanged" is a fact a suite
## prints and not a claim a lane makes.
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/flight_fingerprint.tscn
##       [-- --write=<file>]    save this build's fingerprints, one line a kind and a flight
##       [-- --expect=<file>]   and fail, naming each line, where this build's differ from the saved ones
##       [-- --kind=a,b]        only these kinds
##       [-- --set=k=v|k*f]     retune (TuningCard) before flying, to see one kind's lines move
##
## IMPORT THE PROJECT FIRST IN A LANE THAT HAS JUST MERGED MAIN (`--headless --xr-mode off --desktop-only --import`, which
## `tests/run_all.ps1` does before every suite). Run direct on a stale class cache, this dies at `Sim.kind_name` with
## "Nonexistent function 'kind_name' in base 'Nil'": another lane's new `class_name` (GliderWinch, PermanentWay) is not
## in the cache, the autoloads fail to compile, and `Sim` is null. It is not this suite's fault and it is not a merge
## conflict -- see `working_with_godot.md` (lane/warbirds2 lost half an hour to it, 2026-09-19).
##
## WHY (lane/flightcore, step 0.5 of `research/flight_model_review.md`): the flight models are being moved one kind at a
## time onto shared blocks, and lane/warbirds2 is changing the undercarriage under every aeroplane. Each such step
## promises that the kinds it did not mean to change fly exactly as they did. Before this, that promise was a dozen
## flight suites' thresholds, which a change can slip under: `littlebird_flight` passed a climb of 23.3 m/s against a book
## of 10.5 because its floor was 6. A fingerprint cannot be slipped under. The same inputs through the same build must
## give the same bits, so the only lines that move are the kinds a change touched.
##
## WHAT IS FLOWN, each in a world of its own so no kind's fingerprint depends on another's:
## - HANDS: a seated pilot's frame (`set_pilot_input`) on a fixed script of stick, pedal and lever for FLY_SECONDS:
##   aeroplanes and tiltrotors in the air at their own cruise, helicopters and pods from a hover, boats afloat, cars and
##   the segway on a slab.
## - AUTOPILOT: the same kind spawned for the autopilot (`spawn_ai_vehicle`) and steered (`steer_ai`) to a point
##   three kilometres off to the right at its own cruise, a hundred metres above where it started: a turn, a climb and
##   a speed to hold, which is the mixer, the control law and the model together. Left with nowhere to go, the boats
##   and ships sat still and printed nothing worth comparing.
## - WHEELS: every aeroplane and tiltrotor on the slab at full power down a runway with the pedals working, which is the
##   undercarriage, the nosewheel or tailwheel and the take-off roll.
## THE CRASH RULE IS OFF (`set_crashes(false)`), because a wreck is frozen with its crew in it, and a craft that the
## script flew into the slab would print the wreck's stillness and nothing of how it flew there.
##
## A line is the kind, the flight, the MD5 of the final position, attitude, velocity and spin as 64-bit floats, and those
## numbers rounded for a person to read.
##
## WHAT IS HELD, so this can fail on its own and not only against a saved file:
## - EACH FLIGHT, FLOWN TWICE IN TWO FRESH WORLDS, GIVES THE SAME BITS. A kind that does not is non-deterministic, which
##   rollback cannot survive (a replayed tick must compute what the first did).
## - EVERY STATE IS FINITE.
## - THE FINGERPRINT SEES A CHANGE SMALLER THAN ANY RETUNE: the light twin's thrust times 1.0001 must move its lines. If
##   it does not, the fingerprint is not measuring the flight (the suite's own mutant, run inside it).
## - With `--expect=`, every line matches the saved file, and a kind missing from either side is named.
##
## TRAINS, THE TOWER AND WHAT NOBODY MAY BOARD ARE LEFT OUT: a train's pose is read off its rails, a tower does not move,
## and the brig sails only on its own rig. Read RESULT=.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 61
const FLY_SECONDS: float = 10.0
## The island slab's half-width and depth, as `ground_stick.gd` lays it.
const SLAB: float = 7200.0
const AIR_HEIGHT: float = 600.0
const HOVER_HEIGHT: float = 100.0
## The retune that must move a fingerprint, and the kind it is made on.
const PROBE_KIND: int = Sim.Kind.PLANE
const PROBE_TUNE: Dictionary = {"thrust": 1.0001}

var _failures: PackedStringArray = []
var _lines: Dictionary = {}
var _card: TuningCard


func _check(label: String, ok: bool, detail: String) -> void:
	print("[flight_fingerprint] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL no CockpitWorld")
		get_tree().quit(1)
		return
	_card = TuningCard.from_command_line()
	var only: PackedStringArray = []
	var write_to: String = ""
	var expect_from: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			only = arg.trim_prefix("--kind=").split(",", false)
		elif arg.begins_with("--write="):
			write_to = arg.trim_prefix("--write=")
		elif arg.begins_with("--expect="):
			expect_from = arg.trim_prefix("--expect=")
	var kinds: int = 0
	for kind in range(Sim.Kind.size()):
		var name: String = Sim.kind_name(kind)
		if not only.is_empty() and not only.has(name):
			continue
		var geometry: Dictionary = Sim.geometry_of(kind)
		var model: int = int(geometry.get("model", -1))
		if model == Sim.Model.TRAIN or model == Sim.Model.FIXED or model == Sim.Model.SAIL:
			continue
		if not bool(geometry.get("pilotable", true)):
			continue
		kinds += 1
		for flight in _flights_of(model):
			_fly_twice(kind, flight)
		await get_tree().process_frame
	_check("every_kind_was_flown", kinds > 0, "%d kinds, %d lines" % [kinds, _lines.size()])
	if only.is_empty() or only.has(Sim.kind_name(PROBE_KIND)):
		_the_fingerprint_sees_a_small_retune()
	if not write_to.is_empty():
		_write(write_to)
	if not expect_from.is_empty():
		_compare(expect_from, only)
	_finish()


## Which flights a kind is flown on, by how it moves.
func _flights_of(model: int) -> PackedStringArray:
	match model:
		Sim.Model.AIRPLANE, Sim.Model.TILTROTOR:
			return ["hands", "autopilot", "wheels"]
		Sim.Model.HELICOPTER, Sim.Model.HOVER, Sim.Model.BOAT, Sim.Model.CAR:
			return ["hands", "autopilot"]
		_:
			return ["hands"]


## ONE FLIGHT, TWICE, in two fresh worlds: the line, and whether the two agreed to the bit.
func _fly_twice(kind: int, flight: String, tune: Dictionary = {}) -> String:
	var name: String = Sim.kind_name(kind)
	var first: Dictionary = _fly(kind, flight, tune)
	var second: Dictionary = _fly(kind, flight, tune)
	var key: String = "%s %s" % [name, flight]
	if first.is_empty():
		_check("%s_%s_could_be_flown" % [name, flight], false, "it could not be spawned")
		return ""
	var line: String = "%s %s %s" % [key, first["digest"], first["readable"]]
	if tune.is_empty():
		_lines[key] = line
		print("[flight_fingerprint] %s" % line)
		if not bool(first["finite"]):
			_check("%s_%s_stays_finite" % [name, flight], false, first["readable"])
		if first["digest"] != second.get("digest", ""):
			_check("%s_%s_flies_the_same_twice" % [name, flight], false,
				"%s then %s" % [first["digest"], second.get("digest", "")])
	return String(first["digest"])


## ONE FLIGHT in a world of its own. Returns the digest, a readable summary and whether every number was finite.
func _fly(kind: int, flight: String, tune: Dictionary) -> Dictionary:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.set_crashes(false)
	_card.apply_to(world, kind)
	if not tune.is_empty():
		var now: Dictionary = world.handling(kind)
		var tuned: Dictionary = {}
		for k in tune:
			tuned[k] = float(now.get(k, 0.0)) * float(tune[k])
		world.set_handling(kind, tuned)
	var geometry: Dictionary = Sim.geometry_of(kind)
	var model: int = int(geometry.get("model", -1))
	var hy: float = float((geometry.get("extents", Vector3.ONE) as Vector3).y)
	var cruise: float = float(world.handling(kind).get("cruise", 40.0))
	var at := Vector3.ZERO
	var velocity := Vector3.ZERO
	var slab: bool = true
	match flight:
		"wheels":
			at = Vector3(0.0, hy + 0.05, 0.0)
		_:
			match model:
				Sim.Model.AIRPLANE, Sim.Model.TILTROTOR:
					at = Vector3(0.0, AIR_HEIGHT, 0.0)
					velocity = Vector3(0.0, 0.0, -cruise)
				Sim.Model.HELICOPTER, Sim.Model.HOVER:
					at = Vector3(0.0, HOVER_HEIGHT, 0.0)
				Sim.Model.BOAT:
					# No slab: in a world with no ground, open water is wherever nothing solid is under the hull.
					slab = false
					at = Vector3(0.0, 0.5, 0.0)
				_:
					at = Vector3(0.0, hy + 0.05, 0.0)
	if slab:
		world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(SLAB, 400.0, SLAB))
	var craft: int = 0
	var pilot: int = 0
	if flight == "autopilot":
		craft = int(world.spawn_ai_vehicle(kind, at, 0.0, velocity))
		# Every key given, with its default where it does not apply (CLAUDE.md rule 8): a key left out keeps whatever
		# an earlier steer set.
		world.steer_ai(craft, {"toward": at + Vector3(2600.0, 100.0, -1500.0), "altitude": at.y + 100.0,
			"speed": cruise, "wheels": "fly", "cruise_floor": false, "bank": 0.0, "approach": false})
	else:
		var made: Dictionary = world.spawn_pilot(CLIENT, kind, at, 0.0, velocity)
		craft = int(made.get("vehicle", 0))
		pilot = int(made.get("pilot", 0))
	if craft == 0 or (flight != "autopilot" and pilot == 0):
		world.teardown()
		return {}
	var ticks: int = int(round(FLY_SECONDS / TICK))
	for i in range(ticks):
		if pilot != 0:
			world.set_pilot_input(pilot, _hands(flight, model, i * TICK))
		world.tick(TICK)
	var s: Dictionary = world.vehicle_state(craft)
	world.teardown()
	var p: Vector3 = s.get("position", Vector3.ZERO)
	var q: Quaternion = s.get("basis", Quaternion())
	var v: Vector3 = s.get("velocity", Vector3.ZERO)
	var w: Vector3 = s.get("spin", Vector3.ZERO)
	var numbers := PackedFloat64Array([p.x, p.y, p.z, q.x, q.y, q.z, q.w, v.x, v.y, v.z, w.x, w.y, w.z])
	var finite: bool = true
	for n in numbers:
		finite = finite and is_finite(n)
	return {
		"digest": numbers.to_byte_array().hex_encode().md5_text().substr(0, 16),
		"readable": "at (%.2f, %.2f, %.2f) v %.2f m/s" % [p.x, p.y, p.z, v.length()],
		"finite": finite,
	}


## THE SCRIPT: the same hands for every kind, a function of time only, so a fingerprint depends on the craft and the
## build and on nothing else. Sines of unrelated periods, so every axis is worked in both directions and no two together.
func _hands(flight: String, model: int, t: float) -> Dictionary:
	var hands := {
		"pitch": 0.25 * sin(t * 1.3),
		"roll": 0.5 * sin(t * 0.7),
		"rudder": 0.3 * sin(t * 0.9),
		"throttle": 0.6 + 0.3 * sin(t * 0.5),
		"brake": 0.0,
	}
	if flight == "wheels":
		# Down the runway at full power, the pedals steering a little, and the stick back once it is rolling.
		hands["throttle"] = 1.0
		hands["roll"] = 0.0
		hands["rudder"] = 0.15 * sin(t * 0.8)
		hands["pitch"] = 0.4 if t > 6.0 else 0.0
	elif model == Sim.Model.HELICOPTER or model == Sim.Model.HOVER:
		# About the hover's collective, which the lever sits near on every helicopter here, and a hand gentle enough to
		# keep it in the air: the aeroplanes' half stick of roll put every helicopter on the slab inside ten seconds.
		hands["throttle"] = 0.5 + 0.06 * sin(t * 0.5)
		hands["roll"] = 0.12 * sin(t * 0.7)
		hands["pitch"] = 0.08 * sin(t * 1.3)
	# 0.0 on the lever means "let go" and leaves it where it was: never send exactly that.
	hands["throttle"] = maxf(float(hands["throttle"]), 0.002)
	return hands


## THE SUITE'S OWN MUTANT: a retune of one part in ten thousand must move the fingerprint.
func _the_fingerprint_sees_a_small_retune() -> void:
	var name: String = Sim.kind_name(PROBE_KIND)
	var plain: String = String(_lines.get("%s hands" % name, "")).get_slice(" ", 2)
	var tuned: String = _fly_twice(PROBE_KIND, "hands", PROBE_TUNE)
	_check("the_fingerprint_moves_when_one_number_moves_a_little",
		not plain.is_empty() and not tuned.is_empty() and plain != tuned,
		"%s hands: %s as built, %s with %s" % [name, plain, tuned, PROBE_TUNE])


func _write(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check("the_fingerprints_were_written", false, "could not open %s" % path)
		return
	var keys: Array = _lines.keys()
	keys.sort()
	for key in keys:
		file.store_line(String(_lines[key]))
	file.close()
	print("[flight_fingerprint] wrote %d lines to %s" % [keys.size(), path])


## EVERY LINE AGAINST THE SAVED ONES: the digest must match. The readable numbers are there for a person, not compared.
## With `--kind=`, only those kinds' saved lines are expected, so a file written for every kind serves a narrow run.
func _compare(path: String, only: PackedStringArray) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check("the_saved_fingerprints_were_read", false, "could not open %s" % path)
		return
	var saved: Dictionary = {}
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts: PackedStringArray = line.split(" ", false)
		if parts.size() >= 3 and (only.is_empty() or only.has(parts[0])):
			saved["%s %s" % [parts[0], parts[1]]] = parts[2]
	file.close()
	var moved: PackedStringArray = []
	for key in _lines:
		var digest: String = String(_lines[key]).get_slice(" ", 2)
		if not saved.has(key):
			moved.append("%s (new)" % key)
		elif saved[key] != digest:
			moved.append(key)
	for key in saved:
		if not _lines.has(key):
			moved.append("%s (gone)" % key)
	moved.sort()
	_check("every_fingerprint_matches_the_saved_ones", moved.is_empty(),
		"%d lines flown, %d saved, %d differ%s" % [_lines.size(), saved.size(), moved.size(),
			"" if moved.is_empty() else ": " + ", ".join(moved)])


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
