extends RefCounted
class_name LaunchOrder
## WHAT SESSION A COMMAND LINE ASKS FOR, read before the first level loads: host, join an address, host over Steam, or
## join a Steam game by its code or by the lobby an invite named.
##
##   Godot --path cockpit -- --host                      host over ENet on the default port
##   Godot --path cockpit -- --host=47970                host over ENet on that port
##   Godot --path cockpit -- --join=127.0.0.1:47970      join over ENet
##   Godot --path cockpit -- --steam-host                host over Steam, print STEAM_CODE=
##   Godot --path cockpit -- --steam-join=K7M-Q2X        join over Steam by code
##   Godot --path cockpit +connect_lobby 1097752414...    what Steam itself passes when an invite starts the game
##
## Asked for in agents.md's WHAT IS NOT HERE YET ("A boot flag for host or join") and needed by the two-machine Steam
## run, which has no one at a desk to press a button. Copied in shape from topdowntest's `Network.parse_boot_flags`:
##
## - PURE, so every malformed spelling is a unit check without launching anything.
## - IT OWNS A NAMESPACE AND NOTHING ELSE. A token that starts `--host`, `--join`, `--steam` or `--port` and is not exactly
##   one of the spellings above is a typo, and a typo is what boots a process into the wrong state -- `--host_port=7970`
##   would otherwise start a lone solo game that a harness waits on for ever -- so it is an error and the process says
##   BOOT_ERROR= and quits. Anything else (`--level=`, `--kind=`, Godot's own) is somebody else's and passes untouched.
## - A CODE IS READ BY `JoinCode`, the one validator, so a code refused on the command line is refused in the same words
##   as on the keypad.

const PREFIXES: PackedStringArray = ["--host", "--join", "--steam", "--port"]


## {mode: "none" | "host" | "join" | "steam_host" | "steam_code" | "steam_lobby", port: int, address: String,
##  code: String, lobby: int, error: String}. `error` non-empty means do not boot; `mode` is then meaningless.
static func read(user_args: PackedStringArray, engine_args: PackedStringArray, default_port: int) -> Dictionary:
	var out: Dictionary = {"mode": "none", "port": default_port, "address": "127.0.0.1", "code": "", "lobby": 0,
		"error": ""}
	var asked: Array[String] = []
	for token in user_args:
		var text: String = String(token)
		var said: String = _one(text, default_port, out)
		if said == "not ours":
			continue
		if said != "":
			out["error"] = said
			return out
		asked.append(text)
	# STEAM'S OWN SPELLING, before the `--` where Steam puts it: `+connect_lobby <id>`.
	for i in range(engine_args.size() - 1):
		if String(engine_args[i]) == "+connect_lobby":
			var lobby: String = String(engine_args[i + 1])
			if not lobby.is_valid_int() or lobby.to_int() <= 0:
				out["error"] = "+connect_lobby wants a lobby id, and '%s' is not one" % lobby
				return out
			out["mode"] = "steam_lobby"
			out["lobby"] = lobby.to_int()
			asked.append("+connect_lobby")
	if asked.size() > 1:
		out["error"] = "one session at a time: %s" % " and ".join(asked)
	return out


## One token. "" when it was ours and understood, "not ours" when it belongs to somebody else, a sentence otherwise.
static func _one(text: String, default_port: int, out: Dictionary) -> String:
	var ours: bool = false
	for prefix in PREFIXES:
		ours = ours or text.begins_with(prefix)
	if not ours:
		return "not ours"
	if text == "--host":
		out["mode"] = "host"
		return ""
	if text.begins_with("--host="):
		var port: String = text.substr(7)
		if not _is_port(port):
			return "--host= wants a port from 1 to 65535, and '%s' is not one" % port
		out["mode"] = "host"
		out["port"] = port.to_int()
		return ""
	if text.begins_with("--join="):
		var where: Dictionary = read_address(text.substr(7), default_port)
		if String(where["error"]) != "":
			return "--join= %s" % where["error"]
		out["mode"] = "join"
		out["address"] = where["address"]
		out["port"] = where["port"]
		return ""
	if text == "--steam-host":
		out["mode"] = "steam_host"
		return ""
	if text.begins_with("--steam-join="):
		var typed: String = text.substr(13)
		var why: String = JoinCode.why_not(typed)
		if why != "":
			return "--steam-join=: %s" % why
		out["mode"] = "steam_code"
		out["code"] = JoinCode.read(typed)
		return ""
	return "'%s' is not a session flag: --host, --host=PORT, --join=ADDRESS[:PORT], --steam-host or --steam-join=CODE" % text


## WHERE A PERSON MEANT: `ADDRESS` or `ADDRESS:PORT`, as {address, port, error}. `error` non-empty means it is not one,
## and is a sentence a player can act on.
##
## ONE PARSER, TWO DOORS. The command line has read `--join=ADDRESS[:PORT]` since the boot flags went in; the desk's
## address field could only ever mean an address, and `DeskRoom` handed it straight to `Net.join` whose port argument
## defaults -- so the only host reachable from the main menu was one on 7788, and a player typing the perfectly
## reasonable `192.168.1.50:7788` got a host name that does not resolve and, ten seconds later, "Nothing is listening
## there." (2026-09-15). Both doors come here now, so the two cannot drift.
static func read_address(where: String, default_port: int) -> Dictionary:
	var out: Dictionary = {"address": where.strip_edges(), "port": default_port, "error": ""}
	if where.contains(":"):
		out["address"] = where.get_slice(":", 0).strip_edges()
		var given: String = where.get_slice(":", 1).strip_edges()
		if not _is_port(given):
			out["error"] = "wants address:port with a port from 1 to 65535, and '%s' is not one" % given
			return out
		out["port"] = given.to_int()
	if String(out["address"]).is_empty():
		out["error"] = "wants an address"
	return out


static func _is_port(text: String) -> bool:
	return text.is_valid_int() and text.to_int() >= 1 and text.to_int() <= 65535
