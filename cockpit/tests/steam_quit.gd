extends Node
## DOES A PLAYER WHO QUITS AFTER USING STEAM QUIT, rather than leave a crash report behind?
##
##   Godot --headless --path cockpit res://tests/steam_quit.tscn
##
## A PROBE, because it needs a Steam client running, which is a property of the desk and not of the code. Where Steam is
## missing or not running it says SKIP out loud.
##
## THE BUG IT HOLDS. Measured 2026-09-14 on GodotSteam 4.21: a GDScript lambda still connected to the `Steam` singleton
## when the game quits makes the process exit 0xC0000005 after everything else has finished -- whether or not Steam was
## ever initialised, and whatever `steamShutdown` does. GodotSteam frees the singleton in its terminator, after the
## scripts are gone. Disconnected first, the same run exits 0. So `Net._exit_tree` has `SteamLobbyDirectory.close()`
## disconnect everything it connected, and this checks the one number that says whether it worked: the exit code.
##
## A PROCESS CANNOT READ ITS OWN EXIT CODE, so this starts a second one. The parent runs this scene with nothing after
## `--`; the child runs it with `--child`, hosts over Steam through `Net` exactly as the desk's button does, and quits.
## The parent reads what `OS.execute` returns.
##
## Read RESULT=, not the exit code -- of the parent.

## Long enough for a real Steam lobby to be made and the child to quit: 187 ms to make one was measured.
const CHILD_SECONDS: float = 30.0


func _ready() -> void:
	if "--child" in OS.get_cmdline_user_args():
		await _be_the_child()
		return
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"res://tests/steam_quit.tscn", "--", "--child"])
	var since: int = Time.get_ticks_msec()
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var said: String = "\n".join(PackedStringArray(output))
	var lines: PackedStringArray = []
	for line in said.split("\n"):
		if line.begins_with("[steam_quit]"):
			lines.append(line)
	print("\n".join(lines))
	print("[steam_quit] the child exited %d (0x%X) after %d ms" % [code, code & 0xFFFFFFFF, Time.get_ticks_msec() - since])
	if said.contains("[steam_quit] SKIP"):
		print("[steam_quit] SKIP -- the child could not reach Steam, so there is nothing to quit out of")
		print("RESULT=PASS")
	elif not said.contains("[steam_quit] hosted"):
		print("RESULT=FAIL the child never hosted")
	elif code != 0:
		print("RESULT=FAIL a_player_who_hosted_over_steam_quits_cleanly (exit %d)" % code)
	else:
		print("RESULT=PASS")
	get_tree().quit()


func _be_the_child() -> void:
	var why: String = Net.lobbies.unavailable()
	if why != "":
		print("[steam_quit] SKIP %s" % why)
		get_tree().quit()
		return
	Net.host_steam()
	var since: int = Time.get_ticks_msec()
	while not Net.is_in_session and Net.transport == "steam":
		if Time.get_ticks_msec() - since > int(CHILD_SECONDS * 1000.0):
			break
		await get_tree().process_frame
	print("[steam_quit] %s code %s" % ["hosted" if Net.is_in_session else "did not host", Net.session_code])
	get_tree().quit()
