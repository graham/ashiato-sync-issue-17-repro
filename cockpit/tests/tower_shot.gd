extends Node
## THE TOWER, LOOKED AT: an aeroplane being told to climb, and climbing.
##
##   Godot --path cockpit --resolution 1600x900 --xr-mode off res://tests/tower_shot.tscn -- --level=tower
##       --out=C:/somewhere --seconds=70
##
## A PROBE, NOT A SUITE: it renders, and headless has no rendering device (`../../seeing_the_game.md`). Whether the
## buttons reach the autopilot is `tests/tower.gd`'s, and it is held there against the flown aeroplane. **This is for
## eyes**, because the tower exists to be watched and a green suite is very nearly no evidence about a thing whose
## whole purpose is being looked at (`../../CLAUDE.md`, rule 2).
##
## NEVER A CAPTURE OF THE DESKTOP: every picture is the viewport's own image.
##
## WHAT IT SHOWS, in three stills a person can compare:
##   tower-1-before.png   an aeroplane under the camera, the panel beside it, TOLD reading "nothing yet"
##   tower-2-told.png     the moment after CLIMB: TOLD three hundred metres above DOING, and the message line saying so
##   tower-3-after.png    a minute later: DOING has caught TOLD up, and the aeroplane is where it was sent
##
## WHAT THE PAIR IS EVIDENCE OF, which is worth stating because a still of a panel proves nothing on its own: that the
## readout's two columns MOVE INDEPENDENTLY and then converge. A panel wired to display its own orders back would show
## them equal in every frame; a panel wired to nothing would show TOLD blank for ever. Three stills of them parting and
## closing is the smallest picture that can only be produced by the buttons reaching the pilot.

const OUT: String = "user://tower_shots"

var _failures: PackedStringArray = []
var _level: FlightLevel = null
var _out: String = OUT
var _seconds: float = 70.0


func _check(label: String, ok: bool, detail: String) -> void:
	print("[tower_shot] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--seconds="):
			_seconds = argument.trim_prefix("--seconds=").to_float()
	if DisplayServer.get_name() == "headless":
		_check("it_is_rendering", false, "headless has no rendering device; run it windowed")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_level = (load("res://world/sky.tscn") as PackedScene).instantiate() as FlightLevel
	get_tree().root.add_child.call_deferred(_level)
	await _frames(2)
	if _level.observer == null:
		_check("there_is_nobody_flying", false, "pass --level=tower after the bare --")
		_finish()
		return
	var panel: TowerPanel = _level.find_child("TowerPanel", true, false) as TowerPanel
	if panel == null:
		_check("the_tower_has_its_panel", false, "no TowerPanel: was --level=tower asked for?")
		_finish()
		return
	# LET THE WORLD STAND UP AND THE TRAFFIC GET INTO THE AIR. The ground takes seconds and an aeroplane on a stand is
	# not worth a picture of a climb.
	await _frames(int(_seconds * 0.35 * 60.0))
	var flying: int = _one_in_the_air()
	_check("something_is_flying_to_command", flying != 0,
		"%d vehicles on the server" % Sim.server.vehicle_states().size())
	if flying == 0:
		_finish()
		return
	panel.choose(flying)
	await _frames(45)
	await _shoot("1-before")
	var before: float = _height_of(flying)
	# BOTH ANSWERS, because the first run disagreed with itself: the board said 350 m and the panel asked for 973.
	# `Sim.current` is the DISPLAY list and `vehicle_state` is the physics pose, and a probe that prints only one of
	# them cannot say which is lying.
	print("[tower_shot] commanding server entity %d at %.0f m" % [flying, before])
	panel.press("climb")
	await _frames(20)
	await _shoot("2-told")
	var told: float = float(panel.told_of(flying).get("altitude", 0.0))
	_check("the_panel_is_commanding_the_craft_in_frame", panel.chosen() == flying,
		"chose %d, commanding %d" % [flying, panel.chosen()])
	_check("the_panel_asked_for_three_hundred_metres_more",
		told > before + 250.0 and told < before + 350.0,
		"flying at %.0f m, told %.0f m" % [before, told])
	await _frames(int(_seconds * 0.55 * 60.0))
	await _shoot("3-after")
	var after: float = _height_of(flying)
	_check("and_it_climbed_toward_what_it_was_told", after > before + 80.0,
		"%.0f m to %.0f m, against an order of %.0f m" % [before, after, told])
	_finish()


## THE FIRST AIRCRAFT THAT IS ACTUALLY FLYING, because a picture of a parked one being told to climb shows nothing.
##
## FROM THE SERVER'S LIST, which is the whole point of the fix this probe is re-shooting: picking from `Sim.current`
## and commanding `Sim.server` is how the first version of this probe "proved" the tower worked by measuring an
## aeroplane that was never on the screen.
func _one_in_the_air() -> int:
	for row in Sim.server.vehicle_states():
		var state: Dictionary = row
		var entity: int = int(state["entity"])
		var model: int = int(Sim.geometry_of(int(state.get("kind", -1))).get("model", -1))
		if model != Sim.Model.AIRPLANE:
			continue
		if (state.get("position", Vector3.ZERO) as Vector3).y < 200.0:
			continue
		if (state.get("velocity", Vector3.ZERO) as Vector3).length() < 30.0:
			continue
		return entity
	return 0


## HEIGHT AS THE SIMULATION HOLDS IT, not as the renderer draws it. `Sim.current` is the DISPLAY list and it read
## 352 m for an aeroplane the server had at 673 -- the rebased pose the camera draws, not the one an autopilot's
## altitude is compared against. A probe that checks an order against the drawn height is comparing two different
## quantities and will report a fault that is not there (`../agents.md`, "a field that can hold two different
## physical quantities").
func _height_of(entity: int) -> float:
	return ((Sim.server.vehicle_state(entity) as Dictionary).get("position", Vector3.ZERO) as Vector3).y


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = "%s/tower-%s.png" % [_out, name]
	_check("saved_%s" % name, get_viewport().get_texture().get_image().save_png(path) == OK, path)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
		get_tree().quit(0)
	else:
		print("RESULT=FAIL %s" % " ".join(_failures))
		get_tree().quit(1)
