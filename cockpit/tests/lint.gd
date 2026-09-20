extends Node
## Headless: does every script in the project still COMPILE, and does every scene still
## point at files that exist?
##
##   Godot --headless --path cockpit res://tests/lint.tscn
##
## THE CHEAPEST SUITE IN THE SET, AND THE ONE THAT RUNS FIRST. Under a second for the lot.
##
## A GDScript parse error does not fail a test run, it HANGS it. The scene never loads, so
## `_ready` never runs, so nothing calls `quit()`, and the suite sits there until the
## deadline kills it three minutes later -- reported as a TIMEOUT, which reads like a hang
## in the code under test rather than a typo. Every suite that has ever appeared to take
## minutes was this, and every one of them is now a red line here two seconds into the run.
##
## The other half is worse, because it is silent: A SCRIPT NOTHING INSTANTIATES CAN BE
## BROKEN FOR WEEKS. Most of `objects/controls/` is only ever built by a station scene at
## runtime, and a suite that never sits in that particular craft never touches it. The type
## checker already knows -- it just was not being asked.
##
## IT HAS TO RUN INSIDE THE PROJECT, which is why this is a scene rather than a shell loop
## over `--check-only`. Godot registers `Net` and `Sim` as global identifiers only when a
## main loop starts, so a standalone check of any file that mentions either fails on the
## autoload and then cascades -- "Failed to compile depended scripts" for two thirds of the
## project. From in here they exist, and the errors left over are real ones.
##
## Read RESULT=, not the exit code.

## Where not to look. `.godot` is the import cache, and `addons` is somebody else's code:
## the ashiato plugin ships its own scripts and its own editor tooling, and a warning in
## them is neither this project's to fix nor its business to fail on.
const SKIP: PackedStringArray = ["res://.godot", "res://addons"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[lint] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var scripts: PackedStringArray = _every("res://", ".gd")
	var scenes: PackedStringArray = _every("res://", ".tscn")
	# THE COUNT IS A CHECK OF ITS OWN. A walk that silently found nothing would pass every
	# assertion under it, which is the one way a linter can be worse than no linter at all.
	_check("there_are_files_to_read", scripts.size() > 40 and scenes.size() > 20,
		"%d scripts and %d scenes" % [scripts.size(), scenes.size()])
	var broken: PackedStringArray = []
	for path in scripts:
		if not _compiles(path):
			broken.append(path)
	_check("every_script_compiles", broken.is_empty(), _said(broken, scripts.size()))
	broken = []
	for path in scenes:
		for missing in _dangling(path):
			broken.append("%s -> %s" % [path.get_file(), missing])
	_check("and_every_scene_points_at_something_that_exists", broken.is_empty(),
		_said(broken, scenes.size()))
	broken = []
	var shaders: PackedStringArray = _every("res://", ".gdshader")
	shaders.append_array(_every("res://", ".gdshaderinc"))
	for path in shaders:
		if path not in READS_THE_ENGINE_EYE and _reads_the_engine_eye(path):
			broken.append(path)
	_check("and_no_shader_asks_the_engine_where_the_eye_is", broken.is_empty() and shaders.size() > 20,
		_said(broken, shaders.size()))
	broken = []
	var see_through: int = 0
	for path in shaders:
		if not path.ends_with(".gdshader") or not _is_see_through(path):
			continue
		see_through += 1
		if not MIST_EXEMPT.has(path) and not _includes_the_mist(path, {}):
			broken.append(path)
	# ONLY THE SPATIAL MIST READS THE DEPTH TEXTURE (team-lead, step 2c): the engine copies the depth buffer for the transparent
	# pass whenever any shader reads hint_depth_texture, and on PLAIN the compute mist draws and the spatial pass does not, so the
	# copy is skipped -- a shader that starts reading depth brings the copy back to every PLAIN frame.
	var depth_readers: Array[String] = []
	for path in shaders:
		if not DEPTH_READERS.has(path) and _shader_code(path).contains("hint_depth_texture"):
			depth_readers.append(path)
	_check("and_only_the_spatial_mist_reads_the_depth_texture", depth_readers.is_empty(), "%s" % [depth_readers])
	# A COMPUTE SHADER CARRIES THE HASH OF THE MIST'S MATHS IT INCLUDES (team-lead, 2026-09-15). An RDShaderFile is compiled on
	# import, and an edit to its include changes nothing in it, so nothing reimports it: PLAIN kept the old maths while FINE took
	# the new (the horizon fix, equality 11 of 12). Every .glsl that includes mist_core.gdshaderinc -- found by reading, not
	# listed -- must say the include's SHA-256 with carriage returns stripped (git checks out CRLF here and LF on Linux), so an
	# edit to the maths is an edit to the .glsl too, and every checkout's --import recompiles it with no hand step.
	var stamps_wrong: Array[String] = []
	var includers: int = 0
	var maths: String = FileAccess.get_file_as_string(MIST_MATHS).replace("\r", "").sha256_text()
	for path in _every("res://", ".glsl"):
		var code: String = FileAccess.get_file_as_string(path).replace("\r", "")
		if not code.contains("#include \"mist_core.gdshaderinc\""):
			continue
		includers += 1
		var stamp: String = ""
		for line in code.split("\n"):
			if line.begins_with(MATHS_STAMP):
				stamp = line.trim_prefix(MATHS_STAMP).strip_edges()
		if stamp != maths:
			stamps_wrong.append("%s says '%s', the maths are %s" % [path.get_file(), stamp, maths])
	_check("and_every_compute_shader_carries_the_hash_of_the_maths_it_includes", stamps_wrong.is_empty() and includers >= 1,
		"%d including%s" % [includers, "" if stamps_wrong.is_empty() else
			": %s -- put the maths' hash in the stamp, which recompiles the shader" % [stamps_wrong]])
	_check("and_every_see_through_shader_is_misted_or_says_why_not", broken.is_empty() and see_through > 10,
		"%d see-through shaders%s" % [see_through, "" if broken.is_empty() else ", not misted: %s" % [broken]])
	broken = []
	# AND ON THE MIST'S OWN CLOCK, NEVER TIME: the lamps must not read TIME (they flash from the tick alone), and d414da58 handed
	# their mist TIME and turned tests/night_lights.gd red on main. Read from the code, not its notes.
	var mist_calls: int = 0
	for path in shaders:
		# SPLIT ON "\n", NOT ON A NEWLINE TYPED INTO THE STRING: that literal took this file's own line ending, which is
		# \r\n in a Windows checkout, so an LF shader read as ONE line and any mist_along plus any TIME anywhere in it
		# failed. lane/oilrig found it writing a new shader, 2026-09-18.
		for line in _shader_code(path).split("\n"):
			if line.contains("mist_along("):
				mist_calls += 1
				if line.contains("TIME"):
					broken.append(path.get_file())
	_check("and_every_mist_call_hands_the_mists_own_clock_not_TIME", broken.is_empty() and mist_calls > 10,
		"%d calls%s" % [mist_calls, "" if broken.is_empty() else ", on TIME: %s" % [broken]])
	broken = []
	# THE SEA'S PAINTED DETAIL IS NEVER A HEIGHT. No hull floats on anything drawn, so a wave the simulation does not know
	# is sea over a deck it keeps dry (FINE's chop at 0.4 over the launch, 2026-09-15). The wind-sea, its gusts and its
	# whitecaps (`ocean_detail.gdshaderinc`) are normal, roughness and colour: neither ocean shader's vertex() may read them,
	# and the include may not touch VERTEX. Read from the code; tests/ocean_height_shot.gd holds the drawn height itself.
	var seas: int = 0
	for path in ["res://world/shaders/ocean.gdshader", "res://world/shaders/ocean_fine.gdshader"]:
		# LF ONLY: a Windows checkout writes CRLF, and a body's end searched as "\n}\n" was never found in either sea.
		var code: String = _shader_code(path).replace("\r", "")
		var start: int = code.find("void vertex()")
		var end: int = code.find("\n}\n", start)
		if start < 0 or end < 0:
			broken.append("%s has no vertex()" % path.get_file())
			continue
		seas += 1
		var body: String = code.substr(start, end - start)
		for word in ["wind_sea", "whitecap", "gusts", "paint_wind_sea", "ripple_map"]:
			if body.contains(word):
				broken.append("%s vertex() reads %s" % [path.get_file(), word])
	if _shader_code("res://world/shaders/ocean_detail.gdshaderinc").contains("VERTEX"):
		broken.append("ocean_detail.gdshaderinc touches VERTEX")
	_check("and_the_seas_painted_detail_moves_no_vertex", broken.is_empty() and seas == 2,
		"%d ocean vertex() read%s" % [seas, "" if broken.is_empty() else ": %s" % [broken]])
	broken = []
	for path in scripts + scenes:
		if _makes_a_see_through_material(path) and not MIST_EXEMPT_MATERIALS.has(path):
			broken.append(path)
	_check("and_every_see_through_material_is_misted_or_says_why_not", broken.is_empty(),
		_said(broken, scripts.size() + scenes.size()))
	broken = []
	# THE CARRIERS ARE ASKED OF NET, not listed here: `Net.carrier_for` is the one answer to which RPC carries sync's
	# bytes over each transport, and the send goes through it.
	var carriers: Dictionary = {}
	for which in ["enet", "steam"]:
		carriers[String(Net.carrier_for(which))] = false
	for path in scripts:
		for rpc in _godot_rpcs(path):
			if path == THE_PACKET_TRANSPORT and carriers.has(String(rpc["func"])):
				carriers[String(rpc["func"])] = true
			else:
				broken.append("%s:%d %s" % [path, int(rpc["line"]), rpc["func"]])
	var unmarked: PackedStringArray = []
	for name in carriers:
		if not bool(carriers[name]):
			unmarked.append(name)
	_check("and_only_the_packet_transport_is_a_godot_rpc", broken.is_empty() and unmarked.is_empty(),
		"carriers %s in %s%s%s" % [carriers.keys(), THE_PACKET_TRANSPORT,
			"" if broken.is_empty() else "; other RPCs: %s" % [broken],
			"" if unmarked.is_empty() else "; carriers with no @rpc: %s" % [unmarked]])
	# A BIT COUNT BELOW ONE IS NET'S OWN HELLO, never sync's (Net, "THE HELLO"): nothing but the packet transport names the
	# hello's bit count, reaches the carriers past `send_to`, or hands a send a negative count.
	broken = []
	var hello_sender := RegEx.create_from_string("HELLO" + "_BITS|_carry[(]|send_to(_server)?[(][^)]*,[ ]*-[ ]*[0-9]")
	for path in scripts:
		if path == THE_PACKET_TRANSPORT:
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i in range(lines.size()):
			if hello_sender.search(lines[i].split("#")[0]) != null:
				broken.append("%s:%d" % [path, i + 1])
	_check("and_only_the_packet_transport_sends_a_bit_count_below_one", broken.is_empty(),
		_said(broken, scripts.size()))
	broken = []
	var suites: int = 0
	for path in scripts:
		if not path.begins_with("res://tests/") or SOCKETS_EXEMPT.has(path):
			continue
		suites += 1
		for said in _sockets_outside_the_authority(path):
			broken.append(said)
	_check("and_every_suite_takes_its_ports_from_the_authority", broken.is_empty() and suites > 100,
		"%d suites read%s" % [suites, "" if broken.is_empty() else ": %s" % [broken]])
	broken = []
	var held: int = 0
	for path in scripts:
		var holding: PackedStringArray = _literals_holding_a_newline(path)
		held += holding.size()
		var allowed: int = int(RAW_NEWLINE_ALLOWED.get(path, 0))
		if holding.size() > allowed:
			for said in holding:
				broken.append(said)
		elif holding.size() < allowed:
			broken.append("%s: %d on the list, %d in the file -- take it off the list" % [path, allowed, holding.size()])
	_check("and_no_string_literal_is_broken_by_a_real_newline", broken.is_empty(),
		"%d held, every one of them on the list" % held if broken.is_empty() else "%s" % [broken])
	_finish()


## A SUITE'S SOCKETS COME FROM `TestPorts` AND NOWHERE ELSE (lane/ports, 2026-09-18). A port typed into a suite is the
## same socket in every checkout on the machine: `notices`, `sky_peers`, `bulk_peers` and the rest timed out or went red
## in nearly every lane's gate the night six lanes gated at once, and the one that printed its error printed "Couldn't
## create an ENet host." for a port another lane's copy held. So in a test file, outside comments:
##   - a number in the block the suites ask from (47900-48299), or the game's own 7788, only inside a `TestPorts` call
##     or as the suite's own `const FIRST_PORT` / `const LAST_PORT` -- and those two names only inside `TestPorts` calls;
##   - `Net.host()` or `Net.join(address)` with the port left off -- that is `Net.usual_port`, 7788 for everybody;
##   - `DEFAULT_PORT` handed to anything that opens a socket.
## The files it does not read, and why.
const SOCKETS_EXEMPT: Dictionary = {
	"res://tests/ports.gd": "the authority itself",
	"res://tests/launch_order.gd": "reads command-line flags into a dictionary and opens no socket; its numbers are text",
	"res://tests/lint.gd": "names the numbers in the pattern that looks for them",
}
## EVERY PORT IN `TestPorts`' BLOCK, so a suite that types one instead of asking the authority is caught. It has to
## cover the WHOLE block: it read `48[0-2]` while the block ended at 48299, and when the block was widened to 48399
## (lane/flatcrew, 2026-09-20, because it had run out) this line had to move with it -- otherwise a suite typing
## 48350 walks straight past the linter that exists to catch exactly that.
const TYPED_PORT: String = "\\b(7788|479[0-9][0-9]|48[0-3][0-9][0-9])\\b"
const PORT_LEFT_OFF: String = "Net\\.host\\(\\s*\\)|Net\\.join\\(\\s*(\"[^\"]*\"\\s*)?\\)"
const SOCKET_OPENER: String = "host\\(|join\\(|create_server|create_client|--host|--join"
const WANTED_DECLARED: String = "^const (FIRST|LAST)_PORT\\b"
const WANTED_USED: String = "\\b(FIRST|LAST)_PORT\\b"


## Every line of a test script, outside its comments, that opens a socket other than through `TestPorts`: "file:line".
func _sockets_outside_the_authority(path: String) -> PackedStringArray:
	var typed := RegEx.create_from_string(TYPED_PORT)
	var left_off := RegEx.create_from_string(PORT_LEFT_OFF)
	var opener := RegEx.create_from_string(SOCKET_OPENER)
	var declared := RegEx.create_from_string(WANTED_DECLARED)
	var used := RegEx.create_from_string(WANTED_USED)
	var found: PackedStringArray = []
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).replace("\r", "").split("\n")
	for i in range(lines.size()):
		var code: String = lines[i]
		if code.strip_edges().begins_with("#"):
			continue
		var through: bool = code.contains("TestPorts.")
		var declares: bool = declared.search(code) != null
		var wrong: bool = (typed.search(code) != null and not through and not declares) \
			or (used.search(code) != null and not through and not declares) \
			or left_off.search(code) != null \
			or (code.contains("DEFAULT_PORT") and opener.search(code) != null)
		if wrong:
			found.append("%s:%d" % [path.get_file(), i + 1])
	return found


## THE ONE SCRIPT ALLOWED A GODOT RPC, and only on the functions `Net.carrier_for` names: the carriers sync's packets ride,
## one per transport (ordered over ENet, unreliable over Steam). Game data goes through ashiato-sync and nothing else, so
## any other `@rpc` is a second ordering model and a second audience rule beside the one sync keeps (agents.md, "It goes
## on the input frame, not down a side channel"). Red when it went in (2026-09-14): `Sim._receive_client`, the joiner's
## sync client id sent to the host on a reliable RPC, which sync's own connection events now supply.
const THE_PACKET_TRANSPORT: String = "res://autoload/net.gd"


## Every `@rpc` annotation in a script outside its comments, with the function it annotates: [{line, func}].
func _godot_rpcs(path: String) -> Array:
	var found: Array = []
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for i in range(lines.size()):
		if not lines[i].split("#")[0].strip_edges().begins_with("@rpc"):
			continue
		var named: String = "?"
		for j in range(i + 1, mini(i + 4, lines.size())):
			var code: String = lines[j].split("#")[0].strip_edges()
			if code.begins_with("func "):
				named = code.trim_prefix("func ").get_slice("(", 0).strip_edges()
				break
		found.append({"line": i + 1, "func": named})
	return found


## THE MIST IS DRAWN FIRST AMONG THE SEE-THROUGH THINGS (world/shaders/mist.gdshader), so anything blended after it is laid over
## the misted world unmisted: a smoke column standing in valley fog would stand in front of it. Every blended spatial shader
## includes world/shaders/mist.gdshaderinc and applies `mist_along`, or is here with the reason it need not (team-lead,
## 2026-09-15: "the shared include is a contract for every transparent shader").
## The shaders that may read `hint_depth_texture`, and why: the spatial mist, which PLAIN does not draw, and a probe no level
## draws. See the check.
const DEPTH_READERS: Dictionary = {
	"res://world/shaders/mist.gdshader": "the spatial mist, FINE's; PLAIN draws the compute mist",
	"res://tests/mist_edges_probe.gdshader": "a pictures probe drawn only on --mist-pass=edges",
	"res://world/shaders/puff.gdshaderinc": "the body of puff.gdshader, which reads the depth texture only under CUT_AT_THE_WORLD",
	"res://world/shaders/puff.gdshader": "the puff clouds (PuffSky, lane/clouds2): each chord is cut at the world's surface, so an aeroplane in a cloud is in it and a cloud meets the hill; the copy this brings back to PLAIN is +0.022 to +0.075 ms, measured and chosen (research/clouds_2.md)",
}
## The mist's maths, which a compute shader includes, and the line that says which maths it was last compiled from. See the check.
const MIST_MATHS: String = "res://world/shaders/mist_core.gdshaderinc"
const MATHS_STAMP: String = "// mist_core sha256: "
const MIST_EXEMPT: Dictionary = {
	"res://world/shaders/mist.gdshader": "it is the mist",
	"res://tests/eye_probe.gdshader": "a probe",
	"res://tests/mist_edges_probe.gdshader": "a pictures probe: depth edges and sky, opaque, drawn only on --mist-pass=edges",
	"res://tests/mist_fill_probe.gdshader": "a pricing probe: the mist pass's quad with nothing in it, drawn only on --mist-pass=fill",
}
## AND THE STANDARD MATERIALS, which cannot include a shader: each file that makes a see-through one, and why it need not be misted.
const MIST_EXEMPT_MATERIALS: Dictionary = {
	"res://objects/weapons/burst.gd": "a shell's flash is light, a fraction of a second, and seen through haze as light",
	"res://objects/weapons/shot_yard.gd": "a tracer is a light, seconds long, and near",
	"res://levels/trace/trace_level.gd": "the path's curtain is a marker, meant to be found through haze, drawn with the fog off on purpose",
	"res://world/lift_yard.gd": "the rings round a thermal are a marker, meant to be found through haze",
	"res://world/sky.gd": "the waypoint column is a marker, meant to be found through haze",
	"res://objects/vehicles/vehicle_view.gd": "a cab's glass or a ghosted body is a pane on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/fighter_airframe.gd": "the close canopy is a pane on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/uh60_airframe.gd": "the close windscreens are panes on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/rotorcraft_kit.gd": "a helicopter's glazing and its swept rotor disc are panes on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/savoia_airframe.gd": "the windscreen and the propeller's disc are panes on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/skyhawk_airframe.gd": "the cabin's windows and the propeller's disc are panes on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/cessna310_airframe.gd": "the cabin's windows and the two propeller discs are panes on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/phantom_airframe.gd": "the two canopies are panes on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/tomcat_airframe.gd": "the canopy is a pane on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/falcon_airframe.gd": "the canopy is a pane on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/sailplane_airframe.gd": "the canopy is a pane on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/lightning_airframe.gd": "the canopy is a pane on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/harrier_airframe.gd": "the raised cockpit's canopy is a pane on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/warthog_airframe.gd": "the bubble canopy is a pane on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/warbird_airframe.gd": "every warbird's canopy is a pane on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/osprey_airframe.gd": "the flight deck's glazing and the proprotors' discs are panes on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/prowler_airframe.gd": "the canopy is a pane on an aircraft whose opaque body the pass mists",
	"res://objects/vehicles/jetliner_airframe.gd": "the flight deck's windscreen is a pane on an aircraft whose opaque body the pass mists",
	"res://objects/seats/gun_sight.gd": "in the cockpit, at arm's length",
	"res://objects/seats/lock_sight.gd": "in the cockpit, at arm's length",
	"res://objects/seats/helmet_sight.gd": "a helmet display a metre in front of the eye",
	"res://objects/seats/range_sight.gd": "a reticle half a metre in front of the eye",
	"res://player/hand_beam.gd": "in the hand",
	"res://addons/hand_signals/signal_ghosts.gd": "at arm's length round the signaller",
	"res://ui/vehicle_hud.tscn": "in the cockpit",
	"res://tests/lint.gd": "the check itself, which names TRANSPARENCY_ALPHA to look for it",
	"res://tests/seat_room_shot.gd": "a pictures probe in a bare room with no world and no mist: the envelope boxes are markers drawn to be seen through the craft",
}
const THE_MIST_INCLUDE: String = "res://world/shaders/mist.gdshaderinc"


## Whether a spatial shader draws blended: a blend mode or no depth in its render_mode, or ALPHA written with no scissor, outside
## its comments.
func _is_see_through(path: String) -> bool:
	var code: String = _shader_code(path)
	if not code.contains("shader_type spatial"):
		return false
	var mode := RegEx.new()
	mode.compile("render_mode([^;]*);")
	var found: RegExMatch = mode.search(code)
	var modes: String = found.get_string(1) if found != null else ""
	if modes.contains("blend_") or modes.contains("depth_draw_never"):
		return true
	return code.contains("ALPHA =") and not code.contains("ALPHA_SCISSOR_THRESHOLD")


## Whether a shader includes the mist, itself or through an include it includes.
func _includes_the_mist(path: String, seen: Dictionary) -> bool:
	if seen.has(path):
		return false
	seen[path] = true
	var include := RegEx.new()
	include.compile("#include\\s+\"([^\"]+)\"")
	for found in include.search_all(_shader_code(path)):
		var included: String = found.get_string(1)
		if included == THE_MIST_INCLUDE or _includes_the_mist(included, seen):
			return true
	return false


## Whether a script or scene makes a see-through StandardMaterial3D, outside comments.
func _makes_a_see_through_material(path: String) -> bool:
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var code: String = line.split("#")[0] if path.ends_with(".gd") else line
		if code.contains("TRANSPARENCY_ALPHA") or (path.ends_with(".tscn") and code.strip_edges() == "transparency = 1"):
			return true
	return false


## A shader's text with its // comments taken out -- EXCEPT an #include line, whose path has a `//` of its own in `res://`: the
## first run of the mist check split every include there and found all seventeen misted shaders unmisted (2026-09-15).
func _shader_code(path: String) -> String:
	var out: String = ""
	for line in FileAccess.get_file_as_string(path).split("\n"):
		out += (line if line.strip_edges().begins_with("#include") else line.split("//")[0]) + "\n"
	return out


## THE TWO FILES ALLOWED TO READ `CAMERA_POSITION_WORLD`: the include that replaces it, and the probe that reports what
## the engine gives.
const READS_THE_ENGINE_EYE: PackedStringArray = ["res://world/shaders/eye.gdshaderinc", "res://tests/eye_probe.gdshader"]


## WHETHER A SHADER READS THE EYE FROM THE ENGINE, outside its comments.
##
## On the precision=double editor the game is played on, Godot 4.7.2's Forward+ hands a shader MINUS the camera as
## `CAMERA_POSITION_WORLD`, and as the translation of `INV_VIEW_MATRIX`, in every stage (tests/eye_shot.gd has the
## lines in Godot's source). The stock editor hands the camera. So a shader that asks draws right on the editor a
## window is looked at with and wrong in the headset: the runway lights were domes a hundred pixels across. The eye
## comes from `EYE_POSITION_WORLD` in world/shaders/eye.gdshaderinc, worked out from VIEW_MATRIX, which both builds
## hand over whole. Red when it went in (2026-09-14): 22 of the 39 shaders and includes asked.
func _reads_the_engine_eye(path: String) -> bool:
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var code: String = line.split("//")[0]
		if code.contains("CAMERA_POSITION_WORLD") or code.contains("INV_VIEW_MATRIX[3]"):
			return true
	return false


## ONE SCRIPT, PARSED FROM DISK. True if the type checker is happy with it.
##
## THE OBVIOUS WAY CRASHES THE ENGINE. `ResourceLoader.load` with CACHE_MODE_IGNORE
## segfaults on any script carrying a `class_name`: the global class table still points at
## the copy in memory, a second copy is compiled beside it, and the first dependency
## resolved between the two walks a dangling pointer. CACHE_MODE_REPLACE survives but
## reports nothing -- it prints the parse error and then hands back the cached script, so
## there is no way to tell a good file from a bad one. And plain `load` never re-reads the
## file at all, which makes the whole suite a check of whether the cache is happy.
##
## So the source is read as TEXT and compiled into a script of its own, which touches
## neither the cache nor the class table and answers with an error code.
##
## The one thing that has to go is the `class_name` line: a second declaration of a name
## already in the global table is an error in itself ("hides a global script class"), and
## it would be the only thing this ever reported. Commented out IN PLACE rather than
## deleted, so the line numbers in the parse errors underneath still match the file.
func _compiles(path: String) -> bool:
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for i in range(lines.size()):
		if lines[i].begins_with("class_name "):
			lines[i] = "#" + lines[i].substr(1)
	var script := GDScript.new()
	script.source_code = "\n".join(lines)
	# `resource_path` stays empty on purpose. Setting it to the real path would put this
	# copy into the cache under the name of the file it came from.
	return script.reload(true) == OK


## EVERY FILE A SCENE NAMES THAT IS NOT THERE.
##
## A scene whose script has been renamed out from under it still LOADS -- Godot drops the
## missing resource, warns, and hands back a PackedScene -- so there is nothing to test by
## loading it. What there is to test is the text: an `ext_resource` line names a path, and
## either that path is a file or the scene is broken. This is the check that would have
## turned a renamed control into a red line rather than into a cockpit with a gap in it.
func _dangling(path: String) -> PackedStringArray:
	var missing: PackedStringArray = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.begins_with("[ext_resource "):
			continue
		var quoted: PackedStringArray = line.split("path=\"")
		if quoted.size() < 2:
			continue
		var named: String = quoted[1].split("\"")[0]
		# `uid://` is an alias for a path this cannot resolve without the import cache, and
		# a path is written beside it on every line that has one -- so there is nothing
		# here that only a uid can answer.
		if named.begins_with("res://") and not ResourceLoader.exists(named):
			missing.append(named)
	return missing


func _said(broken: PackedStringArray, total: int) -> String:
	if broken.is_empty():
		return "all %d" % total
	return "%d of %d: %s" % [broken.size(), total, ", ".join(broken)]


## Every file under `at` whose name ends in `suffix`, depth first.
##
## `DirAccess` and not a written list: a list is a roster, and a roster of every file in the
## project is the one roster nobody would keep in step. A file nothing else mentions is
## exactly the file this suite exists to find.
func _every(at: String, suffix: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for skip in SKIP:
		if at.begins_with(skip):
			return found
	var dir: DirAccess = DirAccess.open(at)
	if dir == null:
		return found
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var path: String = at.path_join(name)
		if dir.current_is_dir():
			found.append_array(_every(path, suffix))
		elif name.ends_with(suffix):
			found.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	return found


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()

## A STRING LITERAL BROKEN BY A REAL NEWLINE MEANS TWO DIFFERENT THINGS ON TWO MACHINES (lane/voicefix, 2026-09-20).
## GDScript accepts a newline inside a `"..."` literal, and the literal then holds whatever bytes end that line in the
## file on disk. `core.autocrlf=true` here, so every `.gd` is checked out CRLF on Windows and LF on Linux: the same
## source is `"\r\n"` on one machine and `"\n"` on the other, and nothing about reading it tells you which.
##
## `intercom_peers` lost a night's merges to it. Two of its helpers split the host's log on such a literal -- so, on
## this machine, on `"\r\n"` -- while Godot writes `user://*.log` LF-only (measured: CR=0 against LF=204). The split
## found no separator, handed back the whole file as ONE element, that element did not begin with `LOBBY_VOICE `, and
## the helper returned empty. Its siblings, written `split("\n")`, read the very same string correctly, so two readers
## of one string disagreed and the fault looked impossible. It was invisible on Linux, where the literal is `"\n"`.
##
## A GREP CANNOT FIND THESE, which is why this is a walk and not a `RegEx`. A regex cannot tell a closing quote from an
## opening one and does not know a comment when it sees one: grepping for a quote at end of line found 3 of them, and
## walking every file character by character, tracking which quote opened a literal and whether it was tripled, found
## 16 in 1162 scripts. Tripled strings (`"""..."""`) are meant to span lines and are not the fault.
##
## THE ONES BELOW ARE KNOWN AND ALLOWED BY NUMBER, not by file. Every one of them JOINS strings rather than splitting a
## file, so at worst it writes CRLF where LF was meant into a message or a label; none is known to be wrong, and the
## naive repair is worse than the disease. Writing `"\n"` at a site that SPLITS leaves a trailing `\r` on every line on
## Windows, where `begins_with` keeps passing while an equality, an `ends_with` or a `to_int` on a trailing field
## quietly change -- the same fault pointed the other way, and silent on both platforms instead of loud on one. A
## reader is repaired with `text.replace("\r\n", "\n").split("\n")`, which is what `pavement` and `water_surfaces` do
## since b0496f83 and why neither appears here.
##
##   res://objects/seats/crew_board.gd  the only one outside a test: joins the crew board's rows into a real
##                                      `Label.text`, so that label is CRLF on Windows and LF on Linux. Worth a look
##                                      by whoever is next in the board; not investigated here.
##   res://tests/jet_arms.gd            `says.replace(<newline>, " | ")` on text the GAME produced, so it may simply
##                                      never fire. It only tidies a failure detail, and it is a reader, not a writer.
##   res://tests/fit.gd                 joins a list of faults into the detail string of a `_check`.
##   res://tests/liners_shot.gd         two lines of a `Label3D` caption in a screenshot.
##   res://tests/rotor_hold.gd          as `fit.gd`.
##   res://tests/skyhawk.gd             as `fit.gd`.
##   res://tests/stations.gd            two: one as `fit.gd`, one joining the board's rows to search them for a name,
##                                      where the separator cannot matter.
##
## BY NUMBER RATHER THAN BY FILE, because exempting a whole file hides the NEXT one somebody adds to it, and the next
## one is the one this rule exists to catch. A file that drops below its number fails too, so the list shrinks as the
## sites are repaired instead of rotting: it is a record of work owed, and `todo/voicefix--string-literals-holding-a-
## raw-newline.md` says what finishes it. `racer/world/race.gd` holds five more that this suite cannot see, because it
## reads `res://` and that is another project.
const RAW_NEWLINE_ALLOWED: Dictionary = {
	"res://objects/seats/crew_board.gd": 1,
	"res://tests/fit.gd": 1,
	"res://tests/jet_arms.gd": 1,
	"res://tests/liners_shot.gd": 1,
	"res://tests/rotor_hold.gd": 1,
	"res://tests/skyhawk.gd": 1,
	"res://tests/stations.gd": 2,
}


## Every string literal in a script that is broken by a real newline, as "file:line" of the line it opened on.
## Tripled strings are allowed to span lines and are skipped; a comment is skipped; a backslash takes the character
## after it whatever that character is, so an escaped quote does not close the literal.
func _literals_holding_a_newline(path: String) -> PackedStringArray:
	var text: String = FileAccess.get_file_as_string(path)
	var found: PackedStringArray = []
	var line: int = 1
	var i: int = 0
	while i < text.length():
		var c: String = text[i]
		if c == "\n":
			line += 1
			i += 1
		elif c == "#":
			while i < text.length() and text[i] != "\n":
				i += 1
		elif c == "\"" or c == "'":
			var opened: int = line
			var triple: bool = text.substr(i, 3) == c.repeat(3)
			var quote: String = c.repeat(3) if triple else c
			var holds: bool = false
			i += quote.length()
			while i < text.length():
				if text[i] == "\\":
					if text.substr(i + 1, 1) == "\n":
						line += 1
					i += 2
					continue
				if text.substr(i, quote.length()) == quote:
					i += quote.length()
					break
				if text[i] == "\n":
					holds = true
					line += 1
				i += 1
			if holds and not triple:
				found.append("%s:%d" % [path, opened])
		else:
			i += 1
	return found
