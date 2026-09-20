extends Node3D
class_name ShotYard
## EVERY ROUND IN THE AIR, DRAWN -- AND EVERY MACHINE DRAWS THEM ALL.
##
## The wire carries a round twice: once when it leaves the barrel and once when it lands.
## See `ShotState`. Everything between those two moments is drawn from the birth record, by
## whoever is looking, which is why a shell fired by somebody else is visible to you at all.
##
## THREE THINGS THIS HAS TO GET RIGHT, and they are the three that make a tracer read as a
## round rather than as a dot:
##
##   IT IS A STREAK, NOT A POINT. 1700 m/s is fourteen metres in a physics tick and
##   twenty-eight in a frame. Drawn as a ball, a shell is invisible between frames and a
##   burst of them is a stroboscope; drawn as a length of light along its own velocity it
##   reads as one continuous thing, which is what a tracer looks like and why they exist.
##
##   IT HAS A FLOOR ON ITS SIZE. A 120 mm round is a tenth of a metre across, which at two
##   kilometres is a fraction of a pixel. The same problem the spotting boxes solve, solved
##   the same way: it is never drawn thinner than a couple of pixels' worth at its range,
##   so a gunship working a target below you is something you can see from the ground.
##
##   IT STARTS WHERE IT ALREADY IS. A record that took a round trip to arrive describes a
##   round that has been flying for a round trip, so the flight is wound forward by the
##   latency before it is drawn. Otherwise every remote shell starts at the muzzle late and
##   crawls after an aeroplane that has already moved on.

const BURST := preload("res://objects/weapons/burst.gd")

## How thin a round may look, as a fraction of its distance from the eye. About two pixels
## at a 70-degree field of view on a 1080p screen.
const THINNEST: float = 0.0018
## How many bursts may be going at once before the oldest is taken for the newest.
const BURSTS: int = 24

## A ROUND WAS BORN, drawn here for the first time: who fired it (-1 for nobody's finger), from which of their craft's
## mounts, and what it is. Announced, not acted on -- the level decides whose hand, if anybody's, feels it.
signal round_left(shooter: int, mount: int, ammo: int)

var _live: Dictionary = {}
var _bursts: Array[Burst] = []
var _next_burst: int = 0
## WHERE A HEAVY ROUND'S EXPLOSION IS DRAWN: the level's yard, handed in before this is added so the sky has one cap
## for shells and missiles together. A yard built on its own -- a test's -- makes one of its own.
var bursts: BurstYard = null
## THE ROUNDS ALREADY LANDED, so each goes off once. A landed record stays on the list for as long as the simulation keeps
## it before retiring it -- three ticks once, half a second since cockpit-netjump made the retire long enough to reach a
## joined machine -- and this draws every frame, so without it one 105 would set off an explosion a frame for half a
## second and take the whole pool. Forgotten when the row goes.
var _landed: Dictionary = {}


func _ready() -> void:
	if bursts == null:
		bursts = BurstYard.new()
		bursts.name = "Bursts"
		add_child(bursts)


## HOW LONG A PREDICTED SHELL'S DIFFERENCE FROM THE SERVER'S IS BLENDED AWAY OVER, seconds. Linear, so the most it moves
## the drawn shell in a tick is the difference over 120 ticks, where the shell itself moves 3.3 m a tick
## (tests/shell_prediction.gd holds a 0.25 m budget on that step). A SECOND, not the half second first chosen: over a
## 16-tick link the server acts on the trigger five frames after the gunner's machine fired, the drawn shell is re-anchored
## 16.5 m back onto the one the server fired, and over half a second that pull was 0.275 m a tick (2026-09-16). Over this
## second it is a 16 m pull at 0.134 m a tick, the worst step the suite measured over the shell's whole drawn life. The
## late trigger itself was ashiato-sync's input starvation at that latency, fixed by lane/starve: since, the same link
## hands over with a 0.00 m gap and a 0.004 m worst step, and this second is what a late trigger still costs where one
## happens -- at 4 ticks through the suite's held packets it still does.
const BLEND_S: float = 1.0
## How long a predicted shell is drawn waiting for the server's record before it is given up on, seconds. A confirmed shell
## arrives within a round trip; a refused one is withdrawn by its cue. This is only for a record that never comes.
const UNCLAIMED_S: float = 5.0
## HOW LONG A WITHDRAWN SHELL IS STILL DRAWN: 50 ms, in case the same shell is fired again straight away. It is, whenever
## the server acts on the trigger a few frames after the gunner's machine predicted it: each frame's prediction is taken
## back by the server's frame and the gunner's machine fires the same numbered shell again, until they agree -- five times
## over a 16-tick link, every withdrawal "server_mismatch" (tests/shell_prediction.gd, 2026-09-16). MEASURED there: the
## same shell was played again 1 tick (8 ms) after a withdrawal, and 3 ticks (25 ms) at the longest, so 50 ms is those
## three ticks doubled. Removed and redrawn, it was a shell flickering out of the barrel; kept and RE-ANCHORED, it is one.
##
## THE COST, said plainly: a grace cannot tell a late trigger from a refusal, so a shell the server truly refused stays on
## screen this long after the refusal reaches the gunner -- and no longer, which the suite holds (grace and a tick).
const WITHDRAWN_GRACE_S: float = 0.05

## THE SHELLS THIS MACHINE'S GUNNER FIRED AND IS DRAWING AHEAD OF THE SERVER, by `_shell_key`: a round dictionary like
## `_live`'s, until the server's record for it arrives and it moves there.
var _predicted: Dictionary = {}


## ONE FRAME OF EVERY ROUND. `shots` is `Sim.shots`, `eye` is where the camera is, and
## `late` is how far behind the server this machine is drawing -- see the note above.
##
## `cues` IS WHAT THIS MACHINE'S GUNNER HAS FIRED SINCE THE LAST FRAME (`Sim.take_shells_cued`) and `me` is who this
## machine is. A played cue starts a shell drawn at once from the muzzle it carries; a withdrawn one takes it away; and
## when the server's record for it arrives, the drawn shell is HANDED OVER to it -- see `_adopt`.
func draw_shots(shots: Array, eye: Vector3, delta: float, late: float = 0.0, cues: Array = [], me: int = -1) -> void:
	for row in cues:
		_cued(row as Dictionary, me)
	var seen: Dictionary = {}
	for row in shots:
		var shot: Dictionary = row
		var entity: int = int(shot["entity"])
		seen[entity] = true
		if bool(shot["flying"]) and not _live.has(entity) and me >= 0 and int(shot.get("shooter", -1)) == me \
				and int(shot.get("shell", 0)) > 0:
			_adopt(entity, shot, me)
		if bool(shot["flying"]):
			_fly(entity, shot, eye, delta, late)
		elif not _landed.has(entity):
			_landed[entity] = true
			_land(entity, shot)
	# A ROUND THAT SIMPLY WENT AWAY. It was retired between one frame and the next without
	# this machine ever seeing the landed record -- a packet lost, or a session ending --
	# and the honest thing is to take the tracer away rather than leave it flying for ever.
	for entity in _live.keys():
		if not seen.has(entity):
			_forget(entity)
	for entity in _landed.keys():
		if not seen.has(entity):
			_landed.erase(entity)
	# AND THE SHELLS DRAWN AHEAD OF THE SERVER, until it answers.
	for key in _predicted.keys():
		var ahead: Dictionary = _predicted[key]
		fly_for(ahead, delta)
		_place(ahead, eye)
		if ahead.has("withdrawn_left"):
			ahead["withdrawn_left"] = float(ahead["withdrawn_left"]) - delta
		if float(ahead["clock"]) > UNCLAIMED_S or float(ahead.get("withdrawn_left", 1.0)) <= 0.0:
			(ahead["node"] as Node3D).queue_free()
			_predicted.erase(key)


## WHICH SHELL: who fired it, from which mount, and its number. The server's record and the cue both carry all three.
static func _shell_key(shooter: int, mount: int, shell: int) -> String:
	return "%d:%d:%d" % [shooter, mount, shell]


## A SHELL THIS MACHINE'S GUNNER FIRED, OR ONE THE SERVER DID NOT. See ShellCue.
func _cued(cue: Dictionary, me: int) -> void:
	var key: String = _shell_key(me, int(cue.get("mount", -1)), int(cue.get("shell", -1)))
	if bool(cue.get("withdrawn", false)):
		if _predicted.has(key):
			(_predicted[key] as Dictionary)["withdrawn_left"] = WITHDRAWN_GRACE_S
		return
	if _predicted.has(key):
		var kept: Dictionary = _predicted[key]
		if kept.has("withdrawn_left"):
			_reanchor(kept, cue)
		return
	var shot: Dictionary = {"ammo": int(cue.get("ammo", 0)), "from": cue["from"], "velocity": cue["velocity"]}
	var ahead: Dictionary = {
		"node": _tracer(shot),
		"at": cue["from"] as Vector3,
		"ticked": cue["from"] as Vector3,
		"velocity": cue["velocity"] as Vector3,
		"drag": float(cue.get("drag", 0.0)),
		"age": 0.0,
		"clock": 0.0,
		"key": key,
		"ammo": int(cue.get("ammo", 0)),
	}
	_predicted[key] = ahead
	# AND IT MAKES ITS NOISE NOW, where the gunner is, which is the point of predicting it: the bang and the kick arrive
	# with the trigger. The server's record, when it comes, is adopted silently -- see `_adopt`.
	VehicleSound.report(self, cue["from"] as Vector3,
		float(Ammunition.look(int(ahead["ammo"])).get("calibre", 0.10)) / 0.10)
	round_left.emit(me, int(cue.get("mount", 0)), int(ahead["ammo"]))
	fly_for(ahead, float(cue.get("late", 0.0)))


## THE SAME SHELL FIRED AGAIN WHILE ITS WITHDRAWAL WAS STILL IN GRACE: it continues from where it is drawn, flown from the
## new cue's muzzle from here on, with the difference blended away over `BLEND_S` exactly as a handover is. No second bang.
func _reanchor(kept: Dictionary, cue: Dictionary) -> void:
	var shown: Vector3 = kept.get("shown", kept["at"]) as Vector3
	var fresh: Dictionary = {"at": cue["from"] as Vector3, "ticked": cue["from"] as Vector3,
		"velocity": cue["velocity"] as Vector3, "drag": float(cue.get("drag", 0.0)), "age": 0.0, "clock": 0.0}
	fly_for(fresh, float(cue.get("late", 0.0)))
	for field in ["at", "ticked", "velocity", "drag", "age", "clock"]:
		kept[field] = fresh[field]
	kept["offset"] = shown - (fresh["at"] as Vector3)
	kept["blend"] = BLEND_S
	kept.erase("withdrawn_left")


## THE SERVER'S RECORD FOR A SHELL THIS MACHINE IS ALREADY DRAWING: HANDED OVER, NOT REDRAWN.
##
## WHAT IT MATCHES ON: the shooter, the mount and the shell number -- the three `ShotState` and `ShellCue` both carry, and
## the three a resimulation cannot change (see `CockpitWorld::work_a_predicted_gun`). Not the muzzle, which the two
## machines worked out from a ship one of them was drawing a packet late.
##
## HOW: the server's shell is flown from its own birth record to the SAME age the drawn one has reached -- both started at
## the frame the gunner fired -- and becomes the shell from here on. The difference between where the drawn one was and
## where the server's is at that age is the GAP, kept as an offset and taken away over `BLEND_S`, so the gunner watching
## their fall of shot never sees the arc jump.
func _adopt(entity: int, shot: Dictionary, me: int) -> void:
	var key: String = _shell_key(me, int(shot.get("mount", -1)), int(shot.get("shell", -1)))
	if not _predicted.has(key):
		return
	var ahead: Dictionary = _predicted[key]
	_predicted.erase(key)
	ahead.erase("withdrawn_left")
	var shown: Vector3 = ahead.get("shown", ahead["at"]) as Vector3
	var server: Dictionary = {
		"at": shot["from"] as Vector3, "ticked": shot["from"] as Vector3, "velocity": shot["velocity"] as Vector3,
		"drag": float(shot["drag"]), "age": 0.0, "clock": 0.0,
	}
	fly_for(server, float(ahead["clock"]))
	ahead["at"] = server["at"]
	ahead["ticked"] = server["ticked"]
	ahead["velocity"] = server["velocity"]
	ahead["drag"] = server["drag"]
	ahead["age"] = server["age"]
	ahead["clock"] = server["clock"]
	# THE HANDOVER'S OWN GAP: where the drawn shell's flight has got to against the server's at the same age -- NOT counting
	# an offset still being blended from a re-anchor (see `_reanchor`), which carries on into this one.
	ahead["gap"] = (ahead["at"] as Vector3).distance_to(server["at"] as Vector3)
	ahead["carried"] = (shown - (ahead["at"] as Vector3)).length()
	ahead["offset"] = shown - (server["at"] as Vector3)
	ahead["blend"] = BLEND_S
	ahead["handed_over"] = true
	_live[entity] = ahead


## WHERE A SHELL THIS MACHINE FIRED IS DRAWN: {"at", "velocity", "handed_over", "gap"}, or {} when it is not in the air.
## For the tests, which watch the handover from the outside.
func drawn_shell(shooter: int, mount: int, shell: int) -> Dictionary:
	var key: String = _shell_key(shooter, mount, shell)
	var found: Dictionary = _predicted.get(key, {})
	if found.is_empty():
		for entity in _live:
			if String((_live[entity] as Dictionary).get("key", "")) == key:
				found = _live[entity]
	if found.is_empty():
		return {}
	return {"at": found.get("shown", found["at"]), "velocity": found["velocity"],
		"handed_over": bool(found.get("handed_over", false)), "gap": float(found.get("gap", -1.0)),
		"carried": float(found.get("carried", 0.0))}


func _fly(entity: int, shot: Dictionary, eye: Vector3, delta: float, late: float) -> void:
	var round_now: Dictionary = _live.get(entity, {})
	if round_now.is_empty():
		round_now = {
			"node": _tracer(shot),
			"at": shot["from"] as Vector3,
			"velocity": shot["velocity"] as Vector3,
			"drag": float(shot["drag"]),
			# HOW LONG IT HAS BEEN GOING. Nothing needs it for a shell -- a tracer is the
			# same tracer all the way down -- and a mass of water spreads as it falls,
			# which is the whole reason a drop has to be made low.
			"age": 0.0,
			# HOW LONG THIS MACHINE HAS DRAWN IT FOR, which runs ahead of `age` by less than a tick. See `fly_for`.
			"clock": 0.0,
			# Where the last whole tick left it, which `at` is drawn onward from.
			"ticked": shot["from"] as Vector3,
		}
		_live[entity] = round_now
		# AND IT MAKES A NOISE AT THE MUZZLE. A round is born once, here, which is the only
		# edge there is -- the record is a birth record and every machine that can see the
		# entity gets it, so a gunship working a target is heard from the ground exactly as
		# its tracers are seen from there.
		#
		# Water is silent: six tonnes leaving a tanker is not a gun. `is_wet` is asked
		# rather than the ammunition number compared, for the reason written on it.
		var ammo: int = int(shot["ammo"])
		if not Ammunition.is_wet(ammo):
			# The calibre the renderer already keeps, turned into a weight. One table, and
			# the sound of a round and the look of it cannot disagree about how big it is.
			VehicleSound.report(self, shot["from"] as Vector3,
				float(Ammunition.look(ammo).get("calibre", 0.10)) / 0.10)
			round_left.emit(int(shot.get("shooter", -1)), int(shot.get("mount", 0)), ammo)
		# WOUND FORWARD BY THE LATENCY, in the same steps the server took, so a round that
		# arrives late is where it would have been rather than back at the barrel.
		fly_for(round_now, late)
	else:
		fly_for(round_now, delta)
	_place(round_now, eye)
	var node: MeshInstance3D = round_now["node"]
	var at: Vector3 = round_now["shown"]
	var look: Dictionary = Ammunition.look(int(shot["ammo"]))
	# The streak is a fixed LENGTH in metres and the thickness is what has a floor: a round
	# stretched to stay visible would be a round that gets longer as it goes away.
	var thick: float = maxf(float(look["calibre"]),
		eye.distance_to(at) * THINNEST)
	# AND IT BREAKS UP ON THE WAY DOWN. A mass of water leaves the tank as a mass and
	# arrives as rain: it spreads as it falls, which is why a drop made high is a drop that
	# waters a hillside evenly and puts nothing out. `age` is how long this one has been
	# going, which every machine works out for itself from the birth record.
	if bool(look.get("wet", false)):
		var spread: float = 1.0 + float(round_now.get("age", 0.0)) * 1.6
		node.scale = Vector3(thick * spread, thick * spread,
			float(look["streak"]) * spread)
		return
	node.scale = Vector3(thick, thick, float(look["streak"]))


## WHERE A ROUND IS DRAWN THIS FRAME: its flight, plus whatever is left of a handed-over shell's offset (see `_adopt`).
func _place(round_now: Dictionary, eye: Vector3) -> void:
	var at: Vector3 = round_now["at"]
	if round_now.has("offset"):
		var left: float = maxf(float(round_now.get("blend", 0.0)), 0.0)
		at += (round_now["offset"] as Vector3) * (left / BLEND_S)
	round_now["shown"] = at
	var node: MeshInstance3D = round_now["node"]
	var flew: Vector3 = round_now["velocity"]
	node.global_position = at
	if flew.length_squared() > 0.01:
		node.look_at_from_position(at, at + flew, Vector3.UP)


## THE SERVER'S TICK, which a round is flown in whole steps of: `step_round` in the simulation flies it at 120 Hz.
const TICK: float = 1.0 / 120.0


## FLY A ROUND ON BY `seconds` OF THIS MACHINE'S DRAWING, IN THE SERVER'S OWN STEPS.
##
## It was one step of `delta`, whatever the frame rate: at 90 or 72 Hz that is a coarser integration than the server's,
## and over a battleship shell's thirteen seconds it drew the splash 6.7 and 7.8 m from where the server burst it
## (tests/big_guns.gd, 2026-09-16) -- a fall of shot the gunner reads, landing in the wrong place. So the round is flown
## in whole server ticks, exactly as the server flew it, and drawn between them: `at` is the last whole tick moved on by
## its velocity for the part of a tick the clock is past it. A drawn point, never stepped from.
static func fly_for(round_now: Dictionary, seconds: float) -> void:
	round_now["clock"] = float(round_now.get("clock", 0.0)) + seconds
	if round_now.has("blend"):
		round_now["blend"] = float(round_now["blend"]) - seconds
	if not round_now.has("ticked"):
		round_now["ticked"] = round_now["at"]
	round_now["at"] = round_now["ticked"]
	while float(round_now["age"]) + TICK <= float(round_now["clock"]) + 0.000001:
		_step(round_now, TICK)
	round_now["ticked"] = round_now["at"]
	var over: float = float(round_now["clock"]) - float(round_now["age"])
	round_now["at"] = (round_now["ticked"] as Vector3) + (round_now["velocity"] as Vector3) * maxf(over, 0.0)


## Integrate one step of the same flight the server is integrating: quadratic drag, and the
## coefficient comes off the wire with the round rather than out of a table over here.
static func _step(round_now: Dictionary, delta: float) -> void:
	var flew: Vector3 = round_now["velocity"]
	var slow: float = float(round_now["drag"]) * flew.length()
	flew += (-flew * slow + Vector3.DOWN * 9.81) * delta
	round_now["velocity"] = flew
	round_now["at"] = (round_now["at"] as Vector3) + flew * delta
	round_now["age"] = float(round_now.get("age", 0.0)) + delta


func _land(entity: int, shot: Dictionary) -> void:
	var what: int = int(shot["surface"])
	_forget(entity)
	if not Ammunition.explodes(what):
		return
	# A HEAVY SHELL IS A BIG EXPLOSION, sized from the simulation's calibre -- the gunship's 40 mm and 105 mm and a
	# tank's HE. Everything lighter stays a `Burst`: a machine gun's hit is a puff, and thirty fireballs a second from a
	# 25 mm would be a wall. See BurstTuning.
	var ammo: int = int(shot["ammo"])
	if BurstTuning.is_heavy(ammo) and bursts != null:
		var heavy: HeavyBurst = bursts.set_off(shot["impact"] as Vector3, BurstTuning.fireball_for_round(ammo), true,
			float(Ammunition.surface(what).get("smoke", 1.0)), float(entity % 97) * 0.4)
		if heavy != null:
			return
	var burst: Burst = _a_burst()
	if burst != null:
		burst.light(shot["impact"] as Vector3, Ammunition.look(ammo), Ammunition.surface(what))


## A GUSH OF WATER LEAVING AN AEROPLANE, drawn once, where the doors opened.
##
## THIS IS THE FAR END OF A CUE, and it is the one effect in the game that is not derived
## from a state somebody could read twice. Six tonnes starting to leave is a MOMENT: the
## doors being open is on the wire and stays true for the next five seconds, and the first
## white burst out of the belly happens once, at a frame everybody agrees on. See CraftCue.
##
## `full` is how much was in the tank, 0 to 1, and it is the size of the burst -- a quarter
## tank does not make the same mess as a full one. `late` is how far behind the frame it
## happened on this machine is drawing, which is how far INTO the effect it should start:
## a burst that always began at its beginning would be a burst that lags the aeroplane by
## the length of the wire.
func release(at: Vector3, full: float, late: float = 0.0) -> void:
	var burst: Burst = _a_burst()
	if burst == null:
		return
	var look: Dictionary = Ammunition.look(WATER).duplicate()
	# ABOUT THE WIDTH OF THE AEROPLANE, and no more. The first version scaled the arrival
	# splash UP and drew a twenty-five metre cloud that swallowed the whole aircraft: what
	# leaves the tank is a sheet the width of the hull, and it is what ARRIVES a hundred and
	# fifty metres further on that is spread out.
	look["dust"] = 3.2 + full * 3.4
	look["sparks"] = int(round(float(look.get("sparks", 14)) * (0.4 + full * 0.6)))
	look["spark_speed"] = 7.0
	look["seconds"] = 0.9
	burst.light(at, look, {"dust": 1.0, "smoke": 0.0, "sparks": 1.0,
		"dust_colour": Color(0.88, 0.94, 0.98)})
	burst.wind_on(late)


## Which round is water, for the release above. The renderer's table and the simulation's
## agree about this number -- see the test that checks they name the same rounds.
const WATER: int = 8


func _forget(entity: int) -> void:
	var round_now: Dictionary = _live.get(entity, {})
	if round_now.is_empty():
		return
	(round_now["node"] as Node3D).queue_free()
	_live.erase(entity)


## ---- the pool ----------------------------------------------------------------------

## WHAT ONE THING IN THE AIR LOOKS LIKE, and there are two answers.
##
## A TRACER IS LIGHT. It is a box drawn along its own velocity in ADDITIVE blend, because
## two overlapping tracers are brighter than one and because a round is a thing that glows
## in a way nothing around it does.
##
## WATER IS NOT. Half a tonne of it is a lump of something falling: lit by the sun like the
## aeroplane it came out of, not glowing, and translucent rather than bright. Drawn additive
## it came out as a white streak indistinguishable from a cannon shell, which is the one
## thing a water bomber's load must not look like -- so it is a rounded mass in plain alpha,
## and the difference is visible from a mile away.
func _tracer(shot: Dictionary) -> MeshInstance3D:
	var ammo: int = int(shot["ammo"])
	var wet: bool = Ammunition.is_wet(ammo)
	var node := MeshInstance3D.new()
	if wet:
		var mass := SphereMesh.new()
		mass.radius = 0.5
		mass.height = 1.0
		mass.radial_segments = 8
		mass.rings = 5
		node.mesh = mass
	else:
		var body := BoxMesh.new()
		body.size = Vector3(1.0, 1.0, 1.0)
		node.mesh = body
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if wet \
		else BaseMaterial3D.BLEND_MODE_ADD
	var tint: Color = Ammunition.look(ammo)["tracer"]
	# Translucent, so a curtain of it reads as a curtain rather than as a wall of dots.
	paint.albedo_color = Color(tint.r, tint.g, tint.b, 0.55) if wet else tint
	node.material_override = paint
	add_child(node)
	return node


## A burst, from the drawer. Round-robin rather than grown: thirty rounds a second from a
## 25 mm cannon would otherwise build thirty explosions a second for ever, and the oldest
## of twenty-four has always finished by the time it is wanted again.
func _a_burst() -> Burst:
	if _bursts.size() < BURSTS:
		var made := Burst.new()
		add_child(made)
		_bursts.append(made)
		return made
	var burst: Burst = _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % _bursts.size()
	return burst


## How many rounds are being drawn, for the tests and the boards.
func in_the_air() -> int:
	return _live.size()
