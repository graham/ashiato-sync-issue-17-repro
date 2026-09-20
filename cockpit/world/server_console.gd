extends Control
class_name ServerConsole
## THE SERVER'S OWN FACE: who is connected, what is flying, and what the tick costs -- in 2D, or in a log.
##
##   Godot --path cockpit --headless --xr-mode off -- --host=7788 --world=island --level=server
##   server.bat                                    the same, from a double-click
##
## WHY IT EXISTS. The user, 2026-09-19: *"Since not everyone has a vr headset, i want to make sure i make room to run
## the game as a server in 2d (just better for resources), or headless"*.
##
## ---------------------------------------------------------------------------------------------------
## WHAT WAS ALREADY TRUE, AND WHY THIS IS SMALL
## ---------------------------------------------------------------------------------------------------
##
## Hosting headless already worked: every `*_peers.gd` suite in this project does it, and `--headless --host` has stood
## a world up since long before this file. So the room had already been made, and the honest job here was to NAME the
## thing, take the three costs off it that a server has no use for, and MEASURE what that is worth -- not to write a
## second way of standing a world up.
##
## THE THREE COSTS A SERVER HAS NO USE FOR, and where each one goes:
##
##   1. THE PILOT RIG. `Sky._nobody_is_playing()` already builds no rig, no seat, no hands and no XR for `watch` and
##      `tower`; `server` was added to that list and inherits all of it. The host is no longer a player.
##   2. THE CAMERA. `watch` and `tower` still build an `Observer`, which is a camera that chases things. A server looks
##      at nothing, so `Sky._the_server()` builds this panel INSTEAD of the observer, and the level then has no camera
##      at all. Every `observer` use in `sky.gd` was already null-guarded, so nothing had to change to allow it.
##   3. THE OPENXR ATTACH. `--xr-mode off`, which is Godot's own flag and not ours.
##
## WHAT THAT IS WORTH, measured on the island on this workstation, headless, twenty seconds after `SESSION=`, the child
## process matched by the port on its command line (the `.console.exe` is a wrapper and reports its own 6 MB otherwise):
##
##   | run                                    | working set | private | CPU to that point |
##   |----------------------------------------|-------------|---------|-------------------|
##   | `--level=world`  (rig, XR attached)    | 407.1 MB    | 343.1 MB| 25.7 s            |
##   | `--level=watch`  (no rig, XR attached) | 389.7 MB    | 325.8 MB| 23.3 s            |
##   | `--level=watch --xr-mode off`          | 384.8 MB    | 324.2 MB| 21.0 s            |
##
## So the whole saving is **22.3 MB and 4.7 s of CPU, about 5 per cent of the memory and 18 per cent of the work**.
##
## THAT NUMBER IS THE POINT OF THIS DOC BLOCK, because it is much smaller than "run it as a server" sounds, and the next
## person to read the user's word *"resources"* should know where the rest of it went before they go looking. **The
## remaining 385 MB is very largely SCENERY** -- meshes, trees, towns, materials and textures that `Sky` loads and a
## headless server never draws. Roughly twenty visual yards are built unconditionally in `Sky._ready` (`BurstYard`,
## `ContrailYard`, `WakeYard`, `SprayYard`, `Woodland`, `GrassBlades`, `TownView`, `MistLayer`, the clouds, ...) and
## some of them carry simulation duties as well as drawing ones, so they cannot be dropped as a group.
##
## **CARVING THE SCENERY OUT WAS CONSIDERED AND REJECTED FOR THIS LANE**, deliberately and not by running out of time.
## It is a twenty-site change to the single most central file in the project (`sky.gd`, 3154 lines), the thing it would
## break is what the world SIMULATES, and a headless suite cannot see most of what it would break. That is a lane of its
## own with its own pictures, and it is written up in `../../todo/flatcrew--the-server-still-builds-the-scenery.md`.
##
## ---------------------------------------------------------------------------------------------------
## IT ASKS; IT DOES NOT KEEP (rule 5, and rule 4)
## ---------------------------------------------------------------------------------------------------
##
## Every number on this panel is asked for at the moment it is drawn, from the authority that owns it: the players from
## `Net.roster_cards()`, the team from `Net.team_of`, the craft from `Sim.server.vehicle_states()`, the tick from
## `Sim.server.tick_breakdown()`. It keeps no roster, no count and no total of its own.
##
## THAT IS RULE 4 ("one number, one place") AND IT IS ALSO WHY THIS PANEL CANNOT DRIFT FROM `SESSION_REPORT`. `sky.gd`
## prints that line from the same four places once a second under `--report=1`; if this panel kept its own tallies, an
## operator reading the screen and a harness reading the log could disagree about how many people were connected, and
## the screen would be the one nobody could check. `tests/server_peers.gd` holds them equal on purpose, as its
## sixth check, so the claim in this paragraph is a thing that fails when it stops being true rather than a sentence.
##
## THE CRAFT COUNT IS THE **SERVER'S**, `Sim.server.vehicle_states()`, and not `Sim.current`. On a host those two are
## different lists with different numbering -- `tower_panel.gd` measured it on the island, 93 machines, of the 89 ids
## in both only 54 named the same kind and 18 the same place, and one id was an aeroplane on the client and a train on
## the server. A server console that counted the client's list would be reporting what the host happens to have drawn
## for itself, which is not what it is serving.

## How often the panel is redrawn and the headless line printed, in seconds. A server is read by somebody glancing at
## it, and once a second is what `SESSION_REPORT` and the statistics board already use.
const EVERY: float = 1.0

const BACKING := Color(0.06, 0.07, 0.09)
const PALE := Color(0.86, 0.90, 0.92)
const DIM := Color(0.45, 0.50, 0.55)
const AMBER := Color(0.95, 0.76, 0.28)
const GOOD := Color(0.45, 0.85, 0.55)

## The world this console reports on. Handed in rather than reached for, the way `TowerPanel.sky` is, so
## a suite can stand one up with no level at all.
var sky: Node = null

## The simulation's server, likewise handed in -- but ASKED FOR AGAIN every time it is used, through `_server()`,
## which is not a detail. `Sky` builds this console at line 270 of its `_ready` and calls `Sim.start()` at line 540, so
## `Sim.server` is STILL NULL when the console is handed it. Kept as handed, every craft count on the panel and in the
## headless line would read -1 for ever, and the console would look like it was working. `TowerPanel` resolves its own
## the same way and for the same reason.
var server: Object = null

var _since: float = 0.0
var _up_at: int = 0
var _title: Label = null
var _session: Label = null
var _players: VBoxContainer = null
var _world_line: Label = null
var _tick: Label = null


func _ready() -> void:
	_up_at = Time.get_ticks_msec()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backing := ColorRect.new()
	backing.color = BACKING
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	column.offset_left = 28.0
	column.offset_top = 24.0
	column.offset_right = -28.0
	column.offset_bottom = -24.0
	add_child(column)

	_title = _a_label("COCKPIT SERVER", AMBER, 28)
	column.add_child(_title)
	_session = _a_label("", PALE, 16)
	column.add_child(_session)
	_world_line = _a_label("", PALE, 16)
	column.add_child(_world_line)
	_tick = _a_label("", DIM, 14)
	column.add_child(_tick)
	column.add_child(_a_label("PLAYERS", DIM, 14))
	_players = VBoxContainer.new()
	column.add_child(_players)

	_draw_the_facts()


func _process(delta: float) -> void:
	_since += delta
	if _since < EVERY:
		return
	_since = 0.0
	_draw_the_facts()
	_say_it_where_a_shell_reads_it()


## WHAT IS TRUE RIGHT NOW, asked for here and kept nowhere. See the doc block.
func _draw_the_facts() -> void:
	_session.text = "%s  ·  %s  ·  %s  ·  up %s" % [
		("HOSTING" if Net.is_host else "CLIENT") if Net.is_networked() else "SOLO",
		Net.transport, _port_words(), _uptime_words()]
	_session.add_theme_color_override("font_color", GOOD if _is_serving() else AMBER)
	_world_line.text = "level %s  ·  %s  ·  %d craft  ·  %d pilots" % [Net.level,
		"simulating" if Sim.is_ready else "NOT SIMULATING", _craft(), Sim.pilots.size()]
	var ms: float = _tick_ms()
	_tick.text = "server tick %s  ·  %.0f Hz asked" % ["-" if ms < 0.0 else "%.3f ms" % ms, Sim.tick_hz]

	for row in _players.get_children():
		row.queue_free()
	var cards: Array = Net.roster_cards()
	if cards.is_empty():
		_players.add_child(_a_label("nobody yet", DIM, 15))
		return
	for card in cards:
		var client: int = int(card["player"])
		var team: int = Net.team_of(client)
		_players.add_child(_a_label("  %d   %s   %s" % [client, String(card["name"]),
			"-" if team == TeamBoard.NOBODY else TeamBoard.name_of(team)], PALE, 15))


## THE SAME FACTS AS ONE LINE, for a headless server -- which is the half of the user's sentence a panel cannot answer
## ("or headless"). Once a second, latest wins, in the shape every other harness line here uses, so a test reads the
## LAST one and a value that has not settled is never mistaken for one that never will.
##
## IT IS NOT GATED ON `--report=1`, and that is the difference between this line and `SESSION_REPORT`. A report is for a
## harness that asked for it; this IS the headless server's face, and a server that printed nothing unless a flag was
## passed would look hung to the person who started it.
func _say_it_where_a_shell_reads_it() -> void:
	var who := PackedStringArray()
	for card in Net.roster_cards():
		who.append("%d:%s:%d" % [int(card["player"]), String(card["name"]).replace(" ", "_"),
			Net.team_of(int(card["player"]))])
	# NO SPACES IN ANY VALUE, which is why the tick is a bare number here and carries its unit only on the panel: every
	# harness in this project splits a report line on spaces and then on `=`, and one value with a space in it silently
	# takes the next key with it. `sky.gd`'s `_near_words` says the same thing about its own.
	print("SERVER_CONSOLE role=%s transport=%s level=%s ready=%s players=%d who=%s craft=%d pilots=%d tick_ms=%.3f up_s=%d" % [
		("host" if Net.is_host else "client") if Net.is_networked() else "solo",
		Net.transport, Net.level, "yes" if Sim.is_ready else "no",
		Net.roster_cards().size(), ",".join(who) if not who.is_empty() else "-",
		_craft(), Sim.pilots.size(), _tick_ms(), (Time.get_ticks_msec() - _up_at) / 1000])


## HOW MANY MACHINES THE SIMULATION IS SERVING, from the SERVER's list. -1 where this process has no server, which is
## a fact and not a failure: see the doc block.
func _craft() -> int:
	var world: Object = _server()
	return int(world.vehicle_states().size()) if world != null else -1


## THE SERVER AS IT IS *NOW*, not as it was when this panel was built. See `server`.
func _server() -> Object:
	if server != null:
		return server
	return Sim.server


## WHAT THE SERVER'S OWN TICK COST, in milliseconds, or -1.0 on a process that has no server or a library with no
## breakdown in it. THE ONE PLACE IT IS WORKED OUT (rule 4): the panel and the headless line both format this, so a
## screen and a log cannot report different tick costs for the same second.
##
## `total_us` FIRST AND `total` AFTER IT, which is what `sky.gd`'s SESSION_REPORT reads, so the two agree on a library
## that names it either way.
func _tick_ms() -> float:
	var world: Object = _server()
	if world == null or not world.has_method("tick_breakdown"):
		return -1.0
	var breakdown: Dictionary = world.tick_breakdown()
	return float(breakdown.get("total_us", breakdown.get("total", 0.0))) / 1000.0


## Whether this process is actually serving anybody, which is what the session line's colour says.
func _is_serving() -> bool:
	return Net.is_networked() and Net.is_host


func _port_words() -> String:
	if Net.session_code != "":
		return "code %s" % Net.session_code
	return "port %d" % Net.usual_port


func _uptime_words() -> String:
	var seconds: int = (Time.get_ticks_msec() - _up_at) / 1000
	return "%d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]


func _a_label(words: String, colour: Color, size: int) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", size)
	return label
