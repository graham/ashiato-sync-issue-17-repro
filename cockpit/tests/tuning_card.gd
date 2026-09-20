class_name TuningCard
extends RefCounted
## A CARD OF RETUNES CLIPPED TO A CRAFT BEFORE IT FLIES: `-- --set=surfaces=1,cruise=62.8 --kind=cessna` on a suite's
## command line, applied through `set_handling` to both worlds the game runs.
##
## `tests/handling.gd` has taken `--set=` since lane/handling, and `tests/rota_probe.gd` since lane/flightmodel. The AI
## fleet's suites (`trim`, `climb`) did not, and step 2 of `research/flight_model_plan.md` is exactly the question they
## answer -- does the unedited autopilot still hold its height, climb gently and not hunt, with a kind on its lifting
## surfaces -- so they take the same card, and an A/B of a kind is two runs and no build.
##
## BOTH WORLDS, because both are asked: the server flies the autopilots, and `Terrain.cruise_for` reads the CLIENT's
## handling for the speed a suite spawns a craft at. Retuned on the server alone, a surface Cessna was launched at the
## lumped one's 55 m/s and flown at 62.8.
##
## A value with `=` sets, one with `*` multiplies what the kind has now, as `handling.gd` takes them. `--kind=` names the
## kinds the card is clipped to; without it, every kind gets it -- a key a kind does not use is harmless, and `surfaces`
## is ignored by every kind without a drawn planform.

var retune: Dictionary = {}
var kinds: Array[int] = []


## The card on this run's command line, empty if there is none.
static func from_command_line() -> TuningCard:
	var card := TuningCard.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			for pair in arg.trim_prefix("--set=").split(",", false):
				var factor: bool = pair.contains("*")
				var bits: PackedStringArray = pair.split("*" if factor else "=")
				if bits.size() == 2:
					card.retune[bits[0]] = [factor, float(bits[1])]
		if arg.begins_with("--kind="):
			for name in arg.trim_prefix("--kind=").split(",", false):
				for kind in range(Sim.Kind.size()):
					if Sim.kind_name(kind) == name:
						card.kinds.append(kind)
	return card


func is_empty() -> bool:
	return retune.is_empty()


## Whether a suite that flies every kind should fly this one: all of them with no `--kind=`, or the named ones.
func flies(kind: int) -> bool:
	return kinds.is_empty() or kinds.has(kind)


## Clip it on: every named kind (or every kind), both worlds. Returns what the server reads back, for the log.
func clip_on() -> String:
	if retune.is_empty():
		return ""
	var said: Array[String] = []
	for kind in range(Sim.Kind.size()):
		if not flies(kind):
			continue
		for world in [Sim.server, Sim.client]:
			if world == null:
				continue
			var now: Dictionary = world.handling(kind)
			var tuned: Dictionary = {}
			for key in retune:
				var o: Array = retune[key]
				tuned[key] = float(now.get(key, 0.0)) * float(o[1]) if bool(o[0]) else float(o[1])
			world.set_handling(kind, tuned)
		if not kinds.is_empty():
			var read: Dictionary = Sim.server.handling(kind)
			said.append("%s: surfaces %s, rotors %s, cruise %.1f, stall %.1f" % [Sim.kind_name(kind),
				read.get("surfaces", "-"), read.get("rotors", "-"),
				float(read.get("cruise", 0.0)), float(read.get("stall_speed", 0.0))])
	return "retuned %s%s" % [str(retune), (" -- " + "; ".join(said)) if not said.is_empty() else ""]


## Clip onto ONE world, for a suite that instantiates CockpitWorld itself (littlebird_book,
## littlebird_circuit, cessna_book). `clip_on` talks to Sim.server / Sim.client.
func apply_to(world: Object, kind: int) -> void:
	if world == null or retune.is_empty():
		return
	if not flies(kind):
		return
	var now: Dictionary = world.handling(kind)
	var tuned: Dictionary = {}
	for key in retune:
		var o: Array = retune[key]
		tuned[key] = float(now.get(key, 0.0)) * float(o[1]) if bool(o[0]) else float(o[1])
	world.set_handling(kind, tuned)
