extends VBoxContainer
class_name TowerPanel
## THE TOWER: YOU SET THE GOAL, THE AUTOPILOT FLIES IT, AND YOU WATCH.
##
##   Godot --path cockpit -- --level=tower
##   ...and on the desk's level menu, beside `watch`.
##
## WHY IT EXISTS. The user, 2026-09-19, in their own words: *"can this be a level i can load when the game loads? i
## want to experiment (in 2d not in vr) by having the planes fly around and I cna click buttons to tell them to do
## things, 'climb', 'descend' land at nearest airport, takeoff, etc, that way i can see them fly around and make sure
## things are going well (fly to random location, etc) ... i don't control them ai pilot controls them, i just set the
## goal and mode"*.
##
## `tests/vehicle_gym.gd` answers "how well is each kind flown" as a hundred and eighty numbers. It cannot answer "does
## that look right", which is the question this game keeps failing at (`../../CLAUDE.md`, rule 2: LOOK AT IT). This is
## the other half: the same aircraft, the same autopilots, on a monitor, with a row of buttons.
##
## IT FLIES NOTHING. Every button is one `steer_ai` call -- the SAME call `AirportTraffic` makes for the island's own
## airliners -- so what you are watching is the game's pilot doing the game's job, not a second control path written
## for a test. A button that flew the aeroplane itself would look convincing and prove nothing.
##
## THE SELECTION AND THE ORDER COME FROM THE SAME WORLD, AND THAT IS NOT A DETAIL -- IT IS THE WHOLE DESIGN.
##
## The first version took the craft under `Observer`'s camera and sent it to `Sim.server.steer_ai`. **It commanded a
## different aeroplane from the one on the screen**, and its own suite said it worked: `Sim.current` is built from
## `client.vehicle_states()` and the client and the server do not number entities alike. Measured on the island, 93
## machines: of the 89 ids present in both, **54 named the same KIND and 18 the same PLACE**, and one id was an
## aeroplane on the client and a **train** on the server. See `../../todo/flightcore--a-client-id-is-not-a-server-id.md`.
##
## So this panel **walks the SERVER's own list, commands the SERVER, and places the camera from the SERVER's pose**.
## There is no lookup between the two worlds, so there is none to get wrong: the craft in frame is the craft commanded
## BY CONSTRUCTION. N and P step, K narrows to a kind, F lets the camera go -- the same keys `Observer` offers, read
## here first so the two never disagree about what is selected.
##
## WHY NOT MOVE `Observer` ITSELF, which would be the fuller fix: it is the tool other lanes shoot pictures with, and
## changing how it picks and places would move stills in lanes that have nothing to do with a command panel. The
## duplication here is a few lines; that would be everybody's problem. The fuller fix is written up in the todo.
##
## WHAT PLACING FROM THE SERVER COSTS, measured, so nobody "improves" it back onto the client list believing they are
## curing judder:
##   * the two worlds agree on where the machines are to **0.25 m median and 1.56 m worst** (93 of 93 matched by kind
##     and place) -- invisible on a chase view standing tens of metres off;
##   * the camera moves **once a tick rather than once a frame**, and at 120 Hz that is more often than most frames;
##   * it loses the display pose's rollback smoothing, which is worth nothing here -- a solo tower reports 0 rollbacks
##     and there is nothing to absorb.
##
## WHAT THE READOUT IS FOR. Two columns: what the aeroplane was TOLD, and what it is DOING, with the kind's stall and
## cruise beside them. An aeroplane told to hold 70 m/s and doing 58 is not a bad picture -- it is a visible fault, and
## the gym has already measured seven kinds that cannot make a speed gate. The panel's job is to make that obvious to
## somebody watching rather than to somebody reading a table.
##
## ON THE MOUSE: `Observer` looks with the RIGHT button held, so the left one is free and the buttons are simply
## clicked. Nothing here captures the mouse, and nothing here reads the keyboard -- the camera's keys stay the
## camera's.

## What one press of CLIMB or DESCEND is worth, in metres.
const STEP_UP: float = 300.0
## And one press of FASTER or SLOWER, as a share of what it was told.
const STEP_SPEED: float = 0.1
## How far behind and above a chased craft the camera sits, in multiples of its own length, and never closer than
## `NEAR_ENOUGH`. `Observer.BEHIND`, `ABOVE` and `NEAR_ENOUGH`, because the tower places its own camera from the
## server's pose and a chase view that framed a craft differently from `--level=watch` would be a second answer to a
## question the game has already answered.
const BEHIND: float = 3.2
const ABOVE: float = 0.9
const NEAR_ENOUGH: float = 14.0
## How far ahead a turn or a wander puts its point. Far enough that the aeroplane flies the heading rather than
## arriving and asking for another.
const REACH: float = 12000.0
## Never told to fly lower than this above the ground under it.
const FLOOR: float = 60.0

const AMBER := Color(0.95, 0.76, 0.28)
const PALE := Color(0.86, 0.90, 0.92)
const DIM := Color(0.62, 0.66, 0.70)

## THE CAMERA, which owns which craft is being commanded. Typed as an `Object` and not as an `Observer` on purpose:
## the only thing this panel ever asks of it is `watching()`, and depending on the QUESTION rather than on the class
## is what lets `tests/tower.gd` hand it a two-line stand-in instead of standing up a `Camera3D` with a world and a
## level behind it. A narrower dependency is a testable one.
var observer: Object = null
## The level, for its `AirportTraffic` where it has one (landing needs a pattern, not a point).
var sky: Node = null
## THE SIMULATION IT COMMANDS, handed in rather than reached for. `Sky` gives it `Sim.server`; `tests/tower.gd` gives
## it a world of its own. A panel that reached for the autoload could only ever be tested by standing up the whole
## game, which is how a row of buttons ends up with no test at all.
var server: Object = null

## What each craft was last told, by entity: the steer dictionary, kept so CLIMB adds to the last altitude rather than
## to whatever the aeroplane has drifted to. A craft that has never been told anything is not in here.
var _told: Dictionary = {}
var _readout: Label = null
var _said: Label = null
var _last_said: String = ""
## Entity to kind, filled by `_kind_of`. A kind never changes, so a hit is for ever.
var _kinds: Dictionary = {}
## THE CRAFT UNDER THE CAMERA, as a SERVER entity, and the only id this panel ever holds.
var _chosen: int = 0
## Narrowed to one kind by K, or -1 for all of them.
var _only_kind: int = -1
## While the camera has been let go with F, nothing is chased and nothing is commanded.
var _free: bool = false
var _dice := RandomNumberGenerator.new()


func _ready() -> void:
	_dice.seed = 20260919
	# A CONTAINER AND NOT A BARE `Control`, and the first version was the second. A `Control` does not lay its children
	# out: the `VBoxContainer` inside it was given a rect of 0 by 0, so every button was 0 by 0 and THE WHOLE PANEL WAS
	# INVISIBLE -- with `tests/tower.gd` passing all five of its checks, because the buttons worked perfectly and
	# nobody could see them. That is rule 2 of `../../CLAUDE.md` in one afternoon: a green suite says nothing about a
	# thing whose whole purpose is being looked at.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_top = 64.0
	offset_right = -16.0
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 4)
	var box: VBoxContainer = self
	# READ AGAINST A BRIGHT SKY, WHICH THE FIRST VERSION WAS NOT. Pale grey on cloud is legible in a screenshot viewer
	# and gone in the game: the first still of this panel had the numbers a person actually judges the aeroplane by --
	# told against doing -- washed out against the overcast behind them, while the buttons underneath were perfectly
	# clear because they carry their own background. A black outline costs nothing and works over sky, sea and ground.
	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 16)
	_readout.add_theme_color_override("font_color", PALE)
	_readout.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_readout.add_theme_constant_override("outline_size", 5)
	box.add_child(_readout)
	for row in _buttons():
		var button := Button.new()
		button.text = String(row["text"])
		button.custom_minimum_size = Vector2(216.0, 30.0)
		button.add_theme_font_size_override("font_size", 15)
		button.tooltip_text = String(row["says"])
		var order: String = String(row["order"])
		button.pressed.connect(func() -> void: press(order))
		box.add_child(button)
	_said = Label.new()
	_said.add_theme_font_size_override("font_size", 14)
	_said.add_theme_color_override("font_color", AMBER)
	_said.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_said.add_theme_constant_override("outline_size", 5)
	_said.custom_minimum_size = Vector2(216.0, 0.0)
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_said)


## THE BUTTONS, and each one is a goal rather than a control. `order` is what `_press` matches on; `says` is the
## tooltip, which says what the autopilot is being asked for rather than what the aeroplane will do about it.
func _buttons() -> Array[Dictionary]:
	return [
		{"text": "TAKE OFF", "order": "take_off",
			"says": "Fly: on its wheels it opens the throttle and lifts off."},
		{"text": "CLIMB  +300 m", "order": "climb", "says": "Add 300 m to the height it is holding."},
		{"text": "DESCEND  -300 m", "order": "descend", "says": "Take 300 m off, never below 60 m up."},
		{"text": "FASTER  +10%", "order": "faster", "says": "Ask for a tenth more speed."},
		{"text": "SLOWER  -10%", "order": "slower", "says": "Ask for a tenth less, never under its stall."},
		{"text": "TURN LEFT  90", "order": "left", "says": "Put the point a quarter turn to port."},
		{"text": "TURN RIGHT  90", "order": "right", "says": "Put the point a quarter turn to starboard."},
		{"text": "FLY SOMEWHERE", "order": "wander", "says": "A point somewhere else on this level."},
		{"text": "LAND AT NEAREST", "order": "land", "says": "Join the pattern at the closest airfield and land."},
		{"text": "HOLD ON THE GROUND", "order": "hold", "says": "Stop where it is, on its brakes."},
		{"text": "LET IT GO", "order": "release", "says": "Hand it back to its own waypoints."},
	]


func _process(_delta: float) -> void:
	if _chosen != 0 and _state_of(_chosen).is_empty():
		_chosen = 0
	if _chosen == 0 and not _free:
		step(1)
	_place_the_camera()
	_write_the_readout()


## ---- the orders ---------------------------------------------------------------------------

## ONE BUTTON. Public because `tests/tower.gd` presses the buttons by name -- the same function the `pressed` signal
## calls -- rather than reaching past the panel to `steer_ai`, which would pass with every button wired wrongly.
func press(order: String) -> void:
	var entity: int = _commanding()
	if entity == 0:
		_say("No aircraft under the camera. N steps to the next one.")
		return
	var state: Dictionary = _state_of(entity)
	if state.is_empty():
		_say("That machine has gone.")
		return
	var kind: int = _kind_of(entity)
	var at: Vector3 = state.get("position", Vector3.ZERO)
	var told: Dictionary = _told.get(entity, _fresh(entity, state, kind))
	match order:
		"release":
			_off_its_route(entity)
			_server().steer_ai(entity, {})
			_told.erase(entity)
			_say("%s let go: back on its own waypoints." % Sim.kind_name(kind).to_upper())
			return
		"land":
			_land(entity, kind, at)
			return
		"take_off":
			told["wheels"] = "fly"
			told["altitude"] = maxf(float(told["altitude"]), at.y + 400.0)
			told["toward"] = at + _heading_of(state) * REACH
		"hold":
			told["wheels"] = "hold"
			told["toward"] = at
		"climb":
			told["wheels"] = "fly"
			told["altitude"] = float(told["altitude"]) + STEP_UP
		"descend":
			told["altitude"] = maxf(float(told["altitude"]) - STEP_UP, _ground_under(at) + FLOOR)
		"faster":
			told["speed"] = float(told["speed"]) * (1.0 + STEP_SPEED)
		"slower":
			told["speed"] = maxf(float(told["speed"]) * (1.0 - STEP_SPEED), _slowest(kind))
		"left", "right":
			var turn: float = (PI * 0.5) * (-1.0 if order == "left" else 1.0)
			told["toward"] = at + _heading_of(state).rotated(Vector3.UP, -turn) * REACH
			told["wheels"] = "fly"
		"wander":
			told["toward"] = _somewhere_else(at)
			told["wheels"] = "fly"
	_tell(entity, kind, told)


## TAKE IT OFF ITS ROUTE FIRST, AND THIS IS THE ONE THING THE PANEL CANNOT SKIP.
##
## An aeroplane flying the island's airport life is steered by `AirportTraffic` on the chore rota, a few times a
## second, every second. An order from this panel lands in the same place and is overwritten before the next frame:
## the button works, the message line says it worked, the aeroplane carries on to its gate. Measured, 2026-09-20 --
## a Cessna told to climb 300 m stayed at its 673 m for seventy seconds, and the picture showed nothing wrong.
##
## `AirportTraffic.release` drops its record and takes its chore off the rota, which is what makes the aeroplane
## actually listen. A craft that was never on a route is simply not in its list and nothing happens.
func _off_its_route(entity: int) -> void:
	var traffic: Node = sky.get("airport_traffic") if sky != null else null
	if traffic != null:
		(traffic as AirportTraffic).release(entity)


## EVERY KEY GIVEN, WITH ITS DEFAULT WHERE IT DOES NOT APPLY (`../../CLAUDE.md`, rule 8): `steer_ai` keeps whatever an
## earlier steer set for a key left out, so a half-filled order carries the last one's leftovers.
func _tell(entity: int, kind: int, told: Dictionary) -> void:
	_off_its_route(entity)
	var full: Dictionary = {
		"toward": told.get("toward", Vector3.ZERO),
		"altitude": told.get("altitude", 0.0),
		"speed": told.get("speed", 0.0),
		"wheels": told.get("wheels", "fly"),
		"cruise_floor": false, "bank": 0.0, "approach": false,
	}
	if not _server().steer_ai(entity, full):
		_say("%s would not take an order: it has no autopilot." % Sim.kind_name(kind).to_upper())
		return
	_told[entity] = told
	_say("%s told: %s at %.0f m, %.0f m/s." % [Sim.kind_name(kind).to_upper(),
		String(full["wheels"]).to_upper(), float(full["altitude"]), float(full["speed"])])


## WHAT A CRAFT IS TAKEN TO HAVE BEEN TOLD before anybody tells it anything: where it is, how high it is, and its own
## cruise. So the first press of CLIMB adds to the height it is at rather than to zero.
func _fresh(_entity: int, state: Dictionary, kind: int) -> Dictionary:
	var at: Vector3 = state.get("position", Vector3.ZERO)
	return {
		"toward": at + _heading_of(state) * REACH,
		"altitude": at.y,
		"speed": _cruise(kind),
		"wheels": "fly",
	}


## LANDING IS A PATTERN AND NOT A POINT, so it goes through `AirportTraffic` -- the same downwind, base and final the
## island's own arrivals fly. Without a level that has airfields there is nothing to join, and it says so.
func _land(entity: int, kind: int, at: Vector3) -> void:
	var traffic: Node = sky.get("airport_traffic") if sky != null else null
	if traffic == null:
		_say("This level has no airport traffic, so there is no pattern to join.")
		return
	var fields: Array[Dictionary] = Airfield.here()
	var nearest: Dictionary = {}
	var closest: float = INF
	for field in fields:
		var centre: Vector3 = (field.get("frame", {}) as Dictionary).get("centre", Vector3.ZERO)
		var away: float = at.distance_to(centre)
		if away < closest:
			closest = away
			nearest = field
	if nearest.is_empty():
		_say("No airfield on this level. The test field has four.")
		return
	if not (traffic as AirportTraffic).arrive(entity, nearest, kind):
		_say("%s could not be sent to %s." % [Sim.kind_name(kind).to_upper(), nearest.get("id", "?")])
		return
	_told.erase(entity)
	_say("%s sent to %s, %.1f km away." % [Sim.kind_name(kind).to_upper(),
		nearest.get("name", nearest.get("id", "?")), closest * 0.001])


## ---- what it says -------------------------------------------------------------------------

## TOLD AGAINST DOING, which is the whole point of watching rather than reading. The stall and the cruise are the
## kind's own (`handling()`), so a speed asked for below the stall reads as one.
func _write_the_readout() -> void:
	if _readout == null:
		return
	var entity: int = _commanding()
	var state: Dictionary = _state_of(entity)
	if state.is_empty():
		_readout.text = ("THE TOWER\n%s\nN next  ·  P back  ·  K by kind  ·  F free"
			% ("camera let go" if _free else "no aircraft under the camera"))
		return
	var kind: int = _kind_of(entity)
	var v: Vector3 = state.get("velocity", Vector3.ZERO)
	var at: Vector3 = state.get("position", Vector3.ZERO)
	var told: Dictionary = _told.get(entity, {})
	var lines: PackedStringArray = ["THE TOWER  ·  %s #%d" % [Sim.kind_name(kind).to_upper(),
		entity & 0xFFFFFFFF]]
	# THE SIMULATION'S HEIGHT AND NOT THE DRAWN ONE, and it is labelled because both are on the screen at once: the
	# camera's board bottom-left reads the pose the aeroplane is DRAWN at, and on the island the two differ by 322 m
	# (`../../todo/flightcore--the-drawn-height-and-the-simulations-differ.md`). An ORDER is compared against the
	# simulation, so that is the number a panel giving orders has to show.
	lines.append("doing   %5.0f m sim  %5.1f m/s   %+5.1f m/s up" % [at.y, v.length(), v.y])
	if told.is_empty():
		lines.append("told    nothing yet -- press a button")
	else:
		lines.append("told    %5.0f m   %5.1f m/s   %s" % [float(told.get("altitude", 0.0)),
			float(told.get("speed", 0.0)), String(told.get("wheels", "fly"))])
	# THREE NUMBERS AND THREE NAMES, because the first version printed `_slowest` under the word "stall" and the light
	# twin read "stall 72" when it stalls at 55.3. A person judging how close an aeroplane is to the stall would have
	# been wrong by seventeen metres a second, off this panel, in the picture this lane shot to prove the panel
	# honest. SLOWEST is what SLOWER stops at -- 1.30 times the stall, the mixer's own margin -- and it is a different
	# quantity from the stall with a different name (`../agents.md`, "a field that can hold two different physical
	# quantities, with nothing in its name to say which").
	lines.append("its own  stall %.0f   slowest %.0f   cruise %.0f m/s"
		% [_stall(kind), _slowest(kind), _cruise(kind)])
	_readout.text = "\n".join(lines)


func _say(words: String) -> void:
	if _said != null:
		_said.text = words
	_last_said = words


## WHAT A CRAFT WAS LAST TOLD, and what the panel last said about it: what a suite reads instead of a screen.
func told_of(entity: int) -> Dictionary:
	return _told.get(entity, {})


func said() -> String:
	return _last_said


## ---- the small questions ------------------------------------------------------------------

## WHICH CRAFT THE BUTTONS COMMAND: whatever the camera is chasing, and 0 for none.
func _commanding() -> int:
	return 0 if _free else _chosen


## STEP THROUGH THE SERVER'S OWN LIST, in the order it holds them. `Observer` does the same walk over the client's,
## which is right for a camera and wrong for anything that gives orders.
func step(by: int) -> void:
	var entities: Array[int] = []
	for row in _rows():
		if _only_kind < 0 or int((row as Dictionary)["kind"]) == _only_kind:
			entities.append(int((row as Dictionary)["entity"]))
	if entities.is_empty():
		_chosen = 0
		_say("Nothing of that kind in the world.")
		return
	var at: int = entities.find(_chosen)
	_chosen = entities[posmod(at + by, entities.size())] if at >= 0 else entities[0]
	_free = false
	_say("Watching %s #%d." % [Sim.kind_name(_kind_of(_chosen)).to_upper(), _chosen & 0xFFFFFFFF])


func only(kind: int) -> void:
	_only_kind = kind
	_chosen = 0
	step(1)


## PICK ONE BY NAME, for a probe that knows which machine it wants (`tests/tower_shot.gd`) and for `tests/tower.gd`.
func choose(entity: int) -> void:
	_chosen = entity
	_free = false


func chosen() -> int:
	return _chosen


func _rows() -> Array:
	var world: Object = _server()
	return world.vehicle_states() if world != null else []


## THE KEYS, READ BEFORE `Observer` SEES THEM. A Control's `_input` runs ahead of a node's `_unhandled_input`, so the
## camera never learns of an N it would answer with a craft from the other world's numbering.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_N: step(1)
		KEY_P: step(-1)
		KEY_K: only(-1 if _only_kind >= Sim.Kind.size() - 1 else _only_kind + 1)
		KEY_F:
			_free = true
			_say("Camera let go. N picks an aircraft up again.")
		_: return
	get_viewport().set_input_as_handled()


## AND THE CAMERA IS PLACED FROM THE SAME POSE THE ORDER IS COMPARED AGAINST, behind and above in the craft's own
## frame, which is `Observer._chase`'s arithmetic on the server's numbers instead of the drawn node's.
func _place_the_camera() -> void:
	if observer == null or _free or _chosen == 0:
		return
	var state: Dictionary = _state_of(_chosen)
	if state.is_empty():
		return
	var at: Vector3 = state.get("position", Vector3.ZERO)
	var basis := Basis(state.get("basis", Quaternion()) as Quaternion)
	var size: float = maxf((Sim.geometry_of(_kind_of(_chosen)).get("extents", Vector3.ONE) as Vector3).z * 2.0, 4.0)
	var back: float = maxf(size * BEHIND, NEAR_ENOUGH)
	observer.look_from(at + basis.z * back + Vector3.UP * (size * ABOVE), at)


func _heading_of(state: Dictionary) -> Vector3:
	var v: Vector3 = state.get("velocity", Vector3.ZERO)
	var flat := Vector3(v.x, 0.0, v.z)
	if flat.length() > 1.0:
		return flat.normalized()
	var basis := Basis((state.get("basis", Quaternion()) as Quaternion))
	flat = Vector3(-basis.z.x, 0.0, -basis.z.z)
	return flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD


func _somewhere_else(at: Vector3) -> Vector3:
	var away: float = _dice.randf_range(REACH * 0.4, REACH)
	var turn: float = _dice.randf_range(-PI, PI)
	return at + Vector3.FORWARD.rotated(Vector3.UP, turn) * away


## THE GROUND UNDER A POINT, so DESCEND cannot be pressed into a hill. `Terrain.ground_height` is the level's own
## answer -- the same one the autopilot's look-ahead uses -- rather than a second sampler of this panel's (rule 4).
func _ground_under(at: Vector3) -> float:
	return Terrain.ground_height(at)


func _cruise(kind: int) -> float:
	return float(_handling(kind).get("cruise", 60.0))


## NEVER TOLD TO FLY SLOWER THAN ITS STALL, with the mixer's own margin over it: below 1.30 times the stall
## `AircraftMixer` allows no climb at all, so an order under that is one the autopilot cannot obey (see
## `../tests/vehicle_gym.gd`, the waypoint floor).
func _slowest(kind: int) -> float:
	return _stall(kind) * 1.30


## THE SPEED THE WING STOPS FLYING AT, as the model derives it. Not the slowest a task may ASK for, which is this
## times the mixer's margin.
func _stall(kind: int) -> float:
	return float(_handling(kind).get("stall_speed", 0.0))


func _handling(kind: int) -> Dictionary:
	var world: Object = _server()
	if world == null or kind < 0:
		return {}
	return world.handling(kind)


func _server() -> Object:
	return server if server != null else Sim.server


## WHAT KIND A CRAFT IS. **`vehicle_state(entity)` DOES NOT CARRY THE KIND** -- it is a pose, and only the whole-world
## `vehicle_states()` list has it. Getting that wrong cost this panel its speed floor: `kind` came back -1, `handling`
## returned {}, the stall read 0, and forty presses of SLOWER walked a Cessna down to 0.9 m/s. `tests/tower.gd` caught
## it; nothing a person could see on the screen would have.
##
## CACHED, because an entity's kind never changes and the readout asks every frame: one scan of the world the first
## time an unseen craft is looked at, and nothing after.
func _kind_of(entity: int) -> int:
	if _kinds.has(entity):
		return int(_kinds[entity])
	var world: Object = _server()
	if world == null:
		return -1
	for row in world.vehicle_states():
		_kinds[int((row as Dictionary)["entity"])] = int((row as Dictionary)["kind"])
	return int(_kinds.get(entity, -1))


## WHAT THE SIMULATION SAYS A CRAFT IS DOING, or {} when it has gone. The SERVER's answer and not the client mirror's,
## so the same call works in the game and on a suite's bench.
func _state_of(entity: int) -> Dictionary:
	var world: Object = _server()
	return world.vehicle_state(entity) if world != null and entity != 0 else {}
