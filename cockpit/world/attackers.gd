extends Node
class_name Attackers
## AIRCRAFT THAT COME FOR A BOAT, SHOOT BADLY, AND CAN BE SHOT DOWN (lane/combat, 2026-09-18).
##
## Asked for on 2026-09-18: "we also need a AI that understands that it's goal is to persue and shoot (poorly) at a
## target, mostly so the target can kill them, make it not very good at flying, so they should take wider turns, fly
## not at top speed and be a generally bad shot."
##
## THE HOST'S, AND ONLY TACTICS. Each attacker is an ordinary autopilot (`Sim.spawn_ai_vehicle`) flown by the same
## mixers as all the island's traffic -- the levers a player's hands move -- and this only tells it where to go
## (`steer_ai`), how clumsily (`set_ai_manners`), where to lay a turret (`lay_ai_turret`) and when to pull the trigger
## (`ai_burst`). Ten times a second, not every tick: a pilot does not reconsider his whole plan 120 times a second, and
## the mixers hold the last ask in between.
##
## HOW BAD, in numbers, every one of them below:
##   an aeroplane flies at `SPEED_SHARE` of its top speed, banks no more than `BANK` (a quarter of a turn circle wider than
##   the island's traffic: 1 km at 70 m/s), rolls into it at `ROLL_RATE`, and makes GUN RUNS -- a long approach, a
##   shallow dive, a burst or two inside `RANGE` and `CONE` of the point it guesses the target will be at, a break at
##   `BREAK_AT` straight over it, and a wide turn round for another. It guesses `LEAD` of the target's own motion,
##   drawn fresh each run, lays each burst on that guess and holds it `AIM_ERROR` off, drawn fresh each burst.
##   a helicopter hovers `STANDOFF` off and drifts sideways round the target, nose on it, and lays its chin gun with the
##   same error.
##   anything damaged to thick smoke gives up and runs.
##   nothing flies below `FLOOR` over what is under it: an attacker that would be there in `LOOK_S` pulls up and breaks off.
##
## WHO MAY ATTACK: an aeroplane with a gun on its weapon selector (the light twin, the Savoia, and the jets once their
## guns land), and a helicopter with a turret gun (the Apache). `planes()` and `helicopters()` ask the tables.
##
## SPAWNED from the host's clipboard (the ATTACK section) and from the command line:
##   -- --attackers=planes:2,helis:1 [--attack-target=cb90|me]

## Seconds between two looks at the fight.
const THINK_S: float = 0.1
const SPEED_SHARE: float = 0.68
const BANK: float = 0.45
const ROLL_RATE: float = 0.35
## A helicopter's quickest turn, radians a second: a third of the traffic's 0.9.
const HELI_YAW_RATE: float = 0.3
## Where a gun run starts, and the heights of the run, over the target's surface.
const RUN_FROM: float = 2200.0
const APPROACH_UP: float = 380.0
const RUN_UP: float = 60.0
## THE DIVE, as the slope of the line to the target it flies down: 0.17 is ten degrees. And the climb or dive it may use
## to fly it, metres a second: ten degrees at 80 m/s is 14 m/s, and the gentle climb it was left with first was 8.
const DIVE: float = 0.17
const CLIMB_RATE: float = 18.0
## Gun range, the cone it fires in, and where it breaks off, metres and radians.
const RANGE: float = 900.0
## THE CONE IS 0.2 rad, ELEVEN DEGREES, and it was eight: a run flown with this bank and roll rate never brought the nose
## nearer than 0.12 rad to where it guessed, and fired nothing in three runs (tests/attackers.gd, 2026-09-19).
const CONE: float = 0.2
const BREAK_AT: float = 380.0
## How far it flies on after a break before it comes round again, metres.
const EXTEND: float = 1600.0
## A burst's length, the least gap between two, and the error it is held off by (a standard deviation, radians).
const BURST_S: float = 0.9
const BURST_GAP_S: float = 2.2
## 0.01 rad, TUNED ON THE RAID IN tests/attackers.gd (2026-09-19), aeroplanes' bursts laid on the guess: at 0.005 they
## struck 6%, 30% and 13%; at 0.01 0%, 8% and 0.6%, 10 of 381 rounds all told, and the boat still won in 176 s; at 0.014
## and above, nothing. It was 0.055, and struck nothing, because of the two faults `aim_point` and the run now put right.
const AIM_ERROR: float = 0.01
## The share of the true lead it guesses, drawn each run between these.
const LEAD: Vector2 = Vector2(0.6, 1.3)
## A helicopter's distance from the target, its height over it, how fast it drifts round, and its burst.
const STANDOFF: float = 800.0
const HELI_UP: float = 70.0
const DRIFT: float = 9.0
const HELI_BURST_S: float = 1.4
const HELI_GAP_S: float = 3.2
## Never lower than this over what is under it, and it looks this far ahead in time for the ground.
const FLOOR: float = 60.0
const HELI_FLOOR: float = 45.0
const LOOK_S: float = 3.0
## A helicopter further than this from its post flies to it nose first, at `HELI_TRANSIT`; nearer, it drifts round.
const HELI_NEAR: float = 350.0
const HELI_TRANSIT: float = 45.0
## Where a raid starts: this far out from the target, spread this far apart.
const SPAWN_OUT: float = 3500.0
const SPAWN_APART: float = 300.0

## Every attacker: host entity -> its state. See `_think`.
var attackers: Dictionary = {}
## For a test: aim with no error and the true lead (`--attack-aim=perfect`), which must make it a good shot.
var perfect: bool = false
## `--attack-error=`: the aim error, radians, for tuning; `AIM_ERROR` otherwise.
var aim_error: float = AIM_ERROR
## `--attack-trace`: once a second, a line per attacker -- phase, height over the surface, speed, range, bank.
var tracing: bool = false
var _traced: float = 0.0
var _dice := RandomNumberGenerator.new()
var _due: float = 0.0
var _clock: float = 0.0
var _asked: Dictionary = {}


func _ready() -> void:
	_dice.seed = 1917
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--attackers="):
			for part in argument.trim_prefix("--attackers=").split(",", false):
				var pair: PackedStringArray = part.split(":")
				if pair.size() == 2:
					_asked[pair[0]] = int(pair[1])
		elif argument.begins_with("--attack-target="):
			_asked["target"] = argument.trim_prefix("--attack-target=")
		elif argument.begins_with("--attack-error="):
			aim_error = float(argument.trim_prefix("--attack-error="))
		elif argument == "--attack-aim=perfect":
			perfect = true
		elif argument == "--attack-trace":
			tracing = true


## THE KINDS THAT MAY COME: aeroplanes with a gun on the selector, and helicopters with a turret gun a helmet lays.
static func planes() -> Array[int]:
	var out: Array[int] = []
	for kind in Sim.Kind.values():
		var schema: Dictionary = Sim.missile_schema(kind)
		if String(Sim.geometry_of(kind).get("model_name", "")) != "airplane":
			continue
		for station in schema.get("stations", []):
			if bool((station as Dictionary).get("gun", false)):
				out.append(kind)
				break
	return out


static func helicopters() -> Array[int]:
	var out: Array[int] = []
	for kind in Sim.Kind.values():
		if String(Sim.geometry_of(kind).get("model_name", "")) != "helicopter":
			continue
		var gun: Dictionary = Sim.gun_of(kind, 0)
		if bool(gun.get("fitted", false)) and not bool(gun.get("pintle", false)):
			out.append(kind)
	return out


## A RAID: `plane_count` aeroplanes of `plane_kind` and `heli_count` helicopters of `heli_kind` against the host's
## `target`, spawned `SPAWN_OUT` off it on one bearing. Returns the host's entities. Host only.
func raid(target: int, plane_count: int, heli_count: int, plane_kind: int = Sim.Kind.PLANE,
		heli_kind: int = Sim.Kind.APACHE) -> Array[int]:
	var made: Array[int] = []
	if Sim.server == null or target == 0:
		return made
	var at: Vector3 = Sim.server.vehicle_state(target).get("position", Vector3.ZERO)
	var bearing: float = _dice.randf_range(0.0, TAU)
	var out := Vector3(sin(bearing), 0.0, -cos(bearing))
	var across := Vector3(out.z, 0.0, -out.x)
	var surface: float = maxf(Terrain.surface_height(at), Terrain.SEA_LEVEL)
	for i in range(plane_count + heli_count):
		var heli: bool = i >= plane_count
		var kind: int = heli_kind if heli else plane_kind
		var from: Vector3 = at + out * (SPAWN_OUT * (0.7 if heli else 1.0)) \
			+ across * (float(i) - float(plane_count + heli_count - 1) * 0.5) * SPAWN_APART
		# OVER WHAT IS UNDER IT, not over the boat's sea: the first raid put an Apache 410 m inside a mountain.
		from.y = maxf(surface, _surface(from)) + (HELI_UP + 60.0 if heli else APPROACH_UP)
		# FACING THE TARGET: a compass heading is atan2(x, -z), and it flies along -out.
		var yaw: float = atan2(-out.x, out.z)
		var speed: float = 0.0 if heli else _flying_speed(kind)
		var entity: int = Sim.spawn_ai_vehicle(kind, from, yaw, -out * speed)
		if entity == 0:
			continue
		Sim.server.set_ai_manners(entity, {"bank": BANK, "roll_rate": ROLL_RATE, "yaw_rate": HELI_YAW_RATE,
			"climb_rate": CLIMB_RATE})
		attackers[entity] = {"kind": kind, "heli": heli, "target": target, "phase": "approach", "lead": 1.0,
			"next_burst": 0.0, "side": 1.0 if i % 2 == 0 else -1.0,
			# ITS POST STARTS ON ITS OWN SIDE of the target: put on the raid's bearing plus a share of a turn, the first
			# Apache's was 80 degrees round and it spent the whole fight flying to it.
			"orbit": atan2(from.x - at.x, -(from.z - at.z)),
			"extend_from": Vector3.ZERO, "closest": INF, "lowest": INF, "bank_most": 0.0}
		made.append(entity)
	print("[attackers] a raid of %d aeroplanes and %d helicopters on %d" % [plane_count, heli_count, target])
	return made


## Every attacker sent away and taken out of the world. Host only.
func clear() -> void:
	for entity in attackers.keys():
		Sim.server.despawn_vehicle(int(entity))
	attackers.clear()


func _physics_process(delta: float) -> void:
	if Sim.server == null:
		return
	_clock += delta
	if not _asked.is_empty() and Sim.is_ready and _clock > 2.0:
		_raid_as_asked()
	_due -= delta
	if _due > 0.0 or attackers.is_empty():
		return
	_due = THINK_S
	for entity in attackers.keys():
		var hull: Dictionary = Sim.server.hull_state(int(entity))
		if hull.is_empty() or bool(hull.get("destroyed", false)):
			# SHOT DOWN OR CRASHED: nothing to fly. The simulation retires the wreck.
			attackers.erase(entity)
			continue
		_think(int(entity), attackers[entity], hull)


## THE COMMAND LINE'S RAID, once the level has something to attack: the CB90 asked for (the first in the world, or one
## put to sea under way if there is none), or the host's own craft.
func _raid_as_asked() -> void:
	var asked: Dictionary = _asked
	_asked = {}
	var target: int = 0
	var called: String = String(asked.get("target", "cb90"))
	if called == "me":
		for pilot in Sim.server.pilot_states():
			if int((pilot as Dictionary)["client"]) == Sim.local_client_id():
				target = int((pilot as Dictionary)["vehicle"])
	else:
		target = boat_to_attack()
	raid(target, int(asked.get("planes", 0)), int(asked.get("helis", 0)))


## A CB90 UNDER WAY OFF THE ISLAND, put to sea by its own autopilot: the command line's and a test's target. Open water
## on every side, so a raid is a fight over the sea and not over the island's harbour and its hills.
func boat_to_attack() -> int:
	var sea := Vector3(0.0, 0.0, Terrain.WORLD_HALF + Terrain.OFFSHORE + 3000.0)
	return Sim.spawn_ai_vehicle(Sim.Kind.CB90, sea, 0.0, Vector3(0.0, 0.0, -10.0))


## ---- one attacker, ten times a second -----------------------------------------------------------------------------

func _think(entity: int, me: Dictionary, hull: Dictionary) -> void:
	var state: Dictionary = Sim.server.vehicle_state(entity)
	var target: int = int(me["target"])
	var aim: Dictionary = Sim.server.vehicle_state(target)
	if aim.is_empty() or bool(Sim.server.hull_state(target).get("destroyed", false)):
		me["phase"] = "home"
	var at: Vector3 = state["position"]
	var v: Vector3 = state["velocity"]
	var basis := Basis(state["basis"] as Quaternion)
	var surface: float = maxf(Terrain.surface_height(at), Terrain.SEA_LEVEL)
	me["lowest"] = minf(float(me["lowest"]), at.y - surface)
	var bank: float = absf(atan2(-(basis * Vector3.RIGHT).y, maxf((basis * Vector3.UP).y, 0.05)))
	me["bank_most"] = maxf(float(me["bank_most"]), bank)
	if tracing and _clock - float(me.get("traced", -1.0)) >= 1.0:
		me["traced"] = _clock
		var there_now: Vector3 = aim.get("position", at) if not aim.is_empty() else at
		print("[attackers] t %.0f %d %s: %.0f m up, %.0f m/s (vy %.1f), %.0f m off, bank %.2f, aim off %.2f, fired %s" % [
			_clock, entity, me["phase"], at.y - surface, v.length(), v.y, (there_now - at).length(), bank,
			float(me.get("off", -1.0)), Sim.server.ai_gunnery(entity)])
		if bool(me["heli"]):
			print("[attackers]     %d to its post %.0f m, heading off it %.2f rad" % [entity, float(me.get("post_off", -1.0)),
				float(me.get("heading_off", 0.0))])
	if int(hull.get("stage", 0)) >= 2 and me["phase"] != "home":
		me["phase"] = "home"
		print("[attackers] %d is hit hard and runs for home" % entity)
	if me["phase"] == "home" or aim.is_empty():
		_run_for_home(entity, me, at, surface)
		return
	var there: Vector3 = aim["position"]
	me["closest"] = minf(float(me["closest"]), (there - at).length())
	if bool(me["heli"]):
		_hover_and_shoot(entity, me, at, v, basis, there, aim["velocity"] as Vector3, surface)
	else:
		_gun_run(entity, me, at, v, basis, there, aim["velocity"] as Vector3, surface)


## AN AEROPLANE'S GUN RUNS: approach, run in shooting, break over the top, extend, and round again.
func _gun_run(entity: int, me: Dictionary, at: Vector3, v: Vector3, basis: Basis, there: Vector3, going: Vector3,
		surface: float) -> void:
	var speed: float = _flying_speed(int(me["kind"]))
	var flat: Vector3 = Vector3(there.x - at.x, 0.0, there.z - at.z)
	var range_now: float = flat.length()
	var target_surface: float = maxf(Terrain.surface_height(there), Terrain.SEA_LEVEL)
	var floor_at: float = surface + FLOOR
	# THE GROUND FIRST: where it will be in `LOOK_S` if it goes on as it is going.
	var ahead: Vector3 = at + v * LOOK_S
	var ahead_floor: float = _surface(ahead) + FLOOR
	var too_low: bool = at.y < floor_at or ahead.y < ahead_floor
	# THE HIGHEST SURFACE ABOUT IT, here, ahead and at the target: every height asked for is over that.
	var over: float = maxf(maxf(surface, _surface(ahead)), target_surface)
	match String(me["phase"]):
		"approach":
			_steer(entity, there, over + APPROACH_UP, speed)
			if range_now < RUN_FROM:
				me["phase"] = "run"
				# A GUESS AT THE LEAD, fresh each run: somewhere between a third and a third again of the right one.
				me["lead"] = 1.0 if perfect else _dice.randf_range(LEAD.x, LEAD.y)
		"run":
			# FLOWN AT THE PLAIN LEAD FROM AFAR, and at the gun's own aim point once in range: a rifle round's time of flight
			# grows as e^(kd), and at eight kilometres the aim point was thousands of metres behind the boat -- both
			# aeroplanes flew away from it after their first pass (tests/attackers.gd, 2026-09-19).
			var guess: Vector3 = there + going * (range_now / 850.0) * float(me["lead"])
			if range_now < RANGE * 1.3:
				var gun: Dictionary = _selector_gun(int(me["kind"]))
				guess = aim_point(at + (basis * (gun.get("at", Vector3.ZERO) as Vector3)), v, there, going,
					int(gun.get("ammo", 7)), float(gun.get("muzzle", 850.0)), float(me["lead"]))
			# DOWN THE SLOPE TO THE TARGET, never under the floor here or ahead.
			# THE SLOPE ENDS ON THE TARGET, so the line to it and the line flown are one line; it ended `RUN_UP` over it
			# first, and the boat sat five degrees under the nose all the way in.
			_steer(entity, guess, maxf(target_surface + range_now * DIVE, maxf(floor_at, ahead_floor)), speed)
			var nose: Vector3 = basis * Vector3.FORWARD
			var off: float = nose.angle_to(guess - at)
			me["off"] = off
			if range_now < RANGE and off < CONE and _clock >= float(me["next_burst"]) and not too_low:
				# THE BURST GOES WHERE THE PILOT GUESSED, not down the nose: the nose is only ever somewhere in the cone,
				# and fired down the nose every round of three runs missed -- 0 of 108 each at 0.055 and at 0.03, the
				# error making no difference at all (tests/attackers.gd, 2026-09-19). The badness is the guess and the
				# error, as the Apache's is.
				var gun_at: Vector3 = at + basis * (_selector_gun(int(me["kind"])).get("at", Vector3.ZERO) as Vector3)
				var local: Vector3 = basis.inverse() * (guess - gun_at)
				_burst(entity, me, BURST_S, -1, atan2(-local.x, -local.z), atan2(local.y, Vector2(local.x, local.z).length()))
				me["next_burst"] = _clock + BURST_S + BURST_GAP_S
			if range_now < BREAK_AT or too_low:
				me["phase"] = "extend"
				me["extend_from"] = there
				me["side"] = -float(me["side"])
		"extend":
			# ON PAST IT AND OFF TO ONE SIDE, climbing back to the approach height: the wide way round.
			var from: Vector3 = me["extend_from"]
			var away: Vector3 = Vector3(at.x - from.x, 0.0, at.z - from.z)
			var out: Vector3 = (basis * Vector3.FORWARD) * Vector3(1.0, 0.0, 1.0)
			var aside := Vector3(out.z, 0.0, -out.x) * float(me["side"])
			_steer(entity, at + (out.normalized() + aside * 0.4) * 800.0, over + APPROACH_UP, speed)
			if away.length() > EXTEND:
				me["phase"] = "approach"
	if too_low and String(me["phase"]) != "extend":
		_steer(entity, at + v.normalized() * 600.0, floor_at + 150.0, speed)


## A HELICOPTER'S: hold off at `STANDOFF`, drift sideways round the target with its nose on it, and fire the chin gun.
func _hover_and_shoot(entity: int, me: Dictionary, at: Vector3, v: Vector3, basis: Basis, there: Vector3,
		going: Vector3, surface: float) -> void:
	me["orbit"] = float(me["orbit"]) + DRIFT / STANDOFF * THINK_S * float(me["side"])
	var bearing: float = float(me["orbit"])
	var post: Vector3 = there + Vector3(sin(bearing), 0.0, -cos(bearing)) * STANDOFF
	var target_surface: float = maxf(Terrain.surface_height(there), Terrain.SEA_LEVEL)
	var height: float = maxf(target_surface + HELI_UP, maxf(_surface(post), surface) + HELI_FLOOR)
	var to_post: Vector3 = Vector3(post.x - at.x, 0.0, post.z - at.z)
	var face: float = atan2(there.x - at.x, -(there.z - at.z))
	var nose := Vector3(sin(face), 0.0, -cos(face))
	var right := Vector3(-nose.z, 0.0, nose.x)
	me["post_off"] = to_post.length()
	me["heading_off"] = angle_difference(atan2((basis * Vector3.FORWARD).x, -(basis * Vector3.FORWARD).z),
		atan2(to_post.x, -to_post.z))
	if to_post.length() > HELI_NEAR:
		# FAR FROM ITS POST: nose first to it, as a helicopter goes anywhere.
		Sim.server.steer_ai(entity, {"toward": post, "altitude": height, "speed": HELI_TRANSIT})
	else:
		Sim.server.steer_ai(entity, {"toward": there, "altitude": height, "face": face,
			"speed": clampf(to_post.dot(nose) * 0.08, -8.0, 8.0),
			"bank": clampf(to_post.dot(right) * 0.004, -0.14, 0.14)})
	# THE CHIN GUN, laid on where it guesses the target will be, in the helicopter's own frame, and off by the error.
	var range_now: float = (there - at).length()
	var chin: Dictionary = Sim.gun_of(int(me["kind"]), 0)
	var muzzle: Vector3 = at + basis * (chin.get("at", Vector3.ZERO) as Vector3)
	var guess: Vector3 = aim_point(muzzle, v, there, going, int(chin.get("ammo", 4)),
		float(chin.get("muzzle", 805.0)), 1.0 if perfect else float(me["lead"]))
	var local: Vector3 = basis.inverse() * (guess - muzzle)
	var yaw: float = atan2(-local.x, -local.z)
	var pitch: float = atan2(local.y, Vector2(local.x, local.z).length())
	Sim.server.lay_ai_turret(entity, 0, yaw, pitch)
	# ON STATION ONLY: a burst fired flying to its post at 45 m/s went wherever the helicopter was going.
	if to_post.length() <= HELI_NEAR and range_now < STANDOFF * 1.5 and _clock >= float(me["next_burst"]):
		if not perfect:
			me["lead"] = _dice.randf_range(LEAD.x, LEAD.y)
		_burst(entity, me, HELI_BURST_S, 0)
		me["next_burst"] = _clock + HELI_BURST_S + HELI_GAP_S


func _run_for_home(entity: int, me: Dictionary, at: Vector3, surface: float) -> void:
	var out := Vector3(at.x, 0.0, at.z).normalized() if Vector3(at.x, 0.0, at.z).length() > 1.0 else Vector3.BACK
	_steer(entity, at + out * 5000.0, surface + (HELI_UP + 60.0 if bool(me["heli"]) else APPROACH_UP + 200.0),
		_flying_speed(int(me["kind"])))


## WHERE TO POINT A GUN AT `there`, moving at `going`, from a muzzle at `muzzle` moving at `own`: the target where it will
## be when the round arrives -- by `lead_share` of the true lead, which is the bad pilot's guess -- held up by the round's
## drop over the same time. The time of flight is the round's own, from its drag in the simulation's table (a round
## slows as a = -k v^2, so it covers d in (e^(kd) - 1) / (k v0)), worked out twice, the second time to where the first
## put the target.
##
## BEFORE THIS the helicopter aimed at the target's middle with the range over the muzzle speed as its time and no drop,
## and the gunner in the test aimed from the boat's middle rather than its muzzle: with perfect aim both hit NOTHING --
## 0 of 178 chin-gun rounds at 900 m, where a 25 mm round falls ten metres, and a boat's M2 laid 1.5 m wide of a pod at
## 300 m (tests/aim_probe, 2026-09-19). A bad shot is the errors put in on purpose, not a sight that cannot hit.
static func aim_point(muzzle: Vector3, own: Vector3, there: Vector3, going: Vector3, ammo: int, muzzle_speed: float,
		lead_share: float) -> Vector3:
	var k: float = _drag_of(ammo)
	var at: Vector3 = there
	var seconds: float = 0.0
	for i in range(2):
		var d: float = (at - muzzle).length()
		var v0: float = maxf(muzzle_speed, 1.0)
		seconds = (exp(k * d) - 1.0) / (k * v0) if k > 0.0 else d / v0
		at = there + (going - own) * seconds
	# THE GUESS IS ONLY OF THE TARGET'S OWN MOTION; the shooter's own is always allowed for, as a sight does. Scaling both
	# put an aeroplane's rounds tens of metres off at 77 m/s -- 0 of 108 struck whatever the error, where the true lead
	# struck 9% and 60% (tests/attackers.gd, 2026-09-19).
	return there + (going * lead_share - own) * seconds + Vector3.UP * 4.905 * seconds * seconds


## A round's drag, the k in a = -k v^2, off the simulation's table.
static func _drag_of(ammo: int) -> float:
	for row in Sim.gun_of(Sim.Kind.TANK, 0).get("rounds", []):
		if int((row as Dictionary).get("ammo", -1)) == ammo:
			return float((row as Dictionary).get("drag", 0.0))
	return 0.0


## The gun on a kind's weapon selector, as `missile_schema` gives it: where it is, its round, its muzzle speed.
static func _selector_gun(kind: int) -> Dictionary:
	for station in Sim.missile_schema(kind).get("stations", []):
		if bool((station as Dictionary).get("gun", false)):
			return station
	return {}


## The ground or the sea under a point, whichever is higher.
static func _surface(at: Vector3) -> float:
	return maxf(Terrain.surface_height(at), Terrain.SEA_LEVEL)


## A BURST of `seconds`, laid `laid_yaw` and `laid_pitch` off where the gun points, and off by the error on top.
func _burst(entity: int, me: Dictionary, seconds: float, mount: int, laid_yaw: float = 0.0,
		laid_pitch: float = 0.0) -> void:
	var yaw: float = laid_yaw + (0.0 if perfect else _dice.randfn(0.0, aim_error))
	var pitch: float = laid_pitch + (0.0 if perfect else _dice.randfn(0.0, aim_error))
	if not Sim.server.ai_burst(entity, seconds, yaw, pitch, mount) and tracing:
		print("[attackers] %d: the burst was refused" % entity)


func _steer(entity: int, toward: Vector3, altitude: float, speed: float) -> void:
	# NEVER UNDER ITS CRUISE: slower, the mixer's climb turns into a descent (see `steer_ai`).
	Sim.server.steer_ai(entity, {"toward": toward, "altitude": altitude, "speed": speed, "cruise_floor": true})


## `SPEED_SHARE` OF WHAT FULL THRUST HOLDS AGAINST DRAG, the same flat-out the simulation's own cruise is a share of.
static func _flying_speed(kind: int) -> float:
	var h: Dictionary = Sim.handling_of(kind)
	var top: float = sqrt(maxf(float(h.get("thrust", 1.0)), 1.0) / maxf(float(h.get("drag_forward", 0.05)), 0.05))
	return clampf(top * SPEED_SHARE, 40.0, 160.0)


## ---- for the tests and the page --------------------------------------------------------------------------------

## One attacker's record: its phase, the closest it came, its lowest over the surface and its steepest bank.
func record_of(entity: int) -> Dictionary:
	return attackers.get(entity, {})
