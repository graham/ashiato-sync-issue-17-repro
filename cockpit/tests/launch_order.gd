extends Node
## Headless: does a command line start the session it spells, and refuse, in words, every spelling that is almost one?
##
##   Godot --headless --path cockpit res://tests/launch_order.tscn
##
## THE PARSER IS PURE, so every spelling is a check here without a process. `LaunchOrder.read` owns the session flags
## and nothing else: `--level=` and `--kind=` belong to the router and the bench, and Godot's own arguments to Godot. A
## token in its namespace that is not exactly one of its spellings is a typo, and a typo is what boots a harness into a
## lone solo game it then waits on for ever -- so a typo is refused and the words say what was meant.
##
## Asked for in agents.md's WHAT IS NOT HERE YET ("A boot flag for host or join"), and needed by the two-process check
## and the two-machine Steam run, neither of which has anybody at the desk to press a button.
##
## Read RESULT=, not the exit code.

const PORT: int = 7788

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[launch_order] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_spellings_it_takes()
	_the_spellings_it_refuses_and_why()
	_what_is_not_its_business()
	_finish()


func _read(user: Array, engine: Array = []) -> Dictionary:
	return LaunchOrder.read(PackedStringArray(user), PackedStringArray(engine), PORT)


func _the_spellings_it_takes() -> void:
	var cases: Array = [
		# user args, engine args, expected subset
		[[], [], {"mode": "none", "error": ""}],
		[["--host"], [], {"mode": "host", "port": PORT}],
		[["--host=47980"], [], {"mode": "host", "port": 47980}],
		[["--join=127.0.0.1:47980"], [], {"mode": "join", "address": "127.0.0.1", "port": 47980}],
		[["--join=10.0.0.5"], [], {"mode": "join", "address": "10.0.0.5", "port": PORT}],
		[["--steam-host"], [], {"mode": "steam_host"}],
		[["--steam-join=k7m-q2x"], [], {"mode": "steam_code", "code": "K7MQ2X"}],
		[[], ["--path", "cockpit", "+connect_lobby", "109775241445887825"], {"mode": "steam_lobby",
			"lobby": 109775241445887825}],
		[["--level=world", "--host=47981", "--kind=cessna"], [], {"mode": "host", "port": 47981, "error": ""}],
	]
	for case in cases:
		var got: Dictionary = _read(case[0], case[1])
		var wanted: Dictionary = case[2]
		var same: bool = String(got.get("error", "")) == String(wanted.get("error", ""))
		for key in wanted:
			same = same and got.get(key) == wanted[key]
		_check("takes_%s" % JSON.stringify(case[0] + case[1]), same, "got %s" % [got])


func _the_spellings_it_refuses_and_why() -> void:
	var cases: Array = [
		[["--host_port=47980"], [], "'--host_port=47980' is not a session flag: --host, --host=PORT, --join=ADDRESS[:PORT], --steam-host or --steam-join=CODE"],
		[["--host=0"], [], "--host= wants a port from 1 to 65535, and '0' is not one"],
		[["--host=seventy"], [], "--host= wants a port from 1 to 65535, and 'seventy' is not one"],
		[["--join=127.0.0.1:99999"], [], "--join= wants address:port with a port from 1 to 65535, and '99999' is not one"],
		[["--join="], [], "--join= wants an address"],
		[["--join"], [], "'--join' is not a session flag: --host, --host=PORT, --join=ADDRESS[:PORT], --steam-host or --steam-join=CODE"],
		[["--steam-join=K0MQ2X"], [], "--steam-join=: Codes have no 0, O, 1 or I."],
		[["--steam-join="], [], "--steam-join=: Type the host's code first."],
		[["--port=47980"], [], "'--port=47980' is not a session flag: --host, --host=PORT, --join=ADDRESS[:PORT], --steam-host or --steam-join=CODE"],
		[["--host", "--join=127.0.0.1"], [], "one session at a time: --host and --join=127.0.0.1"],
		[[], ["+connect_lobby", "banana"], "+connect_lobby wants a lobby id, and 'banana' is not one"],
		[["--steam-host"], ["+connect_lobby", "123"], "one session at a time: --steam-host and +connect_lobby"],
	]
	for case in cases:
		var got: Dictionary = _read(case[0], case[1])
		_check("refuses_%s" % JSON.stringify(case[0] + case[1]), String(got["error"]) == String(case[2]),
			"got '%s'" % got["error"])


## NOT ITS BUSINESS: the router's and the bench's flags, Godot's, and a bare `--`, all pass untouched.
func _what_is_not_its_business() -> void:
	var got: Dictionary = _read(["--level=seat", "--kind=osprey", "--seat=1", "--fire=3", "--audio"],
		["--headless", "--path", "cockpit", "res://world/boot.tscn"])
	_check("other_flags_are_somebody_elses", String(got["mode"]) == "none" and String(got["error"]) == "",
		"got %s" % [got])


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
