extends Node
## The first voice activation, model loading, host capture queue and both shutdown cases are
## measured on the main loop. Kokoro may take seconds on its worker; none of that may take a
## 90 Hz frame from the game. Read RESULT=, not the process exit code.

const HEADSET_USEC: int = 11112
const EVENT_FRAMES: int = 4
const QUIET_FRAMES: int = 140
const LOAD_SECONDS: float = 60.0
const RENDER_SECONDS: float = 20.0

var _failures: PackedStringArray = []
var _frames := PackedInt64Array()
var _last_usec: int = 0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_frames.append(now - _last_usec)
	_last_usec = now


func _check(label: String, ok: bool, detail: String) -> void:
	print("[voice_thread] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	await _wait_frames(8)
	# Radio authority is the production authority: host-generated PCM, even in a one-machine session.
	Net.play_solo()
	var why := Headphones.why_there_is_no_voice()
	if not why.is_empty():
		print("[voice_thread] SKIP voice assets unavailable (%s)" % why)
		print("RESULT=PASS")
		get_tree().quit()
		return

	# A normal switch supplies the direct-call baseline without touching the extension.
	var switch_usec := PackedInt64Array()
	for on in [true, false, true, false, true, false]:
		var started := Time.get_ticks_usec()
		Headphones.choose_game_sound(on)
		switch_usec.append(Time.get_ticks_usec() - started)
		await _wait_frames(EVENT_FRAMES)

	var quiet_at := _frames.size()
	await _wait_frames(QUIET_FRAMES + 1)
	var quiet_p99 := _at(_slice(quiet_at, QUIET_FRAMES), 0.99)
	var event_at := _frames.size()
	var began := Time.get_ticks_usec()
	Headphones.choose_voice(true)
	var first_call := Time.get_ticks_usec() - began
	await _wait_frames(EVENT_FRAMES + 1)
	var first_frames := _worst(event_at, EVENT_FRAMES)
	_check("the_first_voice_activation_returns_within_two_headset_frames",
		first_call - _median(switch_usec) <= HEADSET_USEC * 2,
		"voice %d us, ordinary switch %d us" % [first_call, _median(switch_usec)])
	_check("and_its_first_frames_stay_within_one_headset_frame_of_the_adjacent_baseline",
		first_frames - quiet_p99 <= HEADSET_USEC,
		"event %d us, quiet p99 %d us, +%d us" % [first_frames, quiet_p99, first_frames - quiet_p99])

	var loading_at := _frames.size()
	var loaded := await _wall_until(func() -> bool: return Headphones.voice != PilotHeadphones.Voice.LOADING,
		LOAD_SECONDS)
	var loading_frames := _frames.size() - loading_at
	var loading_p99 := _at(_slice(loading_at, loading_frames), 0.99)
	_check("the_model_finishes_loading_on_the_worker", loaded and Headphones.voice == PilotHeadphones.Voice.ON,
		"state %d after %d frames" % [Headphones.voice, loading_frames])
	_check("and_model_loading_does_not_take_a_main_loop_frame",
		loading_p99 - quiet_p99 <= HEADSET_USEC,
		"loading p99 %d us, quiet p99 %d us, +%d us" % [loading_p99, quiet_p99, loading_p99 - quiet_p99])

	# Drive the production host-generated clip path, not the retired ambient frequency.
	var render_began := Time.get_ticks_usec()
	var render_why := Radio.speak("Cockpit tower radio check")
	var render_call := Time.get_ticks_usec() - render_began
	# First render also creates Godot's capture bus, channel and player. It is still bounded by one headset frame;
	# subsequent queues are the short lock/copy path inside that already-built channel.
	_check("a_host_radio_line_is_queued_without_blocking", render_why.is_empty() and render_call <= HEADSET_USEC,
		"'%s', %d us" % [render_why, render_call])
	await _wall(0.15)
	await _timed_off("voice_off_during_host_capture_holds_no_frame")

	# A second activation proves the render channel was not left bound to the old server.
	Headphones.choose_voice(true)
	await _wall_until(func() -> bool: return Headphones.voice != PilotHeadphones.Voice.LOADING, LOAD_SECONDS)
	var rendered := [false]
	var heard := func(_samples: PackedFloat32Array, _rate: int, _text: String) -> void: rendered[0] = true
	Headphones.rendered.connect(heard)
	render_why = Radio.speak("Cockpit tower second radio check")
	await _wall_until(func() -> bool: return rendered[0], RENDER_SECONDS)
	Headphones.rendered.disconnect(heard)
	_check("voice_on_again_uses_the_new_server_for_host_capture", render_why.is_empty() and rendered[0],
		"'%s', rendered %s" % [render_why, rendered[0]])
	await _wall_until(func() -> bool: return not Headphones.on_air(), RENDER_SECONDS)
	await _wall(0.25)
	var idle_over := PackedInt64Array([await _measure_off()])
	# Three adjacent measurements make the verdict about the voice lifetime rather than one scheduler interruption.
	# The old blocking library held every idle shutdown for 72..80 ms, so a median remains strongly discriminating.
	for repeat in range(2):
		Headphones.choose_voice(true)
		await _wall_until(func() -> bool: return Headphones.voice != PilotHeadphones.Voice.LOADING, LOAD_SECONDS)
		await _wall_until(func() -> bool: return not Headphones.on_air(), RENDER_SECONDS)
		await _wall(0.25)
		idle_over.append(await _measure_off())
	_check("voice_off_when_idle_returns_within_two_headset_frames", _median(idle_over) <= HEADSET_USEC * 2,
		"median +%d us of %s" % [_median(idle_over), idle_over])

	Net.leave("voice thread suite")
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL", "" if _failures.is_empty()
		else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _timed_off(label: String) -> void:
	var over := await _measure_off()
	_check(label, over <= HEADSET_USEC, "+%d us" % over)


func _measure_off() -> int:
	var pair_at := _frames.size()
	await _wait_frames(EVENT_FRAMES + 1)
	var pair := _worst(pair_at, EVENT_FRAMES)
	var event_at := _frames.size()
	Headphones.choose_voice(false)
	await _wait_frames(EVENT_FRAMES + 1)
	var event := _worst(event_at, EVENT_FRAMES)
	print("[voice_thread] off event %d us, adjacent pair %d us, +%d us" % [event, pair, event - pair])
	return event - pair


func _slice(at: int, count: int) -> PackedInt64Array:
	var out := PackedInt64Array()
	for i in range(at, mini(at + count, _frames.size())):
		out.append(_frames[i])
	out.sort()
	return out


func _worst(at: int, count: int) -> int:
	return _at(_slice(at, count), 1.0)


func _at(sorted: PackedInt64Array, fraction: float) -> int:
	if sorted.is_empty():
		return 0
	return sorted[clampi(int(floor(float(sorted.size() - 1) * fraction)), 0, sorted.size() - 1)]


func _median(values: PackedInt64Array) -> int:
	var sorted := values.duplicate()
	sorted.sort()
	return _at(sorted, 0.5)


func _wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _wall(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _wall_until(done: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if done.call():
			return true
		await get_tree().process_frame
	return bool(done.call())
